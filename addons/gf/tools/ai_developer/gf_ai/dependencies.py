"""Bounded, evidence-producing project module dependency analysis."""

from __future__ import annotations

from collections.abc import Iterator
import os
import posixpath
import stat
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .constants import RESERVED_DEPENDENCY_IDS
from .paths import (
	is_reserved_framework_resource_path,
	normalize_portable_ownership_path,
	normalize_resource_path,
	portable_ownership_path_identity,
	project_path_has_link_component,
)


MAX_DEPENDENCY_FILES = 20_000
MAX_DEPENDENCY_BYTES = 128 * 1024 * 1024
MAX_DEPENDENCY_FILE_BYTES = 2 * 1024 * 1024
MAX_EDGE_EVIDENCE = 12
MAX_AMBIGUOUS_CLASSES = 100
MAX_DECLARED_CLASS_OBSERVATIONS = MAX_DEPENDENCY_FILES
MAX_UNOWNED_REFERENCE_EVIDENCE = 100
MAX_OWNED_RESOURCE_REFERENCE_EVIDENCE = 100
MAX_PATH_ROLE_REFERENCE_EVIDENCE = 100
MAX_PATH_ROLE_DEPENDENCY_VIOLATION_EVIDENCE = 100
MAX_ADVISORY_REFERENCE_EVIDENCE = 100
SUPPORTED_EXTENSIONS = frozenset({".gd", ".gdshader", ".gdshaderinc", ".tres", ".tscn"})
_RESOURCE_TEXT_EXTENSIONS = frozenset({".gdshader", ".gdshaderinc", ".tres", ".tscn"})
_SKIPPED_DIRECTORY_NAMES = frozenset({".git", ".godot", ".import", "__pycache__", "node_modules"})


@dataclass(frozen=True)
class SourceToken:
	kind: str
	value: str
	line: int
	raw: bool = False


@dataclass(frozen=True)
class PinnedSource:
	text: str
	identity: tuple[int, int, int, int, int]


@dataclass
class PathRoleTraversalBudget:
	remaining_entries: int
	remaining_bytes: int


@dataclass(frozen=True)
class PathRoleState:
	path: str
	role: str
	status: str
	covered_modules: tuple[str, ...]


@dataclass(frozen=True)
class TargetOwnershipRoot:
	owner_id: str
	resource_root: str
	source_module: bool
	scan_files: bool
	require_existing_root: bool
	reference_kind: str


class TargetOwnershipPlan:
	"""One fail-closed target ownership plan for project modules and adapters."""

	def __init__(
		self,
		modules: list[dict[str, Any]],
		adapters: list[dict[str, Any]] | None = None,
	) -> None:
		roots: list[TargetOwnershipRoot] = []
		missing_root_count = 0
		unsafe_path_count = 0
		module_ids: set[str] = set()
		component_ids: set[str] = set()
		for module in modules:
			module_id = str(module.get("id", ""))
			if (
				not module_id
				or module_id in RESERVED_DEPENDENCY_IDS
				or module_id in component_ids
			):
				unsafe_path_count += 1
				continue
			component_ids.add(module_id)
			module_ids.add(module_id)
			raw_roots = module.get("roots", [])
			if not isinstance(raw_roots, list) or not raw_roots:
				missing_root_count += 1
				continue
			generated_output = module.get("ownership") == "generated"
			for raw_root in raw_roots:
				if not isinstance(raw_root, str):
					missing_root_count += 1
					continue
				root = normalize_portable_ownership_path(raw_root)
				if not root or is_reserved_framework_resource_path(root):
					unsafe_path_count += 1
					continue
				roots.append(TargetOwnershipRoot(
					owner_id=module_id,
					resource_root=root,
					source_module=not generated_output,
					scan_files=not generated_output,
					require_existing_root=not generated_output,
					reference_kind="generated_output" if generated_output else "resource_load",
				))
		for adapter in adapters or []:
			adapter_id = str(adapter.get("id", ""))
			if (
				not adapter_id
				or adapter_id in RESERVED_DEPENDENCY_IDS
				or adapter_id in component_ids
			):
				unsafe_path_count += 1
				continue
			component_ids.add(adapter_id)
			raw_root = adapter.get("project_root")
			if not isinstance(raw_root, str) or not raw_root:
				missing_root_count += 1
				continue
			root = normalize_portable_ownership_path(raw_root)
			if not root or is_reserved_framework_resource_path(root):
				unsafe_path_count += 1
				continue
			roots.append(TargetOwnershipRoot(
				owner_id=adapter_id,
				resource_root=root,
				source_module=False,
				scan_files=True,
				require_existing_root=True,
				reference_kind="resource_load",
			))

		for left_index, left in enumerate(roots):
			left_parts = _portable_root_parts(left.resource_root)
			for right in roots[left_index + 1:]:
				right_parts = _portable_root_parts(right.resource_root)
				shorter = min(len(left_parts), len(right_parts))
				if shorter > 0 and left_parts[:shorter] == right_parts[:shorter]:
					unsafe_path_count += 1

		if unsafe_path_count > 0:
			roots.clear()
		self._roots = tuple(sorted(
			roots,
			key=lambda item: (-len(item.resource_root), item.resource_root, item.owner_id),
		))
		self._module_ids = frozenset(module_ids)
		self._component_ids = frozenset(component_ids)
		self.missing_root_count = missing_root_count
		self.unsafe_path_count = unsafe_path_count

	@property
	def roots(self) -> tuple[TargetOwnershipRoot, ...]:
		return self._roots

	@property
	def module_ids(self) -> frozenset[str]:
		return self._module_ids

	@property
	def component_ids(self) -> frozenset[str]:
		return self._component_ids

	def ownership_of(self, resource_path: str) -> TargetOwnershipRoot | None:
		normalized = normalize_resource_path(resource_path)
		if not normalized:
			return None
		for record in self._roots:
			if normalized == record.resource_root or normalized.startswith(record.resource_root + "/"):
				return record
		return None

	def owner_of(self, resource_path: str) -> str:
		record = self.ownership_of(resource_path)
		return record.owner_id if record is not None else ""


