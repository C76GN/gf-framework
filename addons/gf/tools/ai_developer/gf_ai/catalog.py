"""Versioned GF capability, recipe, package, and API catalog queries."""

from __future__ import annotations

import configparser
import re
from functools import lru_cache
from pathlib import Path
from typing import Any

from .constants import KNOWLEDGE_ROOT, SCHEMA_ROOT
from .paths import (
	canonical_json_bytes,
	normalize_portable_ownership_path,
	portable_ownership_path_identity,
	read_bounded_text,
	read_json_object,
	resolve_project_path,
	sha256_bytes,
)
from .schema import validate_schema_file


_CAMEL_ACRONYM_BOUNDARY = re.compile(r"(?<=[A-Z])(?=[A-Z][a-z])")
_CAMEL_WORD_BOUNDARY = re.compile(r"(?<=[a-z0-9])(?=[A-Z])")
_SEARCH_SEPARATOR = re.compile(r"[\W_]+", re.UNICODE)
_SEARCH_STOP_WORDS = frozenset({
	"a", "an", "and", "as", "at", "before", "between", "by", "each", "for",
	"from", "in", "into", "of", "on", "or", "over", "the", "through", "to",
	"with",
})
_PRIMARY_CLASS_PARTIAL_SCORE_LIMIT = 20
_PLUGIN_CONFIG_MAX_BYTES = 256 * 1024
_LOCKFILE_REQUIRED_FIELDS = frozenset({"schema_version", "framework_version", "installed"})
_LOCKFILE_ALLOWED_FIELDS = _LOCKFILE_REQUIRED_FIELDS | {"registry_source"}
_LOCK_ENTRY_REQUIRED_FIELDS = frozenset({
	"version",
	"kind",
	"reason",
	"required_by",
	"paths",
	"archive",
	"sha256",
	"files",
	"file_metadata",
})
_LOCK_ENTRY_ALLOWED_FIELDS = _LOCK_ENTRY_REQUIRED_FIELDS | {"gf_extension_id"}
_LOCKFILE_REGISTRY_SOURCE_ALLOWED_FIELDS = frozenset({
	"source",
	"source_manifest",
	"channel",
	"offline_bundle",
	"registry_sha256",
	"remote",
	"mirror_index",
	"registry_size_bytes",
})
_LOCK_ENTRY_REASONS = frozenset({"manual", "dependency", "preset", "bundled", "dev"})
API_INDEX_CATALOG_VERSION = "2.0.0"


def load_api_index() -> dict[str, Any]:
	return _load_knowledge(KNOWLEDGE_ROOT / "api_index.json", validate_api_index=True)


def load_capabilities() -> dict[str, Any]:
	return _load_catalogs()[0]


def load_recipes() -> dict[str, Any]:
	return _load_catalogs()[1]


def _load_catalogs() -> tuple[dict[str, Any], dict[str, Any]]:
	capabilities = _load_knowledge(
		KNOWLEDGE_ROOT / "capabilities.json",
		SCHEMA_ROOT / "capability_catalog.schema.json",
	)
	recipes = _load_knowledge(
		KNOWLEDGE_ROOT / "recipes.json",
		SCHEMA_ROOT / "recipe_catalog.schema.json",
	)
	issues = [
		*_catalog_record_id_issues(capabilities, "capabilities"),
		*_catalog_record_id_issues(recipes, "recipes"),
		*catalog_reference_issues(load_api_index(), capabilities, recipes),
	]
	if issues:
		raise ValueError("GF AI knowledge validation failed: " + "; ".join(issues[:20]))
	return capabilities, recipes


def api_search(query: str, limit: int = 20, project_root: Path | None = None) -> dict[str, Any]:
	compatibility = catalog_compatibility(project_root)
	if not compatibility["ok"]:
		return {"ok": False, "query": query, "results": [], "compatibility": compatibility, "issues": compatibility["issues"]}
	if not _limit_is_valid(limit, 80):
		return {"ok": False, "query": query, "results": [], "issues": ["limit must be an integer from 1 through 80"]}
	query_issue = _text_query_issue(query, "query", 500)
	if query_issue:
		return {"ok": False, "query": query, "results": [], "issues": [query_issue]}
	needle = _normalize_search_text(query)
	index = load_api_index()
	results: list[dict[str, Any]] = []
	for owner_name, record in _api_owner_records(index).items():
		if not isinstance(record, dict):
			continue
		owner_score = _text_score(
			needle,
			owner_name,
			str(record.get("summary", "")),
			str(record.get("module", "")),
		)
		member_matches: list[dict[str, Any]] = []
		for member in record.get("members", []):
			if not isinstance(member, dict):
				continue
			member_score = _text_score(
				needle,
				str(member.get("name", "")),
				str(member.get("signature", "")),
				str(member.get("summary", "")),
			)
			if member_score > 0:
				member_matches.append({**member, "score": member_score})
		member_matches.sort(key=lambda item: (-int(item["score"]), str(item.get("name", ""))))
		score = max(owner_score, int(member_matches[0]["score"]) if member_matches else 0)
		if score <= 0:
			continue
		owner_kind = str(record.get("owner_kind", ""))
		results.append({
			"score": score,
			"owner_kind": owner_kind,
			"owner_name": owner_name,
			"class_name": owner_name if owner_kind == "class" else "",
			"extends": record.get("extends", ""),
			"module": record.get("module", ""),
			"package_id": record.get("package_id", ""),
			"path": record.get("path", ""),
			"summary": record.get("summary", ""),
			"member_matches": member_matches[:8],
		})
	results.sort(key=lambda item: (-int(item["score"]), str(item["owner_name"])))
	return {
		"ok": True,
		"query": query,
		"source_digest": index.get("source_digest", ""),
		"results": results[:limit],
		"issues": [],
	}


