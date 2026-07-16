#!/usr/bin/env python3
"""Durable package payload and lockfile transactions shared by GF maintenance tools."""

from __future__ import annotations

import ctypes
import hashlib
import json
import os
import re
import shutil
import stat
import sys
import time
from pathlib import Path
from typing import Any


SCHEMA_CONTRACT_PATH = (
	Path(__file__).resolve().parents[1]
	/ "addons/gf/kernel/package/gf_package_transaction_schema.json"
)
with SCHEMA_CONTRACT_PATH.open("r", encoding="utf-8") as schema_handle:
	SCHEMA_CONTRACT: dict[str, Any] = json.load(schema_handle)
SCHEMA_VERSION = int(SCHEMA_CONTRACT["schema_version"])
REPORT_SCHEMA_VERSION = int(SCHEMA_CONTRACT["report_schema_version"])
TRANSACTION_ROOT_RELATIVE_PATH = Path(".gf/package_transactions")
ACTIVE_DIRECTORY_NAME = "active"
CANDIDATE_PREFIX = "candidate-"
CLEANUP_PREFIX = "cleanup-"
JOURNAL_PREFIX = "journal-"
JOURNAL_SUFFIX = ".json"
LOCKFILE_ORIGINAL_NAME = "lockfile-original.json"
LOCKFILE_PLANNED_NAME = "lockfile-planned.json"
BACKUP_DIRECTORY_NAME = "backups"
PACKAGE_ROOT_PREFIX = "addons/gf/"
FILE_ATTRIBUTE_REPARSE_POINT = 0x0400
TRANSACTION_ID_RE = re.compile(r"^[A-Za-z0-9_-]{1,128}$")
PHASE_PREPARING = "preparing"
PHASE_PREPARED = "prepared"
PHASE_APPLYING = "applying_payload"
PHASE_PAYLOAD_APPLIED = "payload_applied"
PHASE_COMMITTING = "committing_lockfile"
PHASE_COMMITTED = "committed"
PHASE_ROLLING_BACK = "rolling_back"
PHASE_RECOVERY_FAILED = "recovery_failed"
OUTCOME_NONE = "none"
OUTCOME_COMMITTED = "committed"
OUTCOME_ROLLED_BACK = "rolled_back"
OUTCOME_PENDING_RECOVERY = "pending_recovery"
OUTCOME_RECOVERED_COMMIT = "recovered_commit"
OUTCOME_RECOVERED_ROLLBACK = "recovered_rollback"
OUTCOME_RECOVERED_ABANDONED = "recovered_abandoned"
OUTCOME_BLOCKED = "blocked"
OUTCOME_RECOVERY_FAILED = "recovery_failed"
VALID_OPERATIONS = {str(value) for value in SCHEMA_CONTRACT["operations"]}
VALID_PHASES = {str(value) for value in SCHEMA_CONTRACT["phases"]}
VALID_OUTCOMES = {str(value) for value in SCHEMA_CONTRACT["outcomes"]}
REQUEST_REQUIRED_FIELDS = {str(value) for value in SCHEMA_CONTRACT["request_required_fields"]}
JOURNAL_REQUIRED_FIELDS = {str(value) for value in SCHEMA_CONTRACT["journal_required_fields"]}
REPORT_FIELDS = {str(value) for value in SCHEMA_CONTRACT["report_fields"]}

if {
	PHASE_PREPARING,
	PHASE_PREPARED,
	PHASE_APPLYING,
	PHASE_PAYLOAD_APPLIED,
	PHASE_COMMITTING,
	PHASE_COMMITTED,
	PHASE_ROLLING_BACK,
	PHASE_RECOVERY_FAILED,
} != VALID_PHASES:
	raise RuntimeError("Package transaction phase constants drifted from the shared schema contract.")
if {
	OUTCOME_NONE,
	OUTCOME_COMMITTED,
	OUTCOME_ROLLED_BACK,
	OUTCOME_PENDING_RECOVERY,
	OUTCOME_RECOVERED_COMMIT,
	OUTCOME_RECOVERED_ROLLBACK,
	OUTCOME_RECOVERED_ABANDONED,
	OUTCOME_BLOCKED,
	OUTCOME_RECOVERY_FAILED,
} != VALID_OUTCOMES:
	raise RuntimeError("Package transaction outcome constants drifted from the shared schema contract.")


class TransactionFailure(RuntimeError):
	"""Raised after a transaction has been claimed so the engine can roll it back."""


def make_request(
	operation: str,
	project_root: Path,
	lockfile_path: Path,
	planned_lockfile: dict[str, Any],
	writes: list[dict[str, Any]] | None = None,
	deletes: list[dict[str, Any]] | None = None,
	cleanup_paths: list[Path] | None = None,
) -> dict[str, Any]:
	return {
		"schema_version": SCHEMA_VERSION,
		"operation": operation,
		"project_root": str(project_root),
		"lockfile_path": str(lockfile_path),
		"planned_lockfile": planned_lockfile,
		"writes": writes or [],
		"deletes": deletes or [],
		"cleanup_paths": [str(path) for path in cleanup_paths or []],
	}


def execute(
	request: dict[str, Any],
	*,
	simulate_copy_failure_after: int = 0,
	simulate_delete_failure_after: int = 0,
	simulate_transaction_failure_at: str = "",
	simulate_transaction_crash_at: str = "",
) -> dict[str, Any]:
	issues: list[str] = []
	normalized_request = normalize_request(request, issues)
	operation = str(normalized_request.get("operation", ""))
	if issues:
		return make_report(False, "", operation, "", OUTCOME_BLOCKED, issues=issues, recovery_required=False)

	project_root = Path(normalized_request["project_root"])
	recovery = recover_pending(project_root)
	if not recovery["ok"]:
		return make_report(
			False,
			"",
			operation,
			"",
			OUTCOME_BLOCKED,
			issues=string_list(recovery.get("issues", [])),
			recovery_required=True,
		)

	claim = claim_transaction(normalized_request, issues)
	if not claim.get("ok"):
		return make_report(False, "", operation, "", OUTCOME_BLOCKED, issues=issues, recovery_required=True)
	active_root = Path(claim["active_root"])
	journal = dictionary(claim["journal"])
	transaction_id = str(journal["transaction_id"])

	try:
		prepare_transaction(active_root, journal, normalized_request)
	except Exception as error:
		issues.append(f"Could not prepare package transaction: {error}")
		cleanup_issues: list[str] = []
		cleanup_ok = cleanup_active_transaction(active_root, journal, cleanup_issues)
		issues.extend(cleanup_issues)
		if not cleanup_ok:
			mark_abandoned(active_root, journal)
		return make_report(
			False,
			transaction_id,
			operation,
			str(journal.get("phase", "")),
			OUTCOME_ROLLED_BACK,
			rolled_back=cleanup_ok,
			recovery_required=not cleanup_ok,
			issues=issues,
		)

	if simulate_transaction_crash_at == "after_prepared":
		mark_abandoned(active_root, journal)
		return make_report(
			False,
			transaction_id,
			operation,
			PHASE_PREPARED,
			OUTCOME_PENDING_RECOVERY,
			recovery_required=True,
		)

	write_count = 0
	delete_count = 0
	try:
		write_phase(active_root, journal, PHASE_APPLYING)
		write_count, delete_count = apply_payload(
			journal,
			normalized_request,
			simulate_copy_failure_after,
			simulate_delete_failure_after,
		)
		write_phase(active_root, journal, PHASE_PAYLOAD_APPLIED)
		if simulate_transaction_crash_at == "after_payload_applied":
			mark_abandoned(active_root, journal)
			return make_report(
				False,
				transaction_id,
				operation,
				PHASE_PAYLOAD_APPLIED,
				OUTCOME_PENDING_RECOVERY,
				write_count=write_count,
				delete_count=delete_count,
				recovery_required=True,
			)
		write_phase(active_root, journal, PHASE_COMMITTING)
		if simulate_transaction_failure_at == "before_lockfile_replace":
			raise TransactionFailure("Simulated package transaction failure before lockfile replace.")
		commit_lockfile(active_root, journal)
		if simulate_transaction_crash_at == "after_lockfile_replace":
			mark_abandoned(active_root, journal)
			return make_report(
				False,
				transaction_id,
				operation,
				PHASE_COMMITTING,
				OUTCOME_PENDING_RECOVERY,
				write_count=write_count,
				delete_count=delete_count,
				lockfile_written=True,
				recovery_required=True,
			)
		write_phase(active_root, journal, PHASE_COMMITTED)
		if simulate_transaction_crash_at == "after_lockfile_committed":
			mark_abandoned(active_root, journal)
			return make_report(
				False,
				transaction_id,
				operation,
				PHASE_COMMITTED,
				OUTCOME_PENDING_RECOVERY,
				write_count=write_count,
				delete_count=delete_count,
				lockfile_written=True,
				recovery_required=True,
			)
	except Exception as error:
		issues.append(str(error) if isinstance(error, TransactionFailure) else f"Package transaction failed: {error}")
		return rollback_after_failure(
			active_root,
			journal,
			operation,
			write_count,
			delete_count,
			issues,
		)

	warnings: list[str] = []
	cleanup_ok = cleanup_active_transaction(active_root, journal, warnings)
	return make_report(
		True,
		transaction_id,
		operation,
		PHASE_COMMITTED,
		OUTCOME_COMMITTED,
		write_count=write_count,
		delete_count=delete_count,
		lockfile_written=True,
		recovery_required=not cleanup_ok,
		warnings=warnings,
	)


