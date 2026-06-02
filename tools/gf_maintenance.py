#!/usr/bin/env python3
"""GF maintenance helpers shared by the CLI and the MCP server."""

from __future__ import annotations

import argparse
import configparser
import json
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from gdscript_api_parser import ApiDocs
from gdscript_api_parser import ApiMember
from gdscript_api_parser import ApiScript
from gdscript_api_parser import collect_api_scripts


ROOT = Path(__file__).resolve().parents[1]
SEMVER_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
CHANGELOG_VERSION_RE = re.compile(r"^##\s+\[(?P<version>[^\]]+)\]")
MARKDOWN_FIELD_RE = re.compile(r"^-\s+(?P<name>[^:]+):\s+`(?P<value>[^`]+)`\s*$")
PLUGIN_REQUIRED_FIELDS = ("name", "description", "author", "version", "script")
ARCHIVE_EXPORT_IGNORE_RULES = (
	"/** export-ignore",
	"/addons !export-ignore",
	"/addons/gf !export-ignore",
	"/addons/gf/** !export-ignore",
)
BLOCKED_PACKAGE_DIR_NAMES = (".git", ".godot", ".import", ".vs", "node_modules")
GODOT_SCRIPT_ERROR_PATTERNS = (
	"SCRIPT ERROR",
	"Parse Error:",
	"ERROR: Failed to load script",
)
REFERENCE_PROJECT_ENV_VAR = "GF_REFERENCE_PROJECT_PATH"
DEFAULT_REFERENCE_PROJECT = os.environ.get(REFERENCE_PROJECT_ENV_VAR, "../gf-reference-project")
REFERENCE_BOOT_SCENE_ENV_VAR = "GF_REFERENCE_BOOT_SCENE"
REFERENCE_SMOKE_SCENE_ENV_VAR = "GF_REFERENCE_SMOKE_SCENE"
REFERENCE_MANIFEST_NAME = ".gf_reference_project.json"
DEFAULT_REFERENCE_BOOT_SCENE = "res://scenes/app/driftbound_boot.tscn"
DEFAULT_REFERENCE_SMOKE_SCENE = "res://tests/smoke/driftbound_smoke.tscn"


def resolve_path_from_root(value: str) -> Path:
	path = Path(value)
	if not path.is_absolute():
		path = ROOT / path
	return path.resolve()


def read_reference_manifest(project_root: str) -> dict[str, Any]:
	manifest_path = resolve_path_from_root(project_root) / REFERENCE_MANIFEST_NAME
	if not manifest_path.is_file():
		return {}
	try:
		payload = json.loads(manifest_path.read_text(encoding="utf-8"))
	except (OSError, json.JSONDecodeError):
		return {}
	if not isinstance(payload, dict):
		return {}
	return payload


def get_reference_scene(project_root: str, env_var: str, manifest_key: str, fallback: str) -> str:
	env_value = os.environ.get(env_var, "").strip()
	if env_value:
		return env_value
	manifest_value = read_reference_manifest(project_root).get(manifest_key, "")
	if isinstance(manifest_value, str) and manifest_value.strip():
		return manifest_value.strip()
	return fallback


REFERENCE_BOOT_SCENE = get_reference_scene(
	DEFAULT_REFERENCE_PROJECT,
	REFERENCE_BOOT_SCENE_ENV_VAR,
	"boot_scene",
	DEFAULT_REFERENCE_BOOT_SCENE,
)
REFERENCE_SMOKE_SCENE = get_reference_scene(
	DEFAULT_REFERENCE_PROJECT,
	REFERENCE_SMOKE_SCENE_ENV_VAR,
	"smoke_scene",
	DEFAULT_REFERENCE_SMOKE_SCENE,
)

CHECK_DEFINITIONS: dict[str, list[str]] = {
	"gut": [
		"godot",
		"--headless",
		"--path",
		".",
		"-s",
		"res://addons/gut/gut_cmdln.gd",
		"-gdir=res://tests/gf_core",
		"-ginclude_subdirs",
		"-gexit",
	],
	"api": [sys.executable, "tools/generate_api_reference.py", "--check"],
	"ai_api": [
		sys.executable,
		"tools/generate_ai_api.py",
		"--source",
		"addons/gf",
		"--output",
		"ai_analysis/generated_api",
		"--check",
		"--check-wiki-coverage",
	],
	"docs": [sys.executable, "tools/check_docs_quality.py", "--strict"],
	"mkdocs": [sys.executable, "-m", "mkdocs", "build", "--strict"],
	"diff": ["git", "diff", "--check"],
	"examples_sync": [
		sys.executable,
		"tools/sync_reference_project.py",
		"--project-root",
		DEFAULT_REFERENCE_PROJECT,
		"--check",
	],
	"examples_sync_write": [
		sys.executable,
		"tools/sync_reference_project.py",
		"--project-root",
		DEFAULT_REFERENCE_PROJECT,
	],
	"examples_scan": [
		"godot",
		"--headless",
		"--path",
		DEFAULT_REFERENCE_PROJECT,
		"--editor",
		"--quit-after",
		"2",
	],
	"examples_boot": [
		"godot",
		"--headless",
		"--quit-after",
		"10",
		"--path",
		DEFAULT_REFERENCE_PROJECT,
		"--scene",
		REFERENCE_BOOT_SCENE,
	],
	"examples_smoke": [
		"godot",
		"--headless",
		"--quit-after",
		"10",
		"--path",
		DEFAULT_REFERENCE_PROJECT,
		"--scene",
		REFERENCE_SMOKE_SCENE,
	],
	"examples_coverage": [
		sys.executable,
		"tools/generate_api_coverage_matrix.py",
		"--examples",
		DEFAULT_REFERENCE_PROJECT,
		"--output",
		"ai_analysis/api_coverage_reference_project",
	],
}

