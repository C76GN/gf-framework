#!/usr/bin/env python3
"""Filesystem containment helpers shared by GF build and analysis tools."""

from __future__ import annotations

import os
import stat
from pathlib import Path
from pathlib import PurePosixPath


FILE_ATTRIBUTE_REPARSE_POINT = 0x0400
DEFAULT_PINNED_READ_CHUNK_BYTES = 64 * 1024
_NATIVE_OS_NAME = os.name


class PinnedReadError(OSError):
	"""Stable, path-free failure from a pinned regular-file read."""

	def __init__(self, rule_id: str) -> None:
		super().__init__(rule_id)
		self.rule_id = rule_id


def absolute_lexical_path(path: Path) -> Path:
	"""Return an absolute path without resolving links or requiring existence."""
	return Path(os.path.abspath(os.fspath(path.expanduser())))


def path_is_inside_lexical(root: Path, child: Path) -> bool:
	"""Check lexical containment with platform case semantics."""
	root_path = absolute_lexical_path(root)
	child_path = absolute_lexical_path(child)
	try:
		common = os.path.commonpath((str(root_path), str(child_path)))
	except ValueError:
		return False
	return os.path.normcase(common) == os.path.normcase(str(root_path))


def path_is_inside(root: Path, child: Path) -> bool:
	"""Require both lexical and resolved containment."""
	if not path_is_inside_lexical(root, child):
		return False
	try:
		child.resolve().relative_to(root.resolve())
	except (OSError, ValueError):
		return False
	return True


def path_has_reparse_component(path: Path) -> bool:
	"""Fail closed when any existing ancestor is a link or Windows reparse point."""
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


def read_pinned_utf8_regular_file(
	containment_root: Path,
	relative_path: str,
	*,
	max_bytes: int,
) -> str:
	"""Read a contained UTF-8 file while pinning its filesystem root-to-leaf chain."""
	payload = read_pinned_regular_file(
		containment_root,
		relative_path,
		max_bytes=max_bytes,
	)
	try:
		return payload.decode("utf-8", errors="strict")
	except UnicodeDecodeError:
		raise PinnedReadError("path_security.invalid_utf8") from None


def read_optional_pinned_utf8_regular_file(
	containment_root: Path,
	relative_path: str,
	*,
	max_bytes: int,
) -> str | None:
	"""Read one optional UTF-8 leaf while proving a stable missing observation."""
	payload = read_optional_pinned_regular_file(
		containment_root,
		relative_path,
		max_bytes=max_bytes,
	)
	if payload is None:
		return None
	try:
		return payload.decode("utf-8", errors="strict")
	except UnicodeDecodeError:
		raise PinnedReadError("path_security.invalid_utf8") from None


def read_pinned_regular_file(
	containment_root: Path,
	relative_path: str,
	*,
	max_bytes: int,
) -> bytes:
	"""Read contained regular-file bytes while pinning the root-to-leaf chain."""
	if type(max_bytes) is not int or max_bytes < 0:
		raise PinnedReadError("path_security.invalid_budget")
	try:
		absolute_root = absolute_lexical_path(containment_root)
		relative = _canonical_relative_path(relative_path)
		absolute_path = absolute_root.joinpath(*relative.parts)
		payload = _read_pinned_regular_file(
			absolute_path,
			max_bytes=max_bytes,
		)
	except PinnedReadError:
		raise
	except (OSError, TypeError, ValueError):
		raise PinnedReadError("path_security.file_unavailable") from None
	return payload


def read_optional_pinned_regular_file(
	containment_root: Path,
	relative_path: str,
	*,
	max_bytes: int,
) -> bytes | None:
	"""Read a contained regular-file leaf, or prove that exact leaf was missing."""
	if type(max_bytes) is not int or max_bytes < 0:
		raise PinnedReadError("path_security.invalid_budget")
	try:
		absolute_root = absolute_lexical_path(containment_root)
		relative = _canonical_relative_path(relative_path)
		absolute_path = absolute_root.joinpath(*relative.parts)
		return _read_optional_pinned_regular_file(
			absolute_path,
			max_bytes=max_bytes,
		)
	except PinnedReadError:
		raise
	except (OSError, TypeError, ValueError):
		raise PinnedReadError("path_security.file_unavailable") from None


