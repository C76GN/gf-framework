#!/usr/bin/env python3
"""Focused tests for strict, advisory GF validation input analysis."""

from __future__ import annotations

import copy
import hashlib
import inspect
import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
TOOLS_ROOT = ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
	sys.path.insert(0, str(TOOLS_ROOT))

import gf_validation_catalog
import gf_validation_contracts
import gf_validation_inputs as inputs
from gf_process_authority import FrozenGitProcess
from gf_process_authority import FrozenProcessEnvironment
from gf_process_authority import freeze_git_process
from gf_process_supervisor import SupervisedBinaryProcessResult
from gf_process_supervisor import SupervisedProcessCleanupError


def _write(path: Path, content: str) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_text(content, encoding="utf-8", newline="\n")


def _make_input_root(parent: Path) -> Path:
	root = parent / "repository"
	root.mkdir()
	_write(root / "README.md", "# Public\n")
	_write(root / "docs/guide.md", "Guide\n")
	_write(root / "docs/reference/api/internal.md", "Excluded\n")
	_write(root / "docs/notes.txt", "Not selected\n")
	_write(root / "tools/checker.py", "RULE_VERSION = 1\n")
	return root


def _remove_directory_link(path: Path) -> None:
	if path.is_symlink():
		path.unlink()
	elif os.path.lexists(path):
		path.rmdir()


def _create_directory_link(target: Path, link: Path) -> None:
	if os.name != "nt":
		os.symlink(target, link, target_is_directory=True)
		return
	command_processor = os.environ.get("COMSPEC", "cmd.exe")
	arguments = subprocess.list2cmdline([os.fspath(link), os.fspath(target)])
	completed = subprocess.run(
		[command_processor, "/d", "/s", "/c", f"mklink /J {arguments}"],
		capture_output=True,
		text=True,
		encoding="utf-8",
		errors="replace",
	)
	if completed.returncode != 0 or not os.path.lexists(link):
		raise OSError("could not create directory-link test fixture")


def _input_spec(
	check_name: str = "public_docs_boundary",
) -> gf_validation_contracts.CheckInputSpec:
	return gf_validation_contracts.CheckInputSpec(
		check_name=check_name,
		source_rules=(
			gf_validation_contracts.PathRule(
				"tree",
				"docs",
				suffixes=(".md",),
				excluded_prefixes=("docs/reference/api",),
			),
			gf_validation_contracts.PathRule("exact", "README.md"),
		),
		implementation_files=("tools/checker.py",),
	)


def _default_input_specs() -> tuple[gf_validation_contracts.CheckInputSpec, ...]:
	context = gf_validation_catalog.ValidationCatalogContext(
		python_executable=sys.executable,
		root=ROOT,
		godot_log_directory=ROOT / ".godot" / "gf-test-logs",
		gut_lifecycle_cli_resource_path="res://tests/gf_core/support/gf_gut_cli.gd",
		gut_shard_config_disabled_argument="-gconfig=",
		gut_lifecycle_hook_arguments=(
			"-gpre_run_script=res://tests/gf_core/support/gf_gut_pre_run_hook.gd",
			"-gpost_run_script=res://tests/gf_core/support/gf_gut_post_run_hook.gd",
		),
		default_reference_project="../gf-reference-project",
		reference_boot_scene="res://scenes/app/driftbound_boot.tscn",
		reference_smoke_scene="res://tests/smoke/driftbound_smoke.tscn",
	)
	return gf_validation_catalog.build_validation_catalog(context).input_specs


def _run_git(root: Path, *arguments: str) -> str:
	completed = subprocess.run(
		["git", *arguments],
		cwd=root,
		capture_output=True,
		text=True,
		encoding="utf-8",
		errors="replace",
		check=False,
	)
	if completed.returncode != 0:
		raise AssertionError(completed.stderr)
	return completed.stdout.strip()


def _frozen_git_process(root: Path) -> FrozenGitProcess:
	return freeze_git_process(
		FrozenProcessEnvironment.capture(dict(os.environ)),
		cwd=root,
	)


def _make_git_repository(parent: Path) -> Path:
	root = _make_input_root(parent)
	_run_git(root, "init", "--quiet")
	_run_git(root, "config", "user.email", "tests@example.invalid")
	_run_git(root, "config", "user.name", "GF Tests")
	_write(root / ".gitignore", "docs/ignored.md\n")
	_write(root / "unrelated.txt", "unrelated\n")
	_run_git(root, "add", "--all")
	_run_git(root, "commit", "--quiet", "-m", "fixture")
	return root


def _make_default_catalog_git_repository(parent: Path) -> Path:
	root = parent / "default-catalog-repository"
	root.mkdir()
	for path, content in (
		("addons/gf/plugin.gd", "extends EditorPlugin\n"),
		("addons/gf/kernel/package/manager.gd", "class_name GFPackageManager\n"),
		("addons/gf/kernel/editor/package/installer.gd", "extends RefCounted\n"),
		("addons/gf/README.md", "# GF\n"),
		("addons/gf/extensions/README.md", "# Extensions\n"),
		("ASSET_LIBRARY.md", "Asset Library\n"),
		("ASSET_STORE.md", "Asset Store\n"),
		("README.md", "# GF\n"),
		("README.zh.md", "# GF\n"),
		("docs/api_catalog/index.xml", "<api />\n"),
		("docs/wiki/index.md", "Wiki\n"),
		("docs/zh/guide.md", "Guide\n"),
		("docs/zh/reference/api/GFNode.md", "Reference\n"),
		("tools/gdscript_api_parser.py", "PARSER_VERSION = 1\n"),
		("tools/gf_api_owners.py", "OWNER_VERSION = 1\n"),
		("tools/gf_maintenance.py", "RULE_VERSION = 1\n"),
		("tools/gf_validation_catalog.py", "CATALOG_VERSION = 1\n"),
		("tools/gf_validation_contracts.py", "CONTRACTS_VERSION = 1\n"),
		("tools/gf_validation_inputs.py", "INPUT_VERSION = 1\n"),
		("tools/gf_workspace_snapshot.py", "SNAPSHOT_VERSION = 1\n"),
	):
		_write(root / path, content)
	_run_git(root, "init", "--quiet")
	_run_git(root, "config", "user.email", "tests@example.invalid")
	_run_git(root, "config", "user.name", "GF Tests")
	_run_git(root, "add", "--all")
	_run_git(root, "commit", "--quiet", "-m", "default catalog fixture")
	return root