CHECK_SUITES: dict[str, list[str]] = {
	"api": ["api", "ai_api"],
	"docs": ["docs", "mkdocs"],
	"examples": ["examples_sync", "examples_scan", "examples_boot", "examples_smoke", "examples_coverage"],
	"quick": ["api", "ai_api", "docs", "diff"],
	"full": ["gut", "api", "ai_api", "docs", "mkdocs", "diff"],
	"release": ["gut", "api", "ai_api", "docs", "mkdocs", "diff", "release_metadata"],
}

_API_CACHE: list[ApiScript] | None = None


@dataclass
class CommandResult:
	name: str
	command: list[str]
	exit_code: int
	stdout: str
	stderr: str
	timed_out: bool = False
	process_exit_code: int | None = None
	notes: list[str] | None = None
	cwd: str = str(ROOT)

	def to_dict(self, max_output_chars: int = 12000) -> dict[str, Any]:
		payload = {
			"name": self.name,
			"command": self.command,
			"cwd": self.cwd,
			"exit_code": self.exit_code,
			"timed_out": self.timed_out,
			"stdout": trim_text(self.stdout, max_output_chars),
			"stderr": trim_text(self.stderr, max_output_chars),
		}
		if self.process_exit_code != None and self.process_exit_code != self.exit_code:
			payload["process_exit_code"] = self.process_exit_code
		if self.notes:
			payload["notes"] = self.notes
		return payload


def main() -> int:
	configure_stdio()
	parser = argparse.ArgumentParser(description="GF maintenance helper CLI.")
	subparsers = parser.add_subparsers(dest="command", required=True)

	summary_parser = subparsers.add_parser("summary", help="Print a compact project maintenance summary.")
	summary_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	search_parser = subparsers.add_parser("api-search", help="Search GF public API by class, member, path, or docs.")
	search_parser.add_argument("query", help="Search text.")
	search_parser.add_argument("--kind", choices=["all", "class", "member"], default="all")
	search_parser.add_argument("--limit", type=int, default=20)
	search_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	class_parser = subparsers.add_parser("api-class", help="Print one GF API class summary.")
	class_parser.add_argument("class_name", help="Class name, case-insensitive.")
	class_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")
	class_parser.add_argument("--no-members", action="store_true", help="Only print class-level information.")

	module_parser = subparsers.add_parser("api-module", help="Print a compact GF API module summary.")
	module_parser.add_argument("module", help="Module id such as kernel, standard, extensions/domain, or domain.")
	module_parser.add_argument("--members", action="store_true", help="Include compact public member signatures.")
	module_parser.add_argument("--limit", type=int, default=80, help="Maximum classes to return.")
	module_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	workspace_parser = subparsers.add_parser("workspace-status", help="Print categorized git status and suggested maintenance checks.")
	workspace_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	check_parser = subparsers.add_parser("check", help="Run predefined maintenance checks.")
	check_parser.add_argument("--suite", choices=sorted(CHECK_SUITES), default="quick")
	check_parser.add_argument(
		"--check",
		action="append",
		choices=sorted([*CHECK_DEFINITIONS.keys(), "release_metadata"]),
		help="Run a specific check. Can be passed multiple times and overrides --suite.",
	)
	check_parser.add_argument("--timeout", type=int, default=600, help="Timeout per subprocess check in seconds.")
	check_parser.add_argument("--fail-fast", action="store_true")
	check_parser.add_argument(
		"--sync-examples",
		action="store_true",
		help="Write-sync addons/gf before examples checks. Default examples checks are read-only.",
	)
	check_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	release_parser = subparsers.add_parser("release-status", help="Check release metadata consistency.")
	release_parser.add_argument("--version", default="", help="Expected SemVer. Defaults to plugin.cfg version.")
	release_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	api_index_parser = subparsers.add_parser("api-index", help="Print compact GF API index statistics.")
	api_index_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	args = parser.parse_args()
	if args.command == "summary":
		data = project_summary()
		print_output(data, args.json, render_summary_text)
		return 0
	if args.command == "api-search":
		data = api_search(args.query, kind=args.kind, limit=args.limit)
		print_output(data, args.json, render_api_search_text)
		return 0
	if args.command == "api-class":
		data = api_class(args.class_name, include_members=not args.no_members)
		print_output(data, args.json, render_api_class_text)
		return 0 if data.get("found") else 1
	if args.command == "api-module":
		data = api_module(args.module, include_members=args.members, limit=args.limit)
		print_output(data, args.json, render_api_module_text)
		return 0 if data.get("found") else 1
	if args.command == "workspace-status":
		data = workspace_status()
		print_output(data, args.json, render_workspace_status_text)
		return 0
	if args.command == "check":
		data = run_checks(
			suite=args.suite,
			checks=args.check,
			timeout_seconds=args.timeout,
			fail_fast=args.fail_fast,
			sync_examples=args.sync_examples,
		)
		print_output(data, args.json, render_checks_text)
		return 0 if data["ok"] else 1
	if args.command == "release-status":
		data = release_status(args.version)
		print_output(data, args.json, render_release_status_text)
		return 0 if data["ok"] else 1
	if args.command == "api-index":
		data = api_index()
		print_output(data, args.json, render_api_index_text)
		return 0
	return 2


def configure_stdio() -> None:
	for stream in (sys.stdin, sys.stdout, sys.stderr):
		if hasattr(stream, "reconfigure"):
			stream.reconfigure(encoding="utf-8", errors="replace")


def project_summary() -> dict[str, Any]:
	release = release_status("")
	catalog = read_api_catalog_stats()
	git_status = git_lines(["status", "--short"])
	workspace = workspace_status()
	return {
		"root": str(ROOT),
		"git": {
			"branch": git_text(["branch", "--show-current"]),
			"head": git_text(["rev-parse", "--short", "HEAD"]),
			"tags_at_head": git_lines(["tag", "--points-at", "HEAD"]),
			"dirty_file_count": len(git_status),
			"dirty_files": git_status[:80],
		},
		"workspace": {
			"dirty_file_count": workspace["dirty_file_count"],
			"categories": {
				name: len(files)
				for name, files in workspace["categories"].items()
				if files
			},
			"recommended_checks": workspace["recommended_checks"],
		},
		"release": release,
		"api_catalog": catalog,
		"maintenance": {
			"rules": "AI_MAINTENANCE.md",
			"ai_api_command": "python tools/generate_ai_api.py --source addons/gf --output ai_analysis/generated_api",
			"api_coverage_command": "python tools/generate_api_coverage_matrix.py --output ai_analysis/api_coverage",
			"full_check_suite": "python tools/gf_maintenance.py check --suite full",
			"mcp_server": "python tools/gf_mcp_server.py",
		},
	}


