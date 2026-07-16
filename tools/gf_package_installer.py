#!/usr/bin/env python3
"""Install and uninstall GF package archives with staging and rollback."""

from __future__ import annotations

import argparse
import configparser
import copy
import hashlib
import json
import os
import posixpath
import secrets
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
import gf_package_cache
import gf_package_transaction
from gf_package_paths import normalize_manifest_path as normalize_shared_manifest_path
from gf_package_paths import path_matches_any_manifest_path as shared_path_matches_any_manifest_path


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
MAX_ARCHIVE_ENTRY_COUNT = 20000
MAX_ARCHIVE_ENTRY_UNCOMPRESSED_BYTES = 64 * 1024 * 1024
MAX_ARCHIVE_TOTAL_UNCOMPRESSED_BYTES = 512 * 1024 * 1024
MAX_ARCHIVE_COMPRESSION_RATIO = 100
MAX_ARCHIVE_ENTRY_PATH_LENGTH = 512
MAX_ARCHIVE_ENTRY_PATH_DEPTH = 32
UNSUPPORTED_REGISTRY_SOURCE_SIGNATURE_FIELDS = {
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
	install_parser.add_argument("--cache-mode", choices=gf_package_cache.CACHE_MODES, default=gf_package_cache.DEFAULT_MODE)
	install_parser.add_argument("--reason", choices=sorted(gf_package_resolver.VALID_REASONS - {"dependency"}), default="manual")
	install_parser.add_argument("--all-concrete", action="store_true", help="Install every non-preset package selected by the registry.")
	install_parser.add_argument("--kind", action="append", default=[], help="Install packages matching one or more comma-separated package kinds.")
	install_parser.add_argument("--exclude-kind", action="append", default=[], help="Exclude packages matching one or more comma-separated package kinds.")
	install_parser.add_argument("--dry-run", action="store_true", help="Resolve and validate archives without copying files or writing the lockfile.")
	install_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")
	install_parser.add_argument("--simulate-copy-failure-after", type=int, default=0, help=argparse.SUPPRESS)
	install_parser.add_argument("--simulate-transaction-failure-at", default="", help=argparse.SUPPRESS)
	install_parser.add_argument("--simulate-transaction-crash-at", default="", help=argparse.SUPPRESS)

	update_parser = subparsers.add_parser("update", help="Update packages that are already present in the project lockfile.")
	update_parser.add_argument("packages", nargs="*", help="Installed package ids to update.")
	update_parser.add_argument("--all-installed", action="store_true", help="Update every installed package that is present in the registry.")
	update_parser.add_argument("--registry", required=True, help="Registry index JSON path.")
	update_parser.add_argument("--channel", default="", help="Channel name when --registry points to a registry source manifest.")
	update_parser.add_argument("--project-root", required=True, help="Target Godot project root.")
	update_parser.add_argument("--lockfile", default=".gf/packages.lock.json", help="Lockfile path, relative to --project-root unless absolute.")
	update_parser.add_argument("--cache-dir", default="", help="Package download cache directory. Defaults to <project-root>/.gf/package_cache.")
	update_parser.add_argument("--cache-mode", choices=gf_package_cache.CACHE_MODES, default=gf_package_cache.DEFAULT_MODE)
	update_parser.add_argument("--dry-run", action="store_true", help="Resolve and validate updates without copying files or writing the lockfile.")
	update_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")
	update_parser.add_argument("--simulate-copy-failure-after", type=int, default=0, help=argparse.SUPPRESS)
	update_parser.add_argument("--simulate-transaction-failure-at", default="", help=argparse.SUPPRESS)
	update_parser.add_argument("--simulate-transaction-crash-at", default="", help=argparse.SUPPRESS)

	uninstall_parser = subparsers.add_parser("uninstall", help="Uninstall packages using the project lockfile.")
	uninstall_parser.add_argument("packages", nargs="+", help="Package ids to uninstall.")
	uninstall_parser.add_argument("--registry", required=True, help="Registry index JSON path.")
	uninstall_parser.add_argument("--channel", default="", help="Channel name when --registry points to a registry source manifest.")
	uninstall_parser.add_argument("--project-root", required=True, help="Target Godot project root.")
	uninstall_parser.add_argument("--lockfile", default=".gf/packages.lock.json", help="Lockfile path, relative to --project-root unless absolute.")
	uninstall_parser.add_argument("--cache-dir", default="", help="Package download cache directory. Defaults to <project-root>/.gf/package_cache.")
	uninstall_parser.add_argument("--cache-mode", choices=gf_package_cache.CACHE_MODES, default=gf_package_cache.DEFAULT_MODE)
	uninstall_parser.add_argument("--force", action="store_true", help="Ignore resolver blockers such as project references.")
	uninstall_parser.add_argument("--dry-run", action="store_true", help="Resolve and validate removal without deleting files or writing the lockfile.")
	uninstall_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")
	uninstall_parser.add_argument("--simulate-delete-failure-after", type=int, default=0, help=argparse.SUPPRESS)
	uninstall_parser.add_argument("--simulate-transaction-failure-at", default="", help=argparse.SUPPRESS)
	uninstall_parser.add_argument("--simulate-transaction-crash-at", default="", help=argparse.SUPPRESS)

	status_parser = subparsers.add_parser("status", help="List registry packages, lockfile state, and package install/uninstall previews.")
	status_parser.add_argument("--registry", required=True, help="Registry index JSON path.")
	status_parser.add_argument("--channel", default="", help="Channel name when --registry points to a registry source manifest.")
	status_parser.add_argument("--project-root", required=True, help="Target Godot project root.")
	status_parser.add_argument("--lockfile", default=".gf/packages.lock.json", help="Lockfile path, relative to --project-root unless absolute.")
	status_parser.add_argument("--cache-dir", default="", help="Package download cache directory. Defaults to <project-root>/.gf/package_cache.")
	status_parser.add_argument("--cache-mode", choices=gf_package_cache.CACHE_MODES, default=gf_package_cache.DEFAULT_MODE)
	status_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	recover_parser = subparsers.add_parser("recover", help="Recover or finalize an interrupted package transaction.")
	recover_parser.add_argument("--project-root", required=True, help="Target Godot project root.")
	recover_parser.add_argument("--lockfile", default=".gf/packages.lock.json", help="Lockfile path, relative to --project-root unless absolute.")
	recover_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	cache_init_parser = subparsers.add_parser("cache-init", help="Initialize an explicitly owned external package cache directory.")
	cache_init_parser.add_argument("--cache-dir", required=True, help="Absolute external cache directory to initialize.")
	cache_init_parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")

	args = parser.parse_args()
	if args.command == "install":
		result = install_packages(
			package_ids=args.packages,
			registry_path=args.registry,
			channel=args.channel,
			project_root=args.project_root,
			lockfile_path=args.lockfile,
			cache_dir=args.cache_dir,
			cache_mode=args.cache_mode,
			reason=args.reason,
			all_concrete=args.all_concrete,
			include_kinds=gf_package_resolver.split_selector_values(args.kind),
			exclude_kinds=gf_package_resolver.split_selector_values(args.exclude_kind),
			dry_run=args.dry_run,
			simulate_copy_failure_after=args.simulate_copy_failure_after,
			simulate_transaction_failure_at=args.simulate_transaction_failure_at,
			simulate_transaction_crash_at=args.simulate_transaction_crash_at,
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
			cache_mode=args.cache_mode,
			dry_run=args.dry_run,
			simulate_copy_failure_after=args.simulate_copy_failure_after,
			simulate_transaction_failure_at=args.simulate_transaction_failure_at,
			simulate_transaction_crash_at=args.simulate_transaction_crash_at,
		)
	elif args.command == "uninstall":
		result = uninstall_packages(
			package_ids=args.packages,
			registry_path=args.registry,
			channel=args.channel,
			project_root=args.project_root,
			lockfile_path=args.lockfile,
			cache_dir=args.cache_dir,
			cache_mode=args.cache_mode,
			force=args.force,
			dry_run=args.dry_run,
			simulate_delete_failure_after=args.simulate_delete_failure_after,
			simulate_transaction_failure_at=args.simulate_transaction_failure_at,
			simulate_transaction_crash_at=args.simulate_transaction_crash_at,
		)
	elif args.command == "status":
		result = package_status(
			registry_path=args.registry,
			channel=args.channel,
			project_root=args.project_root,
			lockfile_path=args.lockfile,
			cache_dir=args.cache_dir,
			cache_mode=args.cache_mode,
		)
	elif args.command == "recover":
		result = recover_package_transaction(
			project_root=args.project_root,
			lockfile_path=args.lockfile,
		)
	else:
		result = initialize_package_cache(args.cache_dir)
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
	cache_mode: str,
	reason: str,
	all_concrete: bool = False,
	include_kinds: list[str] | None = None,
	exclude_kinds: list[str] | None = None,
	dry_run: bool = False,
	simulate_copy_failure_after: int = 0,
	simulate_transaction_failure_at: str = "",
	simulate_transaction_crash_at: str = "",
) -> dict[str, Any]:
	resolved_project_root = resolve_project_path(project_root)
	resolved_lockfile_path = resolve_project_lockfile_path(resolved_project_root, lockfile_path)
	issues: list[str] = []
	append_lockfile_path_issues(resolved_project_root, resolved_lockfile_path, lockfile_path, issues)
	transaction_recovery = gf_package_transaction.empty_report("recover")
	if not issues:
		transaction_recovery = gf_package_transaction.recover_pending(resolved_project_root)
		if not transaction_recovery["ok"]:
			issues.extend(string_list(transaction_recovery.get("issues", [])))
	registry_source = make_pending_registry_source(registry_path, resolved_project_root, cache_mode, transaction_recovery)
	if not issues:
		registry_source = prepare_registry_source(registry_path, channel, resolved_project_root, cache_dir, cache_mode, issues)
		registry_source["_transaction_recovery"] = transaction_recovery
	resolved_registry_path = registry_source["path"]
	cache_context = registry_source["_cache_context"]
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
	lockfile = gf_package_resolver.load_lockfile(resolved_lockfile_path)
	if registry["issues"]:
		issues.extend(string_list(registry["issues"]))
	issues.extend(string_list(lockfile.get("issues", [])))
	issues.extend(installed_file_list_issues(installed_entries(lockfile.get("data", {})), registry.get("packages", {})))
	to_change = set(string_list(plan.get("to_install", [])) + string_list(plan.get("to_update", [])))
	packages_to_change = [package_id for package_id in string_list(plan.get("install_order", [])) if package_id in to_change]
	packages_to_stage = [
		package_id
		for package_id in packages_to_change
		if package_requires_archive(registry["packages"].get(package_id, {}))
	]
	current_lockfile_data = lockfile.get("data", {}) if isinstance(lockfile.get("data", {}), dict) else {}
	planned_lockfile = plan.get("planned_lockfile", {}) if isinstance(plan.get("planned_lockfile", {}), dict) else {}
	planned_lockfile = lockfile_with_installed_files(planned_lockfile, [], current_lockfile_data)
	lockfile_changed = lockfile_data_changed(lockfile.get("data", {}), planned_lockfile)
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
		if dry_run or not lockfile_changed:
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
		transaction = execute_package_transaction(
			"install",
			[],
			[],
			resolved_project_root,
			resolved_lockfile_path,
			planned_lockfile,
			simulate_copy_failure_after=simulate_copy_failure_after,
			simulate_transaction_failure_at=simulate_transaction_failure_at,
			simulate_transaction_crash_at=simulate_transaction_crash_at,
		)
		registry_source["_transaction"] = transaction
		if not transaction["ok"]:
			issues.extend(string_list(transaction.get("issues", [])))
			return make_install_result(
				False,
				resolved_registry_path,
				resolved_project_root,
				resolved_lockfile_path,
				resolved_package_ids,
				plan,
				[],
				0,
				False,
				bool(transaction.get("rolled_back", False)),
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
			[],
			0,
			dry_run,
			False,
			[],
			registry_source,
			True,
		)
	if dry_run:
		audit_package_archives(
			packages_to_stage,
			registry["packages"],
			resolved_registry_path,
			cache_context,
			issues,
		)
		return make_install_result(
			len(issues) == 0,
			resolved_registry_path,
			resolved_project_root,
			resolved_lockfile_path,
			resolved_package_ids,
			plan,
			packages_to_change,
			0,
			True,
			False,
			issues,
			registry_source,
		)

	with tempfile.TemporaryDirectory(prefix="gf-package-install-") as temp_dir:
		temp_root = Path(temp_dir)
		staging_root = temp_root / "staging"
		staged_files = stage_package_archives(
			packages_to_stage,
			registry["packages"],
			resolved_registry_path,
			cache_context,
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
		planned_lockfile = lockfile_with_installed_files(plan["planned_lockfile"], staged_files, current_lockfile_data)
		packages_to_update = string_list(plan.get("to_update", []))
		append_modified_existing_update_file_issues(
			packages_to_update,
			current_lockfile_data,
			planned_lockfile,
			resolved_project_root,
			issues,
		)
		append_existing_target_ownership_issues(
			staged_files,
			resolved_project_root,
			current_lockfile_data,
			issues,
			allow_extracted_kernel_bootstrap=True,
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
				False,
				False,
				issues,
				registry_source,
			)
		obsolete_targets = collect_update_obsolete_targets(
			packages_to_update,
			current_lockfile_data,
			planned_lockfile,
			resolved_project_root,
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
				False,
				False,
				issues,
				registry_source,
			)
		transaction = execute_package_transaction(
			"install",
			staged_files,
			obsolete_targets,
			resolved_project_root,
			resolved_lockfile_path,
			planned_lockfile,
			simulate_copy_failure_after=simulate_copy_failure_after,
			simulate_transaction_failure_at=simulate_transaction_failure_at,
			simulate_transaction_crash_at=simulate_transaction_crash_at,
		)
		registry_source["_transaction"] = transaction
		installed_file_count = int_value(transaction.get("write_count", 0))
		if not transaction["ok"]:
			issues.extend(string_list(transaction.get("issues", [])))
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
				bool(transaction.get("rolled_back", False)),
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
	cache_mode: str,
	dry_run: bool,
	simulate_copy_failure_after: int = 0,
	simulate_transaction_failure_at: str = "",
	simulate_transaction_crash_at: str = "",
) -> dict[str, Any]:
	resolved_project_root = resolve_project_path(project_root)
	resolved_lockfile_path = resolve_project_lockfile_path(resolved_project_root, lockfile_path)
	issues: list[str] = []
	append_lockfile_path_issues(resolved_project_root, resolved_lockfile_path, lockfile_path, issues)
	transaction_recovery = gf_package_transaction.empty_report("recover")
	if not issues:
		transaction_recovery = gf_package_transaction.recover_pending(resolved_project_root)
		if not transaction_recovery["ok"]:
			issues.extend(string_list(transaction_recovery.get("issues", [])))
	registry_source = make_pending_registry_source(registry_path, resolved_project_root, cache_mode, transaction_recovery)
	if not issues:
		registry_source = prepare_registry_source(registry_path, channel, resolved_project_root, cache_dir, cache_mode, issues)
		registry_source["_transaction_recovery"] = transaction_recovery
	resolved_registry_path = registry_source["path"]
	cache_context = registry_source["_cache_context"]
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
	issues.extend(installed_file_list_issues(installed_entries(lockfile.get("data", {})), registry.get("packages", {})))
	to_change = set(string_list(plan.get("to_install", [])) + string_list(plan.get("to_update", [])))
	packages_to_change = [package_id for package_id in string_list(plan.get("install_order", [])) if package_id in to_change]
	packages_to_stage = [
		package_id
		for package_id in packages_to_change
		if package_requires_archive(registry["packages"].get(package_id, {}))
	]
	current_lockfile_data = lockfile.get("data", {}) if isinstance(lockfile.get("data", {}), dict) else {}
	planned_lockfile = plan.get("planned_lockfile", {}) if isinstance(plan.get("planned_lockfile", {}), dict) else {}
	planned_lockfile = lockfile_with_installed_files(planned_lockfile, [], current_lockfile_data)
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
		transaction = execute_package_transaction(
			"update",
			[],
			[],
			resolved_project_root,
			resolved_lockfile_path,
			planned_lockfile,
			simulate_copy_failure_after=simulate_copy_failure_after,
			simulate_transaction_failure_at=simulate_transaction_failure_at,
			simulate_transaction_crash_at=simulate_transaction_crash_at,
		)
		registry_source["_transaction"] = transaction
		if not transaction["ok"]:
			issues.extend(string_list(transaction.get("issues", [])))
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
				bool(transaction.get("rolled_back", False)),
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
	if dry_run:
		audit_package_archives(
			packages_to_stage,
			registry["packages"],
			resolved_registry_path,
			cache_context,
			issues,
		)
		return make_update_result(
			len(issues) == 0,
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
			issues,
			registry_source,
		)

	with tempfile.TemporaryDirectory(prefix="gf-package-update-") as temp_dir:
		temp_root = Path(temp_dir)
		staging_root = temp_root / "staging"
		staged_files = stage_package_archives(
			packages_to_stage,
			registry["packages"],
			resolved_registry_path,
			cache_context,
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
		planned_lockfile = lockfile_with_installed_files(planned_lockfile, staged_files, current_lockfile_data)
		append_modified_existing_update_file_issues(
			packages_to_change,
			current_lockfile_data,
			planned_lockfile,
			resolved_project_root,
			issues,
		)
		append_existing_target_ownership_issues(
			staged_files,
			resolved_project_root,
			current_lockfile_data,
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
				False,
				False,
				False,
				issues,
				registry_source,
			)
		obsolete_targets = collect_update_obsolete_targets(
			packages_to_change,
			current_lockfile_data,
			planned_lockfile,
			resolved_project_root,
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
				False,
				False,
				False,
				issues,
				registry_source,
			)
		transaction = execute_package_transaction(
			"update",
			staged_files,
			obsolete_targets,
			resolved_project_root,
			resolved_lockfile_path,
			planned_lockfile,
			simulate_copy_failure_after=simulate_copy_failure_after,
			simulate_transaction_failure_at=simulate_transaction_failure_at,
			simulate_transaction_crash_at=simulate_transaction_crash_at,
		)
		registry_source["_transaction"] = transaction
		updated_file_count = int_value(transaction.get("write_count", 0))
		if not transaction["ok"]:
			issues.extend(string_list(transaction.get("issues", [])))
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
				bool(transaction.get("rolled_back", False)),
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
	cache_mode: str,
	force: bool,
	dry_run: bool,
	simulate_delete_failure_after: int = 0,
	simulate_transaction_failure_at: str = "",
	simulate_transaction_crash_at: str = "",
) -> dict[str, Any]:
	resolved_project_root = resolve_project_path(project_root)
	resolved_lockfile_path = resolve_project_lockfile_path(resolved_project_root, lockfile_path)
	issues: list[str] = []
	append_lockfile_path_issues(resolved_project_root, resolved_lockfile_path, lockfile_path, issues)
	transaction_recovery = gf_package_transaction.empty_report("recover")
	if not issues:
		transaction_recovery = gf_package_transaction.recover_pending(resolved_project_root)
		if not transaction_recovery["ok"]:
			issues.extend(string_list(transaction_recovery.get("issues", [])))
	registry_source = make_pending_registry_source(registry_path, resolved_project_root, cache_mode, transaction_recovery)
	if not issues:
		registry_source = prepare_registry_source(registry_path, channel, resolved_project_root, cache_dir, cache_mode, issues)
		registry_source["_transaction_recovery"] = transaction_recovery
	resolved_registry_path = registry_source["path"]
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

	transaction = execute_package_transaction(
		"uninstall",
		[],
		targets,
		resolved_project_root,
		resolved_lockfile_path,
		plan["planned_lockfile"],
		simulate_delete_failure_after=simulate_delete_failure_after,
		simulate_transaction_failure_at=simulate_transaction_failure_at,
		simulate_transaction_crash_at=simulate_transaction_crash_at,
	)
	registry_source["_transaction"] = transaction
	removed_file_count = int_value(transaction.get("delete_count", 0))
	if not transaction["ok"]:
		issues.extend(string_list(transaction.get("issues", [])))
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
			bool(transaction.get("rolled_back", False)),
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


