#!/usr/bin/env python3
"""Public API queries and opt-in private maintenance documentation views."""

from __future__ import annotations

import contextlib
import io
import json
import sys
import unittest
from dataclasses import replace
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))

import gf_maintenance
import gf_maintenance_rendering
import gf_mcp_server
from gdscript_api_parser import parse_gdscript_source


PUBLIC_SOURCE = """## Public fixture.
## @api public
class_name GFPrivateDocsFixture
extends RefCounted

## Runs the public operation.
## @api public
func run() -> void:
	pass

## Extension hook.
## @api protected
func _hook() -> void:
	pass

## Coordinates framework work.
## @api framework_internal
func coordinate() -> void:
	pass

## Validates layer work.
## @api layer_internal
func validate() -> void:
	pass

func undocumented() -> void:
	pass

## Unknown visibility must not enter either view.
## @api mystery
func unknown() -> void:
	pass

## Notify local cleanup observers.
## @api private
signal _released()

## Cleanup state phases.
## @api private
enum _Phase { IDLE, RELEASED }

## Internal cleanup limit.
## @api private
const _LIMIT: int = 1

## Retained session state.
## @api private
var _state: Dictionary = {}

PRIVATE_DOCS
func _release() -> void:
	pass

## Session ownership state.
## @api private
class _Lease:
	## Release the lease once.
	## @api private
	func _close() -> void:
		pass

## Public value view.
## @api public
class PublicView:
	## Read the value.
	## @api public
	func read() -> void:
		pass
"""


def fixture_scripts(private_docs: bool = True):
	private_block = "## Release retained session state.\n## @api private" if private_docs else "# Release retained session state."
	return [
		parse_gdscript_source(
			PUBLIC_SOURCE.replace("PRIVATE_DOCS", private_block),
			"addons/gf/kernel/base/gf_private_docs_fixture.gd",
			module="kernel",
		),
		parse_gdscript_source(
			"## Internal owner.\n## @api framework_internal\nclass_name GFQueryInternal\n"
			"extends RefCounted\n## Only available within this internal owner.\n## @api public\n"
			"func exposed_looking() -> void:\n\tpass\n",
			"addons/gf/kernel/base/gf_query_internal.gd",
			module="kernel",
		),
		parse_gdscript_source(
			"extends RefCounted\n## Clear helper state.\n## @api private\n"
			"func _cleanup() -> void:\n\tpass\n",
			"addons/gf/kernel/base/helper.gd",
			module="kernel",
		),
		parse_gdscript_source(
			"## GF entry point.\n## @api public\n## @api_owner autoload Gf\nextends Node\n"
			"## Boot the framework.\n## @api public\nfunc boot() -> void:\n\tpass\n",
			"addons/gf/kernel/core/gf.gd",
			module="kernel",
		),
	]


def without_locations(value):
	if isinstance(value, dict):
		return {key: without_locations(child) for key, child in value.items() if key != "line"}
	if isinstance(value, list):
		return [without_locations(child) for child in value]
	return value


def invalid_owner_fixtures():
	scripts = fixture_scripts()
	for name, fields in [
		("unknown_kind", {"api_owner_kind": "singleton"}),
		("wrong_name", {"api_owner_name": "Other"}),
		("wrong_path", {"path": "addons/gf/kernel/core/other_autoload.gd"}),
		("wrong_base", {"extends": "RefCounted"}),
		("missing_declaration", {"api_owner_kind": "", "api_owner_name": ""}),
	]:
		yield name, [*scripts[:-1], replace(scripts[-1], **fields)]
	yield "missing_owner", scripts[:-1]