def read_api_catalog_stats() -> dict[str, Any]:
	path = ROOT / "docs/api_catalog/index.xml"
	if not path.exists():
		return {"exists": False}
	root = ET.fromstring(path.read_text(encoding="utf-8"))
	return {
		"exists": True,
		"schema_version": root.get("schemaVersion", ""),
		"source_root": root.get("sourceRoot", ""),
		"source_digest": root.get("sourceDigest", ""),
		"class_count": int(root.get("classCount", "0")),
		"method_count": int(root.get("methodCount", "0")),
		"modules": [
			{
				"id": module.get("id", ""),
				"label": module.get("label", ""),
				"class_count": int(module.get("classCount", "0")),
				"method_count": int(module.get("methodCount", "0")),
			}
			for module in root.findall("module")
		],
	}


def api_index() -> dict[str, Any]:
	scripts = load_api_scripts()
	classes = [script for script in scripts if script.class_name]
	modules: dict[str, dict[str, int]] = {}
	for script in scripts:
		module = modules.setdefault(script.module, {"files": 0, "classes": 0, "methods": 0})
		module["files"] += 1
		module["classes"] += 1 if script.class_name else 0
		module["methods"] += len(script.methods)
	return {
		"source_root": "addons/gf",
		"file_count": len(scripts),
		"class_count": len(classes),
		"public_method_count": sum(len(script.methods) for script in scripts),
		"modules": modules,
		"classes": [
			{
				"class_name": script.class_name,
				"extends": script.extends,
				"module": script.module,
				"path": script.path,
				"summary": docs_summary(script.docs),
			}
			for script in classes
		],
	}


def api_search(query: str, kind: str = "all", limit: int = 20) -> dict[str, Any]:
	needle = query.strip().lower()
	if not needle:
		return {"query": query, "results": [], "count": 0}
	results: list[dict[str, Any]] = []
	for script in load_api_scripts():
		class_score = score_text(needle, script.class_name or "", exact=120, starts=90, contains=70)
		class_score = max(class_score, score_text(needle, script.path, exact=40, starts=30, contains=20))
		class_score = max(class_score, score_text(needle, script.module, exact=30, starts=25, contains=15))
		class_score = max(class_score, score_text(needle, " ".join(docs_to_lines(script.docs)), exact=20, starts=15, contains=10))
		member_matches: list[dict[str, Any]] = []
		if kind in {"all", "member"}:
			for member in all_members(script):
				member_score = score_member(needle, member)
				if member_score <= 0:
					continue
				member_matches.append(member_to_compact_dict(member, member_score))
		if kind == "class" and class_score <= 0:
			continue
		if kind == "member" and not member_matches:
			continue
		score = max(class_score, max([item["score"] for item in member_matches], default=0))
		if score <= 0:
			continue
		results.append({
			"score": score,
			"class_name": script.class_name,
			"extends": script.extends,
			"module": script.module,
			"path": script.path,
			"summary": docs_summary(script.docs),
			"member_matches": sorted(member_matches, key=lambda item: item["score"], reverse=True)[:8],
		})
	results.sort(key=lambda item: (-item["score"], item["class_name"] or item["path"]))
	limited = results[:max(limit, 1)]
	return {"query": query, "kind": kind, "count": len(results), "results": limited}


def api_class(class_name: str, include_members: bool = True) -> dict[str, Any]:
	query = class_name.strip().lower()
	for script in load_api_scripts():
		if (script.class_name or "").lower() != query:
			continue
		data = {
			"found": True,
			"class_name": script.class_name,
			"extends": script.extends,
			"module": script.module,
			"path": script.path,
			"summary": docs_to_lines(script.docs),
			"reference_page": f"docs/zh/reference/api/classes/{script.class_name}.md",
		}
		if include_members:
			data["signals"] = [member_to_dict(item) for item in script.signals]
			data["enums"] = [member_to_dict(item) for item in script.enums]
			data["constants"] = [member_to_dict(item) for item in script.constants]
			data["variables"] = [member_to_dict(item) for item in script.properties]
			data["methods"] = [member_to_dict(item) for item in script.methods]
		return data
	return {"found": False, "class_name": class_name, "message": "Class was not found under addons/gf."}


def api_module(module: str, include_members: bool = False, limit: int = 80) -> dict[str, Any]:
	query = module.strip().replace("\\", "/").strip("/").lower()
	if not query:
		return {"found": False, "module": module, "message": "Module query is empty."}
	matched = [
		script
		for script in load_api_scripts()
		if module_matches(script.module, query)
	]
	if not matched:
		available = sorted({script.module for script in load_api_scripts() if script.class_name})
		return {
			"found": False,
			"module": module,
			"message": "Module was not found under addons/gf.",
			"available_modules": available,
		}
	matched.sort(key=lambda script: (script.module, script.class_name or script.path))
	class_scripts = [script for script in matched if script.class_name]
	limited = class_scripts[:max(limit, 1)]
	classes: list[dict[str, Any]] = []
	for script in limited:
		item: dict[str, Any] = {
			"class_name": script.class_name,
			"extends": script.extends,
			"module": script.module,
			"path": script.path,
			"summary": docs_summary(script.docs),
			"member_counts": {
				"signals": len(script.signals),
				"enums": len(script.enums),
				"constants": len(script.constants),
				"variables": len(script.properties),
				"methods": len(script.methods),
			},
		}
		if include_members:
			item["members"] = [
				member_to_module_dict(member)
				for member in all_members(script)
			]
		classes.append(item)
	modules: dict[str, dict[str, int]] = {}
	for script in matched:
		stats = modules.setdefault(script.module, {"files": 0, "classes": 0, "methods": 0})
		stats["files"] += 1
		stats["classes"] += 1 if script.class_name else 0
		stats["methods"] += len(script.methods)
	return {
		"found": True,
		"query": module,
		"matched_modules": modules,
		"class_count": len(class_scripts),
		"returned_class_count": len(classes),
		"truncated": len(class_scripts) > len(limited),
		"classes": classes,
	}


