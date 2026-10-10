#!/usr/bin/env python3
"""Offline ClickHouse/API regression matrix. Requires Helm, PyYAML and a POSIX shell.

Run: python tests/helm/clickhouse-api-env.py
Optional preservation review: --baseline-chart PATH_TO_V6_02_CHART_BEFORE_FOLLOWUP
Optional shell selection: --shell PATH_TO_SH_OR_BASH
Only synthetic settings are used; rendered manifests and passwords are not printed.
"""

import argparse
import base64
import copy
import json
import os
import pathlib
import re
import shutil
import subprocess
import tempfile

import yaml


ROOT = pathlib.Path(__file__).resolve().parents[2]
RELEASE = "v6check"
CLICKHOUSE_ENV = {
    "OLAPProvider", "ClickHouse__HttpEndpoint", "ClickHouse__Database",
    "ClickHouse__User", "ClickHouse__Password",
}
INLINE_PASSWORD = "synthetic-test:@%/'\\\" & $() password\nwith-special-characters-\u00e9"
TLS = {"clickhouse": {"tls": {"enabled": True, "certificatesSecret": "test-clickhouse-tls",
                            "certFilename": "tls.crt", "certKeyFilename": "tls.key"}}}
COMMON = {
    "apiExternalUrl": "https://api.example.test",
    "evaluationServerExternalUrl": "https://els.example.test",
    "ui": {"env": [{"name": "BASE_HREF", "value": "/flags/"}]},
    "api": {
        "ssoEnabled": True,
        "env": [
            {"name": "Jwt__Algorithm", "value": "HS256"},
            {"name": "Jwt__Key", "valueFrom": {"secretKeyRef": {
                "name": "test-jwt", "key": "key"}}},
            {"name": "Logging__MinimumLevel__Default", "value": "Warning"},
        ],
    },
    "els": {"env": [{"name": "RateLimiting__Enabled", "value": "true"}]},
    "openTelemetry": {"enabled": True, "endpoint": "http://otel.example.test:4317"},
}
PRO = {"architecture": {"tier": "professional"}, "kafka": {"enabled": True}}
BUNDLED = {"clickhouse": {"enabled": True}}
EXTERNAL = {"externalClickhouse": {"httpEndpoint": "http://clickhouse.example.test:8123"}}
MONGO = {"architecture": {"database": "mongodb"},
         "postgresql": {"enabled": False}, "mongodb": {"enabled": True}}
API_ONLY = {"ui": {"enabled": False}, "els": {"enabled": False}}


def merge(*items):
    result = {}
    for item in items:
        for key, value in item.items():
            if isinstance(value, dict) and isinstance(result.get(key), dict):
                result[key] = merge(result[key], value)
            else:
                result[key] = copy.deepcopy(value)
    return result


