from __future__ import annotations

import configparser
import contextlib
import io
import json
import os
import struct
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
	def test_standalone_archive_rejects_noncanonical_paths_before_payload_reads(self) -> None:
		builder = release_builder.build_asset_store_package
		for entry in ("addons/gf/../escape.txt", "addons/gf/./same.txt", "addons/gf//empty.txt", "addons/gf/back\\slash.txt", "addons/gf/../outside/"):
			with self.subTest(entry=entry), tempfile.TemporaryDirectory() as directory:
				archive_path = Path(directory) / "framework.zip"
				with zipfile.ZipFile(archive_path, "w") as archive:
					for name in builder.REQUIRED_PACKAGE_PATHS:
						archive.writestr(name, f'[plugin]\nversion="{VERSION}"\n' if name.endswith("plugin.cfg") else "fixture")
					entry_info = zipfile.ZipInfo(entry)
					# ZipInfo's Windows constructor normalizes separators; preserve
					# the literal central-directory spelling of an external archive.
					entry_info.filename = entry
					archive.writestr(entry_info, "fixture")
				with mock.patch.object(zipfile.ZipFile, "open", side_effect=AssertionError("unsafe archive payload read")):
					result = builder.audit_package(archive_path, expected_version=VERSION)
				self.assertFalse(result["ok"])
				self.assertTrue(any("canonical" in issue for issue in result["issues"]), result)

	def test_asset_store_validate_only_checks_the_archived_version(self) -> None:
		builder = release_builder.build_asset_store_package
		for archived_version in ("10.0.0", VERSION):
			with self.subTest(archived_version=archived_version), tempfile.TemporaryDirectory() as directory:
				archive_path = Path(directory) / "framework.zip"
				with zipfile.ZipFile(archive_path, "w") as archive:
					for name in builder.REQUIRED_PACKAGE_PATHS:
						content = f'[plugin]\nversion="{archived_version}"\n' if name.endswith("plugin.cfg") else "fixture"
						archive.writestr(name, content)
				stdout = io.StringIO()
				with (
					mock.patch.object(sys, "argv", ["builder", "--version", VERSION, "--output", str(archive_path), "--validate-only", "--json"]),
					mock.patch.object(builder, "read_plugin_version", return_value=VERSION),
					mock.patch.object(builder, "configure_stdio"),
					contextlib.redirect_stdout(stdout),
				):
					status = builder.main()
				result = json.loads(stdout.getvalue())
				self.assertEqual(status, 0 if archived_version == VERSION else 1)
				self.assertEqual(result["archive_plugin_version"], archived_version)
				self.assertEqual(result["workspace_plugin_version"], VERSION)
				self.assertEqual(result["plugin_version"], archived_version)

	def test_asset_store_archive_version_requires_unique_bounded_utf8_config(self) -> None:
		builder = release_builder.build_asset_store_package
		valid = f'[plugin]\nversion="{VERSION}"\n'.encode("utf-8")
		for kind, payload in (
			("missing-version", b"[plugin]\n"),
			("invalid-utf8", b"[plugin]\nversion=\xff\n"),
			("oversized", valid + b"#" * builder.MAX_PLUGIN_CONFIG_BYTES),
			("duplicate", valid),
		):
			with self.subTest(kind=kind), tempfile.TemporaryDirectory() as directory:
				archive_path = Path(directory) / "framework.zip"
				with zipfile.ZipFile(archive_path, "w") as archive:
					for name in builder.REQUIRED_PACKAGE_PATHS:
						archive.writestr(name, payload if name.endswith("plugin.cfg") else b"fixture")
					if kind == "duplicate":
						with self.assertWarns(UserWarning):
							archive.writestr("addons/gf/plugin.cfg", valid)
				original = archive_path.read_bytes()
				result = builder.audit_package(archive_path, expected_version=VERSION)
				self.assertFalse(result["ok"])
				self.assertTrue(any("plugin.cfg" in issue for issue in result["issues"]))
				self.assertEqual(archive_path.read_bytes(), original)

	def test_asset_store_archive_version_must_be_explicit_in_plugin_section(self) -> None:
		builder = release_builder.build_asset_store_package
		for default_version, explicit_version, expected_ok in (
			(VERSION, None, False),
			("10.0.0", VERSION, True),
			(VERSION, "10.0.0", False),
		):
			with self.subTest(default=default_version, explicit=explicit_version), tempfile.TemporaryDirectory() as directory:
				config = f'[DEFAULT]\nversion="{default_version}"\n[plugin]\nname="GF"\n'
				if explicit_version is not None:
					config += f'version="{explicit_version}"\n'
				archive_path = Path(directory) / "framework.zip"
				with zipfile.ZipFile(archive_path, "w") as archive:
					for name in builder.REQUIRED_PACKAGE_PATHS:
						archive.writestr(name, config if name.endswith("plugin.cfg") else "fixture")
				original = archive_path.read_bytes()
				result = builder.audit_package(archive_path, expected_version=VERSION)
				self.assertEqual(result["ok"], expected_ok)
				self.assertEqual(result["archive_plugin_version"], explicit_version or "")
				self.assertEqual(archive_path.read_bytes(), original)

	def test_asset_store_archive_version_uses_exact_godot_key_and_separator(self) -> None:
		builder = release_builder.build_asset_store_package
		for kind, config, expected_version in _plugin_version_config_cases():
			with self.subTest(kind=kind), tempfile.TemporaryDirectory() as directory:
				archive_path = Path(directory) / "framework.zip"
				with zipfile.ZipFile(archive_path, "w") as archive:
					for name in builder.REQUIRED_PACKAGE_PATHS:
						archive.writestr(name, config if name.endswith("plugin.cfg") else "fixture")
				original = archive_path.read_bytes()
				result = builder.audit_package(archive_path, expected_version=expected_version or VERSION)
				self.assertEqual(result["ok"], bool(expected_version))
				self.assertEqual(result["archive_plugin_version"], expected_version)
				self.assertEqual(archive_path.read_bytes(), original)

	def test_workspace_plugin_version_uses_the_same_explicit_config_rules(self) -> None:
		builder = release_builder.build_asset_store_package
		for kind, config, expected_version in _plugin_version_config_cases():
			with self.subTest(kind=kind), tempfile.TemporaryDirectory() as directory:
				root = Path(directory)
				plugin_path = root / "addons/gf/plugin.cfg"
				plugin_path.parent.mkdir(parents=True)
				plugin_path.write_text(config, encoding="utf-8")
				with mock.patch.object(builder, "ROOT", root):
					try:
						actual_version = builder.read_plugin_version()
					except (configparser.Error, ValueError):
						actual_version = ""
				self.assertEqual(actual_version, expected_version)

	def test_build_publishes_only_five_archives_and_manifest(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			build_root = Path(temporary_directory) / "build"
			output_dir = build_root / "release"
			audit_calls: list[tuple[Path, str, str]] = []
			real_audit = release_builder.audit_release_artifact_manifest
			_test_delivery(build_root / "native-delivery")

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
				mock.patch.object(release_builder.gf_native_acceptance, "qualify", side_effect=_qualify_test_archives),
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
				published = {path.name: release_builder.sha256_file(path) for path in output_dir.iterdir()}
				with mock.patch.object(release_builder.gf_native_acceptance, "qualify",
						side_effect=RuntimeError("native export failed")):
					failed = release_builder.build_release_artifacts(VERSION, output_dir, source_revision=REVISION)
				self.assertFalse(failed["ok"])
				self.assertEqual(published, {path.name: release_builder.sha256_file(path) for path in output_dir.iterdir()})
			self.assertTrue(result["ok"], result["issues"])
			self.assertEqual(
				{path.name for path in output_dir.iterdir()},
				{
					f"gf-framework-{VERSION}.zip",
					f"gf-ai-developer-kit-{VERSION}.zip",
					f"gf-framework-windows-x86_64-{VERSION}.zip",
					f"gf-native-windows-x86_64-{VERSION}.zip",
					f"gf-native-multiplatform-{VERSION}.zip",
					f"gf-release-artifacts-{VERSION}.json",
				},
			)
			manifest = json.loads(
				(output_dir / f"gf-release-artifacts-{VERSION}.json").read_text(
					encoding="utf-8"
				)
			)
			self.assertEqual(manifest["schema_version"], 5)
			self.assertEqual(manifest["artifact_count"], 5)
			self.assertEqual(
				{entry["role"] for entry in manifest["artifacts"]},
				{"framework", "ai_developer_kit", "framework_windows_x86_64", "native_windows_x86_64", "native_multiplatform"},
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
			data["artifact_count"] = len(data["artifacts"])
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
			self.assertTrue(any("only the five archives" in issue for issue in result["issues"]))

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
			self.assertTrue(any("only the five archives" in issue for issue in result["issues"]))

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

	def test_native_archives_must_match_the_verified_version_and_portable_payload(self) -> None:
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			_write_valid_release_fixture(root)
			names = release_builder.archive_names(VERSION)
			portable = root / names["framework"]
			supplement = root / names["native_windows_x86_64"]
			bundle = root / names["framework_windows_x86_64"]
			verify = release_builder.gf_native_distribution.verify
			with self.assertRaisesRegex(ValueError, "version"):
				verify(portable, supplement, bundle, "other-version", REVISION)
			with self.assertRaisesRegex(ValueError, "source"):
				verify(portable, supplement, bundle, VERSION, "b" * 40)
			with zipfile.ZipFile(bundle, "a") as archive:
				archive.writestr("unqualified-addon.gd", "unexpected")
			with self.assertRaisesRegex(ValueError, "exactly"):
				verify(portable, supplement, bundle, VERSION, REVISION)

	def test_release_requires_runtime_evidence_for_the_exact_archive_and_every_abi(self) -> None:
		acceptance = release_builder.gf_native_platform_acceptance
		with tempfile.TemporaryDirectory() as temporary:
			directory = Path(temporary)
			_test_delivery(directory)
			debug = directory / "linux-debug.json"
			original = debug.read_text(encoding="utf-8")
			wrong = json.loads(original)
			wrong["runtime"]["x86_64"]["debug_build"] = False
			debug.write_text(json.dumps(wrong), encoding="utf-8")
			with self.assertRaisesRegex(ValueError, "debug template"):
				acceptance.verify_delivery(directory, VERSION, REVISION)
			debug.write_text(original, encoding="utf-8")
			path = directory / "android-release.json"
			proof = json.loads(path.read_text(encoding="utf-8"))
			proof["runtime"].pop("arm64-v8a")
			path.write_text(json.dumps(proof), encoding="utf-8")
			with self.assertRaisesRegex(ValueError, "architectures"):
				acceptance.verify_delivery(directory, VERSION, REVISION)
			proof["archive_sha256"] = "0" * 64
			path.write_text(json.dumps(proof), encoding="utf-8")
			with self.assertRaisesRegex(ValueError, "evidence"):
				acceptance.verify_delivery(directory, VERSION, REVISION)

	def test_linux_build_enforces_the_published_glibc_baseline(self) -> None:
		platforms = release_builder.gf_native_platforms
		requirements = [
			("GLIBC_2.34", True), ("GLIBC_2.3.4", True),
			("GLIBC_2.35", False), ("GLIBC_ABI_DT_RELR", False), ("GCC_3.0", False),
		]
		for requirement, valid in requirements:
			with self.subTest(requirement=requirement), mock.patch.object(platforms, "invoke", return_value="Name: " + requirement):
				if valid:
					platforms.check_linux_symbol_versions(Path("libgf_native.so"))
				else:
					with self.assertRaisesRegex(ValueError, "glibc"):
						platforms.check_linux_symbol_versions(Path("libgf_native.so"))

	def test_platform_slices_reject_swapped_os_and_alignment(self) -> None:
		platforms = release_builder.gf_native_platforms
		with tempfile.TemporaryDirectory() as temporary:
			stage = _test_slices(Path(temporary))
			device = platforms.staged_binary(stage, platforms.IOS, REVISION)
			with self.assertRaisesRegex(ValueError, "platform"):
				platforms.check_binary(platforms.SIM, device)
			newer = bytearray(device)
			struct.pack_into("<I", newer, 44, 17 << 16)
			with self.assertRaisesRegex(ValueError, "deployment minimum"):
				platforms.check_binary(platforms.IOS, newer)
			android = bytearray(platforms.staged_binary(stage, platforms.ANDROID_X64, REVISION))
			android.extend(b"libc.so.6\0")
			with self.assertRaisesRegex(ValueError, "libc"):
				platforms.check_binary(platforms.LINUX, android)
			invalid = bytearray(android)
			struct.pack_into("<I", invalid, 120, 0)
			with self.assertRaisesRegex(ValueError, "dynamic segment"):
				platforms.check_binary(platforms.ANDROID_X64, invalid)
			struct.pack_into("<Q", android, 64 + 48, 4096)
			with self.assertRaisesRegex(ValueError, "alignment"):
				platforms.check_binary(platforms.ANDROID_X64, android)
			with self.assertRaisesRegex(ValueError, "receipt"):
				platforms.staged_binary(stage, platforms.MAC, "b" * 40)
			with self.assertRaisesRegex(ValueError, "both iOS"):
				platforms.support_files({platforms.IOS}, b"notices")

	def test_validate_output_dir_rejects_build_root_itself(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			build_root = Path(temporary_directory) / "build"
			build_root.mkdir()
			with mock.patch.object(release_builder, "BUILD_ROOT", build_root):
				with self.assertRaises(ValueError):
					release_builder.validate_output_dir(build_root)


def _write_framework_archive(path: Path) -> None:
	_write_zip(path, "framework.txt", b"framework")


def _plugin_version_config_cases() -> tuple[tuple[str, str, str], ...]:
	return (
		("uppercase-key", f'[plugin]\nVERSION="{VERSION}"\n', ""),
		("mixed-case-key", f'[plugin]\nVersion="{VERSION}"\n', ""),
		("colon-separator", f'[plugin]\nversion: "{VERSION}"\n', ""),
		("uppercase-section", f'[Plugin]\nversion="{VERSION}"\n', ""),
		("default-only", f'[DEFAULT]\nversion="{VERSION}"\n[plugin]\nname="GF"\n', ""),
		("duplicate-version", f'[plugin]\nversion="{VERSION}"\nversion="{VERSION}"\n', ""),
		("duplicate-section", f'[plugin]\nversion="{VERSION}"\n[plugin]\nversion="{VERSION}"\n', ""),
		("valid", f'[plugin]\nversion="{VERSION}"\n', VERSION),
		("valid-spaces", f'[plugin]\nversion = "{VERSION}"\n', VERSION),
		("distinct-case-key", f'[plugin]\nVERSION="10.0.0"\nversion="{VERSION}"\n', VERSION),
		("explicit-over-default", f'[DEFAULT]\nversion="10.0.0"\n[plugin]\nversion="{VERSION}"\n', VERSION),
		("unquoted-stable-version", f'[plugin]\nversion={VERSION}\n', ""),
		("unquoted-development-version", '[plugin]\nversion=12.0.0-dev.0\n', ""),
		("empty-value", '[plugin]\nversion=\n', ""),
		("empty-string", '[plugin]\nversion=""\n', ""),
		("unterminated-string", f'[plugin]\nversion="{VERSION}\n', ""),
		("unmatched-closing-quote", f'[plugin]\nversion={VERSION}"\n', ""),
		("extra-quote", f'[plugin]\nversion="{VERSION}""\n', ""),
		("extra-declaration", f'[plugin]\nversion="{VERSION}"version="10.0.0"\n', ""),
		("escaped-quote", f'[plugin]\nversion="{VERSION}\\""\n', ""),
		("valid-development-version", '[plugin]\nversion="12.0.0-dev.0"\n', "12.0.0-dev.0"),
	)


def _write_ai_archive(path: Path, _version: str) -> None:
	_write_zip(path, "ai.txt", b"ai")


def _write_zip(path: Path, name: str, payload: bytes) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	with zipfile.ZipFile(path, "w") as archive:
		archive.writestr(name, payload)


def _windows_library() -> bytes:
	# Executable behavior is covered by the real exported games.
	library = bytearray(128)
	library[:2] = b"MZ"
	struct.pack_into("<I", library, 60, 64)
	library[64:68] = b"PE\0\0"
	struct.pack_into("<H", library, 68, 0x8664)
	struct.pack_into("<HH", library, 86, 0x2000, 0x20B)
	return bytes(library)


def _qualify_test_archives(
		portable: Path, supplement: Path, bundle: Path, version: str, revision: str, *, export: bool,
		candidate_library: bytes | None = None,
) -> dict[str, object]:
	if not export or candidate_library not in (None, _windows_library()):
		raise AssertionError("Windows must qualify the candidate library through both exports.")
	release_builder.gf_native_distribution.assemble(portable, supplement, bundle, _windows_library(),
		b"fixture toolchain copyright", version, revision)
	return {"archives_sha256": {p.name: release_builder.sha256_file(p) for p in (portable, supplement, bundle)}}


def _test_slices(directory: Path) -> Path:
	"""Minimal target headers for transport tests. Export jobs use actual Cargo binaries."""
	platforms = release_builder.gf_native_platforms
	for target, (_, filename) in platforms.TARGETS.items():
		data = bytearray(128)
		if target == platforms.WINDOWS:
			data = bytearray(_windows_library())
		elif target in (platforms.MAC, platforms.IOS, platforms.SIM):
			struct.pack_into("<8I", data, 0, 0xfeedfacf, 0x100000c, 0, 6, 1, 24, 0, 0)
			platform = {platforms.MAC: 1, platforms.IOS: 2, platforms.SIM: 7}[target]
			struct.pack_into("<6I", data, 32, 0x32, 24, platform, 15 << 16, 0, 0)
		else:
			data[:6] = b"\x7fELF\x02\x01"
			struct.pack_into("<HH", data, 16, 3, 183 if target == platforms.ANDROID_ARM else 62)
			struct.pack_into("<Q", data, 32, 64)
			names = b"\0libc.so.6\0" if target == platforms.LINUX else b"\0libc.so\0"
			data.extend(bytes(256 - len(data)))
			struct.pack_into("<HH", data, 54, 56, 2)
			struct.pack_into("<II6Q", data, 64, 1, 5, 0, 0, 0, 256 + len(names), 256 + len(names), 16384)
			struct.pack_into("<II6Q", data, 120, 2, 4, 176, 176, 0, 64, 64, 8)
			struct.pack_into("<8Q", data, 176, 1, 1, 5, 256, 10, len(names), 0, 0)
			data.extend(names)
		folder = directory / target
		folder.mkdir(parents=True)
		if target == platforms.WINDOWS:
			(folder / platforms.dist.STD_NOTICES).write_bytes(b"fixture toolchain copyright")
		else:
			data.extend(platforms.dist.notice_bytes() + b"\n\nfixture toolchain copyright")
		(folder / Path(filename).name).write_bytes(data)
		record = platforms.stage_record(target, bytes(data), REVISION)
		(folder / "build.json").write_text(json.dumps(record), encoding="utf-8")
	return directory


def _test_delivery(directory: Path) -> None:
	platforms = release_builder.gf_native_platforms
	with tempfile.TemporaryDirectory() as scratch:
		platforms.assemble(directory / "overlay.zip", _test_slices(Path(scratch)), set(platforms.TARGETS), VERSION, REVISION)
	digest = release_builder.sha256_file(directory / "overlay.zip")
	for platform, os_name, abis in [
		("linux", "Linux", {"x86_64": "x86_64"}),
		("android", "Android", {"arm64-v8a": "arm64", "x86_64": "x86_64"}),
		("ios", "iOS", {"arm64-simulator": "arm64"}),
	]:
		for profile in ("debug", "release"):
			runtime = {}
			for abi, arch in abis.items():
				samples = [dict(source_rows=n, selected_rows=n // 2, int64_columns=4,
					native_usec=[1] * 10, script_usec=[2] * 10) for n in (16, 1000, 100000)]
				foundation = {name: dict(native_usec=[1] * 5, script_usec=[2] * 5)
					for name in ("terrain_rgb_256", "wfc_entropy_16")}
				runtime[abi] = dict(ok=True, failures=[], platform=os_name, architecture=arch, run_token="a" * 24,
					samples=samples, foundation=foundation, debug_build=profile == "debug")
			proof = dict(platform=platform, profile=profile, source_revision=REVISION, archive_sha256=digest,
				native_source_sha256=platforms.dist.native_source_digest(), runtime=runtime)
			(directory / f"{platform}-{profile}.json").write_text(json.dumps(proof), encoding="utf-8")


def _write_valid_release_fixture(root: Path) -> Path:
	framework = root / f"gf-framework-{VERSION}.zip"
	ai_kit = root / f"gf-ai-developer-kit-{VERSION}.zip"
	_write_framework_archive(framework)
	_write_ai_archive(ai_kit, VERSION)
	archives = {role: root / name for role, name in release_builder.archive_names(VERSION).items()}
	_qualify_test_archives(framework, archives["native_windows_x86_64"], archives["framework_windows_x86_64"],
		VERSION, REVISION, export=True)
	platforms = release_builder.gf_native_platforms
	with tempfile.TemporaryDirectory() as temporary:
		platforms.assemble(archives["native_multiplatform"], _test_slices(Path(temporary)), set(platforms.TARGETS),
			VERSION, REVISION)
	artifacts = [release_builder.artifact_record(path, role) for role, path in archives.items()]
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
