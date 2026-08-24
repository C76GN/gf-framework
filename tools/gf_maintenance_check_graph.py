#!/usr/bin/env python3
"""Check graph, timeout budgets, and provenance fingerprints for GF maintenance."""

from __future__ import annotations

import hashlib
import json
import math
import os
import stat
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from typing import Iterable
from typing import Mapping

from gf_process_supervisor import SupervisedProcessStartError
from gf_process_supervisor import run_supervised_process


FILE_ATTRIBUTE_REPARSE_POINT = 0x0400
WORKSPACE_FINGERPRINT_CHUNK_BYTES = 1024 * 1024
MAX_WORKSPACE_FINGERPRINT_UNTRACKED_FILE_BYTES = 64 * 1024 * 1024
MAX_WORKSPACE_FINGERPRINT_UNTRACKED_TOTAL_BYTES = 256 * 1024 * 1024


class WorkspaceFingerprintError(RuntimeError):
	"""Base error for fail-closed workspace fingerprint operations."""


class WorkspaceFingerprintSetupError(WorkspaceFingerprintError):
	"""Raised when a workspace entry cannot be fingerprinted safely."""


class WorkspaceFingerprintDriftError(WorkspaceFingerprintError):
	"""Raised when a workspace entry changes during fingerprinting."""


class WorkspaceFingerprintProcessBoundaryError(WorkspaceFingerprintError):
	"""Raised when a fingerprint Git process is not proven fully quiescent."""

	def __init__(self, message: str) -> None:
		super().__init__(message)
		self.cleanup_debt = True
		self.process_boundary_quiescent = False


def stable_fingerprint(value: Any) -> str:
	"""Return a stable SHA-256 fingerprint for JSON-compatible maintenance data."""
	payload = json.dumps(
		value,
		allow_nan=False,
		ensure_ascii=False,
		sort_keys=True,
		separators=(",", ":"),
	).encode("utf-8")
	return hashlib.sha256(payload).hexdigest()


def workspace_fingerprint(root: Path, *, deadline: float | None = None) -> dict[str, Any]:
	"""Fingerprint committed state plus every non-ignored local change."""
	_check_deadline(deadline, "workspace fingerprint")
	head = run_git_bytes(root, ["rev-parse", "HEAD"], deadline=deadline).decode(
		"utf-8",
		errors="replace",
	).strip()
	diff = run_git_bytes(
		root,
		["diff", "--binary", "--no-ext-diff", "HEAD", "--"],
		deadline=deadline,
	)
	untracked_output = run_git_bytes(
		root,
		["ls-files", "--others", "--exclude-standard", "-z"],
		deadline=deadline,
	)
	untracked_paths = sorted(
		path
		for path in untracked_output.decode("utf-8", errors="surrogateescape").split("\0")
		if path
	)
	digest = hashlib.sha256()
	digest.update(b"gf-maintenance-workspace-v1\0")
	digest.update(head.encode("utf-8"))
	digest.update(b"\0diff\0")
	digest.update(diff)
	untracked_regular_bytes = 0
	for relative_path in untracked_paths:
		_check_deadline(deadline, "workspace fingerprint")
		digest.update(b"\0untracked\0")
		digest.update(relative_path.encode("utf-8", errors="surrogateescape"))
		path = root / relative_path
		try:
			file_stat = path.lstat()
		except OSError as exc:
			raise WorkspaceFingerprintDriftError(
				f"Could not inspect Git-enumerated untracked workspace entry: {relative_path}: {exc}"
			) from exc
		digest.update(f"\0mode={file_stat.st_mode:o}\0size={file_stat.st_size}\0".encode("ascii"))
		if stat.S_ISLNK(file_stat.st_mode):
			if not _stat_has_verifiable_identity(file_stat):
				raise WorkspaceFingerprintSetupError(
					"Untracked workspace symlink identity is unavailable: "
					f"{relative_path}"
				)
			try:
				link_target = os.readlink(path)
			except OSError as exc:
				raise WorkspaceFingerprintDriftError(
					"Could not read Git-enumerated untracked workspace symlink: "
					f"{relative_path}: {exc}"
				) from exc
			try:
				symlink_after = path.lstat()
			except OSError as exc:
				raise WorkspaceFingerprintDriftError(
					"Git-enumerated untracked workspace symlink disappeared while reading: "
					f"{relative_path}: {exc}"
				) from exc
			if not _same_symlink_snapshot(file_stat, symlink_after):
				raise WorkspaceFingerprintDriftError(
					"Git-enumerated untracked workspace symlink changed while reading: "
					f"{relative_path}"
				)
			digest.update(link_target.encode("utf-8", errors="surrogateescape"))
		elif stat.S_ISREG(file_stat.st_mode):
			if file_stat.st_size > MAX_WORKSPACE_FINGERPRINT_UNTRACKED_FILE_BYTES:
				raise WorkspaceFingerprintSetupError(
					"Untracked workspace file exceeds the "
					f"{MAX_WORKSPACE_FINGERPRINT_UNTRACKED_FILE_BYTES}-byte fingerprint "
					f"limit: {relative_path}"
				)
			projected_regular_bytes = untracked_regular_bytes + file_stat.st_size
			if projected_regular_bytes > MAX_WORKSPACE_FINGERPRINT_UNTRACKED_TOTAL_BYTES:
				raise WorkspaceFingerprintSetupError(
					"Untracked workspace files exceed the "
					f"{MAX_WORKSPACE_FINGERPRINT_UNTRACKED_TOTAL_BYTES}-byte total "
					"fingerprint limit."
				)
			digest = _update_digest_from_stable_regular_file(
				digest,
				path,
				file_stat,
				deadline=deadline,
			)
			untracked_regular_bytes = projected_regular_bytes
	_check_deadline(deadline, "workspace fingerprint")
	return {
		"schema_version": 1,
		"head": head,
		"dirty": bool(diff or untracked_paths),
		"untracked_file_count": len(untracked_paths),
		"fingerprint": digest.hexdigest(),
	}


