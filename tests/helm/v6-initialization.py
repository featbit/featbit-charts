#!/usr/bin/env python3
"""Offline v6 initialization checks; no database, broker or cluster is contacted.

Run: python tests/helm/v6-initialization.py --shell PATH_TO_BASH
"""
import argparse
import hashlib
import importlib.util
import json
import os
import pathlib
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
CHART = ROOT / "charts/featbit"
spec = importlib.util.spec_from_file_location("api_checks", ROOT / "tests/helm/clickhouse-api-env.py")
api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api)
TOPICS = {"featbit-feature-flag-change", "featbit-segment-change", "featbit-endusers",
          "featbit-insights", "featbit-usage", "featbit-control-plane-web-hooks", "healthchecks-topic"}
PINS = {
    "postgresql-v6.0.0.sql": "13d8149cb2795ebe74de1ba95da3311e55fd07766b9896a0b3522ec29d898671",
    "mongodb-v6.0.0.js": "48a29602d5584dbab7823cb936fe8a08e82252c9729335cad89740cb109df18b",
    "clickhouse-v6.0.0.sql": "e954632f707bfc2f65369bd8090a69e6849aa01d15d8e301b934489d4506d392",
}


def check(docs, values, shell):
    index = {(d["kind"], d["metadata"]["name"]): d for d in docs}
    for database, filename, expected in [
        ("postgresql", "12_v6.0.0.sql", values.get("postgresql", {}).get("auth", {}).get("database", "featbit")),
        ("mongodb", "11_v6.0.0.js", values.get("mongodb", {}).get("userDatabase", {}).get("name", "featbit")),
    ]:
        config = index.get(("ConfigMap", f"featbit-{database}-init-scripts-configmap"))
        if values.get(database, {}).get("enabled") is False:
            assert config is None, "external business database must not have init resources"
        if not config:
            continue
        scripts = config["data"]
        assert sorted(scripts)[-1] == filename, "v6 must follow existing initialization scripts"
        assert expected in scripts[filename], "configured business database missing"
        assert any(v.get("configMap", {}).get("name") == config["metadata"]["name"]
                   for d in docs if d["kind"] == "StatefulSet"
                   for v in d["spec"]["template"]["spec"].get("volumes", [])), "missing init ConfigMap mount"
        if database == "mongodb":
            with tempfile.TemporaryDirectory() as tmp:
                for name, script in scripts.items():
                    path = pathlib.Path(tmp) / name
                    path.write_text(script, encoding="utf-8", newline="\n")
                    result = subprocess.run(["node", "--check", str(path)], capture_output=True)
                    assert result.returncode == 0, f"JavaScript syntax: {name}"
    jobs = [d for d in docs if d["kind"] == "Job" and d["metadata"].get("labels", {}).get("app.kubernetes.io/component") == "kafka-provisioning"]
    if values.get("kafka", {}).get("enabled"):
        assert len(jobs) == 1, "retain the single dependency provisioning Job"
        job = jobs[0]
        assert job["metadata"]["annotations"]["helm.sh/hook"] == "post-install,post-upgrade"
        command = json.dumps(job["spec"]["template"]["spec"]["containers"][0])
        assert all(topic in command for topic in TOPICS), "missing required topic"
    else:
        assert not jobs, "external Kafka must not be provisioned"
    secrets = [d for d in docs if d["kind"] == "Secret" and d["metadata"]["name"].endswith("-featbit-initdb")]
    custom = values.get("clickhouse", {}).get("initdbScriptsSecret")
    if custom is not None:
        assert not secrets, "custom/empty Secret must override managed initialization"
        return None
    if not values.get("clickhouse", {}).get("enabled"):
        assert not secrets, "external ClickHouse must not have initialization resources"
        return None
    assert len(secrets) == 1
    secret = secrets[0]
    scripts = secret["stringData"]
    if values.get("architecture", {}).get("tier") != "professional":
        assert not scripts, "Standard must not initialize the Professional schema"
        return None
    script = scripts["20_featbit-v6.sh"]
    name = secret["metadata"]["name"]
    pods = [d["spec"]["template"]["spec"] for d in docs if d["kind"] == "StatefulSet"]
    assert any(v.get("secret", {}).get("secretName") == name for pod in pods for v in pod.get("volumes", []))
    assert any(m["mountPath"] == "/docker-entrypoint-initdb.d" for pod in pods
               for c in pod["containers"] for m in c.get("volumeMounts", []))
    database = values.get("clickhouse", {}).get("database", "featbit")
    assert f"CREATE DATABASE IF NOT EXISTS `{database}`;" in script
    if values.get("kafka", {}).get("enabled"):
        broker = next(d for d in docs if d["kind"] == "Service" and
                      any(p.get("name") == "tcp-client" for p in d["spec"]["ports"]) and
                      not d["metadata"]["name"].endswith("headless"))
        port = next(p["port"] for p in broker["spec"]["ports"] if p["name"] == "tcp-client")
        assert f"kafka_broker_list = '{broker['metadata']['name']}:{port}'" in script
    else:
        hosts = values["externalKafka"]["brokers"]["consumer"]["hosts"]
        assert f"kafka_broker_list = '{','.join(hosts)}'" in script
    assert script.count("CREATE TABLE IF NOT EXISTS") == 3
    assert script.count("CREATE MATERIALIZED VIEW IF NOT EXISTS") == 2
    assert "kafka_group_name = 'ch_group'" in script
    assert "${CLICKHOUSE_ADMIN_PASSWORD:-}" in script and "${CLICKHOUSE_TCP_PORT:-9000}" in script
    assert not any("helm.sh/hook" in d["metadata"].get("annotations", {}) for d in secrets)
    with tempfile.TemporaryDirectory() as tmp:
        path = pathlib.Path(tmp) / "init.sh"
        path.write_text(script, encoding="utf-8", newline="\n")
        result = subprocess.run([str(shell), "-n", str(path)], capture_output=True)
        assert result.returncode == 0, f"Bash syntax status {result.returncode}: {result.stderr.decode(errors='replace')}"
    if values.get("clickhouse", {}).get("initdbScripts"):
        assert sorted(scripts) == ["20_featbit-v6.sh", "30_custom.sh"]
        assert scripts["30_custom.sh"] == "echo v6check\n"
    return script


