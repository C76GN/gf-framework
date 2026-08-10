#!/usr/bin/env python3
"""Deterministic package manifest path matching shared by GF maintenance tools."""

from __future__ import annotations

from collections.abc import Callable
from typing import Any


_WINDOWS_INVALID_PATH_CHARACTERS = '<>:"/\\|'
_WINDOWS_RESERVED_DEVICE_STEMS = {"CON", "PRN", "AUX", "NUL"}
_WINDOWS_RESERVED_DEVICE_PREFIXES = {"COM", "LPT"}
_WINDOWS_RESERVED_DEVICE_NUMBERS = "123456789¹²³"


def normalize_manifest_path(path: str) -> str:
	"""Normalize manifest syntax without resolving it against the filesystem."""
	normalized = path.strip().replace("\\", "/")
	if normalized.startswith("res://"):
		normalized = normalized.removeprefix("res://")
	if normalized.startswith("./"):
		normalized = normalized[2:]
	return normalized.strip("/")


def manifest_pattern_has_magic(pattern: str) -> bool:
	return any(character in pattern for character in "*?")


def portable_path_component_is_valid(component: str, *, allow_manifest_glob_characters: bool) -> bool:
	"""Apply GF's platform-independent package path component policy."""
	if (
		not component
		or component in {".", ".."}
		or component != component.rstrip(" .")
		or any(ord(character) < 32 for character in component)
	):
		return False
	invalid_characters = _WINDOWS_INVALID_PATH_CHARACTERS
	if not allow_manifest_glob_characters:
		invalid_characters += "?*"
	if any(character in invalid_characters for character in component):
		return False
	if allow_manifest_glob_characters and "**" in component and component != "**":
		return False
	device_stem = component.split(".", 1)[0].upper()
	if device_stem in _WINDOWS_RESERVED_DEVICE_STEMS:
		return False
	if (
		len(device_stem) == 4
		and device_stem[:3] in _WINDOWS_RESERVED_DEVICE_PREFIXES
		and device_stem[3] in _WINDOWS_RESERVED_DEVICE_NUMBERS
	):
		return False
	return True


def manifest_pattern_is_supported(pattern: str) -> bool:
	parts = pattern.split("/")
	for index, part in enumerate(parts):
		if (
			not portable_path_component_is_valid(part, allow_manifest_glob_characters=True)
			or (part == "**" and index != len(parts) - 1)
		):
			return False
	return True


def portable_literal_path_identity(path: str) -> str:
	"""Return GF's case-insensitive portable identity for a canonical relative literal path."""
	if not path or path != path.strip() or "\\" in path or path.startswith("/"):
		return ""
	parts = path.split("/")
	if not all(
		portable_path_component_is_valid(part, allow_manifest_glob_characters=False)
		for part in parts
	):
		return ""
	return "/".join(part.lower() for part in parts)


def portable_manifest_path_identity(path: str) -> str:
	"""Return a portable identity for a canonical manifest path, or ``""`` when unsafe."""
	if not path or path != path.strip() or "\\" in path or normalize_manifest_path(path) != path:
		return ""
	if not manifest_pattern_is_supported(path):
		return ""
	return "/".join(part.lower() for part in path.split("/"))


def manifest_segment_matches(value: str, pattern: str) -> bool:
	"""Match one path segment where only ``*`` and ``?`` have glob meaning."""
	pattern_index = 0
	value_index = 0
	star_index = -1
	match_index = 0
	while value_index < len(value):
		if (
			pattern_index < len(pattern)
			and (pattern[pattern_index] == value[value_index] or pattern[pattern_index] == "?")
		):
			pattern_index += 1
			value_index += 1
		elif pattern_index < len(pattern) and pattern[pattern_index] == "*":
			star_index = pattern_index
			match_index = value_index
			pattern_index += 1
		elif star_index >= 0:
			pattern_index = star_index + 1
			match_index += 1
			value_index = match_index
		else:
			return False
	while pattern_index < len(pattern) and pattern[pattern_index] == "*":
		pattern_index += 1
	return pattern_index == len(pattern)