def _update_digest_from_stable_regular_file(
	digest: Any,
	path: Path,
	before: os.stat_result,
	*,
	deadline: float | None,
) -> Any:
	"""Append one regular file without buffering it or accepting a replaced path."""
	_check_deadline(deadline, "workspace fingerprint file reading")
	if (
		before.st_size < 0
		or before.st_size > MAX_WORKSPACE_FINGERPRINT_UNTRACKED_FILE_BYTES
	):
		raise WorkspaceFingerprintSetupError(
			"Untracked workspace file has an unsupported fingerprint size "
			f"{before.st_size}: {path}"
		)
	if _stat_is_regular_reparse(before):
		raise WorkspaceFingerprintSetupError(
			f"Untracked workspace regular file is a reparse point: {path}"
		)
	if not _stat_has_verifiable_identity(before):
		raise WorkspaceFingerprintSetupError(
			f"Untracked workspace file identity is unavailable: {path}"
		)
	flags = (
		os.O_RDONLY
		| getattr(os, "O_BINARY", 0)
		| getattr(os, "O_CLOEXEC", 0)
		| getattr(os, "O_NOFOLLOW", 0)
	)
	try:
		file_descriptor = os.open(path, flags)
	except TimeoutError:
		raise
	except OSError as exc:
		raise WorkspaceFingerprintSetupError(
			f"Could not open untracked workspace file safely: {path}: {exc}"
		) from exc
	try:
		candidate = digest.copy()
		byte_count = 0
		try:
			opened_before = os.fstat(file_descriptor)
			if _stat_is_regular_reparse(opened_before):
				raise WorkspaceFingerprintDriftError(
					f"Untracked workspace file became a reparse point while opening: {path}"
				)
			if not _stat_has_verifiable_identity(opened_before):
				raise WorkspaceFingerprintSetupError(
					f"Opened untracked workspace file identity is unavailable: {path}"
				)
			if not _same_regular_file_cross_view(before, opened_before):
				raise WorkspaceFingerprintDriftError(
					f"Untracked workspace file changed while opening: {path}"
				)
			while byte_count <= before.st_size:
				_check_deadline(deadline, "workspace fingerprint file reading")
				chunk = os.read(
					file_descriptor,
					min(
						WORKSPACE_FINGERPRINT_CHUNK_BYTES,
						before.st_size + 1 - byte_count,
					),
				)
				_check_deadline(deadline, "workspace fingerprint file reading")
				if not chunk:
					break
				candidate.update(chunk)
				byte_count += len(chunk)
			if byte_count > before.st_size:
				raise WorkspaceFingerprintDriftError(
					f"Untracked workspace file grew while being read: {path}"
				)
			opened_after = os.fstat(file_descriptor)
		except TimeoutError:
			raise
		except OSError as exc:
			raise WorkspaceFingerprintSetupError(
				f"Could not read untracked workspace file safely: {path}: {exc}"
			) from exc
	finally:
		try:
			os.close(file_descriptor)
		except TimeoutError:
			raise
		except OSError as exc:
			raise WorkspaceFingerprintSetupError(
				f"Could not close untracked workspace file safely: {path}: {exc}"
			) from exc
	try:
		after = path.lstat()
	except OSError as exc:
		raise WorkspaceFingerprintDriftError(
			f"Untracked workspace file disappeared while reading: {path}"
		) from exc
	if (
		_stat_is_regular_reparse(after)
		or not _stat_has_verifiable_identity(after)
		or not _same_regular_file_snapshot(opened_before, opened_after)
		or not _same_regular_file_cross_view(opened_after, after)
		or not _same_regular_file_snapshot(before, after)
		or byte_count != opened_after.st_size
	):
		raise WorkspaceFingerprintDriftError(
			f"Untracked workspace file changed while being read: {path}"
		)
	_check_deadline(deadline, "workspace fingerprint file reading")
	return candidate


