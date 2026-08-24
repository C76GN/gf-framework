#!/usr/bin/env python3
"""Resolve executables from an explicit environment and execution cwd."""

from __future__ import annotations

import ntpath
import os
import posixpath
from collections.abc import Mapping
from pathlib import Path


WINDOWS_DEFAULT_PATHEXT = (".COM", ".EXE", ".BAT", ".CMD")
WINDOWS_NO_DEFAULT_CWD_ENV_VAR = "NoDefaultCurrentDirectoryInExePath"
WINDOWS_PATH_LIST_SEPARATOR = ";"
POSIX_PATH_LIST_SEPARATOR = ":"


class ExecutableResolutionError(FileNotFoundError):
	"""Raised when an executable has no match in the frozen search inputs."""


class FrozenEnvironmentError(ValueError):
	"""Raised when a caller-supplied environment has invalid target semantics."""


class EnvironmentNameAmbiguityError(FrozenEnvironmentError):
	"""Raised when a Windows environment contains duplicate folded names."""


def _windows_environment_matching_keys(
	environment: Mapping[str, str],
	name: str,
) -> tuple[str, ...]:
	name_folded = name.casefold()
	return tuple(
		key
		for key in environment
		if key.casefold() == name_folded
	)


def frozen_environment_value(
	environment: Mapping[str, str],
	name: str,
	*,
	platform_name: str | None = None,
) -> str | None:
	"""Read one frozen environment value with target-platform name semantics."""
	effective_platform = platform_name if platform_name is not None else os.name
	if effective_platform != "nt":
		return environment.get(name)
	matching_keys = _windows_environment_matching_keys(environment, name)
	if len(matching_keys) > 1:
		raise EnvironmentNameAmbiguityError(
			f"Frozen Windows environment contains ambiguous {name} entries."
		)
	return environment[matching_keys[0]] if matching_keys else None


def set_owned_environment_value(
	environment: dict[str, str],
	name: str,
	value: str,
	*,
	platform_name: str | None = None,
) -> None:
	"""Set one caller-owned environment value with target-platform semantics."""
	effective_platform = platform_name if platform_name is not None else os.name
	if effective_platform != "nt":
		environment[name] = value
		return
	# Validate the caller-owned snapshot before mutating it.  A single differently
	# cased key is the same Windows variable and is replaced by the canonical name;
	# multiple folded matches are ambiguous input and must fail closed.
	matching_keys = _windows_environment_matching_keys(environment, name)
	if len(matching_keys) > 1:
		raise EnvironmentNameAmbiguityError(
			f"Frozen Windows environment contains ambiguous {name} entries."
		)
	# Publish the replacement before removing a differently cased alias so a
	# failed dict assignment cannot erase the caller's existing value.
	environment[name] = value
	if matching_keys and matching_keys[0] != name:
		del environment[matching_keys[0]]


def remove_owned_environment_value(
	environment: dict[str, str],
	name: str,
	*,
	platform_name: str | None = None,
) -> None:
	"""Remove one caller-owned environment value with target-platform semantics."""
	effective_platform = platform_name if platform_name is not None else os.name
	if effective_platform != "nt":
		environment.pop(name, None)
		return
	for key in _windows_environment_matching_keys(environment, name):
		del environment[key]


def resolve_frozen_executable(
	candidate: str,
	*,
	environment: Mapping[str, str],
	cwd: Path,
	platform_name: str | None = None,
) -> str:
	"""Resolve one executable without consulting ambient environment or cwd."""
	if type(candidate) is not str or not candidate:
		raise ValueError("Executable resolution requires a non-empty string candidate.")
	effective_platform = platform_name if platform_name is not None else os.name
	has_drive_relative_input = (
		effective_platform == "nt"
		and _windows_search_has_drive_relative_input(candidate, environment)
	)
	if has_drive_relative_input:
		raise ExecutableResolutionError(
			"Windows drive-relative executable search inputs cannot be resolved "
			"from the frozen cwd/PATH search."
		)
	path_module = ntpath if effective_platform == "nt" else posixpath
	if path_module.basename(candidate) in {"", ".", ".."}:
		raise ExecutableResolutionError(
			"Executable candidate must identify a file in the frozen search inputs."
		)
	effective_cwd = Path(cwd)
	if not effective_cwd.is_absolute():
		raise ValueError("Executable resolution requires an absolute cwd.")
	resolved_path = _find_executable(
		candidate,
		environment=environment,
		platform_name=effective_platform,
		cwd=effective_cwd,
	)
	if resolved_path is None:
		raise ExecutableResolutionError(
			"Executable could not be resolved from the frozen cwd/PATH search."
		)
	return str(resolved_path.resolve())


