#!/usr/bin/env python3
"""Read-only, bounded test discovery evidence for GF validation planning.

This module inventories test declarations; it never executes tests, writes cache
state, or decides that a validation action may be skipped.
"""

from __future__ import annotations

import ast
import codecs
import hashlib
import json
import math
import os
import re
import stat
import time
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from typing import Callable


INVENTORY_SCHEMA_VERSION = 1
DISCOVERY_CONTRACT_VERSION = 1
TEST_ROOT_PARTS = ("tests", "gf_core")
TEST_ROOT_LABEL = "tests/gf_core"
FILE_ATTRIBUTE_REPARSE_POINT = 0x0400
READ_CHUNK_BYTES = 1024 * 1024
_WINDOWS_FORBIDDEN_CHARACTERS = frozenset('<>:"|?*')
_WINDOWS_RESERVED_NAMES = frozenset(
	{
		"CON",
		"PRN",
		"AUX",
		"NUL",
		*(f"COM{index}" for index in range(1, 10)),
		*(f"LPT{index}" for index in range(1, 10)),
	}
)
_GDSCRIPT_TEST_PATTERN = re.compile(
	r"(?m)^func[\t ]+(test_\w*)[\t ]*\(",
	re.UNICODE,
)
_GDSCRIPT_SIMPLE_ESCAPES = frozenset({
	"a",
	"b",
	"f",
	"n",
	"r",
	"t",
	"v",
	'"',
	"'",
	"\\",
})
_HEXADECIMAL_DIGITS = frozenset("0123456789abcdefABCDEF")


class TestInventoryError(RuntimeError):
	"""Base error for fail-closed test inventory operations."""


class TestInventoryInputError(TestInventoryError):
	"""Raised when the inventory root or a source entry is unsafe."""


class TestInventoryLimitError(TestInventoryError):
	"""Raised when an inventory input exceeds a declared hard budget."""


class TestInventoryDriftError(TestInventoryError):
	"""Raised when an inventory input changes while it is being captured."""


class TestInventoryDeadlineError(TestInventoryError):
	"""Raised when an advisory inventory capture exceeds its monotonic deadline."""


@dataclass(frozen=True)
class InventoryLimits:
	"""Hard upper bounds for one test inventory capture."""

	max_entries: int = 4096
	max_source_files: int = 2048
	max_source_file_bytes: int = 1024 * 1024
	max_total_source_bytes: int = 32 * 1024 * 1024
	max_path_bytes: int = 1024
	max_total_path_bytes: int = 512 * 1024
	max_directory_depth: int = 32
	max_test_methods: int = 50_000
	max_method_name_bytes: int = 512


DEFAULT_LIMITS = InventoryLimits()


@dataclass
class _BudgetState:
	entry_count: int = 0
	source_file_count: int = 0
	total_source_bytes: int = 0
	total_path_bytes: int = 0
	test_method_count: int = 0


@dataclass(frozen=True)
class _FileSnapshot:
	device: int
	inode: int
	mode: int
	size: int
	mtime_ns: int


@dataclass(frozen=True)
class _CapturedSource:
	path: Path
	logical_path: str
	snapshot: _FileSnapshot
	record: dict[str, Any]


@dataclass(frozen=True)
class _AdvisoryDeadline:
	deadline_seconds: float | None
	monotonic: Callable[[], float]

	def check(self) -> None:
		if self.deadline_seconds is None:
			return
		try:
			now_value = self.monotonic()
		except Exception as exc:
			raise TestInventoryInputError(
				"test_inventory.advisory_clock_failed"
			) from exc
		if (
			type(now_value) not in (int, float)
			or not math.isfinite(float(now_value))
			or float(now_value) < 0.0
		):
			raise TestInventoryInputError(
				"test_inventory.advisory_clock_invalid"
			)
		if float(now_value) >= self.deadline_seconds:
			raise TestInventoryDeadlineError(
				"test_inventory.advisory_deadline_exceeded"
			)


