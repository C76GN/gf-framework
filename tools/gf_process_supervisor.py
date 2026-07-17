#!/usr/bin/env python3
"""Cross-platform subprocess supervision for GF maintenance commands."""

from __future__ import annotations

import os
import signal
import subprocess
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from typing import Callable


OUTPUT_DRAIN_GRACE_SECONDS = 1.0
OUTPUT_CLEANUP_GRACE_SECONDS = 2.0


@dataclass(frozen=True)
class SupervisedProcessResult:
	return_code: int
	stdout: str
	stderr: str
	timed_out: bool
	duration_seconds: float
	pid: int
	notes: tuple[str, ...] = ()


def run_supervised_process(
	command: list[str],
	*,
	cwd: Path,
	timeout_seconds: float,
	environment: dict[str, str] | None = None,
	stdout_callback: Callable[[str], None] | None = None,
	stderr_callback: Callable[[str], None] | None = None,
	heartbeat_callback: Callable[[float, int], None] | None = None,
	heartbeat_interval_seconds: float = 15.0,
) -> SupervisedProcessResult:
	started = time.perf_counter()
	process = subprocess.Popen(
		command,
		cwd=cwd,
		stdout=subprocess.PIPE,
		stderr=subprocess.PIPE,
		text=True,
		encoding="utf-8",
		errors="replace",
		env=environment,
		**process_group_options(),
	)
	stdout_parts: list[str] = []
	stderr_parts: list[str] = []
	callback_errors: list[str] = []
	callback_error_lock = threading.Lock()
	activity_lock = threading.Lock()
	last_output_at = [started]
	stdout_thread = start_output_pump(
		process.stdout,
		stdout_parts,
		stdout_callback,
		"stdout",
		callback_errors,
		callback_error_lock,
		last_output_at,
		activity_lock,
	)
	stderr_thread = start_output_pump(
		process.stderr,
		stderr_parts,
		stderr_callback,
		"stderr",
		callback_errors,
		callback_error_lock,
		last_output_at,
		activity_lock,
	)
	deadline = started + max(0.001, timeout_seconds)
	next_heartbeat = started + max(0.1, heartbeat_interval_seconds)
	timed_out = False
	notes: list[str] = []
	try:
		while process.poll() is None:
			now = time.perf_counter()
			remaining = deadline - now
			if remaining <= 0.0:
				timed_out = True
				notes.append(f"Command timed out after {timeout_seconds:g}s; terminating its process tree.")
				notes.extend(terminate_process_tree(process))
				break
			if heartbeat_callback is not None and now >= next_heartbeat:
				with activity_lock:
					last_activity = last_output_at[0]
				if now - last_activity >= heartbeat_interval_seconds:
					try:
						heartbeat_callback(now - started, process.pid)
					except Exception as exc:  # pragma: no cover - defensive callback boundary
						with callback_error_lock:
							callback_errors.append(f"heartbeat callback failed: {exc}")
					next_heartbeat = now + max(0.1, heartbeat_interval_seconds)
				else:
					next_heartbeat = last_activity + max(0.1, heartbeat_interval_seconds)
			try:
				process.wait(timeout=min(0.25, remaining))
			except subprocess.TimeoutExpired:
				continue
	except BaseException:
		notes.extend(terminate_process_tree(process))
		if process.poll() is None:
			process.kill()
			process.wait()
		drain_output_pumps(process, (stdout_thread, stderr_thread), notes)
		raise
	if process.poll() is None:
		process.kill()
		notes.append("Direct child required a final kill after process-tree termination.")
		process.wait()
	if not drain_output_pumps(process, (stdout_thread, stderr_thread), notes):
		timed_out = True
	notes.extend(callback_errors)
	return SupervisedProcessResult(
		return_code=process.returncode if process.returncode is not None else 124,
		stdout="".join(stdout_parts),
		stderr="".join(stderr_parts),
		timed_out=timed_out,
		duration_seconds=time.perf_counter() - started,
		pid=process.pid,
		notes=tuple(notes),
	)


def start_output_pump(
	pipe: Any,
	parts: list[str],
	callback: Callable[[str], None] | None,
	stream_name: str,
	callback_errors: list[str],
	callback_error_lock: threading.Lock,
	last_output_at: list[float],
	activity_lock: threading.Lock,
) -> threading.Thread:
	def pump() -> None:
		if pipe is None:
			return
		try:
			for line in iter(pipe.readline, ""):
				parts.append(line)
				with activity_lock:
					last_output_at[0] = time.perf_counter()
				if callback is not None:
					try:
						callback(line)
					except Exception as exc:  # pragma: no cover - defensive callback boundary
						with callback_error_lock:
							callback_errors.append(f"{stream_name} callback failed: {exc}")
		finally:
			pipe.close()

	thread = threading.Thread(target=pump, name=f"gf-{stream_name}-pump", daemon=True)
	thread.start()
	return thread


def drain_output_pumps(
	process: subprocess.Popen[str],
	threads: tuple[threading.Thread, ...],
	notes: list[str],
) -> bool:
	if wait_for_output_pumps(threads, OUTPUT_DRAIN_GRACE_SECONDS):
		return True
	notes.append(
		"Output pipes remained open after the direct child exited; "
		"terminating remaining descendants instead of truncating output silently."
	)
	notes.extend(terminate_remaining_descendants(process.pid))
	if not wait_for_output_pumps(threads, OUTPUT_CLEANUP_GRACE_SECONDS):
		notes.append("Output pumps did not reach EOF after descendant cleanup.")
	return False