def analyze_module_dependencies(
	project_root: Path,
	contract_data: dict[str, Any],
	*,
	contract_valid: bool,
) -> dict[str, Any]:
	modules = _contract_modules(contract_data)
	adapters = _contract_adapters(contract_data)
	if not contract_valid:
		return _empty_analysis("contract_invalid", modules, complete=False)
	owned_resource_collection = _collect_owned_resources(project_root, contract_data)
	target_plan = TargetOwnershipPlan(modules, adapters)
	collection = _collect_target_files(project_root, target_plan)
	path_role_collection = _collect_path_roles(project_root, contract_data, target_plan)
	available_owned_resources = set(owned_resource_collection["available_paths"])
	files: list[Path] = collection.pop("files")
	collection_identities: dict[Path, tuple[int, int, int, int, int]] = collection.pop("file_identities")
	source_identities: dict[Path, tuple[int, int, int, int, int]] = {}
	class_definitions: dict[str, list[tuple[str, str]]] = {}
	class_observation_count = 0
	class_observations_truncated = False
	unreadable_paths: set[Path] = set()
	unstable_paths: set[Path] = set()
	for path in files:
		expected_identity = collection_identities.get(path)
		if expected_identity is None or _path_identity(path) != expected_identity:
			unstable_paths.add(path)
			continue
		source = _read_pinned_utf8(path, expected_identity=expected_identity)
		if source is None:
			if _path_identity(path) != expected_identity:
				unstable_paths.add(path)
			else:
				unreadable_paths.add(path)
			continue
		source_identities[path] = source.identity
		suffix = path.suffix.casefold()
		if suffix == ".gd":
			tokens = lex_gdscript(source.text)
		elif suffix in (".gdshader", ".gdshaderinc"):
			tokens = lex_shader_text(source.text)
		else:
			tokens = lex_resource_text(source.text)
		if suffix != ".gd":
			del tokens
			continue
		resource_path = _resource_path(project_root, path)
		owner_id = target_plan.owner_of(resource_path)
		for class_name in _declared_class_names(tokens):
			if class_observation_count >= MAX_DECLARED_CLASS_OBSERVATIONS:
				class_observations_truncated = True
				break
			class_observation_count += 1
			class_definitions.setdefault(class_name, []).append((owner_id, resource_path))
		del tokens

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
	owned_resource_reference_count = 0
	owned_resource_references: list[dict[str, Any]] = []
	path_role_reference_count = 0
	path_role_references: list[dict[str, Any]] = []
	path_role_dependency_violation_count = 0
	path_role_dependency_violations: list[dict[str, Any]] = []
	advisory_reference_count = 0
	advisory_references: list[dict[str, Any]] = []
	module_allowed_dependencies = {
		str(module.get("id", "")): frozenset(
			dependency_id
			for dependency_id in module.get("allowed_dependencies", [])
			if isinstance(dependency_id, str)
		)
		for module in modules
		if str(module.get("id", ""))
	}
	for path in files:
		if path in unreadable_paths or path not in source_identities:
			continue
		source = _read_pinned_utf8(path, expected_identity=source_identities[path])
		if source is None or source.identity != source_identities[path]:
			unstable_paths.add(path)
			continue
		source_path = _resource_path(project_root, path)
		source_ownership = target_plan.ownership_of(source_path)
		if source_ownership is None or not source_ownership.source_module:
			continue
		source_module = source_ownership.owner_id
		source_domain = _source_domain(path, project_root)
		suffix = path.suffix.casefold()
		if suffix == ".gd":
			tokens = lex_gdscript(source.text)
		elif suffix in (".gdshader", ".gdshaderinc"):
			tokens = lex_shader_text(source.text)
		else:
			tokens = lex_resource_text(source.text)
		if suffix == ".gd":
			for token_index, token in enumerate(tokens):
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
					increments = _record_path_observation(
						edges,
						target_plan,
						available_owned_resources,
						path_role_collection["states"],
						module_allowed_dependencies,
						source_module,
						source_path,
						source_domain,
						token.value,
						token.line,
						_gdscript_string_reference_kind(tokens, token_index),
						unowned_references,
						owned_resource_references,
						path_role_references,
						path_role_dependency_violations,
						advisory_references,
					)
					unowned_reference_count += increments[0]
					owned_resource_reference_count += increments[1]
					path_role_reference_count += increments[2]
					path_role_dependency_violation_count += increments[3]
					advisory_reference_count += increments[4]
		elif suffix in _RESOURCE_TEXT_EXTENSIONS:
			resource_lines = source.text.splitlines()
			for token_index, token in enumerate(tokens):
				if token.kind not in ("string", "shader_include"):
					continue
				if suffix in (".gdshader", ".gdshaderinc"):
					high_confidence_kind = "shader_include" if token.kind == "shader_include" else None
				else:
					high_confidence_kind = _resource_string_reference_kind(
						tokens,
						token_index,
						resource_lines,
					)
				target_literal = token.value
				if high_confidence_kind == "shader_include":
					target_literal = _resolve_shader_include(source_path, token.value)
				increments = _record_path_observation(
					edges,
					target_plan,
					available_owned_resources,
					path_role_collection["states"],
					module_allowed_dependencies,
					source_module,
					source_path,
					source_domain,
					target_literal,
					token.line,
					high_confidence_kind,
					unowned_references,
					owned_resource_references,
					path_role_references,
					path_role_dependency_violations,
					advisory_references,
				)
				unowned_reference_count += increments[0]
				owned_resource_reference_count += increments[1]
				path_role_reference_count += increments[2]
				path_role_dependency_violation_count += increments[3]
				advisory_reference_count += increments[4]
		del tokens

	unstable_paths.update({
		path
		for path, identity in source_identities.items()
		if _path_identity(path) != identity
	})
	_mark_late_path_role_drift(path_role_collection)

	edge_records = _edge_records(edges)
	cycles = _dependency_cycles(edge_records, set(target_plan.module_ids))
	module_file_counts = []
	for module in modules:
		module_id = str(module.get("id", ""))
		owned_files = [
			path
			for path in files
			if target_plan.owner_of(_resource_path(project_root, path)) == module_id
		]
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
	truncated = bool(
		collection["truncated"]
		or path_role_collection["truncated"]
		or class_observations_truncated
	)
	unsafe_path_count = (
		int(collection["unsafe_path_count"])
		+ int(path_role_collection["unsafe_count"])
		+ len(unstable_paths)
	)
	complete = (
		not truncated
		and unreadable_count == 0
		and collection["missing_root_count"] == 0
		and unsafe_path_count == 0
		and owned_resource_collection["missing_count"] == 0
		and owned_resource_collection["unsafe_count"] == 0
		and path_role_collection["partial_count"] == 0
		and not all_ambiguous_classes
	)
	status = ("complete" if modules else "not_configured") if complete else "partial"
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
		"unsafe_path_count": unsafe_path_count,
		"declared_owned_resource_count": len(owned_resource_collection["records"]),
		"missing_owned_resource_count": int(owned_resource_collection["missing_count"]),
		"unsafe_owned_resource_count": int(owned_resource_collection["unsafe_count"]),
		"owned_resources": owned_resource_collection["records"],
		"owned_resource_reference_count": owned_resource_reference_count,
		"owned_resource_references_truncated": owned_resource_reference_count > len(owned_resource_references),
		"owned_resource_references": sorted(
			owned_resource_references,
			key=lambda item: (item["source_path"], item["line"], item["target_path"]),
		),
		"declared_path_role_count": len(path_role_collection["records"]),
		"partial_path_role_count": int(path_role_collection["partial_count"]),
		"path_roles": path_role_collection["records"],
		"path_role_reference_count": path_role_reference_count,
		"path_role_references_truncated": path_role_reference_count > len(path_role_references),
		"path_role_references": sorted(
			path_role_references,
			key=lambda item: (item["source_path"], item["line"], item["target_path"], item["role"]),
		),
		"path_role_dependency_violation_count": path_role_dependency_violation_count,
		"path_role_dependency_violations_truncated": (
			path_role_dependency_violation_count > len(path_role_dependency_violations)
		),
		"path_role_dependency_violations": sorted(
			path_role_dependency_violations,
			key=lambda item: (
				item["source_path"],
				item["line"],
				item["target_path"],
				item["target_module"],
			),
		),
		"advisory_reference_count": advisory_reference_count,
		"advisory_references_truncated": advisory_reference_count > len(advisory_references),
		"advisory_references": sorted(
			advisory_references,
			key=lambda item: (item["source_path"], item["line"], item["target_path"]),
		),
		"unowned_reference_count": unowned_reference_count,
		"unowned_references_truncated": unowned_reference_count > len(unowned_references),
		"unowned_references": sorted(
			unowned_references,
			key=lambda item: (item["source_path"], item["line"], item["target_path"]),
		),
		"module_file_counts": sorted(module_file_counts, key=lambda item: item["module_id"]),
		"ambiguous_class_name_count": len(all_ambiguous_classes),
		"ambiguous_class_names_truncated": len(all_ambiguous_classes) > len(ambiguous_classes),
		"ambiguous_class_names": ambiguous_classes,
		"edges": edge_records,
		"cycles": cycles,
	}