def recover_package_transaction(
	project_root: str,
	lockfile_path: str = ".gf/packages.lock.json",
) -> dict[str, Any]:
	resolved_project_root = resolve_project_path(project_root)
	resolved_lockfile_path = resolve_project_lockfile_path(resolved_project_root, lockfile_path)
	issues: list[str] = []
	append_lockfile_path_issues(resolved_project_root, resolved_lockfile_path, lockfile_path, issues)
	if issues:
		result = gf_package_transaction.empty_report("recover")
		result.update({
			"ok": False,
			"outcome": "blocked",
			"recovery_required": True,
			"issue_count": len(issues),
			"issues": issues,
		})
	else:
		result = gf_package_transaction.recover_pending(resolved_project_root)
	result["backend"] = "python_maintenance"
	result["project_root"] = display_path(resolved_project_root)
	result["lockfile"] = display_path(resolved_lockfile_path)
	return result


def initialize_package_cache(cache_dir: str) -> dict[str, Any]:
	result = gf_package_cache.initialize_external_cache(cache_dir)
	result["backend"] = "python_maintenance"
	return result


def package_status(
	registry_path: str,
	channel: str,
	project_root: str,
	lockfile_path: str,
	cache_dir: str,
	cache_mode: str,
) -> dict[str, Any]:
	resolved_project_root = resolve_project_path(project_root)
	resolved_lockfile_path = resolve_project_lockfile_path(resolved_project_root, lockfile_path)
	issues: list[str] = []
	append_lockfile_path_issues(resolved_project_root, resolved_lockfile_path, lockfile_path, issues)
	transaction_recovery = gf_package_transaction.empty_report("recover")
	if not issues:
		transaction_recovery = gf_package_transaction.recover_pending(resolved_project_root)
		if not transaction_recovery["ok"]:
			issues.extend(string_list(transaction_recovery.get("issues", [])))
	registry_source = make_pending_registry_source(registry_path, resolved_project_root, cache_mode, transaction_recovery)
	if not issues:
		registry_source = prepare_registry_source(registry_path, channel, resolved_project_root, cache_dir, cache_mode, issues)
		registry_source["_transaction_recovery"] = transaction_recovery
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
		raw_files = lock_entry.get("files", [])
		if not isinstance(raw_files, list) or any(not isinstance(item, str) or not item.strip() for item in raw_files):
			issues.append(f"Installed package lockfile entry files must be an array of non-empty strings: {package_id}")
			continue
		files = string_list(raw_files)
		if not files:
			issues.append(f"Installed package lockfile entry is missing files list: {package_id}")
			continue
		file_identities = [portable_path_identity(path) for path in files]
		if any(not identity for identity in file_identities) or len(file_identities) != len(set(file_identities)):
			issues.append(f"Installed package lockfile entry files must not contain duplicates: {package_id}")
		metadata = lock_entry.get("file_metadata", {})
		if not isinstance(metadata, dict):
			issues.append(f"Installed package lockfile entry file_metadata must be an object: {package_id}")
			continue
		file_set = set(files)
		metadata_set = {str(relative_path) for relative_path in metadata}
		metadata_identities = [portable_path_identity(path) for path in metadata_set]
		if any(not identity for identity in metadata_identities) or len(metadata_identities) != len(set(metadata_identities)):
			issues.append(f"Installed package file_metadata contains unsafe or aliased paths: {package_id}")
		for relative_path in sorted(file_set - metadata_set):
			issues.append(f"Installed package file_metadata is missing file: {package_id}: {relative_path}")
		for relative_path in sorted(metadata_set - file_set):
			issues.append(f"Installed package file_metadata contains an unlisted file: {package_id}: {relative_path}")
		for relative_path in sorted(file_set.intersection(metadata_set)):
			if normalize_archive_name(relative_path) != relative_path or not relative_path.startswith("addons/gf/"):
				issues.append(f"Installed package files entry is unsafe: {package_id}: {relative_path}")
				continue
			file_state = metadata.get(relative_path)
			if not isinstance(file_state, dict):
				issues.append(f"Installed package file_metadata entry must be an object: {package_id}: {relative_path}")
				continue
			sha256 = str(file_state.get("sha256", "")).strip().lower()
			size_bytes = file_state.get("size_bytes")
			if not is_sha256_hex(sha256) or type(size_bytes) is not int or size_bytes < 0:
				issues.append(f"Installed package file_metadata entry is invalid: {package_id}: {relative_path}")
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
		"gf_extension_id": str(registry_entry.get("gf_extension_id", "")),
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


