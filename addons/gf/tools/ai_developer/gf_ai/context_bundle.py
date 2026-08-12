"""Explicit, hash-bound offline context bundles for human-reviewed AI handoff."""

from __future__ import annotations

import re
import unicodedata
from pathlib import Path
from typing import Any

from .constants import CONTEXT_BUNDLE_SCHEMA_VERSION, PROJECT_ARTIFACT_PATHS, SCHEMA_ROOT, TOOL_VERSION
from .paths import (
	atomic_write_json,
	normalize_portable_ownership_path,
	read_bounded_bytes,
	read_bounded_text,
	resolve_project_path,
	sha256_bytes,
	sha256_json,
)
from .schema import validate_schema_file


MAX_CONTEXT_FILES = 64
MAX_CONTEXT_SETTINGS = 64
MAX_CONTEXT_PATH_CHARS = 512
MAX_CONTEXT_SETTING_CHARS = 160
MAX_CONTEXT_FILE_BYTES = 512 * 1024
MAX_CONTEXT_TOTAL_BYTES = 4 * 1024 * 1024
MAX_PROJECT_FILE_BYTES = 16 * 1024 * 1024

_SETTING_NAME_PATTERN = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+$")
_SECTION_PATTERN = re.compile(r"^\[([^\[\]\r\n]+)\]$")
_HEX_SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
_CONTEXT_OUTPUT_ROOT = PROJECT_ARTIFACT_PATHS["ai_output_root"].rstrip("/") + "/context"
_OPENING_DELIMITERS = {"(": ")", "[": "]", "{": "}"}
_CLOSING_DELIMITERS = frozenset(_OPENING_DELIMITERS.values())
_CONTEXT_OUTPUT_ROOT_IDENTITY = unicodedata.normalize("NFC", _CONTEXT_OUTPUT_ROOT).casefold()


def plan_context_bundle(
	project_root: Path,
	file_paths: list[str],
	setting_names: list[str],
) -> dict[str, Any]:
	"""Build a deterministic content-bound plan without returning selected contents."""
	collected = _collect_context(project_root, file_paths, setting_names)
	plan_contract = _make_plan_contract(collected)
	return {
		"ok": True,
		"status": "ready",
		**plan_contract,
		"plan_sha256": sha256_json(plan_contract),
	}


def export_context_bundle(
	project_root: Path,
	file_paths: list[str],
	setting_names: list[str],
	expected_plan_sha256: str,
	*,
	human_approved: bool = False,
) -> dict[str, Any]:
	"""Export exactly the reviewed context after re-reading and re-hashing every source."""
	if _HEX_SHA256_PATTERN.fullmatch(expected_plan_sha256) is None:
		return _blocked("invalid_plan_sha256", "Expected plan SHA-256 must be 64 lowercase hexadecimal characters.")
	collected = _collect_context(project_root, file_paths, setting_names)
	plan_contract = _make_plan_contract(collected)
	current_plan_sha256 = sha256_json(plan_contract)
	if current_plan_sha256 != expected_plan_sha256:
		return _blocked(
			"context_sources_changed",
			"Selected context changed after review; create and review a new plan.",
			status="stale",
			current_plan_sha256=current_plan_sha256,
		)
	if not human_approved:
		return _blocked("human_approval_required", "Interactive human approval was not completed.")

	bundle = {
		"schema_version": CONTEXT_BUNDLE_SCHEMA_VERSION,
		"generator_version": TOOL_VERSION,
		"project_root": ".",
		"plan_sha256": current_plan_sha256,
		"untrusted_content": True,
		"files": [
			{
				"path": item["path"],
				"size_bytes": item["size_bytes"],
				"sha256": item["sha256"],
				"content": item["content"],
			}
			for item in collected["files"]
		],
		"settings": [
			{
				"name": item["name"],
				"size_bytes": item["size_bytes"],
				"sha256": item["sha256"],
				"serialized_value": item["serialized_value"],
			}
			for item in collected["settings"]
		],
	}
	issues = validate_schema_file(bundle, SCHEMA_ROOT / "editor_context_bundle.schema.json")
	if issues:
		raised = "; ".join(f"{item['path']}: {item['message']}" for item in issues[:8])
		raise RuntimeError(f"Generated context bundle failed its schema: {raised}")
	output_relative = f"{_CONTEXT_OUTPUT_ROOT}/{current_plan_sha256}.json"
	output_path = resolve_project_path(project_root, output_relative)
	atomic_write_json(output_path, bundle)
	return {
		"ok": True,
		"status": "exported",
		"plan_sha256": current_plan_sha256,
		"output": output_relative,
		"file_count": len(collected["files"]),
		"setting_count": len(collected["settings"]),
		"total_bytes": collected["total_bytes"],
	}