def lex_gdscript(source: str) -> list[SourceToken]:
	"""Return exact identifiers and string literals while excluding comments."""
	return _lex_text(source, comment_markers=("#",), identifiers=True, punctuation=True)


def lex_resource_text(source: str) -> list[SourceToken]:
	"""Return quoted values from Godot text resources while excluding comments."""
	return _lex_text(source, comment_markers=("#", ";"), identifiers=True, punctuation=True)


def lex_shader_text(source: str) -> list[SourceToken]:
	"""Return shader strings and exact include directives outside comments."""
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
			line_start = source.rfind("\n", 0, index) + 1
			kind = (
				"shader_include"
				if character == '"' and source[line_start:index].strip() == "#include"
				else "string"
			)
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
			tokens.append(SourceToken(kind, "".join(value), start_line))
			continue
		index += 1
	return tokens


def _lex_text(
	source: str,
	*,
	comment_markers: tuple[str, ...],
	identifiers: bool,
	punctuation: bool,
) -> list[SourceToken]:
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
			raw_string = bool(
				index > 0
				and source[index - 1] == "r"
				and (
					index < 2
					or not (source[index - 2] == "_" or source[index - 2].isalnum())
				)
			)
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
			tokens.append(SourceToken("string", "".join(value), start_line, raw=raw_string))
			continue
		if identifiers and (character == "_" or character.isalpha()):
			start = index
			index += 1
			while index < length and (source[index] == "_" or source[index].isalnum()):
				index += 1
			tokens.append(SourceToken("identifier", source[start:index], line))
			continue
		if punctuation and character in "().,=":
			tokens.append(SourceToken("punctuation", character, line))
		index += 1
	return tokens


def _declared_class_names(tokens: list[SourceToken]) -> Iterator[str]:
	seen: set[str] = set()
	for index, token in enumerate(tokens[:-1]):
		if token.kind == "identifier" and token.value == "class_name":
			candidate = tokens[index + 1]
			if candidate.kind == "identifier" and candidate.value not in seen:
				seen.add(candidate.value)
				yield candidate.value


def _gdscript_string_reference_kind(
	tokens: list[SourceToken],
	string_index: int,
) -> str | None:
	literal_prefix = tokens[string_index - 1] if string_index >= 1 else None
	prefix_length = 1 if (
		tokens[string_index].raw
		and literal_prefix is not None
		and literal_prefix.kind == "identifier"
		and literal_prefix.value == "r"
	) else 0
	opening_index = string_index - 1 - prefix_length
	method_index = string_index - 2 - prefix_length
	if method_index < 0:
		return None
	opening = tokens[opening_index]
	method = tokens[method_index]
	if opening.kind != "punctuation" or opening.value != "(" or method.kind != "identifier":
		return None
	previous = tokens[method_index - 1] if method_index >= 1 else None
	if method.value in ("load", "preload") and not (
		previous is not None
		and previous.kind == "punctuation"
		and previous.value == "."
	):
		return "resource_load"
	if method.value not in ("load", "load_threaded_request", "load_threaded_get"):
		return None
	if method_index < 2:
		return None
	receiver_separator = tokens[method_index - 1]
	receiver = tokens[method_index - 2]
	receiver_prefix = tokens[method_index - 3] if method_index >= 3 else None
	if (
		receiver_separator.kind == "punctuation"
		and receiver_separator.value == "."
		and receiver.kind == "identifier"
		and receiver.value == "ResourceLoader"
		and not (
			receiver_prefix is not None
			and receiver_prefix.kind == "punctuation"
			and receiver_prefix.value == "."
		)
	):
		return "resource_load"
	return None


