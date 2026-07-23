#!/usr/bin/env python3
"""Immutable, maintenance-only package artifact sets for GF smoke checks.

This module deliberately does not share the release artifact mechanism and does
not provide a persistent cache.  A caller builds one package distribution,
seals its bytes together with workspace provenance, and materializes private
copies for individual smoke consumers.
"""

from __future__ import annotations

import copy
import hashlib
import json
import math
import os
import re
import secrets
import shutil
import stat
import time
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from pathlib import PurePosixPath
from typing import Any
from typing import Mapping

import gf_path_security


MANIFEST_SCHEMA_VERSION = 1
MANIFEST_KIND = "gf_package_smoke_artifact_set"
MANIFEST_FILENAME = "gf-package-artifact-set.json"
BUILDER_RESULT_RELATIVE_PATH = "builder-result.json"
REGISTRY_RELATIVE_PATH = "registry/index.json"
REGISTRY_SOURCE_RELATIVE_PATH = "registry/gf-registry-source.json"
OFFLINE_BUNDLE_RELATIVE_PATH = "offline_bundle/gf-package-offline-bundle.zip"

ROLE_BUILDER_RESULT = "builder_result"
ROLE_REGISTRY = "registry"
ROLE_REGISTRY_SOURCE = "registry_source"
ROLE_OFFLINE_BUNDLE = "offline_bundle"
ROLE_PACKAGE = "package"

_ALLOWED_ROLES = frozenset({
	ROLE_BUILDER_RESULT,
	ROLE_REGISTRY,
	ROLE_REGISTRY_SOURCE,
	ROLE_OFFLINE_BUNDLE,
	ROLE_PACKAGE,
})
_FIXED_ROLE_PATHS = {
	ROLE_BUILDER_RESULT: BUILDER_RESULT_RELATIVE_PATH,
	ROLE_REGISTRY: REGISTRY_RELATIVE_PATH,
	ROLE_REGISTRY_SOURCE: REGISTRY_SOURCE_RELATIVE_PATH,
	ROLE_OFFLINE_BUNDLE: OFFLINE_BUNDLE_RELATIVE_PATH,
}
_MANIFEST_FIELDS = frozenset({
	"schema_version",
	"kind",
	"workspace",
	"artifact_count",
	"artifacts",
})
_WORKSPACE_FIELDS = frozenset({"schema_version", "fingerprint", "head", "dirty"})
_ARTIFACT_FIELDS = frozenset({"role", "path", "size_bytes", "sha256"})
_SHA256_PATTERN = re.compile(r"[0-9a-f]{64}")
_GIT_HEAD_PATTERN = re.compile(r"[0-9a-f]{40}(?:[0-9a-f]{24})?")
_WINDOWS_INVALID_CHARACTERS = frozenset('<>:"|?*')
_WINDOWS_RESERVED_NAMES = frozenset({
	"con",
	"prn",
	"aux",
	"nul",
	*(f"com{index}" for index in range(1, 10)),
	*(f"lpt{index}" for index in range(1, 10)),
})


class PackageArtifactSetError(RuntimeError):
	"""Raised when a package artifact set cannot be trusted."""


class PackageArtifactDeadlineError(PackageArtifactSetError):
	"""Raised when artifact work exceeds its caller-owned absolute deadline."""


@dataclass(frozen=True)
class PackageArtifactInput:
	"""One caller-provided file that will be sealed into an artifact set."""

	role: str
	relative_path: str
	path: Path


@dataclass(frozen=True)
class PackageArtifact:
	"""One immutable file described by the package artifact manifest."""

	role: str
	relative_path: str
	size_bytes: int
	sha256: str

	def to_manifest_record(self) -> dict[str, Any]:
		return {
			"role": self.role,
			"path": self.relative_path,
			"size_bytes": self.size_bytes,
			"sha256": self.sha256,
		}


@dataclass(frozen=True)
class PackageArtifactSet:
	"""A validated package smoke artifact set rooted at one private directory."""

	root: Path
	manifest_path: Path
	manifest_sha256: str
	workspace_state: dict[str, Any]
	artifacts: tuple[PackageArtifact, ...]
	builder_result: dict[str, Any]

	def path_for_role(self, role: str) -> Path:
		matches = [artifact for artifact in self.artifacts if artifact.role == role]
		if len(matches) != 1:
			raise PackageArtifactSetError(
				f"Package artifact role must occur exactly once for path lookup: {role!r}."
			)
		return _path_for_relative(self.root, matches[0].relative_path)

	@property
	def registry_path(self) -> Path:
		return self.path_for_role(ROLE_REGISTRY)

	@property
	def registry_source_path(self) -> Path:
		return self.path_for_role(ROLE_REGISTRY_SOURCE)

	@property
	def offline_bundle_path(self) -> Path:
		return self.path_for_role(ROLE_OFFLINE_BUNDLE)

	@property
	def builder_result_path(self) -> Path:
		return self.path_for_role(ROLE_BUILDER_RESULT)

	@property
	def package_archive_paths(self) -> tuple[Path, ...]:
		return tuple(
			_path_for_relative(self.root, artifact.relative_path)
			for artifact in self.artifacts
			if artifact.role == ROLE_PACKAGE
		)

	def rebased_builder_data(self) -> dict[str, Any]:
		"""Return builder JSON whose file fields point at this set's private root."""
		return rebase_package_builder_data(self.root, self.builder_result)

	def revalidate(
		self,
		expected_workspace_state: Mapping[str, Any] | None = None,
		*,
		deadline: float | None = None,
	) -> PackageArtifactSet:
		return revalidate_package_artifact_set(
			self,
			expected_workspace_state,
			deadline=deadline,
		)


def assemble_package_artifact_inputs(
	root: str | Path,
	builder_data: Mapping[str, Any],
) -> tuple[PackageArtifactInput, ...]:
	"""Validate builder JSON and derive the fixed package artifact input paths."""
	root_path = _validated_root(root)
	normalized_builder = _normalize_builder_result(root_path, builder_data)
	return _inputs_from_normalized_builder(root_path, normalized_builder)


def assemble_package_artifact_set_inputs(
	root: str | Path,
	builder_data: Mapping[str, Any],
) -> tuple[PackageArtifactInput, ...]:
	"""Compatibility spelling that makes the owning artifact set explicit."""
	return assemble_package_artifact_inputs(root, builder_data)