def recover_pending(project_root: Path, force_current_process: bool = False) -> dict[str, Any]:
	normalized_root = absolute_lexical_path(project_root)
	if path_has_reparse_component(normalized_root):
		return make_report(
			False,
			"",
			"recover",
			"",
			OUTCOME_BLOCKED,
			issues=[f"Package transaction project root crosses a filesystem link: {normalized_root.as_posix()}"],
			recovery_required=True,
		)
	if normalized_root.exists() and not normalized_root.is_dir():
		return make_report(
			False,
			"",
			"recover",
			"",
			OUTCOME_BLOCKED,
			issues=[f"Package transaction project root is not a directory: {normalized_root.as_posix()}"],
			recovery_required=True,
		)
	if not normalized_root.is_dir():
		return empty_report("recover")
	transaction_root = normalized_root / TRANSACTION_ROOT_RELATIVE_PATH
	if path_has_reparse_component(transaction_root):
		return make_report(
			False,
			"",
			"recover",
			"",
			OUTCOME_RECOVERY_FAILED,
			issues=[f"Package transaction directory crosses a filesystem link: {transaction_root.as_posix()}"],
			recovery_required=True,
		)
	if os.path.lexists(transaction_root) and not transaction_root.is_dir():
		return make_report(
			False,
			"",
			"recover",
			"",
			OUTCOME_RECOVERY_FAILED,
			issues=[f"Package transaction path is not a directory: {transaction_root.as_posix()}"],
			recovery_required=True,
		)
	candidate_cleanup_issues = cleanup_abandoned_candidates(transaction_root)
	if candidate_cleanup_issues:
		return make_report(
			False,
			"",
			"recover",
			"",
			OUTCOME_RECOVERY_FAILED,
			issues=candidate_cleanup_issues,
			recovery_required=True,
		)
	active_root = transaction_root / ACTIVE_DIRECTORY_NAME
	if not os.path.lexists(active_root):
		return empty_report("recover")
	if path_has_reparse_component(active_root) or not active_root.is_dir():
		return make_report(
			False,
			"",
			"recover",
			"",
			OUTCOME_RECOVERY_FAILED,
			issues=[f"Active package transaction path is not a safe directory: {active_root.as_posix()}"],
			recovery_required=True,
		)

	issues: list[str] = []
	journal = read_latest_journal(active_root, issues, normalized_root)
	if not journal:
		if not issues:
			issues.append(f"Package transaction directory exists without a valid journal: {active_root.as_posix()}")
		return make_report(False, "", "recover", "", OUTCOME_RECOVERY_FAILED, issues=issues, recovery_required=True)

	transaction_id = str(journal.get("transaction_id", ""))
	operation = str(journal.get("operation", ""))
	phase = str(journal.get("phase", ""))
	journal_project_root = absolute_lexical_path(Path(str(journal.get("project_root", ""))))
	if journal_project_root != normalized_root:
		issues.append("Package transaction journal project root does not match the requested project.")
		return make_report(False, transaction_id, operation, phase, OUTCOME_RECOVERY_FAILED, issues=issues, recovery_required=True)
	if transaction_owner_is_running(journal) and not force_current_process:
		issues.append(f"Another live process owns the active package transaction: {transaction_id}")
		return make_report(False, transaction_id, operation, phase, OUTCOME_BLOCKED, issues=issues, recovery_required=True)

	write_count = len(list_value(journal.get("writes", [])))
	delete_count = len(list_value(journal.get("deletes", [])))
	if phase == PHASE_PREPARING:
		cleanup_ok = cleanup_active_transaction(active_root, journal, issues)
		return make_report(
			cleanup_ok,
			transaction_id,
			operation,
			phase,
			OUTCOME_RECOVERED_ABANDONED if cleanup_ok else OUTCOME_RECOVERY_FAILED,
			recovered=True,
			recovery_required=not cleanup_ok,
			issues=issues,
		)

	recovery_warnings: list[str] = []
	if phase == PHASE_COMMITTED:
		committed_issues: list[str] = []
		if verify_committed_state(journal, committed_issues):
			cleanup_ok = cleanup_active_transaction(active_root, journal, issues)
			return make_report(
				cleanup_ok,
				transaction_id,
				operation,
				phase,
				OUTCOME_RECOVERED_COMMIT if cleanup_ok else OUTCOME_RECOVERY_FAILED,
				write_count=write_count,
				delete_count=delete_count,
				lockfile_written=True,
				recovered=True,
				recovery_required=not cleanup_ok,
				issues=issues,
			)
		recovery_warnings.extend(committed_issues)

	rollback_issues: list[str] = []
	rollback_ok = rollback_state(active_root, journal, rollback_issues)
	issues.extend(rollback_issues)
	if rollback_ok:
		rollback_ok = cleanup_active_transaction(active_root, journal, issues)
	else:
		try:
			write_phase(active_root, journal, PHASE_RECOVERY_FAILED)
		except Exception as error:
			issues.append(f"Could not persist package recovery failure state: {error}")
	return make_report(
		rollback_ok,
		transaction_id,
		operation,
		phase,
		OUTCOME_RECOVERED_ROLLBACK if rollback_ok else OUTCOME_RECOVERY_FAILED,
		write_count=write_count,
		delete_count=delete_count,
		rolled_back=rollback_ok,
		recovered=True,
		recovery_required=not rollback_ok,
		issues=issues,
		warnings=recovery_warnings,
	)


def empty_report(operation: str = "") -> dict[str, Any]:
	return make_report(True, "", operation, "", OUTCOME_NONE)