def lockfile_with_installed_files(
	planned_lockfile: dict[str, Any],
	staged_files: list[dict[str, Any]],
	current_lockfile: dict[str, Any] | None = None,
) -> dict[str, Any]:
	lockfile = copy.deepcopy(planned_lockfile)
	installed = lockfile.get("installed", {})
	if not isinstance(installed, dict):
		return lockfile
	current_installed = current_lockfile.get("installed", {}) if isinstance(current_lockfile, dict) else {}
	if not isinstance(current_installed, dict):
		current_installed = {}
	for package_id, entry in installed.items():
		current_entry = current_installed.get(package_id)
		if not isinstance(entry, dict) or not isinstance(current_entry, dict):
			continue
		current_files = string_array(current_entry.get("files", []))
		current_metadata = current_entry.get("file_metadata", {})
		if current_files:
			entry["files"] = sorted(current_files)
		if isinstance(current_metadata, dict) and current_metadata:
			entry["file_metadata"] = {
				str(relative_path): copy.deepcopy(current_metadata[relative_path])
				for relative_path in sorted(current_metadata, key=str)
			}
	files_by_package: dict[str, list[str]] = {}
	metadata_by_package: dict[str, dict[str, dict[str, Any]]] = {}
	for item in staged_files:
		package_id = str(item.get("package_id", ""))
		relative_path = str(item.get("relative_path", ""))
		if not package_id or not relative_path:
			continue
		files_by_package.setdefault(package_id, [])
		metadata_by_package.setdefault(package_id, {})
		if relative_path not in files_by_package[package_id]:
			files_by_package[package_id].append(relative_path)
		sha256 = str(item.get("sha256", "")).strip().lower()
		size_bytes = item.get("size_bytes", -1)
		staged_path = item.get("staged_path")
		if (not is_sha256_hex(sha256) or not is_non_negative_int_value(size_bytes)) and isinstance(staged_path, Path):
			sha256 = sha256_file(staged_path)
			size_bytes = staged_path.stat().st_size
		metadata_by_package[package_id][relative_path] = {
			"sha256": sha256,
			"size_bytes": int(size_bytes),
		}
	for package_id, files in files_by_package.items():
		entry = installed.get(package_id)
		if isinstance(entry, dict):
			entry["files"] = sorted(files)
			entry["file_metadata"] = {
				relative_path: metadata_by_package[package_id][relative_path]
				for relative_path in sorted(metadata_by_package[package_id])
			}
	lockfile["installed"] = installed
	return lockfile