def _canonical_relative_path(path: str) -> PurePosixPath:
	if not isinstance(path, str):
		raise PinnedReadError("path_security.boundary_invalid")
	raw_path = path
	if (
		not raw_path
		or "\\" in raw_path
		or "\0" in raw_path
	):
		raise PinnedReadError("path_security.boundary_invalid")
	relative = PurePosixPath(raw_path)
	if (
		relative.is_absolute()
		or relative.as_posix() != raw_path
		or not relative.parts
		or any(
			part in {"", ".", ".."} or ":" in part
			for part in relative.parts
		)
	):
		raise PinnedReadError("path_security.boundary_invalid")
	return relative


def _read_pinned_regular_file(path: Path, *, max_bytes: int) -> bytes:
	directory_bindings = _open_directory_chain(path.parent)
	file_descriptor = -1
	try:
		parent_descriptor = directory_bindings[-1][1]
		path_before = _stat_path_entry(path, parent_descriptor)
		_assert_safe_regular_metadata(path_before, max_bytes=max_bytes)
		file_descriptor = _open_file_entry(path, parent_descriptor)
		opened_before = os.fstat(file_descriptor)
		if not _same_regular_file_identity(path_before, opened_before):
			raise PinnedReadError("path_security.file_changed")

		payload = _read_opened_file_bytes(
			file_descriptor,
			opened_before.st_size,
			max_bytes=max_bytes,
		)
		opened_after = os.fstat(file_descriptor)
		path_after = _stat_path_entry(path, parent_descriptor)
		if (
			not _same_regular_file_snapshot(opened_before, opened_after)
			or not _same_regular_file_identity(opened_after, path_after)
			or not _same_regular_file_snapshot(path_before, path_after)
			or not _directory_bindings_are_current(directory_bindings)
		):
			raise PinnedReadError("path_security.file_changed")
		return payload
	finally:
		_close_descriptors([
			file_descriptor,
			*(
				descriptor
				for _path, descriptor, _opened, _parent
				in reversed(directory_bindings)
			),
		])


def _read_optional_pinned_regular_file(
	path: Path,
	*,
	max_bytes: int,
) -> bytes | None:
	directory_bindings = _open_directory_chain(path.parent)
	file_descriptor = -1
	try:
		parent_descriptor = directory_bindings[-1][1]
		try:
			path_before = _stat_path_entry(path, parent_descriptor)
		except FileNotFoundError:
			# Observe the same missing leaf twice while the complete parent chain
			# remains pinned. Other lookup failures are never interpreted as absence.
			if not _directory_bindings_are_current(directory_bindings):
				raise PinnedReadError("path_security.chain_changed")
			try:
				_stat_path_entry(path, parent_descriptor)
			except FileNotFoundError:
				if not _directory_bindings_are_current(directory_bindings):
					raise PinnedReadError("path_security.chain_changed")
				return None
			else:
				raise PinnedReadError("path_security.file_changed")
		_assert_safe_regular_metadata(path_before, max_bytes=max_bytes)
		file_descriptor = _open_file_entry(path, parent_descriptor)
		opened_before = os.fstat(file_descriptor)
		if not _same_regular_file_identity(path_before, opened_before):
			raise PinnedReadError("path_security.file_changed")

		payload = _read_opened_file_bytes(
			file_descriptor,
			opened_before.st_size,
			max_bytes=max_bytes,
		)
		opened_after = os.fstat(file_descriptor)
		path_after = _stat_path_entry(path, parent_descriptor)
		if (
			not _same_regular_file_snapshot(opened_before, opened_after)
			or not _same_regular_file_identity(opened_after, path_after)
			or not _same_regular_file_snapshot(path_before, path_after)
			or not _directory_bindings_are_current(directory_bindings)
		):
			raise PinnedReadError("path_security.file_changed")
		return payload
	finally:
		_close_descriptors([
			file_descriptor,
			*(
				descriptor
				for _path, descriptor, _opened, _parent
				in reversed(directory_bindings)
			),
		])