def seal_package_artifact_set(
	root: str | Path,
	builder_data: Mapping[str, Any],
	workspace_state: Mapping[str, Any],
	*,
	deadline: float | None = None,
) -> PackageArtifactSet:
	"""Seal one already-built package distribution and return its validated set."""
	_check_deadline(deadline, "package artifact sealing")
	root_path = _validated_root(root)
	manifest_path = root_path / MANIFEST_FILENAME
	if os.path.lexists(manifest_path):
		raise PackageArtifactSetError(
			f"Package artifact set is already sealed: {manifest_path.as_posix()}"
		)
	normalized_workspace = _normalize_workspace_state(workspace_state, "workspace state")
	normalized_builder = _normalize_builder_result(root_path, builder_data, deadline=deadline)
	inputs = _inputs_from_normalized_builder(root_path, normalized_builder)

	# Validate every builder output and the tree before adding owned metadata.
	for artifact_input in inputs:
		_check_deadline(deadline, "package artifact input validation")
		_snapshot_regular_file(artifact_input.path, deadline=deadline)
	builder_result_path = root_path / BUILDER_RESULT_RELATIVE_PATH
	allowed_before_seal = {item.relative_path for item in inputs}
	if os.path.lexists(builder_result_path):
		stored_builder = _load_json_object(
			builder_result_path,
			"Package builder result",
			deadline=deadline,
		)
		if stored_builder != normalized_builder:
			raise PackageArtifactSetError(
				"Existing builder-result.json does not match the supplied normalized builder data."
			)
		if _read_regular_bytes(builder_result_path, deadline=deadline) != _json_bytes(
			normalized_builder,
			deadline=deadline,
		):
			raise PackageArtifactSetError("Existing builder-result.json is not canonical UTF-8 JSON.")
		allowed_before_seal.add(BUILDER_RESULT_RELATIVE_PATH)
	_validate_exact_tree(root_path, allowed_before_seal, deadline=deadline)

	if not os.path.lexists(builder_result_path):
		_atomic_write_json(builder_result_path, normalized_builder, deadline=deadline)

	artifact_inputs = [
		*inputs,
		PackageArtifactInput(
			role=ROLE_BUILDER_RESULT,
			relative_path=BUILDER_RESULT_RELATIVE_PATH,
			path=builder_result_path,
		),
	]
	artifacts = tuple(sorted(
		(_artifact_from_input(item, deadline=deadline) for item in artifact_inputs),
		key=lambda artifact: _portable_path_identity(artifact.relative_path),
	))
	_validate_artifact_role_paths(artifacts)
	_validate_exact_tree(
		root_path,
		{artifact.relative_path for artifact in artifacts},
		deadline=deadline,
	)
	manifest = {
		"schema_version": MANIFEST_SCHEMA_VERSION,
		"kind": MANIFEST_KIND,
		"workspace": normalized_workspace,
		"artifact_count": len(artifacts),
		"artifacts": [artifact.to_manifest_record() for artifact in artifacts],
	}
	_atomic_write_json(manifest_path, manifest, deadline=deadline)
	manifest_sha256 = _snapshot_regular_file(manifest_path, deadline=deadline)[1]
	_check_deadline(deadline, "package artifact sealing")
	return load_package_artifact_set(
		manifest_path,
		manifest_sha256,
		normalized_workspace,
		deadline=deadline,
	)


def load_package_artifact_set(
	manifest_path: str | Path,
	expected_manifest_sha256: str,
	expected_workspace_state: Mapping[str, Any],
	*,
	deadline: float | None = None,
) -> PackageArtifactSet:
	"""Load a set only when manifest bytes and workspace provenance are expected."""
	_check_deadline(deadline, "package artifact loading")
	manifest = gf_path_security.absolute_lexical_path(Path(manifest_path))
	if manifest.name != MANIFEST_FILENAME:
		raise PackageArtifactSetError(
			f"Package artifact manifest must be named {MANIFEST_FILENAME}."
		)
	root = _validated_root(manifest.parent)
	expected_sha256 = _require_sha256(expected_manifest_sha256, "expected manifest SHA-256")
	expected_workspace = _normalize_workspace_state(expected_workspace_state, "expected workspace state")
	manifest_bytes = _read_regular_bytes(manifest, deadline=deadline)
	actual_manifest_sha256 = hashlib.sha256(manifest_bytes).hexdigest()
	if actual_manifest_sha256 != expected_sha256:
		raise PackageArtifactSetError(
			"Package artifact manifest SHA-256 does not match the expected producer value."
		)
	manifest_data = _parse_json_object(
		manifest_bytes,
		"Package artifact manifest",
		deadline=deadline,
	)
	if manifest_bytes != _json_bytes(manifest_data, deadline=deadline):
		raise PackageArtifactSetError("Package artifact manifest is not canonical UTF-8 JSON.")
	artifacts, manifest_workspace = _validate_manifest_data(manifest_data, deadline=deadline)
	if manifest_workspace != expected_workspace:
		raise PackageArtifactSetError(
			"Package artifact workspace fingerprint, HEAD, or dirty state does not match the expected workspace."
		)

	_validate_exact_tree(
		root,
		{MANIFEST_FILENAME, *(artifact.relative_path for artifact in artifacts)},
		deadline=deadline,
	)
	for artifact in artifacts:
		_check_deadline(deadline, "package artifact file validation")
		path = _path_for_relative(root, artifact.relative_path)
		size_bytes, sha256 = _snapshot_regular_file(path, deadline=deadline)
		if size_bytes != artifact.size_bytes:
			raise PackageArtifactSetError(
				f"Package artifact size does not match its manifest: {artifact.relative_path}"
			)
		if sha256 != artifact.sha256:
			raise PackageArtifactSetError(
				f"Package artifact SHA-256 does not match its manifest: {artifact.relative_path}"
			)

	builder_result_path = root / BUILDER_RESULT_RELATIVE_PATH
	builder_result_bytes = _read_regular_bytes(builder_result_path, deadline=deadline)
	builder_result = _parse_json_object(
		builder_result_bytes,
		"Package builder result",
		deadline=deadline,
	)
	if builder_result_bytes != _json_bytes(builder_result, deadline=deadline):
		raise PackageArtifactSetError("builder-result.json is not canonical UTF-8 JSON.")
	normalized_builder = _normalize_builder_result(root, builder_result, deadline=deadline)
	if builder_result != normalized_builder:
		raise PackageArtifactSetError("builder-result.json contains non-canonical artifact paths.")
	expected_inputs = _inputs_from_normalized_builder(root, normalized_builder)
	expected_role_paths = {
		(item.role, item.relative_path)
		for item in expected_inputs
	}
	expected_role_paths.add((ROLE_BUILDER_RESULT, BUILDER_RESULT_RELATIVE_PATH))
	manifest_role_paths = {(artifact.role, artifact.relative_path) for artifact in artifacts}
	if manifest_role_paths != expected_role_paths:
		raise PackageArtifactSetError(
			"Package artifact manifest entries do not match the sealed builder result."
		)

	_check_deadline(deadline, "package artifact loading")
	return PackageArtifactSet(
		root=root,
		manifest_path=manifest,
		manifest_sha256=actual_manifest_sha256,
		workspace_state=copy.deepcopy(manifest_workspace),
		artifacts=artifacts,
		builder_result=copy.deepcopy(builder_result),
	)