class InputSpecContractTests(unittest.TestCase):
	def test_default_catalog_declares_only_three_phase_two_candidates(self) -> None:
		input_specs = _default_input_specs()
		input_spec_by_name = {spec.check_name: spec for spec in input_specs}
		self.assertEqual(
			[spec.check_name for spec in input_specs],
			[
				"public_docs_boundary",
				"public_api_boundary",
				"package_user_dependency_boundary",
			],
		)
		self.assertEqual(
			set(input_spec_by_name),
			{
				"package_user_dependency_boundary",
				"public_api_boundary",
				"public_docs_boundary",
			},
		)
		expected_implementation_files = {
			"package_user_dependency_boundary": (
				"tools/gf_maintenance.py",
				"tools/gf_validation_catalog.py",
				"tools/gf_validation_contracts.py",
				"tools/gf_validation_inputs.py",
				"tools/gf_workspace_snapshot.py",
			),
			"public_api_boundary": (
				"tools/gdscript_api_parser.py",
				"tools/gf_api_owners.py",
				"tools/gf_maintenance.py",
				"tools/gf_validation_catalog.py",
				"tools/gf_validation_contracts.py",
				"tools/gf_validation_inputs.py",
				"tools/gf_workspace_snapshot.py",
			),
			"public_docs_boundary": (
				"tools/gf_maintenance.py",
				"tools/gf_validation_catalog.py",
				"tools/gf_validation_contracts.py",
				"tools/gf_validation_inputs.py",
				"tools/gf_workspace_snapshot.py",
			),
		}
		for spec in input_specs:
			with self.subTest(check_name=spec.check_name):
				self.assertEqual(
					spec.implementation_files,
					expected_implementation_files[spec.check_name],
				)
				self.assertFalse(hasattr(spec, "reuse_scope"))
				self.assertFalse(hasattr(spec, "input_closure"))

		public_docs = input_spec_by_name[
			"public_docs_boundary"
		]
		self.assertTrue(public_docs.matches_source_path("docs/zh/guide.md"))
		self.assertFalse(
			public_docs.matches_source_path("docs/zh/reference/api/GFNode.md")
		)
		self.assertTrue(public_docs.matches_source_path("ASSET_STORE.md"))
		public_api = input_spec_by_name[
			"public_api_boundary"
		]
		self.assertTrue(public_api.matches_source_path("addons/gf/kernel/node.gd"))
		self.assertFalse(public_api.matches_source_path("addons/gf/README.md"))
		package_user = input_spec_by_name[
			"package_user_dependency_boundary"
		]
		self.assertTrue(package_user.matches_source_path("addons/gf/plugin.gd"))
		self.assertTrue(package_user.matches_source_path(
			"addons/gf/kernel/editor/package/installer.gd"
		))
		self.assertFalse(package_user.matches_source_path(
			"addons/gf/standard/package/example.gd"
		))

	def test_path_rule_and_input_spec_have_exact_versioned_round_trip(self) -> None:
		spec = _input_spec()
		payload = spec.to_dict()
		self.assertEqual(
			payload["schema_version"],
			gf_validation_contracts.INPUT_SPEC_SCHEMA_VERSION,
		)
		self.assertEqual(
			set(payload),
			{
				"schema_version",
				"check_name",
				"source_rules",
				"implementation_files",
				"consumed_artifacts",
			},
		)
		encoded = json.dumps(payload, allow_nan=False, ensure_ascii=False, sort_keys=True)
		self.assertEqual(
			inputs.CheckInputSpec.from_dict(json.loads(encoded)),
			spec,
		)
		self.assertRegex(spec.digest, r"^[0-9a-f]{64}$")

	def test_noncanonical_or_unsafe_paths_fail_closed(self) -> None:
		for path in (
			"",
			"/absolute",
			"docs\\guide.md",
			"docs/../guide.md",
			"./docs",
			"docs/",
			"docs//guide.md",
			"docs/CON.txt",
			"docs/trailing.",
			"docs/control\tname.md",
		):
			with self.subTest(path=path):
				with self.assertRaises(inputs.ValidationInputContractError):
					inputs.PathRule("exact", path)

	def test_exact_and_tree_options_are_strict_and_canonical(self) -> None:
		invalid_arguments = (
			("exact", "README.md", (".md",), ()),
			("tree", "docs", ("md",), ()),
			("tree", "docs", (".MD",), ()),
			("tree", "docs", (".txt", ".md"), ()),
			("tree", "docs", (".md", ".md"), ()),
			("tree", "docs", (".md",), ("other",)),
			(
				"tree",
				"docs",
				(".md",),
				("docs/private", "docs/private/nested"),
			),
		)
		for kind, path, suffixes, exclusions in invalid_arguments:
			with self.subTest(kind=kind, suffixes=suffixes, exclusions=exclusions):
				with self.assertRaises(inputs.ValidationInputContractError):
					inputs.PathRule(kind, path, suffixes, exclusions)

	def test_input_spec_rejects_duplicates_bad_order_and_missing_implementation(self) -> None:
		rule = inputs.PathRule("exact", "README.md")
		for source_rules, implementation_files in (
			((), ("tools/checker.py",)),
			((rule,), ()),
			((rule, rule), ("tools/checker.py",)),
			((rule,), ("z.py", "a.py")),
			((rule,), ("tools/checker.py", "tools/checker.py")),
		):
			with self.subTest(source_rules=source_rules, implementation_files=implementation_files):
				with self.assertRaises(inputs.ValidationInputContractError):
					inputs.CheckInputSpec(
						"check_name",
						source_rules,
						implementation_files,
					)

	def test_decoder_rejects_missing_extra_and_wrong_scalar_shapes(self) -> None:
		payload = _input_spec().to_dict()
		mutations: list[dict[str, object]] = []
		missing = dict(payload)
		missing.pop("source_rules")
		mutations.append(missing)
		extra = dict(payload)
		extra["glob"] = "**/*"
		mutations.append(extra)
		wrong_schema = dict(payload)
		wrong_schema["schema_version"] = True
		mutations.append(wrong_schema)
		wrong_array = dict(payload)
		wrong_array["source_rules"] = {}
		mutations.append(wrong_array)
		for mutated in mutations:
			with self.subTest(mutated=mutated):
				with self.assertRaises(inputs.ValidationInputContractError):
					inputs.CheckInputSpec.from_dict(mutated)

	def test_path_matching_is_prefix_safe_excluded_and_suffix_conservative(self) -> None:
		rule = inputs.PathRule(
			"tree",
			"docs",
			suffixes=(".md",),
			excluded_prefixes=("docs/reference/api",),
		)
		self.assertTrue(rule.matches("docs/guide.md"))
		self.assertTrue(rule.matches("docs/GUIDE.MD"))
		self.assertFalse(rule.matches("docs2/guide.md"))
		self.assertFalse(rule.matches("docs/guide.txt"))
		self.assertFalse(rule.matches("docs/reference/api/page.md"))


