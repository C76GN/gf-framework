from __future__ import annotations

import copy
import hashlib
import json
import os
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[4]
TOOLS_ROOT = ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
	sys.path.insert(0, str(TOOLS_ROOT))

import build_gf_package  # noqa: E402
import gf_package_cache  # noqa: E402
import gf_package_resolver  # noqa: E402
import gf_path_security  # noqa: E402


class BuildPackageManifestSchemaTests(unittest.TestCase):
	def test_standalone_builder_rejects_unknown_and_forbidden_manifest_fields(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-package-builder-schema-") as temp_dir:
			root = Path(temp_dir)
			package_root = root / "packages"
			package_root.mkdir(parents=True)
			manifest_path = package_root / "gf.standard.fixture.json"
			manifest_path.write_text(
				json.dumps(
					{
						"schema_version": 1,
						"id": "gf.standard.fixture",
						"kind": "standard",
						"paths": ["addons/gf/standard/fixture/**"],
						"dependencies": ["gf.kernel"],
						"download_url": "https://invalid.example/archive.zip",
						"custom_field": True,
					},
					ensure_ascii=False,
				),
				encoding="utf-8",
			)

			with (
				mock.patch.object(build_gf_package, "ROOT", root),
				mock.patch.object(build_gf_package, "PACKAGE_ROOT", package_root),
			):
				result = build_gf_package.load_package_manifests()

			issues = result["issues"]
			self.assertTrue(any("forbidden package manifest field: download_url" in issue for issue in issues), issues)
			self.assertTrue(any("unsupported package manifest field: custom_field" in issue for issue in issues), issues)

	def test_standalone_builder_rejects_boolean_schema_version(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-package-builder-int-") as temp_dir:
			root = Path(temp_dir)
			package_root = root / "packages"
			package_root.mkdir(parents=True)
			(package_root / "gf.kernel.json").write_text(
				json.dumps({"schema_version": True, "id": "gf.kernel", "kind": "kernel", "paths": []}),
				encoding="utf-8",
			)

			with (
				mock.patch.object(build_gf_package, "ROOT", root),
				mock.patch.object(build_gf_package, "PACKAGE_ROOT", package_root),
			):
				result = build_gf_package.load_package_manifests()

			self.assertTrue(any("schema_version must be the integer 1" in issue for issue in result["issues"]), result)

	def test_builder_rejects_symlinked_package_source(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-package-builder-symlink-") as temp_dir:
			root = Path(temp_dir)
			source_root = root / "addons/gf/standard/fixture"
			source_root.mkdir(parents=True)
			external = root / "external.gd"
			external.write_text("extends RefCounted\n", encoding="utf-8")
			linked_source = source_root / "linked.gd"
			try:
				linked_source.symlink_to(external)
			except OSError:
				self.skipTest("The platform does not permit symlink creation.")
			record = {
				"id": "gf.standard.fixture",
				"kind": "standard",
				"paths": ["addons/gf/standard/fixture/**"],
				"exclude_paths": [],
			}
			issues: list[str] = []

			with mock.patch.object(build_gf_package, "ROOT", root):
				files = build_gf_package.collect_package_files(record, issues)

			self.assertEqual(files, [])
			self.assertTrue(any("symlink, junction, or reparse point" in issue for issue in issues), issues)

	def test_distribution_publish_failure_restores_every_previous_output(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-package-builder-publish-") as temp_dir:
			root = Path(temp_dir)
			first = root / "first.zip"
			second = root / "index.json"
			first.write_bytes(b"old first")
			second.write_bytes(b"old second")
			first_candidate = root / ".first.zip.gf-build-test.candidate"
			second_candidate = root / ".index.json.gf-build-test.candidate"
			first_candidate.write_bytes(b"new first")
			second_candidate.write_bytes(b"new second")
			real_replace = os.replace
			call_count = 0

			def fail_second_publish(source: str | Path, target: str | Path) -> None:
				nonlocal call_count
				call_count += 1
				if call_count == 4:
					raise OSError("simulated second publish failure")
				real_replace(source, target)

			with mock.patch.object(build_gf_package.os, "replace", side_effect=fail_second_publish):
				issues = build_gf_package.publish_staged_outputs(
					{first: first_candidate, second: second_candidate},
					"test",
				)

			self.assertTrue(any("publish failed" in issue for issue in issues), issues)
			self.assertEqual(first.read_bytes(), b"old first")
			self.assertEqual(second.read_bytes(), b"old second")
			self.assertFalse(any(root.glob("*.backup")))


class PackageResolverPlanTests(unittest.TestCase):
	def test_install_and_update_plans_preserve_unchanged_dependency_file_metadata(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-package-plan-metadata-") as temp_dir:
			root = Path(temp_dir)
			registry_path = root / "registry.json"
			lockfile_path = root / "packages.lock.json"
			metadata = {
				"addons/gf/kernel/example.gd": {
					"sha256": "a" * 64,
					"size_bytes": 17,
				},
			}
			registry_path.write_text(json.dumps({
				"schema_version": 2,
				"framework_version": "7.0.0",
				"minimum_framework_version": "7.0.0",
				"maximum_framework_version_exclusive": "8.0.0",
				"packages": {
					"gf.kernel": self._registry_entry("kernel", []),
					"gf.standard.fixture": self._registry_entry("standard", ["gf.kernel"]),
				},
			}, indent=2), encoding="utf-8")
			lockfile_path.write_text(json.dumps({
				"schema_version": 1,
				"framework_version": "7.0.0",
				"installed": {
					"gf.kernel": {
						**gf_package_resolver.make_lock_entry(self._registry_entry("kernel", []), "gf.kernel"),
						"reason": ["bundled"],
						"files": ["addons/gf/kernel/example.gd"],
						"file_metadata": metadata,
					},
					"gf.standard.fixture": {
						**gf_package_resolver.make_lock_entry(self._registry_entry("standard", ["gf.kernel"]), "gf.standard.fixture"),
						"reason": ["manual"],
						"files": ["addons/gf/standard/fixture/example.gd"],
						"file_metadata": {
							"addons/gf/standard/fixture/example.gd": {
								"sha256": "b" * 64,
								"size_bytes": 19,
							},
						},
					},
				},
			}, indent=2), encoding="utf-8")

			install_result = gf_package_resolver.install_plan(
				str(registry_path), str(lockfile_path), ["gf.standard.fixture"], "manual"
			)
			update_result = gf_package_resolver.update_plan(
				str(registry_path), str(lockfile_path), ["gf.standard.fixture"], False
			)

			self.assertTrue(install_result["ok"], install_result["issues"])
			self.assertTrue(update_result["ok"], update_result["issues"])
			self.assertEqual(install_result["planned_lockfile"]["installed"]["gf.kernel"]["file_metadata"], metadata)
			self.assertEqual(update_result["planned_lockfile"]["installed"]["gf.kernel"]["file_metadata"], metadata)

	@staticmethod
	def _registry_entry(kind: str, dependencies: list[str]) -> dict[str, object]:
		return {
			"version": "7.0.0",
			"kind": kind,
			"paths": [f"addons/gf/{'kernel' if kind == 'kernel' else 'standard/fixture'}/**"],
			"archive": f"{kind}.zip",
			"sha256": "c" * 64,
			"dependencies": dependencies,
			"minimum_framework_version": "7.0.0",
			"maximum_framework_version_exclusive": "8.0.0",
		}


class PackageResolverVerifyLockTests(unittest.TestCase):
	PACKAGE_ID = "gf.standard.fixture"
	RELATIVE_PATH = "addons/gf/standard/fixture/current.gd"
	PACKAGE_ROOT_PATTERN = "addons/gf/standard/fixture/**"

	def test_verify_lock_requires_exact_files_and_file_metadata_contract(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-package-verify-schema-") as temp_dir:
			fixture = self._make_fixture(Path(temp_dir))
			base_lockfile = fixture["lockfile"]
			cases = (
				("missing_files", lambda entry: entry.pop("files"), "missing files list"),
				("missing_metadata", lambda entry: entry.pop("file_metadata"), "file_metadata must be an object"),
				("missing_metadata_entry", lambda entry: entry["file_metadata"].clear(), "file_metadata is missing file"),
				(
					"unlisted_metadata_entry",
					lambda entry: entry["file_metadata"].update(
						{"addons/gf/standard/fixture/stale.gd": {"sha256": "0" * 64, "size_bytes": 0}}
					),
					"file_metadata contains an unlisted file",
				),
			)
			for label, mutate, expected_issue in cases:
				with self.subTest(label=label):
					lockfile = copy.deepcopy(base_lockfile)
					mutate(lockfile["installed"][self.PACKAGE_ID])
					self._write_json(fixture["lockfile_path"], lockfile)

					result = self._verify(fixture)

					self.assertFalse(result["ok"], result)
					self.assertTrue(any(expected_issue in issue for issue in result["issues"]), result["issues"])

	def test_verify_lock_checks_installed_file_digest_and_size(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-package-verify-integrity-") as temp_dir:
			fixture = self._make_fixture(Path(temp_dir), payload=b"abcde")
			target_path = fixture["project_root"] / self.RELATIVE_PATH
			target_path.write_bytes(b"vwxyz")

			digest_result = self._verify(fixture)

			self.assertFalse(digest_result["ok"], digest_result)
			self.assertTrue(any("sha256 does not match" in issue for issue in digest_result["issues"]), digest_result["issues"])

			target_path.write_bytes(b"different size")
			size_result = self._verify(fixture)

			self.assertFalse(size_result["ok"], size_result)
			self.assertTrue(any("size does not match" in issue for issue in size_result["issues"]), size_result["issues"])

	def test_verify_lock_infers_project_root_from_canonical_lockfile(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-package-verify-inferred-root-") as temp_dir:
			fixture = self._make_fixture(Path(temp_dir), payload=b"abcde")
			(fixture["project_root"] / "project.godot").write_text("[application]\n", encoding="utf-8")
			target_path = fixture["project_root"] / self.RELATIVE_PATH
			target_path.write_bytes(b"vwxyz")

			result = gf_package_resolver.verify_lock(
				registry_path=str(fixture["registry_path"]),
				lockfile_path=str(fixture["lockfile_path"]),
			)

			self.assertFalse(result["ok"], result)
			self.assertTrue(any("sha256 does not match" in issue for issue in result["issues"]), result["issues"])

	def test_verify_lock_rejects_extra_file_in_exclusive_package_tree(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-package-verify-extra-") as temp_dir:
			fixture = self._make_fixture(Path(temp_dir))
			legacy_path = fixture["project_root"] / "addons/gf/standard/fixture/legacy.gd"
			legacy_path.write_text("extends RefCounted\n", encoding="utf-8")

			result = self._verify(fixture)

			self.assertFalse(result["ok"], result)
			self.assertTrue(
				any("unlisted file remains in package-owned tree" in issue and "legacy.gd" in issue for issue in result["issues"]),
				result["issues"],
			)

	def test_verify_lock_does_not_treat_project_files_as_package_owned(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-package-verify-project-file-") as temp_dir:
			fixture = self._make_fixture(Path(temp_dir))
			project_file = fixture["project_root"] / "scripts/project_owned.gd"
			project_file.parent.mkdir(parents=True)
			project_file.write_text("extends Node\n", encoding="utf-8")

			result = self._verify(fixture)

			self.assertTrue(result["ok"], result)

	def test_verify_lock_skips_extra_scan_when_manifest_tree_is_not_exclusive(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-package-verify-overlap-") as temp_dir:
			fixture = self._make_fixture(Path(temp_dir))
			registry = fixture["registry"]
			registry["packages"]["gf.standard.other"] = self._registry_entry(
				["addons/gf/standard/fixture/project_owned.gd"]
			)
			self._write_json(fixture["registry_path"], registry)
			project_file = fixture["project_root"] / "addons/gf/standard/fixture/project_owned.gd"
			project_file.write_text("extends RefCounted\n", encoding="utf-8")

			result = self._verify(fixture)

			self.assertTrue(result["ok"], result)

	def test_verify_lock_skips_extra_scan_when_registry_identity_is_stale(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-package-verify-stale-identity-") as temp_dir:
			fixture = self._make_fixture(Path(temp_dir))
			lockfile = fixture["lockfile"]
			lockfile["installed"][self.PACKAGE_ID]["sha256"] = "b" * 64
			self._write_json(fixture["lockfile_path"], lockfile)
			project_file = fixture["project_root"] / "addons/gf/standard/fixture/project_owned.gd"
			project_file.write_text("extends RefCounted\n", encoding="utf-8")

			result = self._verify(fixture)

			self.assertFalse(result["ok"], result)
			self.assertTrue(any("sha256 differs from registry" in issue for issue in result["issues"]), result["issues"])
			self.assertFalse(any("unlisted file remains" in issue for issue in result["issues"]), result["issues"])

	def test_verify_lock_requires_complete_registry_identity_schema(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-package-verify-identity-") as temp_dir:
			fixture = self._make_fixture(Path(temp_dir))
			cases = (
				("kind", "extension", "kind differs from registry"),
				("archive", "other.zip", "archive differs from registry"),
				("paths", ["addons/gf/standard/other/**"], "paths differ from registry"),
			)
			for field_name, value, expected_issue in cases:
				with self.subTest(field=field_name):
					lockfile = copy.deepcopy(fixture["lockfile"])
					lockfile["installed"][self.PACKAGE_ID][field_name] = value
					self._write_json(fixture["lockfile_path"], lockfile)

					result = self._verify(fixture)

					self.assertFalse(result["ok"], result)
					self.assertTrue(any(expected_issue in issue for issue in result["issues"]), result["issues"])

			lockfile = copy.deepcopy(fixture["lockfile"])
			lockfile["installed"][self.PACKAGE_ID]["unexpected_identity"] = True
			lockfile["installed"][self.PACKAGE_ID]["file_metadata"][self.RELATIVE_PATH]["extra"] = "unsafe"
			self._write_json(fixture["lockfile_path"], lockfile)
			result = self._verify(fixture)
			self.assertFalse(result["ok"], result)
			self.assertTrue(any("unsupported field" in issue for issue in result["issues"]), result["issues"])
			self.assertTrue(any("file_metadata entry is invalid" in issue for issue in result["issues"]), result["issues"])

	def test_reference_scan_reads_class_names_from_target_project(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-package-target-class-scan-") as temp_dir:
			project_root = Path(temp_dir)
			package_source = project_root / "addons/gf/standard/fixture/api.gd"
			package_source.parent.mkdir(parents=True)
			package_source.write_text("class_name GFTargetProjectOnlyClass\nextends RefCounted\n", encoding="utf-8")
			consumer = project_root / "game/consumer.gd"
			consumer.parent.mkdir(parents=True)
			consumer.write_text("var dependency: GFTargetProjectOnlyClass\n", encoding="utf-8")
			packages = {self.PACKAGE_ID: {"paths": [self.PACKAGE_ROOT_PATTERN]}}

			references = gf_package_resolver.scan_project_references(project_root, packages, self.PACKAGE_ID)

			self.assertTrue(
				any(reference["path"] == "game/consumer.gd" and reference["symbol"] == "GFTargetProjectOnlyClass" for reference in references),
				references,
			)

	def test_reference_scan_finds_package_path_in_binary_resource(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-package-binary-reference-") as temp_dir:
			project_root = Path(temp_dir)
			binary_consumer = project_root / "game/consumer.res"
			binary_consumer.parent.mkdir(parents=True)
			binary_consumer.write_bytes(
				b"RSRC\x00fixture\x00res://addons/gf/standard/fixture/data.res\x00"
			)
			packages = {self.PACKAGE_ID: {"paths": [self.PACKAGE_ROOT_PATTERN]}}

			references = gf_package_resolver.scan_project_references(project_root, packages, self.PACKAGE_ID)

			self.assertTrue(
				any(
					reference["path"] == "game/consumer.res"
					and reference["symbol"] == "addons/gf/standard/fixture"
					for reference in references
				),
				references,
			)

	def test_wildcard_prefix_conservatively_blocks_exclusive_tree_scan(self) -> None:
		registry = {
			self.PACKAGE_ID: {"paths": [self.PACKAGE_ROOT_PATTERN]},
			"gf.standard.other": {"paths": ["addons/gf/standard/f*"]},
		}

		roots = gf_package_resolver.exclusive_package_tree_roots(self.PACKAGE_ID, registry)

		self.assertEqual(roots, [])

	def _make_fixture(self, root: Path, payload: bytes = b"extends RefCounted\n") -> dict[str, object]:
		project_root = root / "project"
		target_path = project_root / self.RELATIVE_PATH
		target_path.parent.mkdir(parents=True)
		target_path.write_bytes(payload)
		registry_path = root / "registry/index.json"
		lockfile_path = project_root / ".gf/packages.lock.json"
		registry = {
			"schema_version": 2,
			"framework_version": "1.0.0",
			"minimum_framework_version": "1.0.0",
			"maximum_framework_version_exclusive": "2.0.0",
			"packages": {
				self.PACKAGE_ID: self._registry_entry([self.PACKAGE_ROOT_PATTERN]),
			},
		}
		lockfile = {
			"schema_version": 1,
			"framework_version": "1.0.0",
			"installed": {
				self.PACKAGE_ID: {
					"version": "1.0.0",
					"kind": "standard",
					"reason": ["manual"],
					"required_by": [],
					"paths": [self.PACKAGE_ROOT_PATTERN],
					"archive": "fixture.zip",
					"sha256": "a" * 64,
					"files": [self.RELATIVE_PATH],
					"file_metadata": {
						self.RELATIVE_PATH: {
							"sha256": hashlib.sha256(payload).hexdigest(),
							"size_bytes": len(payload),
						}
					},
				}
			},
		}
		self._write_json(registry_path, registry)
		self._write_json(lockfile_path, lockfile)
		return {
			"project_root": project_root,
			"registry_path": registry_path,
			"lockfile_path": lockfile_path,
			"registry": registry,
			"lockfile": lockfile,
		}

	def _registry_entry(self, paths: list[str]) -> dict[str, object]:
		return {
			"kind": "standard",
			"version": "1.0.0",
			"dependencies": [],
			"paths": paths,
			"archive": "fixture.zip",
			"sha256": "a" * 64,
			"size_bytes": 1,
			"minimum_framework_version": "1.0.0",
			"maximum_framework_version_exclusive": "2.0.0",
		}

	def _verify(self, fixture: dict[str, object]) -> dict[str, object]:
		return gf_package_resolver.verify_lock(
			registry_path=str(fixture["registry_path"]),
			lockfile_path=str(fixture["lockfile_path"]),
			project_root=str(fixture["project_root"]),
		)

	def _write_json(self, path: Path, data: dict[str, object]) -> None:
		path.parent.mkdir(parents=True, exist_ok=True)
		path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


class PackageResolverUninstallTests(unittest.TestCase):
	ROOT_PACKAGE_ID = "gf.extension.fixture"
	DEPENDENCY_PACKAGE_ID = "gf.standard.fixture"

	def test_uninstall_blocks_when_auto_pruned_dependency_has_project_reference(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-package-prune-reference-") as temp_dir:
			root = Path(temp_dir)
			project_root = root / "project"
			registry_path = root / "registry/index.json"
			lockfile_path = project_root / ".gf/packages.lock.json"
			dependency_path = "addons/gf/standard/fixture/api.gd"
			root_path = "addons/gf/extensions/fixture/api.gd"
			for relative_path in (dependency_path, root_path):
				path = project_root / relative_path
				path.parent.mkdir(parents=True, exist_ok=True)
				path.write_text("extends RefCounted\n", encoding="utf-8")
			consumer_path = project_root / "scripts/uses_fixture.gd"
			consumer_path.parent.mkdir(parents=True)
			consumer_path.write_text(
				'extends Node\nconst Fixture = preload("res://addons/gf/standard/fixture/api.gd")\n',
				encoding="utf-8",
			)
			binary_consumer_path = project_root / "resources/uses_fixture.res"
			binary_consumer_path.parent.mkdir(parents=True)
			binary_consumer_path.write_bytes(
				b"RSRC\x00res://addons/gf/standard/fixture/api.gd\x00"
			)

			registry = {
				"schema_version": 2,
				"framework_version": "1.0.0",
				"minimum_framework_version": "1.0.0",
				"maximum_framework_version_exclusive": "2.0.0",
				"packages": {
					self.ROOT_PACKAGE_ID: self._registry_entry(
						"extension", ["addons/gf/extensions/fixture/**"], [self.DEPENDENCY_PACKAGE_ID]
					),
					self.DEPENDENCY_PACKAGE_ID: self._registry_entry(
						"standard", ["addons/gf/standard/fixture/**"], []
					),
				},
			}
			lockfile = {
				"schema_version": 1,
				"framework_version": "1.0.0",
				"installed": {
					self.ROOT_PACKAGE_ID: self._lock_entry(
						registry["packages"][self.ROOT_PACKAGE_ID], [root_path], ["manual"], []
					),
					self.DEPENDENCY_PACKAGE_ID: self._lock_entry(
						registry["packages"][self.DEPENDENCY_PACKAGE_ID],
						[dependency_path],
						["dependency"],
						[self.ROOT_PACKAGE_ID],
					),
				},
			}
			self._write_json(registry_path, registry)
			self._write_json(lockfile_path, lockfile)

			result = gf_package_resolver.uninstall_plan(
				registry_path=str(registry_path),
				lockfile_path=str(lockfile_path),
				package_ids=[self.ROOT_PACKAGE_ID],
				project_root=str(project_root),
				force=False,
			)

			self.assertFalse(result["ok"], result)
			self.assertEqual(result["to_remove"], [])
			self.assertEqual(result["planned_lockfile"], lockfile)
			self.assertTrue(
				any(
					blocker.get("id") == self.DEPENDENCY_PACKAGE_ID
					and blocker.get("reason") == "project_references"
					and any(reference.get("path") == "scripts/uses_fixture.gd" for reference in blocker.get("references", []))
					for blocker in result["blocked"]
				),
				result["blocked"],
			)
			self.assertTrue(
				any(
					any(reference.get("path") == "resources/uses_fixture.res" for reference in blocker.get("references", []))
					for blocker in result["blocked"]
				),
				result["blocked"],
			)

	@staticmethod
	def _registry_entry(kind: str, paths: list[str], dependencies: list[str]) -> dict[str, object]:
		return {
			"kind": kind,
			"version": "1.0.0",
			"dependencies": dependencies,
			"paths": paths,
			"archive": f"{kind}.zip",
			"sha256": "a" * 64,
			"size_bytes": 1,
			"minimum_framework_version": "1.0.0",
			"maximum_framework_version_exclusive": "2.0.0",
		}

	@staticmethod
	def _lock_entry(
		registry_entry: dict[str, object],
		files: list[str],
		reason: list[str],
		required_by: list[str],
	) -> dict[str, object]:
		return {
			**copy.deepcopy(registry_entry),
			"reason": reason,
			"required_by": required_by,
			"files": files,
			"file_metadata": {
				relative_path: {"sha256": hashlib.sha256(b"extends RefCounted\n").hexdigest(), "size_bytes": 19}
				for relative_path in files
			},
		}

	@staticmethod
	def _write_json(path: Path, data: dict[str, object]) -> None:
		path.parent.mkdir(parents=True, exist_ok=True)
		path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


class PackageCacheContainmentTests(unittest.TestCase):
	def test_shared_path_security_rejects_lexical_sibling_escape(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-path-security-") as temp_dir:
			root = Path(temp_dir) / "project"
			root.mkdir()
			self.assertTrue(gf_path_security.path_is_inside_lexical(root, root / "addons/gf"))
			self.assertFalse(gf_path_security.path_is_inside_lexical(root, root.parent / "project-other"))

	def test_project_cache_rejects_symlinked_owned_root(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-package-cache-link-") as temp_dir:
			root = Path(temp_dir)
			project_root = root / "project"
			external_root = root / "external"
			project_root.mkdir()
			external_root.mkdir()
			try:
				(project_root / ".gf").symlink_to(external_root, target_is_directory=True)
			except OSError:
				self.skipTest("The platform does not permit directory symlink creation.")
			issues: list[str] = []

			gf_package_cache.resolve_context(project_root, "", gf_package_cache.MODE_PROJECT_LOCAL, issues)

			self.assertTrue(any("crosses a filesystem link" in issue for issue in issues), issues)


if __name__ == "__main__":
	unittest.main()
