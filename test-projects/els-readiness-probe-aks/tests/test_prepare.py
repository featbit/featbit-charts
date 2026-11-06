import importlib.util
from contextlib import contextmanager
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import yaml


HERE = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("probe_aks_prepare", HERE / "prepare.py")
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


def reference_values():
    return {
        "architecture": {"database": "postgres"},
        "postgresql": {"enabled": False}, "redis": {"enabled": False},
        "externalPostgresql": {
            "hosts": ["pg.example.invalid:5432"], "username": "probe-user", "database": "featbit",
            "existingSecret": "shared-pg-secret", "existingSecretPasswordKey": "pg-password",
            "password": "PG-SECRET-CANARY",
            "extraParams": "SSL Mode=VerifyFull;Application Name=Probe: test #1"
        },
        "externalRedis": {
            "hosts": ["redis.example.invalid:6380"], "db": 0, "ssl": True,
            "existingSecret": "shared-redis-secret", "existingSecretPasswordKey": "redis-password",
            "password": "REDIS-SECRET-CANARY"
        },
        "els": {"env": [{"name": "UNRELATED_SECRET", "value": "OTHER-SECRET-CANARY"}]}
    }


class PreparationTests(unittest.TestCase):
    def render(self, values=None, mode="background"):
        return prepare.render_manifests(values or reference_values(),
                                        "example.azurecr.io/els-readiness-probe:test", "featbit", mode)

    def test_only_independent_deployment_and_service_are_created(self):
        documents = self.render()
        self.assertEqual([doc["kind"] for doc in documents], ["Deployment", "Service"])
        deployment, service = documents
        for doc in documents:
            self.assertEqual(doc["metadata"]["name"], "els-readiness-probe")
            self.assertEqual(doc["metadata"]["namespace"], "featbit")
            self.assertNotIn("annotations", doc["metadata"])
        pod = deployment["spec"]["template"]
        self.assertEqual(service["spec"]["selector"], pod["metadata"]["labels"])
        self.assertEqual(deployment["spec"]["selector"]["matchLabels"], pod["metadata"]["labels"])
        self.assertNotIn("featbit", pod["metadata"]["labels"].values())
        self.assertEqual(service["spec"]["type"], "ClusterIP")
        self.assertEqual(deployment["spec"]["replicas"], 1)
        self.assertEqual(deployment["spec"]["strategy"]["type"], "Recreate")
        self.assertFalse(pod["spec"]["automountServiceAccountToken"])

    def test_secret_references_and_exact_connection_strings_are_preserved(self):
        documents = self.render()
        env = {entry["name"]: entry for entry in documents[0]["spec"]["template"]["spec"]["containers"][0]["env"]}
        self.assertEqual(env["Postgres__Password"]["valueFrom"]["secretKeyRef"],
                         {"name": "shared-pg-secret", "key": "pg-password"})
        self.assertEqual(env["Redis__Password"]["valueFrom"]["secretKeyRef"],
                         {"name": "shared-redis-secret", "key": "redis-password"})
        self.assertEqual(env["Postgres__ConnectionString"]["value"],
                         "Host=pg.example.invalid;Port=5432;Username=probe-user;Database=featbit;"
                         "SSL Mode=VerifyFull;Application Name=Probe: test #1")
        self.assertEqual(env["Redis__ConnectionString"]["value"],
                         "redis.example.invalid:6380,defaultDatabase=0,abortConnect=false,ssl=true")
        serialized = yaml.safe_dump_all(documents)
        self.assertNotIn("SECRET-CANARY", serialized)
        self.assertEqual(list(yaml.safe_load_all(serialized)), documents)

    def test_background_mode_does_not_double_sample_via_kubelet(self):
        container = self.render()[0]["spec"]["template"]["spec"]["containers"][0]
        env = {entry["name"]: entry.get("value") for entry in container["env"]}
        self.assertEqual(env["Probe__Enabled"], "true")
        self.assertEqual(env["Probe__IntervalSeconds"], "30")
        self.assertEqual(container["args"], ["--urls", "http://0.0.0.0:5080"])
        for probe in ("startupProbe", "livenessProbe", "readinessProbe"):
            self.assertEqual(container[probe]["httpGet"]["path"], "/health/liveness")
            self.assertEqual(container[probe]["httpGet"]["port"], "http")

    def test_kubelet_mode_disables_background_and_keeps_liveness_independent(self):
        container = self.render(mode="kubelet")[0]["spec"]["template"]["spec"]["containers"][0]
        env = {entry["name"]: entry.get("value") for entry in container["env"]}
        self.assertEqual(env["Probe__Enabled"], "false")
        self.assertEqual(container["readinessProbe"]["httpGet"]["path"], "/health/readiness")
        self.assertEqual(container["readinessProbe"]["timeoutSeconds"], 60)
        self.assertEqual(container["livenessProbe"]["httpGet"]["path"], "/health/liveness")

    def test_custom_els_environment_overrides_only_dependency_keys(self):
        values = reference_values()
        values["els"]["env"] += [
            {"name": "Postgres__ConnectionString", "value": "Host=override.invalid;Username=reader;Database=custom"},
            {"name": "Redis__Password", "valueFrom": {"secretKeyRef": {"name": "override-redis", "key": "key"}}},
            {"name": "Redis__ConnectTimeoutMs", "value": "2500"},
        ]
        entries = prepare.dependency_environment(values)
        env = {entry["name"]: entry for entry in entries}
        self.assertEqual(len(env), len(entries))
        self.assertEqual(env["Postgres__ConnectionString"]["value"], values["els"]["env"][1]["value"])
        self.assertEqual(env["Redis__Password"]["valueFrom"]["secretKeyRef"]["name"], "override-redis")
        self.assertEqual(env["Redis__ConnectTimeoutMs"]["value"], "2500")
        self.assertNotIn("UNRELATED_SECRET", env)

    def test_whole_connection_string_can_reference_an_existing_secret(self):
        values = reference_values()
        entry = {"name": "Postgres__ConnectionString", "valueFrom": {
            "secretKeyRef": {"name": "pg-connection", "key": "connection"}}}
        values["els"]["env"] = [entry]
        self.assertIn(entry, prepare.dependency_environment(values))

    def test_inline_password_overrides_and_missing_secret_refs_are_rejected(self):
        values = reference_values()
        values["els"]["env"] = [{"name": "Redis__Password", "value": "DO-NOT-PRINT"}]
        with self.assertRaises(prepare.PreparationError) as error:
            self.render(values)
        self.assertNotIn("DO-NOT-PRINT", str(error.exception))
        values = reference_values()
        values["externalPostgresql"]["existingSecret"] = ""
        with self.assertRaises(prepare.PreparationError):
            self.render(values)

    def test_credentials_in_connections_are_rejected(self):
        values = reference_values()
        values["externalPostgresql"]["extraParams"] = "Password=DO-NOT-PRINT"
        with self.assertRaises(prepare.PreparationError) as error:
            self.render(values)
        self.assertNotIn("DO-NOT-PRINT", str(error.exception))

    def test_duplicate_dependency_override_is_rejected(self):
        values = reference_values()
        entry = {"name": "Redis__SyncTimeoutMs", "value": "2500"}
        values["els"]["env"] = [entry, entry]
        with self.assertRaises(prepare.PreparationError):
            self.render(values)

    def test_multiple_pg_hosts_and_redis_cluster_and_sentinel(self):
        values = reference_values()
        values["externalPostgresql"]["hosts"] = ["pg-a:5433", "pg-b"]
        self.assertTrue(prepare.base_connections(values)["Postgres__ConnectionString"].startswith(
            "Host=pg-a,pg-b;Port=5433,5432;"))
        values["externalRedis"]["hosts"] = ["redis-a:6380", "redis-b:6380"]
        values["externalRedis"]["cluster"] = {"enabled": True}
        self.assertEqual(prepare.base_connections(values)["Redis__ConnectionString"],
                         "redis-a:6380,redis-b:6380,abortConnect=false,ssl=true")
        values["externalRedis"]["cluster"]["enabled"] = False
        values["externalRedis"]["sentinel"] = {"enabled": True, "masterSet": "primary"}
        self.assertEqual(prepare.base_connections(values)["Redis__ConnectionString"],
                         "redis-a:6380,redis-b:6380,serviceName=primary,defaultDatabase=0,abortConnect=false,ssl=true")

    def test_values_maps_merge_but_env_lists_replace(self):
        original = {"externalRedis": {"ssl": False, "db": 0}, "els": {"env": [{"name": "old"}]}}
        merged = prepare.merge_maps(original, {"externalRedis": {"ssl": True}, "els": {"env": []}})
        self.assertEqual(merged["externalRedis"], {"ssl": True, "db": 0})
        self.assertEqual(merged["els"]["env"], [])
        self.assertFalse(original["externalRedis"]["ssl"])

    def test_prepare_creates_isolated_context_without_mutating_inputs(self):
        with self.local_directory() as directory:
            root = Path(directory)
            project = self.project_fixture(root)
            values_file, defaults_file = root / "values.yaml", root / "defaults.yaml"
            values_file.write_text(yaml.safe_dump(reference_values()), encoding="utf-8")
            defaults_file.write_text("{}", encoding="utf-8")
            before = values_file.read_bytes()
            output = root / "prepared output"
            result = prepare.prepare(values_file, defaults_file, project, output,
                                     "example.azurecr.io/els-readiness-probe:test", "featbit", "background", 30)
            context = Path(result["buildContext"])
            files = [path for path in context.rglob("*") if path.is_file()]
            self.assertEqual(len(files), 7)
            self.assertTrue((context / "Dockerfile").is_file())
            for path in files:
                self.assertNotIn(b"PRIVATE-CONTEXT-CANARY", path.read_bytes())
                self.assertNotIn(b"SECRET-CANARY", path.read_bytes())
            self.assertEqual(values_file.read_bytes(), before)
            self.assertEqual([doc["kind"] for doc in yaml.safe_load_all(Path(result["manifest"]).read_text())],
                             ["Deployment", "Service"])
            with self.assertRaises(prepare.PreparationError):
                prepare.prepare(values_file, defaults_file, project, output,
                                "example.azurecr.io/els-readiness-probe:test", "featbit", "background", 30)

    def test_build_rejects_credentials_in_tracked_settings(self):
        with self.local_directory() as directory:
            project = self.project_fixture(Path(directory))
            (project / "src/Els.ReadinessProbe/appsettings.json").write_text(
                json.dumps({"Postgres": {"Password": "PRIVATE-CONTEXT-CANARY"}}))
            with self.assertRaises(prepare.PreparationError) as error:
                prepare.public_build_files(project)
            self.assertNotIn("PRIVATE-CONTEXT-CANARY", str(error.exception))

    def test_cli_does_not_echo_a_malformed_secret_line(self):
        with self.local_directory() as directory:
            path = Path(directory) / "values.yaml"
            path.write_text('password: "PRIVATE-CONTEXT-CANARY\n', encoding="utf-8")
            result = subprocess.run([sys.executable, str(HERE / "prepare.py"),
                                     "--image", "probe:test", "--values", str(path)],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("PRIVATE-CONTEXT-CANARY", result.stdout + result.stderr)
            self.assertIn("Preparation failed", result.stderr)

    def test_build_rejects_private_nuget_credentials_or_authenticated_feed_urls(self):
        for content in (
            '<configuration><packageSourceCredentials><feed password="PRIVATE-CONTEXT-CANARY" /></packageSourceCredentials></configuration>',
            '<configuration><packageSources><add key="private" value="https://user:PRIVATE-CONTEXT-CANARY@example.invalid/" /></packageSources></configuration>',
        ):
            with self.subTest(content_type=content.split(">")[1]), self.local_directory() as directory:
                project = self.project_fixture(Path(directory))
                (project / "NuGet.Config").write_text(content)
                with self.assertRaises(prepare.PreparationError) as error:
                    prepare.public_build_files(project)
                self.assertNotIn("PRIVATE-CONTEXT-CANARY", str(error.exception))

    @staticmethod
    @contextmanager
    def local_directory():
        directory = tempfile.TemporaryDirectory(prefix="probe-aks-test-")
        # Verify the absolute target before TemporaryDirectory's recursive
        # cleanup, including on Windows.
        target = Path(directory.name).resolve()
        assert target.parent == Path(tempfile.gettempdir()).resolve()
        assert target.name.startswith("probe-aks-test-")
        try:
            yield target
        finally:
            directory.cleanup()

    @staticmethod
    def project_fixture(root):
        project = root / "source project"
        app = project / "src/Els.ReadinessProbe"
        app.mkdir(parents=True)
        (project / "global.json").write_text('{"sdk":{"version":"10.0.100"}}')
        (project / "NuGet.Config").write_text("<configuration><packageSources /></configuration>")
        (app / "Els.ReadinessProbe.csproj").write_text('<Project Sdk="Microsoft.NET.Sdk.Web" />')
        (app / "Program.cs").write_text('Console.WriteLine("public source");')
        (app / "appsettings.json").write_text('{"Postgres":{"Password":""},"Redis":{"ConnectionString":""}}')
        for relative in ("appsettings.Local.json", "appsettings.Local.example.json", ".env", "obj/Generated.cs"):
            path = app / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("PRIVATE-CONTEXT-CANARY")
        return project


if __name__ == "__main__":
    unittest.main(verbosity=2)
