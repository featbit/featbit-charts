#!/usr/bin/env python3
"""Prepare files locally; never invoke a registry, Helm or Kubernetes client."""

import argparse
from copy import deepcopy
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

import yaml


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
NAME = "els-readiness-probe"
CONNECTION_KEYS = ("Postgres__ConnectionString", "Redis__ConnectionString")
PASSWORD_KEYS = ("Postgres__Password", "Redis__Password")
EXTRA_KEYS = ("Redis__ConnectTimeoutMs", "Redis__SyncTimeoutMs")


class PreparationError(Exception):
    pass


def read_yaml(path):
    try:
        value = yaml.safe_load(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, yaml.YAMLError):
        # YAML parser errors can quote the line containing a password.
        raise PreparationError(f"Cannot read a YAML mapping from {path}; details withheld.") from None
    if not isinstance(value, dict):
        raise PreparationError(f"Expected a YAML mapping in {path}.")
    return value


def merge_maps(base, override):
    result = deepcopy(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merge_maps(result[key], value)
        else:
            result[key] = deepcopy(value)
    return result


def required_text(value, field):
    if not isinstance(value, str) or not value.strip():
        raise PreparationError(f"A non-empty string is required for {field}.")
    return value


def validate_dns_name(value, field):
    value = required_text(value, field)
    if len(value) > 253 or not re.fullmatch(r"[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?", value):
        raise PreparationError(f"Invalid Kubernetes name in {field}.")
    if any(len(part) > 63 or not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]*[a-z0-9])?", part)
           for part in value.split(".")):
        raise PreparationError(f"Invalid Kubernetes name in {field}.")
    return value


def secret_reference(name, key, field):
    name = validate_dns_name(name, field + ".name")
    key = required_text(key, field + ".key")
    if not re.fullmatch(r"[A-Za-z0-9._-]+", key):
        raise PreparationError(f"Invalid Secret key in {field}.")
    return {"secretKeyRef": {"name": name, "key": key}}


def endpoint_pairs(section, field, default_port):
    hosts = section.get("hosts")
    if not isinstance(hosts, list) or not hosts:
        raise PreparationError(f"{field}.hosts must contain at least one endpoint.")
    pairs = []
    for endpoint in hosts:
        if not isinstance(endpoint, str) or not re.fullmatch(r"[A-Za-z0-9_.-]+(?::[0-9]+)?", endpoint):
            raise PreparationError(f"Unsupported endpoint syntax in {field}.hosts; no values were printed.")
        parts = endpoint.split(":")
        port = parts[1] if len(parts) == 2 else str(default_port)
        if not 1 <= int(port) <= 65535:
            raise PreparationError(f"Invalid port in {field}.hosts.")
        pairs.append((parts[0], port, endpoint))
    return pairs


def base_connections(values):
    if values.get("postgresql", {}).get("enabled") is not False or values.get("redis", {}).get("enabled") is not False:
        raise PreparationError("This helper supports external PostgreSQL and Redis only; it creates no infrastructure.")
    if values.get("architecture", {}).get("database", "postgres").lower() not in ("postgres", "postgresql"):
        raise PreparationError("The reference values must select PostgreSQL.")
    pg = values.get("externalPostgresql", {})
    redis = values.get("externalRedis", {})
    pg_hosts = endpoint_pairs(pg, "externalPostgresql", 5432)
    pg_string = "Host={};Port={};Username={};Database={}".format(
        ",".join(item[0] for item in pg_hosts), ",".join(item[1] for item in pg_hosts),
        required_text(pg.get("username"), "externalPostgresql.username"), pg.get("database") or "featbit")
    if pg.get("extraParams"):
        pg_string += ";" + required_text(pg["extraParams"], "externalPostgresql.extraParams")

    redis_hosts = endpoint_pairs(redis, "externalRedis", 6379)
    cluster = redis.get("cluster", {}).get("enabled", False)
    sentinel = redis.get("sentinel", {}).get("enabled", False)
    if cluster and sentinel:
        raise PreparationError("Redis cluster and sentinel cannot both be selected.")
    redis_string = (",".join(item[2] for item in redis_hosts) if cluster or sentinel
                    else f"{redis_hosts[0][0]}:{redis_hosts[0][1]}")
    if sentinel:
        redis_string += ",serviceName=" + required_text(redis["sentinel"].get("masterSet"), "externalRedis.sentinel.masterSet")
    if not cluster:
        redis_string += f",defaultDatabase={int(redis.get('db', 0))}"
    redis_string += ",abortConnect=false,ssl=" + str(bool(redis.get("ssl", False))).lower()
    if redis.get("user"):
        redis_string += ",user=" + redis["user"]
    return {CONNECTION_KEYS[0]: pg_string, CONNECTION_KEYS[1]: redis_string}


