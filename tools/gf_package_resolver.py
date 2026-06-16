#!/usr/bin/env python3
"""Plan GF package installs/uninstalls against a registry and lockfile."""

from __future__ import annotations

import argparse
import copy
import json
import re
import sys
from pathlib import Path
from typing import Any


def find_workspace_root(start: Path, fallback: Path) -> Path:
	current = start.resolve()
	while True:
		if (current / "addons/gf/plugin.cfg").is_file():
			return current
		if current == current.parent:
			return fallback.resolve()
		current = current.parent


SCRIPT_PATH = Path(__file__).resolve()
ROOT = find_workspace_root(SCRIPT_PATH.parent, SCRIPT_PATH.parents[1])
LOCKFILE_SCHEMA_VERSION = 1
VALID_REASONS = {"manual", "dependency", "preset", "bundled", "dev"}
PROTECTED_REASONS = {"manual", "preset", "bundled", "dev"}
PROJECT_SCAN_EXTENSIONS = {".cfg", ".gd", ".godot", ".json", ".tres", ".tscn"}
PROJECT_SCAN_EXCLUDED_PREFIXES = (
	".git/",
	".gf/",
	".godot/",
	".import/",
	"addons/gf/",
	"addons/gut/",
	"ai_analysis/",
	"build/",
)
UNSUPPORTED_REGISTRY_PACKAGE_SIGNATURE_FIELDS = {
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


def main() -> int:
	configure_stdio()
	parser = argparse.ArgumentParser(description="Plan GF package installs and uninstalls.")
	subparsers = parser.add_subparsers(dest="command", required=True)

	install_parser = subparsers.add_parser("install-plan", help="Resolve package dependencies and optionally write a lockfile.")
	install_parser.add_argument("packages", nargs="+", help="Package ids to install.")
	add_common_args(install_parser)
	install_parser.add_argument("--reason", choices=sorted(VALID_REASONS - {"dependency"}), default="manual")
	install_parser.add_argument("--write-lock", action="store_true")

	uninstall_parser = subparsers.add_parser("uninstall-plan", help="Plan safe package removal from a lockfile.")
	uninstall_parser.add_argument("packages", nargs="+", help="Package ids to uninstall.")
	add_common_args(uninstall_parser)
	uninstall_parser.add_argument("--project-root", default=".", help="Project root to scan for references before removal.")
	uninstall_parser.add_argument("--force", action="store_true", help="Ignore required_by/protected reason/reference blockers.")
	uninstall_parser.add_argument("--write-lock", action="store_true")

	verify_parser = subparsers.add_parser("verify-lock", help="Validate lockfile consistency with a registry.")
	add_common_args(verify_parser)

	args = parser.parse_args()
	if args.command == "install-plan":
		result = install_plan(
			registry_path=args.registry,
			lockfile_path=args.lockfile,
			package_ids=args.packages,
			reason=args.reason,
			write_lock=args.write_lock,
		)
	elif args.command == "uninstall-plan":
		result = uninstall_plan(
			registry_path=args.registry,
			lockfile_path=args.lockfile,
			package_ids=args.packages,
			project_root=args.project_root,
			force=args.force,
			write_lock=args.write_lock,
		)
	else:
		result = verify_lock(registry_path=args.registry, lockfile_path=args.lockfile)
	print_result(result, args.json)
	return 0 if result["ok"] else 1


def add_common_args(parser: argparse.ArgumentParser) -> None:
	parser.add_argument("--registry", required=True, help="Registry index JSON path.")
	parser.add_argument("--lockfile", default=".gf/packages.lock.json", help="Project package lockfile path.")
	parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")


def configure_stdio() -> None:
	for stream in (sys.stdin, sys.stdout, sys.stderr):
		if hasattr(stream, "reconfigure"):
			stream.reconfigure(encoding="utf-8", errors="replace")


def install_plan(
	registry_path: str,
	lockfile_path: str,
	package_ids: list[str],
	reason: str,
	write_lock: bool,
) -> dict[str, Any]:
	registry = load_registry(resolve_path(registry_path))
	lockfile = load_lockfile(resolve_path(lockfile_path))
	issues = [*registry["issues"], *lockfile["issues"]]
	if reason not in VALID_REASONS or reason == "dependency":
		issues.append(f"Invalid install reason: {reason}")
	if issues:
		return make_plan_result(False, "install", [], [], [], [], issues, lockfile["data"], write_lock, lockfile_path)

	closure = resolve_dependency_closure(registry["packages"], package_ids)
	if closure["issues"]:
		return make_plan_result(False, "install", [], [], [], [], closure["issues"], lockfile["data"], write_lock, lockfile_path)

	original_installed = copy.deepcopy(lockfile["data"]["installed"])
	installed = copy.deepcopy(original_installed)
	requested_package_ids = set(package_ids)
	for package_id in closure["order"]:
		registry_entry = registry["packages"][package_id]
		entry = make_lock_entry(registry_entry, package_id)
		existing = installed.get(package_id, {})
		reasons = set(string_array(existing.get("reason", [])))
		if package_id in requested_package_ids:
			reasons.add(reason)
		elif package_id == "gf.kernel":
			reasons.add("bundled")
		else:
			reasons.add("dependency")
		entry["reason"] = sorted(reasons)
		installed[package_id] = entry
	recompute_required_by(installed, registry["packages"])
	planned_lock = make_lockfile(lockfile["data"], installed, registry["framework_version"])
	to_install = [package_id for package_id in closure["order"] if package_id not in original_installed]
	to_update = [
		package_id
		for package_id in closure["order"]
		if package_id in original_installed
		and lock_entry_changed(original_installed[package_id], installed[package_id])
	]
	if write_lock:
		write_lockfile(resolve_path(lockfile_path), planned_lock)
	return make_plan_result(
		True,
		"install",
		closure["order"],
		to_install,
		to_update,
		[],
		[],
		planned_lock,
		write_lock,
		lockfile_path,
	)


def uninstall_plan(
	registry_path: str,
	lockfile_path: str,
	package_ids: list[str],
	project_root: str,
	force: bool,
	write_lock: bool,
) -> dict[str, Any]:
	registry = load_registry(resolve_path(registry_path))
	lockfile = load_lockfile(resolve_path(lockfile_path))
	issues = [*registry["issues"], *lockfile["issues"]]
	if issues:
		return make_plan_result(False, "uninstall", [], [], [], [], issues, lockfile["data"], write_lock, lockfile_path)

	installed = copy.deepcopy(lockfile["data"]["installed"])
	blocked: list[dict[str, Any]] = []
	to_remove: list[str] = []
	for package_id in package_ids:
		entry = installed.get(package_id)
		if not isinstance(entry, dict):
			blocked.append({"id": package_id, "reason": "not_installed"})
			continue
		reasons = set(string_array(entry.get("reason", [])))
		required_by = string_array(entry.get("required_by", []))
		protected = sorted((reasons & (PROTECTED_REASONS - {"manual"})))
		references = scan_project_references(resolve_path(project_root), registry["packages"], package_id)
		if required_by and not force:
			blocked.append({"id": package_id, "reason": "required_by", "required_by": required_by})
			continue
		if protected and not force:
			blocked.append({"id": package_id, "reason": "protected_reason", "protected_reasons": protected})
			continue
		if references and not force:
			blocked.append({"id": package_id, "reason": "project_references", "references": references[:20]})
			continue
		append_unique(to_remove, package_id)
	if blocked:
		return make_plan_result(False, "uninstall", [], [], [], [], ["Uninstall blocked."], lockfile["data"], write_lock, lockfile_path, blocked=blocked)

	for package_id in to_remove:
		installed.pop(package_id, None)
	recompute_required_by(installed, registry["packages"])
	pruned = prune_dependency_only_packages(installed, registry["packages"], force=force)
	planned_lock = make_lockfile(lockfile["data"], installed, registry["framework_version"])
	if write_lock:
		write_lockfile(resolve_path(lockfile_path), planned_lock)
	return make_plan_result(
		True,
		"uninstall",
		[],
		[],
		[],
		[to_remove_item for to_remove_item in [*to_remove, *pruned]],
		[],
		planned_lock,
		write_lock,
		lockfile_path,
		blocked=[],
	)


def verify_lock(registry_path: str, lockfile_path: str) -> dict[str, Any]:
	registry = load_registry(resolve_path(registry_path))
	lockfile = load_lockfile(resolve_path(lockfile_path))
	issues = [*registry["issues"], *lockfile["issues"]]
	installed = lockfile["data"]["installed"]
	expected = copy.deepcopy(installed)
	recompute_required_by(expected, registry["packages"])
	for package_id, entry in installed.items():
		registry_entry = registry["packages"].get(package_id)
		if registry_entry is None:
			issues.append(f"Installed package is missing from registry: {package_id}")
			continue
		if entry.get("sha256", "") != registry_entry.get("sha256", ""):
			issues.append(f"Installed package sha256 differs from registry: {package_id}")
		if sorted(string_array(entry.get("required_by", []))) != sorted(string_array(expected.get(package_id, {}).get("required_by", []))):
			issues.append(f"Installed package required_by is stale: {package_id}")
	return make_plan_result(len(issues) == 0, "verify", [], [], [], [], issues, lockfile["data"], False, lockfile_path)


def resolve_dependency_closure(packages: dict[str, dict[str, Any]], roots: list[str]) -> dict[str, Any]:
	order: list[str] = []
	issues: list[str] = []
	visiting: list[str] = []
	visited: set[str] = set()

	def visit(package_id: str) -> None:
		if package_id in visited:
			return
		if package_id in visiting:
			cycle = [*visiting[visiting.index(package_id):], package_id]
			issues.append("Package dependency cycle: " + " -> ".join(cycle))
			return
		if package_id not in packages:
			issues.append(f"Missing package: {package_id}")
			return
		visiting.append(package_id)
		for dependency_id in package_dependency_ids(packages[package_id]):
			visit(dependency_id)
		visiting.pop()
		visited.add(package_id)
		append_unique(order, package_id)

	for root_package_id in roots:
		visit(root_package_id)
	return {"order": order, "issues": issues}


def recompute_required_by(installed: dict[str, Any], packages: dict[str, dict[str, Any]]) -> None:
	for entry in installed.values():
		if isinstance(entry, dict):
			entry["required_by"] = []
	for package_id in sorted(installed.keys()):
		registry_entry = packages.get(package_id, {})
		for dependency_id in package_dependency_ids(registry_entry):
			if dependency_id in installed:
				append_unique(installed[dependency_id]["required_by"], package_id)
	for entry in installed.values():
		if isinstance(entry, dict):
			entry["required_by"] = sorted(string_array(entry.get("required_by", [])))


def prune_dependency_only_packages(installed: dict[str, Any], packages: dict[str, dict[str, Any]], force: bool) -> list[str]:
	pruned: list[str] = []
	changed = True
	while changed:
		changed = False
		recompute_required_by(installed, packages)
		for package_id in sorted(list(installed.keys())):
			entry = installed[package_id]
			reasons = set(string_array(entry.get("reason", [])))
			required_by = string_array(entry.get("required_by", []))
			if reasons <= {"dependency"} and not required_by:
				if package_id == "gf.kernel" and not force:
					continue
				installed.pop(package_id, None)
				append_unique(pruned, package_id)
				changed = True
	return pruned


def scan_project_references(project_root: Path, packages: dict[str, dict[str, Any]], package_id: str) -> list[dict[str, Any]]:
	package = packages.get(package_id)
	if package is None:
		return []
	path_tokens = package_path_tokens(string_array(package.get("paths", [])))
	symbols = collect_package_class_names(package)
	package_tokens = [package_id, *path_tokens, *symbols]
	if not package_tokens:
		return []
	references: list[dict[str, Any]] = []
	for path in collect_project_scan_files(project_root):
		text = read_text(path)
		if not text:
			continue
		relative_path = path.relative_to(project_root).as_posix()
		for token in package_tokens:
			if token.startswith("GF"):
				if source_contains_identifier(text, token):
					references.append({"path": relative_path, "symbol": token})
					break
			elif token in text:
				references.append({"path": relative_path, "symbol": token})
				break
	return references


def collect_project_scan_files(project_root: Path) -> list[Path]:
	if not project_root.is_dir():
		return []
	files: list[Path] = []
	for path in sorted(project_root.rglob("*")):
		if not path.is_file():
			continue
		relative_path = path.relative_to(project_root).as_posix()
		if any(relative_path.startswith(prefix) for prefix in PROJECT_SCAN_EXCLUDED_PREFIXES):
			continue
		if path.suffix.lower() in PROJECT_SCAN_EXTENSIONS or path.name == "project.godot":
			files.append(path)
	return files


def collect_package_class_names(package: dict[str, Any]) -> list[str]:
	result: list[str] = []
	for pattern in string_array(package.get("paths", [])):
		for path in expand_source_pattern(pattern):
			if path.suffix.lower() != ".gd":
				continue
			text = read_text(path)
			for match in re.finditer(r"(?m)^\s*class_name\s+([A-Za-z_]\w*)", text):
				append_unique(result, match.group(1))
	return result


def expand_source_pattern(pattern: str) -> list[Path]:
	normalized = normalize_manifest_path(pattern)
	if not normalized:
		return []
	if normalized.endswith("/**") and not any(token in normalized[:-3] for token in ("*", "?", "[")):
		directory = ROOT / normalized[:-3].rstrip("/")
		if not directory.is_dir():
			return []
		return sorted(path for path in directory.rglob("*") if path.is_file())
	if any(token in normalized for token in ("*", "?", "[")):
		return sorted(ROOT.glob(normalized))
	path = ROOT / normalized
	return [path] if path.exists() else []


def package_path_tokens(paths: list[str]) -> list[str]:
	tokens: list[str] = []
	for path in paths:
		normalized = normalize_manifest_path(path)
		if not normalized:
			continue
		if normalized.endswith("/**"):
			normalized = normalized[:-3].rstrip("/")
		append_unique(tokens, normalized)
		append_unique(tokens, "res://" + normalized)
	return tokens


def make_lock_entry(registry_entry: dict[str, Any], package_id: str) -> dict[str, Any]:
	entry = {
		"version": str(registry_entry.get("version", "")),
		"kind": str(registry_entry.get("kind", "")),
		"reason": [],
		"required_by": [],
		"paths": string_array(registry_entry.get("paths", [])),
		"archive": str(registry_entry.get("archive", "")),
		"sha256": str(registry_entry.get("sha256", "")),
	}
	if entry["kind"] == "preset":
		entry["packages"] = string_array(registry_entry.get("packages", []))
	if registry_entry.get("enable_extension"):
		entry["enable_extension"] = str(registry_entry["enable_extension"])
	return entry


def package_dependency_ids(registry_entry: dict[str, Any]) -> list[str]:
	if str(registry_entry.get("kind", "")) == "preset":
		return string_array(registry_entry.get("packages", []))
	return string_array(registry_entry.get("dependencies", []))


def make_lockfile(base_lockfile: dict[str, Any], installed: dict[str, Any], framework_version: str) -> dict[str, Any]:
	return {
		"schema_version": LOCKFILE_SCHEMA_VERSION,
		"framework_version": framework_version or str(base_lockfile.get("framework_version", "")),
		"installed": {package_id: installed[package_id] for package_id in sorted(installed.keys())},
	}


def make_plan_result(
	ok: bool,
	operation: str,
	install_order: list[str],
	to_install: list[str],
	to_update: list[str],
	to_remove: list[str],
	issues: list[str],
	lockfile: dict[str, Any],
	write_lock: bool,
	lockfile_path: str,
	blocked: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
	return {
		"ok": ok,
		"operation": operation,
		"install_order": install_order,
		"to_install": to_install,
		"to_update": to_update,
		"to_remove": sorted(to_remove),
		"blocked": blocked or [],
		"lockfile_written": write_lock and ok,
		"lockfile": normalize_display_path(resolve_path(lockfile_path)),
		"installed_count": len(lockfile.get("installed", {})),
		"issues": issues,
		"planned_lockfile": lockfile,
	}


def load_registry(path: Path) -> dict[str, Any]:
	issues: list[str] = []
	try:
		data = json.loads(path.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
		return {"packages": {}, "framework_version": "", "issues": [f"Could not read registry: {error}"]}
	if not isinstance(data, dict):
		return {"packages": {}, "framework_version": "", "issues": ["Registry root must be an object."]}
	if data.get("schema_version") != 1:
		issues.append("Registry schema_version must be 1.")
	packages = data.get("packages", {})
	if not isinstance(packages, dict):
		issues.append("Registry packages must be an object.")
		packages = {}
	clean_packages: dict[str, dict[str, Any]] = {}
	for package_id, package_entry in sorted(packages.items()):
		if not isinstance(package_entry, dict):
			continue
		has_unsupported_signature = False
		for field_name in sorted(UNSUPPORTED_REGISTRY_PACKAGE_SIGNATURE_FIELDS.intersection(package_entry)):
			has_unsupported_signature = True
			issues.append(
				"Registry package signature field is not supported until native verification is implemented: "
				f"{package_id}.{field_name}"
			)
		if has_unsupported_signature:
			continue
		clean_packages[str(package_id)] = package_entry
	return {
		"packages": clean_packages,
		"framework_version": str(data.get("framework_version", "")),
		"issues": issues,
	}


def load_lockfile(path: Path) -> dict[str, Any]:
	if not path.exists():
		return {"data": {"schema_version": LOCKFILE_SCHEMA_VERSION, "framework_version": "", "installed": {}}, "issues": []}
	issues: list[str] = []
	try:
		data = json.loads(path.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
		return {"data": {"schema_version": LOCKFILE_SCHEMA_VERSION, "framework_version": "", "installed": {}}, "issues": [f"Could not read lockfile: {error}"]}
	if not isinstance(data, dict):
		return {"data": {"schema_version": LOCKFILE_SCHEMA_VERSION, "framework_version": "", "installed": {}}, "issues": ["Lockfile root must be an object."]}
	if data.get("schema_version") != LOCKFILE_SCHEMA_VERSION:
		issues.append(f"Lockfile schema_version must be {LOCKFILE_SCHEMA_VERSION}.")
	installed = data.get("installed", {})
	if not isinstance(installed, dict):
		issues.append("Lockfile installed must be an object.")
		installed = {}
	data["installed"] = {str(package_id): entry for package_id, entry in installed.items() if isinstance(entry, dict)}
	return {"data": data, "issues": issues}


def write_lockfile(path: Path, lockfile: dict[str, Any]) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_text(json.dumps(lockfile, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def lock_entry_changed(left: dict[str, Any], right: dict[str, Any]) -> bool:
	return (
		left.get("version") != right.get("version")
		or left.get("sha256") != right.get("sha256")
		or sorted(string_array(left.get("reason", []))) != sorted(string_array(right.get("reason", [])))
	)


def resolve_path(path: str) -> Path:
	resolved = Path(path)
	if not resolved.is_absolute():
		resolved = ROOT / resolved
	return resolved


def normalize_display_path(path: Path) -> str:
	try:
		return path.relative_to(ROOT).as_posix()
	except ValueError:
		return path.as_posix()


def normalize_manifest_path(path: str) -> str:
	normalized = path.strip().replace("\\", "/")
	if normalized.startswith("res://"):
		normalized = normalized.removeprefix("res://")
	if normalized.startswith("./"):
		normalized = normalized[2:]
	return normalized.strip("/")


def string_array(value: Any) -> list[str]:
	if isinstance(value, str):
		return [value.strip()] if value.strip() else []
	if not isinstance(value, list):
		return []
	return [item.strip() for item in value if isinstance(item, str) and item.strip()]


def append_unique(items: list[str], item: str) -> None:
	if item and item not in items:
		items.append(item)


def source_contains_identifier(source: str, identifier: str) -> bool:
	return re.search(rf"(?<![A-Za-z0-9_]){re.escape(identifier)}(?![A-Za-z0-9_])", source) is not None


def read_text(path: Path) -> str:
	try:
		return path.read_text(encoding="utf-8")
	except OSError:
		return ""


def print_result(result: dict[str, Any], as_json: bool) -> None:
	if as_json:
		print(json.dumps(result, ensure_ascii=False, indent=2))
		return
	print(f"{result['operation']}: ok={result['ok']} installed={result['installed_count']} lockfile={result['lockfile']}")
	if result["to_install"]:
		print("to_install: " + ", ".join(result["to_install"]))
	if result["to_update"]:
		print("to_update: " + ", ".join(result["to_update"]))
	if result["to_remove"]:
		print("to_remove: " + ", ".join(result["to_remove"]))
	if result["blocked"]:
		print("blocked:")
		for item in result["blocked"]:
			print(f"- {item}")
	if result["issues"]:
		print("issues:")
		for issue in result["issues"]:
			print(f"- {issue}")


if __name__ == "__main__":
	raise SystemExit(main())
