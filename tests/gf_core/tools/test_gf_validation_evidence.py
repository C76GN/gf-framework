#!/usr/bin/env python3
"""Focused tests for fail-closed GF validation shadow evidence."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
TOOLS_ROOT = ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
	sys.path.insert(0, str(TOOLS_ROOT))

import gf_validation_evidence as evidence


DIGEST_A = "a" * 64
DIGEST_B = "b" * 64
DIGEST_C = "c" * 64
DIGEST_D = "d" * 64


def _material(
	*,
	action_name: str = "api",
	input_complete: bool = True,
	input_digests: dict[str, str] | None = None,
) -> evidence.ActionKeyMaterial:
	return evidence.ActionKeyMaterial(
		action_name=action_name,
		implementation_epoch=1,
		command=["python", "tools/generate_api_reference.py", "--check"],
		contract_digest=DIGEST_A,
		input_digests=input_digests or {
			"addons/gf": DIGEST_B,
			"tools/generate_api_reference.py": DIGEST_C,
		},
		dependency_artifact_digests={"generated_catalog": DIGEST_D},
		toolchain_digests={"python": DIGEST_A},
		environment_digests={"platform_contract": DIGEST_B},
		discovery_digest=DIGEST_C if input_complete else None,
		suite_membership_digest=DIGEST_D if input_complete else None,
		input_complete=input_complete,
		unknown_reasons=[] if input_complete else ["input_closure_unknown"],
	)


def _execution(
	material: evidence.ActionKeyMaterial,
	*,
	outcome: str = "passed",
	exit_code: int | None = 0,
	timed_out: bool = False,
	cancelled: bool = False,
	warning_count: int = 0,
	orphan_count: int = 0,
	leak_count: int = 0,
	quality_signals_complete: bool = True,
	structured_result_digest: str | None = DIGEST_B,
	result_fingerprint: str = DIGEST_A,
	invocation_id: str = "invocation-1",
	producer_identity: str = "local_cli",
	duration_seconds: float = 1.25,
	execution: str = "executed",
) -> evidence.ExecutionEvidence:
	return evidence.ExecutionEvidence(
		material,
		execution=execution,
		outcome=outcome,
		exit_code=exit_code,
		timed_out=timed_out,
		cancelled=cancelled,
		warning_count=warning_count,
		orphan_count=orphan_count,
		leak_count=leak_count,
		quality_signals_complete=quality_signals_complete,
		structured_result_digest=structured_result_digest,
		result_fingerprint=result_fingerprint,
		invocation_id=invocation_id,
		producer_identity=producer_identity,
		duration_seconds=duration_seconds,
	)


class CanonicalJsonTests(unittest.TestCase):
	def test_canonical_hash_is_stable_across_mapping_order(self) -> None:
		left = {"z": [2, 1], "a": {"second": True, "first": None}}
		right = {"a": {"first": None, "second": True}, "z": [2, 1]}
		self.assertEqual(
			evidence.canonical_json_bytes(left),
			b'{"a":{"first":null,"second":true},"z":[2,1]}',
		)
		self.assertEqual(
			evidence.canonical_json_sha256(left),
			evidence.canonical_json_sha256(right),
		)

	def test_non_finite_unsupported_cyclic_and_deep_values_fail_closed(self) -> None:
		for invalid in (float("nan"), float("inf"), float("-inf"), object()):
			with self.subTest(invalid=type(invalid).__name__):
				with self.assertRaises(evidence.ValidationEvidenceError):
					evidence.canonical_json_bytes({"value": invalid})
		cyclic: list[object] = []
		cyclic.append(cyclic)
		with self.assertRaisesRegex(evidence.ValidationEvidenceError, "cycle"):
			evidence.canonical_json_bytes(cyclic)
		deep: object = None
		for _index in range(evidence.MAX_CANONICAL_JSON_DEPTH + 1):
			deep = [deep]
		with self.assertRaisesRegex(evidence.ValidationEvidenceError, "depth"):
			evidence.canonical_json_bytes(deep)

	def test_json_budgets_and_key_types_are_enforced(self) -> None:
		with self.assertRaisesRegex(evidence.ValidationEvidenceError, "string-byte"):
			evidence.canonical_json_bytes({"value": "x" * (evidence.MAX_CANONICAL_JSON_STRING_BYTES + 1)})
		with self.assertRaisesRegex(evidence.ValidationEvidenceError, "collection-item"):
			evidence.canonical_json_bytes([None] * (evidence.MAX_COLLECTION_ITEMS + 1))
		with self.assertRaisesRegex(evidence.ValidationEvidenceError, "keys must be strings"):
			evidence.canonical_json_bytes({1: "value"})


class ActionKeyMaterialTests(unittest.TestCase):
	def test_material_has_an_explicit_schema_and_stable_action_key(self) -> None:
		first = _material(input_digests={"z": DIGEST_A, "a": DIGEST_B})
		second = _material(input_digests={"a": DIGEST_B, "z": DIGEST_A})
		self.assertEqual(first.action_key, second.action_key)
		self.assertEqual(first.to_dict()["schema_version"], 1)
		self.assertTrue(first.to_dict()["input_complete"])
		self.assertEqual(list(first.to_dict()["inputs"]), ["a", "z"])
		json.loads(evidence.canonical_json_bytes(first.to_dict()).decode("utf-8"))

	def test_every_material_dimension_changes_the_action_key(self) -> None:
		base = _material()
		base_kwargs = {
			"action_name": base.action_name,
			"implementation_epoch": base.implementation_epoch,
			"command": base.command,
			"contract_digest": base.contract_digest,
			"input_digests": dict(base.input_digests),
			"dependency_artifact_digests": dict(base.dependency_artifact_digests),
			"toolchain_digests": dict(base.toolchain_digests),
			"environment_digests": dict(base.environment_digests),
			"discovery_digest": base.discovery_digest,
			"suite_membership_digest": base.suite_membership_digest,
			"input_complete": True,
		}
		changes = {
			"action_name": "docs",
			"implementation_epoch": 2,
			"command": [*base.command, "--strict"],
			"contract_digest": DIGEST_D,
			"input_digests": {"addons/gf": DIGEST_D},
			"dependency_artifact_digests": {"generated_catalog": DIGEST_C},
			"toolchain_digests": {"python": DIGEST_D},
			"environment_digests": {"platform_contract": DIGEST_D},
			"discovery_digest": DIGEST_D,
			"suite_membership_digest": DIGEST_C,
		}
		for field_name, changed_value in changes.items():
			with self.subTest(field=field_name):
				changed = evidence.ActionKeyMaterial(
					**{**base_kwargs, field_name: changed_value}
				)
				self.assertNotEqual(base.action_key, changed.action_key)
		incomplete = evidence.ActionKeyMaterial(
			**{
				**base_kwargs,
				"input_complete": False,
				"unknown_reasons": ["synthetic_unknown"],
			}
		)
		self.assertNotEqual(base.action_key, incomplete.action_key)

	def test_complete_material_requires_discovery_and_suite_membership(self) -> None:
		with self.assertRaisesRegex(evidence.ValidationEvidenceError, "discovery"):
			evidence.ActionKeyMaterial(
				action_name="api",
				implementation_epoch=1,
				command=["python", "check.py"],
				contract_digest=DIGEST_A,
				input_digests={"source": DIGEST_B},
				input_complete=True,
			)

	def test_incomplete_material_is_explicit_and_never_hides_unknowns(self) -> None:
		material = evidence.ActionKeyMaterial(
			action_name="api",
			implementation_epoch=0,
			command=["python", "check.py"],
			contract_digest=DIGEST_A,
			input_digests={"workspace": DIGEST_B},
		)
		self.assertFalse(material.input_complete)
		self.assertEqual(material.implementation_epoch, 0)
		self.assertEqual(material.unknown_reasons, ("input_closure_incomplete",))
		with self.assertRaisesRegex(evidence.ValidationEvidenceError, "must be a list"):
			evidence.ActionKeyMaterial(
				action_name="api",
				implementation_epoch=0,
				command=["python", "check.py"],
				contract_digest=DIGEST_A,
				input_digests={"workspace": DIGEST_B},
				unknown_reasons={},
			)

	def test_digest_and_collection_budgets_fail_closed(self) -> None:
		with self.assertRaisesRegex(evidence.ValidationEvidenceError, "SHA-256"):
			_material(input_digests={"source": "A" * 64})
		with self.assertRaisesRegex(evidence.ValidationEvidenceError, "entry budget"):
			_material(input_digests={
				f"input-{index}": DIGEST_A
				for index in range(evidence.MAX_DIGEST_ENTRIES + 1)
			})


class ExecutionEvidenceTests(unittest.TestCase):
	def test_only_actual_clean_complete_execution_is_reusable_candidate(self) -> None:
		record = _execution(_material())
		self.assertEqual(record.execution, "executed")
		self.assertTrue(record.structurally_reusable_candidate)
		self.assertTrue(record.to_dict()["structurally_reusable_candidate"])
		self.assertEqual(record.evidence_authority, "self_asserted")
		self.assertEqual(record.producer_identity, "local_cli")
		self.assertEqual(len(record.evidence_fingerprint), 64)

	def test_failure_timeout_cancel_warning_orphan_and_leak_are_not_reusable(self) -> None:
		material = _material()
		unsafe_records = [
			_execution(material, outcome="failed", exit_code=1),
			_execution(material, outcome="failed", exit_code=None, timed_out=True),
			_execution(material, outcome="failed", exit_code=None, cancelled=True),
			_execution(material, warning_count=1),
			_execution(material, orphan_count=1),
			_execution(material, leak_count=1),
		]
		for record in unsafe_records:
			with self.subTest(result=record.semantic_result()):
				self.assertFalse(record.structurally_reusable_candidate)

	def test_incomplete_input_closure_is_not_reusable_even_after_a_clean_pass(self) -> None:
		record = _execution(_material(input_complete=False))
		self.assertFalse(record.structurally_reusable_candidate)

	def test_unknown_quality_signal_collection_is_not_treated_as_three_zeroes(self) -> None:
		record = _execution(
			_material(),
			warning_count=None,
			orphan_count=None,
			leak_count=None,
			quality_signals_complete=False,
		)
		self.assertFalse(record.structurally_reusable_candidate)
		self.assertFalse(record.semantic_result()["quality_signals_complete"])
		self.assertFalse(record.to_dict()["quality_signals_complete"])
		self.assertIsNone(record.to_dict()["warning_count"])

	def test_missing_structured_result_digest_is_not_a_candidate(self) -> None:
		record = _execution(_material(), structured_result_digest=None)
		self.assertFalse(record.structurally_reusable_candidate)

	def test_reused_evidence_is_forbidden_in_phase_one(self) -> None:
		with self.assertRaisesRegex(evidence.ValidationEvidenceError, "executed action"):
			_execution(_material(), execution="reused")

	def test_inconsistent_pass_and_non_finite_duration_are_rejected(self) -> None:
		with self.assertRaisesRegex(evidence.ValidationEvidenceError, "exit code zero"):
			_execution(_material(), exit_code=1)
		with self.assertRaisesRegex(evidence.ValidationEvidenceError, "duration_seconds"):
			_execution(_material(), duration_seconds=float("nan"))


class EvidenceConflictTests(unittest.TestCase):
	def test_semantically_equal_runs_ignore_run_specific_fingerprint_and_timing(self) -> None:
		material = _material()
		left = _execution(material)
		right = _execution(
			material,
			result_fingerprint=DIGEST_B,
			invocation_id="invocation-2",
			duration_seconds=9.5,
		)
		comparison = evidence.compare_evidence(left, right)
		self.assertEqual(comparison.relation, "equivalent")
		self.assertFalse(comparison.conflict)

	def test_same_action_key_with_different_structured_result_is_a_conflict(self) -> None:
		material = _material()
		comparison = evidence.compare_evidence(
			_execution(material),
			_execution(material, outcome="failed", exit_code=1),
		)
		self.assertEqual(comparison.relation, "conflict")
		self.assertTrue(comparison.conflict)

	def test_same_exit_status_with_different_structured_digest_is_a_conflict(self) -> None:
		material = _material()
		comparison = evidence.compare_evidence(
			_execution(material, structured_result_digest=DIGEST_A),
			_execution(material, structured_result_digest=DIGEST_B),
		)
		self.assertEqual(comparison.relation, "conflict")
		self.assertTrue(comparison.conflict)

	def test_missing_structured_digest_cannot_prove_two_runs_equivalent(self) -> None:
		material = _material()
		comparison = evidence.compare_evidence(
			_execution(material, structured_result_digest=None),
			_execution(material, structured_result_digest=None),
		)
		self.assertEqual(comparison.reason_code, "structured_result_unavailable")
		self.assertTrue(comparison.conflict)

	def test_different_action_keys_are_not_compared_as_a_conflict(self) -> None:
		comparison = evidence.compare_evidence(
			_execution(_material(action_name="api")),
			_execution(_material(action_name="docs")),
		)
		self.assertEqual(comparison.relation, "different_action_key")
		self.assertFalse(comparison.conflict)


class ShadowAcceptanceTests(unittest.TestCase):
	def test_clean_candidate_still_forces_execute_and_shadow_only(self) -> None:
		record = _execution(_material())
		decision = evidence.decide_shadow_acceptance(
			record.action_key,
			evidence=record,
		)
		self.assertEqual(decision.decision, "execute")
		self.assertEqual(decision.acceptance, "shadow_only")
		self.assertTrue(decision.structurally_reusable_candidate)
		self.assertEqual(
			decision.reason_code,
			"structurally_reusable_shadow_candidate",
		)

	def test_missing_unsafe_and_conflicting_evidence_all_force_execute(self) -> None:
		material = _material()
		failed = _execution(material, outcome="failed", exit_code=1)
		decisions = [
			evidence.decide_shadow_acceptance(material.action_key),
			evidence.decide_shadow_acceptance(material.action_key, evidence=failed),
			evidence.decide_shadow_acceptance(
				material.action_key,
				evidence=_execution(material),
				conflict_detected=True,
			),
		]
		self.assertEqual({decision.decision for decision in decisions}, {"execute"})
		self.assertEqual({decision.acceptance for decision in decisions}, {"shadow_only"})
		self.assertFalse(
			any(decision.structurally_reusable_candidate for decision in decisions)
		)

	def test_report_is_bounded_structured_and_never_reports_reuse(self) -> None:
		material = _material()
		record = _execution(material)
		report = evidence.build_shadow_evidence_report(material, [record])
		self.assertEqual(report["mode"], "shadow_only")
		self.assertEqual(report["execution_summary"], {"executed": 1, "reused": 0})
		self.assertEqual(report["acceptance_decision"]["decision"], "execute")
		self.assertFalse(report["conflict"]["detected"])
		self.assertEqual(len(report["report_fingerprint"]), 64)
		json.loads(evidence.canonical_json_bytes(report).decode("utf-8"))

	def test_report_detects_semantic_conflict_and_quarantines_candidate(self) -> None:
		material = _material()
		report = evidence.build_shadow_evidence_report(material, [
			_execution(material),
			_execution(material, outcome="failed", exit_code=1),
		])
		self.assertTrue(report["conflict"]["detected"])
		self.assertEqual(report["conflict"]["semantic_variant_count"], 2)
		self.assertEqual(
			report["acceptance_decision"]["reason_code"],
			"evidence_conflict",
		)
		self.assertFalse(
			report["acceptance_decision"]["structurally_reusable_candidate"]
		)

	def test_report_rejects_foreign_and_over_budget_evidence(self) -> None:
		material = _material()
		with self.assertRaisesRegex(evidence.ValidationEvidenceError, "does not match"):
			evidence.build_shadow_evidence_report(
				material,
				[_execution(_material(action_name="docs"))],
			)
		with self.assertRaisesRegex(evidence.ValidationEvidenceError, "record budget"):
			evidence.build_shadow_evidence_report(
				material,
				[_execution(material)] * (evidence.MAX_EVIDENCE_RECORDS + 1),
			)


if __name__ == "__main__":
	unittest.main()