def _open_directory_chain(
	directory: Path,
) -> list[tuple[Path, int, os.stat_result, int]]:
	if _NATIVE_OS_NAME != "nt" and (
		os.open not in os.supports_dir_fd
		or os.stat not in os.supports_dir_fd
		or os.stat not in os.supports_follow_symlinks
		or int(getattr(os, "O_DIRECTORY", 0)) == 0
		or int(getattr(os, "O_NONBLOCK", 0)) == 0
		or int(getattr(os, "O_NOFOLLOW", 0)) == 0
	):
		raise PinnedReadError("path_security.platform_unsupported")
	bindings: list[tuple[Path, int, os.stat_result, int]] = []
	pending_descriptor = -1
	try:
		for path in _full_directory_paths(directory):
			parent_descriptor = (
				-1 if _NATIVE_OS_NAME == "nt" or not bindings else bindings[-1][1]
			)
			before = _stat_path_entry(path, parent_descriptor)
			_assert_safe_directory_metadata(before)
			pending_descriptor = _open_directory_entry(path, parent_descriptor)
			opened = os.fstat(pending_descriptor)
			after = _stat_path_entry(path, parent_descriptor)
			if (
				not _same_directory_identity(before, opened)
				or not _same_directory_identity(opened, after)
			):
				raise PinnedReadError("path_security.chain_changed")
			bindings.append((
				path,
				pending_descriptor,
				opened,
				parent_descriptor,
			))
			pending_descriptor = -1
		return bindings
	except BaseException:
		_close_descriptors([
			pending_descriptor,
			*(
				descriptor
				for _path, descriptor, _opened, _parent
				in reversed(bindings)
			),
		])
		raise


def _read_opened_file_bytes(
	file_descriptor: int,
	expected_size: int,
	*,
	max_bytes: int,
) -> bytes:
	if expected_size < 0 or expected_size > max_bytes:
		raise PinnedReadError("path_security.file_too_large")
	payload = bytearray()
	while True:
		read_limit = min(
			DEFAULT_PINNED_READ_CHUNK_BYTES,
			max_bytes - len(payload) + 1,
		)
		if read_limit <= 0:
			raise PinnedReadError("path_security.file_too_large")
		try:
			chunk = os.read(file_descriptor, read_limit)
		except InterruptedError:
			continue
		if not chunk:
			break
		payload.extend(chunk)
		if len(payload) > max_bytes:
			raise PinnedReadError("path_security.file_too_large")
		if len(payload) > expected_size:
			raise PinnedReadError("path_security.file_changed")
	if len(payload) != expected_size:
		raise PinnedReadError("path_security.file_changed")
	return bytes(payload)


def _close_descriptors(descriptors: list[int]) -> None:
	close_failed = False
	interrupted: BaseException | None = None
	for descriptor in descriptors:
		if descriptor < 0:
			continue
		try:
			os.close(descriptor)
		except BaseException as error:
			if isinstance(error, (KeyboardInterrupt, SystemExit)):
				if interrupted is None:
					interrupted = error
			else:
				close_failed = True
	if interrupted is not None:
		raise interrupted
	if close_failed:
		raise PinnedReadError("path_security.close_failed")


def _full_directory_paths(directory: Path) -> tuple[Path, ...]:
	absolute_directory = absolute_lexical_path(directory)
	if not absolute_directory.anchor:
		raise PinnedReadError("path_security.boundary_invalid")
	current = Path(absolute_directory.anchor)
	paths = [current]
	for component in absolute_directory.relative_to(current).parts:
		current = current / component
		paths.append(current)
	return tuple(paths)


def _stat_path_entry(path: Path, parent_descriptor: int) -> os.stat_result:
	if _NATIVE_OS_NAME == "nt" or parent_descriptor < 0:
		return os.lstat(path)
	return os.stat(
		path.name,
		dir_fd=parent_descriptor,
		follow_symlinks=False,
	)


def _open_directory_entry(path: Path, parent_descriptor: int) -> int:
	if _NATIVE_OS_NAME == "nt":
		return _windows_open_descriptor(path, expect_directory=True)
	flags = (
		os.O_RDONLY
		| int(getattr(os, "O_DIRECTORY", 0))
		| int(getattr(os, "O_CLOEXEC", 0))
		| int(getattr(os, "O_NOFOLLOW", 0))
	)
	if parent_descriptor < 0:
		return os.open(path, flags)
	return os.open(path.name, flags, dir_fd=parent_descriptor)


def _open_file_entry(path: Path, parent_descriptor: int) -> int:
	if _NATIVE_OS_NAME == "nt":
		return _windows_open_descriptor(path, expect_directory=False)
	return os.open(
		path.name,
		os.O_RDONLY
		| int(getattr(os, "O_BINARY", 0))
		| int(getattr(os, "O_CLOEXEC", 0))
		| int(getattr(os, "O_NONBLOCK", 0))
		| int(getattr(os, "O_NOFOLLOW", 0)),
		dir_fd=parent_descriptor,
	)