def cases():
    result = []

    def add(name, *values, endpoint=None, database="featbit", user="default",
            secret=None, password=None):
        result.append(dict(name=name, values=merge(COMMON, *values), endpoint=endpoint,
                           database=database, user=user, secret=secret,
                           password=password))

    bundled_secret = ("v6check-featbit-clickhouse", "admin-password")
    add("standard-postgres")
    add("standard-mongodb", MONGO)
    add("standard-postgres-api-only", API_ONLY)
    add("standard-mongodb-api-only", MONGO, API_ONLY)
    add("standard-ignores-clickhouse-provider", EXTERNAL,
        {"externalClickhouse": {"tcpPort": 9440, "cluster": "legacy", "altHosts": ["other:9000"], "verify": False}})
    add("standard-bundled-ignores-clickhouse-wait", BUNDLED)
    add("bundled-default", PRO, BUNDLED, endpoint="http://v6check-featbit-clickhouse:8123",
        secret=bundled_secret, password="featbit")
    add("bundled-api-only", PRO, BUNDLED, API_ONLY,
        endpoint="http://v6check-featbit-clickhouse:8123", secret=bundled_secret, password="featbit")
    add("bundled-mongodb", PRO, BUNDLED, MONGO,
        endpoint="http://v6check-featbit-clickhouse:8123", secret=bundled_secret, password="featbit")
    add("bundled-custom-database-user-inline", PRO, BUNDLED,
        {"clickhouse": {"database": "analytics-v6", "auth": {"username": "on", "password": INLINE_PASSWORD}}},
        endpoint="http://v6check-featbit-clickhouse:8123", database="analytics-v6", user="on",
        secret=bundled_secret, password=INLINE_PASSWORD)
    add("bundled-existing-secret", PRO, BUNDLED,
        {"clickhouse": {"auth": {"existingSecret": "precreated-clickhouse", "existingSecretKey": "pass-key", "password": INLINE_PASSWORD}}},
        endpoint="http://v6check-featbit-clickhouse:8123", secret=("precreated-clickhouse", "pass-key"))
    add("bundled-service-port-and-default-name", PRO, BUNDLED,
        {"clickhouse": {"nameOverride": "", "service": {"ports": {"http": 18123}}, "containerPorts": {"http": 28123}}},
        endpoint="http://v6check-clickhouse:18123", secret=("v6check-clickhouse", "admin-password"),
        password="featbit")
    add("bundled-fullname-override", PRO, BUNDLED, {"clickhouse": {"fullnameOverride": "custom-ch"}},
        endpoint="http://custom-ch:8123", secret=("custom-ch", "admin-password"), password="featbit")
    add("bundled-name-matches-release", PRO, BUNDLED, {"clickhouse": {"nameOverride": RELEASE}},
        endpoint="http://v6check:8123", secret=(RELEASE, "admin-password"), password="featbit")
    add("bundled-custom-name", PRO, BUNDLED,
        {"clickhouse": {"nameOverride": "named-ch", "auth": {"username": "query-reader", "password": INLINE_PASSWORD}}},
        endpoint="http://v6check-named-ch:8123", user="query-reader",
        secret=("v6check-named-ch", "admin-password"), password=INLINE_PASSWORD)
    add("bundled-no-kafka-wait", PRO, BUNDLED,
        {"kafka": {"enabled": False}, "externalKafka": {"brokers": {
            "producer": {"hosts": ["kafka.example.test:9092"]}, "consumer": {"hosts": ["kafka.example.test:9092"]}}}},
        endpoint="http://v6check-featbit-clickhouse:8123", secret=bundled_secret, password="featbit")
    add("bundled-http-naming-multiple-nodes", PRO, BUNDLED,
        {"clickhouse": {"fullnameOverride": "multi-ch", "service": {"ports": {"http": 18124}},
                        "containerPorts": {"http": 28124}, "shards": 2, "replicaCount": 3,
                        "auth": {"username": "query-reader", "existingSecret": "precreated-clickhouse", "existingSecretKey": "pass-key"}}},
        endpoint="http://multi-ch:18124", user="query-reader", secret=("precreated-clickhouse", "pass-key"))
    add("external-http-passwordless", PRO, EXTERNAL, endpoint="http://clickhouse.example.test:8123")
    add("external-http-inline", PRO, EXTERNAL, {"externalClickhouse": {"password": INLINE_PASSWORD}},
        endpoint="http://clickhouse.example.test:8123", secret=("v6check-featbit-clickhouse-external", "admin-password"), password=INLINE_PASSWORD)
    add("external-https-custom-database-secret", PRO,
        {"externalClickhouse": {"httpEndpoint": "https://clickhouse.example.test:8443/query", "database": "analytics-v6", "user": "on",
                                "existingSecret": "precreated-clickhouse", "existingSecretKey": "pass-key", "password": INLINE_PASSWORD}},
        endpoint="https://clickhouse.example.test:8443/query", database="analytics-v6", user="on", secret=("precreated-clickhouse", "pass-key"))
    add("external-https-inline-api-only", PRO, API_ONLY,
        {"externalClickhouse": {"httpEndpoint": "https://clickhouse.example.test:443", "database": "analytics-v6", "password": INLINE_PASSWORD}},
        endpoint="https://clickhouse.example.test:443", database="analytics-v6",
        secret=("v6check-featbit-clickhouse-external", "admin-password"), password=INLINE_PASSWORD)
    add("external-secret-api-only", PRO, EXTERNAL, API_ONLY,
        {"externalClickhouse": {"existingSecret": "precreated-clickhouse", "existingSecretKey": "pass-key"}},
        endpoint="http://clickhouse.example.test:8123", secret=("precreated-clickhouse", "pass-key"))
    add("external-yaml-like-secret-reference", PRO, EXTERNAL,
        {"externalClickhouse": {"existingSecret": "on", "existingSecretKey": "yes"}},
        endpoint="http://clickhouse.example.test:8123", secret=("on", "yes"))
    add("external-ignores-removed-values", PRO, EXTERNAL,
        {"externalClickhouse": {"host": "ignored.example.test", "httpPort": 9440, "secure": True,
                                "tcpPort": 9000, "altHosts": ["ignored:9000"], "cluster": "ignored", "verify": False,
                                "existingSecret": "precreated-clickhouse", "existingSecretKey": "pass-key"}},
        endpoint="http://clickhouse.example.test:8123", secret=("precreated-clickhouse", "pass-key"))
    add("external-infrastructure-and-dotnet-secrets", {"architecture": {"tier": "professional"}}, EXTERNAL,
        {"postgresql": {"enabled": False}, "redis": {"enabled": False},
         "externalPostgresql": {"hosts": ["db.example.test:5432"], "database": "business-v6", "username": "business",
                                "existingSecret": "test-db", "existingSecretPasswordKey": "db-pass"},
         "externalRedis": {"hosts": ["redis.example.test:6379"], "existingSecret": "test-redis", "existingSecretPasswordKey": "redis-pass"},
         "externalKafka": {"brokers": {
             "producer": {"hosts": ["producer.example.test:9093"], "user": "producer", "existingSecret": "test-kafka-producer", "existingSecretPasswordKey": "producer-pass", "protocol": "SASL_SSL", "mechanism": "PLAIN"},
             "consumer": {"hosts": ["consumer.example.test:9093"], "user": "consumer", "existingSecret": "test-kafka-consumer", "existingSecretPasswordKey": "consumer-pass", "protocol": "SASL_SSL", "mechanism": "SCRAM-SHA-512"}}},
         "externalClickhouse": {"existingSecret": "precreated-clickhouse", "existingSecretKey": "pass-key"}},
        endpoint="http://clickhouse.example.test:8123", secret=("precreated-clickhouse", "pass-key"))
    return result


