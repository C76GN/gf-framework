#!/usr/bin/env python3
"""Strict SemVer 2.0 parsing and precedence helpers for GF tooling."""

from __future__ import annotations

import re
from dataclasses import dataclass
from functools import total_ordering


SEMVER_RE = re.compile(
	r"^(?P<major>0|[1-9][0-9]*)\."
	r"(?P<minor>0|[1-9][0-9]*)\."
	r"(?P<patch>0|[1-9][0-9]*)"
	r"(?:-(?P<prerelease>(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)"
	r"(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?"
	r"(?:\+(?P<build>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$"
)


@total_ordering
@dataclass(frozen=True, eq=False)
class SemVer:
	"""Parsed SemVer whose comparisons follow SemVer precedence rules."""

	major: int
	minor: int
	patch: int
	prerelease: tuple[str, ...] = ()
	build: tuple[str, ...] = ()

	def __eq__(self, other: object) -> bool:
		if not isinstance(other, SemVer):
			return NotImplemented
		return self.precedence_key == other.precedence_key

	def __lt__(self, other: object) -> bool:
		if not isinstance(other, SemVer):
			return NotImplemented
		return compare_semver(self, other) < 0

	def __hash__(self) -> int:
		return hash(self.precedence_key)

	@property
	def is_stable(self) -> bool:
		return not self.prerelease

	@property
	def precedence_key(self) -> tuple[int, int, int, tuple[str, ...]]:
		return (self.major, self.minor, self.patch, self.prerelease)


def parse_semver(value: str) -> SemVer | None:
	"""Parse a complete SemVer value; return None for malformed input."""

	text = value.strip()
	match = SEMVER_RE.fullmatch(text)
	if match is None:
		return None
	prerelease = tuple(match.group("prerelease").split(".")) if match.group("prerelease") else ()
	build = tuple(match.group("build").split(".")) if match.group("build") else ()
	return SemVer(
		major=int(match.group("major")),
		minor=int(match.group("minor")),
		patch=int(match.group("patch")),
		prerelease=prerelease,
		build=build,
	)


def compare_semver(left: SemVer, right: SemVer) -> int:
	"""Return -1, 0, or 1 using SemVer precedence, ignoring build metadata."""

	left_core = (left.major, left.minor, left.patch)
	right_core = (right.major, right.minor, right.patch)
	if left_core < right_core:
		return -1
	if left_core > right_core:
		return 1
	if not left.prerelease and not right.prerelease:
		return 0
	if not left.prerelease:
		return 1
	if not right.prerelease:
		return -1
	for left_identifier, right_identifier in zip(left.prerelease, right.prerelease):
		if left_identifier == right_identifier:
			continue
		left_numeric = left_identifier.isdigit()
		right_numeric = right_identifier.isdigit()
		if left_numeric and right_numeric:
			return -1 if int(left_identifier) < int(right_identifier) else 1
		if left_numeric:
			return -1
		if right_numeric:
			return 1
		return -1 if left_identifier < right_identifier else 1
	if len(left.prerelease) < len(right.prerelease):
		return -1
	if len(left.prerelease) > len(right.prerelease):
		return 1
	return 0


def reaches_exclusive_compatibility_bound(current: SemVer, maximum: SemVer) -> bool:
	"""Return whether a framework version reaches an exclusive compatibility line."""

	current_core = (current.major, current.minor, current.patch)
	maximum_core = (maximum.major, maximum.minor, maximum.patch)
	if current_core != maximum_core:
		return current_core > maximum_core
	if maximum.is_stable:
		return True
	return current >= maximum


def next_major_version(value: str) -> str:
	"""Return the next stable major boundary, or an empty string if invalid."""

	version = parse_semver(value)
	if version is None:
		return ""
	return f"{version.major + 1}.0.0"
