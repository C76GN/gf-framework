#!/usr/bin/env python3
"""Scan only explicit GF release inputs and Git-tracked files for credentials."""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import os
import re
import stat
import struct
import subprocess
import sys
import tempfile
import threading
import zipfile
import zlib
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from pathlib import PurePosixPath
from typing import BinaryIO
from typing import Iterator

from gf_path_security import absolute_lexical_path
from gf_path_security import path_has_reparse_component
from gf_path_security import path_is_inside_lexical


ROOT = Path(__file__).resolve().parents[1]
SCHEMA_VERSION = 1

TEXT_SUFFIXES = frozenset({
	".cfg",
	".conf",
	".cs",
	".css",
	".csv",
	".gd",
	".gdextension",
	".gitignore",
	".gitattributes",
	".html",
	".ini",
	".java",
	".js",
	".json",
	".jsonl",
	".md",
	".mk",
	".po",
	".pot",
	".ps1",
	".py",
	".rst",
	".sh",
	".svg",
	".toml",
	".ts",
	".tscn",
	".tres",
	".tsv",
	".txt",
	".uid",
	".xml",
	".yaml",
	".yml",
})
BINARY_SUFFIXES = frozenset({
	".a",
	".avi",
	".bin",
	".bmp",
	".class",
	".db",
	".dll",
	".dylib",
	".eot",
	".exe",
	".flac",
	".gif",
	".glb",
	".ico",
	".jpeg",
	".jpg",
	".lib",
	".mov",
	".mp3",
	".mp4",
	".ogg",
	".otf",
	".pdf",
	".png",
	".so",
	".sqlite",
	".ttf",
	".wasm",
	".wav",
	".webm",
	".webp",
	".woff",
	".woff2",
})
UNSUPPORTED_ARCHIVE_SUFFIXES = frozenset({
	".7z",
	".bz2",
	".gz",
	".pck",
	".tar",
	".tgz",
	".xz",
})
ZIP_SUFFIXES = frozenset({
	".apk",
	".jar",
	".nupkg",
	".whl",
	".zip",
})
SAFE_REPORT_PATH_RE = re.compile(r"^[A-Za-z0-9._+/@!()-]+$")
SENSITIVE_FILE_NAMES = frozenset({
	".env",
	".netrc",
	"_netrc",
	"credentials.json",
	"id_dsa",
	"id_ecdsa",
	"id_ed25519",
	"id_rsa",
	"service-account.json",
})
SENSITIVE_FILE_NAME_RE = re.compile(
	r"(?i)^(?:"
	r"\.env(?:\.[a-z0-9_-]+)?"
	r"|(?:client[_-]?secret|private[_-]?key|secret[_-]?key)"
	r"(?:\.(?:env|json|key|pem|txt|yaml|yml))?"
	r")$"
)
PLACEHOLDER_VALUE_WORDS = frozenset({
	"changeme",
	"change-me",
	"dummy",
	"example",
	"fake",
	"masked",
	"not-a-real",
	"placeholder",
	"redacted",
	"replace-me",
	"replace_with",
	"replace-with",
	"sample",
	"test-only",
	"your_",
	"your-",
})
ASSIGNMENT_RE = re.compile(
	r"""(?ix)
	(?<![A-Za-z0-9_])
	(?P<key>
		account[_.-]?key
		|api[_.-]?key
		|auth[_.-]?token
		|aws[_.-]?secret[_.-]?access[_.-]?key
		|client[_.-]?secret
		|private[_.-]?token
		|secret[_.-]?access[_.-]?key
		|secret[_.-]?key
		|access[_.-]?token
		|password
		|passwd
	)
	["']?\s*(?:=|:)\s*
	(?:
		"(?P<double>[^"\r\n]{8,512})"
		|'(?P<single>[^'\r\n]{8,512})'
		|(?P<bare>[^\s,;\#}\]]{8,512})
	)
	"""
)
URI_CREDENTIAL_RE = re.compile(
	r"(?i)\b[a-z][a-z0-9+.-]{1,20}://[^:/@\s]{1,128}:(?P<value>[^/@\s]{8,256})@"
)
PATH_ASSIGNMENT_CREDENTIAL_RE = re.compile(
	r"""(?ix)
	(?<![A-Za-z0-9_])
	(?:
		account[_.-]?key
		|api[_.-]?key
		|auth[_.-]?token
		|client[_.-]?secret
		|private[_.-]?token
		|secret[_.-]?(?:access[_.-]?)?key
		|access[_.-]?token
		|password
		|passwd
	)
	["']?\s*(?:=|:)\s*["']?
	(?P<value>[A-Za-z0-9_$@!+.-]{12,180})
	"""
)
PRIVATE_KEY_BLOCK_RE = re.compile(
	r"""(?msx)
	-----BEGIN[ ](?P<kind>
		(?:RSA[ ]|EC[ ]|DSA[ ]|OPENSSH[ ]|PGP[ ]|ENCRYPTED[ ])?PRIVATE[ ]KEY(?:[ ]BLOCK)?
	)-----
	(?P<body>.*?)
	-----END[ ](?P=kind)-----
	"""
)
KNOWN_TOKEN_PATTERNS = (
	(
		"credential.token.github",
		re.compile(r"(?<![A-Za-z0-9_])gh[pousr]_[A-Za-z0-9]{36,255}(?![A-Za-z0-9_])"),
	),
	(
		"credential.token.github_fine_grained",
		re.compile(
			r"(?<![A-Za-z0-9_])github_pat_[A-Za-z0-9_]{22,255}(?![A-Za-z0-9_])"
		),
	),
	(
		"credential.token.gitlab",
		re.compile(r"(?<![A-Za-z0-9_-])glpat-[A-Za-z0-9_-]{20,255}(?![A-Za-z0-9_-])"),
	),
	(
		"credential.token.google",
		re.compile(r"(?<![A-Za-z0-9_-])AIza[0-9A-Za-z_-]{35}(?![A-Za-z0-9_-])"),
	),
	(
		"credential.token.google_oauth",
		re.compile(r"(?<![A-Za-z0-9_-])GOCSPX-[0-9A-Za-z_-]{20,255}(?![A-Za-z0-9_-])"),
	),
	(
		"credential.token.npm",
		re.compile(r"(?<![A-Za-z0-9_-])npm_[A-Za-z0-9]{36,255}(?![A-Za-z0-9_-])"),
	),
	(
		"credential.token.sk_prefix",
		re.compile(r"(?<![A-Za-z0-9_-])sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{32,255}(?![A-Za-z0-9_-])"),
	),
	(
		"credential.token.slack",
		re.compile(r"(?<![A-Za-z0-9-])xox[baprs]-[A-Za-z0-9-]{20,255}(?![A-Za-z0-9-])"),
	),
	(
		"credential.token.stripe_live",
		re.compile(r"(?<![A-Za-z0-9_])sk_live_[A-Za-z0-9]{16,255}(?![A-Za-z0-9_])"),
	),
)
SUPPRESSION_RE = re.compile(
	r"#\s*gf-credential-gate:\s*allow-next=(?P<rule_id>credential\.[a-z0-9_.]+)"
	r"\s+reason=[a-z0-9][a-z0-9_-]{2,63}\s*$"
)
ALLOWED_ZIP_COMPRESSION = frozenset({
	zipfile.ZIP_STORED,
	zipfile.ZIP_DEFLATED,
})
ZIP_EOCD_SIGNATURE = b"PK\x05\x06"
ZIP_EOCD_STRUCT = struct.Struct("<4s4H2LH")
ZIP_CENTRAL_DIRECTORY_STRUCT = struct.Struct("<4s6H3L5H2L")
ZIP_LOCAL_FILE_HEADER_SIGNATURE = b"PK\x03\x04"
ZIP_LOCAL_FILE_HEADER_STRUCT = struct.Struct("<4s5H3L2H")
ZIP_MAGIC_PREFIXES = (
	b"PK\x03\x04",
	b"PK\x05\x06",
	b"PK\x07\x08",
)
ASCII_METADATA_TRANSLATION = bytes(
	byte
	if byte in {9, 10, 13} or 32 <= byte <= 126
	else 10
	for byte in range(256)
)


@dataclass(frozen=True)
class GateLimits:
	"""Hard input budgets for one credential-gate invocation."""

	max_tracked_files: int = 100_000
	max_source_file_bytes: int = 16 * 1024 * 1024
	max_source_total_bytes: int = 512 * 1024 * 1024
	max_total_io_bytes: int = 32 * 1024 * 1024 * 1024
	max_git_root_output_bytes: int = 4 * 1024
	max_git_index_output_bytes: int = 64 * 1024 * 1024
	max_git_stderr_bytes: int = 64 * 1024
	max_text_file_bytes: int = 8 * 1024 * 1024
	max_total_text_scan_bytes: int = 512 * 1024 * 1024
	max_manifest_bytes: int = 4 * 1024 * 1024
	max_artifacts: int = 2_048
	max_artifact_bytes: int = 512 * 1024 * 1024
	max_release_bytes: int = 4 * 1024 * 1024 * 1024
	max_zip_entries: int = 20_000
	max_zip_central_directory_bytes: int = 64 * 1024 * 1024
	max_zip_leading_bytes: int = 16 * 1024 * 1024
	max_total_archive_count: int = 4_096
	max_total_zip_entries: int = 200_000
	max_total_zip_central_directory_bytes: int = 256 * 1024 * 1024
	max_zip_entry_bytes: int = 64 * 1024 * 1024
	max_zip_comment_bytes: int = 64 * 1024
	max_zip_comment_scan_bytes: int = 4 * 1024 * 1024
	max_zip_expanded_bytes: int = 1024 * 1024 * 1024
	max_total_expanded_bytes: int = 4 * 1024 * 1024 * 1024
	max_zip_compression_ratio: float = 200.0
	compression_ratio_minimum_bytes: int = 4_096
	max_nested_zip_depth: int = 2
	max_issues: int = 256
	read_chunk_bytes: int = 64 * 1024


class GateInputError(Exception):
	"""An input failed a stable, non-secret-bearing validation rule."""

	def __init__(self, rule_id: str) -> None:
		super().__init__(rule_id)
		self.rule_id = rule_id


class IssueCollector:
	"""Collect only schema-bounded, non-secret issue metadata."""

	def __init__(self, limit: int) -> None:
		self._limit = max(1, limit)
		self._issues: list[dict[str, object]] = []
		self._seen: set[tuple[str, str, int]] = set()
		self._limit_reported = False

	@property
	def issues(self) -> list[dict[str, object]]:
		return list(self._issues)

	@property
	def exhausted(self) -> bool:
		return self._limit_reported or len(self._issues) >= self._limit

	def add(
		self,
		rule_id: str,
		path: str,
		line: int = 0,
		*,
		sensitive_value: str = "",
	) -> None:
		path = _sanitize_issue_path(path)
		if sensitive_value and sensitive_value in path:
			path = "gate-entry"
		safe_line = line if 0 < line <= 2_000_000_000 else 0
		identity = (rule_id, path, safe_line)
		if identity in self._seen:
			return
		self._seen.add(identity)
		if len(self._issues) >= self._limit:
			if not self._limit_reported:
				self._limit_reported = True
				self._issues[-1] = {
					"rule_id": "credential_gate.issue_budget_exceeded",
					"path": "gate",
				}
			return
		issue: dict[str, object] = {
			"rule_id": rule_id,
			"path": path,
		}
		if safe_line:
			issue["line"] = safe_line
		self._issues.append(issue)


@dataclass
class WorkBudget:
	"""Invocation-global work counters shared across source and release scans."""

	source_bytes: int = 0
	text_bytes: int = 0
	archive_count: int = 0
	archive_entries: int = 0
	central_directory_bytes: int = 0
	expanded_bytes: int = 0
	io_bytes: int = 0
	hard_exhausted: bool = False

	def ensure_io_bytes(self, amount: int, limits: GateLimits) -> None:
		safe_amount = max(0, amount)
		if self.io_bytes + safe_amount > limits.max_total_io_bytes:
			self.hard_exhausted = True
			raise GateInputError("credential_gate.io_total_budget_exceeded")

	def consume_io_bytes(self, amount: int, limits: GateLimits) -> None:
		safe_amount = max(0, amount)
		self.ensure_io_bytes(safe_amount, limits)
		self.io_bytes += safe_amount

	def consume_source_bytes(self, amount: int, limits: GateLimits) -> None:
		self.source_bytes += max(0, amount)
		if self.source_bytes > limits.max_source_total_bytes:
			self.hard_exhausted = True
			raise GateInputError("credential_gate.source_total_budget_exceeded")

	def consume_text_bytes(self, amount: int, limits: GateLimits) -> None:
		self.text_bytes += max(0, amount)
		if self.text_bytes > limits.max_total_text_scan_bytes:
			self.hard_exhausted = True
			raise GateInputError("credential_gate.text_total_budget_exceeded")

	def consume_archive(
		self,
		entry_count: int,
		central_directory_bytes: int,
		limits: GateLimits,
	) -> None:
		self.archive_count += 1
		self.archive_entries += max(0, entry_count)
		self.central_directory_bytes += max(0, central_directory_bytes)
		if self.archive_count > limits.max_total_archive_count:
			self.hard_exhausted = True
			raise GateInputError("credential_gate.archive_total_count_exceeded")
		if self.archive_entries > limits.max_total_zip_entries:
			self.hard_exhausted = True
			raise GateInputError("credential_gate.archive_total_entry_count_exceeded")
		if (
			self.central_directory_bytes
			> limits.max_total_zip_central_directory_bytes
		):
			self.hard_exhausted = True
			raise GateInputError(
				"credential_gate.archive_total_central_directory_budget_exceeded"
			)

	def consume_expanded_bytes(self, amount: int, limits: GateLimits) -> None:
		self.expanded_bytes += max(0, amount)
		if self.expanded_bytes > limits.max_total_expanded_bytes:
			self.hard_exhausted = True
			raise GateInputError("credential_gate.archive_total_expanded_budget_exceeded")


