#!/usr/bin/env python3
"""Fail-closed structural eligibility shadow for deterministic GF static checks.

This module is opt-in and advisory.  It creates fresh immutable snapshots and
executes each candidate twice, but has no API for filtering a plan, reading or
writing caches, persisting evidence, or skipping validation.
"""

from __future__ import annotations

import hashlib
import json
import math
import os
import platform
import shutil
import stat
import sys
import tempfile
import time
from pathlib import Path
from typing import Any
from typing import Callable
from typing import Mapping
from typing import Sequence

import gf_parallel_validation
import gf_process_supervisor
import gf_validation_contracts
import gf_validation_evidence
import gf_validation_inputs


ELIGIBILITY_SCHEMA_VERSION = 1
ELIGIBILITY_IMPLEMENTATION_EPOCH = 1
ELIGIBILITY_WORKER_TIMEOUT_SECONDS = 30.0
MAX_WORKER_OUTPUT_CHARACTERS = 1024 * 1024
MAX_CHECKS = 3
MAX_RUNTIME_FILES = 512
MAX_RUNTIME_FILE_BYTES = 64 * 1024 * 1024
MAX_RUNTIME_TOTAL_BYTES = 256 * 1024 * 1024
MAX_TOOL_FILES = 2048
MAX_TOOL_FILE_BYTES = 8 * 1024 * 1024
MAX_TOOL_TOTAL_BYTES = 64 * 1024 * 1024
MAX_PYTHON_EXECUTABLE_BYTES = 256 * 1024 * 1024
MAX_IGNORED_GIT_OUTPUT_CHARACTERS = 4 * 1024 * 1024
MAX_IGNORED_INPUT_PATHS = 20_000
MAX_IGNORED_PATH_BYTES = 1024
IGNORED_QUERY_TIMEOUT_SECONDS = 15.0
FILE_ATTRIBUTE_REPARSE_POINT = 0x0400
ALLOWED_CHECKS = frozenset({
	"package_user_dependency_boundary",
	"public_api_boundary",
	"public_docs_boundary",
})
LOGICAL_COMMANDS: Mapping[str, tuple[str, ...]] = {
	name: (
		"python-safe-path", "-P", "-S", "-B", "-X", "utf8",
		"gf_validation_static_worker", name,
	)
	for name in sorted(ALLOWED_CHECKS)
}
CONTROLLED_ENVIRONMENT: Mapping[str, str] = {
	"PYTHONHASHSEED": "0",
	"PYTHONDONTWRITEBYTECODE": "1",
	"PYTHONIOENCODING": "utf-8",
	"PYTHONUTF8": "1",
}
ELIGIBILITY_ERROR_CODES = frozenset({
	"capture_failed",
	"cleanup_failed",
	"deadline_exceeded",
	"eligibility_internal_error",
	"input_drift",
	"invalid_worker_json",
	"result_mismatch",
	"worker_failed",
	"worker_timed_out",
})
ELIGIBILITY_REPORT_FIELDS = frozenset({
	"schema_version",
	"mode",
	"authoritative",
	"scheduling_effect",
	"reuse_permitted",
	"decision",
	"report_ok",
	"workspace_fingerprint",
	"requested_checks",
	"requested_check_count",
	"candidate_count",
	"structurally_eligible_count",
	"ineligible_count",
	"executed_count",
	"collection_duration_seconds",
	"skip_count",
	"cache_read_count",
	"cache_write_count",
	"persist_count",
	"reused_count",
	"projections",
	"errors",
})
ELIGIBILITY_PROJECTION_FIELDS = frozenset({
	"check_name",
	"structurally_eligible",
	"projection",
	"reason_code",
	"policy",
	"action_key",
	"action_key_material",
	"structured_result_digest",
	"execution_count",
	"evidence",
	"workspace_fingerprint",
})
WORKER_FIELDS = frozenset({"schema_version", "check_name", "result", "runtime_manifest"})
RUNTIME_MANIFEST_FIELDS = frozenset({
	"schema_version", "identity", "file_count", "total_bytes", "files", "digest",
})
RUNTIME_FILE_FIELDS = frozenset({"module", "origin_name", "size_bytes", "sha256"})
RUNTIME_IDENTITY_FIELDS = frozenset({
	"implementation", "cache_tag", "hexversion", "version", "unicode_version",
})


class ValidationEligibilityError(RuntimeError):
	"""Base error for bounded eligibility observation."""


class ValidationEligibilityDeadlineError(ValidationEligibilityError):
	"""Raised when the absolute observation deadline is exhausted."""


class ValidationEligibilityCaptureError(ValidationEligibilityError):
	"""Raised when the candidate source boundary cannot be captured completely."""


class ValidationEligibilityWorkerError(ValidationEligibilityError):
	"""Raised when the isolated worker cannot produce trusted structure."""


class ValidationEligibilityDriftError(ValidationEligibilityError):
	"""Raised when candidate inputs change during execution."""


class ValidationEligibilityWorkerTimeoutError(ValidationEligibilityDeadlineError):
	"""Raised when an owned isolated worker exhausts its private timeout."""


class ValidationEligibilityInvalidWorkerError(ValidationEligibilityWorkerError):
	"""Raised when worker JSON or its exact schema is invalid."""


class ValidationEligibilityResultMismatchError(ValidationEligibilityWorkerError):
	"""Raised when the two isolated executions disagree."""


class ValidationEligibilityCleanupError(ValidationEligibilityError):
	"""Raised when the private materialization cannot be fully removed."""


