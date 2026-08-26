#!/usr/bin/env python3
"""Execute one observational GUT shard inside a parent-owned private workspace.

The worker is deliberately not a maintenance check.  It accepts one closed,
parent-authored in-memory request, executes import then exactly one selected GUT
process, and returns one closed report.  It never reads or writes reusable test
evidence.
"""

from __future__ import annotations

import hashlib
import json
import math
import os
from pathlib import Path
import stat
import sys
import threading
import time
from typing import Any, Callable, Iterable, Mapping, Sequence


TOOLS_ROOT = Path(__file__).resolve().parent
if str(TOOLS_ROOT) not in sys.path:
	sys.path.insert(0, str(TOOLS_ROOT))

import gf_gut_sharding
from gf_process_authority import FrozenGitProcess
from gf_process_authority import FrozenProcessAuthority
from gf_process_authority import FrozenProcessEnvironment
import gf_process_supervisor
from gf_executable_resolution import FrozenEnvironmentError
from gf_executable_resolution import remove_owned_environment_value
from gf_executable_resolution import set_owned_environment_value


SCHEMA_VERSION = 1
CANDIDATE_MODE = "single_shard_observation"
CONTROL_MODE = "authoritative_control_observation"
MODES = frozenset({CANDIDATE_MODE, CONTROL_MODE})
MODE = CANDIDATE_MODE
CONTROL_SHARD_NAME = "gut-authoritative-control"
CONTROL_ROLE = "control"
EXECUTION_POLICY = "execute_selected_shard_no_reuse"
MAX_REPORT_BYTES = 16 * 1024 * 1024
MAX_ISSUES = 20
MAX_ISSUE_TEXT_BYTES = 1024
MAX_CAPTURE_CHARACTERS = 16 * 1024 * 1024
MAX_GODOT_LOG_BYTES = 16 * 1024 * 1024
MAX_REMAINING_SECONDS = 6 * 60 * 60
MAX_PHASE_TIMEOUT_SECONDS = 2 * 60 * 60
MIN_PHASE_TIMEOUT_SECONDS = 0.001
WORKER_NON_INVENTORY_PREFLIGHT_ALLOWANCE_SECONDS = 30
WORKER_PREFLIGHT_ALLOWANCE_SECONDS = (
	math.ceil(2 * gf_gut_sharding.INVENTORY_DEADLINE_SECONDS)
	+ WORKER_NON_INVENTORY_PREFLIGHT_ALLOWANCE_SECONDS
)
WORKER_FINALIZE_ALLOWANCE_SECONDS = 30
MAX_GUT_SHARD_ARGV_ITEMS = 2048
MAX_GUT_SHARD_ARGV_UTF8_BYTES = 1024 * 1024
OBSERVATION_ROOT_RELATIVE = Path("build") / "gut-sharding"
OBSERVATION_JUNIT_FILENAME = "gut-authoritative.xml"
OBSERVATION_PROVENANCE_FILENAME = "gut-authoritative-provenance.json"
OBSERVATION_NONCE_ENVIRONMENT = "GF_GUT_SHARD_OBSERVATION_NONCE"
OBSERVATION_PATH_ENVIRONMENT = "GF_GUT_SHARD_OBSERVATION_PATH"
PRIVATE_ENVIRONMENT_FALLBACK_NONCE_CHARACTERS = 16
WINDOWS_LEGACY_MAX_PATH_CHARACTERS = 259
WINDOWS_GUT_KNOWN_DEEPEST_RELATIVE_PATH_CHARACTERS = 202
WINDOWS_GUT_PATH_GROWTH_MARGIN_CHARACTERS = 10
# The compact production layout keeps the deepest currently-owned GF path plus
# an explicit growth margin within the legacy Windows API budget even when the
# validation root reaches its 19-character owner limit.
WINDOWS_GUT_USER_PATH_RESERVE_CHARACTERS = (
	WINDOWS_GUT_KNOWN_DEEPEST_RELATIVE_PATH_CHARACTERS
	+ WINDOWS_GUT_PATH_GROWTH_MARGIN_CHARACTERS
)

_FORBIDDEN_SELECTION_PREFIXES = (
	"-gdir",
	"-ginclude_subdirs",
	"-gtest",
	"-gconfig",
	"-gpre_run_script",
	"-gpost_run_script",
	"-gjunit_xml_file",
)

REQUEST_KEYS = frozenset({
	"schema_version",
	"nonce",
	"mode",
	"shard_name",
	"role",
	"scripts",
	"workspace_path",
	"workspace_fingerprint",
	"runtime_source_digest",
	"manifest_digest",
	"inventory_digest",
	"remaining_seconds",
	"import_timeout_seconds",
	"gut_timeout_seconds",
})
REPORT_KEYS = frozenset({
	"schema_version",
	"ok",
	"request",
	"request_digest",
	"selection_digest",
	"selection_count",
	"import_run_count",
	"gut_run_count",
	"import_result",
	"gut_result",
	"junit",
	"junit_digest",
	"lifecycle_ok",
	"process_boundary_quiescent",
	"worker_cleanup_complete",
	"workspace_cleanup_permitted",
	"continuation_safe",
	"duration_seconds",
	"observation_policy",
	"issues",
})
PHASE_RESULT_KEYS = frozenset({
	"ok",
	"exit_code",
	"timed_out",
	"cancelled",
	"duration_seconds",
})
POLICY_KEYS = frozenset({
	"observation_only",
	"execution_policy",
	"skip_count",
	"cache_read_count",
	"cache_write_count",
	"reuse_count",
	"persistence_count",
})
ISSUE_KEYS = frozenset({"kind", "message", "phase"})

_HEX_64 = frozenset("0123456789abcdef")
WORKSPACE_OWNERSHIP_ERROR_CODES = frozenset({
	"worker_directory_identity_invalid",
	"worker_input_drift",
	"worker_input_invalid",
	"worker_log_path_invalid",
	"worker_managed_directory_replaced",
	"worker_log_root_replaced",
	"worker_path_invalid",
	"worker_workspace_replaced",
	"worker_workspace_publication_identity_mismatch",
})
CONTINUATION_SAFE_ERROR_CODES = frozenset({
	"worker_import_failed",
	"worker_gut_failed",
	"worker_junit_rejected",
})


class GutShardWorkerError(ValueError):
	"""Closed, stable worker failure safe to include in a report."""

	def __init__(self, code: str, message: str, phase: str = "preflight") -> None:
		super().__init__(f"{code}: {message}")
		self.code = code
		self.message = message
		self.phase = phase


def canonical_json_bytes(value: Any) -> bytes:
	try:
		return json.dumps(
			value,
			ensure_ascii=False,
			allow_nan=False,
			separators=(",", ":"),
			sort_keys=True,
		).encode("utf-8")
	except (TypeError, ValueError) as error:
		raise GutShardWorkerError(
			"worker_json_invalid",
			"Worker data cannot be represented as finite canonical JSON.",
		) from error


def canonical_digest(value: Any) -> str:
	return hashlib.sha256(canonical_json_bytes(value)).hexdigest()


def build_gut_shard_argv(
	base_command: Sequence[str],
	*,
	config_path: str,
	pre_run_script: str,
	post_run_script: str,
	scripts: Iterable[str],
	junit_xml_path: str | None = None,
) -> tuple[str, ...]:
	"""Build one bounded, exact-script-selected GUT command."""

	base = _validate_argv(base_command, "base command")
	if any(
		argument == prefix or argument.startswith(f"{prefix}=")
		for argument in base
		for prefix in _FORBIDDEN_SELECTION_PREFIXES
	):
		raise GutShardWorkerError(
			"gut_shard_base_selection_forbidden",
			"The shard base command must not contain GUT selection or owned-output arguments.",
		)
	config = _validate_resource_path(config_path, "config_path")
	pre_run = _validate_resource_path(pre_run_script, "pre_run_script")
	post_run = _validate_resource_path(post_run_script, "post_run_script")
	normalized_scripts: list[str] = []
	for script in scripts:
		if type(script) is not str:
			raise GutShardWorkerError(
				"gut_shard_scripts_invalid",
				"Every selected GUT script must be a string.",
			)
		try:
			normalized = gf_gut_sharding._normalize_test_script_path(script)  # noqa: SLF001
		except gf_gut_sharding.GutShardingError as error:
			raise GutShardWorkerError(
				"gut_shard_scripts_invalid",
				"A selected GUT script is not canonical.",
			) from error
		if normalized != script or "," in script:
			raise GutShardWorkerError(
				"gut_shard_scripts_invalid",
				"Selected GUT scripts must be canonical and unambiguous for vendored optparse.",
			)
		normalized_scripts.append(script)
	if (
		not normalized_scripts
		or normalized_scripts != sorted(normalized_scripts)
		or len(set(normalized_scripts)) != len(normalized_scripts)
	):
		raise GutShardWorkerError(
			"gut_shard_scripts_invalid",
			"Selected GUT scripts must be a non-empty sorted unique sequence.",
		)
	result = [
		*base,
		f"-gconfig={config}",
		f"-gpre_run_script={pre_run}",
		f"-gpost_run_script={post_run}",
	]
	for script in normalized_scripts:
		# The vendored GUT optparse consumes this as two argv tokens.  Repeating the
		# option preserves exact script identity without comma-separated ambiguity.
		result.extend(("-gtest", script))
	if junit_xml_path is not None:
		result.append(f"-gjunit_xml_file={_validate_junit_path(junit_xml_path)}")
	result.append("-gexit")
	return _validate_argv(result, "shard command")