class FrozenActionInputTests(unittest.TestCase):
	def test_capture_is_stable_bounded_and_does_not_leak_absolute_paths(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_input_root(Path(temporary_directory))
			first = inputs.freeze_action_inputs(root, _input_spec())
			second = inputs.freeze_action_inputs(root, _input_spec())

			self.assertEqual(first, second)
			self.assertTrue(first.capture_complete)
			self.assertEqual(first.source_entry_count, 2)
			self.assertEqual(first.implementation_entry_count, 1)
			self.assertEqual(first.artifact_count, 0)
			self.assertEqual(first.unknown_reasons, ())
			self.assertEqual(
				set(first.action_key_input_digests()),
				{
					"input_spec",
					"source_manifest",
					"implementation_manifest",
					"discovery",
					"consumed_artifacts",
				},
			)
			serialized = json.dumps(first.to_dict(), sort_keys=True)
			self.assertNotIn(str(root), serialized)
			self.assertEqual(
				inputs.FrozenActionInputs.from_dict(first.to_dict()),
				first,
			)

	def test_source_content_membership_and_implementation_have_separate_digests(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_input_root(Path(temporary_directory))
			spec = _input_spec()
			baseline = inputs.freeze_action_inputs(root, spec)

			_write(root / "docs/notes.txt", "Unselected changed\n")
			unselected = inputs.freeze_action_inputs(root, spec)
			self.assertEqual(unselected, baseline)

			_write(root / "docs/guide.md", "Changed guide\n")
			source_changed = inputs.freeze_action_inputs(root, spec)
			self.assertNotEqual(
				source_changed.source_manifest_digest,
				baseline.source_manifest_digest,
			)
			self.assertEqual(
				source_changed.implementation_manifest_digest,
				baseline.implementation_manifest_digest,
			)

			_write(root / "docs/new.md", "New member\n")
			membership_changed = inputs.freeze_action_inputs(root, spec)
			self.assertNotEqual(
				membership_changed.discovery_digest,
				source_changed.discovery_digest,
			)

			_write(root / "tools/checker.py", "RULE_VERSION = 2\n")
			implementation_changed = inputs.freeze_action_inputs(root, spec)
			self.assertNotEqual(
				implementation_changed.implementation_manifest_digest,
				membership_changed.implementation_manifest_digest,
			)

	def test_input_spec_change_changes_candidate_action_identity(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_input_root(Path(temporary_directory))
			baseline = inputs.freeze_action_inputs(root, _input_spec())
			changed_spec = replace(
				_input_spec(),
				source_rules=(
					inputs.PathRule(
						"tree",
						"docs",
						suffixes=(".md", ".txt"),
						excluded_prefixes=("docs/reference/api",),
					),
					inputs.PathRule("exact", "README.md"),
				),
			)
			changed = inputs.freeze_action_inputs(root, changed_spec)
			self.assertNotEqual(changed.input_spec_digest, baseline.input_spec_digest)
			self.assertNotEqual(changed.discovery_digest, baseline.discovery_digest)
			self.assertNotEqual(changed.source_manifest_digest, baseline.source_manifest_digest)

	def test_missing_exact_source_is_frozen_but_missing_implementation_fails(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_input_root(Path(temporary_directory))
			missing_source = inputs.CheckInputSpec(
				"missing_source",
				(inputs.PathRule("exact", "optional/missing.md"),),
				("tools/checker.py",),
			)
			frozen = inputs.freeze_action_inputs(root, missing_source)
			self.assertTrue(frozen.capture_complete)
			self.assertEqual(frozen.source_entry_count, 1)

			missing_implementation = inputs.CheckInputSpec(
				"missing_implementation",
				(inputs.PathRule("exact", "README.md"),),
				("tools/missing.py",),
			)
			with self.assertRaises(inputs.ValidationInputCaptureError):
				inputs.freeze_action_inputs(root, missing_implementation)

	def test_consumed_artifacts_require_exact_named_digest_set(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_input_root(Path(temporary_directory))
			spec = replace(_input_spec(), consumed_artifacts=("package.archive",))
			with self.assertRaises(inputs.ValidationInputCaptureError):
				inputs.freeze_action_inputs(root, spec)
			digest = hashlib.sha256(b"artifact").hexdigest()
			frozen = inputs.freeze_action_inputs(
				root,
				spec,
				artifact_digests={"package.archive": digest},
			)
			self.assertEqual(frozen.artifact_count, 1)
			with self.assertRaises(inputs.ValidationInputCaptureError):
				inputs.freeze_action_inputs(
					root,
					spec,
					artifact_digests={"other": digest},
				)

	def test_limits_links_and_special_files_fail_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_input_root(Path(temporary_directory))
			with self.assertRaises(inputs.ValidationInputLimitError):
				inputs.freeze_action_inputs(
					root,
					_input_spec(),
					limits=replace(
						inputs.DEFAULT_INPUT_CAPTURE_LIMITS,
						max_file_bytes=4,
					),
				)

			link_path = root / "docs/link.md"
			try:
				os.symlink(root / "README.md", link_path)
			except OSError:
				pass
			else:
				with self.assertRaises(inputs.ValidationInputCaptureError):
					inputs.freeze_action_inputs(root, _input_spec())

	def test_file_identity_drift_during_read_fails_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_input_root(Path(temporary_directory))
			original_read = inputs.os.read
			mutated = False

			def drifting_read(file_descriptor: int, size: int) -> bytes:
				nonlocal mutated
				data = original_read(file_descriptor, size)
				if not mutated:
					mutated = True
					with (root / "README.md").open("ab") as stream:
						stream.write(b"drift")
				return data

			with mock.patch.object(inputs.os, "read", side_effect=drifting_read):
				with self.assertRaises(inputs.ValidationInputDriftError):
					inputs.freeze_action_inputs(
						root,
						inputs.CheckInputSpec(
							"drift_check",
							(inputs.PathRule("exact", "README.md"),),
							("tools/checker.py",),
						),
					)

	def test_declared_file_parent_replacement_during_open_fails_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_input_root(Path(temporary_directory))
			docs = root / "docs"
			moved_docs = root / "docs-before-replacement"
			original_open = inputs.os.open
			replaced = False

			def replacing_open(path: object, flags: int, *args: object, **kwargs: object) -> int:
				nonlocal replaced
				if Path(path) == docs / "guide.md" and not replaced:
					docs.rename(moved_docs)
					try:
						_create_directory_link(moved_docs, docs)
					except OSError as error:
						raise unittest.SkipTest(
							"directory-link fixtures are unavailable"
						) from error
					replaced = True
				return original_open(path, flags, *args, **kwargs)

			try:
				with mock.patch.object(inputs.os, "open", side_effect=replacing_open):
					with self.assertRaises(inputs.ValidationInputDriftError):
						inputs.freeze_action_inputs(root, _input_spec())
			finally:
				if moved_docs.exists() and os.path.lexists(docs):
					_remove_directory_link(docs)
				if moved_docs.exists():
					moved_docs.rename(docs)

	def test_repository_ancestor_replacement_during_open_fails_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			temporary_root = Path(temporary_directory)
			workspace = temporary_root / "workspace"
			workspace.mkdir()
			root = _make_input_root(workspace)
			moved_workspace = temporary_root / "workspace-before-replacement"
			original_open = inputs.os.open
			replaced = False

			def replacing_open(path: object, flags: int, *args: object, **kwargs: object) -> int:
				nonlocal replaced
				if Path(path) == root / "docs/guide.md" and not replaced:
					workspace.rename(moved_workspace)
					try:
						_create_directory_link(moved_workspace, workspace)
					except OSError as error:
						raise unittest.SkipTest(
							"directory-link fixtures are unavailable"
						) from error
					replaced = True
				return original_open(path, flags, *args, **kwargs)

			try:
				with mock.patch.object(inputs.os, "open", side_effect=replacing_open):
					with self.assertRaises(inputs.ValidationInputDriftError):
						inputs.freeze_action_inputs(root, _input_spec())
			finally:
				if moved_workspace.exists() and os.path.lexists(workspace):
					_remove_directory_link(workspace)
				if moved_workspace.exists():
					moved_workspace.rename(workspace)

	def test_parent_replacement_after_location_before_file_snapshot_fails_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_input_root(Path(temporary_directory))
			docs = root / "docs"
			moved_docs = root / "docs-before-replacement"
			original_locate = inputs._locate_declared_path
			replaced = False

			def replacing_locate(*args: object, **kwargs: object) -> object:
				nonlocal replaced
				located = original_locate(*args, **kwargs)
				if args[1] == "docs/guide.md" and not replaced:
					docs.rename(moved_docs)
					try:
						_create_directory_link(moved_docs, docs)
					except OSError as error:
						raise unittest.SkipTest(
							"directory-link fixtures are unavailable"
						) from error
					replaced = True
				return located

			try:
				with mock.patch.object(
					inputs,
					"_locate_declared_path",
					side_effect=replacing_locate,
				):
					with self.assertRaises(inputs.ValidationInputDriftError):
						inputs.freeze_action_inputs(
							root,
							inputs.CheckInputSpec(
								"exact_source",
								(inputs.PathRule("exact", "docs/guide.md"),),
								("tools/checker.py",),
							),
						)
			finally:
				if moved_docs.exists() and os.path.lexists(docs):
					_remove_directory_link(docs)
				if moved_docs.exists():
					moved_docs.rename(docs)

	def test_missing_exact_source_retains_and_revalidates_existing_parent_chain(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_input_root(Path(temporary_directory))
			optional = root / "optional"
			optional.mkdir()
			moved_optional = root / "optional-before-replacement"
			original_locate = inputs._locate_declared_path
			replaced = False

			def replacing_locate(*args: object, **kwargs: object) -> object:
				nonlocal replaced
				located = original_locate(*args, **kwargs)
				if args[1] == "optional/missing.md" and not replaced:
					optional.rename(moved_optional)
					try:
						_create_directory_link(moved_optional, optional)
					except OSError as error:
						raise unittest.SkipTest(
							"directory-link fixtures are unavailable"
						) from error
					replaced = True
				return located

			spec = inputs.CheckInputSpec(
				"missing_source",
				(inputs.PathRule("exact", "optional/missing.md"),),
				("tools/checker.py",),
			)
			try:
				with mock.patch.object(
					inputs,
					"_locate_declared_path",
					side_effect=replacing_locate,
				):
					with self.assertRaises(inputs.ValidationInputDriftError):
						inputs.freeze_action_inputs(root, spec)
			finally:
				if moved_optional.exists() and os.path.lexists(optional):
					_remove_directory_link(optional)
				if moved_optional.exists():
					moved_optional.rename(optional)

	def test_missing_exact_source_appearance_after_location_fails_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_input_root(Path(temporary_directory))
			optional = root / "optional"
			optional.mkdir()
			target = optional / "missing.md"
			original_locate = inputs._locate_declared_path
			created = False

			def creating_locate(*args: object, **kwargs: object) -> object:
				nonlocal created
				located = original_locate(*args, **kwargs)
				if args[1] == "optional/missing.md" and not created:
					target.write_text("appeared\n", encoding="utf-8")
					created = True
				return located

			with mock.patch.object(
				inputs,
				"_locate_declared_path",
				side_effect=creating_locate,
			):
				with self.assertRaises(inputs.ValidationInputDriftError):
					inputs.freeze_action_inputs(
						root,
						inputs.CheckInputSpec(
							"missing_source",
							(inputs.PathRule("exact", "optional/missing.md"),),
							("tools/checker.py",),
						),
					)

	def test_open_file_identity_requires_ctime_on_posix_only(self) -> None:
		baseline = inputs._FileSnapshot(1, 2, stat.S_IFREG, 3, 4, 5)
		changed_ctime = replace(baseline, ctime_ns=6)
		with mock.patch.object(inputs.os, "name", "posix"):
			self.assertFalse(inputs._same_open_file_identity(baseline, changed_ctime))
		with mock.patch.object(inputs.os, "name", "nt"):
			self.assertTrue(inputs._same_open_file_identity(baseline, changed_ctime))

	@unittest.skipIf(os.name == "nt", "POSIX ctime is distinct from Windows creation time")
	def test_same_size_rewrite_after_read_with_restored_mtime_fails_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_input_root(Path(temporary_directory))
			target = root / "README.md"
			original_close = inputs.os.close
			rewritten = False

			def rewriting_close(file_descriptor: int) -> None:
				nonlocal rewritten
				if not rewritten:
					before = target.stat()
					target.write_text("# Hidden\n", encoding="utf-8", newline="\n")
					os.utime(target, ns=(before.st_atime_ns, before.st_mtime_ns))
					rewritten = True
				original_close(file_descriptor)

			spec = inputs.CheckInputSpec(
				"rewrite_source",
				(inputs.PathRule("exact", "README.md"),),
				("tools/checker.py",),
			)
			with mock.patch.object(inputs.os, "close", side_effect=rewriting_close):
				with self.assertRaises(inputs.ValidationInputDriftError):
					inputs.freeze_action_inputs(root, spec)

	def test_git_capture_revalidates_repository_ancestor_chain(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			temporary_root = Path(temporary_directory)
			workspace = temporary_root / "workspace"
			workspace.mkdir()
			root = _make_git_repository(workspace)
			moved_workspace = temporary_root / "workspace-before-replacement"
			original_run_git = inputs._run_git
			replaced = False

			def replacing_run_git(*args: object, **kwargs: object) -> bytes:
				nonlocal replaced
				output = original_run_git(*args, **kwargs)
				if not replaced:
					workspace.rename(moved_workspace)
					try:
						_create_directory_link(moved_workspace, workspace)
					except OSError as error:
						raise unittest.SkipTest(
							"directory-link fixtures are unavailable"
						) from error
					replaced = True
				return output

			try:
				with mock.patch.object(inputs, "_run_git", side_effect=replacing_run_git):
					with self.assertRaises(inputs.ValidationInputDriftError):
						inputs.changed_paths_since(
							root,
							git_process=_frozen_git_process(root),
						)
			finally:
				if moved_workspace.exists() and os.path.lexists(workspace):
					_remove_directory_link(workspace)
				if moved_workspace.exists():
					moved_workspace.rename(workspace)

	def test_tree_enumeration_checks_deadline_before_accumulating_all_entries(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_input_root(Path(temporary_directory))
			observed_entries = 0
			original_scandir = inputs.os.scandir

			class TrackedIterator:
				def __init__(self, iterator: object) -> None:
					self.iterator = iterator

				def __enter__(self) -> TrackedIterator:
					self.iterator.__enter__()  # type: ignore[attr-defined]
					return self

				def __exit__(self, *args: object) -> object:
					return self.iterator.__exit__(*args)  # type: ignore[attr-defined]

				def __iter__(self) -> TrackedIterator:
					return self

				def __next__(self) -> object:
					nonlocal observed_entries
					entry = next(self.iterator)  # type: ignore[arg-type]
					observed_entries += 1
					return entry

			def tracked_scandir(path: object) -> TrackedIterator:
				return TrackedIterator(original_scandir(path))

			def monotonic() -> float:
				return 2.0 if observed_entries >= 1 else 0.0

			with mock.patch.object(inputs.os, "scandir", side_effect=tracked_scandir):
				with self.assertRaises(inputs.ValidationInputDeadlineError):
					inputs.freeze_action_inputs(
						root,
						_input_spec(),
						deadline_seconds=1.0,
						monotonic=monotonic,
					)
			self.assertEqual(observed_entries, 1)

	def test_frozen_schema_rejects_invalid_digest_and_completeness_relationship(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_input_root(Path(temporary_directory))
			payload = inputs.freeze_action_inputs(root, _input_spec()).to_dict()
			invalid_digest = dict(payload)
			invalid_digest["source_manifest_digest"] = "not-a-digest"
			with self.assertRaises(inputs.ValidationInputContractError):
				inputs.FrozenActionInputs.from_dict(invalid_digest)
			invalid_complete = dict(payload)
			invalid_complete["capture_complete"] = False
			with self.assertRaises(inputs.ValidationInputContractError):
				inputs.FrozenActionInputs.from_dict(invalid_complete)


class AffectedGitAuthorityTests(unittest.TestCase):
	def test_affected_analysis_requires_explicit_input_specs(self) -> None:
		parameter = inspect.signature(
			inputs.analyze_affected_checks
		).parameters["input_specs"]

		self.assertIs(parameter.kind, inspect.Parameter.KEYWORD_ONLY)
		self.assertIs(parameter.default, inspect.Parameter.empty)

	def test_public_git_readers_require_explicit_authority(self) -> None:
		with self.assertRaises(TypeError):
			inputs.changed_paths_since(ROOT)  # type: ignore[call-arg]
		with self.assertRaises(TypeError):
			inputs.analyze_affected_checks(  # type: ignore[call-arg]
				ROOT,
				["public_docs_boundary"],
				input_specs=(),
			)

	def test_git_dispatch_uses_absolute_identity_and_frozen_environment(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory).resolve()
			frozen_values = dict(os.environ)
			frozen_values["GF_VALIDATION_INPUTS_AUTHORITY"] = "frozen"
			git_process = freeze_git_process(
				FrozenProcessEnvironment.capture(frozen_values),
				cwd=root,
			)
			completed = SupervisedBinaryProcessResult(
				return_code=0,
				stdout=b"fixture\0",
				stderr=b"",
				timed_out=False,
				duration_seconds=0.01,
				pid=123,
				cleanup_complete=True,
			)
			with (
				mock.patch.dict(
					os.environ,
					{
						"PATH": os.fspath(root / "ambient-path"),
						"GF_VALIDATION_INPUTS_AUTHORITY": "ambient",
					},
					clear=True,
				),
				mock.patch.object(
					inputs,
					"run_supervised_process_bytes",
					return_value=completed,
				) as supervised,
				mock.patch.object(
					inputs,
					"require_supervised_binary_quiet_boundary",
					wraps=inputs.require_supervised_binary_quiet_boundary,
				) as quiet_boundary,
			):
				output = inputs._run_git(
					root,
					["status", "--porcelain=v1", "-z"],
					git_process=git_process,
					limits=inputs.DEFAULT_INPUT_CAPTURE_LIMITS,
					deadline=inputs._Deadline(None, lambda: 0.0),
				)

		self.assertEqual(output, b"fixture\0")
		command = supervised.call_args.args[0]
		self.assertEqual(
			command,
			list(git_process.command(["status", "--porcelain=v1", "-z"]).effective),
		)
		self.assertTrue(Path(command[0]).is_absolute())
		dispatched_environment = supervised.call_args.kwargs["environment"]
		self.assertEqual(dispatched_environment, git_process.environment.values())
		self.assertEqual(
			dispatched_environment["GF_VALIDATION_INPUTS_AUTHORITY"],
			"frozen",
		)
		self.assertEqual(supervised.call_args.kwargs["cwd"], root)
		self.assertEqual(
			supervised.call_args.kwargs["deadline"],
			quiet_boundary.call_args.kwargs["deadline"],
		)
		self.assertEqual(
			supervised.call_args.kwargs["max_stdout_bytes"],
			inputs.DEFAULT_INPUT_CAPTURE_LIMITS.max_git_output_bytes + 1,
		)

	def test_git_dispatch_rejects_unproved_process_boundary(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory).resolve()
			git_process = _frozen_git_process(root)
			completed = SupervisedBinaryProcessResult(
				return_code=0,
				stdout=b"",
				stderr=b"",
				timed_out=False,
				duration_seconds=0.01,
				pid=123,
				notes=("fixture cleanup note",),
				cleanup_complete=False,
			)
			with mock.patch.object(
				inputs,
				"run_supervised_process_bytes",
				return_value=completed,
			):
				with self.assertRaises(SupervisedProcessCleanupError) as raised:
					inputs._run_git(
						root,
						["status", "--porcelain=v1"],
						git_process=git_process,
						limits=inputs.DEFAULT_INPUT_CAPTURE_LIMITS,
						deadline=inputs._Deadline(None, lambda: 0.0),
					)
		self.assertTrue(raised.exception.cleanup_debt)
		self.assertFalse(raised.exception.process_boundary_quiescent)
		self.assertEqual(raised.exception.pid, 123)
		self.assertEqual(raised.exception.notes, ("fixture cleanup note",))

	def test_git_deadline_mapping_samples_supervisor_clock_before_remaining_budget(
		self,
	) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory).resolve()
			git_process = _frozen_git_process(root)
			completed = SupervisedBinaryProcessResult(
				return_code=0,
				stdout=b"fixture\0",
				stderr=b"",
				timed_out=False,
				duration_seconds=0.01,
				pid=123,
				cleanup_complete=True,
			)
			events: list[str] = []
			advisory_values = iter((100.0, 103.0, 106.0, 107.0))
			supervisor_values = iter((101.0, 104.0, 105.0))

			def advisory_clock() -> float:
				events.append("advisory")
				return next(advisory_values)

			def supervisor_clock() -> float:
				events.append("supervisor")
				return next(supervisor_values)

			with mock.patch.object(
				inputs.time,
				"perf_counter",
				side_effect=supervisor_clock,
			), mock.patch.object(
				inputs,
				"run_supervised_process_bytes",
				return_value=completed,
			) as supervised, mock.patch.object(
				inputs,
				"require_supervised_binary_quiet_boundary",
				wraps=inputs.require_supervised_binary_quiet_boundary,
			) as quiet_boundary:
				output = inputs._run_git(
					root,
					["status", "--porcelain=v1", "-z"],
					git_process=git_process,
					limits=inputs.DEFAULT_INPUT_CAPTURE_LIMITS,
					deadline=inputs._Deadline(110.0, advisory_clock),
				)

		self.assertEqual(output, b"fixture\0")
		self.assertEqual(
			events,
			[
				"advisory",
				"supervisor",
				"advisory",
				"supervisor",
				"supervisor",
				"advisory",
				"advisory",
			],
		)
		self.assertEqual(supervised.call_count, 1)
		self.assertEqual(quiet_boundary.call_count, 1)
		self.assertEqual(supervised.call_args.kwargs["timeout_seconds"], 7.0)
		self.assertEqual(supervised.call_args.kwargs["deadline"], 108.0)
		self.assertEqual(quiet_boundary.call_args.kwargs["deadline"], 108.0)

	def test_git_dispatch_preserves_cleanup_debt_exception_identity(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory).resolve()
			git_process = _frozen_git_process(root)
			debt = SupervisedProcessCleanupError(
				"fixture Git cleanup debt",
				pid=123,
				process_tree_empty=False,
			)
			with mock.patch.object(
				inputs,
				"run_supervised_process_bytes",
				side_effect=debt,
			):
				with self.assertRaises(SupervisedProcessCleanupError) as raised:
					inputs._run_git(
						root,
						["status", "--porcelain=v1"],
						git_process=git_process,
						limits=inputs.DEFAULT_INPUT_CAPTURE_LIMITS,
						deadline=inputs._Deadline(None, lambda: 0.0),
					)

		self.assertIs(raised.exception, debt)
		self.assertTrue(raised.exception.cleanup_debt)
		self.assertFalse(raised.exception.process_boundary_quiescent)

	def test_git_quiet_acceptance_reuses_absolute_deadline_and_rejects_late_result(
		self,
	) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory).resolve()
			git_process = _frozen_git_process(root)
			completed = SupervisedBinaryProcessResult(
				return_code=0,
				stdout=b"",
				stderr=b"",
				timed_out=False,
				duration_seconds=0.01,
				pid=123,
				cleanup_complete=True,
			)
			with mock.patch.object(
				inputs.time,
				"perf_counter",
				side_effect=(100.0, 131.0),
			), mock.patch.object(
				inputs,
				"run_supervised_process_bytes",
				return_value=completed,
			) as supervised, mock.patch.object(
				inputs,
				"require_supervised_binary_quiet_boundary",
				wraps=inputs.require_supervised_binary_quiet_boundary,
			) as quiet_boundary, self.assertRaises(
				inputs.ValidationInputDeadlineError
			):
				inputs._run_git(
					root,
					["status", "--porcelain=v1"],
					git_process=git_process,
					limits=inputs.DEFAULT_INPUT_CAPTURE_LIMITS,
					deadline=inputs._Deadline(None, lambda: 0.0),
				)

		self.assertEqual(
			supervised.call_args.kwargs["deadline"],
			quiet_boundary.call_args.kwargs["deadline"],
		)


class AffectedAnalysisTests(unittest.TestCase):
	def test_cleanup_debt_escapes_fallback_unchanged(self) -> None:
		debt = SupervisedProcessCleanupError(
			"fixture affected-analysis cleanup debt",
			pid=456,
			process_tree_empty=False,
		)
		with mock.patch.object(
			inputs,
			"changed_paths_since",
			side_effect=debt,
		):
			with self.assertRaises(SupervisedProcessCleanupError) as raised:
				inputs.analyze_affected_checks(
					ROOT,
					["public_docs_boundary"],
					git_process=_frozen_git_process(ROOT),
					input_specs=[_input_spec()],
				)

		self.assertIs(raised.exception, debt)
		self.assertTrue(raised.exception.cleanup_debt)
		self.assertFalse(raised.exception.process_boundary_quiescent)

	def test_default_catalog_change_affects_all_declared_candidates(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_default_catalog_git_repository(Path(temporary_directory))
			_write(root / "tools/gf_validation_catalog.py", "CATALOG_VERSION = 2\n")
			input_specs = _default_input_specs()
			check_names = [
				spec.check_name for spec in input_specs
			]

			report = inputs.analyze_affected_checks(
				root,
				check_names,
				"HEAD",
				True,
				git_process=_frozen_git_process(root),
				input_specs=input_specs,
			)

		self.assertTrue(report["report_ok"])
		self.assertEqual(report["affected_count"], 3)
		self.assertEqual(report["unknown_count"], 0)
		for check in report["checks"]:
			self.assertEqual(
				check["reason_codes"],
				["implementation_input_changed"],
			)
			self.assertEqual(
				check["matched_paths"],
				["tools/gf_validation_catalog.py"],
			)

	def test_default_catalog_shared_snapshot_change_affects_all_three_candidates(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_default_catalog_git_repository(Path(temporary_directory))
			_write(root / "tools/gf_workspace_snapshot.py", "SNAPSHOT_VERSION = 2\n")
			input_specs = _default_input_specs()
			check_names = [
				spec.check_name for spec in input_specs
			]

			report = inputs.analyze_affected_checks(
				root,
				check_names,
				"HEAD",
				True,
				git_process=_frozen_git_process(root),
				input_specs=input_specs,
			)

			self.assertTrue(report["report_ok"])
			self.assertEqual(report["affected_count"], 3)
			self.assertEqual(report["unknown_count"], 0)
			for check in report["checks"]:
				self.assertEqual(
					check["reason_codes"],
					["implementation_input_changed"],
				)
				self.assertEqual(
					check["matched_paths"],
					["tools/gf_workspace_snapshot.py"],
				)

	def test_default_catalog_parser_change_affects_only_public_api_candidate(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_default_catalog_git_repository(Path(temporary_directory))
			_write(root / "tools/gdscript_api_parser.py", "PARSER_VERSION = 2\n")
			input_specs = _default_input_specs()
			check_names = [
				spec.check_name for spec in input_specs
			]

			report = inputs.analyze_affected_checks(
				root,
				check_names,
				"HEAD",
				True,
				git_process=_frozen_git_process(root),
				input_specs=input_specs,
			)

			self.assertTrue(report["report_ok"])
			self.assertEqual(report["affected_count"], 1)
			self.assertEqual(report["unaffected_count"], 2)
			by_name = {check["check_name"]: check for check in report["checks"]}
			self.assertEqual(
				by_name["public_api_boundary"]["reason_codes"],
				["implementation_input_changed"],
			)
			self.assertEqual(
				by_name["public_api_boundary"]["matched_paths"],
				["tools/gdscript_api_parser.py"],
			)
			for check_name in (
				"package_user_dependency_boundary",
				"public_docs_boundary",
			):
				self.assertEqual(
					by_name[check_name]["reason_codes"],
					["no_declared_input_changed"],
				)

	def test_default_catalog_owner_model_change_affects_only_public_api_candidate(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_default_catalog_git_repository(Path(temporary_directory))
			_write(root / "tools/gf_api_owners.py", "OWNER_VERSION = 2\n")
			input_specs = _default_input_specs()
			check_names = [
				spec.check_name for spec in input_specs
			]

			report = inputs.analyze_affected_checks(
				root,
				check_names,
				"HEAD",
				True,
				git_process=_frozen_git_process(root),
				input_specs=input_specs,
			)

			self.assertTrue(report["report_ok"])
			self.assertEqual(report["affected_count"], 1)
			self.assertEqual(report["unaffected_count"], 2)
			by_name = {check["check_name"]: check for check in report["checks"]}
			self.assertEqual(
				by_name["public_api_boundary"]["reason_codes"],
				["implementation_input_changed"],
			)
			self.assertEqual(
				by_name["public_api_boundary"]["matched_paths"],
				["tools/gf_api_owners.py"],
			)
			for check_name in (
				"package_user_dependency_boundary",
				"public_docs_boundary",
			):
				self.assertEqual(
					by_name[check_name]["reason_codes"],
					["no_declared_input_changed"],
				)

	def test_changed_source_is_affected_but_every_counter_stays_execute_only(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_git_repository(Path(temporary_directory))
			_write(root / "docs/guide.md", "Changed\n")

			report = inputs.analyze_affected_checks(
				root,
				["public_docs_boundary"],
				"HEAD",
				True,
				git_process=_frozen_git_process(root),
				input_specs=[_input_spec()],
			)

			self.assertTrue(report["report_ok"])
			self.assertTrue(report["capture_complete"])
			self.assertFalse(report["authoritative"])
			self.assertFalse(report["scheduling_effect"])
			self.assertEqual(report["affected_count"], 1)
			self.assertEqual(report["execute_count"], 1)
			for counter in (
				"affected_skip_count",
				"cache_read_count",
				"cache_write_count",
				"reused_count",
			):
				self.assertEqual(report[counter], 0)
			check = report["checks"][0]
			self.assertEqual(check["classification"], "affected")
			self.assertEqual(check["decision"], "execute")
			self.assertEqual(check["reason_codes"], ["source_input_changed"])
			self.assertEqual(check["matched_paths"], ["docs/guide.md"])
			self.assertIsNotNone(check["frozen_inputs"])

	def test_explain_changes_visibility_not_classification_or_count(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_git_repository(Path(temporary_directory))
			_write(root / "README.md", "Changed\n")
			report = inputs.analyze_affected_checks(
				root,
				["public_docs_boundary"],
				git_process=_frozen_git_process(root),
				input_specs=[_input_spec()],
			)
			check = report["checks"][0]
			self.assertEqual(check["classification"], "affected")
			self.assertEqual(check["matched_path_count"], 1)
			self.assertEqual(check["matched_paths"], [])

	def test_unrelated_change_is_unaffected_and_undeclared_is_unknown(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_git_repository(Path(temporary_directory))
			_write(root / "unrelated.txt", "Changed unrelated\n")
			report = inputs.analyze_affected_checks(
				root,
				["public_docs_boundary", "gut"],
				git_process=_frozen_git_process(root),
				input_specs=[_input_spec()],
			)
			self.assertTrue(report["report_ok"])
			self.assertEqual(report["unaffected_count"], 1)
			self.assertEqual(report["unknown_count"], 1)
			self.assertEqual(
				report["checks"][0]["reason_codes"],
				["no_declared_input_changed"],
			)
			self.assertEqual(
				report["checks"][1]["reason_codes"],
				["input_spec_undeclared"],
			)
			self.assertTrue(all(
				check["decision"] == "execute" for check in report["checks"]
			))

	def test_implementation_change_has_explicit_reason(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_git_repository(Path(temporary_directory))
			_write(root / "tools/checker.py", "RULE_VERSION = 2\n")
			report = inputs.analyze_affected_checks(
				root,
				["public_docs_boundary"],
				git_process=_frozen_git_process(root),
				input_specs=[_input_spec()],
			)
			self.assertEqual(
				report["checks"][0]["reason_codes"],
				["implementation_input_changed"],
			)

	def test_delete_rename_and_ignored_untracked_inputs_are_conservative(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_git_repository(Path(temporary_directory))
			(root / "README.md").unlink()
			(root / "docs/guide.md").rename(root / "docs/renamed.md")
			_write(root / "docs/ignored.md", "Ignored but scanned\n")

			changed = inputs.changed_paths_since(
				root,
				git_process=_frozen_git_process(root),
				pathspecs=("README.md", "docs"),
			)
			self.assertIn("README.md", changed.paths)
			self.assertIn("docs/guide.md", changed.paths)
			self.assertIn("docs/renamed.md", changed.paths)
			self.assertIn("docs/ignored.md", changed.paths)
			report = inputs.analyze_affected_checks(
				root,
				["public_docs_boundary"],
				"HEAD",
				True,
				git_process=_frozen_git_process(root),
				input_specs=[_input_spec()],
			)
			self.assertEqual(report["affected_count"], 1)
			self.assertGreaterEqual(report["checks"][0]["matched_path_count"], 4)

	def test_invalid_base_and_expired_deadline_return_exact_unknown_execute_fallback(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_git_repository(Path(temporary_directory))
			for kwargs, error_code in (
				({"base_revision": "missing-revision"}, "affected_base_invalid"),
				({"deadline_seconds": 0.0}, "affected_deadline_exceeded"),
			):
				with self.subTest(error_code=error_code):
					report = inputs.analyze_affected_checks(
						root,
						["public_docs_boundary"],
						git_process=_frozen_git_process(root),
						input_specs=[_input_spec()],
						**kwargs,
					)
					self.assertEqual(set(report), inputs.AFFECTED_ANALYSIS_REPORT_FIELDS)
					self.assertFalse(report["report_ok"])
					self.assertFalse(report["capture_complete"])
					self.assertEqual(report["errors"], [error_code])
					self.assertEqual(report["unknown_count"], 1)
					self.assertEqual(report["execute_count"], 1)
					self.assertEqual(report["checks"][0]["decision"], "execute")

	def test_failure_builder_bounds_error_codes_and_report_validator_rejects_drift(self) -> None:
		report = inputs.make_affected_analysis_failure(
			["api", "gut"],
			"HEAD",
			"raw exception: secret absolute path",
			explain=True,
		)
		self.assertEqual(report["errors"], ["affected_internal_error"])
		self.assertNotIn("secret", json.dumps(report))
		self.assertEqual(report["unknown_count"], 2)
		self.assertEqual(report["execute_count"], 2)
		self.assertTrue(all(
			set(check) == inputs.AFFECTED_CHECK_FIELDS
			for check in report["checks"]
		))

		for mutation in (
			lambda value: value.update({"affected_skip_count": 1}),
			lambda value: value.update({"scheduling_effect": True}),
			lambda value: value.update({"unknown_count": 0}),
			lambda value: value.update({"unexpected": True}),
		):
			with self.subTest(mutation=mutation):
				mutated = dict(report)
				mutation(mutated)
				with self.assertRaises(inputs.ValidationInputContractError):
					inputs.validate_affected_analysis_report(mutated)

	def test_schema_v1_rejects_contradictory_check_and_report_relationships(self) -> None:
		def assert_invalid(report: dict[str, object], label: str) -> None:
			with self.subTest(label=label):
				with self.assertRaises(inputs.ValidationInputContractError):
					inputs.validate_affected_analysis_report(report)

		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _make_git_repository(Path(temporary_directory))
			baseline = inputs.analyze_affected_checks(
				root,
				["public_docs_boundary", "gut"],
				"HEAD",
				True,
				git_process=_frozen_git_process(root),
				input_specs=[_input_spec()],
			)
			self.assertTrue(baseline["report_ok"])
			unaffected = baseline["checks"][0]
			unknown = baseline["checks"][1]
			self.assertEqual(unaffected["classification"], "unaffected")
			self.assertEqual(unknown["classification"], "unknown")

			mutated = copy.deepcopy(baseline)
			mutated["checks"][0]["reason_codes"] = ["source_input_changed"]
			assert_invalid(mutated, "unaffected reason must be exact")

			mutated = copy.deepcopy(baseline)
			mutated["checks"][0]["matched_path_count"] = 1
			mutated["checks"][0]["matched_paths"] = ["README.md"]
			assert_invalid(mutated, "unaffected cannot expose matches")

			mutated = copy.deepcopy(baseline)
			mutated["checks"][0]["input_spec_declared"] = False
			mutated["checks"][0]["frozen_inputs"] = None
			assert_invalid(mutated, "unaffected must be declared and frozen")

			mutated = copy.deepcopy(baseline)
			mutated["checks"][1]["reason_codes"] = ["analysis_failed"]
			assert_invalid(mutated, "success unknown reason must be undeclared")

			mutated = copy.deepcopy(baseline)
			mutated["checks"][1]["input_spec_declared"] = True
			mutated["checks"][1]["frozen_inputs"] = copy.deepcopy(
				unaffected["frozen_inputs"]
			)
			mutated["checks"][1]["frozen_inputs"]["check_name"] = "gut"
			assert_invalid(mutated, "unknown cannot be declared or frozen")

			mutated = copy.deepcopy(baseline)
			mutated["checks"][1]["matched_path_count"] = 1
			mutated["checks"][1]["matched_paths"] = ["README.md"]
			assert_invalid(mutated, "unknown cannot expose matches")

			_write(root / "README.md", "Changed\n")
			affected = inputs.analyze_affected_checks(
				root,
				["public_docs_boundary"],
				"HEAD",
				True,
				git_process=_frozen_git_process(root),
				input_specs=[_input_spec()],
			)
			self.assertEqual(affected["checks"][0]["classification"], "affected")

			mutated = copy.deepcopy(affected)
			mutated["explain"] = False
			assert_invalid(mutated, "explain false hides every matched path")

			mutated = copy.deepcopy(affected)
			mutated["checks"][0]["matched_paths"] = []
			assert_invalid(mutated, "explained affected requires a visible match")

			mutated = copy.deepcopy(affected)
			mutated["checks"][0]["matched_path_count"] = 0
			mutated["checks"][0]["matched_paths"] = []
			assert_invalid(mutated, "affected requires a positive match count")

			mutated = copy.deepcopy(affected)
			mutated["checks"][0]["reason_codes"] = [
				"no_declared_input_changed"
			]
			assert_invalid(mutated, "affected reason must be source or implementation")

			mutated = copy.deepcopy(affected)
			mutated["checks"][0]["input_spec_declared"] = False
			mutated["checks"][0]["frozen_inputs"] = None
			assert_invalid(mutated, "affected must be declared and frozen")

		failure = inputs.make_affected_analysis_failure(
			["public_docs_boundary"],
			"HEAD",
			"affected_internal_error",
			explain=True,
		)
		mutated = copy.deepcopy(failure)
		mutated["checks"][0]["reason_codes"] = ["input_spec_undeclared"]
		assert_invalid(mutated, "failure reason must be analysis failed")

		mutated = copy.deepcopy(failure)
		mutated["checks"][0]["matched_path_count"] = 1
		mutated["checks"][0]["matched_paths"] = ["README.md"]
		assert_invalid(mutated, "failure cannot expose matches")

	def test_module_has_no_skip_cache_or_persistence_surface(self) -> None:
		for name in (
			"should_skip",
			"skip_checks",
			"load_evidence",
			"save_evidence",
			"read_cache",
			"write_cache",
			"persist",
		):
			self.assertFalse(hasattr(inputs, name))


if __name__ == "__main__":
	unittest.main()
