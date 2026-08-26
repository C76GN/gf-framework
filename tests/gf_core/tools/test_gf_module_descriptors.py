from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
	sys.path.insert(0, str(TOOLS))

import build_gf_package  # noqa: E402


class ModuleDescriptorTests(unittest.TestCase):
	def test_repository_descriptors_are_valid_and_own_source(self) -> None:
		result = build_gf_package.load_package_manifests()
		self.assertFalse(result["issues"], result["issues"])
		self.assertGreater(len(result["records"]), 1)
		for record in result["records"]:
			issues: list[str] = []
			files = build_gf_package.collect_package_files(record, issues)
			self.assertFalse(issues, f"{record['id']}: {issues}")
			self.assertTrue(files, f"{record['id']} must own source files")

	def test_descriptors_have_only_static_boundary_fields(self) -> None:
		for path in sorted((ROOT / "packages").rglob("*.json")):
			data = json.loads(path.read_text(encoding="utf-8"))
			self.assertLessEqual(
				set(data),
				build_gf_package.PACKAGE_MANIFEST_ALLOWED_FIELDS,
				path.as_posix(),
			)
			self.assertNotIn("version", data)
			self.assertNotIn("registry", data)
			self.assertNotIn("packages", data)
			self.assertNotEqual(data.get("kind"), "preset")

	def test_loader_rejects_retired_distribution_fields(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			package_root = root / "packages"
			package_root.mkdir()
			(package_root / "gf.kernel.json").write_text(
				json.dumps({
					"schema_version": 1,
					"id": "gf.kernel",
					"kind": "kernel",
					"dependencies": [],
					"paths": ["addons/gf/kernel/**"],
					"registry": "https://example.invalid/index.json",
				}),
				encoding="utf-8",
			)
			with (
				mock.patch.object(build_gf_package, "ROOT", root),
				mock.patch.object(build_gf_package, "PACKAGE_ROOT", package_root),
			):
				result = build_gf_package.load_package_manifests()
			self.assertTrue(any("unsupported" in issue for issue in result["issues"]))

	def test_loader_rejects_preset_descriptors(self) -> None:
		issues = build_gf_package.audit_manifest_fields(
			{
				"schema_version": 1,
				"id": "gf.preset.save",
				"kind": "preset",
				"dependencies": [],
				"paths": ["addons/gf/extensions/save/**"],
			},
			"packages/presets/gf.preset.save.json",
		)
		self.assertTrue(any("kind" in issue for issue in issues))

	def test_loader_rejects_boolean_schema_version(self) -> None:
		issues = build_gf_package.audit_manifest_fields(
			{
				"schema_version": True,
				"id": "gf.kernel",
				"kind": "kernel",
				"dependencies": [],
				"paths": ["addons/gf/kernel/**"],
			},
			"packages/gf.kernel.json",
		)
		self.assertTrue(any("schema_version" in issue for issue in issues))

	def test_loader_rejects_duplicate_keys_and_non_finite_numbers(self) -> None:
		for invalid_json in (
			'{"schema_version":1,"id":"gf.kernel","id":"gf.other"}',
			'{"schema_version":1,"id":"gf.kernel","value":NaN}',
		):
			with self.subTest(invalid_json=invalid_json):
				with tempfile.TemporaryDirectory() as temporary_directory:
					root = Path(temporary_directory)
					package_root = root / "packages"
					package_root.mkdir()
					(package_root / "gf.kernel.json").write_text(
						invalid_json,
						encoding="utf-8",
					)
					with (
						mock.patch.object(build_gf_package, "ROOT", root),
						mock.patch.object(build_gf_package, "PACKAGE_ROOT", package_root),
					):
						result = build_gf_package.load_package_manifests()
					self.assertTrue(
						any("invalid module descriptor JSON" in issue for issue in result["issues"]),
						result["issues"],
					)

	def test_path_matching_is_case_sensitive_and_portable(self) -> None:
		self.assertTrue(build_gf_package.path_matches_any_manifest_path(
			"addons/gf/kernel/gf_kernel.gd",
			["addons/gf/kernel/**"],
		))
		self.assertFalse(build_gf_package.path_matches_any_manifest_path(
			"addons/GF/kernel/gf_kernel.gd",
			["addons/gf/kernel/**"],
		))
		self.assertFalse(build_gf_package.is_windows_portable_relative_path(
			"addons/gf/kernel/CON.gd"
		))


if __name__ == "__main__":
	unittest.main()