class _BudgetedBinaryReader:
	"""Account every physical or logical read against one invocation budget."""

	def __init__(
		self,
		handle: BinaryIO,
		logical_size: int,
		work_budget: WorkBudget,
		limits: GateLimits,
	) -> None:
		self._handle = handle
		self._logical_size = max(0, logical_size)
		self._work_budget = work_budget
		self._limits = limits

	def read(self, size: int = -1) -> bytes:
		try:
			position = self._handle.tell()
		except (OSError, ValueError):
			raise GateInputError("credential_gate.controlled_read_incomplete") from None
		remaining = max(0, self._logical_size - max(0, position))
		requested = remaining if size is None or size < 0 else min(size, remaining)
		self._work_budget.ensure_io_bytes(requested, self._limits)
		try:
			payload = self._handle.read(size)
		except (OSError, ValueError):
			raise GateInputError("credential_gate.controlled_read_incomplete") from None
		if not isinstance(payload, bytes):
			payload = bytes(payload)
		if len(payload) > requested:
			raise GateInputError("credential_gate.controlled_read_incomplete")
		self._work_budget.consume_io_bytes(len(payload), self._limits)
		return payload

	def read1(self, size: int = -1) -> bytes:
		return self.read(size)

	def readinto(self, buffer: bytearray | memoryview) -> int:
		payload = self.read(len(buffer))
		buffer[:len(payload)] = payload
		return len(payload)

	def seek(self, offset: int, whence: int = os.SEEK_SET) -> int:
		try:
			return self._handle.seek(offset, whence)
		except (OSError, ValueError):
			raise GateInputError("credential_gate.controlled_read_incomplete") from None

	def tell(self) -> int:
		try:
			return self._handle.tell()
		except (OSError, ValueError):
			raise GateInputError("credential_gate.controlled_read_incomplete") from None

	def fileno(self) -> int:
		return self._handle.fileno()

	def readable(self) -> bool:
		return True

	def seekable(self) -> bool:
		return True

	def __getattr__(self, name: str) -> object:
		return getattr(self._handle, name)


class _BudgetedBinaryWriter:
	"""Preflight and account every snapshot write before bytes leave the process."""

	def __init__(
		self,
		handle: BinaryIO,
		work_budget: WorkBudget,
		limits: GateLimits,
	) -> None:
		self._handle = handle
		self._work_budget = work_budget
		self._limits = limits

	def write(self, payload: bytes) -> int:
		self._work_budget.ensure_io_bytes(len(payload), self._limits)
		try:
			written = self._handle.write(payload)
		except (OSError, ValueError):
			raise GateInputError("credential_gate.release_snapshot_failed") from None
		if written is None or written < 0 or written > len(payload):
			raise GateInputError("credential_gate.release_snapshot_failed")
		self._work_budget.consume_io_bytes(written, self._limits)
		return written

	def flush(self) -> None:
		self._handle.flush()

	def fileno(self) -> int:
		return self._handle.fileno()

	def __getattr__(self, name: str) -> object:
		return getattr(self._handle, name)


@dataclass(frozen=True)
class ReleaseEvidence:
	"""Private release identity evidence; never include this object in reports."""

	manifest_sha256: str
	artifacts: tuple[tuple[str, int, str], ...]


@dataclass(frozen=True)
class ZipPreflight:
	"""Bounded EOCD facts that must agree with the parsed central directory."""

	entry_count: int
	central_directory_bytes: int
	archive_size: int
	leading_bytes: int
	central_directory_offset: int


@dataclass(frozen=True)
class ReleaseSnapshot:
	"""Private materialized release snapshot shared by scanning and semantic audit."""

	manifest_path: Path
	evidence: ReleaseEvidence


@dataclass
class ScanStats:
	tracked_file_count: int = 0
	artifact_count: int = 0
	archive_count: int = 0
	archive_entry_count: int = 0
	text_file_count: int = 0
	skipped_binary_count: int = 0
	expanded_bytes: int = 0

	def to_dict(self) -> dict[str, int]:
		return {
			"tracked_file_count": self.tracked_file_count,
			"artifact_count": self.artifact_count,
			"archive_count": self.archive_count,
			"archive_entry_count": self.archive_entry_count,
			"text_file_count": self.text_file_count,
			"skipped_binary_count": self.skipped_binary_count,
			"expanded_bytes": self.expanded_bytes,
		}


def main() -> int:
	configure_stdio()
	parser = argparse.ArgumentParser(
		description="Scan Git-tracked files and explicitly manifested release artifacts for credentials.",
		epilog=(
			"Documented examples should use recognizable placeholder values. A deliberate real-shape "
			"tracked test fixture may suppress exactly the next line and one rule with "
			"'# gf-credential-gate: allow-next=<rule> reason=<reviewable-id>'. "
			"Release artifacts never honor inline suppression. "
			"Reports contain only rule ids, bounded relative paths, safe line numbers, and counters."
		),
	)
	parser.add_argument(
		"--repo-root",
		default=str(ROOT),
		help="Git worktree whose tracked files are scanned. No directory walk is performed.",
	)
	parser.add_argument(
		"--artifact-manifest",
		default="",
		help="Optional explicit release artifact manifest. Only its listed files are scanned.",
	)
	parser.add_argument("--release-only", action="store_true", help="Skip the Git-tracked source scan.")
	parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")
	args = parser.parse_args()

	try:
		if args.release_only:
			if not args.artifact_manifest.strip():
				result = _failure_result(
					"release",
					"credential_gate.release_manifest_required",
					"manifest",
				)
			else:
				result = run_release_gate(Path(args.artifact_manifest))
		elif args.artifact_manifest.strip():
			result = run_repository_and_release_gate(
				Path(args.repo_root),
				Path(args.artifact_manifest),
			)
		else:
			result = run_tracked_gate(Path(args.repo_root))
	except Exception:
		result = _failure_result(
			"internal",
			"credential_gate.internal_error",
			"gate",
		)
	print_result(result, args.json)
	return 0 if result.get("ok", False) else 1


def configure_stdio() -> None:
	for stream in (sys.stdin, sys.stdout, sys.stderr):
		if hasattr(stream, "reconfigure"):
			stream.reconfigure(encoding="utf-8", errors="replace")


def run_tracked_gate(
	repo_root: Path = ROOT,
	limits: GateLimits | None = None,
) -> dict[str, object]:
	try:
		return scan_tracked_repository(repo_root, limits)
	except Exception:
		return _failure_result(
			"tracked",
			"credential_gate.internal_error",
			"gate",
		)


def run_release_gate(
	artifact_manifest: Path,
	limits: GateLimits | None = None,
) -> dict[str, object]:
	try:
		return scan_release_manifest(artifact_manifest, limits)
	except Exception:
		return _failure_result(
			"release",
			"credential_gate.internal_error",
			"gate",
		)


def run_release_gate_with_evidence(
	artifact_manifest: Path,
	limits: GateLimits | None = None,
) -> tuple[dict[str, object], ReleaseEvidence | None]:
	"""Run the release gate and retain non-serializable identity evidence for a caller."""
	evidence: list[ReleaseEvidence] = []
	try:
		result = scan_release_manifest(
			artifact_manifest,
			limits,
			evidence_out=evidence,
		)
	except Exception:
		return (
			_failure_result(
				"release",
				"credential_gate.internal_error",
				"gate",
			),
			None,
		)
	return result, evidence[0] if result.get("ok", False) and evidence else None


def release_audit_matches_evidence(
	audit_result: dict[str, object],
	evidence: ReleaseEvidence | None,
) -> bool:
	"""Compare an artifact audit to private gate evidence without exposing digests."""
	if evidence is None:
		return False
	raw_artifacts = audit_result.get("artifacts")
	if not isinstance(raw_artifacts, list):
		return False
	bindings: list[tuple[str, int, str]] = []
	for raw_artifact in raw_artifacts:
		if not isinstance(raw_artifact, dict):
			return False
		raw_path = raw_artifact.get("path")
		raw_size = raw_artifact.get("size_bytes")
		raw_sha256 = raw_artifact.get("sha256")
		if (
			not isinstance(raw_path, str)
			or not isinstance(raw_size, int)
			or isinstance(raw_size, bool)
			or not isinstance(raw_sha256, str)
			or re.fullmatch(r"[0-9a-f]{64}", raw_sha256) is None
		):
			return False
		try:
			normalized = _normalize_relative_path(raw_path)
		except GateInputError:
			return False
		bindings.append((normalized, raw_size, raw_sha256))
	return tuple(bindings) == evidence.artifacts


def release_snapshot_failure() -> dict[str, object]:
	"""Return a stable report for cross-step release identity drift."""
	return _failure_result(
		"release",
		"credential_gate.release_snapshot_changed",
		"manifest",
	)


