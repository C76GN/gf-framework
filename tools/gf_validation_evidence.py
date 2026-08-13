#!/usr/bin/env python3
"""Bounded in-memory evidence records for GF validation shadow mode.

This module deliberately cannot skip validation or persist evidence.  It only
constructs content-addressed action material, records actual executions, and
reports only whether an execution meets structural conditions that a future
acceptance policy might evaluate.  The acceptance decision remains
fail-closed: execute in shadow-only mode.
"""

from __future__ import annotations

import hashlib
import json
import math
from dataclasses import dataclass
from typing import Any
from typing import Mapping
from typing import Sequence


ACTION_KEY_MATERIAL_SCHEMA_VERSION = 1
EXECUTION_EVIDENCE_SCHEMA_VERSION = 1
SHADOW_ACCEPTANCE_SCHEMA_VERSION = 1
SHADOW_REPORT_SCHEMA_VERSION = 1

ACTION_KEY_DOMAIN = b"gf-validation-action-key-v1\0"
EVIDENCE_FINGERPRINT_DOMAIN = b"gf-validation-evidence-v1\0"
SHADOW_REPORT_FINGERPRINT_DOMAIN = b"gf-validation-shadow-report-v1\0"

MAX_CANONICAL_JSON_DEPTH = 16
MAX_CANONICAL_JSON_NODES = 8192
MAX_CANONICAL_JSON_STRING_BYTES = 256 * 1024
MAX_CANONICAL_JSON_BYTES = 1024 * 1024
MAX_COLLECTION_ITEMS = 1024
MAX_MAPPING_ITEMS = 512
MAX_COMMAND_ARGUMENTS = 128
MAX_COMMAND_ARGUMENT_BYTES = 16 * 1024
MAX_IDENTIFIER_BYTES = 512
MAX_DIGEST_ENTRIES = 512
MAX_UNKNOWN_REASONS = 64
MAX_EVIDENCE_RECORDS = 64
MAX_COUNTER_VALUE = 1_000_000_000
MAX_DURATION_SECONDS = 7 * 24 * 60 * 60
MAX_IMPLEMENTATION_EPOCH = 2_147_483_647
MAX_JSON_INTEGER = 9_007_199_254_740_991

EXECUTION_EXECUTED = "executed"
DECISION_EXECUTE = "execute"
ACCEPTANCE_SHADOW_ONLY = "shadow_only"

OUTCOME_PASSED = "passed"
OUTCOME_FAILED = "failed"
OUTCOMES = frozenset({OUTCOME_PASSED, OUTCOME_FAILED})

EVIDENCE_AUTHORITY_SELF_ASSERTED = "self_asserted"

COMPARISON_EQUIVALENT = "equivalent"
COMPARISON_CONFLICT = "conflict"
COMPARISON_DIFFERENT_ACTION = "different_action_key"

_SHA256_HEX_LENGTH = 64
_HEX_DIGITS = frozenset("0123456789abcdef")


class ValidationEvidenceError(ValueError):
	"""Raised when validation evidence is incomplete, unsafe, or over budget."""


@dataclass
class _JsonBudget:
	nodes: int = 0
	string_bytes: int = 0

	def observe_node(self) -> None:
		self.nodes += 1
		if self.nodes > MAX_CANONICAL_JSON_NODES:
			raise ValidationEvidenceError("Canonical JSON node budget exceeded.")

	def observe_string(self, value: str) -> None:
		try:
			byte_count = len(value.encode("utf-8", errors="strict"))
		except UnicodeEncodeError as exc:
			raise ValidationEvidenceError("Canonical JSON contains invalid Unicode.") from exc
		self.string_bytes += byte_count
		if self.string_bytes > MAX_CANONICAL_JSON_STRING_BYTES:
			raise ValidationEvidenceError("Canonical JSON string-byte budget exceeded.")


