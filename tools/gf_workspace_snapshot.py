#!/usr/bin/env python3
"""Invocation-scoped read cache for GF maintenance suites."""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path
from typing import Any
from typing import Hashable
from typing import TypeVar


Value = TypeVar("Value")


class WorkspaceSnapshot:
	"""Cache immutable workspace reads for one maintenance suite invocation."""

	def __init__(self, root: Path) -> None:
		self.root = root
		self._text_by_identity: dict[tuple[str, int, int], str] = {}
		self._identity_by_path: dict[str, tuple[str, int, int]] = {}
		self._values: dict[tuple[str, Hashable], Any] = {}
		self._text_hits = 0
		self._text_misses = 0
		self._value_hits = 0
		self._value_misses = 0

	def read_utf8_text(self, path: Path) -> str:
		try:
			return self.read_utf8_text_strict(path)
		except OSError:
			return ""

	def read_utf8_text_strict(self, path: Path) -> str:
		file_stat = path.stat()
		path_key = str(path)
		identity = (path_key, file_stat.st_mtime_ns, file_stat.st_size)
		cached = self._text_by_identity.get(identity)
		if cached is not None:
			self._text_hits += 1
			return cached
		text = path.read_text(encoding="utf-8")
		previous_identity = self._identity_by_path.get(path_key)
		if previous_identity is not None and previous_identity != identity:
			self._text_by_identity.pop(previous_identity, None)
		self._text_by_identity[identity] = text
		self._identity_by_path[path_key] = identity
		self._text_misses += 1
		return text

	def memoize(
		self,
		namespace: str,
		key: Hashable,
		factory: Callable[[], Value],
	) -> Value:
		cache_key = (namespace, key)
		if cache_key in self._values:
			self._value_hits += 1
			return self._values[cache_key]
		value = factory()
		self._values[cache_key] = value
		self._value_misses += 1
		return value

	def stats(self) -> dict[str, int]:
		return {
			"text_entry_count": len(self._text_by_identity),
			"text_cache_hits": self._text_hits,
			"text_cache_misses": self._text_misses,
			"value_entry_count": len(self._values),
			"value_cache_hits": self._value_hits,
			"value_cache_misses": self._value_misses,
		}