class PrivateDocsQueryTests(unittest.TestCase):
	def setUp(self) -> None:
		self.source_patch = mock.patch.object(gf_maintenance, "load_api_scripts", return_value=fixture_scripts())
		self.source_patch.start()
		self.addCleanup(self.source_patch.stop)

	def test_default_public_queries_do_not_leak_internal_owners_or_private_members(self) -> None:
		self.assertFalse(gf_maintenance.api_class("GFQueryInternal")["found"])
		self.assertEqual(gf_maintenance.api_search("exposed_looking")["count"], 0)
		self.assertEqual(gf_maintenance.api_search("_release")["count"], 0)
		data = gf_maintenance.api_class("GFPrivateDocsFixture")
		self.assertEqual(data["scope"], "public")
		self.assertEqual({item["name"] for item in data["methods"]}, {"run", "_hook"})
		self.assertTrue(all(item["visibility"] in {"public", "protected"} for item in data["methods"]))

	def test_adding_private_documentation_does_not_change_public_query_semantics(self) -> None:
		def query_outputs():
			return [
				gf_maintenance.api_index(),
				gf_maintenance.api_search("kernel", limit=80),
				gf_maintenance.api_class("GFPrivateDocsFixture"),
				gf_maintenance.api_module("kernel", include_members=True),
			]
		with mock.patch.object(gf_maintenance, "load_api_scripts", return_value=fixture_scripts(False)):
			before = without_locations(query_outputs())
		self.assertEqual(before, without_locations(query_outputs()))

	def test_maintenance_view_exposes_documented_private_state_but_not_unknown_visibility(self) -> None:
		data = gf_maintenance.api_class("GFPrivateDocsFixture", scope="maintenance")
		methods = {item["name"]: item for item in data["methods"]}
		self.assertEqual(methods["_release"]["visibility"], "private")
		self.assertIn("Release retained session state.", methods["_release"]["docs"])
		self.assertNotIn("undocumented", methods)
		self.assertNotIn("unknown", methods)
		for group, name in [("signals", "_released"), ("enums", "_Phase"), ("constants", "_LIMIT"), ("variables", "_state")]:
			with self.subTest(group=group):
				self.assertEqual(data[group][0]["name"], name)
				self.assertEqual(data[group][0]["visibility"], "private")
				self.assertEqual(gf_maintenance.api_class("GFPrivateDocsFixture")[group], [])
		result = gf_maintenance.api_search("_release", scope="maintenance")["results"][0]
		self.assertEqual(result["member_matches"][0]["visibility"], "private")

	def test_maintenance_queries_support_classless_paths_inner_classes_and_autoload(self) -> None:
		helper = gf_maintenance.api_class("res://addons/gf/kernel/base/helper.gd", scope="maintenance")
		self.assertTrue(helper["found"])
		self.assertEqual(helper["owner_kind"], "script")
		self.assertEqual(helper["reference_page"], "")
		self.assertEqual(helper["visibility"], "unclassified")
		inner = gf_maintenance.api_class("GFPrivateDocsFixture._Lease", scope="maintenance")
		self.assertTrue(inner["found"])
		self.assertEqual(inner["owner_kind"], "inner_class")
		self.assertEqual(inner["methods"][0]["visibility"], "private")
		self.assertFalse(gf_maintenance.api_class("GFPrivateDocsFixture._Lease")["found"])
		self.assertEqual(gf_maintenance.api_class("Gf")["owner_kind"], "autoload")
		module = gf_maintenance.api_module("kernel", include_members=True, scope="maintenance")
		self.assertIn("addons/gf/kernel/base/helper.gd", {item["path"] for item in module["scripts"]})

	def test_index_counts_public_contracts_separately_from_declared_visibility(self) -> None:
		public = gf_maintenance.api_index()
		maintenance = gf_maintenance.api_index(scope="maintenance")
		self.assertEqual(public["public_method_count"], 4)
		self.assertEqual(maintenance["public_method_count"], 4)
		self.assertEqual(maintenance["method_counts_by_visibility"], {
			"public": 4, "protected": 1, "framework_internal": 1, "layer_internal": 1, "private": 3,
		})
		self.assertEqual(maintenance["method_count"], 10)
		self.assertEqual(maintenance["inner_class_count"], 2)
		self.assertEqual(maintenance["file_count"], 4)

	def test_reference_links_follow_public_owner_pages_and_internal_classes_have_none(self) -> None:
		inner = gf_maintenance.api_class("GFPrivateDocsFixture.PublicView", scope="maintenance")
		self.assertEqual(inner["reference_page"], "docs/zh/reference/api/classes/GFPrivateDocsFixture.md#gfprivatedocsfixturepublicview")
		self.assertEqual(gf_maintenance.api_class("Gf")["reference_page"], "docs/zh/reference/api/autoloads/Gf.md")
		internal = gf_maintenance.api_class("GFQueryInternal", scope="maintenance")
		self.assertEqual(internal["reference_page"], "")

	def test_text_view_shows_private_maintenance_docs_and_classless_module_entries(self) -> None:
		text = gf_maintenance_rendering.render_api_class_text(
			gf_maintenance.api_class("GFPrivateDocsFixture", scope="maintenance")
		)
		self.assertIn("scope: maintenance", text)
		self.assertIn("[private] func _release()", text)
		self.assertIn("Release retained session state.", text)
		module = gf_maintenance_rendering.render_api_module_text(
			gf_maintenance.api_module("kernel", include_members=True, scope="maintenance")
		)
		self.assertIn("addons/gf/kernel/base/helper.gd [unclassified]", module)
		self.assertIn("[private] func _cleanup()", module)

	def test_module_limit_bounds_classes_and_classless_containers_together(self) -> None:
		data = gf_maintenance.api_module("kernel", limit=1, scope="maintenance")
		self.assertEqual(data["returned_owner_count"], 1)
		self.assertEqual(len(data["classes"]) + len(data["scripts"]), 1)
		self.assertTrue(data["truncated"])

	def test_python_queries_reject_unknown_scope(self) -> None:
		for function, args in [
			(gf_maintenance.api_index, ()), (gf_maintenance.api_search, ("x",)),
			(gf_maintenance.api_class, ("x",)), (gf_maintenance.api_module, ("kernel",)),
		]:
			with self.subTest(function=function.__name__), self.assertRaises(ValueError):
				function(*args, scope="all")

	def test_all_query_scopes_reject_invalid_owner_identity_before_search_or_lookup(self) -> None:
		for case, scripts in invalid_owner_fixtures():
			with mock.patch.object(gf_maintenance, "load_api_scripts", return_value=scripts):
				for scope in ("public", "maintenance"):
					for function, args in [
						(gf_maintenance.api_index, ()),
						(gf_maintenance.api_search, ("",)),
						(gf_maintenance.api_class, ("DoesNotExist",)),
						(gf_maintenance.api_module, ("DoesNotExist",)),
					]:
						with self.subTest(case=case, scope=scope, function=function.__name__), self.assertRaises(ValueError):
							function(*args, scope=scope)

	def test_cli_and_mcp_maintenance_queries_fail_closed_for_invalid_owners(self) -> None:
		for case, scripts in invalid_owner_fixtures():
			with mock.patch.object(gf_maintenance, "load_api_scripts", return_value=scripts):
				for command in [
					["api-index"], ["api-search", "_release"],
					["api-class", "DoesNotExist"], ["api-module", "DoesNotExist"],
				]:
					with self.subTest(case=case, command=command), mock.patch.object(
						sys, "argv", ["gf_maintenance.py", *command, "--scope", "maintenance", "--json"],
					), mock.patch.object(gf_maintenance, "configure_stdio"), contextlib.redirect_stdout(io.StringIO()) as output:
						with self.assertRaises(ValueError):
							gf_maintenance.main()
						self.assertEqual(output.getvalue(), "")
				for name, arguments in [
					("gf_api_search", {"query": "_release"}),
					("gf_api_class", {"class_name": "DoesNotExist"}),
					("gf_api_module", {"module": "DoesNotExist"}),
				]:
					with self.subTest(case=case, name=name):
						response = gf_mcp_server.call_tool(1, {"name": name, "arguments": {**arguments, "scope": "maintenance"}})
						self.assertTrue(response["result"]["isError"])
						self.assertEqual(set(response["result"]["structuredContent"]), {"error"})

	def test_cli_accepts_and_validates_scope_for_all_query_commands(self) -> None:
		for command in [
			["api-index"], ["api-search", "_release"],
			["api-class", "GFPrivateDocsFixture"], ["api-module", "kernel"],
		]:
			with self.subTest(command=command):
				with mock.patch.object(sys, "argv", ["gf_maintenance.py", *command, "--scope", "maintenance", "--json"]), mock.patch.object(gf_maintenance, "configure_stdio"), contextlib.redirect_stdout(io.StringIO()) as output:
					self.assertEqual(gf_maintenance.main(), 0)
				self.assertEqual(json.loads(output.getvalue())["scope"], "maintenance")
				with mock.patch.object(sys, "argv", ["gf_maintenance.py", *command, "--scope", "all"]), mock.patch.object(gf_maintenance, "configure_stdio"), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as raised:
					gf_maintenance.main()
				self.assertEqual(raised.exception.code, 2)

	def test_mcp_tools_forward_scope_validate_enum_and_resources_remain_public(self) -> None:
		for name, arguments in [
			("gf_api_search", {"query": "_release"}),
			("gf_api_class", {"class_name": "GFPrivateDocsFixture"}),
			("gf_api_module", {"module": "kernel"}),
		]:
			with self.subTest(name=name):
				result = gf_mcp_server.call_tool(1, {"name": name, "arguments": {**arguments, "scope": "maintenance"}})
				self.assertNotIn("error", result)
				self.assertEqual(json.loads(result["result"]["content"][0]["text"])["scope"], "maintenance")
				rejected = gf_mcp_server.call_tool(2, {"name": name, "arguments": {**arguments, "scope": "all"}})
				self.assertEqual(rejected["error"]["code"], -32602)
				default = gf_mcp_server.call_tool(3, {"name": name, "arguments": arguments})
				self.assertEqual(default["result"]["structuredContent"]["scope"], "public")
		resource = gf_mcp_server.read_resource(3, {"uri": "gf://api/classes/GFPrivateDocsFixture"})
		data = json.loads(resource["result"]["contents"][0]["text"])
		self.assertEqual(data["scope"], "public")
		self.assertNotIn("_release", {item["name"] for item in data["methods"]})


if __name__ == "__main__":
	unittest.main()