def collect_test_inventory(
	repository_root: Path,
	*,
	limits: InventoryLimits = DEFAULT_LIMITS,
	deadline_seconds: float | None = None,
	monotonic: Callable[[], float] = time.monotonic,
) -> dict[str, Any]:
	"""Return stable declaration-inventory evidence below ``tests/gf_core``.

	Only regular ``.gd`` and ``.py`` files contribute source bytes. Every entry
	below the fixed test root still consumes path and entry budgets and is checked
	for links, reparse points, special file types, and portable path collisions.

	``capture_complete`` means the bounded source inventory and conservative test
	declaration scan completed over one stable view. It does not claim that Godot
	parsed, compiled, or executed any GDScript. ``deadline_seconds`` is an optional
	absolute value in the injected monotonic clock's domain; expiry is advisory to
	the caller and raises ``TestInventoryDeadlineError`` without returning evidence.
	"""
	_validate_limits(limits)
	deadline = _make_advisory_deadline(deadline_seconds, monotonic)
	deadline.check()
	root = _validate_repository_root(repository_root, deadline=deadline)
	test_root = root.joinpath(*TEST_ROOT_PARTS)
	_validate_fixed_test_root(root, test_root, deadline=deadline)

	state = _BudgetState()
	portable_paths: dict[str, str] = {}
	directory_snapshots: list[tuple[Path, str, _FileSnapshot]] = []
	captured_sources: list[_CapturedSource] = []
	_walk_test_tree(
		test_root,
		root=root,
		depth=0,
		limits=limits,
		state=state,
		portable_paths=portable_paths,
		directory_snapshots=directory_snapshots,
		captured_sources=captured_sources,
		deadline=deadline,
	)

	# Recheck all discovered identities after enumeration so ordinary replacement,
	# deletion, and in-place source mutation cannot yield mixed-time evidence.
	for path, logical_path, expected in directory_snapshots:
		deadline.check()
		_validate_unchanged_path(path, logical_path, expected, expect_directory=True)
	for source in captured_sources:
		deadline.check()
		_validate_unchanged_path(
			source.path,
			source.logical_path,
			source.snapshot,
			expect_directory=False,
		)

	files = sorted(
		(source.record for source in captured_sources),
		key=lambda record: _portable_sort_key(str(record["path"])),
	)
	test_manifest = [
		{"path": record["path"], "tests": record["tests"]}
		for record in files
	]
	source_manifest = [
		{
			"path": record["path"],
			"language": record["language"],
			"size_bytes": record["size_bytes"],
			"content_sha256": record["content_sha256"],
		}
		for record in files
	]
	source_manifest_sha256 = _stable_digest(
		"gf-validation-test-source-manifest-v1",
		source_manifest,
	)
	test_list_sha256 = _stable_digest(
		"gf-validation-test-list-v1",
		test_manifest,
	)
	result: dict[str, Any] = {
		"schema_version": INVENTORY_SCHEMA_VERSION,
		"discovery_contract_version": DISCOVERY_CONTRACT_VERSION,
		"root": TEST_ROOT_LABEL,
		"capture_complete": True,
		"entry_count": state.entry_count,
		"file_count": len(files),
		"method_count": state.test_method_count,
		"source_bytes": state.total_source_bytes,
		"source_manifest_sha256": source_manifest_sha256,
		"test_list_sha256": test_list_sha256,
		"files": files,
	}
	result["inventory_sha256"] = _stable_digest(
		"gf-validation-test-inventory-v1",
		result,
	)
	deadline.check()
	return result


def _make_advisory_deadline(
	deadline_seconds: float | None,
	monotonic: Callable[[], float],
) -> _AdvisoryDeadline:
	if not callable(monotonic):
		raise TypeError("monotonic must be callable")
	if deadline_seconds is None:
		return _AdvisoryDeadline(None, monotonic)
	if (
		type(deadline_seconds) not in (int, float)
		or not math.isfinite(float(deadline_seconds))
		or float(deadline_seconds) < 0.0
	):
		raise ValueError("deadline_seconds must be a finite non-negative number")
	return _AdvisoryDeadline(float(deadline_seconds), monotonic)


def _validate_limits(limits: InventoryLimits) -> None:
	if not isinstance(limits, InventoryLimits):
		raise TypeError("limits must be an InventoryLimits value")
	for field_name in InventoryLimits.__dataclass_fields__:
		value = getattr(limits, field_name)
		default_value = getattr(DEFAULT_LIMITS, field_name)
		if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
			raise ValueError(f"{field_name} must be a positive integer")
		if value > default_value:
			raise ValueError(
				f"{field_name} cannot exceed the module hard limit of {default_value}"
			)