def normalize_request(request: dict[str, Any], issues: list[str]) -> dict[str, Any]:
	for field_name in sorted(REQUEST_REQUIRED_FIELDS - set(request.keys())):
		issues.append(f"Package transaction request is missing required field: {field_name}")
	if int_value(request.get("schema_version", 0)) != SCHEMA_VERSION:
		issues.append("Unsupported package transaction request schema_version.")
		return {}
	operation = str(request.get("operation", "")).strip()
	if operation not in VALID_OPERATIONS:
		issues.append(f"Invalid package transaction operation: {operation}")
	raw_project_root = str(request.get("project_root", "")).strip()
	raw_lockfile_path = str(request.get("lockfile_path", "")).strip()
	if not raw_project_root:
		issues.append("Package transaction project root is invalid.")
	if not raw_lockfile_path:
		issues.append("Package transaction lockfile path is invalid.")
	project_root = absolute_lexical_path(Path(raw_project_root or ".").expanduser())
	lockfile_path = absolute_lexical_path(Path(raw_lockfile_path or ".").expanduser())
	if path_has_reparse_component(project_root):
		issues.append(f"Package transaction project root crosses a filesystem link: {project_root.as_posix()}")
	elif project_root.exists() and not project_root.is_dir():
		issues.append(f"Package transaction project root is not a directory: {project_root.as_posix()}")
	if not path_is_inside_lexical(project_root, lockfile_path):
		issues.append(f"Package transaction lockfile must stay inside project root: {lockfile_path.as_posix()}")
	elif path_has_reparse_component(lockfile_path):
		issues.append(f"Package transaction lockfile path crosses a filesystem link: {lockfile_path.as_posix()}")
	transaction_root = project_root / TRANSACTION_ROOT_RELATIVE_PATH
	if path_is_inside_lexical(transaction_root, lockfile_path):
		issues.append("Package lockfile cannot be stored inside the package transaction directory.")
	planned_lockfile = dictionary(request.get("planned_lockfile", {}))

	writes: list[dict[str, Any]] = []
	deletes: list[dict[str, Any]] = []
	seen_paths: set[str] = set()
	for raw_entry in list_value(request.get("writes", [])):
		entry = dictionary(raw_entry)
		relative_path = normalize_payload_relative_path(str(entry.get("relative_path", "")))
		source_path = absolute_lexical_path(Path(str(entry.get("source_path", ""))).expanduser())
		path_key = portable_path_identity(relative_path)
		if not relative_path or not source_path.is_file() or path_has_reparse_component(source_path):
			issues.append(f"Invalid package transaction write entry: {entry.get('relative_path', '')}")
			continue
		if path_key in seen_paths:
			issues.append(f"Duplicate package transaction payload path: {relative_path}")
			continue
		seen_paths.add(path_key)
		validate_payload_target(project_root, relative_path, issues)
		writes.append({"relative_path": relative_path, "source_path": source_path.as_posix()})
	for raw_entry in list_value(request.get("deletes", [])):
		entry = dictionary(raw_entry)
		relative_path = normalize_payload_relative_path(str(entry.get("relative_path", "")))
		path_key = portable_path_identity(relative_path)
		if not relative_path:
			issues.append(f"Invalid package transaction delete entry: {entry.get('relative_path', '')}")
			continue
		if path_key in seen_paths:
			issues.append(f"Duplicate package transaction payload path: {relative_path}")
			continue
		seen_paths.add(path_key)
		validate_payload_target(project_root, relative_path, issues)
		deletes.append({"relative_path": relative_path})

	cleanup_paths: list[str] = []
	project_internal_root = project_root / ".gf"
	for raw_path in string_list(request.get("cleanup_paths", [])):
		cleanup_path = absolute_lexical_path(Path(raw_path).expanduser())
		if cleanup_path == project_internal_root or not path_is_inside_lexical(project_internal_root, cleanup_path):
			issues.append(f"Package transaction cleanup path must stay below project_root/.gf: {raw_path}")
			continue
		if path_is_inside_lexical(transaction_root, cleanup_path) or path_is_inside_lexical(cleanup_path, transaction_root):
			issues.append(f"Package transaction cleanup path cannot overlap the transaction directory: {raw_path}")
			continue
		if path_has_reparse_component(cleanup_path):
			issues.append(f"Package transaction cleanup path crosses a filesystem link: {raw_path}")
			continue
		if cleanup_path.as_posix() not in cleanup_paths:
			cleanup_paths.append(cleanup_path.as_posix())
	if issues:
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"operation": operation,
		"project_root": project_root.as_posix(),
		"lockfile_path": lockfile_path.as_posix(),
		"planned_lockfile": planned_lockfile,
		"writes": writes,
		"deletes": deletes,
		"cleanup_paths": cleanup_paths,
	}


def claim_transaction(request: dict[str, Any], issues: list[str]) -> dict[str, Any]:
	project_root = Path(str(request["project_root"]))
	transaction_root = project_root / TRANSACTION_ROOT_RELATIVE_PATH
	try:
		transaction_root.mkdir(parents=True, exist_ok=True)
	except OSError as error:
		issues.append(f"Could not create package transaction root: {error}")
		return {"ok": False}
	if path_has_reparse_component(transaction_root):
		issues.append(f"Package transaction root crosses a filesystem link: {transaction_root.as_posix()}")
		return {"ok": False}
	transaction_id = f"{os.getpid()}-{time.time_ns()}"
	candidate_root = transaction_root / f"{CANDIDATE_PREFIX}{transaction_id}"
	try:
		candidate_root.mkdir()
	except OSError as error:
		issues.append(f"Could not create package transaction candidate: {error}")
		return {"ok": False}
	if path_has_reparse_component(candidate_root):
		issues.append(f"Package transaction candidate crosses a filesystem link: {candidate_root.as_posix()}")
		return {"ok": False}
	journal: dict[str, Any] = {
		"schema_version": SCHEMA_VERSION,
		"sequence": -1,
		"transaction_id": transaction_id,
		"operation": request["operation"],
		"phase": PHASE_PREPARING,
		"owner_pid": os.getpid(),
		"project_root": request["project_root"],
		"lockfile_path": request["lockfile_path"],
		"lockfile_had_original": False,
		"lockfile_original_sha256": "",
		"lockfile_planned_sha256": "",
		"writes": [],
		"deletes": [],
		"cleanup_paths": request["cleanup_paths"],
		"started_unix_time": int(time.time()),
	}
	try:
		write_journal_snapshot(candidate_root, journal)
		active_root = transaction_root / ACTIVE_DIRECTORY_NAME
		assert_path_without_reparse(candidate_root, "package transaction candidate")
		assert_path_without_reparse(active_root, "active package transaction directory")
		if os.path.lexists(active_root):
			raise TransactionFailure(f"Active package transaction path already exists: {active_root.as_posix()}")
		os.rename(candidate_root, active_root)
	except (OSError, TransactionFailure) as error:
		try:
			remove_path(candidate_root)
		except (OSError, TransactionFailure):
			pass
		issues.append(f"Could not claim package transaction; another transaction may be active: {error}")
		return {"ok": False}
	return {"ok": True, "active_root": active_root.as_posix(), "journal": journal}


def prepare_transaction(
	active_root: Path,
	journal: dict[str, Any],
	request: dict[str, Any],
) -> None:
	planned_path = active_root / LOCKFILE_PLANNED_NAME
	write_json_file(planned_path, dictionary(request["planned_lockfile"]))
	journal["lockfile_planned_sha256"] = sha256_file(planned_path)

	lockfile_path = lockfile_target_path(journal)
	assert_path_without_reparse(lockfile_path, "package transaction lockfile")
	journal["lockfile_had_original"] = lockfile_path.is_file()
	if lockfile_path.is_file():
		original_path = active_root / LOCKFILE_ORIGINAL_NAME
		copy_file_verified(lockfile_path, original_path)
		journal["lockfile_original_sha256"] = sha256_file(original_path)

	prepared_writes: list[dict[str, Any]] = []
	for entry in list_value(request["writes"]):
		prepared = prepare_payload_entry(active_root, journal, dictionary(entry), "write")
		source_path = Path(str(dictionary(entry)["source_path"]))
		prepared["expected_sha256"] = sha256_file(source_path)
		prepared["expected_size_bytes"] = source_path.stat().st_size
		prepared_writes.append(prepared)
	prepared_deletes = [
		prepare_payload_entry(active_root, journal, dictionary(entry), "delete")
		for entry in list_value(request["deletes"])
	]
	journal["writes"] = prepared_writes
	journal["deletes"] = prepared_deletes
	write_phase(active_root, journal, PHASE_PREPARED)


def prepare_payload_entry(
	active_root: Path,
	journal: dict[str, Any],
	entry: dict[str, Any],
	action: str,
) -> dict[str, Any]:
	relative_path = str(entry["relative_path"])
	target_path = payload_target_path(journal, entry)
	assert_path_without_reparse(target_path, "package transaction payload target")
	if target_path.is_dir():
		raise TransactionFailure(f"Package transaction target is a directory: {relative_path}")
	prepared: dict[str, Any] = {
		"action": action,
		"relative_path": relative_path,
		"original_exists": target_path.is_file(),
		"original_sha256": "",
		"original_size_bytes": 0,
		"backup_relative_path": "",
	}
	if not target_path.is_file():
		return prepared
	backup_relative_path = Path(BACKUP_DIRECTORY_NAME) / Path(*relative_path.split("/"))
	backup_path = active_root / backup_relative_path
	copy_file_verified(target_path, backup_path)
	prepared["original_sha256"] = sha256_file(backup_path)
	prepared["original_size_bytes"] = backup_path.stat().st_size
	prepared["backup_relative_path"] = backup_relative_path.as_posix()
	return prepared