def validate_package_artifact_set(
	artifact_set_or_manifest: PackageArtifactSet | str | Path,
	expected_manifest_sha256: str | None = None,
	expected_workspace_state: Mapping[str, Any] | None = None,
	*,
	deadline: float | None = None,
) -> PackageArtifactSet:
	"""Validate either an existing object or a manifest path, returning fresh data."""
	_check_deadline(deadline, "package artifact validation")
	if isinstance(artifact_set_or_manifest, PackageArtifactSet):
		artifact_set = artifact_set_or_manifest
		manifest_path = artifact_set.manifest_path
		manifest_sha256 = (
			artifact_set.manifest_sha256
			if expected_manifest_sha256 is None
			else expected_manifest_sha256
		)
		workspace_state = (
			artifact_set.workspace_state
			if expected_workspace_state is None
			else expected_workspace_state
		)
	else:
		manifest_path = artifact_set_or_manifest
		if expected_manifest_sha256 is None or expected_workspace_state is None:
			raise PackageArtifactSetError(
				"Manifest-path validation requires an expected manifest SHA-256 and workspace state."
			)
		manifest_sha256 = expected_manifest_sha256
		workspace_state = expected_workspace_state
	return load_package_artifact_set(
		manifest_path,
		manifest_sha256,
		workspace_state,
		deadline=deadline,
	)


def revalidate_package_artifact_set(
	artifact_set: PackageArtifactSet,
	expected_workspace_state: Mapping[str, Any] | None = None,
	*,
	deadline: float | None = None,
) -> PackageArtifactSet:
	"""Perform the final byte-for-byte validation immediately before consumption."""
	_check_deadline(deadline, "package artifact revalidation")
	return load_package_artifact_set(
		artifact_set.manifest_path,
		artifact_set.manifest_sha256,
		artifact_set.workspace_state if expected_workspace_state is None else expected_workspace_state,
		deadline=deadline,
	)


def materialize_package_artifact_set(
	artifact_set: PackageArtifactSet,
	target_root: str | Path,
	*,
	deadline: float | None = None,
) -> PackageArtifactSet:
	"""Copy a validated set into a consumer-private root and validate the copy."""
	_check_deadline(deadline, "package artifact materialization")
	source = revalidate_package_artifact_set(artifact_set, deadline=deadline)
	target = gf_path_security.absolute_lexical_path(Path(target_root))
	if (
		gf_path_security.path_is_inside_lexical(source.root, target)
		or gf_path_security.path_is_inside_lexical(target, source.root)
	):
		raise PackageArtifactSetError("Consumer artifact root must not overlap the producer root.")
	if not target.name or not target.parent.is_dir():
		raise PackageArtifactSetError("Consumer artifact root must have an existing parent directory.")
	if gf_path_security.path_has_reparse_component(target):
		raise PackageArtifactSetError(
			"Consumer artifact root crosses a symlink, junction, or reparse point."
		)
	target_existed = os.path.lexists(target)
	if target_existed:
		if not target.is_dir():
			raise PackageArtifactSetError("Consumer artifact root exists and is not a directory.")
		files, directories = _scan_tree(target, deadline=deadline)
		if files or directories:
			raise PackageArtifactSetError("Consumer artifact root must be absent or empty.")

	staging = target.parent / f".{target.name}.a-{secrets.token_hex(4)}"
	if os.path.lexists(staging) or gf_path_security.path_has_reparse_component(staging):
		raise PackageArtifactSetError("Consumer artifact staging path is unsafe or already exists.")
	staging.mkdir()
	staging_identity = staging.lstat()
	published = False
	try:
		copy_relative_paths = [
			*(artifact.relative_path for artifact in source.artifacts),
			MANIFEST_FILENAME,
		]
		for relative_path in sorted(copy_relative_paths, key=_portable_path_identity):
			_check_deadline(deadline, "package artifact copying")
			source_path = _path_for_relative(source.root, relative_path)
			destination_path = _path_for_relative(staging, relative_path)
			destination_path.parent.mkdir(parents=True, exist_ok=True)
			if gf_path_security.path_has_reparse_component(destination_path):
				raise PackageArtifactSetError(
					f"Consumer artifact destination became unsafe: {relative_path}"
				)
			_copy_regular_file_with_deadline(
				source_path,
				destination_path,
				deadline=deadline,
			)
			if os.path.samefile(source_path, destination_path):
				raise PackageArtifactSetError(
					f"Consumer artifact must be an independent copy, not a hardlink: {relative_path}"
				)
			_snapshot_regular_file(destination_path, deadline=deadline)

		load_package_artifact_set(
			staging / MANIFEST_FILENAME,
			source.manifest_sha256,
			source.workspace_state,
			deadline=deadline,
		)
		_check_deadline(deadline, "package artifact publication")
		if target_existed:
			if gf_path_security.path_has_reparse_component(target):
				raise PackageArtifactSetError("Consumer artifact root became unsafe before publication.")
			target.rmdir()
		if os.path.lexists(target):
			raise PackageArtifactSetError("Consumer artifact root was concurrently created.")
		os.replace(staging, target)
		_sync_directory(target.parent)
		published = True
		return load_package_artifact_set(
			target / MANIFEST_FILENAME,
			source.manifest_sha256,
			source.workspace_state,
			deadline=deadline,
		)
	finally:
		if not published and os.path.lexists(staging):
			cleanup_issue = _safe_remove_private_tree(staging, expected_identity=staging_identity)
			if cleanup_issue:
				raise PackageArtifactSetError(cleanup_issue)


def rebase_package_builder_data(
	root: str | Path,
	builder_data: Mapping[str, Any],
) -> dict[str, Any]:
	"""Return canonical builder data with absolute paths for one artifact root."""
	root_path = gf_path_security.absolute_lexical_path(Path(root))
	data = _json_clone(builder_data, "Package builder result")
	data["output_dir"] = (root_path / "packages").as_posix()
	data["registry"] = (root_path / REGISTRY_RELATIVE_PATH).as_posix()
	data["registry_source"] = (root_path / REGISTRY_SOURCE_RELATIVE_PATH).as_posix()
	data["offline_bundle"] = (root_path / OFFLINE_BUNDLE_RELATIVE_PATH).as_posix()
	packages = data.get("packages", [])
	if not isinstance(packages, list):
		raise PackageArtifactSetError("Package builder result packages must be an array.")
	for package in packages:
		if not isinstance(package, dict):
			raise PackageArtifactSetError("Package builder result entries must be objects.")
		archive = str(package.get("archive", ""))
		if archive:
			_validate_relative_artifact_path(archive)
			package["archive"] = _path_for_relative(root_path, archive).as_posix()
	return data


