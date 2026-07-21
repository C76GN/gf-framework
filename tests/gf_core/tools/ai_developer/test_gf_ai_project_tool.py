#!/usr/bin/env python3
"""Behavior and safety tests for the optional project-side GF AI kit."""

from __future__ import annotations

import io
import json
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[4]
ADDON_ROOT = ROOT / "addons/gf/tools/ai_developer"
TOOLS_ROOT = ROOT / "tools"
FIXTURE_PATH = Path(__file__).with_name("fixtures") / "evaluation_cases.json"
sys.path.insert(0, str(ADDON_ROOT))
sys.path.insert(0, str(TOOLS_ROOT))

from gf_ai import adapters, catalog, dependencies, feedback, mcp, snapshot  # noqa: E402
from gf_ai.constants import (  # noqa: E402
	ARTIFACT_POLICY_PATH,
	DEFAULT_CONTRACT_PATH,
	PROJECT_ARTIFACT_PATHS,
	SCHEMA_ROOT,
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
		(self.project_root / "addons/gf/plugin.cfg").write_text(
			f'[plugin]\nname="GF"\nversion="{framework_version}"\n',
			encoding="utf-8",
		)
		(self.project_root / ".gf").mkdir()
		(self.project_root / ".gf/packages.lock.json").write_text(
			json.dumps({
				"schema_version": 1,
				"framework_version": framework_version,
				"installed": {"gf.kernel": {"version": framework_version}},
			}),
			encoding="utf-8",
		)
		result = initialize_contract(self.project_root)
		self.assertTrue(result["ok"], result)

	def tearDown(self) -> None:
		self._temporary.cleanup()

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

	def test_strict_json_rejects_duplicate_keys_and_non_finite_numbers(self) -> None:
		path = self.project_root / "strict.json"
		path.write_text('{"value": 1, "value": 2}', encoding="utf-8")
		with self.assertRaisesRegex(ValueError, "Duplicate JSON object key"):
			read_json_object(path)
		path.write_text('{"value": NaN}', encoding="utf-8")
		with self.assertRaisesRegex(ValueError, "Non-finite JSON number"):
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
		self.assertTrue(report["project"]["source_scan_truncated"])
		self.assertIn("GFArchitecture", report["project"]["gf_api_usage"])
		self.assertNotIn("GFSettingsUtility", report["project"]["gf_api_usage"])
		self.assertNotIn("GFStorageUtility", report["project"]["gf_api_usage"])

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
			dependencies.ModuleOwnershipMatcher([unsafe_module]).owner_of("res://Addons/GF/unsafe.gd"),
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

	def test_feedback_is_redacted_bound_to_contract_and_human_gated(self) -> None:
		self._enable_network_feedback()
		candidate = self._framework_bug_candidate()
		candidate["actual"] += f" at {self.project_root} token=secret123456"
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
		self.assertNotIn("gf_issue_submit", names)
		self.assertTrue(all(item["annotations"]["destructiveHint"] is False for item in mcp.list_tools()))

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
		for case in fixture["feedback_cases"]:
			with self.subTest(case=case["id"]):
				result = feedback.analyze_candidate(self.project_root, case["candidate"])
				self.assertEqual(result["classification"], case["classification"])
				self.assertEqual(result["eligible_for_official_issue"], case["eligible"])
		for case in fixture["capability_queries"]:
			with self.subTest(query=case["query"]):
				result = catalog.capability_search(case["query"], 10, self.project_root)
				self.assertIn(case["expected_id"], [item["id"] for item in result["results"]])
		for case in fixture["api_queries"]:
			with self.subTest(query=case["query"]):
				result = catalog.api_search(case["query"], 10, self.project_root)
				self.assertIn(case["expected_class"], [item["class_name"] for item in result["results"]])
		for case in fixture["module_queries"]:
			with self.subTest(module=case["module"]):
				result = catalog.api_module(case["module"], 200, self.project_root)
				self.assertIn(case["expected_class"], [item["class_name"] for item in result["classes"]])
		for case in fixture["package_queries"]:
			with self.subTest(package=case["package_id"]):
				result = catalog.package_by_id(case["package_id"], 200, self.project_root)
				self.assertIn(case["expected_class"], result["classes"])

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