def _find_executable(
	candidate: str,
	*,
	environment: Mapping[str, str],
	platform_name: str,
	cwd: Path,
) -> Path | None:
	"""Find an executable using only the supplied environment and cwd."""
	path_module = ntpath if platform_name == "nt" else posixpath
	if platform_name == "nt" and _windows_search_has_drive_relative_input(
		candidate,
		environment,
	):
		return None
	candidate_path = _host_path(candidate, platform_name)
	has_directory = bool(path_module.dirname(candidate))
	search_roots: list[Path]
	if has_directory:
		search_roots = [cwd]
	else:
		path_value_or_none = frozen_environment_value(
			environment,
			"PATH",
			platform_name=platform_name,
		)
		path_present = path_value_or_none is not None
		path_value = path_value_or_none or ""
		path_entries = (
			path_value.split(_path_list_separator(platform_name))
			if path_value or (path_present and platform_name != "nt")
			else []
		)
		path_roots = [
			cwd if not entry else _absolute_search_root(
				_host_path(entry, platform_name),
				cwd,
			)
			for entry in path_entries
		]
		if platform_name == "nt":
			search_roots = [
				*([cwd] if _windows_default_cwd_search_enabled(environment) else []),
				*path_roots,
			]
		else:
			search_roots = path_roots
	file_names = (
		(candidate_path.name,)
		if has_directory
		else _executable_file_names(
			candidate_path.name,
			environment=environment,
			platform_name=platform_name,
		)
	)
	for search_root in search_roots:
		base_path = (
			candidate_path
			if candidate_path.is_absolute()
			else search_root / candidate_path
		)
		for file_name in file_names:
			path = base_path.with_name(file_name)
			if not path.is_file():
				continue
			if platform_name != "nt" and not os.access(path, os.X_OK):
				continue
			return path
	return None


def _host_path(value: str, platform_name: str) -> Path:
	"""Represent target-platform separators on the current host filesystem."""
	if platform_name == "nt" and os.name != "nt":
		return Path(value.replace("\\", "/"))
	if platform_name != "nt" and os.name == "nt":
		return Path(value.replace("/", "\\"))
	return Path(value)


def _absolute_search_root(path: Path, cwd: Path) -> Path:
	return path if path.is_absolute() else cwd / path


def _is_windows_drive_relative(value: str) -> bool:
	"""Reject Windows paths that depend on an ambient per-drive cwd."""
	drive, _tail = ntpath.splitdrive(value)
	return bool(drive) and not ntpath.isabs(value)


def _windows_search_has_drive_relative_input(
	candidate: str,
	environment: Mapping[str, str],
) -> bool:
	"""Classify unsafe Windows search inputs without touching the filesystem."""
	if _is_windows_drive_relative(candidate):
		return True
	if ntpath.dirname(candidate):
		return False
	path_value = frozen_environment_value(
		environment,
		"PATH",
		platform_name="nt",
	) or ""
	return any(
		entry and _is_windows_drive_relative(entry)
		for entry in path_value.split(WINDOWS_PATH_LIST_SEPARATOR)
	)


def _path_list_separator(platform_name: str) -> str:
	return (
		WINDOWS_PATH_LIST_SEPARATOR
		if platform_name == "nt"
		else POSIX_PATH_LIST_SEPARATOR
	)


def _windows_default_cwd_search_enabled(
	environment: Mapping[str, str],
) -> bool:
	"""Mirror Windows bare-command cwd suppression using the frozen environment."""
	return frozen_environment_value(
		environment,
		WINDOWS_NO_DEFAULT_CWD_ENV_VAR,
		platform_name="nt",
	) is None


def _executable_file_names(
	name: str,
	*,
	environment: Mapping[str, str],
	platform_name: str,
) -> tuple[str, ...]:
	if platform_name != "nt":
		return (name,)
	pathext_value = frozen_environment_value(
		environment,
		"PATHEXT",
		platform_name=platform_name,
	) or ""
	extensions = tuple(
		extension if extension.startswith(".") else f".{extension}"
		for extension in (
			part.strip()
			for part in pathext_value.split(_path_list_separator(platform_name))
		)
		if extension
	) or WINDOWS_DEFAULT_PATHEXT
	recognized_extensions = tuple(dict.fromkeys([
		*extensions,
		*WINDOWS_DEFAULT_PATHEXT,
	]))
	if any(
		name.casefold().endswith(extension.casefold())
		for extension in recognized_extensions
	):
		return (name,)
	return tuple(f"{name}{extension}" for extension in extensions)
