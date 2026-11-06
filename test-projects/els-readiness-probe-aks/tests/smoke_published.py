#!/usr/bin/env python3
"""Exercise a local published DLL with loopback-only, unavailable dependencies."""

import argparse
from contextlib import ExitStack
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import time
import urllib.error
import urllib.request


def reserved_port(stack):
    connection = stack.enter_context(socket.socket())
    connection.bind(("127.0.0.1", 0))
    # Bound but not listening: connections fail, and another local server cannot
    # claim the selected dependency port while this smoke test is running.
    return connection.getsockname()[1]


def smoke(dll):
    dotnet = shutil.which("dotnet")
    if not dotnet or not dll.is_file():
        raise RuntimeError("Supply a published DLL and an installed .NET 10 runtime.")
    with ExitStack() as stack:
        postgres_port, redis_port = reserved_port(stack), reserved_port(stack)
        with socket.socket() as server_port:
            server_port.bind(("127.0.0.1", 0))
            port = server_port.getsockname()[1]
        environment = dict(os.environ)
        environment.update({
            "Postgres__ConnectionString": f"Host=127.0.0.1;Port={postgres_port};Username=unused;Database=unused;Timeout=1;Command Timeout=1",
            "Postgres__Password": "",
            "Redis__ConnectionString": f"127.0.0.1:{redis_port},abortConnect=false,connectRetry=0,connectTimeout=100,syncTimeout=100,asyncTimeout=100",
            "Redis__Password": "",
            "Probe__Enabled": "false",
            "ASPNETCORE_ENVIRONMENT": "Production",
        })
        child = subprocess.Popen([dotnet, str(dll), "--urls", f"http://127.0.0.1:{port}"],
                                 cwd=dll.parent, env=environment, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT,
                                 creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        # Do not forward localhost requests through any configured HTTP proxy.
        client = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        base = f"http://127.0.0.1:{port}"
        try:
            deadline = time.monotonic() + 15
            while True:
                if child.poll() is not None:
                    raise RuntimeError("Published application exited before liveness succeeded.")
                try:
                    with client.open(base + "/health/liveness", timeout=1) as response:
                        assert response.status == 200 and response.read() == b"Healthy"
                    break
                except (urllib.error.URLError, TimeoutError):
                    if time.monotonic() >= deadline:
                        raise RuntimeError("Published application did not start on localhost.") from None
                    time.sleep(0.1)
            with client.open(base + "/diagnostics/stats", timeout=2) as response:
                assert json.load(response)["completedRuns"] == 0
            try:
                client.open(base + "/health/readiness", timeout=15)
                raise AssertionError("Readiness unexpectedly succeeded with closed dependency ports.")
            except urllib.error.HTTPError as response:
                assert response.code == 503 and response.read() == b"Unhealthy"
            with client.open(base + "/diagnostics/stats", timeout=2) as response:
                statistics = json.load(response)
            assert statistics["completedRuns"] == 1
            assert all(check["attempts"] == 1 and check["unhealthy"] == 1
                       for check in statistics["checks"].values())
            print("Published app smoke passed: localhost HTTP, liveness, statistics and both real-driver failure paths.")
        finally:
            if child.poll() is None:
                child.terminate()
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=5)
            child.stdout.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dll", type=Path, required=True)
    smoke(parser.parse_args().dll.resolve())