def run_eligibility_shadow(
	repository_root: Path,
	check_names: Sequence[str],
	*,
	deadline_seconds: float | None = None,
	expected_workspace_fingerprint: str | None = None,
) -> dict[str, Any]:
	"""Observe double-run structural eligibility without changing scheduling."""
	names = _validated_check_names(check_names)
	expected_fingerprint = _validated_optional_fingerprint(expected_workspace_fingerprint)
	candidates = tuple(name for name in names if name in ALLOWED_CHECKS)
	started = time.perf_counter()
	if not candidates:
		return validate_eligibility_report(_make_report(
			names, (), (), report_ok=True,
			workspace_fingerprint=expected_fingerprint or "0" * 64,
			collection_duration_seconds=time.perf_counter() - started,
		))
	try:
		_validate_deadline(deadline_seconds)
		root = Path(repository_root)
		_assert_no_ignored_candidate_inputs(
			root,
			candidates,
			deadline_seconds,
			drift=False,
		)
		captured = gf_parallel_validation.capture_workspace(root, deadline=deadline_seconds)
		captured_fingerprint = _validated_fingerprint(captured.workspace_fingerprint)
		if expected_fingerprint is not None and captured_fingerprint != expected_fingerprint:
			raise ValidationEligibilityDriftError("eligibility.workspace_fingerprint_mismatch")
		projections: list[dict[str, Any]] = []
		errors: list[str] = []
		for check_name in candidates:
			_validate_deadline(deadline_seconds)
			try:
				projections.append(_observe_candidate(
					captured,
					check_name,
					deadline_seconds=deadline_seconds,
				))
			except Exception as error:
				code = eligibility_error_code(error)
				errors.append(code)
				projections.append(_failure_projection(
					check_name,
					code,
					workspace_fingerprint=captured_fingerprint,
				))
		_assert_no_ignored_candidate_inputs(
			root,
			candidates,
			deadline_seconds,
			drift=True,
		)
		if errors:
			primary_error = sorted(set(errors))[0]
			projections = [
				projection
				if not projection["structurally_eligible"]
				else _failure_projection(
					projection["check_name"],
					primary_error,
					workspace_fingerprint=captured_fingerprint,
				)
				for projection in projections
			]
		return validate_eligibility_report(
			_make_report(
				names,
				tuple(projections),
				tuple(sorted(set(errors))),
				report_ok=not errors,
				workspace_fingerprint=captured_fingerprint,
				collection_duration_seconds=time.perf_counter() - started,
			)
		)
	except Exception as error:
		return _make_eligibility_failure(
			names,
			eligibility_error_code(error),
			workspace_fingerprint=expected_fingerprint or "0" * 64,
		)


def make_eligibility_failure(
	check_names: Sequence[str],
	error_code: str,
) -> dict[str, Any]:
	"""Return one exact-schema unknown/ineligible report without exception text."""
	names = _validated_check_names(check_names)
	if error_code not in ELIGIBILITY_ERROR_CODES:
		error_code = "eligibility_internal_error"
	return _make_eligibility_failure(names, error_code, workspace_fingerprint="0" * 64)


def _make_eligibility_failure(
	names: Sequence[str],
	error_code: str,
	*,
	workspace_fingerprint: str,
) -> dict[str, Any]:
	projections = tuple(
		_failure_projection(
			name,
			error_code,
			workspace_fingerprint=workspace_fingerprint,
		)
		for name in names
		if name in ALLOWED_CHECKS
	)
	return validate_eligibility_report(
		_make_report(
			names, projections, (error_code,), report_ok=False,
			collection_duration_seconds=0.0,
			workspace_fingerprint=_validated_fingerprint(workspace_fingerprint),
		)
	)


def validate_eligibility_report(report: Mapping[str, Any]) -> dict[str, Any]:
	"""Validate the exact report envelope and immutable no-reuse invariants."""
	if not isinstance(report, Mapping) or frozenset(report) != ELIGIBILITY_REPORT_FIELDS:
		raise ValidationEligibilityError("eligibility.report_fields")
	data = dict(report)
	for field, expected in (
		("schema_version", ELIGIBILITY_SCHEMA_VERSION),
		("mode", "eligibility_shadow_only"),
		("authoritative", False),
		("scheduling_effect", False),
		("reuse_permitted", False),
		("decision", "execute"),
		("skip_count", 0),
		("cache_read_count", 0),
		("cache_write_count", 0),
		("persist_count", 0),
		("reused_count", 0),
	):
		if type(data[field]) is not type(expected) or data[field] != expected:
			raise ValidationEligibilityError(f"eligibility.{field}")
	if type(data["report_ok"]) is not bool or type(data["projections"]) is not list:
		raise ValidationEligibilityError("eligibility.report_types")
	for field in (
		"requested_check_count", "candidate_count", "structurally_eligible_count", "ineligible_count", "executed_count",
	):
		if type(data[field]) is not int or data[field] < 0:
			raise ValidationEligibilityError(f"eligibility.{field}")
	if (
		type(data["requested_checks"]) is not list
		or tuple(data["requested_checks"]) != _validated_check_names(data["requested_checks"])
		or data["requested_check_count"] != len(data["requested_checks"])
	):
		raise ValidationEligibilityError("eligibility.requested_checks")
	if data["candidate_count"] != len(data["projections"]):
		raise ValidationEligibilityError("eligibility.candidate_count")
	expected_candidates = tuple(
		name for name in data["requested_checks"] if name in ALLOWED_CHECKS
	)
	projection_names = tuple(item.get("check_name") for item in data["projections"])
	if (
		data["candidate_count"] > MAX_CHECKS
		or projection_names != expected_candidates
		or len(set(projection_names)) != len(projection_names)
	):
		raise ValidationEligibilityError("eligibility.candidate_relationship")
	eligible = 0
	executed = 0
	for projection in data["projections"]:
		_validate_projection(projection)
		if projection["workspace_fingerprint"] != data["workspace_fingerprint"]:
			raise ValidationEligibilityError("eligibility.projection_workspace")
		eligible += int(projection["structurally_eligible"])
		executed += projection["execution_count"]
	if data["structurally_eligible_count"] != eligible or data["ineligible_count"] != len(data["projections"]) - eligible:
		raise ValidationEligibilityError("eligibility.projection_counts")
	if data["executed_count"] != executed:
		raise ValidationEligibilityError("eligibility.executed_count")
	duration = data["collection_duration_seconds"]
	if type(duration) not in (int, float) or not math.isfinite(float(duration)) or duration < 0.0:
		raise ValidationEligibilityError("eligibility.collection_duration")
	_validated_fingerprint(data["workspace_fingerprint"])
	if type(data["errors"]) is not list or any(
		type(code) is not str or code not in ELIGIBILITY_ERROR_CODES for code in data["errors"]
	):
		raise ValidationEligibilityError("eligibility.errors")
	if data["errors"] != sorted(set(data["errors"])):
		raise ValidationEligibilityError("eligibility.errors_order")
	if data["report_ok"] != (not data["errors"]):
		raise ValidationEligibilityError("eligibility.report_relationship")
	if not data["report_ok"] and not data["projections"] and data["errors"]:
		pass
	elif not data["report_ok"] and any(
		item["reason_code"] not in data["errors"]
		for item in data["projections"]
	):
		raise ValidationEligibilityError("eligibility.failure_reason_relationship")
	if not data["report_ok"] and any(item["structurally_eligible"] for item in data["projections"]):
		raise ValidationEligibilityError("eligibility.failure_eligible")
	gf_validation_evidence.canonical_json_bytes(data)
	return data


