"""统一解释内部模块描述符中的源码归属、路径和模块种类。"""
from __future__ import annotations

import json
import re
from collections.abc import Callable
from pathlib import Path
from typing import Any

import gf_path_security
from gf_package_paths import (
	ManifestPathIndex, normalize_manifest_path, path_matches_any_manifest_path, portable_manifest_path_identity,
)

SCHEMA_VERSION = 1
MAX_BYTES = 1024 * 1024
MAX_DEPTH = 32
MAX_NODES = 4096
KINDS = {"kernel", "standard", "extension", "tool"}
ALLOWED_FIELDS = {"schema_version", "id", "kind", "dependencies", "paths", "exclude_paths", "gf_extension_id"}
RETIRED_FIELDS = {
	"archive", "checksum", "download", "download_url", "download_urls", "downloads", "install_script",
	"install_url", "installer", "installer_paths", "installers", "npm", "registry", "repository",
	"sha256", "size_bytes", "public_key", "public_keys", "registry_signature",
	"registry_signature_algorithm", "registry_signature_sha256", "registry_signature_size_bytes",
	"registry_signature_url", "registry_signing_key_id", "signature", "signature_algorithm",
	"signature_public_key", "signature_sha256", "signature_url", "signing_key", "signing_key_id", "signing_keys",
}
MODULE_ID = re.compile(r"gf\.(?:kernel|(?:standard|extension|tool)(?:\.[a-z0-9_]+)+)")


def expected_package_kind_from_id(identifier: str) -> str:
	"""按模块 ID 识别预期种类，不能映射时返回空串。"""
	if identifier == "gf.kernel":
		return "kernel"
	for kind in ("standard", "extension", "tool", "preset"):
		if identifier.startswith(f"gf.{kind}."):
			return kind
	return ""


def issue(kind: str, path: str, message: str, **details: Any) -> dict[str, Any]:
	result = {"kind": kind, "path": path, "message": message, "severity": "error"}
	result.update({key: value for key, value in details.items() if value not in ("", None)})
	return result


def _empty_record(path: str) -> dict[str, Any]:
	return {
		"path": path, "id": "", "kind": "", "gf_extension_id": "",
		"dependencies": [], "paths": [], "exclude_paths": [],
	}


def structure_issues(data: Any, path: str) -> list[dict[str, Any]]:
	stack = [(data, 1)]
	count = 0
	while stack:
		value, depth = stack.pop()
		count += 1
		if depth > MAX_DEPTH:
			return [issue("package_manifest_nesting_too_deep", path, "Module descriptor is too deeply nested.",
						  expected_value=f"<= {MAX_DEPTH}", actual_value=depth)]
		if count > MAX_NODES:
			return [issue("package_manifest_node_budget_exceeded", path, "Too many JSON values in module descriptor.",
						  expected_value=f"<= {MAX_NODES}", actual_value=count)]
		if isinstance(value, dict):
			stack.extend((child, depth + 1) for child in value.values())
		elif isinstance(value, list):
			stack.extend((child, depth + 1) for child in value)
	return []


