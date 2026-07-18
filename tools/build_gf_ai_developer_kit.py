#!/usr/bin/env python3
"""Generate, validate, build, and audit the optional GF AI Developer Kit."""

from __future__ import annotations

import argparse
import configparser
import hashlib
import json
import os
import re
import sys
import tempfile
import zipfile
from pathlib import Path
from typing import Any

import build_gf_package
from gdscript_api_parser import ApiDocs, ApiMember, collect_api_scripts, visibility_of


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "addons/gf/tools/ai_developer"
API_INDEX_PATH = ADDON_ROOT / "knowledge/api_index.json"
PLUGIN_NAME = "gf-ai-developer"
ZIP_TIMESTAMP = (1980, 1, 1, 0, 0, 0)
BLOCKED_PARTS = {"__pycache__", ".git", ".godot"}
BLOCKED_SUFFIXES = {".pyc", ".pyo", ".tmp", ".log"}

sys.path.insert(0, str(ADDON_ROOT))
try:
	from gf_ai.paths import read_json_object as read_strict_json_object
finally:
	sys.path.pop(0)


def main(argv: list[str] | None = None) -> int:
	configure_stdio()
	parser = argparse.ArgumentParser(description="Build and validate the GF AI Developer Kit.")
	parser.add_argument("--version", default="", help="GF SemVer used for the generated Codex plugin.")
	parser.add_argument("--output", default="", help="Output plugin zip path.")
	parser.add_argument("--generate-source", action="store_true", help="Regenerate the tracked compact API index.")
	parser.add_argument("--check-source", action="store_true", help="Check generated knowledge, schemas, catalogs, and templates.")
	parser.add_argument("--validate-only", action="store_true", help="Audit an existing --output plugin zip.")
	parser.add_argument("--json", action="store_true", help="Print JSON output.")
	args = parser.parse_args(argv)
	version = args.version.strip() or read_plugin_version()
	output = resolve_output(args.output, version)
	result: dict[str, Any]
	if args.generate_source:
		payload = render_api_index()
		write_api_index(payload)
		result = check_source(payload)
	elif args.check_source:
		result = check_source()
	elif args.validate_only:
		result = audit_plugin_archive(output, version)
	else:
		issues = check_source()["issues"]
		if issues:
			result = {"ok": False, "version": version, "output": output.as_posix(), "issues": issues}
		else:
			build_plugin_archive(output, version)
			result = audit_plugin_archive(output, version)
	print_result(result, args.json)
	return 0 if result.get("ok") else 1


def configure_stdio() -> None:
	for stream in (sys.stdin, sys.stdout, sys.stderr):
		if hasattr(stream, "reconfigure"):
			stream.reconfigure(encoding="utf-8", errors="strict")


def read_plugin_version() -> str:
	parser = configparser.ConfigParser()
	parser.read(ROOT / "addons/gf/plugin.cfg", encoding="utf-8")
	return parser.get("plugin", "version", fallback="").strip().strip('"')


def resolve_output(raw_path: str, version: str) -> Path:
	path = Path(raw_path) if raw_path else ROOT / "build" / f"gf-ai-developer-kit-{version}.zip"
	return path.resolve()