def module_matches(module: str, query: str) -> bool:
	normalized = module.lower().strip("/")
	return normalized == query or normalized.endswith(f"/{query}") or query in normalized


def workspace_status() -> dict[str, Any]:
	entries = parse_git_status(git_lines(["status", "--short"]))
	categories: dict[str, list[dict[str, str]]] = {
		"runtime_source": [],
		"examples": [],
		"tests": [],
		"manual_docs": [],
		"generated_docs": [],
		"maintenance_tools": [],
		"release_metadata": [],
		"other": [],
	}
	for entry in entries:
		categories[classify_status_path(entry["path"])].append(entry)
	recommended_checks = recommend_checks(categories)
	return {
		"ok": True,
		"root": str(ROOT),
		"branch": git_text(["branch", "--show-current"]),
		"head": git_text(["rev-parse", "--short", "HEAD"]),
		"dirty_file_count": len(entries),
		"categories": categories,
		"ai_analysis_ignored": git_exit_code(["check-ignore", "-q", "ai_analysis"]) == 0,
		"recommended_checks": recommended_checks,
	}


def parse_git_status(lines: list[str]) -> list[dict[str, str]]:
	entries: list[dict[str, str]] = []
	for line in lines:
		if len(line) < 3:
			continue
		status = line[:2]
		path = line[3:].strip()
		if " -> " in path:
			path = path.split(" -> ", 1)[1].strip()
		entries.append({
			"status": status,
			"path": path.replace("\\", "/"),
		})
	return entries


def classify_status_path(path: str) -> str:
	normalized = path.replace("\\", "/")
	if normalized.startswith("docs/api_catalog/") or normalized.startswith("docs/zh/reference/api/"):
		return "generated_docs"
	if normalized.startswith("examples/"):
		return "examples"
	if normalized.startswith("tests/"):
		return "tests"
	if normalized.startswith("docs/") or normalized in {"README.md", "README.zh.md", "addons/gf/README.md"}:
		return "manual_docs"
	if normalized.startswith("tools/") or normalized in {"AI_MAINTENANCE.md", "CODING_STYLE.md", "API_SURFACE.md"}:
		return "maintenance_tools"
	if (
		normalized in {"ASSET_LIBRARY.md", "ASSET_STORE.md", ".gitattributes"}
		or normalized == "addons/gf/plugin.cfg"
		or normalized.endswith("/gf_extension.json")
	):
		return "release_metadata"
	if normalized.startswith("addons/gf/"):
		return "runtime_source"
	return "other"


def recommend_checks(categories: dict[str, list[dict[str, str]]]) -> list[str]:
	recommendations: list[str] = []
	if categories["runtime_source"]:
		recommendations.extend([
			"python tools/generate_api_reference.py --check",
			"python tools/generate_ai_api.py --source addons/gf --output ai_analysis/generated_api --check --check-wiki-coverage",
			"godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gf_core -ginclude_subdirs -gexit",
		])
	if categories["examples"]:
		recommendations.append("python tools/gf_maintenance.py check --suite examples --json")
	if categories["tests"]:
		recommendations.append("godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gf_core -ginclude_subdirs -gexit")
	if categories["manual_docs"]:
		recommendations.extend([
			"python tools/check_docs_quality.py --strict",
			"python -m mkdocs build --strict",
		])
	if categories["generated_docs"]:
		recommendations.append("python tools/generate_api_reference.py --check")
	if categories["maintenance_tools"]:
		recommendations.extend([
			"python -m py_compile tools/gf_maintenance.py tools/gf_mcp_server.py",
			"python tools/gf_maintenance.py check --suite quick --json",
		])
	if categories["release_metadata"]:
		recommendations.append("python tools/gf_maintenance.py release-status --json")
	if categories["other"]:
		recommendations.append("python tools/gf_maintenance.py check --suite quick --json")
	return dedupe_preserve_order(recommendations)


def dedupe_preserve_order(items: list[str]) -> list[str]:
	result: list[str] = []
	for item in items:
		if item not in result:
			result.append(item)
	return result


def load_api_scripts() -> list[ApiScript]:
	global _API_CACHE
	if _API_CACHE is None:
		_API_CACHE = collect_api_scripts(ROOT / "addons/gf", ROOT)
	return _API_CACHE


def all_members(script: ApiScript) -> list[ApiMember]:
	return [*script.signals, *script.enums, *script.constants, *script.properties, *script.methods]


def score_member(needle: str, member: ApiMember) -> int:
	score = score_text(needle, member.name, exact=100, starts=80, contains=60)
	score = max(score, score_text(needle, member.signature, exact=60, starts=50, contains=40))
	score = max(score, score_text(needle, " ".join(docs_to_lines(member.docs)), exact=30, starts=20, contains=10))
	return score


def score_text(needle: str, value: str, exact: int, starts: int, contains: int) -> int:
	text = value.lower()
	if not text:
		return 0
	if text == needle:
		return exact
	if text.startswith(needle):
		return starts
	if needle in text:
		return contains
	return 0


def docs_to_lines(docs: ApiDocs) -> list[str]:
	lines = docs.description[:]
	for tag_name in sorted(docs.tags):
		for value in docs.tags[tag_name]:
			lines.append(f"@{tag_name} {value}".strip())
	return lines


