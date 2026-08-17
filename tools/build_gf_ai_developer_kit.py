#!/usr/bin/env python3
"""Generate, validate, build, and audit the optional GF AI Developer Kit."""

from __future__ import annotations

import argparse
import configparser
import hashlib
import io
import json
import os
import re
import secrets
import shutil
import stat
import struct
import subprocess
import sys
import tempfile
import unicodedata
import zipfile
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from pathlib import PurePosixPath
from typing import Any
from typing import BinaryIO
from typing import Iterator

import build_gf_package
from gdscript_api_parser import ApiDocs, ApiMember, visibility_of
from gf_api_owners import OWNER_KIND_CLASS, ApiOwner, collect_api_owners
from gf_godot_process import GODOT_EXECUTABLE_ENV_VAR, resolve_godot_executable
from gf_process_supervisor import SupervisedProcessResult, run_supervised_process
from gf_semver import SemVer, parse_semver


ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = ROOT / "addons/gf/tools/ai_developer"
API_INDEX_PATH = ADDON_ROOT / "knowledge/api_index.json"
ARTIFACT_POLICY_PATH = ROOT / "addons/gf/kernel/core/project_artifact_policy.json"
PLATFORM_ADAPTER_TEMPLATE_ROOT = ADDON_ROOT / "templates/adapters/platform"
PLATFORM_ADAPTER_PROFILE_SCHEMA_PATH = (
	ROOT / "tools/schemas/platform_adapter_profile.schema.json"
)
STORAGE_BACKEND_TEMPLATE_ROOT = ADDON_ROOT / "templates/adapters/storage"
PLUGIN_NAME = "gf-ai-developer"
ZIP_TIMESTAMP = (1980, 1, 1, 0, 0, 0)
BLOCKED_PARTS = {"__pycache__", ".git", ".godot"}
BLOCKED_PART_IDENTITIES = frozenset(part.casefold() for part in BLOCKED_PARTS)
BLOCKED_SUFFIXES = {".pyc", ".pyo", ".tmp", ".log"}
NATIVE_HASH_PLACEHOLDER = "replace-with-64-lowercase-sha256"
NATIVE_THREAD_PLACEHOLDER = "replace-with-main-or-worker"
STORAGE_ACCEPTANCE_TIMEOUT_SECONDS = 240.0
STORAGE_ACCEPTANCE_OUTPUT_CHARACTER_LIMIT = 2 * 1024 * 1024
STORAGE_ACCEPTANCE_LOG_BYTE_LIMIT = 4 * 1024 * 1024
ADAPTER_TEMPLATE_BYTE_LIMIT = 2 * 1024 * 1024
STORAGE_ACCEPTANCE_TEMPLATE_BYTE_LIMIT = ADAPTER_TEMPLATE_BYTE_LIMIT
STORAGE_ACCEPTANCE_COPY_FILE_LIMIT = 50_000
STORAGE_ACCEPTANCE_COPY_BYTE_LIMIT = 1024 * 1024 * 1024
STORAGE_ACCEPTANCE_COPY_SINGLE_FILE_LIMIT = 128 * 1024 * 1024
STORAGE_REDACTION_CANARY = "REDACTION_CANARY_DO_NOT_EMIT"
_STORAGE_ACCEPTANCE_LIFECYCLE_PREFIX = "GF_TEST_LIFECYCLE_GATE="
_STORAGE_ACCEPTANCE_LIFECYCLE_MAX_JSON_BYTES = 65_536
_STORAGE_ACCEPTANCE_LIFECYCLE_REQUIRED_KEYS = frozenset({
	"schema_version",
	"ok",
	"baseline_available",
	"warning_tracking_available",
	"unhandled_warning_count",
	"orphan_count",
	"warnings",
	"orphans",
	"details_truncated",
	"configuration_error",
})
_STORAGE_ACCEPTANCE_EXIT_LEAK_PATTERNS = (
	"objectdb instances leaked at exit",
	"resource still in use at exit",
	"resources still in use at exit",
	"rid allocations",
	"were leaked at exit",
)
PLUGIN_SOURCE_DIRECTORY_LIMIT = 2_048
PLUGIN_SOURCE_FILE_LIMIT = 10_000
PLUGIN_SOURCE_SINGLE_FILE_LIMIT = 16 * 1024 * 1024
PLUGIN_SOURCE_TOTAL_BYTE_LIMIT = 256 * 1024 * 1024
PLUGIN_ARCHIVE_BYTE_LIMIT = 256 * 1024 * 1024
PLUGIN_ARCHIVE_ENTRY_LIMIT = 12_000
PLUGIN_ARCHIVE_CENTRAL_DIRECTORY_BYTE_LIMIT = 32 * 1024 * 1024
PLUGIN_ARCHIVE_ENTRY_BYTE_LIMIT = 32 * 1024 * 1024
PLUGIN_ARCHIVE_EXPANDED_BYTE_LIMIT = 384 * 1024 * 1024
PLUGIN_ARCHIVE_COMPRESSION_RATIO_LIMIT = 200.0
PLUGIN_ARCHIVE_COMPRESSION_RATIO_MINIMUM_BYTES = 4_096
PLUGIN_ARCHIVE_ISSUE_LIMIT = 256
PLUGIN_ARCHIVE_READ_CHUNK_BYTES = 64 * 1024
PLUGIN_ARCHIVE_EOCD_SIGNATURE = b"PK\x05\x06"
PLUGIN_ARCHIVE_EOCD_STRUCT = struct.Struct("<4s4H2LH")
PLUGIN_ARCHIVE_CENTRAL_DIRECTORY_SIGNATURE = b"PK\x01\x02"
PLUGIN_ARCHIVE_CENTRAL_DIRECTORY_STRUCT = struct.Struct("<4s6H3L5H2L")
PLUGIN_ARCHIVE_LOCAL_HEADER_SIGNATURE = b"PK\x03\x04"
PLUGIN_ARCHIVE_LOCAL_HEADER_STRUCT = struct.Struct("<4s5H3L2H")
PLUGIN_ARCHIVE_ALLOWED_COMPRESSION = frozenset({
	zipfile.ZIP_STORED,
	zipfile.ZIP_DEFLATED,
})
PLUGIN_INVOCATION_TOTAL_IO_BYTE_LIMIT = 4 * 1024 * 1024 * 1024
PLUGIN_INVOCATION_SOURCE_BYTE_LIMIT = 2 * PLUGIN_SOURCE_TOTAL_BYTE_LIMIT
PLUGIN_INVOCATION_OUTPUT_BYTE_LIMIT = 2 * 1024 * 1024 * 1024
_PRIVATE_OWNED_ROOTS: dict[Path, Any] = {}


@dataclass(frozen=True)
class PluginSourceLimits:
	"""Hard work budgets for collecting one AI Developer Kit source set."""

	max_directories: int = PLUGIN_SOURCE_DIRECTORY_LIMIT
	max_files: int = PLUGIN_SOURCE_FILE_LIMIT
	max_single_file_bytes: int = PLUGIN_SOURCE_SINGLE_FILE_LIMIT
	max_total_bytes: int = PLUGIN_SOURCE_TOTAL_BYTE_LIMIT


@dataclass
class PluginSourceBudget:
	"""Mutable counters shared by all fixed and traversed plugin sources."""

	directories: int = 0
	files: int = 0
	total_bytes: int = 0
	read_bytes: int = 0
	output_files: int = 0
	output_bytes: int = 0
	output_identities: set[str] | None = None
	required_directory_identities: set[str] | None = None

	def consume_directory(self, limits: PluginSourceLimits) -> None:
		self.directories += 1
		if self.directories > limits.max_directories:
			raise ValueError("Plugin source directory budget exceeded.")

	def consume_file(
		self,
		size_bytes: int,
		limits: PluginSourceLimits,
	) -> None:
		if size_bytes < 0 or size_bytes > limits.max_single_file_bytes:
			raise ValueError("Plugin source single-file budget exceeded.")
		self.files += 1
		if self.files > limits.max_files:
			raise ValueError("Plugin source file-count budget exceeded.")
		self.total_bytes += size_bytes
		if self.total_bytes > limits.max_total_bytes:
			raise ValueError("Plugin source total-byte budget exceeded.")

	def consume_read_file(
		self,
		size_bytes: int,
		limits: PluginSourceLimits,
	) -> None:
		if size_bytes < 0 or size_bytes > limits.max_single_file_bytes:
			raise ValueError("Plugin source single-file read budget exceeded.")
		if self.read_bytes + size_bytes > limits.max_total_bytes:
			raise ValueError("Plugin source actual-read budget exceeded.")
		self.read_bytes += size_bytes

	def consume_output_entry(
		self,
		name: str,
		size_bytes: int,
		limits: PluginSourceLimits,
	) -> None:
		identity = _portable_plugin_archive_identity(name)
		if self.output_identities is None:
			self.output_identities = set()
		if self.required_directory_identities is None:
			self.required_directory_identities = set()
		if identity in self.output_identities:
			raise ValueError("Plugin output contains a portable duplicate path.")
		if identity in self.required_directory_identities:
			raise ValueError("Plugin output contains a file-directory prefix conflict.")
		parent_identity = ""
		for component in identity.split("/")[:-1]:
			parent_identity = (
				component
				if not parent_identity
				else f"{parent_identity}/{component}"
			)
			if parent_identity in self.output_identities:
				raise ValueError(
					"Plugin output contains a file-directory prefix conflict."
				)
			self.required_directory_identities.add(parent_identity)
		if size_bytes < 0:
			raise ValueError("Plugin output entry size is invalid.")
		if self.output_files + 1 > limits.max_files:
			raise ValueError("Plugin entry file-count budget exceeded.")
		if self.output_bytes + size_bytes > limits.max_total_bytes:
			raise ValueError("Plugin entry total-byte budget exceeded.")
		self.output_identities.add(identity)
		self.output_files += 1
		self.output_bytes += size_bytes


@dataclass(frozen=True)
class PluginWorkLimits:
	"""Invocation-level bounds for physical and logical plugin work."""

	max_total_io_bytes: int = PLUGIN_INVOCATION_TOTAL_IO_BYTE_LIMIT
	max_source_bytes: int = PLUGIN_INVOCATION_SOURCE_BYTE_LIMIT
	max_output_bytes: int = PLUGIN_INVOCATION_OUTPUT_BYTE_LIMIT
	max_archive_entries: int = PLUGIN_ARCHIVE_ENTRY_LIMIT
	max_central_directory_bytes: int = (
		PLUGIN_ARCHIVE_CENTRAL_DIRECTORY_BYTE_LIMIT
	)
	max_expanded_bytes: int = PLUGIN_ARCHIVE_EXPANDED_BYTE_LIMIT


@dataclass
class PluginWorkBudget:
	"""Mutable counters shared by one build-and-audit invocation."""

	io_bytes: int = 0
	source_bytes: int = 0
	output_bytes: int = 0
	archive_entries: int = 0
	central_directory_bytes: int = 0
	expanded_bytes: int = 0
	hard_exhausted: bool = False

	def ensure_io_bytes(self, amount: int, limits: PluginWorkLimits) -> None:
		safe_amount = max(0, amount)
		if self.io_bytes + safe_amount > limits.max_total_io_bytes:
			self.hard_exhausted = True
			raise ValueError("ai_kit.work.io_budget_exceeded")

	def consume_io_bytes(self, amount: int, limits: PluginWorkLimits) -> None:
		safe_amount = max(0, amount)
		self.ensure_io_bytes(safe_amount, limits)
		self.io_bytes += safe_amount

	def consume_source_bytes(self, amount: int, limits: PluginWorkLimits) -> None:
		safe_amount = max(0, amount)
		if self.source_bytes + safe_amount > limits.max_source_bytes:
			self.hard_exhausted = True
			raise ValueError("ai_kit.work.source_budget_exceeded")
		self.source_bytes += safe_amount

	def consume_output_bytes(self, amount: int, limits: PluginWorkLimits) -> None:
		safe_amount = max(0, amount)
		if self.output_bytes + safe_amount > limits.max_output_bytes:
			self.hard_exhausted = True
			raise ValueError("ai_kit.work.output_budget_exceeded")
		self.output_bytes += safe_amount

	def consume_archive(
		self,
		entry_count: int,
		central_directory_bytes: int,
		limits: PluginWorkLimits,
	) -> None:
		self.archive_entries += max(0, entry_count)
		self.central_directory_bytes += max(0, central_directory_bytes)
		if self.archive_entries > limits.max_archive_entries:
			self.hard_exhausted = True
			raise ValueError("ai_kit.archive.entry_count_exceeded")
		if (
			self.central_directory_bytes
			> limits.max_central_directory_bytes
		):
			self.hard_exhausted = True
			raise ValueError("ai_kit.archive.central_directory_budget_exceeded")

	def consume_expanded_bytes(
		self,
		amount: int,
		limits: PluginWorkLimits,
	) -> None:
		self.expanded_bytes += max(0, amount)
		if self.expanded_bytes > limits.max_expanded_bytes:
			self.hard_exhausted = True
			raise ValueError("ai_kit.archive.expanded_budget_exceeded")


class _BudgetedBinaryIO:
	"""Charge every delegated binary read or write to one invocation budget."""

	def __init__(
		self,
		handle: BinaryIO,
		work_budget: PluginWorkBudget,
		work_limits: PluginWorkLimits,
		*,
		logical_size: int | None = None,
		charge_output: bool = False,
	) -> None:
		self._handle = handle
		self._work_budget = work_budget
		self._work_limits = work_limits
		self._logical_size = logical_size
		self._charge_output = charge_output

	def read(self, size: int = -1) -> bytes:
		requested = self._bounded_read_request(size)
		self._work_budget.ensure_io_bytes(requested, self._work_limits)
		payload = self._handle.read(size)
		if not isinstance(payload, bytes):
			payload = bytes(payload)
		if len(payload) > requested:
			raise ValueError("ai_kit.work.controlled_read_incomplete")
		self._work_budget.consume_io_bytes(len(payload), self._work_limits)
		return payload

	def read1(self, size: int = -1) -> bytes:
		return self.read(size)

	def readinto(self, buffer: bytearray | memoryview) -> int:
		requested = self._bounded_read_request(len(buffer))
		self._work_budget.ensure_io_bytes(requested, self._work_limits)
		readinto = getattr(self._handle, "readinto", None)
		if readinto is None:
			payload = self._handle.read(requested)
			length = len(payload)
			buffer[:length] = payload
		else:
			length = int(readinto(buffer))
		if length < 0 or length > requested:
			raise ValueError("ai_kit.work.controlled_read_incomplete")
		self._work_budget.consume_io_bytes(length, self._work_limits)
		return length

	def write(self, payload: bytes | bytearray | memoryview) -> int:
		size_bytes = len(payload)
		self._work_budget.ensure_io_bytes(size_bytes, self._work_limits)
		if self._charge_output:
			if (
				self._work_budget.output_bytes + size_bytes
				> self._work_limits.max_output_bytes
			):
				self._work_budget.hard_exhausted = True
				raise ValueError("ai_kit.work.output_budget_exceeded")
		written = int(self._handle.write(payload))
		if written < 0 or written > size_bytes:
			raise ValueError("ai_kit.work.controlled_write_incomplete")
		self._work_budget.consume_io_bytes(written, self._work_limits)
		if self._charge_output:
			self._work_budget.consume_output_bytes(
				written,
				self._work_limits,
			)
		return written

	def seek(self, offset: int, whence: int = os.SEEK_SET) -> int:
		return int(self._handle.seek(offset, whence))

	def tell(self) -> int:
		return int(self._handle.tell())

	def flush(self) -> None:
		self._handle.flush()

	def truncate(self, size: int | None = None) -> int:
		return int(self._handle.truncate(size))

	def readable(self) -> bool:
		return bool(self._handle.readable())

	def writable(self) -> bool:
		return bool(self._handle.writable())

	def seekable(self) -> bool:
		return bool(self._handle.seekable())

	def fileno(self) -> int:
		return int(self._handle.fileno())

	@property
	def closed(self) -> bool:
		return bool(self._handle.closed)

	@property
	def name(self) -> Any:
		return getattr(self._handle, "name", None)

	def _bounded_read_request(self, size: int) -> int:
		if self._logical_size is None:
			return max(0, size)
		position = max(0, self.tell())
		remaining = max(0, self._logical_size - position)
		if size is None or size < 0:
			return remaining
		return min(size, remaining)


@dataclass(frozen=True)
class PluginArchivePreflight:
	"""Bounded EOCD facts validated before ZipFile parses the directory."""

	entry_count: int
	central_directory_bytes: int

sys.path.insert(0, str(ADDON_ROOT))
try:
	from gf_ai.paths import (
		is_reserved_framework_resource_path,
		normalize_portable_ownership_path,
		portable_ownership_path_identity,
		read_json_object as read_strict_json_object,
		strict_json_loads,
	)
	from gf_ai.schema import validate_schema_file
finally:
	sys.path.pop(0)


def main(argv: list[str] | None = None) -> int:
	configure_stdio()
	parser = argparse.ArgumentParser(description="Build and validate the GF AI Developer Kit.")
	parser.add_argument("--version", default="", help="GF SemVer used for the generated Codex plugin.")
	parser.add_argument("--output", default="", help="Output plugin zip path.")
	action_group = parser.add_mutually_exclusive_group()
	action_group.add_argument(
		"--generate-source",
		action="store_true",
		help="Regenerate the tracked compact API index.",
	)
	action_group.add_argument(
		"--check-source",
		action="store_true",
		help="Check generated knowledge, schemas, catalogs, and templates.",
	)
	action_group.add_argument(
		"--storage-backend-acceptance",
		action="store_true",
		help="Run the isolated Godot acceptance for the storage Adapter templates.",
	)
	action_group.add_argument(
		"--validate-only",
		action="store_true",
		help="Audit an existing --output plugin zip.",
	)
	parser.add_argument("--json", action="store_true", help="Print JSON output.")
	args = parser.parse_args(argv)
	version = args.version.strip() or read_plugin_version()
	output = resolve_output(args.output, version)
	work_budget = PluginWorkBudget()
	work_limits = PluginWorkLimits()
	result: dict[str, Any]
	if args.generate_source:
		payload = render_api_index()
		write_api_index(payload)
		result = check_source(payload)
	elif args.check_source:
		result = check_source()
	elif args.storage_backend_acceptance:
		result = run_storage_backend_template_acceptance()
	elif args.validate_only:
		result = audit_plugin_archive(
			output,
			version,
			work_budget=work_budget,
			work_limits=work_limits,
		)
	else:
		issues = check_source()["issues"]
		if issues:
			result = {"ok": False, "version": version, "output": output.as_posix(), "issues": issues}
		else:
			build_plugin_archive(
				output,
				version,
				work_budget=work_budget,
				work_limits=work_limits,
			)
			result = audit_plugin_archive(
				output,
				version,
				work_budget=work_budget,
				work_limits=work_limits,
			)
	print_result(result, args.json)
	return 0 if result.get("ok") else 1


def configure_stdio() -> None:
	for stream in (sys.stdin, sys.stdout, sys.stderr):
		if hasattr(stream, "reconfigure"):
			stream.reconfigure(encoding="utf-8", errors="strict")


def read_plugin_version() -> str:
	parser = configparser.ConfigParser()
	parser.read(ROOT / "addons/gf/plugin.cfg", encoding="utf-8")
	return parser.get("plugin", "version", fallback="").strip().strip('"')


def resolve_output(raw_path: str, version: str) -> Path:
	path = Path(raw_path) if raw_path else ROOT / "build" / f"gf-ai-developer-kit-{version}.zip"
	return path.resolve()