def canonical_json_bytes(value: Any) -> bytes:
	"""Encode a bounded JSON value with deterministic ordering and finite numbers."""
	normalized = _normalize_json_value(
		value,
		budget=_JsonBudget(),
		depth=0,
		active_container_ids=set(),
	)
	try:
		payload = json.dumps(
			normalized,
			allow_nan=False,
			ensure_ascii=False,
			separators=(",", ":"),
			sort_keys=True,
		).encode("utf-8", errors="strict")
	except (TypeError, ValueError, UnicodeEncodeError) as exc:
		raise ValidationEvidenceError("Canonical JSON encoding failed.") from exc
	if len(payload) > MAX_CANONICAL_JSON_BYTES:
		raise ValidationEvidenceError("Canonical JSON encoded-byte budget exceeded.")
	return payload


def canonical_json_sha256(value: Any, *, domain: bytes = b"") -> str:
	"""Return a domain-separated SHA-256 digest for bounded canonical JSON."""
	if type(domain) is not bytes or len(domain) > MAX_IDENTIFIER_BYTES:
		raise ValidationEvidenceError("Canonical JSON hash domain is invalid.")
	digest = hashlib.sha256()
	digest.update(domain)
	digest.update(canonical_json_bytes(value))
	return digest.hexdigest()


def _normalize_json_value(
	value: Any,
	*,
	budget: _JsonBudget,
	depth: int,
	active_container_ids: set[int],
) -> Any:
	if depth > MAX_CANONICAL_JSON_DEPTH:
		raise ValidationEvidenceError("Canonical JSON depth budget exceeded.")
	budget.observe_node()
	if value is None or type(value) is bool:
		return value
	if type(value) is int:
		if abs(value) > MAX_JSON_INTEGER:
			raise ValidationEvidenceError("Canonical JSON integer is out of range.")
		return value
	if type(value) is float:
		if not math.isfinite(value):
			raise ValidationEvidenceError("Canonical JSON number must be finite.")
		return value
	if type(value) is str:
		budget.observe_string(value)
		return value
	if type(value) not in (dict, list, tuple):
		raise ValidationEvidenceError("Canonical JSON contains an unsupported value type.")
	container_id = id(value)
	if container_id in active_container_ids:
		raise ValidationEvidenceError("Canonical JSON contains a container cycle.")
	active_container_ids.add(container_id)
	try:
		if type(value) is dict:
			if len(value) > MAX_MAPPING_ITEMS:
				raise ValidationEvidenceError("Canonical JSON mapping-item budget exceeded.")
			normalized_mapping: dict[str, Any] = {}
			for key, nested_value in value.items():
				if type(key) is not str:
					raise ValidationEvidenceError("Canonical JSON mapping keys must be strings.")
				budget.observe_string(key)
				normalized_mapping[key] = _normalize_json_value(
					nested_value,
					budget=budget,
					depth=depth + 1,
					active_container_ids=active_container_ids,
				)
			return normalized_mapping
		if len(value) > MAX_COLLECTION_ITEMS:
			raise ValidationEvidenceError("Canonical JSON collection-item budget exceeded.")
		return [
			_normalize_json_value(
				item,
				budget=budget,
				depth=depth + 1,
				active_container_ids=active_container_ids,
			)
			for item in value
		]
	finally:
		active_container_ids.remove(container_id)


