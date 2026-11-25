#!/usr/bin/env python3
"""在受控的 Godot 工程中执行布局规则，只读分析调用者提供的外部项目目录。"""

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
from gf_path_security import (
	PinnedReadError, path_has_reparse_component, path_is_inside_lexical, read_pinned_regular_file,
)
from gf_process_supervisor import (
	run_supervised_process_bytes, require_supervised_binary_quiet_boundary,
	SupervisedProcessStartError, exception_has_cleanup_debt,
)


REQUEST_MAX_BYTES = 8 * 1024 * 1024
REPORT_MAX_BYTES = 16 * 1024 * 1024
SOURCE_MAX_BYTES = 128 * 1024 * 1024
SOURCE_MAX_FILES = 8192
RUN_TIMEOUT_SECONDS = 120.0
RUNNER_PATH = "res://addons/gf/tools/project_layout/cli/gf_project_layout_cli.gd"


class NativeExecutionError(RuntimeError):
	"""原生传输无法完成，调用方应保留执行失败，不应据此构造分析结果。"""

	def __init__(
		self, reason: str, *, process_boundary_quiet: bool, cleanup_errors: tuple[str, ...] = (),
	) -> None:
		super().__init__(reason)
		self.reason = reason
		self.process_boundary_quiet = process_boundary_quiet
		self.cleanup_errors = cleanup_errors


def run_native_analysis(
	request: dict[str, Any], *, trusted_root: Path,
	environment: Mapping[str, str],
	temporary_directory: Callable[[dict[str, bool]], ContextManager[Path]],
	private_environment: Callable[[Path, Path, Mapping[str, str]], dict[str, str]],
	protected_root: Path | None = None,
	on_quiet_failure: Callable[[], None] | None = None,
) -> dict[str, Any]:
	"""在导入和求值两阶段共用时限、输入字节和进程清理责任。"""
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
			if protected_root is not None and path_is_inside_lexical(protected_root, log_root):
				log_root = owned_root / "logs"
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
				try:
					result = run_supervised_process_bytes(
						argv, cwd=fixture, timeout_seconds=RUN_TIMEOUT_SECONDS,
						deadline=deadline, max_stdout_bytes=1024 * 1024,
						max_stderr_bytes=256 * 1024, environment=private,
						on_quiet_failure=lambda: cleanup.__setitem__("permitted", True),
					)
				except SupervisedProcessStartError as error:
					# 只有监督器明确确认未创建子进程时，才恢复清理测试工程的许可。
					cleanup["permitted"] = (
						error.process_boundary_quiescent is True
						and not exception_has_cleanup_debt(error)
					)
					raise
				# 确认整个进程树已结束后，即使结果较晚返回也允许拆除工程。
				cleanup["permitted"] = result.cleanup_complete is True and result.deferred_cleanup is None
				result = require_supervised_binary_quiet_boundary(result, deadline=deadline)
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
		# 将传输和准备错误投影为诊断，TypeError 与流程控制异常继续传播。
		reason = error.rule_id if isinstance(error, PinnedReadError) else "project_layout.native_unavailable"
		raise NativeExecutionError(reason, process_boundary_quiet=cleanup["permitted"]) from error
	except BaseException:
		if on_quiet_failure is not None and cleanup["permitted"]:
			on_quiet_failure()
		raise


def _stage_trusted_source(root: Path, destination: Path, deadline: float) -> None:
	"""启动任何代码前两次采集全部受信输入，核对其内容及身份。"""
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
	# 目录成员和采集到的源码内容都须与输入快照一致。
	if paths != _source_paths(root, deadline):
		raise PinnedReadError("project_layout.trusted_source_changed")
	for path, digest in files:
		if time.perf_counter() >= deadline or hashlib.sha256(
			read_pinned_regular_file(root, path, max_bytes=SOURCE_MAX_BYTES)
		).digest() != digest:
			raise PinnedReadError("project_layout.trusted_source_changed")


def _source_paths(root: Path, deadline: float) -> list[str]:
	"""为遇到的每个目录项扣减预算，进入子目录前先排除缓存。"""
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