def _stat_has_verifiable_identity(value: os.stat_result) -> bool:
	return int(getattr(value, "st_ino", 0)) != 0


def _stat_is_regular_reparse(value: os.stat_result) -> bool:
	return (
		stat.S_ISREG(value.st_mode)
		and bool(int(getattr(value, "st_file_attributes", 0)) & FILE_ATTRIBUTE_REPARSE_POINT)
	)


def _same_symlink_snapshot(left: os.stat_result, right: os.stat_result) -> bool:
	return (
		stat.S_ISLNK(left.st_mode)
		and stat.S_ISLNK(right.st_mode)
		and _stat_has_verifiable_identity(left)
		and _stat_has_verifiable_identity(right)
		and left.st_dev == right.st_dev
		and left.st_ino == right.st_ino
		and left.st_mode == right.st_mode
		and left.st_size == right.st_size
		and left.st_mtime_ns == right.st_mtime_ns
		and left.st_ctime_ns == right.st_ctime_ns
		and int(getattr(left, "st_file_attributes", 0))
		== int(getattr(right, "st_file_attributes", 0))
	)


def _same_regular_file_snapshot(left: os.stat_result, right: os.stat_result) -> bool:
	return (
		_same_regular_file_cross_view(left, right)
		and left.st_mode == right.st_mode
		and left.st_size == right.st_size
		and left.st_mtime_ns == right.st_mtime_ns
		and left.st_ctime_ns == right.st_ctime_ns
		and int(getattr(left, "st_file_attributes", 0))
		== int(getattr(right, "st_file_attributes", 0))
	)


def _same_regular_file_cross_view(left: os.stat_result, right: os.stat_result) -> bool:
	"""Compare lstat/fstat views without relying on Windows' differing ctime view."""
	return (
		stat.S_ISREG(left.st_mode)
		and stat.S_ISREG(right.st_mode)
		and not _stat_is_regular_reparse(left)
		and not _stat_is_regular_reparse(right)
		and _stat_has_verifiable_identity(left)
		and _stat_has_verifiable_identity(right)
		and os.path.samestat(left, right)
		and left.st_mode == right.st_mode
		and left.st_size == right.st_size
		and left.st_mtime_ns == right.st_mtime_ns
	)