def _normalize_builder_result(
	root: Path,
	builder_data: Mapping[str, Any],
	*,
	deadline: float | None = None,
) -> dict[str, Any]:
	_check_deadline(deadline, "package builder result normalization")
	data = _json_clone(builder_data, "Package builder result", deadline=deadline)
	if data.get("ok") is not True:
		raise PackageArtifactSetError("Package builder result must report ok=true before sealing.")
	issues = data.get("issues", [])
	if not isinstance(issues, list) or issues:
		raise PackageArtifactSetError("Package builder result must contain an empty issues array.")
	packages = data.get("packages")
	if not isinstance(packages, list):
		raise PackageArtifactSetError("Package builder result packages must be an array.")
	package_count = data.get("package_count", len(packages))
	if not _is_int(package_count) or package_count != len(packages):
		raise PackageArtifactSetError("Package builder result package_count is inconsistent.")

	_assert_builder_path(root, data.get("output_dir"), root / "packages", "output_dir")
	_assert_builder_path(root, data.get("registry"), root / REGISTRY_RELATIVE_PATH, "registry")
	_assert_builder_path(
		root,
		data.get("registry_source"),
		root / REGISTRY_SOURCE_RELATIVE_PATH,
		"registry_source",
	)
	_assert_builder_path(
		root,
		data.get("offline_bundle"),
		root / OFFLINE_BUNDLE_RELATIVE_PATH,
		"offline_bundle",
	)
	data["output_dir"] = "packages"
	data["registry"] = REGISTRY_RELATIVE_PATH
	data["registry_source"] = REGISTRY_SOURCE_RELATIVE_PATH
	data["offline_bundle"] = OFFLINE_BUNDLE_RELATIVE_PATH
	data["package_count"] = len(packages)

	seen_ids: dict[str, str] = {}
	seen_archives: dict[str, str] = {}
	archive_count = 0
	for index, package in enumerate(packages):
		_check_deadline(deadline, "package builder result normalization")
		if not isinstance(package, dict):
			raise PackageArtifactSetError(f"Package builder result entry {index} must be an object.")
		package_id = package.get("id")
		if not isinstance(package_id, str) or not package_id.strip():
			raise PackageArtifactSetError(f"Package builder result entry {index} has no package id.")
		package_identity = unicodedata.normalize("NFC", package_id).casefold()
		if package_identity in seen_ids:
			raise PackageArtifactSetError(
				f"Package builder result contains duplicate or case-conflicting ids: "
				f"{seen_ids[package_identity]!r} and {package_id!r}."
			)
		seen_ids[package_identity] = package_id
		if package.get("ok") is not True:
			raise PackageArtifactSetError(f"Package builder entry did not succeed: {package_id}")
		package_issues = package.get("issues", [])
		if not isinstance(package_issues, list) or package_issues:
			raise PackageArtifactSetError(f"Package builder entry contains issues: {package_id}")

		kind = str(package.get("kind", ""))
		archive_value = package.get("archive", "")
		if kind == "preset":
			if archive_value not in ("", None):
				raise PackageArtifactSetError(f"Preset builder entry must not have an archive: {package_id}")
			if package.get("sha256", "") not in ("", None) or package.get("size_bytes", 0) != 0:
				raise PackageArtifactSetError(
					f"Preset builder entry must not have archive integrity fields: {package_id}"
				)
			package["archive"] = ""
			continue
		if not isinstance(archive_value, str) or not archive_value.strip():
			raise PackageArtifactSetError(f"Package builder entry has no archive: {package_id}")
		archive_name = Path(archive_value.replace("\\", "/")).name
		relative_path = f"packages/{archive_name}"
		_validate_relative_artifact_path(relative_path)
		if not archive_name.endswith(".zip"):
			raise PackageArtifactSetError(f"Package archive must use a lowercase .zip suffix: {archive_name}")
		archive_identity = _portable_path_identity(relative_path)
		if archive_identity in seen_archives:
			raise PackageArtifactSetError(
				f"Package archives are duplicated or conflict by case: "
				f"{seen_archives[archive_identity]} and {relative_path}."
			)
		seen_archives[archive_identity] = relative_path
		archive_path = root / "packages" / archive_name
		_assert_builder_path(root, archive_value, archive_path, f"packages[{package_id}].archive")
		size_bytes, sha256 = _snapshot_regular_file(archive_path, deadline=deadline)
		if package.get("size_bytes") != size_bytes:
			raise PackageArtifactSetError(f"Package builder size does not match archive bytes: {package_id}")
		if package.get("sha256") != sha256:
			raise PackageArtifactSetError(f"Package builder SHA-256 does not match archive bytes: {package_id}")
		package["archive"] = relative_path
		archive_count += 1
	if archive_count == 0:
		raise PackageArtifactSetError("Package artifact set must contain at least one package archive.")
	_check_deadline(deadline, "package builder result normalization")
	return data


def _inputs_from_normalized_builder(
	root: Path,
	builder_data: Mapping[str, Any],
) -> tuple[PackageArtifactInput, ...]:
	inputs = [
		PackageArtifactInput(ROLE_REGISTRY, REGISTRY_RELATIVE_PATH, root / REGISTRY_RELATIVE_PATH),
		PackageArtifactInput(
			ROLE_REGISTRY_SOURCE,
			REGISTRY_SOURCE_RELATIVE_PATH,
			root / REGISTRY_SOURCE_RELATIVE_PATH,
		),
		PackageArtifactInput(
			ROLE_OFFLINE_BUNDLE,
			OFFLINE_BUNDLE_RELATIVE_PATH,
			root / OFFLINE_BUNDLE_RELATIVE_PATH,
		),
	]
	for package in builder_data["packages"]:
		archive = str(package.get("archive", ""))
		if archive:
			inputs.append(PackageArtifactInput(ROLE_PACKAGE, archive, _path_for_relative(root, archive)))
	return tuple(sorted(inputs, key=lambda item: _portable_path_identity(item.relative_path)))


