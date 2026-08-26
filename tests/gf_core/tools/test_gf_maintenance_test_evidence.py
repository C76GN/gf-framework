#!/usr/bin/env python3
"""Focused tests for repository-owned Python test execution evidence."""

from __future__ import annotations

import ast
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
TOOLS_ROOT = ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
	sys.path.insert(0, str(TOOLS_ROOT))

import gf_maintenance


def _repository_python_test_modules() -> list[Path]:
	return sorted((ROOT / "tests" / "gf_core").rglob("test_*.py"))


def _check_owners(module_path: Path) -> list[str]:
	relative_path = module_path.relative_to(ROOT).as_posix()
	return sorted(
		check_name
		for check_name, command in gf_maintenance.CHECK_DEFINITIONS.items()
		if relative_path in [str(argument).replace("\\", "/") for argument in command]
	)


class PythonTestEvidenceTests(unittest.TestCase):
	def test_every_python_test_module_has_exactly_one_named_check_owner(self) -> None:
		governed_checks = {
			check_name
			for suite_checks in gf_maintenance.CHECK_SUITES.values()
			for check_name in suite_checks
		}
		ownership = {
			module.relative_to(ROOT).as_posix(): _check_owners(module)
			for module in _repository_python_test_modules()
		}
		invalid = {
			module: owners
			for module, owners in ownership.items()
			if len(owners) != 1
		}
		self.assertEqual(
			invalid,
			{},
			"Every Python test module must have exactly one named check owner.",
		)
		ungoverned = {
			module: owners[0]
			for module, owners in ownership.items()
			if len(owners) == 1 and owners[0] not in governed_checks
		}
		self.assertEqual(
			ungoverned,
			{},
			"Every Python test owner must be reachable from a governed check suite.",
		)

	def test_every_owned_python_test_module_declares_nonempty_test_evidence(self) -> None:
		for module in _repository_python_test_modules():
			with self.subTest(module=module.relative_to(ROOT).as_posix()):
				tree = ast.parse(module.read_text(encoding="utf-8"), filename=str(module))
				test_methods = [
					node
					for node in ast.walk(tree)
					if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
					and node.name.startswith("test_")
				]
				self.assertTrue(
					test_methods,
					"Owned Python test modules must declare at least one test method.",
				)

	def test_evidence_checks_are_owned_by_their_required_suites(self) -> None:
		for suite_name, checks in {
			"light-boundary": gf_maintenance.LIGHT_BOUNDARY_CHECKS,
			"quick": gf_maintenance.QUICK_CHECKS,
			"framework-static": gf_maintenance.FRAMEWORK_STATIC_CHECKS,
			"framework": gf_maintenance.FRAMEWORK_CHECKS,
			"full": gf_maintenance.FULL_CHECKS,
			"release": gf_maintenance.RELEASE_CHECKS,
		}.items():
			with self.subTest(suite=suite_name):
				self.assertIn("maintenance_test_evidence_tests", checks)

	def test_static_module_descriptor_evidence_is_framework_governed(self) -> None:
		for suite_name, checks in {
			"light-boundary": gf_maintenance.LIGHT_BOUNDARY_CHECKS,
			"quick": gf_maintenance.QUICK_CHECKS,
			"framework-static": gf_maintenance.FRAMEWORK_STATIC_CHECKS,
			"framework": gf_maintenance.FRAMEWORK_CHECKS,
			"full": gf_maintenance.FULL_CHECKS,
			"release": gf_maintenance.RELEASE_CHECKS,
		}.items():
			with self.subTest(suite=suite_name):
				self.assertIn("module_descriptor_tests", checks)


if __name__ == "__main__":
	unittest.main()