def append_modified_existing_update_file_issues(
	package_ids: list[str],
	current_lockfile: dict[str, Any],
	planned_lockfile: dict[str, Any],
	project_root: Path,
	issues: list[str],
) -> None:
	current_installed = installed_entries(current_lockfile)
	planned_installed = installed_entries(planned_lockfile)
	for package_id in package_ids:
		current_entry = current_installed.get(package_id)
		planned_entry = planned_installed.get(package_id)
		if not isinstance(current_entry, dict) or not isinstance(planned_entry, dict):
			continue
		planned_files = set(string_array(planned_entry.get("files", [])))
		current_metadata = current_entry.get("file_metadata", {})
		if not isinstance(current_metadata, dict):
			current_metadata = {}
		for relative_path in string_array(current_entry.get("files", [])):
			if relative_path not in planned_files:
				continue
			target_path = checked_project_target_path(project_root, relative_path, package_id, issues)
			if target_path is None or not target_path.exists():
				continue
			metadata = current_metadata.get(relative_path)
			if not valid_file_metadata(metadata):
				issues.append(
					f"{package_id}: installed file is missing lockfile metadata; "
					f"reinstall before updating: {relative_path}"
				)
				continue
			if not file_matches_metadata(target_path, metadata):
				issues.append(
					f"{package_id}: installed file was modified; "
					f"refusing to overwrite it during update: {relative_path}"
				)