def _resource_string_reference_kind(
	tokens: list[SourceToken],
	string_index: int,
	source_lines: list[str],
) -> str | None:
	if string_index < 2:
		return None
	separator = tokens[string_index - 1]
	field = tokens[string_index - 2]
	if (
		separator.kind == "punctuation"
		and separator.value == "="
		and field.kind == "identifier"
		and field.value == "path"
	):
		line_index = tokens[string_index].line - 1
		if (
			0 <= line_index < len(source_lines)
			and source_lines[line_index].lstrip().startswith("[ext_resource")
		):
			return "resource_field"
	return None


def _resolve_shader_include(source_path: str, raw_include: str) -> str:
	if normalize_resource_path(raw_include):
		return raw_include
	if (
		not raw_include
		or raw_include != raw_include.strip()
		or "\\" in raw_include
		or raw_include.startswith("/")
	):
		return raw_include
	parent = posixpath.dirname(source_path.removeprefix("res://"))
	resolved = posixpath.normpath(posixpath.join(parent, raw_include))
	if resolved in ("", ".", "..") or resolved.startswith("../"):
		return raw_include
	return "res://" + resolved


def _collect_target_files(project_root: Path, plan: TargetOwnershipPlan) -> dict[str, Any]:
	files: list[Path] = []
	file_identities: dict[Path, tuple[int, int, int, int, int]] = {}
	seen: set[Path] = set()
	total_bytes = 0
	oversized_count = 0
	missing_root_count = plan.missing_root_count
	unsafe_path_count = plan.unsafe_path_count
	truncated = False
	if unsafe_path_count > 0:
		return {
			"files": [],
			"file_identities": {},
			"scanned_byte_count": 0,
			"oversized_file_count": 0,
			"missing_root_count": missing_root_count,
			"unsafe_path_count": unsafe_path_count,
			"truncated": False,
		}

	def record_walk_error(_error: OSError) -> None:
		nonlocal unsafe_path_count
		unsafe_path_count += 1

	for record in sorted(plan.roots, key=lambda item: (item.resource_root, item.owner_id)):
		relative_root = record.resource_root.removeprefix("res://")
		root = project_root / Path(*relative_root.split("/"))
		if project_path_has_link_component(project_root, relative_root):
			unsafe_path_count += 1
			continue
		if not record.require_existing_root:
			try:
				root.lstat()
			except FileNotFoundError:
				continue
			except OSError:
				unsafe_path_count += 1
				continue
			if not _safe_path(project_root, root, directory=True):
				unsafe_path_count += 1
			continue
		if not root.is_dir() or not _safe_path(project_root, root, directory=True):
			missing_root_count += 1
			continue
		if not record.scan_files:
			continue
		for current_root, directory_names, file_names in os.walk(
			root,
			topdown=True,
			followlinks=False,
			onerror=record_walk_error,
		):
			current_path = Path(current_root)
			if ".gdignore" in file_names:
				marker_path = current_path / ".gdignore"
				if _safe_path(project_root, marker_path, directory=False):
					directory_names[:] = []
					continue
				unsafe_path_count += 1
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
				suffix = path.suffix.casefold()
				if (
					suffix not in SUPPORTED_EXTENSIONS
					or (not record.source_module and suffix != ".gd")
					or path in seen
				):
					continue
				seen.add(path)
				if not _safe_path(project_root, path, directory=False):
					unsafe_path_count += 1
					continue
				try:
					metadata = path.lstat()
				except OSError:
					unsafe_path_count += 1
					continue
				if _metadata_is_link_or_reparse(path, metadata) or not stat.S_ISREG(metadata.st_mode):
					unsafe_path_count += 1
					continue
				identity = _stat_identity(metadata)
				if _path_identity(path) != identity:
					unsafe_path_count += 1
					continue
				size = int(metadata.st_size)
				if size > MAX_DEPENDENCY_FILE_BYTES:
					oversized_count += 1
					truncated = True
					continue
				if len(files) >= MAX_DEPENDENCY_FILES or total_bytes + size > MAX_DEPENDENCY_BYTES:
					truncated = True
					break
				files.append(path)
				file_identities[path] = identity
				total_bytes += size
			if truncated and (len(files) >= MAX_DEPENDENCY_FILES or total_bytes >= MAX_DEPENDENCY_BYTES):
				break
		if truncated and (len(files) >= MAX_DEPENDENCY_FILES or total_bytes >= MAX_DEPENDENCY_BYTES):
			break
	return {
		"files": sorted(files),
		"file_identities": file_identities,
		"scanned_byte_count": total_bytes,
		"oversized_file_count": oversized_count,
		"missing_root_count": missing_root_count,
		"unsafe_path_count": unsafe_path_count,
		"truncated": truncated,
	}


def _collect_owned_resources(project_root: Path, contract_data: dict[str, Any]) -> dict[str, Any]:
	records: list[dict[str, str]] = []
	available_paths: list[str] = []
	missing_count = 0
	unsafe_count = 0
	for raw_path in _contract_owned_resources(contract_data):
		normalized_path = normalize_portable_ownership_path(raw_path)
		if not normalized_path or is_reserved_framework_resource_path(normalized_path):
			records.append({"path": raw_path, "status": "unsafe"})
			unsafe_count += 1
			continue
		relative_path = normalized_path.removeprefix("res://")
		path = project_root / Path(*relative_path.split("/"))
		if not path.exists():
			status = "missing"
			missing_count += 1
		elif not _safe_path(project_root, path, directory=False):
			status = "unsafe"
			unsafe_count += 1
		else:
			status = "available"
			available_paths.append(normalized_path)
		records.append({"path": normalized_path, "status": status})
	return {
		"records": sorted(records, key=lambda item: item["path"]),
		"available_paths": sorted(available_paths),
		"missing_count": missing_count,
		"unsafe_count": unsafe_count,
	}