def descriptor_fields(
	data: dict[str, Any], path: str, *, path_exists: Callable[[str], bool] | None = None,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
	"""校验并返回各调用方共用的描述符字段，字段解释独立于文件发现方式。"""
	record = _empty_record(path)
	issues = structure_issues(data, path)
	if issues:
		return record, issues
	for key in sorted(data.keys() - ALLOWED_FIELDS):
		code = "forbidden_package_manifest_field" if key in RETIRED_FIELDS else "unsupported_package_manifest_field"
		issues.append(issue(code, path, f"unsupported module descriptor field: {key}.", field=key))
	version = data.get("schema_version")
	if type(version) is not int or version != SCHEMA_VERSION:
		issues.append(issue("invalid_package_schema_version", path, f"schema_version must be {SCHEMA_VERSION}.",
							field="schema_version", expected_value=SCHEMA_VERSION, actual_value=data.get("schema_version")))
	for key in ("id", "kind", "gf_extension_id"):
		value = data.get(key, "")
		if isinstance(value, str) and value == value.strip():
			record[key] = value
		else:
			issues.append(issue(f"invalid_package_{key}", path, f"{key} must be a canonical string.", field=key))
	identifier, kind = record["id"], record["kind"]
	if not identifier:
		issues.append(issue("missing_package_id", path, "Package id is required.", field="id"))
	elif not MODULE_ID.fullmatch(identifier):
		issues.append(issue("invalid_package_id", path, "Unsupported module id.", field="id", actual_value=identifier))
	if kind not in KINDS:
		issues.append(issue("invalid_package_kind", path, "Unsupported module kind.", field="kind", actual_value=kind))
	elif identifier and expected_package_kind_from_id(identifier) != kind:
		issues.append(issue("package_id_kind_mismatch", path, "Module id and kind disagree.", field="kind",
							expected_value=expected_package_kind_from_id(identifier), actual_value=kind))
	if kind == "extension" and not record["gf_extension_id"]:
		issues.append(issue("extension_package_missing_gf_extension_id", path, "Extension id is required.", field="gf_extension_id"))
	elif kind != "extension" and "gf_extension_id" in data:
		issues.append(issue("non_extension_gf_extension_id", path, "Only extensions may declare gf_extension_id.", field="gf_extension_id"))
	for field in ("dependencies", "paths", "exclude_paths"):
		values = data.get(field, [] if field == "exclude_paths" else None)
		items, errors = array_field(values, path, field, path_exists=path_exists)
		record[field] = items
		issues.extend(errors)
	if not record["paths"]:
		issues.append(issue("package_manifest_missing_paths", path, "A module must own at least one path.", field="paths"))
	return record, issues


def array_field(
	values: Any, path: str, field: str, *, path_exists: Callable[[str], bool] | None = None,
) -> tuple[list[str], list[dict[str, Any]]]:
	"""校验描述符的数组字段并返回值与问题，可选用调用方提供的路径存在性检查。"""
	if not isinstance(values, list):
		return [], [issue(f"invalid_package_{field}", path, f"{field} must be an array.", field=field)]
	items: list[str] = []
	issues = []
	seen: set[str] = set()
	for index, value in enumerate(values):
		if not isinstance(value, str) or not value or value != value.strip():
			issues.append(issue(f"invalid_package_{field}", path, f"{field} requires canonical strings.", field=field, row_index=index))
			continue
		identity = value
		if field != "dependencies":
			prefix = "package_exclude_path" if field == "exclude_paths" else "package_path"
			identity = portable_manifest_path_identity(value)
			if not identity:
				issues.append(issue(f"invalid_{prefix}", path, f"Unsafe or non-portable path: {value}.",
									field=field, row_index=index, actual_value=value))
				continue
			if value != "addons/gf" and not value.startswith("addons/gf/"):
				issues.append(issue(f"{prefix}_outside_addons_gf", path, "Owned paths must be under addons/gf.",
									field=field, row_index=index, actual_value=value))
				continue
			if path_exists is not None and not path_exists(value):
				issues.append(issue(f"{prefix}_missing", path, "Module path anchor does not exist in the source tree.",
									field=field, row_index=index, actual_value=value))
		if identity in seen:
			issues.append(issue(f"duplicate_package_{field}", path, f"Duplicate {field} entry: {value}.",
								field=field, row_index=index, actual_value=value))
			continue
		seen.add(identity)
		items.append(value)
	return items, issues


def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
	result = {}
	for key, value in pairs:
		if key in result:
			raise ValueError(f"Duplicate key: {key}")
		result[key] = value
	return result


def _reject_constant(value: str) -> Any:
	raise ValueError(f"Non-finite JSON number: {value}")


def read_descriptor(
	root: Path, path: str, *, path_exists: Callable[[str], bool] | None = None,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
	"""读取相对仓库根的描述文件并返回记录及问题，读取失败也保留可定位的路径。"""
	try:
		source = gf_path_security.read_pinned_utf8_regular_file(root, path, max_bytes=MAX_BYTES)
		data = json.loads(source, object_pairs_hook=_unique_object, parse_constant=_reject_constant)
	except gf_path_security.PinnedReadError as error:
		if error.rule_id == "path_security.file_too_large":
			problem = issue("package_manifest_too_large", path, "Module descriptor exceeds its byte limit.", expected_value=f"<= {MAX_BYTES}")
		else:
			problem = issue("invalid_package_manifest_json", path, f"Cannot read stable module descriptor: {error.rule_id}.")
	except RecursionError:
		problem = issue("package_manifest_nesting_too_deep", path, "Module descriptor is too deeply nested.", expected_value=f"<= {MAX_DEPTH}")
	except ValueError as error:
		problem = issue("invalid_package_manifest_json", path, f"invalid module descriptor JSON: {error}")
	else:
		if isinstance(data, dict):
			return descriptor_fields(data, path, path_exists=path_exists)
		problem = issue("invalid_package_manifest", path, "Module descriptor root must be a JSON object.",
						expected_value="object", actual_value=type(data).__name__)
	return _empty_record(path), [problem]


def normalize_package_manifest_path(path: str) -> str:
	"""规范化清单中的相对路径，对不受支持的路径形式返回空串。"""
	normalized = normalize_manifest_path(path)
	parts = [part for part in normalized.split("/") if part not in ("", ".")]
	return "" if ":" in normalized or ".." in parts else "/".join(parts)


def exact_source_path(root: Path, relative: str) -> Path | None:
	"""按路径的每一段核实实际目录项拼写，在 Windows 上也保留此约束。"""
	if not portable_manifest_path_identity(relative) or "*" in relative or "?" in relative:
		return None
	current = root
	for part in relative.split("/"):
		if gf_path_security.path_has_reparse_component(current) or not current.is_dir():
			return None
		match = next((child for child in current.iterdir() if child.name == part), None)
		if match is None:
			return None
		current = match
	return current


def collect_package_source_owner_entries(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
	"""整理源码归属模式，并按模式长度降序排列。"""
	entries = []
	for record in records:
		if not record.get("id") or record.get("kind") == "preset":
			continue
		exclusions = [path for path in record.get("exclude_paths", []) if portable_manifest_path_identity(path)]
		for pattern in record.get("paths", []):
			if portable_manifest_path_identity(pattern):
				entries.append({
					"package_id": record["id"], "manifest_path": record.get("path", ""),
					"owned_path": pattern, "pattern": pattern, "exclude_paths": exclusions,
				})
	return sorted(entries, key=lambda entry: len(entry["pattern"]), reverse=True)


class PackageOwnershipIndex(ManifestPathIndex):
	"""按包含和排除规则解析给定路径的归属，判定不依赖文件发现顺序。"""

	def __init__(self, owner_entries: list[dict[str, Any]]) -> None:
		super().__init__(owner_entries, path_normalizer=normalize_package_manifest_path)

	def find_owners(self, path: str) -> list[dict[str, Any]]:
		candidate = normalize_package_manifest_path(path)
		by_module = {}
		for entry in self.find_all(candidate):
			if not path_matches_any_manifest_path(candidate, entry.get("exclude_paths", [])):
				by_module.setdefault(entry["package_id"], entry)
		return list(by_module.values())

	def find_owner(self, path: str) -> dict[str, Any] | None:
		"""返回唯一匹配的模块，缺失或歧义时返回 None。"""
		matches = self.find_owners(path)
		return matches[0] if len(matches) == 1 else None