def validate_request(value: Any) -> dict[str, Any]:
	if type(value) is not dict or set(value) != REQUEST_KEYS:
		raise GutShardWorkerError("worker_request_schema_invalid", "Request fields do not match the closed schema.")
	request = dict(value)
	if (
		type(request["schema_version"]) is not int
		or request["schema_version"] != SCHEMA_VERSION
	):
		raise GutShardWorkerError("worker_request_schema_unsupported", "Request schema_version is unsupported.")
	if type(request["mode"]) is not str or request["mode"] not in MODES:
		raise GutShardWorkerError(
			"worker_request_mode_invalid",
			"Request mode is not a supported observational execution mode.",
		)
	nonce = request["nonce"]
	if (
		type(nonce) is not str
		or len(nonce) != 64
		or any(character not in _HEX_64 for character in nonce)
	):
		raise GutShardWorkerError(
			"worker_request_nonce_invalid",
			"Request nonce must be exactly 64 lowercase hexadecimal characters.",
		)
	for key in ("shard_name", "role"):
		value_text = request[key]
		if type(value_text) is not str or not value_text or len(value_text.encode("utf-8")) > 128:
			raise GutShardWorkerError("worker_request_identity_invalid", f"Request {key} is invalid.")
	for key in (
		"workspace_fingerprint",
		"runtime_source_digest",
		"manifest_digest",
		"inventory_digest",
	):
		if not _is_sha256(request[key]):
			raise GutShardWorkerError("worker_request_digest_invalid", f"Request {key} must be lowercase SHA-256.")
	for key in ("remaining_seconds", "import_timeout_seconds", "gut_timeout_seconds"):
		seconds = request[key]
		if type(seconds) not in (int, float) or not math.isfinite(float(seconds)) or float(seconds) <= 0.0:
			raise GutShardWorkerError("worker_request_timeout_invalid", f"Request {key} must be positive and finite.")
		request[key] = float(seconds)
	if request["remaining_seconds"] > MAX_REMAINING_SECONDS:
		raise GutShardWorkerError(
			"worker_request_timeout_invalid",
			"Request remaining_seconds exceeds the worker bound.",
		)
	for key in ("import_timeout_seconds", "gut_timeout_seconds"):
		if request[key] > MAX_PHASE_TIMEOUT_SECONDS:
			raise GutShardWorkerError(
				"worker_request_timeout_invalid",
				f"Request {key} exceeds the worker phase bound.",
			)
	scripts = request["scripts"]
	if type(scripts) is not list or not scripts:
		raise GutShardWorkerError("worker_request_scripts_invalid", "Request scripts must be a non-empty array.")
	if len(scripts) > gf_gut_sharding.MAX_INVENTORY_SCRIPTS:
		raise GutShardWorkerError("worker_request_scripts_invalid", "Request script count exceeds the inventory limit.")
	normalized_scripts: list[str] = []
	for script in scripts:
		if type(script) is not str:
			raise GutShardWorkerError("worker_request_scripts_invalid", "Every request script must be a string.")
		try:
			normalized = gf_gut_sharding._normalize_test_script_path(script)  # noqa: SLF001
		except gf_gut_sharding.GutShardingError as error:
			raise GutShardWorkerError("worker_request_scripts_invalid", "Request contains a non-canonical test script.") from error
		if normalized != script:
			raise GutShardWorkerError("worker_request_scripts_invalid", "Request test scripts must already be canonical.")
		normalized_scripts.append(normalized)
	if normalized_scripts != sorted(normalized_scripts) or len(set(normalized_scripts)) != len(normalized_scripts):
		raise GutShardWorkerError("worker_request_scripts_invalid", "Request scripts must be sorted and unique.")
	request["scripts"] = normalized_scripts
	workspace_text = request["workspace_path"]
	if type(workspace_text) is not str or "\x00" in workspace_text:
		raise GutShardWorkerError("worker_workspace_path_invalid", "Request workspace_path must be an absolute path string.")
	workspace = Path(workspace_text)
	if not workspace.is_absolute():
		raise GutShardWorkerError("worker_workspace_path_invalid", "Request workspace_path must be absolute.")
	canonical_workspace = str(Path(os.path.abspath(os.path.normpath(workspace))))
	if workspace_text != canonical_workspace:
		raise GutShardWorkerError(
			"worker_workspace_path_invalid",
			"Request workspace_path must already use its canonical absolute form.",
		)
	request["workspace_path"] = canonical_workspace
	canonical_json_bytes(request)
	return request


def _validate_argv(value: Sequence[str], label: str) -> tuple[str, ...]:
	if type(value) not in (list, tuple) or not value:
		raise GutShardWorkerError("gut_shard_argv_invalid", f"{label} must be non-empty.")
	arguments: list[str] = []
	for argument in value:
		if type(argument) is not str or not argument or "\x00" in argument:
			raise GutShardWorkerError(
				"gut_shard_argv_invalid",
				f"{label} contains an invalid argument.",
			)
		arguments.append(argument)
	if (
		len(arguments) > MAX_GUT_SHARD_ARGV_ITEMS
		or sum(len(argument.encode("utf-8")) + 1 for argument in arguments)
		> MAX_GUT_SHARD_ARGV_UTF8_BYTES
	):
		raise GutShardWorkerError(
			"gut_shard_argv_budget_exceeded",
			f"{label} exceeds the bounded argv budget.",
		)
	return tuple(arguments)


def _validate_resource_path(value: str, label: str) -> str:
	if (
		type(value) is not str
		or not value.startswith("res://")
		or "\x00" in value
		or "\\" in value
		or "," in value
	):
		raise GutShardWorkerError(
			"gut_shard_resource_path_invalid",
			f"{label} must be one canonical res:// path.",
		)
	parts = value.removeprefix("res://").split("/")
	if not parts or any(part in {"", ".", ".."} for part in parts):
		raise GutShardWorkerError(
			"gut_shard_resource_path_invalid",
			f"{label} contains an unsafe component.",
		)
	return value


def _validate_junit_path(value: str) -> str:
	if type(value) is not str or "\x00" in value or "," in value:
		raise GutShardWorkerError(
			"gut_shard_junit_path_invalid",
			"JUnit output path is invalid.",
		)
	path = Path(value)
	if not path.is_absolute() or path.suffix.casefold() != ".xml":
		raise GutShardWorkerError(
			"gut_shard_junit_path_invalid",
			"JUnit output must be an absolute .xml path.",
		)
	return Path(os.path.abspath(path)).as_posix()