def apply_payload(
	journal: dict[str, Any],
	request: dict[str, Any],
	simulate_copy_failure_after: int,
	simulate_delete_failure_after: int,
) -> tuple[int, int]:
	source_paths = {
		str(dictionary(entry)["relative_path"]): Path(str(dictionary(entry)["source_path"]))
		for entry in list_value(request["writes"])
	}
	write_count = 0
	for raw_entry in list_value(journal["writes"]):
		entry = dictionary(raw_entry)
		apply_write(journal, entry, source_paths[str(entry["relative_path"])])
		write_count += 1
		if simulate_copy_failure_after > 0 and write_count >= simulate_copy_failure_after:
			raise TransactionFailure("Simulated package install copy failure.")
	delete_count = 0
	for raw_entry in list_value(journal["deletes"]):
		entry = dictionary(raw_entry)
		apply_delete(journal, entry)
		if bool(entry.get("original_exists", False)):
			delete_count += 1
		if simulate_delete_failure_after > 0 and delete_count >= simulate_delete_failure_after:
			raise TransactionFailure("Simulated package uninstall delete failure.")
	return write_count, delete_count


def apply_write(journal: dict[str, Any], entry: dict[str, Any], source_path: Path) -> None:
	expected_sha = str(entry["expected_sha256"])
	expected_size = int_value(entry["expected_size_bytes"])
	if not file_matches(source_path, expected_sha, expected_size):
		raise TransactionFailure(f"Package transaction staged source changed after preparation: {source_path.as_posix()}")
	target_path = payload_target_path(journal, entry)
	assert_path_without_reparse(target_path, "package transaction write target")
	temp_path = payload_temp_path(target_path, str(journal["transaction_id"]))
	copy_file_verified(source_path, temp_path)
	target_path.parent.mkdir(parents=True, exist_ok=True)
	assert_path_without_reparse(target_path, "package transaction write target")
	assert_path_without_reparse(temp_path, "package transaction write temporary target")
	os.replace(temp_path, target_path)
	if not file_matches(target_path, expected_sha, expected_size):
		raise TransactionFailure(f"Committed package payload failed verification: {target_path.as_posix()}")


def apply_delete(journal: dict[str, Any], entry: dict[str, Any]) -> None:
	target_path = payload_target_path(journal, entry)
	assert_path_without_reparse(target_path, "package transaction delete target")
	if target_path.is_dir():
		raise TransactionFailure(f"Refusing to delete directory as package payload: {target_path.as_posix()}")
	if target_path.is_file():
		target_path.unlink()


def commit_lockfile(active_root: Path, journal: dict[str, Any]) -> None:
	planned_path = active_root / LOCKFILE_PLANNED_NAME
	lockfile_path = lockfile_target_path(journal)
	assert_path_without_reparse(lockfile_path, "package transaction lockfile")
	temp_path = lockfile_temp_path(lockfile_path, str(journal["transaction_id"]))
	copy_file_verified(planned_path, temp_path)
	lockfile_path.parent.mkdir(parents=True, exist_ok=True)
	assert_path_without_reparse(lockfile_path, "package transaction lockfile")
	assert_path_without_reparse(temp_path, "package transaction lockfile temporary target")
	os.replace(temp_path, lockfile_path)
	if not file_matches(lockfile_path, str(journal["lockfile_planned_sha256"]), planned_path.stat().st_size):
		raise TransactionFailure(f"Committed package lockfile failed verification: {lockfile_path.as_posix()}")


def rollback_after_failure(
	active_root: Path,
	journal: dict[str, Any],
	operation: str,
	write_count: int,
	delete_count: int,
	issues: list[str],
) -> dict[str, Any]:
	try:
		write_phase(active_root, journal, PHASE_ROLLING_BACK)
	except Exception as error:
		issues.append(f"Could not persist package rollback phase: {error}")
	rollback_issues: list[str] = []
	rollback_ok = rollback_state(active_root, journal, rollback_issues)
	issues.extend(rollback_issues)
	if rollback_ok:
		rollback_ok = cleanup_active_transaction(active_root, journal, issues)
	else:
		try:
			write_phase(active_root, journal, PHASE_RECOVERY_FAILED)
		except Exception as error:
			issues.append(f"Could not persist package recovery failure state: {error}")
	return make_report(
		False,
		str(journal["transaction_id"]),
		operation,
		str(journal.get("phase", "")),
		OUTCOME_ROLLED_BACK if rollback_ok else OUTCOME_RECOVERY_FAILED,
		write_count=write_count,
		delete_count=delete_count,
		rolled_back=rollback_ok,
		recovery_required=not rollback_ok,
		issues=issues,
	)


def rollback_state(active_root: Path, journal: dict[str, Any], issues: list[str]) -> bool:
	conflict_issues = rollback_conflict_issues(journal)
	if conflict_issues:
		issues.extend(conflict_issues)
		return False
	entries = list_value(journal.get("deletes", [])) + list_value(journal.get("writes", []))
	for raw_entry in reversed(entries):
		try:
			restore_payload_entry(active_root, journal, dictionary(raw_entry))
		except Exception as error:
			issues.append(f"Could not restore package payload: {error}")
	try:
		restore_lockfile(active_root, journal)
	except Exception as error:
		issues.append(f"Could not restore package lockfile: {error}")
	return verify_original_state(journal, issues)


def restore_payload_entry(active_root: Path, journal: dict[str, Any], entry: dict[str, Any]) -> None:
	target_path = payload_target_path(journal, entry)
	assert_path_without_reparse(target_path, "package rollback target")
	temp_path = payload_temp_path(target_path, str(journal["transaction_id"]))
	assert_path_without_reparse(temp_path, "package rollback temporary target")
	temp_path.unlink(missing_ok=True)
	if payload_matches_original_state(target_path, entry):
		return
	if not payload_matches_planned_state(target_path, entry):
		raise TransactionFailure(
			f"Package rollback target changed outside the transaction: {entry.get('relative_path', '')}"
		)
	if bool(entry.get("original_exists", False)):
		backup_path = active_root / str(entry["backup_relative_path"])
		assert_path_without_reparse(backup_path, "package rollback backup")
		restore_file_from_snapshot(backup_path, target_path, str(journal["transaction_id"]))
		return
	if target_path.is_file():
		target_path.unlink()
	remove_empty_parents(target_path.parent, journal_project_root(journal))


def restore_lockfile(active_root: Path, journal: dict[str, Any]) -> None:
	lockfile_path = lockfile_target_path(journal)
	assert_path_without_reparse(lockfile_path, "package rollback lockfile")
	temp_path = lockfile_temp_path(lockfile_path, str(journal["transaction_id"]))
	assert_path_without_reparse(temp_path, "package rollback lockfile temporary target")
	temp_path.unlink(missing_ok=True)
	if lockfile_matches_original_state(lockfile_path, journal):
		return
	if not lockfile_matches_planned_state(lockfile_path, journal):
		raise TransactionFailure("Package rollback lockfile changed outside the transaction.")
	if bool(journal.get("lockfile_had_original", False)):
		restore_file_from_snapshot(active_root / LOCKFILE_ORIGINAL_NAME, lockfile_path, str(journal["transaction_id"]))
	elif lockfile_path.is_file():
		lockfile_path.unlink()


def restore_file_from_snapshot(snapshot_path: Path, target_path: Path, transaction_id: str) -> None:
	if not snapshot_path.is_file():
		raise TransactionFailure(f"Missing transaction snapshot: {snapshot_path.as_posix()}")
	assert_path_without_reparse(snapshot_path, "package transaction snapshot")
	assert_path_without_reparse(target_path, "package transaction restore target")
	temp_path = target_path.with_name(f"{target_path.name}.gf-package-restore-{transaction_id}.tmp")
	copy_file_verified(snapshot_path, temp_path)
	target_path.parent.mkdir(parents=True, exist_ok=True)
	assert_path_without_reparse(snapshot_path, "package transaction snapshot")
	assert_path_without_reparse(target_path, "package transaction restore target")
	assert_path_without_reparse(temp_path, "package transaction restore temporary target")
	os.replace(temp_path, target_path)