def append_existing_target_ownership_issues(
	staged_files: list[dict[str, Any]],
	project_root: Path,
	current_lockfile: dict[str, Any],
	issues: list[str],
	allow_extracted_kernel_bootstrap: bool = False,
) -> None:
	installed = installed_entries(current_lockfile)
	adopt_extracted_kernel = allow_extracted_kernel_bootstrap and extracted_kernel_matches_staged_files(
		staged_files,
		project_root,
		current_lockfile,
	)
	for item in staged_files:
		package_id = str(item.get("package_id", ""))
		relative_path = normalize_archive_name(str(item.get("relative_path", "")))
		if not package_id or not relative_path:
			continue
		target_path = checked_project_target_path(project_root, relative_path, package_id, issues)
		if target_path is None or not target_path.exists():
			continue
		owner = installed_file_owner(relative_path, installed)
		if not owner:
			if adopt_extracted_kernel and package_id == "gf.kernel":
				continue
			issues.append(f"{package_id}: package target already exists but is not owned by the lockfile: {relative_path}")
			continue
		if owner != package_id:
			issues.append(f"{package_id}: package target is owned by installed package {owner}: {relative_path}")


def extracted_kernel_matches_staged_files(
	staged_files: list[dict[str, Any]],
	project_root: Path,
	current_lockfile: dict[str, Any],
) -> bool:
	if installed_entries(current_lockfile):
		return False
	kernel_files = [item for item in staged_files if str(item.get("package_id", "")) == "gf.kernel"]
	if not kernel_files:
		return False
	for item in kernel_files:
		relative_path = normalize_archive_name(str(item.get("relative_path", "")))
		if not relative_path:
			return False
		path_issues: list[str] = []
		target_path = checked_project_target_path(project_root, relative_path, "gf.kernel", path_issues)
		if path_issues or target_path is None or not target_matches_staged_file(target_path, item):
			return False
	return True


def collect_update_obsolete_targets(
	package_ids: list[str],
	current_lockfile: dict[str, Any],
	planned_lockfile: dict[str, Any],
	project_root: Path,
	issues: list[str],
) -> list[dict[str, Any]]:
	targets_by_path: dict[str, dict[str, Any]] = {}
	current_installed = installed_entries(current_lockfile)
	planned_installed = installed_entries(planned_lockfile)
	for package_id in package_ids:
		current_entry = current_installed.get(package_id)
		planned_entry = planned_installed.get(package_id)
		if not isinstance(current_entry, dict) or not isinstance(planned_entry, dict):
			continue
		planned_files = set(string_array(planned_entry.get("files", [])))
		current_metadata = current_entry.get("file_metadata", {})
		if not isinstance(current_metadata, dict):
			current_metadata = {}
		for raw_path in string_array(current_entry.get("files", [])):
			relative_path = normalize_archive_name(raw_path)
			if not relative_path or relative_path in planned_files or relative_path in targets_by_path:
				continue
			if remaining_installed_file_owner(relative_path, current_installed, package_id):
				continue
			target_path = checked_project_target_path(project_root, relative_path, package_id, issues)
			if target_path is None or not target_path.exists():
				continue
			metadata = current_metadata.get(relative_path)
			if not valid_file_metadata(metadata):
				issues.append(
					f"{package_id}: obsolete installed file is missing lockfile metadata; "
					f"reinstall before updating: {relative_path}"
				)
				continue
			if not file_matches_metadata(target_path, metadata):
				issues.append(
					f"{package_id}: obsolete installed file was modified; "
					f"refusing to delete it during update: {relative_path}"
				)
				continue
			targets_by_path[relative_path] = {
				"package_id": package_id,
				"relative_path": relative_path,
				"target_path": target_path,
			}
	return [targets_by_path[relative_path] for relative_path in sorted(targets_by_path)]


def installed_entries(lockfile: dict[str, Any]) -> dict[str, Any]:
	installed = lockfile.get("installed", {}) if isinstance(lockfile, dict) else {}
	return installed if isinstance(installed, dict) else {}


def installed_file_owner(relative_path: str, installed: dict[str, Any]) -> str:
	path_identity = portable_path_identity(relative_path)
	for package_id in sorted(installed):
		entry = installed.get(package_id)
		if not isinstance(entry, dict):
			continue
		if any(portable_path_identity(path) == path_identity for path in string_array(entry.get("files", []))):
			return str(package_id)
	return ""


def remaining_installed_file_owner(relative_path: str, installed: dict[str, Any], current_package_id: str) -> str:
	path_identity = portable_path_identity(relative_path)
	for package_id in sorted(installed):
		if package_id == current_package_id:
			continue
		entry = installed.get(package_id)
		if not isinstance(entry, dict):
			continue
		if any(portable_path_identity(path) == path_identity for path in string_array(entry.get("files", []))):
			return str(package_id)
	return ""


def checked_project_target_path(
	project_root: Path,
	relative_path: str,
	package_id: str,
	issues: list[str],
) -> Path | None:
	try:
		return project_target_path(project_root, relative_path)
	except InstallFailure as error:
		issues.append(f"{package_id}: {error}")
		return None


def valid_file_metadata(value: Any) -> bool:
	if not isinstance(value, dict):
		return False
	if set(value) != {"sha256", "size_bytes"}:
		return False
	sha256 = str(value.get("sha256", "")).strip().lower()
	size_bytes = value.get("size_bytes")
	return is_sha256_hex(sha256) and type(size_bytes) is int and size_bytes >= 0


def file_matches_metadata(path: Path, metadata: Any) -> bool:
	if gf_package_transaction.path_has_reparse_component(path) or not path.is_file() or not valid_file_metadata(metadata):
		return False
	return path.stat().st_size == int(metadata["size_bytes"]) and sha256_file(path) == str(metadata["sha256"]).lower()


def target_matches_staged_file(target_path: Path, staged_file: dict[str, Any]) -> bool:
	metadata = {
		"sha256": staged_file.get("sha256", ""),
		"size_bytes": staged_file.get("size_bytes", -1),
	}
	return file_matches_metadata(target_path, metadata)


def stage_package_archives(
	package_ids: list[str],
	registry_packages: dict[str, dict[str, Any]],
	registry_path: Path,
	cache_context: dict[str, Any],
	staging_root: Path,
	issues: list[str],
) -> list[dict[str, Any]]:
	staged_files: list[dict[str, Any]] = []
	for package_id in package_ids:
		entry = registry_packages.get(package_id)
		if not isinstance(entry, dict):
			issues.append(f"{package_id}: missing registry package entry.")
			continue
		archive_path = resolve_archive_path(str(entry.get("archive", "")), registry_path, cache_context, package_id, entry, issues)
		if archive_path is None:
			continue
		package_issues = audit_package_archive(package_id, entry, archive_path)
		if package_issues:
			issues.extend(package_issues)
			continue
		with zipfile.ZipFile(archive_path, "r") as archive:
			for name in sorted(name for name in archive.namelist() if name and not name.endswith("/")):
				normalized = normalize_archive_name(name)
				if not normalized:
					issues.append(f"{package_id}: unsafe archive entry path during staging: {name}")
					continue
				staged_path = staging_root / package_id / Path(*normalized.split("/"))
				if gf_package_transaction.path_has_reparse_component(staged_path):
					issues.append(f"{package_id}: archive staging path crosses a filesystem link: {normalized}")
					continue
				staged_path.parent.mkdir(parents=True, exist_ok=True)
				payload = archive.read(name)
				staged_path.write_bytes(payload)
				staged_files.append({
					"package_id": package_id,
					"relative_path": normalized,
					"staged_path": staged_path,
					"sha256": hashlib.sha256(payload).hexdigest(),
					"size_bytes": len(payload),
				})
	return staged_files


