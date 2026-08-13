#!/usr/bin/env python3
"""Strict, read-only input identity and affected-check diagnostics for GF.

This module is deliberately advisory.  It can describe changed inputs and freeze
content identities for a candidate Action Key, but it has no API for filtering a
check plan, reading evidence, caching results, or skipping execution.
"""

from __future__ import annotations

import hashlib
import json
import math
import os
import re
import stat
import subprocess
import time
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from pathlib import PurePosixPath
from types import MappingProxyType
from typing import Any
from typing import Callable
from typing import Iterable
from typing import Mapping


INPUT_SPEC_SCHEMA_VERSION = 1
FROZEN_ACTION_INPUTS_SCHEMA_VERSION = 1
AFFECTED_ANALYSIS_SCHEMA_VERSION = 1
FILE_ATTRIBUTE_REPARSE_POINT = 0x0400
READ_CHUNK_BYTES = 1024 * 1024
MAX_CHECK_NAME_CHARACTERS = 128
MAX_BASE_REVISION_CHARACTERS = 256
MAX_ARTIFACT_NAME_CHARACTERS = 128

PATH_RULE_KINDS = frozenset({"exact", "tree"})
AFFECTED_CLASSIFICATIONS = frozenset({"affected", "unaffected", "unknown"})
AFFECTED_ANALYSIS_ERROR_CODES = frozenset({
	"affected_base_invalid",
	"affected_git_failed",
	"affected_capture_failed",
	"affected_deadline_exceeded",
	"affected_contract_failed",
	"affected_internal_error",
})
AFFECTED_REASON_CODES = frozenset({
	"analysis_failed",
	"implementation_input_changed",
	"input_spec_undeclared",
	"no_declared_input_changed",
	"source_input_changed",
})