def _collect_path_roles(
	project_root: Path,
	contract_data: dict[str, Any],
	plan: TargetOwnershipPlan,
) -> dict[str, Any]:
	declarations = _contract_path_roles(contract_data)
	prepared: list[dict[str, Any]] = []
	conflicts: set[int] = set()
	for index, declaration in enumerate(declarations):
		raw_path = declaration.get("path")
		role = declaration.get("role")
		path = raw_path if isinstance(raw_path, str) else ""
		role_name = role if isinstance(role, str) else ""
		normalized = normalize_portable_ownership_path(path)
		identity = portable_ownership_path_identity(path)
		prepared.append({
			"index": index,
			"raw_path": path,
			"path": normalized or path,
			"role": role_name,
			"identity_parts": tuple(identity.removeprefix("res://").split("/")) if identity else (),
			"valid": bool(
				normalized
				and not is_reserved_framework_resource_path(normalized)
				and role_name in ("scan_root", "test_fixture", "optional_input")
			),
		})
	for left_index, left in enumerate(prepared):
		left_parts = left["identity_parts"]
		if not left_parts:
			continue
		for right in prepared[left_index + 1:]:
			right_parts = right["identity_parts"]
			shorter = min(len(left_parts), len(right_parts))
			if shorter > 0 and left_parts[:shorter] == right_parts[:shorter]:
				conflicts.update((int(left["index"]), int(right["index"])))

	records: list[dict[str, Any]] = []
	states: list[PathRoleState] = []
	partial_count = 0
	unsafe_count = 0
	truncated = False
	traversal_budget = PathRoleTraversalBudget(
		remaining_entries=MAX_DEPENDENCY_FILES,
		remaining_bytes=MAX_DEPENDENCY_BYTES,
	)
	identity_groups: dict[tuple[str, str], dict[Path, tuple[int, int, int, int, int]]] = {}
	for declaration in prepared:
		path = str(declaration["path"])
		role = str(declaration["role"])
		record_status = "complete"
		exists = False
		covered_modules: list[str] = []
		role_identities: dict[Path, tuple[int, int, int, int, int]] = {}
		if not declaration["valid"] or int(declaration["index"]) in conflicts:
			record_status = "partial"
			unsafe_count += 1
			exists = _path_lexists(project_root, path)
		else:
			relative_path = path.removeprefix("res://")
			role_path = project_root / Path(*relative_path.split("/"))
			linked_path = project_path_has_link_component(project_root, relative_path)
			try:
				metadata = role_path.lstat()
			except FileNotFoundError:
				metadata = None
			except OSError:
				metadata = None
				record_status = "partial"
				unsafe_count += 1
			exists = metadata is not None
			if linked_path:
				record_status = "partial"
				unsafe_count += 1
			elif metadata is None:
				if role != "optional_input":
					record_status = "partial"
				else:
					parent_identity = _nearest_existing_parent_identity(project_root, role_path)
					if parent_identity is None:
						record_status = "partial"
						unsafe_count += 1
					else:
						role_identities = parent_identity
			elif _metadata_is_link_or_reparse(role_path, metadata):
				record_status = "partial"
				unsafe_count += 1
			elif role == "optional_input":
				if not stat.S_ISREG(metadata.st_mode) or not _safe_path(project_root, role_path, directory=False):
					record_status = "partial"
					unsafe_count += 1
				elif _stat_identity(metadata) != _path_identity(role_path):
					record_status = "partial"
					unsafe_count += 1
				else:
					role_identities[role_path] = _stat_identity(metadata)
			elif role == "scan_root":
				if not stat.S_ISDIR(metadata.st_mode) or not _safe_path(project_root, role_path, directory=True):
					record_status = "partial"
					unsafe_count += 1
				else:
					scan = _scan_path_role_tree(
						project_root,
						role_path,
						plan=plan,
						prove_ownership=True,
						budget=traversal_budget,
					)
					covered_modules = scan["covered_modules"]
					role_identities = scan["identities"]
					unsafe_count += int(scan["unsafe_count"])
					truncated = truncated or bool(scan["truncated"])
					if not scan["complete"]:
						record_status = "partial"
			else:
				if stat.S_ISREG(metadata.st_mode):
					if not _safe_path(project_root, role_path, directory=False):
						record_status = "partial"
						unsafe_count += 1
					else:
						role_identities[role_path] = _stat_identity(metadata)
				elif stat.S_ISDIR(metadata.st_mode) and _safe_path(project_root, role_path, directory=True):
					scan = _scan_path_role_tree(
						project_root,
						role_path,
						plan=plan,
						prove_ownership=False,
						budget=traversal_budget,
					)
					role_identities = scan["identities"]
					unsafe_count += int(scan["unsafe_count"])
					truncated = truncated or bool(scan["truncated"])
					if not scan["complete"]:
						record_status = "partial"
				else:
					record_status = "partial"
					unsafe_count += 1
		if record_status == "partial":
			partial_count += 1
		else:
			states.append(PathRoleState(
				path=path,
				role=role,
				status=record_status,
				covered_modules=tuple(sorted(covered_modules)),
			))
			identity_groups[(path, role)] = role_identities
		records.append({
			"path": path,
			"role": role,
			"status": record_status,
			"exists": exists,
			"covered_modules": sorted(covered_modules),
		})
	return {
		"records": sorted(records, key=lambda item: (item["path"], item["role"])),
		"states": tuple(sorted(states, key=lambda item: (item.path, item.role))),
		"partial_count": partial_count,
		"unsafe_count": unsafe_count,
		"truncated": truncated,
		"identity_groups": identity_groups,
	}


