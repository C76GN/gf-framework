#!/usr/bin/env python3
"""Behavior and safety tests for the optional project-side GF AI kit."""

from __future__ import annotations

import copy
import hashlib
import io
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from typing import Any
from unittest import mock


ROOT = Path(__file__).resolve().parents[4]
ADDON_ROOT = ROOT / "addons/gf/tools/ai_developer"
TOOLS_ROOT = ROOT / "tools"
FIXTURE_PATH = Path(__file__).with_name("fixtures") / "evaluation_cases.json"
sys.path.insert(0, str(ADDON_ROOT))
sys.path.insert(0, str(TOOLS_ROOT))

from gf_ai import adapters, catalog, cli, context_bundle, dependencies, feedback, mcp, migration, paths, snapshot  # noqa: E402
from gf_ai.constants import (  # noqa: E402
	ARTIFACT_POLICY_PATH,
	CONTRACT_SCHEMA_VERSION,
	DEFAULT_CONTRACT_PATH,
	PROJECT_ARTIFACT_PATHS,
	SCHEMA_ROOT,
	SNAPSHOT_SCHEMA_VERSION,
	TOOL_VERSION,
)
from gf_ai.contract import initialize_contract, load_contract  # noqa: E402
from gf_ai.paths import read_json_object, resolve_project_path  # noqa: E402
from gf_ai.schema import validate_schema_definition, validate_schema_file  # noqa: E402
import build_gf_ai_developer_kit  # noqa: E402
from gf_maintenance import create_directory_link_fixture  # noqa: E402