def _observe_candidate(
	captured: gf_parallel_validation.CapturedWorkspace,
	check_name: str,
	*,
	deadline_seconds: float | None,
) -> dict[str, Any]:
	temporary = Path(tempfile.mkdtemp(prefix="gfe-"))
	temporary_identity = _owned_directory_identity(temporary)
	cleanup_error = False
	try:
		materialized = gf_parallel_validation.materialize_workspace(
			captured,
			temporary / "w",
			deadline=deadline_seconds,
		)
		input_spec = gf_validation_inputs.DEFAULT_AFFECTED_INPUT_SPEC_BY_NAME[check_name]
		first_inputs = _freeze_complete_inputs(materialized, input_spec, deadline_seconds)
		base_toolchain = _toolchain_digests(materialized, deadline_seconds)
		worker_environment = _worker_environment()
		environment = _environment_digests(worker_environment)
		results = [
			_run_worker(materialized, check_name, deadline_seconds, worker_environment),
			_run_worker(materialized, check_name, deadline_seconds, worker_environment),
		]
		runtime_manifests = [result["runtime_manifest"] for result in results]
		if runtime_manifests[0] != runtime_manifests[1]:
			raise ValidationEligibilityResultMismatchError("eligibility.runtime_manifest_mismatch")
		second_inputs = _freeze_complete_inputs(materialized, input_spec, deadline_seconds)
		if first_inputs.to_dict() != second_inputs.to_dict():
			raise ValidationEligibilityDriftError("eligibility.input_drift")
		postrun_toolchain = _toolchain_digests(materialized, deadline_seconds)
		if base_toolchain != postrun_toolchain:
			raise ValidationEligibilityDriftError("eligibility.toolchain_drift")
		toolchain = {
			**base_toolchain,
			"python_runtime_manifest": runtime_manifests[0]["digest"],
		}
		structured = [
			_normalized_result(item["result"], check_name=check_name)
			for item in results
		]
		digests = [
			gf_validation_evidence.canonical_json_sha256(item, domain=b"gf-static-result-v1\0")
			for item in structured
		]
		if digests[0] != digests[1]:
			raise ValidationEligibilityResultMismatchError("eligibility.result_mismatch")
		policy = gf_validation_contracts.CheckValidationPolicy(
			check_name=check_name,
			determinism="deterministic",
			input_closure="complete",
			reuse_scope="never",
			minimum_evidence_authority="none",
			implementation_epoch=ELIGIBILITY_IMPLEMENTATION_EPOCH,
		)
		contract_digest = gf_validation_evidence.canonical_json_sha256(
			policy.to_dict(), domain=b"gf-eligibility-policy-v1\0"
		)
		material = gf_validation_evidence.make_action_key_material(
			action_name=check_name,
			implementation_epoch=policy.implementation_epoch,
			command=LOGICAL_COMMANDS[check_name],
			contract_digest=contract_digest,
			input_digests={
				**first_inputs.action_key_input_digests(),
				"captured_workspace": captured.workspace_fingerprint,
			},
			dependency_artifact_digests={},
			toolchain_digests=toolchain,
			environment_digests=environment,
			discovery_digest=first_inputs.discovery_digest,
			suite_membership_digest=_suite_digest(check_name),
			input_complete=True,
			unknown_reasons=(),
		)
		invocation_id = "eligibility_" + hashlib.sha256(
			bytes.fromhex(material.action_key) + os.urandom(16)
		).hexdigest()[:32]
		evidence = []
		for index, result in enumerate(results):
			result_fingerprint = gf_validation_evidence.canonical_json_sha256(
				{"index": index, "result": structured[index]}, domain=b"gf-eligibility-run-v1\0"
			)
			evidence.append(gf_validation_evidence.make_execution_evidence(
				material,
				outcome="passed" if bool(result["result"].get("ok")) else "failed",
				exit_code=0,
				timed_out=False,
				cancelled=False,
				warning_count=0,
				orphan_count=0,
				leak_count=0,
				quality_signals_complete=True,
				structured_result_digest=digests[index],
				result_fingerprint=result_fingerprint,
				invocation_id=invocation_id,
				producer_identity="isolated_static_worker",
				duration_seconds=0.0,
			))
		eligible = all(item.structurally_reusable_candidate for item in evidence)
		return {
			"check_name": check_name,
			"structurally_eligible": eligible,
			"projection": "structurally_eligible" if eligible else "ineligible",
			"reason_code": "double_run_match" if eligible else "check_failed",
			"policy": policy.to_dict(),
			"action_key": material.action_key,
			"action_key_material": material.to_dict(),
			"structured_result_digest": digests[0],
			"execution_count": 2,
			"evidence": [item.to_dict() for item in evidence],
			"workspace_fingerprint": captured.workspace_fingerprint,
		}
	finally:
		try:
			if _owned_directory_identity(temporary) != temporary_identity:
				cleanup_error = True
			else:
				shutil.rmtree(temporary, onexc=_make_writable_and_retry)
				if os.path.lexists(temporary):
					cleanup_error = True
		except (OSError, ValidationEligibilityCleanupError):
			cleanup_error = True
		if cleanup_error:
			raise ValidationEligibilityCleanupError("eligibility.cleanup_failed")


def _run_worker(
	root: Path,
	check_name: str,
	deadline_seconds: float | None,
	environment: Mapping[str, str] | None = None,
) -> dict[str, Any]:
	remaining = _remaining_seconds(deadline_seconds)
	worker_timeout = min(ELIGIBILITY_WORKER_TIMEOUT_SECONDS, remaining)
	worker = root / "tools/gf_validation_static_worker.py"
	# ``-I`` ignores every PYTHON* environment control, including the hash seed
	# and UTF-8 settings that are part of this action's declared environment.
	# ``-P`` keeps the worker script directory off the implicit search path while
	# the worker adds only its sealed tools directory explicitly.
	command = [sys.executable, "-P", "-S", "-B", "-X", "utf8", str(worker), check_name]
	worker_environment = dict(_worker_environment() if environment is None else environment)
	result = gf_process_supervisor.run_supervised_process(
		command,
		cwd=root,
		timeout_seconds=worker_timeout,
		environment=worker_environment,
		max_stdout_characters=MAX_WORKER_OUTPUT_CHARACTERS,
		max_stderr_characters=64 * 1024,
	)
	if result.timed_out:
		raise ValidationEligibilityWorkerTimeoutError("eligibility.worker_timeout")
	if (
		result.cancelled
		or result.return_code != 0
		or result.stdout_truncated
		or result.stderr_truncated
		or result.stderr != ""
		or result.notes
	):
		raise ValidationEligibilityWorkerError("eligibility.worker_failed")
	try:
		payload = json.loads(
			result.stdout,
			parse_constant=_reject_json_constant,
			object_pairs_hook=_strict_json_object,
		)
	except (UnicodeError, ValueError) as error:
		raise ValidationEligibilityInvalidWorkerError("eligibility.invalid_worker_json") from error
	return _validate_worker_payload(payload, check_name, expected_root=root)