def _scan_path_role_tree(
	project_root: Path,
	root: Path,
	*,
	plan: TargetOwnershipPlan,
	prove_ownership: bool,
	budget: PathRoleTraversalBudget,
) -> dict[str, Any]:
	stack = [root]
	unsafe_count = 0
	truncated = False
	covered_modules: set[str] = set()
	identities: dict[Path, tuple[int, int, int, int, int]] = {}
	root_owner = plan.ownership_of(_resource_path(project_root, root))
	if root_owner is not None and root_owner.owner_id in plan.component_ids:
		covered_modules.add(root_owner.owner_id)
	if prove_ownership:
		root_resource = _resource_path(project_root, root)
		root_identity = portable_ownership_path_identity(root_resource)
		for ownership_root in plan.roots:
			ownership_identity = portable_ownership_path_identity(ownership_root.resource_root)
			if (
				root_identity
				and ownership_identity
				and (
					ownership_identity == root_identity
					or ownership_identity.startswith(root_identity + "/")
				)
			):
				covered_modules.add(ownership_root.owner_id)
	try:
		root_metadata = root.lstat()
		if (
			not stat.S_ISDIR(root_metadata.st_mode)
			or _metadata_is_link_or_reparse(root, root_metadata)
			or not _safe_path(project_root, root, directory=True)
		):
			raise OSError("unsafe path-role root")
		identities[root] = _stat_identity(root_metadata)
	except OSError:
		return {
			"complete": False,
			"truncated": False,
			"unsafe_count": 1,
			"covered_modules": sorted(covered_modules),
			"identities": identities,
		}
	while stack and not truncated:
		current = stack.pop()
		try:
			entry_names, current_identity, exhausted = _scandir_pinned_directory(
				current,
				budget,
			)
			if current_identity != identities.get(current):
				unsafe_count += 1
				continue
			if exhausted:
				truncated = True
				break
		except OSError:
			unsafe_count += 1
			continue
		for entry_name in entry_names:
			path = current / entry_name
			try:
				metadata = path.lstat()
			except OSError:
				unsafe_count += 1
				continue
			identities[path] = _stat_identity(metadata)
			if _metadata_is_link_or_reparse(path, metadata):
				unsafe_count += 1
				continue
			if prove_ownership:
				ownership = plan.ownership_of(_resource_path(project_root, path))
				if ownership is None:
					unsafe_count += 1
				else:
					if ownership.owner_id in plan.component_ids:
						covered_modules.add(ownership.owner_id)
			if stat.S_ISDIR(metadata.st_mode):
				stack.append(path)
			elif stat.S_ISREG(metadata.st_mode):
				file_size = int(metadata.st_size)
				if file_size > budget.remaining_bytes:
					budget.remaining_bytes = 0
					truncated = True
					break
				budget.remaining_bytes -= file_size
			else:
				unsafe_count += 1
	for path, identity in identities.items():
		if _path_identity(path) != identity:
			unsafe_count += 1
	return {
		"complete": not truncated and unsafe_count == 0,
		"truncated": truncated,
		"unsafe_count": unsafe_count,
		"covered_modules": sorted(covered_modules),
		"identities": identities,
	}


def _mark_late_path_role_drift(collection: dict[str, Any]) -> None:
	drifted: set[tuple[str, str]] = set()
	for key, identities in collection.get("identity_groups", {}).items():
		if any(_path_identity(path) != identity for path, identity in identities.items()):
			drifted.add(key)
	if not drifted:
		return
	newly_partial = 0
	for record in collection["records"]:
		key = (str(record["path"]), str(record["role"]))
		if key in drifted and record["status"] == "complete":
			record["status"] = "partial"
			newly_partial += 1
	collection["states"] = tuple(
		state
		for state in collection["states"]
		if (state.path, state.role) not in drifted
	)
	collection["partial_count"] += newly_partial
	collection["unsafe_count"] += len(drifted)


def _record_path_observation(
	edges: dict[tuple[str, str], dict[str, Any]],
	matcher: TargetOwnershipPlan,
	owned_resource_paths: set[str],
	path_roles: tuple[PathRoleState, ...],
	module_allowed_dependencies: dict[str, frozenset[str]],
	source_module: str,
	source_path: str,
	source_domain: str,
	raw_target_path: str,
	line: int,
	high_confidence_kind: str | None,
	unowned_references: list[dict[str, Any]],
	owned_resource_references: list[dict[str, Any]],
	path_role_references: list[dict[str, Any]],
	path_role_dependency_violations: list[dict[str, Any]],
	advisory_references: list[dict[str, Any]],
) -> tuple[int, int, int, int, int]:
	target_path = normalize_resource_path(raw_target_path)
	if not target_path:
		return 0, 0, 0, 0, 0
	if is_reserved_framework_resource_path(target_path):
		return 0, 0, 0, 0, 0
	target_ownership = matcher.ownership_of(target_path)
	if high_confidence_kind is not None:
		if target_ownership is not None:
			_add_reference(
				edges,
				source_module,
				target_ownership.owner_id,
				source_path,
				target_path,
				high_confidence_kind,
				raw_target_path,
				line,
			)
			return 0, 0, 0, 0, 0
		candidate = {
			"source_path": source_path,
			"target_path": target_path,
			"line": max(line, 1),
		}
		if target_path in owned_resource_paths:
			if (
				len(owned_resource_references) < MAX_OWNED_RESOURCE_REFERENCE_EVIDENCE
				and candidate not in owned_resource_references
			):
				owned_resource_references.append(candidate)
			return 0, 1, 0, 0, 0
		if len(unowned_references) < MAX_UNOWNED_REFERENCE_EVIDENCE and candidate not in unowned_references:
			unowned_references.append(candidate)
		return 1, 0, 0, 0, 0

	if target_ownership is not None and target_ownership.reference_kind == "generated_output":
		_add_reference(
			edges,
			source_module,
			target_ownership.owner_id,
			source_path,
			target_path,
			"generated_output",
			raw_target_path,
			line,
		)
		return 0, 0, 0, 0, 0

	path_role = _matching_path_role(path_roles, raw_target_path, source_domain)
	if path_role is not None:
		candidate_with_role = {
			"source_path": source_path,
			"target_path": target_path,
			"source_domain": source_domain,
			"role": path_role.role,
			"line": max(line, 1),
		}
		if (
			len(path_role_references) < MAX_PATH_ROLE_REFERENCE_EVIDENCE
			and candidate_with_role not in path_role_references
		):
			path_role_references.append(candidate_with_role)
		violation_count = 0
		if path_role.role == "scan_root":
			allowed_dependencies = module_allowed_dependencies.get(source_module, frozenset())
			for target_module in path_role.covered_modules:
				if target_module == source_module or target_module in allowed_dependencies:
					continue
				violation_count += 1
				violation = {
					"source_path": source_path,
					"source_module": source_module,
					"target_path": target_path,
					"target_module": target_module,
					"line": max(line, 1),
				}
				if (
					len(path_role_dependency_violations)
					< MAX_PATH_ROLE_DEPENDENCY_VIOLATION_EVIDENCE
					and violation not in path_role_dependency_violations
				):
					path_role_dependency_violations.append(violation)
		return 0, 0, 1, violation_count, 0

	if target_path in owned_resource_paths:
		owned_candidate = {
			"source_path": source_path,
			"target_path": target_path,
			"line": max(line, 1),
		}
		if (
			len(owned_resource_references) < MAX_OWNED_RESOURCE_REFERENCE_EVIDENCE
			and owned_candidate not in owned_resource_references
		):
			owned_resource_references.append(owned_candidate)
		return 0, 1, 0, 0, 0

	advisory_candidate = {
		"source_path": source_path,
		"target_path": target_path,
		"source_domain": source_domain,
		"line": max(line, 1),
	}
	if (
		len(advisory_references) < MAX_ADVISORY_REFERENCE_EVIDENCE
		and advisory_candidate not in advisory_references
	):
		advisory_references.append(advisory_candidate)
	return 0, 0, 0, 0, 1