@dataclass(frozen=True, init=False)
class ActionKeyMaterial:
	"""Validated material used to identify one validation action."""

	action_name: str
	implementation_epoch: int
	command: tuple[str, ...]
	contract_digest: str
	input_digests: tuple[tuple[str, str], ...]
	dependency_artifact_digests: tuple[tuple[str, str], ...]
	toolchain_digests: tuple[tuple[str, str], ...]
	environment_digests: tuple[tuple[str, str], ...]
	discovery_digest: str | None
	suite_membership_digest: str | None
	input_complete: bool
	unknown_reasons: tuple[str, ...]

	def __init__(
		self,
		*,
		action_name: str,
		implementation_epoch: int,
		command: Sequence[str],
		contract_digest: str,
		input_digests: Mapping[str, str],
		dependency_artifact_digests: Mapping[str, str] | None = None,
		toolchain_digests: Mapping[str, str] | None = None,
		environment_digests: Mapping[str, str] | None = None,
		discovery_digest: str | None = None,
		suite_membership_digest: str | None = None,
		input_complete: bool = False,
		unknown_reasons: Sequence[str] | None = None,
	) -> None:
		validated_name = _validated_identifier("action_name", action_name)
		validated_epoch = _validated_bounded_integer(
			"implementation_epoch",
			implementation_epoch,
			minimum=0,
			maximum=MAX_IMPLEMENTATION_EPOCH,
		)
		validated_command = _validated_command(command)
		validated_contract_digest = _validated_sha256("contract_digest", contract_digest)
		validated_inputs = _validated_digest_mapping("input_digests", input_digests)
		validated_dependencies = _validated_digest_mapping(
			"dependency_artifact_digests",
			{} if dependency_artifact_digests is None else dependency_artifact_digests,
		)
		validated_toolchain = _validated_digest_mapping(
			"toolchain_digests",
			{} if toolchain_digests is None else toolchain_digests,
		)
		validated_environment = _validated_digest_mapping(
			"environment_digests",
			{} if environment_digests is None else environment_digests,
		)
		validated_discovery = (
			None
			if discovery_digest is None
			else _validated_sha256("discovery_digest", discovery_digest)
		)
		validated_suite_membership = (
			None
			if suite_membership_digest is None
			else _validated_sha256(
				"suite_membership_digest",
				suite_membership_digest,
			)
		)
		if type(input_complete) is not bool:
			raise ValidationEvidenceError("input_complete must be a boolean.")
		validated_unknown_reasons = _validated_unknown_reasons(
			() if unknown_reasons is None else unknown_reasons
		)
		if input_complete:
			if validated_epoch == 0:
				raise ValidationEvidenceError(
					"Complete action material requires a positive implementation epoch."
				)
			if validated_discovery is None or validated_suite_membership is None:
				raise ValidationEvidenceError(
					"Complete action material requires discovery and suite membership digests."
				)
			if validated_unknown_reasons:
				raise ValidationEvidenceError(
					"Complete action material cannot declare unknown input reasons."
				)
		elif not validated_unknown_reasons:
			validated_unknown_reasons = ("input_closure_incomplete",)
		object.__setattr__(self, "action_name", validated_name)
		object.__setattr__(self, "implementation_epoch", validated_epoch)
		object.__setattr__(self, "command", validated_command)
		object.__setattr__(self, "contract_digest", validated_contract_digest)
		object.__setattr__(self, "input_digests", validated_inputs)
		object.__setattr__(self, "dependency_artifact_digests", validated_dependencies)
		object.__setattr__(self, "toolchain_digests", validated_toolchain)
		object.__setattr__(self, "environment_digests", validated_environment)
		object.__setattr__(self, "discovery_digest", validated_discovery)
		object.__setattr__(self, "suite_membership_digest", validated_suite_membership)
		object.__setattr__(self, "input_complete", input_complete)
		object.__setattr__(self, "unknown_reasons", validated_unknown_reasons)
		canonical_json_bytes(self.to_dict())

	@property
	def action_key(self) -> str:
		return canonical_json_sha256(self.to_dict(), domain=ACTION_KEY_DOMAIN)

	def to_dict(self) -> dict[str, Any]:
		return {
			"schema_version": ACTION_KEY_MATERIAL_SCHEMA_VERSION,
			"action_name": self.action_name,
			"implementation_epoch": self.implementation_epoch,
			"command": list(self.command),
			"contract_digest": self.contract_digest,
			"inputs": dict(self.input_digests),
			"dependency_artifacts": dict(self.dependency_artifact_digests),
			"toolchain": dict(self.toolchain_digests),
			"environment": dict(self.environment_digests),
			"discovery_digest": self.discovery_digest,
			"suite_membership_digest": self.suite_membership_digest,
			"input_complete": self.input_complete,
			"unknown_reasons": list(self.unknown_reasons),
		}