def api_class(
	class_name: str,
	include_members: bool = True,
	project_root: Path | None = None,
) -> dict[str, Any]:
	compatibility = catalog_compatibility(project_root)
	if not compatibility["ok"]:
		return {"ok": False, "class_name": class_name, "compatibility": compatibility, "issues": compatibility["issues"]}
	query_issue = _text_query_issue(class_name, "class_name", 200)
	if query_issue:
		return {"ok": False, "class_name": class_name, "issues": [query_issue]}
	needle = class_name.strip().casefold()
	classes = _class_records(load_api_index())
	for candidate, record in classes.items():
		if candidate.casefold() != needle or not isinstance(record, dict):
			continue
		result = {"ok": True, "class_name": candidate, **record, "issues": []}
		if not include_members:
			result.pop("members", None)
		return result
	return {"ok": False, "class_name": class_name, "issues": ["GF API class was not found"]}


def api_module(
	module_name: str,
	limit: int = 100,
	project_root: Path | None = None,
) -> dict[str, Any]:
	compatibility = catalog_compatibility(project_root)
	if not compatibility["ok"]:
		return {"ok": False, "module": module_name, "classes": [], "compatibility": compatibility, "issues": compatibility["issues"]}
	if not _limit_is_valid(limit, 200):
		return {"ok": False, "module": module_name, "classes": [], "issues": ["limit must be an integer from 1 through 200"]}
	query_issue = _text_query_issue(module_name, "module_name", 240)
	if query_issue:
		return {"ok": False, "module": module_name, "classes": [], "issues": [query_issue]}
	needle = module_name.strip().casefold()
	classes = _class_records(load_api_index())
	modules = sorted({str(record.get("module", "")) for record in classes.values() if isinstance(record, dict) and record.get("module")})
	exact = next((module for module in modules if module.casefold() == needle), "")
	if not exact:
		suggestions = [module for module in modules if needle in module.casefold()][:20]
		return {
			"ok": False,
			"module": module_name,
			"classes": [],
			"suggestions": suggestions,
			"issues": ["GF API module was not found"],
		}
	records = [
		{
			"class_name": class_name,
			"extends": record.get("extends", ""),
			"package_id": record.get("package_id", ""),
			"path": record.get("path", ""),
			"summary": record.get("summary", ""),
			"visibility": record.get("visibility", ""),
		}
		for class_name, record in classes.items()
		if isinstance(record, dict) and record.get("module") == exact
	]
	records.sort(key=lambda item: str(item["class_name"]))
	return {
		"ok": True,
		"module": exact,
		"class_count": len(records),
		"truncated": len(records) > limit,
		"classes": records[:limit],
		"issues": [],
	}


def package_by_id(
	package_id: str,
	limit: int = 100,
	project_root: Path | None = None,
) -> dict[str, Any]:
	compatibility = catalog_compatibility(project_root)
	if not compatibility["ok"]:
		return {"ok": False, "id": package_id, "compatibility": compatibility, "issues": compatibility["issues"]}
	if not _limit_is_valid(limit, 200):
		return {"ok": False, "id": package_id, "issues": ["limit must be an integer from 1 through 200"]}
	query_issue = _text_query_issue(package_id, "package_id", 160)
	if query_issue:
		return {"ok": False, "id": package_id, "issues": [query_issue]}
	index = load_api_index()
	package = next(
		(item for item in index.get("packages", []) if isinstance(item, dict) and item.get("id") == package_id),
		None,
	)
	if package is None:
		return {"ok": False, "id": package_id, "issues": ["GF package was not found"]}
	class_names = sorted(
		class_name
		for class_name, record in _class_records(index).items()
		if isinstance(record, dict) and record.get("package_id") == package_id
	)
	installed = None
	package_state: dict[str, Any] = {}
	if project_root is not None:
		package_report = installed_package_report(project_root)
		installed = package_id in package_report["packages"]
		package_state = {
			"source": package_report["source"],
			"lockfile_present": package_report["lockfile_present"],
			"valid": package_report["valid"],
			"issues": package_report["issues"],
		}
	return {
		"ok": True,
		**package,
		"installed": installed,
		"class_count": len(class_names),
		"truncated": len(class_names) > limit,
		"classes": class_names[:limit],
		"package_state": package_state,
		"issues": [],
	}


def capability_search(query: str, limit: int = 10, project_root: Path | None = None) -> dict[str, Any]:
	compatibility = catalog_compatibility(project_root)
	if not compatibility["ok"]:
		return {"ok": False, "query": query, "results": [], "compatibility": compatibility, "issues": compatibility["issues"]}
	if not _limit_is_valid(limit, 30):
		return {"ok": False, "query": query, "results": [], "issues": ["limit must be an integer from 1 through 30"]}
	query_issue = _text_query_issue(query, "query", 500)
	if query_issue:
		return {"ok": False, "query": query, "results": [], "issues": [query_issue]}
	needle = _normalize_search_text(query)
	data = load_capabilities()
	results: list[dict[str, Any]] = []
	for capability in data.get("capabilities", []):
		if not isinstance(capability, dict):
			continue
		keywords = [
			str(item)
			for item in capability.get("keywords", [])
			if isinstance(item, str)
		]
		search_values = [
			str(capability.get("id", "")),
			str(capability.get("title", "")),
			str(capability.get("summary", "")),
			*keywords,
		]
		semantic_score = max(
			_text_score(needle, *search_values, allow_partial=True),
			_text_score(needle, " ".join(search_values), allow_partial=True),
		)
		primary_classes = [
			str(item)
			for item in capability.get("primary_classes", [])
			if isinstance(item, str)
		]
		class_score = _primary_class_score(needle, primary_classes)
		score = max(semantic_score, class_score)
		if score > 0:
			results.append({**capability, "score": score})
	results.sort(key=lambda item: (-int(item["score"]), str(item.get("id", ""))))
	return {
		"ok": True,
		"query": query,
		"catalog_version": data.get("catalog_version", ""),
		"results": results[:limit],
		"issues": [],
	}


