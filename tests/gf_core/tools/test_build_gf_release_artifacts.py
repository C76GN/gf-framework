from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
	sys.path.insert(0, str(TOOLS))

import build_gf_release_artifacts as release_builder  # noqa: E402
from gf_process_authority import freeze_process_authority  # noqa: E402
from gf_process_authority import FrozenProcessAuthority  # noqa: E402
from gf_process_authority import FrozenProcessEnvironment  # noqa: E402
from gf_process_supervisor import SupervisedBinaryProcessResult  # noqa: E402
from gf_process_supervisor import SupervisedProcessCleanupError  # noqa: E402


REVISION = "a" * 40
VERSION = "11.0.0"


def _process_authority() -> FrozenProcessAuthority:
	return freeze_process_authority(
		FrozenProcessEnvironment.capture(dict(os.environ)),
		cwd=ROOT,
	)


def _git_result(**overrides: object) -> SupervisedBinaryProcessResult:
	values: dict[str, object] = {
		"return_code": 0,
		"stdout": (REVISION + "\n").encode("ascii"),
		"stderr": b"",
		"timed_out": False,
		"duration_seconds": 0.1,
		"pid": 123,
		"cleanup_complete": True,
	}
	values.update(overrides)
	return SupervisedBinaryProcessResult(**values)