def rollback_conflict_issues(journal: dict[str, Any]) -> list[str]:
	issues: list[str] = []
	for raw_entry in list_value(journal.get("writes", [])) + list_value(journal.get("deletes", [])):
		entry = dictionary(raw_entry)
		try:
			target_path = payload_target_path(journal, entry)
		except TransactionFailure as error:
			issues.append(str(error))
			continue
		if path_has_reparse_component(target_path):
			issues.append(f"Package rollback target crosses a filesystem link: {entry.get('relative_path', '')}")
			continue
		if not payload_matches_original_state(target_path, entry) and not payload_matches_planned_state(target_path, entry):
			issues.append(
				f"Package rollback conflict; target matches neither original nor planned state: {entry.get('relative_path', '')}"
			)
	try:
		lockfile_path = lockfile_target_path(journal)
	except TransactionFailure as error:
		issues.append(str(error))
		return issues
	if path_has_reparse_component(lockfile_path):
		issues.append("Package rollback lockfile path crosses a filesystem link.")
	elif not lockfile_matches_original_state(lockfile_path, journal) and not lockfile_matches_planned_state(lockfile_path, journal):
		issues.append("Package rollback conflict; lockfile matches neither original nor planned state.")
	return issues


def payload_matches_original_state(target_path: Path, entry: dict[str, Any]) -> bool:
	if bool(entry.get("original_exists", False)):
		return file_matches(
			target_path,
			str(entry.get("original_sha256", "")),
			int_value(entry.get("original_size_bytes", -1), -1),
		)
	return not target_path.exists()


def payload_matches_planned_state(target_path: Path, entry: dict[str, Any]) -> bool:
	if str(entry.get("action", "")) == "write":
		return file_matches(
			target_path,
			str(entry.get("expected_sha256", "")),
			int_value(entry.get("expected_size_bytes", -1), -1),
		)
	return not target_path.exists()


def lockfile_matches_original_state(lockfile_path: Path, journal: dict[str, Any]) -> bool:
	if bool(journal.get("lockfile_had_original", False)):
		return file_matches(lockfile_path, str(journal.get("lockfile_original_sha256", "")), -1)
	return not lockfile_path.exists()


def lockfile_matches_planned_state(lockfile_path: Path, journal: dict[str, Any]) -> bool:
	return file_matches(lockfile_path, str(journal.get("lockfile_planned_sha256", "")), -1)


def verify_committed_state(journal: dict[str, Any], issues: list[str]) -> bool:
	try:
		lockfile_path = lockfile_target_path(journal)
	except TransactionFailure as error:
		issues.append(str(error))
		return False
	if not file_matches(lockfile_path, str(journal.get("lockfile_planned_sha256", "")), -1):
		issues.append("Committed package transaction lockfile no longer matches its planned snapshot.")
		return False
	for raw_entry in list_value(journal.get("writes", [])):
		entry = dictionary(raw_entry)
		try:
			target_path = payload_target_path(journal, entry)
		except TransactionFailure as error:
			issues.append(str(error))
			return False
		if not file_matches(target_path, str(entry.get("expected_sha256", "")), int_value(entry.get("expected_size_bytes", -1), -1)):
			issues.append(f"Committed package payload does not match journal: {entry.get('relative_path', '')}")
			return False
	for raw_entry in list_value(journal.get("deletes", [])):
		entry = dictionary(raw_entry)
		try:
			target_path = payload_target_path(journal, entry)
		except TransactionFailure as error:
			issues.append(str(error))
			return False
		if target_path.exists():
			issues.append(f"Committed package delete target still exists: {entry.get('relative_path', '')}")
			return False
	return True


def verify_original_state(journal: dict[str, Any], issues: list[str]) -> bool:
	entries = list_value(journal.get("writes", [])) + list_value(journal.get("deletes", []))
	for raw_entry in entries:
		entry = dictionary(raw_entry)
		try:
			target_path = payload_target_path(journal, entry)
		except TransactionFailure as error:
			issues.append(str(error))
			continue
		if bool(entry.get("original_exists", False)):
			if not file_matches(
				target_path,
				str(entry.get("original_sha256", "")),
				int_value(entry.get("original_size_bytes", -1)),
			):
				issues.append(f"Rolled-back package payload does not match original snapshot: {entry.get('relative_path', '')}")
		elif target_path.exists():
			issues.append(f"Rolled-back package payload still exists: {entry.get('relative_path', '')}")
	try:
		lockfile_path = lockfile_target_path(journal)
	except TransactionFailure as error:
		issues.append(str(error))
		return False
	if bool(journal.get("lockfile_had_original", False)):
		if not file_matches(lockfile_path, str(journal.get("lockfile_original_sha256", "")), -1):
			issues.append("Rolled-back package lockfile does not match original snapshot.")
	elif lockfile_path.exists():
		issues.append("Rolled-back package lockfile still exists.")
	return not issues


def cleanup_active_transaction(active_root: Path, journal: dict[str, Any], issues: list[str]) -> bool:
	if not active_root.is_dir():
		return True
	project_root = journal_project_root(journal)
	transaction_root = project_root / TRANSACTION_ROOT_RELATIVE_PATH
	validated_cleanup_paths: list[Path] = []
	for raw_path in strict_string_list(journal.get("cleanup_paths", [])):
		cleanup_path = validate_cleanup_path(project_root, transaction_root, raw_path)
		if cleanup_path is None:
			issues.append(f"Package transaction journal contains an unsafe cleanup path: {raw_path}")
			continue
		validated_cleanup_paths.append(cleanup_path)
	if len(validated_cleanup_paths) != len(list_value(journal.get("cleanup_paths", []))):
		return False
	cleanup_root = active_root.parent / f"{CLEANUP_PREFIX}{journal.get('transaction_id', '')}"
	if os.path.lexists(cleanup_root):
		cleanup_root = cleanup_root.with_name(f"{cleanup_root.name}-{time.time_ns()}")
	try:
		assert_path_without_reparse(active_root, "active package transaction directory")
		assert_path_without_reparse(cleanup_root, "package transaction cleanup directory")
		if os.path.lexists(cleanup_root):
			raise TransactionFailure(f"Package transaction cleanup directory already exists: {cleanup_root.as_posix()}")
		os.rename(active_root, cleanup_root)
	except (OSError, TransactionFailure) as error:
		issues.append(f"Could not finalize package transaction directory: {error}")
		return False
	ok = True
	for path in validated_cleanup_paths:
		try:
			assert_path_without_reparse(path, "package transaction cleanup path")
			remove_path(path)
		except OSError as error:
			issues.append(f"Could not remove package transaction cleanup path {path.as_posix()}: {error}")
			ok = False
		except TransactionFailure as error:
			issues.append(str(error))
			ok = False
	try:
		remove_path(cleanup_root)
		try:
			cleanup_root.parent.rmdir()
		except OSError:
			pass
	except (OSError, TransactionFailure) as error:
		issues.append(f"Could not remove package transaction cleanup directory {cleanup_root.as_posix()}: {error}")
		ok = False
	return ok


def write_phase(active_root: Path, journal: dict[str, Any], phase: str) -> None:
	journal["phase"] = phase
	write_journal_snapshot(active_root, journal)


def write_journal_snapshot(root: Path, journal: dict[str, Any]) -> None:
	sequence = int_value(journal.get("sequence", -1)) + 1
	journal["sequence"] = sequence
	final_path = root / f"{JOURNAL_PREFIX}{sequence:06d}{JOURNAL_SUFFIX}"
	temp_path = final_path.with_name(final_path.name + ".tmp")
	assert_path_without_reparse(final_path, "package transaction journal snapshot")
	if os.path.lexists(final_path):
		raise TransactionFailure(f"Package transaction journal snapshot already exists: {final_path.as_posix()}")
	write_json_file(temp_path, journal)
	assert_path_without_reparse(final_path, "package transaction journal snapshot")
	assert_path_without_reparse(temp_path, "package transaction journal temporary path")
	os.replace(temp_path, final_path)
	fsync_directory(root)