def dependency_environment(values):
    # Reproduce the external-connection fields of _postgresql-config.tpl and
    # _redis-config.tpl without using Helm for preparing or deploying the probe.
    connections = base_connections(values)
    overrides = {}
    for entry in values.get("els", {}).get("env", []) or []:
        name = entry.get("name")
        if name not in CONNECTION_KEYS + PASSWORD_KEYS + EXTRA_KEYS:
            continue
        if name in overrides:
            raise PreparationError(f"Duplicate ELS dependency environment name: {name}.")
        overrides[name] = deepcopy(entry)

    result = []
    for name in CONNECTION_KEYS:
        entry = overrides.get(name, {"name": name, "value": connections[name]})
        if "valueFrom" in entry:
            source = entry["valueFrom"]
            if set(source) != {"secretKeyRef"}:
                raise PreparationError(f"{name} must be literal or use an existing Secret reference.")
            ref = source["secretKeyRef"]
            entry = {"name": name, "valueFrom": secret_reference(ref.get("name"), ref.get("key"), name)}
        else:
            text = required_text(entry.get("value"), name)
            if re.search(r"(?:^|[;,])\s*(?:password|pwd|passfile)\s*=|\$\(", text, re.IGNORECASE):
                raise PreparationError(f"{name} must not embed credentials or environment expansion; use the separate Secret reference.")
            entry = {"name": name, "value": text}
        result.append(entry)

    for name, section in zip(PASSWORD_KEYS, ("externalPostgresql", "externalRedis")):
        if name in overrides:
            source = overrides[name].get("valueFrom", {})
            if set(source) != {"secretKeyRef"}:
                raise PreparationError(f"{name} must use an existing Secret reference; literal passwords are not copied.")
            ref = source["secretKeyRef"]
            reference = secret_reference(ref.get("name"), ref.get("key"), name)
        else:
            config = values.get(section, {})
            reference = secret_reference(config.get("existingSecret"), config.get("existingSecretPasswordKey"), section)
        result.append({"name": name, "valueFrom": reference})

    for name in EXTRA_KEYS:
        if name in overrides:
            text = required_text(overrides[name].get("value"), name)
            if not text.isdecimal() or int(text) <= 0:
                raise PreparationError(f"{name} must be a positive integer string.")
            result.append({"name": name, "value": text})
    return result


def render_manifests(values, image, namespace, mode="background", interval=30):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:/@-]*", image) or (":" not in image.rsplit("/", 1)[-1] and "@sha256:" not in image):
        raise PreparationError("Supply an explicit image tag or digest, without a URL scheme.")
    validate_dns_name(namespace, "namespace")
    if "." in namespace or len(namespace) > 63:
        raise PreparationError("Namespace must be a DNS label.")
    if mode not in ("background", "kubelet") or not 1 <= interval <= 3600:
        raise PreparationError("Invalid sampling mode or interval.")
    deployment = read_yaml(HERE / "deployment.template.yaml")
    service = read_yaml(HERE / "service.yaml")
    for document in (deployment, service):
        document["metadata"]["namespace"] = namespace
    container = deployment["spec"]["template"]["spec"]["containers"][0]
    container["image"] = image
    container["env"] = dependency_environment(values) + [
        {"name": "Probe__Enabled", "value": str(mode == "background").lower()},
        {"name": "Probe__IntervalSeconds", "value": str(interval)},
        {"name": "Probe__RecentFailureLimit", "value": "100"},
    ]
    if mode == "kubelet":
        container["readinessProbe"]["httpGet"]["path"] = "/health/readiness"
        container["readinessProbe"]["periodSeconds"] = interval
        # Avoid blindly inheriting ELS's 5-second HTTP timeout. Verify against
        # the actual connection/command timeouts before a kubelet-mode experiment.
        container["readinessProbe"]["timeoutSeconds"] = 60
    return [deployment, service]