def _validate_manifest_data(
	data: Mapping[str, Any],
	*,
	deadline: float | None = None,
) -> tuple[tuple[PackageArtifact, ...], dict[str, Any]]:
	_check_deadline(deadline, "package artifact manifest validation")
	if set(data) != _MANIFEST_FIELDS:
		raise PackageArtifactSetError("Package artifact manifest fields do not match schema version 1.")
	if not _is_int(data.get("schema_version")) or data.get("schema_version") != MANIFEST_SCHEMA_VERSION:
		raise PackageArtifactSetError(
			f"Package artifact manifest schema_version must be {MANIFEST_SCHEMA_VERSION}."
		)
	if data.get("kind") != MANIFEST_KIND:
		raise PackageArtifactSetError("Package artifact manifest kind is invalid.")
	workspace = data.get("workspace")
	if not isinstance(workspace, dict) or set(workspace) != _WORKSPACE_FIELDS:
		raise PackageArtifactSetError("Package artifact manifest workspace fields are invalid.")
	normalized_workspace = _normalize_workspace_state(workspace, "manifest workspace")
	artifact_values = data.get("artifacts")
	if not isinstance(artifact_values, list):
		raise PackageArtifactSetError("Package artifact manifest artifacts must be an array.")
	if not _is_int(data.get("artifact_count")) or data.get("artifact_count") != len(artifact_values):
		raise PackageArtifactSetError("Package artifact manifest artifact_count is inconsistent.")
	artifacts: list[PackageArtifact] = []
	seen_paths: dict[str, str] = {}
	for index, value in enumerate(artifact_values):
		_check_deadline(deadline, "package artifact manifest validation")
		if not isinstance(value, dict) or set(value) != _ARTIFACT_FIELDS:
			raise PackageArtifactSetError(
				f"Package artifact manifest entry {index} fields are invalid."
			)
		role = value.get("role")
		relative_path = value.get("path")
		size_bytes = value.get("size_bytes")
		sha256 = value.get("sha256")
		if not isinstance(role, str) or role not in _ALLOWED_ROLES:
			raise PackageArtifactSetError(f"Package artifact role is unsupported: {role!r}")
		if not isinstance(relative_path, str):
			raise PackageArtifactSetError(f"Package artifact path must be a string at entry {index}.")
		_validate_relative_artifact_path(relative_path)
		identity = _portable_path_identity(relative_path)
		if identity in seen_paths:
			raise PackageArtifactSetError(
				f"Package artifact paths are duplicated or conflict by case: "
				f"{seen_paths[identity]} and {relative_path}."
			)
		seen_paths[identity] = relative_path
		if not _is_int(size_bytes) or size_bytes <= 0:
			raise PackageArtifactSetError(f"Package artifact size is invalid: {relative_path}")
		validated_sha = _require_sha256(sha256, f"artifact SHA-256 for {relative_path}")
		artifacts.append(PackageArtifact(role, relative_path, size_bytes, validated_sha))
	if [artifact.relative_path for artifact in artifacts] != [
		artifact.relative_path
		for artifact in sorted(artifacts, key=lambda item: _portable_path_identity(item.relative_path))
	]:
		raise PackageArtifactSetError("Package artifact manifest entries must use deterministic path order.")
	artifact_tuple = tuple(artifacts)
	_validate_artifact_role_paths(artifact_tuple)
	_check_deadline(deadline, "package artifact manifest validation")
	return artifact_tuple, normalized_workspace


def _validate_artifact_role_paths(artifacts: tuple[PackageArtifact, ...]) -> None:
	roles = [artifact.role for artifact in artifacts]
	for role, expected_path in _FIXED_ROLE_PATHS.items():
		matches = [artifact.relative_path for artifact in artifacts if artifact.role == role]
		if matches != [expected_path]:
			raise PackageArtifactSetError(
				f"Package artifact role {role!r} must occur once at {expected_path}."
			)
	package_paths = [artifact.relative_path for artifact in artifacts if artifact.role == ROLE_PACKAGE]
	if not package_paths:
		raise PackageArtifactSetError("Package artifact manifest must contain package archives.")
	for relative_path in package_paths:
		parts = PurePosixPath(relative_path).parts
		if len(parts) != 2 or parts[0] != "packages" or not parts[1].endswith(".zip"):
			raise PackageArtifactSetError(
				f"Package artifact must be packages/<archive>.zip: {relative_path}"
			)
	if any(role not in _ALLOWED_ROLES for role in roles):
		raise PackageArtifactSetError("Package artifact manifest contains an unsupported role.")


def _normalize_workspace_state(value: Mapping[str, Any], label: str) -> dict[str, Any]:
	if not isinstance(value, Mapping):
		raise PackageArtifactSetError(f"{label} must be an object.")
	schema_version = value.get("schema_version", 1)
	if not _is_int(schema_version) or schema_version != 1:
		raise PackageArtifactSetError(f"{label} schema_version must be 1.")
	fingerprint = _require_sha256(value.get("fingerprint"), f"{label} fingerprint")
	head = value.get("head")
	if not isinstance(head, str) or _GIT_HEAD_PATTERN.fullmatch(head) is None:
		raise PackageArtifactSetError(f"{label} HEAD must be a full lowercase Git commit SHA.")
	dirty = value.get("dirty")
	if not isinstance(dirty, bool):
		raise PackageArtifactSetError(f"{label} dirty must be a boolean.")
	return {
		"schema_version": 1,
		"fingerprint": fingerprint,
		"head": head,
		"dirty": dirty,
	}


def _validated_root(value: str | Path) -> Path:
	root = gf_path_security.absolute_lexical_path(Path(value))
	if not root.is_dir():
		raise PackageArtifactSetError(f"Package artifact root is not a directory: {root.as_posix()}")
	if gf_path_security.path_has_reparse_component(root):
		raise PackageArtifactSetError(
			f"Package artifact root crosses a symlink, junction, or reparse point: {root.as_posix()}"
		)
	return root


def _assert_builder_path(root: Path, raw_value: Any, expected: Path, field: str) -> None:
	if not isinstance(raw_value, str) or not raw_value.strip():
		raise PackageArtifactSetError(f"Package builder result field {field} must be a path string.")
	normalized = raw_value.replace("\\", "/")
	if ".." in PurePosixPath(normalized).parts:
		raise PackageArtifactSetError(f"Package builder result field {field} contains '..'.")
	raw_path = Path(raw_value)
	candidates = (
		[gf_path_security.absolute_lexical_path(raw_path)]
		if raw_path.is_absolute()
		else [
			gf_path_security.absolute_lexical_path(root / raw_path),
			gf_path_security.absolute_lexical_path(Path.cwd() / raw_path),
		]
	)
	expected_path = gf_path_security.absolute_lexical_path(expected)
	if not any(_same_lexical_path(candidate, expected_path) for candidate in candidates):
		raise PackageArtifactSetError(
			f"Package builder result field {field} does not point at the artifact root layout."
		)


def _same_lexical_path(left: Path, right: Path) -> bool:
	return os.path.normcase(str(left)) == os.path.normcase(str(right))


def _artifact_from_input(
	artifact_input: PackageArtifactInput,
	*,
	deadline: float | None = None,
) -> PackageArtifact:
	_check_deadline(deadline, "package artifact hashing")
	_validate_relative_artifact_path(artifact_input.relative_path)
	size_bytes, sha256 = _snapshot_regular_file(artifact_input.path, deadline=deadline)
	return PackageArtifact(
		role=artifact_input.role,
		relative_path=artifact_input.relative_path,
		size_bytes=size_bytes,
		sha256=sha256,
	)


def _validate_relative_artifact_path(value: str) -> None:
	if not value or value != value.replace("\\", "/"):
		raise PackageArtifactSetError(f"Package artifact path is not canonical: {value!r}")
	if value.startswith("/") or value.startswith("//") or re.match(r"^[A-Za-z]:", value):
		raise PackageArtifactSetError(f"Package artifact path must be relative: {value!r}")
	parts = value.split("/")
	if any(part in ("", ".", "..") for part in parts):
		raise PackageArtifactSetError(f"Package artifact path contains an unsafe component: {value!r}")
	if PurePosixPath(value).as_posix() != value:
		raise PackageArtifactSetError(f"Package artifact path is not normalized: {value!r}")
	for part in parts:
		if part != part.rstrip(" ."):
			raise PackageArtifactSetError(f"Package artifact path has a non-portable component: {value!r}")
		if any(ord(character) < 32 or character in _WINDOWS_INVALID_CHARACTERS for character in part):
			raise PackageArtifactSetError(f"Package artifact path has invalid characters: {value!r}")
		base_name = part.split(".", 1)[0].casefold()
		if base_name in _WINDOWS_RESERVED_NAMES:
			raise PackageArtifactSetError(f"Package artifact path uses a reserved name: {value!r}")


