#!/usr/bin/env python3
"""Build modular GF package archives and a local registry index."""

from __future__ import annotations

import argparse
import configparser
import hashlib
import json
import os
import secrets
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import gf_path_security
from gf_package_paths import normalize_manifest_path as normalize_shared_manifest_path
from gf_package_paths import path_matches_any_manifest_path as shared_path_matches_any_manifest_path


ROOT = Path(__file__).resolve().parents[1]
PACKAGE_ROOT = ROOT / "packages"
ZIP_TIMESTAMP = (1980, 1, 1, 0, 0, 0)
BLOCKED_DIR_NAMES = {".git", ".godot", ".import", ".vs", "__pycache__", "node_modules"}
BLOCKED_FILE_NAMES = {".DS_Store", "Thumbs.db"}
BLOCKED_SUFFIXES = {".import", ".pyc", ".pyo", ".tmp", ".log"}
PACKAGE_SCHEMA_VERSION = 1
REGISTRY_SCHEMA_VERSION = 2
REGISTRY_SOURCE_SCHEMA_VERSION = 1
DEFAULT_REGISTRY_SOURCE_CHANNEL = "stable"
UNSUPPORTED_REGISTRY_SOURCE_SIGNATURE_FIELDS = {
	"public_key",
	"public_keys",
	"registry_signature",
	"registry_signature_algorithm",
	"registry_signature_sha256",
	"registry_signature_size_bytes",
	"registry_signature_url",
	"registry_signing_key_id",
	"signature",
	"signature_algorithm",
	"signature_public_key",
	"signature_sha256",
	"signature_url",
	"signing_key",
	"signing_key_id",
	"signing_keys",
}
UNSUPPORTED_REGISTRY_PACKAGE_SIGNATURE_FIELDS = UNSUPPORTED_REGISTRY_SOURCE_SIGNATURE_FIELDS
PACKAGE_MANIFEST_ALLOWED_FIELDS = {
	"schema_version",
	"id",
	"kind",
	"version",
	"display_name",
	"description",
	"dependencies",
	"exclude_paths",
	"paths",
	"gf_extension_id",
	"packages",
	"metadata",
}
PACKAGE_MANIFEST_FORBIDDEN_FIELDS = {
	"archive",
	"checksum",
	"download",
	"download_url",
	"download_urls",
	"downloads",
	"install_script",
	"install_url",
	"installer",
	"installer_paths",
	"installers",
	"npm",
	"registry",
	"repository",
	"sha256",
	"size_bytes",
} | UNSUPPORTED_REGISTRY_SOURCE_SIGNATURE_FIELDS


def main() -> int:
	configure_stdio()
	parser = argparse.ArgumentParser(description="Build modular GF package archives and registry indexes.")
	parser.add_argument("--package", action="append", default=[], help="Package id to build. Can be passed multiple times.")
	parser.add_argument("--preset", action="append", default=[], help="Preset package id whose concrete packages should be built.")
	parser.add_argument("--all", action="store_true", help="Build every non-preset package manifest.")
	parser.add_argument("--version", default="", help="Override package versions in archive names and registry entries.")
	parser.add_argument("--output-dir", default="build/packages", help="Directory for package zip archives.")
	parser.add_argument("--registry", default="build/registry/index.json", help="Registry JSON output path.")
	parser.add_argument("--archive-base-url", default="", help="Optional base URL or prefix for registry archive fields.")
	parser.add_argument("--registry-source", default="", help="Optional registry source manifest output path.")
	parser.add_argument("--registry-source-channel", default=DEFAULT_REGISTRY_SOURCE_CHANNEL, help="Channel name for --registry-source.")
	parser.add_argument(
		"--registry-source-registry-url",
		default="",
		help="Registry URL written into --registry-source. Defaults to a relative path to --registry.",
	)
	parser.add_argument(
		"--registry-source-mirror",
		action="append",
		default=[],
		help="Additional mirror registry URL for --registry-source. Can be passed multiple times.",
	)
	parser.add_argument(
		"--offline-bundle",
		default="",
		help="Optional zip containing the generated registry/source manifest and package archives for offline install.",
	)
	parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")
	args = parser.parse_args()

	result = build_gf_packages(
		package_ids=args.package,
		preset_ids=args.preset,
		build_all=args.all,
		version_override=args.version,
		output_dir=args.output_dir,
		registry_path=args.registry,
		archive_base_url=args.archive_base_url,
		registry_source_path=args.registry_source,
		registry_source_channel=args.registry_source_channel,
		registry_source_registry_url=args.registry_source_registry_url,
		registry_source_mirrors=args.registry_source_mirror,
		offline_bundle_path=args.offline_bundle,
	)
	print_result(result, args.json)
	return 0 if result["ok"] else 1


def configure_stdio() -> None:
	for stream in (sys.stdin, sys.stdout, sys.stderr):
		if hasattr(stream, "reconfigure"):
			stream.reconfigure(encoding="utf-8", errors="replace")


