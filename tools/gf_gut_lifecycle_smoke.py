#!/usr/bin/env python3
"""Exercise the GF GUT lifecycle gate against process-level failure fixtures."""

from __future__ import annotations

import argparse
import json
import os
import secrets
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from gf_godot_process import resolve_godot_executable
from gf_maintenance import (
	GUT_LIFECYCLE_CLI_RESOURCE_PATH,
	GUT_LIFECYCLE_GATE_MAX_DETAIL_COUNT,
	GUT_LIFECYCLE_GATE_MAX_JSON_BYTES,
	GUT_LIFECYCLE_GATE_MAX_TEXT_LENGTH,
	GUT_LIFECYCLE_GATE_PREFIX,
	GUT_POST_RUN_HOOK_RESOURCE_PATH,
	GUT_PRE_RUN_HOOK_RESOURCE_PATH,
	godot_exit_leak_report_from_output,
	gut_report_all_tests_passed,
	has_gdscript_reload_warning,
	has_godot_script_error,
	parse_gut_lifecycle_gate_output,
)
from gf_parallel_validation import WorkspaceProcessBoundaryError
from gf_process_supervisor import (
	SupervisedProcessStartError,
	run_supervised_process,
	safe_exception_detail,
)


ROOT = Path(__file__).resolve().parents[1]
LOG_ROOT = ROOT / "ai_analysis" / "godot_logs"
FIXTURE_ROOT = "res://tests/gf_core/fixtures/lifecycle_gate"
TERMINAL_WARNING_CODE = "GF lifecycle terminal fixture warning"
BOOTSTRAP_WARNING_CODE = "GF lifecycle bootstrap fixture warning"
CUTOVER_WARNING_CODE = "GF lifecycle cutover thread fixture warning"
SCENARIO_TIMEOUT_SECONDS = 45
BOOTSTRAP_FIXTURE_ENVIRONMENT = "GF_GUT_LIFECYCLE_BOOTSTRAP_FIXTURE"


@dataclass(frozen=True)
class Scenario:
	name: str
	fixture: str
	expect_ok: bool
	extra_arguments: tuple[str, ...] = ()
	pre_run_argument: str = f"-gpre_run_script={GUT_PRE_RUN_HOOK_RESOURCE_PATH}"
	post_run_argument: str = f"-gpost_run_script={GUT_POST_RUN_HOOK_RESOURCE_PATH}"
	expected_configuration_error: str = ""
	expected_warning_count: int | None = None
	expected_orphan_count: int | None = None
	expected_warning_code: str = ""
	bootstrap_fixture: str = ""
	require_terminal_order: bool = False
	require_bounded_details: bool = False