def make_action_key_material(**kwargs: Any) -> ActionKeyMaterial:
	"""Construct validated ActionKey material without accepting free-form payloads."""
	return ActionKeyMaterial(**kwargs)


def action_key_for_material(material: ActionKeyMaterial) -> str:
	if not isinstance(material, ActionKeyMaterial):
		raise ValidationEvidenceError("Action key material has an invalid type.")
	return material.action_key


@dataclass(frozen=True, init=False)
class ExecutionEvidence:
	"""One actual execution observation; reused records are forbidden in phase one."""

	action_key: str
	action_name: str
	input_complete: bool
	execution: str
	outcome: str
	exit_code: int | None
	timed_out: bool
	cancelled: bool
	warning_count: int | None
	orphan_count: int | None
	leak_count: int | None
	quality_signals_complete: bool
	structured_result_digest: str | None
	result_fingerprint: str
	invocation_id: str
	evidence_authority: str
	producer_identity: str
	duration_seconds: float

	def __init__(
		self,
		material: ActionKeyMaterial,
		*,
		execution: str = EXECUTION_EXECUTED,
		outcome: str,
		exit_code: int | None,
		timed_out: bool,
		cancelled: bool,
		warning_count: int | None,
		orphan_count: int | None,
		leak_count: int | None,
		quality_signals_complete: bool,
		structured_result_digest: str | None,
		result_fingerprint: str,
		invocation_id: str,
		producer_identity: str,
		duration_seconds: float,
	) -> None:
		if not isinstance(material, ActionKeyMaterial):
			raise ValidationEvidenceError("Execution evidence requires ActionKey material.")
		if execution != EXECUTION_EXECUTED:
			raise ValidationEvidenceError(
				"Phase-one evidence must come from an executed action."
			)
		if type(outcome) is not str or outcome not in OUTCOMES:
			raise ValidationEvidenceError("Execution evidence outcome is invalid.")
		validated_exit_code = _validated_optional_exit_code(exit_code)
		if type(timed_out) is not bool or type(cancelled) is not bool:
			raise ValidationEvidenceError("Execution termination flags must be booleans.")
		if timed_out and cancelled:
			raise ValidationEvidenceError(
				"Execution evidence cannot be both timed out and cancelled."
			)
		if outcome == OUTCOME_PASSED and (
			validated_exit_code != 0 or timed_out or cancelled
		):
			raise ValidationEvidenceError(
				"Passed execution evidence requires exit code zero and normal completion."
			)
		validated_warning_count = _validated_optional_counter("warning_count", warning_count)
		validated_orphan_count = _validated_optional_counter("orphan_count", orphan_count)
		validated_leak_count = _validated_optional_counter("leak_count", leak_count)
		if type(quality_signals_complete) is not bool:
			raise ValidationEvidenceError(
				"quality_signals_complete must be a boolean."
			)
		if quality_signals_complete and None in (
			validated_warning_count,
			validated_orphan_count,
			validated_leak_count,
		):
			raise ValidationEvidenceError(
				"Complete quality signals require every quality counter."
			)
		validated_structured_result_digest = (
			None
			if structured_result_digest is None
			else _validated_sha256(
				"structured_result_digest",
				structured_result_digest,
			)
		)
		validated_result_fingerprint = _validated_sha256(
			"result_fingerprint",
			result_fingerprint,
		)
		validated_invocation_id = _validated_identifier("invocation_id", invocation_id)
		validated_producer_identity = _validated_identifier(
			"producer_identity",
			producer_identity,
		)
		validated_duration = _validated_duration(duration_seconds)
		object.__setattr__(self, "action_key", material.action_key)
		object.__setattr__(self, "action_name", material.action_name)
		object.__setattr__(self, "input_complete", material.input_complete)
		object.__setattr__(self, "execution", EXECUTION_EXECUTED)
		object.__setattr__(self, "outcome", outcome)
		object.__setattr__(self, "exit_code", validated_exit_code)
		object.__setattr__(self, "timed_out", timed_out)
		object.__setattr__(self, "cancelled", cancelled)
		object.__setattr__(self, "warning_count", validated_warning_count)
		object.__setattr__(self, "orphan_count", validated_orphan_count)
		object.__setattr__(self, "leak_count", validated_leak_count)
		object.__setattr__(self, "quality_signals_complete", quality_signals_complete)
		object.__setattr__(
			self,
			"structured_result_digest",
			validated_structured_result_digest,
		)
		object.__setattr__(self, "result_fingerprint", validated_result_fingerprint)
		object.__setattr__(self, "invocation_id", validated_invocation_id)
		# Phase one only records local/self-asserted observations. Trusted authority
		# must later come from a protected attestation verifier, never a constructor
		# argument or untrusted JSON field.
		object.__setattr__(
			self,
			"evidence_authority",
			EVIDENCE_AUTHORITY_SELF_ASSERTED,
		)
		object.__setattr__(self, "producer_identity", validated_producer_identity)
		object.__setattr__(self, "duration_seconds", validated_duration)
		canonical_json_bytes(self.to_dict())

	@property
	def structurally_reusable_candidate(self) -> bool:
		return (
			self.input_complete
			and self.execution == EXECUTION_EXECUTED
			and self.outcome == OUTCOME_PASSED
			and self.exit_code == 0
			and not self.timed_out
			and not self.cancelled
			and self.quality_signals_complete
			and self.structured_result_digest is not None
			and self.warning_count == 0
			and self.orphan_count == 0
			and self.leak_count == 0
		)

	@property
	def evidence_fingerprint(self) -> str:
		return canonical_json_sha256(
			self.to_dict(),
			domain=EVIDENCE_FINGERPRINT_DOMAIN,
		)

	def semantic_result(self) -> dict[str, Any]:
		"""Return result semantics while excluding run-specific metadata and logs."""
		return {
			"outcome": self.outcome,
			"exit_code": self.exit_code,
			"timed_out": self.timed_out,
			"cancelled": self.cancelled,
			"warning_count": self.warning_count,
			"orphan_count": self.orphan_count,
			"leak_count": self.leak_count,
			"quality_signals_complete": self.quality_signals_complete,
			"structured_result_digest": self.structured_result_digest,
			"structurally_reusable_candidate": self.structurally_reusable_candidate,
		}

	def to_dict(self) -> dict[str, Any]:
		return {
			"schema_version": EXECUTION_EVIDENCE_SCHEMA_VERSION,
			"action_key": self.action_key,
			"action_name": self.action_name,
			"input_complete": self.input_complete,
			"execution": self.execution,
			"outcome": self.outcome,
			"exit_code": self.exit_code,
			"timed_out": self.timed_out,
			"cancelled": self.cancelled,
			"warning_count": self.warning_count,
			"orphan_count": self.orphan_count,
			"leak_count": self.leak_count,
			"quality_signals_complete": self.quality_signals_complete,
			"structured_result_digest": self.structured_result_digest,
			"result_fingerprint": self.result_fingerprint,
			"invocation_id": self.invocation_id,
			"evidence_authority": self.evidence_authority,
			"producer_identity": self.producer_identity,
			"duration_seconds": self.duration_seconds,
			"structurally_reusable_candidate": self.structurally_reusable_candidate,
		}