def docs_summary(docs: ApiDocs, max_lines: int = 3) -> list[str]:
	return docs_to_lines(docs)[:max_lines]


def member_to_compact_dict(member: ApiMember, score: int) -> dict[str, Any]:
	return {
		"score": score,
		"kind": member.kind,
		"name": member.name,
		"signature": member.signature,
		"docs": docs_summary(member.docs, max_lines=2),
	}


def member_to_module_dict(member: ApiMember) -> dict[str, Any]:
	return {
		"kind": member.kind,
		"name": member.name,
		"signature": member.signature,
		"docs": docs_summary(member.docs, max_lines=2),
	}


def member_to_dict(member: ApiMember) -> dict[str, Any]:
	return {
		"kind": member.kind,
		"name": member.name,
		"signature": member.signature,
		"line": member.line,
		"decorators": member.decorators,
		"docs": docs_to_lines(member.docs),
	}


def run_checks(
	suite: str = "quick",
	checks: list[str] | None = None,
	timeout_seconds: int = 600,
	fail_fast: bool = False,
	sync_examples: bool = False,
) -> dict[str, Any]:
	check_names = list(checks if checks else CHECK_SUITES[suite])
	if sync_examples:
		check_names = [
			"examples_sync_write" if name == "examples_sync" else name
			for name in check_names
		]
	results: list[dict[str, Any]] = []
	for name in check_names:
		if name == "release_metadata":
			status = release_status("")
			results.append({
				"name": name,
				"exit_code": 0 if status["ok"] else 1,
				"timed_out": False,
				"release_status": status,
			})
			if fail_fast and not status["ok"]:
				break
			continue
		result = run_command(name, CHECK_DEFINITIONS[name], timeout_seconds)
		results.append(result.to_dict())
		if fail_fast and result.exit_code != 0:
			break
	ok = all(item.get("exit_code", 1) == 0 for item in results)
	return {"ok": ok, "suite": suite, "checks": check_names, "results": results}


def run_command(name: str, command: list[str], timeout_seconds: int) -> CommandResult:
	try:
		completed = subprocess.run(
			command,
			cwd=ROOT,
			capture_output=True,
			text=True,
			encoding="utf-8",
			errors="replace",
			timeout=timeout_seconds,
		)
		exit_code = completed.returncode
		notes: list[str] | None = None
		if name == "gut" and completed.returncode != 0 and gut_report_all_tests_passed(completed.stdout):
			exit_code = 0
			notes = [
				"Godot returned a non-zero process code after GUT reported all tests passed; "
				"the original code is preserved as process_exit_code.",
			]
		if name in {"examples_scan", "examples_boot", "examples_smoke"} and has_godot_script_error(completed.stdout, completed.stderr):
			exit_code = 1
			notes = append_note(
				notes,
				"Godot returned zero but reported script loading or parse errors in output.",
			)
		return CommandResult(
			name,
			command,
			exit_code,
			completed.stdout,
			completed.stderr,
			process_exit_code=completed.returncode,
			notes=notes,
		)
	except subprocess.TimeoutExpired as exc:
		return CommandResult(
			name,
			command,
			124,
			exc.stdout or "",
			exc.stderr or f"timed out after {timeout_seconds}s",
			timed_out=True,
			notes=["Command timed out."],
		)
	except FileNotFoundError as exc:
		return CommandResult(
			name,
			command,
			127,
			"",
			f"command not found: {command[0]}\n{exc}",
			notes=[
				"Check that the executable is installed and available on PATH.",
				f"cwd: {ROOT}",
			],
		)
	except OSError as exc:
		return CommandResult(
			name,
			command,
			126,
			"",
			f"failed to run command: {exc}",
			notes=[f"cwd: {ROOT}"],
		)


def has_godot_script_error(stdout: str, stderr: str) -> bool:
	output = f"{stdout}\n{stderr}"
	return any(pattern in output for pattern in GODOT_SCRIPT_ERROR_PATTERNS)


def append_note(notes: list[str] | None, note: str) -> list[str]:
	if notes == None:
		return [note]
	notes.append(note)
	return notes


def gut_report_all_tests_passed(stdout: str) -> bool:
	return "---- All tests passed! ----" in stdout


