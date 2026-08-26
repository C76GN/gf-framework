#!/usr/bin/env python3
"""Versioned, fail-closed validation policy contracts for GF maintenance."""

from __future__ import annotations

import hashlib
import json
import re
import unicodedata
from dataclasses import dataclass
from pathlib import PurePosixPath
from types import MappingProxyType
from typing import Any
from typing import Iterable
from typing import Mapping


VALIDATION_CONTRACT_SCHEMA_VERSION = 1
INPUT_SPEC_SCHEMA_VERSION = 1
MAX_CHECK_NAME_CHARACTERS = 128
MAX_ARTIFACT_NAME_CHARACTERS = 128
MAX_IMPLEMENTATION_EPOCH = 2**31 - 1
MAX_POLICY_COUNT = 4096

PATH_RULE_KINDS = frozenset({"exact", "tree"})
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
_ARTIFACT_NAME_PATTERN = re.compile(r"^[a-z][a-z0-9_.-]*$")
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
_PATH_RULE_FIELDS = frozenset({
	"schema_version",
	"kind",
	"path",
	"suffixes",
	"excluded_prefixes",
})
_INPUT_SPEC_FIELDS = frozenset({
	"schema_version",
	"check_name",
	"source_rules",
	"implementation_files",
	"consumed_artifacts",
})
_WINDOWS_FORBIDDEN_CHARACTERS = frozenset('<>:"|?*')
_WINDOWS_RESERVED_NAMES = frozenset({
	"CON",
	"PRN",
	"AUX",
	"NUL",
	*(f"COM{index}" for index in range(1, 10)),
	*(f"LPT{index}" for index in range(1, 10)),
})


class ValidationContractError(ValueError):
	"""Raised when validation policy metadata is malformed or unsafe."""


class ValidationInputError(RuntimeError):
	"""Base error for strict validation-input contracts."""


class ValidationInputContractError(ValidationInputError):
	"""Raised when validation input schemas, paths, or declarations are invalid."""


@dataclass(frozen=True)
class PathRule:
	"""One exact-file or recursive-tree source selector."""

	kind: str
	path: str
	suffixes: tuple[str, ...] = ()
	excluded_prefixes: tuple[str, ...] = ()

	def __post_init__(self) -> None:
		if type(self.kind) is not str or self.kind not in PATH_RULE_KINDS:
			raise ValidationInputContractError(
				"validation_inputs.path_rule_kind_invalid"
			)
		_validate_portable_relative_path(self.path)
		if type(self.suffixes) is not tuple:
			raise ValidationInputContractError(
				"validation_inputs.path_rule_suffixes_not_tuple"
			)
		if type(self.excluded_prefixes) is not tuple:
			raise ValidationInputContractError(
				"validation_inputs.path_rule_exclusions_not_tuple"
			)
		for suffix in self.suffixes:
			_validate_suffix(suffix)
		for prefix in self.excluded_prefixes:
			_validate_portable_relative_path(prefix)
			if not _is_strict_child_path(prefix, self.path):
				raise ValidationInputContractError(
					"validation_inputs.path_rule_exclusion_outside_tree"
				)
		if self.kind == "exact" and (self.suffixes or self.excluded_prefixes):
			raise ValidationInputContractError(
				"validation_inputs.exact_rule_has_tree_options"
			)
		if len(set(self.suffixes)) != len(self.suffixes):
			raise ValidationInputContractError(
				"validation_inputs.path_rule_duplicate_suffix"
			)
		if len(set(self.excluded_prefixes)) != len(self.excluded_prefixes):
			raise ValidationInputContractError(
				"validation_inputs.path_rule_duplicate_exclusion"
			)
		if tuple(sorted(self.suffixes, key=_portable_sort_key)) != self.suffixes:
			raise ValidationInputContractError(
				"validation_inputs.path_rule_suffixes_not_canonical"
			)
		if (
			tuple(sorted(self.excluded_prefixes, key=_portable_sort_key))
			!= self.excluded_prefixes
		):
			raise ValidationInputContractError(
				"validation_inputs.path_rule_exclusions_not_canonical"
			)
		for index, prefix in enumerate(self.excluded_prefixes):
			if any(
				_is_same_or_child_path(prefix, earlier)
				for earlier in self.excluded_prefixes[:index]
			):
				raise ValidationInputContractError(
					"validation_inputs.path_rule_redundant_exclusion"
				)

	@classmethod
	def from_dict(cls, payload: Mapping[str, Any]) -> PathRule:
		data = _validated_input_exact_object("path rule", payload, _PATH_RULE_FIELDS)
		_validate_input_schema_version(data["schema_version"], "path rule")
		return cls(
			kind=data["kind"],
			path=data["path"],
			suffixes=_validated_input_string_tuple("suffixes", data["suffixes"]),
			excluded_prefixes=_validated_input_string_tuple(
				"excluded_prefixes",
				data["excluded_prefixes"],
			),
		)

	def to_dict(self) -> dict[str, Any]:
		return {
			"schema_version": INPUT_SPEC_SCHEMA_VERSION,
			"kind": self.kind,
			"path": self.path,
			"suffixes": list(self.suffixes),
			"excluded_prefixes": list(self.excluded_prefixes),
		}

	def matches(self, logical_path: str) -> bool:
		_validate_portable_relative_path(logical_path)
		if self.kind == "exact":
			return logical_path == self.path
		if not _is_same_or_child_path(logical_path, self.path):
			return False
		if any(
			_is_same_or_child_path(logical_path, prefix)
			for prefix in self.excluded_prefixes
		):
			return False
		if logical_path == self.path or not self.suffixes:
			return True
		return PurePosixPath(logical_path).suffix.casefold() in {
			suffix.casefold() for suffix in self.suffixes
		}