def _portable_path_identity(value: str) -> str:
	return unicodedata.normalize("NFC", value).casefold()


def _path_for_relative(root: Path, relative_path: str) -> Path:
	_validate_relative_artifact_path(relative_path)
	path = gf_path_security.absolute_lexical_path(root.joinpath(*relative_path.split("/")))
	if not gf_path_security.path_is_inside_lexical(root, path):
		raise PackageArtifactSetError(f"Package artifact path escapes its root: {relative_path}")
	return path


def _scan_tree(
	root: Path,
	*,
	deadline: float | None = None,
) -> tuple[set[str], set[str]]:
	_check_deadline(deadline, "package artifact tree scan")
	if gf_path_security.path_has_reparse_component(root):
		raise PackageArtifactSetError(
			f"Package artifact tree crosses a symlink, junction, or reparse point: {root.as_posix()}"
		)
	files: set[str] = set()
	directories: set[str] = set()
	identities: dict[str, str] = {}
	stack = [root]
	while stack:
		_check_deadline(deadline, "package artifact tree scan")
		current = stack.pop()
		try:
			directory_entries = os.scandir(current)
		except OSError as exc:
			raise PackageArtifactSetError(
				f"Could not enumerate package artifact tree {current.as_posix()}: {exc}"
			) from exc
		with directory_entries:
			for entry in directory_entries:
				_check_deadline(deadline, "package artifact tree scan")
				path = Path(entry.path)
				try:
					metadata = entry.stat(follow_symlinks=False)
				except OSError as exc:
					raise PackageArtifactSetError(
						f"Could not inspect package artifact entry {path.as_posix()}: {exc}"
					) from exc
				if _metadata_is_reparse(metadata):
					raise PackageArtifactSetError(
						f"Package artifact tree contains a symlink, junction, or reparse point: {path.as_posix()}"
					)
				relative_path = path.relative_to(root).as_posix()
				_validate_relative_artifact_path(relative_path)
				identity = _portable_path_identity(relative_path)
				if identity in identities:
					raise PackageArtifactSetError(
						f"Package artifact tree contains duplicate or case-conflicting paths: "
						f"{identities[identity]} and {relative_path}."
					)
				identities[identity] = relative_path
				if stat.S_ISDIR(metadata.st_mode):
					directories.add(relative_path)
					stack.append(path)
				elif stat.S_ISREG(metadata.st_mode):
					files.add(relative_path)
				else:
					raise PackageArtifactSetError(
						f"Package artifact tree contains a non-regular filesystem entry: {relative_path}"
					)
	_check_deadline(deadline, "package artifact tree scan")
	return files, directories


def _validate_exact_tree(
	root: Path,
	allowed_files: set[str],
	*,
	deadline: float | None = None,
) -> None:
	for relative_path in allowed_files:
		_check_deadline(deadline, "package artifact tree validation")
		_validate_relative_artifact_path(relative_path)
	files, directories = _scan_tree(root, deadline=deadline)
	if files != allowed_files:
		missing = sorted(allowed_files - files, key=_portable_path_identity)
		extra = sorted(files - allowed_files, key=_portable_path_identity)
		details = []
		if missing:
			details.append("missing=" + ", ".join(missing))
		if extra:
			details.append("extra=" + ", ".join(extra))
		raise PackageArtifactSetError(
			"Package artifact tree does not match the sealed file set: " + "; ".join(details)
		)
	allowed_directories: set[str] = set()
	for relative_path in allowed_files:
		_check_deadline(deadline, "package artifact tree validation")
		parent = PurePosixPath(relative_path).parent
		while parent != PurePosixPath("."):
			allowed_directories.add(parent.as_posix())
			parent = parent.parent
	if directories != allowed_directories:
		missing = sorted(allowed_directories - directories, key=_portable_path_identity)
		extra = sorted(directories - allowed_directories, key=_portable_path_identity)
		details = []
		if missing:
			details.append("missing=" + ", ".join(missing))
		if extra:
			details.append("extra=" + ", ".join(extra))
		raise PackageArtifactSetError(
			"Package artifact directories do not match the fixed layout: " + "; ".join(details)
		)
	_check_deadline(deadline, "package artifact tree validation")


def _snapshot_regular_file(
	path: Path,
	*,
	deadline: float | None = None,
) -> tuple[int, str]:
	size_bytes, sha256, _payload = _inspect_regular_file(
		path,
		capture=False,
		deadline=deadline,
	)
	return size_bytes, sha256


def _read_regular_bytes(
	path: Path,
	*,
	deadline: float | None = None,
) -> bytes:
	_size_bytes, _sha256, payload = _inspect_regular_file(
		path,
		capture=True,
		deadline=deadline,
	)
	return payload


def _inspect_regular_file(
	path: Path,
	capture: bool,
	*,
	deadline: float | None = None,
) -> tuple[int, str, bytes]:
	_check_deadline(deadline, "package artifact file inspection")
	path = gf_path_security.absolute_lexical_path(path)
	if gf_path_security.path_has_reparse_component(path):
		raise PackageArtifactSetError(
			f"Package artifact crosses a symlink, junction, or reparse point: {path.as_posix()}"
		)
	try:
		before = os.lstat(path)
	except OSError as exc:
		raise PackageArtifactSetError(f"Package artifact is missing or unreadable: {path.as_posix()}: {exc}") from exc
	if not stat.S_ISREG(before.st_mode) or _metadata_is_reparse(before):
		raise PackageArtifactSetError(f"Package artifact is not a regular file: {path.as_posix()}")
	flags = os.O_RDONLY | getattr(os, "O_BINARY", 0) | getattr(os, "O_CLOEXEC", 0)
	flags |= getattr(os, "O_NOFOLLOW", 0)
	try:
		file_descriptor = os.open(path, flags)
	except OSError as exc:
		raise PackageArtifactSetError(f"Could not open package artifact: {path.as_posix()}: {exc}") from exc
	digest = hashlib.sha256()
	payload_chunks: list[bytes] = []
	byte_count = 0
	try:
		_check_deadline(deadline, "package artifact file inspection")
		opened_before = os.fstat(file_descriptor)
		if not stat.S_ISREG(opened_before.st_mode) or _metadata_is_reparse(opened_before):
			raise PackageArtifactSetError(f"Package artifact changed type while opening: {path.as_posix()}")
		if not os.path.samestat(before, opened_before):
			raise PackageArtifactSetError(f"Package artifact changed while opening: {path.as_posix()}")
		while True:
			_check_deadline(deadline, "package artifact file reading")
			chunk = os.read(file_descriptor, 1024 * 1024)
			if not chunk:
				break
			digest.update(chunk)
			byte_count += len(chunk)
			if capture:
				payload_chunks.append(chunk)
		_check_deadline(deadline, "package artifact file reading")
		opened_after = os.fstat(file_descriptor)
	finally:
		os.close(file_descriptor)
	try:
		after = os.lstat(path)
	except OSError as exc:
		raise PackageArtifactSetError(f"Package artifact disappeared while reading: {path.as_posix()}") from exc
	if (
		not os.path.samestat(opened_before, opened_after)
		or not os.path.samestat(opened_after, after)
		or opened_before.st_size != opened_after.st_size
		or opened_before.st_mtime_ns != opened_after.st_mtime_ns
		or byte_count != opened_after.st_size
		or _metadata_is_reparse(after)
		or gf_path_security.path_has_reparse_component(path)
	):
		raise PackageArtifactSetError(f"Package artifact changed while being read: {path.as_posix()}")
	_check_deadline(deadline, "package artifact file inspection")
	payload = b"".join(payload_chunks)
	_check_deadline(deadline, "package artifact file inspection")
	return byte_count, digest.hexdigest(), payload


