#!/usr/bin/env python3
"""Versioned, fail-closed validation policy contracts for GF maintenance."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from types import MappingProxyType
from typing import Any
from typing import Iterable
from typing import Mapping


VALIDATION_CONTRACT_SCHEMA_VERSION = 1
MAX_CHECK_NAME_CHARACTERS = 128
MAX_IMPLEMENTATION_EPOCH = 2**31 - 1
MAX_POLICY_COUNT = 4096

DETERMINISM_VALUES = frozenset({
	"unknown",
	"deterministic",
	"nondeterministic",
})
INPUT_CLOSURE_VALUES = frozenset({
	"unknown",
	"incomplete",
	"complete",
})
REUSE_SCOPE_VALUES = frozenset({
	"never",
	"same_invocation",
	"same_validation_epoch",
	"matching_action_key",
})
MINIMUM_EVIDENCE_AUTHORITY_VALUES = frozenset({
	"none",
	"self_asserted",
	"trusted_ci",
})

_CHECK_NAME_PATTERN = re.compile(r"^[a-z][a-z0-9_]*$")
_POLICY_FIELDS = frozenset({
	"schema_version",
	"check_name",
	"declared",
	"determinism",
	"input_closure",
	"reuse_scope",
	"minimum_evidence_authority",
	"implementation_epoch",
})
_CATALOG_FIELDS = frozenset({
	"schema_version",
	"policy_count",
	"declared_policy_count",
	"defaulted_policy_count",
	"policies",
})


class ValidationContractError(ValueError):
	"""Raised when validation policy metadata is malformed or unsafe."""


@dataclass(frozen=True)
class CheckValidationPolicy:
	"""Policy metadata for one maintenance check.

	This class records policy facts only. It deliberately has no API that skips a
	check, reads cached evidence, or persists results.
	"""

	check_name: str
	determinism: str
	input_closure: str
	reuse_scope: str
	minimum_evidence_authority: str
	implementation_epoch: int
	declared: bool = True

	def __post_init__(self) -> None:
		_validate_check_name(self.check_name)
		_validate_exact_string_choice(
			"determinism",
			self.determinism,
			DETERMINISM_VALUES,
		)
		_validate_exact_string_choice(
			"input_closure",
			self.input_closure,
			INPUT_CLOSURE_VALUES,
		)
		_validate_exact_string_choice(
			"reuse_scope",
			self.reuse_scope,
			REUSE_SCOPE_VALUES,
		)
		_validate_exact_string_choice(
			"minimum_evidence_authority",
			self.minimum_evidence_authority,
			MINIMUM_EVIDENCE_AUTHORITY_VALUES,
		)
		if type(self.declared) is not bool:
			raise ValidationContractError("declared must be a JSON boolean.")
		_validate_implementation_epoch(self.implementation_epoch, self.declared)
		_validate_policy_relationships(self)

	@classmethod
	def fail_closed(cls, check_name: str) -> CheckValidationPolicy:
		"""Return the only valid policy for an undeclared check."""
		return cls(
			check_name=check_name,
			determinism="unknown",
			input_closure="unknown",
			reuse_scope="never",
			minimum_evidence_authority="none",
			implementation_epoch=0,
			declared=False,
		)

	@classmethod
	def from_dict(cls, payload: Mapping[str, Any]) -> CheckValidationPolicy:
		"""Decode one exact schema-v1 JSON object or fail closed."""
		data = _validated_exact_object("validation policy", payload, _POLICY_FIELDS)
		_validate_schema_version(data["schema_version"], "validation policy")
		return cls(
			check_name=data["check_name"],
			determinism=data["determinism"],
			input_closure=data["input_closure"],
			reuse_scope=data["reuse_scope"],
			minimum_evidence_authority=data["minimum_evidence_authority"],
			implementation_epoch=data["implementation_epoch"],
			declared=data["declared"],
		)

	def to_dict(self) -> dict[str, Any]:
		"""Return an exact JSON-safe schema-v1 representation."""
		payload = {
			"schema_version": VALIDATION_CONTRACT_SCHEMA_VERSION,
			"check_name": self.check_name,
			"declared": self.declared,
			"determinism": self.determinism,
			"input_closure": self.input_closure,
			"reuse_scope": self.reuse_scope,
			"minimum_evidence_authority": self.minimum_evidence_authority,
			"implementation_epoch": self.implementation_epoch,
		}
		_assert_strict_json_safe(payload)
		return payload


class ValidationPolicyCatalog:
	"""Resolve explicit policy declarations over a closed set of known checks."""

	def __init__(
		self,
		check_names: Iterable[str],
		declared_policies: Iterable[CheckValidationPolicy] = (),
	) -> None:
		known_names: list[str] = []
		seen_names: set[str] = set()
		for check_name in check_names:
			if len(known_names) >= MAX_POLICY_COUNT:
				raise ValidationContractError(
					f"Validation policy catalogs are limited to {MAX_POLICY_COUNT} checks."
				)
			_validate_check_name(check_name)
			if check_name in seen_names:
				raise ValidationContractError(
					f"Duplicate known validation check name: {check_name}"
				)
			seen_names.add(check_name)
			known_names.append(check_name)

		policies: dict[str, CheckValidationPolicy] = {}
		for policy in declared_policies:
			if type(policy) is not CheckValidationPolicy:
				raise ValidationContractError(
					"declared_policies must contain CheckValidationPolicy values."
				)
			if not policy.declared:
				raise ValidationContractError(
					"Fail-closed defaults cannot be registered as declarations."
				)
			if policy.check_name not in seen_names:
				raise ValidationContractError(
					f"Validation policy declares an unknown check: {policy.check_name}"
				)
			if policy.check_name in policies:
				raise ValidationContractError(
					f"Duplicate validation policy declaration: {policy.check_name}"
				)
			policies[policy.check_name] = policy

		self._check_names = tuple(sorted(known_names))
		self._declared_policies: Mapping[str, CheckValidationPolicy] = MappingProxyType(
			dict(sorted(policies.items()))
		)

	@property
	def check_names(self) -> tuple[str, ...]:
		return self._check_names

	@property
	def declared_policy_count(self) -> int:
		return len(self._declared_policies)

	def is_declared(self, check_name: str) -> bool:
		_validate_check_name(check_name)
		return check_name in self._declared_policies

	def policy_for(self, check_name: str) -> CheckValidationPolicy:
		"""Resolve a declaration or return a non-reusable fail-closed default.

		A syntactically valid name that is absent from the catalog is also treated as
		undeclared. This keeps a newly added check from acquiring reuse eligibility
		before the catalog is updated.
		"""
		_validate_check_name(check_name)
		declared_policy = self._declared_policies.get(check_name)
		if declared_policy is not None:
			return declared_policy
		return CheckValidationPolicy.fail_closed(check_name)

	@classmethod
	def from_dict(cls, payload: Mapping[str, Any]) -> ValidationPolicyCatalog:
		"""Decode and verify a complete catalog report."""
		data = _validated_exact_object("validation policy catalog", payload, _CATALOG_FIELDS)
		_validate_schema_version(data["schema_version"], "validation policy catalog")
		for count_name in (
			"policy_count",
			"declared_policy_count",
			"defaulted_policy_count",
		):
			_validate_non_negative_integer(count_name, data[count_name])
		policies_data = data["policies"]
		if type(policies_data) is not list:
			raise ValidationContractError("policies must be a JSON array.")
		if len(policies_data) > MAX_POLICY_COUNT:
			raise ValidationContractError(
				f"Validation policy catalogs are limited to {MAX_POLICY_COUNT} checks."
			)
		policies = [CheckValidationPolicy.from_dict(item) for item in policies_data]
		catalog = cls(
			(policy.check_name for policy in policies),
			(policy for policy in policies if policy.declared),
		)
		if catalog.to_dict() != dict(data):
			raise ValidationContractError(
				"Validation policy catalog counts, ordering, or defaults are not canonical."
			)
		return catalog

	def to_dict(self) -> dict[str, Any]:
		"""Return every known check, making undeclared defaults visible."""
		policies = [self.policy_for(check_name).to_dict() for check_name in self._check_names]
		payload = {
			"schema_version": VALIDATION_CONTRACT_SCHEMA_VERSION,
			"policy_count": len(policies),
			"declared_policy_count": self.declared_policy_count,
			"defaulted_policy_count": len(policies) - self.declared_policy_count,
			"policies": policies,
		}
		_assert_strict_json_safe(payload)
		return payload


def _validate_check_name(check_name: Any) -> None:
	if type(check_name) is not str:
		raise ValidationContractError("check_name must be a JSON string.")
	if (
		not check_name
		or len(check_name) > MAX_CHECK_NAME_CHARACTERS
		or _CHECK_NAME_PATTERN.fullmatch(check_name) is None
	):
		raise ValidationContractError(
			"check_name must be a bounded lowercase snake_case identifier."
		)


def _validate_exact_string_choice(field_name: str, value: Any, allowed: frozenset[str]) -> None:
	if type(value) is not str or value not in allowed:
		raise ValidationContractError(
			f"{field_name} must be one of: {', '.join(sorted(allowed))}."
		)


def _validate_implementation_epoch(value: Any, declared: bool) -> None:
	_validate_non_negative_integer("implementation_epoch", value)
	if value > MAX_IMPLEMENTATION_EPOCH:
		raise ValidationContractError(
			f"implementation_epoch must not exceed {MAX_IMPLEMENTATION_EPOCH}."
		)
	if declared and value == 0:
		raise ValidationContractError(
			"Declared validation policies require a positive implementation_epoch."
		)
	if not declared and value != 0:
		raise ValidationContractError(
			"Undeclared validation policies must use implementation_epoch 0."
		)


def _validate_policy_relationships(policy: CheckValidationPolicy) -> None:
	if not policy.declared:
		fail_closed_values = (
			policy.determinism == "unknown"
			and policy.input_closure == "unknown"
			and policy.reuse_scope == "never"
			and policy.minimum_evidence_authority == "none"
		)
		if not fail_closed_values:
			raise ValidationContractError(
				"Undeclared checks must use the fail-closed unknown/never/none policy."
			)
		return
	if policy.reuse_scope == "never":
		if policy.minimum_evidence_authority != "none":
			raise ValidationContractError(
				"A never-reused check cannot accept reusable evidence."
			)
		return
	if policy.determinism != "deterministic":
		raise ValidationContractError(
			"Reusable checks must be declared deterministic."
		)
	if policy.input_closure != "complete":
		raise ValidationContractError(
			"Reusable checks must have a complete input closure."
		)
	if policy.minimum_evidence_authority == "none":
		raise ValidationContractError(
			"Reusable checks must declare a minimum evidence authority."
		)


def _validated_exact_object(
	label: str,
	payload: Mapping[str, Any],
	expected_fields: frozenset[str],
) -> Mapping[str, Any]:
	if type(payload) is not dict:
		raise ValidationContractError(f"{label} must be a JSON object.")
	if any(type(field_name) is not str for field_name in payload):
		raise ValidationContractError(f"{label} field names must be JSON strings.")
	actual_fields = frozenset(payload)
	if actual_fields != expected_fields:
		missing = sorted(expected_fields - actual_fields)
		extra = sorted(actual_fields - expected_fields)
		raise ValidationContractError(
			f"{label} fields must match schema v{VALIDATION_CONTRACT_SCHEMA_VERSION}; "
			f"missing={missing}, extra={extra}."
		)
	return payload


def _validate_schema_version(value: Any, label: str) -> None:
	if type(value) is not int or value != VALIDATION_CONTRACT_SCHEMA_VERSION:
		raise ValidationContractError(
			f"{label} schema_version must be the integer "
			f"{VALIDATION_CONTRACT_SCHEMA_VERSION}."
		)


def _validate_non_negative_integer(field_name: str, value: Any) -> None:
	if type(value) is not int or value < 0:
		raise ValidationContractError(
			f"{field_name} must be a non-negative JSON integer."
		)


def _assert_strict_json_safe(payload: Any) -> None:
	try:
		json.dumps(
			payload,
			allow_nan=False,
			ensure_ascii=False,
			sort_keys=True,
			separators=(",", ":"),
		)
	except (TypeError, ValueError) as error:
		raise ValidationContractError(
			"Validation contract payload is not strict JSON-safe."
		) from error


__all__ = [
	"CheckValidationPolicy",
	"DETERMINISM_VALUES",
	"INPUT_CLOSURE_VALUES",
	"MAX_CHECK_NAME_CHARACTERS",
	"MAX_IMPLEMENTATION_EPOCH",
	"MAX_POLICY_COUNT",
	"MINIMUM_EVIDENCE_AUTHORITY_VALUES",
	"REUSE_SCOPE_VALUES",
	"VALIDATION_CONTRACT_SCHEMA_VERSION",
	"ValidationContractError",
	"ValidationPolicyCatalog",
]