class GFAIDeveloperKitTest(unittest.TestCase):
	def setUp(self) -> None:
		self._temporary = tempfile.TemporaryDirectory(prefix="gf-ai-kit-test-")
		self.project_root = Path(self._temporary.name)
		(self.project_root / "project.godot").write_text(
			'[application]\nconfig/name="GF AI Test"\nconfig/features=PackedStringArray("4.5")\n',
			encoding="utf-8",
		)
		framework_version = catalog.catalog_framework_version()
		(self.project_root / "addons/gf").mkdir(parents=True)
		plugin_source = f'[plugin]\nname="GF"\nversion="{framework_version}"\n'
		plugin_path = self.project_root / "addons/gf/plugin.cfg"
		plugin_path.write_text(plugin_source, encoding="utf-8")
		plugin_payload = plugin_source.encode("utf-8")
		(self.project_root / ".gf").mkdir()
		(self.project_root / ".gf/packages.lock.json").write_text(
			json.dumps({
				"schema_version": 1,
				"framework_version": framework_version,
				"installed": {
					"gf.kernel": {
						"version": framework_version,
						"kind": "kernel",
						"reason": ["bundled"],
						"required_by": [],
						"paths": ["addons/gf/plugin.cfg"],
						"archive": "gf.kernel.zip",
						"sha256": "0" * 64,
						"files": ["addons/gf/plugin.cfg"],
						"file_metadata": {
							"addons/gf/plugin.cfg": {
								"sha256": hashlib.sha256(plugin_payload).hexdigest(),
								"size_bytes": len(plugin_payload),
							},
						},
					},
				},
			}),
			encoding="utf-8",
		)
		result = initialize_contract(self.project_root)
		self.assertTrue(result["ok"], result)

	def tearDown(self) -> None:
		self._temporary.cleanup()

	def _load_platform_adapter_profile(self) -> dict[str, Any]:
		profile_path = (
			build_gf_ai_developer_kit.PLATFORM_ADAPTER_TEMPLATE_ROOT
			/ "compatibility_profile.json"
		)
		return json.loads(profile_path.read_text(encoding="utf-8"))

	def _validate_platform_adapter_profile(
		self,
		profile: dict[str, Any],
	) -> list[str]:
		with tempfile.TemporaryDirectory(prefix="gf-ai-native-profile-case-") as temporary:
			copied_template_root = Path(temporary) / "platform"
			shutil.copytree(
				build_gf_ai_developer_kit.PLATFORM_ADAPTER_TEMPLATE_ROOT,
				copied_template_root,
			)
			(copied_template_root / "compatibility_profile.json").write_text(
				json.dumps(profile, ensure_ascii=False, indent=2) + "\n",
				encoding="utf-8",
			)
			return build_gf_ai_developer_kit.validate_platform_adapter_templates(
				copied_template_root
			)

	def test_artifact_policy_is_shared_and_contract_defaults_to_project_state_root(self) -> None:
		policy = json.loads(ARTIFACT_POLICY_PATH.read_text(encoding="utf-8"))

		self.assertEqual(policy["paths"], PROJECT_ARTIFACT_PATHS)
		self.assertEqual(DEFAULT_CONTRACT_PATH, ".gf/project_contract.json")
		self.assertTrue((self.project_root / DEFAULT_CONTRACT_PATH).is_file())
		self.assertFalse((self.project_root / "gf_project_contract.json").exists())

	def test_contract_rejects_unknown_fields_and_path_escape(self) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		contract = json.loads(contract_path.read_text(encoding="utf-8"))
		contract["project"]["accidental_convention"] = True
		contract_path.write_text(json.dumps(contract, ensure_ascii=False), encoding="utf-8")

		result = load_contract(self.project_root)

		self.assertFalse(result["ok"])
		self.assertTrue(any("accidental_convention" in item["path"] for item in result["issues"]))
		with self.assertRaises(ValueError):
			resolve_project_path(self.project_root, "../outside.json")

	def test_strict_json_rejects_duplicate_non_finite_and_parser_recursion(self) -> None:
		path = self.project_root / "strict.json"
		path.write_text('{"value": 1, "value": 2}', encoding="utf-8")
		with self.assertRaisesRegex(ValueError, "Duplicate JSON object key"):
			read_json_object(path)
		path.write_text('{"value": NaN}', encoding="utf-8")
		with self.assertRaisesRegex(ValueError, "Non-finite JSON number"):
			read_json_object(path)
		path.write_text('{"value": 1}', encoding="utf-8")
		with mock.patch.object(
			paths.json,
			"loads",
			side_effect=RecursionError("maximum JSON nesting exceeded"),
		):
			with self.assertRaisesRegex(ValueError, "JSON file is unreadable"):
				read_json_object(path)

	def test_schema_definition_rejects_keywords_the_validator_does_not_implement(self) -> None:
		issues = validate_schema_definition({"type": "string", "format": "uri"})

		self.assertEqual(issues[0]["code"], "unsupported_schema_keyword")

	def test_contract_rejects_unknown_packages_and_module_cycles(self) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		contract = json.loads(contract_path.read_text(encoding="utf-8"))
		contract["framework"]["optional_packages"] = ["gf.standard.not_real"]
		contract["architecture"]["modules"] = [
			{
				"id": "first",
				"responsibility": "First module",
				"roots": ["res://first"],
				"allowed_dependencies": ["second"],
				"forbidden_dependencies": [],
				"ownership": "project",
			},
			{
				"id": "second",
				"responsibility": "Second module",
				"roots": ["res://second"],
				"allowed_dependencies": ["first"],
				"forbidden_dependencies": [],
				"ownership": "project",
			},
		]
		contract_path.write_text(json.dumps(contract), encoding="utf-8")

		result = load_contract(self.project_root)
		codes = {item["code"] for item in result["issues"]}

		self.assertFalse(result["ok"])
		self.assertIn("unknown_package", codes)
		self.assertIn("module_dependency_cycle", codes)

	def test_contract_requires_capability_package_owner_and_advertised_recipe(self) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		contract = json.loads(contract_path.read_text(encoding="utf-8"))
		contract["framework"]["capability_requirements"].append({
			"id": "storage-save",
			"decision_state": "confirmed",
			"owner": "missing_owner",
			"recipes": ["ui-screen-flow"],
			"acceptance": [],
			"notes": "",
		})
		contract_path.write_text(json.dumps(contract), encoding="utf-8")

		result = load_contract(self.project_root)
		codes = {item["code"] for item in result["issues"]}

		self.assertFalse(result["ok"])
		self.assertIn("unknown_capability_owner", codes)
		self.assertIn("capability_package_not_required", codes)
		self.assertIn("capability_recipe_mismatch", codes)

	def test_contract_migration_is_dry_run_first_hash_bound_and_atomic(self) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		current = json.loads(contract_path.read_text(encoding="utf-8"))
		legacy = dict(current)
		legacy["schema_version"] = 1
		legacy["framework"] = dict(current["framework"])
		legacy["framework"]["required_capabilities"] = [
			item["id"] for item in current["framework"]["capability_requirements"]
		]
		del legacy["framework"]["capability_requirements"]
		contract_path.write_text(json.dumps(legacy, ensure_ascii=False), encoding="utf-8")
		original_bytes = contract_path.read_bytes()

		loaded = load_contract(self.project_root)
		plan = migration.plan_contract_migration(self.project_root)

		self.assertFalse(loaded["ok"])
		self.assertTrue(loaded["migration_required"])
		self.assertEqual(loaded["schema_version"], 1)
		self.assertIn("contract_migration_required", {item["code"] for item in loaded["issues"]})
		self.assertTrue(plan["ok"], plan)
		self.assertEqual(plan["status"], "ready")
		self.assertEqual(plan["source"]["schema_version"], 1)
		self.assertEqual(plan["target"]["schema_version"], CONTRACT_SCHEMA_VERSION)
		self.assertEqual(plan["candidate"]["schema_version"], CONTRACT_SCHEMA_VERSION)
		self.assertIn("capability_requirements", plan["candidate"]["framework"])
		self.assertNotIn("required_capabilities", plan["candidate"]["framework"])
		self.assertEqual(contract_path.read_bytes(), original_bytes)

		stale = migration.apply_contract_migration(self.project_root, "0" * 64)
		self.assertFalse(stale["ok"])
		self.assertEqual(stale["issues"][0]["code"], "migration_plan_changed")
		self.assertEqual(contract_path.read_bytes(), original_bytes)
		approval_required = migration.apply_contract_migration(self.project_root, plan["plan_sha256"])
		self.assertFalse(approval_required["ok"])
		self.assertEqual(approval_required["issues"][0]["code"], "human_approval_required")
		self.assertEqual(contract_path.read_bytes(), original_bytes)

		applied = migration.apply_contract_migration(
			self.project_root,
			plan["plan_sha256"],
			human_approved=True,
		)
		self.assertTrue(applied["ok"], applied)
		self.assertEqual(applied["status"], "applied")
		migrated_contract = json.loads(contract_path.read_text(encoding="utf-8"))
		self.assertEqual(migrated_contract["schema_version"], CONTRACT_SCHEMA_VERSION)
		self.assertEqual(
			migrated_contract["framework"]["capability_requirements"][0]["decision_state"],
			"pending_review",
		)
		self.assertTrue(load_contract(self.project_root)["ok"])
		migrated_snapshot = snapshot.build_snapshot(self.project_root)
		self.assertFalse(migrated_snapshot["drift"]["ok"])
		self.assertIn(
			"capability_requirement_pending_review",
			{item["code"] for item in migrated_snapshot["drift"]["issues"]},
		)
		self.assertEqual(migration.plan_contract_migration(self.project_root)["status"], "up_to_date")

	def test_contract_and_migration_reject_a_linked_contract_path(self) -> None:
		real_root = self.project_root / "contract-real"
		real_root.mkdir()
		(real_root / "project_contract.json").write_bytes(
			(self.project_root / ".gf/project_contract.json").read_bytes()
		)
		linked_root = self.project_root / "contract-link"
		create_directory_link_fixture(real_root, linked_root)

		loaded = load_contract(self.project_root, "contract-link/project_contract.json")
		plan = migration.plan_contract_migration(self.project_root, "contract-link/project_contract.json")

		self.assertFalse(loaded["ok"])
		self.assertIn("unsafe_contract_path", {item["code"] for item in loaded["issues"]})
		self.assertFalse(plan["ok"])
		self.assertEqual(plan["issues"][0]["code"], "unsafe_contract_path")

	def test_contract_migration_rejects_invalid_or_unsupported_sources_without_writing(self) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		legacy = json.loads(contract_path.read_text(encoding="utf-8"))
		legacy["schema_version"] = 1
		legacy["framework"]["required_capabilities"] = ["architecture", "architecture"]
		del legacy["framework"]["capability_requirements"]
		contract_path.write_text(json.dumps(legacy), encoding="utf-8")
		legacy_bytes = contract_path.read_bytes()

		invalid = migration.plan_contract_migration(self.project_root)
		blocked_apply = migration.apply_contract_migration(self.project_root, "0" * 64)

		self.assertFalse(invalid["ok"])
		self.assertEqual(invalid["issues"][0]["code"], "duplicate_legacy_capability")
		self.assertFalse(blocked_apply["ok"])
		self.assertEqual(contract_path.read_bytes(), legacy_bytes)

		legacy["schema_version"] = CONTRACT_SCHEMA_VERSION + 1
		contract_path.write_text(json.dumps(legacy), encoding="utf-8")
		future_bytes = contract_path.read_bytes()
		unsupported = migration.plan_contract_migration(self.project_root)

		self.assertFalse(unsupported["ok"])
		self.assertEqual(unsupported["issues"][0]["code"], "unsupported_contract_migration")
		self.assertEqual(contract_path.read_bytes(), future_bytes)

	def test_contract_migration_plan_binds_the_reviewed_target(self) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		legacy = json.loads(contract_path.read_text(encoding="utf-8"))
		legacy["schema_version"] = 1
		legacy["framework"]["required_capabilities"] = [
			item["id"] for item in legacy["framework"].pop("capability_requirements")
		]
		contract_path.write_text(json.dumps(legacy), encoding="utf-8")
		original_bytes = contract_path.read_bytes()
		plan = migration.plan_contract_migration(self.project_root)
		real_migrate = migration._migrate_v1_to_v2

		def changed_migration(source: dict[str, object]) -> tuple[dict[str, object], list[dict[str, str]]]:
			candidate, issues = real_migrate(source)
			candidate["project"]["summary"] = "A different but schema-valid migration target."
			return candidate, issues

		with mock.patch.object(migration, "_migrate_v1_to_v2", side_effect=changed_migration):
			blocked = migration.apply_contract_migration(self.project_root, plan["plan_sha256"])

		self.assertFalse(blocked["ok"])
		self.assertEqual(blocked["issues"][0]["code"], "migration_plan_changed")
		self.assertEqual(contract_path.read_bytes(), original_bytes)

	def test_contract_migration_plan_binds_the_contract_path(self) -> None:
		current = json.loads((self.project_root / ".gf/project_contract.json").read_text(encoding="utf-8"))
		current["schema_version"] = 1
		current["framework"]["required_capabilities"] = [
			item["id"] for item in current["framework"].pop("capability_requirements")
		]
		for name in ("first.json", "second.json"):
			(self.project_root / ".gf" / name).write_text(json.dumps(current), encoding="utf-8")
		plan = migration.plan_contract_migration(self.project_root, ".gf/first.json")

		blocked = migration.apply_contract_migration(
			self.project_root,
			plan["plan_sha256"],
			".gf/second.json",
			human_approved=True,
		)

		self.assertFalse(blocked["ok"])
		self.assertEqual(blocked["issues"][0]["code"], "migration_plan_changed")
		self.assertEqual(json.loads((self.project_root / ".gf/second.json").read_text(encoding="utf-8"))["schema_version"], 1)

	def test_contract_migration_validates_current_contract_and_rejects_apply_without_pending_plan(self) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		contract = json.loads(contract_path.read_text(encoding="utf-8"))
		contract["project"]["summary"] = ""
		contract_path.write_text(json.dumps(contract), encoding="utf-8")

		invalid_current = migration.plan_contract_migration(self.project_root)
		invalid_authorization = migration.apply_contract_migration(self.project_root, "not-a-hash")

		self.assertFalse(invalid_current["ok"])
		self.assertEqual(invalid_current["issues"][0]["code"], "min_length")
		self.assertFalse(invalid_authorization["ok"])
		self.assertEqual(invalid_authorization["issues"][0]["code"], "invalid_expected_plan_sha256")

		contract["project"]["summary"] = "Valid current contract."
		contract_path.write_text(json.dumps(contract), encoding="utf-8")
		no_pending = migration.apply_contract_migration(self.project_root, "0" * 64)

		self.assertFalse(no_pending["ok"])
		self.assertEqual(no_pending["issues"][0]["code"], "no_pending_contract_migration")

	def test_atomic_compare_exchange_rejects_a_changed_source_and_reparse_parent(self) -> None:
		path = self.project_root / ".gf/compare.json"
		path.write_text('{"value": 1}', encoding="utf-8")
		expected_sha256 = paths.sha256_json({"value": 1})
		with mock.patch.object(
			paths,
			"_json_sha256_at_path",
			side_effect=[expected_sha256, paths.sha256_json({"value": 2})],
		):
			with self.assertRaisesRegex(paths.CompareExchangeError, "changed during compare-exchange"):
				paths.atomic_compare_exchange_json(path, expected_sha256, {"value": 3})

		real_root = self.project_root / "write-real"
		real_root.mkdir()
		linked_root = self.project_root / "write-link"
		create_directory_link_fixture(real_root, linked_root)
		with self.assertRaisesRegex(ValueError, "linked or reparsed"):
			paths.atomic_write_json(linked_root / "blocked.json", {"blocked": True})

	def test_cli_contract_migration_round_trip_uses_reviewed_hash(self) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		legacy = json.loads(contract_path.read_text(encoding="utf-8"))
		legacy["schema_version"] = 1
		legacy["framework"]["required_capabilities"] = [
			item["id"] for item in legacy["framework"].pop("capability_requirements")
		]
		contract_path.write_text(json.dumps(legacy), encoding="utf-8")
		cli = ADDON_ROOT / "gf_ai_project.py"

		planned = subprocess.run(
			[sys.executable, str(cli), "contract-migration-plan", "--project-root", str(self.project_root)],
			capture_output=True,
			text=True,
			encoding="utf-8",
			timeout=30,
			check=False,
		)
		plan = json.loads(planned.stdout)
		self.assertEqual(planned.returncode, 0, planned.stderr)
		self.assertEqual(plan["status"], "ready")

		applied = subprocess.run(
			[
				sys.executable,
				str(cli),
				"contract-migrate",
				"--project-root",
				str(self.project_root),
				"--expected-plan-sha256",
				plan["plan_sha256"],
			],
			capture_output=True,
			text=True,
			encoding="utf-8",
			timeout=30,
			check=False,
		)

		blocked = json.loads(applied.stdout)
		self.assertEqual(applied.returncode, 1, applied.stderr)
		self.assertEqual(blocked["issues"][0]["code"], "interactive_approval_required")
		self.assertEqual(json.loads(contract_path.read_text(encoding="utf-8"))["schema_version"], 1)
		core_applied = migration.apply_contract_migration(
			self.project_root,
			plan["plan_sha256"],
			human_approved=True,
		)
		self.assertTrue(core_applied["ok"], core_applied)
		self.assertEqual(json.loads(contract_path.read_text(encoding="utf-8"))["schema_version"], CONTRACT_SCHEMA_VERSION)

	def test_context_bundle_plan_and_export_are_content_bound_and_schema_valid(self) -> None:
		(self.project_root / "scripts").mkdir()
		(self.project_root / "scripts/player.gd").write_bytes("extends Node\nvar icon := \"🧭\"\n".encode("utf-8"))
		project_source = (self.project_root / "project.godot").read_text(encoding="utf-8")
		(self.project_root / "project.godot").write_text(
			project_source + '\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',
			encoding="utf-8",
		)

		plan = context_bundle.plan_context_bundle(
			self.project_root,
			["scripts/player.gd"],
			["rendering/renderer/rendering_method"],
		)

		self.assertTrue(plan["ok"], plan)
		self.assertEqual(plan["generator_version"], TOOL_VERSION)
		self.assertNotIn("content", plan["files"][0])
		self.assertNotIn("serialized_value", plan["settings"][0])
		self.assertEqual(plan, context_bundle.plan_context_bundle(
			self.project_root,
			["scripts/player.gd"],
			["rendering/renderer/rendering_method"],
		))
		exported = context_bundle.export_context_bundle(
			self.project_root,
			["scripts/player.gd"],
			["rendering/renderer/rendering_method"],
			plan["plan_sha256"],
			human_approved=True,
		)
		self.assertTrue(exported["ok"], exported)
		bundle_path = self.project_root / exported["output"]
		bundle = json.loads(bundle_path.read_text(encoding="utf-8"))
		self.assertEqual(bundle["files"][0]["content"], "extends Node\nvar icon := \"🧭\"\n")
		self.assertEqual(bundle["settings"][0]["serialized_value"], '"gl_compatibility"')
		self.assertTrue(bundle["untrusted_content"])
		self.assertEqual(
			validate_schema_file(bundle, ADDON_ROOT / "schemas/editor_context_bundle.schema.json"),
			[],
		)

	def test_context_bundle_captures_complete_multiline_project_setting(self) -> None:
		project_source = (self.project_root / "project.godot").read_text(encoding="utf-8")
		(self.project_root / "project.godot").write_text(
			project_source
			+ (
				"\n[debug]\n"
				"gdscript/warnings/directory_rules={\n"
				'"res://addons/gf": 1,\n'
				'"res://addons/gut": 0,\n'
				'"marker": "};#"\n'
				"}\n"
			),
			encoding="utf-8",
		)
		setting_name = "debug/gdscript/warnings/directory_rules"
		plan = context_bundle.plan_context_bundle(self.project_root, [], [setting_name])

		exported = context_bundle.export_context_bundle(
			self.project_root,
			[],
			[setting_name],
			plan["plan_sha256"],
			human_approved=True,
		)
		bundle = json.loads((self.project_root / exported["output"]).read_text(encoding="utf-8"))

		self.assertEqual(
			bundle["settings"][0]["serialized_value"],
			'{\n"res://addons/gf": 1,\n"res://addons/gut": 0,\n"marker": "};#"\n}',
		)

	def test_context_bundle_excludes_setting_comments_from_export_and_plan_hash(self) -> None:
		project_source = (self.project_root / "project.godot").read_text(encoding="utf-8")
		setting_source = (
			"\n[debug]\n"
			"commented={ ; opening comment\n"
			'"literal": "#; keep", ; inline comment\n'
			"# comment-only line\n"
			'"value": 1 # hash comment\n'
			"} ; closing comment\n"
		)
		(self.project_root / "project.godot").write_text(
			project_source + setting_source,
			encoding="utf-8",
		)
		setting_name = "debug/commented"
		first_plan = context_bundle.plan_context_bundle(self.project_root, [], [setting_name])

		(self.project_root / "project.godot").write_text(
			project_source
			+ setting_source.replace("opening comment", "changed opening comment")
			.replace("inline comment", "changed inline comment")
			.replace("comment-only line", "changed comment-only line")
			.replace("hash comment", "changed hash comment")
			.replace("closing comment", "changed closing comment"),
			encoding="utf-8",
		)
		second_plan = context_bundle.plan_context_bundle(self.project_root, [], [setting_name])
		self.assertEqual(first_plan["plan_sha256"], second_plan["plan_sha256"])
		exported = context_bundle.export_context_bundle(
			self.project_root,
			[],
			[setting_name],
			first_plan["plan_sha256"],
			human_approved=True,
		)
		self.assertTrue(exported["ok"], exported)
		bundle = json.loads((self.project_root / exported["output"]).read_text(encoding="utf-8"))

		self.assertEqual(
			bundle["settings"][0]["serialized_value"],
			'{\n"literal": "#; keep",\n"value": 1\n}',
		)

	def test_context_bundle_rejects_incomplete_project_setting(self) -> None:
		project_source = (self.project_root / "project.godot").read_text(encoding="utf-8")
		(self.project_root / "project.godot").write_text(
			project_source + '\n[debug]\nbroken={\n"value": 1\n',
			encoding="utf-8",
		)

		with self.assertRaisesRegex(ValueError, "setting value is incomplete"):
			context_bundle.plan_context_bundle(self.project_root, [], ["debug/broken"])

	def test_context_bundle_refuses_stale_unsafe_binary_and_self_inputs(self) -> None:
		(self.project_root / "selected.txt").write_text("before", encoding="utf-8")
		plan = context_bundle.plan_context_bundle(self.project_root, ["selected.txt"], [])
		(self.project_root / "selected.txt").write_text("after", encoding="utf-8")

		stale = context_bundle.export_context_bundle(
			self.project_root,
			["selected.txt"],
			[],
			plan["plan_sha256"],
			human_approved=True,
		)

		self.assertFalse(stale["ok"])
		self.assertEqual(stale["status"], "stale")
		self.assertFalse((self.project_root / ".gf/ai/context" / f"{plan['plan_sha256']}.json").exists())
		(self.project_root / "binary.dat").write_bytes(b"\xff\x00")
		with self.assertRaisesRegex(ValueError, "valid UTF-8"):
			context_bundle.plan_context_bundle(self.project_root, ["binary.dat"], [])
		with self.assertRaisesRegex(ValueError, "unsafe or non-portable"):
			context_bundle.plan_context_bundle(self.project_root, ["../outside.txt"], [])
		with self.assertRaisesRegex(ValueError, "output files cannot be selected"):
			context_bundle.plan_context_bundle(
				self.project_root,
				[".gf/ai/context/already.json"],
				[],
			)
		with self.assertRaisesRegex(ValueError, "output files cannot be selected"):
			context_bundle.plan_context_bundle(
				self.project_root,
				[".GF/AI/CONTEXT/already.json"],
				[],
			)

	def test_context_bundle_rejects_case_collisions_missing_settings_and_links(self) -> None:
		(self.project_root / "Case.txt").write_text("case", encoding="utf-8")
		with self.assertRaisesRegex(ValueError, "case-colliding"):
			context_bundle.plan_context_bundle(self.project_root, ["Case.txt", "case.txt"], [])
		with self.assertRaisesRegex(ValueError, "were not found"):
			context_bundle.plan_context_bundle(self.project_root, [], ["application/missing"])
		real_root = self.project_root / "context-real"
		real_root.mkdir()
		(real_root / "linked.txt").write_text("linked", encoding="utf-8")
		linked_root = self.project_root / "context-link"
		create_directory_link_fixture(real_root, linked_root)
		with self.assertRaisesRegex(ValueError, "filesystem link"):
			context_bundle.plan_context_bundle(self.project_root, ["context-link/linked.txt"], [])

	def test_context_bundle_cli_requires_the_exact_interactive_phrase(self) -> None:
		plan_sha256 = "b" * 64
		plan = {"plan_sha256": plan_sha256, "files": [], "settings": [], "total_bytes": 0}
		with (
			mock.patch("sys.stdin.isatty", return_value=True),
			mock.patch("sys.stdout.isatty", return_value=True),
			mock.patch("builtins.input", return_value=f"EXPORT {plan_sha256}"),
			mock.patch("sys.stderr", io.StringIO()),
		):
			self.assertTrue(cli._confirm_context_export(plan, plan_sha256))
		with (
			mock.patch("sys.stdin.isatty", return_value=True),
			mock.patch("sys.stdout.isatty", return_value=True),
			mock.patch("builtins.input", return_value=plan_sha256),
			mock.patch("sys.stderr", io.StringIO()),
		):
			self.assertFalse(cli._confirm_context_export(plan, plan_sha256))

	def test_cli_contract_migrate_rejects_when_contract_is_current(self) -> None:
		cli = ADDON_ROOT / "gf_ai_project.py"

		completed = subprocess.run(
			[
				sys.executable,
				str(cli),
				"contract-migrate",
				"--project-root",
				str(self.project_root),
				"--expected-plan-sha256",
				"0" * 64,
			],
			capture_output=True,
			text=True,
			encoding="utf-8",
			timeout=30,
			check=False,
		)

		result = json.loads(completed.stdout)
		self.assertEqual(completed.returncode, 1, completed.stderr)
		self.assertFalse(result["ok"])
		self.assertEqual(result["issues"][0]["code"], "no_pending_contract_migration")

	def test_cli_contract_migration_requires_the_exact_interactive_phrase(self) -> None:
		plan_sha256 = "a" * 64
		plan = {"plan_sha256": plan_sha256, "candidate": {"schema_version": CONTRACT_SCHEMA_VERSION}}
		with (
			mock.patch("sys.stdin.isatty", return_value=True),
			mock.patch("sys.stdout.isatty", return_value=True),
			mock.patch("builtins.input", return_value=f"MIGRATE {plan_sha256}"),
			mock.patch("sys.stderr", io.StringIO()),
		):
			self.assertTrue(cli._confirm_contract_migration(plan, plan_sha256))
		with (
			mock.patch("sys.stdin.isatty", return_value=True),
			mock.patch("sys.stdout.isatty", return_value=True),
			mock.patch("builtins.input", return_value=plan_sha256),
			mock.patch("sys.stderr", io.StringIO()),
		):
			self.assertFalse(cli._confirm_contract_migration(plan, plan_sha256))

	def test_contract_rejects_ambiguous_component_ids_and_ownership_roots(self) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		contract = json.loads(contract_path.read_text(encoding="utf-8"))
		contract["architecture"]["modules"] = [
			{
				"id": "platform",
				"responsibility": "Project platform facade",
				"roots": ["res://features"],
				"allowed_dependencies": [],
				"forbidden_dependencies": [],
				"ownership": "project",
			},
			{
				"id": "ui",
				"responsibility": "Project UI",
				"roots": ["res://features/ui"],
				"allowed_dependencies": [],
				"forbidden_dependencies": [],
				"ownership": "project",
			},
		]
		contract["framework"]["adapter_boundaries"] = [
			{
				"id": "platform",
				"provider": "example",
				"project_root": "res://adapters/example",
				"responsibility": "External provider integration",
			}
		]
		contract_path.write_text(json.dumps(contract), encoding="utf-8")

		result = load_contract(self.project_root)
		codes = {item["code"] for item in result["issues"]}

		self.assertFalse(result["ok"])
		self.assertIn("ambiguous_component_id", codes)
		self.assertIn("ownership_root_overlap", codes)

	def test_contract_rejects_unsafe_paths_and_legacy_shell_commands(self) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		contract = json.loads(contract_path.read_text(encoding="utf-8"))
		contract["verification"]["required_paths"] = ["../outside.txt"]
		contract_path.write_text(json.dumps(contract), encoding="utf-8")

		unsafe = load_contract(self.project_root)
		self.assertIn("unsafe_project_path", {item["code"] for item in unsafe["issues"]})

		contract = json.loads(contract_path.read_text(encoding="utf-8"))
		contract["verification"] = {
			"commands": ["godot --headless --editor --quit"],
			"required_paths": ["project.godot"],
		}
		contract_path.write_text(json.dumps(contract), encoding="utf-8")
		legacy = load_contract(self.project_root)

		self.assertFalse(legacy["ok"])
		self.assertTrue(any(item["path"] == "$.verification.commands" for item in legacy["issues"]))

	def test_snapshot_reports_declared_and_observed_drift(self) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		contract = json.loads(contract_path.read_text(encoding="utf-8"))
		contract["framework"]["required_packages"].append("gf.standard.storage")
		contract["architecture"]["modules"] = [
			{
				"id": "gameplay",
				"responsibility": "Project gameplay",
				"roots": ["res://features/gameplay"],
				"allowed_dependencies": [],
				"forbidden_dependencies": [],
				"ownership": "project",
			}
		]
		contract_path.write_text(json.dumps(contract, ensure_ascii=False), encoding="utf-8")

		report = snapshot.build_snapshot(self.project_root)
		codes = {item["code"] for item in report["drift"]["issues"]}

		self.assertFalse(report["drift"]["ok"])
		self.assertIn("required_package_missing", codes)
		self.assertIn("declared_module_root_missing", codes)
		self.assertEqual(
			validate_schema_file(report, SCHEMA_ROOT / "project_snapshot.schema.json"),
			[],
		)

	def test_snapshot_reports_versioned_capability_readiness_without_inferring_intent(self) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		contract = json.loads(contract_path.read_text(encoding="utf-8"))
		contract["framework"]["required_packages"].append("gf.extension.save")
		contract["framework"]["capability_requirements"].append({
			"id": "storage-save",
			"decision_state": "confirmed",
			"owner": "project",
			"recipes": ["save-profile"],
			"acceptance": ["Interrupted writes preserve the previous committed generation."],
			"notes": "",
		})
		contract_path.write_text(json.dumps(contract, ensure_ascii=False), encoding="utf-8")

		report = snapshot.build_snapshot(self.project_root)
		readiness = {item["id"]: item for item in report["framework"]["capability_readiness"]}

		self.assertEqual(report["schema_version"], SNAPSHOT_SCHEMA_VERSION)
		self.assertEqual(report["generator_version"], TOOL_VERSION)
		self.assertEqual(report["contract"]["schema_version"], CONTRACT_SCHEMA_VERSION)
		self.assertFalse(report["contract"]["migration_required"])
		self.assertEqual(readiness["architecture"]["status"], "available_unobserved")
		self.assertEqual(readiness["storage-save"]["status"], "unavailable")
		self.assertEqual(readiness["storage-save"]["owner"], "project")
		self.assertEqual(readiness["storage-save"]["recipes"], ["save-profile"])
		self.assertEqual(readiness["storage-save"]["acceptance_count"], 1)
		self.assertIn("gf.extension.save", readiness["storage-save"]["missing_recipe_all_of_packages"])
		self.assertIn("required_capability_unavailable", {item["code"] for item in report["drift"]["issues"]})
		self.assertEqual(validate_schema_file(report, SCHEMA_ROOT / "project_snapshot.schema.json"), [])

	def test_capability_readiness_bounds_recipe_package_and_class_evidence(self) -> None:
		class_names = [f"GFStress{index}" for index in range(100)]
		package_ids = [f"gf.test.package_{index}" for index in range(50)]
		api_index = {
			"classes": {
				class_name: {"package_id": package_ids[index % len(package_ids)]}
				for index, class_name in enumerate(class_names)
			}
		}
		contract_data = {
			"framework": {
				"capability_requirements": [{
					"id": "stress",
					"decision_state": "confirmed",
					"owner": "project",
					"recipes": ["stress-recipe"],
					"acceptance": [],
					"notes": "",
				}],
			}
		}
		with (
			mock.patch.object(catalog, "capability_records_by_id", return_value={
				"stress": {"packages": ["gf.kernel"], "primary_classes": class_names},
			}),
			mock.patch.object(catalog, "recipe_records_by_id", return_value={
				"stress-recipe": {
					"primary_classes": class_names,
					"package_requirements": {"all_of": package_ids, "any_of": []},
				},
			}),
			mock.patch.object(catalog, "load_api_index", return_value=api_index),
		):
			readiness = snapshot._build_capability_readiness(
				{"ok": True},
				contract_data,
				["gf.kernel", *package_ids],
				{"gf_api_usage": class_names, "source_scan_complete": True},
			)[0]

		self.assertEqual(readiness["recipe_all_of_package_count"], 50)
		self.assertEqual(len(readiness["recipe_all_of_packages"]), 40)
		self.assertTrue(readiness["recipe_all_of_packages_truncated"])
		self.assertEqual(readiness["observed_class_count"], 100)
		self.assertEqual(len(readiness["observed_classes"]), 80)
		self.assertTrue(readiness["observed_classes_truncated"])

	def test_provider_backend_recipe_accepts_one_explicit_provider_package(self) -> None:
		contract_data = {
			"framework": {
				"capability_requirements": [{
					"id": "audio",
					"decision_state": "confirmed",
					"owner": "project",
					"recipes": ["provider-backend"],
					"acceptance": ["Audio provider failures map to a stable project-facing result."],
					"notes": "",
				}],
			}
		}

		readiness = snapshot._build_capability_readiness(
			{"ok": True},
			contract_data,
			["gf.standard.audio"],
			{"gf_api_usage": [], "source_scan_complete": True},
		)[0]

		self.assertEqual(readiness["status"], "available_unobserved")
		self.assertEqual(readiness["recipe_all_of_packages"], [])
		self.assertEqual(
			readiness["recipe_any_of_package_groups"],
			[["gf.extension.network", "gf.standard.audio", "gf.standard.storage"]],
		)
		self.assertEqual(readiness["unsatisfied_recipe_any_of_package_groups"], [])

	def test_new_recipe_package_readiness_matches_declared_requirements(self) -> None:
		render_group = [["gf.extension.feedback", "gf.standard.assets", "gf.standard.display"]]
		artifact_packages = [
			"gf.extension.content_package",
			"gf.standard.debug",
			"gf.standard.spatial",
		]
		cases = [
			{
				"recipe_id": "bounded-runtime-work",
				"available": ["gf.standard.base"],
				"satisfied": True,
				"all_of": ["gf.standard.base"],
				"missing_all_of": [],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
			{
				"recipe_id": "bounded-runtime-work",
				"available": ["gf.kernel"],
				"satisfied": False,
				"all_of": ["gf.standard.base"],
				"missing_all_of": ["gf.standard.base"],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
			{
				"recipe_id": "undoable-command-history",
				"available": ["gf.standard.storage"],
				"satisfied": True,
				"all_of": ["gf.standard.storage"],
				"missing_all_of": [],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
			{
				"recipe_id": "undoable-command-history",
				"available": ["gf.standard.base"],
				"satisfied": False,
				"all_of": ["gf.standard.storage"],
				"missing_all_of": ["gf.standard.storage"],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
			{
				"recipe_id": "scalable-ui-collection",
				"available": ["gf.standard.ui"],
				"satisfied": True,
				"all_of": ["gf.standard.ui"],
				"missing_all_of": [],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
			{
				"recipe_id": "scalable-ui-collection",
				"available": ["gf.standard.ui.state"],
				"satisfied": True,
				"all_of": ["gf.standard.ui"],
				"missing_all_of": [],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
			{
				"recipe_id": "scalable-ui-collection",
				"available": ["gf.kernel"],
				"satisfied": False,
				"all_of": ["gf.standard.ui"],
				"missing_all_of": ["gf.standard.ui"],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
			*[
				{
					"recipe_id": "render-feedback-orchestration",
					"available": [package_id],
					"satisfied": True,
					"all_of": [],
					"missing_all_of": [],
					"any_of": render_group,
					"unsatisfied_any_of": [],
				}
				for package_id in (
					"gf.standard.display",
					"gf.standard.assets",
					"gf.extension.feedback",
				)
			],
			{
				"recipe_id": "render-feedback-orchestration",
				"available": ["gf.standard.base"],
				"satisfied": False,
				"all_of": [],
				"missing_all_of": [],
				"any_of": render_group,
				"unsatisfied_any_of": render_group,
			},
			{
				"recipe_id": "external-artifact-export",
				"available": artifact_packages,
				"satisfied": True,
				"all_of": artifact_packages,
				"missing_all_of": [],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
			{
				"recipe_id": "external-artifact-export",
				"available": [
					"gf.extension.content_package",
					"gf.standard.spatial",
				],
				"satisfied": False,
				"all_of": artifact_packages,
				"missing_all_of": ["gf.standard.debug"],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
			{
				"recipe_id": "periodic-environment-presentation",
				"available": ["gf.standard.display"],
				"satisfied": True,
				"all_of": ["gf.standard.display"],
				"missing_all_of": [],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
			{
				"recipe_id": "periodic-environment-presentation",
				"available": ["gf.standard.base"],
				"satisfied": False,
				"all_of": ["gf.standard.display"],
				"missing_all_of": ["gf.standard.display"],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
			{
				"recipe_id": "headless-health-probe",
				"available": ["gf.extension.network"],
				"satisfied": True,
				"all_of": ["gf.extension.network"],
				"missing_all_of": [],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
			{
				"recipe_id": "headless-health-probe",
				"available": ["gf.standard.debug"],
				"satisfied": False,
				"all_of": ["gf.extension.network"],
				"missing_all_of": ["gf.extension.network"],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
			{
				"recipe_id": "physics-backend-adapter",
				"available": ["gf.standard.base"],
				"satisfied": False,
				"all_of": ["gf.standard.diagnostics"],
				"missing_all_of": ["gf.standard.diagnostics"],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
			{
				"recipe_id": "physics-backend-adapter",
				"available": ["gf.standard.diagnostics"],
				"satisfied": True,
				"all_of": ["gf.standard.diagnostics"],
				"missing_all_of": [],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
			{
				"recipe_id": "achievement-composition",
				"available": [
					"gf.extension.domain",
					"gf.extension.save",
					"gf.standard.assets",
					"gf.standard.platform",
				],
				"satisfied": True,
				"all_of": [
					"gf.extension.domain",
					"gf.extension.save",
					"gf.standard.assets",
					"gf.standard.platform",
				],
				"missing_all_of": [],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
			{
				"recipe_id": "achievement-composition",
				"available": [
					"gf.extension.domain",
					"gf.extension.save",
					"gf.standard.assets",
				],
				"satisfied": False,
				"all_of": [
					"gf.extension.domain",
					"gf.extension.save",
					"gf.standard.assets",
					"gf.standard.platform",
				],
				"missing_all_of": ["gf.standard.platform"],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
			{
				"recipe_id": "environment-query-composition",
				"available": [
					"gf.extension.decision",
					"gf.standard.diagnostics",
					"gf.standard.spatial",
				],
				"satisfied": True,
				"all_of": [
					"gf.extension.decision",
					"gf.standard.diagnostics",
					"gf.standard.spatial",
				],
				"missing_all_of": [],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
			{
				"recipe_id": "environment-query-composition",
				"available": [
					"gf.extension.decision",
					"gf.standard.spatial",
				],
				"satisfied": False,
				"all_of": [
					"gf.extension.decision",
					"gf.standard.diagnostics",
					"gf.standard.spatial",
				],
				"missing_all_of": ["gf.standard.diagnostics"],
				"any_of": [],
				"unsatisfied_any_of": [],
			},
		]

		for case in cases:
			with self.subTest(recipe_id=case["recipe_id"], available=case["available"]):
				readiness = catalog.recipe_package_readiness(
					[case["recipe_id"]],
					case["available"],
				)
				for field in (
					"satisfied",
					"all_of",
					"missing_all_of",
					"any_of",
					"unsatisfied_any_of",
				):
					self.assertEqual(readiness[field], case[field], readiness)

	def test_snapshot_uses_canonical_lockfile_and_exact_editor_plugin_section(self) -> None:
		project_source = (
			'[application]\nconfig/name="res://addons/gf/plugin.cfg"\n\n'
			'[editor_plugins]\nenabled=PackedStringArray("res://addons/gf/plugin.cfg")\n'
			'[not_gf]\nextensions/enabled=PackedStringArray("gf.extension.wrong")\n'
			'[gf]\nextensions/enabled=Array[String](["gf.save", "gf.action_queue"])\n'
		)
		(self.project_root / "project.godot").write_text(project_source, encoding="utf-8")

		report = snapshot.build_snapshot(self.project_root)

		self.assertEqual(report["framework"]["packages"], ["gf.kernel"])
		self.assertEqual(report["framework"]["package_state"]["source"], "lockfile")
		self.assertTrue(report["framework"]["package_state"]["valid"])
		self.assertTrue(report["framework"]["plugin_enabled"])
		self.assertTrue(report["framework"]["catalog_matches_framework"])
		self.assertEqual(report["framework"]["extensions"], ["gf.action_queue", "gf.save"])
		lockfile_path = self.project_root / ".gf/packages.lock.json"
		lockfile = json.loads(lockfile_path.read_text(encoding="utf-8"))
		lockfile.pop("framework_version")
		lockfile_path.write_text(json.dumps(lockfile), encoding="utf-8")
		invalid_lockfile = catalog.installed_package_report(self.project_root)
		self.assertFalse(invalid_lockfile["valid"])
		self.assertIn("framework_version", invalid_lockfile["issues"][0])
		self.assertEqual(invalid_lockfile["packages"], [])

	def test_package_lockfile_requires_the_formal_closed_entry_schema(self) -> None:
		lockfile_path = self.project_root / ".gf/packages.lock.json"
		baseline = json.loads(lockfile_path.read_text(encoding="utf-8"))
		cases: dict[str, dict[str, Any]] = {}

		boolean_schema = copy.deepcopy(baseline)
		boolean_schema["schema_version"] = True
		cases["boolean_schema"] = boolean_schema
		unknown_root = copy.deepcopy(baseline)
		unknown_root["legacy_hint"] = True
		cases["unknown_root"] = unknown_root
		empty_entry = copy.deepcopy(baseline)
		empty_entry["installed"]["gf.kernel"] = {}
		cases["empty_entry"] = empty_entry
		wrong_version = copy.deepcopy(baseline)
		wrong_version["installed"]["gf.kernel"]["version"] = "0.0.0"
		cases["wrong_version"] = wrong_version
		unknown_entry_field = copy.deepcopy(baseline)
		unknown_entry_field["installed"]["gf.kernel"]["legacy_hint"] = "trusted"
		cases["unknown_entry_field"] = unknown_entry_field
		missing_metadata = copy.deepcopy(baseline)
		missing_metadata["installed"]["gf.kernel"].pop("file_metadata")
		cases["missing_metadata"] = missing_metadata
		boolean_size = copy.deepcopy(baseline)
		boolean_size["installed"]["gf.kernel"]["file_metadata"]["addons/gf/plugin.cfg"][
			"size_bytes"
		] = True
		cases["boolean_size"] = boolean_size

		for name, lockfile in cases.items():
			with self.subTest(name=name):
				lockfile_path.write_text(json.dumps(lockfile), encoding="utf-8")
				report = catalog.installed_package_report(self.project_root)
				self.assertFalse(report["valid"], report)
				self.assertEqual(report["packages"], [], report)
				self.assertFalse(catalog.package_by_id("gf.kernel", 1, self.project_root)["installed"])

	def test_invalid_package_lockfile_never_populates_snapshot_readiness_facts(self) -> None:
		lockfile_path = self.project_root / ".gf/packages.lock.json"
		lockfile = json.loads(lockfile_path.read_text(encoding="utf-8"))
		lockfile["installed"]["gf.kernel"]["version"] = "0.0.0"
		lockfile_path.write_text(json.dumps(lockfile), encoding="utf-8")

		report = snapshot.build_snapshot(self.project_root)

		self.assertFalse(report["framework"]["package_state"]["valid"])
		self.assertEqual(report["framework"]["packages"], [])
		for readiness in report["framework"]["capability_readiness"]:
			self.assertEqual(readiness["installed_catalog_packages"], [], readiness)

	def test_package_lockfile_must_include_transitive_dependencies(self) -> None:
		lockfile_path = self.project_root / ".gf/packages.lock.json"
		lockfile = json.loads(lockfile_path.read_text(encoding="utf-8"))
		lockfile["installed"]["gf.extension.save"] = {"version": catalog.catalog_framework_version()}
		lockfile_path.write_text(json.dumps(lockfile), encoding="utf-8")

		report = catalog.installed_package_report(self.project_root)

		self.assertFalse(report["valid"])
		self.assertIn(
			"gf.standard.storage",
			"\n".join(report["issues"]),
		)

	def test_snapshot_source_scan_prunes_framework_and_reports_budget_truncation(self) -> None:
		source_root = self.project_root / "src"
		source_root.mkdir()
		(source_root / "a.gd").write_text(
			'extends Node\nvar value := GFArchitecture.new()\n'
			'# GFSettingsUtility must not count from a comment.\n'
			'var label := "GFStorageUtility"\n',
			encoding="utf-8",
		)
		(source_root / "b.gd").write_text("extends Node\n", encoding="utf-8")
		(self.project_root / "addons/gf/ignored.gd").write_text("class_name GFShouldNotBeScanned\n", encoding="utf-8")

		with mock.patch.object(snapshot, "_MAX_PROJECT_SCRIPTS", 1):
			report = snapshot.build_snapshot(self.project_root)

		self.assertEqual(report["project"]["script_count"], 1)
		self.assertEqual(report["project"]["scanned_script_count"], 1)
		self.assertTrue(report["project"]["source_scan_truncated"])
		self.assertEqual(report["project"]["source_scan_truncation_reason"], "script_count")
		self.assertFalse(report["project"]["source_scan_complete"])
		self.assertIn("GFArchitecture", report["project"]["gf_api_usage"])
		self.assertNotIn("GFSettingsUtility", report["project"]["gf_api_usage"])
		self.assertNotIn("GFStorageUtility", report["project"]["gf_api_usage"])

	def test_snapshot_source_scan_has_a_total_byte_budget(self) -> None:
		source_root = self.project_root / "src"
		source_root.mkdir()
		(source_root / "a.gd").write_text("extends Node\nvar first := GFArchitecture.new()\n", encoding="utf-8")
		(source_root / "b.gd").write_text("extends Node\nvar second := GFStorageUtility.new()\n", encoding="utf-8")
		first_size = (source_root / "a.gd").stat().st_size

		with mock.patch.object(snapshot, "_MAX_SOURCE_SCAN_BYTES", first_size):
			report = snapshot.build_snapshot(self.project_root)

		self.assertTrue(report["project"]["source_scan_truncated"])
		self.assertEqual(report["project"]["source_scan_truncation_reason"], "byte_budget")
		self.assertEqual(report["project"]["scanned_script_count"], 1)
		self.assertEqual(report["project"]["scanned_script_bytes"], first_size)
		self.assertEqual(report["project"]["gf_api_usage"], ["GFArchitecture"])
		self.assertFalse(report["project"]["source_scan_complete"])

	def test_snapshot_source_scan_separates_tests_and_fails_closed_on_skipped_sources(self) -> None:
		source_root = self.project_root / "src"
		test_root = self.project_root / "Tests"
		source_root.mkdir()
		test_root.mkdir()
		(source_root / "large.gd").write_text(
			"extends Node\nvar architecture := GFArchitecture.new()\n" + ("# padding\n" * 20),
			encoding="utf-8",
		)
		(test_root / "test_architecture.gd").write_text(
			"extends Node\nvar architecture := GFArchitecture.new()\n",
			encoding="utf-8",
		)

		with mock.patch.object(snapshot, "_MAX_SCRIPT_BYTES", 80):
			report = snapshot.build_snapshot(self.project_root)

		readiness = {item["id"]: item for item in report["framework"]["capability_readiness"]}
		self.assertEqual(report["project"]["script_count"], 2)
		self.assertEqual(report["project"]["scanned_script_count"], 1)
		self.assertEqual(report["project"]["test_script_count"], 1)
		self.assertEqual(report["project"]["skipped_large_script_count"], 1)
		self.assertFalse(report["project"]["source_scan_complete"])
		self.assertEqual(report["project"]["gf_api_usage"], [])
		self.assertEqual(report["project"]["test_gf_api_usage"], ["GFArchitecture"])
		self.assertEqual(readiness["architecture"]["status"], "evidence_incomplete")

	def test_module_dependency_analysis_accepts_declared_class_and_resource_edges(self) -> None:
		self._set_modules([
			self._module("core", allowed=["shared"]),
			self._module("shared"),
		])
		shared_root = self.project_root / "features/shared"
		(shared_root / "shared_type.gd").write_text(
			"class_name SharedType\nextends RefCounted\n",
			encoding="utf-8",
		)
		(shared_root / "data.tres").write_text("[gd_resource format=3]\n", encoding="utf-8")
		(self.project_root / "features/core/use_shared.gd").write_text(
			'extends Node\nvar value: SharedType\nconst DATA = preload("res://features/shared/data.tres")\n',
			encoding="utf-8",
		)

		report = snapshot.build_snapshot(self.project_root)
		analysis = report["project"]["module_dependency_analysis"]

		self.assertEqual(analysis["status"], "complete")
		self.assertEqual(len(analysis["edges"]), 1)
		self.assertEqual(analysis["edges"][0]["source_module"], "core")
		self.assertEqual(analysis["edges"][0]["target_module"], "shared")
		self.assertEqual(analysis["edges"][0]["kinds"], ["class_name", "resource_path"])
		self.assertNotIn("undeclared_module_dependency", {item["code"] for item in report["drift"]["issues"]})
		self.assertEqual(validate_schema_file(report, SCHEMA_ROOT / "project_snapshot.schema.json"), [])

	def test_module_dependency_analysis_accepts_adapter_targets_without_emitting_adapter_source_edges(
		self,
	) -> None:
		self._set_modules([self._module("core", allowed=["platform_adapter"])])
		self._set_adapter_boundaries([self._adapter("platform_adapter")])
		adapter_root = self.project_root / "adapters/platform_adapter"
		adapter_root.mkdir(parents=True)
		(adapter_root / "client.gd").write_text(
			"class_name PlatformAdapterClient\n"
			"extends RefCounted\n"
			"var project_type: CoreProjectType\n",
			encoding="utf-8",
		)
		(adapter_root / "settings.tres").write_text(
			"[gd_resource format=3]\n",
			encoding="utf-8",
		)
		(self.project_root / "features/core/use_adapter.gd").write_text(
			"class_name CoreProjectType\n"
			"extends Node\n"
			"var client: PlatformAdapterClient\n"
			'const SETTINGS = preload("res://adapters/platform_adapter/settings.tres")\n',
			encoding="utf-8",
		)

		report = snapshot.build_snapshot(self.project_root)
		analysis = report["project"]["module_dependency_analysis"]
		drift_codes = {item["code"] for item in report["drift"]["issues"]}

		self.assertEqual(analysis["status"], "complete")
		self.assertEqual(
			analysis["edges"],
			[{
				"source_module": "core",
				"target_module": "platform_adapter",
				"reference_count": 2,
				"kinds": ["class_name", "resource_path"],
				"evidence_truncated": False,
				"evidence": [
					{
						"source_path": "res://features/core/use_adapter.gd",
						"target_path": "res://adapters/platform_adapter/client.gd",
						"kind": "class_name",
						"symbol": "PlatformAdapterClient",
						"line": 3,
					},
					{
						"source_path": "res://features/core/use_adapter.gd",
						"target_path": "res://adapters/platform_adapter/settings.tres",
						"kind": "resource_path",
						"symbol": "res://adapters/platform_adapter/settings.tres",
						"line": 4,
					},
				],
			}],
		)
		self.assertEqual(analysis["cycles"], [])
		self.assertEqual(analysis["unowned_reference_count"], 0)
		self.assertNotIn("undeclared_module_dependency", drift_codes)
		self.assertNotIn("unowned_project_resource_reference", drift_codes)
		self.assertEqual(validate_schema_file(report, SCHEMA_ROOT / "project_snapshot.schema.json"), [])

	def test_module_dependency_analysis_enforces_adapter_dependency_policy(self) -> None:
		self._set_modules([self._module("core")])
		self._set_adapter_boundaries([self._adapter("platform_adapter")])
		adapter_root = self.project_root / "adapters/platform_adapter"
		adapter_root.mkdir(parents=True)
		(adapter_root / "client.gd").write_text(
			"class_name PlatformAdapterClient\nextends RefCounted\n",
			encoding="utf-8",
		)
		(self.project_root / "features/core/use_adapter.gd").write_text(
			"extends Node\nvar client: PlatformAdapterClient\n",
			encoding="utf-8",
		)

		undeclared_report = snapshot.build_snapshot(self.project_root)
		undeclared_codes = {item["code"] for item in undeclared_report["drift"]["issues"]}
		undeclared_analysis = undeclared_report["project"]["module_dependency_analysis"]

		self.assertEqual(undeclared_analysis["edges"][0]["target_module"], "platform_adapter")
		self.assertEqual(undeclared_analysis["unowned_reference_count"], 0)
		self.assertIn("undeclared_module_dependency", undeclared_codes)
		self.assertNotIn("unowned_project_resource_reference", undeclared_codes)

		self._set_modules([self._module("core", forbidden=["platform_adapter"])])
		forbidden_report = snapshot.build_snapshot(self.project_root)
		forbidden_codes = {item["code"] for item in forbidden_report["drift"]["issues"]}

		self.assertIn("forbidden_module_dependency", forbidden_codes)
		self.assertNotIn("undeclared_module_dependency", forbidden_codes)

		self._set_modules([self._module("core", allowed=["platform_adapter"])])
		allowed_report = snapshot.build_snapshot(self.project_root)
		allowed_codes = {item["code"] for item in allowed_report["drift"]["issues"]}

		self.assertNotIn("forbidden_module_dependency", allowed_codes)
		self.assertNotIn("undeclared_module_dependency", allowed_codes)

	def test_dependency_namespace_rejects_reserved_module_and_adapter_ids(self) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		base_contract = json.loads(contract_path.read_text(encoding="utf-8"))
		for component_kind in ("module", "adapter"):
			for reserved_id in ("gf", "godot"):
				with self.subTest(component_kind=component_kind, reserved_id=reserved_id):
					contract = copy.deepcopy(base_contract)
					modules = [self._module(reserved_id)] if component_kind == "module" else []
					adapters = [self._adapter(reserved_id)] if component_kind == "adapter" else []
					contract["architecture"]["modules"] = modules
					contract["framework"]["adapter_boundaries"] = adapters
					contract_path.write_text(
						json.dumps(contract, ensure_ascii=False),
						encoding="utf-8",
					)

					result = load_contract(self.project_root)
					plan = dependencies.TargetOwnershipPlan(modules, adapters)
					reserved_issues = [
						item for item in result["issues"]
						if item["code"] == "reserved_dependency_id"
					]

					self.assertFalse(result["ok"])
					self.assertEqual(
						[item["path"] for item in reserved_issues],
						[
							"$.architecture.modules[0].id"
							if component_kind == "module"
							else "$.framework.adapter_boundaries[0].id"
						],
					)
					self.assertEqual(plan.unsafe_path_count, 1)
					self.assertEqual(plan.roots, ())
					self.assertEqual(plan.module_ids, frozenset())

	def test_target_ownership_plan_rejects_duplicate_dependency_ids(self) -> None:
		fixtures = {
			"duplicate_module": (
				[self._module("shared"), self._module("shared")],
				[],
				frozenset({"shared"}),
			),
			"duplicate_adapter": (
				[],
				[self._adapter("shared"), self._adapter("shared")],
				frozenset(),
			),
			"module_adapter_collision": (
				[self._module("shared")],
				[self._adapter("shared")],
				frozenset({"shared"}),
			),
		}
		for name, (modules, adapters, expected_module_ids) in fixtures.items():
			with self.subTest(name=name):
				plan = dependencies.TargetOwnershipPlan(modules, adapters)

				self.assertEqual(plan.unsafe_path_count, 1)
				self.assertEqual(plan.roots, ())
				self.assertEqual(plan.module_ids, expected_module_ids)

	def test_module_dependency_analysis_keeps_adapter_roots_fail_closed(self) -> None:
		self._set_modules([self._module("core", allowed=["missing_adapter"])])
		self._set_adapter_boundaries([self._adapter("missing_adapter")])

		missing_report = snapshot.build_snapshot(self.project_root)
		missing_analysis = missing_report["project"]["module_dependency_analysis"]

		self.assertEqual(missing_analysis["status"], "incomplete")
		self.assertFalse(missing_analysis["complete"])
		self.assertEqual(missing_analysis["missing_root_count"], 1)
		self.assertIn(
			"module_dependency_analysis_incomplete",
			{item["code"] for item in missing_report["drift"]["issues"]},
		)

		unsafe_contract = {
			"architecture": {
				"modules": [self._module("core", allowed=["unsafe_adapter"])],
				"owned_resources": [],
			},
			"framework": {
				"adapter_boundaries": [{
					**self._adapter("unsafe_adapter"),
					"project_root": "res://Addons/GF",
				}],
			},
		}
		unsafe_analysis = dependencies.analyze_module_dependencies(
			self.project_root,
			unsafe_contract,
			contract_valid=True,
		)

		self.assertEqual(unsafe_analysis["status"], "incomplete")
		self.assertFalse(unsafe_analysis["complete"])
		self.assertEqual(unsafe_analysis["unsafe_path_count"], 1)

		overlap_contract = {
			"architecture": {
				"modules": [self._module("core", allowed=["overlap_adapter"])],
				"owned_resources": [],
			},
			"framework": {
				"adapter_boundaries": [{
					**self._adapter("overlap_adapter"),
					"project_root": "res://features/core/adapter",
				}],
			},
		}
		overlap_analysis = dependencies.analyze_module_dependencies(
			self.project_root,
			overlap_contract,
			contract_valid=True,
		)

		self.assertEqual(overlap_analysis["status"], "incomplete")
		self.assertFalse(overlap_analysis["complete"])
		self.assertEqual(overlap_analysis["unsafe_path_count"], 1)
		self.assertEqual(overlap_analysis["scanned_file_count"], 0)
		self.assertEqual(
			dependencies.TargetOwnershipPlan(
				overlap_contract["architecture"]["modules"],
				overlap_contract["framework"]["adapter_boundaries"],
			).owner_of("res://features/core/adapter/client.gd"),
			"",
		)

	def test_module_dependency_analysis_adapter_resources_do_not_consume_scan_budget(
		self,
	) -> None:
		self._set_modules([self._module("core", allowed=["platform_adapter"])])
		self._set_adapter_boundaries([self._adapter("platform_adapter")])
		adapter_root = self.project_root / "adapters/platform_adapter"
		adapter_root.mkdir(parents=True)
		(adapter_root / "large.tres").write_text("x" * 256, encoding="utf-8")
		(self.project_root / "features/core/source.gd").write_text(
			"extends Node\n",
			encoding="utf-8",
		)

		with mock.patch.object(dependencies, "MAX_DEPENDENCY_FILE_BYTES", 32):
			report = snapshot.build_snapshot(self.project_root)
		analysis = report["project"]["module_dependency_analysis"]

		self.assertEqual(analysis["status"], "complete")
		self.assertEqual(analysis["scanned_file_count"], 1)
		self.assertEqual(analysis["oversized_file_count"], 0)

		(adapter_root / "large.gd").write_text("x" * 256, encoding="utf-8")
		with mock.patch.object(dependencies, "MAX_DEPENDENCY_FILE_BYTES", 32):
			oversized_report = snapshot.build_snapshot(self.project_root)
			oversized_analysis = oversized_report["project"]["module_dependency_analysis"]

		self.assertEqual(oversized_analysis["status"], "truncated")
		self.assertFalse(oversized_analysis["complete"])
		self.assertTrue(oversized_analysis["truncated"])
		self.assertEqual(oversized_analysis["oversized_file_count"], 1)

	def test_module_dependency_analysis_records_adapter_descendant_walk_errors(self) -> None:
		module = self._module("core", allowed=["platform_adapter"])
		adapter = self._adapter("platform_adapter")
		self._set_modules([module])
		self._set_adapter_boundaries([adapter])
		adapter_root = self.project_root / "adapters/platform_adapter"
		blocked_root = adapter_root / "blocked"
		blocked_root.mkdir(parents=True)
		(blocked_root / "client.gd").write_text(
			"class_name BlockedAdapterClient\nextends RefCounted\n",
			encoding="utf-8",
		)
		(self.project_root / "features/core/use_adapter.gd").write_text(
			"extends Node\nvar client: BlockedAdapterClient\n",
			encoding="utf-8",
		)
		contract = {
			"architecture": {"modules": [module], "owned_resources": []},
			"framework": {"adapter_boundaries": [adapter]},
		}
		real_scandir = os.scandir

		def fail_blocked_scandir(path: object) -> os.ScandirIterator:
			if Path(os.fspath(path)) == blocked_root:
				raise PermissionError(
					13,
					"simulated descendant enumeration failure",
					os.fspath(path),
				)
			return real_scandir(path)

		with mock.patch.object(dependencies.os, "scandir", side_effect=fail_blocked_scandir):
			analysis = dependencies.analyze_module_dependencies(
				self.project_root,
				contract,
				contract_valid=True,
			)

		self.assertEqual(analysis["status"], "incomplete")
		self.assertFalse(analysis["complete"])
		self.assertEqual(analysis["unsafe_path_count"], 1)
		self.assertEqual(analysis["scanned_file_count"], 1)
		self.assertEqual(analysis["edges"], [])

	def test_module_dependency_analysis_honors_adapter_root_gdignore(self) -> None:
		self._set_modules([self._module("core", allowed=["platform_adapter"])])
		self._set_adapter_boundaries([self._adapter("platform_adapter")])
		adapter_root = self.project_root / "adapters/platform_adapter"
		adapter_root.mkdir(parents=True)
		(adapter_root / ".gdignore").write_text("", encoding="utf-8")
		(adapter_root / "client.gd").write_text(
			"class_name IgnoredAdapterClient\nextends RefCounted\n",
			encoding="utf-8",
		)
		(self.project_root / "features/core/use_adapter.gd").write_text(
			"extends Node\nvar client: IgnoredAdapterClient\n",
			encoding="utf-8",
		)

		report = snapshot.build_snapshot(self.project_root)
		analysis = report["project"]["module_dependency_analysis"]

		self.assertEqual(analysis["status"], "complete")
		self.assertEqual(analysis["scanned_file_count"], 1)
		self.assertEqual(analysis["edges"], [])
		self.assertNotIn(
			"undeclared_module_dependency",
			{item["code"] for item in report["drift"]["issues"]},
		)

	def test_module_dependency_analysis_rejects_broken_gdignore_marker(self) -> None:
		module = self._module("core")
		self._set_modules([module])
		module_root = self.project_root / "features/core"
		(module_root / "visible.gd").write_text(
			"extends Node\n",
			encoding="utf-8",
		)
		marker_target = self.project_root / "gdignore-target"
		marker_target.mkdir()
		marker_path = module_root / ".gdignore"
		create_directory_link_fixture(marker_target, marker_path)
		marker_target.rmdir()
		self.assertTrue(os.path.lexists(marker_path))
		self.assertFalse(marker_path.exists())

		contract = {
			"architecture": {"modules": [module], "owned_resources": []},
			"framework": {"adapter_boundaries": []},
		}

		try:
			if os.name == "nt":
				# Windows keeps a broken junction in directory_names; present its
				# real reparse identity through the POSIX file_names classification.
				with mock.patch.object(
					dependencies.os,
					"walk",
					return_value=[(
						os.fspath(module_root),
						[],
						[".gdignore", "visible.gd"],
					)],
				):
					analysis = dependencies.analyze_module_dependencies(
						self.project_root,
						contract,
						contract_valid=True,
					)
			else:
				analysis = dependencies.analyze_module_dependencies(
					self.project_root,
					contract,
					contract_valid=True,
				)
		finally:
			if os.path.lexists(marker_path):
				if os.name == "nt":
					marker_path.rmdir()
				else:
					marker_path.unlink()

		self.assertEqual(analysis["status"], "incomplete")
		self.assertFalse(analysis["complete"])
		self.assertEqual(analysis["unsafe_path_count"], 1)
		self.assertEqual(analysis["scanned_file_count"], 1)

	def test_module_dependency_analysis_honors_adapter_descendant_gdignore(self) -> None:
		self._set_modules([self._module("core", allowed=["platform_adapter"])])
		self._set_adapter_boundaries([self._adapter("platform_adapter")])
		adapter_root = self.project_root / "adapters/platform_adapter"
		ignored_root = adapter_root / "ignored"
		ignored_root.mkdir(parents=True)
		(adapter_root / "visible.gd").write_text(
			"class_name VisibleAdapterClient\nextends RefCounted\n",
			encoding="utf-8",
		)
		(ignored_root / ".gdignore").write_text("", encoding="utf-8")
		(ignored_root / "hidden.gd").write_text(
			"class_name HiddenAdapterClient\nextends RefCounted\n",
			encoding="utf-8",
		)
		(self.project_root / "features/core/use_adapter.gd").write_text(
			"extends Node\n"
			"var visible: VisibleAdapterClient\n"
			"var hidden: HiddenAdapterClient\n",
			encoding="utf-8",
		)

		report = snapshot.build_snapshot(self.project_root)
		analysis = report["project"]["module_dependency_analysis"]

		self.assertEqual(analysis["status"], "complete")
		self.assertEqual(analysis["scanned_file_count"], 2)
		self.assertEqual(len(analysis["edges"]), 1)
		self.assertEqual(analysis["edges"][0]["target_module"], "platform_adapter")
		self.assertEqual(analysis["edges"][0]["reference_count"], 1)
		self.assertEqual(
			analysis["edges"][0]["evidence"][0]["symbol"],
			"VisibleAdapterClient",
		)

	def test_module_dependency_analysis_honors_module_descendant_gdignore(self) -> None:
		self._set_modules([self._module("core", allowed=["platform_adapter"])])
		self._set_adapter_boundaries([self._adapter("platform_adapter")])
		adapter_root = self.project_root / "adapters/platform_adapter"
		adapter_root.mkdir(parents=True)
		(adapter_root / "client.gd").write_text(
			"class_name PlatformAdapterClient\nextends RefCounted\n",
			encoding="utf-8",
		)
		module_root = self.project_root / "features/core"
		ignored_root = module_root / "ignored"
		ignored_root.mkdir()
		(ignored_root / ".gdignore").write_text("", encoding="utf-8")
		(ignored_root / "ignored_source.gd").write_text(
			"extends Node\nvar client: PlatformAdapterClient\n",
			encoding="utf-8",
		)
		(module_root / "visible_source.gd").write_text(
			"extends Node\n",
			encoding="utf-8",
		)

		report = snapshot.build_snapshot(self.project_root)
		analysis = report["project"]["module_dependency_analysis"]

		self.assertEqual(analysis["status"], "complete")
		self.assertEqual(analysis["scanned_file_count"], 2)
		self.assertEqual(analysis["module_file_counts"][0]["file_count"], 1)
		self.assertEqual(analysis["edges"], [])

	def test_module_dependency_analysis_honors_module_root_gdignore(self) -> None:
		self._set_modules([self._module("core", allowed=["platform_adapter"])])
		self._set_adapter_boundaries([self._adapter("platform_adapter")])
		adapter_root = self.project_root / "adapters/platform_adapter"
		adapter_root.mkdir(parents=True)
		(adapter_root / "client.gd").write_text(
			"class_name PlatformAdapterClient\nextends RefCounted\n",
			encoding="utf-8",
		)
		module_root = self.project_root / "features/core"
		(module_root / ".gdignore").write_text("", encoding="utf-8")
		(module_root / "ignored_source.gd").write_text(
			"extends Node\nvar client: PlatformAdapterClient\n",
			encoding="utf-8",
		)

		report = snapshot.build_snapshot(self.project_root)
		analysis = report["project"]["module_dependency_analysis"]

		self.assertEqual(analysis["status"], "complete")
		self.assertEqual(analysis["scanned_file_count"], 1)
		self.assertEqual(analysis["module_file_counts"][0]["file_count"], 0)
		self.assertEqual(analysis["edges"], [])

	def test_module_dependency_analysis_preserves_unowned_evidence_with_adapters(self) -> None:
		self._set_modules([self._module("core", allowed=["platform_adapter"])])
		self._set_adapter_boundaries([self._adapter("platform_adapter")])
		(self.project_root / "adapters/platform_adapter").mkdir(parents=True)
		(self.project_root / "features/core/unowned.gd").write_text(
			'extends Node\nconst DATA = preload("res://outside/data.tres")\n',
			encoding="utf-8",
		)

		report = snapshot.build_snapshot(self.project_root)
		analysis = report["project"]["module_dependency_analysis"]

		self.assertEqual(analysis["status"], "complete")
		self.assertEqual(analysis["unowned_reference_count"], 1)
		self.assertEqual(
			analysis["unowned_references"],
			[{
				"source_path": "res://features/core/unowned.gd",
				"target_path": "res://outside/data.tres",
				"line": 2,
			}],
		)
		self.assertIn(
			"unowned_project_resource_reference",
			{item["code"] for item in report["drift"]["issues"]},
		)

		(self.project_root / "features/core/unowned.gd").write_text(
			"extends Node\n"
			'const FIRST = preload("res://outside/first.tres")\n'
			'const SECOND = preload("res://outside/second.tres")\n',
			encoding="utf-8",
		)
		with mock.patch.object(dependencies, "MAX_UNOWNED_REFERENCE_EVIDENCE", 1):
			bounded_report = snapshot.build_snapshot(self.project_root)
			bounded_analysis = bounded_report["project"]["module_dependency_analysis"]

		self.assertEqual(bounded_analysis["unowned_reference_count"], 2)
		self.assertEqual(len(bounded_analysis["unowned_references"]), 1)
		self.assertTrue(bounded_analysis["unowned_references_truncated"])

	def test_module_dependency_analysis_preserves_literal_resource_path_characters(self) -> None:
		self._set_modules([
			self._module("core", allowed=["shared"]),
			self._module("shared"),
		])
		(self.project_root / "features/shared/[data].tres").write_text(
			"[gd_resource format=3]\n",
			encoding="utf-8",
		)
		(self.project_root / "features/core/use_shared.gd").write_text(
			'extends Node\nconst DATA = preload("res://features/shared/[data].tres")\n',
			encoding="utf-8",
		)

		report = snapshot.build_snapshot(self.project_root)
		analysis = report["project"]["module_dependency_analysis"]

		self.assertEqual(analysis["status"], "complete")
		self.assertEqual(len(analysis["edges"]), 1)
		self.assertEqual(analysis["edges"][0]["source_module"], "core")
		self.assertEqual(analysis["edges"][0]["target_module"], "shared")
		self.assertEqual(analysis["edges"][0]["kinds"], ["resource_path"])
		self.assertEqual(validate_schema_file(report, SCHEMA_ROOT / "project_snapshot.schema.json"), [])

	def test_module_dependency_analysis_ignores_bare_resource_root(self) -> None:
		self._set_modules([self._module("core")])
		(self.project_root / "features/core/scan_root.gd").write_text(
			'extends Node\nconst SCAN_ROOT := "res://"\n',
			encoding="utf-8",
		)

		report = snapshot.build_snapshot(self.project_root)
		analysis = report["project"]["module_dependency_analysis"]

		self.assertEqual(analysis["unowned_reference_count"], 0)
		self.assertEqual(analysis["unowned_references"], [])
		self.assertEqual(validate_schema_file(report, SCHEMA_ROOT / "project_snapshot.schema.json"), [])

	def test_module_dependency_analysis_ignores_case_equivalent_reserved_framework_paths(
		self,
	) -> None:
		self._set_modules([self._module("core")])
		(self.project_root / "features/core/framework_paths.gd").write_text(
			"extends Node\n"
			"const FRAMEWORK_PATHS := [\n"
			'\t"res://addons/gf",\n'
			'\t"res://ADDONS/GF",\n'
			'\t"res://addons/gf/plugin.cfg",\n'
			'\t"res://AdDoNs/Gf/plugin.cfg",\n'
			"]\n",
			encoding="utf-8",
		)

		report = snapshot.build_snapshot(self.project_root)
		analysis = report["project"]["module_dependency_analysis"]

		self.assertEqual(analysis["status"], "complete")
		self.assertEqual(analysis["unowned_reference_count"], 0)
		self.assertEqual(analysis["unowned_references"], [])
		self.assertNotIn(
			"unowned_project_resource_reference",
			{item["code"] for item in report["drift"]["issues"]},
		)
		self.assertEqual(validate_schema_file(report, SCHEMA_ROOT / "project_snapshot.schema.json"), [])

	def test_module_dependency_analysis_accepts_auditable_owned_resource_references(self) -> None:
		self._set_modules([self._module("core")])
		(self.project_root / "export_presets.cfg").write_text("[preset.0]\n", encoding="utf-8")
		self._set_owned_resources(["res://project.godot", "res://export_presets.cfg"])
		(self.project_root / "features/core/project_metadata.gd").write_text(
			'extends Node\nconst PROJECT_FILE := "res://project.godot"\n'
			'const EXPORT_PRESETS := "res://export_presets.cfg"\n',
			encoding="utf-8",
		)

		contract_result = load_contract(self.project_root)
		report = snapshot.build_snapshot(self.project_root)
		analysis = report["project"]["module_dependency_analysis"]
		drift_codes = {item["code"] for item in report["drift"]["issues"]}

		self.assertTrue(contract_result["ok"], contract_result)
		self.assertEqual(analysis["status"], "complete")
		self.assertEqual(analysis["declared_owned_resource_count"], 2)
		self.assertEqual(analysis["missing_owned_resource_count"], 0)
		self.assertEqual(analysis["unsafe_owned_resource_count"], 0)
		self.assertEqual(
			analysis["owned_resources"],
			[
				{"path": "res://export_presets.cfg", "status": "available"},
				{"path": "res://project.godot", "status": "available"},
			],
		)
		self.assertEqual(analysis["owned_resource_reference_count"], 2)
		self.assertFalse(analysis["owned_resource_references_truncated"])
		self.assertEqual(
			analysis["owned_resource_references"],
			[
				{
					"source_path": "res://features/core/project_metadata.gd",
					"target_path": "res://project.godot",
					"line": 2,
				},
				{
					"source_path": "res://features/core/project_metadata.gd",
					"target_path": "res://export_presets.cfg",
					"line": 3,
				},
			],
		)
		self.assertEqual(analysis["unowned_reference_count"], 0)
		self.assertEqual(analysis["edges"], [])
		self.assertNotIn("unowned_project_resource_reference", drift_codes)
		self.assertEqual(validate_schema_file(report, SCHEMA_ROOT / "project_snapshot.schema.json"), [])

		with mock.patch.object(dependencies, "MAX_OWNED_RESOURCE_REFERENCE_EVIDENCE", 1):
			bounded_analysis = snapshot.build_snapshot(self.project_root)["project"]["module_dependency_analysis"]
		self.assertEqual(bounded_analysis["owned_resource_reference_count"], 2)
		self.assertEqual(len(bounded_analysis["owned_resource_references"]), 1)
		self.assertTrue(bounded_analysis["owned_resource_references_truncated"])

	def test_module_dependency_analysis_fails_closed_for_invalid_owned_resources(self) -> None:
		self._set_modules([self._module("core")])
		(self.project_root / "governance").mkdir()
		(self.project_root / "features/core/project_metadata.gd").write_text(
			'extends Node\nconst MISSING := "res://missing.cfg"\n',
			encoding="utf-8",
		)
		self._set_owned_resources(["res://missing.cfg", "res://governance"])

		report = snapshot.build_snapshot(self.project_root)
		analysis = report["project"]["module_dependency_analysis"]

		self.assertEqual(analysis["status"], "incomplete")
		self.assertFalse(analysis["complete"])
		self.assertEqual(analysis["missing_owned_resource_count"], 1)
		self.assertEqual(analysis["unsafe_owned_resource_count"], 1)
		self.assertEqual(
			analysis["owned_resources"],
			[
				{"path": "res://governance", "status": "unsafe"},
				{"path": "res://missing.cfg", "status": "missing"},
			],
		)
		self.assertEqual(analysis["owned_resource_reference_count"], 0)
		self.assertEqual(analysis["unowned_reference_count"], 1)
		self.assertIn("module_dependency_analysis_incomplete", {item["code"] for item in report["drift"]["issues"]})
		self.assertEqual(validate_schema_file(report, SCHEMA_ROOT / "project_snapshot.schema.json"), [])

	def test_contract_rejects_bare_or_overlapping_owned_resources(self) -> None:
		self._set_modules([self._module("core")])
		self._set_owned_resources(["res://"])

		bare_result = load_contract(self.project_root)

		self.assertFalse(bare_result["ok"])
		self.assertTrue(any("owned_resources" in item["path"] for item in bare_result["issues"]))

		contract_path = self.project_root / ".gf/project_contract.json"
		contract = json.loads(contract_path.read_text(encoding="utf-8"))
		contract["architecture"]["owned_resources"] = []
		contract["architecture"]["modules"][0]["roots"] = ["res://"]
		contract_path.write_text(json.dumps(contract, ensure_ascii=False), encoding="utf-8")
		bare_module_result = load_contract(self.project_root)

		self.assertFalse(bare_module_result["ok"])
		self.assertTrue(any(".roots[0]" in item["path"] for item in bare_module_result["issues"]))

		self._set_modules([self._module("core")])
		self._set_owned_resources(["res://governance//rules.cfg"])
		non_canonical_result = load_contract(self.project_root)

		self.assertFalse(non_canonical_result["ok"])
		self.assertIn("non_canonical_owned_resource_path", {item["code"] for item in non_canonical_result["issues"]})

		self._set_owned_resources(["res://governance/line\nbreak.cfg"])
		control_character_result = load_contract(self.project_root)
		control_character_snapshot = snapshot.build_snapshot(self.project_root)

		self.assertFalse(control_character_result["ok"])
		self.assertTrue(any("owned_resources" in item["path"] for item in control_character_result["issues"]))
		self.assertEqual(
			validate_schema_file(control_character_snapshot, SCHEMA_ROOT / "project_snapshot.schema.json"),
			[],
		)

		self._set_owned_resources(["res://Addons/GF/project.godot"])
		framework_result = load_contract(self.project_root)

		self.assertFalse(framework_result["ok"])
		self.assertIn("framework_owned_resource", {item["code"] for item in framework_result["issues"]})

		for unsafe_alias in (
			"res://governance/*.cfg",
			"res://governance/?.cfg",
			"res://governance/[rules].cfg",
			"res://addons./gf/plugin.cfg",
			"res://addons/gf./plugin.cfg",
			"res://addons/gf/plugin.cfg.",
			"res://governance/data:stream",
			"res://CON/settings.cfg",
		):
			with self.subTest(unsafe_alias=unsafe_alias):
				self._set_owned_resources([unsafe_alias])
				alias_result = load_contract(self.project_root)
				self.assertFalse(alias_result["ok"])
				self.assertTrue(
					{item["code"] for item in alias_result["issues"]}.intersection({
						"non_canonical_owned_resource_path",
						"pattern_mismatch",
					}),
				)

		self._set_owned_resources(["res://features/core/settings.cfg"])
		overlap_result = load_contract(self.project_root)

		self.assertFalse(overlap_result["ok"])
		self.assertIn("ownership_resource_overlap", {item["code"] for item in overlap_result["issues"]})

	def test_contract_rejects_owned_resources_and_adapter_roots_through_linked_parent(self) -> None:
		self._set_modules([self._module("core")])
		real_root = self.project_root / "governance-real"
		real_root.mkdir()
		(real_root / "rules.cfg").write_text("[rules]\n", encoding="utf-8")
		linked_root = self.project_root / "governance-link"
		create_directory_link_fixture(real_root, linked_root)
		self._set_owned_resources(["res://governance-link/rules.cfg"])

		owned_resource_result = load_contract(self.project_root)
		report = snapshot.build_snapshot(self.project_root)

		self.assertFalse(owned_resource_result["ok"])
		self.assertIn("unsafe_project_path", {item["code"] for item in owned_resource_result["issues"]})
		self.assertEqual(report["project"]["module_dependency_analysis"]["status"], "contract_invalid")
		self.assertEqual(validate_schema_file(report, SCHEMA_ROOT / "project_snapshot.schema.json"), [])

		self._set_owned_resources(["res://governance-real/rules.cfg"])
		contract_path = self.project_root / ".gf/project_contract.json"
		contract = json.loads(contract_path.read_text(encoding="utf-8"))
		contract["framework"]["adapter_boundaries"] = [{
			"id": "governance_adapter",
			"provider": "test",
			"project_root": "res://governance-link",
			"responsibility": "Test linked adapter boundary",
		}]
		contract_path.write_text(json.dumps(contract, ensure_ascii=False), encoding="utf-8")

		adapter_result = load_contract(self.project_root)

		self.assertFalse(adapter_result["ok"])
		self.assertIn("unsafe_project_path", {item["code"] for item in adapter_result["issues"]})

	def test_contract_rejects_nonportable_or_reserved_ownership_roots(self) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		for unsafe_root, expected_code in (
			("res://Addons/GF", "framework_ownership_root"),
			("res://addons./gf", "non_canonical_ownership_root"),
			("res://addons/gf.", "non_canonical_ownership_root"),
			("res://CON", "non_canonical_ownership_root"),
		):
			with self.subTest(unsafe_root=unsafe_root):
				contract = json.loads(contract_path.read_text(encoding="utf-8"))
				contract["architecture"]["modules"] = [{
					**self._module("unsafe"),
					"roots": [unsafe_root],
				}]
				contract_path.write_text(json.dumps(contract, ensure_ascii=False), encoding="utf-8")

				result = load_contract(self.project_root)
				report = snapshot.build_snapshot(self.project_root)

				self.assertFalse(result["ok"])
				self.assertIn(expected_code, {item["code"] for item in result["issues"]})
				self.assertEqual(report["project"]["module_dependency_analysis"]["status"], "contract_invalid")

		contract = json.loads(contract_path.read_text(encoding="utf-8"))
		contract["architecture"]["modules"] = []
		contract["framework"]["adapter_boundaries"] = [{
			"id": "unsafe_adapter",
			"provider": "test",
			"project_root": "res://Addons/GF",
			"responsibility": "Must not alias the framework boundary",
		}]
		contract_path.write_text(json.dumps(contract, ensure_ascii=False), encoding="utf-8")

		adapter_result = load_contract(self.project_root)
		self.assertFalse(adapter_result["ok"])
		self.assertIn("framework_ownership_root", {item["code"] for item in adapter_result["issues"]})

	def test_portable_ownership_path_identity_normalizes_case_and_unicode(self) -> None:
		composed = "res://adapters/platform/Café/Provider.gdextension"
		decomposed = "res://adapters/platform/cafe\u0301/provider.gdextension"

		self.assertEqual(
			paths.portable_ownership_path_identity(composed),
			paths.portable_ownership_path_identity(decomposed),
		)
		self.assertEqual(
			paths.portable_ownership_path_identity("res://adapters/../provider"),
			"",
		)

	def test_dependency_core_rejects_reserved_framework_root_when_contract_is_prevalidated(self) -> None:
		(self.project_root / "addons/gf/unsafe.gd").write_text(
			"extends Node\n",
			encoding="utf-8",
		)
		unsafe_module = {
			**self._module("unsafe"),
			"roots": ["res://Addons/GF"],
		}
		contract_data = {
			"architecture": {
				"modules": [unsafe_module],
				"owned_resources": [],
			},
		}

		analysis = dependencies.analyze_module_dependencies(
			self.project_root,
			contract_data,
			contract_valid=True,
		)

		self.assertEqual(analysis["status"], "incomplete")
		self.assertFalse(analysis["complete"])
		self.assertEqual(analysis["scanned_file_count"], 0)
		self.assertEqual(analysis["unsafe_path_count"], 1)
		self.assertEqual(
			dependencies.TargetOwnershipPlan([unsafe_module]).owner_of("res://Addons/GF/unsafe.gd"),
			"",
		)

	def test_module_dependency_analysis_keeps_missing_module_roots_fail_closed(self) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		contract = json.loads(contract_path.read_text(encoding="utf-8"))
		contract["architecture"]["modules"] = [self._module("missing")]
		contract_path.write_text(json.dumps(contract, ensure_ascii=False), encoding="utf-8")

		analysis = snapshot.build_snapshot(self.project_root)["project"]["module_dependency_analysis"]

		self.assertEqual(analysis["status"], "incomplete")
		self.assertEqual(analysis["missing_root_count"], 1)

	def test_module_dependency_analysis_enforces_forbidden_before_undeclared_edges(self) -> None:
		self._set_modules([
			self._module("core", forbidden=["shared"]),
			self._module("shared"),
		])
		(self.project_root / "features/shared/shared_type.gd").write_text(
			"class_name SharedType\nextends RefCounted\n",
			encoding="utf-8",
		)
		(self.project_root / "features/core/use_shared.gd").write_text(
			"extends Node\nvar value: SharedType\n",
			encoding="utf-8",
		)

		forbidden_report = snapshot.build_snapshot(self.project_root)
		forbidden_codes = {item["code"] for item in forbidden_report["drift"]["issues"]}
		self.assertIn("forbidden_module_dependency", forbidden_codes)
		self.assertNotIn("undeclared_module_dependency", forbidden_codes)

		self._set_modules([self._module("core"), self._module("shared")])
		undeclared_report = snapshot.build_snapshot(self.project_root)
		undeclared_issues = [
			item for item in undeclared_report["drift"]["issues"]
			if item["code"] == "undeclared_module_dependency"
		]
		self.assertEqual(len(undeclared_issues), 1)
		self.assertIn("res://features/core/use_shared.gd:2", undeclared_issues[0]["message"])

	def test_module_dependency_analysis_ignores_comments_and_ordinary_strings(self) -> None:
		self._set_modules([self._module("core"), self._module("shared")])
		(self.project_root / "features/shared/shared_type.gd").write_text(
			"class_name SharedType\nextends RefCounted\n",
			encoding="utf-8",
		)
		(self.project_root / "features/core/no_dependency.gd").write_text(
			'# SharedType\nvar label := "SharedType"\n',
			encoding="utf-8",
		)

		analysis = snapshot.build_snapshot(self.project_root)["project"]["module_dependency_analysis"]

		self.assertEqual(analysis["status"], "complete")
		self.assertEqual(analysis["edges"], [])

	def test_module_dependency_analysis_reports_observed_cycles_and_ambiguous_classes(self) -> None:
		self._set_modules([self._module("first"), self._module("second")])
		(self.project_root / "features/first/first_type.gd").write_text(
			"class_name FirstType\nextends RefCounted\nvar peer: SecondType\n",
			encoding="utf-8",
		)
		(self.project_root / "features/second/second_type.gd").write_text(
			"class_name SecondType\nextends RefCounted\nvar peer: FirstType\n",
			encoding="utf-8",
		)

		cycle_report = snapshot.build_snapshot(self.project_root)
		self.assertEqual(
			cycle_report["project"]["module_dependency_analysis"]["cycles"],
			[["first", "second"]],
		)
		self.assertIn("observed_module_dependency_cycle", {item["code"] for item in cycle_report["drift"]["issues"]})

		(self.project_root / "features/first/duplicate.gd").write_text(
			"class_name SecondType\nextends RefCounted\n",
			encoding="utf-8",
		)
		ambiguous_report = snapshot.build_snapshot(self.project_root)
		analysis = ambiguous_report["project"]["module_dependency_analysis"]
		self.assertEqual(analysis["status"], "incomplete")
		self.assertEqual(analysis["ambiguous_class_name_count"], 1)
		self.assertIn("ambiguous_project_class_name", {item["code"] for item in ambiguous_report["drift"]["issues"]})

	def test_module_dependency_analysis_fails_closed_when_budget_is_exhausted(self) -> None:
		self._set_modules([self._module("core"), self._module("shared")])
		(self.project_root / "features/core/a.gd").write_text("extends Node\n", encoding="utf-8")
		(self.project_root / "features/shared/b.gd").write_text("extends Node\n", encoding="utf-8")

		with mock.patch.object(dependencies, "MAX_DEPENDENCY_FILES", 1):
			report = snapshot.build_snapshot(self.project_root)

		analysis = report["project"]["module_dependency_analysis"]
		self.assertEqual(analysis["status"], "truncated")
		self.assertFalse(analysis["complete"])
		self.assertIn("module_dependency_analysis_incomplete", {item["code"] for item in report["drift"]["issues"]})

	def test_catalog_queries_fail_closed_when_kit_version_differs_from_project(self) -> None:
		(self.project_root / "addons/gf/plugin.cfg").write_text(
			'[plugin]\nname="GF"\nversion="999.0.0"\n',
			encoding="utf-8",
		)

		result = catalog.api_search("GFArchitecture", 10, self.project_root)

		self.assertFalse(result["ok"])
		self.assertIn("does not match", result["issues"][0])

	def test_generated_api_index_exposes_gf_as_an_autoload_owner(self) -> None:
		api_index = build_gf_ai_developer_kit.render_api_index()

		self.assertEqual(api_index["schema_version"], 2)
		self.assertEqual(api_index["catalog_version"], "2.0.0")
		self.assertEqual(api_index["autoload_count"], 1)
		self.assertNotIn("Gf", api_index["classes"])
		self.assertIn("Gf", api_index["autoloads"])
		gf_owner = api_index["autoloads"]["Gf"]
		self.assertEqual(gf_owner["owner_kind"], "autoload")
		self.assertEqual(gf_owner["package_id"], "gf.kernel")
		self.assertEqual(gf_owner["path"], "addons/gf/kernel/core/gf.gd")
		gf_api_owner = next(
			owner
			for owner in build_gf_ai_developer_kit.collect_api_owners(
				ROOT / "addons/gf",
				ROOT,
			)
			if owner.name == "Gf"
		)
		self.assertEqual(
			{(member["kind"], member["name"]) for member in gf_owner["members"]},
			{
				(build_gf_ai_developer_kit._member_kind(member), member.name)
				for member in [
					*gf_api_owner.script.signals,
					*gf_api_owner.script.enums,
					*gf_api_owner.script.constants,
					*gf_api_owner.script.properties,
					*gf_api_owner.script.methods,
				]
			},
		)
		self.assertEqual(catalog._api_index_issues(api_index), [])

		wrong_kind = copy.deepcopy(api_index)
		wrong_kind["autoloads"]["Gf"]["owner_kind"] = "class"
		wrong_payload = {key: value for key, value in wrong_kind.items() if key != "source_digest"}
		wrong_kind["source_digest"] = paths.sha256_bytes(paths.canonical_json_bytes(wrong_payload))
		self.assertTrue(any(
			"autoload record owner_kind is invalid: Gf" in issue
			for issue in catalog._api_index_issues(wrong_kind)
		))

	def test_api_search_finds_autoload_without_widening_api_class(self) -> None:
		api_index = build_gf_ai_developer_kit.render_api_index()
		knowledge_root = self.project_root / "knowledge"
		knowledge_root.mkdir()
		(knowledge_root / "api_index.json").write_text(
			json.dumps(api_index),
			encoding="utf-8",
		)

		with mock.patch.object(catalog, "KNOWLEDGE_ROOT", knowledge_root):
			search = catalog.api_search("Gf", 10, self.project_root)
			class_lookup = catalog.api_class("Gf", True, self.project_root)

		self.assertTrue(search["ok"], search)
		gf_result = next(item for item in search["results"] if item["owner_name"] == "Gf")
		self.assertEqual(gf_result["owner_kind"], "autoload")
		self.assertEqual(gf_result["class_name"], "")
		self.assertFalse(class_lookup["ok"], class_lookup)
		cli_help = " ".join(cli._make_parser().format_help().split())
		self.assertIn("API owners (classes and controlled AutoLoads)", cli_help)
		api_search_tool = next(item for item in mcp.list_tools() if item["name"] == "gf_api_search")
		self.assertIn("API owners (classes and controlled AutoLoads)", api_search_tool["description"])

	def test_catalog_runtime_rejects_structural_and_digest_corruption(self) -> None:
		knowledge_root = self.project_root / "knowledge"
		knowledge_root.mkdir()
		api_index = json.loads((ADDON_ROOT / "knowledge/api_index.json").read_text(encoding="utf-8"))
		api_index["source_digest"] = "0" * 64
		(knowledge_root / "api_index.json").write_text(json.dumps(api_index), encoding="utf-8")
		capabilities = json.loads((ADDON_ROOT / "knowledge/capabilities.json").read_text(encoding="utf-8"))
		capabilities["unexpected"] = True
		(knowledge_root / "capabilities.json").write_text(json.dumps(capabilities), encoding="utf-8")

		with mock.patch.object(catalog, "KNOWLEDGE_ROOT", knowledge_root):
			with self.assertRaisesRegex(ValueError, "source_digest"):
				catalog.load_api_index()
			with self.assertRaisesRegex(ValueError, "Field is not part of the schema"):
				catalog.load_capabilities()

		valid_api_index = json.loads((ADDON_ROOT / "knowledge/api_index.json").read_text(encoding="utf-8"))
		valid_capabilities = json.loads((ADDON_ROOT / "knowledge/capabilities.json").read_text(encoding="utf-8"))
		mismatched_recipes = json.loads((ADDON_ROOT / "knowledge/recipes.json").read_text(encoding="utf-8"))
		mismatched_recipes["catalog_version"] = "9.9.9"
		(knowledge_root / "api_index.json").write_text(json.dumps(valid_api_index), encoding="utf-8")
		(knowledge_root / "capabilities.json").write_text(json.dumps(valid_capabilities), encoding="utf-8")
		(knowledge_root / "recipes.json").write_text(json.dumps(mismatched_recipes), encoding="utf-8")

		with mock.patch.object(catalog, "KNOWLEDGE_ROOT", knowledge_root):
			with self.assertRaisesRegex(ValueError, "catalog_version must match"):
				catalog.load_recipes()

	def test_catalog_cross_references_classes_packages_recipes_and_owners(self) -> None:
		api_index = json.loads((ADDON_ROOT / "knowledge/api_index.json").read_text(encoding="utf-8"))
		capabilities = json.loads((ADDON_ROOT / "knowledge/capabilities.json").read_text(encoding="utf-8"))
		recipes = json.loads((ADDON_ROOT / "knowledge/recipes.json").read_text(encoding="utf-8"))

		self.assertEqual(catalog.catalog_reference_issues(api_index, capabilities, recipes), [])

		unknown_class = copy.deepcopy(capabilities)
		unknown_class["capabilities"][0]["primary_classes"].append("GFMissingCatalogClass")
		self.assertTrue(any(
			"unknown class: GFMissingCatalogClass" in issue
			for issue in catalog.catalog_reference_issues(api_index, unknown_class, recipes)
		))
		autoload_as_class = copy.deepcopy(capabilities)
		autoload_as_class["capabilities"][0]["primary_classes"].append("Gf")
		self.assertTrue(any(
			"unknown class: Gf" in issue
			for issue in catalog.catalog_reference_issues(api_index, autoload_as_class, recipes)
		))

		unknown_package = copy.deepcopy(capabilities)
		unknown_package["capabilities"][0]["packages"].append("gf.unknown")
		self.assertTrue(any(
			"unknown package: gf.unknown" in issue
			for issue in catalog.catalog_reference_issues(api_index, unknown_package, recipes)
		))

		unknown_recipe = copy.deepcopy(capabilities)
		unknown_recipe["capabilities"][0]["recipes"].append("unknown-recipe")
		self.assertTrue(any(
			"unknown recipe: unknown-recipe" in issue
			for issue in catalog.catalog_reference_issues(api_index, unknown_recipe, recipes)
		))

		invalid_capability_owner = copy.deepcopy(capabilities)
		ui_navigation = next(
			item for item in invalid_capability_owner["capabilities"]
			if item["id"] == "ui-navigation"
		)
		ui_navigation["packages"] = ["gf.kernel"]
		self.assertTrue(any(
			"primary class GFUIUtility is owned by gf.standard.ui" in issue
			for issue in catalog.catalog_reference_issues(api_index, invalid_capability_owner, recipes)
		))

		invalid_recipe_owner = copy.deepcopy(recipes)
		owned_resource_load = next(
			item for item in invalid_recipe_owner["recipes"]
			if item["id"] == "owned-resource-load"
		)
		owned_resource_load["package_requirements"] = {"all_of": ["gf.kernel"], "any_of": []}
		self.assertTrue(any(
			"primary class GFAssetUtility is owned by gf.standard.assets" in issue
			for issue in catalog.catalog_reference_issues(api_index, capabilities, invalid_recipe_owner)
		))

		mismatched_version = copy.deepcopy(recipes)
		mismatched_version["catalog_version"] = "9.9.9"
		self.assertTrue(any(
			"catalog_version must match" in issue
			for issue in catalog.catalog_reference_issues(api_index, capabilities, mismatched_version)
		))

		fixture = json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))
		missing_members = copy.deepcopy(api_index)
		required_members_by_class: dict[str, set[str]] = {}
		for case in fixture["catalog_api_requirements"]:
			required_members_by_class.setdefault(case["class_name"], set()).update(case["members"])
		for class_name, required_members in required_members_by_class.items():
			self.assertIn(class_name, missing_members["classes"])
			class_members = missing_members["classes"][class_name]["members"]
			missing_members["classes"][class_name]["members"] = [
				member
				for member in class_members
				if member.get("name") not in required_members
			]
		missing_member_issues = catalog.catalog_reference_issues(
			missing_members,
			capabilities,
			recipes,
		)
		for case in fixture["catalog_api_requirements"]:
			label = "Capability" if case["catalog"] == "capability" else "Recipe"
			for member_name in case["members"]:
				self.assertIn(
					f"{label} {case['record_id']} requires an unknown API member: "
					f"{case['class_name']}.{member_name}.",
					missing_member_issues,
				)

	def test_catalog_exposes_bounded_module_and_package_context(self) -> None:
		module = catalog.api_module("kernel", 3, self.project_root)
		package = catalog.package_by_id("gf.kernel", 3, self.project_root)
		invalid_limit = catalog.api_search("GFArchitecture", True, self.project_root)
		oversized_query = catalog.capability_search("x" * 501, 10, self.project_root)

		self.assertTrue(module["ok"], module)
		self.assertEqual(module["module"], "kernel")
		self.assertGreater(module["class_count"], len(module["classes"]))
		self.assertTrue(module["truncated"])
		self.assertIn("GFArchitecture", [item["class_name"] for item in module["classes"]])
		self.assertTrue(package["ok"], package)
		self.assertTrue(package["installed"])
		self.assertEqual(package["package_state"]["source"], "lockfile")
		self.assertGreater(package["class_count"], len(package["classes"]))
		self.assertTrue(package["truncated"])
		self.assertFalse(invalid_limit["ok"])
		self.assertIn("integer", invalid_limit["issues"][0])
		self.assertFalse(oversized_query["ok"])
		self.assertIn("500", oversized_query["issues"][0])

	def test_agent_install_is_reversible_and_refuses_drifted_owned_files(self) -> None:
		project_kit_root = self.project_root / "addons/gf/tools/ai_developer"
		project_kit_root.mkdir(parents=True)
		(project_kit_root / "gf_ai_project.py").write_text("# project kit marker\n", encoding="utf-8")
		agents_path = self.project_root / "AGENTS.md"
		agents_path.write_text("# Project-owned instructions\n", encoding="utf-8")
		cursor_rules_root = self.project_root / ".cursor/rules"
		cursor_rules_root.mkdir(parents=True)
		installed = adapters.install_agents(self.project_root, ["agents", "codex", "cursor"])

		self.assertTrue(installed["ok"], installed)
		self.assertEqual(adapters.agent_status(self.project_root)["installed"], ["agents", "codex", "cursor"])
		cursor_path = self.project_root / ".cursor/rules/gf-framework.mdc"
		cursor_path.write_text(cursor_path.read_text(encoding="utf-8") + "project edit\n", encoding="utf-8")
		blocked = adapters.uninstall_agents(self.project_root, ["cursor"])
		self.assertFalse(blocked["ok"])
		self.assertTrue(cursor_path.is_file())
		blocked_update = adapters.install_agents(self.project_root, ["cursor"])
		self.assertFalse(blocked_update["ok"])
		approved_update = adapters.install_agents(self.project_root, ["cursor"], replace_drifted=True)
		self.assertTrue(approved_update["ok"], approved_update)
		removed_cursor = adapters.uninstall_agents(self.project_root, ["cursor"])
		self.assertTrue(removed_cursor["ok"], removed_cursor)
		self.assertFalse(cursor_path.exists())
		self.assertTrue(cursor_rules_root.is_dir())

		removed = adapters.uninstall_agents(self.project_root, ["agents", "codex"])
		self.assertTrue(removed["ok"], removed)
		self.assertEqual(agents_path.read_text(encoding="utf-8"), "# Project-owned instructions\n")

	def test_agent_install_rolls_back_exact_bytes_and_reports_restore_failures(self) -> None:
		agents_path = self.project_root / "AGENTS.md"
		original = b"# Project-owned instructions\r\n"
		agents_path.write_bytes(original)
		real_write = adapters.atomic_write_text

		def fail_cursor_write(path: Path, content: str) -> None:
			if path.name == "gf-framework.mdc":
				raise OSError("simulated cursor write failure")
			real_write(path, content)

		with mock.patch.object(adapters, "atomic_write_text", side_effect=fail_cursor_write):
			result = adapters.install_agents(self.project_root, ["agents", "cursor"])

		self.assertFalse(result["ok"])
		self.assertEqual(agents_path.read_bytes(), original)
		self.assertFalse((self.project_root / ".cursor/rules/gf-framework.mdc").exists())

		agents_path.write_text("modified\n", encoding="utf-8")
		with mock.patch.object(adapters, "atomic_write_bytes", side_effect=OSError("rollback denied")):
			rollback_issues = adapters._restore_files({agents_path: original})
		self.assertEqual(len(rollback_issues), 1)
		self.assertIn("rollback failed", rollback_issues[0])

	def test_standalone_adapter_does_not_install_a_broken_project_codex_skill(self) -> None:
		default_install = adapters.install_agents(self.project_root, [])
		explicit_codex = adapters.install_agents(self.project_root, ["codex"])

		self.assertTrue(default_install["ok"], default_install)
		self.assertEqual(default_install["targets"], ["agents"])
		self.assertFalse((self.project_root / ".codex/skills/gf-project-development/SKILL.md").exists())
		self.assertFalse(explicit_codex["ok"])
		self.assertIn("standalone plugin", explicit_codex["issues"][0])

	def test_agent_adapter_rejects_duplicate_managed_blocks(self) -> None:
		from gf_ai.constants import MANAGED_BLOCK_END, MANAGED_BLOCK_START

		path = self.project_root / "AGENTS.md"
		path.write_text(
			f"{MANAGED_BLOCK_START}\nfirst\n{MANAGED_BLOCK_END}\n"
			f"{MANAGED_BLOCK_START}\nsecond\n{MANAGED_BLOCK_END}\n",
			encoding="utf-8",
		)
		status = adapters.agent_status(self.project_root)

		self.assertIn("agents", status["drifted"])
		self.assertFalse(adapters.install_agents(self.project_root, ["agents"])["ok"])

	def test_agent_managed_block_preserves_all_project_owned_bytes(self) -> None:
		agents_path = self.project_root / "AGENTS.md"
		original = b"\n# Project heading  \r\n    indented code\r\n\n"
		agents_path.write_bytes(original)

		installed = adapters.install_agents(self.project_root, ["agents"])
		self.assertTrue(installed["ok"], installed)
		installed_payload = agents_path.read_bytes()
		self.assertTrue(installed_payload.startswith(original + b"\n\n"))
		removed = adapters.uninstall_agents(self.project_root, ["agents"])

		self.assertTrue(removed["ok"], removed)
		self.assertEqual(agents_path.read_bytes(), original)

	def test_agent_managed_block_splice_keeps_prefix_and_suffix_exact(self) -> None:
		from gf_ai.constants import MANAGED_BLOCK_END, MANAGED_BLOCK_START

		prefix = "\n# Project heading  \r\n"
		suffix = "\n    indented code\r\n\n"
		existing = f"{prefix}{MANAGED_BLOCK_START}\nold\n{MANAGED_BLOCK_END}{suffix}"

		replaced = adapters._replace_managed_block(existing, adapters._managed_block())

		self.assertTrue(replaced.startswith(prefix))
		self.assertTrue(replaced.endswith(suffix))
		self.assertEqual(adapters._remove_managed_block(replaced), prefix + suffix)

	def test_agent_install_rejects_a_target_changed_after_planning(self) -> None:
		agents_path = self.project_root / "AGENTS.md"
		agents_path.write_bytes(b"reviewed source\n")
		concurrent_payload = b"concurrent user edit\n"
		real_commit = adapters._commit_agent_operations

		def mutate_before_commit(
			project_root: Path,
			operations: list[dict[str, Any]],
			read_budget: Any,
			**kwargs: Any,
		) -> dict[str, Any]:
			agents_path.write_bytes(concurrent_payload)
			return real_commit(project_root, operations, read_budget, **kwargs)

		with mock.patch.object(adapters, "_commit_agent_operations", side_effect=mutate_before_commit):
			result = adapters.install_agents(self.project_root, ["agents"])

		self.assertFalse(result["ok"], result)
		self.assertIn("changed after planning", "\n".join(result["issues"]))
		self.assertEqual(agents_path.read_bytes(), concurrent_payload)

	def test_agent_targets_are_bounded_per_file_and_per_invocation(self) -> None:
		agents_path = self.project_root / "AGENTS.md"
		agents_path.write_bytes(b"123456789")
		with mock.patch.object(adapters, "_AGENT_TARGET_MAX_BYTES", 8):
			status = adapters.agent_status(self.project_root)
			install = adapters.install_agents(self.project_root, ["agents"], replace_drifted=True)
		self.assertIn("agents", status["drifted"])
		self.assertTrue(status["issues"])
		self.assertFalse(install["ok"], install)
		self.assertEqual(agents_path.read_bytes(), b"123456789")

		agents_path.write_bytes(b"123456")
		(self.project_root / "CLAUDE.md").write_bytes(b"abcdef")
		with (
			mock.patch.object(adapters, "_AGENT_TARGET_MAX_BYTES", 10),
			mock.patch.object(adapters, "_AGENT_INVOCATION_MAX_BYTES", 10),
		):
			aggregate_status = adapters.agent_status(self.project_root)
		self.assertIn("claude", aggregate_status["drifted"])
		self.assertTrue(aggregate_status["issues"])

	def test_agent_adapter_rejects_a_project_internal_directory_alias(self) -> None:
		real_cursor_root = self.project_root / "shared-cursor"
		(real_cursor_root / "rules").mkdir(parents=True)
		target = real_cursor_root / "rules/gf-framework.mdc"
		original = b"project-owned target\n"
		target.write_bytes(original)
		create_directory_link_fixture(real_cursor_root, self.project_root / ".cursor")

		with self.assertRaisesRegex(ValueError, "filesystem link"):
			resolve_project_path(self.project_root, ".cursor/rules/gf-framework.mdc")
		install = adapters.install_agents(
			self.project_root,
			["cursor"],
			replace_drifted=True,
		)
		uninstall = adapters.uninstall_agents(self.project_root, ["cursor"])

		self.assertFalse(install["ok"], install)
		self.assertFalse(uninstall["ok"], uninstall)
		self.assertEqual(target.read_bytes(), original)

	def test_feedback_is_redacted_bound_to_contract_and_human_gated(self) -> None:
		self._enable_network_feedback()
		candidate = self._framework_bug_candidate()
		candidate["actual"] += f" at {self.project_root} token=secret123456"
		# gf-credential-gate: allow-next=credential.assignment reason=feedback-redaction-fixture
		candidate["evidence"] = [{"kind": "observation", "text": "password=secret123456"}]

		draft_result = feedback.draft_feedback(self.project_root, candidate)
		self.assertTrue(draft_result["ok"], draft_result)
		draft = draft_result["draft"]
		body = draft["payload"]["body"]
		self.assertIn("<project>", body)
		self.assertIn("<redacted-secret>", body)
		self.assertNotIn("secret123456", body)
		prepared = feedback.prepare_submission(self.project_root, draft)
		self.assertTrue(prepared["ready"], prepared)
		blocked = feedback.submit_issue(
			self.project_root,
			draft,
			prepared["confirmation_sha256"],
		)
		self.assertFalse(blocked["ok"])
		self.assertIn("Interactive human approval", blocked["issues"][0])

		contract_path = self.project_root / ".gf/project_contract.json"
		contract = json.loads(contract_path.read_text(encoding="utf-8"))
		contract["project"]["summary"] = "Changed after approval"
		contract_path.write_text(json.dumps(contract, ensure_ascii=False), encoding="utf-8")
		self.assertFalse(feedback.prepare_submission(self.project_root, draft)["ready"])

	def test_feedback_policy_rejects_unapproved_source_and_log_evidence(self) -> None:
		candidate = self._framework_bug_candidate()
		candidate["evidence"] = [{"kind": "source_snippet", "text": "private project code"}]
		source_result = feedback.analyze_candidate(self.project_root, candidate)
		candidate["evidence"] = [{"kind": "log_excerpt", "text": "private runtime log"}]
		log_result = feedback.analyze_candidate(self.project_root, candidate)

		self.assertFalse(source_result["ok"])
		self.assertEqual(source_result["issues"][0]["code"], "source_snippet_not_allowed")
		self.assertFalse(log_result["ok"])
		self.assertEqual(log_result["issues"][0]["code"], "log_excerpt_not_allowed")

	def test_mcp_does_not_expose_public_issue_submission(self) -> None:
		names = {item["name"] for item in mcp.list_tools()}
		self.assertIn("gf_feedback_draft", names)
		self.assertIn("gf_issue_check_duplicates", names)
		self.assertIn("gf_api_module", names)
		self.assertIn("gf_package", names)
		self.assertIn("gf_contract_migration_plan", names)
		self.assertNotIn("gf_contract_migrate", names)
		self.assertNotIn("gf_issue_submit", names)
		tools_by_name = {item["name"]: item for item in mcp.list_tools()}
		self.assertTrue(tools_by_name["gf_contract_migration_plan"]["annotations"]["readOnlyHint"])
		self.assertTrue(all(
			item["annotations"]["destructiveHint"] is False
			for item in mcp.list_tools()
		))

	def test_mcp_validates_tool_arguments_before_dispatch(self) -> None:
		valid = mcp.handle_message({
			"jsonrpc": "2.0",
			"id": 1,
			"method": "tools/call",
			"params": {
				"name": "gf_package",
				"arguments": {
					"project_root": str(self.project_root),
					"package_id": "gf.kernel",
					"limit": 2,
				},
			},
		})
		invalid = mcp.handle_message({
			"jsonrpc": "2.0",
			"id": 2,
			"method": "tools/call",
			"params": {
				"name": "gf_api_module",
				"arguments": {
					"project_root": str(self.project_root),
					"module_name": "kernel",
					"limit": True,
					"unexpected": "blocked",
				},
			},
		})

		self.assertTrue(valid["result"]["structuredContent"]["ok"], valid)
		self.assertEqual(len(valid["result"]["structuredContent"]["classes"]), 2)
		self.assertEqual(invalid["error"]["code"], -32602)

	def test_mcp_contract_migration_is_plan_only(self) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		legacy = json.loads(contract_path.read_text(encoding="utf-8"))
		legacy["schema_version"] = 1
		legacy["framework"]["required_capabilities"] = [
			item["id"] for item in legacy["framework"].pop("capability_requirements")
		]
		contract_path.write_text(json.dumps(legacy), encoding="utf-8")
		plan_response = mcp.handle_message({
			"jsonrpc": "2.0",
			"id": 10,
			"method": "tools/call",
			"params": {
				"name": "gf_contract_migration_plan",
				"arguments": {"project_root": str(self.project_root)},
			},
		})
		plan = plan_response["result"]["structuredContent"]

		apply_response = mcp.handle_message({
			"jsonrpc": "2.0",
			"id": 11,
			"method": "tools/call",
			"params": {
				"name": "gf_contract_migrate",
				"arguments": {
					"project_root": str(self.project_root),
					"expected_plan_sha256": plan["plan_sha256"],
				},
			},
		})

		self.assertEqual(plan["status"], "ready")
		self.assertEqual(apply_response["error"]["code"], -32602)
		self.assertEqual(json.loads(contract_path.read_text(encoding="utf-8"))["schema_version"], 1)

	def test_cli_argument_errors_preserve_the_json_output_contract(self) -> None:
		completed = subprocess.run(
			[
				sys.executable,
				str(ADDON_ROOT / "gf_ai_project.py"),
				"contract-migrate",
				"--project-root",
				str(self.project_root),
			],
			capture_output=True,
			text=True,
			encoding="utf-8",
			timeout=30,
			check=False,
		)

		payload = json.loads(completed.stdout)
		self.assertEqual(completed.returncode, 1)
		self.assertEqual(payload["issues"][0]["code"], "invalid_arguments")
		self.assertIn("--expected-plan-sha256", payload["issues"][0]["message"])

	def test_mcp_does_not_expose_unexpected_internal_failures(self) -> None:
		request = {
			"jsonrpc": "2.0",
			"id": 7,
			"method": "tools/call",
			"params": {
				"name": "gf_agent_status",
				"arguments": {"project_root": str(self.project_root)},
			},
		}
		stderr = io.StringIO()
		with mock.patch.object(mcp, "resolve_project_root", side_effect=AssertionError("sensitive invariant detail")):
			with mock.patch("sys.stderr", stderr):
				response = mcp.handle_message(request)

		result = response["result"]["structuredContent"]
		self.assertFalse(result["ok"])
		self.assertEqual(result["issues"], [mcp.INTERNAL_ERROR_MESSAGE])
		self.assertNotIn("sensitive invariant detail", json.dumps(response))
		self.assertIn("sensitive invariant detail", stderr.getvalue())

	def test_mcp_initialize_uses_server_protocol_and_rejects_invalid_json_rpc(self) -> None:
		response = mcp.handle_message({
			"jsonrpc": "2.0",
			"id": 1,
			"method": "initialize",
			"params": {"protocolVersion": "2099-01-01"},
		})
		invalid = mcp.handle_message({"id": 2, "method": "ping"})
		invalid_params = mcp.handle_message({"jsonrpc": "2.0", "id": 3, "method": "ping", "params": []})
		invalid_id = mcp.handle_message({"jsonrpc": "2.0", "id": {}, "method": "ping"})

		self.assertEqual(response["result"]["protocolVersion"], mcp.PROTOCOL_VERSION)
		self.assertEqual(invalid["error"]["code"], -32600)
		self.assertEqual(invalid_params["error"]["code"], -32602)
		self.assertEqual(invalid_id["error"]["code"], -32600)

	def test_versioned_evaluation_cases(self) -> None:
		fixture = json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))
		api_index = catalog.load_api_index()
		catalogs = {
			"capability": (catalog.load_capabilities(), "capabilities"),
			"recipe": (catalog.load_recipes(), "recipes"),
		}
		for case in fixture["catalog_api_requirements"]:
			with self.subTest(
				catalog=case["catalog"],
				record_id=case["record_id"],
				class_name=case["class_name"],
			):
				self.assertIn(case["catalog"], catalogs)
				data, record_key = catalogs[case["catalog"]]
				records = {
					item["id"]: item
					for item in data[record_key]
					if isinstance(item, dict) and isinstance(item.get("id"), str)
				}
				self.assertIn(case["record_id"], records)
				record = records[case["record_id"]]
				declared_members = {
					requirement["class_name"]: set(requirement["members"])
					for requirement in record.get("required_api_members", [])
					if (
						isinstance(requirement, dict)
						and isinstance(requirement.get("class_name"), str)
						and isinstance(requirement.get("members"), list)
					)
				}
				expected_members = set(case["members"])
				self.assertIn(case["class_name"], declared_members)
				self.assertTrue(
					expected_members.issubset(declared_members[case["class_name"]]),
					(case, declared_members),
				)
				self.assertIn(case["class_name"], api_index["classes"])
				api_members = {
					member["name"]
					for member in api_index["classes"][case["class_name"]]["members"]
					if isinstance(member, dict) and isinstance(member.get("name"), str)
				}
				self.assertTrue(expected_members.issubset(api_members), (case, api_members))
		for case in fixture["feedback_cases"]:
			with self.subTest(case=case["id"]):
				result = feedback.analyze_candidate(self.project_root, case["candidate"])
				self.assertEqual(result["classification"], case["classification"])
				self.assertEqual(result["eligible_for_official_issue"], case["eligible"])
		for case in fixture["capability_queries"]:
			with self.subTest(query=case["query"]):
				result = catalog.capability_search(case["query"], 10, self.project_root)
				self.assertTrue(result["ok"], result)
				self.assertEqual(result["issues"], [])
				self.assertTrue(result["results"], result)
				self.assertEqual(result["catalog_version"], fixture["catalog_version"])
				self.assertEqual(result["results"][0]["id"], case["expected_id"], result)
		for case in fixture["recipe_cases"]:
			with self.subTest(recipe=case["recipe_id"]):
				result = catalog.recipe_by_id(case["recipe_id"], self.project_root)
				self.assertTrue(result["ok"], result)
				self.assertIn(case["expected_class"], result["primary_classes"])
				if "expected_step_fragment" in case:
					self.assertTrue(any(
						case["expected_step_fragment"] in step
						for step in result["steps"]
					), result)
		for case in fixture["api_queries"]:
			with self.subTest(query=case["query"]):
				result = catalog.api_search(case["query"], 10, self.project_root)
				self.assertTrue(result["ok"], result)
				self.assertEqual(result["issues"], [])
				self.assertTrue(result["results"], result)
				self.assertEqual(result["results"][0]["class_name"], case["expected_class"], result)
		for case in fixture["module_queries"]:
			with self.subTest(module=case["module"]):
				result = catalog.api_module(case["module"], 200, self.project_root)
				self.assertIn(case["expected_class"], [item["class_name"] for item in result["classes"]])
		for case in fixture["package_queries"]:
			with self.subTest(package=case["package_id"]):
				result = catalog.package_by_id(case["package_id"], 200, self.project_root)
				self.assertIn(case["expected_class"], result["classes"])

	def test_capability_search_does_not_match_inside_unrelated_words(self) -> None:
		result = catalog.capability_search("build", 30, self.project_root)
		self.assertTrue(result["ok"], result)
		result_ids = {item["id"] for item in result["results"]}
		self.assertNotIn("ui-navigation", result_ids)
		self.assertNotIn("ui-scalability", result_ids)

	def test_capability_search_prioritizes_exact_primary_class(self) -> None:
		capabilities = catalog.load_capabilities()["capabilities"]
		owners_by_class: dict[str, set[str]] = {}
		for capability in capabilities:
			for class_name in capability["primary_classes"]:
				owners_by_class.setdefault(class_name, set()).add(capability["id"])

		for class_name, owner_ids in owners_by_class.items():
			with self.subTest(class_name=class_name):
				result = catalog.capability_search(class_name, 10, self.project_root)
				self.assertTrue(result["ok"], result)
				self.assertTrue(result["results"], result)
				self.assertIn(result["results"][0]["id"], owner_ids, result)
				self.assertEqual(result["results"][0]["score"], 100, result)

	def test_capability_search_ignores_stop_word_only_queries(self) -> None:
		for query in ("and", "in", "the and"):
			with self.subTest(query=query):
				result = catalog.capability_search(query, 30, self.project_root)
				self.assertTrue(result["ok"], result)
				self.assertEqual(result["issues"], [])
				self.assertEqual(result["results"], [])

	def test_generated_catalog_and_plugin_archive_are_current_and_deterministic(self) -> None:
		source_audit = build_gf_ai_developer_kit.check_source()
		self.assertTrue(source_audit["ok"], source_audit)
		expected = build_gf_ai_developer_kit.render_api_index_text()
		actual = (ADDON_ROOT / "knowledge/api_index.json").read_text(encoding="utf-8")
		self.assertEqual(actual, expected)
		with tempfile.TemporaryDirectory(prefix="gf-ai-plugin-test-") as temporary:
			first = Path(temporary) / "first.zip"
			second = Path(temporary) / "second.zip"
			version = build_gf_ai_developer_kit.read_plugin_version()
			build_gf_ai_developer_kit.build_plugin_archive(first, version)
			build_gf_ai_developer_kit.build_plugin_archive(second, version)
			self.assertEqual(first.read_bytes(), second.read_bytes())
			audit = build_gf_ai_developer_kit.audit_plugin_archive(first, version)
			self.assertTrue(audit["ok"], audit)
			with zipfile.ZipFile(first, "a") as archive:
				archive.writestr("unexpected.txt", "unexpected")
			self.assertFalse(build_gf_ai_developer_kit.audit_plugin_archive(first, version)["ok"])

	def test_storage_backend_templates_are_validated_and_packaged(self) -> None:
		self.assertEqual(
			build_gf_ai_developer_kit.validate_storage_backend_templates(),
			[],
		)
		template_root = build_gf_ai_developer_kit.STORAGE_BACKEND_TEMPLATE_ROOT
		expected_files = {
			"README.md",
			"storage_backend.gd.txt",
			"storage_backend_conformance.gd.txt",
			"storage_backend_contract_test.gd.txt",
			"storage_provider.gd.txt",
			"storage_provider_factory.gd.txt",
			"storage_provider_fault_driver.gd.txt",
			"storage_value_limits.gd.txt",
		}
		self.assertEqual(
			{path.name for path in template_root.iterdir() if path.is_file()},
			expected_files,
		)
		readme_text = (template_root / "README.md").read_text(encoding="utf-8")
		backend_text = (template_root / "storage_backend.gd.txt").read_text(
			encoding="utf-8"
		)
		contract_test_text = (
			template_root / "storage_backend_contract_test.gd.txt"
		).read_text(encoding="utf-8")
		conformance_text = (
			template_root / "storage_backend_conformance.gd.txt"
		).read_text(encoding="utf-8")
		fault_driver_text = (
			template_root / "storage_provider_fault_driver.gd.txt"
		).read_text(encoding="utf-8")
		value_limits_text = (
			template_root / "storage_value_limits.gd.txt"
		).read_text(encoding="utf-8")
		for fragment in (
			"protocol mismatch",
			"guarantee atomic replacement",
			"logical storage key",
			"`write_options.expected_revision`",
			"`write_options.create_if_absent`",
			"bounded opaque non-empty String token",
			"closed schemas",
			"synchronous protocol",
			"cancellation: false",
		):
			self.assertIn(fragment, readme_text)
		for fragment in (
			"extends GFStorageBackend",
			"func save_data(",
			"func _save_validated_data(",
			"candidate_provider.get_protocol_version() != PROTOCOL_VERSION",
			"post_initialize_capabilities != pre_initialize_capabilities",
			"_provider.write_record_atomic(",
			"ProjectStorageValueLimits.validate_payload(",
			"provider_error_code == int(OK)",
			"func _map_provider_error(",
			"\"cancellation\": false",
			"\"sync\": false",
		):
			self.assertIn(fragment, backend_text)
		public_save = backend_text[
			backend_text.index("func save_data("):
			backend_text.index("# --- 可重写钩子 / 虚方法 ---")
		]
		hook_save = backend_text[
			backend_text.index("func _save_data("):
			backend_text.index("func _save_validated_data(")
		]
		validated_save = backend_text[
			backend_text.index("func _save_validated_data("):
			backend_text.index("func _load_data(")
		]
		self.assertEqual(public_save.count("ProjectStorageValueLimits.validate_payload("), 1)
		self.assertEqual(hook_save.count("ProjectStorageValueLimits.validate_payload("), 1)
		self.assertNotIn("ProjectStorageValueLimits.validate_payload(", validated_save)
		self.assertIn("return _save_validated_data(storage_key, data, metadata)", public_save)
		self.assertIn("return _save_validated_data(storage_key, data, metadata)", hook_save)
		for fragment in (
			"extends ProjectStorageBackendConformance",
			"class MemoryStorageProviderFactory extends ProjectStorageProviderFactory",
			"class MemoryStorageFaultDriver extends ProjectStorageProviderFaultDriver",
			"test_enforces_write_read_and_list_budgets",
			"test_atomic_faults_and_opaque_revision_conditions_preserve_state",
			"test_normalizes_unknown_errors_and_redacts_malformed_results",
			"test_defensive_copies_and_idempotent_shutdown",
			"fail_next_failed_read_with_ok",
			"_assert_list_budget_covers_complete_response",
			"for storage_key_value: Variant in _records:",
			"response_validation",
		):
			self.assertTrue(
				fragment in contract_test_text,
				"Storage contract fixture is missing a required behavior.",
			)
		self.assertLess(
			contract_test_text.index("# --- 可重写钩子 / 虚方法 ---"),
			contract_test_text.index("# --- 私有/辅助方法 ---"),
			"Storage fixture helpers must follow the virtual hook section.",
		)
		self.assertIn("FAULT_FAILED_READ_WITH_OK", fault_driver_text)
		self.assertTrue(
			"FAULT_FAILED_READ_WITH_OK" in conformance_text,
			"Storage conformance is missing the failed-with-OK fault.",
		)
		self.assertIn(
			"value.length() > maximum_string_bytes",
			value_limits_text,
		)
		length_cap_index = value_limits_text.find(
			"value.length() > maximum_string_bytes"
		)
		utf8_allocation_index = value_limits_text.find(
			"var utf8_size: int = value.to_utf8_buffer().size()"
		)
		self.assertTrue(
			0 <= length_cap_index < utf8_allocation_index,
			"Storage String length must be capped before UTF-8 allocation.",
		)
		self.assertFalse(
			"assert_eq(" in conformance_text,
			"Storage conformance must not render compared boundary values.",
		)
		self.assertFalse(
			"assert_ne(" in conformance_text,
			"Storage conformance must not render compared boundary values.",
		)
		self.assertFalse(
			"assert_not_null(" in conformance_text,
			"Storage conformance must not stringify Provider fixtures.",
		)
		self.assertFalse(
			"fail_test(" in contract_test_text,
			"Storage contract fixture must not contain a placeholder failure.",
		)
		self.assertFalse(
			"Replace this sentinel" in contract_test_text,
			"Storage contract fixture must be directly executable.",
		)

		with tempfile.TemporaryDirectory(prefix="gf-ai-storage-template-copy-") as temporary:
			project_adapter_root = (
				Path(temporary) / "res/adapters/storage/sample"
			)
			project_adapter_root.mkdir(parents=True)
			copy_map = {
				path.name: path.name.removesuffix(".txt")
				for path in template_root.glob("*.gd.txt")
			}
			for source_name, target_name in copy_map.items():
				shutil.copyfile(
					template_root / source_name,
					project_adapter_root / target_name,
				)
			self.assertEqual(
				{path.name for path in project_adapter_root.iterdir()},
				set(copy_map.values()),
			)
			self.assertEqual(
				(project_adapter_root / "storage_backend.gd").read_text(
					encoding="utf-8"
				),
				backend_text,
			)

		with tempfile.TemporaryDirectory(prefix="gf-ai-storage-template-archive-") as temporary:
			archive_path = Path(temporary) / "kit.zip"
			version = build_gf_ai_developer_kit.read_plugin_version()
			build_gf_ai_developer_kit.build_plugin_archive(archive_path, version)
			audit = build_gf_ai_developer_kit.audit_plugin_archive(
				archive_path,
				version,
			)
			self.assertTrue(audit["ok"], audit)
			with zipfile.ZipFile(archive_path, "r") as archive:
				for file_name in expected_files:
					entry_name = f"templates/adapters/storage/{file_name}"
					self.assertIn(entry_name, archive.namelist())
					self.assertTrue(
						archive.read(entry_name)
						== (template_root / file_name).read_bytes(),
						"Archived storage template bytes must match their source.",
					)

	def test_storage_backend_acceptance_fails_closed_without_godot(self) -> None:
		with (
			mock.patch.dict(
				build_gf_ai_developer_kit.os.environ,
				{"GF_GODOT_EXECUTABLE": ""},
				clear=False,
			),
			mock.patch.object(
				build_gf_ai_developer_kit.shutil,
				"which",
				return_value=None,
			),
		):
			acceptance = (
				build_gf_ai_developer_kit
				.run_storage_backend_template_acceptance()
			)

		self.assertFalse(acceptance["ok"], acceptance)
		self.assertEqual(acceptance["phase"], "engine_resolution")

	def test_storage_backend_acceptance_uses_shared_godot_resolver(self) -> None:
		configured = "D:/fixture/godot.exe"
		resolved = "D:/fixture/godot.windows.opt.tools.64.exe"
		with (
			mock.patch.object(
				build_gf_ai_developer_kit,
				"resolve_godot_executable",
				return_value=resolved,
			) as resolve_godot,
			mock.patch.object(
				build_gf_ai_developer_kit.shutil,
				"which",
				return_value=resolved,
			),
		):
			engine = (
				build_gf_ai_developer_kit
				.resolve_storage_backend_acceptance_engine(configured)
			)

		self.assertEqual(engine, resolved)
		resolve_godot.assert_called_once()
		self.assertEqual(resolve_godot.call_args.args, (configured,))
		self.assertEqual(
			resolve_godot.call_args.kwargs["environment"][
				build_gf_ai_developer_kit.GODOT_EXECUTABLE_ENV_VAR
			],
			configured,
		)

	def test_storage_backend_acceptance_has_an_explicit_cli_action(self) -> None:
		expected = {
			"ok": True,
			"phase": "complete",
			"passing_tests": 8,
			"lifecycle_ok": True,
		}
		with (
			mock.patch.object(build_gf_ai_developer_kit, "configure_stdio"),
			mock.patch.object(
				build_gf_ai_developer_kit,
				"run_storage_backend_template_acceptance",
				return_value=expected,
			) as acceptance,
			mock.patch.object(
				build_gf_ai_developer_kit,
				"print_result",
			) as print_result,
		):
			exit_code = build_gf_ai_developer_kit.main([
				"--storage-backend-acceptance",
				"--json",
			])

		self.assertEqual(exit_code, 0)
		acceptance.assert_called_once_with()
		print_result.assert_called_once_with(expected, True)

	def test_storage_acceptance_lifecycle_marker_is_closed_and_leak_free(
		self,
	) -> None:
		marker = {
			"schema_version": 1,
			"ok": True,
			"baseline_available": True,
			"warning_tracking_available": True,
			"unhandled_warning_count": 0,
			"orphan_count": 0,
			"warnings": [],
			"orphans": [],
			"details_truncated": False,
			"configuration_error": "",
		}

		def encode(payload: object) -> str:
			return (
				"GF_TEST_LIFECYCLE_GATE="
				+ json.dumps(payload, separators=(",", ":"))
			)

		clean_output = encode(marker)
		self.assertTrue(
			build_gf_ai_developer_kit
			._storage_acceptance_lifecycle_ok(clean_output)
		)
		malformed_markers = [
			{**marker, "unexpected": "field"},
			{**marker, "schema_version": True},
			{**marker, "unhandled_warning_count": False},
			{**marker, "details_truncated": 0},
			{**marker, "ok": False},
			{**marker, "warnings": [{}]},
		]
		for malformed in malformed_markers:
			self.assertFalse(
				build_gf_ai_developer_kit
				._storage_acceptance_lifecycle_ok(encode(malformed)),
				malformed,
			)
		for exit_leak in (
			"WARNING: ObjectDB instances leaked at exit.",
			"ERROR: 1 RID allocations of type 'Dummy' were leaked at exit.",
			"ERROR: 1 resource still in use at exit.",
		):
			self.assertFalse(
				build_gf_ai_developer_kit
				._storage_acceptance_lifecycle_ok(
					f"{clean_output}\n{exit_leak}"
				),
				exit_leak,
			)

	def test_storage_backend_template_validation_fails_closed(self) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-storage-template-validation-"
		) as temporary:
			copied_template_root = Path(temporary) / "storage"
			shutil.copytree(
				build_gf_ai_developer_kit.STORAGE_BACKEND_TEMPLATE_ROOT,
				copied_template_root,
			)
			contract_test_path = (
				copied_template_root / "storage_backend_contract_test.gd.txt"
			)
			contract_test_path.write_text(
				"extends GutTest\n\nfunc test_placeholder() -> void:\n\tfail_test(\"todo\")\n",
				encoding="utf-8",
			)

			issues = build_gf_ai_developer_kit.validate_storage_backend_templates(
				copied_template_root
			)

			self.assertTrue(
				any(
					"missing required contract text" in issue
					for issue in issues
				),
				issues,
			)
			self.assertTrue(
				any(
					"without a placeholder sentinel" in issue
					for issue in issues
				),
				issues,
			)

	def test_storage_backend_template_validation_rejects_linked_source(self) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-storage-template-link-"
		) as temporary:
			temporary_root = Path(temporary)
			copied_template_root = temporary_root / "storage"
			shutil.copytree(
				build_gf_ai_developer_kit.STORAGE_BACKEND_TEMPLATE_ROOT,
				copied_template_root,
			)
			outside = temporary_root / "outside.txt"
			outside.write_text("outside", encoding="utf-8")
			linked_template = copied_template_root / "storage_backend.gd.txt"
			linked_template.unlink()
			try:
				os.symlink(outside, linked_template)
			except OSError as exc:
				self.skipTest(f"Symbolic links are unavailable: {type(exc).__name__}")

			issues = build_gf_ai_developer_kit.validate_storage_backend_templates(
				copied_template_root
			)

			self.assertTrue(
				any("owned-file boundary" in issue for issue in issues),
				issues,
			)

	def test_storage_backend_template_validation_rejects_linked_parent(self) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-storage-template-parent-link-"
		) as temporary:
			temporary_root = Path(temporary)
			outside_root = temporary_root / "outside-storage"
			shutil.copytree(
				build_gf_ai_developer_kit.STORAGE_BACKEND_TEMPLATE_ROOT,
				outside_root,
			)
			linked_root = temporary_root / "linked-storage"
			try:
				create_directory_link_fixture(outside_root, linked_root)
			except OSError as exc:
				self.skipTest(
					"Directory link fixtures are unavailable: "
					f"{type(exc).__name__}"
				)
			try:
				issues = (
					build_gf_ai_developer_kit
					.validate_storage_backend_templates(linked_root)
				)
			finally:
				if os.path.lexists(linked_root):
					if os.name == "nt":
						linked_root.rmdir()
					else:
						linked_root.unlink()

			self.assertTrue(
				any("owned-file boundary" in issue for issue in issues),
				issues,
			)

	def test_storage_backend_template_validation_redacts_unexpected_names(
		self,
	) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-storage-template-name-redaction-"
		) as temporary:
			template_root = Path(temporary) / "storage"
			shutil.copytree(
				build_gf_ai_developer_kit.STORAGE_BACKEND_TEMPLATE_ROOT,
				template_root,
			)
			synthetic_secret = "ghp_" + "Ab9" * 16
			(template_root / f"api_key={synthetic_secret}.txt").write_text(
				"ordinary",
				encoding="utf-8",
			)

			issues = build_gf_ai_developer_kit.validate_storage_backend_templates(
				template_root
			)
			rendered = json.dumps(issues, ensure_ascii=False)

			self.assertIn(
				"Storage backend template has unexpected files (count=1).",
				issues,
			)
			self.assertNotIn(synthetic_secret, rendered)

	def test_storage_owned_read_rejects_open_time_replacement(self) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-storage-template-read-race-"
		) as temporary:
			owner_root = Path(temporary)
			source = owner_root / "source.txt"
			replacement = owner_root / "replacement.txt"
			source.write_bytes(b"safe-source")
			replacement.write_bytes(b"other-source")
			real_open = os.open
			replaced = False

			def replace_before_open(
				path: str | bytes | os.PathLike[str] | os.PathLike[bytes],
				flags: int,
				mode: int = 0o777,
			) -> int:
				nonlocal replaced
				if not replaced and Path(path) == source:
					replaced = True
					os.replace(replacement, source)
				return real_open(path, flags, mode)

			with mock.patch.object(
				build_gf_ai_developer_kit.os,
				"open",
				side_effect=replace_before_open,
			):
				with self.assertRaisesRegex(ValueError, "identity changed"):
					build_gf_ai_developer_kit._read_owned_bytes(
						source,
						owner_root,
						1024,
					)

	def test_storage_owned_read_rejects_parent_identity_drift(self) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-storage-template-parent-race-"
		) as temporary:
			owner_root = Path(temporary)
			source = owner_root / "source.txt"
			race_sentinel = "synthetic-parent-race-value"
			source.write_text(race_sentinel, encoding="utf-8")
			real_snapshot = (
				build_gf_ai_developer_kit
				._snapshot_owned_directory_chain
			)
			snapshot_count = 0

			def drift_after_open(
				root: Path,
				directory: Path,
			) -> tuple[tuple[Path, os.stat_result], ...]:
				nonlocal snapshot_count
				snapshot_count += 1
				snapshot = real_snapshot(root, directory)
				if snapshot_count < 3:
					return snapshot
				parent_path, parent_stat = snapshot[-1]
				drifted_stat = mock.Mock(
					st_dev=parent_stat.st_dev,
					st_ino=parent_stat.st_ino + 1,
					st_mode=parent_stat.st_mode,
					st_file_attributes=int(
						getattr(parent_stat, "st_file_attributes", 0)
					),
				)
				return (*snapshot[:-1], (parent_path, drifted_stat))

			with mock.patch.object(
				build_gf_ai_developer_kit,
				"_snapshot_owned_directory_chain",
				side_effect=drift_after_open,
			):
				with self.assertRaises(ValueError) as raised:
					build_gf_ai_developer_kit._read_owned_bytes(
						source,
						owner_root,
						1024,
					)

			self.assertFalse(
				race_sentinel in str(raised.exception),
				"Owned-read failure disclosed synthetic fixture content.",
			)

	def test_storage_owned_copy_uses_exclusive_target_creation(self) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-storage-template-copy-race-"
		) as temporary:
			temporary_root = Path(temporary)
			source_root = temporary_root / "source"
			target_root = temporary_root / "target"
			source_root.mkdir()
			target_root.mkdir()
			source = source_root / "source.txt"
			target = target_root / "target.txt"
			source.write_bytes(b"ordinary")
			target.write_bytes(b"occupied")

			with build_gf_ai_developer_kit._private_owned_root(temporary_root):
				with self.assertRaises(FileExistsError):
					build_gf_ai_developer_kit._copy_owned_regular_file(
						source,
						target,
						source_root,
						1024,
						target_root,
					)
			self.assertEqual(target.read_bytes(), b"occupied")

	@unittest.skipUnless(
		os.name == "nt",
		"Windows directory HANDLE pinning is platform-specific.",
	)
	def test_storage_owned_target_blocks_or_detects_parent_path_exchange(
		self,
	) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-storage-target-parent-drift-"
		) as temporary:
			private_root = Path(temporary)
			target_parent = private_root / "target"
			target_parent.mkdir()
			target = target_parent / "payload.bin"
			moved_parent = private_root / "moved-target"
			synthetic_secret = b"synthetic-target-value-that-must-not-escape"

			with build_gf_ai_developer_kit._private_owned_root(private_root):
				binding = (
					build_gf_ai_developer_kit
					._validated_private_root_for(target_parent)
				)
				binding.ensure_directory(target_parent)
				try:
					os.replace(target_parent, moved_parent)
				except OSError:
					build_gf_ai_developer_kit._write_owned_target_bytes(
						target,
						synthetic_secret,
						private_root,
					)
					self.assertEqual(target.read_bytes(), synthetic_secret)
				else:
					with self.assertRaisesRegex(
						ValueError,
						"identity changed",
					):
						binding.verify()
					with self.assertRaisesRegex(
						ValueError,
						"identity changed",
					):
						build_gf_ai_developer_kit._write_owned_target_bytes(
							target,
							synthetic_secret,
							private_root,
						)
					self.assertFalse(
						(moved_parent / target.name).exists()
					)

	def test_storage_owned_target_rejects_linked_parent(self) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-storage-target-linked-parent-"
		) as temporary:
			private_root = Path(temporary)
			outside_root = private_root / "outside"
			outside_root.mkdir()
			linked_parent = private_root / "linked"
			try:
				create_directory_link_fixture(outside_root, linked_parent)
			except OSError as exc:
				self.skipTest(
					"Directory link fixtures are unavailable: "
					f"{type(exc).__name__}"
				)
			target = linked_parent / "payload.bin"
			try:
				with build_gf_ai_developer_kit._private_owned_root(private_root):
					with self.assertRaisesRegex(
						ValueError,
						"link or reparse|identity changed|unavailable",
					):
						build_gf_ai_developer_kit._write_owned_target_bytes(
							target,
							b"ordinary",
							private_root,
						)
			finally:
				if os.path.lexists(linked_parent):
					if os.name == "nt":
						linked_parent.rmdir()
					else:
						linked_parent.unlink()
			self.assertFalse((outside_root / "payload.bin").exists())

	def test_storage_owned_target_requires_private_root_without_dir_fd(self) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-storage-target-private-root-"
		) as temporary:
			private_root = Path(temporary)
			target = private_root / "payload.bin"
			with mock.patch.object(
				build_gf_ai_developer_kit,
				"_supports_secure_directory_descriptors",
				return_value=False,
			):
				with self.assertRaisesRegex(
					ValueError,
					"process-created private root",
				):
					build_gf_ai_developer_kit._write_owned_target_bytes(
						target,
						b"ordinary",
						private_root,
					)
			self.assertFalse(target.exists())

	def test_owned_directory_descriptor_closes_next_fd_when_fstat_fails(
		self,
	) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-owned-directory-fstat-"
		) as temporary:
			owner_root = Path(temporary)
			root_metadata = os.lstat(owner_root)

			def controlled_fstat(file_descriptor: int) -> os.stat_result:
				if file_descriptor == 100:
					return root_metadata
				if file_descriptor == 102:
					raise OSError("simulated next-directory fstat failure")
				raise AssertionError(f"Unexpected descriptor: {file_descriptor}")

			with (
				mock.patch.object(
					build_gf_ai_developer_kit,
					"_supports_secure_directory_descriptors",
					return_value=True,
				),
				mock.patch.object(
					build_gf_ai_developer_kit.os,
					"open",
					side_effect=(100, 102),
				),
				mock.patch.object(
					build_gf_ai_developer_kit.os,
					"dup",
					return_value=101,
				),
				mock.patch.object(
					build_gf_ai_developer_kit.os,
					"fstat",
					side_effect=controlled_fstat,
				),
				mock.patch.object(
					build_gf_ai_developer_kit.os,
					"close",
				) as close_descriptor,
			):
				with self.assertRaisesRegex(
					OSError,
					"simulated next-directory fstat failure",
				):
					with (
						build_gf_ai_developer_kit
						._open_owned_directory_descriptor(
							owner_root,
							owner_root / "child",
							create=False,
						)
					):
						self.fail("Descriptor context must not be entered.")

			self.assertEqual(
				close_descriptor.call_args_list,
				[mock.call(102), mock.call(101), mock.call(100)],
			)

	def test_storage_acceptance_failure_does_not_echo_runtime_lines(self) -> None:
		synthetic_secret = "synthetic-provider-value-that-must-not-escape"
		result = build_gf_ai_developer_kit._storage_acceptance_failure(
			"gut",
			1,
			"SCRIPT ERROR: api_key=" + synthetic_secret,
		)

		self.assertFalse(
			synthetic_secret in json.dumps(result, ensure_ascii=False),
			"Storage acceptance failure output disclosed synthetic fixture content.",
		)
		self.assertEqual(
			result["diagnostics"],
			["Storage acceptance reported a script error."],
		)

	def test_storage_acceptance_rejects_missing_and_oversized_logs(self) -> None:
		result = build_gf_ai_developer_kit.SupervisedProcessResult(
			return_code=0,
			stdout="",
			stderr="",
			timed_out=False,
			duration_seconds=0.0,
			pid=1,
		)
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-storage-template-log-"
		) as temporary:
			log_path = Path(temporary) / "acceptance.log"
			with self.assertRaises((OSError, ValueError)):
				build_gf_ai_developer_kit._combined_storage_acceptance_output(
					result,
					log_path,
				)
			log_path.write_bytes(
				b"x"
				* (
					build_gf_ai_developer_kit
					.STORAGE_ACCEPTANCE_LOG_BYTE_LIMIT
					+ 1
				)
			)
			with self.assertRaises(ValueError):
				build_gf_ai_developer_kit._combined_storage_acceptance_output(
					result,
					log_path,
				)

	def test_storage_acceptance_supervisor_bounds_both_output_streams(self) -> None:
		result = build_gf_ai_developer_kit.run_supervised_process(
			[
				sys.executable,
				"-c",
				(
					"import sys; "
					"sys.stdout.write('o' * 4096); "
					"sys.stderr.write('e' * 4096)"
				),
			],
			cwd=ROOT,
			timeout_seconds=30.0,
			max_stdout_characters=64,
			max_stderr_characters=64,
		)

		self.assertEqual(result.return_code, 0)
		self.assertFalse(result.timed_out)
		self.assertTrue(result.stdout_truncated)
		self.assertTrue(result.stderr_truncated)
		self.assertLessEqual(len(result.stdout), 64)
		self.assertLessEqual(len(result.stderr), 64)

	def test_storage_owned_path_rejects_windows_reparse_attribute(self) -> None:
		fake_stat = mock.Mock(
			st_mode=0o100644,
			st_file_attributes=0x400,
		)
		with mock.patch.object(
			build_gf_ai_developer_kit.os,
			"lstat",
			return_value=fake_stat,
		):
			self.assertTrue(
				build_gf_ai_developer_kit._path_is_link_or_reparse(
					Path("synthetic")
				)
			)

	def test_platform_adapter_templates_are_strictly_validated(self) -> None:
		self.assertEqual(build_gf_ai_developer_kit.validate_platform_adapter_templates(), [])
		template_root = build_gf_ai_developer_kit.PLATFORM_ADAPTER_TEMPLATE_ROOT
		readme_text = (template_root / "README.md").read_text(encoding="utf-8")
		contract_test_text = (template_root / "adapter_contract_test.gd.txt").read_text(
			encoding="utf-8"
		)
		platform_adapter_text = (template_root / "platform_adapter.gd.txt").read_text(
			encoding="utf-8"
		)
		lobby_backend_text = (template_root / "lobby_backend.gd.txt").read_text(
			encoding="utf-8"
		)
		profile = json.loads(
			(template_root / "compatibility_profile.json").read_text(encoding="utf-8")
		)
		self.assertEqual(
			validate_schema_file(
				profile,
				build_gf_ai_developer_kit.PLATFORM_ADAPTER_PROFILE_SCHEMA_PATH,
			),
			[],
		)
		self.assertEqual(profile["godot_version"], "4.7.0")
		self.assertEqual(
			profile["framework_version"],
			build_gf_ai_developer_kit.read_plugin_version(),
		)
		for heading in (
			"## Native mode and fail-closed probing",
			"## Native artifact matrix",
			"## Threading and callback pump",
			"## Shutdown and cancellation",
			"## Permissions and sensitive data",
			"## Reproducible supply chain",
			"## Editor and export boundary",
		):
			self.assertIn(heading, readme_text)
		self.assertIn("test_native_adapter_acceptance_matrix", contract_test_text)
		self.assertIn(
			"Replace this sentinel with the native Adapter acceptance matrix.",
			contract_test_text,
		)
		self.assertIn("main-thread pump", platform_adapter_text)
		self.assertIn("main-thread pump", lobby_backend_text)
		self.assertIn("bounded timeout", platform_adapter_text)
		self.assertIn("bounded timeout", lobby_backend_text)

		native_boundary = profile["metadata"]["native_boundary"]
		self.assertIn(native_boundary["mode"], ("script_only", "optional", "required"))
		availability_probe = native_boundary["availability_probe"]
		self.assertIn(availability_probe["kind"], ("class_db", "resource"))
		self.assertTrue(availability_probe["side_effect_free"])
		if availability_probe["kind"] == "class_db":
			self.assertIn("class_name", availability_probe)
		else:
			self.assertIn("resource_path", availability_probe)
		self.assertIn("call_thread", native_boundary)
		self.assertIn("callback_thread", native_boundary)
		self.assertIn("callback_pump", native_boundary)
		self.assertGreater(native_boundary["shutdown_timeout_msec"], 0)
		self.assertIn("permissions", native_boundary)
		self.assertIn("editor_only", native_boundary)
		self.assertIn("dependency_lock_path", native_boundary)
		self.assertIn("offline_rebuild_verified", native_boundary)

		artifacts = profile["artifacts"]
		descriptor_artifacts = [
			item for item in artifacts if item.get("kind") == "gdextension_descriptor"
		]
		native_libraries = [
			item for item in artifacts if item.get("kind") == "native_library"
		]
		self.assertEqual(len(descriptor_artifacts), 1)
		self.assertGreaterEqual(len(native_libraries), 2)
		descriptor = descriptor_artifacts[0]
		self.assertEqual(descriptor["path"], native_boundary["descriptor_path"])
		self.assertIn("minimum_godot_version", descriptor["metadata"])
		self.assertIn("reloadable", descriptor["metadata"])
		target_tuples = set()
		for artifact in native_libraries:
			metadata = artifact["metadata"]
			target_tuple = (
				metadata["platform"],
				metadata["architecture"],
				metadata["build_configuration"],
			)
			self.assertNotIn(target_tuple, target_tuples)
			target_tuples.add(target_tuple)
			self.assertIn(metadata["export_scope"], ("editor", "runtime"))
			self.assertIn("source_version", metadata)
			self.assertIn("license_id", metadata)
			self.assertIn("sha256", artifact)
			self.assertIn("size_bytes", artifact)
		declared_export_targets = {
			(
				item["platform"],
				item["architecture"],
				item["build_configuration"],
			)
			for item in native_boundary["export_targets"]
		}
		self.assertEqual(target_tuples, declared_export_targets)

		native_dependencies = profile["metadata"]["native_dependencies"]
		self.assertTrue(native_dependencies)
		for dependency in native_dependencies:
			self.assertIn("version", dependency)
			self.assertIn("source", dependency)
			self.assertIn("sha256", dependency)
			self.assertIn("license_id", dependency)

		with tempfile.TemporaryDirectory(prefix="gf-ai-native-profile-test-") as temporary:
			copied_template_root = Path(temporary) / "platform"
			shutil.copytree(
				build_gf_ai_developer_kit.PLATFORM_ADAPTER_TEMPLATE_ROOT,
				copied_template_root,
			)
			copied_profile_path = copied_template_root / "compatibility_profile.json"
			resource_profile = json.loads(copied_profile_path.read_text(encoding="utf-8"))
			resource_probe = resource_profile["metadata"]["native_boundary"]["availability_probe"]
			resource_probe["kind"] = "resource"
			resource_probe.pop("class_name")
			resource_probe["resource_path"] = resource_profile["metadata"]["native_boundary"][
				"descriptor_path"
			]
			copied_profile_path.write_text(
				json.dumps(resource_profile, ensure_ascii=False, indent=2) + "\n",
				encoding="utf-8",
			)
			self.assertEqual(
				build_gf_ai_developer_kit.validate_platform_adapter_templates(
					copied_template_root
				),
				[],
			)

			resource_probe.pop("resource_path")
			copied_profile_path.write_text(
				json.dumps(resource_profile, ensure_ascii=False, indent=2) + "\n",
				encoding="utf-8",
			)
			issues = build_gf_ai_developer_kit.validate_platform_adapter_templates(
				copied_template_root
			)
			self.assertTrue(
				any("resource_path" in issue for issue in issues),
				issues,
			)

			script_only_profile = json.loads(
				(template_root / "compatibility_profile.json").read_text(encoding="utf-8")
			)
			script_only_profile["metadata"]["native_boundary"]["mode"] = "script_only"
			copied_profile_path.write_text(
				json.dumps(script_only_profile, ensure_ascii=False, indent=2) + "\n",
				encoding="utf-8",
			)
			issues = build_gf_ai_developer_kit.validate_platform_adapter_templates(
				copied_template_root
			)
			self.assertTrue(
				any("script_only native mode" in issue for issue in issues),
				issues,
			)

			invalid_hash_profile = json.loads(
				(template_root / "compatibility_profile.json").read_text(encoding="utf-8")
			)
			invalid_hash_profile["artifacts"][0]["sha256"] = "not-a-digest"
			copied_profile_path.write_text(
				json.dumps(invalid_hash_profile, ensure_ascii=False, indent=2) + "\n",
				encoding="utf-8",
			)
			issues = build_gf_ai_developer_kit.validate_platform_adapter_templates(
				copied_template_root
			)
			self.assertTrue(any("sha256" in issue for issue in issues), issues)

			invalid_path_profile = json.loads(
				(template_root / "compatibility_profile.json").read_text(encoding="utf-8")
			)
			invalid_path_profile["artifacts"][0][
				"path"
			] = "res://adapters/platform/../outside.gdextension"
			invalid_path_profile["metadata"]["native_boundary"][
				"descriptor_path"
			] = "res://adapters/platform/../outside.gdextension"
			copied_profile_path.write_text(
				json.dumps(invalid_path_profile, ensure_ascii=False, indent=2) + "\n",
				encoding="utf-8",
			)
			issues = build_gf_ai_developer_kit.validate_platform_adapter_templates(
				copied_template_root
			)
			self.assertTrue(
				any("canonical cross-platform" in issue for issue in issues),
				issues,
			)

		with tempfile.TemporaryDirectory(prefix="gf-ai-adapter-template-") as temporary:
			copied_template_root = Path(temporary) / "platform"
			shutil.copytree(
				build_gf_ai_developer_kit.PLATFORM_ADAPTER_TEMPLATE_ROOT,
				copied_template_root,
			)
			(copied_template_root / "platform_adapter.gd.txt").write_text(
				"extends RefCounted\n",
				encoding="utf-8",
			)
			issues = build_gf_ai_developer_kit.validate_platform_adapter_templates(
				copied_template_root
			)
			self.assertTrue(
				any("platform_adapter.gd.txt" in issue for issue in issues),
				issues,
			)

			(copied_template_root / "compatibility_profile.json").write_text(
				'{"profile_id":"broken","godot_version":NaN}',
				encoding="utf-8",
			)
			issues = build_gf_ai_developer_kit.validate_platform_adapter_templates(
				copied_template_root
			)
			self.assertTrue(
				any("compatibility profile is invalid" in issue for issue in issues),
				issues,
			)

	def test_platform_adapter_template_validation_uses_the_owned_file_boundary(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-ai-platform-owned-source-") as temporary:
			root = Path(temporary)
			copied_template_root = root / "platform"
			shutil.copytree(
				build_gf_ai_developer_kit.PLATFORM_ADAPTER_TEMPLATE_ROOT,
				copied_template_root,
			)
			(copied_template_root / "unexpected.txt").write_text("unexpected\n", encoding="utf-8")
			issues = build_gf_ai_developer_kit.validate_platform_adapter_templates(
				copied_template_root
			)
			self.assertTrue(any("unexpected files" in issue for issue in issues), issues)

			(copied_template_root / "unexpected.txt").unlink()
			(copied_template_root / "platform_adapter.gd.txt").write_bytes(b"x" * 33)
			with mock.patch.object(build_gf_ai_developer_kit, "ADAPTER_TEMPLATE_BYTE_LIMIT", 32):
				issues = build_gf_ai_developer_kit.validate_platform_adapter_templates(
					copied_template_root
				)
			self.assertTrue(any("owned-file boundary" in issue for issue in issues), issues)

			real_template_root = root / "real-platform"
			shutil.copytree(
				build_gf_ai_developer_kit.PLATFORM_ADAPTER_TEMPLATE_ROOT,
				real_template_root,
			)
			linked_template_root = root / "linked-platform"
			create_directory_link_fixture(real_template_root, linked_template_root)
			issues = build_gf_ai_developer_kit.validate_platform_adapter_templates(
				linked_template_root
			)
			self.assertTrue(any("owned-file boundary" in issue for issue in issues), issues)

	def test_platform_native_profile_rejects_non_scalar_mode_without_crashing(self) -> None:
		for invalid_mode in ([], {}):
			with self.subTest(invalid_mode=invalid_mode):
				profile = self._load_platform_adapter_profile()
				profile["metadata"]["native_boundary"]["mode"] = invalid_mode

				issues = self._validate_platform_adapter_profile(profile)

				self.assertTrue(
					any("native_boundary.mode" in issue for issue in issues),
					issues,
				)

	def test_platform_native_profile_schema_rejects_malformed_shapes_without_crashing(
		self,
	) -> None:
		oversized_version = f"{'9' * 5000}.0.0"
		mutations = (
			(
				"artifacts[0].kind",
				lambda profile: profile["artifacts"][0].__setitem__("kind", []),
			),
			(
				"artifacts[0].metadata.export_scope",
				lambda profile: profile["artifacts"][0]["metadata"].__setitem__(
					"export_scope",
					{},
				),
			),
			(
				"metadata.native_boundary.availability_probe.kind",
				lambda profile: profile["metadata"]["native_boundary"][
					"availability_probe"
				].__setitem__("kind", []),
			),
			(
				"metadata.native_boundary.call_thread",
				lambda profile: profile["metadata"]["native_boundary"].__setitem__(
					"call_thread",
					[],
				),
			),
			(
				"artifacts[1].metadata.source_id",
				lambda profile: profile["artifacts"][1]["metadata"].__setitem__(
					"source_id",
					[],
				),
			),
			(
				"metadata",
				lambda profile: profile.__setitem__("metadata", []),
			),
			(
				"packages",
				lambda profile: profile.__setitem__("packages", None),
			),
			(
				"godot_version",
				lambda profile: profile.__setitem__(
					"godot_version",
					oversized_version,
				),
			),
			(
				"artifacts[0].metadata.minimum_godot_version",
				lambda profile: profile["artifacts"][0]["metadata"].__setitem__(
					"minimum_godot_version",
					oversized_version,
				),
			),
			(
				"contract_versions",
				lambda profile: profile["metadata"]["contract_versions"].__setitem__(
					"gf.test.contract",
					oversized_version,
				),
			),
		)
		for expected_path, mutate in mutations:
			with self.subTest(expected_path=expected_path):
				profile = self._load_platform_adapter_profile()
				mutate(profile)

				issues = self._validate_platform_adapter_profile(profile)

				self.assertTrue(
					any(expected_path in issue for issue in issues),
					issues,
				)
		self.assertIsNone(
			build_gf_ai_developer_kit._parse_exact_semver(oversized_version)
		)

	def test_ai_kit_source_check_reports_invalid_platform_profile_without_crashing(
		self,
	) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-ai-native-profile-source-") as temporary:
			copied_template_root = Path(temporary) / "platform"
			shutil.copytree(
				build_gf_ai_developer_kit.PLATFORM_ADAPTER_TEMPLATE_ROOT,
				copied_template_root,
			)
			profile_path = copied_template_root / "compatibility_profile.json"
			profile = json.loads(profile_path.read_text(encoding="utf-8"))
			profile["metadata"]["native_boundary"]["mode"] = []
			profile_path.write_text(
				json.dumps(profile, ensure_ascii=False, indent=2) + "\n",
				encoding="utf-8",
			)
			api_index = json.loads(
				(build_gf_ai_developer_kit.API_INDEX_PATH).read_text(encoding="utf-8")
			)
			with mock.patch.object(
				build_gf_ai_developer_kit,
				"PLATFORM_ADAPTER_TEMPLATE_ROOT",
				copied_template_root,
			):
				result = build_gf_ai_developer_kit.check_source(api_index)

		self.assertFalse(result["ok"], result)
		self.assertTrue(
			any("native_boundary.mode" in issue for issue in result["issues"]),
			result,
		)

	def test_platform_native_profile_binds_resource_probe_to_descriptor(self) -> None:
		valid_resource_profile = self._load_platform_adapter_profile()
		valid_resource_boundary = valid_resource_profile["metadata"]["native_boundary"]
		valid_resource_probe = valid_resource_boundary["availability_probe"]
		valid_resource_probe["kind"] = "resource"
		valid_resource_probe.pop("class_name")
		valid_resource_probe["resource_path"] = valid_resource_boundary["descriptor_path"]
		self.assertEqual(
			self._validate_platform_adapter_profile(valid_resource_profile),
			[],
		)

		for resource_path in (
			"res://icon.svg",
			self._load_platform_adapter_profile()["artifacts"][1]["path"],
		):
			with self.subTest(resource_path=resource_path):
				profile = self._load_platform_adapter_profile()
				probe = profile["metadata"]["native_boundary"]["availability_probe"]
				probe["kind"] = "resource"
				probe.pop("class_name")
				probe["resource_path"] = resource_path

				issues = self._validate_platform_adapter_profile(profile)

				self.assertTrue(
					any(
						"resource_path must match the descriptor artifact" in issue
						for issue in issues
					),
					issues,
				)

		script_only_profile = self._load_platform_adapter_profile()
		script_only_boundary = script_only_profile["metadata"]["native_boundary"]
		script_only_boundary["mode"] = "script_only"
		script_only_boundary.pop("descriptor_path")
		script_only_boundary.pop("dependency_lock_path")
		script_only_boundary["export_targets"] = []
		script_only_profile["artifacts"] = []
		script_only_profile["metadata"]["native_dependencies"] = []
		self.assertEqual(
			self._validate_platform_adapter_profile(script_only_profile),
			[],
		)
		for field_name, field_value in (
			(
				"descriptor_path",
				"res://adapters/platform/sample/native/sample.gdextension",
			),
			(
				"dependency_lock_path",
				"res://adapters/platform/sample/native/dependencies.lock.json",
			),
		):
			with self.subTest(script_only_native_path=field_name):
				script_only_boundary[field_name] = field_value
				issues = self._validate_platform_adapter_profile(script_only_profile)
				self.assertTrue(
					any(
						f"script_only native mode must not declare {field_name}" in issue
						for issue in issues
					),
					issues,
				)
				script_only_boundary.pop(field_name)

		script_only_probe = script_only_boundary["availability_probe"]
		script_only_probe["kind"] = "resource"
		script_only_probe.pop("class_name")
		script_only_probe["resource_path"] = "res://adapters/platform/sample/probe.tres"
		script_only_issues = self._validate_platform_adapter_profile(script_only_profile)
		self.assertTrue(
			any("invalid in script_only mode" in issue for issue in script_only_issues),
			script_only_issues,
		)

	def test_platform_native_profile_requires_runtime_scope_for_runtime_adapter(self) -> None:
		for native_mode in ("required", "optional"):
			valid_runtime_profile = self._load_platform_adapter_profile()
			valid_runtime_profile["metadata"]["native_boundary"]["mode"] = native_mode
			self.assertEqual(
				self._validate_platform_adapter_profile(valid_runtime_profile),
				[],
			)
			for artifact_index, artifact in enumerate(valid_runtime_profile["artifacts"]):
				with self.subTest(
					native_mode=native_mode,
					runtime_artifact=artifact["id"],
				):
					profile = self._load_platform_adapter_profile()
					profile["metadata"]["native_boundary"]["mode"] = native_mode
					profile["artifacts"][artifact_index]["metadata"][
						"export_scope"
					] = "editor"

					issues = self._validate_platform_adapter_profile(profile)

					self.assertTrue(
						any(
							artifact["id"] in issue
							and "for a non-editor-only adapter" in issue
							for issue in issues
						),
						issues,
					)

		valid_editor_profile = self._load_platform_adapter_profile()
		valid_editor_profile["metadata"]["native_boundary"]["editor_only"] = True
		for artifact in valid_editor_profile["artifacts"]:
			artifact["metadata"]["export_scope"] = "editor"
		self.assertEqual(
			self._validate_platform_adapter_profile(valid_editor_profile),
			[],
		)
		for artifact_index, artifact in enumerate(valid_editor_profile["artifacts"]):
			with self.subTest(editor_artifact=artifact["id"]):
				profile = self._load_platform_adapter_profile()
				profile["metadata"]["native_boundary"]["editor_only"] = True
				for candidate in profile["artifacts"]:
					candidate["metadata"]["export_scope"] = "editor"
				profile["artifacts"][artifact_index]["metadata"][
					"export_scope"
				] = "runtime"

				issues = self._validate_platform_adapter_profile(profile)

				self.assertTrue(
					any(
						artifact["id"] in issue
						and "for an editor-only adapter" in issue
						for issue in issues
					),
					issues,
				)

	def test_platform_native_profile_rejects_descriptor_above_target_godot(self) -> None:
		for target_version, minimum_version in (
			("4.5.0", "4.6.0"),
			("4.9.0", "4.10.0"),
			("4.5.0", "5.0.0"),
		):
			with self.subTest(
				target_version=target_version,
				minimum_version=minimum_version,
			):
				profile = self._load_platform_adapter_profile()
				profile["godot_version"] = target_version
				profile["artifacts"][0]["metadata"][
					"minimum_godot_version"
				] = minimum_version

				issues = self._validate_platform_adapter_profile(profile)

				self.assertTrue(
					any("exceeds target Godot version" in issue for issue in issues),
					issues,
				)

		for target_version, minimum_version in (
			("4.7.0", "4.7.0"),
			("4.10.0", "4.9.99"),
			("10.0.0", "9.99.99"),
		):
			with self.subTest(
				valid_target_version=target_version,
				valid_minimum_version=minimum_version,
			):
				profile = self._load_platform_adapter_profile()
				profile["godot_version"] = target_version
				profile["artifacts"][0]["metadata"][
					"minimum_godot_version"
				] = minimum_version
				self.assertEqual(
					self._validate_platform_adapter_profile(profile),
					[],
				)

	def test_platform_native_profile_tracks_framework_version_exactly(self) -> None:
		profile = self._load_platform_adapter_profile()
		current_version = build_gf_ai_developer_kit.read_plugin_version()
		profile["framework_version"] = (
			"0.0.1" if current_version == "0.0.0" else "0.0.0"
		)

		issues = self._validate_platform_adapter_profile(profile)

		self.assertTrue(
			any("must match the GF Framework version" in issue for issue in issues),
			issues,
		)

	def test_platform_native_profile_deduplicates_paths_case_insensitively(self) -> None:
		for first_path, duplicate_path in (
			(
				"res://adapters/platform/sample/bin/provider.dll",
				"res://adapters/platform/sample/bin/PROVIDER.DLL",
			),
			(
				"res://adapters/platform/sample/bin/café.dll",
				"res://adapters/platform/sample/bin/cafe\u0301.dll",
			),
		):
			with self.subTest(first_path=first_path, duplicate_path=duplicate_path):
				profile = self._load_platform_adapter_profile()
				profile["artifacts"][1]["path"] = first_path
				profile["artifacts"][2]["path"] = duplicate_path

				issues = self._validate_platform_adapter_profile(profile)

				self.assertTrue(
					any("path is duplicated" in issue for issue in issues),
					issues,
				)

	def test_platform_native_profile_cross_checks_library_provenance(self) -> None:
		for field_name, invalid_value in (
			("source_version", "contradictory-version"),
			("license_id", "contradictory-license"),
		):
			with self.subTest(field_name=field_name):
				profile = self._load_platform_adapter_profile()
				profile["artifacts"][1]["metadata"][field_name] = invalid_value

				issues = self._validate_platform_adapter_profile(profile)

				self.assertTrue(
					any(
						f"{field_name} must match native dependency" in issue
						for issue in issues
					),
					issues,
				)

	def test_platform_native_profile_requires_gdextension_descriptor_path(self) -> None:
		for invalid_suffix in (".txt", ".GDEXTENSION", ".gdextension.json", ""):
			with self.subTest(invalid_suffix=invalid_suffix):
				profile = self._load_platform_adapter_profile()
				invalid_descriptor_path = (
					"res://adapters/platform/sample/not_a_descriptor" + invalid_suffix
				)
				profile["artifacts"][0]["path"] = invalid_descriptor_path
				profile["metadata"]["native_boundary"][
					"descriptor_path"
				] = invalid_descriptor_path

				issues = self._validate_platform_adapter_profile(profile)

				self.assertTrue(
					any("must use a .gdextension path" in issue for issue in issues),
					issues,
				)

	def test_plugin_builder_reads_only_owned_source_files(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-ai-owned-source-") as temporary:
			root = Path(temporary)
			owner_root = root / "owner"
			owner_root.mkdir()
			owned = owner_root / "owned.txt"
			outside = root / "outside.txt"
			owned.write_bytes(b"owned")
			outside.write_bytes(b"outside")

			self.assertEqual(
				build_gf_ai_developer_kit._read_owned_source(owned, owner_root),
				b"owned",
			)
			with self.assertRaisesRegex(ValueError, "escapes its owned root"):
				build_gf_ai_developer_kit._read_owned_source(outside, owner_root)

	def test_plugin_source_traversal_enforces_every_global_budget(self) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-plugin-source-budget-"
		) as temporary:
			source_root = Path(temporary) / "source"
			source_root.mkdir()
			(source_root / "first.txt").write_bytes(b"12")
			(source_root / "second.txt").write_bytes(b"34")
			(source_root / "nested").mkdir()

			with self.assertRaisesRegex(ValueError, "file-count budget"):
				build_gf_ai_developer_kit._bounded_owned_tree_files(
					source_root,
					source_root,
					build_gf_ai_developer_kit.PluginSourceBudget(),
					build_gf_ai_developer_kit.PluginSourceLimits(
						max_directories=8,
						max_files=1,
						max_single_file_bytes=16,
						max_total_bytes=32,
					),
				)
			with self.assertRaisesRegex(ValueError, "total-byte budget"):
				build_gf_ai_developer_kit._bounded_owned_tree_files(
					source_root,
					source_root,
					build_gf_ai_developer_kit.PluginSourceBudget(),
					build_gf_ai_developer_kit.PluginSourceLimits(
						max_directories=8,
						max_files=8,
						max_single_file_bytes=16,
						max_total_bytes=3,
					),
				)
			with self.assertRaisesRegex(ValueError, "directory budget"):
				build_gf_ai_developer_kit._bounded_owned_tree_files(
					source_root,
					source_root,
					build_gf_ai_developer_kit.PluginSourceBudget(),
					build_gf_ai_developer_kit.PluginSourceLimits(
						max_directories=1,
						max_files=8,
						max_single_file_bytes=16,
						max_total_bytes=32,
					),
				)

	def test_plugin_source_traversal_rejects_linked_entries(self) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-plugin-source-link-"
		) as temporary:
			temporary_root = Path(temporary)
			source_root = temporary_root / "source"
			source_root.mkdir()
			outside = temporary_root / "outside.txt"
			outside.write_bytes(b"outside")
			linked = source_root / "linked.txt"
			try:
				os.symlink(outside, linked)
			except OSError as exc:
				self.skipTest(f"Symbolic links are unavailable: {type(exc).__name__}")

			with self.assertRaisesRegex(ValueError, "link or reparse"):
				build_gf_ai_developer_kit._bounded_owned_tree_files(
					source_root,
					source_root,
					build_gf_ai_developer_kit.PluginSourceBudget(),
					build_gf_ai_developer_kit.PluginSourceLimits(),
				)

	def test_plugin_source_actual_reads_share_the_enumeration_budget(
		self,
	) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-plugin-source-growth-"
		) as temporary:
			source_root = Path(temporary) / "source"
			source_root.mkdir()
			(source_root / "first.txt").write_bytes(b"12")
			(source_root / "second.txt").write_bytes(b"34")
			limits = build_gf_ai_developer_kit.PluginSourceLimits(
				max_directories=4,
				max_files=4,
				max_single_file_bytes=8,
				max_total_bytes=10,
			)
			budget = build_gf_ai_developer_kit.PluginSourceBudget()
			files = build_gf_ai_developer_kit._bounded_owned_tree_files(
				source_root,
				source_root,
				budget,
				limits,
			)
			for path in files:
				path.write_bytes(b"123456")
			work_budget = build_gf_ai_developer_kit.PluginWorkBudget()
			work_limits = build_gf_ai_developer_kit.PluginWorkLimits()

			self.assertEqual(
				build_gf_ai_developer_kit._read_budgeted_plugin_source(
					files[0],
					source_root,
					budget,
					limits,
					work_budget,
					work_limits,
					already_consumed=True,
				),
				b"123456",
			)
			with self.assertRaisesRegex(ValueError, "actual-read budget"):
				build_gf_ai_developer_kit._read_budgeted_plugin_source(
					files[1],
					source_root,
					budget,
					limits,
					work_budget,
					work_limits,
					already_consumed=True,
				)

	def test_plugin_source_blocks_case_variant_internal_directories(self) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-plugin-source-blocked-case-"
		) as temporary:
			source_root = Path(temporary) / "source"
			blocked_root = source_root / ".GIT"
			blocked_root.mkdir(parents=True)
			(blocked_root / "credential.txt").write_bytes(b"ordinary")
			visible = source_root / "visible.txt"
			visible.write_bytes(b"ordinary")

			files = build_gf_ai_developer_kit._bounded_owned_tree_files(
				source_root,
				source_root,
				build_gf_ai_developer_kit.PluginSourceBudget(),
				build_gf_ai_developer_kit.PluginSourceLimits(),
			)

			self.assertEqual(files, [visible])

	def test_plugin_work_budget_counts_repeated_logical_reads(self) -> None:
		budget = build_gf_ai_developer_kit.PluginWorkBudget()
		limits = build_gf_ai_developer_kit.PluginWorkLimits(
			max_total_io_bytes=6,
		)
		stream = build_gf_ai_developer_kit._BudgetedBinaryIO(
			io.BytesIO(b"1234"),
			budget,
			limits,
			logical_size=4,
		)

		self.assertEqual(stream.read(), b"1234")
		stream.seek(0)
		with self.assertRaisesRegex(
			ValueError,
			"ai_kit.work.io_budget_exceeded",
		):
			stream.read(3)
		self.assertEqual(budget.io_bytes, 4)

	def test_plugin_archive_paths_use_portable_identities(self) -> None:
		for raw_path in (
			"folder/NUL.txt",
			"folder/name. ",
			"folder/value:stream",
			"folder/.GIT/config",
			"folder/e\u0301.txt",
		):
			with self.subTest(raw_path=raw_path):
				with self.assertRaises(ValueError):
					build_gf_ai_developer_kit._normalized_plugin_archive_path(
						raw_path
					)

	def test_plugin_archive_rejects_invalid_explicit_expected_version(self) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-plugin-version-"
		) as temporary:
			archive_path = Path(temporary) / "kit.zip"
			for invalid_version in (
				"not-semver",
				"01.2.3",
				"1.2.3-alpha..1",
			):
				with self.subTest(invalid_version=invalid_version):
					with mock.patch.object(
						build_gf_ai_developer_kit,
						"_read_owned_bytes",
					) as controlled_read:
						result = (
							build_gf_ai_developer_kit.audit_plugin_archive(
								archive_path,
								invalid_version,
							)
						)

					self.assertFalse(result["ok"])
					self.assertEqual(result["version"], "")
					self.assertEqual(
						result["issues"],
						[
							"ai_kit.archive.expected_version_invalid archive"
						],
					)
					controlled_read.assert_not_called()

	def test_validate_only_cli_rejects_invalid_version_before_archive_read(
		self,
	) -> None:
		with (
			mock.patch.object(build_gf_ai_developer_kit, "configure_stdio"),
			mock.patch.object(
				build_gf_ai_developer_kit,
				"_read_owned_bytes",
			) as controlled_read,
			mock.patch.object(
				build_gf_ai_developer_kit,
				"print_result",
			) as print_result,
		):
			exit_code = build_gf_ai_developer_kit.main([
				"--validate-only",
				"--version",
				"not-semver",
				"--output",
				"build/validation/nonexistent-ai-kit.zip",
				"--json",
			])

		self.assertEqual(exit_code, 1)
		controlled_read.assert_not_called()
		result = print_result.call_args.args[0]
		self.assertEqual(result["version"], "")
		self.assertEqual(
			result["issues"],
			["ai_kit.archive.expected_version_invalid archive"],
		)

	def test_plugin_archive_rejects_portable_duplicates_and_prefixes_before_reads(
		self,
	) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-plugin-portable-conflict-"
		) as temporary:
			for case_name, entry_names, expected_rule in (
				(
					"casefold",
					("Folder/Entry.txt", "folder/entry.TXT"),
					"ai_kit.archive.entry_duplicate ",
				),
				(
					"prefix",
					("folder", "folder/entry.txt"),
					"ai_kit.archive.path_prefix_conflict ",
				),
			):
				with self.subTest(case_name=case_name):
					archive_path = Path(temporary) / f"{case_name}.zip"
					with zipfile.ZipFile(
						archive_path,
						"w",
						compression=zipfile.ZIP_DEFLATED,
					) as archive:
						for entry_name in entry_names:
							info = zipfile.ZipInfo(
								entry_name,
								date_time=(1980, 1, 1, 0, 0, 0),
							)
							info.create_system = 3
							info.compress_type = zipfile.ZIP_DEFLATED
							info.external_attr = 0o644 << 16
							archive.writestr(info, b"ordinary")
					with mock.patch.object(
						build_gf_ai_developer_kit,
						"_read_bounded_plugin_archive_entry",
					) as controlled_read:
						result = (
							build_gf_ai_developer_kit
							.audit_plugin_archive(archive_path)
						)

					self.assertFalse(result["ok"])
					self.assertTrue(
						any(
							issue.startswith(expected_rule)
							for issue in result["issues"]
						),
						result,
					)
					controlled_read.assert_not_called()

	def test_plugin_archive_preflight_blocks_budget_bombs_before_entry_reads(
		self,
	) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-plugin-archive-bomb-"
		) as temporary:
			archive_path = Path(temporary) / "bomb.zip"
			info = zipfile.ZipInfo("payload.txt", date_time=(1980, 1, 1, 0, 0, 0))
			info.create_system = 3
			info.compress_type = zipfile.ZIP_DEFLATED
			info.external_attr = 0o644 << 16
			with zipfile.ZipFile(
				archive_path,
				"w",
				compression=zipfile.ZIP_DEFLATED,
			) as archive:
				archive.writestr(info, b"A" * (1024 * 1024))

			with mock.patch.object(
				build_gf_ai_developer_kit,
				"_read_bounded_plugin_archive_entry",
			) as controlled_read:
				result = build_gf_ai_developer_kit.audit_plugin_archive(
					archive_path
				)

			self.assertFalse(result["ok"])
			self.assertTrue(
				any(
					issue.startswith(
						"ai_kit.archive.compression_ratio_exceeded "
					)
					for issue in result["issues"]
				),
				result,
			)
			controlled_read.assert_not_called()

	def test_plugin_archive_entry_count_is_bounded_before_zipfile_parsing(
		self,
	) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-plugin-entry-budget-"
		) as temporary:
			archive_path = Path(temporary) / "kit.zip"
			version = build_gf_ai_developer_kit.read_plugin_version()
			build_gf_ai_developer_kit.build_plugin_archive(
				archive_path,
				version,
			)
			with (
				mock.patch.object(
					build_gf_ai_developer_kit,
					"PLUGIN_ARCHIVE_ENTRY_LIMIT",
					1,
				),
				mock.patch.object(
					build_gf_ai_developer_kit.zipfile,
					"ZipFile",
				) as zip_file,
			):
				result = build_gf_ai_developer_kit.audit_plugin_archive(
					archive_path,
					version,
				)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"],
				["ai_kit.archive.entry_count_exceeded archive"],
			)
			zip_file.assert_not_called()

	def test_plugin_archive_actual_io_budget_fails_before_zipfile_parsing(
		self,
	) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-plugin-io-budget-"
		) as temporary:
			archive_path = Path(temporary) / "kit.zip"
			version = build_gf_ai_developer_kit.read_plugin_version()
			build_gf_ai_developer_kit.build_plugin_archive(
				archive_path,
				version,
			)
			archive_size = archive_path.stat().st_size
			with mock.patch.object(
				build_gf_ai_developer_kit.zipfile,
				"ZipFile",
			) as zip_file:
				result = build_gf_ai_developer_kit.audit_plugin_archive(
					archive_path,
					version,
					work_limits=(
						build_gf_ai_developer_kit.PluginWorkLimits(
							max_total_io_bytes=archive_size - 1,
						)
					),
				)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"],
				["ai_kit.work.io_budget_exceeded archive"],
			)
			zip_file.assert_not_called()

	def test_plugin_archive_secret_shaped_entry_is_never_echoed(self) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-plugin-entry-redaction-"
		) as temporary:
			archive_path = Path(temporary) / "kit.zip"
			version = build_gf_ai_developer_kit.read_plugin_version()
			build_gf_ai_developer_kit.build_plugin_archive(
				archive_path,
				version,
			)
			secret = "ghp_" + "Ab9" * 16
			info = zipfile.ZipInfo(
				f"zz-api_key={secret}.txt",
				date_time=(1980, 1, 1, 0, 0, 0),
			)
			info.create_system = 3
			info.compress_type = zipfile.ZIP_DEFLATED
			info.external_attr = 0o644 << 16
			with zipfile.ZipFile(
				archive_path,
				"a",
				compression=zipfile.ZIP_DEFLATED,
			) as archive:
				archive.writestr(info, b"ordinary")

			with mock.patch.object(
				build_gf_ai_developer_kit,
				"_read_bounded_plugin_archive_entry",
			) as controlled_read:
				result = build_gf_ai_developer_kit.audit_plugin_archive(
					archive_path,
					version,
				)
			rendered = json.dumps(result, ensure_ascii=False)

			self.assertFalse(result["ok"])
			self.assertTrue(
				any(
					issue.startswith("ai_kit.archive.unexpected_entry ")
					for issue in result["issues"]
				),
				result,
			)
			self.assertFalse(
				secret in rendered,
				"Plugin archive diagnostics disclosed an entry credential.",
			)
			controlled_read.assert_not_called()

	def test_plugin_archive_rejects_comment_before_zip_parsing_without_disclosure(
		self,
	) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-plugin-comment-redaction-"
		) as temporary:
			archive_path = Path(temporary) / "kit.zip"
			version = build_gf_ai_developer_kit.read_plugin_version()
			build_gf_ai_developer_kit.build_plugin_archive(
				archive_path,
				version,
			)
			secret = "ghp_" + "Ab9" * 16
			with zipfile.ZipFile(archive_path, "a") as archive:
				archive.comment = f"api_key={secret}".encode("utf-8")

			with mock.patch.object(
				build_gf_ai_developer_kit.zipfile,
				"ZipFile",
			) as zip_file:
				result = build_gf_ai_developer_kit.audit_plugin_archive(
					archive_path,
					version,
				)

			self.assertFalse(result["ok"])
			self.assertEqual(
				result["issues"],
				["ai_kit.archive.comment_forbidden archive"],
			)
			self.assertNotIn(secret, json.dumps(result, ensure_ascii=False))
			zip_file.assert_not_called()

	def test_plugin_archive_rejects_unreferenced_leading_payload_before_zip_parsing(
		self,
	) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-plugin-leading-payload-"
		) as temporary:
			archive_path = Path(temporary) / "kit.zip"
			version = build_gf_ai_developer_kit.read_plugin_version()
			build_gf_ai_developer_kit.build_plugin_archive(
				archive_path,
				version,
			)
			archive_payload = bytearray(archive_path.read_bytes())
			eocd_offset = archive_payload.rfind(b"PK\x05\x06")
			eocd = struct.unpack_from(
				"<4s4H2LH",
				archive_payload,
				eocd_offset,
			)
			central_size = eocd[5]
			central_offset = eocd[6]
			secret = b"api_key=ghp_" + b"Ab9" * 16
			prefixed = bytearray(secret + archive_payload)
			cursor = central_offset + len(secret)
			central_end = cursor + central_size
			while cursor < central_end:
				self.assertEqual(prefixed[cursor:cursor + 4], b"PK\x01\x02")
				local_offset = struct.unpack_from(
					"<L",
					prefixed,
					cursor + 42,
				)[0]
				struct.pack_into(
					"<L",
					prefixed,
					cursor + 42,
					local_offset + len(secret),
				)
				name_size, extra_size, comment_size = struct.unpack_from(
					"<3H",
					prefixed,
					cursor + 28,
				)
				cursor += 46 + name_size + extra_size + comment_size
			struct.pack_into(
				"<L",
				prefixed,
				eocd_offset + len(secret) + 16,
				central_offset + len(secret),
			)
			archive_path.write_bytes(prefixed)

			with mock.patch.object(
				build_gf_ai_developer_kit.zipfile,
				"ZipFile",
			) as zip_file:
				result = build_gf_ai_developer_kit.audit_plugin_archive(
					archive_path,
					version,
				)

			self.assertEqual(
				result["issues"],
				["ai_kit.archive.layout_invalid archive"],
			)
			self.assertNotIn(
				secret.decode("utf-8"),
				json.dumps(result, ensure_ascii=False),
			)
			zip_file.assert_not_called()

	def test_plugin_archive_rejects_unreferenced_internal_gap_before_zip_parsing(
		self,
	) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-plugin-internal-gap-"
		) as temporary:
			archive_path = Path(temporary) / "kit.zip"
			version = build_gf_ai_developer_kit.read_plugin_version()
			build_gf_ai_developer_kit.build_plugin_archive(
				archive_path,
				version,
			)
			archive_payload = bytearray(archive_path.read_bytes())
			eocd_offset = archive_payload.rfind(b"PK\x05\x06")
			central_offset = struct.unpack_from(
				"<L",
				archive_payload,
				eocd_offset + 16,
			)[0]
			secret = b"api_key=ghp_" + b"Ab9" * 16
			gapped = bytearray(
				archive_payload[:central_offset]
				+ secret
				+ archive_payload[central_offset:]
			)
			struct.pack_into(
				"<L",
				gapped,
				eocd_offset + len(secret) + 16,
				central_offset + len(secret),
			)
			archive_path.write_bytes(gapped)

			with mock.patch.object(
				build_gf_ai_developer_kit.zipfile,
				"ZipFile",
			) as zip_file:
				result = build_gf_ai_developer_kit.audit_plugin_archive(
					archive_path,
					version,
				)

			self.assertEqual(
				result["issues"],
				["ai_kit.archive.layout_invalid archive"],
			)
			self.assertNotIn(
				secret.decode("utf-8"),
				json.dumps(result, ensure_ascii=False),
			)
			zip_file.assert_not_called()

	def test_plugin_builder_rejects_linked_output_parent(self) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-plugin-output-link-"
		) as temporary:
			temporary_root = Path(temporary)
			outside_root = temporary_root / "outside"
			outside_root.mkdir()
			linked_root = temporary_root / "linked"
			try:
				create_directory_link_fixture(outside_root, linked_root)
			except OSError as exc:
				self.skipTest(
					"Directory link fixtures are unavailable: "
					f"{type(exc).__name__}"
				)
			try:
				with self.assertRaisesRegex(
					ValueError,
					"link or reparse",
				):
					build_gf_ai_developer_kit.build_plugin_archive(
						linked_root / "kit.zip",
						build_gf_ai_developer_kit.read_plugin_version(),
					)
			finally:
				if os.path.lexists(linked_root):
					if os.name == "nt":
						linked_root.rmdir()
					else:
						linked_root.unlink()
			self.assertFalse((outside_root / "kit.zip").exists())

	def test_plugin_builder_preserves_archive_when_output_budget_fails(
		self,
	) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-plugin-output-budget-"
		) as temporary:
			output = Path(temporary) / "gf-ai-developer-kit.zip"
			output.write_bytes(b"last-known-good")
			with self.assertRaisesRegex(
				ValueError,
				"ai_kit.work.output_budget_exceeded",
			):
				build_gf_ai_developer_kit.build_plugin_archive(
					output,
					build_gf_ai_developer_kit.read_plugin_version(),
					work_limits=(
						build_gf_ai_developer_kit.PluginWorkLimits(
							max_output_bytes=1,
						)
					),
				)

			self.assertEqual(output.read_bytes(), b"last-known-good")

	def test_plugin_builder_replaces_existing_archive_through_bound_target(
		self,
	) -> None:
		with tempfile.TemporaryDirectory(
			prefix="gf-ai-plugin-bound-publish-"
		) as temporary:
			output = Path(temporary) / "gf-ai-developer-kit.zip"
			output.write_bytes(b"last-known-good")
			version = build_gf_ai_developer_kit.read_plugin_version()

			build_gf_ai_developer_kit.build_plugin_archive(output, version)

			result = build_gf_ai_developer_kit.audit_plugin_archive(
				output,
				version,
			)
			self.assertTrue(result["ok"], result)
			self.assertFalse(
				any(
					path.name.endswith(".tmp")
					for path in output.parent.iterdir()
				)
			)

	def test_plugin_builder_preserves_existing_archive_when_zip_creation_fails(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-ai-atomic-archive-") as temporary:
			output = Path(temporary) / "gf-ai-developer-kit.zip"
			output.write_bytes(b"last-known-good")
			with mock.patch.object(
				build_gf_ai_developer_kit.zipfile,
				"ZipFile",
				side_effect=OSError("simulated zip failure"),
			):
				with self.assertRaisesRegex(OSError, "simulated zip failure"):
					build_gf_ai_developer_kit.build_plugin_archive(
						output,
						build_gf_ai_developer_kit.read_plugin_version(),
					)

			self.assertEqual(output.read_bytes(), b"last-known-good")

	def test_standalone_plugin_runtime_resolves_bundled_data(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-ai-plugin-runtime-") as temporary:
			archive_path = Path(temporary) / "plugin.zip"
			plugin_root = Path(temporary) / "plugin"
			version = build_gf_ai_developer_kit.read_plugin_version()
			build_gf_ai_developer_kit.build_plugin_archive(archive_path, version)
			with zipfile.ZipFile(archive_path, "r") as archive:
				archive.extractall(plugin_root)
			completed = subprocess.run(
				[
					sys.executable,
					str(plugin_root / "runtime/gf_ai_project.py"),
					"context",
					"--project-root",
					str(self.project_root),
				],
				capture_output=True,
				text=True,
				encoding="utf-8",
				timeout=30,
				check=False,
			)

			self.assertEqual(completed.returncode, 0, completed.stderr)
			payload = json.loads(completed.stdout)
			self.assertTrue(payload["ok"], payload)
			self.assertEqual(
				payload["snapshot"]["framework"]["catalog_framework_version"],
				version,
			)
			mcp_request = json.dumps({
				"jsonrpc": "2.0",
				"id": 1,
				"method": "initialize",
				"params": {"protocolVersion": "2099-01-01"},
			}) + "\n"
			mcp_completed = subprocess.run(
				[sys.executable, str(plugin_root / "runtime/gf_ai_mcp_server.py")],
				input=mcp_request,
				capture_output=True,
				text=True,
				encoding="utf-8",
				timeout=30,
				check=False,
			)
			self.assertEqual(mcp_completed.returncode, 0, mcp_completed.stderr)
			mcp_payload = json.loads(mcp_completed.stdout)
			self.assertEqual(mcp_payload["result"]["protocolVersion"], mcp.PROTOCOL_VERSION)

	def test_cli_submission_refuses_non_interactive_input(self) -> None:
		prepared = {"confirmation_sha256": "a" * 64}
		with mock.patch.object(sys, "stdin", io.StringIO()), mock.patch.object(sys, "stdout", io.StringIO()):
			from gf_ai.cli import _confirm_submission

			with self.assertRaises(ValueError):
				_confirm_submission(prepared, "a" * 64)

	def _enable_network_feedback(self) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		contract = json.loads(contract_path.read_text(encoding="utf-8"))
		contract["feedback"]["allow_network_submission"] = True
		contract_path.write_text(json.dumps(contract, ensure_ascii=False), encoding="utf-8")

	def _set_modules(self, modules: list[dict[str, object]]) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		contract = json.loads(contract_path.read_text(encoding="utf-8"))
		contract["architecture"]["modules"] = modules
		contract_path.write_text(json.dumps(contract, ensure_ascii=False), encoding="utf-8")
		for module in modules:
			for root in module["roots"]:
				(self.project_root / str(root).removeprefix("res://")).mkdir(parents=True, exist_ok=True)

	def _set_adapter_boundaries(self, adapters: list[dict[str, object]]) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		contract = json.loads(contract_path.read_text(encoding="utf-8"))
		contract["framework"]["adapter_boundaries"] = adapters
		contract_path.write_text(json.dumps(contract, ensure_ascii=False), encoding="utf-8")

	def _set_owned_resources(self, paths: list[str]) -> None:
		contract_path = self.project_root / ".gf/project_contract.json"
		contract = json.loads(contract_path.read_text(encoding="utf-8"))
		contract["architecture"]["owned_resources"] = paths
		contract_path.write_text(json.dumps(contract, ensure_ascii=False), encoding="utf-8")

	@staticmethod
	def _module(
		module_id: str,
		*,
		allowed: list[str] | None = None,
		forbidden: list[str] | None = None,
	) -> dict[str, object]:
		return {
			"id": module_id,
			"responsibility": f"{module_id} test module",
			"roots": [f"res://features/{module_id}"],
			"allowed_dependencies": list(allowed or []),
			"forbidden_dependencies": list(forbidden or []),
			"ownership": "project",
		}

	@staticmethod
	def _adapter(adapter_id: str) -> dict[str, object]:
		return {
			"id": adapter_id,
			"provider": "test",
			"project_root": f"res://adapters/{adapter_id}",
			"responsibility": f"{adapter_id} test adapter",
		}

	@staticmethod
	def _framework_bug_candidate() -> dict[str, object]:
		return {
			"schema_version": 1,
			"title": "Operation completes twice",
			"summary": "A minimal project observes two terminal callbacks.",
			"expected": "One terminal callback.",
			"actual": "Two terminal callbacks.",
			"reproduction_steps": ["Start and cancel one operation."],
			"evidence": [],
			"environment": {
				"godot_version": "4.5",
				"gf_version": "",
				"platform": "Windows",
				"packages": ["gf.kernel"],
			},
			"suspected_scope": "framework",
			"requested_change": "",
			"impact": "high",
			"workaround": "",
		}


if __name__ == "__main__":
	unittest.main(verbosity=2)
