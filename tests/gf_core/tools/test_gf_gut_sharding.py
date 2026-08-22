#!/usr/bin/env python3
"""Focused tests for observational GUT inventory, sharding, and JUnit data."""

from __future__ import annotations

import copy
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
TOOLS_ROOT = ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
	sys.path.insert(0, str(TOOLS_ROOT))

import gf_gut_sharding as gut_sharding  # noqa: E402
import gf_maintenance as maintenance  # noqa: E402


class GutInventoryTests(unittest.TestCase):
	def test_inventory_deadline_preserves_windows_io_headroom(self) -> None:
		self.assertEqual(gut_sharding.INVENTORY_DEADLINE_SECONDS, 30.0)

	def test_inventory_stability_scans_receive_independent_bounded_deadlines(self) -> None:
		clock = [100.0]
		deadlines: list[float] = []
		inventory = {"res://tests/gf_core/kernel/test_example.gd"}
		def scan(_root: Path, deadline: float) -> set[str]:
			deadlines.append(deadline)
			clock[0] += 25.0
			return inventory

		with (
			mock.patch.object(
				gut_sharding.time,
				"monotonic",
				side_effect=lambda: clock[0],
			),
			mock.patch.object(
				gut_sharding,
				"_scan_test_inventory",
				side_effect=scan,
			),
		):
			actual = gut_sharding.discover_gut_test_scripts(Path("repository"))
		self.assertEqual(actual, tuple(inventory))
		self.assertEqual(deadlines, [130.0, 155.0])

		clock[0] = 100.0
		deadlines.clear()
		with (
			mock.patch.object(
				gut_sharding.time,
				"monotonic",
				side_effect=lambda: clock[0],
			),
			mock.patch.object(
				gut_sharding,
				"_scan_test_inventory",
				side_effect=scan,
			),
		):
			gut_sharding.discover_gut_test_scripts(
				Path("repository"),
				deadline=140.0,
			)
		self.assertEqual(deadlines, [130.0, 140.0])

	def test_repository_inventory_and_manifest_cover_live_scripts_once(self) -> None:
		inventory = gut_sharding.discover_gut_test_scripts(ROOT)
		manifest = gut_sharding.load_and_validate_manifest(
			ROOT / gut_sharding.MANIFEST_RELATIVE_PATH,
			root=ROOT,
			expected_inventory=inventory,
		)

		self.assertEqual(manifest["script_count"], len(inventory))
		assigned = [
			script
			for shard in manifest["shards"]
			for script in shard["scripts"]
		]
		self.assertEqual(len(assigned), len(set(assigned)))
		self.assertEqual(set(assigned), set(inventory))
		self.assertIn(gut_sharding.LIFECYCLE_CONTRACT_SCRIPT, inventory)

	def test_inventory_includes_runnable_fixture_and_support_tests(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			self._write_test(root, "kernel/test_real.gd")
			self._write_test(root, "fixtures/test_fixture.gd")
			self._write_test(root, "support/test_helper.gd")
			self._write_test(
				root,
				"support/test_gf_test_lifecycle_scope.gd",
			)
			self._write_test(root, "kernel/helper.gd")

			inventory = gut_sharding.discover_gut_test_scripts(root)

			self.assertEqual(
				inventory,
				(
					"res://tests/gf_core/fixtures/test_fixture.gd",
					"res://tests/gf_core/kernel/test_real.gd",
					gut_sharding.LIFECYCLE_CONTRACT_SCRIPT,
					"res://tests/gf_core/support/test_helper.gd",
				),
			)

	def test_inventory_requires_discovered_scripts_to_extend_gut_test(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			path = root / "tests/gf_core/kernel/test_invalid.gd"
			path.parent.mkdir(parents=True)
			path.write_text("extends Node\n", encoding="utf-8")

			with self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"inventory_test_contract_invalid",
			):
				gut_sharding.discover_gut_test_scripts(root)

	def test_inventory_does_not_accept_extends_text_inside_multiline_string(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			path = root / "tests/gf_core/kernel/test_invalid.gd"
			path.parent.mkdir(parents=True)
			path.write_text(
				'extends Node\nvar bait := """\nextends GutTest\n"""\n',
				encoding="utf-8",
			)

			with self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"inventory_test_contract_invalid",
			):
				gut_sharding.discover_gut_test_scripts(root)

	def test_inventory_does_not_end_multiline_string_at_escaped_quote(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			path = root / "tests/gf_core/kernel/test_invalid.gd"
			path.parent.mkdir(parents=True)
			path.write_text(
				'extends Node\nvar bait := """\n\\"""\nextends GutTest\n"""\n',
				encoding="utf-8",
			)

			with self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"inventory_test_contract_invalid",
			):
				gut_sharding.discover_gut_test_scripts(root)

	def test_inventory_rejects_inner_gut_test_classes_until_observation_maps_them(self) -> None:
		for source in (
			"extends GutTest\n\nclass TestNested extends GutTest:\n\tfunc test_nested() -> void:\n\t\tpass\n",
			"extends GutTest\n\nclass TestNested:\n\textends GutTest\n\tfunc test_nested() -> void:\n\t\tpass\n",
			"extends GutTest\n\nclass Base extends GutTest:\n\tpass\nclass TestNested extends Base:\n\tpass\n",
		):
			with self.subTest(source=source), tempfile.TemporaryDirectory() as temporary_directory:
				root = Path(temporary_directory)
				path = root / "tests/gf_core/kernel/test_inner.gd"
				path.parent.mkdir(parents=True)
				path.write_text(source, encoding="utf-8")

				with self.assertRaisesRegex(
					gut_sharding.GutShardingError,
					"inventory_inner_test_class_unsupported",
				):
					gut_sharding.discover_gut_test_scripts(root)

	def test_inventory_ignores_inner_class_text_inside_strings_and_comments(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			path = root / "tests/gf_core/kernel/test_no_inner.gd"
			path.parent.mkdir(parents=True)
			path.write_text(
				'extends GutTest\n# class TestComment extends GutTest\nvar text := "class TestString extends GutTest"\n',
				encoding="utf-8",
			)

			inventory = gut_sharding.discover_gut_test_scripts(root)

			self.assertEqual(
				inventory,
				("res://tests/gf_core/kernel/test_no_inner.gd",),
			)

	def test_inventory_ignores_helper_inner_classes_that_are_not_gut_tests(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			path = root / "tests/gf_core/kernel/test_helpers.gd"
			path.parent.mkdir(parents=True)
			path.write_text(
				"extends GutTest\n\nclass TestData extends RefCounted:\n\tvar value := 1\n",
				encoding="utf-8",
			)

			self.assertEqual(
				gut_sharding.discover_gut_test_scripts(root),
				("res://tests/gf_core/kernel/test_helpers.gd",),
			)

	def test_inventory_resolves_shared_gut_test_bases_by_path_and_class_name(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			base = root / "tests/gf_core/support/shared_gut_base.gd"
			base.parent.mkdir(parents=True)
			base.write_text(
				'class_name SharedGutBase\nextends "res://addons/gut/test.gd"\n',
				encoding="utf-8",
			)
			path_test = root / "tests/gf_core/kernel/test_path_base.gd"
			path_test.parent.mkdir(parents=True)
			path_test.write_text(
				'extends "res://tests/gf_core/support/shared_gut_base.gd"\n',
				encoding="utf-8",
			)
			class_test = root / "tests/gf_core/kernel/test_class_base.gd"
			class_test.write_text("extends SharedGutBase\n", encoding="utf-8")

			self.assertEqual(
				gut_sharding.discover_gut_test_scripts(root),
				(
					"res://tests/gf_core/kernel/test_class_base.gd",
					"res://tests/gf_core/kernel/test_path_base.gd",
				),
			)

	def test_inventory_rejects_paths_the_controlled_xml_exporter_cannot_escape(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			self._write_test(root, "kernel/test_xml&unsafe.gd")

			with self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"test_script_path_xml_unsafe",
			):
				gut_sharding.discover_gut_test_scripts(root)

		for unsafe in ('"', "<", "\ufffe"):
			with self.subTest(character=repr(unsafe)), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"test_script_path_xml_unsafe",
			):
				gut_sharding._normalize_test_script_path(  # noqa: SLF001
					f"res://tests/gf_core/kernel/test_xml{unsafe}unsafe.gd"
				)

	def test_inventory_rejects_invalid_utf8_test_source(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			path = root / "tests/gf_core/kernel/test_invalid.gd"
			path.parent.mkdir(parents=True)
			path.write_bytes(b"extends GutTest\n\xff")

			with self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"inventory_script_utf8_invalid",
			):
				gut_sharding.discover_gut_test_scripts(root)

	def test_inventory_rejects_special_entries(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			tests_root = root / "tests/gf_core"
			tests_root.mkdir(parents=True)
			link_path = tests_root / "linked"
			target_path = root / "target"
			target_path.mkdir()
			maintenance.create_directory_link_fixture(target_path, link_path)

			with self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"inventory_link_forbidden",
			):
				gut_sharding.discover_gut_test_scripts(root)

	def test_inventory_stops_scandir_at_the_entry_budget(self) -> None:
		class BoundedScandir:
			def __init__(self) -> None:
				self.yield_count = 0

			def __enter__(self) -> BoundedScandir:
				return self

			def __exit__(self, *_args: object) -> None:
				return None

			def __iter__(self) -> BoundedScandir:
				return self

			def __next__(self) -> object:
				if self.yield_count >= 3:
					raise AssertionError("scandir was consumed beyond the entry budget")
				entry = type("InventoryEntry", (), {})()
				entry.name = f"entry-{self.yield_count}"
				self.yield_count += 1
				return entry

		with tempfile.TemporaryDirectory() as temporary_directory:
			tests_root = Path(temporary_directory) / "tests/gf_core"
			tests_root.mkdir(parents=True)
			iterator = BoundedScandir()
			with mock.patch.object(
				gut_sharding,
				"MAX_INVENTORY_ENTRIES",
				2,
			), mock.patch.object(
				gut_sharding.os,
				"scandir",
				return_value=iterator,
			), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"inventory_entry_budget_exceeded",
			):
				gut_sharding._scan_test_inventory(  # noqa: SLF001
					tests_root,
					float("inf"),
				)

			self.assertEqual(iterator.yield_count, 3)

	def test_inventory_checks_deadline_after_final_scandir_step(self) -> None:
		clock = [0.0]

		class DeadlineScandir:
			def __enter__(self) -> DeadlineScandir:
				return self

			def __exit__(self, *_args: object) -> None:
				return None

			def __iter__(self) -> DeadlineScandir:
				return self

			def __next__(self) -> object:
				clock[0] = 2.0
				raise StopIteration

		with tempfile.TemporaryDirectory() as temporary_directory:
			tests_root = Path(temporary_directory) / "tests/gf_core"
			tests_root.mkdir(parents=True)
			with mock.patch.object(
				gut_sharding.os,
				"scandir",
				return_value=DeadlineScandir(),
			), mock.patch.object(
				gut_sharding.time,
				"monotonic",
				side_effect=lambda: clock[0],
			), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"inventory_deadline_exceeded",
			):
				gut_sharding._scan_test_inventory(tests_root, 1.0)  # noqa: SLF001

	def test_inventory_checks_deadline_after_stable_source_read(self) -> None:
		clock = [0.0]
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			self._write_test(root, "kernel/test_deadline.gd")

			def delayed_read(*_args: object, **_kwargs: object) -> bytes:
				clock[0] = 2.0
				return b"extends GutTest\n"

			with mock.patch.object(
				gut_sharding,
				"_read_stable_regular_file",
				side_effect=delayed_read,
			), mock.patch.object(
				gut_sharding.time,
				"monotonic",
				side_effect=lambda: clock[0],
			), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"inventory_deadline_exceeded",
			):
				gut_sharding._scan_test_inventory(  # noqa: SLF001
					root / "tests/gf_core",
					1.0,
				)

	def test_inventory_rejects_queued_directory_replacement(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			tests_root = root / "tests/gf_core"
			queued = tests_root / "queued"
			queued.mkdir(parents=True)
			self._write_test(root, "queued/test_original.gd")
			replacement = root / "replacement"
			replacement.mkdir()
			(replacement / "test_escape.gd").write_text(
				"extends GutTest\n",
				encoding="utf-8",
			)
			real_scandir = gut_sharding.os.scandir
			replaced = False

			def replacing_scandir(path: object) -> object:
				nonlocal replaced
				iterator = real_scandir(path)
				if Path(path) == tests_root and not replaced:
					entries = list(iterator)
					iterator.close()
					original = queued.with_name("queued-original")
					queued.rename(original)
					maintenance.create_directory_link_fixture(replacement, queued)
					replaced = True
					return _ListScandir(entries)
				return iterator

			with mock.patch.object(
				gut_sharding.os,
				"scandir",
				side_effect=replacing_scandir,
			), self.assertRaises(gut_sharding.GutShardingError) as captured:
				gut_sharding._scan_test_inventory(tests_root, float("inf"))  # noqa: SLF001
			self.assertIn(
				captured.exception.code,
				{
					"inventory_directory_changed",
					"inventory_link_forbidden",
					"inventory_special_file_forbidden",
				},
			)

	def test_inventory_binds_enumerated_file_identity_to_stable_read(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			path = self._write_test(root, "kernel/test_identity.gd")
			real_read = gut_sharding._read_stable_regular_file  # noqa: SLF001

			def replace_before_read(
				read_path: Path,
				max_bytes: int,
				label: str,
				**kwargs: object,
			) -> bytes:
				replacement = path.with_name("replacement.gd")
				replacement.write_text("extends GutTest\n# replacement\n", encoding="utf-8")
				os.replace(replacement, path)
				return real_read(read_path, max_bytes, label, **kwargs)

			with mock.patch.object(
				gut_sharding,
				"_read_stable_regular_file",
				side_effect=replace_before_read,
			), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"inventory_script_file_changed",
			):
				gut_sharding._scan_test_inventory(  # noqa: SLF001
					root / "tests/gf_core",
					float("inf"),
				)

	def test_inventory_rejects_second_scan_tail_directory_replacement(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			tests_root = root / "tests/gf_core"
			queued = tests_root / "queued"
			self._write_test(root, "queued/test_original.gd")
			replacement = root / "replacement"
			replacement.mkdir()
			(replacement / "test_replacement.gd").write_text(
				"extends GutTest\n",
				encoding="utf-8",
			)
			real_scan = gut_sharding._scan_test_inventory  # noqa: SLF001
			real_validate = gut_sharding._validate_directory_chain  # noqa: SLF001
			scan_number = 0
			queued_validation_count = 0

			def track_scan(scan_root: Path, deadline: float) -> object:
				nonlocal scan_number
				scan_number += 1
				return real_scan(scan_root, deadline)

			def replace_after_second_scan_tail(
				chain: tuple[tuple[Path, tuple[int, int, int]], ...],
				code: str,
			) -> None:
				nonlocal queued_validation_count
				if scan_number == 2 and chain[-1][0] == queued:
					queued_validation_count += 1
					if queued_validation_count == 2:
						queued.rename(root / "queued-original")
						replacement.rename(queued)
				real_validate(chain, code)

			with mock.patch.object(
				gut_sharding,
				"_scan_test_inventory",
				side_effect=track_scan,
			), mock.patch.object(
				gut_sharding,
				"_validate_directory_chain",
				side_effect=replace_after_second_scan_tail,
			), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"inventory_directory_changed",
			):
				gut_sharding.discover_gut_test_scripts(root)
			self.assertEqual(scan_number, 2)
			self.assertEqual(queued_validation_count, 2)

	def test_inventory_rejects_second_scan_tail_shared_base_replacement(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			base = root / "tests/gf_core/support/shared_gut_base.gd"
			base.parent.mkdir(parents=True)
			base.write_text(
				"class_name SharedGutBase\nextends GutTest\n",
				encoding="utf-8",
			)
			test_path = root / "tests/gf_core/kernel/test_shared_base.gd"
			test_path.parent.mkdir(parents=True)
			test_path.write_text("extends SharedGutBase\n", encoding="utf-8")
			real_scan = gut_sharding._scan_test_inventory  # noqa: SLF001
			real_inner_check = gut_sharding._source_has_inner_gut_test  # noqa: SLF001
			scan_number = 0
			replaced = False

			def track_scan(scan_root: Path, deadline: float) -> object:
				nonlocal scan_number
				scan_number += 1
				return real_scan(scan_root, deadline)

			def replace_base_after_second_inheritance(
				resource_path: str,
				*args: object,
				**kwargs: object,
			) -> bool:
				nonlocal replaced
				result = real_inner_check(resource_path, *args, **kwargs)
				if scan_number == 2 and not replaced:
					replacement = base.with_name("shared_gut_base_replacement.gd")
					replacement.write_text(
						"class_name SharedGutBase\nextends Node\n",
						encoding="utf-8",
					)
					os.replace(replacement, base)
					replaced = True
				return result

			with mock.patch.object(
				gut_sharding,
				"_scan_test_inventory",
				side_effect=track_scan,
			), mock.patch.object(
				gut_sharding,
				"_source_has_inner_gut_test",
				side_effect=replace_base_after_second_inheritance,
			), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"inventory_script_file_changed",
			):
				gut_sharding.discover_gut_test_scripts(root)
			self.assertEqual(scan_number, 2)
			self.assertTrue(replaced)

	@staticmethod
	def _write_test(root: Path, relative_path: str) -> Path:
		path = root / "tests/gf_core" / relative_path
		path.parent.mkdir(parents=True, exist_ok=True)
		path.write_text("extends GutTest\n", encoding="utf-8")
		return path


class _ListScandir:
	def __init__(self, entries: list[object]) -> None:
		self._iterator = iter(entries)

	def __enter__(self) -> _ListScandir:
		return self

	def __exit__(self, *_args: object) -> None:
		return None

	def __iter__(self) -> _ListScandir:
		return self

	def __next__(self) -> object:
		return next(self._iterator)


class GutManifestTests(unittest.TestCase):
	def setUp(self) -> None:
		self.inventory = (
			"res://tests/gf_core/kernel/test_alpha.gd",
			"res://tests/gf_core/maintenance/test_contract.gd",
			"res://tests/gf_core/standard/test_beta.gd",
			gut_sharding.LIFECYCLE_CONTRACT_SCRIPT,
		)
		self.manifest = gut_sharding._bootstrap_manifest_for_inventory(  # noqa: SLF001
			self.inventory
		)

	def test_bootstrap_manifest_has_fixed_shards_and_no_performance_claim(self) -> None:
		normalized = gut_sharding.validate_manifest(
			self.manifest,
			self.inventory,
		)

		self.assertEqual(
			[shard["name"] for shard in normalized["shards"]],
			list(gut_sharding.SHARD_NAMES),
		)
		self.assertEqual(
			normalized["balancing_basis"],
			"bootstrap_unweighted",
		)
		self.assertEqual(normalized["timing_observation_run_count"], 0)
		self.assertEqual(normalized["required_timing_observation_run_count"], 5)
		self.assertEqual(
			normalized["execution_policy"],
			"observe_full_suite_no_skip",
		)
		contracts = normalized["shards"][0]["scripts"]
		self.assertEqual(
			contracts,
			[
				"res://tests/gf_core/maintenance/test_contract.gd",
				gut_sharding.LIFECYCLE_CONTRACT_SCRIPT,
			],
		)

	def test_test_script_paths_reject_nonportable_components(self) -> None:
		for relative_path in (
			"CON/test_reserved.gd",
			"trailing./test_trailing_dot.gd",
			"trailing /test_trailing_space.gd",
			"invalid?/test_question.gd",
			"invalid*/test_star.gd",
		):
			with self.subTest(path=relative_path), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"test_script_path_not_portable",
			):
				gut_sharding._normalize_test_script_path(  # noqa: SLF001
					f"{gut_sharding.INVENTORY_ROOT}/{relative_path}",
				)

	def test_bootstrap_lanes_are_stable_and_count_balanced(self) -> None:
		inventory = tuple(
			f"res://tests/gf_core/kernel/test_{index:03d}.gd"
			for index in range(31)
		)
		first = gut_sharding._bootstrap_manifest_for_inventory(inventory)  # noqa: SLF001
		second = gut_sharding._bootstrap_manifest_for_inventory(  # noqa: SLF001
			reversed(inventory)
		)

		self.assertEqual(first, second)
		lane_counts = [len(shard["scripts"]) for shard in first["shards"][1:]]
		self.assertLessEqual(max(lane_counts) - min(lane_counts), 1)

	def test_missing_script_is_rejected(self) -> None:
		mutated = copy.deepcopy(self.manifest)
		for shard in mutated["shards"]:
			if self.inventory[0] in shard["scripts"]:
				shard["scripts"].remove(self.inventory[0])
				break
		mutated["script_count"] -= 1

		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"manifest_script_missing",
		):
			gut_sharding.validate_manifest(mutated, self.inventory)

	def test_extra_script_is_rejected(self) -> None:
		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"manifest_script_extra",
		):
			gut_sharding.validate_manifest(self.manifest, self.inventory[:-1])

	def test_lifecycle_contract_is_required_even_for_self_consistent_inventory(self) -> None:
		inventory = tuple(
			script
			for script in self.inventory
			if script != gut_sharding.LIFECYCLE_CONTRACT_SCRIPT
		)
		manifest = gut_sharding._bootstrap_manifest_for_inventory(inventory)  # noqa: SLF001

		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"manifest_required_contract_missing",
		):
			gut_sharding.validate_manifest(manifest, inventory)

	def test_duplicate_script_is_rejected(self) -> None:
		mutated = copy.deepcopy(self.manifest)
		mutated["shards"][-1]["scripts"].append(self.inventory[0])
		mutated["shards"][-1]["scripts"].sort()
		mutated["script_count"] += 1

		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"manifest_script_duplicate",
		):
			gut_sharding.validate_manifest(mutated, self.inventory)

	def test_extra_schema_field_is_rejected(self) -> None:
		mutated = copy.deepcopy(self.manifest)
		mutated["unrecognized"] = True

		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"manifest_schema_invalid",
		):
			gut_sharding.validate_manifest(mutated, self.inventory)

	def test_noncanonical_assignment_is_rejected(self) -> None:
		mutated = copy.deepcopy(self.manifest)
		nonempty_lanes = [
			shard for shard in mutated["shards"][1:] if shard["scripts"]
		]
		first_script = nonempty_lanes[0]["scripts"].pop()
		second_script = nonempty_lanes[1]["scripts"].pop()
		nonempty_lanes[0]["scripts"].append(second_script)
		nonempty_lanes[1]["scripts"].append(first_script)
		for shard in nonempty_lanes[:2]:
			shard["scripts"].sort()

		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"manifest_bootstrap_assignment_mismatch",
		):
			gut_sharding.validate_manifest(mutated, self.inventory)

	def test_inventory_digest_binds_sorted_complete_inventory(self) -> None:
		mutated = copy.deepcopy(self.manifest)
		mutated["inventory_digest"] = "0" * 64

		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"manifest_inventory_digest_mismatch",
		):
			gut_sharding.validate_manifest(mutated, self.inventory)

	def test_canonical_digest_is_independent_of_dictionary_insertion_order(self) -> None:
		reordered = {
			key: self.manifest[key]
			for key in reversed(tuple(self.manifest))
		}

		self.assertEqual(
			gut_sharding.canonical_json_bytes(self.manifest),
			gut_sharding.canonical_json_bytes(reordered),
		)
		self.assertEqual(
			gut_sharding.canonical_digest(self.manifest),
			gut_sharding.canonical_digest(reordered),
		)

	def test_manifest_reader_rejects_duplicate_json_keys_and_directories(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			manifest_path = root / "manifest.json"
			manifest_path.write_text(
				'{"schema_version":1,"schema_version":1}',
				encoding="utf-8",
			)
			with self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"manifest_json_duplicate_key",
			):
				gut_sharding.load_and_validate_manifest(
					manifest_path,
					root=root,
					expected_inventory=(),
				)
			with self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"manifest_file_not_regular",
			):
				gut_sharding.load_and_validate_manifest(
					root,
					root=root,
					expected_inventory=(),
				)