@dataclass(frozen=True)
class CheckInputSpec:
	"""Explicit candidate input declaration for one maintenance check."""

	check_name: str
	source_rules: tuple[PathRule, ...]
	implementation_files: tuple[str, ...]
	consumed_artifacts: tuple[str, ...] = ()

	def __post_init__(self) -> None:
		_validate_input_check_name(self.check_name)
		if type(self.source_rules) is not tuple or not self.source_rules:
			raise ValidationInputContractError(
				"validation_inputs.source_rules_required"
			)
		if any(type(rule) is not PathRule for rule in self.source_rules):
			raise ValidationInputContractError(
				"validation_inputs.source_rule_type_invalid"
			)
		if type(self.implementation_files) is not tuple or not self.implementation_files:
			raise ValidationInputContractError(
				"validation_inputs.implementation_files_required"
			)
		if type(self.consumed_artifacts) is not tuple:
			raise ValidationInputContractError(
				"validation_inputs.consumed_artifacts_not_tuple"
			)
		for path in self.implementation_files:
			_validate_portable_relative_path(path)
		for artifact_name in self.consumed_artifacts:
			_validate_artifact_name(artifact_name)
		rule_keys = [
			(rule.kind, rule.path, rule.suffixes, rule.excluded_prefixes)
			for rule in self.source_rules
		]
		if len(set(rule_keys)) != len(rule_keys):
			raise ValidationInputContractError(
				"validation_inputs.duplicate_source_rule"
			)
		for field_name, values in (
			("implementation_files", self.implementation_files),
			("consumed_artifacts", self.consumed_artifacts),
		):
			if len(set(values)) != len(values):
				raise ValidationInputContractError(
					f"validation_inputs.duplicate_{field_name}"
				)
			if tuple(sorted(values, key=_portable_sort_key)) != values:
				raise ValidationInputContractError(
					f"validation_inputs.{field_name}_not_canonical"
				)
		if tuple(sorted(self.source_rules, key=_path_rule_sort_key)) != self.source_rules:
			raise ValidationInputContractError(
				"validation_inputs.source_rules_not_canonical"
			)

	@classmethod
	def from_dict(cls, payload: Mapping[str, Any]) -> CheckInputSpec:
		data = _validated_input_exact_object("input spec", payload, _INPUT_SPEC_FIELDS)
		_validate_input_schema_version(data["schema_version"], "input spec")
		if type(data["source_rules"]) is not list:
			raise ValidationInputContractError(
				"validation_inputs.source_rules_not_array"
			)
		return cls(
			check_name=data["check_name"],
			source_rules=tuple(
				PathRule.from_dict(rule) for rule in data["source_rules"]
			),
			implementation_files=_validated_input_string_tuple(
				"implementation_files",
				data["implementation_files"],
			),
			consumed_artifacts=_validated_input_string_tuple(
				"consumed_artifacts",
				data["consumed_artifacts"],
			),
		)

	def to_dict(self) -> dict[str, Any]:
		return {
			"schema_version": INPUT_SPEC_SCHEMA_VERSION,
			"check_name": self.check_name,
			"source_rules": [rule.to_dict() for rule in self.source_rules],
			"implementation_files": list(self.implementation_files),
			"consumed_artifacts": list(self.consumed_artifacts),
		}

	@property
	def digest(self) -> str:
		return _stable_input_digest(
			b"gf-validation-input-spec-v1\0",
			self.to_dict(),
		)

	def matches_source_path(self, logical_path: str) -> bool:
		return any(rule.matches(logical_path) for rule in self.source_rules)

	def matches_implementation_path(self, logical_path: str) -> bool:
		_validate_portable_relative_path(logical_path)
		return logical_path in self.implementation_files

	def git_pathspecs(self) -> tuple[str, ...]:
		paths = {
			*(rule.path for rule in self.source_rules),
			*self.implementation_files,
		}
		return tuple(sorted(paths, key=_portable_sort_key))


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


