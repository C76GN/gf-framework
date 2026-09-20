"""Executable contract for framework-native diagnostic convention checks."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))

import gf_diagnostic_policy as policy  # noqa: E402


PATH = "addons/gf/kernel/core/gf_fixture.gd"
EMPTY_POLICY = {"schema_version": 1, "forwarders": []}
MESSAGE = "[GFFixture][fixture.invalid_target] Cannot start: target is invalid."


class DiagnosticPolicyTests(unittest.TestCase):
	def check_source(self, source: str, forwarders: list[dict[str, object]] | None = None) -> dict[str, object]:
		return policy.audit_sources({PATH: source}, {"schema_version": 1, "forwarders": forwarders or []})

	def kinds(self, report: dict[str, object]) -> set[str]:
		return {issue["kind"] for issue in report["issues"]}

	def test_coded_english_template_and_unicode_runtime_context(self) -> None:
		report = self.check_source('func run():\n\tpush_warning("' + MESSAGE + ' Path=%s." % "用户/配置.json")\n')
		self.assertTrue(report["ok"], report)
		self.assertEqual(report["native_call_count"], 1)

	def test_code_like_unicode_arguments_are_not_framework_templates(self) -> None:
		for argument in ('"[level.name] 中文"', '"[GFProject][project.text] 中文"', '_PATH'):
			with self.subTest(argument=argument):
				source = 'const _PATH = "[level.name] 中文"\npush_error("[GFFixture][fixture.failed] Failed at %s." % ' + argument + ')'
				# An unused project-data constant is not introduced in other cases.
				if argument != '_PATH':
					source = source.split('\n', 1)[1]
				report = self.check_source(source)
				self.assertTrue(report["ok"], report)
		for expression in ('"[GFFixture][fixture.failed] Failed at %s." % "[level.name] 中文"', '"[GFFixture][fixture.failed] Failed at {path}.".format({"path": "[level.name] 中文"})'):
			with self.subTest(expression=expression):
				report = self.check_source('var message = ' + expression + '\nrelay(message)')
				self.assertTrue(report["ok"], report)

	def test_legacy_prefix_and_chinese_template_are_rejected(self) -> None:
		legacy = self.check_source('push_error("[GFFixture] Invalid target.")')
		chinese = self.check_source('push_error("[GFFixture][fixture.invalid_target] 目标无效。")')
		self.assertIn("diagnostic.template_shape", self.kinds(legacy))
		self.assertIn("diagnostic.template_language", self.kinds(chinese))

	def test_namespace_names_the_owner_including_acronyms_and_numeric_suffixes(self) -> None:
		for owner, namespace in (("GF", "gf"), ("GFUIUtility", "ui_utility"), ("GFSpatialHash3D", "spatial_hash_3d")):
			with self.subTest(owner=owner):
				self.assertTrue(self.check_source(f'push_error("[{owner}][{namespace}.failed] Failed.")')["ok"])
		report = self.check_source('push_error("[GFFixture][unrelated.failed] Failed.")')
		self.assertIn("diagnostic.owner_namespace", self.kinds(report))

	def test_unicode_escapes_do_not_bypass_language_check(self) -> None:
		report = self.check_source(r'push_warning("[GFFixture][fixture.invalid_target] Invalid target\u3002")')
		self.assertIn("diagnostic.template_language", self.kinds(report))

	def test_comments_strings_and_qualified_project_methods_are_not_native_calls(self) -> None:
		source = '# push_error("wrong")\nvar text = \'push_warning("wrong")\'\nproject.push_error("project text")\n'
		report = self.check_source(source)
		self.assertTrue(report["ok"], report)
		self.assertEqual(report["native_call_count"], 0)

	def test_multiline_parentheses_and_literal_concatenation(self) -> None:
		source = 'push_error(\n\t("[GFFixture][fixture.invalid_target] " +\n\t"Cannot start: target is invalid."),\n)'
		report = self.check_source(source)
		self.assertTrue(report["ok"], report)

	def test_constant_template_is_checked_at_every_emission(self) -> None:
		source = 'const _MESSAGE: String = "' + MESSAGE + '"\nfunc run():\n\tpush_error(_MESSAGE)\n\tpush_error(_MESSAGE)\n'
		report = self.check_source(source)
		self.assertTrue(report["ok"], report)
		self.assertEqual(report["native_call_count"], 2)
		self.assertEqual(report["diagnostic_code_count"], 1)

	def test_constant_fragments_are_validated_as_the_complete_template(self) -> None:
		source = 'const _PREFIX = "[GFFixture][fixture.failed] "\npush_error(_PREFIX + "Failed.")'
		report = self.check_source(source)
		self.assertTrue(report["ok"], report)
		report = self.check_source(source.replace('Failed.', '失败。'))
		self.assertIn("diagnostic.template_language", self.kinds(report))

	def test_constant_language_violation_is_not_hidden(self) -> None:
		report = self.check_source('const _MESSAGE = "[GFFixture][fixture.failed] 失败。"\npush_error(_MESSAGE)')
		self.assertIn("diagnostic.template_language", self.kinds(report))

	def test_forwarded_producer_templates_keep_the_language_and_identity_contract(self) -> None:
		chinese = self.check_source('var message = "[GFFixture][fixture.failed] 失败。"\nrelay(message)')
		self.assertIn("diagnostic.template_language", self.kinds(chinese))
		conflict = self.check_source('relay("[fixture.failed] First failure.")\nrelay("[fixture.failed] Different failure.")')
		self.assertIn("diagnostic.code_conflict", self.kinds(conflict))

	def test_cyclic_constants_fail_closed(self) -> None:
		report = self.check_source('const _A = _B\nconst _B = _A\npush_error(_A)')
		self.assertIn("diagnostic.unreadable_syntax", self.kinds(report))

	def test_format_method_keeps_parameters_outside_language_rule(self) -> None:
		report = self.check_source('push_error("[GFFixture][fixture.failed] Cannot load {path}.".format({"path": "中文"}))')
		self.assertTrue(report["ok"], report)
		appended = self.check_source('push_error("[GFFixture][fixture.failed] Cannot load {path}.".format({"path": "中文"}) + "未校验的模板")')
		self.assertIn("diagnostic.unreviewed_forwarder", self.kinds(appended))

	def test_double_spaces_and_missing_explanation_fail(self) -> None:
		for message in ("[GFFixture][fixture.failed] Failed  twice.", "[GFFixture][fixture.failed] 123."):
			with self.subTest(message=message):
				self.assertFalse(self.check_source('push_error("' + message + '")')["ok"])

	def test_placeholder_arity_with_literal_arguments_and_escaped_percent(self) -> None:
		good = self.check_source('push_error("[GFFixture][fixture.failed] Failed at %s: %d%%." % ["中文", 30])')
		bad = self.check_source('push_error("[GFFixture][fixture.failed] Failed at %s: %d%%." % ["中文"])')
		self.assertTrue(good["ok"], good)
		self.assertIn("diagnostic.format_arity", self.kinds(bad))
		bracket = self.check_source('push_error("[GFFixture][fixture.failed] Failed at %s." % "[")')
		self.assertTrue(bracket["ok"], bracket)

	def test_scalar_percent_checks_syntax_and_known_literal_arity(self) -> None:
		for argument in ('name', '"name"', '1', '[name]'):
			with self.subTest(argument=argument):
				report = self.check_source('push_error("[GFFixture][fixture.failed] Failed at %q." % ' + argument + ')')
				self.assertIn("diagnostic.format_placeholder", self.kinds(report))
		for argument in ('"name"', '42'):
			with self.subTest(argument=argument):
				report = self.check_source('push_error("[GFFixture][fixture.failed] Failed at %s %s." % ' + argument + ')')
				self.assertIn("diagnostic.format_arity", self.kinds(report))

	def test_percent_expression_must_describe_the_entire_native_output(self) -> None:
		for tail in ('name + "未校验的模板"', 'name if ok else "未校验的模板"', 'name * 2'):
			with self.subTest(tail=tail):
				report = self.check_source('push_error("[GFFixture][fixture.failed] Failed at %s." % ' + tail + ')')
				self.assertIn("diagnostic.unreviewed_forwarder", self.kinds(report))
		for argument in ('(name + "中文")', '(first if ok else "中文")', 'context.get_name()', 'values[0]', '42'):
			with self.subTest(argument=argument):
				report = self.check_source('push_error("[GFFixture][fixture.failed] Failed at %s." % ' + argument + ')')
				self.assertTrue(report["ok"], report)

	def test_sentence_termination_is_consistent(self) -> None:
		report = self.check_source('push_error("[GFFixture][fixture.failed] Failed")')
		self.assertIn("diagnostic.template_termination", self.kinds(report))
		report = self.check_source('push_error("[GFFixture][fixture.failed] Failed\\n%s" % details)')
		self.assertIn("diagnostic.template_termination", self.kinds(report))
		report = self.check_source('push_error("[GFFixture][fixture.failed] Failed.\\n%s" % details)')
		self.assertTrue(report["ok"], report)

	def test_same_code_cannot_change_template_or_severity(self) -> None:
		for other in ('push_warning("' + MESSAGE + '")', 'push_error("[GFFixture][fixture.invalid_target] Different reason.")'):
			with self.subTest(other=other):
				report = self.check_source('push_error("' + MESSAGE + '")\n' + other)
				self.assertIn("diagnostic.code_conflict", self.kinds(report))

	def test_dynamic_output_needs_exact_reviewed_site(self) -> None:
		source = 'func relay(message: String):\n\tpush_error(message)\n'
		entry = {"path": PATH, "function": "relay", "callee": "push_error", "argument": "message", "kind": "project_message", "reason": "Project-owned text is preserved.", "count": 1}
		self.assertIn("diagnostic.unreviewed_forwarder", self.kinds(self.check_source(source)))
		report = self.check_source(source, [entry])
		self.assertTrue(report["ok"], report)
		self.assertEqual(report["forwarded_call_count"], 1)
		for changed in (source.replace("message)", "other)"), source + '\tpush_error(message)\n', source.replace("relay", "other"), ""):
			with self.subTest(changed=changed):
				self.assertFalse(self.check_source(changed, [entry])["ok"])

	def test_forwarding_policy_cannot_exempt_literal_violations(self) -> None:
		entry = {"path": PATH, "function": "relay", "callee": "push_error", "argument": '"中文"', "kind": "framework_message", "reason": "Invalid exemption.", "count": 1}
		report = self.check_source('func relay():\n\tpush_error("中文")', [entry])
		self.assertIn("diagnostic.template_shape", self.kinds(report))
		self.assertIn("diagnostic.forwarder_drift", self.kinds(report))
		source = 'func relay(detail):\n\tpush_error("[GFFixture][fixture.failed] 中文。" + detail)'
		entry["argument"] = '"[GFFixture][fixture.failed] 中文。" + detail'
		report = self.check_source(source, [entry])
		self.assertIn("diagnostic.template_language", self.kinds(report))
		entry["argument"] = "BAD + detail"
		source = 'const BAD = "[GFFixture][fixture.failed] 中文。"\nfunc relay(detail):\n\tpush_error(BAD + detail)\n\tvar text = "%s" % BAD'
		report = self.check_source(source, [entry])
		self.assertIn("diagnostic.template_language", self.kinds(report))

	def test_forwarding_binding_follows_function_body_and_not_neighboring_initializers(self) -> None:
		entry = {"path": PATH, "function": "relay", "callee": "push_error", "argument": "message", "kind": "project_message", "reason": "Project text.", "count": 1}
		for source in (
			'func relay():\n\tpass\nvar out = push_error(message)',
			'func relay():\n\tvar output = func(): push_error(message)',
		):
			with self.subTest(source=source):
				self.assertFalse(self.check_source(source, [entry])["ok"])
		source = 'func relay(\n\tmessage: String,\n) -> void:\n\tpush_error(message)\n'
		self.assertTrue(self.check_source(source, [entry])["ok"])

	def test_invalid_policy_and_duplicate_sites_fail_closed(self) -> None:
		for config in ({}, {"schema_version": True, "forwarders": []}, {"schema_version": 1, "forwarders": [], "ignore": ["*"]}):
			with self.subTest(config=config):
				self.assertFalse(policy.audit_sources({}, config)["ok"])
		entry = {"path": PATH, "function": "relay", "callee": "push_error", "argument": "message", "kind": "project_message", "reason": "Project text.", "count": 1}
		self.assertIn("diagnostic.policy_invalid", self.kinds(self.check_source("", [entry, entry])))

	def test_unclosed_syntax_and_indirect_builtins_are_rejected(self) -> None:
		for source in ('push_error("unterminated)', 'push_error(("message")', 'var output = push_error'):
			with self.subTest(source=source):
				self.assertFalse(self.check_source(source)["ok"])

	def test_native_varargs_do_not_bypass_template_contract(self) -> None:
		report = self.check_source('push_error("' + MESSAGE + '", "extra")')
		self.assertIn("diagnostic.argument_count", self.kinds(report))

	def test_budget_failure_does_not_become_empty_success(self) -> None:
		report = self.check_source("x" * (policy.MAX_SOURCE_BYTES + 1))
		self.assertIn("diagnostic.unreadable_syntax", self.kinds(report))

	def test_expanding_constants_fail_before_building_an_unbounded_template(self) -> None:
		source = 'const _A0 = "' + ('A' * 32768) + '"\n'
		for index in range(1, 9):
			source += f'const _A{index} = _A{index - 1} + _A{index - 1}\n'
		source += 'push_error("[GFFixture][fixture.failed] " + _A8 + ".")'
		report = self.check_source(source)
		self.assertIn("diagnostic.unreadable_syntax", self.kinds(report))
		self.assertIn("byte budget", str(report["issues"]))

	def test_unreadable_input_is_a_hard_failure(self) -> None:
		def fail_read(_path: Path) -> str:
			raise OSError("unreadable")
		report = policy.audit_files(ROOT, [], fail_read)
		self.assertIn("diagnostic.source_unreadable", self.kinds(report))

	def test_duplicate_json_keys_cannot_replace_forwarding_policy(self) -> None:
		report = policy.audit_files(ROOT, [], lambda _path: '{"schema_version": 1, "forwarders": [{"invalid": true}], "forwarders": []}')
		self.assertFalse(report["ok"], report)

	def test_gate_is_in_quick_full_and_release_without_engine_dependency(self) -> None:
		import gf_maintenance
		import gf_validation_catalog
		for suite in ("quick", "framework-static", "framework", "full", "release"):
			self.assertIn("diagnostic_policy", gf_maintenance.CHECK_SUITES[suite])
			self.assertIn("diagnostic_policy_tests", gf_maintenance.CHECK_SUITES[suite])
		self.assertEqual(gf_maintenance._VALIDATION_CATALOG.executor_kind("diagnostic_policy"), gf_validation_catalog.ValidationExecutorKind.IN_PROCESS)
		self.assertIn("diagnostic_policy", gf_maintenance.maintenance_in_process_adapter_registry())


if __name__ == "__main__":
	unittest.main()