def _copy_regular_file_with_deadline(
	source: Path,
	destination: Path,
	*,
	deadline: float | None = None,
) -> None:
	"""Copy one real regular file while checking the owning performance-clock deadline per chunk."""
	_check_deadline(deadline, "package artifact copying")
	source_path = gf_path_security.absolute_lexical_path(source)
	destination_path = gf_path_security.absolute_lexical_path(destination)
	if gf_path_security.path_has_reparse_component(source_path):
		raise PackageArtifactSetError(
			f"Package artifact copy source crosses a symlink, junction, or reparse point: "
			f"{source_path.as_posix()}"
		)
	if gf_path_security.path_has_reparse_component(destination_path):
		raise PackageArtifactSetError(
			f"Package artifact copy destination crosses a symlink, junction, or reparse point: "
			f"{destination_path.as_posix()}"
		)
	try:
		source_before = os.lstat(source_path)
	except OSError as exc:
		raise PackageArtifactSetError(
			f"Package artifact copy source is missing or unreadable: {source_path.as_posix()}: {exc}"
		) from exc
	if not stat.S_ISREG(source_before.st_mode) or _metadata_is_reparse(source_before):
		raise PackageArtifactSetError(
			f"Package artifact copy source is not a regular file: {source_path.as_posix()}"
		)
	if os.path.lexists(destination_path):
		raise PackageArtifactSetError(
			f"Package artifact copy destination already exists: {destination_path.as_posix()}"
		)

	read_flags = os.O_RDONLY | getattr(os, "O_BINARY", 0) | getattr(os, "O_CLOEXEC", 0)
	read_flags |= getattr(os, "O_NOFOLLOW", 0)
	write_flags = (
		os.O_CREAT
		| os.O_EXCL
		| os.O_WRONLY
		| getattr(os, "O_BINARY", 0)
		| getattr(os, "O_CLOEXEC", 0)
	)
	write_flags |= getattr(os, "O_NOFOLLOW", 0)
	source_descriptor = -1
	destination_descriptor = -1
	try:
		source_descriptor = os.open(source_path, read_flags)
		opened_before = os.fstat(source_descriptor)
		if (
			not stat.S_ISREG(opened_before.st_mode)
			or _metadata_is_reparse(opened_before)
			or not os.path.samestat(source_before, opened_before)
		):
			raise PackageArtifactSetError(
				f"Package artifact copy source changed while opening: {source_path.as_posix()}"
			)
		destination_descriptor = os.open(
			destination_path,
			write_flags,
			stat.S_IMODE(source_before.st_mode),
		)
		while True:
			_check_deadline(deadline, "package artifact copying")
			chunk = os.read(source_descriptor, 1024 * 1024)
			if not chunk:
				break
			view = memoryview(chunk)
			while view:
				_check_deadline(deadline, "package artifact copying")
				written = os.write(destination_descriptor, view)
				if written <= 0:
					raise PackageArtifactSetError(
						f"Package artifact copy made no write progress: {destination_path.as_posix()}"
					)
				view = view[written:]
		_check_deadline(deadline, "package artifact copying")
		opened_after = os.fstat(source_descriptor)
	finally:
		if destination_descriptor >= 0:
			os.close(destination_descriptor)
		if source_descriptor >= 0:
			os.close(source_descriptor)

	try:
		source_after = os.lstat(source_path)
		destination_metadata = os.lstat(destination_path)
	except OSError as exc:
		raise PackageArtifactSetError(
			f"Package artifact copy could not validate its completed files: {exc}"
		) from exc
	if (
		not os.path.samestat(opened_before, opened_after)
		or not os.path.samestat(opened_after, source_after)
		or opened_before.st_size != opened_after.st_size
		or opened_before.st_mtime_ns != opened_after.st_mtime_ns
		or _metadata_is_reparse(source_after)
		or not stat.S_ISREG(destination_metadata.st_mode)
		or _metadata_is_reparse(destination_metadata)
		or destination_metadata.st_size != opened_after.st_size
		or gf_path_security.path_has_reparse_component(source_path)
		or gf_path_security.path_has_reparse_component(destination_path)
	):
		raise PackageArtifactSetError(
			f"Package artifact changed while being copied: {source_path.as_posix()}"
		)
	_check_deadline(deadline, "package artifact copying")


def _metadata_is_reparse(metadata: os.stat_result) -> bool:
	return stat.S_ISLNK(metadata.st_mode) or bool(
		int(getattr(metadata, "st_file_attributes", 0)) & gf_path_security.FILE_ATTRIBUTE_REPARSE_POINT
	)


def _atomic_write_json(
	path: Path,
	data: Mapping[str, Any],
	*,
	deadline: float | None = None,
) -> None:
	_check_deadline(deadline, "package artifact JSON write")
	path = gf_path_security.absolute_lexical_path(path)
	if not path.parent.is_dir() or gf_path_security.path_has_reparse_component(path):
		raise PackageArtifactSetError(f"Atomic JSON destination is unsafe: {path.as_posix()}")
	if os.path.lexists(path):
		raise PackageArtifactSetError(f"Atomic JSON destination already exists: {path.as_posix()}")
	payload = _json_bytes(data, deadline=deadline)
	temporary = path.parent / f".{path.name}.tmp-{os.getpid()}-{secrets.token_hex(12)}"
	if os.path.lexists(temporary) or gf_path_security.path_has_reparse_component(temporary):
		raise PackageArtifactSetError(f"Atomic JSON staging path is unsafe: {temporary.as_posix()}")
	try:
		with temporary.open("xb") as handle:
			offset = 0
			while offset < len(payload):
				_check_deadline(deadline, "package artifact JSON write")
				written = handle.write(payload[offset:offset + 1024 * 1024])
				if written is None or written <= 0:
					raise PackageArtifactSetError(
						f"Atomic JSON write made no progress: {temporary.as_posix()}"
					)
				offset += written
			handle.flush()
			os.fsync(handle.fileno())
		_check_deadline(deadline, "package artifact JSON write")
		if os.path.lexists(path):
			raise PackageArtifactSetError(f"Atomic JSON destination was concurrently created: {path.as_posix()}")
		if gf_path_security.path_has_reparse_component(temporary):
			raise PackageArtifactSetError(f"Atomic JSON staging path became unsafe: {temporary.as_posix()}")
		os.replace(temporary, path)
		_sync_directory(path.parent)
		_check_deadline(deadline, "package artifact JSON write")
	finally:
		if os.path.lexists(temporary):
			try:
				temporary.unlink()
			except OSError:
				pass