def run_git_bytes(
	root: Path,
	args: list[str],
	*,
	input_bytes: bytes | None = None,
	deadline: float | None = None,
) -> bytes:
	"""Run Git under the shared tree owner while preserving exact binary I/O."""
	timeout_seconds = _remaining_timeout(deadline, "workspace fingerprint git operation")
	effective_timeout = min(30.0, timeout_seconds)
	command = ["git", *args]
	try:
		completed = run_supervised_process(
			command,
			cwd=root,
			timeout_seconds=effective_timeout,
			stdin_bytes=input_bytes,
			text_errors="surrogateescape",
			binary_output=True,
		)
	except SupervisedProcessStartError as error:
		raise WorkspaceFingerprintSetupError(
			"Git workspace fingerprint command could not start."
		) from error
	except Exception as error:
		raise WorkspaceFingerprintProcessBoundaryError(
			"Git workspace fingerprint supervision did not return a quiet-boundary proof."
		) from error
	if completed.process_boundary_quiescent is not True:
		raise WorkspaceFingerprintProcessBoundaryError(
			"Git workspace fingerprint supervision did not prove a quiet process boundary."
		)
	stdout = completed.stdout.encode("utf-8", errors="surrogateescape")
	stderr = completed.stderr.encode("utf-8", errors="surrogateescape")
	if completed.timed_out:
		raise subprocess.TimeoutExpired(
			command,
			effective_timeout,
			output=stdout,
			stderr=stderr,
		)
	if completed.return_code != 0:
		message = stderr.decode("utf-8", errors="replace").strip()
		raise RuntimeError(f"git {' '.join(args)} failed: {message}")
	return stdout


def _remaining_timeout(deadline: float | None, operation: str) -> float:
	if deadline is None:
		return 30.0
	remaining = deadline - time.perf_counter()
	if remaining <= 0.0:
		raise TimeoutError(f"Suite deadline exhausted during {operation}.")
	return max(0.001, remaining)


def _check_deadline(deadline: float | None, operation: str) -> None:
	if deadline is not None and time.perf_counter() >= deadline:
		raise TimeoutError(f"Suite deadline exhausted during {operation}.")


class CheckGraph:
	"""Validate and expand a deterministic dependency graph of maintenance checks."""

	def __init__(
		self,
		check_names: Iterable[str],
		dependencies: Mapping[str, Iterable[str]],
	) -> None:
		self._check_names = frozenset(check_names)
		self._dependencies = {
			name: tuple(dependency_names)
			for name, dependency_names in dependencies.items()
		}
		self._validate()

	def expand(self, requested_names: Iterable[str]) -> list[str]:
		"""Return a topologically ordered closure with every check exactly once."""
		expanded: list[str] = []
		completed: set[str] = set()
		visiting: list[str] = []

		def append_check(name: str) -> None:
			if name in completed:
				return
			if name not in self._check_names:
				raise ValueError(f"Unknown maintenance check: {name}")
			if name in visiting:
				cycle_start = visiting.index(name)
				cycle = " -> ".join([*visiting[cycle_start:], name])
				raise ValueError(f"Maintenance check dependency cycle: {cycle}")
			visiting.append(name)
			for dependency in self.dependencies_for(name):
				append_check(dependency)
			visiting.pop()
			completed.add(name)
			expanded.append(name)

		for check_name in requested_names:
			append_check(check_name)
		return expanded

	def dependencies_for(self, name: str) -> tuple[str, ...]:
		return self._dependencies.get(name, ())

	def describe(self, selected_names: Iterable[str]) -> dict[str, Any]:
		selected = list(selected_names)
		selected_set = set(selected)
		edges = [
			{"check": name, "depends_on": dependency}
			for name in selected
			for dependency in self.dependencies_for(name)
			if dependency in selected_set
		]
		return {
			"node_count": len(selected),
			"edge_count": len(edges),
			"nodes": selected,
			"edges": edges,
			"fingerprint": stable_fingerprint({"nodes": selected, "edges": edges}),
		}

	def _validate(self) -> None:
		for name, dependencies in self._dependencies.items():
			if name not in self._check_names:
				raise ValueError(f"Unknown maintenance check dependency owner: {name}")
			seen: set[str] = set()
			for dependency in dependencies:
				if dependency not in self._check_names:
					raise ValueError(f"Unknown maintenance check dependency: {name} -> {dependency}")
				if dependency == name:
					raise ValueError(f"Maintenance check cannot depend on itself: {name}")
				if dependency in seen:
					raise ValueError(f"Duplicate maintenance check dependency: {name} -> {dependency}")
				seen.add(dependency)
		self.expand(sorted(self._check_names))