def helm(operation, chart, values, case_name):
    # JSON is valid YAML. The private temporary file contains synthetic inputs only.
    with tempfile.TemporaryDirectory(prefix="featbit-clickhouse-check-") as directory:
        values_path = pathlib.Path(directory) / "values.yaml"
        values_path.write_text(json.dumps(values), encoding="utf-8")
        command = ["helm", operation]
        if operation == "template":
            command.append(RELEASE)
        command.extend([str(chart), "-f", str(values_path)])
        result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8")
    return result


def render(chart, case, lint=True):
    for operation in (["lint", "template"] if lint else ["template"]):
        result = helm(operation, chart, case["values"], case["name"])
        assert result.returncode == 0, f"{case['name']}: helm {operation} failed (output withheld)"
    return [doc for doc in yaml.safe_load_all(result.stdout) if doc]


def env_map(container):
    entries = container.get("env", [])
    names = [entry["name"] for entry in entries]
    assert len(names) == len(set(names)), "duplicate environment variable"
    for entry in entries:
        assert "value" not in entry or isinstance(entry["value"], str), "non-string environment value"
    return {entry["name"]: {key: value for key, value in entry.items() if key != "name"} for entry in entries}


def check(case, docs):
    text = json.dumps(docs).lower()
    assert "featbit-data-analytics-server" not in text and "olap__servicehost" not in text, "active DAS reference"
    deployments = {doc["metadata"]["labels"].get("app.kubernetes.io/component"): doc
                   for doc in docs if doc["kind"] == "Deployment"}
    expected = {"api"} if case["values"].get("ui", {}).get("enabled") is False else {"ui", "api", "els"}
    assert set(deployments) == expected, "unexpected application Deployments"
    services = {doc["metadata"]["name"] for doc in docs if doc["kind"] == "Service"}
    for component, deployment in deployments.items():
        assert deployment["metadata"]["name"] in services, "missing application Service"
        pod = deployment["spec"]["template"]["spec"]
        container = pod["containers"][0]
        assert "data-analytics" not in container["image"], "DAS image"
        assert container["image"].endswith(":5.4.10"), "application image changed"
        if component in {"api", "els"}:
            wait = pod["initContainers"][0]
            command = wait["command"][2]
            bundled = bool(case["endpoint"] and case["values"].get("clickhouse", {}).get("enabled"))
            assert ("clusterAllReplicas('featbit_ch_cluster'" in command) == bundled, "ClickHouse wait activation changed"
            if not bundled:
                assert not {"CLICKHOUSE_USER", "CLICKHOUSE_PASSWORD"}.intersection(env_map(wait)), "unused ClickHouse wait credentials"
            bundled_kafka = bool(case["endpoint"] and case["values"].get("kafka", {}).get("enabled"))
            assert ("waiting for Kafka" in command) == bundled_kafka, "Kafka wait activation changed"
            if bundled:
                address = re.search(r'CLICKHOUSE_HTTP_ENDPOINT="([^"]+)";', command)
                assert address and address[1] == case["endpoint"], "API and wait endpoints differ"
                assert '"$CLICKHOUSE_USER:$CLICKHOUSE_PASSWORD@' not in command, "credentials embedded in endpoint"
                assert '--header "Authorization: Basic $CLICKHOUSE_AUTH"' in command, "missing separate Basic auth"
                nodes = case["values"]["clickhouse"].get("shards", 1) * case["values"]["clickhouse"].get("replicaCount", 1)
                assert f'test "$NODES_COUNT" -eq {nodes}' in command, "cluster node-count check changed"
                assert case["endpoint"].startswith("http:"), "bundled wait must use HTTP"
                assert "wget -qO-" in command and "curl" not in command, "HTTP client changed"
                assert "--insecure" not in command and "--no-check-certificate" not in command, "TLS verification bypass"
        env = env_map(container)
        assert not any(name.startswith(("DB_PROVIDER", "POSTGRES_", "MONGO_", "KAFKA_", "CLICKHOUSE_")) for name in env), "DA environment variable"
        assert not any(name.startswith("ControlPlane") or name == "UseControlPlane" for name in env), "Control Plane enabled/configured"
        if component == "ui":
            assert env["API_URL"]["value"] == "https://api.example.test", "UI API URL"
            assert env["BASE_HREF"]["value"] == "/flags/", "UI passthrough"
            continue
        assert env["DbProvider"]["value"] == ("MongoDb" if case["values"].get("architecture", {}).get("database") == "mongodb" else "Postgres"), "business DbProvider changed"
        assert env["MqProvider"]["value"] == ("Kafka" if case["endpoint"] else "Redis"), "MqProvider mapping"
        assert env["CacheProvider"]["value"] == "Redis", "cache configuration"
        if component == "els" or not case["endpoint"]:
            assert not CLICKHOUSE_ENV.intersection(env), "unexpected ClickHouse provider block"
            continue
        assert CLICKHOUSE_ENV.issubset(env), "incomplete Professional API block"
        for name, expected_value in [("OLAPProvider", "ClickHouse"), ("ClickHouse__HttpEndpoint", case["endpoint"]),
                                     ("ClickHouse__Database", case["database"]), ("ClickHouse__User", case["user"])]:
            assert env[name] == {"value": expected_value}, f"incorrect {name}"
        password = env["ClickHouse__Password"]
        if case["secret"]:
            name, key = case["secret"]
            expected_ref = {"valueFrom": {"secretKeyRef": {"name": name, "key": key}}}
            assert password == expected_ref, "API ClickHouse Secret reference"
            secret_docs = [doc for doc in docs if doc["kind"] == "Secret" and doc["metadata"]["name"] == name]
            if case["password"] is not None:
                assert len(secret_docs) == 1, "missing/duplicate generated ClickHouse Secret"
                assert base64.b64decode(secret_docs[0]["data"][key]).decode() == case["password"], "generated password does not match input"
            else:
                assert not secret_docs, "existing ClickHouse Secret was recreated"
                assert not any(doc["kind"] == "Secret" and doc["metadata"]["name"].endswith("clickhouse-external") for doc in docs), "inline password overrode existing Secret"
        else:
            expected_ref = {"value": ""}
            assert password == expected_ref, "passwordless API references a Secret"
        for backend in [dep for key, dep in deployments.items() if key in {"api", "els"}]:
            wait = backend["spec"]["template"]["spec"]["initContainers"][0]
            wait_env = env_map(wait)
            if case["values"].get("clickhouse", {}).get("enabled"):
                assert wait_env["CLICKHOUSE_USER"] == {"value": case["user"]}, "wait user diverges from API"
                assert wait_env["CLICKHOUSE_PASSWORD"] == expected_ref, "wait credentials diverge from API"
                # The endpoint and Secret must target the real bundled Service/Secret.
                host = case["endpoint"].split("://", 1)[1].split(":", 1)[0]
                service = next(doc for doc in docs if doc["kind"] == "Service" and doc["metadata"]["name"] == host)
                scheme = case["endpoint"].split(":", 1)[0]
                service_port = next(port["port"] for port in service["spec"]["ports"] if port["name"] == scheme)
                assert case["endpoint"] == f"{scheme}://{host}:{service_port}", "endpoint misses the bundled Service port"
    if expected == {"api"}:
        assert "v6check-featbit-ui" not in services and "v6check-featbit-els" not in services, "api-only Services"