@contextmanager
def materialized_release_snapshot(
	manifest_path: Path,
	limits: GateLimits | None = None,
) -> Iterator[tuple[ReleaseSnapshot | None, dict[str, object] | None]]:
	"""Copy one explicit release set into a private bounded snapshot for all consumers."""
	active_limits = limits or GateLimits()
	work_budget = WorkBudget()
	temporary: tempfile.TemporaryDirectory[str] | None = None
	snapshot_binding: _SnapshotRootBinding | None = None
	try:
		manifest = absolute_lexical_path(manifest_path)
		manifest_bytes = _read_regular_file(
			manifest,
			active_limits.max_manifest_bytes,
			"credential_gate.release_manifest_budget_exceeded",
			containment_root=manifest.parent,
			work_budget=work_budget,
			limits=active_limits,
		)
		if b"\0" in manifest_bytes:
			raise GateInputError("credential_gate.release_manifest_invalid")
		data = json.loads(manifest_bytes.decode("utf-8", errors="strict"))
		if not isinstance(data, dict):
			raise GateInputError("credential_gate.release_manifest_invalid")
		raw_artifacts = data.get("artifacts")
		if (
			not isinstance(raw_artifacts, list)
			or not raw_artifacts
			or len(raw_artifacts) > active_limits.max_artifacts
		):
			raise GateInputError("credential_gate.release_artifact_count_exceeded")

		artifact_root = manifest.parent
		seen_paths: set[str] = set()
		preflight: list[tuple[Path, str, int, str]] = []
		total_bytes = 0
		for raw_artifact in raw_artifacts:
			if not isinstance(raw_artifact, dict):
				raise GateInputError("credential_gate.release_artifact_invalid")
			raw_path = raw_artifact.get("path")
			raw_size = raw_artifact.get("size_bytes")
			raw_sha256 = raw_artifact.get("sha256")
			if (
				not isinstance(raw_path, str)
				or not isinstance(raw_size, int)
				or isinstance(raw_size, bool)
				or not isinstance(raw_sha256, str)
				or re.fullmatch(r"[0-9a-f]{64}", raw_sha256) is None
			):
				raise GateInputError("credential_gate.release_artifact_invalid")
			normalized = _normalize_relative_path(raw_path)
			identity = normalized.casefold()
			if identity in seen_paths:
				raise GateInputError("credential_gate.release_artifact_duplicate")
			seen_paths.add(identity)
			source = _controlled_relative_path(artifact_root, normalized)
			actual_size = _regular_file_size(
				source,
				containment_root=artifact_root,
			)
			if actual_size != raw_size:
				raise GateInputError("credential_gate.release_artifact_size_mismatch")
			if actual_size > active_limits.max_artifact_bytes:
				raise GateInputError("credential_gate.release_artifact_budget_exceeded")
			total_bytes += actual_size
			if total_bytes > active_limits.max_release_bytes:
				raise GateInputError("credential_gate.release_total_budget_exceeded")
			preflight.append((source, normalized, actual_size, raw_sha256))

		temporary = tempfile.TemporaryDirectory(prefix="gf-credential-release-")
		snapshot_root = absolute_lexical_path(Path(temporary.name))
		if path_has_reparse_component(snapshot_root):
			raise GateInputError("credential_gate.snapshot_boundary_invalid")
		snapshot_binding = _SnapshotRootBinding(snapshot_root)
		snapshot_manifest = snapshot_root / "release-manifest.json"
		_write_snapshot_bytes(
			snapshot_manifest,
			manifest_bytes,
			snapshot_binding,
			work_budget,
			active_limits,
		)
		bindings: list[tuple[str, int, str]] = []
		for source, normalized, expected_size, expected_sha256 in preflight:
			target = snapshot_root / normalized
			_copy_snapshot_file(
				source,
				target,
				expected_size,
				expected_sha256,
				active_limits,
				artifact_root,
				snapshot_binding,
				work_budget,
			)
			bindings.append((normalized, expected_size, expected_sha256))
		snapshot = ReleaseSnapshot(
			manifest_path=snapshot_manifest,
			evidence=ReleaseEvidence(
				manifest_sha256=hashlib.sha256(manifest_bytes).hexdigest(),
				artifacts=tuple(bindings),
			),
		)
	except (GateInputError, OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
		if snapshot_binding is not None:
			snapshot_binding.close()
		if temporary is not None:
			temporary.cleanup()
		rule_id = (
			error.rule_id
			if isinstance(error, GateInputError)
			else "credential_gate.release_snapshot_failed"
		)
		yield None, _failure_result("release", rule_id, "manifest")
		return
	except Exception:
		if snapshot_binding is not None:
			snapshot_binding.close()
		if temporary is not None:
			temporary.cleanup()
		yield None, _failure_result(
			"release",
			"credential_gate.release_snapshot_failed",
			"manifest",
		)
		return
	try:
		yield snapshot, None
	finally:
		if snapshot_binding is not None:
			snapshot_binding.close()
		if temporary is not None:
			temporary.cleanup()


def _write_snapshot_bytes(
	path: Path,
	payload: bytes,
	snapshot_binding: _SnapshotRootBinding,
	work_budget: WorkBudget,
	limits: GateLimits,
) -> None:
	try:
		with _open_snapshot_target(
			path,
			snapshot_binding,
			work_budget,
			limits,
		) as handle:
			_write_all_stream(handle, payload)
			handle.flush()
			if os.fstat(handle.fileno()).st_size != len(payload):
				raise GateInputError("credential_gate.release_snapshot_failed")
	except OSError:
		raise GateInputError("credential_gate.release_snapshot_failed") from None


def _copy_snapshot_file(
	source: Path,
	target: Path,
	expected_size: int,
	expected_sha256: str,
	limits: GateLimits,
	source_root: Path,
	snapshot_binding: _SnapshotRootBinding,
	work_budget: WorkBudget,
) -> None:
	try:
		digest = hashlib.sha256()
		copied_bytes = 0
		with _open_regular_file(
			source,
			limits.max_artifact_bytes,
			"credential_gate.release_artifact_budget_exceeded",
			containment_root=source_root,
			work_budget=work_budget,
			limits=limits,
		) as (source_handle, stable_size):
			if stable_size != expected_size:
				raise GateInputError("credential_gate.release_artifact_size_mismatch")
			with _open_snapshot_target(
				target,
				snapshot_binding,
				work_budget,
				limits,
			) as target_handle:
				while True:
					chunk = source_handle.read(limits.read_chunk_bytes)
					if not chunk:
						break
					copied_bytes += len(chunk)
					if copied_bytes > expected_size:
						raise GateInputError(
							"credential_gate.controlled_read_budget_exceeded"
						)
					digest.update(chunk)
					_write_all_stream(target_handle, chunk)
				if copied_bytes != expected_size:
					raise GateInputError("credential_gate.controlled_read_incomplete")
				if digest.hexdigest() != expected_sha256:
					raise GateInputError(
						"credential_gate.release_artifact_hash_mismatch"
					)
				target_handle.flush()
				if os.fstat(target_handle.fileno()).st_size != copied_bytes:
					raise GateInputError(
						"credential_gate.release_snapshot_failed"
					)
	except OSError:
		raise GateInputError("credential_gate.release_snapshot_failed") from None


def run_repository_and_release_gate(
	repo_root: Path,
	artifact_manifest: Path,
	limits: GateLimits | None = None,
) -> dict[str, object]:
	try:
		return scan_repository_and_release(repo_root, artifact_manifest, limits)
	except Exception:
		return _failure_result(
			"tracked_and_release",
			"credential_gate.internal_error",
			"gate",
		)


def scan_repository_and_release(
	repo_root: Path,
	artifact_manifest: Path,
	limits: GateLimits | None = None,
) -> dict[str, object]:
	active_limits = limits or GateLimits()
	work_budget = WorkBudget()
	source = scan_tracked_repository(repo_root, active_limits, work_budget)
	release = scan_release_manifest(artifact_manifest, active_limits, work_budget)
	issues = [
		*list(source.get("issues", [])),
		*list(release.get("issues", [])),
	]
	return {
		"schema_version": SCHEMA_VERSION,
		"ok": not issues,
		"mode": "tracked_and_release",
		"issues": issues,
		"source": source,
		"release": release,
	}


def scan_tracked_repository(
	repo_root: Path = ROOT,
	limits: GateLimits | None = None,
	work_budget: WorkBudget | None = None,
) -> dict[str, object]:
	active_limits = limits or GateLimits()
	active_work_budget = work_budget or WorkBudget()
	collector = IssueCollector(active_limits.max_issues)
	stats = ScanStats()
	if active_work_budget.hard_exhausted:
		collector.add("credential_gate.work_budget_exhausted", "gate")
		return _result("tracked", collector, stats)
	root = absolute_lexical_path(repo_root)
	try:
		tracked_paths, repository_binding, index_fingerprint = _git_tracked_paths(
			root,
			active_limits,
			active_work_budget,
		)
	except GateInputError as error:
		collector.add(error.rule_id, "git-index")
		return _result("tracked", collector, stats)

	stats.tracked_file_count = len(tracked_paths)
	preflight: list[tuple[Path, str, str]] = []
	for index, relative_path in enumerate(tracked_paths):
		if not _directory_binding_is_current(root, repository_binding):
			return _failure_result(
				"tracked",
				"credential_gate.repository_changed",
				"git-index",
			)
		report_path = _safe_report_path(relative_path, f"tracked-entry-{index + 1}")
		if _contains_credential_shape(relative_path):
			collector.add("credential.sensitive_path_value", report_path)
		try:
			file_kind = _file_kind(relative_path)
			_scan_sensitive_file_name(report_path, collector)
			candidate = _controlled_relative_path(root, relative_path)
			size = _regular_file_size(candidate, containment_root=root)
			if file_kind in {"text", "unknown"} and size > active_limits.max_source_file_bytes:
				raise GateInputError("credential_gate.source_file_budget_exceeded")
			if file_kind == "zip" and size > active_limits.max_artifact_bytes:
				raise GateInputError("credential_gate.archive_file_budget_exceeded")
			preflight.append((candidate, report_path, file_kind))
		except GateInputError as error:
			collector.add(error.rule_id, report_path)
		if collector.exhausted or active_work_budget.hard_exhausted:
			break

	if collector.issues:
		if not _directory_binding_is_current(root, repository_binding):
			return _failure_result(
				"tracked",
				"credential_gate.repository_changed",
				"git-index",
			)
		return _result("tracked", collector, stats)

	for candidate, report_path, file_kind in preflight:
		if not _directory_binding_is_current(root, repository_binding):
			return _failure_result(
				"tracked",
				"credential_gate.repository_changed",
				"git-index",
			)
		_scan_path(
			candidate,
			report_path,
			file_kind,
			active_limits,
			collector,
			stats,
			active_work_budget,
			containment_root=root,
			allow_suppression=_source_path_allows_suppression(report_path),
			count_source_bytes=True,
		)
		if collector.exhausted or active_work_budget.hard_exhausted:
			break
	if not _directory_binding_is_current(root, repository_binding):
		return _failure_result(
			"tracked",
			"credential_gate.repository_changed",
			"git-index",
		)
	if collector.issues or active_work_budget.hard_exhausted:
		return _result("tracked", collector, stats)
	try:
		(
			final_tracked_paths,
			final_repository_binding,
			final_index_fingerprint,
		) = _git_tracked_paths(
			root,
			active_limits,
			active_work_budget,
		)
	except GateInputError as error:
		collector.add(error.rule_id, "git-index")
		return _result("tracked", collector, stats)
	if (
		tracked_paths != final_tracked_paths
		or index_fingerprint != final_index_fingerprint
		or not _directory_binding_is_current(root, repository_binding)
		or not _directory_binding_is_current(root, final_repository_binding)
	):
		return _failure_result(
			"tracked",
			"credential_gate.repository_changed",
			"git-index",
		)
	return _result("tracked", collector, stats)


def scan_release_manifest(
	manifest_path: Path,
	limits: GateLimits | None = None,
	work_budget: WorkBudget | None = None,
	*,
	evidence_out: list[ReleaseEvidence] | None = None,
) -> dict[str, object]:
	active_limits = limits or GateLimits()
	active_work_budget = work_budget or WorkBudget()
	collector = IssueCollector(active_limits.max_issues)
	stats = ScanStats()
	if active_work_budget.hard_exhausted:
		collector.add("credential_gate.work_budget_exhausted", "gate")
		return _result("release", collector, stats)
	manifest = absolute_lexical_path(manifest_path)
	try:
		manifest_bytes = _read_regular_file(
			manifest,
			active_limits.max_manifest_bytes,
			"credential_gate.release_manifest_budget_exceeded",
			containment_root=manifest.parent,
			work_budget=active_work_budget,
			limits=active_limits,
		)
		active_work_budget.consume_text_bytes(len(manifest_bytes), active_limits)
		if b"\0" in manifest_bytes:
			raise GateInputError("credential_gate.release_manifest_invalid")
		manifest_text = manifest_bytes.decode("utf-8", errors="strict")
		_scan_text(
			manifest_text,
			"manifest",
			collector,
			allow_suppression=False,
		)
		data = json.loads(manifest_text)
	except (GateInputError, UnicodeDecodeError, json.JSONDecodeError) as error:
		rule_id = (
			error.rule_id
			if isinstance(error, GateInputError)
			else "credential_gate.release_manifest_invalid"
		)
		collector.add(rule_id, "manifest")
		return _result("release", collector, stats)
	if collector.issues:
		return _result("release", collector, stats)

	if not isinstance(data, dict):
		collector.add("credential_gate.release_manifest_invalid", "manifest")
		return _result("release", collector, stats)
	raw_artifacts = data.get("artifacts")
	if not isinstance(raw_artifacts, list):
		collector.add("credential_gate.release_manifest_invalid", "manifest")
		return _result("release", collector, stats)
	if not raw_artifacts or len(raw_artifacts) > active_limits.max_artifacts:
		collector.add("credential_gate.release_artifact_count_exceeded", "manifest")
		return _result("release", collector, stats)

	artifact_root = manifest.parent
	seen_paths: set[str] = set()
	preflight: list[tuple[Path, str, str, str]] = []
	artifact_bindings: list[tuple[str, int, str]] = []
	total_bytes = 0
	for index, raw_artifact in enumerate(raw_artifacts):
		fallback_path = f"artifact-{index + 1}"
		if not isinstance(raw_artifact, dict):
			collector.add("credential_gate.release_artifact_invalid", fallback_path)
			continue
		raw_path = raw_artifact.get("path")
		if not isinstance(raw_path, str):
			collector.add("credential_gate.release_artifact_invalid", fallback_path)
			continue
		report_path = _safe_report_path(raw_path, fallback_path)
		if _contains_credential_shape(raw_path):
			collector.add("credential.sensitive_path_value", report_path)
		try:
			normalized = _normalize_relative_path(raw_path)
			identity = normalized.casefold()
			if identity in seen_paths:
				raise GateInputError("credential_gate.release_artifact_duplicate")
			seen_paths.add(identity)
			candidate = _controlled_relative_path(artifact_root, normalized)
			size = _regular_file_size(
				candidate,
				containment_root=artifact_root,
			)
			declared_size = raw_artifact.get("size_bytes")
			if not isinstance(declared_size, int) or isinstance(declared_size, bool):
				raise GateInputError("credential_gate.release_artifact_invalid")
			if declared_size != size:
				raise GateInputError("credential_gate.release_artifact_size_mismatch")
			declared_sha256 = raw_artifact.get("sha256")
			if (
				not isinstance(declared_sha256, str)
				or re.fullmatch(r"[0-9a-f]{64}", declared_sha256) is None
			):
				raise GateInputError("credential_gate.release_artifact_invalid")
			if size > active_limits.max_artifact_bytes:
				raise GateInputError("credential_gate.release_artifact_budget_exceeded")
			total_bytes += size
			if total_bytes > active_limits.max_release_bytes:
				raise GateInputError("credential_gate.release_total_budget_exceeded")
			file_kind = _file_kind(normalized)
			preflight.append((candidate, report_path, file_kind, declared_sha256))
			artifact_bindings.append((normalized, size, declared_sha256))
		except GateInputError as error:
			collector.add(error.rule_id, report_path)
		if collector.exhausted or active_work_budget.hard_exhausted:
			break

	stats.artifact_count = len(preflight)
	if collector.issues:
		return _result("release", collector, stats)

	for candidate, report_path, file_kind, declared_sha256 in preflight:
		_scan_path(
			candidate,
			report_path,
			file_kind,
			active_limits,
			collector,
			stats,
			active_work_budget,
			containment_root=artifact_root,
			allow_suppression=False,
			expected_sha256=declared_sha256,
		)
		if collector.exhausted or active_work_budget.hard_exhausted:
			break
	result = _result("release", collector, stats)
	if result.get("ok", False) and evidence_out is not None:
		evidence_out.append(
			ReleaseEvidence(
				manifest_sha256=hashlib.sha256(manifest_bytes).hexdigest(),
				artifacts=tuple(artifact_bindings),
			)
		)
	return result


def print_result(result: dict[str, object], as_json: bool) -> None:
	if as_json:
		print(json.dumps(result, ensure_ascii=False, indent=2))
		return
	stats = result.get("stats", {})
	if not isinstance(stats, dict):
		stats = {}
	print(
		f"credential_gate ok={result.get('ok', False)} mode={result.get('mode', '')} "
		f"tracked={stats.get('tracked_file_count', 0)} "
		f"artifacts={stats.get('artifact_count', 0)} "
		f"archives={stats.get('archive_count', 0)}"
	)
	for raw_issue in result.get("issues", []):
		if not isinstance(raw_issue, dict):
			continue
		print(f"- {issue_summary(raw_issue)}")


def issue_summary(raw_issue: dict[str, object]) -> str:
	raw_rule_id = raw_issue.get("rule_id")
	rule_id = (
		raw_rule_id
		if isinstance(raw_rule_id, str)
		and re.fullmatch(r"credential(?:_gate)?\.[a-z0-9_.]+", raw_rule_id) is not None
		else "credential_gate.invalid_issue"
	)
	raw_path = raw_issue.get("path")
	path = raw_path if isinstance(raw_path, str) else "gate"
	path = _sanitize_issue_path(path)
	raw_line = raw_issue.get("line")
	if isinstance(raw_line, int) and not isinstance(raw_line, bool) and 0 < raw_line <= 2_000_000_000:
		path = f"{path}:{raw_line}"
	return f"{rule_id} {path}"


def safe_path_label(raw_path: str, fallback: str) -> str:
	"""Return a bounded relative path label with credential-shaped values removed."""
	return _safe_report_path(raw_path, fallback)


def _git_tracked_paths(
	root: Path,
	limits: GateLimits,
	work_budget: WorkBudget,
) -> tuple[list[str], tuple[tuple[Path, os.stat_result], ...], bytes]:
	if path_has_reparse_component(root):
		raise GateInputError("credential_gate.repository_root_linked")
	repository_binding = _snapshot_full_directory_chain(root)
	git_environment = _isolated_git_environment()
	top_level_code, top_level_stdout, top_level_stderr = _run_bounded_capture(
		["git", "rev-parse", "--show-toplevel"],
		root,
		git_environment,
		limits.max_git_root_output_bytes,
		limits.max_git_stderr_bytes,
	)
	work_budget.consume_io_bytes(
		len(top_level_stdout) + len(top_level_stderr),
		limits,
	)
	if not _directory_binding_is_current(root, repository_binding):
		raise GateInputError("credential_gate.repository_changed")
	completed_code, completed_stdout, completed_stderr = _run_bounded_capture(
		["git", "ls-files", "-z", "--cached", "--stage"],
		root,
		git_environment,
		limits.max_git_index_output_bytes,
		limits.max_git_stderr_bytes,
	)
	work_budget.consume_io_bytes(
		len(completed_stdout) + len(completed_stderr),
		limits,
	)
	if not _directory_binding_is_current(root, repository_binding):
		raise GateInputError("credential_gate.repository_changed")
	if top_level_code != 0 or top_level_stderr:
		raise GateInputError("credential_gate.git_index_unavailable")
	try:
		reported_root = top_level_stdout.decode("utf-8", errors="strict").strip()
	except UnicodeDecodeError:
		raise GateInputError("credential_gate.git_index_invalid") from None
	if not reported_root or not _paths_identical(root, absolute_lexical_path(Path(reported_root))):
		raise GateInputError("credential_gate.git_repository_scope_mismatch")
	if completed_code != 0 or completed_stderr:
		raise GateInputError("credential_gate.git_index_unavailable")
	try:
		decoded = completed_stdout.decode("utf-8", errors="strict")
	except UnicodeDecodeError:
		raise GateInputError("credential_gate.git_index_invalid") from None
	records = decoded.split("\0")
	if records and not records[-1]:
		records.pop()
	if not records or len(records) > limits.max_tracked_files:
		raise GateInputError("credential_gate.tracked_file_count_exceeded")
	normalized: list[str] = []
	seen: set[str] = set()
	for record in records:
		metadata, separator, raw_path = record.partition("\t")
		metadata_parts = metadata.split(" ")
		if (
			not separator
			or len(metadata_parts) != 3
			or re.fullmatch(r"[0-7]{6}", metadata_parts[0]) is None
			or re.fullmatch(r"[0-9a-f]{40,64}", metadata_parts[1]) is None
			or metadata_parts[2] != "0"
		):
			raise GateInputError("credential_gate.git_index_invalid")
		path = _normalize_relative_path(raw_path)
		identity = path.casefold()
		if identity in seen:
			raise GateInputError("credential_gate.tracked_path_duplicate")
		seen.add(identity)
		normalized.append(path)
	if not _directory_binding_is_current(root, repository_binding):
		raise GateInputError("credential_gate.repository_changed")
	return (
		normalized,
		repository_binding,
		hashlib.sha256(completed_stdout).digest(),
	)


def _run_bounded_capture(
	arguments: list[str],
	cwd: Path,
	environment: dict[str, str],
	max_stdout_bytes: int,
	max_stderr_bytes: int,
) -> tuple[int, bytes, bytes]:
	try:
		process = subprocess.Popen(
			arguments,
			cwd=cwd,
			env=environment,
			stdin=subprocess.DEVNULL,
			stdout=subprocess.PIPE,
			stderr=subprocess.PIPE,
		)
	except OSError:
		raise GateInputError("credential_gate.git_index_unavailable") from None
	if process.stdout is None or process.stderr is None:
		process.kill()
		raise GateInputError("credential_gate.git_index_unavailable")

	stdout_buffer = bytearray()
	stderr_buffer = bytearray()
	output_exceeded = threading.Event()
	reader_failed = threading.Event()

	def read_stream(
		stream: BinaryIO,
		buffer: bytearray,
		max_bytes: int,
	) -> None:
		try:
			while True:
				chunk = stream.read(64 * 1024)
				if not chunk:
					return
				remaining = max(0, max_bytes + 1 - len(buffer))
				if remaining:
					buffer.extend(chunk[:remaining])
				if len(buffer) > max_bytes or len(chunk) > remaining:
					output_exceeded.set()
					try:
						process.kill()
					except OSError:
						pass
					return
		except (OSError, ValueError):
			reader_failed.set()
			try:
				process.kill()
			except OSError:
				pass

	stdout_thread = threading.Thread(
		target=read_stream,
		args=(process.stdout, stdout_buffer, max(0, max_stdout_bytes)),
		daemon=True,
	)
	stderr_thread = threading.Thread(
		target=read_stream,
		args=(process.stderr, stderr_buffer, max(0, max_stderr_bytes)),
		daemon=True,
	)
	stdout_thread.start()
	stderr_thread.start()
	try:
		return_code = process.wait(timeout=30)
	except subprocess.TimeoutExpired:
		process.kill()
		try:
			process.wait(timeout=5)
		except subprocess.TimeoutExpired:
			pass
		raise GateInputError("credential_gate.git_index_unavailable") from None
	finally:
		stdout_thread.join(timeout=5)
		stderr_thread.join(timeout=5)
		process.stdout.close()
		process.stderr.close()
	if stdout_thread.is_alive() or stderr_thread.is_alive() or reader_failed.is_set():
		raise GateInputError("credential_gate.git_index_unavailable")
	if output_exceeded.is_set():
		raise GateInputError("credential_gate.git_index_output_budget_exceeded")
	return return_code, bytes(stdout_buffer), bytes(stderr_buffer)


def _isolated_git_environment() -> dict[str, str]:
	environment = {
		key: value
		for key, value in os.environ.items()
		if not key.upper().startswith("GIT_")
	}
	environment["GIT_CONFIG_NOSYSTEM"] = "1"
	environment["GIT_OPTIONAL_LOCKS"] = "0"
	return environment


def _paths_identical(left: Path, right: Path) -> bool:
	return os.path.normcase(os.path.normpath(str(left))) == os.path.normcase(
		os.path.normpath(str(right))
	)


def _normalize_relative_path(raw_path: str) -> str:
	if not raw_path or "\\" in raw_path or "\0" in raw_path or len(raw_path) > 512:
		raise GateInputError("credential_gate.path_invalid")
	if any(ord(character) < 32 or ord(character) == 127 for character in raw_path):
		raise GateInputError("credential_gate.path_invalid")
	raw_parts = raw_path.split("/")
	if any(part in {"", ".", ".."} or len(part) > 180 for part in raw_parts):
		raise GateInputError("credential_gate.path_invalid")
	path = PurePosixPath(raw_path)
	if path.is_absolute() or not path.parts:
		raise GateInputError("credential_gate.path_invalid")
	if ":" in path.parts[0]:
		raise GateInputError("credential_gate.path_invalid")
	return path.as_posix()


def _controlled_relative_path(root: Path, raw_path: str) -> Path:
	normalized = _normalize_relative_path(raw_path)
	candidate = absolute_lexical_path(root / normalized)
	if not path_is_inside_lexical(root, candidate) or path_has_reparse_component(candidate):
		raise GateInputError("credential_gate.path_boundary_violation")
	return candidate


def _safe_report_path(raw_path: str, fallback: str) -> str:
	try:
		normalized = _normalize_relative_path(raw_path)
	except GateInputError:
		return fallback
	if (
		len(normalized) > 240
		or SAFE_REPORT_PATH_RE.fullmatch(normalized) is None
		or _contains_credential_shape(normalized)
	):
		return fallback
	return normalized


def _sanitize_issue_path(raw_path: str) -> str:
	if (
		not raw_path
		or len(raw_path) > 240
		or SAFE_REPORT_PATH_RE.fullmatch(raw_path) is None
		or _contains_credential_shape(raw_path)
	):
		return "gate-entry"
	path_parts = raw_path.replace("!/", "/").split("/")
	if any(part in {"", ".", ".."} for part in path_parts):
		return "gate-entry"
	return raw_path


def _compose_report_path(prefix: str, child: str, fallback: str) -> str:
	candidate = f"{prefix}!/{child}"
	sanitized = _sanitize_issue_path(candidate)
	return fallback if sanitized == "gate-entry" else sanitized


def _contains_credential_shape(value: str) -> bool:
	return (
		any(pattern.search(value) is not None for _rule_id, pattern in KNOWN_TOKEN_PATTERNS)
		or URI_CREDENTIAL_RE.search(value) is not None
		or any(
			_looks_like_credential_value(match.group("value"))
			for match in PATH_ASSIGNMENT_CREDENTIAL_RE.finditer(value)
		)
	)


def _file_kind(path: str) -> str:
	lower_path = path.lower()
	suffix = PurePosixPath(lower_path).suffix
	if suffix in ZIP_SUFFIXES:
		return "zip"
	if suffix in UNSUPPORTED_ARCHIVE_SUFFIXES:
		return "unsupported_archive"
	if suffix in TEXT_SUFFIXES:
		return "text"
	if suffix in BINARY_SUFFIXES:
		return "binary"
	return "unknown"


def _metadata_is_link_or_reparse(metadata: os.stat_result) -> bool:
	return (
		stat.S_ISLNK(metadata.st_mode)
		or bool(
			int(getattr(metadata, "st_file_attributes", 0))
			& int(getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x0400))
		)
	)


