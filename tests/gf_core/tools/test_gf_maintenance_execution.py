#!/usr/bin/env python3
"""Focused behavioral tests for GF maintenance execution/protocol boundaries."""

from __future__ import annotations

import contextlib
import concurrent.futures
import copy
import hashlib
import inspect
import io
import json
import math
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest
import xml.etree.ElementTree as ET
from dataclasses import FrozenInstanceError
from dataclasses import replace
from pathlib import Path
from types import ModuleType
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
TOOLS_ROOT = ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
	sys.path.insert(0, str(TOOLS_ROOT))

import gdscript_lsp_diagnostics
import gf_executable_resolution
import gf_godot_process
import gf_gut_lifecycle_smoke
import gf_maintenance
import gf_maintenance_rendering
import gf_mcp_server
import gf_path_security
import gf_process_authority
import gf_process_supervisor
import gf_project_layout_profile
import gf_reference_manifest_reader
import gf_validation_catalog
import gf_validation_contracts
import gf_validation_inputs
import gf_workspace_snapshot


def _frozen_process_environment(
	environment: dict[str, str] | None = None,
) -> gf_process_authority.FrozenProcessEnvironment:
	return gf_process_authority.FrozenProcessEnvironment.capture(
		dict(os.environ) if environment is None else environment
	)


def _frozen_process_authority(
	environment: dict[str, str] | None = None,
) -> gf_process_authority.FrozenProcessAuthority:
	return gf_process_authority.freeze_process_authority(
		_frozen_process_environment(environment),
		cwd=ROOT,
	)


_SHARED_PROCESS_AUTHORITY = _frozen_process_authority()


def _fixture_process_lease_facade(
	*,
	deadline: float | None = None,
	backend: object | None = None,
) -> gf_process_supervisor.SupervisedProcessLease:
	started_at = time.perf_counter()
	lease_deadline = started_at + 5.0 if deadline is None else deadline
	backend = mock.Mock() if backend is None else backend
	backend.command = ("fixture",)
	backend.cwd = ROOT
	backend.started_at = started_at
	backend.deadline = lease_deadline
	backend.cleanup_reserve_seconds = 1.0
	backend.operation_deadline = lease_deadline - 1.0
	backend.pid = 7319
	return gf_process_supervisor.SupervisedProcessLease._from_backend(backend)


class FrozenProcessAuthorityTests(unittest.TestCase):
	def test_frozen_environment_owns_source_and_returned_values_by_value(self) -> None:
		source = {"PATH": "fixture-path", "GF_AUTHORITY_MARKER": "captured"}
		frozen = _frozen_process_environment(source)
		source["GF_AUTHORITY_MARKER"] = "source-mutated"
		returned = frozen.values()
		returned["GF_AUTHORITY_MARKER"] = "returned-mutated"

		self.assertEqual(frozen.values()["GF_AUTHORITY_MARKER"], "captured")

	def test_frozen_authority_ignores_later_ambient_mutation(self) -> None:
		with mock.patch.dict(
			os.environ,
			{"GF_AUTHORITY_AMBIENT_MARKER": "captured"},
			clear=False,
		):
			authority = _frozen_process_authority()
			os.environ["GF_AUTHORITY_AMBIENT_MARKER"] = "ambient-mutated"

			self.assertEqual(
				authority.environment.values()["GF_AUTHORITY_AMBIENT_MARKER"],
				"captured",
			)

	def test_git_authority_is_absolute_and_scrubs_ambient_git_control(self) -> None:
		source = {
			name: value
			for name, value in os.environ.items()
			if not name.upper().startswith("GIT_")
		}
		source.update({
			"GIT_DIR": "ambient-dir",
			"GIT_WORK_TREE": "ambient-tree",
			"GIT_ARBITRARY_AUTHORITY": "ambient-custom",
			"GIT_OPTIONAL_LOCKS": "1",
			"GIT_CONFIG_NOSYSTEM": "0",
			"GIT_TERMINAL_PROMPT": "1",
			"LC_ALL": "ambient-locale",
			"LANG": "ambient-language",
		})
		authority = _frozen_process_authority(source)
		git_environment = authority.git.environment.values()

		self.assertTrue(Path(authority.git.executable).is_absolute())
		self.assertEqual(
			{
				name: value
				for name, value in git_environment.items()
				if name.upper().startswith("GIT_")
			},
			{
				"GIT_OPTIONAL_LOCKS": "0",
				"GIT_CONFIG_NOSYSTEM": "1",
				"GIT_TERMINAL_PROMPT": "0",
			},
		)
		self.assertEqual(git_environment["LC_ALL"], "C")
		self.assertEqual(git_environment["LANG"], "C")

	def test_active_process_context_resets_every_capability_after_failure(self) -> None:
		previous_environment = gf_process_authority.active_process_environment()
		previous_authority = gf_process_authority.active_process_authority()
		previous_git = gf_process_authority.active_git_process()

		with self.assertRaisesRegex(RuntimeError, "fixture context failure"):
			with gf_process_authority.activate_process_context(
				_SHARED_PROCESS_AUTHORITY
			):
				self.assertIs(
					gf_process_authority.active_process_environment(),
					_SHARED_PROCESS_AUTHORITY.environment,
				)
				self.assertIs(
					gf_process_authority.active_process_authority(),
					_SHARED_PROCESS_AUTHORITY,
				)
				self.assertIs(
					gf_process_authority.active_git_process(),
					_SHARED_PROCESS_AUTHORITY.git,
				)
				raise RuntimeError("fixture context failure")

		self.assertIs(
			gf_process_authority.active_process_environment(),
			previous_environment,
		)
		self.assertIs(
			gf_process_authority.active_process_authority(),
			previous_authority,
		)
		self.assertIs(gf_process_authority.active_git_process(), previous_git)

	def test_process_authority_rejects_git_from_a_different_environment(self) -> None:
		mismatched_environment = _frozen_process_environment({
			**_SHARED_PROCESS_AUTHORITY.environment.values(),
			"GF_MISMATCHED_AUTHORITY": "different",
		})
		with self.assertRaisesRegex(
			ValueError,
			"not derived from the paired process environment",
		):
			gf_process_authority.FrozenProcessAuthority(
				environment=mismatched_environment,
				git=_SHARED_PROCESS_AUTHORITY.git,
			)


class MaintenanceInvocationAuthorityTests(unittest.TestCase):
	def test_nested_invocation_reuses_active_environment_and_rejects_replacement(self) -> None:
		active_authority = _SHARED_PROCESS_AUTHORITY
		replacement = _frozen_process_environment({
			**active_authority.environment.values(),
			"GF_NESTED_REPLACEMENT": "forbidden",
		})
		with gf_process_authority.activate_process_context(active_authority):
			self.assertIs(
				gf_maintenance.freeze_maintenance_invocation_environment(),
				active_authority.environment,
			)
			self.assertIs(
				gf_maintenance.freeze_maintenance_invocation_environment(
					active_authority.environment
				),
				active_authority.environment,
			)
			with self.assertRaisesRegex(ValueError, "cannot replace"):
				gf_maintenance.freeze_maintenance_invocation_environment(replacement)
			with gf_process_authority.activate_process_environment(replacement):
				with self.assertRaisesRegex(RuntimeError, "do not share one identity"):
					gf_maintenance.freeze_maintenance_invocation_environment()

	def test_reference_catalog_inputs_ignore_ambient_environment_and_filesystem(
		self,
	) -> None:
		frozen = _frozen_process_environment({
			gf_maintenance.REFERENCE_PROJECT_ENV_VAR: "frozen-reference",
		})
		with mock.patch.dict(
			os.environ,
			{
				gf_maintenance.REFERENCE_PROJECT_ENV_VAR: "ambient-reference",
				gf_maintenance.REFERENCE_BOOT_SCENE_ENV_VAR: "res://ambient_boot.tscn",
				gf_maintenance.REFERENCE_SMOKE_SCENE_ENV_VAR: "res://ambient_smoke.tscn",
			},
			clear=False,
		), mock.patch.object(
			gf_maintenance,
			"_read_reference_manifest_supervised",
			side_effect=AssertionError("Catalog input projection must not read files"),
		) as manifest_reader:
			inputs = gf_maintenance.reference_catalog_inputs(frozen)

		self.assertEqual(
			inputs,
			(
				"frozen-reference",
				gf_maintenance.DEFAULT_REFERENCE_BOOT_SCENE,
				gf_maintenance.DEFAULT_REFERENCE_SMOKE_SCENE,
			),
		)
		manifest_reader.assert_not_called()

	def test_invalid_reference_environment_values_use_stable_setup_envelope(
		self,
	) -> None:
		invalid_values = (
			(gf_maintenance.REFERENCE_PROJECT_ENV_VAR, ""),
			(gf_maintenance.REFERENCE_PROJECT_ENV_VAR, "C:relative"),
			(gf_maintenance.REFERENCE_PROJECT_ENV_VAR, "reference\nroot"),
			(
				gf_maintenance.REFERENCE_PROJECT_ENV_VAR,
				"x" * (
					gf_reference_manifest_reader.REFERENCE_PROJECT_MAX_CHARACTERS + 1
				),
			),
			(gf_maintenance.REFERENCE_BOOT_SCENE_ENV_VAR, ""),
			(gf_maintenance.REFERENCE_BOOT_SCENE_ENV_VAR, "relative.tscn"),
			(gf_maintenance.REFERENCE_BOOT_SCENE_ENV_VAR, "res://a/../b.tscn"),
			(gf_maintenance.REFERENCE_BOOT_SCENE_ENV_VAR, "res://a/line\nb.tscn"),
			(gf_maintenance.REFERENCE_BOOT_SCENE_ENV_VAR, "res://not-a-scene.txt"),
		)
		for variable_name, invalid_value in invalid_values:
			frozen = _frozen_process_environment({
				**dict(os.environ),
				variable_name: invalid_value,
			})
			with self.subTest(
				variable=variable_name,
				value=invalid_value[:32],
			), mock.patch.object(
				gf_maintenance,
				"maintenance_in_process_adapter_registry",
				side_effect=AssertionError(
					"invalid reference input must stop before registry construction"
				),
			) as registry, mock.patch.object(
				gf_maintenance.gf_process_supervisor,
				"run_supervised_process_bytes",
				side_effect=AssertionError(
					"invalid reference input must stop before manifest I/O"
				),
			) as manifest_process:
				report = gf_maintenance.run_checks(
					checks=["docs"],
					jobs=1,
					process_environment=frozen,
				)

			self.assertFalse(report["ok"])
			self.assertEqual(report["results"][0]["name"], "validation_executor_setup")
			self.assertEqual(
				report["results"][0]["stderr"],
				"Reference environment inputs are invalid.",
			)
			registry.assert_not_called()
			manifest_process.assert_not_called()

	def test_windows_reference_project_rejects_current_drive_root_syntax(self) -> None:
		with mock.patch.object(
			gf_reference_manifest_reader,
			"_NATIVE_OS_NAME",
			"nt",
		), self.assertRaises(
			gf_reference_manifest_reader.ReferenceManifestError
		) as raised:
			gf_reference_manifest_reader.validate_reference_project(
				"/current-drive-root"
			)

		self.assertEqual(
			raised.exception.rule_id,
			"reference_manifest.invalid_project_root",
		)

	def test_posix_reference_project_rejects_foreign_windows_absolute_syntax(
		self,
	) -> None:
		for foreign_path in (
			r"C:\reference-project",
			r"\\server\share\reference-project",
		):
			with self.subTest(path=foreign_path), mock.patch.object(
				gf_reference_manifest_reader,
				"_NATIVE_OS_NAME",
				"posix",
			), self.assertRaises(
				gf_reference_manifest_reader.ReferenceManifestError
			) as raised:
				gf_reference_manifest_reader.validate_reference_project(foreign_path)

			self.assertEqual(
				raised.exception.rule_id,
				"reference_manifest.invalid_project_root",
			)

	def test_static_catalog_uses_constants_without_environment_or_filesystem(self) -> None:
		with mock.patch.object(
			gf_maintenance,
			"capture_maintenance_process_environment",
			side_effect=AssertionError("static Catalog must not capture ambient environment"),
		), mock.patch.object(
			gf_maintenance,
			"reference_catalog_inputs",
			side_effect=AssertionError("static Catalog must not resolve invocation inputs"),
		) as reference_inputs, mock.patch.object(
			gf_maintenance,
			"validation_catalog_for_root",
			return_value=mock.sentinel.static_catalog,
		) as catalog_factory:
			actual = gf_maintenance._default_validation_catalog_for_root(ROOT)

		self.assertIs(actual, mock.sentinel.static_catalog)
		reference_inputs.assert_not_called()
		catalog_factory.assert_called_once_with(
			ROOT,
			default_reference_project=gf_maintenance.DEFAULT_REFERENCE_PROJECT,
			reference_boot_scene=gf_maintenance.DEFAULT_REFERENCE_BOOT_SCENE,
			reference_smoke_scene=gf_maintenance.DEFAULT_REFERENCE_SMOKE_SCENE,
		)

	def test_reference_manifest_reader_proves_missing_leaf_and_reads_valid_manifest(
		self,
	) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			reference_root = Path(temporary_directory).resolve()
			missing = gf_reference_manifest_reader.read_reference_manifest(
				reference_root
			)
			self.assertTrue(missing["ok"])
			self.assertFalse(missing["manifest_present"])
			self.assertIsNone(missing["boot_scene"])
			self.assertIsNone(missing["smoke_scene"])

			(reference_root / gf_maintenance.REFERENCE_MANIFEST_NAME).write_text(
				json.dumps({
					"boot_scene": "  res://manifest_boot.tscn  ",
					"smoke_scene": "res://manifest_smoke.tscn",
				}),
				encoding="utf-8",
			)
			present = gf_reference_manifest_reader.read_reference_manifest(
				reference_root
			)

		self.assertTrue(present["ok"])
		self.assertTrue(present["manifest_present"])
		self.assertEqual(present["boot_scene"], "res://manifest_boot.tscn")
		self.assertEqual(present["smoke_scene"], "res://manifest_smoke.tscn")

	def test_reference_manifest_reader_rejects_invalid_closed_schema_inputs(
		self,
	) -> None:
		invalid_payloads = (
			(b'{"boot_scene":"a","boot_scene":"b"}', "duplicate_key"),
			(b"[]", "invalid_top_level"),
			(b'{"unknown":"res://unknown.tscn"}', "unknown_key"),
			(b'{"boot_scene":false}', "invalid_scene"),
			(b'{"boot_scene":""}', "invalid_scene"),
			(b'{"boot_scene":"\\ud800"}', "invalid_scene"),
			(
				json.dumps({
					"smoke_scene": "x" * (
						gf_reference_manifest_reader.REFERENCE_SCENE_MAX_CHARACTERS + 1
					),
				}).encode("utf-8"),
				"invalid_scene",
			),
		)
		with tempfile.TemporaryDirectory() as temporary_directory:
			reference_root = Path(temporary_directory).resolve()
			manifest_path = reference_root / gf_maintenance.REFERENCE_MANIFEST_NAME
			for payload, expected_rule in invalid_payloads:
				with self.subTest(rule=expected_rule, payload=payload[:32]):
					manifest_path.write_bytes(payload)
					with self.assertRaises(
						gf_reference_manifest_reader.ReferenceManifestError
					) as raised:
						gf_reference_manifest_reader.read_reference_manifest(
							reference_root
						)
					self.assertEqual(
						raised.exception.rule_id,
						f"reference_manifest.{expected_rule}",
					)

			manifest_path.write_bytes(b"\xff")
			with self.assertRaises(gf_path_security.PinnedReadError) as invalid_utf8:
				gf_reference_manifest_reader.read_reference_manifest(reference_root)
			self.assertEqual(
				invalid_utf8.exception.rule_id,
				"path_security.invalid_utf8",
			)

			manifest_path.write_bytes(
				b" " * (gf_reference_manifest_reader.REFERENCE_MANIFEST_MAX_BYTES + 1)
			)
			with self.assertRaises(gf_path_security.PinnedReadError) as oversized:
				gf_reference_manifest_reader.read_reference_manifest(reference_root)
			self.assertEqual(
				oversized.exception.rule_id,
				"path_security.file_too_large",
			)

	def test_optional_manifest_missing_proof_rejects_chain_and_leaf_races(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			reference_root = Path(temporary_directory).resolve()
			manifest_path = reference_root / gf_maintenance.REFERENCE_MANIFEST_NAME
			with mock.patch.object(
				gf_path_security,
				"_directory_bindings_are_current",
				return_value=False,
			):
				with self.assertRaises(gf_path_security.PinnedReadError) as chain_changed:
					gf_path_security.read_optional_pinned_utf8_regular_file(
						reference_root,
						gf_maintenance.REFERENCE_MANIFEST_NAME,
						max_bytes=64 * 1024,
					)
			self.assertEqual(
				chain_changed.exception.rule_id,
				"path_security.chain_changed",
			)

			real_stat_path_entry = gf_path_security._stat_path_entry
			created = False

			def create_leaf_after_first_missing(
				path: Path,
				parent_descriptor: int,
			) -> os.stat_result:
				nonlocal created
				if path == manifest_path and not created:
					created = True
					manifest_path.write_text("{}", encoding="utf-8")
					raise FileNotFoundError
				return real_stat_path_entry(path, parent_descriptor)

			with mock.patch.object(
				gf_path_security,
				"_stat_path_entry",
				side_effect=create_leaf_after_first_missing,
			):
				with self.assertRaises(gf_path_security.PinnedReadError) as leaf_changed:
					gf_path_security.read_optional_pinned_utf8_regular_file(
						reference_root,
						gf_maintenance.REFERENCE_MANIFEST_NAME,
						max_bytes=64 * 1024,
					)
			self.assertEqual(
				leaf_changed.exception.rule_id,
				"path_security.file_changed",
			)

	def test_manifest_reader_cli_fails_closed_for_all_pinned_read_failures(self) -> None:
		for rule_id in (
			"path_security.file_unavailable",
			"path_security.boundary_invalid",
			"path_security.file_changed",
			"path_security.file_too_large",
		):
			with self.subTest(rule_id=rule_id), mock.patch.object(
				gf_reference_manifest_reader.gf_path_security,
				"read_optional_pinned_utf8_regular_file",
				side_effect=gf_path_security.PinnedReadError(rule_id),
			), mock.patch.object(
				gf_reference_manifest_reader,
				"_write_response",
			) as write_response:
				exit_code = gf_reference_manifest_reader.main([
					"--project-root",
					str(ROOT),
				])

			self.assertEqual(exit_code, 1)
			self.assertEqual(
				write_response.call_args.args[0],
				{
					"schema_version": 1,
					"ok": False,
					"error": "reference_manifest.read_failed",
				},
			)

	def test_manifest_reader_cli_does_not_swallow_memory_error(self) -> None:
		fatal = MemoryError("fixture reference manifest reader memory error")
		with (
			mock.patch.object(
				gf_reference_manifest_reader,
				"read_reference_manifest",
				side_effect=fatal,
			),
			mock.patch.object(
				gf_reference_manifest_reader,
				"_write_response",
			) as write_response,
			self.assertRaises(MemoryError) as raised,
		):
			gf_reference_manifest_reader.main([
				"--project-root",
				str(ROOT),
			])

		self.assertIs(raised.exception, fatal)
		write_response.assert_not_called()

	def test_non_scene_validation_plans_never_spawn_manifest_reader(self) -> None:
		plans = (
			("quick", ["docs"], 1),
			("full", None, 1),
			("examples", ["examples_sync"], 1),
		)
		for suite, checks, jobs in plans:
			with self.subTest(suite=suite, checks=checks), mock.patch.object(
				gf_maintenance.gf_process_supervisor,
				"run_supervised_process_bytes",
				side_effect=AssertionError("this validation plan does not need a manifest"),
			) as manifest_process, mock.patch.object(
				gf_maintenance,
				"maintenance_in_process_adapter_registry",
				return_value={},
			):
				report = gf_maintenance.run_checks(
					suite=suite,
					checks=checks,
					jobs=jobs,
				)

			self.assertFalse(report["ok"])
			self.assertEqual(report["results"][0]["name"], "validation_executor_setup")
			manifest_process.assert_not_called()

	def test_invalid_registry_precedes_requested_scene_manifest_io(self) -> None:
		frozen = _frozen_process_environment({
			**dict(os.environ),
			gf_maintenance.REFERENCE_PROJECT_ENV_VAR: str(ROOT),
		})
		with mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			return_value={},
		), mock.patch.object(
			gf_maintenance.gf_process_supervisor,
			"run_supervised_process_bytes",
			side_effect=AssertionError(
				"invalid executor registries must fail before manifest I/O"
			),
		) as manifest_process:
			report = gf_maintenance.run_checks(
				checks=["examples_boot"],
				jobs=1,
				process_environment=frozen,
			)

		self.assertFalse(report["ok"])
		self.assertEqual(report["results"][0]["name"], "validation_executor_setup")
		manifest_process.assert_not_called()

	def test_scene_environment_overrides_avoid_manifest_reader(self) -> None:
		frozen = _frozen_process_environment({
			**dict(os.environ),
			gf_maintenance.REFERENCE_PROJECT_ENV_VAR: str(ROOT),
			gf_maintenance.REFERENCE_BOOT_SCENE_ENV_VAR: "res://override_boot.tscn",
			gf_maintenance.REFERENCE_SMOKE_SCENE_ENV_VAR: "res://override_smoke.tscn",
		})
		with mock.patch.object(
			gf_maintenance.gf_process_supervisor,
			"run_supervised_process_bytes",
			side_effect=AssertionError("complete scene overrides must avoid manifest I/O"),
		) as manifest_process, mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			return_value={},
		):
			report = gf_maintenance.run_checks(
				suite="examples",
				jobs=1,
				process_environment=frozen,
			)

		self.assertFalse(report["ok"])
		self.assertEqual(report["results"][0]["name"], "validation_executor_setup")
		manifest_process.assert_not_called()

	def test_scene_plan_reads_manifest_once_and_rebuilds_catalog_from_result(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			reference_root = Path(temporary_directory).resolve()
			(reference_root / gf_maintenance.REFERENCE_MANIFEST_NAME).write_text(
				json.dumps({
					"boot_scene": "res://manifest_boot.tscn",
					"smoke_scene": "res://manifest_smoke.tscn",
				}),
				encoding="utf-8",
			)
			frozen = _frozen_process_environment({
				**dict(os.environ),
				gf_maintenance.REFERENCE_PROJECT_ENV_VAR: str(reference_root),
			})
			with mock.patch.object(
				gf_maintenance,
				"validation_catalog_for_root",
				wraps=gf_maintenance.validation_catalog_for_root,
			) as catalog_factory, mock.patch.object(
				gf_maintenance,
				"pin_godot_executable_selection",
				side_effect=gf_executable_resolution.EnvironmentNameAmbiguityError(
					"fixture stop after reference resolution"
				),
			):
				report = gf_maintenance.run_checks(
					suite="examples",
					jobs=1,
					suite_timeout_seconds=30,
					process_environment=frozen,
				)

		self.assertFalse(report["ok"])
		self.assertEqual(report["results"][0]["name"], "validation_environment_setup")
		self.assertEqual(catalog_factory.call_count, 2)
		self.assertEqual(
			catalog_factory.call_args.kwargs["reference_boot_scene"],
			"res://manifest_boot.tscn",
		)
		self.assertEqual(
			catalog_factory.call_args.kwargs["reference_smoke_scene"],
			"res://manifest_smoke.tscn",
		)

	def test_invalid_manifest_is_stable_executor_setup_failure(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			reference_root = Path(temporary_directory).resolve()
			(reference_root / gf_maintenance.REFERENCE_MANIFEST_NAME).write_bytes(
				b'{"boot_scene":"a","boot_scene":"b"}'
			)
			frozen = _frozen_process_environment({
				**dict(os.environ),
				gf_maintenance.REFERENCE_PROJECT_ENV_VAR: str(reference_root),
			})
			with mock.patch.object(
				gf_maintenance,
				"maintenance_in_process_adapter_registry",
				wraps=gf_maintenance.maintenance_in_process_adapter_registry,
			) as registry:
				report = gf_maintenance.run_checks(
					checks=["examples_boot"],
					jobs=1,
					suite_timeout_seconds=30,
					affected=True,
					process_environment=frozen,
				)

		self.assertFalse(report["ok"])
		self.assertEqual(report["results"][0]["name"], "validation_executor_setup")
		self.assertEqual(
			report["results"][0]["stderr"],
			"Reference manifest inputs could not be established.",
		)
		registry.assert_called_once()
		self.assertFalse(report["affected_analysis"]["report_ok"])
		self.assertEqual(
			report["affected_analysis"]["fallback_decision"],
			"execute",
		)

	def test_expired_suite_deadline_prevents_manifest_process_spawn(self) -> None:
		frozen = _frozen_process_environment({
			**dict(os.environ),
			gf_maintenance.REFERENCE_PROJECT_ENV_VAR: str(ROOT),
		})
		with mock.patch.object(
			gf_maintenance.gf_process_supervisor,
			"run_supervised_process_bytes",
		) as manifest_process, mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			wraps=gf_maintenance.maintenance_in_process_adapter_registry,
		) as registry:
			report = gf_maintenance.run_checks(
				checks=["examples_boot"],
				jobs=1,
				suite_timeout_seconds=0,
				affected=True,
				process_environment=frozen,
			)

		self.assertFalse(report["ok"])
		self.assertEqual(report["results"][0]["name"], "suite_deadline")
		self.assertTrue(report["results"][0]["timed_out"])
		manifest_process.assert_not_called()
		registry.assert_called_once()
		self.assertFalse(report["affected_analysis"]["report_ok"])
		self.assertEqual(report["affected_analysis"]["execute_count"], 3)

	def test_manifest_process_and_quiet_boundary_share_absolute_deadline(self) -> None:
		response = json.dumps({
			"schema_version": 1,
			"ok": True,
			"manifest_present": False,
			"boot_scene": None,
			"smoke_scene": None,
		}).encode("utf-8")
		process_result = gf_process_supervisor.SupervisedBinaryProcessResult(
			return_code=0,
			stdout=response,
			stderr=b"",
			timed_out=False,
			duration_seconds=0.01,
			pid=123,
			cleanup_complete=True,
		)
		frozen = _frozen_process_environment({
			**dict(os.environ),
			gf_maintenance.REFERENCE_PROJECT_ENV_VAR: str(ROOT),
		})
		with mock.patch.object(
			gf_maintenance.gf_process_supervisor,
			"run_supervised_process_bytes",
			return_value=process_result,
		) as manifest_process, mock.patch.object(
			gf_maintenance.gf_process_supervisor,
			"require_supervised_binary_quiet_boundary",
			wraps=gf_process_supervisor.require_supervised_binary_quiet_boundary,
		) as quiet_boundary, mock.patch.object(
			gf_maintenance,
			"pin_godot_executable_selection",
			side_effect=gf_executable_resolution.EnvironmentNameAmbiguityError(
				"fixture stop after reference resolution"
			),
		):
			report = gf_maintenance.run_checks(
				checks=["examples_boot"],
				jobs=1,
				suite_timeout_seconds=30,
				process_environment=frozen,
			)

		self.assertFalse(report["ok"])
		self.assertEqual(
			manifest_process.call_args.kwargs["deadline"],
			quiet_boundary.call_args.kwargs["deadline"],
		)
		self.assertLessEqual(manifest_process.call_args.kwargs["timeout_seconds"], 30.0)

	def test_manifest_process_cleanup_debt_escapes_with_identity(self) -> None:
		debt = gf_process_supervisor.SupervisedProcessCleanupError(
			"fixture manifest cleanup debt",
			pid=321,
			process_tree_empty=False,
		)
		frozen = _frozen_process_environment({
			**dict(os.environ),
			gf_maintenance.REFERENCE_PROJECT_ENV_VAR: str(ROOT),
		})
		with mock.patch.object(
			gf_maintenance.gf_process_supervisor,
			"run_supervised_process_bytes",
			side_effect=debt,
		), self.assertRaises(
			gf_process_supervisor.SupervisedProcessCleanupError
		) as raised:
			gf_maintenance.run_checks(
				checks=["examples_boot"],
				jobs=1,
				suite_timeout_seconds=30,
				process_environment=frozen,
			)

		self.assertIs(raised.exception, debt)

	def test_manifest_decode_crossing_original_deadline_is_deadline_failure(
		self,
	) -> None:
		response = json.dumps({
			"schema_version": 1,
			"ok": True,
			"manifest_present": False,
			"boot_scene": None,
			"smoke_scene": None,
		}).encode("utf-8")
		process_result = gf_process_supervisor.SupervisedBinaryProcessResult(
			return_code=0,
			stdout=response,
			stderr=b"",
			timed_out=False,
			duration_seconds=0.01,
			pid=123,
			cleanup_complete=True,
		)
		with (
			mock.patch.object(
				gf_maintenance.time,
				"perf_counter",
				side_effect=(100.0, 100.0, 100.0, 131.0),
			),
			mock.patch.object(
				gf_maintenance.gf_process_supervisor,
				"run_supervised_process_bytes",
				return_value=process_result,
			),
			self.assertRaises(gf_maintenance._ReferenceManifestDeadlineError),
		):
			gf_maintenance._read_reference_manifest_supervised(
				str(ROOT),
				_SHARED_PROCESS_AUTHORITY.environment.values(),
				deadline=130.0,
			)

	def test_manifest_response_checks_deadline_after_decode_parse_and_validation(
		self,
	) -> None:
		response = json.dumps({
			"schema_version": 1,
			"ok": True,
			"manifest_present": True,
			"boot_scene": "res://manifest_boot.tscn",
			"smoke_scene": "res://manifest_smoke.tscn",
		}).encode("utf-8")
		deadline_check = mock.Mock()

		decoded = gf_reference_manifest_reader.decode_success_response(
			response,
			deadline_check=deadline_check,
		)

		self.assertTrue(decoded["manifest_present"])
		self.assertEqual(deadline_check.call_count, 3)

	def test_manifest_process_does_not_swallow_fatal_or_control_flow_errors(
		self,
	) -> None:
		for fatal in (
			MemoryError("fixture manifest reader memory error"),
			GeneratorExit("fixture manifest reader generator exit"),
			KeyboardInterrupt("fixture manifest reader keyboard interrupt"),
			SystemExit(23),
		):
			with (
				self.subTest(error_type=type(fatal).__name__),
				mock.patch.object(
					gf_maintenance.gf_process_supervisor,
					"run_supervised_process_bytes",
					side_effect=fatal,
				),
				self.assertRaises(type(fatal)) as raised,
			):
				gf_maintenance._read_reference_manifest_supervised(
					str(ROOT),
					_SHARED_PROCESS_AUTHORITY.environment.values(),
					deadline=time.perf_counter() + 30.0,
				)

			self.assertIs(raised.exception, fatal)

	def test_run_checks_with_log_hygiene_reuses_one_frozen_log_policy(self) -> None:
		frozen = _frozen_process_environment({
			gf_maintenance.MAINTENANCE_KEEP_LOGS_ENV_VAR: "yes",
		})
		check_data = {"ok": True, "results": []}
		finalization = {"errors": []}
		with mock.patch.object(
			gf_maintenance,
			"freeze_maintenance_invocation_environment",
			return_value=frozen,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_log_snapshot",
			return_value=({}, []),
		), mock.patch.object(
			gf_maintenance,
			"run_checks",
			return_value=check_data,
		) as run_checks, mock.patch.object(
			gf_maintenance,
			"finalize_maintenance_log_session",
			return_value=finalization,
		) as finalize:
			actual = gf_maintenance.run_checks_with_log_hygiene()

		self.assertIs(actual, check_data)
		self.assertIs(run_checks.call_args.kwargs["process_environment"], frozen)
		self.assertTrue(finalize.call_args.kwargs["keep_logs"])

	def test_log_finalizer_cannot_mask_primary_cleanup_debt(self) -> None:
		primary = gf_process_supervisor.SupervisedProcessCleanupError(
			"fixture primary cleanup debt",
			pid=101,
			process_tree_empty=False,
		)
		secondary = RuntimeError("fixture log finalizer failure")
		with mock.patch.object(
			gf_maintenance,
			"maintenance_log_snapshot",
			return_value=({}, []),
		), mock.patch.object(
			gf_maintenance,
			"run_checks",
			side_effect=primary,
		), mock.patch.object(
			gf_maintenance,
			"finalize_maintenance_log_session",
			side_effect=secondary,
		), self.assertRaises(
			gf_process_supervisor.SupervisedProcessCleanupError
		) as raised:
			gf_maintenance.run_checks_with_log_hygiene(
				process_environment=_frozen_process_environment()
			)

		self.assertIs(raised.exception, primary)
		self.assertIs(raised.exception.__context__, secondary)
		self.assertTrue(gf_process_supervisor.exception_has_cleanup_debt(raised.exception))

	def test_secondary_log_cleanup_debt_is_not_downgraded(self) -> None:
		primary = RuntimeError("fixture primary maintenance failure")
		secondary = gf_process_supervisor.SupervisedProcessCleanupError(
			"fixture secondary cleanup debt",
			pid=102,
			process_tree_empty=False,
		)
		with mock.patch.object(
			gf_maintenance,
			"maintenance_log_snapshot",
			return_value=({}, []),
		), mock.patch.object(
			gf_maintenance,
			"run_checks",
			side_effect=primary,
		), mock.patch.object(
			gf_maintenance,
			"finalize_maintenance_log_session",
			side_effect=secondary,
		), self.assertRaises(
			gf_process_supervisor.SupervisedProcessCleanupError
		) as raised:
			gf_maintenance.run_checks_with_log_hygiene(
				process_environment=_frozen_process_environment()
			)

		self.assertIs(raised.exception, secondary)
		self.assertIs(raised.exception.__cause__, primary)

	def test_log_policy_rejects_windows_folded_conflicts_before_log_work(self) -> None:
		frozen = _frozen_process_environment({
			gf_maintenance.MAINTENANCE_KEEP_LOGS_ENV_VAR: "yes",
			gf_maintenance.MAINTENANCE_KEEP_LOGS_ENV_VAR.lower(): "no",
		})
		real_environment_value = gf_executable_resolution.frozen_environment_value

		def windows_environment_value(
			environment: dict[str, str],
			name: str,
		) -> str | None:
			return real_environment_value(
				environment,
				name,
				platform_name="nt",
			)

		with mock.patch.object(
			gf_maintenance,
			"frozen_environment_value",
			side_effect=windows_environment_value,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_log_snapshot",
		) as snapshot, mock.patch.object(
			gf_maintenance,
			"run_checks",
		) as run_checks, mock.patch.object(
			gf_maintenance,
			"finalize_maintenance_log_session",
		) as finalize:
			with self.assertRaises(
				gf_executable_resolution.EnvironmentNameAmbiguityError
			):
				gf_maintenance.run_checks_with_log_hygiene(
					process_environment=frozen
				)

		snapshot.assert_not_called()
		run_checks.assert_not_called()
		finalize.assert_not_called()

	def test_cli_keep_logs_uses_the_entry_frozen_environment(self) -> None:
		entry_values = {
			"PATH": os.environ.get("PATH", ""),
			gf_maintenance.MAINTENANCE_KEEP_LOGS_ENV_VAR: "on",
		}

		def run_main() -> int:
			active = gf_process_authority.active_process_environment()
			self.assertIsNotNone(active)
			self.assertEqual(
				active.values()[gf_maintenance.MAINTENANCE_KEEP_LOGS_ENV_VAR],
				"on",
			)
			os.environ[gf_maintenance.MAINTENANCE_KEEP_LOGS_ENV_VAR] = "off"
			return 0

		with mock.patch.object(
			gf_maintenance,
			"capture_maintenance_process_environment",
			return_value=entry_values,
		), mock.patch.object(
			sys,
			"argv",
			["gf_maintenance.py", "check"],
		), mock.patch.object(
			gf_maintenance,
			"main",
			side_effect=run_main,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_log_snapshot",
			return_value=({}, []),
		), mock.patch.object(
			gf_maintenance,
			"finalize_maintenance_log_session",
			return_value={"errors": []},
		) as finalize, mock.patch.dict(os.environ, {}, clear=False):
			exit_code = gf_maintenance.run_main_with_log_hygiene()

		self.assertEqual(exit_code, 0)
		self.assertTrue(finalize.call_args.kwargs["keep_logs"])

	def test_cli_log_finalizer_cannot_mask_primary_control_flow_or_hide_debt(
		self,
	) -> None:
		original_argv = ["gf_maintenance.py", "check"]
		primary = KeyboardInterrupt("fixture primary CLI interruption")
		secondary = gf_process_supervisor.SupervisedProcessCleanupError(
			"fixture CLI finalizer cleanup debt",
			pid=103,
			process_tree_empty=False,
		)
		with mock.patch.object(
			gf_maintenance,
			"capture_maintenance_process_environment",
			return_value={"PATH": os.environ.get("PATH", "")},
		), mock.patch.object(
			sys,
			"argv",
			original_argv,
		), mock.patch.object(
			gf_maintenance,
			"main",
			side_effect=primary,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_log_snapshot",
			return_value=({}, []),
		), mock.patch.object(
			gf_maintenance,
			"finalize_maintenance_log_session",
			side_effect=secondary,
		), self.assertRaises(KeyboardInterrupt) as raised:
			gf_maintenance.run_main_with_log_hygiene()

		self.assertIs(raised.exception, primary)
		self.assertIs(raised.exception.__context__, secondary)
		self.assertTrue(gf_process_supervisor.exception_has_cleanup_debt(raised.exception))

	def test_package_builder_relative_paths_require_explicit_builder_cwd(self) -> None:
		artifact_module = gf_maintenance.gf_package_artifact_set
		with tempfile.TemporaryDirectory() as temporary_directory:
			builder_cwd = Path(temporary_directory).resolve()
			artifact_root = builder_cwd / "artifact"
			archive_path = artifact_root / "packages" / "gf.fixture.zip"
			archive_path.parent.mkdir(parents=True)
			archive_path.write_bytes(b"fixture-package")
			path_prefix = artifact_root.relative_to(builder_cwd).as_posix()
			builder_data = {
				"ok": True,
				"issues": [],
				"package_count": 1,
				"output_dir": f"{path_prefix}/packages",
				"registry": f"{path_prefix}/{artifact_module.REGISTRY_RELATIVE_PATH}",
				"registry_source": (
					f"{path_prefix}/{artifact_module.REGISTRY_SOURCE_RELATIVE_PATH}"
				),
				"offline_bundle": (
					f"{path_prefix}/{artifact_module.OFFLINE_BUNDLE_RELATIVE_PATH}"
				),
				"packages": [{
					"id": "gf.fixture",
					"kind": "kernel",
					"ok": True,
					"issues": [],
					"archive": f"{path_prefix}/packages/{archive_path.name}",
					"size_bytes": archive_path.stat().st_size,
					"sha256": hashlib.sha256(archive_path.read_bytes()).hexdigest(),
				}],
			}
			root_relative_builder_data = copy.deepcopy(builder_data)
			root_relative_builder_data.update({
				"output_dir": "packages",
				"registry": artifact_module.REGISTRY_RELATIVE_PATH,
				"registry_source": artifact_module.REGISTRY_SOURCE_RELATIVE_PATH,
				"offline_bundle": artifact_module.OFFLINE_BUNDLE_RELATIVE_PATH,
			})
			root_relative_builder_data["packages"][0]["archive"] = (
				f"packages/{archive_path.name}"
			)
			with mock.patch.object(
				artifact_module.Path,
				"cwd",
				return_value=builder_cwd,
			) as ambient_cwd:
				with self.assertRaises(TypeError):
					artifact_module.assemble_package_artifact_inputs(
						artifact_root,
						builder_data,
					)
				with self.assertRaisesRegex(
					artifact_module.PackageArtifactSetError,
					"cwd is required",
				):
					artifact_module.assemble_package_artifact_inputs(
						artifact_root,
						builder_data,
						builder_cwd=None,
					)
				with self.assertRaisesRegex(
					artifact_module.PackageArtifactSetError,
					"does not point at the artifact root layout",
				):
					artifact_module.assemble_package_artifact_inputs(
						artifact_root,
						root_relative_builder_data,
						builder_cwd=builder_cwd,
					)
				inputs = artifact_module.assemble_package_artifact_inputs(
					artifact_root,
					builder_data,
					builder_cwd=builder_cwd,
				)

			ambient_cwd.assert_not_called()
			self.assertIn(
				artifact_module.REGISTRY_RELATIVE_PATH,
				{item.relative_path for item in inputs},
			)
			self.assertIn(
				f"packages/{archive_path.name}",
				{item.relative_path for item in inputs},
			)

	def test_package_artifact_producer_passes_the_exact_subprocess_cwd_to_sealer(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory).resolve()
			artifact_root = root / "artifact"
			source_root = root / "source"
			process_environment = _frozen_process_environment()
			sealed = mock.Mock()
			completed = subprocess.CompletedProcess(
				args=["fixture-builder"],
				returncode=0,
				stdout="{}",
				stderr="",
			)
			with mock.patch.object(
				gf_maintenance,
				"run_maintenance_subprocess",
				return_value=completed,
			) as run_builder, mock.patch.object(
				gf_maintenance.gf_package_artifact_set,
				"seal_package_artifact_set",
				return_value=sealed,
			) as seal:
				actual = gf_maintenance.build_package_smoke_artifact_set(
					artifact_root,
					{"fixture": True},
					process_environment=process_environment,
					source_root=source_root,
				)

		self.assertIs(actual, sealed)
		self.assertEqual(run_builder.call_args.kwargs["cwd"], source_root)
		self.assertIs(
			run_builder.call_args.kwargs["process_environment"],
			process_environment,
		)
		self.assertEqual(seal.call_args.kwargs["builder_cwd"], source_root)


def _remove_directory_link_fixture(path: Path) -> None:
	if not os.path.lexists(path):
		return
	if os.name == "nt":
		os.rmdir(path)
	else:
		path.unlink()


def _full_validation_plan() -> gf_validation_catalog.ValidationPlan:
	return gf_maintenance._VALIDATION_CATALOG.plan("full")


def _in_process_adapter_registry_with(
	**overrides: object,
) -> dict[str, object]:
	registry: dict[str, object] = dict(
		gf_maintenance.maintenance_in_process_adapter_registry()
	)
	registry.update(overrides)
	return registry


def _deferred_command_materializer_registry_for(
	catalog: gf_validation_catalog.ValidationCatalog,
	**overrides: object,
) -> dict[str, object]:
	registry: dict[str, object] = {
		name: (lambda _context, action_name=name: ("fixture-python", action_name))
		for name in catalog.deferred_action_names
	}
	registry.update(overrides)
	return registry


def _validation_executor_binding(
	catalog: gf_validation_catalog.ValidationCatalog,
	in_process_adapters: object,
	deferred_command_materializers: object | None = None,
) -> gf_maintenance.ValidationExecutorBinding:
	return gf_maintenance.validate_validation_executor_registries(
		catalog,
		in_process_adapters,
		(
			_deferred_command_materializer_registry_for(catalog)
			if deferred_command_materializers is None
			else deferred_command_materializers
		),
	)


def _synthetic_parallel_shard_plan(
	name: str,
	checks: tuple[str, ...],
	execution_checks: tuple[str, ...] | None = None,
) -> gf_maintenance.ParallelCheckShardPlan:
	return gf_maintenance.ParallelCheckShardPlan(
		name,
		checks,
		execution_checks if execution_checks is not None else checks,
	)


def _synthetic_full_validation_plan(
	plans: list[gf_maintenance.ParallelCheckShardPlan],
	*,
	dependencies: dict[str, tuple[str, ...]] | None = None,
) -> gf_validation_catalog.ValidationPlan:
	actions = tuple(dict.fromkeys(
		action
		for plan in plans
		for action in plan.execution_checks
	))
	return gf_validation_catalog.ValidationPlan(
		suite="full",
		requested_actions=actions,
		actions=actions,
		check_graph=gf_validation_catalog.CheckGraph(actions, dependencies or {}),
		lanes=(),
	)


def _self_test_namespace_fixture() -> dict[str, object]:
	global fixture_marker
	original_hook = globals()["fixture_hook"]
	original_marker = fixture_marker
	try:
		globals()["fixture_hook"] = lambda: "patched"
		fixture_marker = "mutated"
		return {
			"hook": fixture_hook(),
			"marker": fixture_marker,
			"module_name": __name__,
		}
	finally:
		globals()["fixture_hook"] = original_hook
		fixture_marker = original_marker


class MaintenanceSelfTestModuleTests(unittest.TestCase):
	def test_maintenance_import_keeps_large_self_test_module_lazy(self) -> None:
		completed = subprocess.run(
			[
				sys.executable,
				"-c",
				(
					"import sys; "
					f"sys.path.insert(0, {str(TOOLS_ROOT)!r}); "
					"import gf_maintenance; "
					"raise SystemExit(int('gf_maintenance_self_test' in sys.modules))"
				),
			],
			cwd=ROOT,
			capture_output=True,
			check=False,
			timeout=10.0,
		)
		self.assertEqual(
			completed.returncode,
			0,
			completed.stderr.decode("utf-8", "replace"),
		)

	def test_maintenance_self_test_delegates_the_live_runtime_module(self) -> None:
		import gf_maintenance_self_test

		expected = {"ok": True, "tests": []}
		with mock.patch.object(
			gf_maintenance_self_test,
			"run_maintenance_self_test",
			return_value=expected,
		) as runner:
			self.assertIs(gf_maintenance.maintenance_self_test(), expected)
		runner.assert_called_once_with(gf_maintenance)

	def test_white_box_runner_preserves_live_global_fixture_semantics(self) -> None:
		import gf_maintenance_self_test

		runtime = ModuleType("fixture_runtime")
		original_hook = lambda: "original"
		runtime.fixture_hook = original_hook
		runtime.fixture_marker = "original"
		result = gf_maintenance_self_test._run_in_module_namespace(
			runtime,
			_self_test_namespace_fixture,
		)

		self.assertEqual(
			result,
			{
				"hook": "patched",
				"marker": "mutated",
				"module_name": "fixture_runtime",
			},
		)
		self.assertIs(runtime.fixture_hook, original_hook)
		self.assertEqual(runtime.fixture_marker, "original")

	def test_maintenance_self_test_cli_preserves_json_and_exit_contract(self) -> None:
		for ok, expected_exit_code in ((True, 0), (False, 1)):
			payload = {
				"ok": ok,
				"root": str(ROOT),
				"test_count": 1,
				"failure_count": 0 if ok else 1,
				"tests": [{"name": "fixture", "passed": ok}],
				"failures": [] if ok else [{"name": "fixture", "passed": False}],
			}
			stdout = io.StringIO()
			with self.subTest(ok=ok), mock.patch.object(
				gf_maintenance,
				"maintenance_self_test",
				return_value=payload,
			), mock.patch.object(
				sys,
				"argv",
				["gf_maintenance.py", "maintenance-self-test", "--json"],
			), contextlib.redirect_stdout(stdout):
				exit_code = gf_maintenance.main()

			self.assertEqual(exit_code, expected_exit_code)
			self.assertEqual(
				stdout.getvalue(),
				gf_maintenance_rendering.encode_strict_json(
					payload,
					indent=2,
					trailing_newline=True,
				),
			)


class ValidationCatalogContractTests(unittest.TestCase):
	_AUTHORITY_SNAPSHOT_SHA256 = (
		"078ad76c3f4de5525fb7b1564ab588d30bf6ab8e3588fa20ee6a14be664bc733"
	)
	_PRE_MIGRATION_EXECUTOR_PROJECTION_SHA256 = (
		"85f24f2287735a812ef48ffe8b91489365dd0bbd06a7c24c8a8457280c32f346"
	)

	def test_default_catalog_matches_authority_snapshot_exactly(self) -> None:
		catalog = gf_validation_catalog.build_validation_catalog(
			self._snapshot_context()
		)
		commands = catalog.command_definitions()
		snapshot = {
			"actions": [
				[name, self._normalize_snapshot_value(commands.get(name))]
				for name in catalog.action_names
			],
			"input_specs": [
				self._normalize_snapshot_value(spec.to_dict())
				for spec in catalog.input_specs
			],
			"dependencies": [
				[name, dependencies]
				for name, dependencies in catalog.dependencies().items()
			],
			"groups": [
				[name, actions]
				for name, actions in catalog.check_groups().items()
			],
			"suites": [
				[name, actions]
				for name, actions in catalog.suites().items()
			],
			"lanes": list(catalog.parallel_full_shard_suites),
		}
		encoded = json.dumps(
			snapshot,
			sort_keys=False,
			separators=(",", ":"),
			ensure_ascii=True,
		).encode("ascii")

		self.assertEqual(
			hashlib.sha256(encoded).hexdigest(),
			self._AUTHORITY_SNAPSHOT_SHA256,
			"Catalog declarations changed from the reviewed process-authority baseline.",
		)
		self.assertEqual(
			(
				len(snapshot["actions"]),
				len(snapshot["input_specs"]),
				len(snapshot["dependencies"]),
				len(snapshot["groups"]),
				len(snapshot["suites"]),
				len(snapshot["lanes"]),
			),
			(57, 3, 9, 22, 20, 8),
		)
		self.assertEqual(
			[name for name in catalog.action_names if name not in commands],
			["release_metadata"],
		)

	def test_default_catalog_owns_exactly_the_three_affected_input_specs(self) -> None:
		catalog = gf_validation_catalog.build_validation_catalog(
			self._snapshot_context()
		)
		expected_names = (
			"public_docs_boundary",
			"public_api_boundary",
			"package_user_dependency_boundary",
		)

		self.assertIs(type(catalog.input_specs), tuple)
		self.assertEqual(
			tuple(spec.check_name for spec in catalog.input_specs),
			expected_names,
		)
		for spec in catalog.input_specs:
			with self.subTest(action_name=spec.check_name):
				self.assertIsInstance(
					spec,
					gf_validation_contracts.CheckInputSpec,
				)
				self.assertIs(catalog.input_spec(spec.check_name), spec)
		for action_name in catalog.action_names:
			if action_name not in expected_names:
				with self.subTest(undeclared_action_name=action_name):
					self.assertIsNone(catalog.input_spec(action_name))

	def test_context_materialization_is_isolated(self) -> None:
		first = gf_validation_catalog.build_validation_catalog(
			self._context("first")
		)
		first_before = first.command_definitions()
		second = gf_validation_catalog.build_validation_catalog(
			self._context("second")
		)
		first_after = first.command_definitions()
		second_commands = second.command_definitions()

		self.assertEqual(first_after, first_before)
		self.assertEqual(
			first_before["godot_import"][3],
			"<log-first>/godot_import.log",
		)
		self.assertEqual(
			second_commands["godot_import"][3],
			"<log-second>/godot_import.log",
		)
		self.assertEqual(first_before["gut_lifecycle_smoke"][0], "<python-first>")
		self.assertEqual(second_commands["gut_lifecycle_smoke"][0], "<python-second>")
		self.assertIn("-ghook=first", first_before["gut"])
		self.assertIn("-ghook=second", second_commands["gut"])
		self.assertEqual(
			first_before["mkdocs"][-1],
			(ROOT / "first" / "ai_analysis/mkdocs_site").as_posix(),
		)
		self.assertIn("<reference-first>", first_before["examples_sync"])
		self.assertEqual(first_before["examples_boot"][-1], "<boot-first>")
		self.assertEqual(first_before["examples_smoke"][-1], "<smoke-first>")

	def test_captured_catalog_projects_only_root_bound_static_commands(self) -> None:
		source_context = self._context("source")
		catalog = gf_validation_catalog.build_validation_catalog(source_context)
		target_root = ROOT / "projected-root"
		target_log_directory = target_root / "ai_analysis" / "godot_logs"

		projected = catalog.project_static_commands(
			root=target_root,
			godot_log_directory=target_log_directory,
		)
		expected = gf_validation_catalog.build_validation_catalog(
			replace(
				source_context,
				root=target_root,
				godot_log_directory=target_log_directory,
			)
		).command_definitions()

		self.assertEqual(projected, expected)
		self.assertEqual(
			projected["gut_lifecycle_smoke"][0],
			source_context.python_executable,
		)

	def test_catalog_timeout_policy_matches_pre_migration_runner_values(self) -> None:
		catalog = gf_validation_catalog.build_validation_catalog(
			self._snapshot_context()
		)
		expected_overrides = {
			"gut": 1200,
			"gdscript_lsp_diagnostics": 660,
			"gut_lifecycle_smoke": 360,
			"ai_developer_adapter_acceptance": 900,
			"package_editor_wizard_smoke": 1200,
			"package_godot_cli_smoke": 2400,
			"package_godot_cli_local_smoke": 1200,
			"package_godot_cli_network_smoke": 1200,
			"package_godot_matrix_smoke": 2400,
		}

		self.assertEqual(catalog.default_timeout_seconds, 600)
		self.assertEqual(catalog.timeout_overrides(), expected_overrides)
		self.assertEqual(catalog.timeout_floor_seconds("api"), 600)
		for action_name, timeout_seconds in expected_overrides.items():
			with self.subTest(action=action_name):
				self.assertEqual(
					catalog.timeout_floor_seconds(action_name),
					timeout_seconds,
				)

	def test_catalog_executor_policy_matches_pre_migration_runner_values(self) -> None:
		catalog = gf_validation_catalog.build_validation_catalog(
			self._snapshot_context()
		)
		expected_in_process_actions = (
			"api",
			"ai_api",
			"docs",
			"changelog_policy",
			"codeql_suppression_policy",
			"public_docs_boundary",
			"public_api_boundary",
			"resource_boundary",
			"content_package_boundary",
			"asset_lifecycle_boundary",
			"project_profile_boundary",
			"package_boundary",
			"package_closure_audit",
			"package_source_boundary",
			"package_user_dependency_boundary",
			"package_external_command_audit",
			"core_only_smoke",
			"package_focused_gut_mapping",
			"api_since_touched",
			"path_hygiene",
			"dependency_boundary",
			"maintenance_self_test",
			"project_settings_drift",
		)
		encoded = json.dumps(
			[
				[action_name, catalog.executor_kind(action_name).value]
				for action_name in catalog.action_names
			],
			ensure_ascii=True,
			separators=(",", ":"),
		).encode("ascii")
		executor_kinds = [
			catalog.executor_kind(action_name)
			for action_name in catalog.action_names
		]

		self.assertEqual(
			hashlib.sha256(encoded).hexdigest(),
			self._PRE_MIGRATION_EXECUTOR_PROJECTION_SHA256,
		)
		self.assertTrue(all(isinstance(kind, str) for kind in executor_kinds))
		self.assertTrue(all(str(kind) == kind.value for kind in executor_kinds))
		self.assertTrue(all(format(kind) == kind.value for kind in executor_kinds))
		self.assertTrue(all(f"{kind}" == kind.value for kind in executor_kinds))
		self.assertTrue(all(
			json.dumps(kind) == json.dumps(kind.value)
			for kind in executor_kinds
		))
		self.assertEqual(catalog.in_process_action_names, expected_in_process_actions)
		self.assertEqual(catalog.deferred_action_names, ("release_metadata",))
		self.assertEqual(
			[
				action_name
				for action_name in catalog.action_names
				if catalog.executor_kind(action_name)
				is gf_validation_catalog.ValidationExecutorKind.IN_PROCESS
			],
			list(expected_in_process_actions),
		)
		self.assertEqual(
			sum(
				catalog.executor_kind(action_name)
				is gf_validation_catalog.ValidationExecutorKind.SUBPROCESS
				for action_name in catalog.action_names
			),
			34,
		)
		self.assertEqual(
			sum(
				catalog.executor_kind(action_name)
				is gf_validation_catalog.ValidationExecutorKind.IN_PROCESS
				for action_name in catalog.plan("full").actions
			),
			22,
		)
		self.assertIs(
			catalog.executor_kind("release_metadata"),
			gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
		)

	def test_runner_legacy_projections_come_from_catalog(self) -> None:
		catalog = gf_maintenance._VALIDATION_CATALOG
		legacy_groups = {
			"api": gf_maintenance.API_CHECKS,
			"docs": gf_maintenance.DOCS_CHECKS,
			"examples": gf_maintenance.EXAMPLES_CHECKS,
			"light_boundary": gf_maintenance.LIGHT_BOUNDARY_CHECKS,
			"package_contract_smoke": gf_maintenance.PACKAGE_CONTRACT_SMOKE_CHECKS,
			"package_editor": gf_maintenance.PACKAGE_EDITOR_CHECKS,
			"package_cli_local": gf_maintenance.PACKAGE_CLI_LOCAL_CHECKS,
			"package_cli_network": gf_maintenance.PACKAGE_CLI_NETWORK_CHECKS,
			"package_cli": gf_maintenance.PACKAGE_CLI_CHECKS,
			"package_smoke": gf_maintenance.PACKAGE_SMOKE_CHECKS,
			"package_contract": gf_maintenance.PACKAGE_CONTRACT_CHECKS,
			"package": gf_maintenance.PACKAGE_CHECKS,
			"quick": gf_maintenance.QUICK_CHECKS,
			"full": gf_maintenance.FULL_CHECKS,
			"release": gf_maintenance.RELEASE_CHECKS,
			"framework_gut": gf_maintenance.FRAMEWORK_GUT_CHECKS,
			"framework_lsp": gf_maintenance.FRAMEWORK_LSP_CHECKS,
			"framework_static": gf_maintenance.FRAMEWORK_STATIC_CHECKS,
			"framework": gf_maintenance.FRAMEWORK_CHECKS,
			"package_ci": gf_maintenance.PACKAGE_CI_CHECKS,
			"package_release": gf_maintenance.PACKAGE_RELEASE_CHECKS,
		}

		self.assertEqual(gf_maintenance.CHECK_DEFINITIONS, catalog.command_definitions())
		self.assertEqual(gf_maintenance.VALIDATION_ACTION_NAMES, catalog.action_names)
		self.assertEqual(gf_maintenance.CHECK_DEPENDENCIES, catalog.dependencies())
		for name, actions in legacy_groups.items():
			with self.subTest(group=name):
				self.assertEqual(actions, catalog.check_group(name))
		self.assertEqual(
			gf_maintenance.PACKAGE_ARTIFACT_CONSUMER_CHECKS,
			frozenset(catalog.check_group("package_artifact_consumers")),
		)
		self.assertEqual(gf_maintenance.CHECK_SUITES, catalog.suites())
		self.assertEqual(
			gf_maintenance.PARALLEL_FULL_SHARD_SUITES,
			catalog.parallel_full_shard_suites,
		)
		self.assertIs(gf_maintenance.maintenance_check_graph(), catalog.check_graph)
		self.assertEqual(catalog.check_graph.expand(["release_metadata"]), ["release_metadata"])
		self.assertNotIn("release_metadata", gf_maintenance.CHECK_DEFINITIONS)
		self.assertIsNot(gf_maintenance.CHECK_SUITES["api"], gf_maintenance.API_CHECKS)
		adapter_registry = gf_maintenance.maintenance_in_process_adapter_registry()
		materializer_registry = (
			gf_maintenance.maintenance_deferred_command_materializer_registry()
		)
		self.assertEqual(
			tuple(adapter_registry),
			catalog.in_process_action_names,
		)
		self.assertEqual(
			tuple(materializer_registry),
			catalog.deferred_action_names,
		)
		binding = gf_maintenance.validate_validation_executor_registries(
			catalog,
			adapter_registry,
			materializer_registry,
		)
		self.assertEqual(
			tuple(binding.in_process_adapters),
			catalog.in_process_action_names,
		)
		self.assertEqual(
			tuple(binding.deferred_command_materializers),
			catalog.deferred_action_names,
		)

	def test_reference_catalog_resolution_reuses_exact_frozen_callable_mappings(
		self,
	) -> None:
		provisional = gf_maintenance.validation_catalog_for_root(ROOT)
		resolved_boot_scene = "res://verified/manifest_boot.tscn"
		resolved = gf_maintenance.validation_catalog_for_root(
			ROOT,
			reference_boot_scene=resolved_boot_scene,
		)
		binding = gf_maintenance.validate_validation_executor_registries(
			provisional,
			gf_maintenance.maintenance_in_process_adapter_registry(),
			gf_maintenance.maintenance_deferred_command_materializer_registry(),
		)
		provisional_plan = provisional.plan("examples", ["examples_boot"])
		resolved_plan = resolved.plan("examples", ["examples_boot"])

		gf_maintenance.validate_resolved_reference_catalog(
			provisional,
			resolved,
			provisional_plan=provisional_plan,
			resolved_plan=resolved_plan,
			allowed_scene_changes={
				"examples_boot": (
					gf_maintenance.DEFAULT_REFERENCE_BOOT_SCENE,
					resolved_boot_scene,
				),
			},
		)
		rebound = gf_maintenance.rebind_frozen_validation_executors(
			resolved,
			binding,
		)

		self.assertIs(rebound.in_process_adapters, binding.in_process_adapters)
		self.assertIs(
			rebound.deferred_command_materializers,
			binding.deferred_command_materializers,
		)

	def test_reference_catalog_resolution_rejects_unapproved_command_change(
		self,
	) -> None:
		provisional = gf_maintenance.validation_catalog_for_root(ROOT)
		resolved = gf_maintenance.validation_catalog_for_root(
			ROOT,
			reference_boot_scene="res://verified/manifest_boot.tscn",
			reference_smoke_scene="res://unrequested/manifest_smoke.tscn",
		)
		provisional_plan = provisional.plan("examples", ["examples_boot"])
		resolved_plan = resolved.plan("examples", ["examples_boot"])

		with self.assertRaisesRegex(
			gf_validation_catalog.ValidationCatalogError,
			"unapproved command argument",
		):
			gf_maintenance.validate_resolved_reference_catalog(
				provisional,
				resolved,
				provisional_plan=provisional_plan,
				resolved_plan=resolved_plan,
				allowed_scene_changes={
					"examples_boot": (
						gf_maintenance.DEFAULT_REFERENCE_BOOT_SCENE,
						"res://verified/manifest_boot.tscn",
					),
				},
			)

	def test_reference_catalog_resolution_rejects_timeout_authority_drift(
		self,
	) -> None:
		provisional = gf_maintenance.validation_catalog_for_root(ROOT)
		drifted = gf_validation_catalog.ValidationCatalog(
			actions=(
				(
					name,
					provisional.static_command(name),
					provisional.executor_kind(name),
				)
				for name in provisional.action_names
			),
			input_specs=provisional.input_specs,
			dependencies=(
				(name, dependencies)
				for name, dependencies in provisional.dependencies().items()
			),
			check_groups=(
				(name, actions)
				for name, actions in provisional.check_groups().items()
			),
			suites=(
				(name, actions)
				for name, actions in provisional.suites().items()
			),
			parallel_full_shard_suites=provisional.parallel_full_shard_suites,
			default_timeout_seconds=provisional.default_timeout_seconds + 1,
			timeout_overrides=provisional.timeout_overrides().items(),
			command_projection_context=provisional.command_projection_context,
		)

		with self.assertRaisesRegex(
			gf_validation_catalog.ValidationCatalogError,
			"non-command authority",
		):
			gf_maintenance.validate_resolved_reference_catalog(
				provisional,
				drifted,
				provisional_plan=provisional.plan("quick", ["docs"]),
				resolved_plan=drifted.plan("quick", ["docs"]),
				allowed_scene_changes={},
			)

	def test_reference_catalog_resolution_rejects_explicit_plan_authority_drift(
		self,
	) -> None:
		catalog = gf_maintenance.validation_catalog_for_root(ROOT)
		plan = catalog.plan("full")
		drifted_plans = (
			replace(plan, requested_actions=plan.requested_actions[:-1]),
			replace(plan, actions=plan.actions[:-1]),
			replace(
				plan,
				check_graph=gf_maintenance.CheckGraph(catalog.action_names, {}),
			),
			replace(
				plan,
				lanes=(
					replace(plan.lanes[0], execution_actions=()),
					*plan.lanes[1:],
				),
			),
		)

		for drifted_plan in drifted_plans:
			with self.subTest(
				requested=len(drifted_plan.requested_actions),
				actions=len(drifted_plan.actions),
				lanes=len(drifted_plan.lanes),
			), self.assertRaisesRegex(
				gf_validation_catalog.ValidationCatalogError,
				"validation plan authority",
			):
				gf_maintenance.validate_resolved_reference_catalog(
					catalog,
					catalog,
					provisional_plan=plan,
					resolved_plan=drifted_plan,
					allowed_scene_changes={},
				)

	def test_plan_preserves_full_closure_and_isolated_lane_occurrences(self) -> None:
		catalog = gf_maintenance._VALIDATION_CATALOG
		plan = catalog.plan("full")
		owned_actions = [
			action
			for lane in plan.lanes
			for action in lane.owned_actions
		]

		self.assertEqual(len(plan.actions), 46)
		self.assertEqual(tuple(lane.name for lane in plan.lanes), catalog.parallel_full_shard_suites)
		self.assertEqual(set(owned_actions), set(catalog.check_group("full")))
		self.assertEqual(len(owned_actions), len(set(owned_actions)))
		self.assertEqual(
			sum(len(lane.execution_actions) for lane in plan.lanes),
			47,
			"隔离 lane 必须分别执行各自的依赖 occurrence，不能按全局 action 去重。",
		)
		self.assertEqual(
			[
				lane.name
				for lane in plan.lanes
				if "godot_import" in lane.execution_actions
			],
			["framework-gut", "framework-lsp"],
		)

	def test_validation_plan_and_lanes_reject_field_rebinding(self) -> None:
		plan = gf_maintenance._VALIDATION_CATALOG.plan("full")

		with self.assertRaises(FrozenInstanceError):
			setattr(plan, "suite", "quick")
		with self.assertRaises(FrozenInstanceError):
			setattr(plan.lanes[0], "execution_actions", ())
		self.assertIsInstance(plan.requested_actions, tuple)
		self.assertIsInstance(plan.actions, tuple)
		self.assertIsInstance(plan.lanes, tuple)
		self.assertTrue(all(
			isinstance(lane.owned_actions, tuple)
			and isinstance(lane.execution_actions, tuple)
			for lane in plan.lanes
		))

	def test_plan_uses_one_effective_graph_for_sync_examples(self) -> None:
		plan = gf_maintenance._VALIDATION_CATALOG.plan(
			"examples",
			sync_examples=True,
		)
		description = plan.check_graph.describe(plan.actions)

		self.assertEqual(
			plan.actions,
			(
				"examples_sync_write",
				"examples_scan",
				"examples_boot",
				"examples_smoke",
				"examples_coverage",
			),
		)
		self.assertEqual(description["edge_count"], 4)
		self.assertEqual(
			description["edges"],
			[
				{"check": "examples_scan", "depends_on": "examples_sync_write"},
				{"check": "examples_boot", "depends_on": "examples_scan"},
				{"check": "examples_smoke", "depends_on": "examples_scan"},
				{"check": "examples_coverage", "depends_on": "examples_sync_write"},
			],
		)

	def test_sync_examples_setup_failure_reports_the_effective_plan_graph(self) -> None:
		frozen = _frozen_process_environment({
			**dict(os.environ),
			gf_maintenance.REFERENCE_BOOT_SCENE_ENV_VAR: "res://fixture_boot.tscn",
			gf_maintenance.REFERENCE_SMOKE_SCENE_ENV_VAR: "res://fixture_smoke.tscn",
		})
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=gf_maintenance.gf_maintenance_check_graph.WorkspaceFingerprintSetupError(
				"synthetic setup failure"
			),
		):
			report = gf_maintenance.run_checks(
				suite="examples",
				sync_examples=True,
				process_environment=frozen,
			)

		self.assertFalse(report["ok"])
		self.assertEqual(report["check_graph"]["edge_count"], 4)
		self.assertEqual(
			report["check_graph"]["edges"],
			[
				{"check": "examples_scan", "depends_on": "examples_sync_write"},
				{"check": "examples_boot", "depends_on": "examples_scan"},
				{"check": "examples_smoke", "depends_on": "examples_scan"},
				{"check": "examples_coverage", "depends_on": "examples_sync_write"},
			],
		)

	def test_sync_examples_deadline_failure_reports_the_effective_plan_graph(self) -> None:
		plan = gf_maintenance._VALIDATION_CATALOG.plan(
			"examples",
			sync_examples=True,
		)
		frozen = _frozen_process_environment({
			**dict(os.environ),
			gf_maintenance.REFERENCE_BOOT_SCENE_ENV_VAR: "res://fixture_boot.tscn",
			gf_maintenance.REFERENCE_SMOKE_SCENE_ENV_VAR: "res://fixture_smoke.tscn",
		})
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=TimeoutError("synthetic workspace deadline"),
		):
			report = gf_maintenance.run_checks(
				suite="examples",
				sync_examples=True,
				suite_timeout_seconds=1,
				process_environment=frozen,
			)

		self.assertFalse(report["ok"])
		self.assertEqual(report["checks"], list(plan.actions))
		self.assertEqual(report["check_graph"], plan.describe_graph())
		self.assertEqual(report["results"][0]["name"], "suite_deadline")

	def test_serial_runner_consumes_the_effective_plan_dependencies(self) -> None:
		plan = gf_maintenance._VALIDATION_CATALOG.plan(
			"examples",
			sync_examples=True,
		)
		workspace_state = {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "b" * 64,
		}

		def succeed(
			name: str,
			command: gf_maintenance.CommandIdentity,
			timeout_seconds: float,
			_output_callback: object,
			**_kwargs: object,
		) -> gf_maintenance.CommandResult:
			return gf_maintenance.CommandResult(
				name=name,
				command=list(command.effective),
				exit_code=0,
				stdout="",
				stderr="",
				timeout_seconds=timeout_seconds,
			)

		validation_executor_binding = _validation_executor_binding(
			gf_maintenance._VALIDATION_CATALOG,
			gf_maintenance.maintenance_in_process_adapter_registry(),
		)
		process_environment = {
			gf_maintenance.GODOT_EXECUTABLE_ENV_VAR: str(
				Path(sys.executable).resolve()
			),
		}
		with mock.patch.object(
			gf_maintenance,
			"run_command",
			side_effect=succeed,
		):
			report = gf_maintenance.run_checks_with_active_snapshot(
				plan,
				validation_executor_binding=validation_executor_binding,
				git_process=_SHARED_PROCESS_AUTHORITY.git,
				workspace_state=workspace_state,
				process_environment=process_environment,
			)

		self.assertTrue(report["ok"])
		results = {result["name"]: result for result in report["results"]}
		for consumer in ("examples_scan", "examples_coverage"):
			with self.subTest(consumer=consumer):
				self.assertEqual(
					results[consumer]["dependencies"],
					["examples_sync_write"],
				)
				self.assertEqual(
					set(results[consumer]["dependency_fingerprints"]),
					{"examples_sync_write"},
				)

	def test_serial_runner_consumes_the_catalog_timeout_floor(self) -> None:
		plan = gf_maintenance._VALIDATION_CATALOG.plan("api", ["api"])
		workspace_state = {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "b" * 64,
		}
		adapter = mock.Mock(return_value={"ok": True})
		validation_executor_binding = _validation_executor_binding(
			gf_maintenance._VALIDATION_CATALOG,
			_in_process_adapter_registry_with(api=adapter),
		)
		with mock.patch.object(
			gf_maintenance._VALIDATION_CATALOG,
			"timeout_floor_seconds",
			return_value=321,
		) as timeout_floor:
			report = gf_maintenance.run_checks_with_active_snapshot(
				plan,
				validation_executor_binding=validation_executor_binding,
				git_process=_SHARED_PROCESS_AUTHORITY.git,
				workspace_state=workspace_state,
			)

		timeout_floor.assert_called_once_with("api")
		adapter.assert_called_once_with()
		self.assertEqual(
			report["results"][0]["timeout_budget"],
			{
				"policy_seconds": 321.0,
				"requested_minimum_seconds": None,
				"suite_remaining_seconds": None,
				"effective_seconds": 321.0,
			},
		)

	def test_run_checks_keeps_assigned_timeout_while_action_budget_decreases(self) -> None:
		workspace_state = {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "b" * 64,
		}
		clock = [10.0]

		def fingerprint(*_args: object, **_kwargs: object) -> dict[str, object]:
			clock[0] = 11.1
			return dict(workspace_state)

		with mock.patch.object(
			gf_maintenance.time,
			"perf_counter",
			side_effect=lambda: clock[0],
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=fingerprint,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			return_value=_in_process_adapter_registry_with(
				docs=lambda: {"ok": True}
			),
		):
			report = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				suite_timeout_seconds=90,
			)

		self.assertTrue(report["ok"])
		self.assertEqual(report["suite_timeout_seconds"], 90)
		self.assertEqual(
			report["results"][0]["timeout_budget"]["suite_remaining_seconds"],
			89.0,
		)

	def test_serial_runner_can_emit_complete_output_evidence_for_parallel_parent(self) -> None:
		plan = gf_maintenance._VALIDATION_CATALOG.plan("api", ["api"])
		workspace_state = {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "b" * 64,
		}
		adapter_payload = {"ok": True, "details": "x" * 12001}
		binding = _validation_executor_binding(
			gf_maintenance._VALIDATION_CATALOG,
			_in_process_adapter_registry_with(
				api=mock.Mock(return_value=adapter_payload)
			),
		)

		report = gf_maintenance.run_checks_with_active_snapshot(
			plan,
			validation_executor_binding=binding,
			git_process=_SHARED_PROCESS_AUTHORITY.git,
			complete_output_evidence=True,
			workspace_state=workspace_state,
		)

		result = report["results"][0]
		expected_stdout = json.dumps(adapter_payload, ensure_ascii=False)
		self.assertGreater(len(expected_stdout), 12000)
		self.assertEqual(result["stdout"], expected_stdout)
		self.assertFalse(result["stdout_truncated"])
		self.assertEqual(result["stdout_char_count"], len(expected_stdout))
		self.assertEqual(
			result["stdout_sha256"],
			hashlib.sha256(expected_stdout.encode("utf-8")).hexdigest(),
		)

	def test_check_cli_forwards_complete_output_evidence_only_when_requested(self) -> None:
		for requested in (False, True):
			argv = ["gf_maintenance.py", "check", "--check", "docs", "--json"]
			if requested:
				argv = [
					"gf_maintenance.py",
					"--json-output",
					"build/p/complete-output-fixture.json",
					"check",
					"--check",
					"docs",
					"--jobs",
					"1",
					"--internal-complete-output-evidence",
					"--json",
				]
			with self.subTest(requested=requested), mock.patch.object(
				sys,
				"argv",
				argv,
			), mock.patch.object(
				gf_maintenance,
				"run_checks",
				return_value={"ok": True, "results": []},
			) as runner, mock.patch.object(
				gf_maintenance.maintenance_rendering,
				"print_output",
			) as print_output, mock.patch.object(
				gf_maintenance,
				"write_internal_complete_output_evidence_report",
			) as complete_writer:
				exit_code = gf_maintenance.main()

			self.assertEqual(exit_code, 0)
			self.assertIs(
				runner.call_args.kwargs["complete_output_evidence"],
				requested,
			)
			if requested:
				complete_writer.assert_called_once()
				print_output.assert_not_called()
			else:
				complete_writer.assert_not_called()
				print_output.assert_called_once()

		invalid_argv = (
			[
				"gf_maintenance.py",
				"check",
				"--check",
				"docs",
				"--jobs",
				"1",
				"--internal-complete-output-evidence",
			],
			[
				"gf_maintenance.py",
				"--json-output",
				"build/p/missing-job.json",
				"check",
				"--check",
				"docs",
				"--internal-complete-output-evidence",
			],
			[
				"gf_maintenance.py",
				"--json-output",
				"build/p/missing-check.json",
				"check",
				"--jobs",
				"1",
				"--internal-complete-output-evidence",
			],
		)
		for argv in invalid_argv:
			stderr = io.StringIO()
			with self.subTest(argv=argv), mock.patch.object(
				sys,
				"argv",
				argv,
			), mock.patch.object(
				gf_maintenance,
				"run_checks",
			) as runner, contextlib.redirect_stderr(stderr), self.assertRaises(
				SystemExit,
			) as raised:
				gf_maintenance.main()
			self.assertEqual(raised.exception.code, 2)
			self.assertIn(
				"requires --json-output, --jobs 1, and at least one explicit --check",
				stderr.getvalue(),
			)
			runner.assert_not_called()

	def test_executor_registry_failure_precedes_workspace_and_action_io(self) -> None:
		with mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			return_value={},
		), mock.patch.object(
			gf_maintenance,
			"pin_godot_executable_selection",
			side_effect=AssertionError(
				"executor setup must fail before executable resolution"
			),
		) as executable_pin, mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=AssertionError("executor setup must fail before workspace I/O"),
		) as fingerprint, mock.patch.object(
			gf_maintenance,
			"materialize_check_command",
			side_effect=AssertionError("executor setup must fail before command materialization"),
		) as command, mock.patch.object(
			gf_maintenance,
			"run_command",
			side_effect=AssertionError("executor setup must fail before subprocess execution"),
		) as subprocess_runner:
			report = gf_maintenance.run_checks(checks=["docs"], jobs=1)

		self.assertFalse(report["ok"])
		self.assertEqual(report["completed_check_count"], 0)
		self.assertEqual(report["results"][0]["name"], "validation_executor_setup")
		executable_pin.assert_not_called()
		fingerprint.assert_not_called()
		command.assert_not_called()
		subprocess_runner.assert_not_called()

	def test_invocation_environment_snapshot_precedes_registries_and_pin_follows_closure(
		self,
	) -> None:
		events: list[str] = []
		sentinel_name = "GF_TEST_INVOCATION_ENVIRONMENT"
		real_capture = gf_maintenance.capture_maintenance_process_environment
		real_adapters = gf_maintenance.maintenance_in_process_adapter_registry
		real_materializers = (
			gf_maintenance.maintenance_deferred_command_materializer_registry
		)
		real_validator = gf_maintenance.validate_validation_executor_registries

		def capture_environment() -> dict[str, str]:
			events.append("capture")
			return real_capture()

		def construct_adapters() -> dict[str, object]:
			events.append("adapters")
			active_environment = gf_process_authority.active_process_environment()
			self.assertIsNotNone(active_environment)
			self.assertEqual(
				active_environment.values()[sentinel_name],
				"captured-at-entry",
			)
			os.environ[sentinel_name] = "changed-by-registry"
			return real_adapters()

		def construct_materializers() -> dict[str, object]:
			events.append("materializers")
			return real_materializers()

		def validate_registries(*args: object) -> object:
			events.append("validate")
			return real_validator(*args)

		def reject_pinned_environment(
			environment: dict[str, str],
			*,
			cwd: Path,
		) -> None:
			events.append("pin")
			self.assertEqual(cwd, ROOT)
			self.assertEqual(environment[sentinel_name], "captured-at-entry")
			raise gf_executable_resolution.EnvironmentNameAmbiguityError(
				"fixture frozen environment is invalid"
			)

		with mock.patch.dict(
			os.environ,
			{sentinel_name: "captured-at-entry"},
		), mock.patch.object(
			gf_maintenance,
			"capture_maintenance_process_environment",
			side_effect=capture_environment,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			side_effect=construct_adapters,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_deferred_command_materializer_registry",
			side_effect=construct_materializers,
		), mock.patch.object(
			gf_maintenance,
			"validate_validation_executor_registries",
			side_effect=validate_registries,
		), mock.patch.object(
			gf_maintenance,
			"pin_godot_executable_selection",
			side_effect=reject_pinned_environment,
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=AssertionError(
				"invalid frozen environment must fail before workspace I/O"
			),
		) as fingerprint:
			report = gf_maintenance.run_checks(checks=["docs"], jobs=1)

		self.assertEqual(
			events,
			["capture", "adapters", "materializers", "validate", "pin"],
		)
		self.assertFalse(report["ok"])
		self.assertEqual(report["completed_check_count"], 0)
		self.assertEqual(
			report["results"][0]["name"],
			"validation_environment_setup",
		)
		fingerprint.assert_not_called()

	def test_materializer_registry_failure_precedes_workspace_and_action_io(self) -> None:
		with mock.patch.object(
			gf_maintenance,
			"maintenance_deferred_command_materializer_registry",
			return_value={},
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=AssertionError("executor setup must fail before workspace I/O"),
		) as fingerprint, mock.patch.object(
			gf_maintenance,
			"materialize_check_command",
			side_effect=AssertionError("executor setup must fail before command materialization"),
		) as command, mock.patch.object(
			gf_maintenance,
			"run_command",
			side_effect=AssertionError("executor setup must fail before subprocess execution"),
		) as subprocess_runner:
			report = gf_maintenance.run_checks(checks=["docs"], jobs=1)

		self.assertFalse(report["ok"])
		self.assertEqual(report["completed_check_count"], 0)
		self.assertEqual(report["results"][0]["name"], "validation_executor_setup")
		fingerprint.assert_not_called()
		command.assert_not_called()
		subprocess_runner.assert_not_called()

	def test_executor_registry_constructor_failure_is_bounded_before_io(self) -> None:
		class HostileRegistryError(RuntimeError):
			def __str__(self) -> str:
				raise AssertionError("arbitrary registry exceptions must not be rendered")

		class HostileCatalogRegistryError(
			gf_validation_catalog.ValidationCatalogError
		):
			def __str__(self) -> str:
				raise AssertionError("constructor errors must not inherit validator trust")

		for error in (HostileRegistryError(), HostileCatalogRegistryError()):
			with self.subTest(error_type=type(error).__name__), mock.patch.object(
				gf_maintenance,
				"maintenance_in_process_adapter_registry",
				side_effect=error,
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				side_effect=AssertionError("executor setup must fail before workspace I/O"),
			) as fingerprint, mock.patch.object(
				gf_maintenance,
				"materialize_check_command",
				side_effect=AssertionError(
					"executor setup must fail before command materialization"
				),
			) as command:
				report = gf_maintenance.run_checks(checks=["docs"], jobs=1)

			self.assertFalse(report["ok"])
			self.assertEqual(report["results"][0]["name"], "validation_executor_setup")
			self.assertEqual(
				report["results"][0]["stderr"],
				"Validation executor registries could not be constructed.",
			)
			fingerprint.assert_not_called()
			command.assert_not_called()

	def test_executor_registry_constructor_preserves_cleanup_debt_identity(self) -> None:
		debt = gf_process_supervisor.SupervisedProcessCleanupError(
			"fixture registry cleanup debt",
			pid=123,
			process_tree_empty=False,
		)
		with mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			side_effect=debt,
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=AssertionError("cleanup debt must escape before workspace I/O"),
		) as fingerprint:
			with self.assertRaises(
				gf_process_supervisor.SupervisedProcessCleanupError
			) as raised:
				gf_maintenance.run_checks(checks=["docs"], jobs=1)

		self.assertIs(raised.exception, debt)
		self.assertTrue(raised.exception.cleanup_debt)
		self.assertFalse(raised.exception.process_boundary_quiescent)
		fingerprint.assert_not_called()

	def test_run_checks_captures_one_catalog_before_registry_construction(self) -> None:
		invocation_catalog = gf_maintenance.validation_catalog_for_root(ROOT)
		invocation_environment = _frozen_process_environment()

		with mock.patch.object(
			gf_maintenance,
			"validation_catalog_for_root",
			return_value=invocation_catalog,
		) as catalog_factory, mock.patch.object(
			gf_maintenance,
			"reference_catalog_inputs",
			return_value=("fixture-reference", "fixture-boot", "fixture-smoke"),
		) as reference_inputs, mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
		), mock.patch.object(
			gf_maintenance,
			"validate_validation_executor_registries",
			side_effect=gf_validation_catalog.ValidationCatalogError("fixture stop"),
		) as validate_registries, mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=AssertionError("executor setup must fail before workspace I/O"),
		) as fingerprint:
			report = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				process_environment=invocation_environment,
			)

		self.assertFalse(report["ok"])
		self.assertEqual(report["results"][0]["name"], "validation_executor_setup")
		catalog_factory.assert_called_once_with(
			ROOT,
			default_reference_project="fixture-reference",
			reference_boot_scene="fixture-boot",
			reference_smoke_scene="fixture-smoke",
		)
		reference_inputs.assert_called_once_with(invocation_environment)
		validate_registries.assert_called_once()
		self.assertIs(validate_registries.call_args.args[0], invocation_catalog)
		fingerprint.assert_not_called()

	def test_parallel_executor_registry_failure_precedes_workspace_and_artifact_io(self) -> None:
		plan = gf_maintenance._VALIDATION_CATALOG.plan("full")
		with mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			return_value={},
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=AssertionError("executor setup must fail before workspace I/O"),
		) as fingerprint, mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"capture_workspace",
			side_effect=AssertionError("executor setup must fail before workspace capture"),
		) as capture, mock.patch.object(
			gf_maintenance,
			"build_package_smoke_artifact_set",
			side_effect=AssertionError("executor setup must fail before artifact build"),
		) as artifact_build, mock.patch.object(
			gf_maintenance,
			"run_parallel_godot_isolation_probe",
			side_effect=AssertionError("executor setup must fail before isolation probe"),
		) as isolation_probe, mock.patch.object(
			gf_maintenance,
			"run_parallel_full_checks",
			side_effect=AssertionError("executor setup must fail before shard execution"),
		) as parallel_runner:
			report = gf_maintenance.run_checks(suite="full", jobs=2)

		self.assertFalse(report["ok"])
		self.assertEqual(report["checks"], list(plan.actions))
		self.assertEqual(report["check_graph"], plan.describe_graph())
		self.assertEqual(report["results"][0]["name"], "validation_executor_setup")
		self.assertEqual(report["execution"], "parallel_shards")
		self.assertEqual(report["jobs"], 2)
		fingerprint.assert_not_called()
		capture.assert_not_called()
		artifact_build.assert_not_called()
		isolation_probe.assert_not_called()
		parallel_runner.assert_not_called()

	def test_parallel_unresolved_godot_is_structured_before_shard_dispatch(self) -> None:
		workspace_state = {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "b" * 64,
		}
		captured_workspace = gf_maintenance.CapturedWorkspace(
			source_root=ROOT,
			head=str(workspace_state["head"]),
			binary_diff=b"",
			untracked_files=(),
			workspace_fingerprint=str(workspace_state["fingerprint"]),
		)
		artifact_set = mock.Mock(
			artifacts=(object(),),
			manifest_sha256="c" * 64,
		)
		with tempfile.TemporaryDirectory() as temporary_directory:
			managed_root = Path(temporary_directory)
			artifact_set.manifest_path = managed_root / "artifact-manifest.json"

			@contextlib.contextmanager
			def managed_directory(*, prefix: str, **_kwargs: object):
				path = managed_root / prefix.rstrip("-")
				path.mkdir()
				yield path

			with mock.patch.dict(
				gf_maintenance.os.environ,
				{
					"PATH": os.fspath(
						Path(_SHARED_PROCESS_AUTHORITY.git.executable).parent
					),
					"PATHEXT": ".EXE",
					"NoDefaultCurrentDirectoryInExePath": "1",
				},
				clear=True,
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				return_value=workspace_state,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"capture_workspace",
				return_value=captured_workspace,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"assert_source_matches_snapshot",
			), mock.patch.object(
				gf_maintenance,
				"managed_validation_directory",
				side_effect=managed_directory,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"materialize_workspace",
				return_value=ROOT,
			), mock.patch.object(
				gf_maintenance,
				"build_package_smoke_artifact_set",
				return_value=artifact_set,
			), mock.patch.object(
				gf_maintenance,
				"package_artifact_details",
				return_value={"fixture": True},
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"run_parallel_shards",
				side_effect=AssertionError(
					"unresolved Godot must fail before parallel shard dispatch"
				),
			) as run_parallel:
				report = gf_maintenance.run_checks(suite="full", jobs=2)

		self.assertFalse(report["ok"])
		self.assertEqual(report["execution"], "parallel_shards")
		self.assertEqual(report["jobs"], 2)
		self.assertEqual(report["completed_check_count"], 0)
		self.assertEqual(report["results"][0]["name"], "parallel_validation_setup")
		self.assertIn(
			"Godot executable could not be resolved",
			report["results"][0]["stderr"],
		)
		run_parallel.assert_not_called()

	def test_executor_setup_advisories_fail_closed_without_collection(self) -> None:
		with mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			return_value={},
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=AssertionError("executor setup must fail before workspace I/O"),
		), mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
		) as inventory, mock.patch.object(
			gf_maintenance.gf_validation_inputs,
			"analyze_affected_checks",
		) as affected_analyzer:
			report = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				validation_shadow=True,
				affected=True,
			)

		self.assertEqual(report["results"][0]["name"], "validation_executor_setup")
		self.assertEqual(report["validation_shadow"]["errors"], ["shadow_internal_error"])
		self.assertEqual(report["validation_shadow"]["executed_action_count"], 0)
		self.assertEqual(report["affected_analysis"]["errors"], ["affected_internal_error"])
		self.assertEqual(report["affected_analysis"]["unknown_count"], 1)
		self.assertEqual(report["affected_analysis"]["fallback_decision"], "execute")
		inventory.assert_not_called()
		affected_analyzer.assert_not_called()

	def test_serial_dispatch_uses_catalog_executor_kind(self) -> None:
		workspace_state = {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "b" * 64,
		}
		for executor_kind in (
			gf_validation_catalog.ValidationExecutorKind.IN_PROCESS,
			gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
		):
			with self.subTest(executor_kind=executor_kind):
				catalog = self._minimal_catalog(actions=(
					("alpha", ("python",), executor_kind),
					(
						"beta",
						None,
						gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
					),
				))
				plan = catalog.plan("suite", ["alpha"])
				adapter = mock.Mock(return_value={"ok": True})
				registry = _validation_executor_binding(
					catalog,
					{"alpha": adapter}
					if executor_kind is gf_validation_catalog.ValidationExecutorKind.IN_PROCESS
					else {},
				)
				materialized_command = [
					str(Path(sys.executable).resolve()),
					"fixture.py",
					executor_kind.value,
				]
				subprocess_result = gf_maintenance.CommandResult(
					name="alpha",
					command=materialized_command,
					exit_code=0,
					stdout="",
					stderr="",
					timeout_seconds=10.0,
				)
				with mock.patch.object(
					gf_maintenance,
					"materialize_check_command",
					return_value=materialized_command,
				) as command, mock.patch.object(
					gf_maintenance,
					"make_check_input_fingerprint",
					wraps=gf_maintenance.make_check_input_fingerprint,
				) as input_fingerprint, mock.patch.object(
					gf_maintenance,
					"run_command",
					return_value=subprocess_result,
				) as subprocess_runner:
					report = gf_maintenance.run_checks_with_active_snapshot(
						plan,
						validation_executor_binding=registry,
						git_process=_SHARED_PROCESS_AUTHORITY.git,
						workspace_state=workspace_state,
					)

				self.assertTrue(report["ok"])
				self.assertEqual(report["results"][0]["command"], materialized_command)
				command.assert_called_once_with(
					"alpha",
					"",
					"",
					validation_executor_binding=registry,
					deferred_command_context=gf_maintenance.DeferredCommandContext(
						artifact_manifest="",
						allow_breaking_api=False,
					),
				)
				self.assertEqual(input_fingerprint.call_args.args[1], materialized_command)
				self.assertEqual(input_fingerprint.call_args.args[2], materialized_command)
				if executor_kind is gf_validation_catalog.ValidationExecutorKind.IN_PROCESS:
					adapter.assert_called_once_with()
					subprocess_runner.assert_not_called()
					self.assertEqual(report["results"][0]["execution"], "in_process")
				else:
					adapter.assert_not_called()
					identity = subprocess_runner.call_args.args[1]
					self.assertIsInstance(identity, gf_maintenance.CommandIdentity)
					self.assertEqual(list(identity.declared), materialized_command)
					self.assertEqual(list(identity.effective), materialized_command)
					self.assertIn("environment", subprocess_runner.call_args.kwargs)
					self.assertEqual(report["results"][0]["execution"], "subprocess")

	def test_serial_command_materialization_uses_the_bound_catalog(self) -> None:
		catalog = self._minimal_catalog(actions=(
			(
				"alpha",
				("custom-python", "custom.py"),
				gf_validation_catalog.ValidationExecutorKind.IN_PROCESS,
			),
			(
				"beta",
				None,
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
		))
		adapter = mock.Mock(return_value={"ok": True})
		binding = _validation_executor_binding(
			catalog,
			{"alpha": adapter},
		)
		report = gf_maintenance.run_checks_with_active_snapshot(
			catalog.plan("suite", ["alpha"]),
			validation_executor_binding=binding,
			git_process=_SHARED_PROCESS_AUTHORITY.git,
			workspace_state={
				"schema_version": 1,
				"head": "a" * 40,
				"dirty": False,
				"untracked_file_count": 0,
				"fingerprint": "b" * 64,
			},
		)

		self.assertTrue(report["ok"])
		self.assertEqual(report["results"][0]["command"], ["custom-python", "custom.py"])
		self.assertEqual(report["results"][0]["timeout_budget"]["policy_seconds"], 15.0)
		adapter.assert_called_once_with()

	def test_serial_godot_fingerprint_and_dispatch_share_one_frozen_identity(self) -> None:
		catalog = self._minimal_catalog(actions=(
			(
				"alpha",
				("godot", "--headless"),
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
			(
				"beta",
				None,
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
		))
		binding = _validation_executor_binding(catalog, {})
		with tempfile.TemporaryDirectory() as temporary_directory:
			godot_path = Path(temporary_directory) / (
				"fixture-godot.exe" if os.name == "nt" else "fixture-godot"
			)
			godot_path.write_bytes(b"fixture")
			if os.name != "nt":
				godot_path.chmod(0o755)
			process_environment = {
				gf_maintenance.GODOT_EXECUTABLE_ENV_VAR: str(godot_path),
				"PATH": "",
				"PATHEXT": ".EXE",
			}

			def succeed(
				name: str,
				identity: gf_maintenance.CommandIdentity,
				timeout: float,
				_output: object,
				**_kwargs: object,
			) -> gf_maintenance.CommandResult:
				return gf_maintenance.CommandResult(
					name=name,
					command=list(identity.effective),
					exit_code=0,
					stdout="",
					stderr="",
					timeout_seconds=timeout,
				)

			with mock.patch.object(
				gf_maintenance,
				"make_check_input_fingerprint",
				wraps=gf_maintenance.make_check_input_fingerprint,
			) as input_fingerprint, mock.patch.object(
				gf_maintenance,
				"run_command",
				side_effect=succeed,
			) as subprocess_runner:
				report = gf_maintenance.run_checks_with_active_snapshot(
					catalog.plan("suite", ["alpha"]),
					validation_executor_binding=binding,
					git_process=_SHARED_PROCESS_AUTHORITY.git,
					workspace_state={
						"schema_version": 1,
						"head": "a" * 40,
						"dirty": False,
						"untracked_file_count": 0,
						"fingerprint": "b" * 64,
					},
					process_environment=process_environment,
				)

		declared = ["godot", "--headless"]
		effective = [str(godot_path.resolve()), "--headless"]
		self.assertTrue(report["ok"])
		self.assertEqual(report["results"][0]["command"], effective)
		self.assertEqual(input_fingerprint.call_args.args[1], declared)
		self.assertEqual(input_fingerprint.call_args.args[2], effective)
		identity = subprocess_runner.call_args.args[1]
		self.assertEqual(list(identity.declared), declared)
		self.assertEqual(list(identity.effective), effective)
		fingerprint_args = input_fingerprint.call_args.args
		original_fingerprint = report["results"][0]["input_fingerprint"]
		self.assertNotEqual(
			gf_maintenance.make_check_input_fingerprint(
				fingerprint_args[0],
				["godot", "--editor"],
				fingerprint_args[2],
				fingerprint_args[3],
				fingerprint_args[4],
				fingerprint_args[5],
			),
			original_fingerprint,
		)
		self.assertNotEqual(
			gf_maintenance.make_check_input_fingerprint(
				fingerprint_args[0],
				fingerprint_args[1],
				["C:/forged/godot.exe", "--headless"],
				fingerprint_args[3],
				fingerprint_args[4],
				fingerprint_args[5],
			),
			original_fingerprint,
		)

	def test_serial_windows_mixed_case_godot_pin_survives_rebinding(self) -> None:
		catalog = self._minimal_catalog(actions=(
			(
				"alpha",
				("godot", "--headless"),
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
			(
				"beta",
				None,
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
		))
		binding = _validation_executor_binding(catalog, {})
		with tempfile.TemporaryDirectory() as temporary_directory:
			godot_path = Path(temporary_directory) / "fixture-godot.exe"
			godot_path.write_bytes(b"fixture")
			if os.name != "nt":
				godot_path.chmod(0o755)
			mixed_name = "gF_GoDoT_ExEcUtAbLe"
			mixed_nonce_name = (
				gf_maintenance.GUT_SHARD_OBSERVATION_NONCE_ENVIRONMENT.swapcase()
			)
			mixed_path_name = (
				gf_maintenance.GUT_SHARD_OBSERVATION_PATH_ENVIRONMENT.swapcase()
			)
			process_environment = {
				mixed_name: str(godot_path),
				mixed_nonce_name: "late-observation",
				mixed_path_name: "res://build/gut-sharding/late/provenance.json",
				"PATH": "",
				"PATHEXT": ".EXE",
			}
			original_environment = dict(process_environment)
			real_resolver = gf_godot_process.resolve_godot_executable
			real_setter = gf_executable_resolution.set_owned_environment_value
			real_remover = gf_executable_resolution.remove_owned_environment_value

			def resolve_as_windows(
				configured: str = "godot",
				*,
				environment: dict[str, str],
				cwd: Path,
				platform_name: str | None = None,
			) -> str:
				return real_resolver(
					configured,
					environment=environment,
					cwd=cwd,
					platform_name="nt",
				)

			def set_as_windows(
				environment: dict[str, str],
				name: str,
				value: str,
				*,
				platform_name: str | None = None,
			) -> None:
				real_setter(
					environment,
					name,
					value,
					platform_name="nt",
				)

			def remove_as_windows(
				environment: dict[str, str],
				name: str,
				*,
				platform_name: str | None = None,
			) -> None:
				real_remover(
					environment,
					name,
					platform_name="nt",
				)

			def succeed(
				name: str,
				identity: gf_maintenance.CommandIdentity,
				timeout: float,
				_output: object,
				**_kwargs: object,
			) -> gf_maintenance.CommandResult:
				return gf_maintenance.CommandResult(
					name=name,
					command=list(identity.effective),
					exit_code=0,
					stdout="",
					stderr="",
					timeout_seconds=timeout,
				)

			with mock.patch.object(
				gf_maintenance,
				"resolve_godot_executable",
				side_effect=resolve_as_windows,
			), mock.patch.object(
				gf_maintenance,
				"set_owned_environment_value",
				side_effect=set_as_windows,
			), mock.patch.object(
				gf_maintenance,
				"remove_owned_environment_value",
				side_effect=remove_as_windows,
			), mock.patch.object(
				gf_maintenance,
				"run_command",
				side_effect=succeed,
			) as subprocess_runner:
				report = gf_maintenance.run_checks_with_active_snapshot(
					catalog.plan("suite", ["alpha"]),
					validation_executor_binding=binding,
					git_process=_SHARED_PROCESS_AUTHORITY.git,
					workspace_state={
						"schema_version": 1,
						"head": "a" * 40,
						"dirty": False,
						"untracked_file_count": 0,
						"fingerprint": "b" * 64,
					},
					process_environment=process_environment,
				)

		self.assertTrue(report["ok"])
		self.assertEqual(process_environment, original_environment)
		self.assertEqual(
			report["results"][0]["command"][0],
			str(godot_path.resolve()),
		)
		dispatch_environment = subprocess_runner.call_args.kwargs["environment"]
		self.assertEqual(
			[
				key
				for key in dispatch_environment
				if key.casefold()
				== gf_maintenance.GODOT_EXECUTABLE_ENV_VAR.casefold()
			],
			[gf_maintenance.GODOT_EXECUTABLE_ENV_VAR],
		)
		self.assertEqual(
			dispatch_environment[gf_maintenance.GODOT_EXECUTABLE_ENV_VAR],
			str(godot_path.resolve()),
		)
		for scrubbed_name in (
			gf_maintenance.GUT_SHARD_OBSERVATION_NONCE_ENVIRONMENT,
			gf_maintenance.GUT_SHARD_OBSERVATION_PATH_ENVIRONMENT,
		):
			self.assertFalse(any(
				key.casefold() == scrubbed_name.casefold()
				for key in dispatch_environment
			))

	def test_serial_windows_ambiguous_godot_pin_is_a_setup_failure(self) -> None:
		catalog = self._minimal_catalog(actions=(
			(
				"alpha",
				("python", "-c", "pass"),
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
			(
				"beta",
				None,
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
		))
		binding = _validation_executor_binding(catalog, {})
		process_environment = {
			gf_maintenance.GODOT_EXECUTABLE_ENV_VAR: "first.exe",
			"gF_GoDoT_ExEcUtAbLe": "second.exe",
			"PATH": "",
			"PATHEXT": ".EXE",
		}
		original_environment = dict(process_environment)
		real_resolver = gf_godot_process.resolve_godot_executable

		def resolve_as_windows(
			configured: str = "godot",
			*,
			environment: dict[str, str],
			cwd: Path,
			platform_name: str | None = None,
		) -> str:
			return real_resolver(
				configured,
				environment=environment,
				cwd=cwd,
				platform_name="nt",
			)

		with mock.patch.object(
			gf_maintenance,
			"resolve_godot_executable",
			side_effect=resolve_as_windows,
		), mock.patch.object(
			gf_maintenance,
			"run_command",
			side_effect=AssertionError(
				"an ambiguous selection environment must fail before dispatch"
			),
		) as subprocess_runner:
			report = gf_maintenance.run_checks_with_active_snapshot(
				catalog.plan("suite", ["alpha"]),
				validation_executor_binding=binding,
				git_process=_SHARED_PROCESS_AUTHORITY.git,
				workspace_state={
					"schema_version": 1,
					"head": "a" * 40,
					"dirty": False,
					"untracked_file_count": 0,
					"fingerprint": "b" * 64,
				},
				process_environment=process_environment,
			)

		self.assertFalse(report["ok"])
		self.assertEqual(report["completed_check_count"], 0)
		self.assertEqual(
			report["results"][0]["name"],
			"validation_environment_setup",
		)
		self.assertIn(
			f"ambiguous {gf_maintenance.GODOT_EXECUTABLE_ENV_VAR}",
			report["results"][0]["stderr"],
		)
		self.assertEqual(process_environment, original_environment)
		subprocess_runner.assert_not_called()

	def test_serial_identity_environment_failure_is_a_setup_failure(self) -> None:
		catalog = self._minimal_catalog(actions=(
			(
				"alpha",
				("godot", "--headless"),
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
			(
				"beta",
				None,
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
		))
		binding = _validation_executor_binding(catalog, {})
		with mock.patch.object(
			gf_maintenance,
			"pin_godot_executable_selection",
		), mock.patch.object(
			gf_maintenance,
			"resolve_command_identity",
			side_effect=gf_executable_resolution.EnvironmentNameAmbiguityError(
				"fixture command environment is invalid"
			),
		), mock.patch.object(
			gf_maintenance,
			"run_command",
			side_effect=AssertionError(
				"invalid command environments must fail before dispatch"
			),
		) as subprocess_runner:
			report = gf_maintenance.run_checks_with_active_snapshot(
				catalog.plan("suite", ["alpha"]),
				validation_executor_binding=binding,
				git_process=_SHARED_PROCESS_AUTHORITY.git,
				workspace_state={
					"schema_version": 1,
					"head": "a" * 40,
					"dirty": False,
					"untracked_file_count": 0,
					"fingerprint": "b" * 64,
				},
				process_environment={"PATH": ""},
			)

		self.assertFalse(report["ok"])
		self.assertEqual(report["completed_check_count"], 0)
		self.assertEqual(
			report["results"][0]["name"],
			"validation_environment_setup",
		)
		subprocess_runner.assert_not_called()

	def test_serial_unresolved_godot_fails_before_supervisor_dispatch(self) -> None:
		catalog = self._minimal_catalog(actions=(
			(
				"alpha",
				("godot", "--headless"),
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
			(
				"beta",
				None,
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
		))
		binding = _validation_executor_binding(catalog, {})
		workspace_state = {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "b" * 64,
		}
		with tempfile.TemporaryDirectory() as temporary_directory:
			ambient_bin = Path(temporary_directory)
			ambient_godot = ambient_bin / (
				"godot.exe" if os.name == "nt" else "godot"
			)
			ambient_godot.write_bytes(b"ambient fixture")
			if os.name != "nt":
				ambient_godot.chmod(0o755)
			process_environment = {
				"PATH": "",
				"PATHEXT": ".EXE",
				"NoDefaultCurrentDirectoryInExePath": "1",
			}
			with mock.patch.dict(
				os.environ,
				{"PATH": str(ambient_bin)},
				clear=True,
			), mock.patch.object(
				gf_maintenance,
				"make_check_input_fingerprint",
				wraps=gf_maintenance.make_check_input_fingerprint,
			) as input_fingerprint, mock.patch.object(
				gf_maintenance,
				"run_command",
				side_effect=AssertionError("unresolved commands must not reach the runner"),
			) as subprocess_runner, mock.patch.object(
				gf_maintenance,
				"run_supervised_process",
				side_effect=AssertionError("unresolved commands must not reach the supervisor"),
			) as supervisor:
				report = gf_maintenance.run_checks_with_active_snapshot(
					catalog.plan("suite", ["alpha"]),
					validation_executor_binding=binding,
					git_process=_SHARED_PROCESS_AUTHORITY.git,
					workspace_state=workspace_state,
					process_environment=process_environment,
				)

		result = report["results"][0]
		self.assertFalse(report["ok"])
		self.assertEqual(result["exit_code"], 127)
		self.assertEqual(result["execution"], "not_started")
		self.assertEqual(
			result["command"],
			[
				gf_maintenance.UNRESOLVED_GODOT_EXECUTABLE_SENTINEL,
				"--headless",
			],
		)
		self.assertEqual(input_fingerprint.call_args.args[1], ["godot", "--headless"])
		self.assertIsNone(input_fingerprint.call_args.args[2])
		subprocess_runner.assert_not_called()
		supervisor.assert_not_called()

	def test_serial_unresolved_generic_executable_is_not_started(self) -> None:
		catalog = self._minimal_catalog(actions=(
			(
				"alpha",
				("fixture-missing-tool", "--version"),
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
			(
				"beta",
				None,
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
		))
		binding = _validation_executor_binding(catalog, {})
		workspace_state = {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "b" * 64,
		}
		with mock.patch.object(
			gf_maintenance,
			"make_check_input_fingerprint",
			wraps=gf_maintenance.make_check_input_fingerprint,
		) as input_fingerprint, mock.patch.object(
			gf_maintenance,
			"run_command",
			side_effect=AssertionError(
				"Unresolved generic commands must not reach the runner."
			),
		) as subprocess_runner, mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			side_effect=AssertionError(
				"Unresolved generic commands must not reach the supervisor."
			),
		) as supervisor:
			report = gf_maintenance.run_checks_with_active_snapshot(
				catalog.plan("suite", ["alpha"]),
				validation_executor_binding=binding,
				git_process=_SHARED_PROCESS_AUTHORITY.git,
				workspace_state=workspace_state,
				process_environment={
					"PATH": "",
					"PATHEXT": ".EXE",
					"NoDefaultCurrentDirectoryInExePath": "1",
				},
			)

		result = report["results"][0]
		self.assertFalse(report["ok"])
		self.assertEqual(result["exit_code"], 127)
		self.assertEqual(result["execution"], "not_started")
		self.assertEqual(
			result["command"],
			[
				gf_maintenance.UNRESOLVED_EXECUTABLE_SENTINEL,
				"--version",
			],
		)
		self.assertEqual(
			input_fingerprint.call_args.args[1],
			["fixture-missing-tool", "--version"],
		)
		self.assertIsNone(input_fingerprint.call_args.args[2])
		subprocess_runner.assert_not_called()
		supervisor.assert_not_called()

	def test_deferred_materializer_runs_once_before_either_executor(self) -> None:
		workspace_state = {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "b" * 64,
		}
		context = gf_maintenance.DeferredCommandContext(
			artifact_manifest="artifact.json",
			allow_breaking_api=True,
		)
		for executor_kind in (
			gf_validation_catalog.ValidationExecutorKind.IN_PROCESS,
			gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
		):
			with self.subTest(executor_kind=executor_kind):
				catalog = self._minimal_catalog(actions=(
					("alpha", None, executor_kind),
					(
						"beta",
						("python",),
						gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
					),
				))
				adapter = mock.Mock(return_value={"ok": True})
				fixture_python = str(Path(sys.executable).resolve())
				materializer = mock.Mock(
					return_value=(fixture_python, "alpha.py")
				)
				binding = _validation_executor_binding(
					catalog,
					{"alpha": adapter}
					if executor_kind is gf_validation_catalog.ValidationExecutorKind.IN_PROCESS
					else {},
					{"alpha": materializer},
				)
				with mock.patch.object(
					gf_maintenance,
					"make_check_input_fingerprint",
					wraps=gf_maintenance.make_check_input_fingerprint,
				) as input_fingerprint, mock.patch.object(
					gf_maintenance,
					"run_command",
					side_effect=lambda name, command, timeout, _output, **_kwargs: (
						gf_maintenance.CommandResult(
							name=name,
							command=list(command.effective),
							exit_code=0,
							stdout="",
							stderr="",
							timeout_seconds=timeout,
						)
					),
				) as subprocess_runner:
					report = gf_maintenance.run_checks_with_active_snapshot(
						catalog.plan("suite", ["alpha"]),
						validation_executor_binding=binding,
						git_process=_SHARED_PROCESS_AUTHORITY.git,
						artifact_manifest=context.artifact_manifest,
						allow_breaking_api=context.allow_breaking_api,
						workspace_state=workspace_state,
					)

				self.assertTrue(report["ok"])
				materializer.assert_called_once_with(context)
				command = report["results"][0]["command"]
				self.assertEqual(command, [fixture_python, "alpha.py"])
				self.assertNotIn(gf_maintenance.DEFERRED_COMMAND_SENTINEL, command)
				self.assertEqual(input_fingerprint.call_args.args[1], command)
				self.assertEqual(input_fingerprint.call_args.args[2], command)
				if executor_kind is gf_validation_catalog.ValidationExecutorKind.IN_PROCESS:
					adapter.assert_called_once_with()
					subprocess_runner.assert_not_called()
				else:
					adapter.assert_not_called()
					identity = subprocess_runner.call_args.args[1]
					self.assertEqual(list(identity.declared), command)
					self.assertEqual(list(identity.effective), command)

	def test_release_metadata_materializes_legacy_empty_manifest_argv(self) -> None:
		for allow_breaking_api in (False, True):
			with self.subTest(allow_breaking_api=allow_breaking_api):
				context = gf_maintenance.DeferredCommandContext(
					artifact_manifest="",
					allow_breaking_api=allow_breaking_api,
				)
				expected = (
					sys.executable,
					"tools/gf_maintenance.py",
					"release-status",
					"--json",
					"--artifact-manifest",
					"",
				)
				if allow_breaking_api:
					expected = (*expected, "--allow-breaking-api")
				self.assertEqual(
					gf_maintenance.materialize_release_metadata_command(context),
					expected,
				)

	def test_release_metadata_empty_manifest_dispatch_preserves_result(self) -> None:
		binding = gf_maintenance.validate_validation_executor_registries(
			gf_maintenance._VALIDATION_CATALOG,
			gf_maintenance.maintenance_in_process_adapter_registry(),
			gf_maintenance.maintenance_deferred_command_materializer_registry(),
		)
		structured_stdout = json.dumps({
			"ok": False,
			"issues": ["Release status requires an artifact manifest."],
		})
		declared_command = [
			sys.executable,
			"tools/gf_maintenance.py",
			"release-status",
			"--json",
			"--artifact-manifest",
			"",
		]
		effective_command = [
			str(Path(sys.executable).resolve()),
			*declared_command[1:],
		]
		with mock.patch.object(
			gf_maintenance,
			"run_command",
			side_effect=lambda name, command, timeout, _output, **_kwargs: (
				gf_maintenance.CommandResult(
					name=name,
					command=list(command.effective),
					exit_code=1,
					stdout=structured_stdout,
					stderr="",
					timeout_seconds=timeout,
				)
			),
		) as subprocess_runner:
			report = gf_maintenance.run_checks_with_active_snapshot(
				gf_maintenance._VALIDATION_CATALOG.plan(
					"release",
					["release_metadata"],
				),
				validation_executor_binding=binding,
				git_process=_SHARED_PROCESS_AUTHORITY.git,
				artifact_manifest="",
				workspace_state={
					"schema_version": 1,
					"head": "a" * 40,
					"dirty": False,
					"untracked_file_count": 0,
					"fingerprint": "b" * 64,
				},
			)

		result = report["results"][0]
		self.assertFalse(report["ok"])
		self.assertEqual(result["exit_code"], 1)
		self.assertEqual(result["execution"], "subprocess")
		self.assertEqual(json.loads(result["stdout"])["ok"], False)
		self.assertEqual(result["command"], effective_command)
		identity = subprocess_runner.call_args.args[1]
		self.assertEqual(list(identity.declared), declared_command)
		self.assertEqual(list(identity.effective), effective_command)

	def test_release_status_cli_accepts_explicit_empty_manifest(self) -> None:
		completed = subprocess.run(
			[
				sys.executable,
				"tools/gf_maintenance.py",
				"release-status",
				"--artifact-manifest",
				"",
				"--json",
			],
			cwd=ROOT,
			capture_output=True,
			text=True,
			encoding="utf-8",
			check=False,
		)

		self.assertEqual(completed.returncode, 1)
		self.assertEqual(completed.stderr, "")
		payload = json.loads(completed.stdout)
		self.assertFalse(payload["ok"])
		self.assertIn("requires --artifact-manifest", "\n".join(payload["issues"]))

	def test_invalid_deferred_materializer_never_dispatches(self) -> None:
		catalog = self._minimal_catalog(actions=(
			(
				"alpha",
				None,
				gf_validation_catalog.ValidationExecutorKind.IN_PROCESS,
			),
			(
				"beta",
				("python",),
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
		))
		invalid_materializers = {
			"list": mock.Mock(return_value=["python"]),
			"empty": mock.Mock(return_value=()),
			"empty part": mock.Mock(return_value=("",)),
			"non-string": mock.Mock(return_value=(object(),)),
			"sentinel": mock.Mock(return_value=(
				gf_maintenance.DEFERRED_COMMAND_SENTINEL,
			)),
			"exception": mock.Mock(side_effect=RuntimeError("fixture failure")),
		}
		for label, materializer in invalid_materializers.items():
			with self.subTest(label=label):
				adapter = mock.Mock(return_value={"ok": True})
				binding = _validation_executor_binding(
					catalog,
					{"alpha": adapter},
					{"alpha": materializer},
				)
				report = gf_maintenance.run_checks_with_active_snapshot(
					catalog.plan("suite", ["alpha"]),
					validation_executor_binding=binding,
					git_process=_SHARED_PROCESS_AUTHORITY.git,
					workspace_state={
						"schema_version": 1,
						"head": "a" * 40,
						"dirty": False,
						"untracked_file_count": 0,
						"fingerprint": "b" * 64,
					},
				)

				self.assertFalse(report["ok"])
				result = report["results"][0]
				self.assertEqual(result["execution"], "not_started")
				self.assertEqual(result["exit_code"], 125)
				self.assertEqual(
					result["command"],
					[
						gf_maintenance.DEFERRED_COMMAND_SENTINEL,
						"in_process",
						"alpha",
					],
				)
				adapter.assert_not_called()

	def test_deferred_materializer_cleanup_debt_escapes_unchanged(self) -> None:
		catalog = self._minimal_catalog(actions=(
			(
				"alpha",
				None,
				gf_validation_catalog.ValidationExecutorKind.IN_PROCESS,
			),
			(
				"beta",
				("python",),
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
		))
		debt = gf_process_supervisor.SupervisedProcessCleanupError(
			"fixture deferred materializer cleanup debt",
			pid=123,
			process_tree_empty=False,
		)
		adapter = mock.Mock(return_value={"ok": True})
		binding = _validation_executor_binding(
			catalog,
			{"alpha": adapter},
			{"alpha": mock.Mock(side_effect=debt)},
		)

		with self.assertRaises(
			gf_process_supervisor.SupervisedProcessCleanupError
		) as raised:
			gf_maintenance.run_checks_with_active_snapshot(
				catalog.plan("suite", ["alpha"]),
				validation_executor_binding=binding,
				git_process=_SHARED_PROCESS_AUTHORITY.git,
				workspace_state={
					"schema_version": 1,
					"head": "a" * 40,
					"dirty": False,
					"untracked_file_count": 0,
					"fingerprint": "b" * 64,
				},
			)

		self.assertIs(raised.exception, debt)
		adapter.assert_not_called()

	def test_deferred_materializer_cleanup_debt_cause_chain_is_not_converted(self) -> None:
		catalog = self._minimal_catalog(actions=(
			(
				"alpha",
				None,
				gf_validation_catalog.ValidationExecutorKind.IN_PROCESS,
			),
			(
				"beta",
				("python",),
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
		))
		debt = gf_process_supervisor.SupervisedProcessCleanupError(
			"fixture nested deferred materializer cleanup debt",
			pid=456,
			process_tree_empty=False,
		)
		try:
			raise debt
		except gf_process_supervisor.SupervisedProcessCleanupError:
			try:
				raise gf_maintenance.DeferredCommandMaterializationError(
					"fixture deferred materializer wrapper"
				) from debt
			except gf_maintenance.DeferredCommandMaterializationError as error:
				wrapped_error = error
		adapter = mock.Mock(return_value={"ok": True})
		binding = _validation_executor_binding(
			catalog,
			{"alpha": adapter},
			{"alpha": mock.Mock(side_effect=wrapped_error)},
		)

		with self.assertRaises(
			gf_maintenance.DeferredCommandMaterializationError
		) as raised:
			gf_maintenance.run_checks_with_active_snapshot(
				catalog.plan("suite", ["alpha"]),
				validation_executor_binding=binding,
				git_process=_SHARED_PROCESS_AUTHORITY.git,
				workspace_state={
					"schema_version": 1,
					"head": "a" * 40,
					"dirty": False,
					"untracked_file_count": 0,
					"fingerprint": "b" * 64,
				},
			)

		self.assertIs(raised.exception, wrapped_error)
		self.assertIs(raised.exception.__cause__, debt)
		adapter.assert_not_called()

	def test_run_checks_preserves_deferred_materializer_cleanup_debt_chain(self) -> None:
		debt = gf_process_supervisor.SupervisedProcessCleanupError(
			"fixture public-runner deferred materializer cleanup debt",
			pid=789,
			process_tree_empty=False,
		)
		try:
			raise debt
		except gf_process_supervisor.SupervisedProcessCleanupError:
			try:
				raise gf_maintenance.DeferredCommandMaterializationError(
					"fixture public-runner deferred materializer wrapper"
				) from debt
			except gf_maintenance.DeferredCommandMaterializationError as error:
				wrapped_error = error

		workspace_state = {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "b" * 64,
		}
		materializer = mock.Mock(side_effect=wrapped_error)
		materializers = dict(
			gf_maintenance.maintenance_deferred_command_materializer_registry()
		)
		materializers["release_metadata"] = materializer
		fingerprint = mock.Mock(return_value=workspace_state)
		with mock.patch.object(
			gf_maintenance,
			"reference_catalog_inputs",
			return_value=("fixture-reference", "fixture-boot", "fixture-smoke"),
		), mock.patch.object(
			gf_maintenance,
			"pin_godot_executable_selection",
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			fingerprint,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_deferred_command_materializer_registry",
			return_value=materializers,
		), mock.patch.object(
			gf_maintenance,
			"exception_has_cleanup_debt",
			wraps=gf_process_supervisor.exception_has_cleanup_debt,
		) as classify_debt, mock.patch.object(
			gf_maintenance,
			"run_command",
			side_effect=AssertionError("cleanup debt must stop command dispatch"),
		) as dispatch, mock.patch.object(
			gf_maintenance,
			"make_check_setup_failure",
			side_effect=AssertionError("cleanup debt must not become a setup result"),
		) as setup_failure:
			with self.assertRaises(
				gf_maintenance.DeferredCommandMaterializationError
			) as raised:
				gf_maintenance.run_checks(
					suite="release",
					checks=["release_metadata"],
					jobs=1,
					process_environment=_SHARED_PROCESS_AUTHORITY.environment,
				)

		self.assertIs(raised.exception, wrapped_error)
		self.assertIs(raised.exception.__cause__, debt)
		self.assertEqual(classify_debt.call_count, 3)
		self.assertTrue(all(
			call.args == (wrapped_error,)
			for call in classify_debt.call_args_list
		))
		materializer.assert_called_once()
		dispatch.assert_not_called()
		setup_failure.assert_not_called()
		self.assertEqual(fingerprint.call_count, 1)

	def test_deferred_materializer_is_not_called_for_unexecuted_actions(self) -> None:
		workspace_state = {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "b" * 64,
		}
		blocked_catalog = self._minimal_catalog()
		blocked_materializer = mock.Mock(return_value=("python", "beta.py"))
		blocked_binding = _validation_executor_binding(
			blocked_catalog,
			{"alpha": mock.Mock(return_value={"ok": False})},
			{"beta": blocked_materializer},
		)
		blocked_report = gf_maintenance.run_checks_with_active_snapshot(
			blocked_catalog.plan("suite", ["beta"]),
			validation_executor_binding=blocked_binding,
			git_process=_SHARED_PROCESS_AUTHORITY.git,
			workspace_state=workspace_state,
		)

		blocked_materializer.assert_not_called()
		self.assertEqual(blocked_report["results"][1]["execution"], "blocked")
		self.assertEqual(
			blocked_report["results"][1]["command"],
			[
				gf_maintenance.DEFERRED_COMMAND_SENTINEL,
				"subprocess",
				"beta",
			],
		)

		deadline_catalog = self._minimal_catalog(actions=(
			(
				"alpha",
				None,
				gf_validation_catalog.ValidationExecutorKind.IN_PROCESS,
			),
			(
				"beta",
				("python",),
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
		))
		deadline_materializer = mock.Mock(return_value=("python", "alpha.py"))
		deadline_binding = _validation_executor_binding(
			deadline_catalog,
			{"alpha": mock.Mock(return_value={"ok": True})},
			{"alpha": deadline_materializer},
		)
		deadline_report = gf_maintenance.run_checks_with_active_snapshot(
			deadline_catalog.plan("suite", ["alpha"]),
			validation_executor_binding=deadline_binding,
			git_process=_SHARED_PROCESS_AUTHORITY.git,
			suite_timeout_seconds=0,
			workspace_state=workspace_state,
		)

		deadline_materializer.assert_not_called()
		self.assertEqual(deadline_report["results"][0]["execution"], "not_started")
		self.assertEqual(
			deadline_report["results"][0]["command"],
			[
				gf_maintenance.DEFERRED_COMMAND_SENTINEL,
				"in_process",
				"alpha",
			],
		)

	def test_static_command_does_not_require_a_deferred_materializer(self) -> None:
		catalog = self._minimal_catalog(
			actions=((
				"release_metadata",
				("sentinel", "static-command"),
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),),
			dependencies=(),
			check_groups=(),
			suites=(("suite", ("release_metadata",)),),
			parallel_full_shard_suites=("suite",),
			timeout_overrides=(),
		)
		binding = _validation_executor_binding(catalog, {})

		self.assertEqual(
			gf_maintenance.materialize_check_command(
				"release_metadata",
				validation_executor_binding=binding,
				deferred_command_context=gf_maintenance.DeferredCommandContext(
					artifact_manifest="fixture.json",
					allow_breaking_api=True,
				),
			),
			["sentinel", "static-command"],
		)

	def test_in_process_failure_records_the_materialized_command(self) -> None:
		materialized_command = ["fixture-python", "fixture.py", "--sentinel"]
		result = gf_maintenance.run_in_process_check(
			"docs",
			materialized_command,
			mock.Mock(side_effect=RuntimeError("fixture failure")),
			10.0,
		)

		self.assertEqual(result.exit_code, 1)
		self.assertEqual(result.command, materialized_command)
		self.assertEqual(result.execution, "in_process")

	def test_in_process_cleanup_debt_escapes_unchanged(self) -> None:
		debt = gf_process_supervisor.SupervisedProcessCleanupError(
			"fixture in-process cleanup debt",
			pid=123,
			process_tree_empty=False,
		)
		with self.assertRaises(
			gf_process_supervisor.SupervisedProcessCleanupError
		) as raised:
			gf_maintenance.run_in_process_check(
				"docs",
				["fixture-python", "fixture.py"],
				mock.Mock(side_effect=debt),
				10.0,
			)

		self.assertIs(raised.exception, debt)
		self.assertTrue(raised.exception.cleanup_debt)
		self.assertFalse(raised.exception.process_boundary_quiescent)

	def test_invalid_parallel_jobs_return_a_structured_plan_setup_failure(self) -> None:
		plan = gf_maintenance._VALIDATION_CATALOG.plan("quick")
		for suite_timeout_seconds in (None, 0):
			with self.subTest(
				suite_timeout_seconds=suite_timeout_seconds
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				side_effect=AssertionError("invalid jobs must fail before workspace I/O"),
			) as fingerprint:
				report = gf_maintenance.run_checks(
					suite="quick",
					jobs=2,
					suite_timeout_seconds=suite_timeout_seconds,
				)

			self.assertFalse(report["ok"])
			self.assertEqual(report["suite"], "quick")
			self.assertEqual(report["checks"], list(plan.actions))
			self.assertEqual(report["check_graph"], plan.describe_graph())
			self.assertEqual(report["workspace_fingerprint"], "0" * 64)
			self.assertEqual(report["execution"], "serial")
			self.assertEqual(report["jobs"], 1)
			self.assertEqual(
				report["results"][0]["name"],
				"parallel_validation_setup",
			)
			self.assertIn(
				"Parallel check jobs are supported only",
				report["results"][0]["stderr"],
			)
			fingerprint.assert_not_called()

	def test_rejects_duplicate_declarations_and_members(self) -> None:
		input_spec = self._input_spec("alpha")
		invalid_overrides = {
			"action": {
				"actions": (
					(
						"alpha",
						("python",),
						gf_validation_catalog.ValidationExecutorKind.IN_PROCESS,
					),
					(
						"alpha",
						("other",),
						gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
					),
				),
			},
			"dependency owner": {
				"dependencies": (("beta", ("alpha",)), ("beta", ("alpha",))),
			},
			"dependency member": {
				"dependencies": (("beta", ("alpha", "alpha")),),
			},
			"group": {
				"check_groups": (("group", ("alpha",)), ("group", ("beta",))),
			},
			"group member": {
				"check_groups": (("group", ("alpha", "alpha")),),
			},
			"suite": {
				"suites": (("suite", ("alpha",)), ("suite", ("beta",))),
			},
			"suite member": {
				"suites": (("suite", ("alpha", "alpha")),),
			},
			"lane": {
				"parallel_full_shard_suites": ("suite", "suite"),
			},
			"timeout override": {
				"timeout_overrides": (("alpha", 1), ("alpha", 2)),
			},
			"input spec": {
				"input_specs": (input_spec, input_spec),
			},
		}
		for label, overrides in invalid_overrides.items():
			with self.subTest(label=label), self.assertRaises(
				gf_validation_catalog.ValidationCatalogError
			):
				self._minimal_catalog(**overrides)

	def test_rejects_unknown_references(self) -> None:
		invalid_overrides = {
			"dependency owner": {"dependencies": (("unknown", ("alpha",)),)},
			"dependency target": {"dependencies": (("beta", ("unknown",)),)},
			"group action": {"check_groups": (("group", ("unknown",)),)},
			"suite action": {"suites": (("suite", ("unknown",)),)},
			"lane suite": {"parallel_full_shard_suites": ("unknown",)},
			"timeout action": {"timeout_overrides": (("unknown", 1),)},
			"input spec action": {
				"input_specs": (self._input_spec("unknown"),),
			},
		}
		for label, overrides in invalid_overrides.items():
			with self.subTest(label=label), self.assertRaises(
				gf_validation_catalog.ValidationCatalogError
			):
				self._minimal_catalog(**overrides)
		with self.assertRaises(gf_validation_catalog.ValidationCatalogError):
			self._minimal_catalog().check_group("unknown")
		with self.assertRaises(gf_validation_catalog.ValidationCatalogError):
			self._minimal_catalog().timeout_floor_seconds("unknown")
		with self.assertRaises(gf_validation_catalog.ValidationCatalogError):
			self._minimal_catalog().executor_kind("unknown")
		with self.assertRaises(gf_validation_catalog.ValidationCatalogError):
			self._minimal_catalog().static_command("unknown")
		with self.assertRaises(gf_validation_catalog.ValidationCatalogError):
			self._minimal_catalog().input_spec("unknown")

	def test_rejects_non_contract_input_spec_values(self) -> None:
		for invalid_input_spec in (None, object(), {"check_name": "alpha"}):
			with self.subTest(
				invalid_input_spec=invalid_input_spec
			), self.assertRaises(
				gf_validation_catalog.ValidationCatalogError
			):
				self._minimal_catalog(input_specs=(invalid_input_spec,))

	def test_catalog_allows_an_explicit_all_subprocess_executor_policy(self) -> None:
		catalog = self._minimal_catalog(actions=(
			(
				"alpha",
				("python",),
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
			(
				"beta",
				None,
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
		))
		self.assertEqual(catalog.in_process_action_names, ())
		self.assertTrue(all(
			catalog.executor_kind(action_name)
			is gf_validation_catalog.ValidationExecutorKind.SUBPROCESS
			for action_name in catalog.action_names
		))

	def test_validation_executor_registries_must_close_catalog_exactly(self) -> None:
		catalog = self._minimal_catalog()
		adapter = lambda: {"ok": True}
		adapter_replacement = lambda: {"ok": False}
		materializer = lambda _context: ("python", "beta.py")
		materializer_replacement = lambda _context: ("replacement",)
		valid_adapters = {"alpha": adapter}
		valid_materializers = {"beta": materializer}
		validated = gf_maintenance.validate_validation_executor_registries(
			catalog,
			valid_adapters,
			valid_materializers,
		)
		self.assertIs(validated.catalog, catalog)
		self.assertEqual(tuple(validated.in_process_adapters), ("alpha",))
		self.assertEqual(tuple(validated.deferred_command_materializers), ("beta",))
		valid_adapters["alpha"] = adapter_replacement
		valid_adapters.clear()
		valid_materializers["beta"] = materializer_replacement
		valid_materializers.clear()
		self.assertIs(validated.in_process_adapters["alpha"], adapter)
		self.assertIs(
			validated.deferred_command_materializers["beta"],
			materializer,
		)
		with self.assertRaises(TypeError):
			validated.in_process_adapters["alpha"] = lambda: {"ok": False}
		with self.assertRaises(TypeError):
			validated.deferred_command_materializers["beta"] = (
				lambda _context: ("replacement",)
			)

		class DriftingCallableMapping(dict[str, object]):
			def __init__(self, name: str, binding: object) -> None:
				super().__init__({name: binding})
				self.binding = binding
				self.read_count = 0

			def __getitem__(self, key: str) -> object:
				self.read_count += 1
				return self.binding if self.read_count == 1 else object()

		drifting_adapters = DriftingCallableMapping("alpha", adapter)
		drifting_materializers = DriftingCallableMapping("beta", materializer)
		drift_binding = gf_maintenance.validate_validation_executor_registries(
			catalog,
			drifting_adapters,
			drifting_materializers,
		)
		self.assertEqual(drifting_adapters.read_count, 1)
		self.assertEqual(drifting_materializers.read_count, 1)
		self.assertIs(drift_binding.in_process_adapters["alpha"], adapter)
		self.assertIs(
			drift_binding.deferred_command_materializers["beta"],
			materializer,
		)

		class DuplicateKeyMapping(dict[str, object]):
			def __iter__(self):
				return iter(("alpha", "alpha"))

		invalid_adapter_registries = {
			"missing": {},
			"extra subprocess adapter": {
				"alpha": lambda: {"ok": True},
				"beta": lambda: {"ok": True},
			},
			"non-callable": {"alpha": object()},
			"non-string key": {1: lambda: {"ok": True}},
			"not a mapping": [("alpha", lambda: {"ok": True})],
			"duplicate key iteration": DuplicateKeyMapping({"alpha": adapter}),
		}
		for label, registry in invalid_adapter_registries.items():
			with self.subTest(label=label), self.assertRaises(
				gf_validation_catalog.ValidationCatalogError
			):
				gf_maintenance.validate_validation_executor_registries(
					catalog,
					registry,
					{"beta": materializer},
				)

		invalid_materializer_registries = {
			"missing": {},
			"extra static action": {
				"alpha": lambda _context: ("alpha",),
				"beta": materializer,
			},
			"non-callable": {"beta": object()},
			"non-string key": {1: materializer},
			"not a mapping": [("beta", materializer)],
		}
		for label, registry in invalid_materializer_registries.items():
			with self.subTest(label=label), self.assertRaises(
				gf_validation_catalog.ValidationCatalogError
			):
				gf_maintenance.validate_validation_executor_registries(
					catalog,
					{"alpha": adapter},
					registry,
				)

	def test_timeout_policy_rejects_non_positive_or_non_integer_seconds(self) -> None:
		for value in (True, 0, -1, 1.0, "1"):
			with self.subTest(default=value), self.assertRaises(
				gf_validation_catalog.ValidationCatalogError
			):
				self._minimal_catalog(default_timeout_seconds=value)
			with self.subTest(override=value), self.assertRaises(
				gf_validation_catalog.ValidationCatalogError
			):
				self._minimal_catalog(timeout_overrides=(("alpha", value),))

	def test_timeout_policy_rejects_malformed_override_declarations(self) -> None:
		for declarations in (
			(["alpha", 15],),
			(("alpha",),),
			(("alpha", 15, "extra"),),
		):
			with self.subTest(declarations=declarations), self.assertRaises(
				gf_validation_catalog.ValidationCatalogError
			):
				self._minimal_catalog(timeout_overrides=declarations)

	def test_dependency_topology_is_validated_during_catalog_construction(self) -> None:
		invalid_dependencies = {
			"self cycle": (("alpha", ("alpha",)),),
			"multi action cycle": (
				("alpha", ("beta",)),
				("beta", ("alpha",)),
			),
		}
		for label, dependencies in invalid_dependencies.items():
			with self.subTest(label=label), self.assertRaises(
				gf_validation_catalog.ValidationCatalogError
			) as raised:
				self._minimal_catalog(dependencies=dependencies)
			self.assertIsInstance(raised.exception.__cause__, ValueError)

	def test_distinguishes_deferred_commands_from_invalid_static_commands(self) -> None:
		catalog = self._minimal_catalog()
		self.assertEqual(catalog.action_names, ("alpha", "beta"))
		self.assertEqual(catalog.command_definitions(), {"alpha": ["python"]})
		deferred_in_process = self._minimal_catalog(actions=(
			(
				"alpha",
				None,
				gf_validation_catalog.ValidationExecutorKind.IN_PROCESS,
			),
			(
				"beta",
				None,
				gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
			),
		))
		self.assertEqual(deferred_in_process.command_definitions(), {})
		self.assertIs(
			deferred_in_process.executor_kind("alpha"),
			gf_validation_catalog.ValidationExecutorKind.IN_PROCESS,
		)

		for command in ([], (), ("",), (1,), "python"):
			with self.subTest(command=command), self.assertRaises(
				gf_validation_catalog.ValidationCatalogError
			):
				self._minimal_catalog(actions=(
					(
						"alpha",
						command,
						gf_validation_catalog.ValidationExecutorKind.IN_PROCESS,
					),
					(
						"beta",
						None,
						gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
					),
				))
		for actions in (
			(("alpha", ("python",)),),
			(("alpha", ("python",), "in_process"),),
			(("alpha", ("python",), True),),
		):
			with self.subTest(actions=actions), self.assertRaises(
				gf_validation_catalog.ValidationCatalogError
			):
				self._minimal_catalog(actions=actions)

	def test_constructor_inputs_and_accessors_are_detached(self) -> None:
		command = ["python"]
		dependencies = ["alpha"]
		group = ["alpha", "beta"]
		suite = ["alpha", "beta"]
		lanes = ["suite"]
		timeout_overrides = [("alpha", 15)]
		input_spec = self._input_spec("alpha")
		input_specs = [input_spec]
		catalog = self._minimal_catalog(
			actions=(
				(
					"alpha",
					command,
					gf_validation_catalog.ValidationExecutorKind.IN_PROCESS,
				),
				(
					"beta",
					None,
					gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
				),
			),
			dependencies=(("beta", dependencies),),
			check_groups=(("group", group),),
			suites=(("suite", suite),),
			parallel_full_shard_suites=lanes,
			timeout_overrides=timeout_overrides,
			input_specs=input_specs,
		)
		command.append("mutated")
		dependencies.append("beta")
		group.append("alpha")
		suite.append("alpha")
		lanes.append("suite")
		timeout_overrides.append(("beta", 30))
		input_specs.append(self._input_spec("beta"))

		command_copy = catalog.command_definitions()
		static_command_copy = catalog.static_command("alpha")
		dependency_copy = catalog.dependencies()
		group_copy = catalog.check_groups()
		suite_copy = catalog.suites()
		timeout_copy = catalog.timeout_overrides()
		command_copy["alpha"].append("mutated")
		assert static_command_copy is not None
		static_command_copy.append("mutated")
		dependency_copy["beta"].append("beta")
		group_copy["group"].append("alpha")
		suite_copy["suite"].append("alpha")
		timeout_copy["alpha"] = 99

		self.assertEqual(catalog.action_names, ("alpha", "beta"))
		self.assertEqual(catalog.command_definitions(), {"alpha": ["python"]})
		self.assertEqual(catalog.static_command("alpha"), ["python"])
		self.assertIsNone(catalog.static_command("beta"))
		self.assertEqual(catalog.dependencies(), {"beta": ["alpha"]})
		self.assertEqual(catalog.check_groups(), {"group": ["alpha", "beta"]})
		self.assertEqual(catalog.suites(), {"suite": ["alpha", "beta"]})
		self.assertEqual(catalog.parallel_full_shard_suites, ("suite",))
		self.assertEqual(catalog.default_timeout_seconds, 10)
		self.assertEqual(catalog.timeout_overrides(), {"alpha": 15})
		self.assertEqual(catalog.timeout_floor_seconds("alpha"), 15)
		self.assertEqual(catalog.timeout_floor_seconds("beta"), 10)
		self.assertIs(type(catalog.input_specs), tuple)
		self.assertEqual(catalog.input_specs, (input_spec,))
		self.assertIs(catalog.input_spec("alpha"), input_spec)
		self.assertIsNone(catalog.input_spec("beta"))
		self.assertEqual(catalog.in_process_action_names, ("alpha",))
		self.assertEqual(catalog.deferred_action_names, ("beta",))
		self.assertIs(
			catalog.executor_kind("alpha"),
			gf_validation_catalog.ValidationExecutorKind.IN_PROCESS,
		)
		self.assertIs(
			catalog.executor_kind("beta"),
			gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
		)

	@staticmethod
	def _snapshot_context() -> gf_validation_catalog.ValidationCatalogContext:
		return gf_validation_catalog.ValidationCatalogContext(
			python_executable="<python>",
			root=ROOT,
			godot_log_directory=Path("<log>"),
			gut_lifecycle_cli_resource_path=(
				"res://tests/gf_core/support/gf_gut_cli.gd"
			),
			gut_shard_config_disabled_argument="-gconfig=",
			gut_lifecycle_hook_arguments=(
				"-gpre_run_script=res://tests/gf_core/support/gf_gut_pre_run_hook.gd",
				"-gpost_run_script=res://tests/gf_core/support/gf_gut_post_run_hook.gd",
			),
			default_reference_project="../gf-reference-project",
			reference_boot_scene="res://scenes/app/driftbound_boot.tscn",
			reference_smoke_scene="res://tests/smoke/driftbound_smoke.tscn",
		)

	@staticmethod
	def _context(label: str) -> gf_validation_catalog.ValidationCatalogContext:
		return gf_validation_catalog.ValidationCatalogContext(
			python_executable=f"<python-{label}>",
			root=ROOT / label,
			godot_log_directory=Path(f"<log-{label}>"),
			gut_lifecycle_cli_resource_path=f"<gut-cli-{label}>",
			gut_shard_config_disabled_argument=f"<gut-config-{label}>",
			gut_lifecycle_hook_arguments=(f"-ghook={label}",),
			default_reference_project=f"<reference-{label}>",
			reference_boot_scene=f"<boot-{label}>",
			reference_smoke_scene=f"<smoke-{label}>",
		)

	@staticmethod
	def _minimal_catalog(**overrides: object) -> gf_validation_catalog.ValidationCatalog:
		arguments: dict[str, object] = {
			"actions": (
				(
					"alpha",
					("python",),
					gf_validation_catalog.ValidationExecutorKind.IN_PROCESS,
				),
				(
					"beta",
					None,
					gf_validation_catalog.ValidationExecutorKind.SUBPROCESS,
				),
			),
			"dependencies": (("beta", ("alpha",)),),
			"check_groups": (("group", ("alpha", "beta")),),
			"suites": (("suite", ("alpha", "beta")),),
			"parallel_full_shard_suites": ("suite",),
			"default_timeout_seconds": 10,
			"timeout_overrides": (("alpha", 15),),
			"input_specs": (),
		}
		arguments.update(overrides)
		return gf_validation_catalog.ValidationCatalog(**arguments)

	@staticmethod
	def _input_spec(action_name: str) -> gf_validation_contracts.CheckInputSpec:
		return gf_validation_contracts.CheckInputSpec(
			check_name=action_name,
			source_rules=(
				gf_validation_contracts.PathRule("exact", "README.md"),
			),
			implementation_files=("tools/gf_maintenance.py",),
		)

	@staticmethod
	def _normalize_snapshot_value(value: object) -> object:
		if isinstance(value, str):
			return value.replace(ROOT.as_posix(), "<root>")
		if isinstance(value, list):
			return [
				ValidationCatalogContractTests._normalize_snapshot_value(item)
				for item in value
			]
		return value


class StrictJsonBoundaryTests(unittest.TestCase):
	def test_strict_encoder_rejects_non_finite_numbers(self) -> None:
		with self.assertRaises(ValueError):
			gf_maintenance_rendering.encode_strict_json({"value": float("nan")})

	def test_internal_complete_output_writer_enforces_exact_utf8_limit_atomically(self) -> None:
		data = {"ok": True, "text": "\u754c\nfixture"}
		encoded = gf_maintenance_rendering.encode_strict_json(
			data,
			indent=2,
			trailing_newline=True,
		).encode("utf-8")
		with tempfile.TemporaryDirectory() as temporary_directory:
			path = Path(temporary_directory) / "report.json"
			gf_maintenance.write_internal_complete_output_evidence_report(
				path,
				data,
				max_utf8_bytes=len(encoded),
			)
			self.assertEqual(path.read_bytes(), encoded)
			original_bytes = path.read_bytes()
			with self.assertRaisesRegex(ValueError, "bounded UTF-8 size limit"):
				gf_maintenance.write_internal_complete_output_evidence_report(
					path,
					data,
					max_utf8_bytes=len(encoded) - 1,
				)
			self.assertEqual(path.read_bytes(), original_bytes)
			self.assertEqual(list(path.parent.iterdir()), [path])

	def test_atomic_json_writer_preserves_old_target_when_replace_fails(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			target = Path(temporary_directory) / "report.json"
			target.write_text('{"old":true}\n', encoding="utf-8")
			with mock.patch.object(
				gf_maintenance_rendering.os,
				"replace",
				side_effect=OSError("injected replace failure"),
			):
				with self.assertRaises(OSError):
					gf_maintenance_rendering.write_json_object_atomic(target, {"new": True})
			self.assertEqual(target.read_text(encoding="utf-8"), '{"old":true}\n')
			self.assertEqual(list(target.parent.glob(f".{target.name}.*.tmp")), [])

	def test_lsp_json_writers_are_strict_and_atomic(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			target = Path(temporary_directory) / "lsp.json"
			target.write_text('{"old":true}\n', encoding="utf-8")
			with self.assertRaises(ValueError):
				gdscript_lsp_diagnostics._write_json(target, {"value": float("inf")})
			self.assertEqual(target.read_text(encoding="utf-8"), '{"old":true}\n')
			gdscript_lsp_diagnostics._write_connection_audit_log(target, {"ok": True})
			self.assertEqual(json.loads(target.read_text(encoding="utf-8")), {"ok": True})


class GutLifecycleSmokeBoundaryTests(unittest.TestCase):
	def test_unresolved_godot_preserves_json_without_process_dispatch(self) -> None:
		stdout = io.StringIO()
		resolution_error = gf_maintenance.GodotExecutableResolutionError(
			"fixture unresolved"
		)
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.dict(
			gf_gut_lifecycle_smoke.os.environ,
			{"PATH": "frozen-lifecycle-path"},
			clear=True,
		), mock.patch.object(
			gf_gut_lifecycle_smoke,
			"LOG_ROOT",
			Path(temporary_directory),
		), mock.patch.object(
			gf_gut_lifecycle_smoke,
			"resolve_godot_executable",
			side_effect=resolution_error,
		) as resolve_godot, mock.patch.object(
			gf_gut_lifecycle_smoke,
			"run_supervised_process",
			side_effect=AssertionError("unresolved Godot must not dispatch scenarios"),
		) as supervisor, mock.patch.object(
			sys,
			"argv",
			["gf_gut_lifecycle_smoke.py", "--json"],
		), contextlib.redirect_stdout(stdout):
			exit_code = gf_gut_lifecycle_smoke.main()

		payload = json.loads(stdout.getvalue())
		self.assertEqual(exit_code, 1)
		self.assertFalse(payload["ok"])
		self.assertEqual(payload["scenario_count"], len(gf_gut_lifecycle_smoke.SCENARIOS))
		self.assertEqual(payload["failure_count"], payload["scenario_count"])
		self.assertTrue(all(
			scenario["process_exit_code"] is None
			and scenario["issues"] == [
				"Godot executable could not be resolved before scenario dispatch."
			]
			for scenario in payload["scenarios"]
		))
		self.assertEqual(resolve_godot.call_count, len(gf_gut_lifecycle_smoke.SCENARIOS))
		self.assertTrue(all(
			call.args == ("godot",)
			and call.kwargs["cwd"] == ROOT
			and call.kwargs["environment"]["PATH"] == "frozen-lifecycle-path"
			for call in resolve_godot.call_args_list
		))
		supervisor.assert_not_called()

	def test_structured_no_child_start_remains_an_ordinary_scenario_failure(self) -> None:
		original = FileNotFoundError("fixture missing Godot")
		start_error = gf_maintenance.gf_process_supervisor.SupervisedProcessStartError(
			original
		)
		scenario = gf_gut_lifecycle_smoke.SCENARIOS[2]
		mixed_bootstrap_name = "gF_gUt_LiFeCyClE_bOoTsTrAp_FiXtUrE"
		base_environment = {
			"PATH": "frozen-lifecycle-path",
			"FROZEN_MARKER": "captured",
			mixed_bootstrap_name: "stale",
		}
		real_setter = gf_executable_resolution.set_owned_environment_value
		real_remover = gf_executable_resolution.remove_owned_environment_value

		def set_as_windows(
			environment: dict[str, str],
			name: str,
			value: str,
			*,
			platform_name: str | None = None,
		) -> None:
			real_setter(environment, name, value, platform_name="nt")

		def remove_as_windows(
			environment: dict[str, str],
			name: str,
			*,
			platform_name: str | None = None,
		) -> None:
			real_remover(environment, name, platform_name="nt")

		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.dict(
			gf_gut_lifecycle_smoke.os.environ,
			{"PATH": "ambient-path", "AMBIENT_ONLY": "must-not-leak"},
			clear=True,
		), mock.patch.object(
			gf_gut_lifecycle_smoke,
			"LOG_ROOT",
			Path(temporary_directory),
		), mock.patch.object(
			gf_gut_lifecycle_smoke,
			"set_owned_environment_value",
			side_effect=set_as_windows,
		), mock.patch.object(
			gf_gut_lifecycle_smoke,
			"remove_owned_environment_value",
			side_effect=remove_as_windows,
		), mock.patch.object(
			gf_gut_lifecycle_smoke,
			"resolve_godot_executable",
			return_value="fixture-godot",
		) as resolve_godot, mock.patch.object(
			gf_gut_lifecycle_smoke,
			"run_supervised_process",
			side_effect=start_error,
		) as supervisor:
			result = gf_gut_lifecycle_smoke.run_scenario(
				"fixture-godot",
				scenario,
				base_environment=base_environment,
			)
		self.assertFalse(result.ok)
		self.assertIn("before a child was created", result.issues[0])
		self.assertIs(
			resolve_godot.call_args.kwargs["environment"],
			supervisor.call_args.kwargs["environment"],
		)
		dispatch_environment = supervisor.call_args.kwargs["environment"]
		self.assertEqual(dispatch_environment["PATH"], "frozen-lifecycle-path")
		self.assertEqual(dispatch_environment["FROZEN_MARKER"], "captured")
		self.assertEqual(
			dispatch_environment[
				gf_gut_lifecycle_smoke.BOOTSTRAP_FIXTURE_ENVIRONMENT
			],
			scenario.bootstrap_fixture,
		)
		self.assertEqual(
			[
				name
				for name in dispatch_environment
				if name.casefold()
				== gf_gut_lifecycle_smoke.BOOTSTRAP_FIXTURE_ENVIRONMENT.casefold()
			],
			[gf_gut_lifecycle_smoke.BOOTSTRAP_FIXTURE_ENVIRONMENT],
		)
		self.assertNotIn("AMBIENT_ONLY", dispatch_environment)
		self.assertEqual(base_environment[mixed_bootstrap_name], "stale")
		self.assertNotIn(
			gf_gut_lifecycle_smoke.BOOTSTRAP_FIXTURE_ENVIRONMENT,
			base_environment,
		)

	def test_clean_scenario_scrubs_all_windows_bootstrap_aliases(self) -> None:
		original = FileNotFoundError("fixture missing Godot")
		start_error = gf_process_supervisor.SupervisedProcessStartError(original)
		canonical_name = gf_gut_lifecycle_smoke.BOOTSTRAP_FIXTURE_ENVIRONMENT
		mixed_name = "gF_gUt_LiFeCyClE_bOoTsTrAp_FiXtUrE"
		nonce_name = gf_gut_lifecycle_smoke.GUT_SHARD_OBSERVATION_NONCE_ENVIRONMENT
		path_name = gf_gut_lifecycle_smoke.GUT_SHARD_OBSERVATION_PATH_ENVIRONMENT
		base_environment = {
			"PATH": "frozen-lifecycle-path",
			canonical_name: "canonical-stale",
			mixed_name: "mixed-stale",
			nonce_name: "canonical-stale-nonce",
			"gF_gUt_ShArD_oBsErVaTiOn_NoNcE": "mixed-stale-nonce",
			path_name: "canonical-stale-path",
			"gF_gUt_ShArD_oBsErVaTiOn_PaTh": "mixed-stale-path",
		}
		base_snapshot = dict(base_environment)
		real_remover = gf_executable_resolution.remove_owned_environment_value

		def remove_as_windows(
			environment: dict[str, str],
			name: str,
			*,
			platform_name: str | None = None,
		) -> None:
			real_remover(environment, name, platform_name="nt")

		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_gut_lifecycle_smoke,
			"LOG_ROOT",
			Path(temporary_directory),
		), mock.patch.object(
			gf_gut_lifecycle_smoke,
			"remove_owned_environment_value",
			side_effect=remove_as_windows,
		), mock.patch.object(
			gf_gut_lifecycle_smoke,
			"resolve_godot_executable",
			return_value="fixture-godot",
		) as resolve_godot, mock.patch.object(
			gf_gut_lifecycle_smoke,
			"run_supervised_process",
			side_effect=start_error,
		) as supervisor:
			result = gf_gut_lifecycle_smoke.run_scenario(
				"fixture-godot",
				gf_gut_lifecycle_smoke.SCENARIOS[0],
				base_environment=base_environment,
			)

		self.assertFalse(result.ok)
		resolver_environment = resolve_godot.call_args.kwargs["environment"]
		self.assertIs(
			resolver_environment,
			supervisor.call_args.kwargs["environment"],
		)
		for scrubbed_name in (canonical_name, nonce_name, path_name):
			self.assertFalse(any(
				name.casefold() == scrubbed_name.casefold()
				for name in resolver_environment
			))
		self.assertEqual(base_environment, base_snapshot)

	def test_structured_start_diagnostics_ignore_hostile_string(self) -> None:
		class HostileMissing(FileNotFoundError):
			def __str__(self) -> str:
				raise SystemExit("fixture hostile start-error text")

		original = HostileMissing("fixture missing Godot")
		start_error = gf_maintenance.gf_process_supervisor.SupervisedProcessStartError(
			original
		)
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_gut_lifecycle_smoke,
			"LOG_ROOT",
			Path(temporary_directory),
		), mock.patch.object(
			gf_gut_lifecycle_smoke,
			"resolve_godot_executable",
			return_value="fixture-godot",
		), mock.patch.object(
			gf_gut_lifecycle_smoke,
			"run_supervised_process",
			side_effect=start_error,
		):
			result = gf_gut_lifecycle_smoke.run_scenario(
				"fixture-godot",
				gf_gut_lifecycle_smoke.SCENARIOS[0],
				base_environment={"PATH": "frozen-lifecycle-path"},
			)
		self.assertFalse(result.ok)
		self.assertIn("detail unavailable", result.issues[0])

	def test_unclassified_supervisor_failure_escapes_with_boundary_debt(self) -> None:
		original = RuntimeError("fixture supervisor failure")
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_gut_lifecycle_smoke,
			"LOG_ROOT",
			Path(temporary_directory),
		), mock.patch.object(
			gf_gut_lifecycle_smoke,
			"resolve_godot_executable",
			return_value="fixture-godot",
		), mock.patch.object(
			gf_gut_lifecycle_smoke,
			"run_supervised_process",
			side_effect=original,
		):
			with self.assertRaises(
				gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError
			) as raised:
				gf_gut_lifecycle_smoke.run_scenario(
					"fixture-godot",
					gf_gut_lifecycle_smoke.SCENARIOS[0],
					base_environment={"PATH": "frozen-lifecycle-path"},
				)
		self.assertIs(raised.exception.__cause__, original)

	def test_returned_unproved_scenario_boundary_is_rejected(self) -> None:
		unproved = gf_maintenance.gf_process_supervisor.SupervisedProcessResult(
			return_code=0,
			stdout="",
			stderr="",
			timed_out=False,
			duration_seconds=0.1,
			pid=123,
			process_boundary_quiescent=False,
		)
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_gut_lifecycle_smoke,
			"LOG_ROOT",
			Path(temporary_directory),
		), mock.patch.object(
			gf_gut_lifecycle_smoke,
			"resolve_godot_executable",
			return_value="fixture-godot",
		), mock.patch.object(
			gf_gut_lifecycle_smoke,
			"run_supervised_process",
			return_value=unproved,
		):
			with self.assertRaises(
				gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError
			):
				gf_gut_lifecycle_smoke.run_scenario(
					"fixture-godot",
					gf_gut_lifecycle_smoke.SCENARIOS[0],
					base_environment={"PATH": "frozen-lifecycle-path"},
				)


class ProjectLayoutProfileTests(unittest.TestCase):
	AUTHORITATIVE_RESULT_FIELDS = (
		"root",
		"profile_found",
		"profile_path",
		"profile_id",
		"profile_source_digest",
		"file_count",
		"issue_count",
		"error_count",
		"warning_count",
		"info_count",
		"issue_kind_counts",
		"reason_code_counts",
		"severity_counts",
		"issues",
		"ok",
	)
	FIXTURE_PATH = (
		ROOT
		/ "tests/gf_core/tools/project_layout/fixtures/profile_conformance_v1.json"
	)

	@classmethod
	def _fixture(cls) -> dict[str, object]:
		return json.loads(cls.FIXTURE_PATH.read_text(encoding="utf-8"))

	def assert_shadow_preserves_legacy_authority(
		self,
		legacy: dict[str, object],
		shadow: dict[str, object],
	) -> None:
		for field_name in self.AUTHORITATIVE_RESULT_FIELDS:
			with self.subTest(authoritative_field=field_name):
				self.assertEqual(shadow[field_name], legacy[field_name])
		self.assertEqual(
			0 if shadow["ok"] else 1,
			0 if legacy["ok"] else 1,
			"CLI exit semantics must remain bound to the legacy authoritative result.",
		)

	@staticmethod
	def git_inventory_capture_factory(
		tracked_stdout: bytes,
		untracked_stdout: bytes = b"",
	) -> object:
		def capture(
			command: list[str],
			**_kwargs: object,
		) -> gf_process_supervisor.SupervisedBinaryProcessResult:
			stdout = tracked_stdout if command[-1] == "--cached" else untracked_stdout
			return gf_process_supervisor.SupervisedBinaryProcessResult(
				return_code=0,
				stdout=stdout,
				stderr=b"",
				timed_out=False,
				duration_seconds=0.01,
				pid=123,
				cleanup_complete=True,
			)

		return capture

	def assert_single_git_inventory_capture(self, run_mock: mock.Mock) -> None:
		commands = [call.args[0] for call in run_mock.call_args_list]
		self.assertEqual(len(commands), 2)
		self.assertTrue(Path(commands[0][0]).is_absolute())
		self.assertEqual(commands[1][0], commands[0][0])
		self.assertEqual(
			[command[1:] for command in commands],
			[
				["ls-files", "-z", "--cached"],
				["ls-files", "-z", "--others", "--exclude-standard"],
			],
		)
		environments = [
			call.kwargs["environment"] for call in run_mock.call_args_list
		]
		self.assertEqual(environments[0], environments[1])
		self.assertEqual(environments[0]["GIT_OPTIONAL_LOCKS"], "0")
		self.assertEqual(environments[0]["GIT_CONFIG_NOSYSTEM"], "1")
		self.assertEqual(environments[0]["GIT_TERMINAL_PROMPT"], "0")

	def test_canonical_fixture_matches_strict_python_contract_and_runtime(self) -> None:
		fixture = self._fixture()
		self.assertEqual(fixture["fixture_schema_version"], 1)
		cases = fixture["cases"]
		case_ids = [case["id"] for case in cases]
		self.assertEqual(len(case_ids), 33)
		self.assertEqual(len(case_ids), len(set(case_ids)))
		for case in cases:
			with self.subTest(case=case["id"]):
				expected = case["expected"]
				compilation = gf_project_layout_profile.compile_project_profile_v1(
					case["profile"],
					"fixture.json",
				)
				self.assertEqual(
					compilation["ok"],
					expected["strict_contract_valid"],
					compilation["issues"],
				)
				if "reason_code" in expected:
					self.assertTrue(any(
						issue.get("reason_code") == expected["reason_code"]
						for issue in compilation["issues"]
					), compilation["issues"])
				if not compilation["ok"]:
					continue
				runtime_issues = (
					gf_project_layout_profile.audit_compiled_project_profile_runtime(
						compilation,
						"fixture.json",
						case["inventory"],
					)
				)
				self.assertEqual(
					len(runtime_issues),
					expected["python_issue_count"],
					runtime_issues,
				)
				self.assertEqual(
					sorted(issue.get("kind", "") for issue in runtime_issues),
					sorted(expected["python_runtime_issue_kinds"]),
					runtime_issues,
				)
				if "python_runtime_reason_code" in expected:
					self.assertTrue(any(
						issue.get("reason_code")
						== expected["python_runtime_reason_code"]
						and issue.get("path") == expected["python_runtime_issue_path"]
						for issue in runtime_issues
					), runtime_issues)
				if "excluded_path" in expected:
					self.assertFalse(any(
						issue.get("path") == expected["excluded_path"]
						for issue in runtime_issues
					), runtime_issues)

	def test_default_adapter_is_strict_and_migration_modes_are_explicit(self) -> None:
		profile = {
			"schema_version": 1,
			"id": "neutral.mode_contract",
			"zones": [],
			"rules": [{
				"id": "bounded",
				"kind": "bucket_size",
				"roots": ["src"],
				"max_files": 1,
				"extensions": [".gd"],
			}],
		}
		inventory = ["src/main.gd", "src/readme.md"]
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_project_layout_profile,
			"ROOT",
			Path(temporary_directory),
		), mock.patch.object(
			gf_project_layout_profile,
			"collect_project_profile_paths",
			return_value={"paths": inventory, "errors": []},
		), mock.patch.object(
			gf_project_layout_profile,
			"collect_project_profile_path_views",
			return_value={
				"legacy": {"paths": inventory, "errors": []},
				"strict": {"paths": inventory, "errors": []},
			},
		):
			(Path(temporary_directory) / "profile.json").write_text(
				json.dumps(profile),
				encoding="utf-8",
			)
			strict = gf_maintenance.project_profile_boundary(
				profile_path="profile.json",
				fail_on_warnings=True,
			)
			legacy = gf_maintenance.project_profile_boundary(
				profile_path="profile.json",
				fail_on_warnings=True,
				profile_mode="legacy",
			)
			shadow = gf_maintenance.project_profile_boundary(
				profile_path="profile.json",
				fail_on_warnings=True,
				profile_mode="shadow",
			)

		self.assertEqual(strict["profile_mode"], "strict")
		self.assertFalse(strict["deprecated"])
		self.assertIsNone(strict["removal_version"])
		self.assertFalse(strict["ok"])
		self.assertEqual(strict["authoritative_profile_mode"], "strict")
		self.assertRegex(strict["contract_digest"], r"^[0-9a-f]{64}$")
		self.assertEqual(legacy["profile_mode"], "legacy")
		self.assertTrue(legacy["deprecated"])
		self.assertEqual(legacy["removal_version"], "12.0.0")
		self.assertTrue(legacy["ok"])
		self.assertEqual(shadow["profile_mode"], "shadow")
		self.assertTrue(shadow["deprecated"])
		self.assertEqual(shadow["removal_version"], "12.0.0")
		self.assertEqual(shadow["authoritative_profile_mode"], "legacy")
		self.assertTrue(shadow["ok"])
		self.assertIsInstance(shadow["shadow"], dict)
		self.assertFalse(shadow["shadow"]["authoritative"])
		self.assertTrue(shadow["shadow"]["migration_only"])
		self.assertEqual(shadow["shadow"]["runtime_issue_count"], 1)

	def test_strict_admission_failure_precedes_inventory(self) -> None:
		invalid_profile = {
			"schema_version": 2,
			"id": "neutral.future",
			"zones": [],
			"rules": [],
		}
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_project_layout_profile,
			"ROOT",
			Path(temporary_directory),
		), mock.patch.object(
			gf_project_layout_profile,
			"collect_project_profile_paths",
			return_value={"paths": [], "errors": []},
		) as collect_paths, mock.patch.object(
			gf_project_layout_profile,
			"collect_project_profile_path_views",
			return_value={
				"legacy": {"paths": [], "errors": []},
				"strict": {"paths": [], "errors": []},
			},
		):
			(Path(temporary_directory) / "profile.json").write_text(
				json.dumps(invalid_profile),
				encoding="utf-8",
			)
			result = gf_maintenance.project_profile_boundary(
				profile_path="profile.json",
			)
		collect_paths.assert_not_called()
		self.assertFalse(result["ok"])
		self.assertFalse(result["evaluation_complete"])
		self.assertEqual(result["skip_reason"], "profile_contract_invalid")
		self.assertEqual(result["file_count"], 0)

	def test_shadow_strict_admission_failure_does_not_rescan_inventory(self) -> None:
		profile = {
			"schema_version": 2,
			"id": "neutral.shadow_admission_failure",
			"zones": [{
				"id": "required_root",
				"roots": ["required"],
				"required": True,
			}],
			"rules": [],
		}
		with tempfile.TemporaryDirectory() as temporary_directory:
			(Path(temporary_directory) / "profile.json").write_text(
				json.dumps(profile),
				encoding="utf-8",
			)
			with mock.patch.object(
				gf_project_layout_profile,
				"ROOT",
				Path(temporary_directory),
			), mock.patch.object(
				gf_project_layout_profile.gf_process_supervisor,
				"run_supervised_process_bytes",
				side_effect=self.git_inventory_capture_factory(b"src/main.gd\0"),
			) as legacy_git_run:
				legacy = gf_maintenance.project_profile_boundary(
					profile_path="profile.json",
					profile_mode="legacy",
				)
			self.assert_single_git_inventory_capture(legacy_git_run)

			with mock.patch.object(
				gf_project_layout_profile,
				"ROOT",
				Path(temporary_directory),
			), mock.patch.object(
				gf_project_layout_profile.gf_process_supervisor,
				"run_supervised_process_bytes",
				side_effect=self.git_inventory_capture_factory(b"src/main.gd\0"),
			) as shadow_git_run:
				shadow = gf_maintenance.project_profile_boundary(
					profile_path="profile.json",
					profile_mode="shadow",
				)
			self.assert_single_git_inventory_capture(shadow_git_run)

		self.assert_shadow_preserves_legacy_authority(legacy, shadow)
		self.assertFalse(shadow["shadow"]["inventory_available"])
		self.assertFalse(shadow["shadow"]["evaluation_complete"])
		self.assertEqual(
			shadow["shadow"]["skip_reason"],
			"profile_contract_invalid",
		)

	def test_shadow_uses_legacy_authority_when_strict_inventory_is_rejected(self) -> None:
		profile = {
			"schema_version": 1,
			"id": "neutral.shadow_authority",
			"zones": [{
				"id": "canonical_legacy_root",
				"roots": ["src/main.gd"],
				"required": True,
			}],
			"rules": [],
		}
		raw_inventory = b"src\\main.gd\0src/\xff.gd\0"
		with tempfile.TemporaryDirectory() as temporary_directory:
			(Path(temporary_directory) / "profile.json").write_text(
				json.dumps(profile),
				encoding="utf-8",
			)
			with mock.patch.object(
				gf_project_layout_profile,
				"ROOT",
				Path(temporary_directory),
			), mock.patch.object(
				gf_project_layout_profile.gf_process_supervisor,
				"run_supervised_process_bytes",
				side_effect=self.git_inventory_capture_factory(raw_inventory),
			) as legacy_git_run:
				legacy = gf_maintenance.project_profile_boundary(
					profile_path="profile.json",
					profile_mode="legacy",
				)
			self.assert_single_git_inventory_capture(legacy_git_run)

			with mock.patch.object(
				gf_project_layout_profile,
				"ROOT",
				Path(temporary_directory),
			), mock.patch.object(
				gf_project_layout_profile.gf_process_supervisor,
				"run_supervised_process_bytes",
				side_effect=self.git_inventory_capture_factory(raw_inventory),
			) as shadow_git_run:
				shadow = gf_maintenance.project_profile_boundary(
					profile_path="profile.json",
					profile_mode="shadow",
				)
			self.assert_single_git_inventory_capture(shadow_git_run)

		self.assert_shadow_preserves_legacy_authority(legacy, shadow)
		self.assertEqual(shadow["file_count"], 2)
		self.assertEqual(shadow["issues"], [])
		self.assertFalse(shadow["shadow"]["inventory_available"])
		self.assertEqual(shadow["shadow"]["skip_reason"], "inventory_unavailable")
		self.assertEqual(
			[issue["kind"] for issue in shadow["shadow"]["issues"]],
			["project_profile_tracked_scan_failed"],
		)

	def test_shadow_fails_closed_when_legacy_inventory_is_unavailable(self) -> None:
		profile = {
			"schema_version": 1,
			"id": "neutral.shadow_legacy_inventory_failure",
			"zones": [],
			"rules": [],
		}
		legacy_inventory = {
			"paths": [],
			"errors": [gf_project_layout_profile.make_project_profile_issue(
				"project_profile_tracked_scan_failed",
				"",
				"legacy inventory is unavailable.",
			)],
		}
		strict_inventory = {
			"paths": [],
			"errors": [gf_project_layout_profile.make_project_profile_issue(
				"project_profile_tracked_scan_failed",
				"",
				"strict inventory is unavailable.",
			)],
		}

		with tempfile.TemporaryDirectory() as temporary_directory:
			(Path(temporary_directory) / "profile.json").write_text(
				json.dumps(profile),
				encoding="utf-8",
			)
			with mock.patch.object(
				gf_project_layout_profile,
				"ROOT",
				Path(temporary_directory),
			), mock.patch.object(
				gf_project_layout_profile,
				"collect_project_profile_paths",
				return_value=legacy_inventory,
			) as legacy_collect_paths:
				legacy = gf_maintenance.project_profile_boundary(
					profile_path="profile.json",
					profile_mode="legacy",
				)
			legacy_collect_paths.assert_called_once()
			legacy_git_process = legacy_collect_paths.call_args.kwargs["git_process"]
			self.assertIsInstance(
				legacy_git_process,
				gf_process_authority.FrozenGitProcess,
			)
			self.assertTrue(Path(legacy_git_process.executable).is_absolute())

			with mock.patch.object(
				gf_project_layout_profile,
				"ROOT",
				Path(temporary_directory),
			), mock.patch.object(
				gf_project_layout_profile,
				"collect_project_profile_path_views",
				return_value={
					"legacy": legacy_inventory,
					"strict": strict_inventory,
				},
			) as shadow_collect_views:
				shadow = gf_maintenance.project_profile_boundary(
					profile_path="profile.json",
					profile_mode="shadow",
				)
			shadow_collect_views.assert_called_once()
			shadow_git_process = shadow_collect_views.call_args.kwargs["git_process"]
			self.assertIsInstance(
				shadow_git_process,
				gf_process_authority.FrozenGitProcess,
			)
			self.assertTrue(Path(shadow_git_process.executable).is_absolute())

		self.assert_shadow_preserves_legacy_authority(legacy, shadow)
		self.assertFalse(shadow["ok"])
		self.assertEqual(shadow["file_count"], 0)
		self.assertEqual(
			[issue["kind"] for issue in shadow["issues"]],
			["project_profile_tracked_scan_failed"],
		)
		self.assertEqual(0 if shadow["ok"] else 1, 1)

	def test_git_capture_oserror_is_stable_and_fail_closed(self) -> None:
		profile = {
			"schema_version": 1,
			"id": "neutral.git_capture_oserror",
			"zones": [],
			"rules": [],
		}

		def git_capture(command: list[str], **_kwargs: object) -> object:
			if command[-1] == "--cached":
				raise OSError("machine-specific detail must not leak")
			factory = self.git_inventory_capture_factory(b"", b"")
			return factory(command)

		with tempfile.TemporaryDirectory() as temporary_directory:
			(Path(temporary_directory) / "profile.json").write_text(
				json.dumps(profile),
				encoding="utf-8",
			)
			with mock.patch.object(
				gf_project_layout_profile,
				"ROOT",
				Path(temporary_directory),
			), mock.patch.object(
				gf_project_layout_profile.gf_process_supervisor,
				"run_supervised_process_bytes",
				side_effect=git_capture,
			) as legacy_git_run:
				legacy = gf_maintenance.project_profile_boundary(
					profile_path="profile.json",
					profile_mode="legacy",
				)
			self.assert_single_git_inventory_capture(legacy_git_run)

			with mock.patch.object(
				gf_project_layout_profile,
				"ROOT",
				Path(temporary_directory),
			), mock.patch.object(
				gf_project_layout_profile.gf_process_supervisor,
				"run_supervised_process_bytes",
				side_effect=git_capture,
			) as shadow_git_run:
				shadow = gf_maintenance.project_profile_boundary(
					profile_path="profile.json",
					profile_mode="shadow",
				)
			self.assert_single_git_inventory_capture(shadow_git_run)

		self.assert_shadow_preserves_legacy_authority(legacy, shadow)
		self.assertFalse(legacy["ok"])
		self.assertEqual(0 if legacy["ok"] else 1, 1)
		self.assertEqual(
			[issue["kind"] for issue in legacy["issues"]],
			["project_profile_tracked_scan_failed"],
		)
		self.assertEqual(legacy["issues"][0]["message"], "git path scan failed.")
		self.assertFalse(shadow["shadow"]["inventory_available"])
		self.assertEqual(
			[issue["kind"] for issue in shadow["shadow"]["issues"]],
			["project_profile_tracked_scan_failed"],
		)

	def test_git_capture_does_not_swallow_unexpected_or_control_flow_errors(self) -> None:
		for raised_error in (
			RuntimeError("unexpected failure"),
			KeyboardInterrupt(),
			SystemExit(2),
		):
			with self.subTest(error_type=type(raised_error).__name__), mock.patch.object(
				gf_project_layout_profile.gf_process_supervisor,
				"run_supervised_process_bytes",
				side_effect=raised_error,
			):
				with self.assertRaises(type(raised_error)):
					gf_project_layout_profile.capture_git_paths(
						["ls-files", "-z", "--cached"],
						git_process=_SHARED_PROCESS_AUTHORITY.git,
					)

	def test_git_capture_execution_and_cleanup_share_one_deadline(self) -> None:
		completed = gf_process_supervisor.SupervisedBinaryProcessResult(
			return_code=0,
			stdout=b"ok",
			stderr=b"",
			timed_out=False,
			duration_seconds=0.1,
			pid=123,
			cleanup_complete=True,
		)
		with (
			mock.patch.object(
				gf_project_layout_profile.time,
				"perf_counter",
				return_value=100.0,
			) as clock,
			mock.patch.object(
				gf_project_layout_profile.gf_process_supervisor,
				"run_supervised_process_bytes",
				return_value=completed,
			) as supervisor,
			mock.patch.object(
				gf_project_layout_profile.gf_process_supervisor,
				"require_supervised_binary_quiet_boundary",
				return_value=completed,
			) as quiet_boundary,
		):
			actual = gf_project_layout_profile.capture_subprocess_bytes_bounded(
				["fixture-git", "status"],
				cwd=ROOT,
				environment={"PATH": "fixture-path"},
				max_stdout_bytes=16,
				max_stderr_bytes=16,
			)

		self.assertEqual(actual["returncode"], 0)
		self.assertEqual(actual["stdout"], b"ok")
		clock.assert_called_once_with()
		self.assertEqual(supervisor.call_args.kwargs["deadline"], 130.0)
		self.assertEqual(quiet_boundary.call_args.kwargs["deadline"], 130.0)

	def test_git_capture_maps_clean_result_observed_after_deadline_to_timeout(self) -> None:
		completed = gf_process_supervisor.SupervisedBinaryProcessResult(
			return_code=0,
			stdout=b"late",
			stderr=b"",
			timed_out=False,
			duration_seconds=0.1,
			pid=123,
			cleanup_complete=True,
		)
		with (
			mock.patch.object(
				gf_project_layout_profile.time,
				"perf_counter",
				side_effect=(100.0, 131.0),
			),
			mock.patch.object(
				gf_project_layout_profile.gf_process_supervisor,
				"run_supervised_process_bytes",
				return_value=completed,
			),
		):
			actual = gf_project_layout_profile.capture_subprocess_bytes_bounded(
				["fixture-git", "status"],
				cwd=ROOT,
				environment={"PATH": "fixture-path"},
				max_stdout_bytes=16,
				max_stderr_bytes=16,
			)

		self.assertEqual(actual["error_kind"], "timeout")
		self.assertEqual(actual["stdout"], b"")
		self.assertEqual(actual["stderr"], b"")

	def test_git_inventory_subprocess_capture_has_a_hard_byte_ceiling(self) -> None:
		process_result = gf_process_supervisor.SupervisedBinaryProcessResult(
			return_code=-9,
			stdout=b"x" * 64,
			stderr=b"",
			timed_out=False,
			duration_seconds=0.01,
			pid=123,
			stdout_truncated=True,
			cleanup_complete=True,
		)
		with mock.patch.object(
			gf_project_layout_profile,
			"PROJECT_PROFILE_GIT_STDOUT_MAX_BYTES",
			64,
		), mock.patch.object(
			gf_project_layout_profile.gf_process_supervisor,
			"run_supervised_process_bytes",
			return_value=process_result,
		):
			capture = gf_project_layout_profile.capture_git_paths(
				["ls-files", "-z", "--cached"],
				git_process=_SHARED_PROCESS_AUTHORITY.git,
			)

		self.assertEqual(capture["error_kind"], "resource_limit")
		self.assertEqual(capture["stdout"], b"")

	def test_git_inventory_cleanup_debt_precedes_limits_and_stops_later_capture(self) -> None:
		process_result = gf_process_supervisor.SupervisedBinaryProcessResult(
			return_code=124,
			stdout=b"partial",
			stderr=b"partial",
			timed_out=True,
			duration_seconds=0.5,
			pid=123,
			stdout_truncated=True,
			stderr_truncated=True,
			cleanup_complete=False,
		)
		with mock.patch.object(
			gf_project_layout_profile.gf_process_supervisor,
			"run_supervised_process_bytes",
			return_value=process_result,
		) as supervisor:
			with self.assertRaises(
				gf_process_supervisor.SupervisedProcessCleanupError
			):
				gf_project_layout_profile.collect_project_profile_path_views(
					git_process=_SHARED_PROCESS_AUTHORITY.git
				)

		self.assertEqual(supervisor.call_count, 1)

	def test_git_inventory_descendant_pipe_failure_is_stable_and_fail_closed(self) -> None:
		process_result = gf_process_supervisor.SupervisedBinaryProcessResult(
			return_code=0,
			stdout=b"partial\0",
			stderr=b"",
			timed_out=False,
			duration_seconds=0.5,
			pid=123,
			output_drain_failed=True,
			cleanup_complete=True,
		)
		with mock.patch.object(
			gf_project_layout_profile.gf_process_supervisor,
			"run_supervised_process_bytes",
			return_value=process_result,
		):
			capture = gf_project_layout_profile.capture_git_paths(
				["ls-files", "-z", "--cached"],
				git_process=_SHARED_PROCESS_AUTHORITY.git,
			)

		self.assertEqual(capture["error_kind"], "process_tree")
		self.assertEqual(capture["stdout"], b"")
		self.assertEqual(capture["error"], "git path scan failed.")

	def test_inventory_count_bytes_and_sort_work_limits_are_terminal(self) -> None:
		def path_result(paths: list[str]) -> dict[str, object]:
			return {
				"paths": paths,
				"path_count": len(paths),
				"utf8_bytes": sum(len(path.encode("utf-8")) for path in paths),
				"error": "",
				"error_kind": "",
			}

		cases = (
			("PROJECT_PROFILE_INVENTORY_MAX_PATHS", 1, ["a.gd", "b.gd"]),
			("PROJECT_PROFILE_INVENTORY_MAX_UTF8_BYTES", 4, ["alpha.gd"]),
			("PROJECT_PROFILE_INVENTORY_MAX_SORT_WORK_UNITS", 1, ["a.gd", "b.gd"]),
		)
		for constant_name, limit, paths in cases:
			with self.subTest(limit=constant_name), mock.patch.object(
				gf_project_layout_profile,
				constant_name,
				limit,
			):
				payload = gf_project_layout_profile.make_project_profile_paths_payload(
					path_result(paths),
					path_result([]),
				)
			self.assertEqual(payload["paths"], [])
			self.assertEqual(len(payload["errors"]), 1)
			self.assertEqual(
				payload["errors"][0]["reason_code"],
				"PROJECT_LAYOUT_PROFILE_RESOURCE_LIMIT_EXCEEDED",
			)

	def test_inventory_resource_limit_preserves_all_mode_authority_contracts(self) -> None:
		profile = {
			"schema_version": 1,
			"id": "neutral.inventory_resource",
			"zones": [],
			"rules": [],
		}
		with tempfile.TemporaryDirectory() as temporary_directory:
			(Path(temporary_directory) / "profile.json").write_text(
				json.dumps(profile),
				encoding="utf-8",
			)
			results: dict[str, dict[str, object]] = {}
			for profile_mode in gf_project_layout_profile.PROFILE_MODES:
				with self.subTest(profile_mode=profile_mode), mock.patch.object(
					gf_project_layout_profile,
					"ROOT",
					Path(temporary_directory),
				), mock.patch.object(
					gf_project_layout_profile,
					"PROJECT_PROFILE_GIT_STDOUT_MAX_BYTES",
					64,
				), mock.patch.object(
					gf_project_layout_profile.gf_process_supervisor,
					"run_supervised_process_bytes",
					side_effect=self.git_inventory_capture_factory(b"x" * 1024),
				) as popen_mock:
					results[profile_mode] = gf_maintenance.project_profile_boundary(
						profile_path="profile.json",
						profile_mode=profile_mode,
					)
				self.assert_single_git_inventory_capture(popen_mock)

		self.assert_shadow_preserves_legacy_authority(
			results["legacy"],
			results["shadow"],
		)
		for profile_mode in ("strict", "legacy"):
			self.assertFalse(results[profile_mode]["ok"])
			self.assertEqual(results[profile_mode]["file_count"], 0)
			self.assertEqual(
				results[profile_mode]["issues"][0]["reason_code"],
				"PROJECT_LAYOUT_PROFILE_RESOURCE_LIMIT_EXCEEDED",
			)
		self.assertEqual(
			results["shadow"]["shadow"]["issues"][0]["reason_code"],
			"PROJECT_LAYOUT_PROFILE_RESOURCE_LIMIT_EXCEEDED",
		)

	def test_audit_work_and_diagnostic_floods_discard_partial_results(self) -> None:
		profile = {
			"schema_version": 1,
			"id": "neutral.budget",
			"zones": [],
			"rules": [{
				"id": "names",
				"kind": "naming_convention",
				"roots": [],
				"pattern": "^[a-z]+$",
			}],
		}
		compilation = gf_project_layout_profile.compile_project_profile_v1(
			profile,
			"fixture.json",
		)
		self.assertTrue(compilation["ok"], compilation["issues"])

		with mock.patch.object(
			gf_project_layout_profile,
			"PROJECT_PROFILE_AUDIT_MAX_WORK_UNITS",
			1,
		):
			work_issues = (
				gf_project_layout_profile.audit_compiled_project_profile_runtime(
					compilation,
					"fixture.json",
					["bad.gd"],
				)
			)
		self.assertEqual(len(work_issues), 1)
		self.assertEqual(
			work_issues[0]["reason_code"],
			"PROJECT_LAYOUT_PROFILE_RESOURCE_LIMIT_EXCEEDED",
		)

		with mock.patch.object(
			gf_project_layout_profile,
			"PROJECT_PROFILE_MAX_DIAGNOSTICS",
			8,
		):
			diagnostic_issues = (
				gf_project_layout_profile.audit_compiled_project_profile_runtime(
					compilation,
					"fixture.json",
					["BAD_%03d.gd" % index for index in range(32)],
				)
			)
		self.assertEqual(len(diagnostic_issues), 1)
		self.assertEqual(
			diagnostic_issues[0]["reason_code"],
			"PROJECT_LAYOUT_PROFILE_RESOURCE_LIMIT_EXCEEDED",
		)

	def test_regex_portable_subset_rejects_dialect_and_backtracking_hazards(self) -> None:
		for pattern in (r"(a+)+$", r"\R", "[é]", "a*a$"):
			with self.subTest(pattern=pattern):
				profile = {
					"schema_version": 1,
					"id": "neutral.regex_budget",
					"zones": [],
					"rules": [{
						"id": "names",
						"kind": "naming_convention",
						"roots": [],
						"pattern": pattern,
					}],
				}
				compilation = gf_project_layout_profile.compile_project_profile_v1(
					profile,
					"fixture.json",
				)
			self.assertFalse(compilation["ok"])
			self.assertEqual(
				[
					issue.get("reason_code")
					for issue in compilation["issues"]
					if issue.get("reason_code")
				],
				["PROJECT_LAYOUT_PROFILE_REGEX_UNSAFE"],
			)

	def test_all_modes_use_bounded_regular_file_reading(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_project_layout_profile,
			"ROOT",
			Path(temporary_directory),
		), mock.patch.object(
			gf_project_layout_profile,
			"PROJECT_PROFILE_STRICT_MAX_BYTES",
			64,
		), mock.patch.object(
			gf_project_layout_profile,
			"collect_project_profile_paths",
			return_value={"paths": [], "errors": []},
		) as collect_paths:
			(Path(temporary_directory) / "profile.json").write_bytes(b"{" + b"x" * 80)
			for profile_mode in gf_project_layout_profile.PROFILE_MODES:
				with self.subTest(profile_mode=profile_mode):
					collect_paths.reset_mock()
					result = gf_maintenance.project_profile_boundary(
						profile_path="profile.json",
						profile_mode=profile_mode,
					)
					self.assertTrue(any(
						issue.get("kind") == "invalid_project_profile_json"
						for issue in (
							result["shadow"]["issues"]
							if profile_mode == "shadow"
							else result["issues"]
						)
					))
					if profile_mode == "strict":
						collect_paths.assert_not_called()

	def test_capabilities_are_mode_scoped_and_shadow_is_not_authoritative(self) -> None:
		strict = gf_project_layout_profile.project_profile_capabilities(
			profile_mode="strict",
		)
		legacy = gf_project_layout_profile.project_profile_capabilities(
			profile_mode="legacy",
		)
		shadow = gf_project_layout_profile.project_profile_capabilities(
			profile_mode="shadow",
		)
		self.assertTrue(strict["contract_enforced"])
		self.assertTrue(strict["authoritative"])
		self.assertFalse(strict["deprecated"])
		self.assertFalse(legacy["contract_enforced"])
		self.assertTrue(legacy["deprecated"])
		self.assertEqual(legacy["removal_version"], "12.0.0")
		self.assertTrue(shadow["contract_enforced"])
		self.assertFalse(shadow["authoritative"])
		self.assertTrue(shadow["deprecated"])
		self.assertEqual(
			set(strict["rule_kinds"]),
			set(gf_project_layout_profile.project_profile_rule_handler_registry()),
		)
		self.assertNotIn("extensions", strict["rule_fields"]["bucket_size"])
		self.assertIn("extensions", legacy["rule_fields"]["bucket_size"])
		self.assertEqual(strict["regex_dialect"], "portable_safe_v1")
		self.assertEqual(strict["limits"]["inventory_paths"], 20_000)
		self.assertEqual(strict["limits"]["diagnostics"], 256)
		self.assertNotIn(
			"regex_engine_portability_not_guaranteed",
			strict["limitation_codes"],
		)

	def test_cli_accepts_only_the_three_product_modes_and_defaults_to_strict(self) -> None:
		command = [
			sys.executable,
			str(ROOT / "tools/gf_maintenance.py"),
			"project-profile-boundary",
			"--json",
		]
		result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
		self.assertEqual(result.returncode, 0, result.stderr)
		self.assertEqual(json.loads(result.stdout)["profile_mode"], "strict")
		invalid = subprocess.run(
			[*command[:-1], "--profile-mode", "strict-v1", "--json"],
			cwd=ROOT,
			capture_output=True,
			text=True,
		)
		self.assertEqual(invalid.returncode, 2)
		self.assertIn("invalid choice", invalid.stderr)

	def test_renderer_marks_deprecated_migration_mode(self) -> None:
		data = gf_project_layout_profile.project_profile_boundary(
			profile_mode="legacy",
			git_process=_SHARED_PROCESS_AUTHORITY.git,
		)
		rendered = gf_maintenance_rendering.render_project_profile_boundary_text(data)
		self.assertIn("mode=legacy", rendered)
		self.assertIn("deprecated: mode=legacy removal_version=12.0.0", rendered)


class ProcessSupervisorPosixWatchdogTests(unittest.TestCase):
	class _SyntheticControl(BaseException):
		pass

	class _PipeHelper:
		def __init__(self) -> None:
			control_read_fd, control_write_fd = os.pipe()
			status_read_fd, status_write_fd = os.pipe()
			self.control_reader = os.fdopen(control_read_fd, "rb", buffering=0)
			self.stdin = os.fdopen(control_write_fd, "wb", buffering=0)
			self.stdout = os.fdopen(status_read_fd, "rb", buffering=0)
			self.status_writer = os.fdopen(status_write_fd, "wb", buffering=0)
			self.pid = 7319
			self.returncode: int | None = None
			self._pidfd_closed = False

		def poll(self) -> int | None:
			return self.returncode

		def close_pidfd(self) -> None:
			self._pidfd_closed = True

		def pidfd_closed(self) -> bool:
			return self._pidfd_closed

		def close_fixture(self) -> None:
			for stream in (
				self.control_reader,
				self.stdin,
				self.stdout,
				self.status_writer,
			):
				with contextlib.suppress(BaseException):
					stream.close()

	def _new_transport(
		self,
	) -> tuple[
		gf_process_supervisor._PosixWatchdogTransport,
		ProcessSupervisorPosixWatchdogTests._PipeHelper,
	]:
		helper = self._PipeHelper()
		transport = gf_process_supervisor._PosixWatchdogTransport(
			helper,  # type: ignore[arg-type]
			nonce="a" * 64,
			deadline=time.perf_counter() + 5.0,
			deadline_ns=time.monotonic_ns() + 5_000_000_000,
		)
		return transport, helper

	def test_status_eof_fails_fast_and_revokes_control_authority(self) -> None:
		transport, helper = self._new_transport()
		try:
			helper.status_writer.close()
			with self.assertRaises(
				gf_process_supervisor._PosixWatchdogProtocolError
			):
				transport.poll()
			self.assertTrue(helper.stdin.closed)
			status = transport.cleanup_status()
			self.assertFalse(status.cleanup_complete)
			self.assertEqual(status.error_type, "_PosixWatchdogProtocolError")
		finally:
			helper.close_fixture()

	def test_status_rejects_trailing_bytes_after_authenticated_quiet(self) -> None:
		transport, helper = self._new_transport()
		quiet = {
			"version": gf_process_supervisor.POSIX_WATCHDOG_PROTOCOL_VERSION,
			"nonce": "a" * 64,
			"type": "QUIET",
			"helper_pid": helper.pid,
			"server_pid": 0,
			"process_group_id": 0,
			"return_code": 0,
			"trigger": "startup_error",
			"ready": False,
			"child_created": False,
			"tree_empty": True,
			"direct_reaped": False,
			"cancelled": False,
			"error_type": "RuntimeError",
		}
		try:
			helper.status_writer.write(
				json.dumps(quiet, separators=(",", ":")).encode("ascii")
				+ b"\ntrailing"
			)
			helper.status_writer.flush()
			with self.assertRaises(
				gf_process_supervisor._PosixWatchdogProtocolError
			):
				transport.poll()
			self.assertTrue(helper.stdin.closed)
			self.assertFalse(transport.cleanup_status().cleanup_complete)
		finally:
			helper.close_fixture()

	def test_spawn_launch_rethrows_first_control_after_second_worker_starts(self) -> None:
		operation = gf_process_supervisor._PosixWatchdogSpawnOperation(
			deadline=time.perf_counter() + 5.0,
			deadline_ns=time.monotonic_ns() + 5_000_000_000,
			nonce="b" * 64,
		)
		control = self._SyntheticControl("first worker start interrupted")
		starts = 0

		class FixtureThread:
			def __init__(self, *, target: object, name: str, daemon: bool) -> None:
				_ = (target, name, daemon)

			def start(self) -> None:
				nonlocal starts
				starts += 1
				if starts == 1:
					raise control

		with mock.patch.object(
			gf_process_supervisor.threading,
			"Thread",
			FixtureThread,
		):
			with self.assertRaises(self._SyntheticControl) as raised:
				operation.launch()

		self.assertIs(raised.exception, control)
		self.assertEqual(starts, 2)

	def test_spawn_claim_lock_timeout_publishes_abandon_decision_without_blocking(
		self,
	) -> None:
		operation = gf_process_supervisor._PosixWatchdogSpawnOperation(
			deadline=time.perf_counter() + 5.0,
			deadline_ns=time.monotonic_ns() + 5_000_000_000,
			nonce="f" * 64,
		)
		operation._ready.set()
		operation._state_lock.acquire()
		try:
			deadline = time.perf_counter() + 0.05
			started = time.perf_counter()
			handoff = operation.claim_before_deadline(deadline)
			elapsed = time.perf_counter() - started
		finally:
			operation._state_lock.release()

		self.assertIsNone(handoff)
		self.assertTrue(operation._decision.is_set())
		self.assertLess(elapsed, 0.2)

	def test_ack_keeps_publication_control_over_later_ordinary_error(self) -> None:
		operation = gf_process_supervisor._PosixWatchdogSpawnOperation(
			deadline=time.perf_counter() + 5.0,
			deadline_ns=time.monotonic_ns() + 5_000_000_000,
			nonce="c" * 64,
		)
		transport = object()
		operation._transport = transport  # type: ignore[assignment]
		handoff = gf_process_supervisor._PosixWatchdogSpawnHandoff(transport)  # type: ignore[arg-type]
		slot = gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
		lease = _fixture_process_lease_facade()
		control = self._SyntheticControl("publication committed interruption")

		def checkpoint(name: str) -> None:
			if name == "process_lease_publication_committed":
				raise control
			if name == "process_lease_claim_ack_committed":
				raise RuntimeError("later ordinary acknowledgement failure")

		with mock.patch.object(
			gf_process_supervisor,
			"_process_supervision_checkpoint",
			side_effect=checkpoint,
		):
			with self.assertRaises(self._SyntheticControl) as raised:
				operation.acknowledge_claim(
					handoff,
					lease=lease,
					publication_slot=slot,
					deadline=time.perf_counter() + 5.0,
				)

		self.assertIs(raised.exception, control)
		self.assertTrue(operation.claim_acknowledged())
		self.assertIs(slot.get(), lease)

	def test_deferred_close_control_error_waits_for_quiet_then_rethrows(self) -> None:
		control = self._SyntheticControl("control close interrupted")
		wait_called = False
		quiet_status = gf_process_supervisor.SupervisedBinaryCleanupStatus(
			complete=True,
			cleanup_complete=True,
			owner_closed=True,
			process_tree_empty=True,
			pid=7319,
		)

		class FixtureTransport:
			def close_control(self) -> None:
				raise control

			def wait_quiet_and_reaped(self, _deadline: float | None) -> bool:
				nonlocal wait_called
				wait_called = True
				return True

			def cleanup_status(self) -> gf_process_supervisor.SupervisedBinaryCleanupStatus:
				return quiet_status

		operation = gf_process_supervisor._PosixWatchdogDeferredCleanupOperation(
			FixtureTransport()  # type: ignore[arg-type]
		)
		with self.assertRaises(self._SyntheticControl) as raised:
			operation.wait(1.0)

		self.assertIs(raised.exception, control)
		self.assertTrue(wait_called)

	def test_cached_quiet_never_publishes_redundant_cancel_at_reap_edge(self) -> None:
		deadline = time.perf_counter() + 5.0
		quiet_status = gf_process_supervisor.SupervisedBinaryCleanupStatus(
			complete=True,
			cleanup_complete=True,
			owner_closed=True,
			process_tree_empty=True,
			pid=7319,
		)

		class FixtureTransport:
			server_pid = 7319

			def __init__(self) -> None:
				self.wait_calls = 0
				self.cancel_calls = 0

			def quiet_payload(self) -> dict[str, object]:
				return {
					"return_code": 7,
					"trigger": "early_exit",
					"cancelled": False,
				}

			def wait_quiet_and_reaped(self, _deadline: float) -> bool:
				self.wait_calls += 1
				# Model the deadline edge where the wait result is stale but the
				# immediately following status snapshot observes finalization.
				return False

			def request_cancel(self, *, deadline: float) -> None:
				_ = deadline
				self.cancel_calls += 1
				raise AssertionError("cached QUIET must suppress redundant CANCEL")

			def close_control(self) -> None:
				return

			def cleanup_status(
				self,
			) -> gf_process_supervisor.SupervisedBinaryCleanupStatus:
				return quiet_status

		transport = FixtureTransport()
		lease = gf_process_supervisor._PosixWatchdogProcessLease(
			transport,  # type: ignore[arg-type]
			command=(sys.executable, "-c", "pass"),
			cwd=ROOT,
			started_at=time.perf_counter(),
			deadline=deadline,
		)

		result = lease.cancel_and_close(deadline=deadline)

		self.assertEqual(transport.wait_calls, 1)
		self.assertEqual(transport.cancel_calls, 0)
		self.assertEqual(result.return_code, 7)
		self.assertFalse(result.cancelled)
		self.assertTrue(result.process_boundary_quiescent)

	def test_partial_transport_cleanup_retries_all_resources_and_prefers_control(self) -> None:
		control = self._SyntheticControl("first raw control close interrupted")

		class RecoveringStream:
			def __init__(self, first_error: BaseException | None = None) -> None:
				self.closed = False
				self.first_error = first_error

			def close(self) -> None:
				if self.first_error is not None:
					error = self.first_error
					self.first_error = None
					raise error
				self.closed = True

		class RecoveringHelper:
			def __init__(self) -> None:
				self.stdin = RecoveringStream(control)
				self.stdout = RecoveringStream()
				self.pid = 7319
				self._pidfd_closed = False

			def poll(self) -> int | None:
				return 0 if self.stdin.closed else None

			def close_pidfd(self) -> None:
				self._pidfd_closed = True

			def pidfd_closed(self) -> bool:
				return self._pidfd_closed

		helper = RecoveringHelper()
		operation = gf_process_supervisor._PosixWatchdogSpawnOperation(
			deadline=time.perf_counter() + 5.0,
			deadline_ns=time.monotonic_ns() + 5_000_000_000,
			nonce="d" * 64,
		)
		status, preferred_error, _preferred_traceback = (
			operation._cleanup_failed_helper_construction(
				helper,  # type: ignore[arg-type]
				None,
				RuntimeError("ordinary transport construction failure"),
			)
		)

		self.assertTrue(status.cleanup_complete)
		self.assertTrue(helper.stdin.closed)
		self.assertTrue(helper.stdout.closed)
		self.assertTrue(helper.pidfd_closed())
		self.assertIs(preferred_error, control)

	def test_abandoned_transport_retries_finalize_and_retains_control(self) -> None:
		control = self._SyntheticControl("first finalize interrupted")
		quiet_status = gf_process_supervisor.SupervisedBinaryCleanupStatus(
			complete=True,
			cleanup_complete=True,
			owner_closed=True,
			process_tree_empty=True,
			pid=7319,
		)

		class FixtureTransport:
			def __init__(self) -> None:
				self._state_lock = threading.Lock()
				self._helper_return_code: int | None = 0
				self.finalize_calls = 0

			def request_cancel(self, *, deadline: float) -> None:
				_ = deadline

			def close_control(self) -> None:
				return

			def _pump_status_once(self, *, deadline: float, wait: bool) -> None:
				_ = (deadline, wait)

			def _try_reap_helper(self) -> None:
				return

			def finalize(self) -> bool:
				self.finalize_calls += 1
				if self.finalize_calls == 1:
					raise control
				return True

			def cleanup_status(self) -> gf_process_supervisor.SupervisedBinaryCleanupStatus:
				return quiet_status

		transport = FixtureTransport()
		operation = gf_process_supervisor._PosixWatchdogSpawnOperation(
			deadline=time.perf_counter() + 5.0,
			deadline_ns=time.monotonic_ns() + 5_000_000_000,
			nonce="e" * 64,
		)
		status, preferred_error, _preferred_traceback = (
			operation._finish_abandoned_transport(  # type: ignore[arg-type]
				transport
			)
		)

		self.assertTrue(status.cleanup_complete)
		self.assertEqual(transport.finalize_calls, 2)
		self.assertIs(preferred_error, control)


class ProcessSupervisorBinaryCaptureTests(unittest.TestCase):
	def test_binary_spawn_worker_wraps_original_when_cleanup_is_not_quiet(self) -> None:
		primary = RuntimeError("synthetic spawn failure after possible child creation")
		dirty_status = gf_process_supervisor.SupervisedBinaryCleanupStatus(
			complete=True,
			cleanup_complete=False,
			owner_closed=True,
			process_tree_empty=False,
			pid=7319,
			notes=("synthetic process tree remained live",),
			error_type=type(primary).__name__,
		)
		deferred_handle = mock.Mock()
		with self.assertRaises(
			gf_process_supervisor.SupervisedProcessCleanupError
		) as raised:
			gf_process_supervisor._raise_binary_original_or_cleanup_debt(
				primary,
				primary.__traceback__,
				message="fixture spawn cleanup remained unproved",
				status=dirty_status,
				deferred_cleanup=deferred_handle,
			)

		self.assertIs(raised.exception.__cause__, primary)
		self.assertIs(raised.exception.original_error, primary)
		self.assertTrue(raised.exception.cleanup_debt)
		self.assertFalse(raised.exception.process_boundary_quiescent)
		self.assertEqual(raised.exception.pid, 7319)
		self.assertEqual(raised.exception.cleanup_status, dirty_status)
		self.assertIs(raised.exception.deferred_cleanup, deferred_handle)

	def test_binary_monitor_preserves_primary_but_wraps_cleanup_failure(self) -> None:
		primary = RuntimeError("synthetic binary monitor failure")
		cleanup = RuntimeError("synthetic binary confirmation failure")
		original_owner_factory = gf_process_supervisor._new_process_tree_owner
		owner_holder: list[gf_process_supervisor._ProcessTreeOwner] = []
		original_close_holder: list[Callable[[float], list[str]]] = []

		def failing_owner_factory() -> gf_process_supervisor._ProcessTreeOwner:
			owner = original_owner_factory()
			owner_holder.append(owner)
			original_confirmation = owner.confirm_cleanup_after_reap_before_deadline
			original_close = owner.close_before_deadline
			original_close_holder.append(original_close)
			owner.wait_for_close_completion = (  # type: ignore[method-assign]
				lambda _timeout_seconds: False
			)

			def failing_confirmation(deadline: float) -> list[str]:
				notes = original_confirmation(deadline)
				raise cleanup

			owner.confirm_cleanup_after_reap_before_deadline = (  # type: ignore[method-assign]
				failing_confirmation
			)

			def unproved_close(_deadline: float) -> list[str]:
				return ["synthetic owner close remained unproved"]

			owner.close_before_deadline = unproved_close  # type: ignore[method-assign]
			return owner

		with mock.patch.object(
			gf_process_supervisor,
			"_new_process_tree_owner",
			side_effect=failing_owner_factory,
		), mock.patch.object(
			gf_process_supervisor,
			"_prepare_binary_pipe_for_polling",
			side_effect=primary,
		):
			with self.assertRaises(
				gf_process_supervisor.SupervisedProcessCleanupError
			) as raised:
				gf_process_supervisor.run_supervised_process_bytes(
					[sys.executable, "-c", "pass"],
					cwd=ROOT,
					timeout_seconds=5.0,
					environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
					max_stdout_bytes=1024,
					max_stderr_bytes=1024,
				)

		self.assertIs(raised.exception.__cause__, primary)
		self.assertIs(raised.exception.original_error, primary)
		self.assertFalse(raised.exception.owner_closed)
		self.assertFalse(raised.exception.cleanup_complete)
		self.assertTrue(
			any("confirmation failed" in note for note in raised.exception.notes),
			raised.exception.notes,
		)
		self.assertIsNotNone(raised.exception.deferred_cleanup)
		assert raised.exception.deferred_cleanup is not None
		owner_holder[0].close_before_deadline = original_close_holder[0]  # type: ignore[method-assign]
		self.assertTrue(raised.exception.deferred_cleanup.wait(2.0))

	def test_binary_output_pipe_close_failure_is_cleanup_debt(self) -> None:
		original_owner_factory = gf_process_supervisor._new_process_tree_owner
		retained_pipes: list[object] = []

		class UnclosablePipe:
			def __init__(self, pipe: object) -> None:
				self.pipe = pipe
				self.allow_close = False

			@property
			def closed(self) -> bool:
				return bool(self.pipe.closed)  # type: ignore[attr-defined]

			def fileno(self) -> int:
				return self.pipe.fileno()  # type: ignore[attr-defined,no-any-return]

			def close(self) -> None:
				if not self.allow_close:
					raise OSError("synthetic binary pipe close failure")
				self.pipe.close()  # type: ignore[attr-defined]

		def owner_factory() -> gf_process_supervisor._ProcessTreeOwner:
			owner = original_owner_factory()
			original_start = owner.start_bytes

			def start_with_unclosable_stdout(
				command: list[str],
				*,
				cwd: Path,
				environment: dict[str, str],
			) -> subprocess.Popen[bytes]:
				process = original_start(command, cwd=cwd, environment=environment)
				assert process.stdout is not None
				wrapped_pipe = UnclosablePipe(process.stdout)
				retained_pipes.append(wrapped_pipe)
				process.stdout = wrapped_pipe  # type: ignore[assignment]
				return process

			owner.start_bytes = start_with_unclosable_stdout  # type: ignore[method-assign]
			return owner

		try:
			with mock.patch.object(
				gf_process_supervisor,
				"_new_process_tree_owner",
				side_effect=owner_factory,
			):
				with self.assertRaises(
					gf_process_supervisor.SupervisedProcessCleanupError
				) as raised:
					gf_process_supervisor.run_supervised_process_bytes(
						[sys.executable, "-c", "pass"],
						cwd=ROOT,
						timeout_seconds=5.0,
						environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
						max_stdout_bytes=1024,
						max_stderr_bytes=1024,
					)
		finally:
			for retained_pipe in retained_pipes:
				retained_pipe.allow_close = True  # type: ignore[attr-defined]
			assert raised.exception.deferred_cleanup is not None
			try:
				raised.exception.deferred_cleanup.wait(2.0)
			except OSError:
				# The deferred authority retains the first close failure until the
				# boundary is quiet, then faithfully propagates it to the observer.
				pass
			final_snapshot = raised.exception.deferred_cleanup.snapshot()
			self.assertTrue(final_snapshot.cleanup_complete, final_snapshot)

		self.assertIsInstance(raised.exception.original_error, OSError)
		self.assertTrue(raised.exception.owner_closed)
		self.assertTrue(raised.exception.process_tree_empty)
		self.assertTrue(
			any("output-pipe close failed" in note for note in raised.exception.notes),
			raised.exception.notes,
		)

	def test_text_monitor_rethrows_original_only_after_quiet_cleanup(self) -> None:
		primary = RuntimeError("synthetic text monitor failure")
		with self.assertRaises(RuntimeError) as raised:
			gf_process_supervisor.run_supervised_process(
				[sys.executable, "-c", "pass"],
				cwd=ROOT,
				timeout_seconds=5.0,
				environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
				process_started_callback=lambda _pid: (_ for _ in ()).throw(primary),
			)
		self.assertIs(raised.exception, primary)

	def test_text_monitor_wraps_original_when_cleanup_fails(self) -> None:
		primary = RuntimeError("synthetic text monitor failure")
		cleanup = RuntimeError("synthetic text confirmation failure")
		original_owner_factory = gf_process_supervisor._new_process_tree_owner

		def failing_owner_factory() -> gf_process_supervisor._ProcessTreeOwner:
			owner = original_owner_factory()
			original_confirmation = owner.confirm_cleanup_after_reap

			def failing_confirmation() -> list[str]:
				notes = original_confirmation()
				raise cleanup

			owner.confirm_cleanup_after_reap = failing_confirmation  # type: ignore[method-assign]
			return owner

		with mock.patch.object(
			gf_process_supervisor,
			"_new_process_tree_owner",
			side_effect=failing_owner_factory,
		):
			with self.assertRaises(
				gf_process_supervisor.SupervisedProcessCleanupError
			) as raised:
				gf_process_supervisor.run_supervised_process(
					[sys.executable, "-c", "pass"],
					cwd=ROOT,
					timeout_seconds=5.0,
					environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
					process_started_callback=(
						lambda _pid: (_ for _ in ()).throw(primary)
					),
				)

		self.assertIs(raised.exception.__cause__, primary)
		self.assertIs(raised.exception.original_error, primary)
		self.assertTrue(raised.exception.owner_closed)
		self.assertTrue(raised.exception.direct_reaped)
		self.assertFalse(raised.exception.cleanup_complete)

	def test_binary_quiet_boundary_waits_for_final_snapshot(self) -> None:
		class DeferredOperation:
			def __init__(self, status: object) -> None:
				self.status = status
				self.waited: list[float | None] = []

			def wait(self, timeout_seconds: float | None) -> bool:
				self.waited.append(timeout_seconds)
				return True

			def snapshot(self) -> object:
				return self.status

			def snapshot_before_deadline(self, _deadline: float) -> object:
				return self.status

		status = gf_process_supervisor.SupervisedBinaryCleanupStatus(
			complete=True,
			cleanup_complete=True,
			owner_closed=True,
			process_tree_empty=True,
			pid=8123,
			notes=("deferred cleanup completed",),
		)
		operation = DeferredOperation(status)
		result = gf_process_supervisor.SupervisedBinaryProcessResult(
			return_code=0,
			stdout=b"ok",
			stderr=b"",
			timed_out=False,
			duration_seconds=0.1,
			pid=8123,
			cleanup_complete=False,
			deferred_cleanup=gf_process_supervisor.SupervisedBinaryCleanupHandle(operation),
		)

		deadline = time.perf_counter() + 0.25
		quiet_result = gf_process_supervisor.require_supervised_binary_quiet_boundary(
			result,
			deadline=deadline,
		)

		self.assertEqual(len(operation.waited), 1)
		assert operation.waited[0] is not None
		self.assertGreaterEqual(operation.waited[0], 0.0)
		self.assertLessEqual(operation.waited[0], 0.25)
		self.assertTrue(quiet_result.cleanup_complete)
		self.assertIsNone(quiet_result.deferred_cleanup)
		self.assertIn("deferred cleanup completed", quiet_result.notes)

	def test_binary_quiet_boundary_rejects_clean_result_observed_after_deadline(
		self,
	) -> None:
		result = gf_process_supervisor.SupervisedBinaryProcessResult(
			return_code=0,
			stdout=b"ok",
			stderr=b"",
			timed_out=False,
			duration_seconds=0.01,
			pid=8124,
			cleanup_complete=True,
			deferred_cleanup=None,
		)

		with self.assertRaisesRegex(TimeoutError, "original absolute deadline"):
			gf_process_supervisor.require_supervised_binary_quiet_boundary(
				result,
				deadline=time.perf_counter() - 0.001,
			)

	def test_binary_quiet_boundary_retains_deferred_owner_on_failure(self) -> None:
		class DeferredOperation:
			def wait(self, _timeout_seconds: float | None) -> bool:
				return False

			def snapshot(self) -> object:
				return gf_process_supervisor.SupervisedBinaryCleanupStatus(
					complete=False,
					cleanup_complete=False,
					owner_closed=False,
					process_tree_empty=False,
					pid=9123,
				)

		handle = gf_process_supervisor.SupervisedBinaryCleanupHandle(DeferredOperation())
		result = gf_process_supervisor.SupervisedBinaryProcessResult(
			return_code=124,
			stdout=b"",
			stderr=b"",
			timed_out=True,
			duration_seconds=0.1,
			pid=9123,
			cleanup_complete=False,
			deferred_cleanup=handle,
		)
		with self.assertRaises(
			gf_process_supervisor.SupervisedProcessCleanupError
		) as raised:
			gf_process_supervisor.require_supervised_binary_quiet_boundary(
				result,
				deadline=time.perf_counter(),
			)
		self.assertIs(raised.exception.deferred_cleanup, handle)
		self.assertTrue(
			gf_process_supervisor.exception_has_cleanup_debt(raised.exception)
		)

	def test_binary_quiet_boundary_cannot_accept_cleanup_after_original_deadline(
		self,
	) -> None:
		class LateQuietOperation:
			def __init__(self) -> None:
				self.waited: list[float | None] = []

			def wait(self, timeout_seconds: float | None) -> bool:
				self.waited.append(timeout_seconds)
				time.sleep(0.02)
				return True

			def snapshot(self) -> object:
				return gf_process_supervisor.SupervisedBinaryCleanupStatus(
					complete=True,
					cleanup_complete=True,
					owner_closed=True,
					process_tree_empty=True,
					pid=9321,
				)

		operation = LateQuietOperation()
		result = gf_process_supervisor.SupervisedBinaryProcessResult(
			return_code=124,
			stdout=b"",
			stderr=b"",
			timed_out=True,
			duration_seconds=0.1,
			pid=9321,
			cleanup_complete=False,
			deferred_cleanup=gf_process_supervisor.SupervisedBinaryCleanupHandle(
				operation
			),
		)
		started = time.monotonic()
		with self.assertRaises(
			gf_process_supervisor.SupervisedProcessCleanupError
		) as raised:
			gf_process_supervisor.require_supervised_binary_quiet_boundary(
				result,
				deadline=time.perf_counter() + 0.005,
			)
		elapsed = time.monotonic() - started

		self.assertEqual(len(operation.waited), 1)
		assert operation.waited[0] is not None
		self.assertLessEqual(operation.waited[0], 0.005)
		self.assertLess(elapsed, 0.1)
		self.assertIs(raised.exception.deferred_cleanup, result.deferred_cleanup)
		self.assertTrue(
			any("original absolute deadline" in note for note in raised.exception.notes),
			raised.exception.notes,
		)

	def test_cleanup_debt_classifier_fails_closed_for_hostile_exception(self) -> None:
		class HostileError(RuntimeError):
			def __getattribute__(self, name: str) -> object:
				if name in {"cleanup_debt", "process_boundary_quiescent"}:
					raise RuntimeError("hostile attribute access")
				return super().__getattribute__(name)

		self.assertTrue(
			gf_process_supervisor.exception_has_cleanup_debt(HostileError("fixture"))
		)
		self.assertFalse(
			gf_process_supervisor.exception_has_cleanup_debt(RuntimeError("ordinary"))
		)

	def test_binary_capture_rejects_invalid_deadlines_and_byte_limits(self) -> None:
		base_arguments = {
			"cwd": ROOT,
			"timeout_seconds": 1.0,
			"max_stdout_bytes": 1,
			"max_stderr_bytes": 1,
		}
		for timeout_seconds in (True, 0.0, -1.0, float("nan"), float("inf")):
			with self.subTest(timeout=timeout_seconds), self.assertRaises(ValueError):
				gf_process_supervisor.run_supervised_process_bytes(
					[sys.executable, "-c", "pass"],
					environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
					**{**base_arguments, "timeout_seconds": timeout_seconds},
				)
		for deadline in (True, float("nan"), float("inf"), float("-inf")):
			with self.subTest(deadline=deadline), self.assertRaises(ValueError):
				gf_process_supervisor.run_supervised_process_bytes(
					[sys.executable, "-c", "pass"],
					environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
					deadline=deadline,
					**base_arguments,
				)
		for field_name in ("max_stdout_bytes", "max_stderr_bytes"):
			for capture_limit in (True, 0, -1):
				with self.subTest(
					field=field_name,
					limit=capture_limit,
				), self.assertRaises(ValueError):
					gf_process_supervisor.run_supervised_process_bytes(
						[sys.executable, "-c", "pass"],
						environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
						**{**base_arguments, field_name: capture_limit},
					)

	def test_binary_capture_spawn_wait_is_bounded_by_the_absolute_deadline(self) -> None:
		spawn_entered = threading.Event()
		release_spawn = threading.Event()

		class BlockingSpawnOwner(gf_process_supervisor._ProcessTreeOwner):
			def start_bytes(
				self,
				_command: list[str],
				*,
				cwd: Path,
				environment: dict[str, str] | None,
			) -> subprocess.Popen[bytes]:
				_ = (cwd, environment)
				spawn_entered.set()
				release_spawn.wait(2.0)
				raise OSError("synthetic blocked spawn")

		owner = BlockingSpawnOwner()
		safety_release = threading.Timer(0.25, release_spawn.set)
		safety_release.start()
		started = time.monotonic()
		caller_deadline = time.perf_counter() + 0.05
		try:
			with mock.patch.object(
				gf_process_supervisor,
				"_new_process_tree_owner",
				return_value=owner,
			):
				result = gf_process_supervisor.run_supervised_process_bytes(
					[sys.executable, "-c", "pass"],
					cwd=ROOT,
					timeout_seconds=5.0,
					deadline=caller_deadline,
					environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
					max_stdout_bytes=1024,
					max_stderr_bytes=1024,
				)
			elapsed = time.monotonic() - started
		finally:
			release_spawn.set()
			safety_release.join()

		self.assertTrue(spawn_entered.is_set())
		self.assertLess(elapsed, 0.15)
		self.assertTrue(result.timed_out, result.notes)
		self.assertFalse(result.cleanup_complete)
		self.assertIsNotNone(result.deferred_cleanup)
		assert result.deferred_cleanup is not None
		self.assertTrue(result.deferred_cleanup.wait(2.0))
		cleanup_status = result.deferred_cleanup.snapshot()
		self.assertTrue(cleanup_status.complete)
		self.assertTrue(cleanup_status.owner_closed)

	def test_binary_capture_expired_caller_deadline_stops_before_dispatch(self) -> None:
		with mock.patch.object(
			gf_process_supervisor,
			"_BinarySpawnOperation",
		) as spawn_operation:
			result = gf_process_supervisor.run_supervised_process_bytes(
				[sys.executable, "-c", "pass"],
				cwd=ROOT,
				timeout_seconds=5.0,
				deadline=time.perf_counter() - 1.0,
				environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
				max_stdout_bytes=1024,
				max_stderr_bytes=1024,
			)

		spawn_operation.assert_not_called()
		self.assertTrue(result.timed_out)
		self.assertEqual(result.pid, 0)
		self.assertTrue(result.cleanup_complete)
		self.assertIsNone(result.deferred_cleanup)

	@unittest.skipUnless(os.name == "nt", "Windows pipe compatibility boundary")
	def test_windows_binary_capture_does_not_require_os_set_blocking(self) -> None:
		with mock.patch.object(
			gf_process_supervisor.os,
			"set_blocking",
			side_effect=AssertionError("Windows pipe path must not use os.set_blocking"),
			create=True,
		) as set_blocking:
			result = gf_process_supervisor.run_supervised_process_bytes(
				[sys.executable, "-c", "import os; os.write(1, b'compatible')"],
				cwd=ROOT,
				timeout_seconds=5.0,
				environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
				max_stdout_bytes=1024,
				max_stderr_bytes=1024,
			)

		set_blocking.assert_not_called()
		self.assertEqual(result.stdout, b"compatible")
		self.assertTrue(result.cleanup_complete, result.notes)

	@unittest.skipUnless(os.name == "nt", "Windows suspended-start boundary")
	def test_windows_unassigned_start_retains_child_until_outer_cleanup(self) -> None:
		owner = gf_process_supervisor._WindowsJobOwner()
		process: subprocess.Popen[bytes] | None = None
		try:
			with mock.patch.object(
				gf_process_supervisor,
				"_ASSIGN_PROCESS_TO_JOB",
				return_value=False,
			):
				with self.assertRaises(OSError):
					owner.start_bytes(
						[sys.executable, "-c", "pass"],
						cwd=ROOT,
						environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
					)
			process = owner._started_process  # type: ignore[assignment]
			self.assertIsNotNone(process)
			assert process is not None
			self.assertFalse(owner._started_process_assigned_to_job)
			notes = owner.terminate_before_deadline(
				process,
				time.perf_counter() + 2.0,
			)
			self.assertTrue(owner.termination_succeeded(), notes)
			self.assertTrue(
				gf_process_supervisor._reap_direct_process_before_deadline(
					process,
					time.perf_counter() + 2.0,
					notes,
				),
				notes,
			)
			self.assertIsNotNone(process.returncode)
			notes.extend(
				owner.confirm_cleanup_after_reap_before_deadline(
					time.perf_counter() + 2.0
				)
			)
			self.assertTrue(owner.cleanup_confirmation_succeeded(), notes)
			notes.extend(owner.close_before_deadline(time.perf_counter() + 2.0))
			self.assertTrue(owner.is_closed(), notes)
			self.assertIs(
				owner._started_process,
				process,
				"returncode alone must not release the retained child identity",
			)
		finally:
			if process is not None:
				try:
					if process.returncode is None:
						process.kill()
						process.wait(timeout=2.0)
				except (OSError, subprocess.TimeoutExpired):
					pass
				for pipe in (process.stdout, process.stderr):
					if pipe is not None:
						try:
							pipe.close()
						except OSError:
							pass
			if not owner.is_closed():
				owner.close_before_deadline(time.perf_counter() + 2.0)

	@unittest.skipUnless(os.name == "nt", "Windows suspended-start boundary")
	def test_windows_startup_repeated_stdin_close_failure_is_cleanup_debt(self) -> None:
		primary = RuntimeError("synthetic failure after Windows Job assignment")
		real_stream = tempfile.TemporaryFile(mode="w+b", buffering=0)

		class UnclosableStdin:
			def __init__(self) -> None:
				self.close_count = 0

			def fileno(self) -> int:
				return real_stream.fileno()

			def write(self, payload: object) -> int:
				return real_stream.write(payload)  # type: ignore[arg-type]

			def seek(self, offset: int) -> int:
				return real_stream.seek(offset)

			def close(self) -> None:
				self.close_count += 1
				raise OSError("synthetic staged-input close failure")

		stdin_stream = UnclosableStdin()

		def checkpoint(name: str) -> None:
			if name == "windows_process_assigned":
				raise primary

		try:
			with mock.patch.object(
				gf_process_supervisor.tempfile,
				"TemporaryFile",
				return_value=stdin_stream,
			), mock.patch.object(
				gf_process_supervisor,
				"_process_supervision_checkpoint",
				side_effect=checkpoint,
			):
				with self.assertRaises(
					gf_process_supervisor.SupervisedProcessCleanupError
				) as raised:
					gf_process_supervisor.run_supervised_process(
						[sys.executable, "-c", "pass"],
						cwd=ROOT,
						timeout_seconds=5.0,
						environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
						stdin_bytes=b"fixture",
					)
		finally:
			real_stream.close()

		self.assertIs(raised.exception.original_error, primary)
		self.assertIs(raised.exception.__cause__, primary)
		self.assertGreaterEqual(stdin_stream.close_count, 2)
		self.assertTrue(raised.exception.cleanup_debt)

	def test_binary_capture_cleans_a_child_tree_that_starts_after_the_deadline(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			temporary_root = Path(temporary_directory)
			ready_path = temporary_root / "ready"
			trigger_path = temporary_root / "trigger"
			survived_path = temporary_root / "survived"
			release_spawn = threading.Event()
			spawn_entered = threading.Event()
			grandchild_code = "\n".join([
				"import time",
				"from pathlib import Path",
				f"ready = Path({str(ready_path)!r})",
				f"trigger = Path({str(trigger_path)!r})",
				f"survived = Path({str(survived_path)!r})",
				"ready.write_text('ready', encoding='utf-8')",
				"deadline = time.monotonic() + 10.0",
				"while not trigger.exists() and time.monotonic() < deadline:",
				"\ttime.sleep(0.01)",
				"if trigger.exists():",
				"\tsurvived.write_text('survived', encoding='utf-8')",
			])
			parent_code = "\n".join([
				"import subprocess, sys, time",
				(
					f"subprocess.Popen([sys.executable, '-c', {grandchild_code!r}], "
					"stdout=sys.stdout, stderr=sys.stderr)"
				),
				"time.sleep(10.0)",
			])
			original_owner_factory = gf_process_supervisor._new_process_tree_owner

			def delayed_owner_factory() -> gf_process_supervisor._ProcessTreeOwner:
				owner = original_owner_factory()
				original_start_bytes = owner.start_bytes

				def delayed_start_bytes(
					command: list[str],
					*,
					cwd: Path,
					environment: dict[str, str] | None,
				) -> subprocess.Popen[bytes]:
					spawn_entered.set()
					release_spawn.wait(2.0)
					process = original_start_bytes(
						command,
						cwd=cwd,
						environment=environment,
					)
					ready_deadline = time.monotonic() + 2.0
					while not ready_path.exists() and time.monotonic() < ready_deadline:
						time.sleep(0.01)
					return process

				owner.start_bytes = delayed_start_bytes  # type: ignore[method-assign]
				return owner

			safety_release = threading.Timer(0.5, release_spawn.set)
			safety_release.start()
			started = time.monotonic()
			try:
				with mock.patch.object(
					gf_process_supervisor,
					"_new_process_tree_owner",
					side_effect=delayed_owner_factory,
				):
					result = gf_process_supervisor.run_supervised_process_bytes(
						[sys.executable, "-c", parent_code],
						cwd=ROOT,
						timeout_seconds=0.1,
						environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
						max_stdout_bytes=1024,
						max_stderr_bytes=1024,
					)
				elapsed = time.monotonic() - started
				release_spawn.set()
				self.assertIsNotNone(result.deferred_cleanup)
				assert result.deferred_cleanup is not None
				self.assertTrue(result.deferred_cleanup.wait(5.0))
				cleanup_status = result.deferred_cleanup.snapshot()
				trigger_path.write_text("finish", encoding="utf-8")
				observation_deadline = time.monotonic() + 0.5
				while (
					not survived_path.exists()
					and time.monotonic() < observation_deadline
				):
					time.sleep(0.01)
			finally:
				release_spawn.set()
				safety_release.join()

			self.assertTrue(spawn_entered.is_set())
			self.assertLess(elapsed, 0.25)
			self.assertTrue(result.timed_out, result.notes)
			self.assertTrue(ready_path.exists(), (cleanup_status, result.notes))
			self.assertTrue(cleanup_status.complete)
			self.assertTrue(cleanup_status.owner_closed)
			self.assertTrue(cleanup_status.process_tree_empty)
			self.assertTrue(cleanup_status.cleanup_complete, cleanup_status.notes)
			self.assertFalse(survived_path.exists())

	@unittest.skipUnless(os.name == "nt", "Windows Job Object close boundary")
	def test_windows_binary_close_wait_is_bounded_and_eventually_safe(self) -> None:
		owner = gf_process_supervisor._WindowsJobOwner()
		original_close_handle = gf_process_supervisor._CLOSE_HANDLE
		close_entered = threading.Event()
		release_close = threading.Event()

		def blocked_close_handle(handle: object) -> object:
			close_entered.set()
			release_close.wait(2.0)
			return original_close_handle(handle)

		safety_release = threading.Timer(0.25, release_close.set)
		safety_release.start()
		started = time.monotonic()
		try:
			with mock.patch.object(
				gf_process_supervisor,
				"_CLOSE_HANDLE",
				side_effect=blocked_close_handle,
			):
				notes = owner.close_before_deadline(time.perf_counter() + 0.05)
			elapsed = time.monotonic() - started
			self.assertTrue(close_entered.is_set())
			self.assertLess(elapsed, 0.15)
			self.assertFalse(owner.is_closed())
			self.assertTrue(any("deadline" in note for note in notes), notes)
			release_close.set()
			self.assertTrue(owner.wait_for_close_completion(2.0))
			self.assertTrue(owner.is_closed())
		finally:
			release_close.set()
			safety_release.join()

	def test_binary_capture_preserves_raw_bytes_and_enforces_byte_limits(self) -> None:
		result = gf_process_supervisor.run_supervised_process_bytes(
			[
				sys.executable,
				"-c",
				"import os; os.write(1, b'\\xffabcde'); os.write(2, b'\\xfeerr')",
			],
			cwd=ROOT,
			timeout_seconds=5.0,
			environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
			max_stdout_bytes=4,
			max_stderr_bytes=16,
		)

		self.assertFalse(result.timed_out, result.notes)
		self.assertTrue(result.stdout_truncated)
		self.assertFalse(result.stderr_truncated)
		self.assertEqual(result.stdout, b"\xffabc")
		self.assertEqual(result.stderr, b"\xfeerr")
		self.assertTrue(result.cleanup_complete, result.notes)

	def test_binary_capture_clears_descendant_that_holds_output_pipes(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			temporary_root = Path(temporary_directory)
			ready_path = temporary_root / "ready"
			trigger_path = temporary_root / "trigger"
			survived_path = temporary_root / "survived"
			grandchild_code = "\n".join([
				"import time",
				"from pathlib import Path",
				f"ready = Path({str(ready_path)!r})",
				f"trigger = Path({str(trigger_path)!r})",
				f"survived = Path({str(survived_path)!r})",
				"ready.write_text('ready', encoding='utf-8')",
				"deadline = time.monotonic() + 10.0",
				"while not trigger.exists() and time.monotonic() < deadline:",
				"\ttime.sleep(0.01)",
				"if trigger.exists():",
				"\tsurvived.write_text('survived', encoding='utf-8')",
			])
			parent_code = "\n".join([
				"import subprocess, sys, time",
				"from pathlib import Path",
				f"ready = Path({str(ready_path)!r})",
				(
					f"subprocess.Popen([sys.executable, '-c', {grandchild_code!r}], "
					"stdout=sys.stdout, stderr=sys.stderr)"
				),
				"deadline = time.monotonic() + 5.0",
				"while not ready.exists() and time.monotonic() < deadline:",
				"\ttime.sleep(0.01)",
				"raise SystemExit(0 if ready.exists() else 2)",
			])

			started = time.monotonic()
			result = gf_process_supervisor.run_supervised_process_bytes(
				[sys.executable, "-c", parent_code],
				cwd=ROOT,
				timeout_seconds=5.0,
				environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
				max_stdout_bytes=1024,
				max_stderr_bytes=1024,
			)
			elapsed = time.monotonic() - started
			trigger_path.write_text("finish", encoding="utf-8")
			observation_deadline = time.monotonic() + 0.5
			while not survived_path.exists() and time.monotonic() < observation_deadline:
				time.sleep(0.01)
			ready_observed = ready_path.exists()
			survived_observed = survived_path.exists()

		self.assertLess(elapsed, 4.0)
		self.assertTrue(
			ready_observed,
			(result.stderr, result.notes),
		)
		self.assertTrue(result.output_drain_failed, result.notes)
		self.assertTrue(result.cleanup_complete, result.notes)
		self.assertFalse(survived_observed)

	def test_binary_capture_deadline_includes_direct_and_descendant_cleanup(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			temporary_root = Path(temporary_directory)
			ready_path = temporary_root / "ready"
			trigger_path = temporary_root / "trigger"
			survived_path = temporary_root / "survived"
			grandchild_code = "\n".join([
				"import time",
				"from pathlib import Path",
				f"ready = Path({str(ready_path)!r})",
				f"trigger = Path({str(trigger_path)!r})",
				f"survived = Path({str(survived_path)!r})",
				"ready.write_text('ready', encoding='utf-8')",
				"deadline = time.monotonic() + 10.0",
				"while not trigger.exists() and time.monotonic() < deadline:",
				"\ttime.sleep(0.01)",
				"if trigger.exists():",
				"\tsurvived.write_text('survived', encoding='utf-8')",
			])
			parent_code = "\n".join([
				"import subprocess, sys, time",
				"from pathlib import Path",
				f"ready = Path({str(ready_path)!r})",
				(
					f"subprocess.Popen([sys.executable, '-c', {grandchild_code!r}], "
					"stdout=sys.stdout, stderr=sys.stderr)"
				),
				"deadline = time.monotonic() + 5.0",
				"while not ready.exists() and time.monotonic() < deadline:",
				"\ttime.sleep(0.01)",
				"time.sleep(10.0)",
			])

			started = time.monotonic()
			result = gf_process_supervisor.run_supervised_process_bytes(
				[sys.executable, "-c", parent_code],
				cwd=ROOT,
				timeout_seconds=2.0,
				environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
				max_stdout_bytes=1024,
				max_stderr_bytes=1024,
			)
			elapsed = time.monotonic() - started
			trigger_path.write_text("finish", encoding="utf-8")
			observation_deadline = time.monotonic() + 0.5
			while not survived_path.exists() and time.monotonic() < observation_deadline:
				time.sleep(0.01)
			ready_observed = ready_path.exists()
			survived_observed = survived_path.exists()

		self.assertTrue(result.timed_out, result.notes)
		self.assertLessEqual(result.duration_seconds, 2.0)
		self.assertLess(elapsed, 2.25)
		self.assertTrue(
			ready_observed,
			(result.stderr, result.notes),
		)
		self.assertTrue(result.cleanup_complete, result.notes)
		self.assertFalse(survived_observed)


	def test_binary_later_close_control_supersedes_ordinary_monitor_error(self) -> None:
		ordinary_error = RuntimeError("fixture binary monitor failure")
		control_error = KeyboardInterrupt("fixture binary close interruption")
		original_owner_factory = gf_process_supervisor._new_process_tree_owner

		def owner_factory() -> gf_process_supervisor._ProcessTreeOwner:
			owner = original_owner_factory()
			original_close = owner.close_before_deadline

			def interrupted_close(deadline: float) -> list[str]:
				original_close(deadline)
				raise control_error

			owner.close_before_deadline = interrupted_close  # type: ignore[method-assign]
			return owner

		with mock.patch.object(
			gf_process_supervisor,
			"_new_process_tree_owner",
			side_effect=owner_factory,
		), mock.patch.object(
			gf_process_supervisor,
			"_prepare_binary_pipe_for_polling",
			side_effect=ordinary_error,
		), self.assertRaises(KeyboardInterrupt) as raised:
			gf_process_supervisor.run_supervised_process_bytes(
				[sys.executable, "-c", "pass"],
				cwd=ROOT,
				timeout_seconds=5.0,
				environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
				max_stdout_bytes=1024,
				max_stderr_bytes=1024,
			)

		self.assertIs(raised.exception, control_error)

	def test_binary_spawn_launch_prefers_second_control_over_first_ordinary(
		self,
	) -> None:
		ordinary_error = RuntimeError("fixture first Thread.start failure")
		control_error = SystemExit("fixture second Thread.start interruption")
		operation = gf_process_supervisor._BinarySpawnOperation(
			[sys.executable, "-c", "pass"],
			cwd=ROOT,
			environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
			max_stdout_bytes=1024,
			max_stderr_bytes=1024,
		)

		with mock.patch.object(
			threading.Thread,
			"start",
			side_effect=(ordinary_error, control_error),
		), self.assertRaises(SystemExit) as raised:
			operation.launch()

		self.assertIs(raised.exception, control_error)
		self.assertTrue(operation.wait(0.0))
		self.assertTrue(operation.snapshot().cleanup_complete)


class ProcessSupervisorLeaseTests(unittest.TestCase):
	def _start_sleeping_lease(
		self,
		*,
		deadline: float,
	) -> gf_process_supervisor.SupervisedProcessLease:
		publication_slot = (
			gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
		)
		lease = gf_process_supervisor.start_supervised_process_lease(
			[sys.executable, "-c", "import time; time.sleep(30)"],
			cwd=ROOT,
			deadline=deadline,
			environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
			publication_slot=publication_slot,
		)
		self.assertIs(publication_slot.get(), lease)
		self.assertIs(type(lease), gf_process_supervisor.SupervisedProcessLease)
		return lease

	def _local_facade(
		self,
		owner: gf_process_supervisor._ProcessTreeOwner,
		process: object,
		*,
		started_at: float,
		deadline: float,
	) -> gf_process_supervisor.SupervisedProcessLease:
		backend = gf_process_supervisor._LocalSupervisedProcessLeaseBackend(
			owner,
			process,  # type: ignore[arg-type]
			command=("fixture",),
			cwd=ROOT,
			started_at=started_at,
			deadline=deadline,
		)
		return gf_process_supervisor.SupervisedProcessLease._from_backend(backend)

	def _start_local_sleeping_facade(
		self,
		*,
		deadline: float,
	) -> tuple[
		gf_process_supervisor.SupervisedProcessLease,
		gf_process_supervisor._ProcessTreeOwner,
		object,
	]:
		started_at = time.perf_counter()
		owner = gf_process_supervisor._new_process_tree_owner()
		process = owner.start_lease(
			[sys.executable, "-c", "import time; time.sleep(30)"],
			cwd=ROOT,
			environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
		)
		return (
			self._local_facade(
				owner,
				process,
				started_at=started_at,
				deadline=deadline,
			),
			owner,
			process,
		)

	def test_public_lease_facade_closes_with_zero_byte_output_policy(self) -> None:
		deadline = time.perf_counter() + 5.0
		lease = self._start_sleeping_lease(deadline=deadline)
		lease.poll_health()
		self.assertGreater(lease.pid, 0)
		self.assertEqual(lease.deadline, deadline)
		self.assertLess(lease.operation_deadline, lease.deadline)
		self.assertGreater(lease.cleanup_reserve_seconds, 0.0)
		self.assertAlmostEqual(
			lease.operation_deadline + lease.cleanup_reserve_seconds,
			lease.deadline,
		)
		result = lease.cancel_and_close(deadline=deadline)

		self.assertEqual(result.pid, lease.pid)
		self.assertTrue(result.cancelled)
		self.assertFalse(result.timed_out, result.notes)
		self.assertTrue(result.process_boundary_quiescent, result.notes)
		self.assertEqual(result.stdout, "")
		self.assertEqual(result.stderr, "")

	def test_local_lease_backend_reports_devnull_output_policy(self) -> None:
		deadline = time.perf_counter() + 5.0
		lease, _owner, _process = self._start_local_sleeping_facade(
			deadline=deadline
		)

		result = lease.cancel_and_close(deadline=deadline)

		self.assertTrue(result.process_boundary_quiescent, result.notes)
		self.assertEqual(result.stdout, "")
		self.assertEqual(result.stderr, "")
		self.assertTrue(any("DEVNULL" in note for note in result.notes))

	def test_lease_repeat_close_after_deadline_reuses_published_quiet_result(self) -> None:
		deadline = time.perf_counter() + 0.5
		lease = self._start_sleeping_lease(deadline=deadline)
		first_result = lease.cancel_and_close(deadline=deadline)
		while time.perf_counter() <= deadline:
			time.sleep(0.005)

		second_result = lease.cancel_and_close(deadline=deadline)

		self.assertIs(second_result, first_result)
		self.assertTrue(second_result.process_boundary_quiescent)

	def test_lease_repeat_close_after_deadline_rethrows_published_control(self) -> None:
		deadline = time.perf_counter() + 0.5
		lease = self._start_sleeping_lease(deadline=deadline)
		control = KeyboardInterrupt("terminal close control")
		injected = False

		def checkpoint(name: str) -> None:
			nonlocal injected
			if name == "process_lease_close_claimed" and not injected:
				injected = True
				raise control

		with mock.patch.object(
			gf_process_supervisor,
			"_process_supervision_checkpoint",
			side_effect=checkpoint,
		), self.assertRaises(KeyboardInterrupt) as first_raised:
			lease.cancel_and_close(deadline=deadline)
		self.assertIs(first_raised.exception, control)
		while time.perf_counter() <= deadline:
			time.sleep(0.005)

		with self.assertRaises(KeyboardInterrupt) as second_raised:
			lease.cancel_and_close(deadline=deadline)

		self.assertIs(second_raised.exception, control)

	def test_lease_close_claim_interruption_still_cleans_real_child(self) -> None:
		deadline = time.perf_counter() + 5.0
		lease = self._start_sleeping_lease(deadline=deadline)
		control_error = KeyboardInterrupt("fixture close-claim interruption")
		injected = False

		def inject(checkpoint: str) -> None:
			nonlocal injected
			if checkpoint == "process_lease_close_claimed" and not injected:
				injected = True
				raise control_error

		with mock.patch.object(
			gf_process_supervisor,
			"_process_supervision_checkpoint",
			side_effect=inject,
		), self.assertRaises(KeyboardInterrupt) as raised:
			lease.cancel_and_close(deadline=deadline)

		self.assertIs(raised.exception, control_error)
		with self.assertRaises(KeyboardInterrupt) as repeated:
			lease.cancel_and_close(deadline=deadline)
		self.assertIs(repeated.exception, control_error)

	def test_lease_close_preparation_interruption_is_recovered_by_outer_choreography(
		self,
	) -> None:
		deadline = time.perf_counter() + 5.0
		lease = self._start_sleeping_lease(deadline=deadline)
		control_error = KeyboardInterrupt("fixture close preparation interruption")
		injected = False

		def inject(checkpoint: str) -> None:
			nonlocal injected
			if checkpoint == "process_lease_close_impl_entered" and not injected:
				injected = True
				raise control_error

		with mock.patch.object(
			gf_process_supervisor,
			"_process_supervision_checkpoint",
			side_effect=inject,
		), self.assertRaises(KeyboardInterrupt) as raised:
			lease.cancel_and_close(deadline=deadline)

		self.assertIs(raised.exception, control_error)
		with self.assertRaises(KeyboardInterrupt) as repeated:
			lease.cancel_and_close(deadline=deadline)
		self.assertIs(repeated.exception, control_error)

	def test_concurrent_lease_close_runs_each_cleanup_stage_once(self) -> None:
		terminate_entered = threading.Event()
		release_terminate = threading.Event()

		class CountingOwner(gf_process_supervisor._ProcessTreeOwner):
			def __init__(self) -> None:
				super().__init__()
				self.terminate_calls = 0
				self.confirm_calls = 0
				self.close_calls = 0

			def wait_for_direct_exit(self, _process: object, _timeout: float) -> bool:
				return False

			def terminate(self, _process: object) -> list[str]:
				self.terminate_calls += 1
				terminate_entered.set()
				release_terminate.wait(2.0)
				self._termination_succeeded = True
				return []

			def confirm_cleanup_after_reap(self) -> list[str]:
				self.confirm_calls += 1
				self._cleanup_confirmation_succeeded = True
				return []

			def close(self) -> list[str]:
				self.close_calls += 1
				return super().close()

		owner = CountingOwner()
		process = mock.Mock()
		process.pid = 4321
		process.returncode = None
		process.wait.side_effect = (
			lambda **_kwargs: setattr(process, "returncode", 1) or 1
		)
		deadline = time.perf_counter() + 5.0
		lease = self._local_facade(
			owner,
			process,
			started_at=time.perf_counter(),
			deadline=deadline,
		)
		results: list[gf_process_supervisor.SupervisedProcessResult] = []
		errors: list[BaseException] = []

		def close_lease() -> None:
			try:
				results.append(lease.cancel_and_close(deadline=deadline))
			except BaseException as error:
				errors.append(error)

		first = threading.Thread(target=close_lease)
		second = threading.Thread(target=close_lease)
		first.start()
		self.assertTrue(terminate_entered.wait(1.0))
		second.start()
		release_terminate.set()
		first.join(2.0)
		second.join(2.0)

		self.assertFalse(first.is_alive())
		self.assertFalse(second.is_alive())
		self.assertEqual(errors, [])
		self.assertEqual(len(results), 2)
		self.assertIs(results[0], results[1])
		self.assertEqual(owner.terminate_calls, 1)
		self.assertEqual(owner.confirm_calls, 1)
		self.assertEqual(owner.close_calls, 1)

	def test_lease_publication_slot_is_a_concurrent_compare_and_set(self) -> None:
		slot = gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
		barrier = threading.Barrier(3)
		leases = (_fixture_process_lease_facade(), _fixture_process_lease_facade())
		published: list[gf_process_supervisor.SupervisedProcessLease] = []
		errors: list[BaseException] = []

		def publish(lease: gf_process_supervisor.SupervisedProcessLease) -> None:
			barrier.wait()
			try:
				slot.publish(lease, deadline=time.perf_counter() + 2.0)
				published.append(lease)
			except BaseException as error:
				errors.append(error)

		threads = [threading.Thread(target=publish, args=(lease,)) for lease in leases]
		for thread in threads:
			thread.start()
		barrier.wait()
		for thread in threads:
			thread.join(2.0)

		self.assertEqual(len(published), 1)
		self.assertEqual(len(errors), 1)
		self.assertIsInstance(errors[0], RuntimeError)
		self.assertIs(slot.get(), published[0])

	def test_public_lease_facade_forwards_and_caches_exact_terminal_result(self) -> None:
		deadline = time.perf_counter() + 5.0
		backend = mock.Mock()
		lease = _fixture_process_lease_facade(deadline=deadline, backend=backend)
		result = gf_process_supervisor.SupervisedProcessResult(
			return_code=0,
			stdout="",
			stderr="",
			timed_out=False,
			duration_seconds=0.1,
			pid=7319,
			process_boundary_quiescent=True,
		)
		backend.cancel_and_close.return_value = result
		slot = gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
		slot.publish(lease, deadline=deadline)

		first = lease.cancel_and_close(deadline=deadline)
		second = lease.cancel_and_close(deadline=deadline)

		self.assertIs(type(lease), gf_process_supervisor.SupervisedProcessLease)
		self.assertIs(slot.get(), lease)
		self.assertIs(first, result)
		self.assertIs(second, result)
		backend.cancel_and_close.assert_called_once_with(deadline=deadline)

	def test_public_lease_facade_wraps_claim_control_and_later_timeout_as_debt(
		self,
	) -> None:
		deadline = time.perf_counter() + 0.05
		backend = mock.Mock()
		lease = _fixture_process_lease_facade(deadline=deadline, backend=backend)
		control = ProcessSupervisorPosixWatchdogTests._SyntheticControl(
			"facade claim interrupted"
		)
		claim_calls = 0

		def fail_claim(shared_deadline: float) -> bool:
			nonlocal claim_calls
			claim_calls += 1
			if claim_calls == 1:
				raise control
			while time.perf_counter() < shared_deadline:
				time.sleep(0.001)
			raise TimeoutError("second claim exhausted the shared deadline")

		with mock.patch.object(
			lease,
			"_claim_close_before_deadline",
			side_effect=fail_claim,
		), self.assertRaises(
			gf_process_supervisor.SupervisedProcessCleanupError
		) as raised:
			lease.cancel_and_close(deadline=deadline)

		self.assertTrue(raised.exception.cleanup_debt)
		self.assertIs(raised.exception.original_error, control)
		self.assertIs(raised.exception.__cause__, control)
		backend.cancel_and_close.assert_not_called()

	def test_publication_slot_rejects_a_raw_platform_backend(self) -> None:
		deadline = time.perf_counter() + 5.0
		raw_backend = mock.Mock(spec=gf_process_supervisor._PosixWatchdogProcessLease)
		slot = gf_process_supervisor.SupervisedProcessLeasePublicationSlot()

		with self.assertRaisesRegex(TypeError, "public lease facade"):
			slot.publish(raw_backend, deadline=deadline)

		self.assertFalse(slot.has_lease)

	def test_public_facade_consumes_terminal_event_while_publisher_lock_is_held(
		self,
	) -> None:
		deadline = time.perf_counter() - 1.0
		lease = _fixture_process_lease_facade(deadline=deadline)
		result = gf_process_supervisor.SupervisedProcessResult(
			return_code=0,
			stdout="",
			stderr="",
			timed_out=True,
			duration_seconds=1.0,
			pid=7319,
			process_boundary_quiescent=True,
		)
		lease._close_claim_lock.acquire()
		try:
			lease._close_result = result
			lease._close_finished.set()
			actual = lease.cancel_and_close(deadline=deadline)
		finally:
			lease._close_claim_lock.release()

		self.assertIs(actual, result)

	def test_public_facade_rechecks_terminal_after_claim_timeout_before_debt(self) -> None:
		deadline = time.perf_counter() - 1.0
		lease = _fixture_process_lease_facade(deadline=deadline)
		result = gf_process_supervisor.SupervisedProcessResult(
			return_code=0,
			stdout="",
			stderr="",
			timed_out=True,
			duration_seconds=1.0,
			pid=7319,
			process_boundary_quiescent=True,
		)
		lease._close_result = result

		class RacingTerminalEvent:
			def __init__(self) -> None:
				self.checks = 0

			def is_set(self) -> bool:
				self.checks += 1
				return self.checks >= 3

			def wait(self, timeout: float | None = None) -> bool:
				_ = timeout
				return True

		lease._close_finished = RacingTerminalEvent()  # type: ignore[assignment]
		with mock.patch.object(
			lease,
			"_claim_close_before_deadline",
			side_effect=TimeoutError("claim raced terminal publication"),
		):
			actual = lease.cancel_and_close(deadline=deadline)

		self.assertIs(actual, result)

	def test_public_facade_rechecks_terminal_after_timed_wait_returns_false(self) -> None:
		deadline = time.perf_counter() + 1.0
		lease = _fixture_process_lease_facade(deadline=deadline)
		result = gf_process_supervisor.SupervisedProcessResult(
			return_code=0,
			stdout="",
			stderr="",
			timed_out=False,
			duration_seconds=0.1,
			pid=7319,
			process_boundary_quiescent=True,
		)
		lease._close_result = result

		class DeadlineEdgeEvent:
			def is_set(self) -> bool:
				return False

			def wait(self, timeout: float | None = None) -> bool:
				return timeout == 0.0

		lease._close_finished = DeadlineEdgeEvent()  # type: ignore[assignment]

		actual = lease._wait_for_close_owner_before_deadline(
			deadline,
			initial_error=None,
			initial_traceback=None,
		)

		self.assertIs(actual, result)

	def test_lease_reports_early_direct_child_exit_before_close(self) -> None:
		deadline = time.perf_counter() + 5.0
		publication_slot = (
			gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
		)
		lease = gf_process_supervisor.start_supervised_process_lease(
			[sys.executable, "-c", "raise SystemExit(7)"],
			cwd=ROOT,
			deadline=deadline,
			environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
			publication_slot=publication_slot,
		)
		observation_deadline = time.perf_counter() + 2.0
		while True:
			try:
				lease.poll_health()
			except RuntimeError as error:
				self.assertIn("exited before cancellation", str(error))
				break
			if time.perf_counter() >= observation_deadline:
				self.fail("lease did not observe its early direct-child exit")
			time.sleep(0.01)

		result = lease.cancel_and_close(deadline=deadline)

		self.assertEqual(result.return_code, 7)
		self.assertFalse(result.cancelled)
		self.assertTrue(result.process_boundary_quiescent, result.notes)

	def test_lease_publication_failure_cleans_child_before_rethrow(self) -> None:
		publication_slot = (
			gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
		)
		control_error = KeyboardInterrupt("fixture publication failure")
		with mock.patch.object(
			gf_process_supervisor.SupervisedProcessLeasePublicationSlot,
			"publish",
			side_effect=control_error,
		), self.assertRaises(KeyboardInterrupt) as raised:
			gf_process_supervisor.start_supervised_process_lease(
				[sys.executable, "-c", "import time; time.sleep(30)"],
				cwd=ROOT,
				deadline=time.perf_counter() + 5.0,
				environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
				publication_slot=publication_slot,
			)

		self.assertIs(raised.exception, control_error)
		self.assertFalse(publication_slot.has_lease)

	def test_lease_cleanup_clears_owned_descendant_tree(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			temporary_root = Path(temporary_directory)
			ready_path = temporary_root / "ready"
			trigger_path = temporary_root / "trigger"
			survived_path = temporary_root / "survived"
			grandchild_code = "\n".join([
				"import time",
				"from pathlib import Path",
				f"ready = Path({str(ready_path)!r})",
				f"trigger = Path({str(trigger_path)!r})",
				f"survived = Path({str(survived_path)!r})",
				"ready.write_text('ready', encoding='utf-8')",
				"deadline = time.monotonic() + 10.0",
				"while not trigger.exists() and time.monotonic() < deadline:",
				"\ttime.sleep(0.01)",
				"if trigger.exists():",
				"\tsurvived.write_text('survived', encoding='utf-8')",
			])
			parent_code = "\n".join([
				"import subprocess, sys, time",
				(
					f"subprocess.Popen([sys.executable, '-c', {grandchild_code!r}])"
				),
				"time.sleep(30.0)",
			])
			deadline = time.perf_counter() + 5.0
			publication_slot = (
				gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
			)
			lease = gf_process_supervisor.start_supervised_process_lease(
				[sys.executable, "-c", parent_code],
				cwd=ROOT,
				deadline=deadline,
				environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
				publication_slot=publication_slot,
			)
			ready_deadline = time.perf_counter() + 2.0
			while not ready_path.exists() and time.perf_counter() < ready_deadline:
				lease.poll_health()
				time.sleep(0.01)
			self.assertTrue(ready_path.exists())

			result = lease.cancel_and_close(deadline=deadline)
			trigger_path.write_text("finish", encoding="utf-8")
			time.sleep(0.2)

			self.assertTrue(result.process_boundary_quiescent, result.notes)
			self.assertFalse(survived_path.exists())

	def test_lease_reuses_one_absolute_deadline_for_every_cleanup_stage(self) -> None:
		original_owner_factory = gf_process_supervisor._new_process_tree_owner
		observed_deadlines: list[float] = []

		def owner_factory() -> gf_process_supervisor._ProcessTreeOwner:
			owner = original_owner_factory()
			original_terminate = owner.terminate_before_deadline
			original_confirm = owner.confirm_cleanup_after_reap_before_deadline
			original_close = owner.close_before_deadline

			def terminate(process: object, deadline: float) -> list[str]:
				observed_deadlines.append(deadline)
				return original_terminate(process, deadline)  # type: ignore[arg-type]

			def confirm(deadline: float) -> list[str]:
				observed_deadlines.append(deadline)
				return original_confirm(deadline)

			def close(deadline: float) -> list[str]:
				observed_deadlines.append(deadline)
				return original_close(deadline)

			owner.terminate_before_deadline = terminate  # type: ignore[method-assign]
			owner.confirm_cleanup_after_reap_before_deadline = confirm  # type: ignore[method-assign]
			owner.close_before_deadline = close  # type: ignore[method-assign]
			return owner

		deadline = time.perf_counter() + 5.0
		with mock.patch.object(
			gf_process_supervisor,
			"_new_process_tree_owner",
			side_effect=owner_factory,
		):
			lease, _owner, _process = self._start_local_sleeping_facade(
				deadline=deadline
			)
			result = lease.cancel_and_close(deadline=deadline)

		self.assertTrue(result.process_boundary_quiescent, result.notes)
		self.assertEqual(observed_deadlines, [deadline, deadline, deadline])
		with self.assertRaisesRegex(ValueError, "original absolute"):
			lease.cancel_and_close(deadline=deadline + 1.0)

	def test_lease_stuck_owner_close_returns_cleanup_debt_at_original_deadline(
		self,
	) -> None:
		original_owner_factory = gf_process_supervisor._new_process_tree_owner
		owner_holder: list[gf_process_supervisor._ProcessTreeOwner] = []
		original_close_holder: list[object] = []

		def owner_factory() -> gf_process_supervisor._ProcessTreeOwner:
			owner = original_owner_factory()
			owner_holder.append(owner)
			original_close = owner.close_before_deadline
			original_close_holder.append(original_close)

			def stuck_close(deadline: float) -> list[str]:
				while not owner.is_closed():
					remaining = max(0.0, deadline - time.perf_counter())
					if remaining <= 0.0:
						break
					time.sleep(min(0.01, remaining))
				if owner.is_closed():
					return []
				owner.cleanup_failed = True
				return ["synthetic owner close reached the original deadline"]

			owner.close_before_deadline = stuck_close  # type: ignore[method-assign]
			return owner

		# Keep enough startup headroom for slow Windows CI while retaining a short,
		# authoritative close deadline for the injected stuck owner.
		deadline = time.perf_counter() + 0.5
		started = time.monotonic()
		cleanup_handle: (
			gf_process_supervisor.SupervisedBinaryCleanupHandle | None
		) = None
		try:
			with mock.patch.object(
				gf_process_supervisor,
				"_new_process_tree_owner",
				side_effect=owner_factory,
			):
				lease, _owner, _process = self._start_local_sleeping_facade(
					deadline=deadline
				)
				with self.assertRaises(
					gf_process_supervisor.SupervisedProcessCleanupError
				) as raised:
					lease.cancel_and_close(deadline=deadline)
				cleanup_handle = raised.exception.deferred_cleanup
			elapsed = time.monotonic() - started
		finally:
			if owner_holder and original_close_holder:
				original_close_holder[0](time.perf_counter() + 2.0)  # type: ignore[operator]
			if cleanup_handle is not None:
				self.assertTrue(cleanup_handle.wait(2.0))

		self.assertLess(elapsed, 0.9)
		self.assertFalse(raised.exception.owner_closed)
		self.assertIsNotNone(raised.exception.deferred_cleanup)
		self.assertTrue(raised.exception.cleanup_debt)

	def test_lease_late_but_fully_proven_cleanup_is_timeout_not_debt(self) -> None:
		class QuietLateOwner(gf_process_supervisor._ProcessTreeOwner):
			def wait_for_direct_exit(self, _process: object, _timeout: float) -> bool:
				return False

			def terminate(self, _process: object) -> list[str]:
				self._termination_succeeded = True
				return []

			def confirm_cleanup_after_reap(self) -> list[str]:
				self._cleanup_confirmation_succeeded = True
				return []

			def close_before_deadline(self, _deadline: float) -> list[str]:
				notes = self.close()
				self.deadline_late = True
				return [*notes, "synthetic late owner close"]

		owner = QuietLateOwner()
		process = mock.Mock()
		process.pid = 4321
		process.returncode = None

		def reap(*, timeout: float) -> int:
			_ = timeout
			process.returncode = 1
			return 1

		process.wait.side_effect = reap
		lease = self._local_facade(
			owner,
			process,
			started_at=90.0,
			deadline=100.0,
		)
		with mock.patch.object(
			gf_process_supervisor.time,
			"perf_counter",
			return_value=101.0,
		):
			result = lease.cancel_and_close(deadline=100.0)

		self.assertTrue(result.process_boundary_quiescent, result.notes)
		self.assertTrue(result.timed_out)
		self.assertTrue(result.cancelled)
		self.assertFalse(owner.cleanup_failed)

	def test_lease_stage_control_errors_are_rethrown_only_after_quiet_cleanup(
		self,
	) -> None:
		class QuietOwner(gf_process_supervisor._ProcessTreeOwner):
			def wait_for_direct_exit(self, _process: object, _timeout: float) -> bool:
				return False

			def terminate(self, _process: object) -> list[str]:
				self._termination_succeeded = True
				return []

			def confirm_cleanup_after_reap(self) -> list[str]:
				self._cleanup_confirmation_succeeded = True
				return []

		for phase, control_error in (
			("process_lease_before_terminate", KeyboardInterrupt("terminate")),
			("process_lease_before_reap", SystemExit("reap")),
			("process_lease_before_confirm", KeyboardInterrupt("confirm")),
			("process_lease_before_close", SystemExit("close")),
		):
			with self.subTest(phase=phase):
				owner = QuietOwner()
				process = mock.Mock()
				process.pid = 4321
				process.returncode = None

				def reap(*, timeout: float) -> int:
					_ = timeout
					process.returncode = 1
					return 1

				process.wait.side_effect = reap
				deadline = time.perf_counter() + 5.0
				lease = self._local_facade(
					owner,
					process,
					started_at=time.perf_counter(),
					deadline=deadline,
				)

				def inject(checkpoint: str) -> None:
					if checkpoint == phase:
						raise control_error

				with mock.patch.object(
					gf_process_supervisor,
					"_process_supervision_checkpoint",
					side_effect=inject,
				), self.assertRaises(type(control_error)) as raised:
					lease.cancel_and_close(deadline=deadline)
				self.assertIs(raised.exception, control_error)
				self.assertTrue(owner.is_closed())
				self.assertTrue(owner.close_succeeded())
				self.assertIsNotNone(process.returncode)

	def test_lease_control_error_with_unproved_close_becomes_cleanup_debt(self) -> None:
		class UnclosedOwner(gf_process_supervisor._ProcessTreeOwner):
			allow_close = False

			def wait_for_direct_exit(self, _process: object, _timeout: float) -> bool:
				return False

			def terminate(self, _process: object) -> list[str]:
				self._termination_succeeded = True
				return []

			def confirm_cleanup_after_reap(self) -> list[str]:
				self._cleanup_confirmation_succeeded = True
				return []

			def close_before_deadline(self, _deadline: float) -> list[str]:
				if self.allow_close:
					return self.close()
				self.cleanup_failed = True
				return ["synthetic unproved close"]

			def wait_for_close_completion(self, _timeout: float | None) -> bool:
				return False

		owner = UnclosedOwner()
		process = mock.Mock()
		process.pid = 4321
		process.returncode = None
		process.wait.side_effect = lambda **_kwargs: setattr(process, "returncode", 1) or 1
		deadline = time.perf_counter() + 5.0
		lease = self._local_facade(
			owner,
			process,
			started_at=time.perf_counter(),
			deadline=deadline,
		)
		control_error = KeyboardInterrupt("fixture control interruption")

		def inject(checkpoint: str) -> None:
			if checkpoint == "process_lease_before_close":
				raise control_error

		with mock.patch.object(
			gf_process_supervisor,
			"_process_supervision_checkpoint",
			side_effect=inject,
		), self.assertRaises(
			gf_process_supervisor.SupervisedProcessCleanupError
		) as raised:
			lease.cancel_and_close(deadline=deadline)

		self.assertIs(raised.exception.original_error, control_error)
		self.assertIs(raised.exception.__cause__, control_error)
		self.assertFalse(raised.exception.owner_closed)
		self.assertIsNotNone(raised.exception.deferred_cleanup)
		owner.allow_close = True
		assert raised.exception.deferred_cleanup is not None
		self.assertTrue(raised.exception.deferred_cleanup.wait(2.0))

	def test_lease_later_control_error_supersedes_earlier_ordinary_cleanup_error(
		self,
	) -> None:
		ordinary_error = RuntimeError("fixture ordinary terminate failure")
		control_error = KeyboardInterrupt("fixture later close interruption")

		class QuietCloseOwner(gf_process_supervisor._ProcessTreeOwner):
			def wait_for_direct_exit(self, _process: object, _timeout: float) -> bool:
				return False

			def terminate(self, _process: object) -> list[str]:
				raise ordinary_error

			def close_before_deadline(self, _deadline: float) -> list[str]:
				self.close()
				raise control_error

			def close_terminates_tree(self) -> bool:
				return True

		owner = QuietCloseOwner()
		process = mock.Mock()
		process.pid = 4321
		process.returncode = None
		process.stdout = None
		process.stderr = None

		def reap(*, timeout: float) -> int:
			_ = timeout
			process.returncode = 1
			return 1

		process.wait.side_effect = reap
		deadline = time.perf_counter() + 5.0
		lease = self._local_facade(
			owner,
			process,
			started_at=time.perf_counter(),
			deadline=deadline,
		)
		with self.assertRaises(KeyboardInterrupt) as raised:
			lease.cancel_and_close(deadline=deadline)

		self.assertIs(raised.exception, control_error)
		self.assertIsNotNone(process.returncode)
		with self.assertRaises(KeyboardInterrupt) as repeated:
			lease.cancel_and_close(deadline=deadline)
		self.assertIs(repeated.exception, control_error)

	def test_deferred_cleanup_later_control_supersedes_worker_launch_error(
		self,
	) -> None:
		ordinary_error = RuntimeError("fixture worker launch failure")
		control_error = SystemExit("fixture deferred close interruption")

		class QuietCloseOwner(gf_process_supervisor._ProcessTreeOwner):
			def terminate(self, _process: object) -> list[str]:
				self._termination_succeeded = True
				return []

			def close_before_deadline(self, _deadline: float) -> list[str]:
				self.close()
				raise control_error

			def close_terminates_tree(self) -> bool:
				return True

		owner = QuietCloseOwner()
		process = mock.Mock()
		process.pid = 8765
		process.returncode = None
		process.stdout = None
		process.stderr = None
		process.wait.side_effect = (
			lambda **_kwargs: setattr(process, "returncode", 1) or 1
		)
		operation = gf_process_supervisor._LeaseDeferredCleanupOperation(
			owner,
			process,
			owner_closed=False,
			process_tree_empty=False,
			direct_reaped=False,
			cleanup_confirmation_complete=False,
			notes=(),
		)
		operation._worker_launch_failed = True
		operation._record_pending_error("worker launch", ordinary_error)

		with self.assertRaises(SystemExit) as raised:
			operation.wait(2.0)

		self.assertIs(raised.exception, control_error)
		self.assertTrue(operation.snapshot().cleanup_complete)

	def test_deferred_lease_cleanup_reaps_after_kill_on_close_proof(self) -> None:
		class DeferredCloseOwner(gf_process_supervisor._ProcessTreeOwner):
			def terminate_before_deadline(
				self,
				_process: object,
				_deadline: float,
			) -> list[str]:
				return []

			def wait_for_close_completion(self, _timeout: float | None) -> bool:
				self._closed = True
				self._close_succeeded = True
				return True

			def close_terminates_tree(self) -> bool:
				return True

		owner = DeferredCloseOwner()
		process = mock.Mock()
		process.pid = 4321
		process.returncode = None

		def reap(*, timeout: float) -> int:
			_ = timeout
			process.returncode = 1
			return 1

		process.wait.side_effect = reap
		operation = gf_process_supervisor._LeaseDeferredCleanupOperation(
			owner,
			process,
			owner_closed=False,
			process_tree_empty=False,
			direct_reaped=False,
			cleanup_confirmation_complete=False,
			notes=("fixture original deadline debt",),
		)
		operation.launch()
		handle = gf_process_supervisor.SupervisedBinaryCleanupHandle(operation)

		self.assertTrue(handle.wait(2.0))
		status = handle.snapshot()
		self.assertTrue(status.complete)
		self.assertTrue(status.cleanup_complete, status.notes)
		self.assertTrue(status.owner_closed)
		self.assertTrue(status.process_tree_empty)
		self.assertIsNotNone(process.returncode)

	def test_deferred_lease_constructor_does_not_call_hostile_owner_proof(self) -> None:
		class HostileConstructionOwner(gf_process_supervisor._ProcessTreeOwner):
			def __init__(self) -> None:
				super().__init__()
				self.constructing_operation = True

			def is_closed(self) -> bool:
				if self.constructing_operation:
					raise KeyboardInterrupt("fixture hostile construction proof")
				return super().is_closed()

			def terminate_before_deadline(
				self,
				_process: object,
				_deadline: float,
			) -> list[str]:
				return []

			def wait_for_close_completion(self, _timeout: float | None) -> bool:
				self._closed = True
				self._close_succeeded = True
				return True

			def close_terminates_tree(self) -> bool:
				return True

		owner = HostileConstructionOwner()
		process = mock.Mock()
		process.pid = 4321
		process.returncode = None
		process.wait.side_effect = lambda **_kwargs: setattr(process, "returncode", 1) or 1
		with mock.patch.object(
			gf_process_supervisor._LeaseDeferredCleanupOperation,
			"_launch_worker",
			return_value=None,
		):
			operation = gf_process_supervisor._LeaseDeferredCleanupOperation(
				owner,
				process,
				owner_closed=False,
				process_tree_empty=False,
				direct_reaped=False,
				cleanup_confirmation_complete=False,
				notes=("fixture retained authority",),
			)
		owner.constructing_operation = False
		operation._worker_main()

		status = operation.snapshot()
		self.assertTrue(status.cleanup_complete, status.notes)
		self.assertTrue(status.owner_closed)
		self.assertTrue(status.process_tree_empty)

	def test_deferred_lease_double_worker_start_failure_is_cleaned_by_wait(self) -> None:
		owner = gf_process_supervisor._new_process_tree_owner()
		process = owner.start_lease(
			[sys.executable, "-c", "import time; time.sleep(30)"],
			cwd=ROOT,
			environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
		)
		owner.close_before_deadline(time.perf_counter() + 2.0)
		with mock.patch.object(
			threading.Thread,
			"start",
			side_effect=(RuntimeError("first start"), RuntimeError("second start")),
		):
			operation = gf_process_supervisor._LeaseDeferredCleanupOperation(
				owner,
				process,
				owner_closed=owner.is_closed(),
				process_tree_empty=False,
				direct_reaped=False,
				cleanup_confirmation_complete=False,
				notes=("fixture original cleanup debt",),
			)
			operation.launch()
		handle = gf_process_supervisor.SupervisedBinaryCleanupHandle(operation)

		try:
			with self.assertRaisesRegex(RuntimeError, "first start"):
				handle.wait(5.0)
			status = handle.snapshot()
			self.assertTrue(status.cleanup_complete, status.notes)
			self.assertTrue(status.owner_closed)
			self.assertTrue(status.process_tree_empty)
			self.assertIsNotNone(process.returncode)
			self.assertTrue(any("worker launch failed" in note for note in status.notes))
		finally:
			if process.returncode is None:
				process.kill()
				process.wait(timeout=2.0)

	def test_deferred_lease_worker_is_retained_non_daemon_until_quiet(self) -> None:
		release_close = threading.Event()

		class BlockingDeferredOwner(gf_process_supervisor._ProcessTreeOwner):
			def terminate_before_deadline(
				self,
				_process: object,
				_deadline: float,
			) -> list[str]:
				self._termination_succeeded = True
				return []

			def wait_for_close_completion(self, timeout: float | None) -> bool:
				release_close.wait(timeout)
				if release_close.is_set():
					self._closed = True
					self._close_succeeded = True
				return self._closed

			def confirm_cleanup_after_reap_before_deadline(
				self,
				_deadline: float,
			) -> list[str]:
				self._cleanup_confirmation_succeeded = True
				return []

		owner = BlockingDeferredOwner()
		process = mock.Mock()
		process.pid = 4321
		process.returncode = None
		process.wait.side_effect = lambda **_kwargs: setattr(process, "returncode", 1) or 1
		operation = gf_process_supervisor._LeaseDeferredCleanupOperation(
			owner,
			process,
			owner_closed=False,
			process_tree_empty=False,
			direct_reaped=False,
			cleanup_confirmation_complete=False,
			notes=("fixture retained worker",),
		)
		operation.launch()
		handle = gf_process_supervisor.SupervisedBinaryCleanupHandle(operation)
		try:
			workers = [
				thread
				for thread in threading.enumerate()
				if thread.name == "gf-process-lease-deferred-cleanup"
			]
			self.assertTrue(workers)
			self.assertTrue(all(not thread.daemon for thread in workers))
		finally:
			release_close.set()
		self.assertTrue(handle.wait(2.0))
		self.assertTrue(handle.snapshot().cleanup_complete)

	def test_deferred_lease_cleanup_retries_until_a_later_attempt_is_quiet(self) -> None:
		class TransientOwner(gf_process_supervisor._ProcessTreeOwner):
			def __init__(self) -> None:
				super().__init__()
				self.terminate_calls = 0

			def terminate_before_deadline(
				self,
				_process: object,
				_deadline: float,
			) -> list[str]:
				self.terminate_calls += 1
				if self.terminate_calls == 1:
					raise OSError("fixture first termination failure")
				self._termination_succeeded = True
				return []

			def confirm_cleanup_after_reap_before_deadline(
				self,
				_deadline: float,
			) -> list[str]:
				self._cleanup_confirmation_succeeded = True
				return []

		owner = TransientOwner()
		process = mock.Mock()
		process.pid = 4321
		process.returncode = None
		process.wait.side_effect = (
			lambda **_kwargs: setattr(process, "returncode", 1) or 1
		)
		with mock.patch.object(
			gf_process_supervisor._LeaseDeferredCleanupOperation,
			"_launch_worker",
			return_value=None,
		):
			operation = gf_process_supervisor._LeaseDeferredCleanupOperation(
				owner,
				process,
				owner_closed=False,
				process_tree_empty=False,
				direct_reaped=False,
				cleanup_confirmation_complete=False,
				notes=("fixture retained cleanup",),
			)
		operation._worker_main()

		status = operation.snapshot()
		self.assertGreaterEqual(owner.terminate_calls, 2)
		self.assertTrue(status.complete)
		self.assertTrue(status.cleanup_complete, status.notes)
		self.assertTrue(status.process_tree_empty)
		self.assertIsNotNone(process.returncode)

	def test_lease_launch_interruption_abandons_and_quiets_real_child(self) -> None:
		original_launch = gf_process_supervisor._BinarySpawnOperation.launch
		control_error = KeyboardInterrupt("fixture interruption after worker launch")
		started_at = time.perf_counter()
		deadline = started_at + 5.0

		def launch_then_interrupt(
			operation: gf_process_supervisor._BinarySpawnOperation,
		) -> None:
			original_launch(operation)
			raise control_error

		with mock.patch.object(
			gf_process_supervisor._BinarySpawnOperation,
			"launch",
			side_effect=launch_then_interrupt,
			autospec=True,
		), self.assertRaises(KeyboardInterrupt) as raised:
			gf_process_supervisor._start_local_supervised_process_lease(
				[sys.executable, "-c", "import time; time.sleep(30)"],
				cwd=ROOT,
				deadline=deadline,
				environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
				publication_slot=(
					gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
				),
				started_at=started_at,
			)

		self.assertIs(raised.exception, control_error)

	def test_deferred_sync_cleanup_rethrows_control_only_after_real_child_is_quiet(
		self,
	) -> None:
		owner = gf_process_supervisor._new_process_tree_owner()
		process = owner.start_lease(
			[sys.executable, "-c", "import time; time.sleep(30)"],
			cwd=ROOT,
			environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
		)
		owner.close_before_deadline(time.perf_counter() + 2.0)
		control_error = KeyboardInterrupt("fixture deferred termination interruption")
		original_terminate = owner.terminate_before_deadline

		def terminate_then_interrupt(
			process_to_stop: object,
			deadline: float,
		) -> list[str]:
			original_terminate(process_to_stop, deadline)  # type: ignore[arg-type]
			raise control_error

		owner.terminate_before_deadline = terminate_then_interrupt  # type: ignore[method-assign]
		with mock.patch.object(
			gf_process_supervisor._LeaseDeferredCleanupOperation,
			"_launch_worker",
			return_value=None,
		):
			operation = gf_process_supervisor._LeaseDeferredCleanupOperation(
				owner,
				process,
				owner_closed=owner.is_closed(),
				process_tree_empty=False,
				direct_reaped=False,
				cleanup_confirmation_complete=False,
				notes=("fixture original cleanup debt",),
			)
		operation._worker_launch_failed = True
		handle = gf_process_supervisor.SupervisedBinaryCleanupHandle(operation)

		try:
			with self.assertRaises(KeyboardInterrupt) as raised:
				handle.wait(5.0)
			self.assertIs(raised.exception, control_error)
			status = handle.snapshot()
			self.assertTrue(status.cleanup_complete, status.notes)
			self.assertIsNotNone(process.returncode)
		finally:
			if process.returncode is None:
				process.kill()
				process.wait(timeout=2.0)

	def test_lease_spawn_timeout_retains_worker_authority_until_cleanup(self) -> None:
		original_owner_factory = gf_process_supervisor._new_process_tree_owner
		allow_spawn = threading.Event()

		def owner_factory() -> gf_process_supervisor._ProcessTreeOwner:
			owner = original_owner_factory()
			original_start = owner.start_lease

			def blocked_start(*args: object, **kwargs: object) -> object:
				allow_spawn.wait(2.0)
				return original_start(*args, **kwargs)

			owner.start_lease = blocked_start  # type: ignore[method-assign]
			return owner

		deadline = time.perf_counter() + 0.1
		started_at = time.perf_counter()
		started = time.monotonic()
		with mock.patch.object(
			gf_process_supervisor,
			"_new_process_tree_owner",
			side_effect=owner_factory,
		), self.assertRaises(
			gf_process_supervisor.SupervisedProcessCleanupError
		) as raised:
			gf_process_supervisor._start_local_supervised_process_lease(
				[sys.executable, "-c", "import time; time.sleep(30)"],
				cwd=ROOT,
				deadline=deadline,
				environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
				publication_slot=(
					gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
				),
				started_at=started_at,
			)
		elapsed = time.monotonic() - started
		self.assertLess(elapsed, 0.5)
		self.assertIsNotNone(raised.exception.deferred_cleanup)
		spawn_workers = [
			thread
			for thread in threading.enumerate()
			if thread.name == "gf-binary-process-spawn"
		]
		self.assertTrue(spawn_workers)
		self.assertTrue(all(not thread.daemon for thread in spawn_workers))
		allow_spawn.set()
		self.assertTrue(raised.exception.deferred_cleanup.wait(3.0))
		status = raised.exception.deferred_cleanup.snapshot()
		self.assertTrue(status.cleanup_complete, status.notes)

	def test_deferred_sync_handoff_interrupt_never_runs_cleanup_twice(self) -> None:
		for phase in (
			"deferred_lease_sync_authority_released",
			"deferred_lease_sync_worker_launched",
		):
			with self.subTest(phase=phase):
				control_error = KeyboardInterrupt(f"fixture interruption at {phase}")

				class CountingOwner(gf_process_supervisor._ProcessTreeOwner):
					def __init__(self) -> None:
						super().__init__()
						self.terminate_calls = 0
						self.close_calls = 0

					def terminate(self, _process: object) -> list[str]:
						self.terminate_calls += 1
						self._termination_succeeded = True
						return []

					def confirm_cleanup_after_reap(self) -> list[str]:
						self._cleanup_confirmation_succeeded = True
						return []

					def close_before_deadline(self, _deadline: float) -> list[str]:
						self.close_calls += 1
						return self.close()

				owner = CountingOwner()
				process = mock.Mock()
				process.pid = 2468
				process.returncode = None
				process.stdout = None
				process.stderr = None
				process.wait.side_effect = (
					lambda **_kwargs: setattr(process, "returncode", 1) or 1
				)
				operation = gf_process_supervisor._LeaseDeferredCleanupOperation(
					owner,
					process,
					owner_closed=False,
					process_tree_empty=False,
					direct_reaped=False,
					cleanup_confirmation_complete=False,
					notes=(),
				)
				operation._worker_launch_failed = True
				injected = False

				def inject(checkpoint: str) -> None:
					nonlocal injected
					if checkpoint == phase and not injected:
						injected = True
						raise control_error

				with mock.patch.object(
					gf_process_supervisor,
					"_process_supervision_checkpoint",
					side_effect=inject,
				), self.assertRaises(KeyboardInterrupt) as raised:
					operation.wait(0.0)

				self.assertIs(raised.exception, control_error)
				self.assertTrue(operation.snapshot().cleanup_complete)
				self.assertEqual(owner.terminate_calls, 1)
				self.assertEqual(owner.close_calls, 1)

	def test_deferred_launch_commit_interruption_quiets_real_child_before_rethrow(
		self,
	) -> None:
		owner = gf_process_supervisor._new_process_tree_owner()
		process = owner.start_lease(
			[sys.executable, "-c", "import time; time.sleep(30)"],
			cwd=ROOT,
			environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
		)
		control_error = SystemExit("fixture deferred launch commit interruption")
		operation = gf_process_supervisor._LeaseDeferredCleanupOperation(
			owner,
			process,
			owner_closed=False,
			process_tree_empty=False,
			direct_reaped=False,
			cleanup_confirmation_complete=False,
			notes=(),
		)

		def inject(checkpoint: str) -> None:
			if checkpoint == "deferred_lease_launch_committed":
				raise control_error

		try:
			with mock.patch.object(
				gf_process_supervisor,
				"_process_supervision_checkpoint",
				side_effect=inject,
			):
				operation.launch()
			with self.assertRaises(SystemExit) as raised:
				operation.wait(5.0)
			self.assertIs(raised.exception, control_error)
			self.assertTrue(operation.snapshot().cleanup_complete)
			self.assertIsNotNone(process.returncode)
		finally:
			if process.returncode is None:
				process.kill()
				process.wait(timeout=2.0)

	def test_deferred_worker_wait_retains_control_until_worker_is_quiet(self) -> None:
		close_entered = threading.Event()
		release_close = threading.Event()
		control_error = KeyboardInterrupt("fixture worker completion wait interruption")

		class BlockingOwner(gf_process_supervisor._ProcessTreeOwner):
			def terminate(self, _process: object) -> list[str]:
				self._termination_succeeded = True
				return []

			def confirm_cleanup_after_reap(self) -> list[str]:
				self._cleanup_confirmation_succeeded = True
				return []

			def close_before_deadline(self, _deadline: float) -> list[str]:
				close_entered.set()
				release_close.wait(2.0)
				return self.close()

		owner = BlockingOwner()
		process = mock.Mock()
		process.pid = 9753
		process.returncode = None
		process.stdout = None
		process.stderr = None
		process.wait.side_effect = (
			lambda **_kwargs: setattr(process, "returncode", 1) or 1
		)
		operation = gf_process_supervisor._LeaseDeferredCleanupOperation(
			owner,
			process,
			owner_closed=False,
			process_tree_empty=False,
			direct_reaped=False,
			cleanup_confirmation_complete=False,
			notes=(),
		)
		operation.launch()
		self.assertTrue(close_entered.wait(1.0))
		original_wait = operation._finished.wait
		wait_calls = 0

		def interrupted_wait(timeout: float | None = None) -> bool:
			nonlocal wait_calls
			wait_calls += 1
			if wait_calls == 1:
				raise control_error
			return original_wait(timeout)

		release_timer = threading.Timer(0.05, release_close.set)
		release_timer.start()
		with mock.patch.object(
			operation._finished,
			"wait",
			side_effect=interrupted_wait,
		), self.assertRaises(KeyboardInterrupt) as raised:
			operation.wait(2.0)
		release_timer.join()

		self.assertIs(raised.exception, control_error)
		self.assertTrue(operation.snapshot().cleanup_complete)

	def test_lease_spawn_checkpoint_error_cleans_published_child_before_rethrow(
		self,
	) -> None:
		for phase in (
			"process_lease_spawn_published",
			"process_lease_before_claim_ack",
			"process_lease_publication_committed",
			"process_lease_claim_ack_committed",
		):
			with self.subTest(phase=phase):
				control_error = KeyboardInterrupt(
					f"fixture process lease interruption at {phase}"
				)

				def inject(checkpoint: str) -> None:
					if checkpoint == phase:
						raise control_error

				with mock.patch.object(
					gf_process_supervisor,
					"_process_supervision_checkpoint",
					side_effect=inject,
				), self.assertRaises(KeyboardInterrupt) as raised:
					gf_process_supervisor.start_supervised_process_lease(
						[sys.executable, "-c", "import time; time.sleep(30)"],
						cwd=ROOT,
						deadline=time.perf_counter() + 5.0,
						environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
						publication_slot=(
							gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
						),
					)
				self.assertIs(raised.exception, control_error)


class CorePluginBootstrapSmokeTests(unittest.TestCase):
	def test_translation_preview_smoke_uses_a_real_display_on_linux(self) -> None:
		environment = {"PATH": "frozen-core-path"}
		with mock.patch.object(
			gf_maintenance.sys,
			"platform",
			"linux",
		), mock.patch.object(
			gf_maintenance,
			"resolve_godot_executable",
			return_value="/opt/godot",
		) as resolve_godot, mock.patch.object(
			gf_maintenance,
			"resolve_frozen_executable",
			return_value="/usr/bin/xvfb-run",
		) as resolve_wrapper:
			command = gf_maintenance.make_core_plugin_bootstrap_smoke_command(
				Path("/tmp/project"),
				Path("/tmp/godot.log"),
				"resource_preview_translation",
				environment=environment,
			)

		self.assertEqual(command[0], "/usr/bin/xvfb-run")
		self.assertIn("/opt/godot", command)
		self.assertIn("--display-driver", command)
		self.assertIn("x11", command)
		self.assertNotIn("--headless", command)
		resolve_godot.assert_called_once_with(
			environment=environment,
			cwd=ROOT,
		)
		resolve_wrapper.assert_called_once_with(
			"xvfb-run",
			environment=environment,
			cwd=ROOT,
			platform_name="posix",
		)
		self.assertIs(resolve_wrapper.call_args.kwargs["environment"], environment)

	def test_translation_preview_smoke_uses_resolved_godot_on_desktop_platforms(self) -> None:
		environment = {"PATH": "frozen-core-path"}
		for platform_name in ("darwin", "win32"):
			with self.subTest(platform=platform_name), mock.patch.object(
				gf_maintenance.sys,
				"platform",
				platform_name,
			), mock.patch.object(
				gf_maintenance,
				"resolve_godot_executable",
				return_value="/opt/godot",
			), mock.patch.object(
				gf_maintenance,
				"resolve_frozen_executable",
			) as wrapper_resolver:
				command = gf_maintenance.make_core_plugin_bootstrap_smoke_command(
					Path("/tmp/project"),
					Path("/tmp/godot.log"),
					"resource_preview_translation",
					environment=environment,
				)

			self.assertEqual(command[0], "/opt/godot")
			self.assertIn("--editor", command)
			self.assertNotIn("--headless", command)
			wrapper_resolver.assert_not_called()

	def test_translation_preview_smoke_fails_closed_without_xvfb(self) -> None:
		environment = {"PATH": "frozen-core-path"}
		with mock.patch.object(
			gf_maintenance.sys,
			"platform",
			"linux",
		), mock.patch.object(
			gf_maintenance,
			"resolve_godot_executable",
			return_value="/opt/godot",
		), mock.patch.object(
			gf_maintenance,
			"resolve_frozen_executable",
			side_effect=gf_maintenance.ExecutableResolutionError(
				"fixture unresolved wrapper"
			),
		):
			with self.assertRaises(
				gf_maintenance.CorePluginBootstrapDisplayDependencyError
			) as raised:
				gf_maintenance.make_core_plugin_bootstrap_smoke_command(
					Path("/tmp/project"),
					Path("/tmp/godot.log"),
					"resource_preview_translation",
					environment=environment,
				)
		self.assertIsInstance(
			raised.exception.__cause__,
			gf_maintenance.ExecutableResolutionError,
		)

	def test_translation_preview_smoke_reports_missing_display_dependency(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_maintenance,
			"prepare_core_plugin_bootstrap_smoke_project",
		), mock.patch.object(
			gf_maintenance,
			"make_core_plugin_bootstrap_smoke_command",
			side_effect=gf_maintenance.CorePluginBootstrapDisplayDependencyError(
				"xvfb-run missing"
			),
		), mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			side_effect=AssertionError(
				"an unresolved wrapper must fail before supervisor dispatch"
			),
		) as supervisor:
			issues: list[dict[str, object]] = []
			result = gf_maintenance.run_core_plugin_bootstrap_smoke_scenario(
				Path(temporary_directory),
				"resource_preview_translation",
				issues,
				base_environment={"PATH": "frozen-core-path"},
			)

		self.assertFalse(result["ok"])
		self.assertEqual(
			[item["kind"] for item in issues],
			["core_plugin_bootstrap_smoke_display_dependency_missing"],
		)
		self.assertIn("display dependency", str(issues[0]["message"]))
		supervisor.assert_not_called()

	def test_translation_preview_smoke_reports_ambiguous_environment_names(
		self,
	) -> None:
		ambiguity = gf_executable_resolution.EnvironmentNameAmbiguityError(
			"Frozen Windows environment contains ambiguous APPDATA entries."
		)
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_maintenance,
			"prepare_core_plugin_bootstrap_smoke_project",
		), mock.patch.object(
			gf_maintenance,
			"make_core_plugin_bootstrap_smoke_environment",
			side_effect=ambiguity,
		), mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			side_effect=AssertionError(
				"an ambiguous environment must fail before supervisor dispatch"
			),
		) as supervisor:
			issues: list[dict[str, object]] = []
			result = gf_maintenance.run_core_plugin_bootstrap_smoke_scenario(
				Path(temporary_directory),
				"resource_preview_translation",
				issues,
				base_environment={"APPDATA": "a", "AppData": "b"},
			)

		self.assertFalse(result["ok"])
		self.assertEqual(
			[item["kind"] for item in issues],
			["core_plugin_bootstrap_smoke_environment_invalid"],
		)
		self.assertNotEqual(
			issues[0]["kind"],
			"core_plugin_bootstrap_smoke_godot_missing",
		)
		supervisor.assert_not_called()

	def test_translation_preview_smoke_binds_posix_path_to_dispatch_cwd(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			execution_root = fixture_root / "execution"
			ambient_root = fixture_root / "ambient"
			execution_root.mkdir()
			ambient_root.mkdir()
			scenarios = (
				(
					"relative",
					"relative-bin",
					execution_root / "relative-bin" / "xvfb-run",
					ambient_root / "relative-bin" / "xvfb-run",
				),
				(
					"empty",
					":fallback-bin",
					execution_root / "xvfb-run",
					ambient_root / "xvfb-run",
				),
			)
			for _name, _path_value, execution_wrapper, ambient_wrapper in scenarios:
				for wrapper in (execution_wrapper, ambient_wrapper):
					wrapper.parent.mkdir(parents=True, exist_ok=True)
					wrapper.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
					wrapper.chmod(0o755)

			original_cwd = Path.cwd()
			try:
				os.chdir(ambient_root)
				for name, path_value, execution_wrapper, ambient_wrapper in scenarios:
					with self.subTest(path_entry=name), mock.patch.object(
						gf_maintenance,
						"ROOT",
						execution_root,
					), mock.patch.object(
						gf_maintenance.sys,
						"platform",
						"linux",
					), mock.patch.object(
						gf_maintenance,
						"resolve_godot_executable",
						return_value=str(execution_root / "godot"),
					):
						command = gf_maintenance.make_core_plugin_bootstrap_smoke_command(
							execution_root / "project",
							execution_root / "godot.log",
							"resource_preview_translation",
							environment={"PATH": path_value},
						)

					self.assertEqual(command[0], str(execution_wrapper.resolve()))
					self.assertTrue(Path(command[0]).is_absolute())
					self.assertNotEqual(command[0], str(ambient_wrapper.resolve()))
			finally:
				os.chdir(original_cwd)

	def test_translation_preview_smoke_never_falls_back_to_ambient_cwd(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			execution_root = fixture_root / "execution"
			ambient_root = fixture_root / "ambient"
			execution_root.mkdir()
			ambient_root.mkdir()
			scenarios = (
				("relative", "relative-bin", ambient_root / "relative-bin" / "xvfb-run"),
				("empty", ":fallback-bin", ambient_root / "xvfb-run"),
			)
			for _name, _path_value, ambient_wrapper in scenarios:
				ambient_wrapper.parent.mkdir(parents=True, exist_ok=True)
				ambient_wrapper.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
				ambient_wrapper.chmod(0o755)

			original_cwd = Path.cwd()
			try:
				os.chdir(ambient_root)
				for name, path_value, ambient_wrapper in scenarios:
					with self.subTest(path_entry=name), mock.patch.dict(
						os.environ,
						{"PATH": str(ambient_wrapper.parent)},
						clear=True,
					), mock.patch.object(
						gf_maintenance,
						"ROOT",
						execution_root,
					), mock.patch.object(
						gf_maintenance.sys,
						"platform",
						"linux",
					), mock.patch.object(
						gf_maintenance,
						"resolve_godot_executable",
						return_value=str(execution_root / "godot"),
					), mock.patch.object(
						gf_maintenance,
						"run_supervised_process",
						side_effect=AssertionError(
							"ambient fallback must fail before supervisor dispatch"
						),
					) as supervisor, self.assertRaises(
						gf_maintenance.CorePluginBootstrapDisplayDependencyError
					) as raised:
						gf_maintenance.make_core_plugin_bootstrap_smoke_command(
							execution_root / "project",
							execution_root / "godot.log",
							"resource_preview_translation",
							environment={"PATH": path_value},
						)

					self.assertIsInstance(
						raised.exception.__cause__,
						gf_maintenance.ExecutableResolutionError,
					)
					supervisor.assert_not_called()
			finally:
				os.chdir(original_cwd)

	def test_core_smoke_reuses_one_frozen_environment_for_resolution_and_dispatch(self) -> None:
		base_environment = {"PATH": "frozen-core-path", "BASE": "fixture"}
		derived_environment = dict(base_environment)
		quiet_result = gf_maintenance.gf_process_supervisor.SupervisedProcessResult(
			return_code=0,
			stdout="",
			stderr="",
			timed_out=False,
			duration_seconds=0.1,
			pid=101,
			process_boundary_quiescent=True,
		)
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_maintenance,
			"prepare_core_plugin_bootstrap_smoke_project",
		), mock.patch.object(
			gf_maintenance,
			"make_core_plugin_bootstrap_smoke_environment",
			return_value=derived_environment,
		) as make_environment, mock.patch.object(
			gf_maintenance,
			"resolve_godot_executable",
			return_value="/fixture/godot",
		) as godot_resolver, mock.patch.object(
			gf_maintenance,
			"resolve_frozen_executable",
			return_value="/fixture/xvfb-run",
		) as wrapper_resolver, mock.patch.object(
			gf_maintenance,
			"resolve_command_identity",
			side_effect=lambda command, **_kwargs: gf_maintenance.CommandIdentity(
				declared=tuple(command),
				effective=tuple(command),
			),
		) as command_resolver, mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			return_value=quiet_result,
		) as supervisor, mock.patch.object(
			gf_maintenance,
			"read_text_file",
			return_value="",
		), mock.patch.object(
			gf_maintenance,
			"validate_resource_preview_translation_smoke_output",
		), mock.patch.object(
			gf_maintenance.sys,
			"platform",
			"linux",
		):
			issues: list[dict[str, object]] = []
			result = gf_maintenance.run_core_plugin_bootstrap_smoke_scenario(
				Path(temporary_directory),
				"resource_preview_translation",
				issues,
				base_environment=base_environment,
			)

		self.assertTrue(result["ok"])
		make_environment.assert_called_once_with(
			Path(temporary_directory),
			"resource_preview_translation",
			base_environment=base_environment,
		)
		godot_environment = godot_resolver.call_args.kwargs["environment"]
		wrapper_environment = wrapper_resolver.call_args.kwargs["environment"]
		identity_environment = command_resolver.call_args.kwargs["environment"]
		dispatch_environment = supervisor.call_args.kwargs["environment"]
		self.assertIs(godot_environment, wrapper_environment)
		self.assertIs(wrapper_environment, identity_environment)
		self.assertIs(identity_environment, dispatch_environment)
		self.assertIsNot(dispatch_environment, derived_environment)
		self.assertEqual(dispatch_environment, derived_environment)
		self.assertEqual(godot_resolver.call_args.kwargs["cwd"], ROOT)
		self.assertEqual(wrapper_resolver.call_args.kwargs["cwd"], ROOT)
		self.assertEqual(wrapper_resolver.call_args.kwargs["platform_name"], "posix")
		self.assertEqual(supervisor.call_args.kwargs["cwd"], ROOT)
		dispatched_command = supervisor.call_args.args[0]
		self.assertEqual(dispatched_command[0], "/fixture/xvfb-run")
		self.assertIn("/fixture/godot", dispatched_command)

	def test_translation_preview_smoke_isolates_platform_user_directories(self) -> None:
		base_environment = {"PATH": "frozen-core-path", "FROZEN_MARKER": "captured"}
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.dict(
			gf_maintenance.os.environ,
			{"PATH": "ambient-path", "AMBIENT_ONLY": "must-not-leak"},
			clear=True,
		):
			normal_environment = (
				gf_maintenance.make_core_plugin_bootstrap_smoke_environment(
					Path(temporary_directory),
					"kernel_only",
					base_environment=base_environment,
				)
			)
		self.assertEqual(normal_environment, base_environment)
		self.assertIsNot(normal_environment, base_environment)
		self.assertNotIn("AMBIENT_ONLY", normal_environment)

		platform_cases = [
			("nt", "win32", ("APPDATA", "LOCALAPPDATA", "TMPDIR", "TEMP", "TMP")),
			("posix", "darwin", ("HOME", "TMPDIR", "TEMP", "TMP")),
			(
				"posix",
				"linux",
				(
					"HOME",
					"XDG_DATA_HOME",
					"XDG_CONFIG_HOME",
					"XDG_CACHE_HOME",
					"TMPDIR",
					"TEMP",
					"TMP",
				),
			),
		]
		with tempfile.TemporaryDirectory() as temporary_directory:
			temp_root = Path(temporary_directory)
			for os_name, platform_name, isolated_fields in platform_cases:
				original_environment = dict(gf_maintenance.os.environ)
				user_home_name = (
					"gOdOt_UsEr_HoMe"
					if os_name == "nt"
					else "GODOT_USER_HOME"
				)
				base_environment = {
					"PATH": "frozen-core-path",
					user_home_name: "unsafe",
					"HOME": "frozen-home",
					"FROZEN_MARKER": "captured",
				}
				if os_name == "nt":
					base_environment.update({
						"AppData": "ambient-appdata",
						"LocalAppData": "ambient-localappdata",
						"TmpDir": "ambient-tmpdir",
						"Temp": "ambient-temp",
						"Tmp": "ambient-tmp",
						"PythonUtf8": "0",
					})
				with self.subTest(platform=platform_name), mock.patch.object(
					gf_maintenance.os,
					"name",
					os_name,
				), mock.patch.object(
					gf_maintenance.sys,
					"platform",
					platform_name,
				), mock.patch.dict(
					gf_maintenance.os.environ,
					{"PATH": "ambient-path", "AMBIENT_ONLY": "must-not-leak"},
					clear=True,
				):
					ambient_environment = dict(gf_maintenance.os.environ)
					environment = gf_maintenance.make_core_plugin_bootstrap_smoke_environment(
						temp_root,
						"resource_preview_translation",
						base_environment=base_environment,
					)
					self.assertEqual(dict(gf_maintenance.os.environ), ambient_environment)

				self.assertFalse(any(
					key.casefold() == "GODOT_USER_HOME".casefold()
					for key in environment
				))
				self.assertNotIn("AMBIENT_ONLY", environment)
				self.assertEqual(environment["PATH"], "frozen-core-path")
				self.assertEqual(environment["FROZEN_MARKER"], "captured")
				self.assertEqual(base_environment[user_home_name], "unsafe")
				self.assertEqual(dict(gf_maintenance.os.environ), original_environment)
				isolation_root = temp_root / "resource_preview_translation" / "user"
				prefix = f"{isolation_root}{os.sep}"
				for field_name in isolated_fields:
					self.assertTrue(
						environment[field_name].startswith(prefix),
						f"{platform_name} {field_name} should stay inside the smoke root",
					)
					if os_name == "nt":
						self.assertEqual(
							[
								key
								for key in environment
								if key.casefold() == field_name.casefold()
							],
							[field_name],
						)
				if os_name == "nt":
					self.assertEqual(
						[
							key
							for key in environment
							if key.casefold() == "PYTHONUTF8".casefold()
						],
						["PYTHONUTF8"],
					)

	def test_translation_preview_smoke_rejects_source_load_errors(self) -> None:
		clean_issues: list[dict[str, object]] = []
		gf_maintenance.validate_resource_preview_translation_smoke_output(
			"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK",
			"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK",
			"resource_preview_translation",
			clean_issues,
		)
		self.assertEqual(clean_issues, [])

		failed_issues: list[dict[str, object]] = []
		gf_maintenance.validate_resource_preview_translation_smoke_output(
			(
				"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK\n"
				"ERROR: Failed loading resource: res://preview_translation.csv"
			),
			"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK",
			"resource_preview_translation",
			failed_issues,
		)
		self.assertEqual(
			[item["kind"] for item in failed_issues],
			["core_plugin_bootstrap_smoke_resource_preview_source_loaded"],
		)

		callback_cases = [
			("", "", "missing success marker"),
			(
				"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK\n"
				"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK",
				"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK\n"
				"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK",
				"duplicate success marker",
			),
			(
				"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_FAILED: injected",
				"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK",
				"failure marker",
			),
		]
		for combined_output, log_text, case_name in callback_cases:
			with self.subTest(case=case_name):
				callback_issues: list[dict[str, object]] = []
				gf_maintenance.validate_resource_preview_translation_smoke_output(
					combined_output,
					log_text,
					"resource_preview_translation",
					callback_issues,
				)
				self.assertIn(
					"core_plugin_bootstrap_smoke_resource_preview_callback_failed",
					[item["kind"] for item in callback_issues],
				)

		null_translation_issues: list[dict[str, object]] = []
		gf_maintenance.validate_resource_preview_translation_smoke_output(
			(
				"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK\n"
				'ERROR: Parameter "p_translation" is null.'
			),
			"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK",
			"resource_preview_translation",
			null_translation_issues,
		)
		self.assertEqual(
			[item["kind"] for item in null_translation_issues],
			["core_plugin_bootstrap_smoke_resource_preview_source_loaded"],
		)


class LspFramingBoundaryTests(unittest.TestCase):
	def _make_client(self, connection: socket.socket) -> gdscript_lsp_diagnostics.LspClient:
		client = gdscript_lsp_diagnostics.LspClient.__new__(
			gdscript_lsp_diagnostics.LspClient
		)
		client._socket = connection
		client._next_id = 1
		client._receive_buffer = bytearray()
		return client

	def test_fragmented_frame_round_trips(self) -> None:
		client_socket, peer_socket = socket.socketpair()
		self.addCleanup(client_socket.close)
		self.addCleanup(peer_socket.close)
		client = self._make_client(client_socket)
		payload = b'{"jsonrpc":"2.0","id":1,"result":{}}'
		frame = b"Content-Length: %d\r\n\r\n" % len(payload) + payload
		for offset in range(0, len(frame), 3):
			peer_socket.sendall(frame[offset:offset + 3])
		message = client.receive(0.5)
		self.assertIsNotNone(message)
		self.assertEqual(message.payload["id"], 1)

	def test_duplicate_and_oversized_content_length_fail_closed(self) -> None:
		with self.assertRaises(gdscript_lsp_diagnostics.LspProtocolError):
			gdscript_lsp_diagnostics._parse_content_length(
				b"Content-Length: 2\r\nContent-Length: 2\r\n\r\n"
			)
		with self.assertRaises(gdscript_lsp_diagnostics.LspProtocolError):
			gdscript_lsp_diagnostics._parse_content_length(
				(
					"Content-Length: %d\r\n\r\n"
					% (gdscript_lsp_diagnostics.MAX_LSP_BODY_BYTES + 1)
				).encode("ascii")
			)

	def test_trickle_header_cannot_refresh_the_absolute_deadline(self) -> None:
		client_socket, peer_socket = socket.socketpair()
		self.addCleanup(client_socket.close)
		self.addCleanup(peer_socket.close)
		client = self._make_client(client_socket)

		def trickle() -> None:
			for byte in b"Content-Length: 2":
				try:
					peer_socket.sendall(bytes([byte]))
				except OSError:
					return
				time.sleep(0.02)

		thread = threading.Thread(target=trickle, daemon=True)
		thread.start()
		started = time.monotonic()
		with self.assertRaises(gdscript_lsp_diagnostics.LspProtocolError):
			client.receive(0.06)
		self.assertLess(time.monotonic() - started, 0.25)

	def test_non_object_json_rpc_body_is_rejected(self) -> None:
		client_socket, peer_socket = socket.socketpair()
		self.addCleanup(client_socket.close)
		self.addCleanup(peer_socket.close)
		client = self._make_client(client_socket)
		payload = b"[]"
		peer_socket.sendall(b"Content-Length: 2\r\n\r\n" + payload)
		with self.assertRaises(gdscript_lsp_diagnostics.LspProtocolError):
			client.receive(0.5)

	def test_tcp_listener_identity_resolves_the_kernel_owner_pid(self) -> None:
		if os.name != "nt" and not sys.platform.startswith("linux"):
			self.skipTest("authoritative TCP listener identity is Windows/Linux only")
		with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
			listener.bind(("127.0.0.1", 0))
			listener.listen()
			port = int(listener.getsockname()[1])
			self.assertEqual(
				gdscript_lsp_diagnostics._tcp_listener_pid("127.0.0.1", port),
				os.getpid(),
			)

	def test_tcp_established_connection_identity_resolves_the_server_owner_pid(self) -> None:
		if os.name != "nt" and not sys.platform.startswith("linux"):
			self.skipTest("authoritative TCP connection identity is Windows/Linux only")
		with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
			listener.bind(("127.0.0.1", 0))
			listener.listen()
			with socket.create_connection(listener.getsockname()) as client_connection:
				server_connection, _client_address = listener.accept()
				with server_connection:
					self.assertEqual(
						gdscript_lsp_diagnostics._tcp_connection_server_pid(
							client_connection
						),
						os.getpid(),
					)

	def test_owned_connection_identity_must_match_the_live_and_final_supervised_pid(self) -> None:
		result = gf_process_supervisor.SupervisedProcessResult(
			return_code=1,
			stdout="",
			stderr="",
			timed_out=False,
			duration_seconds=0.1,
			pid=1234,
			cancelled=True,
			process_boundary_quiescent=True,
		)
		gdscript_lsp_diagnostics._verify_live_owned_connection_identity(1234, 1234)
		gdscript_lsp_diagnostics._verify_owned_connection_identity(1234, 1234, result)
		with self.assertRaisesRegex(RuntimeError, "connection_pid=4321"):
			gdscript_lsp_diagnostics._verify_live_owned_connection_identity(4321, 1234)
		with self.assertRaisesRegex(RuntimeError, "started_pid=4321"):
			gdscript_lsp_diagnostics._verify_owned_connection_identity(1234, 4321, result)

	def test_owned_connect_rejects_ambient_server_before_lsp_client_publication(self) -> None:
		owned_process = mock.Mock()
		owned_process.wait_started_pid.return_value = 1234
		owned_process.operation_deadline = time.perf_counter() + 5.0
		connection = mock.Mock()
		with mock.patch.object(
			socket,
			"create_connection",
			return_value=connection,
		), mock.patch.object(
			gdscript_lsp_diagnostics,
			"_tcp_connection_server_pid",
			return_value=4321,
		), mock.patch.object(
			gdscript_lsp_diagnostics.LspClient,
			"from_connected_socket",
		) as publish_client:
			with self.assertRaisesRegex(RuntimeError, "connection_pid=4321"):
				gdscript_lsp_diagnostics._connect_verified_owned_lsp_client(
					owned_process,
					"127.0.0.1",
					49152,
					1.0,
				)
		publish_client.assert_not_called()
		connection.close.assert_called_once_with()

	def test_owned_connect_ignores_listener_snapshot_and_proves_the_actual_socket(self) -> None:
		owned_process = mock.Mock()
		owned_process.wait_started_pid.return_value = 1234
		owned_process.operation_deadline = time.perf_counter() + 5.0
		connection = mock.Mock()
		with mock.patch.object(
			socket,
			"create_connection",
			return_value=connection,
		), mock.patch.object(
			gdscript_lsp_diagnostics,
			"_tcp_listener_pid",
			return_value=1234,
		) as listener_snapshot, mock.patch.object(
			gdscript_lsp_diagnostics,
			"_tcp_connection_server_pid",
			return_value=4321,
		):
			with self.assertRaisesRegex(RuntimeError, "connection_pid=4321"):
				gdscript_lsp_diagnostics._connect_verified_owned_lsp_client(
					owned_process,
					"127.0.0.1",
					49152,
					1.0,
				)
		listener_snapshot.assert_not_called()

	def test_windows_tcp_table_retries_one_growth_race(self) -> None:
		import ctypes

		calls: list[bool] = []

		def query(buffer: object, size_pointer: object, *_args: object) -> int:
			calls.append(buffer is None)
			size = size_pointer._obj
			if buffer is None:
				size.value = 4
				return 122
			if len(calls) == 2:
				size.value = 28
				return 122
			ctypes.memmove(buffer, b"\x00\x00\x00\x00", 4)
			size.value = 4
			return 0

		buffer, used_size = gdscript_lsp_diagnostics._query_windows_tcp_table(query, 5)
		self.assertEqual(calls, [True, False, False])
		self.assertEqual(used_size, 4)
		self.assertEqual(buffer.raw[:4], b"\x00\x00\x00\x00")

	def test_windows_tcp_native_query_obeys_operation_deadline_and_health(self) -> None:
		release_query = threading.Event()
		query_started = threading.Event()
		query_finished = threading.Event()
		worker_was_daemon: list[bool] = []
		health_checks = 0

		def query(_buffer: object, size_pointer: object, *_args: object) -> int:
			worker_was_daemon.append(threading.current_thread().daemon)
			query_started.set()
			try:
				release_query.wait()
				size_pointer._obj.value = 4
				return 122
			finally:
				query_finished.set()

		def health_check() -> None:
			nonlocal health_checks
			health_checks += 1

		started_at = time.perf_counter()
		try:
			with self.assertRaisesRegex(
				gdscript_lsp_diagnostics.TcpOwnerLookupError,
				"operation deadline",
			):
				gdscript_lsp_diagnostics._query_windows_tcp_table(
					query,
					5,
					deadline=started_at + 0.05,
					health_check=health_check,
				)
		finally:
			release_query.set()
			self.assertTrue(query_finished.wait(1.0))

		self.assertTrue(query_started.is_set())
		self.assertEqual(worker_was_daemon, [True])
		self.assertGreater(health_checks, 1)
		self.assertLess(time.perf_counter() - started_at, 0.5)

	def test_windows_tcp_native_query_preserves_health_and_worker_control_errors(
		self,
	) -> None:
		class NativeQueryControl(BaseException):
			pass

		release_query = threading.Event()
		query_started = threading.Event()

		def blocked_query(
			_buffer: object,
			_size_pointer: object,
			*_args: object,
		) -> int:
			query_started.set()
			release_query.wait()
			return 0

		health_error = RuntimeError("fixture owner exited during native query")

		def health_check() -> None:
			if query_started.is_set():
				raise health_error

		try:
			with self.assertRaises(RuntimeError) as raised:
				gdscript_lsp_diagnostics._query_windows_tcp_table(
					blocked_query,
					5,
					deadline=time.perf_counter() + 1.0,
					health_check=health_check,
				)
			self.assertIs(raised.exception, health_error)
		finally:
			release_query.set()

		query_control = NativeQueryControl("fixture native query control")

		def control_query(
			_buffer: object,
			_size_pointer: object,
			*_args: object,
		) -> int:
			raise query_control

		with self.assertRaises(NativeQueryControl) as raised:
			gdscript_lsp_diagnostics._query_windows_tcp_table(
				control_query,
				5,
				deadline=time.perf_counter() + 1.0,
			)
		self.assertIs(raised.exception, query_control)

	def test_windows_tcp_table_rejects_byte_and_entry_budgets(self) -> None:
		import ctypes

		def oversized_initial_query(
			_buffer: object,
			size_pointer: object,
			*_args: object,
		) -> int:
			size_pointer._obj.value = (
				gdscript_lsp_diagnostics.WINDOWS_TCP_OWNER_TABLE_MAX_BYTES + 1
			)
			return 122

		with self.assertRaisesRegex(
			gdscript_lsp_diagnostics.TcpOwnerLookupError,
			"byte budget",
		):
			gdscript_lsp_diagnostics._query_windows_tcp_table(
				oversized_initial_query,
				5,
			)

		calls = 0

		def oversized_growth_query(
			buffer: object,
			size_pointer: object,
			*_args: object,
		) -> int:
			nonlocal calls
			calls += 1
			size_pointer._obj.value = (
				4
				if buffer is None
				else gdscript_lsp_diagnostics.WINDOWS_TCP_OWNER_TABLE_MAX_BYTES + 1
			)
			return 122

		with self.assertRaisesRegex(
			gdscript_lsp_diagnostics.TcpOwnerLookupError,
			"byte budget",
		):
			gdscript_lsp_diagnostics._query_windows_tcp_table(
				oversized_growth_query,
				5,
			)
		self.assertEqual(calls, 2)

		entry_table = ctypes.create_string_buffer(4)
		entry_table.raw = (
			gdscript_lsp_diagnostics.WINDOWS_TCP_OWNER_MAX_ENTRIES + 1
		).to_bytes(4, byteorder="little")
		with self.assertRaisesRegex(
			gdscript_lsp_diagnostics.TcpOwnerLookupError,
			"entry budget",
		):
			gdscript_lsp_diagnostics._windows_tcp_table_entry_count(
				entry_table,
				4,
				24,
			)

		entry_table.raw = (1).to_bytes(4, byteorder="little")
		with self.assertRaisesRegex(RuntimeError, "truncated"):
			gdscript_lsp_diagnostics._windows_tcp_table_entry_count(
				entry_table,
				4,
				24,
			)

	def test_linux_tcp_fixture_parsing_uses_native_address_byte_order(self) -> None:
		line_template = (
			"0: {local}:82F4 {remote}:C001 01 00000000:00000000 "
			"00:00000000 00000000 1000 0 12345"
		)
		for byteorder, address in (("little", "0100007F"), ("big", "7F000001")):
			with self.subTest(byteorder=byteorder), mock.patch.object(
				sys,
				"byteorder",
				byteorder,
			):
				self.assertEqual(
					gdscript_lsp_diagnostics._linux_proc_tcp_endpoint(
						"127.0.0.1",
						33524,
					),
					f"{address}:82F4",
				)
				self.assertEqual(
					gdscript_lsp_diagnostics._linux_tcp_owner_inodes(
						[line_template.format(local=address, remote=address)],
						"127.0.0.1",
						33524,
						remote_host="127.0.0.1",
						remote_port=49153,
						state="01",
					),
					{"12345"},
				)

	def test_lsp_send_uses_remaining_absolute_deadline_not_unbounded_socket(self) -> None:
		connection = mock.Mock()
		client = gdscript_lsp_diagnostics.LspClient.from_connected_socket(connection)
		boundary = gdscript_lsp_diagnostics._LspOperationBoundary()
		clock = [100.0]

		def sendall(_payload: bytes) -> None:
			clock[0] = 103.0

		connection.sendall.side_effect = sendall
		with mock.patch.object(
			gdscript_lsp_diagnostics.time,
			"perf_counter",
			side_effect=lambda: clock[0],
		), self.assertRaisesRegex(TimeoutError, "socket write exceeded"):
			client.send(
				{"jsonrpc": "2.0", "method": "fixture"},
				deadline=102.0,
				boundary=boundary,
			)

		connection.settimeout.assert_called_once_with(2.0)
		self.assertNotIn(mock.call(None), connection.settimeout.mock_calls)

	def test_initialize_cannot_cross_owned_operation_deadline(self) -> None:
		clock = [100.0]
		owned_process = mock.Mock()
		owned_process.operation_deadline = 101.0
		client = mock.Mock()
		client.request.return_value = 1

		def receive(
			_timeout: float,
			*,
			boundary: object,
		) -> None:
			_ = boundary
			clock[0] += 0.6
			return None

		client.receive.side_effect = receive
		boundary = gdscript_lsp_diagnostics._LspOperationBoundary(owned_process)
		with mock.patch.object(
			gdscript_lsp_diagnostics.time,
			"perf_counter",
			side_effect=lambda: clock[0],
		), self.assertRaisesRegex(TimeoutError, "operation deadline"):
			gdscript_lsp_diagnostics._initialize_lsp(
				client,
				ROOT,
				60.0,
				boundary=boundary,
			)

		self.assertGreaterEqual(owned_process.raise_if_finished.call_count, 2)
		client.notify.assert_not_called()

	def test_owned_connection_rechecks_health_after_same_pid_lookup(self) -> None:
		owned_process = mock.Mock()
		owned_process.wait_started_pid.return_value = 1234
		owned_process.operation_deadline = time.perf_counter() + 5.0
		lookup_complete = False

		def health_check() -> None:
			if lookup_complete:
				raise RuntimeError("fixture child exited during owner lookup")

		def owner_lookup(*_args: object, **_kwargs: object) -> int:
			nonlocal lookup_complete
			lookup_complete = True
			return 1234

		owned_process.raise_if_finished.side_effect = health_check
		connection = mock.Mock()
		with mock.patch.object(
			socket,
			"create_connection",
			return_value=connection,
		), mock.patch.object(
			gdscript_lsp_diagnostics,
			"_tcp_connection_server_pid",
			side_effect=owner_lookup,
		), mock.patch.object(
			gdscript_lsp_diagnostics.LspClient,
			"from_connected_socket",
		) as publish_client:
			with self.assertRaisesRegex(RuntimeError, "exited during owner lookup"):
				gdscript_lsp_diagnostics._connect_verified_owned_lsp_client(
					owned_process,
					"127.0.0.1",
					49152,
					1.0,
				)

		publish_client.assert_not_called()
		connection.close.assert_called_once_with()

	def test_linux_tcp_owner_lookup_enforces_pid_and_fd_entry_budgets(self) -> None:
		table_payload = (
			b"header\n"
			b"0: 0100007F:C000 0100007F:C001 01 00000000:00000000 "
			b"00:00000000 00000000 1000 0 12345\n"
		)

		def proc_entries(path: Path) -> object:
			if str(path).replace("\\", "/") == "/proc":
				return iter((Path("/proc/123"),))
			return iter((Path("/proc/123/fd/0"),))

		for budget_name, pid_budget, fd_budget, expected in (
			("pid", 0, 10, "PID budget"),
			("fd", 1, 0, "file-descriptor budget"),
		):
			with self.subTest(budget=budget_name), mock.patch.object(
				Path,
				"open",
				return_value=io.BytesIO(table_payload),
			), mock.patch.object(
				Path,
				"iterdir",
				autospec=True,
				side_effect=proc_entries,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"LINUX_TCP_OWNER_MAX_PID_ENTRIES",
				pid_budget,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"LINUX_TCP_OWNER_MAX_FD_ENTRIES",
				fd_budget,
			), self.assertRaisesRegex(
				gdscript_lsp_diagnostics.TcpOwnerLookupError,
				expected,
			):
				gdscript_lsp_diagnostics._linux_tcp_owner_pid(
					"127.0.0.1",
					49152,
					remote_host="127.0.0.1",
					remote_port=49153,
					state="01",
					deadline=time.perf_counter() + 5.0,
				)

	def test_spawn_lsp_rejects_every_fixed_port_before_process_creation(self) -> None:
		argv = [
			"gdscript_lsp_diagnostics.py",
			"--spawn-lsp",
			"--port",
			"6005",
		]
		with mock.patch.object(sys, "argv", argv), mock.patch.object(
			gdscript_lsp_diagnostics,
			"_create_owned_godot_lsp",
		) as create_owned, contextlib.redirect_stderr(io.StringIO()):
			exit_code = gdscript_lsp_diagnostics.main()
		self.assertEqual(exit_code, 2)
		create_owned.assert_not_called()

	def test_lsp_spawn_resolves_godot_against_the_execution_workspace(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			project_root = Path(temporary_directory).resolve()
			log_path = project_root / "lsp.log"
			environment = {"PATH": "frozen-lsp-path"}
			with mock.patch.object(
				gdscript_lsp_diagnostics,
				"resolve_godot_executable",
				return_value="C:/fixture/godot.exe",
			) as resolve_godot:
				actual = gdscript_lsp_diagnostics._create_owned_godot_lsp(
					"godot",
					project_root,
					49152,
					log_path,
					environment=environment,
					timeout_seconds=600.0,
				)

		resolve_godot.assert_called_once_with(
			"godot",
			environment=environment,
			cwd=project_root,
		)
		self.assertEqual(actual.cwd, project_root)
		self.assertEqual(actual.environment, environment)
		self.assertEqual(actual.timeout_seconds, 600.0)
		self.assertEqual(actual.command[0], "C:/fixture/godot.exe")
		self.assertEqual(actual.command[actual.command.index("--lsp-port") + 1], "49152")
		self.assertEqual(actual.command[actual.command.index("--path") + 1], str(project_root))

	def test_owned_lsp_process_uses_caller_owned_lease_and_requires_quiet_close(self) -> None:
		result = gf_process_supervisor.SupervisedProcessResult(
			return_code=1,
			stdout="",
			stderr="",
			timed_out=False,
			duration_seconds=0.1,
			pid=1234,
			cancelled=True,
			process_boundary_quiescent=True,
		)
		backend = mock.Mock()
		lease = _fixture_process_lease_facade(deadline=700.0, backend=backend)
		backend.pid = 1234
		backend.operation_deadline = 670.0
		backend.cancel_and_close.return_value = result
		process = gdscript_lsp_diagnostics._OwnedLspProcess(
			["C:/fixture/godot.exe", "--headless"],
			cwd=ROOT,
			environment={"PATH": "frozen-lsp-path"},
			timeout_seconds=600.0,
		)
		caller_thread = threading.get_ident()
		started_threads: list[int] = []

		def start_lease(*_args: object, **_kwargs: object) -> object:
			started_threads.append(threading.get_ident())
			publication_slot = _kwargs["publication_slot"]
			assert isinstance(
				publication_slot,
				gf_process_supervisor.SupervisedProcessLeasePublicationSlot,
			)
			publication_slot.publish(lease, deadline=float(_kwargs["deadline"]))
			return lease

		with mock.patch.object(
			gdscript_lsp_diagnostics.time,
			"perf_counter",
			return_value=100.0,
		), mock.patch.object(
			gf_process_supervisor,
			"start_supervised_process_lease",
			side_effect=start_lease,
		) as supervised:
			process.start()
			actual = process.stop()

		self.assertIs(actual, result)
		kwargs = supervised.call_args.kwargs
		self.assertEqual(supervised.call_args.args[0], ["C:/fixture/godot.exe", "--headless"])
		self.assertEqual(kwargs["cwd"], ROOT)
		self.assertEqual(kwargs["environment"], {"PATH": "frozen-lsp-path"})
		self.assertEqual(kwargs["deadline"], 700.0)
		self.assertEqual(process.wait_started_pid(0.0), 1234)
		self.assertEqual(started_threads, [caller_thread])
		self.assertNotIn("_thread", vars(process))
		backend.cancel_and_close.assert_called_once_with(deadline=700.0)

	def test_owned_lsp_publication_survives_api_return_interruption(self) -> None:
		process = gdscript_lsp_diagnostics._OwnedLspProcess(
			[sys.executable, "-c", "import time; time.sleep(30)"],
			cwd=ROOT,
			environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
			timeout_seconds=5.0,
		)
		control_error = KeyboardInterrupt("fixture API return interruption")

		def inject(checkpoint: str) -> None:
			if checkpoint == "lsp_owned_process_after_lease_api_return":
				raise control_error

		with mock.patch.object(
			gf_process_supervisor,
			"_process_supervision_checkpoint",
			side_effect=inject,
		), self.assertRaises(KeyboardInterrupt) as raised:
			process.start()

		self.assertIs(raised.exception, control_error)
		self.assertTrue(process.has_lease)
		result = process.stop()
		self.assertTrue(result.process_boundary_quiescent, result.notes)
		self.assertTrue(result.cancelled)

	def test_supervisor_publishes_the_live_direct_pid_once(self) -> None:
		published_pids: list[int] = []
		result = gf_process_supervisor.run_supervised_process(
			[sys.executable, "-c", "pass"],
			cwd=ROOT,
			timeout_seconds=5.0,
			environment=dict(os.environ),
			process_started_callback=published_pids.append,
		)
		self.assertEqual(published_pids, [result.pid])
		self.assertGreater(result.pid, 0)
		self.assertEqual(result.return_code, 0)
		self.assertTrue(result.process_boundary_quiescent)

	def test_owned_lsp_process_rejects_unproved_process_tree_cleanup(self) -> None:
		result = gf_process_supervisor.SupervisedProcessResult(
			return_code=1,
			stdout="",
			stderr="",
			timed_out=False,
			duration_seconds=0.1,
			pid=1234,
			cancelled=True,
			process_boundary_quiescent=False,
		)
		backend = mock.Mock()
		lease = _fixture_process_lease_facade(
			deadline=time.perf_counter() + 600.0,
			backend=backend,
		)
		backend.pid = 1234
		backend.cancel_and_close.return_value = result
		process = gdscript_lsp_diagnostics._OwnedLspProcess(
			["C:/fixture/godot.exe", "--headless"],
			cwd=ROOT,
			environment={},
			timeout_seconds=600.0,
		)
		with mock.patch.object(
			gf_process_supervisor,
			"start_supervised_process_lease",
			side_effect=lambda *_args, **kwargs: (
				kwargs["publication_slot"].publish(lease, deadline=kwargs["deadline"])
				or lease
			),
		):
			process.start()
			with self.assertRaisesRegex(RuntimeError, "not proven quiescent"):
				process.stop()

	def test_owned_lsp_process_surfaces_early_lease_exit(self) -> None:
		backend = mock.Mock()
		lease = _fixture_process_lease_facade(
			deadline=time.perf_counter() + 600.0,
			backend=backend,
		)
		backend.pid = 1234
		backend.poll_operation_health.side_effect = RuntimeError("fixture early exit")
		process = gdscript_lsp_diagnostics._OwnedLspProcess(
			["C:/fixture/godot.exe", "--headless"],
			cwd=ROOT,
			environment={},
			timeout_seconds=600.0,
		)
		with mock.patch.object(
			gf_process_supervisor,
			"start_supervised_process_lease",
			side_effect=lambda *_args, **kwargs: (
				kwargs["publication_slot"].publish(lease, deadline=kwargs["deadline"])
				or lease
			),
		):
			process.start()
			with self.assertRaisesRegex(RuntimeError, "became unavailable") as raised:
				process.raise_if_finished()

		self.assertIsInstance(raised.exception.__cause__, RuntimeError)
		self.assertIn("fixture early exit", str(raised.exception.__cause__))

	def test_owned_lsp_stop_rejects_quiet_early_exit_as_not_cancelled(self) -> None:
		result = gf_process_supervisor.SupervisedProcessResult(
			return_code=7,
			stdout="",
			stderr="",
			timed_out=False,
			duration_seconds=0.1,
			pid=1234,
			cancelled=False,
			process_boundary_quiescent=True,
		)
		backend = mock.Mock()
		lease = _fixture_process_lease_facade(
			deadline=time.perf_counter() + 600.0,
			backend=backend,
		)
		backend.pid = 1234
		backend.operation_deadline = time.perf_counter() + 570.0
		backend.cancel_and_close.return_value = result
		process = gdscript_lsp_diagnostics._OwnedLspProcess(
			["C:/fixture/godot.exe", "--headless"],
			cwd=ROOT,
			environment={},
			timeout_seconds=600.0,
		)
		with mock.patch.object(
			gf_process_supervisor,
			"start_supervised_process_lease",
			side_effect=lambda *_args, **kwargs: (
				kwargs["publication_slot"].publish(lease, deadline=kwargs["deadline"])
				or lease
			),
		):
			process.start()
			with self.assertRaisesRegex(RuntimeError, "did not acknowledge") as raised:
				process.stop()

		self.assertTrue(raised.exception.process_boundary_quiescent)
		self.assertFalse(raised.exception.cleanup_debt)

	def test_no_child_lsp_start_error_is_not_replaced_by_unstarted_stop(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			project_root = Path(temporary_directory).resolve()
			(project_root / "fixture.gd").write_text("extends Node\n", encoding="utf-8")
			owned_process = mock.Mock()
			owned_process.has_lease = False
			start_error = FileNotFoundError("fixture Godot missing")
			owned_process.start.side_effect = start_error
			argv = [
				"gdscript_lsp_diagnostics.py",
				"--project-root",
				str(project_root),
				"--spawn-lsp",
				"--port",
				"0",
				"--startup-timeout",
				"1",
				"--lsp-process-timeout",
				"2",
				"--include",
				"fixture.gd",
			]
			with mock.patch.object(sys, "argv", argv), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_reserve_local_port",
				return_value=49152,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_create_owned_godot_lsp",
				return_value=owned_process,
			), contextlib.redirect_stderr(io.StringIO()) as stderr:
				exit_code = gdscript_lsp_diagnostics.main()

		self.assertEqual(exit_code, 2)
		self.assertIn("fixture Godot missing", stderr.getvalue())
		owned_process.stop.assert_not_called()
		self.assertFalse(gf_process_supervisor.exception_has_cleanup_debt(start_error))

	def test_published_start_failure_audit_remains_invocation_owned(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			project_root = Path(temporary_directory).resolve()
			(project_root / "fixture.gd").write_text("extends Node\n", encoding="utf-8")
			audit_path = project_root / "lsp-audit.json"
			start_error = RuntimeError("fixture interruption after lease publication")
			result = gf_process_supervisor.SupervisedProcessResult(
				return_code=1,
				stdout="",
				stderr="",
				timed_out=False,
				duration_seconds=0.1,
				pid=4321,
				cancelled=True,
				process_boundary_quiescent=True,
			)
			owned_process = mock.Mock()
			owned_process.has_lease = True
			owned_process.start.side_effect = start_error
			owned_process.stop.return_value = result
			audit_reports: list[dict[str, object]] = []
			argv = [
				"gdscript_lsp_diagnostics.py",
				"--project-root",
				str(project_root),
				"--spawn-lsp",
				"--port",
				"0",
				"--startup-timeout",
				"1",
				"--lsp-process-timeout",
				"2",
				"--include",
				"fixture.gd",
				"--log-file",
				str(audit_path),
			]
			with mock.patch.object(sys, "argv", argv), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_reserve_local_port",
				return_value=49152,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_create_owned_godot_lsp",
				return_value=owned_process,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_write_connection_audit_log",
				side_effect=lambda _path, report: audit_reports.append(report),
			), contextlib.redirect_stderr(io.StringIO()):
				exit_code = gdscript_lsp_diagnostics.main()

		self.assertEqual(exit_code, 2)
		owned_process.stop.assert_called_once_with()
		self.assertEqual(len(audit_reports), 1)
		transport = audit_reports[0]["transport"]
		self.assertEqual(transport["mode"], "spawned")
		self.assertEqual(transport["authority"], "invocation_owned")
		self.assertTrue(transport["spawned_godot_lsp"])

	def test_lsp_main_prefers_quiet_cleanup_control_over_prior_operation_error(
		self,
	) -> None:
		class QuietCleanupControl(BaseException):
			pass

		with tempfile.TemporaryDirectory() as temporary_directory:
			project_root = Path(temporary_directory).resolve()
			(project_root / "fixture.gd").write_text("extends Node\n", encoding="utf-8")
			owned_process = mock.Mock()
			owned_process.has_lease = True
			operation_error = RuntimeError("fixture LSP connect failure")
			control_error = QuietCleanupControl("fixture quiet cleanup control")
			owned_process.stop.side_effect = control_error
			argv = [
				"gdscript_lsp_diagnostics.py",
				"--project-root",
				str(project_root),
				"--spawn-lsp",
				"--port",
				"0",
				"--startup-timeout",
				"1",
				"--lsp-process-timeout",
				"2",
				"--include",
				"fixture.gd",
			]
			with mock.patch.object(sys, "argv", argv), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_reserve_local_port",
				return_value=49152,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_create_owned_godot_lsp",
				return_value=owned_process,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_connect_verified_owned_lsp_client",
				side_effect=operation_error,
			), self.assertRaises(QuietCleanupControl) as raised:
				gdscript_lsp_diagnostics.main()

		self.assertIs(raised.exception, control_error)
		self.assertIs(raised.exception.__cause__, operation_error)
		owned_process.stop.assert_called_once_with()

	def test_lsp_main_keeps_first_operation_control_over_later_cleanup_control(
		self,
	) -> None:
		class FirstOperationControl(BaseException):
			pass

		with tempfile.TemporaryDirectory() as temporary_directory:
			project_root = Path(temporary_directory).resolve()
			(project_root / "fixture.gd").write_text("extends Node\n", encoding="utf-8")
			owned_process = mock.Mock()
			owned_process.has_lease = True
			operation_control = FirstOperationControl("first operation control")
			cleanup_control = SystemExit("later cleanup control")
			owned_process.stop.side_effect = cleanup_control
			argv = [
				"gdscript_lsp_diagnostics.py",
				"--project-root",
				str(project_root),
				"--spawn-lsp",
				"--port",
				"0",
				"--startup-timeout",
				"1",
				"--lsp-process-timeout",
				"2",
				"--include",
				"fixture.gd",
			]
			with mock.patch.object(sys, "argv", argv), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_reserve_local_port",
				return_value=49152,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_create_owned_godot_lsp",
				return_value=owned_process,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_connect_verified_owned_lsp_client",
				side_effect=operation_control,
			), self.assertRaises(FirstOperationControl) as raised:
				gdscript_lsp_diagnostics.main()

		self.assertIs(raised.exception, operation_control)
		owned_process.stop.assert_called_once_with()

	def test_partial_start_cleanup_debt_escapes_without_second_stop(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			project_root = Path(temporary_directory).resolve()
			(project_root / "fixture.gd").write_text("extends Node\n", encoding="utf-8")
			owned_process = mock.Mock()
			owned_process.has_lease = False
			deferred_cleanup = mock.Mock()
			deferred_cleanup.wait.return_value = True
			cleanup_debt = gf_process_supervisor.SupervisedProcessCleanupError(
				"fixture partial-start cleanup debt",
				deferred_cleanup=deferred_cleanup,
			)
			owned_process.start.side_effect = cleanup_debt
			argv = [
				"gdscript_lsp_diagnostics.py",
				"--project-root",
				str(project_root),
				"--spawn-lsp",
				"--port",
				"0",
				"--startup-timeout",
				"1",
				"--lsp-process-timeout",
				"2",
				"--include",
				"fixture.gd",
			]
			with mock.patch.object(sys, "argv", argv), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_reserve_local_port",
				return_value=49152,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_create_owned_godot_lsp",
				return_value=owned_process,
			), self.assertRaises(
				gf_process_supervisor.SupervisedProcessCleanupError
			) as raised:
				gdscript_lsp_diagnostics.main()

		self.assertIs(raised.exception, cleanup_debt)
		self.assertIs(raised.exception.deferred_cleanup, deferred_cleanup)
		deferred_cleanup.wait.assert_called_once_with(
			gf_process_supervisor.BINARY_PROCESS_DEFERRED_CLEANUP_SECONDS
		)
		owned_process.stop.assert_not_called()

	def test_lsp_main_consumes_deferred_authority_before_rethrowing_start_debt(
		self,
	) -> None:
		owner = gf_process_supervisor._new_process_tree_owner()
		retained_process = owner.start_lease(
			[sys.executable, "-c", "import time; time.sleep(30)"],
			cwd=ROOT,
			environment=_SHARED_PROCESS_AUTHORITY.environment.values(),
		)
		owner.close_before_deadline(time.perf_counter() + 2.0)
		with mock.patch.object(
			threading.Thread,
			"start",
			side_effect=(RuntimeError("first start"), RuntimeError("second start")),
		):
			operation = gf_process_supervisor._LeaseDeferredCleanupOperation(
				owner,
				retained_process,
				owner_closed=owner.is_closed(),
				process_tree_empty=False,
				direct_reaped=False,
				cleanup_confirmation_complete=False,
				notes=("fixture partial-start cleanup debt",),
			)
			operation.launch()
		deferred_cleanup = gf_process_supervisor.SupervisedBinaryCleanupHandle(operation)
		cleanup_debt = gf_process_supervisor.SupervisedProcessCleanupError(
			"fixture retained partial-start cleanup debt",
			deferred_cleanup=deferred_cleanup,
		)

		try:
			with tempfile.TemporaryDirectory() as temporary_directory:
				project_root = Path(temporary_directory).resolve()
				(project_root / "fixture.gd").write_text(
					"extends Node\n",
					encoding="utf-8",
				)
				owned_process = mock.Mock()
				owned_process.has_lease = False
				owned_process.start.side_effect = cleanup_debt
				argv = [
					"gdscript_lsp_diagnostics.py",
					"--project-root",
					str(project_root),
					"--spawn-lsp",
					"--port",
					"0",
					"--startup-timeout",
					"1",
					"--lsp-process-timeout",
					"2",
					"--include",
					"fixture.gd",
				]
				with mock.patch.object(sys, "argv", argv), mock.patch.object(
					gdscript_lsp_diagnostics,
					"_reserve_local_port",
					return_value=49152,
				), mock.patch.object(
					gdscript_lsp_diagnostics,
					"_create_owned_godot_lsp",
					return_value=owned_process,
				), self.assertRaises(
					gf_process_supervisor.SupervisedProcessCleanupError
				) as raised:
					gdscript_lsp_diagnostics.main()

			self.assertIs(raised.exception, cleanup_debt)
			status = deferred_cleanup.snapshot()
			self.assertTrue(status.cleanup_complete, status.notes)
			self.assertTrue(status.process_tree_empty)
			self.assertIsNotNone(retained_process.returncode)
		finally:
			if retained_process.returncode is None:
				retained_process.kill()
				retained_process.wait(timeout=2.0)

	def test_quiet_late_cleanup_combination_is_not_mislabeled_as_debt(self) -> None:
		operation_error = TimeoutError("fixture operation deadline")
		cleanup_error = RuntimeError("fixture quiet but late cleanup")
		cleanup_error.cleanup_debt = False
		cleanup_error.process_boundary_quiescent = True
		combined = gdscript_lsp_diagnostics.LspOperationCleanupError(
			operation_error,
			cleanup_error,
		)

		self.assertFalse(combined.cleanup_debt)
		self.assertTrue(combined.process_boundary_quiescent)

	def test_combined_lsp_error_keeps_operation_debt_and_settles_handle_once(self) -> None:
		handle = mock.Mock()
		handle.wait.return_value = True
		operation_error = gf_process_supervisor.SupervisedProcessCleanupError(
			"fixture operation cleanup debt",
			deferred_cleanup=handle,
		)
		cleanup_error = RuntimeError("fixture quiet ordinary cleanup issue")
		cleanup_error.cleanup_debt = False
		cleanup_error.process_boundary_quiescent = True
		cleanup_error.deferred_cleanup = handle
		combined = gdscript_lsp_diagnostics.LspOperationCleanupError(
			operation_error,
			cleanup_error,
		)

		self.assertTrue(combined.cleanup_debt)
		self.assertFalse(combined.process_boundary_quiescent)
		gdscript_lsp_diagnostics._settle_deferred_cleanups_before_propagation(
			(operation_error, cleanup_error)
		)
		handle.wait.assert_called_once_with(
			gf_process_supervisor.BINARY_PROCESS_DEFERRED_CLEANUP_SECONDS
		)

	def test_lsp_settle_rethrows_control_after_quiet_deferred_cleanup(self) -> None:
		control_error = KeyboardInterrupt("fixture settle interruption")
		handle = mock.Mock()
		handle.wait.side_effect = control_error
		handle.snapshot.return_value = (
			gf_process_supervisor.SupervisedBinaryCleanupStatus(
				complete=True,
				cleanup_complete=True,
				owner_closed=True,
				process_tree_empty=True,
				pid=4321,
			)
		)
		primary = gf_process_supervisor.SupervisedProcessCleanupError(
			"fixture primary cleanup debt",
			deferred_cleanup=handle,
		)

		with self.assertRaises(KeyboardInterrupt) as raised:
			gdscript_lsp_diagnostics._settle_deferred_cleanups_before_propagation(
				(primary,)
			)
		self.assertIs(raised.exception, control_error)

	def test_lsp_settle_wraps_control_when_deferred_boundary_remains_unproved(
		self,
	) -> None:
		control_error = SystemExit("fixture unquiet settle interruption")
		handle = mock.Mock()
		handle.wait.side_effect = control_error
		handle.snapshot.return_value = (
			gf_process_supervisor.SupervisedBinaryCleanupStatus(
				complete=True,
				cleanup_complete=False,
				owner_closed=False,
				process_tree_empty=False,
				pid=4321,
			)
		)
		primary = gf_process_supervisor.SupervisedProcessCleanupError(
			"fixture primary cleanup debt",
			deferred_cleanup=handle,
		)

		with self.assertRaises(
			gf_process_supervisor.SupervisedProcessCleanupError
		) as raised:
			gdscript_lsp_diagnostics._settle_deferred_cleanups_before_propagation(
				(primary,)
			)
		self.assertIs(raised.exception.original_error, control_error)
		self.assertIs(raised.exception.__cause__, control_error)

	def test_lsp_settle_later_control_supersedes_first_ordinary_handle_error(
		self,
	) -> None:
		first_handle = mock.Mock()
		first_wait_error = gf_process_supervisor.SupervisedProcessCleanupError(
			"fixture first handle ordinary debt"
		)
		first_handle.wait.side_effect = first_wait_error
		second_handle = mock.Mock()
		control_error = KeyboardInterrupt("fixture second handle control")
		second_handle.wait.side_effect = control_error
		second_handle.snapshot.return_value = (
			gf_process_supervisor.SupervisedBinaryCleanupStatus(
				complete=True,
				cleanup_complete=True,
				owner_closed=True,
				process_tree_empty=True,
				pid=4321,
			)
		)
		first_primary = gf_process_supervisor.SupervisedProcessCleanupError(
			"fixture first primary debt",
			deferred_cleanup=first_handle,
		)
		second_primary = gf_process_supervisor.SupervisedProcessCleanupError(
			"fixture second primary debt",
			deferred_cleanup=second_handle,
		)

		with self.assertRaises(
			gf_process_supervisor.SupervisedProcessCleanupError
		) as raised:
			gdscript_lsp_diagnostics._settle_deferred_cleanups_before_propagation(
				(first_primary, second_primary)
			)

		self.assertIs(raised.exception.original_error, control_error)
		self.assertIs(raised.exception.__cause__, control_error)
		first_handle.wait.assert_called_once()
		second_handle.wait.assert_called_once()

	def test_lsp_settle_keeps_first_control_and_observes_later_handle(self) -> None:
		first_control = KeyboardInterrupt("first deferred cleanup control")
		later_control = SystemExit("later deferred cleanup control")
		quiet_status = gf_process_supervisor.SupervisedBinaryCleanupStatus(
			complete=True,
			cleanup_complete=True,
			owner_closed=True,
			process_tree_empty=True,
			pid=4321,
		)
		first_handle = mock.Mock()
		first_handle.wait.side_effect = first_control
		first_handle.snapshot.return_value = quiet_status
		later_handle = mock.Mock()
		later_handle.wait.side_effect = later_control
		later_handle.snapshot.return_value = quiet_status
		first_primary = gf_process_supervisor.SupervisedProcessCleanupError(
			"first deferred authority",
			deferred_cleanup=first_handle,
		)
		later_primary = gf_process_supervisor.SupervisedProcessCleanupError(
			"later deferred authority",
			deferred_cleanup=later_handle,
		)

		with self.assertRaises(KeyboardInterrupt) as raised:
			gdscript_lsp_diagnostics._settle_deferred_cleanups_before_propagation(
				(first_primary, later_primary)
			)

		self.assertIs(raised.exception, first_control)
		first_handle.wait.assert_called_once()
		later_handle.wait.assert_called_once()

	def test_operation_deadline_failure_closes_lease_before_blocking_report(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			project_root = Path(temporary_directory).resolve()
			(project_root / "fixture.gd").write_text("extends Node\n", encoding="utf-8")
			result = gf_process_supervisor.SupervisedProcessResult(
				return_code=1,
				stdout="",
				stderr="",
				timed_out=False,
				duration_seconds=0.1,
				pid=4321,
				cancelled=True,
				process_boundary_quiescent=True,
			)
			owned_process = mock.Mock()
			owned_process.has_lease = True
			owned_process.operation_deadline = time.perf_counter() + 1.0
			owned_process.stop.return_value = result
			client = mock.Mock()
			argv = [
				"gdscript_lsp_diagnostics.py",
				"--project-root",
				str(project_root),
				"--spawn-lsp",
				"--port",
				"0",
				"--startup-timeout",
				"1",
				"--lsp-process-timeout",
				"2",
				"--include",
				"fixture.gd",
				"--output-json",
				str(project_root / "report.json"),
			]
			with mock.patch.object(sys, "argv", argv), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_reserve_local_port",
				return_value=49152,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_create_owned_godot_lsp",
				return_value=owned_process,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_connect_verified_owned_lsp_client",
				return_value=(client, 4321, 4321),
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_initialize_lsp",
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_verify_lsp_workspace",
				return_value=(project_root / "fixture.gd").as_uri(),
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_scan_files",
				side_effect=TimeoutError("fixture operation deadline exhausted"),
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_write_json",
			) as publish, contextlib.redirect_stderr(io.StringIO()):
				exit_code = gdscript_lsp_diagnostics.main()

		self.assertEqual(exit_code, 2)
		owned_process.stop.assert_called_once_with()
		publish.assert_not_called()

	def test_authoritative_lsp_publishes_only_after_owned_tree_is_quiet(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			project_root = Path(temporary_directory).resolve()
			(project_root / "fixture.gd").write_text("extends Node\n", encoding="utf-8")
			output_path = project_root / "report.json"
			events: list[str] = []
			result = gf_process_supervisor.SupervisedProcessResult(
				return_code=1,
				stdout="",
				stderr="",
				timed_out=False,
				duration_seconds=0.1,
				pid=4321,
				cancelled=True,
				process_boundary_quiescent=True,
			)
			owned_process = mock.Mock()
			owned_process.command = ("C:/fixture/godot.exe", "--headless")
			owned_process.has_lease = True
			owned_process.operation_deadline = time.perf_counter() + 10.0
			owned_process.stop.side_effect = lambda: events.append("stop") or result
			client = mock.Mock()

			def publish(_path: Path, report: dict[str, object]) -> None:
				events.append("publish")
				transport = report["transport"]
				self.assertEqual(transport["authority"], "invocation_owned")
				self.assertTrue(transport["dynamic_port"])
				self.assertFalse(transport["ambient_connect_allowed"])
				self.assertTrue(transport["process_boundary_quiescent"])
				self.assertEqual(transport["server_pid"], 4321)
				self.assertEqual(transport["listener_pid"], 4321)
				self.assertTrue(transport["listener_identity_verified"])

			argv = [
				"gdscript_lsp_diagnostics.py",
				"--project-root",
				str(project_root),
				"--spawn-lsp",
				"--port",
				"0",
				"--startup-timeout",
				"1",
				"--lsp-process-timeout",
				"2",
				"--include",
				"fixture.gd",
				"--output-json",
				str(output_path),
				"--format",
				"json",
			]
			with mock.patch.object(sys, "argv", argv), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_reserve_local_port",
				return_value=49152,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_create_owned_godot_lsp",
				return_value=owned_process,
			) as create_owned, mock.patch.object(
				gdscript_lsp_diagnostics,
				"_connect_verified_owned_lsp_client",
				side_effect=lambda *_args: (
					events.append("owner_verified") or (client, 4321, 4321)
				),
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"LspClient",
				return_value=client,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_initialize_lsp",
				side_effect=lambda *_args, **_kwargs: events.append("initialize"),
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_verify_lsp_workspace",
				side_effect=lambda *_args, **_kwargs: (
					events.append("workspace_probe")
					or (project_root / "addons/gf/variant/gf_variant_data.gd").as_uri()
				),
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_scan_files",
				side_effect=lambda *_args, **_kwargs: events.append("scan") or ([], []),
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_write_json",
				side_effect=publish,
			), contextlib.redirect_stdout(io.StringIO()):
				exit_code = gdscript_lsp_diagnostics.main()

		self.assertEqual(exit_code, 0)
		self.assertEqual(
			events,
			[
				"owner_verified",
				"initialize",
				"workspace_probe",
				"scan",
				"stop",
				"publish",
			],
		)
		owned_process.start.assert_called_once_with()
		self.assertEqual(create_owned.call_args.args[2], 49152)

	def test_connect_or_spawn_fallback_reports_actual_invocation_owned_authority(
		self,
	) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			project_root = Path(temporary_directory).resolve()
			(project_root / "fixture.gd").write_text("extends Node\n", encoding="utf-8")
			output_path = project_root / "report.json"
			result = gf_process_supervisor.SupervisedProcessResult(
				return_code=1,
				stdout="",
				stderr="",
				timed_out=False,
				duration_seconds=0.1,
				pid=4321,
				cancelled=True,
				process_boundary_quiescent=True,
			)
			owned_process = mock.Mock()
			owned_process.command = ("C:/fixture/godot.exe", "--headless")
			owned_process.has_lease = True
			owned_process.operation_deadline = time.perf_counter() + 10.0
			owned_process.stop.return_value = result
			client = mock.Mock()
			published_reports: list[dict[str, object]] = []
			argv = [
				"gdscript_lsp_diagnostics.py",
				"--project-root",
				str(project_root),
				"--connect-or-spawn",
				"--port",
				"6005",
				"--startup-timeout",
				"1",
				"--lsp-process-timeout",
				"2",
				"--include",
				"fixture.gd",
				"--output-json",
				str(output_path),
			]
			with mock.patch.object(sys, "argv", argv), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_wait_for_port",
				return_value=False,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_reserve_local_port",
				return_value=49152,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_create_owned_godot_lsp",
				return_value=owned_process,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_connect_verified_owned_lsp_client",
				return_value=(client, 4321, 4321),
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_initialize_lsp",
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_verify_lsp_workspace",
				return_value=(project_root / "fixture.gd").as_uri(),
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_scan_files",
				return_value=([], []),
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_write_json",
				side_effect=lambda _path, report: published_reports.append(report),
			), contextlib.redirect_stdout(io.StringIO()):
				exit_code = gdscript_lsp_diagnostics.main()

		self.assertEqual(exit_code, 0)
		self.assertEqual(len(published_reports), 1)
		transport = published_reports[0]["transport"]
		self.assertEqual(transport["authority"], "invocation_owned")
		self.assertEqual(transport["configured_port"], 6005)
		self.assertEqual(transport["port"], 49152)
		self.assertTrue(transport["dynamic_port"])
		self.assertTrue(transport["ambient_connect_allowed"])
		self.assertTrue(transport["listener_identity_verified"])
		owned_process.stop.assert_called_once_with()

	def test_authoritative_lsp_cleanup_debt_blocks_report_publication(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			project_root = Path(temporary_directory).resolve()
			(project_root / "fixture.gd").write_text("extends Node\n", encoding="utf-8")
			owned_process = mock.Mock()
			cleanup_error = gf_process_supervisor.SupervisedProcessCleanupError(
				"fixture cleanup debt"
			)
			owned_process.stop.side_effect = cleanup_error
			client = mock.Mock()
			argv = [
				"gdscript_lsp_diagnostics.py",
				"--project-root",
				str(project_root),
				"--spawn-lsp",
				"--port",
				"0",
				"--startup-timeout",
				"1",
				"--lsp-process-timeout",
				"2",
				"--include",
				"fixture.gd",
				"--output-json",
				str(project_root / "report.json"),
			]
			with mock.patch.object(sys, "argv", argv), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_reserve_local_port",
				return_value=49152,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_create_owned_godot_lsp",
				return_value=owned_process,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_connect_verified_owned_lsp_client",
				return_value=(client, 4321, 4321),
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"LspClient",
				return_value=client,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_initialize_lsp",
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_verify_lsp_workspace",
				return_value=(project_root / "fixture.gd").as_uri(),
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_scan_files",
				return_value=([], []),
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_write_json",
			) as publish:
				with self.assertRaises(
					gf_process_supervisor.SupervisedProcessCleanupError
				) as raised:
					gdscript_lsp_diagnostics.main()
			self.assertIs(raised.exception, cleanup_error)
			publish.assert_not_called()

	def test_authoritative_lsp_double_failure_preserves_the_scan_root_cause(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			project_root = Path(temporary_directory).resolve()
			(project_root / "fixture.gd").write_text("extends Node\n", encoding="utf-8")
			owned_process = mock.Mock()
			cleanup_error = gf_process_supervisor.SupervisedProcessCleanupError(
				"fixture cleanup debt"
			)
			owned_process.stop.side_effect = cleanup_error
			client = mock.Mock()
			scan_error = gdscript_lsp_diagnostics.LspProtocolError("fixture scan root cause")
			argv = [
				"gdscript_lsp_diagnostics.py",
				"--project-root",
				str(project_root),
				"--spawn-lsp",
				"--port",
				"0",
				"--startup-timeout",
				"1",
				"--lsp-process-timeout",
				"2",
				"--include",
				"fixture.gd",
			]
			with mock.patch.object(sys, "argv", argv), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_reserve_local_port",
				return_value=49152,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_create_owned_godot_lsp",
				return_value=owned_process,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_connect_verified_owned_lsp_client",
				return_value=(client, 4321, 4321),
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"LspClient",
				return_value=client,
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_initialize_lsp",
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_verify_lsp_workspace",
				return_value=(project_root / "fixture.gd").as_uri(),
			), mock.patch.object(
				gdscript_lsp_diagnostics,
				"_scan_files",
				side_effect=scan_error,
			):
				with self.assertRaises(gdscript_lsp_diagnostics.LspOperationCleanupError) as raised:
					gdscript_lsp_diagnostics.main()
		self.assertIs(raised.exception.operation_error, scan_error)
		self.assertIs(raised.exception.cleanup_error, cleanup_error)
		self.assertIs(raised.exception.__cause__, scan_error)
		self.assertIn("fixture scan root cause", str(raised.exception))
		self.assertIn("fixture cleanup debt", str(raised.exception))


class McpBoundaryTests(unittest.TestCase):
	def _tool_request(self, request_id: int, name: str, arguments: dict[str, object]) -> dict[str, object]:
		return {
			"jsonrpc": "2.0",
			"id": request_id,
			"method": "tools/call",
			"params": {"name": name, "arguments": arguments},
		}

	def test_tool_arguments_enforce_advertised_schema(self) -> None:
		too_large = gf_mcp_server.handle_message(
			self._tool_request(1, "gf_api_search", {"query": "x", "limit": 81})
		)
		self.assertEqual(too_large["error"]["code"], -32602)
		extra = gf_mcp_server.handle_message(
			self._tool_request(2, "gf_api_search", {"query": "x", "unexpected": True})
		)
		self.assertEqual(extra["error"]["code"], -32602)
		empty_checks = gf_mcp_server.handle_message(
			self._tool_request(3, "gf_run_checks", {"checks": []})
		)
		self.assertEqual(empty_checks["error"]["code"], -32602)

	def test_run_checks_schema_uses_catalog_action_names(self) -> None:
		run_checks = next(
			tool for tool in gf_mcp_server.list_tools()
			if tool["name"] == "gf_run_checks"
		)
		check_enum = run_checks["inputSchema"]["properties"]["checks"]["items"][
			"enum"
		]
		self.assertEqual(
			check_enum,
			sorted(gf_maintenance.VALIDATION_ACTION_NAMES),
		)

	def test_request_decoder_is_bounded_strict_and_object_only(self) -> None:
		with self.assertRaises(gf_mcp_server.McpRequestError):
			gf_mcp_server.decode_request_bytes(b"[]\n")
		with self.assertRaises(gf_mcp_server.McpRequestError):
			gf_mcp_server.decode_request_bytes(b'{"jsonrpc":"2.0","x":NaN}\n')
		deep_value: object = None
		for _index in range(gf_mcp_server.MAX_MCP_JSON_DEPTH + 1):
			deep_value = [deep_value]
		with self.assertRaises(gf_mcp_server.McpRequestError):
			gf_mcp_server.decode_request_bytes(
				json.dumps({"jsonrpc": "2.0", "method": "ping", "params": {"value": deep_value}}).encode("utf-8")
			)
		with self.assertRaises(gf_mcp_server.McpRequestError):
			gf_mcp_server.decode_request_bytes(
				json.dumps({
					"jsonrpc": "2.0",
					"method": "ping",
					"params": {"value": "x" * (gf_mcp_server.MAX_MCP_STRING_BYTES + 1)},
				}).encode("utf-8")
			)
		oversized = io.BytesIO(b"x" * (gf_mcp_server.MAX_MCP_REQUEST_BYTES + 1))
		with self.assertRaises(gf_mcp_server.McpRequestError):
			gf_mcp_server.read_request_bytes(oversized)

	def test_each_mcp_request_starts_with_a_fresh_api_cache(self) -> None:
		gf_maintenance._API_CACHE = None
		with mock.patch.object(gf_maintenance, "collect_api_scripts", return_value=[]) as collect:
			gf_mcp_server.handle_message(
				self._tool_request(1, "gf_api_search", {"query": "first"})
			)
			gf_mcp_server.handle_message(
				self._tool_request(2, "gf_api_search", {"query": "second"})
			)
		self.assertEqual(collect.call_count, 2)

	def test_mcp_text_serializer_rejects_non_finite_results(self) -> None:
		with self.assertRaises(ValueError):
			gf_mcp_server.tool_result({"value": float("nan")})

	def test_stdio_server_applies_validation_and_emits_strict_json(self) -> None:
		requests = b"\n".join([
			b'{"jsonrpc":"2.0","id":1,"method":"ping"}',
			b'{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"gf_api_search","arguments":{"query":"x","limit":81}}}',
		]) + b"\n"
		completed = subprocess.run(
			[sys.executable, str(TOOLS_ROOT / "gf_mcp_server.py")],
			input=requests,
			cwd=ROOT,
			capture_output=True,
			check=False,
			timeout=10.0,
		)
		self.assertEqual(completed.returncode, 0, completed.stderr.decode("utf-8"))
		responses = [json.loads(line) for line in completed.stdout.decode("utf-8").splitlines()]
		self.assertEqual(responses[0]["id"], 1)
		self.assertEqual(responses[0]["result"], {})
		self.assertEqual(responses[1]["id"], 2)
		self.assertEqual(responses[1]["error"]["code"], -32602)
		self.assertEqual(completed.stderr, b"")


class GutShardPlanIntegrationTests(unittest.TestCase):
	OBSERVATION_NONCE = "a" * 64
	INVENTORY = (
		"res://tests/gf_core/maintenance/test_alpha.gd",
		"res://tests/gf_core/kernel/test_beta.gd",
	)
	MANIFEST = {
		"schema_version": 1,
		"inventory_root": "res://tests/gf_core",
		"balancing_basis": "bootstrap_unweighted",
		"shards": [
			{
				"name": "gut-contracts",
				"role": "contracts",
				"scripts": [INVENTORY[0]],
			},
			{
				"name": "gut-lane-a",
				"role": "lane",
				"scripts": [INVENTORY[1]],
			},
		],
	}

	def _prepared_output(self) -> mock.Mock:
		invocation_directory = (
			ROOT / "build/gut-sharding" / self.OBSERVATION_NONCE
		)
		return mock.Mock(
			path=invocation_directory / "gut-authoritative.xml",
			provenance_path=(
				invocation_directory / "gut-authoritative-provenance.json"
			),
			nonce=self.OBSERVATION_NONCE,
			invocation_directory=invocation_directory,
		)

	def _manifest_patches(self) -> tuple[mock._patch, mock._patch, mock._patch]:
		return (
			mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"discover_gut_test_scripts",
				return_value=self.INVENTORY,
			),
			mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"load_and_validate_manifest",
				return_value=self.MANIFEST,
			),
			mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"canonical_digest",
				return_value="a" * 64,
			),
		)

	def _observation_report(self) -> dict[str, object]:
		return {
			"schema_version": 1,
			"observation_only": True,
			"execution_changed": False,
			"skip_count": 0,
			"reuse_count": 0,
			"shards": [
				{
					"name": "gut-contracts",
					"role": "contracts",
					"script_count": 1,
					"test_count": 2,
					"duration_seconds": 1.0,
				},
				{
					"name": "gut-lane-a",
					"role": "lane",
					"script_count": 1,
					"test_count": 2,
					"duration_seconds": 2.0,
				},
			],
		}

	def test_manifest_only_mode_never_runs_or_mutates_authoritative_gut(self) -> None:
		canonical_gut = list(gf_maintenance.CHECK_DEFINITIONS["gut"])
		discover_patch, manifest_patch, digest_patch = self._manifest_patches()
		with discover_patch, manifest_patch, digest_patch, mock.patch.object(
			gf_maintenance,
			"run_command",
		) as run_command:
			report = gf_maintenance.gut_shard_plan()
		self.assertTrue(report["ok"])
		self.assertEqual(report["mode"], "manifest_only")
		self.assertFalse(report["execution"]["performed"])
		self.assertEqual(report["execution"]["gut_run_count"], 0)
		self.assertEqual(
			[
				report["observation_policy"]["skip_count"],
				report["observation_policy"]["cache_read_count"],
				report["observation_policy"]["cache_write_count"],
				report["observation_policy"]["reuse_count"],
			],
			[0, 0, 0, 0],
		)
		self.assertEqual(gf_maintenance.CHECK_DEFINITIONS["gut"], canonical_gut)
		run_command.assert_not_called()

	def test_existing_junit_is_diagnostic_only_and_rejected_as_observation(self) -> None:
		discover_patch, manifest_patch, digest_patch = self._manifest_patches()
		junit_report = {
			"input_complete": False,
			"script_count": 2,
			"test_count": 4,
			"scripts": [],
		}
		observed_identity: tuple[int, int, int, int, int, int] | None = None
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			junit_path = fixture_root / "build/gut-sharding/existing.xml"
			junit_path.parent.mkdir(parents=True)
			junit_path.write_text("fixture", encoding="utf-8")
			observed_identity = (
				gf_maintenance.gf_gut_sharding.stable_file_identity(junit_path.lstat())
			)
			with discover_patch, manifest_patch, digest_patch, mock.patch.object(
				gf_maintenance,
				"ROOT",
				fixture_root,
			), mock.patch.object(
				gf_maintenance,
				"validate_gut_shard_junit_input_path",
				return_value=junit_path,
			), mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"parse_gut_junit_xml",
				return_value=junit_report,
			) as parse_junit, mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"build_observation_report",
			) as build_observation, mock.patch.object(
				gf_maintenance,
				"run_command",
			) as run_command:
				report = gf_maintenance.gut_shard_plan(
					junit_path="build/gut-sharding/existing.xml"
				)
		self.assertFalse(report["ok"])
		self.assertEqual(report["junit"], junit_report)
		self.assertNotIn("observation", report)
		self.assertEqual(
			[item["kind"] for item in report["issues"]],
			["gut_shard_observation_junit_rejected"],
		)
		self.assertEqual(parse_junit.call_args.args, (junit_path,))
		self.assertEqual(parse_junit.call_args.kwargs["expected_scripts"], self.INVENTORY)
		self.assertEqual(
			parse_junit.call_args.kwargs["expected_file_identity"],
			observed_identity,
		)
		self.assertNotIn("trusted_unfiltered_run", parse_junit.call_args.kwargs)
		self.assertNotIn("provenance_path", parse_junit.call_args.kwargs)
		build_observation.assert_not_called()
		run_command.assert_not_called()

	def test_explicit_run_executes_import_and_authoritative_gut_once(self) -> None:
		discover_patch, manifest_patch, digest_patch = self._manifest_patches()
		canonical_gut = list(gf_maintenance.CHECK_DEFINITIONS["gut"])
		prepared_output = self._prepared_output()
		junit_output = prepared_output.path
		import_result = gf_maintenance.CommandResult(
			name="godot_import",
			command=list(gf_maintenance.CHECK_DEFINITIONS["godot_import"]),
			exit_code=0,
			stdout="",
			stderr="",
		)
		gut_result = gf_maintenance.CommandResult(
			name="gut",
			command=canonical_gut,
			exit_code=0,
			stdout="",
			stderr="",
			gut_lifecycle_report={"ok": True},
		)
		with discover_patch, manifest_patch, digest_patch, mock.patch.object(
			gf_maintenance,
			"prepare_gut_shard_junit_output",
			return_value=prepared_output,
		), mock.patch.object(
			gf_maintenance,
			"run_command",
			side_effect=[import_result, gut_result],
		) as run_command, mock.patch.object(
			gf_maintenance,
			"parse_published_gut_shard_junit",
			return_value={"input_complete": True, "script_count": 2, "scripts": []},
		) as parse_junit, mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"build_observation_report",
			return_value=self._observation_report(),
		) as build_observation:
			report = gf_maintenance.gut_shard_plan(run_gut=True)
		self.assertTrue(report["ok"])
		self.assertEqual(report["execution"]["gut_run_count"], 1)
		self.assertTrue(report["execution"]["result_accepted"])
		self.assertEqual(run_command.call_count, 2)
		self.assertEqual(run_command.call_args_list[0].args[0], "godot_import")
		self.assertNotIn("environment", run_command.call_args_list[0].kwargs)
		gut_call = run_command.call_args_list[1]
		self.assertEqual(gut_call.args[0], "gut")
		self.assertEqual(
			gut_call.kwargs["environment"][
				gf_maintenance.GUT_SHARD_OBSERVATION_NONCE_ENVIRONMENT
			],
			self.OBSERVATION_NONCE,
		)
		self.assertEqual(
			gut_call.kwargs["environment"][
				gf_maintenance.GUT_SHARD_OBSERVATION_PATH_ENVIRONMENT
			],
			(
				"res://build/gut-sharding/"
				f"{self.OBSERVATION_NONCE}/gut-authoritative-provenance.json"
			),
		)
		self.assertEqual(
			gut_call.args[1][:-1],
			gf_maintenance.gut_shard_observation_command(
				canonical_gut,
				self.OBSERVATION_NONCE,
				"gut",
			),
		)
		self.assertEqual(
			gut_call.args[1][-1:],
			[
				f"-gjunit_xml_file={junit_output.as_posix()}",
			],
		)
		self.assertEqual(
			run_command.call_args_list[1].args[2],
			gf_maintenance.GUT_SHARD_OBSERVATION_TIMEOUT_SECONDS,
		)
		self.assertEqual(gf_maintenance.CHECK_DEFINITIONS["gut"], canonical_gut)
		parse_junit.assert_called_once_with(
			prepared_output,
			self.INVENTORY,
		)
		build_observation.assert_called_once()
		self.assertTrue(report["observation_policy"]["writes_ignored_state"])
		self.assertEqual(
			report["execution"]["junit_path"],
			f"build/gut-sharding/{self.OBSERVATION_NONCE}/gut-authoritative.xml",
		)
		self.assertEqual(
			report["execution"]["provenance_path"],
			(
				f"build/gut-sharding/{self.OBSERVATION_NONCE}/"
				"gut-authoritative-provenance.json"
			),
		)

	def test_authoritative_gut_command_rejects_filtered_missing_or_duplicate_flags(self) -> None:
		canonical_gut = list(gf_maintenance.CHECK_DEFINITIONS["gut"])
		invalid_commands = {
			"filtered_script": [
				*canonical_gut,
				"-gtest=res://tests/gf_core/kernel/test_beta.gd",
			],
			"filtered_testcase": [*canonical_gut, "-gunit_test_name=test_selected"],
			"filtered_inner_class": [*canonical_gut, "-ginner_class=TestSelected"],
			"filtered_name": [*canonical_gut, "-gselect=selected"],
			"filtered_config": [
				(
					"-gconfig=res://build/gut-sharding/filtered.json"
					if argument == gf_maintenance.GUT_SHARD_CONFIG_DISABLED_ARGUMENT
					else argument
				)
				for argument in canonical_gut
			],
			"missing_recursive_flag": [
				argument
				for argument in canonical_gut
				if argument != "-ginclude_subdirs"
			],
			"missing_directory_flag": [
				argument
				for argument in canonical_gut
				if argument != gf_maintenance.GUT_SHARD_FULL_DIRECTORY_ARGUMENT
			],
			"duplicate_recursive_flag": [*canonical_gut, "-ginclude_subdirs"],
			"duplicate_directory_flag": [
				*canonical_gut,
				gf_maintenance.GUT_SHARD_FULL_DIRECTORY_ARGUMENT,
			],
			"duplicate_managed_log": [
				*canonical_gut,
				"--log-file",
				gf_maintenance.godot_log_path("duplicate"),
			],
			"preexisting_junit_flag": [
				*canonical_gut,
				"-gjunit_xml_file=build/gut-sharding/unowned.xml",
			],
		}
		for case_name, invalid_command in invalid_commands.items():
			with self.subTest(case=case_name), mock.patch.dict(
				gf_maintenance.CHECK_DEFINITIONS,
				{"gut": invalid_command},
			), self.assertRaises(ValueError):
				gf_maintenance.authoritative_gut_shard_observation_command(
					ROOT / "build/gut-sharding" / self.OBSERVATION_NONCE / "gut-authoritative.xml",
					self.OBSERVATION_NONCE,
				)

	def test_authoritative_gut_observation_environment_replaces_folded_aliases(
		self,
	) -> None:
		invocation_directory = (
			ROOT / "build/gut-sharding" / self.OBSERVATION_NONCE
		)
		output = gf_maintenance.GutShardJunitOutput(
			path=invocation_directory / "gut-authoritative.xml",
			provenance_path=(
				invocation_directory / "gut-authoritative-provenance.json"
			),
			nonce=self.OBSERVATION_NONCE,
			root=invocation_directory.parent,
			root_identity=mock.Mock(),
			invocation_directory=invocation_directory,
			invocation_identity=mock.Mock(),
		)
		real_setter = gf_executable_resolution.set_owned_environment_value

		def set_as_windows(
			environment: dict[str, str],
			name: str,
			value: str,
			*,
			platform_name: str | None = None,
		) -> None:
			real_setter(
				environment,
				name,
				value,
				platform_name="nt",
			)

		ambient = {
			"FROZEN_MARKER": "captured",
			gf_maintenance.GUT_SHARD_OBSERVATION_NONCE_ENVIRONMENT.swapcase(): (
				"ambient-nonce"
			),
			gf_maintenance.GUT_SHARD_OBSERVATION_PATH_ENVIRONMENT.swapcase(): (
				"res://ambient.json"
			),
		}
		with mock.patch.object(
			gf_maintenance.os,
			"environ",
			ambient,
		), mock.patch.object(
			gf_maintenance,
			"set_owned_environment_value",
			side_effect=set_as_windows,
		):
			environment = gf_maintenance.gut_shard_observation_environment(output)

		self.assertEqual(environment["FROZEN_MARKER"], "captured")
		for environment_name in (
			gf_maintenance.GUT_SHARD_OBSERVATION_NONCE_ENVIRONMENT,
			gf_maintenance.GUT_SHARD_OBSERVATION_PATH_ENVIRONMENT,
		):
			self.assertEqual(
				[
					key
					for key in environment
					if key.casefold() == environment_name.casefold()
				],
				[environment_name],
			)
		self.assertEqual(
			environment[gf_maintenance.GUT_SHARD_OBSERVATION_NONCE_ENVIRONMENT],
			self.OBSERVATION_NONCE,
		)

	def test_run_command_forwards_explicit_observation_environment(self) -> None:
		environment = {
			gf_maintenance.GUT_SHARD_OBSERVATION_NONCE_ENVIRONMENT: (
				self.OBSERVATION_NONCE
			),
			gf_maintenance.GUT_SHARD_OBSERVATION_PATH_ENVIRONMENT: (
				"res://build/gut-sharding/owned/provenance.json"
			),
		}
		process_result = mock.Mock(
			timed_out=False,
			process_boundary_quiescent=True,
			return_code=0,
			stdout="",
			stderr="",
			duration_seconds=0.1,
			pid=123,
			notes=(),
		)
		resolved_godot = str((ROOT / "resolved-godot").resolve())
		expected_result = gf_maintenance.CommandResult(
			name="gut",
			command=[resolved_godot],
			exit_code=0,
			stdout="",
			stderr="",
		)
		with mock.patch.object(
			gf_maintenance,
			"resolve_command_identity",
			return_value=gf_maintenance.CommandIdentity(
				declared=("godot",),
				effective=(resolved_godot,),
			),
		) as resolve_command, mock.patch.object(
			gf_maintenance,
			"prepare_command_log_paths",
			return_value=[],
		), mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			return_value=process_result,
		) as run_process, mock.patch.object(
			gf_maintenance,
			"completed_command_result",
			return_value=expected_result,
		):
			result = gf_maintenance.run_command(
				"gut",
				["godot"],
				1200.0,
				environment=environment,
			)

		self.assertIs(result, expected_result)
		resolve_command.assert_called_once_with(
			["godot"],
			environment=environment,
			cwd=ROOT,
		)
		resolved_environment = resolve_command.call_args.kwargs["environment"]
		dispatched_environment = run_process.call_args.kwargs["environment"]
		self.assertEqual(resolved_environment, environment)
		self.assertIsNot(resolved_environment, environment)
		self.assertIs(dispatched_environment, resolved_environment)

	def test_run_command_consumes_frozen_identity_without_resolving_again(self) -> None:
		environment = {"PATH": "fixture-path"}
		resolved_godot = str((ROOT / "fixture-godot.exe").resolve())
		identity = gf_maintenance.CommandIdentity(
			declared=("godot", "--headless"),
			effective=(resolved_godot, "--headless"),
		)
		process_result = mock.Mock(
			timed_out=False,
			process_boundary_quiescent=True,
			return_code=0,
			stdout="",
			stderr="",
			duration_seconds=0.1,
			pid=123,
			notes=(),
		)
		with mock.patch.object(
			gf_maintenance,
			"resolve_command_identity",
			side_effect=AssertionError("frozen identities must not be resolved twice"),
		) as resolve_command, mock.patch.object(
			gf_maintenance,
			"prepare_command_log_paths",
			return_value=[],
		), mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			return_value=process_result,
		) as run_process:
			result = gf_maintenance.run_command(
				"gut",
				identity,
				1200.0,
				environment=environment,
			)

		resolve_command.assert_not_called()
		self.assertEqual(result.command, list(identity.effective))
		self.assertEqual(run_process.call_args.args[0], list(identity.effective))

	def test_command_identity_resolves_generic_executable_from_frozen_path(
		self,
	) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory).resolve()
			ambient_bin = root / "ambient"
			frozen_bin = root / "frozen"
			ambient_bin.mkdir()
			frozen_bin.mkdir()
			executable_name = "fixture-tool.exe" if os.name == "nt" else "fixture-tool"
			ambient_tool = ambient_bin / executable_name
			frozen_tool = frozen_bin / executable_name
			for executable in (ambient_tool, frozen_tool):
				executable.write_bytes(b"fixture")
				if os.name != "nt":
					executable.chmod(0o755)
			environment = {
				"PATH": str(frozen_bin),
				"PATHEXT": ".EXE",
			}
			with mock.patch.dict(
				os.environ,
				{"PATH": str(ambient_bin)},
				clear=True,
			):
				identity = gf_godot_process.resolve_command_identity(
					["fixture-tool", "--version"],
					environment=environment,
					cwd=root,
				)

		self.assertEqual(identity.declared, ("fixture-tool", "--version"))
		self.assertEqual(
			identity.effective,
			(str(frozen_tool.resolve()), "--version"),
		)

	def test_generic_command_resolution_rejects_folded_windows_path_ambiguity(
		self,
	) -> None:
		real_resolver = gf_executable_resolution.resolve_frozen_executable

		def resolve_as_windows(
			candidate: str,
			*,
			environment: dict[str, str],
			cwd: Path,
		) -> str:
			return real_resolver(
				candidate,
				environment=environment,
				cwd=cwd,
				platform_name="nt",
			)

		with mock.patch.object(
			gf_godot_process,
			"resolve_frozen_executable",
			side_effect=resolve_as_windows,
		), self.assertRaises(
			gf_executable_resolution.EnvironmentNameAmbiguityError
		):
			gf_godot_process.resolve_command_identity(
				["fixture-tool"],
				environment={"PATH": "first", "Path": "second"},
				cwd=ROOT,
			)

	def test_run_command_unresolved_generic_executable_is_zero_dispatch(self) -> None:
		with mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			side_effect=AssertionError(
				"Unresolved generic commands must not reach the supervisor."
			),
		) as supervisor:
			result = gf_maintenance.run_command(
				"diff",
				["fixture-missing-tool", "--check"],
				10.0,
				environment={
					"PATH": "",
					"PATHEXT": ".EXE",
					"NoDefaultCurrentDirectoryInExePath": "1",
				},
			)

		self.assertEqual(result.exit_code, 127)
		self.assertEqual(result.execution, "not_started")
		self.assertEqual(
			result.command,
			[
				gf_maintenance.UNRESOLVED_EXECUTABLE_SENTINEL,
				"--check",
			],
		)
		supervisor.assert_not_called()

	def test_godot_resolver_uses_supplied_path_and_cwd_not_ambient_path(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			ambient_bin = root / "ambient"
			frozen_bin = root / "frozen"
			ambient_bin.mkdir()
			frozen_bin.mkdir()
			executable_name = "godot.exe" if os.name == "nt" else "godot"
			ambient_godot = ambient_bin / executable_name
			frozen_godot = frozen_bin / executable_name
			for executable in (ambient_godot, frozen_godot):
				executable.write_bytes(b"fixture")
				if os.name != "nt":
					executable.chmod(0o755)
			environment = {
				"PATH": "frozen",
				"PATHEXT": ".EXE",
			}
			with mock.patch.dict(os.environ, {"PATH": str(ambient_bin)}):
				resolved = gf_maintenance.resolve_godot_executable(
					environment=environment,
					cwd=root,
				)

		self.assertEqual(resolved, str(frozen_godot.resolve()))

	def test_posix_resolver_distinguishes_missing_and_empty_path(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			executable = root / "fixture-tool"
			executable.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
			executable.chmod(0o755)

			resolved = gf_executable_resolution.resolve_frozen_executable(
				"fixture-tool",
				environment={"PATH": ""},
				cwd=root,
				platform_name="posix",
			)
			with self.assertRaises(
				gf_executable_resolution.ExecutableResolutionError
			):
				gf_executable_resolution.resolve_frozen_executable(
					"fixture-tool",
					environment={},
					cwd=root,
					platform_name="posix",
				)

		self.assertEqual(resolved, str(executable.resolve()))

	def test_posix_resolver_rejects_non_executable_targets(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			executable = root / "fixture-tool"
			executable.write_bytes(b"fixture")
			with mock.patch.object(
				gf_executable_resolution.os,
				"access",
				return_value=False,
			) as access, self.assertRaises(
				gf_executable_resolution.ExecutableResolutionError
			):
				gf_executable_resolution.resolve_frozen_executable(
					"fixture-tool",
					environment={"PATH": ""},
					cwd=root,
					platform_name="posix",
				)

		access.assert_called_once_with(executable, os.X_OK)

	def test_frozen_resolver_rejects_relative_cwd_before_filesystem_io(self) -> None:
		with mock.patch.object(
			Path,
			"is_file",
			side_effect=AssertionError("relative cwd must fail before executable lookup"),
		) as is_file, self.assertRaisesRegex(ValueError, "absolute cwd"):
			gf_executable_resolution.resolve_frozen_executable(
				"fixture-tool",
				environment={"PATH": ""},
				cwd=Path("relative-cwd"),
				platform_name="posix",
			)

		is_file.assert_not_called()

	def test_windows_resolver_reads_path_and_pathext_case_insensitively(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			path_bin = root / "path-bin"
			path_bin.mkdir()
			executable = path_bin / "fixture-tool.TOOL"
			executable.write_bytes(b"fixture")

			resolved = gf_executable_resolution.resolve_frozen_executable(
				"fixture-tool",
				environment={
					"Path": str(path_bin),
					"Pathext": ".TOOL",
					"NoDefaultCurrentDirectoryInExePath": "1",
				},
				cwd=root,
				platform_name="nt",
			)

		self.assertEqual(resolved, str(executable.resolve()))

	def test_owned_environment_write_uses_target_platform_name_semantics(self) -> None:
		canonical_name = gf_maintenance.GODOT_EXECUTABLE_ENV_VAR
		mixed_name = "gF_GoDoT_ExEcUtAbLe"
		environment = {mixed_name: "old-value", "UNCHANGED": "fixture"}
		gf_executable_resolution.set_owned_environment_value(
			environment,
			canonical_name,
			"first-value",
			platform_name="nt",
		)
		gf_executable_resolution.set_owned_environment_value(
			environment,
			canonical_name,
			"second-value",
			platform_name="nt",
		)

		self.assertEqual(environment[canonical_name], "second-value")
		self.assertEqual(environment["UNCHANGED"], "fixture")
		self.assertEqual(
			[
				key
				for key in environment
				if key.casefold() == canonical_name.casefold()
			],
			[canonical_name],
		)

		ambiguous = {
			canonical_name: "canonical",
			mixed_name: "mixed",
		}
		before = dict(ambiguous)
		with self.assertRaisesRegex(
			gf_executable_resolution.EnvironmentNameAmbiguityError,
			f"ambiguous {canonical_name}",
		):
			gf_executable_resolution.set_owned_environment_value(
				ambiguous,
				canonical_name,
				"replacement",
				platform_name="nt",
			)
		self.assertEqual(ambiguous, before)

		posix_environment = {
			canonical_name: "canonical",
			mixed_name: "distinct-posix-name",
		}
		gf_executable_resolution.set_owned_environment_value(
			posix_environment,
			canonical_name,
			"replacement",
			platform_name="posix",
		)
		self.assertEqual(posix_environment[canonical_name], "replacement")
		self.assertEqual(posix_environment[mixed_name], "distinct-posix-name")

	def test_owned_environment_removal_uses_target_platform_name_semantics(
		self,
	) -> None:
		canonical_name = gf_maintenance.GUT_SHARD_OBSERVATION_NONCE_ENVIRONMENT
		mixed_name = canonical_name.swapcase()
		windows_environment = {
			canonical_name: "canonical",
			mixed_name: "mixed",
			"UNCHANGED": "fixture",
		}
		gf_executable_resolution.remove_owned_environment_value(
			windows_environment,
			canonical_name,
			platform_name="nt",
		)
		self.assertEqual(windows_environment, {"UNCHANGED": "fixture"})

		posix_environment = {
			canonical_name: "canonical",
			mixed_name: "distinct-posix-name",
		}
		gf_executable_resolution.remove_owned_environment_value(
			posix_environment,
			canonical_name,
			platform_name="posix",
		)
		self.assertNotIn(canonical_name, posix_environment)
		self.assertEqual(posix_environment[mixed_name], "distinct-posix-name")

	def test_windows_resolver_expands_dotted_bare_command_stems(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			path_bin = root / "path-bin"
			path_bin.mkdir()
			stem = "Godot_v4.5-stable_win64"
			executable = path_bin / f"{stem}.EXE"
			executable.write_bytes(b"fixture")

			resolved = gf_executable_resolution.resolve_frozen_executable(
				stem,
				environment={
					"PATH": str(path_bin),
					"PATHEXT": ".EXE",
					"NoDefaultCurrentDirectoryInExePath": "1",
				},
				cwd=root,
				platform_name="nt",
			)

		self.assertEqual(resolved, str(executable.resolve()))

	def test_windows_godot_override_name_is_case_insensitive(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			override = root / "custom-godot.exe"
			override.write_bytes(b"fixture")

			resolved = gf_maintenance.resolve_godot_executable(
				"missing-godot",
				environment={
					"gf_godot_executable": str(override),
					"Path": "",
					"Pathext": ".BAT",
					"NoDefaultCurrentDirectoryInExePath": "1",
				},
				cwd=root,
				platform_name="nt",
			)

		self.assertEqual(resolved, str(override.resolve()))

	def test_windows_godot_override_preserves_environment_ambiguity(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
		with self.assertRaises(
			gf_executable_resolution.EnvironmentNameAmbiguityError
		) as raised:
				gf_maintenance.resolve_godot_executable(
					environment={
						gf_maintenance.GODOT_EXECUTABLE_ENV_VAR: "first.exe",
						"gF_GoDoT_ExEcUtAbLe": "second.exe",
						"PATH": "",
					},
					cwd=root,
					platform_name="nt",
				)

		self.assertIsNone(raised.exception.__cause__)

	def test_windows_explicit_pins_are_exact_and_ignore_pathext(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			pinned_root = root / "pinned"
			pinned_root.mkdir()
			for relative_candidate in (
				"pinned/tool.exe",
				"pinned/tool-without-extension",
			):
				with self.subTest(candidate=relative_candidate):
					exact_target = root / relative_candidate
					exact_target.write_bytes(b"exact fixture")
					decoy = exact_target.with_name(f"{exact_target.name}.BAT")
					decoy.write_bytes(b"PATHEXT decoy")

					resolved = gf_executable_resolution.resolve_frozen_executable(
						relative_candidate,
						environment={"PATH": "", "PATHEXT": ".BAT"},
						cwd=root,
						platform_name="nt",
					)

				self.assertEqual(resolved, str(exact_target.resolve()))

	def test_resolver_rejects_candidates_without_file_names_before_io(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			Path,
			"is_file",
			side_effect=AssertionError(
				"directory-only candidates must fail before executable lookup"
			),
		) as is_file:
			root = Path(temporary_directory)
			for platform_name, candidates in (
				("posix", (".", "..", "./", "/")),
				("nt", (".", "..", ".\\", "\\", "C:\\")),
			):
				for candidate in candidates:
					with self.subTest(
						platform=platform_name,
						candidate=candidate,
					), self.assertRaises(
						gf_executable_resolution.ExecutableResolutionError
					):
						gf_executable_resolution.resolve_frozen_executable(
							candidate,
							environment={"PATH": ""},
							cwd=root,
							platform_name=platform_name,
						)

		is_file.assert_not_called()

	def test_windows_resolver_rejects_ambiguous_environment_names_before_io(
		self,
	) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			path_bin = root / "bin"
			path_bin.mkdir()
			(path_bin / "godot.exe").write_bytes(b"decoy")
			(path_bin / "godot.cmd").write_bytes(b"decoy")
			cases = (
				(
					"PATH",
					{
						"PATH": str(path_bin),
						"Path": str(path_bin),
						"PATHEXT": ".exe",
					},
				),
				(
					"PATHEXT",
					{
						"PATH": str(path_bin),
						"PATHEXT": ".exe",
						"Pathext": ".cmd",
					},
				),
				(
					"NoDefaultCurrentDirectoryInExePath",
					{
						"PATH": str(path_bin),
						"PATHEXT": ".exe",
						"NoDefaultCurrentDirectoryInExePath": "1",
						"nodefaultcurrentdirectoryinexepath": "",
					},
				),
			)
			real_resolver = gf_godot_process.resolve_godot_executable

			def resolve_as_windows(
				configured: str = "godot",
				*,
				environment: dict[str, str],
				cwd: Path,
				platform_name: str | None = None,
			) -> str:
				return real_resolver(
					configured,
					environment=environment,
					cwd=cwd,
					platform_name="nt",
				)

			for environment_name, environment in cases:
				with self.subTest(
					environment_name=environment_name,
				), mock.patch.object(
					Path,
					"is_file",
					side_effect=AssertionError(
						"ambiguous Windows environment names must fail before executable lookup"
					),
				) as is_file, self.assertRaisesRegex(
					gf_executable_resolution.EnvironmentNameAmbiguityError,
					f"ambiguous {environment_name}",
				):
					gf_executable_resolution.resolve_frozen_executable(
						"godot",
						environment=environment,
						cwd=root,
						platform_name="nt",
					)

				is_file.assert_not_called()

				with self.subTest(
					environment_name=f"{environment_name}_dispatch",
				), mock.patch.object(
					gf_maintenance,
					"ROOT",
					root,
				), mock.patch.object(
					gf_godot_process,
					"resolve_godot_executable",
					side_effect=resolve_as_windows,
				), mock.patch.object(
					gf_maintenance,
					"run_supervised_process",
					side_effect=AssertionError(
						"ambiguous Windows environment names must fail before dispatch"
					),
				) as supervisor, self.assertRaisesRegex(
					gf_executable_resolution.EnvironmentNameAmbiguityError,
					f"ambiguous {environment_name}",
				):
					gf_maintenance.run_command(
						"gut",
						["godot", "--headless"],
						10.0,
						environment=environment,
					)

				supervisor.assert_not_called()

	def test_windows_godot_resolver_binds_bare_command_found_only_in_cwd(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			cwd_godot = root / "godot.exe"
			cwd_godot.write_bytes(b"fixture")

			resolved = gf_maintenance.resolve_godot_executable(
				environment={"PATH": "", "PATHEXT": ".exe"},
				platform_name="nt",
				cwd=root,
			)

		self.assertEqual(resolved, str(cwd_godot.resolve()))

	def test_windows_godot_resolver_honors_default_cwd_search_suppression(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			path_bin = root / "path-bin"
			path_bin.mkdir()
			cwd_godot = root / "godot.exe"
			path_godot = path_bin / "godot.exe"
			cwd_godot.write_bytes(b"cwd fixture")
			path_godot.write_bytes(b"path fixture")
			unsuppressed = gf_maintenance.resolve_godot_executable(
				environment={
					"PATH": str(path_bin),
					"PATHEXT": ".exe",
				},
				platform_name="nt",
				cwd=root,
			)
			self.assertEqual(unsuppressed, str(cwd_godot.resolve()))

			for suppression_key, suppression_value in (
				("NoDefaultCurrentDirectoryInExePath", "1"),
				("nodefaultcurrentdirectoryinexepath", "0"),
				("NODEFAULTCURRENTDIRECTORYINEXEPATH", ""),
			):
				with self.subTest(
					suppression_key=suppression_key,
					suppression_value=suppression_value,
				):
					resolved = gf_maintenance.resolve_godot_executable(
						environment={
							"PATH": str(path_bin),
							"PATHEXT": ".exe",
							suppression_key: suppression_value,
						},
						platform_name="nt",
						cwd=root,
					)

					self.assertEqual(resolved, str(path_godot.resolve()))
					pinned = gf_maintenance.resolve_godot_executable(
						"./godot.exe",
						environment={
							"PATH": str(path_bin),
							"PATHEXT": ".exe",
							suppression_key: suppression_value,
						},
						platform_name="nt",
						cwd=root,
					)
					self.assertEqual(pinned, str(cwd_godot.resolve()))

			with self.assertRaises(
				gf_maintenance.GodotExecutableResolutionError
			):
				gf_maintenance.resolve_godot_executable(
					environment={
						"PATH": "",
						"PATHEXT": ".exe",
						"NoDefaultCurrentDirectoryInExePath": "1",
					},
					platform_name="nt",
					cwd=root,
				)

	def test_windows_drive_relative_path_classification_is_host_independent(self) -> None:
		for value in (
			"C:godot.exe",
			"C:engine\\godot.exe",
			"C:",
			"C:.",
		):
			with self.subTest(value=value):
				self.assertTrue(gf_executable_resolution._is_windows_drive_relative(value))

		for value in (
			"godot.exe",
			".\\engine\\godot.exe",
			"..\\engine\\godot.exe",
			"C:\\engine\\godot.exe",
			"\\engine\\godot.exe",
			"\\\\server\\share\\godot.exe",
		):
			with self.subTest(value=value):
				self.assertFalse(gf_executable_resolution._is_windows_drive_relative(value))

		for pinned_candidate in (
			".\\engine\\godot.exe",
			"C:\\engine\\godot.exe",
		):
			with self.subTest(pinned_candidate=pinned_candidate):
				self.assertFalse(
					gf_executable_resolution._windows_search_has_drive_relative_input(
						pinned_candidate,
						{"PATH": "C:bin"},
					)
				)
		self.assertTrue(
			gf_executable_resolution._windows_search_has_drive_relative_input(
				"godot",
				{"PATH": "C:bin"},
			)
		)

	def test_windows_godot_resolver_rejects_drive_relative_candidate_before_io(
		self,
	) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			for candidate in (
				"C:godot.exe",
				"C:engine\\godot.exe",
				"C:",
			):
				for selection_source in ("configured", "environment"):
					with self.subTest(
						candidate=candidate,
						selection_source=selection_source,
					), mock.patch.object(
						Path,
						"resolve",
						side_effect=AssertionError(
							"drive-relative candidates must fail before cwd resolution"
						),
					) as resolve, mock.patch.object(
						Path,
						"is_file",
						side_effect=AssertionError(
							"drive-relative candidates must fail before filesystem lookup"
						),
					) as is_file:
						environment = {"PATH": "", "PATHEXT": ".exe"}
						configured = candidate
						if selection_source == "environment":
							environment[gf_maintenance.GODOT_EXECUTABLE_ENV_VAR] = candidate
							configured = "godot"
						with self.assertRaises(
							gf_maintenance.GodotExecutableResolutionError
						):
							gf_maintenance.resolve_godot_executable(
								configured,
								environment=environment,
								platform_name="nt",
								cwd=root,
							)
						resolve.assert_not_called()
						is_file.assert_not_called()

	def test_windows_godot_resolver_rejects_entire_drive_relative_path_before_io(
		self,
	) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			for suppression in ({}, {"NoDefaultCurrentDirectoryInExePath": "1"}):
				with self.subTest(suppression=suppression), mock.patch.object(
					Path,
					"resolve",
					side_effect=AssertionError(
						"an unsafe PATH must fail before cwd resolution"
					),
				) as resolve, mock.patch.object(
					Path,
					"is_file",
					side_effect=AssertionError(
						"an unsafe PATH entry must fail before any later root is searched"
					),
				) as is_file:
					environment = {
						"PATH": f"C:bin;{root / 'safe-bin'}",
						"PATHEXT": ".exe;.cmd",
						**suppression,
					}
					with self.assertRaises(
						gf_maintenance.GodotExecutableResolutionError
					):
						gf_maintenance.resolve_godot_executable(
							environment=environment,
							platform_name="nt",
							cwd=root,
						)
					resolve.assert_not_called()
					is_file.assert_not_called()

	def test_windows_drive_relative_search_rejects_before_cwd_validation(
		self,
	) -> None:
		scenarios = (
			(
				"candidate",
				"C:godot.exe",
				{"PATH": "", "PATHEXT": ".exe"},
			),
			(
				"path",
				"godot",
				{"PATH": "C:bin;safe-bin", "PATHEXT": ".exe"},
			),
		)
		for selection_source, configured, environment in scenarios:
			with self.subTest(selection_source=selection_source), mock.patch.object(
				Path,
				"is_absolute",
				side_effect=AssertionError(
					"unsafe search inputs must fail before cwd validation"
				),
			) as cwd_validation, mock.patch.object(
				Path,
				"is_file",
				side_effect=AssertionError(
					"unsafe search inputs must fail before file lookup"
				),
			) as is_file:
				with self.assertRaises(
					gf_maintenance.GodotExecutableResolutionError
				):
					gf_maintenance.resolve_godot_executable(
						configured,
						environment=environment,
						platform_name="nt",
						cwd=Path("relative-fixture-cwd"),
					)
				cwd_validation.assert_not_called()
				is_file.assert_not_called()

	def test_windows_drive_relative_selection_never_reaches_supervisor(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			execution_root = Path(temporary_directory)
			scenarios = (
				(
					"configured",
					["C:godot.exe", "--headless"],
					{"PATH": "", "PATHEXT": ".exe"},
				),
				(
					"environment",
					["godot", "--headless"],
					{
						gf_maintenance.GODOT_EXECUTABLE_ENV_VAR: "C:godot.exe",
						"PATH": "",
						"PATHEXT": ".exe",
					},
				),
				(
					"path",
					["godot", "--headless"],
					{
						"PATH": f"C:bin;{execution_root / 'safe-bin'}",
						"PATHEXT": ".exe",
					},
				),
			)
			for selection_source, command, environment in scenarios:
				with self.subTest(selection_source=selection_source), mock.patch.object(
					gf_maintenance,
					"ROOT",
					execution_root,
				), mock.patch.object(
					gf_godot_process.os,
					"name",
					"nt",
				), mock.patch.object(
					gf_godot_process,
					"looks_like_godot_executable",
					return_value=True,
				), mock.patch.object(
					gf_maintenance,
					"run_supervised_process",
					side_effect=AssertionError(
						"drive-relative selections must fail before supervisor dispatch"
					),
				) as supervisor:
					result = gf_maintenance.run_command(
						"gut",
						command,
						10.0,
						environment=environment,
					)

				self.assertEqual(result.exit_code, 127)
				self.assertEqual(result.execution, "not_started")
				self.assertEqual(
					result.command,
					[
						gf_maintenance.UNRESOLVED_GODOT_EXECUTABLE_SENTINEL,
						"--headless",
					],
				)
				supervisor.assert_not_called()

	def test_godot_resolver_does_not_fallback_from_configured_relative_path(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			path_bin = root / "path-bin"
			path_bin.mkdir()
			executable_name = "godot.exe" if os.name == "nt" else "godot"
			path_godot = path_bin / executable_name
			path_godot.write_bytes(b"fixture")
			if os.name != "nt":
				path_godot.chmod(0o755)
			configured = f".{os.sep}{executable_name}"

			with self.assertRaises(
				gf_maintenance.GodotExecutableResolutionError
			):
				gf_maintenance.resolve_godot_executable(
					configured,
					environment={"PATH": str(path_bin), "PATHEXT": ".EXE"},
					cwd=root,
				)

	def test_godot_resolver_does_not_fallback_from_environment_relative_path(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			path_bin = root / "path-bin"
			path_bin.mkdir()
			executable_name = "godot.exe" if os.name == "nt" else "godot"
			path_godot = path_bin / executable_name
			path_godot.write_bytes(b"fixture")
			if os.name != "nt":
				path_godot.chmod(0o755)
			configured = f".{os.sep}{executable_name}"

			with self.assertRaises(
				gf_maintenance.GodotExecutableResolutionError
			):
				gf_maintenance.resolve_godot_executable(
					environment={
						gf_maintenance.GODOT_EXECUTABLE_ENV_VAR: configured,
						"PATH": str(path_bin),
						"PATHEXT": ".EXE",
					},
					cwd=root,
				)

	def test_missing_relative_godot_pin_never_reaches_supervisor(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			execution_root = Path(temporary_directory)
			with mock.patch.object(
				gf_maintenance,
				"ROOT",
				execution_root,
			), mock.patch.object(
				gf_maintenance,
				"run_supervised_process",
				side_effect=AssertionError("a missing relative pin must not be dispatched"),
			) as supervisor:
				result = gf_maintenance.run_command(
					"gut",
					["./godot.exe", "--headless"],
					10.0,
					environment={"PATH": "", "PATHEXT": ".EXE"},
				)

		self.assertEqual(result.exit_code, 127)
		self.assertEqual(result.execution, "not_started")
		self.assertEqual(
			result.command,
			[
				gf_maintenance.UNRESOLVED_GODOT_EXECUTABLE_SENTINEL,
				"--headless",
			],
		)
		supervisor.assert_not_called()

	def test_malformed_godot_override_never_reaches_supervisor(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			execution_root = Path(temporary_directory)
			with mock.patch.object(
				gf_maintenance,
				"ROOT",
				execution_root,
			), mock.patch.object(
				gf_maintenance,
				"run_supervised_process",
				side_effect=AssertionError(
					"a malformed override must fail before supervisor dispatch"
				),
			) as supervisor:
				result = gf_maintenance.run_command(
					"gut",
					["godot", "--headless"],
					10.0,
					environment={
						gf_maintenance.GODOT_EXECUTABLE_ENV_VAR: ".",
						"PATH": "",
					},
				)

		self.assertEqual(result.exit_code, 127)
		self.assertEqual(result.execution, "not_started")
		self.assertEqual(
			result.command,
			[
				gf_maintenance.UNRESOLVED_GODOT_EXECUTABLE_SENTINEL,
				"--headless",
			],
		)
		supervisor.assert_not_called()

	def test_run_command_scrubs_ambient_observation_environment_by_default(self) -> None:
		resolved_godot = str(Path(sys.executable).resolve())
		process_result = mock.Mock(
			timed_out=False,
			process_boundary_quiescent=True,
			return_code=0,
			stdout="",
			stderr="",
			duration_seconds=0.1,
			pid=123,
			notes=(),
		)
		with mock.patch.dict(
			os.environ,
			{
				gf_maintenance.GUT_SHARD_OBSERVATION_NONCE_ENVIRONMENT: (
					self.OBSERVATION_NONCE
				),
				gf_maintenance.GUT_SHARD_OBSERVATION_PATH_ENVIRONMENT: (
					"res://build/gut-sharding/stale/provenance.json"
				),
			},
		), mock.patch.object(
			gf_maintenance,
			"resolve_command_identity",
			return_value=gf_maintenance.CommandIdentity(
				declared=("godot",),
				effective=(resolved_godot,),
			),
		) as resolve_command, mock.patch.object(
			gf_maintenance,
			"prepare_command_log_paths",
			return_value=[],
		), mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			return_value=process_result,
		) as run_process:
			gf_maintenance.run_command("gut", ["godot"], 1200.0)

		resolved_environment = resolve_command.call_args.kwargs["environment"]
		process_environment = run_process.call_args.kwargs["environment"]
		for environment in (resolved_environment, process_environment):
			self.assertNotIn(
				gf_maintenance.GUT_SHARD_OBSERVATION_NONCE_ENVIRONMENT,
				environment,
			)
			self.assertNotIn(
				gf_maintenance.GUT_SHARD_OBSERVATION_PATH_ENVIRONMENT,
				environment,
			)

	def test_run_command_maps_proven_start_failures_without_tracebacks(self) -> None:
		resolved_command = str(Path(sys.executable).resolve())
		cases = (
			(FileNotFoundError("fixture missing"), 127, "command not found"),
			(PermissionError("fixture denied"), 126, "failed to run command"),
		)
		for original, expected_exit, expected_message in cases:
			with self.subTest(error=type(original).__name__), mock.patch.object(
				gf_maintenance,
				"resolve_command_identity",
				return_value=gf_maintenance.CommandIdentity(
					declared=("fixture-command",),
					effective=(resolved_command,),
				),
			), mock.patch.object(
				gf_maintenance,
				"prepare_command_log_paths",
				return_value=[],
			), mock.patch.object(
				gf_maintenance,
				"run_supervised_process",
				side_effect=(
					gf_maintenance.gf_process_supervisor.SupervisedProcessStartError(
						original
					)
				),
			):
				result = gf_maintenance.run_command(
					"fixture",
					["fixture-command"],
					10.0,
				)

			self.assertEqual(result.exit_code, expected_exit)
			self.assertFalse(result.timed_out)
			self.assertFalse(result.cancelled)
			self.assertIn(expected_message, result.stderr)
			self.assertNotIn("Traceback", result.stderr)

	def test_run_command_start_diagnostics_ignore_hostile_string(self) -> None:
		class HostileMissing(FileNotFoundError):
			def __str__(self) -> str:
				raise SystemExit("fixture hostile start-error text")

		original = HostileMissing("fixture missing")
		resolved_command = str(Path(sys.executable).resolve())
		with mock.patch.object(
			gf_maintenance,
			"resolve_command_identity",
			return_value=gf_maintenance.CommandIdentity(
				declared=("fixture-command",),
				effective=(resolved_command,),
			),
		), mock.patch.object(
			gf_maintenance,
			"prepare_command_log_paths",
			return_value=[],
		), mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			side_effect=(
				gf_maintenance.gf_process_supervisor.SupervisedProcessStartError(
					original
				)
			),
		):
			result = gf_maintenance.run_command(
				"fixture",
				["fixture-command"],
				10.0,
			)

		self.assertEqual(result.exit_code, 127)
		self.assertIn("detail unavailable", result.stderr)

	def test_run_command_rejects_raw_supervisor_os_errors_without_boundary_proof(self) -> None:
		resolved_command = str(Path(sys.executable).resolve())
		for original_error in (
			FileNotFoundError("fixture unclassified missing executable"),
			PermissionError("fixture unclassified process failure"),
			RuntimeError("fixture unclassified runtime failure"),
		):
			with self.subTest(error=type(original_error).__name__), mock.patch.object(
				gf_maintenance,
				"resolve_command_identity",
				return_value=gf_maintenance.CommandIdentity(
					declared=("fixture-command",),
					effective=(resolved_command,),
				),
			), mock.patch.object(
				gf_maintenance,
				"prepare_command_log_paths",
				return_value=[],
			), mock.patch.object(
				gf_maintenance,
				"run_supervised_process",
				side_effect=original_error,
			):
				with self.assertRaises(
					gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError
				) as raised:
					gf_maintenance.run_command(
						"fixture",
						["fixture-command"],
						10.0,
					)
			self.assertIs(raised.exception.__cause__, original_error)
			self.assertTrue(raised.exception.cleanup_debt)

	def test_run_command_rejects_returned_unproved_process_boundary(self) -> None:
		process_result = gf_maintenance.gf_process_supervisor.SupervisedProcessResult(
			return_code=0,
			stdout="",
			stderr="",
			timed_out=False,
			duration_seconds=0.1,
			pid=123,
			process_boundary_quiescent=False,
		)
		resolved_command = str(Path(sys.executable).resolve())
		with mock.patch.object(
			gf_maintenance,
			"resolve_command_identity",
			return_value=gf_maintenance.CommandIdentity(
				declared=("fixture-command",),
				effective=(resolved_command,),
			),
		), mock.patch.object(
			gf_maintenance,
			"prepare_command_log_paths",
			return_value=[],
		), mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			return_value=process_result,
		):
			with self.assertRaises(
				gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError
			) as raised:
				gf_maintenance.run_command("fixture", ["fixture-command"], 10.0)
		self.assertTrue(raised.exception.cleanup_debt)

	def test_run_command_gut_timeout_publishes_failed_lifecycle_evidence(self) -> None:
		resolved_godot = str(Path(sys.executable).resolve())
		process_result = mock.Mock(
			timed_out=True,
			process_boundary_quiescent=True,
			return_code=-1,
			stdout="partial GUT output without a lifecycle marker",
			stderr="",
			duration_seconds=600.0,
			pid=123,
			notes=("terminated supervised process tree",),
		)
		with mock.patch.object(
			gf_maintenance,
			"resolve_command_identity",
			return_value=gf_maintenance.CommandIdentity(
				declared=("godot",),
				effective=(resolved_godot,),
			),
		), mock.patch.object(
			gf_maintenance,
			"prepare_command_log_paths",
			return_value=[],
		), mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			return_value=process_result,
		):
			result = gf_maintenance.run_command("gut", ["godot"], 600.0)

		self.assertEqual(result.exit_code, 124)
		self.assertTrue(result.timed_out)
		self.assertEqual(result.process_exit_code, -1)
		self.assertIsNotNone(result.gut_lifecycle_report)
		assert result.gut_lifecycle_report is not None
		self.assertFalse(result.gut_lifecycle_report["ok"])
		self.assertEqual(result.gut_lifecycle_report["marker_count"], 0)
		self.assertEqual(
			gf_maintenance.validate_gut_lifecycle_report(
				result.gut_lifecycle_report
			),
			"",
		)
		payload = result.to_dict()
		self.assertEqual(payload["exit_code"], 124)
		self.assertTrue(payload["timed_out"])
		self.assertEqual(payload["process_exit_code"], -1)
		self.assertEqual(
			payload["gut_lifecycle_report"],
			result.gut_lifecycle_report,
		)

	def test_import_failure_stops_before_gut_and_junit_parse(self) -> None:
		discover_patch, manifest_patch, digest_patch = self._manifest_patches()
		import_failure = gf_maintenance.CommandResult(
			name="godot_import",
			command=[],
			exit_code=1,
			stdout="",
			stderr="import failed",
		)
		with discover_patch, manifest_patch, digest_patch, mock.patch.object(
			gf_maintenance,
			"prepare_gut_shard_junit_output",
			return_value=self._prepared_output(),
		), mock.patch.object(
			gf_maintenance,
			"run_command",
			return_value=import_failure,
		) as run_command, mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"parse_gut_junit_xml",
		) as parse_junit:
			report = gf_maintenance.gut_shard_plan(run_gut=True)
		self.assertFalse(report["ok"])
		self.assertEqual(run_command.call_count, 1)
		self.assertEqual(report["execution"]["gut_run_count"], 0)
		parse_junit.assert_not_called()

	def test_process_boundary_failure_remains_a_closed_observation_report(self) -> None:
		discover_patch, manifest_patch, digest_patch = self._manifest_patches()
		with discover_patch, manifest_patch, digest_patch, mock.patch.object(
			gf_maintenance,
			"prepare_gut_shard_junit_output",
			return_value=self._prepared_output(),
		), mock.patch.object(
			gf_maintenance,
			"run_command",
			side_effect=gf_maintenance.WorkspaceSnapshotError(
				"fixture process-boundary cleanup was not proven"
			),
		):
			report = gf_maintenance.gut_shard_plan(run_gut=True)
		self.assertFalse(report["ok"])
		self.assertEqual(
			[item["kind"] for item in report["issues"]],
			["gut_shard_observation_failed"],
		)
		self.assertIn("process-boundary", report["issues"][0]["message"])

	def test_process_boundary_debt_escapes_observation_report(self) -> None:
		discover_patch, manifest_patch, digest_patch = self._manifest_patches()
		boundary_error = (
			gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError(
				"fixture unproved process boundary"
			)
		)
		with discover_patch, manifest_patch, digest_patch, mock.patch.object(
			gf_maintenance,
			"prepare_gut_shard_junit_output",
			return_value=self._prepared_output(),
		), mock.patch.object(
			gf_maintenance,
			"run_command",
			side_effect=boundary_error,
		):
			with self.assertRaises(
				gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError
			) as raised:
				gf_maintenance.gut_shard_plan(run_gut=True)
		self.assertIs(raised.exception, boundary_error)

	def test_gut_timeout_without_published_junit_remains_a_failed_observation(self) -> None:
		discover_patch, manifest_patch, digest_patch = self._manifest_patches()
		import_result = gf_maintenance.CommandResult(
			name="godot_import",
			command=[],
			exit_code=0,
			stdout="",
			stderr="",
		)
		gut_timeout = gf_maintenance.CommandResult(
			name="gut",
			command=[],
			exit_code=124,
			stdout="",
			stderr="timed out",
			timed_out=True,
			process_exit_code=1,
			notes=["Command timed out after 600s; terminating its process tree."],
			duration_seconds=600.0,
		)
		prepared_output = self._prepared_output()
		with discover_patch, manifest_patch, digest_patch, mock.patch.object(
			gf_maintenance,
			"prepare_gut_shard_junit_output",
			return_value=prepared_output,
		), mock.patch.object(
			gf_maintenance,
			"run_command",
			side_effect=[import_result, gut_timeout],
		), mock.patch.object(
			gf_maintenance,
			"parse_published_gut_shard_junit",
			side_effect=gf_maintenance.gf_gut_sharding.GutShardingError(
				"junit_file_unreadable",
				"JUnit input cannot be inspected.",
			),
		), mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"build_observation_report",
		) as build_observation:
			report = gf_maintenance.gut_shard_plan(run_gut=True)

		self.assertFalse(report["ok"])
		self.assertEqual(report["execution"]["gut_run_count"], 1)
		self.assertFalse(report["execution"]["result_accepted"])
		self.assertTrue(report["execution"]["gut"]["timed_out"])
		self.assertEqual(
			[item["kind"] for item in report["issues"]],
			["gut_shard_observation_gut_failed", "junit_file_unreadable"],
		)
		build_observation.assert_not_called()

	def test_gut_success_with_rejected_junit_is_not_accepted(self) -> None:
		discover_patch, manifest_patch, digest_patch = self._manifest_patches()
		command_result = gf_maintenance.CommandResult(
			name="command",
			command=[],
			exit_code=0,
			stdout="",
			stderr="",
		)
		prepared_output = self._prepared_output()
		with discover_patch, manifest_patch, digest_patch, mock.patch.object(
			gf_maintenance,
			"prepare_gut_shard_junit_output",
			return_value=prepared_output,
		), mock.patch.object(
			gf_maintenance,
			"run_command",
			return_value=command_result,
		), mock.patch.object(
			gf_maintenance,
			"parse_published_gut_shard_junit",
			return_value={"input_complete": False},
		), mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"build_observation_report",
		) as build_observation:
			report = gf_maintenance.gut_shard_plan(run_gut=True)

		self.assertFalse(report["ok"])
		self.assertEqual(report["execution"]["gut_run_count"], 1)
		self.assertFalse(report["execution"]["result_accepted"])
		self.assertEqual(
			[item["kind"] for item in report["issues"]],
			["gut_shard_observation_junit_rejected"],
		)
		build_observation.assert_not_called()

	def test_invalid_manifest_and_rejected_junit_fail_closed(self) -> None:
		with mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"discover_gut_test_scripts",
			return_value=self.INVENTORY,
		), mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"load_and_validate_manifest",
			side_effect=gf_maintenance.gf_gut_sharding.GutShardingError(
				"manifest_inventory_mismatch",
				"manifest inventory mismatch",
			),
		), mock.patch.object(gf_maintenance, "run_command") as run_command:
			manifest_report = gf_maintenance.gut_shard_plan()
		self.assertFalse(manifest_report["ok"])
		self.assertEqual(manifest_report["issues"][0]["kind"], "manifest_inventory_mismatch")
		run_command.assert_not_called()

		discover_patch, manifest_patch, digest_patch = self._manifest_patches()
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			junit_path = fixture_root / "build/gut-sharding/rejected.xml"
			junit_path.parent.mkdir(parents=True)
			junit_path.write_text("fixture", encoding="utf-8")
			with discover_patch, manifest_patch, digest_patch, mock.patch.object(
				gf_maintenance,
				"ROOT",
				fixture_root,
			), mock.patch.object(
				gf_maintenance,
				"validate_gut_shard_junit_input_path",
				return_value=junit_path,
			), mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"parse_gut_junit_xml",
				return_value={"input_complete": False},
			), mock.patch.object(gf_maintenance, "run_command") as run_command:
				junit_report = gf_maintenance.gut_shard_plan(
					junit_path="build/gut-sharding/rejected.xml"
				)
		self.assertFalse(junit_report["ok"])
		self.assertEqual(
			junit_report["issues"][0]["kind"],
			"gut_shard_observation_junit_rejected",
		)
		run_command.assert_not_called()

	def test_junit_read_paths_are_confined_to_ignored_build_tree(self) -> None:
		with self.assertRaises(ValueError):
			gf_maintenance.validate_gut_shard_junit_input_path(
				str(ROOT.parent / "outside.xml"),
			)

	def test_run_output_uses_fresh_invocation_owned_directory_without_unlink(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			observation_root = Path(temporary_directory) / "gut-sharding"
			observation_root.mkdir()
			sentinel = observation_root / "prior-observation.xml"
			sentinel.write_text("must survive", encoding="utf-8")
			with mock.patch.object(
				gf_maintenance,
				"GUT_SHARD_OBSERVATION_ROOT",
				observation_root,
			):
				first = gf_maintenance.prepare_gut_shard_junit_output()
				second = gf_maintenance.prepare_gut_shard_junit_output()

			self.assertNotEqual(first.invocation_directory, second.invocation_directory)
			self.assertRegex(first.nonce, r"[0-9a-f]{64}\Z")
			self.assertRegex(second.nonce, r"[0-9a-f]{64}\Z")
			self.assertEqual(first.path.name, "gut-authoritative.xml")
			self.assertEqual(second.path.name, "gut-authoritative.xml")
			self.assertEqual(
				first.provenance_path.name,
				"gut-authoritative-provenance.json",
			)
			self.assertEqual(
				second.provenance_path.name,
				"gut-authoritative-provenance.json",
			)
			self.assertTrue(first.invocation_directory.is_dir())
			self.assertTrue(second.invocation_directory.is_dir())
			self.assertFalse(first.path.exists())
			self.assertFalse(second.path.exists())
			self.assertFalse(first.provenance_path.exists())
			self.assertFalse(second.provenance_path.exists())
			self.assertEqual(first.invocation_directory.parent, observation_root)
			self.assertEqual(second.invocation_directory.parent, observation_root)
			self.assertEqual(sentinel.read_text(encoding="utf-8"), "must survive")
			self.assertFalse(
				hasattr(gf_maintenance, "remove_stale_gut_shard_junit_output")
			)

	def test_run_output_creation_refuses_existing_invocation_identity(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			observation_root = Path(temporary_directory) / "gut-sharding"
			observation_root.mkdir()
			reused_nonce = "0" * 64
			(observation_root / reused_nonce).mkdir()
			with mock.patch.object(
				gf_maintenance,
				"GUT_SHARD_OBSERVATION_ROOT",
				observation_root,
			), mock.patch.object(
				gf_maintenance.secrets,
				"token_hex",
				return_value=reused_nonce,
			), self.assertRaises(FileExistsError):
				gf_maintenance.prepare_gut_shard_junit_output()

	def test_run_output_creation_rejects_observation_root_identity_change(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			observation_root = Path(temporary_directory) / "gut-sharding"
			with mock.patch.object(
				gf_maintenance,
				"GUT_SHARD_OBSERVATION_ROOT",
				observation_root,
			), mock.patch.object(
				gf_maintenance,
				"same_owned_directory_identity",
				return_value=False,
			), self.assertRaisesRegex(ValueError, "changed while preparing"):
				gf_maintenance.prepare_gut_shard_junit_output()

	def test_published_junit_revalidates_file_identity_after_parse(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			observation_root = Path(temporary_directory) / "gut-sharding"
			with mock.patch.object(
				gf_maintenance,
				"GUT_SHARD_OBSERVATION_ROOT",
				observation_root,
			):
				output = gf_maintenance.prepare_gut_shard_junit_output()
			output.path.write_text("before", encoding="utf-8")
			output.provenance_path.write_text("provenance", encoding="utf-8")

			def replace_during_parse(*_args: object, **_kwargs: object) -> dict[str, object]:
				replacement = output.path.with_name("replacement.xml")
				replacement.write_text("after payload", encoding="utf-8")
				os.replace(replacement, output.path)
				return {"input_complete": True}

			with mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"parse_gut_junit_xml",
				side_effect=replace_during_parse,
			) as parse_junit, self.assertRaisesRegex(ValueError, "changed while parsing"):
				gf_maintenance.parse_published_gut_shard_junit(output, self.INVENTORY)
			self.assertTrue(parse_junit.call_args.kwargs["trusted_unfiltered_run"])
			self.assertEqual(
				parse_junit.call_args.kwargs["provenance_path"],
				output.provenance_path,
			)
			self.assertEqual(
				parse_junit.call_args.kwargs["expected_provenance_nonce"],
				output.nonce,
			)

	def test_published_junit_revalidates_provenance_identity_after_parse(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			observation_root = Path(temporary_directory) / "gut-sharding"
			with mock.patch.object(
				gf_maintenance,
				"GUT_SHARD_OBSERVATION_ROOT",
				observation_root,
			):
				output = gf_maintenance.prepare_gut_shard_junit_output()
			output.path.write_text("junit", encoding="utf-8")
			output.provenance_path.write_text("before", encoding="utf-8")

			def replace_during_parse(*_args: object, **_kwargs: object) -> dict[str, object]:
				replacement = output.provenance_path.with_name("replacement.json")
				replacement.write_text("after payload", encoding="utf-8")
				os.replace(replacement, output.provenance_path)
				return {"input_complete": True}

			with mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"parse_gut_junit_xml",
				side_effect=replace_during_parse,
			), self.assertRaisesRegex(ValueError, "changed while parsing"):
				gf_maintenance.parse_published_gut_shard_junit(output, self.INVENTORY)

	def test_published_junit_rejects_real_root_and_invocation_replacement(self) -> None:
		for replacement_kind in ("root", "invocation"):
			with self.subTest(replacement=replacement_kind), tempfile.TemporaryDirectory() as temporary_directory:
				fixture_root = Path(temporary_directory)
				observation_root = fixture_root / "gut-sharding"
				with mock.patch.object(
					gf_maintenance,
					"GUT_SHARD_OBSERVATION_ROOT",
					observation_root,
				):
					output = gf_maintenance.prepare_gut_shard_junit_output()
				output.path.write_text("before", encoding="utf-8")
				output.provenance_path.write_text("provenance", encoding="utf-8")
				original = (
					output.root.with_name("gut-sharding-original")
					if replacement_kind == "root"
					else output.invocation_directory.with_name(
						f"{output.invocation_directory.name}-original"
					)
				)
				link = output.root if replacement_kind == "root" else output.invocation_directory
				target = fixture_root / f"replacement-{replacement_kind}"

				def replace_directory_during_parse(
					*_args: object,
					**_kwargs: object,
				) -> dict[str, object]:
					link.rename(original)
					if replacement_kind == "root":
						replacement_invocation = target / output.invocation_directory.name
						replacement_invocation.mkdir(parents=True)
						(replacement_invocation / output.path.name).write_text(
							"replacement",
							encoding="utf-8",
						)
					else:
						target.mkdir()
						(target / output.path.name).write_text(
							"replacement",
							encoding="utf-8",
						)
					gf_maintenance.create_directory_link_fixture(target, link)
					return {"input_complete": True}

				try:
					with mock.patch.object(
						gf_maintenance.gf_gut_sharding,
						"parse_gut_junit_xml",
						side_effect=replace_directory_during_parse,
					), self.assertRaises(ValueError):
						gf_maintenance.parse_published_gut_shard_junit(
							output,
							self.INVENTORY,
						)
				finally:
					_remove_directory_link_fixture(link)
					original.rename(link)

	def test_published_junit_rejects_ordinary_root_and_invocation_replacement(self) -> None:
		for replacement_kind in ("root", "invocation"):
			with self.subTest(replacement=replacement_kind), tempfile.TemporaryDirectory() as temporary_directory:
				fixture_root = Path(temporary_directory)
				observation_root = fixture_root / "gut-sharding"
				with mock.patch.object(
					gf_maintenance,
					"GUT_SHARD_OBSERVATION_ROOT",
					observation_root,
				):
					output = gf_maintenance.prepare_gut_shard_junit_output()
				output.path.write_text("before", encoding="utf-8")
				output.provenance_path.write_text("provenance", encoding="utf-8")
				replaced_path = (
					output.root
					if replacement_kind == "root"
					else output.invocation_directory
				)
				original = replaced_path.with_name(f"{replaced_path.name}-original")
				replacement = fixture_root / f"replacement-{replacement_kind}"

				def replace_directory_during_parse(
					*_args: object,
					**_kwargs: object,
				) -> dict[str, object]:
					replaced_path.rename(original)
					if replacement_kind == "root":
						replacement_output = (
							replacement / output.invocation_directory.name / output.path.name
						)
					else:
						replacement_output = replacement / output.path.name
					replacement_output.parent.mkdir(parents=True)
					replacement_output.write_text("replacement", encoding="utf-8")
					replacement.rename(replaced_path)
					return {"input_complete": True}

				with mock.patch.object(
					gf_maintenance.gf_gut_sharding,
					"parse_gut_junit_xml",
					side_effect=replace_directory_during_parse,
				), self.assertRaises(ValueError):
					gf_maintenance.parse_published_gut_shard_junit(
						output,
						self.INVENTORY,
					)

	def test_existing_junit_revalidates_file_identity_after_parse(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			path = fixture_root / "build/gut-sharding/existing.xml"
			path.parent.mkdir(parents=True)
			path.write_text("before", encoding="utf-8")

			def replace_during_parse(*_args: object, **_kwargs: object) -> dict[str, object]:
				replacement = path.with_name("replacement.xml")
				replacement.write_text("after payload", encoding="utf-8")
				os.replace(replacement, path)
				return {"input_complete": True}

			with mock.patch.object(
				gf_maintenance,
				"ROOT",
				fixture_root,
			), mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"parse_gut_junit_xml",
				side_effect=replace_during_parse,
			), self.assertRaisesRegex(ValueError, "changed while parsing"):
				gf_maintenance.parse_existing_gut_shard_junit(path, self.INVENTORY)

	def test_existing_junit_rejects_real_parent_directory_replacement(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			parent = fixture_root / "build/gut-sharding"
			path = parent / "existing.xml"
			parent.mkdir(parents=True)
			path.write_text("before", encoding="utf-8")
			original = parent.with_name("gut-sharding-original")
			target = fixture_root / "replacement-parent"

			def replace_parent_during_parse(
				*_args: object,
				**_kwargs: object,
			) -> dict[str, object]:
				parent.rename(original)
				target.mkdir()
				(target / path.name).write_text("replacement", encoding="utf-8")
				gf_maintenance.create_directory_link_fixture(target, parent)
				return {"input_complete": True}

			try:
				with mock.patch.object(
					gf_maintenance,
					"ROOT",
					fixture_root,
				), mock.patch.object(
					gf_maintenance.gf_gut_sharding,
					"parse_gut_junit_xml",
					side_effect=replace_parent_during_parse,
				), self.assertRaises(ValueError):
					gf_maintenance.parse_existing_gut_shard_junit(path, self.INVENTORY)
			finally:
				_remove_directory_link_fixture(parent)
				original.rename(parent)

	def test_existing_junit_rejects_ordinary_build_and_parent_replacement(self) -> None:
		for replacement_kind in ("build", "parent"):
			with self.subTest(replacement=replacement_kind), tempfile.TemporaryDirectory() as temporary_directory:
				fixture_root = Path(temporary_directory)
				build = fixture_root / "build"
				parent = build / "gut-sharding"
				path = parent / "existing.xml"
				parent.mkdir(parents=True)
				path.write_text("before", encoding="utf-8")
				replaced_path = build if replacement_kind == "build" else parent
				original = replaced_path.with_name(f"{replaced_path.name}-original")
				replacement = fixture_root / f"replacement-{replacement_kind}"

				def replace_directory_during_parse(
					*_args: object,
					**_kwargs: object,
				) -> dict[str, object]:
					replaced_path.rename(original)
					replacement_output = (
						replacement / "gut-sharding" / path.name
						if replacement_kind == "build"
						else replacement / path.name
					)
					replacement_output.parent.mkdir(parents=True)
					replacement_output.write_text("replacement", encoding="utf-8")
					replacement.rename(replaced_path)
					return {"input_complete": True}

				with mock.patch.object(
					gf_maintenance,
					"ROOT",
					fixture_root,
				), mock.patch.object(
					gf_maintenance.gf_gut_sharding,
					"parse_gut_junit_xml",
					side_effect=replace_directory_during_parse,
				), self.assertRaises(ValueError):
					gf_maintenance.parse_existing_gut_shard_junit(
						path,
						self.INVENTORY,
					)

	def test_authoritative_gut_timeouts_have_a_twenty_minute_floor(self) -> None:
		self.assertEqual(
			gf_maintenance.resolve_gut_shard_observation_timeout_seconds(None),
			1200,
		)
		self.assertEqual(
			gf_maintenance.resolve_gut_shard_observation_timeout_seconds(30),
			1200,
		)
		self.assertEqual(
			gf_maintenance.resolve_gut_shard_observation_timeout_seconds(1500),
			1500,
		)
		self.assertEqual(
			gf_maintenance._VALIDATION_CATALOG.timeout_floor_seconds("gut"),
			1200,
		)
		self.assertEqual(
			gf_maintenance.resolve_check_timeout_seconds("gut", None),
			1200,
		)
		self.assertEqual(
			gf_maintenance.resolve_check_timeout_seconds("gut", 600),
			1200,
		)
		self.assertEqual(
			gf_maintenance.resolve_check_timeout_seconds("gut", 1500),
			1500,
		)
		framework_gut = next(
			shard
			for shard in gf_maintenance.parallel_full_shard_plan(
				_full_validation_plan()
			)
			if shard.name == "framework-gut"
		)
		self.assertEqual(
			gf_maintenance.parallel_shard_timeout_seconds(
				framework_gut,
				None,
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
			),
			2820,
		)

	def test_gut_observation_timeout_consumes_the_catalog_floor(self) -> None:
		timeout_catalog = mock.Mock()
		timeout_catalog.timeout_floor_seconds.return_value = 1301

		with mock.patch.object(
			gf_maintenance,
			"_VALIDATION_CATALOG",
			timeout_catalog,
		):
			self.assertEqual(
				gf_maintenance.resolve_gut_shard_observation_timeout_seconds(None),
				1301,
			)
			self.assertEqual(
				gf_maintenance.resolve_gut_shard_observation_timeout_seconds(1500),
				1500,
			)

		timeout_catalog.timeout_floor_seconds.assert_has_calls([
			mock.call("gut"),
			mock.call("gut"),
		])

	def test_parallel_shard_timeout_consumes_each_catalog_floor(self) -> None:
		floor_by_action = {
			"godot_import": 501,
			"gut_lifecycle_smoke": 502,
			"gut": 503,
			"gdscript_warnings": 504,
		}
		timeout_catalog = mock.Mock()
		timeout_catalog.timeout_floor_seconds.side_effect = floor_by_action.__getitem__
		shard = gf_maintenance.ParallelCheckShardPlan(
			name="framework-gut",
			checks=("gut", "gut_lifecycle_smoke", "gdscript_warnings"),
			execution_checks=tuple(floor_by_action),
		)

		resolved = gf_maintenance.parallel_shard_timeout_seconds(
			shard,
			None,
			validation_catalog=timeout_catalog,
		)

		self.assertEqual(
			resolved,
			sum(floor_by_action.values())
			+ gf_maintenance.PARALLEL_SHARD_STARTUP_ALLOWANCE_SECONDS,
		)
		timeout_catalog.timeout_floor_seconds.assert_has_calls([
			mock.call(action_name)
			for action_name in floor_by_action
		])

	def test_parallel_child_supervisor_timeout_uses_the_passed_catalog(self) -> None:
		timeout_catalog = mock.Mock()
		timeout_catalog.timeout_floor_seconds.return_value = 5000
		plan = gf_maintenance.ParallelCheckShardPlan(
			name="framework-static",
			checks=("api",),
			execution_checks=("api",),
		)
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_maintenance,
			"parallel_shard_environment",
			return_value=({}, Path(temporary_directory) / "user"),
		):
			shard, _report_path = gf_maintenance.make_parallel_full_shard(
				plan,
				Path(temporary_directory),
				validation_catalog=timeout_catalog,
				private_environment_root=Path(temporary_directory) / "private",
				timeout_seconds=None,
				suite_deadline=None,
				fail_fast=False,
				package_artifact_manifest="",
				package_artifact_manifest_sha256="",
			)

		self.assertEqual(
			shard.timeout_seconds,
			5000 + gf_maintenance.PARALLEL_SHARD_STARTUP_ALLOWANCE_SECONDS,
		)
		timeout_catalog.timeout_floor_seconds.assert_called_once_with("api")

	def test_renderer_exposes_diagnostic_completeness_and_duration_scope(self) -> None:
		text = gf_maintenance_rendering.render_gut_shard_plan_text({
			"ok": True,
			"mode": "existing_junit",
			"inventory_count": 1,
			"shard_count": 1,
			"manifest_path": "tests/gf_core/gut_shard_manifest.json",
			"manifest_digest": "a" * 64,
			"shards": [],
			"observation_policy": {
				"skip_count": 0,
				"cache_read_count": 0,
				"cache_write_count": 0,
				"reuse_count": 0,
			},
			"execution": {"performed": False, "result_accepted": False},
			"junit": {
				"input_complete": False,
				"completeness_basis": "script_names_only",
				"duration_scope": "testcase_only_excludes_script_lifecycle",
				"assertion_counts_complete": False,
				"assertion_count_unknown_reason": (
					"script_lifecycle_assertions_not_exported"
				),
				"script_count": 1,
				"test_count": 5,
				"assertion_count": 7,
				"lifecycle_assertion_count": 0,
				"duration_seconds": 0.5,
				"testcase_duration_seconds": 0.5,
				"status_counts": {
					"passed": 1,
					"failed": 1,
					"pending": 1,
					"no_asserts": 1,
					"skipped": 1,
				},
			},
			"issues": [],
		})

		self.assertIn(
			"statuses=passed=1, failed=1, pending=1, no_asserts=1, skipped=1",
			text,
		)
		self.assertIn(
			"policy: skips=0 cache_reads=0 cache_writes=0 reuse=0",
			text,
		)
		self.assertIn(
			"execution: performed=False result_accepted=False",
			text,
		)
		self.assertIn("input_complete=False", text)
		self.assertIn("completeness_basis=script_names_only", text)
		self.assertIn(
			"duration_scope=testcase_only_excludes_script_lifecycle",
			text,
		)
		self.assertIn("assertion_counts_complete=False", text)
		self.assertIn("lifecycle_assertion_count=0", text)
		self.assertIn(
			"assertion_count_unknown_reason=script_lifecycle_assertions_not_exported",
			text,
		)

	def test_full_synthetic_existing_junit_remains_diagnostic_only(self) -> None:
		inventory = (
			gf_maintenance.gf_gut_sharding.LIFECYCLE_CONTRACT_SCRIPT,
		)
		manifest = gf_maintenance.gf_gut_sharding._bootstrap_manifest_for_inventory(
			inventory
		)
		expected_count = len(inventory)
		root_element = ET.Element(
			"testsuites",
			{"name": "GutTests", "failures": "0", "tests": str(len(inventory))},
		)
		for script in inventory:
			junit_script = script.removeprefix("res://")
			suite = ET.SubElement(
				root_element,
				"testsuite",
				{
					"name": junit_script,
					"tests": "1",
					"failures": "0",
					"skipped": "0",
					"time": "0.001",
				},
			)
			ET.SubElement(
				suite,
				"testcase",
				{
					"name": "test_synthetic_observation",
					"assertions": "1",
					"status": "pass",
					"classname": junit_script,
					"time": "0.001",
				},
			)

		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			junit_path = fixture_root / "build/gut-sharding/full.xml"
			junit_path.parent.mkdir(parents=True)
			junit_path.write_bytes(
				b'<?xml version="1.0" encoding="UTF-8"?>\n'
				+ ET.tostring(root_element, encoding="utf-8"),
			)
			with mock.patch.object(gf_maintenance, "ROOT", fixture_root), mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"discover_gut_test_scripts",
				return_value=inventory,
			), mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"load_and_validate_manifest",
				return_value=manifest,
			):
				report = gf_maintenance.gut_shard_plan(junit_path=str(junit_path))

		self.assertFalse(report["ok"])
		self.assertEqual(report["mode"], "existing_junit")
		self.assertEqual(report["inventory_count"], expected_count)
		self.assertFalse(report["junit"]["input_complete"])
		self.assertEqual(report["junit"]["script_count"], expected_count)
		self.assertEqual(report["junit"]["test_count"], expected_count)
		self.assertNotIn("observation", report)
		self.assertEqual(
			[item["kind"] for item in report["issues"]],
			["gut_shard_observation_junit_rejected"],
		)


class GutShardRuntimeSourceBindingTests(unittest.TestCase):
	def test_loaded_runtime_binding_matches_current_source(self) -> None:
		digest = gf_maintenance.validate_gut_shard_runtime_source_binding(
			ROOT,
			gf_maintenance.GUT_SHARD_LOADED_RUNTIME_SOURCE_BINDING,
			deadline=time.perf_counter() + 10.0,
		)
		self.assertEqual(
			digest,
			gf_maintenance.GUT_SHARD_LOADED_RUNTIME_SOURCE_DIGEST,
		)
		self.assertEqual(
			tuple(path for path, _digest in gf_maintenance.GUT_SHARD_LOADED_RUNTIME_SOURCE_BINDING),
			tuple(path for path, _module in gf_maintenance.GUT_SHARD_RUNTIME_SOURCE_MODULES),
		)
		self.assertIn(
			("tools/gf_executable_resolution.py", "gf_executable_resolution"),
			gf_maintenance.GUT_SHARD_RUNTIME_SOURCE_MODULES,
			"Executable resolution participates in GUT command identity and must be "
			"bound into the runtime source closure.",
		)
		self.assertIn(
			("tools/gf_validation_catalog.py", "gf_validation_catalog"),
			gf_maintenance.GUT_SHARD_RUNTIME_SOURCE_MODULES,
			"Validation Catalog participates in GUT shard command planning and must be "
			"bound into the runtime source closure.",
		)
		self.assertIn(
			("tools/gf_validation_contracts.py", "gf_validation_contracts"),
			gf_maintenance.GUT_SHARD_RUNTIME_SOURCE_MODULES,
			"Catalog-owned input specs participate in GUT shard command planning and "
			"their contract module must be bound into the runtime source closure.",
		)

	def test_top_report_and_worker_request_bind_runtime_digest(self) -> None:
		report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=False)
		self.assertEqual(
			report["runtime_source_digest"],
			gf_maintenance.GUT_SHARD_LOADED_RUNTIME_SOURCE_DIGEST,
		)
		with tempfile.TemporaryDirectory() as temporary_directory:
			request = gf_maintenance.make_gut_shard_worker_request(
				{
					"name": "gut-lane-a",
					"role": "lane",
					"scripts": ["res://tests/gf_core/a/test_a.gd"],
				},
				Path(temporary_directory),
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				runtime_source_digest="4" * 64,
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
			)
		self.assertEqual(request["runtime_source_digest"], "4" * 64)
		self.assertEqual(
			set(request),
			gf_maintenance.gf_gut_shard_worker.REQUEST_KEYS,
		)

	def test_imported_a_rejects_captured_b_before_probe_or_worker(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			for relative_path, _module_name in gf_maintenance.GUT_SHARD_RUNTIME_SOURCE_MODULES:
				source_path = ROOT / relative_path
				target_path = fixture_root / relative_path
				target_path.parent.mkdir(parents=True, exist_ok=True)
				target_path.write_bytes(source_path.read_bytes())
			mutated_path = fixture_root / "tools/gf_gut_sharding.py"
			original = mutated_path.read_bytes()
			mutated = original.replace(b"SCHEMA_VERSION = 1", b"SCHEMA_VERSION = 2", 1)
			self.assertNotEqual(mutated, original)
			mutated_path.write_bytes(mutated)
			captured = mock.Mock(workspace_fingerprint="1" * 64)
			with mock.patch.object(
				gf_maintenance,
				"ROOT",
				fixture_root,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"capture_workspace",
				return_value=captured,
			) as capture, mock.patch.object(
				gf_maintenance,
				"run_parallel_godot_isolation_probe",
			) as isolation_probe, mock.patch.object(
				gf_maintenance,
				"execute_gut_shard_candidate_reports",
			) as candidates:
				report = gf_maintenance.gut_shard_run()
		capture.assert_called_once()
		isolation_probe.assert_not_called()
		candidates.assert_not_called()
		self.assertFalse(report["ok"])
		self.assertEqual(report["executed_shard_count"], 0)
		self.assertIn(
			"gut_shard_runtime_source_mismatch",
			{issue["kind"] for issue in report["issues"]},
		)


class GutShardRunIntegrationTests(unittest.TestCase):
	TOP_LEVEL_FIELDS = {
		"schema_version",
		"ok",
		"mode",
		"authoritative",
		"merge_evidence",
		"workspace_fingerprint",
		"runtime_source_digest",
		"manifest_path",
		"manifest_digest",
		"inventory_digest",
		"inventory_count",
		"jobs",
		"import_timeout_seconds",
		"candidate_gut_timeout_seconds",
		"control_gut_timeout_seconds",
		"total_timeout_seconds",
		"qualify_requested",
		"candidate_eligible",
		"qualified",
		"qualification_status",
		"shard_count",
		"executed_shard_count",
		"completed_shard_count",
		"successful_shard_count",
		"failed_shard_count",
		"unreported_shard_count",
		"not_scheduled_shard_count",
		"duration_seconds",
		"isolation_probe",
		"shards",
		"aggregate",
		"control",
		"equivalence",
		"observation_policy",
		"issues",
	}
	INVENTORY = (
		gf_maintenance.gf_gut_sharding.LIFECYCLE_CONTRACT_SCRIPT,
		*tuple(
			f"res://tests/gf_core/synthetic/test_{index}.gd"
			for index in range(8)
		),
	)
	INVENTORY = tuple(sorted(INVENTORY))
	MANIFEST = gf_maintenance.gf_gut_sharding._bootstrap_manifest_for_inventory(  # noqa: SLF001
		INVENTORY
	)

	@staticmethod
	def _junit(scripts: list[str], *, duration: float = 0.1) -> dict[str, object]:
		script_reports = []
		for script_path in scripts:
			script_reports.append({
				"script": script_path,
				"duration_seconds": duration,
				"testcase_duration_seconds": duration,
				"testcase_duration_sum_seconds": duration,
				"testcase_duration_serialization_tolerance_seconds": 0.000002,
				"duration_scope": (
					gf_maintenance.gf_gut_sharding.JUNIT_LIFECYCLE_DURATION_SCOPE
				),
				"test_count": 1,
				"status_counts": {
					"passed": 1,
					"failed": 0,
					"pending": 0,
					"no_asserts": 0,
					"skipped": 0,
				},
				"failure_assertion_count": 0,
				"pending_assertion_count": 0,
				"failure_test_count_lower_bound": 0,
				"failure_test_count_upper_bound": 0,
				"assertion_count": 1,
				"lifecycle_assertion_count": 0,
				"assertion_counts_complete": True,
				"assertion_count_unknown_reason": None,
				"tests": [{
					"name": "test_fixture",
					"duration_seconds": duration,
					"status": "passed",
					"assertion_count": 1,
				}],
			})
		total_duration = gf_maintenance.gf_gut_sharding._finite_sum(  # noqa: SLF001
			(
				float(script["duration_seconds"])
				for script in script_reports
			),
			"fixture_duration_invalid",
			"Fixture duration must remain finite.",
		)
		return {
			"schema_version": 1,
			"ok": True,
			"source_format": "gut_junit_xml",
			"junit_sha256": "a" * 64,
			"provenance_sha256": "b" * 64,
			"input_complete": True,
			"completeness_basis": (
				gf_maintenance.gf_gut_sharding.JUNIT_COMPLETENESS_CONTROLLED_RUN
			),
			"script_count": len(scripts),
			"covered_script_count": len(scripts),
			"test_count": len(scripts),
			"duration_seconds": total_duration,
			"testcase_duration_seconds": total_duration,
			"duration_scope": (
				gf_maintenance.gf_gut_sharding.JUNIT_LIFECYCLE_DURATION_SCOPE
			),
			"status_counts": {
				"passed": len(scripts),
				"failed": 0,
				"pending": 0,
				"no_asserts": 0,
				"skipped": 0,
			},
			"failure_test_count": 0,
			"failure_assertion_count": 0,
			"pending_assertion_count": 0,
			"assertion_count": len(scripts),
			"lifecycle_assertion_count": 0,
			"assertion_counts_complete": True,
			"assertion_count_unknown_reason": None,
			"scripts": script_reports,
		}

	@staticmethod
	def _successful_worker_report(
		request: dict[str, object],
		junit: dict[str, object],
	) -> dict[str, object]:
		report = gf_maintenance.gf_gut_shard_worker._empty_report(request)
		report.update({
			"ok": True,
			"import_run_count": 1,
			"gut_run_count": 1,
			"import_result": {
				"ok": True,
				"exit_code": 0,
				"timed_out": False,
				"cancelled": False,
				"duration_seconds": 0.0,
			},
			"gut_result": {
				"ok": True,
				"exit_code": 0,
				"timed_out": False,
				"cancelled": False,
				"duration_seconds": 0.0,
			},
			"junit": junit,
			"junit_digest": gf_maintenance.gf_gut_shard_worker.canonical_digest(junit),
			"lifecycle_ok": True,
			"process_boundary_quiescent": True,
			"worker_cleanup_complete": True,
			"workspace_cleanup_permitted": True,
			"continuation_safe": True,
			"duration_seconds": 0.0,
		})
		return report

	@staticmethod
	def _failed_worker_report(
		request: dict[str, object],
		*,
		kind: str = "worker_import_failed",
	) -> dict[str, object]:
		report = gf_maintenance.gf_gut_shard_worker._empty_report(request)
		report["workspace_cleanup_permitted"] = True
		if kind == "worker_import_failed":
			report["import_run_count"] = 1
			report["import_result"] = {
				"ok": False,
				"exit_code": 1,
				"timed_out": False,
				"cancelled": False,
				"duration_seconds": 0.01,
			}
			report["duration_seconds"] = 0.01
			report["continuation_safe"] = True
		report["issues"].append({
			"kind": kind,
			"message": "fixture",
			"phase": "import" if kind == "worker_import_failed" else "worker",
		})
		return report

	def _candidate_worker_reports(
		self,
		workspace: Path,
		*,
		gut_timeout: int | None = None,
	) -> list[dict[str, object]]:
		manifest_digest = gf_maintenance.gf_gut_sharding.canonical_digest(self.MANIFEST)
		inventory_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
			list(self.INVENTORY)
		)
		import_timeout = gf_maintenance.resolve_check_timeout_seconds(
			"godot_import", None
		)
		resolved_gut_timeout = gf_maintenance.resolve_gut_shard_run_gut_timeout_seconds(
			gut_timeout
		)
		reports: list[dict[str, object]] = []
		for index, shard in enumerate(self.MANIFEST["shards"]):
			candidate_workspace = workspace / f"candidate-{index}"
			candidate_workspace.mkdir(exist_ok=True)
			reports.append(self._successful_worker_report(
				gf_maintenance.make_gut_shard_worker_request(
					shard,
					candidate_workspace,
					workspace_fingerprint_value="1" * 64,
					manifest_digest=manifest_digest,
					inventory_digest=inventory_digest,
					remaining_seconds=float(
						gf_maintenance.gut_shard_worker_total_timeout_seconds(
							import_timeout,
							resolved_gut_timeout,
						)
					),
					import_timeout_seconds=import_timeout,
					gut_timeout_seconds=resolved_gut_timeout,
				),
				self._junit(shard["scripts"]),
			))
		return reports

	def _control_worker_report(self, workspace: Path) -> dict[str, object]:
		control_workspace = workspace / "control"
		control_workspace.mkdir(exist_ok=True)
		import_timeout = gf_maintenance.resolve_check_timeout_seconds(
			"godot_import", None
		)
		gut_timeout = gf_maintenance.resolve_gut_shard_observation_timeout_seconds(None)
		request = gf_maintenance.make_gut_shard_worker_request(
			{
				"name": gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME,
				"role": gf_maintenance.gf_gut_shard_worker.CONTROL_ROLE,
				"scripts": list(self.INVENTORY),
			},
			control_workspace,
			workspace_fingerprint_value="1" * 64,
			manifest_digest=gf_maintenance.gf_gut_sharding.canonical_digest(
				self.MANIFEST
			),
			inventory_digest=gf_maintenance.gf_gut_sharding.canonical_digest(
				list(self.INVENTORY)
			),
			remaining_seconds=float(
				gf_maintenance.gut_shard_worker_total_timeout_seconds(
					import_timeout,
					gut_timeout,
				)
			),
			import_timeout_seconds=import_timeout,
			gut_timeout_seconds=gut_timeout,
			mode=gf_maintenance.gf_gut_shard_worker.CONTROL_MODE,
		)
		return self._successful_worker_report(
			request,
			self._junit(list(self.INVENTORY)),
		)

	def test_report_envelope_is_non_authoritative_and_has_zero_reuse(self) -> None:
		self.assertEqual(
			gf_maintenance.WINDOWS_PARALLEL_VALIDATION_ROOT_MAX_CHARACTERS,
			19,
		)
		report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=False)
		self.assertEqual(set(report), self.TOP_LEVEL_FIELDS)
		self.assertEqual(report["mode"], "sharded_observation")
		self.assertFalse(report["authoritative"])
		self.assertFalse(report["merge_evidence"])
		self.assertFalse(report["qualified"])
		self.assertEqual(report["qualification_status"], "not_requested")
		self.assertEqual(report["isolation_probe"]["probe_count"], 0)
		self.assertEqual(
			report["observation_policy"],
			{
				"affects_check_graph": False,
				"affects_suite_membership": False,
				"authoritative_result_replaced": False,
				"skip_count": 0,
				"cache_read_count": 0,
				"cache_write_count": 0,
				"reuse_count": 0,
			},
		)

	def test_timeout_override_only_raises_candidate_floor_and_parent_is_bounded(self) -> None:
		self.assertEqual(gf_maintenance.resolve_gut_shard_run_gut_timeout_seconds(None), 600)
		self.assertEqual(gf_maintenance.resolve_gut_shard_run_gut_timeout_seconds(30), 600)
		self.assertEqual(gf_maintenance.resolve_gut_shard_run_gut_timeout_seconds(900), 900)
		self.assertEqual(
			gf_maintenance.make_gut_shard_run_report(
				jobs=2,
				qualify=True,
			)["control_gut_timeout_seconds"],
			1200,
		)
		self.assertEqual(
			gf_maintenance.GUT_SHARD_RUN_WORKER_PREFLIGHT_ALLOWANCE_SECONDS,
			math.ceil(
				2 * gf_maintenance.gf_gut_sharding.INVENTORY_DEADLINE_SECONDS
			)
			+ gf_maintenance.GUT_SHARD_RUN_WORKER_NON_INVENTORY_PREFLIGHT_ALLOWANCE_SECONDS,
		)
		self.assertEqual(
			gf_maintenance.gut_shard_worker_total_timeout_seconds(600, 600),
			1320,
		)
		self.assertEqual(
			gf_maintenance.gut_shard_worker_total_timeout_seconds(600, 1200),
			1920,
		)
		self.assertEqual(
			gf_maintenance.gut_shard_run_total_timeout_seconds(
				9,
				2,
				gut_timeout_seconds=600,
				qualify=False,
			),
			6900,
		)
		self.assertEqual(
			gf_maintenance.gut_shard_run_total_timeout_seconds(
				9,
				2,
				gut_timeout_seconds=600,
				qualify=True,
			),
			8820,
		)
		overridden_report = gf_maintenance.make_gut_shard_run_report(
			jobs=2,
			qualify=True,
			gut_timeout_seconds=1500,
		)
		self.assertEqual(overridden_report["candidate_gut_timeout_seconds"], 1500)
		self.assertEqual(overridden_report["control_gut_timeout_seconds"], 1200)
		self.assertEqual(overridden_report["total_timeout_seconds"], 13320)
		self.assertEqual(
			overridden_report["total_timeout_seconds"]
			- gf_maintenance.gut_shard_run_total_timeout_seconds(
				9,
				2,
				gut_timeout_seconds=1500,
				qualify=False,
			),
			gf_maintenance.gut_shard_worker_total_timeout_seconds(600, 1200),
		)
		with self.assertRaisesRegex(ValueError, "phase timeout ceiling"):
			gf_maintenance.resolve_gut_shard_run_gut_timeout_seconds(
				gf_maintenance.gf_gut_shard_worker.MAX_PHASE_TIMEOUT_SECONDS + 1
			)
		for invalid in (-1, 0):
			with self.subTest(invalid=invalid), self.assertRaisesRegex(
				ValueError,
				"positive seconds",
			):
				gf_maintenance.resolve_gut_shard_run_gut_timeout_seconds(invalid)
			with self.assertRaisesRegex(ValueError, "positive seconds"):
				gf_maintenance.gut_shard_run(timeout_seconds=invalid)
		for invalid in (True, 1.5):
			with self.subTest(invalid=invalid), self.assertRaisesRegex(
				TypeError,
				"must be integers",
			):
				gf_maintenance.resolve_gut_shard_run_gut_timeout_seconds(invalid)
			with self.assertRaisesRegex(TypeError, "must be integers"):
				gf_maintenance.gut_shard_run(timeout_seconds=invalid)

	def test_cli_defaults_to_two_workers_and_forwards_qualification(self) -> None:
		report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=True)
		with mock.patch.object(
			sys,
			"argv",
			["gf_maintenance.py", "gut-shard-run", "--qualify", "--json"],
		), mock.patch.object(
			gf_maintenance,
			"gut_shard_run",
			return_value=report,
		) as runner, mock.patch.object(
			gf_maintenance.maintenance_rendering,
			"print_output",
		) as print_output:
			exit_code = gf_maintenance.main()
		self.assertEqual(exit_code, 1)
		runner.assert_called_once_with(jobs=2, timeout_seconds=None, qualify=True)
		print_output.assert_called_once()

	def test_cli_rejects_out_of_range_shard_timeouts_before_execution(self) -> None:
		for invalid in ("0", "7201", "not-an-integer"):
			stdout = io.StringIO()
			stderr = io.StringIO()
			with self.subTest(invalid=invalid), mock.patch.object(
				sys,
				"argv",
				["gf_maintenance.py", "gut-shard-run", "--timeout", invalid, "--json"],
			), mock.patch.object(
				gf_maintenance,
				"gut_shard_run",
			) as runner, contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(
				stderr,
			), self.assertRaises(
				SystemExit,
			) as raised:
				gf_maintenance.main()
			self.assertEqual(raised.exception.code, 2)
			runner.assert_not_called()
			self.assertEqual(stdout.getvalue(), "")
			self.assertIn("between 1 and 7200 seconds", stderr.getvalue())
			self.assertNotIn("Traceback", stderr.getvalue())

	def test_cli_shard_timeout_parser_accepts_worker_phase_bounds(self) -> None:
		for valid in ("1", "600", "7200"):
			with self.subTest(valid=valid):
				self.assertEqual(
					gf_maintenance.parse_gut_shard_run_timeout_seconds(valid),
					int(valid),
				)
		for invalid in ("0", "7201", "1.5"):
			with self.subTest(invalid=invalid), self.assertRaises(
				gf_maintenance.argparse.ArgumentTypeError,
			):
				gf_maintenance.parse_gut_shard_run_timeout_seconds(invalid)

	def test_top_level_run_captures_once_and_accepts_all_candidate_reports(self) -> None:
		captured = mock.Mock(
			workspace_fingerprint="1" * 64,
		)
		with tempfile.TemporaryDirectory() as temporary_directory:
			worker_reports = self._candidate_worker_reports(Path(temporary_directory))
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				worker_reports,
			)
			with mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"capture_workspace",
				return_value=captured,
			) as capture, mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"assert_source_matches_snapshot",
			), mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"discover_gut_test_scripts",
				return_value=self.INVENTORY,
			) as discover_inventory, mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"load_and_validate_manifest",
				return_value=self.MANIFEST,
			), mock.patch.object(
				gf_maintenance,
				"validate_gut_shard_runtime_source_binding",
				wraps=gf_maintenance.validate_gut_shard_runtime_source_binding,
			) as runtime_binding, mock.patch.object(
				gf_maintenance,
				"managed_validation_directory",
				return_value=contextlib.nullcontext(Path(temporary_directory)),
			), mock.patch.object(
				gf_maintenance,
				"run_parallel_godot_isolation_probe",
				return_value={
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path",
						"user_dir",
						"data_dir",
						"config_dir",
						"cache_dir",
					],
					"private_roots": {"a": "random-a", "b": "random-b"},
				},
			) as isolation_probe, mock.patch.object(
				gf_maintenance,
				"execute_gut_shard_candidate_reports",
				return_value=(worker_reports, 9, []),
			) as candidates, mock.patch.object(
				gf_maintenance,
				"aggregate_gut_shard_candidate_reports",
				return_value=aggregate,
			):
				call_order = mock.Mock()
				call_order.attach_mock(isolation_probe, "isolation_probe")
				call_order.attach_mock(candidates, "candidates")
				report = gf_maintenance.gut_shard_run()
		self.assertTrue(report["ok"], report["issues"])
		self.assertTrue(report["candidate_eligible"])
		self.assertFalse(report["authoritative"])
		self.assertFalse(report["merge_evidence"])
		self.assertEqual(report["executed_shard_count"], 9)
		self.assertEqual(report["completed_shard_count"], 9)
		self.assertEqual(report["successful_shard_count"], 9)
		self.assertEqual(report["failed_shard_count"], 0)
		self.assertEqual(report["unreported_shard_count"], 0)
		self.assertEqual(report["not_scheduled_shard_count"], 0)
		self.assertEqual(
			report["isolation_probe"],
			{
				"ok": True,
				"probe_count": 2,
				"fields": [
					"marker_path",
					"user_dir",
					"data_dir",
					"config_dir",
					"cache_dir",
				],
			},
		)
		capture.assert_called_once()
		discover_inventory.assert_called_once_with(
			gf_maintenance.ROOT,
			deadline=capture.call_args.kwargs["deadline"],
		)
		self.assertEqual(runtime_binding.call_count, 2)
		isolation_probe.assert_called_once()
		self.assertEqual(
			[call[0] for call in call_order.mock_calls[:2]],
			["isolation_probe", "candidates"],
		)
		self.assertEqual(candidates.call_args.kwargs["jobs"], 2)
		self.assertEqual(
			candidates.call_args.kwargs["runtime_source_digest"],
			report["runtime_source_digest"],
		)
		self.assertEqual(candidates.call_args.kwargs["gut_timeout_seconds"], 600)
		self.assertIsInstance(
			candidates.call_args.kwargs["cancellation_event"],
			threading.Event,
		)
		self.assertFalse(candidates.call_args.kwargs["cancellation_event"].is_set())

	def test_isolation_probe_failure_starts_zero_candidate_workers(self) -> None:
		captured = mock.Mock(workspace_fingerprint="1" * 64)
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"capture_workspace",
			return_value=captured,
		), mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"assert_source_matches_snapshot",
		), mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"discover_gut_test_scripts",
			return_value=self.INVENTORY,
		), mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"load_and_validate_manifest",
			return_value=self.MANIFEST,
		), mock.patch.object(
			gf_maintenance,
			"managed_validation_directory",
			return_value=contextlib.nullcontext(Path(temporary_directory)),
		), mock.patch.object(
			gf_maintenance,
			"run_parallel_godot_isolation_probe",
			side_effect=gf_maintenance.WorkspaceSnapshotError("probe failed closed"),
		), mock.patch.object(
			gf_maintenance,
			"execute_gut_shard_candidate_reports",
		) as candidates:
			report = gf_maintenance.gut_shard_run()
		self.assertFalse(report["ok"])
		self.assertEqual(report["executed_shard_count"], 0)
		self.assertEqual(
			report["isolation_probe"],
			{
				"ok": False,
				"probe_count": 0,
				"fields": [
					"marker_path",
					"user_dir",
					"data_dir",
					"config_dir",
					"cache_dir",
				],
			},
		)
		candidates.assert_not_called()

	def test_isolation_probe_unproven_boundary_forbids_validation_root_cleanup(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parallel_root = Path(temporary_directory)
			resolved_godot = str((parallel_root / "fixture-godot").resolve())
			cleanup_state = {"permitted": True}
			results = [
				gf_maintenance.ParallelShardResult(
					name=label,
					command=(resolved_godot,),
					workspace=parallel_root / "p" / label,
					exit_code=0,
					process_exit_code=0,
					stdout="",
					stderr="",
					timed_out=False,
					cancelled=False,
					duration_seconds=0.1,
					pid=index + 1,
					started=True,
					process_boundary_quiescent=(label == "a"),
				)
				for index, label in enumerate(("a", "b"))
			]
			with mock.patch.object(
				gf_maintenance,
				"resolve_godot_executable",
				return_value=resolved_godot,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"run_parallel_shards",
				return_value=results,
			):
				with self.assertRaisesRegex(
					gf_maintenance.WorkspaceSnapshotError,
					"process-boundary cleanup",
				):
					gf_maintenance.run_parallel_godot_isolation_probe(
						parallel_root,
						deadline=time.perf_counter() + 10.0,
						output_callback=None,
						cleanup_state=cleanup_state,
					)
			self.assertFalse(cleanup_state["permitted"])

	def test_isolation_probe_no_child_start_failure_permits_root_cleanup(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			cleanup_state = {"permitted": True}
			missing_executable = Path(temporary_directory) / "missing-godot"
			with mock.patch.object(
				gf_maintenance,
				"resolve_godot_executable",
				return_value=str(missing_executable),
			):
				with self.assertRaisesRegex(
					gf_maintenance.WorkspaceSnapshotError,
					"failed",
				):
					gf_maintenance.run_parallel_godot_isolation_probe(
						Path(temporary_directory),
						deadline=time.perf_counter() + 10.0,
						output_callback=None,
						cleanup_state=cleanup_state,
					)
			self.assertTrue(cleanup_state["permitted"])

	def test_isolation_probe_base_exception_keeps_cleanup_fail_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			cleanup_state = {"permitted": True}
			resolved_godot = str(
				(Path(temporary_directory) / "fixture-godot").resolve()
			)
			with mock.patch.object(
				gf_maintenance,
				"resolve_godot_executable",
				return_value=resolved_godot,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"run_parallel_shards",
				side_effect=KeyboardInterrupt("fixture probe interruption"),
			):
				with self.assertRaisesRegex(KeyboardInterrupt, "probe interruption"):
					gf_maintenance.run_parallel_godot_isolation_probe(
						Path(temporary_directory),
						deadline=time.perf_counter() + 10.0,
						output_callback=None,
						cleanup_state=cleanup_state,
					)
			self.assertFalse(cleanup_state["permitted"])

	def test_qualification_runs_one_original_timeout_control_after_candidates(self) -> None:
		captured = mock.Mock(workspace_fingerprint="1" * 64)
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			worker_reports = self._candidate_worker_reports(
				workspace,
				gut_timeout=900,
			)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST, self.INVENTORY, worker_reports,
			)
			control = self._control_worker_report(workspace)
			equivalence = gf_maintenance.compare_gut_shard_qualification(
				aggregate,
				control,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				candidate_reports=worker_reports,
			)
			with mock.patch.object(
				gf_maintenance.gf_parallel_validation,
			"capture_workspace",
			return_value=captured,
		), mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"assert_source_matches_snapshot",
		), mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"discover_gut_test_scripts",
			return_value=self.INVENTORY,
		), mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"load_and_validate_manifest",
			return_value=self.MANIFEST,
		), mock.patch.object(
			gf_maintenance,
			"managed_validation_directory",
			return_value=contextlib.nullcontext(Path(temporary_directory)),
		), mock.patch.object(
			gf_maintenance,
			"run_parallel_godot_isolation_probe",
			return_value={
				"ok": True,
				"probe_count": 2,
				"fields": [
					"marker_path",
					"user_dir",
					"data_dir",
					"config_dir",
					"cache_dir",
				],
			},
		), mock.patch.object(
			gf_maintenance,
			"execute_gut_shard_candidate_reports",
			return_value=(worker_reports, 9, []),
		), mock.patch.object(
			gf_maintenance,
			"aggregate_gut_shard_candidate_reports",
			return_value=aggregate,
		), mock.patch.object(
			gf_maintenance,
			"execute_gut_shard_control_report",
			return_value=(control, 1, []),
		) as control_runner, mock.patch.object(
			gf_maintenance,
			"compare_gut_shard_qualification",
			return_value=equivalence,
		) as compare:
				report = gf_maintenance.gut_shard_run(
				timeout_seconds=900,
				qualify=True,
			)
		self.assertTrue(report["ok"], report["issues"])
		self.assertTrue(report["qualified"])
		self.assertEqual(report["qualification_status"], "qualified")
		control_runner.assert_called_once()
		self.assertEqual(control_runner.call_args.kwargs["gut_timeout_seconds"], 1200)
		self.assertEqual(compare.call_count, 2)
		for call in compare.call_args_list:
			self.assertEqual(call.args, (report["aggregate"], control))
			self.assertEqual(call.kwargs, {
				"manifest": self.MANIFEST,
				"inventory": self.INVENTORY,
				"candidate_reports": worker_reports,
			})

	def test_comparison_exception_returns_closed_infrastructure_report(self) -> None:
		captured = mock.Mock(workspace_fingerprint="1" * 64)
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			worker_reports = self._candidate_worker_reports(workspace)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				worker_reports,
			)
			control = self._control_worker_report(workspace)
			with mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"capture_workspace",
				return_value=captured,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"assert_source_matches_snapshot",
			), mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"discover_gut_test_scripts",
				return_value=self.INVENTORY,
			), mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"load_and_validate_manifest",
				return_value=self.MANIFEST,
			), mock.patch.object(
				gf_maintenance,
				"managed_validation_directory",
				return_value=contextlib.nullcontext(workspace),
			), mock.patch.object(
				gf_maintenance,
				"run_parallel_godot_isolation_probe",
				return_value={
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
			), mock.patch.object(
				gf_maintenance,
				"execute_gut_shard_candidate_reports",
				return_value=(worker_reports, len(worker_reports), []),
			), mock.patch.object(
				gf_maintenance,
				"aggregate_gut_shard_candidate_reports",
				return_value=aggregate,
			), mock.patch.object(
				gf_maintenance,
				"execute_gut_shard_control_report",
				return_value=(control, 1, []),
			), mock.patch.object(
				gf_maintenance,
				"compare_gut_shard_qualification",
				side_effect=RuntimeError("synthetic comparison failure"),
			) as compare:
				report = gf_maintenance.gut_shard_run(qualify=True)
		self.assertFalse(report["ok"])
		self.assertFalse(report["candidate_eligible"])
		self.assertFalse(report["qualified"])
		self.assertEqual(report["qualification_status"], "infrastructure_failed")
		self.assertIsNone(report["equivalence"])
		self.assertEqual(compare.call_count, 1)
		self.assertIn(
			"gut_shard_comparison_failed",
			{issue["kind"] for issue in report["issues"]},
		)

	def test_final_source_drift_revokes_candidate_and_qualification(self) -> None:
		captured = mock.Mock(workspace_fingerprint="1" * 64)
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)

			@contextlib.contextmanager
			def retained_validation_root(**kwargs: object) -> object:
				try:
					yield workspace
				finally:
					cleanup_permitted = kwargs["cleanup_permitted"]
					if not cleanup_permitted():
						kwargs["cleanup_errors"].append(
							"Retained validation root after final source drift."
						)

			worker_reports = self._candidate_worker_reports(workspace)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST, self.INVENTORY, worker_reports,
			)
			control = self._control_worker_report(workspace)
			equivalence = gf_maintenance.compare_gut_shard_qualification(
				aggregate,
				control,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				candidate_reports=worker_reports,
			)
			with mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"capture_workspace",
				return_value=captured,
		), mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"assert_source_matches_snapshot",
			side_effect=[
				None,
				gf_maintenance.gf_parallel_validation.WorkspaceDriftError(
					"final source drift"
				),
			],
		) as source_check, mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"discover_gut_test_scripts",
			return_value=self.INVENTORY,
		), mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"load_and_validate_manifest",
			return_value=self.MANIFEST,
		), mock.patch.object(
			gf_maintenance,
			"managed_validation_directory",
			side_effect=retained_validation_root,
		), mock.patch.object(
			gf_maintenance,
			"run_parallel_godot_isolation_probe",
			return_value={
				"ok": True,
				"probe_count": 2,
				"fields": [
					"marker_path",
					"user_dir",
					"data_dir",
					"config_dir",
					"cache_dir",
				],
			},
		), mock.patch.object(
			gf_maintenance,
			"execute_gut_shard_candidate_reports",
			return_value=(worker_reports, 9, []),
		), mock.patch.object(
			gf_maintenance,
			"aggregate_gut_shard_candidate_reports",
			return_value=aggregate,
		), mock.patch.object(
			gf_maintenance,
			"execute_gut_shard_control_report",
			return_value=(control, 1, []),
		), mock.patch.object(
			gf_maintenance,
			"compare_gut_shard_qualification",
			return_value=equivalence,
		):
				report = gf_maintenance.gut_shard_run(qualify=True)
		self.assertEqual(source_check.call_count, 2)
		self.assertFalse(report["ok"])
		self.assertFalse(report["candidate_eligible"])
		self.assertFalse(report["qualified"])
		self.assertEqual(report["qualification_status"], "cleanup_failed")
		self.assertIn("final source drift", "\n".join(
			issue["message"] for issue in report["issues"]
		))

	def test_command_is_outside_checks_suites_dependencies_and_workflows(self) -> None:
		self.assertNotIn("gut_shard_run", gf_maintenance.CHECK_DEFINITIONS)
		self.assertTrue(all(
			"gut_shard_run" not in checks
			for checks in gf_maintenance.CHECK_SUITES.values()
		))
		self.assertTrue(all(
			"gut_shard_run" not in dependencies
			for dependencies in gf_maintenance.CHECK_DEPENDENCIES.values()
		))
		for relative_path in (
			".github/workflows/ci.yml",
			".github/workflows/ci-manual.yml",
			".github/workflows/release.yml",
		):
			self.assertNotIn("gut-shard-run", (ROOT / relative_path).read_text(encoding="utf-8"))

	def test_worker_request_binds_exact_workspace_selection_and_remaining_duration(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			request = gf_maintenance.make_gut_shard_worker_request(
				{
					"name": "gut-lane-a",
					"role": "lane",
					"scripts": ["res://tests/gf_core/a/test_a.gd"],
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				remaining_seconds=123.5,
				import_timeout_seconds=600,
				gut_timeout_seconds=900,
			)
		self.assertEqual(set(request), gf_maintenance.gf_gut_shard_worker.REQUEST_KEYS)
		self.assertEqual(request["workspace_path"], str(workspace.resolve()))
		self.assertEqual(request["mode"], gf_maintenance.gf_gut_shard_worker.CANDIDATE_MODE)
		self.assertEqual(request["remaining_seconds"], 123.5)
		self.assertNotIn("deadline", request)

	def test_direct_worker_failed_report_is_accepted_only_when_request_matches(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory) / "workspace"
			workspace.mkdir()
			request = gf_maintenance.make_gut_shard_worker_request(
				{
					"name": "gut-lane-a",
					"role": "lane",
					"scripts": ["res://tests/gf_core/a/test_a.gd"],
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
			)
			report = gf_maintenance.gf_gut_shard_worker._empty_report(request)
			report["issues"].append({
				"kind": "fixture_failure",
				"message": "fixture",
				"phase": "gut",
			})
			with mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				return_value={"fingerprint": "1" * 64},
			):
				loaded = gf_maintenance.validate_direct_gut_shard_worker_report(
					report,
					request,
					workspace,
					git_process=_SHARED_PROCESS_AUTHORITY.git,
					expected_workspace_fingerprint="1" * 64,
					deadline=time.perf_counter() + 10.0,
				)
				self.assertEqual(loaded, report)
				with self.assertRaisesRegex(ValueError, "parent request"):
					gf_maintenance.validate_direct_gut_shard_worker_report(
						report,
						{**request, "nonce": "fe" * 32},
						workspace,
						git_process=_SHARED_PROCESS_AUTHORITY.git,
						expected_workspace_fingerprint="1" * 64,
						deadline=time.perf_counter() + 10.0,
					)

	def test_direct_worker_wave_is_parallel_ordered_and_never_nests_parallel_shards(self) -> None:
		temporary_owner = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_owner.cleanup)
		with contextlib.nullcontext(temporary_owner.name) as temporary_directory:
			root = Path(temporary_directory)
			workspaces = {}
			requests = []
			for index, name in enumerate(("gut-lane-a", "gut-lane-b")):
				workspace = root / f"s{index}"
				workspace.mkdir()
				workspaces[name] = workspace
				requests.append(gf_maintenance.make_gut_shard_worker_request(
					{
						"name": name,
						"role": "lane",
						"scripts": [f"res://tests/gf_core/{name}/test_fixture.gd"],
					},
					workspace,
					workspace_fingerprint_value="1" * 64,
					manifest_digest="2" * 64,
					inventory_digest="3" * 64,
					remaining_seconds=120.0,
					import_timeout_seconds=60,
					gut_timeout_seconds=60,
				))
		barrier = threading.Barrier(2)
		second_finished = threading.Event()
		active = 0
		maximum_active = 0
		active_lock = threading.Lock()

		def run_worker(
			request: dict[str, object],
			*,
			cancellation_event: threading.Event,
			process_authority: gf_process_authority.FrozenProcessAuthority,
		) -> dict[str, object]:
			self.assertIs(process_authority, _SHARED_PROCESS_AUTHORITY)
			nonlocal active, maximum_active
			with active_lock:
				active += 1
				maximum_active = max(maximum_active, active)
			try:
				barrier.wait(timeout=2.0)
				if request["shard_name"] == "gut-lane-b":
					second_finished.set()
				else:
					self.assertTrue(second_finished.wait(timeout=2.0))
				return self._successful_worker_report(
					request,
					self._junit(request["scripts"]),
				)
			finally:
				with active_lock:
					active -= 1

		with mock.patch.object(
			gf_maintenance.gf_gut_shard_worker,
			"run_worker",
			side_effect=run_worker,
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value={"fingerprint": "1" * 64},
		), mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"run_parallel_shards",
			side_effect=AssertionError("nested worker supervisor forbidden"),
		) as nested_runner:
			reports, executed, issues = gf_maintenance.execute_gut_shard_worker_wave(
				requests,
				workspaces,
				expected_workspace_fingerprint="1" * 64,
				process_authority=_SHARED_PROCESS_AUTHORITY,
				deadline=time.perf_counter() + 10.0,
				cancellation_event=threading.Event(),
			)
		self.assertEqual(issues, [])
		self.assertEqual(executed, 2)
		self.assertEqual(maximum_active, 2)
		self.assertEqual(
			[report["request"]["shard_name"] for report in reports],
			["gut-lane-a", "gut-lane-b"],
		)
		nested_runner.assert_not_called()

	def test_direct_worker_wave_deadline_sets_shared_cancellation(self) -> None:
		temporary_owner = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_owner.cleanup)
		with contextlib.nullcontext(temporary_owner.name) as temporary_directory:
			workspace = Path(temporary_directory)
			request = gf_maintenance.make_gut_shard_worker_request(
				{
					"name": "gut-lane-a",
					"role": "lane",
					"scripts": ["res://tests/gf_core/a/test_a.gd"],
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
			)
		cancellation_event = threading.Event()

		def wait_for_cancellation(
			worker_request: dict[str, object],
			*,
			cancellation_event: threading.Event,
			process_authority: gf_process_authority.FrozenProcessAuthority,
		) -> dict[str, object]:
			self.assertIs(process_authority, _SHARED_PROCESS_AUTHORITY)
			self.assertTrue(cancellation_event.wait(timeout=2.0))
			return self._failed_worker_report(worker_request, kind="worker_cancelled")

		with mock.patch.object(
			gf_maintenance.gf_gut_shard_worker,
			"run_worker",
			side_effect=wait_for_cancellation,
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=TimeoutError("synthetic expired fingerprint deadline"),
		):
			reports, executed, issues = gf_maintenance.execute_gut_shard_worker_wave(
				[request],
				{"gut-lane-a": workspace},
				expected_workspace_fingerprint="1" * 64,
				process_authority=_SHARED_PROCESS_AUTHORITY,
				deadline=time.perf_counter() + 0.02,
				cancellation_event=cancellation_event,
			)
		self.assertTrue(cancellation_event.is_set())
		self.assertEqual(executed, 1)
		self.assertEqual(reports, [])
		self.assertEqual(
			[issue["kind"] for issue in issues],
			["gut_shard_worker_wave_deadline_exhausted"],
		)

	def test_direct_worker_boundary_can_precede_peer_wave_deadline(self) -> None:
		temporary_owner = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_owner.cleanup)
		root = Path(temporary_owner.name)
		workspaces: dict[str, Path] = {}
		requests: list[dict[str, object]] = []
		for index, name in enumerate(("gut-lane-a", "gut-lane-b")):
			workspace = root / f"s{index}"
			workspace.mkdir()
			workspaces[name] = workspace
			requests.append(gf_maintenance.make_gut_shard_worker_request(
				{
					"name": name,
					"role": "lane",
					"scripts": [f"res://tests/gf_core/{name}/test_fixture.gd"],
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
			))
		barrier = threading.Barrier(2)
		cancellation_event = threading.Event()
		cleanup_state = {"permitted": True}
		worker_deadline = time.perf_counter() + 1.0

		def run_worker(
			request: dict[str, object],
			*,
			cancellation_event: threading.Event,
			process_authority: gf_process_authority.FrozenProcessAuthority,
		) -> dict[str, object]:
			self.assertIs(process_authority, _SHARED_PROCESS_AUTHORITY)
			barrier.wait(timeout=2.0)
			if request["shard_name"] == "gut-lane-b":
				self.assertTrue(cancellation_event.wait(timeout=2.0))
				while time.perf_counter() <= worker_deadline + 0.03:
					time.sleep(0.005)
			return self._successful_worker_report(
				request,
				self._junit(request["scripts"]),
			)

		def fingerprint(
			workspace: Path,
			*,
			git_process: gf_process_authority.FrozenGitProcess,
			deadline: float | None = None,
		) -> dict[str, str]:
			self.assertIs(git_process, _SHARED_PROCESS_AUTHORITY.git)
			if workspace == workspaces["gut-lane-a"]:
				boundary_error = (
					gf_maintenance.gf_maintenance_check_graph
					.WorkspaceFingerprintProcessBoundaryError
				)
				raise boundary_error("synthetic early fingerprint boundary debt")
			raise TimeoutError("synthetic peer report validation deadline")

		with mock.patch.object(
			gf_maintenance.gf_gut_shard_worker,
			"run_worker",
			side_effect=run_worker,
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=fingerprint,
		):
			reports, executed, issues = gf_maintenance.execute_gut_shard_worker_wave(
				requests,
				workspaces,
				expected_workspace_fingerprint="1" * 64,
				process_authority=_SHARED_PROCESS_AUTHORITY,
				deadline=worker_deadline,
				cancellation_event=cancellation_event,
				cleanup_state=cleanup_state,
			)
		self.assertEqual(reports, [])
		self.assertEqual(executed, 2)
		self.assertTrue(cancellation_event.is_set())
		self.assertFalse(cleanup_state["permitted"])
		self.assertEqual(
			[issue["kind"] for issue in issues],
			[
				"gut_shard_workspace_fingerprint_boundary_unproven",
				"gut_shard_worker_wave_deadline_exhausted",
			],
		)

	def test_direct_worker_boundary_can_precede_retained_peer_deadline_debt(self) -> None:
		temporary_owner = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_owner.cleanup)
		root = Path(temporary_owner.name)
		workspaces: dict[str, Path] = {}
		requests: list[dict[str, object]] = []
		for index, name in enumerate(("gut-lane-a", "gut-lane-b")):
			workspace = root / f"s{index}"
			workspace.mkdir()
			workspaces[name] = workspace
			requests.append(gf_maintenance.make_gut_shard_worker_request(
				{
					"name": name,
					"role": "lane",
					"scripts": [f"res://tests/gf_core/{name}/test_fixture.gd"],
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
			))
		barrier = threading.Barrier(2)
		cancellation_event = threading.Event()
		cleanup_state = {"permitted": True}
		worker_deadline = time.perf_counter() + 1.0

		def run_worker(
			request: dict[str, object],
			*,
			cancellation_event: threading.Event,
			process_authority: gf_process_authority.FrozenProcessAuthority,
		) -> dict[str, object]:
			self.assertIs(process_authority, _SHARED_PROCESS_AUTHORITY)
			barrier.wait(timeout=2.0)
			if request["shard_name"] == "gut-lane-a":
				return self._successful_worker_report(
					request,
					self._junit(request["scripts"]),
				)
			self.assertTrue(cancellation_event.wait(timeout=2.0))
			while time.perf_counter() <= worker_deadline + 0.03:
				time.sleep(0.005)
			retained = self._failed_worker_report(
				request,
				kind="worker_cancelled",
			)
			retained["workspace_cleanup_permitted"] = False
			retained["continuation_safe"] = False
			return retained

		def fingerprint(
			workspace: Path,
			*,
			git_process: gf_process_authority.FrozenGitProcess,
			deadline: float | None = None,
		) -> dict[str, str]:
			self.assertIs(git_process, _SHARED_PROCESS_AUTHORITY.git)
			self.assertEqual(workspace, workspaces["gut-lane-a"])
			boundary_error = (
				gf_maintenance.gf_maintenance_check_graph
				.WorkspaceFingerprintProcessBoundaryError
			)
			raise boundary_error("synthetic early fingerprint boundary debt")

		with mock.patch.object(
			gf_maintenance.gf_gut_shard_worker,
			"run_worker",
			side_effect=run_worker,
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=fingerprint,
		):
			reports, executed, issues = gf_maintenance.execute_gut_shard_worker_wave(
				requests,
				workspaces,
				expected_workspace_fingerprint="1" * 64,
				process_authority=_SHARED_PROCESS_AUTHORITY,
				deadline=worker_deadline,
				cancellation_event=cancellation_event,
				cleanup_state=cleanup_state,
			)
		self.assertEqual(executed, 2)
		self.assertEqual(
			[report["request"]["shard_name"] for report in reports],
			["gut-lane-b"],
		)
		self.assertFalse(cleanup_state["permitted"])
		self.assertEqual(
			[issue["kind"] for issue in issues],
			[
				"gut_shard_workspace_fingerprint_boundary_unproven",
				"gut_shard_worker_wave_deadline_exhausted",
				"gut_shard_worker_infrastructure_failed",
				"gut_shard_workspace_ownership_unproven",
			],
		)

	def test_direct_worker_exception_cancels_and_drains_its_peer(self) -> None:
		temporary_owner = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_owner.cleanup)
		with contextlib.nullcontext(temporary_owner.name) as temporary_directory:
			root = Path(temporary_directory)
			workspaces = {}
			requests = []
			for index, name in enumerate(("gut-lane-a", "gut-lane-b")):
				workspace = root / f"s{index}"
				workspace.mkdir()
				workspaces[name] = workspace
				requests.append(gf_maintenance.make_gut_shard_worker_request(
					{
						"name": name,
						"role": "lane",
						"scripts": [f"res://tests/gf_core/{name}/test_fixture.gd"],
					},
					workspace,
					workspace_fingerprint_value="1" * 64,
					manifest_digest="2" * 64,
					inventory_digest="3" * 64,
					remaining_seconds=120.0,
					import_timeout_seconds=60,
					gut_timeout_seconds=60,
				))
		barrier = threading.Barrier(2)
		peer_drained = threading.Event()
		cancellation_event = threading.Event()

		def run_worker(
			request: dict[str, object],
			*,
			cancellation_event: threading.Event,
			process_authority: gf_process_authority.FrozenProcessAuthority,
		) -> dict[str, object]:
			self.assertIs(process_authority, _SHARED_PROCESS_AUTHORITY)
			barrier.wait(timeout=2.0)
			if request["shard_name"] == "gut-lane-a":
				raise RuntimeError("fixture worker crash")
			self.assertTrue(cancellation_event.wait(timeout=2.0))
			peer_drained.set()
			return self._failed_worker_report(request, kind="worker_cancelled")

		with mock.patch.object(
			gf_maintenance.gf_gut_shard_worker,
			"run_worker",
			side_effect=run_worker,
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value={"fingerprint": "1" * 64},
		):
			reports, executed, issues = gf_maintenance.execute_gut_shard_worker_wave(
				requests,
				workspaces,
				expected_workspace_fingerprint="1" * 64,
				process_authority=_SHARED_PROCESS_AUTHORITY,
				deadline=time.perf_counter() + 10.0,
				cancellation_event=cancellation_event,
			)
		self.assertTrue(cancellation_event.is_set())
		self.assertTrue(peer_drained.is_set())
		self.assertEqual(executed, 2)
		self.assertEqual(len(reports), 1)
		self.assertIn("gut_shard_worker_exception", {issue["kind"] for issue in issues})

	def test_direct_worker_submit_failure_retains_exact_launched_progress(self) -> None:
		temporary_owner = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_owner.cleanup)
		root = Path(temporary_owner.name)
		workspaces = {}
		requests = []
		for index, name in enumerate(("gut-lane-a", "gut-lane-b")):
			workspace = root / f"s{index}"
			workspace.mkdir()
			workspaces[name] = workspace
			requests.append(gf_maintenance.make_gut_shard_worker_request(
				{
					"name": name,
					"role": "lane",
					"scripts": [f"res://tests/gf_core/{name}/test_fixture.gd"],
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
			))
		original_submit = concurrent.futures.ThreadPoolExecutor.submit
		submit_count = 0

		def fail_second_submit(
			executor: concurrent.futures.ThreadPoolExecutor,
			function: object,
			*args: object,
			**kwargs: object,
		) -> concurrent.futures.Future[object]:
			nonlocal submit_count
			submit_count += 1
			if submit_count == 2:
				raise RuntimeError("fixture submit failure")
			return original_submit(executor, function, *args, **kwargs)

		def run_worker(
			request: dict[str, object],
			*,
			cancellation_event: threading.Event,
			process_authority: gf_process_authority.FrozenProcessAuthority,
		) -> dict[str, object]:
			self.assertIs(process_authority, _SHARED_PROCESS_AUTHORITY)
			del cancellation_event
			return self._successful_worker_report(
				request,
				self._junit(request["scripts"]),
			)

		cancellation_event = threading.Event()
		cleanup_state = {"permitted": True}
		with mock.patch.object(
			concurrent.futures.ThreadPoolExecutor,
			"submit",
			new=fail_second_submit,
		), mock.patch.object(
			gf_maintenance.gf_gut_shard_worker,
			"run_worker",
			side_effect=run_worker,
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value={"fingerprint": "1" * 64},
		):
			reports, executed, issues = gf_maintenance.execute_gut_shard_worker_wave(
				requests,
				workspaces,
				expected_workspace_fingerprint="1" * 64,
				process_authority=_SHARED_PROCESS_AUTHORITY,
				deadline=time.perf_counter() + 10.0,
				cancellation_event=cancellation_event,
				cleanup_state=cleanup_state,
			)
		self.assertTrue(cancellation_event.is_set())
		self.assertFalse(cleanup_state["permitted"])
		self.assertEqual(executed, 1)
		self.assertEqual(len(reports), 1)
		self.assertEqual(
			{issue["kind"] for issue in issues},
			{"gut_shard_worker_schedule_failed"},
		)

	def test_base_exception_sets_cancellation_before_executor_drains_workers(self) -> None:
		temporary_owner = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_owner.cleanup)
		workspace = Path(temporary_owner.name)
		request = gf_maintenance.make_gut_shard_worker_request(
			{
				"name": "gut-lane-a",
				"role": "lane",
				"scripts": ["res://tests/gf_core/a/test_a.gd"],
			},
			workspace,
			workspace_fingerprint_value="1" * 64,
			manifest_digest="2" * 64,
			inventory_digest="3" * 64,
			remaining_seconds=120.0,
			import_timeout_seconds=60,
			gut_timeout_seconds=60,
		)
		worker_started = threading.Event()
		worker_drained = threading.Event()
		cancellation_event = threading.Event()

		def run_worker(
			worker_request: dict[str, object],
			*,
			cancellation_event: threading.Event,
			process_authority: gf_process_authority.FrozenProcessAuthority,
		) -> dict[str, object]:
			self.assertIs(process_authority, _SHARED_PROCESS_AUTHORITY)
			worker_started.set()
			self.assertTrue(cancellation_event.wait(timeout=2.0))
			worker_drained.set()
			return self._failed_worker_report(worker_request, kind="worker_cancelled")

		def interrupted_wait(*_args: object, **_kwargs: object) -> object:
			self.assertTrue(worker_started.wait(timeout=2.0))
			raise KeyboardInterrupt("fixture interrupt")

		with mock.patch.object(
			gf_maintenance.gf_gut_shard_worker,
			"run_worker",
			side_effect=run_worker,
		), mock.patch.object(
			gf_maintenance.concurrent.futures,
			"wait",
			side_effect=interrupted_wait,
		):
			with self.assertRaises(KeyboardInterrupt):
				gf_maintenance.execute_gut_shard_worker_wave(
					[request],
					{"gut-lane-a": workspace},
					expected_workspace_fingerprint="1" * 64,
					process_authority=_SHARED_PROCESS_AUTHORITY,
					deadline=time.perf_counter() + 10.0,
					cancellation_event=cancellation_event,
				)
		self.assertTrue(cancellation_event.is_set())
		self.assertTrue(worker_drained.is_set())

	def test_closed_worker_failures_continue_through_every_candidate_wave(self) -> None:
		temporary_owner = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_owner.cleanup)
		parallel_root = Path(temporary_owner.name)
		captured = mock.Mock(workspace_fingerprint="1" * 64)
		cancellation_event = threading.Event()
		seen_names = []

		def materialize(
			_captured: object,
			batch_root: Path,
			shards: list[dict[str, object]],
			*,
			git_process: gf_process_authority.FrozenGitProcess,
			deadline: float,
		) -> tuple[dict[str, Path], dict[str, tuple[int, int, int]]]:
			self.assertIs(git_process, _SHARED_PROCESS_AUTHORITY.git)
			del deadline
			result = {}
			identities = {}
			for index, shard in enumerate(shards):
				workspace = batch_root / f"fixture-{index}"
				workspace.mkdir()
				result[shard["name"]] = workspace
				identities[shard["name"]] = (
					gf_maintenance.gf_parallel_validation._owned_directory_identity(  # noqa: SLF001
						workspace.lstat()
					)
				)
			return result, identities

		def run_worker(
			request: dict[str, object],
			*,
			cancellation_event: threading.Event,
			process_authority: gf_process_authority.FrozenProcessAuthority,
			expected_workspace_identity: tuple[int, int, int],
		) -> dict[str, object]:
			self.assertIs(process_authority, _SHARED_PROCESS_AUTHORITY)
			self.assertIsInstance(expected_workspace_identity, tuple)
			self.assertLessEqual(
				request["remaining_seconds"],
				gf_maintenance.gut_shard_worker_total_timeout_seconds(60, 60),
			)
			seen_names.append(request["shard_name"])
			return self._failed_worker_report(request)

		with mock.patch.object(
			gf_maintenance,
			"materialize_gut_shard_workspaces",
			side_effect=materialize,
		), mock.patch.object(
			gf_maintenance.gf_gut_shard_worker,
			"run_worker",
			side_effect=run_worker,
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value={"fingerprint": "1" * 64},
		), mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"assert_source_matches_snapshot",
		), mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"run_parallel_shards",
			side_effect=AssertionError("nested worker supervisor forbidden"),
		) as nested_runner:
			reports, executed, issues = gf_maintenance.execute_gut_shard_candidate_reports(
				captured,
				self.MANIFEST,
				parallel_root,
				jobs=2,
				process_authority=_SHARED_PROCESS_AUTHORITY,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
				deadline=time.perf_counter() + 300.0,
				cancellation_event=cancellation_event,
			)
		self.assertFalse(cancellation_event.is_set())
		self.assertEqual(issues, [])
		self.assertEqual(executed, 9)
		self.assertEqual(len(reports), 9)
		self.assertCountEqual(
			seen_names,
			[shard["name"] for shard in self.MANIFEST["shards"]],
		)
		self.assertEqual(
			[report["request"]["shard_name"] for report in reports],
			[shard["name"] for shard in self.MANIFEST["shards"]],
		)
		nested_runner.assert_not_called()

	def test_worker_local_deadline_or_phase_timeout_cancels_later_waves(self) -> None:
		for failure_mode in ("deadline", "timed_out"):
			with self.subTest(failure_mode=failure_mode), tempfile.TemporaryDirectory() as temporary_directory:
				parallel_root = Path(temporary_directory)
				captured = mock.Mock(workspace_fingerprint="1" * 64)
				cancellation_event = threading.Event()
				seen_names: list[str] = []

				def materialize(
					_captured: object,
					batch_root: Path,
					shards: list[dict[str, object]],
					*,
					git_process: gf_process_authority.FrozenGitProcess,
					deadline: float,
				) -> tuple[dict[str, Path], dict[str, tuple[int, int, int]]]:
					self.assertIs(git_process, _SHARED_PROCESS_AUTHORITY.git)
					del deadline
					result = {}
					identities = {}
					for index, shard in enumerate(shards):
						workspace = batch_root / f"fixture-{index}"
						workspace.mkdir()
						result[shard["name"]] = workspace
						identities[shard["name"]] = (
							gf_maintenance.gf_parallel_validation._owned_directory_identity(  # noqa: SLF001
								workspace.lstat()
							)
						)
					return result, identities

				def run_worker(
					request: dict[str, object],
					*,
					cancellation_event: threading.Event,
					process_authority: gf_process_authority.FrozenProcessAuthority,
					expected_workspace_identity: tuple[int, int, int],
				) -> dict[str, object]:
					self.assertIs(process_authority, _SHARED_PROCESS_AUTHORITY)
					self.assertIsInstance(expected_workspace_identity, tuple)
					seen_names.append(request["shard_name"])
					if failure_mode == "deadline":
						return self._failed_worker_report(
							request,
							kind="worker_deadline_exhausted",
						)
					report = self._failed_worker_report(
						request,
						kind="worker_import_failed",
					)
					report["issues"][0]["phase"] = "import"
					report["import_run_count"] = 1
					report["import_result"] = {
						"ok": False,
						"exit_code": 124,
						"timed_out": True,
						"cancelled": False,
						"duration_seconds": 0.1,
					}
					report["continuation_safe"] = False
					report["duration_seconds"] = 0.1
					return report

				with mock.patch.object(
					gf_maintenance,
					"materialize_gut_shard_workspaces",
					side_effect=materialize,
				), mock.patch.object(
					gf_maintenance.gf_gut_shard_worker,
					"run_worker",
					side_effect=run_worker,
				), mock.patch.object(
					gf_maintenance,
					"workspace_fingerprint",
					return_value={"fingerprint": "1" * 64},
				), mock.patch.object(
					gf_maintenance.gf_parallel_validation,
					"assert_source_matches_snapshot",
					side_effect=AssertionError("later wave checkpoint must not run"),
				) as source_check:
					reports, executed, issues = gf_maintenance.execute_gut_shard_candidate_reports(
						captured,
						self.MANIFEST,
						parallel_root,
						jobs=2,
						process_authority=_SHARED_PROCESS_AUTHORITY,
						manifest_digest="2" * 64,
						inventory_digest="3" * 64,
						import_timeout_seconds=60,
						gut_timeout_seconds=60,
						deadline=time.perf_counter() + 300.0,
						cancellation_event=cancellation_event,
					)
				self.assertTrue(cancellation_event.is_set())
				self.assertEqual(executed, 2)
				self.assertEqual(len(reports), 2)
				self.assertCountEqual(
					seen_names,
					[shard["name"] for shard in self.MANIFEST["shards"][:2]],
				)
				self.assertIn(
					"gut_shard_worker_deadline_exhausted",
					{issue["kind"] for issue in issues},
				)
				source_check.assert_not_called()

	def test_candidate_source_drift_preserves_completed_wave_progress(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parallel_root = Path(temporary_directory)
			captured = mock.Mock(workspace_fingerprint="1" * 64)
			cancellation_event = threading.Event()
			cleanup_state = {"permitted": True}

			def materialize(
				_captured: object,
				batch_root: Path,
				shards: list[dict[str, object]],
				*,
				git_process: gf_process_authority.FrozenGitProcess,
				deadline: float,
			) -> tuple[dict[str, Path], dict[str, tuple[int, int, int]]]:
				self.assertIs(git_process, _SHARED_PROCESS_AUTHORITY.git)
				del deadline
				workspaces: dict[str, Path] = {}
				identities: dict[str, tuple[int, int, int]] = {}
				for index, shard in enumerate(shards):
					workspace = batch_root / f"s{index}"
					workspace.mkdir()
					workspaces[shard["name"]] = workspace
					identities[shard["name"]] = (
						gf_maintenance.gf_parallel_validation._owned_directory_identity(  # noqa: SLF001
							workspace.lstat()
						)
					)
				return workspaces, identities

			def completed_wave(
				requests: list[dict[str, object]],
				_workspace_by_name: dict[str, Path],
				**_kwargs: object,
			) -> tuple[list[dict[str, object]], int, list[dict[str, str]]]:
				return (
					[self._failed_worker_report(request) for request in requests],
					len(requests),
					[],
				)

			with mock.patch.object(
				gf_maintenance,
				"materialize_gut_shard_workspaces",
				side_effect=materialize,
			), mock.patch.object(
				gf_maintenance,
				"execute_gut_shard_worker_wave",
				side_effect=completed_wave,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"assert_source_matches_snapshot",
				side_effect=gf_maintenance.gf_parallel_validation.WorkspaceDriftError(
					"synthetic source drift"
				),
			):
				reports, executed, issues = (
					gf_maintenance.execute_gut_shard_candidate_reports(
						captured,
						self.MANIFEST,
						parallel_root,
						jobs=2,
						process_authority=_SHARED_PROCESS_AUTHORITY,
						manifest_digest="2" * 64,
						inventory_digest="3" * 64,
						import_timeout_seconds=60,
						gut_timeout_seconds=60,
						deadline=time.perf_counter() + 300.0,
						cancellation_event=cancellation_event,
						cleanup_state=cleanup_state,
					)
				)
			self.assertEqual(executed, 2)
			self.assertEqual(len(reports), 2)
			self.assertTrue(cancellation_event.is_set())
			self.assertFalse(cleanup_state["permitted"])
			self.assertIn(
				"gut_shard_candidate_source_verification_failed",
				{issue["kind"] for issue in issues},
			)

	def test_candidate_batch_cleanup_failure_cancels_and_forbids_outer_cleanup(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parallel_root = Path(temporary_directory)
			captured = mock.Mock(workspace_fingerprint="1" * 64)
			cancellation_event = threading.Event()
			cleanup_state = {"permitted": True}

			def materialize(
				_captured: object,
				batch_root: Path,
				shards: list[dict[str, object]],
				*,
				git_process: gf_process_authority.FrozenGitProcess,
				deadline: float,
			) -> tuple[dict[str, Path], dict[str, tuple[int, int, int]]]:
				self.assertIs(git_process, _SHARED_PROCESS_AUTHORITY.git)
				del deadline
				result = {}
				identities = {}
				for index, shard in enumerate(shards):
					workspace = batch_root / f"fixture-{index}"
					workspace.mkdir()
					result[shard["name"]] = workspace
					identities[shard["name"]] = (
						gf_maintenance.gf_parallel_validation._owned_directory_identity(  # noqa: SLF001
							workspace.lstat()
						)
					)
				return result, identities

			def run_worker(
				request: dict[str, object],
				*,
				cancellation_event: threading.Event,
				process_authority: gf_process_authority.FrozenProcessAuthority,
				expected_workspace_identity: tuple[int, int, int],
			) -> dict[str, object]:
				self.assertIs(process_authority, _SHARED_PROCESS_AUTHORITY)
				self.assertIsInstance(expected_workspace_identity, tuple)
				return self._failed_worker_report(request)

			with mock.patch.object(
				gf_maintenance,
				"materialize_gut_shard_workspaces",
				side_effect=materialize,
			), mock.patch.object(
				gf_maintenance.gf_gut_shard_worker,
				"run_worker",
				side_effect=run_worker,
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				return_value={"fingerprint": "1" * 64},
			), mock.patch.object(
				gf_maintenance,
				"remove_owned_gut_shard_workspace_batch",
				return_value="synthetic batch cleanup failure",
			):
				reports, executed, issues = gf_maintenance.execute_gut_shard_candidate_reports(
					captured,
					self.MANIFEST,
					parallel_root,
					jobs=2,
					process_authority=_SHARED_PROCESS_AUTHORITY,
					manifest_digest="2" * 64,
					inventory_digest="3" * 64,
					import_timeout_seconds=60,
					gut_timeout_seconds=60,
					deadline=time.perf_counter() + 300.0,
					cancellation_event=cancellation_event,
					cleanup_state=cleanup_state,
				)
			self.assertEqual(executed, 2)
			self.assertEqual(len(reports), 2)
			self.assertTrue(cancellation_event.is_set())
			self.assertFalse(cleanup_state["permitted"])
			self.assertIn(
				"gut_shard_workspace_cleanup_failed",
				{issue["kind"] for issue in issues},
			)

	def test_candidate_materialization_and_nested_cleanup_failure_forbid_outer_cleanup(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			cleanup_state = {"permitted": True}
			with mock.patch.object(
				gf_maintenance,
				"materialize_gut_shard_workspaces",
				side_effect=OSError("synthetic materialization failure"),
			), mock.patch.object(
				gf_maintenance,
				"remove_managed_temporary_tree",
				return_value="synthetic nested cleanup failure",
			):
				reports, executed, issues = (
					gf_maintenance.execute_gut_shard_candidate_reports(
						mock.Mock(workspace_fingerprint="1" * 64),
						self.MANIFEST,
						Path(temporary_directory),
						jobs=2,
						process_authority=_SHARED_PROCESS_AUTHORITY,
						manifest_digest="2" * 64,
						inventory_digest="3" * 64,
						import_timeout_seconds=60,
						gut_timeout_seconds=60,
						deadline=time.perf_counter() + 30.0,
						cancellation_event=threading.Event(),
						cleanup_state=cleanup_state,
					)
				)
			self.assertEqual(reports, [])
			self.assertEqual(executed, 0)
			self.assertIn(
				"gut_shard_candidate_batch_failed",
				{issue["kind"] for issue in issues},
			)
			self.assertIn(
				"gut_shard_workspace_cleanup_failed",
				{issue["kind"] for issue in issues},
			)
			self.assertFalse(cleanup_state["permitted"])

	def test_candidate_retains_batch_when_materializer_refuses_replaced_child(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parallel_root = Path(temporary_directory)
			cleanup_state = {"permitted": True}
			cancellation_event = threading.Event()

			def reject_replaced_child(
				_captured: object,
				batch_root: Path,
				_shards: list[dict[str, object]],
				*,
				git_process: gf_process_authority.FrozenGitProcess,
				deadline: float,
			) -> dict[str, Path]:
				self.assertIs(git_process, _SHARED_PROCESS_AUTHORITY.git)
				del deadline
				target = batch_root / "s0"
				target.mkdir()
				expected_identity = target.lstat()
				target.rename(batch_root / "original-s0")
				target.mkdir()
				(target / "replacement-marker.txt").write_text(
					"replacement",
					encoding="utf-8",
				)
				gf_maintenance.gf_parallel_validation._remove_owned_tree(  # noqa: SLF001
					target,
					expected_identity=expected_identity,
				)
				raise AssertionError("replaced child cleanup must fail closed")

			with mock.patch.object(
				gf_maintenance,
				"materialize_gut_shard_workspaces",
				side_effect=reject_replaced_child,
			):
				reports, executed, issues = (
					gf_maintenance.execute_gut_shard_candidate_reports(
						mock.Mock(workspace_fingerprint="1" * 64),
						self.MANIFEST,
						parallel_root,
						jobs=2,
						process_authority=_SHARED_PROCESS_AUTHORITY,
						manifest_digest="2" * 64,
						inventory_digest="3" * 64,
						import_timeout_seconds=60,
						gut_timeout_seconds=60,
						deadline=time.perf_counter() + 30.0,
						cancellation_event=cancellation_event,
						cleanup_state=cleanup_state,
					)
				)
			batch_root = parallel_root / "0"
			self.assertEqual(reports, [])
			self.assertEqual(executed, 0)
			self.assertIn(
				"gut_shard_candidate_batch_failed",
				{issue["kind"] for issue in issues},
			)
			self.assertTrue((batch_root / "s0" / "replacement-marker.txt").is_file())
			self.assertTrue((batch_root / "original-s0").is_dir())
			self.assertTrue(cancellation_event.is_set())
			self.assertFalse(cleanup_state["permitted"])

	def test_candidate_distinguishes_pre_yield_workspace_acquisition_failure(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parallel_root = Path(temporary_directory)
			foreign_batch = parallel_root / "0"
			foreign_batch.mkdir()
			marker = foreign_batch / "foreign-marker.txt"
			marker.write_text("retain", encoding="utf-8")
			cleanup_state = {"permitted": True}
			cancellation_event = threading.Event()
			reports, executed, issues = gf_maintenance.execute_gut_shard_candidate_reports(
				mock.Mock(workspace_fingerprint="1" * 64),
				self.MANIFEST,
				parallel_root,
				jobs=2,
				process_authority=_SHARED_PROCESS_AUTHORITY,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
				deadline=time.perf_counter() + 30.0,
				cancellation_event=cancellation_event,
				cleanup_state=cleanup_state,
			)
			kinds = {issue["kind"] for issue in issues}
			self.assertEqual(reports, [])
			self.assertEqual(executed, 0)
			self.assertIn("gut_shard_candidate_workspace_acquisition_failed", kinds)
			self.assertNotIn("gut_shard_workspace_cleanup_failed", kinds)
			self.assertTrue(marker.is_file())
			self.assertTrue(cancellation_event.is_set())
			self.assertFalse(cleanup_state["permitted"])

	def test_unproven_process_boundary_cancels_and_retains_owned_workspace(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			workspace = root / "workspace"
			workspace.mkdir()
			request = gf_maintenance.make_gut_shard_worker_request(
				{
					"name": "gut-lane-a",
					"role": "lane",
					"scripts": ["res://tests/gf_core/a/test_a.gd"],
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
			)
			report = self._failed_worker_report(request)
			report["process_boundary_quiescent"] = False
			report["workspace_cleanup_permitted"] = False
			report["continuation_safe"] = False
			cancellation_event = threading.Event()
			cleanup_state = {"permitted": True}
			with mock.patch.object(
				gf_maintenance.gf_gut_shard_worker,
				"run_worker",
				return_value=report,
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				side_effect=AssertionError(
					"unproven worker boundary must forbid post-validation reads"
				),
			) as fingerprint:
				reports, executed, issues = gf_maintenance.execute_gut_shard_worker_wave(
					[request],
					{"gut-lane-a": workspace},
					expected_workspace_fingerprint="1" * 64,
					process_authority=_SHARED_PROCESS_AUTHORITY,
					deadline=time.perf_counter() + 10.0,
					cancellation_event=cancellation_event,
					cleanup_state=cleanup_state,
				)
			self.assertEqual(executed, 1)
			self.assertEqual(len(reports), 1)
			self.assertTrue(cancellation_event.is_set())
			self.assertFalse(cleanup_state["permitted"])
			fingerprint.assert_not_called()
			self.assertIn(
				"gut_shard_workspace_ownership_unproven",
				{issue["kind"] for issue in issues},
			)

	def test_post_validation_git_boundary_debt_is_not_protocol_rejection(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory) / "workspace"
			workspace.mkdir()
			request = gf_maintenance.make_gut_shard_worker_request(
				{
					"name": "gut-lane-a",
					"role": "lane",
					"scripts": ["res://tests/gf_core/a/test_a.gd"],
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
			)
			report = self._failed_worker_report(request)
			cancellation_event = threading.Event()
			cleanup_state = {"permitted": True}
			with mock.patch.object(
				gf_maintenance.gf_gut_shard_worker,
				"run_worker",
				return_value=report,
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				side_effect=(
					gf_maintenance.gf_maintenance_check_graph.
					WorkspaceFingerprintProcessBoundaryError("synthetic Git boundary debt")
				),
			):
				reports, executed, issues = gf_maintenance.execute_gut_shard_worker_wave(
					[request],
					{"gut-lane-a": workspace},
					expected_workspace_fingerprint="1" * 64,
					process_authority=_SHARED_PROCESS_AUTHORITY,
					deadline=time.perf_counter() + 10.0,
					cancellation_event=cancellation_event,
					cleanup_state=cleanup_state,
				)
			kinds = {issue["kind"] for issue in issues}
			self.assertEqual(executed, 1)
			self.assertEqual(reports, [])
			self.assertIn("gut_shard_workspace_fingerprint_boundary_unproven", kinds)
			self.assertNotIn("gut_shard_worker_report_rejected", kinds)
			self.assertTrue(cancellation_event.is_set())
			self.assertFalse(cleanup_state["permitted"])

	def test_worker_cleanup_debt_cancels_and_retains_owned_workspace(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			workspace = root / "workspace"
			workspace.mkdir()
			request = gf_maintenance.make_gut_shard_worker_request(
				{
					"name": "gut-lane-a",
					"role": "lane",
					"scripts": ["res://tests/gf_core/a/test_a.gd"],
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
			)
			report = self._failed_worker_report(
				request,
				kind="worker_private_environment_cleanup_failed",
			)
			report["issues"][0]["phase"] = "cleanup"
			report["worker_cleanup_complete"] = False
			cancellation_event = threading.Event()
			cleanup_state = {"permitted": True}
			with mock.patch.object(
				gf_maintenance.gf_gut_shard_worker,
				"run_worker",
				return_value=report,
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				return_value={"fingerprint": "1" * 64},
			):
				reports, executed, issues = gf_maintenance.execute_gut_shard_worker_wave(
					[request],
					{"gut-lane-a": workspace},
					expected_workspace_fingerprint="1" * 64,
					process_authority=_SHARED_PROCESS_AUTHORITY,
					deadline=time.perf_counter() + 10.0,
					cancellation_event=cancellation_event,
					cleanup_state=cleanup_state,
				)
			self.assertEqual(executed, 1)
			self.assertEqual(len(reports), 1)
			self.assertTrue(cancellation_event.is_set())
			self.assertFalse(cleanup_state["permitted"])
			self.assertIn(
				"gut_shard_worker_cleanup_debt",
				{issue["kind"] for issue in issues},
			)

	def test_managed_owned_directory_retains_when_cleanup_is_not_proven(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			owned = Path(temporary_directory) / "owned"
			errors: list[str] = []
			with gf_maintenance.managed_owned_directory(
				owned,
				cleanup_errors=errors,
				cleanup_permitted=lambda: False,
			):
				(owned / "evidence.txt").write_text("retain", encoding="utf-8")
			self.assertTrue((owned / "evidence.txt").is_file())
			self.assertTrue(any("Retained managed directory" in error for error in errors))

	def test_managed_owned_directory_marks_only_real_cleanup_failures(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			cleanup_state = {"permitted": True}
			cleanup_failed = mock.Mock(
				side_effect=lambda: cleanup_state.__setitem__("permitted", False)
			)
			errors: list[str] = []
			success = root / "success"
			with gf_maintenance.managed_owned_directory(
				success,
				cleanup_errors=errors,
				cleanup_permitted=lambda: cleanup_state["permitted"],
				cleanup_failed=cleanup_failed,
			):
				(success / "fixture.txt").write_text("fixture", encoding="utf-8")
			self.assertFalse(success.exists())
			self.assertEqual(errors, [])
			self.assertTrue(cleanup_state["permitted"])
			cleanup_failed.assert_not_called()

			failure = root / "failure"
			with mock.patch.object(
				gf_maintenance,
				"remove_managed_temporary_tree",
				return_value="synthetic cleanup failure",
			):
				with gf_maintenance.managed_owned_directory(
					failure,
					cleanup_errors=errors,
					cleanup_permitted=lambda: cleanup_state["permitted"],
					cleanup_failed=cleanup_failed,
				):
					(failure / "fixture.txt").write_text("fixture", encoding="utf-8")
			self.assertEqual(errors, ["synthetic cleanup failure"])
			self.assertFalse(cleanup_state["permitted"])
			cleanup_failed.assert_called_once_with()

	def test_cleanup_base_exception_revokes_every_wider_owner(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			cleanup_state = {"permitted": True}
			owned = root / "owned"
			with mock.patch.object(
				gf_maintenance,
				"remove_managed_temporary_tree",
				side_effect=KeyboardInterrupt("synthetic cleanup interrupt"),
			), self.assertRaisesRegex(KeyboardInterrupt, "cleanup interrupt"):
				with gf_maintenance.managed_owned_directory(
					owned,
					cleanup_errors=[],
					cleanup_permitted=lambda: cleanup_state["permitted"],
					cleanup_started=lambda: cleanup_state.__setitem__("permitted", False),
					cleanup_succeeded=lambda: cleanup_state.__setitem__("permitted", True),
					cleanup_failed=lambda: cleanup_state.__setitem__("permitted", False),
				):
					(owned / "evidence.txt").write_text("retain", encoding="utf-8")
			self.assertFalse(cleanup_state["permitted"])
			self.assertTrue((owned / "evidence.txt").is_file())

			batch_state = {"permitted": True}
			cancellation_event = threading.Event()
			batch = root / "batch"
			with mock.patch.object(
				gf_maintenance,
				"remove_owned_gut_shard_workspace_batch",
				side_effect=SystemExit("synthetic batch cleanup interrupt"),
			), self.assertRaisesRegex(SystemExit, "batch cleanup interrupt"):
				with gf_maintenance.managed_gut_shard_workspace_batch(
					batch,
					cleanup_errors=[],
					workspace_ownership={},
					cancellation_event=cancellation_event,
					cleanup_state=batch_state,
				):
					pass
			self.assertFalse(batch_state["permitted"])
			self.assertTrue(cancellation_event.is_set())
			self.assertTrue(batch.is_dir())

	def test_exact_workspace_batch_cleanup_preflights_every_child(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			batch = Path(temporary_directory) / "batch"
			batch.mkdir()
			first = batch / "s0"
			second = batch / "s1"
			first.mkdir()
			second.mkdir()
			(first / "first.txt").write_text("first", encoding="utf-8")
			(second / "second.txt").write_text("second", encoding="utf-8")
			batch_identity = batch.lstat()
			ownership = {
				first: gf_maintenance.gf_parallel_validation._owned_directory_identity(  # noqa: SLF001
					first.lstat()
				),
				second: gf_maintenance.gf_parallel_validation._owned_directory_identity(  # noqa: SLF001
					second.lstat()
				),
			}
			second.rename(batch / "original-s1")
			second.mkdir()
			(second / "replacement.txt").write_text("replacement", encoding="utf-8")
			error = gf_maintenance.remove_owned_gut_shard_workspace_batch(
				batch,
				batch_identity,
				ownership,
			)
			self.assertIn("membership differs", error)
			self.assertTrue((first / "first.txt").is_file())
			self.assertTrue((second / "replacement.txt").is_file())
			self.assertTrue((batch / "original-s1" / "second.txt").is_file())

	def test_exact_workspace_batch_cleanup_rejects_unowned_entry_and_deletes_normal_batch(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			batch = Path(temporary_directory) / "batch"
			batch.mkdir()
			workspace = batch / "s0"
			workspace.mkdir()
			(workspace / "source.txt").write_text("source", encoding="utf-8")
			ownership = {
				workspace: gf_maintenance.gf_parallel_validation._owned_directory_identity(  # noqa: SLF001
					workspace.lstat()
				),
			}
			unexpected = batch / ".gf-gut-leftover"
			unexpected.mkdir()
			error = gf_maintenance.remove_owned_gut_shard_workspace_batch(
				batch,
				batch.lstat(),
				ownership,
			)
			self.assertIn("membership differs", error)
			self.assertTrue((workspace / "source.txt").is_file())
			self.assertTrue(unexpected.is_dir())
			unexpected.rmdir()
			self.assertEqual(
				gf_maintenance.remove_owned_gut_shard_workspace_batch(
					batch,
					batch.lstat(),
					ownership,
				),
				"",
			)
			self.assertFalse(batch.exists())

	def test_timeout_above_worker_ceiling_fails_before_capture_or_probe(self) -> None:
		with mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"capture_workspace",
		) as capture, mock.patch.object(
			gf_maintenance,
			"run_parallel_godot_isolation_probe",
		) as isolation_probe:
			with self.assertRaisesRegex(ValueError, "phase timeout ceiling"):
				gf_maintenance.gut_shard_run(
					timeout_seconds=(
						gf_maintenance.gf_gut_shard_worker.MAX_PHASE_TIMEOUT_SECONDS + 1
					),
				)
		capture.assert_not_called()
		isolation_probe.assert_not_called()

	def test_control_uses_direct_worker_without_parallel_shard_supervisor(self) -> None:
		temporary_owner = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_owner.cleanup)
		parallel_root = Path(temporary_owner.name)
		captured = mock.Mock(workspace_fingerprint="1" * 64)

		def materialize(
			_captured: object,
			destination: Path,
			*,
			git_process: gf_process_authority.FrozenGitProcess,
			deadline: float,
			verify_source: bool,
			identity_callback: object,
		) -> Path:
			self.assertIs(git_process, _SHARED_PROCESS_AUTHORITY.git)
			del deadline
			self.assertFalse(verify_source)
			destination.mkdir()
			identity_callback(
				gf_maintenance.gf_parallel_validation._owned_directory_identity(  # noqa: SLF001
					destination.lstat()
				)
			)
			return destination

		def run_worker(
			request: dict[str, object],
			*,
			cancellation_event: threading.Event,
			process_authority: gf_process_authority.FrozenProcessAuthority,
			expected_workspace_identity: tuple[int, int, int] | None = None,
		) -> dict[str, object]:
			self.assertIs(process_authority, _SHARED_PROCESS_AUTHORITY)
			self.assertFalse(cancellation_event.is_set())
			self.assertIsNotNone(expected_workspace_identity)
			self.assertEqual(request["mode"], gf_maintenance.gf_gut_shard_worker.CONTROL_MODE)
			return self._successful_worker_report(request, self._junit(request["scripts"]))

		with mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"materialize_workspace",
			side_effect=materialize,
		), mock.patch.object(
			gf_maintenance.gf_gut_shard_worker,
			"run_worker",
			side_effect=run_worker,
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value={"fingerprint": "1" * 64},
		), mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"assert_source_matches_snapshot",
		), mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"run_parallel_shards",
			side_effect=AssertionError("nested worker supervisor forbidden"),
		) as nested_runner:
			report, executed, issues = gf_maintenance.execute_gut_shard_control_report(
				captured,
				parallel_root,
				inventory=self.INVENTORY,
				process_authority=_SHARED_PROCESS_AUTHORITY,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
				deadline=time.perf_counter() + 300.0,
				cancellation_event=threading.Event(),
			)
		self.assertEqual(issues, [])
		self.assertEqual(executed, 1)
		self.assertIsNotNone(report)
		self.assertEqual(report["request"]["mode"], gf_maintenance.gf_gut_shard_worker.CONTROL_MODE)
		nested_runner.assert_not_called()

	def test_control_retains_root_when_materializer_refuses_replaced_child(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parallel_root = Path(temporary_directory)
			cleanup_state = {"permitted": True}
			cancellation_event = threading.Event()

			def reject_replaced_child(
				_captured: object,
				target: Path,
				*,
				git_process: gf_process_authority.FrozenGitProcess,
				deadline: float,
				verify_source: bool,
				identity_callback: object,
			) -> Path:
				self.assertIs(git_process, _SHARED_PROCESS_AUTHORITY.git)
				del deadline, identity_callback
				self.assertFalse(verify_source)
				target.mkdir()
				expected_identity = target.lstat()
				target.rename(target.parent / "original-s0")
				target.mkdir()
				(target / "replacement-marker.txt").write_text(
					"replacement",
					encoding="utf-8",
				)
				gf_maintenance.gf_parallel_validation._remove_owned_tree(  # noqa: SLF001
					target,
					expected_identity=expected_identity,
				)
				raise AssertionError("replaced child cleanup must fail closed")

			with mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"materialize_workspace",
				side_effect=reject_replaced_child,
			):
				control, executed, issues = (
					gf_maintenance.execute_gut_shard_control_report(
						mock.Mock(workspace_fingerprint="1" * 64),
						parallel_root,
						inventory=self.INVENTORY,
						process_authority=_SHARED_PROCESS_AUTHORITY,
						manifest_digest="2" * 64,
						inventory_digest="3" * 64,
						import_timeout_seconds=60,
						gut_timeout_seconds=60,
						deadline=time.perf_counter() + 30.0,
						cancellation_event=cancellation_event,
						cleanup_state=cleanup_state,
					)
				)
			control_root = parallel_root / "c"
			self.assertIsNone(control)
			self.assertEqual(executed, 0)
			self.assertIn(
				"gut_shard_control_report_rejected",
				{issue["kind"] for issue in issues},
			)
			self.assertIn(
				"gut_shard_control_cleanup_failed",
				{issue["kind"] for issue in issues},
			)
			self.assertTrue(
				(control_root / "s0" / "replacement-marker.txt").is_file()
			)
			self.assertTrue((control_root / "original-s0").is_dir())
			self.assertTrue(cancellation_event.is_set())
			self.assertFalse(cleanup_state["permitted"])

	def test_control_distinguishes_pre_yield_workspace_acquisition_failure(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parallel_root = Path(temporary_directory)
			foreign_control = parallel_root / "c"
			foreign_control.mkdir()
			marker = foreign_control / "foreign-marker.txt"
			marker.write_text("retain", encoding="utf-8")
			cleanup_state = {"permitted": True}
			cancellation_event = threading.Event()
			control, executed, issues = gf_maintenance.execute_gut_shard_control_report(
				mock.Mock(workspace_fingerprint="1" * 64),
				parallel_root,
				inventory=self.INVENTORY,
				process_authority=_SHARED_PROCESS_AUTHORITY,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
				deadline=time.perf_counter() + 30.0,
				cancellation_event=cancellation_event,
				cleanup_state=cleanup_state,
			)
			kinds = {issue["kind"] for issue in issues}
			self.assertIsNone(control)
			self.assertEqual(executed, 0)
			self.assertIn("gut_shard_control_workspace_acquisition_failed", kinds)
			self.assertNotIn("gut_shard_control_cleanup_failed", kinds)
			self.assertTrue(marker.is_file())
			self.assertTrue(cancellation_event.is_set())
			self.assertFalse(cleanup_state["permitted"])

	def test_candidate_aggregate_requires_all_exact_shards_and_combines_junit(self) -> None:
		inventory = tuple(
			f"res://tests/gf_core/synthetic/test_{index}.gd"
			for index in range(9)
		)
		manifest = {
			"inventory_digest": gf_maintenance.gf_gut_sharding.canonical_digest(list(inventory)),
			"shards": [
				{
					"name": name,
					"role": "contracts" if index == 0 else "lane",
					"scripts": [inventory[index]],
				}
				for index, name in enumerate(gf_maintenance.gf_gut_sharding.SHARD_NAMES)
			],
		}
		manifest_digest = gf_maintenance.gf_gut_sharding.canonical_digest(manifest)
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			reports = []
			for shard in manifest["shards"]:
				request = gf_maintenance.make_gut_shard_worker_request(
					shard,
					workspace,
					workspace_fingerprint_value="1" * 64,
					manifest_digest=manifest_digest,
					inventory_digest=manifest["inventory_digest"],
					remaining_seconds=120.0,
					import_timeout_seconds=60,
					gut_timeout_seconds=60,
				)
				reports.append(self._successful_worker_report(
					request,
					self._junit(shard["scripts"]),
				))
			with mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"validate_manifest",
				return_value=manifest,
			), mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"build_observation_report_from_script_records",
				return_value={"observation_only": True},
			):
				aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
					manifest,
					inventory,
					reports,
				)
			workspace_marker = str(workspace)
		with mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"validate_manifest",
			return_value=manifest,
		), mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"build_observation_report_from_script_records",
			return_value={"observation_only": True},
		):
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				manifest,
				inventory,
				reports,
			)
			missing = gf_maintenance.aggregate_gut_shard_candidate_reports(
				manifest,
				inventory,
				reports[:-1],
			)
		self.assertFalse(Path(workspace_marker).exists())
		self.assertTrue(aggregate["eligible"], aggregate["issues"])
		self.assertEqual(aggregate["shard_count"], 9)
		self.assertEqual(aggregate["script_count"], 9)
		self.assertEqual(aggregate["test_count"], 9)
		self.assertEqual(aggregate["assertion_count"], 9)
		self.assertFalse(missing["eligible"])

	def test_failed_worker_diagnostic_junit_never_becomes_candidate_evidence(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			reports = self._candidate_worker_reports(Path(temporary_directory))
			failed = reports[0]
			failed["ok"] = False
			failed["gut_result"] = {
				"ok": False,
				"exit_code": 1,
				"timed_out": False,
				"cancelled": False,
				"duration_seconds": 0.0,
			}
			failed["issues"] = [{
				"kind": "worker_gut_failed",
				"message": "fixture test failure",
				"phase": "gut",
			}]
			failed["continuation_safe"] = True
			validated = gf_maintenance.gf_gut_shard_worker.validate_report(failed)
			self.assertIsNotNone(validated["junit"])
			self.assertFalse(
				gf_maintenance.gut_shard_worker_report_eligible(validated)
			)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				reports,
			)
		self.assertFalse(aggregate["eligible"])
		self.assertEqual(aggregate["members"], [])
		self.assertIsNone(aggregate["semantic_result"])

	def test_qualification_ignores_duration_but_rejects_test_semantic_drift(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			candidate_reports = self._candidate_worker_reports(workspace)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				candidate_reports,
			)
			request = gf_maintenance.make_gut_shard_worker_request(
				{
					"name": gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME,
					"role": gf_maintenance.gf_gut_shard_worker.CONTROL_ROLE,
					"scripts": list(self.INVENTORY),
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest=aggregate["manifest_digest"],
				inventory_digest=aggregate["inventory_digest"],
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
				mode=gf_maintenance.gf_gut_shard_worker.CONTROL_MODE,
			)
			control = self._successful_worker_report(
				request,
				self._junit(list(self.INVENTORY), duration=0.9),
			)
			equivalent = gf_maintenance.compare_gut_shard_qualification(
				aggregate,
				control,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				candidate_reports=candidate_reports,
			)
			forged = copy.deepcopy(control)
			forged["junit"]["scripts"][0]["tests"][0]["status"] = "failed"
			forged["junit"]["scripts"][0]["status_counts"] = {
				"passed": 0,
				"failed": 1,
				"pending": 0,
				"no_asserts": 0,
				"skipped": 0,
			}
			forged["junit"]["status_counts"] = {
				"passed": len(self.INVENTORY) - 1,
				"failed": 1,
				"pending": 0,
				"no_asserts": 0,
				"skipped": 0,
			}
			forged["junit"]["failure_test_count"] = 1
			forged["junit"]["failure_assertion_count"] = 1
			forged["junit"]["scripts"][0]["failure_test_count_lower_bound"] = 1
			forged["junit"]["scripts"][0]["failure_test_count_upper_bound"] = 1
			forged["junit"]["scripts"][0]["failure_assertion_count"] = 1
			forged["junit_digest"] = gf_maintenance.gf_gut_shard_worker.canonical_digest(
				forged["junit"]
			)
			workspace_marker = str(workspace)
		equivalent = gf_maintenance.compare_gut_shard_qualification(
			aggregate,
			control,
			manifest=self.MANIFEST,
			inventory=self.INVENTORY,
			candidate_reports=candidate_reports,
		)
		different = gf_maintenance.compare_gut_shard_qualification(
			aggregate,
			forged,
			manifest=self.MANIFEST,
			inventory=self.INVENTORY,
			candidate_reports=candidate_reports,
		)
		self.assertFalse(Path(workspace_marker).exists())
		self.assertTrue(equivalent["equivalent"], equivalent["issues"])
		self.assertTrue(equivalent["semantic_match"])
		self.assertFalse(different["equivalent"])
		self.assertFalse(different["semantic_match"])

	def test_qualification_rejects_partial_or_forged_candidate_aggregate(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			candidate_reports = self._candidate_worker_reports(workspace)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				candidate_reports,
			)
			control = self._control_worker_report(workspace)

			partial = copy.deepcopy(aggregate)
			partial.pop("members")
			forged_semantic = copy.deepcopy(aggregate)
			forged_semantic["semantic_result"]["assertion_count"] += 1
			forged_count = copy.deepcopy(aggregate)
			forged_count["assertion_count"] += 1
			forged_status = copy.deepcopy(aggregate)
			forged_status["status_counts"] = {
				"passed": len(self.INVENTORY) - 1,
				"failed": 1,
				"pending": 0,
				"no_asserts": 0,
				"skipped": 0,
			}
			forged_member = copy.deepcopy(aggregate)
			forged_member["members"][0]["junit_report_digest"] = "c" * 64
			forged_member["member_evidence_digest"] = (
				gf_maintenance.gf_gut_shard_worker.canonical_digest(
					forged_member["members"]
				)
			)
			for candidate in (
				partial,
				forged_semantic,
				forged_count,
				forged_status,
				forged_member,
			):
				with self.subTest(fields=set(candidate)):
					result = gf_maintenance.compare_gut_shard_qualification(
						candidate,
						control,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						candidate_reports=candidate_reports,
					)
					self.assertFalse(result["equivalent"])
					self.assertFalse(result["candidate_eligible"])

			forged_failure = copy.deepcopy(aggregate)
			forged_script = forged_failure["scripts"][0]
			forged_script["tests"][0]["status"] = "failed"
			forged_script["status_counts"] = {
				"passed": 0,
				"failed": 1,
				"pending": 0,
				"no_asserts": 0,
				"skipped": 0,
			}
			forged_script["failure_test_count_lower_bound"] = 1
			forged_script["failure_test_count_upper_bound"] = 1
			forged_script["failure_assertion_count"] = 1
			forged_failure["status_counts"]["passed"] -= 1
			forged_failure["status_counts"]["failed"] = 1
			forged_failure["failure_test_count"] = 1
			forged_failure["failure_assertion_count"] = 1
			forged_failure["observation"] = (
				gf_maintenance.gf_gut_sharding.build_observation_report_from_script_records(
					self.MANIFEST,
					forged_failure["scripts"],
					failure_test_count=1,
				)
			)
			forged_failure["semantic_result"] = (
				gf_maintenance.gut_shard_semantic_result_from_evidence(
					forged_failure
				)
			)
			with self.assertRaisesRegex(ValueError, "only passing"):
				gf_maintenance.validate_gut_shard_candidate_aggregate(
					forged_failure,
					self.MANIFEST,
					self.INVENTORY,
					worker_reports=candidate_reports,
				)

	def test_equivalence_validator_rejects_forged_decision_booleans(self) -> None:
		valid_failure = {
			"schema_version": 1,
			"equivalent": False,
			"candidate_eligible": True,
			"control_eligible": True,
			"same_workspace": True,
			"same_manifest": True,
			"same_inventory": True,
			"semantic_match": False,
			"issues": [{
				"kind": "gut_shard_qualification_not_equivalent",
				"message": "fixture mismatch",
			}],
		}
		gf_maintenance.validate_gut_shard_equivalence_report(valid_failure)
		for mutation in (
			{**valid_failure, "equivalent": True},
			{**valid_failure, "semantic_match": "true"},
			{**valid_failure, "unexpected": False},
		):
			with self.assertRaises(ValueError):
				gf_maintenance.validate_gut_shard_equivalence_report(mutation)

	def test_top_report_validator_rejects_linked_positive_claim_mutations(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			worker_reports = self._candidate_worker_reports(workspace)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				worker_reports,
			)
			report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=False)
			report.update({
				"ok": True,
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					self.MANIFEST
				),
				"inventory_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					list(self.INVENTORY)
				),
				"inventory_count": len(self.INVENTORY),
				"candidate_eligible": True,
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": len(worker_reports),
				"completed_shard_count": len(worker_reports),
				"successful_shard_count": len(worker_reports),
				"duration_seconds": 1.0,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"shards": worker_reports,
				"aggregate": aggregate,
			})
			normalized = gf_maintenance.validate_gut_shard_run_report(
				report,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			self.assertTrue(normalized["ok"])
			other_reports = self._candidate_worker_reports(workspace)
			for worker_report in other_reports:
				worker_report["junit"] = self._junit(
					worker_report["request"]["scripts"],
					duration=0.9,
				)
				worker_report["junit_digest"] = (
					gf_maintenance.gf_gut_shard_worker.canonical_digest(
						worker_report["junit"]
					)
				)
			forged_independent = copy.deepcopy(report)
			forged_independent["shards"] = other_reports
			with self.assertRaisesRegex(ValueError, "not exactly derived"):
				gf_maintenance.validate_gut_shard_run_report(
					forged_independent,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			for mutate in (
				lambda value: value.__setitem__("candidate_eligible", False),
				lambda value: value.__setitem__("successful_shard_count", 8),
				lambda value: value["aggregate"].__setitem__("test_count", 100),
				lambda value: value["shards"].__setitem__(1, value["shards"][0]),
			):
				forged = copy.deepcopy(report)
				mutate(forged)
				with self.assertRaises((
					ValueError,
					gf_maintenance.gf_gut_shard_worker.GutShardWorkerError,
				)):
					gf_maintenance.validate_gut_shard_run_report(
						forged,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

	def test_top_report_validator_binds_private_workspace_and_timeout_policy(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			worker_reports = self._candidate_worker_reports(workspace)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				worker_reports,
			)
			report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=False)
			report.update({
				"ok": True,
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					self.MANIFEST
				),
				"inventory_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					list(self.INVENTORY)
				),
				"inventory_count": len(self.INVENTORY),
				"candidate_eligible": True,
				"shard_count": len(worker_reports),
				"executed_shard_count": len(worker_reports),
				"completed_shard_count": len(worker_reports),
				"successful_shard_count": len(worker_reports),
				"duration_seconds": 1.0,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"shards": worker_reports,
				"aggregate": aggregate,
			})
			with self.assertRaisesRegex(ValueError, "bound private context"):
				gf_maintenance.validate_gut_shard_run_report(
					report,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
				)

			duplicate_nonce = copy.deepcopy(report)
			duplicate_nonce["shards"][1]["request"]["nonce"] = (
				duplicate_nonce["shards"][0]["request"]["nonce"]
			)
			duplicate_nonce["shards"][1]["request_digest"] = (
				gf_maintenance.gf_gut_shard_worker.canonical_digest(
					duplicate_nonce["shards"][1]["request"]
				)
			)
			with self.assertRaisesRegex(ValueError, "nonces must be exact and unique"):
				gf_maintenance.validate_gut_shard_run_report(
					duplicate_nonce,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			duplicate_workspace = copy.deepcopy(report)
			duplicate_workspace["shards"][1]["request"]["workspace_path"] = (
				duplicate_workspace["shards"][0]["request"]["workspace_path"]
			)
			duplicate_workspace["shards"][1]["request_digest"] = (
				gf_maintenance.gf_gut_shard_worker.canonical_digest(
					duplicate_workspace["shards"][1]["request"]
				)
			)
			with self.assertRaisesRegex(ValueError, "non-overlapping workspaces"):
				gf_maintenance.validate_gut_shard_run_report(
					duplicate_workspace,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			forged_timeout = copy.deepcopy(report)
			forged_timeout["candidate_gut_timeout_seconds"] += 1
			with self.assertRaisesRegex(ValueError, "timeout policy"):
				gf_maintenance.validate_gut_shard_run_report(
					forged_timeout,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			forged_duration = copy.deepcopy(report)
			forged_duration["shards"][0]["duration_seconds"] = 2.0
			with self.assertRaisesRegex(ValueError, "duration cannot be shorter"):
				gf_maintenance.validate_gut_shard_run_report(
					forged_duration,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			forged_wave_duration = copy.deepcopy(report)
			for shard in forged_wave_duration["shards"]:
				shard["duration_seconds"] = 100.0
			forged_wave_duration["duration_seconds"] = 100.0
			with self.assertRaisesRegex(ValueError, "duration cannot be shorter"):
				gf_maintenance.validate_gut_shard_run_report(
					forged_wave_duration,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			for issue_kind, error_pattern in (
				("totally_fabricated", "unknown producer kind"),
				("gut_shard_run_setup_failed", "cannot follow published candidate aggregate"),
			):
				forged_failure = copy.deepcopy(report)
				forged_failure.update({
					"ok": False,
					"candidate_eligible": False,
					"issues": [{
						"kind": issue_kind,
						"message": "synthetic unrelated failure",
					}],
				})
				with self.subTest(issue_kind=issue_kind), self.assertRaisesRegex(
					ValueError,
					error_pattern,
				):
					gf_maintenance.validate_gut_shard_run_report(
						forged_failure,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

			duplicate_deadline = copy.deepcopy(report)
			duplicate_deadline.update({
				"ok": False,
				"candidate_eligible": False,
				"issues": [
					{
						"kind": "gut_shard_candidate_scheduling_deadline_exhausted",
						"message": "synthetic first parent deadline",
					},
					{
						"kind": "gut_shard_candidate_scheduling_deadline_exhausted",
						"message": "synthetic second parent deadline",
					},
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained validation root",
					},
				],
			})
			with self.assertRaisesRegex(ValueError, "duplicates singleton producer"):
				gf_maintenance.validate_gut_shard_run_report(
					duplicate_deadline,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			for control_issues in (
				[
					{
						"kind": "gut_shard_control_report_missing",
						"message": "synthetic unrequested control report",
					},
				],
				[
					{
						"kind": "gut_shard_control_deadline_exhausted",
						"message": "synthetic unrequested control deadline",
					},
					{
						"kind": "gut_shard_control_cleanup_failed",
						"message": "synthetic retained control root",
					},
				],
			):
				unrequested_control = copy.deepcopy(report)
				unrequested_control.update({
					"ok": False,
					"candidate_eligible": False,
					"issues": [
						*control_issues,
						{
							"kind": "gut_shard_validation_cleanup_failed",
							"message": "synthetic retained validation root",
						},
					],
				})
				with self.subTest(control_issues=control_issues), self.assertRaisesRegex(
					ValueError,
					"Unrequested GUT shard observation retained control-stage",
				):
					gf_maintenance.validate_gut_shard_run_report(
						unrequested_control,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

			for wave_kind in (
				"gut_shard_worker_wave_deadline_exhausted",
				"gut_shard_worker_wave_failed",
			):
				complete_wave_failure = copy.deepcopy(report)
				complete_wave_failure.update({
					"ok": False,
					"candidate_eligible": False,
					"issues": [
						{
							"kind": wave_kind,
							"message": "synthetic impossible complete wave failure",
						},
						{
							"kind": "gut_shard_workspace_cleanup_failed",
							"message": "synthetic retained candidate batch",
						},
						{
							"kind": "gut_shard_validation_cleanup_failed",
							"message": "synthetic retained validation root",
						},
					],
				})
				with self.subTest(wave_kind=wave_kind), self.assertRaisesRegex(
					ValueError,
					(
						"deadline lacks pending result"
						if wave_kind == "gut_shard_worker_wave_deadline_exhausted"
						else "complete.*result set"
					),
				):
					gf_maintenance.validate_gut_shard_run_report(
						complete_wave_failure,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

	def test_top_report_validator_rejects_qualified_label_without_positive_claim(self) -> None:
		report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=True)
		report.update({
			"qualification_status": "qualified",
			"duration_seconds": 0.1,
		})
		with self.assertRaisesRegex(ValueError, "qualified status"):
			gf_maintenance.validate_gut_shard_run_report(report)

	def test_top_report_validator_binds_probe_and_candidate_stop_to_aggregate_stage(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			manifest_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				self.MANIFEST
			)
			inventory_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				list(self.INVENTORY)
			)
			base = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=True)
			base.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": manifest_digest,
				"inventory_digest": inventory_digest,
				"inventory_count": len(self.INVENTORY),
				"shard_count": len(self.MANIFEST["shards"]),
				"not_scheduled_shard_count": len(self.MANIFEST["shards"]),
				"qualification_status": "infrastructure_failed",
				"duration_seconds": 0.1,
				"issues": [{
					"kind": "gut_shard_run_setup_failed",
					"message": "synthetic setup failure after probe publication",
				}],
			})
			probe_without_aggregate = copy.deepcopy(base)
			probe_without_aggregate["isolation_probe"] = {
				"ok": True,
				"probe_count": 2,
				"fields": [
					"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
				],
			}
			with self.assertRaisesRegex(ValueError, "isolation must publish"):
				gf_maintenance.validate_gut_shard_run_report(
					probe_without_aggregate,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			stop_before_probe = copy.deepcopy(base)
			stop_before_probe["qualification_status"] = "cleanup_failed"
			stop_before_probe["issues"] = [
				{
					"kind": "gut_shard_candidate_scheduling_deadline_exhausted",
					"message": "synthetic candidate-phase deadline before isolation",
				},
				{
					"kind": "gut_shard_validation_cleanup_failed",
					"message": "synthetic retained validation root",
				},
			]
			with self.assertRaisesRegex(ValueError, "candidate-phase stop lacks"):
				gf_maintenance.validate_gut_shard_run_report(
					stop_before_probe,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			cleanup_without_setup = copy.deepcopy(base)
			cleanup_without_setup["qualification_status"] = "cleanup_failed"
			cleanup_without_setup["issues"] = [{
				"kind": "gut_shard_validation_cleanup_failed",
				"message": "synthetic retained root without setup cause",
			}]
			with self.assertRaisesRegex(ValueError, "exact setup-stage cause"):
				gf_maintenance.validate_gut_shard_run_report(
					cleanup_without_setup,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			bound_early_runtime_mismatch = copy.deepcopy(base)
			bound_early_runtime_mismatch["issues"] = [{
				"kind": "gut_shard_runtime_source_mismatch",
				"message": "synthetic early loaded-source mismatch with bound context",
			}]
			with self.assertRaisesRegex(ValueError, "retained bound execution context"):
				gf_maintenance.validate_gut_shard_run_report(
					bound_early_runtime_mismatch,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

	def test_top_report_validator_revokes_unrequested_candidate_when_issues_exist(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			worker_reports = self._candidate_worker_reports(workspace)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				worker_reports,
			)
			report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=False)
			report.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					self.MANIFEST
				),
				"inventory_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					list(self.INVENTORY)
				),
				"inventory_count": len(self.INVENTORY),
				"candidate_eligible": True,
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": len(worker_reports),
				"completed_shard_count": len(worker_reports),
				"successful_shard_count": len(worker_reports),
				"duration_seconds": 0.1,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"shards": worker_reports,
				"aggregate": aggregate,
				"issues": [{
					"kind": "gut_shard_final_source_drift",
					"message": "fixture final drift",
				}],
			})
			with self.assertRaisesRegex(ValueError, "candidate eligibility is not derived"):
				gf_maintenance.validate_gut_shard_run_report(
					report,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

	def test_top_report_validator_binds_workspace_acquisition_to_exact_phase(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			manifest_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				self.MANIFEST
			)
			inventory_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				list(self.INVENTORY)
			)
			empty_aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				[],
			)
			candidate_acquisition = gf_maintenance.make_gut_shard_run_report(
				jobs=2,
				qualify=False,
			)
			candidate_acquisition.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": manifest_digest,
				"inventory_digest": inventory_digest,
				"inventory_count": len(self.INVENTORY),
				"shard_count": len(self.MANIFEST["shards"]),
				"not_scheduled_shard_count": len(self.MANIFEST["shards"]),
				"duration_seconds": 0.1,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"aggregate": empty_aggregate,
				"issues": [
					{
						"kind": "gut_shard_candidate_workspace_acquisition_failed",
						"message": "synthetic foreign candidate batch",
					},
					*copy.deepcopy(empty_aggregate["issues"]),
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained validation root",
					},
				],
			})
			gf_maintenance.validate_gut_shard_run_report(
				candidate_acquisition,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			for case, mutate in (
				(
					"missing_outer_cleanup",
					lambda value: value["issues"].pop(),
				),
				(
					"forged_inner_cleanup",
					lambda value: value["issues"].insert(1, {
						"kind": "gut_shard_workspace_cleanup_failed",
						"message": "synthetic impossible inner cleanup",
					}),
				),
				(
					"redundant_stop",
					lambda value: value["issues"].insert(1, {
						"kind": "gut_shard_candidate_scheduling_deadline_exhausted",
						"message": "synthetic redundant deadline",
					}),
				),
				(
					"impossible_final_source_phase",
					lambda value: value["issues"].insert(1, {
						"kind": "gut_shard_final_source_drift",
						"message": "synthetic unreachable final source drift",
					}),
				),
				(
					"unreported_worker",
					lambda value: value.update({
						"executed_shard_count": 1,
						"unreported_shard_count": 1,
						"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - 1,
					}),
				),
			):
				forged = copy.deepcopy(candidate_acquisition)
				mutate(forged)
				with self.subTest(case=case), self.assertRaises(ValueError):
					gf_maintenance.validate_gut_shard_run_report(
						forged,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

			candidate_reports = self._candidate_worker_reports(workspace)
			eligible_aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				candidate_reports,
			)
			control_acquisition = gf_maintenance.make_gut_shard_run_report(
				jobs=2,
				qualify=True,
			)
			control_acquisition.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": manifest_digest,
				"inventory_digest": inventory_digest,
				"inventory_count": len(self.INVENTORY),
				"shard_count": len(candidate_reports),
				"executed_shard_count": len(candidate_reports),
				"completed_shard_count": len(candidate_reports),
				"successful_shard_count": len(candidate_reports),
				"duration_seconds": 1.0,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"shards": candidate_reports,
				"aggregate": eligible_aggregate,
				"qualification_status": "cleanup_failed",
				"issues": [
					{
						"kind": "gut_shard_control_workspace_acquisition_failed",
						"message": "synthetic foreign control root",
					},
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained validation root",
					},
				],
			})
			gf_maintenance.validate_gut_shard_run_report(
				control_acquisition,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			for case, extra_issue in (
				(
					"forged_inner_cleanup",
					{
						"kind": "gut_shard_control_cleanup_failed",
						"message": "synthetic impossible control cleanup",
					},
				),
				(
					"redundant_control_stop",
					{
						"kind": "gut_shard_control_report_missing",
						"message": "synthetic redundant missing report",
					},
				),
				(
					"impossible_final_source_phase",
					{
						"kind": "gut_shard_final_source_drift",
						"message": "synthetic unreachable final source drift",
					},
				),
			):
				forged = copy.deepcopy(control_acquisition)
				forged["issues"].insert(1, extra_issue)
				with self.subTest(case=case), self.assertRaises(ValueError):
					gf_maintenance.validate_gut_shard_run_report(
						forged,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

	def test_top_report_validator_enforces_terminal_status_evidence(self) -> None:
		for status, error_pattern in (
			("candidate_ineligible", "failed aggregate evidence"),
			("control_ineligible", "failed control evidence"),
			("not_equivalent", "complete mismatch evidence"),
			("cleanup_failed", "terminal priority"),
		):
			with self.subTest(status=status):
				report = gf_maintenance.make_gut_shard_run_report(
					jobs=2,
					qualify=True,
				)
				report.update({
					"qualification_status": status,
					"duration_seconds": 0.1,
				})
				with self.assertRaisesRegex(ValueError, error_pattern):
					gf_maintenance.validate_gut_shard_run_report(report)

		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			worker_reports = self._candidate_worker_reports(workspace)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				worker_reports,
			)
			control_ineligible = gf_maintenance.make_gut_shard_run_report(
				jobs=2,
				qualify=True,
			)
			control_ineligible.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					self.MANIFEST
				),
				"inventory_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					list(self.INVENTORY)
				),
				"inventory_count": len(self.INVENTORY),
				"candidate_eligible": True,
				"qualification_status": "control_ineligible",
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": len(worker_reports),
				"completed_shard_count": len(worker_reports),
				"successful_shard_count": len(worker_reports),
				"duration_seconds": 0.1,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"shards": worker_reports,
				"aggregate": aggregate,
				"issues": [{
					"kind": "gut_shard_control_report_missing",
					"message": "control failed before publishing a report",
				}],
			})
			normalized = gf_maintenance.validate_gut_shard_run_report(
				control_ineligible,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
		self.assertEqual(normalized["qualification_status"], "control_ineligible")
		self.assertIsNone(normalized["control"])

	def test_terminal_candidate_state_requires_every_manifest_shard_report(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			worker_reports = self._candidate_worker_reports(workspace)[:-1]
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				worker_reports,
			)
			control = self._control_worker_report(workspace)
			report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=True)
			report.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					self.MANIFEST
				),
				"inventory_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					list(self.INVENTORY)
				),
				"inventory_count": len(self.INVENTORY),
				"qualification_status": "candidate_ineligible",
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": len(worker_reports),
				"completed_shard_count": len(worker_reports),
				"successful_shard_count": len(worker_reports),
				"not_scheduled_shard_count": 1,
				"duration_seconds": 0.1,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"shards": worker_reports,
				"aggregate": aggregate,
				"control": control,
				"issues": copy.deepcopy(aggregate["issues"]),
			})
			with self.assertRaisesRegex(ValueError, "incomplete candidate partition"):
				gf_maintenance.validate_gut_shard_run_report(
					report,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

	def test_terminal_candidate_state_rejects_infrastructure_worker_failure(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			worker_reports = self._candidate_worker_reports(workspace)
			failed_worker = self._failed_worker_report(
				worker_reports[0]["request"],
				kind="worker_deadline_exhausted",
			)
			worker_reports[0] = failed_worker
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				worker_reports,
			)
			worker_issue = failed_worker["issues"][0]
			report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=True)
			report.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					self.MANIFEST
				),
				"inventory_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					list(self.INVENTORY)
				),
				"inventory_count": len(self.INVENTORY),
				"qualification_status": "candidate_ineligible",
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": len(worker_reports),
				"completed_shard_count": len(worker_reports),
				"successful_shard_count": len(worker_reports) - 1,
				"failed_shard_count": 1,
				"duration_seconds": 0.1,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"shards": worker_reports,
				"aggregate": aggregate,
				"control": self._control_worker_report(workspace),
				"issues": [
					{
						"kind": worker_issue["kind"],
						"message": (
							f"{failed_worker['request']['shard_name']}: "
							f"{worker_issue['message']}"
						),
					},
					*copy.deepcopy(aggregate["issues"]),
				],
			})
			with self.assertRaisesRegex(ValueError, "derived worker orchestration debt"):
				gf_maintenance.validate_gut_shard_run_report(
					report,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

	def test_top_report_validator_binds_reports_to_scheduled_wave_prefix(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			all_reports = self._candidate_worker_reports(workspace)
			manifest_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				self.MANIFEST
			)
			inventory_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				list(self.INVENTORY)
			)

			for case, reports, executed, extra_issue in (
				(
					"all_unreported",
					[],
					len(self.MANIFEST["shards"]),
					{
						"kind": "gut_shard_worker_exception",
						"message": "synthetic fault wave",
					},
				),
				(
					"last_shard_first",
					[all_reports[-1]],
					1,
					None,
				),
				(
					"partial_second_wave_without_schedule_failure",
					all_reports[:2],
					3,
					{
						"kind": "gut_shard_worker_exception",
						"message": "synthetic result fault",
					},
				),
				(
					"final_drift_cannot_explain_an_incomplete_candidate_schedule",
					all_reports[:2],
					2,
					{
						"kind": "gut_shard_final_source_drift",
						"message": "synthetic post-candidate source drift",
					},
				),
			):
				with self.subTest(case=case):
					aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
						self.MANIFEST,
						self.INVENTORY,
						reports,
					)
					top_issues = (
						[extra_issue] if extra_issue is not None else []
					) + copy.deepcopy(aggregate["issues"])
					if case == "final_drift_cannot_explain_an_incomplete_candidate_schedule":
						top_issues = [
							*copy.deepcopy(aggregate["issues"]),
							extra_issue,
							{
								"kind": "gut_shard_validation_cleanup_failed",
								"message": "synthetic retained validation root",
							},
						]
					report = gf_maintenance.make_gut_shard_run_report(
						jobs=2,
						qualify=False,
					)
					report.update({
						"workspace_fingerprint": "1" * 64,
						"manifest_digest": manifest_digest,
						"inventory_digest": inventory_digest,
						"inventory_count": len(self.INVENTORY),
						"shard_count": len(self.MANIFEST["shards"]),
						"executed_shard_count": executed,
						"completed_shard_count": len(reports),
						"successful_shard_count": len(reports),
						"unreported_shard_count": executed - len(reports),
						"not_scheduled_shard_count": (
							len(self.MANIFEST["shards"]) - executed
						),
						"duration_seconds": 1.0,
						"isolation_probe": {
							"ok": True,
							"probe_count": 2,
							"fields": [
								"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
							],
						},
						"shards": reports,
						"aggregate": aggregate,
						"issues": top_issues,
					})
				with self.assertRaisesRegex(
					ValueError,
					"planned worker wave|scheduled wave|scheduled prefix|incomplete candidate partition|candidate infrastructure stop",
				):
					gf_maintenance.validate_gut_shard_run_report(
						report,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

			empty_aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				[],
			)
			too_many_worker_exceptions = gf_maintenance.make_gut_shard_run_report(
				jobs=2,
				qualify=False,
			)
			too_many_worker_exceptions.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": manifest_digest,
				"inventory_digest": inventory_digest,
				"inventory_count": len(self.INVENTORY),
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": 2,
				"unreported_shard_count": 2,
				"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - 2,
				"duration_seconds": 1.0,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"aggregate": empty_aggregate,
				"issues": [
					*[
						{
							"kind": "gut_shard_worker_exception",
							"message": f"synthetic worker exception {index}",
						}
						for index in range(3)
					],
					{
						"kind": "gut_shard_workspace_cleanup_failed",
						"message": "synthetic retained candidate batch",
					},
					*copy.deepcopy(empty_aggregate["issues"]),
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained validation root",
					},
				],
			})
			with self.assertRaisesRegex(
				ValueError,
				"worker-result failure|exceeds unreported execution",
			):
				gf_maintenance.validate_gut_shard_run_report(
					too_many_worker_exceptions,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			reachable_boundary_then_deadline = copy.deepcopy(
				too_many_worker_exceptions
			)
			reachable_boundary_then_deadline["issues"] = [
				{
					"kind": "gut_shard_workspace_fingerprint_boundary_unproven",
					"message": (
						f"{self.MANIFEST['shards'][0]['name']}: "
						"synthetic early boundary failure"
					),
				},
				{
					"kind": "gut_shard_worker_wave_deadline_exhausted",
					"message": "synthetic peer deadline",
				},
				{
					"kind": "gut_shard_workspace_cleanup_failed",
					"message": "synthetic retained candidate batch",
				},
				*copy.deepcopy(empty_aggregate["issues"]),
				{
					"kind": "gut_shard_validation_cleanup_failed",
					"message": "synthetic retained validation root",
				},
			]
			gf_maintenance.validate_gut_shard_run_report(
				reachable_boundary_then_deadline,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)

			wave_deadline_with_fingerprint_boundary = copy.deepcopy(
				reachable_boundary_then_deadline
			)
			wave_deadline_with_fingerprint_boundary["issues"][:2] = list(reversed(
				wave_deadline_with_fingerprint_boundary["issues"][:2]
			))
			with self.assertRaisesRegex(
				ValueError,
				"boundary and worker-wave deadline ordering is unreachable",
			):
				gf_maintenance.validate_gut_shard_run_report(
					wave_deadline_with_fingerprint_boundary,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			boundary_deadline_then_wave_failure = copy.deepcopy(
				reachable_boundary_then_deadline
			)
			boundary_deadline_then_wave_failure["issues"].insert(2, {
				"kind": "gut_shard_worker_wave_failed",
				"message": "synthetic failure while the peer remained unresolved",
			})
			gf_maintenance.validate_gut_shard_run_report(
				boundary_deadline_then_wave_failure,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)

			for label, executed, cause_issues in (
				(
					"deadline-before-schedule",
					1,
					[
						{
							"kind": "gut_shard_worker_wave_deadline_exhausted",
							"message": "synthetic impossible early deadline",
						},
						{
							"kind": "gut_shard_worker_schedule_failed",
							"message": (
								f"{self.MANIFEST['shards'][1]['name']}: "
								"synthetic late submit failure"
							),
						},
					],
				),
				(
					"wave-failed-before-deadline",
					2,
					[
						{
							"kind": "gut_shard_worker_wave_failed",
							"message": "synthetic impossible early outer failure",
						},
						{
							"kind": "gut_shard_worker_wave_deadline_exhausted",
							"message": "synthetic late deadline",
						},
					],
				),
				(
					"fingerprint-before-schedule",
					1,
					[
						{
							"kind": "gut_shard_workspace_fingerprint_boundary_unproven",
							"message": (
								f"{self.MANIFEST['shards'][0]['name']}: "
								"synthetic impossible pre-schedule result"
							),
						},
						{
							"kind": "gut_shard_worker_schedule_failed",
							"message": (
								f"{self.MANIFEST['shards'][1]['name']}: "
								"synthetic late submit failure"
							),
						},
					],
				),
				(
					"exception-before-schedule",
					1,
					[
						{
							"kind": "gut_shard_worker_exception",
							"message": (
								f"{self.MANIFEST['shards'][0]['name']}: "
								"synthetic impossible pre-schedule result"
							),
						},
						{
							"kind": "gut_shard_worker_schedule_failed",
							"message": (
								f"{self.MANIFEST['shards'][1]['name']}: "
								"synthetic late submit failure"
							),
						},
					],
				),
			):
				unreachable_wave_order = copy.deepcopy(too_many_worker_exceptions)
				unreachable_wave_order.update({
					"executed_shard_count": executed,
					"unreported_shard_count": executed,
					"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - executed,
					"issues": [
						*copy.deepcopy(cause_issues),
						{
							"kind": "gut_shard_workspace_cleanup_failed",
							"message": "synthetic retained candidate batch",
						},
						*copy.deepcopy(empty_aggregate["issues"]),
						{
							"kind": "gut_shard_validation_cleanup_failed",
							"message": "synthetic retained validation root",
						},
					],
				})
				with self.subTest(label=label), self.assertRaisesRegex(
					ValueError,
					"did not precede|did not follow",
				):
					gf_maintenance.validate_gut_shard_run_report(
						unreachable_wave_order,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

			candidate_deadline_issue = {
				"kind": "gut_shard_worker_wave_deadline_exhausted",
				"message": "synthetic single-worker parent deadline",
			}
			candidate_exception_issue = {
				"kind": "gut_shard_worker_exception",
				"message": (
					f"{self.MANIFEST['shards'][0]['name']}: "
					"synthetic late worker exception"
				),
			}
			candidate_cleanup_issue = {
				"kind": "gut_shard_workspace_cleanup_failed",
				"message": "synthetic retained candidate batch",
			}
			outer_cleanup_issue = {
				"kind": "gut_shard_validation_cleanup_failed",
				"message": "synthetic retained validation root",
			}
			single_worker_deadline = gf_maintenance.make_gut_shard_run_report(
				jobs=1,
				qualify=False,
			)
			single_worker_deadline.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": manifest_digest,
				"inventory_digest": inventory_digest,
				"inventory_count": len(self.INVENTORY),
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": 1,
				"unreported_shard_count": 1,
				"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - 1,
				"duration_seconds": 1.0,
				"isolation_probe": copy.deepcopy(
					too_many_worker_exceptions["isolation_probe"]
				),
				"aggregate": copy.deepcopy(empty_aggregate),
				"issues": [
					candidate_deadline_issue,
					candidate_exception_issue,
					candidate_cleanup_issue,
					*copy.deepcopy(empty_aggregate["issues"]),
					outer_cleanup_issue,
				],
			})
			gf_maintenance.validate_gut_shard_run_report(
				single_worker_deadline,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			single_worker_reverse = copy.deepcopy(single_worker_deadline)
			single_worker_reverse["issues"][:2] = list(reversed(
				single_worker_reverse["issues"][:2]
			))
			with self.assertRaisesRegex(ValueError, "single-worker result failure preceded"):
				gf_maintenance.validate_gut_shard_run_report(
					single_worker_reverse,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			partial_schedule_deadline = copy.deepcopy(too_many_worker_exceptions)
			partial_schedule_deadline.update({
				"executed_shard_count": 1,
				"unreported_shard_count": 1,
				"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - 1,
				"issues": [
					{
						"kind": "gut_shard_worker_schedule_failed",
						"message": (
							f"{self.MANIFEST['shards'][1]['name']}: "
							"synthetic second submit failure"
						),
					},
					candidate_deadline_issue,
					candidate_exception_issue,
					candidate_cleanup_issue,
					*copy.deepcopy(empty_aggregate["issues"]),
					outer_cleanup_issue,
				],
			})
			gf_maintenance.validate_gut_shard_run_report(
				partial_schedule_deadline,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			partial_schedule_reverse = copy.deepcopy(partial_schedule_deadline)
			partial_schedule_reverse["issues"][1:3] = list(reversed(
				partial_schedule_reverse["issues"][1:3]
			))
			with self.assertRaisesRegex(ValueError, "single-worker result failure preceded"):
				gf_maintenance.validate_gut_shard_run_report(
					partial_schedule_reverse,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			candidate_cleanup_before_causes = copy.deepcopy(partial_schedule_deadline)
			candidate_cleanup_before_causes["issues"] = [
				candidate_cleanup_before_causes["issues"][3],
				*candidate_cleanup_before_causes["issues"][:3],
				*candidate_cleanup_before_causes["issues"][4:],
			]
			with self.assertRaisesRegex(ValueError, "workspace cleanup preceded"):
				gf_maintenance.validate_gut_shard_run_report(
					candidate_cleanup_before_causes,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			aggregate_before_candidate_cleanup = copy.deepcopy(partial_schedule_deadline)
			aggregate_before_candidate_cleanup["issues"] = [
				*aggregate_before_candidate_cleanup["issues"][:3],
				*copy.deepcopy(empty_aggregate["issues"]),
				candidate_cleanup_issue,
				outer_cleanup_issue,
			]
			with self.assertRaisesRegex(ValueError, "followed its derived"):
				gf_maintenance.validate_gut_shard_run_report(
					aggregate_before_candidate_cleanup,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			outer_cleanup_before_candidate = copy.deepcopy(partial_schedule_deadline)
			outer_cleanup_before_candidate["issues"] = [
				outer_cleanup_before_candidate["issues"][-1],
				*outer_cleanup_before_candidate["issues"][:-1],
			]
			with self.assertRaisesRegex(ValueError, "validation cleanup evidence did not follow"):
				gf_maintenance.validate_gut_shard_run_report(
					outer_cleanup_before_candidate,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			outer_cleanup_before_aggregate = copy.deepcopy(partial_schedule_deadline)
			outer_cleanup_before_aggregate["issues"] = [
				*outer_cleanup_before_aggregate["issues"][:4],
				outer_cleanup_issue,
				*copy.deepcopy(empty_aggregate["issues"]),
			]
			with self.assertRaisesRegex(ValueError, "validation cleanup evidence did not follow"):
				gf_maintenance.validate_gut_shard_run_report(
					outer_cleanup_before_aggregate,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			deadline_worker = self._failed_worker_report(
				all_reports[0]["request"],
				kind="worker_deadline_exhausted",
			)
			deadline_aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				[deadline_worker],
			)
			deadline_nested_issue = {
				"kind": deadline_worker["issues"][0]["kind"],
				"message": (
					f"{deadline_worker['request']['shard_name']}: "
					f"{deadline_worker['issues'][0]['message']}"
				),
			}
			derived_deadline_issue = {
				"kind": "gut_shard_worker_deadline_exhausted",
				"message": (
					f"{deadline_worker['request']['shard_name']}: worker-local deadline "
					"or phase timeout stopped the remaining shard schedule."
				),
			}
			wave_failure_issue = {
				"kind": "gut_shard_worker_wave_failed",
				"message": "synthetic failure while draining the worker wave",
			}
			schedule_failure_issue = {
				"kind": "gut_shard_worker_schedule_failed",
				"message": (
					f"{self.MANIFEST['shards'][1]['name']}: "
					"synthetic second submit failure"
				),
			}

			def derived_worker_failure_report(
				*,
				jobs: int,
				executed: int,
				worker: dict[str, object],
				aggregate: dict[str, object],
				causes: list[dict[str, str]],
				nested_issue: dict[str, str],
			) -> dict[str, object]:
				result = gf_maintenance.make_gut_shard_run_report(
					jobs=jobs,
					qualify=False,
				)
				result.update({
					"workspace_fingerprint": "1" * 64,
					"manifest_digest": manifest_digest,
					"inventory_digest": inventory_digest,
					"inventory_count": len(self.INVENTORY),
					"shard_count": len(self.MANIFEST["shards"]),
					"executed_shard_count": executed,
					"completed_shard_count": 1,
					"failed_shard_count": 1,
					"unreported_shard_count": executed - 1,
					"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - executed,
					"duration_seconds": 1.0,
					"isolation_probe": copy.deepcopy(
						too_many_worker_exceptions["isolation_probe"]
					),
					"shards": [worker],
					"aggregate": aggregate,
					"issues": [
						*copy.deepcopy(causes),
						candidate_cleanup_issue,
						copy.deepcopy(nested_issue),
						*copy.deepcopy(aggregate["issues"]),
						outer_cleanup_issue,
					],
				})
				return result

			for label, executed, causes in (
				(
					"schedule-before-derived-result",
					1,
					[schedule_failure_issue, derived_deadline_issue],
				),
				(
					"derived-result-before-wave-failure",
					2,
					[derived_deadline_issue, wave_failure_issue],
				),
			):
				derived_order = derived_worker_failure_report(
					jobs=2,
					executed=executed,
					worker=deadline_worker,
					aggregate=deadline_aggregate,
					causes=causes,
					nested_issue=deadline_nested_issue,
				)
				with self.subTest(label=label):
					gf_maintenance.validate_gut_shard_run_report(
						derived_order,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)
					reversed_derived_order = copy.deepcopy(derived_order)
					reversed_derived_order["issues"][:2] = list(reversed(
						reversed_derived_order["issues"][:2]
					))
					with self.assertRaisesRegex(ValueError, "did not precede|did not follow"):
						gf_maintenance.validate_gut_shard_run_report(
							reversed_derived_order,
							manifest=self.MANIFEST,
							inventory=self.INVENTORY,
							expected_workspace_fingerprint="1" * 64,
							expected_validation_root=workspace,
						)

			unowned_deadline_worker = copy.deepcopy(deadline_worker)
			unowned_deadline_worker.update({
				"process_boundary_quiescent": False,
				"workspace_cleanup_permitted": False,
				"continuation_safe": False,
			})
			unowned_deadline_aggregate = (
				gf_maintenance.aggregate_gut_shard_candidate_reports(
					self.MANIFEST,
					self.INVENTORY,
					[unowned_deadline_worker],
				)
			)
			ownership_issue = {
				"kind": "gut_shard_workspace_ownership_unproven",
				"message": (
					f"{unowned_deadline_worker['request']['shard_name']}: "
					"process-boundary, workspace ownership, or worker-owned cleanup "
					"was not proven; the validation workspace must be retained."
				),
			}
			parent_deadline_issue = {
				"kind": "gut_shard_worker_wave_deadline_exhausted",
				"message": "synthetic parent deadline before retained worker evidence",
			}
			single_worker_owned_debt = derived_worker_failure_report(
				jobs=1,
				executed=1,
				worker=unowned_deadline_worker,
				aggregate=unowned_deadline_aggregate,
				causes=[
					parent_deadline_issue,
					derived_deadline_issue,
					ownership_issue,
				],
				nested_issue=deadline_nested_issue,
			)
			gf_maintenance.validate_gut_shard_run_report(
				single_worker_owned_debt,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			for label, order in (
				("result-before-parent-deadline", [1, 0, 2]),
				("ownership-before-result", [0, 2, 1]),
			):
				forged_order = copy.deepcopy(single_worker_owned_debt)
				forged_order["issues"][:3] = [
					forged_order["issues"][index] for index in order
				]
				with self.subTest(label=label), self.assertRaisesRegex(
					ValueError,
					(
						"single-worker result failure preceded|ownership debt preceded|"
						"are not adjacent"
					),
				):
					gf_maintenance.validate_gut_shard_run_report(
						forged_order,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
							expected_validation_root=workspace,
						)

			fingerprint_issue = {
				"kind": "gut_shard_workspace_fingerprint_boundary_unproven",
				"message": (
					f"{self.MANIFEST['shards'][1]['name']}: "
					"synthetic early fingerprint boundary debt"
				),
			}
			fingerprint_then_retained_peer = derived_worker_failure_report(
				jobs=2,
				executed=2,
				worker=unowned_deadline_worker,
				aggregate=unowned_deadline_aggregate,
				causes=[
					fingerprint_issue,
					parent_deadline_issue,
					derived_deadline_issue,
					ownership_issue,
				],
				nested_issue=deadline_nested_issue,
			)
			gf_maintenance.validate_gut_shard_run_report(
				fingerprint_then_retained_peer,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			surplus_wave_failure = copy.deepcopy(fingerprint_then_retained_peer)
			surplus_wave_failure["issues"].insert(4, wave_failure_issue)
			with self.assertRaisesRegex(ValueError, "does not explain unresolved"):
				gf_maintenance.validate_gut_shard_run_report(
					surplus_wave_failure,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			fingerprint_without_peer_debt = derived_worker_failure_report(
				jobs=2,
				executed=2,
				worker=deadline_worker,
				aggregate=deadline_aggregate,
				causes=[
					fingerprint_issue,
					parent_deadline_issue,
					derived_deadline_issue,
				],
				nested_issue=deadline_nested_issue,
			)
			with self.assertRaisesRegex(ValueError, "lacks retained ownership debt"):
				gf_maintenance.validate_gut_shard_run_report(
					fingerprint_without_peer_debt,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			early_exception_issue = {
				"kind": "gut_shard_worker_exception",
				"message": (
					f"{self.MANIFEST['shards'][1]['name']}: "
					"synthetic early worker exception"
				),
			}
			for label, causes in (
				(
					"owned-result-before-peer-exception",
					[derived_deadline_issue, ownership_issue, early_exception_issue],
				),
				(
					"peer-exception-before-owned-result",
					[early_exception_issue, derived_deadline_issue, ownership_issue],
				),
			):
				adjacent_owned_result = derived_worker_failure_report(
					jobs=2,
					executed=2,
					worker=unowned_deadline_worker,
					aggregate=unowned_deadline_aggregate,
					causes=causes,
					nested_issue=deadline_nested_issue,
				)
				with self.subTest(label=label):
					gf_maintenance.validate_gut_shard_run_report(
						adjacent_owned_result,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)
			interleaved_owned_result = derived_worker_failure_report(
				jobs=2,
				executed=2,
				worker=unowned_deadline_worker,
				aggregate=unowned_deadline_aggregate,
				causes=[
					derived_deadline_issue,
					early_exception_issue,
					ownership_issue,
				],
				nested_issue=deadline_nested_issue,
			)
			with self.assertRaisesRegex(ValueError, "are not adjacent"):
				gf_maintenance.validate_gut_shard_run_report(
					interleaved_owned_result,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			safe_partial_aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				[all_reports[0]],
			)
			early_exception_with_safe_peer = gf_maintenance.make_gut_shard_run_report(
				jobs=2,
				qualify=False,
			)
			early_exception_with_safe_peer.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": manifest_digest,
				"inventory_digest": inventory_digest,
				"inventory_count": len(self.INVENTORY),
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": 2,
				"completed_shard_count": 1,
				"successful_shard_count": 1,
				"unreported_shard_count": 1,
				"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - 2,
				"duration_seconds": 1.0,
				"isolation_probe": copy.deepcopy(
					too_many_worker_exceptions["isolation_probe"]
				),
				"shards": [all_reports[0]],
				"aggregate": safe_partial_aggregate,
				"issues": [
					early_exception_issue,
					parent_deadline_issue,
					candidate_cleanup_issue,
					*copy.deepcopy(safe_partial_aggregate["issues"]),
					outer_cleanup_issue,
				],
			})
			with self.assertRaisesRegex(ValueError, "retained an unowned peer report"):
				gf_maintenance.validate_gut_shard_run_report(
					early_exception_with_safe_peer,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			deadline_then_late_exception = copy.deepcopy(early_exception_with_safe_peer)
			deadline_then_late_exception["issues"][:2] = list(reversed(
				deadline_then_late_exception["issues"][:2]
			))
			gf_maintenance.validate_gut_shard_run_report(
				deadline_then_late_exception,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)

			early_exception_with_missing_peer = copy.deepcopy(
				reachable_boundary_then_deadline
			)
			early_exception_with_missing_peer["issues"][0] = early_exception_issue
			gf_maintenance.validate_gut_shard_run_report(
				early_exception_with_missing_peer,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)

			early_exception_with_owned_peer = derived_worker_failure_report(
				jobs=2,
				executed=2,
				worker=unowned_deadline_worker,
				aggregate=unowned_deadline_aggregate,
				causes=[
					early_exception_issue,
					parent_deadline_issue,
					derived_deadline_issue,
					ownership_issue,
				],
				nested_issue=deadline_nested_issue,
			)
			gf_maintenance.validate_gut_shard_run_report(
				early_exception_with_owned_peer,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)

			first_exception_issue = {
				"kind": "gut_shard_worker_exception",
				"message": (
					f"{self.MANIFEST['shards'][0]['name']}: "
					"synthetic first worker exception"
				),
			}
			all_scoped_before_deadline = copy.deepcopy(
				early_exception_with_missing_peer
			)
			all_scoped_before_deadline["issues"] = [
				first_exception_issue,
				early_exception_issue,
				parent_deadline_issue,
				candidate_cleanup_issue,
				*copy.deepcopy(empty_aggregate["issues"]),
				outer_cleanup_issue,
			]
			with self.assertRaisesRegex(ValueError, "deadline lacks pending result"):
				gf_maintenance.validate_gut_shard_run_report(
					all_scoped_before_deadline,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			for label, prefix in (
				(
					"deadline-before-both-scoped-results",
					[parent_deadline_issue, first_exception_issue, early_exception_issue],
				),
				(
					"deadline-between-scoped-results",
					[first_exception_issue, parent_deadline_issue, early_exception_issue],
				),
			):
				reachable_scoped_deadline = copy.deepcopy(
					all_scoped_before_deadline
				)
				reachable_scoped_deadline["issues"][:3] = prefix
				with self.subTest(label=label):
					gf_maintenance.validate_gut_shard_run_report(
						reachable_scoped_deadline,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

			post_deadline_result_without_debt = derived_worker_failure_report(
				jobs=2,
				executed=2,
				worker=deadline_worker,
				aggregate=deadline_aggregate,
				causes=[parent_deadline_issue, derived_deadline_issue],
				nested_issue=deadline_nested_issue,
			)
			with self.assertRaisesRegex(ValueError, "result lacks ownership debt"):
				gf_maintenance.validate_gut_shard_run_report(
					post_deadline_result_without_debt,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			pre_deadline_result_without_debt = copy.deepcopy(
				post_deadline_result_without_debt
			)
			pre_deadline_result_without_debt["issues"][:2] = list(reversed(
				pre_deadline_result_without_debt["issues"][:2]
			))
			gf_maintenance.validate_gut_shard_run_report(
				pre_deadline_result_without_debt,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)

			straddled_result_ownership = derived_worker_failure_report(
				jobs=2,
				executed=2,
				worker=unowned_deadline_worker,
				aggregate=unowned_deadline_aggregate,
				causes=[
					derived_deadline_issue,
					parent_deadline_issue,
					ownership_issue,
				],
				nested_issue=deadline_nested_issue,
			)
			with self.assertRaisesRegex(
				ValueError,
				"straddle its wave deadline|are not adjacent",
			):
				gf_maintenance.validate_gut_shard_run_report(
					straddled_result_ownership,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			for label, prefix in (
				(
					"result-and-ownership-before-deadline",
					[derived_deadline_issue, ownership_issue, parent_deadline_issue],
				),
				(
					"result-and-ownership-after-deadline",
					[parent_deadline_issue, derived_deadline_issue, ownership_issue],
				),
			):
				reachable_owned_deadline = copy.deepcopy(straddled_result_ownership)
				reachable_owned_deadline["issues"][:3] = prefix
				with self.subTest(label=label):
					gf_maintenance.validate_gut_shard_run_report(
						reachable_owned_deadline,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
							expected_validation_root=workspace,
					)

			two_report_owned_aggregate = (
				gf_maintenance.aggregate_gut_shard_candidate_reports(
					self.MANIFEST,
					self.INVENTORY,
					[unowned_deadline_worker, all_reports[1]],
				)
			)
			completed_owned_wave = gf_maintenance.make_gut_shard_run_report(
				jobs=2,
				qualify=False,
			)
			completed_owned_wave.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": manifest_digest,
				"inventory_digest": inventory_digest,
				"inventory_count": len(self.INVENTORY),
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": 2,
				"completed_shard_count": 2,
				"successful_shard_count": 1,
				"failed_shard_count": 1,
				"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - 2,
				"duration_seconds": 1.0,
				"isolation_probe": copy.deepcopy(
					too_many_worker_exceptions["isolation_probe"]
				),
				"shards": [unowned_deadline_worker, all_reports[1]],
				"aggregate": two_report_owned_aggregate,
				"issues": [
					derived_deadline_issue,
					ownership_issue,
					parent_deadline_issue,
					candidate_cleanup_issue,
					deadline_nested_issue,
					*copy.deepcopy(two_report_owned_aggregate["issues"]),
					outer_cleanup_issue,
				],
			})
			with self.assertRaisesRegex(ValueError, "deadline lacks pending result"):
				gf_maintenance.validate_gut_shard_run_report(
					completed_owned_wave,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			deadline_then_completed_owned_wave = copy.deepcopy(completed_owned_wave)
			deadline_then_completed_owned_wave["issues"][:3] = [
				parent_deadline_issue,
				derived_deadline_issue,
				ownership_issue,
			]
			gf_maintenance.validate_gut_shard_run_report(
				deadline_then_completed_owned_wave,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)

	def test_top_report_validator_binds_control_and_equivalence_to_completed_candidates(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			all_reports = self._candidate_worker_reports(workspace)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				all_reports,
			)
			control = self._control_worker_report(workspace)
			equivalence = gf_maintenance.compare_gut_shard_qualification(
				aggregate,
				control,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				candidate_reports=all_reports,
			)
			manifest_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				self.MANIFEST
			)
			inventory_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				list(self.INVENTORY)
			)
			qualified = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=True)
			qualified.update({
				"ok": True,
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": manifest_digest,
				"inventory_digest": inventory_digest,
				"inventory_count": len(self.INVENTORY),
				"candidate_eligible": True,
				"qualified": True,
				"qualification_status": "qualified",
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": len(all_reports),
				"completed_shard_count": len(all_reports),
				"successful_shard_count": len(all_reports),
				"duration_seconds": 1.0,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"shards": all_reports,
				"aggregate": aggregate,
				"control": control,
				"equivalence": equivalence,
			})
			gf_maintenance.validate_gut_shard_run_report(
				qualified,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)

			failed_control = self._failed_worker_report(control["request"])
			for primary_kind, cleanup_scope in (
				("gut_shard_control_workspace_acquisition_failed", "outer"),
				("gut_shard_control_deadline_exhausted", "inner"),
				("gut_shard_control_report_rejected", "inner"),
				("gut_shard_control_report_missing", "none"),
			):
				retained_control = copy.deepcopy(qualified)
				cleanup_issues = []
				if cleanup_scope == "inner":
					cleanup_issues.append(
						{
							"kind": "gut_shard_control_cleanup_failed",
							"message": "synthetic retained control root",
						}
					)
				if cleanup_scope != "none":
					cleanup_issues.append(
						{
							"kind": "gut_shard_validation_cleanup_failed",
							"message": "synthetic retained validation root",
						}
					)
				retained_control.update({
					"ok": False,
					"candidate_eligible": cleanup_scope == "none",
					"qualified": False,
					"qualification_status": (
						"cleanup_failed" if cleanup_scope != "none" else "control_ineligible"
					),
					"control": copy.deepcopy(failed_control),
					"equivalence": None,
					"issues": [
						*[
							{
								"kind": issue["kind"],
								"message": issue["message"],
							}
							for issue in failed_control["issues"]
						],
						{
							"kind": primary_kind,
							"message": "synthetic primary control failure",
						},
						*cleanup_issues,
					],
				})
				with self.subTest(primary_kind=primary_kind), self.assertRaisesRegex(
					ValueError,
					"control primary failure retained a control report",
				):
					gf_maintenance.validate_gut_shard_run_report(
						retained_control,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

			deadline_control = self._failed_worker_report(
				control["request"],
				kind="worker_deadline_exhausted",
			)
			derived_control_deadline_issue = {
				"kind": "gut_shard_control_worker_failed",
				"message": (
					"gut_shard_worker_deadline_exhausted: "
					f"{gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME}: "
					"worker-local deadline or phase timeout stopped the remaining "
					"shard schedule."
				),
			}
			nested_control_deadline_issue = {
				"kind": deadline_control["issues"][0]["kind"],
				"message": deadline_control["issues"][0]["message"],
			}
			retained_deadline_control = copy.deepcopy(qualified)
			retained_deadline_control.update({
				"ok": False,
				"candidate_eligible": True,
				"qualified": False,
				"qualification_status": "control_ineligible",
				"control": deadline_control,
				"equivalence": None,
				"issues": [
					derived_control_deadline_issue,
					nested_control_deadline_issue,
				],
			})
			gf_maintenance.validate_gut_shard_run_report(
				retained_deadline_control,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			reversed_deadline_control = copy.deepcopy(retained_deadline_control)
			reversed_deadline_control["issues"].reverse()
			with self.assertRaisesRegex(ValueError, "followed its nested control evidence"):
				gf_maintenance.validate_gut_shard_run_report(
					reversed_deadline_control,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			ineligible_candidate_reports = copy.deepcopy(all_reports)
			ineligible_candidate_reports[0] = self._failed_worker_report(
				all_reports[0]["request"]
			)
			ineligible_aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				ineligible_candidate_reports,
			)
			candidate_worker_issue = ineligible_candidate_reports[0]["issues"][0]
			candidate_nested_issue = {
				"kind": candidate_worker_issue["kind"],
				"message": (
					f"{self.MANIFEST['shards'][0]['name']}: "
					f"{candidate_worker_issue['message']}"
				),
			}
			control_missing_issue = {
				"kind": "gut_shard_control_report_missing",
				"message": "synthetic missing control report",
			}
			candidate_ineligible_control_missing = copy.deepcopy(qualified)
			candidate_ineligible_control_missing.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "control_ineligible",
				"successful_shard_count": len(all_reports) - 1,
				"failed_shard_count": 1,
				"shards": ineligible_candidate_reports,
				"aggregate": ineligible_aggregate,
				"control": None,
				"equivalence": None,
				"issues": [
					candidate_nested_issue,
					*copy.deepcopy(ineligible_aggregate["issues"]),
					control_missing_issue,
				],
			})
			gf_maintenance.validate_gut_shard_run_report(
				candidate_ineligible_control_missing,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			control_before_candidate_nested = copy.deepcopy(
				candidate_ineligible_control_missing
			)
			control_before_candidate_nested["issues"] = [
				control_missing_issue,
				candidate_nested_issue,
				*copy.deepcopy(ineligible_aggregate["issues"]),
			]
			with self.assertRaisesRegex(ValueError, "preceded candidate nested evidence"):
				gf_maintenance.validate_gut_shard_run_report(
					control_before_candidate_nested,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			failed_control_nested_issue = {
				"kind": failed_control["issues"][0]["kind"],
				"message": failed_control["issues"][0]["message"],
			}
			final_drift_issue = {
				"kind": "gut_shard_final_source_drift",
				"message": "synthetic final source drift",
			}
			final_cleanup_issue = {
				"kind": "gut_shard_validation_cleanup_failed",
				"message": "synthetic retained validation root",
			}
			control_failure_then_final_drift = copy.deepcopy(qualified)
			control_failure_then_final_drift.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "cleanup_failed",
				"control": failed_control,
				"equivalence": None,
				"issues": [
					failed_control_nested_issue,
					final_drift_issue,
					final_cleanup_issue,
				],
			})
			gf_maintenance.validate_gut_shard_run_report(
				control_failure_then_final_drift,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			final_before_control_nested = copy.deepcopy(control_failure_then_final_drift)
			final_before_control_nested["issues"][:2] = list(reversed(
				final_before_control_nested["issues"][:2]
			))
			with self.assertRaisesRegex(ValueError, "final-proof evidence preceded"):
				gf_maintenance.validate_gut_shard_run_report(
					final_before_control_nested,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			legacy_control_budget = copy.deepcopy(qualified)
			legacy_control_budget["control_gut_timeout_seconds"] = 600
			legacy_control_budget["total_timeout_seconds"] = 8220
			legacy_control_request = legacy_control_budget["control"]["request"]
			legacy_control_request["gut_timeout_seconds"] = 600
			legacy_control_request["remaining_seconds"] = 1320.0
			legacy_control_budget["control"]["request_digest"] = (
				gf_maintenance.gf_gut_shard_worker.canonical_digest(
					legacy_control_request
				)
			)
			with self.assertRaisesRegex(ValueError, "timeout policy"):
				gf_maintenance.validate_gut_shard_run_report(
					legacy_control_budget,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			missing_control_stage = copy.deepcopy(qualified)
			missing_control_stage.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "cleanup_failed",
				"control": None,
				"equivalence": None,
				"issues": [
					{
						"kind": "gut_shard_final_source_drift",
						"message": "synthetic final drift without control stage",
					},
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained root",
					},
				],
			})
			with self.assertRaisesRegex(ValueError, "omitted its reached control stage"):
				gf_maintenance.validate_gut_shard_run_report(
					missing_control_stage,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			missing_equivalence = copy.deepcopy(qualified)
			missing_equivalence.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "cleanup_failed",
				"equivalence": None,
				"issues": [
					{
						"kind": "gut_shard_final_source_drift",
						"message": "synthetic final drift",
					},
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained root",
					},
				],
			})
			with self.assertRaisesRegex(ValueError, "equivalence presence"):
				gf_maintenance.validate_gut_shard_run_report(
					missing_equivalence,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			final_runtime_mismatch = copy.deepcopy(qualified)
			final_runtime_mismatch.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "infrastructure_failed",
				"issues": [{
					"kind": "gut_shard_runtime_source_mismatch",
					"message": "synthetic final loaded-source mismatch",
				}],
			})
			with self.assertRaisesRegex(ValueError, "final source-proof failure"):
				gf_maintenance.validate_gut_shard_run_report(
					final_runtime_mismatch,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			multiple_final_causes = copy.deepcopy(qualified)
			multiple_final_causes.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "cleanup_failed",
				"issues": [
					{
						"kind": "gut_shard_final_infrastructure_failed",
						"message": "synthetic final infrastructure root cause",
					},
					{
						"kind": "gut_shard_final_source_drift",
						"message": "synthetic impossible second final root cause",
					},
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained validation root",
					},
				],
			})
			with self.assertRaisesRegex(ValueError, "mutually exclusive root causes"):
				gf_maintenance.validate_gut_shard_run_report(
					multiple_final_causes,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			multiple_control_causes = copy.deepcopy(qualified)
			multiple_control_causes.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "cleanup_failed",
				"control": None,
				"equivalence": None,
				"issues": [
					{
						"kind": "gut_shard_control_deadline_exhausted",
						"message": "synthetic control deadline",
					},
					{
						"kind": "gut_shard_control_report_rejected",
						"message": "synthetic impossible second control cause",
					},
					{
						"kind": "gut_shard_control_cleanup_failed",
						"message": "synthetic retained control root",
					},
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained validation root",
					},
				],
			})
			with self.assertRaisesRegex(ValueError, "mutually exclusive primary failures"):
				gf_maintenance.validate_gut_shard_run_report(
					multiple_control_causes,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			control_primary_with_worker = copy.deepcopy(multiple_control_causes)
			control_primary_with_worker["issues"][1] = {
				"kind": "gut_shard_control_worker_failed",
				"message": (
					"gut_shard_worker_exception: "
					f"{gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME}: "
					"synthetic worker failure"
				),
			}
			with self.assertRaisesRegex(ValueError, "cannot follow worker-wave"):
				gf_maintenance.validate_gut_shard_run_report(
					control_primary_with_worker,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			for worker_prefixes in (
				(
					"gut_shard_worker_schedule_failed",
					"gut_shard_worker_exception",
				),
				(
					"gut_shard_worker_wave_failed",
					"gut_shard_worker_exception",
				),
				(
					"gut_shard_worker_schedule_failed",
					"gut_shard_worker_wave_deadline_exhausted",
				),
				(
					"gut_shard_worker_wave_deadline_exhausted",
					"gut_shard_worker_infrastructure_failed",
				),
				(
					"gut_shard_worker_wave_deadline_exhausted",
					"gut_shard_workspace_fingerprint_boundary_unproven",
				),
			):
				impossible_control_wave = copy.deepcopy(qualified)
				worker_issues = []
				for prefix in worker_prefixes:
					detail = "synthetic single-worker failure"
					if prefix not in {
						"gut_shard_worker_wave_failed",
						"gut_shard_worker_wave_deadline_exhausted",
					}:
						detail = (
							f"{gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME}: "
							f"{detail}"
						)
					worker_issues.append({
						"kind": "gut_shard_control_worker_failed",
						"message": f"{prefix}: {detail}",
					})
				impossible_control_wave.update({
					"ok": False,
					"candidate_eligible": False,
					"qualified": False,
					"qualification_status": "cleanup_failed",
					"control": None,
					"equivalence": None,
					"issues": [
						*worker_issues,
						{
							"kind": "gut_shard_control_cleanup_failed",
							"message": "synthetic retained control root",
						},
						{
							"kind": "gut_shard_validation_cleanup_failed",
							"message": "synthetic retained validation root",
						},
					],
				})
				with self.subTest(worker_prefixes=worker_prefixes), self.assertRaisesRegex(
					ValueError,
					"mutually exclusive single-worker causes",
				):
					gf_maintenance.validate_gut_shard_run_report(
						impossible_control_wave,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

			reachable_deadline_ownership = copy.deepcopy(impossible_control_wave)
			reachable_deadline_ownership["issues"] = [
				{
					"kind": "gut_shard_control_worker_failed",
					"message": (
						"gut_shard_worker_wave_deadline_exhausted: "
						"synthetic parent deadline"
					),
				},
				{
					"kind": "gut_shard_control_worker_failed",
					"message": (
						"gut_shard_worker_infrastructure_failed: "
						f"{gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME}: "
						"synthetic unsafe report"
					),
				},
				{
					"kind": "gut_shard_control_worker_failed",
					"message": (
						"gut_shard_workspace_ownership_unproven: "
						f"{gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME}: "
						"synthetic retained workspace"
					),
				},
				{
					"kind": "gut_shard_control_cleanup_failed",
					"message": "synthetic retained control root",
				},
				{
					"kind": "gut_shard_validation_cleanup_failed",
					"message": "synthetic retained validation root",
				},
			]
			validated_deadline_ownership = gf_maintenance.validate_gut_shard_run_report(
				reachable_deadline_ownership,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			self.assertEqual(
				validated_deadline_ownership["qualification_status"],
				"cleanup_failed",
			)

			def control_failure_report(
				issues: list[dict[str, str]],
			) -> dict[str, object]:
				result = copy.deepcopy(qualified)
				result.update({
					"ok": False,
					"candidate_eligible": False,
					"qualified": False,
					"qualification_status": "cleanup_failed",
					"control": None,
					"equivalence": None,
					"issues": copy.deepcopy(issues),
				})
				return result

			control_cleanup_issues = [
				{
					"kind": "gut_shard_control_cleanup_failed",
					"message": "synthetic retained control root",
				},
				{
					"kind": "gut_shard_validation_cleanup_failed",
					"message": "synthetic retained validation root",
				},
			]
			control_deadline_issue = {
				"kind": "gut_shard_control_worker_failed",
				"message": (
					"gut_shard_worker_wave_deadline_exhausted: "
					"synthetic parent deadline"
				),
			}
			control_wave_failure_issue = {
				"kind": "gut_shard_control_worker_failed",
				"message": "gut_shard_worker_wave_failed: synthetic outer wave failure",
			}
			reachable_deadline_then_wave_failure = control_failure_report([
				control_deadline_issue,
				control_wave_failure_issue,
				*control_cleanup_issues,
			])
			gf_maintenance.validate_gut_shard_run_report(
				reachable_deadline_then_wave_failure,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)

			control_exception_issue = {
				"kind": "gut_shard_control_worker_failed",
				"message": (
					"gut_shard_worker_exception: "
					f"{gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME}: "
					"synthetic worker exception"
				),
			}
			control_rejected_issue = {
				"kind": "gut_shard_control_worker_failed",
				"message": (
					"gut_shard_worker_report_rejected: "
					f"{gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME}: "
					"synthetic rejected report"
				),
			}
			control_infrastructure_issue = {
				"kind": "gut_shard_control_worker_failed",
				"message": (
					"gut_shard_worker_infrastructure_failed: "
					f"{gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME}: "
					"synthetic unsafe report"
				),
			}
			control_ownership_issue = {
				"kind": "gut_shard_control_worker_failed",
				"message": (
					"gut_shard_workspace_ownership_unproven: "
					f"{gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME}: "
					"synthetic retained workspace"
				),
			}
			for label, issues, expected_message in (
				(
					"wave-failure-before-deadline",
					[
						control_wave_failure_issue,
						control_deadline_issue,
						*control_cleanup_issues,
					],
					"deadline did not precede|failure did not follow",
				),
				(
					"exception-before-deadline",
					[
						control_exception_issue,
						control_deadline_issue,
						*control_cleanup_issues,
					],
					"deadline did not precede",
				),
				(
					"rejection-before-deadline",
					[
						control_rejected_issue,
						control_deadline_issue,
						*control_cleanup_issues,
					],
					"deadline did not precede",
				),
				(
					"ownership-before-result",
					[
						control_ownership_issue,
						control_infrastructure_issue,
						*control_cleanup_issues,
					],
					"ownership debt preceded",
				),
				(
					"control-cleanup-before-worker",
					[
						control_cleanup_issues[0],
						control_exception_issue,
						control_cleanup_issues[1],
					],
					"control cleanup evidence preceded",
				),
				(
					"outer-cleanup-before-worker",
					[
						control_cleanup_issues[1],
						control_exception_issue,
						control_cleanup_issues[0],
					],
					"validation cleanup evidence did not follow",
				),
				(
					"primary-after-control-cleanup",
					[
						control_cleanup_issues[0],
						{
							"kind": "gut_shard_control_report_rejected",
							"message": "synthetic rejected control",
						},
						control_cleanup_issues[1],
					],
					"control cleanup evidence preceded",
				),
				(
					"outer-cleanup-before-primary-cleanup",
					[
						{
							"kind": "gut_shard_control_report_rejected",
							"message": "synthetic rejected control",
						},
						control_cleanup_issues[1],
						control_cleanup_issues[0],
					],
					"validation cleanup evidence did not follow",
				),
			):
				with self.subTest(label=label), self.assertRaisesRegex(
					ValueError,
					expected_message,
				):
					gf_maintenance.validate_gut_shard_run_report(
						control_failure_report(issues),
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

			final_infrastructure_failure = copy.deepcopy(qualified)
			final_infrastructure_failure.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "infrastructure_failed",
				"issues": [{
					"kind": "gut_shard_final_infrastructure_failed",
					"message": "synthetic final proof infrastructure failure",
				}],
			})
			with self.assertRaisesRegex(ValueError, "final source-proof failure"):
				gf_maintenance.validate_gut_shard_run_report(
					final_infrastructure_failure,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			partial_reports = all_reports[:2]
			partial_aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				partial_reports,
			)
			partial_with_control = copy.deepcopy(qualified)
			partial_with_control.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "cleanup_failed",
				"executed_shard_count": 2,
				"completed_shard_count": 2,
				"successful_shard_count": 2,
				"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - 2,
				"shards": partial_reports,
				"aggregate": partial_aggregate,
				"equivalence": None,
				"issues": [
					{
						"kind": "gut_shard_candidate_scheduling_deadline_exhausted",
						"message": "synthetic candidate deadline",
					},
					*copy.deepcopy(partial_aggregate["issues"]),
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained candidate root",
					},
				],
			})
			with self.assertRaisesRegex(ValueError, "candidate-phase stop retained control"):
				gf_maintenance.validate_gut_shard_run_report(
					partial_with_control,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			unowned_control = self._failed_worker_report(control["request"])
			unowned_control.update({
				"process_boundary_quiescent": False,
				"workspace_cleanup_permitted": False,
				"continuation_safe": False,
			})
			forged_unowned_control = copy.deepcopy(qualified)
			forged_unowned_control.update({
				"ok": False,
				"qualified": False,
				"qualification_status": "control_ineligible",
				"control": unowned_control,
				"equivalence": None,
				"issues": [{
					"kind": issue["kind"],
					"message": issue["message"],
				} for issue in unowned_control["issues"]],
			})
			with self.assertRaisesRegex(ValueError, "control evidence retained unproven"):
				gf_maintenance.validate_gut_shard_run_report(
					forged_unowned_control,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			failed_control = self._failed_worker_report(control["request"])
			control_retained_after_cleanup = copy.deepcopy(qualified)
			control_retained_after_cleanup.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "cleanup_failed",
				"control": failed_control,
				"equivalence": None,
				"issues": [
					{
						"kind": "gut_shard_control_cleanup_failed",
						"message": "synthetic retained control root",
					},
					*[{
						"kind": issue["kind"],
						"message": issue["message"],
					} for issue in failed_control["issues"]],
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained validation root",
					},
				],
			})
			with self.assertRaisesRegex(ValueError, "retained a control report"):
				gf_maintenance.validate_gut_shard_run_report(
					control_retained_after_cleanup,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

	def test_top_report_validator_requires_nested_failure_issue_subsequence(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			candidate_workspace = workspace / "candidate-0"
			candidate_workspace.mkdir()
			manifest_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				self.MANIFEST
			)
			inventory_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				list(self.INVENTORY)
			)
			request = gf_maintenance.make_gut_shard_worker_request(
				self.MANIFEST["shards"][0],
				candidate_workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest=manifest_digest,
				inventory_digest=inventory_digest,
				remaining_seconds=float(
					gf_maintenance.gut_shard_worker_total_timeout_seconds(
						gf_maintenance.resolve_check_timeout_seconds("godot_import", None),
						gf_maintenance.resolve_gut_shard_run_gut_timeout_seconds(None),
					)
				),
				import_timeout_seconds=gf_maintenance.resolve_check_timeout_seconds(
					"godot_import", None
				),
				gut_timeout_seconds=(
					gf_maintenance.resolve_gut_shard_run_gut_timeout_seconds(None)
				),
			)
			failed_worker = self._failed_worker_report(request)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				[failed_worker],
			)
			worker_issue = failed_worker["issues"][0]
			derived_issue = {
				"kind": worker_issue["kind"],
				"message": (
					f"{request['shard_name']}: {worker_issue['message']}".rstrip()
				),
			}
			report = gf_maintenance.make_gut_shard_run_report(
				jobs=2,
				qualify=False,
			)
			report.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": manifest_digest,
				"inventory_digest": inventory_digest,
				"inventory_count": len(self.INVENTORY),
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": 2,
				"completed_shard_count": 1,
				"failed_shard_count": 1,
				"unreported_shard_count": 1,
				"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - 2,
				"duration_seconds": 0.1,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"shards": [failed_worker],
				"aggregate": aggregate,
				"issues": [
					{
						"kind": "gut_shard_worker_exception",
						"message": (
							f"{self.MANIFEST['shards'][1]['name']}: "
							"synthetic peer worker failure"
						),
					},
					{
						"kind": "gut_shard_workspace_cleanup_failed",
						"message": "synthetic retained candidate batch",
					},
					derived_issue,
					*copy.deepcopy(aggregate["issues"]),
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained validation root",
					},
				],
			})
			gf_maintenance.validate_gut_shard_run_report(
				report,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			early_nested_issue = copy.deepcopy(report)
			early_nested_issue["issues"][1:3] = list(reversed(
				early_nested_issue["issues"][1:3]
			))
			with self.assertRaisesRegex(ValueError, "followed its derived candidate"):
				gf_maintenance.validate_gut_shard_run_report(
					early_nested_issue,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			forged = copy.deepcopy(report)
			forged["issues"] = [{
				"kind": "gut_shard_unrelated_failure",
				"message": "unrelated orchestrator issue",
			}]
			with self.assertRaisesRegex(ValueError, "omit derived nested evidence"):
				gf_maintenance.validate_gut_shard_run_report(
					forged,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

	def test_top_report_validator_binds_context_even_for_failure_reports(self) -> None:
		report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=False)
		report.update({
			"workspace_fingerprint": "1" * 64,
			"manifest_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
				self.MANIFEST
			),
			"inventory_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
				list(self.INVENTORY)
			),
			"inventory_count": len(self.INVENTORY),
			"shard_count": len(self.MANIFEST["shards"]),
			"not_scheduled_shard_count": len(self.MANIFEST["shards"]),
			"duration_seconds": 0.1,
			"issues": [{
				"kind": "gut_shard_run_setup_failed",
				"message": "fixture",
			}],
		})
		gf_maintenance.validate_gut_shard_run_report(
			report,
			manifest=self.MANIFEST,
			inventory=self.INVENTORY,
			expected_workspace_fingerprint="1" * 64,
		)
		with self.assertRaisesRegex(ValueError, "requires manifest and inventory"):
			gf_maintenance.validate_gut_shard_run_report(
				report,
				expected_workspace_fingerprint="1" * 64,
			)
		for field, value in (
			("workspace_fingerprint", "2" * 64),
			("manifest_digest", "2" * 64),
			("inventory_digest", "3" * 64),
			("inventory_count", 999),
			("shard_count", 1),
			("runtime_source_digest", "4" * 64),
		):
			forged = copy.deepcopy(report)
			forged[field] = value
			if field == "shard_count":
				forged["not_scheduled_shard_count"] = value
			with self.subTest(field=field), self.assertRaises(ValueError):
				gf_maintenance.validate_gut_shard_run_report(
					forged,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
				)

	def test_renderer_keeps_candidate_and_evidence_status_distinct(self) -> None:
		report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=False)
		report.update({
			"manifest_digest": "a" * 64,
			"inventory_digest": "b" * 64,
			"inventory_count": 2,
			"shard_count": 2,
		})
		text = gf_maintenance_rendering.render_gut_shard_run_text(report)
		self.assertIn("candidate_eligible=False qualified=False", text)
		self.assertIn("authoritative=False merge_evidence=False", text)
		self.assertIn(f"runtime_source={report['runtime_source_digest']}", text)
		self.assertIn("skips=0 cache_reads=0 cache_writes=0 reuse=0", text)


class WorkspaceExecutionBoundaryTests(unittest.TestCase):
	def test_parallel_shard_freezes_and_materializes_environment_by_value(
		self,
	) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory).resolve()
			owned_environment = {
				"PATH": "frozen-parallel-path",
				"FROZEN_MARKER": "captured",
			}
			shard = gf_maintenance.ParallelShard(
				name="environment-snapshot",
				command=(str(Path(sys.executable).resolve()), "--version"),
				workspace=workspace,
				timeout_seconds=10.0,
				environment=owned_environment,
			)
			owned_environment["FROZEN_MARKER"] = "late-owner-mutation"
			owned_environment["OWNER_ONLY"] = "must-not-leak"
			assert shard.environment is not None
			with self.assertRaises(TypeError):
				shard.environment["LATE_MUTATION"] = "blocked"  # type: ignore[index]

			quiet_result = (
				gf_maintenance.gf_process_supervisor.SupervisedProcessResult(
					return_code=0,
					stdout="",
					stderr="",
					timed_out=False,
					duration_seconds=0.1,
					pid=101,
					process_boundary_quiescent=True,
				)
			)
			with mock.patch.dict(
				gf_maintenance.os.environ,
				{"AMBIENT_ONLY": "must-not-leak"},
				clear=True,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"run_supervised_process",
				return_value=quiet_result,
			) as supervisor:
				result = gf_maintenance.gf_parallel_validation._run_parallel_shard(  # noqa: SLF001
					shard,
					gf_maintenance.gf_parallel_validation._CancellationState(),  # noqa: SLF001
					None,
					None,
				)

		self.assertTrue(result.ok)
		dispatch_environment = supervisor.call_args.kwargs["environment"]
		self.assertIsNot(dispatch_environment, owned_environment)
		self.assertIsNot(dispatch_environment, shard.environment)
		self.assertEqual(dispatch_environment, dict(shard.environment))
		self.assertEqual(dispatch_environment["FROZEN_MARKER"], "captured")
		self.assertNotIn("OWNER_ONLY", dispatch_environment)
		self.assertNotIn("AMBIENT_ONLY", dispatch_environment)
		self.assertEqual(supervisor.call_args.kwargs["cwd"], shard.workspace)
		self.assertTrue(Path(supervisor.call_args.args[0][0]).is_absolute())

	def test_parallel_command_projection_uses_captured_executor_authority(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory).resolve()
			catalog = gf_maintenance._VALIDATION_CATALOG
			resolved_executable = str(workspace / "resolved-godot")

			def resolve(
				command: list[str],
				**_kwargs: object,
			) -> gf_maintenance.CommandIdentity:
				return gf_maintenance.CommandIdentity(
					declared=tuple(command),
					effective=(resolved_executable, *command[1:]),
				)

			with mock.patch.object(
				gf_maintenance,
				"resolve_command_identity",
				side_effect=resolve,
			) as resolver:
				contract = gf_maintenance.freeze_parallel_shard_command_contract(
					["godot_import"],
					authority_catalog=catalog,
					environment={},
					workspace=workspace,
					package_artifact_manifest="",
					package_artifact_manifest_sha256="",
				)

			resolver.assert_called_once()
			self.assertEqual(
				contract.identities["godot_import"].effective[0],
				resolved_executable,
			)

	def test_parallel_command_contract_freezes_generic_executable_identity(
		self,
	) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory).resolve()
			workspace = root / "workspace"
			tool_root = root / "tools"
			workspace.mkdir()
			tool_root.mkdir()
			git_name = "git.exe" if os.name == "nt" else "git"
			git_path = tool_root / git_name
			git_path.write_bytes(b"fixture")
			if os.name != "nt":
				git_path.chmod(0o755)

			contract = gf_maintenance.freeze_parallel_shard_command_contract(
				["diff"],
				authority_catalog=gf_maintenance._VALIDATION_CATALOG,
				environment={
					"PATH": str(tool_root),
					"PATHEXT": ".EXE",
				},
				workspace=workspace,
				package_artifact_manifest="",
				package_artifact_manifest_sha256="",
			)

		identity = contract.identities["diff"]
		self.assertEqual(identity.declared, ("git", "diff", "--check"))
		self.assertEqual(
			identity.effective,
			(str(git_path.resolve()), "diff", "--check"),
		)

	def test_parallel_windows_mixed_case_godot_pin_remains_resolvable(
		self,
	) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory).resolve()
			workspace = root / "workspace"
			workspace.mkdir()
			godot_path = root / "fixture-godot.exe"
			godot_path.write_bytes(b"fixture")
			if os.name != "nt":
				godot_path.chmod(0o755)
			mixed_name = "gF_GoDoT_ExEcUtAbLe"
			mixed_user_home = "gOdOt_UsEr_HoMe"
			base_environment = {
				mixed_name: str(godot_path),
				mixed_user_home: str(root / "ambient-user-home"),
				"PATH": "",
				"PATHEXT": ".EXE",
			}
			if os.name == "nt":
				isolated_names = (
					"APPDATA",
					"LOCALAPPDATA",
					"TMPDIR",
					"TEMP",
					"TMP",
					"PYTHONUTF8",
				)
			elif sys.platform == "darwin":
				isolated_names = (
					"HOME",
					"TMPDIR",
					"TEMP",
					"TMP",
					"PYTHONUTF8",
				)
			else:
				isolated_names = (
					"HOME",
					"XDG_DATA_HOME",
					"XDG_CONFIG_HOME",
					"XDG_CACHE_HOME",
					"TMPDIR",
					"TEMP",
					"TMP",
					"PYTHONUTF8",
				)
			for isolated_name in isolated_names:
				base_environment[isolated_name.swapcase()] = "ambient-private-value"
			original_environment = dict(base_environment)
			real_resolver = gf_godot_process.resolve_godot_executable
			real_setter = gf_executable_resolution.set_owned_environment_value
			real_remover = gf_executable_resolution.remove_owned_environment_value

			def resolve_as_windows(
				configured: str = "godot",
				*,
				environment: dict[str, str],
				cwd: Path,
				platform_name: str | None = None,
			) -> str:
				return real_resolver(
					configured,
					environment=environment,
					cwd=cwd,
					platform_name="nt",
				)

			def set_as_windows(
				environment: dict[str, str],
				name: str,
				value: str,
				*,
				platform_name: str | None = None,
			) -> None:
				real_setter(
					environment,
					name,
					value,
					platform_name="nt",
				)

			def remove_as_windows(
				environment: dict[str, str],
				name: str,
				*,
				platform_name: str | None = None,
			) -> None:
				real_remover(
					environment,
					name,
					platform_name="nt",
				)

			with mock.patch.object(
				gf_maintenance,
				"resolve_godot_executable",
				side_effect=resolve_as_windows,
			), mock.patch.object(
				gf_maintenance,
				"set_owned_environment_value",
				side_effect=set_as_windows,
			), mock.patch.object(
				gf_maintenance,
				"remove_owned_environment_value",
				side_effect=remove_as_windows,
			):
				environment, _private_root = (
					gf_maintenance.parallel_shard_environment(
						workspace,
						root / "private",
						base_environment=base_environment,
					)
				)

			self.assertEqual(base_environment, original_environment)
			self.assertFalse(any(
				key.casefold() == "GODOT_USER_HOME".casefold()
				for key in environment
			))
			for isolated_name in isolated_names:
				self.assertEqual(
					[
						key
						for key in environment
						if key.casefold() == isolated_name.casefold()
					],
					[isolated_name],
				)
				if isolated_name != "PYTHONUTF8":
					self.assertTrue(
						environment[isolated_name].startswith(str(root / "private")),
					)
			self.assertEqual(
				[
					key
					for key in environment
					if key.casefold()
					== gf_maintenance.GODOT_EXECUTABLE_ENV_VAR.casefold()
				],
				[gf_maintenance.GODOT_EXECUTABLE_ENV_VAR],
			)
			self.assertEqual(
				real_resolver(
					environment=environment,
					cwd=workspace,
					platform_name="nt",
				),
				str(godot_path.resolve()),
			)
			contract = gf_maintenance.freeze_parallel_shard_command_contract(
				["godot_import"],
				authority_catalog=gf_maintenance._VALIDATION_CATALOG,
				environment=environment,
				workspace=workspace,
				package_artifact_manifest="",
				package_artifact_manifest_sha256="",
			)

		self.assertEqual(
			contract.identities["godot_import"].effective[0],
			str(godot_path.resolve()),
		)

	def test_parallel_contract_ignores_tampered_external_projection_copy(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory).resolve()
			git_name = "git.exe" if os.name == "nt" else "git"
			git_path = workspace / git_name
			git_path.write_bytes(b"fixture")
			if os.name != "nt":
				git_path.chmod(0o755)
			catalog = gf_maintenance._VALIDATION_CATALOG
			external_projection = catalog.project_static_commands(
				root=workspace,
				godot_log_directory=workspace / "ai_analysis" / "godot_logs",
			)
			external_projection["diff"] = ["git", "status"]

			contract = gf_maintenance.freeze_parallel_shard_command_contract(
				["diff"],
				authority_catalog=catalog,
				environment={"PATH": "", "PATHEXT": ".EXE"},
				workspace=workspace,
				package_artifact_manifest="",
				package_artifact_manifest_sha256="",
			)

		self.assertNotIn(
			"projected_commands",
			inspect.signature(
				gf_maintenance.freeze_parallel_shard_command_contract
			).parameters,
		)
		self.assertEqual(
			contract.identities["diff"].declared,
			("git", "diff", "--check"),
		)
		self.assertEqual(
			contract.identities["diff"].effective[0],
			str(git_path.resolve()),
		)

	def test_parallel_package_artifact_contract_matches_parent_dispatch_tuple(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory).resolve()
			git_name = "git.exe" if os.name == "nt" else "git"
			git_path = workspace / git_name
			git_path.write_bytes(b"fixture")
			if os.name != "nt":
				git_path.chmod(0o755)
			check_name = "package_build_boundary"
			non_consumer_name = "diff"
			expected_checks = [check_name, non_consumer_name]
			workspace_state: dict[str, object] = {
				"schema_version": 1,
				"head": "a" * 40,
				"dirty": False,
				"untracked_file_count": 0,
				"fingerprint": "b" * 64,
			}
			manifest_a = str(workspace / "artifact-a.json")
			manifest_b = str(workspace / "artifact-b.json")
			manifest_sha256 = "c" * 64
			command = (
				*gf_maintenance._VALIDATION_CATALOG.command_definitions()[check_name],
				"--package-artifact-manifest",
				manifest_b,
				"--package-artifact-manifest-sha256",
				manifest_sha256,
			)
			non_consumer_command = tuple(
				gf_maintenance._VALIDATION_CATALOG.command_definitions()[
					non_consumer_name
				]
			)
			non_consumer_effective_command = (
				str(git_path.resolve()),
				*non_consumer_command[1:],
			)
			command_contract = gf_maintenance.ParallelShardCommandContract(
				identities={
					check_name: gf_maintenance.CommandIdentity(
						declared=command,
						effective=command,
					),
					non_consumer_name: gf_maintenance.CommandIdentity(
						declared=non_consumer_command,
						effective=non_consumer_effective_command,
					),
				},
			)
			report = {
				"ok": False,
				"suite": "quick",
				"checks": expected_checks,
				"completed_check_count": 0,
				"duration_seconds": 0.01,
				"suite_timeout_seconds": None,
				"check_graph": gf_maintenance.maintenance_check_graph().describe(
					expected_checks
				),
				"workspace_fingerprint": workspace_state["fingerprint"],
				"workspace_snapshot": {
					"text_entry_count": 0,
					"text_cache_hits": 0,
					"text_cache_misses": 0,
					"value_entry_count": 0,
					"value_cache_hits": 0,
					"value_cache_misses": 0,
				},
				"workspace": workspace_state,
				"execution": "serial",
				"jobs": 1,
				"results": [],
				"package_artifact_set": {
					"reused": True,
					"manifest_sha256": manifest_sha256,
					"artifact_count": 1,
					"workspace_fingerprint": workspace_state["fingerprint"],
				},
			}
			report_path = workspace / "report.json"
			report_path.write_text(
				json.dumps(report, ensure_ascii=False),
				encoding="utf-8",
				newline="\n",
			)
			shard_result = gf_maintenance.ParallelShardResult(
				name="fixture",
				command=(sys.executable, "fixture.py"),
				workspace=workspace,
				exit_code=1,
				process_exit_code=1,
				stdout="",
				stderr="",
				timed_out=False,
				cancelled=False,
				duration_seconds=0.01,
				pid=1,
				started=True,
			)

			def load(
				expected_manifest: str,
				contract: gf_maintenance.ParallelShardCommandContract = command_contract,
			) -> tuple[dict[str, object] | None, str]:
				return gf_maintenance.load_parallel_shard_report(
					shard_result,
					report_path,
					expected_checks,
					workspace_state,
					validation_catalog=gf_maintenance._VALIDATION_CATALOG,
					expected_command_contract=contract,
					expected_check_graph=report["check_graph"],
					expected_package_artifact_manifest=expected_manifest,
					expected_package_artifact_manifest_sha256=manifest_sha256,
					expected_package_artifact_count=1,
				)

			matching_report, matching_issue = load(manifest_b)
			self.assertIsNotNone(matching_report)
			self.assertEqual(matching_issue, "")
			mismatched_report, mismatched_issue = load(manifest_a)
			self.assertIsNone(mismatched_report)
			self.assertIn("package artifact", mismatched_issue.lower())
			forged_non_consumer_contract = (
				gf_maintenance.ParallelShardCommandContract(
					identities={
						**command_contract.identities,
						non_consumer_name: gf_maintenance.CommandIdentity(
							declared=(*non_consumer_command, *command[-4:]),
							effective=(
								*non_consumer_effective_command,
								*command[-4:],
							),
						),
					},
				)
			)
			forged_report, forged_issue = load(
				manifest_b,
				forged_non_consumer_contract,
			)
			self.assertIsNone(forged_report)
			self.assertIn("non-consumer", forged_issue)

	def test_parallel_supervisor_result_identity_must_match_frozen_dispatch(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory).resolve()
			dispatched = gf_maintenance.ParallelShard(
				name="fixture",
				command=(str(Path(sys.executable).resolve()), "--timeout", "17"),
				workspace=workspace,
				timeout_seconds=18.0,
				environment={},
			)

			def result(**overrides: object) -> gf_maintenance.ParallelShardResult:
				values: dict[str, object] = {
					"name": dispatched.name,
					"command": dispatched.command,
					"workspace": dispatched.workspace,
					"exit_code": 0,
					"process_exit_code": 0,
					"stdout": "",
					"stderr": "",
					"timed_out": False,
					"cancelled": False,
					"duration_seconds": 0.1,
					"pid": 1,
					"started": True,
					"process_boundary_quiescent": True,
				}
				values.update(overrides)
				return gf_maintenance.ParallelShardResult(**values)

			valid_result = result()
			gf_maintenance.assert_parallel_shard_results_match_dispatch(
				[dispatched],
				[valid_result],
			)
			invalid_results = (
				[],
				[valid_result, valid_result],
				[result(name="forged")],
				[result(command=("python", "--timeout", "999"))],
				[result(workspace=workspace / "forged")],
			)
			for shard_results in invalid_results:
				with self.subTest(shard_results=shard_results), self.assertRaises(
					gf_maintenance.WorkspaceSnapshotError
				):
					gf_maintenance.assert_parallel_shard_results_match_dispatch(
						[dispatched],
						shard_results,
					)
			second_dispatched = gf_maintenance.ParallelShard(
				name="fixture-second",
				command=(str(Path(sys.executable).resolve()), "--timeout", "23"),
				workspace=workspace / "second",
				timeout_seconds=24.0,
				environment={},
			)
			second_result = result(
				name=second_dispatched.name,
				command=second_dispatched.command,
				workspace=second_dispatched.workspace,
			)
			with self.assertRaises(gf_maintenance.WorkspaceSnapshotError):
				gf_maintenance.assert_parallel_shard_results_match_dispatch(
					[dispatched, second_dispatched],
					[second_result, valid_result],
				)

	def test_parallel_full_schedule_separates_heavy_shards(self) -> None:
		plan = gf_maintenance.parallel_full_shard_plan(_full_validation_plan())
		plan_names = tuple(shard.name for shard in plan)
		self.assertEqual(
			plan_names,
			(
				"package-editor",
				"framework-static",
				"package-godot-ci",
				"package-cli-local",
				"package-cli-network",
				"package-contract",
				"framework-gut",
				"framework-lsp",
			),
		)
		self.assertEqual(
			tuple(
				tuple(shard.name for shard in batch)
				for batch in gf_maintenance.parallel_full_shard_batches(plan, 2)
			),
			(
				("package-editor", "framework-static"),
				("package-godot-ci", "package-cli-local"),
				("package-cli-network", "package-contract"),
				("framework-gut",),
				("framework-lsp",),
			),
		)
		self.assertEqual(
			tuple(
				tuple(shard.name for shard in batch)
				for batch in gf_maintenance.parallel_full_shard_batches(plan, 3)
			),
			(
				("package-editor", "framework-static", "package-godot-ci"),
				("package-cli-local", "package-cli-network", "package-contract"),
				("framework-gut",),
				("framework-lsp",),
			),
		)
		for jobs in range(1, gf_maintenance.MAX_PARALLEL_FULL_JOBS + 1):
			batches = gf_maintenance.parallel_full_shard_batches(plan, jobs)
			batch_names = tuple(
				tuple(shard.name for shard in batch)
				for batch in batches
			)
			flattened_names = tuple(
				name for batch in batch_names for name in batch
			)
			with self.subTest(jobs=jobs):
				self.assertEqual(flattened_names, plan_names)
				self.assertTrue(all(1 <= len(batch) <= jobs for batch in batches))
				self.assertEqual(
					[batch for batch in batch_names if "framework-gut" in batch],
					[("framework-gut",)],
				)
		with self.assertRaisesRegex(ValueError, "must be positive"):
			gf_maintenance.parallel_full_shard_batches(plan, 0)

	def test_parallel_full_fail_fast_marks_only_future_resource_batches(self) -> None:
		plan = [
			_synthetic_parallel_shard_plan("first", ("docs",)),
			_synthetic_parallel_shard_plan(
				"framework-gut",
				("api",),
				("docs", "api"),
			),
			_synthetic_parallel_shard_plan("last", ("ai_api",)),
		]
		validation_plan = _synthetic_full_validation_plan(
			plan,
			dependencies={"api": ("docs",)},
		)
		expected_graphs: dict[str, dict[str, object]] = {}
		frozen_contracts: dict[str, gf_maintenance.ParallelShardCommandContract] = {}
		contract_events: list[tuple[str, str]] = []

		class ExpectedStop(RuntimeError):
			pass

		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			parallel_root = root / "parallel"
			parallel_root.mkdir()
			captured = gf_maintenance.CapturedWorkspace(
				source_root=root,
				head="a" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint="b" * 64,
			)

			def materialize(
				_captured: object,
				batch_root: Path,
				batch_plan: list[object],
				**_kwargs: object,
			) -> dict[str, Path]:
				workspaces: dict[str, Path] = {}
				for shard_plan in batch_plan:
					workspace = batch_root / str(shard_plan.name)
					workspace.mkdir()
					workspaces[str(shard_plan.name)] = workspace
				return workspaces

			def make_shard(
				shard_plan: object,
				workspace: Path,
				**_kwargs: object,
			) -> tuple[object, Path]:
				return (
					gf_maintenance.ParallelShard(
						name=str(shard_plan.name),
						command=(str(Path(sys.executable).resolve()), "-V"),
						workspace=workspace,
						timeout_seconds=1.0,
						environment={},
					),
					workspace / "report.json",
				)

			def run_shards(
				shards: list[object],
				**_kwargs: object,
			) -> list[object]:
				for dispatched_shard in shards:
					self.assertIn(str(dispatched_shard.name), frozen_contracts)
					contract_events.append(("dispatch", str(dispatched_shard.name)))
				shard = shards[0]
				exit_code = 1 if shard.name == "framework-gut" else 0
				return [gf_maintenance.ParallelShardResult(
					name=str(shard.name),
					command=tuple(shard.command),
					workspace=shard.workspace,
					exit_code=exit_code,
					process_exit_code=exit_code,
					stdout="",
					stderr="",
					timed_out=False,
					cancelled=False,
					duration_seconds=0.1,
					pid=1,
					started=True,
					process_boundary_quiescent=True,
				)]

			def load_report(
				shard_result: object,
				_report_path: Path,
				expected_checks: list[str],
				*_args: object,
				**kwargs: object,
			) -> tuple[dict[str, object], str]:
				shard_name = str(shard_result.name)
				self.assertIs(
					kwargs["expected_command_contract"],
					frozen_contracts[shard_name],
				)
				contract_events.append(("load", shard_name))
				expected_graphs[str(shard_result.name)] = dict(
					kwargs["expected_check_graph"]
				)
				return ({
					"ok": shard_result.exit_code == 0,
					"results": [{
						"name": expected_checks[0],
						"exit_code": shard_result.exit_code,
						"timed_out": False,
						"cancelled": False,
						"duration_seconds": 0.1,
					}],
				}, "")

			real_freeze_contract = gf_maintenance.freeze_parallel_shard_command_contract

			def freeze_contract(
				expected_checks: list[str],
				**kwargs: object,
			) -> gf_maintenance.ParallelShardCommandContract:
				self.assertIs(
					kwargs["authority_catalog"],
					gf_maintenance._VALIDATION_CATALOG,
				)
				contract = real_freeze_contract(expected_checks, **kwargs)
				shard_name = Path(str(kwargs["workspace"])).name
				frozen_contracts[shard_name] = contract
				contract_events.append(("freeze", shard_name))
				return contract

			with mock.patch.object(
				gf_maintenance,
				"parallel_full_shard_plan",
				return_value=plan,
			), mock.patch.object(
				gf_maintenance._VALIDATION_CATALOG,
				"plan",
				side_effect=AssertionError("parallel execution must not re-plan"),
			), mock.patch.object(
				gf_maintenance,
				"expanded_check_names",
				side_effect=AssertionError("parallel execution must consume its plan"),
			), mock.patch.object(
				gf_maintenance,
				"run_parallel_godot_isolation_probe",
				return_value={"ok": True},
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"assert_source_matches_snapshot",
			), mock.patch.object(
				gf_maintenance,
				"materialize_parallel_full_workspaces",
				side_effect=materialize,
			), mock.patch.object(
				gf_maintenance,
				"validation_catalog_for_root",
				side_effect=AssertionError(
					"parallel projection must not construct a second Catalog"
				),
			), mock.patch.object(
				gf_maintenance,
				"make_parallel_full_shard",
				side_effect=make_shard,
			), mock.patch.object(
				gf_maintenance,
				"freeze_parallel_shard_command_contract",
				side_effect=freeze_contract,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"run_parallel_shards",
				side_effect=run_shards,
			) as run_parallel, mock.patch.object(
				gf_maintenance,
				"load_parallel_shard_report",
				side_effect=load_report,
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				return_value={"fingerprint": "b" * 64},
			), mock.patch.object(
				gf_maintenance,
				"collect_parallel_failure_logs",
				return_value=[],
			), mock.patch.object(
				gf_maintenance,
				"append_unstarted_parallel_shards",
				side_effect=ExpectedStop("captured future batches"),
			) as append_unstarted:
				with self.assertRaises(ExpectedStop):
					gf_maintenance.run_parallel_full_checks(
						captured,
						parallel_root,
						validation_plan=validation_plan,
						validation_catalog=gf_maintenance._VALIDATION_CATALOG,
						git_process=_SHARED_PROCESS_AUTHORITY.git,
						jobs=2,
						timeout_seconds=None,
						suite_timeout_seconds=None,
						fail_fast=True,
						package_artifact_manifest="manifest.json",
						package_artifact_manifest_sha256="d" * 64,
						package_artifact_count=1,
						progress_callback=None,
						output_callback=None,
						overall_started=time.perf_counter(),
						suite_deadline=time.perf_counter() + 10.0,
					)

		self.assertEqual(run_parallel.call_count, 2)
		first_dispatch_index = min(
			index
			for index, event in enumerate(contract_events)
			if event[0] == "dispatch"
		)
		for shard_name in ("first", "framework-gut", "last"):
			self.assertLess(
				contract_events.index(("freeze", shard_name)),
				first_dispatch_index,
			)
		for shard_name in ("first", "framework-gut"):
			self.assertLess(
				contract_events.index(("freeze", shard_name)),
				contract_events.index(("dispatch", shard_name)),
			)
			self.assertLess(
				contract_events.index(("dispatch", shard_name)),
				contract_events.index(("load", shard_name)),
			)
		self.assertEqual(
			[shard.name for shard in append_unstarted.call_args.args[0]],
			["last"],
		)
		self.assertEqual(
			expected_graphs["framework-gut"],
			validation_plan.check_graph.describe(["docs", "api"]),
		)

	def test_parallel_full_later_batch_resolution_failure_starts_nothing(
		self,
	) -> None:
		plan = [
			_synthetic_parallel_shard_plan("first", ("diff",)),
			_synthetic_parallel_shard_plan("later", ("godot_import",)),
		]
		validation_plan = _synthetic_full_validation_plan(plan)
		freeze_events: list[tuple[str, ...]] = []
		frozen_contracts: dict[
			str,
			gf_maintenance.ParallelShardCommandContract,
		] = {}
		progress_events: list[tuple[str, str, float | None]] = []
		real_freeze_contract = gf_maintenance.freeze_parallel_shard_command_contract

		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory).resolve()
			parallel_root = root / "parallel"
			tool_root = root / "tools"
			parallel_root.mkdir()
			tool_root.mkdir()
			git_name = "git.exe" if os.name == "nt" else "git"
			git_path = tool_root / git_name
			git_path.write_bytes(b"fixture")
			if os.name != "nt":
				git_path.chmod(0o755)
			captured = gf_maintenance.CapturedWorkspace(
				source_root=root,
				head="a" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint="b" * 64,
			)

			def materialize(
				_captured: object,
				batch_root: Path,
				batch_plan: list[object],
				**_kwargs: object,
			) -> dict[str, Path]:
				workspaces: dict[str, Path] = {}
				for shard_plan in batch_plan:
					workspace = batch_root / str(shard_plan.name)
					workspace.mkdir()
					workspaces[str(shard_plan.name)] = workspace
				return workspaces

			def make_shard(
				shard_plan: object,
				workspace: Path,
				**_kwargs: object,
			) -> tuple[object, Path]:
				return (
					gf_maintenance.ParallelShard(
						name=str(shard_plan.name),
						command=(str(Path(sys.executable).resolve()), "-V"),
						workspace=workspace,
						timeout_seconds=1.0,
						environment={
							"PATH": str(tool_root),
							"PATHEXT": ".EXE",
							"NoDefaultCurrentDirectoryInExePath": "1",
						},
					),
					workspace / "report.json",
				)

			def freeze_contract(
				expected_checks: list[str],
				**kwargs: object,
			) -> gf_maintenance.ParallelShardCommandContract:
				freeze_events.append(tuple(expected_checks))
				contract = real_freeze_contract(expected_checks, **kwargs)
				frozen_contracts[expected_checks[0]] = contract
				return contract

			with mock.patch.object(
				gf_maintenance,
				"parallel_full_shard_plan",
				return_value=plan,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"assert_source_matches_snapshot",
			), mock.patch.object(
				gf_maintenance,
				"materialize_parallel_full_workspaces",
				side_effect=materialize,
			), mock.patch.object(
				gf_maintenance,
				"make_parallel_full_shard",
				side_effect=make_shard,
			), mock.patch.object(
				gf_maintenance,
				"freeze_parallel_shard_command_contract",
				side_effect=freeze_contract,
			), mock.patch.object(
				gf_maintenance,
				"run_parallel_godot_isolation_probe",
				side_effect=AssertionError(
					"The isolation probe must remain behind global admission."
				),
			) as isolation_probe, mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"run_parallel_shards",
				side_effect=AssertionError(
					"No shard may dispatch before every command identity resolves."
				),
			) as run_parallel:
				with self.assertRaises(gf_maintenance.ExecutableResolutionError):
					gf_maintenance.run_parallel_full_checks(
						captured,
						parallel_root,
						validation_plan=validation_plan,
						validation_catalog=gf_maintenance._VALIDATION_CATALOG,
						git_process=_SHARED_PROCESS_AUTHORITY.git,
						jobs=1,
						timeout_seconds=None,
						suite_timeout_seconds=None,
						fail_fast=False,
						package_artifact_manifest="",
						package_artifact_manifest_sha256="",
						package_artifact_count=0,
						progress_callback=lambda status, name, duration: (
							progress_events.append((status, name, duration))
						),
						output_callback=None,
						overall_started=time.perf_counter(),
						suite_deadline=time.perf_counter() + 10.0,
					)

		self.assertEqual(freeze_events, [("diff",), ("godot_import",)])
		self.assertEqual(
			frozen_contracts["diff"].identities["diff"].effective[0],
			str(git_path.resolve()),
		)
		isolation_probe.assert_not_called()
		run_parallel.assert_not_called()
		self.assertEqual(progress_events, [])

	def test_parallel_workspace_materialization_drains_later_cleanup_debt(
		self,
	) -> None:
		plan = [
			_synthetic_parallel_shard_plan("ordinary", ("docs",)),
			_synthetic_parallel_shard_plan("cleanup-debt", ("api",)),
		]
		second_started = threading.Event()
		first_failed = threading.Event()
		completed: list[str] = []
		ordinary_error = ValueError("fixture ordinary materializer failure")
		debt_error = (
			gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError(
				"fixture materializer cleanup debt"
			)
		)

		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory).resolve()
			captured = gf_maintenance.CapturedWorkspace(
				source_root=root,
				head="a" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint="b" * 64,
			)

			def materialize(
				_captured: object,
				destination: Path,
				**_kwargs: object,
			) -> Path:
				if destination.name == "s0":
					if not second_started.wait(timeout=2.0):
						raise RuntimeError(
							"fixture sibling materializer did not start"
						)
					completed.append("ordinary")
					first_failed.set()
					raise ordinary_error
				second_started.set()
				if not first_failed.wait(timeout=2.0):
					raise RuntimeError(
						"fixture first materializer did not fail"
					)
				completed.append("cleanup-debt")
				raise debt_error

			with mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"materialize_workspace",
				side_effect=materialize,
			) as materializer, self.assertRaises(
				gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError
			) as raised:
				gf_maintenance.materialize_parallel_full_workspaces(
					captured,
					root / "parallel",
					plan,
					git_process=_SHARED_PROCESS_AUTHORITY.git,
					deadline=time.perf_counter() + 5.0,
				)

		self.assertIs(raised.exception, debt_error)
		self.assertTrue(raised.exception.cleanup_debt)
		self.assertEqual(materializer.call_count, 2)
		self.assertEqual(completed, ["ordinary", "cleanup-debt"])
		self.assertIn(
			"Additional parallel workspace materializer failure (ordinary): ValueError",
			"\n".join(getattr(raised.exception, "__notes__", ())),
		)

	def test_parallel_workspace_submission_failure_still_drains_cleanup_debt(
		self,
	) -> None:
		plan = [
			_synthetic_parallel_shard_plan("launched", ("docs",)),
			_synthetic_parallel_shard_plan("submit-fails", ("api",)),
		]
		submission_failed = threading.Event()
		debt_error = (
			gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError(
				"fixture launched materializer cleanup debt"
			)
		)
		submit_error = RuntimeError("fixture second materializer submit failure")
		real_submit = concurrent.futures.ThreadPoolExecutor.submit
		submit_count = 0

		def fail_second_submit(
			executor: concurrent.futures.ThreadPoolExecutor,
			function: object,
			*args: object,
			**kwargs: object,
		) -> concurrent.futures.Future[object]:
			nonlocal submit_count
			submit_count += 1
			if submit_count == 2:
				submission_failed.set()
				raise submit_error
			return real_submit(executor, function, *args, **kwargs)

		def materialize(*_args: object, **_kwargs: object) -> Path:
			if not submission_failed.wait(timeout=2.0):
				raise RuntimeError("fixture submission failure was not published")
			raise debt_error

		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory).resolve()
			captured = gf_maintenance.CapturedWorkspace(
				source_root=root,
				head="a" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint="b" * 64,
			)
			with mock.patch.object(
				concurrent.futures.ThreadPoolExecutor,
				"submit",
				new=fail_second_submit,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"materialize_workspace",
				side_effect=materialize,
			) as materializer, self.assertRaises(
				gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError
			) as raised:
				gf_maintenance.materialize_parallel_full_workspaces(
					captured,
					root / "parallel",
					plan,
					git_process=_SHARED_PROCESS_AUTHORITY.git,
					deadline=time.perf_counter() + 5.0,
				)

		self.assertIs(raised.exception, debt_error)
		self.assertEqual(materializer.call_count, 1)
		self.assertEqual(submit_count, 2)
		self.assertIn(
			"Additional parallel workspace materializer failure "
			"(submit-fails:submit): RuntimeError",
			"\n".join(getattr(raised.exception, "__notes__", ())),
		)

	def test_parallel_full_plan_owns_full_check_set_exactly_once(self) -> None:
		plan = gf_maintenance.parallel_full_shard_plan(_full_validation_plan())
		self.assertEqual(
			tuple((shard.name, shard.checks) for shard in plan),
			(
				("package-editor", ("package_editor_wizard_smoke",)),
				(
					"framework-static",
					(
						"api",
						"ai_api",
						"ai_developer_kit",
						"docs",
						"changelog_policy",
						"public_docs_boundary",
						"public_api_boundary",
						"resource_boundary",
						"content_package_boundary",
						"asset_lifecycle_boundary",
						"project_profile_boundary",
						"mkdocs",
						"api_since_touched",
						"repository_policy",
						"credential_gate",
						"credential_gate_tests",
						"codeql_suppression_policy",
						"codeql_suppression_policy_tests",
						"path_hygiene",
						"maintenance_self_test",
						"maintenance_execution_tests",
						"maintenance_generator_tests",
						"maintenance_test_evidence_tests",
						"dependency_boundary",
						"diff",
					),
				),
				("package-godot-ci", ("package_godot_smoke",)),
				("package-cli-local", ("package_godot_cli_local_smoke",)),
				("package-cli-network", ("package_godot_cli_network_smoke",)),
				(
					"package-contract",
					(
						"ai_developer_adapter_acceptance",
						"package_boundary",
						"package_closure_audit",
						"package_source_boundary",
						"package_user_dependency_boundary",
						"package_external_command_audit",
						"core_only_smoke",
						"core_plugin_bootstrap_smoke",
						"package_focused_gut_mapping",
						"package_distribution_tests",
						"package_schema_contract_tests",
						"package_build_boundary",
					),
				),
				(
					"framework-gut",
					("gut_lifecycle_smoke", "gut", "gdscript_warnings"),
				),
				("framework-lsp", ("gdscript_lsp_diagnostics",)),
			),
		)
		owned_checks = [check for shard in plan for check in shard.checks]
		self.assertEqual(set(owned_checks), set(gf_maintenance.FULL_CHECKS))
		self.assertEqual(len(owned_checks), len(set(owned_checks)))
		for shard in plan:
			with self.subTest(shard=shard.name):
				self.assertTrue(set(shard.checks).issubset(
					gf_maintenance.CHECK_SUITES[shard.name]
				))
		self.assertEqual(
			next(
				shard.name
				for shard in plan
				if "gdscript_lsp_diagnostics" in shard.checks
			),
			"framework-lsp",
		)

	def test_windows_path_budget_counts_utf16_code_units(self) -> None:
		path = r"D:\😀😀😀\gfs-xxxxxxxx"
		self.assertEqual(len(path), 19)
		self.assertEqual(gf_maintenance.windows_utf16_path_code_units(path), 22)

	def test_open_file_identity_rejects_missing_device_and_inode(self) -> None:
		missing_identity = os.stat_result(
			(0o100600, 0, 0, 1, 0, 0, 7, 0, 0, 0)
		)
		self.assertFalse(
			gf_maintenance.same_open_file_identity(
				missing_identity,
				missing_identity,
			)
		)

	@unittest.skipUnless(os.name == "nt", "Windows extended-path behavior")
	def test_parallel_failure_log_copy_supports_long_destination_leaf(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			workspace_root = fixture_root / "workspace"
			source_root = workspace_root / "ai_analysis" / "godot_logs"
			destination_containment_root = fixture_root / "destination"
			destination_root = (
				destination_containment_root
				/ ("session-" + "x" * 96)
				/ "package-editor"
			)
			source_root.mkdir(parents=True)
			destination_root.mkdir(parents=True)
			entry_name = (
				"package_editor_wizard_smoke_minimal_kernel_project_editor_"
				"offline_bundle_preset_install_uninstall.log"
			)
			payload = b"retained failure evidence"
			(source_root / entry_name).write_bytes(payload)
			destination_path = destination_root / entry_name
			self.assertGreaterEqual(
				gf_maintenance.windows_utf16_path_code_units(destination_path),
				260,
			)
			extended_destination = "\\\\?\\" + str(destination_path)
			try:
				gf_maintenance.copy_parallel_log_tree(
					source_root,
					destination_root,
					containment_root=workspace_root,
					destination_containment_root=destination_containment_root,
					expected_destination_identity=destination_root.lstat(),
					expected_destination_containment_identity=(
						destination_containment_root.lstat()
					),
				)

				file_descriptor = os.open(extended_destination, os.O_RDONLY)
				try:
					self.assertEqual(os.read(file_descriptor, len(payload) + 1), payload)
				finally:
					os.close(file_descriptor)
			finally:
				if os.path.lexists(extended_destination):
					os.unlink(extended_destination)

	@unittest.skipUnless(os.name == "nt", "Windows extended-path behavior")
	def test_parallel_failure_log_copy_supports_long_source_leaf(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			workspace_root = fixture_root / "workspace"
			source_root = workspace_root / ("source-" + "x" * 104)
			destination_containment_root = fixture_root / "destination"
			destination_root = destination_containment_root / "package-editor"
			source_root.mkdir(parents=True)
			destination_root.mkdir(parents=True)
			entry_name = (
				"package_editor_wizard_smoke_minimal_kernel_project_editor_"
				"offline_bundle_preset_install_uninstall.log"
			)
			payload = b"retained failure evidence"
			source_path = source_root / entry_name
			self.assertGreaterEqual(
				gf_maintenance.windows_utf16_path_code_units(source_path),
				260,
			)
			extended_source = "\\\\?\\" + str(source_path)
			file_descriptor = os.open(
				extended_source,
				os.O_CREAT | os.O_EXCL | os.O_WRONLY | getattr(os, "O_BINARY", 0),
				0o600,
			)
			with os.fdopen(file_descriptor, "wb") as source_file:
				source_file.write(payload)
			try:
				gf_maintenance.copy_parallel_log_tree(
					source_root,
					destination_root,
					containment_root=workspace_root,
					destination_containment_root=destination_containment_root,
					expected_destination_identity=destination_root.lstat(),
					expected_destination_containment_identity=(
						destination_containment_root.lstat()
					),
				)

				self.assertEqual((destination_root / entry_name).read_bytes(), payload)
			finally:
				if os.path.lexists(extended_source):
					os.unlink(extended_source)

	def test_standalone_process_smokes_use_guarded_temporary_roots(self) -> None:
		for function in (
			gf_maintenance.core_plugin_bootstrap_smoke,
			gf_maintenance.package_build_boundary,
			gf_maintenance.package_editor_wizard_smoke,
			gf_maintenance.package_godot_cli_smoke,
			gf_maintenance.package_godot_smoke,
		):
			with self.subTest(function=function.__name__):
				source = inspect.getsource(function)
				self.assertIn("strict_process_boundary_temporary_directory", source)
				self.assertNotIn("with strict_managed_temporary_directory", source)

	def test_process_boundary_temp_retains_root_until_body_proves_quiescence(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parent = Path(temporary_directory)
			retained: Path | None = None
			with self.assertRaises(
				gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError,
			) as raised:
				with gf_maintenance.strict_process_boundary_temporary_directory(
					prefix="gf-process-boundary-fixture-",
					directory=parent,
				) as owned_root:
					retained = owned_root
					(owned_root / "must-retain.txt").write_text("retained", encoding="utf-8")
					raise gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError(
						"synthetic unproved process boundary",
						preserved_paths=(owned_root,),
					)
			self.assertIsNotNone(retained)
			assert retained is not None
			self.assertTrue(gf_maintenance.exception_has_cleanup_debt(raised.exception))
			self.assertIn(
				"Retained temporary root because process-boundary cleanup ownership was not proven",
				"\n".join(getattr(raised.exception, "__notes__", ())),
			)
			self.assertEqual(
				(retained / "must-retain.txt").read_text(encoding="utf-8"),
				"retained",
			)

	def test_retention_diagnostics_do_not_replace_hostile_primary_error(self) -> None:
		class HostileBoundaryError(
			gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError
		):
			def add_note(self, _note: str) -> None:
				raise SystemExit("fixture hostile add_note")

		with tempfile.TemporaryDirectory() as temporary_directory:
			owned_root = Path(temporary_directory) / "owned"
			owned_root.mkdir()
			primary = HostileBoundaryError(
				"synthetic unproved process boundary",
				preserved_paths=(owned_root,),
			)
			with mock.patch.object(
				gf_maintenance.tempfile,
				"mkdtemp",
				return_value=str(owned_root),
			):
				with self.assertRaises(HostileBoundaryError) as raised:
					with gf_maintenance.strict_process_boundary_temporary_directory(
						prefix="gf-process-boundary-fixture-",
					) as retained:
						(retained / "must-retain.txt").write_text(
							"retained",
							encoding="utf-8",
						)
						raise primary

			self.assertIs(raised.exception, primary)
			self.assertEqual(
				(owned_root / "must-retain.txt").read_text(encoding="utf-8"),
				"retained",
			)

	def test_cleanup_debt_classifier_has_one_shared_authority(self) -> None:
		self.assertIs(
			gf_maintenance.exception_has_cleanup_debt,
			gf_process_supervisor.exception_has_cleanup_debt,
		)

	def test_cleanup_debt_classifier_bypasses_lying_exception_getters(self) -> None:
		class HostileDebtError(gf_maintenance.PackageArtifactSetError):
			def __init__(self, message: str) -> None:
				super().__init__(message)
				attributes = BaseException.__getattribute__(self, "__dict__")
				attributes["cleanup_debt"] = True
				attributes["process_boundary_quiescent"] = False

			def __getattribute__(self, name: str) -> object:
				if name == "cleanup_debt":
					return False
				if name == "process_boundary_quiescent":
					return True
				return super().__getattribute__(name)

		with tempfile.TemporaryDirectory() as temporary_directory:
			owned_root = Path(temporary_directory) / "owned"
			owned_root.mkdir()
			marker = owned_root / "must-retain.txt"
			marker.write_text("retained", encoding="utf-8")
			primary = HostileDebtError("synthetic uninspectable cleanup boundary")

			with mock.patch.object(
				gf_maintenance.tempfile,
				"mkdtemp",
				return_value=str(owned_root),
			), mock.patch.object(
				gf_maintenance,
				"load_or_build_private_package_artifact_set",
				side_effect=primary,
			):
				with self.assertRaises(HostileDebtError) as raised:
					gf_maintenance.package_build_boundary()

			self.assertIs(raised.exception, primary)
			self.assertEqual(marker.read_text(encoding="utf-8"), "retained")

	def test_cleanup_debt_classifier_rejects_hidden_context_descriptor(self) -> None:
		class HostileWrapper(gf_maintenance.PackageArtifactSetError):
			@property
			def __context__(self) -> None:
				return None

		debt = gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError(
			"fixture hidden cleanup debt"
		)
		try:
			raise debt
		except gf_maintenance.WorkspaceSnapshotError:
			try:
				raise HostileWrapper("fixture wrapper") from None
			except HostileWrapper as wrapper:
				primary = wrapper

		self.assertTrue(gf_maintenance.exception_has_cleanup_debt(primary))

	def test_package_capture_wrapper_does_not_format_hostile_cleanup_debt(self) -> None:
		class HostileSnapshotError(gf_maintenance.WorkspaceSnapshotError):
			cleanup_debt = True
			process_boundary_quiescent = False

			def __str__(self) -> str:
				raise SystemExit("fixture hostile snapshot __str__")

		with tempfile.TemporaryDirectory() as temporary_directory:
			owned_root = Path(temporary_directory) / "owned"
			owned_root.mkdir()
			marker = owned_root / "must-retain.txt"
			marker.write_text("retained", encoding="utf-8")
			primary = HostileSnapshotError("synthetic capture cleanup debt")
			workspace_state = {"fingerprint": "a" * 64}

			with (
				mock.patch.object(
					gf_maintenance.tempfile,
					"mkdtemp",
					return_value=str(owned_root),
				),
				mock.patch.object(
					gf_maintenance,
					"workspace_fingerprint",
					return_value=workspace_state,
				),
				mock.patch.object(
					gf_maintenance.gf_parallel_validation,
					"capture_workspace",
					side_effect=primary,
				),
			):
				with self.assertRaises(gf_maintenance.PackageArtifactSetError) as raised:
					gf_maintenance.package_build_boundary()

			self.assertIs(raised.exception.__cause__, primary)
			self.assertTrue(gf_maintenance.exception_has_cleanup_debt(raised.exception))
			self.assertEqual(marker.read_text(encoding="utf-8"), "retained")

	def test_package_build_diagnostic_does_not_format_hostile_ordinary_error(self) -> None:
		class HostilePackageError(gf_maintenance.PackageArtifactSetError):
			def __str__(self) -> str:
				raise SystemExit("fixture hostile package error text")

		with mock.patch.object(
			gf_maintenance,
			"load_or_build_private_package_artifact_set",
			side_effect=HostilePackageError("fixture invalid artifact set"),
		):
			report = gf_maintenance.package_build_boundary()

		self.assertFalse(report["ok"])
		self.assertEqual(report["issues"][0]["kind"], "package_artifact_set_invalid")
		self.assertIn("detail unavailable", report["issues"][0]["error"])

	def test_package_build_boundary_preserves_wrapped_materializer_debt(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			owned_root = Path(temporary_directory) / "owned"
			owned_root.mkdir()

			def fail_with_boundary(
				temp_root: Path,
				_consumer_root: Path,
				*_args: object,
				**_kwargs: object,
			) -> object:
				marker = temp_root / "artifact-source" / "must-retain.txt"
				marker.parent.mkdir(parents=True)
				marker.write_text("retained", encoding="utf-8")
				try:
					raise gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError(
						"synthetic materializer boundary debt",
						preserved_paths=(marker.parent,),
					)
				except gf_maintenance.WorkspaceSnapshotError as error:
					raise gf_maintenance.PackageArtifactSetError(
						"wrapped materializer failure"
					) from error

			with mock.patch.object(
				gf_maintenance.tempfile,
				"mkdtemp",
				return_value=str(owned_root),
			), mock.patch.object(
				gf_maintenance,
				"load_or_build_private_package_artifact_set",
				side_effect=fail_with_boundary,
			):
				with self.assertRaises(
					gf_maintenance.PackageArtifactSetError,
				) as raised:
					gf_maintenance.package_build_boundary()
			self.assertTrue(gf_maintenance.exception_has_cleanup_debt(raised.exception))
			self.assertIsInstance(
				raised.exception.__cause__,
				gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError,
			)
			self.assertIn(
				"Retained temporary root",
				"\n".join(getattr(raised.exception, "__notes__", ())),
			)
			self.assertTrue((owned_root / "artifact-source" / "must-retain.txt").is_file())

	def test_private_artifact_cleanup_failure_carries_debt_and_retained_path(self) -> None:
		artifact_module = gf_maintenance.gf_package_artifact_set
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			source_root = root / "source"
			source_root.mkdir()
			manifest_path = source_root / artifact_module.MANIFEST_FILENAME
			manifest_path.write_text("{}\n", encoding="utf-8")
			source = artifact_module.PackageArtifactSet(
				root=source_root,
				manifest_path=manifest_path,
				manifest_sha256="a" * 64,
				workspace_state={},
				artifacts=(),
				builder_result={},
			)
			target = root / "consumer"
			staging = root / ".consumer.a-deadbeef"
			primary = artifact_module.PackageArtifactSetError("private copy validation failed")

			with (
				mock.patch.object(
					artifact_module,
					"revalidate_package_artifact_set",
					return_value=source,
				),
				mock.patch.object(
					artifact_module,
					"load_package_artifact_set",
					side_effect=primary,
				),
				mock.patch.object(artifact_module.secrets, "token_hex", return_value="deadbeef"),
				mock.patch.object(
					artifact_module,
					"_safe_remove_private_tree",
					return_value="exact private staging cleanup was refused",
				),
			):
				with self.assertRaises(artifact_module.PackageArtifactSetError) as raised:
					artifact_module.materialize_package_artifact_set(source, target)

			self.assertIs(raised.exception, primary)
			self.assertTrue(raised.exception.cleanup_debt)
			self.assertFalse(raised.exception.process_boundary_quiescent)
			self.assertEqual(raised.exception.preserved_paths, (staging,))
			self.assertIsInstance(
				raised.exception.cleanup_error,
				artifact_module.PackageArtifactSetError,
			)
			self.assertIn(
				"exact private staging cleanup was refused",
				str(raised.exception.cleanup_error),
			)
			self.assertTrue(staging.is_dir())

	def test_missing_private_artifact_staging_is_cleanup_debt(self) -> None:
		artifact_module = gf_maintenance.gf_package_artifact_set
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			source_root = root / "source"
			source_root.mkdir()
			manifest_path = source_root / artifact_module.MANIFEST_FILENAME
			manifest_path.write_text("{}\n", encoding="utf-8")
			source = artifact_module.PackageArtifactSet(
				root=source_root,
				manifest_path=manifest_path,
				manifest_sha256="a" * 64,
				workspace_state={},
				artifacts=(),
				builder_result={},
			)
			target = root / "consumer"
			staging = root / ".consumer.a-deadbeef"
			moved_staging = root / "moved-private-staging"
			primary = artifact_module.PackageArtifactSetError(
				"private copy validation failed"
			)

			def move_staging_then_fail(*_args: object, **_kwargs: object) -> object:
				staging.rename(moved_staging)
				raise primary

			with (
				mock.patch.object(
					artifact_module,
					"revalidate_package_artifact_set",
					return_value=source,
				),
				mock.patch.object(
					artifact_module,
					"load_package_artifact_set",
					side_effect=move_staging_then_fail,
				),
				mock.patch.object(artifact_module.secrets, "token_hex", return_value="deadbeef"),
			):
				with self.assertRaises(artifact_module.PackageArtifactSetError) as raised:
					artifact_module.materialize_package_artifact_set(source, target)

			self.assertIs(raised.exception, primary)
			self.assertTrue(raised.exception.cleanup_debt)
			self.assertFalse(raised.exception.process_boundary_quiescent)
			self.assertEqual(raised.exception.preserved_paths, (staging,))
			self.assertTrue(moved_staging.is_dir())

	def test_private_artifact_publication_move_then_control_retains_target(self) -> None:
		artifact_module = gf_maintenance.gf_package_artifact_set
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			source_root = root / "source"
			source_root.mkdir()
			manifest_path = source_root / artifact_module.MANIFEST_FILENAME
			manifest_path.write_text("{}\n", encoding="utf-8")
			source = artifact_module.PackageArtifactSet(
				root=source_root,
				manifest_path=manifest_path,
				manifest_sha256="a" * 64,
				workspace_state={},
				artifacts=(),
				builder_result={},
			)
			target = root / "consumer"
			staging = root / ".consumer.a-deadbeef"
			primary = KeyboardInterrupt("fixture publication interruption")
			real_replace = os.replace

			def move_then_interrupt(source_path: object, target_path: object) -> None:
				real_replace(source_path, target_path)
				raise primary

			with (
				mock.patch.object(
					artifact_module,
					"revalidate_package_artifact_set",
					return_value=source,
				),
				mock.patch.object(
					artifact_module,
					"load_package_artifact_set",
					return_value=source,
				),
				mock.patch.object(artifact_module.secrets, "token_hex", return_value="deadbeef"),
				mock.patch.object(
					artifact_module.os,
					"replace",
					side_effect=move_then_interrupt,
				),
			):
				observed: BaseException | None = None
				try:
					artifact_module.materialize_package_artifact_set(source, target)
				except BaseException as error:
					observed = error

			self.assertIs(observed, primary)
			self.assertTrue(primary.cleanup_debt)
			self.assertFalse(primary.process_boundary_quiescent)
			self.assertEqual(primary.preserved_paths, (target,))
			self.assertTrue(target.is_dir())
			self.assertFalse(staging.exists())

	def test_package_build_boundary_preserves_private_artifact_cleanup_debt(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			owned_root = Path(temporary_directory) / "owned"
			staging = owned_root / ".artifact-consumer.a-deadbeef"
			staging.mkdir(parents=True)
			debt = gf_maintenance.PackageArtifactSetError(
				"private artifact cleanup could not be proven"
			)
			debt.cleanup_debt = True
			debt.process_boundary_quiescent = False
			debt.preserved_paths = (staging,)

			with mock.patch.object(
				gf_maintenance.tempfile,
				"mkdtemp",
				return_value=str(owned_root),
			), mock.patch.object(
				gf_maintenance,
				"load_or_build_private_package_artifact_set",
				side_effect=debt,
			):
				with self.assertRaises(gf_maintenance.PackageArtifactSetError) as raised:
					gf_maintenance.package_build_boundary()

			self.assertIs(raised.exception, debt)
			self.assertTrue(gf_maintenance.exception_has_cleanup_debt(raised.exception))
			self.assertTrue(staging.is_dir())

	def test_package_build_boundary_retains_replaced_published_artifact_root(self) -> None:
		artifact_module = gf_maintenance.gf_package_artifact_set
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			source_root = root / "source"
			source_root.mkdir()
			manifest_path = source_root / artifact_module.MANIFEST_FILENAME
			manifest_path.write_text("{}\n", encoding="utf-8")
			source = artifact_module.PackageArtifactSet(
				root=source_root,
				manifest_path=manifest_path,
				manifest_sha256="a" * 64,
				workspace_state={},
				artifacts=(),
				builder_result={},
			)
			owned_root = root / "owned"
			owned_root.mkdir()
			target = owned_root / "artifact-consumer"
			published_original = owned_root / "published-original"
			replacement_marker = target / "replacement.txt"
			primary = artifact_module.PackageArtifactSetError(
				"published private artifact validation failed"
			)
			load_count = 0

			def replace_before_final_validation(*_args: object, **_kwargs: object) -> object:
				nonlocal load_count
				load_count += 1
				if load_count == 1:
					return source
				target.rename(published_original)
				target.mkdir()
				replacement_marker.write_text("retained", encoding="utf-8")
				raise primary

			def materialize_private_set(
				_temp_root: Path,
				consumer_root: Path,
				*_args: object,
				**_kwargs: object,
			) -> object:
				return artifact_module.materialize_package_artifact_set(source, consumer_root)

			with (
				mock.patch.object(
					artifact_module,
					"revalidate_package_artifact_set",
					return_value=source,
				),
				mock.patch.object(
					artifact_module,
					"load_package_artifact_set",
					side_effect=replace_before_final_validation,
				),
				mock.patch.object(artifact_module.secrets, "token_hex", return_value="deadbeef"),
				mock.patch.object(
					gf_maintenance.tempfile,
					"mkdtemp",
					return_value=str(owned_root),
				),
				mock.patch.object(
					gf_maintenance,
					"load_or_build_private_package_artifact_set",
					side_effect=materialize_private_set,
				),
			):
				with self.assertRaises(artifact_module.PackageArtifactSetError) as raised:
					gf_maintenance.package_build_boundary()

			self.assertIs(raised.exception, primary)
			self.assertTrue(gf_maintenance.exception_has_cleanup_debt(raised.exception))
			self.assertEqual(raised.exception.preserved_paths, (target,))
			self.assertTrue(owned_root.is_dir())
			self.assertTrue(
				(published_original / artifact_module.MANIFEST_FILENAME).is_file()
			)
			self.assertEqual(replacement_marker.read_text(encoding="utf-8"), "retained")

	def test_process_boundary_temp_cleans_handled_non_debt_failure(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			owned_root = Path(temporary_directory) / "owned"
			owned_root.mkdir()
			with mock.patch.object(
				gf_maintenance.tempfile,
				"mkdtemp",
				return_value=str(owned_root),
			), mock.patch.object(
				gf_maintenance,
				"load_or_build_private_package_artifact_set",
				side_effect=gf_maintenance.PackageArtifactSetError(
					"ordinary closed artifact failure"
				),
			):
				report = gf_maintenance.package_build_boundary()
			self.assertFalse(report["ok"])
			self.assertFalse(owned_root.exists())

	def test_maintenance_subprocess_requires_positive_process_boundary_proof(self) -> None:
		unproved = gf_maintenance.gf_process_supervisor.SupervisedProcessResult(
			return_code=0,
			stdout="",
			stderr="",
			timed_out=False,
			duration_seconds=0.1,
			pid=101,
			process_boundary_quiescent=False,
		)
		with mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			return_value=unproved,
		):
			with self.assertRaisesRegex(
				gf_maintenance.WorkspaceSnapshotError,
				"process-boundary cleanup was not proven",
			):
				gf_maintenance.run_maintenance_subprocess(
					[sys.executable, "-c", "pass"],
					timeout_seconds=1.0,
					process_environment=_SHARED_PROCESS_AUTHORITY.environment,
				)

	def test_maintenance_subprocess_reuses_one_frozen_environment(self) -> None:
		declared_command = [sys.executable, "-c", "pass"]
		frozen_environment = {
			"PATH": "frozen-subprocess-path",
			"FROZEN_MARKER": "captured",
		}
		quiet_result = gf_maintenance.gf_process_supervisor.SupervisedProcessResult(
			return_code=0,
			stdout="",
			stderr="",
			timed_out=False,
			duration_seconds=0.1,
			pid=101,
			process_boundary_quiescent=True,
		)
		with mock.patch.dict(
			gf_maintenance.os.environ,
			{"PATH": "ambient-path", "AMBIENT_ONLY": "must-not-leak"},
			clear=True,
		), mock.patch.object(
			gf_maintenance,
			"resolve_command_identity",
			return_value=gf_maintenance.CommandIdentity(
				declared=tuple(declared_command),
				effective=tuple(declared_command),
			),
		) as resolver, mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			return_value=quiet_result,
		) as supervisor:
			completed = gf_maintenance.run_maintenance_subprocess(
				declared_command,
				timeout_seconds=1.0,
				process_environment=_frozen_process_environment(frozen_environment),
			)

		resolver_environment = resolver.call_args.kwargs["environment"]
		dispatch_environment = supervisor.call_args.kwargs["environment"]
		self.assertIs(resolver_environment, dispatch_environment)
		self.assertIsNot(resolver_environment, frozen_environment)
		self.assertEqual(resolver_environment["PATH"], "frozen-subprocess-path")
		self.assertEqual(resolver_environment["FROZEN_MARKER"], "captured")
		self.assertNotIn("AMBIENT_ONLY", resolver_environment)
		self.assertEqual(frozen_environment["PATH"], "frozen-subprocess-path")
		self.assertEqual(resolver.call_args.kwargs["cwd"], gf_maintenance.ROOT)
		self.assertEqual(supervisor.call_args.kwargs["cwd"], gf_maintenance.ROOT)
		self.assertEqual(completed.returncode, 0)

	def test_maintenance_subprocess_scrubs_default_observation_authority(self) -> None:
		declared_command = [sys.executable, "-c", "pass"]
		nonce_name = gf_maintenance.GUT_SHARD_OBSERVATION_NONCE_ENVIRONMENT
		path_name = gf_maintenance.GUT_SHARD_OBSERVATION_PATH_ENVIRONMENT
		ambient_environment = {
			"PATH": "ambient-path",
			nonce_name: "canonical-stale-nonce",
			"gF_gUt_ShArD_oBsErVaTiOn_NoNcE": "mixed-stale-nonce",
			path_name: "canonical-stale-path",
			"gF_gUt_ShArD_oBsErVaTiOn_PaTh": "mixed-stale-path",
		}
		ambient_snapshot = dict(ambient_environment)
		real_remover = gf_executable_resolution.remove_owned_environment_value
		quiet_result = gf_process_supervisor.SupervisedProcessResult(
			return_code=0,
			stdout="",
			stderr="",
			timed_out=False,
			duration_seconds=0.1,
			pid=101,
			process_boundary_quiescent=True,
		)

		def remove_as_windows(
			environment: dict[str, str],
			name: str,
			*,
			platform_name: str | None = None,
		) -> None:
			real_remover(environment, name, platform_name="nt")

		with mock.patch.object(
			gf_maintenance.os,
			"environ",
			ambient_environment,
		), mock.patch.object(
			gf_maintenance,
			"remove_owned_environment_value",
			side_effect=remove_as_windows,
		), mock.patch.object(
			gf_maintenance,
			"resolve_command_identity",
			return_value=gf_maintenance.CommandIdentity(
				declared=tuple(declared_command),
				effective=tuple(declared_command),
			),
		) as resolver, mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			return_value=quiet_result,
		) as supervisor:
			process_environment = _frozen_process_environment(
				gf_maintenance.capture_maintenance_process_environment()
			)
			completed = gf_maintenance.run_maintenance_subprocess(
				declared_command,
				timeout_seconds=1.0,
				process_environment=process_environment,
			)

		resolver_environment = resolver.call_args.kwargs["environment"]
		self.assertIs(
			resolver_environment,
			supervisor.call_args.kwargs["environment"],
		)
		for scrubbed_name in (nonce_name, path_name):
			self.assertFalse(any(
				name.casefold() == scrubbed_name.casefold()
				for name in resolver_environment
			))
		self.assertEqual(ambient_environment, ambient_snapshot)
		self.assertEqual(completed.returncode, 0)

	def test_maintenance_subprocess_restores_proven_no_child_start_errors(self) -> None:
		for original_error in (
			FileNotFoundError("fixture missing executable"),
			PermissionError("fixture executable denied"),
		):
			with self.subTest(error=type(original_error).__name__), mock.patch.object(
				gf_maintenance,
				"run_supervised_process",
				side_effect=(
					gf_maintenance.gf_process_supervisor.SupervisedProcessStartError(
						original_error
					)
				),
			):
				with self.assertRaises(type(original_error)) as raised:
					gf_maintenance.run_maintenance_subprocess(
						[sys.executable, "-c", "pass"],
						timeout_seconds=1.0,
						process_environment=_SHARED_PROCESS_AUTHORITY.environment,
					)
			self.assertIs(raised.exception, original_error)

	def test_maintenance_subprocess_rejects_unproved_raw_os_errors(self) -> None:
		for original_error in (
			FileNotFoundError("fixture unproved missing executable"),
			PermissionError("fixture unproved executable denial"),
			OSError("fixture partial-start cleanup debt"),
			RuntimeError("fixture runtime cleanup debt"),
		):
			with self.subTest(error=type(original_error).__name__), mock.patch.object(
				gf_maintenance,
				"run_supervised_process",
				side_effect=original_error,
			):
				with self.assertRaises(
					gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError,
				) as raised:
					gf_maintenance.run_maintenance_subprocess(
						[sys.executable, "-c", "pass"],
						timeout_seconds=1.0,
						process_environment=_SHARED_PROCESS_AUTHORITY.environment,
					)
			self.assertIs(raised.exception.__cause__, original_error)

	def test_parallel_full_boundary_debt_retains_artifact_and_validation_roots(self) -> None:
		workspace_state = {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "b" * 64,
		}
		captured = gf_maintenance.CapturedWorkspace(
			source_root=gf_maintenance.ROOT,
			head="a" * 40,
			binary_diff=b"",
			untracked_files=(),
			workspace_fingerprint="b" * 64,
		)
		retained_roots: dict[str, Path] = {}
		with tempfile.TemporaryDirectory() as temporary_directory:
			temp_root = Path(temporary_directory)

			def materialize(
				_captured: object,
				target: Path,
				**_kwargs: object,
			) -> Path:
				target.mkdir()
				retained_roots["artifact"] = target.parent
				return target

			def build_artifact(artifact_root: Path, *_args: object, **_kwargs: object) -> object:
				artifact_root.mkdir()
				artifact = mock.Mock()
				artifact.manifest_path = artifact_root / "manifest.json"
				artifact.manifest_sha256 = "c" * 64
				artifact.artifacts = (mock.Mock(),)
				return artifact

			def fail_parallel(
				_captured: object,
				parallel_root: Path,
				**kwargs: object,
			) -> object:
				retained_roots["validation"] = parallel_root
				kwargs["cleanup_state"]["permitted"] = False
				raise gf_maintenance.WorkspaceSnapshotError(
					"synthetic unproved Full consumer process boundary"
				)

			with mock.patch.dict(
				os.environ,
				{
					gf_maintenance.MAINTENANCE_VALIDATION_TEMP_ROOT_ENV_VAR: str(temp_root),
				},
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				return_value=workspace_state,
			), mock.patch.object(
				gf_maintenance,
				"expanded_check_names",
				return_value=["package_build_boundary"],
			), mock.patch.object(
				gf_maintenance,
				"resolve_check_jobs",
				return_value=2,
			), mock.patch.object(
				gf_maintenance,
				"WINDOWS_PARALLEL_VALIDATION_ROOT_MAX_CHARACTERS",
				260,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"capture_workspace",
				return_value=captured,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"materialize_workspace",
				side_effect=materialize,
			), mock.patch.object(
				gf_maintenance,
				"build_package_smoke_artifact_set",
				side_effect=build_artifact,
			), mock.patch.object(
				gf_maintenance,
				"run_parallel_full_checks",
				side_effect=fail_parallel,
			), mock.patch.object(
				gf_maintenance,
				"package_artifact_details",
				return_value={"retained_fixture": True},
			):
				result = gf_maintenance.run_checks(
					checks=["package_build_boundary"],
					jobs=2,
				)
			self.assertFalse(result["ok"])
			self.assertTrue(retained_roots["artifact"].exists())
			self.assertIn("validation", retained_roots, result)
			self.assertTrue(retained_roots["validation"].exists())
			self.assertIn(
				"temporary_workspace_cleanup",
				{item["name"] for item in result["results"]},
			)

	def test_workspace_snapshot_keeps_only_the_current_live_identity(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			path = Path(temporary_directory) / "value.txt"
			path.write_text("a", encoding="utf-8")
			snapshot = gf_workspace_snapshot.WorkspaceSnapshot(Path(temporary_directory))
			self.assertEqual(snapshot.read_utf8_text_strict(path), "a")
			path.write_text("longer", encoding="utf-8")
			self.assertEqual(snapshot.read_utf8_text_strict(path), "longer")
			self.assertEqual(snapshot.stats()["text_entry_count"], 1)

	def test_read_only_suite_rejects_ending_workspace_drift(self) -> None:
		initial = {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "a" * 64,
		}
		ending = {**initial, "dirty": True, "fingerprint": "b" * 64}
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=[initial, ending],
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			return_value=_in_process_adapter_registry_with(
				docs=lambda: {"ok": True}
			),
		):
			result = gf_maintenance.run_checks(checks=["docs"], jobs=1)
		self.assertFalse(result["ok"])
		self.assertIn(
			"workspace_snapshot_integrity",
			[item["name"] for item in result["results"]],
		)

	def test_plugin_cfg_uses_the_shared_containment_policy(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			addon_root = root / "addons/gf"
			addon_root.mkdir(parents=True)
			(addon_root / "plugin.cfg").write_text(
				'[plugin]\nname="GF"\nscript="plugin.gd"\n',
				encoding="utf-8",
			)
			(addon_root / "plugin.gd").write_text("@tool\nextends EditorPlugin\n", encoding="utf-8")
			with mock.patch.object(gf_maintenance, "ROOT", root), mock.patch.object(
				gf_maintenance.gf_path_security,
				"path_is_inside",
				return_value=False,
			) as containment:
				report = gf_maintenance.audit_plugin_cfg()
			self.assertFalse(report["script_inside_addon"])
			containment.assert_called_once_with(addon_root, addon_root / "plugin.gd")


class ValidationShadowIntegrationTests(unittest.TestCase):
	def _workspace_state(self) -> dict[str, object]:
		return {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "a" * 64,
		}

	def _inventory(self) -> dict[str, object]:
		return {
			"schema_version": 1,
			"discovery_contract_version": 2,
			"root": "tests/gf_core",
			"capture_complete": True,
			"entry_count": 4,
			"file_count": 2,
			"method_count": 3,
			"source_bytes": 128,
			"source_manifest_sha256": "b" * 64,
			"test_list_sha256": "c" * 64,
			"inventory_sha256": "d" * 64,
			"files": [],
		}

	def test_default_check_execution_does_not_collect_shadow_inventory(self) -> None:
		workspace_state = self._workspace_state()
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value=workspace_state,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			return_value=_in_process_adapter_registry_with(
				docs=lambda: {"ok": True}
			),
		), mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
		) as inventory:
			result = gf_maintenance.run_checks(checks=["docs"], jobs=1)
		self.assertTrue(result["ok"])
		self.assertNotIn("validation_shadow", result)
		inventory.assert_not_called()

	def test_shadow_observes_one_real_execution_but_never_reuses_it(self) -> None:
		workspace_state = self._workspace_state()
		runner = mock.Mock(return_value={"ok": True})
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value=workspace_state,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			return_value=_in_process_adapter_registry_with(docs=runner),
		), mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			return_value=self._inventory(),
		):
			result = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				validation_shadow=True,
			)
		self.assertTrue(result["ok"])
		runner.assert_called_once_with()
		shadow = result["validation_shadow"]
		self.assertTrue(shadow["report_ok"])
		self.assertFalse(shadow["authoritative"])
		self.assertFalse(shadow["scheduling_effect"])
		self.assertFalse(shadow["reuse_permitted"])
		self.assertEqual(shadow["executed_action_count"], 1)
		self.assertEqual(shadow["execution_observation_count"], 1)
		self.assertEqual(shadow["reused_count"], 0)
		action = shadow["actions"][0]
		self.assertFalse(action["policy"]["declared"])
		material = action["shadow_evidence"]["action_key_material"]
		self.assertFalse(material["input_complete"])
		self.assertIn(
			"inventory_not_bound_to_immutable_snapshot",
			material["unknown_reasons"],
		)
		decision = action["shadow_evidence"]["acceptance_decision"]
		self.assertEqual(decision["decision"], "execute")
		self.assertEqual(decision["acceptance"], "shadow_only")
		self.assertFalse(decision["structurally_reusable_candidate"])

	def test_shadow_inventory_failure_does_not_change_suite_result(self) -> None:
		workspace_state = self._workspace_state()
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value=workspace_state,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			return_value=_in_process_adapter_registry_with(
				docs=lambda: {"ok": True}
			),
		), mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			side_effect=RuntimeError("injected inventory failure"),
		):
			result = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				validation_shadow=True,
			)
		self.assertTrue(result["ok"])
		self.assertEqual(len(result["results"]), 1)
		shadow = result["validation_shadow"]
		self.assertFalse(shadow["report_ok"])
		self.assertEqual(
			frozenset(shadow),
			gf_maintenance.VALIDATION_SHADOW_REPORT_FIELDS,
		)
		self.assertEqual(shadow["fallback_decision"], "execute")
		self.assertEqual(shadow["reused_count"], 0)
		self.assertEqual(shadow["errors"], ["shadow_internal_error"])
		self.assertIsNone(shadow["test_inventory"])
		self.assertEqual(len(shadow["report_fingerprint"]), 64)

	def test_shadow_success_and_failure_use_the_same_exact_envelope(self) -> None:
		workspace_state = self._workspace_state()
		data = {
			"ok": True,
			"suite": "quick",
			"checks": ["docs"],
			"results": [],
		}
		with mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			return_value=self._inventory(),
		):
			gf_maintenance.attach_validation_shadow_report(
				data,
				workspace_state,
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
			)
		success = data["validation_shadow"]
		failure = gf_maintenance.make_validation_shadow_failure_report(
			data,
			"inventory_capture_failed",
		)
		self.assertEqual(frozenset(success), frozenset(failure))
		self.assertEqual(
			frozenset(success),
			gf_maintenance.VALIDATION_SHADOW_REPORT_FIELDS,
		)

	def test_shadow_private_deadline_covers_post_inventory_report_work(self) -> None:
		workspace_state = self._workspace_state()
		data = {
			"ok": True,
			"suite": "quick",
			"checks": ["docs"],
			"results": [],
		}
		with mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			return_value=self._inventory(),
		), mock.patch.object(
			gf_maintenance.time,
			"monotonic",
			side_effect=[0.0, 2.0],
		):
			with self.assertRaisesRegex(
				gf_maintenance.ValidationShadowDeadlineError,
				"deadline",
			):
				gf_maintenance.make_validation_shadow_report(
					data,
					workspace_state,
					validation_catalog=gf_maintenance._VALIDATION_CATALOG,
					shadow_deadline_seconds=1.0,
				)

	def test_advisory_deadline_translates_and_caps_the_suite_clock(self) -> None:
		with mock.patch.object(
			gf_maintenance.time,
			"monotonic",
			return_value=1_000.0,
		), mock.patch.object(
			gf_maintenance.time,
			"perf_counter",
			return_value=100.0,
		):
			self.assertEqual(
				gf_maintenance.advisory_collection_deadline(15.0, 104.0),
				1_004.0,
			)
			self.assertEqual(
				gf_maintenance.advisory_collection_deadline(15.0, None),
				1_015.0,
			)

	def test_shadow_attachment_uses_the_suite_capped_deadline(self) -> None:
		data = {"checks": ["docs"]}
		workspace_state = self._workspace_state()
		with mock.patch.object(
			gf_maintenance,
			"advisory_collection_deadline",
			return_value=123.0,
		) as deadline, mock.patch.object(
			gf_maintenance,
			"make_validation_shadow_report",
			return_value={"report_ok": True},
		) as make_report:
			gf_maintenance.attach_validation_shadow_report(
				data,
				workspace_state,
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
				suite_deadline=50.0,
			)
		deadline.assert_called_once_with(
			gf_maintenance.VALIDATION_SHADOW_COLLECTION_TIMEOUT_SECONDS,
			50.0,
		)
		self.assertEqual(make_report.call_args.kwargs["shadow_deadline_seconds"], 123.0)

	def test_exhausted_suite_budget_makes_shadow_fail_closed_immediately(self) -> None:
		data = {"checks": ["docs"]}
		with mock.patch.object(
			gf_maintenance,
			"advisory_collection_deadline",
			return_value=10.0,
		), mock.patch.object(
			gf_maintenance.time,
			"monotonic",
			return_value=10.0,
		), mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
		) as inventory:
			gf_maintenance.attach_validation_shadow_report(
				data,
				self._workspace_state(),
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
				suite_deadline=1.0,
			)
		self.assertEqual(data["validation_shadow"]["errors"], ["shadow_deadline_exceeded"])
		inventory.assert_not_called()

	def test_ordinary_dependency_pass_does_not_change_shadow_action_key(self) -> None:
		workspace_state = self._workspace_state()

		def report(dependency_fingerprint: str) -> dict[str, object]:
			data = {
				"ok": True,
				"suite": "quick",
				"checks": ["docs"],
				"results": [{
					"name": "docs",
					"command": ["python", "check.py"],
					"execution": "in_process",
					"exit_code": 0,
					"timed_out": False,
					"cancelled": False,
					"duration_seconds": 0.1,
					"dependency_fingerprints": {"api": dependency_fingerprint},
					"result_fingerprint": "e" * 64,
				}],
			}
			with mock.patch.object(
				gf_maintenance.gf_validation_test_inventory,
				"collect_test_inventory",
				return_value=self._inventory(),
			):
				return gf_maintenance.make_validation_shadow_report(
					data,
					workspace_state,
					validation_catalog=gf_maintenance._VALIDATION_CATALOG,
				)

		first = report("1" * 64)
		second = report("2" * 64)
		first_evidence = first["actions"][0]["shadow_evidence"]
		second_evidence = second["actions"][0]["shadow_evidence"]
		self.assertEqual(first_evidence["action_key"], second_evidence["action_key"])
		self.assertEqual(
			first_evidence["action_key_material"]["dependency_artifacts"],
			{},
		)

	def test_package_artifact_action_key_uses_digest_not_ephemeral_path(self) -> None:
		workspace_state = self._workspace_state()

		def report(manifest_path: str, digest: str) -> dict[str, object]:
			data = {
				"ok": True,
				"suite": "package-contract",
				"checks": ["package_build_boundary"],
				"package_artifact_set": {
					"reused": False,
					"manifest_sha256": digest,
					"artifact_count": 1,
					"workspace_fingerprint": "a" * 64,
				},
				"results": [{
					"name": "package_build_boundary",
					"command": [
						"python",
						"tools/gf_maintenance.py",
						"package-build-boundary",
						"--package-artifact-manifest",
						manifest_path,
						"--package-artifact-manifest-sha256",
						digest,
					],
					"execution": "in_process",
					"exit_code": 0,
					"timed_out": False,
					"cancelled": False,
					"duration_seconds": 0.1,
					"result_fingerprint": "e" * 64,
				}],
			}
			with mock.patch.object(
				gf_maintenance.gf_validation_test_inventory,
				"collect_test_inventory",
				return_value=self._inventory(),
			):
				return gf_maintenance.make_validation_shadow_report(
					data,
					workspace_state,
					validation_catalog=gf_maintenance._VALIDATION_CATALOG,
				)

		first = report("C:/temp/gfa-one/manifest.json", "1" * 64)
		second = report("C:/temp/gfa-two/manifest.json", "1" * 64)
		changed = report("C:/temp/gfa-two/manifest.json", "2" * 64)
		first_evidence = first["actions"][0]["shadow_evidence"]
		second_evidence = second["actions"][0]["shadow_evidence"]
		changed_evidence = changed["actions"][0]["shadow_evidence"]
		self.assertEqual(first_evidence["action_key"], second_evidence["action_key"])
		self.assertNotEqual(first_evidence["action_key"], changed_evidence["action_key"])
		material = first_evidence["action_key_material"]
		self.assertIn(
			gf_maintenance.PACKAGE_ARTIFACT_MANIFEST_ACTION_SENTINEL,
			material["command"],
		)
		self.assertNotIn("C:/temp/gfa-one/manifest.json", material["command"])
		self.assertEqual(
			material["dependency_artifacts"],
			{gf_maintenance.PACKAGE_ARTIFACT_MANIFEST_DEPENDENCY_LABEL: "1" * 64},
		)
		with self.assertRaisesRegex(ValueError, "differs from the parent"):
			gf_maintenance.validation_shadow_action_inputs(
				{"package_artifact_set": {
					"reused": False,
					"manifest_sha256": "1" * 64,
					"artifact_count": 1,
					"workspace_fingerprint": "a" * 64,
				}},
				"package_build_boundary",
				[
					"python",
					"--package-artifact-manifest",
					"C:/temp/gfa/manifest.json",
					"--package-artifact-manifest-sha256",
					"2" * 64,
				],
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
				workspace_digest="a" * 64,
				allow_planned_command=False,
			)
		malformed_commands = (
			[
				"python",
				"--package-artifact-manifest",
				"--package-artifact-manifest-sha256",
				"1" * 64,
			],
			[
				"python",
				"--package-artifact-manifest-sha256",
				"1" * 64,
				"--package-artifact-manifest",
				"manifest.json",
			],
			[
				"python",
				"--package-artifact-manifest",
				"one.json",
				"--package-artifact-manifest",
				"two.json",
				"--package-artifact-manifest-sha256",
				"1" * 64,
			],
		)
		artifact_data = {
			"package_artifact_set": {
				"reused": False,
				"manifest_sha256": "1" * 64,
				"artifact_count": 1,
				"workspace_fingerprint": "a" * 64,
			},
		}
		for command in malformed_commands:
			with self.subTest(command=command):
				with self.assertRaises(ValueError):
					gf_maintenance.validation_shadow_action_inputs(
						artifact_data,
						"package_build_boundary",
						command,
						validation_catalog=gf_maintenance._VALIDATION_CATALOG,
						workspace_digest="a" * 64,
						allow_planned_command=False,
					)

	def test_unstarted_package_action_uses_a_stable_planned_command(self) -> None:
		workspace_state = self._workspace_state()
		data = {
			"ok": False,
			"suite": "full",
			"checks": ["package_build_boundary"],
			"package_artifact_set": {
				"reused": False,
				"manifest_sha256": "1" * 64,
				"artifact_count": 1,
				"workspace_fingerprint": "a" * 64,
			},
			"results": [{
				"name": "package_build_boundary",
				"command": ["python", "tools/gf_maintenance.py", "package-build-boundary"],
				"execution": "not_started",
				"exit_code": 124,
				"timed_out": True,
				"cancelled": False,
				"duration_seconds": 0.0,
			}],
		}
		with mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			return_value=self._inventory(),
		):
			report = gf_maintenance.make_validation_shadow_report(
				data,
				workspace_state,
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
			)
		action = report["actions"][0]
		self.assertFalse(action["execution_observed"])
		material = action["shadow_evidence"]["action_key_material"]
		self.assertIn(
			gf_maintenance.PACKAGE_ARTIFACT_MANIFEST_ACTION_SENTINEL,
			material["command"],
		)
		self.assertEqual(
			material["dependency_artifacts"],
			{gf_maintenance.PACKAGE_ARTIFACT_MANIFEST_DEPENDENCY_LABEL: "1" * 64},
		)

	def test_unstarted_deferred_subprocess_is_not_labeled_in_process(self) -> None:
		workspace_state = self._workspace_state()
		data = {
			"ok": False,
			"suite": "release",
			"checks": ["release_metadata"],
			"results": [],
		}
		with mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			return_value=self._inventory(),
		):
			report = gf_maintenance.make_validation_shadow_report(
				data,
				workspace_state,
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
			)

		command = report["actions"][0]["shadow_evidence"]["action_key_material"][
			"command"
		]
		self.assertEqual(
			command,
			[
				gf_maintenance.DEFERRED_COMMAND_SENTINEL,
				"subprocess",
				"release_metadata",
			],
		)

	def test_empty_observed_command_fails_shadow_closed(self) -> None:
		workspace_state = self._workspace_state()
		data = {
			"ok": False,
			"suite": "release",
			"checks": ["release_metadata"],
			"results": [{
				"name": "release_metadata",
				"command": [],
				"execution": "subprocess",
				"exit_code": 1,
				"timed_out": False,
				"cancelled": False,
				"duration_seconds": 0.0,
				"result_fingerprint": "e" * 64,
			}],
		}
		with mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			return_value=self._inventory(),
		), self.assertRaises(ValueError):
			gf_maintenance.make_validation_shadow_report(
				data,
				workspace_state,
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
			)

	def test_shadow_failure_never_stringifies_untrusted_exception(self) -> None:
		class HostileError(RuntimeError):
			def __str__(self) -> str:
				raise AssertionError("exception text must not be observed")

		workspace_state = self._workspace_state()
		data = {"suite": "quick", "checks": ["docs"], "results": []}
		with mock.patch.object(
			gf_maintenance,
			"make_validation_shadow_report",
			side_effect=HostileError(),
		):
			gf_maintenance.attach_validation_shadow_report(
				data,
				workspace_state,
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
			)
		shadow = data["validation_shadow"]
		self.assertEqual(shadow["errors"], ["shadow_internal_error"])
		json.dumps(shadow, allow_nan=False)

	def test_shadow_attachment_preserves_cleanup_debt_identity(self) -> None:
		debt = gf_process_supervisor.SupervisedProcessCleanupError(
			"fixture shadow cleanup debt",
			pid=123,
			process_tree_empty=False,
		)
		workspace_state = self._workspace_state()
		data = {"suite": "quick", "checks": ["docs"], "results": []}
		with mock.patch.object(
			gf_maintenance,
			"make_validation_shadow_report",
			side_effect=debt,
		):
			with self.assertRaises(
				gf_process_supervisor.SupervisedProcessCleanupError
			) as raised:
				gf_maintenance.attach_validation_shadow_report(
					data,
					workspace_state,
					validation_catalog=gf_maintenance._VALIDATION_CATALOG,
				)

		self.assertIs(raised.exception, debt)
		self.assertTrue(raised.exception.cleanup_debt)
		self.assertFalse(raised.exception.process_boundary_quiescent)
		self.assertNotIn("validation_shadow", data)

	def test_initial_workspace_failure_gets_exact_zero_io_shadow_envelope(self) -> None:
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=gf_maintenance.gf_maintenance_check_graph.WorkspaceFingerprintSetupError(
				"fixture failure"
			),
		), mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
		) as inventory:
			result = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				validation_shadow=True,
			)
		self.assertFalse(result["ok"])
		shadow = result["validation_shadow"]
		self.assertEqual(shadow["errors"], ["workspace_fingerprint_setup_failed"])
		self.assertEqual(shadow["execution_observation_count"], 0)
		self.assertIsNone(shadow["test_inventory"])
		inventory.assert_not_called()

	def test_initial_workspace_process_control_exception_propagates(self) -> None:
		for error in (
			KeyboardInterrupt("fixture interrupt"),
			SystemExit(7),
			GeneratorExit("fixture generator exit"),
		):
			with self.subTest(error=type(error).__name__), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				side_effect=error,
			):
				with self.assertRaises(type(error)) as raised:
					gf_maintenance.run_checks(
						checks=["docs"],
						jobs=1,
						validation_shadow=True,
					)
			self.assertIs(raised.exception, error)

	def test_shadow_attaches_only_after_workspace_revalidation_and_result_freeze(self) -> None:
		workspace_state = self._workspace_state()
		events: list[str] = []

		def fingerprint(*_args: object, **_kwargs: object) -> dict[str, object]:
			events.append("workspace_fingerprint")
			return workspace_state

		def attach(
			data: dict[str, object],
			state: dict[str, object],
			**_kwargs: object,
		) -> None:
			events.append("validation_shadow")
			self.assertIs(state, workspace_state)
			self.assertEqual(data["workspace"], workspace_state)
			self.assertIn("workspace_snapshot", data)
			self.assertIn("duration_seconds", data)
			data["validation_shadow"] = {"report_ok": True}

		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=fingerprint,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			return_value=_in_process_adapter_registry_with(
				docs=lambda: {"ok": True}
			),
		), mock.patch.object(
			gf_maintenance,
			"attach_validation_shadow_report",
			side_effect=attach,
		):
			result = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				validation_shadow=True,
			)

		self.assertTrue(result["ok"])
		self.assertEqual(
			events,
			[
				"workspace_fingerprint",
				"workspace_fingerprint",
				"validation_shadow",
			],
		)

	def test_shadow_does_not_invent_evidence_for_blocked_action(self) -> None:
		workspace_state = self._workspace_state()
		data = {
			"ok": False,
			"suite": "quick",
			"checks": ["gut"],
			"results": [{
				"name": "gut",
				"command": ["godot"],
				"execution": "blocked",
				"exit_code": 125,
				"timed_out": False,
				"cancelled": False,
				"duration_seconds": 0.0,
				"dependency_fingerprints": {},
			}],
		}
		with mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			return_value=self._inventory(),
		):
			gf_maintenance.attach_validation_shadow_report(
				data,
				workspace_state,
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
			)
		shadow = data["validation_shadow"]
		self.assertEqual(shadow["executed_action_count"], 0)
		self.assertEqual(shadow["non_execution_action_count"], 1)
		self.assertEqual(
			shadow["actions"][0]["shadow_evidence"]["evidence"],
			[],
		)
		decision = shadow["actions"][0]["shadow_evidence"]["acceptance_decision"]
		self.assertEqual(decision["decision"], "execute")
		self.assertEqual(decision["reason_code"], "no_evidence")

	def test_parallel_occurrences_are_all_observed_and_unproved_equivalence_conflicts(self) -> None:
		workspace_state = self._workspace_state()
		data = {
			"ok": True,
			"suite": "full",
			"checks": ["godot_import"],
			"results": [{
				"name": "godot_import",
				"command": ["godot", "--editor", "--quit"],
				"parallel_occurrences": [
					{
						"shard": "gut",
						"execution": "subprocess",
						"exit_code": 0,
						"timed_out": False,
						"cancelled": False,
						"duration_seconds": 1.0,
						"result_fingerprint": "e" * 64,
					},
					{
						"shard": "lsp",
						"execution": "subprocess",
						"exit_code": 0,
						"timed_out": False,
						"cancelled": False,
						"duration_seconds": 2.0,
						"result_fingerprint": "f" * 64,
					},
				],
			}],
		}
		with mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			return_value=self._inventory(),
		):
			gf_maintenance.attach_validation_shadow_report(
				data,
				workspace_state,
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
			)
		shadow = data["validation_shadow"]
		self.assertEqual(shadow["executed_action_count"], 1)
		self.assertEqual(shadow["execution_observation_count"], 2)
		evidence_report = shadow["actions"][0]["shadow_evidence"]
		self.assertEqual(evidence_report["execution_summary"]["executed"], 2)
		self.assertTrue(evidence_report["conflict"]["detected"])
		self.assertFalse(evidence_report["conflict"]["comparison_complete"])

	def test_parallel_public_occurrences_do_not_leak_shadow_execution_field(self) -> None:
		occurrences = [("gut", {
			"execution": "subprocess",
			"exit_code": 0,
			"timed_out": False,
			"cancelled": False,
			"duration_seconds": 1.0,
			"input_fingerprint": "e" * 64,
			"result_fingerprint": "f" * 64,
		})]
		public = gf_maintenance.serialize_parallel_occurrences(
			occurrences,
			include_execution=False,
		)
		shadow = gf_maintenance.serialize_parallel_occurrences(
			occurrences,
			include_execution=True,
		)
		self.assertNotIn("execution", public[0])
		self.assertEqual(shadow[0]["execution"], "subprocess")
		self.assertEqual(set(shadow[0]) - {"execution"}, set(public[0]))

	def test_parallel_deadline_preserves_completed_shadow_occurrences(self) -> None:
		workspace_state = self._workspace_state()
		observations: dict[str, list[dict[str, object]]] = {}
		plans = [
			_synthetic_parallel_shard_plan("first", ("docs",)),
			_synthetic_parallel_shard_plan("second", ("api",)),
		]

		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			(root / "parallel").mkdir()
			captured = gf_maintenance.CapturedWorkspace(
				source_root=root,
				head="a" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint=str(workspace_state["fingerprint"]),
			)

			def materialize(
				_captured: object,
				batch_root: Path,
				batch_plan: list[object],
				**_kwargs: object,
			) -> dict[str, Path]:
				workspaces: dict[str, Path] = {}
				for plan in batch_plan:
					workspace = batch_root / str(plan.name)
					workspace.mkdir()
					workspaces[str(plan.name)] = workspace
				return workspaces

			def make_shard(
				plan: object,
				workspace: Path,
				**_kwargs: object,
			) -> tuple[object, Path]:
				shard = gf_maintenance.ParallelShard(
					name=str(plan.name),
					command=(str(Path(sys.executable).resolve()), "-V"),
					workspace=workspace,
					timeout_seconds=1.0,
					environment={},
				)
				return shard, workspace / f"{plan.name}.json"

			def run_shards(shards: list[object], **_kwargs: object) -> list[object]:
				shard = shards[0]
				return [gf_maintenance.ParallelShardResult(
					name=str(shard.name),
					command=tuple(shard.command),
					workspace=shard.workspace,
					exit_code=0,
					process_exit_code=0,
					stdout="",
					stderr="",
					timed_out=False,
					cancelled=False,
					duration_seconds=1.0,
					pid=1,
					started=True,
					process_boundary_quiescent=True,
				)]

			report = {
				"ok": True,
				"results": [{
					"name": "docs",
					"execution": "subprocess",
					"exit_code": 0,
					"timed_out": False,
					"cancelled": False,
					"duration_seconds": 1.0,
					"input_fingerprint": "b" * 64,
					"result_fingerprint": "c" * 64,
				}],
			}
			with mock.patch.object(
				gf_maintenance,
				"parallel_full_shard_plan",
				return_value=plans,
			), mock.patch.object(
				gf_maintenance,
				"expanded_check_names",
				side_effect=AssertionError("parallel execution must consume its plan"),
			), mock.patch.object(
				gf_maintenance,
				"run_parallel_godot_isolation_probe",
				return_value={"ok": True},
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"assert_source_matches_snapshot",
				side_effect=[
					None,
					gf_maintenance.WorkspaceDeadlineError("injected deadline"),
				],
			), mock.patch.object(
				gf_maintenance,
				"materialize_parallel_full_workspaces",
				side_effect=materialize,
			), mock.patch.object(
				gf_maintenance,
				"make_parallel_full_shard",
				side_effect=make_shard,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"run_parallel_shards",
				side_effect=run_shards,
			), mock.patch.object(
				gf_maintenance,
				"load_parallel_shard_report",
				return_value=(report, ""),
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				return_value=workspace_state,
			):
				with self.assertRaises(gf_maintenance.WorkspaceDeadlineError):
					gf_maintenance.run_parallel_full_checks(
						captured,
						root / "parallel",
						validation_plan=_synthetic_full_validation_plan(plans),
						validation_catalog=gf_maintenance._VALIDATION_CATALOG,
						git_process=_SHARED_PROCESS_AUTHORITY.git,
						jobs=1,
						timeout_seconds=None,
						suite_timeout_seconds=None,
						fail_fast=False,
						package_artifact_manifest="manifest.json",
						package_artifact_manifest_sha256="d" * 64,
						package_artifact_count=1,
						progress_callback=None,
						output_callback=None,
						overall_started=0.0,
						suite_deadline=None,
						validation_occurrences_out=observations,
					)

		self.assertEqual(len(observations["docs"]), 1)
		self.assertEqual(observations["docs"][0]["execution"], "subprocess")
		data = {
			"ok": False,
			"suite": "full",
			"checks": ["docs", "api"],
			"results": [],
		}
		with mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			return_value=self._inventory(),
		):
			shadow = gf_maintenance.make_validation_shadow_report(
				data,
				workspace_state,
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
				parallel_occurrences=observations,
			)
		self.assertEqual(shadow["execution_observation_count"], 1)

	def test_parallel_full_unproven_boundary_keeps_cleanup_fail_closed(self) -> None:
		plan = [_synthetic_parallel_shard_plan("first", ("docs",))]
		cleanup_state = {"permitted": True}
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			parallel_root = root / "parallel"
			parallel_root.mkdir()
			captured = gf_maintenance.CapturedWorkspace(
				source_root=root,
				head="a" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint="b" * 64,
			)

			def materialize(
				_captured: object,
				batch_root: Path,
				_batch_plan: list[object],
				**_kwargs: object,
			) -> dict[str, Path]:
				workspace = batch_root / "first"
				workspace.mkdir()
				return {"first": workspace}

			def make_shard(
				_plan: object,
				workspace: Path,
				**_kwargs: object,
			) -> tuple[object, Path]:
				return (
					gf_maintenance.ParallelShard(
						name="first",
						command=(str(Path(sys.executable).resolve()), "-V"),
						workspace=workspace,
						timeout_seconds=1.0,
						environment={},
					),
					workspace / "report.json",
				)

			def run_shards(shards: list[object], **_kwargs: object) -> list[object]:
				shard = shards[0]
				return [gf_maintenance.ParallelShardResult(
					name=str(shard.name),
					command=tuple(shard.command),
					workspace=shard.workspace,
					exit_code=0,
					process_exit_code=0,
					stdout="",
					stderr="",
					timed_out=False,
					cancelled=False,
					duration_seconds=0.1,
					pid=1,
					started=True,
					process_boundary_quiescent=False,
				)]

			with mock.patch.object(
				gf_maintenance,
				"parallel_full_shard_plan",
				return_value=plan,
			), mock.patch.object(
				gf_maintenance,
				"expanded_check_names",
				side_effect=AssertionError("parallel execution must consume its plan"),
			), mock.patch.object(
				gf_maintenance,
				"run_parallel_godot_isolation_probe",
				return_value={"ok": True},
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"assert_source_matches_snapshot",
			), mock.patch.object(
				gf_maintenance,
				"materialize_parallel_full_workspaces",
				side_effect=materialize,
			), mock.patch.object(
				gf_maintenance,
				"make_parallel_full_shard",
				side_effect=make_shard,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"run_parallel_shards",
				side_effect=run_shards,
			), mock.patch.object(
				gf_maintenance,
				"load_parallel_shard_report",
			) as report_loader:
				with self.assertRaisesRegex(
					gf_maintenance.WorkspaceSnapshotError,
					"process-boundary cleanup",
				):
					gf_maintenance.run_parallel_full_checks(
						captured,
						parallel_root,
						validation_plan=_synthetic_full_validation_plan(plan),
						validation_catalog=gf_maintenance._VALIDATION_CATALOG,
						git_process=_SHARED_PROCESS_AUTHORITY.git,
						jobs=1,
						timeout_seconds=None,
						suite_timeout_seconds=None,
						fail_fast=False,
						package_artifact_manifest="manifest.json",
						package_artifact_manifest_sha256="d" * 64,
						package_artifact_count=1,
						progress_callback=None,
						output_callback=None,
						overall_started=time.perf_counter(),
						suite_deadline=time.perf_counter() + 10.0,
						cleanup_state=cleanup_state,
					)
			self.assertFalse(cleanup_state["permitted"])
			report_loader.assert_not_called()

	def test_parallel_full_log_copy_failure_retains_source_batch(self) -> None:
		plan = [_synthetic_parallel_shard_plan("first", ("docs",))]
		cleanup_state = {"permitted": True}
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			parallel_root = root / "parallel"
			parallel_root.mkdir()
			captured = gf_maintenance.CapturedWorkspace(
				source_root=root,
				head="a" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint="b" * 64,
			)
			retained_marker: Path | None = None

			def materialize(
				_captured: object,
				batch_root: Path,
				_batch_plan: list[object],
				**_kwargs: object,
			) -> dict[str, Path]:
				nonlocal retained_marker
				workspace = batch_root / "first"
				workspace.mkdir()
				retained_marker = workspace / "must-retain.log"
				retained_marker.write_text("source evidence", encoding="utf-8")
				return {"first": workspace}

			def make_shard(
				_plan: object,
				workspace: Path,
				**_kwargs: object,
			) -> tuple[object, Path]:
				return (
					gf_maintenance.ParallelShard(
						name="first",
						command=(str(Path(sys.executable).resolve()), "-V"),
						workspace=workspace,
						timeout_seconds=1.0,
						environment={},
					),
					workspace / "report.json",
				)

			def run_shards(shards: list[object], **_kwargs: object) -> list[object]:
				shard = shards[0]
				return [gf_maintenance.ParallelShardResult(
					name=str(shard.name),
					command=tuple(shard.command),
					workspace=shard.workspace,
					exit_code=1,
					process_exit_code=1,
					stdout="",
					stderr="synthetic failure",
					timed_out=False,
					cancelled=False,
					duration_seconds=0.1,
					pid=1,
					started=True,
					process_boundary_quiescent=True,
				)]

			report = {
				"ok": False,
				"results": [{
					"name": "docs",
					"exit_code": 1,
					"timed_out": False,
					"cancelled": False,
					"duration_seconds": 0.1,
				}],
			}
			with mock.patch.object(
				gf_maintenance,
				"parallel_full_shard_plan",
				return_value=plan,
			), mock.patch.object(
				gf_maintenance,
				"expanded_check_names",
				side_effect=AssertionError("parallel execution must consume its plan"),
			), mock.patch.object(
				gf_maintenance,
				"run_parallel_godot_isolation_probe",
				return_value={"ok": True},
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"assert_source_matches_snapshot",
			), mock.patch.object(
				gf_maintenance,
				"materialize_parallel_full_workspaces",
				side_effect=materialize,
			), mock.patch.object(
				gf_maintenance,
				"make_parallel_full_shard",
				side_effect=make_shard,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"run_parallel_shards",
				side_effect=run_shards,
			), mock.patch.object(
				gf_maintenance,
				"load_parallel_shard_report",
				return_value=(report, ""),
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				return_value={"fingerprint": "b" * 64},
			), mock.patch.object(
				gf_maintenance,
				"collect_parallel_failure_logs",
				return_value=["first: synthetic copy failure"],
			):
				with self.assertRaises(
					gf_maintenance.WorkspaceSnapshotError,
				) as raised:
					gf_maintenance.run_parallel_full_checks(
						captured,
						parallel_root,
						validation_plan=_synthetic_full_validation_plan(plan),
						validation_catalog=gf_maintenance._VALIDATION_CATALOG,
						git_process=_SHARED_PROCESS_AUTHORITY.git,
						jobs=1,
						timeout_seconds=None,
						suite_timeout_seconds=None,
						fail_fast=False,
						package_artifact_manifest="manifest.json",
						package_artifact_manifest_sha256="d" * 64,
						package_artifact_count=1,
						progress_callback=None,
						output_callback=None,
						overall_started=time.perf_counter(),
						suite_deadline=time.perf_counter() + 10.0,
						cleanup_state=cleanup_state,
					)
			self.assertIn("batch cleanup failed", str(raised.exception))
			self.assertIn("first: synthetic copy failure", str(raised.exception))
			self.assertFalse(cleanup_state["permitted"])
			self.assertIsNotNone(retained_marker)
			assert retained_marker is not None
			self.assertEqual(
				retained_marker.read_text(encoding="utf-8"),
				"source evidence",
			)

	def test_parallel_full_passing_batch_cleanup_failure_keeps_its_reason(self) -> None:
		plan = [
			_synthetic_parallel_shard_plan("first", ("docs",)),
			_synthetic_parallel_shard_plan("second", ("api",)),
		]
		cleanup_state = {"permitted": True}
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			parallel_root = root / "parallel"
			parallel_root.mkdir()
			captured = gf_maintenance.CapturedWorkspace(
				source_root=root,
				head="a" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint="b" * 64,
			)
			retained_marker: Path | None = None

			@contextlib.contextmanager
			def retained_batch(
				path: Path,
				**kwargs: object,
			) -> object:
				path.mkdir()
				try:
					yield path
				finally:
					cleanup_errors = kwargs["cleanup_errors"]
					assert isinstance(cleanup_errors, list)
					cleanup_errors.append("synthetic passing-batch cleanup failure")
					cleanup_failed = kwargs["cleanup_failed"]
					assert callable(cleanup_failed)
					cleanup_failed()

			def materialize(
				_captured: object,
				batch_root: Path,
				batch_plan: list[object],
				**_kwargs: object,
			) -> dict[str, Path]:
				nonlocal retained_marker
				workspaces: dict[str, Path] = {}
				for shard_plan in batch_plan:
					name = str(shard_plan.name)
					workspace = batch_root / name
					workspace.mkdir()
					workspaces[name] = workspace
					if name == "first":
						retained_marker = workspace / "must-retain.log"
						retained_marker.write_text("source evidence", encoding="utf-8")
				return workspaces

			def make_shard(
				shard_plan: object,
				workspace: Path,
				**_kwargs: object,
			) -> tuple[object, Path]:
				name = str(shard_plan.name)
				return (
					gf_maintenance.ParallelShard(
						name=name,
						command=(str(Path(sys.executable).resolve()), "-V"),
						workspace=workspace,
						timeout_seconds=1.0,
						environment={},
					),
					workspace / f"{name}.json",
				)

			report = {
				"ok": True,
				"results": [{
					"name": "docs",
					"exit_code": 0,
					"timed_out": False,
					"cancelled": False,
					"duration_seconds": 0.1,
				}],
			}
			shard_result = gf_maintenance.ParallelShardResult(
				name="first",
				command=(str(Path(sys.executable).resolve()), "-V"),
				workspace=parallel_root / "b0" / "first",
				exit_code=0,
				process_exit_code=0,
				stdout="",
				stderr="",
				timed_out=False,
				cancelled=False,
				duration_seconds=0.1,
				pid=1,
				started=True,
				process_boundary_quiescent=True,
			)
			with mock.patch.object(
				gf_maintenance,
				"parallel_full_shard_plan",
				return_value=plan,
			), mock.patch.object(
				gf_maintenance,
				"expanded_check_names",
				side_effect=AssertionError("parallel execution must consume its plan"),
			), mock.patch.object(
				gf_maintenance,
				"run_parallel_godot_isolation_probe",
				return_value={"ok": True},
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"assert_source_matches_snapshot",
			), mock.patch.object(
				gf_maintenance,
				"managed_owned_directory",
				side_effect=retained_batch,
			), mock.patch.object(
				gf_maintenance,
				"materialize_parallel_full_workspaces",
				side_effect=materialize,
			), mock.patch.object(
				gf_maintenance,
				"make_parallel_full_shard",
				side_effect=make_shard,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"run_parallel_shards",
				return_value=[shard_result],
			) as run_parallel, mock.patch.object(
				gf_maintenance,
				"load_parallel_shard_report",
				return_value=(report, ""),
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				return_value={"fingerprint": "b" * 64},
			), mock.patch.object(
				gf_maintenance,
				"collect_parallel_failure_logs",
			) as collect_logs:
				with self.assertRaises(
					gf_maintenance.WorkspaceSnapshotError,
				) as raised:
					gf_maintenance.run_parallel_full_checks(
						captured,
						parallel_root,
						validation_plan=_synthetic_full_validation_plan(plan),
						validation_catalog=gf_maintenance._VALIDATION_CATALOG,
						git_process=_SHARED_PROCESS_AUTHORITY.git,
						jobs=1,
						timeout_seconds=None,
						suite_timeout_seconds=None,
						fail_fast=False,
						package_artifact_manifest="manifest.json",
						package_artifact_manifest_sha256="d" * 64,
						package_artifact_count=1,
						progress_callback=None,
						output_callback=None,
						overall_started=time.perf_counter(),
						suite_deadline=time.perf_counter() + 10.0,
						cleanup_state=cleanup_state,
					)
			collect_logs.assert_not_called()
			self.assertEqual(run_parallel.call_count, 1)
			self.assertTrue((parallel_root / "b1" / "second").is_dir())
			self.assertIn("synthetic passing-batch cleanup failure", str(raised.exception))
			self.assertFalse(cleanup_state["permitted"])
			self.assertIsNotNone(retained_marker)
			assert retained_marker is not None
			self.assertEqual(
				retained_marker.read_text(encoding="utf-8"),
				"source evidence",
			)

	def test_shadow_timeout_is_failed_evidence_and_never_a_reusable_candidate(self) -> None:
		workspace_state = self._workspace_state()
		data = {
			"ok": False,
			"suite": "quick",
			"checks": ["docs"],
			"results": [{
				"name": "docs",
				"command": ["python", "check.py"],
				"execution": "subprocess",
				"exit_code": 124,
				"timed_out": True,
				"cancelled": False,
				"duration_seconds": 1.0,
				"dependency_fingerprints": {},
				"result_fingerprint": "e" * 64,
			}],
		}
		with mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			return_value=self._inventory(),
		):
			gf_maintenance.attach_validation_shadow_report(
				data,
				workspace_state,
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
			)
		action = data["validation_shadow"]["actions"][0]["shadow_evidence"]
		evidence_record = action["evidence"][0]
		self.assertEqual(evidence_record["outcome"], "failed")
		self.assertTrue(evidence_record["timed_out"])
		self.assertFalse(evidence_record["structurally_reusable_candidate"])
		self.assertEqual(evidence_record["evidence_authority"], "self_asserted")
		self.assertIsNone(evidence_record["warning_count"])
		self.assertEqual(action["acceptance_decision"]["decision"], "execute")

	def test_shadow_rendering_adds_only_a_compact_summary(self) -> None:
		base = {
			"suite": "quick",
			"ok": True,
			"duration_seconds": 0.1,
			"results": [],
		}
		self.assertNotIn(
			"validation_shadow:",
			gf_maintenance_rendering.render_checks_text(base),
		)
		with_shadow = {
			**base,
			"validation_shadow": {
				"report_ok": True,
				"authoritative": False,
				"expected_action_count": 1,
				"executed_action_count": 1,
				"execution_observation_count": 1,
				"reused_count": 0,
				"collection_duration_seconds": 0.01,
				"test_inventory": {"file_count": 2, "method_count": 3},
			},
		}
		rendered = gf_maintenance_rendering.render_checks_text(with_shadow)
		self.assertIn("validation_shadow: report_ok=True", rendered)
		self.assertIn("executed=1 observations=1 reused=0", rendered)
		self.assertNotIn("action_key", rendered)

	def test_parallel_child_command_never_inherits_validation_shadow(self) -> None:
		plan = _synthetic_parallel_shard_plan("framework-static", ("docs",))
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_maintenance,
			"parallel_shard_environment",
			return_value=({}, Path(temporary_directory) / "user"),
		):
			shard, _report_path = gf_maintenance.make_parallel_full_shard(
				plan,
				Path(temporary_directory),
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
				private_environment_root=Path(temporary_directory) / "private",
				timeout_seconds=None,
				suite_deadline=None,
				fail_fast=False,
				package_artifact_manifest="",
				package_artifact_manifest_sha256="",
			)
		self.assertNotIn("--validation-shadow", shard.command)
		self.assertEqual(
			shard.command.count("--internal-complete-output-evidence"),
			1,
		)


class AffectedAnalysisIntegrationTests(unittest.TestCase):
	def _workspace_state(self) -> dict[str, object]:
		return {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "a" * 64,
		}

	def _analysis(self, base_revision: str = "HEAD") -> dict[str, object]:
		return gf_maintenance.gf_validation_inputs.make_affected_analysis_failure(
			("docs",),
			base_revision=base_revision,
			error_code="affected_internal_error",
			explain=True,
		)

	def test_default_check_execution_does_not_run_affected_analysis(self) -> None:
		workspace_state = self._workspace_state()
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value=workspace_state,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			return_value=_in_process_adapter_registry_with(
				docs=lambda: {"ok": True}
			),
		), mock.patch.object(
			gf_maintenance.gf_validation_inputs,
			"analyze_affected_checks",
		) as analyze:
			result = gf_maintenance.run_checks(checks=["docs"], jobs=1)
		self.assertTrue(result["ok"])
		self.assertNotIn("affected_analysis", result)
		analyze.assert_not_called()

	def test_initial_workspace_cleanup_debt_stops_before_affected_analysis(self) -> None:
		debt = (
			gf_maintenance.gf_maintenance_check_graph.WorkspaceFingerprintProcessBoundaryError(
				"fixture initial workspace cleanup debt"
			)
		)
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=debt,
		), mock.patch.object(
			gf_maintenance.gf_validation_inputs,
			"analyze_affected_checks",
		) as analyze:
			with self.assertRaises(
				gf_maintenance.gf_maintenance_check_graph.WorkspaceFingerprintProcessBoundaryError
			) as raised:
				gf_maintenance.run_checks(
					checks=["docs"],
					jobs=1,
					affected=True,
				)

		self.assertIs(raised.exception, debt)
		self.assertTrue(raised.exception.cleanup_debt)
		self.assertFalse(raised.exception.process_boundary_quiescent)
		analyze.assert_not_called()

	def test_affected_analysis_attaches_after_execution_and_workspace_freeze(self) -> None:
		workspace_state = self._workspace_state()
		events: list[str] = []
		invocation_catalog = gf_maintenance._VALIDATION_CATALOG
		invocation_input_specs = invocation_catalog.input_specs

		def fingerprint(*_args: object, **_kwargs: object) -> dict[str, object]:
			events.append("workspace_fingerprint")
			return workspace_state

		def runner() -> dict[str, object]:
			events.append("execute")
			gf_maintenance._VALIDATION_CATALOG = object()
			return {"ok": True}

		def analyze(*args: object, **kwargs: object) -> dict[str, object]:
			events.append("affected_analysis")
			self.assertEqual(args[:2], (gf_maintenance.ROOT, ("docs",)))
			self.assertEqual(kwargs["base_revision"], "fixture-base")
			self.assertTrue(kwargs["explain"])
			self.assertIs(
				kwargs["input_specs"],
				invocation_input_specs,
			)
			self.assertGreater(float(kwargs["deadline_seconds"]), time.monotonic())
			return self._analysis("fixture-base")

		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=fingerprint,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			return_value=_in_process_adapter_registry_with(docs=runner),
		), mock.patch.object(
			gf_maintenance.gf_validation_inputs,
			"analyze_affected_checks",
			side_effect=analyze,
		), mock.patch.object(
			gf_validation_inputs,
			"DEFAULT_AFFECTED_INPUT_SPECS",
			(object(),),
			create=True,
		), mock.patch.object(
			gf_maintenance,
			"_VALIDATION_CATALOG",
			invocation_catalog,
		):
			result = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				affected=True,
				affected_base="fixture-base",
				affected_explain=True,
			)

		self.assertTrue(result["ok"])
		self.assertEqual(
			events,
			[
				"workspace_fingerprint",
				"execute",
				"workspace_fingerprint",
				"affected_analysis",
			],
		)
		analysis = result["affected_analysis"]
		self.assertFalse(analysis["authoritative"])
		self.assertFalse(analysis["scheduling_effect"])
		self.assertEqual(analysis["affected_skip_count"], 0)
		self.assertEqual(analysis["cache_read_count"], 0)
		self.assertEqual(analysis["cache_write_count"], 0)
		self.assertEqual(analysis["reused_count"], 0)

	def test_affected_attachment_uses_the_suite_capped_deadline(self) -> None:
		data = {"checks": ["docs"]}
		with mock.patch.object(
			gf_maintenance,
			"advisory_collection_deadline",
			return_value=321.0,
		) as deadline, mock.patch.object(
			gf_maintenance.gf_validation_inputs,
			"analyze_affected_checks",
			return_value=self._analysis(),
		) as analyze:
			gf_maintenance.attach_affected_analysis_report(
				data,
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
				base_revision="HEAD",
				explain=True,
				git_process=_SHARED_PROCESS_AUTHORITY.git,
				suite_deadline=75.0,
			)
		deadline.assert_called_once_with(
			gf_maintenance.AFFECTED_ANALYSIS_COLLECTION_TIMEOUT_SECONDS,
			75.0,
		)
		self.assertEqual(analyze.call_args.kwargs["deadline_seconds"], 321.0)

	def test_affected_attachment_preserves_cleanup_debt_identity(self) -> None:
		debt = gf_process_supervisor.SupervisedProcessCleanupError(
			"fixture affected attachment cleanup debt",
			pid=123,
			process_tree_empty=False,
		)
		data = {"checks": ["docs"]}
		with mock.patch.object(
			gf_maintenance.gf_validation_inputs,
			"analyze_affected_checks",
			side_effect=debt,
		):
			with self.assertRaises(
				gf_process_supervisor.SupervisedProcessCleanupError
			) as raised:
				gf_maintenance.attach_affected_analysis_report(
					data,
					validation_catalog=gf_maintenance._VALIDATION_CATALOG,
					base_revision="HEAD",
					explain=False,
					git_process=_SHARED_PROCESS_AUTHORITY.git,
				)

		self.assertIs(raised.exception, debt)
		self.assertTrue(raised.exception.cleanup_debt)
		self.assertFalse(raised.exception.process_boundary_quiescent)
		self.assertNotIn("affected_analysis", data)

	def test_cleanup_debt_stops_serial_suite_and_retains_owned_root(self) -> None:
		workspace_state = self._workspace_state()
		temporary_parent = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_parent.cleanup)
		executed_after_debt = mock.Mock(return_value={"ok": True})
		retained_roots: list[Path] = []
		debts: list[gf_process_supervisor.SupervisedProcessCleanupError] = []

		def raise_cleanup_debt() -> dict[str, object]:
			with gf_maintenance.strict_process_boundary_temporary_directory(
				prefix="gf-serial-debt-fixture-",
				directory=Path(temporary_parent.name),
			) as owned_root:
				retained_roots.append(owned_root)
				(owned_root / "must-retain.txt").write_text(
					"retained",
					encoding="utf-8",
				)
				debt = gf_process_supervisor.SupervisedProcessCleanupError(
					"fixture serial cleanup debt",
					pid=123,
					process_tree_empty=False,
				)
				debts.append(debt)
				raise debt

		fingerprint = mock.Mock(return_value=workspace_state)
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			fingerprint,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			return_value=_in_process_adapter_registry_with(
				docs=raise_cleanup_debt,
				public_docs_boundary=executed_after_debt,
			),
		), mock.patch.object(
			gf_maintenance.gf_validation_inputs,
			"analyze_affected_checks",
		) as analyze:
			with self.assertRaises(
				gf_process_supervisor.SupervisedProcessCleanupError
			) as raised:
				gf_maintenance.run_checks(
					checks=["docs", "public_docs_boundary"],
					jobs=1,
					affected=True,
				)

		self.assertEqual(len(debts), 1)
		self.assertIs(raised.exception, debts[0])
		self.assertTrue(raised.exception.cleanup_debt)
		self.assertFalse(raised.exception.process_boundary_quiescent)
		self.assertIn(
			"Retained temporary root because process-boundary cleanup ownership was not proven",
			"\n".join(getattr(raised.exception, "__notes__", ())),
		)
		executed_after_debt.assert_not_called()
		analyze.assert_not_called()
		self.assertEqual(fingerprint.call_count, 1)
		self.assertEqual(
			(retained_roots[0] / "must-retain.txt").read_text(encoding="utf-8"),
			"retained",
		)

	def test_exhausted_suite_budget_makes_affected_analysis_fail_closed(self) -> None:
		data = {"checks": ["docs"]}
		with mock.patch.object(
			gf_maintenance,
			"advisory_collection_deadline",
			return_value=10.0,
		), mock.patch.object(
			gf_maintenance.time,
			"monotonic",
			return_value=10.0,
		):
			gf_maintenance.attach_affected_analysis_report(
				data,
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
				base_revision="HEAD",
				explain=False,
				git_process=_SHARED_PROCESS_AUTHORITY.git,
				suite_deadline=1.0,
			)
		self.assertEqual(
			data["affected_analysis"]["errors"],
			["affected_deadline_exceeded"],
		)

	def test_reported_duration_includes_both_advisory_attachments(self) -> None:
		workspace_state = self._workspace_state()
		clock = [10.0]
		shadow_deadlines: list[object] = []
		affected_deadlines: list[object] = []

		def attach_shadow(data: dict[str, object], *_args: object, **kwargs: object) -> None:
			shadow_deadlines.append(kwargs.get("suite_deadline"))
			clock[0] = 12.0
			data["validation_shadow"] = {"report_ok": True}

		def attach_affected(data: dict[str, object], **kwargs: object) -> None:
			affected_deadlines.append(kwargs.get("suite_deadline"))
			clock[0] = 15.0
			data["affected_analysis"] = self._analysis()

		with mock.patch.object(
			gf_maintenance.time,
			"perf_counter",
			side_effect=lambda: clock[0],
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value=workspace_state,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			return_value=_in_process_adapter_registry_with(
				docs=lambda: {"ok": True}
			),
		), mock.patch.object(
			gf_maintenance,
			"attach_validation_shadow_report",
			side_effect=attach_shadow,
		), mock.patch.object(
			gf_maintenance,
			"attach_affected_analysis_report",
			side_effect=attach_affected,
		):
			result = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				validation_shadow=True,
				affected=True,
				suite_timeout_seconds=10,
			)
		self.assertEqual(result["duration_seconds"], 5.0)
		self.assertEqual(shadow_deadlines, [20.0])
		self.assertEqual(affected_deadlines, [20.0])

	def test_first_affected_specs_cover_the_exact_maintenance_inputs(self) -> None:
		specs = {
			spec.check_name: spec
			for spec in gf_maintenance._VALIDATION_CATALOG.input_specs
		}
		self.assertEqual(
			set(specs),
			{
				"package_user_dependency_boundary",
				"public_api_boundary",
				"public_docs_boundary",
			},
		)
		self.assertTrue(specs["public_docs_boundary"].matches_source_path("README.md"))
		self.assertTrue(
			specs["public_docs_boundary"].matches_source_path("docs/zh/guide.md")
		)
		self.assertFalse(
			specs["public_docs_boundary"].matches_source_path(
				"docs/zh/reference/api/classes/GF.md"
			)
		)
		self.assertTrue(
			specs["public_api_boundary"].matches_source_path("addons/gf/value.gd")
		)
		self.assertTrue(
			specs["package_user_dependency_boundary"].matches_source_path(
				"addons/gf/kernel/package/installer.gd"
			)
		)
		self.assertFalse(
			specs["package_user_dependency_boundary"].matches_source_path(
				"addons/gf/kernel/unrelated.gd"
			)
		)

	def test_affected_failure_is_unknown_execute_and_cannot_change_success(self) -> None:
		workspace_state = self._workspace_state()
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value=workspace_state,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_adapter_registry",
			return_value=_in_process_adapter_registry_with(
				docs=lambda: {"ok": True}
			),
		), mock.patch.object(
			gf_maintenance.gf_validation_inputs,
			"analyze_affected_checks",
			side_effect=RuntimeError("untrusted analyzer failure"),
		):
			result = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				affected=True,
			)
		self.assertTrue(result["ok"])
		analysis = result["affected_analysis"]
		self.assertFalse(analysis["report_ok"])
		self.assertEqual(analysis["unknown_count"], 1)
		self.assertEqual(analysis["fallback_decision"], "execute")
		self.assertEqual(analysis["errors"], ["affected_internal_error"])

	def test_affected_failure_never_stringifies_analyzer_exception(self) -> None:
		class HostileError(RuntimeError):
			def __str__(self) -> str:
				raise AssertionError("exception text must not be observed")

		data = {"checks": ["docs"]}
		with mock.patch.object(
			gf_maintenance.gf_validation_inputs,
			"analyze_affected_checks",
			side_effect=HostileError(),
		):
			gf_maintenance.attach_affected_analysis_report(
				data,
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
				base_revision="HEAD",
				explain=False,
				git_process=_SHARED_PROCESS_AUTHORITY.git,
			)
		self.assertEqual(
			data["affected_analysis"]["errors"],
			["affected_internal_error"],
		)
		json.dumps(data["affected_analysis"], allow_nan=False)

	def test_malformed_affected_report_is_replaced_by_exact_fallback(self) -> None:
		data = {"checks": ["docs"]}
		with mock.patch.object(
			gf_maintenance.gf_validation_inputs,
			"analyze_affected_checks",
			return_value={"report_ok": True, "scheduling_effect": True},
		):
			gf_maintenance.attach_affected_analysis_report(
				data,
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
				base_revision="HEAD",
				explain=False,
				git_process=_SHARED_PROCESS_AUTHORITY.git,
			)
		analysis = data["affected_analysis"]
		self.assertEqual(
			frozenset(analysis),
			gf_maintenance.gf_validation_inputs.AFFECTED_ANALYSIS_REPORT_FIELDS,
		)
		self.assertFalse(analysis["report_ok"])
		self.assertFalse(analysis["scheduling_effect"])
		self.assertEqual(analysis["errors"], ["affected_internal_error"])

	def test_initial_workspace_failure_uses_zero_io_affected_fallback(self) -> None:
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=gf_maintenance.gf_maintenance_check_graph.WorkspaceFingerprintSetupError(
				"fixture failure"
			),
		), mock.patch.object(
			gf_maintenance.gf_validation_inputs,
			"analyze_affected_checks",
		) as analyze:
			result = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				affected=True,
			)
		self.assertFalse(result["ok"])
		analysis = result["affected_analysis"]
		self.assertFalse(analysis["report_ok"])
		self.assertEqual(analysis["unknown_count"], 1)
		self.assertEqual(analysis["execute_count"], 1)
		self.assertEqual(analysis["errors"], ["affected_internal_error"])
		analyze.assert_not_called()

	def test_explain_requires_affected_before_any_check_runs(self) -> None:
		stderr = io.StringIO()
		with mock.patch.object(
			sys,
			"argv",
			[
				"gf_maintenance.py",
				"check",
				"--check",
				"docs",
				"--explain",
				"--json",
			],
		), mock.patch.object(
			gf_maintenance,
			"configure_stdio",
		) as configure_stdio, mock.patch.object(
			gf_maintenance.maintenance_rendering,
			"set_json_output_path",
		) as set_json_output_path, mock.patch.object(
			gf_maintenance,
			"run_checks",
			side_effect=AssertionError("invalid CLI must not dispatch checks"),
		) as run_checks, contextlib.redirect_stderr(stderr), self.assertRaises(
			SystemExit
		) as raised:
			gf_maintenance.main()

		self.assertEqual(raised.exception.code, 2)
		self.assertIn("--explain requires --affected", stderr.getvalue())
		configure_stdio.assert_called_once_with()
		set_json_output_path.assert_called_once_with(None)
		run_checks.assert_not_called()

	def test_affected_rendering_is_compact_and_does_not_emit_reasons(self) -> None:
		data = {
			"suite": "quick",
			"ok": True,
			"duration_seconds": 0.1,
			"results": [],
			"affected_analysis": {
				"report_ok": True,
				"authoritative": False,
				"check_count": 3,
				"affected_count": 1,
				"unaffected_count": 1,
				"unknown_count": 1,
				"execute_count": 3,
				"affected_skip_count": 0,
				"reused_count": 0,
				"checks": [{"reasons": ["secret detail"]}],
			},
		}
		rendered = gf_maintenance_rendering.render_checks_text(data)
		self.assertIn("affected_analysis: report_ok=True", rendered)
		self.assertIn("affected=1 unaffected=1 unknown=1", rendered)
		self.assertIn("execute=3 skipped=0 reused=0", rendered)
		self.assertNotIn("secret detail", rendered)

	def test_parallel_child_command_never_inherits_affected_flags(self) -> None:
		plan = _synthetic_parallel_shard_plan("framework-static", ("docs",))
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_maintenance,
			"parallel_shard_environment",
			return_value=({}, Path(temporary_directory) / "user"),
		):
			shard, _report_path = gf_maintenance.make_parallel_full_shard(
				plan,
				Path(temporary_directory),
				validation_catalog=gf_maintenance._VALIDATION_CATALOG,
				private_environment_root=Path(temporary_directory) / "private",
				timeout_seconds=None,
				suite_deadline=None,
				fail_fast=False,
				package_artifact_manifest="",
				package_artifact_manifest_sha256="",
			)
		self.assertNotIn("--affected", shard.command)
		self.assertNotIn("--explain", shard.command)
		self.assertNotIn("--affected-base", shard.command)


if __name__ == "__main__":
	unittest.main()