def make_execution_evidence(
	material: ActionKeyMaterial,
	**kwargs: Any,
) -> ExecutionEvidence:
	"""Record one actual execution and derive structural eligibility only."""
	return ExecutionEvidence(material, **kwargs)


@dataclass(frozen=True)
class EvidenceComparison:
	"""Semantic comparison for two execution observations."""

	relation: str
	conflict: bool
	reason_code: str

	def to_dict(self) -> dict[str, Any]:
		return {
			"relation": self.relation,
			"conflict": self.conflict,
			"reason_code": self.reason_code,
		}


def compare_evidence(
	left: ExecutionEvidence,
	right: ExecutionEvidence,
) -> EvidenceComparison:
	"""Compare contract results while ignoring timing and run-specific metadata."""
	if not isinstance(left, ExecutionEvidence) or not isinstance(right, ExecutionEvidence):
		raise ValidationEvidenceError("Evidence comparison requires execution evidence.")
	if left.action_key != right.action_key:
		return EvidenceComparison(
			relation=COMPARISON_DIFFERENT_ACTION,
			conflict=False,
			reason_code="action_key_mismatch",
		)
	if left.structured_result_digest is None or right.structured_result_digest is None:
		return EvidenceComparison(
			relation=COMPARISON_CONFLICT,
			conflict=True,
			reason_code="structured_result_unavailable",
		)
	if left.action_name == right.action_name and left.semantic_result() == right.semantic_result():
		return EvidenceComparison(
			relation=COMPARISON_EQUIVALENT,
			conflict=False,
			reason_code="semantic_result_match",
		)
	return EvidenceComparison(
		relation=COMPARISON_CONFLICT,
		conflict=True,
		reason_code="semantic_result_conflict",
	)


