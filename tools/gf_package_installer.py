#!/usr/bin/env python3
"""Install and uninstall GF package archives with staging and rollback."""

from __future__ import annotations

import argparse
import configparser
import copy
import fnmatch
import hashlib
import json
import shutil
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path
from typing import Any

import gf_package_resolver


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
BLOCKED_DIR_NAMES = {".git", ".godot", ".import", ".vs", "__pycache__", "node_modules"}
BLOCKED_FILE_NAMES = {".DS_Store", "Thumbs.db"}
BLOCKED_SUFFIXES = {".import", ".pyc", ".pyo", ".tmp", ".log"}
RUNTIME_PACKAGE_FORBIDDEN_EXTERNAL_TOOL_SUFFIXES = {".bash", ".bat", ".cmd", ".ps1", ".py", ".pyw", ".sh", ".zsh"}
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
REMOTE_ARCHIVE_PREFIXES = ("http://", "https://")
MAX_REGISTRY_DOWNLOAD_BYTES = 16 * 1024 * 1024
MAX_ARCHIVE_DOWNLOAD_BYTES = 1024 * 1024 * 1024
UNSUPPORTED_REGISTRY_SOURCE_SIGNATURE_FIELDS = {
	"registry_signature",
	"registry_signature_algorithm",
	"registry_signature_sha256",
	"registry_signature_size_bytes",
	"registry_signature_url",
	"registry_signing_key_id",
	"signature",
	"signature_algorithm",
	"signature_sha256",
	"signature_url",
	"signing_key_id",
}


class InstallFailure(RuntimeError):
	"""Raised after filesystem mutation starts so rollback can run."""


def main() -> int:
	configure_stdio()
	parser = argparse.ArgumentParser(description="Install and uninstall GF package archives from a registry.")
	subparsers = parser.add_subparsers(dest="command", required=True)

	install_parser = subparsers.add_parser("install", help="Install packages from a local registry archive set.")
	install_parser.add_argument("packages", nargs="*", help="Package ids to install.")
	install_parser.add_argument("--registry", required=True, help="Registry index JSON path.")
	install_parser.add_argument("--channel", default="", help="Channel name when --registry points to a registry source manifest.")
	install_parser.add_argument("--project-root", required=True, help="Target Godot project root.")
	install_parser.add_argument("--lockfile", default=".gf/packages.lock.json", help="Lockfile path, relative to --project-root unless absolute.")
	install_parser.add_argument("--cache-dir", default="", help="Package download cache directory. Defaults to <project-root>/.gf/package_cache.")
	install_parser.add_argument("--reason", choices=sorted(gf_package_resolver.VALID_REASONS - {"dependency"}), default="manual")
	install_parser.add_argument("--all-concrete", action="store_true", help="Install every non-preset package selected by the registry.")
	install_parser.add_argument("--kind", action="append", default=[], help="Install packages matching one or more comma-separated package kinds.")
	install_parser.add_argument("--exclude-kind", action="append", default=[], help="Exclude packages matching one or more comma-separated package kinds.")
	install_parser.add_argument("--dry-run", action="store_true", help="Resolve and validate archives without copying files or writing the lockfile.")
	install_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")
	install_parser.add_argument("--simulate-copy-failure-after", type=int, default=0, help=argparse.SUPPRESS)

	update_parser = subparsers.add_parser("update", help="Update packages that are already present in the project lockfile.")
	update_parser.add_argument("packages", nargs="*", help="Installed package ids to update.")
	update_parser.add_argument("--all-installed", action="store_true", help="Update every installed package that is present in the registry.")
	update_parser.add_argument("--registry", required=True, help="Registry index JSON path.")
	update_parser.add_argument("--channel", default="", help="Channel name when --registry points to a registry source manifest.")
	update_parser.add_argument("--project-root", required=True, help="Target Godot project root.")
	update_parser.add_argument("--lockfile", default=".gf/packages.lock.json", help="Lockfile path, relative to --project-root unless absolute.")
	update_parser.add_argument("--cache-dir", default="", help="Package download cache directory. Defaults to <project-root>/.gf/package_cache.")
	update_parser.add_argument("--dry-run", action="store_true", help="Resolve and validate updates without copying files or writing the lockfile.")
	update_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")
	update_parser.add_argument("--simulate-copy-failure-after", type=int, default=0, help=argparse.SUPPRESS)

	uninstall_parser = subparsers.add_parser("uninstall", help="Uninstall packages using the project lockfile.")
	uninstall_parser.add_argument("packages", nargs="+", help="Package ids to uninstall.")
	uninstall_parser.add_argument("--registry", required=True, help="Registry index JSON path.")
	uninstall_parser.add_argument("--channel", default="", help="Channel name when --registry points to a registry source manifest.")
	uninstall_parser.add_argument("--project-root", required=True, help="Target Godot project root.")
	uninstall_parser.add_argument("--lockfile", default=".gf/packages.lock.json", help="Lockfile path, relative to --project-root unless absolute.")
	uninstall_parser.add_argument("--cache-dir", default="", help="Package download cache directory. Defaults to <project-root>/.gf/package_cache.")
	uninstall_parser.add_argument("--force", action="store_true", help="Ignore resolver blockers such as project references.")
	uninstall_parser.add_argument("--dry-run", action="store_true", help="Resolve and validate removal without deleting files or writing the lockfile.")
	uninstall_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")
	uninstall_parser.add_argument("--simulate-delete-failure-after", type=int, default=0, help=argparse.SUPPRESS)

	status_parser = subparsers.add_parser("status", help="List registry packages, lockfile state, and package install/uninstall previews.")
	status_parser.add_argument("--registry", required=True, help="Registry index JSON path.")
	status_parser.add_argument("--channel", default="", help="Channel name when --registry points to a registry source manifest.")
	status_parser.add_argument("--project-root", required=True, help="Target Godot project root.")
	status_parser.add_argument("--lockfile", default=".gf/packages.lock.json", help="Lockfile path, relative to --project-root unless absolute.")
	status_parser.add_argument("--cache-dir", default="", help="Package download cache directory. Defaults to <project-root>/.gf/package_cache.")
	status_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	args = parser.parse_args()
	if args.command == "install":
		result = install_packages(
			package_ids=args.packages,
			registry_path=args.registry,
			channel=args.channel,
			project_root=args.project_root,
			lockfile_path=args.lockfile,
			cache_dir=args.cache_dir,
			reason=args.reason,
			all_concrete=args.all_concrete,
			include_kinds=gf_package_resolver.split_selector_values(args.kind),
			exclude_kinds=gf_package_resolver.split_selector_values(args.exclude_kind),
			dry_run=args.dry_run,
			simulate_copy_failure_after=args.simulate_copy_failure_after,
		)
	elif args.command == "update":
		result = update_packages(
			package_ids=args.packages,
			all_installed=args.all_installed,
			registry_path=args.registry,
			channel=args.channel,
			project_root=args.project_root,
			lockfile_path=args.lockfile,
			cache_dir=args.cache_dir,
			dry_run=args.dry_run,
			simulate_copy_failure_after=args.simulate_copy_failure_after,
		)
	elif args.command == "uninstall":
		result = uninstall_packages(
			package_ids=args.packages,
			registry_path=args.registry,
			channel=args.channel,
			project_root=args.project_root,
			lockfile_path=args.lockfile,
			cache_dir=args.cache_dir,
			force=args.force,
			dry_run=args.dry_run,
			simulate_delete_failure_after=args.simulate_delete_failure_after,
		)
	else:
		result = package_status(
			registry_path=args.registry,
			channel=args.channel,
			project_root=args.project_root,
			lockfile_path=args.lockfile,
			cache_dir=args.cache_dir,
		)
	print_result(result, args.json)
	return 0 if result["ok"] else 1


def configure_stdio() -> None:
	for stream in (sys.stdin, sys.stdout, sys.stderr):
		if hasattr(stream, "reconfigure"):
			stream.reconfigure(encoding="utf-8", errors="replace")


