#!/usr/bin/env python3
"""Run trusted GDScript against a read-only external directory, never its project."""

from __future__ import annotations

import hashlib
import json
import math
import os
import time
import uuid
from pathlib import Path
from typing import Any, Callable, ContextManager, Mapping

from gf_godot_process import resolve_godot_executable
from gf_path_security import PinnedReadError, read_pinned_regular_file, path_has_reparse_component
from gf_process_supervisor import (
	run_supervised_process_bytes, require_supervised_binary_quiet_boundary,
)


REQUEST_MAX_BYTES = 8 * 1024 * 1024
REPORT_MAX_BYTES = 16 * 1024 * 1024
SOURCE_MAX_BYTES = 128 * 1024 * 1024
SOURCE_MAX_FILES = 8192
RUN_TIMEOUT_SECONDS = 120.0
RUNNER_PATH = "res://addons/gf/tools/project_layout/cli/gf_project_layout_cli.gd"


class NativeExecutionError(RuntimeError):
	"""Unavailable transport is not an invented native analysis report."""

	def __init__(self, reason: str, *, process_boundary_quiet: bool) -> None:
		super().__init__(reason)
		self.reason = reason
		self.process_boundary_quiet = process_boundary_quiet


def run_native_analysis(
	request: dict[str, Any], *, trusted_root: Path,
	environment: Mapping[str, str],
	temporary_directory: Callable[[dict[str, bool]], ContextManager[Path]],
	private_environment: Callable[[Path, Path, Mapping[str, str]], dict[str, str]],
) -> dict[str, Any]:
	"""Keep deadline, bytes and process ownership across import and evaluation."""
	cleanup = {"permitted": True}
	try:
		deadline = time.perf_counter() + RUN_TIMEOUT_SECONDS
		payload = json.dumps(request, ensure_ascii=False, allow_nan=False).encode("utf-8")
		if len(payload) > REQUEST_MAX_BYTES:
			raise PinnedReadError("project_layout.request_limit")
		with temporary_directory(cleanup) as owned_root:
			fixture = owned_root / "p"
			fixture.mkdir()
			_stage_trusted_source(trusted_root, fixture, deadline)
			(fixture / "project.godot").write_text(
				'config_version=5\n[application]\nconfig/name="GF Layout CLI"\n'
				'[rendering]\nrenderer/rendering_method="gl_compatibility"\n',
				encoding="utf-8", newline="\n",
			)
			(fixture / "request.json").write_bytes(payload)
			private = private_environment(fixture, owned_root / "u", environment)
			engine = resolve_godot_executable(environment=private, cwd=fixture)
			log_root = trusted_root / "ai_analysis/godot_logs"
			if path_has_reparse_component(log_root):
				raise PinnedReadError("project_layout.log_root_unavailable")
			log_root.mkdir(parents=True, exist_ok=True)
			run_id = uuid.uuid4().hex
			for stage, argv in enumerate((
				[engine, "--headless", "--path", str(fixture), "--editor", "--import"],
				[engine, "--headless", "--path", str(fixture), "--script", RUNNER_PATH],
			)):
				argv.extend(["--log-file", str(log_root / f"layout-native-{run_id}-{stage}.log")])
				cleanup["permitted"] = False
				result = run_supervised_process_bytes(
					argv, cwd=fixture, timeout_seconds=RUN_TIMEOUT_SECONDS,
					deadline=deadline, max_stdout_bytes=1024 * 1024,
					max_stderr_bytes=256 * 1024, environment=private,
				)
				require_supervised_binary_quiet_boundary(result, deadline=deadline)
				cleanup["permitted"] = True
				output = result.stdout + result.stderr
				if result.return_code == 3 and not result.timed_out:
					raise PinnedReadError("project_layout.report_limit")
				if (
					result.timed_out or result.return_code != 0
					or result.stdout_truncated or result.stderr_truncated or result.output_drain_failed
				) or any(
					marker in output for marker in (
						b"ERROR:", b"WARNING:", b"Parse Error", b"ObjectDB instances leaked",
						b"Resources still in use", b"reload warning",
					)
				):
					raise PinnedReadError("project_layout.native_execution_failed")
			response = _decode_response(read_pinned_regular_file(
				fixture, "report.json", max_bytes=REPORT_MAX_BYTES,
			))
			return response["analysis"]
	except (PinnedReadError, OSError, RuntimeError, ValueError) as error:
		# Convert transport/setup failures; TypeError and control-flow exceptions remain visible.
		reason = error.rule_id if isinstance(error, PinnedReadError) else "project_layout.native_unavailable"
		raise NativeExecutionError(reason, process_boundary_quiet=cleanup["permitted"]) from error