def render_api_index() -> dict[str, Any]:
	manifest_load = build_gf_package.load_package_manifests()
	if manifest_load.get("issues"):
		raise ValueError("Package manifests are invalid: " + "; ".join(manifest_load["issues"][:10]))
	records = [record for record in manifest_load["records"] if record.get("kind") != "preset"]
	package_payload: list[dict[str, Any]] = []
	for record in records:
		file_issues: list[str] = []
		files = build_gf_package.collect_package_files(record, file_issues)
		if file_issues:
			raise ValueError(f"Package {record['id']} is invalid: " + "; ".join(file_issues[:10]))
		relative_files = [path.relative_to(ROOT).as_posix() for path in files]
		# The generated API index belongs to this package but must not influence its
		# own deterministic package summary when bootstrapping from a clean tree.
		representative_candidates = [
			path for path in relative_files
			if path != API_INDEX_PATH.relative_to(ROOT).as_posix()
		]
		representative = _representative_path(representative_candidates)
		package_payload.append({
			"id": record["id"],
			"kind": record["kind"],
			"dependencies": record["dependencies"],
			"description": record["description"],
			"representative_path": representative,
		})

	classes: dict[str, Any] = {}
	autoloads: dict[str, Any] = {}
	for owner in collect_api_owners(ROOT / "addons/gf", ROOT, records):
		target = classes if owner.kind == OWNER_KIND_CLASS else autoloads
		target[owner.name] = _api_owner_record(owner)
	payload = {
		"schema_version": 2,
		"catalog_version": "2.0.0",
		"framework_version": read_plugin_version(),
		"source_digest": "",
		"class_count": len(classes),
		"autoload_count": len(autoloads),
		"package_count": len(package_payload),
		"packages": sorted(package_payload, key=lambda item: str(item["id"])),
		"classes": dict(sorted(classes.items())),
		"autoloads": dict(sorted(autoloads.items())),
	}
	digest_payload = {key: value for key, value in payload.items() if key != "source_digest"}
	payload["source_digest"] = hashlib.sha256(
		json.dumps(digest_payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")
	).hexdigest()
	return payload


def _api_owner_record(owner: ApiOwner) -> dict[str, Any]:
	script = owner.script
	members: list[dict[str, str]] = []
	for member in [*script.signals, *script.enums, *script.constants, *script.properties, *script.methods]:
		member_visibility = visibility_of(member.docs)
		members.append({
			"kind": _member_kind(member),
			"name": member.name,
			"signature": member.signature.rstrip(":"),
			"summary": _summary(member.docs, 1),
			"visibility": member_visibility,
		})
	return {
		"owner_kind": owner.kind,
		"extends": script.extends,
		"module": script.module,
		"package_id": owner.package_id,
		"path": script.path,
		"summary": _summary(script.docs, 3),
		"visibility": visibility_of(script.docs),
		"category": _first_tag(script.docs, "category"),
		"since": _first_tag(script.docs, "since"),
		"members": members,
	}


def render_api_index_text(payload: dict[str, Any] | None = None) -> str:
	value = render_api_index() if payload is None else payload
	return json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n"


def write_api_index(payload: dict[str, Any] | None = None) -> None:
	API_INDEX_PATH.parent.mkdir(parents=True, exist_ok=True)
	temporary = API_INDEX_PATH.with_name(f".{API_INDEX_PATH.name}.{os.getpid()}.tmp")
	try:
		temporary.write_text(render_api_index_text(payload), encoding="utf-8", newline="\n")
		os.replace(temporary, API_INDEX_PATH)
	finally:
		if temporary.exists():
			temporary.unlink()


def check_source(rendered_payload: dict[str, Any] | None = None) -> dict[str, Any]:
	issues: list[str] = []
	payload: dict[str, Any] = {}
	try:
		payload = render_api_index() if rendered_payload is None else rendered_payload
		expected = render_api_index_text(payload)
		actual = API_INDEX_PATH.read_text(encoding="utf-8")
		if actual != expected:
			issues.append("knowledge/api_index.json is stale; run --generate-source.")
	except (OSError, UnicodeDecodeError, ValueError) as exc:
		issues.append(f"API knowledge index check failed: {exc}")
	for relative_path in (
		"schemas/project_contract.schema.json",
		"schemas/feedback_candidate.schema.json",
		"schemas/editor_context_bundle.schema.json",
		"schemas/project_snapshot.schema.json",
		"schemas/capability_catalog.schema.json",
		"schemas/recipe_catalog.schema.json",
		"templates/gf_project_contract.json",
		"templates/feedback_candidate.json",
		"knowledge/capabilities.json",
		"knowledge/recipes.json",
	):
		try:
			read_strict_json_object(ADDON_ROOT / relative_path)
		except ValueError as exc:
			issues.append(f"{relative_path} is invalid UTF-8 JSON: {exc}")
	try:
		read_strict_json_object(ARTIFACT_POLICY_PATH)
		sys.path.insert(0, str(ADDON_ROOT))
		try:
			from gf_ai.constants import ARTIFACT_POLICY_PATH as runtime_policy_path, load_artifact_paths
			if runtime_policy_path.resolve() != ARTIFACT_POLICY_PATH.resolve():
				issues.append("GF AI runtime does not resolve the canonical project artifact policy.")
			load_artifact_paths()
		finally:
			if sys.path and sys.path[0] == str(ADDON_ROOT):
				sys.path.pop(0)
	except (OSError, RuntimeError, ValueError) as exc:
		issues.append(f"project_artifact_policy.json is invalid: {exc}")
	issues.extend(validate_contract_template())
	issues.extend(validate_protocol_versions())
	issues.extend(validate_catalogs())
	issues.extend(validate_agent_templates())
	issues.extend(validate_platform_adapter_templates())
	issues.extend(validate_storage_backend_templates())
	return {
		"ok": not issues,
		"api_index": API_INDEX_PATH.relative_to(ROOT).as_posix(),
		"class_count": len(payload.get("classes", {})),
		"autoload_count": len(payload.get("autoloads", {})),
		"issues": issues,
	}


def validate_contract_template() -> list[str]:
	sys.path.insert(0, str(ADDON_ROOT))
	try:
		from gf_ai.schema import validate_schema_file
	finally:
		if sys.path and sys.path[0] == str(ADDON_ROOT):
			sys.path.pop(0)
	issues: list[str] = []
	contract = read_strict_json_object(ADDON_ROOT / "templates/gf_project_contract.json")
	candidate = read_strict_json_object(ADDON_ROOT / "templates/feedback_candidate.json")
	for item in validate_schema_file(contract, ADDON_ROOT / "schemas/project_contract.schema.json"):
		issues.append(f"Contract template {item['path']}: {item['message']}")
	for item in validate_schema_file(candidate, ADDON_ROOT / "schemas/feedback_candidate.schema.json"):
		issues.append(f"Feedback template {item['path']}: {item['message']}")
	return issues


def validate_protocol_versions() -> list[str]:
	sys.path.insert(0, str(ADDON_ROOT))
	try:
		from gf_ai.constants import CONTRACT_SCHEMA_VERSION, SNAPSHOT_SCHEMA_VERSION, TOOL_VERSION
	finally:
		if sys.path and sys.path[0] == str(ADDON_ROOT):
			sys.path.pop(0)
	contract_schema = read_strict_json_object(ADDON_ROOT / "schemas/project_contract.schema.json")
	snapshot_schema = read_strict_json_object(ADDON_ROOT / "schemas/project_snapshot.schema.json")
	template = read_strict_json_object(ADDON_ROOT / "templates/gf_project_contract.json")
	issues: list[str] = []
	if re.fullmatch(r"\d+\.\d+\.\d+", TOOL_VERSION) is None:
		issues.append("GF AI TOOL_VERSION must be stable SemVer.")
	contract_const = contract_schema.get("properties", {}).get("schema_version", {}).get("const")
	snapshot_const = snapshot_schema.get("properties", {}).get("schema_version", {}).get("const")
	if contract_const != CONTRACT_SCHEMA_VERSION or template.get("schema_version") != CONTRACT_SCHEMA_VERSION:
		issues.append("Project contract template, schema, and runtime version are inconsistent.")
	if snapshot_const != SNAPSHOT_SCHEMA_VERSION:
		issues.append("Project snapshot schema and runtime version are inconsistent.")
	return issues


def validate_catalogs() -> list[str]:
	issues: list[str] = []
	api = (
		read_strict_json_object(API_INDEX_PATH)
		if API_INDEX_PATH.is_file()
		else {"classes": {}, "autoloads": {}, "packages": []}
	)
	capabilities = read_strict_json_object(ADDON_ROOT / "knowledge/capabilities.json")
	recipes = read_strict_json_object(ADDON_ROOT / "knowledge/recipes.json")
	sys.path.insert(0, str(ADDON_ROOT))
	try:
		from gf_ai.catalog import catalog_reference_issues
		from gf_ai.schema import validate_schema_file
	finally:
		if sys.path and sys.path[0] == str(ADDON_ROOT):
			sys.path.pop(0)
	for value, schema_name, label in (
		(capabilities, "capability_catalog.schema.json", "Capability catalog"),
		(recipes, "recipe_catalog.schema.json", "Recipe catalog"),
	):
		for item in validate_schema_file(value, ADDON_ROOT / "schemas" / schema_name):
			issues.append(f"{label} {item['path']}: {item['message']}")
	issues.extend(catalog_reference_issues(api, capabilities, recipes))
	recipe_records = [item for item in recipes.get("recipes", []) if isinstance(item, dict)]
	capability_records = [item for item in capabilities.get("capabilities", []) if isinstance(item, dict)]
	capability_ids: set[str] = set()
	for capability in capability_records:
		capability_id = str(capability.get("id", ""))
		if not capability_id or capability_id in capability_ids:
			issues.append(f"Capability id is empty or duplicated: {capability_id!r}.")
		capability_ids.add(capability_id)
	seen_recipes: set[str] = set()
	for recipe in recipe_records:
		recipe_id = str(recipe.get("id", ""))
		if not recipe_id or recipe_id in seen_recipes:
			issues.append(f"Recipe id is empty or duplicated: {recipe_id!r}.")
		seen_recipes.add(recipe_id)
	return issues


def validate_agent_templates() -> list[str]:
	issues: list[str] = []
	skill = ADDON_ROOT / "templates/skills/gf-project-development/SKILL.md"
	metadata = ADDON_ROOT / "templates/skills/gf-project-development/agents/openai.yaml"
	text = skill.read_text(encoding="utf-8") if skill.is_file() else ""
	if not text.startswith("---\n") or "name: gf-project-development" not in text or "description:" not in text:
		issues.append("GF project skill frontmatter is missing or invalid.")
	if len(text.splitlines()) > 500:
		issues.append("GF project skill must stay under 500 lines.")
	if not metadata.is_file() or "$gf-project-development" not in metadata.read_text(encoding="utf-8"):
		issues.append("GF project skill agents/openai.yaml is missing or stale.")
	for relative in ("knowledge/architecture.md", "knowledge/workflow.md", "knowledge/migration.md", "knowledge/feedback.md", "templates/agent/project_instructions.md"):
		path = ADDON_ROOT / relative
		if not path.is_file() or not path.read_text(encoding="utf-8").strip():
			issues.append(f"Required AI knowledge file is missing or empty: {relative}.")
	return issues


def validate_platform_adapter_templates(
	template_root: Path | None = None,
) -> list[str]:
	root = PLATFORM_ADAPTER_TEMPLATE_ROOT if template_root is None else template_root
	issues: list[str] = []
	required_text = {
		"README.md": (
			"GFPlatformAdapterConformance.inspect()",
			"GFMultiplayerPeerNetworkBackend.adopt_peer()",
			"provider cancellation requested once",
			"## Native mode and fail-closed probing",
			"## Native artifact matrix",
			"## Threading and callback pump",
			"## Reproducible supply chain",
			"## Editor and export boundary",
			"`resource_path` must exactly match",
			"`metadata.native_boundary.descriptor_path`",
			"case-insensitive portable path identity",
			"`source_version` and `license_id`",
			"`metadata.native_boundary.editor_only: false`",
			"`export_scope: runtime`",
			"remove the `descriptor_path` and `dependency_lock_path` keys",
			"`metadata.native_dependencies` to empty arrays",
		),
		"platform_adapter.gd.txt": (
			"extends GFPlatformAdapter",
			"GFPlatformContractDescriptor",
			"_release_request(handle)",
			"_succeed_request(handle",
		),
		"lobby_backend.gd.txt": (
			"extends GFNetworkLobbyBackend",
			"GFNetworkLobbyOperationRequest",
			"_release_operation(handle)",
			"_succeed_operation(handle",
		),
		"adapter_contract_test.gd.txt": (
			"GFPlatformAdapterConformance.inspect",
			"test_adapter_failure_matrix",
			"Replace this sentinel with the complete adapter failure matrix.",
			"test_native_adapter_acceptance_matrix",
			"Replace this sentinel with the native Adapter acceptance matrix.",
		),
	}
	try:
		actual_files = {
			path.name
			for path in _list_owned_regular_files(root, root)
		}
	except (OSError, ValueError) as exc:
		return [
			"Platform adapter template directory violates its owned-file boundary: "
			f"{type(exc).__name__}."
		]
	expected_files = set(required_text) | {"compatibility_profile.json"}
	for missing_path in sorted(expected_files - actual_files):
		issues.append(f"Platform adapter template is missing required file: {missing_path}.")
	unexpected_count = len(actual_files - expected_files)
	if unexpected_count:
		issues.append(
			"Platform adapter template has unexpected files "
			f"(count={unexpected_count})."
		)
	for relative_path, required_fragments in required_text.items():
		path = root / relative_path
		try:
			text = _read_owned_text(path, root, ADAPTER_TEMPLATE_BYTE_LIMIT)
		except (OSError, UnicodeDecodeError) as exc:
			issues.append(
				"Platform adapter template is missing or invalid UTF-8: "
				f"{relative_path}: {type(exc).__name__}"
			)
		except ValueError as exc:
			issues.append(
				"Platform adapter template violates its owned-file boundary: "
				f"{relative_path}: {type(exc).__name__}"
			)
			continue
		if not text.strip():
			issues.append(f"Platform adapter template is empty: {relative_path}.")
			continue
		for fragment in required_fragments:
			if fragment not in text:
				issues.append(
					f"Platform adapter template {relative_path} is missing required contract text: {fragment}"
				)

	profile_path = root / "compatibility_profile.json"
	try:
		profile_source = _read_owned_text(
			profile_path,
			root,
			ADAPTER_TEMPLATE_BYTE_LIMIT,
		)
		profile = strict_json_loads(profile_source)
		if not isinstance(profile, dict):
			raise ValueError("Profile root must be an object.")
	except (OSError, UnicodeDecodeError, ValueError) as exc:
		issues.append(
			"Platform adapter compatibility profile is invalid UTF-8 JSON: "
			f"{type(exc).__name__}"
		)
	else:
		profile_schema_valid = False
		try:
			profile_schema_issues = validate_schema_file(
				profile,
				PLATFORM_ADAPTER_PROFILE_SCHEMA_PATH,
			)
		except (OSError, ValueError) as exc:
			issues.append(
				f"Platform adapter compatibility profile schema is invalid: {exc}"
			)
		else:
			profile_schema_valid = not profile_schema_issues
			for item in profile_schema_issues:
				issues.append(
					f"Platform adapter compatibility profile {item['path']}: "
					f"{item['message']}"
				)
		if profile_schema_valid:
			if not str(profile.get("profile_id", "")).strip():
				issues.append("Platform adapter compatibility profile requires profile_id.")
			if _parse_exact_stable_version(profile.get("godot_version")) is None:
				issues.append(
					"Platform adapter compatibility profile godot_version "
					"must be exact stable SemVer."
				)
			framework_version = profile.get("framework_version")
			if _parse_exact_semver(framework_version) is None:
				issues.append(
					"Platform adapter compatibility profile framework_version "
					"must be exact SemVer."
				)
			elif framework_version != read_plugin_version():
				issues.append(
					"Platform adapter compatibility profile framework_version "
					"must match the GF Framework version."
				)
			package_ids = {
				str(item.get("id", ""))
				for item in profile.get("packages", [])
				if isinstance(item, dict)
			}
			for package_id in ("gf.standard.platform", "gf.extension.network"):
				if package_id not in package_ids:
					issues.append(
						f"Platform adapter compatibility profile is missing package: {package_id}."
					)
			profile_metadata = profile.get("metadata")
			contract_versions = (
				profile_metadata.get("contract_versions", {})
				if isinstance(profile_metadata, dict)
				else {}
			)
			if not isinstance(contract_versions, dict) or not contract_versions:
				issues.append(
					"Platform adapter compatibility profile requires contract_versions metadata."
				)
			elif any(
				not isinstance(contract_id, str)
				or not contract_id.strip()
				or _parse_exact_stable_version(version) is None
				for contract_id, version in contract_versions.items()
			):
				issues.append(
					"Platform adapter contract_versions must map stable IDs to exact SemVer."
				)
			issues.extend(_validate_platform_native_profile(profile))

	try:
		recipes = read_strict_json_object(ADDON_ROOT / "knowledge/recipes.json")
		platform_recipe = next(
			(
				item
				for item in recipes.get("recipes", [])
				if isinstance(item, dict) and item.get("id") == "platform-lobby-adapter"
			),
			None,
		)
		all_of = set(
			platform_recipe.get("package_requirements", {}).get("all_of", [])
			if isinstance(platform_recipe, dict)
			else []
		)
		for package_id in ("gf.standard.platform", "gf.extension.network"):
			if package_id not in all_of:
				issues.append(f"platform-lobby-adapter recipe must require package: {package_id}.")
		platform_steps = " ".join(
			str(step)
			for step in (
				platform_recipe.get("steps", [])
				if isinstance(platform_recipe, dict)
				else []
			)
		)
		for fragment in (
			"native or GDExtension-backed providers",
			"bounded plain-data ingress queue",
			"actual exported target",
		):
			if fragment not in platform_steps:
				issues.append(
					"platform-lobby-adapter recipe is missing native acceptance guidance: "
					f"{fragment}."
				)
		capabilities = read_strict_json_object(ADDON_ROOT / "knowledge/capabilities.json")
		platform_capability = next(
			(
				item
				for item in capabilities.get("capabilities", [])
				if isinstance(item, dict) and item.get("id") == "platform-adapters"
			),
			None,
		)
		if not isinstance(platform_capability, dict) or "gf.standard.platform" not in platform_capability.get("packages", []):
			issues.append("platform-adapters capability must include gf.standard.platform.")
	except (OSError, ValueError) as exc:
		issues.append(f"Platform adapter catalog contract validation failed: {exc}")
	return issues


def validate_storage_backend_templates(
	template_root: Path | None = None,
) -> list[str]:
	root = STORAGE_BACKEND_TEMPLATE_ROOT if template_root is None else template_root
	issues: list[str] = []
	required_text = {
		"README.md": (
			"ProjectStorageBackend.PROTOCOL_VERSION",
			"replacing `MemoryStorageProviderFactory`",
			"clean Godot project",
			"Capability dictionaries are closed schemas",
			"Provider `read_record` receives the complete read budget",
			"Provider `list_records`",
			"`file_name` is a logical storage key",
			"`COM¹`/`COM²`/`COM³`",
			"`write_options.expected_revision`",
			"`write_options.create_if_absent`",
			"bounded opaque non-empty String token",
			"`GFStorageBackend` is a synchronous protocol",
			"requests Provider cancellation at most once",
			"`write_record_atomic()` must leave either the complete old record",
			"delete the previous record",
			"never full configuration, payloads, metadata",
		),
		"storage_value_limits.gd.txt": (
			"class_name ProjectStorageValueLimits",
			"func validate_plain_value(",
			"func validate_payload(",
			"value.length() > maximum_string_bytes",
			"if not is_finite(float_value)",
			"if is_same(ancestor, candidate)",
			"return ERR_INVALID_DATA",
			"return ERR_OUT_OF_MEMORY",
		),
		"storage_provider.gd.txt": (
			"class_name ProjectStorageProvider",
			"const PROTOCOL_VERSION: String = \"1.0.0\"",
			"func read_record(",
			"_read_limits: Dictionary",
			"func write_record_atomic(",
			"func list_records(",
			"_list_limits: Dictionary",
			"\"atomic_write\": false",
			"\"sync\": false",
			"return ERR_UNAVAILABLE",
		),
		"storage_provider_factory.gd.txt": (
			"class_name ProjectStorageProviderFactory",
			"func create_provider() -> ProjectStorageProvider:",
			"func create_fault_driver(",
			"func get_provider_options() -> Dictionary:",
		),
		"storage_provider_fault_driver.gd.txt": (
			"class_name ProjectStorageProviderFaultDriver",
			"FAULT_ATOMIC_COMMIT",
			"FAULT_FAILED_READ_WITH_OK",
			"FAULT_MALFORMED_READ_RESULT",
			"FAULT_POST_INITIALIZE_CAPABILITY_DRIFT",
			"func get_observation(",
		),
		"storage_backend.gd.txt": (
			"class_name ProjectStorageBackend",
			"extends GFStorageBackend",
			"candidate_provider.get_protocol_version() != PROTOCOL_VERSION",
			"post_initialize_capabilities != pre_initialize_capabilities",
			"ProjectStorageValueLimits.validate_payload(",
			"func save_data(",
			"func _save_validated_data(",
			"func _resolve_storage_key(",
			"func _write_options_are_valid(",
			"create_if_absent",
			"MAX_REVISION_TOKEN_BYTES",
			"replace(\"¹\", \"1\")",
			"ERR_OUT_OF_MEMORY",
			"func _map_provider_error(",
			"provider_error_code == int(OK)",
			"_ALLOWED_PROVIDER_ERRORS",
			"\"cancellation\": false",
			"\"sync\": false",
		),
		"storage_backend_conformance.gd.txt": (
			"class_name ProjectStorageBackendConformance",
			"func _create_provider_factory()",
			"run_rejects_invalid_providers_and_capability_drift",
			"run_enforces_write_read_and_list_budgets",
			"run_atomic_faults_and_opaque_revision_conditions_preserve_state",
			"run_normalizes_unknown_errors_and_redacts_malformed_results",
			"FAULT_FAILED_READ_WITH_OK",
			"REDACTION_CANARY_DO_NOT_EMIT",
		),
		"storage_backend_contract_test.gd.txt": (
			"extends ProjectStorageBackendConformance",
			"class MemoryStorageProviderFactory extends ProjectStorageProviderFactory",
			"class MemoryStorageProvider extends ProjectStorageProvider",
			"class MemoryStorageFaultDriver extends ProjectStorageProviderFaultDriver",
			"test_reports_closed_capabilities_before_and_after_initialize",
			"test_enforces_write_read_and_list_budgets",
			"test_atomic_faults_and_opaque_revision_conditions_preserve_state",
			"test_normalizes_unknown_errors_and_redacts_malformed_results",
			"test_defensive_copies_and_idempotent_shutdown",
			"fail_next_atomic_commit",
			"fail_next_failed_read_with_ok",
			"_assert_list_budget_covers_complete_response",
			"# --- 私有/辅助方法 ---",
			"for storage_key_value: Variant in _records:",
			"response_validation",
		),
	}
	try:
		actual_files = {
			path.name
			for path in _list_owned_regular_files(root, root)
		}
	except (OSError, ValueError) as exc:
		return [
			"Storage backend template directory violates its owned-file boundary: "
			f"{type(exc).__name__}."
		]
	expected_files = set(required_text)
	for missing_path in sorted(expected_files - actual_files):
		issues.append(
			f"Storage backend template is missing required file: {missing_path}."
		)
	unexpected_count = len(actual_files - expected_files)
	if unexpected_count:
		issues.append(
			"Storage backend template has unexpected files "
			f"(count={unexpected_count})."
		)
	for relative_path, required_fragments in required_text.items():
		path = root / relative_path
		try:
			text = _read_owned_text(
				path,
				root,
				STORAGE_ACCEPTANCE_TEMPLATE_BYTE_LIMIT,
			)
		except (OSError, UnicodeDecodeError, ValueError) as exc:
			issues.append(
				"Storage backend template is missing or invalid UTF-8: "
				f"{relative_path}: {type(exc).__name__}"
			)
			continue
		if not text.strip():
			issues.append(f"Storage backend template is empty: {relative_path}.")
			continue
		for fragment in required_fragments:
			if fragment not in text:
				issues.append(
					f"Storage backend template {relative_path} is missing "
					f"required contract text: {fragment}"
				)
		if relative_path.endswith(".gd.txt") and "JSON.stringify(" in text:
			issues.append(
				"Storage backend templates must not stringify complete "
				f"boundary values: {relative_path}."
			)
		if relative_path in {
			"storage_backend_conformance.gd.txt",
			"storage_backend_contract_test.gd.txt",
		}:
			for forbidden_fragment in ("fail_test(", "Replace this sentinel"):
				if forbidden_fragment in text:
					issues.append(
						"Storage backend contract test must be directly runnable "
						f"without a placeholder sentinel: {forbidden_fragment}"
					)
		if relative_path == "storage_backend_conformance.gd.txt":
			for forbidden_fragment in (
				"assert_eq(",
				"assert_ne(",
				"assert_not_null(",
			):
				if forbidden_fragment in text:
					issues.append(
						"Storage backend conformance must not pass Provider-derived "
						"values to verbose assertions: "
						f"{forbidden_fragment}"
					)
	return issues


def resolve_storage_backend_acceptance_engine(godot_executable: str = "") -> str:
	"""Resolve a real foreground Godot process before acceptance supervision."""
	environment = os.environ.copy()
	configured = godot_executable.strip()
	if configured:
		environment[GODOT_EXECUTABLE_ENV_VAR] = configured
	configured_environment = environment.get(
		GODOT_EXECUTABLE_ENV_VAR,
		"",
	).strip()
	candidates = (
		(configured or configured_environment,)
		if configured_environment
		else ("godot", "godot4")
	)
	for candidate in candidates:
		resolved = resolve_godot_executable(candidate, environment=environment)
		if Path(resolved).is_file() or shutil.which(resolved):
			return resolved
	return ""


def run_storage_backend_template_acceptance(
	godot_executable: str = "",
) -> dict[str, Any]:
	"""Copy templates into a clean project, import them, and run their GUT suite."""
	issues = validate_storage_backend_templates()
	if issues:
		return {
			"ok": False,
			"phase": "source_validation",
			"issues": issues,
		}

	engine = resolve_storage_backend_acceptance_engine(godot_executable)
	if not engine:
		return {
			"ok": False,
			"phase": "engine_resolution",
			"issues": ["Godot executable is required for storage template acceptance."],
		}

	try:
		with tempfile.TemporaryDirectory(
			prefix="gf-storage-template-acceptance-"
		) as temporary:
			session_root = Path(temporary)
			project_root = session_root / "project"
			with _private_owned_root(session_root):
				prepare_storage_backend_template_acceptance_project(project_root)

			private_environment = os.environ.copy()
			for directory_name, variable_name in (
				("appdata", "APPDATA"),
				("localappdata", "LOCALAPPDATA"),
				("xdg-data", "XDG_DATA_HOME"),
				("xdg-config", "XDG_CONFIG_HOME"),
				("xdg-cache", "XDG_CACHE_HOME"),
			):
				private_path = session_root / directory_name
				private_path.mkdir()
				private_environment[variable_name] = str(private_path)

			import_log = session_root / "import.log"
			import_command = [
				engine,
				"--headless",
				"--log-file",
				str(import_log),
				"--path",
				str(project_root),
				"--import",
			]
			import_result = run_supervised_process(
				import_command,
				cwd=project_root,
				environment=private_environment,
				timeout_seconds=STORAGE_ACCEPTANCE_TIMEOUT_SECONDS,
				max_stdout_characters=(
					STORAGE_ACCEPTANCE_OUTPUT_CHARACTER_LIMIT
				),
				max_stderr_characters=(
					STORAGE_ACCEPTANCE_OUTPUT_CHARACTER_LIMIT
				),
			)
			import_output = _combined_storage_acceptance_output(
				import_result,
				import_log,
			)
			if (
				import_result.return_code != 0
				or import_result.timed_out
				or import_result.cancelled
				or import_result.stdout_truncated
				or import_result.stderr_truncated
				or STORAGE_REDACTION_CANARY in import_output
				or _storage_acceptance_has_script_failure(import_output)
			):
				return _storage_acceptance_failure(
					"godot_import",
					import_result.return_code,
					import_output,
					{
						"timed_out": import_result.timed_out,
						"output_truncated": (
							import_result.stdout_truncated
							or import_result.stderr_truncated
						),
						"redaction_canary_observed": (
							STORAGE_REDACTION_CANARY in import_output
						),
					},
				)

			gut_log = session_root / "gut.log"
			gut_command = [
				engine,
				"--headless",
				"--log-file",
				str(gut_log),
				"--path",
				str(project_root),
				"-s",
				"res://tests/gf_core/support/gf_gut_cli.gd",
				(
					"-gtest=res://adapters/storage/sample/"
					"storage_backend_contract_test.gd"
				),
				(
					"-gpre_run_script=res://tests/gf_core/support/"
					"gf_gut_pre_run_hook.gd"
				),
				(
					"-gpost_run_script=res://tests/gf_core/support/"
					"gf_gut_post_run_hook.gd"
				),
				"-gexit",
			]
			gut_result = run_supervised_process(
				gut_command,
				cwd=project_root,
				environment=private_environment,
				timeout_seconds=STORAGE_ACCEPTANCE_TIMEOUT_SECONDS,
				max_stdout_characters=(
					STORAGE_ACCEPTANCE_OUTPUT_CHARACTER_LIMIT
				),
				max_stderr_characters=(
					STORAGE_ACCEPTANCE_OUTPUT_CHARACTER_LIMIT
				),
			)
			gut_output = _combined_storage_acceptance_output(
				gut_result,
				gut_log,
			)
			passing_match = re.search(
				r"(?m)^\s*Passing Tests\s+(\d+)\s*$",
				gut_output,
			)
			passing_tests = (
				int(passing_match.group(1))
				if passing_match is not None
				else 0
			)
			lifecycle_ok = _storage_acceptance_lifecycle_ok(gut_output)
			if (
				gut_result.return_code != 0
				or gut_result.timed_out
				or gut_result.cancelled
				or gut_result.stdout_truncated
				or gut_result.stderr_truncated
				or STORAGE_REDACTION_CANARY in gut_output
				or _storage_acceptance_has_script_failure(gut_output)
				or "---- All tests passed! ----" not in gut_output
				or passing_tests != 8
				or not lifecycle_ok
			):
				return _storage_acceptance_failure(
					"gut",
					gut_result.return_code,
					gut_output,
					{
						"passing_tests": passing_tests,
						"lifecycle_ok": lifecycle_ok,
						"timed_out": gut_result.timed_out,
						"output_truncated": (
							gut_result.stdout_truncated
							or gut_result.stderr_truncated
						),
						"redaction_canary_observed": (
							STORAGE_REDACTION_CANARY in gut_output
						),
					},
				)
			return {
				"ok": True,
				"phase": "complete",
				"import_return_code": import_result.return_code,
				"gut_return_code": gut_result.return_code,
				"passing_tests": passing_tests,
				"lifecycle_ok": lifecycle_ok,
			}
	except (OSError, RuntimeError, UnicodeError, ValueError) as exc:
		return {
			"ok": False,
			"phase": "environment",
			"issues": [
				"Storage template acceptance environment failed: "
				f"{type(exc).__name__}."
			],
		}


def prepare_storage_backend_template_acceptance_project(
	project_root: Path,
) -> None:
	if os.path.lexists(project_root):
		raise FileExistsError(
			"Storage template acceptance project root must not already exist."
		)
	_ensure_owned_directory_tree(project_root.parent, project_root)
	adapter_root = project_root / "adapters/storage/sample"
	_ensure_owned_directory_tree(project_root, adapter_root)
	_copy_owned_tree(
		ROOT / "addons/gf",
		project_root / "addons/gf",
		project_root,
	)
	_copy_owned_tree(
		ROOT / "addons/gut",
		project_root / "addons/gut",
		project_root,
	)
	_copy_owned_tree(
		ROOT / "tests/gf_core/support",
		project_root / "tests/gf_core/support",
		project_root,
	)
	for source_path in _list_owned_regular_files(
		STORAGE_BACKEND_TEMPLATE_ROOT,
		STORAGE_BACKEND_TEMPLATE_ROOT,
	):
		if not source_path.name.endswith(".gd.txt"):
			continue
		target_name = source_path.name.removesuffix(".txt")
		_copy_owned_regular_file(
			source_path,
			adapter_root / target_name,
			STORAGE_BACKEND_TEMPLATE_ROOT,
			STORAGE_ACCEPTANCE_COPY_SINGLE_FILE_LIMIT,
			project_root,
		)
	_write_storage_acceptance_project_file(project_root)


def _write_storage_acceptance_project_file(project_root: Path) -> None:
	payload = "\n".join([
			"; Generated isolated GF storage Adapter acceptance project.",
			"config_version=5",
			"",
			"[application]",
			'config/name="GF Storage Adapter Acceptance"',
			'config/features=PackedStringArray("4.7", "GL Compatibility")',
			"",
			"[debug]",
			"gdscript/warnings/directory_rules={",
			'"res://adapters": 1,',
			'"res://addons/gf": 1,',
			'"res://addons/gut": 0',
			"}",
			"gdscript/warnings/untyped_declaration=1",
			"gdscript/warnings/inferred_declaration=1",
			"gdscript/warnings/unsafe_property_access=1",
			"gdscript/warnings/unsafe_method_access=1",
			"gdscript/warnings/unsafe_cast=1",
			"gdscript/warnings/unsafe_call_argument=1",
			"gdscript/warnings/return_value_discarded=1",
			"gdscript/warnings/missing_await=1",
			"",
		]).encode("utf-8")
	_write_owned_target_bytes(
		project_root / "project.godot",
		payload,
		project_root,
	)


def _combined_storage_acceptance_output(
	result: SupervisedProcessResult,
	log_path: Path,
) -> str:
	log_text = _read_owned_text(
		log_path,
		log_path.parent,
		STORAGE_ACCEPTANCE_LOG_BYTE_LIMIT,
		require_nonempty=True,
		errors="replace",
	)
	return "\n".join((result.stdout, result.stderr, log_text))


def _storage_acceptance_lifecycle_ok(output: str) -> bool:
	normalized_output = output.lower()
	if any(
		pattern in normalized_output
		for pattern in _STORAGE_ACCEPTANCE_EXIT_LEAK_PATTERNS
	):
		return False
	encoded_payloads = [
		line.split(_STORAGE_ACCEPTANCE_LIFECYCLE_PREFIX, 1)[1].strip()
		for line in output.splitlines()
		if _STORAGE_ACCEPTANCE_LIFECYCLE_PREFIX in line
	]
	if not encoded_payloads or len(encoded_payloads) > 2:
		return False
	if any(payload != encoded_payloads[0] for payload in encoded_payloads[1:]):
		return False
	if (
		not encoded_payloads[0]
		or len(encoded_payloads[0].encode("utf-8"))
		> _STORAGE_ACCEPTANCE_LIFECYCLE_MAX_JSON_BYTES
	):
		return False
	try:
		payload = json.loads(encoded_payloads[0])
	except json.JSONDecodeError:
		return False
	if (
		not isinstance(payload, dict)
		or set(payload) != _STORAGE_ACCEPTANCE_LIFECYCLE_REQUIRED_KEYS
		or type(payload["schema_version"]) is not int
		or payload["schema_version"] != 1
		or type(payload["ok"]) is not bool
		or type(payload["baseline_available"]) is not bool
		or type(payload["warning_tracking_available"]) is not bool
		or type(payload["details_truncated"]) is not bool
		or type(payload["unhandled_warning_count"]) is not int
		or payload["unhandled_warning_count"] < 0
		or type(payload["orphan_count"]) is not int
		or payload["orphan_count"] < 0
		or not isinstance(payload["warnings"], list)
		or not isinstance(payload["orphans"], list)
		or not isinstance(payload["configuration_error"], str)
		or len(payload["configuration_error"].encode("utf-8")) > 512
	):
		return False
	expected_ok = (
		payload["baseline_available"]
		and payload["warning_tracking_available"]
		and payload["unhandled_warning_count"] == 0
		and payload["orphan_count"] == 0
		and payload["warnings"] == []
		and payload["orphans"] == []
		and payload["details_truncated"] is False
		and payload["configuration_error"] == ""
	)
	return (
		payload["ok"] is expected_ok
		and expected_ok
	)


def _storage_acceptance_has_script_failure(output: str) -> bool:
	return any(
		marker in output
		for marker in (
			"SCRIPT ERROR:",
			"Parse Error:",
			"Failed to load script",
			"GDScript reload warning",
			"WARNING: The script",
		)
	)


def _storage_acceptance_failure(
	phase: str,
	return_code: int,
	output: str,
	fields: dict[str, Any] | None = None,
) -> dict[str, Any]:
	diagnostics: list[str] = []
	for marker, diagnostic in (
		("SCRIPT ERROR:", "Storage acceptance reported a script error."),
		("Parse Error:", "Storage acceptance reported a parse error."),
		("Failed to load script", "Storage acceptance reported a script load failure."),
		("GDScript reload warning", "Storage acceptance reported a script reload warning."),
	):
		if marker in output:
			diagnostics.append(diagnostic)
	payload: dict[str, Any] = {
		"ok": False,
		"phase": phase,
		"return_code": return_code,
		"diagnostics": diagnostics,
		"all_tests_passed": "---- All tests passed! ----" in output,
	}
	if fields:
		payload.update(fields)
	return payload


def _validate_platform_native_profile(profile: dict[str, Any]) -> list[str]:
	issues: list[str] = []
	metadata = profile.get("metadata")
	if not isinstance(metadata, dict):
		return ["Platform adapter compatibility profile requires metadata."]
	native_boundary = metadata.get("native_boundary")
	if not isinstance(native_boundary, dict):
		return ["Platform adapter compatibility profile requires native_boundary metadata."]

	mode_value = native_boundary.get("mode")
	mode = mode_value if isinstance(mode_value, str) else ""
	if mode not in ("script_only", "optional", "required"):
		issues.append(
			"Platform adapter native_boundary.mode must be script_only, optional, or required."
		)
	editor_only = native_boundary.get("editor_only")
	if not isinstance(editor_only, bool):
		issues.append("Native boundary editor_only must be bool.")
	target_godot_version = _parse_exact_stable_version(profile.get("godot_version"))

	artifacts_value = profile.get("artifacts")
	if not isinstance(artifacts_value, list):
		issues.append("Platform adapter compatibility profile artifacts must be an array.")
		artifacts: list[dict[str, Any]] = []
	else:
		artifacts = [item for item in artifacts_value if isinstance(item, dict)]
		if len(artifacts) != len(artifacts_value):
			issues.append("Platform adapter compatibility profile artifacts must contain objects.")

	artifact_ids: set[str] = set()
	artifact_paths: dict[str, str] = {}
	descriptor_artifacts: list[dict[str, Any]] = []
	native_libraries: list[dict[str, Any]] = []
	library_targets: set[tuple[str, str, str]] = set()
	for artifact in artifacts:
		artifact_id = artifact.get("id")
		path = artifact.get("path")
		kind = artifact.get("kind")
		if not isinstance(artifact_id, str) or not artifact_id.strip():
			issues.append("Every native artifact requires a stable non-empty id.")
		elif artifact_id in artifact_ids:
			issues.append(f"Native artifact id is duplicated: {artifact_id}.")
		else:
			artifact_ids.add(artifact_id)
		if not _is_project_owned_native_path(path):
			issues.append(
				f"Native artifact {artifact_id!r} requires a canonical cross-platform "
				"project-owned res:// path."
			)
		else:
			path_identity = portable_ownership_path_identity(path)
			if path_identity in artifact_paths:
				issues.append(
					f"Native artifact path is duplicated across portable case-insensitive "
					f"filesystems: {path!r} conflicts with {artifact_paths[path_identity]!r}."
				)
			else:
				artifact_paths[path_identity] = path
		if not isinstance(kind, str) or kind not in (
			"gdextension_descriptor",
			"native_library",
		):
			issues.append(f"Native artifact {artifact_id!r} has unsupported kind: {kind!r}.")

		sha256 = artifact.get("sha256")
		hash_is_placeholder = sha256 == NATIVE_HASH_PLACEHOLDER
		if not hash_is_placeholder and (
			not isinstance(sha256, str)
			or re.fullmatch(r"[0-9a-f]{64}", sha256) is None
		):
			issues.append(
				f"Native artifact {artifact_id!r} sha256 must be a lowercase digest or explicit template placeholder."
			)
		size_bytes = artifact.get("size_bytes")
		if isinstance(size_bytes, bool) or not isinstance(size_bytes, int) or size_bytes < 0:
			issues.append(f"Native artifact {artifact_id!r} size_bytes must be a non-negative integer.")
		elif hash_is_placeholder and size_bytes != 0:
			issues.append(
				f"Unverified native artifact {artifact_id!r} must retain size_bytes = 0."
			)
		elif not hash_is_placeholder and size_bytes <= 0:
			issues.append(
				f"Verified native artifact {artifact_id!r} requires a positive size_bytes value."
			)

		artifact_metadata = artifact.get("metadata")
		if not isinstance(artifact_metadata, dict):
			issues.append(f"Native artifact {artifact_id!r} requires metadata.")
			continue
		export_scope = artifact_metadata.get("export_scope")
		if not isinstance(export_scope, str) or export_scope not in ("editor", "runtime"):
			issues.append(
				f"Native artifact {artifact_id!r} export_scope must be editor or runtime."
			)
		elif isinstance(editor_only, bool) and mode in ("optional", "required"):
			expected_export_scope = "editor" if editor_only else "runtime"
			if export_scope != expected_export_scope:
				adapter_scope = (
					"an editor-only adapter"
					if editor_only
					else "a non-editor-only adapter"
				)
				issues.append(
					f"Native artifact {artifact_id!r} for {adapter_scope} "
					f"must use {expected_export_scope} export_scope."
				)
		if kind == "gdextension_descriptor":
			descriptor_artifacts.append(artifact)
			if isinstance(path, str) and not path.endswith(".gdextension"):
				issues.append(
					f"Native descriptor {artifact_id!r} must use a .gdextension path."
				)
			minimum_godot_version = artifact_metadata.get("minimum_godot_version")
			parsed_minimum_godot_version = _parse_exact_stable_version(
				minimum_godot_version
			)
			if parsed_minimum_godot_version is None:
				issues.append(
					f"Native descriptor {artifact_id!r} requires an exact minimum_godot_version."
				)
			elif (
				target_godot_version is not None
				and parsed_minimum_godot_version > target_godot_version
			):
				issues.append(
					f"Native descriptor {artifact_id!r} minimum_godot_version "
					f"{minimum_godot_version} exceeds target Godot version "
					f"{profile.get('godot_version')}."
				)
			if not isinstance(artifact_metadata.get("reloadable"), bool):
				issues.append(f"Native descriptor {artifact_id!r} requires a bool reloadable policy.")
		elif kind == "native_library":
			native_libraries.append(artifact)
			target_values = tuple(
				artifact_metadata.get(field_name)
				for field_name in ("platform", "architecture", "build_configuration")
			)
			if any(not isinstance(value, str) or not value.strip() for value in target_values):
				issues.append(
					f"Native library {artifact_id!r} requires an exact platform/architecture/build_configuration tuple."
				)
			else:
				target = (target_values[0], target_values[1], target_values[2])
				if target in library_targets:
					issues.append(f"Native library target tuple is duplicated: {target}.")
				library_targets.add(target)
			for field_name in ("source_id", "source_version", "license_id"):
				value = artifact_metadata.get(field_name)
				if not isinstance(value, str) or not value.strip():
					issues.append(
						f"Native library {artifact_id!r} requires non-empty {field_name}."
					)

	if mode == "script_only":
		if artifacts:
			issues.append("script_only native mode must not declare native artifacts.")
	else:
		if len(descriptor_artifacts) != 1:
			issues.append("optional and required native modes require exactly one descriptor artifact.")
		if not native_libraries:
			issues.append("optional and required native modes require at least one native library.")

	descriptor_path = native_boundary.get("descriptor_path")
	if mode == "script_only":
		if "descriptor_path" in native_boundary:
			issues.append("script_only native mode must not declare descriptor_path.")
	elif mode in ("optional", "required"):
		if not _is_project_owned_native_path(descriptor_path):
			issues.append(
				"Native boundary descriptor_path must be a canonical cross-platform "
				"project-owned res:// path."
			)
		elif len(descriptor_artifacts) == 1 and descriptor_artifacts[0].get("path") != descriptor_path:
			issues.append("Native boundary descriptor_path must match the descriptor artifact.")

	probe = native_boundary.get("availability_probe")
	if not isinstance(probe, dict):
		issues.append("Native boundary requires an availability_probe object.")
	else:
		probe_kind = probe.get("kind")
		if not isinstance(probe_kind, str) or probe_kind not in ("class_db", "resource"):
			issues.append("Native availability_probe.kind must be class_db or resource.")
		elif probe_kind == "class_db":
			if not isinstance(probe.get("class_name"), str) or not probe["class_name"].strip():
				issues.append("class_db availability probes require class_name.")
		else:
			resource_path = probe.get("resource_path")
			if not _is_project_owned_native_path(resource_path):
				issues.append(
					"resource availability probes require a canonical cross-platform "
					"project-owned res:// resource_path."
				)
			elif (
				mode in ("optional", "required")
				and (
					len(descriptor_artifacts) != 1
					or descriptor_artifacts[0].get("path") != resource_path
				)
			):
				issues.append(
					"resource availability_probe.resource_path must match the "
					"descriptor artifact."
				)
			elif mode == "script_only":
				issues.append(
					"resource availability probes require a declared descriptor "
					"artifact and are invalid in script_only mode."
				)
		if probe.get("side_effect_free") is not True:
			issues.append("Native availability probes must declare side_effect_free = true.")

	for field_name in ("call_thread", "callback_thread"):
		thread_name = native_boundary.get(field_name)
		if not isinstance(thread_name, str) or thread_name not in (
			"main",
			"worker",
			NATIVE_THREAD_PLACEHOLDER,
		):
			issues.append(
				f"Native boundary {field_name} must be main, worker, or the explicit template placeholder."
			)
	callback_pump = native_boundary.get("callback_pump")
	if not isinstance(callback_pump, str) or not callback_pump.strip():
		issues.append("Native boundary requires a non-empty callback_pump.")
	shutdown_timeout_msec = native_boundary.get("shutdown_timeout_msec")
	if (
		isinstance(shutdown_timeout_msec, bool)
		or not isinstance(shutdown_timeout_msec, int)
		or shutdown_timeout_msec <= 0
	):
		issues.append("Native boundary shutdown_timeout_msec must be a positive integer.")
	permissions = native_boundary.get("permissions")
	if not isinstance(permissions, list) or any(
		not isinstance(permission, str) or not permission.strip()
		for permission in permissions
	):
		issues.append("Native boundary permissions must be an array of stable non-empty strings.")
	dependency_lock_path = native_boundary.get("dependency_lock_path")
	if mode == "script_only":
		if "dependency_lock_path" in native_boundary:
			issues.append("script_only native mode must not declare dependency_lock_path.")
	elif mode in ("optional", "required"):
		if not _is_project_owned_native_path(dependency_lock_path):
			issues.append(
				"Native boundary dependency_lock_path must be a canonical cross-platform "
				"project-owned res:// path."
			)
	if not isinstance(native_boundary.get("offline_rebuild_verified"), bool):
		issues.append("Native boundary offline_rebuild_verified must be bool.")

	export_targets_value = native_boundary.get("export_targets")
	if not isinstance(export_targets_value, list):
		issues.append("Native boundary export_targets must be an array.")
		export_targets: set[tuple[str, str, str]] = set()
	else:
		export_targets = set()
		for target_value in export_targets_value:
			if not isinstance(target_value, dict):
				issues.append("Native boundary export_targets must contain objects.")
				continue
			target_values = tuple(
				target_value.get(field_name)
				for field_name in ("platform", "architecture", "build_configuration")
			)
			if any(not isinstance(value, str) or not value.strip() for value in target_values):
				issues.append(
					"Every native export target requires platform, architecture, and build_configuration."
				)
				continue
			target = (target_values[0], target_values[1], target_values[2])
			if target in export_targets:
				issues.append(f"Native export target tuple is duplicated: {target}.")
			export_targets.add(target)
	if mode == "script_only" and export_targets:
		issues.append("script_only native mode must not declare native export targets.")
	elif mode in ("optional", "required") and export_targets != library_targets:
		issues.append("Native export targets must exactly match declared native library tuples.")

	dependencies_value = metadata.get("native_dependencies")
	if mode == "script_only":
		if dependencies_value not in (None, []):
			issues.append("script_only native mode must not declare native_dependencies.")
	elif not isinstance(dependencies_value, list) or not dependencies_value:
		issues.append("Native modes require a non-empty native_dependencies array.")
	else:
		dependency_ids: set[str] = set()
		dependencies_by_id: dict[str, dict[str, Any]] = {}
		for dependency in dependencies_value:
			if not isinstance(dependency, dict):
				issues.append("native_dependencies must contain objects.")
				continue
			dependency_id = dependency.get("id")
			if not isinstance(dependency_id, str) or not dependency_id.strip():
				issues.append("Every native dependency requires a stable non-empty id.")
			elif dependency_id in dependency_ids:
				issues.append(f"Native dependency id is duplicated: {dependency_id}.")
			else:
				dependency_ids.add(dependency_id)
				dependencies_by_id[dependency_id] = dependency
			for field_name in ("version", "source", "license_id"):
				value = dependency.get(field_name)
				if not isinstance(value, str) or not value.strip():
					issues.append(
						f"Native dependency {dependency_id!r} requires non-empty {field_name}."
					)
			sha256 = dependency.get("sha256")
			if sha256 != NATIVE_HASH_PLACEHOLDER and (
				not isinstance(sha256, str)
				or re.fullmatch(r"[0-9a-f]{64}", sha256) is None
			):
				issues.append(
					f"Native dependency {dependency_id!r} sha256 must be a lowercase digest or explicit template placeholder."
				)
		for artifact in native_libraries:
			artifact_metadata = artifact.get("metadata")
			if not isinstance(artifact_metadata, dict):
				continue
			source_id = artifact_metadata.get("source_id")
			if not isinstance(source_id, str) or source_id not in dependency_ids:
				issues.append(
					f"Native library {artifact.get('id')!r} source_id must reference native_dependencies."
				)
				continue
			dependency = dependencies_by_id[source_id]
			for field_name, dependency_field_name in (
				("source_version", "version"),
				("license_id", "license_id"),
			):
				artifact_value = artifact_metadata.get(field_name)
				dependency_value = dependency.get(dependency_field_name)
				if (
					isinstance(artifact_value, str)
					and artifact_value.strip()
					and isinstance(dependency_value, str)
					and dependency_value.strip()
					and artifact_value != dependency_value
				):
					issues.append(
						f"Native library {artifact.get('id')!r} {field_name} must "
						f"match native dependency {source_id!r} {dependency_field_name}."
					)
	return issues


def _parse_exact_semver(value: Any) -> SemVer | None:
	if (
		not isinstance(value, str)
		or value != value.strip()
		or len(value) > 128
	):
		return None
	try:
		return parse_semver(value)
	except ValueError:
		return None


def _parse_exact_stable_version(value: Any) -> SemVer | None:
	parsed = _parse_exact_semver(value)
	if (
		parsed is None
		or not parsed.is_stable
		or value != f"{parsed.major}.{parsed.minor}.{parsed.patch}"
	):
		return None
	return parsed


def _is_project_owned_native_path(value: Any) -> bool:
	if not isinstance(value, str):
		return False
	return (
		normalize_portable_ownership_path(value) == value
		and not is_reserved_framework_resource_path(value)
	)


def _read_budgeted_plugin_source(
	path: Path,
	owner_root: Path,
	budget: PluginSourceBudget,
	limits: PluginSourceLimits,
	work_budget: PluginWorkBudget,
	work_limits: PluginWorkLimits,
	*,
	already_consumed: bool = False,
) -> bytes:
	absolute_path, metadata = _assert_owned_path(
		path,
		owner_root,
		require_file=True,
	)
	if not already_consumed:
		budget.consume_file(metadata.st_size, limits)
	budget.consume_read_file(metadata.st_size, limits)
	work_budget.consume_source_bytes(metadata.st_size, work_limits)
	root_chain_before = _snapshot_absolute_directory_chain(
		Path(os.path.abspath(owner_root))
	)
	payload = _read_owned_bytes(
		absolute_path,
		owner_root,
		limits.max_single_file_bytes,
		work_budget=work_budget,
		work_limits=work_limits,
		expected_metadata=metadata,
	)
	root_chain_after = _snapshot_absolute_directory_chain(
		Path(os.path.abspath(owner_root))
	)
	if not _same_directory_chain_identity(root_chain_before, root_chain_after):
		raise ValueError("Plugin source owner identity changed while it was read.")
	return payload


def _bounded_owned_tree_files(
	directory: Path,
	owner_root: Path,
	budget: PluginSourceBudget,
	limits: PluginSourceLimits,
) -> list[Path]:
	absolute_directory, _directory_stat = _assert_owned_path(
		directory,
		owner_root,
		require_directory=True,
	)
	absolute_root = Path(os.path.abspath(owner_root))
	root_chain_before = _snapshot_absolute_directory_chain(absolute_root)
	budget.consume_directory(limits)
	pending = [absolute_directory]
	files: list[Path] = []
	while pending:
		source_directory = pending.pop()
		_before_path, directory_before = _assert_owned_path(
			source_directory,
			absolute_root,
			require_directory=True,
		)
		source_chain_before = _snapshot_owned_directory_chain(
			absolute_root,
			source_directory,
		)
		entries: list[os.DirEntry[str]] = []
		with os.scandir(source_directory) as iterator:
			for entry in iterator:
				if (
					len(entries)
					+ budget.files
					+ budget.directories
					>= limits.max_files + limits.max_directories
				):
					raise ValueError("Plugin source traversal budget exceeded.")
				entries.append(entry)
		for entry in sorted(entries, key=lambda item: item.name):
			entry_path = Path(entry.path)
			_path, entry_stat = _assert_owned_path(
				entry_path,
				absolute_root,
			)
			if stat.S_ISDIR(entry_stat.st_mode):
				budget.consume_directory(limits)
				if not _blocked(entry_path):
					pending.append(entry_path)
				continue
			if not stat.S_ISREG(entry_stat.st_mode):
				raise ValueError("Plugin source tree contains a non-regular entry.")
			budget.consume_file(entry_stat.st_size, limits)
			if not _blocked(entry_path):
				files.append(entry_path)
		try:
			directory_after = os.lstat(source_directory)
		except OSError as exc:
			raise ValueError(
				"Plugin source directory disappeared during enumeration."
			) from exc
		source_chain_after = _snapshot_owned_directory_chain(
			absolute_root,
			source_directory,
		)
		if (
			not _same_file_identity(directory_before, directory_after)
			or not _same_directory_chain_identity(
				source_chain_before,
				source_chain_after,
			)
		):
			raise ValueError("Plugin source directory changed during enumeration.")
	root_chain_after = _snapshot_absolute_directory_chain(absolute_root)
	if not _same_directory_chain_identity(root_chain_before, root_chain_after):
		raise ValueError("Plugin source owner identity changed during enumeration.")
	return sorted(files)


def build_plugin_archive(
	output: Path,
	version: str,
	*,
	work_budget: PluginWorkBudget | None = None,
	work_limits: PluginWorkLimits | None = None,
) -> None:
	if _parse_exact_semver(version) is None:
		raise ValueError(f"Plugin version must be SemVer: {version!r}")
	active_work_budget = work_budget or PluginWorkBudget()
	active_work_limits = work_limits or PluginWorkLimits()
	entries = plugin_entries(
		version,
		work_budget=active_work_budget,
		work_limits=active_work_limits,
	)
	absolute_output = Path(os.path.abspath(output))
	absolute_parent = absolute_output.parent
	if not absolute_parent.is_dir():
		raise ValueError("Plugin output parent must be an existing directory.")
	candidate = absolute_parent / (
		f".{absolute_output.name}.gf-ai-{os.getpid()}-"
		f"{secrets.token_hex(16)}.tmp"
	)
	with _OwnedRootBinding(absolute_parent) as output_binding:
		target = output_binding.create_target(candidate)
		target_closed = False
		published = False
		try:
			with os.fdopen(
				os.dup(target.file_descriptor),
				"w+b",
				closefd=True,
			) as raw_stream:
				budgeted_stream = _BudgetedBinaryIO(
					raw_stream,
					active_work_budget,
					active_work_limits,
					charge_output=True,
				)
				with zipfile.ZipFile(
					budgeted_stream,
					"w",
					compression=zipfile.ZIP_DEFLATED,
					compresslevel=9,
				) as archive:
					for name, content in sorted(entries.items()):
						info = zipfile.ZipInfo(name, date_time=ZIP_TIMESTAMP)
						info.create_system = 3
						info.compress_type = zipfile.ZIP_DEFLATED
						info.external_attr = 0o644 << 16
						archive.writestr(info, content)
				budgeted_stream.flush()
				os.fsync(budgeted_stream.fileno())
			opened_after = os.fstat(target.file_descriptor)
			output_binding.verify_target(target, opened_after)
			output_binding.publish_target(
				target,
				absolute_output,
				opened_after,
			)
			published = True
			os.close(target.file_descriptor)
			target_closed = True
		finally:
			if not target_closed:
				os.close(target.file_descriptor)
			if not published:
				output_binding.unlink_target_if_identity(
					candidate,
					target.opened_metadata,
				)


def plugin_entries(
	version: str,
	limits: PluginSourceLimits | None = None,
	*,
	work_budget: PluginWorkBudget | None = None,
	work_limits: PluginWorkLimits | None = None,
) -> dict[str, bytes]:
	active_limits = limits or PluginSourceLimits()
	active_work_budget = work_budget or PluginWorkBudget()
	active_work_limits = work_limits or PluginWorkLimits()
	budget = PluginSourceBudget()
	entries: dict[str, bytes] = {}
	manifest = {
		"name": PLUGIN_NAME,
		"version": version,
		"description": "Contract-driven GF Framework project development with reviewed contract migration, capability readiness, verified API context, and approval-gated feedback.",
		"author": {"name": "GF Framework Maintainers", "url": "https://github.com/C76GN/gf-framework"},
		"homepage": "https://gf-framework.readthedocs.io/",
		"repository": "https://github.com/C76GN/gf-framework",
		"license": "Apache-2.0",
		"keywords": ["godot", "gf-framework", "game-development", "mcp", "skills"],
		"skills": "./skills/",
		"mcpServers": "./.mcp.json",
		"interface": {
			"displayName": "GF AI Developer",
			"shortDescription": "Build Godot projects with verified GF context",
			"longDescription": "Reads explicit project intent, plans target-bound contract migrations for interactive human approval, queries versioned GF capabilities and APIs, reports bounded capability readiness and project drift, guides provider-neutral adapter boundaries, and drafts redacted framework feedback that cannot be submitted without explicit approval.",
			"developerName": "GF Framework Maintainers",
			"category": "Developer Tools",
			"capabilities": ["Read", "Write"],
			"websiteURL": "https://gf-framework.readthedocs.io/",
			"defaultPrompt": [
				"Implement this feature using my GF project contract",
				"Plan and review my GF project contract migration",
				"Find the correct installed GF capability and API",
				"Triage this project finding for GF feedback"
			],
			"brandColor": "#2E7D66",
		},
	}
	mcp = {
		"mcpServers": {
			"gf-project": {
				"title": "GF Project",
				"description": "Versioned GF project context, API discovery, validation, and approval-gated feedback.",
				"cwd": ".",
				"command": "python",
				"args": ["./runtime/gf_ai_mcp_server.py"],
			}
		}
	}
	_add_plugin_entry(
		entries,
		".codex-plugin/plugin.json",
		_json_bytes(manifest),
		budget,
		active_limits,
	)
	_add_plugin_entry(
		entries,
		".mcp.json",
		_json_bytes(mcp),
		budget,
		active_limits,
	)
	budget.total_bytes = budget.output_bytes
	license_payload = _read_budgeted_plugin_source(
		ROOT / "LICENSE.md",
		ROOT,
		budget,
		active_limits,
		active_work_budget,
		active_work_limits,
	)
	_add_plugin_entry(
		entries,
		"LICENSE.md",
		license_payload,
		budget,
		active_limits,
	)
	policy_payload = _read_budgeted_plugin_source(
		ARTIFACT_POLICY_PATH,
		ROOT,
		budget,
		active_limits,
		active_work_budget,
		active_work_limits,
	)
	_add_plugin_entry(
		entries,
		"project_artifact_policy.json",
		policy_payload,
		budget,
		active_limits,
	)
	source_files = _bounded_owned_tree_files(
		ADDON_ROOT,
		ADDON_ROOT,
		budget,
		active_limits,
	)
	for path in source_files:
		relative = path.relative_to(ADDON_ROOT).as_posix()
		payload: bytes | None = None
		if relative.startswith("gf_ai/") or relative in ("gf_ai_project.py", "gf_ai_mcp_server.py"):
			payload = _read_budgeted_plugin_source(
				path,
				ADDON_ROOT,
				budget,
				active_limits,
				active_work_budget,
				active_work_limits,
				already_consumed=True,
			)
			_add_plugin_entry(
				entries,
				f"runtime/{relative}",
				payload,
				budget,
				active_limits,
			)
		elif relative.startswith(("knowledge/", "schemas/", "templates/")):
			payload = _read_budgeted_plugin_source(
				path,
				ADDON_ROOT,
				budget,
				active_limits,
				active_work_budget,
				active_work_limits,
				already_consumed=True,
			)
			_add_plugin_entry(
				entries,
				relative,
				payload,
				budget,
				active_limits,
			)
		if relative.startswith("templates/skills/gf-project-development/"):
			if payload is None:
				payload = _read_budgeted_plugin_source(
					path,
					ADDON_ROOT,
					budget,
					active_limits,
					active_work_budget,
					active_work_limits,
					already_consumed=True,
				)
			relative = path.relative_to(ADDON_ROOT / "templates/skills").as_posix()
			_add_plugin_entry(
				entries,
				f"skills/{relative}",
				payload,
				budget,
				active_limits,
			)
	return entries


def _add_plugin_entry(
	entries: dict[str, bytes],
	name: str,
	payload: bytes,
	budget: PluginSourceBudget,
	limits: PluginSourceLimits,
) -> None:
	normalized_name = _normalized_plugin_archive_path(name)
	if normalized_name != name:
		raise ValueError("Plugin output entry path is not canonical.")
	budget.consume_output_entry(name, len(payload), limits)
	entries[name] = payload


def _append_plugin_archive_issue(
	issues: list[str],
	rule_id: str,
	label: str = "archive",
) -> None:
	if len(issues) >= PLUGIN_ARCHIVE_ISSUE_LIMIT:
		if issues and issues[-1] != "ai_kit.archive.issue_budget_exceeded archive":
			issues[-1] = "ai_kit.archive.issue_budget_exceeded archive"
		return
	safe_label = (
		label
		if re.fullmatch(r"(?:archive|archive-entry-[1-9]\d{0,5}|expected-entry)", label)
		is not None
		else "archive"
	)
	issue = f"{rule_id} {safe_label}"
	if issue not in issues:
		issues.append(issue)


def _preflight_plugin_archive(
	payload: bytes,
	work_budget: PluginWorkBudget,
	work_limits: PluginWorkLimits,
) -> PluginArchivePreflight:
	archive_size = len(payload)
	if archive_size > PLUGIN_ARCHIVE_BYTE_LIMIT:
		raise ValueError("ai_kit.archive.file_budget_exceeded")
	if archive_size < PLUGIN_ARCHIVE_EOCD_STRUCT.size:
		raise ValueError("ai_kit.archive.invalid")
	tail_size = min(
		archive_size,
		PLUGIN_ARCHIVE_EOCD_STRUCT.size + 65_535,
	)
	work_budget.consume_io_bytes(tail_size, work_limits)
	tail = payload[-tail_size:]
	eocd_offset = -1
	search_end = len(tail)
	while True:
		candidate_offset = tail.rfind(
			PLUGIN_ARCHIVE_EOCD_SIGNATURE,
			0,
			search_end,
		)
		if candidate_offset < 0:
			break
		if candidate_offset + PLUGIN_ARCHIVE_EOCD_STRUCT.size <= len(tail):
			fields = PLUGIN_ARCHIVE_EOCD_STRUCT.unpack_from(tail, candidate_offset)
			comment_size = fields[-1]
			if (
				candidate_offset
				+ PLUGIN_ARCHIVE_EOCD_STRUCT.size
				+ comment_size
				== len(tail)
			):
				eocd_offset = candidate_offset
				break
		search_end = candidate_offset
	if eocd_offset < 0:
		raise ValueError("ai_kit.archive.invalid")
	(
		_signature,
		disk_number,
		central_directory_disk,
		disk_entry_count,
		entry_count,
		central_directory_size,
		central_directory_offset,
		comment_size,
	) = PLUGIN_ARCHIVE_EOCD_STRUCT.unpack_from(tail, eocd_offset)
	if comment_size != 0:
		raise ValueError("ai_kit.archive.comment_forbidden")
	if (
		disk_number != 0
		or central_directory_disk != 0
		or disk_entry_count != entry_count
	):
		raise ValueError("ai_kit.archive.multidisk_unsupported")
	if (
		entry_count == 0xFFFF
		or central_directory_size == 0xFFFFFFFF
		or central_directory_offset == 0xFFFFFFFF
	):
		raise ValueError("ai_kit.archive.zip64_unsupported")
	if entry_count > PLUGIN_ARCHIVE_ENTRY_LIMIT:
		raise ValueError("ai_kit.archive.entry_count_exceeded")
	if central_directory_size > PLUGIN_ARCHIVE_CENTRAL_DIRECTORY_BYTE_LIMIT:
		raise ValueError("ai_kit.archive.central_directory_budget_exceeded")
	absolute_eocd_offset = archive_size - tail_size + eocd_offset
	if central_directory_offset + central_directory_size != absolute_eocd_offset:
		raise ValueError("ai_kit.archive.layout_invalid")
	work_budget.consume_archive(
		entry_count,
		central_directory_size,
		work_limits,
	)
	_validate_canonical_plugin_archive_layout(
		payload,
		entry_count,
		central_directory_offset,
		central_directory_size,
		work_budget,
		work_limits,
	)
	return PluginArchivePreflight(
		entry_count=entry_count,
		central_directory_bytes=central_directory_size,
	)


def _validate_canonical_plugin_archive_layout(
	payload: bytes,
	entry_count: int,
	central_directory_offset: int,
	central_directory_size: int,
	work_budget: PluginWorkBudget,
	work_limits: PluginWorkLimits,
) -> None:
	central_directory_end = (
		central_directory_offset + central_directory_size
	)
	if (
		central_directory_offset < 0
		or central_directory_size < 0
		or central_directory_end > len(payload)
	):
		raise ValueError("ai_kit.archive.layout_invalid")
	work_budget.consume_io_bytes(central_directory_size, work_limits)
	cursor = central_directory_offset
	local_ranges: list[tuple[int, int]] = []
	for _index in range(entry_count):
		fixed_end = cursor + PLUGIN_ARCHIVE_CENTRAL_DIRECTORY_STRUCT.size
		if fixed_end > central_directory_end:
			raise ValueError("ai_kit.archive.layout_invalid")
		fields = PLUGIN_ARCHIVE_CENTRAL_DIRECTORY_STRUCT.unpack_from(
			payload,
			cursor,
		)
		(
			signature,
			_version_made_by,
			version_needed,
			flags,
			compression,
			modification_time,
			modification_date,
			crc32,
			compressed_size,
			uncompressed_size,
			name_size,
			extra_size,
			comment_size,
			disk_start,
			_internal_attributes,
			_external_attributes,
			local_header_offset,
		) = fields
		record_end = fixed_end + name_size + extra_size + comment_size
		if (
			signature != PLUGIN_ARCHIVE_CENTRAL_DIRECTORY_SIGNATURE
			or record_end > central_directory_end
			or extra_size != 0
			or comment_size != 0
			or disk_start != 0
			or flags & 0x08
		):
			raise ValueError("ai_kit.archive.layout_invalid")
		central_name = payload[fixed_end:fixed_end + name_size]
		local_fixed_end = (
			local_header_offset + PLUGIN_ARCHIVE_LOCAL_HEADER_STRUCT.size
		)
		if (
			local_header_offset < 0
			or local_fixed_end > central_directory_offset
		):
			raise ValueError("ai_kit.archive.layout_invalid")
		local_fields = PLUGIN_ARCHIVE_LOCAL_HEADER_STRUCT.unpack_from(
			payload,
			local_header_offset,
		)
		(
			local_signature,
			local_version_needed,
			local_flags,
			local_compression,
			local_modification_time,
			local_modification_date,
			local_crc32,
			local_compressed_size,
			local_uncompressed_size,
			local_name_size,
			local_extra_size,
		) = local_fields
		local_name_end = local_fixed_end + local_name_size
		local_record_end = (
			local_name_end + local_extra_size + compressed_size
		)
		if (
			local_signature != PLUGIN_ARCHIVE_LOCAL_HEADER_SIGNATURE
			or local_extra_size != 0
			or local_record_end > central_directory_offset
			or payload[local_fixed_end:local_name_end] != central_name
			or local_version_needed != version_needed
			or local_flags != flags
			or local_compression != compression
			or local_modification_time != modification_time
			or local_modification_date != modification_date
			or local_crc32 != crc32
			or local_compressed_size != compressed_size
			or local_uncompressed_size != uncompressed_size
		):
			raise ValueError("ai_kit.archive.layout_invalid")
		work_budget.consume_io_bytes(
			PLUGIN_ARCHIVE_LOCAL_HEADER_STRUCT.size
			+ local_name_size
			+ local_extra_size,
			work_limits,
		)
		local_ranges.append((local_header_offset, local_record_end))
		cursor = record_end
	if cursor != central_directory_end:
		raise ValueError("ai_kit.archive.layout_invalid")
	expected_offset = 0
	for range_start, range_end in sorted(local_ranges):
		if range_start != expected_offset or range_end < range_start:
			raise ValueError("ai_kit.archive.layout_invalid")
		expected_offset = range_end
	if expected_offset != central_directory_offset:
		raise ValueError("ai_kit.archive.layout_invalid")


def _normalized_plugin_archive_path(raw_path: str) -> str:
	if (
		not raw_path
		or len(raw_path) > 512
		or "\\" in raw_path
		or "\0" in raw_path
		or any(ord(character) < 32 or ord(character) == 127 for character in raw_path)
	):
		raise ValueError("ai_kit.archive.path_invalid")
	parts = raw_path.split("/")
	if any(part in {"", ".", ".."} or len(part) > 180 for part in parts):
		raise ValueError("ai_kit.archive.path_invalid")
	path = PurePosixPath(raw_path)
	if path.is_absolute() or not path.parts or ":" in path.parts[0]:
		raise ValueError("ai_kit.archive.path_invalid")
	resource_path = f"res://{raw_path}"
	if (
		normalize_portable_ownership_path(resource_path) != resource_path
		or unicodedata.normalize("NFC", raw_path) != raw_path
	):
		raise ValueError("ai_kit.archive.path_invalid")
	if any(part.casefold() in BLOCKED_PART_IDENTITIES for part in path.parts):
		raise ValueError("ai_kit.archive.path_blocked")
	if path.suffix.lower() in BLOCKED_SUFFIXES:
		raise ValueError("ai_kit.archive.path_blocked")
	return path.as_posix()


def _portable_plugin_archive_identity(raw_path: str) -> str:
	normalized_path = _normalized_plugin_archive_path(raw_path)
	resource_identity = portable_ownership_path_identity(
		f"res://{normalized_path}"
	)
	if not resource_identity:
		raise ValueError("ai_kit.archive.path_invalid")
	return resource_identity.removeprefix("res://")


def _read_bounded_plugin_archive_entry(
	archive: zipfile.ZipFile,
	entry: zipfile.ZipInfo,
	work_budget: PluginWorkBudget,
	work_limits: PluginWorkLimits,
) -> bytes:
	payload = bytearray()
	try:
		with archive.open(entry, "r") as stream:
			while True:
				chunk = stream.read(
					min(
						PLUGIN_ARCHIVE_READ_CHUNK_BYTES,
						PLUGIN_ARCHIVE_ENTRY_BYTE_LIMIT - len(payload) + 1,
					)
				)
				if not chunk:
					break
				work_budget.consume_io_bytes(len(chunk), work_limits)
				payload.extend(chunk)
				if (
					len(payload) > PLUGIN_ARCHIVE_ENTRY_BYTE_LIMIT
					or len(payload) > entry.file_size
				):
					raise ValueError("ai_kit.archive.entry_read_budget_exceeded")
	except ValueError:
		raise
	except (OSError, RuntimeError, zipfile.BadZipFile):
		raise ValueError("ai_kit.archive.entry_read_failed") from None
	if len(payload) != entry.file_size:
		raise ValueError("ai_kit.archive.entry_read_incomplete")
	return bytes(payload)


def _strict_json_object(payload: bytes) -> dict[str, Any]:
	if b"\0" in payload:
		raise ValueError("ai_kit.archive.json_invalid")
	try:
		value = json.loads(payload.decode("utf-8", errors="strict"))
	except (UnicodeDecodeError, json.JSONDecodeError):
		raise ValueError("ai_kit.archive.json_invalid") from None
	if not isinstance(value, dict):
		raise ValueError("ai_kit.archive.json_invalid")
	return value


def _stable_plugin_archive_rule_id(
	error: BaseException,
	fallback: str,
) -> str:
	rule_id = str(error)
	if (
		re.fullmatch(r"ai_kit\.(?:archive|work)\.[a-z0-9_.]+", rule_id)
		is None
	):
		return fallback
	return rule_id


def _budgeted_sha256(
	payload: bytes,
	work_budget: PluginWorkBudget,
	work_limits: PluginWorkLimits,
) -> str:
	work_budget.consume_io_bytes(len(payload), work_limits)
	return hashlib.sha256(payload).hexdigest()


def _budgeted_bytes_equal(
	first: bytes,
	second: bytes,
	work_budget: PluginWorkBudget,
	work_limits: PluginWorkLimits,
) -> bool:
	work_budget.consume_io_bytes(len(first) + len(second), work_limits)
	return first == second


def audit_plugin_archive(
	output: Path,
	expected_version: str = "",
	*,
	work_budget: PluginWorkBudget | None = None,
	work_limits: PluginWorkLimits | None = None,
) -> dict[str, Any]:
	active_work_budget = work_budget or PluginWorkBudget()
	active_work_limits = work_limits or PluginWorkLimits()
	issues: list[str] = []
	names: list[str] = []
	archive_sha256 = ""
	safe_version = ""
	if expected_version:
		if _parse_exact_semver(expected_version) is None:
			_append_plugin_archive_issue(
				issues,
				"ai_kit.archive.expected_version_invalid",
			)
		else:
			safe_version = expected_version

	def make_result() -> dict[str, Any]:
		return {
			"ok": not issues,
			"version": safe_version,
			"output": "plugin-archive",
			"file_count": len(names),
			"sha256": archive_sha256,
			"issues": issues,
		}

	if issues:
		return make_result()

	try:
		archive_payload = _read_owned_bytes(
			output,
			output.parent,
			PLUGIN_ARCHIVE_BYTE_LIMIT,
			require_nonempty=True,
			work_budget=active_work_budget,
			work_limits=active_work_limits,
		)
	except ValueError as error:
		rule_id = _stable_plugin_archive_rule_id(
			error,
			"ai_kit.archive.unavailable",
		)
		_append_plugin_archive_issue(issues, rule_id)
		return make_result()
	except OSError:
		_append_plugin_archive_issue(issues, "ai_kit.archive.unavailable")
		return make_result()

	try:
		archive_sha256 = _budgeted_sha256(
			archive_payload,
			active_work_budget,
			active_work_limits,
		)
		preflight = _preflight_plugin_archive(
			archive_payload,
			active_work_budget,
			active_work_limits,
		)
	except ValueError as error:
		_append_plugin_archive_issue(
			issues,
			_stable_plugin_archive_rule_id(
				error,
				"ai_kit.archive.invalid",
			),
		)
		return make_result()

	entry_by_name: dict[str, tuple[zipfile.ZipInfo, str]] = {}
	manifest_payload = b""
	mcp_payload = b""
	manifest: dict[str, Any] | None = None
	try:
		archive_stream = _BudgetedBinaryIO(
			io.BytesIO(archive_payload),
			active_work_budget,
			active_work_limits,
			logical_size=len(archive_payload),
		)
		with zipfile.ZipFile(archive_stream, "r") as archive:
			entries = archive.infolist()
			if len(entries) != preflight.entry_count:
				_append_plugin_archive_issue(
					issues,
					"ai_kit.archive.entry_count_mismatch",
				)
			expanded_bytes = 0
			seen_identities: set[str] = set()
			required_directory_identities: set[str] = set()
			for index, entry in enumerate(entries):
				label = f"archive-entry-{index + 1}"
				raw_name = str(
					getattr(entry, "orig_filename", entry.filename)
				)
				try:
					name = _normalized_plugin_archive_path(raw_name)
					identity = _portable_plugin_archive_identity(name)
				except ValueError as error:
					_append_plugin_archive_issue(
						issues,
						_stable_plugin_archive_rule_id(
							error,
							"ai_kit.archive.path_invalid",
						),
						label,
					)
					continue
				if identity in seen_identities:
					_append_plugin_archive_issue(
						issues,
						"ai_kit.archive.entry_duplicate",
						label,
					)
					continue
				path_conflict = identity in required_directory_identities
				parent_identity = ""
				for component in identity.split("/")[:-1]:
					parent_identity = (
						component
						if not parent_identity
						else f"{parent_identity}/{component}"
					)
					if parent_identity in seen_identities:
						path_conflict = True
					required_directory_identities.add(parent_identity)
				if path_conflict:
					_append_plugin_archive_issue(
						issues,
						"ai_kit.archive.path_prefix_conflict",
						label,
					)
					continue
				seen_identities.add(identity)
				names.append(name)
				if entry.is_dir():
					_append_plugin_archive_issue(
						issues,
						"ai_kit.archive.directory_entry_forbidden",
						label,
					)
					continue
				if entry.flag_bits & 0x1:
					_append_plugin_archive_issue(
						issues,
						"ai_kit.archive.encrypted_entry",
						label,
					)
				if (
					entry.compress_type
					not in PLUGIN_ARCHIVE_ALLOWED_COMPRESSION
				):
					_append_plugin_archive_issue(
						issues,
						"ai_kit.archive.compression_unsupported",
						label,
					)
				unix_mode = (entry.external_attr >> 16) & 0xFFFF
				file_type = stat.S_IFMT(unix_mode)
				if file_type not in {0, stat.S_IFREG}:
					_append_plugin_archive_issue(
						issues,
						"ai_kit.archive.special_entry",
						label,
					)
				if entry.file_size < 0 or entry.compress_size < 0:
					_append_plugin_archive_issue(
						issues,
						"ai_kit.archive.metadata_invalid",
						label,
					)
					continue
				if entry.file_size > PLUGIN_ARCHIVE_ENTRY_BYTE_LIMIT:
					_append_plugin_archive_issue(
						issues,
						"ai_kit.archive.entry_budget_exceeded",
						label,
					)
				expanded_bytes += entry.file_size
				if expanded_bytes > PLUGIN_ARCHIVE_EXPANDED_BYTE_LIMIT:
					_append_plugin_archive_issue(
						issues,
						"ai_kit.archive.expanded_budget_exceeded",
					)
					break
				try:
					active_work_budget.consume_expanded_bytes(
						entry.file_size,
						active_work_limits,
					)
				except ValueError as error:
					_append_plugin_archive_issue(
						issues,
						_stable_plugin_archive_rule_id(
							error,
							"ai_kit.archive.expanded_budget_exceeded",
						),
					)
					break
				if (
					entry.file_size
					>= PLUGIN_ARCHIVE_COMPRESSION_RATIO_MINIMUM_BYTES
					and entry.file_size / max(1, entry.compress_size)
					> PLUGIN_ARCHIVE_COMPRESSION_RATIO_LIMIT
				):
					_append_plugin_archive_issue(
						issues,
						"ai_kit.archive.compression_ratio_exceeded",
						label,
					)
				if entry.date_time != ZIP_TIMESTAMP:
					_append_plugin_archive_issue(
						issues,
						"ai_kit.archive.timestamp_invalid",
						label,
					)
				if (
					entry.create_system != 3
					or (entry.external_attr >> 16) & 0o777 != 0o644
				):
					_append_plugin_archive_issue(
						issues,
						"ai_kit.archive.permissions_invalid",
						label,
					)
				if entry.compress_type != zipfile.ZIP_DEFLATED:
					_append_plugin_archive_issue(
						issues,
						"ai_kit.archive.compression_invalid",
						label,
					)
				entry_by_name[name] = (entry, label)
			if names != sorted(names):
				_append_plugin_archive_issue(
					issues,
					"ai_kit.archive.order_invalid",
				)
			if issues:
				raise ValueError("ai_kit.archive.preflight_failed")

			required = {
				".codex-plugin/plugin.json",
				".mcp.json",
				"runtime/gf_ai_project.py",
				"runtime/gf_ai_mcp_server.py",
				"project_artifact_policy.json",
				"skills/gf-project-development/SKILL.md",
				"knowledge/api_index.json",
				"schemas/project_contract.schema.json",
				"schemas/editor_context_bundle.schema.json",
				"templates/adapters/storage/README.md",
				"templates/adapters/storage/storage_backend.gd.txt",
				(
					"templates/adapters/storage/"
					"storage_backend_conformance.gd.txt"
				),
				(
					"templates/adapters/storage/"
					"storage_backend_contract_test.gd.txt"
				),
				"templates/adapters/storage/storage_provider.gd.txt",
				(
					"templates/adapters/storage/"
					"storage_provider_factory.gd.txt"
				),
				(
					"templates/adapters/storage/"
					"storage_provider_fault_driver.gd.txt"
				),
				"templates/adapters/storage/storage_value_limits.gd.txt",
				"LICENSE.md",
			}
			if required - set(names):
				_append_plugin_archive_issue(
					issues,
					"ai_kit.archive.required_entry_missing",
					"expected-entry",
				)
				raise ValueError("ai_kit.archive.preflight_failed")

			manifest_entry, manifest_label = entry_by_name[
				".codex-plugin/plugin.json"
			]
			if not safe_version:
				manifest_payload = _read_bounded_plugin_archive_entry(
					archive,
					manifest_entry,
					active_work_budget,
					active_work_limits,
				)
				manifest = _strict_json_object(manifest_payload)
				manifest_version = str(manifest.get("version", ""))
				if _parse_exact_semver(manifest_version) is None:
					_append_plugin_archive_issue(
						issues,
						"ai_kit.archive.plugin_version_invalid",
						manifest_label,
					)
					raise ValueError("ai_kit.archive.preflight_failed")
			else:
				manifest_version = safe_version

			try:
				expected_entries = plugin_entries(
					manifest_version,
					work_budget=active_work_budget,
					work_limits=active_work_limits,
				)
			except ValueError as error:
				rule_id = _stable_plugin_archive_rule_id(
					error,
					"ai_kit.archive.semantic_invalid",
				)
				_append_plugin_archive_issue(issues, rule_id)
				raise ValueError("ai_kit.archive.preflight_failed") from None
			except (OSError, RuntimeError, UnicodeError):
				_append_plugin_archive_issue(
					issues,
					"ai_kit.archive.semantic_invalid",
				)
				raise ValueError("ai_kit.archive.preflight_failed") from None

			expected_names = set(expected_entries)
			if expected_names - set(names):
				_append_plugin_archive_issue(
					issues,
					"ai_kit.archive.expected_entry_missing",
					"expected-entry",
				)
			for extra_name in sorted(set(names) - expected_names):
				_extra_entry, extra_label = entry_by_name[extra_name]
				_append_plugin_archive_issue(
					issues,
					"ai_kit.archive.unexpected_entry",
					extra_label,
				)
			if issues:
				raise ValueError("ai_kit.archive.preflight_failed")

			for name in sorted(expected_entries):
				entry, label = entry_by_name[name]
				try:
					if (
						name == ".codex-plugin/plugin.json"
						and manifest_payload
					):
						payload = manifest_payload
					else:
						payload = _read_bounded_plugin_archive_entry(
							archive,
							entry,
							active_work_budget,
							active_work_limits,
						)
				except ValueError as error:
					_append_plugin_archive_issue(
						issues,
						_stable_plugin_archive_rule_id(
							error,
							"ai_kit.archive.entry_read_failed",
						),
						label,
					)
					break
				if not _budgeted_bytes_equal(
					payload,
					expected_entries[name],
					active_work_budget,
					active_work_limits,
				):
					_append_plugin_archive_issue(
						issues,
						"ai_kit.archive.content_mismatch",
						label,
					)
					break
				if name == ".codex-plugin/plugin.json":
					manifest_payload = payload
				elif name == ".mcp.json":
					mcp_payload = payload
	except ValueError as error:
		if str(error) != "ai_kit.archive.preflight_failed":
			_append_plugin_archive_issue(
				issues,
				_stable_plugin_archive_rule_id(
					error,
					"ai_kit.archive.invalid",
				),
			)
	except (OSError, RuntimeError, zipfile.BadZipFile):
		_append_plugin_archive_issue(issues, "ai_kit.archive.invalid")

	if not issues:
		try:
			if manifest is None:
				manifest = _strict_json_object(manifest_payload)
			if manifest.get("name") != PLUGIN_NAME:
				_append_plugin_archive_issue(
					issues,
					"ai_kit.archive.plugin_name_invalid",
				)
			if manifest.get("license") != "Apache-2.0":
				_append_plugin_archive_issue(
					issues,
					"ai_kit.archive.plugin_license_invalid",
				)
			if safe_version and manifest.get("version") != safe_version:
				_append_plugin_archive_issue(
					issues,
					"ai_kit.archive.plugin_version_mismatch",
				)
			manifest_version = str(manifest.get("version", ""))
			if _parse_exact_semver(manifest_version) is None:
				_append_plugin_archive_issue(
					issues,
					"ai_kit.archive.plugin_version_invalid",
				)
			mcp = _strict_json_object(mcp_payload)
			server = (
				mcp.get("mcpServers", {}).get("gf-project", {})
				if isinstance(mcp.get("mcpServers"), dict)
				else {}
			)
			if (
				not isinstance(server, dict)
				or server.get("args")
				!= ["./runtime/gf_ai_mcp_server.py"]
				or server.get("cwd") != "."
			):
				_append_plugin_archive_issue(
					issues,
					"ai_kit.archive.mcp_entry_invalid",
				)
		except (KeyError, OSError, RuntimeError, UnicodeError, ValueError):
			_append_plugin_archive_issue(
				issues,
				"ai_kit.archive.semantic_invalid",
			)
	return make_result()


def _representative_path(paths: list[str]) -> str:
	if not paths:
		return ""
	return sorted(paths, key=lambda path: ({".gd": 0, ".json": 1, ".py": 2}.get(Path(path).suffix.lower(), 3), path))[0]


def _summary(docs: ApiDocs, max_lines: int) -> str:
	return " ".join(line.strip() for line in docs.description[:max_lines] if line.strip())


def _first_tag(docs: ApiDocs, name: str) -> str:
	values = docs.tags.get(name, [])
	return values[0] if values else ""


def _member_kind(member: ApiMember) -> str:
	return {"property": "var", "method": "func"}.get(member.kind, member.kind)


def _blocked(path: Path) -> bool:
	return (
		any(
			part.casefold() in BLOCKED_PART_IDENTITIES
			for part in path.parts
		)
		or path.suffix.lower() in BLOCKED_SUFFIXES
	)


def _path_is_link_or_reparse(path: Path) -> bool:
	return _metadata_is_link_or_reparse(os.lstat(path))


def _metadata_is_link_or_reparse(metadata: os.stat_result) -> bool:
	reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
	file_attributes = getattr(metadata, "st_file_attributes", 0)
	return stat.S_ISLNK(metadata.st_mode) or bool(
		file_attributes & reparse_flag
	)


def _absolute_owned_path(path: Path, owner_root: Path) -> tuple[Path, Path]:
	absolute_root = Path(os.path.abspath(owner_root))
	absolute_path = Path(os.path.abspath(path))
	try:
		absolute_path.relative_to(absolute_root)
	except ValueError as exc:
		raise ValueError("GF AI Developer Kit source escapes its owned root.") from exc
	return absolute_path, absolute_root


def _snapshot_owned_directory_chain(
	owner_root: Path,
	directory: Path,
) -> tuple[tuple[Path, os.stat_result], ...]:
	absolute_directory, absolute_root = _absolute_owned_path(
		directory,
		owner_root,
	)
	relative = absolute_directory.relative_to(absolute_root)
	current = absolute_root
	components = [current]
	for component in relative.parts:
		current = current / component
		components.append(current)
	snapshot: list[tuple[Path, os.stat_result]] = []
	for component in components:
		try:
			component_stat = os.lstat(component)
		except OSError as exc:
			raise ValueError("Owned directory chain is unavailable.") from exc
		if (
			_metadata_is_link_or_reparse(component_stat)
			or not stat.S_ISDIR(component_stat.st_mode)
		):
			raise ValueError("Owned directory chain crosses a link or reparse point.")
		snapshot.append((component, component_stat))
	return tuple(snapshot)


def _same_directory_identity(
	before: os.stat_result,
	after: os.stat_result,
) -> bool:
	try:
		same_stat = os.path.samestat(before, after)
	except (AttributeError, OSError):
		same_stat = (
			before.st_dev == after.st_dev
			and before.st_ino == after.st_ino
		)
	return (
		same_stat
		and stat.S_IFMT(before.st_mode) == stat.S_IFMT(after.st_mode)
		and not _metadata_is_link_or_reparse(before)
		and not _metadata_is_link_or_reparse(after)
	)


def _same_directory_chain_identity(
	before: tuple[tuple[Path, os.stat_result], ...],
	after: tuple[tuple[Path, os.stat_result], ...],
) -> bool:
	return (
		len(before) == len(after)
		and all(
			before_path == after_path
			and _same_directory_identity(before_stat, after_stat)
			for (before_path, before_stat), (after_path, after_stat)
			in zip(before, after, strict=True)
		)
	)


def _assert_owned_path(
	path: Path,
	owner_root: Path,
	*,
	require_file: bool = False,
	require_directory: bool = False,
) -> tuple[Path, os.stat_result]:
	absolute_path, absolute_root = _absolute_owned_path(path, owner_root)
	if absolute_path == absolute_root:
		try:
			final_stat = os.lstat(absolute_path)
		except OSError as exc:
			raise ValueError("Owned source is unavailable.") from exc
		if _metadata_is_link_or_reparse(final_stat):
			raise ValueError("Owned source crosses a link or reparse point.")
	else:
		_snapshot_owned_directory_chain(absolute_root, absolute_path.parent)
		try:
			final_stat = os.lstat(absolute_path)
		except OSError as exc:
			raise ValueError("Owned source is unavailable.") from exc
		if _metadata_is_link_or_reparse(final_stat):
			raise ValueError("Owned source crosses a link or reparse point.")
	if require_file and not stat.S_ISREG(final_stat.st_mode):
		raise ValueError("Owned source is not a regular file.")
	if require_directory and not stat.S_ISDIR(final_stat.st_mode):
		raise ValueError("Owned source is not a directory.")
	if require_directory:
		_snapshot_owned_directory_chain(absolute_root, absolute_path)
	return absolute_path, final_stat


def _same_file_identity(
	before: os.stat_result,
	after: os.stat_result,
) -> bool:
	try:
		same_stat = os.path.samestat(before, after)
	except (AttributeError, OSError):
		same_stat = (
			before.st_dev == after.st_dev
			and before.st_ino == after.st_ino
		)
	return (
		same_stat
		and before.st_mode == after.st_mode
		and before.st_size == after.st_size
		and before.st_mtime_ns == after.st_mtime_ns
		and not _metadata_is_link_or_reparse(before)
		and not _metadata_is_link_or_reparse(after)
	)


def _same_regular_object_identity(
	before: os.stat_result,
	after: os.stat_result,
) -> bool:
	try:
		same_stat = os.path.samestat(before, after)
	except (AttributeError, OSError):
		same_stat = (
			before.st_dev == after.st_dev
			and before.st_ino == after.st_ino
		)
	return (
		same_stat
		and stat.S_ISREG(before.st_mode)
		and stat.S_ISREG(after.st_mode)
		and stat.S_IFMT(before.st_mode) == stat.S_IFMT(after.st_mode)
		and not _metadata_is_link_or_reparse(before)
		and not _metadata_is_link_or_reparse(after)
	)


def _owned_read_flags() -> int:
	return (
		os.O_RDONLY
		| int(getattr(os, "O_BINARY", 0))
		| int(getattr(os, "O_CLOEXEC", 0))
		| int(getattr(os, "O_NOFOLLOW", 0))
	)


def _owned_write_flags() -> int:
	return (
		os.O_WRONLY
		| os.O_CREAT
		| os.O_EXCL
		| int(getattr(os, "O_BINARY", 0))
		| int(getattr(os, "O_CLOEXEC", 0))
		| int(getattr(os, "O_NOFOLLOW", 0))
	)


def _write_all_file_descriptor(
	file_descriptor: int,
	payload: bytes,
) -> None:
	offset = 0
	payload_view = memoryview(payload)
	while offset < len(payload):
		written = os.write(file_descriptor, payload_view[offset:])
		if written <= 0:
			raise OSError("Owned target write did not make progress.")
		offset += written


def _supports_secure_directory_descriptors() -> bool:
	return (
		hasattr(os, "supports_dir_fd")
		and os.open in os.supports_dir_fd
		and os.mkdir in os.supports_dir_fd
		and hasattr(os, "O_DIRECTORY")
	)


def _snapshot_absolute_directory_chain(
	directory: Path,
) -> tuple[tuple[Path, os.stat_result], ...]:
	absolute_directory = Path(os.path.abspath(directory))
	components: list[Path] = []
	current = absolute_directory
	while True:
		components.append(current)
		if current == current.parent:
			break
		current = current.parent
	snapshot: list[tuple[Path, os.stat_result]] = []
	for component in reversed(components):
		try:
			metadata = os.lstat(component)
		except OSError as exc:
			raise ValueError("Private owned-root chain is unavailable.") from exc
		if (
			not stat.S_ISDIR(metadata.st_mode)
			or _metadata_is_link_or_reparse(metadata)
		):
			raise ValueError(
				"Private owned-root chain crosses a link or reparse point."
			)
		snapshot.append((component, metadata))
	return tuple(snapshot)


@dataclass(frozen=True)
class _OwnedTargetBinding:
	path: Path
	file_descriptor: int
	opened_metadata: os.stat_result
	parent_descriptor: int = -1
	leaf_name: str = ""


class _OwnedRootBinding:
	"""Pin an existing root and create targets only below pinned parents."""

	def __init__(self, root: Path) -> None:
		self.root = Path(os.path.abspath(root))
		self._closed = False
		self._root_chain = _snapshot_absolute_directory_chain(self.root)
		self._posix_directories: dict[tuple[str, ...], int] = {}
		self._windows_directories: dict[str, int] = {}
		if os.name == "nt":
			self._initialize_windows()
		elif _supports_secure_directory_descriptors():
			self._initialize_posix()
		else:
			raise ValueError(
				"Secure owned-root binding is unavailable on this platform."
			)

	def __enter__(self) -> _OwnedRootBinding:
		return self

	def __exit__(
		self,
		_exc_type: type[BaseException] | None,
		_exc: BaseException | None,
		_traceback: Any,
	) -> None:
		self.close()

	def close(self) -> None:
		if self._closed:
			return
		self._closed = True
		for _key, descriptor in sorted(
			self._posix_directories.items(),
			key=lambda item: len(item[0]),
			reverse=True,
		):
			try:
				os.close(descriptor)
			except OSError:
				pass
		self._posix_directories.clear()
		for _path, handle in reversed(
			tuple(self._windows_directories.items())
		):
			_windows_close_handle(handle)
		self._windows_directories.clear()

	def verify(self) -> None:
		if self._closed:
			raise ValueError("Owned-root binding is closed.")
		if not _same_directory_chain_identity(
			self._root_chain,
			_snapshot_absolute_directory_chain(self.root),
		):
			raise ValueError("Owned-root identity changed.")
		if os.name == "nt":
			self._verify_windows_directories()
			return
		self._verify_posix_directories()

	def ensure_directory(self, directory: Path) -> Path:
		absolute_directory, _absolute_root = _absolute_owned_path(
			directory,
			self.root,
		)
		if os.name == "nt":
			self._ensure_windows_directory(absolute_directory)
		else:
			self._ensure_posix_directory(
				tuple(
					absolute_directory.relative_to(self.root).parts
				)
			)
			self.verify()
		return absolute_directory

	def create_target(self, path: Path) -> _OwnedTargetBinding:
		if self._closed:
			raise ValueError("Owned-root binding is closed.")
		absolute_path, _absolute_root = _absolute_owned_path(
			path,
			self.root,
		)
		if absolute_path == self.root or not absolute_path.name:
			raise ValueError("Owned target must be below its owner root.")
		if os.name == "nt":
			return self._create_windows_target(absolute_path)
		return self._create_posix_target(absolute_path)

	def verify_target(
		self,
		target: _OwnedTargetBinding,
		opened_after: os.stat_result,
	) -> None:
		if not _same_regular_object_identity(
			target.opened_metadata,
			opened_after,
		):
			raise ValueError("Owned target identity changed while it was written.")
		if os.name == "nt":
			self._verify_windows_directories()
			try:
				import msvcrt

				raw_handle = int(
					msvcrt.get_osfhandle(target.file_descriptor)
				)
				path_after = os.lstat(target.path)
			except (OSError, ValueError):
				raise ValueError(
					"Owned target identity changed while it was written."
				) from None
			if not _windows_handle_matches_path(
				raw_handle,
				target.path,
				expect_directory=False,
			):
				raise ValueError(
					"Owned target identity changed while it was written."
				)
		else:
			try:
				path_after = os.stat(
					target.leaf_name,
					dir_fd=target.parent_descriptor,
					follow_symlinks=False,
				)
			except OSError:
				raise ValueError(
					"Owned target identity changed while it was written."
				) from None
		if not _same_regular_object_identity(opened_after, path_after):
			raise ValueError("Owned target identity changed while it was written.")
		self.verify()

	def publish_target(
		self,
		source: _OwnedTargetBinding,
		target_path: Path,
		expected_metadata: os.stat_result,
	) -> None:
		absolute_source, _absolute_root = _absolute_owned_path(
			source.path,
			self.root,
		)
		absolute_target, _absolute_target_root = _absolute_owned_path(
			target_path,
			self.root,
		)
		if absolute_source == absolute_target:
			raise ValueError("Owned publication source and target must differ.")
		source_opened = os.fstat(source.file_descriptor)
		if not _same_regular_object_identity(
			expected_metadata,
			source_opened,
		):
			raise ValueError(
				"Owned publication source identity changed."
			)
		self.verify()
		# The atomic rename below is the publication commit point. A later
		# durability or identity check can still fail after the target changed,
		# so callers must treat such an exception as an ambiguous commit result.
		if os.name == "nt":
			target_parent_handle = self._ensure_windows_directory(
				absolute_target.parent
			)
			try:
				import msvcrt

				raw_handle = int(
					msvcrt.get_osfhandle(source.file_descriptor)
				)
			except (OSError, ValueError):
				raise ValueError(
					"Owned publication source identity changed."
				) from None
			_windows_replace_open_file(
				raw_handle,
				target_parent_handle,
				absolute_target.name,
			)
			target_after = os.lstat(absolute_target)
			if not _windows_handle_matches_path(
				raw_handle,
				absolute_target,
				expect_directory=False,
			):
				raise ValueError(
					"Owned publication target identity changed."
				)
		else:
			source_parent = source.parent_descriptor
			target_parent = self._ensure_posix_directory(
				tuple(
					absolute_target.parent.relative_to(self.root).parts
				)
			)
			source_before = os.stat(
				source.leaf_name,
				dir_fd=source_parent,
				follow_symlinks=False,
			)
			if not _same_regular_object_identity(
				expected_metadata,
				source_before,
			):
				raise ValueError(
					"Owned publication source identity changed."
				)
			os.replace(
				source.leaf_name,
				absolute_target.name,
				src_dir_fd=source_parent,
				dst_dir_fd=target_parent,
			)
			target_after = os.stat(
				absolute_target.name,
				dir_fd=target_parent,
				follow_symlinks=False,
			)
			try:
				os.fsync(target_parent)
			except OSError:
				pass
		if not _same_regular_object_identity(
			expected_metadata,
			target_after,
		):
			raise ValueError("Owned publication target identity changed.")
		self.verify()

	def unlink_target_if_identity(
		self,
		path: Path,
		expected_metadata: os.stat_result,
	) -> None:
		absolute_path, _absolute_root = _absolute_owned_path(
			path,
			self.root,
		)
		try:
			if os.name == "nt":
				path_metadata = os.lstat(absolute_path)
				if not _same_regular_object_identity(
					expected_metadata,
					path_metadata,
				):
					return
				os.unlink(absolute_path)
			else:
				parent_descriptor = self._ensure_posix_directory(
					tuple(
						absolute_path.parent.relative_to(self.root).parts
					)
				)
				path_metadata = os.stat(
					absolute_path.name,
					dir_fd=parent_descriptor,
					follow_symlinks=False,
				)
				if not _same_regular_object_identity(
					expected_metadata,
					path_metadata,
				):
					return
				os.unlink(
					absolute_path.name,
					dir_fd=parent_descriptor,
				)
		except FileNotFoundError:
			return

	def _initialize_posix(self) -> None:
		try:
			before = os.lstat(self.root)
			descriptor = os.open(
				self.root,
				_owned_directory_open_flags(),
			)
			opened = os.fstat(descriptor)
		except OSError:
			raise ValueError("Owned-root binding is unavailable.") from None
		if (
			not stat.S_ISDIR(opened.st_mode)
			or not _same_directory_identity(before, opened)
		):
			os.close(descriptor)
			raise ValueError("Owned-root identity changed.")
		self._posix_directories[()] = descriptor

	def _ensure_posix_directory(
		self,
		parts: tuple[str, ...],
	) -> int:
		current_key: tuple[str, ...] = ()
		for component in parts:
			next_key = (*current_key, component)
			if next_key in self._posix_directories:
				current_key = next_key
				continue
			parent_descriptor = self._posix_directories[current_key]
			try:
				descriptor = os.open(
					component,
					_owned_directory_open_flags(),
					dir_fd=parent_descriptor,
				)
			except FileNotFoundError:
				try:
					os.mkdir(
						component,
						0o700,
						dir_fd=parent_descriptor,
					)
					descriptor = os.open(
						component,
						_owned_directory_open_flags(),
						dir_fd=parent_descriptor,
					)
				except OSError:
					raise ValueError(
						"Owned target directory could not be created."
					) from None
			except OSError:
				raise ValueError(
					"Owned target directory is unavailable."
				) from None
			try:
				opened = os.fstat(descriptor)
				path_metadata = os.stat(
					component,
					dir_fd=parent_descriptor,
					follow_symlinks=False,
				)
			except OSError:
				os.close(descriptor)
				raise ValueError(
					"Owned target directory is unavailable."
				) from None
			if (
				not stat.S_ISDIR(opened.st_mode)
				or not _same_directory_identity(opened, path_metadata)
			):
				os.close(descriptor)
				raise ValueError(
					"Owned target directory crosses a link or reparse point."
				)
			self._posix_directories[next_key] = descriptor
			current_key = next_key
		return self._posix_directories[current_key]

	def _create_posix_target(self, path: Path) -> _OwnedTargetBinding:
		relative = path.relative_to(self.root)
		parent_descriptor = self._ensure_posix_directory(
			tuple(relative.parts[:-1])
		)
		leaf_name = relative.parts[-1]
		flags = (
			os.O_RDWR
			| os.O_CREAT
			| os.O_EXCL
			| int(getattr(os, "O_BINARY", 0))
			| int(getattr(os, "O_CLOEXEC", 0))
			| int(getattr(os, "O_NOFOLLOW", 0))
		)
		try:
			descriptor = os.open(
				leaf_name,
				flags,
				0o600,
				dir_fd=parent_descriptor,
			)
			opened = os.fstat(descriptor)
			path_metadata = os.stat(
				leaf_name,
				dir_fd=parent_descriptor,
				follow_symlinks=False,
			)
		except OSError:
			if "descriptor" in locals():
				os.close(descriptor)
			raise
		if (
			not stat.S_ISREG(opened.st_mode)
			or not _same_regular_object_identity(opened, path_metadata)
		):
			os.close(descriptor)
			raise ValueError("Owned target is not a regular file.")
		return _OwnedTargetBinding(
			path=path,
			file_descriptor=descriptor,
			opened_metadata=opened,
			parent_descriptor=parent_descriptor,
			leaf_name=leaf_name,
		)

	def _verify_posix_directories(self) -> None:
		root_descriptor = self._posix_directories.get(())
		if root_descriptor is None:
			raise ValueError("Owned-root binding is unavailable.")
		for key, descriptor in sorted(
			self._posix_directories.items(),
			key=lambda item: len(item[0]),
		):
			try:
				opened = os.fstat(descriptor)
				if not key:
					path_metadata = self._root_chain[-1][1]
				else:
					parent_descriptor = self._posix_directories[
						key[:-1]
					]
					path_metadata = os.stat(
						key[-1],
						dir_fd=parent_descriptor,
						follow_symlinks=False,
					)
			except (KeyError, OSError):
				raise ValueError(
					"Owned target directory identity changed."
				) from None
			if not _same_directory_identity(opened, path_metadata):
				raise ValueError(
					"Owned target directory identity changed."
				)

	def _initialize_windows(self) -> None:
		try:
			for directory in _full_directory_paths(self.root):
				handle, identity = _windows_open_pinned_directory(
					directory
				)
				self._windows_directories[
					_windows_path_key(directory)
				] = handle
				if int(identity.st_ino) != _windows_handle_file_index(
					handle
				):
					raise ValueError("Owned-root identity changed.")
		except Exception:
			self.close()
			raise

	def _ensure_windows_directory(self, directory: Path) -> int:
		absolute_directory, _absolute_root = _absolute_owned_path(
			directory,
			self.root,
		)
		self._verify_windows_directories()
		current = self.root
		for component in absolute_directory.relative_to(self.root).parts:
			current = current / component
			key = _windows_path_key(current)
			if key in self._windows_directories:
				continue
			try:
				os.mkdir(current, 0o700)
			except FileExistsError:
				pass
			except OSError:
				raise ValueError(
					"Owned target directory could not be created."
				) from None
			handle, _identity = _windows_open_pinned_directory(current)
			self._windows_directories[key] = handle
		self._verify_windows_directories()
		directory_key = _windows_path_key(absolute_directory)
		try:
			return self._windows_directories[directory_key]
		except KeyError:
			raise ValueError(
				"Owned target directory is unavailable."
			) from None

	def _create_windows_target(self, path: Path) -> _OwnedTargetBinding:
		parent_handle = self._ensure_windows_directory(path.parent)
		handle = _windows_create_pinned_file(
			parent_handle,
			path.name,
			path,
		)
		try:
			import msvcrt

			descriptor = msvcrt.open_osfhandle(
				handle,
				os.O_RDWR | int(getattr(os, "O_BINARY", 0)),
			)
			handle = -1
			opened = os.fstat(descriptor)
		except (OSError, ValueError):
			if handle >= 0:
				_windows_close_handle(handle)
			raise ValueError("Owned target could not be created.") from None
		if (
			not stat.S_ISREG(opened.st_mode)
			or _metadata_is_link_or_reparse(opened)
		):
			os.close(descriptor)
			raise ValueError("Owned target is not a regular file.")
		return _OwnedTargetBinding(
			path=path,
			file_descriptor=descriptor,
			opened_metadata=opened,
		)

	def _verify_windows_directories(self) -> None:
		for raw_path, handle in self._windows_directories.items():
			if not _windows_handle_matches_path(
				handle,
				Path(raw_path),
				expect_directory=True,
			):
				raise ValueError("Owned target directory identity changed.")


def _full_directory_paths(directory: Path) -> tuple[Path, ...]:
	absolute_directory = Path(os.path.abspath(directory))
	if not absolute_directory.anchor:
		raise ValueError("Owned-root binding requires an absolute path.")
	current = Path(absolute_directory.anchor)
	result = [current]
	for component in absolute_directory.relative_to(current).parts:
		current = current / component
		result.append(current)
	return tuple(result)


def _windows_path_key(path: Path) -> str:
	return os.path.normcase(os.path.normpath(str(path)))


def _windows_open_pinned_directory(
	path: Path,
) -> tuple[int, os.stat_result]:
	if os.name != "nt":
		raise ValueError("Windows directory binding is unavailable.")
	try:
		before = os.lstat(path)
	except OSError:
		raise ValueError("Owned target directory is unavailable.") from None
	if (
		not stat.S_ISDIR(before.st_mode)
		or _metadata_is_link_or_reparse(before)
	):
		raise ValueError(
			"Owned target directory crosses a link or reparse point."
		)
	handle = _windows_create_file_handle(
		path,
		desired_access=0x00000080,
		share_mode=0x00000001 | 0x00000002,
		creation_disposition=3,
		flags_and_attributes=0x02000000 | 0x00200000,
	)
	if handle < 0:
		raise ValueError("Owned target directory is unavailable.")
	try:
		after = os.lstat(path)
	except OSError:
		_windows_close_handle(handle)
		raise ValueError("Owned target directory is unavailable.") from None
	if (
		not _same_directory_identity(before, after)
		or not _windows_handle_matches_path(
			handle,
			path,
			expect_directory=True,
		)
		or int(after.st_ino) != _windows_handle_file_index(handle)
	):
		_windows_close_handle(handle)
		raise ValueError("Owned target directory identity changed.")
	return handle, after


def _windows_create_pinned_file(
	parent_handle: int,
	leaf_name: str,
	expected_path: Path,
) -> int:
	if (
		os.name != "nt"
		or parent_handle < 0
		or not leaf_name
		or leaf_name in {".", ".."}
		or any(character in leaf_name for character in ("/", "\\", ":", "\0"))
	):
		raise ValueError("Owned target boundary is invalid.")

	import ctypes
	from ctypes import wintypes

	class UnicodeString(ctypes.Structure):
		_fields_ = [
			("Length", wintypes.USHORT),
			("MaximumLength", wintypes.USHORT),
			("Buffer", wintypes.LPWSTR),
		]

	class ObjectAttributes(ctypes.Structure):
		_fields_ = [
			("Length", wintypes.ULONG),
			("RootDirectory", wintypes.HANDLE),
			("ObjectName", ctypes.POINTER(UnicodeString)),
			("Attributes", wintypes.ULONG),
			("SecurityDescriptor", wintypes.LPVOID),
			("SecurityQualityOfService", wintypes.LPVOID),
		]

	class IoStatusBlock(ctypes.Structure):
		_fields_ = [
			("Status", wintypes.LPVOID),
			("Information", ctypes.c_size_t),
		]

	encoded_name = leaf_name.encode("utf-16-le")
	if len(encoded_name) > 65_532:
		raise ValueError("Owned target boundary is invalid.")
	name_buffer = ctypes.create_unicode_buffer(leaf_name)
	unicode_name = UnicodeString(
		Length=len(encoded_name),
		MaximumLength=len(encoded_name) + 2,
		Buffer=ctypes.cast(name_buffer, wintypes.LPWSTR),
	)
	attributes = ObjectAttributes(
		Length=ctypes.sizeof(ObjectAttributes),
		RootDirectory=wintypes.HANDLE(parent_handle),
		ObjectName=ctypes.pointer(unicode_name),
		Attributes=0x00000040,
		SecurityDescriptor=None,
		SecurityQualityOfService=None,
	)
	io_status = IoStatusBlock()
	file_handle = wintypes.HANDLE()
	ntdll = ctypes.WinDLL("ntdll")
	ntdll.NtCreateFile.argtypes = [
		ctypes.POINTER(wintypes.HANDLE),
		wintypes.DWORD,
		ctypes.POINTER(ObjectAttributes),
		ctypes.POINTER(IoStatusBlock),
		wintypes.LPVOID,
		wintypes.DWORD,
		wintypes.DWORD,
		wintypes.DWORD,
		wintypes.DWORD,
		wintypes.LPVOID,
		wintypes.DWORD,
	]
	ntdll.NtCreateFile.restype = wintypes.LONG
	status_code = ntdll.NtCreateFile(
		ctypes.byref(file_handle),
		(
			0x80000000
			| 0x40000000
			| 0x00010000
			| 0x00000080
			| 0x00100000
		),
		ctypes.byref(attributes),
		ctypes.byref(io_status),
		None,
		0x00000080,
		0x00000001,
		2,
		0x00000040 | 0x00000020 | 0x00200000,
		None,
		0,
	)
	handle = int(file_handle.value or -1)
	if status_code < 0 or handle < 0:
		if handle >= 0:
			_windows_close_handle(handle)
		if os.path.lexists(expected_path):
			raise FileExistsError(
				"Owned target file must not already exist."
			)
		raise ValueError("Owned target could not be created.")
	if not _windows_handle_matches_path(
		handle,
		expected_path,
		expect_directory=False,
	):
		_windows_close_handle(handle)
		raise ValueError("Owned target boundary is invalid.")
	return handle


def _windows_create_file_handle(
	path: Path,
	*,
	desired_access: int,
	share_mode: int,
	creation_disposition: int,
	flags_and_attributes: int,
) -> int:
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
		str(Path(os.path.abspath(path))),
		desired_access,
		share_mode,
		None,
		creation_disposition,
		flags_and_attributes,
		None,
	)
	invalid_handle = int(ctypes.c_void_p(-1).value or -1)
	if handle is None or int(handle) == invalid_handle:
		return -1
	return int(handle)


