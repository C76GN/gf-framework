#!/usr/bin/env python3
"""Focused tests for fail-closed GF validation policy contracts."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
TOOLS_ROOT = ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
	sys.path.insert(0, str(TOOLS_ROOT))

import gf_validation_contracts as contracts


def _declared_policy(
	check_name: str = "api",
	**overrides: object,
) -> contracts.CheckValidationPolicy:
	values: dict[str, object] = {
		"check_name": check_name,
		"determinism": "deterministic",
		"input_closure": "complete",
		"reuse_scope": "never",
		"minimum_evidence_authority": "none",
		"implementation_epoch": 1,
		"declared": True,
	}
	values.update(overrides)
	return contracts.CheckValidationPolicy(**values)  # type: ignore[arg-type]


class CheckValidationPolicyTests(unittest.TestCase):
	def test_declared_policy_has_exact_versioned_json_shape(self) -> None:
		policy = _declared_policy()
		payload = policy.to_dict()
		self.assertEqual(
			payload,
			{
				"schema_version": contracts.VALIDATION_CONTRACT_SCHEMA_VERSION,
				"check_name": "api",
				"declared": True,
				"determinism": "deterministic",
				"input_closure": "complete",
				"reuse_scope": "never",
				"minimum_evidence_authority": "none",
				"implementation_epoch": 1,
			},
		)
		encoded = json.dumps(payload, allow_nan=False, sort_keys=True)
		self.assertEqual(
			contracts.CheckValidationPolicy.from_dict(json.loads(encoded)),
			policy,
		)

	def test_fail_closed_policy_is_the_only_valid_undeclared_shape(self) -> None:
		policy = contracts.CheckValidationPolicy.fail_closed("future_check")
		self.assertFalse(policy.declared)
		self.assertEqual(policy.determinism, "unknown")
		self.assertEqual(policy.input_closure, "unknown")
		self.assertEqual(policy.reuse_scope, "never")
		self.assertEqual(policy.minimum_evidence_authority, "none")
		self.assertEqual(policy.implementation_epoch, 0)
		with self.assertRaises(contracts.ValidationContractError):
			contracts.CheckValidationPolicy(
				check_name="future_check",
				determinism="deterministic",
				input_closure="unknown",
				reuse_scope="never",
				minimum_evidence_authority="none",
				implementation_epoch=0,
				declared=False,
			)

	def test_json_decoder_rejects_missing_extra_and_wrong_schema_fields(self) -> None:
		payload = _declared_policy().to_dict()
		for mutate in (
			lambda value: value.pop("input_closure"),
			lambda value: value.update({"unexpected": True}),
			lambda value: value.update({"schema_version": True}),
			lambda value: value.update({"schema_version": 2}),
		):
			with self.subTest(mutate=mutate):
				mutated = dict(payload)
				mutate(mutated)
				with self.assertRaises(contracts.ValidationContractError):
					contracts.CheckValidationPolicy.from_dict(mutated)
		with self.assertRaises(contracts.ValidationContractError):
			contracts.CheckValidationPolicy.from_dict([])  # type: ignore[arg-type]
		with self.assertRaises(contracts.ValidationContractError):
			contracts.CheckValidationPolicy.from_dict({1: "not a JSON field"})  # type: ignore[dict-item]

	def test_scalar_types_and_enum_values_are_strict(self) -> None:
		invalid_overrides = (
			{"declared": 1},
			{"implementation_epoch": True},
			{"implementation_epoch": 0},
			{"implementation_epoch": contracts.MAX_IMPLEMENTATION_EPOCH + 1},
			{"determinism": "sometimes"},
			{"input_closure": "probably"},
			{"reuse_scope": "global"},
			{"minimum_evidence_authority": "unsigned"},
		)
		for overrides in invalid_overrides:
			with self.subTest(overrides=overrides):
				with self.assertRaises(contracts.ValidationContractError):
					_declared_policy(**overrides)

	def test_check_names_are_bounded_snake_case(self) -> None:
		for check_name in (
			"",
			"API",
			"api-check",
			" api",
			"1_api",
			"a" * (contracts.MAX_CHECK_NAME_CHARACTERS + 1),
		):
			with self.subTest(check_name=check_name):
				with self.assertRaises(contracts.ValidationContractError):
					_declared_policy(check_name)

	def test_reuse_eligibility_relations_fail_closed(self) -> None:
		invalid_overrides = (
			{
				"reuse_scope": "same_invocation",
				"minimum_evidence_authority": "self_asserted",
				"determinism": "unknown",
			},
			{
				"reuse_scope": "same_validation_epoch",
				"minimum_evidence_authority": "self_asserted",
				"input_closure": "incomplete",
			},
			{
				"reuse_scope": "matching_action_key",
				"minimum_evidence_authority": "none",
			},
			{"reuse_scope": "never", "minimum_evidence_authority": "trusted_ci"},
		)
		for overrides in invalid_overrides:
			with self.subTest(overrides=overrides):
				with self.assertRaises(contracts.ValidationContractError):
					_declared_policy(**overrides)

	def test_well_formed_future_reuse_metadata_can_be_described_but_not_executed(self) -> None:
		policy = _declared_policy(
			reuse_scope="same_invocation",
			minimum_evidence_authority="self_asserted",
		)
		self.assertEqual(policy.reuse_scope, "same_invocation")
		self.assertFalse(hasattr(policy, "should_skip"))
		self.assertFalse(hasattr(policy, "load_evidence"))
		self.assertFalse(hasattr(policy, "save"))

	def test_pre_freeze_schema_v1_draft_fields_and_values_are_rejected(self) -> None:
		payload = _declared_policy().to_dict()
		legacy_field = dict(payload)
		legacy_field["evidence_trust"] = legacy_field.pop(
			"minimum_evidence_authority"
		)
		with self.assertRaises(contracts.ValidationContractError):
			contracts.CheckValidationPolicy.from_dict(legacy_field)
		for field_name, legacy_value in (
			("determinism", "environment_sensitive"),
			("input_closure", "declared"),
			("input_closure", "hermetic"),
			("reuse_scope", "local"),
			("reuse_scope", "trusted_ci"),
			("minimum_evidence_authority", "same_invocation"),
			("minimum_evidence_authority", "local"),
		):
			with self.subTest(field_name=field_name, legacy_value=legacy_value):
				legacy_payload = dict(payload)
				legacy_payload[field_name] = legacy_value
				with self.assertRaises(contracts.ValidationContractError):
					contracts.CheckValidationPolicy.from_dict(legacy_payload)


class ValidationPolicyCatalogTests(unittest.TestCase):
	def test_undeclared_and_new_checks_resolve_to_fail_closed_defaults(self) -> None:
		catalog = contracts.ValidationPolicyCatalog(
			["api", "gut"],
			[_declared_policy("api")],
		)
		self.assertTrue(catalog.is_declared("api"))
		self.assertFalse(catalog.is_declared("gut"))
		self.assertEqual(catalog.policy_for("api"), _declared_policy("api"))
		for check_name in ("gut", "new_check_added_later"):
			with self.subTest(check_name=check_name):
				policy = catalog.policy_for(check_name)
				self.assertFalse(policy.declared)
				self.assertEqual(policy.reuse_scope, "never")
				self.assertEqual(policy.minimum_evidence_authority, "none")

	def test_catalog_serialization_is_canonical_complete_and_round_trips(self) -> None:
		catalog = contracts.ValidationPolicyCatalog(
			["gut", "api"],
			[_declared_policy("api")],
		)
		payload = catalog.to_dict()
		self.assertEqual(payload["schema_version"], 1)
		self.assertEqual(payload["policy_count"], 2)
		self.assertEqual(payload["declared_policy_count"], 1)
		self.assertEqual(payload["defaulted_policy_count"], 1)
		self.assertEqual(
			[policy["check_name"] for policy in payload["policies"]],
			["api", "gut"],
		)
		encoded = json.dumps(payload, allow_nan=False, sort_keys=True)
		round_tripped = contracts.ValidationPolicyCatalog.from_dict(json.loads(encoded))
		self.assertEqual(round_tripped.to_dict(), payload)

	def test_catalog_rejects_unknown_duplicate_and_default_declarations(self) -> None:
		with self.assertRaises(contracts.ValidationContractError):
			contracts.ValidationPolicyCatalog(["api", "api"])
		with self.assertRaises(contracts.ValidationContractError):
			contracts.ValidationPolicyCatalog(["api"], [_declared_policy("gut")])
		with self.assertRaises(contracts.ValidationContractError):
			contracts.ValidationPolicyCatalog(
				["api"],
				[_declared_policy("api"), _declared_policy("api")],
			)
		with self.assertRaises(contracts.ValidationContractError):
			contracts.ValidationPolicyCatalog(
				["api"],
				[contracts.CheckValidationPolicy.fail_closed("api")],
			)
		with self.assertRaises(contracts.ValidationContractError):
			contracts.ValidationPolicyCatalog(
				(f"check_{index}" for index in range(contracts.MAX_POLICY_COUNT + 1))
			)

	def test_catalog_decoder_rejects_noncanonical_counts_order_and_defaults(self) -> None:
		payload = contracts.ValidationPolicyCatalog(
			["api", "gut"],
			[_declared_policy("api")],
		).to_dict()
		mutations = []
		wrong_count = dict(payload)
		wrong_count["policy_count"] = 3
		mutations.append(wrong_count)
		wrong_order = dict(payload)
		wrong_order["policies"] = list(reversed(payload["policies"]))
		mutations.append(wrong_order)
		wrong_default = dict(payload)
		wrong_default["policies"] = [dict(item) for item in payload["policies"]]
		wrong_default["policies"][1]["implementation_epoch"] = 1
		mutations.append(wrong_default)
		wrong_schema = dict(payload)
		wrong_schema["schema_version"] = 2
		mutations.append(wrong_schema)
		for mutated in mutations:
			with self.subTest(mutated=mutated):
				with self.assertRaises(contracts.ValidationContractError):
					contracts.ValidationPolicyCatalog.from_dict(mutated)


if __name__ == "__main__":
	unittest.main()
