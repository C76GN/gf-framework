#!/usr/bin/env python3
"""Focused tests for bounded, read-only GF test inventory evidence."""

from __future__ import annotations

import hashlib
import json
import os
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

import gf_validation_test_inventory as inventory


def _make_repository(parent: Path) -> Path:
	repository = parent / "repository"
	(repository / "tests" / "gf_core").mkdir(parents=True)
	return repository


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


class TestInventoryTests(unittest.TestCase):
	def test_inventory_is_stable_sorted_and_ignores_comment_and_string_decoys(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = _make_repository(Path(temporary_directory))
			gdscript_path = repository / "tests/gf_core/zeta/test_zeta.gd"
			gdscript_path.parent.mkdir()
			gdscript_source = (
				'extends GutTest\n\n'
				'# func test_comment_decoy() -> void:\n'
				'var decoy := "func test_string_decoy()"\n'
				'var multiline := """\nfunc test_multiline_decoy() -> void:\n"""\n'
				'func test_zulu() -> void:\n\tpass_test("zulu")\n\n'
				'func test_alpha() -> void:\n\tpass_test("alpha")\n'
			)
			gdscript_path.write_text(gdscript_source, encoding="utf-8", newline="\n")
			python_path = repository / "tests/gf_core/alpha/test_alpha.py"
			python_path.parent.mkdir()
			python_source = (
				'import unittest\n\n'
				'class ZetaTests(unittest.TestCase):\n'
				'\tdef test_beta(self) -> None:\n\t\tpass\n\n'
				'\tasync def test_alpha(self) -> None:\n\t\tpass\n\n'
				'\tdef helper(self) -> None:\n'
				'\t\tdef test_nested_decoy() -> None:\n\t\t\tpass\n'
			)
			python_path.write_text(python_source, encoding="utf-8", newline="\n")
			(repository / "tests/gf_core/alpha/support.gd").write_text(
				"extends RefCounted\n",
				encoding="utf-8",
				newline="\n",
			)

			first = inventory.collect_test_inventory(repository)
			second = inventory.collect_test_inventory(repository)

			self.assertEqual(first, second)
			self.assertTrue(first["capture_complete"])
			self.assertNotIn("input_complete", first)
			self.assertEqual(first["discovery_contract_version"], 2)
			self.assertEqual(first["root"], "tests/gf_core")
			self.assertEqual(first["entry_count"], 5)
			self.assertEqual(first["file_count"], 3)
			self.assertEqual(first["method_count"], 4)
			self.assertEqual(
				first["source_bytes"],
				len(gdscript_source.encode("utf-8"))
				+ len(python_source.encode("utf-8"))
				+ len("extends RefCounted\n".encode("utf-8")),
			)
			self.assertEqual(
				[record["path"] for record in first["files"]],
				[
					"tests/gf_core/alpha/support.gd",
					"tests/gf_core/alpha/test_alpha.py",
					"tests/gf_core/zeta/test_zeta.gd",
				],
			)
			python_record = first["files"][1]
			self.assertEqual(
				python_record["tests"],
				["ZetaTests.test_alpha", "ZetaTests.test_beta"],
			)
			gdscript_record = first["files"][2]
			self.assertEqual(gdscript_record["tests"], ["test_alpha", "test_zulu"])
			self.assertEqual(
				gdscript_record["content_sha256"],
				hashlib.sha256(gdscript_source.encode("utf-8")).hexdigest(),
			)
			serialized = json.dumps(first, ensure_ascii=False, sort_keys=True)
			self.assertNotIn(str(repository), serialized)

	def test_valid_gdscript_escape_raw_and_multiline_shapes_are_captured(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = _make_repository(Path(temporary_directory))
			source = repository / "tests/gf_core/test_strings.gd"
			gdscript_source = (
				'var normal := "line\\nquote: \\" unicode: \\u0041 \\U01F642"\n'
				"var single := 'it\\'s'\n"
				'var raw := r"\\q is literal"\n'
				'var triple := """two "" quotes\nstill inside"""\n'
				'var continued := "left\\\nright"\n'
				"func test_after_strings() -> void:\n\tpass\n"
			)
			source.write_text(gdscript_source, encoding="utf-8", newline="\n")

			result = inventory.collect_test_inventory(repository)

			self.assertTrue(result["capture_complete"])
			self.assertEqual(result["method_count"], 1)
			self.assertEqual(result["files"][0]["tests"], ["test_after_strings"])

	def test_malformed_gdscript_lexer_shapes_fail_closed(self) -> None:
		malformed_sources = (
			('var value := "unterminated', "gdscript_unterminated_string"),
			("var value := 'unterminated", "gdscript_unterminated_string"),
			('var value := """unterminated', "gdscript_unterminated_string"),
			("var value := '''unterminated", "gdscript_unterminated_string"),
			('var value := "dangling' + "\\", "gdscript_dangling_escape"),
			('var value := "bad\\q"\n', "gdscript_invalid_escape"),
			('var value := "bad\\u12"\n', "gdscript_invalid_escape"),
			('var value := "bad\\U12345z"\n', "gdscript_invalid_escape"),
			('var value := "line\nnext"\n', "gdscript_unescaped_newline"),
			('var value := """bad\\q"""\n', "gdscript_invalid_escape"),
			("var value := 1\0\n", "gdscript_invalid_control_character"),
		)
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = _make_repository(Path(temporary_directory))
			source = repository / "tests/gf_core/test_malformed.gd"
			for gdscript_source, rule_id in malformed_sources:
				with self.subTest(rule_id=rule_id, source=gdscript_source[:20]):
					source.write_text(gdscript_source, encoding="utf-8", newline="\n")
					with self.assertRaisesRegex(
						inventory.TestInventoryInputError,
						rule_id,
					):
						inventory.collect_test_inventory(repository)

	def test_advisory_deadline_is_checked_after_each_source_read(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = _make_repository(Path(temporary_directory))
			(repository / "tests/gf_core/test_deadline.gd").write_text(
				"func test_deadline() -> void:\n\tpass\n",
				encoding="utf-8",
			)
			read_count = 0
			original_read = inventory.os.read

			def tracked_read(file_descriptor: int, size: int) -> bytes:
				nonlocal read_count
				data = original_read(file_descriptor, size)
				read_count += 1
				return data

			def monotonic() -> float:
				return 2.0 if read_count else 0.0

			with mock.patch.object(inventory.os, "read", side_effect=tracked_read):
				with self.assertRaisesRegex(
					inventory.TestInventoryDeadlineError,
					"advisory_deadline_exceeded",
				):
					inventory.collect_test_inventory(
						repository,
						deadline_seconds=1.0,
						monotonic=monotonic,
					)
			self.assertGreaterEqual(read_count, 1)

	def test_open_file_identity_drift_fails_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = _make_repository(Path(temporary_directory))
			source = repository / "tests/gf_core/test_drift.gd"
			source.write_text(
				"func test_drift() -> void:\n\tpass\n",
				encoding="utf-8",
			)
			before = inventory._snapshot_path(
				source,
				"tests/gf_core/test_drift.gd",
				expect_directory=False,
			)
			original_snapshot = inventory._snapshot_from_stat
			observation_count = 0

			def drifting_snapshot(value: os.stat_result) -> object:
				nonlocal observation_count
				observed = original_snapshot(value)
				observation_count += 1
				if observation_count == 2:
					return replace(observed, mtime_ns=observed.mtime_ns + 1)
				return observed

			with mock.patch.object(
				inventory,
				"_snapshot_from_stat",
				side_effect=drifting_snapshot,
			):
				with self.assertRaisesRegex(
					inventory.TestInventoryDriftError,
					"source_changed_while_reading",
				):
					inventory._read_stable_source(
						source,
						"tests/gf_core/test_drift.gd",
						before,
						limits=inventory.DEFAULT_LIMITS,
						state=inventory._BudgetState(),
						deadline=inventory._AdvisoryDeadline(None, lambda: 0.0),
					)

	def test_open_file_change_time_drift_fails_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = _make_repository(Path(temporary_directory))
			source = repository / "tests/gf_core/test_ctime_drift.gd"
			source.write_text(
				"func test_drift() -> void:\n\tpass\n",
				encoding="utf-8",
			)
			before = inventory._snapshot_path(
				source,
				"tests/gf_core/test_ctime_drift.gd",
				expect_directory=False,
			)
			original_snapshot = inventory._snapshot_open_file
			observation_count = 0

			def drifting_snapshot(file_descriptor: int) -> object:
				nonlocal observation_count
				observed = original_snapshot(file_descriptor)
				observation_count += 1
				if observation_count == 2:
					return replace(
						observed,
						change_time_ns=(observed.change_time_ns or 0) + 1,
					)
				return observed

			with mock.patch.object(
				inventory,
				"_snapshot_open_file",
				side_effect=drifting_snapshot,
			):
				with self.assertRaisesRegex(
					inventory.TestInventoryDriftError,
					"source_changed_while_reading",
				):
					inventory._read_stable_source(
						source,
						"tests/gf_core/test_ctime_drift.gd",
						before,
						limits=inventory.DEFAULT_LIMITS,
						state=inventory._BudgetState(),
						deadline=inventory._AdvisoryDeadline(None, lambda: 0.0),
					)

	def test_same_size_source_rewrite_with_restored_mtime_fails_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = _make_repository(Path(temporary_directory))
			source = repository / "tests/gf_core/test_rewrite.gd"
			source.write_text(
				"func test_one() -> void:\n\tpass\n",
				encoding="utf-8",
			)
			original_walk = inventory._walk_test_tree
			rewritten = False

			def rewrite_after_capture(*args: object, **kwargs: object) -> None:
				nonlocal rewritten
				original_walk(*args, **kwargs)
				directory = args[0] if args else kwargs["directory"]
				if directory == repository / "tests/gf_core" and not rewritten:
					before = source.stat()
					source.write_text(
						"func test_two() -> void:\n\tpass\n",
						encoding="utf-8",
					)
					os.utime(source, ns=(before.st_atime_ns, before.st_mtime_ns))
					rewritten = True

			with mock.patch.object(
				inventory,
				"_walk_test_tree",
				side_effect=rewrite_after_capture,
			):
				with self.assertRaisesRegex(
					inventory.TestInventoryDriftError,
					"source_changed",
				):
					inventory.collect_test_inventory(repository)

	def test_fixed_test_root_ancestor_replacement_fails_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = _make_repository(Path(temporary_directory))
			(repository / "tests/gf_core/test_value.gd").write_text(
				"func test_value() -> void:\n\tpass\n",
				encoding="utf-8",
			)
			tests_root = repository / "tests"
			moved_tests_root = repository / "tests-before-replacement"
			original_walk = inventory._walk_test_tree
			replaced = False

			def replace_ancestor_after_walk(*args: object, **kwargs: object) -> None:
				nonlocal replaced
				original_walk(*args, **kwargs)
				directory = args[0] if args else kwargs["directory"]
				if directory == repository / "tests/gf_core" and not replaced:
					tests_root.rename(moved_tests_root)
					_create_directory_link(moved_tests_root, tests_root)
					replaced = True

			try:
				with mock.patch.object(
					inventory,
					"_walk_test_tree",
					side_effect=replace_ancestor_after_walk,
				):
					with self.assertRaisesRegex(
						inventory.TestInventoryDriftError,
						"path_changed",
					):
						inventory.collect_test_inventory(repository)
			finally:
				if replaced:
					_remove_directory_link(tests_root)
					moved_tests_root.rename(tests_root)

	def test_repository_parent_replacement_fails_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			container = Path(temporary_directory)
			workspace = container / "workspace"
			workspace.mkdir()
			repository = _make_repository(workspace)
			(repository / "tests/gf_core/test_value.gd").write_text(
				"func test_value() -> void:\n\tpass\n",
				encoding="utf-8",
			)
			moved_workspace = container / "workspace-before-replacement"
			original_walk = inventory._walk_test_tree
			replaced = False

			def replace_parent_after_walk(*args: object, **kwargs: object) -> None:
				nonlocal replaced
				original_walk(*args, **kwargs)
				directory = args[0] if args else kwargs["directory"]
				if directory == repository / "tests/gf_core" and not replaced:
					workspace.rename(moved_workspace)
					_create_directory_link(moved_workspace, workspace)
					replaced = True

			try:
				with mock.patch.object(
					inventory,
					"_walk_test_tree",
					side_effect=replace_parent_after_walk,
				):
					with self.assertRaisesRegex(
						inventory.TestInventoryDriftError,
						"path_changed",
					):
						inventory.collect_test_inventory(repository)
			finally:
				if replaced:
					_remove_directory_link(workspace)
					moved_workspace.rename(workspace)

	def test_gdscript_inner_gut_test_methods_are_discovered(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = _make_repository(Path(temporary_directory))
			(repository / "tests/gf_core/test_inner.gd").write_text(
				"extends GutTest\n\n"
				"class SharedInnerBase:\n"
				"\textends GutTest\n"
				"\tfunc helper() -> void:\n"
				"\t\tpass\n\n"
				"class TestInner:\n"
				"\textends GutTest\n"
				"\tfunc test_value() -> void:\n"
				"\t\tpass_test(\"inner\")\n\n"
				"class TestDerived:\n"
				"\textends SharedInnerBase\n"
				"\tfunc test_value() -> void:\n"
				"\t\tpass_test(\"derived\")\n\n"
				"class TestPathBase:\n"
				"\textends \"res://addons/gut/test.gd\"\n"
				"\tfunc test_path() -> void:\n"
				"\t\tpass_test(\"path\")\n\n"
				"class TestInline extends GutTest:\n"
				"\tfunc test_inline() -> void:\n"
				"\t\tpass_test(\"inline\")\n\n"
				"class TestData:\n"
				"\textends RefCounted\n"
				"\tfunc test_not_collected() -> void:\n"
				"\t\tpass\n\n"
				"class HelperGutTest:\n"
				"\textends GutTest\n"
				"\tfunc test_not_collected() -> void:\n"
				"\t\tpass\n\n"
				"# class TestComment extends GutTest:\n"
				"# \tfunc test_comment_decoy() -> void:\n"
				"var decoy := \"class TestString extends GutTest: func test_string_decoy()\"\n",
				encoding="utf-8",
			)

			result = inventory.collect_test_inventory(repository)

			self.assertEqual(result["method_count"], 4)
			self.assertEqual(
				result["files"][0]["tests"],
				[
					"TestDerived.test_value",
					"TestInline.test_inline",
					"TestInner.test_value",
					"TestPathBase.test_path",
				],
			)

	def test_python_class_control_flow_methods_are_discovered(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = _make_repository(Path(temporary_directory))
			(repository / "tests/gf_core/test_conditional.py").write_text(
				"import unittest\n\n"
				"class ConditionalTests(unittest.TestCase):\n"
				"\tif True:\n"
				"\t\tdef test_if_branch(self) -> None:\n"
				"\t\t\tpass\n"
				"\ttry:\n"
				"\t\tdef test_try_body(self) -> None:\n"
				"\t\t\tpass\n"
				"\texcept RuntimeError:\n"
				"\t\tasync def test_except_body(self) -> None:\n"
				"\t\t\tpass\n"
				"\telse:\n"
				"\t\tdef test_else_body(self) -> None:\n"
				"\t\t\tpass\n"
				"\tfinally:\n"
				"\t\tdef test_finally_body(self) -> None:\n"
				"\t\t\tpass\n",
				encoding="utf-8",
			)

			result = inventory.collect_test_inventory(repository)

			self.assertEqual(
				result["files"][0]["tests"],
				[
					"ConditionalTests.test_else_body",
					"ConditionalTests.test_except_body",
					"ConditionalTests.test_finally_body",
					"ConditionalTests.test_if_branch",
					"ConditionalTests.test_try_body",
				],
			)

	def test_superscript_windows_device_names_are_rejected(self) -> None:
		for device_name in ("COM¹.gd", "com².py", "LPT³.gd", "lpt¹.txt"):
			with self.subTest(device_name=device_name):
				with self.assertRaisesRegex(
					inventory.TestInventoryInputError,
					"path_not_portable",
				):
					inventory._validate_path_segment(device_name)

	def test_unexpired_advisory_deadline_does_not_change_inventory_identity(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = _make_repository(Path(temporary_directory))
			(repository / "tests/gf_core/test_value.py").write_text(
				"def test_value():\n\tpass\n",
				encoding="utf-8",
			)
			baseline = inventory.collect_test_inventory(repository)
			with_deadline = inventory.collect_test_inventory(
				repository,
				deadline_seconds=1.0,
				monotonic=lambda: 0.0,
			)
			self.assertEqual(with_deadline, baseline)

	def test_discovery_contract_version_is_bound_to_inventory_identity(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = _make_repository(Path(temporary_directory))
			(repository / "tests/gf_core/test_value.py").write_text(
				"def test_value():\n\tpass\n",
				encoding="utf-8",
			)
			baseline = inventory.collect_test_inventory(repository)
			with mock.patch.object(
				inventory,
				"DISCOVERY_CONTRACT_VERSION",
				inventory.DISCOVERY_CONTRACT_VERSION + 1,
			):
				changed = inventory.collect_test_inventory(repository)
			self.assertNotEqual(
				changed["inventory_sha256"],
				baseline["inventory_sha256"],
			)

	def test_content_add_delete_and_rename_each_invalidate_inventory_digest(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = _make_repository(Path(temporary_directory))
			test_root = repository / "tests/gf_core"
			original = test_root / "test_original.gd"
			original_source = "func test_value() -> void:\n\tpass\n"
			original.write_text(original_source, encoding="utf-8", newline="\n")
			baseline = inventory.collect_test_inventory(repository)

			original.write_text(
				original_source + "# content-only change\n",
				encoding="utf-8",
				newline="\n",
			)
			content_changed = inventory.collect_test_inventory(repository)
			self.assertNotEqual(
				content_changed["source_manifest_sha256"],
				baseline["source_manifest_sha256"],
			)
			self.assertNotEqual(
				content_changed["inventory_sha256"],
				baseline["inventory_sha256"],
			)
			self.assertEqual(
				content_changed["test_list_sha256"],
				baseline["test_list_sha256"],
			)

			original.write_text(original_source, encoding="utf-8", newline="\n")
			added = test_root / "test_added.gd"
			added.write_text("func test_added() -> void:\n\tpass\n", encoding="utf-8")
			added_inventory = inventory.collect_test_inventory(repository)
			self.assertNotEqual(added_inventory["inventory_sha256"], baseline["inventory_sha256"])
			added.unlink()

			renamed = test_root / "test_renamed.gd"
			original.rename(renamed)
			renamed_inventory = inventory.collect_test_inventory(repository)
			self.assertNotEqual(
				renamed_inventory["source_manifest_sha256"],
				baseline["source_manifest_sha256"],
			)
			self.assertNotEqual(
				renamed_inventory["test_list_sha256"],
				baseline["test_list_sha256"],
			)

			renamed.unlink()
			deleted_inventory = inventory.collect_test_inventory(repository)
			self.assertNotEqual(
				deleted_inventory["inventory_sha256"],
				baseline["inventory_sha256"],
			)

	def test_invalid_utf8_bom_and_python_syntax_fail_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = _make_repository(Path(temporary_directory))
			source = repository / "tests/gf_core/test_source.py"
			for payload, rule_id in (
				(b"\xff\xfe", "source_not_utf8"),
				(b"\xef\xbb\xbfdef test_value():\n\tpass\n", "source_has_utf8_bom"),
				(b"def test_value(:\n\tpass\n", "python_parse_failed"),
			):
				with self.subTest(rule_id=rule_id):
					source.write_bytes(payload)
					with self.assertRaisesRegex(
						inventory.TestInventoryInputError,
						rule_id,
					):
						inventory.collect_test_inventory(repository)

	def test_size_path_entry_and_method_budgets_fail_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = _make_repository(Path(temporary_directory))
			test_root = repository / "tests/gf_core"
			(test_root / "test_budget.gd").write_text(
				"func test_one() -> void:\n\tpass\nfunc test_two() -> void:\n\tpass\n",
				encoding="utf-8",
			)
			(test_root / "README.md").write_text("fixture\n", encoding="utf-8")
			for limits, rule_id in (
				(
					replace(inventory.DEFAULT_LIMITS, max_source_file_bytes=8),
					"source_file_size_limit",
				),
				(
					replace(inventory.DEFAULT_LIMITS, max_path_bytes=10),
					"path_length_limit",
				),
				(
					replace(inventory.DEFAULT_LIMITS, max_entries=1),
					"entry_limit",
				),
				(
					replace(inventory.DEFAULT_LIMITS, max_test_methods=1),
					"test_method_limit",
				),
			):
				with self.subTest(rule_id=rule_id):
					with self.assertRaisesRegex(inventory.TestInventoryError, rule_id):
						inventory.collect_test_inventory(repository, limits=limits)

	def test_relative_root_and_directory_link_are_rejected(self) -> None:
		with self.assertRaisesRegex(
			inventory.TestInventoryInputError,
			"repository_root_not_absolute",
		):
			inventory.collect_test_inventory(Path("relative-repository"))

		with tempfile.TemporaryDirectory() as temporary_directory:
			temporary_root = Path(temporary_directory)
			repository = _make_repository(temporary_root)
			outside = temporary_root / "outside"
			outside.mkdir()
			(outside / "test_outside.gd").write_text(
				"func test_outside() -> void:\n\tpass\n",
				encoding="utf-8",
			)
			linked = repository / "tests/gf_core/linked"
			_create_directory_link(outside, linked)
			try:
				with self.assertRaisesRegex(
					inventory.TestInventoryInputError,
					"link_or_reparse_rejected",
				):
					inventory.collect_test_inventory(repository)
			finally:
				_remove_directory_link(linked)

	def test_portable_case_collision_is_rejected_when_filesystem_allows_it(self) -> None:
		if os.name == "nt":
			self.skipTest("Windows cannot create the portable case-collision fixture")
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = _make_repository(Path(temporary_directory))
			test_root = repository / "tests/gf_core"
			(test_root / "Test_Value.gd").write_text("func test_upper():\n\tpass\n")
			(test_root / "test_value.gd").write_text("func test_lower():\n\tpass\n")
			with self.assertRaisesRegex(
				inventory.TestInventoryInputError,
				"portable_path_collision",
			):
				inventory.collect_test_inventory(repository)

	def test_duplicate_test_ids_fail_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = _make_repository(Path(temporary_directory))
			(repository / "tests/gf_core/test_duplicate.gd").write_text(
				"func test_value():\n\tpass\nfunc test_value():\n\tpass\n",
				encoding="utf-8",
			)
			with self.assertRaisesRegex(
				inventory.TestInventoryInputError,
				"duplicate_test_id",
			):
				inventory.collect_test_inventory(repository)


if __name__ == "__main__":
	unittest.main()