def build_gf_packages(
	package_ids: list[str],
	preset_ids: list[str],
	build_all: bool,
	version_override: str,
	output_dir: str,
	registry_path: str,
	archive_base_url: str,
	registry_source_path: str = "",
	registry_source_channel: str = DEFAULT_REGISTRY_SOURCE_CHANNEL,
	registry_source_registry_url: str = "",
	registry_source_mirrors: list[str] | None = None,
	offline_bundle_path: str = "",
) -> dict[str, Any]:
	manifests = load_package_manifests()
	issues: list[str] = []
	if manifests["issues"]:
		return make_result(False, output_dir, registry_path, [], manifests["issues"])

	records_by_id = {record["id"]: record for record in manifests["records"] if record["id"]}
	selection = resolve_selected_package_ids(records_by_id, package_ids, preset_ids, build_all, issues)
	selected_ids = selection["packages"]
	selected_preset_ids = selection["presets"]
	selected_ids = expand_selected_dependency_closure(records_by_id, selected_ids, issues)
	if issues:
		return make_result(False, output_dir, registry_path, [], issues)
	if not selected_ids and not selected_preset_ids:
		return make_result(False, output_dir, registry_path, [], ["No package selected. Pass --all, --package, or --preset."])

	resolved_output_dir = resolve_workspace_path(output_dir)
	resolved_registry_path = resolve_workspace_path(registry_path)
	return build_and_publish_distribution(
		records_by_id,
		selected_ids,
		selected_preset_ids,
		version_override,
		resolved_output_dir,
		resolved_registry_path,
		archive_base_url,
		registry_source_path,
		registry_source_channel,
		registry_source_registry_url,
		registry_source_mirrors or [],
		offline_bundle_path,
	)


def build_and_publish_distribution(
	records_by_id: dict[str, dict[str, Any]],
	selected_ids: list[str],
	selected_preset_ids: list[str],
	version_override: str,
	resolved_output_dir: Path,
	resolved_registry_path: Path,
	archive_base_url: str,
	registry_source_path: str,
	registry_source_channel: str,
	registry_source_registry_url: str,
	registry_source_mirrors: list[str],
	offline_bundle_path: str,
) -> dict[str, Any]:
	transaction_id = f"{os.getpid()}-{secrets.token_hex(12)}"
	staged_outputs: dict[Path, Path] = {}
	package_results: list[dict[str, Any]] = []
	framework_version = version_override.strip() or read_plugin_version()
	framework_compatibility = make_framework_compatibility_fields(framework_version)
	registry_packages: dict[str, Any] = {}
	resolved_registry_source_path = resolve_workspace_path(registry_source_path) if registry_source_path.strip() else None
	resolved_offline_bundle_path = resolve_workspace_path(offline_bundle_path) if offline_bundle_path.strip() else None
	try:
		for package_id in selected_ids:
			record = records_by_id[package_id]
			package_version = version_override.strip() or record["version"]
			archive_name = f"{package_id.replace('.', '-')}-{package_version}.zip"
			archive_path = resolved_output_dir / archive_name
			staged_archive_path = staged_output_path(archive_path, transaction_id)
			staged_outputs[archive_path] = staged_archive_path
			source_issues: list[str] = []
			files = collect_package_files(record, source_issues)
			build_issues = [*source_issues, *validate_package_file_list(record, files)]
			if not build_issues:
				try:
					write_package_archive(staged_archive_path, files)
				except (OSError, zipfile.BadZipFile) as error:
					build_issues.append(f"{package_id}: could not stage package archive: {error}")
			audit_issues = audit_package_archive(record, staged_archive_path, files)["issues"] if not build_issues else []
			all_issues = [*build_issues, *audit_issues]
			archive_sha256 = sha256_file(staged_archive_path) if staged_archive_path.is_file() and not all_issues else ""
			size_bytes = staged_archive_path.stat().st_size if staged_archive_path.is_file() and not all_issues else 0
			archive_field = make_registry_archive_value(archive_path, resolved_registry_path, archive_base_url)
			package_result = {
				"ok": not all_issues,
				"id": package_id,
				"kind": record["kind"],
				"version": package_version,
				"archive": relative_display_path(archive_path),
				"sha256": archive_sha256,
				"size_bytes": size_bytes,
				"file_count": len(files),
				"issues": all_issues,
			}
			package_results.append(package_result)
			registry_packages[package_id] = {
				"version": package_version,
				"kind": record["kind"],
				"display_name": record.get("display_name", ""),
				"description": record.get("description", ""),
				**framework_compatibility,
				"dependencies": record["dependencies"],
				"paths": record["paths"],
				"archive": archive_field,
				"sha256": archive_sha256,
				"size_bytes": size_bytes,
			}
			if record.get("gf_extension_id"):
				registry_packages[package_id]["gf_extension_id"] = record["gf_extension_id"]

		for preset_id in selected_preset_ids:
			record = records_by_id[preset_id]
			package_version = version_override.strip() or record["version"]
			package_results.append({
				"ok": True,
				"id": preset_id,
				"kind": record["kind"],
				"version": package_version,
				"archive": "",
				"sha256": "",
				"size_bytes": 0,
				"file_count": 0,
				"issues": [],
			})
			registry_packages[preset_id] = {
				"version": package_version,
				"kind": record["kind"],
				"display_name": record.get("display_name", ""),
				"description": record.get("description", ""),
				**framework_compatibility,
				"dependencies": [],
				"packages": record["packages"],
				"paths": [],
			}

		if not all(item["ok"] for item in package_results):
			return make_result(
				False,
				resolved_output_dir,
				resolved_registry_path,
				package_results,
				["Package build staging failed; existing distribution outputs were preserved."],
				resolved_registry_source_path or "",
				resolved_offline_bundle_path or "",
			)

		registry = {
			"schema_version": REGISTRY_SCHEMA_VERSION,
			"framework_version": framework_version,
			**framework_compatibility,
			"generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
			"packages": registry_packages,
		}
		staged_registry_path = staged_output_path(resolved_registry_path, transaction_id)
		staged_outputs[resolved_registry_path] = staged_registry_path
		write_json_file(staged_registry_path, registry)
		registry_issues = audit_registry(staged_registry_path, package_results)

		registry_source_issues: list[str] = []
		if resolved_registry_source_path is not None:
			staged_registry_source_path = staged_output_path(resolved_registry_source_path, transaction_id)
			staged_outputs[resolved_registry_source_path] = staged_registry_source_path
			source_manifest = make_registry_source_manifest(
				resolved_registry_path,
				resolved_registry_source_path,
				registry_source_channel,
				registry_source_registry_url,
				registry_source_mirrors,
				registry_content_path=staged_registry_path,
			)
			write_json_file(staged_registry_source_path, source_manifest)
			registry_source_issues = audit_registry_source_manifest(
				staged_registry_source_path,
				source_manifest["default_channel"],
				source_manifest["channels"][source_manifest["default_channel"]]["registry"],
				sha256_file(staged_registry_path),
				staged_registry_path.stat().st_size,
			)

		offline_bundle_issues: list[str] = []
		if resolved_offline_bundle_path is not None:
			staged_offline_bundle_path = staged_output_path(resolved_offline_bundle_path, transaction_id)
			staged_outputs[resolved_offline_bundle_path] = staged_offline_bundle_path
			offline_bundle_issues = write_offline_bundle(
				staged_offline_bundle_path,
				resolved_registry_path,
				resolved_registry_source_path,
				package_results,
				staged_outputs,
			)

		issues = [*registry_issues, *registry_source_issues, *offline_bundle_issues]
		if not issues:
			issues.extend(publish_staged_outputs(staged_outputs, transaction_id))
		return make_result(
			not issues,
			resolved_output_dir,
			resolved_registry_path,
			package_results,
			issues,
			resolved_registry_source_path or "",
			resolved_offline_bundle_path or "",
		)
	except (OSError, ValueError, zipfile.BadZipFile) as error:
		return make_result(
			False,
			resolved_output_dir,
			resolved_registry_path,
			package_results,
			[f"Distribution staging failed; existing outputs were preserved: {error}"],
			resolved_registry_source_path or "",
			resolved_offline_bundle_path or "",
		)
	finally:
		for staged_path in staged_outputs.values():
			try_unlink(staged_path)