def read_latest_journal(
	active_root: Path,
	issues: list[str],
	expected_project_root: Path | None = None,
) -> dict[str, Any]:
	paths = sorted(active_root.glob(f"{JOURNAL_PREFIX}*{JOURNAL_SUFFIX}"), reverse=True)
	if not paths:
		issues.append(f"Package transaction has no journal snapshot: {active_root.as_posix()}")
		return {}
	path = paths[0]
	if path_has_reparse_component(path):
		issues.append(f"Latest package transaction journal crosses a filesystem link: {path.as_posix()}")
		return {}
	try:
		value = json.loads(path.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
		issues.append(f"Latest package transaction journal is unreadable: {path.as_posix()}: {error}")
		return {}
	journal = dictionary(value)
	if not journal:
		issues.append(f"Latest package transaction journal root is not an object: {path.as_posix()}")
		return {}
	match = re.fullmatch(rf"{re.escape(JOURNAL_PREFIX)}(\d+){re.escape(JOURNAL_SUFFIX)}", path.name)
	expected_sequence = int(match.group(1)) if match else -1
	validation_issues = validate_journal(journal, active_root, expected_project_root, expected_sequence)
	if validation_issues:
		issues.extend(validation_issues)
		return {}
	return journal


def journal_is_valid(journal: dict[str, Any]) -> bool:
	return not basic_journal_issues(journal)


def basic_journal_issues(journal: dict[str, Any]) -> list[str]:
	issues: list[str] = []
	required_fields = JOURNAL_REQUIRED_FIELDS | {"started_unix_time"}
	allowed_fields = required_fields | {"fault_injected"}
	missing_fields = required_fields - set(journal)
	unknown_fields = set(journal) - allowed_fields
	for field_name in sorted(missing_fields):
		issues.append(f"Package transaction journal is missing required field: {field_name}")
	for field_name in sorted(unknown_fields):
		issues.append(f"Package transaction journal contains unsupported field: {field_name}")
	if type(journal.get("schema_version")) is not int or journal.get("schema_version") != SCHEMA_VERSION:
		issues.append("Unsupported package transaction journal schema_version.")
	if type(journal.get("sequence")) is not int or int_value(journal.get("sequence", -1), -1) < 0:
		issues.append("Package transaction journal sequence must be a non-negative integer.")
	transaction_id = journal.get("transaction_id")
	if not isinstance(transaction_id, str) or TRANSACTION_ID_RE.fullmatch(transaction_id) is None:
		issues.append("Package transaction journal transaction_id is invalid.")
	if not isinstance(journal.get("operation"), str) or journal.get("operation") not in VALID_OPERATIONS:
		issues.append("Package transaction journal operation is invalid.")
	if not isinstance(journal.get("phase"), str) or journal.get("phase") not in VALID_PHASES:
		issues.append("Package transaction journal phase is invalid.")
	if type(journal.get("owner_pid")) is not int or int_value(journal.get("owner_pid", -1), -1) < 0:
		issues.append("Package transaction journal owner_pid must be a non-negative integer.")
	if type(journal.get("started_unix_time")) is not int or int_value(journal.get("started_unix_time", -1), -1) < 0:
		issues.append("Package transaction journal started_unix_time must be a non-negative integer.")
	if "fault_injected" in journal and type(journal.get("fault_injected")) is not bool:
		issues.append("Package transaction journal fault_injected must be a boolean.")
	if not isinstance(journal.get("project_root"), str) or not str(journal.get("project_root", "")):
		issues.append("Package transaction journal project_root is invalid.")
	if not isinstance(journal.get("lockfile_path"), str) or not str(journal.get("lockfile_path", "")):
		issues.append("Package transaction journal lockfile_path is invalid.")
	if type(journal.get("lockfile_had_original")) is not bool:
		issues.append("Package transaction journal lockfile_had_original must be a boolean.")
	for field_name in ("lockfile_original_sha256", "lockfile_planned_sha256"):
		if not isinstance(journal.get(field_name), str):
			issues.append(f"Package transaction journal {field_name} must be a string.")
	for field_name in ("writes", "deletes", "cleanup_paths"):
		if not isinstance(journal.get(field_name), list):
			issues.append(f"Package transaction journal {field_name} must be an array.")
	return issues


def validate_journal(
	journal: dict[str, Any],
	active_root: Path,
	expected_project_root: Path | None,
	expected_sequence: int,
) -> list[str]:
	issues = basic_journal_issues(journal)
	if issues:
		return issues
	if int(journal["sequence"]) != expected_sequence:
		issues.append("Package transaction journal filename sequence does not match its payload.")
	project_root = absolute_lexical_path(Path(str(journal["project_root"])))
	if canonical_absolute_text(str(journal["project_root"])) != project_root.as_posix():
		issues.append("Package transaction journal project_root is not canonical.")
	if expected_project_root is not None and project_root != absolute_lexical_path(expected_project_root):
		issues.append("Package transaction journal project root does not match the requested project.")
	if not project_root.is_dir() or path_has_reparse_component(project_root):
		issues.append("Package transaction journal project root is missing or crosses a filesystem link.")
	transaction_root = project_root / TRANSACTION_ROOT_RELATIVE_PATH
	normalized_active_root = absolute_lexical_path(active_root)
	if (
		not path_is_inside_lexical(transaction_root, normalized_active_root)
		or normalized_active_root.parent != transaction_root
		or (
			normalized_active_root.name != ACTIVE_DIRECTORY_NAME
			and not normalized_active_root.name.startswith(CANDIDATE_PREFIX)
		)
	):
		issues.append("Package transaction journal directory is not bound to the project transaction root.")
	if path_has_reparse_component(normalized_active_root):
		issues.append("Package transaction journal directory crosses a filesystem link.")

	lockfile_path = absolute_lexical_path(Path(str(journal["lockfile_path"])))
	if canonical_absolute_text(str(journal["lockfile_path"])) != lockfile_path.as_posix():
		issues.append("Package transaction journal lockfile_path is not canonical.")
	if not path_is_inside_lexical(project_root, lockfile_path) or path_is_inside_lexical(transaction_root, lockfile_path):
		issues.append("Package transaction journal lockfile_path is outside its permitted project root.")
	if path_has_reparse_component(lockfile_path):
		issues.append("Package transaction journal lockfile_path crosses a filesystem link.")

	cleanup_values = strict_string_list(journal.get("cleanup_paths", []))
	if len(cleanup_values) != len(list_value(journal.get("cleanup_paths", []))):
		issues.append("Package transaction journal cleanup_paths must contain only non-empty strings.")
	seen_cleanup: set[str] = set()
	for raw_path in cleanup_values:
		cleanup_path = validate_cleanup_path(project_root, transaction_root, raw_path)
		if cleanup_path is None:
			issues.append(f"Package transaction journal cleanup path is unsafe: {raw_path}")
			continue
		cleanup_key = absolute_portable_path_identity(cleanup_path)
		if cleanup_key in seen_cleanup:
			issues.append(f"Package transaction journal cleanup path is duplicated: {raw_path}")
		seen_cleanup.add(cleanup_key)

	phase = str(journal["phase"])
	writes = list_value(journal.get("writes", []))
	deletes = list_value(journal.get("deletes", []))
	if phase == PHASE_PREPARING:
		if writes or deletes:
			issues.append("Preparing package transaction journal cannot contain prepared payload entries.")
		if journal.get("lockfile_had_original") or journal.get("lockfile_original_sha256") or journal.get("lockfile_planned_sha256"):
			issues.append("Preparing package transaction journal cannot claim prepared lockfile snapshots.")
		return issues

	planned_snapshot = normalized_active_root / LOCKFILE_PLANNED_NAME
	planned_sha = str(journal.get("lockfile_planned_sha256", ""))
	if not is_sha256(planned_sha) or path_has_reparse_component(planned_snapshot) or not file_matches(planned_snapshot, planned_sha, -1):
		issues.append("Package transaction journal planned lockfile snapshot is missing or invalid.")
	if bool(journal.get("lockfile_had_original", False)):
		original_snapshot = normalized_active_root / LOCKFILE_ORIGINAL_NAME
		original_sha = str(journal.get("lockfile_original_sha256", ""))
		if not is_sha256(original_sha) or path_has_reparse_component(original_snapshot) or not file_matches(original_snapshot, original_sha, -1):
			issues.append("Package transaction journal original lockfile snapshot is missing or invalid.")
	elif str(journal.get("lockfile_original_sha256", "")):
		issues.append("Package transaction journal has an original lockfile digest without an original lockfile.")

	seen_payload_paths: set[str] = set()
	for action, entries in (("write", writes), ("delete", deletes)):
		for raw_entry in entries:
			entry = dictionary(raw_entry)
			entry_issues = validate_journal_payload_entry(
				entry,
				action,
				project_root,
				normalized_active_root,
				seen_payload_paths,
			)
			issues.extend(entry_issues)
	return issues


def validate_journal_payload_entry(
	entry: dict[str, Any],
	action: str,
	project_root: Path,
	active_root: Path,
	seen_paths: set[str],
) -> list[str]:
	issues: list[str] = []
	common_fields = {
		"action",
		"relative_path",
		"original_exists",
		"original_sha256",
		"original_size_bytes",
		"backup_relative_path",
	}
	allowed_fields = common_fields | ({"expected_sha256", "expected_size_bytes"} if action == "write" else set())
	if set(entry) != allowed_fields:
		issues.append(f"Package transaction journal {action} entry fields are invalid.")
		return issues
	if entry.get("action") != action:
		issues.append(f"Package transaction journal payload action is invalid: {entry.get('action', '')}")
	relative_path = entry.get("relative_path")
	if not isinstance(relative_path, str) or normalize_payload_relative_path(relative_path) != relative_path:
		issues.append(f"Package transaction journal payload path is invalid: {relative_path}")
		return issues
	path_key = portable_path_identity(relative_path)
	if path_key in seen_paths:
		issues.append(f"Package transaction journal payload path is duplicated: {relative_path}")
	seen_paths.add(path_key)
	validate_payload_target(project_root, relative_path, issues)
	if type(entry.get("original_exists")) is not bool:
		issues.append(f"Package transaction journal original_exists must be boolean: {relative_path}")
		return issues
	if not isinstance(entry.get("original_sha256"), str) or type(entry.get("original_size_bytes")) is not int:
		issues.append(f"Package transaction journal original metadata is invalid: {relative_path}")
		return issues
	backup_relative_path = entry.get("backup_relative_path")
	if not isinstance(backup_relative_path, str):
		issues.append(f"Package transaction journal backup path is invalid: {relative_path}")
		return issues
	if bool(entry["original_exists"]):
		expected_backup = (Path(BACKUP_DIRECTORY_NAME) / Path(*relative_path.split("/"))).as_posix()
		backup_path = active_root / Path(*backup_relative_path.split("/"))
		if backup_relative_path != expected_backup or not path_is_inside_lexical(active_root, backup_path):
			issues.append(f"Package transaction journal backup path is not bound to its payload: {relative_path}")
		elif path_has_reparse_component(backup_path) or not file_matches(
			backup_path,
			str(entry["original_sha256"]),
			int(entry["original_size_bytes"]),
		):
			issues.append(f"Package transaction journal backup snapshot is missing or invalid: {relative_path}")
		if not is_sha256(str(entry["original_sha256"])) or int(entry["original_size_bytes"]) < 0:
			issues.append(f"Package transaction journal original metadata is invalid: {relative_path}")
	elif entry["original_sha256"] != "" or entry["original_size_bytes"] != 0 or backup_relative_path != "":
		issues.append(f"Package transaction journal absent original state contains backup metadata: {relative_path}")
	if action == "write":
		if not is_sha256_value(entry.get("expected_sha256")) or type(entry.get("expected_size_bytes")) is not int or int(entry["expected_size_bytes"]) < 0:
			issues.append(f"Package transaction journal planned write metadata is invalid: {relative_path}")
	return issues


def mark_abandoned(active_root: Path, journal: dict[str, Any]) -> None:
	journal["owner_pid"] = 0
	journal["fault_injected"] = True
	try:
		write_journal_snapshot(active_root, journal)
	except OSError:
		pass


def transaction_owner_is_running(journal: dict[str, Any]) -> bool:
	owner_pid = int_value(journal.get("owner_pid", 0))
	if owner_pid <= 0 or bool(journal.get("fault_injected", False)):
		return False
	return process_is_running(owner_pid)


def process_is_running(pid: int) -> bool:
	if pid <= 0:
		return False
	if pid == os.getpid():
		return True
	if sys.platform == "win32":
		process_handle = ctypes.windll.kernel32.OpenProcess(0x00100000, False, pid)
		if not process_handle:
			return ctypes.windll.kernel32.GetLastError() == 5
		ctypes.windll.kernel32.CloseHandle(process_handle)
		return True
	try:
		os.kill(pid, 0)
	except ProcessLookupError:
		return False
	except PermissionError:
		return True
	except OSError:
		return False
	return True


def cleanup_abandoned_candidates(transaction_root: Path) -> list[str]:
	issues: list[str] = []
	if not transaction_root.is_dir():
		return issues
	project_root = transaction_root.parent.parent
	for candidate_root in transaction_root.glob(f"{CANDIDATE_PREFIX}*"):
		if path_has_reparse_component(candidate_root) or tree_has_reparse_point(candidate_root):
			issues.append(f"Package transaction candidate contains a filesystem link: {candidate_root.as_posix()}")
			continue
		if not candidate_root.is_dir():
			issues.append(f"Package transaction candidate is not a directory: {candidate_root.as_posix()}")
			continue
		journal = read_latest_journal(candidate_root, [], project_root)
		if not journal or not transaction_owner_is_running(journal):
			try:
				remove_path(candidate_root)
			except (OSError, TransactionFailure) as error:
				issues.append(f"Could not remove abandoned package transaction candidate: {error}")
	for cleanup_root in transaction_root.glob(f"{CLEANUP_PREFIX}*"):
		if path_has_reparse_component(cleanup_root) or tree_has_reparse_point(cleanup_root):
			issues.append(f"Package transaction cleanup directory contains a filesystem link: {cleanup_root.as_posix()}")
			continue
		if cleanup_root.is_dir():
			try:
				remove_path(cleanup_root)
			except (OSError, TransactionFailure) as error:
				issues.append(f"Could not remove package transaction cleanup directory: {error}")
		else:
			issues.append(f"Package transaction cleanup path is not a directory: {cleanup_root.as_posix()}")
	return issues


def make_report(
	ok: bool,
	transaction_id: str,
	operation: str,
	phase: str,
	outcome: str,
	*,
	write_count: int = 0,
	delete_count: int = 0,
	lockfile_written: bool = False,
	rolled_back: bool = False,
	recovered: bool = False,
	recovery_required: bool = False,
	issues: list[str] | None = None,
	warnings: list[str] | None = None,
) -> dict[str, Any]:
	issue_values = issues or []
	warning_values = warnings or []
	result = {
		"schema_version": REPORT_SCHEMA_VERSION,
		"ok": ok,
		"transaction_id": transaction_id,
		"operation": operation,
		"phase": phase,
		"outcome": outcome,
		"write_count": write_count,
		"delete_count": delete_count,
		"lockfile_written": lockfile_written,
		"rolled_back": rolled_back,
		"recovered": recovered,
		"recovery_required": recovery_required,
		"issue_count": len(issue_values),
		"issues": issue_values,
		"warning_count": len(warning_values),
		"warnings": warning_values,
	}
	if set(result.keys()) != REPORT_FIELDS:
		raise RuntimeError("Package transaction report fields drifted from the shared schema contract.")
	return result


def payload_target_path(journal: dict[str, Any], entry: dict[str, Any]) -> Path:
	project_root = journal_project_root(journal)
	relative_path = str(entry.get("relative_path", ""))
	if normalize_payload_relative_path(relative_path) != relative_path:
		raise TransactionFailure(f"Package transaction journal payload path is unsafe: {relative_path}")
	target_path = project_root / Path(*relative_path.split("/"))
	if not path_is_inside_lexical(project_root, target_path):
		raise TransactionFailure(f"Package transaction payload target is outside project root: {relative_path}")
	return target_path


def journal_project_root(journal: dict[str, Any]) -> Path:
	project_root = absolute_lexical_path(Path(str(journal.get("project_root", ""))))
	if canonical_absolute_text(str(journal.get("project_root", ""))) != project_root.as_posix():
		raise TransactionFailure("Package transaction journal project root is not canonical.")
	return project_root


def lockfile_target_path(journal: dict[str, Any]) -> Path:
	project_root = journal_project_root(journal)
	lockfile_path = absolute_lexical_path(Path(str(journal.get("lockfile_path", ""))))
	if canonical_absolute_text(str(journal.get("lockfile_path", ""))) != lockfile_path.as_posix():
		raise TransactionFailure("Package transaction journal lockfile path is not canonical.")
	transaction_root = project_root / TRANSACTION_ROOT_RELATIVE_PATH
	if not path_is_inside_lexical(project_root, lockfile_path) or path_is_inside_lexical(transaction_root, lockfile_path):
		raise TransactionFailure("Package transaction journal lockfile path is outside its permitted project root.")
	return lockfile_path


def payload_temp_path(target_path: Path, transaction_id: str) -> Path:
	return target_path.with_name(f"{target_path.name}.gf-package-{transaction_id}.tmp")


def lockfile_temp_path(lockfile_path: Path, transaction_id: str) -> Path:
	return lockfile_path.with_name(f"{lockfile_path.name}.gf-package-{transaction_id}.tmp")


def normalize_payload_relative_path(path: str) -> str:
	if path != path.strip():
		return ""
	normalized = path.replace("\\", "/")
	if not normalized or normalized.startswith("/") or ":" in normalized:
		return ""
	parts: list[str] = []
	for part in normalized.split("/"):
		if not part or part in {".", ".."} or part != part.rstrip(" .") or any(ord(character) < 32 for character in part):
			return ""
		parts.append(part)
	result = "/".join(parts)
	return result if result.startswith(PACKAGE_ROOT_PREFIX) else ""


def path_is_inside(root: Path, child: Path) -> bool:
	if not path_is_inside_lexical(root, child):
		return False
	try:
		child.resolve().relative_to(root.resolve())
	except (OSError, ValueError):
		return False
	return True


def path_is_inside_lexical(root: Path, child: Path) -> bool:
	root_path = absolute_lexical_path(root)
	child_path = absolute_lexical_path(child)
	try:
		common = os.path.commonpath((str(root_path), str(child_path)))
	except ValueError:
		return False
	return os.path.normcase(common) == os.path.normcase(str(root_path))


def absolute_lexical_path(path: Path) -> Path:
	return Path(os.path.abspath(os.fspath(path.expanduser())))


def canonical_absolute_text(value: str) -> str:
	if not value or value != value.strip():
		return ""
	path = Path(value)
	if not path.is_absolute():
		return ""
	text = value.replace("\\", "/")
	while len(text) > 3 and text.endswith("/"):
		text = text[:-1]
	return text


def path_has_reparse_component(path: Path) -> bool:
	current = absolute_lexical_path(path)
	while True:
		try:
			metadata = os.lstat(current)
		except FileNotFoundError:
			pass
		except OSError:
			return True
		else:
			if stat.S_ISLNK(metadata.st_mode) or bool(
				int(getattr(metadata, "st_file_attributes", 0)) & FILE_ATTRIBUTE_REPARSE_POINT
			):
				return True
		if current == current.parent:
			return False
		current = current.parent


def assert_path_without_reparse(path: Path, label: str) -> None:
	if path_has_reparse_component(path):
		raise TransactionFailure(f"{label.capitalize()} crosses a filesystem link: {path.as_posix()}")


def portable_path_identity(relative_path: str) -> str:
	normalized = normalize_payload_relative_path(relative_path)
	return normalized.lower() if normalized else ""


def absolute_portable_path_identity(path: Path) -> str:
	return absolute_lexical_path(path).as_posix().lower()


def validate_payload_target(project_root: Path, relative_path: str, issues: list[str]) -> bool:
	target_path = project_root / Path(*relative_path.split("/"))
	if not path_is_inside_lexical(project_root, target_path):
		issues.append(f"Package transaction payload target is outside project root: {relative_path}")
		return False
	if path_has_reparse_component(target_path):
		issues.append(f"Package transaction payload target crosses a filesystem link: {relative_path}")
		return False
	return True


def validate_cleanup_path(project_root: Path, transaction_root: Path, raw_path: str) -> Path | None:
	cleanup_path = absolute_lexical_path(Path(raw_path).expanduser())
	project_internal_root = project_root / ".gf"
	if canonical_absolute_text(raw_path) != cleanup_path.as_posix():
		return None
	if cleanup_path == project_internal_root or not path_is_inside_lexical(project_internal_root, cleanup_path):
		return None
	if path_is_inside_lexical(transaction_root, cleanup_path) or path_is_inside_lexical(cleanup_path, transaction_root):
		return None
	if path_has_reparse_component(cleanup_path):
		return None
	return cleanup_path


def is_sha256(value: str) -> bool:
	return len(value) == 64 and all(character in "0123456789abcdef" for character in value)


def is_sha256_value(value: Any) -> bool:
	return isinstance(value, str) and is_sha256(value)


def copy_file_verified(source_path: Path, target_path: Path) -> None:
	assert_path_without_reparse(source_path, "package transaction copy source")
	assert_path_without_reparse(target_path, "package transaction copy target")
	target_path.parent.mkdir(parents=True, exist_ok=True)
	assert_path_without_reparse(target_path, "package transaction copy target")
	with source_path.open("rb") as source, target_path.open("wb") as target:
		shutil.copyfileobj(source, target, length=1024 * 1024)
		target.flush()
		os.fsync(target.fileno())
	shutil.copystat(source_path, target_path)
	if not file_matches(target_path, sha256_file(source_path), source_path.stat().st_size):
		raise TransactionFailure(f"Copied file verification failed: {target_path.as_posix()}")


def write_json_file(path: Path, value: dict[str, Any]) -> None:
	assert_path_without_reparse(path, "package transaction JSON path")
	path.parent.mkdir(parents=True, exist_ok=True)
	assert_path_without_reparse(path, "package transaction JSON path")
	with path.open("w", encoding="utf-8", newline="\n") as handle:
		json.dump(value, handle, ensure_ascii=False, indent=2)
		handle.write("\n")
		handle.flush()
		os.fsync(handle.fileno())


def fsync_directory(path: Path) -> None:
	if sys.platform == "win32":
		return
	try:
		directory_fd = os.open(path, os.O_RDONLY)
	except OSError:
		return
	try:
		os.fsync(directory_fd)
	finally:
		os.close(directory_fd)


def file_matches(path: Path, expected_sha: str, expected_size: int) -> bool:
	if path_has_reparse_component(path) or not path.is_file():
		return False
	if expected_size >= 0 and path.stat().st_size != expected_size:
		return False
	return not expected_sha or sha256_file(path) == expected_sha


def sha256_file(path: Path) -> str:
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for chunk in iter(lambda: handle.read(1024 * 1024), b""):
			digest.update(chunk)
	return digest.hexdigest()


def remove_path(path: Path) -> None:
	if path_has_reparse_component(path) or tree_has_reparse_point(path):
		raise TransactionFailure(f"Refusing to remove a package transaction path that crosses a filesystem link: {path.as_posix()}")
	if path.is_file():
		path.unlink(missing_ok=True)
	elif path.is_dir():
		shutil.rmtree(path)


def tree_has_reparse_point(root: Path) -> bool:
	if not root.is_dir() or path_has_reparse_component(root):
		return path_has_reparse_component(root)
	pending = [root]
	while pending:
		current = pending.pop()
		try:
			with os.scandir(current) as entries:
				for entry in entries:
					try:
						metadata = entry.stat(follow_symlinks=False)
					except OSError:
						return True
					if entry.is_symlink() or bool(
						int(getattr(metadata, "st_file_attributes", 0)) & FILE_ATTRIBUTE_REPARSE_POINT
					):
						return True
					if stat.S_ISDIR(metadata.st_mode):
						pending.append(Path(entry.path))
		except OSError:
			return True
	return False


def remove_empty_parents(directory_path: Path, project_root: Path) -> None:
	current = absolute_lexical_path(directory_path)
	root = absolute_lexical_path(project_root)
	while current != root and path_is_inside_lexical(root, current):
		if path_has_reparse_component(current):
			break
		if current == root / "addons":
			break
		try:
			current.rmdir()
		except OSError:
			break
		current = current.parent


def dictionary(value: Any) -> dict[str, Any]:
	return value if isinstance(value, dict) else {}


def list_value(value: Any) -> list[Any]:
	return value if isinstance(value, list) else []


def string_list(value: Any) -> list[str]:
	return [str(item) for item in list_value(value)]


def strict_string_list(value: Any) -> list[str]:
	if not isinstance(value, list):
		return []
	return [item for item in value if isinstance(item, str) and bool(item)]


def int_value(value: Any, default: int = 0) -> int:
	if isinstance(value, bool):
		return default
	if isinstance(value, int):
		return value
	return default
