"""Versioned GF capability, recipe, package, and API catalog queries."""

from __future__ import annotations

import configparser
from functools import lru_cache
from pathlib import Path
from typing import Any

from .constants import KNOWLEDGE_ROOT, SCHEMA_ROOT
from .paths import canonical_json_bytes, read_json_object, resolve_project_path, sha256_bytes
from .schema import validate_schema_file


def load_api_index() -> dict[str, Any]:
	return _load_knowledge(KNOWLEDGE_ROOT / "api_index.json", validate_api_index=True)


def load_capabilities() -> dict[str, Any]:
	return _load_knowledge(
		KNOWLEDGE_ROOT / "capabilities.json",
		SCHEMA_ROOT / "capability_catalog.schema.json",
		record_key="capabilities",
	)


def load_recipes() -> dict[str, Any]:
	return _load_knowledge(
		KNOWLEDGE_ROOT / "recipes.json",
		SCHEMA_ROOT / "recipe_catalog.schema.json",
		record_key="recipes",
	)


def api_search(query: str, limit: int = 20, project_root: Path | None = None) -> dict[str, Any]:
	compatibility = catalog_compatibility(project_root)
	if not compatibility["ok"]:
		return {"ok": False, "query": query, "results": [], "compatibility": compatibility, "issues": compatibility["issues"]}
	if not _limit_is_valid(limit, 80):
		return {"ok": False, "query": query, "results": [], "issues": ["limit must be an integer from 1 through 80"]}
	query_issue = _text_query_issue(query, "query", 500)
	if query_issue:
		return {"ok": False, "query": query, "results": [], "issues": [query_issue]}
	needle = query.strip().casefold()
	index = load_api_index()
	results: list[dict[str, Any]] = []
	for class_name, record in _class_records(index).items():
		if not isinstance(record, dict):
			continue
		class_score = _text_score(needle, class_name, str(record.get("summary", "")), str(record.get("module", "")))
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
		score = max(class_score, int(member_matches[0]["score"]) if member_matches else 0)
		if score <= 0:
			continue
		results.append({
			"score": score,
			"class_name": class_name,
			"extends": record.get("extends", ""),
			"module": record.get("module", ""),
			"package_id": record.get("package_id", ""),
			"path": record.get("path", ""),
			"summary": record.get("summary", ""),
			"member_matches": member_matches[:8],
		})
	results.sort(key=lambda item: (-int(item["score"]), str(item["class_name"])))
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
	needle = query.strip().casefold()
	data = load_capabilities()
	results: list[dict[str, Any]] = []
	for capability in data.get("capabilities", []):
		if not isinstance(capability, dict):
			continue
		search_values = [
			str(capability.get("id", "")),
			str(capability.get("title", "")),
			str(capability.get("summary", "")),
			" ".join(str(item) for item in capability.get("keywords", [])),
		]
		score = max(
			_text_score(needle, *search_values),
			_text_score(needle, " ".join(search_values)),
		)
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


def known_package_ids() -> set[str]:
	return {
		str(item.get("id"))
		for item in load_api_index().get("packages", [])
		if isinstance(item, dict) and item.get("id")
	}


def known_api_classes() -> set[str]:
	return set(_class_records(load_api_index()))


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
		parser.read(path, encoding="utf-8")
	except (OSError, UnicodeDecodeError, configparser.Error):
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
		issues: list[str] = []
		if data.get("schema_version") != 1:
			issues.append("Package lockfile schema_version must equal 1.")
		installed = data.get("installed")
		if not isinstance(installed, dict):
			issues.append("Package lockfile installed field must be an object.")
			installed = {}
		package_ids = sorted(str(key) for key in installed if str(key))
		for package_id in package_ids:
			if not isinstance(installed.get(package_id), dict):
				issues.append(f"Package lockfile entry must be an object: {package_id}.")
		for package_id in sorted(set(package_ids) - known_package_ids()):
			issues.append(f"Package lockfile references a package absent from this GF release: {package_id}.")
		lock_framework_version = str(data.get("framework_version", "")).strip()
		project_version = project_framework_version(project_root)
		if not lock_framework_version:
			issues.append("Package lockfile framework_version must be a non-empty string.")
		elif project_version and lock_framework_version != project_version:
			issues.append(
				"Package lockfile framework_version does not match addons/gf/plugin.cfg: "
				f"{lock_framework_version} != {project_version}."
			)
		return {
			"packages": package_ids,
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


def _class_records(index: dict[str, Any]) -> dict[str, Any]:
	classes = index.get("classes", {})
	return classes if isinstance(classes, dict) else {}


def _load_knowledge(
	path: Path,
	schema_path: Path | None = None,
	*,
	validate_api_index: bool = False,
	record_key: str = "",
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
		record_key,
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
	record_key: str,
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
	if record_key:
		issues.extend(_catalog_record_id_issues(data, record_key))
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
		"class_count", "package_count", "packages", "classes",
	}
	if set(data) != expected_fields:
		issues.append("API index fields do not match the version 1 contract.")
	if data.get("schema_version") != 1:
		issues.append("API index schema_version must equal 1.")
	for field in ("catalog_version", "framework_version"):
		if not isinstance(data.get(field), str) or not data.get(field):
			issues.append(f"API index {field} must be a non-empty string.")
	packages = data.get("packages")
	classes = data.get("classes")
	if not isinstance(packages, list):
		issues.append("API index packages must be an array.")
		packages = []
	if not isinstance(classes, dict):
		issues.append("API index classes must be an object.")
		classes = {}
	if data.get("package_count") != len(packages):
		issues.append("API index package_count does not match packages.")
	if data.get("class_count") != len(classes):
		issues.append("API index class_count does not match classes.")
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
	for class_name, record in classes.items():
		if not isinstance(class_name, str) or not class_name or not isinstance(record, dict):
			issues.append(f"API index class record is invalid: {class_name!r}.")
			continue
		if record.get("package_id") not in package_ids:
			issues.append(f"API index class has no known owner package: {class_name}.")
		members = record.get("members")
		if not isinstance(members, list) or any(not isinstance(member, dict) for member in members):
			issues.append(f"API index class members must be object records: {class_name}.")
	digest = data.get("source_digest")
	payload = {key: value for key, value in data.items() if key != "source_digest"}
	expected_digest = sha256_bytes(canonical_json_bytes(payload))
	if not isinstance(digest, str) or digest != expected_digest:
		issues.append("API index source_digest does not match its content.")
	return issues


def _text_score(needle: str, *values: str) -> int:
	score = 0
	for value in values:
		text = value.casefold()
		if text == needle:
			score = max(score, 100)
		elif text.startswith(needle):
			score = max(score, 80)
		elif needle in text:
			score = max(score, 50)
		else:
			terms = [term for term in needle.split() if term]
			if terms and all(_term_matches(term, text) for term in terms):
				score = max(score, 30)
	return score


def _term_matches(term: str, text: str) -> bool:
	if term in text:
		return True
	return len(term) > 3 and term.endswith("s") and term[:-1] in text


def _limit_is_valid(value: Any, maximum: int) -> bool:
	return isinstance(value, int) and not isinstance(value, bool) and 1 <= value <= maximum


def _text_query_issue(value: Any, field: str, maximum: int) -> str:
	if not isinstance(value, str) or not value.strip():
		return f"{field} must be a non-empty string"
	if len(value) > maximum:
		return f"{field} must not exceed {maximum} characters"
	return ""