def wait_for_output_pumps(threads: tuple[threading.Thread, ...], timeout_seconds: float) -> bool:
	deadline = time.perf_counter() + max(0.0, timeout_seconds)
	while True:
		alive_threads = [thread for thread in threads if thread.is_alive()]
		if not alive_threads:
			return True
		remaining = deadline - time.perf_counter()
		if remaining <= 0.0:
			return False
		for thread in alive_threads:
			thread.join(timeout=min(0.05, remaining))


def terminate_remaining_descendants(root_pid: int) -> list[str]:
	if os.name == "nt":
		return terminate_windows_descendants(root_pid)
	return terminate_posix_process_group_id(root_pid)


def terminate_windows_descendants(root_pid: int) -> list[str]:
	creation_flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
	script = (
		"$ErrorActionPreference = 'Stop'; "
		f"$rootId = {root_pid}; "
		"$all = @(Get-CimInstance Win32_Process); "
		"$ids = New-Object 'System.Collections.Generic.List[int]'; "
		"function Add-Descendants([int]$parentId) { "
		"foreach ($child in @($all | Where-Object { $_.ParentProcessId -eq $parentId })) { "
		"Add-Descendants ([int]$child.ProcessId); $ids.Add([int]$child.ProcessId) } }; "
		"Add-Descendants $rootId; $stopped = 0; "
		"foreach ($processId in $ids) { "
		"try { Stop-Process -Id $processId -Force -ErrorAction Stop; $stopped += 1 } catch {} }; "
		"Write-Output $stopped"
	)
	try:
		completed = subprocess.run(
			["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script],
			capture_output=True,
			text=True,
			encoding="utf-8",
			errors="replace",
			timeout=15,
			creationflags=creation_flags,
		)
	except (OSError, subprocess.TimeoutExpired) as exc:
		return [f"Windows descendant snapshot cleanup failed: {exc}"]
	if completed.returncode != 0:
		return [f"Windows descendant snapshot cleanup failed: {completed.stderr[-500:]}"]
	stopped = completed.stdout.strip() or "0"
	return [f"Terminated {stopped} remaining Windows descendant process(es)."]


def terminate_posix_process_group_id(process_group_id: int) -> list[str]:
	notes: list[str] = []
	try:
		os.killpg(process_group_id, signal.SIGTERM)
	except ProcessLookupError:
		return notes
	except OSError as exc:
		return [f"Could not terminate remaining process group {process_group_id}: {exc}"]
	time.sleep(0.1)
	try:
		os.killpg(process_group_id, signal.SIGKILL)
	except ProcessLookupError:
		pass
	except OSError as exc:
		notes.append(f"Could not kill remaining process group {process_group_id}: {exc}")
	return notes


def run_supervised_completed_process(
	command: list[str],
	*,
	cwd: Path,
	timeout_seconds: float,
	environment: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
	"""Compatibility wrapper for call sites that consume CompletedProcess."""
	result = run_supervised_process(
		command,
		cwd=cwd,
		timeout_seconds=timeout_seconds,
		environment=environment,
	)
	if result.timed_out:
		raise subprocess.TimeoutExpired(
			command,
			timeout_seconds,
			output=result.stdout,
			stderr=result.stderr,
		)
	return subprocess.CompletedProcess(
		command,
		result.return_code,
		stdout=result.stdout,
		stderr=result.stderr,
	)


def process_group_options() -> dict[str, Any]:
	if os.name == "nt":
		return {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP}
	return {"start_new_session": True}


def terminate_process_tree(process: subprocess.Popen[str]) -> list[str]:
	if process.poll() is not None:
		return []
	if os.name == "nt":
		return terminate_windows_process_tree(process)
	return terminate_posix_process_tree(process)


def terminate_windows_process_tree(process: subprocess.Popen[str]) -> list[str]:
	notes: list[str] = []
	creation_flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
	try:
		completed = subprocess.run(
			["taskkill", "/PID", str(process.pid), "/T", "/F"],
			capture_output=True,
			text=True,
			encoding="utf-8",
			errors="replace",
			timeout=10,
			creationflags=creation_flags,
		)
		if completed.returncode != 0 and process.poll() is None:
			notes.append(f"taskkill could not terminate process tree: {completed.stderr[-500:]}")
	except (OSError, subprocess.TimeoutExpired) as exc:
		notes.append(f"taskkill process-tree cleanup failed: {exc}")
	try:
		process.wait(timeout=1.0)
	except subprocess.TimeoutExpired:
		process.kill()
		notes.append("Fell back to killing the direct child process.")
	return notes


def terminate_posix_process_tree(process: subprocess.Popen[str]) -> list[str]:
	notes: list[str] = []
	try:
		process_group_id = os.getpgid(process.pid)
	except ProcessLookupError:
		return notes
	try:
		os.killpg(process_group_id, signal.SIGTERM)
	except ProcessLookupError:
		return notes
	except OSError as exc:
		notes.append(f"Could not terminate process group {process_group_id}: {exc}")
	try:
		process.wait(timeout=1.0)
	except subprocess.TimeoutExpired:
		pass
	try:
		os.killpg(process_group_id, signal.SIGKILL)
	except ProcessLookupError:
		pass
	except OSError as exc:
		notes.append(f"Could not kill process group {process_group_id}: {exc}")
	return notes