def _validate_input_check_name(check_name: Any) -> None:
	if (
		type(check_name) is not str
		or not check_name
		or len(check_name) > MAX_CHECK_NAME_CHARACTERS
		or _CHECK_NAME_PATTERN.fullmatch(check_name) is None
	):
		raise ValidationInputContractError(
			"validation_inputs.check_name_invalid"
		)


def _validate_artifact_name(name: Any) -> None:
	if (
		type(name) is not str
		or not name
		or len(name) > MAX_ARTIFACT_NAME_CHARACTERS
		or _ARTIFACT_NAME_PATTERN.fullmatch(name) is None
	):
		raise ValidationInputContractError(
			"validation_inputs.artifact_name_invalid"
		)


def _validate_portable_relative_path(value: Any) -> None:
	if (
		type(value) is not str
		or not value
		or value.startswith("/")
		or value.endswith("/")
		or "\\" in value
		or "\0" in value
		or unicodedata.normalize("NFC", value) != value
	):
		raise ValidationInputContractError(
			"validation_inputs.path_not_canonical"
		)
	for segment in value.split("/"):
		_validate_path_segment(segment)


def _validate_path_segment(segment: str) -> None:
	if not segment or segment in {".", ".."}:
		raise ValidationInputContractError(
			"validation_inputs.path_segment_invalid"
		)
	try:
		segment_bytes = segment.encode("utf-8", errors="strict")
	except UnicodeEncodeError as error:
		raise ValidationInputContractError(
			"validation_inputs.path_not_utf8"
		) from error
	if len(segment_bytes) > 255:
		raise ValidationInputContractError(
			"validation_inputs.path_segment_too_long"
		)
	if any(ord(character) < 32 or ord(character) == 127 for character in segment):
		raise ValidationInputContractError(
			"validation_inputs.path_control_character"
		)
	if any(character in _WINDOWS_FORBIDDEN_CHARACTERS for character in segment):
		raise ValidationInputContractError(
			"validation_inputs.path_not_portable"
		)
	if segment.endswith((" ", ".")):
		raise ValidationInputContractError(
			"validation_inputs.path_not_portable"
		)
	if segment.split(".", 1)[0].upper() in _WINDOWS_RESERVED_NAMES:
		raise ValidationInputContractError(
			"validation_inputs.path_not_portable"
		)