def run_worker(
	request: Mapping[str, Any],
	*,
	process_authority: FrozenProcessAuthority,
	process_runner: Callable[..., Any] = gf_process_supervisor.run_supervised_process,
	result_adapter: Callable[..., Any] | None = None,
	cancellation_event: threading.Event | None = None,
	expected_workspace_identity: tuple[int, int, int] | None = None,
) -> dict[str, Any]:
	"""Execute import then one selected GUT command and return a closed report."""
	if not isinstance(process_authority, FrozenProcessAuthority):
		raise TypeError("GUT shard worker requires one frozen process authority.")
	duration_started = time.perf_counter()
	deadline_started = time.monotonic()
	normalized = validate_request(dict(request))
	deadline = deadline_started + normalized["remaining_seconds"]
	workspace = Path(normalized["workspace_path"])
	report = _empty_report(normalized)
	invocation_root: Path | None = None
	invocation_chain: tuple[tuple[Path, tuple[int, int, int]], ...] | None = None
	private_environment_root: Path | None = None
	private_environment_identity: os.stat_result | None = None
	workspace_identity: tuple[int, int, int] | None = None
	workspace_identity_chain_valid = False
	managed_log_chain: tuple[tuple[Path, tuple[int, int, int]], ...] | None = None
	managed_log_root_identity: tuple[int, int, int] | None = None
	try:
		_check_worker_cancelled(cancellation_event, "worker")
		workspace = _validate_workspace(workspace)
		workspace_identity = _validate_publication_identity_token(
			expected_workspace_identity,
		)
		_validate_workspace_binding(
			workspace,
			normalized["workspace_fingerprint"],
			workspace_identity,
			git_process=process_authority.git,
			deadline=deadline,
		)
		workspace_identity_chain_valid = True
		_check_worker_cancelled(cancellation_event, "preflight")
		_validate_shard_binding(
			workspace,
			normalized,
			workspace_identity,
			deadline=deadline,
		)
		_check_worker_cancelled(cancellation_event, "preflight")
		_assert_workspace_identity(workspace, workspace_identity)
		invocation_root = _create_invocation_root(workspace, normalized["nonce"])
		invocation_chain = _snapshot_managed_directory_chain(
			workspace,
			invocation_root,
			workspace_identity,
		)
		junit_path = invocation_root / OBSERVATION_JUNIT_FILENAME
		provenance_path = invocation_root / OBSERVATION_PROVENANCE_FILENAME
		requested_private_environment_root = _private_environment_root_path(
			workspace,
			normalized["nonce"],
		)
		private_environment_root = requested_private_environment_root
		report["worker_cleanup_complete"] = False
		environment = _private_environment(
			workspace,
			requested_private_environment_root,
			process_environment=process_authority.environment,
			observation_nonce=normalized["nonce"],
		)
		# _private_environment owns rollback until it returns.  Track the root here
		# only after construction succeeded, avoiding a second unowned cleanup on a
		# partially-created-root failure.
		private_environment_identity = private_environment_root.lstat()
		managed_log_root = _create_real_directory_chain(
			workspace,
			Path("ai_analysis") / "godot_logs",
		)
		managed_log_chain = _snapshot_managed_directory_chain(
			workspace,
			managed_log_root,
			workspace_identity,
		)
		managed_log_root_identity = managed_log_chain[-1][1]
		_assert_managed_directory_chain(invocation_chain)
		_assert_managed_directory_chain(managed_log_chain)
		_check_worker_cancelled(cancellation_event, "import")
		_require_remaining_budget(
			deadline,
			float(
				normalized["import_timeout_seconds"]
				+ normalized["gut_timeout_seconds"]
				+ WORKER_FINALIZE_ALLOWANCE_SECONDS
			),
			"import",
		)
		import_timeout = _phase_timeout(deadline, normalized["import_timeout_seconds"], "import")
		import_command = (
			"godot",
			"--headless",
			"--log-file",
			str(managed_log_root / f"gut-shard-{normalized['nonce']}-import.log"),
			"--path",
			".",
			"--import",
		)
		report["import_run_count"] = 1
		report["import_result"] = _failed_attempt_phase()
		report["process_boundary_quiescent"] = False
		import_result, import_phase, _import_lifecycle = _run_authoritative_phase(
			"godot_import",
			import_command,
			workspace=workspace,
			timeout_seconds=import_timeout,
			environment=environment,
			process_runner=process_runner,
			result_adapter=result_adapter,
			owned_log_root=managed_log_root,
			expected_workspace_identity=workspace_identity,
			expected_log_chain=managed_log_chain,
			expected_log_root_identity=managed_log_root_identity,
			cancellation_event=cancellation_event,
		)
		report["import_result"] = import_phase
		report["process_boundary_quiescent"] = _process_boundary_quiescent(import_result)
		_assert_managed_directory_chain(invocation_chain)
		_assert_managed_directory_chain(managed_log_chain)
		_check_worker_cancelled(cancellation_event, "import")
		_check_worker_deadline(deadline, "import")
		if not report["import_result"]["ok"] or not report["process_boundary_quiescent"]:
			raise GutShardWorkerError("worker_import_failed", "Private workspace import did not pass authority checks.", "import")

		_assert_workspace_identity(workspace, workspace_identity)
		_check_worker_cancelled(cancellation_event, "gut")
		_require_remaining_budget(
			deadline,
			float(
				normalized["gut_timeout_seconds"]
				+ WORKER_FINALIZE_ALLOWANCE_SECONDS
			),
			"gut",
		)
		gut_timeout = _phase_timeout(deadline, normalized["gut_timeout_seconds"], "gut")
		if normalized["mode"] == CONTROL_MODE:
			gut_command = _control_gut_command(
				normalized["nonce"],
				junit_path,
				managed_log_root,
			)
		else:
			base_command = (
				"godot",
				"--headless",
				"--log-file",
				str(managed_log_root / f"gut-shard-{normalized['nonce']}-gut.log"),
				"--path",
				".",
				"-s",
				"res://tests/gf_core/support/gf_gut_cli.gd",
			)
			gut_command = build_gut_shard_argv(
				base_command,
				config_path="res://.gutconfig.json",
				pre_run_script="res://tests/gf_core/support/gf_gut_pre_run_hook.gd",
				post_run_script="res://tests/gf_core/support/gf_gut_post_run_hook.gd",
				scripts=tuple(normalized["scripts"]),
				junit_xml_path=junit_path.as_posix(),
			)
		report["gut_run_count"] = 1
		report["gut_result"] = _failed_attempt_phase()
		report["process_boundary_quiescent"] = False
		gut_result, gut_phase, lifecycle_report = _run_authoritative_phase(
			"gut",
			gut_command,
			workspace=workspace,
			timeout_seconds=gut_timeout,
			environment=environment,
			process_runner=process_runner,
			result_adapter=result_adapter,
			owned_log_root=managed_log_root,
			expected_workspace_identity=workspace_identity,
			expected_log_chain=managed_log_chain,
			expected_log_root_identity=managed_log_root_identity,
			cancellation_event=cancellation_event,
		)
		report["gut_result"] = gut_phase
		report["process_boundary_quiescent"] = _process_boundary_quiescent(gut_result)
		_assert_managed_directory_chain(invocation_chain)
		_assert_managed_directory_chain(managed_log_chain)
		_check_worker_cancelled(cancellation_event, "gut")
		_check_worker_deadline(deadline, "gut")
		report["lifecycle_ok"] = bool(lifecycle_report and lifecycle_report.get("ok") is True)
		gut_failed = (
			report["gut_result"]["ok"] is not True
			or report["process_boundary_quiescent"] is not True
			or report["lifecycle_ok"] is not True
		)
		# A non-zero GUT exit may still have published complete, useful failure
		# evidence.  Consume it only after positive process-boundary proof and
		# never let a missing/invalid diagnostic pair replace worker_gut_failed as
		# the primary result.  Ownership, cancellation, and deadline failures are
		# deliberately outside that diagnostic-only suppression.
		if report["process_boundary_quiescent"] is True:
			_check_worker_cancelled(cancellation_event, "junit")
			_assert_workspace_identity(workspace, workspace_identity)
			junit: dict[str, Any] | None = None
			try:
				junit = _parse_published_junit_observation(
					junit_path,
					provenance_path,
					nonce=normalized["nonce"],
					expected_scripts=tuple(normalized["scripts"]),
					invocation_chain=invocation_chain,
				)
				if (
					junit.get("input_complete") is not True
					or junit.get("ok") is not True
				):
					raise GutShardWorkerError(
						"worker_junit_rejected",
						"Selected GUT JUnit report is incomplete or invalid.",
						"junit",
					)
			except GutShardWorkerError as error:
				if not gut_failed or error.code != "worker_junit_rejected":
					raise
				junit = None
			_assert_managed_directory_chain(invocation_chain)
			_assert_managed_directory_chain(managed_log_chain)
			_assert_workspace_identity(workspace, workspace_identity)
			_check_worker_cancelled(cancellation_event, "junit")
			_check_worker_deadline(deadline, "junit")
			if junit is not None:
				report["junit"] = junit
				report["junit_digest"] = canonical_digest(junit)
		if gut_failed:
			raise GutShardWorkerError(
				"worker_gut_failed",
				"Selected GUT shard did not pass authority checks.",
				"gut",
			)
		report["ok"] = True
	except GutShardWorkerError as error:
		if error.code in WORKSPACE_OWNERSHIP_ERROR_CODES:
			workspace_identity_chain_valid = False
		_append_issue(report, error)
	except Exception as error:  # noqa: BLE001 - closed in-memory worker boundary
		if workspace_identity is not None:
			workspace_identity_chain_valid = False
		_append_issue(report, GutShardWorkerError("worker_execution_failed", _safe_error_message(error), "worker"))
	finally:
		if private_environment_root is not None:
			if private_environment_identity is None and not os.path.lexists(
				private_environment_root
			):
				report["worker_cleanup_complete"] = True
			elif report["process_boundary_quiescent"] is not True:
				report["ok"] = False
				_append_issue(
					report,
					GutShardWorkerError(
						"worker_private_environment_retained",
						"Invocation-owned platform state was retained because the process boundary is not quiescent.",
						"cleanup",
					),
				)
			else:
				cleanup_error = _remove_private_environment_root(
					private_environment_root,
					private_environment_identity,
				)
				if cleanup_error:
					report["ok"] = False
					_append_issue(
						report,
						GutShardWorkerError(
							"worker_private_environment_cleanup_failed",
							"Invocation-owned platform state could not be cleaned safely.",
							"cleanup",
						),
					)
				else:
					report["worker_cleanup_complete"] = True
		cancelled = cancellation_event is not None and cancellation_event.is_set()
		if cancelled:
			report["ok"] = False
			if not any(issue["kind"] == "worker_cancelled" for issue in report["issues"]):
				_append_issue(
					report,
					GutShardWorkerError(
						"worker_cancelled",
						"Worker cancellation was requested.",
						"worker",
					),
				)
		elif time.monotonic() >= deadline:
			report["ok"] = False
			_append_issue(
				report,
				GutShardWorkerError(
					"worker_deadline_exhausted",
					"Worker-local deadline expired before the report was finalized.",
					"worker",
				),
			)
		if workspace_identity_chain_valid and workspace_identity is not None:
			try:
				_assert_workspace_identity(workspace, workspace_identity)
				if invocation_chain is not None:
					_assert_managed_directory_chain(invocation_chain)
				if managed_log_chain is not None:
					_assert_managed_directory_chain(managed_log_chain)
			except GutShardWorkerError as error:
				workspace_identity_chain_valid = False
				report["ok"] = False
				_append_issue(report, error)
		report["workspace_cleanup_permitted"] = (
			workspace_identity_chain_valid
			and report["process_boundary_quiescent"] is True
		)
		report["continuation_safe"] = _derive_continuation_safe(report)
	report["duration_seconds"] = _final_report_duration_seconds(
		report,
		duration_started,
	)
	return report


def validate_report(value: Any) -> dict[str, Any]:
	"""Validate one closed report and return a deeply detached mapping."""

	validate_report_shape(value)
	# Canonical JSON is already required by the schema.  A round trip guarantees
	# no mutable request/JUnit/issue object remains shared with an untrusted caller.
	detached = json.loads(canonical_json_bytes(value).decode("utf-8"))
	if type(detached) is not dict:  # pragma: no cover - guarded by validation
		raise GutShardWorkerError(
			"worker_report_schema_invalid",
			"Report did not detach to an object.",
			"report",
		)
	return detached