def capability_by_id(capability_id: str, project_root: Path | None = None) -> dict[str, Any]:
	compatibility = catalog_compatibility(project_root)
	if not compatibility["ok"]:
		return {"ok": False, "id": capability_id, "compatibility": compatibility, "issues": compatibility["issues"]}
	query_issue = _text_query_issue(capability_id, "capability_id", 160)
	if query_issue:
		return {"ok": False, "id": capability_id, "issues": [query_issue]}
	for capability in load_capabilities().get("capabilities", []):
		if isinstance(capability, dict) and capability.get("id") == capability_id:
			return {"ok": True, **capability, "issues": []}
	return {"ok": False, "id": capability_id, "issues": ["GF capability was not found"]}


def recipe_by_id(recipe_id: str, project_root: Path | None = None) -> dict[str, Any]:
	compatibility = catalog_compatibility(project_root)
	if not compatibility["ok"]:
		return {"ok": False, "id": recipe_id, "compatibility": compatibility, "issues": compatibility["issues"]}
	query_issue = _text_query_issue(recipe_id, "recipe_id", 160)
	if query_issue:
		return {"ok": False, "id": recipe_id, "issues": [query_issue]}
	for recipe in load_recipes().get("recipes", []):
		if isinstance(recipe, dict) and recipe.get("id") == recipe_id:
			return {"ok": True, **recipe, "issues": []}
	return {"ok": False, "id": recipe_id, "issues": ["GF recipe was not found"]}


def known_capability_ids() -> set[str]:
	return {
		str(item.get("id"))
		for item in load_capabilities().get("capabilities", [])
		if isinstance(item, dict) and item.get("id")
	}


def capability_records_by_id() -> dict[str, dict[str, Any]]:
	return {
		str(item.get("id")): item
		for item in load_capabilities().get("capabilities", [])
		if isinstance(item, dict) and item.get("id")
	}


def recipe_records_by_id() -> dict[str, dict[str, Any]]:
	return {
		str(item.get("id")): item
		for item in load_recipes().get("recipes", [])
		if isinstance(item, dict) and item.get("id")
	}


def known_recipe_ids() -> set[str]:
	return set(recipe_records_by_id())


def known_package_ids() -> set[str]:
	return {
		str(item.get("id"))
		for item in load_api_index().get("packages", [])
		if isinstance(item, dict) and item.get("id")
	}


def known_api_classes() -> set[str]:
	return set(_class_records(load_api_index()))


def api_index_issues(api_index: dict[str, Any]) -> list[str]:
	"""Return all closed API-index validation issues without raising."""
	return _api_index_issues(api_index)


def catalog_reference_issues(
	api_index: dict[str, Any],
	capabilities: dict[str, Any],
	recipes: dict[str, Any],
) -> list[str]:
	"""Validate catalog references against API class and package ownership."""
	issues: list[str] = []
	classes = _class_records(api_index)
	package_records = {
		str(item.get("id", "")): item
		for item in api_index.get("packages", [])
		if isinstance(item, dict) and item.get("id")
	}
	recipe_records = {
		str(item.get("id", "")): item
		for item in recipes.get("recipes", [])
		if isinstance(item, dict) and item.get("id")
	}
	capability_version = str(capabilities.get("catalog_version", ""))
	recipe_version = str(recipes.get("catalog_version", ""))
	if capability_version != recipe_version:
		issues.append(
			"Capability catalog_version must match Recipe catalog_version: "
			f"{capability_version} != {recipe_version}."
		)

	for capability in capabilities.get("capabilities", []):
		if not isinstance(capability, dict):
			continue
		capability_id = str(capability.get("id", ""))
		declared_packages = _string_items(capability.get("packages"))
		for package_id in sorted(declared_packages - set(package_records)):
			issues.append(f"Capability {capability_id} references an unknown package: {package_id}.")
		provided_packages = _package_record_dependency_closure(
			declared_packages,
			package_records,
		)
		for class_name in sorted(_string_items(capability.get("primary_classes"))):
			record = classes.get(class_name)
			if not isinstance(record, dict):
				issues.append(f"Capability {capability_id} references an unknown class: {class_name}.")
				continue
			owner_package = str(record.get("package_id", ""))
			if owner_package not in provided_packages:
				issues.append(
					f"Capability {capability_id} primary class {class_name} is owned by "
					f"{owner_package}, which is not provided by the declared package dependency closure."
				)
		issues.extend(_required_api_member_issues(
			f"Capability {capability_id}",
			capability,
			classes,
			provided_packages,
			"the declared package dependency closure",
		))
		for recipe_id in sorted(_string_items(capability.get("recipes"))):
			if recipe_id not in recipe_records:
				issues.append(f"Capability {capability_id} references an unknown recipe: {recipe_id}.")

	issues.extend(_recipe_reference_issues(api_index, recipes))
	return issues


def package_dependency_closure(package_ids: set[str] | list[str]) -> set[str]:
	"""Return known transitive package dependencies plus the requested packages."""
	package_records = {
		str(item.get("id")): item
		for item in load_api_index().get("packages", [])
		if isinstance(item, dict) and item.get("id")
	}
	closure: set[str] = set()
	pending = list(package_ids)
	while pending:
		package_id = str(pending.pop())
		if not package_id or package_id in closure:
			continue
		closure.add(package_id)
		record = package_records.get(package_id, {})
		dependencies = record.get("dependencies", []) if isinstance(record, dict) else []
		if isinstance(dependencies, list):
			pending.extend(str(item) for item in dependencies if isinstance(item, str))
	return closure