def _matching_path_role(
	path_roles: tuple[PathRoleState, ...],
	target_path: str,
	source_domain: str,
) -> PathRoleState | None:
	target_identity = portable_ownership_path_identity(target_path)
	if not target_identity:
		return None
	for path_role in path_roles:
		role_identity = portable_ownership_path_identity(path_role.path)
		if not role_identity:
			continue
		if path_role.role in ("scan_root", "optional_input"):
			matches = target_identity == role_identity
		else:
			matches = (
				source_domain == "test"
				and (
					target_identity == role_identity
					or target_identity.startswith(role_identity + "/")
				)
			)
		if matches:
			return path_role
	return None


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
		source_module = str(edge["source_module"])
		target_module = str(edge["target_module"])
		if source_module in module_ids and target_module in module_ids:
			graph[source_module].add(target_module)
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


def _contract_adapters(contract_data: dict[str, Any]) -> list[dict[str, Any]]:
	framework = contract_data.get("framework", {})
	if not isinstance(framework, dict) or not isinstance(framework.get("adapter_boundaries"), list):
		return []
	return [adapter for adapter in framework["adapter_boundaries"] if isinstance(adapter, dict)]


def _contract_owned_resources(contract_data: dict[str, Any]) -> list[str]:
	architecture = contract_data.get("architecture", {})
	if not isinstance(architecture, dict) or not isinstance(architecture.get("owned_resources"), list):
		return []
	return [path for path in architecture["owned_resources"] if isinstance(path, str)]


def _contract_path_roles(contract_data: dict[str, Any]) -> list[dict[str, Any]]:
	architecture = contract_data.get("architecture", {})
	if not isinstance(architecture, dict) or not isinstance(architecture.get("path_roles"), list):
		return []
	return [path_role for path_role in architecture["path_roles"] if isinstance(path_role, dict)]


def _portable_root_parts(resource_root: str) -> tuple[str, ...]:
	identity = portable_ownership_path_identity(resource_root)
	if not identity:
		return ()
	return tuple(identity.removeprefix("res://").split("/"))


def _empty_analysis(
	status: str,
	modules: list[dict[str, Any]],
	*,
	complete: bool,
	owned_resource_collection: dict[str, Any] | None = None,
) -> dict[str, Any]:
	resources = owned_resource_collection or {
		"records": [],
		"missing_count": 0,
		"unsafe_count": 0,
	}
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
		"declared_owned_resource_count": len(resources["records"]),
		"missing_owned_resource_count": int(resources["missing_count"]),
		"unsafe_owned_resource_count": int(resources["unsafe_count"]),
		"owned_resources": resources["records"],
		"owned_resource_reference_count": 0,
		"owned_resource_references_truncated": False,
		"owned_resource_references": [],
		"declared_path_role_count": 0,
		"partial_path_role_count": 0,
		"path_roles": [],
		"path_role_reference_count": 0,
		"path_role_references_truncated": False,
		"path_role_references": [],
		"path_role_dependency_violation_count": 0,
		"path_role_dependency_violations_truncated": False,
		"path_role_dependency_violations": [],
		"advisory_reference_count": 0,
		"advisory_references_truncated": False,
		"advisory_references": [],
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


def _resource_path(project_root: Path, path: Path) -> str:
	return "res://" + path.relative_to(project_root).as_posix()


def _read_pinned_utf8(
	path: Path,
	*,
	expected_identity: tuple[int, int, int, int, int] | None = None,
) -> PinnedSource | None:
	try:
		before = path.lstat()
		if _metadata_is_link_or_reparse(path, before) or not stat.S_ISREG(before.st_mode):
			return None
		before_identity = _stat_identity(before)
		if expected_identity is not None and before_identity != expected_identity:
			return None
		read_limit = int(expected_identity[3]) if expected_identity is not None else MAX_DEPENDENCY_FILE_BYTES
		if before.st_size > MAX_DEPENDENCY_FILE_BYTES or read_limit > MAX_DEPENDENCY_FILE_BYTES:
			return None
		with path.open("rb") as stream:
			opened_before = os.fstat(stream.fileno())
			raw = stream.read(read_limit + 1)
			opened_after = os.fstat(stream.fileno())
		after = path.lstat()
		identity = _stat_identity(after)
		if not (
			before_identity == _stat_identity(opened_before)
			and _stat_identity(opened_before) == _stat_identity(opened_after)
			and _stat_identity(opened_after) == identity
			and (expected_identity is None or identity == expected_identity)
			and len(raw) == int(after.st_size)
			and len(raw) <= MAX_DEPENDENCY_FILE_BYTES
		):
			return None
		return PinnedSource(raw.decode("utf-8", errors="strict"), identity)
	except (OSError, UnicodeDecodeError, ValueError):
		return None