@dataclass(frozen=True, init=False)
class AcceptanceDecision:
	"""A phase-one fail-closed decision that can never authorize a skip."""

	action_key: str
	decision: str
	acceptance: str
	reason_code: str
	structurally_reusable_candidate: bool
	conflict_detected: bool

	def __init__(
		self,
		*,
		action_key: str,
		reason_code: str,
		structurally_reusable_candidate: bool,
		conflict_detected: bool,
	) -> None:
		object.__setattr__(self, "action_key", _validated_sha256("action_key", action_key))
		object.__setattr__(self, "decision", DECISION_EXECUTE)
		object.__setattr__(self, "acceptance", ACCEPTANCE_SHADOW_ONLY)
		object.__setattr__(
			self,
			"reason_code",
			_validated_identifier("reason_code", reason_code),
		)
		if (
			type(structurally_reusable_candidate) is not bool
			or type(conflict_detected) is not bool
		):
			raise ValidationEvidenceError("Acceptance flags must be booleans.")
		if conflict_detected and structurally_reusable_candidate:
			raise ValidationEvidenceError(
				"Conflicting evidence cannot be a reusable candidate."
			)
		object.__setattr__(
			self,
			"structurally_reusable_candidate",
			structurally_reusable_candidate,
		)
		object.__setattr__(self, "conflict_detected", conflict_detected)

	def to_dict(self) -> dict[str, Any]:
		return {
			"schema_version": SHADOW_ACCEPTANCE_SCHEMA_VERSION,
			"action_key": self.action_key,
			"decision": self.decision,
			"acceptance": self.acceptance,
			"reason_code": self.reason_code,
			"structurally_reusable_candidate": self.structurally_reusable_candidate,
			"conflict_detected": self.conflict_detected,
		}


def decide_shadow_acceptance(
	action_key: str,
	*,
	evidence: ExecutionEvidence | None = None,
	conflict_detected: bool = False,
) -> AcceptanceDecision:
	"""Always execute; evidence can only be observed as a shadow candidate."""
	validated_action_key = _validated_sha256("action_key", action_key)
	if type(conflict_detected) is not bool:
		raise ValidationEvidenceError("conflict_detected must be a boolean.")
	if evidence is not None:
		if not isinstance(evidence, ExecutionEvidence):
			raise ValidationEvidenceError("Acceptance candidate has an invalid type.")
		if evidence.action_key != validated_action_key:
			raise ValidationEvidenceError("Acceptance evidence action key does not match.")
	if conflict_detected:
		reason_code = "evidence_conflict"
		structurally_reusable_candidate = False
	elif evidence is None:
		reason_code = "no_evidence"
		structurally_reusable_candidate = False
	elif not evidence.input_complete:
		reason_code = "input_closure_incomplete"
		structurally_reusable_candidate = False
	elif evidence.structurally_reusable_candidate:
		reason_code = "structurally_reusable_shadow_candidate"
		structurally_reusable_candidate = True
	else:
		reason_code = "evidence_not_reusable"
		structurally_reusable_candidate = False
	return AcceptanceDecision(
		action_key=validated_action_key,
		reason_code=reason_code,
		structurally_reusable_candidate=structurally_reusable_candidate,
		conflict_detected=conflict_detected,
	)


