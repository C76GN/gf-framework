"""Bounded, evidence-producing project module dependency analysis."""

from __future__ import annotations

import os
import posixpath
import stat
from dataclasses import dataclass
from pathlib import Path
from typing import Any


MAX_DEPENDENCY_FILES = 20_000
MAX_DEPENDENCY_BYTES = 128 * 1024 * 1024
MAX_DEPENDENCY_FILE_BYTES = 2 * 1024 * 1024
MAX_EDGE_EVIDENCE = 12
MAX_AMBIGUOUS_CLASSES = 100
MAX_UNOWNED_REFERENCE_EVIDENCE = 100
SUPPORTED_EXTENSIONS = frozenset({".gd", ".gdshader", ".gdshaderinc", ".tres", ".tscn"})
_RESOURCE_TEXT_EXTENSIONS = frozenset({".gdshader", ".gdshaderinc", ".tres", ".tscn"})
_SKIPPED_DIRECTORY_NAMES = frozenset({".git", ".godot", ".import", "__pycache__", "node_modules"})


@dataclass(frozen=True)
class SourceToken:
	kind: str
	value: str
	line: int


class ModuleOwnershipMatcher:
	"""Longest-root matcher compiled once from validated contract modules."""

	def __init__(self, modules: list[dict[str, Any]]) -> None:
		roots: list[tuple[str, str]] = []
		for module in modules:
			module_id = str(module.get("id", ""))
			for raw_root in module.get("roots", []):
				if not isinstance(raw_root, str):
					continue
				root = _normalize_resource_path(raw_root)
				if root:
					roots.append((root, module_id))
		self._roots = sorted(roots, key=lambda item: (-len(item[0]), item[0], item[1]))

	def owner_of(self, resource_path: str) -> str:
		normalized = _normalize_resource_path(resource_path)
		if not normalized:
			return ""
		for root, module_id in self._roots:
			if normalized == root or normalized.startswith(root + "/"):
				return module_id
		return ""


def analyze_module_dependencies(
	project_root: Path,
	contract_data: dict[str, Any],
	*,
	contract_valid: bool,
) -> dict[str, Any]:
	modules = _contract_modules(contract_data)
	if not contract_valid:
		return _empty_analysis("contract_invalid", modules, complete=False)
	if not modules:
		return _empty_analysis("not_configured", modules, complete=True)

	matcher = ModuleOwnershipMatcher(modules)
	collection = _collect_module_files(project_root, modules)
	files: list[Path] = collection.pop("files")
	class_definitions: dict[str, list[tuple[str, str]]] = {}
	unreadable_paths: set[Path] = set()
	for path in files:
		if path.suffix.casefold() != ".gd":
			continue
		text = _read_utf8(path)
		if text is None:
			unreadable_paths.add(path)
			continue
		resource_path = _resource_path(project_root, path)
		module_id = matcher.owner_of(resource_path)
		for class_name in _declared_class_names(lex_gdscript(text)):
			class_definitions.setdefault(class_name, []).append((module_id, resource_path))

	all_ambiguous_classes = [
		{"class_name": class_name, "paths": sorted({path for _, path in definitions})}
		for class_name, definitions in sorted(class_definitions.items())
		if len({path for _, path in definitions}) > 1
	]
	ambiguous_classes = all_ambiguous_classes[0:MAX_AMBIGUOUS_CLASSES]
	class_owners = {
		class_name: definitions[0]
		for class_name, definitions in class_definitions.items()
		if len({path for _, path in definitions}) == 1
	}
	edges: dict[tuple[str, str], dict[str, Any]] = {}
	unowned_reference_count = 0
	unowned_references: list[dict[str, Any]] = []
	for path in files:
		if path in unreadable_paths:
			continue
		text = _read_utf8(path)
		if text is None:
			unreadable_paths.add(path)
			continue
		source_path = _resource_path(project_root, path)
		source_module = matcher.owner_of(source_path)
		if not source_module:
			continue
		if path.suffix.casefold() == ".gd":
			tokens = lex_gdscript(text)
			for token in tokens:
				if token.kind == "identifier" and token.value in class_owners:
					target_module, target_path = class_owners[token.value]
					_add_reference(
						edges,
						source_module,
						target_module,
						source_path,
						target_path,
						"class_name",
						token.value,
						token.line,
					)
				elif token.kind == "string":
					unowned_reference_count += _record_path_reference(
						edges,
						matcher,
						source_module,
						source_path,
						token.value,
						token.line,
						unowned_references,
					)
		elif path.suffix.casefold() in _RESOURCE_TEXT_EXTENSIONS:
			resource_tokens = (
				lex_shader_text(text)
				if path.suffix.casefold() in (".gdshader", ".gdshaderinc")
				else lex_resource_text(text)
			)
			for token in resource_tokens:
				unowned_reference_count += _record_path_reference(
					edges,
					matcher,
					source_module,
					source_path,
					token.value,
					token.line,
					unowned_references,
				)

	edge_records = _edge_records(edges)
	cycles = _dependency_cycles(edge_records, {str(module.get("id", "")) for module in modules})
	module_file_counts = []
	for module in modules:
		module_id = str(module.get("id", ""))
		owned_files = [path for path in files if matcher.owner_of(_resource_path(project_root, path)) == module_id]
		owned_classes = {
			class_name
			for class_name, definitions in class_definitions.items()
			if any(owner == module_id for owner, _ in definitions)
		}
		module_file_counts.append({
			"module_id": module_id,
			"file_count": len(owned_files),
			"class_name_count": len(owned_classes),
		})

	unreadable_count = len(unreadable_paths)
	truncated = bool(collection["truncated"])
	complete = (
		not truncated
		and unreadable_count == 0
		and collection["missing_root_count"] == 0
		and collection["unsafe_path_count"] == 0
		and not all_ambiguous_classes
	)
	status = "complete" if complete else ("truncated" if truncated else "incomplete")
	return {
		"status": status,
		"complete": complete,
		"truncated": truncated,
		"supported_extensions": sorted(SUPPORTED_EXTENSIONS),
		"scanned_file_count": len(files),
		"scanned_byte_count": int(collection["scanned_byte_count"]),
		"oversized_file_count": int(collection["oversized_file_count"]),
		"unreadable_file_count": unreadable_count,
		"missing_root_count": int(collection["missing_root_count"]),
		"unsafe_path_count": int(collection["unsafe_path_count"]),
		"unowned_reference_count": unowned_reference_count,
		"unowned_references_truncated": unowned_reference_count > len(unowned_references),
		"unowned_references": unowned_references,
		"module_file_counts": sorted(module_file_counts, key=lambda item: item["module_id"]),
		"ambiguous_class_name_count": len(all_ambiguous_classes),
		"ambiguous_class_names_truncated": len(all_ambiguous_classes) > len(ambiguous_classes),
		"ambiguous_class_names": ambiguous_classes,
		"edges": edge_records,
		"cycles": cycles,
	}