def recipe_package_readiness(
	recipe_ids: set[str] | list[str],
	available_packages: set[str] | list[str],
) -> dict[str, Any]:
	"""Evaluate explicit Recipe package expressions without inferring intent from classes."""
	recipes = recipe_records_by_id()
	all_of: set[str] = set()
	any_of_groups: set[tuple[str, ...]] = set()
	for recipe_id in sorted(set(recipe_ids)):
		record = recipes.get(recipe_id, {})
		requirements = record.get("package_requirements", {}) if isinstance(record, dict) else {}
		if not isinstance(requirements, dict):
			continue
		all_of.update(_string_items(requirements.get("all_of")))
		groups = requirements.get("any_of", [])
		if not isinstance(groups, list):
			continue
		for group in groups:
			values = tuple(sorted(_string_items(group)))
			if values:
				any_of_groups.add(values)
	available = package_dependency_closure(available_packages)
	missing_all_of = sorted(all_of - available)
	ordered_groups = sorted(any_of_groups)
	unsatisfied_groups = [group for group in ordered_groups if not available.intersection(group)]
	return {
		"available_packages": sorted(available),
		"all_of": sorted(all_of),
		"missing_all_of": missing_all_of,
		"any_of": [list(group) for group in ordered_groups],
		"unsatisfied_any_of": [list(group) for group in unsatisfied_groups],
		"satisfied": not missing_all_of and not unsatisfied_groups,
	}


def catalog_framework_version() -> str:
	return str(load_api_index().get("framework_version", "")).strip()


def project_framework_version(project_root: Path) -> str:
	try:
		path = resolve_project_path(project_root, "addons/gf/plugin.cfg", must_exist=True)
	except ValueError:
		return ""
	if not path.is_file():
		return ""
	parser = configparser.ConfigParser()
	try:
		parser.read_string(read_bounded_text(path, _PLUGIN_CONFIG_MAX_BYTES))
	except (OSError, UnicodeDecodeError, ValueError, configparser.Error):
		return ""
	return parser.get("plugin", "version", fallback="").strip().strip('"')


def catalog_compatibility(project_root: Path | None) -> dict[str, Any]:
	catalog_version = catalog_framework_version()
	if project_root is None:
		return {
			"ok": True,
			"project_framework_version": "",
			"catalog_framework_version": catalog_version,
			"issues": [],
		}
	project_version = project_framework_version(project_root)
	issues: list[str] = []
	if not project_version:
		issues.append("GF Framework is not installed or addons/gf/plugin.cfg has no version.")
	if not catalog_version:
		issues.append("GF AI catalog does not declare its framework version.")
	if project_version and catalog_version and project_version != catalog_version:
		issues.append(
			"GF AI catalog version does not match the installed framework: "
			f"{catalog_version} != {project_version}."
		)
	return {
		"ok": not issues,
		"project_framework_version": project_version,
		"catalog_framework_version": catalog_version,
		"issues": issues,
	}


def installed_package_report(project_root: Path) -> dict[str, Any]:
	lockfile_candidate = project_root / ".gf/packages.lock.json"
	if lockfile_candidate.exists() or lockfile_candidate.is_symlink():
		try:
			lockfile = resolve_project_path(project_root, ".gf/packages.lock.json", must_exist=True)
		except ValueError as exc:
			return {
				"packages": [],
				"source": "lockfile",
				"lockfile_present": True,
				"valid": False,
				"issues": [str(exc)],
			}
		if not lockfile.is_file():
			return {
				"packages": [],
				"source": "lockfile",
				"lockfile_present": True,
				"valid": False,
				"issues": ["Package lockfile path is not a file."],
			}
		try:
			data = read_json_object(lockfile)
		except ValueError as exc:
			return {
				"packages": [],
				"source": "lockfile",
				"lockfile_present": True,
				"valid": False,
				"issues": [str(exc)],
			}
		issues, package_ids = _formal_package_lock_issues(data, project_root)
		return {
			"packages": package_ids if not issues else [],
			"source": "lockfile",
			"lockfile_present": True,
			"valid": not issues,
			"issues": issues,
		}

	installed: list[str] = []
	for package in load_api_index().get("packages", []):
		if not isinstance(package, dict):
			continue
		package_id = str(package.get("id", ""))
		representative = str(package.get("representative_path", ""))
		if not package_id or not representative:
			continue
		try:
			path = resolve_project_path(project_root, representative, must_exist=True)
		except ValueError:
			continue
		if path.is_file():
			installed.append(package_id)
	return {
		"packages": sorted(set(installed)),
		"source": "filesystem",
		"lockfile_present": False,
		"valid": True,
		"issues": [],
	}


def installed_package_ids(project_root: Path) -> list[str]:
	return list(installed_package_report(project_root)["packages"])


def _formal_package_lock_issues(
	data: dict[str, Any],
	project_root: Path,
) -> tuple[list[str], list[str]]:
	issues: list[str] = []
	issues.extend(_closed_object_field_issues(
		data,
		_LOCKFILE_REQUIRED_FIELDS,
		_LOCKFILE_ALLOWED_FIELDS,
		"Package lockfile",
	))
	if type(data.get("schema_version")) is not int or data.get("schema_version") != 1:
		issues.append("Package lockfile schema_version must be the integer 1.")
	lock_framework_version = data.get("framework_version")
	if not isinstance(lock_framework_version, str) or not lock_framework_version.strip():
		issues.append("Package lockfile framework_version must be a non-empty string.")
		lock_framework_version = ""
	project_version = project_framework_version(project_root)
	catalog_version = catalog_framework_version()
	if not project_version:
		issues.append("addons/gf/plugin.cfg must declare the project GF Framework version.")
	elif lock_framework_version and lock_framework_version != project_version:
		issues.append(
			"Package lockfile framework_version does not match addons/gf/plugin.cfg: "
			f"{lock_framework_version} != {project_version}."
		)
	if project_version and catalog_version and project_version != catalog_version:
		issues.append(
			"GF AI catalog version does not match the installed framework while reading package state: "
			f"{catalog_version} != {project_version}."
		)
	if "registry_source" in data:
		issues.extend(_lockfile_registry_source_issues(data.get("registry_source")))

	installed = data.get("installed")
	if not isinstance(installed, dict):
		issues.append("Package lockfile installed field must be an object.")
		return issues, []
	package_records = {
		str(item.get("id", "")): item
		for item in load_api_index().get("packages", [])
		if isinstance(item, dict) and item.get("id")
	}
	package_ids = sorted(str(key) for key in installed if str(key))
	for package_id in package_ids:
		entry = installed.get(package_id)
		record = package_records.get(package_id)
		if record is None:
			issues.append(f"Package lockfile references a package absent from this GF release: {package_id}.")
			continue
		issues.extend(_formal_lock_entry_issues(
			package_id,
			entry,
			record,
			lock_framework_version,
			set(package_ids),
			package_records,
		))
	missing_dependencies = sorted(package_dependency_closure(package_ids) - set(package_ids))
	for package_id in missing_dependencies:
		issues.append(f"Package lockfile omits an installed package dependency: {package_id}.")
	return issues, package_ids


