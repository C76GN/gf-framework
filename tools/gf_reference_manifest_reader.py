#!/usr/bin/env python3
"""Read the optional external reference-project manifest behind a narrow boundary."""

from __future__ import annotations

import argparse
import json
import os
import sys
import unicodedata
from pathlib import Path
from pathlib import PurePosixPath
from pathlib import PureWindowsPath
from typing import Any
from typing import Callable

import gf_path_security


REFERENCE_MANIFEST_NAME = ".gf_reference_project.json"
REFERENCE_MANIFEST_MAX_BYTES = 64 * 1024
REFERENCE_SCENE_MAX_CHARACTERS = 2048
REFERENCE_SCENE_MAX_UTF8_BYTES = 4096
REFERENCE_PROJECT_MAX_CHARACTERS = 4096
REFERENCE_PROJECT_MAX_UTF8_BYTES = 16 * 1024
RESPONSE_SCHEMA_VERSION = 1
_ALLOWED_MANIFEST_KEYS = frozenset({"boot_scene", "smoke_scene"})
_SUCCESS_RESPONSE_KEYS = frozenset({
	"schema_version",
	"ok",
	"manifest_present",
	"boot_scene",
	"smoke_scene",
})
_NATIVE_OS_NAME = os.name


class ReferenceManifestError(ValueError):
	"""Stable, path-free manifest contract failure."""

	def __init__(self, rule_id: str) -> None:
		super().__init__(rule_id)
		self.rule_id = rule_id


def _reject_json_constant(_value: str) -> Any:
	raise ReferenceManifestError("reference_manifest.invalid_json")


def _strict_json_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
	payload: dict[str, Any] = {}
	for key, value in pairs:
		if key in payload:
			raise ReferenceManifestError("reference_manifest.duplicate_key")
		payload[key] = value
	return payload


def _parse_strict_json_object(source: str) -> dict[str, Any]:
	try:
		payload = json.loads(
			source,
			object_pairs_hook=_strict_json_object,
			parse_constant=_reject_json_constant,
		)
	except ReferenceManifestError:
		raise
	except (json.JSONDecodeError, RecursionError):
		raise ReferenceManifestError("reference_manifest.invalid_json") from None
	if type(payload) is not dict:
		raise ReferenceManifestError("reference_manifest.invalid_top_level")
	return payload


def _contains_path_control_character(value: str) -> bool:
	return any(
		unicodedata.category(character) in {"Cc", "Cf", "Cs"}
		for character in value
	)


def validate_reference_project(value: Any) -> str:
	"""Validate one bounded, explicit filesystem path without resolving it."""
	if type(value) is not str:
		raise ReferenceManifestError("reference_manifest.invalid_project_root")
	try:
		encoded = value.encode("utf-8", errors="strict")
	except UnicodeEncodeError:
		raise ReferenceManifestError(
			"reference_manifest.invalid_project_root"
		) from None
	trimmed = value.strip()
	try:
		trimmed_encoded = trimmed.encode("utf-8", errors="strict")
	except UnicodeEncodeError:
		raise ReferenceManifestError(
			"reference_manifest.invalid_project_root"
		) from None
	native_is_windows = _NATIVE_OS_NAME == "nt"
	native_path = (
		PureWindowsPath(trimmed)
		if native_is_windows
		else PurePosixPath(trimmed)
	)
	windows_path = PureWindowsPath(trimmed)
	if (
		not trimmed
		or _contains_path_control_character(trimmed)
		or len(trimmed) > REFERENCE_PROJECT_MAX_CHARACTERS
		or len(encoded) > REFERENCE_PROJECT_MAX_UTF8_BYTES
		or len(trimmed_encoded) > REFERENCE_PROJECT_MAX_UTF8_BYTES
		or trimmed.startswith("~")
		or (bool(native_path.anchor) and not native_path.is_absolute())
		or (
			native_is_windows
			and bool(windows_path.root)
			and not bool(windows_path.drive)
		)
		or (
			not native_is_windows
			and (
				bool(windows_path.drive)
				or trimmed.startswith("\\\\")
			)
		)
		or (bool(windows_path.drive) and not windows_path.is_absolute())
	):
		raise ReferenceManifestError("reference_manifest.invalid_project_root")
	return trimmed


def validate_reference_scene(value: Any) -> str:
	"""Validate one canonical project-local Godot scene resource path."""
	if type(value) is not str:
		raise ReferenceManifestError("reference_manifest.invalid_scene")
	try:
		encoded = value.encode("utf-8", errors="strict")
	except UnicodeEncodeError:
		raise ReferenceManifestError("reference_manifest.invalid_scene") from None
	trimmed = value.strip()
	if (
		not trimmed
		or _contains_path_control_character(trimmed)
		or len(trimmed) > REFERENCE_SCENE_MAX_CHARACTERS
		or len(encoded) > REFERENCE_SCENE_MAX_UTF8_BYTES
	):
		raise ReferenceManifestError("reference_manifest.invalid_scene")
	try:
		trimmed_encoded = trimmed.encode("utf-8", errors="strict")
	except UnicodeEncodeError:
		raise ReferenceManifestError("reference_manifest.invalid_scene") from None
	if len(trimmed_encoded) > REFERENCE_SCENE_MAX_UTF8_BYTES:
		raise ReferenceManifestError("reference_manifest.invalid_scene")
	if not trimmed.startswith("res://") or "\\" in trimmed:
		raise ReferenceManifestError("reference_manifest.invalid_scene")
	resource_path = trimmed.removeprefix("res://")
	path_parts = resource_path.split("/")
	if (
		not resource_path
		or any(part in {"", ".", ".."} for part in path_parts)
		or any(":" in part for part in path_parts)
		or PurePosixPath(resource_path).as_posix() != resource_path
		or PurePosixPath(resource_path).suffix not in {".scn", ".tscn"}
	):
		raise ReferenceManifestError("reference_manifest.invalid_scene")
	return trimmed