@dataclass(frozen=True)
class TimeoutBudget:
	"""Resolved timeout layers for one check invocation."""

	policy_seconds: float
	requested_minimum_seconds: float | None
	suite_remaining_seconds: float | None
	effective_seconds: float

	def to_dict(self) -> dict[str, float | None]:
		return {
			"policy_seconds": self.policy_seconds,
			"requested_minimum_seconds": self.requested_minimum_seconds,
			"suite_remaining_seconds": self.suite_remaining_seconds,
			"effective_seconds": self.effective_seconds,
		}


def resolve_timeout_budget(
	policy_seconds: float,
	requested_minimum_seconds: float | None,
	suite_remaining_seconds: float | None,
) -> TimeoutBudget:
	policy_seconds = _validated_timeout_seconds("policy_seconds", policy_seconds)
	if requested_minimum_seconds is not None:
		requested_minimum_seconds = _validated_timeout_seconds(
			"requested_minimum_seconds",
			requested_minimum_seconds,
		)
	if suite_remaining_seconds is not None:
		suite_remaining_seconds = _validated_timeout_seconds(
			"suite_remaining_seconds",
			suite_remaining_seconds,
		)
	check_seconds = policy_seconds
	if requested_minimum_seconds is not None:
		check_seconds = max(check_seconds, requested_minimum_seconds)
	effective_seconds = check_seconds
	if suite_remaining_seconds is not None:
		effective_seconds = min(effective_seconds, max(0.001, suite_remaining_seconds))
	return TimeoutBudget(
		policy_seconds=policy_seconds,
		requested_minimum_seconds=requested_minimum_seconds,
		suite_remaining_seconds=suite_remaining_seconds,
		effective_seconds=effective_seconds,
	)


def _validated_timeout_seconds(field_name: str, value: float) -> float:
	if isinstance(value, bool) or not isinstance(value, (int, float)):
		raise ValueError(f"{field_name} must be a finite non-negative number.")
	seconds = float(value)
	if not math.isfinite(seconds) or seconds < 0.0:
		raise ValueError(f"{field_name} must be a finite non-negative number.")
	return seconds


def make_check_input_fingerprint(
	name: str,
	declared_command: list[str],
	effective_command: list[str] | None,
	workspace_fingerprint: str,
	dependency_fingerprints: Mapping[str, str],
	timeout_budget: TimeoutBudget,
) -> str:
	return stable_fingerprint({
		"schema_version": 2,
		"name": name,
		"declared_command": declared_command,
		"effective_command": effective_command,
		"workspace_fingerprint": workspace_fingerprint,
		"dependencies": dict(sorted(dependency_fingerprints.items())),
		"timeout": timeout_budget.to_dict(),
	})


def make_check_result_fingerprint(
	input_fingerprint: str,
	*,
	exit_code: int,
	timed_out: bool,
	stdout: str,
	stderr: str,
) -> str:
	return make_check_result_fingerprint_from_output_evidence(
		input_fingerprint,
		exit_code=exit_code,
		timed_out=timed_out,
		stdout_sha256=hashlib.sha256(
			stdout.encode("utf-8", errors="replace")
		).hexdigest(),
		stderr_sha256=hashlib.sha256(
			stderr.encode("utf-8", errors="replace")
		).hexdigest(),
	)


def make_check_result_fingerprint_from_output_evidence(
	input_fingerprint: str,
	*,
	exit_code: int,
	timed_out: bool,
	stdout_sha256: str,
	stderr_sha256: str,
) -> str:
	"""Bind a result to complete-output digests without requiring output replay."""
	return stable_fingerprint({
		"schema_version": 1,
		"input_fingerprint": input_fingerprint,
		"exit_code": exit_code,
		"timed_out": timed_out,
		"stdout_sha256": stdout_sha256,
		"stderr_sha256": stderr_sha256,
	})