def _formal_lock_entry_issues(
	package_id: str,
	entry: Any,
	record: dict[str, Any],
	framework_version: str,
	installed_ids: set[str],
	package_records: dict[str, dict[str, Any]],
) -> list[str]:
	if not isinstance(entry, dict) or not entry:
		return [f"Package lockfile entry must be a non-empty object: {package_id}."]
	issues = _closed_object_field_issues(
		entry,
		_LOCK_ENTRY_REQUIRED_FIELDS,
		_LOCK_ENTRY_ALLOWED_FIELDS,
		f"Package lockfile entry {package_id}",
	)
	version = entry.get("version")
	if not isinstance(version, str) or not version:
		issues.append(f"Package lockfile entry version must be a non-empty string: {package_id}.")
	elif framework_version and version != framework_version:
		issues.append(
			f"Package lockfile entry version does not match framework_version: {package_id}: "
			f"{version} != {framework_version}."
		)
	kind = entry.get("kind")
	expected_kind = str(record.get("kind", ""))
	if not isinstance(kind, str) or kind != expected_kind:
		issues.append(
			f"Package lockfile entry kind does not match this GF release: {package_id}: "
			f"{kind!r} != {expected_kind!r}."
		)
	for field_name in ("reason", "required_by", "paths"):
		if not _valid_unique_string_array(entry.get(field_name)):
			issues.append(
				f"Package lockfile entry {field_name} must be an array of unique non-empty strings: "
				f"{package_id}."
			)
	reasons = entry.get("reason") if isinstance(entry.get("reason"), list) else []
	if not reasons:
		issues.append(f"Package lockfile entry reason must not be empty: {package_id}.")
	for reason in reasons:
		if isinstance(reason, str) and reason not in _LOCK_ENTRY_REASONS:
			issues.append(f"Package lockfile entry contains an invalid reason: {package_id}: {reason}.")
	required_by = entry.get("required_by") if isinstance(entry.get("required_by"), list) else []
	expected_required_by = sorted(
		candidate_id
		for candidate_id in installed_ids
		if package_id in _package_record_dependencies(package_records.get(candidate_id, {}))
	)
	if _valid_unique_string_array(required_by) and sorted(required_by) != expected_required_by:
		issues.append(f"Package lockfile entry required_by is stale: {package_id}.")
	archive = entry.get("archive")
	if not isinstance(archive, str) or not archive:
		issues.append(f"Package lockfile entry archive must be a non-empty string: {package_id}.")
	sha256 = entry.get("sha256")
	if not _is_sha256(sha256):
		issues.append(f"Package lockfile entry sha256 must be a full SHA-256: {package_id}.")
	if "gf_extension_id" in entry and (
		not isinstance(entry.get("gf_extension_id"), str) or not entry.get("gf_extension_id")
	):
		issues.append(f"Package lockfile entry gf_extension_id must be a non-empty string: {package_id}.")
	issues.extend(_lock_entry_file_metadata_issues(package_id, entry))
	return issues


def _lock_entry_file_metadata_issues(package_id: str, entry: dict[str, Any]) -> list[str]:
	issues: list[str] = []
	files = entry.get("files")
	if not _valid_unique_string_array(files) or not files:
		issues.append(
			f"Package lockfile entry files must be a non-empty array of unique package paths: {package_id}."
		)
		return issues
	file_identities: set[str] = set()
	for relative_path in files:
		identity = _portable_package_file_identity(relative_path)
		if not identity or identity in file_identities:
			issues.append(f"Package lockfile entry files contains an unsafe or aliased path: {package_id}.")
			continue
		file_identities.add(identity)
	metadata = entry.get("file_metadata")
	if not isinstance(metadata, dict):
		issues.append(f"Package lockfile entry file_metadata must be an object: {package_id}.")
		return issues
	metadata_identities: set[str] = set()
	for relative_path, value in metadata.items():
		identity = _portable_package_file_identity(relative_path) if isinstance(relative_path, str) else ""
		if not identity or identity in metadata_identities:
			issues.append(f"Package lockfile entry file_metadata contains an unsafe or aliased path: {package_id}.")
			continue
		metadata_identities.add(identity)
		if not isinstance(value, dict) or set(value) != {"sha256", "size_bytes"}:
			issues.append(f"Package lockfile entry file_metadata value is invalid: {package_id}.")
			continue
		if not _is_sha256(value.get("sha256")) or type(value.get("size_bytes")) is not int or value["size_bytes"] < 0:
			issues.append(f"Package lockfile entry file_metadata value is invalid: {package_id}.")
	if file_identities != metadata_identities:
		issues.append(f"Package lockfile entry file_metadata must exactly cover files: {package_id}.")
	return issues


