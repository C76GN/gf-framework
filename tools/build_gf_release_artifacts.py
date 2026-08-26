#!/usr/bin/env python3
"""Build and verify the complete, intentionally small GF release artifact set."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import secrets
import shutil
import sys
import time
import zipfile
from pathlib import Path
from typing import Any

import build_asset_store_package
import build_gf_ai_developer_kit
from gf_path_security import absolute_lexical_path
from gf_path_security import path_has_reparse_component
from gf_path_security import path_is_inside_lexical
from gf_path_security import PinnedReadError
from gf_path_security import read_pinned_regular_file
from gf_process_authority import freeze_process_authority
from gf_process_authority import FrozenGitProcess
from gf_process_authority import FrozenProcessEnvironment
from gf_process_supervisor import require_supervised_binary_quiet_boundary
from gf_process_supervisor import run_supervised_process_bytes
from gf_process_supervisor import SupervisedProcessCleanupError


ROOT = Path(__file__).resolve().parents[1]
BUILD_ROOT = ROOT / "build"
MANIFEST_SCHEMA_VERSION = 3
MANIFEST_MAX_BYTES = 1024 * 1024
FULL_GIT_OBJECT_ID_RE = re.compile(r"(?:[0-9a-f]{40}|[0-9a-f]{64})")
RELEASE_ARTIFACT_ROLES = ("framework", "ai_developer_kit")


def main() -> int:
	configure_stdio()
	parser = argparse.ArgumentParser(
		description="Build the complete GF release artifact set once."
	)
	parser.add_argument(
		"--version",
		default="",
		help="Release SemVer. Defaults to addons/gf/plugin.cfg.",
	)
	parser.add_argument(
		"--output-dir",
		default="",
		help="Final artifact directory under build/.",
	)
	parser.add_argument(
		"--manifest",
		default="",
		help="Manifest path for --validate-only.",
	)
	parser.add_argument(
		"--validate-only",
		action="store_true",
		help="Validate an existing artifact manifest.",
	)
	parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")
	args = parser.parse_args()

	version = args.version.strip() or build_asset_store_package.read_plugin_version()
	output_dir = resolve_output_dir(args.output_dir, version)
	manifest_path = resolve_manifest_path(args.manifest, output_dir, version)
	try:
		process_authority = freeze_process_authority(
			FrozenProcessEnvironment.capture(os.environ),
			cwd=ROOT,
		)
		source_revision = git_head(process_authority.git)
	except SupervisedProcessCleanupError:
		raise
	except (OSError, RuntimeError, UnicodeError, ValueError) as error:
		result = make_failure(
			version,
			output_dir,
			[f"Release Git authority setup failed: {type(error).__name__}"],
		)
	else:
		if args.validate_only:
			result = audit_release_artifact_manifest(
				manifest_path,
				version,
				source_revision,
			)
		else:
			result = build_release_artifacts(
				version,
				output_dir,
				source_revision=source_revision,
			)
	print_result(result, args.json)
	return 0 if result.get("ok") else 1


def configure_stdio() -> None:
	for stream in (sys.stdin, sys.stdout, sys.stderr):
		if hasattr(stream, "reconfigure"):
			stream.reconfigure(encoding="utf-8", errors="replace")


def build_release_artifacts(
	version: str,
	output_dir: Path,
	*,
	source_revision: str,
) -> dict[str, Any]:
	if (
		type(source_revision) is not str
		or FULL_GIT_OBJECT_ID_RE.fullmatch(source_revision) is None
	):
		return make_failure(
			version,
			output_dir,
			["Release source revision must be one exact Git object id."],
		)
	plugin_version = build_asset_store_package.read_plugin_version()
	if version != plugin_version:
		return make_failure(
			version,
			output_dir,
			[
				f"Requested version {version!r} does not match "
				f"plugin version {plugin_version!r}."
			],
		)
	validate_output_dir(output_dir)
	output_dir.parent.mkdir(parents=True, exist_ok=True)
	candidate = output_dir.parent / (
		f".{output_dir.name}.gf-release-{os.getpid()}-"
		f"{secrets.token_hex(8)}.candidate"
	)
	if os.path.lexists(candidate):
		return make_failure(
			version,
			output_dir,
			[f"Candidate path already exists: {candidate.as_posix()}"],
		)
	candidate.mkdir()
	try:
		framework_path = candidate / f"gf-framework-{version}.zip"
		build_asset_store_package.build_package(framework_path)
		framework_audit = build_asset_store_package.audit_package(framework_path)
		if not framework_audit.get("ok"):
			return make_failure(
				version,
				output_dir,
				list(framework_audit.get("issues", [])),
			)

		ai_kit_source_audit = build_gf_ai_developer_kit.check_source()
		if not ai_kit_source_audit.get("ok"):
			return make_failure(
				version,
				output_dir,
				list(ai_kit_source_audit.get("issues", [])),
			)
		ai_kit_path = candidate / f"gf-ai-developer-kit-{version}.zip"
		build_gf_ai_developer_kit.build_plugin_archive(ai_kit_path, version)
		ai_kit_audit = build_gf_ai_developer_kit.audit_plugin_archive(
			ai_kit_path,
			version,
		)
		if not ai_kit_audit.get("ok"):
			return make_failure(
				version,
				output_dir,
				list(ai_kit_audit.get("issues", [])),
			)

		artifacts = [
			artifact_record(framework_path, "framework"),
			artifact_record(ai_kit_path, "ai_developer_kit"),
		]
		manifest_path = candidate / f"gf-release-artifacts-{version}.json"
		write_json(manifest_path, {
			"schema_version": MANIFEST_SCHEMA_VERSION,
			"version": version,
			"source_revision": source_revision,
			"framework_archive_build_count": 1,
			"ai_developer_kit_build_count": 1,
			"artifact_count": len(artifacts),
			"artifacts": artifacts,
		})
		candidate_audit = audit_release_artifact_manifest(
			manifest_path,
			version,
			source_revision,
		)
		if not candidate_audit.get("ok"):
			return make_failure(
				version,
				output_dir,
				list(candidate_audit.get("issues", [])),
			)
		publish_candidate(candidate, output_dir)
		return audit_release_artifact_manifest(
			output_dir / manifest_path.name,
			version,
			source_revision,
		)
	except (OSError, ValueError, json.JSONDecodeError) as error:
		return make_failure(
			version,
			output_dir,
			[f"Release artifact build failed: {error}"],
		)
	finally:
		if candidate.exists():
			shutil.rmtree(candidate, ignore_errors=True)


def artifact_record(path: Path, role: str) -> dict[str, Any]:
	return {
		"role": role,
		"name": path.name,
		"path": path.name,
		"size_bytes": path.stat().st_size,
		"sha256": sha256_file(path),
	}


def audit_release_artifact_manifest(
	manifest_path: Path,
	expected_version: str = "",
	expected_revision: str = "",
	expected_manifest_sha256: str = "",
) -> dict[str, Any]:
	issues: list[str] = []
	try:
		manifest_path = absolute_lexical_path(manifest_path)
		manifest_bytes = read_pinned_regular_file(
			manifest_path.parent,
			manifest_path.name,
			max_bytes=MANIFEST_MAX_BYTES,
		)
		if (
			expected_manifest_sha256
			and hashlib.sha256(manifest_bytes).hexdigest()
			!= expected_manifest_sha256
		):
			return make_audit_result(
				expected_version,
				manifest_path,
				"",
				[],
				["Release artifact manifest identity changed before audit."],
			)
		data = json.loads(
			manifest_bytes.decode("utf-8", errors="strict"),
			parse_constant=reject_non_finite_json_constant,
			object_pairs_hook=reject_duplicate_json_object_keys,
		)
	except (OSError, PinnedReadError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as error:
		return make_audit_result(
			expected_version,
			manifest_path,
			"",
			[],
			[f"Release artifact manifest is unreadable: {error}"],
		)
	if not isinstance(data, dict):
		return make_audit_result(
			expected_version,
			manifest_path,
			"",
			[],
			["Release artifact manifest root must be an object."],
		)
	allowed_fields = {
		"schema_version",
		"version",
		"source_revision",
		"framework_archive_build_count",
		"ai_developer_kit_build_count",
		"artifact_count",
		"artifacts",
	}
	for field_name in sorted(set(data) - allowed_fields):
		issues.append(f"Release artifact manifest field is unsupported: {field_name}.")
	version = data.get("version", "") if isinstance(data.get("version"), str) else ""
	if (
		type(data.get("schema_version")) is not int
		or data["schema_version"] != MANIFEST_SCHEMA_VERSION
	):
		issues.append(
			f"Release artifact manifest schema_version must be "
			f"{MANIFEST_SCHEMA_VERSION}."
		)
	if expected_version and version != expected_version:
		issues.append(
			f"Release artifact manifest version is {version!r}, "
			f"expected {expected_version!r}."
		)
	raw_revision = data.get("source_revision", "")
	source_revision = raw_revision if isinstance(raw_revision, str) else ""
	if (
		type(raw_revision) is not str
		or FULL_GIT_OBJECT_ID_RE.fullmatch(source_revision) is None
	):
		issues.append(
			"Release artifact source_revision must be a full lowercase Git commit SHA."
		)
	if expected_revision and source_revision != expected_revision:
		issues.append(
			"Release artifact source_revision does not match the checked-out revision."
		)
	if (
		type(data.get("framework_archive_build_count")) is not int
		or data["framework_archive_build_count"] != 1
	):
		issues.append("GF Framework archive must be built exactly once.")
	if (
		type(data.get("ai_developer_kit_build_count")) is not int
		or data["ai_developer_kit_build_count"] != 1
	):
		issues.append("GF AI Developer Kit must be built exactly once.")
	raw_artifacts = data.get("artifacts", [])
	artifacts = raw_artifacts if isinstance(raw_artifacts, list) else []
	if not isinstance(raw_artifacts, list):
		issues.append("Release artifact manifest artifacts must be an array.")
	if (
		type(data.get("artifact_count")) is not int
		or data["artifact_count"] != len(artifacts)
	):
		issues.append("Release artifact_count does not match the artifact array.")
	issues.extend(audit_artifact_entries(manifest_path, version, artifacts))
	return make_audit_result(
		version,
		manifest_path,
		source_revision,
		artifacts,
		issues,
	)


def audit_artifact_entries(
	manifest_path: Path,
	version: str,
	artifacts: list[Any],
) -> list[str]:
	issues: list[str] = []
	expected_paths = {
		"framework": f"gf-framework-{version}.zip",
		"ai_developer_kit": f"gf-ai-developer-kit-{version}.zip",
	}
	seen_roles: set[str] = set()
	seen_paths: set[str] = set()
	paths_by_role: dict[str, Path] = {}
	for artifact in artifacts:
		if not isinstance(artifact, dict):
			issues.append("Release artifact entries must be objects.")
			continue
		if set(artifact) != {"role", "name", "path", "size_bytes", "sha256"}:
			issues.append("Release artifact entries must use the exact v3 field set.")
		role = artifact.get("role", "")
		relative_path = artifact.get("path", "")
		if not isinstance(role, str) or role not in RELEASE_ARTIFACT_ROLES:
			issues.append(f"Release artifact role is unsupported: {role!r}.")
			continue
		if role in seen_roles:
			issues.append(f"Release artifact role is duplicated: {role}.")
		seen_roles.add(role)
		if not isinstance(relative_path, str) or relative_path != expected_paths[role]:
			issues.append(
				f"Release artifact {role} path must be {expected_paths[role]}."
			)
			continue
		if relative_path in seen_paths:
			issues.append(f"Release artifact path is duplicated: {relative_path}.")
			continue
		seen_paths.add(relative_path)
		path = absolute_lexical_path(manifest_path.parent / relative_path)
		paths_by_role[role] = path
		if artifact.get("name") != path.name:
			issues.append(f"Release artifact name does not match: {relative_path}.")
		if (
			not path_is_inside_lexical(manifest_path.parent, path)
			or path_has_reparse_component(path)
		):
			issues.append(
				f"Release artifact path escapes or crosses a link: {relative_path}."
			)
			continue
		if not path.is_file():
			issues.append(f"Release artifact is missing: {relative_path}.")
			continue
		if (
			type(artifact.get("size_bytes")) is not int
			or artifact["size_bytes"] != path.stat().st_size
		):
			issues.append(f"Release artifact size mismatch: {relative_path}.")
		if artifact.get("sha256") != sha256_file(path):
			issues.append(f"Release artifact SHA-256 mismatch: {relative_path}.")
	for role in RELEASE_ARTIFACT_ROLES:
		if role not in seen_roles:
			issues.append(f"Release artifact role is missing: {role}.")
	if issues or set(paths_by_role) != set(RELEASE_ARTIFACT_ROLES):
		return issues
	framework_path = paths_by_role["framework"]
	framework_audit = build_asset_store_package.audit_package(framework_path)
	issues.extend(
		f"GF Framework artifact: {issue}"
		for issue in framework_audit.get("issues", [])
	)
	issues.extend(audit_zip_matches_source(
		framework_path,
		list(build_asset_store_package.iter_package_files()),
		"GF Framework artifact",
	))
	ai_kit_audit = build_gf_ai_developer_kit.audit_plugin_archive(
		paths_by_role["ai_developer_kit"],
		version,
	)
	issues.extend(
		f"GF AI Developer Kit artifact: {issue}"
		for issue in ai_kit_audit.get("issues", [])
	)
	expected_files = {
		manifest_path.name,
		*(path.name for path in paths_by_role.values()),
	}
	try:
		actual_entries = {
			entry.name
			for entry in manifest_path.parent.iterdir()
		}
	except OSError as error:
		issues.append(f"Release artifact directory cannot be enumerated: {error}")
	else:
		if actual_entries != expected_files:
			issues.append(
				"Release directory must contain only the two archives and their manifest."
			)
	return issues


def reject_non_finite_json_constant(value: str) -> Any:
	raise ValueError(f"non-finite JSON number is forbidden: {value}")


def reject_duplicate_json_object_keys(
	pairs: list[tuple[str, Any]],
) -> dict[str, Any]:
	result: dict[str, Any] = {}
	for key, value in pairs:
		if key in result:
			raise ValueError(f"duplicate JSON object key is forbidden: {key}")
		result[key] = value
	return result


def make_audit_result(
	version: str,
	manifest_path: Path,
	source_revision: str,
	artifacts: list[Any],
	issues: list[str],
) -> dict[str, Any]:
	return {
		"ok": not issues,
		"version": version,
		"manifest": manifest_path.as_posix(),
		"source_revision": source_revision,
		"artifact_count": len(artifacts),
		"artifacts": artifacts,
		"issues": issues,
	}


def audit_zip_matches_source(
	zip_path: Path,
	expected_files: list[Path],
	label: str,
) -> list[str]:
	issues: list[str] = []
	expected_by_name = {
		path.relative_to(ROOT).as_posix(): path
		for path in expected_files
	}
	try:
		with zipfile.ZipFile(zip_path, "r") as archive:
			names = [
				name
				for name in archive.namelist()
				if name and not name.endswith("/")
			]
			if len(names) != len(set(names)):
				issues.append(f"{label} contains duplicate ZIP entries.")
			for name in sorted(set(expected_by_name) - set(names))[:20]:
				issues.append(f"{label} is missing source file: {name}")
			for name in sorted(set(names) - set(expected_by_name))[:20]:
				issues.append(f"{label} contains undeclared source file: {name}")
			for name in sorted(set(names).intersection(expected_by_name)):
				try:
					expected_payload = read_pinned_regular_file(
						ROOT,
						name,
						max_bytes=(1 << 63) - 1,
					)
				except PinnedReadError as error:
					issues.append(
						f"{label} source cannot be read from a stable regular "
						f"file: {name}: {error.rule_id}"
					)
					if len(issues) >= 40:
						break
					continue
				if archive.read(name) != expected_payload:
					issues.append(f"{label} content differs from source: {name}")
					if len(issues) >= 40:
						break
	except (OSError, RuntimeError, zipfile.BadZipFile) as error:
		issues.append(f"{label} cannot be compared with source: {error}")
	return issues


def resolve_output_dir(value: str, version: str) -> Path:
	path = Path(value) if value.strip() else Path("build") / f"release-{version}"
	if not path.is_absolute():
		path = ROOT / path
	return absolute_lexical_path(path)


def resolve_manifest_path(value: str, output_dir: Path, version: str) -> Path:
	path = (
		Path(value)
		if value.strip()
		else output_dir / f"gf-release-artifacts-{version}.json"
	)
	if not path.is_absolute():
		path = ROOT / path
	return absolute_lexical_path(path)


def validate_output_dir(output_dir: Path) -> None:
	resolved_build_root = absolute_lexical_path(BUILD_ROOT)
	if (
		output_dir == resolved_build_root
		or not path_is_inside_lexical(resolved_build_root, output_dir)
	):
		raise ValueError("Release output directory must be a child of build/.")
	if path_has_reparse_component(output_dir):
		raise ValueError("Release output directory crosses a filesystem link.")


def publish_candidate(candidate: Path, output_dir: Path) -> None:
	backup = output_dir.parent / (
		f".{output_dir.name}.gf-release-backup-{secrets.token_hex(8)}"
	)
	if os.path.lexists(backup):
		raise OSError(f"Release artifact backup already exists: {backup.as_posix()}")
	moved_existing = False
	try:
		if output_dir.exists():
			replace_path_with_retry(output_dir, backup)
			moved_existing = True
		replace_path_with_retry(candidate, output_dir)
	except OSError:
		if moved_existing and backup.exists() and not output_dir.exists():
			replace_path_with_retry(backup, output_dir)
		raise
	if backup.exists():
		shutil.rmtree(backup)


def replace_path_with_retry(source: Path, target: Path, attempts: int = 8) -> None:
	"""Retry transient Windows sharing violations without weakening publication."""
	for attempt in range(attempts):
		try:
			os.replace(source, target)
			return
		except PermissionError:
			if (
				os.name != "nt"
				or attempt + 1 >= attempts
				or not source.exists()
				or target.exists()
			):
				raise
			time.sleep(0.05 * (2 ** attempt))


def write_json(path: Path, data: dict[str, Any]) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_text(
		json.dumps(data, ensure_ascii=False, indent=2) + "\n",
		encoding="utf-8",
	)


def sha256_file(path: Path) -> str:
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for chunk in iter(lambda: handle.read(1024 * 1024), b""):
			digest.update(chunk)
	return digest.hexdigest()


def git_head(git_process: FrozenGitProcess) -> str:
	identity = git_process.command(("rev-parse", "--verify", "HEAD"))
	deadline = time.perf_counter() + 30.0
	completed = run_supervised_process_bytes(
		list(identity.effective),
		cwd=ROOT,
		timeout_seconds=30.0,
		deadline=deadline,
		max_stdout_bytes=256,
		max_stderr_bytes=4096,
		environment=git_process.environment.values(),
	)
	completed = require_supervised_binary_quiet_boundary(
		completed,
		deadline=deadline,
	)
	if (
		completed.return_code != 0
		or completed.timed_out
		or completed.stdout_truncated
		or completed.stderr_truncated
		or completed.output_drain_failed
		or completed.stderr
	):
		raise RuntimeError("Git source revision capture did not complete cleanly.")
	revision_output = completed.stdout.decode("utf-8", errors="strict")
	if revision_output.endswith("\r\n"):
		revision = revision_output[:-2]
	elif revision_output.endswith("\n"):
		revision = revision_output[:-1]
	else:
		revision = revision_output
	if FULL_GIT_OBJECT_ID_RE.fullmatch(revision) is None:
		raise ValueError("Git source revision is not one exact object id.")
	return revision


def make_failure(
	version: str,
	output_dir: Path,
	issues: list[str],
) -> dict[str, Any]:
	return {
		"ok": False,
		"version": version,
		"output_dir": output_dir.as_posix(),
		"artifact_count": 0,
		"artifacts": [],
		"issues": issues,
	}


def print_result(result: dict[str, Any], as_json: bool) -> None:
	if as_json:
		print(json.dumps(result, ensure_ascii=False, indent=2))
		return
	print(
		f"ok={result.get('ok', False)} "
		f"version={result.get('version', '')} "
		f"artifacts={result.get('artifact_count', 0)}"
	)
	if result.get("manifest"):
		print(f"manifest={result['manifest']}")
	for issue in result.get("issues", []):
		print(f"- {issue}")


if __name__ == "__main__":
	raise SystemExit(main())