SCENARIOS: tuple[Scenario, ...] = (
	Scenario(
		name="clean",
		fixture="lifecycle_gate_clean_fixture.gd",
		expect_ok=True,
	),
	Scenario(
		name="static_init_warning",
		fixture="lifecycle_gate_static_warning_fixture.gd",
		expect_ok=False,
		expected_warning_count=1,
	),
	Scenario(
		name="bootstrap_static_init_warning",
		fixture="lifecycle_gate_clean_fixture.gd",
		expect_ok=False,
		expected_warning_count=1,
		expected_warning_code=BOOTSTRAP_WARNING_CODE,
		bootstrap_fixture=(
			f"{FIXTURE_ROOT}/lifecycle_gate_bootstrap_warning_fixture.gd"
		),
	),
	Scenario(
		name="terminal_cutover_thread_warning",
		fixture="lifecycle_gate_clean_fixture.gd",
		expect_ok=False,
		post_run_argument=(
			"-gpost_run_script="
			f"{FIXTURE_ROOT}/lifecycle_gate_cutover_thread_warning_post_hook.gd"
		),
		expected_warning_code=CUTOVER_WARNING_CODE,
	),
	Scenario(
		name="terminal_warning",
		fixture="lifecycle_gate_clean_fixture.gd",
		expect_ok=False,
		post_run_argument=(
			"-gpost_run_script="
			f"{FIXTURE_ROOT}/lifecycle_gate_terminal_warning_post_hook.gd"
		),
		expected_warning_count=1,
		require_terminal_order=True,
	),
	Scenario(
		name="no_error_tracking",
		fixture="lifecycle_gate_clean_fixture.gd",
		expect_ok=False,
		extra_arguments=("-gno_error_tracking",),
		expected_configuration_error="warning_tracker_unavailable",
	),
	Scenario(
		name="missing_baseline",
		fixture="lifecycle_gate_clean_fixture.gd",
		expect_ok=False,
		pre_run_argument="-gpre_run_script=",
		expected_configuration_error="orphan_baseline_unavailable",
	),
	Scenario(
		name="bounded_warning_details",
		fixture="lifecycle_gate_many_warnings_fixture.gd",
		expect_ok=False,
		expected_warning_count=25,
		require_bounded_details=True,
	),
	Scenario(
		name="real_orphan",
		fixture="lifecycle_gate_orphan_fixture.gd",
		expect_ok=False,
		post_run_argument=(
			"-gpost_run_script="
			f"{FIXTURE_ROOT}/lifecycle_gate_orphan_cleanup_post_hook.gd"
		),
		expected_orphan_count=1,
	),
)


@dataclass
class ScenarioResult:
	name: str
	ok: bool
	issues: list[str] = field(default_factory=list)
	process_exit_code: int | None = None
	lifecycle_report: dict[str, Any] | None = None
	log_path: str = ""
	duration_seconds: float = 0.0
	process_notes: list[str] = field(default_factory=list)

	def to_dict(self) -> dict[str, Any]:
		return {
			"name": self.name,
			"ok": self.ok,
			"issues": self.issues,
			"process_exit_code": self.process_exit_code,
			"lifecycle_report": self.lifecycle_report,
			"log_path": self.log_path,
			"duration_seconds": self.duration_seconds,
			"process_notes": self.process_notes,
		}


def main() -> int:
	parser = argparse.ArgumentParser(
		description="Run process-level GF GUT lifecycle gate fixtures.",
	)
	parser.add_argument("--json", action="store_true", help="Print JSON output.")
	args = parser.parse_args()

	LOG_ROOT.mkdir(parents=True, exist_ok=True)
	godot = resolve_godot_executable()
	results = [run_scenario(godot, scenario) for scenario in SCENARIOS]
	payload = {
		"ok": all(result.ok for result in results),
		"scenario_count": len(results),
		"failure_count": sum(not result.ok for result in results),
		"scenarios": [result.to_dict() for result in results],
	}
	if args.json:
		print(json.dumps(payload, ensure_ascii=False, indent=2))
	else:
		for result in results:
			status = "PASS" if result.ok else "FAIL"
			print(f"[{status}] {result.name}")
			for issue in result.issues:
				print(f"  - {issue}")
	return 0 if payload["ok"] else 1