def _lockfile_registry_source_issues(value: Any) -> list[str]:
	if not isinstance(value, dict):
		return ["Package lockfile registry_source must be an object when present."]
	issues = _closed_object_field_issues(
		value,
		frozenset(),
		_LOCKFILE_REGISTRY_SOURCE_ALLOWED_FIELDS,
		"Package lockfile registry_source",
	)
	for field_name in ("source", "source_manifest", "channel", "offline_bundle", "registry_sha256"):
		if field_name in value and not isinstance(value[field_name], str):
			issues.append(f"Package lockfile registry_source {field_name} must be a string.")
	if "registry_sha256" in value and not _is_sha256(value.get("registry_sha256")):
		issues.append("Package lockfile registry_source registry_sha256 must be a full SHA-256.")
	if "remote" in value and type(value["remote"]) is not bool:
		issues.append("Package lockfile registry_source remote must be boolean.")
	if "mirror_index" in value and (type(value["mirror_index"]) is not int or value["mirror_index"] < -1):
		issues.append("Package lockfile registry_source mirror_index must be an integer greater than or equal to -1.")
	if "registry_size_bytes" in value and (
		type(value["registry_size_bytes"]) is not int or value["registry_size_bytes"] < 0
	):
		issues.append("Package lockfile registry_source registry_size_bytes must be a non-negative integer.")
	return issues


def _closed_object_field_issues(
	value: dict[str, Any],
	required: frozenset[str],
	allowed: frozenset[str],
	label: str,
) -> list[str]:
	issues = [f"{label} is missing required field: {field_name}." for field_name in sorted(required - set(value))]
	issues.extend(f"{label} contains unsupported field: {field_name}." for field_name in sorted(set(value) - allowed))
	return issues


def _valid_unique_string_array(value: Any) -> bool:
	return (
		isinstance(value, list)
		and all(isinstance(item, str) and bool(item) and item == item.strip() for item in value)
		and len(value) == len(set(value))
	)


def _package_record_dependencies(record: dict[str, Any]) -> set[str]:
	value = record.get("dependencies", []) if isinstance(record, dict) else []
	return {str(item) for item in value if isinstance(item, str)} if isinstance(value, list) else set()


def _portable_package_file_identity(relative_path: str) -> str:
	if not isinstance(relative_path, str) or not relative_path.startswith("addons/gf/"):
		return ""
	resource_path = "res://" + relative_path
	if normalize_portable_ownership_path(resource_path) != resource_path:
		return ""
	return portable_ownership_path_identity(resource_path)


def _is_sha256(value: Any) -> bool:
	return isinstance(value, str) and len(value) == 64 and all(
		character in "0123456789abcdefABCDEF" for character in value
	)


def _class_records(index: dict[str, Any]) -> dict[str, Any]:
	classes = index.get("classes", {})
	return classes if isinstance(classes, dict) else {}


def _autoload_records(index: dict[str, Any]) -> dict[str, Any]:
	autoloads = index.get("autoloads", {})
	return autoloads if isinstance(autoloads, dict) else {}


def _api_owner_records(index: dict[str, Any]) -> dict[str, Any]:
	owners = dict(_class_records(index))
	owners.update(_autoload_records(index))
	return owners


def _load_knowledge(
	path: Path,
	schema_path: Path | None = None,
	*,
	validate_api_index: bool = False,
) -> dict[str, Any]:
	try:
		stat = path.stat()
		schema_stat = schema_path.stat() if schema_path is not None else None
	except OSError as exc:
		raise ValueError(f"GF AI knowledge file is unreadable: {path}: {exc}") from exc
	return _load_knowledge_cached(
		str(path),
		stat.st_mtime_ns,
		stat.st_size,
		str(schema_path) if schema_path is not None else "",
		schema_stat.st_mtime_ns if schema_stat is not None else 0,
		schema_stat.st_size if schema_stat is not None else 0,
		validate_api_index,
	)


@lru_cache(maxsize=8)
def _load_knowledge_cached(
	path: str,
	_modified_ns: int,
	_size: int,
	schema_path: str,
	_schema_modified_ns: int,
	_schema_size: int,
	validate_api_index: bool,
) -> dict[str, Any]:
	data = read_json_object(Path(path))
	issues: list[str] = []
	if schema_path:
		issues.extend(
			f"{item['path']}: {item['message']}"
			for item in validate_schema_file(data, Path(schema_path))
		)
	if validate_api_index:
		issues.extend(_api_index_issues(data))
	if issues:
		raise ValueError("GF AI knowledge validation failed: " + "; ".join(issues[:20]))
	return data


def _catalog_record_id_issues(data: dict[str, Any], record_key: str) -> list[str]:
	records = data.get(record_key, [])
	if not isinstance(records, list):
		return [f"Catalog {record_key} must be an array."]
	seen: set[str] = set()
	issues: list[str] = []
	for record in records:
		record_id = record.get("id") if isinstance(record, dict) else None
		if not isinstance(record_id, str) or not record_id or record_id in seen:
			issues.append(f"Catalog {record_key} id is empty or duplicated: {record_id!r}.")
			continue
		seen.add(record_id)
	return issues