def manifest_path_matches(path: str, raw_pattern: str) -> bool:
	"""Match portable Godot paths with identical case-sensitive semantics on every OS."""
	normalized_path = normalize_manifest_path(path)
	pattern = raw_pattern
	if (
		not portable_literal_path_identity(normalized_path)
		or not portable_manifest_path_identity(pattern)
	):
		return False
	path_parts = normalized_path.split("/")
	pattern_parts = pattern.split("/")
	has_recursive_tail = pattern_parts[-1] == "**"
	matched_part_count = len(pattern_parts) - 1 if has_recursive_tail else len(pattern_parts)
	if len(path_parts) < matched_part_count:
		return False
	if not has_recursive_tail and len(path_parts) != matched_part_count:
		return False
	return all(
		manifest_segment_matches(path_parts[index], pattern_parts[index])
		for index in range(matched_part_count)
	)


def path_matches_any_manifest_path(path: str, patterns: list[str]) -> bool:
	return any(manifest_path_matches(path, pattern) for pattern in patterns)


class ManifestPathIndex:
	"""Index exact, recursive-prefix, and fallback glob ownership patterns."""

	def __init__(
		self,
		entries: list[dict[str, str]],
		*,
		pattern_field: str = "pattern",
		path_normalizer: Callable[[str], str] = normalize_manifest_path,
	) -> None:
		self._entries = entries
		self._pattern_field = pattern_field
		self._path_normalizer = path_normalizer
		self._exact: dict[str, list[tuple[int, dict[str, str]]]] = {}
		self._recursive: dict[str, list[tuple[int, dict[str, str]]]] = {}
		self._fallback: list[tuple[int, dict[str, str]]] = []
		self._matches_by_path: dict[str, list[dict[str, str]]] = {}
		for order, entry in enumerate(entries):
			pattern = entry.get(pattern_field, "")
			if not isinstance(pattern, str) or not portable_manifest_path_identity(pattern):
				continue
			indexed_entry = (order, entry)
			if pattern.endswith("/**") and not manifest_pattern_has_magic(pattern[:-3]):
				root = pattern[:-3].rstrip("/")
				self._recursive.setdefault(root, []).append(indexed_entry)
			elif not manifest_pattern_has_magic(pattern):
				self._exact.setdefault(pattern, []).append(indexed_entry)
			else:
				self._fallback.append(indexed_entry)

	def __bool__(self) -> bool:
		return bool(self._entries)

	def find_one(self, path: str) -> dict[str, str] | None:
		matches = self.find_all(path)
		return matches[0] if len(matches) == 1 else None

	def find_all(self, path: str) -> list[dict[str, str]]:
		normalized_path = self._path_normalizer(path)
		if not normalized_path or not portable_literal_path_identity(normalized_path):
			return []
		cached = self._matches_by_path.get(normalized_path)
		if cached is not None:
			return cached

		matches = list(self._exact.get(normalized_path, []))
		parts = normalized_path.split("/")
		for part_count in range(1, len(parts) + 1):
			root = "/".join(parts[:part_count])
			matches.extend(self._recursive.get(root, []))
		for indexed_entry in self._fallback:
			if manifest_path_matches(normalized_path, indexed_entry[1][self._pattern_field]):
				matches.append(indexed_entry)
		matches.sort(key=lambda item: item[0])
		result = [entry for _order, entry in matches]
		self._matches_by_path[normalized_path] = result
		return result

	def stats(self) -> dict[str, Any]:
		return {
			"entry_count": len(self._entries),
			"exact_pattern_count": sum(len(entries) for entries in self._exact.values()),
			"recursive_pattern_count": sum(len(entries) for entries in self._recursive.values()),
			"fallback_pattern_count": len(self._fallback),
			"cached_path_count": len(self._matches_by_path),
		}