def run_scenario(godot: str, scenario: Scenario) -> ScenarioResult:
	run_token = f"{os.getpid()}_{secrets.token_hex(4)}"
	log_path = LOG_ROOT / f"gut_lifecycle_smoke_{scenario.name}_{run_token}.log"
	log_path.unlink(missing_ok=True)
	command = [
		godot,
		"--headless",
		"--log-file",
		str(log_path),
		"--path",
		str(ROOT),
		"-s",
		GUT_LIFECYCLE_CLI_RESOURCE_PATH,
		f"-gtest={FIXTURE_ROOT}/{scenario.fixture}",
		scenario.pre_run_argument,
		scenario.post_run_argument,
		"-gexit",
		"-gdisable_colors",
		*scenario.extra_arguments,
	]
	environment = os.environ.copy()
	environment.pop(BOOTSTRAP_FIXTURE_ENVIRONMENT, None)
	if scenario.bootstrap_fixture:
		environment[BOOTSTRAP_FIXTURE_ENVIRONMENT] = scenario.bootstrap_fixture
	try:
		process_result = run_supervised_process(
			command,
			cwd=ROOT,
			environment=environment,
			timeout_seconds=SCENARIO_TIMEOUT_SECONDS,
		)
	except SupervisedProcessStartError as error:
		original_error = error.original_error
		start_error_detail = safe_exception_detail(original_error)
		return ScenarioResult(
			name=scenario.name,
			ok=False,
			issues=[
				"supervised scenario failed before a child was created: "
				f"{type(original_error).__name__}: {start_error_detail}"
			],
			log_path=log_path.as_posix(),
		)
	except Exception as error:
		raise WorkspaceProcessBoundaryError(
			"GUT lifecycle scenario supervision failed without a quiet-boundary proof."
		) from error
	if process_result.process_boundary_quiescent is not True:
		raise WorkspaceProcessBoundaryError(
			"GUT lifecycle scenario returned without a quiet process-boundary proof."
		)

	log_text = read_log(log_path)
	lifecycle_report = parse_gut_lifecycle_gate_output(
		process_result.stdout,
		f"{process_result.stderr}\n{log_text}",
	)
	issues = validate_scenario(
		scenario,
		process_result.return_code,
		process_result.stdout,
		process_result.stderr,
		log_text,
		lifecycle_report,
	)
	if process_result.timed_out:
		issues.append(
			f"scenario exceeded {SCENARIO_TIMEOUT_SECONDS}s or process-tree cleanup failed"
		)
	if process_result.cancelled:
		issues.append("scenario was cancelled")
	return ScenarioResult(
		name=scenario.name,
		ok=not issues,
		issues=issues,
		process_exit_code=process_result.return_code,
		lifecycle_report=lifecycle_report,
		log_path=log_path.as_posix(),
		duration_seconds=process_result.duration_seconds,
		process_notes=list(process_result.notes),
	)


def read_log(log_path: Path) -> str:
	try:
		return log_path.read_text(encoding="utf-8")
	except (OSError, UnicodeError):
		return ""


