#!/usr/bin/env python3
"""Preview canonical GDScript layout and explicitly write proven token spacing."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path, PurePosixPath
import stat
import tempfile

from generated_output_transaction import validate_controlled_path
from gf_gdscript_format_plan import FormatPlan, MAX_FORMAT_BYTES
import gf_gdscript_readability as readability
from gf_path_security import read_pinned_utf8_regular_file


ROOT = Path(__file__).resolve().parents[1]


def capture_file(root: Path, relative_path: str) -> FormatPlan:
	"""Capture one bounded owned source, rejecting links and path aliases."""
	relative = PurePosixPath(relative_path)
	if (
		relative.as_posix() != relative_path or "\\" in relative_path
		or relative.is_absolute() or ".." in relative.parts
		or not relative_path.startswith(("addons/gf/", "tests/gf_core/"))
		or not relative_path.endswith((".gd", ".gd.txt"))
	):
		raise ValueError("Select one canonical repository-relative GF-owned .gd source or .gd.txt template.")
	source = read_pinned_utf8_regular_file(root, relative_path, max_bytes=MAX_FORMAT_BYTES)
	return FormatPlan.capture(relative_path, source)


def apply_safe_plan(root: Path, plan: FormatPlan) -> bool:
	"""Stage and replace one unchanged file; never apply caller-supplied edits.

		The plan's source is an optimistic concurrency token. Re-capture and compare
		before staging and immediately before replacement. This guards ordinary
		concurrent edits, not a hostile filesystem writer racing the final replace.
	"""
	captured = capture_file(root, plan.path)
	if captured.source != plan.source:
		raise ValueError("Source changed since the preview; capture a new format plan.")
	candidate = captured.safe_source()
	if candidate == captured.source:
		return False
	target = validate_controlled_path(root / plan.path, root)
	initial_stat = target.stat()
	parent_identity = (target.parent.stat().st_dev, target.parent.stat().st_ino)
	staged: Path | None = None
	try:
		descriptor, temporary = tempfile.mkstemp(prefix=f".{target.name}.format-", dir=target.parent)
		staged = Path(temporary)
		with os.fdopen(descriptor, "wb") as stream:
			stream.write(candidate.encode("utf-8"))
			stream.flush()
			os.fsync(stream.fileno())
		os.chmod(staged, stat.S_IMODE(initial_stat.st_mode))
		if capture_file(root, plan.path).source != captured.source:
			raise ValueError("Source changed while staging; no formatting was applied.")
		validate_controlled_path(target, root)
		validate_controlled_path(staged, root)
		current = target.stat()
		if (
			(current.st_dev, current.st_ino, current.st_mtime_ns, current.st_size)
			!= (initial_stat.st_dev, initial_stat.st_ino, initial_stat.st_mtime_ns, initial_stat.st_size)
			or (target.parent.stat().st_dev, target.parent.stat().st_ino) != parent_identity
		):
			raise ValueError("Source identity changed while staging; no formatting was applied.")
		os.replace(staged, target)
		staged = None
		return True
	finally:
		if staged is not None:
			validate_controlled_path(staged, root)
			staged.unlink(missing_ok=True)


def format_file(root: Path, relative_path: str, *, write: bool = False) -> dict:
	plan = capture_file(root, relative_path)
	suggested = plan.suggested_source()
	safe = plan.safe_source() if relative_path.endswith(".gd") else plan.source
	written = apply_safe_plan(root, plan) if write else False
	remaining = readability.audit_source(plan.path, safe if write else plan.source)
	return {
		"ok": not remaining,
		"path": plan.path,
		"source_sha256": plan.source_sha256,
		"write_applied": written,
		"write_scope": "horizontal_token_spacing" if relative_path.endswith(".gd") else "unsupported_template",
		"suggested_diff": plan.diff(suggested),
		"safe_diff": plan.diff(safe),
		"remaining_issues": remaining,
		"complete": not remaining,
	}


def main(argv: list[str] | None = None) -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--path", required=True, help="One literal repository-relative owned source or template.")
	parser.add_argument("--write", action="store_true", help="Apply only proven horizontal token spacing. Remaining violations still fail.")
	parser.add_argument("--json", action="store_true", help="Print structured diffs and remaining diagnostics.")
	args = parser.parse_args(argv)
	try:
		result = format_file(ROOT, args.path, write=args.write)
	except (OSError, ValueError) as error:
		result = {"ok": False, "write_applied": False, "error": str(error)}
	if args.json:
		print(json.dumps(result, ensure_ascii=False, indent=2))
	elif "error" in result:
		print(result["error"])
	else:
		print(result["safe_diff"] if args.write else result["suggested_diff"], end="")
		print(f"Applied: {result['write_applied']}; remaining violations: {len(result['remaining_issues'])}.")
	return 0 if result["ok"] else 1


if __name__ == "__main__":
	raise SystemExit(main())