def make_result(
	ok: bool,
	output_dir: str | Path,
	registry_path: str | Path,
	packages: list[dict[str, Any]],
	issues: list[str],
	registry_source_path: str | Path = "",
	offline_bundle_path: str | Path = "",
) -> dict[str, Any]:
	result = {
		"ok": ok,
		"output_dir": relative_display_path(resolve_workspace_path(str(output_dir))),
		"registry": relative_display_path(resolve_workspace_path(str(registry_path))),
		"package_count": len(packages),
		"packages": packages,
		"issues": issues,
	}
	if str(registry_source_path).strip():
		result["registry_source"] = relative_display_path(resolve_workspace_path(str(registry_source_path)))
	if str(offline_bundle_path).strip():
		result["offline_bundle"] = relative_display_path(resolve_workspace_path(str(offline_bundle_path)))
	return result


def make_framework_compatibility_fields(framework_version: str) -> dict[str, str]:
	return {
		"minimum_framework_version": framework_version,
		"maximum_framework_version_exclusive": next_major_version(framework_version),
	}


def next_major_version(version: str) -> str:
	parts = parse_semver(version)
	if parts is None:
		return ""
	return f"{parts[0] + 1}.0.0"


def parse_semver(version: str) -> tuple[int, int, int] | None:
	text = version.strip()
	if text.startswith("v"):
		text = text[1:]
	pieces = text.split(".")
	if len(pieces) != 3:
		return None
	result: list[int] = []
	for piece in pieces:
		if not piece.isdigit():
			return None
		result.append(int(piece))
	return (result[0], result[1], result[2])


def load_package_manifests() -> dict[str, Any]:
	records: list[dict[str, Any]] = []
	issues: list[str] = []
	for path in sorted(PACKAGE_ROOT.rglob("*.json")):
		if gf_path_security.path_has_reparse_component(path):
			issues.append(f"{relative_display_path(path)}: package manifest crosses a symlink, junction, or reparse point.")
			continue
		try:
			data = json.loads(path.read_text(encoding="utf-8"))
		except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
			issues.append(f"{path.relative_to(ROOT).as_posix()}: invalid package manifest JSON: {error}")
			continue
		if not isinstance(data, dict):
			issues.append(f"{path.relative_to(ROOT).as_posix()}: package manifest root must be an object.")
			continue
		relative_path = path.relative_to(ROOT).as_posix()
		for field_name in sorted(data):
			if field_name in PACKAGE_MANIFEST_FORBIDDEN_FIELDS:
				issues.append(f"{relative_path}: forbidden package manifest field: {field_name}.")
			elif field_name not in PACKAGE_MANIFEST_ALLOWED_FIELDS:
				issues.append(f"{relative_path}: unsupported package manifest field: {field_name}.")
		record = {
			"path": relative_path,
			"id": string_value(data.get("id", "")),
			"kind": string_value(data.get("kind", "")),
			"version": string_value(data.get("version", "unreleased")) or "unreleased",
			"display_name": string_value(data.get("display_name", "")),
			"description": string_value(data.get("description", "")),
			"gf_extension_id": string_value(data.get("gf_extension_id", "")),
			"dependencies": string_array(data.get("dependencies", [])),
			"packages": string_array(data.get("packages", [])),
			"paths": string_array(data.get("paths", [])),
			"exclude_paths": string_array(data.get("exclude_paths", [])),
		}
		schema_version = data.get("schema_version")
		if type(schema_version) is not int or schema_version != PACKAGE_SCHEMA_VERSION:
			issues.append(f"{record['path']}: schema_version must be the integer {PACKAGE_SCHEMA_VERSION}.")
		if not record["id"]:
			issues.append(f"{record['path']}: package id is required.")
		records.append(record)
	return {"records": records, "issues": issues}


