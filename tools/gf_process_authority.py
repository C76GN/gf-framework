#!/usr/bin/env python3
"""Immutable executable and environment authority for maintenance subprocesses."""

from __future__ import annotations

import contextvars
import os
from collections.abc import Mapping
from collections.abc import Sequence
from contextlib import contextmanager
from dataclasses import dataclass
from dataclasses import field
from pathlib import Path
from typing import Iterator

from gf_executable_resolution import ExecutableResolutionError
from gf_executable_resolution import set_owned_environment_value
from gf_godot_process import CommandIdentity
from gf_godot_process import resolve_command_identity


GIT_OPTIONAL_LOCKS_ENVIRONMENT = "GIT_OPTIONAL_LOCKS"
GIT_AUTHORITY_ENVIRONMENT_VALUES = (
	("GIT_NO_REPLACE_OBJECTS", "1"),
	(GIT_OPTIONAL_LOCKS_ENVIRONMENT, "0"),
	("GIT_CONFIG_NOSYSTEM", "1"),
	("GIT_TERMINAL_PROMPT", "0"),
	("LC_ALL", "C"),
	("LANG", "C"),
)


class GitExecutableResolutionError(ExecutableResolutionError):
	"""Raised when the invocation cannot bind its mandatory Git capability."""


@dataclass(frozen=True)
class FrozenProcessEnvironment:
	"""Own one by-value environment snapshot used for resolution and dispatch."""

	_items: tuple[tuple[str, str], ...] = field(repr=False)

	@classmethod
	def capture(cls, environment: Mapping[str, str]) -> FrozenProcessEnvironment:
		items = tuple(environment.items())
		if any(
			type(name) is not str
			or not name
			or "\0" in name
			or "=" in name
			or type(value) is not str
			or "\0" in value
			for name, value in items
		):
			raise ValueError("Frozen process environment contains an invalid entry.")
		if len({name for name, _value in items}) != len(items):
			raise ValueError("Frozen process environment contains duplicate names.")
		return cls(items)

	def values(self) -> dict[str, str]:
		return dict(self._items)

	def resolve(
		self,
		command: Sequence[str],
		*,
		cwd: Path,
	) -> CommandIdentity:
		return resolve_command_identity(
			command,
			environment=self.values(),
			cwd=cwd,
		)


@dataclass(frozen=True)
class FrozenGitProcess:
	"""Bind every Git workspace operation to one executable and environment."""

	identity: CommandIdentity
	environment: FrozenProcessEnvironment = field(repr=False)
	resolution_cwd: Path

	def __post_init__(self) -> None:
		if not isinstance(self.identity, CommandIdentity):
			raise TypeError("Frozen Git authority requires a command identity.")
		if not isinstance(self.environment, FrozenProcessEnvironment):
			raise TypeError("Frozen Git authority requires a frozen environment.")
		if self.identity.declared != ("git",):
			raise ValueError("Frozen Git authority must retain the declared 'git' command.")
		if len(self.identity.effective) != 1 or not Path(
			self.identity.effective[0]
		).is_absolute():
			raise ValueError("Frozen Git authority requires one absolute executable.")
		if not Path(self.resolution_cwd).is_absolute():
			raise ValueError("Frozen Git authority requires an absolute resolution cwd.")

	@property
	def executable(self) -> str:
		return self.identity.effective[0]

	def command(self, arguments: Sequence[str]) -> CommandIdentity:
		if isinstance(arguments, (str, bytes)):
			raise TypeError("Git command arguments require a sequence, not text.")
		arguments_tuple = tuple(arguments)
		if any(type(argument) is not str or "\0" in argument for argument in arguments_tuple):
			raise ValueError("Git command arguments must be strings without NUL bytes.")
		return CommandIdentity(
			declared=("git", *arguments_tuple),
			effective=(self.executable, *arguments_tuple),
		)