def _validate_repository_root(
	repository_root: Path,
	*,
	deadline: _AdvisoryDeadline,
) -> Path:
	try:
		raw_root = os.fspath(repository_root)
	except TypeError as exc:
		raise TypeError("repository_root must be path-like") from exc
	if not isinstance(raw_root, str):
		raise TypeError("repository_root must be a text path")
	if not raw_root or "\0" in raw_root:
		raise TestInventoryInputError("test_inventory.repository_root_invalid")
	root = Path(raw_root)
	if not root.is_absolute() or ".." in root.parts:
		raise TestInventoryInputError("test_inventory.repository_root_not_absolute")
	if os.name == "nt":
		normalized = raw_root.replace("/", "\\")
		if normalized.startswith(("\\\\", "\\?\\", "\\.\\")):
			raise TestInventoryInputError("test_inventory.repository_root_unsupported")

	current = Path(root.anchor)
	for component in root.parts[1:]:
		deadline.check()
		current /= component
		_snapshot_path(current, "repository root", expect_directory=True)
	deadline.check()
	return root


def _validate_fixed_test_root(
	root: Path,
	test_root: Path,
	*,
	deadline: _AdvisoryDeadline,
) -> None:
	current = root
	for part in TEST_ROOT_PARTS:
		deadline.check()
		_validate_path_segment(part)
		current /= part
		_snapshot_path(
			current,
			current.relative_to(root).as_posix(),
			expect_directory=True,
		)
	if current != test_root:
		raise AssertionError("fixed test root construction drifted")


def _walk_test_tree(
	directory: Path,
	*,
	root: Path,
	depth: int,
	limits: InventoryLimits,
	state: _BudgetState,
	portable_paths: dict[str, str],
	directory_snapshots: list[tuple[Path, str, _FileSnapshot]],
	captured_sources: list[_CapturedSource],
	deadline: _AdvisoryDeadline,
) -> None:
	deadline.check()
	logical_directory = directory.relative_to(root).as_posix()
	if depth > limits.max_directory_depth:
		raise TestInventoryLimitError("test_inventory.directory_depth_limit")
	directory_before = _snapshot_path(
		directory,
		logical_directory,
		expect_directory=True,
	)
	directory_snapshots.append((directory, logical_directory, directory_before))
	try:
		with os.scandir(directory) as iterator:
			entry_names: list[str] = []
			for entry in iterator:
				deadline.check()
				entry_names.append(entry.name)
	except OSError as exc:
		raise TestInventoryInputError(
			f"test_inventory.directory_unreadable:{logical_directory}"
		) from exc
	deadline.check()

	for entry_name in sorted(entry_names, key=_portable_sort_key):
		deadline.check()
		_validate_path_segment(entry_name)
		path = directory / entry_name
		logical_path = path.relative_to(root).as_posix()
		_consume_path_budget(logical_path, limits=limits, state=state)
		portable_key = _portable_key(logical_path)
		previous_path = portable_paths.setdefault(portable_key, logical_path)
		if previous_path != logical_path:
			raise TestInventoryInputError(
				"test_inventory.portable_path_collision:"
				f"{previous_path}:{logical_path}"
			)

		state.entry_count += 1
		if state.entry_count > limits.max_entries:
			raise TestInventoryLimitError("test_inventory.entry_limit")
		entry_snapshot = _snapshot_path(path, logical_path)
		mode = entry_snapshot.mode
		if stat.S_ISDIR(mode):
			_walk_test_tree(
				path,
				root=root,
				depth=depth + 1,
				limits=limits,
				state=state,
				portable_paths=portable_paths,
				directory_snapshots=directory_snapshots,
				captured_sources=captured_sources,
				deadline=deadline,
			)
			continue
		if not stat.S_ISREG(mode):
			raise TestInventoryInputError(
				f"test_inventory.special_entry_rejected:{logical_path}"
			)
		if path.suffix not in {".gd", ".py"}:
			continue

		state.source_file_count += 1
		if state.source_file_count > limits.max_source_files:
			raise TestInventoryLimitError("test_inventory.source_file_limit")
		data, final_snapshot = _read_stable_source(
			path,
			logical_path,
			entry_snapshot,
			limits=limits,
			state=state,
			deadline=deadline,
		)
		deadline.check()
		try:
			text = data.decode("utf-8", errors="strict")
		except UnicodeDecodeError as exc:
			raise TestInventoryInputError(
				f"test_inventory.source_not_utf8:{logical_path}"
			) from exc
		if data.startswith(codecs.BOM_UTF8):
			raise TestInventoryInputError(
				f"test_inventory.source_has_utf8_bom:{logical_path}"
			)

		if path.suffix == ".gd":
			language = "gdscript"
			tests = _discover_gdscript_tests(text, logical_path)
		else:
			language = "python"
			tests = _discover_python_tests(text, logical_path)
		tests = sorted(tests, key=_portable_sort_key)
		if len(set(tests)) != len(tests):
			raise TestInventoryInputError(
				f"test_inventory.duplicate_test_id:{logical_path}"
			)
		for test_name in tests:
			method_bytes = len(test_name.encode("utf-8", errors="strict"))
			if method_bytes > limits.max_method_name_bytes:
				raise TestInventoryLimitError(
					f"test_inventory.method_name_limit:{logical_path}"
				)
		state.test_method_count += len(tests)
		if state.test_method_count > limits.max_test_methods:
			raise TestInventoryLimitError("test_inventory.test_method_limit")
		content_sha256 = hashlib.sha256(data).hexdigest()
		record = {
			"path": logical_path,
			"language": language,
			"size_bytes": len(data),
			"content_sha256": content_sha256,
			"method_count": len(tests),
			"test_list_sha256": _stable_digest(
				"gf-validation-test-file-list-v1",
				tests,
			),
			"tests": tests,
		}
		captured_sources.append(
			_CapturedSource(path, logical_path, final_snapshot, record)
		)

	_validate_unchanged_path(
		directory,
		logical_directory,
		directory_before,
		expect_directory=True,
	)
	deadline.check()


