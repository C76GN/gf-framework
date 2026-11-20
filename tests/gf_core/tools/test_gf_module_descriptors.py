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
import gf_maintenance  # noqa: E402
import gf_module_descriptors as descriptors  # noqa: E402


class ModuleDescriptorTests(unittest.TestCase):
	def test_maintenance_and_generator_reject_the_same_invalid_descriptors(self) -> None:
		base = {
			"schema_version": 1, "id": "gf.kernel", "kind": "kernel",
			"dependencies": [], "paths": ["addons/gf/kernel/**"],
		}
		for change in (
			{"id": "gf.tool.wrong"},
			{"paths": ["docs/**"]},
			{"paths": ["addons/gf/kernel/**", "addons/gf/KERNEL/**"]},
			{"exclude_paths": None},
			{"dependencies": ["gf.standard.base", "gf.standard.base"]},
		):
			with self.subTest(change=change):
				data = {**base, **change}
				path = "packages/gf.kernel.json"
				self.assertTrue(build_gf_package.audit_manifest_fields(data, path))
				self.assertTrue(gf_maintenance.audit_package_manifest_data(data, path))

	def test_repository_descriptors_are_valid_and_own_source(self) -> None:
		result = build_gf_package.load_package_manifests()
		self.assertFalse(result["issues"], result["issues"])
		self.assertGreater(len(result["records"]), 1)
		owners = build_gf_package.collect_file_owners(result["records"], ROOT)
		self.assertEqual(set(owners.values()), {record["id"] for record in result["records"]})
		self.assertEqual(owners["addons/gf/extensions/network/runtime/gf_network_request_handle.gd"], "gf.extension.network")
		self.assertEqual(owners["addons/gf/extensions/network/editor/gf_network_editor_actions.gd"], "gf.tool.network.editor")

	def test_overlapping_scopes_apply_exclusions_per_module(self) -> None:
		base = "addons/gf/extensions/network"
		runtime, editor = f"{base}/runtime/a.gd", f"{base}/editor/b.gd"
		records = [
			{"id": "gf.extension.network", "paths": [base + "/**", runtime], "exclude_paths": [base + "/editor/**"]},
			{"id": "gf.tool.network.editor", "paths": [base + "/editor/**"]},
		]
		with tempfile.TemporaryDirectory() as temporary:
			root = Path(temporary)
			for path in (runtime, editor):
				(root / path).parent.mkdir(parents=True)
				(root / path).touch()
			owners = build_gf_package.collect_file_owners(records, root)
			self.assertEqual(owners, {runtime: "gf.extension.network", editor: "gf.tool.network.editor"})
			self.assertEqual(gf_maintenance.audit_package_path_ownership(records, [runtime, editor]), [])
			index = descriptors.PackageOwnershipIndex(descriptors.collect_package_source_owner_entries(records))
			self.assertEqual(index.find_owner("res://" + editor)["package_id"], owners[editor])
			records[0]["exclude_paths"] = []
			with self.assertRaisesRegex(ValueError, "exactly one package"):
				build_gf_package.collect_file_owners(records, root)
			self.assertEqual({item["overlap_path"] for item in gf_maintenance.audit_package_path_ownership(
				[{**record, "path": f"packages/{record['id']}.json"} for record in records], [runtime, editor],
			)}, {editor})

	def test_filesystem_and_git_consumers_own_their_discovery_scope(self) -> None:
		with tempfile.TemporaryDirectory() as temporary:
			root = Path(temporary)
			(root / "packages").mkdir()
			for module in ("visible", "ignored"):
				path = root / "packages" / (module + (".JSON" if module == "visible" else ".json"))
				path.write_text(json.dumps({
					"schema_version": 1, "id": "gf.tool." + module, "kind": "tool",
					"dependencies": [], "paths": ["addons/gf/tools/" + module + "/**"],
				}), encoding="utf-8")
			with mock.patch.object(gf_maintenance, "read_git_paths", side_effect=[
				{"error": "", "paths": ["packages/visible.JSON"]}, {"error": "", "paths": []}, {"error": "", "paths": []},
			]):
				self.assertEqual(gf_maintenance.collect_package_manifest_paths(), {"paths": ["packages/visible.JSON"], "errors": []})
			result = build_gf_package.load_package_manifests(root)
			self.assertFalse(result["issues"])
			self.assertEqual({record["id"] for record in result["records"]}, {"gf.tool.ignored", "gf.tool.visible"})

	def test_literal_file_and_glob_anchor_use_actual_case_on_every_platform(self) -> None:
		with tempfile.TemporaryDirectory() as temporary:
			root = Path(temporary)
			relative = "addons/gf/tools/editor/gf_panel.gd"
			(root / relative).parent.mkdir(parents=True)
			(root / relative).touch()
			with mock.patch.object(gf_maintenance, "ROOT", root):
				for pattern in ("addons/gf/tools/editor/GF_PANEL.gd", "addons/gf/tools/EDITOR/**"):
					with self.subTest(pattern=pattern):
						record = {"id": "gf.tool.editor", "paths": [pattern]}
						self.assertFalse(gf_maintenance.package_manifest_path_exists(pattern))
						self.assertEqual(build_gf_package.collect_file_owners([record], root), {})
				self.assertTrue(gf_maintenance.package_manifest_path_exists(relative))
				self.assertEqual(build_gf_package.collect_file_owners([{"id": "gf.tool.editor", "paths": [relative]}], root),
								 {relative: "gf.tool.editor"})

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