def _controlled_absolute_path(path: Path, containment_root: Path) -> tuple[Path, Path]:
	absolute_root = absolute_lexical_path(containment_root)
	absolute_path = absolute_lexical_path(path)
	if not path_is_inside_lexical(absolute_root, absolute_path):
		raise GateInputError("credential_gate.path_boundary_violation")
	return absolute_path, absolute_root


def _snapshot_directory_chain(
	containment_root: Path,
	directory: Path,
) -> tuple[tuple[Path, os.stat_result], ...]:
	absolute_directory, absolute_root = _controlled_absolute_path(
		directory,
		containment_root,
	)
	try:
		relative = absolute_directory.relative_to(absolute_root)
	except ValueError:
		raise GateInputError("credential_gate.path_boundary_violation") from None
	current = absolute_root
	components = [current]
	for component in relative.parts:
		current = current / component
		components.append(current)
	snapshot: list[tuple[Path, os.stat_result]] = []
	for component in components:
		try:
			metadata = os.lstat(component)
		except OSError:
			raise GateInputError("credential_gate.file_unavailable") from None
		if (
			not stat.S_ISDIR(metadata.st_mode)
			or _metadata_is_link_or_reparse(metadata)
		):
			raise GateInputError("credential_gate.path_boundary_violation")
		snapshot.append((component, metadata))
	return tuple(snapshot)


def _snapshot_full_directory_chain(
	directory: Path,
) -> tuple[tuple[Path, os.stat_result], ...]:
	absolute_directory = absolute_lexical_path(directory)
	if not absolute_directory.anchor:
		raise GateInputError("credential_gate.path_boundary_violation")
	return _snapshot_directory_chain(
		Path(absolute_directory.anchor),
		absolute_directory,
	)


def _directory_binding_is_current(
	directory: Path,
	binding: tuple[tuple[Path, os.stat_result], ...],
) -> bool:
	try:
		current = _snapshot_full_directory_chain(directory)
	except GateInputError:
		return False
	return _same_directory_chain_identity(binding, current)


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


def _same_regular_file_identity(
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
		and before.st_mode == after.st_mode
		and before.st_size == after.st_size
		and before.st_mtime_ns == after.st_mtime_ns
		and not _metadata_is_link_or_reparse(before)
		and not _metadata_is_link_or_reparse(after)
	)