def release_status(expected_version: str = "") -> dict[str, Any]:
	plugin_audit = audit_plugin_cfg()
	plugin_version = plugin_audit["version"]
	version = expected_version.strip() or plugin_version
	issues: list[str] = []
	if SEMVER_RE.match(version) is None:
		issues.append(f"Expected version {version!r} is not SemVer MAJOR.MINOR.PATCH.")
	if plugin_version != version:
		issues.append(f"addons/gf/plugin.cfg version is {plugin_version!r}, expected {version!r}.")
	for field_name in plugin_audit["missing_required_fields"]:
		issues.append(f"addons/gf/plugin.cfg is missing required [plugin] field {field_name!r}.")
	if not plugin_audit["script_inside_addon"]:
		issues.append("addons/gf/plugin.cfg script must resolve inside addons/gf.")
	elif not plugin_audit["script_exists"]:
		issues.append(f"addons/gf/plugin.cfg script was not found: {plugin_audit['script_path']}.")
	else:
		if not plugin_audit["script_has_tool"]:
			issues.append(f"{plugin_audit['script_path']} is missing @tool.")
		if not plugin_audit["script_extends_editor_plugin"]:
			issues.append(f"{plugin_audit['script_path']} must extend EditorPlugin.")
	for file_name, exists in plugin_audit["required_files"].items():
		if not exists:
			issues.append(f"addons/gf package is missing {file_name}.")

	asset_fields = read_asset_library_fields()
	for field_name in ("Asset Version", "Download Commit/URL"):
		value = asset_fields.get(field_name, "")
		if value != version:
			issues.append(f"ASSET_LIBRARY.md {field_name} is {value!r}, expected {version!r}.")
	icon_url = asset_fields.get("Icon URL", "")
	if icon_url and version not in icon_url:
		issues.append(f"ASSET_LIBRARY.md Icon URL does not reference release {version}.")

	asset_store = read_asset_store_metadata()
	for field_name in ("Current release version", "Release tag"):
		value = asset_store["fields"].get(field_name, "")
		if value != version:
			issues.append(f"ASSET_STORE.md {field_name} is {value!r}, expected {version!r}.")
	asset_library_minimum_godot = asset_fields.get("Minimum Godot Version", "")
	asset_store_minimum_godot = asset_store["fields"].get("Minimum Godot version", "")
	if asset_library_minimum_godot and asset_store_minimum_godot and asset_store_minimum_godot != asset_library_minimum_godot:
		issues.append(
			"ASSET_STORE.md Minimum Godot version is "
			f"{asset_store_minimum_godot!r}, expected ASSET_LIBRARY.md Minimum Godot Version {asset_library_minimum_godot!r}."
		)
	if not asset_store["tags"] or len(asset_store["tags"]) > 5:
		issues.append("ASSET_STORE.md Tags must contain 1 to 5 tags.")
	if asset_store["fields"].get("Self disclose AI usage", "").lower() == "enabled" and not asset_store["ai_disclose_reason"]:
		issues.append("ASSET_STORE.md AI disclose reason is empty while AI usage disclosure is enabled.")
	if asset_store["fields"].get("Source code URL", "") != "https://github.com/C76GN/gf-framework":
		issues.append("ASSET_STORE.md Source code URL must point to the GF Framework repository.")

	extension_versions = read_extension_versions()
	extension_mismatches = [
		item for item in extension_versions
		if item["version"] != version
	]
	if extension_mismatches:
		issues.append(f"{len(extension_mismatches)} extension manifest version(s) do not match {version}.")

	changelog_versions = read_changelog_versions()
	if version not in changelog_versions:
		issues.append(f"docs/zh/changelog.md does not contain section [{version}].")

	package_archive = audit_package_archive(version)
	if package_archive["missing_export_ignore_rules"]:
		issues.append(
			".gitattributes is missing GF release archive export-ignore rule(s): "
			+ ", ".join(package_archive["missing_export_ignore_rules"])
		)
	if package_archive["blocked_package_dirs"]:
		issues.append(
			"addons/gf release payload contains blocked package dir(s): "
			+ ", ".join(package_archive["blocked_package_dirs"])
		)
	if not package_archive["asset_store_package"].get("ok", False):
		issues.extend(
			"Asset Store package layout is invalid: " + issue
			for issue in package_archive["asset_store_package"].get("issues", [])
		)

	tag_exists = git_exit_code(["rev-parse", "-q", "--verify", f"refs/tags/{version}"]) == 0
	tag_points_at_head = version in git_lines(["tag", "--points-at", "HEAD"])
	return {
		"ok": len(issues) == 0,
		"version": version,
		"issues": issues,
		"plugin_version": plugin_version,
		"plugin": plugin_audit,
		"asset_library": asset_fields,
		"asset_store": asset_store,
		"extension_count": len(extension_versions),
		"extension_mismatches": extension_mismatches,
		"changelog_versions": changelog_versions[:5],
		"package_archive": package_archive,
		"tag_exists": tag_exists,
		"tag_points_at_head": tag_points_at_head,
	}


def read_plugin_version() -> str:
	return read_plugin_fields().get("version", "")


def read_plugin_fields() -> dict[str, str]:
	path = ROOT / "addons/gf/plugin.cfg"
	config = configparser.ConfigParser()
	config.read(path, encoding="utf-8")
	if not config.has_section("plugin"):
		return {}
	return {
		name: strip_quotes(config.get("plugin", name, fallback="").strip())
		for name in config.options("plugin")
	}


def audit_plugin_cfg() -> dict[str, Any]:
	addon_root = ROOT / "addons/gf"
	fields = read_plugin_fields()
	script_value = fields.get("script", "")
	script_path = addon_root / script_value if script_value else addon_root
	script_inside_addon = path_is_inside(script_path, addon_root)
	script_exists = script_inside_addon and script_path.is_file()
	script_text = script_path.read_text(encoding="utf-8") if script_exists else ""
	required_files = {
		"README.md": (addon_root / "README.md").is_file(),
		"LICENSE.md": (addon_root / "LICENSE.md").is_file(),
		"icon.png": (addon_root / "icon.png").is_file(),
	}
	return {
		"fields": fields,
		"version": fields.get("version", ""),
		"missing_required_fields": [
			field_name for field_name in PLUGIN_REQUIRED_FIELDS
			if not fields.get(field_name, "")
		],
		"script_path": script_path.relative_to(ROOT).as_posix() if script_inside_addon else script_value,
		"script_inside_addon": script_inside_addon,
		"script_exists": script_exists,
		"script_has_tool": "@tool" in script_text,
		"script_extends_editor_plugin": re.search(r"^\s*extends\s+EditorPlugin\b", script_text, re.MULTILINE) is not None,
		"required_files": required_files,
	}


def read_asset_library_fields() -> dict[str, str]:
	path = ROOT / "ASSET_LIBRARY.md"
	return read_markdown_fields(path)


def read_asset_store_metadata() -> dict[str, Any]:
	path = ROOT / "ASSET_STORE.md"
	return {
		"exists": path.exists(),
		"fields": read_markdown_fields(path),
		"tags": read_comma_separated_fenced_field(path, "Tags"),
		"ai_disclose_reason": read_fenced_field(path, "AI disclose reason").strip(),
	}


def read_markdown_fields(path: Path) -> dict[str, str]:
	fields: dict[str, str] = {}
	if not path.exists():
		return fields
	for line in path.read_text(encoding="utf-8").splitlines():
		match = MARKDOWN_FIELD_RE.match(line)
		if match:
			fields[match.group("name")] = match.group("value").strip()
	return fields


def read_comma_separated_fenced_field(path: Path, field_name: str) -> list[str]:
	text = read_fenced_field(path, field_name)
	values: list[str] = []
	for item in re.split(r"[,\n]", text):
		value = item.strip()
		if value:
			values.append(value)
	return values