def _windows_replace_open_file(
	file_handle: int,
	target_parent_handle: int,
	target_leaf_name: str,
) -> None:
	if (
		os.name != "nt"
		or file_handle < 0
		or target_parent_handle < 0
		or not target_leaf_name
		or target_leaf_name in {".", ".."}
		or any(
			character in target_leaf_name
			for character in ("/", "\\", ":", "\0")
		)
	):
		raise ValueError("Owned publication target boundary is invalid.")

	import ctypes
	from ctypes import wintypes

	class FileRenameInfoHeader(ctypes.Structure):
		_fields_ = [
			("ReplaceIfExists", wintypes.BOOLEAN),
			("RootDirectory", wintypes.HANDLE),
			("FileNameLength", wintypes.DWORD),
			("FileName", wintypes.WCHAR * 1),
		]

	class IoStatusBlock(ctypes.Structure):
		_fields_ = [
			("Status", wintypes.LPVOID),
			("Information", ctypes.c_size_t),
		]

	encoded_name = target_leaf_name.encode("utf-16-le")
	if not encoded_name or len(encoded_name) > 65_532:
		raise ValueError("Owned publication target boundary is invalid.")
	name_offset = FileRenameInfoHeader.FileName.offset
	buffer = ctypes.create_string_buffer(
		ctypes.sizeof(FileRenameInfoHeader) + len(encoded_name)
	)
	header = ctypes.cast(
		buffer,
		ctypes.POINTER(FileRenameInfoHeader),
	).contents
	header.ReplaceIfExists = 1
	header.RootDirectory = wintypes.HANDLE(target_parent_handle)
	header.FileNameLength = len(encoded_name)
	ctypes.memmove(
		ctypes.addressof(buffer) + name_offset,
		encoded_name,
		len(encoded_name),
	)
	io_status = IoStatusBlock()
	ntdll = ctypes.WinDLL("ntdll")
	ntdll.NtSetInformationFile.argtypes = [
		wintypes.HANDLE,
		ctypes.POINTER(IoStatusBlock),
		wintypes.LPVOID,
		wintypes.DWORD,
		ctypes.c_int,
	]
	ntdll.NtSetInformationFile.restype = wintypes.LONG
	status_code = ntdll.NtSetInformationFile(
		wintypes.HANDLE(file_handle),
		ctypes.byref(io_status),
		ctypes.byref(buffer),
		len(buffer),
		10,
	)
	if status_code < 0:
		raise OSError(
			int(status_code),
			"Owned publication rename failed.",
		)


