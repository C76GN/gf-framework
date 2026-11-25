#!/usr/bin/env python3
"""为维护进程解析前台 Godot 可执行文件，确保调用方跟踪到实际运行的引擎。"""

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
	"""冻结的搜索输入中没有可供选择的 Godot 引擎。"""


@dataclass(frozen=True)
class CommandIdentity:
	"""将声明的参数序列绑定到真正用于执行的参数序列。"""

	declared: tuple[str, ...]
	effective: tuple[str, ...]


def resolve_godot_executable(
	configured: str = "godot",
	*,
	environment: Mapping[str, str],
	cwd: Path,
	platform_name: str | None = None,
) -> str:
	"""在冻结环境中选择前台 Godot 引擎，Windows 的 Steam 安装优先选同目录的实际引擎。"""
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
	"""按传入的环境和工作目录解析 Godot 命令的可执行文件，其他种类命令保留参数内容。"""
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
	"""只解析一次并固定命令的声明参数与实际执行参数。"""
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