def _make_writable_and_retry(function: Callable[..., Any], path: str, _error: BaseException) -> None:
	"""Retry bounded snapshot cleanup after clearing Git read-only attributes."""
	os.chmod(path, stat.S_IWRITE | stat.S_IREAD)
	function(path)


def _assert_no_ignored_candidate_inputs(
	root: Path,
	check_names: Sequence[str],
	deadline: float | None,
	*,
	drift: bool,
) -> None:
	"""Reject Git-standard-ignored files that a candidate scanner could consume."""
	_validate_deadline(deadline)
	specs = tuple(
		gf_validation_inputs.DEFAULT_AFFECTED_INPUT_SPEC_BY_NAME[name]
		for name in check_names
	)
	pathspecs = tuple(sorted({
		f":(top,literal){rule.path}"
		for spec in specs
		for rule in spec.source_rules
	} | {":(top,literal)tools"}, key=str.casefold))
	if not pathspecs:
		return
	environment = os.environ.copy()
	environment.update({
		"GIT_OPTIONAL_LOCKS": "0",
		"GIT_TERMINAL_PROMPT": "0",
		"LC_ALL": "C",
		"LANG": "C",
	})
	try:
		result = gf_process_supervisor.run_supervised_process(
			[
				"git",
				"-c",
				"core.fsmonitor=false",
				"-c",
				"core.untrackedCache=false",
				"ls-files",
				"--full-name",
				"--others",
				"--ignored",
				"--exclude-standard",
				"-z",
				"--",
				*pathspecs,
			],
			cwd=root,
			timeout_seconds=min(
				IGNORED_QUERY_TIMEOUT_SECONDS,
				_remaining_seconds(deadline),
			),
			environment=environment,
			max_stdout_characters=MAX_IGNORED_GIT_OUTPUT_CHARACTERS,
			max_stderr_characters=64 * 1024,
		)
	except OSError:
		raise _ignored_input_error(drift) from None
	_validate_deadline(deadline)
	if result.timed_out:
		raise ValidationEligibilityDeadlineError("eligibility.ignored_query_deadline")
	if (
		result.cancelled
		or result.return_code != 0
		or result.stdout_truncated
		or result.stderr_truncated
		or result.stderr != ""
		or result.notes
	):
		raise _ignored_input_error(drift)
	output = result.stdout
	if not output:
		return
	# The process supervisor intentionally decodes defensively with
	# ``errors="replace"``.  A replacement character means Git's raw pathname
	# bytes were not decoded exactly, so matching it against source rules would
	# be incomplete even when the resulting text appears unrelated.
	if "\ufffd" in output or not output.endswith("\0"):
		raise _ignored_input_error(drift)
	logical_paths = output[:-1].split("\0")
	if (
		not logical_paths
		or len(logical_paths) > MAX_IGNORED_INPUT_PATHS
		or any(not path for path in logical_paths)
		or len(set(logical_paths)) != len(logical_paths)
	):
		raise _ignored_input_error(drift)
	for logical_path in logical_paths:
		try:
			if len(logical_path.encode("utf-8", errors="strict")) > MAX_IGNORED_PATH_BYTES:
				raise ValueError("ignored path exceeds budget")
			matches = (
				any(spec.matches_source_path(logical_path) for spec in specs)
				or (
					logical_path.startswith("tools/")
					and logical_path.casefold().endswith(".py")
				)
			)
		except (UnicodeError, ValueError, gf_validation_inputs.ValidationInputError):
			raise _ignored_input_error(drift) from None
		if not matches:
			continue
		_assert_real_ignored_input(root, logical_path, drift=drift)
		raise _ignored_input_error(drift)


def _assert_real_ignored_input(root: Path, logical_path: str, *, drift: bool) -> None:
	"""Pin every component of one ignored input without exposing its pathname."""
	current = Path(os.path.abspath(root))
	components: list[tuple[Path, tuple[int, int, int, int, int]]] = []
	try:
		root_metadata = current.lstat()
		if not _is_real_directory(root_metadata):
			raise OSError("unsafe repository root")
		components.append((current, _stat_identity(root_metadata)))
		parts = logical_path.split("/")
		for index, part in enumerate(parts):
			current /= part
			metadata = current.lstat()
			if index == len(parts) - 1:
				if not _is_real_regular_file(metadata):
					raise OSError("ignored candidate is not a real regular file")
			elif not _is_real_directory(metadata):
				raise OSError("ignored candidate parent is unsafe")
			components.append((current, _stat_identity(metadata)))
		for path, expected in reversed(components):
			if _stat_identity(path.lstat()) != expected:
				raise OSError("ignored candidate path drifted")
	except OSError:
		raise _ignored_input_error(drift) from None


def _ignored_input_error(drift: bool) -> ValidationEligibilityError:
	if drift:
		return ValidationEligibilityDriftError("eligibility.ignored_input_drift")
	return ValidationEligibilityCaptureError("eligibility.ignored_input_capture")


def _validate_worker_payload(
	payload: Any,
	check_name: str,
	*,
	expected_root: Path | None = None,
) -> dict[str, Any]:
	if type(payload) is not dict or frozenset(payload) != WORKER_FIELDS:
		raise ValidationEligibilityInvalidWorkerError("eligibility.worker_fields")
	if type(payload["schema_version"]) is not int or payload["schema_version"] != 1 or payload["check_name"] != check_name or type(payload["result"]) is not dict:
		raise ValidationEligibilityInvalidWorkerError("eligibility.worker_identity")
	if expected_root is not None and payload["result"].get("root") != str(expected_root):
		raise ValidationEligibilityInvalidWorkerError("eligibility.worker_root")
	_normalized_result(payload["result"], check_name=check_name)
	payload["runtime_manifest"] = _validate_runtime_manifest(payload["runtime_manifest"])
	return payload