def _windows_handle_file_index(handle: int) -> int:
	import ctypes
	from ctypes import wintypes

	class FileInformation(ctypes.Structure):
		_fields_ = [
			("dwFileAttributes", wintypes.DWORD),
			("ftCreationTime", wintypes.FILETIME),
			("ftLastAccessTime", wintypes.FILETIME),
			("ftLastWriteTime", wintypes.FILETIME),
			("dwVolumeSerialNumber", wintypes.DWORD),
			("nFileSizeHigh", wintypes.DWORD),
			("nFileSizeLow", wintypes.DWORD),
			("nNumberOfLinks", wintypes.DWORD),
			("nFileIndexHigh", wintypes.DWORD),
			("nFileIndexLow", wintypes.DWORD),
		]

	kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
	kernel32.GetFileInformationByHandle.argtypes = [
		wintypes.HANDLE,
		ctypes.POINTER(FileInformation),
	]
	kernel32.GetFileInformationByHandle.restype = wintypes.BOOL
	information = FileInformation()
	if not kernel32.GetFileInformationByHandle(
		wintypes.HANDLE(handle),
		ctypes.byref(information),
	):
		return -1
	return (
		int(information.nFileIndexHigh) << 32
	) | int(information.nFileIndexLow)


def _windows_handle_matches_path(
	handle: int,
	path: Path,
	*,
	expect_directory: bool,
) -> bool:
	import ctypes
	from ctypes import wintypes

	class FileInformation(ctypes.Structure):
		_fields_ = [
			("dwFileAttributes", wintypes.DWORD),
			("ftCreationTime", wintypes.FILETIME),
			("ftLastAccessTime", wintypes.FILETIME),
			("ftLastWriteTime", wintypes.FILETIME),
			("dwVolumeSerialNumber", wintypes.DWORD),
			("nFileSizeHigh", wintypes.DWORD),
			("nFileSizeLow", wintypes.DWORD),
			("nNumberOfLinks", wintypes.DWORD),
			("nFileIndexHigh", wintypes.DWORD),
			("nFileIndexLow", wintypes.DWORD),
		]

	kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
	kernel32.GetFileInformationByHandle.argtypes = [
		wintypes.HANDLE,
		ctypes.POINTER(FileInformation),
	]
	kernel32.GetFileInformationByHandle.restype = wintypes.BOOL
	kernel32.GetFinalPathNameByHandleW.argtypes = [
		wintypes.HANDLE,
		wintypes.LPWSTR,
		wintypes.DWORD,
		wintypes.DWORD,
	]
	kernel32.GetFinalPathNameByHandleW.restype = wintypes.DWORD
	information = FileInformation()
	if not kernel32.GetFileInformationByHandle(
		wintypes.HANDLE(handle),
		ctypes.byref(information),
	):
		return False
	is_directory = bool(int(information.dwFileAttributes) & 0x00000010)
	is_reparse = bool(int(information.dwFileAttributes) & 0x00000400)
	if is_reparse or is_directory != expect_directory:
		return False
	buffer = ctypes.create_unicode_buffer(32_768)
	length = kernel32.GetFinalPathNameByHandleW(
		wintypes.HANDLE(handle),
		buffer,
		len(buffer),
		0,
	)
	if length <= 0 or length >= len(buffer):
		return False
	final_path = buffer.value
	if final_path.startswith("\\\\?\\UNC\\"):
		final_path = "\\\\" + final_path[8:]
	elif final_path.startswith("\\\\?\\"):
		final_path = final_path[4:]
	return _windows_path_key(Path(final_path)) == _windows_path_key(path)