def compare_deployments(before, after):
    def index(docs):
        result = {}
        for doc in docs:
            if doc["kind"] not in {"Deployment", "Service"}:
                continue
            if doc["metadata"].get("labels", {}).get("app.kubernetes.io/component") not in {"ui", "api", "els"}:
                continue
            doc = copy.deepcopy(doc)
            if doc["kind"] == "Deployment":
                for container in doc["spec"]["template"]["spec"].get("initContainers", []):
                    if container["name"] == "wait-for-infrastructure-dependencies":
                        command = container["command"][2]
                        if "clusterAllReplicas('featbit_ch_cluster'" not in command and "env" in container:
                            # Older charts injected unused credentials for external ClickHouse.
                            container["env"] = [entry for entry in container["env"]
                                                if entry["name"] not in {"CLICKHOUSE_USER", "CLICKHOUSE_PASSWORD"}]
                            if not container["env"]:
                                del container["env"]
                        # Only the final ClickHouse request/check block is intended to change.
                        marker = re.search(r"CLICKHOUSE_HTTP_ENDPOINT=|until \(\s*NODES_COUNT=", command)
                        if marker:
                            assert "clusterAllReplicas('featbit_ch_cluster'" in command[marker.start():], "unexpected wait block"
                            assert re.search(r'echo "waiting for all ClickHouse nodes to be available"; sleep 1;\s*done\s*$', command), "unexpected wait suffix"
                            command = command[:marker.start()]
                        container["command"][2] = command.rstrip()
            result[(doc["kind"], doc["metadata"]["name"])] = doc
        return result
    assert index(before) == index(after), "UI/API/ELS configuration changed beyond the ClickHouse wait command/unused credentials"


