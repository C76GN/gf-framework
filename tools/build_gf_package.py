#!/usr/bin/env python3
"""Build modular GF package archives and a local registry index."""

from __future__ import annotations

import argparse
import configparser
import fnmatch
import hashlib
import json
import os
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


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
	resolved_output_dir.mkdir(parents=True, exist_ok=True)
	resolved_registry_path.parent.mkdir(parents=True, exist_ok=True)

	package_results: list[dict[str, Any]] = []
	framework_version = version_override.strip() or read_plugin_version()
	framework_compatibility = make_framework_compatibility_fields(framework_version)
	registry_packages: dict[str, Any] = {}
	for package_id in selected_ids:
		record = records_by_id[package_id]
		package_version = version_override.strip() or record["version"]
		archive_name = f"{package_id.replace('.', '-')}-{package_version}.zip"
		archive_path = resolved_output_dir / archive_name
		files = collect_package_files(record)
		build_issues = validate_package_file_list(record, files)
		if not build_issues:
			write_package_archive(archive_path, files)
		audit = audit_package_archive(record, archive_path, files)
		all_issues = [*build_issues, *audit["issues"]]
		archive_sha256 = sha256_file(archive_path) if archive_path.is_file() else ""
		size_bytes = archive_path.stat().st_size if archive_path.is_file() else 0
		archive_field = make_registry_archive_value(archive_path, resolved_registry_path, archive_base_url)
		package_result = {
			"ok": len(all_issues) == 0,
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
		if record.get("enable_extension"):
			registry_packages[package_id]["enable_extension"] = record["enable_extension"]

	for preset_id in selected_preset_ids:
		record = records_by_id[preset_id]
		package_version = version_override.strip() or record["version"]
		package_result = {
			"ok": True,
			"id": preset_id,
			"kind": record["kind"],
			"version": package_version,
			"archive": "",
			"sha256": "",
			"size_bytes": 0,
			"file_count": 0,
			"issues": [],
		}
		package_results.append(package_result)
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

	registry = {
		"schema_version": REGISTRY_SCHEMA_VERSION,
		"framework_version": framework_version,
		**framework_compatibility,
		"generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
		"packages": registry_packages,
	}
	resolved_registry_path.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
	registry_issues = audit_registry(resolved_registry_path, package_results)
	registry_source_issues: list[str] = []
	resolved_registry_source_path: Path | None = None
	if registry_source_path.strip():
		resolved_registry_source_path = resolve_workspace_path(registry_source_path)
		resolved_registry_source_path.parent.mkdir(parents=True, exist_ok=True)
		source_manifest = make_registry_source_manifest(
			resolved_registry_path,
			resolved_registry_source_path,
			registry_source_channel,
			registry_source_registry_url,
			registry_source_mirrors or [],
		)
		resolved_registry_source_path.write_text(
			json.dumps(source_manifest, ensure_ascii=False, indent=2) + "\n",
			encoding="utf-8",
		)
		registry_source_issues = audit_registry_source_manifest(
			resolved_registry_source_path,
			source_manifest["default_channel"],
			source_manifest["channels"][source_manifest["default_channel"]]["registry"],
			sha256_file(resolved_registry_path),
			resolved_registry_path.stat().st_size,
		)
	offline_bundle_issues: list[str] = []
	resolved_offline_bundle_path: Path | None = None
	if offline_bundle_path.strip():
		resolved_offline_bundle_path = resolve_workspace_path(offline_bundle_path)
		offline_bundle_issues = write_offline_bundle(
			resolved_offline_bundle_path,
			resolved_registry_path,
			resolved_registry_source_path,
			package_results,
		)
	ok = (
		all(item["ok"] for item in package_results)
		and not registry_issues
		and not registry_source_issues
		and not offline_bundle_issues
	)
	return make_result(
		ok,
		resolved_output_dir.as_posix(),
		resolved_registry_path.as_posix(),
		package_results,
		[*registry_issues, *registry_source_issues, *offline_bundle_issues],
		resolved_registry_source_path.as_posix() if resolved_registry_source_path is not None else "",
		resolved_offline_bundle_path.as_posix() if resolved_offline_bundle_path is not None else "",
	)


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
		try:
			data = json.loads(path.read_text(encoding="utf-8"))
		except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
			issues.append(f"{path.relative_to(ROOT).as_posix()}: invalid package manifest JSON: {error}")
			continue
		if not isinstance(data, dict):
			issues.append(f"{path.relative_to(ROOT).as_posix()}: package manifest root must be an object.")
			continue
		record = {
			"path": path.relative_to(ROOT).as_posix(),
			"id": string_value(data.get("id", "")),
			"kind": string_value(data.get("kind", "")),
			"version": string_value(data.get("version", "unreleased")) or "unreleased",
			"display_name": string_value(data.get("display_name", "")),
			"description": string_value(data.get("description", "")),
			"enable_extension": string_value(data.get("enable_extension", "")),
			"dependencies": string_array(data.get("dependencies", [])),
			"packages": string_array(data.get("packages", [])),
			"paths": string_array(data.get("paths", [])),
			"exclude_paths": string_array(data.get("exclude_paths", [])),
		}
		if data.get("schema_version") != PACKAGE_SCHEMA_VERSION:
			issues.append(f"{record['path']}: schema_version must be {PACKAGE_SCHEMA_VERSION}.")
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


def collect_package_files(record: dict[str, Any]) -> list[Path]:
	files: list[Path] = []
	exclude_patterns = record.get("exclude_paths", [])
	for raw_pattern in record["paths"]:
		pattern = normalize_manifest_path(raw_pattern)
		if not pattern:
			continue
		for path in expand_manifest_path(pattern):
			if not path.is_file():
				continue
			if is_blocked_path(path):
				continue
			relative_path = path.relative_to(ROOT).as_posix()
			if path_matches_any_manifest_path(relative_path, exclude_patterns):
				continue
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
	output.parent.mkdir(parents=True, exist_ok=True)
	if output.exists():
		output.unlink()
	with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
		for path in files:
			write_file(archive, path)


def write_file(archive: zipfile.ZipFile, path: Path) -> None:
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
) -> dict[str, Any]:
	channel_name = channel.strip() or DEFAULT_REGISTRY_SOURCE_CHANNEL
	registry_reference = registry_url.strip() or relative_path_between(registry_path, registry_source_path.parent)
	return {
		"schema_version": REGISTRY_SOURCE_SCHEMA_VERSION,
		"default_channel": channel_name,
		"channels": {
			channel_name: {
				"registry": registry_reference,
				"registry_sha256": sha256_file(registry_path),
				"registry_size_bytes": registry_path.stat().st_size,
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
) -> list[str]:
	issues: list[str] = []
	files = offline_bundle_files(registry_path, registry_source_path, package_results)
	for path in files:
		if not path.is_file():
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
		entries.append((entry_name, path))
	if issues:
		return issues
	bundle_path.parent.mkdir(parents=True, exist_ok=True)
	if bundle_path.exists():
		bundle_path.unlink()
	with zipfile.ZipFile(bundle_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
		for entry_name, path in entries:
			write_bundle_file(archive, entry_name, path)
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
	return Path(os.path.commonpath([str(path.resolve()) for path in files]))


def is_safe_bundle_entry(entry_name: str) -> bool:
	if not entry_name or entry_name.startswith("/") or "\\" in entry_name:
		return False
	parts = entry_name.split("/")
	return all(part not in ("", ".", "..") for part in parts)


def write_bundle_file(archive: zipfile.ZipFile, entry_name: str, path: Path) -> None:
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


def read_plugin_version() -> str:
	config = configparser.ConfigParser()
	config.read(ROOT / "addons/gf/plugin.cfg", encoding="utf-8")
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
	return resolved


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
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for chunk in iter(lambda: handle.read(1024 * 1024), b""):
			digest.update(chunk)
	return digest.hexdigest()


def normalize_manifest_path(path: str) -> str:
	normalized_path = path.strip().replace("\\", "/")
	if normalized_path.startswith("res://"):
		normalized_path = normalized_path.removeprefix("res://")
	if normalized_path.startswith("./"):
		normalized_path = normalized_path[2:]
	return normalized_path.strip("/")


def path_matches_any_manifest_path(path: str, patterns: list[str]) -> bool:
	for raw_pattern in patterns:
		pattern = normalize_manifest_path(raw_pattern)
		if pattern and fnmatch.fnmatch(path, pattern):
			return True
		if pattern.endswith("/**") and (path == pattern[:-3].rstrip("/") or path.startswith(pattern[:-3].rstrip("/") + "/")):
			return True
	return False


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
