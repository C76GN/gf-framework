#!/usr/bin/env python3
"""Filesystem containment helpers shared by GF build and analysis tools."""

from __future__ import annotations

import os
import stat
from pathlib import Path


FILE_ATTRIBUTE_REPARSE_POINT = 0x0400


def absolute_lexical_path(path: Path) -> Path:
	"""Return an absolute path without resolving links or requiring existence."""
	return Path(os.path.abspath(os.fspath(path.expanduser())))


def path_is_inside_lexical(root: Path, child: Path) -> bool:
	"""Check lexical containment with platform case semantics."""
	root_path = absolute_lexical_path(root)
	child_path = absolute_lexical_path(child)
	try:
		common = os.path.commonpath((str(root_path), str(child_path)))
	except ValueError:
		return False
	return os.path.normcase(common) == os.path.normcase(str(root_path))


def path_is_inside(root: Path, child: Path) -> bool:
	"""Require both lexical and resolved containment."""
	if not path_is_inside_lexical(root, child):
		return False
	try:
		child.resolve().relative_to(root.resolve())
	except (OSError, ValueError):
		return False
	return True


def path_has_reparse_component(path: Path) -> bool:
	"""Fail closed when any existing ancestor is a link or Windows reparse point."""
	current = absolute_lexical_path(path)
	while True:
		try:
			metadata = os.lstat(current)
		except FileNotFoundError:
			pass
		except OSError:
			return True
		else:
			if stat.S_ISLNK(metadata.st_mode) or bool(
				int(getattr(metadata, "st_file_attributes", 0)) & FILE_ATTRIBUTE_REPARSE_POINT
			):
				return True
		if current == current.parent:
			return False
		current = current.parent