def audit_package_archives(
	package_ids: list[str],
	registry_packages: dict[str, dict[str, Any]],
	registry_path: Path,
	cache_context: dict[str, Any],
	issues: list[str],
) -> None:
	for package_id in package_ids:
		entry = registry_packages.get(package_id)
		if not isinstance(entry, dict):
			issues.append(f"{package_id}: missing registry package entry.")
			continue
		archive_path = resolve_archive_path(str(entry.get("archive", "")), registry_path, cache_context, package_id, entry, issues)
		if archive_path is None:
			continue
		issues.extend(audit_package_archive(package_id, entry, archive_path))


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
			entries = [info for info in archive.infolist() if info.filename and not info.filename.endswith("/")]
	except zipfile.BadZipFile as error:
		return [f"{package_id}: invalid zip archive: {error}"]
	if len(entries) > MAX_ARCHIVE_ENTRY_COUNT:
		issues.append(f"{package_id}: archive contains too many file entries: {len(entries)} > {MAX_ARCHIVE_ENTRY_COUNT}")
	seen: set[str] = set()
	total_uncompressed_size = 0
	for entry_info in entries:
		name = entry_info.filename
		normalized = normalize_archive_name(name)
		if not normalized:
			issues.append(f"{package_id}: unsafe archive entry path: {name}")
			continue
		total_uncompressed_size += entry_info.file_size
		if len(normalized) > MAX_ARCHIVE_ENTRY_PATH_LENGTH:
			issues.append(f"{package_id}: archive entry path is too long: {normalized}")
		if len(normalized.split("/")) > MAX_ARCHIVE_ENTRY_PATH_DEPTH:
			issues.append(f"{package_id}: archive entry path is too deep: {normalized}")
		if entry_info.file_size > MAX_ARCHIVE_ENTRY_UNCOMPRESSED_BYTES:
			issues.append(f"{package_id}: archive entry is too large after decompression: {normalized}")
		if entry_info.compress_size <= 0 and entry_info.file_size > 0:
			issues.append(f"{package_id}: archive entry has invalid compressed size: {normalized}")
		elif entry_info.compress_size > 0 and entry_info.file_size > entry_info.compress_size * MAX_ARCHIVE_COMPRESSION_RATIO:
			issues.append(f"{package_id}: archive entry compression ratio exceeds limit: {normalized}")
		if zip_info_uses_zip64(entry_info):
			issues.append(f"{package_id}: archive entry uses unsupported ZIP64 metadata: {normalized}")
		path_identity = portable_path_identity(normalized)
		if path_identity in seen:
			issues.append(f"{package_id}: duplicate archive entry path: {normalized}")
			continue
		seen.add(path_identity)
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
	if total_uncompressed_size > MAX_ARCHIVE_TOTAL_UNCOMPRESSED_BYTES:
		issues.append(f"{package_id}: archive decompressed size exceeds limit: {total_uncompressed_size} > {MAX_ARCHIVE_TOTAL_UNCOMPRESSED_BYTES}")
	return issues