@dataclass(frozen=True)
class FrozenProcessAuthority:
	"""Pair one invocation environment with its mandatory Git capability."""

	environment: FrozenProcessEnvironment = field(repr=False)
	git: FrozenGitProcess

	def __post_init__(self) -> None:
		if not isinstance(self.environment, FrozenProcessEnvironment):
			raise TypeError("Process authority requires a frozen environment.")
		if not isinstance(self.git, FrozenGitProcess):
			raise TypeError("Process authority requires a frozen Git capability.")
		expected_git_environment = _derive_git_environment(self.environment)
		if self.git.environment.values() != expected_git_environment:
			raise ValueError(
				"Frozen Git capability is not derived from the paired process environment."
			)


def freeze_git_process(
	process_environment: FrozenProcessEnvironment,
	*,
	cwd: Path,
) -> FrozenGitProcess:
	"""Resolve Git once and derive its no-lock, by-value child environment."""
	if not isinstance(process_environment, FrozenProcessEnvironment):
		raise TypeError("Git process freezing requires a frozen environment.")
	environment = _derive_git_environment(process_environment)
	git_environment = FrozenProcessEnvironment.capture(environment)
	try:
		identity = git_environment.resolve(("git",), cwd=cwd)
	except ExecutableResolutionError as error:
		raise GitExecutableResolutionError(
			"Git executable could not be resolved from the frozen cwd/PATH search."
		) from error
	return FrozenGitProcess(
		identity=identity,
		environment=git_environment,
		resolution_cwd=Path(cwd),
	)


def _derive_git_environment(
	process_environment: FrozenProcessEnvironment,
) -> dict[str, str]:
	"""Remove inherited Git redirection/config authority, then add owned policy."""
	environment = process_environment.values()
	for name in tuple(environment):
		is_git_name = (
			name.upper().startswith("GIT_")
			if os.name == "nt"
			else name.startswith("GIT_")
		)
		if is_git_name:
			del environment[name]
	for name, value in GIT_AUTHORITY_ENVIRONMENT_VALUES:
		set_owned_environment_value(environment, name, value)
	return environment


def freeze_process_authority(
	process_environment: FrozenProcessEnvironment,
	*,
	cwd: Path,
) -> FrozenProcessAuthority:
	"""Freeze one exact invocation authority before any workspace Git I/O."""
	if not isinstance(process_environment, FrozenProcessEnvironment):
		raise TypeError("Process authority freezing requires a frozen environment.")
	return FrozenProcessAuthority(
		environment=process_environment,
		git=freeze_git_process(process_environment, cwd=cwd),
	)


_ACTIVE_PROCESS_ENVIRONMENT: contextvars.ContextVar[
	FrozenProcessEnvironment | None
] = contextvars.ContextVar("gf_active_process_environment", default=None)
_ACTIVE_PROCESS_AUTHORITY: contextvars.ContextVar[
	FrozenProcessAuthority | None
] = contextvars.ContextVar("gf_active_process_authority", default=None)


def active_process_environment() -> FrozenProcessEnvironment | None:
	return _ACTIVE_PROCESS_ENVIRONMENT.get()


def active_git_process() -> FrozenGitProcess | None:
	authority = _ACTIVE_PROCESS_AUTHORITY.get()
	return None if authority is None else authority.git


def active_process_authority() -> FrozenProcessAuthority | None:
	return _ACTIVE_PROCESS_AUTHORITY.get()


@contextmanager
def activate_process_environment(
	process_environment: FrozenProcessEnvironment,
) -> Iterator[None]:
	if not isinstance(process_environment, FrozenProcessEnvironment):
		raise TypeError("Active process environment must be frozen by value.")
	token = _ACTIVE_PROCESS_ENVIRONMENT.set(process_environment)
	try:
		yield
	finally:
		_ACTIVE_PROCESS_ENVIRONMENT.reset(token)


@contextmanager
def activate_process_context(
	process_authority: FrozenProcessAuthority,
) -> Iterator[None]:
	if not isinstance(process_authority, FrozenProcessAuthority):
		raise TypeError("Active process context requires one frozen authority.")
	environment_token = _ACTIVE_PROCESS_ENVIRONMENT.set(process_authority.environment)
	authority_token = _ACTIVE_PROCESS_AUTHORITY.set(process_authority)
	try:
		yield
	finally:
		_ACTIVE_PROCESS_AUTHORITY.reset(authority_token)
		_ACTIVE_PROCESS_ENVIRONMENT.reset(environment_token)