def check_wait_shell(shell, case, docs, *, wrong_nodes=False, failed_request=False):
    """Execute only the rendered ClickHouse block against mock wget, never a database."""
    api = next(doc for doc in docs if doc["kind"] == "Deployment" and doc["metadata"]["labels"].get("app.kubernetes.io/component") == "api")
    command = api["spec"]["template"]["spec"]["initContainers"][0]["command"][2]
    command = command[command.index("CLICKHOUSE_HTTP_ENDPOINT="):]
    nodes = case["values"]["clickhouse"].get("shards", 1) * case["values"]["clickhouse"].get("replicaCount", 1)
    env = os.environ.copy()
    env.update({
        "CLICKHOUSE_USER": case["user"], "CLICKHOUSE_PASSWORD": INLINE_PASSWORD,
        "V6_TEST_ENDPOINT": case["endpoint"],
        "V6_TEST_AUTH": "Authorization: Basic " + base64.b64encode(f"{case['user']}:{INLINE_PASSWORD}".encode()).decode(),
        "V6_TEST_QUERY": "SELECT count() FROM clusterAllReplicas('featbit_ch_cluster', system, one)",
        "V6_TEST_NODES": str(nodes + 1 if wrong_nodes else nodes),
        "V6_TEST_STATUS": "1" if failed_request else "0",
    })
    mocks = r'''
wget() {
    [ "$#" = 6 ] && [ "$1" = -qO- ] && [ "$2" = "$V6_TEST_ENDPOINT" ] &&
    [ "$3" = --header ] && [ "$4" = "$V6_TEST_AUTH" ] &&
    [ "$5" = --post-data ] && [ "$6" = "$V6_TEST_QUERY" ] || exit 93
    printf 'called' > "$V6_TEST_CALL_FILE"
    printf '%s\n' "$V6_TEST_NODES"
    return "$V6_TEST_STATUS"
}
sleep() { exit 77; }
'''
    with tempfile.TemporaryDirectory(prefix="featbit-clickhouse-shell-") as directory:
        called = pathlib.Path(directory) / "called"
        env["V6_TEST_CALL_FILE"] = called.as_posix()
        result = subprocess.run([str(shell), "-c", mocks + command], env=env,
                                capture_output=True, text=True, encoding="utf-8", timeout=10)
        expected_status = 77 if wrong_nodes or failed_request else 0
        assert result.returncode == expected_status, "mocked wait returned an unexpected status (output withheld)"
        assert called.exists(), "wait did not use wget"