def build_shadow_evidence_report(
	material: ActionKeyMaterial,
	evidence_records: Sequence[ExecutionEvidence],
) -> dict[str, Any]:
	"""Build a bounded report without persisting evidence or changing execution."""
	if not isinstance(material, ActionKeyMaterial):
		raise ValidationEvidenceError("Shadow report requires ActionKey material.")
	if type(evidence_records) not in (list, tuple):
		raise ValidationEvidenceError("Shadow report evidence must be a list or tuple.")
	if len(evidence_records) > MAX_EVIDENCE_RECORDS:
		raise ValidationEvidenceError("Shadow report evidence-record budget exceeded.")
	validated_records: list[ExecutionEvidence] = []
	for record in evidence_records:
		if not isinstance(record, ExecutionEvidence):
			raise ValidationEvidenceError("Shadow report contains invalid evidence.")
		if record.action_key != material.action_key:
			raise ValidationEvidenceError("Shadow report evidence action key does not match.")
		validated_records.append(record)
	semantic_variants_by_digest: dict[str, dict[str, Any]] = {}
	for record in validated_records:
		semantic_result = record.semantic_result()
		semantic_variants_by_digest.setdefault(
			canonical_json_sha256(semantic_result),
			semantic_result,
		)
	semantic_variants = [
		semantic_variants_by_digest[digest]
		for digest in sorted(semantic_variants_by_digest)
	]
	comparison_complete = all(
		record.structured_result_digest is not None
		for record in validated_records
	)
	conflict_detected = (
		len(semantic_variants) > 1
		or (len(validated_records) > 1 and not comparison_complete)
	)
	candidate = validated_records[-1] if validated_records else None
	acceptance = decide_shadow_acceptance(
		material.action_key,
		evidence=candidate,
		conflict_detected=conflict_detected,
	)
	payload: dict[str, Any] = {
		"schema_version": SHADOW_REPORT_SCHEMA_VERSION,
		"mode": ACCEPTANCE_SHADOW_ONLY,
		"action_key": material.action_key,
		"action_key_material": material.to_dict(),
		"execution_summary": {
			"executed": len(validated_records),
			"reused": 0,
		},
		"evidence": [record.to_dict() for record in validated_records],
		"conflict": {
			"detected": conflict_detected,
			"comparison_complete": comparison_complete,
			"semantic_variant_count": len(semantic_variants),
			"semantic_variants": semantic_variants,
		},
		"acceptance_decision": acceptance.to_dict(),
	}
	payload["report_fingerprint"] = canonical_json_sha256(
		payload,
		domain=SHADOW_REPORT_FINGERPRINT_DOMAIN,
	)
	canonical_json_bytes(payload)
	return payload


def _validated_command(command: Sequence[str]) -> tuple[str, ...]:
	if type(command) not in (list, tuple):
		raise ValidationEvidenceError("command must be a list or tuple.")
	if not command or len(command) > MAX_COMMAND_ARGUMENTS:
		raise ValidationEvidenceError("command argument count is invalid.")
	validated: list[str] = []
	for argument in command:
		if type(argument) is not str or "\0" in argument:
			raise ValidationEvidenceError("command contains an invalid argument.")
		try:
			byte_count = len(argument.encode("utf-8", errors="strict"))
		except UnicodeEncodeError as exc:
			raise ValidationEvidenceError("command contains invalid Unicode.") from exc
		if byte_count > MAX_COMMAND_ARGUMENT_BYTES:
			raise ValidationEvidenceError("command argument byte budget exceeded.")
		validated.append(argument)
	return tuple(validated)