def render_api_index() -> dict[str, Any]:
	manifest_load = build_gf_package.load_package_manifests()
	if manifest_load.get("issues"):
		raise ValueError("Package manifests are invalid: " + "; ".join(manifest_load["issues"][:10]))
	records = [record for record in manifest_load["records"] if record.get("kind") != "preset"]
	owners: dict[str, str] = {}
	package_payload: list[dict[str, Any]] = []
	for record in records:
		file_issues: list[str] = []
		files = build_gf_package.collect_package_files(record, file_issues)
		if file_issues:
			raise ValueError(f"Package {record['id']} is invalid: " + "; ".join(file_issues[:10]))
		relative_files = [path.relative_to(ROOT).as_posix() for path in files]
		for relative_path in relative_files:
			owners[relative_path] = str(record["id"])
		# The generated API index belongs to this package but must not influence its
		# own deterministic package summary when bootstrapping from a clean tree.
		representative_candidates = [
			path for path in relative_files
			if path != API_INDEX_PATH.relative_to(ROOT).as_posix()
		]
		representative = _representative_path(representative_candidates)
		package_payload.append({
			"id": record["id"],
			"kind": record["kind"],
			"dependencies": record["dependencies"],
			"description": record["description"],
			"representative_path": representative,
		})

	classes: dict[str, Any] = {}
	for script in collect_api_scripts(ROOT / "addons/gf", ROOT):
		if not script.class_name:
			continue
		visibility = visibility_of(script.docs)
		if visibility not in ("public", "protected"):
			continue
		members: list[dict[str, str]] = []
		for member in [*script.signals, *script.enums, *script.constants, *script.properties, *script.methods]:
			member_visibility = visibility_of(member.docs)
			if member_visibility not in ("public", "protected"):
				continue
			members.append({
				"kind": _member_kind(member),
				"name": member.name,
				"signature": member.signature.rstrip(":"),
				"summary": _summary(member.docs, 1),
				"visibility": member_visibility,
			})
		classes[script.class_name] = {
			"extends": script.extends,
			"module": script.module,
			"package_id": owners.get(script.path, ""),
			"path": script.path,
			"summary": _summary(script.docs, 3),
			"visibility": visibility,
			"category": _first_tag(script.docs, "category"),
			"since": _first_tag(script.docs, "since"),
			"members": members,
		}
	payload = {
		"schema_version": 1,
		"catalog_version": "1.0.0",
		"framework_version": read_plugin_version(),
		"source_digest": "",
		"class_count": len(classes),
		"package_count": len(package_payload),
		"packages": sorted(package_payload, key=lambda item: str(item["id"])),
		"classes": dict(sorted(classes.items())),
	}
	digest_payload = {key: value for key, value in payload.items() if key != "source_digest"}
	payload["source_digest"] = hashlib.sha256(
		json.dumps(digest_payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")
	).hexdigest()
	return payload


def render_api_index_text(payload: dict[str, Any] | None = None) -> str:
	value = render_api_index() if payload is None else payload
	return json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n"


def write_api_index(payload: dict[str, Any] | None = None) -> None:
	API_INDEX_PATH.parent.mkdir(parents=True, exist_ok=True)
	temporary = API_INDEX_PATH.with_name(f".{API_INDEX_PATH.name}.{os.getpid()}.tmp")
	try:
		temporary.write_text(render_api_index_text(payload), encoding="utf-8", newline="\n")
		os.replace(temporary, API_INDEX_PATH)
	finally:
		if temporary.exists():
			temporary.unlink()


def check_source(rendered_payload: dict[str, Any] | None = None) -> dict[str, Any]:
	issues: list[str] = []
	payload: dict[str, Any] = {}
	try:
		payload = render_api_index() if rendered_payload is None else rendered_payload
		expected = render_api_index_text(payload)
		actual = API_INDEX_PATH.read_text(encoding="utf-8")
		if actual != expected:
			issues.append("knowledge/api_index.json is stale; run --generate-source.")
	except (OSError, UnicodeDecodeError, ValueError) as exc:
		issues.append(f"API knowledge index check failed: {exc}")
	for relative_path in (
		"schemas/project_contract.schema.json",
		"schemas/feedback_candidate.schema.json",
		"schemas/project_snapshot.schema.json",
		"schemas/capability_catalog.schema.json",
		"schemas/recipe_catalog.schema.json",
		"templates/gf_project_contract.json",
		"templates/feedback_candidate.json",
		"knowledge/capabilities.json",
		"knowledge/recipes.json",
	):
		try:
			read_strict_json_object(ADDON_ROOT / relative_path)
		except ValueError as exc:
			issues.append(f"{relative_path} is invalid UTF-8 JSON: {exc}")
	issues.extend(validate_contract_template())
	issues.extend(validate_catalogs())
	issues.extend(validate_agent_templates())
	return {
		"ok": not issues,
		"api_index": API_INDEX_PATH.relative_to(ROOT).as_posix(),
		"class_count": len(payload.get("classes", {})),
		"issues": issues,
	}


def validate_contract_template() -> list[str]:
	sys.path.insert(0, str(ADDON_ROOT))
	try:
		from gf_ai.schema import validate_schema_file
	finally:
		if sys.path and sys.path[0] == str(ADDON_ROOT):
			sys.path.pop(0)
	issues: list[str] = []
	contract = read_strict_json_object(ADDON_ROOT / "templates/gf_project_contract.json")
	candidate = read_strict_json_object(ADDON_ROOT / "templates/feedback_candidate.json")
	for item in validate_schema_file(contract, ADDON_ROOT / "schemas/project_contract.schema.json"):
		issues.append(f"Contract template {item['path']}: {item['message']}")
	for item in validate_schema_file(candidate, ADDON_ROOT / "schemas/feedback_candidate.schema.json"):
		issues.append(f"Feedback template {item['path']}: {item['message']}")
	return issues


def validate_catalogs() -> list[str]:
	issues: list[str] = []
	api = read_strict_json_object(API_INDEX_PATH) if API_INDEX_PATH.is_file() else {"classes": {}, "packages": []}
	capabilities = read_strict_json_object(ADDON_ROOT / "knowledge/capabilities.json")
	recipes = read_strict_json_object(ADDON_ROOT / "knowledge/recipes.json")
	sys.path.insert(0, str(ADDON_ROOT))
	try:
		from gf_ai.schema import validate_schema_file
	finally:
		if sys.path and sys.path[0] == str(ADDON_ROOT):
			sys.path.pop(0)
	for value, schema_name, label in (
		(capabilities, "capability_catalog.schema.json", "Capability catalog"),
		(recipes, "recipe_catalog.schema.json", "Recipe catalog"),
	):
		for item in validate_schema_file(value, ADDON_ROOT / "schemas" / schema_name):
			issues.append(f"{label} {item['path']}: {item['message']}")
	classes = set(api.get("classes", {}))
	packages = {str(item.get("id")) for item in api.get("packages", []) if isinstance(item, dict)}
	recipe_records = [item for item in recipes.get("recipes", []) if isinstance(item, dict)]
	recipe_ids = {str(item.get("id")) for item in recipe_records}
	capability_records = [item for item in capabilities.get("capabilities", []) if isinstance(item, dict)]
	capability_ids: set[str] = set()
	for capability in capability_records:
		capability_id = str(capability.get("id", ""))
		if not capability_id or capability_id in capability_ids:
			issues.append(f"Capability id is empty or duplicated: {capability_id!r}.")
		capability_ids.add(capability_id)
		issues.extend(_missing_references("capability", capability_id, "class", capability.get("primary_classes", []), classes))
		issues.extend(_missing_references("capability", capability_id, "package", capability.get("packages", []), packages))
		issues.extend(_missing_references("capability", capability_id, "recipe", capability.get("recipes", []), recipe_ids))
	seen_recipes: set[str] = set()
	for recipe in recipe_records:
		recipe_id = str(recipe.get("id", ""))
		if not recipe_id or recipe_id in seen_recipes:
			issues.append(f"Recipe id is empty or duplicated: {recipe_id!r}.")
		seen_recipes.add(recipe_id)
		issues.extend(_missing_references("recipe", recipe_id, "class", recipe.get("primary_classes", []), classes))
	return issues


def validate_agent_templates() -> list[str]:
	issues: list[str] = []
	skill = ADDON_ROOT / "templates/skills/gf-project-development/SKILL.md"
	metadata = ADDON_ROOT / "templates/skills/gf-project-development/agents/openai.yaml"
	text = skill.read_text(encoding="utf-8") if skill.is_file() else ""
	if not text.startswith("---\n") or "name: gf-project-development" not in text or "description:" not in text:
		issues.append("GF project skill frontmatter is missing or invalid.")
	if len(text.splitlines()) > 500:
		issues.append("GF project skill must stay under 500 lines.")
	if not metadata.is_file() or "$gf-project-development" not in metadata.read_text(encoding="utf-8"):
		issues.append("GF project skill agents/openai.yaml is missing or stale.")
	for relative in ("knowledge/architecture.md", "knowledge/workflow.md", "knowledge/feedback.md", "templates/agent/project_instructions.md"):
		path = ADDON_ROOT / relative
		if not path.is_file() or not path.read_text(encoding="utf-8").strip():
			issues.append(f"Required AI knowledge file is missing or empty: {relative}.")
	return issues


def build_plugin_archive(output: Path, version: str) -> None:
	if re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?", version) is None:
		raise ValueError(f"Plugin version must be SemVer: {version!r}")
	entries = plugin_entries(version)
	output.parent.mkdir(parents=True, exist_ok=True)
	with tempfile.TemporaryDirectory(prefix=f".{output.name}.gf-ai-", dir=output.parent) as temporary:
		candidate = Path(temporary) / output.name
		with zipfile.ZipFile(candidate, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
			for name, content in sorted(entries.items()):
				info = zipfile.ZipInfo(name, date_time=ZIP_TIMESTAMP)
				info.create_system = 3
				info.compress_type = zipfile.ZIP_DEFLATED
				info.external_attr = 0o644 << 16
				archive.writestr(info, content)
		os.replace(candidate, output)


def plugin_entries(version: str) -> dict[str, bytes]:
	entries: dict[str, bytes] = {}
	manifest = {
		"name": PLUGIN_NAME,
		"version": version,
		"description": "Contract-driven GF Framework project development with verified API context and approval-gated feedback.",
		"author": {"name": "GF Framework Maintainers", "url": "https://github.com/C76GN/gf-framework"},
		"homepage": "https://gf-framework.readthedocs.io/",
		"repository": "https://github.com/C76GN/gf-framework",
		"license": "Apache-2.0",
		"keywords": ["godot", "gf-framework", "game-development", "mcp", "skills"],
		"skills": "./skills/",
		"mcpServers": "./.mcp.json",
		"interface": {
			"displayName": "GF AI Developer",
			"shortDescription": "Build Godot projects with verified GF context",
			"longDescription": "Reads explicit project intent, queries versioned GF capabilities and APIs, validates project drift, guides provider-neutral adapter boundaries, and drafts redacted framework feedback that cannot be submitted without explicit approval.",
			"developerName": "GF Framework Maintainers",
			"category": "Developer Tools",
			"capabilities": ["Read", "Write"],
			"websiteURL": "https://gf-framework.readthedocs.io/",
			"defaultPrompt": [
				"Implement this feature using my GF project contract",
				"Find the correct installed GF capability and API",
				"Triage this project finding for GF feedback"
			],
			"brandColor": "#2E7D66",
		},
	}
	mcp = {
		"mcpServers": {
			"gf-project": {
				"title": "GF Project",
				"description": "Versioned GF project context, API discovery, validation, and approval-gated feedback.",
				"cwd": ".",
				"command": "python",
				"args": ["./runtime/gf_ai_mcp_server.py"],
			}
		}
	}
	entries[".codex-plugin/plugin.json"] = _json_bytes(manifest)
	entries[".mcp.json"] = _json_bytes(mcp)
	entries["LICENSE.md"] = _read_owned_source(ROOT / "LICENSE.md", ROOT)
	for path in sorted(ADDON_ROOT.rglob("*")):
		if not path.is_file() or _blocked(path):
			continue
		relative = path.relative_to(ADDON_ROOT).as_posix()
		if relative.startswith("gf_ai/") or relative in ("gf_ai_project.py", "gf_ai_mcp_server.py"):
			entries[f"runtime/{relative}"] = _read_owned_source(path, ADDON_ROOT)
		elif relative.startswith(("knowledge/", "schemas/", "templates/")):
			entries[relative] = _read_owned_source(path, ADDON_ROOT)
	for path in sorted((ADDON_ROOT / "templates/skills/gf-project-development").rglob("*")):
		if path.is_file():
			relative = path.relative_to(ADDON_ROOT / "templates/skills").as_posix()
			entries[f"skills/{relative}"] = _read_owned_source(path, ADDON_ROOT)
	return entries


def audit_plugin_archive(output: Path, expected_version: str = "") -> dict[str, Any]:
	issues: list[str] = []
	if not output.is_file():
		return {"ok": False, "version": expected_version, "output": output.as_posix(), "file_count": 0, "issues": ["GF AI Developer Kit archive is missing."]}
	try:
		with zipfile.ZipFile(output, "r") as archive:
			names = [name for name in archive.namelist() if name and not name.endswith("/")]
			if len(names) != len(set(names)):
				issues.append("GF AI Developer Kit archive contains duplicate entries.")
			if names != sorted(names):
				issues.append("GF AI Developer Kit archive entries are not deterministically ordered.")
			for name in names:
				info = archive.getinfo(name)
				parts = Path(name).parts
				if name.startswith(("/", "\\")) or ".." in parts or any(part in BLOCKED_PARTS for part in parts):
					issues.append(f"GF AI Developer Kit archive contains an unsafe path: {name}")
				if Path(name).suffix.lower() in BLOCKED_SUFFIXES:
					issues.append(f"GF AI Developer Kit archive contains a blocked generated file: {name}")
				if info.date_time != ZIP_TIMESTAMP:
					issues.append(f"GF AI Developer Kit archive entry has a non-deterministic timestamp: {name}")
				if info.create_system != 3 or (info.external_attr >> 16) & 0o777 != 0o644:
					issues.append(f"GF AI Developer Kit archive entry permissions are invalid: {name}")
				if info.compress_type != zipfile.ZIP_DEFLATED or info.flag_bits & 0x1:
					issues.append(f"GF AI Developer Kit archive entry compression or encryption is invalid: {name}")
			required = {
				".codex-plugin/plugin.json",
				".mcp.json",
				"runtime/gf_ai_project.py",
				"runtime/gf_ai_mcp_server.py",
				"skills/gf-project-development/SKILL.md",
				"knowledge/api_index.json",
				"schemas/project_contract.schema.json",
				"LICENSE.md",
			}
			for missing in sorted(required - set(names)):
				issues.append(f"GF AI Developer Kit archive is missing: {missing}")
			manifest = json.loads(archive.read(".codex-plugin/plugin.json"))
			if manifest.get("name") != PLUGIN_NAME:
				issues.append("GF AI Developer Kit plugin name is invalid.")
			if manifest.get("license") != "Apache-2.0":
				issues.append("GF AI Developer Kit plugin license must match the repository license.")
			if expected_version and manifest.get("version") != expected_version:
				issues.append("GF AI Developer Kit plugin version does not match the release version.")
			manifest_version = str(manifest.get("version", ""))
			if re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?", manifest_version) is None:
				issues.append("GF AI Developer Kit plugin version is not SemVer.")
			expected_entries = plugin_entries(expected_version or manifest_version)
			for missing in sorted(set(expected_entries) - set(names)):
				issues.append(f"GF AI Developer Kit archive is missing expected source content: {missing}")
			for extra in sorted(set(names) - set(expected_entries)):
				issues.append(f"GF AI Developer Kit archive contains unexpected source content: {extra}")
			for name in sorted(set(names).intersection(expected_entries)):
				if archive.read(name) != expected_entries[name]:
					issues.append(f"GF AI Developer Kit archive content differs from the validated source: {name}")
			mcp = json.loads(archive.read(".mcp.json"))
			server = mcp.get("mcpServers", {}).get("gf-project", {}) if isinstance(mcp, dict) else {}
			if server.get("args") != ["./runtime/gf_ai_mcp_server.py"] or server.get("cwd") != ".":
				issues.append("GF AI Developer Kit MCP entry does not use the bundled project server.")
	except (OSError, KeyError, UnicodeDecodeError, ValueError, json.JSONDecodeError, zipfile.BadZipFile) as exc:
		issues.append(f"GF AI Developer Kit archive is unreadable: {exc}")
		names = []
	return {
		"ok": not issues,
		"version": expected_version,
		"output": output.as_posix(),
		"file_count": len(names),
		"sha256": _sha256_file(output) if output.is_file() else "",
		"issues": issues,
	}


def _representative_path(paths: list[str]) -> str:
	if not paths:
		return ""
	return sorted(paths, key=lambda path: ({".gd": 0, ".json": 1, ".py": 2}.get(Path(path).suffix.lower(), 3), path))[0]


def _summary(docs: ApiDocs, max_lines: int) -> str:
	return " ".join(line.strip() for line in docs.description[:max_lines] if line.strip())


def _first_tag(docs: ApiDocs, name: str) -> str:
	values = docs.tags.get(name, [])
	return values[0] if values else ""


def _member_kind(member: ApiMember) -> str:
	return {"property": "var", "method": "func"}.get(member.kind, member.kind)


def _missing_references(owner_kind: str, owner_id: str, reference_kind: str, values: Any, known: set[str]) -> list[str]:
	if not isinstance(values, list):
		return [f"{owner_kind} {owner_id} {reference_kind} references must be an array."]
	return [
		f"{owner_kind} {owner_id} references missing {reference_kind}: {value}."
		for value in values
		if not isinstance(value, str) or value not in known
	]


def _blocked(path: Path) -> bool:
	return any(part in BLOCKED_PARTS for part in path.parts) or path.suffix.lower() in BLOCKED_SUFFIXES


def _read_owned_source(path: Path, owner_root: Path) -> bytes:
	if path.is_symlink():
		raise ValueError(f"GF AI Developer Kit source must not be a symbolic link: {path}")
	resolved_root = owner_root.resolve(strict=True)
	resolved_path = path.resolve(strict=True)
	try:
		resolved_path.relative_to(resolved_root)
	except ValueError as exc:
		raise ValueError(f"GF AI Developer Kit source escapes its owned root: {path}") from exc
	if not resolved_path.is_file():
		raise ValueError(f"GF AI Developer Kit source is not a regular file: {path}")
	return resolved_path.read_bytes()


def _json_bytes(value: Any) -> bytes:
	return (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")


def _sha256_file(path: Path) -> str:
	hasher = hashlib.sha256()
	with path.open("rb") as stream:
		for chunk in iter(lambda: stream.read(1024 * 1024), b""):
			hasher.update(chunk)
	return hasher.hexdigest()


def print_result(result: dict[str, Any], as_json: bool) -> None:
	if as_json:
		print(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False))
		return
	print(f"ok: {result.get('ok', False)}")
	print(f"output: {result.get('output', result.get('api_index', ''))}")
	for issue in result.get("issues", []):
		print(f"- {issue}")


if __name__ == "__main__":
	raise SystemExit(main())