AFFECTED_ANALYSIS_REPORT_FIELDS = frozenset({
	"schema_version",
	"mode",
	"authoritative",
	"scheduling_effect",
	"fallback_decision",
	"report_ok",
	"explain",
	"base_revision",
	"base_resolved",
	"base_tree",
	"capture_complete",
	"check_count",
	"affected_count",
	"unaffected_count",
	"unknown_count",
	"execute_count",
	"affected_skip_count",
	"cache_read_count",
	"cache_write_count",
	"reused_count",
	"checks",
	"errors",
})
AFFECTED_CHECK_FIELDS = frozenset({
	"check_name",
	"input_spec_declared",
	"classification",
	"decision",
	"reason_codes",
	"matched_path_count",
	"matched_paths",
	"frozen_inputs",
})
FROZEN_ACTION_INPUT_FIELDS = frozenset({
	"schema_version",
	"check_name",
	"input_spec_digest",
	"source_manifest_digest",
	"implementation_manifest_digest",
	"discovery_digest",
	"artifact_manifest_digest",
	"capture_complete",
	"source_entry_count",
	"implementation_entry_count",
	"artifact_count",
	"total_bytes",
	"unknown_reasons",
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
_CHECK_NAME_RE = re.compile(r"^[a-z][a-z0-9_]*$")
_ARTIFACT_NAME_RE = re.compile(r"^[a-z][a-z0-9_.-]*$")
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
_GIT_OBJECT_RE = re.compile(r"^[0-9a-f]{40}(?:[0-9a-f]{24})?$")
_WINDOWS_FORBIDDEN_CHARACTERS = frozenset('<>:"|?*')
_WINDOWS_RESERVED_NAMES = frozenset({
	"CON",
	"PRN",
	"AUX",
	"NUL",
	*(f"COM{index}" for index in range(1, 10)),
	*(f"LPT{index}" for index in range(1, 10)),
})


class ValidationInputError(RuntimeError):
	"""Base error for strict validation-input analysis."""


class ValidationInputContractError(ValidationInputError):
	"""Raised for malformed schemas, paths, or declarations."""


class ValidationInputCaptureError(ValidationInputError):
	"""Raised when a declared filesystem input cannot be captured safely."""


class ValidationInputDriftError(ValidationInputCaptureError):
	"""Raised when an input changes during capture."""


class ValidationInputGitError(ValidationInputError):
	"""Raised when Git cannot provide a complete change set."""


class ValidationInputBaseError(ValidationInputGitError):
	"""Raised when the requested comparison base is invalid or unavailable."""


class ValidationInputDeadlineError(ValidationInputError):
	"""Raised when advisory analysis exhausts its monotonic deadline."""


class ValidationInputLimitError(ValidationInputCaptureError):
	"""Raised when an input exceeds a hard capture budget."""


@dataclass(frozen=True)
class InputCaptureLimits:
	"""Hard upper bounds for one affected-input analysis."""

	max_entries: int = 20_000
	max_file_bytes: int = 16 * 1024 * 1024
	max_total_bytes: int = 128 * 1024 * 1024
	max_path_bytes: int = 1024
	max_directory_depth: int = 64
	max_changed_paths: int = 20_000
	max_git_output_bytes: int = 16 * 1024 * 1024
	max_explained_paths: int = 64


DEFAULT_INPUT_CAPTURE_LIMITS = InputCaptureLimits()


@dataclass(frozen=True)
class _Deadline:
	deadline_seconds: float | None
	monotonic: Callable[[], float]

	def check(self) -> None:
		if self.deadline_seconds is None:
			return
		try:
			now_value = self.monotonic()
		except Exception as error:
			raise ValidationInputContractError(
				"validation_inputs.advisory_clock_failed"
			) from error
		if (
			type(now_value) not in (int, float)
			or not math.isfinite(float(now_value))
			or float(now_value) < 0.0
		):
			raise ValidationInputContractError(
				"validation_inputs.advisory_clock_invalid"
			)
		if float(now_value) >= self.deadline_seconds:
			raise ValidationInputDeadlineError(
				"validation_inputs.advisory_deadline_exceeded"
			)

	def timeout_seconds(self) -> float:
		if self.deadline_seconds is None:
			return 30.0
		self.check()
		now_value = float(self.monotonic())
		remaining = self.deadline_seconds - now_value
		if remaining <= 0.0:
			raise ValidationInputDeadlineError(
				"validation_inputs.advisory_deadline_exceeded"
			)
		return max(0.001, min(30.0, remaining))


@dataclass(frozen=True)
class _FileSnapshot:
	device: int
	inode: int
	mode: int
	size: int
	mtime_ns: int
	ctime_ns: int


@dataclass
class _CaptureState:
	entry_count: int = 0
	total_bytes: int = 0


@dataclass(frozen=True)
class PathRule:
	"""One exact-file or recursive-tree source selector.

	Paths use canonical repository-relative POSIX syntax.  Tree suffix matching is
	case-insensitive to conservatively cover platform differences; exclusions are
	whole path prefixes below the selected tree.
	"""

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
		data = _validated_exact_object("path rule", payload, _PATH_RULE_FIELDS)
		_validate_schema_version(data["schema_version"], "path rule")
		return cls(
			kind=data["kind"],
			path=data["path"],
			suffixes=_validated_string_tuple("suffixes", data["suffixes"]),
			excluded_prefixes=_validated_string_tuple(
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
		_validate_check_name(self.check_name)
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
		_rule_keys = [
			(rule.kind, rule.path, rule.suffixes, rule.excluded_prefixes)
			for rule in self.source_rules
		]
		if len(set(_rule_keys)) != len(_rule_keys):
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
		data = _validated_exact_object("input spec", payload, _INPUT_SPEC_FIELDS)
		_validate_schema_version(data["schema_version"], "input spec")
		if type(data["source_rules"]) is not list:
			raise ValidationInputContractError(
				"validation_inputs.source_rules_not_array"
			)
		return cls(
			check_name=data["check_name"],
			source_rules=tuple(
				PathRule.from_dict(rule) for rule in data["source_rules"]
			),
			implementation_files=_validated_string_tuple(
				"implementation_files",
				data["implementation_files"],
			),
			consumed_artifacts=_validated_string_tuple(
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
		return _stable_digest(
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
class FrozenActionInputs:
	"""Content identities captured once for a candidate Action Key."""

	check_name: str
	input_spec_digest: str
	source_manifest_digest: str
	implementation_manifest_digest: str
	discovery_digest: str
	artifact_manifest_digest: str
	capture_complete: bool
	source_entry_count: int
	implementation_entry_count: int
	artifact_count: int
	total_bytes: int
	unknown_reasons: tuple[str, ...] = ()

	def __post_init__(self) -> None:
		_validate_check_name(self.check_name)
		for field_name in (
			"input_spec_digest",
			"source_manifest_digest",
			"implementation_manifest_digest",
			"discovery_digest",
			"artifact_manifest_digest",
		):
			_validate_sha256(field_name, getattr(self, field_name))
		if type(self.capture_complete) is not bool:
			raise ValidationInputContractError(
				"validation_inputs.capture_complete_not_boolean"
			)
		for field_name in (
			"source_entry_count",
			"implementation_entry_count",
			"artifact_count",
			"total_bytes",
		):
			_validate_non_negative_integer(field_name, getattr(self, field_name))
		if type(self.unknown_reasons) is not tuple or any(
			type(reason) is not str or not reason
			for reason in self.unknown_reasons
		):
			raise ValidationInputContractError(
				"validation_inputs.unknown_reasons_invalid"
			)
		if tuple(sorted(set(self.unknown_reasons))) != self.unknown_reasons:
			raise ValidationInputContractError(
				"validation_inputs.unknown_reasons_not_canonical"
			)
		if self.capture_complete == bool(self.unknown_reasons):
			raise ValidationInputContractError(
				"validation_inputs.capture_completeness_relationship_invalid"
			)

	@classmethod
	def from_dict(cls, payload: Mapping[str, Any]) -> FrozenActionInputs:
		data = _validated_exact_object(
			"frozen action inputs",
			payload,
			FROZEN_ACTION_INPUT_FIELDS,
		)
		_validate_specific_schema_version(
			data["schema_version"],
			FROZEN_ACTION_INPUTS_SCHEMA_VERSION,
			"frozen action inputs",
		)
		return cls(
			check_name=data["check_name"],
			input_spec_digest=data["input_spec_digest"],
			source_manifest_digest=data["source_manifest_digest"],
			implementation_manifest_digest=data["implementation_manifest_digest"],
			discovery_digest=data["discovery_digest"],
			artifact_manifest_digest=data["artifact_manifest_digest"],
			capture_complete=data["capture_complete"],
			source_entry_count=data["source_entry_count"],
			implementation_entry_count=data["implementation_entry_count"],
			artifact_count=data["artifact_count"],
			total_bytes=data["total_bytes"],
			unknown_reasons=_validated_string_tuple(
				"unknown_reasons",
				data["unknown_reasons"],
			),
		)

	def to_dict(self) -> dict[str, Any]:
		return {
			"schema_version": FROZEN_ACTION_INPUTS_SCHEMA_VERSION,
			"check_name": self.check_name,
			"input_spec_digest": self.input_spec_digest,
			"source_manifest_digest": self.source_manifest_digest,
			"implementation_manifest_digest": self.implementation_manifest_digest,
			"discovery_digest": self.discovery_digest,
			"artifact_manifest_digest": self.artifact_manifest_digest,
			"capture_complete": self.capture_complete,
			"source_entry_count": self.source_entry_count,
			"implementation_entry_count": self.implementation_entry_count,
			"artifact_count": self.artifact_count,
			"total_bytes": self.total_bytes,
			"unknown_reasons": list(self.unknown_reasons),
		}

	def action_key_input_digests(self) -> dict[str, str]:
		"""Return only input identities; this is not a complete Action Key."""
		return {
			"input_spec": self.input_spec_digest,
			"source_manifest": self.source_manifest_digest,
			"implementation_manifest": self.implementation_manifest_digest,
			"discovery": self.discovery_digest,
			"consumed_artifacts": self.artifact_manifest_digest,
		}


@dataclass(frozen=True)
class ChangedPathSet:
	"""Stable Git base identity and repository-relative changed paths."""

	base_revision: str
	base_resolved: str
	base_tree: str
	paths: tuple[str, ...]

	def __post_init__(self) -> None:
		_validate_base_revision(self.base_revision)
		_validate_git_object("base_resolved", self.base_resolved)
		_validate_git_object("base_tree", self.base_tree)
		if type(self.paths) is not tuple:
			raise ValidationInputContractError(
				"validation_inputs.changed_paths_not_tuple"
			)
		for path in self.paths:
			_validate_portable_relative_path(path)
		if tuple(sorted(set(self.paths), key=_portable_sort_key)) != self.paths:
			raise ValidationInputContractError(
				"validation_inputs.changed_paths_not_canonical"
			)


def freeze_action_inputs(
	repository_root: Path,
	input_spec: CheckInputSpec,
	*,
	artifact_digests: Mapping[str, str] | None = None,
	limits: InputCaptureLimits = DEFAULT_INPUT_CAPTURE_LIMITS,
	deadline_seconds: float | None = None,
	monotonic: Callable[[], float] = time.monotonic,
) -> FrozenActionInputs:
	"""Capture one bounded and stable current-workspace input manifest."""
	if type(input_spec) is not CheckInputSpec:
		raise ValidationInputContractError(
			"validation_inputs.input_spec_type_invalid"
		)
	_validate_limits(limits)
	deadline = _make_deadline(deadline_seconds, monotonic)
	deadline.check()
	root = _validate_repository_root(repository_root, deadline)
	state = _CaptureState()
	source_records: dict[str, dict[str, Any]] = {}
	discovery_records: list[dict[str, Any]] = []
	portable_paths: dict[str, str] = {}

	for rule in input_spec.source_rules:
		deadline.check()
		matched_paths, selector_state = _capture_source_rule(
			root,
			rule,
			records=source_records,
			portable_paths=portable_paths,
			state=state,
			limits=limits,
			deadline=deadline,
		)
		discovery_records.append({
			"rule": rule.to_dict(),
			"state": selector_state,
			"matched_paths": matched_paths,
		})

	implementation_records: list[dict[str, Any]] = []
	for logical_path in input_spec.implementation_files:
		deadline.check()
		path, state_value = _locate_declared_path(root, logical_path, deadline)
		if state_value != "present":
			raise ValidationInputCaptureError(
				"validation_inputs.implementation_file_missing"
			)
		snapshot = _snapshot_path(path, logical_path, expect_directory=False)
		implementation_records.append(
			_capture_regular_file(
				path,
				logical_path,
				snapshot,
				state=state,
				limits=limits,
				deadline=deadline,
			)
		)

	artifacts = _validated_artifact_digests(
		input_spec.consumed_artifacts,
		artifact_digests,
	)
	sorted_source_records = [
		source_records[path]
		for path in sorted(source_records, key=_portable_sort_key)
	]
	deadline.check()
	return FrozenActionInputs(
		check_name=input_spec.check_name,
		input_spec_digest=input_spec.digest,
		source_manifest_digest=_stable_digest(
			b"gf-validation-source-manifest-v1\0",
			sorted_source_records,
		),
		implementation_manifest_digest=_stable_digest(
			b"gf-validation-implementation-manifest-v1\0",
			implementation_records,
		),
		discovery_digest=_stable_digest(
			b"gf-validation-input-discovery-v1\0",
			discovery_records,
		),
		artifact_manifest_digest=_stable_digest(
			b"gf-validation-consumed-artifacts-v1\0",
			artifacts,
		),
		capture_complete=True,
		source_entry_count=len(sorted_source_records),
		implementation_entry_count=len(implementation_records),
		artifact_count=len(artifacts),
		total_bytes=state.total_bytes,
		unknown_reasons=(),
	)


def changed_paths_since(
	repository_root: Path,
	base_revision: str = "HEAD",
	*,
	pathspecs: Iterable[str] = (),
	limits: InputCaptureLimits = DEFAULT_INPUT_CAPTURE_LIMITS,
	deadline_seconds: float | None = None,
	monotonic: Callable[[], float] = time.monotonic,
) -> ChangedPathSet:
	"""Return tracked changes plus all relevant untracked paths since ``base``."""
	_validate_limits(limits)
	_validate_base_revision(base_revision)
	validated_pathspecs = _validated_pathspecs(pathspecs)
	deadline = _make_deadline(deadline_seconds, monotonic)
	deadline.check()
	root = _validate_repository_root(repository_root, deadline)
	base_resolved = _git_text(
		root,
		["rev-parse", "--verify", "--quiet", f"{base_revision}^{{commit}}"],
		limits=limits,
		deadline=deadline,
		base_operation=True,
	)
	_validate_git_object("base_resolved", base_resolved)
	base_tree = _git_text(
		root,
		["rev-parse", "--verify", "--quiet", f"{base_resolved}^{{tree}}"],
		limits=limits,
		deadline=deadline,
		base_operation=True,
	)
	_validate_git_object("base_tree", base_tree)
	path_arguments = ["--", *validated_pathspecs] if validated_pathspecs else ["--"]
	diff_output = _run_git(
		root,
		["diff", "--name-status", "-z", "--find-renames", base_resolved, *path_arguments],
		limits=limits,
		deadline=deadline,
	)
	untracked_output = _run_git(
		root,
		["ls-files", "--others", "-z", *path_arguments],
		limits=limits,
		deadline=deadline,
	)
	paths = {
		*_parse_name_status_z(diff_output),
		*_parse_path_list_z(untracked_output),
	}
	if len(paths) > limits.max_changed_paths:
		raise ValidationInputLimitError(
			"validation_inputs.changed_path_limit"
		)
	for path in paths:
		_validate_portable_relative_path(path)
	deadline.check()
	return ChangedPathSet(
		base_revision=base_revision,
		base_resolved=base_resolved,
		base_tree=base_tree,
		paths=tuple(sorted(paths, key=_portable_sort_key)),
	)


def analyze_affected_checks(
	repository_root: Path,
	check_names: Iterable[str],
	base_revision: str = "HEAD",
	explain: bool = False,
	deadline_seconds: float | None = None,
	*,
	input_specs: Iterable[CheckInputSpec] | None = None,
	artifact_digests: Mapping[str, Mapping[str, str]] | None = None,
	limits: InputCaptureLimits = DEFAULT_INPUT_CAPTURE_LIMITS,
	monotonic: Callable[[], float] = time.monotonic,
) -> dict[str, Any]:
	"""Return advisory affectedness while fixing every decision to ``execute``.

	All exceptions are mapped to one exact-schema failure envelope.  The caller can
	therefore attach this report without changing check execution or suite outcome.
	"""
	names = _safe_check_names(check_names)
	safe_base = _safe_base_revision(base_revision)
	safe_explain = explain if type(explain) is bool else False
	try:
		if type(explain) is not bool:
			raise ValidationInputContractError(
				"validation_inputs.explain_not_boolean"
			)
		_validate_check_name_sequence(names)
		_validate_limits(limits)
		deadline = _make_deadline(deadline_seconds, monotonic)
		catalog = _input_spec_catalog(
			DEFAULT_AFFECTED_INPUT_SPECS if input_specs is None else input_specs
		)
		declared_specs = [catalog[name] for name in names if name in catalog]
		pathspecs = {
			path
			for spec in declared_specs
			for path in spec.git_pathspecs()
		}
		before = changed_paths_since(
			repository_root,
			base_revision,
			pathspecs=tuple(sorted(pathspecs, key=_portable_sort_key)),
			limits=limits,
			deadline_seconds=deadline.deadline_seconds,
			monotonic=monotonic,
		)
		frozen_by_name: dict[str, FrozenActionInputs] = {}
		for spec in declared_specs:
			deadline.check()
			per_check_artifacts = (
				artifact_digests.get(spec.check_name)
				if artifact_digests is not None
				else None
			)
			frozen_by_name[spec.check_name] = freeze_action_inputs(
				repository_root,
				spec,
				artifact_digests=per_check_artifacts,
				limits=limits,
				deadline_seconds=deadline.deadline_seconds,
				monotonic=monotonic,
			)
		after = changed_paths_since(
			repository_root,
			base_revision,
			pathspecs=tuple(sorted(pathspecs, key=_portable_sort_key)),
			limits=limits,
			deadline_seconds=deadline.deadline_seconds,
			monotonic=monotonic,
		)
		if before != after:
			raise ValidationInputDriftError(
				"validation_inputs.change_set_drifted"
			)

		check_reports: list[dict[str, Any]] = []
		for check_name in names:
			spec = catalog.get(check_name)
			if spec is None:
				check_reports.append(_make_check_report(
					check_name,
					input_spec_declared=False,
					classification="unknown",
					reason_codes=("input_spec_undeclared",),
					matched_paths=(),
					frozen_inputs=None,
					explain=explain,
					limits=limits,
				))
				continue
			source_matches = tuple(
				path for path in before.paths if spec.matches_source_path(path)
			)
			implementation_matches = tuple(
				path
				for path in before.paths
				if spec.matches_implementation_path(path)
			)
			matched_paths = tuple(sorted(
				set(source_matches + implementation_matches),
				key=_portable_sort_key,
			))
			if matched_paths:
				reasons = tuple(sorted({
					*(
						("source_input_changed",)
						if source_matches
						else ()
					),
					*(
						("implementation_input_changed",)
						if implementation_matches
						else ()
					),
				}))
				classification = "affected"
			else:
				reasons = ("no_declared_input_changed",)
				classification = "unaffected"
			check_reports.append(_make_check_report(
				check_name,
				input_spec_declared=True,
				classification=classification,
				reason_codes=reasons,
				matched_paths=matched_paths,
				frozen_inputs=frozen_by_name[check_name],
				explain=explain,
				limits=limits,
			))
		deadline.check()
		report = _make_report(
			check_reports,
			base_revision=base_revision,
			base_resolved=before.base_resolved,
			base_tree=before.base_tree,
			report_ok=True,
			explain=explain,
			capture_complete=True,
			errors=(),
		)
		return validate_affected_analysis_report(report)
	except Exception as error:
		return make_affected_analysis_failure(
			names,
			safe_base,
			affected_analysis_error_code(error),
			explain=safe_explain,
		)


def make_affected_analysis_failure(
	check_names: Iterable[str],
	base_revision: str,
	error_code: str,
	explain: bool = False,
) -> dict[str, Any]:
	"""Build the exact fail-closed report without exposing exception text."""
	names = _safe_check_names(check_names)
	safe_base = _safe_base_revision(base_revision)
	if error_code not in AFFECTED_ANALYSIS_ERROR_CODES:
		error_code = "affected_internal_error"
	if type(explain) is not bool:
		explain = False
	limits = DEFAULT_INPUT_CAPTURE_LIMITS
	checks = [
		_make_check_report(
			name,
			input_spec_declared=False,
			classification="unknown",
			reason_codes=("analysis_failed",),
			matched_paths=(),
			frozen_inputs=None,
			explain=explain,
			limits=limits,
		)
		for name in names
	]
	report = _make_report(
		checks,
		base_revision=safe_base,
		base_resolved="",
		base_tree="",
		report_ok=False,
		explain=explain,
		capture_complete=False,
		errors=(error_code,),
	)
	return validate_affected_analysis_report(report)


def affected_analysis_error_code(error: BaseException) -> str:
	"""Map an internal exception to one bounded public error code."""
	if isinstance(error, ValidationInputDeadlineError):
		return "affected_deadline_exceeded"
	if isinstance(error, ValidationInputBaseError):
		return "affected_base_invalid"
	if isinstance(error, ValidationInputGitError):
		return "affected_git_failed"
	if isinstance(error, ValidationInputContractError):
		return "affected_contract_failed"
	if isinstance(error, ValidationInputCaptureError):
		return "affected_capture_failed"
	return "affected_internal_error"


def validate_affected_analysis_report(payload: Mapping[str, Any]) -> dict[str, Any]:
	"""Validate and return an exact schema-v1 JSON-safe report."""
	data = _validated_exact_object(
		"affected analysis report",
		payload,
		AFFECTED_ANALYSIS_REPORT_FIELDS,
	)
	_validate_specific_schema_version(
		data["schema_version"],
		AFFECTED_ANALYSIS_SCHEMA_VERSION,
		"affected analysis report",
	)
	if data["mode"] != "affected_explain_only":
		raise ValidationInputContractError(
			"validation_inputs.report_mode_invalid"
		)
	for field_name, expected in (
		("authoritative", False),
		("scheduling_effect", False),
		("fallback_decision", "execute"),
		("affected_skip_count", 0),
		("cache_read_count", 0),
		("cache_write_count", 0),
		("reused_count", 0),
	):
		if data[field_name] != expected or type(data[field_name]) is not type(expected):
			raise ValidationInputContractError(
				f"validation_inputs.report_{field_name}_invalid"
			)
	for field_name in ("report_ok", "explain", "capture_complete"):
		if type(data[field_name]) is not bool:
			raise ValidationInputContractError(
				f"validation_inputs.report_{field_name}_not_boolean"
			)
	if type(data["base_revision"]) is not str:
		raise ValidationInputContractError(
			"validation_inputs.report_base_revision_invalid"
		)
	for field_name in ("base_resolved", "base_tree"):
		value = data[field_name]
		if type(value) is not str or (value and _GIT_OBJECT_RE.fullmatch(value) is None):
			raise ValidationInputContractError(
				f"validation_inputs.report_{field_name}_invalid"
			)
	for field_name in (
		"check_count",
		"affected_count",
		"unaffected_count",
		"unknown_count",
		"execute_count",
	):
		_validate_non_negative_integer(field_name, data[field_name])
	if type(data["checks"]) is not list:
		raise ValidationInputContractError(
			"validation_inputs.report_checks_not_array"
		)
	validated_checks = [
		_validate_affected_check_report(check)
		for check in data["checks"]
	]
	classifications = [check["classification"] for check in validated_checks]
	if (
		data["check_count"] != len(validated_checks)
		or data["execute_count"] != len(validated_checks)
		or data["affected_count"] != classifications.count("affected")
		or data["unaffected_count"] != classifications.count("unaffected")
		or data["unknown_count"] != classifications.count("unknown")
	):
		raise ValidationInputContractError(
			"validation_inputs.report_counts_invalid"
		)
	if any(check["decision"] != "execute" for check in validated_checks):
		raise ValidationInputContractError(
			"validation_inputs.report_decision_invalid"
		)
	if not data["explain"] and any(
		check["matched_paths"] for check in validated_checks
	):
		raise ValidationInputContractError(
			"validation_inputs.report_unexplained_paths_visible"
		)
	if data["explain"] and any(
		check["classification"] == "affected" and not check["matched_paths"]
		for check in validated_checks
	):
		raise ValidationInputContractError(
			"validation_inputs.report_affected_explanation_missing"
		)
	if type(data["errors"]) is not list or any(
		type(code) is not str or code not in AFFECTED_ANALYSIS_ERROR_CODES
		for code in data["errors"]
	):
		raise ValidationInputContractError(
			"validation_inputs.report_errors_invalid"
		)
	if len(set(data["errors"])) != len(data["errors"]):
		raise ValidationInputContractError(
			"validation_inputs.report_errors_not_unique"
		)
	if data["report_ok"]:
		if (
			not data["capture_complete"]
			or data["errors"]
			or any(
				check["classification"] == "unknown"
				and check["reason_codes"] != ["input_spec_undeclared"]
				for check in validated_checks
			)
		):
			raise ValidationInputContractError(
				"validation_inputs.report_success_relationship_invalid"
			)
	else:
		if (
			data["capture_complete"]
			or not data["errors"]
			or any(classification != "unknown" for classification in classifications)
			or any(
				check["reason_codes"] != ["analysis_failed"]
				for check in validated_checks
			)
		):
			raise ValidationInputContractError(
				"validation_inputs.report_failure_relationship_invalid"
			)
	_assert_strict_json_safe(data)
	return dict(data)


def _make_check_report(
	check_name: str,
	*,
	input_spec_declared: bool,
	classification: str,
	reason_codes: tuple[str, ...],
	matched_paths: tuple[str, ...],
	frozen_inputs: FrozenActionInputs | None,
	explain: bool,
	limits: InputCaptureLimits,
) -> dict[str, Any]:
	visible_paths = (
		list(matched_paths[:limits.max_explained_paths])
		if explain
		else []
	)
	return {
		"check_name": check_name,
		"input_spec_declared": input_spec_declared,
		"classification": classification,
		"decision": "execute",
		"reason_codes": list(reason_codes),
		"matched_path_count": len(matched_paths),
		"matched_paths": visible_paths,
		"frozen_inputs": frozen_inputs.to_dict() if frozen_inputs is not None else None,
	}


def _make_report(
	checks: list[dict[str, Any]],
	*,
	base_revision: str,
	base_resolved: str,
	base_tree: str,
	report_ok: bool,
	explain: bool,
	capture_complete: bool,
	errors: tuple[str, ...],
) -> dict[str, Any]:
	classifications = [check["classification"] for check in checks]
	return {
		"schema_version": AFFECTED_ANALYSIS_SCHEMA_VERSION,
		"mode": "affected_explain_only",
		"authoritative": False,
		"scheduling_effect": False,
		"fallback_decision": "execute",
		"report_ok": report_ok,
		"explain": explain,
		"base_revision": base_revision,
		"base_resolved": base_resolved,
		"base_tree": base_tree,
		"capture_complete": capture_complete,
		"check_count": len(checks),
		"affected_count": classifications.count("affected"),
		"unaffected_count": classifications.count("unaffected"),
		"unknown_count": classifications.count("unknown"),
		"execute_count": len(checks),
		"affected_skip_count": 0,
		"cache_read_count": 0,
		"cache_write_count": 0,
		"reused_count": 0,
		"checks": checks,
		"errors": list(errors),
	}


def _validate_affected_check_report(payload: Any) -> Mapping[str, Any]:
	data = _validated_exact_object(
		"affected check report",
		payload,
		AFFECTED_CHECK_FIELDS,
	)
	_validate_check_name(data["check_name"])
	if type(data["input_spec_declared"]) is not bool:
		raise ValidationInputContractError(
			"validation_inputs.check_input_spec_declared_not_boolean"
		)
	if data["classification"] not in AFFECTED_CLASSIFICATIONS:
		raise ValidationInputContractError(
			"validation_inputs.check_classification_invalid"
		)
	if data["decision"] != "execute":
		raise ValidationInputContractError(
			"validation_inputs.check_decision_invalid"
		)
	if type(data["reason_codes"]) is not list or not data["reason_codes"] or any(
		type(reason) is not str or reason not in AFFECTED_REASON_CODES
		for reason in data["reason_codes"]
	):
		raise ValidationInputContractError(
			"validation_inputs.check_reason_codes_invalid"
		)
	if data["reason_codes"] != sorted(set(data["reason_codes"])):
		raise ValidationInputContractError(
			"validation_inputs.check_reason_codes_not_canonical"
		)
	_validate_non_negative_integer("matched_path_count", data["matched_path_count"])
	if type(data["matched_paths"]) is not list:
		raise ValidationInputContractError(
			"validation_inputs.check_matched_paths_not_array"
		)
	for path in data["matched_paths"]:
		_validate_portable_relative_path(path)
	if data["matched_paths"] != sorted(set(data["matched_paths"]), key=_portable_sort_key):
		raise ValidationInputContractError(
			"validation_inputs.check_matched_paths_not_canonical"
		)
	if len(data["matched_paths"]) > data["matched_path_count"]:
		raise ValidationInputContractError(
			"validation_inputs.check_matched_path_count_invalid"
		)
	if data["frozen_inputs"] is not None:
		frozen = FrozenActionInputs.from_dict(data["frozen_inputs"])
		if frozen.check_name != data["check_name"]:
			raise ValidationInputContractError(
				"validation_inputs.check_frozen_name_mismatch"
			)
	if data["input_spec_declared"] != (data["frozen_inputs"] is not None):
		raise ValidationInputContractError(
			"validation_inputs.check_declaration_relationship_invalid"
		)
	classification = data["classification"]
	if classification == "affected":
		if (
			not data["input_spec_declared"]
			or data["frozen_inputs"] is None
			or data["matched_path_count"] <= 0
			or not set(data["reason_codes"]).issubset({
				"implementation_input_changed",
				"source_input_changed",
			})
		):
			raise ValidationInputContractError(
				"validation_inputs.check_affected_relationship_invalid"
			)
	elif classification == "unaffected":
		if (
			not data["input_spec_declared"]
			or data["frozen_inputs"] is None
			or data["matched_path_count"] != 0
			or data["matched_paths"]
			or data["reason_codes"] != ["no_declared_input_changed"]
		):
			raise ValidationInputContractError(
				"validation_inputs.check_unaffected_relationship_invalid"
			)
	else:
		if (
			data["input_spec_declared"]
			or data["frozen_inputs"] is not None
			or data["matched_path_count"] != 0
			or data["matched_paths"]
			or data["reason_codes"] not in (
				["analysis_failed"],
				["input_spec_undeclared"],
			)
		):
			raise ValidationInputContractError(
				"validation_inputs.check_unknown_relationship_invalid"
			)
	return data


def _capture_source_rule(
	root: Path,
	rule: PathRule,
	*,
	records: dict[str, dict[str, Any]],
	portable_paths: dict[str, str],
	state: _CaptureState,
	limits: InputCaptureLimits,
	deadline: _Deadline,
) -> tuple[list[str], str]:
	path, state_value = _locate_declared_path(root, rule.path, deadline)
	if state_value != "present":
		if rule.kind == "exact":
			records.setdefault(rule.path, {"path": rule.path, "state": "missing"})
			return [rule.path], "missing"
		return [], "missing"
	if rule.kind == "exact":
		snapshot = _snapshot_path(path, rule.path, expect_directory=False)
		records[rule.path] = _capture_regular_file(
			path,
			rule.path,
			snapshot,
			state=state,
			limits=limits,
			deadline=deadline,
		)
		return [rule.path], "present"
	_snapshot_path(path, rule.path, expect_directory=True)
	matched_paths: list[str] = []
	_walk_selected_tree(
		path,
		logical_directory=rule.path,
		rule=rule,
		depth=0,
		records=records,
		matched_paths=matched_paths,
		portable_paths=portable_paths,
		state=state,
		limits=limits,
		deadline=deadline,
	)
	return sorted(set(matched_paths), key=_portable_sort_key), "present"


def _walk_selected_tree(
	directory: Path,
	*,
	logical_directory: str,
	rule: PathRule,
	depth: int,
	records: dict[str, dict[str, Any]],
	matched_paths: list[str],
	portable_paths: dict[str, str],
	state: _CaptureState,
	limits: InputCaptureLimits,
	deadline: _Deadline,
) -> None:
	deadline.check()
	if depth > limits.max_directory_depth:
		raise ValidationInputLimitError(
			"validation_inputs.directory_depth_limit"
		)
	directory_before = _snapshot_path(
		directory,
		logical_directory,
		expect_directory=True,
	)
	try:
		with os.scandir(directory) as iterator:
			entry_names: list[str] = []
			for entry in iterator:
				deadline.check()
				entry_names.append(entry.name)
				if state.entry_count + len(entry_names) > limits.max_entries:
					raise ValidationInputLimitError(
						"validation_inputs.entry_limit"
					)
	except OSError as error:
		raise ValidationInputCaptureError(
			"validation_inputs.directory_unreadable"
		) from error
	for entry_name in sorted(entry_names, key=_portable_sort_key):
		deadline.check()
		_validate_path_segment(entry_name)
		path = directory / entry_name
		logical_path = f"{logical_directory}/{entry_name}"
		_consume_entry(logical_path, state=state, limits=limits)
		portable_key = _portable_key(logical_path)
		previous = portable_paths.setdefault(portable_key, logical_path)
		if previous != logical_path:
			raise ValidationInputCaptureError(
				"validation_inputs.portable_path_collision"
			)
		if any(
			_is_same_or_child_path(logical_path, prefix)
			for prefix in rule.excluded_prefixes
		):
			continue
		snapshot = _snapshot_path(path, logical_path)
		if stat.S_ISDIR(snapshot.mode):
			_walk_selected_tree(
				path,
				logical_directory=logical_path,
				rule=rule,
				depth=depth + 1,
				records=records,
				matched_paths=matched_paths,
				portable_paths=portable_paths,
				state=state,
				limits=limits,
				deadline=deadline,
			)
			continue
		if not stat.S_ISREG(snapshot.mode):
			raise ValidationInputCaptureError(
				"validation_inputs.special_file_rejected"
			)
		if not rule.matches(logical_path):
			continue
		captured = _capture_regular_file(
			path,
			logical_path,
			snapshot,
			state=state,
			limits=limits,
			deadline=deadline,
		)
		previous_record = records.setdefault(logical_path, captured)
		if previous_record != captured:
			raise ValidationInputDriftError(
				"validation_inputs.overlapping_rule_drift"
			)
		matched_paths.append(logical_path)
	_validate_unchanged_path(
		directory,
		logical_directory,
		directory_before,
		expect_directory=True,
	)
	deadline.check()


def _capture_regular_file(
	path: Path,
	logical_path: str,
	before: _FileSnapshot,
	*,
	state: _CaptureState,
	limits: InputCaptureLimits,
	deadline: _Deadline,
) -> dict[str, Any]:
	if before.size < 0 or before.size > limits.max_file_bytes:
		raise ValidationInputLimitError(
			"validation_inputs.file_size_limit"
		)
	projected_total = state.total_bytes + before.size
	if projected_total > limits.max_total_bytes:
		raise ValidationInputLimitError(
			"validation_inputs.total_byte_limit"
		)
	flags = (
		os.O_RDONLY
		| getattr(os, "O_BINARY", 0)
		| getattr(os, "O_CLOEXEC", 0)
		| getattr(os, "O_NOFOLLOW", 0)
	)
	try:
		file_descriptor = os.open(path, flags)
	except OSError as error:
		raise ValidationInputCaptureError(
			"validation_inputs.file_open_failed"
		) from error
	try:
		deadline.check()
		opened = _snapshot_from_stat(os.fstat(file_descriptor))
		if not stat.S_ISREG(opened.mode) or not _same_open_file_identity(opened, before):
			raise ValidationInputDriftError(
				"validation_inputs.file_changed_while_opening"
			)
		hasher = hashlib.sha256()
		captured_size = 0
		remaining_with_growth_probe = before.size + 1
		while remaining_with_growth_probe > 0:
			deadline.check()
			chunk = os.read(
				file_descriptor,
				min(READ_CHUNK_BYTES, remaining_with_growth_probe),
			)
			deadline.check()
			if not chunk:
				break
			hasher.update(chunk)
			captured_size += len(chunk)
			remaining_with_growth_probe -= len(chunk)
		if captured_size != before.size:
			raise ValidationInputDriftError(
				"validation_inputs.file_size_changed"
			)
		opened_after = _snapshot_from_stat(os.fstat(file_descriptor))
		if opened_after != opened:
			raise ValidationInputDriftError(
				"validation_inputs.file_changed_while_reading"
			)
	finally:
		try:
			os.close(file_descriptor)
		except OSError as error:
			raise ValidationInputCaptureError(
				"validation_inputs.file_close_failed"
			) from error
	path_after = _snapshot_path(path, logical_path, expect_directory=False)
	if not _same_open_file_identity(path_after, opened_after):
		raise ValidationInputDriftError(
			"validation_inputs.file_replaced_while_reading"
		)
	state.total_bytes = projected_total
	return {
		"path": logical_path,
		"state": "present",
		"size_bytes": captured_size,
		"content_sha256": hasher.hexdigest(),
	}


def _locate_declared_path(
	root: Path,
	logical_path: str,
	deadline: _Deadline,
) -> tuple[Path, str]:
	current = root
	for segment in logical_path.split("/"):
		deadline.check()
		current /= segment
		try:
			value = current.lstat()
		except FileNotFoundError:
			return current, "missing"
		except OSError as error:
			raise ValidationInputCaptureError(
				"validation_inputs.path_unavailable"
			) from error
		if stat.S_ISLNK(value.st_mode) or _has_reparse_attribute(value):
			raise ValidationInputCaptureError(
				"validation_inputs.link_or_reparse_rejected"
			)
	return current, "present"


def _validate_repository_root(repository_root: Path, deadline: _Deadline) -> Path:
	try:
		raw_root = os.fspath(repository_root)
	except TypeError as error:
		raise ValidationInputContractError(
			"validation_inputs.repository_root_not_pathlike"
		) from error
	if type(raw_root) is not str or not raw_root or "\0" in raw_root:
		raise ValidationInputContractError(
			"validation_inputs.repository_root_invalid"
		)
	root = Path(raw_root)
	if not root.is_absolute() or ".." in root.parts:
		raise ValidationInputContractError(
			"validation_inputs.repository_root_not_absolute"
		)
	if os.name == "nt":
		normalized = raw_root.replace("/", "\\")
		if normalized.startswith(("\\\\", "\\?\\", "\\.\\")):
			raise ValidationInputContractError(
				"validation_inputs.repository_root_unsupported"
			)
	current = Path(root.anchor)
	for component in root.parts[1:]:
		deadline.check()
		current /= component
		_snapshot_path(current, "repository root", expect_directory=True)
	return root


def _snapshot_path(
	path: Path,
	logical_path: str,
	*,
	expect_directory: bool | None = None,
) -> _FileSnapshot:
	try:
		value = path.lstat()
	except OSError as error:
		raise ValidationInputCaptureError(
			f"validation_inputs.path_unavailable:{logical_path}"
		) from error
	if stat.S_ISLNK(value.st_mode) or _has_reparse_attribute(value):
		raise ValidationInputCaptureError(
			f"validation_inputs.link_or_reparse_rejected:{logical_path}"
		)
	if expect_directory is True and not stat.S_ISDIR(value.st_mode):
		raise ValidationInputCaptureError(
			f"validation_inputs.directory_required:{logical_path}"
		)
	if expect_directory is False and not stat.S_ISREG(value.st_mode):
		raise ValidationInputCaptureError(
			f"validation_inputs.regular_file_required:{logical_path}"
		)
	return _snapshot_from_stat(value)


def _snapshot_from_stat(value: os.stat_result) -> _FileSnapshot:
	inode = int(getattr(value, "st_ino", 0))
	device = int(getattr(value, "st_dev", 0))
	if inode <= 0:
		raise ValidationInputCaptureError(
			"validation_inputs.file_identity_unavailable"
		)
	return _FileSnapshot(
		device=device,
		inode=inode,
		mode=int(value.st_mode),
		size=int(value.st_size),
		mtime_ns=int(getattr(value, "st_mtime_ns", round(value.st_mtime * 1_000_000_000))),
		ctime_ns=int(getattr(value, "st_ctime_ns", round(value.st_ctime * 1_000_000_000))),
	)


def _same_open_file_identity(left: _FileSnapshot, right: _FileSnapshot) -> bool:
	"""Compare path and handle identity without Windows' open-time ctime update."""
	return (
		left.device == right.device
		and left.inode == right.inode
		and left.mode == right.mode
		and left.size == right.size
		and left.mtime_ns == right.mtime_ns
	)


def _validate_unchanged_path(
	path: Path,
	logical_path: str,
	expected: _FileSnapshot,
	*,
	expect_directory: bool,
) -> None:
	try:
		actual = _snapshot_path(
			path,
			logical_path,
			expect_directory=expect_directory,
		)
	except ValidationInputCaptureError as error:
		raise ValidationInputDriftError(
			"validation_inputs.path_changed"
		) from error
	if actual != expected:
		raise ValidationInputDriftError(
			"validation_inputs.path_changed"
		)


def _run_git(
	root: Path,
	arguments: list[str],
	*,
	limits: InputCaptureLimits,
	deadline: _Deadline,
	base_operation: bool = False,
) -> bytes:
	deadline.check()
	environment = os.environ.copy()
	environment.update({
		"GIT_CONFIG_NOSYSTEM": "1",
		"GIT_OPTIONAL_LOCKS": "0",
		"GIT_TERMINAL_PROMPT": "0",
		"LC_ALL": "C",
		"LANG": "C",
	})
	try:
		completed = subprocess.run(
			["git", *arguments],
			cwd=root,
			env=environment,
			stdin=subprocess.DEVNULL,
			stdout=subprocess.PIPE,
			stderr=subprocess.PIPE,
			check=False,
			timeout=deadline.timeout_seconds(),
		)
	except subprocess.TimeoutExpired as error:
		raise ValidationInputDeadlineError(
			"validation_inputs.git_deadline_exceeded"
		) from error
	except OSError as error:
		raise ValidationInputGitError(
			"validation_inputs.git_unavailable"
		) from error
	deadline.check()
	if (
		len(completed.stdout) > limits.max_git_output_bytes
		or len(completed.stderr) > limits.max_git_output_bytes
	):
		raise ValidationInputLimitError(
			"validation_inputs.git_output_limit"
		)
	if completed.returncode != 0:
		error_type = ValidationInputBaseError if base_operation else ValidationInputGitError
		raise error_type("validation_inputs.git_command_failed")
	return completed.stdout


def _git_text(
	root: Path,
	arguments: list[str],
	*,
	limits: InputCaptureLimits,
	deadline: _Deadline,
	base_operation: bool,
) -> str:
	data = _run_git(
		root,
		arguments,
		limits=limits,
		deadline=deadline,
		base_operation=base_operation,
	)
	try:
		return data.decode("ascii", errors="strict").strip()
	except UnicodeDecodeError as error:
		raise ValidationInputGitError(
			"validation_inputs.git_object_not_ascii"
		) from error


def _parse_name_status_z(data: bytes) -> tuple[str, ...]:
	tokens = _split_nul_tokens(data)
	paths: list[str] = []
	index = 0
	while index < len(tokens):
		status = _decode_git_token(tokens[index])
		index += 1
		if not status or status[0] not in "ACDMRTUXB":
			raise ValidationInputGitError(
				"validation_inputs.git_name_status_invalid"
			)
		path_count = 2 if status[0] in {"R", "C"} else 1
		if index + path_count > len(tokens):
			raise ValidationInputGitError(
				"validation_inputs.git_name_status_truncated"
			)
		for _ in range(path_count):
			paths.append(_decode_git_token(tokens[index]))
			index += 1
	return tuple(paths)


def _parse_path_list_z(data: bytes) -> tuple[str, ...]:
	return tuple(_decode_git_token(token) for token in _split_nul_tokens(data))


def _split_nul_tokens(data: bytes) -> list[bytes]:
	if not data:
		return []
	if not data.endswith(b"\0"):
		raise ValidationInputGitError(
			"validation_inputs.git_nul_output_unterminated"
		)
	return data[:-1].split(b"\0")


def _decode_git_token(value: bytes) -> str:
	try:
		text = value.decode("utf-8", errors="strict")
	except UnicodeDecodeError as error:
		raise ValidationInputGitError(
			"validation_inputs.git_path_not_utf8"
		) from error
	_validate_portable_relative_path(text)
	return text


def _validated_artifact_digests(
	expected_names: tuple[str, ...],
	artifact_digests: Mapping[str, str] | None,
) -> list[dict[str, str]]:
	if artifact_digests is None:
		artifact_digests = {}
	if not isinstance(artifact_digests, Mapping):
		raise ValidationInputContractError(
			"validation_inputs.artifact_digests_not_mapping"
		)
	if set(artifact_digests) != set(expected_names):
		raise ValidationInputCaptureError(
			"validation_inputs.artifact_digest_set_mismatch"
		)
	result: list[dict[str, str]] = []
	for name in expected_names:
		_validate_artifact_name(name)
		digest = artifact_digests[name]
		_validate_sha256("artifact digest", digest)
		result.append({"name": name, "sha256": digest})
	return result


def _input_spec_catalog(
	input_specs: Iterable[CheckInputSpec],
) -> dict[str, CheckInputSpec]:
	try:
		values = list(input_specs)
	except (TypeError, ValueError) as error:
		raise ValidationInputContractError(
			"validation_inputs.input_specs_not_iterable"
		) from error
	catalog: dict[str, CheckInputSpec] = {}
	for spec in values:
		if type(spec) is not CheckInputSpec:
			raise ValidationInputContractError(
				"validation_inputs.input_spec_type_invalid"
			)
		if spec.check_name in catalog:
			raise ValidationInputContractError(
				"validation_inputs.duplicate_input_spec"
			)
		catalog[spec.check_name] = spec
	return catalog


def _validate_limits(limits: InputCaptureLimits) -> None:
	if not isinstance(limits, InputCaptureLimits):
		raise ValidationInputContractError(
			"validation_inputs.limits_type_invalid"
		)
	for field_name in InputCaptureLimits.__dataclass_fields__:
		value = getattr(limits, field_name)
		hard_limit = getattr(DEFAULT_INPUT_CAPTURE_LIMITS, field_name)
		if type(value) is not int or value <= 0 or value > hard_limit:
			raise ValidationInputContractError(
				f"validation_inputs.limit_invalid:{field_name}"
			)


def _make_deadline(
	deadline_seconds: float | None,
	monotonic: Callable[[], float],
) -> _Deadline:
	if deadline_seconds is not None and (
		type(deadline_seconds) not in (int, float)
		or not math.isfinite(float(deadline_seconds))
		or float(deadline_seconds) < 0.0
	):
		raise ValidationInputContractError(
			"validation_inputs.advisory_deadline_invalid"
		)
	if not callable(monotonic):
		raise ValidationInputContractError(
			"validation_inputs.advisory_clock_not_callable"
		)
	return _Deadline(
		float(deadline_seconds) if deadline_seconds is not None else None,
		monotonic,
	)


def _validated_pathspecs(pathspecs: Iterable[str]) -> tuple[str, ...]:
	try:
		values = tuple(pathspecs)
	except TypeError as error:
		raise ValidationInputContractError(
			"validation_inputs.pathspecs_not_iterable"
		) from error
	for path in values:
		_validate_portable_relative_path(path)
	if len(set(values)) != len(values):
		raise ValidationInputContractError(
			"validation_inputs.pathspecs_duplicate"
		)
	return tuple(sorted(values, key=_portable_sort_key))


def _validate_base_revision(base_revision: Any) -> None:
	if (
		type(base_revision) is not str
		or not base_revision
		or len(base_revision) > MAX_BASE_REVISION_CHARACTERS
		or base_revision.startswith("-")
		or any(ord(character) < 32 or ord(character) == 127 for character in base_revision)
	):
		raise ValidationInputBaseError(
			"validation_inputs.base_revision_invalid"
		)


def _safe_base_revision(value: Any) -> str:
	try:
		_validate_base_revision(value)
	except ValidationInputError:
		return ""
	return value


def _safe_check_names(check_names: Iterable[str]) -> tuple[str, ...]:
	try:
		values = tuple(check_names)
	except Exception:
		return ()
	result: list[str] = []
	for index, value in enumerate(values):
		if type(value) is str and _CHECK_NAME_RE.fullmatch(value) and len(value) <= MAX_CHECK_NAME_CHARACTERS:
			name = value
		else:
			name = f"unknown_check_{index}"
		if name in result:
			name = f"unknown_check_{index}"
		result.append(name)
	return tuple(result)


def _validate_check_name_sequence(check_names: tuple[str, ...]) -> None:
	for check_name in check_names:
		_validate_check_name(check_name)
	if len(set(check_names)) != len(check_names):
		raise ValidationInputContractError(
			"validation_inputs.duplicate_check_name"
		)


def _validate_check_name(check_name: Any) -> None:
	if (
		type(check_name) is not str
		or not check_name
		or len(check_name) > MAX_CHECK_NAME_CHARACTERS
		or _CHECK_NAME_RE.fullmatch(check_name) is None
	):
		raise ValidationInputContractError(
			"validation_inputs.check_name_invalid"
		)


def _validate_artifact_name(name: Any) -> None:
	if (
		type(name) is not str
		or not name
		or len(name) > MAX_ARTIFACT_NAME_CHARACTERS
		or _ARTIFACT_NAME_RE.fullmatch(name) is None
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
		or any(not (character.isalnum() or character in {".", "_", "-"}) for character in suffix)
	):
		raise ValidationInputContractError(
			"validation_inputs.suffix_invalid"
		)


def _consume_entry(
	logical_path: str,
	*,
	state: _CaptureState,
	limits: InputCaptureLimits,
) -> None:
	path_bytes = len(logical_path.encode("utf-8", errors="strict"))
	if path_bytes > limits.max_path_bytes:
		raise ValidationInputLimitError(
			"validation_inputs.path_length_limit"
		)
	state.entry_count += 1
	if state.entry_count > limits.max_entries:
		raise ValidationInputLimitError(
			"validation_inputs.entry_limit"
		)


def _path_rule_sort_key(rule: PathRule) -> tuple[Any, ...]:
	return (
		_portable_sort_key(rule.path),
		rule.kind,
		rule.suffixes,
		rule.excluded_prefixes,
	)


def _portable_key(value: str) -> str:
	return unicodedata.normalize("NFC", value).casefold()


def _portable_sort_key(value: str) -> tuple[str, bytes]:
	return (_portable_key(value), value.encode("utf-8", errors="strict"))


def _is_same_or_child_path(path: str, parent: str) -> bool:
	return path == parent or path.startswith(f"{parent}/")


def _is_strict_child_path(path: str, parent: str) -> bool:
	return path.startswith(f"{parent}/")


def _has_reparse_attribute(value: os.stat_result) -> bool:
	return bool(
		int(getattr(value, "st_file_attributes", 0))
		& FILE_ATTRIBUTE_REPARSE_POINT
	)


def _stable_digest(domain: bytes, payload: Any) -> str:
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


def _validated_exact_object(
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


def _validated_string_tuple(field_name: str, value: Any) -> tuple[str, ...]:
	if type(value) is not list or any(type(item) is not str for item in value):
		raise ValidationInputContractError(
			f"validation_inputs.{field_name}_not_string_array"
		)
	return tuple(value)


def _validate_schema_version(value: Any, label: str) -> None:
	_validate_specific_schema_version(value, INPUT_SPEC_SCHEMA_VERSION, label)


def _validate_specific_schema_version(value: Any, expected: int, label: str) -> None:
	if type(value) is not int or value != expected:
		raise ValidationInputContractError(
			f"validation_inputs.{label.replace(' ', '_')}_schema_invalid"
		)


def _validate_sha256(field_name: str, value: Any) -> None:
	if type(value) is not str or _SHA256_RE.fullmatch(value) is None:
		raise ValidationInputContractError(
			f"validation_inputs.{field_name.replace(' ', '_')}_invalid"
		)


def _validate_git_object(field_name: str, value: Any) -> None:
	if type(value) is not str or _GIT_OBJECT_RE.fullmatch(value) is None:
		raise ValidationInputGitError(
			f"validation_inputs.{field_name}_invalid"
		)


def _validate_non_negative_integer(field_name: str, value: Any) -> None:
	if type(value) is not int or value < 0:
		raise ValidationInputContractError(
			f"validation_inputs.{field_name}_not_non_negative_integer"
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
		raise ValidationInputContractError(
			"validation_inputs.report_not_strict_json"
		) from error


def _declared_input_spec(
	check_name: str,
	*,
	source_rules: Iterable[PathRule],
	additional_implementation_files: Iterable[str] = (),
) -> CheckInputSpec:
	"""Build one module-owned declaration in the canonical contract order."""
	return CheckInputSpec(
		check_name=check_name,
		source_rules=tuple(sorted(source_rules, key=_path_rule_sort_key)),
		implementation_files=tuple(sorted({
			"tools/gf_maintenance.py",
			"tools/gf_validation_inputs.py",
			"tools/gf_workspace_snapshot.py",
			*additional_implementation_files,
		}, key=_portable_sort_key)),
	)


# Phase-two candidate declarations are deliberately limited to three read-only,
# in-process text scanners.  They drive affected/unaffected diagnostics only;
# declaring a path set here does not claim a complete input closure or permit
# evidence reuse.  Undeclared checks continue to resolve to unknown -> execute.
DEFAULT_AFFECTED_INPUT_SPECS: tuple[CheckInputSpec, ...] = (
	_declared_input_spec(
		"package_user_dependency_boundary",
		source_rules=(
			PathRule(
				"tree",
				"addons/gf/kernel/editor/package",
				suffixes=(".gd",),
			),
			PathRule(
				"tree",
				"addons/gf/kernel/package",
				suffixes=(".gd",),
			),
			PathRule("exact", "addons/gf/plugin.gd"),
		),
	),
	_declared_input_spec(
		"public_api_boundary",
		additional_implementation_files=("tools/gdscript_api_parser.py",),
		source_rules=(
			PathRule("tree", "addons/gf", suffixes=(".gd",)),
			PathRule("tree", "docs/api_catalog", suffixes=(".xml",)),
			PathRule(
				"tree",
				"docs/zh/reference/api",
				suffixes=(".md",),
			),
		),
	),
	_declared_input_spec(
		"public_docs_boundary",
		source_rules=(
			PathRule("exact", "addons/gf/extensions/README.md"),
			PathRule("exact", "addons/gf/README.md"),
			PathRule("exact", "ASSET_LIBRARY.md"),
			PathRule("exact", "ASSET_STORE.md"),
			PathRule(
				"tree",
				"docs/wiki",
				suffixes=(".md",),
			),
			PathRule(
				"tree",
				"docs/zh",
				suffixes=(".md",),
				excluded_prefixes=("docs/zh/reference/api",),
			),
			PathRule("exact", "README.md"),
			PathRule("exact", "README.zh.md"),
		),
	),
)
DEFAULT_AFFECTED_INPUT_SPEC_BY_NAME: Mapping[str, CheckInputSpec] = MappingProxyType({
	spec.check_name: spec for spec in DEFAULT_AFFECTED_INPUT_SPECS
})


__all__ = [
	"AFFECTED_ANALYSIS_ERROR_CODES",
	"AFFECTED_ANALYSIS_REPORT_FIELDS",
	"AFFECTED_ANALYSIS_SCHEMA_VERSION",
	"AFFECTED_CHECK_FIELDS",
	"AFFECTED_CLASSIFICATIONS",
	"AFFECTED_REASON_CODES",
	"ChangedPathSet",
	"CheckInputSpec",
	"DEFAULT_INPUT_CAPTURE_LIMITS",
	"DEFAULT_AFFECTED_INPUT_SPECS",
	"DEFAULT_AFFECTED_INPUT_SPEC_BY_NAME",
	"FROZEN_ACTION_INPUTS_SCHEMA_VERSION",
	"FrozenActionInputs",
	"INPUT_SPEC_SCHEMA_VERSION",
	"InputCaptureLimits",
	"PATH_RULE_KINDS",
	"PathRule",
	"ValidationInputBaseError",
	"ValidationInputCaptureError",
	"ValidationInputContractError",
	"ValidationInputDeadlineError",
	"ValidationInputDriftError",
	"ValidationInputError",
	"ValidationInputGitError",
	"ValidationInputLimitError",
	"affected_analysis_error_code",
	"analyze_affected_checks",
	"changed_paths_since",
	"freeze_action_inputs",
	"make_affected_analysis_failure",
	"validate_affected_analysis_report",
]
