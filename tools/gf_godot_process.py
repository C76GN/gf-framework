#!/usr/bin/env python3
"""Resolve a foreground Godot executable for deterministic maintenance runs."""

from __future__ import annotations

import os
import shutil
from collections.abc import Mapping
from pathlib import Path


GODOT_EXECUTABLE_ENV_VAR = "GF_GODOT_EXECUTABLE"
WINDOWS_STEAM_ENGINE_NAME = "godot.windows.opt.tools.64.exe"


def resolve_godot_executable(
	configured: str = "godot",
	*,
	environment: Mapping[str, str] | None = None,
	platform_name: str | None = None,
) -> str:
	"""Resolve Godot while bypassing the detached Steam launcher on Windows."""
	env = environment if environment is not None else os.environ
	candidate = env.get(GODOT_EXECUTABLE_ENV_VAR, "").strip() or configured
	resolved = shutil.which(candidate) or candidate
	resolved_path = Path(resolved)
	effective_platform = platform_name if platform_name is not None else os.name
	if effective_platform == "nt" and resolved_path.name.casefold() == "godot.exe":
		steam_engine = resolved_path.with_name(WINDOWS_STEAM_ENGINE_NAME)
		if steam_engine.is_file():
			return str(steam_engine.resolve())
	if resolved_path.is_file():
		return str(resolved_path.resolve())
	return candidate


def resolve_godot_command(
	command: list[str],
	*,
	environment: Mapping[str, str] | None = None,
) -> list[str]:
	if not command or not looks_like_godot_executable(command[0]):
		return list(command)
	return [
		resolve_godot_executable(command[0], environment=environment),
		*command[1:],
	]


def looks_like_godot_executable(value: str) -> bool:
	name = Path(value).name.casefold()
	return (
		name in {"godot", "godot.exe", WINDOWS_STEAM_ENGINE_NAME}
		or name.startswith("godot_")
		or name.startswith("godot-v")
	)
