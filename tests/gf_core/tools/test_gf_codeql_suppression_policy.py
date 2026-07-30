#!/usr/bin/env python3
"""Focused tests for the tracked-source CodeQL suppression policy."""

from __future__ import annotations

import json
import os
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
import gf_path_security as path_security  # noqa: E402


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

			result = policy.audit_tracked_sources(
				root,
				["tracked.py"],
			)

			self.assertTrue(result["ok"])
			self.assertEqual(result["python_file_count"], 1)
			self.assertEqual(result["suppression_count"], 0)

	def test_tracked_python_invalid_utf8_is_fail_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			root = Path(temp_dir)
			tracked = root / "tracked.py"
			tracked.write_bytes(b"value = '\xff'\n")

			result = policy.audit_tracked_sources(
				root,
				["tracked.py"],
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
			)

			self.assertFalse(result["ok"])
			self.assertEqual(
				self._issue_kinds(result["issues"]),
				{"codeql_suppression.python_source_unreadable"},
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
				result = policy.audit_tracked_sources(
					Path("unused"),
					[tracked_path],
				)

				self.assertFalse(result["ok"])
				self.assertEqual(result["issues"][0]["path"], "git-index")
				self.assertIn(
					str(result["issues"][0]["kind"]),
					{
						"codeql_suppression.tracked_path_control_character",
						"codeql_suppression.tracked_path_noncanonical",
					},
				)

	def test_portable_tracked_path_collisions_fail_before_reads(self) -> None:
		result = policy.audit_tracked_sources(
			Path("unused"),
			["safe/path.py", "SAFE/PATH.py"],
		)

		self.assertFalse(result["ok"])
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

	def test_legacy_lgtm_only_rejects_bracketed_suppression_syntax(self) -> None:
		allowed = (
			"# LGTM after validation\n"
			"# lgtm is ordinary review prose\n"
			"value = 1\n"
		)
		allowed_issues, allowed_count = policy.audit_python_source(
			"tools/fixture.py",
			allowed,
		)
		self.assertEqual(allowed_issues, [])
		self.assertEqual(allowed_count, 0)

		for source in (
			"# lgtm[py/clear-text-storage-sensitive-data]\nsink()\n",
			"# LGTM [py/clear-text-storage-sensitive-data]\nsink()\n",
		):
			with self.subTest(source=source):
				issues, suppression_count = policy.audit_python_source(
					"tools/fixture.py",
					source,
				)
				self.assertEqual(suppression_count, 1)
				self.assertEqual(
					self._issue_kinds(issues),
					{"codeql_suppression.legacy_lgtm_directive"},
				)

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

	def test_codeql_config_ignores_forbidden_words_in_scalar_prose(self) -> None:
		source = (
			'name: "CodeQL paths-ignore query-filters queries config-file"\n'
			'note: "disable-default-queries: false"\n'
			'metadata: {note: "paths: addons, queries: custom"}\n'
		)

		issues = policy.audit_codeql_config(".github/workflows/codeql.yml", source)

		self.assertEqual(issues, [])

	def test_yaml_comment_delimiter_preserves_url_fragments_and_real_flow_keys(
		self,
	) -> None:
		source = (
			"name: CodeQL\n"
			"settings: {url: https://example.invalid/#fragment, "
			"queries: ./security/custom.qls}\n"
			"url: https://example.invalid/value # paths-ignore: tests/**\n"
		)

		issues = policy.audit_codeql_config(".github/workflows/codeql.yml", source)

		self.assertEqual(
			self._issue_kinds(issues),
			{"codeql_suppression.custom_queries_forbidden"},
		)

	def test_block_scalars_and_shell_backslashes_are_not_policy_structure(
		self,
	) -> None:
		source = (
			"name: CodeQL\n"
			"run: |\n"
			"  paths-ignore:\n"
			"  queries: ./security/custom.qls\n"
			"  echo continued \\\n"
			"description: >\n"
			"  query-filters: [{exclude: {tags: security}}]\n"
			"run-inline: echo continued \\\n"
		)

		issues = policy.audit_codeql_config(".github/workflows/codeql.yml", source)

		self.assertEqual(issues, [])

	def test_block_scalar_ends_at_compact_mapping_sibling_indent(self) -> None:
		source = (
			"name: CodeQL\n"
			"steps:\n"
			"  - run: |\n"
			"      echo paths-ignore: harmless\n"
			"    queries: ./security/custom.qls\n"
			"  - run: |2\n"
			"      echo query-filters: harmless\n"
			"    paths-ignore: tests/**\n"
			"  - run: >\n"
			"    config-file: ./security/codeql.yml\n"
		)

		issues = policy.audit_codeql_config(".github/workflows/codeql.yml", source)

		self.assertEqual(
			self._issue_kinds(issues),
			{
				"codeql_suppression.custom_config_reference_forbidden",
				"codeql_suppression.custom_queries_forbidden",
				"codeql_suppression.tests_path_ignored",
			},
		)

	def test_tagged_or_anchored_block_scalars_exclude_only_their_content(
		self,
	) -> None:
		source = (
			"name: CodeQL\n"
			"run: !!str |\n"
			"  queries: harmless\n"
			"verbatim: !<tag:yaml.org,2002:str> |\n"
			"  paths-ignore: harmless\n"
			"script: &script >\n"
			"  paths-ignore: harmless\n"
			"safe: *script\n"
		)

		issues = policy.audit_codeql_config(".github/workflows/codeql.yml", source)

		self.assertEqual(issues, [])

	def test_verbatim_tag_uri_cannot_hide_mapping_keys(self) -> None:
		source = (
			"name: CodeQL\n"
			"!<tag:yaml.org,2002:str> queries: ./security/block.qls\n"
			"flow: {!<tag:yaml.org,2002:str> paths-ignore: tests/**}\n"
			"? !<tag:yaml.org,2002:str> config-file\n"
			": ./security/codeql.yml\n"
		)

		issues = policy.audit_codeql_config(".github/workflows/codeql.yml", source)

		self.assertEqual(
			self._issue_kinds(issues),
			{"codeql_suppression.complex_mapping_key_forbidden"},
		)
		self.assertEqual(
			sum(
				issue["kind"]
				== "codeql_suppression.complex_mapping_key_forbidden"
				for issue in issues
			),
			3,
		)

	def test_multiline_flow_structures_fail_closed(self) -> None:
		fixtures = {
			"plain": (
				"with: {? queries\n"
				"  : ./security/custom.qls}\n"
			),
			"quoted": (
				'with: {? "queries"\n'
				"  : ./security/custom.qls}\n"
			),
			"tagged": (
				"with: {? !<tag:yaml.org,2002:str> queries\n"
				"  : ./security/custom.qls}\n"
			),
		}
		for name, source in fixtures.items():
			with self.subTest(name=name):
				issues = policy.audit_codeql_config(
					".github/workflows/codeql.yml",
					"name: CodeQL\n" + source,
				)
				self.assertIn(
					"codeql_suppression.complex_mapping_key_forbidden",
					self._issue_kinds(issues),
				)

	def test_flow_collection_mapping_keys_fail_closed(self) -> None:
		for source in (
			"flow: {[queries]: value}\n",
			"flow: {? [queries]: value}\n",
			"flow: {{ordinary: value}: nested}\n",
		):
			with self.subTest(source=source):
				issues = policy.audit_codeql_config(
					".github/workflows/codeql.yml",
					"name: CodeQL\n" + source,
				)
				self.assertIn(
					"codeql_suppression.complex_mapping_key_forbidden",
					self._issue_kinds(issues),
				)

	def test_yaml_lexer_work_budget_fails_before_quadratic_quote_probes(
		self,
	) -> None:
		source = 'values: [' + ('""' * 3000) + "]\n"

		with mock.patch.object(
			policy,
			"_normalize_yaml_policy_lines",
			side_effect=AssertionError("lexer normalization must not start"),
		):
			issues = policy.audit_codeql_config(
				".github/workflows/codeql.yml",
				source,
			)

		self.assertEqual(
			self._issue_kinds(issues),
			{"codeql_suppression.yaml_lexer_budget_exceeded"},
		)

	def test_quoted_value_continuation_identifies_codeql_without_key_warning(
		self,
	) -> None:
		source = (
			'uses: "github/codeql-act\\\n'
			'  ion/init@v3"\n'
			"with: {queries: ./security/custom.qls}\n"
		)

		issues = policy.audit_codeql_config(".github/workflows/analysis.yml", source)

		self.assertEqual(
			self._issue_kinds(issues),
			{"codeql_suppression.custom_queries_forbidden"},
		)

	def test_multiline_quoted_scalars_do_not_create_mapping_keys(self) -> None:
		source = (
			'name: "CodeQL review prose\n'
			'  queries: harmless"\n'
			"note: 'review prose\n"
			"  paths-ignore: harmless'\n"
		)

		issues = policy.audit_codeql_config(".github/workflows/codeql.yml", source)

		self.assertEqual(issues, [])

	def test_plain_scalar_colons_do_not_open_multiline_quotes(self) -> None:
		source = (
			"name: CodeQL\n"
			'url: https:"thing\n'
			"queries: ./security/custom.qls\n"
			'with: {url: https:"thing, paths-ignore: tests/**}\n'
		)

		issues = policy.audit_codeql_config(".github/workflows/codeql.yml", source)

		self.assertEqual(
			self._issue_kinds(issues),
			{
				"codeql_suppression.custom_queries_forbidden",
				"codeql_suppression.tests_path_ignored",
			},
		)

	def test_quotes_inside_plain_scalars_do_not_swallow_later_keys(self) -> None:
		source = (
			"name: CodeQL\n"
			"note: it's safe\n"
			'detail: he said "safe"\n'
			"queries: ./security/custom.qls\n"
		)

		issues = policy.audit_codeql_config(".github/workflows/codeql.yml", source)

		self.assertEqual(
			self._issue_kinds(issues),
			{"codeql_suppression.custom_queries_forbidden"},
		)

	def test_escaped_multiline_quoted_values_are_not_key_continuations(
		self,
	) -> None:
		safe_source = (
			"name: CodeQL\n"
			"values:\n"
			'  - "safe\\\n'
			'    value"\n'
			"note:\n"
			'  "safe\\\n'
			'  value"\n'
		)
		structural_source = (
			"name: CodeQL\n"
			'- "safe\\\n'
			'  key": harmless\n'
		)

		safe_issues = policy.audit_codeql_config(
			".github/workflows/codeql.yml",
			safe_source,
		)
		structural_issues = policy.audit_codeql_config(
			".github/workflows/codeql.yml",
			structural_source,
		)

		self.assertEqual(safe_issues, [])
		self.assertEqual(
			self._issue_kinds(structural_issues),
			{"codeql_suppression.yaml_line_continuation_forbidden"},
		)

	def test_flow_mapping_empty_values_remain_real_policy_keys(self) -> None:
		source = (
			"name: CodeQL\n"
			"with: {queries:, other: 1}\n"
			"config: {paths-ignore:}\n"
			'json: {"config-file":"./security/codeql.yml"}\n'
		)

		issues = policy.audit_codeql_config(".github/workflows/codeql.yml", source)

		self.assertEqual(
			self._issue_kinds(issues),
			{
				"codeql_suppression.custom_config_reference_forbidden",
				"codeql_suppression.custom_queries_forbidden",
				"codeql_suppression.tests_path_ignored",
			},
		)

	def test_complex_or_indirect_mapping_keys_fail_closed(self) -> None:
		source = (
			"name: CodeQL\n"
			"&policy queries: ./security/custom.qls\n"
			"shared: &ordinary_value harmless\n"
			"ordinary: *ordinary_value\n"
			"? *indirect_key\n"
			": harmless\n"
			"!!str queries: ./security/tagged.qls\n"
			"*implicit_key: harmless\n"
			"flow: {*flow_key: harmless}\n"
		)

		issues = policy.audit_codeql_config(".github/workflows/codeql.yml", source)

		self.assertEqual(
			self._issue_kinds(issues),
			{"codeql_suppression.complex_mapping_key_forbidden"},
		)
		self.assertEqual(
			sum(
				issue["kind"]
				== "codeql_suppression.complex_mapping_key_forbidden"
				for issue in issues
			),
			5,
		)

	def test_direct_plain_keys_with_punctuation_are_not_complex(self) -> None:
		source = (
			"name: CodeQL\n"
			"some.input: harmless\n"
			"vendor/key: harmless\n"
		)

		issues = policy.audit_codeql_config(".github/workflows/codeql.yml", source)

		self.assertEqual(issues, [])

	def test_stream_start_bom_does_not_hide_policy_key(self) -> None:
		for source in (
			"\ufeffqueries: ./security/custom.qls\n",
			'\ufeff"queries": ./security/custom.qls\n',
		):
			with self.subTest(source=source):
				issues = policy.audit_codeql_config(
					".github/workflows/codeql.yml",
					source,
				)

				self.assertEqual(
					self._issue_kinds(issues),
					{"codeql_suppression.custom_queries_forbidden"},
				)

	def test_tracked_custom_query_suite_is_rejected(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			root = Path(temp_dir)
			query_suite = root / "security/custom.qls"
			query_suite.parent.mkdir(parents=True)
			query_suite.write_text("- include:\n    kind: problem\n", encoding="utf-8")

			result = policy.audit_tracked_sources(
				root,
				["security/custom.qls"],
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
			"block_scalar": (
				"- uses: >-\n"
				"    github/codeql-action/init@v3\n"
				"  with:\n"
				"    queries: ./security/custom.qls\n"
			),
			"escaped_slashes": (
				'uses: "github\\/codeql-action\\/init@v3"\n'
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

	def test_pinned_utf8_regular_file_preserves_bom_and_enforces_limits(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			root = Path(temp_dir)
			candidate = root / "tracked.py"
			payload = b"\xef\xbb\xbfvalue = 1\n"
			candidate.write_bytes(payload)

			text = path_security.read_pinned_utf8_regular_file(
				root,
				"tracked.py",
				max_bytes=len(payload),
			)

			self.assertTrue(text.startswith("\ufeff"))
			with self.assertRaises(path_security.PinnedReadError) as oversized:
				path_security.read_pinned_utf8_regular_file(
					root,
					"tracked.py",
					max_bytes=len(payload) - 1,
				)
			self.assertEqual(
				oversized.exception.rule_id,
				"path_security.file_too_large",
			)
			self.assertEqual(
				str(oversized.exception),
				"path_security.file_too_large",
			)

			candidate.write_bytes(b"\xff")
			with self.assertRaises(path_security.PinnedReadError) as invalid_utf8:
				path_security.read_pinned_utf8_regular_file(
					root,
					"tracked.py",
					max_bytes=1,
				)
			self.assertEqual(
				invalid_utf8.exception.rule_id,
				"path_security.invalid_utf8",
			)

			candidate.write_bytes(b"12345")
			descriptor = os.open(candidate, os.O_RDONLY)
			try:
				with self.assertRaises(path_security.PinnedReadError) as grew:
					path_security._read_opened_file_bytes(
						descriptor,
						4,
						max_bytes=4,
					)
			finally:
				os.close(descriptor)
			self.assertEqual(
				grew.exception.rule_id,
				"path_security.file_too_large",
			)

	def test_pinned_read_rejects_non_integer_or_negative_budgets(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			root = Path(temp_dir)
			(root / "tracked.py").write_bytes(b"value")
			for invalid_budget in (-1, True, float("nan"), "5"):
				with self.subTest(invalid_budget=invalid_budget):
					with self.assertRaises(
						path_security.PinnedReadError
					) as failure:
						path_security.read_pinned_utf8_regular_file(
							root,
							"tracked.py",
							max_bytes=invalid_budget,
						)
					self.assertEqual(
						failure.exception.rule_id,
						"path_security.invalid_budget",
					)

	def test_pinned_read_rejects_unknown_object_identity(self) -> None:
		unknown = os.stat_result((
			0o100644,
			0,
			0,
			1,
			0,
			0,
			1,
			0,
			0,
			0,
		))

		self.assertFalse(path_security._same_object_identity(unknown, unknown))

	def test_pinned_read_requires_posix_pinning_capabilities(self) -> None:
		for flag_name in ("O_DIRECTORY", "O_NOFOLLOW", "O_NONBLOCK"):
			with self.subTest(flag_name=flag_name):
				with (
					mock.patch.object(path_security.os, "name", "posix"),
					mock.patch.object(
						path_security.os,
						"supports_dir_fd",
						{path_security.os.open, path_security.os.stat},
					),
					mock.patch.object(
						path_security.os,
						"supports_follow_symlinks",
						{path_security.os.stat},
					),
					mock.patch.object(
						path_security.os,
						flag_name,
						0,
						create=True,
					),
				):
					with self.assertRaises(
						path_security.PinnedReadError
					) as failure:
						path_security._open_directory_chain(Path("unused"))

				self.assertEqual(
					failure.exception.rule_id,
					"path_security.platform_unsupported",
				)
		with (
			mock.patch.object(path_security.os, "name", "posix"),
			mock.patch.object(
				path_security.os,
				"supports_dir_fd",
				{path_security.os.open, path_security.os.stat},
			),
			mock.patch.object(
				path_security.os,
				"supports_follow_symlinks",
				set(),
			),
			mock.patch.object(path_security.os, "O_DIRECTORY", 1, create=True),
			mock.patch.object(path_security.os, "O_NOFOLLOW", 1, create=True),
			mock.patch.object(path_security.os, "O_NONBLOCK", 1, create=True),
		):
			with self.assertRaises(path_security.PinnedReadError) as failure:
				path_security._open_directory_chain(Path("unused"))
		self.assertEqual(
			failure.exception.rule_id,
			"path_security.platform_unsupported",
		)

	def test_pinned_read_accepts_only_canonical_relative_paths(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			root = Path(temp_dir)
			(root / "tracked.py").write_text("value = 1\n", encoding="utf-8")
			nested = root / "nested"
			nested.mkdir()
			(nested / "tracked.py").write_bytes(b"nested = 1\n")
			self.assertEqual(
				path_security.read_pinned_utf8_regular_file(
					root,
					"nested/tracked.py",
					max_bytes=1024,
				),
				"nested = 1\n",
			)
			fixtures: tuple[str | Path, ...] = (
				root / "tracked.py",
				str(root / "tracked.py"),
				".",
				"./tracked.py",
				"nested/../tracked.py",
				"nested//tracked.py",
				r"nested\tracked.py",
				"C:/tracked.py",
			)
			for relative_path in fixtures:
				with self.subTest(relative_path=relative_path):
					with self.assertRaises(
						path_security.PinnedReadError
					) as failure:
						path_security.read_pinned_utf8_regular_file(
							root,
							relative_path,
							max_bytes=1024,
						)
					self.assertEqual(
						failure.exception.rule_id,
						"path_security.boundary_invalid",
					)

	def test_pinned_read_cleanup_attempts_every_descriptor(self) -> None:
		close_calls: list[int] = []

		def close_descriptor(descriptor: int) -> None:
			close_calls.append(descriptor)
			if descriptor == 102:
				raise OSError("synthetic close failure")

		with mock.patch.object(
			path_security.os,
			"close",
			side_effect=close_descriptor,
		):
			with self.assertRaises(path_security.PinnedReadError) as failure:
				path_security._close_descriptors([102, 101])

		self.assertEqual(close_calls, [102, 101])
		self.assertEqual(
			failure.exception.rule_id,
			"path_security.close_failed",
		)

	def test_tracked_read_rejects_linked_directory_without_disclosure(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			temporary_root = Path(temp_dir)
			root = temporary_root / "workspace"
			root.mkdir()
			outside = temporary_root / "outside-sensitive-location"
			outside.mkdir()
			(outside / "tracked.py").write_text(
				"# codeql[py/clear-text-storage-sensitive-data]\n",
				encoding="utf-8",
			)
			linked = root / "linked"
			gf_maintenance.create_directory_link_fixture(outside, linked)
			try:
				result = policy.audit_tracked_sources(
					root,
					["linked/tracked.py"],
				)
			finally:
				self._remove_directory_link(linked)

			report = json.dumps(result, ensure_ascii=False)
			self.assertFalse(result["ok"])
			self.assertEqual(result["suppression_count"], 0)
			self.assertNotIn(str(outside), report)
			self.assertNotIn("outside-sensitive-location", report)

	def test_pinned_read_rejects_leaf_link_or_reparse(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			temporary_root = Path(temp_dir)
			root = temporary_root / "workspace"
			root.mkdir()
			outside = temporary_root / "outside"
			outside.mkdir()
			leaf = root / "tracked.py"
			if os.name == "nt":
				gf_maintenance.create_directory_link_fixture(outside, leaf)
			else:
				outside_file = outside / "tracked.py"
				outside_file.write_text("value = 1\n", encoding="utf-8")
				os.symlink(outside_file, leaf)
			try:
				with self.assertRaises(path_security.PinnedReadError) as failure:
					path_security.read_pinned_utf8_regular_file(
						root,
						"tracked.py",
						max_bytes=1024,
					)
			finally:
				self._remove_directory_link(leaf)

			self.assertIn(
				failure.exception.rule_id,
				{
					"path_security.file_not_regular",
					"path_security.file_unavailable",
				},
			)
			self.assertNotIn(str(outside), str(failure.exception))

	def test_tracked_read_rejects_linked_workspace_root(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			temporary_root = Path(temp_dir)
			real_root = temporary_root / "real-workspace"
			real_root.mkdir()
			(real_root / "tracked.py").write_text("value = 1\n", encoding="utf-8")
			linked_root = temporary_root / "linked-workspace"
			gf_maintenance.create_directory_link_fixture(real_root, linked_root)
			try:
				result = policy.audit_tracked_sources(
					linked_root,
					["tracked.py"],
				)
			finally:
				self._remove_directory_link(linked_root)

			report = json.dumps(result, ensure_ascii=False)
			self.assertFalse(result["ok"])
			self.assertNotIn(str(real_root), report)
			self.assertNotIn("real-workspace", report)

	def test_tracked_read_pins_chain_against_parent_replacement(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			temporary_root = Path(temp_dir)
			root = temporary_root / "workspace"
			source_parent = root / "nested"
			source_parent.mkdir(parents=True)
			(source_parent / "tracked.py").write_text("value = 1\n", encoding="utf-8")
			outside = temporary_root / "outside"
			outside.mkdir()
			(outside / "tracked.py").write_text(
				"# codeql[py/clear-text-storage-sensitive-data]\n",
				encoding="utf-8",
			)
			held_parent = root / "nested-held"
			real_read = path_security._read_opened_file_bytes
			attack_state = {"attempted": False, "exchanged": False}

			def exchange_during_read(
				file_descriptor: int,
				expected_size: int,
				*,
				max_bytes: int,
			) -> bytes:
				payload = real_read(
					file_descriptor,
					expected_size,
					max_bytes=max_bytes,
				)
				attack_state["attempted"] = True
				try:
					os.replace(source_parent, held_parent)
					gf_maintenance.create_directory_link_fixture(outside, source_parent)
					attack_state["exchanged"] = True
				except OSError:
					if os.path.lexists(source_parent) and source_parent.is_symlink():
						self._remove_directory_link(source_parent)
					if held_parent.exists() and not source_parent.exists():
						os.replace(held_parent, source_parent)
				return payload

			try:
				with mock.patch.object(
					path_security,
					"_read_opened_file_bytes",
					side_effect=exchange_during_read,
				):
					result = policy.audit_tracked_sources(
						root,
						["nested/tracked.py"],
					)
			finally:
				if os.path.lexists(source_parent) and (
					source_parent.is_symlink()
					or getattr(source_parent, "is_junction", lambda: False)()
				):
					self._remove_directory_link(source_parent)
				if held_parent.exists() and not source_parent.exists():
					os.replace(held_parent, source_parent)

			self.assertTrue(attack_state["attempted"])
			if attack_state["exchanged"]:
				self.assertFalse(result["ok"])
			else:
				self.assertTrue(result["ok"])
			self.assertEqual(result["suppression_count"], 0)
			self.assertNotIn(
				str(outside),
				json.dumps(result, ensure_ascii=False),
			)

	def test_pinned_read_detects_leaf_replacement_when_platform_allows_it(
		self,
	) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			root = Path(temp_dir)
			candidate = root / "tracked.py"
			candidate.write_text("value = 1\n", encoding="utf-8")
			held = root / "tracked-held.py"
			replacement = root / "replacement.py"
			replacement.write_text(
				"# codeql[py/clear-text-storage-sensitive-data]\n",
				encoding="utf-8",
			)
			real_read = path_security._read_opened_file_bytes
			attack_state = {"attempted": False, "exchanged": False}

			def replace_leaf_during_read(
				file_descriptor: int,
				expected_size: int,
				*,
				max_bytes: int,
			) -> bytes:
				payload = real_read(
					file_descriptor,
					expected_size,
					max_bytes=max_bytes,
				)
				attack_state["attempted"] = True
				try:
					os.replace(candidate, held)
					os.replace(replacement, candidate)
					attack_state["exchanged"] = True
				except OSError:
					if held.exists() and not candidate.exists():
						os.replace(held, candidate)
				return payload

			with mock.patch.object(
				path_security,
				"_read_opened_file_bytes",
				side_effect=replace_leaf_during_read,
			):
				if os.name == "nt":
					text = path_security.read_pinned_utf8_regular_file(
						root,
						"tracked.py",
						max_bytes=1024,
					)
					self.assertEqual(text.strip(), "value = 1")
				else:
					with self.assertRaises(path_security.PinnedReadError) as failure:
						path_security.read_pinned_utf8_regular_file(
							root,
							"tracked.py",
							max_bytes=1024,
						)
					self.assertEqual(
						failure.exception.rule_id,
						"path_security.file_changed",
					)

			self.assertTrue(attack_state["attempted"])
			if os.name == "nt":
				self.assertFalse(attack_state["exchanged"])
			else:
				self.assertTrue(attack_state["exchanged"])

	def test_pinned_read_blocks_or_detects_equal_size_overwrite(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			root = Path(temp_dir)
			candidate = root / "tracked.py"
			original = b"value = 1"
			replacement = b"# codeql\n"
			self.assertEqual(len(original), len(replacement))
			candidate.write_bytes(original)
			metadata = candidate.stat()
			real_read = path_security._read_opened_file_bytes
			attack_state = {"attempted": False, "modified": False}

			def overwrite_during_read(
				file_descriptor: int,
				expected_size: int,
				*,
				max_bytes: int,
			) -> bytes:
				payload = real_read(
					file_descriptor,
					expected_size,
					max_bytes=max_bytes,
				)
				attack_state["attempted"] = True
				try:
					with candidate.open("r+b", buffering=0) as handle:
						handle.write(replacement)
						os.fsync(handle.fileno())
					os.utime(
						candidate,
						ns=(metadata.st_atime_ns, metadata.st_mtime_ns),
					)
					attack_state["modified"] = True
				except OSError:
					pass
				return payload

			failure: path_security.PinnedReadError | None = None
			text = ""
			try:
				with mock.patch.object(
					path_security,
					"_read_opened_file_bytes",
					side_effect=overwrite_during_read,
				):
					text = path_security.read_pinned_utf8_regular_file(
						root,
						"tracked.py",
						max_bytes=1024,
					)
			except path_security.PinnedReadError as error:
				failure = error

			self.assertTrue(attack_state["attempted"])
			if attack_state["modified"]:
				self.assertIsNotNone(failure)
				self.assertEqual(
					failure.rule_id if failure is not None else "",
					"path_security.file_changed",
				)
			else:
				self.assertIsNone(failure)
				self.assertEqual(text, original.decode("utf-8"))

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

	@staticmethod
	def _remove_directory_link(path: Path) -> None:
		if os.name == "nt":
			os.rmdir(path)
			return
		path.unlink()


if __name__ == "__main__":
	unittest.main()