def parse_reference_manifest(source: str) -> dict[str, str | None]:
	"""Parse one manifest using a closed schema and bounded scene values."""
	payload = _parse_strict_json_object(source)
	if not set(payload).issubset(_ALLOWED_MANIFEST_KEYS):
		raise ReferenceManifestError("reference_manifest.unknown_key")
	return {
		"boot_scene": (
			validate_reference_scene(payload["boot_scene"])
			if "boot_scene" in payload
			else None
		),
		"smoke_scene": (
			validate_reference_scene(payload["smoke_scene"])
			if "smoke_scene" in payload
			else None
		),
	}


def read_reference_manifest(project_root: Path) -> dict[str, Any]:
	"""Return one strict manifest result; only the exact leaf may be absent."""
	if not isinstance(project_root, Path) or not project_root.is_absolute():
		raise ReferenceManifestError("reference_manifest.invalid_project_root")
	source = gf_path_security.read_optional_pinned_utf8_regular_file(
		project_root,
		REFERENCE_MANIFEST_NAME,
		max_bytes=REFERENCE_MANIFEST_MAX_BYTES,
	)
	if source is None:
		return {
			"schema_version": RESPONSE_SCHEMA_VERSION,
			"ok": True,
			"manifest_present": False,
			"boot_scene": None,
			"smoke_scene": None,
		}
	manifest = parse_reference_manifest(source)
	return {
		"schema_version": RESPONSE_SCHEMA_VERSION,
		"ok": True,
		"manifest_present": True,
		"boot_scene": manifest["boot_scene"],
		"smoke_scene": manifest["smoke_scene"],
	}


def decode_success_response(
	payload: bytes,
	*,
	deadline_check: Callable[[], None] | None = None,
) -> dict[str, Any]:
	"""Validate the complete helper success protocol at the parent boundary."""
	if deadline_check is not None and not callable(deadline_check):
		raise TypeError("Reference response deadline check must be callable.")
	if type(payload) is not bytes or len(payload) > REFERENCE_MANIFEST_MAX_BYTES:
		raise ReferenceManifestError("reference_manifest.invalid_response")
	try:
		source = payload.decode("utf-8", errors="strict")
	except UnicodeDecodeError:
		raise ReferenceManifestError("reference_manifest.invalid_response") from None
	if deadline_check is not None:
		deadline_check()
	response = _parse_strict_json_object(source)
	if deadline_check is not None:
		deadline_check()
	if (
		set(response) != _SUCCESS_RESPONSE_KEYS
		or type(response.get("schema_version")) is not int
		or response.get("schema_version") != RESPONSE_SCHEMA_VERSION
		or response.get("ok") is not True
		or type(response.get("manifest_present")) is not bool
	):
		raise ReferenceManifestError("reference_manifest.invalid_response")
	for key in ("boot_scene", "smoke_scene"):
		value = response.get(key)
		if value is not None and validate_reference_scene(value) != value:
			raise ReferenceManifestError("reference_manifest.invalid_response")
	if response["manifest_present"] is False and (
		response["boot_scene"] is not None
		or response["smoke_scene"] is not None
	):
		raise ReferenceManifestError("reference_manifest.invalid_response")
	if deadline_check is not None:
		deadline_check()
	return response


def _encoded_response(payload: dict[str, Any]) -> bytes:
	return (
		json.dumps(
			payload,
			ensure_ascii=True,
			sort_keys=True,
			separators=(",", ":"),
		)
		+ "\n"
	).encode("ascii")


def _write_response(payload: dict[str, Any]) -> None:
	response = _encoded_response(payload)
	if len(response) > REFERENCE_MANIFEST_MAX_BYTES:
		raise ReferenceManifestError("reference_manifest.invalid_response")
	sys.stdout.buffer.write(response)
	sys.stdout.buffer.flush()


def build_parser() -> argparse.ArgumentParser:
	parser = argparse.ArgumentParser(
		description="Read one GF reference-project manifest through a pinned boundary."
	)
	parser.add_argument("--project-root", required=True)
	return parser


def main(argv: list[str] | None = None) -> int:
	args = build_parser().parse_args(argv)
	try:
		project_root = Path(args.project_root)
		response = read_reference_manifest(project_root)
	except gf_path_security.PinnedReadError:
		response = {
			"schema_version": RESPONSE_SCHEMA_VERSION,
			"ok": False,
			"error": "reference_manifest.read_failed",
		}
	except ReferenceManifestError as error:
		response = {
			"schema_version": RESPONSE_SCHEMA_VERSION,
			"ok": False,
			"error": error.rule_id,
		}
	_write_response(response)
	return 0 if response.get("ok") is True else 1


if __name__ == "__main__":
	raise SystemExit(main())