def read_fenced_field(path: Path, field_name: str) -> str:
	if not path.exists():
		return ""
	lines = path.read_text(encoding="utf-8").splitlines()
	marker = f"- {field_name}:"
	for index, line in enumerate(lines):
		if line.strip() != marker:
			continue
		fence_start = -1
		for candidate_index in range(index + 1, len(lines)):
			if lines[candidate_index].strip().startswith("```"):
				fence_start = candidate_index
				break
		if fence_start < 0:
			return ""
		for candidate_index in range(fence_start + 1, len(lines)):
			if lines[candidate_index].strip().startswith("```"):
				return "\n".join(lines[fence_start + 1:candidate_index]).strip()
		return ""
	return ""


def audit_package_archive(version: str) -> dict[str, Any]:
	gitattributes_path = ROOT / ".gitattributes"
	gitattributes_lines = []
	if gitattributes_path.exists():
		gitattributes_lines = [
			line.strip()
			for line in gitattributes_path.read_text(encoding="utf-8").splitlines()
			if line.strip() and not line.strip().startswith("#")
		]
	return {
		"gitattributes_exists": gitattributes_path.exists(),
		"required_export_ignore_rules": list(ARCHIVE_EXPORT_IGNORE_RULES),
		"missing_export_ignore_rules": [
			rule for rule in ARCHIVE_EXPORT_IGNORE_RULES
			if rule not in gitattributes_lines
		],
		"blocked_package_dirs": find_blocked_package_dirs(ROOT / "addons/gf"),
		"asset_store_package": audit_asset_store_package(version),
	}


def audit_asset_store_package(version: str) -> dict[str, Any]:
	script_path = ROOT / "tools/build_asset_store_package.py"
	if not script_path.is_file():
		return {
			"ok": False,
			"issues": ["tools/build_asset_store_package.py is missing."],
		}

	with tempfile.TemporaryDirectory(prefix="gf-package-") as temp_dir:
		output_path = Path(temp_dir) / f"gf-framework-{version}.zip"
		completed = subprocess.run(
			[
				sys.executable,
				"tools/build_asset_store_package.py",
				"--version",
				version,
				"--output",
				str(output_path),
				"--json",
			],
			cwd=ROOT,
			capture_output=True,
			text=True,
			encoding="utf-8",
			errors="replace",
			timeout=60,
		)
		if completed.returncode != 0:
			return {
				"ok": False,
				"issues": [
					"tools/build_asset_store_package.py failed.",
					trim_text(completed.stdout.strip() or completed.stderr.strip(), 1000),
				],
			}
		try:
			return json.loads(completed.stdout)
		except json.JSONDecodeError as exc:
			return {
				"ok": False,
				"issues": [f"tools/build_asset_store_package.py returned invalid JSON: {exc}"],
			}


def find_blocked_package_dirs(root: Path) -> list[str]:
	if not root.exists():
		return []
	blocked_names = set(BLOCKED_PACKAGE_DIR_NAMES)
	result: list[str] = []
	for current_root, dir_names, _file_names in os.walk(root):
		for dir_name in list(dir_names):
			if dir_name not in blocked_names:
				continue
			path = Path(current_root) / dir_name
			result.append(path.relative_to(ROOT).as_posix())
			dir_names.remove(dir_name)
	return sorted(result)


def path_is_inside(path: Path, root: Path) -> bool:
	try:
		path.resolve().relative_to(root.resolve())
		return True
	except ValueError:
		return False


def read_extension_versions() -> list[dict[str, str]]:
	root = ROOT / "addons/gf/extensions"
	versions: list[dict[str, str]] = []
	for path in sorted(root.glob("*/gf_extension.json")):
		data = json.loads(path.read_text(encoding="utf-8"))
		versions.append({
			"extension": path.parent.name,
			"path": path.relative_to(ROOT).as_posix(),
			"version": str(data.get("version", "")).strip(),
			"extension_version": str(data.get("extension_version", "")).strip(),
		})
	return versions


def read_changelog_versions() -> list[str]:
	path = ROOT / "docs/zh/changelog.md"
	if not path.exists():
		return []
	versions: list[str] = []
	for line in path.read_text(encoding="utf-8").splitlines():
		match = CHANGELOG_VERSION_RE.match(line)
		if match:
			versions.append(match.group("version").strip())
	return versions


def strip_quotes(value: str) -> str:
	if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", "\""}:
		return value[1:-1]
	return value


def git_text(args: list[str]) -> str:
	result = subprocess.run(
		["git", *args],
		cwd=ROOT,
		capture_output=True,
		text=True,
		encoding="utf-8",
		errors="replace",
	)
	return result.stdout.strip()


def git_lines(args: list[str]) -> list[str]:
	result = subprocess.run(
		["git", *args],
		cwd=ROOT,
		capture_output=True,
		text=True,
		encoding="utf-8",
		errors="replace",
	)
	text = result.stdout
	return [line for line in text.splitlines() if line.strip()]


def git_exit_code(args: list[str]) -> int:
	return subprocess.run(
		["git", *args],
		cwd=ROOT,
		capture_output=True,
		text=True,
		encoding="utf-8",
		errors="replace",
	).returncode


def print_output(data: dict[str, Any], as_json: bool, renderer: Any) -> None:
	if as_json:
		print(json.dumps(data, ensure_ascii=False, indent=2))
	else:
		print(renderer(data))


def render_summary_text(data: dict[str, Any]) -> str:
	release = data["release"]
	catalog = data["api_catalog"]
	lines = [
		f"root: {data['root']}",
		f"git: {data['git']['branch']} {data['git']['head']} dirty={data['git']['dirty_file_count']}",
		f"version: {release['version']} release_ok={release['ok']}",
		f"api: classes={catalog.get('class_count', 0)} methods={catalog.get('method_count', 0)} schema={catalog.get('schema_version', '')}",
		"checks: python tools/gf_maintenance.py check --suite full",
		"mcp: python tools/gf_mcp_server.py",
	]
	if release["issues"]:
		lines.append("release issues:")
		lines.extend(f"- {issue}" for issue in release["issues"])
	return "\n".join(lines)