def _collect_context(
	project_root: Path,
	file_paths: list[str],
	setting_names: list[str],
) -> dict[str, Any]:
	if not isinstance(file_paths, list) or not isinstance(setting_names, list):
		raise ValueError("Context files and settings must be arrays.")
	if not file_paths and not setting_names:
		raise ValueError("Select at least one explicit file or project setting.")
	if len(file_paths) > MAX_CONTEXT_FILES:
		raise ValueError(f"Context allows at most {MAX_CONTEXT_FILES} files.")
	if len(setting_names) > MAX_CONTEXT_SETTINGS:
		raise ValueError(f"Context allows at most {MAX_CONTEXT_SETTINGS} settings.")

	files: list[dict[str, Any]] = []
	seen_paths: set[str] = set()
	total_bytes = 0
	for raw_path in file_paths:
		relative_path = _normalize_context_path(raw_path)
		identity = unicodedata.normalize("NFC", relative_path).casefold()
		if identity in seen_paths:
			raise ValueError(f"Context file path is duplicated or case-colliding: {relative_path}")
		seen_paths.add(identity)
		if identity == _CONTEXT_OUTPUT_ROOT_IDENTITY or identity.startswith(
			_CONTEXT_OUTPUT_ROOT_IDENTITY + "/"
		):
			raise ValueError("Context output files cannot be selected as context input.")
		path = resolve_project_path(project_root, relative_path, must_exist=True)
		raw = read_bounded_bytes(path, MAX_CONTEXT_FILE_BYTES)
		try:
			content = raw.decode("utf-8", errors="strict")
		except UnicodeDecodeError as exc:
			raise ValueError(f"Context file is not valid UTF-8: {relative_path}: {exc}") from exc
		total_bytes += len(raw)
		if total_bytes > MAX_CONTEXT_TOTAL_BYTES:
			raise ValueError(f"Context exceeds the {MAX_CONTEXT_TOTAL_BYTES}-byte total budget.")
		files.append({
			"path": relative_path,
			"size_bytes": len(raw),
			"sha256": sha256_bytes(raw),
			"content": content,
		})

	normalized_settings = _normalize_setting_names(setting_names)
	setting_values = _read_selected_settings(project_root, normalized_settings)
	settings: list[dict[str, Any]] = []
	for name in normalized_settings:
		serialized_value = setting_values[name]
		raw_value = serialized_value.encode("utf-8")
		total_bytes += len(raw_value)
		if total_bytes > MAX_CONTEXT_TOTAL_BYTES:
			raise ValueError(f"Context exceeds the {MAX_CONTEXT_TOTAL_BYTES}-byte total budget.")
		settings.append({
			"name": name,
			"size_bytes": len(raw_value),
			"sha256": sha256_bytes(raw_value),
			"serialized_value": serialized_value,
		})
	files.sort(key=lambda item: item["path"])
	settings.sort(key=lambda item: item["name"])
	return {"files": files, "settings": settings, "total_bytes": total_bytes}


def _make_plan_contract(collected: dict[str, Any]) -> dict[str, Any]:
	return {
		"schema_version": CONTEXT_BUNDLE_SCHEMA_VERSION,
		"generator_version": TOOL_VERSION,
		"project_root": ".",
		"untrusted_content": True,
		"files": [
			{"path": item["path"], "size_bytes": item["size_bytes"], "sha256": item["sha256"]}
			for item in collected["files"]
		],
		"settings": [
			{"name": item["name"], "size_bytes": item["size_bytes"], "sha256": item["sha256"]}
			for item in collected["settings"]
		],
		"total_bytes": collected["total_bytes"],
	}