class GutJunitTests(unittest.TestCase):
	SCRIPT_ALPHA = "res://tests/gf_core/kernel/test_alpha.gd"
	SCRIPT_BETA = "res://tests/gf_core/standard/test_beta.gd"

	def test_parser_reports_per_script_and_test_timing_status_and_assertions(self) -> None:
		xml = self._junit_xml([
			self._suite_xml(
				self.SCRIPT_ALPHA,
				[
					self._test_xml("test_passes", "pass", "0.25", assertions="3"),
					self._test_xml("test_fails", "fail", "0.5", assertions="1"),
				],
			),
			self._suite_xml(
				self.SCRIPT_BETA,
				[self._test_xml("test_pending", "pending", "0.125")],
			),
		])

		result = self._parse(xml, expected=(self.SCRIPT_ALPHA, self.SCRIPT_BETA))

		self.assertTrue(result["ok"])
		self.assertTrue(result["input_complete"])
		self.assertEqual(result["script_count"], 2)
		self.assertEqual(result["test_count"], 3)
		self.assertEqual(
			result["status_counts"],
			{
				"passed": 1,
				"failed": 1,
				"pending": 1,
				"no_asserts": 0,
				"skipped": 0,
			},
		)
		self.assertAlmostEqual(result["duration_seconds"], 0.895)
		self.assertAlmostEqual(result["testcase_duration_seconds"], 0.875)
		self.assertEqual(
			result["duration_scope"],
			gut_sharding.JUNIT_LIFECYCLE_DURATION_SCOPE,
		)
		self.assertEqual(result["assertion_count"], 4)
		self.assertTrue(result["assertion_counts_complete"])
		self.assertIsNone(result["assertion_count_unknown_reason"])
		alpha = result["scripts"][0]
		self.assertEqual(alpha["script"], self.SCRIPT_ALPHA)
		self.assertEqual(alpha["assertion_count"], 4)
		self.assertTrue(alpha["assertion_counts_complete"])
		self.assertEqual(
			alpha["tests"],
			[
				{
					"name": "test_fails",
					"duration_seconds": 0.5,
					"status": "failed",
					"assertion_count": 1,
				},
				{
					"name": "test_passes",
					"duration_seconds": 0.25,
					"status": "passed",
					"assertion_count": 3,
				},
			],
		)
		self.assertEqual(result["scripts"][1]["tests"][0]["status"], "pending")

	def test_plain_junit_marks_coverage_and_lifecycle_assertions_incomplete(self) -> None:
		xml = self._junit_xml([
			self._suite_xml(
				self.SCRIPT_ALPHA,
				[self._test_xml("test_alpha", "pass", "0.1", assertions="1")],
			),
		])

		result = self._parse(
			xml,
			expected=(self.SCRIPT_ALPHA,),
			with_provenance=False,
		)

		self.assertFalse(result["input_complete"])
		self.assertEqual(
			result["completeness_basis"],
			gut_sharding.JUNIT_COMPLETENESS_SCRIPT_NAMES_ONLY,
		)
		self.assertFalse(result["assertion_counts_complete"])
		self.assertEqual(
			result["assertion_count_unknown_reason"],
			gut_sharding.JUNIT_ASSERTION_COUNT_UNKNOWN_REASON,
		)
		self.assertEqual(
			result["duration_scope"],
			gut_sharding.JUNIT_TESTCASE_DURATION_SCOPE,
		)

	def test_bound_provenance_adds_lifecycle_assertions_and_wall_time(self) -> None:
		xml = self._junit_xml([
			self._suite_xml(
				self.SCRIPT_ALPHA,
				[self._test_xml("test_alpha", "pass", "0.1", assertions="2")],
			),
		])

		result = self._parse(
			xml,
			expected=(self.SCRIPT_ALPHA,),
			lifecycle_assertions=3,
		)

		self.assertTrue(result["input_complete"])
		self.assertEqual(result["assertion_count"], 5)
		self.assertEqual(result["lifecycle_assertion_count"], 3)
		self.assertTrue(result["assertion_counts_complete"])
		self.assertAlmostEqual(result["duration_seconds"], 0.11)
		self.assertAlmostEqual(result["testcase_duration_seconds"], 0.1)

	def test_filtered_provenance_cannot_claim_complete_testcase_coverage(self) -> None:
		xml = self._junit_xml([
			self._suite_xml(
				self.SCRIPT_ALPHA,
				[self._test_xml("test_alpha", "pass", "0.1", assertions="1")],
			),
		])

		result = self._parse(
			xml,
			expected=(self.SCRIPT_ALPHA,),
			unfiltered=False,
		)

		self.assertFalse(result["input_complete"])
		self.assertFalse(result["assertion_counts_complete"])

	def test_provenance_binds_the_invocation_nonce_and_exact_junit_bytes(self) -> None:
		xml = self._junit_xml([
			self._suite_xml(
				self.SCRIPT_ALPHA,
				[self._test_xml("test_alpha", "pass", "0.1", assertions="1")],
			),
		])
		nonce = "a" * 64
		for field, value, error_code in (
			("nonce", "b" * 64, "junit_provenance_nonce_mismatch"),
			("junit_sha256", "0" * 64, "junit_provenance_junit_digest_mismatch"),
		):
			payload = self._provenance_from_xml(xml, nonce)
			payload[field] = value
			with self.subTest(field=field), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				error_code,
			):
				self._parse_with_provenance_payload(
					xml,
					payload,
					expected=(self.SCRIPT_ALPHA,),
					expected_nonce=nonce,
				)

	def test_provenance_execution_gaps_cannot_claim_complete_coverage(self) -> None:
		xml = self._junit_xml([
			self._suite_xml(
				self.SCRIPT_ALPHA,
				[self._test_xml("test_alpha", "pass", "0.1", assertions="1")],
			),
		])
		nonce = "a" * 64

		def omit_test(payload: dict[str, object]) -> None:
			script = payload["scripts"][0]
			script["tests"] = []
			script["assertion_count"] = 0

		mutations = (
			("script_not_run", lambda payload: payload["scripts"][0].__setitem__("was_run", False)),
			("script_skipped", lambda payload: payload["scripts"][0].__setitem__("was_skipped", True)),
			("test_not_run", lambda payload: payload["scripts"][0]["tests"][0].__setitem__("was_run", False)),
			("inner_class", lambda payload: payload["scripts"][0].__setitem__("inner_class", "TestInner")),
			("missing_test", omit_test),
		)
		for name, mutate in mutations:
			payload = self._provenance_from_xml(xml, nonce)
			mutate(payload)
			with self.subTest(gap=name):
				result = self._parse_with_provenance_payload(
					xml,
					payload,
					expected=(self.SCRIPT_ALPHA,),
					expected_nonce=nonce,
				)
				self.assertFalse(result["input_complete"])
				self.assertFalse(result["assertion_counts_complete"])

	def test_provenance_rejects_inconsistent_assertions_and_lifecycle_time(self) -> None:
		xml = self._junit_xml([
			self._suite_xml(
				self.SCRIPT_ALPHA,
				[self._test_xml("test_alpha", "pass", "0.1", assertions="1")],
			),
		])
		nonce = "a" * 64

		def mismatch_assertions(payload: dict[str, object]) -> None:
			payload["scripts"][0]["assertion_count"] = 2

		def shorten_lifecycle(payload: dict[str, object]) -> None:
			payload["scripts"][0]["duration_seconds"] = 0.01

		for name, mutate, error_code in (
			(
				"assertions",
				mismatch_assertions,
				"junit_provenance_assertion_count_mismatch",
			),
			(
				"duration",
				shorten_lifecycle,
				"junit_provenance_duration_mismatch",
			),
		):
			payload = self._provenance_from_xml(xml, nonce)
			mutate(payload)
			with self.subTest(field=name), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				error_code,
			):
				self._parse_with_provenance_payload(
					xml,
					payload,
					expected=(self.SCRIPT_ALPHA,),
					expected_nonce=nonce,
				)

	def test_parser_accepts_real_exporter_assertion_counters_and_all_statuses(self) -> None:
		tests = [
			self._test_xml(
				"test_pass",
				"pass",
				"0.1",
				assertions="2",
				script=self.SCRIPT_ALPHA,
			),
			self._test_xml(
				"test_fail",
				"fail",
				"0.2",
				assertions="3",
				script=self.SCRIPT_ALPHA,
			),
			self._test_xml(
				"test_pending",
				"pending",
				"0.3",
				assertions="0",
				script=self.SCRIPT_ALPHA,
			),
			self._test_xml(
				"test_no_asserts",
				"no asserts",
				"0.4",
				assertions="0",
				script=self.SCRIPT_ALPHA,
			),
			self._test_xml(
				"test_skipped",
				"skipped",
				"0",
				assertions="0",
				script=self.SCRIPT_ALPHA,
			),
		]
		xml = self._junit_xml([
			self._suite_xml(
				self.SCRIPT_ALPHA,
				tests,
				failure_assertion_count=2,
				pending_assertion_count=2,
			),
		])

		result = self._parse(xml, expected=(self.SCRIPT_ALPHA,))

		self.assertEqual(
			result["status_counts"],
			{
				"passed": 1,
				"failed": 1,
				"pending": 1,
				"no_asserts": 1,
				"skipped": 1,
			},
		)
		self.assertEqual(result["failure_assertion_count"], 2)
		self.assertEqual(result["pending_assertion_count"], 2)
		self.assertEqual(result["assertion_count"], 5)
		self.assertEqual(
			[test["status"] for test in result["scripts"][0]["tests"]],
			["failed", "no_asserts", "passed", "pending", "skipped"],
		)

	def test_parser_accepts_pending_status_with_hidden_failing_assertions(self) -> None:
		pending_with_failure = self._test_xml(
			"test_pending_with_failure",
			"pending",
			"0.1",
			assertions="1",
			script=self.SCRIPT_ALPHA,
		)
		suite = self._suite_xml(
			self.SCRIPT_ALPHA,
			[pending_with_failure],
			failure_assertion_count=1,
			pending_assertion_count=1,
		)
		xml = self._junit_xml([suite]).replace(
			'<testsuites name="GutTests" failures="0"',
			'<testsuites name="GutTests" failures="1"',
			1,
		)

		result = self._parse(xml, expected=(self.SCRIPT_ALPHA,))

		self.assertEqual(result["status_counts"]["pending"], 1)
		self.assertEqual(result["status_counts"]["failed"], 0)
		self.assertEqual(result["failure_test_count"], 1)
		self.assertEqual(result["failure_assertion_count"], 1)

	def test_parser_rejects_dtd_and_entity_declarations(self) -> None:
		xml = (
			'<?xml version="1.0" encoding="UTF-8"?>\n'
			'<!DOCTYPE testsuites [<!ENTITY payload SYSTEM "file:///etc/passwd">]>\n'
			'<testsuites name="GutTests" failures="0" tests="0">'
			'</testsuites>'
		)

		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"junit_xml_declaration_forbidden",
		):
			self._parse(xml)

	def test_parser_rejects_real_processing_instructions_and_comments(self) -> None:
		for injected_xml, error_code in (
			("<?probe value?>", "junit_xml_processing_instruction_forbidden"),
			("<!-- probe -->", "junit_xml_comment_forbidden"),
		):
			with self.subTest(error=error_code), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				error_code,
			):
				self._parse(
					self._junit_xml([]).replace(
						"<testsuites ",
						f"{injected_xml}\n<testsuites ",
						1,
					)
				)

	def test_parser_rejects_namespace_declarations(self) -> None:
		for namespace_attribute in (' xmlns:x="urn:x"', ' xmlns=""'):
			with self.subTest(attribute=namespace_attribute), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"junit_namespace_forbidden",
			):
				self._parse(
					self._junit_xml([]).replace(
						'<testsuites name="GutTests"',
						f'<testsuites{namespace_attribute} name="GutTests"',
						1,
					)
				)

	def test_parser_accepts_declaration_like_text_inside_cdata(self) -> None:
		test = self._test_xml(
			"test_pending",
			"pending",
			"0.1",
			assertions="0",
			script=self.SCRIPT_ALPHA,
		).replace(
			"fixture pending",
			"<!DOCTYPE html> <!ENTITY sample> <?probe?>",
		)
		xml = self._junit_xml([self._suite_xml(self.SCRIPT_ALPHA, [test])])

		result = self._parse(xml, expected=(self.SCRIPT_ALPHA,))

		self.assertTrue(result["input_complete"])
		self.assertEqual(result["status_counts"]["pending"], 1)

	def test_parser_rejects_nonformatting_container_and_testcase_text(self) -> None:
		test = self._test_xml(
			"test_text_contract",
			"pass",
			"0.1",
			assertions="1",
			script=self.SCRIPT_ALPHA,
		)
		suite = self._suite_xml(self.SCRIPT_ALPHA, [test])
		valid = self._junit_xml([suite])
		fixtures = (
			(
				valid.replace("\n<testsuite ", "ROOT_TEXT\n<testsuite ", 1),
				"junit_root_text_invalid",
			),
			(
				valid.replace(">\n<testcase ", ">SUITE_TEXT\n<testcase ", 1),
				"junit_suite_text_invalid",
			),
			(
				valid.replace("></testcase>", ">TEST_TEXT</testcase>", 1),
				"junit_test_text_invalid",
			),
			(
				valid.replace("\n<testsuite ", "\u00a0\n<testsuite ", 1),
				"junit_root_text_invalid",
			),
		)
		for xml, error_code in fixtures:
			with self.subTest(error=error_code), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				error_code,
			):
				self._parse(xml, expected=(self.SCRIPT_ALPHA,))

	def test_parser_requires_controlled_exporter_declaration(self) -> None:
		valid = self._junit_xml([])
		for mutated in (
			valid.removeprefix('<?xml version="1.0" encoding="UTF-8"?>\n'),
			valid.replace('encoding="UTF-8"', 'encoding="ISO-8859-1"', 1),
		):
			with self.subTest(xml=mutated[:48]), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"junit_xml_declaration_invalid",
			):
				self._parse(mutated)

	def test_parser_rejects_byte_budget_and_invalid_utf8(self) -> None:
		valid = self._junit_xml([])
		with mock.patch.object(gut_sharding, "MAX_JUNIT_BYTES", 16):
			with self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"junit_file_budget_exceeded",
			):
				self._parse(valid)
		with tempfile.TemporaryDirectory() as temporary_directory:
			path = Path(temporary_directory) / "gut.xml"
			path.write_bytes(b"<testsuites>\xff</testsuites>")
			with self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"junit_utf8_invalid",
			):
				gut_sharding.parse_gut_junit_xml(path)

	def test_parser_binds_the_expected_file_identity_before_opening(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			path = Path(temporary_directory) / "gut.xml"
			path.write_text(self._junit_xml([]), encoding="utf-8")
			expected = list(gut_sharding.stable_file_identity(path.lstat()))
			expected[3] += 1
			with self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"junit_file_changed",
			):
				gut_sharding.parse_gut_junit_xml(
					path,
					expected_file_identity=tuple(expected),
				)

	def test_streaming_xml_budgets_reject_before_tree_construction(self) -> None:
		declaration = '<?xml version="1.0" encoding="UTF-8"?>\n'
		fixtures = (
			(
				"MAX_JUNIT_ELEMENTS",
				1,
				declaration
				+ '<testsuites name="GutTests" failures="0" tests="0"><testsuite /></testsuites>',
				"junit_element_budget_exceeded",
			),
			(
				"MAX_XML_ATTRIBUTES_PER_ELEMENT",
				2,
				declaration
				+ '<testsuites name="GutTests" failures="0" tests="0"></testsuites>',
				"junit_attribute_budget_exceeded",
			),
			(
				"MAX_XML_TEXT_BYTES",
				1,
				declaration
				+ '<testsuites name="GutTests" failures="0" tests="0">xx</testsuites>',
				"junit_text_budget_exceeded",
			),
		)
		for limit_name, limit, xml, error_code in fixtures:
			with self.subTest(limit=limit_name), mock.patch.object(
				gut_sharding,
				limit_name,
				limit,
			), mock.patch.object(
				gut_sharding.ET,
				"fromstring",
			) as build_tree:
				with self.assertRaisesRegex(
					gut_sharding.GutShardingError,
					error_code,
				):
					self._parse(xml)
				build_tree.assert_not_called()

	def test_parser_rejects_duplicate_script_identity(self) -> None:
		suite = self._suite_xml(
			self.SCRIPT_ALPHA,
			[self._test_xml("test_alpha", "pass", "0.1", assertions="1")],
		)
		xml = self._junit_xml([suite, suite])

		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"junit_test_identity_duplicate|junit_script_duplicate",
		):
			self._parse(xml)

	def test_parser_rejects_duplicate_test_identity(self) -> None:
		test = self._test_xml("test_alpha", "pass", "0.1", assertions="1")
		xml = self._junit_xml([
			self._suite_xml(self.SCRIPT_ALPHA, [test, test]),
		])

		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"junit_test_identity_duplicate",
		):
			self._parse(xml)

	def test_parser_rejects_missing_and_extra_expected_scripts(self) -> None:
		xml = self._junit_xml([
			self._suite_xml(
				self.SCRIPT_ALPHA,
				[self._test_xml("test_alpha", "pass", "0.1", assertions="1")],
			),
		])

		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"junit_script_missing",
		):
			self._parse(xml, expected=(self.SCRIPT_ALPHA, self.SCRIPT_BETA))
		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"junit_script_extra",
		):
			self._parse(xml, expected=())

	def test_parser_rejects_count_duration_and_closed_schema_drift(self) -> None:
		test = self._test_xml("test_alpha", "pass", "0.1", assertions="1")
		suite = self._suite_xml(self.SCRIPT_ALPHA, [test]).replace(
			'time="0.1"',
			'time="0.2"',
			1,
		)
		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"junit_suite_duration_mismatch",
		):
			self._parse(self._junit_xml([suite]))

		extra_attribute = test.replace("<testcase ", '<testcase unknown="x" ')
		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"junit_test_attributes_invalid",
		):
			self._parse(self._junit_xml([
				self._suite_xml(self.SCRIPT_ALPHA, [extra_attribute]),
			]))

		missing_assertions = test.replace(' assertions="1"', "")
		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"junit_test_attributes_invalid",
		):
			self._parse(self._junit_xml([
				self._suite_xml(self.SCRIPT_ALPHA, [missing_assertions]),
			]))

	def test_parser_rejects_status_assertion_and_result_message_drift(self) -> None:
		fixtures = (
			("pass", "0", "junit_test_assertion_status_mismatch"),
			("fail", "0", "junit_test_assertion_status_mismatch"),
			("no asserts", "1", "junit_test_assertion_status_mismatch"),
		)
		for status, assertions, error_code in fixtures:
			test = self._test_xml(
				"test_status_contract",
				status,
				"0.1",
				assertions=assertions,
				script=self.SCRIPT_ALPHA,
			)
			with self.subTest(status=status), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				error_code,
			):
				self._parse(self._junit_xml([
					self._suite_xml(self.SCRIPT_ALPHA, [test]),
				]))

		for status, assertions, old_message in (
			("fail", "1", 'message="failed"'),
			("pending", "0", 'message="pending"'),
		):
			test = self._test_xml(
				"test_result_message",
				status,
				"0.1",
				assertions=assertions,
				script=self.SCRIPT_ALPHA,
			).replace(old_message, 'message="drifted"')
			with self.subTest(status=status), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"junit_test_result_message_invalid",
			):
				self._parse(self._junit_xml([
					self._suite_xml(self.SCRIPT_ALPHA, [test]),
				]))

	def test_parser_rejects_suite_assertion_counters_below_status_minimums(self) -> None:
		fixtures = (
			("fail", "1", {"failure_assertion_count": 0}),
			("pending", "0", {"pending_assertion_count": 0}),
		)
		for status, assertions, suite_overrides in fixtures:
			test = self._test_xml(
				"test_counter_contract",
				status,
				"0.1",
				assertions=assertions,
				script=self.SCRIPT_ALPHA,
			)
			with self.subTest(status=status), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"junit_suite_(?:failure|pending)_assertion_count_mismatch",
			):
				self._parse(self._junit_xml([
					self._suite_xml(
						self.SCRIPT_ALPHA,
						[test],
						**suite_overrides,
					),
				]))

		pass_test = self._test_xml(
			"test_pass",
			"pass",
			"0.1",
			assertions="1",
			script=self.SCRIPT_ALPHA,
		)
		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"junit_suite_pending_assertion_count_mismatch",
		):
			self._parse(self._junit_xml([
				self._suite_xml(
					self.SCRIPT_ALPHA,
					[pass_test],
					pending_assertion_count=1,
				),
			]))

	def test_parser_rejects_root_failure_count_without_failure_assertion_capacity(self) -> None:
		failed = self._test_xml(
			"test_fail",
			"fail",
			"0.1",
			assertions="1",
			script=self.SCRIPT_ALPHA,
		)
		pending = self._test_xml(
			"test_pending",
			"pending",
			"0.1",
			assertions="0",
			script=self.SCRIPT_ALPHA,
		)
		suite = self._suite_xml(
			self.SCRIPT_ALPHA,
			[failed, pending],
			failure_assertion_count=1,
			pending_assertion_count=1,
		)
		xml = self._junit_xml([suite]).replace(
			'<testsuites name="GutTests" failures="1"',
			'<testsuites name="GutTests" failures="2"',
			1,
		)
		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"junit_root_failure_count_mismatch",
		):
			self._parse(xml)

	def test_parser_rejects_cross_suite_hidden_failure_reallocation(self) -> None:
		pending = self._test_xml(
			"test_pending",
			"pending",
			"0.1",
			assertions="1",
			script=self.SCRIPT_ALPHA,
		)
		failed = self._test_xml(
			"test_fail",
			"fail",
			"0.1",
			assertions="1",
			script=self.SCRIPT_BETA,
		)
		xml = self._junit_xml([
			self._suite_xml(
				self.SCRIPT_ALPHA,
				[pending],
				failure_assertion_count=0,
				pending_assertion_count=1,
			),
			self._suite_xml(
				self.SCRIPT_BETA,
				[failed],
				failure_assertion_count=2,
				pending_assertion_count=0,
			),
		]).replace(
			'<testsuites name="GutTests" failures="1"',
			'<testsuites name="GutTests" failures="2"',
			1,
		)
		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"junit_root_failure_count_mismatch",
		):
			self._parse(xml)

	def test_parser_accepts_bounded_exporter_duration_rounding(self) -> None:
		tests = [
			self._test_xml(
				"test_rounding_a",
				"pass",
				"0.000001",
				assertions="1",
				script=self.SCRIPT_ALPHA,
			),
			self._test_xml(
				"test_rounding_b",
				"pass",
				"0.000001",
				assertions="1",
				script=self.SCRIPT_ALPHA,
			),
		]
		suite = self._suite_xml(
			self.SCRIPT_ALPHA,
			tests,
			declared_duration="0.000001",
		)

		result = self._parse(self._junit_xml([suite]))

		self.assertEqual(result["scripts"][0]["duration_seconds"], 0.000001)
		self.assertEqual(
			result["scripts"][0]["duration_scope"],
			gut_sharding.JUNIT_TESTCASE_DURATION_SCOPE,
		)
		self.assertEqual(
			result["scripts"][0]["testcase_duration_seconds"],
			0.000001,
		)
		self.assertEqual(
			result["scripts"][0]["testcase_duration_sum_seconds"],
			0.000002,
		)

	def test_parser_rejects_nonfinite_aggregate_duration(self) -> None:
		suites = []
		for script, name in (
			(self.SCRIPT_ALPHA, "test_alpha"),
			(self.SCRIPT_BETA, "test_beta"),
		):
			suites.append(self._suite_xml(
				script,
				[
					self._test_xml(
						name,
						"pass",
						"1e308",
						assertions="1",
						script=script,
					),
				],
				declared_duration="1e308",
			))

		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"junit_duration_total_invalid",
		):
			self._parse(self._junit_xml(suites))

	def test_observation_aggregates_manifest_without_skip_reuse_or_balance_claim(self) -> None:
		inventory = (
			self.SCRIPT_ALPHA,
			self.SCRIPT_BETA,
			gut_sharding.LIFECYCLE_CONTRACT_SCRIPT,
		)
		manifest = gut_sharding._bootstrap_manifest_for_inventory(inventory)  # noqa: SLF001
		xml = self._junit_xml([
			self._suite_xml(
				self.SCRIPT_ALPHA,
				[self._test_xml("test_alpha", "pass", "0.1", assertions="2")],
			),
			self._suite_xml(
				self.SCRIPT_BETA,
				[self._test_xml("test_beta", "pass", "0.2", assertions="3")],
			),
			self._suite_xml(
				gut_sharding.LIFECYCLE_CONTRACT_SCRIPT,
				[
					self._test_xml(
						"test_lifecycle",
						"pass",
						"0.05",
						assertions="1",
						script=gut_sharding.LIFECYCLE_CONTRACT_SCRIPT,
					),
				],
			),
		])
		junit = self._parse(xml, expected=inventory)

		report = gut_sharding.build_observation_report(manifest, junit)

		self.assertTrue(report["observation_only"])
		self.assertFalse(report["execution_changed"])
		self.assertEqual(report["skip_count"], 0)
		self.assertEqual(report["reuse_count"], 0)
		self.assertFalse(report["performance_balance_claimed"])
		self.assertEqual(report["balancing_basis"], "bootstrap_unweighted")
		self.assertEqual(report["test_count"], 3)
		self.assertAlmostEqual(report["duration_seconds"], 0.38)
		self.assertAlmostEqual(report["testcase_duration_seconds"], 0.35)
		self.assertEqual(
			report["status_counts"],
			{
				"passed": 3,
				"failed": 0,
				"pending": 0,
				"no_asserts": 0,
				"skipped": 0,
			},
		)
		self.assertEqual(report["failure_test_count"], 0)
		self.assertEqual(report["failure_assertion_count"], 0)
		self.assertEqual(report["pending_assertion_count"], 0)
		self.assertEqual(report["assertion_count"], 6)
		self.assertEqual(sum(shard["script_count"] for shard in report["shards"]), 3)
		self.assertAlmostEqual(
			sum(shard["duration_seconds"] for shard in report["shards"]),
			0.38,
		)

	def test_observation_script_record_helper_matches_strict_junit_entrypoint(self) -> None:
		manifest, junit = self._observation_fixture(status="fail")

		actual = gut_sharding.build_observation_report_from_script_records(
			manifest,
			copy.deepcopy(junit["scripts"]),
			failure_test_count=junit["failure_test_count"],
		)

		self.assertEqual(
			actual,
			gut_sharding.build_observation_report(manifest, junit),
		)

	def test_observation_script_record_helper_rejects_non_closed_records(self) -> None:
		manifest, junit = self._observation_fixture()
		scripts = junit["scripts"]

		mutations: tuple[tuple[str, object, str], ...] = (
			(
				"non_list",
				tuple(copy.deepcopy(scripts)),
				"observation_junit_invalid",
			),
			(
				"schema_drift",
				self._mutated_observation_scripts(scripts, remove_field="tests"),
				"observation_script_schema_invalid",
			),
			(
				"noncanonical_path",
				self._mutated_observation_scripts(
					scripts,
					script="res://tests/gf_core//kernel/test_alpha.gd",
				),
				"test_script_path_invalid",
			),
			(
				"duplicate_path",
				copy.deepcopy(scripts) + [copy.deepcopy(scripts[0])],
				"observation_script_duplicate",
			),
			(
				"portable_identity_collision",
				copy.deepcopy(scripts)
				+ [
					{
						**copy.deepcopy(scripts[0]),
						"script": "res://tests/gf_core/kernel/test_Alpha.gd",
					},
				],
				"inventory_expected_identity_collision",
			),
			(
				"manifest_not_closed",
				[
					copy.deepcopy(script)
					for script in scripts
					if script["script"] != self.SCRIPT_ALPHA
				],
				"manifest_script_extra",
			),
		)
		for name, mutated_scripts, error_code in mutations:
			with self.subTest(mutation=name), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				error_code,
			):
				gut_sharding.build_observation_report_from_script_records(
					manifest,
					mutated_scripts,
					failure_test_count=junit["failure_test_count"],
				)

	def test_observation_script_record_helper_rejects_failure_count_and_duration_drift(self) -> None:
		manifest, junit = self._observation_fixture(status="fail")
		for failure_test_count in (True, -1, 1.0, "1"):
			with self.subTest(
				failure_test_count=failure_test_count,
			), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"observation_failure_test_count_invalid",
			):
				gut_sharding.build_observation_report_from_script_records(
					manifest,
					copy.deepcopy(junit["scripts"]),
					failure_test_count=failure_test_count,
				)
		for failure_test_count in (0, 2):
			with self.subTest(
				failure_bound=failure_test_count,
			), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"observation_failure_test_count_mismatch",
			):
				gut_sharding.build_observation_report_from_script_records(
					manifest,
					copy.deepcopy(junit["scripts"]),
					failure_test_count=failure_test_count,
				)

		nonfinite_scripts = copy.deepcopy(junit["scripts"])
		nonfinite_scripts[0]["duration_seconds"] = float("inf")
		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"observation_script_value_invalid",
		):
			gut_sharding.build_observation_report_from_script_records(
				manifest,
				nonfinite_scripts,
				failure_test_count=junit["failure_test_count"],
			)

		overflow_scripts = copy.deepcopy(junit["scripts"])
		for script in overflow_scripts:
			script["duration_seconds"] = 1e308
		with self.assertRaisesRegex(
			gut_sharding.GutShardingError,
			"observation_duration_total_invalid",
		):
			gut_sharding.build_observation_report_from_script_records(
				manifest,
				overflow_scripts,
				failure_test_count=junit["failure_test_count"],
			)

	def test_observation_rejects_coerced_parser_record_types(self) -> None:
		inventory = (gut_sharding.LIFECYCLE_CONTRACT_SCRIPT,)
		manifest = gut_sharding._bootstrap_manifest_for_inventory(inventory)  # noqa: SLF001
		xml = self._junit_xml([
			self._suite_xml(
				gut_sharding.LIFECYCLE_CONTRACT_SCRIPT,
				[
					self._test_xml(
						"test_lifecycle",
						"pass",
						"0.1",
						assertions="1",
						script=gut_sharding.LIFECYCLE_CONTRACT_SCRIPT,
					),
				],
			),
		])
		junit = self._parse(xml, expected=inventory)
		for field, forged in (
			("duration_seconds", "0.1"),
			("test_count", True),
			("assertion_count", False),
			("failure_assertion_count", "0"),
		):
			mutated = copy.deepcopy(junit)
			mutated["scripts"][0][field] = forged
			with self.subTest(field=field), self.assertRaisesRegex(
				gut_sharding.GutShardingError,
				"observation_script_value_invalid|observation_script_count_mismatch",
			):
				gut_sharding.build_observation_report(manifest, mutated)

	def test_observation_rejects_top_level_and_testcase_cross_field_drift(self) -> None:
		class ForgedString(str):
			pass

		inventory = (gut_sharding.LIFECYCLE_CONTRACT_SCRIPT,)
		manifest = gut_sharding._bootstrap_manifest_for_inventory(inventory)  # noqa: SLF001
		xml = self._junit_xml([
			self._suite_xml(
				gut_sharding.LIFECYCLE_CONTRACT_SCRIPT,
				[
					self._test_xml(
						"test_lifecycle",
						"pass",
						"0.1",
						assertions="1",
						script=gut_sharding.LIFECYCLE_CONTRACT_SCRIPT,
					),
				],
			),
		])
		junit = self._parse(xml, expected=inventory)
		def mutate_duration_contract(value: dict[str, object]) -> None:
			script = value["scripts"][0]
			script["duration_seconds"] = 9.0
			script["testcase_duration_serialization_tolerance_seconds"] = 10.0
			value["duration_seconds"] = 9.0

		def mutate_pending_contract(value: dict[str, object]) -> None:
			value["scripts"][0]["pending_assertion_count"] = 1
			value["pending_assertion_count"] = 1

		def mutate_source_format_key(value: dict[str, object]) -> None:
			source_format = value.pop("source_format")
			value[ForgedString("source_format")] = source_format

		mutations = (
			("source_format_key_subclass", mutate_source_format_key),
			(
				"source_format_subclass",
				lambda value: value.__setitem__(
					"source_format",
					ForgedString("gut_junit_xml"),
				),
			),
			("top_failure", lambda value: value.__setitem__("failure_test_count", 100)),
			("top_scripts", lambda value: value.__setitem__("script_count", 999)),
			("top_duration", lambda value: value.__setitem__("duration_seconds", 9.0)),
			("linked_duration_contract", mutate_duration_contract),
			("linked_pending_contract", mutate_pending_contract),
			(
				"test_status",
				lambda value: value["scripts"][0]["tests"][0].__setitem__(
					"status",
					"failed",
				),
			),
			(
				"test_status_subclass",
				lambda value: value["scripts"][0]["tests"][0].__setitem__(
					"status",
					ForgedString("passed"),
				),
			),
			(
				"test_assertion",
				lambda value: value["scripts"][0]["tests"][0].__setitem__(
					"assertion_count",
					2,
				),
			),
		)
		for name, mutate in mutations:
			mutated = copy.deepcopy(junit)
			mutate(mutated)
			with self.subTest(mutation=name), self.assertRaises(
				gut_sharding.GutShardingError,
			):
				gut_sharding.build_observation_report(manifest, mutated)

	def _observation_fixture(
		self,
		*,
		status: str = "pass",
	) -> tuple[dict[str, object], dict[str, object]]:
		inventory = (
			self.SCRIPT_ALPHA,
			gut_sharding.LIFECYCLE_CONTRACT_SCRIPT,
		)
		manifest = gut_sharding._bootstrap_manifest_for_inventory(inventory)  # noqa: SLF001
		xml = self._junit_xml([
			self._suite_xml(
				self.SCRIPT_ALPHA,
				[
					self._test_xml(
						"test_alpha",
						status,
						"0.1",
						assertions="1",
						script=self.SCRIPT_ALPHA,
					),
				],
			),
			self._suite_xml(
				gut_sharding.LIFECYCLE_CONTRACT_SCRIPT,
				[
					self._test_xml(
						"test_lifecycle",
						"pass",
						"0.1",
						assertions="1",
						script=gut_sharding.LIFECYCLE_CONTRACT_SCRIPT,
					),
				],
			),
		])
		return manifest, self._parse(xml, expected=inventory)

	@staticmethod
	def _mutated_observation_scripts(
		scripts: object,
		*,
		remove_field: str | None = None,
		script: str | None = None,
	) -> list[dict[str, object]]:
		mutated = copy.deepcopy(scripts)
		if remove_field is not None:
			mutated[0].pop(remove_field)
		if script is not None:
			mutated[0]["script"] = script
		return mutated

	def _parse(
		self,
		xml: str,
		*,
		expected: tuple[str, ...] | None = None,
		with_provenance: bool = True,
		lifecycle_assertions: int = 0,
		unfiltered: bool = True,
	) -> dict[str, object]:
		with tempfile.TemporaryDirectory() as temporary_directory:
			path = Path(temporary_directory) / "gut.xml"
			path.write_text(xml, encoding="utf-8", newline="\n")
			provenance_path: Path | None = None
			nonce: str | None = None
			if expected is not None and with_provenance:
				nonce = "a" * 64
				provenance_path = Path(temporary_directory) / "gut-provenance.json"
				provenance_path.write_text(
					json.dumps(
						self._provenance_from_xml(
							xml,
							nonce,
							lifecycle_assertions=lifecycle_assertions,
							unfiltered=unfiltered,
						),
						ensure_ascii=False,
						allow_nan=False,
						separators=(",", ":"),
						sort_keys=True,
					),
					encoding="utf-8",
					newline="\n",
				)
			return gut_sharding.parse_gut_junit_xml(
				path,
				expected_scripts=expected,
				trusted_unfiltered_run=provenance_path is not None,
				provenance_path=provenance_path,
				expected_provenance_nonce=nonce,
			)

	@staticmethod
	def _parse_with_provenance_payload(
		xml: str,
		payload: dict[str, object],
		*,
		expected: tuple[str, ...],
		expected_nonce: str,
	) -> dict[str, object]:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			junit_path = root / "gut.xml"
			junit_path.write_text(xml, encoding="utf-8", newline="\n")
			provenance_path = root / "gut-provenance.json"
			provenance_path.write_text(
				json.dumps(
					payload,
					ensure_ascii=False,
					allow_nan=False,
					separators=(",", ":"),
					sort_keys=True,
				),
				encoding="utf-8",
				newline="\n",
			)
			return gut_sharding.parse_gut_junit_xml(
				junit_path,
				expected_scripts=expected,
				trusted_unfiltered_run=True,
				provenance_path=provenance_path,
				expected_provenance_nonce=expected_nonce,
			)

	@staticmethod
	def _provenance_from_xml(
		xml: str,
		nonce: str,
		*,
		lifecycle_assertions: int = 0,
		unfiltered: bool = True,
	) -> dict[str, object]:
		root = gut_sharding.ET.fromstring(xml)
		scripts: list[dict[str, object]] = []
		for suite in root.findall("testsuite"):
			tests: list[dict[str, object]] = []
			for test in suite.findall("testcase"):
				tests.append({
					"name": test.attrib["name"],
					"was_run": True,
					"status": test.attrib["status"],
					"assertion_count": int(test.attrib["assertions"]),
					"duration_seconds": float(test.attrib["time"]),
				})
			test_duration = sum(float(test["duration_seconds"]) for test in tests)
			test_assertions = sum(int(test["assertion_count"]) for test in tests)
			scripts.append({
				"script": f"res://{suite.attrib['name']}",
				"inner_class": "",
				"was_run": True,
				"was_skipped": False,
				"duration_seconds": test_duration + 0.01,
				"assertion_count": test_assertions + lifecycle_assertions,
				"lifecycle_assertion_count": lifecycle_assertions,
				"tests": tests,
			})
		return {
			"schema_version": 1,
			"nonce": nonce,
			"junit_sha256": gut_sharding.hashlib.sha256(xml.encode("utf-8")).hexdigest(),
			"unfiltered": unfiltered,
			"script_count": len(scripts),
			"scripts": scripts,
		}

	@staticmethod
	def _junit_xml(suites: list[str]) -> str:
		test_count = sum(suite.count("<testcase ") for suite in suites)
		failure_count = sum(suite.count("<failure ") for suite in suites)
		return (
			'<?xml version="1.0" encoding="UTF-8"?>\n'
			f'<testsuites name="GutTests" failures="{failure_count}" '
			f'tests="{test_count}">\n'
			+ "\n".join(suites)
			+ "\n</testsuites>"
		)

	@staticmethod
	def _suite_xml(
		script: str,
		tests: list[str],
		*,
		failure_assertion_count: int | None = None,
		pending_assertion_count: int | None = None,
		declared_duration: str | None = None,
	) -> str:
		short_path = script.removeprefix("res://")
		test_count = len(tests)
		failure_count = (
			sum(test.count("<failure ") for test in tests)
			if failure_assertion_count is None
			else failure_assertion_count
		)
		skipped_count = (
			sum(test.count("<skipped ") for test in tests)
			if pending_assertion_count is None
			else pending_assertion_count
		)
		duration = sum(
			float(test.split(' time="', 1)[1].split('"', 1)[0])
			for test in tests
		)
		duration_text = declared_duration if declared_duration is not None else str(duration)
		return (
			f'<testsuite name="{short_path}" tests="{test_count}" '
			f'failures="{failure_count}" skipped="{skipped_count}" '
			f'time="{duration_text}">\n'
			+ "\n".join(tests)
			+ "\n</testsuite>"
		)

	@staticmethod
	def _test_xml(
		name: str,
		status: str,
		duration: str,
		*,
		assertions: str | None = "0",
		script: str | None = None,
	) -> str:
		result = ""
		if status == "fail":
			result = '<failure message="failed"><![CDATA[fixture failure]]></failure>'
		elif status == "pending":
			result = '<skipped message="pending"><![CDATA[fixture pending]]></skipped>'
		assertions_attribute = (
			f' assertions="{assertions}"' if assertions is not None else ""
		)
		classname = (
			script.removeprefix("res://")
			if script is not None
			else (
				"tests/gf_core/kernel/test_alpha.gd"
				if "alpha" in name or "passes" in name or "fails" in name
				else "tests/gf_core/standard/test_beta.gd"
			)
		)
		return (
			f'<testcase name="{name}"{assertions_attribute} status="{status}" '
			f'classname="{classname}" '
			f'time="{duration}">{result}</testcase>'
		)


if __name__ == "__main__":
	unittest.main()