def install_packages(
	package_ids: list[str],
	registry_path: str,
	channel: str,
	project_root: str,
	lockfile_path: str,
	cache_dir: str,
	reason: str,
	all_concrete: bool = False,
	include_kinds: list[str] | None = None,
	exclude_kinds: list[str] | None = None,
	dry_run: bool = False,
	simulate_copy_failure_after: int = 0,
) -> dict[str, Any]:
	resolved_project_root = resolve_tool_path(project_root)
	resolved_lockfile_path = resolve_project_lockfile_path(resolved_project_root, lockfile_path)
	issues: list[str] = []
	registry_source = prepare_registry_source(registry_path, channel, resolved_project_root, cache_dir, issues)
	resolved_registry_path = registry_source["path"]
	resolved_cache_dir = registry_source["cache_dir"]
	if issues:
		return make_install_result(
			False,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			package_ids,
			{},
			[],
			0,
			dry_run,
			False,
			issues,
			registry_source,
		)
	plan = gf_package_resolver.install_plan(
		registry_path=str(resolved_registry_path),
		lockfile_path=str(resolved_lockfile_path),
		package_ids=package_ids,
		reason=reason,
		all_concrete=all_concrete,
		include_kinds=include_kinds or [],
		exclude_kinds=exclude_kinds or [],
		write_lock=False,
		current_framework_version=read_project_framework_version(resolved_project_root),
	)
	plan = plan_with_registry_source(plan, registry_source)
	resolved_package_ids = string_list(plan.get("requested_packages", package_ids))
	if not plan.get("ok"):
		return make_install_result(
			False,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			resolved_package_ids,
			plan,
			[],
			0,
			dry_run,
			False,
			string_list(plan.get("issues", [])),
			registry_source,
		)

	registry = gf_package_resolver.load_registry(resolved_registry_path)
	if registry["issues"]:
		issues.extend(string_list(registry["issues"]))
	to_change = set(string_list(plan.get("to_install", [])) + string_list(plan.get("to_update", [])))
	packages_to_change = [package_id for package_id in string_list(plan.get("install_order", [])) if package_id in to_change]
	packages_to_stage = [
		package_id
		for package_id in packages_to_change
		if package_requires_archive(registry["packages"].get(package_id, {}))
	]
	if issues:
		return make_install_result(
			False,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			resolved_package_ids,
			plan,
			packages_to_change,
			0,
			dry_run,
			False,
			issues,
			registry_source,
		)
	if not packages_to_change:
		return make_install_result(
			True,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			resolved_package_ids,
			plan,
			[],
			0,
			dry_run,
			False,
			[],
			registry_source,
		)

	with tempfile.TemporaryDirectory(prefix="gf-package-install-") as temp_dir:
		temp_root = Path(temp_dir)
		staging_root = temp_root / "staging"
		backup_root = temp_root / "backup"
		staged_files = stage_package_archives(
			packages_to_stage,
			registry["packages"],
			resolved_registry_path,
			resolved_cache_dir,
			staging_root,
			issues,
		)
		if issues:
			return make_install_result(
				False,
				resolved_registry_path,
				resolved_project_root,
				resolved_lockfile_path,
				resolved_package_ids,
				plan,
				packages_to_change,
				0,
				dry_run,
				False,
				issues,
				registry_source,
			)
		if dry_run:
			return make_install_result(
				True,
				resolved_registry_path,
				resolved_project_root,
				resolved_lockfile_path,
				resolved_package_ids,
				plan,
				packages_to_change,
				0,
				True,
				False,
				[],
				registry_source,
			)
		planned_lockfile = lockfile_with_installed_files(plan["planned_lockfile"], staged_files)
		try:
			installed_file_count = copy_staged_files_to_project(
				staged_files,
				resolved_project_root,
				resolved_lockfile_path,
				planned_lockfile,
				backup_root,
				simulate_copy_failure_after,
			)
		except InstallFailure as error:
			issues.append(str(error))
			return make_install_result(
				False,
				resolved_registry_path,
				resolved_project_root,
				resolved_lockfile_path,
				resolved_package_ids,
				plan,
				packages_to_change,
				0,
				False,
				True,
				issues,
				registry_source,
			)
		return make_install_result(
			True,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			resolved_package_ids,
			plan,
			packages_to_change,
			installed_file_count,
			False,
			False,
			[],
			registry_source,
		)


def update_packages(
	package_ids: list[str],
	all_installed: bool,
	registry_path: str,
	channel: str,
	project_root: str,
	lockfile_path: str,
	cache_dir: str,
	dry_run: bool,
	simulate_copy_failure_after: int = 0,
) -> dict[str, Any]:
	resolved_project_root = resolve_tool_path(project_root)
	resolved_lockfile_path = resolve_project_lockfile_path(resolved_project_root, lockfile_path)
	issues: list[str] = []
	registry_source = prepare_registry_source(registry_path, channel, resolved_project_root, cache_dir, issues)
	resolved_registry_path = registry_source["path"]
	resolved_cache_dir = registry_source["cache_dir"]
	if issues:
		return make_update_result(
			False,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			package_ids,
			all_installed,
			{},
			[],
			0,
			dry_run,
			False,
			False,
			issues,
			registry_source,
		)

	plan = gf_package_resolver.update_plan(
		registry_path=str(resolved_registry_path),
		lockfile_path=str(resolved_lockfile_path),
		package_ids=package_ids,
		all_installed=all_installed,
		write_lock=False,
		current_framework_version=read_project_framework_version(resolved_project_root),
	)
	plan = plan_with_registry_source(plan, registry_source)
	if not plan.get("ok"):
		return make_update_result(
			False,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			package_ids,
			all_installed,
			plan,
			[],
			0,
			dry_run,
			False,
			False,
			string_list(plan.get("issues", [])),
			registry_source,
		)

	registry = gf_package_resolver.load_registry(resolved_registry_path)
	lockfile = gf_package_resolver.load_lockfile(resolved_lockfile_path)
	issues.extend(string_list(registry.get("issues", [])))
	issues.extend(string_list(lockfile.get("issues", [])))
	to_change = set(string_list(plan.get("to_install", [])) + string_list(plan.get("to_update", [])))
	packages_to_change = [package_id for package_id in string_list(plan.get("install_order", [])) if package_id in to_change]
	packages_to_stage = [
		package_id
		for package_id in packages_to_change
		if package_requires_archive(registry["packages"].get(package_id, {}))
	]
	planned_lockfile = plan.get("planned_lockfile", {}) if isinstance(plan.get("planned_lockfile", {}), dict) else {}
	lockfile_changed = lockfile_data_changed(lockfile.get("data", {}), planned_lockfile)
	if issues:
		return make_update_result(
			False,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			package_ids,
			all_installed,
			plan,
			packages_to_change,
			0,
			dry_run,
			False,
			False,
			issues,
			registry_source,
		)
	if not packages_to_change:
		if dry_run or not lockfile_changed:
			return make_update_result(
				True,
				resolved_registry_path,
				resolved_project_root,
				resolved_lockfile_path,
				package_ids,
				all_installed,
				plan,
				[],
				0,
				dry_run,
				False,
				False,
				[],
				registry_source,
			)
		try:
			write_lockfile_last(resolved_lockfile_path, planned_lockfile)
		except Exception as error:
			issues.append(f"Could not write package lockfile: {error}")
			return make_update_result(
				False,
				resolved_registry_path,
				resolved_project_root,
				resolved_lockfile_path,
				package_ids,
				all_installed,
				plan,
				[],
				0,
				False,
				False,
				False,
				issues,
				registry_source,
			)
		return make_update_result(
			True,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			package_ids,
			all_installed,
			plan,
			[],
			0,
			False,
			False,
			True,
			[],
			registry_source,
		)

	with tempfile.TemporaryDirectory(prefix="gf-package-update-") as temp_dir:
		temp_root = Path(temp_dir)
		staging_root = temp_root / "staging"
		backup_root = temp_root / "backup"
		staged_files = stage_package_archives(
			packages_to_stage,
			registry["packages"],
			resolved_registry_path,
			resolved_cache_dir,
			staging_root,
			issues,
		)
		if issues:
			return make_update_result(
				False,
				resolved_registry_path,
				resolved_project_root,
				resolved_lockfile_path,
				package_ids,
				all_installed,
				plan,
				packages_to_change,
				0,
				dry_run,
				False,
				False,
				issues,
				registry_source,
			)
		if dry_run:
			return make_update_result(
				True,
				resolved_registry_path,
				resolved_project_root,
				resolved_lockfile_path,
				package_ids,
				all_installed,
				plan,
				packages_to_change,
				0,
				True,
				False,
				False,
				[],
				registry_source,
			)
		planned_lockfile = lockfile_with_installed_files(planned_lockfile, staged_files)
		try:
			updated_file_count = copy_staged_files_to_project(
				staged_files,
				resolved_project_root,
				resolved_lockfile_path,
				planned_lockfile,
				backup_root,
				simulate_copy_failure_after,
			)
		except InstallFailure as error:
			issues.append(str(error))
			return make_update_result(
				False,
				resolved_registry_path,
				resolved_project_root,
				resolved_lockfile_path,
				package_ids,
				all_installed,
				plan,
				packages_to_change,
				0,
				False,
				True,
				False,
				issues,
				registry_source,
			)
		return make_update_result(
			True,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			package_ids,
			all_installed,
			plan,
			packages_to_change,
			updated_file_count,
			False,
			False,
			True,
			[],
			registry_source,
		)