class ReleaseBuilderProcessAuthorityTests(unittest.TestCase):
	def test_git_head_uses_frozen_absolute_git_environment_and_quiet_boundary(self) -> None:
		authority = _process_authority()
		with (
			mock.patch.object(release_builder.time, "perf_counter", return_value=100.0) as clock,
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

		self.assertEqual(revision, REVISION)
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

	def test_git_head_rejects_noisy_completion_and_prioritizes_cleanup_debt(self) -> None:
		authority = _process_authority()
		failure_results = (
			("nonzero", _git_result(return_code=1)),
			("timeout", _git_result(timed_out=True)),
			("stdout-truncated", _git_result(stdout_truncated=True)),
			("stderr-truncated", _git_result(stderr_truncated=True)),
			("output-drain", _git_result(output_drain_failed=True)),
			("stderr", _git_result(stderr=b"unexpected diagnostic")),
		)
		for name, result in failure_results:
			with self.subTest(name=name), mock.patch.object(
				release_builder,
				"run_supervised_process_bytes",
				return_value=result,
			), self.assertRaises(RuntimeError):
				release_builder.git_head(authority.git)

		cleanup_debt = _git_result(
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
			return_value=cleanup_debt,
		), self.assertRaises(SupervisedProcessCleanupError):
			release_builder.git_head(authority.git)

	def test_malformed_revision_is_rejected_before_release_io(self) -> None:
		authority = _process_authority()
		malformed_outputs = (
			b"",
			b"a" * 39,
			b"a" * 41,
			b"g" * 40,
			(" " + REVISION + "\n").encode("ascii"),
			(REVISION + "\n\n").encode("ascii"),
			(REVISION + "\nextra\n").encode("ascii"),
		)
		for stdout in malformed_outputs:
			with self.subTest(stdout=stdout), mock.patch.object(
				release_builder,
				"run_supervised_process_bytes",
				return_value=_git_result(stdout=stdout),
			), self.assertRaises(ValueError):
				release_builder.git_head(authority.git)
		sha256_revision = "b" * 64
		with mock.patch.object(
			release_builder,
			"run_supervised_process_bytes",
			return_value=_git_result(stdout=(sha256_revision + "\n").encode("ascii")),
		):
			self.assertEqual(release_builder.git_head(authority.git), sha256_revision)

		invalid_revision_values: tuple[object, ...] = (
			True,
			" " + REVISION,
			REVISION + " ",
			REVISION + "\n",
			"a" * 39,
			"g" * 40,
		)
		with tempfile.TemporaryDirectory() as temporary_directory:
			output_dir = Path(temporary_directory) / "build/release"
			for source_revision in invalid_revision_values:
				with self.subTest(source_revision=source_revision), mock.patch.object(
					release_builder.build_asset_store_package,
					"read_plugin_version",
				) as read_plugin_version:
					result = release_builder.build_release_artifacts(
						VERSION,
						output_dir,
						source_revision=source_revision,  # type: ignore[arg-type]
					)
				self.assertFalse(result["ok"], result)
				read_plugin_version.assert_not_called()
				self.assertFalse(output_dir.exists())

	def test_main_captures_revision_once_and_fails_before_consumers(self) -> None:
		authority = _process_authority()
		output = ROOT / "build/fixture-release"
		manifest = output / f"gf-release-artifacts-{VERSION}.json"
		for validate_only in (False, True):
			arguments = [
				"build_gf_release_artifacts.py",
				"--version",
				VERSION,
			]
			if validate_only:
				arguments.extend(("--validate-only", "--manifest", str(manifest)))
			with (
				self.subTest(validate_only=validate_only),
				mock.patch.object(sys, "argv", arguments),
				mock.patch.object(release_builder, "configure_stdio"),
				mock.patch.object(release_builder, "resolve_output_dir", return_value=output),
				mock.patch.object(release_builder, "resolve_manifest_path", return_value=manifest),
				mock.patch.object(
					release_builder,
					"freeze_process_authority",
					return_value=authority,
				) as freeze_authority,
				mock.patch.object(release_builder, "git_head", return_value=REVISION) as git_head,
				mock.patch.object(
					release_builder,
					"build_release_artifacts",
					return_value={"ok": True},
				) as build,
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
			if validate_only:
				audit.assert_called_once_with(manifest, VERSION, REVISION)
				build.assert_not_called()
			else:
				build.assert_called_once_with(VERSION, output, source_revision=REVISION)
				audit.assert_not_called()

		with (
			mock.patch.object(
				sys,
				"argv",
				["build_gf_release_artifacts.py", "--version", VERSION],
			),
			mock.patch.object(release_builder, "configure_stdio"),
			mock.patch.object(release_builder, "resolve_output_dir", return_value=output),
			mock.patch.object(release_builder, "resolve_manifest_path", return_value=manifest),
			mock.patch.object(
				release_builder,
				"freeze_process_authority",
				return_value=authority,
			),
			mock.patch.object(
				release_builder,
				"git_head",
				side_effect=RuntimeError("synthetic unproven completion"),
			),
			mock.patch.object(release_builder, "build_release_artifacts") as build,
			mock.patch.object(release_builder, "audit_release_artifact_manifest") as audit,
			mock.patch.object(release_builder, "print_result") as print_result,
		):
			exit_code = release_builder.main()

		self.assertEqual(exit_code, 1)
		build.assert_not_called()
		audit.assert_not_called()
		self.assertFalse(print_result.call_args.args[0]["ok"])

		cleanup_error = SupervisedProcessCleanupError("synthetic cleanup debt")
		with (
			mock.patch.object(
				sys,
				"argv",
				["build_gf_release_artifacts.py", "--version", VERSION],
			),
			mock.patch.object(release_builder, "configure_stdio"),
			mock.patch.object(release_builder, "resolve_output_dir", return_value=output),
			mock.patch.object(release_builder, "resolve_manifest_path", return_value=manifest),
			mock.patch.object(
				release_builder,
				"freeze_process_authority",
				return_value=authority,
			),
			mock.patch.object(
				release_builder,
				"git_head",
				side_effect=cleanup_error,
			),
			mock.patch.object(release_builder, "build_release_artifacts") as build,
			mock.patch.object(release_builder, "audit_release_artifact_manifest") as audit,
			mock.patch.object(release_builder, "print_result") as print_result,
			self.assertRaises(SupervisedProcessCleanupError) as raised,
		):
			release_builder.main()

		self.assertIs(raised.exception, cleanup_error)
		build.assert_not_called()
		audit.assert_not_called()
		print_result.assert_not_called()

class ReleaseArtifactTests(unittest.TestCase):
	def test_build_publishes_only_two_archives_and_manifest(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			build_root = Path(temporary_directory) / "build"
			output_dir = build_root / "release"
			audit_calls: list[tuple[Path, str, str]] = []
			real_audit = release_builder.audit_release_artifact_manifest

			def recording_audit(
				manifest_path: Path,
				expected_version: str = "",
				expected_revision: str = "",
				expected_manifest_sha256: str = "",
			) -> dict[str, object]:
				manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
				self.assertEqual(manifest["source_revision"], REVISION)
				audit_calls.append((manifest_path, expected_version, expected_revision))
				return real_audit(
					manifest_path,
					expected_version,
					expected_revision,
					expected_manifest_sha256,
				)

			with (
				mock.patch.object(release_builder, "BUILD_ROOT", build_root),
				mock.patch.object(
					release_builder.build_asset_store_package,
					"read_plugin_version",
					return_value=VERSION,
				),
				mock.patch.object(
					release_builder.build_asset_store_package,
					"build_package",
					side_effect=_write_framework_archive,
				),
				mock.patch.object(
					release_builder.build_asset_store_package,
					"audit_package",
					return_value={"ok": True, "issues": []},
				),
				mock.patch.object(
					release_builder.build_asset_store_package,
					"iter_package_files",
					return_value=[],
				),
				mock.patch.object(
					release_builder,
					"audit_zip_matches_source",
					return_value=[],
				),
				mock.patch.object(
					release_builder.build_gf_ai_developer_kit,
					"check_source",
					return_value={"ok": True, "issues": []},
				),
				mock.patch.object(
					release_builder.build_gf_ai_developer_kit,
					"build_plugin_archive",
					side_effect=_write_ai_archive,
				),
				mock.patch.object(
					release_builder.build_gf_ai_developer_kit,
					"audit_plugin_archive",
					return_value={"ok": True, "issues": []},
				),
				mock.patch.object(
					release_builder,
					"audit_release_artifact_manifest",
					side_effect=recording_audit,
				),
			):
				result = release_builder.build_release_artifacts(
					VERSION,
					output_dir,
					source_revision=REVISION,
				)
			self.assertTrue(result["ok"], result["issues"])
			self.assertEqual(
				{path.name for path in output_dir.iterdir()},
				{
					f"gf-framework-{VERSION}.zip",
					f"gf-ai-developer-kit-{VERSION}.zip",
					f"gf-release-artifacts-{VERSION}.json",
				},
			)
			manifest = json.loads(
				(output_dir / f"gf-release-artifacts-{VERSION}.json").read_text(
					encoding="utf-8"
				)
			)
			self.assertEqual(manifest["schema_version"], 3)
			self.assertEqual(manifest["artifact_count"], 2)
			self.assertEqual(
				{entry["role"] for entry in manifest["artifacts"]},
				{"framework", "ai_developer_kit"},
			)
			self.assertEqual(manifest["source_revision"], REVISION)
			self.assertEqual(
				[(version, revision) for _path, version, revision in audit_calls],
				[(VERSION, REVISION), (VERSION, REVISION)],
			)
			self.assertNotEqual(audit_calls[0][0].parent, output_dir)
			self.assertEqual(audit_calls[1][0].parent, output_dir)

	def test_audit_rejects_legacy_registry_and_package_roles(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			manifest_path = _write_valid_release_fixture(root)
			data = json.loads(manifest_path.read_text(encoding="utf-8"))
			data["artifacts"].append({
				"role": "registry",
				"name": "gf-registry.json",
				"path": "gf-registry.json",
				"size_bytes": 0,
				"sha256": "0" * 64,
			})
			data["artifact_count"] = 3
			manifest_path.write_text(json.dumps(data), encoding="utf-8")
			result = release_builder.audit_release_artifact_manifest(
				manifest_path,
				VERSION,
				REVISION,
			)
			self.assertFalse(result["ok"])
			self.assertTrue(any("unsupported" in issue for issue in result["issues"]))

	def test_audit_rejects_extra_release_file(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			manifest_path = _write_valid_release_fixture(root)
			(root / "gf-kernel.zip").write_bytes(b"retired")
			with _release_audit_stubs():
				result = release_builder.audit_release_artifact_manifest(
					manifest_path,
					VERSION,
					REVISION,
				)
			self.assertFalse(result["ok"])
			self.assertTrue(any("only the two archives" in issue for issue in result["issues"]))

	def test_audit_rejects_extra_release_directory(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			manifest_path = _write_valid_release_fixture(root)
			(root / "packages").mkdir()
			with _release_audit_stubs():
				result = release_builder.audit_release_artifact_manifest(
					manifest_path,
					VERSION,
					REVISION,
				)
			self.assertFalse(result["ok"])
			self.assertTrue(any("only the two archives" in issue for issue in result["issues"]))

	def test_audit_rejects_boolean_integer_fields(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			manifest_path = _write_valid_release_fixture(root)
			data = json.loads(manifest_path.read_text(encoding="utf-8"))
			data["schema_version"] = True
			data["framework_archive_build_count"] = True
			data["artifact_count"] = True
			data["artifacts"][0]["size_bytes"] = True
			manifest_path.write_text(json.dumps(data), encoding="utf-8")
			result = release_builder.audit_release_artifact_manifest(
				manifest_path,
				VERSION,
				REVISION,
			)
			self.assertFalse(result["ok"])
			self.assertTrue(any("schema_version" in issue for issue in result["issues"]))
			self.assertTrue(any("artifact_count" in issue for issue in result["issues"]))

	def test_audit_rejects_duplicate_keys_non_finite_and_oversized_json(self) -> None:
		invalid_payloads = (
			b'{"schema_version":3,"schema_version":3}',
			b'{"schema_version":3,"artifact_count":NaN}',
			b" " * (release_builder.MANIFEST_MAX_BYTES + 1),
		)
		for payload in invalid_payloads:
			with self.subTest(size=len(payload)):
				with tempfile.TemporaryDirectory() as temporary_directory:
					manifest_path = (
						Path(temporary_directory)
						/ f"gf-release-artifacts-{VERSION}.json"
					)
					manifest_path.write_bytes(payload)
					result = release_builder.audit_release_artifact_manifest(
						manifest_path,
						VERSION,
						REVISION,
					)
					self.assertFalse(result["ok"])
					self.assertTrue(any("unreadable" in issue for issue in result["issues"]))

	def test_audit_rejects_artifact_tampering(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			manifest_path = _write_valid_release_fixture(root)
			(root / f"gf-framework-{VERSION}.zip").write_bytes(b"changed")
			with _release_audit_stubs():
				result = release_builder.audit_release_artifact_manifest(
					manifest_path,
					VERSION,
					REVISION,
				)
			self.assertFalse(result["ok"])
			self.assertTrue(any("mismatch" in issue.lower() for issue in result["issues"]))

	def test_validate_output_dir_rejects_build_root_itself(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			build_root = Path(temporary_directory) / "build"
			build_root.mkdir()
			with mock.patch.object(release_builder, "BUILD_ROOT", build_root):
				with self.assertRaises(ValueError):
					release_builder.validate_output_dir(build_root)


def _write_framework_archive(path: Path) -> None:
	_write_zip(path, "framework.txt", b"framework")


def _write_ai_archive(path: Path, _version: str) -> None:
	_write_zip(path, "ai.txt", b"ai")


def _write_zip(path: Path, name: str, payload: bytes) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	with zipfile.ZipFile(path, "w") as archive:
		archive.writestr(name, payload)


def _write_valid_release_fixture(root: Path) -> Path:
	framework = root / f"gf-framework-{VERSION}.zip"
	ai_kit = root / f"gf-ai-developer-kit-{VERSION}.zip"
	_write_framework_archive(framework)
	_write_ai_archive(ai_kit, VERSION)
	artifacts = [
		release_builder.artifact_record(framework, "framework"),
		release_builder.artifact_record(ai_kit, "ai_developer_kit"),
	]
	manifest_path = root / f"gf-release-artifacts-{VERSION}.json"
	release_builder.write_json(manifest_path, {
		"schema_version": release_builder.MANIFEST_SCHEMA_VERSION,
		"version": VERSION,
		"source_revision": REVISION,
		"framework_archive_build_count": 1,
		"ai_developer_kit_build_count": 1,
		"artifact_count": len(artifacts),
		"artifacts": artifacts,
	})
	return manifest_path


def _release_audit_stubs() -> mock._patch:
	stack = _PatchStack()
	stack.enter(mock.patch.object(
		release_builder.build_asset_store_package,
		"audit_package",
		return_value={"ok": True, "issues": []},
	))
	stack.enter(mock.patch.object(
		release_builder,
		"audit_zip_matches_source",
		return_value=[],
	))
	stack.enter(mock.patch.object(
		release_builder.build_gf_ai_developer_kit,
		"audit_plugin_archive",
		return_value={"ok": True, "issues": []},
	))
	return stack


class _PatchStack:
	def __init__(self) -> None:
		self._patches: list[mock._patch] = []

	def enter(self, patcher: mock._patch) -> None:
		patcher.start()
		self._patches.append(patcher)

	def __enter__(self) -> _PatchStack:
		return self

	def __exit__(self, *_args: object) -> None:
		for patcher in reversed(self._patches):
			patcher.stop()


if __name__ == "__main__":
	unittest.main()