def _directory_bindings_are_current(
	bindings: list[tuple[Path, int, os.stat_result, int]],
) -> bool:
	for path, descriptor, opened, parent_descriptor in bindings:
		try:
			current_opened = os.fstat(descriptor)
			current_path = _stat_path_entry(path, parent_descriptor)
		except OSError:
			return False
		if (
			not _same_directory_identity(opened, current_opened)
			or not _same_directory_identity(current_opened, current_path)
		):
			return False
	return True


def _metadata_is_link_or_reparse(metadata: os.stat_result) -> bool:
	return (
		stat.S_ISLNK(metadata.st_mode)
		or bool(
			int(getattr(metadata, "st_file_attributes", 0))
			& FILE_ATTRIBUTE_REPARSE_POINT
		)
	)


def _assert_safe_directory_metadata(metadata: os.stat_result) -> None:
	if (
		not stat.S_ISDIR(metadata.st_mode)
		or _metadata_is_link_or_reparse(metadata)
	):
		raise PinnedReadError("path_security.boundary_invalid")


def _assert_safe_regular_metadata(
	metadata: os.stat_result,
	*,
	max_bytes: int,
) -> None:
	if (
		not stat.S_ISREG(metadata.st_mode)
		or _metadata_is_link_or_reparse(metadata)
	):
		raise PinnedReadError("path_security.file_not_regular")
	if metadata.st_size > max_bytes:
		raise PinnedReadError("path_security.file_too_large")


def _same_directory_identity(
	before: os.stat_result,
	after: os.stat_result,
) -> bool:
	return (
		_same_object_identity(before, after)
		and stat.S_ISDIR(before.st_mode)
		and stat.S_ISDIR(after.st_mode)
	)


def _same_regular_file_identity(
	before: os.stat_result,
	after: os.stat_result,
) -> bool:
	return (
		_same_object_identity(before, after)
		and stat.S_ISREG(before.st_mode)
		and stat.S_ISREG(after.st_mode)
		and before.st_size == after.st_size
		and before.st_mtime_ns == after.st_mtime_ns
	)


def _same_regular_file_snapshot(
	before: os.stat_result,
	after: os.stat_result,
) -> bool:
	return (
		_same_regular_file_identity(before, after)
		and before.st_ctime_ns == after.st_ctime_ns
	)


def _same_object_identity(
	before: os.stat_result,
	after: os.stat_result,
) -> bool:
	before_identity = (int(before.st_dev), int(before.st_ino))
	after_identity = (int(after.st_dev), int(after.st_ino))
	if not any(before_identity) or not any(after_identity):
		return False
	try:
		same_stat = os.path.samestat(before, after)
	except (AttributeError, OSError):
		same_stat = before_identity == after_identity
	return (
		same_stat
		and before.st_mode == after.st_mode
		and not _metadata_is_link_or_reparse(before)
		and not _metadata_is_link_or_reparse(after)
	)


def _windows_open_descriptor(path: Path, *, expect_directory: bool) -> int:
	if _NATIVE_OS_NAME != "nt":
		raise PinnedReadError("path_security.platform_unsupported")
	import ctypes
	import msvcrt
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
	kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
	kernel32.CloseHandle.restype = wintypes.BOOL
	handle = kernel32.CreateFileW(
		str(absolute_lexical_path(path)),
		0x00000080 if expect_directory else 0x80000000 | 0x00000080,
		0x00000001 | (0x00000002 if expect_directory else 0),
		None,
		3,
		0x00200000 | (0x02000000 if expect_directory else 0x08000000),
		None,
	)
	invalid_handle = int(ctypes.c_void_p(-1).value or -1)
	if handle is None or int(handle) == invalid_handle:
		raise PinnedReadError("path_security.file_unavailable")
	raw_handle = int(handle)
	try:
		return msvcrt.open_osfhandle(
			raw_handle,
			os.O_RDONLY | int(getattr(os, "O_BINARY", 0)),
		)
	except BaseException:
		if not kernel32.CloseHandle(wintypes.HANDLE(raw_handle)):
			raise PinnedReadError("path_security.close_failed")
		raise