def _consume_path_budget(
	logical_path: str,
	*,
	limits: InventoryLimits,
	state: _BudgetState,
) -> None:
	try:
		path_size = len(logical_path.encode("utf-8", errors="strict"))
	except UnicodeEncodeError as exc:
		raise TestInventoryInputError("test_inventory.path_not_utf8") from exc
	if path_size > limits.max_path_bytes:
		raise TestInventoryLimitError("test_inventory.path_length_limit")
	state.total_path_bytes += path_size
	if state.total_path_bytes > limits.max_total_path_bytes:
		raise TestInventoryLimitError("test_inventory.total_path_limit")


def _read_stable_source(
	path: Path,
	logical_path: str,
	before: _FileSnapshot,
	*,
	limits: InventoryLimits,
	state: _BudgetState,
	deadline: _AdvisoryDeadline,
) -> tuple[bytes, _FileSnapshot]:
	deadline.check()
	if before.size < 0 or before.size > limits.max_source_file_bytes:
		raise TestInventoryLimitError(
			f"test_inventory.source_file_size_limit:{logical_path}"
		)
	projected_total = state.total_source_bytes + before.size
	if projected_total > limits.max_total_source_bytes:
		raise TestInventoryLimitError("test_inventory.total_source_size_limit")

	flags = (
		os.O_RDONLY
		| getattr(os, "O_BINARY", 0)
		| getattr(os, "O_CLOEXEC", 0)
		| getattr(os, "O_NOFOLLOW", 0)
	)
	try:
		file_descriptor = os.open(path, flags)
	except OSError as exc:
		raise TestInventoryInputError(
			f"test_inventory.source_open_failed:{logical_path}"
		) from exc
	try:
		deadline.check()
		opened = _snapshot_from_stat(os.fstat(file_descriptor))
		if not stat.S_ISREG(opened.mode) or opened != before:
			raise TestInventoryDriftError(
				f"test_inventory.source_changed_while_opening:{logical_path}"
			)
		chunks: list[bytes] = []
		remaining_with_growth_probe = before.size + 1
		while remaining_with_growth_probe > 0:
			deadline.check()
			chunk = os.read(
				file_descriptor,
				min(READ_CHUNK_BYTES, remaining_with_growth_probe),
			)
			deadline.check()
			if not chunk:
				break
			chunks.append(chunk)
			remaining_with_growth_probe -= len(chunk)
		data = b"".join(chunks)
		if len(data) != before.size:
			raise TestInventoryDriftError(
				f"test_inventory.source_size_changed:{logical_path}"
			)
		opened_after = _snapshot_from_stat(os.fstat(file_descriptor))
		if opened_after != opened:
			raise TestInventoryDriftError(
				f"test_inventory.source_changed_while_reading:{logical_path}"
			)
	finally:
		try:
			os.close(file_descriptor)
		except OSError as exc:
			raise TestInventoryInputError(
				f"test_inventory.source_close_failed:{logical_path}"
			) from exc

	deadline.check()
	path_after = _snapshot_path(path, logical_path, expect_directory=False)
	if path_after != opened_after:
		raise TestInventoryDriftError(
			f"test_inventory.source_replaced_while_reading:{logical_path}"
		)
	state.total_source_bytes = projected_total
	return data, path_after


