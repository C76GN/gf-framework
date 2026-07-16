#!/usr/bin/env python3
"""Deterministic package manifest path matching shared by GF maintenance tools."""

from __future__ import annotations

import fnmatch
from collections.abc import Callable
from typing import Any


def normalize_manifest_path(path: str) -> str:
	"""Normalize manifest syntax without resolving it against the filesystem."""
	normalized = path.strip().replace("\\", "/")
	if normalized.startswith("res://"):
		normalized = normalized.removeprefix("res://")
	if normalized.startswith("./"):
		normalized = normalized[2:]
	return normalized.strip("/")


def manifest_pattern_has_magic(pattern: str) -> bool:
	return any(character in pattern for character in "*?[")


def manifest_path_matches(path: str, raw_pattern: str) -> bool:
	"""Match portable Godot paths with identical case-sensitive semantics on every OS."""
	normalized_path = normalize_manifest_path(path)
	pattern = normalize_manifest_path(raw_pattern)
	if not normalized_path or not pattern:
		return False
	if pattern.endswith("/**") and not manifest_pattern_has_magic(pattern[:-3]):
		root = pattern[:-3].rstrip("/")
		return normalized_path == root or normalized_path.startswith(root + "/")
	if not manifest_pattern_has_magic(pattern):
		return normalized_path == pattern
	return fnmatch.fnmatchcase(normalized_path, pattern)


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
			pattern = normalize_manifest_path(entry.get(pattern_field, ""))
			if not pattern:
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
		if not normalized_path:
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