def validate_scenario(
	scenario: Scenario,
	process_exit_code: int,
	stdout: str,
	stderr: str,
	log_text: str,
	lifecycle_report: dict[str, Any],
) -> list[str]:
	issues: list[str] = []
	combined_output = f"{stdout}\n{stderr}\n{log_text}"
	if has_godot_script_error(combined_output, ""):
		issues.append("fixture run reported a Godot script loading or parse error")
	if has_gdscript_reload_warning(combined_output, ""):
		issues.append("fixture run reported a GDScript reload warning")
	exit_leak_report = godot_exit_leak_report_from_output(
		scenario.name,
		stdout,
		f"{stderr}\n{log_text}",
	)
	if exit_leak_report["has_leaks"]:
		issues.append("fixture run reported a Godot exit leak")
	if not gut_report_all_tests_passed(combined_output):
		issues.append("fixture run did not report a non-empty all-tests-passed summary")
	marker_errors = lifecycle_report.get("marker_errors")
	if not isinstance(marker_errors, list) or marker_errors:
		issues.append(f"lifecycle marker parser rejected evidence: {marker_errors!r}")
	marker_count = lifecycle_report.get("marker_count")
	if marker_count not in (1, 2):
		issues.append(f"lifecycle marker count must be one or two, received {marker_count!r}")
	source_marker_count = combined_output.count(GUT_LIFECYCLE_GATE_PREFIX)
	if source_marker_count not in (1, 2):
		issues.append(
			"raw lifecycle evidence must occur once or in one stdout/log mirror pair, "
			f"received {source_marker_count}"
		)
	marker = lifecycle_report.get("marker")
	if not isinstance(marker, dict):
		return ["lifecycle marker is missing or invalid"]

	report_ok = bool(lifecycle_report.get("ok", False))
	if report_ok != scenario.expect_ok:
		issues.append(
			f"expected lifecycle ok={scenario.expect_ok}, received {report_ok}"
		)
	if scenario.expect_ok and process_exit_code != 0:
		issues.append(f"clean scenario exited with {process_exit_code}")
	if not scenario.expect_ok and process_exit_code == 0:
		issues.append("lifecycle failure scenario exited successfully")

	configuration_error = marker.get("configuration_error")
	if configuration_error != scenario.expected_configuration_error:
		issues.append(
			"expected configuration_error="
			f"{scenario.expected_configuration_error!r}, received {configuration_error!r}"
		)
	if scenario.expected_warning_count is not None:
		warning_count = marker.get("unhandled_warning_count")
		if warning_count != scenario.expected_warning_count:
			issues.append(
				f"expected {scenario.expected_warning_count} warnings, received {warning_count!r}"
			)
	if scenario.expected_orphan_count is not None:
		orphan_count = marker.get("orphan_count")
		if orphan_count != scenario.expected_orphan_count:
			issues.append(
				f"expected {scenario.expected_orphan_count} orphans, received {orphan_count!r}"
			)
	if scenario.expected_warning_code:
		warnings = marker.get("warnings")
		matching_warning_count = 0
		if isinstance(warnings, list):
			matching_warning_count = sum(
				isinstance(warning, dict)
				and warning.get("code") == scenario.expected_warning_code
				for warning in warnings
			)
		if matching_warning_count < 1:
			issues.append(
				f"expected warning code {scenario.expected_warning_code!r} was not captured"
			)
		if scenario.name == "terminal_cutover_thread_warning" and matching_warning_count > 2:
			issues.append("terminal cutover warning was captured more than twice")
	if scenario.require_terminal_order:
		warning_index = log_text.find(f"WARNING: {TERMINAL_WARNING_CODE}")
		marker_index = log_text.rfind(GUT_LIFECYCLE_GATE_PREFIX)
		if warning_index < 0:
			issues.append("terminal warning was not emitted")
		elif marker_index <= warning_index:
			issues.append("lifecycle marker was emitted before the terminal warning")

	if scenario.require_bounded_details:
		warnings = marker.get("warnings")
		if not isinstance(warnings, list) or len(warnings) != GUT_LIFECYCLE_GATE_MAX_DETAIL_COUNT:
			issues.append("warning details did not use the exact bounded detail count")
		if marker.get("details_truncated") is not True:
			issues.append("bounded warning details did not declare truncation")
		if isinstance(warnings, list):
			for warning in warnings:
				if not isinstance(warning, dict):
					issues.append("bounded warning detail is not an object")
					continue
				for key in ("test_id", "code", "file"):
					value = warning.get(key)
					if not isinstance(value, str):
						issues.append(f"warning detail {key} is not text")
					elif len(value) > GUT_LIFECYCLE_GATE_MAX_TEXT_LENGTH:
						issues.append(f"warning detail {key} exceeds the character bound")
					elif len(value.encode("utf-8")) > GUT_LIFECYCLE_GATE_MAX_TEXT_LENGTH:
						issues.append(f"warning detail {key} exceeds the UTF-8 byte bound")
		marker_line = next(
			(
				line
				for line in log_text.splitlines()
				if line.startswith(GUT_LIFECYCLE_GATE_PREFIX)
			),
			"",
		)
		marker_bytes = marker_line.removeprefix(GUT_LIFECYCLE_GATE_PREFIX).encode("utf-8")
		if len(marker_bytes) > GUT_LIFECYCLE_GATE_MAX_JSON_BYTES:
			issues.append("lifecycle marker JSON exceeds the byte bound")
	return issues


if __name__ == "__main__":
	sys.exit(main())
