#!/usr/bin/env python3
"""Exact lexical contracts for shared GF package JSON schemas."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[4]
TOOLS_ROOT = ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
	sys.path.insert(0, str(TOOLS_ROOT))

import gf_maintenance


class _JsonInteger(int):
	pass


class _JsonFloat(float):
	pass


def _load_json_with_exact_number_kinds(path: Path) -> Any:
	return json.loads(
		path.read_text(encoding="utf-8"),
		parse_int=_JsonInteger,
		parse_float=_JsonFloat,
	)


def _is_exact_json_integer(value: object, expected: int) -> bool:
	return type(value) is _JsonInteger and int(value) == expected


class PackageSchemaNumberContractTests(unittest.TestCase):
	def test_cache_schema_versions_are_exact_json_integers(self) -> None:
		schema = _load_json_with_exact_number_kinds(
			ROOT / "addons/gf/kernel/package/gf_package_cache_schema.json"
		)
		self.assertTrue(_is_exact_json_integer(schema.get("schema_version"), 1))
		self.assertTrue(_is_exact_json_integer(schema.get("layout_version"), 1))

	def test_transaction_schema_versions_are_exact_json_integers(self) -> None:
		schema = _load_json_with_exact_number_kinds(
			ROOT / "addons/gf/kernel/package/gf_package_transaction_schema.json"
		)
		self.assertTrue(_is_exact_json_integer(schema.get("schema_version"), 1))
		self.assertTrue(_is_exact_json_integer(schema.get("report_schema_version"), 1))

	def test_exact_integer_contract_rejects_coercible_json_values(self) -> None:
		for raw_value in ("1.0", "1.5", "1e0", "true", '"1"', "null"):
			with self.subTest(raw_value=raw_value):
				payload = json.loads(
					'{"version":%s}' % raw_value,
					parse_int=_JsonInteger,
					parse_float=_JsonFloat,
				)
				self.assertFalse(_is_exact_json_integer(payload["version"], 1))
		self.assertFalse(_is_exact_json_integer(None, 1))


class PackageInternalSourceContractTests(unittest.TestCase):
	def setUp(self) -> None:
		self.sources = {
			path: (ROOT / path).read_text(encoding="utf-8")
			for path in gf_maintenance.PACKAGE_INTERNAL_SOURCE_CONTRACT_PATHS
		}

	def _issue_kinds(self, sources: dict[str, str]) -> set[str]:
		return {
			str(issue.get("kind", ""))
			for issue in gf_maintenance.audit_package_internal_source_contracts(sources)
		}

	def test_repository_sources_satisfy_structural_package_contracts(self) -> None:
		self.assertEqual(gf_maintenance.audit_package_internal_source_contracts(self.sources), [])

	def test_comment_cannot_forge_hidden_entry_scanning(self) -> None:
		engine_path = "addons/gf/kernel/package/gf_package_transaction_engine.gd"
		mutated = dict(self.sources)
		mutated[engine_path] = mutated[engine_path].replace(
			"\tdirectory.include_hidden = true",
			"\tdirectory.include_hidden = false\n\t# directory.include_hidden = true",
			1,
		)
		self.assertIn("package_hidden_scan_contract", self._issue_kinds(mutated))

	def test_dead_string_cannot_forge_transaction_execution(self) -> None:
		backend_path = "addons/gf/kernel/package/gf_package_manager_backend.gd"
		mutated = dict(self.sources)
		mutated[backend_path] = mutated[backend_path].replace(
			"\treturn _GF_PACKAGE_TRANSACTION_ENGINE.execute(request, options)",
			(
				'\tvar _dead_evidence: String = "return '
				'_GF_PACKAGE_TRANSACTION_ENGINE.execute(request, options)"\n'
				"\treturn {}"
			),
			1,
		)
		self.assertIn("package_transaction_execute_owner", self._issue_kinds(mutated))

	def test_renamed_second_transaction_adapter_is_rejected(self) -> None:
		backend_path = "addons/gf/kernel/package/gf_package_manager_backend.gd"
		mutated = dict(self.sources)
		mutated[backend_path] += (
			"\n\nstatic func _renamed_transaction_adapter(request: Dictionary, options: Dictionary) -> Dictionary:\n"
			"\treturn _GF_PACKAGE_TRANSACTION_ENGINE.execute(request, options)\n"
		)
		self.assertIn("package_transaction_execute_owner", self._issue_kinds(mutated))

	def test_comment_cannot_hide_wrong_delegation_preload(self) -> None:
		backend_path = "addons/gf/kernel/package/gf_package_manager_backend.gd"
		correct = (
			'const _GF_PACKAGE_CACHE_POLICY = preload('
			'"res://addons/gf/kernel/package/gf_package_cache_policy.gd")'
		)
		mutated = dict(self.sources)
		mutated[backend_path] = mutated[backend_path].replace(
			correct,
			"# %s\n%s" % (
				correct,
				'const _GF_PACKAGE_CACHE_POLICY = preload("res://addons/gf/kernel/package/wrong.gd")',
			),
			1,
		)
		self.assertIn("package_internal_preload_contract", self._issue_kinds(mutated))


if __name__ == "__main__":
	unittest.main()