def _windows_close_handle(handle: int) -> None:
	if os.name != "nt" or handle < 0:
		return
	import ctypes
	from ctypes import wintypes

	kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
	kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
	kernel32.CloseHandle.restype = wintypes.BOOL
	kernel32.CloseHandle(wintypes.HANDLE(handle))


@contextmanager
def _private_owned_root(root: Path) -> Iterator[Path]:
	"""Pin and register one process-created private target root."""
	absolute_root, _root_stat = _assert_owned_path(
		root,
		root,
		require_directory=True,
	)
	if absolute_root in _PRIVATE_OWNED_ROOTS:
		raise ValueError("Private owned root is already registered.")
	binding = _OwnedRootBinding(absolute_root)
	_PRIVATE_OWNED_ROOTS[absolute_root] = binding
	try:
		yield absolute_root
	finally:
		_PRIVATE_OWNED_ROOTS.pop(absolute_root, None)
		binding.close()


def _registered_owned_binding_for(
	path: Path,
) -> _OwnedRootBinding | None:
	absolute_path = Path(os.path.abspath(path))
	candidates: list[Path] = []
	for private_root in _PRIVATE_OWNED_ROOTS:
		try:
			absolute_path.relative_to(private_root)
		except ValueError:
			continue
		candidates.append(private_root)
	if not candidates:
		return None
	private_root = max(candidates, key=lambda item: len(item.parts))
	binding = _PRIVATE_OWNED_ROOTS[private_root]
	if not isinstance(binding, _OwnedRootBinding):
		raise ValueError("Private owned-root binding is invalid.")
	binding.verify()
	return binding