def public_build_files(project):
    app = project / "src" / "Els.ReadinessProbe"
    try:
        settings = json.loads((app / "appsettings.json").read_text(encoding="utf-8-sig"))
        if any(settings.get(section, {}).get(key) for section in ("Postgres", "Redis")
               for key in ("ConnectionString", "Password")):
            raise PreparationError("Source appsettings.json must retain empty dependency credentials; use runtime configuration.")
        config = ET.parse(project / "NuGet.Config").getroot()
        if config.tag != "configuration" or any(child.tag != "packageSources" for child in config):
            raise PreparationError("Only public nuget.org package sources are supported in the build context; credentials are not copied.")
        for source in config.findall("packageSources/*"):
            if source.tag not in ("clear", "add") or (source.tag == "add" and (
                source.get("value") != "https://api.nuget.org/v3/index.json"
                or set(source.attrib) - {"key", "value", "protocolVersion"}
            )):
                raise PreparationError("Only the public nuget.org feed is supported in the build context.")
        paths = [project / "global.json", project / "NuGet.Config",
                 app / "Els.ReadinessProbe.csproj", app / "appsettings.json"]
        paths += [path for path in app.rglob("*.cs") if not {"bin", "obj"}.intersection(path.relative_to(app).parts)]
        files = {}
        for path in paths:
            path.resolve().relative_to(project.resolve())
            files[path.relative_to(project)] = path.read_bytes()
        files[Path("Dockerfile")] = (HERE / "Dockerfile").read_bytes()
        files[Path(".dockerignore")] = (HERE / ".dockerignore").read_bytes()
        # Normalize this public configuration rather than copying comments or
        # unrelated attributes from a locally edited NuGet.Config.
        files[Path("NuGet.Config")] = (
            '<?xml version="1.0" encoding="utf-8"?>\n<configuration><packageSources><clear />'
            '<add key="nuget.org" value="https://api.nuget.org/v3/index.json" />'
            '</packageSources></configuration>\n').encode("utf-8")
        return files
    except PreparationError:
        raise
    except (OSError, ValueError, ET.ParseError):
        raise PreparationError("Cannot prepare the source allowlist; source contents were not printed.") from None


def prepare(values_file, defaults_file, project, output, image, namespace, mode, interval):
    values = merge_maps(read_yaml(defaults_file), read_yaml(values_file))
    documents = render_manifests(values, image, namespace, mode, interval)
    files = public_build_files(project)
    output = output.resolve()
    if output.exists():
        raise PreparationError("Output directory already exists; choose a fresh directory to avoid stale build files.")
    # Prevent generated files from overwriting source/input directories.
    inputs = (values_file.resolve(), defaults_file.resolve(), project.resolve(), HERE)
    if any(output == item or output in item.parents for item in inputs):
        raise PreparationError("Output must not replace a source/input directory.")
    if project.resolve() in output.parents or (ROOT / "charts") in output.parents:
        raise PreparationError("Output must stay outside the application source and FeatBit charts directories.")
    context = output / "build-context"
    context.mkdir(parents=True)
    for relative, content in files.items():
        destination = context / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(content)
    manifest = output / "deployment.local.yaml"
    manifest.write_text(yaml.safe_dump_all(documents, sort_keys=False, allow_unicode=True), encoding="utf-8")
    return {"outputDirectory": str(output), "buildContext": str(context), "manifest": str(manifest),
            "image": image, "namespace": namespace, "samplingMode": mode}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", required=True)
    parser.add_argument("--values", type=Path, default=ROOT / "charts/featbit/examples/aks/featbit-aks-values.local.yaml")
    parser.add_argument("--defaults", type=Path, default=ROOT / "charts/featbit/values.yaml")
    parser.add_argument("--project-directory", type=Path, default=HERE.parent / "els-readiness-probe")
    parser.add_argument("--namespace", default="featbit")
    parser.add_argument("--sampling-mode", choices=("background", "kubelet"), default="background")
    parser.add_argument("--interval-seconds", type=int, default=30)
    parser.add_argument("--output", type=Path, default=HERE / ".generated" /
                        datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
    args = parser.parse_args()
    try:
        result = prepare(args.values, args.defaults, args.project_directory, args.output,
                         args.image, args.namespace, args.sampling_mode, args.interval_seconds)
    except (PreparationError, OSError, TypeError, ValueError, KeyError, AttributeError):
        # Do not print parser errors or malformed user values containing secrets.
        # Known preparation errors carry field names only; preserve those hints.
        error = sys.exc_info()[1]
        message = str(error) if isinstance(error, PreparationError) else "Invalid input structure or output path; details withheld."
        parser.exit(1, f"Preparation failed: {message}\n")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