def uninstall_packages(
	package_ids: list[str],
	registry_path: str,
	channel: str,
	project_root: str,
	lockfile_path: str,
	cache_dir: str,
	force: bool,
	dry_run: bool,
	simulate_delete_failure_after: int = 0,
) -> dict[str, Any]:
	resolved_project_root = resolve_tool_path(project_root)
	resolved_lockfile_path = resolve_project_lockfile_path(resolved_project_root, lockfile_path)
	issues: list[str] = []
	registry_source = prepare_registry_source(registry_path, channel, resolved_project_root, cache_dir, issues)
	resolved_registry_path = registry_source["path"]
	resolved_cache_dir = registry_source["cache_dir"]
	if issues:
		return make_uninstall_result(
			False,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			package_ids,
			{},
			[],
			0,
			0,
			dry_run,
			force,
			False,
			issues,
			registry_source,
		)
	plan = gf_package_resolver.uninstall_plan(
		registry_path=str(resolved_registry_path),
		lockfile_path=str(resolved_lockfile_path),
		package_ids=package_ids,
		project_root=str(resolved_project_root),
		force=force,
		write_lock=False,
	)
	if not plan.get("ok"):
		return make_uninstall_result(
			False,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			package_ids,
			plan,
			[],
			0,
			0,
			dry_run,
			force,
			False,
			string_list(plan.get("issues", [])),
			registry_source,
		)

	registry = gf_package_resolver.load_registry(resolved_registry_path)
	lockfile = gf_package_resolver.load_lockfile(resolved_lockfile_path)
	issues.extend(string_list(registry.get("issues", [])))
	issues.extend(string_list(lockfile.get("issues", [])))
	to_remove = string_list(plan.get("to_remove", []))
	if issues:
		return make_uninstall_result(
			False,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			package_ids,
			plan,
			to_remove,
			0,
			0,
			dry_run,
			force,
			False,
			issues,
			registry_source,
		)
	if not to_remove:
		return make_uninstall_result(
			True,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			package_ids,
			plan,
			[],
			0,
			0,
			dry_run,
			force,
			False,
			[],
			registry_source,
		)

	targets = collect_uninstall_targets(
		to_remove,
		lockfile["data"],
		registry["packages"],
		resolved_project_root,
		issues,
	)
	if issues:
		return make_uninstall_result(
			False,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			package_ids,
			plan,
			to_remove,
			len(targets),
			0,
			dry_run,
			force,
			False,
			issues,
			registry_source,
		)
	if dry_run:
		return make_uninstall_result(
			True,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			package_ids,
			plan,
			to_remove,
			len(targets),
			0,
			True,
			force,
			False,
			[],
			registry_source,
		)

	with tempfile.TemporaryDirectory(prefix="gf-package-uninstall-") as temp_dir:
		backup_root = Path(temp_dir) / "backup"
		try:
			removed_file_count = delete_package_files_from_project(
				targets,
				resolved_project_root,
				resolved_lockfile_path,
				plan["planned_lockfile"],
				backup_root,
				simulate_delete_failure_after,
			)
		except InstallFailure as error:
			issues.append(str(error))
			return make_uninstall_result(
				False,
				resolved_registry_path,
				resolved_project_root,
				resolved_lockfile_path,
				package_ids,
				plan,
				to_remove,
				len(targets),
				0,
				False,
				force,
				True,
				issues,
				registry_source,
			)
		return make_uninstall_result(
			True,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			package_ids,
			plan,
			to_remove,
			len(targets),
			removed_file_count,
			False,
			force,
			False,
			[],
			registry_source,
		)


def package_status(
	registry_path: str,
	channel: str,
	project_root: str,
	lockfile_path: str,
	cache_dir: str,
) -> dict[str, Any]:
	resolved_project_root = resolve_tool_path(project_root)
	resolved_lockfile_path = resolve_project_lockfile_path(resolved_project_root, lockfile_path)
	issues: list[str] = []
	registry_source = prepare_registry_source(registry_path, channel, resolved_project_root, cache_dir, issues)
	resolved_registry_path = registry_source["path"]
	if issues:
		return make_status_result(
			False,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			bool(registry_source.get("remote", False)),
			[],
			[],
			{"ok": False, "issues": issues},
			issues,
			registry_source,
		)

	registry = gf_package_resolver.load_registry(resolved_registry_path)
	lockfile = gf_package_resolver.load_lockfile(resolved_lockfile_path)
	issues.extend(string_list(registry.get("issues", [])))
	issues.extend(string_list(lockfile.get("issues", [])))
	registry_packages = registry.get("packages", {})
	if not isinstance(registry_packages, dict):
		registry_packages = {}
	current_framework_version = read_project_framework_version(resolved_project_root)
	issues.extend(gf_package_resolver.framework_compatibility_issues(
		registry,
		registry_packages,
		sorted(str(package_id) for package_id in registry_packages.keys()),
		current_framework_version,
	))
	lockfile_data = lockfile.get("data", {})
	installed = lockfile_data.get("installed", {}) if isinstance(lockfile_data, dict) else {}
	if not isinstance(installed, dict):
		installed = {}

	verify_data: dict[str, Any] = {"ok": False, "issues": []}
	if not issues:
		verify_data = gf_package_resolver.verify_lock(
			registry_path=str(resolved_registry_path),
			lockfile_path=str(resolved_lockfile_path),
		)
		issues.extend(string_list(verify_data.get("issues", [])))
		file_list_issues = installed_file_list_issues(installed, registry_packages)
		if file_list_issues:
			verify_issues = string_list(verify_data.get("issues", []))
			verify_issues.extend(file_list_issues)
			verify_data = {**verify_data, "ok": False, "issues": verify_issues}
			issues.extend(file_list_issues)

	package_entries: list[dict[str, Any]] = []
	for package_id in sorted(registry_packages.keys()):
		registry_entry = registry_packages.get(package_id, {})
		if not isinstance(registry_entry, dict):
			continue
		lock_entry = installed.get(package_id, {})
		if not isinstance(lock_entry, dict):
			lock_entry = {}
		package_entries.append(make_status_package_entry(
			package_id,
			registry_entry,
			lock_entry,
			resolved_registry_path,
			resolved_lockfile_path,
			resolved_project_root,
			current_framework_version,
		))
	orphan_packages = sorted(package_id for package_id in installed.keys() if package_id not in registry_packages)
	return make_status_result(
		len(issues) == 0,
		resolved_registry_path,
		resolved_project_root,
		resolved_lockfile_path,
		bool(registry_source.get("remote", False)),
		package_entries,
		orphan_packages,
		{"ok": bool(verify_data.get("ok")), "issues": string_list(verify_data.get("issues", []))},
		issues,
		registry_source,
	)


def installed_file_list_issues(installed: dict[str, Any], registry_packages: dict[str, Any]) -> list[str]:
	issues: list[str] = []
	for package_id in sorted(installed.keys()):
		lock_entry = installed.get(package_id, {})
		registry_entry = registry_packages.get(package_id, {})
		if not isinstance(lock_entry, dict) or not isinstance(registry_entry, dict):
			continue
		if str(registry_entry.get("kind", "")) == "preset":
			continue
		if not string_list(lock_entry.get("files", [])):
			issues.append(f"Installed package lockfile entry is missing files list: {package_id}")
	return issues