def _validated_private_root_for(path: Path) -> _OwnedRootBinding:
	binding = _registered_owned_binding_for(path)
	if binding is None:
		raise ValueError(
			"Owned target creation requires a process-created private root "
			"on this platform."
		)
	return binding


def _owned_directory_open_flags() -> int:
	return (
		os.O_RDONLY
		| int(getattr(os, "O_DIRECTORY", 0))
		| int(getattr(os, "O_CLOEXEC", 0))
		| int(getattr(os, "O_NOFOLLOW", 0))
		| int(getattr(os, "O_BINARY", 0))
	)


@contextmanager
def _open_owned_directory_descriptor(
	owner_root: Path,
	directory: Path,
	*,
	create: bool,
) -> Iterator[int]:
	if not _supports_secure_directory_descriptors():
		raise ValueError("Secure directory-relative creation is unavailable.")
	absolute_directory, absolute_root = _absolute_owned_path(
		directory,
		owner_root,
	)
	absolute_root, root_before = _assert_owned_path(
		absolute_root,
		absolute_root,
		require_directory=True,
	)
	root_descriptor = -1
	current_descriptor = -1
	try:
		root_descriptor = os.open(
			absolute_root,
			_owned_directory_open_flags(),
		)
		root_opened = os.fstat(root_descriptor)
		if not _same_directory_identity(root_before, root_opened):
			raise ValueError("Owned target root identity changed before creation.")
		current_descriptor = os.dup(root_descriptor)
		for component in absolute_directory.relative_to(absolute_root).parts:
			next_descriptor = -1
			try:
				next_descriptor = os.open(
					component,
					_owned_directory_open_flags(),
					dir_fd=current_descriptor,
				)
			except FileNotFoundError:
				if not create:
					raise
				os.mkdir(component, 0o700, dir_fd=current_descriptor)
				next_descriptor = os.open(
					component,
					_owned_directory_open_flags(),
					dir_fd=current_descriptor,
				)
			try:
				next_metadata = os.fstat(next_descriptor)
				if (
					not stat.S_ISDIR(next_metadata.st_mode)
					or _metadata_is_link_or_reparse(next_metadata)
				):
					raise ValueError(
						"Owned target directory crosses a link or reparse point."
					)
			except BaseException:
				os.close(next_descriptor)
				raise
			os.close(current_descriptor)
			current_descriptor = next_descriptor
		yield current_descriptor
	finally:
		if current_descriptor >= 0:
			os.close(current_descriptor)
		if root_descriptor >= 0:
			os.close(root_descriptor)