def _regular_file_size(
	path: Path,
	*,
	containment_root: Path | None = None,
) -> int:
	absolute_path, absolute_root = _controlled_absolute_path(
		path,
		containment_root or path.parent,
	)
	chain_before = _snapshot_directory_chain(
		absolute_root,
		absolute_path.parent,
	)
	try:
		metadata = os.lstat(absolute_path)
	except OSError:
		raise GateInputError("credential_gate.file_unavailable") from None
	if (
		not stat.S_ISREG(metadata.st_mode)
		or _metadata_is_link_or_reparse(metadata)
	):
		raise GateInputError("credential_gate.file_not_regular")
	try:
		after = os.lstat(absolute_path)
	except OSError:
		raise GateInputError("credential_gate.file_changed") from None
	chain_after = _snapshot_directory_chain(
		absolute_root,
		absolute_path.parent,
	)
	if (
		not _same_regular_file_identity(metadata, after)
		or not _same_directory_chain_identity(chain_before, chain_after)
	):
		raise GateInputError("credential_gate.file_changed")
	return metadata.st_size


@contextmanager
def _open_regular_file(
	path: Path,
	max_bytes: int,
	budget_rule_id: str,
	*,
	containment_root: Path | None = None,
	work_budget: WorkBudget | None = None,
	limits: GateLimits | None = None,
) -> Iterator[tuple[BinaryIO, int]]:
	if (work_budget is None) != (limits is None):
		raise GateInputError("credential_gate.internal_error")
	absolute_path, absolute_root = _controlled_absolute_path(
		path,
		containment_root or path.parent,
	)
	if path_has_reparse_component(absolute_path):
		raise GateInputError("credential_gate.path_boundary_violation")
	chain_before = _snapshot_directory_chain(
		absolute_root,
		absolute_path.parent,
	)
	try:
		path_before = os.lstat(absolute_path)
	except OSError:
		raise GateInputError("credential_gate.file_unavailable") from None
	if (
		not stat.S_ISREG(path_before.st_mode)
		or _metadata_is_link_or_reparse(path_before)
	):
		raise GateInputError("credential_gate.file_not_regular")
	if path_before.st_size > max_bytes:
		raise GateInputError(budget_rule_id)
	flags = (
		os.O_RDONLY
		| int(getattr(os, "O_BINARY", 0))
		| int(getattr(os, "O_CLOEXEC", 0))
		| int(getattr(os, "O_NOFOLLOW", 0))
	)
	try:
		file_descriptor = os.open(absolute_path, flags)
	except OSError:
		raise GateInputError("credential_gate.file_unavailable") from None
	handle: BinaryIO | None = None
	try:
		opened_before = os.fstat(file_descriptor)
		if not _same_regular_file_identity(path_before, opened_before):
			raise GateInputError("credential_gate.file_changed")
		handle = os.fdopen(
			file_descriptor,
			"rb",
			buffering=0,
			closefd=True,
		)
		file_descriptor = -1
		read_handle: BinaryIO = handle
		if work_budget is not None and limits is not None:
			read_handle = _BudgetedBinaryReader(
				handle,
				opened_before.st_size,
				work_budget,
				limits,
			)
		try:
			yield read_handle, opened_before.st_size
		finally:
			opened_after = os.fstat(handle.fileno())
			try:
				path_after = os.lstat(absolute_path)
			except OSError:
				raise GateInputError("credential_gate.file_changed") from None
			chain_after = _snapshot_directory_chain(
				absolute_root,
				absolute_path.parent,
			)
			if (
				path_has_reparse_component(absolute_path)
				or not _same_regular_file_identity(
					path_before,
					opened_before,
				)
				or not _same_regular_file_identity(
					opened_before,
					opened_after,
				)
				or not _same_regular_file_identity(
					opened_after,
					path_after,
				)
				or not _same_directory_chain_identity(
					chain_before,
					chain_after,
				)
			):
				raise GateInputError("credential_gate.file_changed")
	finally:
		if handle is not None:
			handle.close()
		elif file_descriptor >= 0:
			os.close(file_descriptor)


def _read_regular_file(
	path: Path,
	max_bytes: int,
	budget_rule_id: str,
	*,
	containment_root: Path | None = None,
	work_budget: WorkBudget | None = None,
	limits: GateLimits | None = None,
) -> bytes:
	with _open_regular_file(
		path,
		max_bytes,
		budget_rule_id,
		containment_root=containment_root,
		work_budget=work_budget,
		limits=limits,
	) as (handle, expected_size):
		payload = _read_bounded_stream(handle, expected_size, max_bytes, 64 * 1024)
	return payload


def _read_bounded_stream(
	handle: BinaryIO,
	expected_size: int,
	max_bytes: int,
	chunk_bytes: int,
) -> bytes:
	payload = bytearray()
	while True:
		chunk = handle.read(max(1, min(chunk_bytes, max_bytes - len(payload) + 1)))
		if not chunk:
			break
		payload.extend(chunk)
		if len(payload) > max_bytes or len(payload) > expected_size:
			raise GateInputError("credential_gate.controlled_read_budget_exceeded")
	if len(payload) != expected_size:
		raise GateInputError("credential_gate.controlled_read_incomplete")
	return bytes(payload)


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


@dataclass(frozen=True)
class _SnapshotTargetBinding:
	path: Path
	file_descriptor: int
	opened_metadata: os.stat_result
	parent_descriptor: int = -1
	leaf_name: str = ""