def lex_gdscript(source: str) -> list[SourceToken]:
	"""Return exact identifiers and string literals while excluding comments."""
	return _lex_text(source, comment_markers=("#",), identifiers=True)


def lex_resource_text(source: str) -> list[SourceToken]:
	"""Return quoted values from Godot text resources while excluding comments."""
	return _lex_text(source, comment_markers=("#", ";"), identifiers=False)


def lex_shader_text(source: str) -> list[SourceToken]:
	"""Return shader string literals while excluding C-style comments."""
	tokens: list[SourceToken] = []
	index = 0
	line = 1
	length = len(source)
	while index < length:
		if source.startswith("//", index):
			newline = source.find("\n", index)
			if newline < 0:
				break
			index = newline
			continue
		if source.startswith("/*", index):
			end = source.find("*/", index + 2)
			comment_end = length if end < 0 else end + 2
			line += source.count("\n", index, comment_end)
			index = comment_end
			continue
		character = source[index]
		if character == "\n":
			line += 1
			index += 1
			continue
		if character in ("'", '"'):
			quote = character
			start_line = line
			index += 1
			value: list[str] = []
			while index < length and source[index] != quote:
				if source[index] == "\\" and index + 1 < length:
					if source[index + 1] == "\n":
						line += 1
					value.append(source[index + 1])
					index += 2
					continue
				if source[index] == "\n":
					line += 1
				value.append(source[index])
				index += 1
			if index < length:
				index += 1
			tokens.append(SourceToken("string", "".join(value), start_line))
			continue
		index += 1
	return tokens


def _lex_text(source: str, *, comment_markers: tuple[str, ...], identifiers: bool) -> list[SourceToken]:
	tokens: list[SourceToken] = []
	index = 0
	line = 1
	length = len(source)
	while index < length:
		character = source[index]
		if character == "\n":
			line += 1
			index += 1
			continue
		if character in comment_markers:
			newline = source.find("\n", index)
			if newline < 0:
				break
			index = newline
			continue
		if character in ("'", '"'):
			quote = character
			start_line = line
			triple = source.startswith(quote * 3, index)
			index += 3 if triple else 1
			value: list[str] = []
			while index < length:
				if triple and source.startswith(quote * 3, index):
					index += 3
					break
				if not triple and source[index] == quote:
					index += 1
					break
				if source[index] == "\\" and index + 1 < length:
					if source[index + 1] == "\n":
						line += 1
					value.append(source[index + 1])
					index += 2
					continue
				if source[index] == "\n":
					line += 1
				value.append(source[index])
				index += 1
			tokens.append(SourceToken("string", "".join(value), start_line))
			continue
		if identifiers and (character == "_" or character.isalpha()):
			start = index
			index += 1
			while index < length and (source[index] == "_" or source[index].isalnum()):
				index += 1
			tokens.append(SourceToken("identifier", source[start:index], line))
			continue
		index += 1
	return tokens