def validate_report_shape(report: Mapping[str, Any]) -> None:
	if type(report) is not dict or set(report) != REPORT_KEYS:
		raise GutShardWorkerError("worker_report_schema_invalid", "Report fields do not match the closed schema.", "report")
	if (
		type(report["schema_version"]) is not int
		or report["schema_version"] != SCHEMA_VERSION
		or type(report["ok"]) is not bool
	):
		raise GutShardWorkerError("worker_report_schema_invalid", "Report schema values are invalid.", "report")
	try:
		normalized_request = validate_request(report["request"])
	except GutShardWorkerError as error:
		raise GutShardWorkerError(
			"worker_report_schema_invalid",
			"Embedded request is invalid.",
			"report",
		) from error
	if canonical_json_bytes(normalized_request) != canonical_json_bytes(report["request"]):
		raise GutShardWorkerError(
			"worker_report_schema_invalid",
			"Embedded request must already use its normalized closed form.",
			"report",
		)
	if report["request_digest"] != canonical_digest(report["request"]):
		raise GutShardWorkerError("worker_report_digest_invalid", "Report request_digest is inconsistent.", "report")
	if report["selection_digest"] != canonical_digest(report["request"]["scripts"]):
		raise GutShardWorkerError("worker_report_digest_invalid", "Report selection_digest is invalid.", "report")
	if (
		type(report["selection_count"]) is not int
		or report["selection_count"] != len(report["request"]["scripts"])
	):
		raise GutShardWorkerError(
			"worker_report_count_invalid",
			"Report selection_count is inconsistent with the request.",
			"report",
		)
	for key in ("import_run_count", "gut_run_count"):
		if type(report[key]) is not int or report[key] not in (0, 1):
			raise GutShardWorkerError(
				"worker_report_count_invalid",
				f"Report {key} must be exactly 0 or 1.",
				"report",
			)
	if report["gut_run_count"] > report["import_run_count"]:
		raise GutShardWorkerError(
			"worker_report_count_invalid",
			"GUT cannot run before the import phase.",
			"report",
		)
	for count_key, phase in (
		("import_run_count", report["import_result"]),
		("gut_run_count", report["gut_result"]),
	):
		if type(phase) is not dict or set(phase) != PHASE_RESULT_KEYS:
			raise GutShardWorkerError("worker_report_schema_invalid", "Phase result fields are invalid.", "report")
		_validate_phase_result(phase)
		if report[count_key] == 0 and phase != _not_run_phase():
			raise GutShardWorkerError(
				"worker_report_count_invalid",
				"A phase that did not run must use the exact not-run result.",
				"report",
			)
	if type(report["observation_policy"]) is not dict or set(report["observation_policy"]) != POLICY_KEYS:
		raise GutShardWorkerError("worker_report_schema_invalid", "Observation policy fields are invalid.", "report")
	policy = report["observation_policy"]
	if (
		policy["observation_only"] is not True
		or policy["execution_policy"] != EXECUTION_POLICY
		or any(
			type(policy[key]) is not int or policy[key] != 0
			for key in (
				"skip_count",
				"cache_read_count",
				"cache_write_count",
				"reuse_count",
				"persistence_count",
			)
		)
	):
		raise GutShardWorkerError("worker_report_policy_invalid", "Worker reports may not reuse or persist validation evidence.", "report")
	if (
		type(report["lifecycle_ok"]) is not bool
		or type(report["process_boundary_quiescent"]) is not bool
		or type(report["worker_cleanup_complete"]) is not bool
		or type(report["workspace_cleanup_permitted"]) is not bool
		or type(report["continuation_safe"]) is not bool
	):
		raise GutShardWorkerError(
			"worker_report_schema_invalid",
			"Lifecycle, process-boundary, and worker cleanup results must be booleans.",
			"report",
		)
	if (
		type(report["duration_seconds"]) is not float
		or not math.isfinite(report["duration_seconds"])
		or report["duration_seconds"] < 0.0
		or report["duration_seconds"]
		< report["import_result"]["duration_seconds"]
		+ report["gut_result"]["duration_seconds"]
	):
		raise GutShardWorkerError(
			"worker_report_duration_invalid",
			"Report duration is not a finite total covering both phases.",
			"report",
		)
	_validate_report_junit(report)
	if type(report["issues"]) is not list or len(report["issues"]) > MAX_ISSUES:
		raise GutShardWorkerError("worker_report_schema_invalid", "Report issues are invalid.", "report")
	for issue in report["issues"]:
		if (
			type(issue) is not dict
			or set(issue) != ISSUE_KEYS
			or any(
				type(value) is not str
				or not value
				or len(value.encode("utf-8")) > MAX_ISSUE_TEXT_BYTES
				for value in issue.values()
			)
		):
			raise GutShardWorkerError("worker_report_schema_invalid", "Report issue fields are invalid.", "report")
	cleanup_issue_exists = any(issue["phase"] == "cleanup" for issue in report["issues"])
	if report["worker_cleanup_complete"] == cleanup_issue_exists:
		raise GutShardWorkerError(
			"worker_report_cleanup_invalid",
			"Worker cleanup completion must exactly match structured cleanup issues.",
			"report",
		)
	if report["workspace_cleanup_permitted"] and (
		report["process_boundary_quiescent"] is not True
		or any(
			issue["kind"] in WORKSPACE_OWNERSHIP_ERROR_CODES
			for issue in report["issues"]
		)
	):
		raise GutShardWorkerError(
			"worker_report_cleanup_invalid",
			"Workspace cleanup permission contradicts process or ownership evidence.",
			"report",
		)
	if report["ok"] != (not report["issues"]):
		raise GutShardWorkerError("worker_report_status_invalid", "Report ok is inconsistent with issues.", "report")
	if report["ok"] and not (
		report["import_run_count"] == 1
		and report["gut_run_count"] == 1
		and report["import_result"]["ok"]
		and report["gut_result"]["ok"]
		and report["junit"] is not None
		and report["lifecycle_ok"]
		and report["process_boundary_quiescent"]
		and report["worker_cleanup_complete"]
		and report["workspace_cleanup_permitted"]
	):
		raise GutShardWorkerError(
			"worker_report_status_invalid",
			"Successful report lacks complete execution evidence.",
			"report",
		)
	if report["ok"] and report["continuation_safe"] is not True:
		raise GutShardWorkerError(
			"worker_report_status_invalid",
			"Successful report must be safe for the parent to continue scheduling.",
			"report",
		)
	expected_continuation_safe = _derive_continuation_safe(report)
	if report["continuation_safe"] is not expected_continuation_safe:
		raise GutShardWorkerError(
			"worker_report_status_invalid",
			"Report continuation_safe is inconsistent with closed failure and ownership evidence.",
			"report",
		)
	payload = canonical_json_bytes(report)
	if len(payload) + 1 > MAX_REPORT_BYTES:
		raise GutShardWorkerError(
			"worker_report_too_large",
			"Worker report exceeds its byte limit.",
			"report",
		)


def _validate_phase_result(phase: Mapping[str, Any]) -> None:
	if (
		type(phase["ok"]) is not bool
		or type(phase["exit_code"]) is not int
		or type(phase["timed_out"]) is not bool
		or type(phase["cancelled"]) is not bool
		or type(phase["duration_seconds"]) is not float
		or not math.isfinite(phase["duration_seconds"])
		or phase["duration_seconds"] < 0.0
		or (
			phase["ok"]
			and (
				phase["exit_code"] != 0
				or phase["timed_out"]
				or phase["cancelled"]
			)
		)
	):
		raise GutShardWorkerError(
			"worker_report_phase_invalid",
			"Phase result values are inconsistent.",
			"report",
		)


def _validate_report_junit(report: Mapping[str, Any]) -> None:
	junit = report["junit"]
	digest = report["junit_digest"]
	if junit is None:
		if digest is not None:
			raise GutShardWorkerError(
				"worker_report_junit_invalid",
				"Missing JUnit evidence cannot have a digest.",
				"report",
			)
		return
	if type(junit) is not dict or digest != canonical_digest(junit):
		raise GutShardWorkerError(
			"worker_report_junit_invalid",
			"JUnit report or digest is invalid.",
			"report",
		)
	if not (
		report["import_run_count"] == 1
		and report["gut_run_count"] == 1
		and report["import_result"]["ok"] is True
		and report["process_boundary_quiescent"] is True
	):
		raise GutShardWorkerError(
			"worker_report_junit_invalid",
			"JUnit evidence requires a completed, quiescent GUT execution.",
			"report",
		)
	try:
		gf_gut_sharding._validate_observation_junit_report(junit)  # noqa: SLF001
	except gf_gut_sharding.GutShardingError as error:
		raise GutShardWorkerError(
			"worker_report_junit_invalid",
			"JUnit report does not match the closed parser schema.",
			"report",
		) from error
	if [script["script"] for script in junit["scripts"]] != report["request"]["scripts"]:
		raise GutShardWorkerError(
			"worker_report_junit_invalid",
			"JUnit scripts do not match the requested selection.",
			"report",
		)
	status_counts = junit["status_counts"]
	if report["ok"] and (
		junit["failure_test_count"] != 0
		or junit["failure_assertion_count"] != 0
		or junit["pending_assertion_count"] != 0
		or any(
			status_counts[status] != 0
			for status in ("failed", "pending", "no_asserts", "skipped")
		)
	):
		raise GutShardWorkerError(
			"worker_report_junit_failed",
			"Successful worker evidence requires every selected GUT test to pass with assertions.",
			"report",
		)