def _discover_gdscript_tests(text: str, logical_path: str) -> list[str]:
	masked = _mask_gdscript_non_code(text, logical_path)
	tests = [match.group(1) for match in _GDSCRIPT_TEST_PATTERN.finditer(masked)]
	for test_name in tests:
		if not test_name.isidentifier():
			raise TestInventoryInputError(
				f"test_inventory.invalid_gdscript_test_name:{logical_path}"
			)
	return tests


def _mask_gdscript_non_code(text: str, logical_path: str) -> str:
	"""Mask literals/comments with a conservative, fail-closed lexer.

	This validates only string-token boundaries and documented escape shapes. It
	does not claim to replace the Godot parser or prove that the script compiles.
	"""
	if "\0" in text:
		raise TestInventoryInputError(
			f"test_inventory.gdscript_invalid_control_character:{logical_path}"
		)
	masked = list(text)
	index = 0
	state = "code"
	quote = ""
	raw_string = False
	while index < len(text):
		character = text[index]
		if state == "code":
			if character == "#":
				while index < len(text) and text[index] not in "\r\n":
					masked[index] = " "
					index += 1
				continue
			if character in {'"', "'"}:
				quote = character
				raw_string = _is_raw_string_prefix(text, index)
				if text.startswith(character * 3, index):
					state = "triple"
					for offset in range(3):
						masked[index + offset] = " "
					index += 3
				else:
					state = "string"
					masked[index] = " "
					index += 1
				continue
			index += 1
			continue

		if state == "string":
			if character == "\\":
				index = _mask_gdscript_escape(
					text,
					masked,
					index,
					logical_path,
					raw_string=raw_string,
				)
				continue
			if character in "\r\n":
				raise TestInventoryInputError(
					f"test_inventory.gdscript_unescaped_newline:{logical_path}"
				)
			masked[index] = " "
			if character == quote:
				state = "code"
				raw_string = False
			index += 1
			continue

		# Triple strings may contain newlines; preserve only newline characters so
		# declaration anchors outside the string keep their original line shape.
		if character == "\\":
			index = _mask_gdscript_escape(
				text,
				masked,
				index,
				logical_path,
				raw_string=raw_string,
			)
			continue
		if text.startswith(quote * 3, index):
			for offset in range(3):
				masked[index + offset] = " "
			index += 3
			state = "code"
			raw_string = False
			continue
		if character not in "\r\n":
			masked[index] = " "
		index += 1
	if state != "code":
		raise TestInventoryInputError(
			f"test_inventory.gdscript_unterminated_string:{logical_path}"
		)
	return "".join(masked)


def _is_raw_string_prefix(text: str, quote_index: int) -> bool:
	prefix_index = quote_index - 1
	if prefix_index < 0 or text[prefix_index] != "r":
		return False
	if prefix_index == 0:
		return True
	previous = text[prefix_index - 1]
	return not (previous == "_" or previous.isalnum())


def _mask_gdscript_escape(
	text: str,
	masked: list[str],
	index: int,
	logical_path: str,
	*,
	raw_string: bool,
) -> int:
	masked[index] = " "
	next_index = index + 1
	if next_index >= len(text):
		raise TestInventoryInputError(
			f"test_inventory.gdscript_dangling_escape:{logical_path}"
		)
	next_character = text[next_index]
	if next_character == "\r":
		if next_index + 1 < len(text) and text[next_index + 1] == "\n":
			return next_index + 2
		return next_index + 1
	if next_character == "\n":
		return next_index + 1
	masked[next_index] = " "
	if raw_string or next_character in _GDSCRIPT_SIMPLE_ESCAPES:
		return next_index + 1
	if next_character in {"u", "U"}:
		digit_count = 4 if next_character == "u" else 6
		digits_start = next_index + 1
		digits_end = digits_start + digit_count
		digits = text[digits_start:digits_end]
		if (
			len(digits) == digit_count
			and all(digit in _HEXADECIMAL_DIGITS for digit in digits)
		):
			for digit_index in range(digits_start, digits_end):
				masked[digit_index] = " "
			return digits_end
		raise TestInventoryInputError(
			f"test_inventory.gdscript_invalid_escape:{logical_path}"
		)
	raise TestInventoryInputError(
		f"test_inventory.gdscript_invalid_escape:{logical_path}"
	)


