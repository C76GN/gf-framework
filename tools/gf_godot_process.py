#!/usr/bin/env python3
"""Resolve a foreground Godot executable for deterministic maintenance runs."""

from __future__ import annotations

import ntpath
import os
import posixpath
from dataclasses import dataclass
from collections.abc import Mapping
from collections.abc import Sequence
from pathlib import Path


GODOT_EXECUTABLE_ENV_VAR = "GF_GODOT_EXECUTABLE"
WINDOWS_STEAM_ENGINE_NAME = "godot.windows.opt.tools.64.exe"
WINDOWS_DEFAULT_PATHEXT = (".COM", ".EXE", ".BAT", ".CMD")


@dataclass(frozen=True)
class CommandIdentity:
	"""Bind a declared argv to the exact argv selected for execution."""

	declared: tuple[str, ...]
	effective: tuple[str, ...]


def resolve_godot_executable(
	configured: str = "godot",
	*,
	environment: Mapping[str, str] | None = None,
	platform_name: str | None = None,
	cwd: Path | None = None,
) -> str:
	"""Resolve Godot while bypassing the detached Steam launcher on Windows."""
	env = environment if environment is not None else os.environ
	candidate = env.get(GODOT_EXECUTABLE_ENV_VAR, "").strip() or configured
	effective_platform = platform_name if platform_name is not None else os.name
	effective_cwd = (cwd if cwd is not None else Path.cwd()).resolve()
	resolved_path = _find_executable(
		candidate,
		environment=env,
		platform_name=effective_platform,
		cwd=effective_cwd,
	)
	if resolved_path is None:
		return candidate
	if effective_platform == "nt" and resolved_path.name.casefold() == "godot.exe":
		steam_engine = resolved_path.with_name(WINDOWS_STEAM_ENGINE_NAME)
		if steam_engine.is_file():
			return str(steam_engine.resolve())
	return str(resolved_path.resolve())


def resolve_godot_command(
	command: Sequence[str],
	*,
	environment: Mapping[str, str] | None = None,
	cwd: Path | None = None,
) -> list[str]:
	if not command or not looks_like_godot_executable(command[0]):
		return list(command)
	return [
		resolve_godot_executable(
			command[0],
			environment=environment,
			cwd=cwd,
		),
		*command[1:],
	]


def resolve_command_identity(
	command: Sequence[str],
	*,
	environment: Mapping[str, str] | None = None,
	cwd: Path | None = None,
) -> CommandIdentity:
	"""Resolve one immutable declared/effective command pair exactly once."""
	declared = tuple(command)
	if not declared or any(type(part) is not str for part in declared):
		raise ValueError("Command identity requires a non-empty string argv.")
	return CommandIdentity(
		declared=declared,
		effective=tuple(
			resolve_godot_command(
				declared,
				environment=environment,
				cwd=cwd,
			)
		),
	)


def _find_executable(
	candidate: str,
	*,
	environment: Mapping[str, str],
	platform_name: str,
	cwd: Path,
) -> Path | None:
	"""Find an executable using only the supplied environment and cwd."""
	candidate_path = Path(candidate)
	path_module = ntpath if platform_name == "nt" else posixpath
	has_directory = bool(path_module.dirname(candidate))
	search_roots: list[Path]
	if has_directory:
		search_roots = [cwd]
	else:
		path_value = environment.get("PATH", "")
		if not path_value and platform_name != "nt":
			return None
		path_roots = [
			cwd if not entry else _absolute_search_root(Path(entry), cwd)
			for entry in path_value.split(os.pathsep)
		] if path_value else []
		windows_cwd_lookup_enabled = not _environment_has_nonempty_value_case_insensitive(
			environment,
			"NoDefaultCurrentDirectoryInExePath",
		)
		search_roots = (
			[cwd, *path_roots]
			if platform_name == "nt" and windows_cwd_lookup_enabled
			else path_roots
		)
	file_names = _executable_file_names(
		candidate_path.name,
		environment=environment,
		platform_name=platform_name,
	)
	for search_root in search_roots:
		base_path = candidate_path if candidate_path.is_absolute() else search_root / candidate_path
		for file_name in file_names:
			path = base_path.with_name(file_name)
			if not path.is_file():
				continue
			if platform_name != "nt" and not os.access(path, os.X_OK):
				continue
			return path
	return None


def _environment_has_nonempty_value_case_insensitive(
	environment: Mapping[str, str],
	key: str,
) -> bool:
	"""Match one non-empty Windows environment value without ambient state."""
	key_folded = key.casefold()
	return any(
		name.casefold() == key_folded and value != ""
		for name, value in environment.items()
	)


def _absolute_search_root(path: Path, cwd: Path) -> Path:
	return path if path.is_absolute() else cwd / path


def _executable_file_names(
	name: str,
	*,
	environment: Mapping[str, str],
	platform_name: str,
) -> tuple[str, ...]:
	if platform_name != "nt":
		return (name,)
	pathext_value = environment.get("PATHEXT", "")
	extensions = tuple(
		extension if extension.startswith(".") else f".{extension}"
		for extension in (
			part.strip()
			for part in pathext_value.split(os.pathsep)
		)
		if extension
	) or WINDOWS_DEFAULT_PATHEXT
	if any(name.casefold().endswith(extension.casefold()) for extension in extensions):
		return (name,)
	return tuple(f"{name}{extension}" for extension in extensions)


def looks_like_godot_executable(value: str) -> bool:
	name = Path(value).name.casefold()
	return (
		name in {"godot", "godot.exe", WINDOWS_STEAM_ENGINE_NAME}
		or name.startswith("godot_")
		or name.startswith("godot-v")
	)