def _derive_continuation_safe(report: Mapping[str, Any]) -> bool:
	"""Derive whether another shard may start from closed worker evidence only."""

	if report.get("ok") is True:
		return True
	if not (
		report.get("process_boundary_quiescent") is True
		and report.get("worker_cleanup_complete") is True
		and report.get("workspace_cleanup_permitted") is True
	):
		return False
	issues = report.get("issues")
	if type(issues) is not list or len(issues) != 1 or type(issues[0]) is not dict:
		return False
	issue = issues[0]
	expected_phase = {
		"worker_import_failed": "import",
		"worker_gut_failed": "gut",
		"worker_junit_rejected": "junit",
	}.get(issue.get("kind"))
	if expected_phase is None or issue.get("phase") != expected_phase:
		return False
	import_result = report.get("import_result")
	gut_result = report.get("gut_result")
	if type(import_result) is not dict or type(gut_result) is not dict:
		return False
	if any(
		phase.get("timed_out") is True or phase.get("cancelled") is True
		for phase in (import_result, gut_result)
	):
		return False
	if issue["kind"] == "worker_import_failed":
		return (
			report.get("import_run_count") == 1
			and report.get("gut_run_count") == 0
			and import_result.get("ok") is False
		)
	if issue["kind"] == "worker_gut_failed":
		return (
			report.get("import_run_count") == 1
			and report.get("gut_run_count") == 1
			and import_result.get("ok") is True
			and gut_result.get("ok") is False
		)
	return (
		report.get("import_run_count") == 1
		and report.get("gut_run_count") == 1
		and import_result.get("ok") is True
		and gut_result.get("ok") is True
		and report.get("lifecycle_ok") is True
		and report.get("junit") is None
	)


def _empty_report(request: dict[str, Any]) -> dict[str, Any]:
	return {
		"schema_version": SCHEMA_VERSION,
		"ok": False,
		"request": request,
		"request_digest": canonical_digest(request),
		"selection_digest": canonical_digest(request["scripts"]),
		"selection_count": len(request["scripts"]),
		"import_run_count": 0,
		"gut_run_count": 0,
		"import_result": _not_run_phase(),
		"gut_result": _not_run_phase(),
		"junit": None,
		"junit_digest": None,
		"lifecycle_ok": False,
		"process_boundary_quiescent": True,
		"worker_cleanup_complete": True,
		"workspace_cleanup_permitted": False,
		"continuation_safe": False,
		"duration_seconds": 0.0,
		"observation_policy": {
			"observation_only": True,
			"execution_policy": EXECUTION_POLICY,
			"skip_count": 0,
			"cache_read_count": 0,
			"cache_write_count": 0,
			"reuse_count": 0,
			"persistence_count": 0,
		},
		"issues": [],
	}


def _run_authoritative_phase(
	phase: str,
	command: tuple[str, ...],
	*,
	workspace: Path,
	timeout_seconds: float,
	environment: dict[str, str],
	process_runner: Callable[..., Any],
	result_adapter: Callable[..., Any] | None,
	owned_log_root: Path,
	expected_workspace_identity: tuple[int, int, int],
	expected_log_chain: tuple[tuple[Path, tuple[int, int, int]], ...],
	expected_log_root_identity: tuple[int, int, int],
	cancellation_event: threading.Event | None = None,
) -> tuple[Any, dict[str, Any], dict[str, Any] | None]:
	"""Run one owned process and reuse the maintenance authority evaluator."""
	effective_command = list(command)
	maintenance: Any = None
	_assert_workspace_identity(workspace, expected_workspace_identity)
	owned_log_root = _validate_real_directory(owned_log_root, "owned log root")
	_assert_owned_directory_identity(
		owned_log_root,
		expected_log_root_identity,
		"worker_log_root_replaced",
		"Invocation-owned Godot log root changed during execution.",
		phase,
	)
	_assert_managed_directory_chain(expected_log_chain)
	log_path = _owned_command_log_path(effective_command, owned_log_root)
	if result_adapter is None:
		try:
			import gf_maintenance
		except ImportError as error:
			raise GutShardWorkerError(
				"worker_authority_unavailable",
				"The maintenance command evaluator is unavailable.",
				phase,
			) from error
		maintenance = gf_maintenance
		try:
			effective_command = maintenance.resolve_godot_command(
				effective_command,
				environment=environment,
				cwd=workspace,
			)
		except FrozenEnvironmentError as error:
			raise GutShardWorkerError(
				"worker_environment_invalid",
				"The authoritative process environment is invalid.",
				phase,
			) from error
		except (OSError, ValueError) as error:
			raise GutShardWorkerError(
				"worker_authority_preflight_failed",
				"The authoritative Godot command or log preflight failed.",
				phase,
			) from error
	result = process_runner(
		effective_command,
		cwd=workspace,
		timeout_seconds=timeout_seconds,
		environment=environment,
		max_stdout_characters=MAX_CAPTURE_CHARACTERS,
		max_stderr_characters=MAX_CAPTURE_CHARACTERS,
		cancellation_event=cancellation_event,
	)
	# Do not inspect logs, lifecycle markers, or any other filesystem evidence
	# until the supervisor has positively proved the owned process boundary quiet.
	# A descendant may still be writing those files when this proof is absent.
	if not _process_boundary_quiescent(result):
		return result, {
			"ok": False,
			"exit_code": (
				int(result.return_code)
				if type(getattr(result, "return_code", None)) is int
				and result.return_code != 0
				else 1
			),
			"timed_out": bool(getattr(result, "timed_out", False)),
			"cancelled": bool(getattr(result, "cancelled", False)),
			"duration_seconds": float(getattr(result, "duration_seconds", 0.0)),
		}, None
	_assert_workspace_identity(workspace, expected_workspace_identity)
	_assert_owned_directory_identity(
		owned_log_root,
		expected_log_root_identity,
		"worker_log_root_replaced",
		"Invocation-owned Godot log root changed during execution.",
		phase,
	)
	_assert_managed_directory_chain(expected_log_chain)
	if (
		getattr(result, "stdout_truncated", False) is True
		or getattr(result, "stderr_truncated", False) is True
	):
		raise GutShardWorkerError(
			"worker_phase_capture_truncated",
			"Authoritative phase output exceeded its bounded capture.",
			phase,
		)
	if result_adapter is not None:
		adapted = result_adapter(phase, result)
		if type(adapted) is not dict or set(adapted) != PHASE_RESULT_KEYS:
			raise GutShardWorkerError(
				"worker_result_adapter_invalid",
				"Authority adapter returned an invalid phase result.",
				phase,
			)
		lifecycle = _parse_lifecycle_for_test(result) if phase == "gut" else None
		_assert_workspace_identity(workspace, expected_workspace_identity)
		_assert_owned_directory_identity(
			owned_log_root,
			expected_log_root_identity,
			"worker_log_root_replaced",
			"Invocation-owned Godot log root changed during execution.",
			phase,
		)
		_assert_managed_directory_chain(expected_log_chain)
		return result, adapted, lifecycle
	try:
		log_payload = _read_stable_regular_file(
			log_path,
			MAX_GODOT_LOG_BYTES,
			f"{phase} Godot log",
		)
		_assert_workspace_identity(workspace, expected_workspace_identity)
		_assert_owned_directory_identity(
			owned_log_root,
			expected_log_root_identity,
			"worker_log_root_replaced",
			"Invocation-owned Godot log root changed during execution.",
			phase,
		)
		_assert_managed_directory_chain(expected_log_chain)
		log_output = log_payload.decode("utf-8", errors="replace")
		combined_stdout = maintenance.append_command_log_output(
			str(result.stdout),
			log_output,
		)
		evaluated = maintenance.completed_command_result(
			phase,
			effective_command,
			int(result.return_code),
			combined_stdout,
			str(result.stderr),
			[],
			float(result.duration_seconds),
			float(timeout_seconds),
			int(result.pid),
			False,
			tuple(result.notes),
		)
	except GutShardWorkerError as error:
		if error.code in WORKSPACE_OWNERSHIP_ERROR_CODES:
			raise
		raise GutShardWorkerError(
			"worker_phase_evidence_invalid",
			"Authoritative phase evidence could not be validated.",
			phase,
		) from error
	except (OSError, UnicodeDecodeError, ValueError) as error:
		raise GutShardWorkerError(
			"worker_phase_evidence_invalid",
			"Authoritative phase evidence could not be validated.",
			phase,
		) from error
	phase_result = {
		"ok": (
			evaluated.exit_code == 0
			and not evaluated.godot_exit_leak_warnings
			and not (
				isinstance(evaluated.godot_exit_leak_report, dict)
				and evaluated.godot_exit_leak_report.get("has_leaks") is True
			)
			and not bool(result.timed_out)
			and not bool(result.cancelled)
			and not bool(result.stdout_truncated)
			and not bool(result.stderr_truncated)
		),
		"exit_code": int(evaluated.exit_code),
		"timed_out": bool(result.timed_out),
		"cancelled": bool(result.cancelled),
		"duration_seconds": float(result.duration_seconds),
	}
	_assert_workspace_identity(workspace, expected_workspace_identity)
	_assert_owned_directory_identity(
		owned_log_root,
		expected_log_root_identity,
		"worker_log_root_replaced",
		"Invocation-owned Godot log root changed during execution.",
		phase,
	)
	_assert_managed_directory_chain(expected_log_chain)
	return result, phase_result, evaluated.gut_lifecycle_report