def _normalized_result(
	result: Mapping[str, Any],
	*,
	check_name: str | None = None,
) -> dict[str, Any]:
	if type(result) is not dict or type(result.get("root")) is not str:
		raise ValidationEligibilityInvalidWorkerError("eligibility.worker_result")
	normalized = dict(result)
	normalized.pop("root")
	common = {"ok", "issue_count", "issues"}
	if type(normalized.get("ok")) is not bool or type(normalized.get("issue_count")) is not int or type(normalized.get("issues")) is not list:
		raise ValidationEligibilityInvalidWorkerError("eligibility.worker_ok")
	if normalized["issue_count"] < 0 or normalized["issue_count"] != len(normalized["issues"]) or normalized["ok"] != (normalized["issue_count"] == 0):
		raise ValidationEligibilityInvalidWorkerError("eligibility.worker_count")
	fields = frozenset(normalized)
	static_fields = common | {"file_count"}
	package_fields = common | {"source_file_count", "issue_kind_counts", "scan_roots"}
	if fields == static_fields:
		if check_name not in (None, "public_api_boundary", "public_docs_boundary"):
			raise ValidationEligibilityInvalidWorkerError("eligibility.worker_result_check")
		if type(normalized["file_count"]) is not int or normalized["file_count"] < 0:
			raise ValidationEligibilityInvalidWorkerError("eligibility.worker_file_count")
	elif fields == package_fields:
		if check_name not in (None, "package_user_dependency_boundary"):
			raise ValidationEligibilityInvalidWorkerError("eligibility.worker_result_check")
		if type(normalized["source_file_count"]) is not int or normalized["source_file_count"] < 0:
			raise ValidationEligibilityInvalidWorkerError("eligibility.worker_source_count")
		if type(normalized["issue_kind_counts"]) is not dict or any(
			type(key) is not str or type(count) is not int or count < 0
			for key, count in normalized["issue_kind_counts"].items()
		):
			raise ValidationEligibilityInvalidWorkerError("eligibility.worker_issue_counts")
		if sum(normalized["issue_kind_counts"].values()) != normalized["issue_count"]:
			raise ValidationEligibilityInvalidWorkerError("eligibility.worker_issue_count_sum")
		if type(normalized["scan_roots"]) is not list or any(type(item) is not str for item in normalized["scan_roots"]):
			raise ValidationEligibilityInvalidWorkerError("eligibility.worker_scan_roots")
		if normalized["scan_roots"] != [
			"addons/gf/plugin.gd",
			"addons/gf/kernel/package",
			"addons/gf/kernel/editor/package",
		]:
			raise ValidationEligibilityInvalidWorkerError("eligibility.worker_scan_roots")
	else:
		raise ValidationEligibilityInvalidWorkerError("eligibility.worker_result_fields")
	gf_validation_evidence.canonical_json_bytes(normalized)
	return normalized


def _validate_runtime_manifest(value: Any) -> dict[str, Any]:
	if type(value) is not dict or frozenset(value) != RUNTIME_MANIFEST_FIELDS:
		raise ValidationEligibilityInvalidWorkerError("eligibility.runtime_manifest_fields")
	if (
		type(value["schema_version"]) is not int
		or value["schema_version"] != 1
		or type(value["identity"]) is not dict
		or frozenset(value["identity"]) != RUNTIME_IDENTITY_FIELDS
	):
		raise ValidationEligibilityInvalidWorkerError("eligibility.runtime_manifest_identity")
	identity = value["identity"]
	if (
		type(identity["implementation"]) is not str
		or type(identity["cache_tag"]) not in (str, type(None))
		or type(identity["hexversion"]) is not int
		or type(identity["version"]) is not list
		or any(type(part) not in (int, str) for part in identity["version"])
		or type(identity["unicode_version"]) is not str
	):
		raise ValidationEligibilityInvalidWorkerError("eligibility.runtime_identity_types")
	if type(value["files"]) is not list or type(value["file_count"]) is not int or value["file_count"] != len(value["files"]):
		raise ValidationEligibilityInvalidWorkerError("eligibility.runtime_manifest_count")
	if (
		value["file_count"] < 1
		or value["file_count"] > MAX_RUNTIME_FILES
		or type(value["total_bytes"]) is not int
		or value["total_bytes"] < 1
		or value["total_bytes"] > MAX_RUNTIME_TOTAL_BYTES
	):
		raise ValidationEligibilityInvalidWorkerError("eligibility.runtime_manifest_budget")
	total = 0
	identities: list[tuple[str, str]] = []
	for record in value["files"]:
		if type(record) is not dict or frozenset(record) != RUNTIME_FILE_FIELDS:
			raise ValidationEligibilityInvalidWorkerError("eligibility.runtime_file_fields")
		if (
			type(record["module"]) is not str
			or not record["module"]
			or type(record["origin_name"]) is not str
			or not record["origin_name"]
			or Path(record["origin_name"]).name != record["origin_name"]
			or type(record["size_bytes"]) is not int
			or record["size_bytes"] < 0
			or record["size_bytes"] > MAX_RUNTIME_FILE_BYTES
		):
			raise ValidationEligibilityInvalidWorkerError("eligibility.runtime_file_types")
		_validated_fingerprint(record["sha256"])
		identities.append((record["module"], record["origin_name"].casefold()))
		total += record["size_bytes"]
	if total != value["total_bytes"]:
		raise ValidationEligibilityInvalidWorkerError("eligibility.runtime_total")
	if identities != sorted(identities) or len(set(identities)) != len(identities):
		raise ValidationEligibilityInvalidWorkerError("eligibility.runtime_file_order")
	digest = value["digest"]
	_validated_fingerprint(digest)
	material = dict(value)
	material.pop("digest")
	if digest != gf_validation_evidence.canonical_json_sha256(
		material, domain=b"gf-python-runtime-manifest-v1\0"
	):
		raise ValidationEligibilityInvalidWorkerError("eligibility.runtime_digest")
	gf_validation_evidence.canonical_json_bytes(value)
	return dict(value)


def _freeze_complete_inputs(root: Path, spec: gf_validation_inputs.CheckInputSpec, deadline: float | None) -> gf_validation_inputs.FrozenActionInputs:
	base = gf_validation_inputs.freeze_action_inputs(
		root,
		spec,
		deadline_seconds=deadline,
		monotonic=time.perf_counter,
	)
	tools_digest = _tools_manifest_digest(root, deadline)
	return gf_validation_inputs.FrozenActionInputs(
		check_name=base.check_name,
		input_spec_digest=base.input_spec_digest,
		source_manifest_digest=base.source_manifest_digest,
		implementation_manifest_digest=tools_digest,
		discovery_digest=base.discovery_digest,
		artifact_manifest_digest=base.artifact_manifest_digest,
		capture_complete=True,
		source_entry_count=base.source_entry_count,
		implementation_entry_count=base.implementation_entry_count,
		artifact_count=base.artifact_count,
		total_bytes=base.total_bytes,
		unknown_reasons=(),
	)


