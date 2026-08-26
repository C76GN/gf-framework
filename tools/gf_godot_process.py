#!/usr/bin/env python3
"""Resolve a foreground Godot executable for deterministic maintenance runs."""

from __future__ import annotations

import os
from dataclasses import dataclass
from collections.abc import Mapping
from collections.abc import Sequence
from pathlib import Path

from gf_executable_resolution import ExecutableResolutionError
from gf_executable_resolution import frozen_environment_value
from gf_executable_resolution import resolve_frozen_executable


GODOT_EXECUTABLE_ENV_VAR = "GF_GODOT_EXECUTABLE"
WINDOWS_STEAM_ENGINE_NAME = "godot.windows.opt.tools.64.exe"


class GodotExecutableResolutionError(ExecutableResolutionError):
	"""Raised when a Godot selection has no match in the frozen search inputs."""


@dataclass(frozen=True)
class CommandIdentity:
	"""Bind a declared argv to the exact argv selected for execution."""

	declared: tuple[str, ...]
	effective: tuple[str, ...]


def resolve_godot_executable(
	configured: str = "godot",
	*,
	environment: Mapping[str, str],
	cwd: Path,
	platform_name: str | None = None,
) -> str:
	"""Resolve Godot while bypassing the detached Steam launcher on Windows."""
	effective_platform = platform_name if platform_name is not None else os.name
	try:
		configured_override = frozen_environment_value(
			environment,
			GODOT_EXECUTABLE_ENV_VAR,
			platform_name=effective_platform,
		) or ""
		candidate = configured_override.strip() or configured
		resolved_path = Path(resolve_frozen_executable(
			candidate,
			environment=environment,
			platform_name=effective_platform,
			cwd=cwd,
		))
	except ExecutableResolutionError as error:
		raise GodotExecutableResolutionError(
			"Godot executable could not be resolved from the frozen cwd/PATH search."
		) from error
	if effective_platform == "nt" and resolved_path.name.casefold() == "godot.exe":
		steam_engine = resolved_path.with_name(WINDOWS_STEAM_ENGINE_NAME)
		if steam_engine.is_file():
			return str(steam_engine.resolve())
	return str(resolved_path.resolve())


def resolve_godot_command(
	command: Sequence[str],
	*,
	environment: Mapping[str, str],
	cwd: Path,
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
	environment: Mapping[str, str],
	cwd: Path,
) -> CommandIdentity:
	"""Resolve one immutable declared/effective command pair exactly once."""
	declared = tuple(command)
	if not declared or any(type(part) is not str for part in declared):
		raise ValueError("Command identity requires a non-empty string argv.")
	if looks_like_godot_executable(declared[0]):
		effective = tuple(
			resolve_godot_command(
				declared,
				environment=environment,
				cwd=cwd,
			)
		)
	else:
		effective = (
			resolve_frozen_executable(
				declared[0],
				environment=environment,
				cwd=cwd,
			),
			*declared[1:],
		)
	return CommandIdentity(
		declared=declared,
		effective=effective,
	)


def looks_like_godot_executable(value: str) -> bool:
	name = Path(value).name.casefold()
	return (
		name in {"godot", "godot.exe", WINDOWS_STEAM_ENGINE_NAME}
		or name.startswith("godot_")
		or name.startswith("godot-v")
	)