def _parse_lifecycle_for_test(result: Any) -> dict[str, Any] | None:
	"""Test seam only; the production path consumes completed_command_result."""
	try:
		import gf_maintenance
		return gf_maintenance.parse_gut_lifecycle_gate_output(
			str(getattr(result, "stdout", "")),
			str(getattr(result, "stderr", "")),
		)
	except (ImportError, AttributeError, ValueError):
		return None


def _owned_command_log_path(
	command: tuple[str, ...] | list[str],
	owned_log_root: Path,
) -> Path:
	"""Require exactly one fresh .log output directly below the owned root."""
	paths: list[str] = []
	for index, argument in enumerate(command):
		if argument == "--log-file":
			if index + 1 >= len(command):
				raise GutShardWorkerError(
					"worker_log_path_invalid",
					"Godot command has no log-file value.",
				)
			paths.append(command[index + 1])
		elif argument.startswith("--log-file="):
			paths.append(argument.split("=", 1)[1])
	if len(paths) != 1:
		raise GutShardWorkerError(
			"worker_log_path_invalid",
			"Godot command must own exactly one log file.",
		)
	root = _validate_real_directory(owned_log_root, "owned log root")
	path = Path(paths[0])
	if not path.is_absolute():
		raise GutShardWorkerError(
			"worker_log_path_invalid",
			"Godot log path must be absolute.",
		)
	path = Path(os.path.abspath(path))
	if path.parent != root or path.suffix.casefold() != ".log" or os.path.lexists(path):
		raise GutShardWorkerError(
			"worker_log_path_invalid",
			"Godot log must be a fresh direct child of the invocation-owned log root.",
		)
	return path


def _control_gut_command(
	nonce: str,
	junit_path: Path,
	owned_log_root: Path,
) -> tuple[str, ...]:
	"""Preserve the authoritative G0.1 directory-selection semantics."""
	try:
		import gf_maintenance
		base = gf_maintenance.gut_shard_observation_command(
			gf_maintenance.CHECK_DEFINITIONS["gut"],
			nonce,
			"gut-control",
		)
	except (ImportError, AttributeError, KeyError, ValueError) as error:
		raise GutShardWorkerError(
			"worker_control_command_unavailable",
			"The authoritative control GUT command is unavailable.",
			"gut",
		) from error
	# The helper's canonical definition is module-rooted.  A same-process worker
	# executes in a separate materialization, so bind only the invocation-owned log
	# destination to that workspace while retaining all other authoritative argv.
	try:
		log_index = base.index("--log-file") + 1
	except ValueError as error:
		raise GutShardWorkerError(
			"worker_control_command_invalid",
			"The authoritative control command has no owned log option.",
			"gut",
		) from error
	if log_index >= len(base):
		raise GutShardWorkerError(
			"worker_control_command_invalid",
			"The authoritative control command has no owned log destination.",
			"gut",
		)
	base[log_index] = str(
		owned_log_root / f"gut-shard-{nonce}-gut-control.log"
	)
	if not any(argument.startswith("-gdir=") for argument in base) or "-ginclude_subdirs" not in base:
		raise GutShardWorkerError(
			"worker_control_command_invalid",
			"The authoritative control selection semantics changed unexpectedly.",
			"gut",
		)
	if any(argument.startswith("-gjunit_xml_file") for argument in base):
		raise GutShardWorkerError(
			"worker_control_command_invalid",
			"The authoritative control command already owns a JUnit destination.",
			"gut",
		)
	return (*base, f"-gjunit_xml_file={junit_path.as_posix()}")


def _parse_published_junit_observation(
	junit_path: Path,
	provenance_path: Path,
	*,
	nonce: str,
	expected_scripts: tuple[str, ...],
	invocation_chain: tuple[tuple[Path, tuple[int, int, int]], ...],
) -> dict[str, Any]:
	"""Consume the exact producer pair only after its directory chain is quiet."""
	_assert_managed_directory_chain(invocation_chain)
	try:
		junit_identity = gf_gut_sharding.stable_file_identity(junit_path.lstat())
		provenance_identity = gf_gut_sharding.stable_file_identity(
			provenance_path.lstat()
		)
	except OSError as error:
		raise GutShardWorkerError(
			"worker_junit_rejected",
			"The invocation-owned JUnit and provenance pair was not published.",
			"junit",
		) from error
	_assert_managed_directory_chain(invocation_chain)
	try:
		report = gf_gut_sharding.parse_gut_junit_xml(
			junit_path,
			expected_scripts=expected_scripts,
			expected_file_identity=junit_identity,
			trusted_unfiltered_run=True,
			provenance_path=provenance_path,
			expected_provenance_identity=provenance_identity,
			expected_provenance_nonce=nonce,
		)
	except gf_gut_sharding.GutShardingError as error:
		raise GutShardWorkerError(
			"worker_junit_rejected",
			"The invocation-owned JUnit and provenance pair was invalid.",
			"junit",
		) from error
	_assert_managed_directory_chain(invocation_chain)
	try:
		junit_identity_after = gf_gut_sharding.stable_file_identity(
			junit_path.lstat()
		)
		provenance_identity_after = gf_gut_sharding.stable_file_identity(
			provenance_path.lstat()
		)
	except OSError as error:
		raise GutShardWorkerError(
			"worker_junit_rejected",
			"The invocation-owned JUnit and provenance pair changed after parsing.",
			"junit",
		) from error
	_assert_managed_directory_chain(invocation_chain)
	if (
		junit_identity_after != junit_identity
		or provenance_identity_after != provenance_identity
	):
		raise GutShardWorkerError(
			"worker_junit_rejected",
			"The invocation-owned JUnit and provenance pair changed while parsing.",
			"junit",
		)
	return report


def _validate_workspace_binding(
	workspace: Path,
	expected_fingerprint: str,
	expected_workspace_identity: tuple[int, int, int],
	*,
	git_process: FrozenGitProcess,
	deadline: float,
) -> None:
	_assert_workspace_identity(workspace, expected_workspace_identity)
	fingerprint_error: BaseException | None = None
	actual: Any = None
	try:
		from gf_maintenance_check_graph import workspace_fingerprint
		actual = workspace_fingerprint(
			workspace,
			git_process=git_process,
			deadline=deadline,
		)["fingerprint"]
	except (ImportError, KeyError, OSError, ValueError) as error:
		fingerprint_error = error
	# The publication token is the only workspace identity authority.  Recheck it
	# even when fingerprinting failed, and never replace it with a later lstat.
	_assert_workspace_identity(workspace, expected_workspace_identity)
	if fingerprint_error is not None:
		raise GutShardWorkerError(
			"worker_workspace_fingerprint_failed",
			"Could not verify private workspace fingerprint.",
		) from fingerprint_error
	if actual != expected_fingerprint:
		raise GutShardWorkerError("worker_workspace_fingerprint_mismatch", "Private workspace fingerprint differs from the parent binding.")


def _validate_shard_binding(
	workspace: Path,
	request: Mapping[str, Any],
	expected_workspace_identity: tuple[int, int, int],
	*,
	deadline: float,
) -> None:
	_check_worker_deadline(deadline, "manifest")
	_assert_workspace_identity(workspace, expected_workspace_identity)
	try:
		inventory = _discover_inventory_with_deadline(workspace, deadline)
	except gf_gut_sharding.GutShardingError as error:
		if error.code == "inventory_deadline_exceeded":
			raise GutShardWorkerError(
				"worker_inventory_deadline_exhausted",
				"Private workspace inventory stability scan exceeded its per-scan deadline.",
			) from error
		raise GutShardWorkerError(
			"worker_shard_binding_failed",
			"Could not verify the requested shard against the private workspace manifest.",
		) from error
	except (OSError, ValueError) as error:
		raise GutShardWorkerError(
			"worker_shard_binding_failed",
			"Could not verify the requested shard against the private workspace manifest.",
		) from error
	_assert_workspace_identity(workspace, expected_workspace_identity)
	try:
		manifest = gf_gut_sharding.load_and_validate_manifest(
			workspace / gf_gut_sharding.MANIFEST_RELATIVE_PATH,
			root=workspace,
			expected_inventory=inventory,
		)
	except (gf_gut_sharding.GutShardingError, OSError, ValueError) as error:
		raise GutShardWorkerError(
			"worker_shard_binding_failed",
			"Could not verify the requested shard against the private workspace manifest.",
		) from error
	_assert_workspace_identity(workspace, expected_workspace_identity)
	_check_worker_deadline(deadline, "manifest")
	if canonical_digest(manifest) != request["manifest_digest"]:
		raise GutShardWorkerError("worker_manifest_digest_mismatch", "Private workspace shard manifest digest differs from the request.")
	if manifest.get("inventory_digest") != request["inventory_digest"]:
		raise GutShardWorkerError("worker_inventory_digest_mismatch", "Private workspace inventory digest differs from the request.")
	if request["mode"] == CONTROL_MODE:
		if (
			request["shard_name"] != CONTROL_SHARD_NAME
			or request["role"] != CONTROL_ROLE
			or tuple(request["scripts"]) != inventory
		):
			raise GutShardWorkerError("worker_control_binding_invalid", "Control request must bind the complete canonical inventory.")
		_assert_workspace_identity(workspace, expected_workspace_identity)
		return
	matches = [shard for shard in manifest["shards"] if shard["name"] == request["shard_name"]]
	if len(matches) != 1:
		raise GutShardWorkerError("worker_shard_binding_invalid", "Candidate shard name is not unique in the manifest.")
	shard = matches[0]
	if shard["role"] != request["role"] or shard["scripts"] != request["scripts"]:
		raise GutShardWorkerError("worker_shard_binding_invalid", "Candidate shard role or scripts differ from the manifest.")
	_assert_workspace_identity(workspace, expected_workspace_identity)