def _tools_manifest_digest(root: Path, deadline: float | None) -> str:
	records: list[dict[str, Any]] = []
	total = 0
	for path in sorted((root / "tools").rglob("*.py"), key=lambda item: item.relative_to(root).as_posix().casefold()):
		_validate_deadline(deadline)
		if len(records) >= MAX_TOOL_FILES:
			raise ValidationEligibilityError("eligibility.tool_file_limit")
		value = path.lstat()
		if not stat.S_ISREG(value.st_mode) or stat.S_ISLNK(value.st_mode):
			raise ValidationEligibilityError("eligibility.tool_file_type")
		if value.st_size > MAX_TOOL_FILE_BYTES:
			raise ValidationEligibilityError("eligibility.tool_file_size")
		size, content_digest = _stable_file_digest(
			path,
			maximum_bytes=MAX_TOOL_FILE_BYTES,
			deadline=deadline,
		)
		total += size
		if total > MAX_TOOL_TOTAL_BYTES or size != value.st_size:
			raise ValidationEligibilityError("eligibility.tool_total_size")
		after = path.lstat()
		if (value.st_dev, value.st_ino, value.st_size, value.st_mtime_ns) != (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
			raise ValidationEligibilityDriftError("eligibility.tool_drift")
		records.append({
			"path": path.relative_to(root).as_posix(),
			"size": size,
			"sha256": content_digest,
		})
	return gf_validation_evidence.canonical_json_sha256(records, domain=b"gf-tools-py-manifest-v1\0")


def _toolchain_digests(root: Path, deadline: float | None) -> dict[str, str]:
	_validate_deadline(deadline)
	executable = Path(sys.executable)
	before = executable.stat()
	if not stat.S_ISREG(before.st_mode) or before.st_size < 1 or before.st_size > MAX_PYTHON_EXECUTABLE_BYTES:
		raise ValidationEligibilityError("eligibility.python_executable_size")
	digest = hashlib.sha256()
	read_size = 0
	with executable.open("rb") as stream:
		handle_before = os.fstat(stream.fileno())
		if not _same_open_file_identity(handle_before, before):
			raise ValidationEligibilityDriftError("eligibility.python_executable_open_drift")
		while True:
			_validate_deadline(deadline)
			chunk = stream.read(1024 * 1024)
			if not chunk:
				break
			read_size += len(chunk)
			if read_size > MAX_PYTHON_EXECUTABLE_BYTES:
				raise ValidationEligibilityError("eligibility.python_executable_size")
			digest.update(chunk)
		handle_after = os.fstat(stream.fileno())
	if (
		read_size != before.st_size
		or not _same_open_file_identity(handle_before, handle_after)
		or not _same_open_file_identity(handle_after, executable.stat())
	):
		raise ValidationEligibilityDriftError("eligibility.python_executable_drift")
	return {
		"python_executable_content": digest.hexdigest(),
		"python_identity": gf_validation_evidence.canonical_json_sha256({
			"implementation": platform.python_implementation(),
			"version": list(sys.version_info[:5]),
			"platform": platform.platform(),
			"machine": platform.machine(),
		}),
	}


def _worker_environment() -> dict[str, str]:
	environment = dict(CONTROLLED_ENVIRONMENT)
	if os.name == "nt":
		for name in ("SystemRoot", "WINDIR"):
			value = os.environ.get(name)
			if value:
				environment[name] = value
	return environment


def _environment_digests(environment: Mapping[str, str]) -> dict[str, str]:
	return {
		"controlled_environment": gf_validation_evidence.canonical_json_sha256(dict(environment))
	}


def _suite_digest(check_name: str) -> str:
	return gf_validation_evidence.canonical_json_sha256(
		{"suite": "eligibility_static_v1", "checks": [check_name]},
		domain=b"gf-eligibility-suite-v1\0",
	)


def _failure_projection(
	check_name: str,
	error_code: str,
	*,
	workspace_fingerprint: str = "0" * 64,
) -> dict[str, Any]:
	policy = gf_validation_contracts.CheckValidationPolicy.fail_closed(check_name)
	return {
		"check_name": check_name,
		"structurally_eligible": False,
		"projection": "ineligible",
		"reason_code": error_code,
		"policy": policy.to_dict(),
		"action_key": None,
		"action_key_material": None,
		"structured_result_digest": None,
		"execution_count": 0,
		"evidence": [],
		"workspace_fingerprint": workspace_fingerprint,
	}


def _make_report(
	names: Sequence[str],
	projections: Sequence[dict[str, Any]],
	errors: Sequence[str],
	*,
	report_ok: bool,
	collection_duration_seconds: float,
	workspace_fingerprint: str,
) -> dict[str, Any]:
	eligible = sum(int(item["structurally_eligible"]) for item in projections)
	return {
		"schema_version": ELIGIBILITY_SCHEMA_VERSION,
		"mode": "eligibility_shadow_only",
		"authoritative": False,
		"scheduling_effect": False,
		"reuse_permitted": False,
		"decision": "execute",
		"report_ok": report_ok,
		"workspace_fingerprint": workspace_fingerprint,
		"requested_checks": list(names),
		"requested_check_count": len(names),
		"candidate_count": len(projections),
		"structurally_eligible_count": eligible,
		"ineligible_count": len(projections) - eligible,
		"executed_count": sum(item["execution_count"] for item in projections),
		"collection_duration_seconds": round(max(0.0, collection_duration_seconds), 6),
		"skip_count": 0,
		"cache_read_count": 0,
		"cache_write_count": 0,
		"persist_count": 0,
		"reused_count": 0,
		"projections": list(projections),
		"errors": list(errors),
	}


def _validate_projection(value: Any) -> None:
	if type(value) is not dict or frozenset(value) != ELIGIBILITY_PROJECTION_FIELDS:
		raise ValidationEligibilityError("eligibility.projection_fields")
	if type(value["check_name"]) is not str or value["check_name"] not in ALLOWED_CHECKS:
		raise ValidationEligibilityError("eligibility.projection_name")
	if type(value["structurally_eligible"]) is not bool or value["projection"] not in {"structurally_eligible", "ineligible"}:
		raise ValidationEligibilityError("eligibility.projection_type")
	if value["structurally_eligible"] != (value["projection"] == "structurally_eligible"):
		raise ValidationEligibilityError("eligibility.projection_relationship")
	if type(value["execution_count"]) is not int:
		raise ValidationEligibilityError("eligibility.projection_execution_count")
	policy = gf_validation_contracts.CheckValidationPolicy.from_dict(value["policy"])
	if policy.check_name != value["check_name"]:
		raise ValidationEligibilityError("eligibility.policy_check_name")
	if policy.reuse_scope != "never" or policy.minimum_evidence_authority != "none":
		raise ValidationEligibilityError("eligibility.policy_reuse")
	if value["structurally_eligible"]:
		if (
			value["reason_code"] != "double_run_match"
			or not policy.declared
			or policy.determinism != "deterministic"
			or policy.input_closure != "complete"
			or policy.implementation_epoch != ELIGIBILITY_IMPLEMENTATION_EPOCH
		):
			raise ValidationEligibilityError("eligibility.eligible_policy")
		if type(value["action_key"]) is not str or len(value["action_key"]) != 64 or value["execution_count"] != 2:
			raise ValidationEligibilityError("eligibility.eligible_evidence")
		if type(value["evidence"]) is not list or len(value["evidence"]) != 2:
			raise ValidationEligibilityError("eligibility.eligible_evidence_count")
		_validate_executed_projection_evidence(value, policy, passed=True)
	else:
		if type(value["reason_code"]) is not str or (
			value["reason_code"] != "check_failed"
			and value["reason_code"] not in ELIGIBILITY_ERROR_CODES
		):
			raise ValidationEligibilityError("eligibility.ineligible_reason")
		if value["execution_count"] not in (0, 2):
			raise ValidationEligibilityError("eligibility.ineligible_execution")
		if value["execution_count"] == 2:
			if value["reason_code"] != "check_failed":
				raise ValidationEligibilityError("eligibility.ineligible_executed_reason")
			_validate_executed_projection_evidence(value, policy, passed=False)
		if value["execution_count"] == 0 and any(
			value[field] not in (None, [])
			for field in (
				"action_key", "action_key_material", "structured_result_digest", "evidence",
			)
		):
			raise ValidationEligibilityError("eligibility.ineligible_empty_evidence")
	_validated_fingerprint(value["workspace_fingerprint"])


def _validate_executed_projection_evidence(
	value: Mapping[str, Any],
	policy: gf_validation_contracts.CheckValidationPolicy,
	*,
	passed: bool,
) -> None:
	material_payload = value["action_key_material"]
	if (
		type(material_payload) is not dict
		or type(material_payload.get("schema_version")) is not int
		or material_payload["schema_version"]
		!= gf_validation_evidence.ACTION_KEY_MATERIAL_SCHEMA_VERSION
	):
		raise ValidationEligibilityError("eligibility.action_key_material")
	try:
		material = gf_validation_evidence.make_action_key_material(
			action_name=material_payload["action_name"],
			implementation_epoch=material_payload["implementation_epoch"],
			command=material_payload["command"],
			contract_digest=material_payload["contract_digest"],
			input_digests=material_payload["inputs"],
			dependency_artifact_digests=material_payload["dependency_artifacts"],
			toolchain_digests=material_payload["toolchain"],
			environment_digests=material_payload["environment"],
			discovery_digest=material_payload["discovery_digest"],
			suite_membership_digest=material_payload["suite_membership_digest"],
			input_complete=material_payload["input_complete"],
			unknown_reasons=material_payload["unknown_reasons"],
		)
	except (KeyError, TypeError, gf_validation_evidence.ValidationEvidenceError) as error:
		raise ValidationEligibilityError("eligibility.action_key_material") from error
	if material.to_dict() != material_payload:
		raise ValidationEligibilityError("eligibility.action_key_material_fields")
	expected_contract_digest = gf_validation_evidence.canonical_json_sha256(
		policy.to_dict(), domain=b"gf-eligibility-policy-v1\0"
	)
	if (
		material.action_name != value["check_name"]
		or material.implementation_epoch != policy.implementation_epoch
		or material.contract_digest != expected_contract_digest
		or material.command != LOGICAL_COMMANDS[value["check_name"]]
		or not material.input_complete
		or material.unknown_reasons
		or material.action_key != value["action_key"]
		or dict(material.dependency_artifact_digests)
		or set(dict(material.input_digests)) != {
			"captured_workspace", "consumed_artifacts", "discovery", "implementation_manifest",
			"input_spec", "source_manifest",
		}
		or dict(material.input_digests)["captured_workspace"] != value["workspace_fingerprint"]
		or dict(material.input_digests)["discovery"] != material.discovery_digest
		or set(dict(material.toolchain_digests)) != {
			"python_executable_content", "python_identity", "python_runtime_manifest",
		}
		or set(dict(material.environment_digests)) != {"controlled_environment"}
		or material.suite_membership_digest != _suite_digest(value["check_name"])
	):
		raise ValidationEligibilityError("eligibility.action_key_relationship")
	result_digest = value["structured_result_digest"]
	_validated_fingerprint(result_digest)
	invocation_ids: set[str] = set()
	result_fingerprints: set[str] = set()
	for evidence in value["evidence"]:
		if type(evidence) is not dict or frozenset(evidence) != frozenset({
			"schema_version", "action_key", "action_name", "input_complete", "execution",
			"outcome", "exit_code", "timed_out", "cancelled", "warning_count",
			"orphan_count", "leak_count", "quality_signals_complete",
			"structured_result_digest", "result_fingerprint", "invocation_id",
			"evidence_authority", "producer_identity", "duration_seconds",
			"structurally_reusable_candidate",
		}):
			raise ValidationEligibilityError("eligibility.evidence_fields")
		for fingerprint_field in ("action_key", "structured_result_digest", "result_fingerprint"):
			_validated_fingerprint(evidence[fingerprint_field])
		if (
			type(evidence["schema_version"]) is not int
			or evidence["schema_version"] != gf_validation_evidence.EXECUTION_EVIDENCE_SCHEMA_VERSION
			or evidence["action_key"] != value["action_key"]
			or evidence["action_name"] != value["check_name"]
			or evidence["input_complete"] is not True
			or evidence["execution"] != "executed"
			or evidence["outcome"] != ("passed" if passed else "failed")
			or type(evidence["exit_code"]) is not int
			or evidence["exit_code"] != 0
			or evidence["timed_out"] is not False
			or evidence["cancelled"] is not False
			or type(evidence["warning_count"]) is not int
			or evidence["warning_count"] != 0
			or type(evidence["orphan_count"]) is not int
			or evidence["orphan_count"] != 0
			or type(evidence["leak_count"]) is not int
			or evidence["leak_count"] != 0
			or evidence["quality_signals_complete"] is not True
			or evidence["structured_result_digest"] != result_digest
			or evidence["evidence_authority"] != "self_asserted"
			or evidence["producer_identity"] != "isolated_static_worker"
			or evidence["structurally_reusable_candidate"] is not passed
			or type(evidence["invocation_id"]) is not str
			or not evidence["invocation_id"]
			or type(evidence["duration_seconds"]) not in (int, float)
			or not math.isfinite(float(evidence["duration_seconds"]))
			or float(evidence["duration_seconds"]) < 0.0
		):
			raise ValidationEligibilityError("eligibility.evidence_relationship")
		invocation_ids.add(evidence["invocation_id"])
		result_fingerprints.add(evidence["result_fingerprint"])
	if len(invocation_ids) != 1:
		raise ValidationEligibilityError("eligibility.evidence_invocation")
	if len(result_fingerprints) != 2:
		raise ValidationEligibilityError("eligibility.evidence_result_fingerprints")


def eligibility_error_code(error: BaseException) -> str:
	if isinstance(error, ValidationEligibilityWorkerTimeoutError):
		return "worker_timed_out"
	if isinstance(error, ValidationEligibilityDeadlineError):
		return "deadline_exceeded"
	if isinstance(error, ValidationEligibilityDriftError):
		return "input_drift"
	if isinstance(error, ValidationEligibilityCaptureError):
		return "capture_failed"
	if isinstance(error, gf_parallel_validation.WorkspaceDriftError):
		return "input_drift"
	if isinstance(error, gf_parallel_validation.WorkspaceDeadlineError):
		return "deadline_exceeded"
	if isinstance(error, gf_parallel_validation.WorkspaceSnapshotError):
		return "capture_failed"
	if isinstance(error, ValidationEligibilityCleanupError):
		return "cleanup_failed"
	if isinstance(error, ValidationEligibilityResultMismatchError):
		return "result_mismatch"
	if isinstance(error, ValidationEligibilityInvalidWorkerError):
		return "invalid_worker_json"
	if isinstance(error, ValidationEligibilityWorkerError):
		return "worker_failed"
	return "eligibility_internal_error"


def _validated_check_names(values: Sequence[str]) -> tuple[str, ...]:
	if type(values) not in (list, tuple) or len(values) > MAX_CHECKS * 32:
		raise ValidationEligibilityError("eligibility.check_names")
	names = tuple(values)
	if any(type(name) is not str or not name or len(name) > 128 for name in names) or len(set(names)) != len(names):
		raise ValidationEligibilityError("eligibility.check_name")
	return names


def _validate_deadline(deadline: float | None) -> None:
	if deadline is None:
		return
	if type(deadline) not in (int, float) or not math.isfinite(float(deadline)) or time.perf_counter() >= float(deadline):
		raise ValidationEligibilityDeadlineError("eligibility.deadline")


def _remaining_seconds(deadline: float | None) -> float:
	if deadline is None:
		return ELIGIBILITY_WORKER_TIMEOUT_SECONDS
	_validate_deadline(deadline)
	return max(0.001, float(deadline) - time.perf_counter())


def _stat_identity(value: os.stat_result) -> tuple[int, int, int, int, int]:
	return (value.st_dev, value.st_ino, value.st_mode, value.st_size, value.st_mtime_ns)


def _is_reparse_point(value: os.stat_result) -> bool:
	return bool(
		int(getattr(value, "st_file_attributes", 0))
		& FILE_ATTRIBUTE_REPARSE_POINT
	)


def _is_real_directory(value: os.stat_result) -> bool:
	return (
		stat.S_ISDIR(value.st_mode)
		and not stat.S_ISLNK(value.st_mode)
		and not _is_reparse_point(value)
	)


def _is_real_regular_file(value: os.stat_result) -> bool:
	return (
		stat.S_ISREG(value.st_mode)
		and not stat.S_ISLNK(value.st_mode)
		and not _is_reparse_point(value)
	)


def _owned_directory_identity(path: Path) -> tuple[int, int, int]:
	"""Return the deletion authority identity for one freshly owned real root."""
	if not path.is_absolute():
		raise ValidationEligibilityCleanupError("eligibility.unsafe_temporary_root")
	metadata = path.lstat()
	device = int(getattr(metadata, "st_dev", 0))
	inode = int(getattr(metadata, "st_ino", 0))
	if not _is_real_directory(metadata) or (device == 0 and inode == 0):
		raise ValidationEligibilityCleanupError("eligibility.unsafe_temporary_root")
	return (device, inode, metadata.st_mode)


def _same_open_file_identity(left: os.stat_result, right: os.stat_result) -> bool:
	"""Compare path and handle identity across Windows executable mode views."""
	mode_matches = left.st_mode == right.st_mode
	if os.name == "nt":
		mode_matches = stat.S_IFMT(left.st_mode) == stat.S_IFMT(right.st_mode)
	return (
		left.st_dev == right.st_dev
		and left.st_ino == right.st_ino
		and mode_matches
		and left.st_size == right.st_size
		and left.st_mtime_ns == right.st_mtime_ns
	)


def _stable_file_digest(
	path: Path,
	*,
	maximum_bytes: int,
	deadline: float | None,
) -> tuple[int, str]:
	before = path.lstat()
	if not stat.S_ISREG(before.st_mode) or stat.S_ISLNK(before.st_mode) or before.st_size > maximum_bytes:
		raise ValidationEligibilityError("eligibility.file_not_bounded_regular")
	digest = hashlib.sha256()
	read_size = 0
	with path.open("rb") as stream:
		handle_before = os.fstat(stream.fileno())
		if _stat_identity(before) != _stat_identity(handle_before):
			raise ValidationEligibilityDriftError("eligibility.file_open_drift")
		while True:
			_validate_deadline(deadline)
			chunk = stream.read(1024 * 1024)
			if not chunk:
				break
			read_size += len(chunk)
			if read_size > maximum_bytes:
				raise ValidationEligibilityError("eligibility.file_size_limit")
			digest.update(chunk)
		handle_after = os.fstat(stream.fileno())
	after = path.lstat()
	if (
		read_size != before.st_size
		or _stat_identity(handle_before) != _stat_identity(handle_after)
		or _stat_identity(handle_after) != _stat_identity(after)
	):
		raise ValidationEligibilityDriftError("eligibility.file_read_drift")
	return read_size, digest.hexdigest()


def _validated_fingerprint(value: Any) -> str:
	if type(value) is not str or len(value) != 64 or any(character not in "0123456789abcdef" for character in value):
		raise ValidationEligibilityError("eligibility.workspace_fingerprint")
	return value


def _validated_optional_fingerprint(value: Any) -> str | None:
	return None if value is None else _validated_fingerprint(value)


def _reject_json_constant(_value: str) -> None:
	raise ValueError("non-finite JSON constant")


def _strict_json_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
	result: dict[str, Any] = {}
	for key, value in pairs:
		if key in result:
			raise ValueError("duplicate JSON key")
		result[key] = value
	return result


__all__ = [
	"ALLOWED_CHECKS",
	"ELIGIBILITY_ERROR_CODES",
	"ELIGIBILITY_REPORT_FIELDS",
	"ValidationEligibilityDeadlineError",
	"ValidationEligibilityError",
	"make_eligibility_failure",
	"run_eligibility_shadow",
	"validate_eligibility_report",
]