def resolve_selected_package_ids(
	records_by_id: dict[str, dict[str, Any]],
	package_ids: list[str],
	preset_ids: list[str],
	build_all: bool,
	issues: list[str],
) -> dict[str, list[str]]:
	selected: list[str] = []
	selected_presets: list[str] = []
	if build_all:
		for package_id, record in sorted(records_by_id.items()):
			if record["kind"] == "preset":
				append_unique(selected_presets, package_id)
			else:
				append_unique(selected, package_id)
	for package_id in package_ids:
		if package_id not in records_by_id:
			issues.append(f"Unknown package id: {package_id}")
			continue
		if records_by_id[package_id]["kind"] == "preset":
			issues.append(f"Use --preset for preset package id: {package_id}")
			continue
		append_unique(selected, package_id)
	for preset_id in preset_ids:
		record = records_by_id.get(preset_id)
		if record is None:
			issues.append(f"Unknown preset id: {preset_id}")
			continue
		if record["kind"] != "preset":
			issues.append(f"--preset expects a preset manifest, got {preset_id}.")
			continue
		append_unique(selected_presets, preset_id)
		for package_id in record["packages"]:
			if package_id not in records_by_id:
				issues.append(f"{preset_id} includes missing package id: {package_id}")
				continue
			if records_by_id[package_id]["kind"] == "preset":
				issues.append(f"{preset_id} includes nested preset: {package_id}")
				continue
			append_unique(selected, package_id)
	return {"packages": selected, "presets": selected_presets}


def expand_selected_dependency_closure(
	records_by_id: dict[str, dict[str, Any]],
	roots: list[str],
	issues: list[str],
) -> list[str]:
	order: list[str] = []
	visiting: list[str] = []
	visited: set[str] = set()

	def visit(package_id: str) -> None:
		if package_id in visited:
			return
		if package_id in visiting:
			cycle = [*visiting[visiting.index(package_id):], package_id]
			issues.append("Package dependency cycle: " + " -> ".join(cycle))
			return
		record = records_by_id.get(package_id)
		if record is None:
			issues.append(f"Missing dependency package id: {package_id}")
			return
		if record["kind"] == "preset":
			issues.append(f"Preset package cannot be part of a package dependency closure: {package_id}")
			return
		visiting.append(package_id)
		for dependency_id in record["dependencies"]:
			visit(dependency_id)
		visiting.pop()
		visited.add(package_id)
		append_unique(order, package_id)

	for root in roots:
		visit(root)
	return order


def collect_package_files(record: dict[str, Any], issues: list[str] | None = None) -> list[Path]:
	result_issues = issues if issues is not None else []
	files: list[Path] = []
	seen_identities: dict[str, Path] = {}
	exclude_patterns = record.get("exclude_paths", [])
	for raw_pattern in record["paths"]:
		pattern = normalize_manifest_path(raw_pattern)
		if not pattern:
			continue
		for path in expand_manifest_path(pattern):
			if gf_path_security.path_has_reparse_component(path):
				result_issues.append(
					f"{record['id']}: package source crosses a symlink, junction, or reparse point: "
					f"{relative_display_path(path)}"
				)
				continue
			if not path.is_file():
				continue
			try:
				resolved_path = path.resolve(strict=True)
				resolved_path.relative_to(ROOT.resolve(strict=True))
			except (OSError, ValueError):
				result_issues.append(f"{record['id']}: package source leaves the repository root: {path.as_posix()}")
				continue
			if is_blocked_path(path):
				continue
			relative_path = path.relative_to(ROOT).as_posix()
			if not is_windows_portable_relative_path(relative_path):
				result_issues.append(
					f"{record['id']}: package source is not portable to Windows path rules: {relative_path}"
				)
				continue
			if path_matches_any_manifest_path(relative_path, exclude_patterns):
				continue
			identity = portable_path_identity(relative_path)
			previous = seen_identities.get(identity)
			if previous is not None and previous != path:
				result_issues.append(
					f"{record['id']}: package sources collide under Windows path rules: "
					f"{previous.relative_to(ROOT).as_posix()} and {relative_path}"
				)
				continue
			seen_identities[identity] = path
			if path not in files:
				files.append(path)
	return sorted(files, key=lambda item: item.relative_to(ROOT).as_posix())


def expand_manifest_path(pattern: str) -> list[Path]:
	if pattern.endswith("/**"):
		directory_pattern = pattern[:-3].rstrip("/")
		if not has_glob(directory_pattern):
			directory = ROOT / directory_pattern
			if directory.is_dir():
				return [directory, *sorted(directory.rglob("*"))]
	if has_glob(pattern):
		return sorted(ROOT.glob(pattern))
	path = ROOT / pattern
	return [path] if path.exists() else []


def validate_package_file_list(record: dict[str, Any], files: list[Path]) -> list[str]:
	issues: list[str] = []
	if record["kind"] == "preset":
		return issues
	if not record["paths"]:
		issues.append(f"{record['id']}: package manifest declares no owned paths.")
	if not files:
		issues.append(f"{record['id']}: package archive would contain no files.")
	for path in files:
		relative_path = path.relative_to(ROOT).as_posix()
		if not relative_path.startswith("addons/gf/"):
			issues.append(f"{record['id']}: package file is outside addons/gf: {relative_path}")
		if not path_matches_any_manifest_path(relative_path, record["paths"]):
			issues.append(f"{record['id']}: package file is not covered by manifest paths: {relative_path}")
	return issues


