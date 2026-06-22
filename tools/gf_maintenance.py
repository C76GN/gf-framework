#!/usr/bin/env python3
"""GF maintenance helpers shared by the CLI and the MCP server."""

from __future__ import annotations

import argparse
import concurrent.futures
import configparser
import fnmatch
import functools
import hashlib
import http.server
import json
import os
import posixpath
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import urllib.parse
import xml.etree.ElementTree as ET
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from gdscript_api_parser import ApiDocs
from gdscript_api_parser import ApiMember
from gdscript_api_parser import ApiScript
from gdscript_api_parser import collect_api_scripts


ROOT = Path(__file__).resolve().parents[1]
SEMVER_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
SINCE_VERSION_RE = re.compile(r"@since\s+(?P<version>(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*))")
SINCE_TAG_RE = re.compile(r"@since\s+(?P<value>\S+)")
CHANGELOG_VERSION_RE = re.compile(r"^##\s+\[(?P<version>[^\]]+)\]")
MARKDOWN_FIELD_RE = re.compile(r"^-\s+(?P<name>[^:]+):\s+`(?P<value>[^`]+)`\s*$")
ANSI_ESCAPE_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
API_DOC_API_RE = re.compile(r"##\s*@api\s+(?P<visibility>public|protected)\b")
API_DOC_SINCE_RE = re.compile(r"##\s*@since\s+\S+")
GDSCRIPT_API_DECL_RE = re.compile(
	r"\s*(?:@\w+(?:\([^)]*\))?\s+)*(class_name\s+\w+|signal\s+\w+|enum\s+\w+|const\s+\w+|var\s+\w+|(?:static\s+)?func\s+\w+)"
)
GIT_DIFF_HUNK_RE = re.compile(r"@@ -\d+(?:,\d+)? \+(?P<start>\d+)(?:,(?P<count>\d+))? @@")
RESOURCE_LOAD_LITERAL_RE = re.compile(
	r"\b(?P<callee>preload|load|ResourceLoader\.(?:load|load_interactive|load_threaded_get|load_threaded_request))"
	r"\s*\(\s*(?P<quote>['\"])(?P<target>.*?)(?P=quote)"
)
ASSET_HANDLE_CALL_RE = re.compile(
	r"(?P<callee>(?:[A-Za-z_]\w*\.)?(?:acquire_handle|load_handle_async|request_entry_handle_async))\s*\("
)
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
GDSCRIPT_RELOAD_WARNING_PATTERNS = (
	"GDScript::reload:",
	"The \"await\" keyword is unnecessary",
	"requires the subtype",
	"is shadowing an already-declared",
)
GODOT_EXIT_LEAK_PATTERNS = (
	"objectdb instances leaked at exit",
	"resource still in use at exit",
	"resources still in use at exit",
	"rid allocations",
	"were leaked at exit",
)
PACKAGE_GODOT_SMOKE_DEFAULT_ALL_PACKAGE_JOBS = 4
GODOT_RID_LEAK_RE = re.compile(
	r"^(?:ERROR:\s*)?(?P<count>\d+) RID allocations of type '(?P<type>[^']+)' were leaked at exit\."
)
GODOT_LEAKED_INSTANCE_RE = re.compile(
	r"^Leaked instance: (?P<type>[^:]+):(?P<instance_id>\d+)(?: - Reference count: (?P<reference_count>\d+))?"
)
GODOT_RESOURCE_STILL_IN_USE_RE = re.compile(
	r"^Resource still in use: (?P<path>.+?) \((?P<type>[^)]+)\)"
)
GODOT_RESOURCE_SUMMARY_RE = re.compile(r"^(?:ERROR:\s*)?(?P<count>\d+) resources? still in use at exit\.")
REFERENCE_PROJECT_ENV_VAR = "GF_REFERENCE_PROJECT_PATH"
DEFAULT_REFERENCE_PROJECT = os.environ.get(REFERENCE_PROJECT_ENV_VAR, "../gf-reference-project")
REFERENCE_BOOT_SCENE_ENV_VAR = "GF_REFERENCE_BOOT_SCENE"
REFERENCE_SMOKE_SCENE_ENV_VAR = "GF_REFERENCE_SMOKE_SCENE"
REFERENCE_MANIFEST_NAME = ".gf_reference_project.json"
DEFAULT_REFERENCE_BOOT_SCENE = "res://scenes/app/driftbound_boot.tscn"
DEFAULT_REFERENCE_SMOKE_SCENE = "res://tests/smoke/driftbound_smoke.tscn"
GODOT_LOG_DIR = ROOT / "ai_analysis" / "godot_logs"
GF_KERNEL_ROOT = ROOT / "addons/gf/kernel"
GF_STANDARD_ROOT = ROOT / "addons/gf/standard"
GF_EXTENSIONS_ROOT = ROOT / "addons/gf/extensions"
GF_EXTENSIONS_RES_ROOT = "res://addons/gf/extensions"
GF_STANDARD_RES_ROOT = "res://addons/gf/standard"
GF_ALLOWED_EXTENSION_DEPENDENCIES = ("gf.kernel", "gf.standard")
GF_MANIFEST_ALLOWED_FIELDS = {
	"access_generator_extension_paths",
	"dependencies",
	"description",
	"display_name",
	"editor_action_paths",
	"editor_dock_order",
	"editor_dock_paths",
	"editor_dock_short_label",
	"editor_inspector_paths",
	"enabled_by_default",
	"export_plugin_paths",
	"extension_version",
	"gltf_document_extension_paths",
	"id",
	"import_plugin_paths",
	"installer_paths",
	"kind",
	"tags",
	"version",
}
GF_MANIFEST_FORBIDDEN_RELATION_FIELDS = {
	"after",
	"before",
	"bundle",
	"bundles",
	"conflicts",
	"extension_dependencies",
	"extension_pack",
	"extension_preset",
	"integrates_with",
	"load_after",
	"load_before",
	"optional_dependencies",
	"peer_dependencies",
	"preset",
	"presets",
	"recommends",
	"soft_dependencies",
	"suggests",
}
GF_PRESET_ALLOWED_FIELDS = {
	"description",
	"display_name",
	"extension_ids",
	"id",
	"tags",
}
GF_PRESET_FORBIDDEN_RELATION_FIELDS = {
	"after",
	"before",
	"conflicts",
	"dependencies",
	"depends_on",
	"extension_dependencies",
	"extension_pack",
	"integrates_with",
	"load_after",
	"load_before",
	"optional_dependencies",
	"peer_dependencies",
	"preset",
	"presets",
	"recommends",
	"requires",
	"soft_dependencies",
	"suggests",
}
GF_PRESET_FORBIDDEN_PACKAGE_FIELDS = {
	"archive",
	"checksum",
	"download",
	"download_url",
	"download_urls",
	"downloads",
	"editor_action_paths",
	"external_roots",
	"files",
	"install_script",
	"install_url",
	"installer_paths",
	"installers",
	"manifest_overrides",
	"npm",
	"package",
	"package_id",
	"package_name",
	"packages",
	"registry",
	"repository",
	"sha256",
}
GF_TEXT_BOUNDARY_EXTENSIONS = {
	".cfg",
	".gd",
	".gdshader",
	".json",
	".md",
	".tres",
	".tscn",
	".txt",
}
RESOURCE_BOUNDARY_SCAN_EXTENSIONS = {".gd"}
RESOURCE_BOUNDARY_EXCLUDED_PREFIXES = (
	".git/",
	".godot/",
	".import/",
	"addons/gut/",
	"ai_analysis/",
	"build/",
)
RESOURCE_BOUNDARY_DIRECT_PATH_PREFIXES = ("res://", "uid://", "user://")
RESOURCE_BOUNDARY_EDITOR_METADATA_TARGETS = {
	"res://addons/gf/plugin.cfg",
}
RESOURCE_BOUNDARY_OBSERVATION_KINDS = {
	"direct_editor_metadata_load",
	"direct_script_dependency_load",
}
RESOURCE_BOUNDARY_OBSERVATION_SAMPLE_LIMIT = 12
CONTENT_PACKAGE_MANIFEST_FILE = "gf_content_package.json"
CONTENT_PACKAGE_ALLOWED_FIELDS = {
	"schema_version",
	"package_id",
	"id",
	"display_name",
	"name",
	"version",
	"content_types",
	"dependencies",
	"resources",
	"metadata",
}
CONTENT_PACKAGE_RESOURCE_ALLOWED_FIELDS = {
	"key",
	"resource_key",
	"path",
	"resource_path",
	"type_hint",
	"priority",
	"metadata",
}
ASSET_LIFECYCLE_SCAN_EXTENSIONS = {".gd"}
ASSET_LIFECYCLE_EXCLUDED_PREFIXES = (
	".git/",
	".godot/",
	".import/",
	"addons/gut/",
	"ai_analysis/",
	"build/",
	"tests/",
)
ASSET_HANDLE_METHOD_ARGUMENTS = {
	"acquire_handle": {
		"owner_index": 1,
		"group_index": 2,
		"path_index": 0,
	},
	"load_handle_async": {
		"owner_index": 3,
		"group_index": 4,
		"path_index": 0,
	},
	"request_entry_handle_async": {
		"owner_index": 3,
		"group_index": 4,
		"path_index": 1,
	},
}
PROJECT_PROFILE_DEFAULT_FILES = (
	"gf_project_profile.json",
	".gf/project_profile.json",
	"project_profile.json",
)
PROJECT_PROFILE_ALLOWED_FIELDS = {
	"schema_version",
	"id",
	"display_name",
	"description",
	"zones",
	"rules",
	"metadata",
}
PROJECT_PROFILE_ZONE_ALLOWED_FIELDS = {
	"id",
	"description",
	"roots",
	"required",
	"allow_extensions",
	"deny_extensions",
	"exclude",
	"severity",
	"metadata",
}
PROJECT_PROFILE_RULE_ALLOWED_FIELDS = {
	"id",
	"description",
	"kind",
	"paths",
	"any",
	"roots",
	"include",
	"exclude",
	"extensions",
	"severity",
	"metadata",
}
PROJECT_PROFILE_RULE_KINDS = {
	"path_exists",
	"files_under_roots",
	"extension_allowlist",
	"extension_denylist",
}
PROJECT_PROFILE_SEVERITIES = {"error", "warning", "info"}
PROJECT_PROFILE_SCAN_EXCLUDED_PREFIXES = (
	".git/",
	".godot/",
	".import/",
	"addons/gut/",
	"ai_analysis/",
	"build/",
)
PACKAGE_MANIFEST_ROOT = ROOT / "packages"
PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH = "tests/gf_core/package_focused_gut_mapping.json"
PACKAGE_FOCUSED_GUT_MAPPING_PATH = ROOT / PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH
PACKAGE_FOCUSED_GUT_MAPPING_SCHEMA_VERSION = 1
PACKAGE_FOCUSED_GUT_TEST_ROOT = "res://tests/gf_core/"
PACKAGE_FOCUSED_GUT_ALLOWED_EXTERNAL_PREFIXES = {
	"gf.standard.editor": ("res://tests/gf_core/kernel/editor/",),
}
PACKAGE_USER_DEPENDENCY_BOUNDARY_SCAN_ROOTS = (
	"addons/gf/plugin.gd",
	"addons/gf/kernel/package",
	"addons/gf/kernel/editor/package",
)
PACKAGE_USER_DEPENDENCY_BOUNDARY_SCAN_EXTENSIONS = {".gd"}
PACKAGE_USER_DEPENDENCY_FORBIDDEN_PROCESS_APIS = (
	"OS.execute",
	"OS.create_process",
	"OS.shell_open",
)
PACKAGE_USER_DEPENDENCY_FORBIDDEN_COMMAND_LITERAL_RE = re.compile(
	r"""(?P<quote>["'])(?:python|python3|py|pip|npm|npx|node|git|curl|powershell|pwsh|cmd|cmd\.exe)(?P=quote)""",
	re.IGNORECASE,
)
PACKAGE_USER_DEPENDENCY_FORBIDDEN_PATH_LITERALS = (
	"addons/gf/kernel/package_tools/",
	"tools/gf_package_installer.py",
	"tools/gf_package_resolver.py",
)
PACKAGE_EXTERNAL_COMMAND_AUDIT_PROCESS_CALL_RE = re.compile(
	r"\bOS\.(?P<api>execute|create_process|shell_open)\s*\("
)
PACKAGE_EXTERNAL_COMMAND_AUDIT_SOURCE_EXTENSIONS = {".gd"}
PACKAGE_EXTERNAL_COMMAND_AUDIT_ALLOWED_CALLS = (
	{
		"path": "addons/gf/kernel/editor/gf_editor_workspace_dock.gd",
		"package_id": "gf.kernel",
		"api": "shell_open",
		"command": "",
		"reason": "Editor-only Workspace links open public documentation and release pages.",
	},
)
PACKAGE_SIGNATURE_POLICY_FIELDS = {
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
REGISTRY_SOURCE_UNSUPPORTED_SIGNATURE_FIELDS = PACKAGE_SIGNATURE_POLICY_FIELDS
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
	"enable_extension",
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
} | PACKAGE_SIGNATURE_POLICY_FIELDS
PACKAGE_MANIFEST_KINDS = {"kernel", "standard", "extension", "preset", "tool"}
PACKAGE_MANIFEST_SCHEMA_VERSION = 1
PACKAGE_REGISTRY_SCHEMA_VERSION = 2
PACKAGE_ID_RE = re.compile(r"^(?:gf\.kernel|gf\.(?:standard|extension|preset|tool)\.[a-z0-9_]+(?:\.[a-z0-9_]+)*)$")
PACKAGE_CLOSURE_EXTENSION_TOTAL_WARNING_THRESHOLD = 8
PACKAGE_CLOSURE_EXTENSION_STANDARD_WARNING_THRESHOLD = 6
PACKAGE_CLOSURE_PRESET_TOTAL_INFO_THRESHOLD = 12
PACKAGE_CLOSURE_DEBUG_PACKAGE_ID = "gf.standard.debug"
PACKAGE_CLOSURE_EDITOR_PACKAGE_ID = "gf.standard.editor"
PACKAGE_MANIFEST_SCAN_EXCLUDED_PREFIXES = (
	".git/",
	".godot/",
	".import/",
	"addons/gut/",
	"ai_analysis/",
	"build/",
)
PACKAGE_SOURCE_BOUNDARY_SCAN_EXTENSIONS = {
	".cfg",
	".gd",
	".gdshader",
	".json",
	".tres",
	".tscn",
}
PACKAGED_PACKAGE_TOOL_PAIRS = (
	("tools/gf_package_installer.py", "addons/gf/kernel/package_tools/gf_package_installer.py"),
	("tools/gf_package_resolver.py", "addons/gf/kernel/package_tools/gf_package_resolver.py"),
)
KERNEL_EXCLUDED_PACKAGE_TOOL_PATHS = tuple(packaged_path for _source_path, packaged_path in PACKAGED_PACKAGE_TOOL_PAIRS)
RUNTIME_PACKAGE_FORBIDDEN_EXTERNAL_TOOL_SUFFIXES = {
	".bash",
	".bat",
	".cmd",
	".ps1",
	".py",
	".pyw",
	".sh",
	".zsh",
}
RUNTIME_PACKAGE_FORBIDDEN_EXTERNAL_TOOL_FILES = {
	"npm-shrinkwrap.json",
	"package-lock.json",
	"package.json",
	"pipfile",
	"pipfile.lock",
	"pnpm-lock.yaml",
	"poetry.lock",
	"pyproject.toml",
	"requirements.txt",
	"yarn.lock",
}
PACKAGE_SOURCE_OPTIONAL_REFERENCES = {
	(
		"gf.kernel",
		"addons/gf/plugin.gd",
		"addons/gf/standard/editor/gf_standard_editor_extensions.gd",
	),
}
GF_EXTENSION_INFRASTRUCTURE_PATHS = {
	"addons/gf/kernel/extension/gf_extension_catalog.gd",
	"addons/gf/kernel/extension/gf_extension_usage_audit.gd",
}
GF_EXTENSION_FORBIDDEN_GLOBAL_FACADE = "Gf."
PUBLIC_API_BOUNDARY_FORBIDDEN_TERMS = {
	"GFDeterministicMath": "Planning track names must not become public API classes, catalog modules, or generated reference entries.",
	"GFExtensionPackageManager": "Planning track names must not become public API classes, catalog modules, or generated reference entries.",
	"GFPathfinding2D": "Planning track names must not become public API classes, catalog modules, or generated reference entries.",
}
PUBLIC_API_BOUNDARY_ROOTS = (
	("addons/gf", {".gd"}),
	("docs/api_catalog", {".xml"}),
	("docs/zh/reference/api", {".md"}),
)
PUBLIC_DOC_BOUNDARY_EXPLICIT_FILES = (
	"README.md",
	"README.zh.md",
	"ASSET_LIBRARY.md",
	"ASSET_STORE.md",
	"addons/gf/README.md",
	"addons/gf/extensions/README.md",
)
PUBLIC_DOC_BOUNDARY_ROOTS = (
	"docs/zh",
	"docs/wiki",
)
PUBLIC_DOC_BOUNDARY_EXCLUDED_PREFIXES = (
	"docs/zh/reference/api/",
)
PUBLIC_DOC_BOUNDARY_FORBIDDEN_TERMS = {
	"@gamex": "External package names from comparison research must stay in ai_analysis, not public docs.",
	"AI_MAINTENANCE.md": "AI maintenance policy is internal and must not be advertised in public docs.",
	"Codex": "AI assistant implementation details must stay out of public docs.",
	"MCP": "AI maintenance infrastructure must stay out of public docs.",
	"XForge": "External framework comparison notes must stay in ai_analysis, not public docs.",
	"ai_analysis": "AI workspace paths must stay out of public docs.",
	"godot_logs": "Local maintenance log paths must stay out of public docs.",
	"npm run package": "External package manager workflow notes must stay in ai_analysis, not public docs.",
	**{
		term: "Planning track names must not be documented as shipped public modules."
		for term in PUBLIC_API_BOUNDARY_FORBIDDEN_TERMS
	},
}
PUBLIC_DOC_BOUNDARY_PATTERNS: list[tuple[str, re.Pattern[str], str]] = [
	(
		"optional_extension_workspace_page_as_core_page",
		re.compile(
			r"(?:GF Workspace|Workspace|工作区).{0,80}(?:包含|固定页面|fixed pages|always provides|includes|contains).{0,80}(?:SaveGraph|存档图|存档文件查看|Flow|流程图)",
			re.IGNORECASE,
		),
		"Workspace docs must not describe optional extension pages as fixed core pages.",
	),
	(
		"optional_extension_as_core_editor_tool",
		re.compile(r"GF includes editor support.{0,140}SaveGraph diagnostics", re.IGNORECASE),
		"README editor-tool summaries must distinguish core editor tools from optional extension contributions.",
	),
	(
		"optional_extension_as_core_editor_tool",
		re.compile(r"GF 提供.{0,140}SaveGraph 诊断"),
		"README editor-tool summaries must distinguish core editor tools from optional extension contributions.",
	),
]
PUBLIC_DOC_PACKAGE_MANAGER_TOOL_PATH_RE = re.compile(
	r"\btools[\\/]+gf_package_(?:installer|resolver)\.py\b",
	re.IGNORECASE,
)
PUBLIC_DOC_USER_INSTALL_CONCEPT_RE = re.compile(
	r"(?:install(?:ing)?\s+(?:a\s+)?(?:gf\s+)?(?:extension|package|preset)|"
	r"package\s+manager|extension\s+install|package\s+install|"
	r"安装.{0,16}(?:扩展|包|preset)|包管理|扩展安装|包安装)",
	re.IGNORECASE,
)
PUBLIC_DOC_EXTERNAL_TOOL_RE = re.compile(
	r"\b(?:python|pip|npm|npx|node|git)\b",
	re.IGNORECASE,
)
PUBLIC_DOC_EXTERNAL_TOOL_REQUIREMENT_RE = re.compile(
	r"(?:requires?|required|must|need(?:s|ed)?|depends?\s+on|dependency|"
	r"必须|需要|依赖|前置条件|必备)",
	re.IGNORECASE,
)
PUBLIC_DOC_EXTERNAL_TOOL_NEGATION_RE = re.compile(
	r"(?:does\s+not\s+require|do\s+not\s+need|without|not\s+a\s+requirement|"
	r"not\s+required|only\s+when\s+building\s+the\s+documentation|"
	r"no-python|不需要|无需|不依赖|不能成为|不是.*前置|只.*维护|只.*本地构建|减少)",
	re.IGNORECASE,
)
PUBLIC_DOC_PACKAGE_SIGNATURE_CLAIM_RE = re.compile(
	r"(?:"
	r"(?:package|packages|registry|registries|archive|archives|download|downloads|"
	r"release|releases|extension|extensions|preset|presets).{0,80}"
	r"(?:signature\s+verification|verified\s+signature|signature\s+verified|"
	r"signatures?\s+(?:are\s+)?verified|signed|trusted|authentic)|"
	r"(?:signature\s+verification|verified\s+signature|signature\s+verified|"
	r"signatures?\s+(?:are\s+)?verified|signed|trusted|authentic).{0,80}"
	r"(?:package|packages|registry|registries|archive|archives|download|downloads|"
	r"release|releases|extension|extensions|preset|presets)|"
	r"(?:GF\s*包|扩展包|资源包|内容包|package|扩展|预设|registry|注册表|索引|归档|下载|发布|安装).{0,80}"
	r"(?:签名验证|签名校验|验签|签名已验证|已验证签名|可信|受信任)|"
	r"(?:签名验证|签名校验|验签|签名已验证|已验证签名|可信|受信任).{0,80}"
	r"(?:GF\s*包|扩展包|资源包|内容包|package|扩展|预设|registry|注册表|索引|归档|下载|发布|安装)"
	r")",
	re.IGNORECASE,
)
PUBLIC_DOC_PACKAGE_SIGNATURE_NEGATION_RE = re.compile(
	r"(?:not\s+(?:implemented|yet|supported|verified|trusted)|"
	r"until.{0,80}(?:native|Godot-native).{0,80}(?:verification|verifier)|"
	r"before.{0,80}(?:verification|verifier).{0,80}exists|"
	r"must\s+(?:fail|be\s+rejected)|reject(?:ed|s|ing)?|unsupported|"
	r"does\s+not\s+(?:claim|verify|trust)|no\s+signature\s+verification|"
	r"未实现|尚未|拒绝|不支持|不能.{0,40}静默|不会.{0,40}静默|"
	r"不声称|实现前|没有.{0,40}验签|未完成)",
	re.IGNORECASE,
)
GF_RELEASE_DOWNLOAD_BASE_URL = "https://github.com/C76GN/gf-framework/releases/download"


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


def godot_log_path(check_name: str) -> str:
	return (GODOT_LOG_DIR / f"{check_name}.log").as_posix()


CHECK_DEFINITIONS: dict[str, list[str]] = {
	"gut": [
		"godot",
		"--headless",
		"--log-file",
		godot_log_path("gut"),
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
		"--check-or-generate",
		"--check-wiki-coverage",
	],
	"docs": [sys.executable, "tools/check_docs_quality.py", "--strict"],
	"public_docs_boundary": [sys.executable, "tools/gf_maintenance.py", "public-docs-boundary"],
	"public_api_boundary": [sys.executable, "tools/gf_maintenance.py", "public-api-boundary"],
	"resource_boundary": [sys.executable, "tools/gf_maintenance.py", "resource-boundary", "--fail-on-issues"],
	"content_package_boundary": [sys.executable, "tools/gf_maintenance.py", "content-package-boundary"],
	"asset_lifecycle_boundary": [sys.executable, "tools/gf_maintenance.py", "asset-lifecycle-boundary"],
	"project_profile_boundary": [sys.executable, "tools/gf_maintenance.py", "project-profile-boundary"],
	"package_boundary": [sys.executable, "tools/gf_maintenance.py", "package-boundary"],
	"package_closure_audit": [sys.executable, "tools/gf_maintenance.py", "package-closure-audit"],
	"package_source_boundary": [sys.executable, "tools/gf_maintenance.py", "package-source-boundary"],
	"package_build_boundary": [sys.executable, "tools/gf_maintenance.py", "package-build-boundary"],
	"package_user_dependency_boundary": [sys.executable, "tools/gf_maintenance.py", "package-user-dependency-boundary"],
	"package_external_command_audit": [sys.executable, "tools/gf_maintenance.py", "package-external-command-audit", "--fail-on-warnings"],
	"core_only_smoke": [sys.executable, "tools/gf_maintenance.py", "core-only-smoke"],
	"package_install_smoke": [sys.executable, "tools/gf_maintenance.py", "package-install-smoke"],
	"network_install_smoke": [sys.executable, "tools/gf_maintenance.py", "network-install-smoke"],
	"preset_smoke": [sys.executable, "tools/gf_maintenance.py", "preset-smoke"],
	"package_manager_status_smoke": [sys.executable, "tools/gf_maintenance.py", "package-manager-status-smoke"],
	"package_native_parity_smoke": [sys.executable, "tools/gf_maintenance.py", "package-native-parity-smoke"],
	"package_editor_wizard_smoke": [sys.executable, "tools/gf_maintenance.py", "package-editor-wizard-smoke"],
	"package_focused_gut_mapping": [sys.executable, "tools/gf_maintenance.py", "package-focused-gut-mapping"],
	"package_godot_cli_smoke": [sys.executable, "tools/gf_maintenance.py", "package-godot-cli-smoke"],
	"package_godot_smoke": [sys.executable, "tools/gf_maintenance.py", "package-godot-smoke"],
	"package_godot_matrix_smoke": [sys.executable, "tools/gf_maintenance.py", "package-godot-smoke", "--all-packages"],
	"uninstall_smoke": [sys.executable, "tools/gf_maintenance.py", "uninstall-smoke"],
	"mkdocs": [sys.executable, "-m", "mkdocs", "build", "--strict"],
	"api_since_touched": [sys.executable, "tools/gf_maintenance.py", "api-since-touched"],
	"path_hygiene": [sys.executable, "tools/gf_maintenance.py", "path-hygiene"],
	"dependency_boundary": [sys.executable, "tools/gf_maintenance.py", "dependency-boundary"],
	"maintenance_self_test": [sys.executable, "tools/gf_maintenance.py", "maintenance-self-test"],
	"gdscript_warnings": [
		"godot",
		"--headless",
		"--log-file",
		godot_log_path("gdscript_warnings"),
		"--path",
		".",
		"--editor",
		"--quit",
	],
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
		"--log-file",
		godot_log_path("examples_scan"),
		"--path",
		DEFAULT_REFERENCE_PROJECT,
		"--editor",
		"--quit-after",
		"2",
	],
	"examples_boot": [
		"godot",
		"--headless",
		"--log-file",
		godot_log_path("examples_boot"),
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
		"--log-file",
		godot_log_path("examples_smoke"),
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
		"--check",
	],
}

API_CHECKS: list[str] = ["api", "ai_api", "public_api_boundary"]
DOCS_CHECKS: list[str] = ["docs", "public_docs_boundary", "mkdocs"]
EXAMPLES_CHECKS: list[str] = [
	"examples_sync",
	"examples_scan",
	"examples_boot",
	"examples_smoke",
	"examples_coverage",
]
LIGHT_BOUNDARY_CHECKS: list[str] = [
	"resource_boundary",
	"content_package_boundary",
	"asset_lifecycle_boundary",
	"project_profile_boundary",
	"package_boundary",
	"package_closure_audit",
	"package_source_boundary",
	"package_user_dependency_boundary",
	"package_external_command_audit",
	"core_only_smoke",
	"package_focused_gut_mapping",
	"api_since_touched",
	"path_hygiene",
	"maintenance_self_test",
	"dependency_boundary",
	"diff",
]
PACKAGE_SMOKE_CHECKS: list[str] = [
	"package_build_boundary",
	"package_install_smoke",
	"network_install_smoke",
	"preset_smoke",
	"package_manager_status_smoke",
	"package_native_parity_smoke",
	"package_editor_wizard_smoke",
	"package_godot_cli_smoke",
	"uninstall_smoke",
]
PACKAGE_CHECKS: list[str] = [
	"package_boundary",
	"package_closure_audit",
	"package_source_boundary",
	"package_user_dependency_boundary",
	"package_external_command_audit",
	"core_only_smoke",
	"package_focused_gut_mapping",
	*PACKAGE_SMOKE_CHECKS,
]
QUICK_CHECKS: list[str] = [
	"api",
	"ai_api",
	"docs",
	"public_docs_boundary",
	"public_api_boundary",
	*LIGHT_BOUNDARY_CHECKS,
]
FULL_CHECKS: list[str] = [
	"gut",
	"api",
	"ai_api",
	"docs",
	"public_docs_boundary",
	"public_api_boundary",
	"resource_boundary",
	"content_package_boundary",
	"asset_lifecycle_boundary",
	"project_profile_boundary",
	*PACKAGE_CHECKS,
	"package_godot_smoke",
	"mkdocs",
	"api_since_touched",
	"path_hygiene",
	"maintenance_self_test",
	"dependency_boundary",
	"gdscript_warnings",
	"diff",
]
RELEASE_CHECKS: list[str] = [
	"gut",
	"api",
	"ai_api",
	"docs",
	"public_docs_boundary",
	"public_api_boundary",
	"resource_boundary",
	"content_package_boundary",
	"asset_lifecycle_boundary",
	"project_profile_boundary",
	*PACKAGE_CHECKS,
	"package_godot_matrix_smoke",
	"mkdocs",
	"api_since_touched",
	"path_hygiene",
	"maintenance_self_test",
	"dependency_boundary",
	"gdscript_warnings",
	"diff",
	"release_metadata",
]

CHECK_SUITES: dict[str, list[str]] = {
	"api": API_CHECKS,
	"docs": DOCS_CHECKS,
	"examples": EXAMPLES_CHECKS,
	"quick": QUICK_CHECKS,
	"package": PACKAGE_CHECKS,
	"full": FULL_CHECKS,
	"release": RELEASE_CHECKS,
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
	godot_exit_leak_warnings: list[str] | None = None
	godot_exit_leak_report: dict[str, Any] | None = None
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
		if self.godot_exit_leak_warnings:
			payload["godot_exit_leak_warning_count"] = len(self.godot_exit_leak_warnings)
			payload["godot_exit_leak_warnings"] = self.godot_exit_leak_warnings[:20]
		if self.godot_exit_leak_report:
			payload["godot_exit_leak_report"] = self.godot_exit_leak_report
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

	path_hygiene_parser = subparsers.add_parser("path-hygiene", help="Check tracked and untracked repository paths for cross-platform hazards.")
	path_hygiene_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	api_since_touched_parser = subparsers.add_parser(
		"api-since-touched",
		help="Check changed public/protected API documentation blocks for @since tags.",
	)
	api_since_touched_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	dependency_boundary_parser = subparsers.add_parser(
		"dependency-boundary",
		help="Check GF layer, extension manifest, and bundled extension dependency boundaries.",
	)
	dependency_boundary_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	public_docs_boundary_parser = subparsers.add_parser(
		"public-docs-boundary",
		help="Check public docs for internal planning leaks and optional-extension boundary claims.",
	)
	public_docs_boundary_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	public_api_boundary_parser = subparsers.add_parser(
		"public-api-boundary",
		help="Check public API source and generated references for planning-route names.",
	)
	public_api_boundary_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	resource_boundary_parser = subparsers.add_parser(
		"resource-boundary",
		help="Report direct resource load literals before turning project resource boundaries into hard gates.",
	)
	resource_boundary_parser.add_argument(
		"--fail-on-issues",
		action="store_true",
		help="Return a failing exit code when any direct resource load issue is found. Default is report-only.",
	)
	resource_boundary_parser.add_argument(
		"--include-observations",
		action="store_true",
		help="Include full script-dependency and editor-metadata observation records in JSON output.",
	)
	resource_boundary_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	content_package_boundary_parser = subparsers.add_parser(
		"content-package-boundary",
		help="Check content package manifests for package graph and resource-root boundary violations.",
	)
	content_package_boundary_parser.add_argument(
		"--check-resource-exists",
		action="store_true",
		help="Also require every manifest resource path to exist in the project.",
	)
	content_package_boundary_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	asset_lifecycle_boundary_parser = subparsers.add_parser(
		"asset-lifecycle-boundary",
		help="Report GFAssetHandle acquisition calls without explicit owner or group lifecycle anchors.",
	)
	asset_lifecycle_boundary_parser.add_argument(
		"--fail-on-warnings",
		action="store_true",
		help="Return a failing exit code when ownerless ungrouped asset handle calls are found. Default is report-only.",
	)
	asset_lifecycle_boundary_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	project_profile_boundary_parser = subparsers.add_parser(
		"project-profile-boundary",
		help="Check an optional project structure profile without hardcoding a GF project layout.",
	)
	project_profile_boundary_parser.add_argument(
		"--profile",
		default="",
		help="Profile JSON path. Defaults to gf_project_profile.json, .gf/project_profile.json, or project_profile.json when present.",
	)
	project_profile_boundary_parser.add_argument(
		"--fail-on-warnings",
		action="store_true",
		help="Return a failing exit code when warning-level profile issues are found.",
	)
	project_profile_boundary_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	package_boundary_parser = subparsers.add_parser(
		"package-boundary",
		help="Check GF package manifests for schema, path ownership, and dependency graph violations.",
	)
	package_boundary_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	package_closure_audit_parser = subparsers.add_parser(
		"package-closure-audit",
		help="Report GF package install closures, standard fan-in, and oversized extension dependency risk.",
	)
	package_closure_audit_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	package_source_boundary_parser = subparsers.add_parser(
		"package-source-boundary",
		help="Check GF package-owned source files for undeclared package path and class references.",
	)
	package_source_boundary_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	package_build_boundary_parser = subparsers.add_parser(
		"package-build-boundary",
		help="Build all modular GF package archives in a temp directory and validate the generated registry.",
	)
	package_build_boundary_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	package_user_dependency_boundary_parser = subparsers.add_parser(
		"package-user-dependency-boundary",
		help="Check user-facing package manager scripts for external CLI dependencies.",
	)
	package_user_dependency_boundary_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	package_external_command_audit_parser = subparsers.add_parser(
		"package-external-command-audit",
		help="Report OS external command calls in package-owned GF source.",
	)
	package_external_command_audit_parser.add_argument(
		"--fail-on-warnings",
		action="store_true",
		help="Return a failing exit code when package-owned external command calls are found. Default is report-only.",
	)
	package_external_command_audit_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	core_only_smoke_parser = subparsers.add_parser(
		"core-only-smoke",
		help="Check that the root plugin entry does not require standard packages at parse time.",
	)
	core_only_smoke_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	package_install_smoke_parser = subparsers.add_parser(
		"package-install-smoke",
		help="Smoke-test local package archive install staging, checksum validation, and rollback.",
	)
	package_install_smoke_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	network_install_smoke_parser = subparsers.add_parser(
		"network-install-smoke",
		help="Smoke-test HTTP registry package install, download cache, checksum validation, and rollback.",
	)
	network_install_smoke_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	preset_smoke_parser = subparsers.add_parser(
		"preset-smoke",
		help="Smoke-test preset registry entries, install closure, lockfile pins, and uninstall pruning.",
	)
	preset_smoke_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	package_manager_status_smoke_parser = subparsers.add_parser(
		"package-manager-status-smoke",
		help="Smoke-test the package manager status JSON used by editor install wizards.",
	)
	package_manager_status_smoke_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	package_native_parity_smoke_parser = subparsers.add_parser(
		"package-native-parity-smoke",
		help="Compare Python maintenance installer status with the Godot-native package CLI status contract.",
	)
	package_native_parity_smoke_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	package_editor_wizard_smoke_parser = subparsers.add_parser(
		"package-editor-wizard-smoke",
		help="Smoke-test the editor package manager wizard dock with focused GUT coverage.",
	)
	package_editor_wizard_smoke_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	package_focused_gut_mapping_parser = subparsers.add_parser(
		"package-focused-gut-mapping",
		help="Validate the package-to-focused-GUT coverage mapping used by maintenance gates.",
	)
	package_focused_gut_mapping_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	package_godot_cli_smoke_parser = subparsers.add_parser(
		"package-godot-cli-smoke",
		help="Smoke-test the Godot-native package CLI without requiring Python on the user install path.",
	)
	package_godot_cli_smoke_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	package_godot_smoke_parser = subparsers.add_parser(
		"package-godot-smoke",
		help="Install package closures into temp projects and check Godot editor parse/reload output.",
	)
	package_godot_smoke_parser.add_argument(
		"--all-packages",
		action="store_true",
		help="Check every package in the generated registry instead of representative roots.",
	)
	package_godot_smoke_parser.add_argument(
		"--package",
		action="append",
		dest="package_ids",
		default=[],
		help="Check one package id from the generated registry. May be passed more than once.",
	)
	package_godot_smoke_parser.add_argument(
		"--jobs",
		type=int,
		default=0,
		help=(
			"Number of package parse scenarios to run concurrently. "
			"Default: 4 for --all-packages, 1 otherwise."
		),
	)
	package_godot_smoke_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	uninstall_smoke_parser = subparsers.add_parser(
		"uninstall-smoke",
		help="Smoke-test package resolver lockfile and uninstall safety rules.",
	)
	uninstall_smoke_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	maintenance_self_test_parser = subparsers.add_parser(
		"maintenance-self-test",
		help="Run self-tests for maintenance rule fixtures.",
	)
	maintenance_self_test_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	exit_leak_parser = subparsers.add_parser(
		"godot-exit-leak-report",
		help="Summarize Godot exit ObjectDB/resource/RID leak warnings from log files.",
	)
	exit_leak_parser.add_argument(
		"--log",
		action="append",
		default=[],
		help="Log file to parse. Can be passed multiple times.",
	)
	exit_leak_parser.add_argument(
		"--fail-on-leaks",
		action="store_true",
		help="Return a failing exit code when any exit leak category is present.",
	)
	exit_leak_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

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
	check_parser.add_argument(
		"--failed-only",
		action="store_true",
		help="When printing text, show only failed check details and a compact pass summary.",
	)
	check_parser.add_argument(
		"--github-annotations",
		action="store_true",
		help="Emit GitHub Actions error annotations for failed checks.",
	)
	check_parser.add_argument(
		"--allow-breaking-api",
		action="store_true",
		help="Allow explicitly approved breaking API baseline changes in the release_metadata check.",
	)
	check_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	release_parser = subparsers.add_parser("release-status", help="Check release metadata consistency.")
	release_parser.add_argument("--version", default="", help="Expected SemVer. Defaults to plugin.cfg version.")
	release_parser.add_argument(
		"--allow-dirty",
		action="store_true",
		help="Allow local diagnostics on a dirty worktree. Never use for release packaging.",
	)
	release_parser.add_argument(
		"--allow-breaking-api",
		action="store_true",
		help="Allow explicitly approved breaking API baseline changes without requiring a major version bump.",
	)
	release_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	api_index_parser = subparsers.add_parser("api-index", help="Print compact GF API index statistics.")
	api_index_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	api_baseline_parser = subparsers.add_parser(
		"api-baseline-diff",
		help="Compare the current generated API Catalog against a release tag.",
	)
	api_baseline_parser.add_argument("--base-tag", default="", help="Base SemVer tag. Defaults to the latest tag lower than --version.")
	api_baseline_parser.add_argument("--version", default="", help="Expected release SemVer. Defaults to plugin.cfg version.")
	api_baseline_parser.add_argument(
		"--enforce-version",
		action="store_true",
		help="Fail when breaking API changes are present without a major version bump.",
	)
	api_baseline_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

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
	if args.command == "path-hygiene":
		data = path_hygiene()
		print_output(data, args.json, render_path_hygiene_text)
		return 0 if data["ok"] else 1
	if args.command == "api-since-touched":
		data = api_since_touched()
		print_output(data, args.json, render_api_since_touched_text)
		return 0 if data["ok"] else 1
	if args.command == "dependency-boundary":
		data = dependency_boundary()
		print_output(data, args.json, render_dependency_boundary_text)
		return 0 if data["ok"] else 1
	if args.command == "public-docs-boundary":
		data = public_docs_boundary()
		print_output(data, args.json, render_public_docs_boundary_text)
		return 0 if data["ok"] else 1
	if args.command == "public-api-boundary":
		data = public_api_boundary()
		print_output(data, args.json, render_public_api_boundary_text)
		return 0 if data["ok"] else 1
	if args.command == "resource-boundary":
		data = resource_boundary(
			fail_on_issues=args.fail_on_issues,
			include_observations=args.include_observations,
		)
		print_output(data, args.json, render_resource_boundary_text)
		return 0 if data["ok"] else 1
	if args.command == "content-package-boundary":
		data = content_package_boundary(check_resource_exists=args.check_resource_exists)
		print_output(data, args.json, render_content_package_boundary_text)
		return 0 if data["ok"] else 1
	if args.command == "asset-lifecycle-boundary":
		data = asset_lifecycle_boundary(fail_on_warnings=args.fail_on_warnings)
		print_output(data, args.json, render_asset_lifecycle_boundary_text)
		return 0 if data["ok"] else 1
	if args.command == "project-profile-boundary":
		data = project_profile_boundary(
			profile_path=args.profile,
			fail_on_warnings=args.fail_on_warnings,
		)
		print_output(data, args.json, render_project_profile_boundary_text)
		return 0 if data["ok"] else 1
	if args.command == "package-boundary":
		data = package_boundary()
		print_output(data, args.json, render_package_boundary_text)
		return 0 if data["ok"] else 1
	if args.command == "package-closure-audit":
		data = package_closure_audit()
		print_output(data, args.json, render_package_closure_audit_text)
		return 0 if data["ok"] else 1
	if args.command == "package-source-boundary":
		data = package_source_boundary()
		print_output(data, args.json, render_package_source_boundary_text)
		return 0 if data["ok"] else 1
	if args.command == "package-build-boundary":
		data = package_build_boundary()
		print_output(data, args.json, render_package_build_boundary_text)
		return 0 if data["ok"] else 1
	if args.command == "package-user-dependency-boundary":
		data = package_user_dependency_boundary()
		print_output(data, args.json, render_package_user_dependency_boundary_text)
		return 0 if data["ok"] else 1
	if args.command == "package-external-command-audit":
		data = package_external_command_audit(fail_on_warnings=args.fail_on_warnings)
		print_output(data, args.json, render_package_external_command_audit_text)
		return 0 if data["ok"] else 1
	if args.command == "core-only-smoke":
		data = core_only_smoke()
		print_output(data, args.json, render_core_only_smoke_text)
		return 0 if data["ok"] else 1
	if args.command == "package-install-smoke":
		data = package_install_smoke()
		print_output(data, args.json, render_package_install_smoke_text)
		return 0 if data["ok"] else 1
	if args.command == "network-install-smoke":
		data = network_install_smoke()
		print_output(data, args.json, render_network_install_smoke_text)
		return 0 if data["ok"] else 1
	if args.command == "preset-smoke":
		data = preset_smoke()
		print_output(data, args.json, render_preset_smoke_text)
		return 0 if data["ok"] else 1
	if args.command == "package-manager-status-smoke":
		data = package_manager_status_smoke()
		print_output(data, args.json, render_package_manager_status_smoke_text)
		return 0 if data["ok"] else 1
	if args.command == "package-native-parity-smoke":
		data = package_native_parity_smoke()
		print_output(data, args.json, render_package_native_parity_smoke_text)
		return 0 if data["ok"] else 1
	if args.command == "package-editor-wizard-smoke":
		data = package_editor_wizard_smoke()
		print_output(data, args.json, render_package_editor_wizard_smoke_text)
		return 0 if data["ok"] else 1
	if args.command == "package-focused-gut-mapping":
		data = package_focused_gut_mapping()
		print_output(data, args.json, render_package_focused_gut_mapping_text)
		return 0 if data["ok"] else 1
	if args.command == "package-godot-cli-smoke":
		data = package_godot_cli_smoke()
		print_output(data, args.json, render_package_godot_cli_smoke_text)
		return 0 if data["ok"] else 1
	if args.command == "package-godot-smoke":
		data = package_godot_smoke(
			all_packages=args.all_packages,
			package_ids=args.package_ids,
			jobs=args.jobs,
		)
		print_output(data, args.json, render_package_godot_smoke_text)
		return 0 if data["ok"] else 1
	if args.command == "uninstall-smoke":
		data = uninstall_smoke()
		print_output(data, args.json, render_uninstall_smoke_text)
		return 0 if data["ok"] else 1
	if args.command == "maintenance-self-test":
		data = maintenance_self_test()
		print_output(data, args.json, render_maintenance_self_test_text)
		return 0 if data["ok"] else 1
	if args.command == "godot-exit-leak-report":
		data = godot_exit_leak_report(args.log)
		print_output(data, args.json, render_godot_exit_leak_report_text)
		if not data["ok"]:
			return 1
		if args.fail_on_leaks and data["has_leaks"]:
			return 1
		return 0
	if args.command == "check":
		data = run_checks(
			suite=args.suite,
			checks=args.check,
			timeout_seconds=args.timeout,
			fail_fast=args.fail_fast,
			sync_examples=args.sync_examples,
			allow_breaking_api=args.allow_breaking_api,
		)
		renderer = render_failed_checks_text if args.failed_only else render_checks_text
		print_output(data, args.json, renderer)
		if args.github_annotations:
			print_github_check_annotations(data)
		return 0 if data["ok"] else 1
	if args.command == "release-status":
		data = release_status(
			args.version,
			allow_dirty=args.allow_dirty,
			allow_breaking_api=args.allow_breaking_api,
		)
		print_output(data, args.json, render_release_status_text)
		return 0 if data["ok"] else 1
	if args.command == "api-index":
		data = api_index()
		print_output(data, args.json, render_api_index_text)
		return 0
	if args.command == "api-baseline-diff":
		data = api_baseline_diff(args.base_tag, args.version, enforce_version=args.enforce_version)
		print_output(data, args.json, render_api_baseline_diff_text)
		return 0 if data["ok"] else 1
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


def api_baseline_diff(
	base_tag: str = "",
	version: str = "",
	enforce_version: bool = False,
) -> dict[str, Any]:
	release_version = version.strip() or read_plugin_version()
	resolved_base_tag = base_tag.strip() or find_latest_semver_tag_before(release_version)
	issues: list[str] = []
	if not resolved_base_tag:
		issues.append("Could not resolve a base SemVer tag for API baseline comparison.")
		return make_api_baseline_diff_result(
			release_version,
			resolved_base_tag,
			enforce_version,
			issues,
			{},
			{},
		)

	base_snapshot = read_api_catalog_snapshot_from_git(resolved_base_tag)
	current_snapshot = read_api_catalog_snapshot_from_workspace()
	for snapshot_name, snapshot in (("base", base_snapshot), ("current", current_snapshot)):
		for error in snapshot.get("errors", []):
			issues.append(f"{snapshot_name} API catalog error: {error}")

	diff = compare_api_catalog_snapshots(base_snapshot, current_snapshot)
	classified_signature_changes = classify_api_signature_changes(diff.get("signature_changes", []))
	diff["breaking_signature_changes"] = classified_signature_changes["breaking"]
	diff["compatible_signature_changes"] = classified_signature_changes["compatible"]
	breaking_change_count = (
		len(diff["removed_classes"])
		+ len(diff["removed_members"])
		+ len(diff["breaking_signature_changes"])
		+ len(diff["extends_changes"])
	)
	breaking_allowed = api_diff_breaking_allowed(resolved_base_tag, release_version)
	if enforce_version and breaking_change_count > 0 and not breaking_allowed:
		issues.append(
			"Breaking public API changes require a major version bump above "
			f"{resolved_base_tag}; found {breaking_change_count} breaking change(s)."
		)
	return make_api_baseline_diff_result(
		release_version,
		resolved_base_tag,
		enforce_version,
		issues,
		diff,
		{
			"breaking_change_count": breaking_change_count,
			"breaking_allowed": breaking_allowed,
		},
	)


def make_api_baseline_diff_result(
	release_version: str,
	base_tag: str,
	enforce_version: bool,
	issues: list[str],
	diff: dict[str, Any],
	extra: dict[str, Any],
) -> dict[str, Any]:
	summary = {
		"added_classes": len(diff.get("added_classes", [])),
		"removed_classes": len(diff.get("removed_classes", [])),
		"added_members": len(diff.get("added_members", [])),
		"removed_members": len(diff.get("removed_members", [])),
		"signature_changes": len(diff.get("signature_changes", [])),
		"breaking_signature_changes": len(diff.get("breaking_signature_changes", [])),
		"compatible_signature_changes": len(diff.get("compatible_signature_changes", [])),
		"extends_changes": len(diff.get("extends_changes", [])),
		"breaking_change_count": int(extra.get("breaking_change_count", 0)),
		"breaking_allowed": bool(extra.get("breaking_allowed", False)),
	}
	return {
		"ok": len(issues) == 0,
		"root": str(ROOT),
		"base_tag": base_tag,
		"version": release_version,
		"enforce_version": enforce_version,
		"issues": issues,
		"summary": summary,
		"diff": diff,
	}


def classify_api_signature_changes(changes: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
	breaking: list[dict[str, Any]] = []
	compatible: list[dict[str, Any]] = []
	for change in changes:
		reason = api_signature_compatible_change_reason(change)
		enriched = dict(change)
		if reason:
			enriched["compatibility"] = reason
			compatible.append(enriched)
		else:
			enriched["compatibility"] = "breaking_or_unknown"
			breaking.append(enriched)
	return {
		"breaking": breaking,
		"compatible": compatible,
	}


def api_signature_compatible_change_reason(change: dict[str, Any]) -> str:
	kind = str(change.get("kind", ""))
	old_signature = str(change.get("old_signature", ""))
	new_signature = str(change.get("new_signature", ""))
	if kind == "enum" and api_enum_signature_is_compatible(old_signature, new_signature):
		return "enum_values_added_without_removing_existing_values"
	if kind != "method":
		return ""
	old_method = parse_api_method_signature(old_signature)
	new_method = parse_api_method_signature(new_signature)
	if not old_method or not new_method:
		return ""
	if old_method.get("return_type", "") != new_method.get("return_type", ""):
		return ""
	old_params: list[dict[str, str]] = old_method.get("params", [])
	new_params: list[dict[str, str]] = new_method.get("params", [])
	if len(new_params) < len(old_params):
		return ""
	for index, old_param in enumerate(old_params):
		new_param = new_params[index]
		if old_param.get("name", "") != new_param.get("name", ""):
			return ""
		if not api_parameter_type_change_is_compatible(old_param.get("type", ""), new_param.get("type", "")):
			return ""
	for new_param in new_params[len(old_params):]:
		if not new_param.get("default", ""):
			return ""
	if len(new_params) > len(old_params):
		return "optional_parameters_added"
	if any(
		old_params[index].get("type", "") != new_params[index].get("type", "")
		for index in range(len(old_params))
	):
		return "parameter_types_widened"
	return ""


def api_parameter_type_change_is_compatible(old_type: str, new_type: str) -> bool:
	if old_type == new_type:
		return True
	if old_type and (new_type == "" or new_type == "Variant"):
		return True
	return False


def parse_api_method_signature(signature: str) -> dict[str, Any]:
	match = re.match(
		r"^(?:static\s+)?func\s+(?P<name>\w+)\((?P<params>.*)\)\s*(?:->\s*(?P<return>[^:]+))?:$",
		signature,
	)
	if match is None:
		return {}
	return {
		"name": match.group("name"),
		"params": [
			parse_api_parameter(part)
			for part in split_top_level_commas(match.group("params").strip())
			if part.strip()
		],
		"return_type": (match.group("return") or "").strip(),
	}


def parse_api_parameter(source: str) -> dict[str, str]:
	left, default = split_once_top_level(source, "=")
	name_part, type_part = split_once_top_level(left, ":")
	return {
		"name": name_part.strip(),
		"type": type_part.strip(),
		"default": default.strip(),
	}


def split_top_level_commas(source: str) -> list[str]:
	if not source:
		return []
	parts: list[str] = []
	start = 0
	depth = 0
	for index, char in enumerate(source):
		if char in "([{":
			depth += 1
		elif char in ")]}" and depth > 0:
			depth -= 1
		elif char == "," and depth == 0:
			parts.append(source[start:index].strip())
			start = index + 1
	parts.append(source[start:].strip())
	return parts


def split_once_top_level(source: str, separator: str) -> tuple[str, str]:
	depth = 0
	for index, char in enumerate(source):
		if char in "([{":
			depth += 1
		elif char in ")]}" and depth > 0:
			depth -= 1
		elif char == separator and depth == 0:
			return source[:index], source[index + 1:]
	return source, ""


def api_enum_signature_is_compatible(old_signature: str, new_signature: str) -> bool:
	old_values = parse_api_enum_values(old_signature)
	new_values = parse_api_enum_values(new_signature)
	if not old_values or len(new_values) < len(old_values):
		return False
	position = 0
	for old_value in old_values:
		try:
			found_index = new_values.index(old_value, position)
		except ValueError:
			return False
		position = found_index + 1
	return True


def parse_api_enum_values(signature: str) -> list[str]:
	start = signature.find("{")
	end = signature.rfind("}")
	if start < 0 or end <= start:
		return []
	body = signature[start + 1:end]
	values: list[str] = []
	for part in split_top_level_commas(body):
		left, _default = split_once_top_level(part, "=")
		clean = left.strip()
		if not clean:
			continue
		matches = re.findall(r"[A-Za-z_]\w*", clean)
		if not matches:
			continue
		if clean.startswith("##"):
			values.append(matches[-1])
		else:
			values.append(matches[0])
	return values


def read_api_catalog_snapshot_from_workspace() -> dict[str, Any]:
	catalog_root = ROOT / "docs/api_catalog"
	index_path = catalog_root / "index.xml"
	if not index_path.is_file():
		return {"classes": {}, "errors": ["docs/api_catalog/index.xml is missing."]}
	return parse_api_catalog_snapshot(
		index_path.read_text(encoding="utf-8"),
		lambda class_path: read_text_file(catalog_root / class_path),
		"workspace",
	)


def read_api_catalog_snapshot_from_git(tag: str) -> dict[str, Any]:
	index_text = git_show_text(f"{tag}:docs/api_catalog/index.xml")
	if not index_text:
		return {"classes": {}, "errors": [f"{tag}:docs/api_catalog/index.xml is missing or unreadable."]}
	return parse_api_catalog_snapshot(
		index_text,
		lambda class_path: git_show_text(f"{tag}:docs/api_catalog/{class_path}"),
		tag,
	)


def parse_api_catalog_snapshot(
	index_text: str,
	class_loader: Any,
	label: str,
) -> dict[str, Any]:
	errors: list[str] = []
	classes: dict[str, Any] = {}
	try:
		index_root = ET.fromstring(index_text)
	except ET.ParseError as exc:
		return {"classes": {}, "errors": [f"{label} API catalog index XML parse failed: {exc}"]}
	for module in index_root.findall("module"):
		module_id = module.get("id", "")
		for class_ref in module.findall("class"):
			class_path = class_ref.get("path", "")
			class_name = class_ref.get("name", "")
			if not class_name or not class_path:
				continue
			class_text = class_loader(class_path)
			if not class_text:
				errors.append(f"{label}:{class_path} is missing or unreadable.")
				continue
			try:
				class_root = ET.fromstring(class_text)
			except ET.ParseError as exc:
				errors.append(f"{label}:{class_path} XML parse failed: {exc}")
				continue
			classes[class_name] = parse_api_class_snapshot(class_ref, class_root, module_id)
	return {
		"schema_version": index_root.get("schemaVersion", ""),
		"source_digest": index_root.get("sourceDigest", ""),
		"class_count": len(classes),
		"classes": classes,
		"errors": errors,
	}


def parse_api_class_snapshot(class_ref: ET.Element, class_root: ET.Element, module_id: str) -> dict[str, Any]:
	members: dict[str, Any] = {}
	for group in ("signals", "enums", "constants", "properties", "methods", "innerClasses"):
		group_node = class_root.find(group)
		if group_node is None:
			continue
		for member in group_node.findall("member"):
			kind = member.get("kind", group.rstrip("s"))
			name = member.get("name", "")
			if not name:
				continue
			key = f"{kind}:{name}"
			members[key] = {
				"kind": kind,
				"name": name,
				"group": group,
				"signature": normalize_api_signature(member.findtext("signature", "")),
			}
	return {
		"name": class_ref.get("name", class_root.get("name", "")),
		"module": class_root.get("module", module_id),
		"source_path": class_ref.get("sourcePath", class_root.get("path", "")),
		"extends": class_ref.get("extends", class_root.get("extends", "")),
		"members": members,
	}


def normalize_api_signature(signature: str) -> str:
	return " ".join(signature.split())


def compare_api_catalog_snapshots(base: dict[str, Any], current: dict[str, Any]) -> dict[str, Any]:
	base_classes: dict[str, Any] = base.get("classes", {})
	current_classes: dict[str, Any] = current.get("classes", {})
	added_class_names = sorted(set(current_classes) - set(base_classes))
	removed_class_names = sorted(set(base_classes) - set(current_classes))
	added_classes = [compact_api_class(current_classes[name]) for name in added_class_names]
	removed_classes = [compact_api_class(base_classes[name]) for name in removed_class_names]
	added_members: list[dict[str, Any]] = []
	removed_members: list[dict[str, Any]] = []
	signature_changes: list[dict[str, Any]] = []
	extends_changes: list[dict[str, Any]] = []

	for class_name in sorted(set(base_classes) & set(current_classes)):
		base_class = base_classes[class_name]
		current_class = current_classes[class_name]
		if base_class.get("extends", "") != current_class.get("extends", ""):
			extends_changes.append({
				"class": class_name,
				"old_extends": base_class.get("extends", ""),
				"new_extends": current_class.get("extends", ""),
			})
		base_members: dict[str, Any] = base_class.get("members", {})
		current_members: dict[str, Any] = current_class.get("members", {})
		for member_key in sorted(set(current_members) - set(base_members)):
			added_members.append(compact_api_member(class_name, current_members[member_key]))
		for member_key in sorted(set(base_members) - set(current_members)):
			removed_members.append(compact_api_member(class_name, base_members[member_key]))
		for member_key in sorted(set(base_members) & set(current_members)):
			base_member = base_members[member_key]
			current_member = current_members[member_key]
			if base_member.get("signature", "") == current_member.get("signature", ""):
				continue
			signature_changes.append({
				"class": class_name,
				"kind": current_member.get("kind", ""),
				"name": current_member.get("name", ""),
				"old_signature": base_member.get("signature", ""),
				"new_signature": current_member.get("signature", ""),
			})
	return {
		"added_classes": added_classes,
		"removed_classes": removed_classes,
		"added_members": added_members,
		"removed_members": removed_members,
		"signature_changes": signature_changes,
		"extends_changes": extends_changes,
	}


def compact_api_class(api_class: dict[str, Any]) -> dict[str, Any]:
	return {
		"name": api_class.get("name", ""),
		"module": api_class.get("module", ""),
		"source_path": api_class.get("source_path", ""),
		"extends": api_class.get("extends", ""),
	}


def compact_api_member(class_name: str, member: dict[str, Any]) -> dict[str, Any]:
	return {
		"class": class_name,
		"kind": member.get("kind", ""),
		"name": member.get("name", ""),
		"signature": member.get("signature", ""),
	}


def api_diff_breaking_allowed(base_tag: str, release_version: str) -> bool:
	base_version = parse_semver(base_tag)
	release_parts = parse_semver(release_version)
	if base_version is None or release_parts is None:
		return False
	return release_parts[0] > base_version[0]


def find_latest_semver_tag_before(version: str) -> str:
	release_parts = parse_semver(version)
	if release_parts is None:
		return ""
	tags = [
		(tag, tag_parts)
		for tag in git_lines(["tag", "--list"])
		for tag_parts in [parse_semver(tag)]
		if tag_parts is not None and tag_parts < release_parts
	]
	if not tags:
		return ""
	tags.sort(key=lambda item: item[1])
	return tags[-1][0]


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
		"tool_source": [],
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


def path_hygiene() -> dict[str, Any]:
	tracked_paths_result = read_git_paths(["ls-files", "-z", "--cached"])
	untracked_paths_result = read_git_paths(["ls-files", "-z", "--others", "--exclude-standard"])
	scan_errors: list[dict[str, Any]] = []
	if tracked_paths_result["error"]:
		scan_errors.append({
			"kind": "tracked_path_scan_failed",
			"message": trim_text(tracked_paths_result["error"], 1000),
		})
	if untracked_paths_result["error"]:
		scan_errors.append({
			"kind": "untracked_path_scan_failed",
			"message": trim_text(untracked_paths_result["error"], 1000),
		})
	if scan_errors:
		return {
			"ok": False,
			"root": str(ROOT),
			"tracked_file_count": 0,
			"untracked_file_count": 0,
			"scanned_file_count": 0,
			"issue_count": len(scan_errors),
			"issues": scan_errors,
		}

	tracked_paths = tracked_paths_result["paths"]
	untracked_paths = untracked_paths_result["paths"]
	scanned_paths = sorted(set(tracked_paths + untracked_paths))
	issues = [
		*find_case_collision_issues(scanned_paths),
		*find_blocked_tracked_dir_issues(scanned_paths),
		*find_missing_local_github_action_issues(scanned_paths),
		*find_gdscript_utf8_bom_issues(scanned_paths),
	]
	return {
		"ok": len(issues) == 0,
		"root": str(ROOT),
		"tracked_file_count": len(tracked_paths),
		"untracked_file_count": len(untracked_paths),
		"scanned_file_count": len(scanned_paths),
		"issue_count": len(issues),
		"issues": issues,
	}


def api_since_touched() -> dict[str, Any]:
	entries = parse_git_status(git_lines(["status", "--short", "-uall", "--", "addons/gf"]))
	paths = sorted({
		entry["path"]
		for entry in entries
		if entry["path"].endswith(".gd")
	})
	issues: list[dict[str, Any]] = []
	scanned_paths: list[str] = []
	for path in paths:
		source_path = ROOT / path
		if not source_path.is_file():
			continue

		scanned_paths.append(path)
		touched_lines = read_git_touched_lines(path)
		try:
			source = source_path.read_text(encoding="utf-8")
		except OSError as exc:
			issues.append(make_boundary_issue(
				"api_since_source_unreadable",
				path,
				f"Could not read changed GDScript source: {exc}",
			))
			continue
		issues.extend(find_missing_touched_api_since_issues(path, source, touched_lines))

	return {
		"ok": len(issues) == 0,
		"root": str(ROOT),
		"changed_gdscript_file_count": len(paths),
		"scanned_file_count": len(scanned_paths),
		"issue_count": len(issues),
		"issues": issues,
	}


def read_git_touched_lines(path: str) -> set[int] | None:
	if git_exit_code(["ls-files", "--error-unmatch", path]) != 0:
		return None

	touched_lines: set[int] = set()
	for diff_args in (
		["diff", "--unified=0", "--", path],
		["diff", "--cached", "--unified=0", "--", path],
	):
		touched_lines.update(parse_git_added_lines(git_text(diff_args)))
	return touched_lines


def parse_git_added_lines(diff_text: str) -> set[int]:
	added_lines: set[int] = set()
	current_line: int | None = None
	for line in diff_text.splitlines():
		match = GIT_DIFF_HUNK_RE.match(line)
		if match:
			current_line = int(match.group("start"))
			continue
		if current_line is None:
			continue
		if line.startswith("+++") or line.startswith("---"):
			continue
		if line.startswith("+"):
			added_lines.add(current_line)
			current_line += 1
		elif line.startswith("-"):
			continue
		elif line.startswith("\\"):
			continue
		else:
			current_line += 1
	return added_lines


def find_missing_touched_api_since_issues(
	path: str,
	source: str,
	touched_lines: set[int] | None,
) -> list[dict[str, Any]]:
	lines = source.splitlines()
	issues: list[dict[str, Any]] = []
	index = 0
	while index < len(lines):
		if not lines[index].lstrip().startswith("##"):
			index += 1
			continue

		block_start = index
		block: list[str] = []
		while index < len(lines) and lines[index].lstrip().startswith("##"):
			block.append(lines[index])
			index += 1

		api_match = first_api_doc_match(block)
		if api_match is None or any(API_DOC_SINCE_RE.search(item) for item in block):
			continue

		declaration_index = find_bound_gdscript_declaration_index(lines, index)
		if declaration_index < 0:
			continue

		if not api_doc_block_touched(block_start, declaration_index, touched_lines):
			continue

		issues.append(make_boundary_issue(
			"missing_api_since",
			path,
			"Changed public/protected API documentation must include @since.",
			line=block_start + 1,
			api=api_match.group("visibility"),
			declaration=lines[declaration_index].strip(),
		))
	return issues


def first_api_doc_match(block: list[str]) -> re.Match[str] | None:
	for line in block:
		match = API_DOC_API_RE.search(line)
		if match:
			return match
	return None


def find_bound_gdscript_declaration_index(lines: list[str], start_index: int) -> int:
	index = start_index
	while index < len(lines):
		stripped = lines[index].strip()
		if not stripped:
			index += 1
			continue
		if stripped.startswith("@") and GDSCRIPT_API_DECL_RE.match(lines[index]) is None:
			index += 1
			continue
		if GDSCRIPT_API_DECL_RE.match(lines[index]):
			return index
		return -1
	return -1


def api_doc_block_touched(
	block_start: int,
	declaration_index: int,
	touched_lines: set[int] | None,
) -> bool:
	if touched_lines is None:
		return True
	return bool(set(range(block_start + 1, declaration_index + 2)) & touched_lines)


def dependency_boundary() -> dict[str, Any]:
	manifest_records = collect_bundled_extension_manifest_records()
	extension_ids = sorted({
		record["id"]
		for record in manifest_records
		if record["id"]
	})
	extension_id_by_name = {
		record["extension_name"]: record["id"]
		for record in manifest_records
		if record["id"]
	}
	standard_class_roots = collect_class_name_roots(GF_STANDARD_ROOT)
	extension_class_roots = collect_class_name_roots(GF_EXTENSIONS_ROOT)
	issues: list[dict[str, Any]] = []
	issues.extend(audit_bundled_extension_manifests(manifest_records))
	issues.extend(audit_kernel_dependency_boundary(standard_class_roots, extension_class_roots, extension_ids))
	issues.extend(audit_standard_dependency_boundary(extension_class_roots, extension_ids))
	issues.extend(audit_bundled_extension_dependency_boundary(extension_class_roots, extension_id_by_name, extension_ids))
	issues.extend(audit_framework_project_extension_defaults())
	return {
		"ok": len(issues) == 0,
		"root": str(ROOT),
		"manifest_count": len(manifest_records),
		"extension_id_count": len(extension_ids),
		"standard_class_count": len(standard_class_roots),
		"extension_class_count": len(extension_class_roots),
		"issue_count": len(issues),
		"issues": issues,
	}


def public_api_boundary() -> dict[str, Any]:
	files = collect_public_api_boundary_files()
	issues: list[dict[str, Any]] = []
	for path in files:
		relative_path = path.relative_to(ROOT).as_posix()
		source = read_text_file(path)
		if not source:
			continue
		issues.extend(audit_public_api_boundary_text(source, relative_path))
	return {
		"ok": len(issues) == 0,
		"root": str(ROOT),
		"file_count": len(files),
		"issue_count": len(issues),
		"issues": issues,
	}


def public_docs_boundary() -> dict[str, Any]:
	files = collect_public_doc_boundary_files()
	issues: list[dict[str, Any]] = []
	for path in files:
		relative_path = path.relative_to(ROOT).as_posix()
		source = read_text_file(path)
		if not source:
			continue
		issues.extend(audit_public_doc_boundary_text(source, relative_path))
	return {
		"ok": len(issues) == 0,
		"root": str(ROOT),
		"file_count": len(files),
		"issue_count": len(issues),
		"issues": issues,
	}


def resource_boundary(
	fail_on_issues: bool = False,
	include_observations: bool = False,
) -> dict[str, Any]:
	paths_payload = collect_resource_boundary_paths()
	scan_errors = paths_payload["errors"]
	if scan_errors:
		return {
			"ok": False,
			"root": str(ROOT),
			"report_only": not fail_on_issues,
			"file_count": 0,
			"issue_count": len(scan_errors),
			"warning_count": 0,
			"info_count": 0,
			"issues": scan_errors,
		}

	files: list[str] = paths_payload["paths"]
	findings: list[dict[str, Any]] = []
	for path in files:
		source_path = ROOT / path
		source = read_text_file(source_path)
		if not source:
			continue
		findings.extend(audit_resource_boundary_text(source, path))
	source_owner_entries = collect_resource_boundary_source_owner_entries()
	annotate_resource_boundary_packages(findings, source_owner_entries)
	return make_resource_boundary_payload(files, findings, fail_on_issues, include_observations)


def make_resource_boundary_payload(
	files: list[str],
	findings: list[dict[str, Any]],
	fail_on_issues: bool,
	include_observations: bool = False,
) -> dict[str, Any]:
	issues = [finding for finding in findings if not is_resource_boundary_observation(finding)]
	observations = [finding for finding in findings if is_resource_boundary_observation(finding)]
	warning_count = sum(1 for issue in issues if issue.get("severity") == "warning")
	info_count = sum(1 for issue in issues if issue.get("severity") == "info")
	observation_samples = observations[:RESOURCE_BOUNDARY_OBSERVATION_SAMPLE_LIMIT]
	return {
		"ok": not fail_on_issues or len(issues) == 0,
		"root": str(ROOT),
		"report_only": not fail_on_issues,
		"file_count": len(files),
		"issue_count": len(issues),
		"warning_count": warning_count,
		"info_count": info_count,
		"severity_counts": count_issue_field(issues, "severity"),
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"target_extension_counts": count_issue_field(issues, "target_extension"),
		"source_kind_counts": count_issue_field(issues, "source_kind"),
		"source_package_counts": count_issue_field(issues, "source_package"),
		"target_package_counts": count_issue_field(issues, "target_package"),
		"source_target_package_counts": count_issue_field_pair(issues, "source_package", "target_package"),
		"observation_count": len(observations),
		"observation_kind_counts": count_issue_field(observations, "kind"),
		"observation_target_extension_counts": count_issue_field(observations, "target_extension"),
		"observation_source_kind_counts": count_issue_field(observations, "source_kind"),
		"observation_source_package_counts": count_issue_field(observations, "source_package"),
		"observation_target_package_counts": count_issue_field(observations, "target_package"),
		"observation_source_target_package_counts": count_issue_field_pair(observations, "source_package", "target_package"),
		"observation_samples": observation_samples,
		"observations": observations if include_observations else [],
		"issues": issues,
	}


def is_resource_boundary_observation(finding: dict[str, Any]) -> bool:
	return str(finding.get("kind", "")) in RESOURCE_BOUNDARY_OBSERVATION_KINDS


def collect_resource_boundary_source_owner_entries() -> list[dict[str, str]]:
	paths_payload = collect_package_manifest_paths()
	if paths_payload["errors"]:
		return []

	records: list[dict[str, Any]] = []
	issues: list[dict[str, Any]] = []
	for path in paths_payload["paths"]:
		record = load_package_manifest_record(path)
		records.append(record)
		issues.extend(record["issues"])
	issues.extend(audit_package_manifest_graph(records))
	issues.extend(audit_package_path_ownership(records))
	if package_issue_error_count(issues) > 0:
		return []
	return collect_package_source_owner_entries(records)


def annotate_resource_boundary_packages(
	findings: list[dict[str, Any]],
	owner_entries: list[dict[str, str]],
) -> None:
	for finding in findings:
		finding["source_package"] = resource_boundary_source_package(
			str(finding.get("path", "")),
			owner_entries,
		)
		finding["target_package"] = resource_boundary_target_package(
			str(finding.get("target", "")),
			owner_entries,
		)


def content_package_boundary(check_resource_exists: bool = False) -> dict[str, Any]:
	paths_payload = collect_content_package_manifest_paths()
	scan_errors = paths_payload["errors"]
	if scan_errors:
		return {
			"ok": False,
			"root": str(ROOT),
			"manifest_count": 0,
			"package_count": 0,
			"resource_count": 0,
			"issue_count": len(scan_errors),
			"issue_kind_counts": count_issue_field(scan_errors, "kind"),
			"issues": scan_errors,
		}

	manifest_records: list[dict[str, Any]] = []
	issues: list[dict[str, Any]] = []
	resource_count = 0
	for path in paths_payload["paths"]:
		record = load_content_package_manifest_record(path, check_resource_exists)
		manifest_records.append(record)
		issues.extend(record["issues"])
		resource_count += record["resource_count"]

	issues.extend(audit_content_package_graph(manifest_records))
	return {
		"ok": len(issues) == 0,
		"root": str(ROOT),
		"manifest_count": len(manifest_records),
		"package_count": len([record for record in manifest_records if record["package_id"]]),
		"resource_count": resource_count,
		"issue_count": len(issues),
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"issues": issues,
	}


def asset_lifecycle_boundary(fail_on_warnings: bool = False) -> dict[str, Any]:
	paths_payload = collect_asset_lifecycle_paths()
	scan_errors = paths_payload["errors"]
	if scan_errors:
		return {
			"ok": False,
			"root": str(ROOT),
			"report_only": not fail_on_warnings,
			"file_count": 0,
			"issue_count": len(scan_errors),
			"warning_count": 0,
			"info_count": 0,
			"issue_kind_counts": count_issue_field(scan_errors, "kind"),
			"issues": scan_errors,
		}

	files: list[str] = paths_payload["paths"]
	issues: list[dict[str, Any]] = []
	for path in files:
		source_path = ROOT / path
		source = read_text_file(source_path)
		if not source:
			continue
		issues.extend(audit_asset_lifecycle_text(source, path))
	warning_count = sum(1 for issue in issues if issue.get("severity") == "warning")
	info_count = sum(1 for issue in issues if issue.get("severity") == "info")
	return {
		"ok": not fail_on_warnings or warning_count == 0,
		"root": str(ROOT),
		"report_only": not fail_on_warnings,
		"file_count": len(files),
		"issue_count": len(issues),
		"warning_count": warning_count,
		"info_count": info_count,
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"severity_counts": count_issue_field(issues, "severity"),
		"issues": issues,
	}


def project_profile_boundary(profile_path: str = "", fail_on_warnings: bool = False) -> dict[str, Any]:
	profile_payload = load_project_profile(profile_path)
	issues: list[dict[str, Any]] = list(profile_payload["issues"])
	if not profile_payload["found"]:
		return make_project_profile_boundary_payload(
			profile_payload,
			[],
			issues,
			fail_on_warnings,
		)

	paths_payload = collect_project_profile_paths()
	if paths_payload["errors"]:
		issues.extend(paths_payload["errors"])
		return make_project_profile_boundary_payload(
			profile_payload,
			[],
			issues,
			fail_on_warnings,
		)

	repo_paths: list[str] = paths_payload["paths"]
	profile_data: dict[str, Any] = profile_payload["data"]
	issues.extend(audit_project_profile_data(
		profile_data,
		profile_payload["path"],
		repo_paths,
	))
	return make_project_profile_boundary_payload(
		profile_payload,
		repo_paths,
		issues,
		fail_on_warnings,
	)


def make_project_profile_boundary_payload(
	profile_payload: dict[str, Any],
	repo_paths: list[str],
	issues: list[dict[str, Any]],
	fail_on_warnings: bool,
) -> dict[str, Any]:
	error_count = sum(1 for issue in issues if issue.get("severity") == "error")
	warning_count = sum(1 for issue in issues if issue.get("severity") == "warning")
	info_count = sum(1 for issue in issues if issue.get("severity") == "info")
	return {
		"ok": error_count == 0 and (not fail_on_warnings or warning_count == 0),
		"root": str(ROOT),
		"profile_found": profile_payload["found"],
		"profile_path": profile_payload["path"],
		"profile_id": profile_payload["id"],
		"file_count": len(repo_paths),
		"issue_count": len(issues),
		"error_count": error_count,
		"warning_count": warning_count,
		"info_count": info_count,
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"severity_counts": count_issue_field(issues, "severity"),
		"issues": issues,
	}


def package_boundary() -> dict[str, Any]:
	paths_payload = collect_package_manifest_paths()
	scan_errors = paths_payload["errors"]
	if scan_errors:
		return {
			"ok": False,
			"root": str(ROOT),
			"manifest_count": 0,
			"package_count": 0,
			"path_count": 0,
			"issue_count": len(scan_errors),
			"issue_kind_counts": count_issue_field(scan_errors, "kind"),
			"issues": scan_errors,
		}

	records: list[dict[str, Any]] = []
	issues: list[dict[str, Any]] = []
	path_count = 0
	for path in paths_payload["paths"]:
		record = load_package_manifest_record(path)
		records.append(record)
		issues.extend(record["issues"])
		path_count += len(record["paths"])

	issues.extend(audit_package_manifest_graph(records))
	issues.extend(audit_package_path_ownership(records))
	return {
		"ok": len(issues) == 0,
		"root": str(ROOT),
		"manifest_count": len(records),
		"package_count": len([record for record in records if record["id"]]),
		"path_count": path_count,
		"issue_count": len(issues),
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"kind_counts": count_record_field(records, "kind"),
		"issues": issues,
	}


def package_closure_audit() -> dict[str, Any]:
	paths_payload = collect_package_manifest_paths()
	scan_errors = paths_payload["errors"]
	if scan_errors:
		return make_package_closure_audit_payload([], [], [], scan_errors)

	records: list[dict[str, Any]] = []
	issues: list[dict[str, Any]] = []
	for path in paths_payload["paths"]:
		record = load_package_manifest_record(path)
		records.append(record)
		issues.extend(record["issues"])

	issues.extend(audit_package_manifest_graph(records))
	issues.extend(audit_package_path_ownership(records))
	closure_rows: list[dict[str, Any]] = []
	standard_fan_in: list[dict[str, Any]] = []
	if package_issue_error_count(issues) == 0:
		closure_rows = collect_package_closure_rows(records)
		standard_fan_in = collect_package_standard_fan_in(records, closure_rows)
		issues.extend(audit_package_closure_rows(records, closure_rows))
	return make_package_closure_audit_payload(records, closure_rows, standard_fan_in, issues)


def collect_package_closure_rows(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
	records_by_id = package_records_by_id(records)
	closure_cache: dict[str, list[str]] = {}

	def visit(package_id: str) -> list[str]:
		if package_id in closure_cache:
			return closure_cache[package_id]
		record = records_by_id.get(package_id)
		if record is None:
			return []
		closure: list[str] = []
		for dependency_id in package_direct_package_dependencies(record):
			for transitive_id in visit(dependency_id):
				if transitive_id not in closure:
					closure.append(transitive_id)
		if package_id not in closure:
			closure.append(package_id)
		closure_cache[package_id] = closure
		return closure

	rows: list[dict[str, Any]] = []
	for record in sorted(records, key=package_record_sort_key):
		package_id = str(record.get("id", ""))
		if not package_id:
			continue
		closure = visit(package_id)
		kind_counts = package_closure_kind_count_items(closure, records_by_id)
		rows.append({
			"package_id": package_id,
			"kind": str(record.get("kind", "")),
			"path": str(record.get("path", "")),
			"direct_dependencies": list(record.get("dependencies", [])),
			"direct_packages": list(record.get("packages", [])),
			"closure": closure,
			"closure_count": len(closure),
			"standard_count": package_closure_kind_count(kind_counts, "standard"),
			"extension_count": package_closure_kind_count(kind_counts, "extension"),
			"preset_count": package_closure_kind_count(kind_counts, "preset"),
			"kind_counts": kind_counts,
		})
	return rows


def audit_package_closure_rows(records: list[dict[str, Any]], closure_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
	records_by_id = package_records_by_id(records)
	issues: list[dict[str, Any]] = []
	for row in closure_rows:
		package_id = str(row.get("package_id", ""))
		kind = str(row.get("kind", ""))
		closure_ids = set(row.get("closure", []))
		record = records_by_id.get(package_id, {})
		path = str(record.get("path", ""))
		if kind == "extension":
			if PACKAGE_CLOSURE_EDITOR_PACKAGE_ID in closure_ids:
				issues.append(make_boundary_issue(
					"package_extension_editor_closure",
					path,
					"Runtime extension packages must not pull the editor aggregate package into their install closure.",
					severity="error",
					row_key=package_id,
					actual_value=PACKAGE_CLOSURE_EDITOR_PACKAGE_ID,
				))
			if PACKAGE_CLOSURE_DEBUG_PACKAGE_ID in row.get("direct_dependencies", []):
				issues.append(make_boundary_issue(
					"package_extension_debug_dependency",
					path,
					"Extension depends on the full debug package; review whether a smaller no-UI diagnostics package is enough.",
					severity="warning",
					row_key=package_id,
					actual_value=PACKAGE_CLOSURE_DEBUG_PACKAGE_ID,
				))
			if (
				int(row.get("closure_count", 0)) > PACKAGE_CLOSURE_EXTENSION_TOTAL_WARNING_THRESHOLD
				or int(row.get("standard_count", 0)) > PACKAGE_CLOSURE_EXTENSION_STANDARD_WARNING_THRESHOLD
			):
				issues.append(make_boundary_issue(
					"package_extension_large_closure",
					path,
					"Extension install closure is large enough to need boundary review before it becomes expected user payload.",
					severity="warning",
					row_key=package_id,
					actual_value=f"{row.get('closure_count')} total / {row.get('standard_count')} standard",
					expected_value=(
						f"<= {PACKAGE_CLOSURE_EXTENSION_TOTAL_WARNING_THRESHOLD} total and "
						f"<= {PACKAGE_CLOSURE_EXTENSION_STANDARD_WARNING_THRESHOLD} standard"
					),
				))
		elif package_id == PACKAGE_CLOSURE_DEBUG_PACKAGE_ID and "gf.standard.ui" in closure_ids:
			issues.append(make_boundary_issue(
				"package_debug_ui_closure",
				path,
				"Debug package currently pulls UI into its closure; keep this visible while deciding whether to split diagnostics.",
				severity="warning",
				row_key=package_id,
				actual_value="gf.standard.ui",
			))
		elif kind == "preset" and int(row.get("closure_count", 0)) > PACKAGE_CLOSURE_PRESET_TOTAL_INFO_THRESHOLD:
			issues.append(make_boundary_issue(
				"package_preset_large_closure",
				path,
				"Preset install closure is intentionally broad; editor wizard and CLI dry-run should show the full closure.",
				severity="info",
				row_key=package_id,
				actual_value=row.get("closure_count"),
				expected_value=f"visible closure > {PACKAGE_CLOSURE_PRESET_TOTAL_INFO_THRESHOLD}",
			))
	return issues


def collect_package_standard_fan_in(
	records: list[dict[str, Any]],
	closure_rows: list[dict[str, Any]],
) -> list[dict[str, Any]]:
	records_by_id = package_records_by_id(records)
	fan_in: dict[str, set[str]] = {}
	for row in closure_rows:
		package_id = str(row.get("package_id", ""))
		for dependency_id in row.get("closure", []):
			if dependency_id == package_id:
				continue
			dependency_record = records_by_id.get(str(dependency_id))
			if dependency_record is None or dependency_record.get("kind") != "standard":
				continue
			fan_in.setdefault(str(dependency_id), set()).add(package_id)
	return [
		{
			"package_id": package_id,
			"dependent_count": len(dependents),
			"dependents": sorted(dependents),
		}
		for package_id, dependents in sorted(fan_in.items(), key=lambda item: (-len(item[1]), item[0]))
	]


def make_package_closure_audit_payload(
	records: list[dict[str, Any]],
	closure_rows: list[dict[str, Any]],
	standard_fan_in: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> dict[str, Any]:
	error_count = package_issue_error_count(issues)
	warning_count = package_issue_severity_count(issues, "warning")
	info_count = package_issue_severity_count(issues, "info")
	return {
		"ok": error_count == 0,
		"root": str(ROOT),
		"package_count": len([record for record in records if record.get("id")]),
		"closure_count": len(closure_rows),
		"issue_count": len(issues),
		"error_count": error_count,
		"warning_count": warning_count,
		"info_count": info_count,
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"severity_counts": count_issue_field(issues, "severity"),
		"kind_counts": count_record_field(records, "kind"),
		"extension_total_warning_threshold": PACKAGE_CLOSURE_EXTENSION_TOTAL_WARNING_THRESHOLD,
		"extension_standard_warning_threshold": PACKAGE_CLOSURE_EXTENSION_STANDARD_WARNING_THRESHOLD,
		"preset_total_info_threshold": PACKAGE_CLOSURE_PRESET_TOTAL_INFO_THRESHOLD,
		"closures": closure_rows,
		"standard_fan_in": standard_fan_in,
		"issues": issues,
	}


def package_records_by_id(records: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
	return {
		str(record.get("id", "")): record
		for record in records
		if record.get("id")
	}


def package_record_sort_key(record: dict[str, Any]) -> tuple[int, str]:
	kind_order = {
		"kernel": 0,
		"standard": 1,
		"extension": 2,
		"preset": 3,
		"tool": 4,
	}
	return (kind_order.get(str(record.get("kind", "")), 99), str(record.get("id", "")))


def package_direct_package_dependencies(record: dict[str, Any]) -> list[str]:
	if record.get("kind") == "preset":
		return [str(package_id) for package_id in record.get("packages", [])]
	return [str(package_id) for package_id in record.get("dependencies", [])]


def package_closure_kind_count_items(
	closure_ids: list[str],
	records_by_id: dict[str, dict[str, Any]],
) -> list[dict[str, Any]]:
	counter: dict[str, int] = {}
	for package_id in closure_ids:
		record = records_by_id.get(package_id)
		kind = str(record.get("kind", "")) if record is not None else "<missing>"
		increment_counter(counter, kind or "<empty>")
	return counter_items(counter)


def package_closure_kind_count(kind_counts: list[dict[str, Any]], kind: str) -> int:
	for item in kind_counts:
		if item.get("key") == kind:
			return int(item.get("count", 0))
	return 0


def package_issue_error_count(issues: list[dict[str, Any]]) -> int:
	return sum(1 for issue in issues if issue.get("severity", "error") == "error")


def package_issue_severity_count(issues: list[dict[str, Any]], severity: str) -> int:
	return sum(1 for issue in issues if issue.get("severity", "error") == severity)


def package_focused_gut_mapping() -> dict[str, Any]:
	paths_payload = collect_package_manifest_paths()
	scan_errors = paths_payload["errors"]
	if scan_errors:
		return make_package_focused_gut_mapping_payload([], {}, scan_errors)

	records: list[dict[str, Any]] = []
	issues: list[dict[str, Any]] = []
	for path in paths_payload["paths"]:
		record = load_package_manifest_record(path)
		records.append(record)
		issues.extend(record["issues"])

	issues.extend(audit_package_manifest_graph(records))
	issues.extend(audit_package_path_ownership(records))
	mapping_packages: dict[str, Any] = {}
	if not issues:
		mapping_payload = load_package_focused_gut_mapping_file()
		mapping_packages = mapping_payload["packages"]
		issues.extend(mapping_payload["issues"])
		if not mapping_payload["issues"]:
			issues.extend(audit_package_focused_gut_mapping(records, mapping_packages))
	return make_package_focused_gut_mapping_payload(records, mapping_packages, issues)


def load_package_focused_gut_mapping_file() -> dict[str, Any]:
	issues: list[dict[str, Any]] = []
	if not PACKAGE_FOCUSED_GUT_MAPPING_PATH.is_file():
		issues.append(make_package_issue(
			"package_focused_gut_mapping_missing",
			PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH,
			"Package focused GUT mapping file is required for modular package maintenance.",
		))
		return {"packages": {}, "issues": issues}

	try:
		data = json.loads(PACKAGE_FOCUSED_GUT_MAPPING_PATH.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
		issues.append(make_package_issue(
			"invalid_package_focused_gut_mapping_json",
			PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH,
			"Package focused GUT mapping must be a readable UTF-8 JSON object.",
			error=trim_text(str(error), 300),
		))
		return {"packages": {}, "issues": issues}

	if not isinstance(data, dict):
		issues.append(make_package_issue(
			"invalid_package_focused_gut_mapping",
			PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH,
			"Package focused GUT mapping root must be a JSON object.",
			expected_value="object",
			actual_value=type(data).__name__,
		))
		return {"packages": {}, "issues": issues}

	if data.get("schema_version") != PACKAGE_FOCUSED_GUT_MAPPING_SCHEMA_VERSION:
		issues.append(make_package_issue(
			"invalid_package_focused_gut_mapping_schema_version",
			PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH,
			"Package focused GUT mapping schema_version must match the maintenance tool.",
			field="schema_version",
			expected_value=PACKAGE_FOCUSED_GUT_MAPPING_SCHEMA_VERSION,
			actual_value=data.get("schema_version"),
		))

	raw_packages = data.get("packages")
	if not isinstance(raw_packages, dict):
		issues.append(make_package_issue(
			"invalid_package_focused_gut_mapping_packages",
			PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH,
			"Package focused GUT mapping must contain a packages object.",
			field="packages",
			expected_value="object",
			actual_value=type(raw_packages).__name__,
		))
		return {"packages": {}, "issues": issues}

	mapping_packages: dict[str, Any] = {}
	for raw_package_id, raw_tests in raw_packages.items():
		if not isinstance(raw_package_id, str) or not raw_package_id.strip():
			issues.append(make_package_issue(
				"invalid_package_focused_gut_mapping_package_id",
				PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH,
				"Package focused GUT mapping keys must be non-empty package ids.",
				field="packages",
				actual_value=str(raw_package_id),
			))
			continue
		mapping_packages[raw_package_id.strip()] = raw_tests
	return {"packages": mapping_packages, "issues": issues}


def audit_package_focused_gut_mapping(
	records: list[dict[str, Any]],
	mapping_packages: dict[str, Any],
) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	records_by_id = {
		str(record.get("id", "")): record
		for record in records
		if record.get("id")
	}
	required_package_ids = sorted(
		package_id
		for package_id, record in records_by_id.items()
		if record.get("kind") != "preset"
	)
	mapping_package_ids = sorted(mapping_packages.keys())
	for package_id in mapping_package_ids:
		record = records_by_id.get(package_id)
		if record == None:
			issues.append(make_package_issue(
				"unknown_package_focused_gut_mapping",
				PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH,
				"Focused GUT mapping references a package id that is not declared in packages/**/*.json.",
				field="packages",
				row_key=package_id,
			))
			continue
		if record.get("kind") == "preset":
			issues.append(make_package_issue(
				"preset_package_focused_gut_mapping",
				PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH,
				"Preset packages do not own source and must not declare focused GUT mappings.",
				field="packages",
				row_key=package_id,
			))

	for package_id in required_package_ids:
		if package_id not in mapping_packages:
			issues.append(make_package_issue(
				"missing_package_focused_gut_mapping",
				PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH,
				"Every non-preset package must declare its focused GUT coverage mapping.",
				field="packages",
				row_key=package_id,
			))

	seen_test_paths: dict[str, str] = {}
	for package_id in mapping_package_ids:
		record = records_by_id.get(package_id)
		if record == None:
			continue
		raw_tests = mapping_packages[package_id]
		if not isinstance(raw_tests, list):
			issues.append(make_package_issue(
				"invalid_package_focused_gut_tests",
				PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH,
				"Focused GUT mapping value must be an array of res:// test scripts.",
				field="packages",
				row_key=package_id,
				expected_value="array",
				actual_value=type(raw_tests).__name__,
			))
			continue
		if not raw_tests and package_id in required_package_ids:
			issues.append(make_package_issue(
				"empty_package_focused_gut_tests",
				PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH,
				"Focused GUT mapping for a non-preset package must not be empty.",
				field="packages",
				row_key=package_id,
			))
		for row_index, raw_test_path in enumerate(raw_tests):
			test_path = normalize_package_focused_gut_test_path(raw_test_path)
			if not test_path:
				issues.append(make_package_issue(
					"invalid_package_focused_gut_test_path",
					PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH,
					"Focused GUT test paths must be res:// paths without traversal.",
					field="packages",
					row_key=package_id,
					row_index=row_index,
					actual_value=raw_test_path,
				))
				continue
			if not test_path.startswith(PACKAGE_FOCUSED_GUT_TEST_ROOT):
				issues.append(make_package_issue(
					"package_focused_gut_test_outside_root",
					PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH,
					"Focused GUT tests must stay under res://tests/gf_core/.",
					field="packages",
					row_key=package_id,
					row_index=row_index,
					actual_value=test_path,
				))
			if not test_path.endswith(".gd"):
				issues.append(make_package_issue(
					"package_focused_gut_test_not_gdscript",
					PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH,
					"Focused GUT mappings must point to .gd test scripts.",
					field="packages",
					row_key=package_id,
					row_index=row_index,
					actual_value=test_path,
				))
			if not package_focused_gut_test_path_exists(test_path):
				issues.append(make_package_issue(
					"package_focused_gut_test_missing",
					PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH,
					"Focused GUT test path does not exist.",
					field="packages",
					row_key=package_id,
					row_index=row_index,
					actual_value=test_path,
				))
			duplicate_owner = seen_test_paths.get(test_path, "")
			if duplicate_owner:
				issues.append(make_package_issue(
					"duplicate_package_focused_gut_test",
					PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH,
					"Focused GUT test paths must belong to exactly one package mapping.",
					field="packages",
					row_key=package_id,
					row_index=row_index,
					actual_value=test_path,
					expected_value=f"already mapped by {duplicate_owner}",
				))
			else:
				seen_test_paths[test_path] = package_id
			if not package_focused_gut_test_path_matches_package(package_id, str(record.get("kind", "")), test_path):
				issues.append(make_package_issue(
					"package_focused_gut_test_scope_mismatch",
					PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH,
					"Focused GUT test path must stay in the package's test scope.",
					field="packages",
					row_key=package_id,
					row_index=row_index,
					actual_value=test_path,
					expected_value=", ".join(package_focused_gut_expected_test_prefixes(package_id, str(record.get("kind", "")))),
				))
	return issues


def make_package_focused_gut_mapping_payload(
	records: list[dict[str, Any]],
	mapping_packages: dict[str, Any],
	issues: list[dict[str, Any]],
) -> dict[str, Any]:
	required_records = [
		record
		for record in records
		if record.get("id") and record.get("kind") != "preset"
	]
	required_ids = {str(record.get("id", "")) for record in required_records}
	mapped_required_ids = [
		package_id
		for package_id in mapping_packages.keys()
		if package_id in required_ids
	]
	test_paths: set[str] = set()
	for raw_tests in mapping_packages.values():
		if not isinstance(raw_tests, list):
			continue
		for raw_test_path in raw_tests:
			test_path = normalize_package_focused_gut_test_path(raw_test_path)
			if test_path:
				test_paths.add(test_path)
	return {
		"ok": len(issues) == 0,
		"root": str(ROOT),
		"mapping_path": PACKAGE_FOCUSED_GUT_MAPPING_RELATIVE_PATH,
		"package_count": len(required_records),
		"mapped_package_count": len(mapped_required_ids),
		"test_count": len(test_paths),
		"issue_count": len(issues),
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"kind_counts": count_record_field(records, "kind"),
		"issues": issues,
	}


def normalize_package_focused_gut_test_path(raw_path: Any) -> str:
	if not isinstance(raw_path, str):
		return ""
	normalized_path = raw_path.strip().replace("\\", "/")
	if not normalized_path.startswith("res://"):
		return ""
	if "://" in normalized_path[len("res://"):]:
		return ""
	parts = [part for part in normalized_path[len("res://"):].split("/") if part not in ("", ".")]
	if any(part == ".." for part in parts):
		return ""
	return "res://" + "/".join(parts)


def package_focused_gut_test_path_exists(test_path: str) -> bool:
	if not test_path.startswith("res://"):
		return False
	return (ROOT / test_path[len("res://"):]).is_file()


def package_focused_gut_test_path_matches_package(
	package_id: str,
	package_kind: str,
	test_path: str,
) -> bool:
	return any(
		test_path.startswith(prefix)
		for prefix in package_focused_gut_expected_test_prefixes(package_id, package_kind)
	)


def package_focused_gut_expected_test_prefixes(package_id: str, package_kind: str) -> tuple[str, ...]:
	if package_kind == "kernel":
		return ("res://tests/gf_core/kernel/",)
	if package_kind == "standard":
		return (
			"res://tests/gf_core/standard/",
			*PACKAGE_FOCUSED_GUT_ALLOWED_EXTERNAL_PREFIXES.get(package_id, ()),
		)
	if package_kind == "extension":
		extension_name = package_id.removeprefix("gf.extension.")
		return (f"res://tests/gf_core/extensions/{extension_name}/",)
	if package_kind == "tool":
		tool_name = package_id.removeprefix("gf.tool.")
		return (f"res://tests/gf_core/tools/{tool_name}/",)
	return ()


def core_only_smoke() -> dict[str, Any]:
	plugin_path = "addons/gf/plugin.gd"
	source = read_text_file(ROOT / plugin_path)
	standard_class_roots = collect_class_name_roots(GF_STANDARD_ROOT)
	issues = audit_core_only_plugin_source(source, plugin_path, standard_class_roots)
	return {
		"ok": len(issues) == 0,
		"root": str(ROOT),
		"file_count": 1,
		"standard_class_count": len(standard_class_roots),
		"issue_count": len(issues),
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"issues": issues,
	}


def package_source_boundary() -> dict[str, Any]:
	paths_payload = collect_package_manifest_paths()
	scan_errors = paths_payload["errors"]
	if scan_errors:
		return make_package_source_boundary_payload([], [], scan_errors)

	records: list[dict[str, Any]] = []
	issues: list[dict[str, Any]] = []
	for path in paths_payload["paths"]:
		record = load_package_manifest_record(path)
		records.append(record)
		issues.extend(record["issues"])
	issues.extend(audit_package_manifest_graph(records))
	issues.extend(audit_package_path_ownership(records))
	if issues:
		return make_package_source_boundary_payload(records, [], issues)

	source_paths_payload = collect_package_source_boundary_paths()
	if source_paths_payload["errors"]:
		return make_package_source_boundary_payload(records, [], source_paths_payload["errors"])

	source_paths = source_paths_payload["paths"]
	class_roots = collect_package_source_class_roots(source_paths)
	issues.extend(audit_package_source_references(records, source_paths, class_roots))
	return make_package_source_boundary_payload(records, source_paths, issues)


def package_user_dependency_boundary() -> dict[str, Any]:
	source_paths = collect_package_user_dependency_boundary_paths()
	issues: list[dict[str, Any]] = []
	for source_path in source_paths:
		source = read_text_file(ROOT / source_path)
		issues.extend(audit_package_user_dependency_source(source, source_path))
	return make_package_user_dependency_boundary_payload(source_paths, issues)


def collect_package_user_dependency_boundary_paths() -> list[str]:
	paths: set[str] = set()
	for raw_root in PACKAGE_USER_DEPENDENCY_BOUNDARY_SCAN_ROOTS:
		root_path = ROOT / raw_root
		if root_path.is_file():
			if root_path.suffix.lower() in PACKAGE_USER_DEPENDENCY_BOUNDARY_SCAN_EXTENSIONS:
				paths.add(raw_root.replace("\\", "/"))
			continue
		if not root_path.is_dir():
			continue
		for source_path in root_path.rglob("*"):
			if not source_path.is_file():
				continue
			if source_path.suffix.lower() not in PACKAGE_USER_DEPENDENCY_BOUNDARY_SCAN_EXTENSIONS:
				continue
			paths.add(source_path.relative_to(ROOT).as_posix())
	return sorted(paths)


def audit_package_user_dependency_source(source: str, path: str) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	for line_number, raw_line in enumerate(source.splitlines(), start=1):
		line = strip_gdscript_line_comment(raw_line)
		if not line.strip():
			continue
		for process_api in PACKAGE_USER_DEPENDENCY_FORBIDDEN_PROCESS_APIS:
			if process_api in line:
				issues.append(make_package_issue(
					"package_user_external_process_api",
					path,
					"User-facing package manager scripts must not execute external processes; ordinary package install must require only Godot.",
					line=line_number,
					actual_value=process_api,
				))
		command_match = PACKAGE_USER_DEPENDENCY_FORBIDDEN_COMMAND_LITERAL_RE.search(line)
		if command_match:
			issues.append(make_package_issue(
				"package_user_external_command_literal",
				path,
				"User-facing package manager scripts must not hard-code Python, npm, Git, shell, or similar external CLI commands.",
				line=line_number,
				actual_value=command_match.group(0),
			))
		for forbidden_path in PACKAGE_USER_DEPENDENCY_FORBIDDEN_PATH_LITERALS:
			if forbidden_path in line:
				issues.append(make_package_issue(
					"package_user_package_tool_reference",
					path,
					"User-facing package manager scripts must not call or reference Python package tool paths.",
					line=line_number,
					actual_value=forbidden_path,
				))
	return issues


def make_package_user_dependency_boundary_payload(
	source_paths: list[str],
	issues: list[dict[str, Any]],
) -> dict[str, Any]:
	return {
		"ok": len(issues) == 0,
		"root": str(ROOT),
		"source_file_count": len(source_paths),
		"issue_count": len(issues),
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"scan_roots": list(PACKAGE_USER_DEPENDENCY_BOUNDARY_SCAN_ROOTS),
		"issues": issues,
	}


def package_external_command_audit(fail_on_warnings: bool = False) -> dict[str, Any]:
	paths_payload = collect_package_manifest_paths()
	scan_errors = paths_payload["errors"]
	if scan_errors:
		return make_package_external_command_audit_payload([], [], scan_errors, fail_on_warnings)

	records: list[dict[str, Any]] = []
	issues: list[dict[str, Any]] = []
	for path in paths_payload["paths"]:
		record = load_package_manifest_record(path)
		records.append(record)
		issues.extend(record["issues"])

	issues.extend(audit_package_manifest_graph(records))
	issues.extend(audit_package_path_ownership(records))
	if package_issue_error_count(issues) > 0:
		return make_package_external_command_audit_payload(records, [], issues, fail_on_warnings)

	source_paths_payload = collect_package_source_boundary_paths()
	if source_paths_payload["errors"]:
		issues.extend(source_paths_payload["errors"])
		return make_package_external_command_audit_payload(records, [], issues, fail_on_warnings)

	source_paths = [
		path
		for path in source_paths_payload["paths"]
		if Path(path).suffix.lower() in PACKAGE_EXTERNAL_COMMAND_AUDIT_SOURCE_EXTENSIONS
	]
	owner_entries = collect_package_source_owner_entries(records)
	for source_path in source_paths:
		source_owner = find_package_source_owner(source_path, owner_entries)
		if not source_owner:
			continue
		source = read_text_file(ROOT / source_path)
		if not source:
			continue
		issues.extend(audit_package_external_command_source(
			source,
			source_path,
			source_owner["package_id"],
		))
	return make_package_external_command_audit_payload(records, source_paths, issues, fail_on_warnings)


def audit_package_external_command_source(
	source: str,
	path: str,
	package_id: str,
) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	for line_number, raw_line in enumerate(source.splitlines(), start=1):
		line = strip_gdscript_line_comment(raw_line)
		if not line.strip():
			continue
		for match in PACKAGE_EXTERNAL_COMMAND_AUDIT_PROCESS_CALL_RE.finditer(line):
			api = match.group("api")
			command_literal = package_external_command_literal_from_call_line(line, match.end())
			if package_external_command_is_allowed(path, package_id, api, command_literal):
				continue
			severity = package_external_command_severity(path, package_id, api, command_literal)
			issues.append(make_boundary_issue(
				"package_external_process_call",
				path,
				"Package-owned source calls an OS external process API; keep ordinary install/use Godot-only or isolate this behind editor/debug-only behavior.",
				severity=severity,
				line=line_number,
				row_key=package_id,
				api=f"OS.{api}",
				command=command_literal,
			))
	return issues


def package_external_command_literal_from_call_line(line: str, call_args_start: int) -> str:
	literals = extract_simple_string_literals(line[call_args_start:])
	return str(literals[0]).strip() if literals else ""


def package_external_command_is_allowed(
	path: str,
	package_id: str,
	api: str,
	command_literal: str,
) -> bool:
	for allowed_call in PACKAGE_EXTERNAL_COMMAND_AUDIT_ALLOWED_CALLS:
		if (
			allowed_call["path"] == path
			and allowed_call["package_id"] == package_id
			and allowed_call["api"] == api
			and allowed_call["command"] == command_literal
		):
			return True
	return False


def package_external_command_severity(
	path: str,
	package_id: str,
	api: str,
	command_literal: str,
) -> str:
	return "warning"


def make_package_external_command_audit_payload(
	records: list[dict[str, Any]],
	source_paths: list[str],
	issues: list[dict[str, Any]],
	fail_on_warnings: bool,
) -> dict[str, Any]:
	error_count = package_issue_error_count(issues)
	warning_count = package_issue_severity_count(issues, "warning")
	info_count = package_issue_severity_count(issues, "info")
	return {
		"ok": error_count == 0 and (not fail_on_warnings or warning_count == 0),
		"root": str(ROOT),
		"report_only": not fail_on_warnings,
		"package_count": len([record for record in records if record.get("id")]),
		"source_file_count": len(source_paths),
		"issue_count": len(issues),
		"error_count": error_count,
		"warning_count": warning_count,
		"info_count": info_count,
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"severity_counts": count_issue_field(issues, "severity"),
		"api_counts": count_issue_field(issues, "api"),
		"command_counts": count_issue_field(issues, "command"),
		"issues": issues,
	}


def package_build_boundary() -> dict[str, Any]:
	with tempfile.TemporaryDirectory(prefix="gf-package-build-boundary-") as temp_dir:
		temp_root = Path(temp_dir)
		output_dir = temp_root / "packages"
		registry_path = temp_root / "registry/index.json"
		registry_source_path = temp_root / "registry/gf-registry-source.json"
		offline_bundle_path = temp_root / "gf-package-offline-bundle.zip"
		completed = subprocess.run(
			[
				sys.executable,
				"tools/build_gf_package.py",
				"--all",
				"--output-dir",
				str(output_dir),
				"--registry",
				str(registry_path),
				"--registry-source",
				str(registry_source_path),
				"--offline-bundle",
				str(offline_bundle_path),
				"--json",
			],
			cwd=ROOT,
			capture_output=True,
			text=True,
			encoding="utf-8",
			errors="replace",
			timeout=120,
		)
		issues: list[dict[str, Any]] = []
		builder_data: dict[str, Any] = {}
		if completed.returncode != 0:
			issues.append(make_package_issue(
				"package_builder_failed",
				"tools/build_gf_package.py",
				"Package builder returned a failing exit code.",
				actual_value=str(completed.returncode),
				error=trim_text(completed.stderr.strip() or completed.stdout.strip(), 1000),
			))
		try:
			builder_data = json.loads(completed.stdout or "{}")
		except json.JSONDecodeError as error:
			issues.append(make_package_issue(
				"package_builder_invalid_json",
				"tools/build_gf_package.py",
				"Package builder must return JSON for package-build-boundary.",
				error=trim_text(str(error), 300),
			))
			builder_data = {}
		if builder_data:
			issues.extend(audit_package_build_result(builder_data, registry_path))
			issues.extend(audit_package_build_registry_source_manifest(registry_source_path, registry_path))
			issues.extend(audit_package_build_offline_bundle(offline_bundle_path, registry_path, registry_source_path, builder_data))

		packages = builder_data.get("packages", []) if isinstance(builder_data.get("packages", []), list) else []
		return {
			"ok": len(issues) == 0,
			"root": str(ROOT),
			"package_count": len(packages),
			"archive_count": len([package for package in packages if package.get("archive")]),
			"registry_package_count": count_package_build_registry_entries(registry_path),
			"registry_source": registry_source_path.as_posix(),
			"registry_source_exists": registry_source_path.is_file(),
			"offline_bundle": offline_bundle_path.as_posix(),
			"offline_bundle_exists": offline_bundle_path.is_file(),
			"issue_count": len(issues),
			"issue_kind_counts": count_issue_field(issues, "kind"),
			"issues": issues,
		}


def package_install_smoke() -> dict[str, Any]:
	with tempfile.TemporaryDirectory(prefix="gf-package-install-smoke-") as temp_dir:
		temp_root = Path(temp_dir)
		output_dir = temp_root / "packages"
		registry_path = temp_root / "registry/index.json"
		issues: list[dict[str, Any]] = []
		scenarios: list[dict[str, Any]] = []

		build_data = run_package_smoke_json_command(
			"build_registry",
			[
				sys.executable,
				"tools/build_gf_package.py",
				"--all",
				"--output-dir",
				str(output_dir),
				"--registry",
				str(registry_path),
				"--json",
			],
			issues,
		)
		record_package_install_smoke_scenario(
			scenarios,
			"build_registry",
			len(issues) == 0 and bool(build_data.get("ok")),
			{"package_count": build_data.get("package_count", 0)},
		)
		if issues or not build_data.get("ok"):
			if not build_data.get("ok") and not issues:
				issues.append(make_package_issue(
					"package_install_smoke_builder_failed",
					"tools/build_gf_package.py",
					"Package builder did not report ok=true.",
					row_key="build_registry",
				))
			return make_package_install_smoke_payload(scenarios, issues, registry_path)

		run_package_install_smoke_save_install(temp_root, registry_path, scenarios, issues)
		run_package_install_smoke_dry_run(temp_root, registry_path, scenarios, issues)
		run_package_install_smoke_update_all_installed(temp_root, registry_path, scenarios, issues)
		run_package_install_smoke_framework_compatibility(temp_root, registry_path, scenarios, issues)
		run_package_install_smoke_checksum_failure(temp_root, registry_path, scenarios, issues)
		run_package_install_smoke_path_audit_failure(temp_root, registry_path, scenarios, issues)
		run_package_install_smoke_external_tool_payload_failure(temp_root, registry_path, scenarios, issues)
		run_package_install_smoke_rollback(temp_root, registry_path, scenarios, issues)
		return make_package_install_smoke_payload(scenarios, issues, registry_path)


def run_package_install_smoke_save_install(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "save_archive_install"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	assert_package_install_smoke_condition(
		bool(install_data.get("ok")),
		issues,
		scenario,
		"package_install_smoke_install_failed",
		"Installing gf.extension.save from local archives should succeed.",
	)
	for package_id in ["gf.kernel", "gf.standard.base", "gf.standard.storage", "gf.standard.deterministic", "gf.extension.save"]:
		assert_package_install_smoke_condition(
			package_id in install_data.get("installed_packages", []),
			issues,
			scenario,
			"package_install_smoke_missing_installed_package",
			f"Installed package set should include {package_id}.",
			expected_value=package_id,
		)
	for relative_path in [
		"addons/gf/plugin.gd",
		"addons/gf/standard/utilities/storage/gf_storage_utility.gd",
		"addons/gf/extensions/save/gf_extension.json",
	]:
		assert_package_install_smoke_condition(
			(project_root / relative_path).is_file(),
			issues,
			scenario,
			"package_install_smoke_missing_installed_file",
			f"Installed package should write {relative_path}.",
			expected_value=relative_path,
		)
	verify_data = run_package_smoke_json_command(
		scenario,
		[
			sys.executable,
			"tools/gf_package_resolver.py",
			"verify-lock",
			"--registry",
			str(registry_path),
			"--lockfile",
			str(project_root / ".gf/packages.lock.json"),
			"--json",
		],
		issues,
	)
	assert_package_install_smoke_condition(
		bool(verify_data.get("ok")),
		issues,
		scenario,
		"package_install_smoke_verify_lock_failed",
		"Installer-written lockfile should verify against the registry.",
	)
	lockfile_data = read_json_object(project_root / ".gf/packages.lock.json")
	installed = lockfile_data.get("installed", {}) if isinstance(lockfile_data.get("installed", {}), dict) else {}
	for package_id in ["gf.kernel", "gf.standard.base", "gf.standard.storage", "gf.standard.deterministic", "gf.extension.save"]:
		entry = installed.get(package_id, {})
		files = entry.get("files", []) if isinstance(entry, dict) else []
		assert_package_install_smoke_condition(
			isinstance(files, list) and len(files) > 0,
			issues,
			scenario,
			"package_install_smoke_missing_lockfile_files",
			f"Installed lockfile entry should record exact package files for {package_id}.",
			expected_value=package_id,
		)
	save_entry = installed.get("gf.extension.save", {}) if isinstance(installed.get("gf.extension.save", {}), dict) else {}
	storage_entry = installed.get("gf.standard.storage", {}) if isinstance(installed.get("gf.standard.storage", {}), dict) else {}
	assert_package_install_smoke_condition(
		"addons/gf/extensions/save/gf_extension.json" in uninstall_smoke_string_list(save_entry.get("files", [])),
		issues,
		scenario,
		"package_install_smoke_save_lockfile_file_missing",
		"Save package lockfile entry should include its extension manifest file.",
		expected_value="addons/gf/extensions/save/gf_extension.json",
	)
	assert_package_install_smoke_condition(
		"addons/gf/standard/utilities/storage/gf_storage_utility.gd" in uninstall_smoke_string_list(storage_entry.get("files", [])),
		issues,
		scenario,
		"package_install_smoke_storage_lockfile_file_missing",
		"Storage package lockfile entry should include its storage utility file.",
		expected_value="addons/gf/standard/utilities/storage/gf_storage_utility.gd",
	)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"installed_file_count": install_data.get("installed_file_count", 0)},
	)


def run_package_install_smoke_dry_run(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "dry_run_no_mutation"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--dry-run",
			"--json",
		],
		issues,
	)
	assert_package_install_smoke_condition(
		bool(install_data.get("ok")),
		issues,
		scenario,
		"package_install_smoke_dry_run_failed",
		"Dry-run install should validate local archives successfully.",
	)
	assert_package_install_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"package_install_smoke_dry_run_mutated_project",
		"Dry-run install must not write files to the target project.",
	)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"installed_file_count": install_data.get("installed_file_count", 0)},
	)


def run_package_install_smoke_update_all_installed(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "update_all_installed"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	scenario_registry_path = temp_root / f"{scenario}_registry/index.json"
	scenario_registry_path.parent.mkdir(parents=True, exist_ok=True)
	shutil.copy2(registry_path, scenario_registry_path)
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(scenario_registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	registry_data = read_json_object(scenario_registry_path)
	packages = registry_data.get("packages", {}) if isinstance(registry_data.get("packages", {}), dict) else {}
	storage_entry = packages.get("gf.standard.storage", {}) if isinstance(packages.get("gf.standard.storage", {}), dict) else {}
	storage_entry["version"] = "update-smoke"
	packages["gf.standard.storage"] = storage_entry
	registry_data["packages"] = packages
	write_json_object(scenario_registry_path, registry_data)
	update_data = run_package_installer_smoke(
		scenario,
		[
			"update",
			"--all-installed",
			"--registry",
			str(scenario_registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	lockfile_data = read_json_object(project_root / ".gf/packages.lock.json")
	installed = lockfile_data.get("installed", {}) if isinstance(lockfile_data.get("installed", {}), dict) else {}
	updated_storage_entry = (
		installed.get("gf.standard.storage", {})
		if isinstance(installed.get("gf.standard.storage", {}), dict)
		else {}
	)
	storage_reasons = uninstall_smoke_string_list(updated_storage_entry.get("reason", []))
	assert_package_install_smoke_condition(
		bool(install_data.get("ok")) and bool(update_data.get("ok")),
		issues,
		scenario,
		"package_install_smoke_update_all_failed",
		"update --all-installed should update already installed packages from the selected registry.",
		actual_value=str(update_data.get("issues", [])),
	)
	assert_package_install_smoke_condition(
		"gf.standard.storage" in uninstall_smoke_string_list(update_data.get("updated_packages", [])),
		issues,
		scenario,
		"package_install_smoke_update_all_missing_updated_package",
		"Changed installed package should be reported as updated.",
		expected_value="gf.standard.storage",
	)
	assert_package_install_smoke_condition(
		updated_storage_entry.get("version") == "update-smoke",
		issues,
		scenario,
		"package_install_smoke_update_all_lockfile_not_updated",
		"update --all-installed should rewrite the lockfile entry from the current registry.",
		actual_value=str(updated_storage_entry.get("version", "")),
	)
	assert_package_install_smoke_condition(
		"dependency" in storage_reasons and "manual" not in storage_reasons,
		issues,
		scenario,
		"package_install_smoke_update_all_reason_polluted",
		"Updating installed dependency packages should preserve dependency reason without adding manual.",
		actual_value=str(storage_reasons),
	)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"updated_packages": update_data.get("updated_packages", []),
			"updated_file_count": update_data.get("updated_file_count", 0),
		},
	)


def run_package_install_smoke_framework_compatibility(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "framework_compatibility_failure_no_mutation"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	plugin_cfg_path = project_root / "addons/gf/plugin.cfg"
	plugin_cfg_path.parent.mkdir(parents=True, exist_ok=True)
	plugin_cfg_path.write_text("[plugin]\nversion=\"1.0.0\"\n", encoding="utf-8")
	incompatible_registry_path = temp_root / "incompatible_registry/index.json"
	registry_data = read_json_object(registry_path)
	registry_data["framework_version"] = "9.0.0"
	registry_data["minimum_framework_version"] = "9.0.0"
	registry_data["maximum_framework_version_exclusive"] = "10.0.0"
	packages = registry_data.get("packages", {})
	if isinstance(packages, dict):
		for package_entry in packages.values():
			if not isinstance(package_entry, dict):
				continue
			package_entry["minimum_framework_version"] = "9.0.0"
			package_entry["maximum_framework_version_exclusive"] = "10.0.0"
	write_json_object(incompatible_registry_path, registry_data)
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(incompatible_registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	install_issues = "\n".join(uninstall_smoke_string_list(install_data.get("issues", [])))
	assert_package_install_smoke_condition(
		not bool(install_data.get("ok")) and "minimum_framework_version 9.0.0" in install_issues,
		issues,
		scenario,
		"package_install_smoke_framework_compatibility_not_rejected",
		"Installer should reject packages that require a newer GF framework version before staging archives.",
		actual_value=install_issues,
	)
	assert_package_install_smoke_condition(
		not (project_root / ".gf/packages.lock.json").exists()
		and not (project_root / "addons/gf/extensions/save/gf_extension.json").exists(),
		issues,
		scenario,
		"package_install_smoke_framework_compatibility_mutated_project",
		"Framework compatibility failure must not write lockfiles or package files.",
	)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"issue_count": len(uninstall_smoke_string_list(install_data.get("issues", [])))},
	)


def run_package_install_smoke_checksum_failure(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "checksum_failure_no_mutation"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	bad_registry_path = temp_root / "bad_registry/index.json"
	registry_data = read_json_object(registry_path)
	registry_data["packages"]["gf.extension.save"]["sha256"] = "0" * 64
	write_json_object(bad_registry_path, registry_data)
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(bad_registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	assert_package_install_smoke_condition(
		not bool(install_data.get("ok")),
		issues,
		scenario,
		"package_install_smoke_checksum_not_rejected",
		"Checksum mismatch should fail package installation.",
	)
	assert_package_install_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"package_install_smoke_checksum_failure_mutated_project",
		"Checksum mismatch must not write files to the target project.",
	)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"rolled_back": install_data.get("rolled_back", False)},
	)


def run_package_install_smoke_path_audit_failure(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "path_audit_failure_no_mutation"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	bad_registry_path = temp_root / "bad_path_registry/index.json"
	malicious_archive = temp_root / "malicious/storage.zip"
	malicious_archive.parent.mkdir(parents=True, exist_ok=True)
	with zipfile.ZipFile(malicious_archive, "w", compression=zipfile.ZIP_DEFLATED) as archive:
		archive.writestr("README.md", "outside addons/gf")
	registry_data = read_json_object(registry_path)
	storage_entry = registry_data["packages"]["gf.standard.storage"]
	storage_entry["archive"] = os.path.relpath(malicious_archive, bad_registry_path.parent).replace("\\", "/")
	storage_entry["sha256"] = sha256_file(malicious_archive)
	storage_entry["size_bytes"] = malicious_archive.stat().st_size
	write_json_object(bad_registry_path, registry_data)
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.standard.storage",
			"--registry",
			str(bad_registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	assert_package_install_smoke_condition(
		not bool(install_data.get("ok")),
		issues,
		scenario,
		"package_install_smoke_path_audit_not_rejected",
		"Archive entries outside registry-owned paths should fail package installation.",
	)
	assert_package_install_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"package_install_smoke_path_audit_mutated_project",
		"Archive path audit failure must not write files to the target project.",
	)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"rolled_back": install_data.get("rolled_back", False)},
	)


def run_package_install_smoke_external_tool_payload_failure(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "external_tool_payload_failure_no_mutation"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	bad_registry_path = temp_root / "external_tool_registry/index.json"
	bad_archive = temp_root / "external_tool/gf-extension-save.zip"
	bad_archive.parent.mkdir(parents=True, exist_ok=True)
	with zipfile.ZipFile(bad_archive, "w", compression=zipfile.ZIP_DEFLATED) as archive:
		archive.writestr("addons/gf/extensions/save/install.py", "# fixture\n")
		archive.writestr("addons/gf/extensions/save/package.json", "{}\n")
	registry_data = read_json_object(registry_path)
	save_entry = registry_data["packages"]["gf.extension.save"]
	save_entry["archive"] = os.path.relpath(bad_archive, bad_registry_path.parent).replace("\\", "/")
	save_entry["sha256"] = sha256_file(bad_archive)
	save_entry["size_bytes"] = bad_archive.stat().st_size
	write_json_object(bad_registry_path, registry_data)
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(bad_registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	install_issues = "\n".join(uninstall_smoke_string_list(install_data.get("issues", [])))
	assert_package_install_smoke_condition(
		not bool(install_data.get("ok")) and "external tool payload" in install_issues,
		issues,
		scenario,
		"package_install_smoke_external_tool_payload_not_rejected",
		"Runtime package archive entries for Python/npm tools should fail package installation.",
	)
	assert_package_install_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"package_install_smoke_external_tool_payload_mutated_project",
		"External tool payload audit failure must not write files to the target project.",
	)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"rolled_back": install_data.get("rolled_back", False)},
	)


def run_package_install_smoke_rollback(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "copy_failure_rolls_back"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--simulate-copy-failure-after",
			"5",
			"--json",
		],
		issues,
		allow_failure=True,
	)
	assert_package_install_smoke_condition(
		not bool(install_data.get("ok")) and bool(install_data.get("rolled_back")),
		issues,
		scenario,
		"package_install_smoke_copy_failure_not_rolled_back",
		"Simulated copy failure should fail and report rollback.",
	)
	assert_package_install_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"package_install_smoke_copy_failure_left_files",
		"Rollback should remove package files and avoid writing the lockfile.",
	)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"rolled_back": install_data.get("rolled_back", False)},
	)


def run_package_installer_smoke(
	scenario: str,
	args: list[str],
	issues: list[dict[str, Any]],
	allow_failure: bool = False,
) -> dict[str, Any]:
	return run_package_smoke_json_command(
		scenario,
		[sys.executable, "tools/gf_package_installer.py", *args],
		issues,
		allow_failure=allow_failure,
	)


def assert_package_install_smoke_condition(
	condition: bool,
	issues: list[dict[str, Any]],
	scenario: str,
	kind: str,
	message: str,
	**extra: Any,
) -> None:
	if condition:
		return
	issues.append(make_package_issue(kind, "tools/gf_package_installer.py", message, row_key=scenario, **extra))


def record_package_install_smoke_scenario(
	scenarios: list[dict[str, Any]],
	name: str,
	ok: bool,
	details: dict[str, Any] | None = None,
) -> None:
	scenario = {"name": name, "ok": ok}
	if details:
		scenario.update(details)
	scenarios.append(scenario)


def make_package_install_smoke_payload(
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
	registry_path: Path,
) -> dict[str, Any]:
	return {
		"ok": len(issues) == 0 and all(bool(scenario.get("ok")) for scenario in scenarios),
		"root": str(ROOT),
		"registry": registry_path.as_posix(),
		"scenario_count": len(scenarios),
		"issue_count": len(issues),
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"scenarios": scenarios,
		"issues": issues,
	}


def network_install_smoke() -> dict[str, Any]:
	with tempfile.TemporaryDirectory(prefix="gf-network-install-smoke-") as temp_dir:
		temp_root = Path(temp_dir)
		server_root = temp_root / "server"
		output_dir = server_root / "packages"
		registry_path = server_root / "registry/index.json"
		issues: list[dict[str, Any]] = []
		scenarios: list[dict[str, Any]] = []

		build_data = run_package_smoke_json_command(
			"build_registry",
			[
				sys.executable,
				"tools/build_gf_package.py",
				"--all",
				"--output-dir",
				str(output_dir),
				"--registry",
				str(registry_path),
				"--json",
			],
			issues,
		)
		record_package_install_smoke_scenario(
			scenarios,
			"build_registry",
			len(issues) == 0 and bool(build_data.get("ok")),
			{"package_count": build_data.get("package_count", 0)},
		)
		if issues or not build_data.get("ok"):
			if not build_data.get("ok") and not issues:
				issues.append(make_package_issue(
					"network_install_smoke_builder_failed",
					"tools/build_gf_package.py",
					"Package builder did not report ok=true.",
					row_key="build_registry",
				))
			return make_network_install_smoke_payload(scenarios, issues, registry_path, "")

		server, thread, base_url = start_network_install_smoke_server(server_root, issues)
		if server is None or thread is None:
			return make_network_install_smoke_payload(scenarios, issues, registry_path, "")
		try:
			registry_url = network_install_smoke_url(base_url, "registry/index.json")
			run_network_install_smoke_remote_save_install(temp_root, registry_url, registry_path, scenarios, issues)
			run_network_install_smoke_dry_run(temp_root, registry_url, scenarios, issues)
			run_network_install_smoke_source_mirror_install(temp_root, base_url, server_root, scenarios, issues)
			run_network_install_smoke_package_signature_rejection(temp_root, base_url, registry_path, server_root, scenarios, issues)
			run_network_install_smoke_external_tool_payload_failure(temp_root, base_url, registry_path, server_root, scenarios, issues)
			run_network_install_smoke_checksum_failure(temp_root, base_url, registry_path, server_root, scenarios, issues)
			run_network_install_smoke_download_failure(temp_root, base_url, registry_path, server_root, scenarios, issues)
			run_network_install_smoke_copy_failure_rollback(temp_root, registry_url, scenarios, issues)
		finally:
			stop_network_install_smoke_server(server, thread)
		return make_network_install_smoke_payload(scenarios, issues, registry_path, base_url)


def run_network_install_smoke_remote_save_install(
	temp_root: Path,
	registry_url: str,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "remote_save_install"
	start_issue_count = len(issues)
	project_root = temp_root / scenario / "project"
	cache_root = temp_root / scenario / "cache"
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			registry_url,
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
	)
	assert_network_install_smoke_condition(
		bool(install_data.get("ok")),
		issues,
		scenario,
		"network_install_smoke_remote_install_failed",
		"Installing gf.extension.save from an HTTP registry should succeed.",
	)
	for relative_path in [
		"addons/gf/plugin.gd",
		"addons/gf/standard/utilities/storage/gf_storage_utility.gd",
		"addons/gf/extensions/save/gf_extension.json",
	]:
		assert_network_install_smoke_condition(
			(project_root / relative_path).is_file(),
			issues,
			scenario,
			"network_install_smoke_missing_installed_file",
			f"Network install should write {relative_path}.",
			expected_value=relative_path,
		)
	lockfile_data = read_json_object(project_root / ".gf/packages.lock.json")
	installed = lockfile_data.get("installed", {}) if isinstance(lockfile_data.get("installed", {}), dict) else {}
	save_entry = installed.get("gf.extension.save", {}) if isinstance(installed.get("gf.extension.save", {}), dict) else {}
	assert_network_install_smoke_condition(
		str(save_entry.get("archive", "")).startswith("http://127.0.0.1:"),
		issues,
		scenario,
		"network_install_smoke_lockfile_archive_not_url",
		"Network install should persist the resolved archive URL in the lockfile.",
		actual_value=str(save_entry.get("archive", "")),
	)
	assert_network_install_smoke_condition(
		network_install_cache_has_file(cache_root, "registries", ".json")
		and network_install_cache_has_file(cache_root, "archives", ".zip"),
		issues,
		scenario,
		"network_install_smoke_cache_missing",
		"Network install should cache the registry and downloaded archives.",
	)
	verify_data = run_uninstall_smoke_resolver(
		scenario,
		[
			"verify-lock",
			"--registry",
			str(registry_path),
			"--lockfile",
			str(project_root / ".gf/packages.lock.json"),
			"--json",
		],
		issues,
	)
	assert_network_install_smoke_condition(
		bool(verify_data.get("ok")),
		issues,
		scenario,
		"network_install_smoke_verify_lock_failed",
		"Network installer-written lockfile should verify against the registry.",
	)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"installed_file_count": install_data.get("installed_file_count", 0),
			"cache_file_count": network_install_cache_file_count(cache_root),
		},
	)


def run_network_install_smoke_dry_run(
	temp_root: Path,
	registry_url: str,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "remote_dry_run_no_project_mutation"
	start_issue_count = len(issues)
	project_root = temp_root / scenario / "project"
	cache_root = temp_root / scenario / "cache"
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			registry_url,
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--dry-run",
			"--json",
		],
		issues,
	)
	assert_network_install_smoke_condition(
		bool(install_data.get("ok")) and bool(install_data.get("dry_run")),
		issues,
		scenario,
		"network_install_smoke_dry_run_failed",
		"Network dry-run should resolve and validate archives successfully.",
	)
	assert_network_install_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"network_install_smoke_dry_run_mutated_project",
		"Network dry-run must not write files to the target project.",
	)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"cache_file_count": network_install_cache_file_count(cache_root)},
	)


def run_network_install_smoke_source_mirror_install(
	temp_root: Path,
	base_url: str,
	server_root: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "remote_source_mirror_install"
	start_issue_count = len(issues)
	project_root = temp_root / scenario / "project"
	cache_root = temp_root / scenario / "cache"
	source_path = server_root / "sources/index.json"
	registry_path = server_root / "registry/index.json"
	write_json_object(source_path, {
		"schema_version": 1,
		"default_channel": "stable",
		"channels": {
			"stable": {
				"registry": "../missing/index.json",
				"registry_sha256": sha256_file(registry_path),
				"registry_size_bytes": registry_path.stat().st_size,
				"mirrors": ["../registry/index.json"],
			},
		},
	})
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			network_install_smoke_url(base_url, "sources/index.json"),
			"--channel",
			"stable",
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
	)
	assert_network_install_smoke_condition(
		bool(install_data.get("ok")),
		issues,
		scenario,
		"network_install_smoke_source_mirror_failed",
		"Network installer should use a registry source mirror when the primary channel registry is unavailable.",
	)
	assert_network_install_smoke_condition(
		(project_root / "addons/gf/extensions/save/gf_extension.json").is_file(),
		issues,
		scenario,
		"network_install_smoke_source_mirror_missing_file",
		"Registry source mirror install should write the selected package files.",
	)
	assert_network_install_smoke_condition(
		network_install_cache_has_file(cache_root, "registries", ".json")
		and network_install_cache_has_file(cache_root, "archives", ".zip"),
		issues,
		scenario,
		"network_install_smoke_source_mirror_cache_missing",
		"Registry source mirror install should cache the source, registry, and downloaded archives.",
	)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"cache_file_count": network_install_cache_file_count(cache_root)},
	)


def run_network_install_smoke_package_signature_rejection(
	temp_root: Path,
	base_url: str,
	registry_path: Path,
	server_root: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "remote_package_signature_rejection_no_mutation"
	start_issue_count = len(issues)
	project_root = temp_root / scenario / "project"
	cache_root = temp_root / scenario / "cache"
	signed_registry_path = server_root / "signed_package/index.json"
	registry_data = read_json_object(registry_path)
	packages = registry_data.get("packages", {})
	if isinstance(packages, dict):
		save_entry = packages.get("gf.extension.save", {})
		if isinstance(save_entry, dict):
			save_entry["signature_url"] = "gf-extension-save-unreleased.zip.sig"
			packages["gf.extension.save"] = save_entry
	write_json_object(signed_registry_path, registry_data)
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			network_install_smoke_url(base_url, "signed_package/index.json"),
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	install_issues = uninstall_smoke_string_list(install_data.get("issues", []))
	assert_network_install_smoke_condition(
		not bool(install_data.get("ok"))
		and any("Registry package signature field is not supported until native verification is implemented" in issue for issue in install_issues),
		issues,
		scenario,
		"network_install_smoke_package_signature_not_rejected",
		"Network installer must reject registry package signature fields until native verification exists.",
		actual_value=str(install_issues),
	)
	assert_network_install_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"network_install_smoke_package_signature_mutated_project",
		"Registry package signature rejection must not write files to the target project.",
	)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"cache_file_count": network_install_cache_file_count(cache_root)},
	)


def run_network_install_smoke_external_tool_payload_failure(
	temp_root: Path,
	base_url: str,
	registry_path: Path,
	server_root: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "remote_external_tool_payload_failure_no_mutation"
	start_issue_count = len(issues)
	project_root = temp_root / scenario / "project"
	cache_root = temp_root / scenario / "cache"
	bad_registry_path = server_root / "external_tool/index.json"
	bad_archive = server_root / "external_tool/gf-extension-save.zip"
	bad_archive.parent.mkdir(parents=True, exist_ok=True)
	with zipfile.ZipFile(bad_archive, "w", compression=zipfile.ZIP_DEFLATED) as archive:
		archive.writestr("addons/gf/extensions/save/install.py", "# fixture\n")
		archive.writestr("addons/gf/extensions/save/package.json", "{}\n")
	registry_data = read_json_object(registry_path)
	save_entry = registry_data["packages"]["gf.extension.save"]
	save_entry["archive"] = "gf-extension-save.zip"
	save_entry["sha256"] = sha256_file(bad_archive)
	save_entry["size_bytes"] = bad_archive.stat().st_size
	write_json_object(bad_registry_path, registry_data)
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			network_install_smoke_url(base_url, "external_tool/index.json"),
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	install_issues = "\n".join(uninstall_smoke_string_list(install_data.get("issues", [])))
	assert_network_install_smoke_condition(
		not bool(install_data.get("ok")) and "external tool payload" in install_issues,
		issues,
		scenario,
		"network_install_smoke_external_tool_payload_not_rejected",
		"Network installer must reject runtime package archives that contain Python/npm tool payloads.",
		actual_value=install_issues,
	)
	assert_network_install_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"network_install_smoke_external_tool_payload_mutated_project",
		"Remote external tool payload rejection must not write files to the target project.",
	)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"cache_file_count": network_install_cache_file_count(cache_root)},
	)


def run_network_install_smoke_checksum_failure(
	temp_root: Path,
	base_url: str,
	registry_path: Path,
	server_root: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "remote_checksum_failure_no_mutation"
	start_issue_count = len(issues)
	project_root = temp_root / scenario / "project"
	cache_root = temp_root / scenario / "cache"
	bad_registry_path = server_root / "bad_checksum/index.json"
	registry_data = read_json_object(registry_path)
	registry_data["packages"]["gf.extension.save"]["sha256"] = "0" * 64
	write_json_object(bad_registry_path, registry_data)
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			network_install_smoke_url(base_url, "bad_checksum/index.json"),
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	assert_network_install_smoke_condition(
		not bool(install_data.get("ok")),
		issues,
		scenario,
		"network_install_smoke_checksum_not_rejected",
		"Network checksum mismatch should fail package installation.",
	)
	assert_network_install_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"network_install_smoke_checksum_failure_mutated_project",
		"Network checksum failure must not write files to the target project.",
	)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"cache_file_count": network_install_cache_file_count(cache_root)},
	)


def run_network_install_smoke_download_failure(
	temp_root: Path,
	base_url: str,
	registry_path: Path,
	server_root: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "remote_download_failure_no_mutation"
	start_issue_count = len(issues)
	project_root = temp_root / scenario / "project"
	cache_root = temp_root / scenario / "cache"
	bad_registry_path = server_root / "bad_download/index.json"
	registry_data = read_json_object(registry_path)
	registry_data["packages"]["gf.extension.save"]["archive"] = "../missing/gf-extension-save-unreleased.zip"
	write_json_object(bad_registry_path, registry_data)
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			network_install_smoke_url(base_url, "bad_download/index.json"),
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	assert_network_install_smoke_condition(
		not bool(install_data.get("ok")),
		issues,
		scenario,
		"network_install_smoke_download_failure_not_rejected",
		"Missing remote archive should fail package installation.",
	)
	assert_network_install_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"network_install_smoke_download_failure_mutated_project",
		"Remote download failure must not write files to the target project.",
	)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"cache_file_count": network_install_cache_file_count(cache_root)},
	)


def run_network_install_smoke_copy_failure_rollback(
	temp_root: Path,
	registry_url: str,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "remote_copy_failure_rolls_back"
	start_issue_count = len(issues)
	project_root = temp_root / scenario / "project"
	cache_root = temp_root / scenario / "cache"
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			registry_url,
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--simulate-copy-failure-after",
			"5",
			"--json",
		],
		issues,
		allow_failure=True,
	)
	assert_network_install_smoke_condition(
		not bool(install_data.get("ok")) and bool(install_data.get("rolled_back")),
		issues,
		scenario,
		"network_install_smoke_copy_failure_not_rolled_back",
		"Simulated copy failure after network download should fail and report rollback.",
	)
	assert_network_install_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"network_install_smoke_copy_failure_left_files",
		"Rollback after network download should remove package files and avoid writing the lockfile.",
	)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"rolled_back": install_data.get("rolled_back", False), "cache_file_count": network_install_cache_file_count(cache_root)},
	)


def start_network_install_smoke_server(root: Path, issues: list[dict[str, Any]]) -> tuple[Any, threading.Thread | None, str]:
	class QuietPackageHandler(http.server.SimpleHTTPRequestHandler):
		flaky_counts: dict[str, int] = {}

		def do_GET(self) -> None:
			parsed_path = urllib.parse.urlparse(self.path)
			if parsed_path.path.startswith("/redirect/"):
				target = "/" + parsed_path.path.removeprefix("/redirect/")
				if parsed_path.query:
					target = f"{target}?{parsed_path.query}"
				self.send_response(302)
				self.send_header("Location", target)
				self.end_headers()
				return
			if parsed_path.path.startswith("/flaky-once/"):
				target_path = "/" + parsed_path.path.removeprefix("/flaky-once/")
				target = target_path
				if parsed_path.query:
					target = f"{target}?{parsed_path.query}"
				request_count = QuietPackageHandler.flaky_counts.get(target_path, 0)
				if request_count == 0:
					QuietPackageHandler.flaky_counts[target_path] = 1
					self.send_response(500)
					self.end_headers()
					self.wfile.write(b"temporary fixture failure")
					return
				self.path = target
			super().do_GET()

		def log_message(self, _format: str, *_args: Any) -> None:
			return

	try:
		handler = functools.partial(QuietPackageHandler, directory=str(root))
		server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
		thread = threading.Thread(target=server.serve_forever, daemon=True)
		thread.start()
		return server, thread, f"http://127.0.0.1:{server.server_port}"
	except OSError as error:
		issues.append(make_package_issue(
			"network_install_smoke_server_failed",
			"tools/gf_maintenance.py",
			"Could not start local HTTP fixture server.",
			error=trim_text(str(error), 300),
		))
		return None, None, ""


def stop_network_install_smoke_server(server: Any, thread: threading.Thread) -> None:
	server.shutdown()
	server.server_close()
	thread.join(timeout=5)


def network_install_smoke_url(base_url: str, relative_path: str) -> str:
	return base_url.rstrip("/") + "/" + relative_path.strip("/")


def network_install_cache_has_file(cache_root: Path, child_dir: str, suffix: str) -> bool:
	root = cache_root / child_dir
	return root.is_dir() and any(path.is_file() and path.suffix == suffix for path in root.rglob("*"))


def network_install_cache_file_count(cache_root: Path) -> int:
	if not cache_root.is_dir():
		return 0
	return len([path for path in cache_root.rglob("*") if path.is_file()])


def assert_network_install_smoke_condition(
	condition: bool,
	issues: list[dict[str, Any]],
	scenario: str,
	kind: str,
	message: str,
	**extra: Any,
) -> None:
	if condition:
		return
	issues.append(make_package_issue(kind, "tools/gf_package_installer.py", message, row_key=scenario, **extra))


def make_network_install_smoke_payload(
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
	registry_path: Path,
	base_url: str,
) -> dict[str, Any]:
	return {
		"ok": len(issues) == 0 and all(bool(scenario.get("ok")) for scenario in scenarios),
		"root": str(ROOT),
		"registry": registry_path.as_posix(),
		"base_url": base_url,
		"scenario_count": len(scenarios),
		"issue_count": len(issues),
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"scenarios": scenarios,
		"issues": issues,
	}


def read_json_object(path: Path) -> dict[str, Any]:
	try:
		data = json.loads(path.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError):
		return {}
	return data if isinstance(data, dict) else {}


def write_json_object(path: Path, data: dict[str, Any]) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sha256_file(path: Path) -> str:
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for chunk in iter(lambda: handle.read(1024 * 1024), b""):
			digest.update(chunk)
	return digest.hexdigest()


def project_has_files(project_root: Path) -> bool:
	if not project_root.exists():
		return False
	return any(path.is_file() for path in project_root.rglob("*"))


def preset_smoke() -> dict[str, Any]:
	with tempfile.TemporaryDirectory(prefix="gf-preset-smoke-") as temp_dir:
		temp_root = Path(temp_dir)
		output_dir = temp_root / "packages"
		registry_path = temp_root / "registry/index.json"
		issues: list[dict[str, Any]] = []
		scenarios: list[dict[str, Any]] = []

		build_data = run_package_smoke_json_command(
			"build_registry",
			[
				sys.executable,
				"tools/build_gf_package.py",
				"--all",
				"--output-dir",
				str(output_dir),
				"--registry",
				str(registry_path),
				"--json",
			],
			issues,
		)
		record_package_install_smoke_scenario(
			scenarios,
			"build_registry",
			len(issues) == 0 and bool(build_data.get("ok")),
			{"package_count": build_data.get("package_count", 0)},
		)
		if issues or not build_data.get("ok"):
			if not build_data.get("ok") and not issues:
				issues.append(make_package_issue(
					"preset_smoke_builder_failed",
					"tools/build_gf_package.py",
					"Package builder did not report ok=true.",
					row_key="build_registry",
				))
			return make_preset_smoke_payload(scenarios, issues, registry_path)

		run_preset_smoke_registry_entries(registry_path, scenarios, issues)
		run_preset_smoke_install_plan(temp_root, registry_path, scenarios, issues)
		run_preset_smoke_physical_install(temp_root, registry_path, scenarios, issues)
		run_preset_smoke_physical_uninstall_prunes(temp_root, registry_path, scenarios, issues)
		run_preset_smoke_manual_pin_survives_uninstall(temp_root, registry_path, scenarios, issues)
		return make_preset_smoke_payload(scenarios, issues, registry_path)


def run_preset_smoke_registry_entries(
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "preset_registry_entries"
	start_issue_count = len(issues)
	registry_data = read_json_object(registry_path)
	packages = registry_data.get("packages", {}) if isinstance(registry_data.get("packages", {}), dict) else {}
	expected = {
		"gf.preset.save": ["gf.extension.save"],
		"gf.preset.rpg_save_dialogue": ["gf.extension.save", "gf.extension.dialogue", "gf.extension.domain"],
		"gf.preset.2d_toolkit": [
			"gf.extension.camera",
			"gf.extension.physics",
			"gf.extension.flow",
			"gf.extension.interaction",
			"gf.standard.ui",
		],
	}
	for preset_id, included_ids in expected.items():
		entry = packages.get(preset_id, {}) if isinstance(packages.get(preset_id, {}), dict) else {}
		assert_preset_smoke_condition(
			bool(entry),
			issues,
			scenario,
			"preset_smoke_missing_registry_entry",
			"Generated registry should include preset package entries.",
			row_key=preset_id,
		)
		assert_preset_smoke_condition(
			entry.get("kind") == "preset",
			issues,
			scenario,
			"preset_smoke_registry_kind_wrong",
			"Preset registry entry should keep kind=preset.",
			row_key=preset_id,
		)
		assert_preset_smoke_condition(
			not str(entry.get("archive", "")).strip()
			and not str(entry.get("sha256", "")).strip()
			and int_value(entry.get("size_bytes", 0)) == 0
			and not uninstall_smoke_string_list(entry.get("paths", [])),
			issues,
			scenario,
			"preset_smoke_registry_declares_payload",
			"Preset registry entry must not own archive, sha256, size, or paths.",
			row_key=preset_id,
		)
		entry_packages = uninstall_smoke_string_list(entry.get("packages", []))
		for included_id in included_ids:
			assert_preset_smoke_condition(
				included_id in entry_packages and included_id in packages,
				issues,
				scenario,
				"preset_smoke_registry_missing_included_package",
				"Preset registry entry should list concrete packages that also exist in the registry.",
				row_key=preset_id,
				expected_value=included_id,
			)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"preset_count": len(expected)},
	)


def run_preset_smoke_install_plan(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "rpg_preset_install_plan"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	lockfile_path = project_root / ".gf/packages.lock.json"
	install_data = run_uninstall_smoke_resolver(
		scenario,
		[
			"install-plan",
			"gf.preset.rpg_save_dialogue",
			"--registry",
			str(registry_path),
			"--lockfile",
			str(lockfile_path),
			"--write-lock",
			"--json",
		],
		issues,
	)
	installed = uninstall_smoke_installed(install_data)
	for package_id in [
		"gf.preset.rpg_save_dialogue",
		"gf.extension.save",
		"gf.extension.dialogue",
		"gf.extension.domain",
		"gf.standard.storage",
		"gf.standard.config",
		"gf.standard.deterministic",
		"gf.standard.base",
		"gf.kernel",
	]:
		assert_preset_smoke_condition(
			package_id in installed,
			issues,
			scenario,
			"preset_smoke_install_plan_missing_package",
			"Preset install plan should include the preset, concrete packages, and their dependencies.",
			row_key=package_id,
		)
	assert_preset_smoke_condition(
		"manual" in package_lock_reasons(installed, "gf.preset.rpg_save_dialogue")
		and "dependency" in package_lock_reasons(installed, "gf.extension.save")
		and "gf.preset.rpg_save_dialogue" in package_lock_required_by(installed, "gf.extension.save"),
		issues,
		scenario,
		"preset_smoke_install_plan_reasons_wrong",
		"Preset should pin itself while included packages remain dependency-owned by the preset.",
	)
	verify_data = run_uninstall_smoke_resolver(
		scenario,
		[
			"verify-lock",
			"--registry",
			str(registry_path),
			"--lockfile",
			str(lockfile_path),
			"--json",
		],
		issues,
	)
	assert_preset_smoke_condition(
		bool(install_data.get("ok")) and bool(verify_data.get("ok")),
		issues,
		scenario,
		"preset_smoke_install_plan_verify_failed",
		"Preset install-plan lockfile should verify against the registry.",
	)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"installed_count": install_data.get("installed_count", 0)},
	)


def run_preset_smoke_physical_install(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "physical_preset_install"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.preset.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	installed = read_uninstall_smoke_lock_installed(project_root)
	preset_entry = installed.get("gf.preset.save", {}) if isinstance(installed.get("gf.preset.save", {}), dict) else {}
	assert_preset_smoke_condition(
		bool(install_data.get("ok"))
		and "gf.preset.save" in installed
		and "gf.extension.save" in installed
		and not uninstall_smoke_string_list(preset_entry.get("files", []))
		and (project_root / "addons/gf/extensions/save/gf_extension.json").is_file()
		and (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").is_file(),
		issues,
		scenario,
		"preset_smoke_physical_install_failed",
		"Installing a preset should copy concrete package files and record a no-file preset lock entry.",
		actual_value=str(install_data.get("issues", [])),
	)
	verify_uninstall_smoke_physical_lock(project_root, registry_path, scenario, issues)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"installed_file_count": install_data.get("installed_file_count", 0)},
	)


def run_preset_smoke_physical_uninstall_prunes(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "physical_preset_uninstall_prunes"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.preset.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	uninstall_data = run_package_installer_smoke(
		scenario,
		[
			"uninstall",
			"gf.preset.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	installed = uninstall_smoke_installed(uninstall_data)
	assert_preset_smoke_condition(
		bool(uninstall_data.get("ok"))
		and "gf.preset.save" not in installed
		and "gf.extension.save" not in installed
		and "gf.standard.storage" not in installed
		and "gf.standard.base" not in installed
		and "gf.kernel" in installed
		and not (project_root / "addons/gf/extensions/save/gf_extension.json").exists()
		and not (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").exists()
		and (project_root / "addons/gf/plugin.gd").is_file(),
		issues,
		scenario,
		"preset_smoke_physical_uninstall_prune_failed",
		"Uninstalling a preset should remove the no-file preset and prune unneeded concrete packages while keeping kernel.",
		actual_value=",".join(sorted(installed.keys())),
	)
	verify_uninstall_smoke_physical_lock(project_root, registry_path, scenario, issues)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"removed": uninstall_data.get("removed_packages", [])},
	)


def run_preset_smoke_manual_pin_survives_uninstall(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "manual_pin_survives_preset_uninstall"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.standard.storage",
			"--reason",
			"manual",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.preset.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	uninstall_data = run_package_installer_smoke(
		scenario,
		[
			"uninstall",
			"gf.preset.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	installed = uninstall_smoke_installed(uninstall_data)
	assert_preset_smoke_condition(
		bool(uninstall_data.get("ok"))
		and "gf.preset.save" not in installed
		and "gf.extension.save" not in installed
		and "gf.standard.storage" in installed
		and "manual" in package_lock_reasons(installed, "gf.standard.storage")
		and (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").is_file()
		and not (project_root / "addons/gf/extensions/save/gf_extension.json").exists(),
		issues,
		scenario,
		"preset_smoke_manual_pin_removed",
		"Preset uninstall should not remove packages that were explicitly installed manually.",
		actual_value=",".join(sorted(installed.keys())),
	)
	verify_uninstall_smoke_physical_lock(project_root, registry_path, scenario, issues)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"removed": uninstall_data.get("removed_packages", [])},
	)


def assert_preset_smoke_condition(
	condition: bool,
	issues: list[dict[str, Any]],
	scenario: str,
	kind: str,
	message: str,
	**extra: Any,
) -> None:
	if condition:
		return
	issues.append(make_package_issue(kind, "tools/gf_maintenance.py", message, row_key=scenario, **extra))


def make_preset_smoke_payload(
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
	registry_path: Path,
) -> dict[str, Any]:
	return {
		"ok": len(issues) == 0 and all(bool(scenario.get("ok")) for scenario in scenarios),
		"root": str(ROOT),
		"registry": registry_path.as_posix(),
		"scenario_count": len(scenarios),
		"issue_count": len(issues),
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"scenarios": scenarios,
		"issues": issues,
	}


def package_manager_status_smoke() -> dict[str, Any]:
	with tempfile.TemporaryDirectory(prefix="gf-package-manager-status-smoke-") as temp_dir:
		temp_root = Path(temp_dir)
		output_dir = temp_root / "packages"
		registry_path = temp_root / "registry/index.json"
		issues: list[dict[str, Any]] = []
		scenarios: list[dict[str, Any]] = []

		build_data = run_package_smoke_json_command(
			"build_registry",
			[
				sys.executable,
				"tools/build_gf_package.py",
				"--all",
				"--output-dir",
				str(output_dir),
				"--registry",
				str(registry_path),
				"--json",
			],
			issues,
		)
		record_package_manager_status_smoke_scenario(
			scenarios,
			"build_registry",
			len(issues) == 0 and bool(build_data.get("ok")),
			{"package_count": build_data.get("package_count", 0)},
		)
		if issues or not build_data.get("ok"):
			if not build_data.get("ok") and not issues:
				issues.append(make_package_issue(
					"package_manager_status_smoke_builder_failed",
					"tools/build_gf_package.py",
					"Package builder did not report ok=true.",
					row_key="build_registry",
				))
			return make_package_manager_status_smoke_payload(scenarios, issues, registry_path)

		run_package_manager_status_smoke_empty_project(temp_root, registry_path, scenarios, issues)
		run_package_manager_status_smoke_installed_dependency_risk(temp_root, registry_path, scenarios, issues)
		run_package_manager_status_smoke_project_reference_risk(temp_root, registry_path, scenarios, issues)
		run_package_manager_status_smoke_http_registry(temp_root, registry_path, scenarios, issues)
		run_package_manager_status_smoke_registry_source_signature(temp_root, registry_path, scenarios, issues)
		run_package_manager_status_smoke_registry_package_signature(temp_root, registry_path, scenarios, issues)
		return make_package_manager_status_smoke_payload(scenarios, issues, registry_path)


def run_package_manager_status_smoke_empty_project(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "empty_project_status"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	status_data = run_package_manager_status_command(scenario, registry_path, project_root, issues)
	packages = package_manager_status_package_index(status_data)
	rpg_preset = packages.get("gf.preset.rpg_save_dialogue", {})
	rpg_install = rpg_preset.get("install_preview", {}) if isinstance(rpg_preset, dict) else {}
	rpg_to_install = uninstall_smoke_string_list(rpg_install.get("to_install", [])) if isinstance(rpg_install, dict) else []
	assert_package_manager_status_smoke_condition(
		bool(status_data.get("ok")),
		issues,
		scenario,
		"package_manager_status_smoke_empty_status_failed",
		"Empty project package manager status should succeed.",
	)
	assert_package_manager_status_smoke_condition(
		int(status_data.get("package_count", 0)) >= 34 and int(status_data.get("installed_count", -1)) == 0,
		issues,
		scenario,
		"package_manager_status_smoke_empty_counts_wrong",
		"Empty project status should list registry packages and report no installed packages.",
		actual_value=f"packages={status_data.get('package_count')} installed={status_data.get('installed_count')}",
	)
	for package_id in ["gf.extension.save", "gf.extension.dialogue", "gf.extension.domain", "gf.kernel"]:
		assert_package_manager_status_smoke_condition(
			package_id in rpg_to_install,
			issues,
			scenario,
			"package_manager_status_smoke_preset_preview_missing_package",
			"Preset install preview should expose concrete dependency closure for the editor wizard.",
			expected_value=package_id,
		)
	record_package_manager_status_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"package_count": status_data.get("package_count", 0), "preset_to_install_count": len(rpg_to_install)},
	)


def run_package_manager_status_smoke_installed_dependency_risk(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "installed_dependency_risk"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	status_data = run_package_manager_status_command(scenario, registry_path, project_root, issues)
	packages = package_manager_status_package_index(status_data)
	save_entry = packages.get("gf.extension.save", {})
	storage_entry = packages.get("gf.standard.storage", {})
	storage_uninstall = storage_entry.get("uninstall_preview", {}) if isinstance(storage_entry, dict) else {}
	storage_blocked = storage_uninstall.get("blocked", []) if isinstance(storage_uninstall, dict) else []
	assert_package_manager_status_smoke_condition(
		bool(save_entry.get("installed")) and "manual" in uninstall_smoke_string_list(save_entry.get("reason", [])),
		issues,
		scenario,
		"package_manager_status_smoke_save_manual_missing",
		"Installed root package should be marked as manual in status output.",
	)
	assert_package_manager_status_smoke_condition(
		bool(storage_entry.get("installed"))
		and "dependency" in uninstall_smoke_string_list(storage_entry.get("reason", []))
		and "gf.extension.save" in uninstall_smoke_string_list(storage_entry.get("required_by", [])),
		issues,
		scenario,
		"package_manager_status_smoke_dependency_edge_missing",
		"Status output should expose dependency reason and required_by edges.",
	)
	assert_package_manager_status_smoke_condition(
		not bool(storage_uninstall.get("ok"))
		and any(isinstance(item, dict) and item.get("reason") == "required_by" for item in storage_blocked),
		issues,
		scenario,
		"package_manager_status_smoke_required_by_risk_missing",
		"Dependency package status should expose required_by uninstall blockers.",
	)
	record_package_manager_status_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"installed_count": status_data.get("installed_count", 0)},
	)


def run_package_manager_status_smoke_project_reference_risk(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "project_reference_risk"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.standard.storage",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	user_script = project_root / "scripts/use_storage.gd"
	user_script.parent.mkdir(parents=True, exist_ok=True)
	user_script.write_text("extends Node\nvar storage: GFStorageUtility\n", encoding="utf-8")
	status_data = run_package_manager_status_command(scenario, registry_path, project_root, issues)
	storage_entry = package_manager_status_package_index(status_data).get("gf.standard.storage", {})
	storage_uninstall = storage_entry.get("uninstall_preview", {}) if isinstance(storage_entry, dict) else {}
	storage_blocked = storage_uninstall.get("blocked", []) if isinstance(storage_uninstall, dict) else []
	assert_package_manager_status_smoke_condition(
		not bool(storage_uninstall.get("ok"))
		and any(isinstance(item, dict) and item.get("reason") == "project_references" for item in storage_blocked),
		issues,
		scenario,
		"package_manager_status_smoke_reference_risk_missing",
		"Status output should expose project reference blockers before uninstall.",
	)
	record_package_manager_status_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"blocked_count": len(storage_blocked)},
	)


def run_package_manager_status_smoke_http_registry(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "http_registry_status"
	start_issue_count = len(issues)
	server_root = temp_root / "status_server"
	served_registry = server_root / "registry/index.json"
	served_registry.parent.mkdir(parents=True, exist_ok=True)
	served_registry.write_bytes(registry_path.read_bytes())
	server, thread, base_url = start_network_install_smoke_server(server_root, issues)
	if thread is None:
		record_package_manager_status_smoke_scenario(scenarios, scenario, False)
		return
	try:
		project_root = temp_root / scenario
		registry_url = network_install_smoke_url(base_url, "registry/index.json")
		status_data = run_package_installer_smoke(
			scenario,
			[
				"status",
				"--registry",
				registry_url,
				"--project-root",
				str(project_root),
				"--json",
			],
			issues,
		)
		assert_package_manager_status_smoke_condition(
			bool(status_data.get("ok")) and bool(status_data.get("registry_remote")),
			issues,
			scenario,
			"package_manager_status_smoke_http_status_failed",
			"Status command should read HTTP registry URLs through the shared cache path.",
		)
		assert_package_manager_status_smoke_condition(
			network_install_cache_has_file(project_root / ".gf/package_cache", "registries", ".json"),
			issues,
			scenario,
			"package_manager_status_smoke_http_registry_not_cached",
			"HTTP registry status should cache the downloaded registry.",
		)
		record_package_manager_status_smoke_scenario(
			scenarios,
			scenario,
			len(issues) == start_issue_count,
			{"package_count": status_data.get("package_count", 0)},
		)
	finally:
		stop_network_install_smoke_server(server, thread)


def run_package_manager_status_smoke_registry_source_signature(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "registry_source_signature_status"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	source_path = temp_root / "status_registry_source_signature/gf-registry-source.json"
	write_json_object(source_path, {
		"schema_version": 1,
		"default_channel": "stable",
		"registry_signature_url": "gf-registry-unreleased.json.sig",
		"channels": {
			"stable": {
				"registry": "../registry/index.json",
				"registry_sha256": sha256_file(registry_path),
				"registry_size_bytes": registry_path.stat().st_size,
			},
		},
	})
	status_data = run_package_installer_smoke(
		scenario,
		[
			"status",
			"--registry",
			str(source_path),
			"--channel",
			"stable",
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	status_issues = uninstall_smoke_string_list(status_data.get("issues", []))
	assert_package_manager_status_smoke_condition(
		not bool(status_data.get("ok"))
		and int(status_data.get("package_count", 0)) == 0
		and any("Registry source manifest signature field is not supported until native verification is implemented" in issue for issue in status_issues),
		issues,
		scenario,
		"package_manager_status_smoke_registry_source_signature_not_rejected",
		"Status command should reject registry source signature fields until native verification exists.",
		actual_value=json.dumps({
			"ok": status_data.get("ok"),
			"package_count": status_data.get("package_count"),
			"issues": status_issues,
		}, ensure_ascii=False, sort_keys=True),
	)
	assert_package_manager_status_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"package_manager_status_smoke_registry_source_signature_mutated_project",
		"Registry source signature status rejection must not write lockfiles or package files.",
	)
	record_package_manager_status_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"package_count": status_data.get("package_count", 0),
			"has_issues": len(status_issues) > 0,
		},
	)


def run_package_manager_status_smoke_registry_package_signature(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "registry_package_signature_status"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	signed_registry_path = temp_root / "status_registry_package_signature/index.json"
	registry_data = read_json_object(registry_path)
	packages = registry_data.get("packages", {})
	if isinstance(packages, dict):
		save_entry = packages.get("gf.extension.save", {})
		if isinstance(save_entry, dict):
			save_entry["signature_url"] = "gf-extension-save-unreleased.zip.sig"
			packages["gf.extension.save"] = save_entry
	write_json_object(signed_registry_path, registry_data)
	status_data = run_package_installer_smoke(
		scenario,
		[
			"status",
			"--registry",
			str(signed_registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	status_issues = uninstall_smoke_string_list(status_data.get("issues", []))
	status_packages = package_manager_status_package_index(status_data)
	assert_package_manager_status_smoke_condition(
		not bool(status_data.get("ok"))
		and "gf.extension.save" not in status_packages
		and any("Registry package signature field is not supported until native verification is implemented" in issue for issue in status_issues),
		issues,
		scenario,
		"package_manager_status_smoke_registry_package_signature_not_rejected",
		"Status command should reject registry package signature fields until native verification exists.",
		actual_value=json.dumps({
			"ok": status_data.get("ok"),
			"package_count": status_data.get("package_count"),
			"packages": sorted(status_packages.keys()),
			"issues": status_issues,
		}, ensure_ascii=False, sort_keys=True),
	)
	assert_package_manager_status_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"package_manager_status_smoke_registry_package_signature_mutated_project",
		"Registry package signature status rejection must not write lockfiles or package files.",
	)
	record_package_manager_status_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"package_count": status_data.get("package_count", 0),
			"has_issues": len(status_issues) > 0,
		},
	)


def run_package_manager_status_command(
	scenario: str,
	registry_path: Path,
	project_root: Path,
	issues: list[dict[str, Any]],
	allow_failure: bool = False,
) -> dict[str, Any]:
	return run_package_installer_smoke(
		scenario,
		[
			"status",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		allow_failure=allow_failure,
	)


def package_manager_status_package_index(status_data: dict[str, Any]) -> dict[str, dict[str, Any]]:
	packages = status_data.get("packages", [])
	if not isinstance(packages, list):
		return {}
	return {
		str(item.get("id", "")): item
		for item in packages
		if isinstance(item, dict) and item.get("id")
	}


def assert_package_manager_status_smoke_condition(
	condition: bool,
	issues: list[dict[str, Any]],
	scenario: str,
	kind: str,
	message: str,
	**extra: Any,
) -> None:
	if condition:
		return
	issues.append(make_package_issue(kind, "tools/gf_package_installer.py", message, row_key=scenario, **extra))


def record_package_manager_status_smoke_scenario(
	scenarios: list[dict[str, Any]],
	name: str,
	ok: bool,
	details: dict[str, Any] | None = None,
) -> None:
	scenario = {"name": name, "ok": ok}
	if details:
		scenario.update(details)
	scenarios.append(scenario)


def make_package_manager_status_smoke_payload(
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
	registry_path: Path,
) -> dict[str, Any]:
	return {
		"ok": len(issues) == 0 and all(bool(scenario.get("ok")) for scenario in scenarios),
		"root": str(ROOT),
		"registry": registry_path.as_posix(),
		"scenario_count": len(scenarios),
		"issue_count": len(issues),
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"scenarios": scenarios,
		"issues": issues,
	}


def package_native_parity_smoke() -> dict[str, Any]:
	with tempfile.TemporaryDirectory(prefix="gf-package-native-parity-smoke-", ignore_cleanup_errors=True) as temp_dir:
		temp_root = Path(temp_dir)
		output_dir = temp_root / "packages"
		registry_path = temp_root / "registry/index.json"
		registry_source_path = temp_root / "registry/gf-registry-source.json"
		offline_bundle_path = temp_root / "offline_bundle/gf-package-offline-bundle.zip"
		issues: list[dict[str, Any]] = []
		scenarios: list[dict[str, Any]] = []

		build_data = run_package_smoke_json_command(
			"build_registry",
			[
				sys.executable,
				"tools/build_gf_package.py",
				"--all",
				"--output-dir",
				str(output_dir),
				"--registry",
				str(registry_path),
				"--registry-source",
				str(registry_source_path),
				"--offline-bundle",
				str(offline_bundle_path),
				"--json",
			],
			issues,
		)
		record_package_native_parity_smoke_scenario(
			scenarios,
			"build_registry",
			len(issues) == 0 and bool(build_data.get("ok")),
			{"package_count": build_data.get("package_count", 0)},
		)
		if issues or not build_data.get("ok"):
			if not build_data.get("ok") and not issues:
				issues.append(make_package_issue(
					"package_native_parity_smoke_builder_failed",
					"tools/build_gf_package.py",
					"Package builder did not report ok=true.",
					row_key="build_registry",
				))
			return make_package_native_parity_smoke_payload(scenarios, issues, registry_path)

		run_package_native_parity_smoke_empty_status(temp_root, registry_path, scenarios, issues)
		run_package_native_parity_smoke_offline_bundle_status(temp_root, offline_bundle_path, scenarios, issues)
		run_package_native_parity_smoke_registry_source_mirror_status(temp_root, registry_path, scenarios, issues)
		run_package_native_parity_smoke_registry_source_signature_status(temp_root, registry_path, scenarios, issues)
		run_package_native_parity_smoke_package_signature_status(temp_root, registry_path, scenarios, issues)
		run_package_native_parity_smoke_dry_run_install(temp_root, registry_path, scenarios, issues)
		run_package_native_parity_smoke_checksum_failure_install(temp_root, registry_path, scenarios, issues)
		run_package_native_parity_smoke_registry_source_integrity_failure_install(temp_root, registry_source_path, scenarios, issues)
		run_package_native_parity_smoke_installed_status(temp_root, registry_path, scenarios, issues)
		run_package_native_parity_smoke_installed_verify(temp_root, registry_path, scenarios, issues)
		run_package_native_parity_smoke_dry_run_uninstall(temp_root, registry_path, scenarios, issues)
		run_package_native_parity_smoke_missing_file_list_uninstall(temp_root, registry_path, scenarios, issues)
		return make_package_native_parity_smoke_payload(scenarios, issues, registry_path)


def run_package_native_parity_smoke_empty_status(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "empty_project_status_parity"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	python_status = run_package_manager_status_command(
		"native_parity_python_empty_status",
		registry_path,
		project_root,
		issues,
	)
	godot_status = run_package_godot_cli_smoke_command(
		"native_parity_godot_empty_status",
		[
			"status",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	compare_package_native_parity_statuses(
		scenario,
		python_status,
		godot_status,
		[
			"gf.kernel",
			"gf.standard.storage",
			"gf.extension.save",
			"gf.preset.rpg_save_dialogue",
		],
		issues,
	)
	record_package_native_parity_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"package_count": python_status.get("package_count", 0),
			"installed_count": python_status.get("installed_count", 0),
		},
	)


def run_package_native_parity_smoke_offline_bundle_status(
	temp_root: Path,
	offline_bundle_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "offline_bundle_zip_status_parity"
	start_issue_count = len(issues)
	extract_root = temp_root / "native_parity_offline_bundle_extracted"
	extract_package_godot_cli_smoke_offline_bundle(offline_bundle_path, extract_root, scenario, issues)
	extracted_registry = extract_root / "registry/index.json"
	assert_package_native_parity_smoke_condition(
		extracted_registry.is_file(),
		issues,
		scenario,
		"package_native_parity_smoke_offline_bundle_registry_missing",
		"Offline bundle parity should find the bundled registry/index.json fixture.",
		actual_value=extracted_registry.as_posix(),
	)
	project_root = temp_root / scenario
	python_status = run_package_manager_status_command(
		"native_parity_python_offline_bundle_status",
		extracted_registry,
		project_root,
		issues,
	)
	godot_status = run_package_godot_cli_smoke_command(
		"native_parity_godot_offline_bundle_status",
		[
			"status",
			"--registry",
			str(offline_bundle_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	compare_package_native_parity_statuses(
		scenario,
		python_status,
		godot_status,
		[
			"gf.kernel",
			"gf.standard.storage",
			"gf.extension.save",
			"gf.preset.rpg_save_dialogue",
		],
		issues,
	)
	assert_package_native_parity_smoke_condition(
		bool(godot_status.get("registry_offline_bundle")),
		issues,
		scenario,
		"package_native_parity_smoke_offline_bundle_diagnostic_missing",
		"Godot native status should expose offline bundle diagnostics for editor and CLI callers.",
	)
	record_package_native_parity_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"package_count": python_status.get("package_count", 0),
			"installed_count": python_status.get("installed_count", 0),
			"offline_bundle_entry_count": package_godot_cli_smoke_zip_file_count(offline_bundle_path),
		},
	)


def run_package_native_parity_smoke_registry_source_mirror_status(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "registry_source_mirror_status_parity"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	source_path = temp_root / "registry_source_mirror/gf-registry-source.json"
	write_json_object(source_path, {
		"schema_version": 1,
		"default_channel": "stable",
		"channels": {
			"stable": {
				"registry": "missing/index.json",
				"mirrors": ["../registry/index.json"],
				"registry_sha256": sha256_file(registry_path),
				"registry_size_bytes": registry_path.stat().st_size,
			},
		},
	})
	python_status = run_package_installer_smoke(
		"native_parity_python_registry_source_mirror_status",
		[
			"status",
			"--registry",
			str(source_path),
			"--channel",
			"stable",
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	godot_status = run_package_godot_cli_smoke_command(
		"native_parity_godot_registry_source_mirror_status",
		[
			"status",
			"--registry",
			str(source_path),
			"--channel",
			"stable",
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	compare_package_native_parity_statuses(
		scenario,
		python_status,
		godot_status,
		[
			"gf.kernel",
			"gf.standard.storage",
			"gf.extension.save",
			"gf.preset.rpg_save_dialogue",
		],
		issues,
	)
	python_mirror_index = package_native_parity_int(python_status.get("registry_mirror_index"))
	godot_mirror_index = package_native_parity_int(godot_status.get("registry_mirror_index"))
	assert_package_native_parity_smoke_condition(
		python_mirror_index == 0
		and godot_mirror_index == 0
		and python_status.get("registry_channel") == "stable"
		and godot_status.get("registry_channel") == "stable"
		and is_sha256_hex(str(python_status.get("registry_source_sha256", "")))
		and is_sha256_hex(str(godot_status.get("registry_source_sha256", "")))
		and package_native_parity_int(python_status.get("registry_source_size_bytes")) > 0
		and package_native_parity_int(godot_status.get("registry_source_size_bytes")) > 0,
		issues,
		scenario,
		"package_native_parity_smoke_registry_source_mirror_diagnostics_missing",
		"Python and Godot source mirror fallback status should report channel, mirror index, and registry integrity diagnostics.",
		actual_value=json.dumps({
			"python": {
				"registry_channel": python_status.get("registry_channel"),
				"registry_mirror_index": python_status.get("registry_mirror_index"),
				"registry_source_sha256": python_status.get("registry_source_sha256"),
				"registry_source_size_bytes": python_status.get("registry_source_size_bytes"),
			},
			"godot": {
				"registry_channel": godot_status.get("registry_channel"),
				"registry_mirror_index": godot_status.get("registry_mirror_index"),
				"registry_source_sha256": godot_status.get("registry_source_sha256"),
				"registry_source_size_bytes": godot_status.get("registry_source_size_bytes"),
			},
		}, ensure_ascii=False, sort_keys=True),
	)
	record_package_native_parity_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"package_count": python_status.get("package_count", 0),
			"registry_mirror_index": python_status.get("registry_mirror_index", None),
		},
	)


def run_package_native_parity_smoke_registry_source_signature_status(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "registry_source_signature_status_parity"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	source_path = temp_root / "registry_source_signature/gf-registry-source.json"
	write_json_object(source_path, {
		"schema_version": 1,
		"default_channel": "stable",
		"registry_signature_url": "gf-registry-unreleased.json.sig",
		"channels": {
			"stable": {
				"registry": "../registry/index.json",
				"registry_sha256": sha256_file(registry_path),
				"registry_size_bytes": registry_path.stat().st_size,
			},
		},
	})
	python_status = run_package_installer_smoke(
		"native_parity_python_registry_source_signature_status",
		[
			"status",
			"--registry",
			str(source_path),
			"--channel",
			"stable",
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	godot_status = run_package_godot_cli_smoke_command(
		"native_parity_godot_registry_source_signature_status",
		[
			"status",
			"--registry",
			str(source_path),
			"--channel",
			"stable",
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	python_snapshot = package_native_parity_status_failure_result_snapshot(python_status)
	godot_snapshot = package_native_parity_status_failure_result_snapshot(godot_status)
	assert_package_native_parity_smoke_condition(
		python_snapshot == godot_snapshot,
		issues,
		scenario,
		"package_native_parity_smoke_registry_source_signature_status_mismatch",
		"Python and Godot registry source signature rejection status outputs should agree.",
		expected_value=json.dumps(python_snapshot, ensure_ascii=False, sort_keys=True),
		actual_value=json.dumps(godot_snapshot, ensure_ascii=False, sort_keys=True),
	)
	assert_package_native_parity_smoke_condition(
		not bool(python_status.get("ok"))
		and not bool(godot_status.get("ok"))
		and bool(python_snapshot.get("has_issues"))
		and bool(godot_snapshot.get("has_issues"))
		and not bool(python_snapshot.get("save_package_listed"))
		and not bool(godot_snapshot.get("save_package_listed")),
		issues,
		scenario,
		"package_native_parity_smoke_registry_source_signature_status_not_rejected",
		"Registry source signature fields should be rejected before package listings are trusted in both implementations until native verification exists.",
		actual_value=json.dumps({"python": python_snapshot, "godot": godot_snapshot}, ensure_ascii=False, sort_keys=True),
	)
	assert_package_native_parity_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"package_native_parity_smoke_registry_source_signature_status_mutated_project",
		"Registry source signature status rejection must not write lockfiles or package files.",
	)
	record_package_native_parity_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"package_count": python_status.get("package_count", 0),
			"has_issues": bool(python_snapshot.get("has_issues")),
		},
	)


def run_package_native_parity_smoke_installed_status(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "installed_save_status_parity"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	install_data = run_package_installer_smoke(
		"native_parity_python_install_save",
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	assert_package_native_parity_smoke_condition(
		bool(install_data.get("ok")),
		issues,
		scenario,
		"package_native_parity_smoke_install_failed",
		"Python maintenance installer should prepare the shared lockfile fixture for native parity checks.",
	)
	python_status = run_package_manager_status_command(
		"native_parity_python_installed_status",
		registry_path,
		project_root,
		issues,
	)
	godot_status = run_package_godot_cli_smoke_command(
		"native_parity_godot_installed_status",
		[
			"status",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	compare_package_native_parity_statuses(
		scenario,
		python_status,
		godot_status,
		[
			"gf.kernel",
			"gf.standard.base",
			"gf.standard.storage",
			"gf.standard.deterministic",
			"gf.extension.save",
			"gf.preset.rpg_save_dialogue",
		],
		issues,
	)
	record_package_native_parity_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"package_count": python_status.get("package_count", 0),
			"installed_count": python_status.get("installed_count", 0),
		},
	)


def run_package_native_parity_smoke_installed_verify(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "installed_save_verify_parity"
	start_issue_count = len(issues)
	python_project_root = temp_root / "verify_python_project"
	godot_project_root = temp_root / "verify_godot_project"
	for index, project_root in enumerate((python_project_root, godot_project_root), start=1):
		install_data = run_package_installer_smoke(
			f"native_parity_verify_fixture_install_save_{index}",
			[
				"install",
				"gf.extension.save",
				"--registry",
				str(registry_path),
				"--project-root",
				str(project_root),
				"--json",
			],
			issues,
		)
		assert_package_native_parity_smoke_condition(
			bool(install_data.get("ok")),
			issues,
			scenario,
			"package_native_parity_smoke_verify_fixture_install_failed",
			"Python maintenance installer should prepare installed projects for verify parity checks.",
			actual_value=str(install_data.get("issues", [])),
		)

	python_verify = run_uninstall_smoke_resolver(
		"native_parity_python_verify_save",
		[
			"verify-lock",
			"--registry",
			str(registry_path),
			"--lockfile",
			str(python_project_root / ".gf/packages.lock.json"),
			"--json",
		],
		issues,
	)
	godot_verify = run_package_godot_cli_smoke_command(
		"native_parity_godot_verify_save",
		[
			"verify",
			"--registry",
			str(registry_path),
			"--project-root",
			str(godot_project_root),
			"--json",
		],
		issues,
	)
	python_snapshot = package_native_parity_verify_result_snapshot(python_verify)
	godot_snapshot = package_native_parity_verify_result_snapshot(godot_verify)
	assert_package_native_parity_smoke_condition(
		python_snapshot == godot_snapshot,
		issues,
		scenario,
		"package_native_parity_smoke_verify_mismatch",
		"Python and Godot verify outputs should agree on the lockfile verification contract.",
		expected_value=json.dumps(python_snapshot, ensure_ascii=False, sort_keys=True),
		actual_value=json.dumps(godot_snapshot, ensure_ascii=False, sort_keys=True),
	)
	record_package_native_parity_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"issue_count": package_native_parity_int(python_snapshot.get("issue_count")),
			"lockfile_ok": bool(python_snapshot.get("lockfile_ok")),
		},
	)


def run_package_native_parity_smoke_package_signature_status(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "package_signature_status_parity"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	signed_registry_path = temp_root / "package_signature_status/index.json"
	registry_data = read_json_object(registry_path)
	packages = registry_data.get("packages", {})
	if isinstance(packages, dict):
		save_entry = packages.get("gf.extension.save", {})
		if isinstance(save_entry, dict):
			save_entry["signature_url"] = "gf-extension-save-unreleased.zip.sig"
			packages["gf.extension.save"] = save_entry
	write_json_object(signed_registry_path, registry_data)
	python_status = run_package_installer_smoke(
		"native_parity_python_package_signature_status",
		[
			"status",
			"--registry",
			str(signed_registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	godot_status = run_package_godot_cli_smoke_command(
		"native_parity_godot_package_signature_status",
		[
			"status",
			"--registry",
			str(signed_registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	python_snapshot = package_native_parity_status_failure_result_snapshot(python_status)
	godot_snapshot = package_native_parity_status_failure_result_snapshot(godot_status)
	assert_package_native_parity_smoke_condition(
		python_snapshot == godot_snapshot,
		issues,
		scenario,
		"package_native_parity_smoke_package_signature_status_mismatch",
		"Python and Godot registry package signature rejection status outputs should agree.",
		expected_value=json.dumps(python_snapshot, ensure_ascii=False, sort_keys=True),
		actual_value=json.dumps(godot_snapshot, ensure_ascii=False, sort_keys=True),
	)
	assert_package_native_parity_smoke_condition(
		not bool(python_status.get("ok"))
		and not bool(godot_status.get("ok"))
		and bool(python_snapshot.get("has_issues"))
		and bool(godot_snapshot.get("has_issues"))
		and not bool(python_snapshot.get("save_package_listed"))
		and not bool(godot_snapshot.get("save_package_listed")),
		issues,
		scenario,
		"package_native_parity_smoke_package_signature_status_not_rejected",
		"Registry package signature fields should be rejected and removed from package listings in both implementations until native verification exists.",
		actual_value=json.dumps({"python": python_snapshot, "godot": godot_snapshot}, ensure_ascii=False, sort_keys=True),
	)
	assert_package_native_parity_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"package_native_parity_smoke_package_signature_status_mutated_project",
		"Registry package signature status rejection must not write lockfiles or package files.",
	)
	record_package_native_parity_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"package_count": python_status.get("package_count", 0),
			"has_issues": bool(python_snapshot.get("has_issues")),
		},
	)


def run_package_native_parity_smoke_dry_run_install(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "dry_run_install_save_result_parity"
	start_issue_count = len(issues)
	python_project_root = temp_root / "dry_run_install_python_project"
	godot_project_root = temp_root / "dry_run_install_godot_project"
	python_install = run_package_installer_smoke(
		"native_parity_python_dry_run_install_save",
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(python_project_root),
			"--dry-run",
			"--json",
		],
		issues,
	)
	godot_install = run_package_godot_cli_smoke_command(
		"native_parity_godot_dry_run_install_save",
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(godot_project_root),
			"--dry-run",
			"--json",
		],
		issues,
	)
	python_snapshot = package_native_parity_install_result_snapshot(python_install)
	godot_snapshot = package_native_parity_install_result_snapshot(godot_install)
	assert_package_native_parity_smoke_condition(
		python_snapshot == godot_snapshot,
		issues,
		scenario,
		"package_native_parity_smoke_dry_run_install_mismatch",
		"Python maintenance install and Godot native CLI dry-run install should expose the same package plan contract.",
		expected_value=json.dumps(python_snapshot, ensure_ascii=False, sort_keys=True),
		actual_value=json.dumps(godot_snapshot, ensure_ascii=False, sort_keys=True),
	)
	python_project_snapshot = package_native_parity_dry_run_project_snapshot(python_project_root)
	godot_project_snapshot = package_native_parity_dry_run_project_snapshot(godot_project_root)
	expected_project_snapshot = {
		"has_files": False,
		"lockfile_exists": False,
		"save_manifest_exists": False,
		"storage_utility_exists": False,
	}
	assert_package_native_parity_smoke_condition(
		python_project_snapshot == expected_project_snapshot
		and godot_project_snapshot == expected_project_snapshot,
		issues,
		scenario,
		"package_native_parity_smoke_dry_run_install_mutated_project",
		"Dry-run install parity must not write lockfiles or package files in either implementation.",
		expected_value=json.dumps(expected_project_snapshot, ensure_ascii=False, sort_keys=True),
		actual_value=json.dumps({"python": python_project_snapshot, "godot": godot_project_snapshot}, ensure_ascii=False, sort_keys=True),
	)
	record_package_native_parity_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"to_install_count": len(uninstall_smoke_string_list(python_install.get("to_install", []))),
			"installed_file_count": package_native_parity_int(python_install.get("installed_file_count")),
			"dry_run": bool(python_install.get("dry_run")),
		},
	)


def run_package_native_parity_smoke_checksum_failure_install(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "checksum_failure_install_parity"
	start_issue_count = len(issues)
	python_project_root = temp_root / "checksum_failure_python_project"
	godot_project_root = temp_root / "checksum_failure_godot_project"
	bad_registry_path = temp_root / "checksum_failure_registry/index.json"
	registry_data = read_json_object(registry_path)
	packages = registry_data.get("packages", {})
	if isinstance(packages, dict) and isinstance(packages.get("gf.extension.save"), dict):
		packages["gf.extension.save"]["sha256"] = "0" * 64
	write_json_object(bad_registry_path, registry_data)
	python_install = run_package_installer_smoke(
		"native_parity_python_checksum_failure_install",
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(bad_registry_path),
			"--project-root",
			str(python_project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	godot_install = run_package_godot_cli_smoke_command(
		"native_parity_godot_checksum_failure_install",
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(bad_registry_path),
			"--project-root",
			str(godot_project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	python_snapshot = package_native_parity_install_failure_result_snapshot(python_install)
	godot_snapshot = package_native_parity_install_failure_result_snapshot(godot_install)
	assert_package_native_parity_smoke_condition(
		python_snapshot == godot_snapshot,
		issues,
		scenario,
		"package_native_parity_smoke_checksum_failure_mismatch",
		"Python and Godot checksum failure install outputs should agree on the no-mutation failure contract.",
		expected_value=json.dumps(python_snapshot, ensure_ascii=False, sort_keys=True),
		actual_value=json.dumps(godot_snapshot, ensure_ascii=False, sort_keys=True),
	)
	assert_package_native_parity_smoke_condition(
		not bool(python_install.get("ok"))
		and not bool(godot_install.get("ok"))
		and bool(python_snapshot.get("has_issues"))
		and bool(godot_snapshot.get("has_issues")),
		issues,
		scenario,
		"package_native_parity_smoke_checksum_failure_not_rejected",
		"Checksum mismatch parity should fail in both Python maintenance and Godot native installers.",
		actual_value=json.dumps({"python": python_snapshot, "godot": godot_snapshot}, ensure_ascii=False, sort_keys=True),
	)
	python_project_snapshot = package_native_parity_dry_run_project_snapshot(python_project_root)
	godot_project_snapshot = package_native_parity_dry_run_project_snapshot(godot_project_root)
	expected_project_snapshot = {
		"has_files": False,
		"lockfile_exists": False,
		"save_manifest_exists": False,
		"storage_utility_exists": False,
	}
	assert_package_native_parity_smoke_condition(
		python_project_snapshot == expected_project_snapshot
		and godot_project_snapshot == expected_project_snapshot,
		issues,
		scenario,
		"package_native_parity_smoke_checksum_failure_mutated_project",
		"Checksum failure parity must not write lockfiles or package files in either implementation.",
		expected_value=json.dumps(expected_project_snapshot, ensure_ascii=False, sort_keys=True),
		actual_value=json.dumps({"python": python_project_snapshot, "godot": godot_project_snapshot}, ensure_ascii=False, sort_keys=True),
	)
	record_package_native_parity_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"has_issues": bool(python_snapshot.get("has_issues")),
			"lockfile_written": bool(python_snapshot.get("lockfile_written")),
		},
	)


def run_package_native_parity_smoke_registry_source_integrity_failure_install(
	temp_root: Path,
	registry_source_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "registry_source_integrity_failure_install_parity"
	start_issue_count = len(issues)
	python_project_root = temp_root / "registry_source_integrity_failure_python_project"
	godot_project_root = temp_root / "registry_source_integrity_failure_godot_project"
	bad_source_path = temp_root / "registry_source_integrity_failure/gf-registry-source.json"
	source_data = read_json_object(registry_source_path)
	channels = source_data.get("channels", {})
	channel_name = str(source_data.get("default_channel", "stable")).strip() or "stable"
	channel_entry = channels.get(channel_name, {}) if isinstance(channels, dict) else {}
	if isinstance(channel_entry, dict):
		channel_entry["registry_sha256"] = "0" * 64
		channel_entry["registry_size_bytes"] = 1
	write_json_object(bad_source_path, source_data)
	python_install = run_package_installer_smoke(
		"native_parity_python_registry_source_integrity_failure_install",
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(bad_source_path),
			"--channel",
			channel_name,
			"--project-root",
			str(python_project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	godot_install = run_package_godot_cli_smoke_command(
		"native_parity_godot_registry_source_integrity_failure_install",
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(bad_source_path),
			"--channel",
			channel_name,
			"--project-root",
			str(godot_project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	python_snapshot = package_native_parity_install_failure_result_snapshot(python_install)
	godot_snapshot = package_native_parity_install_failure_result_snapshot(godot_install)
	assert_package_native_parity_smoke_condition(
		python_snapshot == godot_snapshot,
		issues,
		scenario,
		"package_native_parity_smoke_registry_source_integrity_failure_mismatch",
		"Python and Godot registry source integrity failure outputs should agree on the no-mutation failure contract.",
		expected_value=json.dumps(python_snapshot, ensure_ascii=False, sort_keys=True),
		actual_value=json.dumps(godot_snapshot, ensure_ascii=False, sort_keys=True),
	)
	assert_package_native_parity_smoke_condition(
		not bool(python_install.get("ok"))
		and not bool(godot_install.get("ok"))
		and bool(python_snapshot.get("has_issues"))
		and bool(godot_snapshot.get("has_issues")),
		issues,
		scenario,
		"package_native_parity_smoke_registry_source_integrity_failure_not_rejected",
		"Registry source integrity mismatch parity should fail in both Python maintenance and Godot native installers.",
		actual_value=json.dumps({"python": python_snapshot, "godot": godot_snapshot}, ensure_ascii=False, sort_keys=True),
	)
	python_project_snapshot = package_native_parity_dry_run_project_snapshot(python_project_root)
	godot_project_snapshot = package_native_parity_dry_run_project_snapshot(godot_project_root)
	expected_project_snapshot = {
		"has_files": False,
		"lockfile_exists": False,
		"save_manifest_exists": False,
		"storage_utility_exists": False,
	}
	assert_package_native_parity_smoke_condition(
		python_project_snapshot == expected_project_snapshot
		and godot_project_snapshot == expected_project_snapshot,
		issues,
		scenario,
		"package_native_parity_smoke_registry_source_integrity_failure_mutated_project",
		"Registry source integrity failure parity must not write lockfiles or package files in either implementation.",
		expected_value=json.dumps(expected_project_snapshot, ensure_ascii=False, sort_keys=True),
		actual_value=json.dumps({"python": python_project_snapshot, "godot": godot_project_snapshot}, ensure_ascii=False, sort_keys=True),
	)
	record_package_native_parity_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"has_issues": bool(python_snapshot.get("has_issues")),
			"lockfile_written": bool(python_snapshot.get("lockfile_written")),
			"registry_channel": channel_name,
		},
	)


def run_package_native_parity_smoke_dry_run_uninstall(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "dry_run_uninstall_save_result_parity"
	start_issue_count = len(issues)
	python_project_root = temp_root / "dry_run_uninstall_python_project"
	godot_project_root = temp_root / "dry_run_uninstall_godot_project"
	for label, project_root in {
		"python": python_project_root,
		"godot": godot_project_root,
	}.items():
		install_data = run_package_installer_smoke(
			f"native_parity_{label}_dry_run_uninstall_install_save",
			[
				"install",
				"gf.extension.save",
				"--registry",
				str(registry_path),
				"--project-root",
				str(project_root),
				"--json",
			],
			issues,
		)
		assert_package_native_parity_smoke_condition(
			bool(install_data.get("ok")),
			issues,
			scenario,
			"package_native_parity_smoke_uninstall_dry_run_fixture_install_failed",
			"Python maintenance installer should prepare uninstall dry-run parity fixtures.",
			field=label,
			actual_value=str(install_data.get("issues", [])),
		)

	python_uninstall = run_package_installer_smoke(
		"native_parity_python_dry_run_uninstall_save",
		[
			"uninstall",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(python_project_root),
			"--dry-run",
			"--json",
		],
		issues,
	)
	godot_uninstall = run_package_godot_cli_smoke_command(
		"native_parity_godot_dry_run_uninstall_save",
		[
			"uninstall",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(godot_project_root),
			"--dry-run",
			"--json",
		],
		issues,
	)
	python_snapshot = package_native_parity_uninstall_result_snapshot(python_uninstall)
	godot_snapshot = package_native_parity_uninstall_result_snapshot(godot_uninstall)
	assert_package_native_parity_smoke_condition(
		python_snapshot == godot_snapshot,
		issues,
		scenario,
		"package_native_parity_smoke_dry_run_uninstall_mismatch",
		"Python maintenance uninstall and Godot native CLI dry-run uninstall should expose the same package plan contract.",
		expected_value=json.dumps(python_snapshot, ensure_ascii=False, sort_keys=True),
		actual_value=json.dumps(godot_snapshot, ensure_ascii=False, sort_keys=True),
	)
	python_project_snapshot = package_native_parity_installed_project_snapshot(python_project_root)
	godot_project_snapshot = package_native_parity_installed_project_snapshot(godot_project_root)
	expected_project_snapshot = {
		"has_files": True,
		"installed_ids": [
			"gf.extension.save",
			"gf.kernel",
			"gf.standard.base",
			"gf.standard.deterministic",
			"gf.standard.storage",
		],
		"lockfile_exists": True,
		"save_manifest_exists": True,
		"storage_utility_exists": True,
		"deterministic_random_exists": True,
	}
	assert_package_native_parity_smoke_condition(
		python_project_snapshot == expected_project_snapshot
		and godot_project_snapshot == expected_project_snapshot,
		issues,
		scenario,
		"package_native_parity_smoke_dry_run_uninstall_mutated_project",
		"Dry-run uninstall parity must keep lockfiles and package files unchanged in both implementations.",
		expected_value=json.dumps(expected_project_snapshot, ensure_ascii=False, sort_keys=True),
		actual_value=json.dumps({"python": python_project_snapshot, "godot": godot_project_snapshot}, ensure_ascii=False, sort_keys=True),
	)
	record_package_native_parity_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"to_remove_count": len(uninstall_smoke_string_list(python_uninstall.get("to_remove", []))),
			"planned_file_count": package_native_parity_int(python_uninstall.get("planned_file_count")),
			"removed_file_count": package_native_parity_int(python_uninstall.get("removed_file_count")),
			"dry_run": bool(python_uninstall.get("dry_run")),
		},
	)


def run_package_native_parity_smoke_missing_file_list_uninstall(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "missing_file_list_uninstall_parity"
	start_issue_count = len(issues)
	strict_package_ids = [
		"gf.extension.save",
		"gf.standard.base",
		"gf.standard.deterministic",
		"gf.standard.storage",
	]
	python_project_root = temp_root / "missing_file_list_python_project"
	godot_project_root = temp_root / "missing_file_list_godot_project"
	for label, project_root in {
		"python": python_project_root,
		"godot": godot_project_root,
	}.items():
		install_data = run_package_installer_smoke(
			f"native_parity_{label}_missing_files_install_save",
			[
				"install",
				"gf.extension.save",
				"--registry",
				str(registry_path),
				"--project-root",
				str(project_root),
				"--json",
			],
			issues,
		)
		assert_package_native_parity_smoke_condition(
			bool(install_data.get("ok")),
			issues,
			scenario,
			"package_native_parity_smoke_fixture_install_failed",
			"Python maintenance installer should prepare corrupted-lockfile uninstall parity fixtures.",
			field=label,
			actual_value=str(install_data.get("issues", [])),
		)
		(package_native_parity_save_extra_file(project_root)).write_text("extends Node\n", encoding="utf-8")
		(package_native_parity_storage_extra_file(project_root)).write_text("extends Node\n", encoding="utf-8")
		remove_uninstall_smoke_lockfile_files(project_root, strict_package_ids)

	python_uninstall = run_package_installer_smoke(
		"native_parity_python_missing_files_uninstall",
		[
			"uninstall",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(python_project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	godot_uninstall = run_package_godot_cli_smoke_command(
		"native_parity_godot_missing_files_uninstall",
		[
			"uninstall",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(godot_project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	python_counts = package_native_parity_uninstall_counts(python_uninstall)
	godot_counts = package_native_parity_uninstall_counts(godot_uninstall)
	python_issues = uninstall_smoke_string_list(python_uninstall.get("issues", []))
	godot_issues = uninstall_smoke_string_list(godot_uninstall.get("issues", []))
	assert_package_native_parity_smoke_condition(
		not bool(python_uninstall.get("ok"))
		and not bool(godot_uninstall.get("ok"))
		and python_counts["planned_file_count"] == 0
		and python_counts["removed_file_count"] == 0
		and godot_counts["planned_file_count"] == 0
		and godot_counts["removed_file_count"] == 0
		and any("missing the installed files list" in issue for issue in python_issues)
		and any("missing the installed files list" in issue for issue in godot_issues),
		issues,
		scenario,
		"package_native_parity_smoke_missing_files_uninstall_not_rejected",
		"Python maintenance uninstall and Godot native CLI uninstall should both reject lockfile entries without exact files lists.",
		expected_value="ok=false, zero file counts, and missing files-list issue",
		actual_value=f"python={python_uninstall.get('ok')} {python_counts} {python_issues} godot={godot_uninstall.get('ok')} {godot_counts} {godot_issues}",
	)
	assert_package_native_parity_smoke_condition(
		python_counts == godot_counts,
		issues,
		scenario,
		"package_native_parity_smoke_missing_files_count_mismatch",
		"Python maintenance uninstall and Godot native CLI uninstall should report the same strict rejection file counts.",
		expected_value=json.dumps(python_counts, sort_keys=True),
		actual_value=json.dumps(godot_counts, sort_keys=True),
	)
	python_snapshot = package_native_parity_uninstall_project_snapshot(python_project_root)
	godot_snapshot = package_native_parity_uninstall_project_snapshot(godot_project_root)
	expected_snapshot = {
		"installed_ids": [
			"gf.extension.save",
			"gf.kernel",
			"gf.standard.base",
			"gf.standard.deterministic",
			"gf.standard.storage",
		],
		"save_manifest_exists": True,
		"storage_utility_exists": True,
		"deterministic_random_exists": True,
		"save_extra_exists": True,
		"storage_extra_exists": True,
	}
	assert_package_native_parity_smoke_condition(
		python_snapshot == expected_snapshot and godot_snapshot == expected_snapshot,
		issues,
		scenario,
		"package_native_parity_smoke_missing_files_snapshot_mismatch",
		"Strict missing-files-list rejection should leave packages and user-added files unchanged in both implementations.",
		expected_value=json.dumps(expected_snapshot, ensure_ascii=False, sort_keys=True),
		actual_value=json.dumps({"python": python_snapshot, "godot": godot_snapshot}, ensure_ascii=False, sort_keys=True),
	)

	python_status = run_package_manager_status_command(
		"native_parity_python_missing_files_status",
		registry_path,
		python_project_root,
		issues,
		allow_failure=True,
	)
	godot_status = run_package_godot_cli_smoke_command(
		"native_parity_godot_missing_files_status",
		[
			"status",
			"--registry",
			str(registry_path),
			"--project-root",
			str(godot_project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	python_status_issues = uninstall_smoke_string_list(python_status.get("issues", []))
	godot_status_issues = uninstall_smoke_string_list(godot_status.get("issues", []))
	watched_missing_files_packages = [
		"gf.kernel",
		"gf.standard.base",
		"gf.standard.storage",
		"gf.standard.deterministic",
		"gf.extension.save",
	]
	assert_package_native_parity_smoke_condition(
		not bool(python_status.get("ok"))
		and not bool(godot_status.get("ok"))
		and any("missing files list" in issue for issue in python_status_issues)
		and any("missing files list" in issue for issue in godot_status_issues),
		issues,
		scenario,
		"package_native_parity_smoke_missing_files_status_not_rejected",
		"Python maintenance status and Godot native status should both reject corrupted lockfile entries without files lists.",
		actual_value=json.dumps({
			"python_ok": python_status.get("ok"),
			"godot_ok": godot_status.get("ok"),
			"python_issues": python_status_issues,
			"godot_issues": godot_status_issues,
		}, ensure_ascii=False, sort_keys=True),
	)
	for key in ("package_count", "installed_count"):
		assert_package_native_parity_smoke_condition(
			python_status.get(key) == godot_status.get(key),
			issues,
			scenario,
			"package_native_parity_smoke_missing_files_status_count_mismatch",
			"Python and Godot corrupted-lockfile status outputs should report the same package counters.",
			field=key,
			expected_value=str(python_status.get(key)),
			actual_value=str(godot_status.get(key)),
		)
	assert_package_native_parity_smoke_condition(
		package_native_parity_installed_ids(python_status) == package_native_parity_installed_ids(godot_status),
		issues,
		scenario,
		"package_native_parity_smoke_missing_files_status_installed_mismatch",
		"Python and Godot corrupted-lockfile status outputs should agree on installed package IDs.",
		expected_value=json.dumps(package_native_parity_installed_ids(python_status), ensure_ascii=False),
		actual_value=json.dumps(package_native_parity_installed_ids(godot_status), ensure_ascii=False),
	)
	python_packages = package_manager_status_package_index(python_status)
	godot_packages = package_manager_status_package_index(godot_status)
	for package_id in watched_missing_files_packages:
		python_package_snapshot = package_native_parity_package_snapshot(python_packages.get(package_id, {}))
		godot_package_snapshot = package_native_parity_package_snapshot(godot_packages.get(package_id, {}))
		assert_package_native_parity_smoke_condition(
			python_package_snapshot == godot_package_snapshot,
			issues,
			scenario,
			"package_native_parity_smoke_missing_files_status_package_mismatch",
			"Python and Godot corrupted-lockfile status outputs should keep package rows in parity.",
			field=package_id,
			expected_value=json.dumps(python_package_snapshot, ensure_ascii=False, sort_keys=True),
			actual_value=json.dumps(godot_package_snapshot, ensure_ascii=False, sort_keys=True),
		)
	record_package_native_parity_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"planned_file_count": python_counts["planned_file_count"],
			"removed_file_count": python_counts["removed_file_count"],
		},
	)


def compare_package_native_parity_statuses(
	scenario: str,
	python_status: dict[str, Any],
	godot_status: dict[str, Any],
	watched_package_ids: list[str],
	issues: list[dict[str, Any]],
) -> None:
	assert_package_native_parity_smoke_condition(
		bool(python_status.get("ok")) and bool(godot_status.get("ok")),
		issues,
		scenario,
		"package_native_parity_smoke_status_failed",
		"Both Python maintenance status and Godot native CLI status should succeed.",
		actual_value=f"python={python_status.get('ok')} godot={godot_status.get('ok')}",
	)
	for key in ("package_count", "installed_count"):
		assert_package_native_parity_smoke_condition(
			python_status.get(key) == godot_status.get(key),
			issues,
			scenario,
			"package_native_parity_smoke_count_mismatch",
			"Python and Godot status outputs should report the same package counters.",
			field=key,
			expected_value=str(python_status.get(key)),
			actual_value=str(godot_status.get(key)),
		)
	python_installed = package_native_parity_installed_ids(python_status)
	godot_installed = package_native_parity_installed_ids(godot_status)
	assert_package_native_parity_smoke_condition(
		python_installed == godot_installed,
		issues,
		scenario,
		"package_native_parity_smoke_installed_ids_mismatch",
		"Python and Godot status outputs should agree on installed package IDs.",
		expected_value=json.dumps(python_installed, ensure_ascii=False),
		actual_value=json.dumps(godot_installed, ensure_ascii=False),
	)

	python_packages = package_manager_status_package_index(python_status)
	godot_packages = package_manager_status_package_index(godot_status)
	for package_id in watched_package_ids:
		assert_package_native_parity_smoke_condition(
			package_id in python_packages and package_id in godot_packages,
			issues,
			scenario,
			"package_native_parity_smoke_package_missing",
			"Watched package should exist in both status outputs.",
			field=package_id,
			expected_value=str(package_id in python_packages),
			actual_value=str(package_id in godot_packages),
		)
		python_snapshot = package_native_parity_package_snapshot(python_packages.get(package_id, {}))
		godot_snapshot = package_native_parity_package_snapshot(godot_packages.get(package_id, {}))
		assert_package_native_parity_smoke_condition(
			python_snapshot == godot_snapshot,
			issues,
			scenario,
			"package_native_parity_smoke_package_mismatch",
			"Python and Godot status outputs should agree on package contract fields.",
			field=package_id,
			expected_value=json.dumps(python_snapshot, ensure_ascii=False, sort_keys=True),
			actual_value=json.dumps(godot_snapshot, ensure_ascii=False, sort_keys=True),
		)


def package_native_parity_installed_ids(status_data: dict[str, Any]) -> list[str]:
	packages = package_manager_status_package_index(status_data)
	return sorted(
		package_id
		for package_id, entry in packages.items()
		if bool(entry.get("installed"))
	)


def package_native_parity_package_snapshot(entry: dict[str, Any]) -> dict[str, Any]:
	install_preview = entry.get("install_preview", {})
	uninstall_preview = entry.get("uninstall_preview", {})
	snapshot: dict[str, Any] = {
		"kind": str(entry.get("kind", "")),
		"version": str(entry.get("version", "")),
		"dependencies": uninstall_smoke_string_list(entry.get("dependencies", [])),
		"packages": uninstall_smoke_string_list(entry.get("packages", [])),
		"installed": bool(entry.get("installed")),
		"reason": sorted(uninstall_smoke_string_list(entry.get("reason", []))),
		"required_by": sorted(uninstall_smoke_string_list(entry.get("required_by", []))),
	}
	if isinstance(install_preview, dict):
		snapshot["install_preview"] = {
			"install_order": uninstall_smoke_string_list(install_preview.get("install_order", [])),
			"to_install": uninstall_smoke_string_list(install_preview.get("to_install", [])),
			"to_update": uninstall_smoke_string_list(install_preview.get("to_update", [])),
		}
	if isinstance(uninstall_preview, dict) and uninstall_preview:
		snapshot["uninstall_preview"] = {
			"ok": bool(uninstall_preview.get("ok")),
			"to_remove": uninstall_smoke_string_list(uninstall_preview.get("to_remove", [])),
			"blocked": package_native_parity_blockers(uninstall_preview.get("blocked", [])),
		}
	return snapshot


def package_native_parity_install_result_snapshot(data: dict[str, Any]) -> dict[str, Any]:
	return {
		"ok": bool(data.get("ok")),
		"operation": str(data.get("operation", "")),
		"requested_packages": uninstall_smoke_string_list(data.get("requested_packages", [])),
		"install_order": uninstall_smoke_string_list(data.get("install_order", [])),
		"to_install": uninstall_smoke_string_list(data.get("to_install", [])),
		"to_update": uninstall_smoke_string_list(data.get("to_update", [])),
		"installed_packages": uninstall_smoke_string_list(data.get("installed_packages", [])),
		"installed_file_count": package_native_parity_int(data.get("installed_file_count")),
		"lockfile_written": bool(data.get("lockfile_written")),
		"dry_run": bool(data.get("dry_run")),
		"rolled_back": bool(data.get("rolled_back")),
		"issue_count": package_native_parity_int(data.get("issue_count")),
	}


def package_native_parity_status_failure_result_snapshot(data: dict[str, Any]) -> dict[str, Any]:
	issues = uninstall_smoke_string_list(data.get("issues", []))
	packages = package_manager_status_package_index(data)
	return {
		"ok": bool(data.get("ok")),
		"operation": str(data.get("operation", "")),
		"package_count": package_native_parity_int(data.get("package_count")),
		"installed_count": package_native_parity_int(data.get("installed_count")),
		"has_issues": package_native_parity_issue_count(data, issues) > 0,
		"save_package_listed": "gf.extension.save" in packages,
	}


def package_native_parity_install_failure_result_snapshot(data: dict[str, Any]) -> dict[str, Any]:
	issues = uninstall_smoke_string_list(data.get("issues", []))
	return {
		"ok": bool(data.get("ok")),
		"operation": str(data.get("operation", "")),
		"requested_packages": uninstall_smoke_string_list(data.get("requested_packages", [])),
		"install_order": uninstall_smoke_string_list(data.get("install_order", [])),
		"to_install": uninstall_smoke_string_list(data.get("to_install", [])),
		"to_update": uninstall_smoke_string_list(data.get("to_update", [])),
		"installed_packages": uninstall_smoke_string_list(data.get("installed_packages", [])),
		"installed_file_count": package_native_parity_int(data.get("installed_file_count")),
		"lockfile_written": bool(data.get("lockfile_written")),
		"dry_run": bool(data.get("dry_run")),
		"rolled_back": bool(data.get("rolled_back")),
		"has_issues": package_native_parity_issue_count(data, issues) > 0,
	}


def package_native_parity_uninstall_result_snapshot(data: dict[str, Any]) -> dict[str, Any]:
	return {
		"ok": bool(data.get("ok")),
		"operation": str(data.get("operation", "")),
		"requested_packages": uninstall_smoke_string_list(data.get("requested_packages", [])),
		"to_remove": uninstall_smoke_string_list(data.get("to_remove", [])),
		"blocked": package_native_parity_blockers(data.get("blocked", [])),
		"removed_packages": uninstall_smoke_string_list(data.get("removed_packages", [])),
		"planned_file_count": package_native_parity_int(data.get("planned_file_count")),
		"removed_file_count": package_native_parity_int(data.get("removed_file_count")),
		"lockfile_written": bool(data.get("lockfile_written")),
		"dry_run": bool(data.get("dry_run")),
		"force": bool(data.get("force")),
		"rolled_back": bool(data.get("rolled_back")),
		"issue_count": package_native_parity_int(data.get("issue_count")),
	}


def package_native_parity_verify_result_snapshot(data: dict[str, Any]) -> dict[str, Any]:
	lockfile_verify = data.get("lockfile_verify", {})
	if not isinstance(lockfile_verify, dict):
		lockfile_verify = {}
	issues = uninstall_smoke_string_list(data.get("issues", []))
	lockfile_issues = uninstall_smoke_string_list(lockfile_verify.get("issues", issues))
	return {
		"ok": bool(data.get("ok")),
		"operation": str(data.get("operation", "")),
		"lockfile_ok": bool(lockfile_verify.get("ok", data.get("ok", False))),
		"lockfile_issues": lockfile_issues,
		"issue_count": package_native_parity_issue_count(data, issues),
		"issues": issues,
	}


def package_native_parity_issue_count(data: dict[str, Any], issues: list[str]) -> int:
	value = data.get("issue_count")
	if isinstance(value, int):
		return value
	return len(issues)


def package_native_parity_dry_run_project_snapshot(project_root: Path) -> dict[str, Any]:
	return {
		"has_files": project_has_files(project_root),
		"lockfile_exists": (project_root / ".gf/packages.lock.json").is_file(),
		"save_manifest_exists": (project_root / "addons/gf/extensions/save/gf_extension.json").is_file(),
		"storage_utility_exists": (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").is_file(),
	}


def package_native_parity_installed_project_snapshot(project_root: Path) -> dict[str, Any]:
	return {
		"has_files": project_has_files(project_root),
		"installed_ids": sorted(str(package_id) for package_id in read_uninstall_smoke_lock_installed(project_root).keys()),
		"lockfile_exists": (project_root / ".gf/packages.lock.json").is_file(),
		"save_manifest_exists": (project_root / "addons/gf/extensions/save/gf_extension.json").is_file(),
		"storage_utility_exists": (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").is_file(),
		"deterministic_random_exists": (project_root / "addons/gf/standard/foundation/deterministic/gf_deterministic_random.gd").is_file(),
	}


def package_native_parity_blockers(raw_blockers: Any) -> list[dict[str, Any]]:
	if not isinstance(raw_blockers, list):
		return []
	blockers: list[dict[str, Any]] = []
	for raw_blocker in raw_blockers:
		if not isinstance(raw_blocker, dict):
			continue
		blockers.append({
			"id": str(raw_blocker.get("id", "")),
			"reason": str(raw_blocker.get("reason", "")),
			"required_by": sorted(uninstall_smoke_string_list(raw_blocker.get("required_by", []))),
		})
	return sorted(blockers, key=lambda item: json.dumps(item, sort_keys=True))


def package_native_parity_uninstall_counts(data: dict[str, Any]) -> dict[str, int]:
	return {
		"planned_file_count": package_native_parity_int(data.get("planned_file_count")),
		"removed_file_count": package_native_parity_int(data.get("removed_file_count")),
	}


def package_native_parity_int(value: Any) -> int:
	return value if isinstance(value, int) else -1


def package_native_parity_uninstall_project_snapshot(project_root: Path) -> dict[str, Any]:
	installed = read_uninstall_smoke_lock_installed(project_root)
	return {
		"installed_ids": sorted(str(package_id) for package_id in installed.keys()),
		"save_manifest_exists": (project_root / "addons/gf/extensions/save/gf_extension.json").is_file(),
		"storage_utility_exists": (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").is_file(),
		"deterministic_random_exists": (project_root / "addons/gf/standard/foundation/deterministic/gf_deterministic_random.gd").is_file(),
		"save_extra_exists": package_native_parity_save_extra_file(project_root).is_file(),
		"storage_extra_exists": package_native_parity_storage_extra_file(project_root).is_file(),
	}


def package_native_parity_save_extra_file(project_root: Path) -> Path:
	path = project_root / "addons/gf/extensions/save/project_extra_file.gd"
	path.parent.mkdir(parents=True, exist_ok=True)
	return path


def package_native_parity_storage_extra_file(project_root: Path) -> Path:
	path = project_root / "addons/gf/standard/utilities/storage/project_extra_file.gd"
	path.parent.mkdir(parents=True, exist_ok=True)
	return path


def assert_package_native_parity_smoke_condition(
	condition: bool,
	issues: list[dict[str, Any]],
	scenario: str,
	kind: str,
	message: str,
	**extra: Any,
) -> None:
	if condition:
		return
	issues.append(make_package_issue(kind, "tools/gf_maintenance.py", message, row_key=scenario, **extra))


def record_package_native_parity_smoke_scenario(
	scenarios: list[dict[str, Any]],
	name: str,
	ok: bool,
	details: dict[str, Any] | None = None,
) -> None:
	scenario = {"name": name, "ok": ok}
	if details:
		scenario.update(details)
	scenarios.append(scenario)


def make_package_native_parity_smoke_payload(
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
	registry_path: Path,
) -> dict[str, Any]:
	return {
		"ok": len(issues) == 0 and all(bool(scenario.get("ok")) for scenario in scenarios),
		"root": str(ROOT),
		"registry": registry_path.as_posix(),
		"scenario_count": len(scenarios),
		"issue_count": len(issues),
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"scenarios": scenarios,
		"issues": issues,
	}


def package_editor_wizard_smoke() -> dict[str, Any]:
	test_path = "res://tests/gf_core/kernel/editor/test_gf_package_manager_dock.gd"
	log_path = GODOT_LOG_DIR / "package_editor_wizard_smoke.log"
	import_log_path = GODOT_LOG_DIR / "package_editor_wizard_smoke_import.log"
	command = [
		"godot",
		"--headless",
		"--log-file",
		log_path.as_posix(),
		"--path",
		".",
		"-s",
		"res://addons/gut/gut_cmdln.gd",
		f"-gtest={test_path}",
		"-gexit",
		"-gdisable_colors",
	]
	GODOT_LOG_DIR.mkdir(parents=True, exist_ok=True)
	issues: list[dict[str, Any]] = []
	scenarios: list[dict[str, Any]] = []
	scenario = "package_manager_dock_gut"
	import_command = [
		"godot",
		"--headless",
		"--log-file",
		import_log_path.as_posix(),
		"--path",
		".",
		"--import",
	]
	try:
		import_completed = subprocess.run(
			import_command,
			cwd=ROOT,
			capture_output=True,
			text=True,
			encoding="utf-8",
			errors="replace",
			timeout=180,
		)
	except subprocess.TimeoutExpired as error:
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_import_timeout",
			test_path,
			"Editor package wizard focused GUT import preflight timed out.",
			row_key=scenario,
			error=trim_text(str(error), 300),
		))
		record_package_editor_wizard_smoke_scenario(
			scenarios,
			scenario,
			False,
			{"test_path": test_path, "log_path": log_path.as_posix()},
		)
		return make_package_editor_wizard_smoke_payload(command, scenarios, issues, test_path, log_path)
	import_log_text = read_text_file_if_exists(import_log_path)
	import_output = f"{import_completed.stdout}\n{import_completed.stderr}\n{import_log_text}"
	if import_completed.returncode != 0 or has_godot_script_error(import_output, "") or has_gdscript_reload_warning(import_output, ""):
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_import_failed",
			test_path,
			"Editor package wizard focused GUT import preflight failed.",
			row_key=scenario,
			actual_value=str(import_completed.returncode),
			error=trim_text(import_output.strip(), 1200),
		))
		record_package_editor_wizard_smoke_scenario(
			scenarios,
			scenario,
			False,
			{"test_path": test_path, "log_path": log_path.as_posix()},
		)
		return make_package_editor_wizard_smoke_payload(command, scenarios, issues, test_path, log_path)
	try:
		completed = subprocess.run(
			command,
			cwd=ROOT,
			capture_output=True,
			text=True,
			encoding="utf-8",
			errors="replace",
			timeout=180,
		)
	except subprocess.TimeoutExpired as error:
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_timeout",
			test_path,
			"Editor package wizard focused GUT timed out.",
			row_key=scenario,
			error=trim_text(str(error), 300),
		))
		record_package_editor_wizard_smoke_scenario(
			scenarios,
			scenario,
			False,
			{"test_path": test_path, "log_path": log_path.as_posix()},
		)
		return make_package_editor_wizard_smoke_payload(command, scenarios, issues, test_path, log_path)

	log_text = read_text_file_if_exists(log_path)
	combined_output = f"{completed.stdout}\n{completed.stderr}\n{log_text}"
	if completed.returncode != 0:
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_command_failed",
			test_path,
			"Editor package wizard focused GUT returned a failing exit code.",
			row_key=scenario,
			actual_value=str(completed.returncode),
			error=trim_text(combined_output.strip(), 1200),
		))
	if not gut_report_all_tests_passed(combined_output):
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_gut_not_passed",
			test_path,
			"Editor package wizard focused GUT did not report all tests passed.",
			row_key=scenario,
			error=trim_text(combined_output.strip(), 1200),
		))
	if has_godot_script_error(combined_output, ""):
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_script_error",
			test_path,
			"Editor package wizard focused GUT reported a script loading or parse error.",
			row_key=scenario,
			error=trim_text(combined_output.strip(), 1200),
		))
	if has_gdscript_reload_warning(combined_output, ""):
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_reload_warning",
			test_path,
			"Editor package wizard focused GUT reported a GDScript reload warning.",
			row_key=scenario,
			error=trim_text(combined_output.strip(), 1200),
		))

	record_package_editor_wizard_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == 0,
		{
			"test_path": test_path,
			"exit_code": completed.returncode,
			"log_path": log_path.as_posix(),
		},
	)
	with tempfile.TemporaryDirectory(prefix="gf-package-editor-wizard-smoke-", ignore_cleanup_errors=True) as temp_dir:
		temp_root = Path(temp_dir)
		server_root = temp_root / "server"
		output_dir = server_root / "packages"
		registry_path = server_root / "registry/index.json"
		registry_source_path = server_root / "registry/gf-registry-source.json"
		offline_bundle_path = temp_root / "offline_bundle/gf-package-offline-bundle.zip"
		build_data = run_package_smoke_json_command(
			"package_editor_wizard_build_registry",
			[
				sys.executable,
				"tools/build_gf_package.py",
				"--all",
				"--output-dir",
				str(output_dir),
				"--registry",
				str(registry_path),
				"--registry-source",
				str(registry_source_path),
				"--offline-bundle",
				str(offline_bundle_path),
				"--json",
			],
			issues,
		)
		record_package_editor_wizard_smoke_scenario(
			scenarios,
			"build_registry",
			bool(build_data.get("ok")),
			{"package_count": build_data.get("package_count", 0)},
		)
		if bool(build_data.get("ok")):
			run_package_editor_wizard_smoke_minimal_kernel_local_install(
				temp_root,
				registry_path,
				scenarios,
				issues,
			)
			run_package_editor_wizard_smoke_minimal_kernel_local_preset_install(
				temp_root,
				registry_path,
				scenarios,
				issues,
			)
			run_package_editor_wizard_smoke_source_signature_rejection(
				temp_root,
				registry_path,
				scenarios,
				issues,
			)
			run_package_editor_wizard_smoke_package_signature_rejection(
				temp_root,
				registry_path,
				scenarios,
				issues,
			)
			run_package_editor_wizard_smoke_minimal_kernel_offline_bundle_preset_install(
				temp_root,
				offline_bundle_path,
				scenarios,
				issues,
			)
			run_package_editor_wizard_smoke_minimal_kernel_offline_bundle_zip_preset_install(
				temp_root,
				offline_bundle_path,
				scenarios,
				issues,
			)
			server, thread, base_url = start_network_install_smoke_server(server_root, issues)
			if server is not None and thread is not None:
				try:
					run_package_editor_wizard_smoke_minimal_kernel_http_install(
						temp_root,
						base_url,
						registry_path,
						scenarios,
						issues,
					)
					run_package_editor_wizard_smoke_minimal_kernel_http_standard_install(
						temp_root,
						base_url,
						registry_path,
						scenarios,
						issues,
					)
					run_package_editor_wizard_smoke_minimal_kernel_http_preset_install(
						temp_root,
						base_url,
						registry_path,
						scenarios,
						issues,
					)
				finally:
					stop_network_install_smoke_server(server, thread)
	payload = make_package_editor_wizard_smoke_payload(command, scenarios, issues, test_path, log_path)
	if not payload["ok"]:
		payload["stdout_tail"] = trim_text(completed.stdout, 3000)
		payload["stderr_tail"] = trim_text(completed.stderr, 3000)
		payload["log_tail"] = trim_text(log_text, 3000)
	return payload


def run_package_editor_wizard_smoke_minimal_kernel_http_install(
	temp_root: Path,
	base_url: str,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "minimal_kernel_project_editor_install_uninstall"
	start_issue_count = len(issues)
	project_root = temp_root / "minimal_kernel_editor_project"
	write_package_godot_smoke_project(project_root, scenario)
	kernel_archive_path = resolve_package_godot_cli_smoke_local_archive(registry_path, "gf.kernel")
	if kernel_archive_path is None:
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_minimal_kernel_archive_missing",
			"tools/build_gf_package.py",
			"Editor wizard smoke setup should find the locally built gf.kernel archive.",
			row_key=scenario,
		))
		record_package_editor_wizard_smoke_scenario(scenarios, scenario, False)
		return
	extract_package_godot_cli_smoke_archive(kernel_archive_path, project_root, scenario, issues)
	script_path = write_package_editor_wizard_smoke_script(
		project_root,
		network_install_smoke_url(base_url, "registry/index.json"),
	)
	script_data = run_package_editor_wizard_smoke_script(project_root, script_path, scenario, issues)
	assert_package_editor_wizard_smoke_condition(
		bool(script_data.get("ok")),
		issues,
		scenario,
		"package_editor_wizard_smoke_minimal_kernel_install_failed",
		"A project containing only gf.kernel should install and uninstall gf.extension.save through the editor package manager Dock.",
		actual_value=str(script_data.get("issues", [])),
	)
	assert_package_editor_wizard_smoke_condition(
		(project_root / "addons/gf/plugin.gd").is_file()
		and not (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").exists()
		and not (project_root / "addons/gf/extensions/save/gf_extension.json").exists(),
		issues,
		scenario,
		"package_editor_wizard_smoke_minimal_kernel_uninstall_state_invalid",
		"Editor wizard smoke should remove the selected extension closure while keeping gf.kernel.",
	)
	assert_package_editor_wizard_smoke_condition(
		not (project_root / "addons/gf/kernel/package_tools").exists(),
		issues,
		scenario,
		"package_editor_wizard_smoke_minimal_kernel_added_package_tools",
		"Editor wizard install must not add maintenance-side Python package tools to a user project.",
	)
	record_package_editor_wizard_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"package_count": script_data.get("package_count", 0),
			"installed_file_count": script_data.get("installed_file_count", 0),
			"removed_file_count": script_data.get("removed_file_count", 0),
			"selected_package_id": script_data.get("selected_package_id", ""),
		},
	)


def run_package_editor_wizard_smoke_minimal_kernel_local_install(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "minimal_kernel_project_editor_local_install_uninstall"
	start_issue_count = len(issues)
	project_root = temp_root / "minimal_kernel_editor_local_project"
	write_package_godot_smoke_project(project_root, scenario)
	kernel_archive_path = resolve_package_godot_cli_smoke_local_archive(registry_path, "gf.kernel")
	if kernel_archive_path is None:
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_minimal_kernel_local_archive_missing",
			"tools/build_gf_package.py",
			"Editor wizard local registry smoke setup should find the locally built gf.kernel archive.",
			row_key=scenario,
		))
		record_package_editor_wizard_smoke_scenario(scenarios, scenario, False)
		return
	extract_package_godot_cli_smoke_archive(kernel_archive_path, project_root, scenario, issues)
	script_path = write_package_editor_wizard_smoke_script(
		project_root,
		registry_path.as_posix(),
	)
	script_data = run_package_editor_wizard_smoke_script(project_root, script_path, scenario, issues)
	installed_archive = str(script_data.get("installed_archive", ""))
	assert_package_editor_wizard_smoke_condition(
		bool(script_data.get("ok")),
		issues,
		scenario,
		"package_editor_wizard_smoke_minimal_kernel_local_install_failed",
		"A project containing only gf.kernel should install and uninstall gf.extension.save through the editor package manager Dock using a local registry file.",
		actual_value=str(script_data.get("issues", [])),
	)
	assert_package_editor_wizard_smoke_condition(
		installed_archive
		and not installed_archive.startswith("http://")
		and not installed_archive.startswith("https://"),
		issues,
		scenario,
		"package_editor_wizard_smoke_minimal_kernel_local_archive_is_remote",
		"Editor wizard local registry install should not persist a remote archive URL in the lockfile.",
		actual_value=installed_archive,
	)
	assert_package_editor_wizard_smoke_condition(
		(project_root / "addons/gf/plugin.gd").is_file()
		and not (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").exists()
		and not (project_root / "addons/gf/extensions/save/gf_extension.json").exists(),
		issues,
		scenario,
		"package_editor_wizard_smoke_minimal_kernel_local_uninstall_state_invalid",
		"Editor wizard local registry smoke should remove the selected extension closure while keeping gf.kernel.",
	)
	assert_package_editor_wizard_smoke_condition(
		not (project_root / "addons/gf/kernel/package_tools").exists(),
		issues,
		scenario,
		"package_editor_wizard_smoke_minimal_kernel_local_added_package_tools",
		"Editor wizard local registry install must not add maintenance-side Python package tools to a user project.",
	)
	record_package_editor_wizard_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"package_count": script_data.get("package_count", 0),
			"installed_file_count": script_data.get("installed_file_count", 0),
			"removed_file_count": script_data.get("removed_file_count", 0),
			"selected_package_id": script_data.get("selected_package_id", ""),
		},
	)


def run_package_editor_wizard_smoke_minimal_kernel_local_preset_install(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
	scenario: str = "minimal_kernel_project_editor_local_preset_install_uninstall",
	project_dir_name: str = "minimal_kernel_editor_local_preset_project",
	dock_registry_value: str = "",
) -> None:
	start_issue_count = len(issues)
	project_root = temp_root / project_dir_name
	write_package_godot_smoke_project(project_root, scenario)
	kernel_archive_path = resolve_package_godot_cli_smoke_local_archive(registry_path, "gf.kernel")
	if kernel_archive_path is None:
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_minimal_kernel_local_preset_archive_missing",
			"tools/build_gf_package.py",
			"Editor wizard local registry preset smoke setup should find the locally built gf.kernel archive.",
			row_key=scenario,
		))
		record_package_editor_wizard_smoke_scenario(scenarios, scenario, False)
		return
	extract_package_godot_cli_smoke_archive(kernel_archive_path, project_root, scenario, issues)
	script_path = write_package_editor_wizard_smoke_preset_script(
		project_root,
		dock_registry_value if dock_registry_value else registry_path.as_posix(),
	)
	script_data = run_package_editor_wizard_smoke_script(project_root, script_path, scenario, issues)
	installed_archive = str(script_data.get("installed_archive", ""))
	assert_package_editor_wizard_smoke_condition(
		bool(script_data.get("ok")),
		issues,
		scenario,
		"package_editor_wizard_smoke_minimal_kernel_local_preset_install_failed",
		"A project containing only gf.kernel should install and uninstall gf.preset.rpg_save_dialogue through the editor package manager Dock using a local registry file.",
		actual_value=str(script_data.get("issues", [])),
	)
	assert_package_editor_wizard_smoke_condition(
		installed_archive
		and not installed_archive.startswith("http://")
		and not installed_archive.startswith("https://"),
		issues,
		scenario,
		"package_editor_wizard_smoke_minimal_kernel_local_preset_archive_is_remote",
		"Editor wizard local registry preset install should persist local archive paths for concrete packages.",
		actual_value=installed_archive,
	)
	assert_package_editor_wizard_smoke_condition(
		(project_root / "addons/gf/plugin.gd").is_file()
		and not (project_root / "addons/gf/extensions/save/gf_extension.json").exists()
		and not (project_root / "addons/gf/extensions/dialogue/gf_extension.json").exists()
		and not (project_root / "addons/gf/extensions/domain/gf_extension.json").exists()
		and not (project_root / "addons/gf/standard/utilities/config/gf_config_provider.gd").exists()
		and not (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").exists()
		and not (project_root / "addons/gf/standard/foundation/deterministic/gf_deterministic_variant_serializer.gd").exists(),
		issues,
		scenario,
		"package_editor_wizard_smoke_minimal_kernel_local_preset_uninstall_state_invalid",
		"Editor wizard local registry preset smoke should remove the selected preset closure while keeping gf.kernel.",
	)
	assert_package_editor_wizard_smoke_condition(
		not (project_root / "addons/gf/kernel/package_tools").exists(),
		issues,
		scenario,
		"package_editor_wizard_smoke_minimal_kernel_local_preset_added_package_tools",
		"Editor wizard local registry preset install must not add maintenance-side Python package tools to a user project.",
	)
	record_package_editor_wizard_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"package_count": script_data.get("package_count", 0),
			"installed_file_count": script_data.get("installed_file_count", 0),
			"removed_file_count": script_data.get("removed_file_count", 0),
			"selected_package_id": script_data.get("selected_package_id", ""),
			"installed_archive": installed_archive,
		},
	)


def run_package_editor_wizard_smoke_source_signature_rejection(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "minimal_kernel_project_editor_source_signature_status_rejection"
	start_issue_count = len(issues)
	project_root = temp_root / "minimal_kernel_editor_source_signature_project"
	write_package_godot_smoke_project(project_root, scenario)
	kernel_archive_path = resolve_package_godot_cli_smoke_local_archive(registry_path, "gf.kernel")
	if kernel_archive_path is None:
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_source_signature_archive_missing",
			"tools/build_gf_package.py",
			"Editor wizard source signature smoke setup should find the locally built gf.kernel archive.",
			row_key=scenario,
		))
		record_package_editor_wizard_smoke_scenario(scenarios, scenario, False)
		return
	extract_package_godot_cli_smoke_archive(kernel_archive_path, project_root, scenario, issues)
	source_path = temp_root / "editor_source_signature/gf-registry-source.json"
	registry_ref = os.path.relpath(registry_path, source_path.parent).replace("\\", "/")
	write_json_object(source_path, {
		"schema_version": 1,
		"default_channel": "stable",
		"registry_signature_url": "gf-registry-unreleased.json.sig",
		"channels": {
			"stable": {
				"registry": registry_ref,
				"registry_sha256": sha256_file(registry_path),
				"registry_size_bytes": registry_path.stat().st_size,
			},
		},
	})
	script_path = write_package_editor_wizard_smoke_status_rejection_script(
		project_root,
		source_path.as_posix(),
		"Registry source manifest signature field is not supported until native verification is implemented",
		"",
	)
	script_data = run_package_editor_wizard_smoke_script(project_root, script_path, scenario, issues)
	assert_package_editor_wizard_smoke_condition(
		bool(script_data.get("ok")),
		issues,
		scenario,
		"package_editor_wizard_smoke_source_signature_not_rejected",
		"Editor package manager Dock should surface registry source signature rejection and keep package rows empty.",
		actual_value=str(script_data.get("issues", [])),
	)
	assert_package_editor_wizard_smoke_condition(
		not (project_root / ".gf/packages.lock.json").exists()
		and not (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").exists()
		and not (project_root / "addons/gf/extensions/save/gf_extension.json").exists()
		and (project_root / "addons/gf/plugin.gd").is_file(),
		issues,
		scenario,
		"package_editor_wizard_smoke_source_signature_mutated_project",
		"Editor source signature rejection must not write lockfiles or package files.",
	)
	record_package_editor_wizard_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"status_package_count": script_data.get("status_package_count", 0),
			"dock_package_count": script_data.get("dock_package_count", 0),
			"issue_count": script_data.get("status_issue_count", 0),
		},
	)


def run_package_editor_wizard_smoke_package_signature_rejection(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "minimal_kernel_project_editor_package_signature_status_rejection"
	start_issue_count = len(issues)
	project_root = temp_root / "minimal_kernel_editor_package_signature_project"
	write_package_godot_smoke_project(project_root, scenario)
	kernel_archive_path = resolve_package_godot_cli_smoke_local_archive(registry_path, "gf.kernel")
	if kernel_archive_path is None:
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_package_signature_archive_missing",
			"tools/build_gf_package.py",
			"Editor wizard package signature smoke setup should find the locally built gf.kernel archive.",
			row_key=scenario,
		))
		record_package_editor_wizard_smoke_scenario(scenarios, scenario, False)
		return
	extract_package_godot_cli_smoke_archive(kernel_archive_path, project_root, scenario, issues)
	registry_data = read_json_object(registry_path)
	packages = registry_data.get("packages", {})
	if not isinstance(packages, dict) or not isinstance(packages.get("gf.extension.save"), dict):
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_package_signature_fixture_invalid",
			registry_path.as_posix(),
			"Editor wizard package signature smoke fixture should contain gf.extension.save.",
			row_key=scenario,
		))
		record_package_editor_wizard_smoke_scenario(scenarios, scenario, False)
		return
	save_entry = packages["gf.extension.save"]
	save_entry["signature_url"] = "gf-extension-save-unreleased.zip.sig"
	signed_registry_path = temp_root / "editor_package_signature/index.json"
	write_json_object(signed_registry_path, registry_data)
	script_path = write_package_editor_wizard_smoke_status_rejection_script(
		project_root,
		signed_registry_path.as_posix(),
		"Registry package signature field is not supported until native verification is implemented",
		"gf.extension.save",
	)
	script_data = run_package_editor_wizard_smoke_script(project_root, script_path, scenario, issues)
	assert_package_editor_wizard_smoke_condition(
		bool(script_data.get("ok")),
		issues,
		scenario,
		"package_editor_wizard_smoke_package_signature_not_rejected",
		"Editor package manager Dock should surface registry package signature rejection and not expose that package as selectable.",
		actual_value=str(script_data.get("issues", [])),
	)
	assert_package_editor_wizard_smoke_condition(
		not (project_root / ".gf/packages.lock.json").exists()
		and not (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").exists()
		and not (project_root / "addons/gf/extensions/save/gf_extension.json").exists()
		and (project_root / "addons/gf/plugin.gd").is_file(),
		issues,
		scenario,
		"package_editor_wizard_smoke_package_signature_mutated_project",
		"Editor package signature rejection must not write lockfiles or package files.",
	)
	record_package_editor_wizard_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"status_package_count": script_data.get("status_package_count", 0),
			"dock_package_count": script_data.get("dock_package_count", 0),
			"issue_count": script_data.get("status_issue_count", 0),
			"forbidden_package_id": "gf.extension.save",
		},
	)


def run_package_editor_wizard_smoke_minimal_kernel_offline_bundle_preset_install(
	temp_root: Path,
	offline_bundle_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "minimal_kernel_project_editor_offline_bundle_preset_install_uninstall"
	start_issue_count = len(issues)
	extract_root = temp_root / "editor_offline_bundle_extracted"
	extract_package_godot_cli_smoke_offline_bundle(offline_bundle_path, extract_root, scenario, issues)
	extracted_registry_path = extract_root / "registry/index.json"
	assert_package_editor_wizard_smoke_condition(
		extracted_registry_path.is_file(),
		issues,
		scenario,
		"package_editor_wizard_smoke_offline_bundle_registry_missing",
		"Extracted offline bundle should contain registry/index.json for local editor wizard installs.",
		expected_value="registry/index.json",
	)
	if not extracted_registry_path.is_file():
		record_package_editor_wizard_smoke_scenario(scenarios, scenario, False)
		return
	run_package_editor_wizard_smoke_minimal_kernel_local_preset_install(
		temp_root,
		extracted_registry_path,
		scenarios,
		issues,
		scenario,
		"minimal_kernel_editor_offline_bundle_preset_project",
	)
	if len(scenarios) == 0:
		return
	scenario_record = scenarios[-1]
	if scenario_record.get("name") != scenario:
		return
	scenario_record["offline_bundle"] = offline_bundle_path.as_posix()
	scenario_record["extracted_registry"] = extracted_registry_path.as_posix()
	scenario_record["offline_bundle_entry_count"] = package_godot_cli_smoke_zip_file_count(offline_bundle_path)
	scenario_record["ok"] = bool(scenario_record.get("ok")) and len(issues) == start_issue_count


def run_package_editor_wizard_smoke_minimal_kernel_offline_bundle_zip_preset_install(
	temp_root: Path,
	offline_bundle_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "minimal_kernel_project_editor_offline_bundle_zip_preset_install_uninstall"
	start_issue_count = len(issues)
	extract_root = temp_root / "editor_offline_bundle_zip_setup_extracted"
	extract_package_godot_cli_smoke_offline_bundle(offline_bundle_path, extract_root, scenario, issues)
	extracted_registry_path = extract_root / "registry/index.json"
	assert_package_editor_wizard_smoke_condition(
		extracted_registry_path.is_file(),
		issues,
		scenario,
		"package_editor_wizard_smoke_offline_bundle_zip_setup_registry_missing",
		"Extracted offline bundle should contain registry/index.json for minimal-kernel fixture setup.",
		expected_value="registry/index.json",
	)
	if not extracted_registry_path.is_file():
		record_package_editor_wizard_smoke_scenario(scenarios, scenario, False)
		return
	run_package_editor_wizard_smoke_minimal_kernel_local_preset_install(
		temp_root,
		extracted_registry_path,
		scenarios,
		issues,
		scenario,
		"minimal_kernel_editor_offline_bundle_zip_preset_project",
		offline_bundle_path.as_posix(),
	)
	if len(scenarios) == 0:
		return
	scenario_record = scenarios[-1]
	if scenario_record.get("name") != scenario:
		return
	scenario_record["offline_bundle"] = offline_bundle_path.as_posix()
	scenario_record["setup_registry"] = extracted_registry_path.as_posix()
	scenario_record["offline_bundle_entry_count"] = package_godot_cli_smoke_zip_file_count(offline_bundle_path)
	scenario_record["ok"] = bool(scenario_record.get("ok")) and len(issues) == start_issue_count


def run_package_editor_wizard_smoke_minimal_kernel_http_standard_install(
	temp_root: Path,
	base_url: str,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "minimal_kernel_project_editor_standard_install_uninstall"
	start_issue_count = len(issues)
	project_root = temp_root / "minimal_kernel_editor_standard_project"
	write_package_godot_smoke_project(project_root, scenario)
	kernel_archive_path = resolve_package_godot_cli_smoke_local_archive(registry_path, "gf.kernel")
	if kernel_archive_path is None:
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_minimal_kernel_standard_archive_missing",
			"tools/build_gf_package.py",
			"Editor wizard standard smoke setup should find the locally built gf.kernel archive.",
			row_key=scenario,
		))
		record_package_editor_wizard_smoke_scenario(scenarios, scenario, False)
		return
	extract_package_godot_cli_smoke_archive(kernel_archive_path, project_root, scenario, issues)
	script_path = write_package_editor_wizard_smoke_standard_script(
		project_root,
		network_install_smoke_url(base_url, "registry/index.json"),
	)
	script_data = run_package_editor_wizard_smoke_script(project_root, script_path, scenario, issues)
	assert_package_editor_wizard_smoke_condition(
		bool(script_data.get("ok")),
		issues,
		scenario,
		"package_editor_wizard_smoke_minimal_kernel_standard_install_failed",
		"A project containing only gf.kernel should install and uninstall gf.standard.storage through the editor package manager Dock.",
		actual_value=str(script_data.get("issues", [])),
	)
	assert_package_editor_wizard_smoke_condition(
		(project_root / "addons/gf/plugin.gd").is_file()
		and not (project_root / "addons/gf/standard/utilities/logging/gf_log_utility.gd").exists()
		and not (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").exists()
		and not (project_root / "addons/gf/extensions/save/gf_extension.json").exists(),
		issues,
		scenario,
		"package_editor_wizard_smoke_minimal_kernel_standard_uninstall_state_invalid",
		"Editor wizard standard smoke should remove the selected standard closure while keeping gf.kernel.",
	)
	assert_package_editor_wizard_smoke_condition(
		not (project_root / "addons/gf/kernel/package_tools").exists(),
		issues,
		scenario,
		"package_editor_wizard_smoke_minimal_kernel_standard_added_package_tools",
		"Editor wizard standard install must not add maintenance-side Python package tools to a user project.",
	)
	record_package_editor_wizard_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"package_count": script_data.get("package_count", 0),
			"installed_file_count": script_data.get("installed_file_count", 0),
			"removed_file_count": script_data.get("removed_file_count", 0),
			"selected_package_id": script_data.get("selected_package_id", ""),
		},
	)


def run_package_editor_wizard_smoke_minimal_kernel_http_preset_install(
	temp_root: Path,
	base_url: str,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "minimal_kernel_project_editor_preset_install_uninstall"
	start_issue_count = len(issues)
	project_root = temp_root / "minimal_kernel_editor_preset_project"
	write_package_godot_smoke_project(project_root, scenario)
	kernel_archive_path = resolve_package_godot_cli_smoke_local_archive(registry_path, "gf.kernel")
	if kernel_archive_path is None:
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_minimal_kernel_preset_archive_missing",
			"tools/build_gf_package.py",
			"Editor wizard preset smoke setup should find the locally built gf.kernel archive.",
			row_key=scenario,
		))
		record_package_editor_wizard_smoke_scenario(scenarios, scenario, False)
		return
	extract_package_godot_cli_smoke_archive(kernel_archive_path, project_root, scenario, issues)
	script_path = write_package_editor_wizard_smoke_preset_script(
		project_root,
		network_install_smoke_url(base_url, "registry/index.json"),
	)
	script_data = run_package_editor_wizard_smoke_script(project_root, script_path, scenario, issues)
	assert_package_editor_wizard_smoke_condition(
		bool(script_data.get("ok")),
		issues,
		scenario,
		"package_editor_wizard_smoke_minimal_kernel_preset_install_failed",
		"A project containing only gf.kernel should install and uninstall gf.preset.rpg_save_dialogue through the editor package manager Dock.",
		actual_value=str(script_data.get("issues", [])),
	)
	assert_package_editor_wizard_smoke_condition(
		(project_root / "addons/gf/plugin.gd").is_file()
		and not (project_root / "addons/gf/extensions/save/gf_extension.json").exists()
		and not (project_root / "addons/gf/extensions/dialogue/gf_extension.json").exists()
		and not (project_root / "addons/gf/extensions/domain/gf_extension.json").exists()
		and not (project_root / "addons/gf/standard/utilities/config/gf_config_provider.gd").exists()
		and not (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").exists()
		and not (project_root / "addons/gf/standard/foundation/deterministic/gf_deterministic_variant_serializer.gd").exists(),
		issues,
		scenario,
		"package_editor_wizard_smoke_minimal_kernel_preset_uninstall_state_invalid",
		"Editor wizard preset smoke should remove the selected preset closure while keeping gf.kernel.",
	)
	assert_package_editor_wizard_smoke_condition(
		not (project_root / "addons/gf/kernel/package_tools").exists(),
		issues,
		scenario,
		"package_editor_wizard_smoke_minimal_kernel_preset_added_package_tools",
		"Editor wizard preset install must not add maintenance-side Python package tools to a user project.",
	)
	record_package_editor_wizard_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"package_count": script_data.get("package_count", 0),
			"installed_file_count": script_data.get("installed_file_count", 0),
			"removed_file_count": script_data.get("removed_file_count", 0),
			"selected_package_id": script_data.get("selected_package_id", ""),
		},
	)


def write_package_editor_wizard_smoke_script(project_root: Path, registry_url: str) -> Path:
	script_path = project_root / ".gf/package_editor_wizard_minimal_smoke.gd"
	script_path.parent.mkdir(parents=True, exist_ok=True)
	script_path.write_text(
		"\n".join([
			"extends SceneTree",
			"",
			"const DOCK_SCRIPT_PATH: String = \"res://addons/gf/kernel/editor/package/gf_package_manager_dock.gd\"",
			f"const REGISTRY_URL: String = {json.dumps(registry_url)}",
			"",
			"func _init() -> void:",
			"\tvar result: Dictionary = _run_smoke()",
			"\tprint(JSON.stringify(result))",
			"\tquit(0 if bool(result.get(\"ok\", false)) else 1)",
			"",
			"",
			"func _run_smoke() -> Dictionary:",
			"\tvar dock_script_resource: Resource = load(DOCK_SCRIPT_PATH)",
			"\tif not (dock_script_resource is Script):",
			"\t\treturn _fail(\"dock_script_missing\", \"Package manager Dock script could not be loaded.\")",
			"\tvar dock_script: Script = dock_script_resource",
			"\tvar dock_value: Variant = dock_script.new()",
			"\tif not (dock_value is VBoxContainer):",
			"\t\treturn _fail(\"dock_instance_invalid\", \"Package manager Dock did not instantiate as VBoxContainer.\")",
			"\tvar dock: VBoxContainer = dock_value",
			"\tget_root().add_child(dock)",
			"\tvar registry_field_value: Variant = dock.get(\"_registry_field\")",
			"\tif not (registry_field_value is LineEdit):",
			"\t\treturn _fail(\"registry_field_missing\", \"Package manager Dock registry field is unavailable.\")",
			"\tvar registry_field: LineEdit = registry_field_value",
			"\tregistry_field.text = REGISTRY_URL",
			"\tvar refresh_result: Variant = dock.call(\"_refresh_status\")",
			"\tvar _unused_refresh: Variant = refresh_result",
			"\tvar packages_value: Variant = dock.get(\"_packages\")",
			"\tif not (packages_value is Array):",
			"\t\treturn _fail(\"packages_missing\", \"Package manager Dock did not load package entries.\")",
			"\tvar packages: Array = packages_value",
			"\tif not _has_package(packages, \"gf.extension.save\"):",
			"\t\treturn _fail(\"save_package_missing\", \"HTTP registry did not expose gf.extension.save in the Dock.\", {\"package_count\": packages.size()})",
			"\tvar view_filter_value: Variant = dock.get(\"_view_filter_option\")",
			"\tif view_filter_value is OptionButton:",
			"\t\tvar view_filter: OptionButton = view_filter_value",
			"\t\tview_filter.select(1)",
			"\t\tvar view_result: Variant = dock.call(\"_on_view_filter_selected\", 1)",
			"\t\tvar _unused_view: Variant = view_result",
			"\tvar select_result: Variant = dock.call(\"_select_package\", \"gf.extension.save\")",
			"\tvar _unused_select: Variant = select_result",
			"\tvar selected_package_id: String = str(dock.get(\"_selected_package_id\"))",
			"\tif selected_package_id != \"gf.extension.save\":",
			"\t\treturn _fail(\"save_package_not_selected\", \"Package manager Dock did not select gf.extension.save.\", {\"selected_package_id\": selected_package_id})",
			"\tvar details_value: Variant = dock.get(\"_details_output\")",
			"\tif details_value is TextEdit:",
			"\t\tvar details_output: TextEdit = details_value",
			"\t\tif not details_output.text.contains(\"install preview:\"):",
			"\t\t\treturn _fail(\"install_preview_missing\", \"Package manager Dock details did not expose the install preview.\")",
			"\tvar install_value: Variant = dock.call(\"_run_native_operation\", \"install\", false)",
			"\tif not (install_value is Dictionary):",
			"\t\treturn _fail(\"install_result_invalid\", \"Package manager Dock native install did not return a Dictionary.\")",
			"\tvar install_result: Dictionary = install_value",
			"\tif not bool(install_result.get(\"ok\", false)):",
			"\t\treturn _fail(\"install_failed\", \"Package manager Dock native install failed.\", {\"issues\": install_result.get(\"issues\", [])})",
			"\tif not FileAccess.file_exists(\"res://addons/gf/extensions/save/gf_extension.json\"):",
			"\t\treturn _fail(\"save_manifest_missing\", \"Save extension manifest was not installed.\")",
			"\tif not FileAccess.file_exists(\"res://addons/gf/standard/utilities/storage/gf_storage_utility.gd\"):",
			"\t\treturn _fail(\"storage_utility_missing\", \"Storage standard dependency was not installed.\")",
			"\tif DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(\"res://addons/gf/kernel/package_tools\")):",
			"\t\treturn _fail(\"package_tools_added\", \"Maintenance-side Python package tools were installed into the user project.\")",
			"\tvar installed_archive: String = _lockfile_archive(\"gf.extension.save\")",
			"\tvar refresh_after_install: Variant = dock.call(\"_refresh_status\")",
			"\tvar _unused_refresh_after_install: Variant = refresh_after_install",
			"\tvar select_installed_result: Variant = dock.call(\"_select_package\", \"gf.extension.save\")",
			"\tvar _unused_select_installed: Variant = select_installed_result",
			"\tif details_value is TextEdit:",
			"\t\tvar uninstall_details_output: TextEdit = details_value",
			"\t\tif not uninstall_details_output.text.contains(\"uninstall preview:\"):",
			"\t\t\treturn _fail(\"uninstall_preview_missing\", \"Package manager Dock details did not expose the uninstall preview after install.\")",
			"\tvar uninstall_value: Variant = dock.call(\"_run_native_operation\", \"uninstall\", false)",
			"\tif not (uninstall_value is Dictionary):",
			"\t\treturn _fail(\"uninstall_result_invalid\", \"Package manager Dock native uninstall did not return a Dictionary.\")",
			"\tvar uninstall_result: Dictionary = uninstall_value",
			"\tif not bool(uninstall_result.get(\"ok\", false)):",
			"\t\treturn _fail(\"uninstall_failed\", \"Package manager Dock native uninstall failed.\", {\"issues\": uninstall_result.get(\"issues\", [])})",
			"\tif FileAccess.file_exists(\"res://addons/gf/extensions/save/gf_extension.json\"):",
			"\t\treturn _fail(\"save_manifest_left_after_uninstall\", \"Save extension manifest was left after uninstall.\")",
			"\tif FileAccess.file_exists(\"res://addons/gf/standard/utilities/storage/gf_storage_utility.gd\"):",
			"\t\treturn _fail(\"storage_utility_left_after_uninstall\", \"Storage standard dependency was left after uninstall.\")",
			"\tif not FileAccess.file_exists(\"res://addons/gf/plugin.gd\"):",
			"\t\treturn _fail(\"kernel_removed_after_uninstall\", \"Kernel plugin entry was removed after uninstall.\")",
			"\tif DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(\"res://addons/gf/kernel/package_tools\")):",
			"\t\treturn _fail(\"package_tools_left_after_uninstall\", \"Maintenance-side Python package tools exist after uninstall.\")",
			"\treturn {",
			"\t\t\"ok\": true,",
			"\t\t\"package_count\": packages.size(),",
			"\t\t\"installed_file_count\": int(install_result.get(\"installed_file_count\", 0)),",
			"\t\t\"removed_file_count\": int(uninstall_result.get(\"removed_file_count\", 0)),",
			"\t\t\"selected_package_id\": selected_package_id,",
			"\t\t\"installed_archive\": installed_archive,",
			"\t}",
			"",
			"",
			"func _lockfile_installed() -> Dictionary:",
			"\tvar file: FileAccess = FileAccess.open(\"res://.gf/packages.lock.json\", FileAccess.READ)",
			"\tif file == null:",
			"\t\treturn {}",
			"\tvar text: String = file.get_as_text()",
			"\tvar parsed: Variant = JSON.parse_string(text)",
			"\tif not (parsed is Dictionary):",
			"\t\treturn {}",
			"\tvar data: Dictionary = parsed",
			"\tvar installed_value: Variant = data.get(\"installed\", {})",
			"\tif installed_value is Dictionary:",
			"\t\treturn installed_value",
			"\treturn {}",
			"",
			"",
			"func _lockfile_archive(package_id: String) -> String:",
			"\tvar installed: Dictionary = _lockfile_installed()",
			"\tvar entry_value: Variant = installed.get(package_id, {})",
			"\tif entry_value is Dictionary:",
			"\t\tvar entry: Dictionary = entry_value",
			"\t\treturn str(entry.get(\"archive\", \"\"))",
			"\treturn \"\"",
			"",
			"",
			"func _has_package(packages: Array, package_id: String) -> bool:",
			"\tfor package_value: Variant in packages:",
			"\t\tif package_value is Dictionary:",
			"\t\t\tvar package_entry: Dictionary = package_value",
			"\t\t\tif str(package_entry.get(\"id\", \"\")) == package_id:",
			"\t\t\t\treturn true",
			"\treturn false",
			"",
			"",
			"func _fail(kind: String, message: String, extra: Dictionary = {}) -> Dictionary:",
			"\tvar result: Dictionary = {",
			"\t\t\"ok\": false,",
			"\t\t\"issues\": [message],",
			"\t\t\"kind\": kind,",
			"\t}",
			"\tfor key: Variant in extra.keys():",
			"\t\tresult[key] = extra[key]",
			"\treturn result",
			"",
		]) + "\n",
		encoding="utf-8",
	)
	return script_path


def write_package_editor_wizard_smoke_standard_script(project_root: Path, registry_url: str) -> Path:
	script_path = project_root / ".gf/package_editor_wizard_minimal_standard_smoke.gd"
	script_path.parent.mkdir(parents=True, exist_ok=True)
	script_path.write_text(
		"\n".join([
			"extends SceneTree",
			"",
			"const DOCK_SCRIPT_PATH: String = \"res://addons/gf/kernel/editor/package/gf_package_manager_dock.gd\"",
			"const PACKAGE_ID: String = \"gf.standard.storage\"",
			f"const REGISTRY_URL: String = {json.dumps(registry_url)}",
			"",
			"func _init() -> void:",
			"\tvar result: Dictionary = _run_smoke()",
			"\tprint(JSON.stringify(result))",
			"\tquit(0 if bool(result.get(\"ok\", false)) else 1)",
			"",
			"",
			"func _run_smoke() -> Dictionary:",
			"\tvar dock_script_resource: Resource = load(DOCK_SCRIPT_PATH)",
			"\tif not (dock_script_resource is Script):",
			"\t\treturn _fail(\"dock_script_missing\", \"Package manager Dock script could not be loaded.\")",
			"\tvar dock_script: Script = dock_script_resource",
			"\tvar dock_value: Variant = dock_script.new()",
			"\tif not (dock_value is VBoxContainer):",
			"\t\treturn _fail(\"dock_instance_invalid\", \"Package manager Dock did not instantiate as VBoxContainer.\")",
			"\tvar dock: VBoxContainer = dock_value",
			"\tget_root().add_child(dock)",
			"\tvar registry_field_value: Variant = dock.get(\"_registry_field\")",
			"\tif not (registry_field_value is LineEdit):",
			"\t\treturn _fail(\"registry_field_missing\", \"Package manager Dock registry field is unavailable.\")",
			"\tvar registry_field: LineEdit = registry_field_value",
			"\tregistry_field.text = REGISTRY_URL",
			"\tvar refresh_result: Variant = dock.call(\"_refresh_status\")",
			"\tvar _unused_refresh: Variant = refresh_result",
			"\tvar packages_value: Variant = dock.get(\"_packages\")",
			"\tif not (packages_value is Array):",
			"\t\treturn _fail(\"packages_missing\", \"Package manager Dock did not load package entries.\")",
			"\tvar packages: Array = packages_value",
			"\tif not _has_package(packages, PACKAGE_ID):",
			"\t\treturn _fail(\"standard_package_missing\", \"HTTP registry did not expose gf.standard.storage in the Dock.\", {\"package_count\": packages.size()})",
			"\tvar view_filter_value: Variant = dock.get(\"_view_filter_option\")",
			"\tif view_filter_value is OptionButton:",
			"\t\tvar view_filter: OptionButton = view_filter_value",
			"\t\tview_filter.select(2)",
			"\t\tvar view_result: Variant = dock.call(\"_on_view_filter_selected\", 2)",
			"\t\tvar _unused_view: Variant = view_result",
			"\tvar select_result: Variant = dock.call(\"_select_package\", PACKAGE_ID)",
			"\tvar _unused_select: Variant = select_result",
			"\tvar selected_package_id: String = str(dock.get(\"_selected_package_id\"))",
			"\tif selected_package_id != PACKAGE_ID:",
			"\t\treturn _fail(\"standard_package_not_selected\", \"Package manager Dock did not select gf.standard.storage.\", {\"selected_package_id\": selected_package_id})",
			"\tvar details_value: Variant = dock.get(\"_details_output\")",
			"\tif details_value is TextEdit:",
			"\t\tvar details_output: TextEdit = details_value",
			"\t\tif not details_output.text.contains(\"install preview:\"):",
			"\t\t\treturn _fail(\"install_preview_missing\", \"Package manager Dock details did not expose the standard install preview.\")",
			"\tvar install_value: Variant = dock.call(\"_run_native_operation\", \"install\", false)",
			"\tif not (install_value is Dictionary):",
			"\t\treturn _fail(\"install_result_invalid\", \"Package manager Dock native standard install did not return a Dictionary.\")",
			"\tvar install_result: Dictionary = install_value",
			"\tif not bool(install_result.get(\"ok\", false)):",
			"\t\treturn _fail(\"install_failed\", \"Package manager Dock native standard install failed.\", {\"issues\": install_result.get(\"issues\", [])})",
			"\tvar installed_after_install: Dictionary = _lockfile_installed()",
			"\tfor package_id: String in [\"gf.kernel\", \"gf.standard.base\", PACKAGE_ID]:",
			"\t\tif not installed_after_install.has(package_id):",
			"\t\t\treturn _fail(\"installed_package_missing\", \"Standard install did not record an expected package in the lockfile.\", {\"package_id\": package_id})",
			"\tfor unexpected_package_id: String in [\"gf.extension.save\", \"gf.preset.save\", \"gf.preset.rpg_save_dialogue\"]:",
			"\t\tif installed_after_install.has(unexpected_package_id):",
			"\t\t\treturn _fail(\"unexpected_package_installed\", \"Direct standard install should not install extension or preset packages.\", {\"package_id\": unexpected_package_id})",
			"\tvar storage_entry_value: Variant = installed_after_install.get(PACKAGE_ID, {})",
			"\tif storage_entry_value is Dictionary:",
			"\t\tvar storage_entry: Dictionary = storage_entry_value",
			"\t\tvar storage_reason_value: Variant = storage_entry.get(\"reason\", [])",
			"\t\tif storage_reason_value is Array:",
			"\t\t\tvar storage_reasons: Array = storage_reason_value",
			"\t\t\tif not storage_reasons.has(\"manual\"):",
			"\t\t\t\treturn _fail(\"manual_reason_missing\", \"Direct standard install should pin the selected standard package as manual.\")",
			"\tfor relative_path: String in [",
			"\t\t\"res://addons/gf/standard/utilities/logging/gf_log_utility.gd\",",
			"\t\t\"res://addons/gf/standard/utilities/storage/gf_storage_utility.gd\",",
			"\t]:",
			"\t\tif not FileAccess.file_exists(relative_path):",
			"\t\t\treturn _fail(\"installed_file_missing\", \"Standard install did not materialize an expected package file.\", {\"path\": relative_path})",
			"\tif FileAccess.file_exists(\"res://addons/gf/extensions/save/gf_extension.json\"):",
			"\t\treturn _fail(\"extension_file_added\", \"Direct standard install should not add extension files.\")",
			"\tif DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(\"res://addons/gf/kernel/package_tools\")):",
			"\t\treturn _fail(\"package_tools_added\", \"Maintenance-side Python package tools were installed into the user project.\")",
			"\tvar refresh_after_install: Variant = dock.call(\"_refresh_status\")",
			"\tvar _unused_refresh_after_install: Variant = refresh_after_install",
			"\tvar select_installed_result: Variant = dock.call(\"_select_package\", PACKAGE_ID)",
			"\tvar _unused_select_installed: Variant = select_installed_result",
			"\tif details_value is TextEdit:",
			"\t\tvar uninstall_details_output: TextEdit = details_value",
			"\t\tif not uninstall_details_output.text.contains(\"uninstall preview:\"):",
			"\t\t\treturn _fail(\"uninstall_preview_missing\", \"Package manager Dock details did not expose the standard uninstall preview after install.\")",
			"\tvar uninstall_value: Variant = dock.call(\"_run_native_operation\", \"uninstall\", false)",
			"\tif not (uninstall_value is Dictionary):",
			"\t\treturn _fail(\"uninstall_result_invalid\", \"Package manager Dock native standard uninstall did not return a Dictionary.\")",
			"\tvar uninstall_result: Dictionary = uninstall_value",
			"\tif not bool(uninstall_result.get(\"ok\", false)):",
			"\t\treturn _fail(\"uninstall_failed\", \"Package manager Dock native standard uninstall failed.\", {\"issues\": uninstall_result.get(\"issues\", [])})",
			"\tvar installed_after_uninstall: Dictionary = _lockfile_installed()",
			"\tif installed_after_uninstall.keys().size() != 1 or not installed_after_uninstall.has(\"gf.kernel\"):",
			"\t\treturn _fail(\"uninstall_lockfile_invalid\", \"Standard uninstall should prune the project back to kernel-only.\", {\"installed\": installed_after_uninstall.keys()})",
			"\tfor relative_path: String in [",
			"\t\t\"res://addons/gf/standard/utilities/logging/gf_log_utility.gd\",",
			"\t\t\"res://addons/gf/standard/utilities/storage/gf_storage_utility.gd\",",
			"\t]:",
			"\t\tif FileAccess.file_exists(relative_path):",
			"\t\t\treturn _fail(\"package_file_left_after_uninstall\", \"Standard uninstall left an expected package file behind.\", {\"path\": relative_path})",
			"\tif FileAccess.file_exists(\"res://addons/gf/extensions/save/gf_extension.json\"):",
			"\t\treturn _fail(\"extension_file_left_after_uninstall\", \"Direct standard install/uninstall should not leave extension files.\")",
			"\tif not FileAccess.file_exists(\"res://addons/gf/plugin.gd\"):",
			"\t\treturn _fail(\"kernel_removed_after_uninstall\", \"Kernel plugin entry was removed after standard uninstall.\")",
			"\tif DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(\"res://addons/gf/kernel/package_tools\")):",
			"\t\treturn _fail(\"package_tools_left_after_uninstall\", \"Maintenance-side Python package tools exist after standard uninstall.\")",
			"\treturn {",
			"\t\t\"ok\": true,",
			"\t\t\"package_count\": packages.size(),",
			"\t\t\"installed_file_count\": int(install_result.get(\"installed_file_count\", 0)),",
			"\t\t\"removed_file_count\": int(uninstall_result.get(\"removed_file_count\", 0)),",
			"\t\t\"selected_package_id\": selected_package_id,",
			"\t}",
			"",
			"",
			"func _lockfile_installed() -> Dictionary:",
			"\tvar file: FileAccess = FileAccess.open(\"res://.gf/packages.lock.json\", FileAccess.READ)",
			"\tif file == null:",
			"\t\treturn {}",
			"\tvar text: String = file.get_as_text()",
			"\tvar parsed: Variant = JSON.parse_string(text)",
			"\tif not (parsed is Dictionary):",
			"\t\treturn {}",
			"\tvar data: Dictionary = parsed",
			"\tvar installed_value: Variant = data.get(\"installed\", {})",
			"\tif installed_value is Dictionary:",
			"\t\treturn installed_value",
			"\treturn {}",
			"",
			"",
			"func _has_package(packages: Array, package_id: String) -> bool:",
			"\tfor package_value: Variant in packages:",
			"\t\tif package_value is Dictionary:",
			"\t\t\tvar package_entry: Dictionary = package_value",
			"\t\t\tif str(package_entry.get(\"id\", \"\")) == package_id:",
			"\t\t\t\treturn true",
			"\treturn false",
			"",
			"",
			"func _fail(kind: String, message: String, extra: Dictionary = {}) -> Dictionary:",
			"\tvar result: Dictionary = {",
			"\t\t\"ok\": false,",
			"\t\t\"issues\": [message],",
			"\t\t\"kind\": kind,",
			"\t}",
			"\tfor key: Variant in extra.keys():",
			"\t\tresult[key] = extra[key]",
			"\treturn result",
			"",
		]) + "\n",
		encoding="utf-8",
	)
	return script_path


def write_package_editor_wizard_smoke_preset_script(project_root: Path, registry_url: str) -> Path:
	script_path = project_root / ".gf/package_editor_wizard_minimal_preset_smoke.gd"
	script_path.parent.mkdir(parents=True, exist_ok=True)
	script_path.write_text(
		"\n".join([
			"extends SceneTree",
			"",
			"const DOCK_SCRIPT_PATH: String = \"res://addons/gf/kernel/editor/package/gf_package_manager_dock.gd\"",
			"const PACKAGE_ID: String = \"gf.preset.rpg_save_dialogue\"",
			f"const REGISTRY_URL: String = {json.dumps(registry_url)}",
			"",
			"func _init() -> void:",
			"\tvar result: Dictionary = _run_smoke()",
			"\tprint(JSON.stringify(result))",
			"\tquit(0 if bool(result.get(\"ok\", false)) else 1)",
			"",
			"",
			"func _run_smoke() -> Dictionary:",
			"\tvar dock_script_resource: Resource = load(DOCK_SCRIPT_PATH)",
			"\tif not (dock_script_resource is Script):",
			"\t\treturn _fail(\"dock_script_missing\", \"Package manager Dock script could not be loaded.\")",
			"\tvar dock_script: Script = dock_script_resource",
			"\tvar dock_value: Variant = dock_script.new()",
			"\tif not (dock_value is VBoxContainer):",
			"\t\treturn _fail(\"dock_instance_invalid\", \"Package manager Dock did not instantiate as VBoxContainer.\")",
			"\tvar dock: VBoxContainer = dock_value",
			"\tget_root().add_child(dock)",
			"\tvar registry_field_value: Variant = dock.get(\"_registry_field\")",
			"\tif not (registry_field_value is LineEdit):",
			"\t\treturn _fail(\"registry_field_missing\", \"Package manager Dock registry field is unavailable.\")",
			"\tvar registry_field: LineEdit = registry_field_value",
			"\tregistry_field.text = REGISTRY_URL",
			"\tvar refresh_result: Variant = dock.call(\"_refresh_status\")",
			"\tvar _unused_refresh: Variant = refresh_result",
			"\tvar packages_value: Variant = dock.get(\"_packages\")",
			"\tif not (packages_value is Array):",
			"\t\treturn _fail(\"packages_missing\", \"Package manager Dock did not load package entries.\")",
			"\tvar packages: Array = packages_value",
			"\tif not _has_package(packages, PACKAGE_ID):",
			"\t\treturn _fail(\"preset_package_missing\", \"HTTP registry did not expose the RPG preset in the Dock.\", {\"package_count\": packages.size()})",
			"\tvar select_result: Variant = dock.call(\"_select_package\", PACKAGE_ID)",
			"\tvar _unused_select: Variant = select_result",
			"\tvar selected_package_id: String = str(dock.get(\"_selected_package_id\"))",
			"\tif selected_package_id != PACKAGE_ID:",
			"\t\treturn _fail(\"preset_package_not_selected\", \"Package manager Dock did not select the RPG preset.\", {\"selected_package_id\": selected_package_id})",
			"\tvar details_value: Variant = dock.get(\"_details_output\")",
			"\tif details_value is TextEdit:",
			"\t\tvar details_output: TextEdit = details_value",
			"\t\tif not details_output.text.contains(\"install preview:\"):",
			"\t\t\treturn _fail(\"install_preview_missing\", \"Package manager Dock details did not expose the preset install preview.\")",
			"\tvar install_value: Variant = dock.call(\"_run_native_operation\", \"install\", false)",
			"\tif not (install_value is Dictionary):",
			"\t\treturn _fail(\"install_result_invalid\", \"Package manager Dock native preset install did not return a Dictionary.\")",
			"\tvar install_result: Dictionary = install_value",
			"\tif not bool(install_result.get(\"ok\", false)):",
			"\t\treturn _fail(\"install_failed\", \"Package manager Dock native preset install failed.\", {\"issues\": install_result.get(\"issues\", [])})",
			"\tvar installed_after_install: Dictionary = _lockfile_installed()",
			"\tfor package_id: String in [PACKAGE_ID, \"gf.extension.save\", \"gf.extension.dialogue\", \"gf.extension.domain\", \"gf.standard.base\", \"gf.standard.config\", \"gf.standard.storage\", \"gf.standard.deterministic\"]:",
			"\t\tif not installed_after_install.has(package_id):",
			"\t\t\treturn _fail(\"installed_package_missing\", \"Preset install did not record an expected package in the lockfile.\", {\"package_id\": package_id})",
			"\tvar preset_entry_value: Variant = installed_after_install.get(PACKAGE_ID, {})",
			"\tif preset_entry_value is Dictionary:",
			"\t\tvar preset_entry: Dictionary = preset_entry_value",
			"\t\tvar preset_files_value: Variant = preset_entry.get(\"files\", [])",
			"\t\tif preset_files_value is Array:",
			"\t\t\tvar preset_files: Array = preset_files_value",
			"\t\t\tif not preset_files.is_empty():",
			"\t\t\t\treturn _fail(\"preset_entry_has_files\", \"Preset lock entry should not own physical files.\")",
			"\tvar installed_archive: String = \"\"",
			"\tvar save_entry_value: Variant = installed_after_install.get(\"gf.extension.save\", {})",
			"\tif save_entry_value is Dictionary:",
			"\t\tvar save_entry: Dictionary = save_entry_value",
			"\t\tinstalled_archive = str(save_entry.get(\"archive\", \"\"))",
			"\tfor relative_path: String in [",
			"\t\t\"res://addons/gf/extensions/save/gf_extension.json\",",
			"\t\t\"res://addons/gf/extensions/dialogue/gf_extension.json\",",
			"\t\t\"res://addons/gf/extensions/domain/gf_extension.json\",",
			"\t\t\"res://addons/gf/standard/utilities/config/gf_config_provider.gd\",",
			"\t\t\"res://addons/gf/standard/utilities/storage/gf_storage_utility.gd\",",
			"\t\t\"res://addons/gf/standard/foundation/deterministic/gf_deterministic_variant_serializer.gd\",",
			"\t]:",
			"\t\tif not FileAccess.file_exists(relative_path):",
			"\t\t\treturn _fail(\"installed_file_missing\", \"Preset install did not materialize an expected package file.\", {\"path\": relative_path})",
			"\tif DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(\"res://addons/gf/kernel/package_tools\")):",
			"\t\treturn _fail(\"package_tools_added\", \"Maintenance-side Python package tools were installed into the user project.\")",
			"\tvar refresh_after_install: Variant = dock.call(\"_refresh_status\")",
			"\tvar _unused_refresh_after_install: Variant = refresh_after_install",
			"\tvar select_installed_result: Variant = dock.call(\"_select_package\", PACKAGE_ID)",
			"\tvar _unused_select_installed: Variant = select_installed_result",
			"\tif details_value is TextEdit:",
			"\t\tvar uninstall_details_output: TextEdit = details_value",
			"\t\tif not uninstall_details_output.text.contains(\"uninstall preview:\"):",
			"\t\t\treturn _fail(\"uninstall_preview_missing\", \"Package manager Dock details did not expose the preset uninstall preview after install.\")",
			"\tvar uninstall_value: Variant = dock.call(\"_run_native_operation\", \"uninstall\", false)",
			"\tif not (uninstall_value is Dictionary):",
			"\t\treturn _fail(\"uninstall_result_invalid\", \"Package manager Dock native preset uninstall did not return a Dictionary.\")",
			"\tvar uninstall_result: Dictionary = uninstall_value",
			"\tif not bool(uninstall_result.get(\"ok\", false)):",
			"\t\treturn _fail(\"uninstall_failed\", \"Package manager Dock native preset uninstall failed.\", {\"issues\": uninstall_result.get(\"issues\", [])})",
			"\tvar installed_after_uninstall: Dictionary = _lockfile_installed()",
			"\tif installed_after_uninstall.keys().size() != 1 or not installed_after_uninstall.has(\"gf.kernel\"):",
			"\t\treturn _fail(\"uninstall_lockfile_invalid\", \"Preset uninstall should prune the project back to kernel-only.\", {\"installed\": installed_after_uninstall.keys()})",
			"\tfor relative_path: String in [",
			"\t\t\"res://addons/gf/extensions/save/gf_extension.json\",",
			"\t\t\"res://addons/gf/extensions/dialogue/gf_extension.json\",",
			"\t\t\"res://addons/gf/extensions/domain/gf_extension.json\",",
			"\t\t\"res://addons/gf/standard/utilities/config/gf_config_provider.gd\",",
			"\t\t\"res://addons/gf/standard/utilities/storage/gf_storage_utility.gd\",",
			"\t\t\"res://addons/gf/standard/foundation/deterministic/gf_deterministic_variant_serializer.gd\",",
			"\t]:",
			"\t\tif FileAccess.file_exists(relative_path):",
			"\t\t\treturn _fail(\"package_file_left_after_uninstall\", \"Preset uninstall left an expected package file behind.\", {\"path\": relative_path})",
			"\tif not FileAccess.file_exists(\"res://addons/gf/plugin.gd\"):",
			"\t\treturn _fail(\"kernel_removed_after_uninstall\", \"Kernel plugin entry was removed after preset uninstall.\")",
			"\tif DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(\"res://addons/gf/kernel/package_tools\")):",
			"\t\treturn _fail(\"package_tools_left_after_uninstall\", \"Maintenance-side Python package tools exist after preset uninstall.\")",
			"\treturn {",
			"\t\t\"ok\": true,",
			"\t\t\"package_count\": packages.size(),",
			"\t\t\"installed_file_count\": int(install_result.get(\"installed_file_count\", 0)),",
			"\t\t\"removed_file_count\": int(uninstall_result.get(\"removed_file_count\", 0)),",
			"\t\t\"selected_package_id\": selected_package_id,",
			"\t\t\"installed_archive\": installed_archive,",
			"\t}",
			"",
			"",
			"func _lockfile_installed() -> Dictionary:",
			"\tvar file: FileAccess = FileAccess.open(\"res://.gf/packages.lock.json\", FileAccess.READ)",
			"\tif file == null:",
			"\t\treturn {}",
			"\tvar text: String = file.get_as_text()",
			"\tvar parsed: Variant = JSON.parse_string(text)",
			"\tif not (parsed is Dictionary):",
			"\t\treturn {}",
			"\tvar data: Dictionary = parsed",
			"\tvar installed_value: Variant = data.get(\"installed\", {})",
			"\tif installed_value is Dictionary:",
			"\t\treturn installed_value",
			"\treturn {}",
			"",
			"",
			"func _has_package(packages: Array, package_id: String) -> bool:",
			"\tfor package_value: Variant in packages:",
			"\t\tif package_value is Dictionary:",
			"\t\t\tvar package_entry: Dictionary = package_value",
			"\t\t\tif str(package_entry.get(\"id\", \"\")) == package_id:",
			"\t\t\t\treturn true",
			"\treturn false",
			"",
			"",
			"func _fail(kind: String, message: String, extra: Dictionary = {}) -> Dictionary:",
			"\tvar result: Dictionary = {",
			"\t\t\"ok\": false,",
			"\t\t\"issues\": [message],",
			"\t\t\"kind\": kind,",
			"\t}",
			"\tfor key: Variant in extra.keys():",
			"\t\tresult[key] = extra[key]",
			"\treturn result",
			"",
		]) + "\n",
		encoding="utf-8",
	)
	return script_path


def write_package_editor_wizard_smoke_status_rejection_script(
	project_root: Path,
	registry_url: str,
	expected_issue_needle: str,
	forbidden_package_id: str,
) -> Path:
	script_path = project_root / ".gf/package_editor_wizard_status_rejection_smoke.gd"
	script_path.parent.mkdir(parents=True, exist_ok=True)
	script_path.write_text(
		"\n".join([
			"extends SceneTree",
			"",
			"const DOCK_SCRIPT_PATH: String = \"res://addons/gf/kernel/editor/package/gf_package_manager_dock.gd\"",
			f"const REGISTRY_URL: String = {json.dumps(registry_url)}",
			f"const EXPECTED_ISSUE_NEEDLE: String = {json.dumps(expected_issue_needle)}",
			f"const FORBIDDEN_PACKAGE_ID: String = {json.dumps(forbidden_package_id)}",
			"",
			"func _init() -> void:",
			"\tvar result: Dictionary = _run_smoke()",
			"\tprint(JSON.stringify(result))",
			"\tquit(0 if bool(result.get(\"ok\", false)) else 1)",
			"",
			"",
			"func _run_smoke() -> Dictionary:",
			"\tvar dock_script_resource: Resource = load(DOCK_SCRIPT_PATH)",
			"\tif not (dock_script_resource is Script):",
			"\t\treturn _fail(\"dock_script_missing\", \"Package manager Dock script could not be loaded.\")",
			"\tvar dock_script: Script = dock_script_resource",
			"\tvar dock_value: Variant = dock_script.new()",
			"\tif not (dock_value is VBoxContainer):",
			"\t\treturn _fail(\"dock_instance_invalid\", \"Package manager Dock did not instantiate as VBoxContainer.\")",
			"\tvar dock: VBoxContainer = dock_value",
			"\tget_root().add_child(dock)",
			"\tvar registry_field_value: Variant = dock.get(\"_registry_field\")",
			"\tif not (registry_field_value is LineEdit):",
			"\t\treturn _fail(\"registry_field_missing\", \"Package manager Dock registry field is unavailable.\")",
			"\tvar registry_field: LineEdit = registry_field_value",
			"\tregistry_field.text = REGISTRY_URL",
			"\tvar refresh_result: Variant = dock.call(\"_refresh_status\")",
			"\tvar _unused_refresh: Variant = refresh_result",
			"\tvar last_status_value: Variant = dock.get(\"_last_status\")",
			"\tif not (last_status_value is Dictionary):",
			"\t\treturn _fail(\"last_status_missing\", \"Package manager Dock did not retain backend status data.\")",
			"\tvar last_status: Dictionary = last_status_value",
			"\tif bool(last_status.get(\"ok\", true)):",
			"\t\treturn _fail(\"status_unexpectedly_ok\", \"Package manager Dock accepted unsupported signature metadata.\", {\"status\": last_status})",
			"\tvar status_issues: Array = _as_array(last_status.get(\"issues\", []))",
			"\tvar issue_text: String = _join_array_text(status_issues)",
			"\tif not issue_text.contains(EXPECTED_ISSUE_NEEDLE):",
			"\t\treturn _fail(\"expected_issue_missing\", \"Package manager Dock did not expose the expected signature rejection issue.\", {\"issues\": status_issues})",
			"\tvar packages_value: Variant = dock.get(\"_packages\")",
			"\tif not (packages_value is Array):",
			"\t\treturn _fail(\"packages_missing\", \"Package manager Dock package rows are unavailable after rejection.\")",
			"\tvar dock_packages: Array = packages_value",
			"\tif not dock_packages.is_empty():",
			"\t\treturn _fail(\"dock_packages_not_empty\", \"Package manager Dock should clear visible packages after status rejection.\", {\"dock_package_count\": dock_packages.size()})",
			"\tif not FORBIDDEN_PACKAGE_ID.is_empty() and _status_has_package(last_status, FORBIDDEN_PACKAGE_ID):",
			"\t\treturn _fail(\"forbidden_package_listed\", \"Rejected signature package should not remain in backend status packages.\", {\"package_id\": FORBIDDEN_PACKAGE_ID})",
			"\tvar details_value: Variant = dock.get(\"_details_output\")",
			"\tif not (details_value is TextEdit):",
			"\t\treturn _fail(\"details_output_missing\", \"Package manager Dock details output is unavailable.\")",
			"\tvar details_output: TextEdit = details_value",
			"\tif not details_output.text.contains(EXPECTED_ISSUE_NEEDLE):",
			"\t\treturn _fail(\"details_issue_missing\", \"Package manager Dock details should show the signature rejection issue.\", {\"details\": details_output.text})",
			"\tvar status_label_value: Variant = dock.get(\"_status_label\")",
			"\tif status_label_value is Label:",
			"\t\tvar status_label: Label = status_label_value",
			"\t\tif not status_label.text.contains(\"失败\"):",
			"\t\t\treturn _fail(\"status_label_not_failed\", \"Package manager Dock status label should show a failed status refresh.\", {\"label\": status_label.text})",
			"\tif FileAccess.file_exists(\"res://.gf/packages.lock.json\"):",
			"\t\treturn _fail(\"lockfile_written\", \"Package manager Dock status rejection should not write a lockfile.\")",
			"\tfor relative_path: String in [",
			"\t\t\"res://addons/gf/extensions/save/gf_extension.json\",",
			"\t\t\"res://addons/gf/standard/utilities/storage/gf_storage_utility.gd\",",
			"\t]:",
			"\t\tif FileAccess.file_exists(relative_path):",
			"\t\t\treturn _fail(\"package_file_written\", \"Package manager Dock status rejection should not install package files.\", {\"path\": relative_path})",
			"\tif DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(\"res://addons/gf/kernel/package_tools\")):",
			"\t\treturn _fail(\"package_tools_added\", \"Package manager Dock rejection should not add maintenance-side Python package tools.\")",
			"\tif not FileAccess.file_exists(\"res://addons/gf/plugin.gd\"):",
			"\t\treturn _fail(\"kernel_missing\", \"Package manager Dock rejection should keep the existing kernel plugin entry.\")",
			"\tvar status_packages: Array = _as_array(last_status.get(\"packages\", []))",
			"\treturn {",
			"\t\t\"ok\": true,",
			"\t\t\"status_issue_count\": status_issues.size(),",
			"\t\t\"status_package_count\": int(last_status.get(\"package_count\", status_packages.size())),",
			"\t\t\"dock_package_count\": dock_packages.size(),",
			"\t\t\"forbidden_package_id\": FORBIDDEN_PACKAGE_ID,",
			"\t}",
			"",
			"",
			"func _as_array(value: Variant) -> Array:",
			"\tif value is Array:",
			"\t\tvar array_value: Array = value",
			"\t\treturn array_value",
			"\treturn []",
			"",
			"",
			"func _join_array_text(values: Array) -> String:",
			"\tvar parts: PackedStringArray = PackedStringArray()",
			"\tfor item: Variant in values:",
			"\t\tvar _append_result: bool = parts.append(str(item))",
			"\treturn \"\\n\".join(parts)",
			"",
			"",
			"func _status_has_package(status_data: Dictionary, package_id: String) -> bool:",
			"\tvar packages: Array = _as_array(status_data.get(\"packages\", []))",
			"\tfor package_value: Variant in packages:",
			"\t\tif package_value is Dictionary:",
			"\t\t\tvar package_entry: Dictionary = package_value",
			"\t\t\tif str(package_entry.get(\"id\", \"\")) == package_id:",
			"\t\t\t\treturn true",
			"\treturn false",
			"",
			"",
			"func _fail(kind: String, message: String, extra: Dictionary = {}) -> Dictionary:",
			"\tvar result: Dictionary = {",
			"\t\t\"ok\": false,",
			"\t\t\"issues\": [message],",
			"\t\t\"kind\": kind,",
			"\t}",
			"\tfor key: Variant in extra.keys():",
			"\t\tresult[key] = extra[key]",
			"\treturn result",
			"",
		]) + "\n",
		encoding="utf-8",
	)
	return script_path


def run_package_editor_wizard_smoke_script(
	project_root: Path,
	script_path: Path,
	scenario: str,
	issues: list[dict[str, Any]],
) -> dict[str, Any]:
	log_path = GODOT_LOG_DIR / f"package_editor_wizard_smoke_{scenario}.log"
	script_resource_path = "res://%s" % script_path.relative_to(project_root).as_posix()
	command = [
		"godot",
		"--headless",
		"--log-file",
		log_path.as_posix(),
		"--path",
		str(project_root),
		"--script",
		script_resource_path,
	]
	try:
		completed = subprocess.run(
			command,
			cwd=ROOT,
			capture_output=True,
			text=True,
			encoding="utf-8",
			errors="replace",
			timeout=180,
		)
	except subprocess.TimeoutExpired as error:
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_minimal_script_timeout",
			script_path.as_posix(),
			"Minimal kernel editor wizard smoke script timed out.",
			row_key=scenario,
			error=trim_text(str(error), 300),
		))
		return {}
	log_text = read_text_file_if_exists(log_path)
	combined_output = f"{completed.stdout}\n{completed.stderr}\n{log_text}"
	if completed.returncode != 0:
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_minimal_script_failed",
			script_path.as_posix(),
			"Minimal kernel editor wizard smoke script returned a failing exit code.",
			row_key=scenario,
			actual_value=str(completed.returncode),
			error=trim_text(combined_output.strip(), 1200),
		))
	if has_godot_script_error(combined_output, ""):
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_minimal_script_error",
			script_path.as_posix(),
			"Minimal kernel editor wizard smoke script reported a script loading or parse error.",
			row_key=scenario,
			error=trim_text(combined_output.strip(), 1200),
		))
	if has_gdscript_reload_warning(combined_output, ""):
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_minimal_reload_warning",
			script_path.as_posix(),
			"Minimal kernel editor wizard smoke script reported a GDScript reload warning.",
			row_key=scenario,
			error=trim_text(combined_output.strip(), 1200),
		))
	data = parse_package_godot_cli_json(completed.stdout)
	if not data:
		issues.append(make_package_issue(
			"package_editor_wizard_smoke_minimal_invalid_json",
			script_path.as_posix(),
			"Minimal kernel editor wizard smoke script should print a JSON object.",
			row_key=scenario,
			error=trim_text(combined_output.strip(), 1200),
		))
	return data


def assert_package_editor_wizard_smoke_condition(
	condition: bool,
	issues: list[dict[str, Any]],
	scenario: str,
	kind: str,
	message: str,
	**extra: Any,
) -> None:
	if condition:
		return
	issues.append(make_package_issue(kind, "addons/gf/kernel/editor/package/gf_package_manager_dock.gd", message, row_key=scenario, **extra))


def record_package_editor_wizard_smoke_scenario(
	scenarios: list[dict[str, Any]],
	name: str,
	ok: bool,
	details: dict[str, Any] | None = None,
) -> None:
	scenario = {"name": name, "ok": ok}
	if details:
		scenario.update(details)
	scenarios.append(scenario)


def make_package_editor_wizard_smoke_payload(
	command: list[str],
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
	test_path: str,
	log_path: Path,
) -> dict[str, Any]:
	return {
		"ok": len(issues) == 0 and all(bool(scenario.get("ok")) for scenario in scenarios),
		"root": str(ROOT),
		"test_path": test_path,
		"log_path": log_path.as_posix(),
		"command": command,
		"scenario_count": len(scenarios),
		"issue_count": len(issues),
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"scenarios": scenarios,
		"issues": issues,
	}


def read_text_file_if_exists(path: Path) -> str:
	try:
		if path.exists():
			return path.read_text(encoding="utf-8", errors="replace")
	except OSError:
		return ""
	return ""


def package_godot_cli_smoke() -> dict[str, Any]:
	with tempfile.TemporaryDirectory(prefix="gf-package-godot-cli-smoke-", ignore_cleanup_errors=True) as temp_dir:
		temp_root = Path(temp_dir)
		server_root = temp_root / "server"
		output_dir = server_root / "packages"
		registry_path = server_root / "registry/index.json"
		registry_source_path = server_root / "registry/gf-registry-source.json"
		offline_bundle_path = temp_root / "offline_bundle/gf-package-offline-bundle.zip"
		project_root = temp_root / "local_cli_project"
		issues: list[dict[str, Any]] = []
		scenarios: list[dict[str, Any]] = []

		build_data = run_package_smoke_json_command(
			"build_registry",
			[
				sys.executable,
				"tools/build_gf_package.py",
				"--all",
				"--output-dir",
				str(output_dir),
				"--registry",
				str(registry_path),
				"--registry-source",
				str(registry_source_path),
				"--offline-bundle",
				str(offline_bundle_path),
				"--json",
			],
			issues,
		)
		record_package_godot_cli_smoke_scenario(
			scenarios,
			"build_registry",
			len(issues) == 0 and bool(build_data.get("ok")),
			{"package_count": build_data.get("package_count", 0)},
		)
		if issues or not build_data.get("ok"):
			if not build_data.get("ok") and not issues:
				issues.append(make_package_issue(
					"package_godot_cli_smoke_builder_failed",
					"tools/build_gf_package.py",
					"Package builder did not report ok=true.",
					row_key="build_registry",
				))
			return make_package_godot_cli_smoke_payload(scenarios, issues, registry_path)

		run_package_godot_cli_smoke_status(temp_root, registry_path, project_root, scenarios, issues)
		run_package_godot_cli_smoke_human_status(temp_root, registry_path, project_root, scenarios, issues)
		run_package_godot_cli_smoke_dry_run(temp_root, registry_path, scenarios, issues)
		run_package_godot_cli_smoke_install(registry_path, project_root, scenarios, issues)
		run_package_godot_cli_smoke_verify(registry_path, project_root, scenarios, issues)
		run_package_godot_cli_smoke_uninstall(registry_path, project_root, scenarios, issues)
		run_package_godot_cli_smoke_missing_file_list_rejection(temp_root, registry_path, scenarios, issues)
		run_package_godot_cli_smoke_minimal_kernel_local_install_verify_uninstall(temp_root, registry_path, scenarios, issues)
		run_package_godot_cli_smoke_minimal_kernel_local_preset_install_verify_uninstall(temp_root, registry_path, scenarios, issues)
		run_package_godot_cli_smoke_minimal_kernel_offline_bundle_preset_install_verify_uninstall(
			temp_root,
			offline_bundle_path,
			scenarios,
			issues,
		)
		run_package_godot_cli_smoke_minimal_kernel_offline_bundle_zip_preset_install_verify_uninstall(
			temp_root,
			offline_bundle_path,
			scenarios,
			issues,
		)
		server, thread, base_url = start_network_install_smoke_server(server_root, issues)
		if server is not None and thread is not None:
			try:
				registry_url = network_install_smoke_url(base_url, "registry/index.json")
				run_package_godot_cli_smoke_http_install(temp_root, registry_url, scenarios, issues)
				run_package_godot_cli_smoke_minimal_kernel_http_install_verify_uninstall(temp_root, base_url, registry_path, scenarios, issues)
				run_package_godot_cli_smoke_minimal_kernel_http_standard_install_verify_uninstall(temp_root, base_url, registry_path, scenarios, issues)
				run_package_godot_cli_smoke_minimal_kernel_http_preset_install_verify_uninstall(temp_root, base_url, registry_path, scenarios, issues)
				run_package_godot_cli_smoke_http_retry_install(temp_root, base_url, scenarios, issues)
				run_package_godot_cli_smoke_http_dry_run(temp_root, registry_url, scenarios, issues)
				run_package_godot_cli_smoke_http_source_mirror_install(temp_root, base_url, server_root, scenarios, issues)
				run_package_godot_cli_smoke_default_source_install(temp_root, base_url, server_root, scenarios, issues)
				run_package_godot_cli_smoke_source_signature_rejection(temp_root, base_url, server_root, scenarios, issues)
				run_package_godot_cli_smoke_package_signature_rejection(temp_root, base_url, registry_path, server_root, scenarios, issues)
				run_package_godot_cli_smoke_external_tool_payload_rejection(temp_root, base_url, registry_path, server_root, scenarios, issues)
				run_package_godot_cli_smoke_http_download_failure(temp_root, base_url, registry_path, server_root, scenarios, issues)
			finally:
				stop_network_install_smoke_server(server, thread)
		return make_package_godot_cli_smoke_payload(scenarios, issues, registry_path)


def run_package_godot_cli_smoke_status(
	temp_root: Path,
	registry_path: Path,
	project_root: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_status_empty_project"
	start_issue_count = len(issues)
	status_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"status",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	assert_package_godot_cli_smoke_condition(
		bool(status_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_status_failed",
		"Godot native package CLI status should succeed without Python on the user path.",
	)
	assert_package_godot_cli_smoke_condition(
		status_data.get("backend") == "godot_native",
		issues,
		scenario,
		"package_godot_cli_smoke_backend_mismatch",
		"Godot native package CLI status should report the godot_native backend.",
		actual_value=str(status_data.get("backend", "")),
	)
	assert_package_godot_cli_smoke_condition(
		int(status_data.get("package_count", 0)) > 0,
		issues,
		scenario,
		"package_godot_cli_smoke_missing_packages",
		"Godot native package CLI status should list registry packages.",
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"package_count": status_data.get("package_count", 0), "temp_root": temp_root.as_posix()},
	)


def run_package_godot_cli_smoke_human_status(
	temp_root: Path,
	registry_path: Path,
	project_root: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_human_status_output"
	start_issue_count = len(issues)
	status_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"status",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
		],
		issues,
		expect_json=False,
	)
	stdout = str(status_data.get("stdout", ""))
	assert_package_godot_cli_smoke_condition(
		int(status_data.get("exit_code", 1)) == 0,
		issues,
		scenario,
		"package_godot_cli_smoke_human_status_failed",
		"Godot native package CLI default status output should exit successfully.",
		actual_value=str(status_data.get("exit_code", "")),
	)
	for expected_text in ["GF Package CLI status: ok", "Packages:", "Registry:"]:
		assert_package_godot_cli_smoke_condition(
			expected_text in stdout,
			issues,
			scenario,
			"package_godot_cli_smoke_human_status_missing_text",
			"Godot native package CLI default status output should be human-readable.",
			expected_value=expected_text,
		)
	assert_package_godot_cli_smoke_condition(
		not bool(parse_package_godot_cli_json(stdout)),
		issues,
		scenario,
		"package_godot_cli_smoke_human_status_printed_json",
		"Godot native package CLI default status output should not print the JSON payload.",
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"temp_root": temp_root.as_posix()},
	)


def run_package_godot_cli_smoke_dry_run(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_install_dry_run_no_mutation"
	start_issue_count = len(issues)
	project_root = temp_root / "dry_run_project"
	install_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--dry-run",
			"--json",
		],
		issues,
	)
	assert_package_godot_cli_smoke_condition(
		bool(install_data.get("ok")) and bool(install_data.get("dry_run")),
		issues,
		scenario,
		"package_godot_cli_smoke_dry_run_failed",
		"Godot native package CLI dry-run install should validate archives without writing project files.",
	)
	assert_package_godot_cli_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"package_godot_cli_smoke_dry_run_mutated_project",
		"Godot native package CLI dry-run install must not mutate the target project.",
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"dry_run": install_data.get("dry_run", False)},
	)


def run_package_godot_cli_smoke_install(
	registry_path: Path,
	project_root: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_install_save"
	start_issue_count = len(issues)
	install_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	assert_package_godot_cli_smoke_condition(
		bool(install_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_install_failed",
		"Godot native package CLI should install gf.extension.save and its dependencies.",
	)
	for relative_path in [
		"addons/gf/plugin.gd",
		"addons/gf/standard/utilities/storage/gf_storage_utility.gd",
		"addons/gf/extensions/save/gf_extension.json",
	]:
		assert_package_godot_cli_smoke_condition(
			(project_root / relative_path).is_file(),
			issues,
			scenario,
			"package_godot_cli_smoke_missing_installed_file",
			f"Godot native package CLI install should write {relative_path}.",
			expected_value=relative_path,
		)
	lockfile_data = read_json_object(project_root / ".gf/packages.lock.json")
	installed = lockfile_data.get("installed", {}) if isinstance(lockfile_data.get("installed", {}), dict) else {}
	for package_id in ["gf.kernel", "gf.standard.storage", "gf.extension.save"]:
		assert_package_godot_cli_smoke_condition(
			package_id in installed,
			issues,
			scenario,
			"package_godot_cli_smoke_missing_lockfile_package",
			f"Godot native package CLI install should record {package_id} in the lockfile.",
			expected_value=package_id,
		)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"installed_file_count": install_data.get("installed_file_count", 0)},
	)


def run_package_godot_cli_smoke_verify(
	registry_path: Path,
	project_root: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_verify_lockfile"
	start_issue_count = len(issues)
	verify_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"verify",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	assert_package_godot_cli_smoke_condition(
		bool(verify_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_verify_failed",
		"Godot native package CLI verify should accept the installer-written lockfile.",
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"issue_count": verify_data.get("issue_count", 0)},
	)


def run_package_godot_cli_smoke_uninstall(
	registry_path: Path,
	project_root: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_uninstall_save"
	start_issue_count = len(issues)
	uninstall_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"uninstall",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	assert_package_godot_cli_smoke_condition(
		bool(uninstall_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_uninstall_failed",
		"Godot native package CLI should uninstall gf.extension.save safely.",
	)
	assert_package_godot_cli_smoke_condition(
		not (project_root / "addons/gf/extensions/save/gf_extension.json").exists(),
		issues,
		scenario,
		"package_godot_cli_smoke_uninstall_left_extension",
		"Godot native package CLI uninstall should remove the extension package file.",
	)
	assert_package_godot_cli_smoke_condition(
		(project_root / "addons/gf/plugin.gd").is_file(),
		issues,
		scenario,
		"package_godot_cli_smoke_uninstall_removed_kernel",
		"Godot native package CLI uninstall should keep the bundled kernel package.",
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"removed_file_count": uninstall_data.get("removed_file_count", 0)},
	)


def run_package_godot_cli_smoke_missing_file_list_rejection(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_missing_file_list_rejection"
	start_issue_count = len(issues)
	project_root = temp_root / "missing_files_cli_project"
	run_package_godot_cli_smoke_command(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	extra_file = project_root / "addons/gf/extensions/save/project_extra_file.gd"
	extra_file.parent.mkdir(parents=True, exist_ok=True)
	extra_file.write_text("extends Node\n", encoding="utf-8")
	remove_uninstall_smoke_lockfile_files(
		project_root,
		[
			"gf.extension.save",
			"gf.standard.base",
			"gf.standard.deterministic",
			"gf.standard.storage",
		],
	)
	uninstall_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"uninstall",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	verify_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"verify",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	lockfile_data = read_json_object(project_root / ".gf/packages.lock.json")
	installed = lockfile_data.get("installed", {}) if isinstance(lockfile_data.get("installed", {}), dict) else {}
	uninstall_issues = uninstall_smoke_string_list(uninstall_data.get("issues", []))
	assert_package_godot_cli_smoke_condition(
		not bool(uninstall_data.get("ok"))
		and int(uninstall_data.get("planned_file_count", -1)) == 0
		and int(uninstall_data.get("removed_file_count", -1)) == 0
		and any("missing the installed files list" in issue for issue in uninstall_issues),
		issues,
		scenario,
		"package_godot_cli_smoke_missing_files_not_rejected",
		"Godot native package CLI should reject lockfile entries that lack exact files lists.",
		actual_value=json.dumps({
			"ok": uninstall_data.get("ok"),
			"planned_file_count": uninstall_data.get("planned_file_count"),
			"removed_file_count": uninstall_data.get("removed_file_count"),
			"issues": uninstall_issues,
		}, ensure_ascii=False, sort_keys=True),
	)
	assert_package_godot_cli_smoke_condition(
		not bool(verify_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_missing_files_verify_not_rejected",
		"Godot native package CLI verify should reject lockfiles that lack installed files lists.",
		actual_value=str(verify_data.get("issues", [])),
	)
	assert_package_godot_cli_smoke_condition(
		"gf.extension.save" in installed
		and "gf.standard.storage" in installed
		and "gf.standard.base" in installed
		and "gf.standard.deterministic" in installed
		and "gf.kernel" in installed
		and (project_root / "addons/gf/extensions/save/gf_extension.json").exists()
		and (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").exists()
		and extra_file.is_file(),
		issues,
		scenario,
		"package_godot_cli_smoke_missing_files_rejection_mutated_project",
		"Godot native package CLI strict rejection should not delete package or user-added files.",
		actual_value=",".join(sorted(installed.keys())),
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"planned_file_count": uninstall_data.get("planned_file_count", 0),
			"removed_file_count": uninstall_data.get("removed_file_count", 0),
			"verify_ok": verify_data.get("ok", False),
		},
	)


def run_package_godot_cli_smoke_http_install(
	temp_root: Path,
	registry_url: str,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_http_install_save"
	start_issue_count = len(issues)
	project_root = temp_root / "http_cli_project"
	cache_root = temp_root / "http_cli_cache"
	install_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			registry_url,
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
	)
	assert_package_godot_cli_smoke_condition(
		bool(install_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_http_install_failed",
		"Godot native package CLI should install gf.extension.save from an HTTP registry.",
	)
	for relative_path in [
		"addons/gf/plugin.gd",
		"addons/gf/standard/utilities/storage/gf_storage_utility.gd",
		"addons/gf/extensions/save/gf_extension.json",
	]:
		assert_package_godot_cli_smoke_condition(
			(project_root / relative_path).is_file(),
			issues,
			scenario,
			"package_godot_cli_smoke_http_missing_installed_file",
			f"Godot native package CLI HTTP install should write {relative_path}.",
			expected_value=relative_path,
		)
	lockfile_data = read_json_object(project_root / ".gf/packages.lock.json")
	installed = lockfile_data.get("installed", {}) if isinstance(lockfile_data.get("installed", {}), dict) else {}
	save_entry = installed.get("gf.extension.save", {}) if isinstance(installed.get("gf.extension.save", {}), dict) else {}
	assert_package_godot_cli_smoke_condition(
		str(save_entry.get("archive", "")).startswith("http://127.0.0.1:"),
		issues,
		scenario,
		"package_godot_cli_smoke_http_lockfile_archive_not_url",
		"Godot native package CLI HTTP install should persist the resolved archive URL in the lockfile.",
		actual_value=str(save_entry.get("archive", "")),
	)
	assert_package_godot_cli_smoke_condition(
		network_install_cache_has_file(cache_root, "registries", ".json")
		and network_install_cache_has_file(cache_root, "archives", ".zip"),
		issues,
		scenario,
		"package_godot_cli_smoke_http_cache_missing",
		"Godot native package CLI HTTP install should cache the registry and downloaded archives.",
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"installed_file_count": install_data.get("installed_file_count", 0),
			"cache_file_count": network_install_cache_file_count(cache_root),
		},
	)


def run_package_godot_cli_smoke_minimal_kernel_local_install_verify_uninstall(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_minimal_kernel_project_local_install_verify_uninstall"
	start_issue_count = len(issues)
	project_root = temp_root / "minimal_kernel_cli_local_project"
	write_package_godot_smoke_project(project_root, scenario)
	kernel_archive_path = resolve_package_godot_cli_smoke_local_archive(registry_path, "gf.kernel")
	if kernel_archive_path is None:
		assert_package_godot_cli_smoke_condition(
			False,
			issues,
			scenario,
			"package_godot_cli_smoke_minimal_kernel_local_archive_missing",
			"Smoke setup should find the locally built gf.kernel archive for local registry install.",
		)
		record_package_godot_cli_smoke_scenario(scenarios, scenario, False)
		return
	extract_package_godot_cli_smoke_archive(kernel_archive_path, project_root, scenario, issues)
	install_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	install_lockfile_data = read_json_object(project_root / ".gf/packages.lock.json")
	installed_after_install = (
		install_lockfile_data.get("installed", {})
		if isinstance(install_lockfile_data.get("installed", {}), dict)
		else {}
	)
	save_entry = (
		installed_after_install.get("gf.extension.save", {})
		if isinstance(installed_after_install.get("gf.extension.save", {}), dict)
		else {}
	)
	assert_package_godot_cli_smoke_condition(
		bool(install_data.get("ok")) and int(install_data.get("installed_file_count", 0)) > 0,
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_local_install_failed",
		"A project containing only gf.kernel should install gf.extension.save from a local registry through its own Godot-native CLI.",
		actual_value=str(install_data.get("issues", [])),
	)
	for package_id in ["gf.kernel", "gf.standard.base", "gf.standard.deterministic", "gf.standard.storage", "gf.extension.save"]:
		assert_package_godot_cli_smoke_condition(
			package_id in installed_after_install,
			issues,
			scenario,
			"package_godot_cli_smoke_minimal_kernel_local_missing_lockfile_package",
			"Minimal gf.kernel local install should record the selected extension closure in the lockfile.",
			expected_value=package_id,
		)
	assert_package_godot_cli_smoke_condition(
		str(save_entry.get("archive", ""))
		and not str(save_entry.get("archive", "")).startswith("http://")
		and not str(save_entry.get("archive", "")).startswith("https://"),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_local_archive_is_remote",
		"Local registry installs should not persist a remote archive URL in the lockfile.",
		actual_value=str(save_entry.get("archive", "")),
	)
	for relative_path in [
		"addons/gf/plugin.gd",
		"addons/gf/kernel/package/gf_package_cli.gd",
		"addons/gf/standard/utilities/storage/gf_storage_utility.gd",
		"addons/gf/extensions/save/gf_extension.json",
	]:
		assert_package_godot_cli_smoke_condition(
			(project_root / relative_path).is_file(),
			issues,
			scenario,
			"package_godot_cli_smoke_minimal_kernel_local_missing_installed_file",
			"Minimal gf.kernel local registry install should materialize the selected package closure.",
			expected_value=relative_path,
		)
	assert_package_godot_cli_smoke_condition(
		not (project_root / "addons/gf/kernel/package_tools").exists(),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_local_added_package_tools",
		"Local registry install must not add maintenance-side Python package tools to a user project.",
	)
	update_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"update",
			"--all-installed",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	assert_package_godot_cli_smoke_condition(
		bool(update_data.get("ok")) and bool(update_data.get("all_installed")),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_local_update_failed",
		"Minimal gf.kernel project CLI should support update --all-installed after installing a package closure.",
		actual_value=str(update_data.get("issues", [])),
	)
	verify_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"verify",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	assert_package_godot_cli_smoke_condition(
		bool(verify_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_local_verify_failed",
		"Minimal gf.kernel project CLI should verify the lockfile after local registry install.",
		actual_value=str(verify_data.get("issues", [])),
	)
	uninstall_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"uninstall",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	post_uninstall_verify_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"verify",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	lockfile_data = read_json_object(project_root / ".gf/packages.lock.json")
	installed_after_uninstall = (
		lockfile_data.get("installed", {})
		if isinstance(lockfile_data.get("installed", {}), dict)
		else {}
	)
	assert_package_godot_cli_smoke_condition(
		bool(uninstall_data.get("ok")) and int(uninstall_data.get("removed_file_count", 0)) > 0,
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_local_uninstall_failed",
		"Minimal gf.kernel project CLI should uninstall gf.extension.save from a local registry and prune unused dependencies.",
		actual_value=str(uninstall_data.get("issues", [])),
	)
	assert_package_godot_cli_smoke_condition(
		bool(post_uninstall_verify_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_local_post_uninstall_verify_failed",
		"Minimal gf.kernel project CLI should verify the lockfile after local registry uninstall.",
		actual_value=str(post_uninstall_verify_data.get("issues", [])),
	)
	assert_package_godot_cli_smoke_condition(
		sorted(installed_after_uninstall.keys()) == ["gf.kernel"]
		and (project_root / "addons/gf/plugin.gd").is_file()
		and (project_root / "addons/gf/kernel/package/gf_package_cli.gd").is_file()
		and not (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").exists()
		and not (project_root / "addons/gf/extensions/save/gf_extension.json").exists()
		and not (project_root / "addons/gf/kernel/package_tools").exists(),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_local_uninstall_state_invalid",
		"Minimal gf.kernel project CLI local uninstall should keep only kernel and prune the selected extension closure.",
		actual_value=str(sorted(installed_after_uninstall.keys())),
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"installed_file_count": install_data.get("installed_file_count", 0),
			"updated_file_count": update_data.get("updated_file_count", 0),
			"removed_file_count": uninstall_data.get("removed_file_count", 0),
			"post_uninstall_issue_count": post_uninstall_verify_data.get("issue_count", 0),
		},
	)


def run_package_godot_cli_smoke_minimal_kernel_local_preset_install_verify_uninstall(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
	scenario: str = "godot_cli_minimal_kernel_project_local_preset_install_verify_uninstall",
	project_dir_name: str = "minimal_kernel_cli_local_preset_project",
	cli_registry_value: str = "",
) -> None:
	start_issue_count = len(issues)
	project_root = temp_root / project_dir_name
	operation_registry_value = cli_registry_value if cli_registry_value else str(registry_path)
	write_package_godot_smoke_project(project_root, scenario)
	kernel_archive_path = resolve_package_godot_cli_smoke_local_archive(registry_path, "gf.kernel")
	if kernel_archive_path is None:
		assert_package_godot_cli_smoke_condition(
			False,
			issues,
			scenario,
			"package_godot_cli_smoke_minimal_kernel_local_preset_archive_missing",
			"Smoke setup should find the locally built gf.kernel archive for local registry preset install.",
		)
		record_package_godot_cli_smoke_scenario(scenarios, scenario, False)
		return
	extract_package_godot_cli_smoke_archive(kernel_archive_path, project_root, scenario, issues)
	install_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"install",
			"gf.preset.rpg_save_dialogue",
			"--registry",
			operation_registry_value,
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	install_lockfile_data = read_json_object(project_root / ".gf/packages.lock.json")
	installed_after_install = (
		install_lockfile_data.get("installed", {})
		if isinstance(install_lockfile_data.get("installed", {}), dict)
		else {}
	)
	preset_entry = (
		installed_after_install.get("gf.preset.rpg_save_dialogue", {})
		if isinstance(installed_after_install.get("gf.preset.rpg_save_dialogue", {}), dict)
		else {}
	)
	save_entry = (
		installed_after_install.get("gf.extension.save", {})
		if isinstance(installed_after_install.get("gf.extension.save", {}), dict)
		else {}
	)
	assert_package_godot_cli_smoke_condition(
		bool(install_data.get("ok")) and int(install_data.get("installed_file_count", 0)) > 0,
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_local_preset_install_failed",
		"A project containing only gf.kernel should install gf.preset.rpg_save_dialogue from a local registry through its own Godot-native CLI.",
		actual_value=str(install_data.get("issues", [])),
	)
	for package_id in [
		"gf.kernel",
		"gf.preset.rpg_save_dialogue",
		"gf.extension.save",
		"gf.extension.dialogue",
		"gf.extension.domain",
		"gf.standard.base",
		"gf.standard.config",
		"gf.standard.storage",
		"gf.standard.deterministic",
	]:
		assert_package_godot_cli_smoke_condition(
			package_id in installed_after_install,
			issues,
			scenario,
			"package_godot_cli_smoke_minimal_kernel_local_preset_missing_lockfile_package",
			"Minimal gf.kernel local preset install should record the preset, concrete packages, and dependencies in the lockfile.",
			expected_value=package_id,
		)
	assert_package_godot_cli_smoke_condition(
		not uninstall_smoke_string_list(preset_entry.get("files", [])),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_local_preset_has_files",
		"Preset lock entries should not own physical files.",
		actual_value=str(preset_entry.get("files", [])),
	)
	assert_package_godot_cli_smoke_condition(
		str(save_entry.get("archive", ""))
		and not str(save_entry.get("archive", "")).startswith("http://")
		and not str(save_entry.get("archive", "")).startswith("https://"),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_local_preset_archive_is_remote",
		"Local registry preset installs should persist local archive paths for concrete packages.",
		actual_value=str(save_entry.get("archive", "")),
	)
	for relative_path in [
		"addons/gf/extensions/save/gf_extension.json",
		"addons/gf/extensions/dialogue/gf_extension.json",
		"addons/gf/extensions/domain/gf_extension.json",
		"addons/gf/standard/utilities/config/gf_config_provider.gd",
		"addons/gf/standard/utilities/storage/gf_storage_utility.gd",
		"addons/gf/standard/foundation/deterministic/gf_deterministic_variant_serializer.gd",
	]:
		assert_package_godot_cli_smoke_condition(
			(project_root / relative_path).is_file(),
			issues,
			scenario,
			"package_godot_cli_smoke_minimal_kernel_local_preset_missing_installed_file",
			"Minimal gf.kernel local preset install should materialize the preset package closure.",
			expected_value=relative_path,
		)
	assert_package_godot_cli_smoke_condition(
		not (project_root / "addons/gf/kernel/package_tools").exists(),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_local_preset_added_package_tools",
		"Installing presets from a local registry must not add maintenance-side Python package tools to a user project.",
	)
	verify_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"verify",
			"--registry",
			operation_registry_value,
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	assert_package_godot_cli_smoke_condition(
		bool(verify_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_local_preset_verify_failed",
		"Minimal gf.kernel project CLI should verify the lockfile after local registry preset install.",
		actual_value=str(verify_data.get("issues", [])),
	)
	uninstall_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"uninstall",
			"gf.preset.rpg_save_dialogue",
			"--registry",
			operation_registry_value,
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	post_uninstall_verify_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"verify",
			"--registry",
			operation_registry_value,
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	lockfile_data = read_json_object(project_root / ".gf/packages.lock.json")
	installed_after_uninstall = (
		lockfile_data.get("installed", {})
		if isinstance(lockfile_data.get("installed", {}), dict)
		else {}
	)
	assert_package_godot_cli_smoke_condition(
		bool(uninstall_data.get("ok")) and int(uninstall_data.get("removed_file_count", 0)) > 0,
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_local_preset_uninstall_failed",
		"Minimal gf.kernel project CLI should uninstall gf.preset.rpg_save_dialogue from a local registry and prune unused concrete packages.",
		actual_value=str(uninstall_data.get("issues", [])),
	)
	assert_package_godot_cli_smoke_condition(
		bool(post_uninstall_verify_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_local_preset_post_uninstall_verify_failed",
		"Minimal gf.kernel project CLI should verify the lockfile after local registry preset uninstall.",
		actual_value=str(post_uninstall_verify_data.get("issues", [])),
	)
	assert_package_godot_cli_smoke_condition(
		sorted(installed_after_uninstall.keys()) == ["gf.kernel"]
		and (project_root / "addons/gf/plugin.gd").is_file()
		and (project_root / "addons/gf/kernel/package/gf_package_cli.gd").is_file()
		and not (project_root / "addons/gf/extensions/save/gf_extension.json").exists()
		and not (project_root / "addons/gf/extensions/dialogue/gf_extension.json").exists()
		and not (project_root / "addons/gf/extensions/domain/gf_extension.json").exists()
		and not (project_root / "addons/gf/standard/utilities/config/gf_config_provider.gd").exists()
		and not (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").exists()
		and not (project_root / "addons/gf/standard/foundation/deterministic/gf_deterministic_variant_serializer.gd").exists()
		and not (project_root / "addons/gf/kernel/package_tools").exists(),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_local_preset_uninstall_state_invalid",
		"Minimal gf.kernel project CLI local preset uninstall should keep only kernel and prune unneeded preset packages.",
		actual_value=str(sorted(installed_after_uninstall.keys())),
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"installed_file_count": install_data.get("installed_file_count", 0),
			"removed_file_count": uninstall_data.get("removed_file_count", 0),
			"post_uninstall_issue_count": post_uninstall_verify_data.get("issue_count", 0),
			"installed_archive": str(save_entry.get("archive", "")),
		},
	)


def run_package_godot_cli_smoke_minimal_kernel_offline_bundle_preset_install_verify_uninstall(
	temp_root: Path,
	offline_bundle_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_minimal_kernel_project_offline_bundle_preset_install_verify_uninstall"
	start_issue_count = len(issues)
	extract_root = temp_root / "offline_bundle_extracted"
	extract_package_godot_cli_smoke_offline_bundle(offline_bundle_path, extract_root, scenario, issues)
	extracted_registry_path = extract_root / "registry/index.json"
	assert_package_godot_cli_smoke_condition(
		extracted_registry_path.is_file(),
		issues,
		scenario,
		"package_godot_cli_smoke_offline_bundle_registry_missing",
		"Extracted offline bundle should contain registry/index.json for local Godot-native installs.",
		expected_value="registry/index.json",
	)
	if not extracted_registry_path.is_file():
		record_package_godot_cli_smoke_scenario(scenarios, scenario, False)
		return
	run_package_godot_cli_smoke_minimal_kernel_local_preset_install_verify_uninstall(
		temp_root,
		extracted_registry_path,
		scenarios,
		issues,
		scenario,
		"minimal_kernel_cli_offline_bundle_preset_project",
	)
	if len(scenarios) == 0:
		return
	scenario_record = scenarios[-1]
	if scenario_record.get("name") != scenario:
		return
	scenario_record["offline_bundle"] = offline_bundle_path.as_posix()
	scenario_record["extracted_registry"] = extracted_registry_path.as_posix()
	scenario_record["offline_bundle_entry_count"] = package_godot_cli_smoke_zip_file_count(offline_bundle_path)
	scenario_record["ok"] = bool(scenario_record.get("ok")) and len(issues) == start_issue_count


def run_package_godot_cli_smoke_minimal_kernel_offline_bundle_zip_preset_install_verify_uninstall(
	temp_root: Path,
	offline_bundle_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_minimal_kernel_project_offline_bundle_zip_preset_install_verify_uninstall"
	start_issue_count = len(issues)
	extract_root = temp_root / "offline_bundle_zip_setup_extracted"
	extract_package_godot_cli_smoke_offline_bundle(offline_bundle_path, extract_root, scenario, issues)
	extracted_registry_path = extract_root / "registry/index.json"
	assert_package_godot_cli_smoke_condition(
		extracted_registry_path.is_file(),
		issues,
		scenario,
		"package_godot_cli_smoke_offline_bundle_zip_setup_registry_missing",
		"Extracted offline bundle should contain registry/index.json for minimal-kernel CLI fixture setup.",
		expected_value="registry/index.json",
	)
	if not extracted_registry_path.is_file():
		record_package_godot_cli_smoke_scenario(scenarios, scenario, False)
		return
	run_package_godot_cli_smoke_minimal_kernel_local_preset_install_verify_uninstall(
		temp_root,
		extracted_registry_path,
		scenarios,
		issues,
		scenario,
		"minimal_kernel_cli_offline_bundle_zip_preset_project",
		offline_bundle_path.as_posix(),
	)
	if len(scenarios) == 0:
		return
	scenario_record = scenarios[-1]
	if scenario_record.get("name") != scenario:
		return
	scenario_record["offline_bundle"] = offline_bundle_path.as_posix()
	scenario_record["setup_registry"] = extracted_registry_path.as_posix()
	scenario_record["offline_bundle_entry_count"] = package_godot_cli_smoke_zip_file_count(offline_bundle_path)
	scenario_record["ok"] = bool(scenario_record.get("ok")) and len(issues) == start_issue_count


def run_package_godot_cli_smoke_minimal_kernel_http_install_verify_uninstall(
	temp_root: Path,
	base_url: str,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_minimal_kernel_project_http_install_verify_uninstall"
	start_issue_count = len(issues)
	project_root = temp_root / "minimal_kernel_cli_project"
	cache_root = temp_root / "minimal_kernel_cli_cache"
	registry_url = network_install_smoke_url(base_url, "registry/index.json")
	write_package_godot_smoke_project(project_root, scenario)
	kernel_archive_path = resolve_package_godot_cli_smoke_local_archive(registry_path, "gf.kernel")
	if kernel_archive_path is None:
		assert_package_godot_cli_smoke_condition(
			False,
			issues,
			scenario,
			"package_godot_cli_smoke_minimal_kernel_archive_missing",
			"Smoke setup should find the locally built gf.kernel archive.",
		)
		record_package_godot_cli_smoke_scenario(scenarios, scenario, False)
		return
	extract_package_godot_cli_smoke_archive(kernel_archive_path, project_root, scenario, issues)
	assert_package_godot_cli_smoke_condition(
		(project_root / "addons/gf/kernel/package/gf_package_cli.gd").is_file(),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_cli_missing",
		"The built gf.kernel archive should contain the Godot-native package CLI.",
	)
	assert_package_godot_cli_smoke_condition(
		not (project_root / "addons/gf/standard").exists()
		and not (project_root / "addons/gf/extensions/save").exists()
		and not (project_root / "addons/gf/kernel/package_tools").exists(),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_not_minimal",
		"The minimal gf.kernel fixture should not include standard packages, extensions, or Python package tools.",
	)
	install_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			registry_url,
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	assert_package_godot_cli_smoke_condition(
		bool(install_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_install_failed",
		"A project containing only gf.kernel should install gf.extension.save from HTTP through its own Godot-native CLI.",
		actual_value=str(install_data.get("issues", [])),
	)
	for relative_path in [
		"addons/gf/plugin.gd",
		"addons/gf/kernel/package/gf_package_cli.gd",
		"addons/gf/standard/utilities/storage/gf_storage_utility.gd",
		"addons/gf/extensions/save/gf_extension.json",
	]:
		assert_package_godot_cli_smoke_condition(
			(project_root / relative_path).is_file(),
			issues,
			scenario,
			"package_godot_cli_smoke_minimal_kernel_missing_installed_file",
			"Minimal gf.kernel project install should materialize the selected package closure.",
			expected_value=relative_path,
		)
	assert_package_godot_cli_smoke_condition(
		not (project_root / "addons/gf/kernel/package_tools").exists(),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_added_package_tools",
		"Installing extensions must not add maintenance-side Python package tools to a user project.",
	)
	verify_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"verify",
			"--registry",
			registry_url,
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	assert_package_godot_cli_smoke_condition(
		bool(verify_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_verify_failed",
		"Minimal gf.kernel project CLI should verify the lockfile after HTTP install.",
		actual_value=str(verify_data.get("issues", [])),
	)
	uninstall_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"uninstall",
			"gf.extension.save",
			"--registry",
			registry_url,
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	post_uninstall_verify_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"verify",
			"--registry",
			registry_url,
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	lockfile_data = read_json_object(project_root / ".gf/packages.lock.json")
	installed = lockfile_data.get("installed", {}) if isinstance(lockfile_data.get("installed", {}), dict) else {}
	assert_package_godot_cli_smoke_condition(
		bool(uninstall_data.get("ok")) and int(uninstall_data.get("removed_file_count", 0)) > 0,
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_uninstall_failed",
		"Minimal gf.kernel project CLI should uninstall gf.extension.save and prune unused standard dependencies.",
		actual_value=str(uninstall_data.get("issues", [])),
	)
	assert_package_godot_cli_smoke_condition(
		bool(post_uninstall_verify_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_post_uninstall_verify_failed",
		"Minimal gf.kernel project CLI should verify the lockfile after HTTP uninstall.",
		actual_value=str(post_uninstall_verify_data.get("issues", [])),
	)
	assert_package_godot_cli_smoke_condition(
		"gf.kernel" in installed
		and "gf.extension.save" not in installed
		and "gf.standard.storage" not in installed
		and "gf.standard.base" not in installed
		and "gf.standard.deterministic" not in installed
		and (project_root / "addons/gf/plugin.gd").is_file()
		and (project_root / "addons/gf/kernel/package/gf_package_cli.gd").is_file()
		and not (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").exists()
		and not (project_root / "addons/gf/extensions/save/gf_extension.json").exists()
		and not (project_root / "addons/gf/kernel/package_tools").exists(),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_uninstall_state_invalid",
		"Minimal gf.kernel project CLI uninstall should keep kernel, remove the selected extension closure, and avoid Python package tools.",
		actual_value=str(sorted(installed.keys())),
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"installed_file_count": install_data.get("installed_file_count", 0),
			"removed_file_count": uninstall_data.get("removed_file_count", 0),
			"post_uninstall_issue_count": post_uninstall_verify_data.get("issue_count", 0),
			"cache_file_count": network_install_cache_file_count(cache_root),
		},
	)


def run_package_godot_cli_smoke_minimal_kernel_http_standard_install_verify_uninstall(
	temp_root: Path,
	base_url: str,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_minimal_kernel_project_http_standard_install_verify_uninstall"
	start_issue_count = len(issues)
	project_root = temp_root / "minimal_kernel_cli_standard_project"
	cache_root = temp_root / "minimal_kernel_cli_standard_cache"
	registry_url = network_install_smoke_url(base_url, "registry/index.json")
	write_package_godot_smoke_project(project_root, scenario)
	kernel_archive_path = resolve_package_godot_cli_smoke_local_archive(registry_path, "gf.kernel")
	if kernel_archive_path is None:
		assert_package_godot_cli_smoke_condition(
			False,
			issues,
			scenario,
			"package_godot_cli_smoke_minimal_kernel_standard_archive_missing",
			"Smoke setup should find the locally built gf.kernel archive for standard package install.",
		)
		record_package_godot_cli_smoke_scenario(scenarios, scenario, False)
		return
	extract_package_godot_cli_smoke_archive(kernel_archive_path, project_root, scenario, issues)
	install_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"install",
			"gf.standard.storage",
			"--registry",
			registry_url,
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	install_lockfile_data = read_json_object(project_root / ".gf/packages.lock.json")
	installed_after_install = (
		install_lockfile_data.get("installed", {})
		if isinstance(install_lockfile_data.get("installed", {}), dict)
		else {}
	)
	assert_package_godot_cli_smoke_condition(
		bool(install_data.get("ok")) and int(install_data.get("installed_file_count", 0)) > 0,
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_standard_install_failed",
		"A project containing only gf.kernel should install gf.standard.storage from HTTP through its own Godot-native CLI.",
		actual_value=str(install_data.get("issues", [])),
	)
	for package_id in ["gf.kernel", "gf.standard.base", "gf.standard.storage"]:
		assert_package_godot_cli_smoke_condition(
			package_id in installed_after_install,
			issues,
			scenario,
			"package_godot_cli_smoke_minimal_kernel_standard_missing_lockfile_package",
			"Minimal gf.kernel standard install should record the selected standard package and its dependencies in the lockfile.",
			expected_value=package_id,
		)
	for unexpected_package_id in ["gf.extension.save", "gf.preset.save", "gf.preset.rpg_save_dialogue"]:
		assert_package_godot_cli_smoke_condition(
			unexpected_package_id not in installed_after_install,
			issues,
			scenario,
			"package_godot_cli_smoke_minimal_kernel_standard_extra_lockfile_package",
			"Direct standard package install should not install extension or preset packages.",
			expected_value=unexpected_package_id,
		)
	for relative_path in [
		"addons/gf/standard/utilities/logging/gf_log_utility.gd",
		"addons/gf/standard/utilities/storage/gf_storage_utility.gd",
	]:
		assert_package_godot_cli_smoke_condition(
			(project_root / relative_path).is_file(),
			issues,
			scenario,
			"package_godot_cli_smoke_minimal_kernel_standard_missing_installed_file",
			"Minimal gf.kernel standard install should materialize the selected standard package closure.",
			expected_value=relative_path,
		)
	assert_package_godot_cli_smoke_condition(
		not (project_root / "addons/gf/extensions/save/gf_extension.json").exists()
		and not (project_root / "addons/gf/kernel/package_tools").exists(),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_standard_unwanted_payload",
		"Direct standard install must not add extensions or maintenance-side Python package tools.",
	)
	verify_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"verify",
			"--registry",
			registry_url,
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	assert_package_godot_cli_smoke_condition(
		bool(verify_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_standard_verify_failed",
		"Minimal gf.kernel project CLI should verify the lockfile after HTTP standard install.",
		actual_value=str(verify_data.get("issues", [])),
	)
	uninstall_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"uninstall",
			"gf.standard.storage",
			"--registry",
			registry_url,
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	post_uninstall_verify_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"verify",
			"--registry",
			registry_url,
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	lockfile_data = read_json_object(project_root / ".gf/packages.lock.json")
	installed_after_uninstall = (
		lockfile_data.get("installed", {})
		if isinstance(lockfile_data.get("installed", {}), dict)
		else {}
	)
	assert_package_godot_cli_smoke_condition(
		bool(uninstall_data.get("ok")) and int(uninstall_data.get("removed_file_count", 0)) > 0,
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_standard_uninstall_failed",
		"Minimal gf.kernel project CLI should uninstall gf.standard.storage and prune unused standard dependencies.",
		actual_value=str(uninstall_data.get("issues", [])),
	)
	assert_package_godot_cli_smoke_condition(
		bool(post_uninstall_verify_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_standard_post_uninstall_verify_failed",
		"Minimal gf.kernel project CLI should verify the lockfile after HTTP standard uninstall.",
		actual_value=str(post_uninstall_verify_data.get("issues", [])),
	)
	assert_package_godot_cli_smoke_condition(
		sorted(installed_after_uninstall.keys()) == ["gf.kernel"]
		and (project_root / "addons/gf/plugin.gd").is_file()
		and (project_root / "addons/gf/kernel/package/gf_package_cli.gd").is_file()
		and not (project_root / "addons/gf/standard/utilities/logging/gf_log_utility.gd").exists()
		and not (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").exists()
		and not (project_root / "addons/gf/extensions/save/gf_extension.json").exists()
		and not (project_root / "addons/gf/kernel/package_tools").exists(),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_standard_uninstall_state_invalid",
		"Minimal gf.kernel project CLI standard uninstall should keep only kernel and prune unneeded standard dependencies.",
		actual_value=str(sorted(installed_after_uninstall.keys())),
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"installed_file_count": install_data.get("installed_file_count", 0),
			"removed_file_count": uninstall_data.get("removed_file_count", 0),
			"post_uninstall_issue_count": post_uninstall_verify_data.get("issue_count", 0),
			"cache_file_count": network_install_cache_file_count(cache_root),
		},
	)


def run_package_godot_cli_smoke_minimal_kernel_http_preset_install_verify_uninstall(
	temp_root: Path,
	base_url: str,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_minimal_kernel_project_http_preset_install_verify_uninstall"
	start_issue_count = len(issues)
	project_root = temp_root / "minimal_kernel_cli_preset_project"
	cache_root = temp_root / "minimal_kernel_cli_preset_cache"
	registry_url = network_install_smoke_url(base_url, "registry/index.json")
	write_package_godot_smoke_project(project_root, scenario)
	kernel_archive_path = resolve_package_godot_cli_smoke_local_archive(registry_path, "gf.kernel")
	if kernel_archive_path is None:
		assert_package_godot_cli_smoke_condition(
			False,
			issues,
			scenario,
			"package_godot_cli_smoke_minimal_kernel_preset_archive_missing",
			"Smoke setup should find the locally built gf.kernel archive for preset install.",
		)
		record_package_godot_cli_smoke_scenario(scenarios, scenario, False)
		return
	extract_package_godot_cli_smoke_archive(kernel_archive_path, project_root, scenario, issues)
	install_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"install",
			"gf.preset.rpg_save_dialogue",
			"--registry",
			registry_url,
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	install_lockfile_data = read_json_object(project_root / ".gf/packages.lock.json")
	installed_after_install = (
		install_lockfile_data.get("installed", {})
		if isinstance(install_lockfile_data.get("installed", {}), dict)
		else {}
	)
	preset_entry = (
		installed_after_install.get("gf.preset.rpg_save_dialogue", {})
		if isinstance(installed_after_install.get("gf.preset.rpg_save_dialogue", {}), dict)
		else {}
	)
	assert_package_godot_cli_smoke_condition(
		bool(install_data.get("ok")) and int(install_data.get("installed_file_count", 0)) > 0,
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_preset_install_failed",
		"A project containing only gf.kernel should install gf.preset.rpg_save_dialogue from HTTP through its own Godot-native CLI.",
		actual_value=str(install_data.get("issues", [])),
	)
	for package_id in [
		"gf.kernel",
		"gf.preset.rpg_save_dialogue",
		"gf.extension.save",
		"gf.extension.dialogue",
		"gf.extension.domain",
		"gf.standard.base",
		"gf.standard.config",
		"gf.standard.storage",
		"gf.standard.deterministic",
	]:
		assert_package_godot_cli_smoke_condition(
			package_id in installed_after_install,
			issues,
			scenario,
			"package_godot_cli_smoke_minimal_kernel_preset_missing_lockfile_package",
			"Minimal gf.kernel preset install should record the preset, concrete packages, and dependencies in the lockfile.",
			expected_value=package_id,
		)
	assert_package_godot_cli_smoke_condition(
		not uninstall_smoke_string_list(preset_entry.get("files", [])),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_preset_has_files",
		"Preset lock entries should not own physical files.",
		actual_value=str(preset_entry.get("files", [])),
	)
	for relative_path in [
		"addons/gf/extensions/save/gf_extension.json",
		"addons/gf/extensions/dialogue/gf_extension.json",
		"addons/gf/extensions/domain/gf_extension.json",
		"addons/gf/standard/utilities/config/gf_config_provider.gd",
		"addons/gf/standard/utilities/storage/gf_storage_utility.gd",
		"addons/gf/standard/foundation/deterministic/gf_deterministic_variant_serializer.gd",
	]:
		assert_package_godot_cli_smoke_condition(
			(project_root / relative_path).is_file(),
			issues,
			scenario,
			"package_godot_cli_smoke_minimal_kernel_preset_missing_installed_file",
			"Minimal gf.kernel preset install should materialize the preset package closure.",
			expected_value=relative_path,
		)
	assert_package_godot_cli_smoke_condition(
		not (project_root / "addons/gf/kernel/package_tools").exists(),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_preset_added_package_tools",
		"Installing presets must not add maintenance-side Python package tools to a user project.",
	)
	verify_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"verify",
			"--registry",
			registry_url,
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	assert_package_godot_cli_smoke_condition(
		bool(verify_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_preset_verify_failed",
		"Minimal gf.kernel project CLI should verify the lockfile after HTTP preset install.",
		actual_value=str(verify_data.get("issues", [])),
	)
	uninstall_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"uninstall",
			"gf.preset.rpg_save_dialogue",
			"--registry",
			registry_url,
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	post_uninstall_verify_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"verify",
			"--registry",
			registry_url,
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		godot_project_root=project_root,
	)
	lockfile_data = read_json_object(project_root / ".gf/packages.lock.json")
	installed_after_uninstall = (
		lockfile_data.get("installed", {})
		if isinstance(lockfile_data.get("installed", {}), dict)
		else {}
	)
	assert_package_godot_cli_smoke_condition(
		bool(uninstall_data.get("ok")) and int(uninstall_data.get("removed_file_count", 0)) > 0,
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_preset_uninstall_failed",
		"Minimal gf.kernel project CLI should uninstall gf.preset.rpg_save_dialogue and prune unused concrete packages.",
		actual_value=str(uninstall_data.get("issues", [])),
	)
	assert_package_godot_cli_smoke_condition(
		bool(post_uninstall_verify_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_preset_post_uninstall_verify_failed",
		"Minimal gf.kernel project CLI should verify the lockfile after HTTP preset uninstall.",
		actual_value=str(post_uninstall_verify_data.get("issues", [])),
	)
	assert_package_godot_cli_smoke_condition(
		sorted(installed_after_uninstall.keys()) == ["gf.kernel"]
		and (project_root / "addons/gf/plugin.gd").is_file()
		and (project_root / "addons/gf/kernel/package/gf_package_cli.gd").is_file()
		and not (project_root / "addons/gf/extensions/save/gf_extension.json").exists()
		and not (project_root / "addons/gf/extensions/dialogue/gf_extension.json").exists()
		and not (project_root / "addons/gf/extensions/domain/gf_extension.json").exists()
		and not (project_root / "addons/gf/standard/utilities/config/gf_config_provider.gd").exists()
		and not (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").exists()
		and not (project_root / "addons/gf/standard/foundation/deterministic/gf_deterministic_variant_serializer.gd").exists()
		and not (project_root / "addons/gf/kernel/package_tools").exists(),
		issues,
		scenario,
		"package_godot_cli_smoke_minimal_kernel_preset_uninstall_state_invalid",
		"Minimal gf.kernel project CLI preset uninstall should keep only kernel and prune unneeded preset packages.",
		actual_value=str(sorted(installed_after_uninstall.keys())),
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"installed_file_count": install_data.get("installed_file_count", 0),
			"removed_file_count": uninstall_data.get("removed_file_count", 0),
			"post_uninstall_issue_count": post_uninstall_verify_data.get("issue_count", 0),
			"cache_file_count": network_install_cache_file_count(cache_root),
		},
	)


def run_package_godot_cli_smoke_http_retry_install(
	temp_root: Path,
	base_url: str,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_http_retry_install"
	start_issue_count = len(issues)
	project_root = temp_root / "http_cli_retry_project"
	cache_root = temp_root / "http_cli_retry_cache"
	install_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			network_install_smoke_url(base_url, "flaky-once/registry/index.json"),
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
	)
	assert_package_godot_cli_smoke_condition(
		bool(install_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_http_retry_failed",
		"Godot native package CLI should retry transient HTTP registry and archive failures.",
	)
	assert_package_godot_cli_smoke_condition(
		(project_root / "addons/gf/extensions/save/gf_extension.json").is_file(),
		issues,
		scenario,
		"package_godot_cli_smoke_http_retry_missing_file",
		"Godot native package CLI retry install should write selected package files.",
	)
	assert_package_godot_cli_smoke_condition(
		network_install_cache_has_file(cache_root, "registries", ".json")
		and network_install_cache_has_file(cache_root, "archives", ".zip"),
		issues,
		scenario,
		"package_godot_cli_smoke_http_retry_cache_missing",
		"Godot native package CLI retry install should cache the registry and downloaded archives.",
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"installed_file_count": install_data.get("installed_file_count", 0),
			"cache_file_count": network_install_cache_file_count(cache_root),
		},
	)


def run_package_godot_cli_smoke_http_dry_run(
	temp_root: Path,
	registry_url: str,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_http_dry_run_no_mutation"
	start_issue_count = len(issues)
	project_root = temp_root / "http_cli_dry_run_project"
	cache_root = temp_root / "http_cli_dry_run_cache"
	install_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			registry_url,
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--dry-run",
			"--json",
		],
		issues,
	)
	assert_package_godot_cli_smoke_condition(
		bool(install_data.get("ok")) and bool(install_data.get("dry_run")),
		issues,
		scenario,
		"package_godot_cli_smoke_http_dry_run_failed",
		"Godot native package CLI HTTP dry-run should resolve and validate archives successfully.",
	)
	assert_package_godot_cli_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"package_godot_cli_smoke_http_dry_run_mutated_project",
		"Godot native package CLI HTTP dry-run must not write files to the target project.",
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"dry_run": install_data.get("dry_run", False),
			"cache_file_count": network_install_cache_file_count(cache_root),
		},
	)


def run_package_godot_cli_smoke_http_source_mirror_install(
	temp_root: Path,
	base_url: str,
	server_root: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_http_source_mirror_install"
	start_issue_count = len(issues)
	project_root = temp_root / "http_cli_source_mirror_project"
	cache_root = temp_root / "http_cli_source_mirror_cache"
	source_path = server_root / "sources/godot_cli.json"
	registry_path = server_root / "registry/index.json"
	write_json_object(source_path, {
		"schema_version": 1,
		"default_channel": "stable",
		"channels": {
			"stable": {
				"registry": "../missing/index.json",
				"registry_sha256": sha256_file(registry_path),
				"registry_size_bytes": registry_path.stat().st_size,
				"mirrors": ["../registry/index.json"],
			},
		},
	})
	install_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			network_install_smoke_url(base_url, "sources/godot_cli.json"),
			"--channel",
			"stable",
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
	)
	assert_package_godot_cli_smoke_condition(
		bool(install_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_http_source_mirror_failed",
		"Godot native package CLI should use a registry source mirror when the primary channel registry is unavailable.",
	)
	assert_package_godot_cli_smoke_condition(
		(project_root / "addons/gf/extensions/save/gf_extension.json").is_file(),
		issues,
		scenario,
		"package_godot_cli_smoke_http_source_mirror_missing_file",
		"Godot native package CLI registry source mirror install should write selected package files.",
	)
	assert_package_godot_cli_smoke_condition(
		network_install_cache_has_file(cache_root, "registries", ".json")
		and network_install_cache_has_file(cache_root, "archives", ".zip"),
		issues,
		scenario,
		"package_godot_cli_smoke_http_source_mirror_cache_missing",
		"Godot native package CLI registry source mirror install should cache registry source, registry, and archives.",
	)
	assert_package_godot_cli_smoke_condition(
		install_data.get("registry_channel") == "stable"
		and int(install_data.get("registry_mirror_index", -2)) == 0
		and str(install_data.get("registry_source_manifest", "")).startswith("http://127.0.0.1:")
		and is_sha256_hex(str(install_data.get("registry_source_sha256", "")))
		and int_value(install_data.get("registry_source_size_bytes", 0)) > 0,
		issues,
		scenario,
		"package_godot_cli_smoke_http_source_mirror_diagnostics_missing",
		"Godot native package CLI registry source mirror install should report channel, mirror index, source manifest, and registry integrity.",
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"installed_file_count": install_data.get("installed_file_count", 0),
			"cache_file_count": network_install_cache_file_count(cache_root),
			"registry_mirror_index": install_data.get("registry_mirror_index", None),
		},
	)


def run_package_godot_cli_smoke_default_source_install(
	temp_root: Path,
	base_url: str,
	server_root: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_default_source_install"
	start_issue_count = len(issues)
	project_root = temp_root / "default_source_cli_project"
	cache_root = temp_root / "default_source_cli_cache"
	source_path = server_root / "sources/default_godot_cli.json"
	registry_path = server_root / "registry/index.json"
	write_json_object(source_path, {
		"schema_version": 1,
		"default_channel": "stable",
		"channels": {
			"stable": {
				"registry": "../registry/index.json",
				"registry_sha256": sha256_file(registry_path),
				"registry_size_bytes": registry_path.stat().st_size,
				"mirrors": [],
			},
		},
	})
	install_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		env={
			"GF_PACKAGE_DEFAULT_REGISTRY_SOURCE": network_install_smoke_url(base_url, "redirect/sources/default_godot_cli.json"),
		},
	)
	assert_package_godot_cli_smoke_condition(
		bool(install_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_default_source_failed",
		"Godot native package CLI should install from the default registry source when --registry is omitted.",
	)
	assert_package_godot_cli_smoke_condition(
		(project_root / "addons/gf/extensions/save/gf_extension.json").is_file(),
		issues,
		scenario,
		"package_godot_cli_smoke_default_source_missing_file",
		"Godot native package CLI default source install should write selected package files.",
	)
	assert_package_godot_cli_smoke_condition(
		network_install_cache_has_file(cache_root, "registries", ".json")
		and network_install_cache_has_file(cache_root, "archives", ".zip"),
		issues,
		scenario,
		"package_godot_cli_smoke_default_source_cache_missing",
		"Godot native package CLI default source install should cache source, registry, and archives.",
	)
	assert_package_godot_cli_smoke_condition(
		install_data.get("registry_channel") == "stable"
		and int(install_data.get("registry_mirror_index", -2)) == -1
		and str(install_data.get("registry_source_manifest", "")).startswith(network_install_smoke_url(base_url, "redirect/"))
		and is_sha256_hex(str(install_data.get("registry_source_sha256", "")))
		and int_value(install_data.get("registry_source_size_bytes", 0)) > 0,
		issues,
		scenario,
		"package_godot_cli_smoke_default_source_diagnostics_missing",
		"Godot native package CLI default source install should report source manifest, selected channel, primary registry, and registry integrity.",
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"installed_file_count": install_data.get("installed_file_count", 0),
			"cache_file_count": network_install_cache_file_count(cache_root),
			"registry_mirror_index": install_data.get("registry_mirror_index", None),
		},
	)


def run_package_godot_cli_smoke_source_signature_rejection(
	temp_root: Path,
	base_url: str,
	server_root: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_source_signature_rejection"
	start_issue_count = len(issues)
	project_root = temp_root / "source_signature_cli_project"
	cache_root = temp_root / "source_signature_cli_cache"
	source_path = server_root / "sources/signature_godot_cli.json"
	registry_path = server_root / "registry/index.json"
	write_json_object(source_path, {
		"schema_version": 1,
		"default_channel": "stable",
		"channels": {
			"stable": {
				"registry": "../registry/index.json",
				"registry_sha256": sha256_file(registry_path),
				"registry_size_bytes": registry_path.stat().st_size,
				"registry_signature_url": "gf-registry-unreleased.json.sig",
				"mirrors": [],
			},
		},
	})
	status_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"status",
			"--registry",
			network_install_smoke_url(base_url, "sources/signature_godot_cli.json"),
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	assert_package_godot_cli_smoke_condition(
		not bool(status_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_source_signature_not_rejected",
		"Godot native package CLI must reject registry source signature fields until native verification exists.",
	)
	assert_package_godot_cli_smoke_condition(
		int_value(status_data.get("package_count", 0)) == 0,
		issues,
		scenario,
		"package_godot_cli_smoke_source_signature_listed_packages",
		"Godot native package CLI must not list packages after rejecting unsupported registry source signature fields.",
		actual_value=str(status_data.get("package_count", "")),
	)
	assert_package_godot_cli_smoke_condition(
		package_godot_cli_result_issues_contain(
			status_data,
			"signature field is not supported until native verification is implemented",
		),
		issues,
		scenario,
		"package_godot_cli_smoke_source_signature_issue_missing",
		"Godot native package CLI should explain unsupported registry source signature fields in issues.",
	)
	assert_package_godot_cli_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"package_godot_cli_smoke_source_signature_mutated_project",
		"Godot native package CLI registry source signature rejection must not write files to the target project.",
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"cache_file_count": network_install_cache_file_count(cache_root),
			"package_count": status_data.get("package_count", 0),
		},
	)


def run_package_godot_cli_smoke_package_signature_rejection(
	temp_root: Path,
	base_url: str,
	registry_path: Path,
	server_root: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_package_signature_rejection"
	start_issue_count = len(issues)
	project_root = temp_root / "package_signature_cli_project"
	cache_root = temp_root / "package_signature_cli_cache"
	signed_registry_path = server_root / "signed_package_godot_cli/index.json"
	registry_data = read_json_object(registry_path)
	packages = registry_data.get("packages", {})
	if isinstance(packages, dict):
		save_entry = packages.get("gf.extension.save", {})
		if isinstance(save_entry, dict):
			save_entry["signature_url"] = "gf-extension-save-unreleased.zip.sig"
			packages["gf.extension.save"] = save_entry
	write_json_object(signed_registry_path, registry_data)
	status_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"status",
			"--registry",
			network_install_smoke_url(base_url, "signed_package_godot_cli/index.json"),
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	status_issues = uninstall_smoke_string_list(status_data.get("issues", []))
	status_packages = package_manager_status_package_index(status_data)
	assert_package_godot_cli_smoke_condition(
		not bool(status_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_package_signature_not_rejected",
		"Godot native package CLI must reject registry package signature fields until native verification exists.",
		actual_value=str(status_issues),
	)
	assert_package_godot_cli_smoke_condition(
		"gf.extension.save" not in status_packages,
		issues,
		scenario,
		"package_godot_cli_smoke_package_signature_listed_package",
		"Godot native package CLI must not list a package entry after rejecting its unsupported signature fields.",
		actual_value=",".join(sorted(status_packages.keys())),
	)
	assert_package_godot_cli_smoke_condition(
		any("Registry package signature field is not supported until native verification is implemented" in issue for issue in status_issues),
		issues,
		scenario,
		"package_godot_cli_smoke_package_signature_issue_missing",
		"Godot native package CLI should explain unsupported registry package signature fields in issues.",
		actual_value=str(status_issues),
	)
	assert_package_godot_cli_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"package_godot_cli_smoke_package_signature_mutated_project",
		"Godot native package CLI registry package signature rejection must not write files to the target project.",
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"cache_file_count": network_install_cache_file_count(cache_root),
			"package_count": status_data.get("package_count", 0),
		},
	)


def run_package_godot_cli_smoke_external_tool_payload_rejection(
	temp_root: Path,
	base_url: str,
	registry_path: Path,
	server_root: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_external_tool_payload_rejection"
	start_issue_count = len(issues)
	project_root = temp_root / "external_tool_payload_cli_project"
	cache_root = temp_root / "external_tool_payload_cli_cache"
	bad_registry_path = server_root / "external_tool_godot_cli/index.json"
	bad_archive = server_root / "external_tool_godot_cli/gf-extension-save.zip"
	bad_archive.parent.mkdir(parents=True, exist_ok=True)
	with zipfile.ZipFile(bad_archive, "w", compression=zipfile.ZIP_DEFLATED) as archive:
		archive.writestr("addons/gf/extensions/save/install.py", "# fixture\n")
		archive.writestr("addons/gf/extensions/save/package.json", "{}\n")
	registry_data = read_json_object(registry_path)
	save_entry = registry_data["packages"]["gf.extension.save"]
	save_entry["archive"] = "gf-extension-save.zip"
	save_entry["sha256"] = sha256_file(bad_archive)
	save_entry["size_bytes"] = bad_archive.stat().st_size
	write_json_object(bad_registry_path, registry_data)
	install_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			network_install_smoke_url(base_url, "external_tool_godot_cli/index.json"),
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	install_issues = "\n".join(uninstall_smoke_string_list(install_data.get("issues", [])))
	assert_package_godot_cli_smoke_condition(
		not bool(install_data.get("ok")) and "external tool payload" in install_issues,
		issues,
		scenario,
		"package_godot_cli_smoke_external_tool_payload_not_rejected",
		"Godot native package CLI must reject remote runtime package archives that contain Python/npm tool payloads.",
		actual_value=install_issues,
	)
	assert_package_godot_cli_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"package_godot_cli_smoke_external_tool_payload_mutated_project",
		"Godot native package CLI remote external tool payload rejection must not write files to the target project.",
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"cache_file_count": network_install_cache_file_count(cache_root)},
	)


def run_package_godot_cli_smoke_http_download_failure(
	temp_root: Path,
	base_url: str,
	registry_path: Path,
	server_root: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "godot_cli_http_download_failure_no_mutation"
	start_issue_count = len(issues)
	project_root = temp_root / "http_cli_download_failure_project"
	cache_root = temp_root / "http_cli_download_failure_cache"
	bad_registry_path = server_root / "bad_download/index.json"
	registry_data = read_json_object(registry_path)
	registry_data["packages"]["gf.extension.save"]["archive"] = "../missing/gf-extension-save-unreleased.zip"
	write_json_object(bad_registry_path, registry_data)
	install_data = run_package_godot_cli_smoke_command(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			network_install_smoke_url(base_url, "bad_download/index.json"),
			"--project-root",
			str(project_root),
			"--cache-dir",
			str(cache_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	assert_package_godot_cli_smoke_condition(
		not bool(install_data.get("ok")),
		issues,
		scenario,
		"package_godot_cli_smoke_http_download_failure_not_rejected",
		"Godot native package CLI should reject a missing remote archive.",
	)
	assert_package_godot_cli_smoke_condition(
		not project_has_files(project_root),
		issues,
		scenario,
		"package_godot_cli_smoke_http_download_failure_mutated_project",
		"Godot native package CLI HTTP download failure must not write files to the target project.",
	)
	record_package_godot_cli_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"cache_file_count": network_install_cache_file_count(cache_root)},
	)


def run_package_godot_cli_smoke_command(
	scenario: str,
	args: list[str],
	issues: list[dict[str, Any]],
	allow_failure: bool = False,
	expect_json: bool = True,
	env: dict[str, str] | None = None,
	godot_project_root: Path | None = None,
) -> dict[str, Any]:
	GODOT_LOG_DIR.mkdir(parents=True, exist_ok=True)
	safe_scenario = re.sub(r"[^A-Za-z0-9_.-]+", "_", scenario)
	project_path = godot_project_root if godot_project_root is not None else Path(".")
	command = [
		"godot",
		"--headless",
		"--log-file",
		godot_log_path(f"package_godot_cli_smoke_{safe_scenario}"),
		"--path",
		str(project_path),
		"--script",
		"res://addons/gf/kernel/package/gf_package_cli.gd",
		"--",
		*args,
	]
	process_env = None
	if env is not None:
		process_env = os.environ.copy()
		process_env.update(env)
	try:
		completed = subprocess.run(
			command,
			cwd=ROOT,
			capture_output=True,
			text=True,
			encoding="utf-8",
			errors="replace",
			env=process_env,
			timeout=120,
		)
	except subprocess.TimeoutExpired as error:
		issues.append(make_package_issue(
			"package_godot_cli_smoke_timeout",
			"addons/gf/kernel/package/gf_package_cli.gd",
			"Godot native package CLI command timed out.",
			row_key=scenario,
			error=trim_text(str(error), 300),
		))
		return {}
	combined_output = f"{completed.stdout}\n{completed.stderr}"
	if completed.returncode != 0 and not allow_failure:
		issues.append(make_package_issue(
			"package_godot_cli_smoke_command_failed",
			"addons/gf/kernel/package/gf_package_cli.gd",
			"Godot native package CLI returned a failing exit code.",
			row_key=scenario,
			actual_value=str(completed.returncode),
			error=trim_text(combined_output.strip(), 1000),
		))
	if has_godot_script_error(completed.stdout, completed.stderr):
		issues.append(make_package_issue(
			"package_godot_cli_smoke_script_error",
			"addons/gf/kernel/package/gf_package_cli.gd",
			"Godot native package CLI reported a script loading or parse error.",
			row_key=scenario,
			error=trim_text(combined_output.strip(), 1000),
		))
	if has_gdscript_reload_warning(completed.stdout, completed.stderr):
		issues.append(make_package_issue(
			"package_godot_cli_smoke_reload_warning",
			"addons/gf/kernel/package/gf_package_cli.gd",
			"Godot native package CLI reported a GDScript reload warning.",
			row_key=scenario,
			error=trim_text(combined_output.strip(), 1000),
		))
	if not expect_json:
		return {
			"ok": completed.returncode == 0,
			"exit_code": completed.returncode,
			"stdout": completed.stdout,
			"stderr": completed.stderr,
		}
	data = parse_package_godot_cli_json(completed.stdout)
	if not data:
		issues.append(make_package_issue(
			"package_godot_cli_smoke_invalid_json",
			"addons/gf/kernel/package/gf_package_cli.gd",
			"Godot native package CLI must print a JSON object to stdout.",
			row_key=scenario,
			error=trim_text(combined_output.strip(), 1000),
		))
	return data


def resolve_package_godot_cli_smoke_local_archive(registry_path: Path, package_id: str) -> Path | None:
	registry_data = read_json_object(registry_path)
	packages = registry_data.get("packages", {})
	entry = packages.get(package_id, {}) if isinstance(packages, dict) else {}
	if not isinstance(entry, dict):
		return None
	archive_value = str(entry.get("archive", ""))
	if not archive_value or urllib.parse.urlparse(archive_value).scheme:
		return None
	archive_path = Path(archive_value)
	if not archive_path.is_absolute():
		archive_path = registry_path.parent / archive_path
	archive_path = archive_path.resolve()
	if not archive_path.is_file():
		return None
	return archive_path


def extract_package_godot_cli_smoke_archive(
	archive_path: Path,
	project_root: Path,
	scenario: str,
	issues: list[dict[str, Any]],
) -> None:
	try:
		with zipfile.ZipFile(archive_path, "r") as archive:
			for info in archive.infolist():
				normalized = info.filename.replace("\\", "/")
				if info.is_dir():
					continue
				if (
					normalized.startswith("/")
					or normalized.startswith("../")
					or "/../" in normalized
					or not normalized.startswith("addons/gf/")
				):
					issues.append(make_package_issue(
						"package_godot_cli_smoke_minimal_kernel_archive_unsafe_path",
						"tools/build_gf_package.py",
						"Smoke setup rejected an unsafe gf.kernel archive entry.",
						row_key=scenario,
						actual_value=normalized,
					))
					continue
				target_path = project_root / normalized
				target_path.parent.mkdir(parents=True, exist_ok=True)
				target_path.write_bytes(archive.read(info))
	except zipfile.BadZipFile as error:
		issues.append(make_package_issue(
			"package_godot_cli_smoke_minimal_kernel_archive_bad_zip",
			"tools/build_gf_package.py",
			"Smoke setup could not read the built gf.kernel archive.",
			row_key=scenario,
			error=trim_text(str(error), 300),
		))


def extract_package_godot_cli_smoke_offline_bundle(
	bundle_path: Path,
	extract_root: Path,
	scenario: str,
	issues: list[dict[str, Any]],
) -> None:
	if not bundle_path.is_file():
		issues.append(make_package_issue(
			"package_godot_cli_smoke_offline_bundle_missing",
			relative_or_absolute_path(bundle_path),
			"Smoke setup should find the built offline bundle zip.",
			row_key=scenario,
		))
		return
	extract_root.mkdir(parents=True, exist_ok=True)
	try:
		with zipfile.ZipFile(bundle_path, "r") as archive:
			for info in archive.infolist():
				normalized = info.filename.replace("\\", "/")
				if info.is_dir():
					continue
				if not package_build_bundle_entry_is_safe(normalized):
					issues.append(make_package_issue(
						"package_godot_cli_smoke_offline_bundle_unsafe_path",
						relative_or_absolute_path(bundle_path),
						"Smoke setup rejected an unsafe offline bundle entry.",
						row_key=scenario,
						actual_value=normalized,
					))
					continue
				target_path = extract_root / normalized
				target_path.parent.mkdir(parents=True, exist_ok=True)
				target_path.write_bytes(archive.read(info))
	except zipfile.BadZipFile as error:
		issues.append(make_package_issue(
			"package_godot_cli_smoke_offline_bundle_bad_zip",
			relative_or_absolute_path(bundle_path),
			"Smoke setup could not read the built offline bundle zip.",
			row_key=scenario,
			error=trim_text(str(error), 300),
		))


def package_godot_cli_smoke_zip_file_count(path: Path) -> int:
	try:
		with zipfile.ZipFile(path, "r") as archive:
			return len([name for name in archive.namelist() if name and not name.endswith("/")])
	except (OSError, zipfile.BadZipFile):
		return 0


def parse_package_godot_cli_json(stdout: str) -> dict[str, Any]:
	for raw_line in reversed(stdout.splitlines()):
		line = raw_line.strip()
		if not line.startswith("{") or not line.endswith("}"):
			continue
		try:
			data = json.loads(line)
		except json.JSONDecodeError:
			continue
		if isinstance(data, dict):
			return data
	return {}


def assert_package_godot_cli_smoke_condition(
	condition: bool,
	issues: list[dict[str, Any]],
	scenario: str,
	kind: str,
	message: str,
	**extra: Any,
) -> None:
	if condition:
		return
	issues.append(make_package_issue(kind, "addons/gf/kernel/package/gf_package_cli.gd", message, row_key=scenario, **extra))


def package_godot_cli_result_issues_contain(data: dict[str, Any], text: str) -> bool:
	result_issues = data.get("issues", [])
	if not isinstance(result_issues, list):
		return False
	return any(text in str(issue) for issue in result_issues)


def record_package_godot_cli_smoke_scenario(
	scenarios: list[dict[str, Any]],
	name: str,
	ok: bool,
	details: dict[str, Any] | None = None,
) -> None:
	scenario = {"name": name, "ok": ok}
	if details:
		scenario.update(details)
	scenarios.append(scenario)


def make_package_godot_cli_smoke_payload(
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
	registry_path: Path,
) -> dict[str, Any]:
	return {
		"ok": len(issues) == 0 and all(bool(scenario.get("ok")) for scenario in scenarios),
		"root": str(ROOT),
		"registry": registry_path.as_posix(),
		"scenario_count": len(scenarios),
		"issue_count": len(issues),
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"scenarios": scenarios,
		"issues": issues,
	}


def package_godot_smoke(
	all_packages: bool = False,
	package_ids: list[str] | None = None,
	jobs: int = 0,
) -> dict[str, Any]:
	with tempfile.TemporaryDirectory(prefix="gf-package-godot-smoke-") as temp_dir:
		temp_root = Path(temp_dir)
		output_dir = temp_root / "packages"
		registry_path = temp_root / "registry/index.json"
		issues: list[dict[str, Any]] = []
		scenarios: list[dict[str, Any]] = []
		selected_package_ids = normalize_package_godot_smoke_package_ids(package_ids or [])
		mode = "selected" if selected_package_ids else ("all" if all_packages else "representative")
		scenario_jobs = package_godot_smoke_job_count(mode, jobs)

		build_data = run_package_smoke_json_command(
			"build_registry",
			[
				sys.executable,
				"tools/build_gf_package.py",
				"--all",
				"--output-dir",
				str(output_dir),
				"--registry",
				str(registry_path),
				"--json",
			],
			issues,
		)
		record_package_install_smoke_scenario(
			scenarios,
			"build_registry",
			len(issues) == 0 and bool(build_data.get("ok")),
			{"package_count": build_data.get("package_count", 0)},
		)
		if issues or not build_data.get("ok"):
			if not build_data.get("ok") and not issues:
				issues.append(make_package_issue(
					"package_godot_smoke_builder_failed",
					"tools/build_gf_package.py",
					"Package builder did not report ok=true.",
					row_key="build_registry",
				))
			return make_package_godot_smoke_payload(scenarios, issues, registry_path, mode, 0)

		if selected_package_ids:
			scenario_specs = package_godot_smoke_selected_package_specs(registry_path, selected_package_ids, issues)
		elif all_packages:
			scenario_specs = package_godot_smoke_all_package_specs(registry_path, issues)
		else:
			scenario_specs = package_godot_smoke_representative_specs()
		run_package_godot_smoke_specs(
			temp_root,
			registry_path,
			scenario_specs,
			scenario_jobs,
			scenarios,
			issues,
		)
		return make_package_godot_smoke_payload(
			scenarios,
			issues,
			registry_path,
			mode,
			len(scenario_specs),
			scenario_jobs,
		)


def package_godot_smoke_job_count(mode: str, jobs: int) -> int:
	if jobs > 0:
		return max(1, jobs)
	if mode == "all":
		return max(1, min(PACKAGE_GODOT_SMOKE_DEFAULT_ALL_PACKAGE_JOBS, os.cpu_count() or 1))
	return 1


def run_package_godot_smoke_specs(
	temp_root: Path,
	registry_path: Path,
	scenario_specs: list[dict[str, Any]],
	jobs: int,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	if jobs <= 1 or len(scenario_specs) <= 1:
		for index, spec in enumerate(scenario_specs):
			result = run_package_godot_smoke_scenario_result(temp_root, registry_path, index, spec)
			extend_package_godot_smoke_result(result, scenarios, issues)
		return

	results: list[dict[str, Any]] = []
	with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as executor:
		future_by_index = {
			executor.submit(run_package_godot_smoke_scenario_result, temp_root, registry_path, index, spec): index
			for index, spec in enumerate(scenario_specs)
		}
		for future in concurrent.futures.as_completed(future_by_index):
			index = future_by_index[future]
			try:
				results.append(future.result())
			except Exception as error:
				spec = scenario_specs[index]
				scenario_name = str(spec.get("name", ""))
				results.append({
					"index": index,
					"scenarios": [{
						"name": scenario_name,
						"ok": False,
						"package_id": str(spec.get("package_id", "")),
						"package_kind": str(spec.get("kind", "")),
					}],
					"issues": [make_package_issue(
						"package_godot_smoke_worker_failed",
						"tools/gf_maintenance.py",
						"Package Godot smoke worker raised an unexpected exception.",
						row_key=scenario_name,
						error=trim_text(str(error), 500),
					)],
				})
	for result in sorted(results, key=lambda item: int_value(item.get("index", 0))):
		extend_package_godot_smoke_result(result, scenarios, issues)


def run_package_godot_smoke_scenario_result(
	temp_root: Path,
	registry_path: Path,
	index: int,
	spec: dict[str, Any],
) -> dict[str, Any]:
	local_scenarios: list[dict[str, Any]] = []
	local_issues: list[dict[str, Any]] = []
	run_package_godot_smoke_scenario(
		temp_root,
		registry_path,
		str(spec["name"]),
		str(spec["package_id"]),
		str(spec.get("kind", "")),
		list(spec.get("expected_files", [])),
		local_scenarios,
		local_issues,
	)
	return {
		"index": index,
		"scenarios": local_scenarios,
		"issues": local_issues,
	}


def extend_package_godot_smoke_result(
	result: dict[str, Any],
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	for scenario in result.get("scenarios", []):
		if isinstance(scenario, dict):
			scenarios.append(scenario)
	for issue in result.get("issues", []):
		if isinstance(issue, dict):
			issues.append(issue)


def normalize_package_godot_smoke_package_ids(package_ids: list[str]) -> list[str]:
	result: list[str] = []
	seen: set[str] = set()
	for raw_id in package_ids:
		package_id = str(raw_id).strip()
		if not package_id or package_id in seen:
			continue
		seen.add(package_id)
		result.append(package_id)
	return result


def package_godot_smoke_representative_specs() -> list[dict[str, Any]]:
	return [
		{
			"name": "core_only_godot_parse",
			"package_id": "gf.kernel",
			"kind": "kernel",
			"expected_files": ["addons/gf/plugin.gd"],
		},
		{
			"name": "standard_storage_godot_parse",
			"package_id": "gf.standard.storage",
			"kind": "standard",
			"expected_files": ["addons/gf/standard/utilities/storage/gf_storage_utility.gd"],
		},
		{
			"name": "extension_save_godot_parse",
			"package_id": "gf.extension.save",
			"kind": "extension",
			"expected_files": ["addons/gf/extensions/save/gf_extension.json"],
		},
		{
			"name": "preset_rpg_godot_parse",
			"package_id": "gf.preset.rpg_save_dialogue",
			"kind": "preset",
			"expected_files": ["addons/gf/extensions/dialogue/gf_extension.json"],
		},
	]


def package_godot_smoke_all_package_specs(
	registry_path: Path,
	issues: list[dict[str, Any]],
) -> list[dict[str, Any]]:
	registry_data = read_json_object(registry_path)
	packages = registry_data.get("packages", {})
	if not isinstance(packages, dict):
		issues.append(make_package_issue(
			"package_godot_smoke_invalid_registry_packages",
			relative_or_absolute_path(registry_path),
			"Generated registry must contain a packages object for all-packages Godot smoke.",
			field="packages",
		))
		return []

	specs: list[dict[str, Any]] = []
	for package_id in sorted(packages.keys()):
		entry = packages[package_id]
		if not isinstance(entry, dict):
			issues.append(make_package_issue(
				"package_godot_smoke_invalid_registry_entry",
				relative_or_absolute_path(registry_path),
				"Generated registry package entries must be objects.",
				row_key=str(package_id),
				actual_value=type(entry).__name__,
			))
			continue
		kind = package_manifest_string(entry, "kind") or expected_package_kind_from_id(str(package_id))
		expected_files: list[str] = []
		if kind != "preset":
			expected_file = package_godot_smoke_representative_file(entry)
			if expected_file:
				expected_files.append(expected_file)
			else:
				issues.append(make_package_issue(
					"package_godot_smoke_missing_representative_file",
					relative_or_absolute_path(registry_path),
					"Non-preset packages must have at least one source file that can be asserted after install.",
					row_key=str(package_id),
					field="paths",
				))
		specs.append({
			"name": package_godot_smoke_all_package_scenario_name(str(package_id)),
			"package_id": str(package_id),
			"kind": kind,
			"expected_files": expected_files,
		})
	return specs


def package_godot_smoke_selected_package_specs(
	registry_path: Path,
	package_ids: list[str],
	issues: list[dict[str, Any]],
) -> list[dict[str, Any]]:
	all_specs = package_godot_smoke_all_package_specs(registry_path, issues)
	specs_by_id = {str(spec["package_id"]): spec for spec in all_specs}
	selected_specs: list[dict[str, Any]] = []
	for package_id in package_ids:
		spec = specs_by_id.get(package_id)
		if spec is None:
			issues.append(make_package_issue(
				"package_godot_smoke_unknown_package",
				relative_or_absolute_path(registry_path),
				"Selected package id must exist in the generated registry.",
				row_key=package_id,
			))
			continue
		selected_specs.append(spec)
	return selected_specs


def package_godot_smoke_all_package_scenario_name(package_id: str) -> str:
	safe_id = re.sub(r"[^A-Za-z0-9_]+", "_", package_id).strip("_")
	return f"all_package_{safe_id}_godot_parse"


def package_godot_smoke_representative_file(registry_entry: dict[str, Any]) -> str:
	candidates: list[str] = []
	seen: set[str] = set()
	for raw_path in package_manifest_string_array(registry_entry, "paths"):
		for candidate in package_godot_smoke_source_files_for_pattern(raw_path):
			if candidate in seen:
				continue
			seen.add(candidate)
			candidates.append(candidate)
	if not candidates:
		return ""
	return sorted(candidates, key=package_godot_smoke_source_file_sort_key)[0]


def package_godot_smoke_source_files_for_pattern(raw_path: str) -> list[str]:
	pattern = normalize_package_manifest_path(raw_path)
	if not pattern:
		return []
	if not any(character in pattern for character in "*?["):
		source_path = ROOT / pattern
		if source_path.is_file():
			return [pattern]
		if source_path.is_dir():
			return [
				path.relative_to(ROOT).as_posix()
				for path in sorted(source_path.rglob("*"))
				if path.is_file()
			]
		return []

	anchor = package_path_anchor(pattern)
	if not anchor:
		return []
	anchor_path = ROOT / anchor
	if not anchor_path.exists():
		return []
	return [
		path.relative_to(ROOT).as_posix()
		for path in sorted(anchor_path.rglob("*"))
		if path.is_file() and fnmatch.fnmatch(path.relative_to(ROOT).as_posix(), pattern)
	]


def package_godot_smoke_source_file_sort_key(path: str) -> tuple[int, str]:
	suffix = Path(path).suffix.lower()
	if suffix == ".gd":
		return (0, path)
	if suffix == ".json":
		return (1, path)
	if suffix == ".cfg":
		return (2, path)
	return (3, path)


def run_package_godot_smoke_scenario(
	temp_root: Path,
	registry_path: Path,
	scenario: str,
	package_id: str,
	package_kind: str,
	expected_files: list[str],
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	start_issue_count = len(issues)
	project_root = temp_root / scenario / "project"
	write_package_godot_smoke_project(project_root, scenario)
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			package_id,
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	assert_package_godot_smoke_condition(
		bool(install_data.get("ok")),
		issues,
		scenario,
		"package_godot_smoke_install_failed",
		"Package install should succeed before running the Godot parse smoke.",
		row_key=package_id,
		actual_value=str(install_data.get("issues", [])),
	)
	if not install_data.get("ok"):
		record_package_install_smoke_scenario(
			scenarios,
			scenario,
			False,
			{
				"package_id": package_id,
				"package_kind": package_kind,
				"installed_file_count": install_data.get("installed_file_count", 0),
			},
		)
		return
	installed_file_count = int_value(install_data.get("installed_file_count", 0))
	assert_package_godot_smoke_condition(
		installed_file_count > 0,
		issues,
		scenario,
		"package_godot_smoke_empty_install",
		"Installed package closure should copy at least one file.",
		row_key=package_id,
		actual_value=str(installed_file_count),
	)
	for relative_path in expected_files:
		assert_package_godot_smoke_condition(
			(project_root / relative_path).exists(),
			issues,
			scenario,
			"package_godot_smoke_expected_file_missing",
			"Installed package closure should contain the expected representative file.",
			row_key=package_id,
			expected_value=relative_path,
		)
	parse_script_path = write_package_godot_smoke_preload_script(project_root)
	parse_data = run_package_godot_editor_parse(
		scenario,
		project_root,
		parse_script_path,
		temp_root / scenario / "godot.log",
		issues,
	)
	record_package_install_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"package_id": package_id,
			"package_kind": package_kind,
			"installed_file_count": installed_file_count,
			"expected_file_count": len(expected_files),
			"preload_count": parse_data.get("preload_count", 0),
			"exit_leak_warning_count": parse_data.get("exit_leak_warning_count", 0),
		},
	)


def write_package_godot_smoke_project(project_root: Path, scenario: str) -> None:
	project_root.mkdir(parents=True, exist_ok=True)
	project_file = project_root / "project.godot"
	project_file.write_text(
		"\n".join([
			"; Engine configuration file.",
			"; Generated by GF package-godot-smoke.",
			"config_version=5",
			"",
			"[application]",
			f'config/name="GF Package Smoke {scenario}"',
			"",
			"[editor_plugins]",
			'enabled=PackedStringArray("res://addons/gf/plugin.cfg")',
			"",
		]),
		encoding="utf-8",
	)


def write_package_godot_smoke_preload_script(project_root: Path) -> Path:
	script_paths = sorted(
		path
		for path in (project_root / "addons/gf").rglob("*.gd")
		if path.is_file()
	)
	lines = [
		"@tool",
		"extends RefCounted",
		"",
	]
	for index, path in enumerate(script_paths):
		relative_path = path.relative_to(project_root).as_posix()
		lines.append(f'const SCRIPT_{index:04d} = preload("res://{relative_path}")')
	lines.append("")
	lines.append("static func script_count() -> int:")
	lines.append(f"\treturn {len(script_paths)}")
	script_path = project_root / "package_godot_parse_smoke.gd"
	script_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
	return script_path


def run_package_godot_editor_parse(
	scenario: str,
	project_root: Path,
	parse_script_path: Path,
	log_path: Path,
	issues: list[dict[str, Any]],
) -> dict[str, Any]:
	log_path.parent.mkdir(parents=True, exist_ok=True)
	command = [
		"godot",
		"--headless",
		"--log-file",
		str(log_path),
		"--path",
		str(project_root),
		"--editor",
		"--quit",
	]
	try:
		completed = subprocess.run(
			command,
			cwd=ROOT,
			capture_output=True,
			text=True,
			encoding="utf-8",
			errors="replace",
			timeout=180,
		)
	except subprocess.TimeoutExpired as error:
		issues.append(make_package_issue(
			"package_godot_smoke_timeout",
			"godot",
			"Godot editor parse smoke timed out.",
			row_key=scenario,
			error=trim_text(str(error), 300),
		))
		return {"preload_count": package_godot_smoke_preload_count(parse_script_path), "exit_leak_warning_count": 0}
	except FileNotFoundError as error:
		issues.append(make_package_issue(
			"package_godot_smoke_godot_missing",
			"godot",
			"Godot executable was not found on PATH.",
			row_key=scenario,
			error=trim_text(str(error), 300),
		))
		return {"preload_count": package_godot_smoke_preload_count(parse_script_path), "exit_leak_warning_count": 0}

	log_text = read_text_file(log_path)
	combined_output = "\n".join([completed.stdout, completed.stderr, log_text])
	if completed.returncode != 0:
		issues.append(make_package_issue(
			"package_godot_smoke_process_failed",
			"godot",
			"Godot editor parse smoke returned a failing process exit code.",
			row_key=scenario,
			actual_value=str(completed.returncode),
			error=package_godot_smoke_output_excerpt(combined_output),
		))
	if has_godot_script_error(combined_output, ""):
		issues.append(make_package_issue(
			"package_godot_smoke_script_error",
			"godot",
			"Godot reported script loading or parse errors for an installed package closure.",
			row_key=scenario,
			error=package_godot_smoke_output_excerpt(combined_output),
		))
	if has_gdscript_reload_warning(combined_output, ""):
		issues.append(make_package_issue(
			"package_godot_smoke_reload_warning",
			"godot",
			"Godot reported GDScript reload warnings for an installed package closure.",
			row_key=scenario,
			error=package_godot_smoke_output_excerpt(combined_output),
		))
	exit_leak_warnings = collect_godot_exit_leak_warnings(combined_output, "")
	return {
		"preload_count": package_godot_smoke_preload_count(parse_script_path),
		"exit_leak_warning_count": len(exit_leak_warnings),
	}


def package_godot_smoke_preload_count(parse_script_path: Path) -> int:
	source = read_text_file(parse_script_path)
	return len([line for line in source.splitlines() if "preload(" in line])


def package_godot_smoke_output_excerpt(output: str) -> str:
	lines: list[str] = []
	for line in output.splitlines():
		if (
			any(pattern in line for pattern in GODOT_SCRIPT_ERROR_PATTERNS)
			or any(pattern in line for pattern in GDSCRIPT_RELOAD_WARNING_PATTERNS)
			or "ERROR:" in line
			or "WARNING:" in line
		):
			lines.append(line.strip())
		if len(lines) >= 12:
			break
	return trim_text("\n".join(lines) if lines else output.strip(), 1200)


def assert_package_godot_smoke_condition(
	condition: bool,
	issues: list[dict[str, Any]],
	scenario: str,
	kind: str,
	message: str,
	**extra: Any,
) -> None:
	if condition:
		return
	issues.append(make_package_issue(kind, "tools/gf_maintenance.py", message, row_key=scenario, **extra))


def make_package_godot_smoke_payload(
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
	registry_path: Path,
	mode: str,
	package_count: int,
	jobs: int = 1,
) -> dict[str, Any]:
	return {
		"ok": len(issues) == 0 and all(bool(scenario.get("ok")) for scenario in scenarios),
		"root": str(ROOT),
		"registry": registry_path.as_posix(),
		"mode": mode,
		"package_count": package_count,
		"jobs": jobs,
		"scenario_count": len(scenarios),
		"issue_count": len(issues),
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"scenarios": scenarios,
		"issues": issues,
	}


def uninstall_smoke() -> dict[str, Any]:
	with tempfile.TemporaryDirectory(prefix="gf-uninstall-smoke-") as temp_dir:
		temp_root = Path(temp_dir)
		output_dir = temp_root / "packages"
		registry_path = temp_root / "registry/index.json"
		issues: list[dict[str, Any]] = []
		scenarios: list[dict[str, Any]] = []

		build_data = run_uninstall_smoke_json_command(
			"build_registry",
			[
				sys.executable,
				"tools/build_gf_package.py",
				"--all",
				"--output-dir",
				str(output_dir),
				"--registry",
				str(registry_path),
				"--json",
			],
			issues,
		)
		record_uninstall_smoke_scenario(
			scenarios,
			"build_registry",
			len(issues) == 0 and bool(build_data.get("ok")),
			{"package_count": build_data.get("package_count", 0)},
		)
		if issues or not build_data.get("ok"):
			if not build_data.get("ok") and not issues:
				issues.append(make_package_issue(
					"uninstall_smoke_builder_failed",
					"tools/build_gf_package.py",
					"Package builder did not report ok=true.",
					row_key="build_registry",
				))
			return make_uninstall_smoke_payload(scenarios, issues, registry_path)

		run_uninstall_smoke_save_install_verify(temp_root, registry_path, scenarios, issues)
		run_uninstall_smoke_shared_dependency(temp_root, registry_path, scenarios, issues)
		run_uninstall_smoke_manual_pin(temp_root, registry_path, scenarios, issues)
		run_uninstall_smoke_project_reference_block(temp_root, registry_path, scenarios, issues)
		run_uninstall_smoke_physical_save_remove(temp_root, registry_path, scenarios, issues)
		run_uninstall_smoke_physical_shared_dependency(temp_root, registry_path, scenarios, issues)
		run_uninstall_smoke_physical_manual_pin(temp_root, registry_path, scenarios, issues)
		run_uninstall_smoke_physical_project_reference_block(temp_root, registry_path, scenarios, issues)
		run_uninstall_smoke_physical_dry_run(temp_root, registry_path, scenarios, issues)
		run_uninstall_smoke_physical_missing_file_list_rejection(temp_root, registry_path, scenarios, issues)
		run_uninstall_smoke_physical_rollback(temp_root, registry_path, scenarios, issues)
		return make_uninstall_smoke_payload(scenarios, issues, registry_path)


def run_uninstall_smoke_save_install_verify(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "save_install_verify"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	lockfile_path = project_root / ".gf/packages.lock.json"
	install_data = run_uninstall_smoke_resolver(
		scenario,
		[
			"install-plan",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--lockfile",
			str(lockfile_path),
			"--write-lock",
			"--json",
		],
		issues,
	)
	assert_uninstall_smoke_condition(
		bool(install_data.get("ok")),
		issues,
		scenario,
		"uninstall_smoke_save_install_failed",
		"Installing gf.extension.save should produce an ok resolver plan.",
	)
	install_order = set(uninstall_smoke_string_list(install_data.get("install_order", [])))
	for package_id in ["gf.kernel", "gf.standard.base", "gf.standard.storage", "gf.standard.deterministic", "gf.extension.save"]:
		assert_uninstall_smoke_condition(
			package_id in install_order,
			issues,
			scenario,
			"uninstall_smoke_missing_install_order_package",
			f"Installing gf.extension.save should include {package_id} in the dependency closure.",
			expected_value=package_id,
		)
	installed = uninstall_smoke_installed(install_data)
	assert_uninstall_smoke_condition(
		"manual" in package_lock_reasons(installed, "gf.extension.save"),
		issues,
		scenario,
		"uninstall_smoke_save_reason_missing",
		"Explicitly installed extension should be marked as manual.",
		row_key="gf.extension.save",
		expected_value="manual",
	)
	assert_uninstall_smoke_condition(
		"bundled" in package_lock_reasons(installed, "gf.kernel"),
		issues,
		scenario,
		"uninstall_smoke_kernel_reason_missing",
		"Kernel installed as a dependency closure should be marked as bundled.",
		row_key="gf.kernel",
		expected_value="bundled",
	)
	assert_uninstall_smoke_condition(
		"gf.extension.save" in package_lock_required_by(installed, "gf.standard.storage"),
		issues,
		scenario,
		"uninstall_smoke_storage_required_by_missing",
		"Storage standard package should record gf.extension.save as a reverse dependency.",
		row_key="gf.standard.storage",
		expected_value="gf.extension.save",
	)
	verify_data = run_uninstall_smoke_resolver(
		scenario,
		[
			"verify-lock",
			"--registry",
			str(registry_path),
			"--lockfile",
			str(lockfile_path),
			"--json",
		],
		issues,
	)
	assert_uninstall_smoke_condition(
		bool(verify_data.get("ok")),
		issues,
		scenario,
		"uninstall_smoke_verify_lock_failed",
		"Lockfile written by install-plan should verify against the registry.",
	)
	record_uninstall_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"installed_count": install_data.get("installed_count", 0)},
	)


def run_uninstall_smoke_shared_dependency(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "shared_dependency_uninstall"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	lockfile_path = project_root / ".gf/packages.lock.json"
	for package_id in ["gf.extension.save", "gf.extension.domain"]:
		run_uninstall_smoke_resolver(
			scenario,
			[
				"install-plan",
				package_id,
				"--registry",
				str(registry_path),
				"--lockfile",
				str(lockfile_path),
				"--write-lock",
				"--json",
			],
			issues,
		)
	uninstall_data = run_uninstall_smoke_resolver(
		scenario,
		[
			"uninstall-plan",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--lockfile",
			str(lockfile_path),
			"--project-root",
			str(project_root),
			"--write-lock",
			"--json",
		],
		issues,
	)
	installed = uninstall_smoke_installed(uninstall_data)
	assert_uninstall_smoke_condition(
		bool(uninstall_data.get("ok")),
		issues,
		scenario,
		"uninstall_smoke_shared_uninstall_failed",
		"Uninstalling one extension should succeed when no project references it.",
	)
	assert_uninstall_smoke_condition(
		"gf.extension.save" not in installed,
		issues,
		scenario,
		"uninstall_smoke_save_not_removed",
		"Uninstalling gf.extension.save should remove that package from the planned lockfile.",
		row_key="gf.extension.save",
	)
	assert_uninstall_smoke_condition(
		"gf.extension.domain" in installed,
		issues,
		scenario,
		"uninstall_smoke_domain_removed",
		"Uninstalling gf.extension.save should not remove gf.extension.domain.",
		row_key="gf.extension.domain",
	)
	assert_uninstall_smoke_condition(
		"gf.standard.storage" in installed,
		issues,
		scenario,
		"uninstall_smoke_shared_storage_removed",
		"Shared storage package should remain because gf.extension.domain still requires it.",
		row_key="gf.standard.storage",
	)
	assert_uninstall_smoke_condition(
		"gf.extension.domain" in package_lock_required_by(installed, "gf.standard.storage"),
		issues,
		scenario,
		"uninstall_smoke_shared_required_by_missing",
		"Storage should retain gf.extension.domain in required_by after save is removed.",
		row_key="gf.standard.storage",
		expected_value="gf.extension.domain",
	)
	record_uninstall_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"removed": uninstall_data.get("to_remove", [])},
	)


def run_uninstall_smoke_manual_pin(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "manual_pin_keeps_standard"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	lockfile_path = project_root / ".gf/packages.lock.json"
	run_uninstall_smoke_resolver(
		scenario,
		[
			"install-plan",
			"gf.standard.storage",
			"--reason",
			"manual",
			"--registry",
			str(registry_path),
			"--lockfile",
			str(lockfile_path),
			"--write-lock",
			"--json",
		],
		issues,
	)
	run_uninstall_smoke_resolver(
		scenario,
		[
			"install-plan",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--lockfile",
			str(lockfile_path),
			"--write-lock",
			"--json",
		],
		issues,
	)
	uninstall_data = run_uninstall_smoke_resolver(
		scenario,
		[
			"uninstall-plan",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--lockfile",
			str(lockfile_path),
			"--project-root",
			str(project_root),
			"--write-lock",
			"--json",
		],
		issues,
	)
	installed = uninstall_smoke_installed(uninstall_data)
	assert_uninstall_smoke_condition(
		bool(uninstall_data.get("ok")),
		issues,
		scenario,
		"uninstall_smoke_manual_pin_uninstall_failed",
		"Uninstalling an extension should succeed when a shared standard package is manually pinned.",
	)
	assert_uninstall_smoke_condition(
		"gf.standard.storage" in installed,
		issues,
		scenario,
		"uninstall_smoke_manual_storage_removed",
		"Manually installed storage package should remain after uninstalling gf.extension.save.",
		row_key="gf.standard.storage",
	)
	assert_uninstall_smoke_condition(
		"manual" in package_lock_reasons(installed, "gf.standard.storage"),
		issues,
		scenario,
		"uninstall_smoke_manual_reason_lost",
		"Storage package should retain manual reason after dependent extension removal.",
		row_key="gf.standard.storage",
		expected_value="manual",
	)
	record_uninstall_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"removed": uninstall_data.get("to_remove", [])},
	)


def run_uninstall_smoke_project_reference_block(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "project_reference_blocks_uninstall"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	lockfile_path = project_root / ".gf/packages.lock.json"
	run_uninstall_smoke_resolver(
		scenario,
		[
			"install-plan",
			"gf.standard.storage",
			"--reason",
			"manual",
			"--registry",
			str(registry_path),
			"--lockfile",
			str(lockfile_path),
			"--write-lock",
			"--json",
		],
		issues,
	)
	script_path = project_root / "scripts/uses_storage.gd"
	script_path.parent.mkdir(parents=True, exist_ok=True)
	script_path.write_text("extends Node\nvar storage: GFStorageUtility\n", encoding="utf-8")
	uninstall_data = run_uninstall_smoke_resolver(
		scenario,
		[
			"uninstall-plan",
			"gf.standard.storage",
			"--registry",
			str(registry_path),
			"--lockfile",
			str(lockfile_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	blocked = uninstall_data.get("blocked", []) if isinstance(uninstall_data.get("blocked", []), list) else []
	project_reference_blocks = [
		item for item in blocked
		if isinstance(item, dict)
		and item.get("id") == "gf.standard.storage"
		and item.get("reason") == "project_references"
	]
	assert_uninstall_smoke_condition(
		not bool(uninstall_data.get("ok")),
		issues,
		scenario,
		"uninstall_smoke_project_reference_not_blocked",
		"Project references should block uninstalling a standard package.",
		row_key="gf.standard.storage",
	)
	assert_uninstall_smoke_condition(
		bool(project_reference_blocks),
		issues,
		scenario,
		"uninstall_smoke_project_reference_reason_missing",
		"Uninstall block should use project_references reason.",
		row_key="gf.standard.storage",
		expected_value="project_references",
	)
	assert_uninstall_smoke_condition(
		any(
			isinstance(reference, dict)
			and reference.get("path") == "scripts/uses_storage.gd"
			and reference.get("symbol") == "GFStorageUtility"
			for block in project_reference_blocks
			for reference in block.get("references", [])
			if isinstance(block.get("references", []), list)
		),
		issues,
		scenario,
		"uninstall_smoke_project_reference_detail_missing",
		"Uninstall block should report the project script and referenced storage symbol.",
		row_key="gf.standard.storage",
		expected_value="scripts/uses_storage.gd:GFStorageUtility",
	)
	record_uninstall_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"blocked": blocked},
	)


def run_uninstall_smoke_physical_save_remove(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "physical_save_uninstall"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	install_data = run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	uninstall_data = run_package_installer_smoke(
		scenario,
		[
			"uninstall",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	installed = uninstall_smoke_installed(uninstall_data)
	assert_uninstall_installer_smoke_condition(
		bool(install_data.get("ok")) and bool(uninstall_data.get("ok")),
		issues,
		scenario,
		"uninstall_smoke_physical_save_uninstall_failed",
		"Installing and physically uninstalling gf.extension.save should succeed.",
	)
	assert_uninstall_installer_smoke_condition(
		"gf.extension.save" not in installed and "gf.standard.storage" not in installed and "gf.kernel" in installed,
		issues,
		scenario,
		"uninstall_smoke_physical_lockfile_wrong_after_save_remove",
		"Physical save uninstall should remove save and dependency-only standard packages while keeping kernel.",
		actual_value=",".join(sorted(installed.keys())),
	)
	assert_uninstall_installer_smoke_condition(
		not (project_root / "addons/gf/extensions/save/gf_extension.json").exists()
		and not (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").exists()
		and (project_root / "addons/gf/plugin.gd").is_file(),
		issues,
		scenario,
		"uninstall_smoke_physical_files_wrong_after_save_remove",
		"Physical save uninstall should delete removed package files and keep kernel files.",
	)
	verify_uninstall_smoke_physical_lock(project_root, registry_path, scenario, issues)
	record_uninstall_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"removed": uninstall_data.get("removed_packages", []), "removed_file_count": uninstall_data.get("removed_file_count", 0)},
	)


def run_uninstall_smoke_physical_shared_dependency(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "physical_shared_dependency_uninstall"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	for package_id in ["gf.extension.save", "gf.extension.domain"]:
		run_package_installer_smoke(
			scenario,
			[
				"install",
				package_id,
				"--registry",
				str(registry_path),
				"--project-root",
				str(project_root),
				"--json",
			],
			issues,
		)
	uninstall_data = run_package_installer_smoke(
		scenario,
		[
			"uninstall",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	installed = uninstall_smoke_installed(uninstall_data)
	assert_uninstall_installer_smoke_condition(
		bool(uninstall_data.get("ok")),
		issues,
		scenario,
		"uninstall_smoke_physical_shared_uninstall_failed",
		"Physical uninstall should remove only the requested extension when another extension shares dependencies.",
	)
	assert_uninstall_installer_smoke_condition(
		"gf.extension.save" not in installed
		and "gf.extension.domain" in installed
		and "gf.standard.storage" in installed
		and (project_root / "addons/gf/extensions/domain/gf_extension.json").is_file()
		and (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").is_file(),
		issues,
		scenario,
		"uninstall_smoke_physical_shared_dependency_removed",
		"Shared dependency files should remain while gf.extension.domain still requires them.",
		actual_value=",".join(sorted(installed.keys())),
	)
	verify_uninstall_smoke_physical_lock(project_root, registry_path, scenario, issues)
	record_uninstall_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"removed": uninstall_data.get("removed_packages", [])},
	)


def run_uninstall_smoke_physical_manual_pin(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "physical_manual_pin_keeps_standard"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.standard.storage",
			"--reason",
			"manual",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	uninstall_data = run_package_installer_smoke(
		scenario,
		[
			"uninstall",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	installed = uninstall_smoke_installed(uninstall_data)
	assert_uninstall_installer_smoke_condition(
		bool(uninstall_data.get("ok"))
		and "gf.standard.storage" in installed
		and "manual" in package_lock_reasons(installed, "gf.standard.storage")
		and (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").is_file(),
		issues,
		scenario,
		"uninstall_smoke_physical_manual_pin_removed",
		"Physical uninstall should keep a manually pinned standard package and its files.",
		actual_value=",".join(sorted(installed.keys())),
	)
	verify_uninstall_smoke_physical_lock(project_root, registry_path, scenario, issues)
	record_uninstall_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"removed": uninstall_data.get("removed_packages", [])},
	)


def run_uninstall_smoke_physical_project_reference_block(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "physical_project_reference_blocks_uninstall"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.standard.storage",
			"--reason",
			"manual",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	script_path = project_root / "scripts/uses_storage.gd"
	script_path.parent.mkdir(parents=True, exist_ok=True)
	script_path.write_text("extends Node\nvar storage: GFStorageUtility\n", encoding="utf-8")
	uninstall_data = run_package_installer_smoke(
		scenario,
		[
			"uninstall",
			"gf.standard.storage",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	installed = read_uninstall_smoke_lock_installed(project_root)
	blocked = uninstall_data.get("blocked", []) if isinstance(uninstall_data.get("blocked", []), list) else []
	assert_uninstall_installer_smoke_condition(
		not bool(uninstall_data.get("ok"))
		and "gf.standard.storage" in installed
		and (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").is_file(),
		issues,
		scenario,
		"uninstall_smoke_physical_reference_block_mutated_project",
		"Project references should block physical uninstall without deleting package files.",
		actual_value=str(blocked),
	)
	record_uninstall_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"blocked": blocked},
	)


def run_uninstall_smoke_physical_dry_run(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "physical_uninstall_dry_run_no_mutation"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	uninstall_data = run_package_installer_smoke(
		scenario,
		[
			"uninstall",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--dry-run",
			"--json",
		],
		issues,
	)
	installed = read_uninstall_smoke_lock_installed(project_root)
	assert_uninstall_installer_smoke_condition(
		bool(uninstall_data.get("ok"))
		and bool(uninstall_data.get("dry_run"))
		and int(uninstall_data.get("removed_file_count", -1)) == 0
		and int(uninstall_data.get("planned_file_count", 0)) > 0
		and "gf.extension.save" in installed
		and (project_root / "addons/gf/extensions/save/gf_extension.json").is_file(),
		issues,
		scenario,
		"uninstall_smoke_physical_dry_run_mutated_project",
		"Dry-run physical uninstall should not delete files or rewrite the lockfile.",
	)
	record_uninstall_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"planned_file_count": uninstall_data.get("planned_file_count", 0)},
	)


def run_uninstall_smoke_physical_missing_file_list_rejection(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "physical_missing_file_list_rejection"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	extra_file = project_root / "addons/gf/extensions/save/project_extra_file.gd"
	extra_file.parent.mkdir(parents=True, exist_ok=True)
	extra_file.write_text("extends Node\n", encoding="utf-8")
	remove_uninstall_smoke_lockfile_files(
		project_root,
		[
			"gf.extension.save",
			"gf.standard.base",
			"gf.standard.deterministic",
			"gf.standard.storage",
		],
	)
	uninstall_data = run_package_installer_smoke(
		scenario,
		[
			"uninstall",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
		allow_failure=True,
	)
	lockfile_data = read_json_object(project_root / ".gf/packages.lock.json")
	installed = lockfile_data.get("installed", {}) if isinstance(lockfile_data.get("installed", {}), dict) else {}
	uninstall_issues = uninstall_smoke_string_list(uninstall_data.get("issues", []))
	assert_uninstall_installer_smoke_condition(
		not bool(uninstall_data.get("ok"))
		and int(uninstall_data.get("planned_file_count", -1)) == 0
		and int(uninstall_data.get("removed_file_count", -1)) == 0
		and any("missing the installed files list" in issue for issue in uninstall_issues),
		issues,
		scenario,
		"uninstall_smoke_missing_files_not_rejected",
		"Physical uninstall should reject lockfile entries that lack exact files lists.",
		actual_value=json.dumps({
			"ok": uninstall_data.get("ok"),
			"planned_file_count": uninstall_data.get("planned_file_count"),
			"removed_file_count": uninstall_data.get("removed_file_count"),
			"issues": uninstall_issues,
		}, ensure_ascii=False, sort_keys=True),
	)
	assert_uninstall_installer_smoke_condition(
		"gf.extension.save" in installed
		and "gf.standard.storage" in installed
		and "gf.standard.base" in installed
		and "gf.standard.deterministic" in installed
		and "gf.kernel" in installed
		and (project_root / "addons/gf/extensions/save/gf_extension.json").exists()
		and (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").exists()
		and extra_file.is_file(),
		issues,
		scenario,
		"uninstall_smoke_missing_files_rejection_mutated_project",
		"Strict missing-files-list rejection should not delete package or user-added files.",
		actual_value=",".join(sorted(installed.keys())),
	)
	record_uninstall_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{
			"planned_file_count": uninstall_data.get("planned_file_count", 0),
			"removed_file_count": uninstall_data.get("removed_file_count", 0),
		},
	)


def run_uninstall_smoke_physical_rollback(
	temp_root: Path,
	registry_path: Path,
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
) -> None:
	scenario = "physical_uninstall_failure_rolls_back"
	start_issue_count = len(issues)
	project_root = temp_root / scenario
	run_package_installer_smoke(
		scenario,
		[
			"install",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--json",
		],
		issues,
	)
	uninstall_data = run_package_installer_smoke(
		scenario,
		[
			"uninstall",
			"gf.extension.save",
			"--registry",
			str(registry_path),
			"--project-root",
			str(project_root),
			"--simulate-delete-failure-after",
			"5",
			"--json",
		],
		issues,
		allow_failure=True,
	)
	installed = read_uninstall_smoke_lock_installed(project_root)
	assert_uninstall_installer_smoke_condition(
		not bool(uninstall_data.get("ok"))
		and bool(uninstall_data.get("rolled_back"))
		and "gf.extension.save" in installed
		and (project_root / "addons/gf/extensions/save/gf_extension.json").is_file()
		and (project_root / "addons/gf/standard/utilities/storage/gf_storage_utility.gd").is_file(),
		issues,
		scenario,
		"uninstall_smoke_physical_rollback_failed",
		"Simulated physical uninstall failure should restore deleted files and keep the old lockfile.",
		actual_value=str(uninstall_data.get("issues", [])),
	)
	verify_uninstall_smoke_physical_lock(project_root, registry_path, scenario, issues)
	record_uninstall_smoke_scenario(
		scenarios,
		scenario,
		len(issues) == start_issue_count,
		{"rolled_back": uninstall_data.get("rolled_back", False)},
	)


def verify_uninstall_smoke_physical_lock(
	project_root: Path,
	registry_path: Path,
	scenario: str,
	issues: list[dict[str, Any]],
) -> None:
	verify_data = run_uninstall_smoke_resolver(
		scenario,
		[
			"verify-lock",
			"--registry",
			str(registry_path),
			"--lockfile",
			str(project_root / ".gf/packages.lock.json"),
			"--json",
		],
		issues,
	)
	assert_uninstall_installer_smoke_condition(
		bool(verify_data.get("ok")),
		issues,
		scenario,
		"uninstall_smoke_physical_verify_lock_failed",
		"Lockfile after physical uninstall transaction should verify against the registry.",
	)


def read_uninstall_smoke_lock_installed(project_root: Path) -> dict[str, Any]:
	data = read_json_object(project_root / ".gf/packages.lock.json")
	installed = data.get("installed", {})
	return installed if isinstance(installed, dict) else {}


def remove_uninstall_smoke_lockfile_files(project_root: Path, package_ids: list[str]) -> None:
	lockfile_path = project_root / ".gf/packages.lock.json"
	data = read_json_object(lockfile_path)
	installed = data.get("installed", {})
	if not isinstance(installed, dict):
		return
	for package_id in package_ids:
		entry = installed.get(package_id, {})
		if isinstance(entry, dict):
			entry.pop("files", None)
	lockfile_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def assert_uninstall_installer_smoke_condition(
	condition: bool,
	issues: list[dict[str, Any]],
	scenario: str,
	kind: str,
	message: str,
	**extra: Any,
) -> None:
	if condition:
		return
	issues.append(make_package_issue(kind, "tools/gf_package_installer.py", message, row_key=scenario, **extra))


def run_uninstall_smoke_resolver(
	scenario: str,
	args: list[str],
	issues: list[dict[str, Any]],
	allow_failure: bool = False,
) -> dict[str, Any]:
	return run_uninstall_smoke_json_command(
		scenario,
		[sys.executable, "tools/gf_package_resolver.py", *args],
		issues,
		allow_failure=allow_failure,
	)


def run_uninstall_smoke_json_command(
	scenario: str,
	command: list[str],
	issues: list[dict[str, Any]],
	allow_failure: bool = False,
) -> dict[str, Any]:
	return run_package_smoke_json_command(scenario, command, issues, allow_failure=allow_failure)


def run_package_smoke_json_command(
	scenario: str,
	command: list[str],
	issues: list[dict[str, Any]],
	allow_failure: bool = False,
) -> dict[str, Any]:
	try:
		completed = subprocess.run(
			command,
			cwd=ROOT,
			capture_output=True,
			text=True,
			encoding="utf-8",
			errors="replace",
			timeout=120,
		)
	except subprocess.TimeoutExpired as error:
		issues.append(make_package_issue(
			"uninstall_smoke_command_timeout",
			command[1] if len(command) > 1 else command[0],
			"Command timed out during uninstall smoke.",
			row_key=scenario,
			error=trim_text(str(error), 300),
		))
		return {}
	if completed.returncode != 0 and not allow_failure:
		issues.append(make_package_issue(
			"uninstall_smoke_command_failed",
			command[1] if len(command) > 1 else command[0],
			"Command returned a failing exit code during uninstall smoke.",
			row_key=scenario,
			actual_value=str(completed.returncode),
			error=trim_text(completed.stderr.strip() or completed.stdout.strip(), 1000),
		))
	try:
		data = json.loads(completed.stdout or "{}")
	except json.JSONDecodeError as error:
		issues.append(make_package_issue(
			"uninstall_smoke_invalid_json",
			command[1] if len(command) > 1 else command[0],
			"Command must return JSON for uninstall smoke.",
			row_key=scenario,
			error=trim_text(str(error), 300),
		))
		return {}
	if not isinstance(data, dict):
		issues.append(make_package_issue(
			"uninstall_smoke_invalid_json_root",
			command[1] if len(command) > 1 else command[0],
			"Command JSON root must be an object for uninstall smoke.",
			row_key=scenario,
			actual_value=type(data).__name__,
		))
		return {}
	return data


def uninstall_smoke_installed(plan_data: dict[str, Any]) -> dict[str, Any]:
	planned_lockfile = plan_data.get("planned_lockfile", {})
	if not isinstance(planned_lockfile, dict):
		return {}
	installed = planned_lockfile.get("installed", {})
	return installed if isinstance(installed, dict) else {}


def package_lock_reasons(installed: dict[str, Any], package_id: str) -> list[str]:
	entry = installed.get(package_id, {})
	if not isinstance(entry, dict):
		return []
	return uninstall_smoke_string_list(entry.get("reason", []))


def package_lock_required_by(installed: dict[str, Any], package_id: str) -> list[str]:
	entry = installed.get(package_id, {})
	if not isinstance(entry, dict):
		return []
	return uninstall_smoke_string_list(entry.get("required_by", []))


def uninstall_smoke_string_list(value: Any) -> list[str]:
	if isinstance(value, str):
		return [value.strip()] if value.strip() else []
	if not isinstance(value, list):
		return []
	return [item.strip() for item in value if isinstance(item, str) and item.strip()]


def assert_uninstall_smoke_condition(
	condition: bool,
	issues: list[dict[str, Any]],
	scenario: str,
	kind: str,
	message: str,
	**extra: Any,
) -> None:
	if condition:
		return
	details = dict(extra)
	if "row_key" in details:
		details.setdefault("scenario", scenario)
	else:
		details["row_key"] = scenario
	issues.append(make_package_issue(kind, "tools/gf_package_resolver.py", message, **details))


def record_uninstall_smoke_scenario(
	scenarios: list[dict[str, Any]],
	name: str,
	ok: bool,
	details: dict[str, Any] | None = None,
) -> None:
	scenario = {"name": name, "ok": ok}
	if details:
		scenario.update(details)
	scenarios.append(scenario)


def make_uninstall_smoke_payload(
	scenarios: list[dict[str, Any]],
	issues: list[dict[str, Any]],
	registry_path: Path,
) -> dict[str, Any]:
	return {
		"ok": len(issues) == 0 and all(bool(scenario.get("ok")) for scenario in scenarios),
		"root": str(ROOT),
		"registry": registry_path.as_posix(),
		"scenario_count": len(scenarios),
		"issue_count": len(issues),
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"scenarios": scenarios,
		"issues": issues,
	}


def maintenance_self_test() -> dict[str, Any]:
	tests: list[dict[str, Any]] = []
	failures: list[dict[str, Any]] = []

	def record_result(name: str, passed: bool, message: str = "") -> None:
		result = {"name": name, "passed": passed}
		if message and not passed:
			result["message"] = message
		tests.append(result)
		if not passed:
			failures.append(result)

	valid_issues = audit_bundled_extension_manifests([
		make_manifest_test_record("fixture", make_manifest_test_data()),
	])
	record_result(
		"valid_bundled_manifest_fixture_has_no_issues",
		len(valid_issues) == 0,
		f"unexpected issues: {valid_issues}",
	)

	record_result(
		"forbidden_relation_fields_are_not_allowed_fields",
		GF_MANIFEST_ALLOWED_FIELDS.isdisjoint(GF_MANIFEST_FORBIDDEN_RELATION_FIELDS),
		"manifest relation fields must stay outside the allowed bundled manifest field set.",
	)
	record_result(
		"preset_relation_fields_are_not_allowed_fields",
		GF_PRESET_ALLOWED_FIELDS.isdisjoint(GF_PRESET_FORBIDDEN_RELATION_FIELDS),
		"preset relation fields must stay outside the allowed preset field set.",
	)
	record_result(
		"preset_package_fields_are_not_allowed_fields",
		GF_PRESET_ALLOWED_FIELDS.isdisjoint(GF_PRESET_FORBIDDEN_PACKAGE_FIELDS),
		"preset package fields must stay outside the allowed preset field set.",
	)
	record_result(
		"quick_suite_excludes_long_package_smokes",
		set(CHECK_SUITES["quick"]).isdisjoint(PACKAGE_SMOKE_CHECKS),
		"quick suite must stay light; long package build/install/Godot CLI smoke belongs to the package suite.",
	)
	record_result(
		"package_suite_includes_long_package_smokes",
		set(PACKAGE_SMOKE_CHECKS).issubset(CHECK_SUITES["package"]),
		"package suite must cover the package build/install/Godot CLI/uninstall smoke checks.",
	)
	leak_fixture_warnings = collect_godot_exit_leak_warnings(
		"ERROR: 3 RID allocations of type 'DummyTexture' were leaked at exit.",
		"\n".join([
			"WARNING: ObjectDB instances leaked at exit (run with --verbose for details).",
			"ERROR: 137 resources still in use at exit (run with --verbose for details).",
		]),
	)
	record_result(
		"godot_exit_leak_parser_captures_object_resource_and_rid_leaks",
		len(leak_fixture_warnings) == 3,
		f"expected 3 leak warning lines, got {leak_fixture_warnings}",
	)
	leak_report_fixture = make_empty_godot_exit_leak_report()
	for line in [
		"\x1b[31mERROR: 2 RID allocations of type 'DummyTexture' were leaked at exit.\x1b[0m",
		"WARNING: ObjectDB instances leaked at exit (run with --verbose for details).",
		"ERROR: 5 resources still in use at exit.",
		"Resource still in use: res://addons/gf/kernel/core/gf.gd (GDScript)",
		"Resource still in use: res://addons/gut/gui/NormalGui.tscn (PackedScene)",
		"Leaked instance: SceneTreeTimer:9223373801834751926 - Reference count: 1",
	]:
		parse_godot_exit_leak_line(line, leak_report_fixture)
	record_result(
		"godot_exit_leak_report_groups_rid_resource_and_instance_counts",
		(
			leak_report_fixture["objectdb_warning_count"] == 1
			and leak_report_fixture["resource_summary_total"] == 5
			and leak_report_fixture["resource_still_in_use_count"] == 2
			and leak_report_fixture["rid_allocation_total"] == 2
			and leak_report_fixture["leaked_instance_total"] == 1
			and leak_report_fixture["_rid_allocations"].get("DummyTexture") == 2
			and leak_report_fixture["_resource_type_counts"].get("GDScript") == 1
			and leak_report_fixture["_resource_type_counts"].get("PackedScene") == 1
			and leak_report_fixture["_resource_path_prefix_counts"].get("res://addons/gf/kernel") == 1
			and leak_report_fixture["_resource_path_prefix_counts"].get("res://addons/gut") == 1
			and leak_report_fixture["_leaked_instance_types"].get("SceneTreeTimer") == 1
		),
		f"unexpected leak report fixture: {leak_report_fixture}",
	)
	output_leak_report = godot_exit_leak_report_from_output(
		"fixture",
		"\n".join([
			"ERROR: 2 RID allocations of type 'DummyTexture' were leaked at exit.",
			"Leaked instance: Object:819718004321",
		]),
		"WARNING: ObjectDB instances leaked at exit (run with --verbose for details).",
	)
	record_result(
		"godot_exit_leak_report_from_output_groups_stdout_and_stderr",
		(
			output_leak_report["has_leaks"]
			and output_leak_report["objectdb_warning_count"] == 1
			and output_leak_report["rid_allocation_total"] == 2
			and output_leak_report["leaked_instance_total"] == 1
			and len(output_leak_report["logs"]) == 2
			and output_leak_report["leaked_instance_types"][0]["key"] == "Object"
		),
		f"unexpected output leak report: {output_leak_report}",
	)
	command_payload = CommandResult(
		"fixture",
		["godot", "--headless"],
		0,
		"",
		"",
		godot_exit_leak_report=output_leak_report,
	).to_dict()
	record_result(
		"command_result_exposes_structured_godot_exit_leak_report",
		command_payload.get("godot_exit_leak_report", {}).get("rid_allocation_total") == 2,
		f"unexpected command payload: {command_payload}",
	)
	for source_path, packaged_path in PACKAGED_PACKAGE_TOOL_PAIRS:
		source_file = ROOT / source_path
		packaged_file = ROOT / packaged_path
		matches = (
			source_file.is_file()
			and packaged_file.is_file()
			and source_file.read_bytes() == packaged_file.read_bytes()
		)
		record_result(
			"packaged_package_tool_matches_" + Path(source_path).stem,
			matches,
			f"{packaged_path} must match {source_path}; copy the root tool after changing package manager logic.",
		)
	layer_boundary_constants = read_layer_boundary_manifest_constants()
	record_result(
		"layer_boundary_allowed_dependencies_match_python_tool",
		set(layer_boundary_constants.get("EXTENSION_ALLOWED_DEPENDENCIES", [])) == set(GF_ALLOWED_EXTENSION_DEPENDENCIES),
		format_set_mismatch(
			"tests/gf_core/maintenance/test_layer_boundary_validation.gd EXTENSION_ALLOWED_DEPENDENCIES",
			set(layer_boundary_constants.get("EXTENSION_ALLOWED_DEPENDENCIES", [])),
			"tools/gf_maintenance.py GF_ALLOWED_EXTENSION_DEPENDENCIES",
			set(GF_ALLOWED_EXTENSION_DEPENDENCIES),
		),
	)
	record_result(
		"layer_boundary_allowed_manifest_fields_match_python_tool",
		set(layer_boundary_constants.get("EXTENSION_ALLOWED_MANIFEST_FIELDS", [])) == GF_MANIFEST_ALLOWED_FIELDS,
		format_set_mismatch(
			"tests/gf_core/maintenance/test_layer_boundary_validation.gd EXTENSION_ALLOWED_MANIFEST_FIELDS",
			set(layer_boundary_constants.get("EXTENSION_ALLOWED_MANIFEST_FIELDS", [])),
			"tools/gf_maintenance.py GF_MANIFEST_ALLOWED_FIELDS",
			GF_MANIFEST_ALLOWED_FIELDS,
		),
	)
	record_result(
		"layer_boundary_forbidden_manifest_fields_match_python_tool",
		set(layer_boundary_constants.get("EXTENSION_FORBIDDEN_MANIFEST_FIELDS", [])) == GF_MANIFEST_FORBIDDEN_RELATION_FIELDS,
		format_set_mismatch(
			"tests/gf_core/maintenance/test_layer_boundary_validation.gd EXTENSION_FORBIDDEN_MANIFEST_FIELDS",
			set(layer_boundary_constants.get("EXTENSION_FORBIDDEN_MANIFEST_FIELDS", [])),
			"tools/gf_maintenance.py GF_MANIFEST_FORBIDDEN_RELATION_FIELDS",
			GF_MANIFEST_FORBIDDEN_RELATION_FIELDS,
		),
	)
	layer_extension_infrastructure_paths = set(normalize_res_paths(
		layer_boundary_constants.get("KERNEL_EXTENSION_INFRASTRUCTURE_PATHS", [])
	))
	record_result(
		"layer_boundary_extension_infrastructure_paths_match_python_tool",
		layer_extension_infrastructure_paths == GF_EXTENSION_INFRASTRUCTURE_PATHS,
		format_set_mismatch(
			"tests/gf_core/maintenance/test_layer_boundary_validation.gd KERNEL_EXTENSION_INFRASTRUCTURE_PATHS",
			layer_extension_infrastructure_paths,
			"tools/gf_maintenance.py GF_EXTENSION_INFRASTRUCTURE_PATHS",
			GF_EXTENSION_INFRASTRUCTURE_PATHS,
		),
	)
	manifest_constants = read_extension_manifest_constants()
	record_result(
		"manifest_runtime_supported_fields_match_bundled_fields",
		set(manifest_constants.get("_SUPPORTED_FIELDS", [])) == GF_MANIFEST_ALLOWED_FIELDS,
		format_set_mismatch(
			"addons/gf/kernel/extension/gf_extension_manifest.gd _SUPPORTED_FIELDS",
			set(manifest_constants.get("_SUPPORTED_FIELDS", [])),
			"tools/gf_maintenance.py GF_MANIFEST_ALLOWED_FIELDS",
			GF_MANIFEST_ALLOWED_FIELDS,
		),
	)
	record_result(
		"manifest_runtime_forbidden_relation_fields_match_python_tool",
		set(manifest_constants.get("_FORBIDDEN_RELATION_FIELDS", [])) == GF_MANIFEST_FORBIDDEN_RELATION_FIELDS,
		format_set_mismatch(
			"addons/gf/kernel/extension/gf_extension_manifest.gd _FORBIDDEN_RELATION_FIELDS",
			set(manifest_constants.get("_FORBIDDEN_RELATION_FIELDS", [])),
			"tools/gf_maintenance.py GF_MANIFEST_FORBIDDEN_RELATION_FIELDS",
			GF_MANIFEST_FORBIDDEN_RELATION_FIELDS,
		),
	)
	preset_constants = read_extension_preset_constants()
	record_result(
		"preset_allowed_fields_match_runtime",
		set(preset_constants.get("_SUPPORTED_FIELDS", [])) == GF_PRESET_ALLOWED_FIELDS,
		format_set_mismatch(
			"addons/gf/kernel/extension/gf_extension_preset.gd _SUPPORTED_FIELDS",
			set(preset_constants.get("_SUPPORTED_FIELDS", [])),
			"tools/gf_maintenance.py GF_PRESET_ALLOWED_FIELDS",
			GF_PRESET_ALLOWED_FIELDS,
		),
	)
	record_result(
		"preset_forbidden_relation_fields_match_runtime",
		set(preset_constants.get("_FORBIDDEN_RELATION_FIELDS", [])) == GF_PRESET_FORBIDDEN_RELATION_FIELDS,
		format_set_mismatch(
			"addons/gf/kernel/extension/gf_extension_preset.gd _FORBIDDEN_RELATION_FIELDS",
			set(preset_constants.get("_FORBIDDEN_RELATION_FIELDS", [])),
			"tools/gf_maintenance.py GF_PRESET_FORBIDDEN_RELATION_FIELDS",
			GF_PRESET_FORBIDDEN_RELATION_FIELDS,
		),
	)
	record_result(
		"preset_forbidden_package_fields_match_runtime",
		set(preset_constants.get("_FORBIDDEN_PACKAGE_FIELDS", [])) == GF_PRESET_FORBIDDEN_PACKAGE_FIELDS,
		format_set_mismatch(
			"addons/gf/kernel/extension/gf_extension_preset.gd _FORBIDDEN_PACKAGE_FIELDS",
			set(preset_constants.get("_FORBIDDEN_PACKAGE_FIELDS", [])),
			"tools/gf_maintenance.py GF_PRESET_FORBIDDEN_PACKAGE_FIELDS",
			GF_PRESET_FORBIDDEN_PACKAGE_FIELDS,
		),
	)

	forbidden_field_data = make_manifest_test_data()
	for field_name in GF_MANIFEST_FORBIDDEN_RELATION_FIELDS:
		forbidden_field_data[field_name] = []
	forbidden_field_issues = audit_bundled_extension_manifests([
		make_manifest_test_record("fixture", forbidden_field_data),
	])
	for field_name in sorted(GF_MANIFEST_FORBIDDEN_RELATION_FIELDS):
		record_result(
			f"forbidden_manifest_relation_field_{field_name}",
			issue_exists(forbidden_field_issues, "forbidden_manifest_relation_field", field=field_name),
			f"missing forbidden relation issue for field {field_name!r}.",
		)
		record_result(
			f"unsupported_manifest_field_{field_name}",
			issue_exists(forbidden_field_issues, "unsupported_manifest_field", field=field_name),
			f"missing unsupported field issue for field {field_name!r}.",
		)

	valid_preset_issues = audit_extension_preset_data(make_preset_test_data(), "preset-fixture")
	record_result(
		"valid_extension_preset_fixture_has_no_issues",
		len(valid_preset_issues) == 0,
		f"unexpected preset issues: {valid_preset_issues}",
	)

	forbidden_preset_relation_data = make_preset_test_data()
	for field_name in GF_PRESET_FORBIDDEN_RELATION_FIELDS:
		forbidden_preset_relation_data[field_name] = []
	forbidden_preset_relation_issues = audit_extension_preset_data(
		forbidden_preset_relation_data,
		"preset-relation-fixture",
	)
	for field_name in sorted(GF_PRESET_FORBIDDEN_RELATION_FIELDS):
		record_result(
			f"forbidden_preset_relation_field_{field_name}",
			issue_exists(
				forbidden_preset_relation_issues,
				"forbidden_preset_relation_field",
				field=field_name,
			),
			f"missing forbidden preset relation issue for field {field_name!r}.",
		)

	forbidden_preset_package_data = make_preset_test_data()
	for field_name in GF_PRESET_FORBIDDEN_PACKAGE_FIELDS:
		forbidden_preset_package_data[field_name] = ""
	forbidden_preset_package_issues = audit_extension_preset_data(
		forbidden_preset_package_data,
		"preset-package-fixture",
	)
	for field_name in sorted(GF_PRESET_FORBIDDEN_PACKAGE_FIELDS):
		record_result(
			f"forbidden_preset_package_field_{field_name}",
			issue_exists(
				forbidden_preset_package_issues,
				"forbidden_preset_package_field",
				field=field_name,
			),
			f"missing forbidden preset package issue for field {field_name!r}.",
		)

	unsupported_preset_data = make_preset_test_data(custom_field=True)
	unsupported_preset_issues = audit_extension_preset_data(
		unsupported_preset_data,
		"preset-unsupported-fixture",
	)
	record_result(
		"unsupported_preset_field_is_rejected",
		issue_exists(unsupported_preset_issues, "unsupported_preset_field", field="custom_field"),
		"preset fixtures must report unknown fields instead of silently accepting them.",
	)

	enabled_issues = audit_bundled_extension_manifests([
		make_manifest_test_record("fixture", make_manifest_test_data(enabled_by_default=True)),
	])
	record_result(
		"bundled_manifest_enabled_by_default_is_rejected",
		issue_exists(enabled_issues, "bundled_extension_enabled_by_default", field="enabled_by_default"),
		"bundled GF optional extensions must stay disabled by default.",
	)

	dependency_issues = audit_bundled_extension_manifests([
		make_manifest_test_record("fixture", make_manifest_test_data(dependencies=["gf.kernel", "gf.combat"])),
	])
	record_result(
		"bundled_manifest_other_gf_extension_dependency_is_rejected",
		issue_exists(
			dependency_issues,
			"forbidden_bundled_extension_dependency",
			field="dependencies",
			symbol="gf.combat",
		),
		"bundled GF extensions must not depend on other bundled GF extensions.",
	)

	invalid_dependency_container_issues = audit_bundled_extension_manifests([
		make_manifest_test_record("fixture", make_manifest_test_data(dependencies={"gf.kernel": True})),
	])
	record_result(
		"manifest_dependencies_must_be_an_array",
		issue_exists(invalid_dependency_container_issues, "invalid_manifest_dependencies", field="dependencies"),
		"manifest dependencies must remain an array of hard dependency IDs.",
	)

	invalid_dependency_type_issues = audit_bundled_extension_manifests([
		make_manifest_test_record("fixture", make_manifest_test_data(dependencies=["gf.kernel", 42])),
	])
	record_result(
		"manifest_dependencies_must_contain_strings",
		issue_exists(invalid_dependency_type_issues, "invalid_manifest_dependency_type", field="dependencies"),
		"manifest dependencies must contain only string IDs.",
	)

	kind_issues = audit_bundled_extension_manifests([
		make_manifest_test_record("fixture", make_manifest_test_data(kind="package")),
	])
	record_result(
		"bundled_manifest_kind_must_be_extension",
		issue_exists(kind_issues, "invalid_bundled_extension_kind", field="kind"),
		"bundled GF optional extension manifests must declare kind='extension'.",
	)

	missing_extension_version_data = make_manifest_test_data()
	missing_extension_version_data.pop("extension_version", None)
	missing_extension_version_issues = audit_bundled_extension_manifests([
		make_manifest_test_record("fixture", missing_extension_version_data),
	])
	record_result(
		"bundled_manifest_requires_extension_version",
		issue_exists(missing_extension_version_issues, "missing_extension_version", field="extension_version"),
		"bundled GF extensions must declare extension_version independently from the GF release version.",
	)

	api_since_missing_source = "\n".join([
		"## Fixture.",
		"## [br]",
		"## @api public",
		"func changed_entry() -> void:",
		"\tpass",
	])
	api_since_missing_issues = find_missing_touched_api_since_issues(
		"addons/gf/fixture.gd",
		api_since_missing_source,
		{3},
	)
	record_result(
		"api_since_touched_reports_touched_public_block_without_since",
		issue_exists(api_since_missing_issues, "missing_api_since"),
		"changed public API documentation blocks without @since must fail.",
	)

	api_since_historical_issues = find_missing_touched_api_since_issues(
		"addons/gf/fixture.gd",
		api_since_missing_source,
		{5},
	)
	record_result(
		"api_since_touched_ignores_untouched_historical_block",
		not issue_exists(api_since_historical_issues, "missing_api_since"),
		"diff-scoped @since checks must not fail untouched historical API migration debt.",
	)

	api_since_export_source = "\n".join([
		"## Exported value.",
		"## [br]",
		"## @api public",
		"@export var changed_value: int = 0",
	])
	api_since_export_issues = find_missing_touched_api_since_issues(
		"addons/gf/fixture.gd",
		api_since_export_source,
		{4},
	)
	record_result(
		"api_since_touched_handles_export_var_declaration",
		issue_exists(api_since_export_issues, "missing_api_since", declaration="@export var changed_value: int = 0"),
		"@export var declarations bound to public docs must be checked for @since.",
	)

	api_since_versioned_source = "\n".join([
		"## Fixture.",
		"## [br]",
		"## @api public",
		"## [br]",
		"## @since 3.17.0",
		"func changed_entry() -> void:",
		"\tpass",
	])
	api_since_versioned_issues = find_missing_touched_api_since_issues(
		"addons/gf/fixture.gd",
		api_since_versioned_source,
		{3},
	)
	record_result(
		"api_since_touched_accepts_versioned_public_block",
		not issue_exists(api_since_versioned_issues, "missing_api_since"),
		"public API docs that already declare @since must pass the diff-scoped check.",
	)

	record_result(
		"path_hygiene_detects_utf8_bom_prefix",
		has_utf8_bom(b"\xef\xbb\xbfextends Node\n") and not has_utf8_bom(b"extends Node\n"),
		"GDScript path hygiene must detect UTF-8 BOM prefixes.",
	)

	public_doc_allowed_source = (
		"GF Workspace 固定提供扩展管理和诊断快照等基础页面。"
		"SaveGraph、Flow 等工具页面只在对应可选扩展启用后贡献到工作区。"
	)
	public_doc_allowed_issues = audit_public_doc_boundary_text(
		public_doc_allowed_source,
		"docs/zh/fixture.md",
	)
	record_result(
		"public_docs_boundary_allows_optional_extension_contribution_wording",
		len(public_doc_allowed_issues) == 0,
		f"optional extension contribution wording should pass: {public_doc_allowed_issues}",
	)

	public_doc_forbidden_term_issues = audit_public_doc_boundary_text(
		"参考 XForge 的 npm run package，把 GFPathfinding2D 写进公开路线。",
		"docs/zh/fixture.md",
	)
	record_result(
		"public_docs_boundary_rejects_external_package_research_terms",
		issue_exists(public_doc_forbidden_term_issues, "forbidden_public_doc_term", symbol="XForge")
		and issue_exists(public_doc_forbidden_term_issues, "forbidden_public_doc_term", symbol="npm run package")
		and issue_exists(public_doc_forbidden_term_issues, "forbidden_public_doc_term", symbol="GFPathfinding2D"),
		"external research terms and planning track names must stay out of public docs.",
	)

	public_doc_ai_leak_issues = audit_public_doc_boundary_text(
		"See AI_MAINTENANCE.md, Codex MCP notes, and ai_analysis/godot_logs for setup.",
		"docs/zh/fixture.md",
	)
	record_result(
		"public_docs_boundary_rejects_ai_maintenance_leaks",
		issue_exists(public_doc_ai_leak_issues, "forbidden_public_doc_term", symbol="AI_MAINTENANCE.md")
		and issue_exists(public_doc_ai_leak_issues, "forbidden_public_doc_term", symbol="Codex")
		and issue_exists(public_doc_ai_leak_issues, "forbidden_public_doc_term", symbol="MCP")
		and issue_exists(public_doc_ai_leak_issues, "forbidden_public_doc_term", symbol="ai_analysis")
		and issue_exists(public_doc_ai_leak_issues, "forbidden_public_doc_term", symbol="godot_logs"),
		"AI maintenance-only files and infrastructure must stay out of public docs.",
	)

	public_doc_workspace_bad_issues = audit_public_doc_boundary_text(
		"GF Workspace 固定页面包含扩展管理、输入映射、SaveGraph 和 Flow。",
		"docs/zh/fixture.md",
	)
	record_result(
		"public_docs_boundary_rejects_optional_pages_as_fixed_workspace_pages",
		issue_exists(public_doc_workspace_bad_issues, "optional_extension_workspace_page_as_core_page"),
		"optional extension pages must not be described as fixed workspace pages.",
	)

	public_doc_external_install_bad_issues = audit_public_doc_boundary_text(
		"\n".join([
			"To install a GF extension, users must install Python and run tools/gf_package_installer.py.",
			"安装扩展需要 npm 或 Git 作为前置条件。",
		]),
		"README.md",
	)
	record_result(
		"public_docs_boundary_rejects_external_tools_as_user_package_install_requirements",
		issue_exists(public_doc_external_install_bad_issues, "public_doc_package_manager_python_tool_path")
		and issue_exists(public_doc_external_install_bad_issues, "public_doc_package_install_external_tool_requirement", line=1)
		and issue_exists(public_doc_external_install_bad_issues, "public_doc_package_install_external_tool_requirement", line=2),
		f"public docs must not require Python/npm/Git for ordinary package installs: {public_doc_external_install_bad_issues}",
	)

	public_doc_external_install_allowed_issues = audit_public_doc_boundary_text(
		"\n".join([
			"Python dependencies are only needed when building the documentation locally.",
			"Installing GF extensions does not require Python, npm/npx, Git, Node, or pip.",
			"维护侧 Python 工具只用于本地构建和 release 审计；普通用户安装扩展不需要它。",
		]),
		"README.md",
	)
	record_result(
		"public_docs_boundary_allows_docs_and_negated_no_python_install_wording",
		not issue_exists(public_doc_external_install_allowed_issues, "public_doc_package_manager_python_tool_path")
		and not issue_exists(public_doc_external_install_allowed_issues, "public_doc_package_install_external_tool_requirement"),
		f"docs-only and no-Python wording should pass: {public_doc_external_install_allowed_issues}",
	)

	public_doc_signature_claim_bad_issues = audit_public_doc_boundary_text(
		"\n".join([
			"GF package registry signatures are verified before install.",
			"GF 扩展包安装前会完成签名验签。",
		]),
		"README.md",
	)
	record_result(
		"public_docs_boundary_rejects_package_signature_verification_claims",
		issue_exists(
			public_doc_signature_claim_bad_issues,
			"public_doc_package_signature_verification_claim",
			line=1,
		)
		and issue_exists(
			public_doc_signature_claim_bad_issues,
			"public_doc_package_signature_verification_claim",
			line=2,
		),
		f"public docs must not claim package signature verification before implementation: {public_doc_signature_claim_bad_issues}",
	)

	public_doc_signature_claim_allowed_issues = audit_public_doc_boundary_text(
		"\n".join([
			"Signature fields are rejected until Godot-native verification exists.",
			"签名验签实现前，registry 签名字段会被拒绝。",
		]),
		"README.md",
	)
	record_result(
		"public_docs_boundary_allows_unsupported_signature_policy_wording",
		not issue_exists(
			public_doc_signature_claim_allowed_issues,
			"public_doc_package_signature_verification_claim",
		),
		f"unsupported signature policy wording should pass: {public_doc_signature_claim_allowed_issues}",
	)

	resource_boundary_fixture = "\n".join([
		"const PanelScene = preload(\"res://ui/panel.tscn\")",
		"const ScriptDependency = preload(\"res://addons/gf/kernel/core/gf.gd\")",
		"var plugin_cfg = load(\"res://addons/gf/plugin.cfg\")",
		"var cached = ResourceLoader.load('user://cache/report.tres')",
		"var threaded = ResourceLoader.load_threaded_request(\"uid://fixture-resource\")",
		"# var ignored = load(\"res://ignored/comment.tres\")",
		"var text := \"load(\\\"res://ignored/string.tres\\\")\"",
		"var generated_source := 'const Other = preload(\"res://addons/gf/extensions/save_extra/example.gd\")'",
	])
	resource_boundary_fixture_path = "addons/gf/kernel/fixture.gd"
	resource_boundary_issues = audit_resource_boundary_text(
		resource_boundary_fixture,
		resource_boundary_fixture_path,
	)
	record_result(
		"resource_boundary_reports_direct_resource_path_load",
		issue_exists(
			resource_boundary_issues,
			"direct_resource_path_load",
			target="res://ui/panel.tscn",
			severity="warning",
		),
		f"missing direct resource path issue: {resource_boundary_issues}",
	)
	record_result(
		"resource_boundary_reports_direct_script_dependency_load_as_info",
		issue_exists(
			resource_boundary_issues,
			"direct_script_dependency_load",
			target="res://addons/gf/kernel/core/gf.gd",
			severity="info",
		),
		f"missing direct script dependency info issue: {resource_boundary_issues}",
	)
	record_result(
		"resource_boundary_reports_editor_metadata_load_as_info",
		issue_exists(
			resource_boundary_issues,
			"direct_editor_metadata_load",
			target="res://addons/gf/plugin.cfg",
			severity="info",
		),
		f"missing editor metadata info issue: {resource_boundary_issues}",
	)
	record_result(
		"resource_boundary_reports_uid_and_user_load_literals",
		issue_exists(
			resource_boundary_issues,
			"direct_user_resource_load",
			target="user://cache/report.tres",
			severity="info",
		)
		and issue_exists(
			resource_boundary_issues,
			"direct_uid_resource_load",
			target="uid://fixture-resource",
			severity="warning",
		),
		f"missing uid/user resource boundary issues: {resource_boundary_issues}",
	)
	record_result(
		"resource_boundary_ignores_comments_and_plain_string_content",
		not issue_exists(resource_boundary_issues, "direct_resource_path_load", target="res://ignored/comment.tres")
		and not issue_exists(resource_boundary_issues, "direct_resource_path_load", target="res://ignored/string.tres"),
		f"comments or plain string content should not be reported as loads: {resource_boundary_issues}",
	)
	record_result(
		"resource_boundary_ignores_load_calls_inside_plain_string_content",
		not issue_exists(resource_boundary_issues, "direct_script_dependency_load", target="res://addons/gf/extensions/save_extra/example.gd"),
		f"load calls embedded inside generated source strings should not be reported: {resource_boundary_issues}",
	)
	record_result(
		"resource_boundary_source_kind_classifies_common_roots",
		resource_boundary_source_kind("addons/gf/kernel/core/gf.gd") == "runtime"
		and resource_boundary_source_kind("addons/gf/kernel/editor/gf_editor_workspace_dock.gd") == "editor"
		and resource_boundary_source_kind("addons/gf/standard/utilities/debug/editor/gf_build_info_export_plugin.gd") == "editor"
		and resource_boundary_source_kind("addons/gf/tools/config_pipeline/gf_config_pipeline.gd") == "tool"
		and resource_boundary_source_kind("tests/gf_core/kernel/test_fixture.gd") == "test",
		"resource-boundary source kinds should keep runtime/editor/tool/test observations distinct.",
	)
	resource_boundary_owner_entries = [
		{
			"package_id": "gf.kernel",
			"manifest_path": "packages/gf.kernel.json",
			"root_path": "addons/gf/plugin.cfg",
		},
		{
			"package_id": "gf.kernel",
			"manifest_path": "packages/gf.kernel.json",
			"root_path": "addons/gf/kernel",
		},
		{
			"package_id": "gf.standard.diagnostics",
			"manifest_path": "packages/gf.standard.diagnostics.json",
			"root_path": "addons/gf/standard/utilities/debug",
		},
	]
	record_result(
		"resource_boundary_source_package_classifies_manifest_owners",
		resource_boundary_source_package("addons/gf/kernel/core/gf.gd", resource_boundary_owner_entries) == "gf.kernel"
		and resource_boundary_source_package("addons/gf/standard/utilities/debug/gf_build_info.gd", resource_boundary_owner_entries) == "gf.standard.diagnostics"
		and resource_boundary_source_package("tests/gf_core/kernel/test_fixture.gd", resource_boundary_owner_entries) == "<test>"
		and resource_boundary_source_package("addons/gf/unowned/fixture.gd", resource_boundary_owner_entries) == "<unowned>"
		and resource_boundary_source_package("project/local_fixture.gd", resource_boundary_owner_entries) == "<other>"
		and resource_boundary_source_package("addons/gf/kernel/core/gf.gd", []) == "<unknown>",
		"resource-boundary source packages should come from package manifest owners when available.",
	)
	record_result(
		"resource_boundary_target_package_classifies_targets",
		resource_boundary_target_package("res://addons/gf/kernel/core/gf.gd", resource_boundary_owner_entries) == "gf.kernel"
		and resource_boundary_target_package("res://addons/gf/plugin.cfg", resource_boundary_owner_entries) == "gf.kernel"
		and resource_boundary_target_package("res://ui/panel.tscn", resource_boundary_owner_entries) == "<project>"
		and resource_boundary_target_package("user://cache/report.tres", resource_boundary_owner_entries) == "<user>"
		and resource_boundary_target_package("uid://fixture-resource", resource_boundary_owner_entries) == "<uid>"
		and resource_boundary_target_package("res://addons/gf/unowned/fixture.tres", resource_boundary_owner_entries) == "<unowned>"
		and resource_boundary_target_package("res://addons/gf/kernel/core/gf.gd", []) == "<unknown>",
		"resource-boundary target packages should classify GF packages, project resources, user paths, and UID paths.",
	)
	annotate_resource_boundary_packages(resource_boundary_issues, resource_boundary_owner_entries)
	resource_boundary_payload = make_resource_boundary_payload(
		[resource_boundary_fixture_path],
		resource_boundary_issues,
		False,
		False,
	)
	record_result(
		"resource_boundary_payload_splits_observations_from_actionable_issues",
		resource_boundary_payload["issue_count"] == 3
		and resource_boundary_payload["observation_count"] == 2
		and { "key": "runtime", "count": 3 } in resource_boundary_payload["source_kind_counts"]
		and { "key": "runtime", "count": 2 } in resource_boundary_payload["observation_source_kind_counts"]
		and { "key": "gf.kernel", "count": 3 } in resource_boundary_payload["source_package_counts"]
		and { "key": "gf.kernel", "count": 2 } in resource_boundary_payload["observation_source_package_counts"]
		and { "key": "<project>", "count": 1 } in resource_boundary_payload["target_package_counts"]
		and { "key": "<uid>", "count": 1 } in resource_boundary_payload["target_package_counts"]
		and { "key": "<user>", "count": 1 } in resource_boundary_payload["target_package_counts"]
		and { "key": "gf.kernel", "count": 2 } in resource_boundary_payload["observation_target_package_counts"]
		and {
			"key": "gf.kernel -> <project>",
			"source": "gf.kernel",
			"target": "<project>",
			"count": 1,
		} in resource_boundary_payload["source_target_package_counts"]
		and {
			"key": "gf.kernel -> gf.kernel",
			"source": "gf.kernel",
			"target": "gf.kernel",
			"count": 2,
		} in resource_boundary_payload["observation_source_target_package_counts"]
		and issue_exists(resource_boundary_payload["issues"], "direct_resource_path_load", target="res://ui/panel.tscn")
		and issue_exists(resource_boundary_payload["issues"], "direct_user_resource_load", target="user://cache/report.tres")
		and issue_exists(resource_boundary_payload["issues"], "direct_uid_resource_load", target="uid://fixture-resource")
		and resource_boundary_payload["observations"] == []
		and issue_exists(resource_boundary_payload["observation_samples"], "direct_script_dependency_load", target="res://addons/gf/kernel/core/gf.gd")
		and issue_exists(resource_boundary_payload["observation_samples"], "direct_editor_metadata_load", target="res://addons/gf/plugin.cfg"),
		f"resource-boundary payload should keep observations out of actionable issues: {resource_boundary_payload}",
	)
	resource_boundary_observation_only_findings = [
		make_resource_boundary_issue(
			resource_boundary_fixture_path,
			1,
			"preload",
			"res://addons/gf/kernel/core/gf.gd",
		),
	]
	annotate_resource_boundary_packages(
		resource_boundary_observation_only_findings,
		resource_boundary_owner_entries,
	)
	resource_boundary_observation_only_payload = make_resource_boundary_payload(
		[resource_boundary_fixture_path],
		resource_boundary_observation_only_findings,
		True,
		True,
	)
	record_result(
		"resource_boundary_strict_mode_ignores_observation_only_payloads",
		resource_boundary_observation_only_payload["ok"]
		and resource_boundary_observation_only_payload["issue_count"] == 0
		and resource_boundary_observation_only_payload["observation_count"] == 1
		and len(resource_boundary_observation_only_payload["observations"]) == 1,
		f"strict mode should fail only actionable resource issues: {resource_boundary_observation_only_payload}",
	)

	valid_content_package_data = {
		"schema_version": 1,
		"package_id": "author.base",
		"display_name": "Base",
		"version": "1.0.0",
		"content_types": ["items"],
		"dependencies": [],
		"resources": [
			{
				"key": "item.icon",
				"path": "assets/icon.tres",
				"type_hint": "Resource",
				"metadata": {
					"role": "icon",
				},
			},
		],
		"metadata": {
			"project": "fixture",
		},
	}
	valid_content_package_issues = audit_content_package_manifest_data(
		valid_content_package_data,
		"packs/base/gf_content_package.json",
	)
	record_result(
		"content_package_boundary_accepts_valid_manifest_fixture",
		len(valid_content_package_issues) == 0,
		f"valid content package fixture should pass: {valid_content_package_issues}",
	)

	invalid_content_package_data = {
		"package_id": "author.base",
		"version": "1.0.0",
		"download_url": "https://example.test/pack.zip",
		"resources": [
			{
				"key": "escape",
				"path": "../escape.tres",
			},
			{
				"key": "uid_asset",
				"path": "uid://outside-package",
			},
			{
				"key": "custom",
				"path": "assets/custom.tres",
				"download_url": "https://example.test/asset.tres",
			},
		],
	}
	invalid_content_package_issues = audit_content_package_manifest_data(
		invalid_content_package_data,
		"packs/base/gf_content_package.json",
	)
	record_result(
		"content_package_boundary_rejects_package_policy_fields_and_bad_paths",
		issue_exists(invalid_content_package_issues, "unsupported_manifest_field", field="download_url")
		and issue_exists(invalid_content_package_issues, "resource_path_outside_package", row_key="escape")
		and issue_exists(invalid_content_package_issues, "resource_path_not_allowed", row_key="uid_asset")
		and issue_exists(invalid_content_package_issues, "unsupported_resource_field", field="download_url", row_index=2),
		f"content package policy/path issues should be reported: {invalid_content_package_issues}",
	)

	content_package_graph_records = [
		{
			"path": "packs/base/gf_content_package.json",
			"package_id": "author.base",
			"dependencies": ["author.feature"],
			"resource_count": 0,
			"issues": [],
		},
		{
			"path": "packs/feature/gf_content_package.json",
			"package_id": "author.feature",
			"dependencies": ["author.base", "author.missing"],
			"resource_count": 0,
			"issues": [],
		},
	]
	content_package_graph_issues = audit_content_package_graph(content_package_graph_records)
	record_result(
		"content_package_boundary_reports_missing_dependencies_and_cycles",
		issue_exists(content_package_graph_issues, "missing_dependency", row_key="author.feature", actual_value="author.missing")
		and issue_exists(content_package_graph_issues, "dependency_cycle", actual_value="author.base -> author.feature -> author.base"),
		f"missing dependencies and cycles should be reported: {content_package_graph_issues}",
	)

	asset_lifecycle_source = "\n".join([
		"func run(asset_util: GFAssetUtility, registry: GFResourceRegistry, owner: Node) -> void:",
		"\tasset_util.load_handle_async(\"res://hero.tres\", func(_handle: GFAssetHandle) -> void:",
		"\t\tpass",
		"\t)",
		"\tasset_util.load_handle_async(\"res://owned.tres\", Callable(), \"Resource\", owner)",
		"\tasset_util.acquire_handle(\"res://grouped.tres\", null, &\"ui\", \"Resource\", Resource.new())",
		"\tregistry.request_entry_handle_async(asset_util, &\"entry\", Callable(), owner, &\"\")",
	])
	asset_lifecycle_issues = audit_asset_lifecycle_text(
		asset_lifecycle_source,
		"addons/gf/fixture.gd",
	)
	record_result(
		"asset_lifecycle_boundary_reports_ownerless_ungrouped_handles",
		issue_exists(
			asset_lifecycle_issues,
			"ownerless_ungrouped_asset_handle",
			callee="load_handle_async",
			target='"res://hero.tres"',
			severity="warning",
		),
		f"ownerless ungrouped handle should be reported: {asset_lifecycle_issues}",
	)
	record_result(
		"asset_lifecycle_boundary_accepts_owner_or_group_anchored_handles",
		not issue_exists(asset_lifecycle_issues, "ownerless_ungrouped_asset_handle", target='"res://owned.tres"')
		and not issue_exists(asset_lifecycle_issues, "ownerless_ungrouped_asset_handle", target='"res://grouped.tres"')
		and not issue_exists(asset_lifecycle_issues, "ownerless_ungrouped_asset_handle", target='&"entry"'),
		f"owner or group anchored handles should pass: {asset_lifecycle_issues}",
	)

	project_profile_paths = [
		"game/scripts/player.gd",
		"game/scenes/main.tscn",
		"game/assets/icon.png",
		"misc/debug.gd",
	]
	valid_project_profile = {
		"schema_version": 1,
		"id": "fixture",
		"zones": [
			{
				"id": "game_scripts",
				"roots": ["game/scripts"],
				"required": True,
				"allow_extensions": [".gd"],
				"severity": "error",
			},
			{
				"id": "game_assets",
				"roots": ["game/assets"],
				"allow_extensions": [".png", ".tres"],
				"severity": "warning",
			},
		],
		"rules": [
			{
				"id": "has_main_scene",
				"kind": "path_exists",
				"paths": ["game/scenes/main.tscn"],
			},
			{
				"id": "gd_under_scripts",
				"kind": "files_under_roots",
				"extensions": [".gd"],
				"roots": ["game/scripts"],
				"exclude": ["addons/**"],
				"severity": "warning",
			},
		],
		"metadata": {
			"owner": "test",
		},
	}
	valid_project_profile_issues = audit_project_profile_data(
		valid_project_profile,
		"gf_project_profile.json",
		[
			"game/scripts/player.gd",
			"game/scenes/main.tscn",
			"game/assets/icon.png",
		],
	)
	record_result(
		"project_profile_boundary_accepts_flexible_valid_profile",
		len(valid_project_profile_issues) == 0,
		f"valid project profile should pass: {valid_project_profile_issues}",
	)

	project_profile_issues = audit_project_profile_data(
		valid_project_profile,
		"gf_project_profile.json",
		project_profile_paths,
	)
	record_result(
		"project_profile_boundary_reports_selected_files_outside_declared_roots",
		issue_exists(
			project_profile_issues,
			"project_profile_file_outside_roots",
			path="misc/debug.gd",
			rule_id="gd_under_scripts",
			severity="warning",
		),
		f"selected files outside roots should be reported: {project_profile_issues}",
	)

	invalid_project_profile = {
		"schema_version": 1,
		"id": "invalid",
		"preset": "not-allowed",
		"zones": [
			{
				"id": "missing_root",
				"roots": ["missing/scripts"],
				"required": True,
				"severity": "error",
			},
			{
				"id": "scene_zone",
				"roots": ["game/scenes"],
				"deny_extensions": [".gd"],
				"severity": "warning",
			},
		],
		"rules": [
			{
				"id": "bad_kind",
				"kind": "custom_business_rule",
			},
		],
	}
	invalid_project_profile_schema_issues = audit_project_profile_schema(
		invalid_project_profile,
		"gf_project_profile.json",
	)
	invalid_project_profile_runtime_issues = audit_project_profile_data(
		{
			"schema_version": 1,
			"id": "invalid",
			"zones": invalid_project_profile["zones"],
			"rules": [],
		},
		"gf_project_profile.json",
		["game/scenes/debug.gd"],
	)
	record_result(
		"project_profile_boundary_rejects_unsupported_fields_and_rule_kinds",
		issue_exists(invalid_project_profile_schema_issues, "unsupported_project_profile_field", field="preset")
		and issue_exists(invalid_project_profile_schema_issues, "unsupported_project_profile_rule_kind", actual_value="custom_business_rule"),
		f"unsupported project profile fields and rule kinds should be reported: {invalid_project_profile_schema_issues}",
	)
	record_result(
		"project_profile_boundary_reports_missing_roots_and_denied_extensions",
		issue_exists(
			invalid_project_profile_runtime_issues,
			"project_profile_required_root_missing",
			zone_id="missing_root",
			actual_value="missing/scripts",
			severity="error",
		)
		and issue_exists(
			invalid_project_profile_runtime_issues,
			"project_profile_zone_extension_denied",
			path="game/scenes/debug.gd",
			zone_id="scene_zone",
			severity="warning",
		),
		f"missing roots and denied extensions should be reported: {invalid_project_profile_runtime_issues}",
	)

	valid_package_data = {
		"schema_version": 1,
		"id": "gf.standard.fixture",
		"kind": "standard",
		"version": "unreleased",
		"dependencies": ["gf.kernel"],
		"paths": ["addons/gf/standard/**"],
		"exclude_paths": ["addons/gf/standard/**"],
		"metadata": {},
	}
	valid_package_issues = audit_package_manifest_data(
		valid_package_data,
		"packages/gf.standard.fixture.json",
	)
	record_result(
		"package_boundary_accepts_valid_manifest_fixture",
		len(valid_package_issues) == 0,
		f"valid package manifest fixture should pass: {valid_package_issues}",
	)

	record_result(
		"package_boundary_requires_exact_gf_kind_prefix_segments",
		expected_package_kind_from_id("gf.toolkit.fixture") == ""
		and expected_package_kind_from_id("gf.standardish.fixture") == ""
		and expected_package_kind_from_id("gf.tool.fixture") == "tool",
		"package kind detection should require exact gf.<kind>. prefixes.",
	)

	invalid_package_data = {
		"schema_version": 1,
		"id": "gf.extension.bad",
		"kind": "extension",
		"version": "4.x",
		"download_url": "https://example.test/gf-extension-bad.zip",
		"registry_signature_url": "https://example.test/gf-extension-bad.zip.sig",
		"paths": ["../outside/**"],
		"exclude_paths": ["../outside/**"],
		"packages": ["gf.standard"],
	}
	invalid_package_issues = audit_package_manifest_data(
		invalid_package_data,
		"packages/gf.extension.bad.json",
	)
	record_result(
		"package_boundary_rejects_forbidden_fields_bad_version_paths_and_non_preset_packages",
		issue_exists(invalid_package_issues, "forbidden_package_manifest_field", field="download_url")
		and issue_exists(invalid_package_issues, "forbidden_package_manifest_field", field="registry_signature_url")
		and issue_exists(invalid_package_issues, "invalid_package_version", field="version")
		and issue_exists(invalid_package_issues, "invalid_package_path", field="paths", row_index=0)
		and issue_exists(invalid_package_issues, "invalid_package_exclude_path", field="exclude_paths", row_index=0)
		and issue_exists(invalid_package_issues, "non_preset_declares_packages", field="packages"),
		f"invalid package manifest issues should be reported: {invalid_package_issues}",
	)

	package_graph_records = [
		{
			"path": "packages/gf.kernel.json",
			"id": "gf.kernel",
			"kind": "kernel",
			"dependencies": [],
			"packages": [],
			"paths": ["addons/gf/kernel/**"],
			"issues": [],
		},
		{
			"path": "packages/gf.standard.a.json",
			"id": "gf.standard.a",
			"kind": "standard",
			"dependencies": ["gf.standard.b"],
			"packages": [],
			"paths": ["addons/gf/standard/a/**"],
			"issues": [],
		},
		{
			"path": "packages/gf.standard.b.json",
			"id": "gf.standard.b",
			"kind": "standard",
			"dependencies": ["gf.standard.a"],
			"packages": [],
			"paths": ["addons/gf/standard/b/**"],
			"issues": [],
		},
		{
			"path": "packages/extensions/gf.extension.save.json",
			"id": "gf.extension.save",
			"kind": "extension",
			"dependencies": ["gf.extension.dialogue", "gf.standard.missing"],
			"packages": [],
			"paths": ["addons/gf/extensions/save/**"],
			"issues": [],
		},
		{
			"path": "packages/extensions/gf.extension.dialogue.json",
			"id": "gf.extension.dialogue",
			"kind": "extension",
			"dependencies": ["gf.kernel"],
			"packages": [],
			"paths": ["addons/gf/extensions/dialogue/**"],
			"issues": [],
		},
		{
			"path": "packages/extensions/gf.extension.bad_tool_dep.json",
			"id": "gf.extension.bad_tool_dep",
			"kind": "extension",
			"dependencies": ["gf.tool.fixture"],
			"packages": [],
			"paths": ["addons/gf/extensions/bad_tool_dep/**"],
			"issues": [],
		},
		{
			"path": "packages/tools/gf.tool.fixture.json",
			"id": "gf.tool.fixture",
			"kind": "tool",
			"dependencies": ["gf.kernel", "gf.standard.a", "gf.extension.dialogue"],
			"packages": [],
			"paths": ["addons/gf/tools/fixture/**"],
			"issues": [],
		},
		{
			"path": "packages/tools/gf.tool.depends_tool.json",
			"id": "gf.tool.depends_tool",
			"kind": "tool",
			"dependencies": ["gf.tool.fixture"],
			"packages": [],
			"paths": ["addons/gf/tools/depends_tool/**"],
			"issues": [],
		},
	]
	package_graph_issues = audit_package_manifest_graph(package_graph_records)
	record_result(
		"package_boundary_reports_missing_forbidden_tool_and_cyclic_dependencies",
		issue_exists(package_graph_issues, "missing_package_dependency", row_key="gf.extension.save", actual_value="gf.standard.missing")
		and issue_exists(package_graph_issues, "forbidden_package_dependency", row_key="gf.extension.save", actual_value="gf.extension.dialogue")
		and issue_exists(package_graph_issues, "forbidden_package_dependency", row_key="gf.extension.bad_tool_dep", actual_value="gf.tool.fixture")
		and issue_exists(package_graph_issues, "forbidden_package_dependency", row_key="gf.tool.depends_tool", actual_value="gf.tool.fixture")
		and not issue_exists(package_graph_issues, "forbidden_package_dependency", row_key="gf.tool.fixture", actual_value="gf.extension.dialogue")
		and issue_exists(package_graph_issues, "package_dependency_cycle", actual_value="gf.standard.a -> gf.standard.b -> gf.standard.a"),
		f"package graph issues should be reported: {package_graph_issues}",
	)

	package_overlap_issues = audit_package_path_ownership([
		{
			"path": "packages/gf.kernel.json",
			"id": "gf.kernel",
			"kind": "kernel",
			"paths": ["addons/gf/kernel/**"],
		},
		{
			"path": "packages/gf.tool.fixture.json",
			"id": "gf.tool.fixture",
			"kind": "tool",
			"paths": ["addons/gf/kernel/editor/**"],
		},
	])
	record_result(
		"package_boundary_reports_overlapping_owned_paths",
		issue_exists(package_overlap_issues, "package_path_overlap", row_key="gf.kernel")
		and issue_exists(package_overlap_issues, "package_path_overlap", row_key="gf.tool.fixture"),
		f"overlapping package paths should be reported: {package_overlap_issues}",
	)

	package_closure_records = [
		{
			"path": "packages/gf.kernel.json",
			"id": "gf.kernel",
			"kind": "kernel",
			"dependencies": [],
			"packages": [],
			"paths": ["addons/gf/kernel/**"],
			"issues": [],
		},
		{
			"path": "packages/standard/gf.standard.base.json",
			"id": "gf.standard.base",
			"kind": "standard",
			"dependencies": ["gf.kernel"],
			"packages": [],
			"paths": ["addons/gf/standard/base/**"],
			"issues": [],
		},
		{
			"path": "packages/standard/gf.standard.assets.json",
			"id": "gf.standard.assets",
			"kind": "standard",
			"dependencies": ["gf.kernel", "gf.standard.base"],
			"packages": [],
			"paths": ["addons/gf/standard/assets/**"],
			"issues": [],
		},
		{
			"path": "packages/standard/gf.standard.audio.json",
			"id": "gf.standard.audio",
			"kind": "standard",
			"dependencies": ["gf.kernel", "gf.standard.assets"],
			"packages": [],
			"paths": ["addons/gf/standard/audio/**"],
			"issues": [],
		},
		{
			"path": "packages/standard/gf.standard.state.json",
			"id": "gf.standard.state",
			"kind": "standard",
			"dependencies": ["gf.kernel", "gf.standard.base"],
			"packages": [],
			"paths": ["addons/gf/standard/state/**"],
			"issues": [],
		},
		{
			"path": "packages/standard/gf.standard.storage.json",
			"id": "gf.standard.storage",
			"kind": "standard",
			"dependencies": ["gf.kernel", "gf.standard.base"],
			"packages": [],
			"paths": ["addons/gf/standard/storage/**"],
			"issues": [],
		},
		{
			"path": "packages/standard/gf.standard.ui.json",
			"id": "gf.standard.ui",
			"kind": "standard",
			"dependencies": ["gf.kernel", "gf.standard.base", "gf.standard.assets", "gf.standard.audio", "gf.standard.state", "gf.standard.storage"],
			"packages": [],
			"paths": ["addons/gf/standard/ui/**"],
			"issues": [],
		},
		{
			"path": "packages/standard/gf.standard.debug.json",
			"id": PACKAGE_CLOSURE_DEBUG_PACKAGE_ID,
			"kind": "standard",
			"dependencies": ["gf.kernel", "gf.standard.base", "gf.standard.assets", "gf.standard.audio", "gf.standard.state", "gf.standard.storage", "gf.standard.ui"],
			"packages": [],
			"paths": ["addons/gf/standard/debug/**"],
			"issues": [],
		},
		{
			"path": "packages/standard/gf.standard.editor.json",
			"id": PACKAGE_CLOSURE_EDITOR_PACKAGE_ID,
			"kind": "standard",
			"dependencies": ["gf.kernel", "gf.standard.base"],
			"packages": [],
			"paths": ["addons/gf/standard/editor/**"],
			"issues": [],
		},
		{
			"path": "packages/extensions/gf.extension.heavy.json",
			"id": "gf.extension.heavy",
			"kind": "extension",
			"dependencies": ["gf.kernel", "gf.standard.base", PACKAGE_CLOSURE_DEBUG_PACKAGE_ID],
			"packages": [],
			"paths": ["addons/gf/extensions/heavy/**"],
			"issues": [],
		},
		{
			"path": "packages/extensions/gf.extension.bad_editor.json",
			"id": "gf.extension.bad_editor",
			"kind": "extension",
			"dependencies": ["gf.kernel", PACKAGE_CLOSURE_EDITOR_PACKAGE_ID],
			"packages": [],
			"paths": ["addons/gf/extensions/bad_editor/**"],
			"issues": [],
		},
	]
	package_closure_rows = collect_package_closure_rows(package_closure_records)
	package_closure_issues = audit_package_closure_rows(package_closure_records, package_closure_rows)
	heavy_closure = next(
		(row for row in package_closure_rows if row.get("package_id") == "gf.extension.heavy"),
		{},
	)
	record_result(
		"package_closure_audit_reports_large_debug_and_editor_closure_risks",
		(
			heavy_closure.get("closure_count") == 9
			and heavy_closure.get("standard_count") == 7
			and issue_exists(package_closure_issues, "package_extension_debug_dependency", row_key="gf.extension.heavy", severity="warning")
			and issue_exists(package_closure_issues, "package_extension_large_closure", row_key="gf.extension.heavy", severity="warning")
			and issue_exists(package_closure_issues, "package_debug_ui_closure", row_key=PACKAGE_CLOSURE_DEBUG_PACKAGE_ID, severity="warning")
			and issue_exists(package_closure_issues, "package_extension_editor_closure", row_key="gf.extension.bad_editor", severity="error")
		),
		f"closure risks should be reported: rows={package_closure_rows} issues={package_closure_issues}",
	)
	package_closure_fan_in = collect_package_standard_fan_in(package_closure_records, package_closure_rows)
	base_fan_in = next(
		(item for item in package_closure_fan_in if item.get("package_id") == "gf.standard.base"),
		{},
	)
	record_result(
		"package_closure_audit_records_standard_fan_in",
		base_fan_in.get("dependent_count", 0) >= 8
		and "gf.extension.heavy" in base_fan_in.get("dependents", []),
		f"standard fan-in should include transitive dependents: {package_closure_fan_in}",
	)

	package_external_command_issues = audit_package_external_command_source(
		"\n".join([
			"func run(url: String) -> void:",
			"\tOS.execute(\"python\", PackedStringArray(), [], true, false)",
			"\tOS.shell_open(url)",
			"\t# OS.execute(\"git\", [])",
		]),
		"addons/gf/extensions/fixture/gf_fixture.gd",
		"gf.extension.fixture",
	)
	record_result(
		"package_external_command_audit_reports_process_calls",
		issue_exists(
			package_external_command_issues,
			"package_external_process_call",
			row_key="gf.extension.fixture",
			api="OS.execute",
			command="python",
			severity="warning",
		)
		and issue_exists(
			package_external_command_issues,
			"package_external_process_call",
			row_key="gf.extension.fixture",
			api="OS.shell_open",
			severity="warning",
		)
		and not issue_exists(package_external_command_issues, "package_external_process_call", command="git"),
		f"external process calls should be reported while comments stay ignored: {package_external_command_issues}",
	)
	package_git_command_issues = audit_package_external_command_source(
		"func collect() -> void:\n\tOS.execute(\"git\", PackedStringArray(), [], true, false)",
		"addons/gf/standard/utilities/debug/gf_build_info.gd",
		"gf.standard.diagnostics",
	)
	record_result(
		"package_external_command_audit_marks_package_git_as_warning",
		issue_exists(
			package_git_command_issues,
			"package_external_process_call",
			row_key="gf.standard.diagnostics",
			api="OS.execute",
			command="git",
			severity="warning",
		),
		f"package git process calls should be warnings: {package_git_command_issues}",
	)
	package_editor_shell_open_issues = audit_package_external_command_source(
		"func open(url: String) -> void:\n\tOS.shell_open(url)",
		"addons/gf/kernel/editor/gf_editor_workspace_dock.gd",
		"gf.kernel",
	)
	record_result(
		"package_external_command_audit_allows_declared_editor_shell_open",
		package_editor_shell_open_issues == [],
		f"declared editor shell_open calls should be allowlisted: {package_editor_shell_open_issues}",
	)
	record_result(
		"package_external_command_audit_report_only_and_strict_modes",
		make_package_external_command_audit_payload([], ["addons/gf/extensions/fixture/gf_fixture.gd"], package_external_command_issues, False)["ok"]
		and not make_package_external_command_audit_payload([], ["addons/gf/extensions/fixture/gf_fixture.gd"], package_external_command_issues, True)["ok"],
		"report-only mode should pass warnings while strict mode can promote the same baseline to a gate.",
	)

	record_result(
		"package_godot_smoke_normalizes_selected_package_ids",
		normalize_package_godot_smoke_package_ids([" gf.standard.base ", "", "gf.standard.base", "gf.kernel"])
		== ["gf.standard.base", "gf.kernel"],
		"selected package ids should be trimmed, de-duplicated, and kept in user order.",
	)
	expected_default_all_jobs = max(1, min(PACKAGE_GODOT_SMOKE_DEFAULT_ALL_PACKAGE_JOBS, os.cpu_count() or 1))
	record_result(
		"package_godot_smoke_job_count_defaults_are_bounded",
		package_godot_smoke_job_count("all", 0) == expected_default_all_jobs
		and package_godot_smoke_job_count("representative", 0) == 1
		and package_godot_smoke_job_count("selected", 0) == 1
		and package_godot_smoke_job_count("all", 2) == 2,
		"package Godot smoke should parallelize all-package mode by default while keeping focused modes serial.",
	)

	bad_core_plugin_source = "\n".join([
		"const BadStandard = preload(\"res://addons/gf/standard/editor/gf_standard_editor_extensions.gd\")",
		"func run() -> void:",
		"\tGFVariantData.get_option_array({})",
	])
	bad_core_only_issues = audit_core_only_plugin_source(
		bad_core_plugin_source,
		"addons/gf/plugin.gd",
		{"GFVariantData": "addons/gf/standard/foundation/variant/gf_variant_data.gd"},
	)
	record_result(
		"core_only_smoke_rejects_standard_preload_and_standard_class_reference",
		issue_exists(bad_core_only_issues, "plugin_preloads_standard")
		and issue_exists(bad_core_only_issues, "plugin_references_standard_class", symbol="GFVariantData"),
		f"standard parse-time references should be reported: {bad_core_only_issues}",
	)

	current_core_only_issues = audit_core_only_plugin_source(
		read_text_file(ROOT / "addons/gf/plugin.gd"),
		"addons/gf/plugin.gd",
		collect_class_name_roots(GF_STANDARD_ROOT),
	)
	record_result(
		"core_only_smoke_accepts_current_root_plugin_entry",
		len(current_core_only_issues) == 0,
		f"root plugin should not require standard at parse time: {current_core_only_issues}",
	)

	package_source_records = [
		{
			"path": "packages/gf.kernel.json",
			"id": "gf.kernel",
			"kind": "kernel",
			"dependencies": [],
			"paths": [
				"addons/gf/plugin.gd",
				"addons/gf/kernel/**",
			],
			"issues": [],
		},
		{
			"path": "packages/gf.standard.base.json",
			"id": "gf.standard.base",
			"kind": "standard",
			"dependencies": ["gf.kernel"],
			"paths": ["addons/gf/standard/base/**"],
			"issues": [],
		},
		{
			"path": "packages/gf.standard.ui.json",
			"id": "gf.standard.ui",
			"kind": "standard",
			"dependencies": ["gf.kernel", "gf.standard.base"],
			"paths": ["addons/gf/standard/ui/**"],
			"issues": [],
		},
		{
			"path": "packages/extensions/gf.extension.alpha.json",
			"id": "gf.extension.alpha",
			"kind": "extension",
			"dependencies": ["gf.kernel", "gf.standard.ui"],
			"paths": ["addons/gf/extensions/alpha/**"],
			"issues": [],
		},
		{
			"path": "packages/extensions/gf.extension.beta.json",
			"id": "gf.extension.beta",
			"kind": "extension",
			"dependencies": ["gf.kernel"],
			"paths": ["addons/gf/extensions/beta/**"],
			"issues": [],
		},
	]
	package_source_class_roots = {
		"GFBaseThing": "addons/gf/standard/base/base_thing.gd",
		"GFStandardWidget": "addons/gf/standard/ui/widget.gd",
		"GFBetaThing": "addons/gf/extensions/beta/beta_thing.gd",
	}
	package_source_allowed_issues = audit_package_source_references(
		package_source_records,
		["addons/gf/standard/ui/widget.gd"],
		package_source_class_roots,
		{
			"addons/gf/standard/ui/widget.gd": "\n".join([
				"class_name GFStandardWidget",
				"const _BASE = preload(\"res://addons/gf/standard/base/base_thing.gd\")",
				"var base: GFBaseThing",
			]),
		},
	)
	record_result(
		"package_source_boundary_allows_declared_package_references",
		len(package_source_allowed_issues) == 0,
		f"declared package references should pass: {package_source_allowed_issues}",
	)

	package_source_invalid_issues = audit_package_source_references(
		package_source_records,
		["addons/gf/extensions/alpha/feature.gd"],
		package_source_class_roots,
		{
			"addons/gf/extensions/alpha/feature.gd": "\n".join([
				"class_name GFAlphaFeature",
				"const _BETA = preload(\"res://addons/gf/extensions/beta/beta_thing.gd\")",
				"var beta: GFBetaThing",
			]),
		},
	)
	record_result(
		"package_source_boundary_rejects_undeclared_path_and_class_dependencies",
		issue_exists(
			package_source_invalid_issues,
			"package_source_undeclared_path_dependency",
			row_key="gf.extension.alpha",
			target="addons/gf/extensions/beta/beta_thing.gd",
			expected_value="gf.extension.beta",
		)
		and issue_exists(
			package_source_invalid_issues,
			"package_source_undeclared_class_dependency",
			row_key="gf.extension.alpha",
			symbol="GFBetaThing",
			target="addons/gf/extensions/beta/beta_thing.gd",
			expected_value="gf.extension.beta",
		),
		f"undeclared package references should be reported: {package_source_invalid_issues}",
	)

	package_source_optional_records = [
		{
			"path": "packages/gf.kernel.json",
			"id": "gf.kernel",
			"kind": "kernel",
			"dependencies": [],
			"paths": [
				"addons/gf/plugin.gd",
				"addons/gf/kernel/**",
			],
			"issues": [],
		},
		{
			"path": "packages/gf.standard.json",
			"id": "gf.standard",
			"kind": "standard",
			"dependencies": ["gf.kernel"],
			"paths": ["addons/gf/standard/**"],
			"issues": [],
		},
	]
	package_source_optional_issues = audit_package_source_references(
		package_source_optional_records,
		[
			"addons/gf/plugin.gd",
			"addons/gf/kernel/extension/gf_extension_catalog.gd",
		],
		package_source_class_roots,
		{
			"addons/gf/plugin.gd": (
				"const STANDARD_EDITOR_EXTENSIONS_SCRIPT_PATH: String = "
				"\"res://addons/gf/standard/editor/gf_standard_editor_extensions.gd\""
			),
			"addons/gf/kernel/extension/gf_extension_catalog.gd": (
				"const EXTENSIONS_PATH: String = \"res://addons/gf/extensions\""
			),
		},
	)
	record_result(
		"package_source_boundary_allows_narrow_kernel_optional_discovery",
		len(package_source_optional_issues) == 0,
		f"narrow optional discovery references should pass: {package_source_optional_issues}",
	)

	with tempfile.TemporaryDirectory(prefix="gf-package-build-self-test-") as temp_dir:
		registry_path = Path(temp_dir) / "registry/index.json"
		registry_path.parent.mkdir(parents=True, exist_ok=True)
		registry_path.write_text(json.dumps({
			"schema_version": PACKAGE_REGISTRY_SCHEMA_VERSION,
			"framework_version": "unreleased",
			"minimum_framework_version": "unreleased",
			"maximum_framework_version_exclusive": "",
			"packages": {
				"gf.kernel": {
					"minimum_framework_version": "unreleased",
					"maximum_framework_version_exclusive": "",
					"archive": "../packages/gf-kernel-unreleased.zip",
					"sha256": "not-the-archive-sha",
					"size_bytes": 123,
					"signature_url": "../packages/gf-kernel-unreleased.zip.sig",
				},
			},
		}), encoding="utf-8")
		package_build_issues = audit_package_build_result(
			{
				"ok": True,
				"packages": [
					{
						"ok": True,
						"id": "gf.kernel",
						"archive": str(Path(temp_dir) / "packages/gf-kernel-unreleased.zip"),
						"sha256": "builder-sha",
						"size_bytes": 456,
						"issues": [],
					}
				],
				"issues": [],
			},
			registry_path,
		)
	record_result(
		"package_build_boundary_reports_missing_archive_and_registry_mismatch",
		issue_exists(package_build_issues, "package_archive_missing", row_key="gf.kernel")
		and issue_exists(package_build_issues, "package_registry_sha256_mismatch", row_key="gf.kernel")
		and issue_exists(package_build_issues, "package_registry_size_mismatch", row_key="gf.kernel")
		and issue_exists(package_build_issues, "package_registry_signature_field", row_key="gf.kernel", field="signature_url"),
		f"package build archive and registry mismatches should be reported: {package_build_issues}",
	)

	with tempfile.TemporaryDirectory(prefix="gf-package-build-tool-self-test-") as temp_dir:
		archive_path = Path(temp_dir) / "packages/gf-kernel-unreleased.zip"
		archive_path.parent.mkdir(parents=True, exist_ok=True)
		with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
			archive.writestr("addons/gf/plugin.gd", "# fixture\n")
			archive.writestr("addons/gf/kernel/package_tools/gf_package_installer.py", "# fixture\n")
		registry_path = Path(temp_dir) / "registry/index.json"
		registry_path.parent.mkdir(parents=True, exist_ok=True)
		registry_path.write_text(json.dumps({
			"schema_version": PACKAGE_REGISTRY_SCHEMA_VERSION,
			"framework_version": "unreleased",
			"minimum_framework_version": "unreleased",
			"maximum_framework_version_exclusive": "",
			"packages": {
				"gf.kernel": {
					"minimum_framework_version": "unreleased",
					"maximum_framework_version_exclusive": "",
					"archive": "../packages/gf-kernel-unreleased.zip",
					"sha256": sha256_path(archive_path),
					"size_bytes": archive_path.stat().st_size,
				},
			},
		}), encoding="utf-8")
		package_tool_archive_issues = audit_package_build_result(
			{
				"ok": True,
				"packages": [
					{
						"ok": True,
						"id": "gf.kernel",
						"archive": str(archive_path),
						"sha256": sha256_path(archive_path),
						"size_bytes": archive_path.stat().st_size,
						"issues": [],
					}
				],
				"issues": [],
			},
			registry_path,
		)
	record_result(
		"package_build_boundary_rejects_kernel_python_package_tools",
		issue_exists(package_tool_archive_issues, "kernel_archive_contains_package_tool", row_key="gf.kernel"),
		f"kernel package tools should be rejected from shipped gf.kernel archives: {package_tool_archive_issues}",
	)

	with tempfile.TemporaryDirectory(prefix="gf-package-build-external-tool-self-test-") as temp_dir:
		archive_path = Path(temp_dir) / "packages/gf-extension-save-unreleased.zip"
		archive_path.parent.mkdir(parents=True, exist_ok=True)
		with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
			archive.writestr("addons/gf/extensions/save/gf_save.gd", "# fixture\n")
			archive.writestr("addons/gf/extensions/save/install.py", "# fixture\n")
			archive.writestr("addons/gf/extensions/save/package.json", "{}\n")
		registry_path = Path(temp_dir) / "registry/index.json"
		registry_path.parent.mkdir(parents=True, exist_ok=True)
		registry_path.write_text(json.dumps({
			"schema_version": PACKAGE_REGISTRY_SCHEMA_VERSION,
			"framework_version": "unreleased",
			"minimum_framework_version": "unreleased",
			"maximum_framework_version_exclusive": "",
			"packages": {
				"gf.extension.save": {
					"minimum_framework_version": "unreleased",
					"maximum_framework_version_exclusive": "",
					"archive": "../packages/gf-extension-save-unreleased.zip",
					"sha256": sha256_path(archive_path),
					"size_bytes": archive_path.stat().st_size,
				},
			},
		}), encoding="utf-8")
		external_tool_archive_issues = audit_package_build_result(
			{
				"ok": True,
				"packages": [
					{
						"ok": True,
						"id": "gf.extension.save",
						"archive": str(archive_path),
						"sha256": sha256_path(archive_path),
						"size_bytes": archive_path.stat().st_size,
						"issues": [],
					}
				],
				"issues": [],
			},
			registry_path,
		)
	record_result(
		"package_build_boundary_rejects_runtime_external_tool_payload",
		issue_exists(external_tool_archive_issues, "runtime_package_external_tool_payload", row_key="gf.extension.save"),
		f"runtime package archives should reject Python/npm/shell payloads: {external_tool_archive_issues}",
	)

	with tempfile.TemporaryDirectory(prefix="gf-package-source-signature-self-test-") as temp_dir:
		registry_path = Path(temp_dir) / "registry/index.json"
		registry_source_path = Path(temp_dir) / "registry/gf-registry-source.json"
		registry_path.parent.mkdir(parents=True, exist_ok=True)
		registry_path.write_text(json.dumps({
			"schema_version": PACKAGE_REGISTRY_SCHEMA_VERSION,
			"framework_version": "1.2.3",
			"minimum_framework_version": "1.2.3",
			"maximum_framework_version_exclusive": "2.0.0",
			"packages": {},
		}), encoding="utf-8")
		registry_source_path.write_text(json.dumps({
			"schema_version": 1,
			"default_channel": "stable",
			"channels": {
				"stable": {
					"registry": "index.json",
					"registry_sha256": sha256_path(registry_path),
					"registry_size_bytes": registry_path.stat().st_size,
					"registry_signature_url": "gf-registry-1.2.3.json.sig",
					"mirrors": [],
				},
			},
		}), encoding="utf-8")
		package_source_signature_issues = audit_package_build_registry_source_manifest(
			registry_source_path,
			registry_path,
		)
	record_result(
		"package_build_boundary_rejects_registry_source_signature_fields_without_verification",
		issue_exists(
			package_source_signature_issues,
			"package_registry_source_signature_field",
			row_key="stable",
			field="registry_signature_url",
		),
		f"registry source signature fields should be rejected until native verification exists: {package_source_signature_issues}",
	)

	with tempfile.TemporaryDirectory(prefix="gf-release-package-registry-self-test-") as temp_dir:
		registry_path = Path(temp_dir) / "gf-registry-1.2.3.json"
		registry_path.write_text(json.dumps({
			"schema_version": PACKAGE_REGISTRY_SCHEMA_VERSION,
			"framework_version": "unreleased",
			"minimum_framework_version": "unreleased",
			"maximum_framework_version_exclusive": "",
			"packages": {
				"gf.kernel": {
					"version": "unreleased",
					"kind": "kernel",
					"minimum_framework_version": "unreleased",
					"maximum_framework_version_exclusive": "",
					"archive": "https://example.invalid/gf-kernel-unreleased.zip",
					"sha256": "0" * 64,
					"size_bytes": 1,
					"signature_url": "https://example.invalid/gf-kernel-unreleased.zip.sig",
				},
			},
		}), encoding="utf-8")
		release_registry_issues = audit_release_package_registry_metadata(
			{
				"packages": [
					{
						"id": "gf.kernel",
						"kind": "kernel",
						"archive": str(Path(temp_dir) / "packages/gf-kernel-1.2.3.zip"),
					},
				],
			},
			registry_path,
			"1.2.3",
			release_package_archive_base_url("1.2.3"),
		)
	record_result(
		"release_package_registry_rejects_unversioned_release_urls",
		any("framework_version" in issue for issue in release_registry_issues)
		and any("version is" in issue for issue in release_registry_issues)
		and any("archive must use release download base" in issue for issue in release_registry_issues)
		and any("registry package signature field is not supported" in issue for issue in release_registry_issues),
		f"release package registry issues should include version and archive URL problems: {release_registry_issues}",
	)

	with tempfile.TemporaryDirectory(prefix="gf-release-package-source-self-test-") as temp_dir:
		registry_source_path = Path(temp_dir) / "gf-registry-source.json"
		registry_path = Path(temp_dir) / "gf-registry-1.2.3.json"
		registry_path.write_text(json.dumps({
			"schema_version": PACKAGE_REGISTRY_SCHEMA_VERSION,
			"framework_version": "1.2.3",
			"minimum_framework_version": "1.2.3",
			"maximum_framework_version_exclusive": "2.0.0",
			"packages": {},
		}), encoding="utf-8")
		registry_source_path.write_text(json.dumps({
			"schema_version": 1,
			"default_channel": "stable",
			"channels": {
				"stable": {
					"registry": "https://example.invalid/gf-registry-unreleased.json",
					"registry_signature_url": "gf-registry-unreleased.json.sig",
					"mirrors": [" "],
				},
			},
		}), encoding="utf-8")
		release_registry_source_issues = audit_release_package_registry_source_manifest(
			registry_source_path,
			"1.2.3",
			release_package_registry_url("1.2.3"),
			registry_path,
		)
	record_result(
		"release_package_registry_source_rejects_unversioned_registry_url",
		any("stable registry is" in issue for issue in release_registry_source_issues)
		and any("release version 1.2.3" in issue for issue in release_registry_source_issues)
		and any("registry_sha256 must match" in issue for issue in release_registry_source_issues)
		and any("registry_size_bytes must match" in issue for issue in release_registry_source_issues)
		and any("signature field is not supported" in issue for issue in release_registry_source_issues)
		and any("mirrors must contain non-empty strings" in issue for issue in release_registry_source_issues),
		f"release package registry source issues should include registry URL, integrity, and mirror problems: {release_registry_source_issues}",
	)

	with tempfile.TemporaryDirectory(prefix="gf-release-offline-bundle-self-test-") as temp_dir:
		registry_path = Path(temp_dir) / "registry/index.json"
		registry_source_path = Path(temp_dir) / "registry/gf-registry-source.json"
		offline_bundle_path = Path(temp_dir) / "gf-package-offline-bundle-1.2.3.zip"
		registry_path.parent.mkdir(parents=True, exist_ok=True)
		registry_path.write_text(json.dumps({
			"schema_version": PACKAGE_REGISTRY_SCHEMA_VERSION,
			"framework_version": "1.2.3",
			"minimum_framework_version": "1.2.3",
			"maximum_framework_version_exclusive": "2.0.0",
			"packages": {
				"gf.kernel": {
					"version": "1.2.3",
					"kind": "kernel",
					"minimum_framework_version": "1.2.3",
					"maximum_framework_version_exclusive": "2.0.0",
					"archive": "https://example.invalid/gf-kernel-1.2.3.zip",
					"sha256": "0" * 64,
					"size_bytes": 1,
				},
			},
		}), encoding="utf-8")
		registry_source_path.write_text(json.dumps({
			"schema_version": 1,
			"default_channel": "stable",
			"channels": {
				"stable": {
					"registry": "https://example.invalid/gf-registry-1.2.3.json",
					"registry_sha256": sha256_path(registry_path),
					"registry_size_bytes": registry_path.stat().st_size,
					"mirrors": [],
				},
			},
		}), encoding="utf-8")
		release_offline_bundle_issues = audit_release_package_offline_bundle_metadata(
			{"offline_bundle": str(offline_bundle_path)},
			registry_path,
			registry_source_path,
			offline_bundle_path,
			"1.2.3",
		)
	record_result(
		"release_offline_bundle_rejects_remote_registry_references",
		any("archive must be a local relative path" in issue for issue in release_offline_bundle_issues)
		and any("registry source must point to the bundled local registry" in issue for issue in release_offline_bundle_issues),
		f"release offline bundle should reject remote registry/archive references: {release_offline_bundle_issues}",
	)

	public_api_allowed_issues = audit_public_api_boundary_text(
		"class_name GFDeterministicRandom\nclass_name GFGraphPathSearchState",
		"addons/gf/fixture.gd",
	)
	record_result(
		"public_api_boundary_allows_mechanism_class_names",
		len(public_api_allowed_issues) == 0,
		f"mechanism class names should pass: {public_api_allowed_issues}",
	)

	public_api_forbidden_issues = audit_public_api_boundary_text(
		"class_name GFPathfinding2D\n<class name=\"GFDeterministicMath\" />",
		"addons/gf/fixture.gd",
	)
	record_result(
		"public_api_boundary_rejects_planning_track_names",
		issue_exists(public_api_forbidden_issues, "forbidden_public_api_route_name", symbol="GFPathfinding2D")
		and issue_exists(public_api_forbidden_issues, "forbidden_public_api_route_name", symbol="GFDeterministicMath"),
		"planning track names must not become source/API reference names.",
	)

	api_base_snapshot = {
		"classes": {
			"GFStable": make_api_snapshot_class(
				"GFStable",
				"RefCounted",
				{
					"method:kept": make_api_snapshot_member("method", "kept", "func kept() -> int:"),
					"method:removed": make_api_snapshot_member("method", "removed", "func removed() -> void:"),
					"method:changed": make_api_snapshot_member("method", "changed", "func changed() -> int:"),
				},
			),
			"GFRemoved": make_api_snapshot_class("GFRemoved", "RefCounted", {}),
			"GFExtendsChanged": make_api_snapshot_class("GFExtendsChanged", "RefCounted", {}),
		},
	}
	api_current_snapshot = {
		"classes": {
			"GFStable": make_api_snapshot_class(
				"GFStable",
				"RefCounted",
				{
					"method:kept": make_api_snapshot_member("method", "kept", "func kept() -> int:"),
					"method:changed": make_api_snapshot_member("method", "changed", "func changed() -> String:"),
					"method:added": make_api_snapshot_member("method", "added", "func added() -> void:"),
				},
			),
			"GFAdded": make_api_snapshot_class("GFAdded", "RefCounted", {}),
			"GFExtendsChanged": make_api_snapshot_class("GFExtendsChanged", "Object", {}),
		},
	}
	api_catalog_diff = compare_api_catalog_snapshots(api_base_snapshot, api_current_snapshot)
	classified_api_catalog_diff = classify_api_signature_changes(api_catalog_diff["signature_changes"])
	record_result(
		"api_baseline_diff_reports_class_and_member_changes",
		len(api_catalog_diff["added_classes"]) == 1
		and len(api_catalog_diff["removed_classes"]) == 1
		and len(api_catalog_diff["added_members"]) == 1
		and len(api_catalog_diff["removed_members"]) == 1
		and len(api_catalog_diff["signature_changes"]) == 1
		and len(classified_api_catalog_diff["breaking"]) == 1
		and len(api_catalog_diff["extends_changes"]) == 1,
		f"unexpected api catalog diff fixture result: {api_catalog_diff}",
	)
	api_compatible_base_snapshot = {
		"classes": {
			"GFStable": make_api_snapshot_class(
				"GFStable",
				"RefCounted",
				{
					"method:with_optional": make_api_snapshot_member(
						"method",
						"with_optional",
						"func with_optional(value: int) -> void:",
					),
					"method:widen": make_api_snapshot_member(
						"method",
						"widen",
						"func widen(rng: RandomNumberGenerator = null) -> void:",
					),
					"enum:Mode": make_api_snapshot_member("enum", "Mode", "enum Mode { A, B, }"),
				},
			),
		},
	}
	api_compatible_current_snapshot = {
		"classes": {
			"GFStable": make_api_snapshot_class(
				"GFStable",
				"RefCounted",
				{
					"method:with_optional": make_api_snapshot_member(
						"method",
						"with_optional",
						"func with_optional(value: int, options: Dictionary = {}) -> void:",
					),
					"method:widen": make_api_snapshot_member(
						"method",
						"widen",
						"func widen(rng: Variant = null) -> void:",
					),
					"enum:Mode": make_api_snapshot_member("enum", "Mode", "enum Mode { A, B, C, }"),
				},
			),
		},
	}
	api_compatible_diff = compare_api_catalog_snapshots(
		api_compatible_base_snapshot,
		api_compatible_current_snapshot,
	)
	classified_api_compatible_diff = classify_api_signature_changes(api_compatible_diff["signature_changes"])
	record_result(
		"api_baseline_diff_classifies_compatible_signature_changes",
		len(classified_api_compatible_diff["breaking"]) == 0
		and len(classified_api_compatible_diff["compatible"]) == 3,
		f"compatible signature changes should not count as breaking: {classified_api_compatible_diff}",
	)
	record_result(
		"api_baseline_diff_requires_major_for_breaking_changes",
		not api_diff_breaking_allowed("4.4.0", "4.5.0")
		and api_diff_breaking_allowed("4.4.0", "5.0.0"),
		"breaking API baseline changes should require a major version bump.",
	)

	project_extension_enabled_issues = audit_project_extension_settings_source(
		"[gf]\nextensions/enabled=Array[String]([\"gf.save\"])",
		"project.godot",
	)
	record_result(
		"dependency_boundary_rejects_framework_project_default_enabled_extensions",
		issue_exists(project_extension_enabled_issues, "project_extensions_enabled_by_default"),
		"framework project defaults must not enable optional bundled extensions.",
	)

	project_extension_empty_issues = audit_project_extension_settings_source(
		"[gf]\nextensions/enabled=Array[String]([])",
		"project.godot",
	)
	record_result(
		"dependency_boundary_accepts_empty_framework_project_extensions",
		len(project_extension_empty_issues) == 0,
		f"empty framework extension defaults should pass: {project_extension_empty_issues}",
	)

	return {
		"ok": len(failures) == 0,
		"root": str(ROOT),
		"test_count": len(tests),
		"failure_count": len(failures),
		"tests": tests,
		"failures": failures,
	}


def make_manifest_test_data(**overrides: Any) -> dict[str, Any]:
	data: dict[str, Any] = {
		"id": "gf.fixture",
		"display_name": "Fixture",
		"description": "Maintenance self-test fixture.",
		"kind": "extension",
		"version": "0.0.0",
		"extension_version": "1.0.0",
		"dependencies": ["gf.kernel", "gf.standard"],
		"enabled_by_default": False,
		"installer_paths": [],
		"tags": [],
	}
	data.update(overrides)
	return data


def make_preset_test_data(**overrides: Any) -> dict[str, Any]:
	data: dict[str, Any] = {
		"id": "project.fixture",
		"display_name": "Fixture Preset",
		"description": "Maintenance self-test preset fixture.",
		"extension_ids": ["gf.save", "gf.dialogue"],
		"tags": ["fixture"],
	}
	data.update(overrides)
	return data


def make_manifest_test_record(extension_name: str, data: dict[str, Any]) -> dict[str, Any]:
	return {
		"extension_name": extension_name,
		"root_path": f"addons/gf/extensions/{extension_name}",
		"path": f"addons/gf/extensions/{extension_name}/gf_extension.json",
		"id": str(data.get("id", "")).strip(),
		"data": data,
		"error": "",
	}


def make_api_snapshot_class(class_name: str, extends: str, members: dict[str, Any]) -> dict[str, Any]:
	return {
		"name": class_name,
		"module": "fixture",
		"source_path": f"addons/gf/fixture/{class_name}.gd",
		"extends": extends,
		"members": members,
	}


def make_api_snapshot_member(kind: str, member_name: str, signature: str) -> dict[str, Any]:
	return {
		"kind": kind,
		"name": member_name,
		"group": "methods",
		"signature": normalize_api_signature(signature),
	}


def read_extension_manifest_constants() -> dict[str, list[str]]:
	path = ROOT / "addons/gf/kernel/extension/gf_extension_manifest.gd"
	source = read_text_file(path)
	result: dict[str, list[str]] = {}
	for constant_name in (
		"_SUPPORTED_FIELDS",
		"_FORBIDDEN_RELATION_FIELDS",
	):
		result[constant_name] = parse_gdscript_string_array_constant(source, constant_name)
	return result


def read_extension_preset_constants() -> dict[str, list[str]]:
	path = ROOT / "addons/gf/kernel/extension/gf_extension_preset.gd"
	source = read_text_file(path)
	result: dict[str, list[str]] = {}
	for constant_name in (
		"_SUPPORTED_FIELDS",
		"_FORBIDDEN_RELATION_FIELDS",
		"_FORBIDDEN_PACKAGE_FIELDS",
	):
		result[constant_name] = parse_gdscript_string_array_constant(source, constant_name)
	return result


def read_layer_boundary_manifest_constants() -> dict[str, list[str]]:
	path = ROOT / "tests/gf_core/maintenance/test_layer_boundary_validation.gd"
	source = read_text_file(path)
	result: dict[str, list[str]] = {}
	for constant_name in (
		"EXTENSION_ALLOWED_DEPENDENCIES",
		"EXTENSION_ALLOWED_MANIFEST_FIELDS",
		"EXTENSION_FORBIDDEN_MANIFEST_FIELDS",
		"KERNEL_EXTENSION_INFRASTRUCTURE_PATHS",
	):
		result[constant_name] = parse_gdscript_string_array_constant(source, constant_name)
	return result


def normalize_res_paths(paths: list[str]) -> list[str]:
	return sorted(path.removeprefix("res://") for path in paths)


def parse_gdscript_string_array_constant(source: str, constant_name: str) -> list[str]:
	pattern = re.compile(
		rf"(?ms)^const\s+{re.escape(constant_name)}\b[^\n=]*=\s*\[(?P<body>.*?)^\]",
		re.MULTILINE,
	)
	match = pattern.search(source)
	if not match:
		return []
	values: list[str] = []
	for string_match in re.finditer(r'"(?:[^"\\]|\\.)*"', match.group("body")):
		try:
			value = json.loads(string_match.group(0))
		except json.JSONDecodeError:
			continue
		if isinstance(value, str):
			values.append(value)
	return sorted(values)


def format_set_mismatch(
	left_name: str,
	left_values: set[str],
	right_name: str,
	right_values: set[str],
) -> str:
	only_left = sorted(left_values - right_values)
	only_right = sorted(right_values - left_values)
	return (
		f"{left_name} and {right_name} drifted; "
		f"only_left={only_left}; only_right={only_right}"
	)


def issue_exists(
	issues: list[dict[str, Any]],
	kind: str,
	**expected: Any,
) -> bool:
	for issue in issues:
		if issue.get("kind") != kind:
			continue
		if all(issue.get(key) == value for key, value in expected.items()):
			return True
	return False


def audit_extension_preset_data(data: dict[str, Any], path: str) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	for field_name in sorted(set(data) - GF_PRESET_ALLOWED_FIELDS):
		if field_name in GF_PRESET_FORBIDDEN_RELATION_FIELDS:
			issues.append(make_boundary_issue(
				"forbidden_preset_relation_field",
				path,
				f"Field {field_name!r} would turn a preset into a soft dependency or load-order graph.",
				field=field_name,
			))
		elif field_name in GF_PRESET_FORBIDDEN_PACKAGE_FIELDS:
			issues.append(make_boundary_issue(
				"forbidden_preset_package_field",
				path,
				f"Field {field_name!r} belongs to download/package/install tooling outside GFExtensionPreset.",
				field=field_name,
			))
		else:
			issues.append(make_boundary_issue(
				"unsupported_preset_field",
				path,
				f"Extension preset data must not declare unsupported field {field_name!r}.",
				field=field_name,
			))
	return issues


def collect_bundled_extension_manifest_records() -> list[dict[str, Any]]:
	records: list[dict[str, Any]] = []
	if not GF_EXTENSIONS_ROOT.is_dir():
		return records
	for extension_root in sorted(path for path in GF_EXTENSIONS_ROOT.iterdir() if path.is_dir() and not path.name.startswith(".")):
		manifest_path = extension_root / "gf_extension.json"
		data: dict[str, Any] = {}
		error = ""
		if manifest_path.is_file():
			try:
				parsed = json.loads(manifest_path.read_text(encoding="utf-8"))
				if isinstance(parsed, dict):
					data = parsed
				else:
					error = "gf_extension.json must contain a JSON object."
			except (OSError, json.JSONDecodeError) as exc:
				error = f"failed to read gf_extension.json: {exc}"
		else:
			error = "bundled extension directory is missing gf_extension.json."
		records.append({
			"extension_name": extension_root.name,
			"root_path": extension_root.relative_to(ROOT).as_posix(),
			"path": manifest_path.relative_to(ROOT).as_posix(),
			"id": str(data.get("id", "")).strip(),
			"data": data,
			"error": error,
		})
	return records


def audit_bundled_extension_manifests(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	for record in records:
		path = record["path"]
		data = record["data"]
		if record["error"]:
			issues.append(make_boundary_issue(
				"missing_or_invalid_manifest",
				path,
				record["error"],
			))
			continue

		for field_name in sorted(set(data) - GF_MANIFEST_ALLOWED_FIELDS):
			issues.append(make_boundary_issue(
				"unsupported_manifest_field",
				path,
				f"Bundled GF extension manifests must not declare unsupported field {field_name!r}.",
				field=field_name,
				extension_id=record["id"],
			))
		for field_name in sorted(GF_MANIFEST_FORBIDDEN_RELATION_FIELDS.intersection(data)):
			issues.append(make_boundary_issue(
				"forbidden_manifest_relation_field",
				path,
				f"Field {field_name!r} would create package/preset/soft-dependency semantics inside an atomic bundled extension.",
				field=field_name,
				extension_id=record["id"],
			))

		if str(data.get("kind", "")).strip() != "extension":
			issues.append(make_boundary_issue(
				"invalid_bundled_extension_kind",
				path,
				"Bundled GF optional extension manifests must declare kind='extension'.",
				field="kind",
				extension_id=record["id"],
			))
		if not str(data.get("extension_version", "")).strip():
			issues.append(make_boundary_issue(
				"missing_extension_version",
				path,
				"Bundled GF extensions must declare extension_version independently from the GF release version.",
				field="extension_version",
				extension_id=record["id"],
			))
		if data.get("enabled_by_default") is not False:
			issues.append(make_boundary_issue(
				"bundled_extension_enabled_by_default",
				path,
				"Bundled GF optional extensions must explicitly declare enabled_by_default=false.",
				field="enabled_by_default",
				extension_id=record["id"],
			))

		dependencies = data.get("dependencies", [])
		if not isinstance(dependencies, list):
			issues.append(make_boundary_issue(
				"invalid_manifest_dependencies",
				path,
				"dependencies must be an array of explicit hard dependency IDs.",
				field="dependencies",
				extension_id=record["id"],
			))
			continue
		for dependency in dependencies:
			if not isinstance(dependency, str):
				issues.append(make_boundary_issue(
					"invalid_manifest_dependency_type",
					path,
					"dependencies must contain only strings.",
					field="dependencies",
					extension_id=record["id"],
				))
				continue
			dependency_id = dependency.strip()
			if dependency_id not in GF_ALLOWED_EXTENSION_DEPENDENCIES:
				issues.append(make_boundary_issue(
					"forbidden_bundled_extension_dependency",
					path,
					(
						"Bundled GF extensions are atomic and may only depend on "
						f"{', '.join(GF_ALLOWED_EXTENSION_DEPENDENCIES)}; found {dependency_id!r}."
					),
					field="dependencies",
					symbol=dependency_id,
					extension_id=record["id"],
				))
	return issues


def audit_kernel_dependency_boundary(
	standard_class_roots: dict[str, str],
	extension_class_roots: dict[str, str],
	extension_ids: list[str],
) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	for path in collect_text_files(GF_KERNEL_ROOT, {".gd"}):
		relative_path = path.relative_to(ROOT).as_posix()
		source = read_text_file(path)
		if not source:
			continue
		if GF_STANDARD_RES_ROOT in source or "addons/gf/standard" in source:
			issues.append(make_boundary_issue(
				"kernel_references_standard_path",
				relative_path,
				"addons/gf/kernel must not reference addons/gf/standard paths.",
			))
		if relative_path not in GF_EXTENSION_INFRASTRUCTURE_PATHS:
			for extension_name in extract_bundled_extension_names(source):
				issues.append(make_boundary_issue(
					"kernel_references_extension_path",
					relative_path,
					"Only kernel extension infrastructure may know the bundled extension root path.",
					symbol=extension_name,
				))
		for extension_id in extension_ids:
			if extension_id in source:
				issues.append(make_boundary_issue(
					"kernel_references_extension_id",
					relative_path,
					"addons/gf/kernel must not hard-code bundled optional extension IDs.",
					symbol=extension_id,
				))
		for class_name in sorted([*standard_class_roots.keys(), *extension_class_roots.keys()]):
			if source_contains_identifier(source, class_name):
				issues.append(make_boundary_issue(
					"kernel_references_downstream_class",
					relative_path,
					"addons/gf/kernel must not reference concrete standard or optional extension class_name values.",
					symbol=class_name,
				))
	return issues


def audit_standard_dependency_boundary(
	extension_class_roots: dict[str, str],
	extension_ids: list[str],
) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	for path in collect_text_files(GF_STANDARD_ROOT, {".gd"}):
		relative_path = path.relative_to(ROOT).as_posix()
		source = read_text_file(path)
		if not source:
			continue
		for extension_name in extract_bundled_extension_names(source):
			issues.append(make_boundary_issue(
				"standard_references_extension_path",
				relative_path,
				"addons/gf/standard must not reference bundled optional extension paths.",
				symbol=extension_name,
			))
		for extension_id in extension_ids:
			if extension_id in source:
				issues.append(make_boundary_issue(
					"standard_references_extension_id",
					relative_path,
					"addons/gf/standard must not probe bundled optional extension IDs.",
					symbol=extension_id,
				))
		for class_name in sorted(extension_class_roots.keys()):
			if source_contains_identifier(source, class_name):
				issues.append(make_boundary_issue(
					"standard_references_extension_class",
					relative_path,
					"addons/gf/standard must not reference optional extension class_name values.",
					symbol=class_name,
				))
	return issues


def audit_bundled_extension_dependency_boundary(
	extension_class_roots: dict[str, str],
	extension_id_by_name: dict[str, str],
	extension_ids: list[str],
) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	for path in collect_text_files(GF_EXTENSIONS_ROOT, GF_TEXT_BOUNDARY_EXTENSIONS):
		relative_path = path.relative_to(ROOT).as_posix()
		extension_name = get_bundled_extension_name_from_relative_path(relative_path)
		if not extension_name:
			continue
		source = read_text_file(path)
		if not source:
			continue
		own_extension_id = extension_id_by_name.get(extension_name, "")
		for referenced_name in extract_bundled_extension_names(source):
			if referenced_name != extension_name:
				issues.append(make_boundary_issue(
					"extension_references_other_extension_path",
					relative_path,
					"Bundled GF extensions must not reference other bundled extension paths.",
					symbol=referenced_name,
					extension_id=own_extension_id,
				))
		for extension_id in extension_ids:
			if extension_id != own_extension_id and extension_id in source:
				issues.append(make_boundary_issue(
					"extension_references_other_extension_id",
					relative_path,
					"Bundled GF extensions must not probe or name other bundled extension IDs.",
					symbol=extension_id,
					extension_id=own_extension_id,
				))
		for class_name, class_root in sorted(extension_class_roots.items()):
			class_extension_name = get_bundled_extension_name_from_relative_path(class_root)
			if class_extension_name != extension_name and source_contains_identifier(source, class_name):
				issues.append(make_boundary_issue(
					"extension_references_other_extension_class",
					relative_path,
					"Bundled GF extensions must not reference class_name values owned by another bundled extension.",
					symbol=class_name,
					extension_id=own_extension_id,
				))
		if GF_EXTENSION_FORBIDDEN_GLOBAL_FACADE in source:
			issues.append(make_boundary_issue(
				"extension_uses_global_facade",
				relative_path,
				"Bundled GF extension runtime/editor code must use explicit injection or local context instead of the global Gf facade.",
				symbol=GF_EXTENSION_FORBIDDEN_GLOBAL_FACADE,
				extension_id=own_extension_id,
			))
	return issues


def audit_framework_project_extension_defaults() -> list[dict[str, Any]]:
	path = ROOT / "project.godot"
	return audit_project_extension_settings_source(read_text_file(path), "project.godot")


def audit_project_extension_settings_source(source: str, path: str) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	match = re.search(r"(?m)^extensions/enabled\s*=\s*(?P<value>.+?)\s*$", source)
	if match is None:
		issues.append(make_boundary_issue(
			"missing_project_extension_enabled_setting",
			path,
			"The GF framework project must explicitly keep gf/extensions/enabled empty.",
			field="gf/extensions/enabled",
		))
		return issues

	value = match.group("value").strip()
	enabled_extension_ids = extract_godot_string_literals(value)
	if enabled_extension_ids:
		issues.append(make_boundary_issue(
			"project_extensions_enabled_by_default",
			path,
			"The framework repository must not enable optional bundled extensions by default.",
			field="gf/extensions/enabled",
			symbol=", ".join(enabled_extension_ids),
		))
		return issues

	if not re.search(r"\[\s*\]", value) and value not in {"Array[String]()", "PackedStringArray()"}:
		issues.append(make_boundary_issue(
			"invalid_project_extension_enabled_setting",
			path,
			"gf/extensions/enabled must be an explicit empty string array.",
			field="gf/extensions/enabled",
			symbol=value,
		))
	return issues


def extract_godot_string_literals(value: str) -> list[str]:
	result: list[str] = []
	for match in re.finditer(r'"((?:[^"\\]|\\.)*)"', value):
		try:
			parsed = json.loads(f'"{match.group(1)}"')
		except json.JSONDecodeError:
			continue
		if isinstance(parsed, str):
			result.append(parsed)
	return result


def collect_public_doc_boundary_files() -> list[Path]:
	files: list[Path] = []
	for relative_file in PUBLIC_DOC_BOUNDARY_EXPLICIT_FILES:
		path = ROOT / relative_file
		if path.is_file():
			files.append(path)
	for relative_root in PUBLIC_DOC_BOUNDARY_ROOTS:
		root = ROOT / relative_root
		if not root.is_dir():
			continue
		for path in sorted(root.rglob("*.md")):
			relative_path = path.relative_to(ROOT).as_posix()
			if any(relative_path.startswith(prefix) for prefix in PUBLIC_DOC_BOUNDARY_EXCLUDED_PREFIXES):
				continue
			files.append(path)
	return sorted(set(files))


def collect_public_api_boundary_files() -> list[Path]:
	files: list[Path] = []
	for relative_root, extensions in PUBLIC_API_BOUNDARY_ROOTS:
		root = ROOT / relative_root
		files.extend(collect_text_files(root, extensions))
	return sorted(set(files))


def audit_public_api_boundary_text(source: str, path: str) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	for line_number, line in enumerate(source.splitlines(), start=1):
		for term, message in sorted(PUBLIC_API_BOUNDARY_FORBIDDEN_TERMS.items()):
			if term in line:
				issues.append(make_boundary_issue(
					"forbidden_public_api_route_name",
					path,
					message,
					line=line_number,
					symbol=term,
				))
	return issues


def audit_public_doc_boundary_text(source: str, path: str) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	for line_number, line in enumerate(source.splitlines(), start=1):
		for term, message in sorted(PUBLIC_DOC_BOUNDARY_FORBIDDEN_TERMS.items()):
			if term in line:
				issues.append(make_boundary_issue(
					"forbidden_public_doc_term",
					path,
					message,
					line=line_number,
					symbol=term,
				))
		for kind, pattern, message in PUBLIC_DOC_BOUNDARY_PATTERNS:
			if pattern.search(line):
				issues.append(make_boundary_issue(
					kind,
					path,
					message,
					line=line_number,
					symbol=trim_text(line.strip(), 180),
				))
		issues.extend(audit_public_doc_package_install_external_dependency_line(
			line,
			path,
			line_number,
		))
		issues.extend(audit_public_doc_package_signature_claim_line(
			line,
			path,
			line_number,
		))
	return issues


def audit_public_doc_package_install_external_dependency_line(
	line: str,
	path: str,
	line_number: int,
) -> list[dict[str, Any]]:
	if PUBLIC_DOC_EXTERNAL_TOOL_NEGATION_RE.search(line):
		return []
	issues: list[dict[str, Any]] = []
	tool_path_match = PUBLIC_DOC_PACKAGE_MANAGER_TOOL_PATH_RE.search(line)
	if tool_path_match != None:
		issues.append(make_boundary_issue(
			"public_doc_package_manager_python_tool_path",
			path,
			"Public docs must not route ordinary users to maintenance-side Python package manager scripts.",
			line=line_number,
			symbol=tool_path_match.group(0),
		))
	if (
		PUBLIC_DOC_USER_INSTALL_CONCEPT_RE.search(line)
		and PUBLIC_DOC_EXTERNAL_TOOL_RE.search(line)
		and PUBLIC_DOC_EXTERNAL_TOOL_REQUIREMENT_RE.search(line)
	):
		issues.append(make_boundary_issue(
			"public_doc_package_install_external_tool_requirement",
			path,
			"Public docs must not describe Python, npm/npx, Git, Node, or pip as required for ordinary GF package installation.",
			line=line_number,
			symbol=trim_text(line.strip(), 180),
		))
	return issues


def audit_public_doc_package_signature_claim_line(
	line: str,
	path: str,
	line_number: int,
) -> list[dict[str, Any]]:
	if PUBLIC_DOC_PACKAGE_SIGNATURE_NEGATION_RE.search(line):
		return []
	if not PUBLIC_DOC_PACKAGE_SIGNATURE_CLAIM_RE.search(line):
		return []
	return [make_boundary_issue(
		"public_doc_package_signature_verification_claim",
		path,
		"Public docs must not claim GF package or registry signature verification before Godot-native verification is implemented.",
		line=line_number,
		symbol=trim_text(line.strip(), 180),
	)]


def collect_resource_boundary_paths() -> dict[str, Any]:
	tracked_paths_result = read_git_paths(["ls-files", "-z", "--cached"])
	untracked_paths_result = read_git_paths(["ls-files", "-z", "--others", "--exclude-standard"])
	errors: list[dict[str, Any]] = []
	if tracked_paths_result["error"]:
		errors.append(make_boundary_issue(
			"resource_boundary_tracked_scan_failed",
			"",
			trim_text(tracked_paths_result["error"], 1000),
		))
	if untracked_paths_result["error"]:
		errors.append(make_boundary_issue(
			"resource_boundary_untracked_scan_failed",
			"",
			trim_text(untracked_paths_result["error"], 1000),
		))
	if errors:
		return {"paths": [], "errors": errors}

	paths = sorted({
		path
		for path in tracked_paths_result["paths"] + untracked_paths_result["paths"]
		if should_scan_resource_boundary_path(path)
	})
	return {"paths": paths, "errors": []}


def should_scan_resource_boundary_path(path: str) -> bool:
	normalized_path = path.replace("\\", "/")
	if any(normalized_path.startswith(prefix) for prefix in RESOURCE_BOUNDARY_EXCLUDED_PREFIXES):
		return False
	return Path(normalized_path).suffix.lower() in RESOURCE_BOUNDARY_SCAN_EXTENSIONS


def collect_content_package_manifest_paths() -> dict[str, Any]:
	tracked_paths_result = read_git_paths(["ls-files", "-z", "--cached"])
	untracked_paths_result = read_git_paths(["ls-files", "-z", "--others", "--exclude-standard"])
	errors: list[dict[str, Any]] = []
	if tracked_paths_result["error"]:
		errors.append(make_boundary_issue(
			"content_package_tracked_scan_failed",
			"",
			trim_text(tracked_paths_result["error"], 1000),
		))
	if untracked_paths_result["error"]:
		errors.append(make_boundary_issue(
			"content_package_untracked_scan_failed",
			"",
			trim_text(untracked_paths_result["error"], 1000),
		))
	if errors:
		return {"paths": [], "errors": errors}

	paths = sorted({
		path
		for path in tracked_paths_result["paths"] + untracked_paths_result["paths"]
		if should_scan_content_package_manifest_path(path)
	})
	return {"paths": paths, "errors": []}


def should_scan_content_package_manifest_path(path: str) -> bool:
	normalized_path = path.replace("\\", "/")
	if any(normalized_path.startswith(prefix) for prefix in RESOURCE_BOUNDARY_EXCLUDED_PREFIXES):
		return False
	return normalized_path.rsplit("/", 1)[-1] == CONTENT_PACKAGE_MANIFEST_FILE


def collect_package_manifest_paths() -> dict[str, Any]:
	tracked_paths_result = read_git_paths(["ls-files", "-z", "--cached"])
	untracked_paths_result = read_git_paths(["ls-files", "-z", "--others", "--exclude-standard"])
	errors: list[dict[str, Any]] = []
	if tracked_paths_result["error"]:
		errors.append(make_package_issue(
			"package_manifest_tracked_scan_failed",
			"",
			trim_text(tracked_paths_result["error"], 1000),
		))
	if untracked_paths_result["error"]:
		errors.append(make_package_issue(
			"package_manifest_untracked_scan_failed",
			"",
			trim_text(untracked_paths_result["error"], 1000),
		))
	if errors:
		return {"paths": [], "errors": errors}

	paths = sorted({
		path
		for path in tracked_paths_result["paths"] + untracked_paths_result["paths"]
		if should_scan_package_manifest_path(path)
	})
	return {"paths": paths, "errors": []}


def should_scan_package_manifest_path(path: str) -> bool:
	normalized_path = path.replace("\\", "/")
	if any(normalized_path.startswith(prefix) for prefix in PACKAGE_MANIFEST_SCAN_EXCLUDED_PREFIXES):
		return False
	return normalized_path.startswith("packages/") and Path(normalized_path).suffix.lower() == ".json"


def load_package_manifest_record(path: str) -> dict[str, Any]:
	issues: list[dict[str, Any]] = []
	record: dict[str, Any] = {
		"path": path,
		"id": "",
		"kind": "",
		"dependencies": [],
		"packages": [],
		"paths": [],
		"exclude_paths": [],
		"issues": issues,
	}
	source_path = ROOT / path
	try:
		data = json.loads(source_path.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
		issues.append(make_package_issue(
			"invalid_package_manifest_json",
			path,
			"Package manifest must be a readable UTF-8 JSON object.",
			error=trim_text(str(error), 300),
		))
		return record

	if not isinstance(data, dict):
		issues.append(make_package_issue(
			"invalid_package_manifest",
			path,
			"Package manifest root must be a JSON object.",
			expected_value="object",
			actual_value=type(data).__name__,
		))
		return record

	record["id"] = package_manifest_string(data, "id")
	record["kind"] = package_manifest_string(data, "kind")
	record["dependencies"] = package_manifest_string_array(data, "dependencies")
	record["packages"] = package_manifest_string_array(data, "packages")
	record["paths"] = normalize_package_manifest_paths(package_manifest_string_array(data, "paths"))
	record["exclude_paths"] = normalize_package_manifest_paths(package_manifest_string_array(data, "exclude_paths"))
	issues.extend(audit_package_manifest_data(data, path))
	return record


def audit_package_manifest_data(data: dict[str, Any], path: str) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	for field_name in sorted(data.keys()):
		if field_name in PACKAGE_MANIFEST_FORBIDDEN_FIELDS:
			issues.append(make_package_issue(
				"forbidden_package_manifest_field",
				path,
				"Download, registry, and checksum fields belong to the generated registry, not local package manifests.",
				field=field_name,
			))
		elif field_name not in PACKAGE_MANIFEST_ALLOWED_FIELDS:
			issues.append(make_package_issue(
				"unsupported_package_manifest_field",
				path,
				"Package manifest fields are whitelisted; project-specific data belongs in metadata.",
				field=field_name,
			))

	schema_version = data.get("schema_version")
	if schema_version != PACKAGE_MANIFEST_SCHEMA_VERSION:
		issues.append(make_package_issue(
			"invalid_package_schema_version",
			path,
			f"schema_version must be {PACKAGE_MANIFEST_SCHEMA_VERSION}.",
			field="schema_version",
			expected_value=PACKAGE_MANIFEST_SCHEMA_VERSION,
			actual_value=schema_version,
		))

	package_id = package_manifest_string(data, "id")
	if not package_id:
		issues.append(make_package_issue(
			"missing_package_id",
			path,
			"Package id is required.",
			field="id",
		))
	elif PACKAGE_ID_RE.match(package_id) is None:
		issues.append(make_package_issue(
			"invalid_package_id",
			path,
			"Package id must use gf.kernel, gf.standard.*, gf.extension.*, gf.preset.*, or gf.tool.*.",
			field="id",
			actual_value=package_id,
		))

	kind = package_manifest_string(data, "kind")
	if kind not in PACKAGE_MANIFEST_KINDS:
		issues.append(make_package_issue(
			"invalid_package_kind",
			path,
			"Package kind must be one of kernel, standard, extension, preset, or tool.",
			field="kind",
			actual_value=kind,
		))
	elif package_id and not package_id_matches_kind(package_id, kind):
		issues.append(make_package_issue(
			"package_id_kind_mismatch",
			path,
			"Package id prefix must match package kind.",
			field="kind",
			actual_value=kind,
			expected_value=expected_package_kind_from_id(package_id),
		))

	version = package_manifest_string(data, "version")
	if not version:
		issues.append(make_package_issue(
			"missing_package_version",
			path,
			"Package version is required.",
			field="version",
		))
	elif version != "unreleased" and SEMVER_RE.match(version) is None:
		issues.append(make_package_issue(
			"invalid_package_version",
			path,
			"Package version must be 'unreleased' or SemVer.",
			field="version",
			actual_value=version,
		))

	for field_name in ("display_name", "description", "enable_extension"):
		if field_name in data and not isinstance(data[field_name], str):
			issues.append(make_package_issue(
				f"invalid_package_{field_name}",
				path,
				f"{field_name} must be a string when present.",
				field=field_name,
				expected_value="string",
			))
	if "metadata" in data and not isinstance(data["metadata"], dict):
		issues.append(make_package_issue(
			"invalid_package_metadata",
			path,
			"metadata must be an object when present.",
			field="metadata",
			expected_value="object",
		))

	validate_package_string_array(data, "dependencies", path, issues)
	validate_package_string_array(data, "exclude_paths", path, issues)
	validate_package_string_array(data, "paths", path, issues)
	validate_package_string_array(data, "packages", path, issues)

	if kind == "preset":
		if package_manifest_string_array(data, "dependencies"):
			issues.append(make_package_issue(
				"preset_package_declares_dependencies",
				path,
				"Preset manifests must use packages, not dependencies.",
				field="dependencies",
			))
		if package_manifest_string_array(data, "paths"):
			issues.append(make_package_issue(
				"preset_package_declares_paths",
				path,
				"Preset manifests install packages and must not own source paths.",
				field="paths",
			))
		if package_manifest_string_array(data, "exclude_paths"):
			issues.append(make_package_issue(
				"preset_package_declares_exclude_paths",
				path,
				"Preset manifests install packages and must not own source path exclusions.",
				field="exclude_paths",
			))
		if not package_manifest_string_array(data, "packages"):
			issues.append(make_package_issue(
				"preset_package_missing_packages",
				path,
				"Preset manifests must declare at least one package id.",
				field="packages",
			))
	else:
		if "packages" in data:
			issues.append(make_package_issue(
				"non_preset_declares_packages",
				path,
				"Only preset manifests may declare packages.",
				field="packages",
			))
		if not package_manifest_string_array(data, "paths"):
			issues.append(make_package_issue(
				"package_manifest_missing_paths",
				path,
				"Non-preset package manifests must declare owned paths.",
				field="paths",
			))

	if kind != "extension" and "enable_extension" in data:
		issues.append(make_package_issue(
			"non_extension_enable_extension",
			path,
			"Only extension packages may declare enable_extension.",
			field="enable_extension",
		))

	for path_index, raw_path in enumerate(package_manifest_string_array(data, "paths")):
		normalized_path = normalize_package_manifest_path(raw_path)
		if not normalized_path:
			issues.append(make_package_issue(
				"invalid_package_path",
				path,
				"Package paths must be relative addons/gf paths and must not contain '..', protocols, or absolute roots.",
				field="paths",
				row_index=path_index,
				actual_value=raw_path,
			))
			continue
		if not package_path_is_under_addons_gf(normalized_path):
			issues.append(make_package_issue(
				"package_path_outside_addons_gf",
				path,
				"Package paths must stay under addons/gf.",
				field="paths",
				row_index=path_index,
				actual_value=normalized_path,
			))
			continue
		if not package_manifest_path_exists(normalized_path):
			issues.append(make_package_issue(
				"package_path_missing",
				path,
				"Package path anchor does not exist in the source tree.",
				field="paths",
				row_index=path_index,
				actual_value=normalized_path,
			))
	for path_index, raw_path in enumerate(package_manifest_string_array(data, "exclude_paths")):
		normalized_path = normalize_package_manifest_path(raw_path)
		if not normalized_path:
			issues.append(make_package_issue(
				"invalid_package_exclude_path",
				path,
				"Package exclude_paths must be relative addons/gf paths and must not contain '..', protocols, or absolute roots.",
				field="exclude_paths",
				row_index=path_index,
				actual_value=raw_path,
			))
			continue
		if not package_path_is_under_addons_gf(normalized_path):
			issues.append(make_package_issue(
				"package_exclude_path_outside_addons_gf",
				path,
				"Package exclude_paths must stay under addons/gf.",
				field="exclude_paths",
				row_index=path_index,
				actual_value=normalized_path,
			))
			continue
		if not package_manifest_path_exists(normalized_path):
			issues.append(make_package_issue(
				"package_exclude_path_missing",
				path,
				"Package exclude_paths anchor does not exist in the source tree.",
				field="exclude_paths",
				row_index=path_index,
				actual_value=normalized_path,
			))
	return issues


def audit_package_manifest_graph(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	records_by_id: dict[str, list[dict[str, Any]]] = {}
	for record in records:
		package_id = str(record.get("id", ""))
		if package_id:
			records_by_id.setdefault(package_id, []).append(record)

	for package_id, duplicate_records in sorted(records_by_id.items()):
		if len(duplicate_records) <= 1:
			continue
		for record in duplicate_records:
			issues.append(make_package_issue(
				"duplicate_package_id",
				str(record["path"]),
				"Package id must be unique across package manifests.",
				field="id",
				row_key=package_id,
			))

	package_ids = set(records_by_id.keys())
	dependency_map: dict[str, list[str]] = {}
	for record in records:
		package_id = str(record.get("id", ""))
		kind = str(record.get("kind", ""))
		if not package_id:
			continue
		dependencies = [dependency for dependency in record.get("dependencies", []) if isinstance(dependency, str) and dependency]
		dependency_map[package_id] = [dependency for dependency in dependencies if dependency in package_ids]
		for dependency_id in dependencies:
			if dependency_id == package_id:
				issues.append(make_package_issue(
					"package_self_dependency",
					str(record["path"]),
					"Package must not depend on itself.",
					field="dependencies",
					row_key=package_id,
					actual_value=dependency_id,
				))
			elif dependency_id not in package_ids:
				issues.append(make_package_issue(
					"missing_package_dependency",
					str(record["path"]),
					"Package dependency is missing from scanned package manifests.",
					field="dependencies",
					row_key=package_id,
					actual_value=dependency_id,
				))
			elif not package_dependency_allowed(kind, dependency_id):
				issues.append(make_package_issue(
					"forbidden_package_dependency",
					str(record["path"]),
					"Package dependency direction violates runtime and tool package boundaries.",
					field="dependencies",
					row_key=package_id,
					actual_value=dependency_id,
				))

		for included_package_id in [item for item in record.get("packages", []) if isinstance(item, str) and item]:
			if included_package_id == package_id:
				issues.append(make_package_issue(
					"preset_self_package",
					str(record["path"]),
					"Preset must not include itself.",
					field="packages",
					row_key=package_id,
					actual_value=included_package_id,
				))
			elif included_package_id not in package_ids:
				issues.append(make_package_issue(
					"missing_preset_package",
					str(record["path"]),
					"Preset package id is missing from scanned package manifests.",
					field="packages",
					row_key=package_id,
					actual_value=included_package_id,
				))
			elif included_package_id.startswith("gf.preset."):
				issues.append(make_package_issue(
					"preset_includes_preset",
					str(record["path"]),
					"Preset manifests must include concrete packages, not other presets.",
					field="packages",
					row_key=package_id,
					actual_value=included_package_id,
				))

	for cycle in collect_package_dependency_cycles(dependency_map):
		first_package = cycle[0] if cycle else ""
		cycle_records = records_by_id.get(first_package, [])
		issue_path = str(cycle_records[0]["path"]) if cycle_records else ""
		issues.append(make_package_issue(
			"package_dependency_cycle",
			issue_path,
			"Package dependency cycle detected.",
			field="dependencies",
			actual_value=" -> ".join(cycle),
		))
	return issues


def audit_package_path_ownership(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	owners: list[dict[str, str]] = []
	for record in records:
		if record.get("kind") == "preset":
			continue
		for path in record.get("paths", []):
			root_path = package_path_ownership_root(path)
			if not root_path:
				continue
			owners.append({
				"package_id": str(record.get("id", "")),
				"path": str(record.get("path", "")),
				"owned_path": str(path),
				"root_path": root_path,
			})
	for index, left in enumerate(owners):
		for right in owners[index + 1:]:
			if left["package_id"] == right["package_id"]:
				continue
			if not package_paths_overlap(left["root_path"], right["root_path"]):
				continue
			issues.append(make_package_issue(
				"package_path_overlap",
				left["path"],
				"Package manifests must not claim overlapping source paths.",
				field="paths",
				row_key=left["package_id"],
				actual_value=left["owned_path"],
				expected_value=f"{right['package_id']} owns {right['owned_path']}",
			))
			issues.append(make_package_issue(
				"package_path_overlap",
				right["path"],
				"Package manifests must not claim overlapping source paths.",
				field="paths",
				row_key=right["package_id"],
				actual_value=right["owned_path"],
				expected_value=f"{left['package_id']} owns {left['owned_path']}",
			))
	return issues


def audit_core_only_plugin_source(
	source: str,
	path: str,
	standard_class_roots: dict[str, str],
) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	for line_number, raw_line in enumerate(source.splitlines(), start=1):
		line = strip_gdscript_line_comment(raw_line)
		if not line.strip():
			continue
		if re.search(r"\bpreload\s*\(\s*['\"]res://addons/gf/standard/", line):
			issues.append(make_package_issue(
				"plugin_preloads_standard",
				path,
				"The root plugin must not preload standard package files; gf-core must parse without standard installed.",
				line=line_number,
			))
		if re.search(r"\bload\s*\(\s*['\"]res://addons/gf/standard/", line):
			issues.append(make_package_issue(
				"plugin_direct_loads_standard",
				path,
				"The root plugin must use optional ResourceLoader.exists/load indirection for standard contributions.",
				line=line_number,
			))
	for class_name in sorted(standard_class_roots.keys()):
		if source_contains_identifier(source, class_name):
			issues.append(make_package_issue(
				"plugin_references_standard_class",
				path,
				"The root plugin must not reference standard class_name values at parse time.",
				symbol=class_name,
			))
	return issues


def make_package_source_boundary_payload(
	records: list[dict[str, Any]],
	source_paths: list[str],
	issues: list[dict[str, Any]],
) -> dict[str, Any]:
	return {
		"ok": len(issues) == 0,
		"root": str(ROOT),
		"package_count": len([record for record in records if record.get("id")]),
		"source_file_count": len(source_paths),
		"issue_count": len(issues),
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"issues": issues,
	}


def collect_package_source_boundary_paths() -> dict[str, Any]:
	tracked_paths_result = read_git_paths(["ls-files", "-z", "--cached"])
	untracked_paths_result = read_git_paths(["ls-files", "-z", "--others", "--exclude-standard"])
	errors: list[dict[str, Any]] = []
	if tracked_paths_result["error"]:
		errors.append(make_package_issue(
			"package_source_tracked_scan_failed",
			"",
			trim_text(tracked_paths_result["error"], 1000),
		))
	if untracked_paths_result["error"]:
		errors.append(make_package_issue(
			"package_source_untracked_scan_failed",
			"",
			trim_text(untracked_paths_result["error"], 1000),
		))
	if errors:
		return {"paths": [], "errors": errors}

	paths = sorted({
		path
		for path in tracked_paths_result["paths"] + untracked_paths_result["paths"]
		if should_scan_package_source_path(path)
	})
	return {"paths": paths, "errors": []}


def should_scan_package_source_path(path: str) -> bool:
	normalized_path = path.replace("\\", "/")
	return (
		normalized_path.startswith("addons/gf/")
		and Path(normalized_path).suffix.lower() in PACKAGE_SOURCE_BOUNDARY_SCAN_EXTENSIONS
	)


def collect_package_source_class_roots(source_paths: list[str]) -> dict[str, str]:
	result: dict[str, str] = {}
	for path in source_paths:
		if Path(path).suffix.lower() != ".gd":
			continue
		text = read_text_file(ROOT / path)
		for match in re.finditer(r"(?m)^\s*class_name\s+([A-Za-z_]\w*)", text):
			result[match.group(1)] = path
	return result


def audit_package_source_references(
	records: list[dict[str, Any]],
	source_paths: list[str],
	class_roots: dict[str, str],
	source_text_by_path: dict[str, str] | None = None,
) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	owner_entries = collect_package_source_owner_entries(records)
	dependencies_by_id = {
		str(record.get("id", "")): set(record.get("dependencies", []))
		for record in records
		if record.get("id")
	}
	class_owner_by_name: dict[str, dict[str, str]] = {}
	for class_name, class_path in sorted(class_roots.items()):
		class_owner = find_package_source_owner(class_path, owner_entries)
		if class_owner:
			class_owner_by_name[class_name] = class_owner

	for source_path in source_paths:
		source_owner = find_package_source_owner(source_path, owner_entries)
		if not source_owner:
			issues.append(make_package_issue(
				"package_source_unowned_file",
				source_path,
				"GF package source files must be owned by exactly one non-preset package manifest path.",
			))
			continue
		source_package_id = source_owner["package_id"]
		source = (
			source_text_by_path.get(source_path, "")
			if source_text_by_path is not None
			else read_text_file(ROOT / source_path)
		)
		if not source:
			continue
		for reference in extract_package_source_path_literals(source, source_path):
			target_path = normalize_package_source_reference_path(reference["value"])
			if not target_path:
				continue
			if not package_source_reference_is_concrete(target_path):
				continue
			target_owner = find_package_source_owner(target_path, owner_entries)
			if not target_owner:
				if package_source_unknown_reference_allowed(source_package_id, source_path, target_path):
					continue
				issues.append(make_package_issue(
					"package_source_unknown_path_reference",
					source_path,
					"Package source references an addons/gf path that is not owned by any package manifest.",
					line=reference["line"],
					row_key=source_package_id,
					target=target_path,
				))
				continue
			target_package_id = target_owner["package_id"]
			if package_source_reference_allowed(
				source_package_id,
				target_package_id,
				source_path,
				target_path,
				dependencies_by_id,
			):
				continue
			issues.append(make_package_issue(
				"package_source_undeclared_path_dependency",
				source_path,
				"Package source may only reference paths owned by itself or by directly declared package dependencies.",
				line=reference["line"],
				row_key=source_package_id,
				target=target_path,
				expected_value=target_package_id,
			))

		if Path(source_path).suffix.lower() != ".gd":
			continue
		code_source = gdscript_code_identifier_source(source)
		for class_name, target_owner in class_owner_by_name.items():
			target_package_id = target_owner["package_id"]
			if target_package_id == source_package_id:
				continue
			if not source_contains_identifier(code_source, class_name):
				continue
			class_path = class_roots.get(class_name, "")
			if package_source_reference_allowed(
				source_package_id,
				target_package_id,
				source_path,
				class_path,
				dependencies_by_id,
			):
				continue
			issues.append(make_package_issue(
				"package_source_undeclared_class_dependency",
				source_path,
				"Package source may only reference class_name values owned by itself or by directly declared package dependencies.",
				row_key=source_package_id,
				symbol=class_name,
				target=class_path,
				expected_value=target_package_id,
			))
	return issues


def collect_package_source_owner_entries(records: list[dict[str, Any]]) -> list[dict[str, str]]:
	entries: list[dict[str, str]] = []
	for record in records:
		if record.get("kind") == "preset":
			continue
		package_id = str(record.get("id", ""))
		if not package_id:
			continue
		for path in record.get("paths", []):
			root_path = package_path_ownership_root(str(path))
			if not root_path:
				continue
			entries.append({
				"package_id": package_id,
				"manifest_path": str(record.get("path", "")),
				"root_path": root_path,
			})
	return sorted(entries, key=lambda entry: len(entry["root_path"]), reverse=True)


def find_package_source_owner(path: str, owner_entries: list[dict[str, str]]) -> dict[str, str] | None:
	normalized_path = normalize_package_manifest_path(path)
	if not normalized_path:
		return None
	for entry in owner_entries:
		root_path = entry["root_path"]
		if normalized_path == root_path or normalized_path.startswith(root_path + "/"):
			return entry
	return None


def extract_package_source_path_literals(source: str, path: str) -> list[dict[str, Any]]:
	result: list[dict[str, Any]] = []
	is_gdscript = Path(path).suffix.lower() == ".gd"
	for line_number, raw_line in enumerate(source.splitlines(), start=1):
		line = strip_gdscript_line_comment(raw_line) if is_gdscript else raw_line
		for value in extract_simple_string_literals(line):
			if "addons/gf/" in value or value.startswith("res://addons/gf/"):
				result.append({"line": line_number, "value": value})
	return result


def extract_simple_string_literals(line: str) -> list[str]:
	result: list[str] = []
	for match in re.finditer(r'"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\'', line):
		value = match.group(1) if match.group(1) is not None else match.group(2)
		result.append(unescape_gdscript_string_literal(value))
	return result


def normalize_package_source_reference_path(value: str) -> str:
	normalized_path = value.strip().replace("\\", "/")
	if normalized_path.startswith("res://"):
		normalized_path = normalized_path.removeprefix("res://")
	normalized_path = normalized_path.split("?", 1)[0].split("#", 1)[0].split("::", 1)[0].rstrip("/")
	if not normalized_path.startswith("addons/gf"):
		return ""
	if normalized_path == "addons/gf" or normalized_path.startswith("addons/gf/"):
		return normalized_path
	return ""


def package_source_reference_is_concrete(target_path: str) -> bool:
	return not any(token in target_path for token in ("*", "{", "}", "%"))


def package_source_unknown_reference_allowed(source_package_id: str, source_path: str, target_path: str) -> bool:
	return (
		source_package_id == "gf.kernel"
		and source_path in GF_EXTENSION_INFRASTRUCTURE_PATHS
		and target_path == "addons/gf/extensions"
	)


def package_source_reference_allowed(
	source_package_id: str,
	target_package_id: str,
	source_path: str,
	target_path: str,
	dependencies_by_id: dict[str, set[str]],
) -> bool:
	if target_package_id == source_package_id:
		return True
	if (source_package_id, source_path, target_path) in PACKAGE_SOURCE_OPTIONAL_REFERENCES:
		return True
	return target_package_id in dependencies_by_id.get(source_package_id, set())


def gdscript_code_identifier_source(source: str) -> str:
	code_lines: list[str] = []
	for raw_line in source.splitlines():
		line = strip_gdscript_line_comment(raw_line)
		code_lines.append("".join(iter_gdscript_code_characters(line)))
	return "\n".join(code_lines)


def audit_package_build_result(builder_data: dict[str, Any], registry_path: Path) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	if builder_data.get("ok") is not True:
		for message in builder_data.get("issues", []):
			issues.append(make_package_issue(
				"package_builder_reported_issue",
				"tools/build_gf_package.py",
				trim_text(str(message), 500),
			))
	packages = builder_data.get("packages", [])
	if not isinstance(packages, list) or not packages:
		issues.append(make_package_issue(
			"package_builder_missing_packages",
			"tools/build_gf_package.py",
			"Package builder must produce at least one package archive.",
		))
		return issues

	registry_data = load_package_build_registry_data(registry_path, issues)
	registry_packages = registry_data.get("packages", {}) if isinstance(registry_data, dict) else {}
	if isinstance(registry_packages, dict):
		if len(registry_packages) != len(packages):
			issues.append(make_package_issue(
				"package_registry_count_mismatch",
				relative_or_absolute_path(registry_path),
				"Generated registry package count must match built package count.",
				actual_value=str(len(registry_packages)),
				expected_value=str(len(packages)),
			))
	else:
		issues.append(make_package_issue(
			"invalid_package_registry_packages",
			relative_or_absolute_path(registry_path),
			"Generated registry packages field must be an object.",
			field="packages",
		))
		registry_packages = {}

	for package in packages:
		if not isinstance(package, dict):
			issues.append(make_package_issue(
				"invalid_package_build_record",
				"tools/build_gf_package.py",
				"Package builder package entries must be objects.",
			))
			continue
		package_id = str(package.get("id", ""))
		registry_entry = registry_packages.get(package_id)
		if not isinstance(registry_entry, dict):
			issues.append(make_package_issue(
				"package_registry_missing_entry",
				relative_or_absolute_path(registry_path),
				"Generated registry is missing a built package entry.",
				row_key=package_id,
			))
			continue
		for field_name in sorted(PACKAGE_SIGNATURE_POLICY_FIELDS.intersection(registry_entry)):
			issues.append(make_package_issue(
				"package_registry_signature_field",
				relative_or_absolute_path(registry_path),
				"Registry package signature fields must not ship until Godot-native signature verification is implemented.",
				row_key=package_id,
				field=field_name,
			))
		for field_name in ["minimum_framework_version", "maximum_framework_version_exclusive"]:
			if field_name not in registry_entry:
				issues.append(make_package_issue(
					"package_registry_missing_package_compatibility_field",
					relative_or_absolute_path(registry_path),
					"Generated registry package entries must declare framework compatibility bounds.",
					row_key=package_id,
					field=field_name,
				))
		if str(package.get("kind", "")) == "preset":
			issues.extend(audit_package_build_preset_registry_entry(package_id, registry_entry, registry_path))
			continue
		archive_path = resolve_package_build_archive_path(str(package.get("archive", "")))
		if package.get("ok") is not True:
			for message in package.get("issues", []):
				issues.append(make_package_issue(
					"package_archive_reported_issue",
					relative_or_absolute_path(archive_path),
					trim_text(str(message), 500),
					row_key=package_id,
				))
		issues.extend(audit_package_build_archive(package_id, archive_path))
		archive_sha256 = sha256_path(archive_path) if archive_path.is_file() else ""
		archive_size = archive_path.stat().st_size if archive_path.is_file() else 0
		if archive_sha256 and archive_sha256 != package.get("sha256"):
			issues.append(make_package_issue(
				"package_archive_sha256_mismatch",
				relative_or_absolute_path(archive_path),
				"Builder sha256 must match the package archive bytes.",
				row_key=package_id,
			))
		if registry_entry.get("sha256") != archive_sha256:
			issues.append(make_package_issue(
				"package_registry_sha256_mismatch",
				relative_or_absolute_path(registry_path),
				"Generated registry sha256 must match archive bytes.",
				row_key=package_id,
			))
		if registry_entry.get("size_bytes") != archive_size:
			issues.append(make_package_issue(
				"package_registry_size_mismatch",
				relative_or_absolute_path(registry_path),
				"Generated registry size_bytes must match archive bytes.",
				row_key=package_id,
			))
		if not str(registry_entry.get("archive", "")).strip():
			issues.append(make_package_issue(
				"package_registry_empty_archive",
				relative_or_absolute_path(registry_path),
				"Generated registry archive field must not be empty.",
				row_key=package_id,
				field="archive",
			))
	return issues


def audit_package_build_registry_source_manifest(registry_source_path: Path, registry_path: Path) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	location = relative_or_absolute_path(registry_source_path)
	if not registry_source_path.is_file():
		return [
			make_package_issue(
				"package_registry_source_missing",
				location,
				"Package builder must create a registry source manifest for channel-based online installs.",
			)
		]
	try:
		data = json.loads(registry_source_path.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
		return [
			make_package_issue(
				"invalid_package_registry_source_json",
				location,
				"Generated registry source manifest must be readable UTF-8 JSON.",
				error=trim_text(str(error), 300),
			)
		]
	if not isinstance(data, dict):
		return [
			make_package_issue(
				"invalid_package_registry_source",
				location,
				"Generated registry source manifest root must be an object.",
				actual_value=type(data).__name__,
				expected_value="object",
			)
		]
	for scope, field_name in collect_registry_source_signature_fields(data):
		issues.append(make_package_issue(
			"package_registry_source_signature_field",
			location,
			"Registry source signature fields must not ship until Godot-native signature verification is implemented.",
			row_key=scope,
			field=field_name,
		))
	if data.get("schema_version") != 1:
		issues.append(make_package_issue(
			"invalid_package_registry_source_schema_version",
			location,
			"Generated registry source manifest schema_version must be 1.",
			field="schema_version",
			actual_value=str(data.get("schema_version", "")),
		))
	default_channel = str(data.get("default_channel", "")).strip()
	if not default_channel:
		issues.append(make_package_issue(
			"package_registry_source_default_channel_missing",
			location,
			"Generated registry source manifest default_channel is required.",
			field="default_channel",
		))
	channels = data.get("channels", {})
	if not isinstance(channels, dict) or not channels:
		issues.append(make_package_issue(
			"invalid_package_registry_source_channels",
			location,
			"Generated registry source manifest channels field must be a non-empty object.",
			field="channels",
		))
		return issues
	channel_entry = channels.get(default_channel)
	if not isinstance(channel_entry, dict):
		issues.append(make_package_issue(
			"package_registry_source_channel_missing",
			location,
			"Generated registry source manifest default channel must exist.",
			row_key=default_channel,
		))
		return issues
	if not str(channel_entry.get("registry", "")).strip():
		issues.append(make_package_issue(
			"package_registry_source_registry_missing",
			location,
			"Generated registry source channel registry field is required.",
			row_key=default_channel,
			field="registry",
		))
	registry_sha256 = str(channel_entry.get("registry_sha256", "")).strip().lower()
	if not is_sha256_hex(registry_sha256):
		issues.append(make_package_issue(
			"package_registry_source_sha256_invalid",
			location,
			"Generated registry source channel registry_sha256 must be a sha256 hex digest.",
			row_key=default_channel,
			field="registry_sha256",
		))
	elif registry_path.is_file() and registry_sha256 != sha256_path(registry_path):
		issues.append(make_package_issue(
			"package_registry_source_sha256_mismatch",
			location,
			"Generated registry source channel registry_sha256 must match the generated registry.",
			row_key=default_channel,
			field="registry_sha256",
		))
	registry_size = channel_entry.get("registry_size_bytes", 0)
	if not is_non_negative_int_metadata(registry_size):
		issues.append(make_package_issue(
			"package_registry_source_size_invalid",
			location,
			"Generated registry source channel registry_size_bytes must be a non-negative integer.",
			row_key=default_channel,
			field="registry_size_bytes",
		))
	elif registry_path.is_file() and int_value(registry_size) != registry_path.stat().st_size:
		issues.append(make_package_issue(
			"package_registry_source_size_mismatch",
			location,
			"Generated registry source channel registry_size_bytes must match the generated registry.",
			row_key=default_channel,
			field="registry_size_bytes",
		))
	mirrors = channel_entry.get("mirrors", [])
	if not isinstance(mirrors, list):
		issues.append(make_package_issue(
			"invalid_package_registry_source_mirrors",
			location,
			"Generated registry source channel mirrors must be an array.",
			row_key=default_channel,
			field="mirrors",
		))
	elif any(not isinstance(mirror, str) or not mirror.strip() for mirror in mirrors):
		issues.append(make_package_issue(
			"invalid_package_registry_source_mirror",
			location,
			"Generated registry source channel mirrors must contain non-empty strings.",
			row_key=default_channel,
			field="mirrors",
		))
	return issues


def audit_package_build_offline_bundle(
	bundle_path: Path,
	registry_path: Path,
	registry_source_path: Path,
	builder_data: dict[str, Any],
) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	location = relative_or_absolute_path(bundle_path)
	if not bundle_path.is_file():
		return [
			make_package_issue(
				"package_offline_bundle_missing",
				location,
				"Package builder must create an offline bundle zip when requested.",
			)
		]
	if not str(builder_data.get("offline_bundle", "")).strip():
		issues.append(make_package_issue(
			"package_offline_bundle_not_reported",
			"tools/build_gf_package.py",
			"Package builder JSON should report the offline bundle path when one is requested.",
			field="offline_bundle",
		))
	packages = builder_data.get("packages", [])
	if not isinstance(packages, list):
		packages = []
	archive_paths = [
		resolve_package_build_archive_path(str(package.get("archive", "")))
		for package in packages
		if isinstance(package, dict) and str(package.get("kind", "")) != "preset"
	]
	expected_files = [registry_path, registry_source_path, *archive_paths]
	common_root = package_build_offline_bundle_common_root(expected_files)
	expected_entries = sorted(package_build_bundle_entry(path, common_root) for path in expected_files)
	try:
		with zipfile.ZipFile(bundle_path, "r") as archive:
			names = sorted(name for name in archive.namelist() if name and not name.endswith("/"))
			name_set = set(names)
			registry_entry = package_build_bundle_entry(registry_path, common_root)
			registry_bytes = archive.read(registry_entry) if registry_entry in name_set else b""
			source_entry = package_build_bundle_entry(registry_source_path, common_root)
			source_bytes = archive.read(source_entry) if source_entry in name_set else b""
	except (zipfile.BadZipFile, KeyError) as error:
		return [
			make_package_issue(
				"invalid_package_offline_bundle_zip",
				location,
				"Offline bundle must be a readable zip containing the generated registry files.",
				error=trim_text(str(error), 300),
			)
		]
	if names != expected_entries:
		issues.append(make_package_issue(
			"package_offline_bundle_entries_mismatch",
			location,
			"Offline bundle entries must exactly match the generated registry, registry source, and package archives.",
			actual_value=", ".join(names[:30]),
			expected_value=", ".join(expected_entries[:30]),
		))
	for name in names:
		if not package_build_bundle_entry_is_safe(name):
			issues.append(make_package_issue(
				"package_offline_bundle_unsafe_entry",
				location,
				"Offline bundle entries must be relative safe paths.",
				actual_value=name,
			))
	registry_entry = package_build_bundle_entry(registry_path, common_root)
	if registry_entry not in name_set:
		issues.append(make_package_issue(
			"package_offline_bundle_registry_missing",
			location,
			"Offline bundle must include the generated registry JSON.",
			expected_value=registry_entry,
		))
		return issues
	registry_data = parse_package_build_bundle_json(registry_bytes)
	registry_packages = registry_data.get("packages", {}) if isinstance(registry_data, dict) else {}
	if not isinstance(registry_packages, dict):
		issues.append(make_package_issue(
			"package_offline_bundle_registry_invalid",
			location,
			"Offline bundle registry JSON must contain a packages object.",
			field="packages",
		))
		registry_packages = {}
	for package_id, registry_entry_value in registry_packages.items():
		if not isinstance(registry_entry_value, dict) or str(registry_entry_value.get("kind", "")) == "preset":
			continue
		archive_ref = str(registry_entry_value.get("archive", "")).strip()
		archive_entry = normalize_package_build_bundle_relative_entry(registry_entry, archive_ref)
		if not archive_entry or archive_entry not in name_set:
			issues.append(make_package_issue(
				"package_offline_bundle_archive_missing",
				location,
				"Offline bundle registry archive references must resolve to package zips inside the bundle.",
				row_key=str(package_id),
				actual_value=archive_ref,
			))
			continue
		with zipfile.ZipFile(bundle_path, "r") as archive:
			archive_bytes = archive.read(archive_entry)
		expected_sha = str(registry_entry_value.get("sha256", "")).strip().lower()
		expected_size = int_value(registry_entry_value.get("size_bytes", 0))
		if is_sha256_hex(expected_sha) and hashlib.sha256(archive_bytes).hexdigest() != expected_sha:
			issues.append(make_package_issue(
				"package_offline_bundle_archive_sha256_mismatch",
				location,
				"Offline bundle package archive bytes must match registry sha256.",
				row_key=str(package_id),
				field="sha256",
			))
		if expected_size > 0 and len(archive_bytes) != expected_size:
			issues.append(make_package_issue(
				"package_offline_bundle_archive_size_mismatch",
				location,
				"Offline bundle package archive bytes must match registry size_bytes.",
				row_key=str(package_id),
				field="size_bytes",
			))
	source_entry = package_build_bundle_entry(registry_source_path, common_root)
	if source_entry not in name_set:
		issues.append(make_package_issue(
			"package_offline_bundle_registry_source_missing",
			location,
			"Offline bundle must include the generated registry source manifest.",
			expected_value=source_entry,
		))
		return issues
	source_data = parse_package_build_bundle_json(source_bytes)
	channel_name = str(source_data.get("default_channel", "")).strip() if isinstance(source_data, dict) else ""
	channels = source_data.get("channels", {}) if isinstance(source_data, dict) else {}
	channel_entry = channels.get(channel_name, {}) if isinstance(channels, dict) else {}
	if isinstance(channel_entry, dict):
		source_registry_ref = str(channel_entry.get("registry", "")).strip()
		source_registry_entry = normalize_package_build_bundle_relative_entry(source_entry, source_registry_ref)
		if source_registry_entry != registry_entry:
			issues.append(make_package_issue(
				"package_offline_bundle_source_registry_mismatch",
				location,
				"Offline bundle registry source manifest should resolve to the bundled registry JSON.",
				actual_value=source_registry_ref,
				expected_value=registry_entry,
			))
		registry_sha = str(channel_entry.get("registry_sha256", "")).strip().lower()
		if is_sha256_hex(registry_sha) and hashlib.sha256(registry_bytes).hexdigest() != registry_sha:
			issues.append(make_package_issue(
				"package_offline_bundle_source_sha256_mismatch",
				location,
				"Offline bundle registry source sha256 must match bundled registry bytes.",
				field="registry_sha256",
			))
		if int_value(channel_entry.get("registry_size_bytes", 0)) != len(registry_bytes):
			issues.append(make_package_issue(
				"package_offline_bundle_source_size_mismatch",
				location,
				"Offline bundle registry source size must match bundled registry bytes.",
				field="registry_size_bytes",
			))
	else:
		issues.append(make_package_issue(
			"package_offline_bundle_source_channel_invalid",
			location,
			"Offline bundle registry source manifest must contain its default channel entry.",
			field="channels",
		))
	return issues


def package_build_offline_bundle_common_root(paths: list[Path]) -> Path:
	return Path(os.path.commonpath([str(path.resolve()) for path in paths]))


def package_build_bundle_entry(path: Path, common_root: Path) -> str:
	return os.path.relpath(path, common_root).replace("\\", "/")


def package_build_bundle_entry_is_safe(entry: str) -> bool:
	if not entry or entry.startswith("/") or "\\" in entry:
		return False
	return all(part not in ("", ".", "..") for part in entry.split("/"))


def normalize_package_build_bundle_relative_entry(parent_entry: str, reference: str) -> str:
	if not reference or reference.startswith(("http://", "https://")) or "\\" in reference or reference.startswith("/"):
		return ""
	parent_dir = posixpath.dirname(parent_entry)
	normalized = posixpath.normpath(posixpath.join(parent_dir, reference)).replace("\\", "/")
	if normalized == "." or normalized.startswith("../") or normalized.startswith("/"):
		return ""
	return normalized


def parse_package_build_bundle_json(data: bytes) -> dict[str, Any]:
	try:
		parsed = json.loads(data.decode("utf-8"))
	except (UnicodeDecodeError, json.JSONDecodeError):
		return {}
	return parsed if isinstance(parsed, dict) else {}


def collect_registry_source_signature_fields(data: dict[str, Any]) -> list[tuple[str, str]]:
	result: list[tuple[str, str]] = []
	for field_name in sorted(REGISTRY_SOURCE_UNSUPPORTED_SIGNATURE_FIELDS.intersection(data)):
		result.append(("root", field_name))
	channels = data.get("channels", {})
	if not isinstance(channels, dict):
		return result
	for channel_name, channel_entry in channels.items():
		if not isinstance(channel_entry, dict):
			continue
		for field_name in sorted(REGISTRY_SOURCE_UNSUPPORTED_SIGNATURE_FIELDS.intersection(channel_entry)):
			result.append((str(channel_name), field_name))
	return result


def audit_package_build_preset_registry_entry(
	package_id: str,
	registry_entry: dict[str, Any],
	registry_path: Path,
) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	location = relative_or_absolute_path(registry_path)
	if str(registry_entry.get("kind", "")) != "preset":
		issues.append(make_package_issue(
			"package_preset_registry_kind_mismatch",
			location,
			"Preset registry entries must keep kind=preset.",
			row_key=package_id,
			actual_value=str(registry_entry.get("kind", "")),
		))
	if str(registry_entry.get("archive", "")).strip():
		issues.append(make_package_issue(
			"package_preset_registry_has_archive",
			location,
			"Preset registry entries must not declare an archive.",
			row_key=package_id,
			field="archive",
		))
	if str(registry_entry.get("sha256", "")).strip():
		issues.append(make_package_issue(
			"package_preset_registry_has_sha256",
			location,
			"Preset registry entries must not declare sha256.",
			row_key=package_id,
			field="sha256",
		))
	if int_value(registry_entry.get("size_bytes", 0)) != 0:
		issues.append(make_package_issue(
			"package_preset_registry_has_size",
			location,
			"Preset registry entries must not declare a positive size_bytes.",
			row_key=package_id,
			field="size_bytes",
		))
	if package_manifest_string_array(registry_entry, "paths"):
		issues.append(make_package_issue(
			"package_preset_registry_has_paths",
			location,
			"Preset registry entries must not own paths.",
			row_key=package_id,
			field="paths",
		))
	if not package_manifest_string_array(registry_entry, "packages"):
		issues.append(make_package_issue(
			"package_preset_registry_missing_packages",
			location,
			"Preset registry entries must list concrete packages.",
			row_key=package_id,
			field="packages",
		))
	return issues


def load_package_build_registry_data(registry_path: Path, issues: list[dict[str, Any]]) -> dict[str, Any]:
	try:
		data = json.loads(registry_path.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
		issues.append(make_package_issue(
			"invalid_package_registry_json",
			relative_or_absolute_path(registry_path),
			"Generated package registry must be readable UTF-8 JSON.",
			error=trim_text(str(error), 300),
		))
		return {}
	if not isinstance(data, dict):
		issues.append(make_package_issue(
			"invalid_package_registry",
			relative_or_absolute_path(registry_path),
			"Generated package registry root must be an object.",
			expected_value="object",
			actual_value=type(data).__name__,
		))
		return {}
	if data.get("schema_version") != PACKAGE_REGISTRY_SCHEMA_VERSION:
		issues.append(make_package_issue(
			"invalid_package_registry_schema_version",
			relative_or_absolute_path(registry_path),
			f"Generated package registry schema_version must be {PACKAGE_REGISTRY_SCHEMA_VERSION}.",
			field="schema_version",
			expected_value=PACKAGE_REGISTRY_SCHEMA_VERSION,
			actual_value=str(data.get("schema_version", "")),
		))
	for field_name in ["minimum_framework_version", "maximum_framework_version_exclusive"]:
		if field_name not in data:
			issues.append(make_package_issue(
				"package_registry_missing_framework_compatibility_field",
				relative_or_absolute_path(registry_path),
				"Generated package registry must declare framework compatibility bounds.",
				field=field_name,
			))
	return data


def audit_package_build_archive(package_id: str, archive_path: Path) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	display_path = relative_or_absolute_path(archive_path)
	if not archive_path.is_file():
		return [
			make_package_issue(
				"package_archive_missing",
				display_path,
				"Package archive was not created.",
				row_key=package_id,
			)
		]
	try:
		with zipfile.ZipFile(archive_path, "r") as archive:
			names = sorted(name for name in archive.namelist() if name and not name.endswith("/"))
	except zipfile.BadZipFile as error:
		return [
			make_package_issue(
				"invalid_package_archive_zip",
				display_path,
				"Package archive must be a valid zip file.",
				row_key=package_id,
				error=trim_text(str(error), 300),
			)
		]
	top_level_entries = sorted({name.split("/", 1)[0] for name in names})
	if top_level_entries != ["addons"]:
		issues.append(make_package_issue(
			"package_archive_bad_root",
			display_path,
			"Package archive root must contain only addons/.",
			row_key=package_id,
			actual_value=", ".join(top_level_entries),
		))
	if package_id == "gf.kernel":
		for tool_path in KERNEL_EXCLUDED_PACKAGE_TOOL_PATHS:
			if tool_path in names:
				issues.append(make_package_issue(
					"kernel_archive_contains_package_tool",
					display_path,
					"gf.kernel archive must not ship maintenance-side Python package tools; user package management must use the Godot-native backend.",
					row_key=package_id,
					actual_value=tool_path,
				))
	blocked_dirs = {".git", ".godot", ".import", ".vs", "__pycache__", "node_modules"}
	blocked_names = {".DS_Store", "Thumbs.db"}
	blocked_suffixes = {".import", ".pyc", ".pyo", ".tmp", ".log"}
	for name in names:
		if not name.startswith("addons/gf/"):
			issues.append(make_package_issue(
				"package_archive_entry_outside_addons_gf",
				display_path,
				"Package archive entries must stay under addons/gf.",
				row_key=package_id,
				actual_value=name,
			))
		parts = name.split("/")
		if any(part in blocked_dirs for part in parts):
			issues.append(make_package_issue(
				"package_archive_blocked_directory",
				display_path,
				"Package archive must not contain generated or vendored cache directories.",
				row_key=package_id,
				actual_value=name,
			))
		if Path(name).name in blocked_names or Path(name).suffix in blocked_suffixes:
			issues.append(make_package_issue(
				"package_archive_blocked_file",
				display_path,
				"Package archive must not contain generated or temporary files.",
				row_key=package_id,
				actual_value=name,
			))
		lower_name = Path(name).name.lower()
		lower_suffix = Path(name).suffix.lower()
		if (
			not package_id.startswith("gf.tool.")
			and (
				lower_name in RUNTIME_PACKAGE_FORBIDDEN_EXTERNAL_TOOL_FILES
				or lower_suffix in RUNTIME_PACKAGE_FORBIDDEN_EXTERNAL_TOOL_SUFFIXES
			)
		):
			issues.append(make_package_issue(
				"runtime_package_external_tool_payload",
				display_path,
				"Runtime package archives must not ship Python, npm/Node, or shell tool payloads; ordinary package install must require only Godot.",
				row_key=package_id,
				actual_value=name,
			))
	return issues


def resolve_package_build_archive_path(path: str) -> Path:
	archive_path = Path(path)
	if not archive_path.is_absolute():
		archive_path = ROOT / archive_path
	return archive_path


def count_package_build_registry_entries(registry_path: Path) -> int:
	try:
		data = json.loads(registry_path.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError):
		return 0
	packages = data.get("packages", {}) if isinstance(data, dict) else {}
	return len(packages) if isinstance(packages, dict) else 0


def sha256_path(path: Path) -> str:
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for chunk in iter(lambda: handle.read(1024 * 1024), b""):
			digest.update(chunk)
	return digest.hexdigest()


def is_sha256_hex(value: str) -> bool:
	return len(value) == 64 and all(char in "0123456789abcdefABCDEF" for char in value)


def is_non_negative_int_metadata(value: Any) -> bool:
	if isinstance(value, bool):
		return False
	if isinstance(value, int):
		return value >= 0
	if isinstance(value, str):
		return value.strip().isdigit()
	return False


def int_value(value: Any) -> int:
	if isinstance(value, bool):
		return int(value)
	if isinstance(value, int):
		return value
	if isinstance(value, str) and value.strip().isdigit():
		return int(value.strip())
	return 0


def relative_or_absolute_path(path: Path) -> str:
	try:
		return path.relative_to(ROOT).as_posix()
	except ValueError:
		return path.as_posix()


def collect_package_dependency_cycles(dependency_map: dict[str, list[str]]) -> list[list[str]]:
	visited: set[str] = set()
	visiting: set[str] = set()
	stack: list[str] = []
	cycles: dict[tuple[str, ...], list[str]] = {}

	def visit(package_id: str) -> None:
		if package_id in visiting:
			start = stack.index(package_id)
			cycle = [*stack[start:], package_id]
			cycles[canonical_package_cycle(cycle)] = cycle
			return
		if package_id in visited:
			return
		visiting.add(package_id)
		stack.append(package_id)
		for dependency_id in dependency_map.get(package_id, []):
			visit(dependency_id)
		stack.pop()
		visiting.remove(package_id)
		visited.add(package_id)

	for package_id in sorted(dependency_map.keys()):
		visit(package_id)
	return [cycles[key] for key in sorted(cycles.keys())]


def canonical_package_cycle(cycle: list[str]) -> tuple[str, ...]:
	nodes = cycle[:-1] if len(cycle) > 1 and cycle[0] == cycle[-1] else cycle
	if not nodes:
		return tuple(cycle)
	rotations = [nodes[index:] + nodes[:index] for index in range(len(nodes))]
	best = min(rotations)
	return tuple([*best, best[0]])


def package_dependency_allowed(kind: str, dependency_id: str) -> bool:
	if kind == "kernel":
		return False
	if kind == "standard":
		return dependency_id == "gf.kernel" or dependency_id.startswith("gf.standard.")
	if kind == "extension":
		return dependency_id == "gf.kernel" or dependency_id.startswith("gf.standard.")
	if kind == "tool":
		return (
			dependency_id == "gf.kernel"
			or dependency_id.startswith("gf.standard.")
			or dependency_id.startswith("gf.extension.")
		)
	return False


def package_id_matches_kind(package_id: str, kind: str) -> bool:
	return expected_package_kind_from_id(package_id) == kind


def expected_package_kind_from_id(package_id: str) -> str:
	if package_id == "gf.kernel":
		return "kernel"
	if package_id.startswith("gf.standard."):
		return "standard"
	if package_id.startswith("gf.extension."):
		return "extension"
	if package_id.startswith("gf.preset."):
		return "preset"
	if package_id.startswith("gf.tool."):
		return "tool"
	return ""


def package_manifest_string(data: dict[str, Any], key: str, fallback: str = "") -> str:
	value = data.get(key, fallback)
	if isinstance(value, str):
		return value.strip()
	return fallback


def package_manifest_string_array(data: dict[str, Any], key: str) -> list[str]:
	value = data.get(key, [])
	if isinstance(value, str):
		return [value.strip()] if value.strip() else []
	if not isinstance(value, list):
		return []
	result: list[str] = []
	for item in value:
		if isinstance(item, str) and item.strip():
			result.append(item.strip())
	return result


def validate_package_string_array(
	data: dict[str, Any],
	field_name: str,
	path: str,
	issues: list[dict[str, Any]],
) -> None:
	if field_name not in data:
		return
	value = data[field_name]
	if not isinstance(value, list):
		issues.append(make_package_issue(
			f"invalid_package_{field_name}",
			path,
			f"{field_name} must be an array of non-empty strings.",
			field=field_name,
			expected_value="array[string]",
		))
		return
	for index, item in enumerate(value):
		if isinstance(item, str) and item.strip():
			continue
		issues.append(make_package_issue(
			f"invalid_package_{field_name}",
			path,
			f"{field_name} entries must be non-empty strings.",
			field=field_name,
			row_index=index,
			expected_value="non-empty string",
		))


def normalize_package_manifest_paths(paths: list[str]) -> list[str]:
	result: list[str] = []
	for path in paths:
		normalized_path = normalize_package_manifest_path(path)
		if normalized_path and normalized_path not in result:
			result.append(normalized_path)
	return result


def normalize_package_manifest_path(path: str) -> str:
	normalized_path = path.strip().replace("\\", "/")
	if normalized_path.startswith("res://"):
		normalized_path = normalized_path.removeprefix("res://")
	if normalized_path.startswith("./"):
		normalized_path = normalized_path[2:]
	normalized_path = normalized_path.strip("/")
	if not normalized_path:
		return ""
	if normalized_path.startswith("/") or "://" in normalized_path or ":" in normalized_path:
		return ""
	parts = [part for part in normalized_path.split("/") if part not in ("", ".")]
	if any(part == ".." for part in parts):
		return ""
	return "/".join(parts)


def package_path_is_under_addons_gf(path: str) -> bool:
	normalized_path = path.strip().replace("\\", "/")
	return normalized_path == "addons/gf" or normalized_path.startswith("addons/gf/")


def package_manifest_path_exists(path: str) -> bool:
	anchor = package_path_anchor(path)
	if not anchor:
		return False
	return (ROOT / anchor).exists()


def package_path_anchor(path: str) -> str:
	normalized_path = path.strip().replace("\\", "/").rstrip("/")
	wildcard_index = min(
		[index for index in [
			normalized_path.find("*"),
			normalized_path.find("?"),
			normalized_path.find("["),
		] if index >= 0],
		default=-1,
	)
	if wildcard_index < 0:
		return normalized_path
	prefix = normalized_path[:wildcard_index]
	if not prefix:
		return ""
	if prefix.endswith("/"):
		return prefix.rstrip("/")
	if "/" in prefix:
		return prefix.rsplit("/", 1)[0].rstrip("/")
	return ""


def package_path_ownership_root(path: str) -> str:
	return package_path_anchor(path).rstrip("/")


def package_paths_overlap(left: str, right: str) -> bool:
	left_path = left.strip().replace("\\", "/").rstrip("/")
	right_path = right.strip().replace("\\", "/").rstrip("/")
	if not left_path or not right_path:
		return False
	return (
		left_path == right_path
		or left_path.startswith(right_path + "/")
		or right_path.startswith(left_path + "/")
	)


def make_package_issue(
	kind: str,
	path: str,
	message: str,
	**extra: Any,
) -> dict[str, Any]:
	return make_boundary_issue(kind, path, message, severity="error", **extra)


def load_content_package_manifest_record(path: str, check_resource_exists: bool = False) -> dict[str, Any]:
	issues: list[dict[str, Any]] = []
	record: dict[str, Any] = {
		"path": path,
		"package_id": "",
		"dependencies": [],
		"resource_count": 0,
		"issues": issues,
	}
	source_path = ROOT / path
	try:
		data = json.loads(source_path.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
		issues.append(make_content_package_issue(
			"invalid_content_package_json",
			path,
			"Content package manifest must be a readable UTF-8 JSON object.",
			error=trim_text(str(error), 300),
		))
		return record

	if not isinstance(data, dict):
		issues.append(make_content_package_issue(
			"invalid_content_package_manifest",
			path,
			"Content package manifest root must be a JSON object.",
			expected_value="object",
			actual_value=type(data).__name__,
		))
		return record

	package_id = content_package_string(data, "package_id", content_package_string(data, "id"))
	record["package_id"] = package_id
	issues.extend(audit_content_package_manifest_data(data, path, check_resource_exists))
	record["dependencies"] = content_package_string_list(data, "dependencies", path, issues)
	resources = data.get("resources", [])
	if isinstance(resources, list):
		record["resource_count"] = len(resources)
	return record


def audit_content_package_manifest_data(
	data: dict[str, Any],
	path: str,
	check_resource_exists: bool = False,
) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	for field_name in sorted(data.keys()):
		if field_name not in CONTENT_PACKAGE_ALLOWED_FIELDS:
			issues.append(make_content_package_issue(
				"unsupported_manifest_field",
				path,
				"Content package manifest fields are whitelisted; project-specific data belongs in metadata.",
				field=field_name,
			))

	if "schema_version" in data and not isinstance(data["schema_version"], int):
		issues.append(make_content_package_issue(
			"invalid_schema_version",
			path,
			"schema_version must be an integer when present.",
			field="schema_version",
			expected_value="integer",
		))

	package_id = content_package_string(data, "package_id", content_package_string(data, "id"))
	if not package_id:
		issues.append(make_content_package_issue(
			"missing_package_id",
			path,
			"package_id is required.",
			field="package_id",
		))

	if not content_package_string(data, "version"):
		issues.append(make_content_package_issue(
			"missing_version",
			path,
			"version is required.",
			field="version",
		))

	validate_content_package_string_array(data, "content_types", path, issues)
	validate_content_package_string_array(data, "dependencies", path, issues)
	if "metadata" in data and not isinstance(data["metadata"], dict):
		issues.append(make_content_package_issue(
			"invalid_metadata",
			path,
			"metadata must be an object when present.",
			field="metadata",
			expected_value="object",
		))
	audit_content_package_resources(data, path, check_resource_exists, issues)
	return issues


def validate_content_package_string_array(
	data: dict[str, Any],
	field_name: str,
	path: str,
	issues: list[dict[str, Any]],
) -> None:
	if field_name not in data:
		return
	value = data[field_name]
	if not isinstance(value, list):
		issues.append(make_content_package_issue(
			f"invalid_{field_name}",
			path,
			f"{field_name} must be an array of non-empty strings.",
			field=field_name,
			expected_value="array[string]",
		))
		return
	for index, item in enumerate(value):
		if isinstance(item, str) and item.strip():
			continue
		issues.append(make_content_package_issue(
			f"invalid_{field_name}",
			path,
			f"{field_name} entries must be non-empty strings.",
			field=field_name,
			row_index=index,
			expected_value="non-empty string",
		))


def audit_content_package_resources(
	data: dict[str, Any],
	path: str,
	check_resource_exists: bool,
	issues: list[dict[str, Any]],
) -> None:
	resources = data.get("resources", [])
	if not isinstance(resources, list):
		issues.append(make_content_package_issue(
			"invalid_resources",
			path,
			"resources must be an array.",
			field="resources",
			expected_value="array[object]",
		))
		return

	seen_keys: set[str] = set()
	package_root = content_package_root_path(path)
	for index, raw_entry in enumerate(resources):
		if not isinstance(raw_entry, dict):
			issues.append(make_content_package_issue(
				"invalid_resource_entry",
				path,
				"resource entries must be JSON objects.",
				field="resources",
				row_index=index,
				expected_value="object",
			))
			continue
		entry: dict[str, Any] = raw_entry
		for field_name in sorted(entry.keys()):
			if field_name not in CONTENT_PACKAGE_RESOURCE_ALLOWED_FIELDS:
				issues.append(make_content_package_issue(
					"unsupported_resource_field",
					path,
					"Resource entry fields are whitelisted; project-specific data belongs in metadata.",
					field=field_name,
					row_index=index,
				))

		resource_key = content_package_string(entry, "key", content_package_string(entry, "resource_key"))
		if not resource_key:
			issues.append(make_content_package_issue(
				"invalid_resource_key",
				path,
				"resource key is required.",
				field="resources",
				row_index=index,
			))
		elif resource_key in seen_keys:
			issues.append(make_content_package_issue(
				"duplicate_resource_key",
				path,
				"resource key is duplicated within the same content package.",
				field="resources",
				row_index=index,
				row_key=resource_key,
			))
		else:
			seen_keys.add(resource_key)

		if "type_hint" in entry and not isinstance(entry["type_hint"], str):
			issues.append(make_content_package_issue(
				"invalid_resource_type_hint",
				path,
				"type_hint must be a string when present.",
				field="type_hint",
				row_index=index,
				expected_value="string",
			))
		if "priority" in entry and not isinstance(entry["priority"], int):
			issues.append(make_content_package_issue(
				"invalid_resource_priority",
				path,
				"priority must be an integer when present.",
				field="priority",
				row_index=index,
				expected_value="integer",
			))
		if "metadata" in entry and not isinstance(entry["metadata"], dict):
			issues.append(make_content_package_issue(
				"invalid_resource_metadata",
				path,
				"resource metadata must be an object when present.",
				field="metadata",
				row_index=index,
				expected_value="object",
			))

		raw_resource_path = content_package_string(entry, "path", content_package_string(entry, "resource_path"))
		if not raw_resource_path:
			issues.append(make_content_package_issue(
				"invalid_resource_path",
				path,
				"resource path is required.",
				field="resources",
				row_index=index,
				row_key=resource_key,
			))
			continue
		normalized_resource_path = normalize_content_package_resource_path(raw_resource_path, package_root)
		if not normalized_resource_path:
			issues.append(make_content_package_issue(
				"resource_path_not_allowed",
				path,
				"resource path must be res:// or package-relative.",
				field="resources",
				row_index=index,
				row_key=resource_key,
				actual_value=raw_resource_path,
			))
			continue
		if not is_resource_path_under_root(normalized_resource_path, package_root):
			issues.append(make_content_package_issue(
				"resource_path_outside_package",
				path,
				"resource path must stay inside the content package root.",
				field="resources",
				row_index=index,
				row_key=resource_key,
				actual_value=normalized_resource_path,
				expected_value=package_root,
			))
			continue
		if check_resource_exists and not content_package_resource_exists(normalized_resource_path):
			issues.append(make_content_package_issue(
				"missing_resource_file",
				path,
				"resource file does not exist.",
				field="resources",
				row_index=index,
				row_key=resource_key,
				actual_value=normalized_resource_path,
			))


def audit_content_package_graph(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	package_records: dict[str, list[dict[str, Any]]] = {}
	for record in records:
		package_id = str(record.get("package_id", ""))
		if not package_id:
			continue
		package_records.setdefault(package_id, []).append(record)

	for package_id, duplicate_records in sorted(package_records.items()):
		if len(duplicate_records) < 2:
			continue
		for record in duplicate_records:
			issues.append(make_content_package_issue(
				"duplicate_package_id",
				str(record["path"]),
				"package_id must be unique across scanned content package manifests.",
				field="package_id",
				row_key=package_id,
			))

	package_ids = set(package_records.keys())
	dependency_map: dict[str, list[str]] = {}
	for record in records:
		package_id = str(record.get("package_id", ""))
		if not package_id:
			continue
		dependencies = [str(item) for item in record.get("dependencies", []) if str(item)]
		dependency_map[package_id] = [item for item in dependencies if item in package_ids]
		for dependency_id in dependencies:
			if dependency_id == package_id:
				issues.append(make_content_package_issue(
					"self_dependency",
					str(record["path"]),
					"content package must not depend on itself.",
					field="dependencies",
					row_key=package_id,
					actual_value=dependency_id,
				))
			elif dependency_id not in package_ids:
				issues.append(make_content_package_issue(
					"missing_dependency",
					str(record["path"]),
					"dependency package is missing from scanned content package manifests.",
					field="dependencies",
					row_key=package_id,
					actual_value=dependency_id,
				))

	for cycle in collect_content_package_cycles(dependency_map):
		first_package = cycle[0] if cycle else ""
		cycle_records = package_records.get(first_package, [])
		issue_path = str(cycle_records[0]["path"]) if cycle_records else ""
		issues.append(make_content_package_issue(
			"dependency_cycle",
			issue_path,
			"content package dependency cycle detected.",
			field="dependencies",
			actual_value=" -> ".join(cycle),
		))
	return issues


def collect_content_package_cycles(dependency_map: dict[str, list[str]]) -> list[list[str]]:
	visited: set[str] = set()
	visiting: set[str] = set()
	stack: list[str] = []
	cycles: dict[tuple[str, ...], list[str]] = {}

	def visit(package_id: str) -> None:
		if package_id in visiting:
			start = stack.index(package_id)
			cycle = [*stack[start:], package_id]
			cycles[canonical_content_package_cycle(cycle)] = cycle
			return
		if package_id in visited:
			return
		visiting.add(package_id)
		stack.append(package_id)
		for dependency_id in dependency_map.get(package_id, []):
			visit(dependency_id)
		stack.pop()
		visiting.remove(package_id)
		visited.add(package_id)

	for package_id in sorted(dependency_map.keys()):
		visit(package_id)
	return [cycles[key] for key in sorted(cycles.keys())]


def canonical_content_package_cycle(cycle: list[str]) -> tuple[str, ...]:
	nodes = cycle[:-1] if len(cycle) > 1 and cycle[0] == cycle[-1] else cycle
	if not nodes:
		return tuple(cycle)
	rotations = [nodes[index:] + nodes[:index] for index in range(len(nodes))]
	best = min(rotations)
	return tuple([*best, best[0]])


def content_package_string(data: dict[str, Any], key: str, fallback: str = "") -> str:
	value = data.get(key, fallback)
	if isinstance(value, str):
		return value.strip()
	return fallback


def content_package_string_list(
	data: dict[str, Any],
	field_name: str,
	path: str,
	issues: list[dict[str, Any]],
) -> list[str]:
	value = data.get(field_name, [])
	if not isinstance(value, list):
		return []
	result: list[str] = []
	for item in value:
		if isinstance(item, str) and item.strip():
			result.append(item.strip())
	return result


def content_package_root_path(manifest_path: str) -> str:
	normalized_path = manifest_path.replace("\\", "/")
	if "/" not in normalized_path:
		return "res://"
	root = normalized_path.rsplit("/", 1)[0]
	if not root:
		return "res://"
	return normalize_res_resource_path("res://" + root)


def normalize_content_package_resource_path(path: str, package_root: str) -> str:
	normalized_path = path.strip().replace("\\", "/")
	if not normalized_path:
		return ""
	if normalized_path.startswith("res://"):
		return normalize_res_resource_path(normalized_path)
	if normalized_path.startswith(("uid://", "user://")):
		return ""
	if "://" in normalized_path or ":" in normalized_path or normalized_path.startswith("/"):
		return ""
	root_suffix = "" if package_root == "res://" else package_root.removeprefix("res://").rstrip("/")
	combined = f"res://{normalized_path}" if not root_suffix else f"res://{root_suffix}/{normalized_path}"
	return normalize_res_resource_path(combined)


def normalize_res_resource_path(path: str) -> str:
	normalized_path = path.strip().replace("\\", "/")
	if not normalized_path.startswith("res://"):
		return ""
	suffix = normalized_path.removeprefix("res://")
	parts: list[str] = []
	for raw_part in suffix.split("/"):
		part = raw_part.strip()
		if part in ("", "."):
			continue
		if part == "..":
			if not parts:
				return ""
			parts.pop()
			continue
		parts.append(part)
	return "res://" + "/".join(parts)


def is_resource_path_under_root(path: str, package_root: str) -> bool:
	normalized_path = normalize_res_resource_path(path)
	normalized_root = normalize_res_resource_path(package_root)
	if not normalized_path or not normalized_root:
		return False
	if normalized_root == "res://":
		return normalized_path.startswith("res://")
	root_prefix = normalized_root.rstrip("/")
	return normalized_path == root_prefix or normalized_path.startswith(root_prefix + "/")


def content_package_resource_exists(path: str) -> bool:
	normalized_path = normalize_res_resource_path(path)
	if not normalized_path.startswith("res://"):
		return False
	relative_path = normalized_path.removeprefix("res://")
	return (ROOT / relative_path).exists()


def make_content_package_issue(
	kind: str,
	path: str,
	message: str,
	**extra: Any,
) -> dict[str, Any]:
	return make_boundary_issue(kind, path, message, severity="error", **extra)


def collect_asset_lifecycle_paths() -> dict[str, Any]:
	tracked_paths_result = read_git_paths(["ls-files", "-z", "--cached"])
	untracked_paths_result = read_git_paths(["ls-files", "-z", "--others", "--exclude-standard"])
	errors: list[dict[str, Any]] = []
	if tracked_paths_result["error"]:
		errors.append(make_boundary_issue(
			"asset_lifecycle_tracked_scan_failed",
			"",
			trim_text(tracked_paths_result["error"], 1000),
		))
	if untracked_paths_result["error"]:
		errors.append(make_boundary_issue(
			"asset_lifecycle_untracked_scan_failed",
			"",
			trim_text(untracked_paths_result["error"], 1000),
		))
	if errors:
		return {"paths": [], "errors": errors}

	paths = sorted({
		path
		for path in tracked_paths_result["paths"] + untracked_paths_result["paths"]
		if should_scan_asset_lifecycle_path(path)
	})
	return {"paths": paths, "errors": []}


def should_scan_asset_lifecycle_path(path: str) -> bool:
	normalized_path = path.replace("\\", "/")
	if any(normalized_path.startswith(prefix) for prefix in ASSET_LIFECYCLE_EXCLUDED_PREFIXES):
		return False
	return Path(normalized_path).suffix.lower() in ASSET_LIFECYCLE_SCAN_EXTENSIONS


def audit_asset_lifecycle_text(source: str, path: str) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	lines = source.splitlines()
	for line_index, raw_line in enumerate(lines):
		line = strip_gdscript_line_comment(raw_line)
		stripped = line.strip()
		if not stripped or stripped.startswith("func "):
			continue
		for match in ASSET_HANDLE_CALL_RE.finditer(line):
			statement = collect_gdscript_call_statement(lines, line_index, match.start())
			args_text = extract_gdscript_call_arguments(statement)
			if args_text == "":
				continue
			callee = match.group("callee").split(".")[-1]
			args = split_top_level_arguments(args_text)
			issue = make_asset_lifecycle_issue(path, line_index + 1, callee, args)
			if issue:
				issues.append(issue)
	return issues


def make_asset_lifecycle_issue(
	path: str,
	line_number: int,
	callee: str,
	args: list[str],
) -> dict[str, Any] | None:
	method_shape = ASSET_HANDLE_METHOD_ARGUMENTS.get(callee)
	if method_shape is None:
		return None

	owner_expr = argument_at(args, int(method_shape["owner_index"]))
	group_expr = argument_at(args, int(method_shape["group_index"]))
	if not is_asset_owner_missing(owner_expr) or not is_asset_group_missing(group_expr):
		return None

	path_expr = argument_at(args, int(method_shape["path_index"]))
	return make_boundary_issue(
		"ownerless_ungrouped_asset_handle",
		path,
		"GFAssetHandle acquisition should bind an owner or group, or the caller must release the handle manually.",
		line=line_number,
		severity="warning",
		callee=callee,
		target=trim_text(path_expr, 160),
	)


def argument_at(args: list[str], index: int) -> str:
	if index < 0 or index >= len(args):
		return ""
	return args[index].strip()


def is_asset_owner_missing(expression: str) -> bool:
	stripped = expression.strip()
	return stripped == "" or stripped == "null"


def is_asset_group_missing(expression: str) -> bool:
	stripped = expression.strip()
	return stripped in ("", '&""', '""', "StringName()", "StringName(\"\")", "StringName(&\"\")")


def collect_gdscript_call_statement(lines: list[str], start_index: int, start_column: int) -> str:
	statement_parts: list[str] = []
	balance = 0
	seen_open = False
	for line_index in range(start_index, len(lines)):
		line = strip_gdscript_line_comment(lines[line_index])
		if line_index == start_index:
			line = line[start_column:]
		statement_parts.append(line)
		for character in iter_gdscript_code_characters(line):
			if character == "(":
				balance += 1
				seen_open = True
			elif character == ")":
				balance -= 1
				if seen_open and balance <= 0:
					return "\n".join(statement_parts)
	return "\n".join(statement_parts)


def extract_gdscript_call_arguments(statement: str) -> str:
	open_index = statement.find("(")
	if open_index < 0:
		return ""
	balance = 0
	for index in range(open_index, len(statement)):
		character = statement[index]
		if character == "(":
			balance += 1
		elif character == ")":
			balance -= 1
			if balance == 0:
				return statement[open_index + 1:index]
	return statement[open_index + 1:]


def split_top_level_arguments(args_text: str) -> list[str]:
	args: list[str] = []
	current: list[str] = []
	round_depth = 0
	square_depth = 0
	curly_depth = 0
	in_string = False
	string_quote = ""
	escaped = False
	for character in args_text:
		current.append(character)
		if escaped:
			escaped = False
			continue
		if in_string and character == "\\":
			escaped = True
			continue
		if character in ("'", '"'):
			if not in_string:
				in_string = True
				string_quote = character
			elif character == string_quote:
				in_string = False
				string_quote = ""
			continue
		if in_string:
			continue
		if character == "(":
			round_depth += 1
		elif character == ")":
			round_depth = max(round_depth - 1, 0)
		elif character == "[":
			square_depth += 1
		elif character == "]":
			square_depth = max(square_depth - 1, 0)
		elif character == "{":
			curly_depth += 1
		elif character == "}":
			curly_depth = max(curly_depth - 1, 0)
		elif character == "," and round_depth == 0 and square_depth == 0 and curly_depth == 0:
			current.pop()
			args.append("".join(current).strip())
			current = []
	if current or args_text.strip():
		args.append("".join(current).strip())
	return args


def iter_gdscript_code_characters(line: str) -> list[str]:
	characters: list[str] = []
	in_string = False
	string_quote = ""
	escaped = False
	for character in line:
		if escaped:
			escaped = False
			continue
		if in_string and character == "\\":
			escaped = True
			continue
		if character in ("'", '"'):
			if not in_string:
				in_string = True
				string_quote = character
			elif character == string_quote:
				in_string = False
				string_quote = ""
			continue
		if not in_string:
			characters.append(character)
	return characters


def load_project_profile(profile_path: str = "") -> dict[str, Any]:
	resolved_path = resolve_project_profile_path(profile_path)
	issues: list[dict[str, Any]] = []
	payload: dict[str, Any] = {
		"found": resolved_path != "",
		"path": resolved_path,
		"id": "",
		"data": {},
		"issues": issues,
	}
	if not resolved_path:
		return payload

	profile_file = ROOT / resolved_path
	try:
		data = json.loads(profile_file.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
		issues.append(make_project_profile_issue(
			"invalid_project_profile_json",
			resolved_path,
			"Project profile must be a readable UTF-8 JSON object.",
			error=trim_text(str(error), 300),
		))
		return payload
	if not isinstance(data, dict):
		issues.append(make_project_profile_issue(
			"invalid_project_profile",
			resolved_path,
			"Project profile root must be a JSON object.",
			expected_value="object",
			actual_value=type(data).__name__,
		))
		return payload

	payload["data"] = data
	payload["id"] = project_profile_string(data, "id")
	return payload


def resolve_project_profile_path(profile_path: str = "") -> str:
	if profile_path.strip():
		return normalize_project_profile_path(profile_path)
	for candidate in PROJECT_PROFILE_DEFAULT_FILES:
		path = ROOT / candidate
		if path.is_file():
			return candidate
	return ""


def normalize_project_profile_path(path: str) -> str:
	normalized_path = path.strip().replace("\\", "/")
	if normalized_path.startswith("res://"):
		normalized_path = normalized_path.removeprefix("res://")
	if os.path.isabs(normalized_path):
		try:
			return Path(normalized_path).resolve().relative_to(ROOT).as_posix()
		except ValueError:
			return normalized_path
	normalized_path = normalized_path.removeprefix("./")
	return normalized_path


def collect_project_profile_paths() -> dict[str, Any]:
	tracked_paths_result = read_git_paths(["ls-files", "-z", "--cached"])
	untracked_paths_result = read_git_paths(["ls-files", "-z", "--others", "--exclude-standard"])
	errors: list[dict[str, Any]] = []
	if tracked_paths_result["error"]:
		errors.append(make_project_profile_issue(
			"project_profile_tracked_scan_failed",
			"",
			trim_text(tracked_paths_result["error"], 1000),
		))
	if untracked_paths_result["error"]:
		errors.append(make_project_profile_issue(
			"project_profile_untracked_scan_failed",
			"",
			trim_text(untracked_paths_result["error"], 1000),
		))
	if errors:
		return {"paths": [], "errors": errors}

	paths = sorted({
		path
		for path in tracked_paths_result["paths"] + untracked_paths_result["paths"]
		if should_scan_project_profile_path(path)
	})
	return {"paths": paths, "errors": []}


def should_scan_project_profile_path(path: str) -> bool:
	normalized_path = path.replace("\\", "/")
	if any(normalized_path.startswith(prefix) for prefix in PROJECT_PROFILE_SCAN_EXCLUDED_PREFIXES):
		return False
	return True


def audit_project_profile_data(
	data: dict[str, Any],
	profile_path: str,
	repo_paths: list[str],
) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	issues.extend(audit_project_profile_schema(data, profile_path))
	if issues:
		return issues
	for zone_index, zone in enumerate(project_profile_dict_list(data, "zones")):
		issues.extend(audit_project_profile_zone(zone, zone_index, profile_path, repo_paths))
	for rule_index, rule in enumerate(project_profile_dict_list(data, "rules")):
		issues.extend(audit_project_profile_rule(rule, rule_index, profile_path, repo_paths))
	return issues


def audit_project_profile_schema(data: dict[str, Any], profile_path: str) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	for field_name in sorted(data.keys()):
		if field_name not in PROJECT_PROFILE_ALLOWED_FIELDS:
			issues.append(make_project_profile_issue(
				"unsupported_project_profile_field",
				profile_path,
				"Project profile fields are whitelisted; project-specific data belongs in metadata.",
				field=field_name,
			))
	if "schema_version" in data and not isinstance(data["schema_version"], int):
		issues.append(make_project_profile_issue(
			"invalid_project_profile_schema_version",
			profile_path,
			"schema_version must be an integer when present.",
			field="schema_version",
			expected_value="integer",
		))
	if "metadata" in data and not isinstance(data["metadata"], dict):
		issues.append(make_project_profile_issue(
			"invalid_project_profile_metadata",
			profile_path,
			"metadata must be an object when present.",
			field="metadata",
			expected_value="object",
		))
	for field_name in ("zones", "rules"):
		if field_name in data and not isinstance(data[field_name], list):
			issues.append(make_project_profile_issue(
				f"invalid_project_profile_{field_name}",
				profile_path,
				f"{field_name} must be an array when present.",
				field=field_name,
				expected_value="array",
			))
	for index, zone in enumerate(project_profile_raw_list(data, "zones")):
		if not isinstance(zone, dict):
			issues.append(make_project_profile_issue(
				"invalid_project_profile_zone",
				profile_path,
				"zones entries must be objects.",
				field="zones",
				row_index=index,
				expected_value="object",
			))
			continue
		for field_name in sorted(zone.keys()):
			if field_name not in PROJECT_PROFILE_ZONE_ALLOWED_FIELDS:
				issues.append(make_project_profile_issue(
					"unsupported_project_profile_zone_field",
					profile_path,
					"Zone fields are whitelisted; project-specific data belongs in metadata.",
					field=field_name,
					row_index=index,
				))
		issues.extend(validate_project_profile_severity(zone, profile_path, "zones", index))
	for index, rule in enumerate(project_profile_raw_list(data, "rules")):
		if not isinstance(rule, dict):
			issues.append(make_project_profile_issue(
				"invalid_project_profile_rule",
				profile_path,
				"rules entries must be objects.",
				field="rules",
				row_index=index,
				expected_value="object",
			))
			continue
		for field_name in sorted(rule.keys()):
			if field_name not in PROJECT_PROFILE_RULE_ALLOWED_FIELDS:
				issues.append(make_project_profile_issue(
					"unsupported_project_profile_rule_field",
					profile_path,
					"Rule fields are whitelisted; project-specific data belongs in metadata.",
					field=field_name,
					row_index=index,
				))
		rule_kind = project_profile_string(rule, "kind")
		if rule_kind not in PROJECT_PROFILE_RULE_KINDS:
			issues.append(make_project_profile_issue(
				"unsupported_project_profile_rule_kind",
				profile_path,
				"Project profile rule kind is not supported.",
				field="kind",
				row_index=index,
				actual_value=rule_kind,
			))
		issues.extend(validate_project_profile_severity(rule, profile_path, "rules", index))
	return issues


def validate_project_profile_severity(
	data: dict[str, Any],
	profile_path: str,
	field_name: str,
	row_index: int,
) -> list[dict[str, Any]]:
	severity = project_profile_string(data, "severity", "error")
	if severity in PROJECT_PROFILE_SEVERITIES:
		return []
	return [make_project_profile_issue(
		"invalid_project_profile_severity",
		profile_path,
		"severity must be one of error, warning, or info.",
		field=field_name,
		row_index=row_index,
		actual_value=severity,
	)]


def audit_project_profile_zone(
	zone: dict[str, Any],
	zone_index: int,
	profile_path: str,
	repo_paths: list[str],
) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	zone_id = project_profile_string(zone, "id", f"zone_{zone_index}")
	severity = project_profile_severity(zone)
	roots = normalize_project_profile_paths(project_profile_string_array(zone, "roots"))
	exclude = normalize_project_profile_patterns(project_profile_string_array(zone, "exclude"))
	allow_extensions = normalize_project_profile_extensions(project_profile_string_array(zone, "allow_extensions"))
	deny_extensions = normalize_project_profile_extensions(project_profile_string_array(zone, "deny_extensions"))
	if not roots:
		issues.append(make_project_profile_issue(
			"project_profile_zone_missing_roots",
			profile_path,
			"Project profile zone must declare at least one root.",
			severity=severity,
			field="roots",
			zone_id=zone_id,
			row_index=zone_index,
		))
		return issues
	if project_profile_bool(zone, "required", False):
		for root_path in roots:
			if project_profile_root_exists(root_path, repo_paths):
				continue
			issues.append(make_project_profile_issue(
				"project_profile_required_root_missing",
				profile_path,
				"Required project profile root is missing.",
				severity=severity,
				field="roots",
				zone_id=zone_id,
				row_index=zone_index,
				actual_value=root_path,
			))
	for file_path in repo_paths_under_roots(repo_paths, roots):
		if project_profile_path_matches_any(file_path, exclude):
			continue
		extension = Path(file_path).suffix.lower()
		if allow_extensions and extension not in allow_extensions:
			issues.append(make_project_profile_issue(
				"project_profile_zone_extension_not_allowed",
				file_path,
				"File extension is not allowed in this project profile zone.",
				severity=severity,
				profile_path=profile_path,
				zone_id=zone_id,
				field="allow_extensions",
				actual_value=extension or "<none>",
				expected_value=", ".join(sorted(allow_extensions)),
			))
		if deny_extensions and extension in deny_extensions:
			issues.append(make_project_profile_issue(
				"project_profile_zone_extension_denied",
				file_path,
				"File extension is denied in this project profile zone.",
				severity=severity,
				profile_path=profile_path,
				zone_id=zone_id,
				field="deny_extensions",
				actual_value=extension or "<none>",
			))
	return issues


def audit_project_profile_rule(
	rule: dict[str, Any],
	rule_index: int,
	profile_path: str,
	repo_paths: list[str],
) -> list[dict[str, Any]]:
	rule_kind = project_profile_string(rule, "kind")
	if rule_kind == "path_exists":
		return audit_project_profile_path_exists_rule(rule, rule_index, profile_path, repo_paths)
	if rule_kind == "files_under_roots":
		return audit_project_profile_files_under_roots_rule(rule, rule_index, profile_path, repo_paths)
	if rule_kind == "extension_allowlist":
		return audit_project_profile_extension_rule(rule, rule_index, profile_path, repo_paths, True)
	if rule_kind == "extension_denylist":
		return audit_project_profile_extension_rule(rule, rule_index, profile_path, repo_paths, False)
	return []


def audit_project_profile_path_exists_rule(
	rule: dict[str, Any],
	rule_index: int,
	profile_path: str,
	repo_paths: list[str],
) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	rule_id = project_profile_string(rule, "id", f"rule_{rule_index}")
	severity = project_profile_severity(rule)
	paths = normalize_project_profile_paths(project_profile_string_array(rule, "paths"))
	if not paths:
		return [make_project_profile_issue(
			"project_profile_rule_missing_paths",
			profile_path,
			"path_exists rule must declare paths.",
			severity=severity,
			field="paths",
			rule_id=rule_id,
			row_index=rule_index,
		)]
	if project_profile_bool(rule, "any", False):
		if any(project_profile_path_exists(path, repo_paths) for path in paths):
			return []
		issues.append(make_project_profile_issue(
			"project_profile_any_path_missing",
			profile_path,
			"At least one declared project profile path must exist.",
			severity=severity,
			field="paths",
			rule_id=rule_id,
			row_index=rule_index,
			expected_value=", ".join(paths),
		))
		return issues
	for path in paths:
		if project_profile_path_exists(path, repo_paths):
			continue
		issues.append(make_project_profile_issue(
			"project_profile_path_missing",
			profile_path,
			"Declared project profile path is missing.",
			severity=severity,
			field="paths",
			rule_id=rule_id,
			row_index=rule_index,
			actual_value=path,
		))
	return issues


def audit_project_profile_files_under_roots_rule(
	rule: dict[str, Any],
	rule_index: int,
	profile_path: str,
	repo_paths: list[str],
) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	rule_id = project_profile_string(rule, "id", f"rule_{rule_index}")
	severity = project_profile_severity(rule)
	roots = normalize_project_profile_paths(project_profile_string_array(rule, "roots"))
	include = normalize_project_profile_patterns(project_profile_string_array(rule, "include"))
	exclude = normalize_project_profile_patterns(project_profile_string_array(rule, "exclude"))
	extensions = normalize_project_profile_extensions(project_profile_string_array(rule, "extensions"))
	for file_path in repo_paths:
		if not project_profile_file_selected(file_path, include, exclude, extensions):
			continue
		if project_profile_path_under_any_root(file_path, roots):
			continue
		issues.append(make_project_profile_issue(
			"project_profile_file_outside_roots",
			file_path,
			"Selected file must live under one of the declared roots.",
			severity=severity,
			profile_path=profile_path,
			rule_id=rule_id,
			field="roots",
			expected_value=", ".join(roots),
		))
	return issues


def audit_project_profile_extension_rule(
	rule: dict[str, Any],
	rule_index: int,
	profile_path: str,
	repo_paths: list[str],
	allowlist: bool,
) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	rule_id = project_profile_string(rule, "id", f"rule_{rule_index}")
	severity = project_profile_severity(rule)
	roots = normalize_project_profile_paths(project_profile_string_array(rule, "roots"))
	include = normalize_project_profile_patterns(project_profile_string_array(rule, "include"))
	exclude = normalize_project_profile_patterns(project_profile_string_array(rule, "exclude"))
	extensions = normalize_project_profile_extensions(project_profile_string_array(rule, "extensions"))
	for file_path in repo_paths_under_roots(repo_paths, roots):
		if not project_profile_file_selected(file_path, include, exclude, set()):
			continue
		extension = Path(file_path).suffix.lower()
		if allowlist and extension in extensions:
			continue
		if not allowlist and extension not in extensions:
			continue
		issues.append(make_project_profile_issue(
			"project_profile_extension_not_allowed" if allowlist else "project_profile_extension_denied",
			file_path,
			"File extension violates the project profile rule.",
			severity=severity,
			profile_path=profile_path,
			rule_id=rule_id,
			field="extensions",
			actual_value=extension or "<none>",
			expected_value=", ".join(sorted(extensions)),
		))
	return issues


def project_profile_file_selected(
	file_path: str,
	include: list[str],
	exclude: list[str],
	extensions: set[str],
) -> bool:
	if include and not project_profile_path_matches_any(file_path, include):
		return False
	if exclude and project_profile_path_matches_any(file_path, exclude):
		return False
	if extensions and Path(file_path).suffix.lower() not in extensions:
		return False
	return True


def project_profile_path_matches_any(path: str, patterns: list[str]) -> bool:
	return any(fnmatch.fnmatch(path, pattern) for pattern in patterns)


def repo_paths_under_roots(repo_paths: list[str], roots: list[str]) -> list[str]:
	if not roots:
		return list(repo_paths)
	return [
		path
		for path in repo_paths
		if project_profile_path_under_any_root(path, roots)
	]


def project_profile_path_under_any_root(path: str, roots: list[str]) -> bool:
	return any(project_profile_path_under_root(path, root) for root in roots)


def project_profile_path_under_root(path: str, root: str) -> bool:
	normalized_path = path.strip().replace("\\", "/")
	normalized_root = root.strip().replace("\\", "/").rstrip("/")
	if not normalized_root:
		return True
	return normalized_path == normalized_root or normalized_path.startswith(normalized_root + "/")


def project_profile_root_exists(root_path: str, repo_paths: list[str]) -> bool:
	return project_profile_path_exists(root_path, repo_paths) or any(
		project_profile_path_under_root(path, root_path)
		for path in repo_paths
	)


def project_profile_path_exists(path: str, repo_paths: list[str]) -> bool:
	normalized_path = path.strip().replace("\\", "/").rstrip("/")
	if not normalized_path:
		return True
	if normalized_path in repo_paths:
		return True
	return (ROOT / normalized_path).exists()


def project_profile_raw_list(data: dict[str, Any], key: str) -> list[Any]:
	value = data.get(key, [])
	return value if isinstance(value, list) else []


def project_profile_dict_list(data: dict[str, Any], key: str) -> list[dict[str, Any]]:
	result: list[dict[str, Any]] = []
	for item in project_profile_raw_list(data, key):
		if isinstance(item, dict):
			result.append(item)
	return result


def project_profile_string(data: dict[str, Any], key: str, fallback: str = "") -> str:
	value = data.get(key, fallback)
	if isinstance(value, str):
		return value.strip()
	return fallback


def project_profile_bool(data: dict[str, Any], key: str, fallback: bool = False) -> bool:
	value = data.get(key, fallback)
	if isinstance(value, bool):
		return value
	return fallback


def project_profile_string_array(data: dict[str, Any], key: str) -> list[str]:
	value = data.get(key, [])
	if isinstance(value, str):
		return [value]
	if not isinstance(value, list):
		return []
	result: list[str] = []
	for item in value:
		if isinstance(item, str) and item.strip():
			result.append(item.strip())
	return result


def normalize_project_profile_paths(paths: list[str]) -> list[str]:
	result: list[str] = []
	for path in paths:
		normalized_path = normalize_project_profile_relative_path(path)
		if normalized_path and normalized_path not in result:
			result.append(normalized_path)
	return result


def normalize_project_profile_patterns(patterns: list[str]) -> list[str]:
	result: list[str] = []
	for pattern in patterns:
		normalized_pattern = normalize_project_profile_relative_path(pattern, allow_glob=True)
		if normalized_pattern and normalized_pattern not in result:
			result.append(normalized_pattern)
	return result


def normalize_project_profile_relative_path(path: str, allow_glob: bool = False) -> str:
	normalized_path = path.strip().replace("\\", "/")
	if normalized_path.startswith("res://"):
		normalized_path = normalized_path.removeprefix("res://")
	if normalized_path.startswith("./"):
		normalized_path = normalized_path[2:]
	normalized_path = normalized_path.strip("/")
	if not normalized_path:
		return ""
	if normalized_path.startswith("/") or "://" in normalized_path or ":" in normalized_path:
		return ""
	parts = [part for part in normalized_path.split("/") if part not in ("", ".")]
	if any(part == ".." for part in parts):
		return ""
	if not allow_glob and any(any(character in part for character in "*?[") for part in parts):
		return ""
	return "/".join(parts)


def normalize_project_profile_extensions(extensions: list[str]) -> set[str]:
	result: set[str] = set()
	for extension in extensions:
		normalized_extension = extension.strip().lower()
		if not normalized_extension:
			continue
		if not normalized_extension.startswith("."):
			normalized_extension = "." + normalized_extension
		result.add(normalized_extension)
	return result


def project_profile_severity(data: dict[str, Any]) -> str:
	severity = project_profile_string(data, "severity", "error")
	return severity if severity in PROJECT_PROFILE_SEVERITIES else "error"


def make_project_profile_issue(
	kind: str,
	path: str,
	message: str,
	severity: str = "error",
	**extra: Any,
) -> dict[str, Any]:
	return make_boundary_issue(kind, path, message, severity=severity, **extra)


def audit_resource_boundary_text(source: str, path: str) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	for line_number, raw_line in enumerate(source.splitlines(), start=1):
		line = strip_gdscript_line_comment(raw_line)
		if not line.strip():
			continue
		for match in RESOURCE_LOAD_LITERAL_RE.finditer(line):
			if not gdscript_position_is_code(line, match.start()):
				continue
			target = unescape_gdscript_string_literal(match.group("target"))
			if not target.startswith(RESOURCE_BOUNDARY_DIRECT_PATH_PREFIXES):
				continue
			issues.append(make_resource_boundary_issue(
				path,
				line_number,
				match.group("callee"),
				target,
			))
	return issues


def make_resource_boundary_issue(path: str, line_number: int, callee: str, target: str) -> dict[str, Any]:
	extension = get_resource_target_extension(target)
	source_kind = resource_boundary_source_kind(path)
	if extension == ".gd":
		return make_boundary_issue(
			"direct_script_dependency_load",
			path,
			"Direct script preload/load is allowed for now but remains visible to resource-boundary audits.",
			line=line_number,
			severity="info",
			callee=callee,
			target=target,
			target_extension=extension,
			source_kind=source_kind,
		)
	if target in RESOURCE_BOUNDARY_EDITOR_METADATA_TARGETS:
		return make_boundary_issue(
			"direct_editor_metadata_load",
			path,
			"Editor/plugin metadata load literals are tracked separately from runtime resource loads.",
			line=line_number,
			severity="info",
			callee=callee,
			target=target,
			target_extension=extension,
			source_kind=source_kind,
		)
	if target.startswith("user://"):
		return make_boundary_issue(
			"direct_user_resource_load",
			path,
			"user:// resource load literals are report-only for now; runtime ownership should still be explicit.",
			line=line_number,
			severity="info",
			callee=callee,
			target=target,
			target_extension=extension,
			source_kind=source_kind,
		)
	if target.startswith("uid://"):
		return make_boundary_issue(
			"direct_uid_resource_load",
			path,
			"UID resource load literals bypass stable GF resource keys and should be reviewed before strict mode.",
			line=line_number,
			severity="warning",
			callee=callee,
			target=target,
			target_extension=extension,
			source_kind=source_kind,
		)
	return make_boundary_issue(
		"direct_resource_path_load",
		path,
		"Direct resource path load literals should move toward GFResourceResolverUtility keys or declared resource domains.",
		line=line_number,
		severity="warning",
		callee=callee,
		target=target,
		target_extension=extension,
		source_kind=source_kind,
	)


def resource_boundary_source_kind(path: str) -> str:
	normalized_path = path.replace("\\", "/")
	if normalized_path.startswith("tests/"):
		return "test"
	if normalized_path.startswith("addons/gf/tools/"):
		return "tool"
	if (
		normalized_path.startswith("addons/gf/kernel/editor/")
		or normalized_path.startswith("addons/gf/standard/editor/")
		or "/editor/" in normalized_path
	):
		return "editor"
	if normalized_path.startswith("addons/gf/"):
		return "runtime"
	return "other"


def resource_boundary_source_package(path: str, owner_entries: list[dict[str, str]]) -> str:
	normalized_path = normalize_package_manifest_path(path)
	if not normalized_path:
		return "<other>"
	if normalized_path.startswith("tests/"):
		return "<test>"
	if not normalized_path.startswith("addons/gf/"):
		return "<other>"
	owner = find_package_source_owner(normalized_path, owner_entries)
	if owner:
		return owner["package_id"]
	if not owner_entries:
		return "<unknown>"
	return "<unowned>"


def resource_boundary_target_package(target: str, owner_entries: list[dict[str, str]]) -> str:
	normalized_target = target.strip().replace("\\", "/")
	if normalized_target.startswith("uid://"):
		return "<uid>"
	if normalized_target.startswith("user://"):
		return "<user>"
	if normalized_target.startswith("res://"):
		target_path = normalize_package_manifest_path(normalized_target.removeprefix("res://"))
		if not target_path:
			return "<other>"
		if not target_path.startswith("addons/gf/"):
			return "<project>"
		owner = find_package_source_owner(target_path, owner_entries)
		if owner:
			return owner["package_id"]
		if not owner_entries:
			return "<unknown>"
		return "<unowned>"
	return "<other>"


def count_issue_field(issues: list[dict[str, Any]], field_name: str) -> list[dict[str, Any]]:
	counter: dict[str, int] = {}
	for issue in issues:
		key = str(issue.get(field_name) or "<empty>")
		increment_counter(counter, key)
	return counter_items(counter)


def count_issue_field_pair(
	issues: list[dict[str, Any]],
	left_field_name: str,
	right_field_name: str,
) -> list[dict[str, Any]]:
	counter: dict[tuple[str, str], int] = {}
	for issue in issues:
		left_value = str(issue.get(left_field_name, ""))
		right_value = str(issue.get(right_field_name, ""))
		if not left_value or not right_value:
			continue
		key = (left_value, right_value)
		counter[key] = counter.get(key, 0) + 1
	return [
		{
			"key": f"{left_value} -> {right_value}",
			"source": left_value,
			"target": right_value,
			"count": count,
		}
		for (left_value, right_value), count in sorted(
			counter.items(),
			key=lambda item: (-item[1], item[0][0], item[0][1]),
		)
	]


def count_record_field(records: list[dict[str, Any]], field_name: str) -> list[dict[str, Any]]:
	counter: dict[str, int] = {}
	for record in records:
		key = str(record.get(field_name) or "<empty>")
		increment_counter(counter, key)
	return counter_items(counter)


def strip_gdscript_line_comment(line: str) -> str:
	in_string = False
	string_quote = ""
	escaped = False
	for index, character in enumerate(line):
		if escaped:
			escaped = False
			continue
		if in_string and character == "\\":
			escaped = True
			continue
		if character in ("'", '"'):
			if not in_string:
				in_string = True
				string_quote = character
				continue
			if character == string_quote:
				in_string = False
				string_quote = ""
				continue
		if character == "#" and not in_string:
			return line[:index]
	return line


def gdscript_position_is_code(line: str, target_index: int) -> bool:
	in_string = False
	string_quote = ""
	escaped = False
	for index, character in enumerate(line):
		if index >= target_index:
			return not in_string
		if escaped:
			escaped = False
			continue
		if in_string and character == "\\":
			escaped = True
			continue
		if character in ("'", '"'):
			if not in_string:
				in_string = True
				string_quote = character
				continue
			if character == string_quote:
				in_string = False
				string_quote = ""
				continue
		if character == "#" and not in_string:
			return False
	return not in_string


def unescape_gdscript_string_literal(value: str) -> str:
	return value.replace(r"\/", "/").replace(r"\'", "'").replace(r"\"", '"')


def get_resource_target_extension(target: str) -> str:
	normalized_target = target.split("?", 1)[0].split("#", 1)[0].rstrip("/")
	file_name = normalized_target.rsplit("/", 1)[-1]
	if "." not in file_name:
		return ""
	return "." + file_name.rsplit(".", 1)[1].lower()


def collect_text_files(root: Path, extensions: set[str]) -> list[Path]:
	if not root.is_dir():
		return []
	return [
		path
		for path in sorted(root.rglob("*"))
		if path.is_file() and path.suffix.lower() in extensions
	]


def collect_class_name_roots(root: Path) -> dict[str, str]:
	result: dict[str, str] = {}
	for path in collect_text_files(root, {".gd"}):
		text = read_text_file(path)
		for match in re.finditer(r"(?m)^\s*class_name\s+([A-Za-z_]\w*)", text):
			result[match.group(1)] = path.relative_to(ROOT).as_posix()
	return result


def extract_bundled_extension_names(source: str) -> list[str]:
	names: list[str] = []
	for match in re.finditer(r"(?:res://)?addons/gf/extensions/([A-Za-z0-9_.-]+)", source):
		name = match.group(1).strip()
		if name and name not in names:
			names.append(name)
	return names


def get_bundled_extension_name_from_relative_path(path: str) -> str:
	normalized_path = path.replace("\\", "/")
	prefix = "addons/gf/extensions/"
	if not normalized_path.startswith(prefix):
		return ""
	remaining = normalized_path[len(prefix):]
	if "/" not in remaining:
		return ""
	return remaining.split("/", 1)[0].strip()


def source_contains_identifier(source: str, identifier: str) -> bool:
	return re.search(rf"(?<![A-Za-z0-9_]){re.escape(identifier)}(?![A-Za-z0-9_])", source) is not None


def read_text_file(path: Path) -> str:
	try:
		return path.read_text(encoding="utf-8")
	except OSError:
		return ""


def make_boundary_issue(
	kind: str,
	path: str,
	message: str,
	**extra: Any,
) -> dict[str, Any]:
	issue = {
		"kind": kind,
		"path": path,
		"message": message,
	}
	issue.update({key: value for key, value in extra.items() if value not in ("", None)})
	return issue


def read_git_paths(command: list[str]) -> dict[str, Any]:
	result = subprocess.run(
		["git", *command],
		cwd=ROOT,
		capture_output=True,
	)
	if result.returncode != 0:
		message = (result.stderr or result.stdout).decode("utf-8", errors="replace").strip()
		return {"paths": [], "error": message or "git path scan failed."}
	paths = sorted({
		path.replace("\\", "/")
		for path in result.stdout.decode("utf-8", errors="replace").split("\0")
		if path
	})
	return {"paths": paths, "error": ""}


def find_case_collision_issues(tracked_paths: list[str]) -> list[dict[str, Any]]:
	paths_by_folded_name: dict[str, list[str]] = {}
	for path in tracked_paths:
		paths_by_folded_name.setdefault(path.casefold(), []).append(path)

	issues: list[dict[str, Any]] = []
	for folded_path, paths in sorted(paths_by_folded_name.items()):
		unique_paths = sorted(set(paths))
		if len(unique_paths) <= 1:
			continue
		issues.append({
			"kind": "case_collision",
			"path": folded_path,
			"paths": unique_paths,
			"message": "Tracked paths differ only by case and may overwrite each other on case-insensitive filesystems.",
		})
	return issues


def find_blocked_tracked_dir_issues(tracked_paths: list[str]) -> list[dict[str, Any]]:
	blocked_names = set(BLOCKED_PACKAGE_DIR_NAMES)
	blocked_paths: set[str] = set()
	for path in tracked_paths:
		parts = path.split("/")
		for index, part in enumerate(parts[:-1]):
			if part in blocked_names:
				blocked_paths.add("/".join(parts[:index + 1]))

	return [
		{
			"kind": "blocked_tracked_directory",
			"path": path,
			"message": "Tracked files live inside a cache or dependency directory that should not ship with GF.",
		}
		for path in sorted(blocked_paths)
	]


def find_missing_local_github_action_issues(scanned_paths: list[str]) -> list[dict[str, Any]]:
	scanned_path_set = set(scanned_paths)
	workflow_paths = [
		path for path in scanned_paths
		if path.startswith(".github/workflows/")
		and Path(path).suffix.lower() in {".yml", ".yaml"}
	]
	issues: list[dict[str, Any]] = []
	for workflow_path in workflow_paths:
		source = read_text_file(ROOT / workflow_path)
		for line_number, line in enumerate(source.splitlines(), start=1):
			match = re.search(r"\buses:\s*['\"]?(\./\.github/actions/[A-Za-z0-9_.\-/]+)['\"]?", line)
			if match is None:
				continue
			action_path = match.group(1).removeprefix("./").rstrip("/")
			action_manifest_path = f"{action_path}/action.yml"
			if action_manifest_path in scanned_path_set or (ROOT / action_manifest_path).is_file():
				continue
			issues.append({
				"kind": "missing_local_github_action_manifest",
				"path": workflow_path,
				"line": line_number,
				"message": f"Workflow references {match.group(1)} but {action_manifest_path} is missing.",
			})
	return issues


def find_gdscript_utf8_bom_issues(scanned_paths: list[str]) -> list[dict[str, Any]]:
	issues: list[dict[str, Any]] = []
	for path in scanned_paths:
		if not path.endswith(".gd"):
			continue
		source_path = ROOT / path
		if not source_path.is_file():
			continue
		try:
			with source_path.open("rb") as file:
				prefix = file.read(3)
		except OSError as exc:
			issues.append({
				"kind": "gdscript_source_unreadable",
				"path": path,
				"message": f"Could not read GDScript source while checking encoding: {exc}",
			})
			continue
		if has_utf8_bom(prefix):
			issues.append({
				"kind": "gdscript_utf8_bom",
				"path": path,
				"message": "GDScript files must be UTF-8 without BOM.",
			})
	return issues


def has_utf8_bom(data: bytes) -> bool:
	return data.startswith(b"\xef\xbb\xbf")


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
	if normalized.startswith("docs/") or normalized in {"README.md", "README.zh.md", "addons/gf/README.md", "mkdocs.yml"}:
		return "manual_docs"
	if (
		normalized.startswith(".codex/")
		or normalized.startswith("tools/")
		or normalized.startswith("packages/")
		or normalized in {"AI_MAINTENANCE.md", "CODING_STYLE.md", "API_SURFACE.md"}
		or normalized in PROJECT_PROFILE_DEFAULT_FILES
	):
		return "maintenance_tools"
	if (
		normalized in {"ASSET_LIBRARY.md", "ASSET_STORE.md", ".gitattributes"}
		or normalized == "addons/gf/plugin.cfg"
		or normalized.endswith("/gf_extension.json")
	):
		return "release_metadata"
	if normalized.startswith("addons/gf/tools/"):
		return "tool_source"
	if normalized.startswith("addons/gf/"):
		return "runtime_source"
	return "other"


def recommend_checks(categories: dict[str, list[dict[str, str]]]) -> list[str]:
	recommendations: list[str] = []
	if categories["runtime_source"] or categories["tool_source"]:
		recommendations.extend([
			"python tools/generate_api_reference.py --check",
			"python tools/generate_ai_api.py --source addons/gf --output ai_analysis/generated_api --check --check-wiki-coverage",
			"python tools/gf_maintenance.py public-api-boundary --json",
			"python tools/gf_maintenance.py api-since-touched --json",
			"godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gf_core -ginclude_subdirs -gexit",
			"python tools/gf_maintenance.py check --check gdscript_warnings --json",
			"python tools/gf_maintenance.py dependency-boundary --json",
			"python tools/gf_maintenance.py resource-boundary --json",
			"python tools/gf_maintenance.py content-package-boundary --json",
			"python tools/gf_maintenance.py asset-lifecycle-boundary --json",
			"python tools/gf_maintenance.py project-profile-boundary --json",
			"python tools/gf_maintenance.py check --suite package --json",
			"python tools/gf_maintenance.py package-godot-smoke --json",
		])
	if categories["examples"]:
		recommendations.append("python tools/gf_maintenance.py check --suite examples --json")
	if categories["tests"]:
		recommendations.append("godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gf_core -ginclude_subdirs -gexit")
	if categories["manual_docs"]:
		recommendations.extend([
			"python tools/check_docs_quality.py --strict",
			"python tools/gf_maintenance.py public-docs-boundary --json",
			"python -m mkdocs build --strict",
		])
	if categories["generated_docs"]:
		recommendations.append("python tools/generate_api_reference.py --check")
		recommendations.append("python tools/gf_maintenance.py public-api-boundary --json")
		recommendations.append("python tools/gf_maintenance.py api-baseline-diff --json")
	if categories["maintenance_tools"]:
		recommendations.extend([
			"python -m py_compile tools/gf_maintenance.py tools/gf_mcp_server.py",
			"python tools/gf_maintenance.py api-since-touched --json",
			"python tools/gf_maintenance.py resource-boundary --json",
			"python tools/gf_maintenance.py content-package-boundary --json",
			"python tools/gf_maintenance.py asset-lifecycle-boundary --json",
			"python tools/gf_maintenance.py project-profile-boundary --json",
			"python tools/gf_maintenance.py check --suite package --json",
			"python tools/gf_maintenance.py package-godot-smoke --json",
			"python tools/gf_maintenance.py check --check package_godot_matrix_smoke --json",
			"python tools/gf_maintenance.py check --suite quick --json",
		])
	if categories["release_metadata"]:
		recommendations.append("python tools/gf_maintenance.py release-status --json")
		recommendations.append("python tools/gf_maintenance.py api-baseline-diff --json")
		recommendations.append("python tools/gf_maintenance.py dependency-boundary --json")
		recommendations.append("python tools/gf_maintenance.py content-package-boundary --json")
		recommendations.append("python tools/gf_maintenance.py project-profile-boundary --json")
		recommendations.append("python tools/gf_maintenance.py check --suite package --json")
		recommendations.append("python tools/gf_maintenance.py check --check package_godot_matrix_smoke --json")
		recommendations.append("python tools/gf_maintenance.py public-docs-boundary --json")
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
	allow_breaking_api: bool = False,
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
			status = release_status("", allow_breaking_api=allow_breaking_api)
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
		ensure_log_file_parent(command)
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
		has_script_error: bool = has_godot_script_error(completed.stdout, completed.stderr)
		has_reload_warning: bool = has_gdscript_reload_warning(completed.stdout, completed.stderr)
		exit_leak_warnings: list[str] = collect_godot_exit_leak_warnings(completed.stdout, completed.stderr)
		exit_leak_report: dict[str, Any] | None = None
		if name in {"gut", "gdscript_warnings", "examples_scan", "examples_boot", "examples_smoke"}:
			exit_leak_report = godot_exit_leak_report_from_output(name, completed.stdout, completed.stderr)
		if name in {"gut", "gdscript_warnings", "examples_scan", "examples_boot", "examples_smoke"} and has_script_error:
			exit_code = 1
			notes = append_note(
				notes,
				"Godot reported script loading or parse errors in output.",
			)
		if name in {"gut", "gdscript_warnings"} and has_reload_warning:
			exit_code = 1
			notes = append_note(
				notes,
				"Godot reported GDScript reload warnings in output.",
			)
		if exit_leak_warnings:
			notes = append_note(
				notes,
				(
					"Godot reported exit leak warnings. Current policy records these as cleanup debt "
					"but does not fail the check until the baseline is cleaned."
				),
			)
		if (
			name == "gut"
			and not has_script_error
			and not has_reload_warning
			and exit_code == completed.returncode
			and completed.returncode != 0
			and gut_report_all_tests_passed(completed.stdout)
		):
			exit_code = 0
			notes = append_note(
				notes,
				"Godot returned a non-zero process code after GUT reported all tests passed; "
				"the original code is preserved as process_exit_code.",
			)
		return CommandResult(
			name,
			command,
			exit_code,
			completed.stdout,
			completed.stderr,
			process_exit_code=completed.returncode,
			notes=notes,
			godot_exit_leak_warnings=exit_leak_warnings,
			godot_exit_leak_report=exit_leak_report if exit_leak_report != None and exit_leak_report["has_leaks"] else None,
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


def ensure_log_file_parent(command: list[str]) -> None:
	for index, argument in enumerate(command):
		if argument != "--log-file" or index + 1 >= len(command):
			continue
		log_path_text = command[index + 1]
		if log_path_text.startswith(("res://", "user://")):
			continue
		log_path = Path(log_path_text)
		if not log_path.is_absolute():
			log_path = ROOT / log_path
		log_path.parent.mkdir(parents=True, exist_ok=True)


def has_godot_script_error(stdout: str, stderr: str) -> bool:
	output = f"{stdout}\n{stderr}"
	return any(pattern in output for pattern in GODOT_SCRIPT_ERROR_PATTERNS)


def has_gdscript_reload_warning(stdout: str, stderr: str) -> bool:
	output = f"{stdout}\n{stderr}"
	return any(pattern in output for pattern in GDSCRIPT_RELOAD_WARNING_PATTERNS)


def collect_godot_exit_leak_warnings(stdout: str, stderr: str) -> list[str]:
	lines: list[str] = []
	for line in f"{stdout}\n{stderr}".splitlines():
		normalized_line = line.lower()
		if any(pattern in normalized_line for pattern in GODOT_EXIT_LEAK_PATTERNS):
			lines.append(trim_text(line.strip(), 240))
	return lines


def godot_exit_leak_report(log_paths: list[str]) -> dict[str, Any]:
	resolved_paths = [resolve_log_path(path_text) for path_text in log_paths]
	if not resolved_paths:
		resolved_paths = [
			GODOT_LOG_DIR / "gdscript_warnings.log",
			GODOT_LOG_DIR / "gut.log",
		]

	report = make_empty_godot_exit_leak_report()
	for path in resolved_paths:
		path_payload = parse_godot_exit_leak_log(path)
		report["logs"].append(path_payload)
		if not path_payload["exists"]:
			report["missing_logs"].append(path_payload["path"])
			continue
		merge_godot_exit_leak_payload(report, path_payload)

	report["ok"] = len(report["missing_logs"]) == 0
	return finalize_godot_exit_leak_report(report)


def godot_exit_leak_report_from_output(name: str, stdout: str, stderr: str) -> dict[str, Any]:
	report = make_empty_godot_exit_leak_report()
	for stream_name, text in (
		(f"{name}:stdout", stdout),
		(f"{name}:stderr", stderr),
	):
		stream_payload = parse_godot_exit_leak_text(stream_name, text)
		report["logs"].append(stream_payload)
		merge_godot_exit_leak_payload(report, stream_payload)
	report["ok"] = True
	return finalize_godot_exit_leak_report(report)


def finalize_godot_exit_leak_report(report: dict[str, Any]) -> dict[str, Any]:
	report["has_leaks"] = (
		report["objectdb_warning_count"] > 0
		or report["resource_summary_count"] > 0
		or report["resource_still_in_use_count"] > 0
		or report["rid_allocation_total"] > 0
		or report["leaked_instance_total"] > 0
	)
	report["rid_allocations"] = counter_items(report.pop("_rid_allocations"))
	report["leaked_instance_types"] = counter_items(report.pop("_leaked_instance_types"))
	report["resource_type_counts"] = counter_items(report.pop("_resource_type_counts"))
	report["resource_path_prefix_counts"] = counter_items(report.pop("_resource_path_prefix_counts"))
	return report


def make_empty_godot_exit_leak_report() -> dict[str, Any]:
	return {
		"ok": True,
		"root": str(ROOT),
		"logs": [],
		"missing_logs": [],
		"has_leaks": False,
		"line_count": 0,
		"warning_lines": [],
		"objectdb_warning_count": 0,
		"resource_summary_count": 0,
		"resource_summary_total": 0,
		"resource_still_in_use_count": 0,
		"resource_paths_sample": [],
		"rid_allocation_total": 0,
		"leaked_instance_total": 0,
		"_rid_allocations": {},
		"_leaked_instance_types": {},
		"_resource_type_counts": {},
		"_resource_path_prefix_counts": {},
	}


def resolve_log_path(path_text: str) -> Path:
	path = Path(path_text)
	if path.is_absolute():
		return path
	return ROOT / path


def parse_godot_exit_leak_log(path: Path) -> dict[str, Any]:
	payload = make_empty_godot_exit_leak_report()
	payload["path"] = str(path)
	payload["exists"] = path.exists()
	if not path.exists():
		payload["ok"] = False
		payload["has_leaks"] = False
		return finalize_godot_exit_leak_report(payload)

	try:
		text = path.read_text(encoding="utf-8", errors="replace")
	except OSError as exc:
		payload["ok"] = False
		payload["exists"] = False
		payload["error"] = str(exc)
		return finalize_godot_exit_leak_report(payload)

	return parse_godot_exit_leak_text(str(path), text)


def parse_godot_exit_leak_text(source_name: str, text: str) -> dict[str, Any]:
	payload = make_empty_godot_exit_leak_report()
	payload["path"] = source_name
	payload["exists"] = True
	for line in text.splitlines():
		payload["line_count"] += 1
		parse_godot_exit_leak_line(line, payload)
	return finalize_godot_exit_leak_report(payload)


def parse_godot_exit_leak_line(raw_line: str, payload: dict[str, Any]) -> None:
	line = strip_ansi_codes(raw_line).strip()
	if not line:
		return
	normalized_line = line.lower()
	if any(pattern in normalized_line for pattern in GODOT_EXIT_LEAK_PATTERNS):
		append_limited(payload["warning_lines"], trim_text(line, 240), 40)

	if "objectdb instances leaked at exit" in normalized_line:
		payload["objectdb_warning_count"] += 1
		return

	rid_match = GODOT_RID_LEAK_RE.match(line)
	if rid_match != None:
		count = int(rid_match.group("count"))
		rid_type = rid_match.group("type")
		payload["rid_allocation_total"] += count
		increment_counter(payload["_rid_allocations"], rid_type, count)
		return

	resource_summary_match = GODOT_RESOURCE_SUMMARY_RE.match(line)
	if resource_summary_match != None:
		payload["resource_summary_count"] += 1
		payload["resource_summary_total"] += int(resource_summary_match.group("count"))
		return

	resource_match = GODOT_RESOURCE_STILL_IN_USE_RE.match(line)
	if resource_match != None:
		resource_path = resource_match.group("path")
		resource_type = resource_match.group("type")
		payload["resource_still_in_use_count"] += 1
		increment_counter(payload["_resource_type_counts"], resource_type)
		increment_counter(payload["_resource_path_prefix_counts"], classify_resource_path_prefix(resource_path))
		append_limited(payload["resource_paths_sample"], resource_path, 30)
		return

	instance_match = GODOT_LEAKED_INSTANCE_RE.match(line)
	if instance_match != None:
		payload["leaked_instance_total"] += 1
		increment_counter(payload["_leaked_instance_types"], instance_match.group("type"))


def merge_godot_exit_leak_payload(report: dict[str, Any], payload: dict[str, Any]) -> None:
	report["line_count"] += payload["line_count"]
	report["objectdb_warning_count"] += payload["objectdb_warning_count"]
	report["resource_summary_count"] += payload["resource_summary_count"]
	report["resource_summary_total"] += payload["resource_summary_total"]
	report["resource_still_in_use_count"] += payload["resource_still_in_use_count"]
	report["rid_allocation_total"] += payload["rid_allocation_total"]
	report["leaked_instance_total"] += payload["leaked_instance_total"]
	for line in payload["warning_lines"]:
		append_limited(report["warning_lines"], line, 80)
	for resource_path in payload["resource_paths_sample"]:
		append_limited(report["resource_paths_sample"], resource_path, 40)
	merge_counter_items(report["_rid_allocations"], payload.get("rid_allocations", []))
	merge_counter_items(report["_leaked_instance_types"], payload.get("leaked_instance_types", []))
	merge_counter_items(report["_resource_type_counts"], payload.get("resource_type_counts", []))
	merge_counter_items(report["_resource_path_prefix_counts"], payload.get("resource_path_prefix_counts", []))


def classify_resource_path_prefix(resource_path: str) -> str:
	normalized_path = resource_path.replace("\\", "/")
	if normalized_path.startswith("res://addons/gf/"):
		parts = normalized_path[len("res://addons/gf/"):].split("/")
		if parts:
			return f"res://addons/gf/{parts[0]}"
	if normalized_path.startswith("res://addons/gut/"):
		return "res://addons/gut"
	if normalized_path.startswith("res://tests/gf_core/"):
		parts = normalized_path[len("res://tests/gf_core/"):].split("/")
		if parts:
			return f"res://tests/gf_core/{parts[0]}"
	if normalized_path.startswith("res://addons/"):
		parts = normalized_path[len("res://addons/"):].split("/")
		if parts:
			return f"res://addons/{parts[0]}"
	if normalized_path.startswith("res://"):
		parts = normalized_path[len("res://"):].split("/")
		if parts:
			return f"res://{parts[0]}"
	if normalized_path.startswith("user://"):
		return "user://"
	return "<external>"


def strip_ansi_codes(text: str) -> str:
	return ANSI_ESCAPE_RE.sub("", text)


def increment_counter(counter: dict[str, int], key: str, count: int = 1) -> None:
	counter[key] = counter.get(key, 0) + count


def merge_counter_items(counter: dict[str, int], items: list[dict[str, Any]]) -> None:
	for item in items:
		increment_counter(counter, str(item["key"]), int(item["count"]))


def counter_items(counter: dict[str, int]) -> list[dict[str, Any]]:
	return [
		{"key": key, "count": count}
		for key, count in sorted(counter.items(), key=lambda item: (-item[1], item[0]))
	]


def append_limited(items: list[str], value: str, limit: int) -> None:
	if len(items) >= limit:
		return
	items.append(value)


def append_note(notes: list[str] | None, note: str) -> list[str]:
	if notes == None:
		return [note]
	notes.append(note)
	return notes


def gut_report_all_tests_passed(stdout: str) -> bool:
	if "All tests passed!" in stdout:
		return True
	for match in re.finditer(r"(?m)^\s*(\d+)\s*/\s*(\d+)\s+passed\.\s*$", stdout):
		passing = int(match.group(1))
		total = int(match.group(2))
		if total > 0 and passing == total:
			return True
	return False


def release_status(
	expected_version: str = "",
	allow_dirty: bool = False,
	allow_breaking_api: bool = False,
) -> dict[str, Any]:
	plugin_audit = audit_plugin_cfg()
	plugin_version = plugin_audit["version"]
	version = expected_version.strip() or plugin_version
	issues: list[str] = []
	dirty_files = git_lines(["status", "--porcelain", "--untracked-files=all"])
	if dirty_files and not allow_dirty:
		issues.append(
			f"Worktree is dirty ({len(dirty_files)} changed path(s)); commit or stash changes before release, "
			"or pass --allow-dirty only for local diagnostics."
		)
	if SEMVER_RE.match(version) is None:
		issues.append(f"Expected version {version!r} is not SemVer MAJOR.MINOR.PATCH.")
	if plugin_version != version:
		issues.append(f"addons/gf/plugin.cfg version is {plugin_version!r}, expected {version!r}.")
	unresolved_since_markers = read_unresolved_since_markers()
	if unresolved_since_markers:
		issues.append(format_unresolved_since_issue(unresolved_since_markers))
	future_since_markers = read_future_since_markers(version)
	if future_since_markers:
		issues.append(format_future_since_issue(version, future_since_markers))
	api_diff = api_baseline_diff("", version, enforce_version=not allow_breaking_api)
	for api_issue in api_diff.get("issues", []):
		issues.append(f"API baseline diff: {api_issue}")
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
	asset_library_preview_todos = read_asset_library_preview_todos()
	if asset_library_preview_todos:
		examples = ", ".join(
			f"line {entry['line']}: {entry['text']}"
			for entry in asset_library_preview_todos[:4]
		)
		remaining = len(asset_library_preview_todos) - min(len(asset_library_preview_todos), 4)
		suffix = f"; and {remaining} more" if remaining > 0 else ""
		issues.append(f"ASSET_LIBRARY.md preview asset fields still contain TODO: {examples}{suffix}.")

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

	package_archive = make_skipped_package_archive("dirty worktree") if dirty_files and not allow_dirty else audit_package_archive(version)
	if not package_archive.get("skipped", False):
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
		if not package_archive["modular_package_registry"].get("ok", False):
			issues.extend(
				"Modular package release registry is invalid: " + issue
				for issue in package_archive["modular_package_registry"].get("issues", [])
			)

	tag_exists = git_exit_code(["rev-parse", "-q", "--verify", f"refs/tags/{version}"]) == 0
	tag_points_at_head = version in git_lines(["tag", "--points-at", "HEAD"])
	return {
		"ok": len(issues) == 0,
		"version": version,
		"issues": issues,
		"allow_dirty": allow_dirty,
		"allow_breaking_api": allow_breaking_api,
		"worktree_dirty": len(dirty_files) > 0,
		"dirty_file_count": len(dirty_files),
		"dirty_files": dirty_files[:80],
		"unresolved_since_count": len(unresolved_since_markers),
		"unresolved_since_markers": unresolved_since_markers[:80],
		"future_since_count": len(future_since_markers),
		"future_since_markers": future_since_markers[:80],
		"api_baseline_diff": {
			"base_tag": api_diff.get("base_tag", ""),
			"summary": api_diff.get("summary", {}),
			"issues": api_diff.get("issues", []),
			"diff": {
				"added_classes": api_diff.get("diff", {}).get("added_classes", [])[:80],
				"removed_classes": api_diff.get("diff", {}).get("removed_classes", [])[:80],
				"added_members": api_diff.get("diff", {}).get("added_members", [])[:80],
				"removed_members": api_diff.get("diff", {}).get("removed_members", [])[:80],
				"signature_changes": api_diff.get("diff", {}).get("signature_changes", [])[:80],
				"breaking_signature_changes": api_diff.get("diff", {}).get("breaking_signature_changes", [])[:80],
				"compatible_signature_changes": api_diff.get("diff", {}).get("compatible_signature_changes", [])[:80],
				"extends_changes": api_diff.get("diff", {}).get("extends_changes", [])[:80],
			},
		},
		"plugin_version": plugin_version,
		"plugin": plugin_audit,
		"asset_library": asset_fields,
		"asset_library_preview_todos": asset_library_preview_todos,
		"asset_store": asset_store,
		"extension_count": len(extension_versions),
		"extension_mismatches": extension_mismatches,
		"changelog_versions": changelog_versions[:5],
		"package_archive": package_archive,
		"tag_exists": tag_exists,
		"tag_points_at_head": tag_points_at_head,
	}


def parse_semver(value: str) -> tuple[int, int, int] | None:
	match = SEMVER_RE.match(value)
	if match is None:
		return None
	return (int(match.group(1)), int(match.group(2)), int(match.group(3)))


def read_future_since_markers(version: str) -> list[dict[str, Any]]:
	release_version = parse_semver(version)
	if release_version is None:
		return []

	entries: list[dict[str, Any]] = []
	source_root = ROOT / "addons/gf"
	for path in sorted(source_root.rglob("*.gd")):
		if not path.is_file():
			continue
		try:
			lines = path.read_text(encoding="utf-8").splitlines()
		except OSError:
			continue
		for line_number, line in enumerate(lines, start=1):
			for match in SINCE_VERSION_RE.finditer(line):
				since_version = match.group("version")
				since_parts = parse_semver(since_version)
				if since_parts is not None and since_parts > release_version:
					entries.append({
						"path": path.relative_to(ROOT).as_posix(),
						"line": line_number,
						"since": since_version,
						"text": trim_text(line.strip(), 180),
					})
	return entries


def read_unresolved_since_markers() -> list[dict[str, Any]]:
	entries: list[dict[str, Any]] = []
	source_root = ROOT / "addons/gf"
	for path in sorted(source_root.rglob("*.gd")):
		if not path.is_file():
			continue
		try:
			lines = path.read_text(encoding="utf-8").splitlines()
		except OSError:
			continue
		for line_number, line in enumerate(lines, start=1):
			for match in SINCE_TAG_RE.finditer(line):
				since_value = match.group("value").strip().rstrip(".,;")
				if SEMVER_RE.match(since_value) is None:
					entries.append({
						"path": path.relative_to(ROOT).as_posix(),
						"line": line_number,
						"since": since_value,
						"text": trim_text(line.strip(), 180),
					})
	return entries


def format_future_since_issue(version: str, entries: list[dict[str, Any]]) -> str:
	examples = [
		f"{entry['path']}:{entry['line']} @since {entry['since']}"
		for entry in entries[:8]
	]
	remaining = len(entries) - len(examples)
	suffix = f"; and {remaining} more" if remaining > 0 else ""
	return (
		f"{len(entries)} @since marker(s) are newer than release {version}: "
		+ ", ".join(examples)
		+ suffix
	)


def format_unresolved_since_issue(entries: list[dict[str, Any]]) -> str:
	examples = [
		f"{entry['path']}:{entry['line']} @since {entry['since']}"
		for entry in entries[:8]
	]
	remaining = len(entries) - len(examples)
	suffix = f"; and {remaining} more" if remaining > 0 else ""
	return (
		f"{len(entries)} unresolved @since marker(s) must be replaced with a release SemVer before release: "
		+ ", ".join(examples)
		+ suffix
	)


def make_skipped_package_archive(reason: str) -> dict[str, Any]:
	return {
		"skipped": True,
		"skip_reason": reason,
		"gitattributes_exists": (ROOT / ".gitattributes").exists(),
		"required_export_ignore_rules": list(ARCHIVE_EXPORT_IGNORE_RULES),
		"missing_export_ignore_rules": [],
		"blocked_package_dirs": [],
		"asset_store_package": {
			"ok": True,
			"skipped": True,
			"issues": [],
			"reason": reason,
		},
		"modular_package_registry": {
			"ok": True,
			"skipped": True,
			"issues": [],
			"reason": reason,
		},
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


def read_asset_library_preview_todos() -> list[dict[str, Any]]:
	path = ROOT / "ASSET_LIBRARY.md"
	if not path.exists():
		return []
	lines = path.read_text(encoding="utf-8").splitlines()
	in_preview_section = False
	todos: list[dict[str, Any]] = []
	for line_number, line in enumerate(lines, start=1):
		if line.startswith("## "):
			in_preview_section = line.strip() == "## Preview Assets"
			continue
		if not in_preview_section or "TODO" not in line:
			continue
		todos.append({
			"line": line_number,
			"text": trim_text(line.strip(), 180),
		})
	return todos


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
		"skipped": False,
		"gitattributes_exists": gitattributes_path.exists(),
		"required_export_ignore_rules": list(ARCHIVE_EXPORT_IGNORE_RULES),
		"missing_export_ignore_rules": [
			rule for rule in ARCHIVE_EXPORT_IGNORE_RULES
			if rule not in gitattributes_lines
		],
		"blocked_package_dirs": find_blocked_package_dirs(ROOT / "addons/gf"),
		"asset_store_package": audit_asset_store_package(version),
		"modular_package_registry": audit_release_package_registry(version),
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


def audit_release_package_registry(version: str) -> dict[str, Any]:
	script_path = ROOT / "tools/build_gf_package.py"
	archive_base_url = release_package_archive_base_url(version)
	registry_url = release_package_registry_url(version)
	if not script_path.is_file():
		return {
			"ok": False,
			"version": version,
			"archive_base_url": archive_base_url,
			"registry_url": registry_url,
			"issues": ["tools/build_gf_package.py is missing."],
		}

	with tempfile.TemporaryDirectory(prefix="gf-release-package-registry-") as temp_dir:
		temp_root = Path(temp_dir)
		output_dir = temp_root / "packages"
		registry_path = temp_root / f"gf-registry-{version}.json"
		registry_source_path = temp_root / "gf-registry-source.json"
		completed = subprocess.run(
			[
				sys.executable,
				"tools/build_gf_package.py",
				"--all",
				"--version",
				version,
				"--output-dir",
				str(output_dir),
				"--registry",
				str(registry_path),
				"--archive-base-url",
				archive_base_url,
				"--registry-source",
				str(registry_source_path),
				"--registry-source-registry-url",
				registry_url,
				"--json",
			],
			cwd=ROOT,
			capture_output=True,
			text=True,
			encoding="utf-8",
			errors="replace",
			timeout=120,
		)
		if completed.returncode != 0:
			return {
				"ok": False,
				"version": version,
				"archive_base_url": archive_base_url,
				"registry_url": registry_url,
				"registry": registry_path.as_posix(),
				"registry_source": registry_source_path.as_posix(),
				"issues": [
					"tools/build_gf_package.py failed for release registry.",
					trim_text(completed.stdout.strip() or completed.stderr.strip(), 1000),
				],
			}
		try:
			builder_data = json.loads(completed.stdout or "{}")
		except json.JSONDecodeError as exc:
			return {
				"ok": False,
				"version": version,
				"archive_base_url": archive_base_url,
				"registry_url": registry_url,
				"registry": registry_path.as_posix(),
				"registry_source": registry_source_path.as_posix(),
				"issues": [f"tools/build_gf_package.py returned invalid JSON: {exc}"],
			}

		package_build_issues = audit_package_build_result(builder_data, registry_path)
		issues = [
			"package-build-boundary: " + format_package_build_issue_for_release(issue)
			for issue in package_build_issues
		]
		issues.extend(audit_release_package_registry_metadata(builder_data, registry_path, version, archive_base_url))
		issues.extend(audit_release_package_registry_source_manifest(registry_source_path, version, registry_url, registry_path))
		offline_bundle = audit_release_package_offline_bundle(version, temp_root)
		issues.extend(
			"offline bundle: " + issue
			for issue in offline_bundle.get("issues", [])
		)
		packages = builder_data.get("packages", []) if isinstance(builder_data.get("packages", []), list) else []
		archive_count = len([package for package in packages if isinstance(package, dict) and str(package.get("kind", "")) != "preset"])
		preset_count = len([package for package in packages if isinstance(package, dict) and str(package.get("kind", "")) == "preset"])
		return {
			"ok": len(issues) == 0,
			"version": version,
			"archive_base_url": archive_base_url,
			"registry_url": registry_url,
			"registry": registry_path.as_posix(),
			"registry_source": registry_source_path.as_posix(),
			"offline_bundle": offline_bundle.get("offline_bundle", ""),
			"offline_bundle_exists": offline_bundle.get("offline_bundle_exists", False),
			"offline_bundle_package_count": offline_bundle.get("package_count", 0),
			"offline_bundle_archive_count": offline_bundle.get("archive_count", 0),
			"package_count": len(packages),
			"archive_count": archive_count,
			"preset_count": preset_count,
			"issues": issues,
		}


def release_package_archive_base_url(version: str) -> str:
	return f"{GF_RELEASE_DOWNLOAD_BASE_URL}/{version}"


def release_package_registry_url(version: str) -> str:
	return f"{release_package_archive_base_url(version)}/gf-registry-{version}.json"


def next_major_semver(version: str) -> str:
	parts = parse_semver(version)
	if parts is None:
		return ""
	return f"{parts[0] + 1}.0.0"


def release_package_offline_bundle_name(version: str) -> str:
	return f"gf-package-offline-bundle-{version}.zip"


def audit_release_package_offline_bundle(version: str, temp_root: Path) -> dict[str, Any]:
	offline_root = temp_root / "offline-bundle"
	output_dir = offline_root / "packages"
	registry_path = offline_root / "registry/index.json"
	registry_source_path = offline_root / "registry/gf-registry-source.json"
	offline_bundle_path = temp_root / release_package_offline_bundle_name(version)
	completed = subprocess.run(
		[
			sys.executable,
			"tools/build_gf_package.py",
			"--all",
			"--version",
			version,
			"--output-dir",
			str(output_dir),
			"--registry",
			str(registry_path),
			"--registry-source",
			str(registry_source_path),
			"--offline-bundle",
			str(offline_bundle_path),
			"--json",
		],
		cwd=ROOT,
		capture_output=True,
		text=True,
		encoding="utf-8",
		errors="replace",
		timeout=120,
	)
	issues: list[str] = []
	if completed.returncode != 0:
		issues.extend([
			"tools/build_gf_package.py failed for release offline bundle.",
			trim_text(completed.stdout.strip() or completed.stderr.strip(), 1000),
		])
		return {
			"ok": False,
			"offline_bundle": offline_bundle_path.as_posix(),
			"offline_bundle_exists": offline_bundle_path.is_file(),
			"package_count": 0,
			"archive_count": 0,
			"issues": issues,
		}
	try:
		builder_data = json.loads(completed.stdout or "{}")
	except json.JSONDecodeError as exc:
		return {
			"ok": False,
			"offline_bundle": offline_bundle_path.as_posix(),
			"offline_bundle_exists": offline_bundle_path.is_file(),
			"package_count": 0,
			"archive_count": 0,
			"issues": [f"tools/build_gf_package.py returned invalid JSON for release offline bundle: {exc}"],
		}

	package_build_issues = audit_package_build_result(builder_data, registry_path)
	package_build_issues.extend(audit_package_build_registry_source_manifest(registry_source_path, registry_path))
	package_build_issues.extend(audit_package_build_offline_bundle(
		offline_bundle_path,
		registry_path,
		registry_source_path,
		builder_data,
	))
	issues.extend(
		"package-build-boundary: " + format_package_build_issue_for_release(issue)
		for issue in package_build_issues
	)
	issues.extend(audit_release_package_offline_bundle_metadata(
		builder_data,
		registry_path,
		registry_source_path,
		offline_bundle_path,
		version,
	))
	packages = builder_data.get("packages", []) if isinstance(builder_data.get("packages", []), list) else []
	archive_count = len([package for package in packages if isinstance(package, dict) and str(package.get("kind", "")) != "preset"])
	return {
		"ok": len(issues) == 0,
		"offline_bundle": offline_bundle_path.as_posix(),
		"offline_bundle_exists": offline_bundle_path.is_file(),
		"registry": registry_path.as_posix(),
		"registry_source": registry_source_path.as_posix(),
		"package_count": len(packages),
		"archive_count": archive_count,
		"issues": issues,
	}


def audit_release_package_offline_bundle_metadata(
	builder_data: dict[str, Any],
	registry_path: Path,
	registry_source_path: Path,
	offline_bundle_path: Path,
	version: str,
) -> list[str]:
	issues: list[str] = []
	expected_bundle_name = release_package_offline_bundle_name(version)
	reported_bundle = str(builder_data.get("offline_bundle", "")).strip()
	if Path(reported_bundle).name != expected_bundle_name:
		issues.append(
			"offline bundle asset name is "
			f"{Path(reported_bundle).name!r}, expected {expected_bundle_name!r}."
		)
	if offline_bundle_path.name != expected_bundle_name:
		issues.append(
			f"offline bundle output path must use release versioned asset name {expected_bundle_name!r}."
		)
	registry_data = read_json_object(registry_path)
	if str(registry_data.get("framework_version", "")) != version:
		issues.append(
			"offline bundle registry framework_version is "
			f"{registry_data.get('framework_version', '')!r}, expected {version!r}."
		)
	registry_packages = registry_data.get("packages", {}) if isinstance(registry_data, dict) else {}
	if not isinstance(registry_packages, dict):
		issues.append("offline bundle registry packages field must be an object.")
		registry_packages = {}
	for package_id, entry in sorted(registry_packages.items()):
		if not isinstance(entry, dict):
			issues.append(f"offline bundle registry entry for {package_id} must be an object.")
			continue
		kind = str(entry.get("kind", ""))
		if str(entry.get("version", "")) != version:
			issues.append(
				f"offline bundle registry entry {package_id} version is {entry.get('version', '')!r}, expected {version!r}."
			)
		if kind == "preset":
			continue
		archive_value = str(entry.get("archive", "")).strip()
		if archive_value.startswith(("http://", "https://")):
			issues.append(f"offline bundle registry entry {package_id} archive must be a local relative path.")
		if "\\" in archive_value or archive_value.startswith("/"):
			issues.append(f"offline bundle registry entry {package_id} archive must use a safe relative path.")
		if Path(archive_value).name and not Path(archive_value).name.endswith(f"-{version}.zip"):
			issues.append(f"offline bundle registry entry {package_id} archive asset name must include release version {version}.")

	source_data = read_json_object(registry_source_path)
	channels = source_data.get("channels", {}) if isinstance(source_data, dict) else {}
	channel_name = str(source_data.get("default_channel", "stable")).strip()
	channel_entry = channels.get(channel_name, {}) if isinstance(channels, dict) else {}
	if isinstance(channel_entry, dict):
		registry_value = str(channel_entry.get("registry", "")).strip()
		if registry_value.startswith(("http://", "https://")):
			issues.append("offline bundle registry source must point to the bundled local registry, not a remote URL.")
		if "\\" in registry_value or registry_value.startswith("/"):
			issues.append("offline bundle registry source must use a safe relative registry path.")
	else:
		issues.append("offline bundle registry source manifest must contain its default channel entry.")
	return issues


def format_package_build_issue_for_release(issue: dict[str, Any]) -> str:
	location = str(issue.get("path", "")).strip()
	kind = str(issue.get("kind", "")).strip()
	row_key = str(issue.get("row_key", "")).strip()
	message = str(issue.get("message", "")).strip()
	parts = [part for part in [kind, location, row_key, message] if part]
	return " | ".join(parts)


def audit_release_package_registry_metadata(
	builder_data: dict[str, Any],
	registry_path: Path,
	version: str,
	archive_base_url: str,
) -> list[str]:
	issues: list[str] = []
	registry_data = read_json_object(registry_path)
	if not registry_data:
		return ["release registry JSON could not be read for release-specific checks."]
	if str(registry_data.get("framework_version", "")) != version:
		issues.append(
			"registry framework_version is "
			f"{registry_data.get('framework_version', '')!r}, expected {version!r}."
		)
	if str(registry_data.get("minimum_framework_version", "")) != version:
		issues.append(
			"registry minimum_framework_version is "
			f"{registry_data.get('minimum_framework_version', '')!r}, expected {version!r}."
		)
	expected_maximum_version = next_major_semver(version)
	if expected_maximum_version and str(registry_data.get("maximum_framework_version_exclusive", "")) != expected_maximum_version:
		issues.append(
			"registry maximum_framework_version_exclusive is "
			f"{registry_data.get('maximum_framework_version_exclusive', '')!r}, expected {expected_maximum_version!r}."
		)
	packages = registry_data.get("packages", {})
	if not isinstance(packages, dict):
		return [*issues, "registry packages field must be an object for release-specific checks."]
	builder_packages = builder_data.get("packages", [])
	builder_records = {
		str(package.get("id", "")): package
		for package in builder_packages
		if isinstance(package, dict) and str(package.get("id", "")).strip()
	}
	expected_archive_prefix = archive_base_url.rstrip("/") + "/"
	for package_id, entry in sorted(packages.items()):
		if not isinstance(entry, dict):
			issues.append(f"registry entry for {package_id} must be an object.")
			continue
		for field_name in sorted(PACKAGE_SIGNATURE_POLICY_FIELDS.intersection(entry)):
			issues.append(
				"registry package signature field is not supported until native verification is implemented: "
				f"{package_id}.{field_name}"
			)
		if str(entry.get("version", "")) != version:
			issues.append(
				f"registry entry {package_id} version is {entry.get('version', '')!r}, expected {version!r}."
			)
		if str(entry.get("minimum_framework_version", "")) != version:
			issues.append(
				f"registry entry {package_id} minimum_framework_version is "
				f"{entry.get('minimum_framework_version', '')!r}, expected {version!r}."
			)
		if expected_maximum_version and str(entry.get("maximum_framework_version_exclusive", "")) != expected_maximum_version:
			issues.append(
				f"registry entry {package_id} maximum_framework_version_exclusive is "
				f"{entry.get('maximum_framework_version_exclusive', '')!r}, expected {expected_maximum_version!r}."
			)
		kind = str(entry.get("kind", ""))
		if kind == "preset":
			continue
		archive_value = str(entry.get("archive", "")).strip()
		if not archive_value.startswith(expected_archive_prefix):
			issues.append(
				f"registry entry {package_id} archive must use release download base {expected_archive_prefix}."
			)
			continue
		if "\\" in archive_value:
			issues.append(f"registry entry {package_id} archive URL must use forward slashes.")
		archive_name = archive_value.rsplit("/", 1)[-1]
		if not archive_name.endswith(f"-{version}.zip"):
			issues.append(f"registry entry {package_id} archive asset name must include release version {version}.")
		builder_record = builder_records.get(str(package_id))
		if isinstance(builder_record, dict):
			builder_archive_name = Path(str(builder_record.get("archive", ""))).name
			if archive_name != builder_archive_name:
				issues.append(
					f"registry entry {package_id} archive asset {archive_name!r} does not match built archive {builder_archive_name!r}."
				)
	return issues


def audit_release_package_registry_source_manifest(
	registry_source_path: Path,
	version: str,
	expected_registry_url: str,
	registry_path: Path | None = None,
) -> list[str]:
	issues: list[str] = []
	data = read_json_object(registry_source_path)
	if not data:
		return ["release registry source manifest JSON could not be read for release-specific checks."]
	if data.get("schema_version") != 1:
		issues.append("registry source manifest schema_version must be 1.")
	if data.get("default_channel") != "stable":
		issues.append("registry source manifest default_channel must be 'stable'.")
	channels = data.get("channels", {})
	if not isinstance(channels, dict) or not channels:
		return [*issues, "registry source manifest channels field must be a non-empty object."]
	stable_channel = channels.get("stable")
	if not isinstance(stable_channel, dict):
		return [*issues, "registry source manifest stable channel must be an object."]
	for scope, field_name in collect_registry_source_signature_fields(data):
		issues.append(
			"registry source manifest signature field is not supported until native verification is implemented: "
			f"{scope}.{field_name}"
		)
	registry_value = str(stable_channel.get("registry", "")).strip()
	if registry_value != expected_registry_url:
		issues.append(
			"registry source manifest stable registry is "
			f"{registry_value!r}, expected {expected_registry_url!r}."
		)
	if f"/{version}/" not in registry_value:
		issues.append(f"registry source manifest stable registry must point at release version {version}.")
	if "\\" in registry_value:
		issues.append("registry source manifest stable registry URL must use forward slashes.")
	registry_sha256 = str(stable_channel.get("registry_sha256", "")).strip().lower()
	if registry_sha256 and not is_sha256_hex(registry_sha256):
		issues.append("registry source manifest stable registry_sha256 must be a sha256 hex digest.")
	registry_size = stable_channel.get("registry_size_bytes", 0)
	if registry_size not in (None, "") and not is_non_negative_int_metadata(registry_size):
		issues.append("registry source manifest stable registry_size_bytes must be a non-negative integer.")
	if registry_path is not None and registry_path.is_file():
		expected_sha = sha256_file(registry_path)
		expected_size = registry_path.stat().st_size
		if registry_sha256 != expected_sha:
			issues.append("registry source manifest stable registry_sha256 must match the generated registry.")
		if int_value(registry_size) != expected_size:
			issues.append("registry source manifest stable registry_size_bytes must match the generated registry.")
	mirrors = stable_channel.get("mirrors", [])
	if not isinstance(mirrors, list):
		issues.append("registry source manifest stable mirrors must be an array.")
	elif any(not isinstance(mirror, str) or not mirror.strip() for mirror in mirrors):
		issues.append("registry source manifest stable mirrors must contain non-empty strings.")
	return issues


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


def git_show_text(revision_path: str) -> str:
	result = subprocess.run(
		["git", "show", revision_path],
		cwd=ROOT,
		capture_output=True,
		text=True,
		encoding="utf-8",
		errors="replace",
	)
	if result.returncode != 0:
		return ""
	return result.stdout


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


def render_path_hygiene_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"path_hygiene: ok={data['ok']} "
			f"tracked={data['tracked_file_count']} "
			f"untracked={data.get('untracked_file_count', 0)} "
			f"scanned={data.get('scanned_file_count', data['tracked_file_count'])} "
			f"issues={data['issue_count']}"
		),
	]
	for issue in data["issues"]:
		lines.append(f"- {issue['kind']}: {issue.get('path', '')} {issue.get('message', '')}".rstrip())
		if issue.get("paths"):
			for path in issue["paths"]:
				lines.append(f"  path: {path}")
	return "\n".join(lines)


def render_api_since_touched_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"api_since_touched: ok={data['ok']} "
			f"changed_gdscript={data['changed_gdscript_file_count']} "
			f"scanned={data['scanned_file_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for issue in data["issues"]:
		location = f"{issue.get('path', '')}:{issue.get('line', '')}".rstrip(":")
		declaration = issue.get("declaration", "")
		suffix = f" {declaration}" if declaration else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_dependency_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"dependency_boundary: ok={data['ok']} "
			f"manifests={data['manifest_count']} "
			f"extension_ids={data['extension_id_count']} "
			f"standard_classes={data['standard_class_count']} "
			f"extension_classes={data['extension_class_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for issue in data["issues"]:
		details = []
		for key in ("extension_id", "field", "symbol"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {issue.get('path', '')}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_public_docs_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"public_docs_boundary: ok={data['ok']} "
			f"files={data['file_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for issue in data["issues"]:
		location = f"{issue.get('path', '')}:{issue.get('line', '')}".rstrip(":")
		symbol = issue.get("symbol", "")
		suffix = f" ({symbol})" if symbol else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_public_api_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"public_api_boundary: ok={data['ok']} "
			f"files={data['file_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for issue in data["issues"]:
		location = f"{issue.get('path', '')}:{issue.get('line', '')}".rstrip(":")
		symbol = issue.get("symbol", "")
		suffix = f" ({symbol})" if symbol else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def format_counter_summary(items: list[dict[str, Any]], limit: int = 8) -> str:
	parts: list[str] = []
	for item in items[:limit]:
		parts.append(f"{item.get('key', '')}={item.get('count', 0)}")
	if len(items) > limit:
		parts.append(f"...+{len(items) - limit}")
	return ", ".join(parts)


def render_resource_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"resource_boundary: ok={data['ok']} "
			f"report_only={data.get('report_only', True)} "
			f"files={data['file_count']} "
			f"issues={data['issue_count']} "
			f"warnings={data.get('warning_count', 0)} "
			f"info={data.get('info_count', 0)} "
			f"observations={data.get('observation_count', 0)}"
		),
	]
	kind_summary = format_counter_summary(data.get("issue_kind_counts", []))
	extension_summary = format_counter_summary(data.get("target_extension_counts", []))
	source_kind_summary = format_counter_summary(data.get("source_kind_counts", []))
	source_package_summary = format_counter_summary(data.get("source_package_counts", []))
	target_package_summary = format_counter_summary(data.get("target_package_counts", []))
	source_target_package_summary = format_counter_summary(data.get("source_target_package_counts", []))
	observation_kind_summary = format_counter_summary(data.get("observation_kind_counts", []))
	observation_extension_summary = format_counter_summary(data.get("observation_target_extension_counts", []))
	observation_source_kind_summary = format_counter_summary(data.get("observation_source_kind_counts", []))
	observation_source_package_summary = format_counter_summary(data.get("observation_source_package_counts", []))
	observation_target_package_summary = format_counter_summary(data.get("observation_target_package_counts", []))
	observation_source_target_package_summary = format_counter_summary(data.get("observation_source_target_package_counts", []))
	if kind_summary:
		lines.append(f"kinds: {kind_summary}")
	if extension_summary:
		lines.append(f"target_extensions: {extension_summary}")
	if source_kind_summary:
		lines.append(f"source_kinds: {source_kind_summary}")
	if source_package_summary:
		lines.append(f"source_packages: {source_package_summary}")
	if target_package_summary:
		lines.append(f"target_packages: {target_package_summary}")
	if source_target_package_summary:
		lines.append(f"source_target_packages: {source_target_package_summary}")
	if observation_kind_summary:
		lines.append(f"observation_kinds: {observation_kind_summary}")
	if observation_extension_summary:
		lines.append(f"observation_target_extensions: {observation_extension_summary}")
	if observation_source_kind_summary:
		lines.append(f"observation_source_kinds: {observation_source_kind_summary}")
	if observation_source_package_summary:
		lines.append(f"observation_source_packages: {observation_source_package_summary}")
	if observation_target_package_summary:
		lines.append(f"observation_target_packages: {observation_target_package_summary}")
	if observation_source_target_package_summary:
		lines.append(f"observation_source_target_packages: {observation_source_target_package_summary}")
	warning_issues = [issue for issue in data["issues"] if issue.get("severity") == "warning"]
	info_issues = [issue for issue in data["issues"] if issue.get("severity") != "warning"]
	display_limit = 12
	display_issues = [*warning_issues[:display_limit]]
	if len(display_issues) < display_limit:
		display_issues.extend(info_issues[:display_limit - len(display_issues)])
	for issue in display_issues:
		location = f"{issue.get('path', '')}:{issue.get('line', '')}".rstrip(":")
		target = issue.get("target", "")
		callee = issue.get("callee", "")
		severity = issue.get("severity", "")
		source_kind = issue.get("source_kind", "")
		source_package = issue.get("source_package", "")
		target_package = issue.get("target_package", "")
		details = []
		if severity:
			details.append(f"severity={severity}")
		if callee:
			details.append(f"callee={callee}")
		if source_kind:
			details.append(f"source_kind={source_kind}")
		if source_package:
			details.append(f"source_package={source_package}")
		if target_package:
			details.append(f"target_package={target_package}")
		if target:
			details.append(f"target={target}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	if len(data["issues"]) > len(display_issues):
		lines.append(f"... {len(data['issues']) - len(display_issues)} more issue(s) omitted from text output; use --json for the full report.")
	if data.get("observation_count", 0) > 0:
		lines.append("Observations are summarized separately; pass --include-observations --json for full records.")
	return "\n".join(lines)


def render_content_package_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"content_package_boundary: ok={data['ok']} "
			f"manifests={data['manifest_count']} "
			f"packages={data['package_count']} "
			f"resources={data['resource_count']} "
			f"issues={data['issue_count']}"
		),
	]
	kind_summary = format_counter_summary(data.get("issue_kind_counts", []))
	if kind_summary:
		lines.append(f"kinds: {kind_summary}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("field", "row_index", "row_key", "actual_value"):
			if key in issue:
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_asset_lifecycle_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"asset_lifecycle_boundary: ok={data['ok']} "
			f"report_only={data.get('report_only', True)} "
			f"files={data['file_count']} "
			f"issues={data['issue_count']} "
			f"warnings={data.get('warning_count', 0)} "
			f"info={data.get('info_count', 0)}"
		),
	]
	kind_summary = format_counter_summary(data.get("issue_kind_counts", []))
	if kind_summary:
		lines.append(f"kinds: {kind_summary}")
	for issue in data["issues"]:
		location = f"{issue.get('path', '')}:{issue.get('line', '')}".rstrip(":")
		details = []
		for key in ("severity", "callee", "target"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_project_profile_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"project_profile_boundary: ok={data['ok']} "
			f"profile_found={data.get('profile_found', False)} "
			f"profile={data.get('profile_path', '')} "
			f"files={data.get('file_count', 0)} "
			f"issues={data['issue_count']} "
			f"errors={data.get('error_count', 0)} "
			f"warnings={data.get('warning_count', 0)} "
			f"info={data.get('info_count', 0)}"
		),
	]
	kind_summary = format_counter_summary(data.get("issue_kind_counts", []))
	if kind_summary:
		lines.append(f"kinds: {kind_summary}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("severity", "rule_id", "zone_id", "field", "actual_value", "expected_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_boundary: ok={data['ok']} "
			f"manifests={data['manifest_count']} "
			f"packages={data['package_count']} "
			f"paths={data['path_count']} "
			f"issues={data['issue_count']}"
		),
	]
	kind_counts = format_counter_summary(data.get("kind_counts", []))
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if kind_counts:
		lines.append(f"package_kinds: {kind_counts}")
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("field", "row_index", "row_key", "actual_value", "expected_value"):
			if key in issue:
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_closure_audit_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_closure_audit: ok={data['ok']} "
			f"packages={data['package_count']} "
			f"closures={data['closure_count']} "
			f"errors={data['error_count']} "
			f"warnings={data['warning_count']} "
			f"info={data['info_count']}"
		),
	]
	kind_counts = format_counter_summary(data.get("kind_counts", []))
	severity_counts = format_counter_summary(data.get("severity_counts", []))
	if kind_counts:
		lines.append(f"package_kinds: {kind_counts}")
	if severity_counts:
		lines.append(f"severity: {severity_counts}")
	large_closures = [
		row
		for row in data.get("closures", [])
		if (
			(
				row.get("kind") == "extension"
				and int(row.get("closure_count", 0)) > data.get("extension_total_warning_threshold", 8)
			)
			or (
				row.get("kind") == "preset"
				and int(row.get("closure_count", 0)) > data.get("preset_total_info_threshold", 12)
			)
		)
	]
	for row in large_closures[:8]:
		lines.append(
			f"- closure: {row.get('package_id')} "
			f"kind={row.get('kind')} "
			f"total={row.get('closure_count')} "
			f"standard={row.get('standard_count')} "
			f"extension={row.get('extension_count')}"
		)
	for fan_in in data.get("standard_fan_in", [])[:8]:
		lines.append(
			f"- fan_in: {fan_in.get('package_id')} "
			f"dependents={fan_in.get('dependent_count')}"
		)
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("severity", "row_key", "actual_value", "expected_value"):
			if key in issue:
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_source_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_source_boundary: ok={data['ok']} "
			f"packages={data['package_count']} "
			f"source_files={data['source_file_count']} "
			f"issues={data['issue_count']}"
		),
	]
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = f"{issue.get('path', '')}:{issue.get('line', '')}".rstrip(":")
		details = []
		for key in ("row_key", "symbol", "target", "expected_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_build_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_build_boundary: ok={data['ok']} "
			f"packages={data['package_count']} "
			f"archives={data['archive_count']} "
			f"registry_packages={data['registry_package_count']} "
			f"issues={data['issue_count']}"
		),
	]
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("row_key", "field", "actual_value", "expected_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_user_dependency_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_user_dependency_boundary: ok={data['ok']} "
			f"source_files={data['source_file_count']} "
			f"issues={data['issue_count']}"
		),
	]
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = f"{issue.get('path', '')}:{issue.get('line', '')}".rstrip(":")
		details = []
		for key in ("actual_value", "expected_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_external_command_audit_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_external_command_audit: ok={data['ok']} "
			f"report_only={data.get('report_only', True)} "
			f"packages={data.get('package_count', 0)} "
			f"source_files={data['source_file_count']} "
			f"issues={data['issue_count']} "
			f"errors={data.get('error_count', 0)} "
			f"warnings={data.get('warning_count', 0)} "
			f"info={data.get('info_count', 0)}"
		),
	]
	kind_summary = format_counter_summary(data.get("issue_kind_counts", []))
	api_summary = format_counter_summary(data.get("api_counts", []))
	command_summary = format_counter_summary(data.get("command_counts", []))
	if kind_summary:
		lines.append(f"kinds: {kind_summary}")
	if api_summary:
		lines.append(f"apis: {api_summary}")
	if command_summary:
		lines.append(f"commands: {command_summary}")
	display_limit = 16
	for issue in data["issues"][:display_limit]:
		location = f"{issue.get('path', '')}:{issue.get('line', '')}".rstrip(":")
		details = []
		for key in ("severity", "row_key", "api", "command"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	if len(data["issues"]) > display_limit:
		lines.append(f"... {len(data['issues']) - display_limit} more issue(s) omitted from text output; use --json for the full report.")
	return "\n".join(lines)


def render_core_only_smoke_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"core_only_smoke: ok={data['ok']} "
			f"files={data['file_count']} "
			f"standard_classes={data['standard_class_count']} "
			f"issues={data['issue_count']}"
		),
	]
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = f"{issue.get('path', '')}:{issue.get('line', '')}".rstrip(":")
		details = []
		for key in ("symbol", "field", "actual_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_install_smoke_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_install_smoke: ok={data['ok']} "
			f"scenarios={data['scenario_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for scenario in data["scenarios"]:
		lines.append(f"- {scenario.get('name', '')}: ok={scenario.get('ok', False)}")
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("row_key", "field", "actual_value", "expected_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_network_install_smoke_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"network_install_smoke: ok={data['ok']} "
			f"scenarios={data['scenario_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for scenario in data["scenarios"]:
		lines.append(f"- {scenario.get('name', '')}: ok={scenario.get('ok', False)}")
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("row_key", "field", "actual_value", "expected_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_preset_smoke_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"preset_smoke: ok={data['ok']} "
			f"scenarios={data['scenario_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for scenario in data["scenarios"]:
		lines.append(f"- {scenario.get('name', '')}: ok={scenario.get('ok', False)}")
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("row_key", "field", "actual_value", "expected_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_manager_status_smoke_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_manager_status_smoke: ok={data['ok']} "
			f"scenarios={data['scenario_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for scenario in data["scenarios"]:
		lines.append(f"- {scenario.get('name', '')}: ok={scenario.get('ok', False)}")
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("row_key", "field", "actual_value", "expected_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_native_parity_smoke_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_native_parity_smoke: ok={data['ok']} "
			f"scenarios={data['scenario_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for scenario in data["scenarios"]:
		details = []
		for key in ("package_count", "installed_count"):
			if key in scenario:
				details.append(f"{key}={scenario[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {scenario.get('name', '')}: ok={scenario.get('ok', False)}{suffix}")
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("row_key", "field", "actual_value", "expected_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_editor_wizard_smoke_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_editor_wizard_smoke: ok={data['ok']} "
			f"scenarios={data['scenario_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for scenario in data["scenarios"]:
		details = []
		for key in ("test_path", "exit_code", "log_path"):
			if key in scenario:
				details.append(f"{key}={scenario[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {scenario.get('name', '')}: ok={scenario.get('ok', False)}{suffix}")
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("row_key", "actual_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
		if issue.get("error"):
			lines.append(indent_text(str(issue["error"]), "  error_tail: "))
	return "\n".join(lines)


def render_package_focused_gut_mapping_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_focused_gut_mapping: ok={data['ok']} "
			f"packages={data.get('package_count', 0)} "
			f"mapped={data.get('mapped_package_count', 0)} "
			f"tests={data.get('test_count', 0)} "
			f"issues={data['issue_count']}"
		),
		f"mapping: {data.get('mapping_path', '')}",
	]
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("row_key", "row_index", "field", "actual_value", "expected_value"):
			if issue.get(key) != None and issue.get(key) != "":
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_godot_cli_smoke_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_godot_cli_smoke: ok={data['ok']} "
			f"scenarios={data['scenario_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for scenario in data["scenarios"]:
		details = []
		for key in ("package_count", "installed_file_count", "removed_file_count", "dry_run", "cache_file_count", "registry_mirror_index"):
			if key in scenario:
				details.append(f"{key}={scenario[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {scenario.get('name', '')}: ok={scenario.get('ok', False)}{suffix}")
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("row_key", "field", "actual_value", "expected_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_godot_smoke_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_godot_smoke: ok={data['ok']} "
			f"mode={data.get('mode', 'representative')} "
			f"packages={data.get('package_count', 0)} "
			f"jobs={data.get('jobs', 1)} "
			f"scenarios={data['scenario_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for scenario in data["scenarios"]:
		details = []
		for key in ("package_id", "package_kind", "installed_file_count", "expected_file_count", "preload_count", "exit_leak_warning_count"):
			if key in scenario:
				details.append(f"{key}={scenario[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {scenario.get('name', '')}: ok={scenario.get('ok', False)}{suffix}")
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("row_key", "field", "actual_value", "expected_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_uninstall_smoke_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"uninstall_smoke: ok={data['ok']} "
			f"scenarios={data['scenario_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for scenario in data["scenarios"]:
		lines.append(f"- {scenario.get('name', '')}: ok={scenario.get('ok', False)}")
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("row_key", "field", "actual_value", "expected_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_maintenance_self_test_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"maintenance_self_test: ok={data['ok']} "
			f"tests={data['test_count']} "
			f"failures={data['failure_count']}"
		),
	]
	for failure in data["failures"]:
		lines.append(f"- {failure['name']}: {failure.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_godot_exit_leak_report_text(data: dict[str, Any]) -> str:
	lines = [
		f"godot_exit_leak_report: ok={data['ok']} has_leaks={data['has_leaks']} logs={len(data['logs'])}",
		(
			"summary: "
			f"objectdb={data['objectdb_warning_count']} "
			f"resource_summaries={data['resource_summary_count']} "
			f"resource_total={data['resource_summary_total']} "
			f"resource_paths={data['resource_still_in_use_count']} "
			f"rid_total={data['rid_allocation_total']} "
			f"leaked_instances={data['leaked_instance_total']}"
		),
	]
	if data["missing_logs"]:
		lines.append("missing logs:")
		lines.extend(f"- {path}" for path in data["missing_logs"])
	if data["rid_allocations"]:
		lines.append("rid allocations:")
		lines.extend(f"- {item['key']}: {item['count']}" for item in data["rid_allocations"][:12])
	if data["leaked_instance_types"]:
		lines.append("leaked instance types:")
		lines.extend(f"- {item['key']}: {item['count']}" for item in data["leaked_instance_types"][:12])
	if data["resource_type_counts"]:
		lines.append("resource types:")
		lines.extend(f"- {item['key']}: {item['count']}" for item in data["resource_type_counts"][:12])
	if data["resource_path_prefix_counts"]:
		lines.append("resource path prefixes:")
		lines.extend(f"- {item['key']}: {item['count']}" for item in data["resource_path_prefix_counts"][:12])
	if data["warning_lines"]:
		lines.append("warning lines:")
		lines.extend(f"- {line}" for line in data["warning_lines"][:12])
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


def render_failed_checks_text(data: dict[str, Any]) -> str:
	failed_results = failed_check_results(data)
	lines = [
		(
			f"suite: {data['suite']} ok={data['ok']} "
			f"checks={len(data['results'])} failed={len(failed_results)}"
		)
	]
	if not failed_results:
		lines.append("all checks passed")
		return "\n".join(lines)
	lines.append("failed checks:")
	for result in failed_results:
		lines.append(
			f"- {result['name']}: exit={result.get('exit_code')} "
			f"timeout={result.get('timed_out', False)}"
		)
		command = result.get("command")
		if command:
			lines.append(f"  command: {' '.join(str(part) for part in command)}")
		for note in result.get("notes", []) or []:
			lines.append(f"  note: {note}")
		release = result.get("release_status")
		if release and release.get("issues"):
			lines.extend(f"  issue: {issue}" for issue in release["issues"])
		stdout = result.get("stdout", "").strip()
		stderr = result.get("stderr", "").strip()
		if stdout:
			lines.append(indent_text(trim_text(stdout, 4000), "  stdout_tail: "))
		if stderr:
			lines.append(indent_text(trim_text(stderr, 4000), "  stderr_tail: "))
	return "\n".join(lines)


def failed_check_results(data: dict[str, Any]) -> list[dict[str, Any]]:
	return [
		result
		for result in data["results"]
		if result.get("exit_code", 1) != 0 or result.get("timed_out", False)
	]


def print_github_check_annotations(data: dict[str, Any]) -> None:
	for result in failed_check_results(data):
		name = str(result.get("name", "unknown"))
		title = github_workflow_command_escape_property(f"GF check failed: {name}")
		message = github_workflow_command_escape_data(render_failed_check_annotation(result))
		print(f"::error title={title}::{message}")


def render_failed_check_annotation(result: dict[str, Any]) -> str:
	lines = [
		(
			f"{result.get('name', 'unknown')} failed "
			f"exit={result.get('exit_code')} timeout={result.get('timed_out', False)}"
		)
	]
	command = result.get("command")
	if command:
		lines.append(f"command: {' '.join(str(part) for part in command)}")
	for note in result.get("notes", []) or []:
		lines.append(f"note: {note}")
	release = result.get("release_status")
	if release and release.get("issues"):
		lines.extend(f"issue: {issue}" for issue in release["issues"])
	stdout = result.get("stdout", "").strip()
	stderr = result.get("stderr", "").strip()
	if stdout:
		lines.append("stdout_tail:")
		lines.append(trim_text(stdout, 3000))
	if stderr:
		lines.append("stderr_tail:")
		lines.append(trim_text(stderr, 3000))
	return "\n".join(lines)


def github_workflow_command_escape_data(value: str) -> str:
	return value.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def github_workflow_command_escape_property(value: str) -> str:
	return github_workflow_command_escape_data(value).replace(":", "%3A").replace(",", "%2C")


def render_release_status_text(data: dict[str, Any]) -> str:
	lines = [f"version: {data['version']} ok={data['ok']}"]
	lines.append(f"plugin: {data['plugin_version']}")
	lines.append(
		"worktree: "
		f"dirty={data.get('worktree_dirty', False)} "
		f"changed={data.get('dirty_file_count', 0)} "
		f"allow_dirty={data.get('allow_dirty', False)}"
	)
	lines.append(
		"compatibility: "
		f"allow_breaking_api={data.get('allow_breaking_api', False)}"
	)
	lines.append(
		"since: "
		f"unresolved={data.get('unresolved_since_count', 0)} "
		f"future={data.get('future_since_count', 0)}"
	)
	api_diff = data.get("api_baseline_diff", {})
	api_diff_summary = api_diff.get("summary", {})
	if api_diff_summary:
		lines.append(
			"api_baseline: "
			f"base={api_diff.get('base_tag', '')} "
			f"breaking={api_diff_summary.get('breaking_change_count', 0)} "
			f"added_classes={api_diff_summary.get('added_classes', 0)} "
			f"signature_changes={api_diff_summary.get('signature_changes', 0)} "
			f"breaking_signatures={api_diff_summary.get('breaking_signature_changes', 0)} "
			f"compatible_signatures={api_diff_summary.get('compatible_signature_changes', 0)} "
			f"removed_members={api_diff_summary.get('removed_members', 0)} "
			f"breaking_allowed={api_diff_summary.get('breaking_allowed', False)}"
		)
	asset_library = data.get("asset_library", {})
	lines.append(
		"asset_library: "
		f"version={asset_library.get('Asset Version', '')} "
		f"download={asset_library.get('Download Commit/URL', '')} "
		f"preview_todos={len(data.get('asset_library_preview_todos', []))}"
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
		f"skipped={package_archive.get('skipped', False)} "
		f"missing_rules={len(package_archive.get('missing_export_ignore_rules', []))} "
		f"blocked_dirs={len(package_archive.get('blocked_package_dirs', []))} "
		f"asset_store_package_issues={len(package_archive.get('asset_store_package', {}).get('issues', []))}"
	)
	modular_registry = package_archive.get("modular_package_registry", {})
	lines.append(
		"package_registry: "
		f"skipped={modular_registry.get('skipped', False)} "
		f"packages={modular_registry.get('package_count', 0)} "
		f"archives={modular_registry.get('archive_count', 0)} "
		f"presets={modular_registry.get('preset_count', 0)} "
		f"source={bool(modular_registry.get('registry_source', ''))} "
		f"offline_bundle={bool(modular_registry.get('offline_bundle', ''))} "
		f"issues={len(modular_registry.get('issues', []))}"
	)
	lines.append(f"tag: exists={data['tag_exists']} points_at_head={data['tag_points_at_head']}")
	if data["issues"]:
		lines.append("issues:")
		lines.extend(f"- {issue}" for issue in data["issues"])
	return "\n".join(lines)


def render_api_baseline_diff_text(data: dict[str, Any]) -> str:
	summary = data.get("summary", {})
	lines = [
		(
			f"api_baseline_diff: ok={data['ok']} "
			f"base={data.get('base_tag', '')} "
			f"version={data.get('version', '')} "
			f"enforce={data.get('enforce_version', False)}"
		),
		(
			"summary: "
			f"added_classes={summary.get('added_classes', 0)} "
			f"removed_classes={summary.get('removed_classes', 0)} "
			f"added_members={summary.get('added_members', 0)} "
			f"removed_members={summary.get('removed_members', 0)} "
			f"signature_changes={summary.get('signature_changes', 0)} "
			f"breaking_signatures={summary.get('breaking_signature_changes', 0)} "
			f"compatible_signatures={summary.get('compatible_signature_changes', 0)} "
			f"extends_changes={summary.get('extends_changes', 0)} "
			f"breaking={summary.get('breaking_change_count', 0)} "
			f"breaking_allowed={summary.get('breaking_allowed', False)}"
		),
	]
	for issue in data.get("issues", []):
		lines.append(f"- issue: {issue}")
	diff = data.get("diff", {})
	for group in (
		"added_classes",
		"removed_classes",
		"removed_members",
		"breaking_signature_changes",
		"compatible_signature_changes",
		"extends_changes",
	):
		items = diff.get(group, [])
		if not items:
			continue
		lines.append(f"{group}:")
		for item in items[:20]:
			lines.append(f"- {format_api_diff_item(group, item)}")
		if len(items) > 20:
			lines.append(f"- ... {len(items) - 20} more")
	return "\n".join(lines)


def format_api_diff_item(group: str, item: dict[str, Any]) -> str:
	if group in {"added_classes", "removed_classes"}:
		return f"{item.get('name', '')} | {item.get('module', '')} | {item.get('source_path', '')}"
	if group in {"signature_changes", "breaking_signature_changes", "compatible_signature_changes"}:
		compatibility = item.get("compatibility", "")
		suffix = f" [{compatibility}]" if compatibility else ""
		return (
			f"{item.get('class', '')}.{item.get('name', '')}: "
			f"{item.get('old_signature', '')} -> {item.get('new_signature', '')}"
			f"{suffix}"
		)
	if group == "extends_changes":
		return (
			f"{item.get('class', '')}: "
			f"{item.get('old_extends', '')} -> {item.get('new_extends', '')}"
		)
	return f"{item.get('class', '')}.{item.get('name', '')} | {item.get('signature', '')}"


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
