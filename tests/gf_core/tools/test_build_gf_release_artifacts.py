#!/usr/bin/env python3
"""Focused tests for release-builder process and source-revision authority."""

from __future__ import annotations

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

import build_gf_release_artifacts as release_builder  # noqa: E402
from gf_process_authority import freeze_process_authority  # noqa: E402
from gf_process_authority import FrozenProcessEnvironment  # noqa: E402
from gf_process_authority import FrozenProcessAuthority  # noqa: E402
from gf_process_supervisor import SupervisedBinaryProcessResult  # noqa: E402
from gf_process_supervisor import SupervisedProcessCleanupError  # noqa: E402


def _process_authority() -> FrozenProcessAuthority:
	return freeze_process_authority(
		FrozenProcessEnvironment.capture(dict(os.environ)),
		cwd=ROOT,
	)


def _git_result(**overrides: object) -> SupervisedBinaryProcessResult:
	values: dict[str, object] = {
		"return_code": 0,
		"stdout": ("a" * 40 + "\n").encode("ascii"),
		"stderr": b"",
		"timed_out": False,
		"duration_seconds": 0.1,
		"pid": 123,
		"cleanup_complete": True,
	}
	values.update(overrides)
	return SupervisedBinaryProcessResult(**values)


class ReleaseBuilderProcessAuthorityTests(unittest.TestCase):
	def test_git_head_uses_absolute_frozen_git_and_exact_environment(self) -> None:
		authority = _process_authority()
		with (
			mock.patch.object(
				release_builder.time,
				"perf_counter",
				return_value=100.0,
			) as clock,
			mock.patch.dict(
				os.environ,
				{
					"PATH": "ambient-path-after-freeze",
					"GIT_DIR": "ambient-git-dir-after-freeze",
				},
				clear=False,
			),
			mock.patch.object(
				release_builder,
				"run_supervised_process_bytes",
				return_value=_git_result(),
			) as supervisor,
			mock.patch.object(
				release_builder,
				"require_supervised_binary_quiet_boundary",
				side_effect=lambda result, **_kwargs: result,
			) as quiet_boundary,
		):
			revision = release_builder.git_head(authority.git)

		self.assertEqual(revision, "a" * 40)
		command = supervisor.call_args.args[0]
		self.assertTrue(Path(command[0]).is_absolute())
		self.assertEqual(command[0], authority.git.executable)
		self.assertEqual(command[1:], ["rev-parse", "--verify", "HEAD"])
		self.assertEqual(supervisor.call_args.kwargs["cwd"], ROOT)
		clock.assert_called_once_with()
		self.assertEqual(supervisor.call_args.kwargs["deadline"], 130.0)
		self.assertEqual(quiet_boundary.call_args.kwargs["deadline"], 130.0)
		self.assertEqual(
			supervisor.call_args.kwargs["environment"],
			authority.git.environment.values(),
		)
		self.assertNotIn("GIT_DIR", supervisor.call_args.kwargs["environment"])

	def test_git_head_rejects_unproven_or_noisy_completion(self) -> None:
		authority = _process_authority()
		for name, result in (
			("nonzero", _git_result(return_code=1)),
			("timeout", _git_result(timed_out=True)),
			("stdout-truncated", _git_result(stdout_truncated=True)),
			("stderr-truncated", _git_result(stderr_truncated=True)),
			("output-drain", _git_result(output_drain_failed=True)),
			("stderr", _git_result(stderr=b"unexpected diagnostic")),
		):
			with self.subTest(name=name), mock.patch.object(
				release_builder,
				"run_supervised_process_bytes",
				return_value=result,
			), self.assertRaises(RuntimeError):
				release_builder.git_head(authority.git)

	def test_git_head_cleanup_debt_precedes_timeout_and_truncation(self) -> None:
		authority = _process_authority()
		combined_failure = _git_result(
			return_code=124,
			timed_out=True,
			stdout_truncated=True,
			stderr_truncated=True,
			output_drain_failed=True,
			cleanup_complete=False,
		)
		with mock.patch.object(
			release_builder,
			"run_supervised_process_bytes",
			return_value=combined_failure,
		), self.assertRaises(SupervisedProcessCleanupError):
			release_builder.git_head(authority.git)

	def test_git_head_rejects_malformed_revision_output(self) -> None:
		authority = _process_authority()
		for name, stdout in (
			("empty", b""),
			("short", b"a" * 39),
			("unsupported-length", b"a" * 41),
			("too-long", b"a" * 65),
			("non-hex", b"g" * 40),
			("leading-space", (" " + "a" * 40 + "\n").encode("ascii")),
			("extra-blank-line", ("a" * 40 + "\n\n").encode("ascii")),
			("extra-line", ("a" * 40 + "\nextra\n").encode("ascii")),
		):
			with self.subTest(name=name), mock.patch.object(
				release_builder,
				"run_supervised_process_bytes",
				return_value=_git_result(stdout=stdout),
			), self.assertRaises(ValueError):
				release_builder.git_head(authority.git)

	def test_main_captures_source_revision_once_for_validate_only(self) -> None:
		authority = _process_authority()
		revision = "b" * 40
		manifest = ROOT / "build" / "fixture-release-manifest.json"
		output = ROOT / "build" / "fixture-release"
		with (
			mock.patch.object(
				sys,
				"argv",
				[
					"build_gf_release_artifacts.py",
					"--version",
					"3.19.0",
					"--validate-only",
					"--manifest",
					str(manifest),
				],
			),
			mock.patch.object(
				release_builder,
				"resolve_output_dir",
				return_value=output,
			),
			mock.patch.object(
				release_builder,
				"resolve_manifest_path",
				return_value=manifest,
			),
			mock.patch.object(
				release_builder,
				"freeze_process_authority",
				return_value=authority,
			) as freeze_authority,
			mock.patch.object(
				release_builder,
				"git_head",
				return_value=revision,
			) as git_head,
			mock.patch.object(
				release_builder,
				"audit_release_artifact_manifest",
				return_value={"ok": True},
			) as audit,
			mock.patch.object(release_builder, "print_result"),
		):
			exit_code = release_builder.main()

		self.assertEqual(exit_code, 0)
		freeze_authority.assert_called_once()
		git_head.assert_called_once_with(authority.git)
		audit.assert_called_once_with(manifest, "3.19.0", revision)

	def test_main_captures_source_revision_once_for_artifact_build(self) -> None:
		authority = _process_authority()
		revision = "c" * 40
		manifest = ROOT / "build" / "fixture-release-manifest.json"
		output = ROOT / "build" / "fixture-release"
		with (
			mock.patch.object(
				sys,
				"argv",
				[
					"build_gf_release_artifacts.py",
					"--version",
					"3.19.0",
				],
			),
			mock.patch.object(
				release_builder,
				"resolve_output_dir",
				return_value=output,
			),
			mock.patch.object(
				release_builder,
				"resolve_manifest_path",
				return_value=manifest,
			),
			mock.patch.object(
				release_builder,
				"freeze_process_authority",
				return_value=authority,
			) as freeze_authority,
			mock.patch.object(
				release_builder,
				"git_head",
				return_value=revision,
			) as git_head,
			mock.patch.object(
				release_builder,
				"build_release_artifacts",
				return_value={"ok": True},
			) as build,
			mock.patch.object(release_builder, "print_result"),
		):
			exit_code = release_builder.main()

		self.assertEqual(exit_code, 0)
		freeze_authority.assert_called_once()
		git_head.assert_called_once_with(authority.git)
		build.assert_called_once_with(
			"3.19.0",
			output,
			"https://github.com/C76GN/gf-framework/releases/download/3.19.0",
			"https://github.com/C76GN/gf-framework/releases/download/3.19.0/"
			"gf-registry-3.19.0.json",
			source_revision=revision,
		)

	def test_main_fails_closed_before_consumers_when_git_capture_fails(self) -> None:
		authority = _process_authority()
		output = ROOT / "build" / "fixture-release"
		with (
			mock.patch.object(
				sys,
				"argv",
				[
					"build_gf_release_artifacts.py",
					"--version",
					"3.19.0",
				],
			),
			mock.patch.object(
				release_builder,
				"resolve_output_dir",
				return_value=output,
			),
			mock.patch.object(
				release_builder,
				"resolve_manifest_path",
				return_value=output / "manifest.json",
			),
			mock.patch.object(
				release_builder,
				"freeze_process_authority",
				return_value=authority,
			),
			mock.patch.object(
				release_builder,
				"git_head",
				side_effect=RuntimeError("synthetic unproven completion"),
			) as git_head,
			mock.patch.object(
				release_builder,
				"build_release_artifacts",
			) as build,
			mock.patch.object(
				release_builder,
				"audit_release_artifact_manifest",
			) as audit,
			mock.patch.object(release_builder, "print_result") as print_result,
		):
			exit_code = release_builder.main()

		self.assertEqual(exit_code, 1)
		git_head.assert_called_once_with(authority.git)
		build.assert_not_called()
		audit.assert_not_called()
		result = print_result.call_args.args[0]
		self.assertFalse(result["ok"])
		self.assertIn("RuntimeError", result["issues"][0])

	def test_main_propagates_cleanup_debt_before_starting_release_consumers(self) -> None:
		authority = _process_authority()
		output = ROOT / "build" / "fixture-release"
		cleanup_error = SupervisedProcessCleanupError("synthetic cleanup debt")
		with (
			mock.patch.object(
				sys,
				"argv",
				[
					"build_gf_release_artifacts.py",
					"--version",
					"3.19.0",
				],
			),
			mock.patch.object(
				release_builder,
				"resolve_output_dir",
				return_value=output,
			),
			mock.patch.object(
				release_builder,
				"resolve_manifest_path",
				return_value=output / "manifest.json",
			),
			mock.patch.object(
				release_builder,
				"freeze_process_authority",
				return_value=authority,
			),
			mock.patch.object(
				release_builder,
				"git_head",
				side_effect=cleanup_error,
			) as git_head,
			mock.patch.object(
				release_builder,
				"build_release_artifacts",
			) as build,
			mock.patch.object(
				release_builder,
				"audit_release_artifact_manifest",
			) as audit,
			mock.patch.object(release_builder, "print_result") as print_result,
			self.assertRaises(SupervisedProcessCleanupError) as raised,
		):
			release_builder.main()

		self.assertIs(raised.exception, cleanup_error)
		git_head.assert_called_once_with(authority.git)
		build.assert_not_called()
		audit.assert_not_called()
		print_result.assert_not_called()

	def test_build_binds_one_revision_to_candidate_and_published_manifest(self) -> None:
		version = "3.19.0"
		revision = "d" * 40
		with tempfile.TemporaryDirectory() as temp_dir:
			output = Path(temp_dir) / "release"
			audit_revisions: list[str] = []

			def fake_package_build(**arguments: object) -> dict[str, object]:
				Path(str(arguments["output_dir"])).mkdir(parents=True)
				return {"ok": True, "packages": []}

			def audit_manifest(
				manifest_path: Path,
				expected_version: str = "",
				expected_revision: str = "",
				expected_manifest_sha256: str = "",
			) -> dict[str, object]:
				self.assertEqual(expected_version, version)
				self.assertFalse(expected_manifest_sha256)
				manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
				self.assertEqual(manifest["source_revision"], revision)
				audit_revisions.append(expected_revision)
				return {"ok": True, "source_revision": manifest["source_revision"]}

			with (
				mock.patch.object(release_builder, "validate_output_dir"),
				mock.patch.object(
					release_builder.build_asset_store_package,
					"read_plugin_version",
					return_value=version,
				),
				mock.patch.object(
					release_builder.build_asset_store_package,
					"build_package",
				),
				mock.patch.object(
					release_builder.build_asset_store_package,
					"audit_package",
					return_value={"ok": True},
				),
				mock.patch.object(
					release_builder.build_gf_ai_developer_kit,
					"check_source",
					return_value={"ok": True},
				),
				mock.patch.object(
					release_builder.build_gf_ai_developer_kit,
					"build_plugin_archive",
				),
				mock.patch.object(
					release_builder.build_gf_ai_developer_kit,
					"audit_plugin_archive",
					return_value={"ok": True},
				),
				mock.patch.object(
					release_builder.build_gf_package,
					"build_gf_packages",
					side_effect=fake_package_build,
				),
				mock.patch.object(
					release_builder,
					"write_release_registry_metadata",
					return_value=[],
				),
				mock.patch.object(
					release_builder,
					"collect_release_artifacts",
					return_value=[],
				),
				mock.patch.object(
					release_builder,
					"audit_release_artifact_manifest",
					side_effect=audit_manifest,
				),
			):
				result = release_builder.build_release_artifacts(
					version,
					output,
					"https://example.invalid/release",
					"https://example.invalid/registry.json",
					source_revision=revision,
				)

			self.assertTrue(result["ok"], result)
			self.assertEqual(audit_revisions, [revision, revision])
			published_manifest = output / f"gf-release-artifacts-{version}.json"
			manifest = json.loads(published_manifest.read_text(encoding="utf-8"))
			self.assertEqual(manifest["source_revision"], revision)

	def test_manifest_audit_accepts_same_full_object_id_contract(self) -> None:
		with tempfile.TemporaryDirectory() as temp_dir:
			manifest_path = Path(temp_dir) / "manifest.json"
			revision = "e" * 64
			manifest_path.write_text(
				json.dumps({
					"schema_version": release_builder.MANIFEST_SCHEMA_VERSION,
					"version": "3.19.0",
					"source_revision": revision,
					"package_archive_build_count": 1,
					"ai_developer_kit_build_count": 1,
					"artifact_count": 0,
					"artifacts": [],
				}),
				encoding="utf-8",
			)

			result = release_builder.audit_release_artifact_manifest(
				manifest_path,
				"3.19.0",
				revision,
			)

		self.assertFalse(
			any("source_revision" in issue for issue in result["issues"]),
			result,
		)

	def test_manifest_audit_rejects_noncanonical_source_revision_values(self) -> None:
		for source_revision in (
			f" {'e' * 40}",
			f"{'e' * 40} ",
			f"{'e' * 40}\n",
			int("1" * 40),
		):
			with self.subTest(source_revision=source_revision), tempfile.TemporaryDirectory() as temp_dir:
				manifest_path = Path(temp_dir) / "manifest.json"
				manifest_path.write_text(
					json.dumps({
						"schema_version": release_builder.MANIFEST_SCHEMA_VERSION,
						"version": "3.19.0",
						"source_revision": source_revision,
						"package_archive_build_count": 1,
						"ai_developer_kit_build_count": 1,
						"artifact_count": 0,
						"artifacts": [],
					}),
					encoding="utf-8",
				)

				result = release_builder.audit_release_artifact_manifest(
					manifest_path,
					"3.19.0",
					"e" * 40,
				)

			self.assertTrue(
				any("source_revision" in issue for issue in result["issues"]),
				result,
			)

	def test_invalid_source_revision_fails_before_artifact_build(self) -> None:
		for invalid_revision in (
			"not-a-revision",
			"a" * 39,
			"a" * 41,
			"a" * 63,
			"a" * 65,
			int("1" * 40),
		):
			with self.subTest(invalid_revision=invalid_revision), mock.patch.object(
				release_builder.build_asset_store_package,
				"read_plugin_version",
				side_effect=AssertionError("Invalid authority must fail before build I/O."),
			) as version_reader:
				result = release_builder.build_release_artifacts(
					"3.19.0",
					ROOT / "build" / "fixture-release",
					"https://example.invalid/release",
					"https://example.invalid/registry.json",
					source_revision=invalid_revision,
				)

			self.assertFalse(result["ok"])
			self.assertIn("exact Git object id", result["issues"][0])
			version_reader.assert_not_called()


if __name__ == "__main__":
	unittest.main()