def make_status_package_entry(
	package_id: str,
	registry_entry: dict[str, Any],
	lock_entry: dict[str, Any],
	registry_path: Path,
	lockfile_path: Path,
	project_root: Path,
	current_framework_version: str,
) -> dict[str, Any]:
	installed = bool(lock_entry)
	install_preview = gf_package_resolver.install_plan(
		registry_path=str(registry_path),
		lockfile_path=str(lockfile_path),
		package_ids=[package_id],
		reason="manual",
		write_lock=False,
		current_framework_version=current_framework_version,
	)
	uninstall_preview: dict[str, Any] = {}
	if installed:
		uninstall_preview = gf_package_resolver.uninstall_plan(
			registry_path=str(registry_path),
			lockfile_path=str(lockfile_path),
			package_ids=[package_id],
			project_root=str(project_root),
			force=False,
			write_lock=False,
		)
	return {
		"id": package_id,
		"kind": str(registry_entry.get("kind", "")),
		"version": str(registry_entry.get("version", "")),
		"display_name": str(registry_entry.get("display_name", "")),
		"description": str(registry_entry.get("description", "")),
		"dependencies": string_list(registry_entry.get("dependencies", [])),
		"packages": string_list(registry_entry.get("packages", [])),
		"paths": string_list(registry_entry.get("paths", [])),
		"enable_extension": str(registry_entry.get("enable_extension", "")),
		"installed": installed,
		"reason": string_list(lock_entry.get("reason", [])),
		"required_by": string_list(lock_entry.get("required_by", [])),
		"file_count": len(string_list(lock_entry.get("files", []))),
		"can_install": bool(install_preview.get("ok")),
		"install_preview": compact_install_preview(install_preview),
		"can_uninstall": bool(uninstall_preview.get("ok")) if installed else False,
		"uninstall_preview": compact_uninstall_preview(uninstall_preview) if installed else {},
	}


def compact_install_preview(plan: dict[str, Any]) -> dict[str, Any]:
	return {
		"ok": bool(plan.get("ok")),
		"install_order": string_list(plan.get("install_order", [])),
		"to_install": string_list(plan.get("to_install", [])),
		"to_update": string_list(plan.get("to_update", [])),
		"issues": string_list(plan.get("issues", [])),
	}


def compact_uninstall_preview(plan: dict[str, Any]) -> dict[str, Any]:
	return {
		"ok": bool(plan.get("ok")),
		"to_remove": string_list(plan.get("to_remove", [])),
		"blocked": plan.get("blocked", []) if isinstance(plan.get("blocked", []), list) else [],
		"issues": string_list(plan.get("issues", [])),
	}


def plan_with_registry_source(plan: dict[str, Any], registry_source: dict[str, Any]) -> dict[str, Any]:
	result = copy.deepcopy(plan)
	planned_lockfile = result.get("planned_lockfile", {})
	if not isinstance(planned_lockfile, dict):
		return result
	source_info = gf_package_resolver.make_lockfile_registry_source(planned_lockfile, registry_source)
	if source_info:
		planned_lockfile["registry_source"] = source_info
	result["planned_lockfile"] = planned_lockfile
	return result


def lockfile_with_installed_files(planned_lockfile: dict[str, Any], staged_files: list[dict[str, Any]]) -> dict[str, Any]:
	lockfile = copy.deepcopy(planned_lockfile)
	installed = lockfile.get("installed", {})
	if not isinstance(installed, dict):
		return lockfile
	files_by_package: dict[str, list[str]] = {}
	for item in staged_files:
		package_id = str(item.get("package_id", ""))
		relative_path = str(item.get("relative_path", ""))
		if not package_id or not relative_path:
			continue
		files_by_package.setdefault(package_id, [])
		if relative_path not in files_by_package[package_id]:
			files_by_package[package_id].append(relative_path)
	for package_id, files in files_by_package.items():
		entry = installed.get(package_id)
		if isinstance(entry, dict):
			entry["files"] = sorted(files)
	return lockfile


def stage_package_archives(
	package_ids: list[str],
	registry_packages: dict[str, dict[str, Any]],
	registry_path: Path,
	cache_root: Path,
	staging_root: Path,
	issues: list[str],
) -> list[dict[str, Any]]:
	staged_files: list[dict[str, Any]] = []
	for package_id in package_ids:
		entry = registry_packages.get(package_id)
		if not isinstance(entry, dict):
			issues.append(f"{package_id}: missing registry package entry.")
			continue
		archive_path = resolve_archive_path(str(entry.get("archive", "")), registry_path, cache_root, package_id, entry, issues)
		if archive_path is None:
			continue
		package_issues = audit_package_archive(package_id, entry, archive_path)
		if package_issues:
			issues.extend(package_issues)
			continue
		with zipfile.ZipFile(archive_path, "r") as archive:
			for name in sorted(name for name in archive.namelist() if name and not name.endswith("/")):
				staged_path = staging_root / package_id / Path(*name.split("/"))
				staged_path.parent.mkdir(parents=True, exist_ok=True)
				staged_path.write_bytes(archive.read(name))
				staged_files.append({
					"package_id": package_id,
					"relative_path": name,
					"staged_path": staged_path,
				})
	return staged_files


def package_requires_archive(entry: Any) -> bool:
	if not isinstance(entry, dict):
		return True
	return not package_is_preset(entry)


def package_is_preset(entry: dict[str, Any]) -> bool:
	return str(entry.get("kind", "")) == "preset"


def audit_package_archive(package_id: str, entry: dict[str, Any], archive_path: Path) -> list[str]:
	issues: list[str] = []
	if not archive_path.is_file():
		return [f"{package_id}: archive is missing: {archive_path.as_posix()}"]
	expected_size = int_value(entry.get("size_bytes", 0))
	if expected_size > 0 and archive_path.stat().st_size != expected_size:
		issues.append(f"{package_id}: archive size does not match registry size_bytes.")
	expected_sha = str(entry.get("sha256", "")).strip()
	if expected_sha and sha256_file(archive_path) != expected_sha:
		issues.append(f"{package_id}: archive sha256 does not match registry sha256.")
	if issues:
		return issues
	try:
		with zipfile.ZipFile(archive_path, "r") as archive:
			names = [name for name in archive.namelist() if name and not name.endswith("/")]
	except zipfile.BadZipFile as error:
		return [f"{package_id}: invalid zip archive: {error}"]
	seen: set[str] = set()
	for name in names:
		normalized = normalize_archive_name(name)
		if not normalized:
			issues.append(f"{package_id}: unsafe archive entry path: {name}")
			continue
		if normalized in seen:
			issues.append(f"{package_id}: duplicate archive entry path: {normalized}")
			continue
		seen.add(normalized)
		if not normalized.startswith("addons/gf/"):
			issues.append(f"{package_id}: archive entry is outside addons/gf: {normalized}")
		if not path_matches_any_manifest_path(normalized, string_array(entry.get("paths", []))):
			issues.append(f"{package_id}: archive entry is not covered by registry paths: {normalized}")
		parts = normalized.split("/")
		if any(part in BLOCKED_DIR_NAMES for part in parts):
			issues.append(f"{package_id}: archive entry contains blocked directory: {normalized}")
		if Path(normalized).name in BLOCKED_FILE_NAMES or Path(normalized).suffix in BLOCKED_SUFFIXES:
			issues.append(f"{package_id}: archive entry contains blocked generated file: {normalized}")
		if runtime_package_has_external_tool_payload(package_id, entry, normalized):
			issues.append(f"{package_id}: runtime package archive contains external tool payload: {normalized}")
	return issues


def runtime_package_has_external_tool_payload(package_id: str, entry: dict[str, Any], relative_path: str) -> bool:
	if package_id.startswith("gf.tool.") or str(entry.get("kind", "")) == "tool":
		return False
	path = Path(relative_path)
	return (
		path.name.lower() in RUNTIME_PACKAGE_FORBIDDEN_EXTERNAL_TOOL_FILES
		or path.suffix.lower() in RUNTIME_PACKAGE_FORBIDDEN_EXTERNAL_TOOL_SUFFIXES
	)