def _ensure_owned_directory_tree(
	owner_root: Path,
	directory: Path,
) -> Path:
	absolute_directory, absolute_root = _absolute_owned_path(
		directory,
		owner_root,
	)
	binding = _registered_owned_binding_for(absolute_root)
	if binding is not None:
		return binding.ensure_directory(absolute_directory)
	if _supports_secure_directory_descriptors():
		with _open_owned_directory_descriptor(
			absolute_root,
			absolute_directory,
			create=True,
		):
			pass
	else:
		_validated_private_root_for(absolute_root)
	return absolute_directory


@contextmanager
def _open_owned_target_descriptor(
	target_path: Path,
	target_owner_root: Path,
) -> Iterator[tuple[int, Path]]:
	absolute_target, absolute_target_root = _absolute_owned_path(
		target_path,
		target_owner_root,
	)
	if absolute_target == absolute_target_root:
		raise ValueError("Owned target must be below its owner root.")
	binding = _registered_owned_binding_for(absolute_target_root)
	if binding is not None:
		target = binding.create_target(absolute_target)
		try:
			yield target.file_descriptor, absolute_target
			opened_after = os.fstat(target.file_descriptor)
			binding.verify_target(target, opened_after)
		finally:
			os.close(target.file_descriptor)
		return
	if _supports_secure_directory_descriptors():
		with _open_owned_directory_descriptor(
			absolute_target_root,
			absolute_target.parent,
			create=True,
		) as parent_descriptor:
			file_descriptor = -1
			try:
				file_descriptor = os.open(
					absolute_target.name,
					_owned_write_flags(),
					0o600,
					dir_fd=parent_descriptor,
				)
				opened = os.fstat(file_descriptor)
				if (
					not stat.S_ISREG(opened.st_mode)
					or _metadata_is_link_or_reparse(opened)
				):
					raise ValueError("Owned target is not a regular file.")
				target_metadata = os.stat(
					absolute_target.name,
					dir_fd=parent_descriptor,
					follow_symlinks=False,
				)
				if not _same_regular_object_identity(opened, target_metadata):
					raise ValueError(
						"Owned target identity changed before it was written."
					)
				yield file_descriptor, absolute_target
			finally:
				if file_descriptor >= 0:
					os.close(file_descriptor)
		return

	_validated_private_root_for(absolute_target_root)
	raise ValueError("Secure owned-target creation is unavailable.")