def _discover_inventory_with_deadline(
	workspace: Path,
	deadline: float,
) -> tuple[str, ...]:
	"""Reuse G0 inventory rules under the stricter worker-local deadline."""
	return gf_gut_sharding.discover_gut_test_scripts(
		workspace,
		deadline=deadline,
	)


def _assert_workspace_identity(
	workspace: Path,
	expected: tuple[int, int, int],
) -> None:
	try:
		current = workspace.lstat()
	except OSError as error:
		raise GutShardWorkerError(
			"worker_workspace_replaced",
			"Private workspace root became unavailable during execution.",
		) from error
	if _directory_identity(current) != expected:
		raise GutShardWorkerError(
			"worker_workspace_replaced",
			"Private workspace root identity changed during execution.",
		)


def _validate_publication_identity_token(
	value: tuple[int, int, int] | None,
) -> tuple[int, int, int]:
	if (
		type(value) is not tuple
		or len(value) != 3
		or any(type(component) is not int for component in value)
		or value[0] == 0 and value[1] == 0
		or not stat.S_ISDIR(value[2])
	):
		raise GutShardWorkerError(
			"worker_workspace_publication_identity_mismatch",
			"A valid materializer publication identity token is required.",
		)
	return value


def _validate_workspace(path: Path) -> Path:
	return _validate_real_directory(path, "private workspace")


def _validate_real_directory(path: Path, label: str) -> Path:
	path = Path(os.path.abspath(os.path.normpath(path)))
	if not path.is_absolute():
		raise GutShardWorkerError("worker_path_invalid", f"{label} must be absolute.")
	current = Path(path.anchor)
	for part in path.parts[1:]:
		current /= part
		try:
			metadata = current.lstat()
		except OSError as error:
			raise GutShardWorkerError("worker_path_invalid", f"{label} directory chain is unavailable.") from error
		if not stat.S_ISDIR(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode) or _is_reparse(metadata):
			raise GutShardWorkerError("worker_path_invalid", f"{label} must have a real non-link directory chain.")
	return path


def _create_invocation_root(workspace: Path, nonce: str) -> Path:
	root = _create_real_directory_chain(
		workspace,
		OBSERVATION_ROOT_RELATIVE,
	)
	invocation = root / nonce
	try:
		invocation.mkdir(exist_ok=False)
	except FileExistsError as error:
		raise GutShardWorkerError("worker_nonce_reused", "Worker nonce output already exists.") from error
	return _validate_real_directory(invocation, "worker invocation root")


def _create_real_directory_chain(
	root: Path,
	relative_path: Path,
) -> Path:
	"""Create a bounded relative directory chain without traversing aliases."""
	root = _validate_real_directory(root, "managed directory root")
	if relative_path.is_absolute() or not relative_path.parts:
		raise GutShardWorkerError(
			"worker_managed_path_invalid",
			"Managed directory paths must be non-empty and relative.",
		)
	current = root
	for component in relative_path.parts:
		if component in {"", ".", ".."} or "/" in component or "\\" in component:
			raise GutShardWorkerError(
				"worker_managed_path_invalid",
				"Managed directory path contains an unsafe component.",
			)
		current /= component
		if os.path.lexists(current):
			_validate_real_directory(current, "managed directory")
			continue
		current.mkdir(exist_ok=False)
		_validate_real_directory(current, "managed directory")
	return current


def _snapshot_managed_directory_chain(
	root: Path,
	target: Path,
	expected_root_identity: tuple[int, int, int],
) -> tuple[tuple[Path, tuple[int, int, int]], ...]:
	root = Path(os.path.abspath(root))
	target = Path(os.path.abspath(target))
	try:
		relative = target.relative_to(root)
	except ValueError as error:
		raise GutShardWorkerError(
			"worker_managed_path_invalid",
			"Managed directory is outside the private workspace.",
		) from error
	chain: list[tuple[Path, tuple[int, int, int]]] = []
	current = root
	for component in (Path("."), *relative.parts):
		if component != Path("."):
			current /= component
		metadata = _validate_real_directory(current, "managed directory").lstat()
		identity = _directory_identity(metadata)
		if current == root and identity != expected_root_identity:
			raise GutShardWorkerError(
				"worker_workspace_replaced",
				"Private workspace root identity changed while managed ownership was recorded.",
			)
		chain.append((current, identity))
	return tuple(chain)


def _assert_managed_directory_chain(
	chain: tuple[tuple[Path, tuple[int, int, int]], ...] | None,
) -> None:
	if not chain:
		raise GutShardWorkerError(
			"worker_managed_directory_replaced",
			"Managed directory ownership was not recorded.",
	)
	for path, expected in chain:
		try:
			metadata = path.lstat()
		except OSError as error:
			raise GutShardWorkerError(
				"worker_managed_directory_replaced",
				"Managed directory became unavailable during execution.",
			) from error
		if _directory_identity(metadata) != expected or stat.S_ISLNK(metadata.st_mode) or _is_reparse(metadata):
			raise GutShardWorkerError(
				"worker_managed_directory_replaced",
				"Managed directory identity changed during execution.",
			)


def _assert_owned_directory_identity(
	path: Path,
	expected: tuple[int, int, int],
	code: str,
	message: str,
	phase: str,
) -> None:
	try:
		metadata = path.lstat()
	except OSError as error:
		raise GutShardWorkerError(code, message, phase) from error
	try:
		actual = _directory_identity(metadata)
	except GutShardWorkerError as error:
		raise GutShardWorkerError(code, message, phase) from error
	if actual != expected:
		raise GutShardWorkerError(code, message, phase)


def _private_environment(
	workspace: Path,
	root: Path,
	*,
	process_environment: FrozenProcessEnvironment,
	observation_nonce: str,
) -> dict[str, str]:
	if not isinstance(process_environment, FrozenProcessEnvironment):
		raise TypeError("Private worker environment requires a frozen base environment.")
	if _paths_overlap(workspace, root):
		raise GutShardWorkerError(
			"worker_private_environment_overlap",
			"Platform data/config/cache roots must not overlap the private project.",
		)
	_validate_real_directory(root.parent, "platform isolation parent")
	root.mkdir(exist_ok=False)
	root_identity: os.stat_result | None = None
	try:
		root_identity = root.lstat()
		root = _validate_real_directory(root, "platform isolation root")
		directories = {
			name: root / leaf
			for name, leaf in {
				"home": "h",
				"localappdata": "l",
				"data": "d",
				"config": "c",
				"cache": "k",
				"temp": "t",
			}.items()
		}
		for directory in directories.values():
			directory.mkdir(exist_ok=False)
			_validate_real_directory(directory, "platform isolation directory")
		environment = process_environment.values()
		for name in (
			"GODOT_USER_HOME",
			OBSERVATION_NONCE_ENVIRONMENT,
			OBSERVATION_PATH_ENVIRONMENT,
		):
			remove_owned_environment_value(environment, name)
		private_values: dict[str, str]
		if os.name == "nt":
			# Godot appends ``Godot/app_userdata/<project>`` to APPDATA.  Point it
			# at the already-owned root instead of adding another directory name;
			# deep Storage transaction paths must remain below legacy MAX_PATH on
			# Windows hosts where long-path support is disabled.
			private_values = {
				"APPDATA": str(root),
				"LOCALAPPDATA": str(directories["localappdata"]),
			}
		elif sys.platform == "darwin":
			private_values = {"HOME": str(directories["home"])}
		else:
			private_values = {
				"HOME": str(directories["home"]),
				"XDG_DATA_HOME": str(directories["data"]),
				"XDG_CONFIG_HOME": str(directories["config"]),
				"XDG_CACHE_HOME": str(directories["cache"]),
			}
		for key in ("TMPDIR", "TEMP", "TMP"):
			private_values[key] = str(directories["temp"])
		private_values[OBSERVATION_NONCE_ENVIRONMENT] = observation_nonce
		private_values[OBSERVATION_PATH_ENVIRONMENT] = (
			_observation_provenance_resource_path(observation_nonce)
		)
		private_values["PYTHONUTF8"] = "1"
		for name, value in private_values.items():
			set_owned_environment_value(environment, name, value)
		return environment
	except BaseException as error:
		cleanup_error = _remove_private_environment_root(root, root_identity)
		if cleanup_error:
			raise GutShardWorkerError(
				"worker_private_environment_cleanup_failed",
				"Partially-created platform state could not be cleaned safely.",
				"preflight",
			) from error
		raise


