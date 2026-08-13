#!/usr/bin/env python3
"""Isolated read-only worker for GF static validation eligibility observation."""

from __future__ import annotations

import json
import hashlib
import os
import stat
import sys
import unicodedata
from pathlib import Path
from typing import Any


WORKER_SCHEMA_VERSION = 1
MAX_RUNTIME_FILES = 512
MAX_RUNTIME_FILE_BYTES = 64 * 1024 * 1024
MAX_RUNTIME_TOTAL_BYTES = 256 * 1024 * 1024
ALLOWED_CHECKS = frozenset({
	"package_user_dependency_boundary",
	"public_api_boundary",
	"public_docs_boundary",
})


def main() -> int:
	if len(sys.argv) != 2 or sys.argv[1] not in ALLOWED_CHECKS:
		return 2
	if (
		sys.flags.safe_path != 1
		or sys.flags.no_site != 1
		or sys.flags.dont_write_bytecode != 1
		or sys.flags.utf8_mode != 1
		or os.environ.get("PYTHONHASHSEED") != "0"
		or os.environ.get("PYTHONIOENCODING") != "utf-8"
		or os.environ.get("PYTHONUTF8") != "1"
	):
		return 2
	tools_root = Path(__file__).resolve().parent
	repository_root = tools_root.parent
	if Path.cwd().resolve() != repository_root:
		return 2
	sys.path.insert(0, str(tools_root))
	try:
		import gf_maintenance
		import gf_validation_evidence

		runners = {
			"package_user_dependency_boundary": gf_maintenance.package_user_dependency_boundary,
			"public_api_boundary": gf_maintenance.public_api_boundary,
			"public_docs_boundary": gf_maintenance.public_docs_boundary,
		}
		result = runners[sys.argv[1]]()
		runtime_manifest = _runtime_manifest(
			repository_root,
			gf_validation_evidence,
		)
		payload: dict[str, Any] = {
			"schema_version": WORKER_SCHEMA_VERSION,
			"check_name": sys.argv[1],
			"result": result,
			"runtime_manifest": runtime_manifest,
		}
		encoded = gf_validation_evidence.canonical_json_bytes(payload)
		expected_root = str(repository_root)
		if result.get("root") != expected_root:
			return 3
		sys.stdout.buffer.write(encoded + b"\n")
		sys.stdout.buffer.flush()
		return 0
	except Exception:
		return 3


def _runtime_manifest(repository_root: Path, evidence_module: Any) -> dict[str, Any]:
	"""Hash actual loaded runtime code without leaking absolute installation paths."""
	records: dict[tuple[str, str], dict[str, Any]] = {}
	candidates: list[tuple[str, Path]] = []
	for module_name, module in sorted(sys.modules.items()):
		origin = getattr(module, "__file__", None)
		if type(origin) is str:
			candidates.append((module_name, Path(origin)))
		cached = getattr(module, "__cached__", None)
		if type(cached) is str:
			cached_path = Path(cached)
			try:
				cached_path.lstat()
			except FileNotFoundError:
				pass
			except OSError as error:
				raise ValueError("runtime cached bytecode cannot be inspected") from error
			else:
				candidates.append((f"{module_name}:cached", cached_path))
	if os.name == "nt":
		for path in sorted(Path(sys.executable).resolve().parent.glob("python*.dll")):
			candidates.append((f"runtime_dll:{path.name.casefold()}", path))
	total_bytes = 0
	for module_name, path in candidates:
		resolved = path.resolve(strict=True)
		try:
			resolved.relative_to(repository_root)
		except ValueError:
			pass
		else:
			continue
		before = resolved.stat()
		if not stat.S_ISREG(before.st_mode) or before.st_size < 0 or before.st_size > MAX_RUNTIME_FILE_BYTES:
			raise ValueError("runtime file is not a bounded regular file")
		digest = hashlib.sha256()
		read_size = 0
		with resolved.open("rb") as stream:
			handle_before = os.fstat(stream.fileno())
			while True:
				chunk = stream.read(1024 * 1024)
				if not chunk:
					break
				read_size += len(chunk)
				digest.update(chunk)
			handle_after = os.fstat(stream.fileno())
		after = resolved.stat()
		identity = lambda value: (value.st_dev, value.st_ino, value.st_mode, value.st_size, value.st_mtime_ns)
		if read_size != before.st_size or identity(before) != identity(handle_before) or identity(handle_before) != identity(handle_after) or identity(handle_after) != identity(after):
			raise ValueError("runtime file drifted")
		total_bytes += read_size
		if total_bytes > MAX_RUNTIME_TOTAL_BYTES:
			raise ValueError("runtime manifest byte budget exceeded")
		key = (module_name, resolved.name.casefold())
		if key in records:
			raise ValueError("runtime manifest contains an ambiguous file identity")
		records[key] = {
			"module": module_name,
			"origin_name": resolved.name,
			"size_bytes": read_size,
			"sha256": digest.hexdigest(),
		}
	if len(records) > MAX_RUNTIME_FILES:
		raise ValueError("runtime manifest file budget exceeded")
	identity_payload = {
		"implementation": sys.implementation.name,
		"cache_tag": sys.implementation.cache_tag,
		"hexversion": sys.hexversion,
		"version": list(sys.version_info[:5]),
		"unicode_version": unicodedata.unidata_version,
	}
	files = [records[key] for key in sorted(records)]
	manifest = {
		"schema_version": 1,
		"identity": identity_payload,
		"file_count": len(files),
		"total_bytes": total_bytes,
		"files": files,
	}
	manifest["digest"] = evidence_module.canonical_json_sha256(
		manifest,
		domain=b"gf-python-runtime-manifest-v1\0",
	)
	return manifest


if __name__ == "__main__":
	# Isolated workers must not inherit a caller-selected module search path.
	os.environ.pop("PYTHONPATH", None)
	raise SystemExit(main())
