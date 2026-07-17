#!/usr/bin/env python3
"""Check graph, timeout budgets, and provenance fingerprints for GF maintenance."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from typing import Iterable
from typing import Mapping


def stable_fingerprint(value: Any) -> str:
	"""Return a stable SHA-256 fingerprint for JSON-compatible maintenance data."""
	payload = json.dumps(
		value,
		ensure_ascii=False,
		sort_keys=True,
		separators=(",", ":"),
	).encode("utf-8")
	return hashlib.sha256(payload).hexdigest()


def workspace_fingerprint(root: Path) -> dict[str, Any]:
	"""Fingerprint committed state plus every non-ignored local change."""
	head = run_git_bytes(root, ["rev-parse", "HEAD"]).decode("utf-8", errors="replace").strip()
	diff = run_git_bytes(root, ["diff", "--binary", "--no-ext-diff", "HEAD", "--"])
	untracked_output = run_git_bytes(root, ["ls-files", "--others", "--exclude-standard", "-z"])
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
	for relative_path in untracked_paths:
		digest.update(b"\0untracked\0")
		digest.update(relative_path.encode("utf-8", errors="surrogateescape"))
		path = root / relative_path
		try:
			file_stat = path.lstat()
			digest.update(f"\0mode={file_stat.st_mode:o}\0size={file_stat.st_size}\0".encode("ascii"))
			if path.is_symlink():
				digest.update(os.readlink(path).encode("utf-8", errors="surrogateescape"))
			elif path.is_file():
				digest.update(path.read_bytes())
		except OSError as exc:
			digest.update(f"\0unreadable={type(exc).__name__}:{exc}\0".encode("utf-8", errors="replace"))
	return {
		"schema_version": 1,
		"head": head,
		"dirty": bool(diff or untracked_paths),
		"untracked_file_count": len(untracked_paths),
		"fingerprint": digest.hexdigest(),
	}


def run_git_bytes(root: Path, args: list[str]) -> bytes:
	completed = subprocess.run(
		["git", *args],
		cwd=root,
		capture_output=True,
		check=False,
		timeout=30,
	)
	if completed.returncode != 0:
		message = completed.stderr.decode("utf-8", errors="replace").strip()
		raise RuntimeError(f"git {' '.join(args)} failed: {message}")
	return completed.stdout


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


def make_check_input_fingerprint(
	name: str,
	command: list[str],
	workspace_fingerprint: str,
	dependency_fingerprints: Mapping[str, str],
	timeout_budget: TimeoutBudget,
) -> str:
	return stable_fingerprint({
		"schema_version": 1,
		"name": name,
		"command": command,
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
	return stable_fingerprint({
		"schema_version": 1,
		"input_fingerprint": input_fingerprint,
		"exit_code": exit_code,
		"timed_out": timed_out,
		"stdout_sha256": hashlib.sha256(stdout.encode("utf-8", errors="replace")).hexdigest(),
		"stderr_sha256": hashlib.sha256(stderr.encode("utf-8", errors="replace")).hexdigest(),
	})