def _json_bytes(
	data: Mapping[str, Any],
	*,
	deadline: float | None = None,
) -> bytes:
	_check_deadline(deadline, "package artifact JSON serialization")
	try:
		payload = (json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")
	except (TypeError, ValueError) as exc:
		raise PackageArtifactSetError(f"Package artifact JSON data is not serializable: {exc}") from exc
	_check_deadline(deadline, "package artifact JSON serialization")
	return payload


def _json_clone(
	value: Mapping[str, Any],
	label: str,
	*,
	deadline: float | None = None,
) -> dict[str, Any]:
	if not isinstance(value, Mapping):
		raise PackageArtifactSetError(f"{label} must be an object.")
	payload = _json_bytes(value, deadline=deadline)
	return _parse_json_object(payload, label, deadline=deadline)


def _load_json_object(
	path: Path,
	label: str,
	*,
	deadline: float | None = None,
) -> dict[str, Any]:
	return _parse_json_object(
		_read_regular_bytes(path, deadline=deadline),
		label,
		deadline=deadline,
	)


def _parse_json_object(
	payload: bytes,
	label: str,
	*,
	deadline: float | None = None,
) -> dict[str, Any]:
	_check_deadline(deadline, "package artifact JSON parsing")
	try:
		text = payload.decode("utf-8")
		value = json.loads(
			text,
			object_pairs_hook=_reject_duplicate_json_keys,
			parse_constant=_reject_json_constant,
		)
	except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
		raise PackageArtifactSetError(f"{label} is not valid UTF-8 JSON: {exc}") from exc
	if not isinstance(value, dict):
		raise PackageArtifactSetError(f"{label} root must be an object.")
	_check_deadline(deadline, "package artifact JSON parsing")
	return value


def _check_deadline(deadline: float | None, operation: str) -> None:
	"""Fail when a caller-provided perf_counter absolute deadline has elapsed."""
	if deadline is None:
		return
	if isinstance(deadline, bool) or not isinstance(deadline, (int, float)):
		raise PackageArtifactDeadlineError("Package artifact deadline must be a finite performance-clock timestamp.")
	deadline_value = float(deadline)
	if not math.isfinite(deadline_value):
		raise PackageArtifactDeadlineError("Package artifact deadline must be a finite performance-clock timestamp.")
	if time.perf_counter() >= deadline_value:
		raise PackageArtifactDeadlineError(f"Package artifact deadline exhausted during {operation}.")


def _reject_duplicate_json_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
	result: dict[str, Any] = {}
	for key, value in pairs:
		if key in result:
			raise ValueError(f"duplicate JSON key: {key}")
		result[key] = value
	return result


def _reject_json_constant(value: str) -> Any:
	raise ValueError(f"non-finite JSON number: {value}")


def _require_sha256(value: Any, label: str) -> str:
	if not isinstance(value, str) or _SHA256_PATTERN.fullmatch(value) is None:
		raise PackageArtifactSetError(f"{label} must be a full lowercase SHA-256 digest.")
	return value


def _is_int(value: Any) -> bool:
	return isinstance(value, int) and not isinstance(value, bool)


def _sync_directory(path: Path) -> None:
	if os.name == "nt":
		return
	flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
	file_descriptor = os.open(path, flags)
	try:
		os.fsync(file_descriptor)
	finally:
		os.close(file_descriptor)


def _safe_remove_private_tree(
	path: Path,
	*,
	expected_identity: os.stat_result,
) -> str:
	try:
		_scan_tree(path)
		metadata = path.lstat()
	except (OSError, PackageArtifactSetError) as error:
		return f"Could not validate private artifact staging cleanup root {path}: {error}"
	if not _same_owned_directory_identity(expected_identity, metadata):
		return f"Refusing to clean replaced private artifact staging root: {path}"
	cleanup_path: Path | str = path
	if os.name == "nt" and not str(path).startswith("\\\\?\\"):
		cleanup_path = "\\\\?\\" + str(path)
	last_error = ""
	for attempt in range(8):
		try:
			shutil.rmtree(cleanup_path, onexc=_make_remove_writable)
			return ""
		except FileNotFoundError:
			return ""
		except OSError as error:
			last_error = str(error)
		time.sleep(min(0.1 * (2 ** attempt), 1.0))
	return f"Could not clean private artifact staging root {path} after bounded retries: {last_error}"


def _same_owned_directory_identity(left: os.stat_result, right: os.stat_result) -> bool:
	left_device = int(getattr(left, "st_dev", 0))
	left_inode = int(getattr(left, "st_ino", 0))
	return (
		stat.S_ISDIR(left.st_mode)
		and stat.S_ISDIR(right.st_mode)
		and left.st_mode == right.st_mode
		and (left_device != 0 or left_inode != 0)
		and left_device == int(getattr(right, "st_dev", 0))
		and left_inode == int(getattr(right, "st_ino", 0))
	)


def _make_remove_writable(function: Any, path: str, error: BaseException) -> None:
	try:
		os.chmod(path, stat.S_IWRITE)
		function(path)
	except OSError:
		raise error


__all__ = [
	"BUILDER_RESULT_RELATIVE_PATH",
	"MANIFEST_FILENAME",
	"MANIFEST_KIND",
	"MANIFEST_SCHEMA_VERSION",
	"OFFLINE_BUNDLE_RELATIVE_PATH",
	"PackageArtifact",
	"PackageArtifactInput",
	"PackageArtifactSet",
	"PackageArtifactSetError",
	"REGISTRY_RELATIVE_PATH",
	"REGISTRY_SOURCE_RELATIVE_PATH",
	"ROLE_BUILDER_RESULT",
	"ROLE_OFFLINE_BUNDLE",
	"ROLE_PACKAGE",
	"ROLE_REGISTRY",
	"ROLE_REGISTRY_SOURCE",
	"assemble_package_artifact_inputs",
	"assemble_package_artifact_set_inputs",
	"load_package_artifact_set",
	"materialize_package_artifact_set",
	"rebase_package_builder_data",
	"revalidate_package_artifact_set",
	"seal_package_artifact_set",
	"validate_package_artifact_set",
]