def _validate_suffix(suffix: Any) -> None:
	if (
		type(suffix) is not str
		or len(suffix) < 2
		or not suffix.startswith(".")
		or suffix != suffix.casefold()
		or "/" in suffix
		or "\\" in suffix
		or any(
			not (character.isalnum() or character in {".", "_", "-"})
			for character in suffix
		)
	):
		raise ValidationInputContractError(
			"validation_inputs.suffix_invalid"
		)


def _path_rule_sort_key(rule: PathRule) -> tuple[Any, ...]:
	return (
		_portable_sort_key(rule.path),
		rule.kind,
		rule.suffixes,
		rule.excluded_prefixes,
	)


def _portable_sort_key(value: str) -> tuple[str, bytes]:
	return (
		unicodedata.normalize("NFC", value).casefold(),
		value.encode("utf-8", errors="strict"),
	)


def _is_same_or_child_path(path: str, parent: str) -> bool:
	return path == parent or path.startswith(f"{parent}/")


def _is_strict_child_path(path: str, parent: str) -> bool:
	return path.startswith(f"{parent}/")


def _stable_input_digest(domain: bytes, payload: Any) -> str:
	try:
		encoded = json.dumps(
			payload,
			allow_nan=False,
			ensure_ascii=False,
			sort_keys=True,
			separators=(",", ":"),
		).encode("utf-8", errors="strict")
	except (TypeError, ValueError, UnicodeError) as error:
		raise ValidationInputContractError(
			"validation_inputs.payload_not_strict_json"
		) from error
	return hashlib.sha256(domain + encoded).hexdigest()


def _validated_input_exact_object(
	label: str,
	payload: Mapping[str, Any],
	expected_fields: frozenset[str],
) -> Mapping[str, Any]:
	if type(payload) is not dict:
		raise ValidationInputContractError(
			f"validation_inputs.{label.replace(' ', '_')}_not_object"
		)
	if frozenset(payload) != expected_fields:
		raise ValidationInputContractError(
			f"validation_inputs.{label.replace(' ', '_')}_fields_invalid"
		)
	return payload


def _validated_input_string_tuple(field_name: str, value: Any) -> tuple[str, ...]:
	if type(value) is not list or any(type(item) is not str for item in value):
		raise ValidationInputContractError(
			f"validation_inputs.{field_name}_not_string_array"
		)
	return tuple(value)


def _validate_input_schema_version(value: Any, label: str) -> None:
	if type(value) is not int or value != INPUT_SPEC_SCHEMA_VERSION:
		raise ValidationInputContractError(
			f"validation_inputs.{label.replace(' ', '_')}_schema_invalid"
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
	"CheckInputSpec",
	"CheckValidationPolicy",
	"DETERMINISM_VALUES",
	"INPUT_SPEC_SCHEMA_VERSION",
	"INPUT_CLOSURE_VALUES",
	"MAX_ARTIFACT_NAME_CHARACTERS",
	"MAX_CHECK_NAME_CHARACTERS",
	"MAX_IMPLEMENTATION_EPOCH",
	"MAX_POLICY_COUNT",
	"MINIMUM_EVIDENCE_AUTHORITY_VALUES",
	"PATH_RULE_KINDS",
	"PathRule",
	"REUSE_SCOPE_VALUES",
	"VALIDATION_CONTRACT_SCHEMA_VERSION",
	"ValidationContractError",
	"ValidationInputContractError",
	"ValidationInputError",
	"ValidationPolicyCatalog",
]