def check_guard(script, shell):
    prefix = r"""clickhouse-client() {
  if [[ "$*" == *--multiquery* ]]; then
    cat > "$V6_CAPTURE"
    return "$V6_DDL_STATUS"
  fi
  printf '%s\n' "$V6_EXISTING"
}
"""
    for existing, ddl_status, expected in [(0, 0, 0), (1, 0, 1), (0, 7, 7)]:
        with tempfile.TemporaryDirectory(prefix="featbit-v6-mock-") as tmp:
            path = pathlib.Path(tmp) / "check.sh"
            capture = pathlib.Path(tmp) / "captured.sql"
            path.write_text(prefix + script, encoding="utf-8", newline="\n")
            env = dict(os.environ, V6_EXISTING=str(existing), V6_DDL_STATUS=str(ddl_status), V6_CAPTURE=capture.as_posix())
            result = subprocess.run([str(shell), str(path)], env=env, capture_output=True)
            assert result.returncode == expected, "first-boot guard or error propagation failed"
            assert capture.exists() == (existing == 0), "nonempty database received SQL"
            if capture.exists():
                assert "CREATE MATERIALIZED VIEW" in capture.read_text(encoding="utf-8")
    print("PASS 3 mocked initializer cases: fresh, nonempty, SQL failure (no real client)")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shell", type=pathlib.Path)
    args = parser.parse_args()
    shell = args.shell or shutil.which("bash")
    assert shell, "Bash is required"
    for name, digest in PINS.items():
        source = (CHART / "files/featbit-v6" / name).read_text(encoding="utf-8")
        assert hashlib.sha256(source.encode("utf-8")).hexdigest() == digest
    pro = api.merge(api.PRO, api.BUNDLED)
    external_kafka = {"kafka": {"enabled": False}, "externalKafka": {"brokers": {
        "producer": {"hosts": ["broker.example.test:19092"]},
        "consumer": {"hosts": ["broker.example.test:19092"]}}}}
    cases = [
        ("standard-postgres-custom-db", {"postgresql": {"auth": {"database": "business_v6"}}}),
        ("standard-mongo-custom-db", api.merge(api.MONGO, {"mongodb": {"userDatabase": {"name": "mongo_v6"}}})),
        ("standard-clickhouse-unused", api.BUNDLED),
        ("pro-default", pro),
        ("pro-custom-db-broker-port", api.merge(pro, {"clickhouse": {"database": "analytics-v6"}, "kafka": {"fullnameOverride": "trial-broker", "service": {"ports": {"client": 19092}}}})),
        ("pro-api-only-existing-secret", api.merge(pro, api.API_ONLY, {"clickhouse": {"auth": {"existingSecret": "precreated-ch", "existingSecretKey": "password"}}})),
        ("pro-external-kafka", api.merge(pro, external_kafka)),
        ("pro-all-external", next(c["values"] for c in api.cases() if c["name"] == "external-infrastructure-and-dotnet-secrets")),
        ("custom-script-order", api.merge(pro, {"clickhouse": {"initdbScripts": {"30_custom.sh": "echo {{ .Release.Name }}\n"}}})),
        ("custom-secret", api.merge(pro, {"clickhouse": {"initdbScriptsSecret": "my-init"}})),
        ("custom-auth-secret", api.merge(pro, {"clickhouse": {"initdbScriptsSecret": "my-init"},
                                               "kafka": {"listeners": {"client": {"protocol": "SASL_PLAINTEXT"}}}})),
        ("inline-scripts-optout", api.merge(pro, {"clickhouse": {"initdbScriptsSecret": "", "initdbScripts": {"30_custom.sh": "echo custom"}}})),
    ]
    fresh_script = None
    for name, values in cases:
        docs = api.render(CHART, {"name": name, "values": api.merge(api.COMMON, values)})
        script = check(docs, values, shell)
        if name == "pro-all-external":
            assert not any(d["kind"] == "StatefulSet" for d in docs), "external services were deployed"
        if name == "pro-default":
            fresh_script = script
        print(f"PASS {name}: lint, template, initialization resources/order and syntax", flush=True)
    for name, override, diagnostic in [
        ("reserved-script", {"initdbScripts": {"20_featbit-v6.sh": "echo collision"}}, "reserved"),
        ("custom-auth-needs-script", {}, "custom Kafka authentication"),
    ]:
        values = api.merge(pro, {"clickhouse": override})
        if name == "custom-auth-needs-script":
            values = api.merge(values, {"kafka": {"listeners": {"client": {"protocol": "SASL_PLAINTEXT"}}}})
        result = api.helm("template", CHART, values, name)
        assert result.returncode != 0 and diagnostic in result.stdout + result.stderr
    check_guard(fresh_script, shell)
    print(f"PASS {len(cases)} initialization cases, 2 expected rejections, 3 pinned source hashes")
    print("Offline only; actual image startup, SQL execution, topics and ingestion remain unverified.")


if __name__ == "__main__":
    main()