def _declared_class_names(tokens: list[SourceToken]) -> set[str]:
	result: set[str] = set()
	for index, token in enumerate(tokens[:-1]):
		if token.kind == "identifier" and token.value == "class_name":
			candidate = tokens[index + 1]
			if candidate.kind == "identifier":
				result.add(candidate.value)
	return result


def _collect_module_files(project_root: Path, modules: list[dict[str, Any]]) -> dict[str, Any]:
	files: list[Path] = []
	seen: set[Path] = set()
	total_bytes = 0
	oversized_count = 0
	missing_root_count = 0
	unsafe_path_count = 0
	truncated = False
	for raw_root in sorted({root for module in modules for root in module.get("roots", []) if isinstance(root, str)}):
		normalized_root = _normalize_resource_path(raw_root)
		if normalized_root in ("", "res://"):
			missing_root_count += 1
			continue
		relative_root = normalized_root.removeprefix("res://")
		root = (project_root / Path(*relative_root.split("/"))).resolve(strict=False)
		if not root.is_dir() or not _safe_path(project_root, root, directory=True):
			missing_root_count += 1
			continue
		for current_root, directory_names, file_names in os.walk(root, topdown=True, followlinks=False):
			current_path = Path(current_root)
			safe_directories: list[str] = []
			for name in sorted(directory_names):
				if name in _SKIPPED_DIRECTORY_NAMES:
					continue
				if _safe_path(project_root, current_path / name, directory=True):
					safe_directories.append(name)
				else:
					unsafe_path_count += 1
			directory_names[:] = safe_directories
			for file_name in sorted(file_names):
				path = current_path / file_name
				if path.suffix.casefold() not in SUPPORTED_EXTENSIONS or path in seen:
					continue
				seen.add(path)
				if not _safe_path(project_root, path, directory=False):
					unsafe_path_count += 1
					continue
				try:
					size = path.stat().st_size
				except OSError:
					unsafe_path_count += 1
					continue
				if size > MAX_DEPENDENCY_FILE_BYTES:
					oversized_count += 1
					truncated = True
					continue
				if len(files) >= MAX_DEPENDENCY_FILES or total_bytes + size > MAX_DEPENDENCY_BYTES:
					truncated = True
					break
				files.append(path)
				total_bytes += size
			if truncated and (len(files) >= MAX_DEPENDENCY_FILES or total_bytes >= MAX_DEPENDENCY_BYTES):
				break
		if truncated and (len(files) >= MAX_DEPENDENCY_FILES or total_bytes >= MAX_DEPENDENCY_BYTES):
			break
	return {
		"files": sorted(files),
		"scanned_byte_count": total_bytes,
		"oversized_file_count": oversized_count,
		"missing_root_count": missing_root_count,
		"unsafe_path_count": unsafe_path_count,
		"truncated": truncated,
	}


def _record_path_reference(
	edges: dict[tuple[str, str], dict[str, Any]],
	matcher: ModuleOwnershipMatcher,
	source_module: str,
	source_path: str,
	raw_target_path: str,
	line: int,
	unowned_references: list[dict[str, Any]],
) -> int:
	target_path = _normalize_resource_path(raw_target_path)
	if not target_path:
		return 0
	target_module = matcher.owner_of(target_path)
	if not target_module:
		if target_path.startswith("res://addons/gf/"):
			return 0
		candidate = {
			"source_path": source_path,
			"target_path": target_path,
			"line": max(line, 1),
		}
		if len(unowned_references) < MAX_UNOWNED_REFERENCE_EVIDENCE and candidate not in unowned_references:
			unowned_references.append(candidate)
		return 1
	_add_reference(edges, source_module, target_module, source_path, target_path, "resource_path", raw_target_path, line)
	return 0