def _private_environment_root_path(workspace: Path, nonce: str) -> Path:
	"""Return the short, invocation-owned sibling used for platform state."""
	if not _is_sha256(nonce):
		raise GutShardWorkerError(
			"worker_request_nonce_invalid",
			"Observation nonce must be exactly 64 lowercase hexadecimal characters.",
		)
	# Production materialization names candidate parents 0..8 (and the control
	# parent c) with at-most-two concurrent workspaces s0/s1.  The matching 0/1
	# sibling is collision-free inside that fresh owned parent and avoids
	# repeating a 64-character nonce in every user:// path.  Keeping the private
	# root inside workspace.parent is important: that is the narrowest parent
	# scope granted by the request; the worker must not infer authority over a
	# lexical grandparent.
	parent_name = workspace.parent.name
	if (
		workspace.name in {"s0", "s1"}
		and parent_name in {"0", "1", "2", "3", "4", "5", "6", "7", "8"}
	):
		return workspace.parent / workspace.name[1]
	if parent_name == "c" and workspace.name == "s0":
		return workspace.parent / "0"
	# Direct test/API callers with another workspace layout retain a bounded
	# nonce-derived sibling fallback; exist_ok=False remains the final fail-closed
	# collision guard in every layout.
	return (
		workspace.parent
		/ f".gfe-{nonce[:PRIVATE_ENVIRONMENT_FALLBACK_NONCE_CHARACTERS]}"
	)


def _observation_provenance_resource_path(nonce: str) -> str:
	if not _is_sha256(nonce):
		raise GutShardWorkerError(
			"worker_request_nonce_invalid",
			"Observation nonce must be exactly 64 lowercase hexadecimal characters.",
		)
	return (
		"res://"
		+ (OBSERVATION_ROOT_RELATIVE / nonce / OBSERVATION_PROVENANCE_FILENAME).as_posix()
	)


def _remove_private_environment_root(
	root: Path,
	expected_identity: os.stat_result | None,
) -> str:
	"""Remove only the exact sibling tree created by this invocation."""
	if expected_identity is None:
		return "private environment ownership was not recorded"
	try:
		import gf_maintenance
		return str(
			gf_maintenance.remove_managed_temporary_tree(
				root,
				expected_identity=expected_identity,
			)
		)
	except (ImportError, AttributeError, OSError, ValueError):
		return "private environment cleanup helper failed"


def _phase_timeout(deadline: float, requested: float, phase: str) -> float:
	remaining = deadline - time.monotonic()
	if not math.isfinite(remaining) or remaining < float(requested):
		raise GutShardWorkerError("worker_deadline_exhausted", "Worker-local deadline expired before the phase started.", phase)
	return float(requested)


def _require_remaining_budget(
	deadline: float,
	required: float,
	phase: str,
) -> None:
	"""Refuse to start a phase unless every later policy floor still fits."""

	remaining = deadline - time.monotonic()
	if not math.isfinite(remaining) or remaining < required:
		raise GutShardWorkerError(
			"worker_deadline_exhausted",
			"Worker-local deadline cannot preserve the remaining phase timeout floors.",
			phase,
		)


def _check_worker_deadline(deadline: float, phase: str) -> None:
	if time.monotonic() >= deadline:
		raise GutShardWorkerError(
			"worker_deadline_exhausted",
			"Worker-local deadline expired during the operation.",
			phase,
		)


def _check_worker_cancelled(
	cancellation_event: threading.Event | None,
	phase: str,
) -> None:
	if cancellation_event is not None and cancellation_event.is_set():
		raise GutShardWorkerError(
			"worker_cancelled",
			"Worker cancellation was requested.",
			phase,
		)


def _process_boundary_quiescent(result: Any) -> bool:
	return (
		isinstance(result, gf_process_supervisor.SupervisedProcessResult)
		and result.process_boundary_quiescent is True
	)


def _final_report_duration_seconds(
	report: Mapping[str, Any],
	duration_started: float,
) -> float:
	"""Cover both phase durations even when the wall timer has coarser precision."""
	wall_duration = time.perf_counter() - duration_started
	if not math.isfinite(wall_duration) or wall_duration < 0.0:
		wall_duration = 0.0
	phase_duration_sum = 0.0
	for key in ("import_result", "gut_result"):
		phase = report.get(key)
		if type(phase) is not dict:
			continue
		value = phase.get("duration_seconds")
		if (
			type(value) is not float
			or not math.isfinite(value)
			or value < 0.0
			or value > MAX_PHASE_TIMEOUT_SECONDS
		):
			continue
		phase_duration_sum += value
	return max(float(wall_duration), phase_duration_sum)


def _not_run_phase() -> dict[str, Any]:
	return {"ok": False, "exit_code": 0, "timed_out": False, "cancelled": False, "duration_seconds": 0.0}


def _failed_attempt_phase() -> dict[str, Any]:
	return {
		"ok": False,
		"exit_code": 1,
		"timed_out": False,
		"cancelled": False,
		"duration_seconds": 0.0,
	}


def _append_issue(report: dict[str, Any], error: GutShardWorkerError) -> None:
	if any(
		issue.get("kind") == error.code and issue.get("phase") == error.phase
		for issue in report["issues"]
	):
		return
	if len(report["issues"]) >= MAX_ISSUES:
		return
	message = error.message.encode("utf-8")[:MAX_ISSUE_TEXT_BYTES].decode("utf-8", errors="ignore")
	report["issues"].append({"kind": error.code, "message": message, "phase": error.phase})


def _read_stable_regular_file(path: Path, max_bytes: int, label: str) -> bytes:
	path = Path(path)
	if not path.is_absolute():
		raise GutShardWorkerError("worker_path_invalid", f"{label} path must be absolute.")
	parent = _validate_real_directory(path.parent, f"{label} parent")
	parent_identity = parent.lstat()
	before = path.lstat()
	if not stat.S_ISREG(before.st_mode) or stat.S_ISLNK(before.st_mode) or _is_reparse(before) or before.st_size > max_bytes:
		raise GutShardWorkerError("worker_input_invalid", f"{label} must be a bounded regular file.")
	flags = os.O_RDONLY | getattr(os, "O_BINARY", 0) | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
	descriptor = os.open(path, flags)
	try:
		opened_before = os.fstat(descriptor)
		payload = bytearray()
		while len(payload) <= max_bytes:
			chunk = os.read(descriptor, min(64 * 1024, max_bytes + 1 - len(payload)))
			if not chunk:
				break
			payload.extend(chunk)
		opened_after = os.fstat(descriptor)
	finally:
		os.close(descriptor)
	after = path.lstat()
	if (
		len(payload) > max_bytes
		or not _same_directory_identity(parent_identity, parent.lstat())
		or not _same_file_token(before, opened_before, opened_after, after)
		or len(payload) != after.st_size
	):
		raise GutShardWorkerError("worker_input_drift", f"{label} changed while being read.")
	return bytes(payload)


def _same_file_token(
	path_before: os.stat_result,
	handle_before: os.stat_result,
	handle_after: os.stat_result,
	path_after: os.stat_result,
) -> bool:
	"""Detect drift without assuming Windows path/handle timestamp parity."""
	return (
		_stable_metadata_token(path_before) == _stable_metadata_token(path_after)
		and _stable_metadata_token(handle_before) == _stable_metadata_token(handle_after)
		and _open_file_identity(path_before) == _open_file_identity(handle_before)
		and _open_file_identity(handle_after) == _open_file_identity(path_after)
	)


def _stable_metadata_token(metadata: os.stat_result) -> tuple[int, int, int, int, int, int]:
	return (
		int(getattr(metadata, "st_dev", 0)),
		int(getattr(metadata, "st_ino", 0)),
		int(metadata.st_mode),
		int(metadata.st_size),
		int(metadata.st_mtime_ns),
		int(getattr(metadata, "st_ctime_ns", 0)),
	)


def _open_file_identity(metadata: os.stat_result) -> tuple[int, int, int, int]:
	return (
		int(getattr(metadata, "st_dev", 0)),
		int(getattr(metadata, "st_ino", 0)),
		int(metadata.st_mode),
		int(metadata.st_size),
	)


def _same_directory_identity(left: os.stat_result, right: os.stat_result) -> bool:
	left_device = int(getattr(left, "st_dev", 0))
	left_inode = int(getattr(left, "st_ino", 0))
	return (
		stat.S_ISDIR(left.st_mode)
		and stat.S_ISDIR(right.st_mode)
		and not stat.S_ISLNK(left.st_mode)
		and not stat.S_ISLNK(right.st_mode)
		and not _is_reparse(left)
		and not _is_reparse(right)
		and (left_device != 0 or left_inode != 0)
		and left_device == int(getattr(right, "st_dev", 0))
		and left_inode == int(getattr(right, "st_ino", 0))
	)


def _directory_identity(metadata: os.stat_result) -> tuple[int, int, int]:
	device = int(getattr(metadata, "st_dev", 0))
	inode = int(getattr(metadata, "st_ino", 0))
	if (
		not stat.S_ISDIR(metadata.st_mode)
		or stat.S_ISLNK(metadata.st_mode)
		or _is_reparse(metadata)
		or (device == 0 and inode == 0)
	):
		raise GutShardWorkerError(
			"worker_directory_identity_invalid",
			"Managed directory has no stable real-directory identity.",
		)
	return device, inode, int(metadata.st_mode)


def _is_reparse(metadata: os.stat_result) -> bool:
	return bool(int(getattr(metadata, "st_file_attributes", 0)) & 0x0400)


def _is_sha256(value: Any) -> bool:
	return type(value) is str and len(value) == 64 and all(character in _HEX_64 for character in value)


def _paths_overlap(left: Path, right: Path) -> bool:
	left_text = os.path.normcase(os.path.abspath(left))
	right_text = os.path.normcase(os.path.abspath(right))
	try:
		common = os.path.normcase(os.path.commonpath((left_text, right_text)))
	except ValueError:
		return False
	return common in (left_text, right_text)


def _safe_error_message(error: BaseException) -> str:
	return f"{type(error).__name__}: worker operation failed closed."
