#!/usr/bin/env python3
"""Focused tests for the tracked-source CodeQL suppression policy."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
TOOLS_ROOT = ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
	sys.path.insert(0, str(TOOLS_ROOT))

import gf_codeql_suppression_policy as policy  # noqa: E402
import gf_credential_gate as credential_gate  # noqa: E402
import gf_maintenance  # noqa: E402


class CodeqlSuppressionPolicyTests(unittest.TestCase):
	def test_clean_python_has_zero_suppressions(self) -> None:
		issues, suppression_count = policy.audit_python_source(
			"tools/fixture.py",
			"value = 1\n",
		)

		self.assertEqual(issues, [])
		self.assertEqual(suppression_count, 0)

	def test_untracked_python_is_outside_the_supplied_inventory(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			root = Path(temp_dir)
			tracked = root / "tracked.py"
			tracked.write_text("value = 1\n", encoding="utf-8")
			untracked = root / "untracked.py"
			untracked.write_text("# codeql\nvalue = 2\n", encoding="utf-8")
			read_paths: list[Path] = []

			def read_text(path: Path) -> str:
				read_paths.append(path)
				return path.read_text(encoding="utf-8")

			result = policy.audit_tracked_sources(
				root,
				["tracked.py"],
				read_text,
			)

			self.assertTrue(result["ok"])
			self.assertEqual(read_paths, [tracked])
			self.assertNotIn(untracked, read_paths)

	def test_tracked_python_read_failure_is_fail_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			root = Path(temp_dir)
			tracked = root / "tracked.py"
			tracked.write_text("value = 1\n", encoding="utf-8")

			def fail_read(_path: Path) -> str:
				raise OSError("synthetic read failure")

			result = policy.audit_tracked_sources(
				root,
				["tracked.py"],
				fail_read,
			)

			self.assertFalse(result["ok"])
			self.assertEqual(
				self._issue_kinds(result["issues"]),
				{"codeql_suppression.python_source_unreadable"},
			)

	def test_missing_tracked_python_is_fail_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			root = Path(temp_dir)

			result = policy.audit_tracked_sources(
				root,
				["missing.py"],
				lambda path: path.read_text(encoding="utf-8"),
			)

			self.assertFalse(result["ok"])
			self.assertEqual(
				self._issue_kinds(result["issues"]),
				{"codeql_suppression.python_source_not_regular"},
			)

	def test_noncanonical_tracked_path_is_fail_closed_without_echoing_value(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			root = Path(temp_dir)
			tracked = root / "safe/path.py"
			tracked.parent.mkdir(parents=True)
			tracked.write_text("value = 1\n", encoding="utf-8")
			result = policy.audit_tracked_sources(
				root,
				["safe/path.py", r"safe\path.py"],
				lambda path: path.read_text(encoding="utf-8"),
			)

			self.assertFalse(result["ok"])
			self.assertEqual(
				self._issue_kinds(result["issues"]),
				{"codeql_suppression.tracked_path_noncanonical"},
			)
			self.assertEqual(result["issues"][0]["path"], "git-index")

	def test_all_noncanonical_and_control_tracked_paths_fail_before_reads(self) -> None:
		fixtures = {
			"absolute": "/safe/path.py",
			"drive": "C:/safe/path.py",
			"backslash": r"safe\path.py",
			"empty_segment": "safe//path.py",
			"dot_segment": "safe/./path.py",
			"parent_segment": "safe/../path.py",
			"non_nfc": "safe/cafe\u0301.py",
			"newline": "safe/line\nbreak.py",
			"format_control": "safe/line\u200bbreak.py",
		}
		for name, tracked_path in fixtures.items():
			with self.subTest(name=name):
				read_paths: list[Path] = []
				result = policy.audit_tracked_sources(
					Path("unused"),
					[tracked_path],
					lambda path: read_paths.append(path) or "",
				)

				self.assertFalse(result["ok"])
				self.assertEqual(read_paths, [])
				self.assertEqual(result["issues"][0]["path"], "git-index")
				self.assertIn(
					str(result["issues"][0]["kind"]),
					{
						"codeql_suppression.tracked_path_control_character",
						"codeql_suppression.tracked_path_noncanonical",
					},
				)

	def test_portable_tracked_path_collisions_fail_before_reads(self) -> None:
		read_paths: list[Path] = []
		result = policy.audit_tracked_sources(
			Path("unused"),
			["safe/path.py", "SAFE/PATH.py"],
			lambda path: read_paths.append(path) or "",
		)

		self.assertFalse(result["ok"])
		self.assertEqual(read_paths, [])
		self.assertEqual(
			self._issue_kinds(result["issues"]),
			{"codeql_suppression.tracked_path_collision"},
		)
		self.assertEqual(result["issues"][0]["path"], "git-index")

	def test_directive_looking_strings_are_not_comments(self) -> None:
		source = (
			'fixture = """# codeql[*]\n'
			'# lgtm[py/clear-text-storage-sensitive-data]\n'
			'# codeql[py/one,py/two]"""\n'
		)

		issues, suppression_count = policy.audit_python_source("tools/fixture.py", source)

		self.assertEqual(issues, [])
		self.assertEqual(suppression_count, 0)

	def test_every_python_suppression_form_is_rejected(self) -> None:
		fixtures = {
			"exact": "# codeql[py/clear-text-storage-sensitive-data]\nsink()\n",
			"bare": "# codeql\nsink()\n",
			"legacy": "# lgtm[py/clear-text-storage-sensitive-data]\nsink()\n",
			"wildcard": "# codeql[py/*]\nsink()\n",
			"multiple": "# codeql[py/one,py/two]\nsink()\n",
			"invalid": "# codeql[not an id]\nsink()\n",
			"inline": (
				"value = sink()  # codeql[py/clear-text-storage-sensitive-data]\n"
			),
			"nested_marker": "## codeql[py/clear-text-storage-sensitive-data]\nsink()\n",
			"uppercase": "# CODEQL[py/clear-text-storage-sensitive-data]\nsink()\n",
		}
		expected_kinds = {
			"exact": "codeql_suppression.python_directive_forbidden",
			"bare": "codeql_suppression.python_directive_forbidden",
			"legacy": "codeql_suppression.legacy_lgtm_directive",
			"wildcard": "codeql_suppression.python_directive_forbidden",
			"multiple": "codeql_suppression.python_directive_forbidden",
			"invalid": "codeql_suppression.python_directive_forbidden",
			"inline": "codeql_suppression.python_directive_forbidden",
			"nested_marker": "codeql_suppression.python_directive_forbidden",
			"uppercase": "codeql_suppression.python_directive_forbidden",
		}
		for name, source in fixtures.items():
			with self.subTest(name=name):
				issues, suppression_count = policy.audit_python_source(
					"tests/gf_core/tools/test_fixture.py",
					source,
				)
				self.assertIn(expected_kinds[name], self._issue_kinds(issues))
				self.assertEqual(suppression_count, 1)

	def test_multiple_python_suppressions_are_all_counted_and_rejected(self) -> None:
		issues, suppression_count = policy.audit_python_source(
			"tests/gf_core/tools/test_fixture.py",
			"# codeql[py/clear-text-storage-sensitive-data]\n"
			"sink()\n"
			"# lgtm[py/clear-text-storage-sensitive-data]\n"
			"sink()\n",
		)

		self.assertEqual(suppression_count, 2)
		self.assertEqual(
			self._issue_kinds(issues),
			{
				"codeql_suppression.legacy_lgtm_directive",
				"codeql_suppression.python_directive_forbidden",
			},
		)

	def test_tracked_python_suppression_is_fail_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			root = Path(temp_dir)
			tracked = root / "tracked.py"
			tracked.write_text(
				"# codeql[py/clear-text-storage-sensitive-data]\n"
				"sink()\n",
				encoding="utf-8",
			)

			result = policy.audit_tracked_sources(
				root,
				["tracked.py"],
				lambda path: path.read_text(encoding="utf-8"),
			)

			self.assertFalse(result["ok"])
			self.assertEqual(result["suppression_count"], 1)
			self.assertEqual(
				self._issue_kinds(result["issues"]),
				{"codeql_suppression.python_directive_forbidden"},
			)

	def test_codeql_config_rejects_broad_test_and_query_exclusions(self) -> None:
		source = """
name: CodeQL
disable-default-queries: false
paths-ignore:
  - "tests/**"
query-filters:
  - exclude:
      id: py/clear-text-storage-sensitive-data
"""

		issues = policy.audit_codeql_config(".github/codeql/codeql-config.yml", source)

		self.assertEqual(
			self._issue_kinds(issues),
			{
				"codeql_suppression.default_queries_disabled",
				"codeql_suppression.security_query_excluded",
				"codeql_suppression.tests_path_ignored",
			},
		)

	def test_codeql_config_rejects_flow_quoted_and_aliased_escape_hatches(
		self,
	) -> None:
		fixtures = {
			"quoted_disable": (
				'"disable-default-queries": true\n',
				"codeql_suppression.default_queries_disabled",
			),
			"flow_disable": (
				"{disable-default-queries: true}\n",
				"codeql_suppression.default_queries_disabled",
			),
			"flow_paths": (
				'paths-ignore: ["./tests/**"]\n',
				"codeql_suppression.tests_path_ignored",
			),
			"aliased_paths": (
				'shared: &test_paths ["tests/**"]\n'
				"paths-ignore: *test_paths\n",
				"codeql_suppression.tests_path_ignored",
			),
			"equivalent_paths_glob": (
				"paths-ignore: test[s]/**\n",
				"codeql_suppression.tests_path_ignored",
			),
			"source_paths": (
				"paths:\n  - addons/gf/**\n",
				"codeql_suppression.source_paths_filtered",
			),
			"flow_query_filter": (
				"query-filters: [{exclude: "
				"{id: py/clear-text-storage-sensitive-data}}]\n",
				"codeql_suppression.security_query_excluded",
			),
			"tag_query_filter": (
				"query-filters:\n"
				"  - exclude:\n"
				"      tags contain: security\n",
				"codeql_suppression.security_query_excluded",
			),
			"aliased_query_filter": (
				"blocked: &credential_rule "
				"py/clear-text-storage-sensitive-data\n"
				"query-filters:\n"
				"  - exclude:\n"
				"      id: *credential_rule\n",
				"codeql_suppression.security_query_excluded",
			),
			"custom_config": (
				"uses: github/codeql-action/init@v3\n"
				"with:\n"
				"  config-file: security/code-scanning.yml\n",
				"codeql_suppression.custom_config_reference_forbidden",
			),
			"custom_queries": (
				"uses: github/codeql-action/init@v3\n"
				"with:\n"
				"  queries: ./security/custom.qls\n",
				"codeql_suppression.custom_queries_forbidden",
			),
			"unicode_escaped_key": (
				'"disable-default-\\u0071ueries": true\n',
				"codeql_suppression.default_queries_disabled",
			),
		}
		for name, (source, expected_kind) in fixtures.items():
			with self.subTest(name=name):
				issues = policy.audit_codeql_config(
					".github/workflows/codeql.yml",
					source,
				)
				self.assertIn(expected_kind, self._issue_kinds(issues))

	def test_tracked_custom_query_suite_is_rejected(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			root = Path(temp_dir)
			query_suite = root / "security/custom.qls"
			query_suite.parent.mkdir(parents=True)
			query_suite.write_text("- include:\n    kind: problem\n", encoding="utf-8")

			result = policy.audit_tracked_sources(
				root,
				["security/custom.qls"],
				lambda path: path.read_text(encoding="utf-8"),
			)

			self.assertFalse(result["ok"])
			self.assertEqual(result["codeql_config_file_count"], 1)
			self.assertEqual(
				self._issue_kinds(result["issues"]),
				{"codeql_suppression.custom_queries_forbidden"},
			)

	def test_encoded_codeql_action_is_identified_before_policy_audit(self) -> None:
		fixtures = {
			"unicode_escape": (
				'uses: "github/codeql-\\u0061ction/init@v3"\n'
				"with:\n"
				"  queries: ./security/custom.qls\n"
			),
			"line_continuation": (
				'uses: "github/codeql-act\\\n'
				'  ion/init@v3"\n'
				"with:\n"
				"  queries: ./security/custom.qls\n"
			),
		}
		for name, source in fixtures.items():
			with self.subTest(name=name):
				with tempfile.TemporaryDirectory() as temp_dir:
					root = Path(temp_dir)
					workflow = root / ".github/workflows/analysis.yml"
					workflow.parent.mkdir(parents=True)
					workflow.write_text(source, encoding="utf-8")

					result = policy.audit_tracked_sources(
						root,
						[".github/workflows/analysis.yml"],
						lambda path: path.read_text(encoding="utf-8"),
					)

				self.assertFalse(result["ok"])
				self.assertEqual(result["codeql_config_file_count"], 1)
				self.assertIn(
					"codeql_suppression.custom_queries_forbidden",
					self._issue_kinds(result["issues"]),
				)

	def test_codeql_config_rejects_escaped_multiline_policy_keys(self) -> None:
		fixtures = {
			"paths_ignore": (
				'? "paths-\\\n  ignore"\n: [tests/**]\n',
				"codeql_suppression.tests_path_ignored",
			),
			"query_filters": (
				'? "query-\\\n  filters"\n: [{exclude: {tags: security}}]\n',
				"codeql_suppression.security_query_excluded",
			),
			"queries": (
				'? "quer\\\n  ies"\n: ./security/custom.qls\n',
				"codeql_suppression.custom_queries_forbidden",
			),
			"config_file": (
				'? "config-\\\n  file"\n: ./security/codeql.yml\n',
				"codeql_suppression.custom_config_reference_forbidden",
			),
			"disable_default_queries": (
				'? "disable-defa\\\n  ult-queries"\n: true\n',
				"codeql_suppression.default_queries_disabled",
			),
		}
		for name, (source, expected_kind) in fixtures.items():
			with self.subTest(name=name):
				issues = policy.audit_codeql_config(
					".github/workflows/codeql.yml",
					"name: CodeQL\n" + source,
				)
				issue_kinds = self._issue_kinds(issues)
				self.assertIn(expected_kind, issue_kinds)
				self.assertIn(
					"codeql_suppression.yaml_line_continuation_forbidden",
					issue_kinds,
				)

	def test_strict_git_inventory_rejects_invalid_utf8_and_path_collisions(self) -> None:
		fixtures = {
			"invalid_utf8": (
				b"safe.py\0\xff.py\0",
				"Git path inventory is not valid UTF-8.",
			),
			"backslash_collision": (
				b"safe/path.py\0safe\\path.py\0",
				"Git path inventory contains a non-canonical path.",
			),
			"control_character": (
				b"safe.py\0line\nbreak.py\0",
				"Git path inventory contains a non-canonical path.",
			),
		}
		for name, (stdout, expected_error) in fixtures.items():
			with self.subTest(name=name):
				completed = subprocess.CompletedProcess(
					args=["git", "ls-files"],
					returncode=0,
					stdout=stdout,
					stderr=b"",
				)
				with mock.patch.object(
					gf_maintenance.subprocess,
					"run",
					return_value=completed,
				):
					result = gf_maintenance.read_git_paths_uncached(
						["ls-files", "-z", "--cached"],
						strict_utf8=True,
					)

				self.assertEqual(result["paths"], [])
				self.assertEqual(result["error"], expected_error)

	def test_non_codeql_workflow_and_yaml_comments_do_not_trigger(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			root = Path(temp_dir)
			workflow = root / ".github/workflows/ordinary.yml"
			workflow.parent.mkdir(parents=True)
			workflow.write_text(
				"paths-ignore:\n"
				"  - tests/**\n"
				"# github/codeql-action/init@v3\n",
				encoding="utf-8",
			)

			result = policy.audit_tracked_sources(
				root,
				[".github/workflows/ordinary.yml"],
				lambda path: path.read_text(encoding="utf-8"),
			)

			self.assertTrue(result["ok"])
			self.assertEqual(result["codeql_config_file_count"], 0)

	def test_codeql_directive_does_not_suppress_gf_credential_gate(self) -> None:
		self.assertIsNone(
			credential_gate.SUPPRESSION_RE.fullmatch(
				"# codeql[py/clear-text-storage-sensitive-data]"
			)
		)

	@staticmethod
	def _issue_kinds(issues: list[dict[str, object]]) -> set[str]:
		return {str(issue["kind"]) for issue in issues}


if __name__ == "__main__":
	unittest.main()