def _validated_digest_mapping(
	field_name: str,
	values: Mapping[str, str],
) -> tuple[tuple[str, str], ...]:
	if not isinstance(values, Mapping):
		raise ValidationEvidenceError(f"{field_name} must be a mapping.")
	if len(values) > MAX_DIGEST_ENTRIES:
		raise ValidationEvidenceError(f"{field_name} entry budget exceeded.")
	validated: list[tuple[str, str]] = []
	for label, digest in values.items():
		validated.append((
			_validated_identifier(f"{field_name} label", label),
			_validated_sha256(f"{field_name} digest", digest),
		))
	validated.sort(key=lambda item: item[0])
	return tuple(validated)


def _validated_unknown_reasons(reasons: Sequence[str]) -> tuple[str, ...]:
	if type(reasons) not in (list, tuple):
		raise ValidationEvidenceError("unknown_reasons must be a list or tuple.")
	if len(reasons) > MAX_UNKNOWN_REASONS:
		raise ValidationEvidenceError("unknown_reasons entry budget exceeded.")
	validated = tuple(_validated_identifier("unknown reason", reason) for reason in reasons)
	if len(set(validated)) != len(validated):
		raise ValidationEvidenceError("unknown_reasons contains duplicates.")
	return tuple(sorted(validated))


def _validated_identifier(field_name: str, value: str) -> str:
	if type(value) is not str or not value or value != value.strip() or "\0" in value:
		raise ValidationEvidenceError(f"{field_name} must be a canonical non-empty string.")
	if any(ord(character) < 0x20 or ord(character) == 0x7F for character in value):
		raise ValidationEvidenceError(f"{field_name} contains a control character.")
	try:
		byte_count = len(value.encode("utf-8", errors="strict"))
	except UnicodeEncodeError as exc:
		raise ValidationEvidenceError(f"{field_name} contains invalid Unicode.") from exc
	if byte_count > MAX_IDENTIFIER_BYTES:
		raise ValidationEvidenceError(f"{field_name} byte budget exceeded.")
	return value


def _validated_sha256(field_name: str, value: str) -> str:
	if (
		type(value) is not str
		or len(value) != _SHA256_HEX_LENGTH
		or any(character not in _HEX_DIGITS for character in value)
	):
		raise ValidationEvidenceError(f"{field_name} must be a lowercase SHA-256 digest.")
	return value


def _validated_bounded_integer(
	field_name: str,
	value: int,
	*,
	minimum: int,
	maximum: int,
) -> int:
	if type(value) is not int or value < minimum or value > maximum:
		raise ValidationEvidenceError(f"{field_name} is out of range.")
	return value


def _validated_optional_exit_code(value: int | None) -> int | None:
	if value is None:
		return None
	return _validated_bounded_integer(
		"exit_code",
		value,
		minimum=-2_147_483_648,
		maximum=2_147_483_647,
	)


def _validated_counter(field_name: str, value: int) -> int:
	return _validated_bounded_integer(
		field_name,
		value,
		minimum=0,
		maximum=MAX_COUNTER_VALUE,
	)


def _validated_optional_counter(field_name: str, value: int | None) -> int | None:
	if value is None:
		return None
	return _validated_counter(field_name, value)


def _validated_duration(value: float) -> float:
	if type(value) not in (int, float):
		raise ValidationEvidenceError("duration_seconds must be a finite number.")
	duration = float(value)
	if not math.isfinite(duration) or duration < 0.0 or duration > MAX_DURATION_SECONDS:
		raise ValidationEvidenceError("duration_seconds is out of range.")
	return duration