def render_api_search_text(data: dict[str, Any]) -> str:
	lines = [f"query: {data['query']} matches={data['count']}"]
	for item in data["results"]:
		lines.append(f"- {item['class_name']} | {item['module']} | {item['path']}")
		for match in item["member_matches"][:3]:
			lines.append(f"  - {match['kind']} {match['signature']}")
	return "\n".join(lines)


def render_api_class_text(data: dict[str, Any]) -> str:
	if not data.get("found"):
		return data["message"]
	lines = [
		f"{data['class_name']} extends {data['extends']}",
		f"path: {data['path']}",
		f"module: {data['module']}",
	]
	for line in data.get("summary", [])[:5]:
		lines.append(f"summary: {line}")
	for group in ("signals", "enums", "constants", "variables", "methods"):
		items = data.get(group, [])
		if not items:
			continue
		lines.append(f"{group}:")
		for item in items:
			lines.append(f"- {item['signature']}")
	return "\n".join(lines)


def render_api_module_text(data: dict[str, Any]) -> str:
	if not data.get("found"):
		lines = [data["message"]]
		available = data.get("available_modules", [])
		if available:
			lines.append("available modules:")
			lines.extend(f"- {module}" for module in available)
		return "\n".join(lines)
	lines = [
		f"query: {data['query']}",
		f"classes: {data['returned_class_count']}/{data['class_count']} truncated={data['truncated']}",
		"modules:",
	]
	for module, stats in sorted(data["matched_modules"].items()):
		lines.append(f"- {module}: classes={stats['classes']} methods={stats['methods']}")
	lines.append("classes:")
	for item in data["classes"]:
		lines.append(f"- {item['class_name']} extends {item['extends']} | {item['path']}")
		counts = item["member_counts"]
		lines.append(
			"  members: "
			f"signals={counts['signals']} enums={counts['enums']} constants={counts['constants']} "
			f"variables={counts['variables']} methods={counts['methods']}"
		)
	return "\n".join(lines)


def render_workspace_status_text(data: dict[str, Any]) -> str:
	lines = [
		f"root: {data['root']}",
		f"git: {data['branch']} {data['head']} dirty={data['dirty_file_count']}",
		f"ai_analysis_ignored: {data['ai_analysis_ignored']}",
	]
	for category, files in data["categories"].items():
		if not files:
			continue
		lines.append(f"{category}: {len(files)}")
		lines.extend(f"- {item['status']} {item['path']}" for item in files[:20])
		if len(files) > 20:
			lines.append(f"- ... {len(files) - 20} more")
	if data["recommended_checks"]:
		lines.append("recommended checks:")
		lines.extend(f"- {command}" for command in data["recommended_checks"])
	return "\n".join(lines)


def render_checks_text(data: dict[str, Any]) -> str:
	lines = [f"suite: {data['suite']} ok={data['ok']}"]
	for result in data["results"]:
		lines.append(f"- {result['name']}: exit={result['exit_code']} timeout={result.get('timed_out', False)}")
		stdout = result.get("stdout", "").strip()
		stderr = result.get("stderr", "").strip()
		if stdout:
			lines.append(indent_text(trim_text(stdout, 1200), "  stdout: "))
		if stderr:
			lines.append(indent_text(trim_text(stderr, 1200), "  stderr: "))
		release = result.get("release_status")
		if release and release["issues"]:
			lines.extend(f"  issue: {issue}" for issue in release["issues"])
	return "\n".join(lines)


def render_release_status_text(data: dict[str, Any]) -> str:
	lines = [f"version: {data['version']} ok={data['ok']}"]
	lines.append(f"plugin: {data['plugin_version']}")
	asset_library = data.get("asset_library", {})
	lines.append(
		"asset_library: "
		f"version={asset_library.get('Asset Version', '')} "
		f"download={asset_library.get('Download Commit/URL', '')}"
	)
	asset_store = data.get("asset_store", {})
	asset_store_fields = asset_store.get("fields", {})
	lines.append(
		"asset_store: "
		f"version={asset_store_fields.get('Current release version', '')} "
		f"tag={asset_store_fields.get('Release tag', '')} "
		f"tags={len(asset_store.get('tags', []))}"
	)
	lines.append(f"extensions: {data['extension_count']} mismatches={len(data['extension_mismatches'])}")
	package_archive = data.get("package_archive", {})
	lines.append(
		"archive: "
		f"missing_rules={len(package_archive.get('missing_export_ignore_rules', []))} "
		f"blocked_dirs={len(package_archive.get('blocked_package_dirs', []))} "
		f"asset_store_package_issues={len(package_archive.get('asset_store_package', {}).get('issues', []))}"
	)
	lines.append(f"tag: exists={data['tag_exists']} points_at_head={data['tag_points_at_head']}")
	if data["issues"]:
		lines.append("issues:")
		lines.extend(f"- {issue}" for issue in data["issues"])
	return "\n".join(lines)


def render_api_index_text(data: dict[str, Any]) -> str:
	lines = [
		f"source: {data['source_root']}",
		f"files: {data['file_count']}",
		f"classes: {data['class_count']}",
		f"public methods: {data['public_method_count']}",
		"modules:",
	]
	for module, stats in sorted(data["modules"].items()):
		lines.append(f"- {module}: classes={stats['classes']} methods={stats['methods']}")
	return "\n".join(lines)


def trim_text(text: str, max_chars: int) -> str:
	if len(text) <= max_chars:
		return text
	return text[-max_chars:]


def indent_text(text: str, prefix: str) -> str:
	lines = text.splitlines()
	if not lines:
		return prefix
	return prefix + ("\n" + " " * len(prefix)).join(lines)


if __name__ == "__main__":
	raise SystemExit(main())