def write_package_archive(output: Path, files: list[Path]) -> None:
	prepare_new_staged_output(output)
	with zipfile.ZipFile(output, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
		for path in files:
			write_file(archive, path)
	flush_and_sync_file(output)


def write_file(archive: zipfile.ZipFile, path: Path) -> None:
	if gf_path_security.path_has_reparse_component(path):
		raise OSError(f"Package source became a symlink, junction, or reparse point: {path.as_posix()}")
	archive_path = path.relative_to(ROOT).as_posix()
	info = zipfile.ZipInfo(archive_path, ZIP_TIMESTAMP)
	info.compress_type = zipfile.ZIP_DEFLATED
	info.external_attr = 0o644 << 16
	archive.writestr(info, path.read_bytes())


def audit_package_archive(record: dict[str, Any], archive_path: Path, expected_files: list[Path]) -> dict[str, Any]:
	issues: list[str] = []
	if not archive_path.is_file():
		return {"issues": [f"{record['id']}: archive was not created: {archive_path.as_posix()}"]}
	try:
		with zipfile.ZipFile(archive_path, "r") as archive:
			names = sorted(name for name in archive.namelist() if name and not name.endswith("/"))
	except zipfile.BadZipFile as error:
		return {"issues": [f"{record['id']}: invalid zip archive: {error}"]}
	top_level_entries = sorted({name.split("/", 1)[0] for name in names})
	if top_level_entries != ["addons"]:
		issues.append(f"{record['id']}: archive root must contain only addons/.")
	expected_names = sorted(path.relative_to(ROOT).as_posix() for path in expected_files)
	missing = sorted(set(expected_names) - set(names))
	extra = sorted(set(names) - set(expected_names))
	for name in missing[:20]:
		issues.append(f"{record['id']}: archive is missing declared file: {name}")
	for name in extra[:20]:
		issues.append(f"{record['id']}: archive contains undeclared file: {name}")
	for name in names:
		if not name.startswith("addons/gf/"):
			issues.append(f"{record['id']}: archive entry is outside addons/gf: {name}")
		parts = name.split("/")
		if any(part in BLOCKED_DIR_NAMES for part in parts):
			issues.append(f"{record['id']}: archive entry contains blocked directory: {name}")
		if Path(name).name in BLOCKED_FILE_NAMES or Path(name).suffix in BLOCKED_SUFFIXES:
			issues.append(f"{record['id']}: archive entry contains blocked generated file: {name}")
	return {"issues": issues}


def audit_registry(registry_path: Path, package_results: list[dict[str, Any]]) -> list[str]:
	issues: list[str] = []
	try:
		data = json.loads(registry_path.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
		return [f"Registry is not readable JSON: {error}"]
	if not isinstance(data, dict):
		return ["Registry root must be an object."]
	if data.get("schema_version") != REGISTRY_SCHEMA_VERSION:
		issues.append(f"Registry schema_version must be {REGISTRY_SCHEMA_VERSION}.")
	framework_version = string_value(data.get("framework_version", ""))
	if not framework_version:
		issues.append("Registry framework_version must not be empty.")
	for field_name in ["minimum_framework_version", "maximum_framework_version_exclusive"]:
		if field_name not in data:
			issues.append(f"Registry {field_name} field is required.")
	if string_value(data.get("minimum_framework_version", "")) != framework_version:
		issues.append("Registry minimum_framework_version must match framework_version.")
	expected_maximum = next_major_version(framework_version)
	if expected_maximum and string_value(data.get("maximum_framework_version_exclusive", "")) != expected_maximum:
		issues.append("Registry maximum_framework_version_exclusive must be the next major SemVer boundary.")
	packages = data.get("packages")
	if not isinstance(packages, dict):
		return [*issues, "Registry packages must be an object."]
	for package_result in package_results:
		package_id = package_result["id"]
		entry = packages.get(package_id)
		if not isinstance(entry, dict):
			issues.append(f"Registry is missing package entry: {package_id}")
			continue
		for field_name in sorted(UNSUPPORTED_REGISTRY_PACKAGE_SIGNATURE_FIELDS.intersection(entry)):
			issues.append(
				"Registry package signature field is not supported until native verification is implemented: "
				f"{package_id}.{field_name}"
			)
		for field_name in ["minimum_framework_version", "maximum_framework_version_exclusive"]:
			if field_name not in entry:
				issues.append(f"Registry package {package_id} is missing {field_name}.")
		if string_value(entry.get("minimum_framework_version", "")) != string_value(data.get("minimum_framework_version", "")):
			issues.append(f"Registry package {package_id} minimum_framework_version must match registry root.")
		if string_value(entry.get("maximum_framework_version_exclusive", "")) != string_value(data.get("maximum_framework_version_exclusive", "")):
			issues.append(f"Registry package {package_id} maximum_framework_version_exclusive must match registry root.")
		if package_result.get("kind") == "preset":
			if entry.get("archive"):
				issues.append(f"Preset registry archive field must be empty for {package_id}.")
			if entry.get("sha256"):
				issues.append(f"Preset registry sha256 field must be empty for {package_id}.")
			if entry.get("size_bytes", 0):
				issues.append(f"Preset registry size_bytes must be empty or zero for {package_id}.")
			if entry.get("paths"):
				issues.append(f"Preset registry paths must be empty for {package_id}.")
			if not string_array(entry.get("packages", [])):
				issues.append(f"Preset registry packages field is empty for {package_id}.")
			continue
		if entry.get("sha256") != package_result["sha256"]:
			issues.append(f"Registry sha256 does not match archive for {package_id}.")
		if entry.get("size_bytes") != package_result["size_bytes"]:
			issues.append(f"Registry size_bytes does not match archive for {package_id}.")
		if not entry.get("archive"):
			issues.append(f"Registry archive field is empty for {package_id}.")
	return issues


def make_registry_source_manifest(
	registry_path: Path,
	registry_source_path: Path,
	channel: str,
	registry_url: str,
	mirrors: list[str],
	*,
	registry_content_path: Path | None = None,
) -> dict[str, Any]:
	channel_name = channel.strip() or DEFAULT_REGISTRY_SOURCE_CHANNEL
	registry_reference = registry_url.strip() or relative_path_between(registry_path, registry_source_path.parent)
	content_path = registry_content_path or registry_path
	return {
		"schema_version": REGISTRY_SOURCE_SCHEMA_VERSION,
		"default_channel": channel_name,
		"channels": {
			channel_name: {
				"registry": registry_reference,
				"registry_sha256": sha256_file(content_path),
				"registry_size_bytes": content_path.stat().st_size,
				"mirrors": [mirror.strip() for mirror in mirrors if mirror.strip()],
			},
		},
	}


def audit_registry_source_manifest(
	path: Path,
	expected_channel: str,
	expected_registry: str,
	expected_registry_sha256: str,
	expected_registry_size_bytes: int,
) -> list[str]:
	issues: list[str] = []
	try:
		data = json.loads(path.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
		return [f"Registry source manifest is not readable JSON: {error}"]
	if not isinstance(data, dict):
		return ["Registry source manifest root must be an object."]
	issues.extend(registry_source_signature_issues(data))
	if data.get("schema_version") != REGISTRY_SOURCE_SCHEMA_VERSION:
		issues.append(f"Registry source manifest schema_version must be {REGISTRY_SOURCE_SCHEMA_VERSION}.")
	if data.get("default_channel") != expected_channel:
		issues.append(f"Registry source manifest default_channel must be {expected_channel}.")
	channels = data.get("channels", {})
	if not isinstance(channels, dict) or not channels:
		return [*issues, "Registry source manifest channels must be a non-empty object."]
	channel_entry = channels.get(expected_channel)
	if not isinstance(channel_entry, dict):
		return [*issues, f"Registry source manifest channel is missing: {expected_channel}."]
	if channel_entry.get("registry") != expected_registry:
		issues.append(f"Registry source manifest registry must be {expected_registry}.")
	if channel_entry.get("registry_sha256") != expected_registry_sha256:
		issues.append("Registry source manifest registry_sha256 must match the generated registry.")
	if channel_entry.get("registry_size_bytes") != expected_registry_size_bytes:
		issues.append("Registry source manifest registry_size_bytes must match the generated registry.")
	mirrors = channel_entry.get("mirrors", [])
	if not isinstance(mirrors, list):
		issues.append(f"Registry source manifest mirrors must be an array: {expected_channel}.")
	elif any(not isinstance(mirror, str) or not mirror.strip() for mirror in mirrors):
		issues.append(f"Registry source manifest mirrors must contain non-empty strings: {expected_channel}.")
	return issues


def registry_source_signature_issues(data: dict[str, Any]) -> list[str]:
	issues: list[str] = []
	for field_name in sorted(UNSUPPORTED_REGISTRY_SOURCE_SIGNATURE_FIELDS.intersection(data)):
		issues.append(
			"Registry source manifest signature field is not supported until native verification is implemented: "
			f"{field_name}"
		)
	channels = data.get("channels", {})
	if not isinstance(channels, dict):
		return issues
	for channel_name, channel_entry in channels.items():
		if not isinstance(channel_entry, dict):
			continue
		for field_name in sorted(UNSUPPORTED_REGISTRY_SOURCE_SIGNATURE_FIELDS.intersection(channel_entry)):
			issues.append(
				"Registry source channel signature field is not supported until native verification is implemented: "
				f"{channel_name}.{field_name}"
			)
	return issues


def write_offline_bundle(
	bundle_path: Path,
	registry_path: Path,
	registry_source_path: Path | None,
	package_results: list[dict[str, Any]],
	staged_paths: dict[Path, Path] | None = None,
) -> list[str]:
	issues: list[str] = []
	content_paths = staged_paths or {}
	files = offline_bundle_files(registry_path, registry_source_path, package_results)
	for path in files:
		content_path = content_paths.get(path, path)
		if not content_path.is_file() or gf_path_security.path_has_reparse_component(content_path):
			issues.append(f"Offline bundle input is missing: {path.as_posix()}")
	if issues:
		return issues
	common_root = offline_bundle_common_root(files)
	entries: list[tuple[str, Path]] = []
	seen_entries: set[str] = set()
	for path in sorted(files, key=lambda item: item.as_posix()):
		entry_name = relative_path_between(path, common_root)
		if not is_safe_bundle_entry(entry_name):
			issues.append(f"Offline bundle entry would be unsafe: {entry_name}")
			continue
		if entry_name in seen_entries:
			issues.append(f"Offline bundle entry is duplicated: {entry_name}")
			continue
		seen_entries.add(entry_name)
		entries.append((entry_name, content_paths.get(path, path)))
	if issues:
		return issues
	prepare_new_staged_output(bundle_path)
	with zipfile.ZipFile(bundle_path, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
		for entry_name, path in entries:
			write_bundle_file(archive, entry_name, path)
	flush_and_sync_file(bundle_path)
	return audit_offline_bundle(bundle_path, [entry_name for entry_name, _path in entries])


def offline_bundle_files(
	registry_path: Path,
	registry_source_path: Path | None,
	package_results: list[dict[str, Any]],
) -> list[Path]:
	files: list[Path] = [registry_path]
	if registry_source_path is not None:
		files.append(registry_source_path)
	for package in package_results:
		if str(package.get("kind", "")) == "preset":
			continue
		archive_path = resolve_workspace_path(str(package.get("archive", "")))
		if archive_path not in files:
			files.append(archive_path)
	return files


def offline_bundle_common_root(files: list[Path]) -> Path:
	return Path(os.path.commonpath([str(gf_path_security.absolute_lexical_path(path)) for path in files]))


def is_safe_bundle_entry(entry_name: str) -> bool:
	if not entry_name or entry_name.startswith("/") or "\\" in entry_name:
		return False
	parts = entry_name.split("/")
	return all(part not in ("", ".", "..") for part in parts)


def write_bundle_file(archive: zipfile.ZipFile, entry_name: str, path: Path) -> None:
	if gf_path_security.path_has_reparse_component(path):
		raise OSError(f"Offline bundle input became a symlink, junction, or reparse point: {path.as_posix()}")
	info = zipfile.ZipInfo(entry_name, ZIP_TIMESTAMP)
	info.compress_type = zipfile.ZIP_DEFLATED
	info.external_attr = 0o644 << 16
	archive.writestr(info, path.read_bytes())


def audit_offline_bundle(bundle_path: Path, expected_entries: list[str]) -> list[str]:
	try:
		with zipfile.ZipFile(bundle_path, "r") as archive:
			names = sorted(name for name in archive.namelist() if name and not name.endswith("/"))
	except zipfile.BadZipFile as error:
		return [f"Offline bundle is not a valid zip archive: {error}"]
	issues: list[str] = []
	if sorted(expected_entries) != names:
		issues.append("Offline bundle entries do not match generated registry/source/package files.")
	for name in names:
		if not is_safe_bundle_entry(name):
			issues.append(f"Offline bundle contains unsafe entry: {name}")
	if not any(name.endswith(".json") for name in names):
		issues.append("Offline bundle must include generated registry JSON.")
	if not any(name.endswith(".zip") for name in names):
		issues.append("Offline bundle must include package archive zip files.")
	return issues


def staged_output_path(final_path: Path, transaction_id: str) -> Path:
	final = gf_path_security.absolute_lexical_path(final_path)
	validate_distribution_output_path(final)
	candidate = final.parent / f".{final.name}.gf-build-{transaction_id}.candidate"
	validate_distribution_output_path(candidate)
	if os.path.lexists(candidate):
		raise OSError(f"Distribution staging path already exists: {candidate.as_posix()}")
	return candidate


def prepare_new_staged_output(path: Path) -> None:
	validate_distribution_output_path(path)
	path.parent.mkdir(parents=True, exist_ok=True)
	validate_distribution_output_path(path)
	if os.path.lexists(path):
		raise OSError(f"Distribution staging path already exists: {path.as_posix()}")


def write_json_file(path: Path, data: dict[str, Any]) -> None:
	prepare_new_staged_output(path)
	with path.open("x", encoding="utf-8", newline="\n") as handle:
		json.dump(data, handle, ensure_ascii=False, indent=2)
		handle.write("\n")
		handle.flush()
		os.fsync(handle.fileno())


def flush_and_sync_file(path: Path) -> None:
    # Windows requires a writable descriptor for FlushFileBuffers/os.fsync.
    with path.open("r+b") as handle:
        os.fsync(handle.fileno())


def publish_staged_outputs(staged_outputs: dict[Path, Path], transaction_id: str) -> list[str]:
	if not staged_outputs:
		return ["Distribution publish has no staged outputs."]
	issues: list[str] = []
	prepared: list[tuple[Path, Path, Path | None]] = []
	seen_targets: dict[str, Path] = {}
	try:
		for raw_final, raw_candidate in staged_outputs.items():
			final_path = gf_path_security.absolute_lexical_path(raw_final)
			candidate_path = gf_path_security.absolute_lexical_path(raw_candidate)
			validate_distribution_output_path(final_path)
			validate_distribution_output_path(candidate_path)
			if final_path.parent != candidate_path.parent:
				raise OSError(f"Staged output must be a sibling of its destination: {candidate_path.as_posix()}")
			if not candidate_path.is_file():
				raise OSError(f"Staged distribution output is missing: {candidate_path.as_posix()}")
			identity = portable_path_identity(final_path.as_posix())
			previous = seen_targets.get(identity)
			if previous is not None:
				raise OSError(
					"Distribution outputs collide under Windows path rules: "
					f"{previous.as_posix()} and {final_path.as_posix()}"
				)
			seen_targets[identity] = final_path
			backup_path: Path | None = None
			if os.path.lexists(final_path):
				if not final_path.is_file():
					raise OSError(f"Distribution destination is not a regular file: {final_path.as_posix()}")
				backup_path = final_path.parent / f".{final_path.name}.gf-build-{transaction_id}.backup"
				validate_distribution_output_path(backup_path)
				if os.path.lexists(backup_path):
					raise OSError(f"Distribution backup path already exists: {backup_path.as_posix()}")
			prepared.append((final_path, candidate_path, backup_path))

		for final_path, _candidate_path, backup_path in prepared:
			if backup_path is not None:
				os.replace(final_path, backup_path)
				sync_directory(final_path.parent)

		published: list[Path] = []
		try:
			for final_path, candidate_path, _backup_path in prepared:
				validate_distribution_output_path(final_path)
				validate_distribution_output_path(candidate_path)
				os.replace(candidate_path, final_path)
				published.append(final_path)
				sync_directory(final_path.parent)
		except OSError as error:
			issues.append(f"Distribution publish failed: {error}")
			issues.extend(rollback_distribution_publish(prepared, published))
			return issues

		for _final_path, _candidate_path, backup_path in prepared:
			if backup_path is None:
				continue
			try:
				backup_path.unlink()
				sync_directory(backup_path.parent)
			except OSError as error:
				issues.append(f"Published distribution backup could not be removed: {backup_path.as_posix()}: {error}")
		return issues
	except OSError as error:
		issues.append(f"Distribution publish preparation failed: {error}")
		issues.extend(rollback_distribution_publish(prepared, []))
		return issues


def rollback_distribution_publish(
	prepared: list[tuple[Path, Path, Path | None]],
	published: list[Path],
) -> list[str]:
	issues: list[str] = []
	published_set = set(published)
	for final_path in reversed(published):
		try:
			if gf_path_security.path_has_reparse_component(final_path):
				raise OSError("destination became a symlink, junction, or reparse point")
			if final_path.is_file():
				final_path.unlink()
				sync_directory(final_path.parent)
		except OSError as error:
			issues.append(f"Distribution rollback could not remove staged destination {final_path.as_posix()}: {error}")
	for final_path, _candidate_path, backup_path in reversed(prepared):
		if backup_path is None or not os.path.lexists(backup_path):
			continue
		try:
			if gf_path_security.path_has_reparse_component(backup_path):
				raise OSError("backup became a symlink, junction, or reparse point")
			if os.path.lexists(final_path):
				if final_path not in published_set:
					raise OSError("destination was concurrently recreated")
				continue
			os.replace(backup_path, final_path)
			sync_directory(final_path.parent)
		except OSError as error:
			issues.append(f"Distribution rollback could not restore {final_path.as_posix()}: {error}")
	return issues


def validate_distribution_output_path(path: Path) -> None:
	if not path.name or not is_windows_portable_relative_path(path.name):
		raise OSError(f"Distribution output name is not portable to Windows: {path.as_posix()}")
	if gf_path_security.path_has_reparse_component(path):
		raise OSError(f"Distribution output crosses a symlink, junction, or reparse point: {path.as_posix()}")


def try_unlink(path: Path) -> None:
	try:
		if gf_path_security.path_has_reparse_component(path):
			return
		if path.is_file():
			path.unlink()
	except OSError:
		return


def sync_directory(path: Path) -> None:
	if os.name == "nt":
		return
	try:
		fd = os.open(path, os.O_RDONLY)
	except OSError:
		return
	try:
		os.fsync(fd)
	finally:
		os.close(fd)


def read_plugin_version() -> str:
	plugin_config_path = ROOT / "addons/gf/plugin.cfg"
	if gf_path_security.path_has_reparse_component(plugin_config_path):
		raise OSError(f"Plugin config crosses a symlink, junction, or reparse point: {plugin_config_path.as_posix()}")
	config = configparser.ConfigParser()
	config.read(plugin_config_path, encoding="utf-8")
	if not config.has_section("plugin"):
		return ""
	value = config.get("plugin", "version", fallback="").strip()
	if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
		return value[1:-1]
	return value


def resolve_workspace_path(path: str) -> Path:
	resolved = Path(path)
	if not resolved.is_absolute():
		resolved = ROOT / resolved
	return gf_path_security.absolute_lexical_path(resolved)


def make_registry_archive_value(archive_path: Path, registry_path: Path, archive_base_url: str) -> str:
	if archive_base_url.strip():
		return archive_base_url.rstrip("/") + "/" + archive_path.name
	return relative_path_between(archive_path, registry_path.parent)


def relative_path_between(path: Path, parent: Path) -> str:
	return os.path.relpath(path, parent).replace("\\", "/")


def relative_display_path(path: Path) -> str:
	try:
		return path.relative_to(ROOT).as_posix()
	except ValueError:
		return path.as_posix()


def sha256_file(path: Path) -> str:
	if gf_path_security.path_has_reparse_component(path):
		raise OSError(f"Hash input crosses a symlink, junction, or reparse point: {path.as_posix()}")
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for chunk in iter(lambda: handle.read(1024 * 1024), b""):
			digest.update(chunk)
	return digest.hexdigest()


def normalize_manifest_path(path: str) -> str:
	return normalize_shared_manifest_path(path)


def is_windows_portable_relative_path(path: str) -> bool:
	normalized = path.replace("\\", "/")
	if not normalized or normalized.startswith("/"):
		return False
	for part in normalized.split("/"):
		if part in ("", ".", "..") or part != part.rstrip(" ."):
			return False
		if any(ord(character) < 32 for character in part):
			return False
	return True


def portable_path_identity(path: str) -> str:
	return "/".join(part.rstrip(" .").lower() for part in path.replace("\\", "/").split("/"))


def path_matches_any_manifest_path(path: str, patterns: list[str]) -> bool:
	return shared_path_matches_any_manifest_path(path, patterns)


def is_blocked_path(path: Path) -> bool:
	relative_parts = path.relative_to(ROOT).parts
	if any(part in BLOCKED_DIR_NAMES for part in relative_parts):
		return True
	if path.name in BLOCKED_FILE_NAMES:
		return True
	return path.suffix in BLOCKED_SUFFIXES


def has_glob(path: str) -> bool:
	return any(token in path for token in ("*", "?", "["))


def string_value(value: Any) -> str:
	return value.strip() if isinstance(value, str) else ""


def string_array(value: Any) -> list[str]:
	if isinstance(value, str):
		return [value.strip()] if value.strip() else []
	if not isinstance(value, list):
		return []
	return [item.strip() for item in value if isinstance(item, str) and item.strip()]


def append_unique(items: list[str], item: str) -> None:
	if item not in items:
		items.append(item)


def print_result(result: dict[str, Any], as_json: bool) -> None:
	if as_json:
		print(json.dumps(result, ensure_ascii=False, indent=2))
		return
	print(f"ok={result['ok']} packages={result['package_count']} output={result['output_dir']} registry={result['registry']}")
	if result.get("registry_source"):
		print(f"registry_source={result['registry_source']}")
	if result.get("offline_bundle"):
		print(f"offline_bundle={result['offline_bundle']}")
	for package in result["packages"]:
		print(
			f"- {package['id']}: ok={package['ok']} "
			f"files={package['file_count']} size={package['size_bytes']} archive={package['archive']}"
		)
	if result["issues"]:
		print("issues:")
		for issue in result["issues"]:
			print(f"- {issue}")
	for package in result["packages"]:
		for issue in package["issues"]:
			print(f"- {issue}")


if __name__ == "__main__":
	raise SystemExit(main())