def _write_owned_target_bytes(
	target_path: Path,
	payload: bytes,
	target_owner_root: Path,
) -> None:
	absolute_target, absolute_target_root = _absolute_owned_path(
		target_path,
		target_owner_root,
	)
	with _open_owned_target_descriptor(
		absolute_target,
		absolute_target_root,
	) as (file_descriptor, _target):
		opened_before = os.fstat(file_descriptor)
		_write_all_file_descriptor(file_descriptor, payload)
		opened_after = os.fstat(file_descriptor)
	try:
		target_after = os.lstat(absolute_target)
	except OSError as exc:
		raise ValueError("Owned target disappeared after writing.") from exc
	if (
		not _same_regular_object_identity(opened_before, opened_after)
		or not _same_file_identity(opened_after, target_after)
		or opened_after.st_size != len(payload)
	):
		raise ValueError("Owned target identity changed while it was written.")


def _read_owned_bytes(
	path: Path,
	owner_root: Path,
	max_bytes: int,
	*,
	require_nonempty: bool = False,
	work_budget: PluginWorkBudget | None = None,
	work_limits: PluginWorkLimits | None = None,
	expected_metadata: os.stat_result | None = None,
) -> bytes:
	if max_bytes < 1:
		raise ValueError("Owned-source byte limit must be positive.")
	if (work_budget is None) != (work_limits is None):
		raise ValueError("Owned-source work budget and limits must be paired.")
	absolute_path, before = _assert_owned_path(
		path,
		owner_root,
		require_file=True,
	)
	if (
		expected_metadata is not None
		and not _same_file_identity(expected_metadata, before)
	):
		raise ValueError("Owned source identity changed before it was read.")
	if before.st_size > max_bytes:
		raise ValueError("Owned source exceeds its byte limit.")
	absolute_root = Path(os.path.abspath(owner_root))
	chain_before = _snapshot_owned_directory_chain(
		absolute_root,
		absolute_path.parent,
	)
	file_descriptor = -1
	payload = bytearray()
	try:
		file_descriptor = os.open(absolute_path, _owned_read_flags())
		opened_before = os.fstat(file_descriptor)
		if (
			not stat.S_ISREG(opened_before.st_mode)
			or not _same_file_identity(before, opened_before)
		):
			raise ValueError("Owned source identity changed before it was read.")
		if work_budget is not None and work_limits is not None:
			work_budget.ensure_io_bytes(opened_before.st_size, work_limits)
		while len(payload) < opened_before.st_size:
			request_bytes = min(
				64 * 1024,
				opened_before.st_size - len(payload),
			)
			chunk = os.read(
				file_descriptor,
				request_bytes,
			)
			if not chunk:
				raise ValueError(
					"Owned source length changed while it was read."
				)
			if work_budget is not None and work_limits is not None:
				work_budget.consume_io_bytes(len(chunk), work_limits)
			payload.extend(chunk)
		opened_after = os.fstat(file_descriptor)
	finally:
		if file_descriptor >= 0:
			os.close(file_descriptor)
	try:
		after = os.lstat(absolute_path)
	except OSError as exc:
		raise ValueError("Owned source disappeared while it was read.") from exc
	chain_after = _snapshot_owned_directory_chain(
		absolute_root,
		absolute_path.parent,
	)
	if (
		not _same_file_identity(before, opened_before)
		or not _same_file_identity(opened_before, opened_after)
		or not _same_file_identity(opened_after, after)
		or not _same_directory_chain_identity(chain_before, chain_after)
	):
		raise ValueError("Owned source identity changed while it was read.")
	if len(payload) != opened_before.st_size:
		raise ValueError("Owned source length changed while it was read.")
	if require_nonempty and not payload:
		raise ValueError("Owned source must be non-empty.")
	return bytes(payload)


def _read_owned_text(
	path: Path,
	owner_root: Path,
	max_bytes: int,
	*,
	require_nonempty: bool = False,
	errors: str = "strict",
) -> str:
	return _read_owned_bytes(
		path,
		owner_root,
		max_bytes,
		require_nonempty=require_nonempty,
	).decode("utf-8", errors=errors)


def _list_owned_regular_files(
	directory: Path,
	owner_root: Path,
) -> list[Path]:
	absolute_directory, directory_before = _assert_owned_path(
		directory,
		owner_root,
		require_directory=True,
	)
	absolute_root = Path(os.path.abspath(owner_root))
	chain_before = _snapshot_owned_directory_chain(
		absolute_root,
		absolute_directory,
	)
	files: list[Path] = []
	with os.scandir(absolute_directory) as entries:
		for entry in entries:
			entry_path = Path(entry.path)
			_path, entry_stat = _assert_owned_path(
				entry_path,
				owner_root,
			)
			if not stat.S_ISREG(entry_stat.st_mode):
				raise ValueError("Owned flat directory contains a non-file entry.")
			if len(files) >= STORAGE_ACCEPTANCE_COPY_FILE_LIMIT:
				raise ValueError("Owned directory exceeds its file-count limit.")
			files.append(entry_path)
	try:
		directory_after = os.lstat(absolute_directory)
	except OSError as exc:
		raise ValueError("Owned directory disappeared during enumeration.") from exc
	chain_after = _snapshot_owned_directory_chain(
		absolute_root,
		absolute_directory,
	)
	if (
		not _same_file_identity(directory_before, directory_after)
		or not _same_directory_chain_identity(chain_before, chain_after)
	):
		raise ValueError("Owned directory changed during enumeration.")
	return sorted(files, key=lambda item: item.name)


def _copy_owned_regular_file(
	source_path: Path,
	target_path: Path,
	owner_root: Path,
	max_bytes: int,
	target_owner_root: Path,
) -> int:
	absolute_source, before = _assert_owned_path(
		source_path,
		owner_root,
		require_file=True,
	)
	if before.st_size > max_bytes:
		raise ValueError("Owned source file exceeds its copy byte limit.")
	absolute_source_root = Path(os.path.abspath(owner_root))
	source_chain_before = _snapshot_owned_directory_chain(
		absolute_source_root,
		absolute_source.parent,
	)
	absolute_target, absolute_target_root = _absolute_owned_path(
		target_path,
		target_owner_root,
	)
	copied_bytes = 0
	source_descriptor = -1
	try:
		source_descriptor = os.open(absolute_source, _owned_read_flags())
		source_opened_before = os.fstat(source_descriptor)
		if (
			not stat.S_ISREG(source_opened_before.st_mode)
			or not _same_file_identity(before, source_opened_before)
		):
			raise ValueError("Owned source identity changed before it was copied.")
		with _open_owned_target_descriptor(
			absolute_target,
			absolute_target_root,
		) as (target_descriptor, _target):
			target_opened_before = os.fstat(target_descriptor)
			while True:
				chunk = os.read(source_descriptor, 64 * 1024)
				if not chunk:
					break
				copied_bytes += len(chunk)
				if (
					copied_bytes > max_bytes
					or copied_bytes > source_opened_before.st_size
				):
					raise ValueError(
						"Owned source file exceeds its copy byte limit."
					)
				_write_all_file_descriptor(target_descriptor, chunk)
			source_opened_after = os.fstat(source_descriptor)
			target_opened_after = os.fstat(target_descriptor)
	finally:
		if source_descriptor >= 0:
			os.close(source_descriptor)
	try:
		source_after = os.lstat(absolute_source)
		target_after = os.lstat(absolute_target)
	except OSError as exc:
		raise ValueError("Owned copy identity became unavailable.") from exc
	source_chain_after = _snapshot_owned_directory_chain(
		absolute_source_root,
		absolute_source.parent,
	)
	if (
		not _same_file_identity(before, source_opened_before)
		or not _same_file_identity(source_opened_before, source_opened_after)
		or not _same_file_identity(source_opened_after, source_after)
		or copied_bytes != source_opened_before.st_size
		or not _same_directory_chain_identity(
			source_chain_before,
			source_chain_after,
		)
	):
		raise ValueError("Owned source identity changed while it was copied.")
	if (
		not _same_regular_object_identity(
			target_opened_before,
			target_opened_after,
		)
		or not _same_file_identity(target_opened_after, target_after)
		or target_opened_after.st_size != copied_bytes
	):
		raise ValueError("Owned copy target identity changed while it was written.")
	return copied_bytes


def _copy_owned_tree(
	source_root: Path,
	target_root: Path,
	target_owner_root: Path,
) -> None:
	absolute_source_root, _root_stat = _assert_owned_path(
		source_root,
		source_root,
		require_directory=True,
	)
	if os.path.lexists(target_root):
		raise FileExistsError("Owned-tree copy target must not already exist.")
	absolute_target_root = _ensure_owned_directory_tree(
		target_owner_root,
		target_root,
	)
	pending: list[tuple[Path, Path]] = [
		(absolute_source_root, absolute_target_root)
	]
	file_count = 0
	total_bytes = 0
	while pending:
		source_directory, target_directory = pending.pop()
		_before_path, directory_before = _assert_owned_path(
			source_directory,
			absolute_source_root,
			require_directory=True,
		)
		source_chain_before = _snapshot_owned_directory_chain(
			absolute_source_root,
			source_directory,
		)
		with os.scandir(source_directory) as iterator:
			entries = sorted(iterator, key=lambda entry: entry.name)
		for entry in entries:
			source_path = Path(entry.path)
			_path, entry_stat = _assert_owned_path(
				source_path,
				absolute_source_root,
			)
			target_path = target_directory / entry.name
			if stat.S_ISDIR(entry_stat.st_mode):
				_ensure_owned_directory_tree(
					target_owner_root,
					target_path,
				)
				pending.append((source_path, target_path))
				continue
			if not stat.S_ISREG(entry_stat.st_mode):
				raise ValueError("Owned tree contains a non-regular entry.")
			file_count += 1
			if (
				file_count > STORAGE_ACCEPTANCE_COPY_FILE_LIMIT
				or total_bytes + entry_stat.st_size
				> STORAGE_ACCEPTANCE_COPY_BYTE_LIMIT
			):
				raise ValueError("Owned tree exceeds its copy work budget.")
			remaining_copy_bytes = (
				STORAGE_ACCEPTANCE_COPY_BYTE_LIMIT - total_bytes
			)
			copied_bytes = _copy_owned_regular_file(
				source_path,
				target_path,
				absolute_source_root,
				min(
					STORAGE_ACCEPTANCE_COPY_SINGLE_FILE_LIMIT,
					remaining_copy_bytes,
				),
				target_owner_root,
			)
			if total_bytes + copied_bytes > STORAGE_ACCEPTANCE_COPY_BYTE_LIMIT:
				raise ValueError("Owned tree exceeds its copy work budget.")
			total_bytes += copied_bytes
		try:
			directory_after = os.lstat(source_directory)
		except OSError as exc:
			raise ValueError("Owned source directory disappeared during copy.") from exc
		source_chain_after = _snapshot_owned_directory_chain(
			absolute_source_root,
			source_directory,
		)
		if (
			not _same_file_identity(directory_before, directory_after)
			or not _same_directory_chain_identity(
				source_chain_before,
				source_chain_after,
			)
		):
			raise ValueError("Owned source directory changed during copy.")


def _read_owned_source(path: Path, owner_root: Path) -> bytes:
	return _read_owned_bytes(
		path,
		owner_root,
		STORAGE_ACCEPTANCE_COPY_SINGLE_FILE_LIMIT,
	)


def _json_bytes(value: Any) -> bytes:
	return (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")


def _sha256_file(path: Path) -> str:
	hasher = hashlib.sha256()
	with path.open("rb") as stream:
		for chunk in iter(lambda: stream.read(1024 * 1024), b""):
			hasher.update(chunk)
	return hasher.hexdigest()


def print_result(result: dict[str, Any], as_json: bool) -> None:
	if as_json:
		print(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False))
		return
	print(f"ok: {result.get('ok', False)}")
	print(f"output: {result.get('output', result.get('api_index', ''))}")
	for issue in result.get("issues", []):
		print(f"- {issue}")


if __name__ == "__main__":
	raise SystemExit(main())