class _SnapshotRootBinding:
	"""Pin a private snapshot root and create every target below pinned parents."""

	def __init__(self, snapshot_root: Path) -> None:
		self.root = absolute_lexical_path(snapshot_root)
		self._closed = False
		self._root_chain = _snapshot_full_directory_chain(self.root)
		self._posix_directories: dict[tuple[str, ...], int] = {}
		self._windows_directories: dict[str, int] = {}
		if os.name == "nt":
			self._initialize_windows()
			return
		if (
			os.open not in os.supports_dir_fd
			or os.mkdir not in os.supports_dir_fd
			or os.stat not in os.supports_dir_fd
		):
			raise GateInputError("credential_gate.snapshot_boundary_invalid")
		self._initialize_posix()

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
		for _path, handle in reversed(tuple(self._windows_directories.items())):
			_windows_close_handle(handle)
		self._windows_directories.clear()

	def create_target(self, path: Path) -> _SnapshotTargetBinding:
		if self._closed:
			raise GateInputError("credential_gate.snapshot_boundary_invalid")
		absolute_path, _absolute_root = _controlled_absolute_path(path, self.root)
		if absolute_path == self.root or not absolute_path.name:
			raise GateInputError("credential_gate.release_snapshot_failed")
		if os.name == "nt":
			return self._create_windows_target(absolute_path)
		return self._create_posix_target(absolute_path)

	def verify_target(
		self,
		target: _SnapshotTargetBinding,
		opened_after: os.stat_result,
	) -> None:
		if not _same_regular_object_identity(
			target.opened_metadata,
			opened_after,
		):
			raise GateInputError("credential_gate.snapshot_boundary_invalid")
		if os.name == "nt":
			self._verify_windows_directories()
			try:
				path_after = os.lstat(target.path)
			except OSError:
				raise GateInputError(
					"credential_gate.snapshot_boundary_invalid"
				) from None
		else:
			try:
				path_after = os.stat(
					target.leaf_name,
					dir_fd=target.parent_descriptor,
					follow_symlinks=False,
				)
			except OSError:
				raise GateInputError(
					"credential_gate.snapshot_boundary_invalid"
				) from None
		if (
			not _same_regular_file_identity(opened_after, path_after)
			or not _directory_binding_is_current(self.root, self._root_chain)
			or path_has_reparse_component(target.path)
		):
			raise GateInputError("credential_gate.snapshot_boundary_invalid")

	def _initialize_posix(self) -> None:
		flags = (
			os.O_RDONLY
			| int(getattr(os, "O_DIRECTORY", 0))
			| int(getattr(os, "O_CLOEXEC", 0))
			| int(getattr(os, "O_NOFOLLOW", 0))
		)
		try:
			before = os.lstat(self.root)
			descriptor = os.open(self.root, flags)
			opened = os.fstat(descriptor)
		except OSError:
			raise GateInputError(
				"credential_gate.snapshot_boundary_invalid"
			) from None
		if (
			not stat.S_ISDIR(opened.st_mode)
			or not _same_directory_identity(before, opened)
		):
			os.close(descriptor)
			raise GateInputError("credential_gate.snapshot_boundary_invalid")
		self._posix_directories[()] = descriptor

	def _ensure_posix_directory(self, parts: tuple[str, ...]) -> int:
		current_key: tuple[str, ...] = ()
		for component in parts:
			next_key = (*current_key, component)
			if next_key in self._posix_directories:
				current_key = next_key
				continue
			parent_descriptor = self._posix_directories[current_key]
			flags = (
				os.O_RDONLY
				| int(getattr(os, "O_DIRECTORY", 0))
				| int(getattr(os, "O_CLOEXEC", 0))
				| int(getattr(os, "O_NOFOLLOW", 0))
			)
			try:
				descriptor = os.open(
					component,
					flags,
					dir_fd=parent_descriptor,
				)
			except FileNotFoundError:
				try:
					os.mkdir(component, 0o700, dir_fd=parent_descriptor)
					descriptor = os.open(
						component,
						flags,
						dir_fd=parent_descriptor,
					)
				except OSError:
					raise GateInputError(
						"credential_gate.snapshot_boundary_invalid"
					) from None
			except OSError:
				raise GateInputError(
					"credential_gate.snapshot_boundary_invalid"
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
				raise GateInputError(
					"credential_gate.snapshot_boundary_invalid"
				) from None
			if (
				not stat.S_ISDIR(opened.st_mode)
				or not _same_directory_identity(opened, path_metadata)
			):
				os.close(descriptor)
				raise GateInputError("credential_gate.snapshot_boundary_invalid")
			self._posix_directories[next_key] = descriptor
			current_key = next_key
		return self._posix_directories[current_key]

	def _create_posix_target(self, path: Path) -> _SnapshotTargetBinding:
		relative = path.relative_to(self.root)
		parent_descriptor = self._ensure_posix_directory(
			tuple(relative.parts[:-1])
		)
		leaf_name = relative.parts[-1]
		flags = (
			os.O_WRONLY
			| os.O_CREAT
			| os.O_EXCL
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
			raise GateInputError(
				"credential_gate.release_snapshot_failed"
			) from None
		if (
			not stat.S_ISREG(opened.st_mode)
			or not _same_regular_object_identity(opened, path_metadata)
		):
			os.close(descriptor)
			raise GateInputError("credential_gate.snapshot_boundary_invalid")
		return _SnapshotTargetBinding(
			path=path,
			file_descriptor=descriptor,
			opened_metadata=opened,
			parent_descriptor=parent_descriptor,
			leaf_name=leaf_name,
		)

	def _initialize_windows(self) -> None:
		try:
			for directory in _full_directory_paths(self.root):
				handle, identity = _windows_open_pinned_directory(directory)
				self._windows_directories[
					os.path.normcase(os.path.normpath(str(directory)))
				] = handle
				if int(identity.st_ino) != _windows_handle_file_index(handle):
					raise GateInputError(
						"credential_gate.snapshot_boundary_invalid"
					)
		except Exception:
			self.close()
			raise

	def _ensure_windows_directory(self, directory: Path) -> int:
		absolute_directory, _absolute_root = _controlled_absolute_path(
			directory,
			self.root,
		)
		self._verify_windows_directories()
		current = self.root
		for component in absolute_directory.relative_to(self.root).parts:
			current = current / component
			key = os.path.normcase(os.path.normpath(str(current)))
			if key in self._windows_directories:
				continue
			try:
				os.mkdir(current, 0o700)
			except FileExistsError:
				pass
			except OSError:
				raise GateInputError(
					"credential_gate.snapshot_boundary_invalid"
				) from None
			handle, _identity = _windows_open_pinned_directory(current)
			self._windows_directories[key] = handle
		self._verify_windows_directories()
		directory_key = os.path.normcase(
			os.path.normpath(str(absolute_directory))
		)
		try:
			return self._windows_directories[directory_key]
		except KeyError:
			raise GateInputError(
				"credential_gate.snapshot_boundary_invalid"
			) from None

	def _create_windows_target(self, path: Path) -> _SnapshotTargetBinding:
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
				os.O_WRONLY | int(getattr(os, "O_BINARY", 0)),
			)
			handle = -1
			opened = os.fstat(descriptor)
		except (OSError, ValueError):
			if handle >= 0:
				_windows_close_handle(handle)
			raise GateInputError(
				"credential_gate.release_snapshot_failed"
			) from None
		if (
			not stat.S_ISREG(opened.st_mode)
			or _metadata_is_link_or_reparse(opened)
		):
			os.close(descriptor)
			raise GateInputError("credential_gate.snapshot_boundary_invalid")
		return _SnapshotTargetBinding(
			path=path,
			file_descriptor=descriptor,
			opened_metadata=opened,
		)

	def _verify_windows_directories(self) -> None:
		for raw_path, handle in self._windows_directories.items():
			path = Path(raw_path)
			if (
				not _windows_handle_matches_path(handle, path, expect_directory=True)
			):
				raise GateInputError("credential_gate.snapshot_boundary_invalid")


def _full_directory_paths(directory: Path) -> tuple[Path, ...]:
	absolute_directory = absolute_lexical_path(directory)
	if not absolute_directory.anchor:
		raise GateInputError("credential_gate.snapshot_boundary_invalid")
	current = Path(absolute_directory.anchor)
	result = [current]
	for component in absolute_directory.relative_to(current).parts:
		current = current / component
		result.append(current)
	return tuple(result)


def _windows_open_pinned_directory(
	path: Path,
) -> tuple[int, os.stat_result]:
	if os.name != "nt":
		raise GateInputError("credential_gate.snapshot_boundary_invalid")
	try:
		before = os.lstat(path)
	except OSError:
		raise GateInputError("credential_gate.snapshot_boundary_invalid") from None
	if (
		not stat.S_ISDIR(before.st_mode)
		or _metadata_is_link_or_reparse(before)
	):
		raise GateInputError("credential_gate.snapshot_boundary_invalid")
	handle = _windows_create_file_handle(
		path,
		desired_access=0x00000080,
		share_mode=0x00000001 | 0x00000002,
		creation_disposition=3,
		flags_and_attributes=0x02000000 | 0x00200000,
	)
	if handle < 0:
		raise GateInputError("credential_gate.snapshot_boundary_invalid")
	try:
		after = os.lstat(path)
	except OSError:
		_windows_close_handle(handle)
		raise GateInputError("credential_gate.snapshot_boundary_invalid") from None
	if (
		not _same_directory_identity(before, after)
		or not _windows_handle_matches_path(handle, path, expect_directory=True)
		or int(after.st_ino) != _windows_handle_file_index(handle)
	):
		_windows_close_handle(handle)
		raise GateInputError("credential_gate.snapshot_boundary_invalid")
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
		raise GateInputError("credential_gate.snapshot_boundary_invalid")

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
		raise GateInputError("credential_gate.snapshot_boundary_invalid")
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
	status = ntdll.NtCreateFile(
		ctypes.byref(file_handle),
		0x40000000 | 0x00000080 | 0x00100000,
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
	if status < 0 or handle < 0:
		if handle >= 0:
			_windows_close_handle(handle)
		raise GateInputError("credential_gate.release_snapshot_failed")
	if not _windows_handle_matches_path(
		handle,
		expected_path,
		expect_directory=False,
	):
		_windows_close_handle(handle)
		raise GateInputError("credential_gate.snapshot_boundary_invalid")
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
		str(absolute_lexical_path(path)),
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
	return _paths_identical(
		absolute_lexical_path(Path(final_path)),
		absolute_lexical_path(path),
	)


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
def _open_snapshot_target(
	path: Path,
	snapshot_binding: _SnapshotRootBinding,
	work_budget: WorkBudget,
	limits: GateLimits,
) -> Iterator[BinaryIO]:
	target = snapshot_binding.create_target(path)
	file_descriptor = target.file_descriptor
	handle: BinaryIO | None = None
	try:
		handle = os.fdopen(
			file_descriptor,
			"wb",
			buffering=0,
			closefd=True,
		)
		file_descriptor = -1
		writer = _BudgetedBinaryWriter(handle, work_budget, limits)
		try:
			yield writer
		finally:
			try:
				writer.flush()
				opened_after = os.fstat(handle.fileno())
			except OSError:
				raise GateInputError(
					"credential_gate.release_snapshot_failed"
				) from None
			snapshot_binding.verify_target(target, opened_after)
	finally:
		if handle is not None:
			handle.close()
		elif file_descriptor >= 0:
			os.close(file_descriptor)


def _write_all_stream(handle: BinaryIO, payload: bytes) -> None:
	offset = 0
	while offset < len(payload):
		written = handle.write(payload[offset:])
		if written is None or written <= 0:
			raise GateInputError("credential_gate.release_snapshot_failed")
		offset += written


def _scan_path(
	path: Path,
	report_path: str,
	file_kind: str,
	limits: GateLimits,
	collector: IssueCollector,
	stats: ScanStats,
	work_budget: WorkBudget,
	*,
	containment_root: Path,
	allow_suppression: bool,
	count_source_bytes: bool = False,
	expected_sha256: str = "",
) -> None:
	_scan_sensitive_file_name(report_path, collector)
	if collector.exhausted:
		return
	try:
		open_byte_limit = limits.max_artifact_bytes
		if count_source_bytes and file_kind in {"text", "unknown"}:
			open_byte_limit = limits.max_source_file_bytes
		with _open_regular_file(
			path,
			open_byte_limit,
			"credential_gate.source_file_budget_exceeded"
			if count_source_bytes
			else "credential_gate.release_artifact_budget_exceeded",
			containment_root=containment_root,
			work_budget=work_budget,
			limits=limits,
		) as (handle, expected_size):
			if expected_sha256:
				if _sha256_handle(handle, expected_size, limits) != expected_sha256:
					raise GateInputError("credential_gate.release_artifact_hash_mismatch")
			prefix = _read_stream_prefix(handle, 4)
			has_zip_eocd, eocd_probe_bytes = _stream_has_zip_eocd(
				handle,
				expected_size,
			)
			is_archive = (
				file_kind == "zip"
				or _is_zip_magic(prefix)
				or has_zip_eocd
			)
			if count_source_bytes:
				work_budget.consume_source_bytes(
					len(prefix) + eocd_probe_bytes,
					limits,
				)
				if is_archive or file_kind != "binary":
					work_budget.consume_source_bytes(expected_size, limits)
			if is_archive:
				zip_preflight = _preflight_zip_stream(handle, expected_size, limits)
				with zipfile.ZipFile(handle, "r") as archive:
					_scan_zip(
						archive,
						handle,
						report_path,
						0,
						zip_preflight,
						limits,
						collector,
						stats,
						work_budget,
						allow_suppression=allow_suppression,
					)
				_verify_expected_sha256(
					handle,
					expected_size,
					expected_sha256,
					limits,
				)
				return
			if file_kind == "unsupported_archive":
				raise GateInputError("credential_gate.archive_format_unsupported")
			if file_kind == "binary":
				stats.skipped_binary_count += 1
				_verify_expected_sha256(
					handle,
					expected_size,
					expected_sha256,
					limits,
				)
				return
			if expected_size > limits.max_text_file_bytes:
				raise GateInputError("credential_gate.text_file_budget_exceeded")
			work_budget.consume_text_bytes(expected_size, limits)
			handle.seek(0)
			payload = _read_bounded_stream(
				handle,
				expected_size,
				limits.max_text_file_bytes,
				limits.read_chunk_bytes,
			)
			_scan_payload(
				payload,
				report_path,
				file_kind,
				collector,
				stats,
				allow_suppression=allow_suppression,
			)
			_verify_expected_sha256(
				handle,
				expected_size,
				expected_sha256,
				limits,
			)
	except (GateInputError, OSError, zipfile.BadZipFile, RuntimeError) as error:
		rule_id = (
			error.rule_id
			if isinstance(error, GateInputError)
			else "credential_gate.archive_invalid"
		)
		collector.add(rule_id, report_path)
	except Exception:
		collector.add("credential_gate.scan_failed", report_path)


def _scan_zip(
	archive: zipfile.ZipFile,
	archive_stream: BinaryIO,
	report_prefix: str,
	depth: int,
	preflight: ZipPreflight,
	limits: GateLimits,
	collector: IssueCollector,
	stats: ScanStats,
	work_budget: WorkBudget,
	*,
	allow_suppression: bool,
) -> None:
	stats.archive_count += 1
	try:
		entries = archive.infolist()
	except (OSError, zipfile.BadZipFile, RuntimeError):
		collector.add("credential_gate.archive_invalid", report_prefix)
		return
	if len(entries) != preflight.entry_count:
		collector.add("credential_gate.archive_entry_count_mismatch", report_prefix)
		return
	if len(entries) > limits.max_zip_entries:
		collector.add("credential_gate.archive_entry_count_exceeded", report_prefix)
		return
	try:
		work_budget.consume_archive(
			len(entries),
			preflight.central_directory_bytes,
			limits,
		)
	except GateInputError as error:
		collector.add(error.rule_id, report_prefix)
		return

	comment_scan_bytes = 0
	archive_comment_path = _compose_report_path(
		report_prefix,
		"archive-comment",
		"archive-comment",
	)
	try:
		comment_scan_bytes = _scan_zip_comment(
			archive.comment,
			archive_comment_path,
			comment_scan_bytes,
			limits,
			collector,
			stats,
			work_budget,
			allow_suppression=allow_suppression,
		)
	except GateInputError as error:
		collector.add(error.rule_id, archive_comment_path)
		return

	seen_paths: set[str] = set()
	total_expanded = 0
	validated: list[tuple[zipfile.ZipInfo, str, str, int]] = []
	local_ranges: list[tuple[int, int]] = []
	preflight_failed = bool(collector.issues)
	try:
		parsed_central_directory_bytes = sum(
			ZIP_CENTRAL_DIRECTORY_STRUCT.size
			+ len(_encoded_zip_entry_name(entry))
			+ len(entry.extra)
			+ len(entry.comment)
			for entry in entries
		)
		if (
			parsed_central_directory_bytes
			!= preflight.central_directory_bytes
		):
			raise GateInputError("credential_gate.archive_layout_invalid")
	except (GateInputError, UnicodeError):
		collector.add("credential_gate.archive_layout_invalid", report_prefix)
		return
	for index, entry in enumerate(entries):
		entry_fallback = f"archive-entry-{index + 1}"
		entry_report_path = entry_fallback
		try:
			entry_name = (
				entry.filename[:-1]
				if entry.is_dir() and entry.filename.endswith("/")
				else entry.filename
			)
			normalized = _normalize_relative_path(entry_name)
			entry_report_name = _safe_report_path(normalized, f"entry-{index + 1}")
			entry_report_path = _compose_report_path(
				report_prefix,
				entry_report_name,
				entry_fallback,
			)
			if _contains_credential_shape(normalized):
				preflight_failed = True
				collector.add(
					"credential.sensitive_path_value",
					entry_report_path,
				)
			entry_comment_path = _compose_report_path(
				entry_report_path,
				"comment",
				f"entry-comment-{index + 1}",
			)
			comment_scan_bytes = _scan_zip_comment(
				entry.comment,
				entry_comment_path,
				comment_scan_bytes,
				limits,
				collector,
				stats,
				work_budget,
				allow_suppression=allow_suppression,
			)
			central_extra_path = _compose_report_path(
				entry_report_path,
				"extra",
				f"entry-extra-{index + 1}",
			)
			_scan_zip_ascii_metadata(
				entry.extra,
				central_extra_path,
				collector,
				stats,
				work_budget,
				limits,
				allow_suppression=allow_suppression,
			)
			(
				local_name,
				local_extra,
				local_range_start,
				local_range_end,
				local_data_offset,
			) = _read_zip_local_metadata(
				archive_stream,
				entry,
				preflight,
			)
			local_ranges.append((local_range_start, local_range_end))
			local_name_path = _compose_report_path(
				entry_report_path,
				"local-name",
				f"entry-local-name-{index + 1}",
			)
			_scan_zip_ascii_metadata(
				local_name,
				local_name_path,
				collector,
				stats,
				work_budget,
				limits,
				allow_suppression=allow_suppression,
			)
			local_extra_path = _compose_report_path(
				entry_report_path,
				"local-extra",
				f"entry-local-extra-{index + 1}",
			)
			_scan_zip_ascii_metadata(
				local_extra,
				local_extra_path,
				collector,
				stats,
				work_budget,
				limits,
				allow_suppression=allow_suppression,
			)
			if collector.issues:
				preflight_failed = True
			identity = normalized.casefold()
			if identity in seen_paths:
				raise GateInputError("credential_gate.archive_entry_duplicate")
			seen_paths.add(identity)
			if entry.flag_bits & 0x1:
				raise GateInputError("credential_gate.archive_encrypted_entry")
			if entry.compress_type not in ALLOWED_ZIP_COMPRESSION:
				raise GateInputError("credential_gate.archive_compression_unsupported")
			unix_mode = (entry.external_attr >> 16) & 0xFFFF
			file_type = stat.S_IFMT(unix_mode)
			if file_type not in {0, stat.S_IFREG, stat.S_IFDIR}:
				raise GateInputError("credential_gate.archive_special_entry")
			if entry.is_dir():
				if file_type == stat.S_IFREG or entry.file_size != 0 or entry.compress_size != 0:
					raise GateInputError("credential_gate.archive_metadata_invalid")
				continue
			if file_type == stat.S_IFDIR:
				raise GateInputError("credential_gate.archive_metadata_invalid")
			if entry.file_size < 0 or entry.compress_size < 0:
				raise GateInputError("credential_gate.archive_metadata_invalid")
			if entry.file_size > limits.max_zip_entry_bytes:
				raise GateInputError("credential_gate.archive_entry_budget_exceeded")
			if entry.compress_size > limits.max_zip_entry_bytes:
				raise GateInputError("credential_gate.archive_entry_budget_exceeded")
			total_expanded += entry.file_size
			if total_expanded > limits.max_zip_expanded_bytes:
				raise GateInputError("credential_gate.archive_expanded_budget_exceeded")
			if (
				entry.file_size >= limits.compression_ratio_minimum_bytes
				and entry.file_size / max(1, entry.compress_size)
				> limits.max_zip_compression_ratio
			):
				raise GateInputError("credential_gate.archive_compression_ratio_exceeded")
			validated.append((
				entry,
				entry_report_path,
				_file_kind(normalized),
				local_data_offset,
			))
		except GateInputError as error:
			preflight_failed = True
			collector.add(error.rule_id, entry_report_path)
		if collector.exhausted:
			preflight_failed = True
			break
		if work_budget.hard_exhausted:
			preflight_failed = True
			break

	try:
		unreferenced_ranges = _unreferenced_zip_ranges(
			local_ranges,
			preflight.central_directory_offset,
		)
		unreferenced_bytes = sum(
			range_end - range_start
			for range_start, range_end in unreferenced_ranges
		)
		if unreferenced_bytes > limits.max_zip_leading_bytes:
			raise GateInputError(
				"credential_gate.archive_unreferenced_data_budget_exceeded"
			)
		total_expanded += unreferenced_bytes
		if total_expanded > limits.max_zip_expanded_bytes:
			raise GateInputError(
				"credential_gate.archive_expanded_budget_exceeded"
			)
		work_budget.consume_expanded_bytes(total_expanded, limits)
	except GateInputError as error:
		preflight_failed = True
		collector.add(error.rule_id, report_prefix)
	if preflight_failed:
		return

	for entry, entry_report_path, _file_kind_value, data_offset in validated:
		try:
			_validate_zip_compressed_record(
				archive_stream,
				entry,
				data_offset,
				preflight,
				limits,
			)
		except GateInputError as error:
			collector.add(error.rule_id, entry_report_path)
			return

	for range_index, (range_start, range_end) in enumerate(
		unreferenced_ranges,
		start=1,
	):
		is_leading_range = range_start == 0
		report_name = (
			"leading-data"
			if is_leading_range
			else f"unreferenced-data-{range_index}"
		)
		range_report_path = _compose_report_path(
			report_prefix,
			report_name,
			"archive-leading-data"
			if is_leading_range
			else f"archive-unreferenced-data-{range_index}",
		)
		try:
			raw_payload = _read_archive_range(
				archive_stream,
				range_start,
				range_end - range_start,
				preflight.archive_size,
			)
			_scan_zip_ascii_metadata(
				raw_payload,
				range_report_path,
				collector,
				stats,
				work_budget,
				limits,
				allow_suppression=allow_suppression,
			)
		except GateInputError as error:
			collector.add(error.rule_id, range_report_path)
			return
		if collector.exhausted or work_budget.hard_exhausted:
			return
	if collector.issues:
		return

	stats.archive_entry_count += len(validated)
	stats.expanded_bytes += total_expanded
	for entry, entry_report_path, file_kind, _data_offset in validated:
		_scan_sensitive_file_name(entry_report_path, collector)
		if collector.exhausted:
			break
		try:
			payload = _read_zip_entry(
				archive,
				entry,
				limits,
				work_budget,
			)
		except (GateInputError, OSError, zipfile.BadZipFile, RuntimeError) as error:
			rule_id = (
				error.rule_id
				if isinstance(error, GateInputError)
				else "credential_gate.archive_read_failed"
			)
			collector.add(rule_id, entry_report_path)
			continue
		nested_stream = _BudgetedBinaryReader(
			io.BytesIO(payload),
			len(payload),
			work_budget,
			limits,
		)
		is_archive = (
			file_kind == "zip"
			or _is_zip_magic(payload[:4])
			or _stream_has_zip_eocd(nested_stream, len(payload))[0]
		)
		if is_archive:
			if depth >= limits.max_nested_zip_depth:
				collector.add("credential_gate.archive_nesting_exceeded", entry_report_path)
				continue
			try:
				nested_preflight = _preflight_zip_stream(
					nested_stream,
					len(payload),
					limits,
				)
				with zipfile.ZipFile(nested_stream, "r") as nested_archive:
					_scan_zip(
						nested_archive,
						nested_stream,
						entry_report_path,
						depth + 1,
						nested_preflight,
						limits,
						collector,
						stats,
						work_budget,
						allow_suppression=allow_suppression,
					)
			except (GateInputError, OSError, zipfile.BadZipFile, RuntimeError) as error:
				rule_id = (
					error.rule_id
					if isinstance(error, GateInputError)
					else "credential_gate.archive_invalid"
				)
				collector.add(rule_id, entry_report_path)
			if work_budget.hard_exhausted:
				return
			continue
		if file_kind == "unsupported_archive":
			collector.add("credential_gate.archive_format_unsupported", entry_report_path)
			continue
		if file_kind == "binary":
			stats.skipped_binary_count += 1
			continue
		if entry.file_size > limits.max_text_file_bytes:
			collector.add("credential_gate.text_file_budget_exceeded", entry_report_path)
			continue
		try:
			work_budget.consume_text_bytes(len(payload), limits)
		except GateInputError as error:
			collector.add(error.rule_id, entry_report_path)
			break
		_scan_payload(
			payload,
			entry_report_path,
			file_kind,
			collector,
			stats,
			allow_suppression=allow_suppression,
		)
		if collector.exhausted or work_budget.hard_exhausted:
			break


def _scan_zip_comment(
	payload: bytes,
	report_path: str,
	previous_scan_bytes: int,
	limits: GateLimits,
	collector: IssueCollector,
	stats: ScanStats,
	work_budget: WorkBudget,
	*,
	allow_suppression: bool,
) -> int:
	if not payload:
		return previous_scan_bytes
	if len(payload) > limits.max_zip_comment_bytes:
		raise GateInputError("credential_gate.archive_comment_budget_exceeded")
	scan_bytes = previous_scan_bytes + len(payload)
	if scan_bytes > limits.max_zip_comment_scan_bytes:
		raise GateInputError("credential_gate.archive_comment_budget_exceeded")
	work_budget.consume_text_bytes(len(payload), limits)
	_scan_payload(
		payload,
		report_path,
		"text",
		collector,
		stats,
		allow_suppression=allow_suppression,
	)
	return scan_bytes


def _scan_zip_ascii_metadata(
	payload: bytes,
	report_path: str,
	collector: IssueCollector,
	stats: ScanStats,
	work_budget: WorkBudget,
	limits: GateLimits,
	*,
	allow_suppression: bool,
) -> None:
	"""Scan credential-shaped printable runs embedded in bounded ZIP metadata."""
	if not payload or collector.exhausted:
		return
	work_budget.consume_text_bytes(len(payload), limits)
	text = payload.translate(ASCII_METADATA_TRANSLATION).decode("ascii")
	stats.text_file_count += 1
	_scan_text(
		text,
		report_path,
		collector,
		allow_suppression=allow_suppression,
	)


def _read_archive_range(
	handle: BinaryIO,
	offset: int,
	size: int,
	archive_size: int,
) -> bytes:
	if (
		offset < 0
		or size < 0
		or archive_size < 0
		or offset > archive_size
		or size > archive_size - offset
	):
		raise GateInputError("credential_gate.archive_layout_invalid")
	try:
		handle.seek(offset)
		payload = handle.read(size)
	except (OSError, ValueError):
		raise GateInputError("credential_gate.archive_read_failed") from None
	if len(payload) != size:
		raise GateInputError("credential_gate.archive_read_failed")
	return payload


def _read_zip_local_metadata(
	handle: BinaryIO,
	entry: zipfile.ZipInfo,
	preflight: ZipPreflight,
) -> tuple[bytes, bytes, int, int, int]:
	try:
		header_offset = int(entry.header_offset)
	except (TypeError, ValueError, OverflowError):
		raise GateInputError("credential_gate.archive_metadata_invalid") from None
	header = _read_archive_range(
		handle,
		header_offset,
		ZIP_LOCAL_FILE_HEADER_STRUCT.size,
		preflight.archive_size,
	)
	try:
		fields = ZIP_LOCAL_FILE_HEADER_STRUCT.unpack(header)
	except struct.error:
		raise GateInputError("credential_gate.archive_metadata_invalid") from None
	if fields[0] != ZIP_LOCAL_FILE_HEADER_SIGNATURE:
		raise GateInputError("credential_gate.archive_layout_invalid")
	name_size = fields[-2]
	extra_size = fields[-1]
	metadata_size = name_size + extra_size
	metadata_offset = header_offset + ZIP_LOCAL_FILE_HEADER_STRUCT.size
	data_offset = metadata_offset + metadata_size
	data_end = data_offset + entry.compress_size
	if (
		header_offset < preflight.leading_bytes
		or metadata_offset > preflight.central_directory_offset
		or metadata_size > preflight.central_directory_offset - metadata_offset
		or entry.compress_size < 0
		or data_end > preflight.central_directory_offset
	):
		raise GateInputError("credential_gate.archive_layout_invalid")
	metadata = _read_archive_range(
		handle,
		metadata_offset,
		metadata_size,
		preflight.archive_size,
	)
	local_name = metadata[:name_size]
	if (
		local_name != _encoded_zip_entry_name(entry)
		or fields[2] != entry.flag_bits
		or fields[3] != entry.compress_type
	):
		raise GateInputError("credential_gate.archive_layout_invalid")
	if fields[2] & 0x08:
		if (
			fields[6] not in {0, entry.CRC}
			or fields[7] not in {0, entry.compress_size}
			or fields[8] not in {0, entry.file_size}
		):
			raise GateInputError("credential_gate.archive_layout_invalid")
	elif (
		fields[6] != entry.CRC
		or fields[7] != entry.compress_size
		or fields[8] != entry.file_size
	):
		raise GateInputError("credential_gate.archive_layout_invalid")
	return (
		local_name,
		metadata[name_size:],
		header_offset,
		data_end,
		data_offset,
	)


def _encoded_zip_entry_name(entry: zipfile.ZipInfo) -> bytes:
	raw_name = str(getattr(entry, "orig_filename", entry.filename))
	encoding = "utf-8" if entry.flag_bits & 0x800 else "cp437"
	try:
		return raw_name.encode(encoding, errors="strict")
	except UnicodeError:
		raise GateInputError("credential_gate.archive_metadata_invalid") from None


def _unreferenced_zip_ranges(
	local_ranges: list[tuple[int, int]],
	central_directory_offset: int,
) -> list[tuple[int, int]]:
	if central_directory_offset < 0:
		raise GateInputError("credential_gate.archive_layout_invalid")
	ranges: list[tuple[int, int]] = []
	cursor = 0
	for range_start, range_end in sorted(local_ranges):
		if (
			range_start < cursor
			or range_end < range_start
			or range_end > central_directory_offset
		):
			raise GateInputError("credential_gate.archive_layout_invalid")
		if range_start > cursor:
			ranges.append((cursor, range_start))
		cursor = range_end
	if cursor < central_directory_offset:
		ranges.append((cursor, central_directory_offset))
	elif cursor > central_directory_offset:
		raise GateInputError("credential_gate.archive_layout_invalid")
	return ranges


def _validate_zip_compressed_record(
	handle: BinaryIO,
	entry: zipfile.ZipInfo,
	data_offset: int,
	preflight: ZipPreflight,
	limits: GateLimits,
) -> None:
	if entry.compress_type == zipfile.ZIP_STORED:
		if entry.compress_size != entry.file_size:
			raise GateInputError("credential_gate.archive_metadata_invalid")
		return
	if entry.compress_type != zipfile.ZIP_DEFLATED:
		raise GateInputError("credential_gate.archive_compression_unsupported")
	compressed_payload = _read_archive_range(
		handle,
		data_offset,
		entry.compress_size,
		preflight.archive_size,
	)
	decompressor = zlib.decompressobj(-zlib.MAX_WBITS)
	pending = compressed_payload
	expanded_size = 0
	crc32 = 0
	try:
		while pending:
			before_size = len(pending)
			output_limit = max(
				1,
				min(
					limits.read_chunk_bytes,
					entry.file_size - expanded_size + 1,
				),
			)
			output = decompressor.decompress(pending, output_limit)
			expanded_size += len(output)
			crc32 = zlib.crc32(output, crc32)
			if (
				expanded_size > entry.file_size
				or decompressor.unused_data
			):
				raise GateInputError("credential_gate.archive_layout_invalid")
			pending = decompressor.unconsumed_tail
			if (
				pending
				and len(pending) >= before_size
				and not output
			):
				raise GateInputError("credential_gate.archive_layout_invalid")
		flushed = decompressor.flush()
	except zlib.error:
		raise GateInputError("credential_gate.archive_read_failed") from None
	expanded_size += len(flushed)
	crc32 = zlib.crc32(flushed, crc32)
	if (
		not decompressor.eof
		or decompressor.unused_data
		or decompressor.unconsumed_tail
		or expanded_size != entry.file_size
		or crc32 & 0xFFFFFFFF != entry.CRC
	):
		raise GateInputError("credential_gate.archive_layout_invalid")


def _read_stream_prefix(handle: BinaryIO, size: int) -> bytes:
	try:
		handle.seek(0)
		payload = handle.read(max(0, size))
		handle.seek(0)
	except (OSError, ValueError):
		raise GateInputError("credential_gate.controlled_read_incomplete") from None
	return payload


def _is_zip_magic(prefix: bytes) -> bool:
	return any(prefix.startswith(magic) for magic in ZIP_MAGIC_PREFIXES)


def _sha256_handle(
	handle: BinaryIO,
	expected_size: int,
	limits: GateLimits,
) -> str:
	digest = hashlib.sha256()
	read_bytes = 0
	try:
		handle.seek(0)
		while True:
			chunk = handle.read(limits.read_chunk_bytes)
			if not chunk:
				break
			read_bytes += len(chunk)
			if read_bytes > expected_size:
				raise GateInputError("credential_gate.controlled_read_budget_exceeded")
			digest.update(chunk)
		handle.seek(0)
	except (OSError, ValueError):
		raise GateInputError("credential_gate.controlled_read_incomplete") from None
	if read_bytes != expected_size:
		raise GateInputError("credential_gate.controlled_read_incomplete")
	return digest.hexdigest()


def _verify_expected_sha256(
	handle: BinaryIO,
	expected_size: int,
	expected_sha256: str,
	limits: GateLimits,
) -> None:
	if (
		expected_sha256
		and _sha256_handle(handle, expected_size, limits) != expected_sha256
	):
		raise GateInputError("credential_gate.release_artifact_hash_mismatch")


def _read_zip_entry(
	archive: zipfile.ZipFile,
	entry: zipfile.ZipInfo,
	limits: GateLimits,
	work_budget: WorkBudget,
) -> bytes:
	try:
		with archive.open(entry, "r") as handle:
			budgeted_handle = _BudgetedBinaryReader(
				handle,
				entry.file_size,
				work_budget,
				limits,
			)
			return _read_bounded_stream(
				budgeted_handle,
				entry.file_size,
				min(limits.max_zip_entry_bytes, entry.file_size),
				limits.read_chunk_bytes,
			)
	except GateInputError:
		raise
	except (OSError, RuntimeError, zipfile.BadZipFile):
		raise GateInputError("credential_gate.archive_read_failed") from None


def _stream_has_zip_eocd(
	handle: BinaryIO,
	archive_size: int,
) -> tuple[bool, int]:
	if archive_size < ZIP_EOCD_STRUCT.size:
		return False, 0
	tail_size = min(archive_size, ZIP_EOCD_STRUCT.size + 65_535)
	try:
		handle.seek(archive_size - tail_size)
		tail = handle.read(tail_size)
		handle.seek(0)
	except (OSError, ValueError):
		raise GateInputError("credential_gate.archive_read_failed") from None
	if len(tail) != tail_size:
		raise GateInputError("credential_gate.archive_read_failed")
	search_end = len(tail)
	while True:
		candidate_offset = tail.rfind(ZIP_EOCD_SIGNATURE, 0, search_end)
		if candidate_offset < 0:
			return False, tail_size
		if candidate_offset + ZIP_EOCD_STRUCT.size <= len(tail):
			fields = ZIP_EOCD_STRUCT.unpack_from(tail, candidate_offset)
			comment_size = fields[-1]
			if candidate_offset + ZIP_EOCD_STRUCT.size + comment_size == len(tail):
				return True, tail_size
		search_end = candidate_offset


def _preflight_zip_stream(
	handle: BinaryIO,
	archive_size: int,
	limits: GateLimits,
) -> ZipPreflight:
	if archive_size < ZIP_EOCD_STRUCT.size:
		raise GateInputError("credential_gate.archive_invalid")
	tail_size = min(archive_size, ZIP_EOCD_STRUCT.size + 65_535)
	try:
		handle.seek(archive_size - tail_size)
		tail = handle.read(tail_size)
	except (OSError, ValueError):
		raise GateInputError("credential_gate.archive_read_failed") from None
	if len(tail) != tail_size:
		raise GateInputError("credential_gate.archive_read_failed")

	eocd_offset = -1
	search_end = len(tail)
	while True:
		candidate_offset = tail.rfind(ZIP_EOCD_SIGNATURE, 0, search_end)
		if candidate_offset < 0:
			break
		if candidate_offset + ZIP_EOCD_STRUCT.size <= len(tail):
			fields = ZIP_EOCD_STRUCT.unpack_from(tail, candidate_offset)
			comment_size = fields[-1]
			if candidate_offset + ZIP_EOCD_STRUCT.size + comment_size == len(tail):
				eocd_offset = candidate_offset
				break
		search_end = candidate_offset
	if eocd_offset < 0:
		raise GateInputError("credential_gate.archive_invalid")

	(
		_signature,
		disk_number,
		central_directory_disk,
		disk_entry_count,
		entry_count,
		central_directory_size,
		central_directory_offset,
		_comment_size,
	) = ZIP_EOCD_STRUCT.unpack_from(tail, eocd_offset)
	if disk_number != 0 or central_directory_disk != 0 or disk_entry_count != entry_count:
		raise GateInputError("credential_gate.archive_multidisk_unsupported")
	if (
		entry_count == 0xFFFF
		or central_directory_size == 0xFFFFFFFF
		or central_directory_offset == 0xFFFFFFFF
	):
		raise GateInputError("credential_gate.archive_zip64_unsupported")
	if entry_count > limits.max_zip_entries:
		raise GateInputError("credential_gate.archive_entry_count_exceeded")
	if central_directory_size > limits.max_zip_central_directory_bytes:
		raise GateInputError("credential_gate.archive_central_directory_budget_exceeded")
	absolute_eocd_offset = archive_size - tail_size + eocd_offset
	declared_central_directory_end = central_directory_offset + central_directory_size
	if declared_central_directory_end > absolute_eocd_offset:
		raise GateInputError("credential_gate.archive_layout_invalid")
	leading_bytes = absolute_eocd_offset - declared_central_directory_end
	if leading_bytes > limits.max_zip_leading_bytes:
		raise GateInputError("credential_gate.archive_leading_data_budget_exceeded")
	if entry_count:
		try:
			handle.seek(leading_bytes + central_directory_offset)
			central_signature = handle.read(4)
		except (OSError, ValueError):
			raise GateInputError("credential_gate.archive_read_failed") from None
		if central_signature != b"PK\x01\x02":
			raise GateInputError("credential_gate.archive_layout_invalid")
	try:
		handle.seek(0)
	except (OSError, ValueError):
		raise GateInputError("credential_gate.archive_read_failed") from None
	return ZipPreflight(
		entry_count=entry_count,
		central_directory_bytes=central_directory_size,
		archive_size=archive_size,
		leading_bytes=leading_bytes,
		central_directory_offset=leading_bytes + central_directory_offset,
	)


def _scan_payload(
	payload: bytes,
	report_path: str,
	file_kind: str,
	collector: IssueCollector,
	stats: ScanStats,
	*,
	allow_suppression: bool,
) -> None:
	if collector.exhausted:
		return
	if b"\0" in payload:
		if file_kind == "text":
			collector.add("credential_gate.text_encoding_invalid", report_path)
		else:
			stats.skipped_binary_count += 1
		return
	try:
		text = payload.decode("utf-8", errors="strict")
	except UnicodeDecodeError:
		if file_kind == "text":
			collector.add("credential_gate.text_encoding_invalid", report_path)
		else:
			stats.skipped_binary_count += 1
		return
	stats.text_file_count += 1
	_scan_text(
		text,
		report_path,
		collector,
		allow_suppression=allow_suppression,
	)


def _scan_text(
	text: str,
	report_path: str,
	collector: IssueCollector,
	*,
	allow_suppression: bool,
) -> None:
	if collector.exhausted:
		return
	for match, line_number in _matches_with_line_numbers(PRIVATE_KEY_BLOCK_RE, text):
		body = match.group("body")
		base64_characters = sum(character.isalnum() or character in "+/=" for character in body)
		if (
			base64_characters >= 80
			and not (
				allow_suppression
				and _match_is_suppressed(
					text,
					match.start(),
					"credential.private_key_material",
				)
			)
		):
			collector.add(
				"credential.private_key_material",
				report_path,
				line_number,
				sensitive_value=match.group(0),
			)
			if collector.exhausted:
				return

	for rule_id, pattern in KNOWN_TOKEN_PATTERNS:
		for match, line_number in _matches_with_line_numbers(pattern, text):
			value = match.group(0)
			if (
				_is_provider_placeholder(value)
				or (
					allow_suppression
					and _match_is_suppressed(text, match.start(), rule_id)
				)
			):
				continue
			collector.add(
				rule_id,
				report_path,
				line_number,
				sensitive_value=value,
			)
			if collector.exhausted:
				return

	for match, line_number in _matches_with_line_numbers(ASSIGNMENT_RE, text):
		value = match.group("double") or match.group("single") or match.group("bare") or ""
		if (
			not _looks_like_credential_value(value)
			or (
				allow_suppression
				and _match_is_suppressed(text, match.start(), "credential.assignment")
			)
		):
			continue
		collector.add(
			"credential.assignment",
			report_path,
			line_number,
			sensitive_value=value,
		)
		if collector.exhausted:
			return

	for match, line_number in _matches_with_line_numbers(URI_CREDENTIAL_RE, text):
		value = match.group("value")
		if (
			not _looks_like_credential_value(value)
			or (
				allow_suppression
				and _match_is_suppressed(text, match.start(), "credential.uri_userinfo")
			)
		):
			continue
		collector.add(
			"credential.uri_userinfo",
			report_path,
			line_number,
			sensitive_value=value,
		)
		if collector.exhausted:
			return


def _scan_sensitive_file_name(report_path: str, collector: IssueCollector) -> None:
	lower_path = report_path.lower()
	file_name = lower_path.rsplit("/", 1)[-1]
	if file_name in SENSITIVE_FILE_NAMES or SENSITIVE_FILE_NAME_RE.search(file_name):
		collector.add("credential.sensitive_file_name", report_path)


def _source_path_allows_suppression(report_path: str) -> bool:
	return report_path == "tests" or report_path.startswith("tests/")


def _looks_like_credential_value(value: str) -> bool:
	candidate = value.strip()
	if len(candidate) < 12 or len(candidate) > 512:
		return False
	if _is_placeholder_value(candidate):
		return False
	character_classes = sum((
		any(character.islower() for character in candidate),
		any(character.isupper() for character in candidate),
		any(character.isdigit() for character in candidate),
		any(not character.isalnum() for character in candidate),
	))
	if character_classes >= 3:
		return True
	return len(candidate) >= 20 and _shannon_entropy(candidate) >= 3.2


def _is_placeholder_value(value: str) -> bool:
	candidate = value.strip().lower()
	if not candidate:
		return True
	if re.fullmatch(
		r"(?:<[^<>\r\n]{1,80}>|\$\{[^{}\r\n]{1,80}\}|\{\{[^{}\r\n]{1,80}\}\}|"
		r"\$\([^()\r\n]{1,80}\)|%[^%\r\n]{1,80}%)",
		candidate,
	):
		return True
	if candidate in PLACEHOLDER_VALUE_WORDS:
		return True
	if re.fullmatch(
		r"(?:change[-_]?me|dummy|example|fake|masked|not[-_]?a[-_]?real|placeholder|"
		r"redacted|replace[-_]?me|sample|test[-_]?only|your)"
		r"(?:[-_][a-z0-9]+){0,8}",
		candidate,
	):
		return True
	compact = re.sub(r"[^a-z0-9]", "", candidate)
	if not compact or set(compact) <= {"x", "0", "1"}:
		return True
	return False


def _is_provider_placeholder(value: str) -> bool:
	body = re.sub(
		r"^(?:github_pat_|gh[pousr]_|glpat-|AIza|GOCSPX-|npm_|"
		r"sk-(?:proj-|svcacct-)?|xox[baprs]-|sk_live_)",
		"",
		value,
		flags=re.IGNORECASE,
	)
	compact = re.sub(r"[^A-Za-z0-9]", "", body).lower()
	return bool(compact) and set(compact) <= {"x", "0", "1"}


def _shannon_entropy(value: str) -> float:
	if not value:
		return 0.0
	counts: dict[str, int] = {}
	for character in value:
		counts[character] = counts.get(character, 0) + 1
	length = len(value)
	return -sum(
		(count / length) * math.log2(count / length)
		for count in counts.values()
	)


def _matches_with_line_numbers(
	pattern: re.Pattern[str],
	text: str,
) -> Iterator[tuple[re.Match[str], int]]:
	line_number = 1
	cursor = 0
	for match in pattern.finditer(text):
		match_start = match.start()
		line_number += text.count("\n", cursor, match_start)
		cursor = match_start
		yield match, line_number


def _match_is_suppressed(text: str, offset: int, rule_id: str) -> bool:
	line_start = text.rfind("\n", 0, max(0, offset)) + 1
	if line_start <= 0:
		return False
	previous_end = line_start - 1
	previous_start = text.rfind("\n", 0, previous_end) + 1
	previous_line = text[previous_start:previous_end].strip()
	match = SUPPRESSION_RE.fullmatch(previous_line)
	return match is not None and match.group("rule_id") == rule_id


def _result(
	mode: str,
	collector: IssueCollector,
	stats: ScanStats,
) -> dict[str, object]:
	issues = collector.issues
	return {
		"schema_version": SCHEMA_VERSION,
		"ok": not issues,
		"mode": mode,
		"issues": issues,
		"stats": stats.to_dict(),
	}


def _failure_result(mode: str, rule_id: str, path: str) -> dict[str, object]:
	collector = IssueCollector(1)
	collector.add(rule_id, path)
	return _result(mode, collector, ScanStats())


if __name__ == "__main__":
	raise SystemExit(main())