def _add_reference(
	edges: dict[tuple[str, str], dict[str, Any]],
	source_module: str,
	target_module: str,
	source_path: str,
	target_path: str,
	kind: str,
	symbol: str,
	line: int,
) -> None:
	if not source_module or not target_module or source_module == target_module:
		return
	key = (source_module, target_module)
	record = edges.setdefault(
		key,
		{"reference_count": 0, "kinds": set(), "evidence": [], "evidence_truncated": False},
	)
	record["reference_count"] += 1
	record["kinds"].add(kind)
	evidence = record["evidence"]
	candidate = {
		"source_path": source_path,
		"target_path": target_path,
		"kind": kind,
		"symbol": symbol,
		"line": max(line, 1),
	}
	if candidate in evidence:
		return
	if len(evidence) < MAX_EDGE_EVIDENCE:
		evidence.append(candidate)
	else:
		record["evidence_truncated"] = True


def _edge_records(edges: dict[tuple[str, str], dict[str, Any]]) -> list[dict[str, Any]]:
	return [
		{
			"source_module": source,
			"target_module": target,
			"reference_count": int(record["reference_count"]),
			"kinds": sorted(record["kinds"]),
			"evidence_truncated": bool(record["evidence_truncated"]),
			"evidence": sorted(record["evidence"], key=lambda item: (item["source_path"], item["line"], item["kind"], item["symbol"])),
		}
		for (source, target), record in sorted(edges.items())
	]


def _dependency_cycles(edges: list[dict[str, Any]], module_ids: set[str]) -> list[list[str]]:
	graph = {module_id: set() for module_id in module_ids}
	for edge in edges:
		graph[str(edge["source_module"])].add(str(edge["target_module"]))
	index = 0
	indices: dict[str, int] = {}
	low_links: dict[str, int] = {}
	stack: list[str] = []
	on_stack: set[str] = set()
	components: list[list[str]] = []

	def connect(node: str) -> None:
		nonlocal index
		indices[node] = index
		low_links[node] = index
		index += 1
		stack.append(node)
		on_stack.add(node)
		for target in sorted(graph.get(node, set())):
			if target not in indices:
				connect(target)
				low_links[node] = min(low_links[node], low_links[target])
			elif target in on_stack:
				low_links[node] = min(low_links[node], indices[target])
		if low_links[node] != indices[node]:
			return
		component: list[str] = []
		while stack:
			member = stack.pop()
			on_stack.remove(member)
			component.append(member)
			if member == node:
				break
		if len(component) > 1:
			components.append(sorted(component))

	for module_id in sorted(module_ids):
		if module_id not in indices:
			connect(module_id)
	return sorted(components)


def _contract_modules(contract_data: dict[str, Any]) -> list[dict[str, Any]]:
	architecture = contract_data.get("architecture", {})
	if not isinstance(architecture, dict) or not isinstance(architecture.get("modules"), list):
		return []
	return [module for module in architecture["modules"] if isinstance(module, dict)]


def _empty_analysis(status: str, modules: list[dict[str, Any]], *, complete: bool) -> dict[str, Any]:
	return {
		"status": status,
		"complete": complete,
		"truncated": False,
		"supported_extensions": sorted(SUPPORTED_EXTENSIONS),
		"scanned_file_count": 0,
		"scanned_byte_count": 0,
		"oversized_file_count": 0,
		"unreadable_file_count": 0,
		"missing_root_count": 0,
		"unsafe_path_count": 0,
		"unowned_reference_count": 0,
		"unowned_references_truncated": False,
		"unowned_references": [],
		"module_file_counts": [
			{"module_id": str(module.get("id", "")), "file_count": 0, "class_name_count": 0}
			for module in modules
		],
		"ambiguous_class_name_count": 0,
		"ambiguous_class_names_truncated": False,
		"ambiguous_class_names": [],
		"edges": [],
		"cycles": [],
	}


def _normalize_resource_path(raw_path: str) -> str:
	normalized = raw_path.strip().replace("\\", "/")
	if not normalized.startswith("res://"):
		return ""
	relative = normalized.removeprefix("res://")
	if not relative:
		return "res://"
	parts = relative.split("/")
	if any(part in ("", ".", "..") for part in parts):
		return ""
	return "res://" + posixpath.normpath(relative)


def _resource_path(project_root: Path, path: Path) -> str:
	return "res://" + path.relative_to(project_root).as_posix()


def _read_utf8(path: Path) -> str | None:
	try:
		return path.read_text(encoding="utf-8")
	except (OSError, UnicodeDecodeError):
		return None


def _safe_path(project_root: Path, path: Path, *, directory: bool) -> bool:
	try:
		metadata = path.lstat()
		if path.is_symlink():
			return False
		reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
		if reparse_flag and getattr(metadata, "st_file_attributes", 0) & reparse_flag:
			return False
		path.resolve(strict=True).relative_to(project_root)
		return path.is_dir() if directory else path.is_file()
	except (OSError, ValueError):
		return False