def check_helper_removal(chart):
    external = yaml.safe_load((chart / "values.yaml").read_text(encoding="utf-8"))["externalClickhouse"]
    assert not {"host", "httpPort", "secure", "tcpPort", "altHosts", "cluster", "verify"}.intersection(external), "removed values restored"
    templates = "\n".join(path.read_text(encoding="utf-8") for path in (chart / "templates").rglob("*") if path.is_file())
    assert not re.search(r'featbit\.clickhouse\.(host|httpPort|port|altHosts)"', templates), "removed address helper still has a caller"
    assert not re.search(r'\.Values\.externalClickhouse\.(host|httpPort|secure)\b', templates), "legacy endpoint fallback remains"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-chart", type=pathlib.Path)
    parser.add_argument("--shell", type=pathlib.Path)
    args = parser.parse_args()
    chart = ROOT / "charts" / "featbit"
    comparisons = 0
    check_helper_removal(chart)
    shell = args.shell or shutil.which("sh")
    if not shell and os.name == "nt":
        shell = pathlib.Path("C:/Program Files/Git/bin/bash.exe")
    assert shell and pathlib.Path(shell).is_file(), "a POSIX shell is required for mocked wait checks"
    rendered = {}
    positive_cases = cases()
    for case in positive_cases:
        docs = render(chart, case)
        check(case, docs)
        if args.baseline_chart:
            compare_deployments(render(args.baseline_chart, case, lint=False), docs)
            comparisons += 1
        rendered[case["name"]] = docs
        print(f"PASS {case['name']}: lint, template and parsed manifests", flush=True)
    invalid_cases = [
        ("missing-external-endpoint", {}, "externalClickhouse.httpEndpoint is required"),
        ("empty-external-endpoint", {"externalClickhouse": {"httpEndpoint": ""}}, "externalClickhouse.httpEndpoint is required"),
        ("legacy-http-only", {"externalClickhouse": {"host": "legacy.example.test", "httpPort": 18123}}, "migrate legacy host/httpPort/secure"),
        ("legacy-https-only", {"externalClickhouse": {"host": "legacy.example.test", "httpPort": 8443, "secure": True,
            "tcpPort": 9440, "altHosts": ["ignored:9000"], "cluster": "legacy", "verify": False}}, "migrate legacy host/httpPort/secure"),
        ("native-tcp-endpoint", {"externalClickhouse": {"httpEndpoint": "tcp://clickhouse.example.test:9000"}}, "HTTP(S)"),
        ("endpoint-with-credentials", {"externalClickhouse": {"httpEndpoint": "https://test:synthetic@clickhouse.example.test"}}, "without credentials"),
        ("endpoint-with-query", {"externalClickhouse": {"httpEndpoint": "https://clickhouse.example.test/?database=other"}}, "HTTP(S)"),
        ("endpoint-with-fragment", {"externalClickhouse": {"httpEndpoint": "https://clickhouse.example.test/#query"}}, "HTTP(S)"),
        ("endpoint-without-host", {"externalClickhouse": {"httpEndpoint": "https:///"}}, "HTTP(S)"),
        ("external-secret-without-key", merge(EXTERNAL, {"externalClickhouse": {"existingSecret": "precreated-clickhouse"}}), "externalClickhouse.existingSecretKey"),
        ("bundled-secret-without-key", merge(BUNDLED, {"clickhouse": {"auth": {"existingSecret": "precreated-clickhouse"}}}), "clickhouse.auth.existingSecretKey"),
        ("bundled-tls-unsupported", merge(BUNDLED, TLS), "Bundled ClickHouse startup wait supports HTTP only"),
        ("bundled-tls-api-only-unsupported", merge(BUNDLED, TLS, API_ONLY), "Bundled ClickHouse startup wait supports HTTP only"),
    ]
    for name, override, expected_error in invalid_cases:
        values = merge(COMMON, PRO, override)
        # Helm lint suppresses required/fail errors in its template engine.
        # Helm template is the authoritative rejection check for invalid values.
        result = helm("template", chart, values, name)
        assert result.returncode != 0 and expected_error in result.stdout + result.stderr, f"{name}: expected validation failure"
        print(f"PASS {name}: expected validation rejection", flush=True)
    shell_cases = [
        ("http-special-characters", "bundled-custom-name", {}),
        ("http-special-characters-multiple-nodes", "bundled-http-naming-multiple-nodes", {}),
        ("http-wrong-node-count", "bundled-http-naming-multiple-nodes", {"wrong_nodes": True}),
        ("http-failed-request", "bundled-custom-name", {"failed_request": True}),
    ]
    for name, case_name, options in shell_cases:
        case = next(case for case in positive_cases if case["name"] == case_name)
        check_wait_shell(shell, case, rendered[case_name], **options)
        print(f"PASS {name}: mocked startup wait", flush=True)
    print(f"PASS {len(positive_cases)} positive cases, {len(invalid_cases)} validation cases, {len(shell_cases)} mocked wait cases; {comparisons} baseline comparisons.")
    print("Offline rendering only; no v6 runtime, schema, topic or ACL verification.")


if __name__ == "__main__":
    main()