def _normalize_context_path(raw_path: str) -> str:
	if not isinstance(raw_path, str):
		raise ValueError("Context file paths must be strings.")
	if raw_path != raw_path.strip() or "\\" in raw_path or len(raw_path) > MAX_CONTEXT_PATH_CHARS:
		raise ValueError(f"Context file path is not canonical: {raw_path!r}")
	normalized = normalize_portable_ownership_path("res://" + raw_path)
	if not normalized:
		raise ValueError(f"Context file path is unsafe or non-portable: {raw_path!r}")
	return normalized.removeprefix("res://")


def _normalize_setting_names(setting_names: list[str]) -> list[str]:
	result: list[str] = []
	seen: set[str] = set()
	for name in setting_names:
		if (
			not isinstance(name, str)
			or name != name.strip()
			or len(name) > MAX_CONTEXT_SETTING_CHARS
			or _SETTING_NAME_PATTERN.fullmatch(name) is None
			or any(part in ("", ".", "..") for part in name.split("/"))
		):
			raise ValueError(f"Project setting name is invalid: {name!r}")
		identity = unicodedata.normalize("NFC", name).casefold()
		if identity in seen:
			raise ValueError(f"Project setting name is duplicated or case-colliding: {name}")
		seen.add(identity)
		result.append(name)
	return sorted(result)


def _read_selected_settings(project_root: Path, names: list[str]) -> dict[str, str]:
	if not names:
		return {}
	source = read_bounded_text(
		resolve_project_path(project_root, "project.godot", must_exist=True),
		MAX_PROJECT_FILE_BYTES,
	)
	requested = set(names)
	values: dict[str, str] = {}
	section = ""
	source_lines = source.splitlines()
	line_index = 0
	while line_index < len(source_lines):
		source_line = source_lines[line_index]
		line = source_line.strip()
		if not line or line.startswith((";", "#")):
			line_index += 1
			continue
		section_match = _SECTION_PATTERN.fullmatch(line)
		if section_match is not None:
			section = section_match.group(1)
			line_index += 1
			continue
		if not section or "=" not in line:
			line_index += 1
			continue
		key, first_fragment = source_line.split("=", 1)
		serialized_value, line_index = _read_serialized_setting_value(
			source_lines,
			line_index,
			first_fragment,
		)
		name = f"{section}/{key.strip()}"
		if name in requested:
			if name in values:
				raise ValueError(f"Project setting is declared more than once: {name}")
			values[name] = serialized_value
		line_index += 1
	missing = sorted(requested - set(values))
	if missing:
		raise ValueError(f"Project settings were not found: {', '.join(missing)}")
	return values


def _read_serialized_setting_value(
	source_lines: list[str],
	start_index: int,
	first_fragment: str,
) -> tuple[str, int]:
	"""Read one complete Godot Variant expression without evaluating project data."""
	fragments: list[str] = []
	delimiter_stack: list[str] = []
	in_string = False
	escaped = False
	line_index = start_index
	fragment = first_fragment.strip()
	while line_index < len(source_lines):
		expression_characters: list[str] = []
		for character in fragment:
			if in_string:
				expression_characters.append(character)
				if escaped:
					escaped = False
				elif character == "\\":
					escaped = True
				elif character == '"':
					in_string = False
				continue
			if character in ("#", ";"):
				break
			expression_characters.append(character)
			if character == '"':
				in_string = True
				continue
			if character in _OPENING_DELIMITERS:
				delimiter_stack.append(_OPENING_DELIMITERS[character])
				continue
			if character in _CLOSING_DELIMITERS:
				if not delimiter_stack or delimiter_stack[-1] != character:
					raise ValueError(
						f"Project setting has mismatched delimiters near line {line_index + 1}."
					)
				delimiter_stack.pop()
		expression_fragment = "".join(expression_characters).rstrip()
		if expression_fragment:
			fragments.append(expression_fragment)
		if not in_string and not delimiter_stack:
			serialized_value = "\n".join(fragments).strip()
			if not serialized_value:
				raise ValueError(f"Project setting has an empty value near line {start_index + 1}.")
			return serialized_value, line_index
		line_index += 1
		if line_index < len(source_lines):
			fragment = source_lines[line_index].strip()
	raise ValueError(f"Project setting value is incomplete near line {start_index + 1}.")


def _blocked(
	code: str,
	message: str,
	*,
	status: str = "blocked",
	**fields: Any,
) -> dict[str, Any]:
	return {
		"ok": False,
		"status": status,
		"issues": [{"code": code, "message": message}],
		**fields,
	}