def _pinned_source_still_matches(path: Path, source: PinnedSource) -> bool:
	return _path_identity(path) == source.identity


def _source_domain(path: Path, project_root: Path) -> str:
	try:
		relative = path.relative_to(project_root)
	except ValueError:
		return "project"
	if (
		any(part.casefold() in ("test", "tests") for part in relative.parts)
		or path.name.casefold().startswith("test_")
	):
		return "test"
	return "project"


def _path_lexists(project_root: Path, raw_path: str) -> bool:
	normalized = normalize_resource_path(raw_path)
	if not normalized:
		return False
	relative = normalized.removeprefix("res://")
	path = project_root / Path(*relative.split("/"))
	try:
		path.lstat()
	except OSError:
		return False
	return True


def _nearest_existing_parent_identity(
	project_root: Path,
	path: Path,
) -> dict[Path, tuple[int, int, int, int, int]] | None:
	root = project_root.absolute()
	current = path.parent.absolute()
	while True:
		try:
			current.relative_to(root)
		except ValueError:
			return None
		try:
			metadata = current.lstat()
		except FileNotFoundError:
			if current == root:
				return None
			current = current.parent
			continue
		except OSError:
			return None
		if not stat.S_ISDIR(metadata.st_mode) or _metadata_is_link_or_reparse(current, metadata):
			return None
		return {current: _stat_identity(metadata)}


def _scandir_pinned_directory(
	path: Path,
	budget: PathRoleTraversalBudget,
) -> tuple[list[str], tuple[int, int, int, int, int], bool]:
	if budget.remaining_entries <= 0:
		return [], _required_directory_identity(path), True
	before = path.lstat()
	if not stat.S_ISDIR(before.st_mode) or _metadata_is_link_or_reparse(path, before):
		raise OSError("unsafe directory")
	identity = _stat_identity(before)
	names: list[str] = []
	exhausted = False
	if os.name == "nt":
		handle = _open_windows_pinned_directory(path)
		try:
			if _required_directory_identity(path) != identity:
				raise OSError("directory changed before traversal")
			with os.scandir(path) as iterator:
				for entry in iterator:
					if budget.remaining_entries <= 0:
						exhausted = True
						break
					budget.remaining_entries -= 1
					names.append(entry.name)
		finally:
			_close_windows_handle(handle)
	else:
		flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
		descriptor = os.open(path, flags)
		try:
			if _stat_identity(os.fstat(descriptor)) != identity:
				raise OSError("directory changed before traversal")
			with os.scandir(descriptor) as iterator:
				for entry in iterator:
					if budget.remaining_entries <= 0:
						exhausted = True
						break
					budget.remaining_entries -= 1
					names.append(entry.name)
		finally:
			os.close(descriptor)
	if _required_directory_identity(path) != identity:
		raise OSError("directory changed during traversal")
	names.sort()
	return names, identity, exhausted


def _required_directory_identity(path: Path) -> tuple[int, int, int, int, int]:
	metadata = path.lstat()
	if not stat.S_ISDIR(metadata.st_mode) or _metadata_is_link_or_reparse(path, metadata):
		raise OSError("unsafe directory")
	return _stat_identity(metadata)


def _open_windows_pinned_directory(path: Path) -> int:
	import ctypes
	from ctypes import wintypes

	kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
	kernel32.CreateFileW.argtypes = [
		wintypes.LPCWSTR,
		wintypes.DWORD,
		wintypes.DWORD,
		wintypes.LPVOID,
		wintypes.DWORD,
		wintypes.DWORD,
		wintypes.HANDLE,
	]
	kernel32.CreateFileW.restype = wintypes.HANDLE
	handle = kernel32.CreateFileW(
		str(path),
		0x0001,
		0x00000001 | 0x00000002,
		None,
		3,
		0x02000000 | 0x00200000,
		None,
	)
	invalid_handle = ctypes.c_void_p(-1).value
	if handle == invalid_handle:
		raise OSError(ctypes.get_last_error(), "unable to pin directory")
	return int(handle)


def _close_windows_handle(handle: int) -> None:
	import ctypes

	kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
	if not kernel32.CloseHandle(ctypes.c_void_p(handle)):
		raise OSError(ctypes.get_last_error(), "unable to close pinned directory")


def _metadata_is_link_or_reparse(path: Path, metadata: os.stat_result) -> bool:
	if stat.S_ISLNK(metadata.st_mode) or path.is_symlink():
		return True
	reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
	return bool(reparse_flag and getattr(metadata, "st_file_attributes", 0) & reparse_flag)


def _stat_identity(metadata: os.stat_result) -> tuple[int, int, int, int, int]:
	return (
		int(stat.S_IFMT(metadata.st_mode)),
		int(metadata.st_dev),
		int(metadata.st_ino),
		int(metadata.st_size),
		int(getattr(metadata, "st_mtime_ns", int(metadata.st_mtime * 1_000_000_000))),
	)


def _path_identity(path: Path) -> tuple[int, int, int, int, int] | None:
	try:
		return _stat_identity(path.lstat())
	except OSError:
		return None


def _safe_path(project_root: Path, path: Path, *, directory: bool) -> bool:
	try:
		lexical_root = project_root.absolute()
		lexical_path = path.absolute()
		relative_path = lexical_path.relative_to(lexical_root)
		if project_path_has_link_component(project_root, relative_path.as_posix()):
			return False
		current_path = lexical_root / relative_path
		current_path.resolve(strict=True).relative_to(lexical_root.resolve(strict=True))
		return current_path.is_dir() if directory else current_path.is_file()
	except (OSError, ValueError):
		return False