def zip_info_uses_zip64(entry_info: zipfile.ZipInfo) -> bool:
	extra = entry_info.extra
	index = 0
	while index + 4 <= len(extra):
		header_id = int.from_bytes(extra[index:index + 2], "little")
		data_size = int.from_bytes(extra[index + 2:index + 4], "little")
		if header_id == 0x0001:
			return True
		index += 4 + data_size
	return False


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
		raw_file_paths = lock_entry.get("files", [])
		file_paths = string_array(raw_file_paths)
		file_metadata = lock_entry.get("file_metadata", {})
		if not isinstance(raw_file_paths, list) or any(not isinstance(item, str) or not item.strip() for item in raw_file_paths):
			issues.append(f"{package_id}: lockfile entry files must be an array of non-empty strings.")
			continue
		if not file_paths:
			issues.append(f"{package_id}: lockfile entry is missing the installed files list; reinstall or repair the package before uninstalling.")
			continue
		file_identities = [portable_path_identity(path) for path in file_paths]
		if any(not identity for identity in file_identities) or len(file_identities) != len(set(file_identities)):
			issues.append(f"{package_id}: lockfile entry files must not contain duplicates.")
			continue
		if not isinstance(file_metadata, dict):
			issues.append(f"{package_id}: lockfile entry file_metadata must be an object; reinstall or repair the package before uninstalling.")
			continue
		metadata_paths = [str(relative_path) for relative_path in file_metadata]
		metadata_identities = [portable_path_identity(path) for path in metadata_paths]
		if (
			any(not identity for identity in metadata_identities)
			or len(metadata_identities) != len(set(metadata_identities))
			or set(metadata_identities) != set(file_identities)
		):
			issues.append(f"{package_id}: lockfile entry file_metadata must exactly cover the installed files list.")
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
			path_identity = portable_path_identity(normalized)
			if path_identity in seen_paths:
				continue
			target_path = checked_project_target_path(project_root, normalized, package_id, issues)
			if target_path is None:
				continue
			metadata = file_metadata.get(normalized)
			if not valid_file_metadata(metadata):
				issues.append(f"{package_id}: installed file is missing lockfile metadata; refusing to uninstall: {normalized}")
				continue
			if target_path.exists():
				if not file_matches_metadata(target_path, metadata):
					issues.append(f"{package_id}: installed file was modified; refusing to delete it during uninstall: {normalized}")
					continue
			seen_paths.add(path_identity)
			targets.append({
				"package_id": package_id,
				"relative_path": normalized,
				"target_path": target_path,
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
		if any(
			portable_path_identity(relative_path) == portable_path_identity(path)
			for path in string_array(lock_entry.get("files", []))
		) or path_matches_any_manifest_path(relative_path, patterns):
			return str(package_id)
	return ""


def execute_package_transaction(
	operation: str,
	staged_files: list[dict[str, Any]],
	delete_targets: list[dict[str, Any]],
	project_root: Path,
	lockfile_path: Path,
	planned_lockfile: dict[str, Any],
	*,
	simulate_copy_failure_after: int = 0,
	simulate_delete_failure_after: int = 0,
	simulate_transaction_failure_at: str = "",
	simulate_transaction_crash_at: str = "",
) -> dict[str, Any]:
	writes = [
		{
			"relative_path": str(item.get("relative_path", "")),
			"source_path": str(item.get("staged_path", "")),
		}
		for item in staged_files
	]
	deletes = [
		{"relative_path": str(item.get("relative_path", ""))}
		for item in delete_targets
	]
	request = gf_package_transaction.make_request(
		operation,
		project_root,
		lockfile_path,
		planned_lockfile,
		writes,
		deletes,
	)
	return gf_package_transaction.execute(
		request,
		simulate_copy_failure_after=simulate_copy_failure_after,
		simulate_delete_failure_after=simulate_delete_failure_after,
		simulate_transaction_failure_at=simulate_transaction_failure_at,
		simulate_transaction_crash_at=simulate_transaction_crash_at,
	)


def make_pending_registry_source(
	registry_value: str,
	project_root: Path,
	cache_mode: str,
	transaction_recovery: dict[str, Any],
) -> dict[str, Any]:
	local_root = gf_package_transaction.absolute_lexical_path(project_root / gf_package_cache.LOCAL_CACHE_RELATIVE_PATH)
	workspace_root = gf_package_transaction.absolute_lexical_path(project_root / gf_package_cache.WORKSPACE_RELATIVE_PATH)
	cache_context = gf_package_cache.make_context(cache_mode, local_root, workspace_root, project_root)
	gf_package_cache.configure_project_local_context(cache_context, local_root)
	registry = registry_value.strip()
	path = (
		workspace_root / "registries" / f"{sha256_text(registry)}.json"
		if is_remote_url(registry)
		else resolve_tool_path(registry_value)
	)
	result = make_registry_candidate_result(path, cache_context, is_remote_url(registry), registry_value)
	result["_transaction_recovery"] = transaction_recovery
	return result


def prepare_registry_source(
	registry_value: str,
	channel: str,
	project_root: Path,
	cache_dir: str,
	cache_mode: str,
	issues: list[str],
) -> dict[str, Any]:
	cache_context = gf_package_cache.resolve_context(project_root, cache_dir, cache_mode, issues)
	registry = registry_value.strip()
	if issues:
		return make_registry_candidate_result(
			Path(registry) if not is_remote_url(registry) else Path(cache_context["workspace_root"]) / "registries" / f"{sha256_text(registry)}.json",
			cache_context,
			is_remote_url(registry),
			registry,
		)
	source_issues: list[str] = []
	source = prepare_registry_candidate(registry, project_root, cache_context, source_issues)
	if source_issues:
		issues.extend(source_issues)
		return source
	if registry_file_is_source_manifest(source["path"]):
		return prepare_registry_source_channel(source, channel, project_root, cache_context, issues)
	return source


def prepare_registry_candidate(
	registry_value: str,
	project_root: Path,
	cache_context: dict[str, Any],
	issues: list[str],
	expected_sha: str = "",
	expected_size: int = 0,
) -> dict[str, Any]:
	registry = registry_value.strip()
	if is_remote_url(registry):
		try:
			cache_path = gf_package_cache.make_workspace_temp_path(cache_context, "registries", ".json")
		except ValueError as error:
			issues.append(str(error))
			return make_registry_candidate_result(Path(""), cache_context, True, registry)
		raw_path = None
		downloaded_path = None
		if expected_sha and expected_size > 0:
			raw_path = gf_package_cache.find_artifact(cache_context, expected_sha, expected_size, ".json")
		if raw_path is None:
			try:
				downloaded_path = gf_package_cache.make_workspace_temp_path(cache_context, "registry_downloads", ".json")
			except ValueError as error:
				issues.append(str(error))
				return make_registry_candidate_result(cache_path, cache_context, True, registry)
			raw_path = downloaded_path
			if not download_url_to_file(registry, raw_path, "registry", issues, MAX_REGISTRY_DOWNLOAD_BYTES):
				return make_registry_candidate_result(cache_path, cache_context, True, registry)
			if not registry_file_matches_metadata(raw_path, expected_sha, expected_size, issues):
				try_unlink(downloaded_path)
				return make_registry_candidate_result(cache_path, cache_context, True, registry)
			if expected_sha and expected_size > 0:
				committed_path = gf_package_cache.commit_artifact(
					cache_context,
					raw_path,
					expected_sha,
					expected_size,
					".json",
					issues,
				)
				if committed_path is None:
					try_unlink(downloaded_path)
					return make_registry_candidate_result(cache_path, cache_context, True, registry)
				raw_path = committed_path
		rewrite_remote_registry(raw_path, cache_path, registry, issues)
		if downloaded_path is not None:
			try_unlink(downloaded_path)
		return make_registry_candidate_result(cache_path.resolve(), cache_context, True, registry)
	registry_path = resolve_tool_path(registry_value)
	registry_file_matches_metadata(registry_path, expected_sha, expected_size, issues)
	return make_registry_candidate_result(registry_path, cache_context, False, registry_value)


def make_registry_candidate_result(
	path: Path,
	cache_context: dict[str, Any],
	remote: bool,
	source: str,
) -> dict[str, Any]:
	return {
		"path": path,
		"cache_dir": cache_context.get("artifact_write_root"),
		"remote": remote,
		"source": source,
		"_cache_context": cache_context,
	}


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
	cache_context: dict[str, Any],
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
			cache_context,
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
		for package_id, entry in packages.items():
			if not isinstance(entry, dict):
				continue
			archive = str(entry.get("archive", "")).strip()
			if archive:
				resolved_archive = resolve_remote_archive_reference(str(package_id), archive, registry_url, issues)
				if resolved_archive:
					entry["archive"] = resolved_archive
	text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
	temp_path = cache_path.with_name(f"{cache_path.name}.tmp-{secrets.token_hex(8)}")
	try:
		cache_path.parent.mkdir(parents=True, exist_ok=True)
		temp_path.write_text(text, encoding="utf-8", newline="\n")
		os.replace(temp_path, cache_path)
	except OSError as error:
		try_unlink(temp_path)
		issues.append(f"Could not write cached registry: {error}")


def resolve_remote_archive_reference(
	package_id: str,
	archive: str,
	registry_url: str,
	issues: list[str],
) -> str:
	text = archive.strip()
	if not text:
		return ""
	if is_remote_url(text):
		return text
	if text.startswith(("res://", "user://", "//")) or ":" in text:
		issues.append(f"{package_id}: remote registry archive reference is not allowed: {text}")
		return ""

	parsed = urllib.parse.urlsplit(registry_url)
	if not parsed.scheme or not parsed.netloc:
		issues.append(f"{package_id}: remote registry archive base URL is invalid: {registry_url}")
		return ""
	registry_path = parsed.path or "/"
	if text.startswith("/"):
		joined_path = text
	else:
		base_dir = posixpath.dirname(registry_path)
		if not base_dir.startswith("/"):
			base_dir = "/" + base_dir
		if not base_dir.endswith("/"):
			base_dir += "/"
		joined_path = base_dir + text
	normalized_path = normalize_remote_url_path(joined_path)
	if not normalized_path:
		issues.append(f"{package_id}: remote registry archive path escapes the URL root: {text}")
		return ""
	return urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, normalized_path, "", ""))


def normalize_remote_url_path(path: str) -> str:
	segments: list[str] = []
	for segment in path.split("/"):
		if not segment or segment == ".":
			continue
		if segment == "..":
			if not segments:
				return ""
			segments.pop()
		else:
			segments.append(segment)
	return "/" + "/".join(segments)