def collect_uninstall_targets(
	package_ids: list[str],
	lockfile: dict[str, Any],
	registry_packages: dict[str, dict[str, Any]],
	project_root: Path,
	issues: list[str],
) -> list[dict[str, Any]]:
	targets: list[dict[str, Any]] = []
	seen_paths: set[str] = set()
	installed = lockfile.get("installed", {})
	if not isinstance(installed, dict):
		issues.append("Lockfile installed must be an object.")
		return []
	removing = set(package_ids)
	for package_id in package_ids:
		lock_entry = installed.get(package_id)
		if not isinstance(lock_entry, dict):
			issues.append(f"{package_id}: package is not installed in the current lockfile.")
			continue
		registry_entry = registry_packages.get(package_id, {})
		if package_is_preset(lock_entry) or (isinstance(registry_entry, dict) and package_is_preset(registry_entry)):
			continue
		patterns = string_array(lock_entry.get("paths", [])) or string_array(registry_entry.get("paths", []))
		file_paths = string_array(lock_entry.get("files", []))
		if not file_paths:
			issues.append(f"{package_id}: lockfile entry is missing the installed files list; reinstall or repair the package before uninstalling.")
			continue
		for relative_path in file_paths:
			normalized = normalize_archive_name(relative_path)
			if not normalized:
				issues.append(f"{package_id}: unsafe installed file path in lockfile: {relative_path}")
				continue
			if not normalized.startswith("addons/gf/"):
				issues.append(f"{package_id}: uninstall target is outside addons/gf: {normalized}")
				continue
			if not path_matches_any_manifest_path(normalized, patterns):
				issues.append(f"{package_id}: uninstall target is not covered by package paths: {normalized}")
				continue
			remaining_owner = remaining_package_owner(normalized, installed, registry_packages, removing)
			if remaining_owner:
				issues.append(f"{package_id}: uninstall target is still owned by installed package {remaining_owner}: {normalized}")
				continue
			if normalized in seen_paths:
				continue
			seen_paths.add(normalized)
			targets.append({
				"package_id": package_id,
				"relative_path": normalized,
				"target_path": project_target_path(project_root, normalized),
			})
	return sorted(targets, key=lambda item: str(item["relative_path"]))


def remaining_package_owner(
	relative_path: str,
	installed: dict[str, Any],
	registry_packages: dict[str, dict[str, Any]],
	removing: set[str],
) -> str:
	for package_id, lock_entry in installed.items():
		if package_id in removing or not isinstance(lock_entry, dict):
			continue
		registry_entry = registry_packages.get(package_id, {})
		patterns = string_array(lock_entry.get("paths", [])) or string_array(registry_entry.get("paths", []))
		if path_matches_any_manifest_path(relative_path, patterns):
			return str(package_id)
	return ""


def copy_staged_files_to_project(
	staged_files: list[dict[str, Any]],
	project_root: Path,
	lockfile_path: Path,
	planned_lockfile: dict[str, Any],
	backup_root: Path,
	simulate_copy_failure_after: int,
) -> int:
	project_root.mkdir(parents=True, exist_ok=True)
	created_files: list[Path] = []
	created_dirs: list[Path] = []
	backups: list[dict[str, Path]] = []
	copied_count = 0
	try:
		for item in staged_files:
			relative_path = str(item["relative_path"])
			target_path = project_target_path(project_root, relative_path)
			make_parent_dirs(target_path.parent, project_root, created_dirs)
			if target_path.exists():
				if target_path.is_dir():
					raise InstallFailure(f"Cannot overwrite directory with package file: {target_path.as_posix()}")
				backup_path = backup_root / Path(*relative_path.split("/"))
				backup_path.parent.mkdir(parents=True, exist_ok=True)
				shutil.copy2(target_path, backup_path)
				backups.append({"target": target_path, "backup": backup_path})
			else:
				created_files.append(target_path)
			shutil.copy2(item["staged_path"], target_path)
			copied_count += 1
			if simulate_copy_failure_after > 0 and copied_count >= simulate_copy_failure_after:
				raise InstallFailure("Simulated package install copy failure.")
		write_lockfile_last(lockfile_path, planned_lockfile)
		return copied_count
	except Exception as error:
		rollback_files(created_files, backups, created_dirs)
		if isinstance(error, InstallFailure):
			raise
		raise InstallFailure(f"Package install failed and was rolled back: {error}") from error


def delete_package_files_from_project(
	targets: list[dict[str, Any]],
	project_root: Path,
	lockfile_path: Path,
	planned_lockfile: dict[str, Any],
	backup_root: Path,
	simulate_delete_failure_after: int,
) -> int:
	backups: list[dict[str, Path]] = []
	touched_dirs: list[Path] = []
	deleted_count = 0
	try:
		for item in targets:
			relative_path = str(item["relative_path"])
			target_path = item["target_path"]
			if not isinstance(target_path, Path):
				raise InstallFailure(f"Invalid uninstall target path: {relative_path}")
			if not target_path.exists():
				continue
			if target_path.is_dir():
				raise InstallFailure(f"Refusing to delete directory as a package file: {target_path.as_posix()}")
			backup_path = backup_root / Path(*relative_path.split("/"))
			backup_path.parent.mkdir(parents=True, exist_ok=True)
			shutil.copy2(target_path, backup_path)
			backups.append({"target": target_path, "backup": backup_path})
			target_path.unlink()
			deleted_count += 1
			append_unique_path(touched_dirs, target_path.parent)
			if simulate_delete_failure_after > 0 and deleted_count >= simulate_delete_failure_after:
				raise InstallFailure("Simulated package uninstall delete failure.")
		remove_empty_project_dirs(touched_dirs, project_root)
		write_lockfile_last(lockfile_path, planned_lockfile)
		return deleted_count
	except Exception as error:
		restore_deleted_files(backups)
		if isinstance(error, InstallFailure):
			raise
		raise InstallFailure(f"Package uninstall failed and was rolled back: {error}") from error


