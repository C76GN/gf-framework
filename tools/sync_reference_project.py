#!/usr/bin/env python3
"""Sync the local GF addon into the reference example project."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = Path("addons/gf")
DEFAULT_PROJECT_ROOT = Path("../gf-reference-project")
PROJECT_PATH_ENV_VAR = "GF_REFERENCE_PROJECT_PATH"
BLOCKED_DIR_NAMES = {
	".git",
	".godot",
	".import",
	".mypy_cache",
	".pytest_cache",
	".vs",
	"__pycache__",
	"node_modules",
}
BLOCKED_FILE_NAMES = {
	".DS_Store",
	"Thumbs.db",
}
BLOCKED_SUFFIXES = {
	".import",
	".log",
	".pyc",
	".pyo",
	".tmp",
}


@dataclass
class SyncStats:
	mode: str
	source: Path
	target: Path
	dry_run: bool = False
	cleaned: bool = False
	linked: bool = False
	directories: int = 0
	files: int = 0
	bytes: int = 0
	skipped: int = 0

	def to_dict(self) -> dict[str, Any]:
		return {
			"mode": self.mode,
			"source": relative_to_root(self.source),
			"target": relative_to_root(self.target),
			"dry_run": self.dry_run,
			"cleaned": self.cleaned,
			"linked": self.linked,
			"directories": self.directories,
			"files": self.files,
			"bytes": self.bytes,
			"skipped": self.skipped,
		}


@dataclass
class CheckStats:
	source: Path
	target: Path
	mismatches: list[str]

	def to_dict(self) -> dict[str, Any]:
		return {
			"source": relative_to_root(self.source),
			"target": relative_to_root(self.target),
			"ok": not self.mismatches,
			"mismatches": self.mismatches,
		}


def main() -> int:
	configure_stdio()
	parser = argparse.ArgumentParser(description="Sync root addons/gf into the reference project addons/gf.")
	parser.add_argument("--source", default=str(DEFAULT_SOURCE), help="GF addon source directory.")
	parser.add_argument(
		"--project-root",
		default=None,
		help=(
			"Reference project root. Defaults to GF_REFERENCE_PROJECT_PATH "
			"or ../gf-reference-project."
		),
	)
	parser.add_argument(
		"--project",
		dest="project_root",
		default=None,
		help="Deprecated alias for --project-root.",
	)
	parser.add_argument("--mode", choices=["copy", "link"], default="copy", help="Sync mode. Copy is portable.")
	parser.add_argument("--no-clean", action="store_true", help="Keep the existing target before syncing.")
	parser.add_argument("--dry-run", action="store_true", help="Report planned work without writing files.")
	parser.add_argument("--check", action="store_true", help="Verify the target addon is current without writing files.")
	parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")
	args = parser.parse_args()

	project_root = (
		args.project_root
		or os.environ.get(PROJECT_PATH_ENV_VAR, "")
		or str(DEFAULT_PROJECT_ROOT)
	)
	source = resolve_workspace_path(args.source)
	project = resolve_workspace_path(project_root)
	target = project / "addons" / "gf"

	if not source.exists() or not source.is_dir():
		print(f"source directory not found: {source}", file=sys.stderr)
		return 2
	if not project.exists() or not project.is_dir():
		print(f"reference project not found: {project}", file=sys.stderr)
		return 2

	try:
		assert_reference_project(project)
		assert_generated_target(project, target)
		if args.check:
			check_stats = check_addon(source, target)
			if args.json:
				print(json.dumps(check_stats.to_dict(), ensure_ascii=False, indent=2))
			else:
				print(render_check_stats(check_stats))
			return 0 if not check_stats.mismatches else 1
		stats = sync_addon(
			source=source,
			target=target,
			mode=args.mode,
			clean=not args.no_clean,
			dry_run=args.dry_run,
		)
	except OSError as exc:
		print(f"sync failed: {exc}", file=sys.stderr)
		return 1
	except ValueError as exc:
		print(f"sync blocked: {exc}", file=sys.stderr)
		return 1

	if args.json:
		print(json.dumps(stats.to_dict(), ensure_ascii=False, indent=2))
	else:
		print(render_stats(stats))
	return 0


def configure_stdio() -> None:
	for stream in (sys.stdin, sys.stdout, sys.stderr):
		if hasattr(stream, "reconfigure"):
			stream.reconfigure(encoding="utf-8", errors="replace")


def resolve_workspace_path(value: str) -> Path:
	path = Path(value)
	if not path.is_absolute():
		path = ROOT / path
	return path.resolve()


def assert_generated_target(project: Path, target: Path) -> None:
	expected_parent = (project / "addons").resolve()
	target_parent = target.parent.resolve()
	if target_parent != expected_parent or target.name != "gf":
		raise ValueError(f"target must be {expected_parent / 'gf'}")


def assert_reference_project(project: Path) -> None:
	project_file = project / "project.godot"
	if not project_file.is_file():
		raise ValueError(f"reference project must contain project.godot: {project_file}")


def check_addon(source: Path, target: Path) -> CheckStats:
	mismatches: list[str] = []
	if not path_exists(target):
		return CheckStats(source=source, target=target, mismatches=[f"missing target: {target}"])
	if target.is_symlink():
		if target.resolve() != source.resolve():
			mismatches.append(f"stale symlink: {target} -> {target.resolve()}")
		return CheckStats(source=source, target=target, mismatches=mismatches)
	if not target.is_dir():
		return CheckStats(source=source, target=target, mismatches=[f"target is not a directory: {target}"])

	expected_files: set[str] = set()
	for source_path in sorted(source.rglob("*")):
		if should_skip(source_path):
			continue
		relative_path = source_path.relative_to(source)
		relative_key = relative_path.as_posix()
		target_path = target / relative_path
		if source_path.is_symlink():
			continue
		if source_path.is_dir():
			if not target_path.is_dir():
				mismatches.append(f"missing directory: {relative_key}")
			continue
		if source_path.is_file():
			expected_files.add(relative_key)
			if not target_path.is_file():
				mismatches.append(f"missing file: {relative_key}")
				continue
			if source_path.read_bytes() != target_path.read_bytes():
				mismatches.append(f"stale file: {relative_key}")

	for target_path in sorted(target.rglob("*")):
		if should_skip(target_path):
			continue
		if not target_path.is_file():
			continue
		relative_key = target_path.relative_to(target).as_posix()
		if relative_key not in expected_files:
			mismatches.append(f"extra file: {relative_key}")

	return CheckStats(source=source, target=target, mismatches=mismatches)


def sync_addon(source: Path, target: Path, mode: str, clean: bool, dry_run: bool) -> SyncStats:
	stats = SyncStats(mode=mode, source=source, target=target, dry_run=dry_run)
	if clean and path_exists(target):
		stats.cleaned = True
		if not dry_run:
			remove_target(target)

	if mode == "link":
		link_addon(source, target, dry_run)
		stats.linked = True
		return stats

	copy_addon(source, target, dry_run, stats)
	return stats


def path_exists(path: Path) -> bool:
	return path.exists() or path.is_symlink()


def remove_target(target: Path) -> None:
	if target.is_symlink() or target.is_file():
		target.unlink()
		return
	if target.is_dir():
		shutil.rmtree(target)
		return
	raise OSError(f"unsupported target path type: {target}")


def link_addon(source: Path, target: Path, dry_run: bool) -> None:
	if dry_run:
		return
	if path_exists(target):
		raise OSError(f"target already exists: {target}")
	target.parent.mkdir(parents=True, exist_ok=True)
	os.symlink(source, target, target_is_directory=True)


def copy_addon(source: Path, target: Path, dry_run: bool, stats: SyncStats) -> None:
	if not dry_run:
		target.mkdir(parents=True, exist_ok=True)
	for source_path in sorted(source.rglob("*")):
		if should_skip(source_path):
			stats.skipped += 1
			continue
		relative_path = source_path.relative_to(source)
		target_path = target / relative_path
		if source_path.is_symlink():
			stats.skipped += 1
			continue
		if source_path.is_dir():
			stats.directories += 1
			if not dry_run:
				target_path.mkdir(parents=True, exist_ok=True)
			continue
		if source_path.is_file():
			stats.files += 1
			stats.bytes += source_path.stat().st_size
			if not dry_run:
				target_path.parent.mkdir(parents=True, exist_ok=True)
				shutil.copy2(source_path, target_path)


def should_skip(path: Path) -> bool:
	if any(part in BLOCKED_DIR_NAMES for part in path.parts):
		return True
	if path.name in BLOCKED_FILE_NAMES:
		return True
	if path.suffix in BLOCKED_SUFFIXES:
		return True
	return False


def render_stats(stats: SyncStats) -> str:
	return "\n".join([
		f"mode: {stats.mode}",
		f"source: {relative_to_root(stats.source)}",
		f"target: {relative_to_root(stats.target)}",
		f"dry_run: {stats.dry_run}",
		f"cleaned: {stats.cleaned}",
		f"linked: {stats.linked}",
		f"directories: {stats.directories}",
		f"files: {stats.files}",
		f"bytes: {stats.bytes}",
		f"skipped: {stats.skipped}",
	])


def render_check_stats(stats: CheckStats) -> str:
	lines = [
		f"source: {relative_to_root(stats.source)}",
		f"target: {relative_to_root(stats.target)}",
		f"ok: {not stats.mismatches}",
	]
	if stats.mismatches:
		lines.append("mismatches:")
		for mismatch in stats.mismatches[:80]:
			lines.append(f"- {mismatch}")
		if len(stats.mismatches) > 80:
			lines.append(f"- ... {len(stats.mismatches) - 80} more")
	return "\n".join(lines)


def relative_to_root(path: Path) -> str:
	try:
		return path.resolve().relative_to(ROOT).as_posix()
	except ValueError:
		return path.resolve().as_posix()


if __name__ == "__main__":
	raise SystemExit(main())
