#!/usr/bin/env python3
"""Cross-platform subprocess supervision for GF maintenance commands."""

from __future__ import annotations

import os
import signal
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any


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
	try:
		stdout, stderr = process.communicate(timeout=timeout_seconds)
		return SupervisedProcessResult(
			return_code=process.returncode,
			stdout=stdout,
			stderr=stderr,
			timed_out=False,
			duration_seconds=time.perf_counter() - started,
			pid=process.pid,
		)
	except subprocess.TimeoutExpired as exc:
		notes = [f"Command timed out after {timeout_seconds:g}s; terminating its process tree."]
		notes.extend(terminate_process_tree(process))
		try:
			stdout, stderr = process.communicate(timeout=5.0)
		except subprocess.TimeoutExpired:
			process.kill()
			stdout, stderr = process.communicate()
			notes.append("Direct child required a final kill after process-tree termination.")
		return SupervisedProcessResult(
			return_code=process.returncode if process.returncode is not None else 124,
			stdout=stdout or output_text(exc.stdout),
			stderr=stderr or output_text(exc.stderr),
			timed_out=True,
			duration_seconds=time.perf_counter() - started,
			pid=process.pid,
			notes=tuple(notes),
		)


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


def output_text(value: str | bytes | None) -> str:
	if isinstance(value, bytes):
		return value.decode("utf-8", errors="replace")
	return value or ""