def _api_index_issues(data: dict[str, Any]) -> list[str]:
	issues: list[str] = []
	expected_fields = {
		"schema_version", "catalog_version", "framework_version", "source_digest",
		"class_count", "autoload_count", "package_count", "packages", "classes", "autoloads",
	}
	if set(data) != expected_fields:
		issues.append("API index fields do not match the version 2 contract.")
	if data.get("schema_version") != 2:
		issues.append("API index schema_version must equal 2.")
	if data.get("catalog_version") != API_INDEX_CATALOG_VERSION:
		issues.append(
			f"API index catalog_version must equal {API_INDEX_CATALOG_VERSION}."
		)
	for field in ("catalog_version", "framework_version"):
		if not isinstance(data.get(field), str) or not data.get(field):
			issues.append(f"API index {field} must be a non-empty string.")
	packages = data.get("packages")
	classes = data.get("classes")
	autoloads = data.get("autoloads")
	if not isinstance(packages, list):
		issues.append("API index packages must be an array.")
		packages = []
	if not isinstance(classes, dict):
		issues.append("API index classes must be an object.")
		classes = {}
	if not isinstance(autoloads, dict):
		issues.append("API index autoloads must be an object.")
		autoloads = {}
	if data.get("package_count") != len(packages):
		issues.append("API index package_count does not match packages.")
	if data.get("class_count") != len(classes):
		issues.append("API index class_count does not match classes.")
	if data.get("autoload_count") != len(autoloads):
		issues.append("API index autoload_count does not match autoloads.")
	package_ids: set[str] = set()
	for package in packages:
		if not isinstance(package, dict):
			issues.append("API index package record must be an object.")
			continue
		package_id = package.get("id")
		if not isinstance(package_id, str) or not package_id or package_id in package_ids:
			issues.append(f"API index package id is empty or duplicated: {package_id!r}.")
			continue
		package_ids.add(package_id)
	for package in packages:
		if not isinstance(package, dict):
			continue
		package_id = str(package.get("id", ""))
		dependencies = package.get("dependencies", [])
		if not isinstance(dependencies, list):
			issues.append(f"API index package dependencies must be an array: {package_id}.")
			continue
		for dependency_id in dependencies:
			if not isinstance(dependency_id, str) or dependency_id not in package_ids:
				issues.append(f"API index package has an unknown dependency: {package_id} -> {dependency_id!r}.")
	issues.extend(_package_dependency_cycle_issues(packages, package_ids))
	owner_identities: dict[str, str] = {}
	for owner_kind, records in (("class", classes), ("autoload", autoloads)):
		for owner_name, record in records.items():
			if not isinstance(owner_name, str) or not owner_name or not isinstance(record, dict):
				issues.append(f"API index {owner_kind} record is invalid: {owner_name!r}.")
				continue
			identity = owner_name.casefold()
			previous_owner = owner_identities.get(identity)
			if previous_owner is not None:
				issues.append(
					"API index owner identity is duplicated across owner kinds: "
					f"{previous_owner} and {owner_kind}:{owner_name}."
				)
			else:
				owner_identities[identity] = f"{owner_kind}:{owner_name}"
			if record.get("owner_kind") != owner_kind:
				issues.append(
					f"API index {owner_kind} record owner_kind is invalid: {owner_name}."
				)
			owner_package_id = record.get("package_id")
			if not isinstance(owner_package_id, str) or owner_package_id not in package_ids:
				issues.append(
					f"API index {owner_kind} has no known owner package: {owner_name}."
				)
			members = record.get("members")
			if not isinstance(members, list) or any(not isinstance(member, dict) for member in members):
				issues.append(
					f"API index {owner_kind} members must be object records: {owner_name}."
				)
	digest = data.get("source_digest")
	payload = {key: value for key, value in data.items() if key != "source_digest"}
	expected_digest = sha256_bytes(canonical_json_bytes(payload))
	if not isinstance(digest, str) or digest != expected_digest:
		issues.append("API index source_digest does not match its content.")
	return issues


def _package_dependency_cycle_issues(
	packages: list[Any],
	package_ids: set[str],
) -> list[str]:
	graph: dict[str, list[str]] = {}
	for package in packages:
		if not isinstance(package, dict) or not isinstance(package.get("id"), str):
			continue
		raw_dependencies = package.get("dependencies", [])
		dependencies = raw_dependencies if isinstance(raw_dependencies, list) else []
		graph[str(package["id"])] = sorted(
			dependency_id
			for dependency_id in dependencies
			if isinstance(dependency_id, str) and dependency_id in package_ids
		)
	state: dict[str, int] = {}
	cycles: set[tuple[str, ...]] = set()

	for start_id in sorted(graph):
		if state.get(start_id) == 2:
			continue
		path = [start_id]
		positions = {start_id: 0}
		state[start_id] = 1
		stack: list[tuple[str, int]] = [(start_id, 0)]
		while stack:
			package_id, dependency_index = stack[-1]
			dependencies = graph.get(package_id, [])
			if dependency_index >= len(dependencies):
				stack.pop()
				state[package_id] = 2
				positions.pop(package_id, None)
				path.pop()
				continue
			dependency_id = dependencies[dependency_index]
			stack[-1] = (package_id, dependency_index + 1)
			dependency_state = state.get(dependency_id, 0)
			if dependency_state == 2:
				continue
			if dependency_state == 1:
				cycle_start = positions.get(dependency_id)
				if cycle_start is not None:
					cycle = path[cycle_start:]
					minimum_index = min(range(len(cycle)), key=cycle.__getitem__)
					cycles.add(tuple(cycle[minimum_index:] + cycle[:minimum_index]))
				continue
			positions[dependency_id] = len(path)
			path.append(dependency_id)
			state[dependency_id] = 1
			stack.append((dependency_id, 0))
	return [
		"API index package dependency graph contains a cycle: "
		+ " -> ".join((*cycle, cycle[0]))
		+ "."
		for cycle in sorted(cycles)
	]


def _recipe_reference_issues(
	api_index: dict[str, Any],
	recipes: dict[str, Any],
) -> list[str]:
	issues: list[str] = []
	classes = _class_records(api_index)
	package_records = {
		str(item.get("id", "")): item
		for item in api_index.get("packages", [])
		if isinstance(item, dict) and item.get("id")
	}
	for recipe in recipes.get("recipes", []):
		if not isinstance(recipe, dict):
			continue
		recipe_id = str(recipe.get("id", ""))
		requirements = recipe.get("package_requirements", {})
		if not isinstance(requirements, dict):
			continue
		references = set(_string_items(requirements.get("all_of")))
		groups = requirements.get("any_of", [])
		if isinstance(groups, list):
			for group in groups:
				references.update(_string_items(group))
		for package_id in sorted(references - set(package_records)):
			issues.append(f"Recipe {recipe_id} references an unknown package: {package_id}.")
		provided_packages = _package_record_dependency_closure(
			references,
			package_records,
		)
		for class_name in sorted(_string_items(recipe.get("primary_classes"))):
			record = classes.get(class_name)
			if not isinstance(record, dict):
				issues.append(f"Recipe {recipe_id} references an unknown class: {class_name}.")
				continue
			owner_package = str(record.get("package_id", ""))
			if owner_package not in provided_packages:
				issues.append(
					f"Recipe {recipe_id} primary class {class_name} is owned by "
					f"{owner_package}, which is not provided by its package requirements."
				)
		issues.extend(_required_api_member_issues(
			f"Recipe {recipe_id}",
			recipe,
			classes,
			provided_packages,
			"its package requirements",
		))
	return issues