def _stage_trusted_source(root: Path, destination: Path, deadline: float) -> None:
	"""Capture every trusted input twice before launching any code."""
	paths = _source_paths(root, deadline)
	files = []
	byte_count = 0
	for path in paths:
		if time.perf_counter() >= deadline:
			raise PinnedReadError("project_layout.source_capture_deadline")
		absolute = root / path
		if absolute.is_dir():
			continue
		data = read_pinned_regular_file(root, path, max_bytes=SOURCE_MAX_BYTES)
		byte_count += len(data)
		if byte_count > SOURCE_MAX_BYTES or len(files) >= SOURCE_MAX_FILES:
			raise PinnedReadError("project_layout.source_capture_limit")
		files.append((path, hashlib.sha256(data).digest()))
		target = destination / path
		target.parent.mkdir(parents=True, exist_ok=True)
		target.write_bytes(data)
	# Directory membership and captured source content must remain equal.
	if paths != _source_paths(root, deadline):
		raise PinnedReadError("project_layout.trusted_source_changed")
	for path, digest in files:
		if time.perf_counter() >= deadline or hashlib.sha256(
			read_pinned_regular_file(root, path, max_bytes=SOURCE_MAX_BYTES)
		).digest() != digest:
			raise PinnedReadError("project_layout.trusted_source_changed")


def _source_paths(root: Path, deadline: float) -> list[str]:
	"""Charge every encountered entry and prune caches before descending."""
	paths: list[str] = []
	pending = [root / "addons/gf"]
	entry_count = 0
	while pending:
		if time.perf_counter() >= deadline:
			raise PinnedReadError("project_layout.source_capture_deadline")
		directory = pending.pop()
		if path_has_reparse_component(directory):
			raise PinnedReadError("project_layout.trusted_source_unsafe")
		with os.scandir(directory) as entries:
			for entry in entries:
				if time.perf_counter() >= deadline:
					raise PinnedReadError("project_layout.source_capture_deadline")
				entry_count += 1
				if entry_count > SOURCE_MAX_FILES * 2:
					raise PinnedReadError("project_layout.source_capture_limit")
				path = Path(entry.path)
				if entry.name == "__pycache__" or path.suffix.lower() in {".pyc", ".pyo"}:
					continue
				if path_has_reparse_component(path):
					raise PinnedReadError("project_layout.trusted_source_unsafe")
				paths.append(path.relative_to(root).as_posix())
				if entry.is_dir(follow_symlinks=False):
					pending.append(path)
	return sorted(paths)


def _decode_response(payload: bytes) -> dict[str, Any]:
	def reject_constant(_value: str) -> Any:
		raise ValueError("Non-finite response")

	def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
		result: dict[str, Any] = {}
		for key, value in pairs:
			if key in result:
				raise ValueError("Duplicate response field")
			result[key] = value
		return result

	def finite_float(value: str) -> float:
		result = float(value)
		if not math.isfinite(result):
			raise ValueError("Non-finite response")
		return result

	response = json.loads(payload.decode("utf-8", errors="strict"),
		parse_constant=reject_constant, parse_float=finite_float, object_pairs_hook=unique_object)
	if (
		type(response) is not dict
		or set(response) != {"schema_version", "kind", "analysis"}
		or type(response["schema_version"]) is not int or response["schema_version"] != 1
		or response["kind"] != "project_layout_cli_result"
		or type(response["analysis"]) is not dict
		or type(response["analysis"].get("issues")) is not list
		or type(response["analysis"].get("evaluation_complete")) is not bool
		or type(response["analysis"].get("evaluation_status")) is not str
		or any(type(issue) is not dict for issue in response["analysis"]["issues"])
	):
		raise PinnedReadError("project_layout.response_invalid")
	return response
