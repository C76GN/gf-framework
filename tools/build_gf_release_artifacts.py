#!/usr/bin/env python3
"""Build and verify every GF release asset from one package archive pass."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import secrets
import shutil
import subprocess
import sys
import time
import urllib.parse
import zipfile
from pathlib import Path
from typing import Any

import build_asset_store_package
import build_gf_package
from gf_path_security import absolute_lexical_path
from gf_path_security import path_has_reparse_component
from gf_path_security import path_is_inside_lexical


ROOT = Path(__file__).resolve().parents[1]
BUILD_ROOT = ROOT / "build"
MANIFEST_SCHEMA_VERSION = 1
DEFAULT_CHANNEL = "stable"


def main() -> int:
	configure_stdio()
	parser = argparse.ArgumentParser(description="Build the complete GF release artifact set once.")
	parser.add_argument("--version", default="", help="Release SemVer. Defaults to addons/gf/plugin.cfg.")
	parser.add_argument("--output-dir", default="", help="Final artifact directory under build/.")
	parser.add_argument("--archive-base-url", default="", help="Public URL prefix for modular package archives.")
	parser.add_argument("--registry-url", default="", help="Public URL of the generated online registry.")
	parser.add_argument("--manifest", default="", help="Manifest path for --validate-only.")
	parser.add_argument("--validate-only", action="store_true", help="Validate an existing artifact manifest.")
	parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")
	args = parser.parse_args()

	version = args.version.strip() or build_asset_store_package.read_plugin_version()
	output_dir = resolve_output_dir(args.output_dir, version)
	manifest_path = resolve_manifest_path(args.manifest, output_dir, version)
	if args.validate_only:
		result = audit_release_artifact_manifest(manifest_path, version, git_head())
	else:
		archive_base_url = args.archive_base_url.strip() or (
			f"https://github.com/C76GN/gf-framework/releases/download/{version}"
		)
		registry_url = args.registry_url.strip() or f"{archive_base_url}/gf-registry-{version}.json"
		result = build_release_artifacts(
			version,
			output_dir,
			archive_base_url,
			registry_url,
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
	archive_base_url: str,
	registry_url: str,
) -> dict[str, Any]:
	plugin_version = build_asset_store_package.read_plugin_version()
	if version != plugin_version:
		return make_failure(
			version,
			output_dir,
			[f"Requested version {version!r} does not match plugin version {plugin_version!r}."],
		)
	validate_output_dir(output_dir)
	output_dir.parent.mkdir(parents=True, exist_ok=True)
	candidate = output_dir.parent / f".{output_dir.name}.gf-release-{os.getpid()}-{secrets.token_hex(8)}.candidate"
	if os.path.lexists(candidate):
		return make_failure(version, output_dir, [f"Candidate path already exists: {candidate.as_posix()}"])
	candidate.mkdir()
	try:
		asset_store_path = candidate / f"gf-framework-{version}.zip"
		build_asset_store_package.build_package(asset_store_path)
		asset_store_audit = build_asset_store_package.audit_package(asset_store_path)
		if not asset_store_audit.get("ok"):
			return make_failure(version, output_dir, list(asset_store_audit.get("issues", [])))

		offline_root = candidate / "offline"
		offline_package_dir = offline_root / "packages"
		offline_registry_path = offline_root / "registry/index.json"
		offline_source_path = offline_root / "registry/gf-registry-source.json"
		offline_bundle_path = candidate / f"gf-package-offline-bundle-{version}.zip"
		package_build = build_gf_package.build_gf_packages(
			package_ids=[],
			preset_ids=[],
			build_all=True,
			version_override=version,
			output_dir=str(offline_package_dir),
			registry_path=str(offline_registry_path),
			archive_base_url="",
			registry_source_path=str(offline_source_path),
			registry_source_channel=DEFAULT_CHANNEL,
			registry_source_registry_url="",
			registry_source_mirrors=[],
			offline_bundle_path=str(offline_bundle_path),
		)
		if not package_build.get("ok"):
			return make_failure(version, output_dir, list(package_build.get("issues", [])))

		release_registry_path = candidate / f"gf-registry-{version}.json"
		release_source_path = candidate / "gf-registry-source.json"
		metadata_issues = write_release_registry_metadata(
			offline_registry_path,
			release_registry_path,
			release_source_path,
			package_build,
			archive_base_url,
			registry_url,
		)
		if metadata_issues:
			return make_failure(version, output_dir, metadata_issues)

		package_dir = candidate / "packages"
		os.replace(offline_package_dir, package_dir)
		shutil.rmtree(offline_root)
		artifacts = collect_release_artifacts(candidate, version, package_build)
		manifest_path = candidate / f"gf-release-artifacts-{version}.json"
		manifest = {
			"schema_version": MANIFEST_SCHEMA_VERSION,
			"version": version,
			"source_revision": git_head(),
			"archive_base_url": archive_base_url,
			"registry_url": registry_url,
			"package_archive_build_count": 1,
			"artifact_count": len(artifacts),
			"artifacts": artifacts,
		}
		write_json(manifest_path, manifest)
		candidate_audit = audit_release_artifact_manifest(manifest_path, version, git_head())
		if not candidate_audit.get("ok"):
			return make_failure(version, output_dir, list(candidate_audit.get("issues", [])))
		publish_candidate(candidate, output_dir)
		published_manifest = output_dir / manifest_path.name
		return audit_release_artifact_manifest(published_manifest, version, git_head())
	except (OSError, ValueError, json.JSONDecodeError) as exc:
		return make_failure(version, output_dir, [f"Release artifact build failed: {exc}"])
	finally:
		if candidate.exists():
			shutil.rmtree(candidate, ignore_errors=True)


def write_release_registry_metadata(
	offline_registry_path: Path,
	release_registry_path: Path,
	release_source_path: Path,
	package_build: dict[str, Any],
	archive_base_url: str,
	registry_url: str,
) -> list[str]:
	registry = json.loads(offline_registry_path.read_text(encoding="utf-8"))
	packages = registry.get("packages", {})
	if not isinstance(packages, dict):
		return ["Offline registry packages must be an object before release metadata derivation."]
	package_results = package_build.get("packages", [])
	archive_names = {
		str(package.get("id", "")): Path(str(package.get("archive", ""))).name
		for package in package_results
		if str(package.get("kind", "")) != "preset"
	}
	for package_id, archive_name in archive_names.items():
		entry = packages.get(package_id)
		if not isinstance(entry, dict) or not archive_name:
			return [f"Release registry package archive metadata is missing: {package_id}"]
		entry["archive"] = f"{archive_base_url.rstrip('/')}/{archive_name}"
	write_json(release_registry_path, registry)
	registry_issues = build_gf_package.audit_registry(release_registry_path, package_results)
	source_manifest = build_gf_package.make_registry_source_manifest(
		release_registry_path,
		release_source_path,
		DEFAULT_CHANNEL,
		registry_url,
		[],
	)
	write_json(release_source_path, source_manifest)
	source_issues = build_gf_package.audit_registry_source_manifest(
		release_source_path,
		DEFAULT_CHANNEL,
		registry_url,
		sha256_file(release_registry_path),
		release_registry_path.stat().st_size,
	)
	return [*registry_issues, *source_issues]


def collect_release_artifacts(
	candidate: Path,
	version: str,
	package_build: dict[str, Any],
) -> list[dict[str, Any]]:
	roles_by_path = {
		f"gf-framework-{version}.zip": "asset_store",
		f"gf-registry-{version}.json": "registry",
		"gf-registry-source.json": "registry_source",
		f"gf-package-offline-bundle-{version}.zip": "offline_bundle",
	}
	for package in package_build.get("packages", []):
		if str(package.get("kind", "")) == "preset":
			continue
		archive_name = Path(str(package.get("archive", ""))).name
		roles_by_path[f"packages/{archive_name}"] = "package"
	artifacts: list[dict[str, Any]] = []
	for relative_path, role in sorted(roles_by_path.items()):
		path = candidate / relative_path
		artifacts.append({
			"role": role,
			"name": path.name,
			"path": relative_path,
			"size_bytes": path.stat().st_size,
			"sha256": sha256_file(path),
		})
	return artifacts


def audit_release_artifact_manifest(
	manifest_path: Path,
	expected_version: str = "",
	expected_revision: str = "",
) -> dict[str, Any]:
	issues: list[str] = []
	try:
		manifest_path = absolute_lexical_path(manifest_path)
		data = json.loads(manifest_path.read_text(encoding="utf-8"))
	except (OSError, json.JSONDecodeError) as exc:
		return {
			"ok": False,
			"version": expected_version,
			"manifest": manifest_path.as_posix(),
			"artifact_count": 0,
			"issues": [f"Release artifact manifest is unreadable: {exc}"],
		}
	if not isinstance(data, dict):
		return make_failure(expected_version, manifest_path.parent, ["Release artifact manifest root must be an object."])
	version = str(data.get("version", ""))
	if data.get("schema_version") != MANIFEST_SCHEMA_VERSION:
		issues.append(f"Release artifact manifest schema_version must be {MANIFEST_SCHEMA_VERSION}.")
	if expected_version and version != expected_version:
		issues.append(f"Release artifact manifest version is {version!r}, expected {expected_version!r}.")
	source_revision = str(data.get("source_revision", "")).strip()
	if re.fullmatch(r"[0-9a-f]{40}", source_revision) is None:
		issues.append("Release artifact source_revision must be a full lowercase Git commit SHA.")
	if expected_revision and source_revision != expected_revision:
		issues.append("Release artifact source_revision does not match the checked-out revision.")
	if data.get("package_archive_build_count") != 1:
		issues.append("Release package archives must be built exactly once.")
	artifacts = data.get("artifacts", [])
	if not isinstance(artifacts, list):
		artifacts = []
		issues.append("Release artifact manifest artifacts must be an array.")
	if data.get("artifact_count") != len(artifacts):
		issues.append("Release artifact_count does not match the artifact array.")
	seen_paths: set[str] = set()
	roles: list[str] = []
	artifacts_by_role: dict[str, list[tuple[dict[str, Any], Path]]] = {}
	allowed_roles = {"asset_store", "registry", "registry_source", "offline_bundle", "package"}
	for artifact in artifacts:
		if not isinstance(artifact, dict):
			issues.append("Release artifact entries must be objects.")
			continue
		relative_path = str(artifact.get("path", ""))
		role = str(artifact.get("role", ""))
		roles.append(role)
		if role not in allowed_roles:
			issues.append(f"Release artifact role is unsupported: {role!r}.")
		if not relative_path or relative_path in seen_paths:
			issues.append(f"Release artifact path is empty or duplicated: {relative_path!r}.")
			continue
		seen_paths.add(relative_path)
		path = absolute_lexical_path(manifest_path.parent / relative_path)
		if str(artifact.get("name", "")) != path.name:
			issues.append(f"Release artifact name does not match its path: {relative_path}")
		artifacts_by_role.setdefault(role, []).append((artifact, path))
		if not path_is_inside_lexical(manifest_path.parent, path) or path_has_reparse_component(path):
			issues.append(f"Release artifact path escapes or crosses a link: {relative_path}")
			continue
		if not path.is_file():
			issues.append(f"Release artifact is missing: {relative_path}")
			continue
		if artifact.get("size_bytes") != path.stat().st_size:
			issues.append(f"Release artifact size mismatch: {relative_path}")
		if artifact.get("sha256") != sha256_file(path):
			issues.append(f"Release artifact SHA-256 mismatch: {relative_path}")
	for required_role in ("asset_store", "registry", "registry_source", "offline_bundle"):
		if roles.count(required_role) != 1:
			issues.append(f"Release artifact role must occur exactly once: {required_role}")
	if roles.count("package") == 0:
		issues.append("Release artifacts must contain modular package archives.")
	if not issues:
		issues.extend(audit_release_artifact_semantics(
			manifest_path.parent,
			data,
			artifacts_by_role,
			version,
		))
	return {
		"ok": not issues,
		"version": version,
		"manifest": manifest_path.as_posix(),
		"source_revision": source_revision,
		"package_archive_build_count": data.get("package_archive_build_count", 0),
		"artifact_count": len(artifacts),
		"package_archive_count": roles.count("package"),
		"artifacts": artifacts,
		"issues": issues,
	}


def audit_release_artifact_semantics(
	artifact_root: Path,
	manifest: dict[str, Any],
	artifacts_by_role: dict[str, list[tuple[dict[str, Any], Path]]],
	version: str,
) -> list[str]:
	issues: list[str] = []
	expected_paths = {
		"asset_store": f"gf-framework-{version}.zip",
		"registry": f"gf-registry-{version}.json",
		"registry_source": "gf-registry-source.json",
		"offline_bundle": f"gf-package-offline-bundle-{version}.zip",
	}
	role_paths: dict[str, Path] = {}
	for role, expected_path in expected_paths.items():
		entries = artifacts_by_role.get(role, [])
		if len(entries) != 1:
			continue
		record, path = entries[0]
		if str(record.get("path", "")) != expected_path:
			issues.append(f"Release artifact {role} path must be {expected_path}.")
		role_paths[role] = path
	package_pairs = artifacts_by_role.get("package", [])
	for record, _path in package_pairs:
		relative_path = str(record.get("path", ""))
		parts = Path(relative_path).parts
		if len(parts) != 2 or parts[0] != "packages" or not relative_path.endswith(".zip"):
			issues.append(f"Release package artifact must be packages/<archive>.zip: {relative_path}")
	if issues or len(role_paths) != len(expected_paths):
		return issues

	asset_store_path = role_paths["asset_store"]
	asset_audit = build_asset_store_package.audit_package(asset_store_path)
	issues.extend(f"Asset Store artifact: {issue}" for issue in asset_audit.get("issues", []))
	issues.extend(audit_zip_matches_source(
		asset_store_path,
		build_asset_store_package.iter_package_files(),
		"Asset Store artifact",
	))

	registry_path = role_paths["registry"]
	try:
		registry = json.loads(registry_path.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
		return [*issues, f"Release registry is unreadable: {exc}"]
	if not isinstance(registry, dict):
		return [*issues, "Release registry root must be an object."]
	if str(registry.get("framework_version", "")) != version:
		issues.append("Release registry framework_version does not match the artifact version.")
	registry_packages = registry.get("packages", {})
	if not isinstance(registry_packages, dict):
		return [*issues, "Release registry packages must be an object."]

	manifest_load = build_gf_package.load_package_manifests()
	issues.extend(f"Package manifest: {issue}" for issue in manifest_load.get("issues", []))
	package_records = {
		str(record.get("id", "")): record
		for record in manifest_load.get("records", [])
		if str(record.get("id", ""))
	}
	if set(registry_packages) != set(package_records):
		issues.append("Release registry package ids do not match the checked-out package manifests.")

	archive_base_url = str(manifest.get("archive_base_url", "")).rstrip("/")
	registry_url = str(manifest.get("registry_url", ""))
	if not valid_http_url(archive_base_url):
		issues.append("Release artifact archive_base_url must be an absolute HTTP(S) URL.")
	if not valid_http_url(registry_url):
		issues.append("Release artifact registry_url must be an absolute HTTP(S) URL.")
	package_pairs_by_name = {path.name: (record, path) for record, path in package_pairs}
	used_package_names: set[str] = set()
	package_results: list[dict[str, Any]] = []
	for package_id, package_record in sorted(package_records.items()):
		entry = registry_packages.get(package_id)
		if not isinstance(entry, dict):
			continue
		kind = str(package_record.get("kind", ""))
		if kind == "preset":
			package_results.append({"id": package_id, "kind": kind})
			continue
		archive_value = str(entry.get("archive", ""))
		archive_name = Path(urllib.parse.urlparse(archive_value).path).name
		pair = package_pairs_by_name.get(archive_name)
		if pair is None:
			issues.append(f"Release registry archive has no package artifact: {package_id} -> {archive_name}")
			continue
		artifact_record, archive_path = pair
		used_package_names.add(archive_name)
		expected_archive_url = f"{archive_base_url}/{archive_name}"
		if archive_value != expected_archive_url:
			issues.append(f"Release registry archive URL is inconsistent for {package_id}.")
		package_results.append({
			"id": package_id,
			"kind": kind,
			"sha256": str(artifact_record.get("sha256", "")),
			"size_bytes": artifact_record.get("size_bytes", 0),
			"archive": archive_path.as_posix(),
		})
		file_issues: list[str] = []
		expected_files = build_gf_package.collect_package_files(package_record, file_issues)
		issues.extend(f"{package_id}: {issue}" for issue in file_issues)
		archive_audit = build_gf_package.audit_package_archive(package_record, archive_path, expected_files)
		issues.extend(str(issue) for issue in archive_audit.get("issues", []))
		issues.extend(audit_zip_matches_source(archive_path, expected_files, package_id))
	extra_package_names = sorted(set(package_pairs_by_name) - used_package_names)
	if extra_package_names:
		issues.append("Release artifact set contains package ZIPs absent from the registry: " + ", ".join(extra_package_names))
	issues.extend(build_gf_package.audit_registry(registry_path, package_results))

	registry_source_path = role_paths["registry_source"]
	issues.extend(build_gf_package.audit_registry_source_manifest(
		registry_source_path,
		DEFAULT_CHANNEL,
		registry_url,
		sha256_file(registry_path),
		registry_path.stat().st_size,
	))
	issues.extend(audit_offline_release_bundle(
		role_paths["offline_bundle"],
		registry,
		package_pairs_by_name,
	))
	return issues


def audit_zip_matches_source(zip_path: Path, expected_files: list[Path], label: str) -> list[str]:
	issues: list[str] = []
	expected_by_name = {
		path.relative_to(ROOT).as_posix(): path
		for path in expected_files
	}
	try:
		with zipfile.ZipFile(zip_path, "r") as archive:
			names = [name for name in archive.namelist() if name and not name.endswith("/")]
			if len(names) != len(set(names)):
				issues.append(f"{label} contains duplicate ZIP entries.")
			missing = sorted(set(expected_by_name) - set(names))
			extra = sorted(set(names) - set(expected_by_name))
			for name in missing[:20]:
				issues.append(f"{label} is missing source file: {name}")
			for name in extra[:20]:
				issues.append(f"{label} contains undeclared source file: {name}")
			for name in sorted(set(names).intersection(expected_by_name)):
				if archive.read(name) != expected_by_name[name].read_bytes():
					issues.append(f"{label} content differs from source: {name}")
					if len(issues) >= 40:
						break
	except (OSError, RuntimeError, zipfile.BadZipFile) as exc:
		issues.append(f"{label} cannot be compared with source: {exc}")
	return issues


def audit_offline_release_bundle(
	bundle_path: Path,
	online_registry: dict[str, Any],
	package_pairs_by_name: dict[str, tuple[dict[str, Any], Path]],
) -> list[str]:
	issues: list[str] = []
	expected_entries = [
		*[f"packages/{name}" for name in sorted(package_pairs_by_name)],
		"registry/gf-registry-source.json",
		"registry/index.json",
	]
	issues.extend(build_gf_package.audit_offline_bundle(bundle_path, expected_entries))
	try:
		with zipfile.ZipFile(bundle_path, "r") as archive:
			registry_bytes = archive.read("registry/index.json")
			offline_registry = json.loads(registry_bytes.decode("utf-8"))
			offline_source = json.loads(archive.read("registry/gf-registry-source.json").decode("utf-8"))
			for archive_name, (artifact, _path) in package_pairs_by_name.items():
				payload = archive.read(f"packages/{archive_name}")
				if len(payload) != artifact.get("size_bytes"):
					issues.append(f"Offline bundle package size differs from release artifact: {archive_name}")
				if hashlib.sha256(payload).hexdigest() != artifact.get("sha256"):
					issues.append(f"Offline bundle package bytes differ from release artifact: {archive_name}")
	except (KeyError, OSError, UnicodeDecodeError, json.JSONDecodeError, zipfile.BadZipFile) as exc:
		return [*issues, f"Offline release bundle metadata is unreadable: {exc}"]
	if not isinstance(offline_registry, dict) or not isinstance(offline_source, dict):
		return [*issues, "Offline release bundle metadata roots must be objects."]
	online_packages = online_registry.get("packages", {})
	offline_packages = offline_registry.get("packages", {})
	if not isinstance(online_packages, dict) or not isinstance(offline_packages, dict):
		return [*issues, "Online and offline registry packages must be objects."]
	if set(online_packages) != set(offline_packages):
		issues.append("Offline registry package ids differ from the release registry.")
	for package_id, online_entry in online_packages.items():
		offline_entry = offline_packages.get(package_id)
		if not isinstance(online_entry, dict) or not isinstance(offline_entry, dict):
			issues.append(f"Offline registry package entry is invalid: {package_id}")
			continue
		online_comparable = dict(online_entry)
		offline_comparable = dict(offline_entry)
		online_archive = Path(urllib.parse.urlparse(str(online_comparable.get("archive", ""))).path).name
		offline_archive = Path(str(offline_comparable.get("archive", ""))).name
		online_comparable["archive"] = online_archive
		offline_comparable["archive"] = offline_archive
		if online_comparable != offline_comparable:
			issues.append(f"Offline registry metadata differs from release registry: {package_id}")
		if online_archive and str(offline_entry.get("archive", "")) != f"../packages/{online_archive}":
			issues.append(f"Offline registry archive path is invalid: {package_id}")
	channels = offline_source.get("channels", {})
	channel = channels.get(DEFAULT_CHANNEL, {}) if isinstance(channels, dict) else {}
	if offline_source.get("schema_version") != build_gf_package.REGISTRY_SOURCE_SCHEMA_VERSION:
		issues.append("Offline registry source schema_version is invalid.")
	if offline_source.get("default_channel") != DEFAULT_CHANNEL or not isinstance(channel, dict):
		issues.append("Offline registry source stable channel is missing.")
	else:
		if channel.get("registry") != "index.json":
			issues.append("Offline registry source must reference index.json locally.")
		if channel.get("registry_sha256") != hashlib.sha256(registry_bytes).hexdigest():
			issues.append("Offline registry source hash does not match its embedded registry.")
		if channel.get("registry_size_bytes") != len(registry_bytes):
			issues.append("Offline registry source size does not match its embedded registry.")
		if channel.get("mirrors") != []:
			issues.append("Offline registry source must not contain remote mirrors.")
	return issues


def valid_http_url(value: str) -> bool:
	parsed = urllib.parse.urlparse(value)
	return parsed.scheme in {"http", "https"} and bool(parsed.netloc) and not parsed.fragment


def resolve_output_dir(value: str, version: str) -> Path:
	path = Path(value) if value.strip() else Path("build") / f"release-{version}"
	if not path.is_absolute():
		path = ROOT / path
	return absolute_lexical_path(path)


def resolve_manifest_path(value: str, output_dir: Path, version: str) -> Path:
	path = Path(value) if value.strip() else output_dir / f"gf-release-artifacts-{version}.json"
	if not path.is_absolute():
		path = ROOT / path
	return absolute_lexical_path(path)


def validate_output_dir(output_dir: Path) -> None:
	resolved_build_root = absolute_lexical_path(BUILD_ROOT)
	if output_dir == resolved_build_root or not path_is_inside_lexical(resolved_build_root, output_dir):
		raise ValueError("Release output directory must be a child of build/.")
	if path_has_reparse_component(output_dir):
		raise ValueError("Release output directory crosses a filesystem link.")


def publish_candidate(candidate: Path, output_dir: Path) -> None:
	backup = output_dir.parent / f".{output_dir.name}.gf-release-backup-{secrets.token_hex(8)}"
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
	"""Retry transient Windows sharing violations without weakening atomic publication."""
	for attempt in range(attempts):
		try:
			os.replace(source, target)
			return
		except PermissionError:
			if os.name != "nt" or attempt + 1 >= attempts or not source.exists() or target.exists():
				raise
			time.sleep(0.05 * (2 ** attempt))


def write_json(path: Path, data: dict[str, Any]) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sha256_file(path: Path) -> str:
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for chunk in iter(lambda: handle.read(1024 * 1024), b""):
			digest.update(chunk)
	return digest.hexdigest()


def git_head() -> str:
	completed = subprocess.run(
		["git", "rev-parse", "HEAD"],
		cwd=ROOT,
		capture_output=True,
		text=True,
		encoding="utf-8",
		check=False,
		timeout=30,
	)
	return completed.stdout.strip() if completed.returncode == 0 else ""


def make_failure(version: str, output_dir: Path, issues: list[str]) -> dict[str, Any]:
	return {
		"ok": False,
		"version": version,
		"output_dir": output_dir.as_posix(),
		"artifact_count": 0,
		"issues": issues,
	}


def print_result(result: dict[str, Any], as_json: bool) -> None:
	if as_json:
		print(json.dumps(result, ensure_ascii=False, indent=2))
		return
	print(
		f"ok={result.get('ok', False)} version={result.get('version', '')} "
		f"artifacts={result.get('artifact_count', 0)} packages={result.get('package_archive_count', 0)}"
	)
	if result.get("manifest"):
		print(f"manifest={result['manifest']}")
	for issue in result.get("issues", []):
		print(f"- {issue}")


if __name__ == "__main__":
	raise SystemExit(main())