def _required_api_member_issues(
	label: str,
	record: dict[str, Any],
	classes: dict[str, Any],
	provided_packages: set[str],
	package_context: str,
) -> list[str]:
	issues: list[str] = []
	requirements = record.get("required_api_members", [])
	if not isinstance(requirements, list):
		return [f"{label} required_api_members must be an array."]
	for requirement in requirements:
		if not isinstance(requirement, dict):
			issues.append(f"{label} required_api_members entries must be objects.")
			continue
		class_name = str(requirement.get("class_name", ""))
		class_record = classes.get(class_name)
		if not isinstance(class_record, dict):
			issues.append(f"{label} requires an unknown API class: {class_name}.")
			continue
		owner_package = str(class_record.get("package_id", ""))
		if owner_package not in provided_packages:
			issues.append(
				f"{label} required API class {class_name} is owned by "
				f"{owner_package}, which is not provided by {package_context}."
			)
		known_members = {
			str(member.get("name"))
			for member in class_record.get("members", [])
			if isinstance(member, dict) and isinstance(member.get("name"), str)
		}
		for member_name in sorted(_string_items(requirement.get("members")) - known_members):
			issues.append(f"{label} requires an unknown API member: {class_name}.{member_name}.")
	return issues


def _package_record_dependency_closure(
	package_ids: set[str],
	package_records: dict[str, dict[str, Any]],
) -> set[str]:
	closure: set[str] = set()
	pending = list(package_ids)
	while pending:
		package_id = pending.pop()
		if package_id in closure:
			continue
		closure.add(package_id)
		record = package_records.get(package_id, {})
		dependencies = record.get("dependencies", []) if isinstance(record, dict) else []
		pending.extend(_string_items(dependencies))
	return closure


def _string_items(value: Any) -> set[str]:
	if not isinstance(value, (list, tuple, set)):
		return set()
	return {str(item) for item in value if isinstance(item, str) and item}


def _text_score(
	needle: str,
	*values: str,
	allow_partial: bool = False,
) -> int:
	normalized_needle = _normalize_search_text(needle)
	terms = (
		_search_terms(normalized_needle)
		if allow_partial
		else normalized_needle.split()
	)
	if allow_partial:
		if not terms:
			return 0
		normalized_needle = " ".join(terms)
	score = 0
	for value in values:
		text = _normalize_search_text(value)
		if text == normalized_needle:
			score = max(score, 100)
		elif text.startswith(normalized_needle):
			score = max(score, 80)
		elif (
			normalized_needle in text
			if not allow_partial
			else _contains_token_phrase(text, normalized_needle)
		):
			score = max(score, 50)
		elif allow_partial and _contains_token_phrase(normalized_needle, text):
			value_term_count = len(_search_terms(text))
			score = max(score, 60 if value_term_count >= 2 else 35)
		elif terms:
			matched_terms = sum(
				1
				for term in terms
				if _term_matches(term, text, expand_morphology=allow_partial)
			)
			if matched_terms == len(terms):
				score = max(score, 45 if allow_partial else 30)
			elif allow_partial:
				coverage = matched_terms / len(terms)
				if matched_terms >= 2 and coverage >= 0.5:
					score = max(score, 20 + int(coverage * 20))
	return score


def _primary_class_score(needle: str, primary_classes: list[str]) -> int:
	score = _text_score(needle, *primary_classes, allow_partial=True)
	if score == 100:
		return score
	return min(score, _PRIMARY_CLASS_PARTIAL_SCORE_LIMIT)


def _term_matches(
	term: str,
	text: str,
	*,
	expand_morphology: bool = False,
) -> bool:
	if not expand_morphology:
		if term in text:
			return True
		return len(term) > 3 and term.endswith("s") and term[:-1] in text
	return any(_token_matches(term, text_term) for text_term in text.split())


def _token_matches(term: str, text_term: str) -> bool:
	if term == text_term:
		return True
	if len(term) > 3 and term.endswith("s") and term[:-1] == text_term:
		return True
	if len(text_term) > 3 and text_term.endswith("s") and text_term[:-1] == term:
		return True
	if len(term) > 5 and term.endswith("ing"):
		stem = term[:-3]
		return text_term in {stem, f"{stem}e"}
	if len(term) > 4 and term.endswith("ed"):
		stem = term[:-2]
		return text_term in {stem, f"{stem}e"}
	return False


def _contains_token_phrase(haystack: str, phrase: str) -> bool:
	haystack_terms = haystack.split()
	phrase_terms = phrase.split()
	if not phrase_terms or len(phrase_terms) > len(haystack_terms):
		return False
	window_size = len(phrase_terms)
	return any(
		haystack_terms[index:index + window_size] == phrase_terms
		for index in range(len(haystack_terms) - window_size + 1)
	)


def _normalize_search_text(value: str) -> str:
	text = _CAMEL_ACRONYM_BOUNDARY.sub(" ", str(value))
	text = _CAMEL_WORD_BOUNDARY.sub(" ", text)
	text = _SEARCH_SEPARATOR.sub(" ", text.casefold())
	return " ".join(text.split())


def _search_terms(value: str) -> list[str]:
	return [
		term
		for term in value.split()
		if term and term not in _SEARCH_STOP_WORDS
	]


def _limit_is_valid(value: Any, maximum: int) -> bool:
	return isinstance(value, int) and not isinstance(value, bool) and 1 <= value <= maximum


def _text_query_issue(value: Any, field: str, maximum: int) -> str:
	if not isinstance(value, str) or not value.strip():
		return f"{field} must be a non-empty string"
	if len(value) > maximum:
		return f"{field} must not exceed {maximum} characters"
	if not _normalize_search_text(value):
		return f"{field} must include at least one letter or number"
	return ""