def _discover_python_tests(text: str, logical_path: str) -> list[str]:
	try:
		tree = ast.parse(text, filename=logical_path)
	except (SyntaxError, ValueError, TypeError, MemoryError, RecursionError) as exc:
		raise TestInventoryInputError(
			f"test_inventory.python_parse_failed:{logical_path}"
		) from exc
	tests: list[str] = []

	def visit_statements(statements: list[ast.stmt], owners: tuple[str, ...]) -> None:
		for node in statements:
			if isinstance(node, ast.ClassDef):
				visit_statements(node.body, (*owners, node.name))
			elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
				if node.name.startswith("test_"):
					tests.append(".".join((*owners, node.name)))

	visit_statements(tree.body, ())
	return tests


def _snapshot_path(
	path: Path,
	logical_path: str,
	*,
	expect_directory: bool | None = None,
) -> _FileSnapshot:
	try:
		value = path.lstat()
	except OSError as exc:
		raise TestInventoryInputError(
			f"test_inventory.path_unavailable:{logical_path}"
		) from exc
	if stat.S_ISLNK(value.st_mode) or _has_reparse_attribute(value):
		raise TestInventoryInputError(
			f"test_inventory.link_or_reparse_rejected:{logical_path}"
		)
	if expect_directory is True and not stat.S_ISDIR(value.st_mode):
		raise TestInventoryInputError(
			f"test_inventory.directory_required:{logical_path}"
		)
	if expect_directory is False and not stat.S_ISREG(value.st_mode):
		raise TestInventoryInputError(
			f"test_inventory.regular_file_required:{logical_path}"
		)
	return _snapshot_from_stat(value)


def _snapshot_from_stat(value: os.stat_result) -> _FileSnapshot:
	inode = int(getattr(value, "st_ino", 0))
	device = int(getattr(value, "st_dev", 0))
	if inode <= 0:
		raise TestInventoryInputError("test_inventory.identity_unavailable")
	return _FileSnapshot(
		device=device,
		inode=inode,
		mode=int(value.st_mode),
		size=int(value.st_size),
		mtime_ns=int(getattr(value, "st_mtime_ns", round(value.st_mtime * 1_000_000_000))),
	)


def _validate_unchanged_path(
	path: Path,
	logical_path: str,
	expected: _FileSnapshot,
	*,
	expect_directory: bool,
) -> None:
	try:
		actual = _snapshot_path(
			path,
			logical_path,
			expect_directory=expect_directory,
		)
	except TestInventoryInputError as exc:
		raise TestInventoryDriftError(
			f"test_inventory.path_changed:{logical_path}"
		) from exc
	if actual != expected:
		raise TestInventoryDriftError(
			f"test_inventory.path_changed:{logical_path}"
		)


def _has_reparse_attribute(value: os.stat_result) -> bool:
	return bool(
		int(getattr(value, "st_file_attributes", 0))
		& FILE_ATTRIBUTE_REPARSE_POINT
	)


def _validate_path_segment(segment: str) -> None:
	if not segment or segment in {".", ".."}:
		raise TestInventoryInputError("test_inventory.path_segment_invalid")
	try:
		segment_bytes = segment.encode("utf-8", errors="strict")
	except UnicodeEncodeError as exc:
		raise TestInventoryInputError("test_inventory.path_not_utf8") from exc
	if len(segment_bytes) > 255:
		raise TestInventoryLimitError("test_inventory.path_segment_limit")
	if any(ord(character) < 32 or ord(character) == 127 for character in segment):
		raise TestInventoryInputError("test_inventory.path_control_character")
	if any(character in _WINDOWS_FORBIDDEN_CHARACTERS for character in segment):
		raise TestInventoryInputError("test_inventory.path_not_portable")
	if segment.endswith((" ", ".")):
		raise TestInventoryInputError("test_inventory.path_not_portable")
	device_stem = segment.split(".", 1)[0].upper()
	if device_stem in _WINDOWS_RESERVED_NAMES:
		raise TestInventoryInputError("test_inventory.path_not_portable")


def _portable_key(value: str) -> str:
	return unicodedata.normalize("NFC", value).casefold()


def _portable_sort_key(value: str) -> tuple[str, bytes]:
	return (_portable_key(value), value.encode("utf-8", errors="strict"))


def _stable_digest(domain: str, value: Any) -> str:
	payload = json.dumps(
		value,
		allow_nan=False,
		ensure_ascii=False,
		sort_keys=True,
		separators=(",", ":"),
	).encode("utf-8")
	digest = hashlib.sha256()
	digest.update(domain.encode("ascii"))
	digest.update(b"\0")
	digest.update(payload)
	return digest.hexdigest()