def resolve_archive_path(
	archive_value: str,
	registry_path: Path,
	cache_context: dict[str, Any],
	package_id: str,
	entry: dict[str, Any],
	issues: list[str],
) -> Path | None:
	archive = archive_value.strip()
	if not archive:
		return registry_path.parent / ""
	if is_remote_url(archive):
		return cache_remote_archive(package_id, archive, entry, cache_context, issues)
	normalized = archive.replace("\\", "/")
	path = Path(normalized)
	if (
		normalized.startswith(("res://", "user://", "//"))
		or ":" in normalized
		or path.is_absolute()
	):
		issues.append(f"{package_id}: local archive must stay inside the trusted bundle: {archive}")
		return None
	resolved_path = (registry_path.parent / path).resolve()
	registry_root = registry_path.parent.resolve()
	sibling_packages_root = (registry_root.parent / "packages").resolve()
	if not any(resolved_path.is_relative_to(root) for root in (registry_root, sibling_packages_root)):
		issues.append(f"{package_id}: local archive must stay inside the trusted bundle: {archive}")
		return None
	lexical_path = gf_package_transaction.absolute_lexical_path(registry_path.parent / path)
	if gf_package_transaction.path_has_reparse_component(lexical_path):
		issues.append(f"{package_id}: local archive crosses a filesystem link inside the trusted bundle: {archive}")
		return None
	return resolved_path


def cache_remote_archive(
	package_id: str,
	archive_url: str,
	entry: dict[str, Any],
	cache_context: dict[str, Any],
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
	archive_path = gf_package_cache.find_artifact(cache_context, expected_sha, expected_size, ".zip")
	if archive_path is not None:
		return archive_path
	try:
		downloaded_path = gf_package_cache.make_workspace_temp_path(cache_context, "archive_downloads", ".zip")
	except ValueError as error:
		issues.append(f"{package_id}: {error}")
		return None
	if not download_url_to_file(
		archive_url,
		downloaded_path,
		f"{package_id} archive",
		issues,
		min(MAX_ARCHIVE_DOWNLOAD_BYTES, expected_size + 1),
	):
		return None
	if not archive_file_matches_metadata(downloaded_path, expected_sha, expected_size):
		try_unlink(downloaded_path)
		issues.append(f"{package_id}: downloaded archive does not match registry sha256 and size.")
		return None
	archive_path = gf_package_cache.commit_artifact(
		cache_context,
		downloaded_path,
		expected_sha,
		expected_size,
		".zip",
		issues,
	)
	try_unlink(downloaded_path)
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
	if gf_package_transaction.path_has_reparse_component(target_path):
		issues.append(f"{label}: download target crosses a filesystem link.")
		return False
	target_path.parent.mkdir(parents=True, exist_ok=True)
	temp_path = target_path.with_name(f"{target_path.name}.download-{secrets.token_hex(8)}")
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
	project_root_absolute = gf_package_transaction.absolute_lexical_path(project_root)
	target_absolute = gf_package_transaction.absolute_lexical_path(target_path)
	if not gf_package_transaction.path_is_inside_lexical(project_root_absolute, target_absolute):
		raise InstallFailure(f"Refusing to write outside project root: {relative_path}")
	if gf_package_transaction.path_has_reparse_component(project_root_absolute):
		raise InstallFailure(f"Project root crosses a filesystem link: {project_root_absolute.as_posix()}")
	if gf_package_transaction.path_has_reparse_component(target_absolute):
		raise InstallFailure(f"Package target crosses a filesystem link: {relative_path}")
	return target_absolute


def normalize_archive_name(name: str) -> str:
	if name != name.strip():
		return ""
	normalized = name.replace("\\", "/")
	if not normalized or normalized.startswith("/") or ":" in normalized:
		return ""
	parts = normalized.split("/")
	if any(
		part in {"", ".", ".."}
		or part != part.rstrip(" .")
		or any(ord(character) < 32 for character in part)
		for part in parts
	):
		return ""
	return "/".join(parts)


def portable_path_identity(path: str) -> str:
	normalized = normalize_archive_name(path)
	return normalized.lower() if normalized else ""


def path_matches_any_manifest_path(path: str, patterns: list[str]) -> bool:
	return shared_path_matches_any_manifest_path(path, patterns)


def normalize_manifest_path(path: str) -> str:
	return normalize_shared_manifest_path(path)


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
	lockfile_written: bool = False,
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
		"lockfile_written": ok and not dry_run and (lockfile_written or bool(installed_packages)),
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
	operation = str(result.get("operation", ""))
	transaction = registry_source.get("_transaction", {})
	result["transaction"] = transaction if isinstance(transaction, dict) and transaction else gf_package_transaction.empty_report(operation)
	transaction_recovery = registry_source.get("_transaction_recovery", {})
	result["transaction_recovery"] = (
		transaction_recovery
		if isinstance(transaction_recovery, dict) and transaction_recovery
		else gf_package_transaction.empty_report("recover")
	)
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
	cache_context = registry_source.get("_cache_context")
	if isinstance(cache_context, dict) and cache_context:
		cache_report = gf_package_cache.make_report(cache_context)
		result["cache"] = cache_report
		artifact_write_root = cache_context.get("artifact_write_root")
		if isinstance(artifact_write_root, Path):
			result["registry_cache_dir"] = display_path(artifact_write_root)


def resolve_tool_path(path: str) -> Path:
	resolved = Path(path)
	if not resolved.is_absolute():
		resolved = ROOT / resolved
	return resolved.resolve()


def resolve_project_path(path: str) -> Path:
	resolved = Path(path)
	if not resolved.is_absolute():
		resolved = ROOT / resolved
	return gf_package_transaction.absolute_lexical_path(resolved)


def resolve_project_lockfile_path(project_root: Path, lockfile_path: str) -> Path:
	path = Path(lockfile_path)
	if path.is_absolute():
		return gf_package_transaction.absolute_lexical_path(path)
	return gf_package_transaction.absolute_lexical_path(project_root / path)


def append_lockfile_path_issues(project_root: Path, resolved_lockfile_path: Path, raw_lockfile_path: str, issues: list[str]) -> None:
	if not raw_lockfile_path.strip():
		issues.append("Lockfile path is required.")
		return
	if gf_package_transaction.path_has_reparse_component(project_root):
		issues.append(f"Project root crosses a filesystem link: {project_root.as_posix()}")
		return
	if project_root.exists() and not project_root.is_dir():
		issues.append(f"Project root is not a directory: {project_root.as_posix()}")
		return
	if not gf_package_transaction.path_is_inside_lexical(project_root, resolved_lockfile_path):
		issues.append(f"Lockfile path must stay inside project root: {resolved_lockfile_path.as_posix()}")
	elif gf_package_transaction.path_has_reparse_component(resolved_lockfile_path):
		issues.append(f"Lockfile path crosses a filesystem link: {resolved_lockfile_path.as_posix()}")


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
	if result.get("operation") == "recover":
		print(
			f"recover: ok={result['ok']} "
			f"outcome={result.get('outcome', 'none')} "
			f"recovery_required={result.get('recovery_required', False)}"
		)
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