def write_lockfile_last(lockfile_path: Path, planned_lockfile: dict[str, Any]) -> None:
	lockfile_path.parent.mkdir(parents=True, exist_ok=True)
	temp_path = lockfile_path.with_name(lockfile_path.name + ".tmp")
	temp_path.write_text(json.dumps(planned_lockfile, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
	temp_path.replace(lockfile_path)


def rollback_files(created_files: list[Path], backups: list[dict[str, Path]], created_dirs: list[Path]) -> None:
	for path in reversed(created_files):
		if path.is_file():
			path.unlink()
	for item in reversed(backups):
		target = item["target"]
		backup = item["backup"]
		if backup.is_file():
			target.parent.mkdir(parents=True, exist_ok=True)
			shutil.copy2(backup, target)
	for directory in reversed(created_dirs):
		try:
			directory.rmdir()
		except OSError:
			pass


def restore_deleted_files(backups: list[dict[str, Path]]) -> None:
	for item in reversed(backups):
		target = item["target"]
		backup = item["backup"]
		if backup.is_file():
			target.parent.mkdir(parents=True, exist_ok=True)
			shutil.copy2(backup, target)


def remove_empty_project_dirs(directories: list[Path], project_root: Path) -> None:
	project_root_resolved = project_root.resolve()
	stop_dir = (project_root / "addons").resolve(strict=False)
	for directory in sorted(directories, key=lambda path: len(path.parts), reverse=True):
		current = directory
		while current != current.parent:
			resolved = current.resolve(strict=False)
			if not resolved.is_relative_to(project_root_resolved):
				break
			if resolved == project_root_resolved or resolved == stop_dir.parent.resolve(strict=False):
				break
			try:
				current.rmdir()
			except OSError:
				break
			if resolved == stop_dir:
				break
			current = current.parent


def append_unique_path(items: list[Path], path: Path) -> None:
	if path not in items:
		items.append(path)


def make_parent_dirs(parent: Path, project_root: Path, created_dirs: list[Path]) -> None:
	missing: list[Path] = []
	current = parent
	project_root_resolved = project_root.resolve()
	while not current.exists():
		resolved = current.resolve(strict=False)
		if not resolved.is_relative_to(project_root_resolved):
			raise InstallFailure(f"Refusing to create directory outside project root: {current.as_posix()}")
		missing.append(current)
		if current == current.parent:
			break
		current = current.parent
	for directory in reversed(missing):
		directory.mkdir()
		created_dirs.append(directory)


def prepare_registry_source(
	registry_value: str,
	channel: str,
	project_root: Path,
	cache_dir: str,
	issues: list[str],
) -> dict[str, Any]:
	cache_root = resolve_cache_dir(project_root, cache_dir)
	registry = registry_value.strip()
	source_issues: list[str] = []
	source = prepare_registry_candidate(registry, project_root, cache_root, source_issues)
	if source_issues:
		issues.extend(source_issues)
		return source
	if registry_file_is_source_manifest(source["path"]):
		return prepare_registry_source_channel(source, channel, project_root, cache_root, issues)
	return source


def prepare_registry_candidate(
	registry_value: str,
	project_root: Path,
	cache_root: Path,
	issues: list[str],
	expected_sha: str = "",
	expected_size: int = 0,
) -> dict[str, Any]:
	registry = registry_value.strip()
	if is_remote_url(registry):
		cache_path = cache_root / "registries" / f"{sha256_text(registry)}.json"
		raw_path = cache_path.with_name(cache_path.name + ".raw")
		if not download_url_to_file(registry, raw_path, "registry", issues, MAX_REGISTRY_DOWNLOAD_BYTES):
			return {"path": cache_path, "cache_dir": cache_root, "remote": True, "source": registry}
		if not registry_file_matches_metadata(raw_path, expected_sha, expected_size, issues):
			try_unlink(raw_path)
			return {"path": cache_path, "cache_dir": cache_root, "remote": True, "source": registry}
		rewrite_remote_registry(raw_path, cache_path, registry, issues)
		try_unlink(raw_path)
		return {"path": cache_path.resolve(), "cache_dir": cache_root, "remote": True, "source": registry}
	registry_path = resolve_tool_path(registry_value)
	registry_file_matches_metadata(registry_path, expected_sha, expected_size, issues)
	return {"path": registry_path, "cache_dir": cache_root, "remote": False, "source": registry_value}


def registry_file_is_source_manifest(path: Path) -> bool:
	try:
		data = json.loads(path.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError):
		return False
	return isinstance(data, dict) and isinstance(data.get("channels"), dict)


def prepare_registry_source_channel(
	source: dict[str, Any],
	channel: str,
	project_root: Path,
	cache_root: Path,
	issues: list[str],
) -> dict[str, Any]:
	source_path = Path(source["path"])
	try:
		data = json.loads(source_path.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
		issues.append(f"Could not parse registry source manifest: {error}")
		return source
	source_issues = validate_registry_source_manifest(data)
	if source_issues:
		issues.extend(source_issues)
		return source
	selected_channel = channel.strip() or str(data.get("default_channel", "")).strip()
	channels = data.get("channels", {})
	channel_entry = channels.get(selected_channel, {}) if isinstance(channels, dict) else {}
	if not isinstance(channel_entry, dict):
		issues.append(f"Registry source channel is missing: {selected_channel}")
		return source
	candidates = [str(channel_entry.get("registry", "")).strip(), *string_list(channel_entry.get("mirrors", []))]
	expected_sha = str(channel_entry.get("registry_sha256", "")).strip().lower()
	expected_size = int_value(channel_entry.get("registry_size_bytes", 0))
	candidate_errors: list[str] = []
	for index, candidate in enumerate(candidate for candidate in candidates if candidate):
		resolved_candidate = resolve_registry_source_reference(candidate, source, source_path, project_root)
		candidate_issues: list[str] = []
		result = prepare_registry_candidate(
			resolved_candidate,
			project_root,
			cache_root,
			candidate_issues,
			expected_sha,
			expected_size,
		)
		if not candidate_issues:
			result["registry_source_manifest"] = str(source.get("source", "")).strip()
			result["channel"] = selected_channel
			result["mirror_index"] = index - 1
			if expected_sha:
				result["registry_sha256"] = expected_sha
			if expected_size > 0:
				result["registry_size_bytes"] = expected_size
			return result
		candidate_errors.extend(candidate_issues)
	issues.extend(candidate_errors)
	return source


def validate_registry_source_manifest(data: Any) -> list[str]:
	issues: list[str] = []
	if not isinstance(data, dict):
		return ["Registry source manifest root must be an object."]
	issues.extend(registry_source_signature_issues(data))
	if data.get("schema_version") != 1:
		issues.append("Registry source manifest schema_version must be 1.")
	default_channel = str(data.get("default_channel", "")).strip()
	if not default_channel:
		issues.append("Registry source manifest default_channel is required.")
	channels = data.get("channels", {})
	if not isinstance(channels, dict) or not channels:
		issues.append("Registry source manifest channels must be a non-empty object.")
		return issues
	if default_channel and default_channel not in channels:
		issues.append(f"Registry source default_channel is missing from channels: {default_channel}")
	for channel_name, channel_entry in channels.items():
		if not isinstance(channel_name, str) or not channel_name.strip():
			issues.append("Registry source channel names must be non-empty strings.")
			continue
		if not isinstance(channel_entry, dict):
			issues.append(f"Registry source channel must be an object: {channel_name}")
			continue
		if not str(channel_entry.get("registry", "")).strip():
			issues.append(f"Registry source channel registry is required: {channel_name}")
		expected_sha = str(channel_entry.get("registry_sha256", "")).strip().lower()
		if expected_sha and not is_sha256_hex(expected_sha):
			issues.append(f"Registry source channel registry_sha256 must be a sha256 hex digest: {channel_name}")
		raw_size = channel_entry.get("registry_size_bytes", 0)
		if raw_size not in (None, "") and not is_non_negative_int_value(raw_size):
			issues.append(f"Registry source channel registry_size_bytes must be a non-negative integer: {channel_name}")
		mirrors = channel_entry.get("mirrors", [])
		if mirrors is not None and not isinstance(mirrors, list):
			issues.append(f"Registry source channel mirrors must be an array: {channel_name}")
		elif isinstance(mirrors, list):
			for mirror in mirrors:
				if not isinstance(mirror, str) or not mirror.strip():
					issues.append(f"Registry source mirror entries must be non-empty strings: {channel_name}")
	return issues


def registry_source_signature_issues(data: dict[str, Any]) -> list[str]:
	issues: list[str] = []
	for field_name in sorted(UNSUPPORTED_REGISTRY_SOURCE_SIGNATURE_FIELDS.intersection(data)):
		issues.append(
			"Registry source manifest signature field is not supported until native verification is implemented: "
			f"{field_name}"
		)
	channels = data.get("channels", {})
	if not isinstance(channels, dict):
		return issues
	for channel_name, channel_entry in channels.items():
		if not isinstance(channel_entry, dict):
			continue
		for field_name in sorted(UNSUPPORTED_REGISTRY_SOURCE_SIGNATURE_FIELDS.intersection(channel_entry)):
			issues.append(
				"Registry source channel signature field is not supported until native verification is implemented: "
				f"{channel_name}.{field_name}"
			)
	return issues


def resolve_registry_source_reference(
	value: str,
	source: dict[str, Any],
	source_path: Path,
	project_root: Path,
) -> str:
	if is_remote_url(value):
		return value
	source_value = str(source.get("source", "")).strip()
	if is_remote_url(source_value):
		return urllib.parse.urljoin(source_value, value)
	path = Path(value)
	if path.is_absolute():
		return path.as_posix()
	if value.startswith("res://") or value.startswith("user://"):
		return value
	return (source_path.parent / path).resolve().as_posix()


def rewrite_remote_registry(raw_path: Path, cache_path: Path, registry_url: str, issues: list[str]) -> None:
	try:
		data = json.loads(raw_path.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
		issues.append(f"Could not parse downloaded registry: {error}")
		return
	if not isinstance(data, dict):
		issues.append("Downloaded registry root must be an object.")
		return
	packages = data.get("packages", {})
	if isinstance(packages, dict):
		for entry in packages.values():
			if not isinstance(entry, dict):
				continue
			archive = str(entry.get("archive", "")).strip()
			if archive and not is_remote_url(archive) and not Path(archive).is_absolute():
				entry["archive"] = urllib.parse.urljoin(registry_url, archive)
	cache_path.parent.mkdir(parents=True, exist_ok=True)
	cache_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def resolve_cache_dir(project_root: Path, cache_dir: str) -> Path:
	if cache_dir.strip():
		path = Path(cache_dir)
		if not path.is_absolute():
			path = ROOT / path
		return path.resolve()
	return (project_root / ".gf/package_cache").resolve()


def resolve_archive_path(
	archive_value: str,
	registry_path: Path,
	cache_root: Path,
	package_id: str,
	entry: dict[str, Any],
	issues: list[str],
) -> Path | None:
	archive = archive_value.strip()
	if not archive:
		return registry_path.parent / ""
	if is_remote_url(archive):
		return cache_remote_archive(package_id, archive, entry, cache_root, issues)
	path = Path(archive)
	if path.is_absolute():
		return path
	return (registry_path.parent / path).resolve()


def cache_remote_archive(
	package_id: str,
	archive_url: str,
	entry: dict[str, Any],
	cache_root: Path,
	issues: list[str],
) -> Path | None:
	expected_sha = str(entry.get("sha256", "")).strip()
	expected_size = int_value(entry.get("size_bytes", 0))
	if not expected_sha:
		issues.append(f"{package_id}: remote archive requires sha256 in the registry.")
		return None
	if expected_size <= 0:
		issues.append(f"{package_id}: remote archive requires positive size_bytes in the registry.")
		return None
	archive_path = cache_root / "archives" / f"{safe_cache_name(package_id)}-{expected_sha[:16]}.zip"
	if archive_path.is_file() and archive_file_matches_metadata(archive_path, expected_sha, expected_size):
		return archive_path
	if not download_url_to_file(
		archive_url,
		archive_path,
		f"{package_id} archive",
		issues,
		min(MAX_ARCHIVE_DOWNLOAD_BYTES, expected_size + 1),
	):
		return None
	return archive_path


def archive_file_matches_metadata(path: Path, expected_sha: str, expected_size: int) -> bool:
	if not path.is_file():
		return False
	if expected_size > 0 and path.stat().st_size != expected_size:
		return False
	if expected_sha and sha256_file(path) != expected_sha:
		return False
	return True


def registry_file_matches_metadata(path: Path, expected_sha: str, expected_size: int, issues: list[str]) -> bool:
	if not path.is_file():
		issues.append(f"registry: file is missing: {path.as_posix()}")
		return False
	if expected_size > 0 and path.stat().st_size != expected_size:
		issues.append("registry: registry size does not match registry source metadata.")
	if expected_sha and sha256_file(path) != expected_sha:
		issues.append("registry: registry sha256 does not match registry source metadata.")
	return not issues


def download_url_to_file(url: str, target_path: Path, label: str, issues: list[str], max_bytes: int) -> bool:
	target_path.parent.mkdir(parents=True, exist_ok=True)
	temp_path = target_path.with_name(target_path.name + ".download")
	request = urllib.request.Request(url, headers={"User-Agent": "GF-Package-Installer/1"})
	bytes_written = 0
	try:
		with urllib.request.urlopen(request, timeout=30) as response:
			content_length = response.headers.get("Content-Length", "")
			if content_length.isdigit() and int(content_length) > max_bytes:
				issues.append(f"{label}: remote file is larger than the allowed download limit.")
				return False
			with temp_path.open("wb") as handle:
				while True:
					chunk = response.read(1024 * 1024)
					if not chunk:
						break
					bytes_written += len(chunk)
					if bytes_written > max_bytes:
						issues.append(f"{label}: remote file exceeded the allowed download limit.")
						try_unlink(temp_path)
						return False
					handle.write(chunk)
		temp_path.replace(target_path)
		return True
	except (OSError, urllib.error.URLError, urllib.error.HTTPError) as error:
		try_unlink(temp_path)
		issues.append(f"{label}: download failed: {error}")
		return False


def is_remote_url(value: str) -> bool:
	return value.strip().lower().startswith(REMOTE_ARCHIVE_PREFIXES)


def safe_cache_name(value: str) -> str:
	return "".join(char if char.isalnum() or char in {"-", "_"} else "-" for char in value).strip("-") or "package"


def sha256_text(value: str) -> str:
	return hashlib.sha256(value.encode("utf-8")).hexdigest()


def is_sha256_hex(value: str) -> bool:
	return len(value) == 64 and all(char in "0123456789abcdefABCDEF" for char in value)


def is_non_negative_int_value(value: Any) -> bool:
	if isinstance(value, bool):
		return False
	if isinstance(value, int):
		return value >= 0
	if isinstance(value, str):
		return value.isdigit()
	return False


def try_unlink(path: Path) -> None:
	try:
		path.unlink()
	except OSError:
		pass


def project_target_path(project_root: Path, relative_path: str) -> Path:
	normalized = normalize_archive_name(relative_path)
	if not normalized:
		raise InstallFailure(f"Unsafe package target path: {relative_path}")
	target_path = project_root / Path(*normalized.split("/"))
	project_root_resolved = project_root.resolve()
	target_resolved = target_path.resolve(strict=False)
	if not target_resolved.is_relative_to(project_root_resolved):
		raise InstallFailure(f"Refusing to write outside project root: {relative_path}")
	return target_path


def normalize_archive_name(name: str) -> str:
	normalized = name.strip().replace("\\", "/")
	if not normalized or normalized.startswith("/") or ":" in normalized:
		return ""
	parts = normalized.split("/")
	if any(part in {"", ".", ".."} for part in parts):
		return ""
	return "/".join(parts)


def path_matches_any_manifest_path(path: str, patterns: list[str]) -> bool:
	for raw_pattern in patterns:
		pattern = normalize_manifest_path(raw_pattern)
		if pattern and fnmatch.fnmatch(path, pattern):
			return True
		if pattern.endswith("/**") and (path == pattern[:-3].rstrip("/") or path.startswith(pattern[:-3].rstrip("/") + "/")):
			return True
	return False


def normalize_manifest_path(path: str) -> str:
	normalized = path.strip().replace("\\", "/")
	if normalized.startswith("res://"):
		normalized = normalized.removeprefix("res://")
	if normalized.startswith("./"):
		normalized = normalized[2:]
	return normalized.strip("/")


def sha256_file(path: Path) -> str:
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for chunk in iter(lambda: handle.read(1024 * 1024), b""):
			digest.update(chunk)
	return digest.hexdigest()


def make_install_result(
	ok: bool,
	registry_path: Path,
	project_root: Path,
	lockfile_path: Path,
	requested_packages: list[str],
	plan: dict[str, Any],
	installed_packages: list[str],
	installed_file_count: int,
	dry_run: bool,
	rolled_back: bool,
	issues: list[str],
	registry_source: dict[str, Any] | None = None,
) -> dict[str, Any]:
	result = {
		"ok": ok,
		"operation": "install",
		"project_root": display_path(project_root),
		"registry": display_path(registry_path),
		"lockfile": display_path(lockfile_path),
		"requested_packages": requested_packages,
		"install_order": string_list(plan.get("install_order", [])),
		"to_install": string_list(plan.get("to_install", [])),
		"to_update": string_list(plan.get("to_update", [])),
		"installed_packages": installed_packages,
		"installed_file_count": installed_file_count,
		"lockfile_written": ok and not dry_run and bool(installed_packages),
		"dry_run": dry_run,
		"rolled_back": rolled_back,
		"issue_count": len(issues),
		"issues": issues,
	}
	append_registry_source_fields(result, registry_source or {})
	return result


def make_update_result(
	ok: bool,
	registry_path: Path,
	project_root: Path,
	lockfile_path: Path,
	requested_packages: list[str],
	all_installed: bool,
	plan: dict[str, Any],
	updated_packages: list[str],
	updated_file_count: int,
	dry_run: bool,
	rolled_back: bool,
	lockfile_written: bool,
	issues: list[str],
	registry_source: dict[str, Any] | None = None,
) -> dict[str, Any]:
	result = {
		"ok": ok,
		"operation": "update",
		"project_root": display_path(project_root),
		"registry": display_path(registry_path),
		"lockfile": display_path(lockfile_path),
		"requested_packages": requested_packages,
		"all_installed": all_installed,
		"install_order": string_list(plan.get("install_order", [])),
		"to_install": string_list(plan.get("to_install", [])),
		"to_update": string_list(plan.get("to_update", [])),
		"updated_packages": updated_packages,
		"installed_packages": updated_packages,
		"updated_file_count": updated_file_count,
		"installed_file_count": updated_file_count,
		"lockfile_written": lockfile_written and ok and not dry_run,
		"dry_run": dry_run,
		"rolled_back": rolled_back,
		"issue_count": len(issues),
		"issues": issues,
	}
	append_registry_source_fields(result, registry_source or {})
	return result


def make_uninstall_result(
	ok: bool,
	registry_path: Path,
	project_root: Path,
	lockfile_path: Path,
	requested_packages: list[str],
	plan: dict[str, Any],
	removed_packages: list[str],
	planned_file_count: int,
	removed_file_count: int,
	dry_run: bool,
	force: bool,
	rolled_back: bool,
	issues: list[str],
	registry_source: dict[str, Any] | None = None,
) -> dict[str, Any]:
	result = {
		"ok": ok,
		"operation": "uninstall",
		"project_root": display_path(project_root),
		"registry": display_path(registry_path),
		"lockfile": display_path(lockfile_path),
		"requested_packages": requested_packages,
		"to_remove": string_list(plan.get("to_remove", [])),
		"blocked": plan.get("blocked", []) if isinstance(plan.get("blocked", []), list) else [],
		"removed_packages": removed_packages,
		"planned_file_count": planned_file_count,
		"removed_file_count": removed_file_count,
		"lockfile_written": ok and not dry_run and bool(removed_packages),
		"dry_run": dry_run,
		"force": force,
		"rolled_back": rolled_back,
		"issue_count": len(issues),
		"issues": issues,
		"planned_lockfile": plan.get("planned_lockfile", {}),
	}
	append_registry_source_fields(result, registry_source or {})
	return result


def make_status_result(
	ok: bool,
	registry_path: Path,
	project_root: Path,
	lockfile_path: Path,
	registry_remote: bool,
	packages: list[dict[str, Any]],
	orphan_packages: list[str],
	lockfile_verify: dict[str, Any],
	issues: list[str],
	registry_source: dict[str, Any] | None = None,
) -> dict[str, Any]:
	installed_count = len([item for item in packages if item.get("installed")])
	kind_counts: dict[str, int] = {}
	for item in packages:
		kind = str(item.get("kind", ""))
		kind_counts[kind] = kind_counts.get(kind, 0) + 1
	result = {
		"ok": ok,
		"operation": "status",
		"project_root": display_path(project_root),
		"registry": display_path(registry_path),
		"registry_remote": registry_remote,
		"lockfile": display_path(lockfile_path),
		"package_count": len(packages),
		"installed_count": installed_count,
		"available_count": len(packages) - installed_count,
		"kind_counts": [{"kind": key, "count": kind_counts[key]} for key in sorted(kind_counts.keys())],
		"orphan_packages": orphan_packages,
		"lockfile_verify": lockfile_verify,
		"issue_count": len(issues),
		"issues": issues,
		"packages": packages,
	}
	append_registry_source_fields(result, registry_source or {})
	return result


def append_registry_source_fields(result: dict[str, Any], registry_source: dict[str, Any]) -> None:
	if not registry_source:
		return
	result["registry_remote"] = bool(registry_source.get("remote", False))
	source_value = str(registry_source.get("source", "")).strip()
	if source_value:
		result["registry_source"] = source_value
	manifest_value = str(registry_source.get("registry_source_manifest", "")).strip()
	if manifest_value:
		result["registry_source_manifest"] = manifest_value
	channel_value = str(registry_source.get("channel", "")).strip()
	if channel_value:
		result["registry_channel"] = channel_value
	if "mirror_index" in registry_source:
		result["registry_mirror_index"] = int_value(registry_source.get("mirror_index", -2))
	registry_sha = str(registry_source.get("registry_sha256", "")).strip()
	if registry_sha:
		result["registry_source_sha256"] = registry_sha
	registry_size = int_value(registry_source.get("registry_size_bytes", 0))
	if registry_size > 0:
		result["registry_source_size_bytes"] = registry_size
	cache_dir = registry_source.get("cache_dir")
	if isinstance(cache_dir, Path):
		result["registry_cache_dir"] = display_path(cache_dir)


def resolve_tool_path(path: str) -> Path:
	resolved = Path(path)
	if not resolved.is_absolute():
		resolved = ROOT / resolved
	return resolved.resolve()


def resolve_project_lockfile_path(project_root: Path, lockfile_path: str) -> Path:
	path = Path(lockfile_path)
	if path.is_absolute():
		return path.resolve()
	return (project_root / path).resolve()


def read_project_framework_version(project_root: Path) -> str:
	plugin_cfg_path = project_root / "addons/gf/plugin.cfg"
	if not plugin_cfg_path.is_file():
		return ""
	config = configparser.ConfigParser()
	try:
		config.read(plugin_cfg_path, encoding="utf-8")
	except configparser.Error:
		return ""
	if not config.has_section("plugin"):
		return ""
	value = config.get("plugin", "version", fallback="").strip()
	if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
		return value[1:-1]
	return value


def display_path(path: Path) -> str:
	try:
		return path.relative_to(ROOT).as_posix()
	except ValueError:
		return path.as_posix()


def int_value(value: Any) -> int:
	if isinstance(value, int):
		return value
	if isinstance(value, str) and value.isdigit():
		return int(value)
	return 0


def lockfile_data_changed(current_lockfile: Any, planned_lockfile: Any) -> bool:
	return json.dumps(current_lockfile, ensure_ascii=False, sort_keys=True) != json.dumps(
		planned_lockfile,
		ensure_ascii=False,
		sort_keys=True,
	)


def string_array(value: Any) -> list[str]:
	if isinstance(value, str):
		return [value.strip()] if value.strip() else []
	if not isinstance(value, list):
		return []
	return [item.strip() for item in value if isinstance(item, str) and item.strip()]


def string_list(value: Any) -> list[str]:
	return string_array(value)


def print_result(result: dict[str, Any], as_json: bool) -> None:
	if as_json:
		print(json.dumps(result, ensure_ascii=False, indent=2))
		return
	if result.get("operation") == "status":
		print(
			f"{result['operation']}: ok={result['ok']} "
			f"packages={result['package_count']} "
			f"installed={result['installed_count']} "
			f"issues={result['issue_count']}"
		)
		for item in result["packages"]:
			state = "installed" if item.get("installed") else "available"
			print(f"- {item.get('id', '')}: {item.get('kind', '')} {state}")
		if result["orphan_packages"]:
			print("orphan_packages: " + ", ".join(result["orphan_packages"]))
		if result["issues"]:
			print("issues:")
			for issue in result["issues"]:
				print(f"- {issue}")
		return
	if result.get("operation") == "uninstall":
		print(
			f"{result['operation']}: ok={result['ok']} "
			f"packages={len(result['removed_packages'])} "
			f"files={result['removed_file_count']} "
			f"lockfile_written={result['lockfile_written']}"
		)
		if result["removed_packages"]:
			print("removed: " + ", ".join(result["removed_packages"]))
		if result["blocked"]:
			print("blocked:")
			for item in result["blocked"]:
				print(f"- {item}")
		if result["issues"]:
			print("issues:")
			for issue in result["issues"]:
				print(f"- {issue}")
		return
	if result.get("operation") == "update":
		print(
			f"{result['operation']}: ok={result['ok']} "
			f"packages={len(result['updated_packages'])} "
			f"files={result['updated_file_count']} "
			f"lockfile_written={result['lockfile_written']}"
		)
		if result["updated_packages"]:
			print("updated: " + ", ".join(result["updated_packages"]))
		if result["issues"]:
			print("issues:")
			for issue in result["issues"]:
				print(f"- {issue}")
		return
	print(
		f"{result['operation']}: ok={result['ok']} "
		f"packages={len(result['installed_packages'])} "
		f"files={result['installed_file_count']} "
		f"lockfile_written={result['lockfile_written']}"
	)
	if result["installed_packages"]:
		print("installed: " + ", ".join(result["installed_packages"]))
	if result["issues"]:
		print("issues:")
		for issue in result["issues"]:
			print(f"- {issue}")


if __name__ == "__main__":
	raise SystemExit(main())
