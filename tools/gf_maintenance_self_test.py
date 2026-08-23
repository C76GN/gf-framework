#!/usr/bin/env python3
"""White-box contract tests for the live GF maintenance runtime.

The maintenance CLI loads this module only for ``maintenance-self-test``.  The
large test body is intentionally rebound to the caller's live module namespace
so its scoped global fixtures retain the exact semantics they had when the body
lived inline in ``gf_maintenance.py``.  This is a migration seam, not a public
extension API; focused tests should gradually replace white-box cases over time.
"""

from __future__ import annotations

from types import FunctionType
from types import ModuleType
from typing import Any


def _run_in_module_namespace(runtime_module: ModuleType, body: FunctionType) -> Any:
	"""Run a zero-argument white-box body against one live module namespace."""
	if body.__closure__ is not None:
		raise ValueError("maintenance self-test bodies must not capture a closure")
	bound_body = FunctionType(
		body.__code__,
		vars(runtime_module),
		name=body.__name__,
		argdefs=body.__defaults__,
		closure=None,
	)
	bound_body.__kwdefaults__ = body.__kwdefaults__
	return bound_body()


def run_maintenance_self_test(runtime_module: ModuleType) -> dict[str, Any]:
	"""Execute the canonical self-test body against ``runtime_module``."""
	return _run_in_module_namespace(runtime_module, _maintenance_self_test_body)


def _maintenance_self_test_body() -> dict[str, Any]:
	global _ACTIVE_WORKSPACE_SNAPSHOT
	tests: list[dict[str, Any]] = []
	failures: list[dict[str, Any]] = []

	def record_result(name: str, passed: bool, message: str = "") -> None:
		result = {"name": name, "passed": passed}
		if message and not passed:
			result["message"] = message
		tests.append(result)
		if not passed:
			failures.append(result)

	reference_check_command = CHECK_DEFINITIONS["examples_sync"]
	reference_apply_command = CHECK_DEFINITIONS["examples_sync_write"]
	record_result(
		"reference_sync_commands_separate_read_only_check_from_explicit_apply",
		"--check" in reference_check_command
		and "--apply" not in reference_check_command
		and "--apply" in reference_apply_command
		and "--check" not in reference_apply_command,
		"Examples validation must use --check, while authorized synchronization must use --apply.",
	)

	normalized_log_argv = normalize_maintenance_cli_argv([
		"gf_maintenance.py",
		"check",
		"--suite",
		"quick",
		"--keep-logs",
	])
	record_result(
		"maintenance_keep_logs_flag_normalizes_after_subcommand",
		normalized_log_argv == [
			"gf_maintenance.py",
			"--keep-logs",
			"check",
			"--suite",
			"quick",
		]
		and maintenance_cli_command(normalized_log_argv) == "check",
		"--keep-logs must be accepted after a subcommand without changing command discovery.",
	)
	normalized_json_output_argv = normalize_maintenance_cli_argv([
		"gf_maintenance.py",
		"check",
		"--suite",
		"quick",
		"--json-output",
		"build/quick-result.json",
	])
	record_result(
		"maintenance_json_output_flag_normalizes_after_subcommand",
		normalized_json_output_argv == [
			"gf_maintenance.py",
			"--json-output",
			"build/quick-result.json",
			"check",
			"--suite",
			"quick",
		]
		and maintenance_cli_command(normalized_json_output_argv) == "check",
		"--json-output must be accepted after a subcommand without hiding the command name.",
	)
	command_output_exact_text = "A\u754c\U0001f642"
	command_output_over_text = command_output_exact_text + "Z"
	command_output_exact = CommandResult(
		name="output-exact-fixture",
		command=["fixture"],
		exit_code=0,
		stdout=command_output_exact_text,
		stderr=command_output_exact_text,
	).to_dict(max_output_chars=3)
	command_output_over = CommandResult(
		name="output-over-fixture",
		command=["fixture"],
		exit_code=1,
		stdout=command_output_over_text,
		stderr=command_output_over_text,
	).to_dict(max_output_chars=3)
	command_output_over_rendered = maintenance_rendering.render_failed_check_annotation(
		command_output_over
	)
	command_output_zero = CommandResult(
		name="output-zero-fixture",
		command=["fixture"],
		exit_code=1,
		stdout="x",
		stderr="",
	).to_dict(max_output_chars=0)
	command_output_negative_rejected = False
	try:
		CommandResult(
			name="output-negative-fixture",
			command=["fixture"],
			exit_code=1,
			stdout="x",
			stderr="y",
		).to_dict(max_output_chars=-1)
	except ValueError:
		command_output_negative_rejected = True
	record_result(
		"command_results_bind_bounded_tails_to_complete_output_evidence",
		command_output_exact.get("stdout") == command_output_exact_text
		and command_output_exact.get("stderr") == command_output_exact_text
		and command_output_exact.get("stdout_char_count") == 3
		and command_output_exact.get("stderr_char_count") == 3
		and command_output_exact.get("stdout_utf8_byte_count") == 8
		and command_output_exact.get("stderr_utf8_byte_count") == 8
		and command_output_exact.get("stdout_sha256")
		== hashlib.sha256(command_output_exact_text.encode("utf-8")).hexdigest()
		and command_output_exact.get("stderr_sha256")
		== hashlib.sha256(command_output_exact_text.encode("utf-8")).hexdigest()
		and command_output_exact.get("stdout_truncated") is False
		and command_output_exact.get("stderr_truncated") is False
		and command_output_over.get("stdout") == "\u754c\U0001f642Z"
		and command_output_over.get("stderr") == "\u754c\U0001f642Z"
		and command_output_over.get("stdout_char_count") == 4
		and command_output_over.get("stderr_char_count") == 4
		and command_output_over.get("stdout_utf8_byte_count") == 9
		and command_output_over.get("stderr_utf8_byte_count") == 9
		and command_output_over.get("stdout_sha256")
		== hashlib.sha256(command_output_over_text.encode("utf-8")).hexdigest()
		and command_output_over.get("stderr_sha256")
		== hashlib.sha256(command_output_over_text.encode("utf-8")).hexdigest()
		and command_output_over.get("stdout_truncated") is True
		and command_output_over.get("stderr_truncated") is True
		and (
			"stdout_truncated: true original_chars=4 original_utf8_bytes=9"
			in command_output_over_rendered
		)
		and (
			"stderr_truncated: true original_chars=4 original_utf8_bytes=9"
			in command_output_over_rendered
		)
		and command_output_zero.get("stdout") == ""
		and command_output_zero.get("stderr") == ""
		and command_output_zero.get("stdout_char_count") == 1
		and command_output_zero.get("stderr_char_count") == 0
		and command_output_zero.get("stdout_utf8_byte_count") == 1
		and command_output_zero.get("stderr_utf8_byte_count") == 0
		and command_output_zero.get("stdout_sha256")
		== hashlib.sha256(b"x").hexdigest()
		and command_output_zero.get("stderr_sha256")
		== hashlib.sha256(b"").hexdigest()
		and command_output_zero.get("stdout_truncated") is True
		and command_output_zero.get("stderr_truncated") is False
		and command_output_negative_rejected,
		"CommandResult tails must preserve existing fields while reporting exact full-output character/UTF-8 counts, SHA-256, and truncation at 0/N/N+1 boundaries.",
	)
	mcp_server_source = read_text_file(ROOT / "tools/gf_mcp_server.py")
	record_result(
		"mcp_checks_use_managed_log_hygiene_boundary",
		"gf_maintenance.run_checks_with_log_hygiene(" in mcp_server_source
		and '"suite_timeout_seconds"' in mcp_server_source
		and '"jobs"' in mcp_server_source
		and '"minItems": 1' in mcp_server_source
		and '"maxItems": 128' in mcp_server_source
		and '"uniqueItems": True' in mcp_server_source
		and "_validate_schema(arguments, tool[\"inputSchema\"]" in mcp_server_source
		and "gf_maintenance.MAX_PARALLEL_FULL_JOBS" in mcp_server_source,
		"MCP checks must preserve log cleanup, reject ambiguous empty selections, and expose bounded Full parallelism and deadlines.",
	)
	record_result(
		"package_smoke_redirect_rejects_response_splitting_controls",
		validate_package_smoke_header_value("/registry/index.json?channel=stable")
		== "/registry/index.json?channel=stable"
		and validate_package_smoke_header_value("/registry/%0d%0aindex.json")
		== "/registry/%0d%0aindex.json"
		and validate_package_smoke_header_value("/registry/index.json\r\nX-Injected: yes") is None
		and validate_package_smoke_header_value("/registry/index.json\nX-Injected: yes") is None
		and validate_package_smoke_header_value("/registry/index.json\rX-Injected: yes") is None,
		"package smoke redirects must preserve safe targets and reject every raw CR/LF header boundary.",
	)
	default_source_smoke_url = package_smoke_default_registry_source_url("http://127.0.0.1:8123")
	record_result(
		"package_default_source_smoke_does_not_depend_on_insecure_http_redirects",
		default_source_smoke_url == "http://127.0.0.1:8123/sources/default_godot_cli.json"
		and "/redirect/" not in urllib.parse.urlparse(default_source_smoke_url).path,
		"The local HTTP default-source smoke must use the source manifest directly; redirect coverage belongs to the native HTTPS policy tests.",
	)
	with tempfile.TemporaryDirectory(prefix="gf-workspace-snapshot-self-test-") as temp_dir:
		snapshot_path = Path(temp_dir) / "fixture.txt"
		snapshot_path.write_text("first", encoding="utf-8")
		snapshot = WorkspaceSnapshot(ROOT)
		first_read = snapshot.read_utf8_text(snapshot_path)
		cached_read = snapshot.read_utf8_text(snapshot_path)
		snapshot_path.write_text("second-value", encoding="utf-8")
		changed_read = snapshot.read_utf8_text(snapshot_path)
		missing_snapshot_path = Path(temp_dir) / "missing.txt"
		strict_missing_raised = False
		try:
			snapshot.read_utf8_text_strict(missing_snapshot_path)
		except OSError:
			strict_missing_raised = True
		factory_calls = 0

		def snapshot_fixture_factory() -> list[str]:
			nonlocal factory_calls
			factory_calls += 1
			return ["cached"]

		first_value = snapshot.memoize("fixture", ("key",), snapshot_fixture_factory)
		second_value = snapshot.memoize("fixture", ("key",), snapshot_fixture_factory)
		record_result(
			"workspace_snapshot_caches_reads_and_invalidates_changed_files",
			first_read == "first"
			and cached_read == "first"
			and changed_read == "second-value"
			and snapshot.stats()["text_cache_hits"] == 1,
			f"workspace text cache must be invocation-scoped and stat-aware: {snapshot.stats()}",
		)
		record_result(
			"workspace_snapshot_strict_reads_fail_closed",
			strict_missing_raised
			and snapshot.read_utf8_text(missing_snapshot_path) == "",
			"Security-sensitive static gates must reuse the snapshot cache without swallowing read failures.",
		)
		record_result(
			"workspace_snapshot_memoizes_suite_inventory",
			first_value is second_value and factory_calls == 1,
			"workspace inventory factories should execute once per suite key.",
		)

	fixture_graph = CheckGraph(
		["source", "compile", "test", "report"],
		{
			"compile": ["source"],
			"test": ["compile"],
			"report": ["compile"],
		},
	)
	fixture_expansion = fixture_graph.expand(["test", "report"])
	record_result(
		"maintenance_check_graph_expands_shared_dependencies_once",
		fixture_expansion == ["source", "compile", "test", "report"]
		and fixture_graph.describe(fixture_expansion)["edge_count"] == 3,
		f"check graph must be deterministic and deduplicate shared dependencies: {fixture_expansion}",
	)
	cycle_rejected = False
	try:
		CheckGraph(["first", "second"], {"first": ["second"], "second": ["first"]})
	except ValueError:
		cycle_rejected = True
	record_result(
		"maintenance_check_graph_rejects_cycles_before_execution",
		cycle_rejected,
		"cyclic check dependencies must fail before any check starts.",
	)
	record_result(
		"maintenance_check_graph_accepts_release_metadata_node",
		maintenance_check_graph().expand(["release_metadata"]) == ["release_metadata"]
		and "release_metadata" in maintenance_check_graph().expand(RELEASE_CHECKS),
		"the synthetic release metadata check must be a validated DAG node.",
	)
	fixture_timeout = resolve_timeout_budget(600.0, 900.0, 75.0)
	record_result(
		"maintenance_timeout_budget_applies_policy_override_and_suite_deadline",
		fixture_timeout.policy_seconds == 600.0
		and fixture_timeout.requested_minimum_seconds == 900.0
		and fixture_timeout.effective_seconds == 75.0,
		f"suite deadline must cap the check policy and requested minimum: {fixture_timeout}",
	)
	invalid_fingerprint_values_rejected = True
	for invalid_value in (math.nan, math.inf, -math.inf):
		try:
			stable_fingerprint({"timeout": invalid_value})
		except (TypeError, ValueError):
			continue
		invalid_fingerprint_values_rejected = False
	invalid_timeout_values_rejected = True
	for timeout_arguments in (
		(math.nan, None, None),
		(1.0, math.inf, None),
		(1.0, None, -1.0),
	):
		try:
			resolve_timeout_budget(*timeout_arguments)
		except ValueError:
			continue
		invalid_timeout_values_rejected = False
	record_result(
		"maintenance_fingerprints_and_timeouts_reject_non_finite_values",
		invalid_fingerprint_values_rejected and invalid_timeout_values_rejected,
		"Provenance JSON and timeout budgets must reject non-finite or negative values before execution.",
	)
	fingerprint_a = stable_fingerprint({"name": "fixture", "values": [1, 2]})
	fingerprint_b = stable_fingerprint({"values": [1, 2], "name": "fixture"})
	fingerprint_changed = stable_fingerprint({"name": "fixture", "values": [1, 3]})
	record_result(
		"maintenance_fingerprints_are_stable_and_content_sensitive",
		fingerprint_a == fingerprint_b and fingerprint_a != fingerprint_changed,
		"fingerprints must ignore dictionary insertion order but change with their inputs.",
	)

	with tempfile.TemporaryDirectory(prefix="gf-package-artifact-set-self-test-") as temp_dir:
		fixture_root = Path(temp_dir)
		producer_root = fixture_root / "producer"
		(producer_root / "packages").mkdir(parents=True)
		(producer_root / "registry").mkdir()
		(producer_root / "offline_bundle").mkdir()
		archive_path = producer_root / "packages/gf.fixture.zip"
		registry_path = producer_root / gf_package_artifact_set.REGISTRY_RELATIVE_PATH
		registry_source_path = producer_root / gf_package_artifact_set.REGISTRY_SOURCE_RELATIVE_PATH
		offline_bundle_path = producer_root / gf_package_artifact_set.OFFLINE_BUNDLE_RELATIVE_PATH
		archive_path.write_bytes(b"fixture-package-archive")
		registry_path.write_text("{}\n", encoding="utf-8")
		registry_source_path.write_text("{}\n", encoding="utf-8")
		offline_bundle_path.write_bytes(b"fixture-offline-bundle")
		fixture_workspace_state = {
			"schema_version": 1,
			"head": "1" * 40,
			"dirty": True,
			"fingerprint": "2" * 64,
		}
		fixture_builder_data = {
			"ok": True,
			"issues": [],
			"output_dir": (producer_root / "packages").as_posix(),
			"registry": registry_path.as_posix(),
			"registry_source": registry_source_path.as_posix(),
			"offline_bundle": offline_bundle_path.as_posix(),
			"package_count": 1,
			"packages": [{
				"id": "gf.fixture",
				"kind": "kernel",
				"ok": True,
				"issues": [],
				"archive": archive_path.as_posix(),
				"size_bytes": archive_path.stat().st_size,
				"sha256": sha256_file(archive_path),
			}],
		}
		sealed_set = gf_package_artifact_set.seal_package_artifact_set(
			producer_root,
			fixture_builder_data,
			fixture_workspace_state,
		)
		private_set = gf_package_artifact_set.materialize_package_artifact_set(
			sealed_set,
			fixture_root / "consumer",
		)
		original_artifact_copy = gf_package_artifact_set._copy_regular_file_with_deadline
		failed_private_cleanup_rejected = False
		try:
			def fail_private_artifact_copy(*_args: Any, **_kwargs: Any) -> None:
				raise OSError("fixture copy failure")

			gf_package_artifact_set._copy_regular_file_with_deadline = fail_private_artifact_copy
			try:
				gf_package_artifact_set.materialize_package_artifact_set(
					sealed_set,
					fixture_root / "failed-consumer",
				)
			except OSError:
				failed_private_cleanup_rejected = True
		finally:
			gf_package_artifact_set._copy_regular_file_with_deadline = original_artifact_copy
		artifact_cleanup_root = fixture_root / "artifact-cleanup-owned"
		artifact_cleanup_moved = fixture_root / "artifact-cleanup-moved"
		artifact_cleanup_root.mkdir()
		artifact_cleanup_identity = artifact_cleanup_root.lstat()
		os.replace(artifact_cleanup_root, artifact_cleanup_moved)
		artifact_cleanup_root.mkdir()
		artifact_identity_issue = gf_package_artifact_set._safe_remove_private_tree(
			artifact_cleanup_root,
			expected_identity=artifact_cleanup_identity,
		)
		private_archive = private_set.package_archive_paths[0]
		artifact_deadline_rejected = False
		try:
			sealed_set.revalidate(deadline=time.perf_counter() - 1.0)
		except PackageArtifactDeadlineError:
			artifact_deadline_rejected = True
		consumer_deadline_rejected = False
		try:
			load_or_build_private_package_artifact_set(
				fixture_root,
				fixture_root / "expired-consumer",
				sealed_set.manifest_path.as_posix(),
				sealed_set.manifest_sha256,
				fixture_workspace_state,
				deadline=time.perf_counter() - 1.0,
			)
		except PackageArtifactDeadlineError:
			consumer_deadline_rejected = True
		private_archive.write_bytes(b"tampered-private-copy")
		private_tamper_rejected = False
		workspace_mismatch_rejected = False
		try:
			private_set.revalidate()
		except PackageArtifactSetError:
			private_tamper_rejected = True
		try:
			gf_package_artifact_set.load_package_artifact_set(
				sealed_set.manifest_path,
				sealed_set.manifest_sha256,
				{**fixture_workspace_state, "fingerprint": "3" * 64},
			)
		except PackageArtifactSetError:
			workspace_mismatch_rejected = True
		record_result(
			"package_artifact_set_is_sealed_and_consumers_are_private",
			sealed_set.revalidate().manifest_sha256 == sealed_set.manifest_sha256
			and private_tamper_rejected
			and workspace_mismatch_rejected
			and artifact_deadline_rejected
			and consumer_deadline_rejected
			and failed_private_cleanup_rejected
			and not list(fixture_root.glob(".failed-consumer.a-*"))
			and bool(artifact_identity_issue)
			and artifact_cleanup_root.exists()
			and artifact_cleanup_moved.exists()
			and archive_path.read_bytes() == b"fixture-package-archive",
			"Package smoke artifacts must bind provenance, honor absolute deadlines, isolate writes, clean failed staging, and refuse replaced roots.",
		)

	windows_short_repository_root = PureWindowsPath(
		r"C:\Users\RUNNER~1\AppData\Local\Temp\gf-fixture\source"
	)
	windows_long_repository_root = PureWindowsPath(
		r"C:\Users\runneradmin\AppData\Local\Temp\gf-fixture\source"
	)

	def injected_windows_long_path_name(
		path_value: os.PathLike[str],
		_deadline: float | None,
	) -> os.PathLike[str]:
		path = PureWindowsPath(path_value)
		if path == windows_short_repository_root:
			return windows_long_repository_root
		return path

	def failing_windows_long_path_name(
		_path_value: os.PathLike[str],
		_deadline: float | None,
	) -> os.PathLike[str]:
		raise OSError("fixture long-path expansion failure")

	record_result(
		"windows_repository_root_alias_only_accepts_bounded_long_name_expansion",
		gf_parallel_validation._windows_long_repository_paths_match(
			windows_short_repository_root,
			windows_long_repository_root,
			long_path_name=injected_windows_long_path_name,
		)
		and not gf_parallel_validation._windows_long_repository_paths_match(
			PureWindowsPath(r"S:\gf-fixture\source"),
			windows_long_repository_root,
			long_path_name=injected_windows_long_path_name,
		)
		and not gf_parallel_validation._windows_long_repository_paths_match(
			windows_short_repository_root,
			PureWindowsPath(r"C:\Users\runneradmin\AppData\Local\Temp\other\source"),
			long_path_name=injected_windows_long_path_name,
		)
		and not gf_parallel_validation._windows_long_repository_paths_match(
			windows_short_repository_root,
			windows_long_repository_root,
			long_path_name=failing_windows_long_path_name,
		),
		"Repository roots may accept only same-drive Windows 8.3 names that expand exactly to Git's long path.",
	)

	windows_directory_mode = stat.S_IFDIR | 0o755

	def windows_directory_metadata(inode: int) -> argparse.Namespace:
		return argparse.Namespace(
			st_mode=windows_directory_mode,
			st_dev=7,
			st_ino=inode,
			st_file_attributes=0,
		)

	windows_drive_metadata = windows_directory_metadata(1)
	windows_leaf_metadata = windows_directory_metadata(2)
	stable_short_chain = (
		(Path("short-drive"), windows_drive_metadata),
		(Path("short-leaf"), windows_leaf_metadata),
	)
	stable_long_chain = (
		(Path("long-drive"), windows_drive_metadata),
		(Path("long-leaf"), windows_leaf_metadata),
	)

	def windows_snapshot_sequence(
		snapshots: tuple[tuple[tuple[Path, argparse.Namespace], ...], ...],
	) -> tuple[
		Callable[[Path, float | None], tuple[tuple[Path, argparse.Namespace], ...]],
		list[Path],
	]:
		calls: list[Path] = []

		def snapshot(
			path_value: Path,
			_deadline: float | None,
		) -> tuple[tuple[Path, argparse.Namespace], ...]:
			calls.append(path_value)
			return snapshots[len(calls) - 1]

		return snapshot, calls

	lexical_snapshot_calls: list[Path] = []
	lexical_long_path_calls: list[os.PathLike[str]] = []

	def reject_unexpected_windows_snapshot(
		path_value: Path,
		_deadline: float | None,
	) -> tuple[tuple[Path, argparse.Namespace], ...]:
		lexical_snapshot_calls.append(path_value)
		raise AssertionError("lexically unsafe roots must not reach filesystem inspection")

	def reject_unexpected_windows_long_path(
		path_value: os.PathLike[str],
		_deadline: float | None,
	) -> os.PathLike[str]:
		lexical_long_path_calls.append(path_value)
		raise AssertionError("lexically unsafe roots must not reach WinAPI expansion")

	record_result(
		"windows_repository_root_alias_rejects_unsafe_namespaces_before_io",
		all(
			not gf_parallel_validation._windows_repository_root_alias_is_safe(
				unsafe_root,
				windows_long_repository_root,
				deadline=None,
				snapshot_directory_chain=reject_unexpected_windows_snapshot,
				long_path_name=reject_unexpected_windows_long_path,
			)
			for unsafe_root in (
				PureWindowsPath(r"S:\gf-fixture\source"),
				PureWindowsPath(r"\\server\share\gf-fixture\source"),
				PureWindowsPath(r"\\?\C:\gf-fixture\source"),
				PureWindowsPath(r"gf-fixture\source"),
			)
		)
		and not lexical_snapshot_calls
		and not lexical_long_path_calls,
		"Cross-drive, UNC, device, and relative Windows roots must be rejected before filesystem or WinAPI access.",
	)

	stable_snapshot, stable_snapshot_calls = windows_snapshot_sequence(
		(stable_short_chain, stable_long_chain, stable_short_chain, stable_long_chain)
	)
	mismatched_leaf_chain = (
		(Path("mismatched-drive"), windows_drive_metadata),
		(Path("mismatched-leaf"), windows_directory_metadata(3)),
	)
	mismatch_snapshot, mismatch_snapshot_calls = windows_snapshot_sequence(
		(stable_short_chain, mismatched_leaf_chain)
	)
	drifted_short_chain = (
		(Path("short-drive"), windows_drive_metadata),
		(Path("short-leaf"), windows_directory_metadata(4)),
	)
	root_drift_snapshot, root_drift_snapshot_calls = windows_snapshot_sequence(
		(stable_short_chain, stable_long_chain, drifted_short_chain, stable_long_chain)
	)
	drifted_long_chain = (
		(Path("long-drive"), windows_drive_metadata),
		(Path("long-leaf"), windows_directory_metadata(5)),
	)
	reported_drift_snapshot, reported_drift_snapshot_calls = windows_snapshot_sequence(
		(stable_short_chain, stable_long_chain, stable_short_chain, drifted_long_chain)
	)
	record_result(
		"windows_repository_root_alias_pins_identity_and_both_directory_chains",
		gf_parallel_validation._windows_repository_root_alias_is_safe(
			windows_short_repository_root,
			windows_long_repository_root,
			deadline=None,
			snapshot_directory_chain=stable_snapshot,
			long_path_name=injected_windows_long_path_name,
		)
		and len(stable_snapshot_calls) == 4
		and not gf_parallel_validation._windows_repository_root_alias_is_safe(
			windows_short_repository_root,
			windows_long_repository_root,
			deadline=None,
			snapshot_directory_chain=mismatch_snapshot,
			long_path_name=injected_windows_long_path_name,
		)
		and len(mismatch_snapshot_calls) == 2
		and not gf_parallel_validation._windows_repository_root_alias_is_safe(
			windows_short_repository_root,
			windows_long_repository_root,
			deadline=None,
			snapshot_directory_chain=root_drift_snapshot,
			long_path_name=injected_windows_long_path_name,
		)
		and len(root_drift_snapshot_calls) == 4
		and not gf_parallel_validation._windows_repository_root_alias_is_safe(
			windows_short_repository_root,
			windows_long_repository_root,
			deadline=None,
			snapshot_directory_chain=reported_drift_snapshot,
			long_path_name=injected_windows_long_path_name,
		)
		and len(reported_drift_snapshot_calls) == 4,
		"Windows root aliases must share one leaf identity and keep both directory chains stable around expansion.",
	)

	unsafe_snapshot_rejected = False
	unsafe_snapshot_calls = 0

	def reject_windows_reparse_snapshot(
		_path_value: Path,
		_deadline: float | None,
	) -> tuple[tuple[Path, argparse.Namespace], ...]:
		nonlocal unsafe_snapshot_calls
		unsafe_snapshot_calls += 1
		raise gf_parallel_validation.UnsafeWorkspacePathError("fixture reparse point")

	try:
		gf_parallel_validation._windows_repository_root_alias_is_safe(
			windows_short_repository_root,
			windows_long_repository_root,
			deadline=None,
			snapshot_directory_chain=reject_windows_reparse_snapshot,
			long_path_name=injected_windows_long_path_name,
		)
	except gf_parallel_validation.UnsafeWorkspacePathError:
		unsafe_snapshot_rejected = True
	expired_snapshot_calls = 0
	expired_long_path_calls = 0

	def reject_expired_windows_snapshot(
		_path_value: Path,
		_deadline: float | None,
	) -> tuple[tuple[Path, argparse.Namespace], ...]:
		nonlocal expired_snapshot_calls
		expired_snapshot_calls += 1
		return stable_short_chain

	def reject_expired_windows_long_path(
		path_value: os.PathLike[str],
		_deadline: float | None,
	) -> os.PathLike[str]:
		nonlocal expired_long_path_calls
		expired_long_path_calls += 1
		return path_value

	expired_alias_rejected = False
	try:
		gf_parallel_validation._windows_repository_root_alias_is_safe(
			windows_short_repository_root,
			windows_long_repository_root,
			deadline=time.perf_counter() - 1.0,
			snapshot_directory_chain=reject_expired_windows_snapshot,
			long_path_name=reject_expired_windows_long_path,
		)
	except WorkspaceDeadlineError:
		expired_alias_rejected = True
	record_result(
		"windows_repository_root_alias_propagates_unsafe_snapshots_and_deadlines",
		unsafe_snapshot_rejected
		and unsafe_snapshot_calls == 1
		and expired_alias_rejected
		and expired_snapshot_calls == 0
		and expired_long_path_calls == 0,
		"Reparse-point rejection must propagate, and an expired deadline must stop before native or filesystem work.",
	)

	buffer_requests: list[int] = []

	def grow_windows_long_path_buffer(
		_path_text: str,
		buffer_characters: int,
	) -> tuple[int, str]:
		buffer_requests.append(buffer_characters)
		if len(buffer_requests) == 1:
			return 512, ""
		return len(str(windows_long_repository_root)), str(windows_long_repository_root)

	over_limit_rejected = False
	try:
		gf_parallel_validation._bounded_windows_long_path_name(
			windows_short_repository_root,
			deadline=None,
			read_long_path=lambda _path_text, _buffer_characters: (
				gf_parallel_validation.WINDOWS_LONG_PATH_MAX_CHARACTERS + 1,
				"",
			),
		)
	except OSError:
		over_limit_rejected = True
	no_progress_rejected = False
	try:
		gf_parallel_validation._bounded_windows_long_path_name(
			windows_short_repository_root,
			deadline=None,
			read_long_path=lambda _path_text, buffer_characters: (buffer_characters, ""),
		)
	except OSError:
		no_progress_rejected = True
	expired_buffer_calls = 0

	def reject_expired_buffer_read(
		_path_text: str,
		_buffer_characters: int,
	) -> tuple[int, str]:
		nonlocal expired_buffer_calls
		expired_buffer_calls += 1
		return 1, "C:"

	expired_buffer_rejected = False
	try:
		gf_parallel_validation._bounded_windows_long_path_name(
			windows_short_repository_root,
			deadline=time.perf_counter() - 1.0,
			read_long_path=reject_expired_buffer_read,
		)
	except WorkspaceDeadlineError:
		expired_buffer_rejected = True
	record_result(
		"windows_long_path_expansion_is_bounded_and_deadline_aware",
		gf_parallel_validation._bounded_windows_long_path_name(
			windows_short_repository_root,
			deadline=None,
			read_long_path=grow_windows_long_path_buffer,
		)
		== Path(str(windows_long_repository_root))
		and buffer_requests == [260, 512]
		and over_limit_rejected
		and no_progress_rejected
		and expired_buffer_rejected
		and expired_buffer_calls == 0,
		"WinAPI long-path expansion must grow monotonically within a hard cap and honor the suite deadline.",
	)

	with tempfile.TemporaryDirectory(prefix="gf-parallel-workspace-self-test-") as temp_dir:
		fixture_root = Path(temp_dir)
		source_root = fixture_root / "source"
		source_root.mkdir()
		for git_args in (
			["init", "--quiet"],
			["config", "user.email", "gf-maintenance@example.invalid"],
			["config", "user.name", "GF Maintenance"],
			["config", "core.autocrlf", "false"],
		):
			subprocess.run(
				["git", *git_args],
				cwd=source_root,
				check=True,
				capture_output=True,
			)
		tracked_path = source_root / "tracked.txt"
		tracked_path.write_text("committed\n", encoding="utf-8")
		subprocess.run(["git", "add", "tracked.txt"], cwd=source_root, check=True, capture_output=True)
		subprocess.run(
			["git", "commit", "--quiet", "-m", "fixture"],
			cwd=source_root,
			check=True,
			capture_output=True,
		)
		staged_added_path = source_root / "staged-added.txt"
		staged_added_path.write_text("staged\n", encoding="utf-8")
		subprocess.run(
			["git", "add", "staged-added.txt"],
			cwd=source_root,
			check=True,
			capture_output=True,
		)
		tracked_path.write_text("dirty\n", encoding="utf-8")
		(source_root / "untracked.bin").write_bytes(b"\x00gf-parallel-fixture\xff")
		captured_fixture = gf_parallel_validation.capture_workspace(source_root)
		workspace_a = gf_parallel_validation.materialize_workspace(
			captured_fixture,
			fixture_root / "workspace-a",
		)
		workspace_b = gf_parallel_validation.materialize_workspace(
			captured_fixture,
			fixture_root / "workspace-b",
		)
		normal_parallel_results = gf_parallel_validation.run_parallel_shards(
			[
				ParallelShard("a", (sys.executable, "-c", "print('a')"), workspace_a, 10),
				ParallelShard("b", (sys.executable, "-c", "print('b')"), workspace_b, 10),
			],
			max_workers=2,
		)
		fail_fast_results = gf_parallel_validation.run_parallel_shards(
			[
				ParallelShard("failure", (sys.executable, "-c", "raise SystemExit(7)"), workspace_a, 10),
				ParallelShard("not-started", (sys.executable, "-c", "print('unexpected')"), workspace_b, 10),
			],
			max_workers=1,
			fail_fast=True,
		)
		original_parallel_run_git = gf_parallel_validation._run_git
		failed_materialization_cleaned = False
		try:
			def fail_materialization_git(*_args: Any, **_kwargs: Any) -> bytes:
				raise WorkspaceSnapshotError("fixture materialization failure")

			gf_parallel_validation._run_git = fail_materialization_git
			failed_target = fixture_root / "failed-workspace"
			try:
				gf_parallel_validation.materialize_workspace(captured_fixture, failed_target)
			except WorkspaceSnapshotError:
				failed_materialization_cleaned = (
					not os.path.lexists(failed_target)
					and not os.path.lexists(fixture_root / ".failed-workspace.m")
				)
		finally:
			gf_parallel_validation._run_git = original_parallel_run_git
		record_result(
			"parallel_validation_materializes_equivalent_isolated_workspaces",
			captured_fixture.workspace_fingerprint == workspace_fingerprint(workspace_a)["fingerprint"]
			and captured_fixture.workspace_fingerprint == workspace_fingerprint(workspace_b)["fingerprint"]
			and (workspace_a / "tracked.txt").read_text(encoding="utf-8") == "dirty\n"
			and (workspace_a / "staged-added.txt").read_text(encoding="utf-8") == "staged\n"
			and (workspace_b / "untracked.bin").read_bytes() == b"\x00gf-parallel-fixture\xff"
			and [result.name for result in normal_parallel_results] == ["a", "b"]
			and all(result.ok for result in normal_parallel_results)
			and failed_materialization_cleaned,
			"Parallel Full workers must receive equivalent private source workspaces and clean failed staging safely.",
		)
		record_result(
			"parallel_validation_fail_fast_cancels_unscheduled_shards",
			fail_fast_results[0].exit_code == 7
			and not fail_fast_results[0].cancelled
			and fail_fast_results[1].exit_code == 130
			and fail_fast_results[1].cancelled
			and not fail_fast_results[1].started,
			"Fail-fast must stop unscheduled shards with a stable structured cancellation result.",
		)
		capture_limit_path = source_root / "capture-limit.bin"
		original_file_capture_limit = gf_parallel_validation.MAX_CAPTURED_UNTRACKED_FILE_BYTES
		original_total_capture_limit = gf_parallel_validation.MAX_CAPTURED_UNTRACKED_TOTAL_BYTES
		exact_limit_accepted = False
		over_limit_rejected = False
		total_limit_exact_accepted = False
		total_limit_rejected = False
		try:
			gf_parallel_validation.MAX_CAPTURED_UNTRACKED_FILE_BYTES = 8
			capture_limit_path.write_bytes(b"12345678")
			exact_limit_accepted = (
				gf_parallel_validation._capture_untracked_file(
					source_root,
					capture_limit_path.name,
				).data
				== b"12345678"
			)
			capture_limit_path.write_bytes(b"123456789")
			try:
				gf_parallel_validation._capture_untracked_file(
					source_root,
					capture_limit_path.name,
				)
			except WorkspaceSnapshotError:
				over_limit_rejected = True
			capture_limit_path.unlink()
			total_source_root = fixture_root / "total-source"
			total_source_root.mkdir()
			for total_git_args in (
				["init", "--quiet"],
				["config", "user.email", "gf-maintenance@example.invalid"],
				["config", "user.name", "GF Maintenance"],
				["config", "core.autocrlf", "false"],
			):
				subprocess.run(
					["git", *total_git_args],
					cwd=total_source_root,
					check=True,
					capture_output=True,
				)
			(total_source_root / "tracked.txt").write_text("fixture\n", encoding="utf-8")
			subprocess.run(
				["git", "add", "tracked.txt"],
				cwd=total_source_root,
				check=True,
				capture_output=True,
			)
			subprocess.run(
				["git", "commit", "--quiet", "-m", "fixture"],
				cwd=total_source_root,
				check=True,
				capture_output=True,
			)
			(total_source_root / "small-a.bin").write_bytes(b"aaaa")
			(total_source_root / "small-b.bin").write_bytes(b"bbbb")
			gf_parallel_validation.MAX_CAPTURED_UNTRACKED_TOTAL_BYTES = 8
			total_limit_exact_accepted = (
				sum(
					captured.size_bytes
					for captured in gf_parallel_validation.capture_workspace(
						total_source_root
					).untracked_files
				)
				== 8
			)
			(total_source_root / "small-c.bin").write_bytes(b"c")
			try:
				gf_parallel_validation.capture_workspace(total_source_root)
			except WorkspaceSnapshotError:
				total_limit_rejected = True
		finally:
			gf_parallel_validation.MAX_CAPTURED_UNTRACKED_FILE_BYTES = original_file_capture_limit
			gf_parallel_validation.MAX_CAPTURED_UNTRACKED_TOTAL_BYTES = original_total_capture_limit
			capture_limit_path.unlink(missing_ok=True)

		open_race_path = source_root / "capture-open-race.bin"
		open_race_replacement = source_root / "capture-open-race-replacement.bin"
		open_race_original = source_root / "capture-open-race-original.bin"
		open_race_path.write_bytes(b"original")
		open_race_replacement.write_bytes(b"replaced")
		original_os_open = gf_parallel_validation.os.open
		open_replacement_rejected = False
		open_was_replaced = False

		def replace_capture_path_before_open(
			path_value: str | bytes | os.PathLike[str] | os.PathLike[bytes],
			flags: int,
			*args: Any,
			**kwargs: Any,
		) -> int:
			nonlocal open_was_replaced
			if Path(path_value) == open_race_path and not open_was_replaced:
				os.replace(open_race_path, open_race_original)
				os.replace(open_race_replacement, open_race_path)
				open_was_replaced = True
			return original_os_open(path_value, flags, *args, **kwargs)

		try:
			gf_parallel_validation.os.open = replace_capture_path_before_open
			try:
				gf_parallel_validation._capture_untracked_file(
					source_root,
					open_race_path.name,
				)
			except WorkspaceSnapshotError:
				open_replacement_rejected = True
		finally:
			gf_parallel_validation.os.open = original_os_open
			for cleanup_path in (open_race_path, open_race_replacement, open_race_original):
				cleanup_path.unlink(missing_ok=True)

		chain_race_path = source_root / "capture-chain-race.bin"
		chain_race_path.write_bytes(b"chain")
		original_chain_snapshot = gf_parallel_validation._snapshot_real_directory_chain
		chain_snapshot_calls = 0
		chain_replacement_rejected = False

		def drift_capture_chain(
			directory: Path,
			*,
			deadline: float | None = None,
		) -> tuple[tuple[Path, os.stat_result], ...]:
			nonlocal chain_snapshot_calls
			chain_snapshot_calls += 1
			snapshot_value = original_chain_snapshot(directory, deadline=deadline)
			return snapshot_value[:-1] if chain_snapshot_calls == 2 else snapshot_value

		try:
			gf_parallel_validation._snapshot_real_directory_chain = drift_capture_chain
			try:
				gf_parallel_validation._capture_untracked_file(
					source_root,
					chain_race_path.name,
				)
			except WorkspaceSnapshotError:
				chain_replacement_rejected = True
		finally:
			gf_parallel_validation._snapshot_real_directory_chain = original_chain_snapshot
			chain_race_path.unlink(missing_ok=True)

		deadline_path = source_root / "capture-deadline.bin"
		deadline_path.write_bytes(b"deadline")
		original_os_read = gf_parallel_validation.os.read
		original_deadline_check = gf_parallel_validation._check_deadline
		read_occurred = False
		read_descriptor = -1
		chunk_deadline_rejected = False
		deadline_descriptor_closed = False

		def mark_capture_read(file_descriptor: int, byte_count: int) -> bytes:
			nonlocal read_occurred
			nonlocal read_descriptor
			chunk = original_os_read(file_descriptor, byte_count)
			read_occurred = True
			read_descriptor = file_descriptor
			return chunk

		def expire_after_capture_read(deadline: float | None, phase: str) -> None:
			if read_occurred and phase == "untracked workspace file reading":
				raise WorkspaceDeadlineError("fixture chunk deadline")
			original_deadline_check(deadline, phase)

		try:
			gf_parallel_validation.os.read = mark_capture_read
			gf_parallel_validation._check_deadline = expire_after_capture_read
			try:
				gf_parallel_validation._capture_untracked_file(
					source_root,
					deadline_path.name,
					deadline=time.perf_counter() + 10.0,
				)
			except WorkspaceDeadlineError:
				chunk_deadline_rejected = True
		finally:
			gf_parallel_validation.os.read = original_os_read
			gf_parallel_validation._check_deadline = original_deadline_check
			deadline_path.unlink(missing_ok=True)
		if read_descriptor >= 0:
			try:
				os.fstat(read_descriptor)
			except OSError:
				deadline_descriptor_closed = True

		linked_capture_target = fixture_root / "capture-link-target"
		linked_capture_target.mkdir()
		(linked_capture_target / "payload.bin").write_bytes(b"linked")
		linked_capture_parent = source_root / "capture-linked-parent"
		create_directory_link_fixture(linked_capture_target, linked_capture_parent)
		linked_parent_rejected = False
		try:
			gf_parallel_validation._capture_untracked_file(
				source_root,
				"capture-linked-parent/payload.bin",
			)
		except WorkspaceSnapshotError:
			linked_parent_rejected = True
		record_result(
			"parallel_untracked_capture_is_bounded_and_identity_pinned",
			exact_limit_accepted
			and over_limit_rejected
			and total_limit_exact_accepted
			and total_limit_rejected
			and open_replacement_rejected
			and chain_replacement_rejected
			and chunk_deadline_rejected
			and deadline_descriptor_closed
			and linked_parent_rejected,
			"Untracked capture must enforce file/total limits, deadlines, stable handles, and real parent chains.",
		)
		report_root = workspace_a / "build" / "p"
		report_root.mkdir(parents=True)
		expected_report_checks = ["diff"]
		expected_report_workspace = captured_fixture.workspace_state()
		expected_package_manifest_sha256 = "5" * 64
		expected_package_artifact_count = 7
		valid_report = {
			"ok": True,
			"suite": "quick",
			"checks": expected_report_checks,
			"completed_check_count": 1,
			"duration_seconds": 0.01,
			"suite_timeout_seconds": None,
			"check_graph": maintenance_check_graph().describe(expected_report_checks),
			"workspace_fingerprint": captured_fixture.workspace_fingerprint,
			"workspace_snapshot": {
				"text_entry_count": 0,
				"text_cache_hits": 0,
				"text_cache_misses": 0,
				"value_entry_count": 0,
				"value_cache_hits": 0,
				"value_cache_misses": 0,
			},
			"workspace": expected_report_workspace,
			"execution": "serial",
			"jobs": 1,
			"results": [{
				"name": "diff",
				"command": ["git", "diff", "--check"],
				"cwd": str(workspace_a),
				"exit_code": 0,
				"timed_out": False,
				"cancelled": False,
				"duration_seconds": 0.01,
				"execution": "subprocess",
				"stdout": "",
				"stderr": "",
				"stdout_char_count": 0,
				"stdout_utf8_byte_count": 0,
				"stdout_sha256": hashlib.sha256(b"").hexdigest(),
				"stdout_truncated": False,
				"stderr_char_count": 0,
				"stderr_utf8_byte_count": 0,
				"stderr_sha256": hashlib.sha256(b"").hexdigest(),
				"stderr_truncated": False,
				"timeout_seconds": 600.0,
				"dependencies": [],
				"dependency_fingerprints": {},
				"input_fingerprint": "3" * 64,
				"result_fingerprint": "4" * 64,
				"timeout_budget": {
					"policy_seconds": 600.0,
					"requested_minimum_seconds": None,
					"suite_remaining_seconds": None,
					"effective_seconds": 600.0,
				},
			}],
		}
		passing_report_runner = ParallelShardResult(
			name="report-fixture",
			command=(sys.executable, "fixture.py"),
			workspace=workspace_a,
			exit_code=0,
			process_exit_code=0,
			stdout="",
			stderr="",
			timed_out=False,
			cancelled=False,
			duration_seconds=0.01,
			pid=123,
			started=True,
		)

		def write_report_fixture(name: str, payload: dict[str, Any]) -> Path:
			path = report_root / f"{name}.json"
			path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8", newline="\n")
			return path

		def load_report_fixture(
			shard_result: ParallelShardResult,
			report_path: Path,
			expected_checks: list[str],
			expected_workspace_state: dict[str, object],
			**kwargs: Any,
		) -> tuple[dict[str, Any] | None, str]:
			return load_parallel_shard_report(
				shard_result,
				report_path,
				expected_checks,
				expected_workspace_state,
				expected_check_graph=maintenance_check_graph().describe(
					expected_checks
				),
				**kwargs,
			)

		valid_report_path = write_report_fixture("valid", valid_report)
		valid_loaded, valid_issue = load_report_fixture(
			passing_report_runner,
			valid_report_path,
			expected_report_checks,
			expected_report_workspace,
			expected_package_artifact_manifest_sha256=expected_package_manifest_sha256,
			expected_package_artifact_count=expected_package_artifact_count,
		)
		assigned_graph = dict(valid_report["check_graph"])
		assigned_graph["fingerprint"] = "9" * 64
		_, assigned_graph_issue = load_parallel_shard_report(
			passing_report_runner,
			valid_report_path,
			expected_report_checks,
			expected_report_workspace,
			expected_check_graph=assigned_graph,
		)
		missing_report = json.loads(json.dumps(valid_report))
		missing_report["results"] = []
		missing_report["completed_check_count"] = 0
		_, missing_issue = load_report_fixture(
			passing_report_runner,
			write_report_fixture("missing", missing_report),
			expected_report_checks,
			expected_report_workspace,
		)
		invalid_exit_report = json.loads(json.dumps(valid_report))
		invalid_exit_report["results"][0]["exit_code"] = None
		_, invalid_exit_issue = load_report_fixture(
			passing_report_runner,
			write_report_fixture("invalid-exit", invalid_exit_report),
			expected_report_checks,
			expected_report_workspace,
		)
		non_finite_report_path = report_root / "non-finite.json"
		non_finite_report_path.write_text(
			json.dumps(valid_report, ensure_ascii=False).replace('"duration_seconds": 0.01', '"duration_seconds": NaN', 1),
			encoding="utf-8",
			newline="\n",
		)
		_, non_finite_issue = load_report_fixture(
			passing_report_runner,
			non_finite_report_path,
			expected_report_checks,
			expected_report_workspace,
		)
		duplicate_key_report_path = report_root / "duplicate-key.json"
		duplicate_key_report_path.write_text(
			json.dumps(valid_report, ensure_ascii=False).replace(
				'{"ok": true,',
				'{"ok": true, "ok": true,',
				1,
			),
			encoding="utf-8",
			newline="\n",
		)
		_, duplicate_key_issue = load_report_fixture(
			passing_report_runner,
			duplicate_key_report_path,
			expected_report_checks,
			expected_report_workspace,
		)
		oversized_report_path = report_root / "oversized.json"
		oversized_report_path.write_bytes(b"{}" + b" " * MAX_PARALLEL_SHARD_REPORT_BYTES)
		_, oversized_issue = load_report_fixture(
			passing_report_runner,
			oversized_report_path,
			expected_report_checks,
			expected_report_workspace,
		)
		extra_field_report = json.loads(json.dumps(valid_report))
		extra_field_report["unexpected"] = True
		_, extra_field_issue = load_report_fixture(
			passing_report_runner,
			write_report_fixture("extra-field", extra_field_report),
			expected_report_checks,
			expected_report_workspace,
		)
		external_cwd_report = json.loads(json.dumps(valid_report))
		external_cwd_report["results"][0]["cwd"] = str(fixture_root)
		_, external_cwd_issue = load_report_fixture(
			passing_report_runner,
			write_report_fixture("external-cwd", external_cwd_report),
			expected_report_checks,
			expected_report_workspace,
		)
		invalid_output_report = json.loads(json.dumps(valid_report))
		invalid_output_report["results"][0]["stdout"] = []
		_, invalid_output_issue = load_report_fixture(
			passing_report_runner,
			write_report_fixture("invalid-output", invalid_output_report),
			expected_report_checks,
			expected_report_workspace,
		)
		partial_output_evidence_report = json.loads(json.dumps(valid_report))
		del partial_output_evidence_report["results"][0]["stderr_sha256"]
		_, partial_output_evidence_issue = load_report_fixture(
			passing_report_runner,
			write_report_fixture(
				"partial-output-evidence",
				partial_output_evidence_report,
			),
			expected_report_checks,
			expected_report_workspace,
		)
		inconsistent_output_evidence_report = json.loads(json.dumps(valid_report))
		inconsistent_output_evidence_report["results"][0]["stdout_char_count"] = 1
		_, inconsistent_output_evidence_issue = load_report_fixture(
			passing_report_runner,
			write_report_fixture(
				"inconsistent-output-evidence",
				inconsistent_output_evidence_report,
			),
			expected_report_checks,
			expected_report_workspace,
		)
		clean_lifecycle_marker = {
			"schema_version": GUT_LIFECYCLE_GATE_SCHEMA_VERSION,
			"ok": True,
			"baseline_available": True,
			"warning_tracking_available": True,
			"unhandled_warning_count": 0,
			"orphan_count": 0,
			"warnings": [],
			"orphans": [],
			"details_truncated": False,
			"configuration_error": "",
		}
		clean_lifecycle_report = parse_gut_lifecycle_gate_output(
			GUT_LIFECYCLE_GATE_PREFIX
			+ json.dumps(
				clean_lifecycle_marker,
				ensure_ascii=False,
				separators=(",", ":"),
			),
			"",
		)
		gut_report_checks = ["gut"]
		gut_report = json.loads(json.dumps(valid_report))
		gut_report["checks"] = gut_report_checks
		gut_report["check_graph"] = maintenance_check_graph().describe(
			gut_report_checks
		)
		gut_report["results"][0]["name"] = "gut"
		gut_report["results"][0]["command"] = [
			"godot",
			"--headless",
			"-s",
			GUT_LIFECYCLE_CLI_RESOURCE_PATH,
		]
		gut_report["results"][0]["gut_lifecycle_report"] = (
			clean_lifecycle_report
		)
		gut_loaded, gut_issue = load_report_fixture(
			passing_report_runner,
			write_report_fixture("gut-valid", gut_report),
			gut_report_checks,
			expected_report_workspace,
		)
		non_gut_lifecycle_report = json.loads(json.dumps(valid_report))
		non_gut_lifecycle_report["results"][0]["gut_lifecycle_report"] = (
			clean_lifecycle_report
		)
		_, non_gut_lifecycle_issue = load_report_fixture(
			passing_report_runner,
			write_report_fixture(
				"non-gut-lifecycle",
				non_gut_lifecycle_report,
			),
			expected_report_checks,
			expected_report_workspace,
		)
		missing_gut_lifecycle_report = json.loads(json.dumps(gut_report))
		del missing_gut_lifecycle_report["results"][0]["gut_lifecycle_report"]
		_, missing_gut_lifecycle_issue = load_report_fixture(
			passing_report_runner,
			write_report_fixture(
				"gut-missing-lifecycle",
				missing_gut_lifecycle_report,
			),
			gut_report_checks,
			expected_report_workspace,
		)
		failed_gut_lifecycle_report = json.loads(json.dumps(gut_report))
		failed_gut_lifecycle_report["results"][0]["gut_lifecycle_report"] = (
			parse_gut_lifecycle_gate_output("", "")
		)
		_, failed_gut_lifecycle_issue = load_report_fixture(
			passing_report_runner,
			write_report_fixture(
				"gut-failed-lifecycle",
				failed_gut_lifecycle_report,
			),
			gut_report_checks,
			expected_report_workspace,
		)
		impossible_gut_lifecycle_report = json.loads(json.dumps(gut_report))
		impossible_gut_lifecycle_report["results"][0][
			"gut_lifecycle_report"
		]["marker_count"] = GUT_LIFECYCLE_GATE_MAX_MIRRORED_MARKERS + 1
		_, impossible_gut_lifecycle_issue = load_report_fixture(
			passing_report_runner,
			write_report_fixture(
				"gut-impossible-lifecycle",
				impossible_gut_lifecycle_report,
			),
			gut_report_checks,
			expected_report_workspace,
		)
		failing_report_runner = ParallelShardResult(
			**{
				**passing_report_runner.__dict__,
				"exit_code": 1,
				"process_exit_code": 1,
			}
		)
		timed_out_gut_report = json.loads(json.dumps(gut_report))
		timed_out_gut_report["ok"] = False
		timed_out_gut_result = timed_out_gut_report["results"][0]
		timed_out_gut_result["exit_code"] = 124
		timed_out_gut_result["timed_out"] = True
		timed_out_gut_result["process_exit_code"] = -1
		timed_out_gut_result["gut_lifecycle_report"] = (
			parse_gut_lifecycle_gate_output("partial output", "")
		)
		timed_out_gut_loaded, timed_out_gut_issue = load_report_fixture(
			failing_report_runner,
			write_report_fixture(
				"gut-timeout-with-lifecycle",
				timed_out_gut_report,
			),
			gut_report_checks,
			expected_report_workspace,
		)
		cancelled_gut_report = json.loads(json.dumps(timed_out_gut_report))
		cancelled_gut_result = cancelled_gut_report["results"][0]
		cancelled_gut_result["exit_code"] = 130
		cancelled_gut_result["timed_out"] = False
		cancelled_gut_result["cancelled"] = True
		cancelled_gut_loaded, cancelled_gut_issue = load_report_fixture(
			failing_report_runner,
			write_report_fixture(
				"gut-cancelled-with-lifecycle",
				cancelled_gut_report,
			),
			gut_report_checks,
			expected_report_workspace,
		)
		plain_124_gut_report = json.loads(json.dumps(timed_out_gut_report))
		plain_124_gut_report["results"][0]["timed_out"] = False
		plain_124_gut_loaded, plain_124_gut_issue = load_report_fixture(
			failing_report_runner,
			write_report_fixture(
				"gut-plain-124-with-lifecycle",
				plain_124_gut_report,
			),
			gut_report_checks,
			expected_report_workspace,
		)
		forged_timeout_exit_report = json.loads(json.dumps(timed_out_gut_report))
		forged_timeout_exit_report["results"][0]["exit_code"] = 1
		_, forged_timeout_exit_issue = load_report_fixture(
			failing_report_runner,
			write_report_fixture(
				"gut-timeout-wrong-exit",
				forged_timeout_exit_report,
			),
			gut_report_checks,
			expected_report_workspace,
		)
		forged_cancel_exit_report = json.loads(json.dumps(timed_out_gut_report))
		forged_cancel_result = forged_cancel_exit_report["results"][0]
		forged_cancel_result["timed_out"] = False
		forged_cancel_result["cancelled"] = True
		_, forged_cancel_exit_issue = load_report_fixture(
			failing_report_runner,
			write_report_fixture(
				"gut-cancel-wrong-exit",
				forged_cancel_exit_report,
			),
			gut_report_checks,
			expected_report_workspace,
		)
		forged_conflicting_terminal_report = json.loads(json.dumps(
			timed_out_gut_report
		))
		forged_conflicting_terminal_report["results"][0]["cancelled"] = True
		_, forged_conflicting_terminal_issue = load_report_fixture(
			failing_report_runner,
			write_report_fixture(
				"gut-conflicting-terminal-state",
				forged_conflicting_terminal_report,
			),
			gut_report_checks,
			expected_report_workspace,
		)
		_, mismatch_issue = load_report_fixture(
			failing_report_runner,
			valid_report_path,
			expected_report_checks,
			expected_report_workspace,
		)
		record_result(
			"parallel_shard_reports_are_strict_and_fail_closed",
			valid_loaded is not None
			and not valid_issue
			and bool(assigned_graph_issue)
			and bool(missing_issue)
			and bool(invalid_exit_issue)
			and bool(non_finite_issue)
			and bool(duplicate_key_issue)
			and bool(oversized_issue)
			and bool(extra_field_issue)
			and bool(external_cwd_issue)
			and bool(invalid_output_issue)
			and bool(partial_output_evidence_issue)
			and bool(inconsistent_output_evidence_issue)
			and gut_loaded is not None
			and not gut_issue
			and bool(non_gut_lifecycle_issue)
			and bool(missing_gut_lifecycle_issue)
			and bool(failed_gut_lifecycle_issue)
			and timed_out_gut_loaded is not None
			and not timed_out_gut_issue
			and cancelled_gut_loaded is not None
			and not cancelled_gut_issue
			and plain_124_gut_loaded is not None
			and not plain_124_gut_issue
			and bool(forged_timeout_exit_issue)
			and bool(forged_cancel_exit_issue)
			and bool(forged_conflicting_terminal_issue)
			and bool(impossible_gut_lifecycle_issue)
			and bool(mismatch_issue),
			"Parallel reports must retain closed failed GUT lifecycle evidence for timeouts while rejecting missing or oversized results, invalid scalars, opaque or inconsistent output evidence, duplicate/non-finite JSON, schema drift, inconsistent timeout/cancellation states, successful checks with failed lifecycle evidence, impossible lifecycle evidence, workspace escapes, and process/report disagreement.",
		)
		package_report_checks = ["package_build_boundary"]
		package_report = json.loads(json.dumps(valid_report))
		package_report["checks"] = package_report_checks
		package_report["check_graph"] = maintenance_check_graph().describe(package_report_checks)
		package_report["results"][0]["name"] = "package_build_boundary"
		package_report["results"][0]["command"] = [
			sys.executable,
			"tools/gf_maintenance.py",
			"package-build-boundary",
		]
		package_report["package_artifact_set"] = {
			"reused": True,
			"manifest_sha256": expected_package_manifest_sha256,
			"artifact_count": expected_package_artifact_count,
			"workspace_fingerprint": captured_fixture.workspace_fingerprint,
		}
		package_loaded, package_issue = load_report_fixture(
			passing_report_runner,
			write_report_fixture("package-valid", package_report),
			package_report_checks,
			expected_report_workspace,
			expected_package_artifact_manifest_sha256=expected_package_manifest_sha256,
			expected_package_artifact_count=expected_package_artifact_count,
		)
		mutated_package_sha_report = json.loads(json.dumps(package_report))
		mutated_package_sha_report["package_artifact_set"]["manifest_sha256"] = "6" * 64
		_, mutated_package_sha_issue = load_report_fixture(
			passing_report_runner,
			write_report_fixture("package-mutated-sha", mutated_package_sha_report),
			package_report_checks,
			expected_report_workspace,
			expected_package_artifact_manifest_sha256=expected_package_manifest_sha256,
			expected_package_artifact_count=expected_package_artifact_count,
		)
		mutated_package_count_report = json.loads(json.dumps(package_report))
		mutated_package_count_report["package_artifact_set"]["artifact_count"] += 1
		_, mutated_package_count_issue = load_report_fixture(
			passing_report_runner,
			write_report_fixture("package-mutated-count", mutated_package_count_report),
			package_report_checks,
			expected_report_workspace,
			expected_package_artifact_manifest_sha256=expected_package_manifest_sha256,
			expected_package_artifact_count=expected_package_artifact_count,
		)
		non_package_artifact_report = json.loads(json.dumps(valid_report))
		non_package_artifact_report["package_artifact_set"] = package_report["package_artifact_set"]
		_, non_package_artifact_issue = load_report_fixture(
			passing_report_runner,
			write_report_fixture("non-package-artifact", non_package_artifact_report),
			expected_report_checks,
			expected_report_workspace,
			expected_package_artifact_manifest_sha256=expected_package_manifest_sha256,
			expected_package_artifact_count=expected_package_artifact_count,
		)
		record_result(
			"parallel_package_shard_reports_bind_exact_artifact_identity",
			package_loaded is not None
			and not package_issue
			and bool(mutated_package_sha_issue)
			and bool(mutated_package_count_issue)
			and bool(non_package_artifact_issue),
			"Package shard reports must match the parent sealed set exactly without widening non-package reports.",
		)

	with tempfile.TemporaryDirectory(prefix="gf-workspace-fingerprint-self-test-") as temp_dir:
		fingerprint_fixture_root = Path(temp_dir)

		def initialize_fingerprint_repository(repository_root: Path) -> None:
			repository_root.mkdir(parents=True, exist_ok=True)
			for git_args in (
				["init", "--quiet"],
				["config", "user.email", "gf-maintenance@example.invalid"],
				["config", "user.name", "GF Maintenance"],
				["config", "core.autocrlf", "false"],
			):
				subprocess.run(
					["git", *git_args],
					cwd=repository_root,
					check=True,
					capture_output=True,
				)
			(repository_root / "tracked.txt").write_text("fixture\n", encoding="utf-8")
			subprocess.run(
				["git", "add", "tracked.txt"],
				cwd=repository_root,
				check=True,
				capture_output=True,
			)
			subprocess.run(
				["git", "commit", "--quiet", "-m", "fixture"],
				cwd=repository_root,
				check=True,
				capture_output=True,
			)

		fingerprint_root = fingerprint_fixture_root / "chunked"
		initialize_fingerprint_repository(fingerprint_root)
		fingerprint_path = fingerprint_root / "multi-chunk.bin"
		fingerprint_path.write_bytes(b"0123456789-tail")
		fingerprint_path_stat = fingerprint_path.lstat()
		original_fingerprint_chunk_bytes = gf_maintenance_check_graph.WORKSPACE_FINGERPRINT_CHUNK_BYTES
		original_fingerprint_os_read = gf_maintenance_check_graph.os.read
		chunked_read_lengths: list[int] = []
		chunked_requested_sizes: list[int] = []

		def track_chunked_fingerprint_read(file_descriptor: int, size: int) -> bytes:
			chunk = original_fingerprint_os_read(file_descriptor, size)
			try:
				is_target = os.path.samestat(fingerprint_path_stat, os.fstat(file_descriptor))
			except OSError:
				is_target = False
			if is_target:
				chunked_requested_sizes.append(size)
				if chunk:
					chunked_read_lengths.append(len(chunk))
			return chunk

		try:
			gf_maintenance_check_graph.WORKSPACE_FINGERPRINT_CHUNK_BYTES = 4
			gf_maintenance_check_graph.os.read = track_chunked_fingerprint_read
			chunked_fingerprint = workspace_fingerprint(fingerprint_root)["fingerprint"]
		finally:
			gf_maintenance_check_graph.os.read = original_fingerprint_os_read
			gf_maintenance_check_graph.WORKSPACE_FINGERPRINT_CHUNK_BYTES = original_fingerprint_chunk_bytes
		captured_fingerprint = gf_parallel_validation.capture_workspace(
			fingerprint_root
		).workspace_fingerprint
		record_result(
			"workspace_fingerprint_chunking_preserves_v1_digest",
			chunked_fingerprint == captured_fingerprint
			and chunked_read_lengths == [4, 4, 4, 3]
			and bool(chunked_requested_sizes)
			and max(chunked_requested_sizes) <= 4,
			"Chunked workspace hashing, including a tail chunk, must preserve the captured workspace v1 digest.",
		)

		deadline_before = fingerprint_path.lstat()
		deadline_read_count = 0
		deadline_digest_updates: list[bytes] = []
		deadline_rejected_between_chunks = False

		class TrackingFingerprintDigest:
			def copy(self) -> TrackingFingerprintDigest:
				return self

			def update(self, payload: bytes) -> None:
				deadline_digest_updates.append(bytes(payload))

		def delay_first_fingerprint_read(file_descriptor: int, size: int) -> bytes:
			nonlocal deadline_read_count
			chunk = original_fingerprint_os_read(file_descriptor, size)
			try:
				is_target = os.path.samestat(deadline_before, os.fstat(file_descriptor))
			except OSError:
				is_target = False
			if is_target and chunk:
				deadline_read_count += 1
				if deadline_read_count == 1:
					time.sleep(0.3)
			return chunk

		try:
			gf_maintenance_check_graph.WORKSPACE_FINGERPRINT_CHUNK_BYTES = 4
			gf_maintenance_check_graph.os.read = delay_first_fingerprint_read
			try:
				gf_maintenance_check_graph._update_digest_from_stable_regular_file(
					TrackingFingerprintDigest(),
					fingerprint_path,
					deadline_before,
					deadline=time.perf_counter() + 0.2,
				)
			except TimeoutError:
				deadline_rejected_between_chunks = True
		finally:
			gf_maintenance_check_graph.os.read = original_fingerprint_os_read
			gf_maintenance_check_graph.WORKSPACE_FINGERPRINT_CHUNK_BYTES = original_fingerprint_chunk_bytes
		record_result(
			"workspace_fingerprint_checks_deadline_after_each_chunk",
			deadline_rejected_between_chunks
			and deadline_read_count == 1
			and not deadline_digest_updates,
			"Workspace fingerprinting must enforce its absolute deadline immediately after every file chunk.",
		)

		open_race_path = fingerprint_root / "fingerprint-open-race.bin"
		open_race_replacement = fingerprint_root / "fingerprint-open-race-replacement.bin"
		open_race_original = fingerprint_root / "fingerprint-open-race-original.bin"
		open_race_path.write_bytes(b"original")
		open_race_replacement.write_bytes(b"replaced")
		open_race_before = open_race_path.lstat()
		original_fingerprint_os_open = gf_maintenance_check_graph.os.open
		open_race_rejected = False
		open_race_swapped = False

		def replace_fingerprint_path_before_open(
			path_value: str | bytes | os.PathLike[str] | os.PathLike[bytes],
			flags: int,
			*args: Any,
			**kwargs: Any,
		) -> int:
			nonlocal open_race_swapped
			if Path(path_value) == open_race_path and not open_race_swapped:
				os.replace(open_race_path, open_race_original)
				os.replace(open_race_replacement, open_race_path)
				open_race_swapped = True
			return original_fingerprint_os_open(path_value, flags, *args, **kwargs)

		try:
			gf_maintenance_check_graph.os.open = replace_fingerprint_path_before_open
			try:
				gf_maintenance_check_graph._update_digest_from_stable_regular_file(
					hashlib.sha256(),
					open_race_path,
					open_race_before,
					deadline=None,
				)
			except gf_maintenance_check_graph.WorkspaceFingerprintDriftError:
				open_race_rejected = True
		finally:
			gf_maintenance_check_graph.os.open = original_fingerprint_os_open

		read_race_path = fingerprint_root / "fingerprint-read-race.bin"
		read_race_replacement = fingerprint_root / "fingerprint-read-race-replacement.bin"
		read_race_original = fingerprint_root / "fingerprint-read-race-original.bin"
		read_race_path.write_bytes(b"read-original")
		read_race_replacement.write_bytes(b"read-replaced")
		read_race_before = read_race_path.lstat()
		read_race_rejected = False
		read_race_attempted = False
		read_race_swapped = False

		def replace_fingerprint_path_during_read(file_descriptor: int, size: int) -> bytes:
			nonlocal read_race_attempted
			nonlocal read_race_swapped
			chunk = original_fingerprint_os_read(file_descriptor, size)
			try:
				is_target = os.path.samestat(read_race_before, os.fstat(file_descriptor))
			except OSError:
				is_target = False
			if is_target and chunk and not read_race_swapped:
				read_race_attempted = True
				os.replace(read_race_path, read_race_original)
				os.replace(read_race_replacement, read_race_path)
				read_race_swapped = True
			return chunk

		try:
			gf_maintenance_check_graph.WORKSPACE_FINGERPRINT_CHUNK_BYTES = 4
			gf_maintenance_check_graph.os.read = replace_fingerprint_path_during_read
			try:
				gf_maintenance_check_graph._update_digest_from_stable_regular_file(
					hashlib.sha256(),
					read_race_path,
					read_race_before,
					deadline=None,
				)
			except gf_maintenance_check_graph.WorkspaceFingerprintError:
				read_race_rejected = True
		finally:
			gf_maintenance_check_graph.os.read = original_fingerprint_os_read
			gf_maintenance_check_graph.WORKSPACE_FINGERPRINT_CHUNK_BYTES = original_fingerprint_chunk_bytes
		record_result(
			"workspace_fingerprint_rejects_open_and_read_path_replacement",
			open_race_swapped
			and open_race_rejected
			and read_race_attempted
			and read_race_rejected,
			"Stable fingerprint handles must reject path replacement both before open and during chunked reads.",
		)

		pre_lstat_path = fingerprint_root / "fingerprint-pre-lstat.bin"
		pre_lstat_path.write_bytes(b"pre-lstat")
		original_fingerprint_path_lstat = Path.lstat
		pre_lstat_attempted = False
		pre_lstat_rejected = False

		def reject_fingerprint_pre_lstat(
			path_value: Path,
			*args: Any,
			**kwargs: Any,
		) -> os.stat_result:
			nonlocal pre_lstat_attempted
			if path_value == pre_lstat_path:
				pre_lstat_attempted = True
				raise FileNotFoundError("fixture pre-lstat drift")
			return original_fingerprint_path_lstat(path_value, *args, **kwargs)

		try:
			Path.lstat = reject_fingerprint_pre_lstat
			try:
				workspace_fingerprint(fingerprint_root)
			except gf_maintenance_check_graph.WorkspaceFingerprintDriftError:
				pre_lstat_rejected = True
		finally:
			Path.lstat = original_fingerprint_path_lstat
		record_result(
			"workspace_fingerprint_fails_closed_before_lstat",
			pre_lstat_attempted and pre_lstat_rejected,
			"Git-enumerated untracked entries that disappear before lstat must abort provenance.",
		)

		readlink_path = fingerprint_root / "fingerprint-readlink.bin"
		readlink_path.write_bytes(b"readlink")
		readlink_path_stat = readlink_path.lstat()
		original_fingerprint_os_readlink = gf_maintenance_check_graph.os.readlink
		readlink_attempted = False
		readlink_rejected = False

		def present_fingerprint_path_as_symlink(
			path_value: str | bytes | os.PathLike[str] | os.PathLike[bytes],
			*args: Any,
			**kwargs: Any,
		) -> Any:
			if Path(path_value) == readlink_path:
				return argparse.Namespace(
					st_mode=stat.S_IFLNK | 0o777,
					st_size=len(b"readlink"),
					st_dev=readlink_path_stat.st_dev,
					st_ino=readlink_path_stat.st_ino,
					st_mtime_ns=readlink_path_stat.st_mtime_ns,
					st_ctime_ns=readlink_path_stat.st_ctime_ns,
					st_file_attributes=0,
				)
			return original_fingerprint_path_lstat(path_value, *args, **kwargs)

		def reject_fingerprint_readlink(
			path_value: str | bytes | os.PathLike[str] | os.PathLike[bytes],
			*args: Any,
			**kwargs: Any,
		) -> str | bytes:
			nonlocal readlink_attempted
			if Path(path_value) == readlink_path:
				readlink_attempted = True
				raise PermissionError("fixture readlink drift")
			return original_fingerprint_os_readlink(path_value, *args, **kwargs)

		try:
			Path.lstat = present_fingerprint_path_as_symlink
			gf_maintenance_check_graph.os.readlink = reject_fingerprint_readlink
			try:
				workspace_fingerprint(fingerprint_root)
			except gf_maintenance_check_graph.WorkspaceFingerprintDriftError:
				readlink_rejected = True
		finally:
			gf_maintenance_check_graph.os.readlink = original_fingerprint_os_readlink
			Path.lstat = original_fingerprint_path_lstat
		record_result(
			"workspace_fingerprint_fails_closed_during_readlink",
			readlink_attempted and readlink_rejected,
			"Git-enumerated untracked symlinks that fail during readlink must abort provenance.",
		)

		symlink_race_path = fingerprint_root / "fingerprint-symlink-race.bin"
		symlink_race_path.write_bytes(b"symlink-race")
		symlink_race_stat = symlink_race_path.lstat()
		symlink_race_before = argparse.Namespace(
			st_mode=stat.S_IFLNK | 0o777,
			st_size=len("target-one"),
			st_dev=symlink_race_stat.st_dev,
			st_ino=symlink_race_stat.st_ino,
			st_mtime_ns=symlink_race_stat.st_mtime_ns,
			st_ctime_ns=symlink_race_stat.st_ctime_ns,
			st_file_attributes=0,
		)
		symlink_race_after = argparse.Namespace(
			st_mode=stat.S_IFLNK | 0o777,
			st_size=len("target-two"),
			st_dev=symlink_race_stat.st_dev,
			st_ino=symlink_race_stat.st_ino + 1,
			st_mtime_ns=symlink_race_stat.st_mtime_ns + 1,
			st_ctime_ns=symlink_race_stat.st_ctime_ns + 1,
			st_file_attributes=0,
		)
		symlink_lstat_count = 0
		symlink_race_rejected = False

		def replace_symlink_during_readlink(
			path_value: Path,
			*args: Any,
			**kwargs: Any,
		) -> os.stat_result:
			nonlocal symlink_lstat_count
			if path_value == symlink_race_path:
				symlink_lstat_count += 1
				return symlink_race_before if symlink_lstat_count == 1 else symlink_race_after
			return original_fingerprint_path_lstat(path_value, *args, **kwargs)

		def read_replaced_symlink_target(
			path_value: str | bytes | os.PathLike[str] | os.PathLike[bytes],
			*args: Any,
			**kwargs: Any,
		) -> str | bytes:
			if Path(path_value) == symlink_race_path:
				return "target-two"
			return original_fingerprint_os_readlink(path_value, *args, **kwargs)

		try:
			Path.lstat = replace_symlink_during_readlink
			gf_maintenance_check_graph.os.readlink = read_replaced_symlink_target
			try:
				workspace_fingerprint(fingerprint_root)
			except gf_maintenance_check_graph.WorkspaceFingerprintDriftError:
				symlink_race_rejected = True
		finally:
			gf_maintenance_check_graph.os.readlink = original_fingerprint_os_readlink
			Path.lstat = original_fingerprint_path_lstat
		record_result(
			"workspace_fingerprint_rejects_symlink_replacement_during_readlink",
			symlink_lstat_count >= 2 and symlink_race_rejected,
			"Workspace symlink fingerprints must bind lstat metadata and readlink output to the same object.",
		)

		identity_path = fingerprint_root / "fingerprint-identity.bin"
		identity_path.write_bytes(b"identity")
		identity_stat = identity_path.lstat()
		unknown_identity = argparse.Namespace(
			st_mode=identity_stat.st_mode,
			st_size=identity_stat.st_size,
			st_ino=0,
			st_dev=identity_stat.st_dev,
			st_mtime_ns=identity_stat.st_mtime_ns,
		)
		regular_reparse = argparse.Namespace(
			st_mode=identity_stat.st_mode,
			st_size=identity_stat.st_size,
			st_ino=identity_stat.st_ino,
			st_file_attributes=gf_maintenance_check_graph.FILE_ATTRIBUTE_REPARSE_POINT,
		)
		unknown_identity_rejected = False
		regular_reparse_rejected = False
		try:
			gf_maintenance_check_graph._update_digest_from_stable_regular_file(
				hashlib.sha256(),
				identity_path,
				unknown_identity,
				deadline=None,
			)
		except gf_maintenance_check_graph.WorkspaceFingerprintSetupError:
			unknown_identity_rejected = True
		try:
			gf_maintenance_check_graph._update_digest_from_stable_regular_file(
				hashlib.sha256(),
				identity_path,
				regular_reparse,
				deadline=None,
			)
		except gf_maintenance_check_graph.WorkspaceFingerprintSetupError:
			regular_reparse_rejected = True
		record_result(
			"workspace_fingerprint_rejects_unknown_identity_and_regular_reparse",
			unknown_identity_rejected
			and regular_reparse_rejected
			and gf_maintenance_check_graph._stat_is_regular_reparse(regular_reparse),
			"Workspace fingerprints must fail closed for unverifiable identities and regular-file reparse points.",
		)

		limit_root = fingerprint_fixture_root / "limits"
		initialize_fingerprint_repository(limit_root)
		original_fingerprint_file_limit = (
			gf_maintenance_check_graph.MAX_WORKSPACE_FINGERPRINT_UNTRACKED_FILE_BYTES
		)
		original_fingerprint_total_limit = (
			gf_maintenance_check_graph.MAX_WORKSPACE_FINGERPRINT_UNTRACKED_TOTAL_BYTES
		)
		file_limit_rejected = False
		total_limit_exact_accepted = False
		total_limit_rejected = False
		try:
			gf_maintenance_check_graph.MAX_WORKSPACE_FINGERPRINT_UNTRACKED_FILE_BYTES = 8
			gf_maintenance_check_graph.MAX_WORKSPACE_FINGERPRINT_UNTRACKED_TOTAL_BYTES = 12
			oversized_path = limit_root / "oversized.bin"
			oversized_path.write_bytes(b"123456789")
			try:
				workspace_fingerprint(limit_root)
			except gf_maintenance_check_graph.WorkspaceFingerprintSetupError:
				file_limit_rejected = True
			oversized_path.unlink()
			(limit_root / "a.bin").write_bytes(b"aaaaaa")
			(limit_root / "b.bin").write_bytes(b"bbbbbb")
			total_limit_exact_accepted = workspace_fingerprint(limit_root)["untracked_file_count"] == 2
			(limit_root / "c.bin").write_bytes(b"c")
			try:
				workspace_fingerprint(limit_root)
			except gf_maintenance_check_graph.WorkspaceFingerprintSetupError:
				total_limit_rejected = True
		finally:
			gf_maintenance_check_graph.MAX_WORKSPACE_FINGERPRINT_UNTRACKED_FILE_BYTES = (
				original_fingerprint_file_limit
			)
			gf_maintenance_check_graph.MAX_WORKSPACE_FINGERPRINT_UNTRACKED_TOTAL_BYTES = (
				original_fingerprint_total_limit
			)
		record_result(
			"workspace_fingerprint_enforces_capture_aligned_size_limits",
			file_limit_rejected
			and total_limit_exact_accepted
			and total_limit_rejected
			and original_fingerprint_file_limit
			== gf_parallel_validation.MAX_CAPTURED_UNTRACKED_FILE_BYTES
			and original_fingerprint_total_limit
			== gf_parallel_validation.MAX_CAPTURED_UNTRACKED_TOTAL_BYTES,
			"Workspace fingerprinting must enforce the same per-file and aggregate untracked limits as capture.",
		)

		original_workspace_fingerprint_runner = globals()["workspace_fingerprint"]
		structured_fingerprint_failure: dict[str, Any] | None = None
		structured_fingerprint_error = ""

		def fail_workspace_fingerprint_setup(
			_root: Path,
			*,
			deadline: float | None = None,
		) -> dict[str, Any]:
			del deadline
			raise gf_maintenance_check_graph.WorkspaceFingerprintSetupError(
				"fixture fingerprint setup failure"
			)

		try:
			globals()["workspace_fingerprint"] = fail_workspace_fingerprint_setup
			try:
				structured_fingerprint_failure = run_checks(
					suite="quick",
					checks=["api"],
					jobs=1,
				)
			except BaseException as error:
				structured_fingerprint_error = f"{type(error).__name__}: {error}"
		finally:
			globals()["workspace_fingerprint"] = original_workspace_fingerprint_runner
		structured_results = (
			structured_fingerprint_failure.get("results", [])
			if isinstance(structured_fingerprint_failure, dict)
			else []
		)
		record_result(
			"workspace_fingerprint_setup_errors_are_structured",
			not structured_fingerprint_error
			and structured_fingerprint_failure is not None
			and not structured_fingerprint_failure.get("ok", True)
			and structured_fingerprint_failure.get("completed_check_count") == 0
			and len(structured_results) == 1
			and structured_results[0].get("name") == "workspace_fingerprint_setup"
			and structured_results[0].get("exit_code") == 1
			and "fixture fingerprint setup failure" in structured_results[0].get("stderr", ""),
			"Fingerprint setup drift and safety failures must return structured check JSON instead of a traceback: "
			f"error={structured_fingerprint_error!r}, payload={structured_fingerprint_failure}.",
		)

	with tempfile.TemporaryDirectory(prefix="gf-godot-resolver-self-test-") as temp_dir:
		fixture_root = Path(temp_dir)
		steam_launcher = fixture_root / "godot.exe"
		steam_engine = fixture_root / "godot.windows.opt.tools.64.exe"
		override_engine = fixture_root / "custom-godot.exe"
		for executable_path in (steam_launcher, steam_engine, override_engine):
			executable_path.write_bytes(b"fixture")
		record_result(
			"godot_resolver_bypasses_detached_windows_steam_launcher",
			resolve_godot_executable(
				str(steam_launcher),
				environment={},
				platform_name="nt",
			) == str(steam_engine.resolve()),
			"Windows maintenance checks must supervise the foreground Steam engine binary.",
		)
		record_result(
			"godot_resolver_honors_explicit_environment_override",
			resolve_godot_executable(
				str(steam_launcher),
				environment={"GF_GODOT_EXECUTABLE": str(override_engine)},
				platform_name="nt",
			) == str(override_engine.resolve()),
			"GF_GODOT_EXECUTABLE must remain the explicit cross-platform executable override.",
		)
		environment_workspace = fixture_root / "environment-workspace"
		environment_workspace.mkdir()
		external_private_root = fixture_root / "u0"
		private_environment, private_root = parallel_shard_environment(
			environment_workspace,
			external_private_root,
		)
		if os.name == "nt":
			platform_environment_fields = ("APPDATA", "LOCALAPPDATA", "TMPDIR", "TEMP", "TMP")
		elif sys.platform == "darwin":
			platform_environment_fields = ("HOME", "TMPDIR", "TEMP", "TMP")
		else:
			platform_environment_fields = (
				"HOME",
				"XDG_DATA_HOME",
				"XDG_CONFIG_HOME",
				"XDG_CACHE_HOME",
				"TMPDIR",
				"TEMP",
				"TMP",
			)
		record_result(
			"parallel_godot_environment_uses_platform_private_roots",
			all(
				path_is_within_private_root(private_environment[field_name], private_root)
				for field_name in platform_environment_fields
			)
			and "GODOT_USER_HOME" not in private_environment
			and private_root == external_private_root
			and not paths_overlap(environment_workspace, private_root),
			"Parallel Godot shards must use platform-native private data/config/cache roots.",
		)
		preexisting_private_root = fixture_root / "preexisting-private-root"
		preexisting_private_root.mkdir()
		preexisting_private_rejected = False
		overlapping_private_rejected = False
		try:
			parallel_shard_environment(environment_workspace, preexisting_private_root)
		except WorkspaceSnapshotError:
			preexisting_private_rejected = True
		try:
			parallel_shard_environment(
				environment_workspace,
				environment_workspace / "nested-private-root",
			)
		except WorkspaceSnapshotError:
			overlapping_private_rejected = True
		record_result(
			"parallel_private_roots_reject_existing_and_overlapping_paths",
			preexisting_private_rejected and overlapping_private_rejected,
			"Shard-private OS roots must be new external siblings, never preexisting or nested in a clone.",
		)

	injected_windows_drives = {
		"C:\\": (WINDOWS_DRIVE_FIXED, (r"\Device\HarddiskVolume3",)),
		"N:\\": (4, (r"\Device\Mup\server\share",)),
		"S:\\": (WINDOWS_DRIVE_FIXED, (r"\??\C:\subst-root",)),
		"A:\\": (WINDOWS_DRIVE_FIXED, (r"\DosDevices\C:\alias-root",)),
		"R:\\": (2, (r"\Device\HarddiskVolume4",)),
		"M:\\": (
			WINDOWS_DRIVE_FIXED,
			(r"\Device\HarddiskVolume5", r"\Device\HarddiskVolume6"),
		),
		"X:\\": (WINDOWS_DRIVE_FIXED, (r"\Device\Mup\server\share",)),
	}

	def injected_windows_drive_probe(drive_root: str) -> tuple[int, tuple[str, ...]]:
		if drive_root not in injected_windows_drives:
			raise OSError("fixture drive is unavailable")
		return injected_windows_drives[drive_root]

	record_result(
		"windows_validation_drive_identity_rejects_remote_subst_and_aliases",
		not windows_validation_drive_issue(
			"C:\\",
			drive_probe=injected_windows_drive_probe,
		)
		and all(
			bool(windows_validation_drive_issue(
				drive_root,
				drive_probe=injected_windows_drive_probe,
			))
			for drive_root in ("N:\\", "S:\\", "A:\\", "R:\\", "M:\\", "X:\\", "Q:\\")
		)
		and bool(windows_validation_drive_issue(
			"not-a-drive",
			drive_probe=injected_windows_drive_probe,
		)),
		"Windows validation roots must resolve directly to one local fixed-volume device and fail closed on probe errors.",
	)

	with tempfile.TemporaryDirectory(prefix="gf-validation-root-policy-self-test-") as temp_dir:
		fixture_root = Path(temp_dir)
		missing_candidate = fixture_root / "missing"
		link_target = fixture_root / "link-target"
		link_target.mkdir()
		linked_candidate = fixture_root / "linked-candidate"
		create_directory_link_fixture(link_target, linked_candidate)
		candidate_policy_ok = (
			bool(validation_temp_candidate_issue(Path("relative-root")))
			and bool(validation_temp_candidate_issue(missing_candidate))
			and bool(validation_temp_candidate_issue(ROOT))
			and bool(validation_temp_candidate_issue(linked_candidate))
			and not validation_temp_candidate_issue(linked_candidate.resolve(strict=True))
		)
		if os.name == "nt":
			candidate_policy_ok = candidate_policy_ok and bool(
				validation_temp_candidate_issue(Path(r"\\server\share\gf"))
			)
		record_result(
			"validation_temp_candidates_reject_unsafe_boundaries",
			candidate_policy_ok,
			"Validation roots must reject relative, missing, source-owned, linked, UNC, mapped, substituted, and device boundaries.",
		)

	short_root_issue = ""
	short_root_cleanup_errors: list[str] = []
	short_root: Path | None = None
	short_root_was_safe = False
	try:
		with managed_validation_directory(
			prefix="gfv-",
			cleanup_errors=short_root_cleanup_errors,
			windows_max_characters=WINDOWS_PARALLEL_VALIDATION_ROOT_MAX_CHARACTERS,
		) as managed_root:
			short_root = managed_root
			metadata = managed_root.lstat()
			projected_workspace = managed_root / "b0" / "s5"
			projected_staging_workspace = managed_root / "b0" / ".s5.m" / "w"
			projected_private_temp = managed_root / "b0" / "u" / "5" / "t"
			short_root_was_safe = (
				stat.S_ISDIR(metadata.st_mode)
				and not stat.S_ISLNK(metadata.st_mode)
				and not bool(int(getattr(metadata, "st_file_attributes", 0)) & 0x0400)
				and not paths_overlap(managed_root, ROOT)
				and (
					os.name != "nt"
					or (
						windows_utf16_path_code_units(managed_root)
						<= WINDOWS_PARALLEL_VALIDATION_ROOT_MAX_CHARACTERS
						and windows_utf16_path_code_units(projected_workspace) <= 30
						and windows_utf16_path_code_units(projected_staging_workspace) <= 30
						and windows_utf16_path_code_units(projected_private_temp) <= 30
					)
				)
			)
	except WorkspaceSnapshotError as error:
		short_root_issue = str(error)
	record_result(
		"parallel_validation_owns_a_short_nonoverlapping_root",
		short_root_was_safe
		and short_root is not None
		and not os.path.lexists(short_root)
		and not short_root_cleanup_errors,
		"Parallel Full must own and clean a short root outside the source workspace: "
		f"{short_root_issue or short_root_cleanup_errors}",
	)

	with tempfile.TemporaryDirectory(prefix="gf-batch-cleanup-self-test-") as temp_dir:
		batch_cleanup_errors: list[str] = []
		batch_path = Path(temp_dir) / "b"
		with managed_owned_directory(batch_path, cleanup_errors=batch_cleanup_errors) as batch_root:
			batch_workspace = batch_root / "s0"
			batch_workspace.mkdir()
			_batch_environment, _batch_private_root = parallel_shard_environment(
				batch_workspace,
				batch_root / "u0",
			)
		record_result(
			"parallel_batches_cleanup_workspaces_and_private_os_roots_together",
			not batch_cleanup_errors and not os.path.lexists(batch_path),
			f"Each batch must release clones, user data, caches, and temporary files together: {batch_cleanup_errors}",
		)

	managed_cleanup_root = Path(tempfile.mkdtemp(prefix="gf-managed-cleanup-self-test-"))
	managed_cleanup_nested = managed_cleanup_root.joinpath(
		*(f"long-{index}-" + "x" * 72 for index in range(4))
	)
	managed_cleanup_target: Path | str = managed_cleanup_nested
	if os.name == "nt":
		managed_cleanup_target = "\\\\?\\" + str(managed_cleanup_nested)
	Path(managed_cleanup_target).mkdir(parents=True)
	(Path(managed_cleanup_target) / "fixture.txt").write_text("fixture", encoding="utf-8")
	managed_cleanup_issue = remove_managed_temporary_tree(managed_cleanup_root)
	record_result(
		"managed_temporary_cleanup_handles_extended_windows_paths",
		not managed_cleanup_issue and not os.path.lexists(managed_cleanup_root),
		f"Managed temporary cleanup must remove long owned trees with bounded retries: {managed_cleanup_issue}",
	)

	with tempfile.TemporaryDirectory(prefix="gf-managed-identity-self-test-") as temp_dir:
		fixture_root = Path(temp_dir)
		owned_root = fixture_root / "owned"
		moved_root = fixture_root / "moved"
		owned_root.mkdir()
		owned_identity = owned_root.lstat()
		os.replace(owned_root, moved_root)
		owned_root.mkdir()
		replacement_issue = remove_managed_temporary_tree(
			owned_root,
			expected_identity=owned_identity,
		)
		record_result(
			"managed_cleanup_rejects_replaced_root_identity",
			bool(replacement_issue) and owned_root.exists() and moved_root.exists(),
			"Cleanup must not delete a path whose directory identity changed after ownership was recorded.",
		)

	with tempfile.TemporaryDirectory(prefix="gf-parallel-log-copy-self-test-") as temp_dir:
		fixture_root = Path(temp_dir)
		workspace_root = fixture_root / "workspace"
		source_log_root = workspace_root / "ai_analysis" / "godot_logs"
		destination_log_root = fixture_root / "destination"
		source_log_root.mkdir(parents=True)
		destination_log_root.mkdir()
		(source_log_root / "gut.log").write_text("stable evidence", encoding="utf-8")
		log_copy_issue = ""
		try:
			copy_parallel_log_tree(
				source_log_root,
				destination_log_root,
				containment_root=workspace_root,
				destination_containment_root=fixture_root,
				expected_destination_identity=destination_log_root.lstat(),
				expected_destination_containment_identity=fixture_root.lstat(),
			)
		except (OSError, ValueError) as error:
			log_copy_issue = str(error)
		overflow_source = workspace_root / "overflow-logs"
		overflow_destination = fixture_root / "overflow-destination"
		overflow_source.mkdir()
		overflow_destination.mkdir()
		for index in range(DEFAULT_MAINTENANCE_LOG_MAX_FILES + 1):
			(overflow_source / f"{index:02d}.log").write_bytes(b"x")
		overflow_rejected = False
		try:
			copy_parallel_log_tree(
				overflow_source,
				overflow_destination,
				containment_root=workspace_root,
				destination_containment_root=fixture_root,
				expected_destination_identity=overflow_destination.lstat(),
				expected_destination_containment_identity=fixture_root.lstat(),
			)
		except ValueError:
			overflow_rejected = True
		record_result(
			"parallel_failure_logs_copy_from_stable_open_handles",
			not log_copy_issue
			and overflow_rejected
			and (destination_log_root / "gut.log").read_text(encoding="utf-8") == "stable evidence",
			f"Stable regular log files must survive bounded source/destination identity validation: {log_copy_issue}",
		)

	with tempfile.TemporaryDirectory(prefix="gf-maintenance-log-session-self-test-") as temp_dir:
		log_root = Path(temp_dir) / "logs"
		log_root.mkdir()
		unchanged_path = log_root / "unchanged.log"
		changed_path = log_root / "changed.log"
		unchanged_path.write_text("unchanged", encoding="utf-8")
		changed_path.write_text("before", encoding="utf-8")
		before_snapshot, before_errors = maintenance_log_snapshot(log_root)
		changed_path.write_text("after-with-a-different-size", encoding="utf-8")
		new_path = log_root / "new.json"
		new_path.write_text("{}", encoding="utf-8")
		after_snapshot, after_errors = maintenance_log_snapshot(log_root)
		changed_paths = changed_maintenance_log_paths(before_snapshot, after_snapshot, log_root)
		session_cleanup = remove_maintenance_log_files(changed_paths, log_root)
		record_result(
			"maintenance_log_session_cleanup_removes_only_changed_files",
			not before_errors
			and not after_errors
			and session_cleanup["ok"]
			and set(session_cleanup["removed_files"]) == {"changed.log", "new.json"}
			and unchanged_path.exists()
			and not changed_path.exists()
			and not new_path.exists(),
			f"session log cleanup must preserve unchanged evidence: {session_cleanup}",
		)

	with tempfile.TemporaryDirectory(prefix="gf-maintenance-log-finalization-self-test-") as temp_dir:
		log_root = Path(temp_dir) / "logs"
		log_root.mkdir()
		historical_path = log_root / "historical.log"
		session_path = log_root / "session.log"
		historical_path.write_text("historical", encoding="utf-8")
		before_snapshot, before_errors = maintenance_log_snapshot(log_root)
		session_path.write_text("session", encoding="utf-8")
		success_finalization = finalize_maintenance_log_session(
			before_snapshot,
			before_errors,
			succeeded=True,
			keep_logs=False,
			log_root=log_root,
		)
		failed_before_snapshot, failed_before_errors = maintenance_log_snapshot(log_root)
		failure_path = log_root / "failure.log"
		failure_path.write_text("failure", encoding="utf-8")
		failure_finalization = finalize_maintenance_log_session(
			failed_before_snapshot,
			failed_before_errors,
			succeeded=False,
			keep_logs=False,
			log_root=log_root,
		)
		record_result(
			"maintenance_log_finalization_is_strictly_session_owned",
			success_finalization["ok"]
			and success_finalization["changed_file_count"] == 1
			and success_finalization["retained_session_file_count"] == 0
			and historical_path.exists()
			and not session_path.exists()
			and failure_finalization["ok"]
			and failure_finalization["retained_session_file_count"] == 1
			and failure_path.exists()
			and "retention" not in success_finalization
			and "legacy_cleanup" not in success_finalization,
			(
				"automatic finalization may delete only successful invocation-owned logs; unrelated history "
				"and failed-session evidence require an explicit hygiene command."
			),
		)

	with tempfile.TemporaryDirectory(prefix="gf-maintenance-log-retention-self-test-") as temp_dir:
		log_root = Path(temp_dir) / "logs"
		log_root.mkdir()
		now_ns = time.time_ns()
		for index in range(5):
			path = log_root / f"retained_{index}.log"
			path.write_text(str(index) * 8, encoding="utf-8")
			mtime_ns = now_ns - (5 - index) * 1_000_000_000
			os.utime(path, ns=(mtime_ns, mtime_ns))
		retention = maintenance_log_hygiene(
			log_root,
			max_files=2,
			max_age_days=365,
			max_total_bytes=1024,
			now_ns=now_ns,
		)
		remaining_names = {path.name for path in log_root.iterdir()}
		record_result(
			"maintenance_log_retention_keeps_newest_files_within_count_limit",
			retention["ok"]
			and retention["retention_satisfied"]
			and remaining_names == {"retained_3.log", "retained_4.log"},
			f"bounded retention must keep the newest files: {retention}",
		)

	with tempfile.TemporaryDirectory(prefix="gf-maintenance-log-protection-self-test-") as temp_dir:
		log_root = Path(temp_dir) / "logs"
		log_root.mkdir()
		now_ns = time.time_ns()
		protected_path = log_root / "current_failure.log"
		stale_path = log_root / "stale.log"
		protected_path.write_text("failure", encoding="utf-8")
		stale_path.write_text("stale", encoding="utf-8")
		stale_mtime_ns = now_ns - 30 * 24 * 60 * 60 * 1_000_000_000
		os.utime(stale_path, ns=(stale_mtime_ns, stale_mtime_ns))
		protected_retention = maintenance_log_hygiene(
			log_root,
			max_files=0,
			max_age_days=0,
			max_total_bytes=0,
			protected_paths=[protected_path],
			now_ns=now_ns,
		)
		record_result(
			"maintenance_log_retention_protects_current_failure_evidence",
			protected_retention["ok"]
			and not protected_retention["retention_satisfied"]
			and protected_path.exists()
			and not stale_path.exists(),
			f"current failed-session logs must survive the invocation that produced them: {protected_retention}",
		)

	with tempfile.TemporaryDirectory(prefix="gf-maintenance-log-all-self-test-") as temp_dir:
		log_root = Path(temp_dir) / "logs"
		log_root.mkdir()
		(log_root / "one.log").write_text("one", encoding="utf-8")
		(log_root / "two.xml").write_text("two", encoding="utf-8")
		dry_run_cleanup = maintenance_log_hygiene(log_root, remove_all=True, dry_run=True)
		actual_cleanup = maintenance_log_hygiene(log_root, remove_all=True)
		record_result(
			"maintenance_log_hygiene_all_supports_dry_run_then_cleanup",
			dry_run_cleanup["ok"]
			and dry_run_cleanup["candidate_file_count"] == 2
			and dry_run_cleanup["removed_file_count"] == 0
			and actual_cleanup["ok"]
			and actual_cleanup["removed_file_count"] == 2
			and actual_cleanup["retained_file_count"] == 0,
			f"--all dry-run and cleanup results must remain truthful: {dry_run_cleanup} / {actual_cleanup}",
		)

	with tempfile.TemporaryDirectory(prefix="gf-maintenance-log-race-self-test-") as temp_dir:
		log_root = Path(temp_dir) / "logs"
		log_root.mkdir()
		vanishing_log_path = log_root / "vanishing.log"
		vanishing_log_path.write_text("vanishing", encoding="utf-8")
		original_lstat = Path.lstat

		def remove_log_before_lstat(path: Path) -> os.stat_result:
			if lexical_absolute_path(path) == lexical_absolute_path(vanishing_log_path):
				vanishing_log_path.unlink(missing_ok=True)
			return original_lstat(path)

		Path.lstat = remove_log_before_lstat
		try:
			vanishing_records, vanishing_errors = scan_maintenance_log_files(log_root)
		finally:
			Path.lstat = original_lstat
		record_result(
			"maintenance_log_scan_tolerates_concurrent_deletion",
			not vanishing_records and not vanishing_errors,
			f"logs deleted after enumeration must be treated as already cleaned: {vanishing_errors}",
		)

	with tempfile.TemporaryDirectory(prefix="gf-workspace-log-hygiene-self-test-") as temp_dir:
		temp_root = Path(temp_dir)
		managed_log_root = temp_root / "managed"
		legacy_log_root = temp_root / ".gf"
		managed_log_root.mkdir()
		legacy_log_root.mkdir()
		managed_log_path = managed_log_root / "current.log"
		legacy_log_path = legacy_log_root / "manual_test.log"
		preserved_state_path = legacy_log_root / "packages.lock.json"
		nested_state_root = legacy_log_root / "package_cache"
		nested_state_root.mkdir()
		nested_log_path = nested_state_root / "registry.log"
		managed_log_path.write_text("managed", encoding="utf-8")
		legacy_log_path.write_text("legacy", encoding="utf-8")
		preserved_state_path.write_text("{}", encoding="utf-8")
		nested_log_path.write_text("package state", encoding="utf-8")
		workspace_cleanup = workspace_log_hygiene(
			managed_log_root,
			legacy_log_root,
			max_files=32,
			max_age_days=7,
			max_total_bytes=1024,
		)
		record_result(
			"workspace_log_hygiene_removes_only_top_level_legacy_logs",
			workspace_cleanup["ok"]
			and workspace_cleanup["reason_counts"].get("legacy_location") == 1
			and managed_log_path.exists()
			and not legacy_log_path.exists()
			and preserved_state_path.exists()
			and nested_log_path.exists(),
			f"legacy cleanup must not touch .gf package state or nested files: {workspace_cleanup}",
		)

	gitignore_source = read_text_file(ROOT / ".gitignore")
	gitignore_lines = {
		line.strip()
		for line in gitignore_source.splitlines()
		if line.strip() and not line.lstrip().startswith("#")
	}
	record_result(
		"gitignore_blocks_top_level_gf_log_files",
		".gf/*.log" in gitignore_lines,
		"Top-level .gf logs must not reappear as commit candidates.",
	)
	record_result(
		"build_output_is_outside_godot_resource_graph",
		(ROOT / "build" / ".gdignore").is_file()
		and "/build/*" in gitignore_lines
		and "!/build/.gdignore" in gitignore_lines,
		"build/.gdignore must stay tracked while every other build output stays ignored.",
	)
	outside_json_output_rejected = False
	try:
		maintenance_json_output_path("ai_analysis/maintenance-result.json")
	except ValueError:
		outside_json_output_rejected = True
	record_result(
		"maintenance_json_output_rejects_paths_outside_build",
		outside_json_output_rejected,
		"Machine-readable maintenance results must stay below the ignored build root.",
	)
	with tempfile.TemporaryDirectory(prefix="gf-json-output-self-test-", dir=ROOT / "build") as temp_dir:
		json_output_path = maintenance_json_output_path(str(Path(temp_dir) / "result.json"))
		maintenance_rendering.write_utf8_json_output(
			json_output_path,
			json.dumps({"message": "UTF-8 输出"}, ensure_ascii=False) + "\n",
		)
		json_output_bytes = json_output_path.read_bytes()
		json_output_payload = json.loads(json_output_bytes.decode("utf-8"))
		record_result(
			"maintenance_json_output_is_atomic_utf8_without_bom",
			json_output_bytes.startswith(b"{")
			and not json_output_bytes.startswith((b"\xff\xfe", b"\xfe\xff", b"\xef\xbb\xbf"))
			and json_output_payload == {"message": "UTF-8 输出"},
			"Explicit JSON output must remain strict UTF-8 and parse without byte-order repair.",
		)

	with tempfile.TemporaryDirectory(prefix="gf-generated-output-self-test-") as temp_dir:
		temp_root = Path(temp_dir)
		first_root = temp_root / "first"
		second_root = temp_root / "second"
		first_root.mkdir()
		second_root.mkdir()
		(first_root / "old.txt").write_text("old-first", encoding="utf-8")
		(second_root / "old.txt").write_text("old-second", encoding="utf-8")
		replace_generated_trees([
			(first_root, {"new.txt": "new-first"}),
			(second_root, {"nested/new.txt": "new-second"}),
		])
		transaction_replaced_both = (
			(first_root / "new.txt").read_text(encoding="utf-8") == "new-first"
			and (second_root / "nested/new.txt").read_text(encoding="utf-8") == "new-second"
			and not (first_root / "old.txt").exists()
			and not (second_root / "old.txt").exists()
		)
		record_result(
			"generated_output_transaction_replaces_all_roots",
			transaction_replaced_both,
			"generated output transaction must replace every staged root together.",
		)
		try:
			replace_generated_trees([
				(first_root, {"after.txt": "after"}),
				(second_root, {"../escape.txt": "escape"}),
			])
		except ValueError:
			pass
		record_result(
			"generated_output_transaction_rejects_escape_before_replacement",
			(first_root / "new.txt").exists() and (second_root / "nested/new.txt").exists(),
			"invalid generated paths must be rejected before any existing output is replaced.",
		)
		invalid_root = temp_root / "not-a-directory"
		invalid_root.write_text("preserve", encoding="utf-8")
		try:
			replace_generated_trees([
				(first_root, {"after.txt": "after"}),
				(invalid_root, {"never.txt": "never"}),
			])
		except RuntimeError:
			pass
		record_result(
			"generated_output_transaction_rolls_back_previous_root",
			(first_root / "new.txt").read_text(encoding="utf-8") == "new-first"
			and invalid_root.read_text(encoding="utf-8") == "preserve",
			"a later root replacement failure must restore every root already replaced.",
		)

		external_root = temp_root / "external-generated-root"
		external_root.mkdir()
		(external_root / "user.txt").write_text("preserve", encoding="utf-8")
		linked_root = temp_root / "linked-generated-root"
		create_directory_link_fixture(external_root, linked_root)
		linked_root_rejected = False
		try:
			replace_generated_trees([(linked_root, {"generated.txt": "unsafe"})])
		except ValueError:
			linked_root_rejected = True
		record_result(
			"generated_output_transaction_rejects_linked_roots",
			linked_root_rejected
			and (external_root / "user.txt").read_text(encoding="utf-8") == "preserve"
			and not (external_root / "generated.txt").exists(),
			"generated output roots must reject symlink or junction traversal before staging or cleanup.",
		)

		rollback_root = temp_root / "rollback-evidence"
		rollback_blocker = temp_root / "rollback-blocker"
		rollback_root.mkdir()
		rollback_root.joinpath("old.txt").write_text("old", encoding="utf-8")
		rollback_blocker.write_text("block", encoding="utf-8")
		original_rmtree = generated_output_transaction.shutil.rmtree

		def fail_rollback_rmtree(path: Any, *args: Any, **kwargs: Any) -> Any:
			if lexical_absolute_path(Path(path)) == lexical_absolute_path(rollback_root):
				raise OSError("fixture rollback removal failure")
			return original_rmtree(path, *args, **kwargs)

		rollback_error: GeneratedOutputTransactionError | None = None
		generated_output_transaction.shutil.rmtree = fail_rollback_rmtree
		try:
			replace_generated_trees([
				(rollback_root, {"new.txt": "new"}),
				(rollback_blocker, {"never.txt": "never"}),
			])
		except GeneratedOutputTransactionError as error:
			rollback_error = error
		finally:
			generated_output_transaction.shutil.rmtree = original_rmtree
		retained_backups = rollback_error.backup_paths if rollback_error is not None else []
		record_result(
			"generated_output_transaction_retains_backup_when_rollback_fails",
			rollback_error is not None
			and "Generated output root is not a directory" in str(rollback_error.original_error)
			and len(rollback_error.rollback_errors) == 1
			and len(retained_backups) == 1
			and retained_backups[0].joinpath("old.txt").read_text(encoding="utf-8") == "old",
			f"rollback failure must report both errors and retain one recoverable backup: {rollback_error}",
		)
		for backup_path in retained_backups:
			if backup_path.parent.exists():
				original_rmtree(backup_path.parent)

	with tempfile.TemporaryDirectory(prefix="gf-command-log-self-test-") as temp_dir:
		log_path = Path(temp_dir) / "gut.log"
		gut_success_summary = "\n".join([
			"==============================================",
			"= Run Summary",
			"==============================================",
			"Totals",
			"------",
			"Scripts 1",
			"Tests 1",
			"Passing Tests 1",
			"Asserts 1",
			"---- All tests passed! ----",
			(
				f'{GUT_LIFECYCLE_GATE_PREFIX}'
				'{"schema_version":1,"ok":true,"unhandled_warning_count":0,"orphan_count":0,'
				'"baseline_available":true,"warning_tracking_available":true,'
				'"warnings":[],"orphans":[],"details_truncated":false,"configuration_error":""}'
			),
			"",
		])
		passing_code = (
			"from pathlib import Path; "
			f"Path({str(log_path)!r}).write_text({gut_success_summary!r}, encoding='utf-8')"
		)
		passing_result = run_command(
			"gut",
			[sys.executable, "-c", passing_code, "--log-file", str(log_path)],
			10,
		)
		record_result(
			"run_command_reads_configured_log_for_gut_summary",
			passing_result.exit_code == 0
			and "---- All tests passed! ----" in passing_result.stdout
			and passing_result.gut_lifecycle_report is not None
			and passing_result.gut_lifecycle_report["ok"]
			and passing_result.to_dict().get("gut_lifecycle_report", {}).get("schema_version")
			== GUT_LIFECYCLE_GATE_SCHEMA_VERSION
			and passing_result.duration_seconds > 0.0
			and passing_result.timeout_seconds == 10,
			(
				"configured GUT log and lifecycle evidence must be part of command evaluation: "
				f"{passing_result.to_dict()}"
			),
		)
		per_script_code = (
			"from pathlib import Path; "
			f"Path({str(log_path)!r}).write_text('1 / 1 passed.\\n', encoding='utf-8')"
		)
		per_script_result = run_command(
			"gut",
			[sys.executable, "-c", per_script_code, "--log-file", str(log_path)],
			10,
		)
		record_result(
			"run_command_rejects_per_script_gut_pass_line",
			per_script_result.exit_code != 0,
			"per-script x/x pass lines must not substitute for the final whole-suite GUT summary.",
		)
		nonzero_code = (
			"import sys; from pathlib import Path; "
			f"Path({str(log_path)!r}).write_text({gut_success_summary!r}, encoding='utf-8'); "
			"sys.exit(7)"
		)
		nonzero_result = run_command(
			"gut",
			[sys.executable, "-c", nonzero_code, "--log-file", str(log_path)],
			10,
		)
		record_result(
			"run_command_preserves_nonzero_gut_process_exit",
			nonzero_result.exit_code == 7 and nonzero_result.process_exit_code == 7,
			f"a final pass summary must never downgrade a non-zero process exit: {nonzero_result.to_dict()}",
		)
		failing_code = (
			"from pathlib import Path; "
			f"Path({str(log_path)!r}).write_text("
			"'1 / 1 passed.\\n= Run Summary\\nTotals\\nTests 3\\nPassing Tests 2\\n'"
			"'Failing Tests 1\\n---- 1 failing tests ----\\n', encoding='utf-8')"
		)
		failing_result = run_command(
			"gut",
			[sys.executable, "-c", failing_code, "--log-file", str(log_path)],
			10,
		)
		record_result(
			"run_command_rejects_failing_whole_suite_gut_summary",
			failing_result.exit_code != 0,
			"failure text and a failing final summary must fail even when per-script pass lines exist.",
		)
		empty_code = (
			"from pathlib import Path; "
			f"Path({str(log_path)!r}).write_text('Nothing was run.\\n', encoding='utf-8')"
		)
		empty_result = run_command(
			"gut",
			[sys.executable, "-c", empty_code, "--log-file", str(log_path)],
			10,
		)
		record_result(
			"run_command_rejects_empty_gut_success",
			empty_result.exit_code != 0,
			"a zero process exit without a non-empty GUT pass summary must fail.",
		)
		warning_code = (
			"from pathlib import Path; "
			f"Path({str(log_path)!r}).write_text("
			f"{'GDScript::reload: fixture warning' + chr(10) + gut_success_summary!r}, encoding='utf-8')"
		)
		warning_result = run_command(
			"gut",
			[sys.executable, "-c", warning_code, "--log-file", str(log_path)],
			10,
		)
		record_result(
			"run_command_rejects_reload_warning_from_configured_log",
			warning_result.exit_code != 0,
			"GDScript reload warnings in --log-file output must fail the command.",
		)
		lsp_parse_error_code = (
			"from pathlib import Path; "
			f"Path({str(log_path)!r}).write_text("
			"'SCRIPT ERROR: Parse Error: Could not resolve super class path.\\n', encoding='utf-8')"
		)
		lsp_parse_error_result = run_command(
			"gdscript_lsp_diagnostics",
			[sys.executable, "-c", lsp_parse_error_code, "--log-file", str(log_path)],
			10,
		)
		record_result(
			"run_command_rejects_lsp_parse_error_from_configured_log",
			lsp_parse_error_result.exit_code != 0,
			"LSP startup parse errors in --log-file output must fail the command.",
		)
		lsp_reload_warning_code = (
			"from pathlib import Path; "
			f"Path({str(log_path)!r}).write_text("
			"'GDScript::reload: fixture warning\\n', encoding='utf-8')"
		)
		lsp_reload_warning_result = run_command(
			"gdscript_lsp_diagnostics",
			[sys.executable, "-c", lsp_reload_warning_code, "--log-file", str(log_path)],
			10,
		)
		record_result(
			"run_command_rejects_lsp_reload_warning_from_configured_log",
			lsp_reload_warning_result.exit_code != 0,
			"LSP startup reload warnings in --log-file output must fail the command.",
		)
		missing_lifecycle_marker_summary = gut_success_summary.replace(
			next(
				line
				for line in gut_success_summary.splitlines()
				if line.startswith(GUT_LIFECYCLE_GATE_PREFIX)
			) + "\n",
			"",
		)
		missing_lifecycle_marker_code = (
			"from pathlib import Path; "
			f"Path({str(log_path)!r}).write_text({missing_lifecycle_marker_summary!r}, encoding='utf-8')"
		)
		missing_lifecycle_marker_result = run_command(
			"gut",
			[sys.executable, "-c", missing_lifecycle_marker_code, "--log-file", str(log_path)],
			10,
		)
		record_result(
			"run_command_requires_gut_lifecycle_marker",
			missing_lifecycle_marker_result.exit_code != 0
			and missing_lifecycle_marker_result.gut_lifecycle_report is not None
			and not missing_lifecycle_marker_result.gut_lifecycle_report["ok"],
			"GUT success must be rejected when the lifecycle post-run hook did not report.",
		)
		warning_lifecycle_summary = gut_success_summary.replace(
			'"ok":true,"unhandled_warning_count":0',
			'"ok":false,"unhandled_warning_count":1',
		).replace(
			'"warnings":[]',
			'"warnings":[{"test_id":"fixture","code":"warning","file":"fixture.gd","line":1}]',
		).replace(
			"Asserts 1\n",
			"Asserts 1\nWarnings 1\n",
		)
		warning_lifecycle_code = (
			"from pathlib import Path; "
			f"Path({str(log_path)!r}).write_text({warning_lifecycle_summary!r}, encoding='utf-8')"
		)
		warning_lifecycle_result = run_command(
			"gut",
			[sys.executable, "-c", warning_lifecycle_code, "--log-file", str(log_path)],
			10,
		)
		record_result(
			"run_command_rejects_unhandled_gut_warnings",
			warning_lifecycle_result.exit_code != 0
			and warning_lifecycle_result.gut_lifecycle_report is not None
			and warning_lifecycle_result.gut_lifecycle_report["unhandled_warning_count"] == 1
			and warning_lifecycle_result.gut_lifecycle_report["summary_warning_count"] == 1,
			"Unhandled push_warning records and non-zero GUT summary warnings must hard-fail.",
		)
		orphan_lifecycle_summary = gut_success_summary.replace(
			'"ok":true,"unhandled_warning_count":0,"orphan_count":0',
			'"ok":false,"unhandled_warning_count":0,"orphan_count":2',
		).replace(
			'"orphans":[]',
			'"orphans":[{"instance_id":1,"class":"Node","name":"first"},'
			'{"instance_id":2,"class":"Node","name":"second"}]',
		).replace(
			"---- All tests passed! ----\n",
			"    2 Orphans\n---- All tests passed! ----\n",
		)
		orphan_lifecycle_code = (
			"from pathlib import Path; "
			f"Path({str(log_path)!r}).write_text({orphan_lifecycle_summary!r}, encoding='utf-8')"
		)
		orphan_lifecycle_result = run_command(
			"gut",
			[sys.executable, "-c", orphan_lifecycle_code, "--log-file", str(log_path)],
			10,
		)
		record_result(
			"run_command_rejects_gut_orphans",
			orphan_lifecycle_result.exit_code != 0
			and orphan_lifecycle_result.gut_lifecycle_report is not None
			and orphan_lifecycle_result.gut_lifecycle_report["orphan_count"] == 2
			and orphan_lifecycle_result.gut_lifecycle_report["reported_orphan_count"] == 2,
			"GUT orphan reports must hard-fail even when every assertion passed.",
		)
		clean_lifecycle_payload = {
			"schema_version": GUT_LIFECYCLE_GATE_SCHEMA_VERSION,
			"ok": True,
			"baseline_available": True,
			"warning_tracking_available": True,
			"unhandled_warning_count": 0,
			"orphan_count": 0,
			"warnings": [],
			"orphans": [],
			"details_truncated": False,
			"configuration_error": "",
		}
		extra_field_payload = {**clean_lifecycle_payload, "unexpected": True}
		invalid_truncation_payload = {
			**clean_lifecycle_payload,
			"details_truncated": True,
		}
		invalid_warning_detail_payload = {
			**clean_lifecycle_payload,
			"ok": False,
			"unhandled_warning_count": 1,
			"warnings": [{"test_id": "fixture", "code": "warning", "file": "fixture.gd"}],
		}
		oversized_text_payload = {
			**clean_lifecycle_payload,
			"configuration_error": "x" * (GUT_LIFECYCLE_GATE_MAX_TEXT_LENGTH + 1),
		}
		oversized_multibyte_text_payload = {
			**clean_lifecycle_payload,
			"configuration_error": "界" * GUT_LIFECYCLE_GATE_MAX_TEXT_LENGTH,
		}
		record_result(
			"gut_lifecycle_marker_schema_is_closed_and_bounded",
			validate_gut_lifecycle_gate_payload(clean_lifecycle_payload) == ""
			and validate_gut_lifecycle_gate_payload(extra_field_payload) != ""
			and validate_gut_lifecycle_gate_payload(invalid_truncation_payload) != ""
			and validate_gut_lifecycle_gate_payload(invalid_warning_detail_payload) != ""
			and validate_gut_lifecycle_gate_payload(oversized_text_payload) != ""
			and validate_gut_lifecycle_gate_payload(oversized_multibyte_text_payload) != "",
			"Lifecycle marker v1 must reject extra fields, inconsistent truncation, malformed details, and character/UTF-8 oversized text.",
		)
		clean_lifecycle_marker = (
			GUT_LIFECYCLE_GATE_PREFIX
			+ json.dumps(clean_lifecycle_payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
		)
		invalid_lifecycle_payload = {
			**clean_lifecycle_payload,
			"ok": False,
			"baseline_available": False,
			"configuration_error": "fixture_baseline_unavailable",
		}
		invalid_lifecycle_marker = (
			GUT_LIFECYCLE_GATE_PREFIX
			+ json.dumps(invalid_lifecycle_payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
		)
		identical_marker_report = parse_gut_lifecycle_gate_output(
			f"{clean_lifecycle_marker}\n{clean_lifecycle_marker}\n",
			"",
		)
		excessive_identical_marker_report = parse_gut_lifecycle_gate_output(
			"\n".join([clean_lifecycle_marker] * 3),
			"",
		)
		conflicting_marker_report = parse_gut_lifecycle_gate_output(
			f"{clean_lifecycle_marker}\n{invalid_lifecycle_marker}\n",
			"",
		)
		malformed_marker_report = parse_gut_lifecycle_gate_output(
			f"{clean_lifecycle_marker}\n{GUT_LIFECYCLE_GATE_PREFIX}{{\n",
			"",
		)
		oversized_marker_report = parse_gut_lifecycle_gate_output(
			GUT_LIFECYCLE_GATE_PREFIX + ("x" * (GUT_LIFECYCLE_GATE_MAX_JSON_BYTES + 1)),
			"",
		)
		record_result(
			"gut_lifecycle_marker_duplicates_are_fail_closed",
			identical_marker_report["ok"]
			and identical_marker_report["marker_count"] == 2
			and not identical_marker_report["marker_errors"]
			and not excessive_identical_marker_report["ok"]
			and (
				"lifecycle marker exceeds the mirrored copy limit"
				in excessive_identical_marker_report["marker_errors"]
			)
			and not conflicting_marker_report["ok"]
			and "conflicting lifecycle markers" in conflicting_marker_report["marker_errors"]
			and not malformed_marker_report["ok"]
			and any(
				error.startswith("invalid JSON:")
				for error in malformed_marker_report["marker_errors"]
			)
			and not oversized_marker_report["ok"]
			and "lifecycle marker exceeds the byte limit" in oversized_marker_report["marker_errors"],
			"Exactly one mirrored lifecycle copy is allowed; excessive, conflicting, or malformed copies must fail.",
		)
		run_summary_orphan_text = gut_success_summary.replace(
			"---- All tests passed! ----\n",
			"Orphans              1\n---- All tests passed! ----\n",
		)
		run_summary_orphan_code = (
			"from pathlib import Path; "
			f"Path({str(log_path)!r}).write_text({run_summary_orphan_text!r}, encoding='utf-8')"
		)
		run_summary_orphan_result = run_command(
			"gut",
			[sys.executable, "-c", run_summary_orphan_code, "--log-file", str(log_path)],
			10,
		)
		record_result(
			"run_command_rejects_gut_run_summary_orphans_with_clean_hook_marker",
			run_summary_orphan_result.exit_code != 0
			and run_summary_orphan_result.gut_lifecycle_report is not None
			and run_summary_orphan_result.gut_lifecycle_report["orphan_count"] == 0
			and run_summary_orphan_result.gut_lifecycle_report["reported_orphan_count"] == 1,
			"The label-first GUT Run Summary orphan count must independently hard-fail.",
		)
		exit_leak_summary = (
			"WARNING: ObjectDB instances leaked at exit (run with --verbose for details).\n"
			+ gut_success_summary
		)
		exit_leak_code = (
			"from pathlib import Path; "
			f"Path({str(log_path)!r}).write_text({exit_leak_summary!r}, encoding='utf-8')"
		)
		exit_leak_result = run_command(
			"gut",
			[sys.executable, "-c", exit_leak_code, "--log-file", str(log_path)],
			10,
		)
		record_result(
			"run_command_rejects_gut_exit_leaks",
			exit_leak_result.exit_code != 0
			and exit_leak_result.godot_exit_leak_report is not None
			and exit_leak_result.godot_exit_leak_report["has_leaks"],
			"Godot exit leak diagnostics from GUT must be a hard failure.",
		)
		lone_leaked_instance_summary = "Leaked instance: Node:123456\n" + gut_success_summary
		lone_leaked_instance_code = (
			"from pathlib import Path; "
			f"Path({str(log_path)!r}).write_text({lone_leaked_instance_summary!r}, encoding='utf-8')"
		)
		lone_leaked_instance_result = run_command(
			"gut",
			[sys.executable, "-c", lone_leaked_instance_code, "--log-file", str(log_path)],
			10,
		)
		record_result(
			"run_command_rejects_structured_gut_exit_leak_without_summary_header",
			lone_leaked_instance_result.exit_code != 0
			and not lone_leaked_instance_result.godot_exit_leak_warnings
			and lone_leaked_instance_result.godot_exit_leak_report is not None
			and lone_leaked_instance_result.godot_exit_leak_report["has_leaks"]
			and lone_leaked_instance_result.godot_exit_leak_report["leaked_instance_total"] == 1,
			"Structured leaked-instance evidence must fail GUT even without an ObjectDB summary line.",
		)
		log_target_directory = Path(temp_dir) / "user-owned-logs"
		log_target_directory.mkdir()
		log_target = log_target_directory / "user-owned.log"
		log_target.write_text("preserve", encoding="utf-8")
		linked_log_directory = Path(temp_dir) / "linked-logs"
		create_directory_link_fixture(log_target_directory, linked_log_directory)
		linked_log = linked_log_directory / "user-owned.log"
		linked_log_result = run_command(
			"fixture",
			[sys.executable, "-c", "pass", "--log-file", str(linked_log)],
			10,
		)
		record_result(
			"run_command_rejects_linked_log_cleanup_targets",
			linked_log_result.exit_code == 126
			and log_target.read_text(encoding="utf-8") == "preserve",
			"command log cleanup must reject symlink or junction targets without touching their referents.",
		)
		directory_log = Path(temp_dir) / "directory.log"
		directory_log.mkdir()
		directory_log_result = run_command(
			"fixture",
			[sys.executable, "-c", "pass", "--log-file", str(directory_log)],
			10,
		)
		record_result(
			"run_command_cleans_only_regular_log_files",
			directory_log_result.exit_code == 126 and directory_log.is_dir(),
			"command log cleanup must refuse directories and other non-regular filesystem objects.",
		)
		outside_log_rejected = False
		try:
			prepare_command_log_paths([
				"fixture",
				"--log-file",
				str(ROOT / "maintenance-self-test-forbidden.log"),
			])
		except OSError:
			outside_log_rejected = True
		record_result(
			"run_command_rejects_logs_outside_controlled_roots",
			outside_log_rejected and not (ROOT / "maintenance-self-test-forbidden.log").exists(),
			"configured logs must stay under the repository log root or system temporary root.",
		)

	with tempfile.TemporaryDirectory(prefix="gf-process-tree-self-test-") as temp_dir:
		timeout_ready_path = Path(temp_dir) / "grandchild-ready.txt"
		timeout_ready_observed_path = Path(temp_dir) / "grandchild-ready-observed.txt"
		timeout_trigger_path = Path(temp_dir) / "grandchild-survival-trigger.txt"
		marker_path = Path(temp_dir) / "grandchild-survived.txt"
		grandchild_code = "\n".join([
			"import time",
			"from pathlib import Path",
			f"Path({str(timeout_ready_path)!r}).write_text('ready', encoding='utf-8')",
			f"trigger = Path({str(timeout_trigger_path)!r})",
			"deadline = time.monotonic() + 30.0",
			"while not trigger.exists() and time.monotonic() < deadline:",
			"\ttime.sleep(0.01)",
			"if trigger.exists():",
			f"\tPath({str(marker_path)!r}).write_text('survived', encoding='utf-8')",
		])
		parent_code = "\n".join([
			"import subprocess, sys, time",
			"from pathlib import Path",
			f"subprocess.Popen([sys.executable, '-c', {grandchild_code!r}])",
			f"ready = Path({str(timeout_ready_path)!r})",
			"deadline = time.monotonic() + 5.0",
			"while not ready.exists() and time.monotonic() < deadline:",
			"\ttime.sleep(0.01)",
			"if not ready.exists():",
			"\traise SystemExit(2)",
			f"Path({str(timeout_ready_observed_path)!r}).write_text('observed', encoding='utf-8')",
			"time.sleep(30.0)",
		])
		tree_timeout_result: CommandResult | None = None
		try:
			tree_timeout_result = run_command(
				"process_tree_timeout_fixture",
				[sys.executable, "-c", parent_code],
				6.0,
			)
		finally:
			# Always release a descendant that survived a failed or interrupted
			# supervision attempt; its own deadline covers abrupt harness exit.
			timeout_trigger_path.write_text("trigger", encoding="utf-8")
			time.sleep(1.2)
		record_result(
			"run_command_timeout_terminates_descendant_processes",
			tree_timeout_result is not None
			and tree_timeout_result.timed_out
			and not tree_timeout_result.cancelled
			and tree_timeout_result.exit_code == 124
			and timeout_ready_path.exists()
			and timeout_ready_observed_path.exists()
			and not marker_path.exists(),
			"timed-out checks must trigger only after the grandchild is ready and leave no descendants: "
			f"{tree_timeout_result.to_dict()}",
		)
		pre_cancelled_event = threading.Event()
		pre_cancelled_event.set()
		pre_cancelled_result = run_supervised_process(
			[sys.executable, "-c", "raise SystemExit(99)"],
			cwd=ROOT,
			timeout_seconds=10,
			cancellation_event=pre_cancelled_event,
		)
		cancel_ready_path = Path(temp_dir) / "grandchild-ready-cancel.txt"
		cancel_marker_path = Path(temp_dir) / "grandchild-survived-cancel.txt"
		cancel_grandchild_code = (
			"import time; from pathlib import Path; "
			f"Path({str(cancel_ready_path)!r}).write_text('ready', encoding='utf-8'); "
			"time.sleep(0.8); "
			f"Path({str(cancel_marker_path)!r}).write_text('survived', encoding='utf-8')"
		)
		cancel_parent_code = (
			"import subprocess, sys, time; "
			f"subprocess.Popen([sys.executable, '-c', {cancel_grandchild_code!r}]); "
			"time.sleep(30.0)"
		)
		running_cancel_event = threading.Event()

		def cancel_when_grandchild_is_ready() -> None:
			ready_deadline = time.monotonic() + 5.0
			while not cancel_ready_path.exists() and time.monotonic() < ready_deadline:
				time.sleep(0.01)
			if cancel_ready_path.exists():
				running_cancel_event.set()

		cancel_thread = threading.Thread(
			target=cancel_when_grandchild_is_ready,
			name="gf-self-test-cancel-when-ready",
			daemon=True,
		)
		cancel_thread.start()
		try:
			running_cancel_result = run_supervised_process(
				[sys.executable, "-c", cancel_parent_code],
				cwd=ROOT,
				timeout_seconds=10,
				cancellation_event=running_cancel_event,
			)
		finally:
			cancel_thread.join()
		time.sleep(1.0)
		record_result(
			"run_command_cancellation_is_structured_and_terminates_descendants",
			pre_cancelled_result.cancelled
			and not pre_cancelled_result.timed_out
			and pre_cancelled_result.pid == 0
			and pre_cancelled_result.process_boundary_quiescent
			and running_cancel_result.cancelled
			and not running_cancel_result.timed_out
			and running_cancel_result.pid > 0
			and running_cancel_result.process_boundary_quiescent
			and cancel_ready_path.exists()
			and not cancel_marker_path.exists(),
			"Pre-start and ready-synchronized running cancellation must remain distinct from timeout "
			"and clean descendant processes.",
		)
		interrupt_ready_path = Path(temp_dir) / "grandchild-ready-interrupt.txt"
		interrupt_marker_path = Path(temp_dir) / "grandchild-survived-interrupt.txt"
		interrupt_grandchild_code = (
			"import time; from pathlib import Path; "
			f"Path({str(interrupt_ready_path)!r}).write_text('ready', encoding='utf-8'); "
			"time.sleep(0.6); "
			f"Path({str(interrupt_marker_path)!r}).write_text('survived', encoding='utf-8')"
		)
		interrupt_parent_code = (
			"import subprocess, sys, time; "
			f"subprocess.Popen([sys.executable, '-c', {interrupt_grandchild_code!r}]); "
			"time.sleep(30.0)"
		)
		interrupted = False

		def interrupt_heartbeat(_elapsed: float, _pid: int) -> None:
			if interrupt_ready_path.exists():
				raise KeyboardInterrupt

		try:
			run_supervised_process(
				[sys.executable, "-c", interrupt_parent_code],
				cwd=ROOT,
				timeout_seconds=10,
				heartbeat_callback=interrupt_heartbeat,
				heartbeat_interval_seconds=0.05,
			)
		except KeyboardInterrupt:
			interrupted = True
		time.sleep(0.8)
		record_result(
			"run_command_interrupt_terminates_descendant_processes",
			interrupted
			and interrupt_ready_path.exists()
			and not interrupt_marker_path.exists(),
			"Interrupted checks must wait for grandchild readiness, then terminate their complete descendant "
			"process tree before propagating the interrupt.",
		)
		streamed_events: list[tuple[str, str]] = []
		stream_fixture = (
			"import sys, time; "
			"print('first-progress', flush=True); "
			"print('diagnostic-progress', file=sys.stderr, flush=True); "
			"time.sleep(0.05); "
			"print('last-progress', flush=True)"
		)
		stream_result = run_command(
			"stream_output_fixture",
			[sys.executable, "-c", stream_fixture],
			10,
			lambda _name, stream, text: streamed_events.append((stream, text.strip())),
		)
		record_result(
			"run_command_streams_stdout_and_stderr_while_preserving_capture",
			stream_result.exit_code == 0
			and stream_result.streamed_output
			and ("stdout", "first-progress") in streamed_events
			and ("stderr", "diagnostic-progress") in streamed_events
			and "last-progress" in stream_result.stdout,
			f"human-mode streaming must retain complete structured output: {streamed_events}",
		)
		orphan_marker_path = Path(temp_dir) / "background-descendant-survived.txt"
		orphan_grandchild_code = (
			"import time; from pathlib import Path; "
			"time.sleep(5.0); "
			f"Path({str(orphan_marker_path)!r}).write_text('survived', encoding='utf-8')"
		)
		orphan_parent_code = (
			"import subprocess, sys; "
			f"subprocess.Popen([sys.executable, '-c', {orphan_grandchild_code!r}], "
			"stdout=sys.stdout, stderr=sys.stderr, close_fds=False)"
		)
		orphan_result = run_supervised_process(
			[sys.executable, "-c", orphan_parent_code],
			cwd=ROOT,
			timeout_seconds=10,
		)
		time.sleep(4.2)
		record_result(
			"run_command_rejects_background_descendants_holding_output_pipes",
			orphan_result.timed_out
			and orphan_result.process_boundary_quiescent
			and not orphan_marker_path.exists()
			and any("Output pipes remained open" in note for note in orphan_result.notes),
			f"checks must fail and clean descendants that outlive the direct child: {orphan_result}",
		)
		detached_ready_path = Path(temp_dir) / "detached-background-descendant-ready.txt"
		detached_marker_path = Path(temp_dir) / "detached-background-descendant-survived.txt"
		detached_grandchild_code = (
			"import time; from pathlib import Path; "
			f"Path({str(detached_ready_path)!r}).write_text('ready', encoding='utf-8'); "
			"time.sleep(0.6); "
			f"Path({str(detached_marker_path)!r}).write_text('survived', encoding='utf-8')"
		)
		detached_parent_code = "\n".join([
			"import subprocess, sys, time",
			"from pathlib import Path",
			(
				f"subprocess.Popen([sys.executable, '-c', {detached_grandchild_code!r}], "
				"stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, close_fds=True)"
			),
			"deadline = time.monotonic() + 5.0",
			f"ready = Path({str(detached_ready_path)!r})",
			"while not ready.exists() and time.monotonic() < deadline:",
			"\ttime.sleep(0.01)",
			"raise SystemExit(0 if ready.exists() else 2)",
		])
		detached_result = run_supervised_process(
			[sys.executable, "-c", detached_parent_code],
			cwd=ROOT,
			timeout_seconds=10,
		)
		time.sleep(0.8)
		record_result(
			"run_command_cleans_detached_descendants_after_normal_exit",
			detached_result.return_code == 0
			and not detached_result.timed_out
			and not detached_result.cancelled
			and detached_ready_path.exists()
			and not detached_marker_path.exists(),
			"A successful direct child must not let DEVNULL background descendants escape its owned process tree: "
			f"{detached_result}.",
		)

		linux_proc_fixture_root = Path(temp_dir) / "linux-proc-fixture"
		linux_proc_fixture_root.mkdir()

		def write_linux_proc_stat(
			process_id: int,
			process_state: str,
			process_group_id: int,
			*,
			thread_count: int = 1,
		) -> None:
			process_root = linux_proc_fixture_root / str(process_id)
			process_root.mkdir()
			stat_fields = [
				process_state,
				"1",
				str(process_group_id),
				"1",
				"0",
				"-1",
				"0",
				"0",
				"0",
				"0",
				"0",
				"0",
				"0",
				"0",
				"0",
				"20",
				"0",
				str(thread_count),
			]
			(process_root / "stat").write_bytes(
				f"{process_id} (fixture) worker) {' '.join(stat_fields)}\n".encode("ascii")
			)

		terminated_process_group_id = 43100
		live_process_group_id = 43101
		multithreaded_terminal_group_id = 43103
		write_linux_proc_stat(43110, "Z", terminated_process_group_id)
		write_linux_proc_stat(43111, "X", terminated_process_group_id)
		write_linux_proc_stat(43112, "x", terminated_process_group_id)
		write_linux_proc_stat(43113, "S", live_process_group_id)
		write_linux_proc_stat(43114, "R", 43199)
		write_linux_proc_stat(43118, "S", 0)
		write_linux_proc_stat(
			43116,
			"Z",
			multithreaded_terminal_group_id,
			thread_count=2,
		)
		(linux_proc_fixture_root / "43117").mkdir()
		terminated_process_group_state = (
			gf_process_supervisor._linux_process_group_cleanup_state(
				terminated_process_group_id,
				proc_root=linux_proc_fixture_root,
			)
		)
		live_process_group_state = gf_process_supervisor._linux_process_group_cleanup_state(
			live_process_group_id,
			proc_root=linux_proc_fixture_root,
		)
		absent_process_group_state = gf_process_supervisor._linux_process_group_cleanup_state(
			43102,
			proc_root=linux_proc_fixture_root,
		)
		multithreaded_terminal_group_state = (
			gf_process_supervisor._linux_process_group_cleanup_state(
				multithreaded_terminal_group_id,
				proc_root=linux_proc_fixture_root,
			)
		)
		expired_process_group_state = gf_process_supervisor._linux_process_group_cleanup_state(
			terminated_process_group_id,
			proc_root=linux_proc_fixture_root,
			scan_deadline=time.perf_counter() - 1.0,
		)
		malformed_process_root = linux_proc_fixture_root / "43115"
		malformed_process_root.mkdir()
		(malformed_process_root / "stat").write_bytes(b"malformed proc stat")
		unavailable_process_group_state = (
			gf_process_supervisor._linux_process_group_cleanup_state(
				terminated_process_group_id,
				proc_root=linux_proc_fixture_root,
			)
		)
		(malformed_process_root / "stat").write_bytes(
			b"x" * (gf_process_supervisor.LINUX_PROC_STAT_MAX_BYTES + 1)
		)
		oversized_process_group_state = (
			gf_process_supervisor._linux_process_group_cleanup_state(
				terminated_process_group_id,
				proc_root=linux_proc_fixture_root,
			)
		)
		record_result(
			"linux_process_group_cleanup_state_is_terminal_only_and_fail_closed",
			terminated_process_group_state
			== gf_process_supervisor._LINUX_PROCESS_GROUP_TERMINATED
			and live_process_group_state == gf_process_supervisor._LINUX_PROCESS_GROUP_LIVE
			and absent_process_group_state == gf_process_supervisor._LINUX_PROCESS_GROUP_ABSENT
			and multithreaded_terminal_group_state
			== gf_process_supervisor._LINUX_PROCESS_GROUP_LIVE
			and expired_process_group_state is None
			and unavailable_process_group_state is None
			and oversized_process_group_state is None,
			"Linux process-group confirmation must distinguish absent, terminal-only, live, "
			"multithreaded, expired, and uninspectable procfs snapshots.",
		)

		def run_posix_cleanup_confirmation_fixture(
			cleanup_state: str | None,
			*,
			cleanup_state_sequence: tuple[str | None, ...] = (),
			cleanup_grace_seconds: float = 0.0,
			prior_cleanup_failure: bool = False,
			probe_error: str = "",
		) -> dict[str, Any]:
			owner = object.__new__(gf_process_supervisor._PosixProcessGroupOwner)
			gf_process_supervisor._ProcessTreeOwner.__init__(owner)
			owner.cleanup_failed = prior_cleanup_failure
			owner.process_group_id = 43200
			owner._cleanup_probe_group_id = 0
			original_linux_cleanup_state = (
				gf_process_supervisor._linux_process_group_cleanup_state
			)
			original_cleanup_grace = gf_process_supervisor.OUTPUT_CLEANUP_GRACE_SECONDS
			original_supervisor_time = gf_process_supervisor.time
			had_killpg = hasattr(gf_process_supervisor.os, "killpg")
			original_killpg = getattr(gf_process_supervisor.os, "killpg", None)
			probe_calls: list[tuple[int, int]] = []
			cleanup_state_calls: list[int] = []

			class InjectedCleanupClock:
				def __init__(self) -> None:
					self.now = 0.0

				def perf_counter(self) -> float:
					return self.now

				def sleep(self, seconds: float) -> None:
					self.now += max(0.0, seconds)

			injected_cleanup_clock = InjectedCleanupClock()

			def report_injected_cleanup_state(injected_process_group_id: int) -> str | None:
				cleanup_state_calls.append(injected_process_group_id)
				if cleanup_state_sequence:
					state_index = min(
						len(cleanup_state_calls) - 1,
						len(cleanup_state_sequence) - 1,
					)
					return cleanup_state_sequence[state_index]
				return cleanup_state

			def probe_injected_process_group(
				injected_process_group_id: int,
				signal_number: int,
			) -> None:
				probe_calls.append((injected_process_group_id, signal_number))
				if probe_error == "missing":
					raise ProcessLookupError("fixture process group disappeared")
				if probe_error == "permission":
					raise PermissionError("fixture process group permission denied")

			try:
				setattr(
					gf_process_supervisor.os,
					"killpg",
					probe_injected_process_group,
				)
				gf_process_supervisor._linux_process_group_cleanup_state = (
					report_injected_cleanup_state
				)
				gf_process_supervisor.OUTPUT_CLEANUP_GRACE_SECONDS = cleanup_grace_seconds
				gf_process_supervisor.time = injected_cleanup_clock
				confirmation_notes = owner.confirm_cleanup_after_reap()
			finally:
				gf_process_supervisor.time = original_supervisor_time
				gf_process_supervisor.OUTPUT_CLEANUP_GRACE_SECONDS = original_cleanup_grace
				gf_process_supervisor._linux_process_group_cleanup_state = (
					original_linux_cleanup_state
				)
				if had_killpg:
					setattr(gf_process_supervisor.os, "killpg", original_killpg)
				else:
					delattr(gf_process_supervisor.os, "killpg")
			return {
				"cleanup_failed": owner.cleanup_failed,
				"confirmation_succeeded": owner.cleanup_confirmation_succeeded(),
				"probe_group_id": owner._cleanup_probe_group_id,
				"notes": confirmation_notes,
				"probe_calls": probe_calls,
				"cleanup_state_calls": cleanup_state_calls,
			}

		terminated_confirmation = run_posix_cleanup_confirmation_fixture(
			gf_process_supervisor._LINUX_PROCESS_GROUP_TERMINATED
		)
		absent_confirmation = run_posix_cleanup_confirmation_fixture(
			gf_process_supervisor._LINUX_PROCESS_GROUP_ABSENT
		)
		live_confirmation = run_posix_cleanup_confirmation_fixture(
			gf_process_supervisor._LINUX_PROCESS_GROUP_LIVE
		)
		unavailable_confirmation = run_posix_cleanup_confirmation_fixture(None)
		transitioning_confirmation = run_posix_cleanup_confirmation_fixture(
			gf_process_supervisor._LINUX_PROCESS_GROUP_LIVE,
			cleanup_state_sequence=(
				gf_process_supervisor._LINUX_PROCESS_GROUP_LIVE,
				gf_process_supervisor._LINUX_PROCESS_GROUP_TERMINATED,
			),
			cleanup_grace_seconds=0.05,
		)
		sticky_failure_confirmation = run_posix_cleanup_confirmation_fixture(
			gf_process_supervisor._LINUX_PROCESS_GROUP_TERMINATED,
			prior_cleanup_failure=True,
		)
		missing_confirmation = run_posix_cleanup_confirmation_fixture(
			None,
			probe_error="missing",
		)
		permission_confirmation = run_posix_cleanup_confirmation_fixture(
			gf_process_supervisor._LINUX_PROCESS_GROUP_TERMINATED,
			probe_error="permission",
		)
		record_result(
			"posix_cleanup_confirmation_accepts_only_absent_or_terminal_groups",
			terminated_confirmation["confirmation_succeeded"]
			and not terminated_confirmation["cleanup_failed"]
			and terminated_confirmation["probe_group_id"] == 0
			and any(
				"terminated" in note
				for note in terminated_confirmation["notes"]
			)
			and absent_confirmation["confirmation_succeeded"]
			and not absent_confirmation["cleanup_failed"]
			and absent_confirmation["probe_group_id"] == 0
			and not absent_confirmation["notes"]
			and not live_confirmation["confirmation_succeeded"]
			and live_confirmation["cleanup_failed"]
			and live_confirmation["probe_group_id"] == 43200
			and any("non-terminal" in note for note in live_confirmation["notes"])
			and not unavailable_confirmation["confirmation_succeeded"]
			and unavailable_confirmation["cleanup_failed"]
			and unavailable_confirmation["probe_group_id"] == 43200
			and transitioning_confirmation["confirmation_succeeded"]
			and not transitioning_confirmation["cleanup_failed"]
			and transitioning_confirmation["probe_group_id"] == 0
			and len(transitioning_confirmation["cleanup_state_calls"]) == 2
			and sticky_failure_confirmation["confirmation_succeeded"]
			and sticky_failure_confirmation["cleanup_failed"]
			and missing_confirmation["confirmation_succeeded"]
			and not missing_confirmation["cleanup_failed"]
			and missing_confirmation["probe_group_id"] == 0
			and not missing_confirmation["cleanup_state_calls"]
			and not permission_confirmation["confirmation_succeeded"]
			and permission_confirmation["cleanup_failed"]
			and permission_confirmation["probe_group_id"] == 43200
			and not permission_confirmation["cleanup_state_calls"]
			and all(
				signal_number == 0
				for confirmation in (
					terminated_confirmation,
					absent_confirmation,
					live_confirmation,
					unavailable_confirmation,
					transitioning_confirmation,
					sticky_failure_confirmation,
					missing_confirmation,
					permission_confirmation,
				)
				for _process_group_id, signal_number in confirmation["probe_calls"]
			),
			"Post-reap POSIX confirmation may accept absent or terminal-only groups without "
			"clearing any earlier cleanup failure; live, uninspectable, and permission-denied "
			"groups must still fail, a live-to-terminal transition must be retried, and "
			"post-reap probes must remain signal zero.",
		)

		original_supervision_checkpoint = gf_process_supervisor._process_supervision_checkpoint
		original_supervisor_popen = gf_process_supervisor.subprocess.Popen

		platform_startup_checkpoints = (
			["windows_process_started", "windows_process_assigned"]
			if os.name == "nt"
			else ["posix_process_started"]
		)
		startup_fault_checkpoints = platform_startup_checkpoints + ["process_owner_started"]

		def run_startup_interrupt_fixture(target_checkpoint: str) -> dict[str, Any]:
			marker_path = Path(temp_dir) / f"startup-{target_checkpoint}-survived.txt"
			process_code = (
				"import time; from pathlib import Path; "
				"time.sleep(0.8); "
				f"Path({str(marker_path)!r}).write_text('survived', encoding='utf-8')"
			)
			checkpoint_names: list[str] = []
			processes: list[subprocess.Popen[str]] = []
			interrupt_raised = False
			interrupted = False

			def capture_startup_process(*args: Any, **kwargs: Any) -> subprocess.Popen[str]:
				process = original_supervisor_popen(*args, **kwargs)
				processes.append(process)
				return process

			def interrupt_started_process(checkpoint_name: str) -> None:
				nonlocal interrupt_raised
				if checkpoint_name in startup_fault_checkpoints:
					checkpoint_names.append(checkpoint_name)
				if checkpoint_name == target_checkpoint and not interrupt_raised:
					interrupt_raised = True
					raise KeyboardInterrupt("startup checkpoint fixture")
				original_supervision_checkpoint(checkpoint_name)

			try:
				gf_process_supervisor.subprocess.Popen = capture_startup_process
				gf_process_supervisor._process_supervision_checkpoint = interrupt_started_process
				try:
					run_supervised_process(
						[sys.executable, "-c", process_code],
						cwd=ROOT,
						timeout_seconds=10,
					)
				except KeyboardInterrupt:
					interrupted = True
			finally:
				gf_process_supervisor._process_supervision_checkpoint = original_supervision_checkpoint
				gf_process_supervisor.subprocess.Popen = original_supervisor_popen

			process_reaped = False
			process_pipes_closed = False
			if len(processes) == 1:
				process = processes[0]
				process_reaped = process.returncode is not None
				process_pipes_closed = (
					(process.stdout is None or process.stdout.closed)
					and (process.stderr is None or process.stderr.closed)
				)
				if not process_reaped:
					try:
						process.kill()
						process.wait(timeout=2.0)
					except (OSError, subprocess.TimeoutExpired):
						pass
			return {
				"target": target_checkpoint,
				"interrupt_raised": interrupt_raised,
				"interrupted": interrupted,
				"checkpoints": checkpoint_names,
				"expected_checkpoints": startup_fault_checkpoints[
					:startup_fault_checkpoints.index(target_checkpoint) + 1
				],
				"process_count": len(processes),
				"process_reaped": process_reaped,
				"process_pipes_closed": process_pipes_closed,
				"marker_exists": marker_path.exists(),
			}

		startup_fixture_results = [
			run_startup_interrupt_fixture(checkpoint_name)
			for checkpoint_name in startup_fault_checkpoints
		]
		record_result(
			"run_command_startup_interrupt_reaps_started_process",
			all(
				fixture["interrupt_raised"]
				and fixture["interrupted"]
				and fixture["checkpoints"] == fixture["expected_checkpoints"]
				and fixture["process_count"] == 1
				and fixture["process_reaped"]
				and fixture["process_pipes_closed"]
				and not fixture["marker_exists"]
				for fixture in startup_fixture_results
			),
			"A BaseException at every startup ownership boundary must reap the actual process without escape: "
			f"{startup_fixture_results}.",
		)

		def run_windows_unassigned_startup_retry_fixture() -> dict[str, Any]:
			state: dict[str, Any] = {
				"interrupt_raised": False,
				"interrupted": False,
				"same_exception": False,
				"kill_calls": 0,
				"injected_kill_failures": 0,
				"outer_terminate_calls": 0,
				"retained_on_outer_terminate": [],
				"process_reaped_before_fixture_cleanup": False,
				"pipes_closed_before_fixture_cleanup": False,
				"owner_closed": False,
				"owner_cleanup_failed": False,
				"owner_released_reaped_process": False,
				"marker_exists": False,
				"fixture_cleanup_error": "",
				"error": "",
			}
			if os.name != "nt":
				return state

			marker_path = Path(temp_dir) / "windows-unassigned-startup-retry-survived.txt"
			process_code = (
				"import time; from pathlib import Path; "
				f"Path({str(marker_path)!r}).write_text('survived', encoding='utf-8'); "
				"time.sleep(10.0)"
			)
			original_owner_factory = gf_process_supervisor._new_process_tree_owner
			process: subprocess.Popen[str] | None = None
			owner: Any | None = None
			original_process_kill: Any = None
			injected_interrupt = KeyboardInterrupt(
				"Windows unassigned startup retry fixture"
			)

			def capture_owner() -> Any:
				nonlocal owner
				owner = original_owner_factory()
				original_terminate = owner.terminate

				def track_outer_termination(
					target_process: subprocess.Popen[str],
				) -> list[str]:
					state["outer_terminate_calls"] += 1
					state["retained_on_outer_terminate"].append(
						owner._started_process is target_process
					)
					return original_terminate(target_process)

				owner.terminate = track_outer_termination
				return owner

			def capture_process(*args: Any, **kwargs: Any) -> subprocess.Popen[str]:
				nonlocal process
				nonlocal original_process_kill
				process = original_supervisor_popen(*args, **kwargs)
				original_process_kill = process.kill

				def fail_two_local_kills() -> None:
					state["kill_calls"] += 1
					if state["kill_calls"] <= 2:
						state["injected_kill_failures"] += 1
						raise OSError("fixture rejected local suspended-child kill")
					original_process_kill()

				process.kill = fail_two_local_kills
				return process

			def interrupt_before_job_assignment(checkpoint_name: str) -> None:
				if checkpoint_name == "windows_process_started" and not state["interrupt_raised"]:
					state["interrupt_raised"] = True
					raise injected_interrupt
				original_supervision_checkpoint(checkpoint_name)

			try:
				gf_process_supervisor._new_process_tree_owner = capture_owner
				gf_process_supervisor.subprocess.Popen = capture_process
				gf_process_supervisor._process_supervision_checkpoint = (
					interrupt_before_job_assignment
				)
				try:
					run_supervised_process(
						[sys.executable, "-c", process_code],
						cwd=ROOT,
						timeout_seconds=10,
					)
				except KeyboardInterrupt as error:
					state["interrupted"] = True
					state["same_exception"] = error is injected_interrupt
				except BaseException as error:
					state["error"] = f"{type(error).__name__}: {error}"
			finally:
				gf_process_supervisor._process_supervision_checkpoint = (
					original_supervision_checkpoint
				)
				gf_process_supervisor.subprocess.Popen = original_supervisor_popen
				gf_process_supervisor._new_process_tree_owner = original_owner_factory
				if process is not None and original_process_kill is not None:
					process.kill = original_process_kill

			if process is not None:
				state["process_reaped_before_fixture_cleanup"] = process.returncode is not None
				state["pipes_closed_before_fixture_cleanup"] = (
					(process.stdout is None or process.stdout.closed)
					and (process.stderr is None or process.stderr.closed)
				)
			if owner is not None:
				state["owner_closed"] = owner.is_closed()
				state["owner_cleanup_failed"] = owner.cleanup_failed
				state["owner_released_reaped_process"] = owner._started_process is None
			state["marker_exists"] = marker_path.exists()

			if process is not None and process.returncode is None:
				try:
					original_process_kill()
					process.wait(timeout=2.0)
				except (OSError, subprocess.TimeoutExpired) as error:
					state["fixture_cleanup_error"] = f"{type(error).__name__}: {error}"
			if process is not None:
				gf_process_supervisor._close_process_pipes(process)
			return state

		windows_unassigned_startup_retry_state = (
			run_windows_unassigned_startup_retry_fixture()
		)
		record_result(
			"windows_unassigned_startup_failure_retains_process_for_outer_retry",
			os.name != "nt"
			or (
				not windows_unassigned_startup_retry_state["error"]
				and not windows_unassigned_startup_retry_state["fixture_cleanup_error"]
				and windows_unassigned_startup_retry_state["interrupt_raised"]
				and windows_unassigned_startup_retry_state["interrupted"]
				and windows_unassigned_startup_retry_state["same_exception"]
				and windows_unassigned_startup_retry_state["kill_calls"] == 3
				and windows_unassigned_startup_retry_state["injected_kill_failures"] == 2
				and windows_unassigned_startup_retry_state["outer_terminate_calls"] >= 2
				and all(windows_unassigned_startup_retry_state["retained_on_outer_terminate"])
				and windows_unassigned_startup_retry_state["process_reaped_before_fixture_cleanup"]
				and windows_unassigned_startup_retry_state["pipes_closed_before_fixture_cleanup"]
				and windows_unassigned_startup_retry_state["owner_closed"]
				and windows_unassigned_startup_retry_state["owner_cleanup_failed"]
				and windows_unassigned_startup_retry_state["owner_released_reaped_process"]
				and not windows_unassigned_startup_retry_state["marker_exists"]
			),
			"A suspended Windows child whose two local startup kill/reap attempts fail must remain published "
			"to the outer cleanup chain until its third real kill is reaped; "
			f"state={windows_unassigned_startup_retry_state}.",
		)

		cleanup_ready_path = Path(temp_dir) / "cleanup-interrupt-descendant-ready.txt"
		cleanup_marker_path = Path(temp_dir) / "cleanup-interrupt-descendant-survived.txt"
		cleanup_grandchild_code = (
			"import time; from pathlib import Path; "
			f"Path({str(cleanup_ready_path)!r}).write_text('ready', encoding='utf-8'); "
			"time.sleep(1.5); "
			f"Path({str(cleanup_marker_path)!r}).write_text('survived', encoding='utf-8')"
		)
		cleanup_parent_code = "\n".join([
			"import subprocess, sys, time",
			"from pathlib import Path",
			(
				f"subprocess.Popen([sys.executable, '-c', {cleanup_grandchild_code!r}], "
				"stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, close_fds=True)"
			),
			f"ready = Path({str(cleanup_ready_path)!r})",
			"deadline = time.monotonic() + 5.0",
			"while not ready.exists() and time.monotonic() < deadline:",
			"\ttime.sleep(0.01)",
			"raise SystemExit(0 if ready.exists() else 2)",
		])
		cleanup_checkpoint_names: list[str] = []
		cleanup_action_names: list[str] = []
		cleanup_interrupt_raised = False
		cleanup_interrupted = False
		original_owner_factory = gf_process_supervisor._new_process_tree_owner
		original_terminate_process_tree = gf_process_supervisor.terminate_process_tree
		original_reap_direct_process = gf_process_supervisor.reap_direct_process

		def interrupt_cleanup_checkpoint(checkpoint_name: str) -> None:
			nonlocal cleanup_interrupt_raised
			cleanup_checkpoint_names.append(checkpoint_name)
			if checkpoint_name == "before_output_drain" and not cleanup_interrupt_raised:
				cleanup_interrupt_raised = True
				raise KeyboardInterrupt("cleanup checkpoint fixture")
			original_supervision_checkpoint(checkpoint_name)

		def instrument_cleanup_owner() -> Any:
			owner = original_owner_factory()
			original_confirm_cleanup = owner.confirm_cleanup_after_reap
			original_owner_close = owner.close

			def tracked_confirm_cleanup() -> list[str]:
				cleanup_action_names.append("confirm")
				return original_confirm_cleanup()

			def tracked_owner_close() -> list[str]:
				cleanup_action_names.append("close")
				return original_owner_close()

			owner.confirm_cleanup_after_reap = tracked_confirm_cleanup
			owner.close = tracked_owner_close
			return owner

		def tracked_terminate_process_tree(process: subprocess.Popen[str]) -> list[str]:
			cleanup_action_names.append("terminate")
			return original_terminate_process_tree(process)

		def tracked_reap_direct_process(
			process: subprocess.Popen[str],
			notes: list[str],
		) -> None:
			cleanup_action_names.append("reap")
			original_reap_direct_process(process, notes)

		try:
			gf_process_supervisor._process_supervision_checkpoint = interrupt_cleanup_checkpoint
			gf_process_supervisor._new_process_tree_owner = instrument_cleanup_owner
			gf_process_supervisor.terminate_process_tree = tracked_terminate_process_tree
			gf_process_supervisor.reap_direct_process = tracked_reap_direct_process
			try:
				run_supervised_process(
					[sys.executable, "-c", cleanup_parent_code],
					cwd=ROOT,
					timeout_seconds=10,
				)
			except KeyboardInterrupt:
				cleanup_interrupted = True
		finally:
			gf_process_supervisor.reap_direct_process = original_reap_direct_process
			gf_process_supervisor.terminate_process_tree = original_terminate_process_tree
			gf_process_supervisor._new_process_tree_owner = original_owner_factory
			gf_process_supervisor._process_supervision_checkpoint = original_supervision_checkpoint
		time.sleep(1.7)
		expected_cleanup_checkpoints = (
			["windows_process_started", "windows_process_assigned"]
			if os.name == "nt"
			else ["posix_process_started"]
		) + [
			"process_owner_started",
			"before_output_drain",
			"before_final_termination",
			"before_direct_reap",
			"before_cleanup_confirmation",
			"before_owner_close",
		]
		expected_cleanup_actions = ["terminate", "reap", "confirm", "close"]
		if os.name == "nt":
			# Successful Job close is also the last-resort tree boundary. The
			# supervisor performs one post-close reap before closing the pipes even
			# when the earlier direct reap already observed the short-lived parent.
			expected_cleanup_actions.append("reap")
		record_result(
			"run_command_cleanup_interrupt_runs_remaining_owner_steps",
			cleanup_interrupt_raised
			and cleanup_interrupted
			and cleanup_ready_path.exists()
			and not cleanup_marker_path.exists()
			and cleanup_checkpoint_names == expected_cleanup_checkpoints
			and cleanup_action_names == expected_cleanup_actions,
			"A cleanup-boundary BaseException must preserve the first error only after terminate/reap/confirm/close "
			f"kill a ready DEVNULL descendant: checkpoints={cleanup_checkpoint_names}, "
			f"actions={cleanup_action_names}.",
		)

		persistent_failure_ready_path = Path(temp_dir) / "persistent-termination-ready.txt"
		persistent_failure_release_path = Path(temp_dir) / "persistent-termination-release.txt"
		persistent_failure_process_code = "\n".join([
			"import time",
			"from pathlib import Path",
			f"ready = Path({str(persistent_failure_ready_path)!r})",
			f"release = Path({str(persistent_failure_release_path)!r})",
			"ready.write_text('ready', encoding='utf-8')",
			"deadline = time.monotonic() + 10.0",
			"while not release.exists() and time.monotonic() < deadline:",
			"\ttime.sleep(0.01)",
		])
		persistent_failure_original_owner_factory = gf_process_supervisor._new_process_tree_owner
		persistent_failure_original_drain_grace = gf_process_supervisor.OUTPUT_DRAIN_GRACE_SECONDS
		persistent_failure_original_cleanup_grace = gf_process_supervisor.OUTPUT_CLEANUP_GRACE_SECONDS
		persistent_failure_owner: Any | None = None
		persistent_failure_process: subprocess.Popen[str] | None = None
		persistent_failure_terminate_calls = 0
		persistent_failure_result: Any | None = None
		persistent_failure_error = ""
		persistent_failure_elapsed = 0.0
		persistent_failure_safety_fired = False
		persistent_failure_safety_cancel = threading.Event()
		persistent_failure_safety_seconds = 2.0

		def instrument_persistent_failure_owner() -> Any:
			nonlocal persistent_failure_owner
			nonlocal persistent_failure_process
			nonlocal persistent_failure_terminate_calls
			owner = persistent_failure_original_owner_factory()
			persistent_failure_owner = owner
			original_owner_start = owner.start

			def capture_persistent_failure_process(
				command: list[str],
				*,
				cwd: Path,
				environment: dict[str, str] | None,
			) -> subprocess.Popen[str]:
				nonlocal persistent_failure_process
				process = original_owner_start(command, cwd=cwd, environment=environment)
				persistent_failure_process = process
				return process

			def reject_persistent_termination(_process: subprocess.Popen[str]) -> list[str]:
				nonlocal persistent_failure_terminate_calls
				persistent_failure_terminate_calls += 1
				owner.cleanup_failed = True
				owner._termination_succeeded = False
				return ["Fixture intentionally rejected process-tree termination."]

			owner.start = capture_persistent_failure_process
			owner.terminate = reject_persistent_termination
			return owner

		def release_persistent_failure_safety() -> None:
			nonlocal persistent_failure_safety_fired
			if persistent_failure_safety_cancel.wait(persistent_failure_safety_seconds):
				return
			persistent_failure_safety_fired = True
			try:
				persistent_failure_release_path.write_text("safety", encoding="utf-8")
			except OSError:
				pass

		persistent_failure_safety_thread = threading.Thread(
			target=release_persistent_failure_safety,
			name="gf-self-test-persistent-termination-safety",
			daemon=True,
		)
		persistent_failure_safety_thread.start()
		persistent_failure_started = time.perf_counter()
		try:
			gf_process_supervisor._new_process_tree_owner = instrument_persistent_failure_owner
			gf_process_supervisor.OUTPUT_DRAIN_GRACE_SECONDS = 0.05
			gf_process_supervisor.OUTPUT_CLEANUP_GRACE_SECONDS = 0.05
			try:
				persistent_failure_result = run_supervised_process(
					[sys.executable, "-c", persistent_failure_process_code],
					cwd=ROOT,
					timeout_seconds=0.5,
				)
			except BaseException as error:
				persistent_failure_error = f"{type(error).__name__}: {error}"
			finally:
				persistent_failure_elapsed = time.perf_counter() - persistent_failure_started
		finally:
			gf_process_supervisor.OUTPUT_CLEANUP_GRACE_SECONDS = persistent_failure_original_cleanup_grace
			gf_process_supervisor.OUTPUT_DRAIN_GRACE_SECONDS = persistent_failure_original_drain_grace
			gf_process_supervisor._new_process_tree_owner = persistent_failure_original_owner_factory
			persistent_failure_safety_cancel.set()
			persistent_failure_release_path.write_text("cleanup", encoding="utf-8")
			persistent_failure_safety_thread.join(timeout=1.0)

		persistent_failure_process_reaped = False
		persistent_failure_pipes_closed = False
		if persistent_failure_process is not None:
			try:
				persistent_failure_process.wait(timeout=2.0)
			except subprocess.TimeoutExpired:
				try:
					persistent_failure_process.kill()
					persistent_failure_process.wait(timeout=2.0)
				except (OSError, subprocess.TimeoutExpired):
					pass
			persistent_failure_process_reaped = persistent_failure_process.returncode is not None
			pipe_close_deadline = time.monotonic() + 0.5
			while (
				(
					(persistent_failure_process.stdout is not None and not persistent_failure_process.stdout.closed)
					or (persistent_failure_process.stderr is not None and not persistent_failure_process.stderr.closed)
				)
				and time.monotonic() < pipe_close_deadline
			):
				time.sleep(0.01)
			for pipe in (persistent_failure_process.stdout, persistent_failure_process.stderr):
				if pipe is not None and not pipe.closed:
					pipe.close()
			persistent_failure_pipes_closed = (
				(persistent_failure_process.stdout is None or persistent_failure_process.stdout.closed)
				and (persistent_failure_process.stderr is None or persistent_failure_process.stderr.closed)
			)
		record_result(
			"run_command_persistent_termination_failure_does_not_block_pipe_close",
			not persistent_failure_error
			and persistent_failure_result is not None
			and persistent_failure_result.timed_out
			and persistent_failure_owner is not None
			and persistent_failure_process is not None
			and persistent_failure_ready_path.exists()
			and persistent_failure_terminate_calls >= 2
			and not persistent_failure_safety_fired
			and persistent_failure_elapsed < persistent_failure_safety_seconds * 0.75
			and persistent_failure_process_reaped
			and persistent_failure_pipes_closed,
			"Repeated process-tree termination failure must return before the safety release instead of blocking "
			"while closing pipes still owned by output pumps; "
			f"calls={persistent_failure_terminate_calls}, elapsed={persistent_failure_elapsed:.3f}s, "
			f"safety_fired={persistent_failure_safety_fired}, reaped={persistent_failure_process_reaped}, "
			f"pipes_closed={persistent_failure_pipes_closed}, error={persistent_failure_error!r}.",
		)

		reap_noop_ready_path = Path(temp_dir) / "reap-noop-ready.txt"
		reap_noop_release_path = Path(temp_dir) / "reap-noop-release.txt"
		reap_noop_process_code = "\n".join([
			"import time",
			"from pathlib import Path",
			f"ready = Path({str(reap_noop_ready_path)!r})",
			f"release = Path({str(reap_noop_release_path)!r})",
			"ready.write_text('ready', encoding='utf-8')",
			"deadline = time.monotonic() + 10.0",
			"while not release.exists() and time.monotonic() < deadline:",
			"\ttime.sleep(0.01)",
		])
		reap_noop_original_owner_factory = gf_process_supervisor._new_process_tree_owner
		reap_noop_original_reap = gf_process_supervisor.reap_direct_process
		reap_noop_original_close_pipes = gf_process_supervisor._close_process_pipes
		reap_noop_original_drain_grace = gf_process_supervisor.OUTPUT_DRAIN_GRACE_SECONDS
		reap_noop_original_cleanup_grace = gf_process_supervisor.OUTPUT_CLEANUP_GRACE_SECONDS
		reap_noop_owner: Any | None = None
		reap_noop_process: subprocess.Popen[str] | None = None
		reap_noop_result: Any | None = None
		reap_noop_error = ""
		reap_noop_cleanup_error = ""
		reap_noop_terminate_calls = 0
		reap_noop_reap_calls = 0
		reap_noop_pipe_close_calls = 0
		reap_noop_pipe_close_attempted_while_live = False
		reap_noop_returned_before_release = False
		reap_noop_elapsed = 0.0
		reap_noop_safety_fired = False
		reap_noop_safety_cancel = threading.Event()
		reap_noop_safety_seconds = 2.0

		def instrument_reap_noop_owner() -> Any:
			nonlocal reap_noop_owner
			nonlocal reap_noop_process
			nonlocal reap_noop_terminate_calls
			owner = reap_noop_original_owner_factory()
			reap_noop_owner = owner
			original_owner_start = owner.start

			def capture_reap_noop_process(
				command: list[str],
				*,
				cwd: Path,
				environment: dict[str, str] | None,
			) -> subprocess.Popen[str]:
				nonlocal reap_noop_process
				process = original_owner_start(command, cwd=cwd, environment=environment)
				reap_noop_process = process
				return process

			def report_termination_without_stopping(
				_process: subprocess.Popen[str],
			) -> list[str]:
				nonlocal reap_noop_terminate_calls
				reap_noop_terminate_calls += 1
				owner._termination_succeeded = True
				return []

			owner.start = capture_reap_noop_process
			owner.terminate = report_termination_without_stopping
			return owner

		def leave_direct_process_unreaped(
			_process: subprocess.Popen[str],
			_notes: list[str],
		) -> None:
			nonlocal reap_noop_reap_calls
			reap_noop_reap_calls += 1

		def observe_reap_noop_pipe_close(process: subprocess.Popen[str]) -> None:
			nonlocal reap_noop_pipe_close_calls
			nonlocal reap_noop_pipe_close_attempted_while_live
			reap_noop_pipe_close_calls += 1
			if process.returncode is None and not reap_noop_release_path.exists():
				reap_noop_pipe_close_attempted_while_live = True
			reap_noop_original_close_pipes(process)

		def release_reap_noop_safety() -> None:
			nonlocal reap_noop_safety_fired
			if reap_noop_safety_cancel.wait(reap_noop_safety_seconds):
				return
			reap_noop_safety_fired = True
			try:
				reap_noop_release_path.write_text("safety", encoding="utf-8")
			except OSError:
				pass

		reap_noop_safety_thread = threading.Thread(
			target=release_reap_noop_safety,
			name="gf-self-test-reap-noop-safety",
			daemon=True,
		)
		reap_noop_safety_thread.start()
		reap_noop_started = time.perf_counter()
		try:
			gf_process_supervisor._new_process_tree_owner = instrument_reap_noop_owner
			gf_process_supervisor.reap_direct_process = leave_direct_process_unreaped
			gf_process_supervisor._close_process_pipes = observe_reap_noop_pipe_close
			gf_process_supervisor.OUTPUT_DRAIN_GRACE_SECONDS = 0.05
			gf_process_supervisor.OUTPUT_CLEANUP_GRACE_SECONDS = 0.05
			try:
				reap_noop_result = run_supervised_process(
					[sys.executable, "-c", reap_noop_process_code],
					cwd=ROOT,
					timeout_seconds=0.5,
				)
			except BaseException as error:
				reap_noop_error = f"{type(error).__name__}: {error}"
			finally:
				reap_noop_elapsed = time.perf_counter() - reap_noop_started
				reap_noop_returned_before_release = not reap_noop_release_path.exists()
		finally:
			gf_process_supervisor.OUTPUT_CLEANUP_GRACE_SECONDS = reap_noop_original_cleanup_grace
			gf_process_supervisor.OUTPUT_DRAIN_GRACE_SECONDS = reap_noop_original_drain_grace
			gf_process_supervisor._close_process_pipes = reap_noop_original_close_pipes
			gf_process_supervisor.reap_direct_process = reap_noop_original_reap
			gf_process_supervisor._new_process_tree_owner = reap_noop_original_owner_factory
			reap_noop_safety_cancel.set()
			try:
				reap_noop_release_path.write_text("cleanup", encoding="utf-8")
			except OSError as error:
				reap_noop_cleanup_error = f"{type(error).__name__}: {error}"
			reap_noop_safety_thread.join(timeout=1.0)

		if reap_noop_owner is not None and not reap_noop_owner.is_closed():
			try:
				reap_noop_owner.close()
			except BaseException as error:
				reap_noop_cleanup_error = (
					reap_noop_cleanup_error
					or f"{type(error).__name__}: {error}"
				)
		reap_noop_process_reaped = False
		reap_noop_pipes_closed = False
		if reap_noop_process is not None:
			try:
				reap_noop_process.wait(timeout=2.0)
			except subprocess.TimeoutExpired:
				try:
					reap_noop_process.kill()
					reap_noop_process.wait(timeout=2.0)
				except (OSError, subprocess.TimeoutExpired) as error:
					reap_noop_cleanup_error = (
						reap_noop_cleanup_error
						or f"{type(error).__name__}: {error}"
					)
			reap_noop_process_reaped = reap_noop_process.returncode is not None
			pipe_close_deadline = time.monotonic() + 0.5
			while (
				(
					(reap_noop_process.stdout is not None and not reap_noop_process.stdout.closed)
					or (reap_noop_process.stderr is not None and not reap_noop_process.stderr.closed)
				)
				and time.monotonic() < pipe_close_deadline
			):
				time.sleep(0.01)
			for pipe in (reap_noop_process.stdout, reap_noop_process.stderr):
				if pipe is not None and not pipe.closed:
					pipe.close()
			reap_noop_pipes_closed = (
				(reap_noop_process.stdout is None or reap_noop_process.stdout.closed)
				and (reap_noop_process.stderr is None or reap_noop_process.stderr.closed)
			)
		record_result(
			"run_command_reap_noop_does_not_close_live_pump_pipes",
			not reap_noop_error
			and not reap_noop_cleanup_error
			and reap_noop_result is not None
			and reap_noop_result.timed_out
			and reap_noop_owner is not None
			and reap_noop_process is not None
			and reap_noop_ready_path.exists()
			and reap_noop_terminate_calls >= 2
			and reap_noop_reap_calls >= 1
			and reap_noop_returned_before_release
			and not reap_noop_safety_fired
			and reap_noop_elapsed < reap_noop_safety_seconds * 0.75
			and not reap_noop_pipe_close_attempted_while_live
			and not reap_noop_safety_thread.is_alive()
			and reap_noop_process_reaped
			and reap_noop_pipes_closed,
			"A successful termination report followed by a no-op reap must return without synchronously closing "
			"pipes still owned by live pumps; "
			f"terminates={reap_noop_terminate_calls}, reaps={reap_noop_reap_calls}, "
			f"pipe_closes={reap_noop_pipe_close_calls}, "
			f"live_close={reap_noop_pipe_close_attempted_while_live}, "
			f"elapsed={reap_noop_elapsed:.3f}s, safety_fired={reap_noop_safety_fired}, "
			f"reaped={reap_noop_process_reaped}, pipes_closed={reap_noop_pipes_closed}, "
			f"error={reap_noop_error!r}, cleanup_error={reap_noop_cleanup_error!r}.",
		)

		terminate_retry_ready_path = Path(temp_dir) / "terminate-retry-descendant-ready.txt"
		terminate_retry_trigger_path = Path(temp_dir) / "terminate-retry-trigger.txt"
		terminate_retry_marker_path = Path(temp_dir) / "terminate-retry-descendant-survived.txt"
		terminate_retry_grandchild_code = "\n".join([
			"import time",
			"from pathlib import Path",
			f"ready = Path({str(terminate_retry_ready_path)!r})",
			f"trigger = Path({str(terminate_retry_trigger_path)!r})",
			f"marker = Path({str(terminate_retry_marker_path)!r})",
			"ready.write_text('ready', encoding='utf-8')",
			"deadline = time.monotonic() + 20.0",
			"while not trigger.exists() and time.monotonic() < deadline:",
			"\ttime.sleep(0.01)",
			"if trigger.exists():",
			"\tmarker.write_text('survived', encoding='utf-8')",
		])
		terminate_retry_parent_code = "\n".join([
			"import subprocess, sys, time",
			"from pathlib import Path",
			(
				f"subprocess.Popen([sys.executable, '-c', {terminate_retry_grandchild_code!r}], "
				"stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, close_fds=True)"
			),
			f"ready = Path({str(terminate_retry_ready_path)!r})",
			"deadline = time.monotonic() + 5.0",
			"while not ready.exists() and time.monotonic() < deadline:",
			"\ttime.sleep(0.01)",
			"raise SystemExit(0 if ready.exists() else 2)",
		])
		terminate_retry_call_count = 0
		terminate_retry_real_call_count = 0
		terminate_retry_reap_started = False
		terminate_retry_real_completed_before_reap = False
		terminate_retry_owner_close_observed = False
		terminate_retry_marker_before_owner_close = False
		terminate_retry_owner: Any | None = None
		terminate_retry_process: subprocess.Popen[str] | None = None
		terminate_retry_error = ""
		terminate_retry_original_owner_factory = gf_process_supervisor._new_process_tree_owner
		terminate_retry_original_reap = gf_process_supervisor.reap_direct_process

		def instrument_terminate_retry_owner() -> Any:
			nonlocal terminate_retry_owner
			owner = terminate_retry_original_owner_factory()
			terminate_retry_owner = owner
			original_owner_terminate = owner.terminate
			original_owner_close = owner.close

			def fail_first_termination(process: subprocess.Popen[str]) -> list[str]:
				nonlocal terminate_retry_call_count
				nonlocal terminate_retry_process
				nonlocal terminate_retry_real_call_count
				nonlocal terminate_retry_real_completed_before_reap
				terminate_retry_call_count += 1
				terminate_retry_process = process
				if terminate_retry_call_count == 1:
					owner.cleanup_failed = True
					return ["Fixture intentionally skipped the first process-tree termination."]
				terminate_retry_real_call_count += 1
				termination_notes = original_owner_terminate(process)
				if not terminate_retry_reap_started and owner.termination_succeeded():
					terminate_retry_real_completed_before_reap = True
				return termination_notes

			def observe_descendant_before_owner_close() -> list[str]:
				nonlocal terminate_retry_owner_close_observed
				nonlocal terminate_retry_marker_before_owner_close
				if not terminate_retry_owner_close_observed:
					terminate_retry_owner_close_observed = True
					terminate_retry_trigger_path.write_text("pre-close-check", encoding="utf-8")
					observation_deadline = time.monotonic() + 1.0
					while (
						not terminate_retry_marker_path.exists()
						and time.monotonic() < observation_deadline
					):
						time.sleep(0.01)
					terminate_retry_marker_before_owner_close = terminate_retry_marker_path.exists()
				return original_owner_close()

			owner.terminate = fail_first_termination
			owner.close = observe_descendant_before_owner_close
			return owner

		def track_terminate_retry_reap(
			process: subprocess.Popen[str],
			notes: list[str],
		) -> None:
			nonlocal terminate_retry_reap_started
			terminate_retry_reap_started = True
			terminate_retry_original_reap(process, notes)

		try:
			gf_process_supervisor._new_process_tree_owner = instrument_terminate_retry_owner
			gf_process_supervisor.reap_direct_process = track_terminate_retry_reap
			try:
				run_supervised_process(
					[sys.executable, "-c", terminate_retry_parent_code],
					cwd=ROOT,
					timeout_seconds=10,
				)
			except BaseException as error:
				terminate_retry_error = f"{type(error).__name__}: {error}"
		finally:
			gf_process_supervisor.reap_direct_process = terminate_retry_original_reap
			gf_process_supervisor._new_process_tree_owner = terminate_retry_original_owner_factory
			if not terminate_retry_trigger_path.exists():
				terminate_retry_trigger_path.write_text("cleanup", encoding="utf-8")
		time.sleep(0.2)
		terminate_retry_process_reaped = (
			terminate_retry_process is not None
			and terminate_retry_process.returncode is not None
		)
		if terminate_retry_process is not None and terminate_retry_process.returncode is None:
			try:
				terminate_retry_process.kill()
				terminate_retry_process.wait(timeout=2.0)
			except (OSError, subprocess.TimeoutExpired):
				pass
		record_result(
			"run_command_retries_failed_tree_termination_before_reap",
			not terminate_retry_error
			and terminate_retry_owner is not None
			and terminate_retry_ready_path.exists()
			and not terminate_retry_marker_path.exists()
			and terminate_retry_call_count >= 2
			and terminate_retry_real_call_count >= 1
			and terminate_retry_real_completed_before_reap
			and terminate_retry_owner_close_observed
			and not terminate_retry_marker_before_owner_close
			and terminate_retry_process_reaped,
			"A reported process-tree termination failure must be retried successfully before the direct child is reaped; "
			f"calls={terminate_retry_call_count}, real_calls={terminate_retry_real_call_count}, "
			f"real_before_reap={terminate_retry_real_completed_before_reap}, "
			f"owner_close={terminate_retry_owner_close_observed}, "
			f"marker_before_close={terminate_retry_marker_before_owner_close}, "
			f"reaped={terminate_retry_process_reaped}, marker={terminate_retry_marker_path.exists()}, "
			f"error={terminate_retry_error!r}.",
		)

		def run_windows_close_handle_interrupt_fixture(mode: str) -> dict[str, Any]:
			state: dict[str, Any] = {
				"mode": mode,
				"owner": None,
				"process": None,
				"result": None,
				"worker_start_attempts": 0,
				"low_level_start_attempts": 0,
				"operations": [],
				"operation_handles": [],
				"owner_handles_at_start": [],
				"wrapper_results": [],
				"native_results": [],
				"worker_thread_names": [],
				"interrupt_injected": False,
				"second_interrupt_injected": False,
				"boundary_after_success": False,
				"interrupted": False,
				"same_exception": False,
				"handle_zero": False,
				"owner_closed": False,
				"process_reaped": False,
				"pipes_closed": False,
				"error": "",
				"cleanup_error": "",
			}
			if os.name != "nt":
				return state

			original_owner_factory = gf_process_supervisor._new_process_tree_owner
			original_popen = gf_process_supervisor.subprocess.Popen
			original_close_handle = gf_process_supervisor._CLOSE_HANDLE
			original_thread_start = gf_process_supervisor.threading.Thread.start
			original_low_level_start = gf_process_supervisor._thread.start_new_thread
			original_wait_for_close_event = gf_process_supervisor._wait_for_windows_close_event
			injected_interrupt = KeyboardInterrupt(f"CloseHandle {mode} fixture")
			second_injected_interrupt = KeyboardInterrupt(
				f"CloseHandle {mode} second fixture"
			)

			def capture_owner() -> Any:
				owner = original_owner_factory()
				state["owner"] = owner
				return owner

			def capture_process(
				*args: Any,
				**kwargs: Any,
			) -> subprocess.Popen[str]:
				process = original_popen(*args, **kwargs)
				state["process"] = process
				return process

			def track_real_close_handle(handle: Any) -> bool:
				if mode == "false_retry" and not state["wrapper_results"]:
					ctypes.set_last_error(6)
					state["wrapper_results"].append(False)
					state["worker_thread_names"].append(threading.current_thread().name)
					return False
				real_result = bool(original_close_handle(handle))
				state["wrapper_results"].append(real_result)
				state["native_results"].append(real_result)
				state["worker_thread_names"].append(threading.current_thread().name)
				return real_result

			def interrupt_first_worker_start(
				worker: threading.Thread,
				*args: Any,
				**kwargs: Any,
			) -> Any:
				if worker.name == "gf-windows-handle-close":
					state["worker_start_attempts"] += 1
					owner = state["owner"]
					operation = owner._close_operation if owner is not None else None
					state["operations"].append(operation)
					state["operation_handles"].append(
						operation.handle if operation is not None else 0
					)
					state["owner_handles_at_start"].append(
						owner.handle if owner is not None else -1
					)
					if mode == "pre_call" and state["worker_start_attempts"] == 1:
						state["interrupt_injected"] = True
						raise injected_interrupt
					if mode == "double_start_failure" and state["worker_start_attempts"] <= 2:
						if state["worker_start_attempts"] == 1:
							state["interrupt_injected"] = True
							raise injected_interrupt
						state["second_interrupt_injected"] = True
						raise second_injected_interrupt
				return original_thread_start(worker, *args, **kwargs)

			def track_low_level_start(
				function: Callable[..., Any],
				args: tuple[Any, ...],
				kwargs: dict[str, Any] | None = None,
			) -> int:
				state["low_level_start_attempts"] += 1
				if kwargs is None:
					return original_low_level_start(function, args)
				return original_low_level_start(function, args, kwargs)

			def interrupt_after_worker_commit(
				event: threading.Event,
				pending_error: BaseException | None,
				pending_traceback: Any,
			) -> tuple[BaseException | None, Any]:
				wait_result = original_wait_for_close_event(
					event,
					pending_error,
					pending_traceback,
				)
				if mode == "post_success" and not state["interrupt_injected"]:
					owner = state["owner"]
					state["boundary_after_success"] = (
						state["wrapper_results"] == [True]
						and state["native_results"] == [True]
						and owner is not None
						and owner.handle == 0
						and owner.is_closed()
					)
					state["interrupt_injected"] = True
					raise injected_interrupt
				return wait_result

			try:
				gf_process_supervisor._new_process_tree_owner = capture_owner
				gf_process_supervisor.subprocess.Popen = capture_process
				gf_process_supervisor._CLOSE_HANDLE = track_real_close_handle
				gf_process_supervisor.threading.Thread.start = interrupt_first_worker_start
				gf_process_supervisor._thread.start_new_thread = track_low_level_start
				gf_process_supervisor._wait_for_windows_close_event = interrupt_after_worker_commit
				try:
					state["result"] = run_supervised_process(
						[sys.executable, "-c", "print('close-handle-fixture', flush=True)"],
						cwd=ROOT,
						timeout_seconds=10,
					)
				except KeyboardInterrupt as error:
					state["interrupted"] = True
					state["same_exception"] = error is injected_interrupt
				except BaseException as error:
					state["error"] = f"{type(error).__name__}: {error}"
			finally:
				gf_process_supervisor._wait_for_windows_close_event = original_wait_for_close_event
				gf_process_supervisor._thread.start_new_thread = original_low_level_start
				gf_process_supervisor.threading.Thread.start = original_thread_start
				gf_process_supervisor._CLOSE_HANDLE = original_close_handle
				gf_process_supervisor.subprocess.Popen = original_popen
				gf_process_supervisor._new_process_tree_owner = original_owner_factory

			owner = state["owner"]
			process = state["process"]
			if owner is not None:
				state["handle_zero"] = owner.handle == 0
				state["owner_closed"] = owner.is_closed()
			if process is not None:
				state["process_reaped"] = process.returncode is not None
				state["pipes_closed"] = (
					(process.stdout is None or process.stdout.closed)
					and (process.stderr is None or process.stderr.closed)
				)

			# Snapshot the supervised outcome first, then release any real resource
			# left behind by a failed fixture without masking the failed assertions.
			if owner is not None and not owner.is_closed():
				try:
					owner.close()
				except BaseException as error:
					state["cleanup_error"] = f"{type(error).__name__}: {error}"
			if process is not None and process.returncode is None:
				try:
					process.wait(timeout=2.0)
				except subprocess.TimeoutExpired:
					try:
						process.kill()
						process.wait(timeout=2.0)
					except (OSError, subprocess.TimeoutExpired) as error:
						state["cleanup_error"] = (
							state["cleanup_error"]
							or f"{type(error).__name__}: {error}"
						)
			if process is not None:
				pipe_close_deadline = time.perf_counter() + 0.5
				while time.perf_counter() < pipe_close_deadline:
					if (
						(process.stdout is None or process.stdout.closed)
						and (process.stderr is None or process.stderr.closed)
					):
						break
					time.sleep(0.01)
				if process.stdout is not None and not process.stdout.closed:
					process.stdout.close()
				if process.stderr is not None and not process.stderr.closed:
					process.stderr.close()
			return state

		windows_pre_call_state = run_windows_close_handle_interrupt_fixture("pre_call")
		record_result(
			"windows_job_closehandle_pre_call_interrupt_retries_safely",
			os.name != "nt"
			or (
				not windows_pre_call_state["error"]
				and not windows_pre_call_state["cleanup_error"]
				and windows_pre_call_state["interrupt_injected"]
				and windows_pre_call_state["interrupted"]
				and windows_pre_call_state["same_exception"]
				and windows_pre_call_state["worker_start_attempts"] == 2
				and windows_pre_call_state["low_level_start_attempts"] == 0
				and len(windows_pre_call_state["operations"]) == 2
				and windows_pre_call_state["operations"][0] is windows_pre_call_state["operations"][1]
				and windows_pre_call_state["operation_handles"][0] != 0
				and windows_pre_call_state["operation_handles"][0] == windows_pre_call_state["operation_handles"][1]
				and windows_pre_call_state["owner_handles_at_start"] == [0, 0]
				and windows_pre_call_state["wrapper_results"] == [True]
				and windows_pre_call_state["native_results"] == [True]
				and windows_pre_call_state["worker_thread_names"] == ["gf-windows-handle-close"]
				and windows_pre_call_state["owner"] is not None
				and windows_pre_call_state["process"] is not None
				and windows_pre_call_state["handle_zero"]
				and windows_pre_call_state["owner_closed"]
				and windows_pre_call_state["process_reaped"]
				and windows_pre_call_state["pipes_closed"]
			),
			"A main-thread interruption before the CloseHandle worker starts must preserve the handle for one safe "
			"emergency retry and propagate the same exception; "
			f"platform={os.name}, starts={windows_pre_call_state['worker_start_attempts']}, "
			f"low_level_starts={windows_pre_call_state['low_level_start_attempts']}, "
			f"operation_handles={windows_pre_call_state['operation_handles']}, "
			f"owner_handles_at_start={windows_pre_call_state['owner_handles_at_start']}, "
			f"wrapper_results={windows_pre_call_state['wrapper_results']}, "
			f"native_results={windows_pre_call_state['native_results']}, "
			f"worker_threads={windows_pre_call_state['worker_thread_names']}, "
			f"interrupted={windows_pre_call_state['interrupted']}, "
			f"same_exception={windows_pre_call_state['same_exception']}, "
			f"handle_zero={windows_pre_call_state['handle_zero']}, "
			f"owner_closed={windows_pre_call_state['owner_closed']}, "
			f"reaped={windows_pre_call_state['process_reaped']}, "
			f"pipes_closed={windows_pre_call_state['pipes_closed']}, "
			f"error={windows_pre_call_state['error']!r}, "
			f"cleanup_error={windows_pre_call_state['cleanup_error']!r}.",
		)

		windows_double_start_state = run_windows_close_handle_interrupt_fixture(
			"double_start_failure"
		)
		record_result(
			"windows_job_closehandle_double_start_failure_uses_single_low_level_fallback",
			os.name != "nt"
			or (
				not windows_double_start_state["error"]
				and not windows_double_start_state["cleanup_error"]
				and windows_double_start_state["interrupt_injected"]
				and windows_double_start_state["second_interrupt_injected"]
				and windows_double_start_state["interrupted"]
				and windows_double_start_state["same_exception"]
				and windows_double_start_state["worker_start_attempts"] == 2
				and windows_double_start_state["low_level_start_attempts"] == 1
				and len(windows_double_start_state["operations"]) == 2
				and windows_double_start_state["operations"][0]
				is windows_double_start_state["operations"][1]
				and windows_double_start_state["operation_handles"][0] != 0
				and windows_double_start_state["operation_handles"][0]
				== windows_double_start_state["operation_handles"][1]
				and windows_double_start_state["owner_handles_at_start"] == [0, 0]
				and windows_double_start_state["wrapper_results"] == [True]
				and windows_double_start_state["native_results"] == [True]
				and len(windows_double_start_state["worker_thread_names"]) == 1
				and windows_double_start_state["owner"] is not None
				and windows_double_start_state["process"] is not None
				and windows_double_start_state["handle_zero"]
				and windows_double_start_state["owner_closed"]
				and windows_double_start_state["process_reaped"]
				and windows_double_start_state["pipes_closed"]
			),
			"Two pre-call Thread.start failures must retain one operation, close its numeric handle exactly once "
			"through the low-level fallback, and propagate the first exception without a stale retry; "
			f"platform={os.name}, starts={windows_double_start_state['worker_start_attempts']}, "
			f"low_level_starts={windows_double_start_state['low_level_start_attempts']}, "
			f"operation_handles={windows_double_start_state['operation_handles']}, "
			f"owner_handles_at_start={windows_double_start_state['owner_handles_at_start']}, "
			f"wrapper_results={windows_double_start_state['wrapper_results']}, "
			f"native_results={windows_double_start_state['native_results']}, "
			f"worker_threads={windows_double_start_state['worker_thread_names']}, "
			f"interrupted={windows_double_start_state['interrupted']}, "
			f"same_exception={windows_double_start_state['same_exception']}, "
			f"handle_zero={windows_double_start_state['handle_zero']}, "
			f"owner_closed={windows_double_start_state['owner_closed']}, "
			f"reaped={windows_double_start_state['process_reaped']}, "
			f"pipes_closed={windows_double_start_state['pipes_closed']}, "
			f"error={windows_double_start_state['error']!r}, "
			f"cleanup_error={windows_double_start_state['cleanup_error']!r}.",
		)

		windows_post_success_state = run_windows_close_handle_interrupt_fixture("post_success")
		record_result(
			"windows_job_closehandle_post_success_interrupt_avoids_stale_retry",
			os.name != "nt"
			or (
				not windows_post_success_state["error"]
				and not windows_post_success_state["cleanup_error"]
				and windows_post_success_state["interrupt_injected"]
				and windows_post_success_state["boundary_after_success"]
				and windows_post_success_state["interrupted"]
				and windows_post_success_state["same_exception"]
				and windows_post_success_state["worker_start_attempts"] == 1
				and windows_post_success_state["low_level_start_attempts"] == 0
				and len(windows_post_success_state["operations"]) == 1
				and windows_post_success_state["operation_handles"][0] != 0
				and windows_post_success_state["owner_handles_at_start"] == [0]
				and windows_post_success_state["wrapper_results"] == [True]
				and windows_post_success_state["native_results"] == [True]
				and windows_post_success_state["worker_thread_names"] == ["gf-windows-handle-close"]
				and windows_post_success_state["owner"] is not None
				and windows_post_success_state["process"] is not None
				and windows_post_success_state["handle_zero"]
				and windows_post_success_state["owner_closed"]
				and windows_post_success_state["process_reaped"]
				and windows_post_success_state["pipes_closed"]
			),
			"A main-thread interruption after successful CloseHandle publication must propagate the same exception "
			"without retrying the consumed numeric handle; "
			f"platform={os.name}, starts={windows_post_success_state['worker_start_attempts']}, "
			f"low_level_starts={windows_post_success_state['low_level_start_attempts']}, "
			f"operation_handles={windows_post_success_state['operation_handles']}, "
			f"owner_handles_at_start={windows_post_success_state['owner_handles_at_start']}, "
			f"wrapper_results={windows_post_success_state['wrapper_results']}, "
			f"native_results={windows_post_success_state['native_results']}, "
			f"worker_threads={windows_post_success_state['worker_thread_names']}, "
			f"boundary_after_success={windows_post_success_state['boundary_after_success']}, "
			f"interrupted={windows_post_success_state['interrupted']}, "
			f"same_exception={windows_post_success_state['same_exception']}, "
			f"handle_zero={windows_post_success_state['handle_zero']}, "
			f"owner_closed={windows_post_success_state['owner_closed']}, "
			f"reaped={windows_post_success_state['process_reaped']}, "
			f"pipes_closed={windows_post_success_state['pipes_closed']}, "
			f"error={windows_post_success_state['error']!r}, "
			f"cleanup_error={windows_post_success_state['cleanup_error']!r}.",
		)

		windows_false_retry_state = run_windows_close_handle_interrupt_fixture("false_retry")
		windows_false_retry_result = windows_false_retry_state["result"]
		record_result(
			"windows_job_closehandle_explicit_false_retries_same_handle_safely",
			os.name != "nt"
			or (
				not windows_false_retry_state["error"]
				and not windows_false_retry_state["cleanup_error"]
				and not windows_false_retry_state["interrupt_injected"]
				and not windows_false_retry_state["interrupted"]
				and windows_false_retry_state["worker_start_attempts"] == 2
				and windows_false_retry_state["low_level_start_attempts"] == 0
				and len(windows_false_retry_state["operations"]) == 2
				and windows_false_retry_state["operations"][0] is not windows_false_retry_state["operations"][1]
				and windows_false_retry_state["operation_handles"][0] != 0
				and windows_false_retry_state["operation_handles"][0] == windows_false_retry_state["operation_handles"][1]
				and windows_false_retry_state["owner_handles_at_start"] == [0, 0]
				and windows_false_retry_state["wrapper_results"] == [False, True]
				and windows_false_retry_state["native_results"] == [True]
				and windows_false_retry_state["worker_thread_names"]
				== ["gf-windows-handle-close", "gf-windows-handle-close"]
				and windows_false_retry_result is not None
				and windows_false_retry_result.timed_out
				and any(
					"Could not close the owned Windows Job Object" in note
					for note in windows_false_retry_result.notes
				)
				and windows_false_retry_state["owner"] is not None
				and windows_false_retry_state["process"] is not None
				and windows_false_retry_state["handle_zero"]
				and windows_false_retry_state["owner_closed"]
				and windows_false_retry_state["process_reaped"]
				and windows_false_retry_state["pipes_closed"]
			),
			"An explicit CloseHandle False result must restore the same numeric handle for a fresh operation, then "
			"close it exactly once through the native API on the emergency retry; "
			f"platform={os.name}, starts={windows_false_retry_state['worker_start_attempts']}, "
			f"low_level_starts={windows_false_retry_state['low_level_start_attempts']}, "
			f"operation_handles={windows_false_retry_state['operation_handles']}, "
			f"owner_handles_at_start={windows_false_retry_state['owner_handles_at_start']}, "
			f"wrapper_results={windows_false_retry_state['wrapper_results']}, "
			f"native_results={windows_false_retry_state['native_results']}, "
			f"worker_threads={windows_false_retry_state['worker_thread_names']}, "
			f"timed_out={getattr(windows_false_retry_result, 'timed_out', None)}, "
			f"handle_zero={windows_false_retry_state['handle_zero']}, "
			f"owner_closed={windows_false_retry_state['owner_closed']}, "
			f"reaped={windows_false_retry_state['process_reaped']}, "
			f"pipes_closed={windows_false_retry_state['pipes_closed']}, "
			f"error={windows_false_retry_state['error']!r}, "
			f"cleanup_error={windows_false_retry_state['cleanup_error']!r}.",
		)

		def run_windows_job_configuration_cleanup_fixture(mode: str) -> dict[str, Any]:
			state: dict[str, Any] = {
				"mode": mode,
				"owner": None,
				"set_calls": 0,
				"real_set_result": None,
				"captured_handle": 0,
				"state_machine_close_calls": 0,
				"worker_start_attempts": 0,
				"operations": [],
				"operation_handles": [],
				"owner_handles_at_start": [],
				"wrapper_results": [],
				"native_results": [],
				"close_handles": [],
				"worker_thread_names": [],
				"interrupt_injected": False,
				"interrupted": False,
				"same_exception": False,
				"os_error": False,
				"error": "",
				"owner_closed": False,
				"handle_zero": False,
				"cleanup_close_result": None,
				"cleanup_error": "",
			}
			if os.name != "nt":
				return state

			original_set_job_information = gf_process_supervisor._SET_JOB_INFORMATION
			original_close_handle = gf_process_supervisor._CLOSE_HANDLE
			original_close_in_worker = gf_process_supervisor._close_windows_handle_in_worker
			original_thread_start = gf_process_supervisor.threading.Thread.start
			injected_interrupt = KeyboardInterrupt(
				f"SetInformationJobObject {mode} fixture"
			)

			def handle_value(handle: Any) -> int:
				value = getattr(handle, "value", handle)
				return int(value or 0)

			def inject_job_configuration_result(
				handle: Any,
				information_class: int,
				information: Any,
				information_size: int,
			) -> bool:
				state["set_calls"] += 1
				state["captured_handle"] = handle_value(handle)
				if mode == "false_retry":
					ctypes.set_last_error(5)
					return False
				real_result = bool(original_set_job_information(
					handle,
					information_class,
					information,
					information_size,
				))
				state["real_set_result"] = real_result
				if real_result:
					state["interrupt_injected"] = True
					raise injected_interrupt
				return real_result

			def track_configuration_close_handle(handle: Any) -> bool:
				numeric_handle = handle_value(handle)
				state["close_handles"].append(numeric_handle)
				state["worker_thread_names"].append(threading.current_thread().name)
				if mode == "false_retry" and not state["wrapper_results"]:
					ctypes.set_last_error(6)
					state["wrapper_results"].append(False)
					return False
				real_result = bool(original_close_handle(handle))
				state["wrapper_results"].append(real_result)
				state["native_results"].append(real_result)
				return real_result

			def capture_configuration_state_machine(owner: Any) -> Any:
				state["state_machine_close_calls"] += 1
				state["owner"] = owner
				return original_close_in_worker(owner)

			def track_configuration_worker_start(
				worker: threading.Thread,
				*args: Any,
				**kwargs: Any,
			) -> Any:
				if worker.name == "gf-windows-handle-close":
					state["worker_start_attempts"] += 1
					worker_args = getattr(worker, "_args", ())
					owner = worker_args[0] if len(worker_args) >= 1 else None
					operation = worker_args[1] if len(worker_args) >= 2 else None
					if owner is not None:
						state["owner"] = owner
					state["operations"].append(operation)
					state["operation_handles"].append(
						operation.handle if operation is not None else 0
					)
					state["owner_handles_at_start"].append(
						owner.handle if owner is not None else -1
					)
				return original_thread_start(worker, *args, **kwargs)

			try:
				gf_process_supervisor._SET_JOB_INFORMATION = inject_job_configuration_result
				gf_process_supervisor._CLOSE_HANDLE = track_configuration_close_handle
				gf_process_supervisor._close_windows_handle_in_worker = (
					capture_configuration_state_machine
				)
				gf_process_supervisor.threading.Thread.start = (
					track_configuration_worker_start
				)
				try:
					gf_process_supervisor._WindowsJobOwner()
				except KeyboardInterrupt as error:
					state["interrupted"] = True
					state["same_exception"] = error is injected_interrupt
				except OSError:
					state["os_error"] = True
				except BaseException as error:
					state["error"] = f"{type(error).__name__}: {error}"
			finally:
				gf_process_supervisor.threading.Thread.start = original_thread_start
				gf_process_supervisor._close_windows_handle_in_worker = original_close_in_worker
				gf_process_supervisor._CLOSE_HANDLE = original_close_handle
				gf_process_supervisor._SET_JOB_INFORMATION = original_set_job_information

			owner = state["owner"]
			if owner is not None:
				state["owner_closed"] = owner.is_closed()
				state["handle_zero"] = owner.handle == 0

			# A failed implementation may leave the empty Job open. Clean it only
			# after snapshotting the assertions, and never retry a handle whose real
			# CloseHandle result was already successful.
			if owner is not None and not owner.is_closed():
				try:
					owner.close()
				except BaseException as error:
					state["cleanup_error"] = f"{type(error).__name__}: {error}"
			if (
				state["captured_handle"] != 0
				and True not in state["native_results"]
				and (owner is None or not owner.is_closed())
			):
				try:
					state["cleanup_close_result"] = bool(
						original_close_handle(
							gf_process_supervisor.wintypes.HANDLE(
								state["captured_handle"]
							)
						)
					)
				except BaseException as error:
					state["cleanup_error"] = (
						state["cleanup_error"]
						or f"{type(error).__name__}: {error}"
					)
			return state

		windows_set_false_state = run_windows_job_configuration_cleanup_fixture(
			"false_retry"
		)
		record_result(
			"windows_job_configuration_false_closes_empty_job_via_state_machine",
			os.name != "nt"
			or (
				not windows_set_false_state["error"]
				and not windows_set_false_state["cleanup_error"]
				and windows_set_false_state["os_error"]
				and not windows_set_false_state["interrupted"]
				and windows_set_false_state["set_calls"] == 1
				and windows_set_false_state["captured_handle"] != 0
				and windows_set_false_state["state_machine_close_calls"] == 2
				and windows_set_false_state["worker_start_attempts"] == 2
				and len(windows_set_false_state["operations"]) == 2
				and windows_set_false_state["operations"][0]
				is not windows_set_false_state["operations"][1]
				and windows_set_false_state["operation_handles"][0]
				== windows_set_false_state["captured_handle"]
				and windows_set_false_state["operation_handles"][0]
				== windows_set_false_state["operation_handles"][1]
				and windows_set_false_state["owner_handles_at_start"] == [0, 0]
				and windows_set_false_state["wrapper_results"] == [False, True]
				and windows_set_false_state["native_results"] == [True]
				and windows_set_false_state["close_handles"]
				== [
					windows_set_false_state["captured_handle"],
					windows_set_false_state["captured_handle"],
				]
				and windows_set_false_state["worker_thread_names"]
				== ["gf-windows-handle-close", "gf-windows-handle-close"]
				and windows_set_false_state["owner"] is not None
				and windows_set_false_state["owner_closed"]
				and windows_set_false_state["handle_zero"]
				and windows_set_false_state["cleanup_close_result"] is None
			),
			"SetInformationJobObject False must preserve its original error while closing the real empty Job "
			"through two state-machine operations when the first CloseHandle explicitly returns False; "
			f"platform={os.name}, set_calls={windows_set_false_state['set_calls']}, "
			f"handle={windows_set_false_state['captured_handle']}, "
			f"state_machine_closes={windows_set_false_state['state_machine_close_calls']}, "
			f"starts={windows_set_false_state['worker_start_attempts']}, "
			f"operation_handles={windows_set_false_state['operation_handles']}, "
			f"wrapper_results={windows_set_false_state['wrapper_results']}, "
			f"native_results={windows_set_false_state['native_results']}, "
			f"owner_closed={windows_set_false_state['owner_closed']}, "
			f"handle_zero={windows_set_false_state['handle_zero']}, "
			f"cleanup_close={windows_set_false_state['cleanup_close_result']}, "
			f"error={windows_set_false_state['error']!r}, "
			f"cleanup_error={windows_set_false_state['cleanup_error']!r}.",
		)

		windows_set_interrupt_state = run_windows_job_configuration_cleanup_fixture(
			"interrupt_after_success"
		)
		record_result(
			"windows_job_configuration_interrupt_closes_empty_job_via_state_machine",
			os.name != "nt"
			or (
				not windows_set_interrupt_state["error"]
				and not windows_set_interrupt_state["cleanup_error"]
				and not windows_set_interrupt_state["os_error"]
				and windows_set_interrupt_state["interrupt_injected"]
				and windows_set_interrupt_state["interrupted"]
				and windows_set_interrupt_state["same_exception"]
				and windows_set_interrupt_state["set_calls"] == 1
				and windows_set_interrupt_state["real_set_result"] is True
				and windows_set_interrupt_state["captured_handle"] != 0
				and windows_set_interrupt_state["state_machine_close_calls"] == 1
				and windows_set_interrupt_state["worker_start_attempts"] == 1
				and len(windows_set_interrupt_state["operations"]) == 1
				and windows_set_interrupt_state["operation_handles"]
				== [windows_set_interrupt_state["captured_handle"]]
				and windows_set_interrupt_state["owner_handles_at_start"] == [0]
				and windows_set_interrupt_state["wrapper_results"] == [True]
				and windows_set_interrupt_state["native_results"] == [True]
				and windows_set_interrupt_state["close_handles"]
				== [windows_set_interrupt_state["captured_handle"]]
				and windows_set_interrupt_state["worker_thread_names"]
				== ["gf-windows-handle-close"]
				and windows_set_interrupt_state["owner"] is not None
				and windows_set_interrupt_state["owner_closed"]
				and windows_set_interrupt_state["handle_zero"]
				and windows_set_interrupt_state["cleanup_close_result"] is None
			),
			"An interruption immediately after successful SetInformationJobObject must close the real empty Job "
			"once through the state machine before propagating the same exception; "
			f"platform={os.name}, set_calls={windows_set_interrupt_state['set_calls']}, "
			f"real_set={windows_set_interrupt_state['real_set_result']}, "
			f"handle={windows_set_interrupt_state['captured_handle']}, "
			f"state_machine_closes={windows_set_interrupt_state['state_machine_close_calls']}, "
			f"starts={windows_set_interrupt_state['worker_start_attempts']}, "
			f"operation_handles={windows_set_interrupt_state['operation_handles']}, "
			f"wrapper_results={windows_set_interrupt_state['wrapper_results']}, "
			f"native_results={windows_set_interrupt_state['native_results']}, "
			f"same_exception={windows_set_interrupt_state['same_exception']}, "
			f"owner_closed={windows_set_interrupt_state['owner_closed']}, "
			f"handle_zero={windows_set_interrupt_state['handle_zero']}, "
			f"cleanup_close={windows_set_interrupt_state['cleanup_close_result']}, "
			f"error={windows_set_interrupt_state['error']!r}, "
			f"cleanup_error={windows_set_interrupt_state['cleanup_error']!r}.",
		)

	from check_docs_quality import check_local_links
	from check_docs_quality import resolve_local_link_path
	from generate_ai_api import markdown_mentions_identifier
	from generate_ai_api import visible_markdown_text

	with tempfile.TemporaryDirectory(prefix="gf-doc-link-self-test-") as temp_dir:
		docs_root = Path(temp_dir) / "docs"
		docs_root.mkdir()
		source_path = docs_root / "page.md"
		source_path.write_text("# Page\n", encoding="utf-8")
		outside_path = Path(temp_dir) / "outside.md"
		outside_path.write_text("# Outside\n", encoding="utf-8")
		record_result(
			"docs_local_link_resolver_rejects_root_escape",
			resolve_local_link_path(source_path, docs_root, "../outside.md") is None,
			"documentation links must stay under the configured documentation root.",
		)
		assets_root = docs_root / "assets"
		assets_root.mkdir()
		(assets_root / "local.png").write_bytes(b"fixture")
		(Path(temp_dir) / "outside.png").write_bytes(b"outside")
		source_path.write_text("\n".join([
			"# Page",
			"[Web](https://example.com/GFVisible)",
			"[Secure web](http://example.com)",
			"[Mail](mailto:team@example.com)",
			"[Section](#page)",
			"![Local](assets/local.png)",
			"[Drive](C:/Users/example/private.md)",
			"[File URI](file:///C:/Users/example/private.md)",
			"![Escape](../outside.png)",
			"",
		]), encoding="utf-8")
		link_errors = check_local_links(source_path, docs_root)
		record_result(
			"docs_link_containment_covers_images_drives_and_file_uris",
			len(link_errors) == 3
			and any("C:/Users/example/private.md" in error for error in link_errors)
			and any("file:///C:/Users/example/private.md" in error for error in link_errors)
			and any("../outside.png" in error for error in link_errors),
			f"docs containment must reject local escapes while allowing http(s), mailto, fragments, and valid images: {link_errors}",
		)

	record_result(
		"wiki_coverage_uses_identifier_boundaries",
		markdown_mentions_identifier("Use `GFExact` here.", "GFExact")
		and not markdown_mentions_identifier("GFExactSuffix", "GFExact"),
		"wiki coverage must not satisfy a short class name through a longer identifier.",
	)
	hidden_markdown = "\n".join([
		"<!-- GFHiddenComment -->",
		"```gdscript",
		"var value := GFHiddenCode.new()",
		"```",
		"[Documentation](https://example.com/GFHiddenTarget)",
		"[Nested URL](https://example.com/(GFHiddenNestedTarget))",
		"[reference]: https://example.com/GFHiddenReference",
		'<a href="https://example.com/GFHiddenHtmlTarget">HTML label</a>',
	])
	visible_markdown = visible_markdown_text(hidden_markdown)
	record_result(
		"wiki_coverage_counts_only_visible_markdown_text",
		not markdown_mentions_identifier(visible_markdown, "GFHiddenComment")
		and not markdown_mentions_identifier(visible_markdown, "GFHiddenCode")
		and not markdown_mentions_identifier(visible_markdown, "GFHiddenTarget")
		and not markdown_mentions_identifier(visible_markdown, "GFHiddenNestedTarget")
		and not markdown_mentions_identifier(visible_markdown, "GFHiddenReference")
		and not markdown_mentions_identifier(visible_markdown, "GFHiddenHtmlTarget")
		and markdown_mentions_identifier(
			visible_markdown_text("[GFVisibleLabel](https://example.com/hidden)"),
			"GFVisibleLabel",
		),
		f"AI coverage must exclude comments, fenced code, and hidden URL targets: {visible_markdown!r}",
	)
	mkdocs_config_source = read_text_file(ROOT / "mkdocs.yml")
	record_result(
		"mkdocs_check_writes_only_to_ignored_output_root",
		"--site-dir" in CHECK_DEFINITIONS["mkdocs"]
		and (ROOT / "ai_analysis/mkdocs_site").as_posix() in CHECK_DEFINITIONS["mkdocs"]
		and "site_dir: ai_analysis/mkdocs_site" in mkdocs_config_source,
		"MkDocs validation must not create the repository-root site directory.",
	)
	record_result(
		"ai_api_check_bootstraps_ignored_output_on_clean_checkout",
		"--check-or-generate" in CHECK_DEFINITIONS["ai_api"]
		and "--check" not in CHECK_DEFINITIONS["ai_api"],
		"AI API validation must generate its ignored output on a clean checkout and strictly check it when present.",
	)
	record_result(
		"gut_check_declares_clean_import_dependency",
		"godot_import" in CHECK_DEFINITIONS
		and CHECK_DEPENDENCIES.get("gut") == ["godot_import"]
		and expand_check_dependencies(["gut"]) == ["godot_import", "gut"]
		and expand_check_dependencies(["godot_import", "gut"]) == ["godot_import", "gut"]
		and GUT_LIFECYCLE_CLI_RESOURCE_PATH in CHECK_DEFINITIONS["gut"]
		and GUT_SHARD_CONFIG_DISABLED_ARGUMENT in CHECK_DEFINITIONS["gut"]
		and all(argument in CHECK_DEFINITIONS["gut"] for argument in GUT_LIFECYCLE_HOOK_ARGUMENTS),
		(
			"GUT validation must import a clean Godot project exactly once before loading "
			"class_name scripts and must use the lifecycle-aware CLI with both hooks."
		),
	)
	record_result(
		"gut_shard_plan_remains_observational_and_outside_suites",
		"gut_shard_plan" not in CHECK_DEFINITIONS
		and all(
			"gut_shard_plan" not in suite_checks
			for suite_checks in CHECK_SUITES.values()
		)
		and all(
			"gut_shard_plan" not in dependencies
			for dependencies in CHECK_DEPENDENCIES.values()
		)
		and CHECK_DEPENDENCIES.get("gut") == ["godot_import"],
		(
			"The G0 shard plan must remain an explicit observational command and must "
			"not change authoritative suite membership or GUT dependencies."
		),
	)
	record_result(
		"gut_shard_run_remains_non_authoritative_and_outside_all_gates",
		"gut_shard_run" not in CHECK_DEFINITIONS
		and all(
			"gut_shard_run" not in suite_checks
			for suite_checks in CHECK_SUITES.values()
		)
		and all(
			"gut_shard_run" not in dependencies
			for dependencies in CHECK_DEPENDENCIES.values()
		)
		and all(
			"gut-shard-run" not in read_text_file(ROOT / workflow_path)
			for workflow_path in (
				".github/workflows/ci.yml",
				".github/workflows/ci-manual.yml",
				".github/workflows/release.yml",
			)
		),
		(
			"The G0.2A runner must remain an explicit non-authoritative command and must "
			"not enter checks, suites, dependencies, CI, or release workflows."
		),
	)
	record_result(
		"gut_sharding_tests_share_the_maintenance_execution_owner",
		CHECK_DEFINITIONS.get("maintenance_execution_tests") == [
			sys.executable,
			"-m",
			"unittest",
			"tests/gf_core/tools/test_gf_maintenance_execution.py",
			"tests/gf_core/tools/test_gf_maintenance_check_graph.py",
			"tests/gf_core/tools/test_gf_parallel_validation.py",
			"tests/gf_core/tools/test_gf_validation_contracts.py",
			"tests/gf_core/tools/test_gf_validation_evidence.py",
			"tests/gf_core/tools/test_gf_validation_inputs.py",
			"tests/gf_core/tools/test_gf_validation_test_inventory.py",
			"tests/gf_core/tools/test_gf_gut_sharding.py",
			"tests/gf_core/tools/test_gf_gut_shard_worker.py",
		],
		(
			"GUT shard protocol tests must stay in the existing maintenance execution "
			"owner instead of creating an unowned or suite-expanding test path."
		),
	)
	record_result(
		"gut_shard_observation_has_an_independent_owned_output_and_timeout",
		GUT_SHARD_OBSERVATION_ROOT == ROOT / "build/gut-sharding"
		and GUT_SHARD_OBSERVATION_JUNIT_FILENAME == "gut-authoritative.xml"
		and GUT_SHARD_OBSERVATION_PROVENANCE_FILENAME
		== "gut-authoritative-provenance.json"
		and GUT_SHARD_OBSERVATION_NONCE_ENVIRONMENT
		== "GF_GUT_SHARD_OBSERVATION_NONCE"
		and GUT_SHARD_OBSERVATION_PATH_ENVIRONMENT
		== "GF_GUT_SHARD_OBSERVATION_PATH"
		and GUT_SHARD_OBSERVATION_TIMEOUT_SECONDS == 1200
		and resolve_gut_shard_observation_timeout_seconds(None) == 1200
		and resolve_gut_shard_observation_timeout_seconds(1500) == 1500
		and _VALIDATION_CATALOG.timeout_floor_seconds("gut") == 1200
		and resolve_check_timeout_seconds("gut", None) == 1200
		and resolve_check_timeout_seconds("gut", 600) == 1200
		and resolve_check_timeout_seconds("gut", 1500) == 1500,
		(
			"The explicit G0 observation must use its dedicated ignored output root and "
			"share the measured authoritative GUT timeout floor."
		),
	)
	record_result(
		"gut_shard_run_has_bounded_two_worker_observation_policy",
		GUT_SHARD_RUN_DEFAULT_JOBS == 2
		and GUT_SHARD_RUN_ALLOWED_JOBS == (1, 2)
		and resolve_gut_shard_run_gut_timeout_seconds(None) == 600
		and resolve_gut_shard_run_gut_timeout_seconds(30) == 600
		and resolve_gut_shard_run_gut_timeout_seconds(900) == 900
		and gut_shard_run_total_timeout_seconds(
			9,
			2,
			gut_timeout_seconds=600,
			qualify=False,
		) == 6900
		and gut_shard_run_total_timeout_seconds(
			9,
			2,
			gut_timeout_seconds=600,
			qualify=True,
		) == 8820,
		(
			"G0.2A must default to two bounded workers, accept only jobs 1 or 2, preserve "
			"the candidate GUT floor, and derive a finite wave-based parent budget."
		),
	)
	record_result(
		"gut_lifecycle_smoke_is_a_framework_gate",
		CHECK_DEPENDENCIES.get("gut_lifecycle_smoke") == ["godot_import"]
		and expand_check_dependencies(["gut_lifecycle_smoke"])
		== ["godot_import", "gut_lifecycle_smoke"]
		and "gut_lifecycle_smoke" in CHECK_SUITES["framework-gut"]
		and "gut_lifecycle_smoke" in CHECK_SUITES["framework"]
		and "gut_lifecycle_smoke" in CHECK_SUITES["full"]
		and "gut_lifecycle_smoke" in CHECK_SUITES["release"],
		"Process-level lifecycle failure fixtures must remain a framework and release gate.",
	)
	gut_lifecycle_cli_source = read_text_file(
		ROOT / GUT_LIFECYCLE_CLI_RESOURCE_PATH.removeprefix("res://")
	)
	legacy_gut_runner_paths = (
		"tests/gf_core/support/gf_gut_runner.gd",
		"tests/gf_core/support/gf_gut_runner.gd.uid",
		"tests/gf_core/support/gf_gut_runner.tscn",
	)
	record_result(
		"gut_lifecycle_cli_owns_vendor_runner_tracking",
		GUT_RUNNER_SCENE_RESOURCE_PATH in gut_lifecycle_cli_source
		and "GutUtils.get_error_tracker()" in gut_lifecycle_cli_source
		and "GutErrorTracker.register_logger(tracker)" in gut_lifecycle_cli_source
		and "GutErrorTracker.registered_loggers.has(tracker)" in gut_lifecycle_cli_source
		and "GF_GUT_LIFECYCLE_STATE_SCRIPT.enter_tracking_phase(tracker_registered)"
		in gut_lifecycle_cli_source
		and "GutErrorTracker.deregister_logger(_gut_error_tracker)"
		in gut_lifecycle_cli_source
		and "res://tests/gf_core/support/gf_gut_runner.tscn"
		not in gut_lifecycle_cli_source
		and all(not (ROOT / path).exists() for path in legacy_gut_runner_paths),
		(
			"The lifecycle CLI must own early warning-tracker registration around the vendored "
			"GUT runner without a path-inheritance shim outside the LSP scan closure."
		),
	)
	gut_config_payload = read_json_object(ROOT / ".gutconfig.json")
	record_result(
		"gut_lifecycle_hook_configuration_is_canonical",
		gut_config_payload == {
			"pre_run_script": GUT_PRE_RUN_HOOK_RESOURCE_PATH,
			"post_run_script": GUT_POST_RUN_HOOK_RESOURCE_PATH,
		}
		and GUT_LIFECYCLE_CLI_RESOURCE_PATH in CHECK_DEFINITIONS["gut"]
		and all(argument in CHECK_DEFINITIONS["gut"] for argument in GUT_LIFECYCLE_HOOK_ARGUMENTS),
		(
			"Repository GUT defaults and the lifecycle-aware maintenance command must "
			"install the same hooks."
		),
	)
	record_result(
		"gdscript_lsp_check_declares_clean_import_dependency",
		"godot_import" in CHECK_DEFINITIONS
		and CHECK_DEPENDENCIES.get("gdscript_lsp_diagnostics") == ["godot_import"]
		and expand_check_dependencies(["gdscript_lsp_diagnostics"])
		== ["godot_import", "gdscript_lsp_diagnostics"]
		and expand_check_dependencies(["godot_import", "gdscript_lsp_diagnostics"])
		== ["godot_import", "gdscript_lsp_diagnostics"],
		"LSP validation must import a clean Godot project exactly once before scanning editor diagnostics.",
	)
	setup_godot_action_source = read_text_file(ROOT / ".github/actions/setup-godot/action.yml")
	setup_godot_issues = audit_setup_godot_action_source(setup_godot_action_source)
	record_result(
		"setup_godot_action_pins_and_verifies_synchronized_archive",
		not setup_godot_issues,
		f"setup-godot must pin a real digest, synchronize version/URL, and verify before unzip: {setup_godot_issues}",
	)
	bad_digest_source = re.sub(
		r"(?m)^(    default:) [0-9A-Fa-f]{64}$",
		r"\1 deadbeef",
		setup_godot_action_source,
		count=1,
	)
	late_checksum_source = setup_godot_action_source.replace(
		"        unzip -q \"${install_dir}/${archive}\" -d \"${install_dir}\"\n",
		"",
	).replace(
		"        printf '%s  %s\\n' \"${expected_sha256}\" \"${install_dir}/${archive}\" | sha256sum --check --strict -\n",
		"        unzip -q \"${install_dir}/${archive}\" -d \"${install_dir}\"\n"
		"        printf '%s  %s\\n' \"${expected_sha256}\" \"${install_dir}/${archive}\" | sha256sum --check --strict -\n",
	)
	stale_url_source = setup_godot_action_source.replace(
		"/releases/download/${version}/${archive}",
		"/releases/download/4.6-stable/${archive}",
	)
	record_result(
		"setup_godot_action_audit_rejects_digest_order_and_version_regressions",
		bool(audit_setup_godot_action_source(bad_digest_source))
		and bool(audit_setup_godot_action_source(late_checksum_source))
		and bool(audit_setup_godot_action_source(stale_url_source)),
		"setup-godot self-test fixtures must detect malformed digests, late checksum checks, and stale URLs.",
	)
	ci_workflow_source = read_text_file(ROOT / ".github/workflows/ci.yml")
	manual_ci_workflow_source = read_text_file(ROOT / ".github/workflows/ci-manual.yml")
	release_workflow_source = read_text_file(ROOT / ".github/workflows/release.yml")
	ci_action_issues = audit_governed_workflow_actions(
		ci_workflow_source,
		".github/workflows/ci.yml",
		CI_WORKFLOW_ACTION_COUNTS,
	)
	release_action_issues = audit_governed_workflow_actions(
		release_workflow_source,
		".github/workflows/release.yml",
		RELEASE_WORKFLOW_ACTION_COUNTS,
	)
	manual_ci_action_issues = audit_governed_workflow_actions(
		manual_ci_workflow_source,
		".github/workflows/ci-manual.yml",
		MANUAL_CI_WORKFLOW_ACTION_COUNTS,
	)
	record_result(
		"workflows_use_current_node24_action_majors",
		not ci_action_issues and not manual_ci_action_issues and not release_action_issues,
		"CI and release workflows must use the governed current Node.js 24 action majors without stale variants.",
	)
	stale_action_source = ci_workflow_source.replace("actions/checkout@v7", "actions/checkout@v6", 1)
	commented_stale_action_source = ci_workflow_source.replace(
		"actions/setup-python@v7",
		"actions/setup-python@v6 # stale",
		1,
	)
	missing_action_source = ci_workflow_source.replace("        uses: actions/checkout@v7\n", "", 1)
	shorthand_stale_action_source = ci_workflow_source + "\n      - uses: actions/checkout@v4\n"
	case_variant_action_source = ci_workflow_source + "\n      - uses: Actions/Checkout@v4\n"
	record_result(
		"workflow_action_audit_rejects_stale_commented_and_missing_steps",
		bool(audit_governed_workflow_actions(stale_action_source, "ci-stale", CI_WORKFLOW_ACTION_COUNTS))
		and bool(audit_governed_workflow_actions(
			commented_stale_action_source,
			"ci-commented-stale",
			CI_WORKFLOW_ACTION_COUNTS,
		))
		and bool(audit_governed_workflow_actions(missing_action_source, "ci-missing", CI_WORKFLOW_ACTION_COUNTS))
		and bool(audit_governed_workflow_actions(
			shorthand_stale_action_source,
			"ci-shorthand-stale",
			CI_WORKFLOW_ACTION_COUNTS,
		))
		and bool(audit_governed_workflow_actions(
			case_variant_action_source,
			"ci-case-variant",
			CI_WORKFLOW_ACTION_COUNTS,
		)),
		"Workflow action policy fixtures must detect stale refs, comments, missing steps, shorthand, and case variants.",
	)
	quick_job_match = re.search(
		r"(?ms)^  quick-checks:\n(?P<body>.*?)(?=^  framework-checks:)",
		ci_workflow_source,
	)
	quick_job_source = quick_job_match.group("body") if quick_job_match is not None else ""
	windows_process_job_match = re.search(
		r"(?ms)^  windows-process-supervision:\n(?P<body>.*?)(?=^  draft-gate:)",
		ci_workflow_source,
	)
	windows_process_job_source = (
		windows_process_job_match.group("body")
		if windows_process_job_match is not None
		else ""
	)
	record_result(
		"ci_workflow_runs_all_full_suite_shards",
		ci_workflow_source.count("--suite ${{ matrix.suite }}") == 2
		and all(
			f"suite: {suite_name}" in ci_workflow_source
			for suite_name in (
				"framework-gut",
				"framework-lsp",
				"framework-static",
				"package-contract",
				"package-editor",
				"package-cli-local",
				"package-cli-network",
				"package-godot-ci",
			)
		),
		"CI workflow must run every set-equivalent full-suite shard.",
	)
	record_result(
		"ci_workflow_layers_draft_ready_and_stable_merge_gate",
		"repository-policy:" in ci_workflow_source
		and "quick-checks:" in ci_workflow_source
		and "windows-process-supervision:" in ci_workflow_source
		and "draft-gate:" in ci_workflow_source
		and "full-validation-gate:" in ci_workflow_source
		and "merge-gate:" in ci_workflow_source
		and "GF draft gate" in ci_workflow_source
		and "GF draft gate (not applicable)" in ci_workflow_source
		and "GF merge gate" in ci_workflow_source
		and "GF merge gate (not applicable)" in ci_workflow_source
		and "converted_to_draft" in ci_workflow_source
		and "edited" in ci_workflow_source
		and "ready_for_review" in ci_workflow_source
		and "github.event.changes.base.ref.from" in ci_workflow_source
		and "'policy' || 'validation'" in ci_workflow_source
		and "GF CI|mode=" in ci_workflow_source
		and "GF full validation (${{ github.event.pull_request.base.sha || github.sha }})" in ci_workflow_source
		and "github.event.pull_request.draft == true" in ci_workflow_source
		and "github.event.pull_request.draft == false" in ci_workflow_source
		and re.search(r"(?ms)^  draft-gate:.*?if:.*?!cancelled\(\).*?needs:.*?repository-policy.*?quick-checks", ci_workflow_source) is not None
		and re.search(r"(?ms)^  full-validation-gate:.*?if:.*?!cancelled\(\).*?needs:.*?repository-policy.*?framework-checks.*?package-checks.*?windows-process-supervision", ci_workflow_source) is not None
		and re.search(r"(?ms)^  merge-gate:.*?if:.*?always\(\).*?needs:.*?repository-policy.*?full-validation-gate", ci_workflow_source) is not None
		and re.search(r"(?ms)^  merge-gate:.*?needs:(?P<needs>.*?)(?=^    runs-on:)", ci_workflow_source) is not None
		and "quick-checks" not in re.search(
			r"(?ms)^  merge-gate:.*?needs:(?P<needs>.*?)(?=^    runs-on:)",
			ci_workflow_source,
		).group("needs")
		and "python tools/gf_repository_policy.py validate --json" in ci_workflow_source
		and "python tools/gf_repository_policy.py validate-pr --json" in ci_workflow_source
		and "python tools/gf_repository_policy.py validate-pr-gate" in ci_workflow_source
		and "workflow_dispatch:" not in ci_workflow_source,
		"CI must isolate metadata edits, freeze Full epochs, give Draft PRs their own gate, and expose the protected merge gate only for Ready PRs/main.",
	)
	record_result(
		"manual_ci_isolated_from_required_contexts",
		"workflow_dispatch:" in manual_ci_workflow_source
		and "pull_request:" not in manual_ci_workflow_source
		and "push:" not in manual_ci_workflow_source
		and "GF manual repository policy" in manual_ci_workflow_source
		and "GF manual diagnostics gate" in manual_ci_workflow_source
		and "GF merge gate" not in manual_ci_workflow_source
		and "--suite full" in manual_ci_workflow_source
		and "github.ref == 'refs/heads/main'" in manual_ci_workflow_source,
		"Manual diagnostics must stay in a separately named workflow and never emit protected CI contexts.",
	)
	record_result(
		"ci_ready_main_runs_windows_process_supervision",
		bool(windows_process_job_source)
		and "runs-on: windows-latest" in windows_process_job_source
		and "python tools/gf_maintenance.py maintenance-self-test --json" in windows_process_job_source
		and "tests.gf_core.tools.test_gf_parallel_validation" in windows_process_job_source
		and "tests.gf_core.tools.test_gf_maintenance_check_graph" in windows_process_job_source
		and "github.event.pull_request.draft == false" in windows_process_job_source
		and "github.event.changes.base.ref.from" in windows_process_job_source,
		"Ready/main CI must exercise kernel-owned cleanup plus staging/startup boundaries on Windows.",
	)
	record_result(
		"ci_draft_quick_job_avoids_heavy_environment_bootstrap",
		bool(quick_job_source)
		and "actions/setup-python@v7" in quick_job_source
		and "docs/requirements.txt" not in quick_job_source
		and ".github/actions/setup-godot" not in quick_job_source,
		"Draft quick CI must remain pure Python and avoid documentation or Godot environment bootstrap.",
	)
	record_result(
		"release_workflow_gates_publish_on_all_release_shards",
		"release-framework-checks:" in release_workflow_source
		and "release-package-checks:" in release_workflow_source
		and "--suite framework" in release_workflow_source
		and (
			f"--suite-timeout {gf_repository_policy.RELEASE_FRAMEWORK_SUITE_TIMEOUT_SECONDS}"
			in release_workflow_source
		)
		and "--suite ${{ matrix.suite }}" in release_workflow_source
		and all(
			f"suite: {suite_name}" in release_workflow_source
			for suite_name in (
				"package-contract",
				"package-editor",
				"package-cli-local",
				"package-cli-network",
				"package-godot-release",
			)
		)
		and re.search(
			r"(?s)create-release:.*?needs:.*?build-release-artifacts.*?release-framework-checks.*?release-package-checks",
			release_workflow_source,
		) is not None,
		"Release publishing must wait for metadata/framework and every package matrix shard.",
	)
	record_result(
		"release_workflow_builds_one_immutable_artifact_set",
		"build-release-artifacts:" in release_workflow_source
		and release_workflow_source.count("python tools/build_gf_release_artifacts.py") == 2
		and release_workflow_source.count("--output-dir build/release") == 1
		and "python tools/build_asset_store_package.py" not in release_workflow_source
		and "python tools/build_gf_package.py" not in release_workflow_source
		and "actions/upload-artifact@v7" in release_workflow_source
		and "actions/download-artifact@v8" in release_workflow_source
		and "--validate-only" in release_workflow_source,
		"Release workflow must build archives once, transport that immutable set, then validate without rebuilding.",
	)
	release_artifact_builder_source = read_text_file(ROOT / "tools/build_gf_release_artifacts.py")
	record_result(
		"release_artifact_set_includes_one_versioned_ai_developer_kit",
		'"ai_developer_kit_build_count": 1' in release_artifact_builder_source
		and 'f"gf-ai-developer-kit-{version}.zip": "ai_developer_kit"' in release_artifact_builder_source
		and '"ai_developer_kit": f"gf-ai-developer-kit-{version}.zip"' in release_artifact_builder_source
		and '"build/release/gf-ai-developer-kit-${GITHUB_REF_NAME}.zip"' in release_workflow_source,
		"Release build, manifest audit, semantic audit, and upload must share one GF AI Developer Kit artifact.",
	)
	release_without_manifest = run_maintenance_subprocess(
		[
			sys.executable,
			"tools/gf_maintenance.py",
			"release-status",
			"--version",
			read_plugin_version(),
			"--json",
		],
		timeout_seconds=10,
	)
	maintenance_source = read_text_file(ROOT / "tools/gf_maintenance.py")
	obsolete_release_builders = (
		"audit_package_archive",
		"audit_asset_store_package",
		"audit_release_package_registry",
	)
	record_result(
		"release_status_requires_prebuilt_artifact_manifest",
		release_without_manifest.returncode == 2
		and "--artifact-manifest" in release_without_manifest.stderr
		and all(f"def {name}(" not in maintenance_source for name in obsolete_release_builders),
		"release-status must fail closed instead of rebuilding a second artifact set.",
	)
	record_result(
		"bare_extension_root_detector_matches_only_bare_root",
		source_contains_bare_bundled_extension_root('const ROOT = "res://addons/gf/extensions"')
		and not source_contains_bare_bundled_extension_root(
			'const SAVE = "res://addons/gf/extensions/save/core.gd"'
		),
		"dependency boundary must detect the bare bundled extension root without duplicating named path findings.",
	)
	comment_stripped_fixture = strip_gdscript_comments(
		'# GFCombatSystem in res://addons/gf/extensions/combat\n'
		'const DYNAMIC_PATH = "res://addons/gf/extensions/save/runtime.gd"\n'
	)
	record_result(
		"dependency_boundary_strips_comments_but_preserves_runtime_strings",
		"GFCombatSystem" not in comment_stripped_fixture
		and "res://addons/gf/extensions/combat" not in comment_stripped_fixture
		and "res://addons/gf/extensions/save/runtime.gd" in comment_stripped_fixture,
		"dependency scanning must ignore comments without hiding executable string-based probes.",
	)

	light_summary = project_summary()
	record_result(
		"summary_default_skips_release_diagnostics",
		light_summary["release"].get("ok") == None,
		"summary must stay lightweight by default; release diagnostics belong behind summary --release.",
	)

	maintenance_plan = workspace_status(paths=[
		"tools/gf_maintenance.py",
		"AI_MAINTENANCE.md",
	])
	maintenance_recommendations = maintenance_plan["recommended_checks"]
	record_result(
		"workspace_status_path_scope_limits_general_maintenance_recommendations",
		"python tools/gf_maintenance.py check --check package_godot_matrix_smoke --json" not in maintenance_recommendations,
		"general maintenance path recommendations should not force package matrix smoke by default.",
	)

	package_plan = workspace_status(paths=["tools/build_gf_release_artifacts.py"])
	artifact_set_plan = workspace_status(paths=["tools/gf_package_artifact_set.py"])
	record_result(
		"workspace_status_path_scope_keeps_package_tool_recommendations",
		"python tools/gf_maintenance.py check --suite package --json" in package_plan["recommended_checks"]
		and "python tools/gf_maintenance.py check --suite package --json" in artifact_set_plan["recommended_checks"],
		"package maintenance tool changes must still recommend package validation.",
	)
	workflow_plan = workspace_status(paths=[".github/workflows/ci.yml", ".github/workflows/ci-manual.yml"])
	record_result(
		"workspace_status_recommends_repository_policy_for_governed_workflows",
		"python tools/gf_repository_policy.py validate --json" in workflow_plan["recommended_checks"],
		"Governed workflow edits must recommend the repository-policy validator.",
	)

	lsp_check_command = "python tools/gf_maintenance.py check --check gdscript_lsp_diagnostics --json"
	runtime_plan = workspace_status(paths=["addons/gf/kernel/core/gf_architecture.gd"])
	test_plan = workspace_status(paths=["tests/gf_core/kernel/core/test_gf_singleton.gd"])
	record_result(
		"workspace_status_recommends_lsp_for_gdscript_changes",
		lsp_check_command in runtime_plan["recommended_checks"]
		and lsp_check_command in test_plan["recommended_checks"],
		"runtime and test GDScript changes must recommend the standalone LSP check before the full gate.",
	)

	valid_issues = audit_bundled_extension_manifests([
		make_manifest_test_record("fixture", make_manifest_test_data()),
	])
	record_result(
		"valid_bundled_manifest_fixture_has_no_issues",
		len(valid_issues) == 0,
		f"unexpected issues: {valid_issues}",
	)

	record_result(
		"forbidden_relation_fields_are_not_allowed_fields",
		GF_MANIFEST_ALLOWED_FIELDS.isdisjoint(GF_MANIFEST_FORBIDDEN_RELATION_FIELDS),
		"manifest relation fields must stay outside the allowed bundled manifest field set.",
	)
	record_result(
		"preset_relation_fields_are_not_allowed_fields",
		GF_PRESET_ALLOWED_FIELDS.isdisjoint(GF_PRESET_FORBIDDEN_RELATION_FIELDS),
		"preset relation fields must stay outside the allowed preset field set.",
	)
	record_result(
		"preset_package_fields_are_not_allowed_fields",
		GF_PRESET_ALLOWED_FIELDS.isdisjoint(GF_PRESET_FORBIDDEN_PACKAGE_FIELDS),
		"preset package fields must stay outside the allowed preset field set.",
	)
	previous_identifier_snapshot = _ACTIVE_WORKSPACE_SNAPSHOT
	identifier_snapshot = WorkspaceSnapshot(ROOT)
	_ACTIVE_WORKSPACE_SNAPSHOT = identifier_snapshot
	try:
		first_identifier_tokens = source_identifiers("GFRoute GFRoute GFUtility")
		second_identifier_tokens = source_identifiers("GFRoute GFRoute GFUtility")
	finally:
		_ACTIVE_WORKSPACE_SNAPSHOT = previous_identifier_snapshot
	record_result(
		"source_identifier_index_preserves_token_boundaries",
		source_contains_identifier("GFRoute other.GFRoute 'GFRoute'", "GFRoute")
		and not source_contains_identifier("PrefixGFRoute GFRouteSuffix", "GFRoute")
		and first_identifier_tokens == {"GFRoute", "GFUtility"}
		and first_identifier_tokens is second_identifier_tokens
		and identifier_snapshot.stats()["value_cache_hits"] == 1,
		"dependency scans must tokenize each source once without broadening identifier matches.",
	)
	record_result(
		"quick_suite_excludes_long_package_smokes",
		set(CHECK_SUITES["quick"]).isdisjoint(PACKAGE_SMOKE_CHECKS),
		"quick suite must stay light; long package build/install/Godot CLI smoke belongs to the package suite.",
	)
	record_result(
		"quick_suite_excludes_maintenance_self_test",
		"maintenance_self_test" not in CHECK_SUITES["quick"]
		and "maintenance_self_test" in CHECK_SUITES["framework"]
		and "maintenance_self_test" in CHECK_SUITES["framework-static"],
		"quick must keep the developer loop lean while framework/full retain maintenance tool self-tests.",
	)
	record_result(
		"quick_uses_ai_developer_source_gate_while_full_runs_behavior_tests",
		"ai_developer_kit_source" in CHECK_SUITES["quick"]
		and "ai_developer_kit" not in CHECK_SUITES["quick"]
		and "ai_developer_adapter_acceptance" not in CHECK_SUITES["quick"]
		and "ai_developer_kit" in CHECK_SUITES["api"]
		and "ai_developer_kit" in CHECK_SUITES["framework-static"]
		and "ai_developer_kit" in CHECK_SUITES["framework"]
		and "ai_developer_kit" not in CHECK_SUITES["package-contract"]
		and "ai_developer_kit" not in CHECK_SUITES["package"]
		and "ai_developer_adapter_acceptance" not in CHECK_SUITES["api"]
		and "ai_developer_adapter_acceptance" not in CHECK_SUITES["framework-static"]
		and "ai_developer_adapter_acceptance" not in CHECK_SUITES["framework"]
		and "ai_developer_adapter_acceptance" in CHECK_SUITES["package-contract"]
		and "ai_developer_adapter_acceptance" in CHECK_SUITES["package"]
		and {
			"tools/build_gf_ai_developer_kit.py",
			"--storage-backend-acceptance",
		}.issubset(CHECK_DEFINITIONS["ai_developer_adapter_acceptance"])
		and "ai_developer_kit" in CHECK_SUITES["full"]
		and "ai_developer_adapter_acceptance" in CHECK_SUITES["full"]
		and "ai_developer_kit" in CHECK_SUITES["release"]
		and "ai_developer_adapter_acceptance" in CHECK_SUITES["release"],
		"Draft feedback should check tracked AI Kit inputs quickly; static/API behavior and Godot-backed Adapter acceptance must retain distinct owners through merge and release.",
	)
	record_result(
		"repository_policy_is_a_quick_and_full_gate",
		"repository_policy" in CHECK_SUITES["quick"]
		and "repository_policy" in CHECK_SUITES["framework-static"]
		and "repository_policy" in CHECK_SUITES["framework"]
		and "repository_policy" in CHECK_SUITES["full"]
		and "repository_policy" in CHECK_SUITES["release"],
		"repository workflow drift must fail local quick checks, full CI, and release checks.",
	)
	semver_precedence_values = [
		"1.0.0-alpha",
		"1.0.0-alpha.1",
		"1.0.0-alpha.beta",
		"1.0.0-beta",
		"1.0.0-beta.2",
		"1.0.0-beta.11",
		"1.0.0-rc.1",
		"1.0.0",
	]
	parsed_semver_precedence = [gf_semver.parse_semver(value) for value in semver_precedence_values]
	record_result(
		"shared_semver_parser_enforces_semver_2_precedence",
		all(version is not None for version in parsed_semver_precedence)
		and all(
			parsed_semver_precedence[index] < parsed_semver_precedence[index + 1]
			for index in range(len(parsed_semver_precedence) - 1)
		)
		and gf_semver.parse_semver("1.0.0+build.1") == gf_semver.parse_semver("1.0.0+build.2")
		and gf_semver.parse_semver("1.0.0-01") is None
		and gf_semver.parse_semver("01.0.0") is None
		and gf_semver.parse_semver("1\u0661.0.0") is None
		and gf_semver.parse_semver("1.0.0-\u0661") is None
		and gf_semver.parse_semver("v1.0.0") is None
		and gf_semver.next_major_version("8.2.0-dev.0") == "9.0.0",
		"Python package tooling must share strict SemVer parsing and prerelease precedence.",
	)
	from build_gf_package import make_framework_compatibility_fields
	from gf_package_resolver import compatibility_range_issues

	dev_compatibility_fields = make_framework_compatibility_fields("8.2.0-dev.0")
	record_result(
		"package_build_and_resolver_preserve_prerelease_compatibility",
		dev_compatibility_fields == {
			"minimum_framework_version": "8.2.0-dev.0",
			"maximum_framework_version_exclusive": "9.0.0",
		}
		and any(
			"lower than minimum_framework_version 8.2.0" in issue
			for issue in compatibility_range_issues("registry", "8.2.0-dev.0", "8.2.0", "9.0.0")
		)
		and not compatibility_range_issues("registry", "8.2.0-dev.1", "8.2.0-dev.0", "9.0.0")
		and any(
			"maximum_framework_version_exclusive 9.0.0" in issue
			for issue in compatibility_range_issues("registry", "9.0.0-dev.0", "8.1.0", "9.0.0")
		)
		and any(
			"target GF framework version is not SemVer" in issue
			for issue in compatibility_range_issues("registry", "v8.2.0", "8.1.0", "9.0.0")
		),
		"Package archives and CLI planning must preserve strict SemVer and exclude prereleases from the next compatibility line.",
	)
	record_result(
		"package_suite_includes_long_package_smokes",
		set(PACKAGE_SMOKE_CHECKS).issubset(CHECK_SUITES["package"]),
		"package suite must cover the package build/install/Godot CLI/uninstall smoke checks.",
	)
	record_result(
		"credential_gate_covers_tracked_source_in_light_and_release_flows",
		"credential_gate" in CHECK_DEFINITIONS
		and "credential_gate_tests" in CHECK_DEFINITIONS
		and "credential_gate" in LIGHT_BOUNDARY_CHECKS
		and "credential_gate_tests" in LIGHT_BOUNDARY_CHECKS
		and "credential_gate" in FRAMEWORK_STATIC_CHECKS
		and "credential_gate_tests" in FRAMEWORK_STATIC_CHECKS
		and "credential_gate" in FRAMEWORK_CHECKS
		and "credential_gate_tests" in FRAMEWORK_CHECKS
		and "credential_gate" in FULL_CHECKS
		and "credential_gate_tests" in FULL_CHECKS
		and "credential_gate" in RELEASE_CHECKS
		and "credential_gate_tests" in RELEASE_CHECKS
		and "credential_gate" not in maintenance_in_process_check_runners(),
		"Credential scanning and its behavior tests must remain static gates in quick, full, and release flows.",
	)
	credential_path_fixture = "ghp_" + ("A" * 40)
	credential_safe_release_fixture = safe_release_artifact_report({
		"ok": False,
		"artifacts": [{"path": credential_path_fixture}],
		"issues": [credential_path_fixture],
	})
	credential_safe_dirty_fixture = safe_git_status_labels([
		f"?? {credential_path_fixture}.txt",
	])
	record_result(
		"credential_gate_outputs_are_redacted_and_supervised",
		credential_path_fixture
		not in json.dumps(
			{
				"release": credential_safe_release_fixture,
				"dirty": credential_safe_dirty_fixture,
			},
			ensure_ascii=False,
		)
		and "credential_gate" not in maintenance_in_process_check_runners()
		and "release_metadata" not in maintenance_in_process_check_runners()
		and "release-status" in check_command("release_metadata"),
		"Credential and release scans must use supervised subprocesses and redact manifest/status path values.",
	)
	record_result(
		"codeql_suppression_policy_is_a_tracked_static_gate",
		not hasattr(gf_codeql_suppression_policy, "ALLOWED_SUPPRESSIONS")
		and "codeql_suppression_policy" in CHECK_DEFINITIONS
		and "codeql_suppression_policy_tests" in CHECK_DEFINITIONS
		and {
			"tools/gf_maintenance.py",
			"codeql-suppression-policy",
			"--json",
		}.issubset(CHECK_DEFINITIONS["codeql_suppression_policy"])
		and "codeql_suppression_policy" in LIGHT_BOUNDARY_CHECKS
		and "codeql_suppression_policy_tests" in LIGHT_BOUNDARY_CHECKS
		and all(
			{
				"codeql_suppression_policy",
				"codeql_suppression_policy_tests",
			}.issubset(CHECK_SUITES[suite_name])
			for suite_name in ("quick", "framework-static", "framework", "full", "release")
		)
		and "codeql_suppression_policy" in maintenance_in_process_check_runners()
		and "codeql_suppression_policy_tests" not in maintenance_in_process_check_runners(),
		"CodeQL suppressions must remain forbidden by a tracked-source gate in quick, Full, and release flows.",
	)
	codeql_python_fixture_results = [
		gf_codeql_suppression_policy.audit_python_source(
			"tests/gf_core/tools/test_fixture.py",
			source,
		)
		for source in (
			"# codeql[py/clear-text-storage-sensitive-data]\nsink()\n",
			"# codeql\nsink()\n",
			"# codeql[py/*]\nsink()\n",
			"# codeql[py/one,py/two]\nsink()\n",
			"# lgtm[py/clear-text-storage-sensitive-data]\nsink()\n",
		)
	]
	codeql_allowed_lgtm_result = (
		gf_codeql_suppression_policy.audit_python_source(
			"tests/gf_core/tools/test_fixture.py",
			"# LGTM after validation\nsink()\n",
		)
	)
	codeql_config_fixture_issues = gf_codeql_suppression_policy.audit_codeql_config(
		".github/codeql/codeql-config.yml",
		"disable-default-queries: true\n"
		"paths-ignore:\n"
		"  - tests/**\n"
		"query-filters:\n"
		"  - exclude:\n"
		"      id: py/clear-text-storage-sensitive-data\n",
	)
	codeql_safe_yaml_issues = gf_codeql_suppression_policy.audit_codeql_config(
		".github/workflows/codeql.yml",
		'name: "CodeQL review prose\n'
		'  queries: harmless"\n'
		"steps:\n"
		"  - run: |2\n"
		"      query-filters: harmless\n"
		"some.input: harmless\n"
		"url: https://example.invalid/#paths-ignore\n",
	)
	codeql_structural_yaml_issues = (
		gf_codeql_suppression_policy.audit_codeql_config(
			".github/workflows/codeql.yml",
			"\ufeffname: CodeQL\n"
			"steps:\n"
			"  - run: |\n"
			"      echo queries: harmless\n"
			"    queries: ./security/custom.qls\n"
			"with: {paths-ignore:, other: 1}\n"
			"? *indirect_key\n"
			": harmless\n",
		)
	)
	codeql_escaped_key_issues = gf_codeql_suppression_policy.audit_codeql_config(
		".github/workflows/codeql.yml",
		'name: CodeQL\n? "quer\\\n  ies"\n: ./security/custom.qls\n',
	)
	record_result(
		"codeql_suppression_policy_rejects_broad_escape_hatches",
		all(
			issues
			and suppression_count == 1
			for issues, suppression_count in codeql_python_fixture_results
		)
		and {
			"codeql_suppression.python_directive_forbidden",
		} == {
			str(issue.get("kind", ""))
			for issues, _suppression_count in codeql_python_fixture_results[:-1]
			for issue in issues
		}
		and {
			"codeql_suppression.legacy_lgtm_directive",
		} == {
			str(issue.get("kind", ""))
			for issue in codeql_python_fixture_results[-1][0]
		}
		and codeql_allowed_lgtm_result == ([], 0)
		and {
			"codeql_suppression.default_queries_disabled",
			"codeql_suppression.tests_path_ignored",
			"codeql_suppression.security_query_excluded",
		} == {
			str(issue.get("kind", ""))
			for issue in codeql_config_fixture_issues
		}
		and not codeql_safe_yaml_issues
		and {
			"codeql_suppression.complex_mapping_key_forbidden",
			"codeql_suppression.custom_queries_forbidden",
			"codeql_suppression.tests_path_ignored",
		} == {
			str(issue.get("kind", ""))
			for issue in codeql_structural_yaml_issues
		}
		and {
			"codeql_suppression.custom_queries_forbidden",
			"codeql_suppression.yaml_line_continuation_forbidden",
		} == {
			str(issue.get("kind", ""))
			for issue in codeql_escaped_key_issues
		}
		and callable(gf_path_security.read_pinned_utf8_regular_file)
		and gf_credential_gate.SUPPRESSION_RE.fullmatch(
			"# codeql[py/clear-text-storage-sensitive-data]"
		) is None,
		"All Python CodeQL suppressions and CodeQL configuration escape hatches must fail; credential-gate allowances remain independent.",
	)
	record_result(
		"ci_shards_preserve_full_suite_coverage",
		set(FRAMEWORK_CHECKS) == set(FRAMEWORK_GUT_CHECKS).union(
			FRAMEWORK_LSP_CHECKS,
			FRAMEWORK_STATIC_CHECKS,
		)
		and all(
			left.isdisjoint(right)
			for index, left in enumerate((
				set(FRAMEWORK_GUT_CHECKS),
				set(FRAMEWORK_LSP_CHECKS),
				set(FRAMEWORK_STATIC_CHECKS),
			))
			for right in (
				set(FRAMEWORK_GUT_CHECKS),
				set(FRAMEWORK_LSP_CHECKS),
				set(FRAMEWORK_STATIC_CHECKS),
			)[index + 1:]
		)
		and set(FULL_CHECKS) == set(FRAMEWORK_GUT_CHECKS).union(
			FRAMEWORK_LSP_CHECKS,
			FRAMEWORK_STATIC_CHECKS,
			PACKAGE_CONTRACT_CHECKS,
			PACKAGE_EDITOR_CHECKS,
			PACKAGE_CLI_CHECKS,
			{"package_godot_smoke"},
		)
		and set(PACKAGE_CI_CHECKS) == set(PACKAGE_CONTRACT_CHECKS).union(
			PACKAGE_EDITOR_CHECKS,
			PACKAGE_CLI_CHECKS,
			{"package_godot_smoke"},
		),
		"parallel framework partitions and package matrix shards must be disjoint within framework and set-equivalent to full/package-ci.",
	)
	parallel_validation_plan = _VALIDATION_CATALOG.plan("full")
	parallel_plan = parallel_full_shard_plan(parallel_validation_plan)
	parallel_plan_names = tuple(shard.name for shard in parallel_plan)
	framework_gut_shard = next(
		shard for shard in parallel_plan if shard.name == "framework-gut"
	)
	ci_jobs, ci_duplicate_jobs = gf_repository_policy.extract_ci_job_blocks(ci_workflow_source)
	release_jobs, release_duplicate_jobs = gf_repository_policy.extract_ci_job_blocks(
		release_workflow_source
	)
	manual_jobs, manual_duplicate_jobs = gf_repository_policy.extract_ci_job_blocks(
		manual_ci_workflow_source
	)
	ci_framework_gut_timeout_value = gf_repository_policy.extract_matrix_suite_scalar(
		ci_jobs.get("framework-checks", ""),
		"framework-gut",
		"timeout_minutes",
	)
	release_framework_job = release_jobs.get("release-framework-checks", "")
	release_framework_step = gf_repository_policy.extract_ci_step_block(
		release_framework_job,
		"Run release framework shard",
	)
	release_framework_command = gf_repository_policy.extract_yaml_scalar(
		release_framework_step,
		"run",
		8,
	)
	release_framework_timeout_value = gf_repository_policy.extract_yaml_scalar(
		release_framework_job,
		"timeout-minutes",
		4,
	)
	manual_full_timeout_value = gf_repository_policy.extract_yaml_scalar(
		manual_jobs.get("manual-full-validation", ""),
		"timeout-minutes",
		4,
	)
	parallel_batch_names_by_jobs = {
		jobs: tuple(
			tuple(shard.name for shard in batch)
			for batch in parallel_full_shard_batches(parallel_plan, jobs)
		)
		for jobs in range(1, MAX_PARALLEL_FULL_JOBS + 1)
	}
	parallel_owned_checks = [
		check_name
		for shard in parallel_plan
		for check_name in shard.checks
	]
	record_result(
		"local_parallel_full_plan_has_unique_set_equivalent_ownership",
		set(parallel_owned_checks) == set(FULL_CHECKS)
		and len(parallel_owned_checks) == len(set(parallel_owned_checks))
		and parallel_plan_names == PARALLEL_FULL_SHARD_SUITES
		and next(
			shard.name
			for shard in parallel_plan
			if "gdscript_lsp_diagnostics" in shard.checks
		) == "framework-lsp",
		"Local parallel Full must assign every target check exactly once and keep LSP owned by its hard-gate shard.",
	)
	record_result(
		"local_parallel_full_schedule_separates_heavy_shards",
		parallel_plan_names == (
			"package-editor",
			"framework-static",
			"package-godot-ci",
			"package-cli-local",
			"package-cli-network",
			"package-contract",
			"framework-gut",
			"framework-lsp",
		)
		and parallel_batch_names_by_jobs[2] == (
			("package-editor", "framework-static"),
			("package-godot-ci", "package-cli-local"),
			("package-cli-network", "package-contract"),
			("framework-gut",),
			("framework-lsp",),
		)
		and parallel_batch_names_by_jobs[3] == (
			("package-editor", "framework-static", "package-godot-ci"),
			("package-cli-local", "package-cli-network", "package-contract"),
			("framework-gut",),
			("framework-lsp",),
		)
		and all(
			tuple(name for batch in batches for name in batch) == parallel_plan_names
			and all(1 <= len(batch) <= jobs for batch in batches)
			and tuple(
				batch for batch in batches if "framework-gut" in batch
			) == (("framework-gut",),)
			for jobs, batches in parallel_batch_names_by_jobs.items()
		),
		(
			"Local parallel Full must preserve stable shard ownership and run the "
			"resource-intensive framework GUT shard in its own batch."
		),
	)
	deadline_fixture_snapshot = CapturedWorkspace(
		source_root=ROOT,
		head="1" * 40,
		binary_diff=b"",
		untracked_files=(),
		workspace_fingerprint="2" * 64,
	)
	deadline_fixture_result = make_parallel_full_deadline_result(
		deadline_fixture_snapshot,
		parallel_plan,
		DEFAULT_PARALLEL_FULL_JOBS,
		1,
		validation_plan=parallel_validation_plan,
	)
	deadline_fixture_canonical_checks = list(parallel_validation_plan.actions)
	record_result(
		"parallel_deadline_reports_canonical_but_unstarted_results",
		deadline_fixture_result.get("completed_check_count") == 0
		and deadline_fixture_result.get("checks") == deadline_fixture_canonical_checks
		and deadline_fixture_result.get("canonical_result_count") == len(deadline_fixture_canonical_checks)
		and deadline_fixture_result.get("not_started_check_count") == len(deadline_fixture_canonical_checks)
		and [
			item.get("name")
			for item in deadline_fixture_result.get("results", [])
		] == deadline_fixture_canonical_checks
		and all(
			item.get("execution") == "not_started"
			and item.get("exit_code") == 124
			and item.get("timed_out") is True
			for item in deadline_fixture_result.get("results", [])
		),
		"A pre-worker deadline must distinguish canonical placeholders from completed checks.",
	)
	invalid_parallel_job_requests_rejected = False
	try:
		resolve_check_jobs("quick", None, 2)
	except ValueError:
		try:
			resolve_check_jobs("full", ["api"], 2)
		except ValueError:
			try:
				resolve_check_jobs("full", None, MAX_PARALLEL_FULL_JOBS + 1)
			except ValueError:
				invalid_parallel_job_requests_rejected = True
	record_result(
		"local_parallel_full_jobs_are_bounded_with_serial_escape",
		resolve_check_jobs("full", None, 0) == DEFAULT_PARALLEL_FULL_JOBS
		and resolve_check_jobs("full", None, 1) == 1
		and resolve_check_jobs("full", None, 2) == 2
		and resolve_check_jobs("quick", None, 0) == 1
		and invalid_parallel_job_requests_rejected,
		"Full parallelism must stay bounded, expose jobs=1 diagnostics, and reject ambiguous suite/check combinations.",
	)
	fixture_package_command = check_command(
		"package_build_boundary",
		"C:/fixture/gf-package-artifact-set.json",
		"a" * 64,
	)
	record_result(
		"parallel_full_shards_preserve_check_timeout_minima_and_scope_artifact_inputs",
		set(PARALLEL_FULL_SHARD_TIMEOUT_SECONDS) == set(PARALLEL_FULL_SHARD_SUITES)
		and all(value > 0 for value in PARALLEL_FULL_SHARD_TIMEOUT_SECONDS.values())
		and all(
			parallel_shard_timeout_seconds(shard, 3600)
			>= len(expanded_check_names("quick", list(shard.checks))) * 3600
			for shard in parallel_plan
		)
		and parallel_shard_timeout_seconds(framework_gut_shard, None) == 2820
		and "--package-artifact-manifest" in fixture_package_command
		and "--package-artifact-manifest-sha256" in fixture_package_command
		and "--package-artifact-manifest" not in check_command("api"),
		"Each shard budget must preserve every child check's requested minimum, while immutable package inputs reach only consumers.",
	)
	record_result(
		"workflow_deadlines_preserve_the_closed_framework_gut_envelope",
		not ci_duplicate_jobs
		and not release_duplicate_jobs
		and not manual_duplicate_jobs
		and ci_framework_gut_timeout_value
		== str(gf_repository_policy.FRAMEWORK_GUT_CI_TIMEOUT_MINUTES)
		and release_framework_timeout_value
		== str(gf_repository_policy.RELEASE_FRAMEWORK_TIMEOUT_MINUTES)
		and manual_full_timeout_value == str(gf_repository_policy.MANUAL_FULL_TIMEOUT_MINUTES)
		and release_framework_command == gf_repository_policy.RELEASE_FRAMEWORK_COMMAND
		and gf_repository_policy.FRAMEWORK_GUT_CI_TIMEOUT_MINUTES * 60
		> parallel_shard_timeout_seconds(framework_gut_shard, None)
		and gf_repository_policy.RELEASE_FRAMEWORK_TIMEOUT_MINUTES * 60
		> gf_repository_policy.RELEASE_FRAMEWORK_SUITE_TIMEOUT_SECONDS,
		(
			"Ready/main framework GUT must retain its exact 60-minute outer deadline above "
			"the 2,820-second child envelope; release framework must retain a 4,800-second "
			"maintenance deadline within its exact 90-minute outer deadline; manual Full "
			"must remain 90 minutes."
		),
	)
	record_result(
		"release_shards_preserve_release_suite_coverage",
		set(RELEASE_CHECKS) == set(FRAMEWORK_CHECKS).union(
			PACKAGE_CONTRACT_CHECKS,
			PACKAGE_EDITOR_CHECKS,
			PACKAGE_CLI_CHECKS,
			{"package_godot_matrix_smoke", "release_metadata"},
		)
		and set(PACKAGE_RELEASE_CHECKS) == set(PACKAGE_CONTRACT_CHECKS).union(
			PACKAGE_EDITOR_CHECKS,
			PACKAGE_CLI_CHECKS,
			{"package_godot_matrix_smoke"},
		),
		"parallel release matrix shards plus release metadata must be set-equivalent to the release and package-release suites.",
	)
	record_result(
		"long_package_smokes_have_dedicated_timeout_budgets",
		resolve_check_timeout_seconds("ai_developer_adapter_acceptance", None) == 900
		and resolve_check_timeout_seconds("ai_developer_adapter_acceptance", 45) == 900
		and resolve_check_timeout_seconds("package_editor_wizard_smoke", None) == 1200
		and resolve_check_timeout_seconds("package_editor_wizard_smoke", 45) == 1200
		and resolve_check_timeout_seconds("package_godot_cli_smoke", None) == 2400
		and resolve_check_timeout_seconds("package_godot_cli_smoke", 45) == 2400
		and resolve_check_timeout_seconds("package_godot_cli_local_smoke", None) == 1200
		and resolve_check_timeout_seconds("package_godot_cli_network_smoke", None) == 1200
		and resolve_check_timeout_seconds("package_godot_matrix_smoke", None) == 2400
		and resolve_check_timeout_seconds("package_godot_matrix_smoke", 45) == 2400
		and resolve_check_timeout_seconds("api", None)
		== _VALIDATION_CATALOG.default_timeout_seconds
		and resolve_check_timeout_seconds("api", 900) == 900,
		"generic timeout settings may raise budgets but must not erase measured longer check policies.",
	)
	record_result(
		"in_process_checks_enforce_return_time_deadlines",
		in_process_check_timed_out(10.001, 10.0)
		and not in_process_check_timed_out(10.0, 10.0),
		"In-process pure checks must fail when they return after their deadline.",
	)
	record_result(
		"static_suite_checks_run_in_process",
		{
			"api",
			"ai_api",
			"docs",
			"changelog_policy",
			"public_docs_boundary",
			"public_api_boundary",
			"package_source_boundary",
			"dependency_boundary",
			"maintenance_self_test",
		}.issubset(maintenance_in_process_check_runners()),
		"pure static checks should reuse one maintenance process while external Godot and package smokes remain isolated.",
	)
	record_result(
		"changelog_policy_is_a_quick_full_release_gate",
		"changelog_policy" in CHECK_DEFINITIONS
		and "changelog_policy" in maintenance_in_process_check_runners()
		and all(
			"changelog_policy" in set(CHECK_SUITES[suite_name])
			for suite_name in (
				"docs",
				"quick",
				"framework-static",
				"framework",
				"full",
				"release",
			)
		),
		"the current changelog state and entry template must fail before commit and release, not only inside release-status.",
	)
	record_result(
		"gdscript_lsp_diagnostics_is_a_full_and_release_hard_gate",
		all(
			"gdscript_lsp_diagnostics" in set(CHECK_SUITES[suite_name])
			for suite_name in ("full", "release", "framework", "framework-lsp")
		)
		and all(
			"gdscript_lsp_diagnostics" not in set(CHECK_SUITES[suite_name])
			for suite_name in (
				"api",
				"docs",
				"examples",
				"quick",
				"package",
				"framework-gut",
				"framework-static",
			)
		),
		"Full, release, and their framework shard must fail on LSP diagnostics without making lighter suites run the editor scan.",
	)
	gdscript_lsp_command = CHECK_DEFINITIONS["gdscript_lsp_diagnostics"]
	record_result(
		"gdscript_lsp_diagnostics_uses_strict_hard_gate_severities",
		"--allow-diagnostics" not in gdscript_lsp_command
		and "--fail-severity" in gdscript_lsp_command
		and gdscript_lsp_command[gdscript_lsp_command.index("--fail-severity") + 1] == "error,warning",
		"Full and release LSP diagnostics must fail explicitly on both errors and warnings.",
	)
	gdscript_lsp_include_roots = [
		gdscript_lsp_command[index + 1]
		for index, value in enumerate(gdscript_lsp_command[:-1])
		if value == "--include"
	]
	gdscript_lsp_excluded_roots = [
		gdscript_lsp_command[index + 1]
		for index, value in enumerate(gdscript_lsp_command[:-1])
		if value == "--exclude-prefix"
	]
	record_result(
		"gdscript_lsp_diagnostics_keeps_framework_and_test_scan_roots",
		gdscript_lsp_include_roots == ["addons/gf", "tests/gf_core"]
		and gdscript_lsp_excluded_roots == ["addons/gut"],
		"The hard gate must scan GF runtime and gf_core tests while excluding vendored GUT sources.",
	)
	record_result(
		"gdscript_lsp_diagnostics_uses_scaled_timeout_retries",
		"--connect-or-spawn" in gdscript_lsp_command
		and "--spawn-lsp" not in gdscript_lsp_command
		and gdscript_lsp_command[gdscript_lsp_command.index("--port") + 1] == "6005"
		and "--max-file-timeout" in gdscript_lsp_command
		and "--timeout-retries" in gdscript_lsp_command,
		"GDScript LSP diagnostics should reuse an active editor and use scaled timeout retries.",
	)
	gdscript_lsp_source = read_text_file(ROOT / "tools/gdscript_lsp_diagnostics.py")
	record_result(
		"gdscript_lsp_diagnostics_preserves_existing_editor_buffers",
		"workspace/didChangeWatchedFiles" not in gdscript_lsp_source
		and "textDocument/didChange" not in gdscript_lsp_source,
		"connected LSP diagnostics must not broadcast disk changes over an editor's unsaved buffers.",
	)
	record_result(
		"gdscript_lsp_connected_mode_writes_auditable_result",
		"_write_connection_audit_log" in gdscript_lsp_source
		and '"mode": "connected"' in gdscript_lsp_source,
		"connected LSP diagnostics must persist an auditable result without requiring a spawned Godot log.",
	)
	record_result(
		"gdscript_lsp_rejects_cross_project_ports",
		'client.request("textDocument/definition"' in gdscript_lsp_source
		and "_uri_is_within_project" in gdscript_lsp_source
		and "Connected Godot LSP workspace mismatch" in gdscript_lsp_source,
		"connected LSP diagnostics must prove that class definitions resolve inside the requested project root.",
	)
	leak_fixture_warnings = collect_godot_exit_leak_warnings(
		"ERROR: 3 RID allocations of type 'DummyTexture' were leaked at exit.",
		"\n".join([
			"WARNING: ObjectDB instances leaked at exit (run with --verbose for details).",
			"ERROR: 137 resources still in use at exit (run with --verbose for details).",
		]),
	)
	record_result(
		"godot_exit_leak_parser_captures_object_resource_and_rid_leaks",
		len(leak_fixture_warnings) == 3,
		f"expected 3 leak warning lines, got {leak_fixture_warnings}",
	)
	leak_report_fixture = make_empty_godot_exit_leak_report()
	for line in [
		"\x1b[31mERROR: 2 RID allocations of type 'DummyTexture' were leaked at exit.\x1b[0m",
		"WARNING: ObjectDB instances leaked at exit (run with --verbose for details).",
		"ERROR: 5 resources still in use at exit.",
		"Resource still in use: res://addons/gf/kernel/core/gf.gd (GDScript)",
		"Resource still in use: res://addons/gut/gui/NormalGui.tscn (PackedScene)",
		"Leaked instance: SceneTreeTimer:9223373801834751926 - Reference count: 1",
	]:
		parse_godot_exit_leak_line(line, leak_report_fixture)
	record_result(
		"godot_exit_leak_report_groups_rid_resource_and_instance_counts",
		(
			leak_report_fixture["objectdb_warning_count"] == 1
			and leak_report_fixture["resource_summary_total"] == 5
			and leak_report_fixture["resource_still_in_use_count"] == 2
			and leak_report_fixture["rid_allocation_total"] == 2
			and leak_report_fixture["leaked_instance_total"] == 1
			and leak_report_fixture["_rid_allocations"].get("DummyTexture") == 2
			and leak_report_fixture["_resource_type_counts"].get("GDScript") == 1
			and leak_report_fixture["_resource_type_counts"].get("PackedScene") == 1
			and leak_report_fixture["_resource_path_prefix_counts"].get("res://addons/gf/kernel") == 1
			and leak_report_fixture["_resource_path_prefix_counts"].get("res://addons/gut") == 1
			and leak_report_fixture["_leaked_instance_types"].get("SceneTreeTimer") == 1
		),
		f"unexpected leak report fixture: {leak_report_fixture}",
	)
	output_leak_report = godot_exit_leak_report_from_output(
		"fixture",
		"\n".join([
			"ERROR: 2 RID allocations of type 'DummyTexture' were leaked at exit.",
			"Leaked instance: Object:819718004321",
		]),
		"WARNING: ObjectDB instances leaked at exit (run with --verbose for details).",
	)
	record_result(
		"godot_exit_leak_report_from_output_groups_stdout_and_stderr",
		(
			output_leak_report["has_leaks"]
			and output_leak_report["objectdb_warning_count"] == 1
			and output_leak_report["rid_allocation_total"] == 2
			and output_leak_report["leaked_instance_total"] == 1
			and len(output_leak_report["logs"]) == 2
			and output_leak_report["leaked_instance_types"][0]["key"] == "Object"
		),
		f"unexpected output leak report: {output_leak_report}",
	)
	godot_47_summary_report = godot_exit_leak_report_from_output(
		"godot_47_fixture",
		"",
		"\n".join([
			"WARNING: 235 ObjectDB instances were leaked at exit (run with `--verbose` for details).",
			"ERROR: 113 resources still in use at exit (run with --verbose for details).",
		]),
	)
	record_result(
		"godot_exit_leak_report_accepts_current_summary_format",
		godot_47_summary_report["has_leaks"]
		and godot_47_summary_report["objectdb_warning_count"] == 1
		and godot_47_summary_report["objectdb_instance_total"] == 235
		and godot_47_summary_report["resource_summary_count"] == 1
		and godot_47_summary_report["resource_summary_total"] == 113,
		f"Godot 4.7 summary lines must be structured hard-gate evidence: {godot_47_summary_report}",
	)
	singular_objectdb_line = (
		"WARNING: 1 ObjectDB instance was leaked at exit (run with `--verbose` for details)."
	)
	singular_objectdb_report = godot_exit_leak_report_from_output(
		"godot_47_singular_fixture",
		"",
		singular_objectdb_line,
	)
	record_result(
		"godot_exit_leak_report_accepts_singular_objectdb_summary",
		collect_godot_exit_leak_warnings("", singular_objectdb_line) == [singular_objectdb_line]
		and singular_objectdb_report["has_leaks"]
		and singular_objectdb_report["objectdb_warning_count"] == 1
		and singular_objectdb_report["objectdb_instance_total"] == 1,
		f"A one-instance Godot leak must remain structured hard-gate evidence: {singular_objectdb_report}",
	)
	future_leak_report = godot_exit_leak_report_from_output(
		"future_leak_fixture",
		"WARNING: 3 objects were leaked at exit.",
		"",
	)
	record_result(
		"godot_exit_leak_report_fails_closed_on_unclassified_leak_evidence",
		future_leak_report["has_leaks"]
		and future_leak_report["warning_lines"] == [
			"WARNING: 3 objects were leaked at exit."
		],
		f"Raw leak evidence must remain a hard gate when Godot changes its summary format: {future_leak_report}",
	)
	command_payload = CommandResult(
		"fixture",
		["godot", "--headless"],
		0,
		"",
		"",
		godot_exit_leak_report=output_leak_report,
	).to_dict()
	record_result(
		"command_result_exposes_structured_godot_exit_leak_report",
		command_payload.get("godot_exit_leak_report", {}).get("rid_allocation_total") == 2,
		f"unexpected command payload: {command_payload}",
	)
	record_result(
		"addons_kernel_package_tools_removed_from_plugin_tree",
		not (ROOT / "addons/gf/kernel/package_tools").exists(),
		"Python package manager maintenance tools must live under tools/ only; ordinary users should install GF with Godot alone.",
	)
	layer_boundary_constants = read_layer_boundary_manifest_constants()
	record_result(
		"layer_boundary_allowed_dependencies_match_python_tool",
		set(layer_boundary_constants.get("EXTENSION_ALLOWED_DEPENDENCIES", [])) == set(GF_ALLOWED_EXTENSION_DEPENDENCIES),
		format_set_mismatch(
			"tests/gf_core/maintenance/test_layer_boundary_validation.gd EXTENSION_ALLOWED_DEPENDENCIES",
			set(layer_boundary_constants.get("EXTENSION_ALLOWED_DEPENDENCIES", [])),
			"tools/gf_maintenance.py GF_ALLOWED_EXTENSION_DEPENDENCIES",
			set(GF_ALLOWED_EXTENSION_DEPENDENCIES),
		),
	)
	record_result(
		"layer_boundary_allowed_manifest_fields_match_python_tool",
		set(layer_boundary_constants.get("EXTENSION_ALLOWED_MANIFEST_FIELDS", [])) == GF_MANIFEST_ALLOWED_FIELDS,
		format_set_mismatch(
			"tests/gf_core/maintenance/test_layer_boundary_validation.gd EXTENSION_ALLOWED_MANIFEST_FIELDS",
			set(layer_boundary_constants.get("EXTENSION_ALLOWED_MANIFEST_FIELDS", [])),
			"tools/gf_maintenance.py GF_MANIFEST_ALLOWED_FIELDS",
			GF_MANIFEST_ALLOWED_FIELDS,
		),
	)
	record_result(
		"layer_boundary_forbidden_manifest_fields_match_python_tool",
		set(layer_boundary_constants.get("EXTENSION_FORBIDDEN_MANIFEST_FIELDS", [])) == GF_MANIFEST_FORBIDDEN_RELATION_FIELDS,
		format_set_mismatch(
			"tests/gf_core/maintenance/test_layer_boundary_validation.gd EXTENSION_FORBIDDEN_MANIFEST_FIELDS",
			set(layer_boundary_constants.get("EXTENSION_FORBIDDEN_MANIFEST_FIELDS", [])),
			"tools/gf_maintenance.py GF_MANIFEST_FORBIDDEN_RELATION_FIELDS",
			GF_MANIFEST_FORBIDDEN_RELATION_FIELDS,
		),
	)
	layer_extension_infrastructure_paths = set(normalize_res_paths(
		layer_boundary_constants.get("KERNEL_EXTENSION_INFRASTRUCTURE_PATHS", [])
	))
	record_result(
		"layer_boundary_extension_infrastructure_paths_match_python_tool",
		layer_extension_infrastructure_paths == GF_EXTENSION_INFRASTRUCTURE_PATHS,
		format_set_mismatch(
			"tests/gf_core/maintenance/test_layer_boundary_validation.gd KERNEL_EXTENSION_INFRASTRUCTURE_PATHS",
			layer_extension_infrastructure_paths,
			"tools/gf_maintenance.py GF_EXTENSION_INFRASTRUCTURE_PATHS",
			GF_EXTENSION_INFRASTRUCTURE_PATHS,
		),
	)
	record_result(
		"manifest_and_tool_contribution_path_authorities_are_disjoint",
		GF_MANIFEST_ALLOWED_FIELDS.isdisjoint(GF_TOOL_CONTRIBUTION_PATH_FIELDS),
		"Editor/tool path fields must be owned only by GF_TOOL_CONTRIBUTION_PATH_FIELDS.",
	)
	tool_contribution_constants = read_extension_tool_contribution_constants()
	record_result(
		"tool_contribution_schema_version_matches_runtime",
		tool_contribution_constants.get("SCHEMA_VERSION") == GF_TOOL_CONTRIBUTION_SCHEMA_VERSION,
		"Python dependency gate and GFExtensionToolContribution must use the same schema version.",
	)
	record_result(
		"tool_contribution_path_fields_match_runtime",
		set(tool_contribution_constants.get("PATH_FIELDS", [])) == GF_TOOL_CONTRIBUTION_PATH_FIELDS,
		format_set_mismatch(
			"GFExtensionToolContribution.PATH_FIELDS",
			set(tool_contribution_constants.get("PATH_FIELDS", [])),
			"tools/gf_maintenance.py GF_TOOL_CONTRIBUTION_PATH_FIELDS",
			GF_TOOL_CONTRIBUTION_PATH_FIELDS,
		),
	)
	record_result(
		"tool_contribution_allowed_fields_match_runtime",
		set(tool_contribution_constants.get("ALLOWED_FIELDS", [])) == GF_TOOL_CONTRIBUTION_ALLOWED_FIELDS,
		format_set_mismatch(
			"GFExtensionToolContribution.ALLOWED_FIELDS",
			set(tool_contribution_constants.get("ALLOWED_FIELDS", [])),
			"tools/gf_maintenance.py GF_TOOL_CONTRIBUTION_ALLOWED_FIELDS",
			GF_TOOL_CONTRIBUTION_ALLOWED_FIELDS,
		),
	)
	valid_tool_contribution_record = {
		"path": "addons/gf/extensions/fixture/editor/gf_tool_contribution.json",
		"root_path": "addons/gf/extensions/fixture",
		"extension_id": "gf.fixture",
		"data": {
			"schema_version": GF_TOOL_CONTRIBUTION_SCHEMA_VERSION,
			"extension_id": "gf.fixture",
			"debugger_plugin_paths": [],
		},
		"error": "",
	}
	record_result(
		"dependency_boundary_accepts_valid_tool_contribution_schema",
		len(audit_bundled_tool_contributions([valid_tool_contribution_record])) == 0,
		"valid tool contribution schema fixture should pass.",
	)
	legacy_tool_contribution_record = dict(valid_tool_contribution_record)
	legacy_tool_contribution_record["data"] = {
		"schema_version": GF_TOOL_CONTRIBUTION_SCHEMA_VERSION - 1,
		"extension_id": "gf.fixture",
	}
	record_result(
		"dependency_boundary_rejects_legacy_tool_contribution_schema",
		issue_exists(
			audit_bundled_tool_contributions([legacy_tool_contribution_record]),
			"unsupported_tool_contribution_schema_version",
		),
		"Legacy tool contribution schema versions must fail closed instead of entering a compatibility path.",
	)
	float_tool_contribution_record = dict(valid_tool_contribution_record)
	float_tool_contribution_record["data"] = {
		"schema_version": float(GF_TOOL_CONTRIBUTION_SCHEMA_VERSION),
		"extension_id": "gf.fixture",
	}
	bool_tool_contribution_record = dict(valid_tool_contribution_record)
	bool_tool_contribution_record["data"] = {
		"schema_version": True,
		"extension_id": "gf.fixture",
	}
	fractional_tool_contribution_record = dict(valid_tool_contribution_record)
	fractional_tool_contribution_record["data"] = {
		"schema_version": 1.5,
		"extension_id": "gf.fixture",
	}
	non_finite_tool_contribution_record = dict(valid_tool_contribution_record)
	non_finite_tool_contribution_record["data"] = {
		"schema_version": float("nan"),
		"extension_id": "gf.fixture",
	}
	record_result(
		"tool_contribution_numeric_contract_matches_runtime",
		not audit_bundled_tool_contributions([float_tool_contribution_record])
		and issue_exists(
			audit_bundled_tool_contributions([bool_tool_contribution_record]),
			"unsupported_tool_contribution_schema_version",
		)
		and issue_exists(
			audit_bundled_tool_contributions([fractional_tool_contribution_record]),
			"unsupported_tool_contribution_schema_version",
		)
		and issue_exists(
			audit_bundled_tool_contributions([non_finite_tool_contribution_record]),
			"unsupported_tool_contribution_schema_version",
		),
		"Python contribution validation must accept finite integral floats and reject bool/fractional values like runtime.",
	)
	invalid_tool_contribution_record = dict(valid_tool_contribution_record)
	invalid_tool_contribution_record["data"] = {
		"schema_version": GF_TOOL_CONTRIBUTION_SCHEMA_VERSION + 1,
		"extension_id": "gf.other",
		"unknown_field": True,
		"editor_action_paths": "editor/action.gd",
	}
	invalid_tool_contribution_issues = audit_bundled_tool_contributions([
		invalid_tool_contribution_record,
	])
	record_result(
		"dependency_boundary_rejects_invalid_tool_contribution_schema",
		issue_exists(invalid_tool_contribution_issues, "unsupported_tool_contribution_schema_version")
		and issue_exists(invalid_tool_contribution_issues, "tool_contribution_extension_id_mismatch")
		and issue_exists(
			invalid_tool_contribution_issues,
			"unsupported_tool_contribution_field",
			field="unknown_field",
		)
		and issue_exists(
			invalid_tool_contribution_issues,
			"invalid_tool_contribution_path_field",
			field="editor_action_paths",
		),
		f"invalid tool contribution fixture was not fully rejected: {invalid_tool_contribution_issues}",
	)
	manifest_constants = read_extension_manifest_constants()
	record_result(
		"manifest_runtime_supported_fields_match_bundled_fields",
		set(manifest_constants.get("_SUPPORTED_FIELDS", [])) == GF_MANIFEST_ALLOWED_FIELDS,
		format_set_mismatch(
			"addons/gf/kernel/extension/gf_extension_manifest.gd _SUPPORTED_FIELDS",
			set(manifest_constants.get("_SUPPORTED_FIELDS", [])),
			"tools/gf_maintenance.py GF_MANIFEST_ALLOWED_FIELDS",
			GF_MANIFEST_ALLOWED_FIELDS,
		),
	)
	record_result(
		"manifest_runtime_forbidden_relation_fields_match_python_tool",
		set(manifest_constants.get("_FORBIDDEN_RELATION_FIELDS", [])) == GF_MANIFEST_FORBIDDEN_RELATION_FIELDS,
		format_set_mismatch(
			"addons/gf/kernel/extension/gf_extension_manifest.gd _FORBIDDEN_RELATION_FIELDS",
			set(manifest_constants.get("_FORBIDDEN_RELATION_FIELDS", [])),
			"tools/gf_maintenance.py GF_MANIFEST_FORBIDDEN_RELATION_FIELDS",
			GF_MANIFEST_FORBIDDEN_RELATION_FIELDS,
		),
	)
	preset_constants = read_extension_preset_constants()
	record_result(
		"preset_allowed_fields_match_runtime",
		set(preset_constants.get("_SUPPORTED_FIELDS", [])) == GF_PRESET_ALLOWED_FIELDS,
		format_set_mismatch(
			"addons/gf/kernel/extension/gf_extension_preset.gd _SUPPORTED_FIELDS",
			set(preset_constants.get("_SUPPORTED_FIELDS", [])),
			"tools/gf_maintenance.py GF_PRESET_ALLOWED_FIELDS",
			GF_PRESET_ALLOWED_FIELDS,
		),
	)
	record_result(
		"preset_forbidden_relation_fields_match_runtime",
		set(preset_constants.get("_FORBIDDEN_RELATION_FIELDS", [])) == GF_PRESET_FORBIDDEN_RELATION_FIELDS,
		format_set_mismatch(
			"addons/gf/kernel/extension/gf_extension_preset.gd _FORBIDDEN_RELATION_FIELDS",
			set(preset_constants.get("_FORBIDDEN_RELATION_FIELDS", [])),
			"tools/gf_maintenance.py GF_PRESET_FORBIDDEN_RELATION_FIELDS",
			GF_PRESET_FORBIDDEN_RELATION_FIELDS,
		),
	)
	record_result(
		"preset_forbidden_package_fields_match_runtime",
		set(preset_constants.get("_FORBIDDEN_PACKAGE_FIELDS", [])) == GF_PRESET_FORBIDDEN_PACKAGE_FIELDS,
		format_set_mismatch(
			"addons/gf/kernel/extension/gf_extension_preset.gd _FORBIDDEN_PACKAGE_FIELDS",
			set(preset_constants.get("_FORBIDDEN_PACKAGE_FIELDS", [])),
			"tools/gf_maintenance.py GF_PRESET_FORBIDDEN_PACKAGE_FIELDS",
			GF_PRESET_FORBIDDEN_PACKAGE_FIELDS,
		),
	)

	forbidden_field_data = make_manifest_test_data()
	for field_name in GF_MANIFEST_FORBIDDEN_RELATION_FIELDS:
		forbidden_field_data[field_name] = []
	forbidden_field_issues = audit_bundled_extension_manifests([
		make_manifest_test_record("fixture", forbidden_field_data),
	])
	for field_name in sorted(GF_MANIFEST_FORBIDDEN_RELATION_FIELDS):
		record_result(
			f"forbidden_manifest_relation_field_{field_name}",
			issue_exists(forbidden_field_issues, "forbidden_manifest_relation_field", field=field_name),
			f"missing forbidden relation issue for field {field_name!r}.",
		)
		record_result(
			f"unsupported_manifest_field_{field_name}",
			issue_exists(forbidden_field_issues, "unsupported_manifest_field", field=field_name),
			f"missing unsupported field issue for field {field_name!r}.",
		)

	valid_preset_issues = audit_extension_preset_data(make_preset_test_data(), "preset-fixture")
	record_result(
		"valid_extension_preset_fixture_has_no_issues",
		len(valid_preset_issues) == 0,
		f"unexpected preset issues: {valid_preset_issues}",
	)

	forbidden_preset_relation_data = make_preset_test_data()
	for field_name in GF_PRESET_FORBIDDEN_RELATION_FIELDS:
		forbidden_preset_relation_data[field_name] = []
	forbidden_preset_relation_issues = audit_extension_preset_data(
		forbidden_preset_relation_data,
		"preset-relation-fixture",
	)
	for field_name in sorted(GF_PRESET_FORBIDDEN_RELATION_FIELDS):
		record_result(
			f"forbidden_preset_relation_field_{field_name}",
			issue_exists(
				forbidden_preset_relation_issues,
				"forbidden_preset_relation_field",
				field=field_name,
			),
			f"missing forbidden preset relation issue for field {field_name!r}.",
		)

	forbidden_preset_package_data = make_preset_test_data()
	for field_name in GF_PRESET_FORBIDDEN_PACKAGE_FIELDS:
		forbidden_preset_package_data[field_name] = ""
	forbidden_preset_package_issues = audit_extension_preset_data(
		forbidden_preset_package_data,
		"preset-package-fixture",
	)
	for field_name in sorted(GF_PRESET_FORBIDDEN_PACKAGE_FIELDS):
		record_result(
			f"forbidden_preset_package_field_{field_name}",
			issue_exists(
				forbidden_preset_package_issues,
				"forbidden_preset_package_field",
				field=field_name,
			),
			f"missing forbidden preset package issue for field {field_name!r}.",
		)

	unsupported_preset_data = make_preset_test_data(custom_field=True)
	unsupported_preset_issues = audit_extension_preset_data(
		unsupported_preset_data,
		"preset-unsupported-fixture",
	)
	record_result(
		"unsupported_preset_field_is_rejected",
		issue_exists(unsupported_preset_issues, "unsupported_preset_field", field="custom_field"),
		"preset fixtures must report unknown fields instead of silently accepting them.",
	)

	enabled_issues = audit_bundled_extension_manifests([
		make_manifest_test_record("fixture", make_manifest_test_data(enabled_by_default=True)),
	])
	record_result(
		"bundled_manifest_enabled_by_default_is_rejected",
		issue_exists(enabled_issues, "bundled_extension_enabled_by_default", field="enabled_by_default"),
		"bundled GF optional extensions must stay disabled by default.",
	)

	internal_tag_issues = audit_bundled_extension_manifests([
		make_manifest_test_record("fixture", make_manifest_test_data(tags=["fixture", "externalization-candidate"])),
	])
	record_result(
		"bundled_manifest_internal_tags_are_rejected",
		issue_exists(
			internal_tag_issues,
			"forbidden_internal_manifest_tag",
			field="tags",
			symbol="externalization-candidate",
		),
		"bundled extension manifests must not expose internal roadmap or migration tags.",
	)

	invalid_tags_issues = audit_bundled_extension_manifests([
		make_manifest_test_record("fixture", make_manifest_test_data(tags=["fixture", 42])),
	])
	record_result(
		"bundled_manifest_tags_must_contain_strings",
		issue_exists(invalid_tags_issues, "invalid_manifest_tag_type", field="tags"),
		"manifest tags must contain only public string labels.",
	)

	dependency_issues = audit_bundled_extension_manifests([
		make_manifest_test_record("fixture", make_manifest_test_data(dependencies=["gf.kernel", "gf.combat"])),
	])
	record_result(
		"bundled_manifest_other_gf_extension_dependency_is_rejected",
		issue_exists(
			dependency_issues,
			"forbidden_bundled_extension_dependency",
			field="dependencies",
			symbol="gf.combat",
		),
		"bundled GF extensions must not depend on other bundled GF extensions.",
	)

	invalid_dependency_container_issues = audit_bundled_extension_manifests([
		make_manifest_test_record("fixture", make_manifest_test_data(dependencies={"gf.kernel": True})),
	])
	record_result(
		"manifest_dependencies_must_be_an_array",
		issue_exists(invalid_dependency_container_issues, "invalid_manifest_dependencies", field="dependencies"),
		"manifest dependencies must remain an array of hard dependency IDs.",
	)

	invalid_dependency_type_issues = audit_bundled_extension_manifests([
		make_manifest_test_record("fixture", make_manifest_test_data(dependencies=["gf.kernel", 42])),
	])
	record_result(
		"manifest_dependencies_must_contain_strings",
		issue_exists(invalid_dependency_type_issues, "invalid_manifest_dependency_type", field="dependencies"),
		"manifest dependencies must contain only string IDs.",
	)

	kind_issues = audit_bundled_extension_manifests([
		make_manifest_test_record("fixture", make_manifest_test_data(kind="package")),
	])
	record_result(
		"bundled_manifest_kind_must_be_extension",
		issue_exists(kind_issues, "invalid_bundled_extension_kind", field="kind"),
		"bundled GF optional extension manifests must declare kind='extension'.",
	)

	missing_extension_version_data = make_manifest_test_data()
	missing_extension_version_data.pop("extension_version", None)
	missing_extension_version_issues = audit_bundled_extension_manifests([
		make_manifest_test_record("fixture", missing_extension_version_data),
	])
	record_result(
		"bundled_manifest_requires_extension_version",
		issue_exists(missing_extension_version_issues, "missing_extension_version", field="extension_version"),
		"bundled GF extensions must declare extension_version independently from the GF release version.",
	)

	api_since_missing_source = "\n".join([
		"## Fixture.",
		"## [br]",
		"## @api public",
		"func changed_entry() -> void:",
		"\tpass",
	])
	api_since_missing_issues = find_missing_touched_api_since_issues(
		"addons/gf/fixture.gd",
		api_since_missing_source,
		{3},
	)
	record_result(
		"api_since_touched_reports_touched_public_block_without_since",
		issue_exists(api_since_missing_issues, "missing_api_since"),
		"changed public API documentation blocks without @since must fail.",
	)

	api_since_historical_issues = find_missing_touched_api_since_issues(
		"addons/gf/fixture.gd",
		api_since_missing_source,
		{5},
	)
	record_result(
		"api_since_touched_ignores_untouched_historical_block",
		not issue_exists(api_since_historical_issues, "missing_api_since"),
		"diff-scoped @since checks must not fail untouched historical API migration debt.",
	)

	api_since_export_source = "\n".join([
		"## Exported value.",
		"## [br]",
		"## @api public",
		"@export var changed_value: int = 0",
	])
	api_since_export_issues = find_missing_touched_api_since_issues(
		"addons/gf/fixture.gd",
		api_since_export_source,
		{4},
	)
	record_result(
		"api_since_touched_handles_export_var_declaration",
		issue_exists(api_since_export_issues, "missing_api_since", declaration="@export var changed_value: int = 0"),
		"@export var declarations bound to public docs must be checked for @since.",
	)

	api_since_versioned_source = "\n".join([
		"## Fixture.",
		"## [br]",
		"## @api public",
		"## [br]",
		"## @since 3.17.0",
		"func changed_entry() -> void:",
		"\tpass",
	])
	api_since_versioned_issues = find_missing_touched_api_since_issues(
		"addons/gf/fixture.gd",
		api_since_versioned_source,
		{3},
	)
	record_result(
		"api_since_touched_accepts_versioned_public_block",
		not issue_exists(api_since_versioned_issues, "missing_api_since"),
		"public API docs that already declare @since must pass the diff-scoped check.",
	)

	api_since_template_source = "\n".join([
		"func make_template() -> String:",
		'\treturn """## Generated project script.',
		"## [br]",
		"## @api public",
		"func generated_entry() -> void:",
		"\tpass",
		'"""',
	])
	api_since_template_issues = find_missing_touched_api_since_issues(
		"addons/gf/editor/template_source.gd",
		api_since_template_source,
		{2, 3, 4},
	)
	record_result(
		"api_since_touched_ignores_declarations_inside_multiline_strings",
		len(api_since_template_issues) == 0,
		"project-code templates embedded in multiline strings must not be treated as GF public API declarations.",
	)

	record_result(
		"path_hygiene_detects_utf8_bom_prefix",
		has_utf8_bom(b"\xef\xbb\xbfextends Node\n") and not has_utf8_bom(b"extends Node\n"),
		"GDScript path hygiene must detect UTF-8 BOM prefixes.",
	)
	valid_gdscript_format_issues = audit_gdscript_text_format(
		"addons/gf/valid.gd",
		b'extends Node\n\nconst TEMPLATE := """\n    embedded project text\n"""\n\nfunc run() -> void:\n\tpass\n',
	)
	invalid_gdscript_format_issues = [
		*audit_gdscript_text_format("addons/gf/space.gd", b"func run() -> void:\n    pass\n"),
		*audit_gdscript_text_format("addons/gf/crlf.gd", b"extends Node\r\n"),
		*audit_gdscript_text_format("addons/gf/no-final-newline.gd", b"extends Node"),
		*audit_gdscript_text_format("addons/gf/invalid-utf8.gd", b"extends Node\n\xff"),
	]
	record_result(
		"path_hygiene_enforces_utf8_lf_final_newline_and_tab_indentation",
		not valid_gdscript_format_issues
		and issue_exists(invalid_gdscript_format_issues, "gdscript_space_indentation")
		and issue_exists(invalid_gdscript_format_issues, "gdscript_non_lf_line_ending")
		and issue_exists(invalid_gdscript_format_issues, "gdscript_missing_final_newline")
		and issue_exists(invalid_gdscript_format_issues, "gdscript_invalid_utf8"),
		(
			"GDScript text format must be strict UTF-8/LF with a final newline and tab indentation, "
			"while embedded multiline project text stays outside the indentation rule."
		),
	)

	public_doc_allowed_source = (
		"GF Workspace 固定提供扩展管理和诊断快照等基础页面。"
		"SaveGraph、Flow 等工具页面只在对应可选扩展启用后贡献到工作区。"
	)
	public_doc_allowed_issues = audit_public_doc_boundary_text(
		public_doc_allowed_source,
		"docs/zh/fixture.md",
	)
	record_result(
		"public_docs_boundary_allows_optional_extension_contribution_wording",
		len(public_doc_allowed_issues) == 0,
		f"optional extension contribution wording should pass: {public_doc_allowed_issues}",
	)

	public_doc_forbidden_term_issues = audit_public_doc_boundary_text(
		"参考 XForge 的 npm run package，把 GFPathfinding2D 写进公开路线。",
		"docs/zh/fixture.md",
	)
	record_result(
		"public_docs_boundary_rejects_external_package_research_terms",
		issue_exists(public_doc_forbidden_term_issues, "forbidden_public_doc_term", symbol="XForge")
		and issue_exists(public_doc_forbidden_term_issues, "forbidden_public_doc_term", symbol="npm run package")
		and issue_exists(public_doc_forbidden_term_issues, "forbidden_public_doc_term", symbol="GFPathfinding2D"),
		"external research terms and planning track names must stay out of public docs.",
	)

	public_doc_ai_leak_issues = audit_public_doc_boundary_text(
		"See AI_MAINTENANCE.md, Codex MCP notes, and ai_analysis/godot_logs for setup.",
		"docs/zh/fixture.md",
	)
	record_result(
		"public_docs_boundary_rejects_ai_maintenance_leaks",
		issue_exists(public_doc_ai_leak_issues, "forbidden_public_doc_term", symbol="AI_MAINTENANCE.md")
		and issue_exists(public_doc_ai_leak_issues, "forbidden_public_doc_term", symbol="Codex")
		and issue_exists(public_doc_ai_leak_issues, "forbidden_public_doc_term", symbol="MCP")
		and issue_exists(public_doc_ai_leak_issues, "forbidden_public_doc_term", symbol="ai_analysis")
		and issue_exists(public_doc_ai_leak_issues, "forbidden_public_doc_term", symbol="godot_logs"),
		"AI maintenance-only files and infrastructure must stay out of public docs.",
	)
	internal_validation_leaks = (
		"Use --validation-shadow for this release.",
		"Read validation_shadow from the report.",
		"Use --affected --explain with --affected-base HEAD.",
		"Read affected_analysis from the report.",
		"Read Affected Analysis from the report.",
		"Persist this Action Key for later reuse.",
		"Persist this Action   Key for later reuse.",
		"Persist this Action         Key for later reuse.",
		"Persist this Action\nKey for later reuse.",
		"Persist this Action\tKey for later reuse.",
		"Load tools/gf_validation_evidence.py directly.",
	)
	internal_validation_leak_issues = [
		audit_public_doc_boundary_text(source, "docs/zh/fixture.md")
		for source in internal_validation_leaks
	]
	record_result(
		"public_docs_boundary_rejects_internal_validation_contract_leaks",
		all(
			issue_exists(issues, "internal_validation_reuse_contract")
			for issues in internal_validation_leak_issues
		),
		(
			"internal validation contracts must stay out of public docs: "
			f"{internal_validation_leak_issues}"
		),
	)
	public_doc_ai_product_issues = audit_public_doc_boundary_text(
		"The optional Codex plugin exposes read-oriented MCP project context tools.",
		"docs/zh/editor/tools/ai-developer.md",
	)
	record_result(
		"public_docs_boundary_allows_scoped_ai_developer_product_docs",
		len(public_doc_ai_product_issues) == 0,
		f"dedicated AI Developer Kit docs should pass: {public_doc_ai_product_issues}",
	)

	public_doc_workspace_bad_issues = audit_public_doc_boundary_text(
		"GF Workspace 固定页面包含扩展管理、输入映射、SaveGraph 和 Flow。",
		"docs/zh/fixture.md",
	)
	record_result(
		"public_docs_boundary_rejects_optional_pages_as_fixed_workspace_pages",
		issue_exists(public_doc_workspace_bad_issues, "optional_extension_workspace_page_as_core_page"),
		"optional extension pages must not be described as fixed workspace pages.",
	)

	public_doc_external_install_bad_issues = audit_public_doc_boundary_text(
		"\n".join([
			"To install a GF extension, users must install Python and run tools/gf_package_installer.py.",
			"安装扩展需要 npm 或 Git 作为前置条件。",
		]),
		"README.md",
	)
	record_result(
		"public_docs_boundary_rejects_external_tools_as_user_package_install_requirements",
		issue_exists(public_doc_external_install_bad_issues, "public_doc_package_manager_python_tool_path")
		and issue_exists(public_doc_external_install_bad_issues, "public_doc_package_install_external_tool_requirement", line=1)
		and issue_exists(public_doc_external_install_bad_issues, "public_doc_package_install_external_tool_requirement", line=2),
		f"public docs must not require Python/npm/Git for ordinary package installs: {public_doc_external_install_bad_issues}",
	)

	public_doc_external_install_allowed_issues = audit_public_doc_boundary_text(
		"\n".join([
			"Python dependencies are only needed when building the documentation locally.",
			"Installing GF extensions does not require Python, npm/npx, Git, Node, or pip.",
			"维护侧 Python 工具只用于本地构建和 release 审计；普通用户安装扩展不需要它。",
		]),
		"README.md",
	)
	record_result(
		"public_docs_boundary_allows_docs_and_negated_no_python_install_wording",
		not issue_exists(public_doc_external_install_allowed_issues, "public_doc_package_manager_python_tool_path")
		and not issue_exists(public_doc_external_install_allowed_issues, "public_doc_package_install_external_tool_requirement"),
		f"docs-only and no-Python wording should pass: {public_doc_external_install_allowed_issues}",
	)

	public_doc_signature_claim_bad_issues = audit_public_doc_boundary_text(
		"\n".join([
			"GF package registry signatures are verified before install.",
			"GF 扩展包安装前会完成签名验签。",
		]),
		"README.md",
	)
	record_result(
		"public_docs_boundary_rejects_package_signature_verification_claims",
		issue_exists(
			public_doc_signature_claim_bad_issues,
			"public_doc_package_signature_verification_claim",
			line=1,
		)
		and issue_exists(
			public_doc_signature_claim_bad_issues,
			"public_doc_package_signature_verification_claim",
			line=2,
		),
		f"public docs must not claim package signature verification before implementation: {public_doc_signature_claim_bad_issues}",
	)

	public_doc_signature_claim_allowed_issues = audit_public_doc_boundary_text(
		"\n".join([
			"Signature fields are rejected until Godot-native verification exists.",
			"签名验签实现前，registry 签名字段会被拒绝。",
		]),
		"README.md",
	)
	record_result(
		"public_docs_boundary_allows_unsupported_signature_policy_wording",
		not issue_exists(
			public_doc_signature_claim_allowed_issues,
			"public_doc_package_signature_verification_claim",
		),
		f"unsupported signature policy wording should pass: {public_doc_signature_claim_allowed_issues}",
	)

	resource_boundary_fixture = "\n".join([
		"const PanelScene = preload(\"res://ui/panel.tscn\")",
		"const ScriptDependency = preload(\"res://addons/gf/kernel/core/gf.gd\")",
		"var plugin_cfg = load(\"res://addons/gf/plugin.cfg\")",
		"var cached = ResourceLoader.load('user://cache/report.tres')",
		"var threaded = ResourceLoader.load_threaded_request(\"uid://fixture-resource\")",
		"var dialog = ResourceLoader.load(",
		"\t\"res://ui/dialog.tscn\"",
		")",
		"# var ignored = load(\"res://ignored/comment.tres\")",
		"var text := \"load(\\\"res://ignored/string.tres\\\")\"",
		"var generated_source := 'const Other = preload(\"res://addons/gf/extensions/save_extra/example.gd\")'",
	])
	resource_boundary_fixture_path = "addons/gf/kernel/fixture.gd"
	resource_boundary_issues = audit_resource_boundary_text(
		resource_boundary_fixture,
		resource_boundary_fixture_path,
	)
	record_result(
		"resource_boundary_reports_direct_resource_path_load",
		issue_exists(
			resource_boundary_issues,
			"direct_resource_path_load",
			target="res://ui/panel.tscn",
			severity="warning",
		),
		f"missing direct resource path issue: {resource_boundary_issues}",
	)
	record_result(
		"resource_boundary_reports_direct_script_dependency_load_as_info",
		issue_exists(
			resource_boundary_issues,
			"direct_script_dependency_load",
			target="res://addons/gf/kernel/core/gf.gd",
			severity="info",
		),
		f"missing direct script dependency info issue: {resource_boundary_issues}",
	)
	record_result(
		"resource_boundary_reports_editor_metadata_load_as_info",
		issue_exists(
			resource_boundary_issues,
			"direct_editor_metadata_load",
			target="res://addons/gf/plugin.cfg",
			severity="info",
		),
		f"missing editor metadata info issue: {resource_boundary_issues}",
	)
	record_result(
		"resource_boundary_reports_uid_and_user_load_literals",
		issue_exists(
			resource_boundary_issues,
			"direct_user_resource_load",
			target="user://cache/report.tres",
			severity="info",
		)
		and issue_exists(
			resource_boundary_issues,
			"direct_uid_resource_load",
			target="uid://fixture-resource",
			severity="warning",
		),
		f"missing uid/user resource boundary issues: {resource_boundary_issues}",
	)
	record_result(
		"resource_boundary_reports_multiline_resource_load",
		issue_exists(
			resource_boundary_issues,
			"direct_resource_path_load",
			target="res://ui/dialog.tscn",
			severity="warning",
		),
		f"missing multiline resource path issue: {resource_boundary_issues}",
	)
	record_result(
		"resource_boundary_ignores_comments_and_plain_string_content",
		not issue_exists(resource_boundary_issues, "direct_resource_path_load", target="res://ignored/comment.tres")
		and not issue_exists(resource_boundary_issues, "direct_resource_path_load", target="res://ignored/string.tres"),
		f"comments or plain string content should not be reported as loads: {resource_boundary_issues}",
	)
	record_result(
		"resource_boundary_ignores_load_calls_inside_plain_string_content",
		not issue_exists(resource_boundary_issues, "direct_script_dependency_load", target="res://addons/gf/extensions/save_extra/example.gd"),
		f"load calls embedded inside generated source strings should not be reported: {resource_boundary_issues}",
	)
	test_fixture_resource_issues = audit_resource_boundary_text(
		'const RunnerScene = preload("res://tests/gf_core/support/runner.tscn")',
		"tests/gf_core/support/fixture.gd",
	)
	record_result(
		"resource_boundary_reports_test_owned_fixture_load_as_info",
		issue_exists(
			test_fixture_resource_issues,
			"direct_test_fixture_resource_load",
			target="res://tests/gf_core/support/runner.tscn",
			severity="info",
		),
		f"test-owned fixture resources should remain observational: {test_fixture_resource_issues}",
	)
	runtime_test_fixture_issues = audit_resource_boundary_text(
		'const RunnerScene = preload("res://tests/gf_core/support/runner.tscn")',
		"addons/gf/kernel/fixture.gd",
	)
	record_result(
		"resource_boundary_keeps_runtime_load_of_test_fixture_actionable",
		issue_exists(
			runtime_test_fixture_issues,
			"direct_resource_path_load",
			target="res://tests/gf_core/support/runner.tscn",
			severity="warning",
		),
		f"runtime code must not inherit the test-fixture observation rule: {runtime_test_fixture_issues}",
	)
	traversal_fixture_resource_issues = audit_resource_boundary_text(
		'const RuntimeScene = preload("res://tests/gf_core/../../addons/gf/runtime.tscn")',
		"tests/gf_core/support/fixture.gd",
	)
	record_result(
		"resource_boundary_rejects_test_fixture_path_traversal",
		issue_exists(
			traversal_fixture_resource_issues,
			"direct_resource_path_load",
			target="res://tests/gf_core/../../addons/gf/runtime.tscn",
			severity="warning",
		)
		and not issue_exists(
			traversal_fixture_resource_issues,
			"direct_test_fixture_resource_load",
		),
		f"path traversal must not inherit the test-fixture observation rule: {traversal_fixture_resource_issues}",
	)
	traversal_source_resource_issues = audit_resource_boundary_text(
		'const RunnerScene = preload("res://tests/gf_core/support/runner.tscn")',
		"tests/gf_core/../runtime/fixture.gd",
	)
	record_result(
		"resource_boundary_rejects_test_source_path_traversal",
		issue_exists(
			traversal_source_resource_issues,
			"direct_resource_path_load",
			target="res://tests/gf_core/support/runner.tscn",
			severity="warning",
		)
		and not issue_exists(
			traversal_source_resource_issues,
			"direct_test_fixture_resource_load",
		),
		f"source traversal must not inherit the test-fixture observation rule: {traversal_source_resource_issues}",
	)
	record_result(
		"resource_boundary_source_kind_classifies_common_roots",
		resource_boundary_source_kind("addons/gf/kernel/core/gf.gd") == "runtime"
		and resource_boundary_source_kind("addons/gf/kernel/editor/gf_editor_workspace_dock.gd") == "editor"
		and resource_boundary_source_kind("addons/gf/standard/utilities/debug/editor/gf_build_info_export_plugin.gd") == "editor"
		and resource_boundary_source_kind("addons/gf/tools/config_pipeline/gf_config_pipeline.gd") == "tool"
		and resource_boundary_source_kind("tests/gf_core/kernel/test_fixture.gd") == "test",
		"resource-boundary source kinds should keep runtime/editor/tool/test observations distinct.",
	)
	resource_boundary_owner_entries = collect_package_source_owner_entries([
		{
			"kind": "kernel",
			"id": "gf.kernel",
			"path": "packages/gf.kernel.json",
			"paths": ["addons/gf/plugin.cfg", "addons/gf/kernel/**"],
		},
		{
			"kind": "standard",
			"id": "gf.standard.diagnostics",
			"path": "packages/gf.standard.diagnostics.json",
			"paths": ["addons/gf/standard/utilities/debug/**"],
		},
	])
	record_result(
		"resource_boundary_source_package_classifies_manifest_owners",
		resource_boundary_source_package("addons/gf/kernel/core/gf.gd", resource_boundary_owner_entries) == "gf.kernel"
		and resource_boundary_source_package("addons/gf/standard/utilities/debug/gf_build_info.gd", resource_boundary_owner_entries) == "gf.standard.diagnostics"
		and resource_boundary_source_package("tests/gf_core/kernel/test_fixture.gd", resource_boundary_owner_entries) == "<test>"
		and resource_boundary_source_package("addons/gf/unowned/fixture.gd", resource_boundary_owner_entries) == "<unowned>"
		and resource_boundary_source_package("project/local_fixture.gd", resource_boundary_owner_entries) == "<other>"
		and resource_boundary_source_package("addons/gf/kernel/core/gf.gd", []) == "<unknown>",
		"resource-boundary source packages should come from package manifest owners when available.",
	)
	record_result(
		"resource_boundary_target_package_classifies_targets",
		resource_boundary_target_package("res://addons/gf/kernel/core/gf.gd", resource_boundary_owner_entries) == "gf.kernel"
		and resource_boundary_target_package("res://addons/gf/plugin.cfg", resource_boundary_owner_entries) == "gf.kernel"
		and resource_boundary_target_package("res://ui/panel.tscn", resource_boundary_owner_entries) == "<project>"
		and resource_boundary_target_package("user://cache/report.tres", resource_boundary_owner_entries) == "<user>"
		and resource_boundary_target_package("uid://fixture-resource", resource_boundary_owner_entries) == "<uid>"
		and resource_boundary_target_package("res://addons/gf/unowned/fixture.tres", resource_boundary_owner_entries) == "<unowned>"
		and resource_boundary_target_package("res://addons/gf/kernel/core/gf.gd", []) == "<unknown>",
		"resource-boundary target packages should classify GF packages, project resources, user paths, and UID paths.",
	)
	annotate_resource_boundary_packages(resource_boundary_issues, resource_boundary_owner_entries)
	resource_boundary_payload = make_resource_boundary_payload(
		[resource_boundary_fixture_path],
		resource_boundary_issues,
		False,
		False,
	)
	record_result(
		"resource_boundary_payload_splits_observations_from_actionable_issues",
		resource_boundary_payload["issue_count"] == 4
		and resource_boundary_payload["observation_count"] == 2
		and { "key": "runtime", "count": 4 } in resource_boundary_payload["source_kind_counts"]
		and { "key": "runtime", "count": 2 } in resource_boundary_payload["observation_source_kind_counts"]
		and { "key": "gf.kernel", "count": 4 } in resource_boundary_payload["source_package_counts"]
		and { "key": "gf.kernel", "count": 2 } in resource_boundary_payload["observation_source_package_counts"]
		and { "key": "<project>", "count": 2 } in resource_boundary_payload["target_package_counts"]
		and { "key": "<uid>", "count": 1 } in resource_boundary_payload["target_package_counts"]
		and { "key": "<user>", "count": 1 } in resource_boundary_payload["target_package_counts"]
		and { "key": "gf.kernel", "count": 2 } in resource_boundary_payload["observation_target_package_counts"]
		and {
			"key": "gf.kernel -> <project>",
			"source": "gf.kernel",
			"target": "<project>",
			"count": 2,
		} in resource_boundary_payload["source_target_package_counts"]
		and {
			"key": "gf.kernel -> gf.kernel",
			"source": "gf.kernel",
			"target": "gf.kernel",
			"count": 2,
		} in resource_boundary_payload["observation_source_target_package_counts"]
		and issue_exists(resource_boundary_payload["issues"], "direct_resource_path_load", target="res://ui/panel.tscn")
		and issue_exists(resource_boundary_payload["issues"], "direct_resource_path_load", target="res://ui/dialog.tscn")
		and issue_exists(resource_boundary_payload["issues"], "direct_user_resource_load", target="user://cache/report.tres")
		and issue_exists(resource_boundary_payload["issues"], "direct_uid_resource_load", target="uid://fixture-resource")
		and resource_boundary_payload["observations"] == []
		and issue_exists(resource_boundary_payload["observation_samples"], "direct_script_dependency_load", target="res://addons/gf/kernel/core/gf.gd")
		and issue_exists(resource_boundary_payload["observation_samples"], "direct_editor_metadata_load", target="res://addons/gf/plugin.cfg"),
		f"resource-boundary payload should keep observations out of actionable issues: {resource_boundary_payload}",
	)
	resource_boundary_observation_only_findings = [
		make_resource_boundary_issue(
			resource_boundary_fixture_path,
			1,
			"preload",
			"res://addons/gf/kernel/core/gf.gd",
		),
	]
	annotate_resource_boundary_packages(
		resource_boundary_observation_only_findings,
		resource_boundary_owner_entries,
	)
	resource_boundary_observation_only_payload = make_resource_boundary_payload(
		[resource_boundary_fixture_path],
		resource_boundary_observation_only_findings,
		True,
		True,
	)
	record_result(
		"resource_boundary_strict_mode_ignores_observation_only_payloads",
		resource_boundary_observation_only_payload["ok"]
		and resource_boundary_observation_only_payload["issue_count"] == 0
		and resource_boundary_observation_only_payload["observation_count"] == 1
		and len(resource_boundary_observation_only_payload["observations"]) == 1,
		f"strict mode should fail only actionable resource issues: {resource_boundary_observation_only_payload}",
	)

	valid_content_package_data = {
		"schema_version": 1,
		"package_id": "author.base",
		"id": "author.base",
		"display_name": "Base",
		"name": "Base",
		"version": "1.0.0",
		"content_types": ["items"],
		"dependencies": [],
		"safety_kind": "data_only",
		"forbidden_resource_extensions": ["gd"],
		"resources": [
			{
				"key": "item.icon",
				"resource_key": "item.icon",
				"path": "assets/icon.tres",
				"resource_path": "assets/icon.tres",
				"type_hint": "Resource",
				"metadata": {
					"role": "icon",
				},
			},
		],
		"metadata": {
			"project": "fixture",
		},
	}
	valid_content_package_issues = audit_content_package_manifest_data(
		valid_content_package_data,
		"packs/base/gf_content_package.json",
	)
	record_result(
		"content_package_boundary_accepts_valid_manifest_fixture",
		len(valid_content_package_issues) == 0,
		f"valid content package fixture should pass: {valid_content_package_issues}",
	)

	invalid_content_package_data = {
		"package_id": "author.base",
		"version": "1.0.0",
		"download_url": "https://example.test/pack.zip",
		"resources": [
			{
				"key": "escape",
				"path": "../escape.tres",
			},
			{
				"key": "uid_asset",
				"path": "uid://outside-package",
			},
			{
				"key": "custom",
				"path": "assets/custom.tres",
				"download_url": "https://example.test/asset.tres",
			},
		],
	}
	invalid_content_package_issues = audit_content_package_manifest_data(
		invalid_content_package_data,
		"packs/base/gf_content_package.json",
	)
	record_result(
		"content_package_boundary_rejects_package_policy_fields_and_bad_paths",
		issue_exists(invalid_content_package_issues, "unsupported_manifest_field", field="download_url")
		and issue_exists(invalid_content_package_issues, "resource_path_outside_package", row_key="escape")
		and issue_exists(invalid_content_package_issues, "resource_path_not_allowed", row_key="uid_asset")
		and issue_exists(invalid_content_package_issues, "unsupported_resource_field", field="download_url", row_index=2),
		f"content package policy/path issues should be reported: {invalid_content_package_issues}",
	)

	conflicting_content_package_data = {
		"schema_version": 1,
		"package_id": "author.canonical",
		"id": "author.alias",
		"display_name": "Canonical",
		"name": "Alias",
		"version": "1.0.0",
		"resources": [{
			"key": "canonical.key",
			"resource_key": "alias.key",
			"path": "canonical.tres",
			"resource_path": "alias.tres",
		}],
	}
	conflicting_content_package_issues = audit_content_package_manifest_data(
		conflicting_content_package_data,
		"packs/conflict/gf_content_package.json",
	)
	record_result(
		"content_package_boundary_rejects_schema_drift_and_conflicting_aliases",
		len([
			issue
			for issue in conflicting_content_package_issues
			if issue.get("kind") == "conflicting_alias_fields"
		]) == 4
		and issue_exists(
			audit_content_package_manifest_data(
				{"package_id": "author.missing_schema", "version": "1.0.0", "resources": []},
				"packs/missing/gf_content_package.json",
			),
			"missing_schema_version",
			field="schema_version",
		)
		and issue_exists(
			audit_content_package_manifest_data(
				{
					"schema_version": 2,
					"package_id": "author.future",
					"version": "1.0.0",
					"resources": [],
				},
				"packs/future/gf_content_package.json",
			),
			"unsupported_schema_version",
			field="schema_version",
		),
		f"content package schema/alias issues should be reported: {conflicting_content_package_issues}",
	)

	content_package_graph_records = [
		{
			"path": "packs/base/gf_content_package.json",
			"package_id": "author.base",
			"dependencies": ["author.feature"],
			"resource_count": 0,
			"issues": [],
		},
		{
			"path": "packs/feature/gf_content_package.json",
			"package_id": "author.feature",
			"dependencies": ["author.base", "author.missing"],
			"resource_count": 0,
			"issues": [],
		},
	]
	content_package_graph_issues = audit_content_package_graph(content_package_graph_records)
	record_result(
		"content_package_boundary_reports_missing_dependencies_and_cycles",
		issue_exists(content_package_graph_issues, "missing_dependency", row_key="author.feature", actual_value="author.missing")
		and issue_exists(content_package_graph_issues, "dependency_cycle", actual_value="author.base -> author.feature -> author.base"),
		f"missing dependencies and cycles should be reported: {content_package_graph_issues}",
	)

	asset_lifecycle_source = "\n".join([
		"func run(asset_util: GFAssetUtility, registry: GFResourceRegistry, owner: Node) -> void:",
		"\tasset_util.load_handle_async(\"res://hero.tres\", func(_handle: GFAssetHandle) -> void:",
		"\t\tpass",
		"\t)",
		"\tasset_util.load_handle_async(\"res://owned.tres\", Callable(), \"Resource\", owner)",
		"\tasset_util.acquire_handle(\"res://grouped.tres\", null, &\"ui\", \"Resource\", Resource.new())",
		"\tregistry.request_entry_handle_async(asset_util, &\"entry\", Callable(), owner, &\"\")",
	])
	asset_lifecycle_issues = audit_asset_lifecycle_text(
		asset_lifecycle_source,
		"addons/gf/fixture.gd",
	)
	record_result(
		"asset_lifecycle_boundary_reports_ownerless_ungrouped_handles",
		issue_exists(
			asset_lifecycle_issues,
			"ownerless_ungrouped_asset_handle",
			callee="load_handle_async",
			target='"res://hero.tres"',
			severity="warning",
		),
		f"ownerless ungrouped handle should be reported: {asset_lifecycle_issues}",
	)
	record_result(
		"asset_lifecycle_boundary_accepts_owner_or_group_anchored_handles",
		not issue_exists(asset_lifecycle_issues, "ownerless_ungrouped_asset_handle", target='"res://owned.tres"')
		and not issue_exists(asset_lifecycle_issues, "ownerless_ungrouped_asset_handle", target='"res://grouped.tres"')
		and not issue_exists(asset_lifecycle_issues, "ownerless_ungrouped_asset_handle", target='&"entry"'),
		f"owner or group anchored handles should pass: {asset_lifecycle_issues}",
	)

	project_profile_paths = [
		"game/scripts/player.gd",
		"game/scenes/main.tscn",
		"game/assets/icon.png",
		"misc/debug.gd",
	]
	valid_project_profile = {
		"schema_version": 1,
		"id": "fixture",
		"zones": [
			{
				"id": "game_scripts",
				"roots": ["game/scripts"],
				"required": True,
				"allow_extensions": [".gd"],
				"severity": "error",
			},
			{
				"id": "game_assets",
				"roots": ["game/assets"],
				"allow_extensions": [".png", ".tres"],
				"severity": "warning",
			},
		],
		"rules": [
			{
				"id": "has_main_scene",
				"kind": "path_exists",
				"paths": ["game/scenes/main.tscn"],
			},
			{
				"id": "gd_under_scripts",
				"kind": "files_under_roots",
				"extensions": [".gd"],
				"roots": ["game/scripts"],
				"exclude": ["addons/**"],
				"severity": "warning",
			},
		],
		"metadata": {
			"owner": "test",
		},
	}
	valid_project_profile_issues = audit_project_profile_data(
		valid_project_profile,
		"gf_project_profile.json",
		[
			"game/scripts/player.gd",
			"game/scenes/main.tscn",
			"game/assets/icon.png",
		],
	)
	record_result(
		"project_profile_boundary_accepts_flexible_valid_profile",
		len(valid_project_profile_issues) == 0,
		f"valid project profile should pass: {valid_project_profile_issues}",
	)

	project_profile_issues = audit_project_profile_data(
		valid_project_profile,
		"gf_project_profile.json",
		project_profile_paths,
	)
	record_result(
		"project_profile_boundary_reports_selected_files_outside_declared_roots",
		issue_exists(
			project_profile_issues,
			"project_profile_file_outside_roots",
			path="misc/debug.gd",
			rule_id="gd_under_scripts",
			severity="warning",
		),
		f"selected files outside roots should be reported: {project_profile_issues}",
	)

	invalid_project_profile = {
		"schema_version": 1,
		"id": "invalid",
		"preset": "not-allowed",
		"zones": [
			{
				"id": "missing_root",
				"roots": ["missing/scripts"],
				"required": True,
				"severity": "error",
			},
			{
				"id": "scene_zone",
				"roots": ["game/scenes"],
				"deny_extensions": [".gd"],
				"severity": "warning",
			},
		],
		"rules": [
			{
				"id": "bad_kind",
				"kind": "custom_business_rule",
			},
		],
	}
	invalid_project_profile_schema_issues = audit_project_profile_schema(
		invalid_project_profile,
		"gf_project_profile.json",
	)
	invalid_project_profile_runtime_issues = audit_project_profile_data(
		{
			"schema_version": 1,
			"id": "invalid",
			"zones": invalid_project_profile["zones"],
			"rules": [],
		},
		"gf_project_profile.json",
		["game/scenes/debug.gd"],
	)
	record_result(
		"project_profile_boundary_rejects_unsupported_fields_and_rule_kinds",
		issue_exists(invalid_project_profile_schema_issues, "unsupported_project_profile_field", field="preset")
		and issue_exists(invalid_project_profile_schema_issues, "unsupported_project_profile_rule_kind", actual_value="custom_business_rule"),
		f"unsupported project profile fields and rule kinds should be reported: {invalid_project_profile_schema_issues}",
	)
	record_result(
		"project_profile_boundary_reports_missing_roots_and_denied_extensions",
		issue_exists(
			invalid_project_profile_runtime_issues,
			"project_profile_required_root_missing",
			zone_id="missing_root",
			actual_value="missing/scripts",
			severity="error",
		)
		and issue_exists(
			invalid_project_profile_runtime_issues,
			"project_profile_zone_extension_denied",
			path="game/scenes/debug.gd",
			zone_id="scene_zone",
			severity="warning",
		),
		f"missing roots and denied extensions should be reported: {invalid_project_profile_runtime_issues}",
	)

	advanced_project_profile = {
		"schema_version": 1,
		"id": "advanced_fixture",
		"rules": [
			{
				"id": "root_files_are_declared",
				"kind": "forbid_root_files",
				"allowed_files": ["project.godot"],
			},
			{
				"id": "paths_are_snake_case",
				"kind": "naming_convention",
				"roots": ["features"],
				"pattern": r"^[a-z0-9_./-]+$",
				"target": "path",
			},
			{
				"id": "features_are_cohesive",
				"kind": "feature_module_contract",
				"roots": ["features"],
				"feature_id_pattern": r"^[a-z][a-z0-9_]*$",
				"required_subdirs": ["scripts"],
				"allowed_subdirs": ["scripts", "scenes"],
				"allow_root_files": False,
			},
			{
				"id": "generated_stays_generated",
				"kind": "generated_boundary",
				"include": ["**/*.generated.gd"],
				"roots": ["generated"],
			},
			{
				"id": "utility_bucket_limit",
				"kind": "bucket_size",
				"roots": ["scripts/utilities"],
				"max_files": 1,
				"severity": "warning",
			},
		],
	}
	advanced_project_profile_valid_issues = audit_project_profile_data(
		advanced_project_profile,
		"gf_project_profile.json",
		[
			"project.godot",
			"features/fleet/scripts/fleet_system.gd",
			"features/fleet/scenes/fleet_panel.tscn",
			"generated/config.generated.gd",
			"scripts/utilities/math.gd",
		],
	)
	record_result(
		"project_profile_boundary_accepts_advanced_layout_rules",
		len(advanced_project_profile_valid_issues) == 0,
		f"advanced project profile rules should pass valid layout: {advanced_project_profile_valid_issues}",
	)
	advanced_project_profile_invalid_issues = audit_project_profile_data(
		advanced_project_profile,
		"gf_project_profile.json",
		[
			"RootDebug.gd",
			"features/Fleet/fleet_system.gd",
			"features/fleet/misc/fleet.gd",
			"features/empty/scenes/empty_scene.tscn",
			"outside/config.generated.gd",
			"scripts/utilities/math.gd",
			"scripts/utilities/text.gd",
		],
	)
	record_result(
		"project_profile_boundary_reports_advanced_layout_violations",
		issue_exists(advanced_project_profile_invalid_issues, "project_profile_forbidden_root_file", path="RootDebug.gd")
		and issue_exists(advanced_project_profile_invalid_issues, "project_profile_naming_convention_violation", path="features/Fleet/fleet_system.gd")
		and issue_exists(advanced_project_profile_invalid_issues, "project_profile_feature_id_invalid", path="features/Fleet")
		and issue_exists(advanced_project_profile_invalid_issues, "project_profile_feature_root_file", path="features/Fleet/fleet_system.gd")
		and issue_exists(advanced_project_profile_invalid_issues, "project_profile_feature_subdir_not_allowed", path="features/fleet/misc")
		and issue_exists(advanced_project_profile_invalid_issues, "project_profile_feature_required_subdir_missing", path="features/empty/scripts")
		and issue_exists(advanced_project_profile_invalid_issues, "project_profile_generated_file_outside_roots", path="outside/config.generated.gd")
		and issue_exists(advanced_project_profile_invalid_issues, "project_profile_bucket_too_large", path="scripts/utilities", severity="warning"),
		f"advanced project profile violations should be reported: {advanced_project_profile_invalid_issues}",
	)

	valid_package_data = {
		"schema_version": 1,
		"id": "gf.standard.fixture",
		"kind": "standard",
		"version": "unreleased",
		"dependencies": ["gf.kernel"],
		"paths": ["addons/gf/standard/**"],
		"exclude_paths": ["addons/gf/standard/**"],
		"metadata": {},
	}
	valid_package_issues = audit_package_manifest_data(
		valid_package_data,
		"packages/gf.standard.fixture.json",
	)
	record_result(
		"package_boundary_accepts_valid_manifest_fixture",
		len(valid_package_issues) == 0,
		f"valid package manifest fixture should pass: {valid_package_issues}",
	)

	package_metadata_policy_data = dict(valid_package_data)
	package_metadata_policy_data["metadata"] = {
		"stage": "fixture",
		"download_url": "https://example.test/package.zip",
		"nested": {
			"load_after": ["gf.extension.save"],
		},
	}
	package_metadata_policy_issues = audit_package_manifest_data(
		package_metadata_policy_data,
		"packages/gf.standard.fixture.json",
	)
	record_result(
		"package_boundary_rejects_forbidden_metadata_policy_fields",
		issue_exists(package_metadata_policy_issues, "forbidden_package_metadata_field", field="metadata.download_url")
		and issue_exists(package_metadata_policy_issues, "forbidden_package_metadata_field", field="metadata.nested.load_after"),
		f"forbidden package metadata policy fields should be reported: {package_metadata_policy_issues}",
	)
	package_builder_metadata_policy_fields = build_gf_package.forbidden_package_manifest_metadata_field_paths(
		package_metadata_policy_data["metadata"]
	)
	record_result(
		"package_builder_rejects_forbidden_nested_metadata_policy_fields",
		package_builder_metadata_policy_fields == [
			"metadata.download_url",
			"metadata.nested.load_after",
		],
		(
			"Standalone package builder must apply the same fail-closed nested metadata policy: "
			f"{package_builder_metadata_policy_fields}"
		),
	)
	deep_package_metadata: dict[str, Any] = {}
	deep_package_cursor = deep_package_metadata
	for depth_index in range(70):
		nested_metadata: dict[str, Any] = {}
		deep_package_cursor[f"level_{depth_index}"] = nested_metadata
		deep_package_cursor = nested_metadata
	deep_package_data = dict(valid_package_data)
	deep_package_data["metadata"] = deep_package_metadata
	deep_package_issues = audit_package_manifest_data(
		deep_package_data,
		"packages/gf.standard.deep.json",
	)
	record_result(
		"package_boundary_rejects_excessive_manifest_nesting",
		issue_exists(
			deep_package_issues,
			"package_manifest_nesting_too_deep",
			expected_value="<= 64",
		),
		f"Excessively nested package manifests must fail closed: {deep_package_issues}",
	)
	wide_package_data = dict(valid_package_data)
	wide_package_data["metadata"] = {"values": [0] * (16 * 1024)}
	wide_package_issues = audit_package_manifest_data(
		wide_package_data,
		"packages/gf.standard.wide.json",
	)
	record_result(
		"package_boundary_rejects_excessive_manifest_structure",
		issue_exists(
			wide_package_issues,
			"package_manifest_node_budget_exceeded",
			expected_value="<= 16384",
		),
		f"Excessively wide package manifests must fail closed: {wide_package_issues}",
	)

	record_result(
		"package_boundary_requires_exact_gf_kind_prefix_segments",
		expected_package_kind_from_id("gf.toolkit.fixture") == ""
		and expected_package_kind_from_id("gf.standardish.fixture") == ""
		and expected_package_kind_from_id("gf.tool.fixture") == "tool",
		"package kind detection should require exact gf.<kind>. prefixes.",
	)

	invalid_package_data = {
		"schema_version": 1,
		"id": "gf.extension.bad",
		"kind": "extension",
		"version": "4.x",
		"download_url": "https://example.test/gf-extension-bad.zip",
		"registry_signature_url": "https://example.test/gf-extension-bad.zip.sig",
		"paths": ["../outside/**"],
		"exclude_paths": ["../outside/**"],
		"packages": ["gf.standard"],
	}
	invalid_package_issues = audit_package_manifest_data(
		invalid_package_data,
		"packages/gf.extension.bad.json",
	)
	record_result(
		"package_boundary_rejects_forbidden_fields_bad_version_paths_and_non_preset_packages",
		issue_exists(invalid_package_issues, "forbidden_package_manifest_field", field="download_url")
		and issue_exists(invalid_package_issues, "forbidden_package_manifest_field", field="registry_signature_url")
		and issue_exists(invalid_package_issues, "invalid_package_version", field="version")
		and issue_exists(invalid_package_issues, "invalid_package_path", field="paths", row_index=0)
		and issue_exists(invalid_package_issues, "invalid_package_exclude_path", field="exclude_paths", row_index=0)
		and issue_exists(invalid_package_issues, "non_preset_declares_packages", field="packages"),
		f"invalid package manifest issues should be reported: {invalid_package_issues}",
	)

	package_graph_records = [
		{
			"path": "packages/gf.kernel.json",
			"id": "gf.kernel",
			"kind": "kernel",
			"dependencies": [],
			"packages": [],
			"paths": ["addons/gf/kernel/**"],
			"issues": [],
		},
		{
			"path": "packages/gf.standard.a.json",
			"id": "gf.standard.a",
			"kind": "standard",
			"dependencies": ["gf.standard.b"],
			"packages": [],
			"paths": ["addons/gf/standard/a/**"],
			"issues": [],
		},
		{
			"path": "packages/gf.standard.b.json",
			"id": "gf.standard.b",
			"kind": "standard",
			"dependencies": ["gf.standard.a"],
			"packages": [],
			"paths": ["addons/gf/standard/b/**"],
			"issues": [],
		},
		{
			"path": "packages/extensions/gf.extension.save.json",
			"id": "gf.extension.save",
			"kind": "extension",
			"dependencies": ["gf.extension.dialogue", "gf.standard.missing"],
			"packages": [],
			"paths": ["addons/gf/extensions/save/**"],
			"issues": [],
		},
		{
			"path": "packages/extensions/gf.extension.dialogue.json",
			"id": "gf.extension.dialogue",
			"kind": "extension",
			"dependencies": ["gf.kernel"],
			"packages": [],
			"paths": ["addons/gf/extensions/dialogue/**"],
			"issues": [],
		},
		{
			"path": "packages/extensions/gf.extension.bad_tool_dep.json",
			"id": "gf.extension.bad_tool_dep",
			"kind": "extension",
			"dependencies": ["gf.tool.fixture"],
			"packages": [],
			"paths": ["addons/gf/extensions/bad_tool_dep/**"],
			"issues": [],
		},
		{
			"path": "packages/tools/gf.tool.fixture.json",
			"id": "gf.tool.fixture",
			"kind": "tool",
			"dependencies": ["gf.kernel", "gf.standard.a", "gf.extension.dialogue"],
			"packages": [],
			"paths": ["addons/gf/tools/fixture/**"],
			"issues": [],
		},
		{
			"path": "packages/tools/gf.tool.depends_tool.json",
			"id": "gf.tool.depends_tool",
			"kind": "tool",
			"dependencies": ["gf.tool.fixture"],
			"packages": [],
			"paths": ["addons/gf/tools/depends_tool/**"],
			"issues": [],
		},
	]
	package_graph_issues = audit_package_manifest_graph(package_graph_records)
	record_result(
		"package_boundary_reports_missing_forbidden_tool_and_cyclic_dependencies",
		issue_exists(package_graph_issues, "missing_package_dependency", row_key="gf.extension.save", actual_value="gf.standard.missing")
		and issue_exists(package_graph_issues, "forbidden_package_dependency", row_key="gf.extension.save", actual_value="gf.extension.dialogue")
		and issue_exists(package_graph_issues, "forbidden_package_dependency", row_key="gf.extension.bad_tool_dep", actual_value="gf.tool.fixture")
		and issue_exists(package_graph_issues, "forbidden_package_dependency", row_key="gf.tool.depends_tool", actual_value="gf.tool.fixture")
		and not issue_exists(package_graph_issues, "forbidden_package_dependency", row_key="gf.tool.fixture", actual_value="gf.extension.dialogue")
		and issue_exists(package_graph_issues, "package_dependency_cycle", actual_value="gf.standard.a -> gf.standard.b -> gf.standard.a"),
		f"package graph issues should be reported: {package_graph_issues}",
	)

	extension_binding_issues = audit_package_extension_bindings([
		{
			"path": "packages/extensions/gf.extension.save.json",
			"id": "gf.extension.save",
			"kind": "extension",
			"gf_extension_id": "gf.svae",
			"paths": ["addons/gf/extensions/save/**"],
			"issues": [],
		},
	])
	record_result(
		"package_boundary_validates_gf_extension_id_against_owned_extension_manifest",
		issue_exists(
			extension_binding_issues,
			"extension_package_gf_extension_id_mismatch",
			row_key="gf.extension.save",
			expected_value="gf.save",
			actual_value="gf.svae",
		),
		f"extension package gf_extension_id mismatch should be reported: {extension_binding_issues}",
	)

	package_overlap_issues = audit_package_path_ownership([
		{
			"path": "packages/gf.kernel.json",
			"id": "gf.kernel",
			"kind": "kernel",
			"paths": ["addons/gf/kernel/**"],
		},
		{
			"path": "packages/gf.tool.fixture.json",
			"id": "gf.tool.fixture",
			"kind": "tool",
			"paths": ["addons/gf/kernel/editor/**"],
		},
	], ["addons/gf/kernel/editor/plugin.gd"])
	record_result(
		"package_boundary_reports_overlapping_owned_paths",
		issue_exists(package_overlap_issues, "package_path_overlap", row_key="gf.kernel")
		and issue_exists(package_overlap_issues, "package_path_overlap", row_key="gf.tool.fixture"),
		f"overlapping package paths should be reported: {package_overlap_issues}",
	)
	package_exclusion_records = [
		{
			"path": "packages/standard/gf.standard.spatial.json",
			"id": "gf.standard.spatial",
			"kind": "standard",
			"paths": ["addons/gf/standard/foundation/math/**"],
			"exclude_paths": ["addons/gf/standard/foundation/math/editor/**"],
		},
		{
			"path": "packages/standard/gf.standard.spatial.editor.json",
			"id": "gf.standard.spatial.editor",
			"kind": "standard",
			"paths": ["addons/gf/standard/foundation/math/editor/**"],
			"exclude_paths": [],
		},
	]
	package_exclusion_paths = [
		"addons/gf/standard/foundation/math/runtime.gd",
		"addons/gf/standard/foundation/math/editor/inspector.gd",
	]
	package_exclusion_index = PackageOwnershipIndex(
		collect_package_source_owner_entries(package_exclusion_records)
	)
	package_exclusion_issues = audit_package_path_ownership(
		package_exclusion_records,
		package_exclusion_paths,
		package_exclusion_index,
	)
	package_runtime_owner = package_exclusion_index.find_owner(package_exclusion_paths[0])
	package_editor_owner = package_exclusion_index.find_owner(package_exclusion_paths[1])
	record_result(
		"package_ownership_applies_declared_exclude_paths",
		not package_exclusion_issues
		and package_runtime_owner is not None
		and package_runtime_owner.get("package_id") == "gf.standard.spatial"
		and package_editor_owner is not None
		and package_editor_owner.get("package_id") == "gf.standard.spatial.editor",
		(
			"Package ownership must apply exclude_paths before overlap and owner checks: "
			f"issues={package_exclusion_issues}, runtime={package_runtime_owner}, editor={package_editor_owner}"
		),
	)
	editor_contribution_ownership_index = PackageOwnershipIndex(
		collect_package_source_owner_entries([
			{
				"path": "packages/standard/gf.standard.editor.json",
				"id": "gf.standard.editor",
				"kind": "standard",
				"paths": ["addons/gf/standard/editor/**"],
			},
			{
				"path": "packages/standard/gf.standard.state_machine.editor.json",
				"id": "gf.standard.state_machine.editor",
				"kind": "standard",
				"paths": ["addons/gf/standard/state_machine/node/editor/**"],
			},
		])
	)
	mismatched_editor_contribution_issues = audit_editor_contribution_manifest_data(
		{
			"template_records": [{
				"owner_package_id": "gf.standard.state_machine.editor",
				"template_path": "res://addons/gf/standard/editor/templates/node_state.gdtemplate",
			}],
		},
		"addons/gf/standard/editor/gf_editor_contributions.json",
		editor_contribution_ownership_index,
	)
	valid_editor_contribution_issues = audit_editor_contribution_manifest_data(
		{
			"template_records": [{
				"owner_package_id": "gf.standard.state_machine.editor",
				"template_path": "res://addons/gf/standard/state_machine/node/editor/templates/node_state.gdtemplate",
			}],
		},
		"addons/gf/standard/editor/gf_editor_contributions.json",
		editor_contribution_ownership_index,
	)
	record_result(
		"package_source_boundary_requires_editor_contribution_target_owner_identity",
		issue_exists(
			mismatched_editor_contribution_issues,
			"editor_contribution_owner_mismatch",
			row_key="gf.standard.state_machine.editor",
			expected_value="gf.standard.editor",
		)
		and not valid_editor_contribution_issues,
		(
			"Editor contribution target paths must be uniquely owned by their declared payload package: "
			f"mismatch={mismatched_editor_contribution_issues}, valid={valid_editor_contribution_issues}"
		),
	)
	disjoint_glob_issues = audit_package_path_ownership([
		{
			"path": "packages/gf.scripts.json",
			"id": "gf.scripts",
			"kind": "standard",
			"paths": ["addons/gf/standard/fixture/*.gd"],
		},
		{
			"path": "packages/gf.images.json",
			"id": "gf.images",
			"kind": "standard",
			"paths": ["addons/gf/standard/fixture/*.png"],
		},
	], [
		"addons/gf/standard/fixture/service.gd",
		"addons/gf/standard/fixture/icon.png",
	])
	wildcard_entries = collect_package_source_owner_entries([
		{
			"path": "packages/gf.extension.editors.json",
			"id": "gf.extension.editors",
			"kind": "extension",
			"paths": ["addons/gf/extensions/*/editor/**"],
		},
	])
	record_result(
		"package_glob_ownership_matches_manifest_semantics",
		not disjoint_glob_issues
		and find_package_source_owner(
			"addons/gf/extensions/save/editor/plugin.gd",
			wildcard_entries,
		) is not None
		and find_package_source_owner(
			"addons/gf/extensions/save/runtime/service.gd",
			wildcard_entries,
		) is None,
		f"package ownership must preserve disjoint globs and wildcard directory semantics: {disjoint_glob_issues}",
	)
	record_result(
		"package_manifest_paths_are_case_sensitive_on_every_platform",
		package_manifest_path_matches(
			"addons/gf/extensions/save/runtime/service.gd",
			"addons/gf/extensions/save/**",
		)
		and not package_manifest_path_matches(
			"addons/GF/extensions/save/runtime/service.gd",
			"addons/gf/extensions/save/**",
		),
		"package matching must follow Godot resource path case semantics instead of host OS defaults.",
	)
	record_result(
		"package_manifest_globs_are_segment_bounded_and_recursive_tail_only",
		package_manifest_path_matches(
			"addons/gf/kernel/core/service.gd",
			"**",
		)
		and package_manifest_path_matches(
			"addons/gf/kernel/core/service.gd",
			"addons/g*/kernel*/**",
		)
		and not package_manifest_path_matches(
			"addons/gf/kernel/core/service.gd",
			"addons/gf/kernel/*",
		)
		and package_manifest_path_matches(
			"addons/gf/kernel/[ab].gd",
			"addons/gf/kernel/[ab].gd",
		)
		and not package_manifest_path_matches(
			"addons/gf/kernel/a.gd",
			"addons/gf/kernel/[ab].gd",
		)
		and not package_manifest_path_matches(
			"addons/gf/kernel/core/service.gd",
			"addons/**/service.gd",
		),
		"package globs must keep * and ? within one segment, treat brackets literally, and reserve ** for the final full segment.",
	)

	package_closure_records = [
		{
			"path": "packages/gf.kernel.json",
			"id": "gf.kernel",
			"kind": "kernel",
			"dependencies": [],
			"packages": [],
			"paths": ["addons/gf/kernel/**"],
			"issues": [],
		},
		{
			"path": "packages/standard/gf.standard.base.json",
			"id": "gf.standard.base",
			"kind": "standard",
			"dependencies": ["gf.kernel"],
			"packages": [],
			"paths": ["addons/gf/standard/base/**"],
			"issues": [],
		},
		{
			"path": "packages/standard/gf.standard.assets.json",
			"id": "gf.standard.assets",
			"kind": "standard",
			"dependencies": ["gf.kernel", "gf.standard.base"],
			"packages": [],
			"paths": ["addons/gf/standard/assets/**"],
			"issues": [],
		},
		{
			"path": "packages/standard/gf.standard.audio.json",
			"id": "gf.standard.audio",
			"kind": "standard",
			"dependencies": ["gf.kernel", "gf.standard.assets"],
			"packages": [],
			"paths": ["addons/gf/standard/audio/**"],
			"issues": [],
		},
		{
			"path": "packages/standard/gf.standard.state.json",
			"id": "gf.standard.state",
			"kind": "standard",
			"dependencies": ["gf.kernel", "gf.standard.base"],
			"packages": [],
			"paths": ["addons/gf/standard/state/**"],
			"issues": [],
		},
		{
			"path": "packages/standard/gf.standard.storage.json",
			"id": "gf.standard.storage",
			"kind": "standard",
			"dependencies": ["gf.kernel", "gf.standard.base"],
			"packages": [],
			"paths": ["addons/gf/standard/storage/**"],
			"issues": [],
		},
		{
			"path": "packages/standard/gf.standard.ui.json",
			"id": "gf.standard.ui",
			"kind": "standard",
			"dependencies": ["gf.kernel", "gf.standard.base", "gf.standard.assets", "gf.standard.audio", "gf.standard.state", "gf.standard.storage"],
			"packages": [],
			"paths": ["addons/gf/standard/ui/**"],
			"issues": [],
		},
		{
			"path": "packages/standard/gf.standard.debug.json",
			"id": PACKAGE_CLOSURE_DEBUG_PACKAGE_ID,
			"kind": "standard",
			"dependencies": ["gf.kernel", "gf.standard.base", "gf.standard.assets", "gf.standard.audio", "gf.standard.state", "gf.standard.storage", "gf.standard.ui"],
			"packages": [],
			"paths": ["addons/gf/standard/debug/**"],
			"issues": [],
		},
		{
			"path": "packages/standard/gf.standard.editor.json",
			"id": PACKAGE_CLOSURE_EDITOR_PACKAGE_ID,
			"kind": "standard",
			"dependencies": ["gf.kernel", "gf.standard.base"],
			"packages": [],
			"paths": ["addons/gf/standard/editor/**"],
			"issues": [],
		},
		{
			"path": "packages/extensions/gf.extension.heavy.json",
			"id": "gf.extension.heavy",
			"kind": "extension",
			"dependencies": ["gf.kernel", "gf.standard.base", PACKAGE_CLOSURE_DEBUG_PACKAGE_ID],
			"packages": [],
			"paths": ["addons/gf/extensions/heavy/**"],
			"issues": [],
		},
		{
			"path": "packages/extensions/gf.extension.bad_editor.json",
			"id": "gf.extension.bad_editor",
			"kind": "extension",
			"dependencies": ["gf.kernel", PACKAGE_CLOSURE_EDITOR_PACKAGE_ID],
			"packages": [],
			"paths": ["addons/gf/extensions/bad_editor/**"],
			"issues": [],
		},
	]
	package_closure_rows = collect_package_closure_rows(package_closure_records)
	package_closure_issues = audit_package_closure_rows(package_closure_records, package_closure_rows)
	heavy_closure = next(
		(row for row in package_closure_rows if row.get("package_id") == "gf.extension.heavy"),
		{},
	)
	record_result(
		"package_closure_audit_reports_large_debug_and_editor_closure_risks",
		(
			heavy_closure.get("closure_count") == 9
			and heavy_closure.get("standard_count") == 7
			and issue_exists(package_closure_issues, "package_extension_debug_dependency", row_key="gf.extension.heavy", severity="warning")
			and issue_exists(package_closure_issues, "package_extension_large_closure", row_key="gf.extension.heavy", severity="warning")
			and issue_exists(package_closure_issues, "package_debug_ui_closure", row_key=PACKAGE_CLOSURE_DEBUG_PACKAGE_ID, severity="warning")
			and issue_exists(package_closure_issues, "package_extension_editor_closure", row_key="gf.extension.bad_editor", severity="error")
		),
		f"closure risks should be reported: rows={package_closure_rows} issues={package_closure_issues}",
	)
	package_closure_fan_in = collect_package_standard_fan_in(package_closure_records, package_closure_rows)
	base_fan_in = next(
		(item for item in package_closure_fan_in if item.get("package_id") == "gf.standard.base"),
		{},
	)
	record_result(
		"package_closure_audit_records_standard_fan_in",
		base_fan_in.get("dependent_count", 0) >= 8
		and "gf.extension.heavy" in base_fan_in.get("dependents", []),
		f"standard fan-in should include transitive dependents: {package_closure_fan_in}",
	)
	closure_baseline_issues = audit_package_closure_baselines(
		[{
			"package_id": PACKAGE_CLOSURE_EDITOR_PACKAGE_ID,
			"path": "packages/standard/gf.standard.editor.json",
			"closure_count": PACKAGE_AGGREGATE_CLOSURE_BASELINES[PACKAGE_CLOSURE_EDITOR_PACKAGE_ID] + 1,
		}],
		[{
			"package_id": "gf.standard.base",
			"dependent_count": PACKAGE_STANDARD_FAN_IN_BASELINES["gf.standard.base"] + 1,
		}],
	)
	record_result(
		"package_closure_audit_reports_reviewed_baseline_growth",
		issue_exists(
			closure_baseline_issues,
			"package_aggregate_closure_growth",
			row_key=PACKAGE_CLOSURE_EDITOR_PACKAGE_ID,
		)
		and issue_exists(
			closure_baseline_issues,
			"package_standard_fan_in_growth",
			row_key="gf.standard.base",
		),
		f"aggregate closure and standard fan-in growth should stay visible: {closure_baseline_issues}",
	)
	payload_metric_paths_before = [
		"addons/gf/kernel/core.gd",
		"addons/gf/standard/base/runtime.gd",
	]
	payload_metric_paths_after = [
		*payload_metric_paths_before,
		"addons/gf/standard/base/new_runtime.gd",
	]
	payload_metric_sizes = {
		"addons/gf/kernel/core.gd": 10,
		"addons/gf/standard/base/runtime.gd": 20,
		"addons/gf/standard/base/new_runtime.gd": 30,
	}
	payload_metrics_before, payload_metric_issues_before = collect_package_payload_metrics(
		package_closure_records,
		payload_metric_paths_before,
		payload_metric_sizes,
	)
	payload_metrics_after, payload_metric_issues_after = collect_package_payload_metrics(
		package_closure_records,
		payload_metric_paths_after,
		payload_metric_sizes,
	)
	payload_editor_before = next(
		(
			row
			for row in collect_package_closure_rows(package_closure_records, payload_metrics_before)
			if row.get("package_id") == PACKAGE_CLOSURE_EDITOR_PACKAGE_ID
		),
		{},
	)
	payload_editor_after = next(
		(
			row
			for row in collect_package_closure_rows(package_closure_records, payload_metrics_after)
			if row.get("package_id") == PACKAGE_CLOSURE_EDITOR_PACKAGE_ID
		),
		{},
	)
	record_result(
		"package_closure_audit_records_payload_growth_without_id_growth",
		not payload_metric_issues_before
		and not payload_metric_issues_after
		and payload_editor_before.get("closure_count") == payload_editor_after.get("closure_count")
		and payload_editor_before.get("payload_file_count") == 2
		and payload_editor_after.get("payload_file_count") == 3
		and payload_editor_before.get("payload_gdscript_count") == 2
		and payload_editor_after.get("payload_gdscript_count") == 3
		and payload_editor_before.get("payload_size_bytes") == 30
		and payload_editor_after.get("payload_size_bytes") == 60,
		(
			"Broad-root payload growth must remain visible even when closure IDs do not change: "
			f"before={payload_editor_before}, after={payload_editor_after}, "
			f"issues={payload_metric_issues_before + payload_metric_issues_after}"
		),
	)

	package_external_command_issues = audit_package_external_command_source(
		"\n".join([
			"func run(url: String) -> void:",
			"\tOS.execute(\"python\", PackedStringArray(), [], true, false)",
			"\tOS.shell_open(url)",
			"\t# OS.execute(\"git\", [])",
		]),
		"addons/gf/extensions/fixture/gf_fixture.gd",
		"gf.extension.fixture",
	)
	record_result(
		"package_external_command_audit_reports_process_calls",
		issue_exists(
			package_external_command_issues,
			"package_external_process_call",
			row_key="gf.extension.fixture",
			api="OS.execute",
			command="python",
			severity="warning",
		)
		and issue_exists(
			package_external_command_issues,
			"package_external_process_call",
			row_key="gf.extension.fixture",
			api="OS.shell_open",
			severity="warning",
		)
		and not issue_exists(package_external_command_issues, "package_external_process_call", command="git"),
		f"external process calls should be reported while comments stay ignored: {package_external_command_issues}",
	)
	package_external_command_dynamic_issues = audit_package_external_command_source(
		"\n".join([
			"func run(method_name: String) -> void:",
			"\tCallable(OS, \"execute\").call(\"python\", PackedStringArray(), [], true, false)",
			"\tOS.call(\"shell_open\", \"https://example.invalid\")",
			"\tCallable(self, method_name).call()",
		]),
		"addons/gf/extensions/fixture/gf_fixture.gd",
		"gf.extension.fixture",
	)
	record_result(
		"package_external_command_audit_reports_dynamic_process_calls",
		issue_exists(
			package_external_command_dynamic_issues,
			"package_external_process_call",
			row_key="gf.extension.fixture",
			api='Callable(OS, "execute")',
			severity="warning",
		)
		and issue_exists(
			package_external_command_dynamic_issues,
			"package_external_process_call",
			row_key="gf.extension.fixture",
			api='OS.call("shell_open")',
			severity="warning",
		),
		f"dynamic external process calls should be reported: {package_external_command_dynamic_issues}",
	)
	package_git_command_issues = audit_package_external_command_source(
		"func collect() -> void:\n\tOS.execute(\"git\", PackedStringArray(), [], true, false)",
		"addons/gf/standard/utilities/debug/gf_build_info.gd",
		"gf.standard.diagnostics",
	)
	record_result(
		"package_external_command_audit_marks_package_git_as_warning",
		issue_exists(
			package_git_command_issues,
			"package_external_process_call",
			row_key="gf.standard.diagnostics",
			api="OS.execute",
			command="git",
			severity="warning",
		),
		f"package git process calls should be warnings: {package_git_command_issues}",
	)
	package_editor_shell_open_issues = audit_package_external_command_source(
		"func open(url: String) -> void:\n\tOS.shell_open(url)",
		"addons/gf/kernel/editor/gf_editor_workspace_dock.gd",
		"gf.kernel",
	)
	record_result(
		"package_external_command_audit_allows_declared_editor_shell_open",
		package_editor_shell_open_issues == [],
		f"declared editor shell_open calls should be allowlisted: {package_editor_shell_open_issues}",
	)
	record_result(
		"package_external_command_audit_report_only_and_strict_modes",
		make_package_external_command_audit_payload([], ["addons/gf/extensions/fixture/gf_fixture.gd"], package_external_command_issues, False)["ok"]
		and not make_package_external_command_audit_payload([], ["addons/gf/extensions/fixture/gf_fixture.gd"], package_external_command_issues, True)["ok"],
		"report-only mode should pass warnings while strict mode can promote the same baseline to a gate.",
	)
	filtered_package_sources = filter_existing_package_source_paths([
		"addons/gf/kernel/core/gf.gd",
		"addons/gf/kernel/core/__missing_for_maintenance_self_test__.gd",
		"tools/gf_maintenance.py",
	])
	record_result(
		"package_source_boundary_skips_deleted_tracked_sources",
		filtered_package_sources == ["addons/gf/kernel/core/gf.gd"],
		f"package source scans should use current workspace files: {filtered_package_sources}",
	)
	record_result(
		"package_distribution_ownership_includes_docs_and_ignores_import_sidecars",
		should_audit_package_distribution_path("addons/gf/extensions/README.md")
		and not should_audit_package_distribution_path("addons/gf/icon.png.import")
		and not should_audit_package_distribution_path("docs/zh/index.md"),
		"distribution ownership should cover all addon files except explicit generated sidecars.",
	)
	distribution_ownership_records = [{
		"id": "gf.kernel",
		"kind": "kernel",
		"path": "packages/gf.kernel.json",
		"paths": ["addons/gf/kernel/**", "addons/gf/README.md"],
	}]
	distribution_ownership_issues = audit_package_distribution_ownership(
		distribution_ownership_records,
		["addons/gf/kernel/core/gf.gd", "addons/gf/README.md", "addons/gf/UNOWNED.md"],
	)
	record_result(
		"package_distribution_ownership_rejects_unowned_non_source_files",
		len(distribution_ownership_issues) == 1
		and distribution_ownership_issues[0].get("kind") == "package_distribution_unowned_file"
		and distribution_ownership_issues[0].get("path") == "addons/gf/UNOWNED.md",
		f"unowned distributable files should fail: {distribution_ownership_issues}",
	)

	record_result(
		"package_godot_smoke_normalizes_selected_package_ids",
		normalize_package_godot_smoke_package_ids([" gf.standard.base ", "", "gf.standard.base", "gf.kernel"])
		== ["gf.standard.base", "gf.kernel"],
		"selected package ids should be trimmed, de-duplicated, and kept in user order.",
	)
	expected_default_all_jobs = max(1, min(PACKAGE_GODOT_SMOKE_DEFAULT_ALL_PACKAGE_JOBS, os.cpu_count() or 1))
	record_result(
		"package_godot_smoke_job_count_defaults_are_bounded",
		package_godot_smoke_job_count("all", 0) == expected_default_all_jobs
		and package_godot_smoke_job_count("representative", 0) == 1
		and package_godot_smoke_job_count("selected", 0) == 1
		and package_godot_smoke_job_count("all", 2) == 2,
		"package Godot smoke should parallelize all-package mode by default while keeping focused modes serial.",
	)
	record_result(
		"package_godot_smoke_parallel_installs_have_dedicated_timeout_headroom",
		PACKAGE_GODOT_SMOKE_INSTALL_TIMEOUT_SECONDS == 240,
		"all-package workers need a longer install budget than ordinary single-command CLI smoke scenarios.",
	)
	record_result(
		"package_smoke_complex_transactions_have_bounded_timeout_headroom",
		PACKAGE_EDITOR_WIZARD_SMOKE_TRANSACTION_TIMEOUT_SECONDS == 240
		and PACKAGE_GODOT_CLI_SMOKE_PRESET_INSTALL_TIMEOUT_SECONDS == 240
		and package_godot_cli_smoke_command_timeout_seconds(
			["install", "gf.preset.rpg_save_dialogue", "--json"],
			120,
		) == 240
		and package_godot_cli_smoke_command_timeout_seconds(
			["install", "gf.preset.rpg_save_dialogue", "--json"],
			300,
		) == 300
		and package_godot_cli_smoke_command_timeout_seconds(
			["verify", "--json"],
			120,
		) == 120,
		"editor transactions and multi-package CLI preset installs need bounded headroom beyond ordinary smoke commands.",
	)
	package_smoke_assertion_issues: list[dict[str, Any]] = []
	assert_package_godot_smoke_condition(
		False,
		package_smoke_assertion_issues,
		"fixture_scenario",
		"fixture_failure",
		"Fixture package smoke failure.",
		row_key="gf.fixture",
	)
	record_result(
		"package_godot_smoke_assertion_preserves_explicit_row_key",
		len(package_smoke_assertion_issues) == 1
		and package_smoke_assertion_issues[0].get("kind") == "fixture_failure"
		and package_smoke_assertion_issues[0].get("row_key") == "gf.fixture",
		f"package smoke assertion failures must not crash while adding context: {package_smoke_assertion_issues}",
	)

	bad_core_plugin_source = "\n".join([
		"const BadStandard = preload(\"res://addons/gf/standard/utilities/debug/gf_build_info.gd\")",
		"func run() -> void:",
		"\tGFVariantData.get_option_array({})",
	])
	bad_core_only_issues = audit_core_only_plugin_source(
		bad_core_plugin_source,
		"addons/gf/plugin.gd",
		{"GFVariantData": "addons/gf/standard/foundation/variant/gf_variant_data.gd"},
	)
	record_result(
		"core_only_smoke_rejects_standard_preload_and_standard_class_reference",
		issue_exists(bad_core_only_issues, "plugin_preloads_standard")
		and issue_exists(bad_core_only_issues, "plugin_references_standard_class", symbol="GFVariantData"),
		f"standard parse-time references should be reported: {bad_core_only_issues}",
	)

	current_core_only_issues = audit_core_only_plugin_source(
		read_text_file(ROOT / "addons/gf/plugin.gd"),
		"addons/gf/plugin.gd",
		collect_class_name_roots(GF_STANDARD_ROOT),
	)
	record_result(
		"core_only_smoke_accepts_current_root_plugin_entry",
		len(current_core_only_issues) == 0,
		f"root plugin should not require standard at parse time: {current_core_only_issues}",
	)

	package_source_records = [
		{
			"path": "packages/gf.kernel.json",
			"id": "gf.kernel",
			"kind": "kernel",
			"dependencies": [],
			"paths": [
				"addons/gf/plugin.gd",
				"addons/gf/gf_builtin_tool_contributions.json",
				"addons/gf/kernel/**",
			],
			"issues": [],
		},
		{
			"path": "packages/gf.standard.base.json",
			"id": "gf.standard.base",
			"kind": "standard",
			"dependencies": ["gf.kernel"],
			"paths": ["addons/gf/standard/base/**"],
			"issues": [],
		},
		{
			"path": "packages/gf.standard.ui.json",
			"id": "gf.standard.ui",
			"kind": "standard",
			"dependencies": ["gf.kernel", "gf.standard.base"],
			"paths": ["addons/gf/standard/ui/**"],
			"issues": [],
		},
		{
			"path": "packages/extensions/gf.extension.alpha.json",
			"id": "gf.extension.alpha",
			"kind": "extension",
			"dependencies": ["gf.kernel", "gf.standard.ui"],
			"paths": ["addons/gf/extensions/alpha/**"],
			"issues": [],
		},
		{
			"path": "packages/extensions/gf.extension.beta.json",
			"id": "gf.extension.beta",
			"kind": "extension",
			"dependencies": ["gf.kernel"],
			"paths": ["addons/gf/extensions/beta/**"],
			"issues": [],
		},
	]
	package_source_class_roots = {
		"GFBaseThing": "addons/gf/standard/base/base_thing.gd",
		"GFStandardWidget": "addons/gf/standard/ui/widget.gd",
		"GFBetaThing": "addons/gf/extensions/beta/beta_thing.gd",
	}
	package_source_allowed_issues = audit_package_source_references(
		package_source_records,
		["addons/gf/standard/ui/widget.gd"],
		package_source_class_roots,
		{
			"addons/gf/standard/ui/widget.gd": "\n".join([
				"class_name GFStandardWidget",
				"const _BASE = preload(\"res://addons/gf/standard/base/base_thing.gd\")",
				"var base: GFBaseThing",
			]),
		},
	)
	record_result(
		"package_source_boundary_allows_declared_package_references",
		len(package_source_allowed_issues) == 0,
		f"declared package references should pass: {package_source_allowed_issues}",
	)

	package_source_invalid_issues = audit_package_source_references(
		package_source_records,
		["addons/gf/extensions/alpha/feature.gd"],
		package_source_class_roots,
		{
			"addons/gf/extensions/alpha/feature.gd": "\n".join([
				"class_name GFAlphaFeature",
				"const _BETA = preload(\"res://addons/gf/extensions/beta/beta_thing.gd\")",
				"var beta: GFBetaThing",
			]),
		},
	)
	record_result(
		"package_source_boundary_rejects_undeclared_path_and_class_dependencies",
		issue_exists(
			package_source_invalid_issues,
			"package_source_undeclared_path_dependency",
			row_key="gf.extension.alpha",
			target="addons/gf/extensions/beta/beta_thing.gd",
			expected_value="gf.extension.beta",
		)
		and issue_exists(
			package_source_invalid_issues,
			"package_source_undeclared_class_dependency",
			row_key="gf.extension.alpha",
			symbol="GFBetaThing",
			target="addons/gf/extensions/beta/beta_thing.gd",
			expected_value="gf.extension.beta",
		),
		f"undeclared package references should be reported: {package_source_invalid_issues}",
	)

	package_source_catalog_records = [
		*package_source_records,
		{
			"path": "packages/tools/gf.tool.ai_developer.json",
			"id": "gf.tool.ai_developer",
			"kind": "tool",
			"dependencies": ["gf.kernel"],
			"paths": ["addons/gf/tools/ai_developer/**"],
			"issues": [],
		},
	]
	generated_catalog_path = "addons/gf/tools/ai_developer/knowledge/api_index.json"
	generated_catalog_issues = audit_package_source_references(
		package_source_catalog_records,
		[generated_catalog_path],
		package_source_class_roots,
		{generated_catalog_path: '"path": "addons/gf/extensions/beta/beta_thing.gd"'},
	)
	handwritten_catalog_path = "addons/gf/tools/ai_developer/knowledge/handwritten.json"
	handwritten_catalog_issues = audit_package_source_references(
		package_source_catalog_records,
		[handwritten_catalog_path],
		package_source_class_roots,
		{handwritten_catalog_path: '"path": "addons/gf/extensions/beta/beta_thing.gd"'},
	)
	record_result(
		"package_source_boundary_scopes_generated_ai_catalog_references",
		len(generated_catalog_issues) == 0
		and issue_exists(
			handwritten_catalog_issues,
			"package_source_undeclared_path_dependency",
			row_key="gf.tool.ai_developer",
			target="addons/gf/extensions/beta/beta_thing.gd",
			expected_value="gf.extension.beta",
		),
		"only the exact generated AI API catalog may describe paths owned by optional packages.",
	)

	package_source_optional_records = [
		{
			"path": "packages/gf.kernel.json",
			"id": "gf.kernel",
			"kind": "kernel",
			"dependencies": [],
			"paths": [
				"addons/gf/plugin.gd",
				"addons/gf/gf_builtin_tool_contributions.json",
				"addons/gf/kernel/**",
			],
			"issues": [],
		},
		{
			"path": "packages/gf.standard.json",
			"id": "gf.standard",
			"kind": "standard",
			"dependencies": ["gf.kernel"],
			"paths": ["addons/gf/standard/**"],
			"issues": [],
		},
		{
			"path": "packages/tools/gf.tool.project_layout.json",
			"id": "gf.tool.project_layout",
			"kind": "tool",
			"dependencies": ["gf.kernel"],
			"paths": ["addons/gf/tools/project_layout/**"],
			"issues": [],
		},
	]
	package_source_optional_issues = audit_package_source_references(
		package_source_optional_records,
		[
			"addons/gf/plugin.gd",
			"addons/gf/gf_builtin_tool_contributions.json",
			"addons/gf/kernel/extension/gf_extension_catalog.gd",
		],
		package_source_class_roots,
		{
			"addons/gf/plugin.gd": (
				"const STANDARD_EDITOR_CONTRIBUTIONS_MANIFEST_PATH: String = "
				"\"res://addons/gf/standard/editor/gf_editor_contributions.json\""
			),
			"addons/gf/gf_builtin_tool_contributions.json": (
				'"manifest_path": '
				'"res://addons/gf/tools/project_layout/editor/gf_editor_contributions.json"'
			),
			"addons/gf/kernel/extension/gf_extension_catalog.gd": (
				"const EXTENSIONS_PATH: String = \"res://addons/gf/extensions\""
			),
		},
	)
	record_result(
		"package_source_boundary_allows_root_composed_optional_tool_catalog",
		len(package_source_optional_issues) == 0,
		f"narrow optional discovery references should pass: {package_source_optional_issues}",
	)

	with tempfile.TemporaryDirectory(prefix="gf-package-build-self-test-") as temp_dir:
		registry_path = Path(temp_dir) / "registry/index.json"
		registry_path.parent.mkdir(parents=True, exist_ok=True)
		registry_path.write_text(json.dumps({
			"schema_version": PACKAGE_REGISTRY_SCHEMA_VERSION,
			"framework_version": "unreleased",
			"minimum_framework_version": "unreleased",
			"maximum_framework_version_exclusive": "",
			"packages": {
				"gf.kernel": {
					"minimum_framework_version": "unreleased",
					"maximum_framework_version_exclusive": "",
					"archive": "../packages/gf-kernel-unreleased.zip",
					"sha256": "not-the-archive-sha",
					"size_bytes": 123,
					"signature_url": "../packages/gf-kernel-unreleased.zip.sig",
				},
			},
		}), encoding="utf-8")
		package_build_issues = audit_package_build_result(
			{
				"ok": True,
				"packages": [
					{
						"ok": True,
						"id": "gf.kernel",
						"archive": str(Path(temp_dir) / "packages/gf-kernel-unreleased.zip"),
						"sha256": "builder-sha",
						"size_bytes": 456,
						"issues": [],
					}
				],
				"issues": [],
			},
			registry_path,
		)
	record_result(
		"package_build_boundary_reports_missing_archive_and_registry_mismatch",
		issue_exists(package_build_issues, "package_archive_missing", row_key="gf.kernel")
		and issue_exists(package_build_issues, "package_registry_sha256_mismatch", row_key="gf.kernel")
		and issue_exists(package_build_issues, "package_registry_size_mismatch", row_key="gf.kernel")
		and issue_exists(package_build_issues, "package_registry_signature_field", row_key="gf.kernel", field="signature_url"),
		f"package build archive and registry mismatches should be reported: {package_build_issues}",
	)

	with tempfile.TemporaryDirectory(prefix="gf-package-build-tool-self-test-") as temp_dir:
		archive_path = Path(temp_dir) / "packages/gf-kernel-unreleased.zip"
		archive_path.parent.mkdir(parents=True, exist_ok=True)
		with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
			archive.writestr("addons/gf/plugin.gd", "# fixture\n")
			archive.writestr("addons/gf/kernel/package_tools/gf_package_installer.py", "# fixture\n")
		registry_path = Path(temp_dir) / "registry/index.json"
		registry_path.parent.mkdir(parents=True, exist_ok=True)
		registry_path.write_text(json.dumps({
			"schema_version": PACKAGE_REGISTRY_SCHEMA_VERSION,
			"framework_version": "unreleased",
			"minimum_framework_version": "unreleased",
			"maximum_framework_version_exclusive": "",
			"packages": {
				"gf.kernel": {
					"minimum_framework_version": "unreleased",
					"maximum_framework_version_exclusive": "",
					"archive": "../packages/gf-kernel-unreleased.zip",
					"sha256": sha256_path(archive_path),
					"size_bytes": archive_path.stat().st_size,
				},
			},
		}), encoding="utf-8")
		package_tool_archive_issues = audit_package_build_result(
			{
				"ok": True,
				"packages": [
					{
						"ok": True,
						"id": "gf.kernel",
						"archive": str(archive_path),
						"sha256": sha256_path(archive_path),
						"size_bytes": archive_path.stat().st_size,
						"issues": [],
					}
				],
				"issues": [],
			},
			registry_path,
		)
	record_result(
		"package_build_boundary_rejects_kernel_python_package_tools",
		issue_exists(package_tool_archive_issues, "kernel_archive_contains_package_tool", row_key="gf.kernel"),
		f"kernel package tools should be rejected from shipped gf.kernel archives: {package_tool_archive_issues}",
	)

	with tempfile.TemporaryDirectory(prefix="gf-package-build-external-tool-self-test-") as temp_dir:
		archive_path = Path(temp_dir) / "packages/gf-extension-save-unreleased.zip"
		archive_path.parent.mkdir(parents=True, exist_ok=True)
		with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
			archive.writestr("addons/gf/extensions/save/gf_save.gd", "# fixture\n")
			archive.writestr("addons/gf/extensions/save/install.py", "# fixture\n")
			archive.writestr("addons/gf/extensions/save/package.json", "{}\n")
		registry_path = Path(temp_dir) / "registry/index.json"
		registry_path.parent.mkdir(parents=True, exist_ok=True)
		registry_path.write_text(json.dumps({
			"schema_version": PACKAGE_REGISTRY_SCHEMA_VERSION,
			"framework_version": "unreleased",
			"minimum_framework_version": "unreleased",
			"maximum_framework_version_exclusive": "",
			"packages": {
				"gf.extension.save": {
					"minimum_framework_version": "unreleased",
					"maximum_framework_version_exclusive": "",
					"archive": "../packages/gf-extension-save-unreleased.zip",
					"sha256": sha256_path(archive_path),
					"size_bytes": archive_path.stat().st_size,
				},
			},
		}), encoding="utf-8")
		external_tool_archive_issues = audit_package_build_result(
			{
				"ok": True,
				"packages": [
					{
						"ok": True,
						"id": "gf.extension.save",
						"archive": str(archive_path),
						"sha256": sha256_path(archive_path),
						"size_bytes": archive_path.stat().st_size,
						"issues": [],
					}
				],
				"issues": [],
			},
			registry_path,
		)
	record_result(
		"package_build_boundary_rejects_runtime_external_tool_payload",
		issue_exists(external_tool_archive_issues, "runtime_package_external_tool_payload", row_key="gf.extension.save"),
		f"runtime package archives should reject Python/npm/shell payloads: {external_tool_archive_issues}",
	)

	with tempfile.TemporaryDirectory(prefix="gf-package-source-signature-self-test-") as temp_dir:
		registry_path = Path(temp_dir) / "registry/index.json"
		registry_source_path = Path(temp_dir) / "registry/gf-registry-source.json"
		registry_path.parent.mkdir(parents=True, exist_ok=True)
		registry_path.write_text(json.dumps({
			"schema_version": PACKAGE_REGISTRY_SCHEMA_VERSION,
			"framework_version": "1.2.3",
			"minimum_framework_version": "1.2.3",
			"maximum_framework_version_exclusive": "2.0.0",
			"packages": {},
		}), encoding="utf-8")
		registry_source_path.write_text(json.dumps({
			"schema_version": 1,
			"default_channel": "stable",
			"channels": {
				"stable": {
					"registry": "index.json",
					"registry_sha256": sha256_path(registry_path),
					"registry_size_bytes": registry_path.stat().st_size,
					"registry_signature_url": "gf-registry-1.2.3.json.sig",
					"mirrors": [],
				},
			},
		}), encoding="utf-8")
		package_source_signature_issues = audit_package_build_registry_source_manifest(
			registry_source_path,
			registry_path,
		)
	record_result(
		"package_build_boundary_rejects_registry_source_signature_fields_without_verification",
		issue_exists(
			package_source_signature_issues,
			"package_registry_source_signature_field",
			row_key="stable",
			field="registry_signature_url",
		),
		f"registry source signature fields should be rejected until native verification exists: {package_source_signature_issues}",
	)

	public_api_allowed_issues = audit_public_api_boundary_text(
		"class_name GFDeterministicRandom\nclass_name GFGraphPathSearchState",
		"addons/gf/fixture.gd",
	)
	record_result(
		"public_api_boundary_allows_mechanism_class_names",
		len(public_api_allowed_issues) == 0,
		f"mechanism class names should pass: {public_api_allowed_issues}",
	)

	public_api_forbidden_issues = audit_public_api_boundary_text(
		"class_name GFPathfinding2D\n<class name=\"GFDeterministicMath\" />",
		"addons/gf/fixture.gd",
	)
	record_result(
		"public_api_boundary_rejects_planning_track_names",
		issue_exists(public_api_forbidden_issues, "forbidden_public_api_route_name", symbol="GFPathfinding2D")
		and issue_exists(public_api_forbidden_issues, "forbidden_public_api_route_name", symbol="GFDeterministicMath"),
		"planning track names must not become source/API reference names.",
	)

	private_script_signature_source = "\n".join([
		'const _RESOURCE_BROKER_SCRIPT = preload("res://addons/gf/fixture/gf_resource_broker.gd")',
		"class_name GFPrivateScriptSignatureFixture",
		"extends RefCounted",
		"",
		"## Configure.",
		"## @api public",
		"## @param broker: Broker.",
		"func configure(broker: _RESOURCE_BROKER_SCRIPT) -> void:",
		"\tpass",
		"",
		"## Resolve.",
		"## @api protected",
		"## @return: Broker.",
		"func _resolve() -> _RESOURCE_BROKER_SCRIPT:",
		"\treturn null",
	])
	private_script_signature_issues = audit_private_script_constant_api_exposure_text(
		private_script_signature_source,
		"addons/gf/fixture/gf_private_script_signature_fixture.gd",
	)
	record_result(
		"public_api_boundary_rejects_private_script_constant_parameter_and_return_types",
		issue_exists(
			private_script_signature_issues,
			"private_script_constant_api_exposure",
			api="public",
			symbol="_RESOURCE_BROKER_SCRIPT",
		)
		and issue_exists(
			private_script_signature_issues,
			"private_script_constant_api_exposure",
			api="protected",
			symbol="_RESOURCE_BROKER_SCRIPT",
		)
		and len(private_script_signature_issues) == 2,
		f"public/protected signatures must reject private script constant types: {private_script_signature_issues}",
	)

	private_script_internal_source = "\n".join([
		'const _RESOURCE_BROKER_SCRIPT = preload("res://addons/gf/fixture/gf_resource_broker.gd")',
		"class_name GFPrivateScriptInternalFixture",
		"extends RefCounted",
		"",
		"## Create.",
		"## @api public",
		"## @return: Broker.",
		"func create() -> GFResourceBroker:",
		"\tvar broker: _RESOURCE_BROKER_SCRIPT = _RESOURCE_BROKER_SCRIPT.new()",
		"\treturn broker",
		"",
		"## Internal helper.",
		"## @api framework_internal",
		"## @param broker: Broker.",
		"## @return: Broker.",
		"func normalize_for_framework(broker: _RESOURCE_BROKER_SCRIPT) -> _RESOURCE_BROKER_SCRIPT:",
		"\treturn broker",
		"",
		"func _private_helper(broker: _RESOURCE_BROKER_SCRIPT) -> _RESOURCE_BROKER_SCRIPT:",
		"\treturn broker",
	])
	private_script_internal_issues = audit_private_script_constant_api_exposure_text(
		private_script_internal_source,
		"addons/gf/fixture/gf_private_script_internal_fixture.gd",
	)
	record_result(
		"public_api_boundary_allows_private_script_types_in_internal_and_local_implementation",
		len(private_script_internal_issues) == 0,
		(
			"private script constant types may remain in local implementation and non-public methods: "
			f"{private_script_internal_issues}"
		),
	)

	api_schema_class_snapshot = parse_api_class_snapshot(
		ET.fromstring(
			'<class name="GFSchemaFixture" path="classes/GFSchemaFixture.xml" '
			'sourcePath="addons/gf/fixture/gf_schema_fixture.gd" extends="RefCounted" />'
		),
		ET.fromstring(
			'<class name="GFSchemaFixture" module="fixture">'
			'<methods><member kind="method" name="snapshot">'
			'<signature>func snapshot() -&gt; Dictionary:</signature>'
			'<tags><tag name="schema">return: Dictionary with stable_field.</tag></tags>'
			'</member></methods></class>'
		),
		"fixture",
	)
	record_result(
		"api_baseline_snapshot_reads_schema_tags",
		api_schema_class_snapshot["members"]["method:snapshot"]["schema"]
		== ["return: Dictionary with stable_field."],
		f"API baseline snapshots must preserve structured schema tags: {api_schema_class_snapshot}",
	)
	api_inner_catalog_snapshot = parse_api_catalog_snapshot(
		(
			'<apiCatalog schemaVersion="1"><module id="fixture">'
			'<class name="GFOuter" path="classes/GFOuter.xml" />'
			'<class name="GFOuter.Inner" path="classes/GFOuter.xml" />'
			"</module></apiCatalog>"
		),
		lambda _class_path: (
			'<class name="GFOuter" module="fixture">'
			'<methods><member kind="method" name="snapshot">'
			'<signature>func snapshot() -&gt; Dictionary:</signature>'
			'<tags><tag name="schema">return: outer schema.</tag></tags>'
			"</member></methods>"
			'<innerClasses><class name="Inner" fullName="GFOuter.Inner">'
			'<methods><member kind="method" name="snapshot">'
			'<signature>func snapshot() -&gt; Dictionary:</signature>'
			'<tags><tag name="schema">return: inner schema.</tag></tags>'
			"</member></methods>"
			"</class></innerClasses></class>"
		),
		"fixture",
	)
	record_result(
		"api_baseline_snapshot_resolves_inner_class_nodes",
		not api_inner_catalog_snapshot["errors"]
		and api_inner_catalog_snapshot["classes"]["GFOuter"]["members"][
			"method:snapshot"
		]["schema"] == ["return: outer schema."]
		and api_inner_catalog_snapshot["classes"]["GFOuter.Inner"]["members"][
			"method:snapshot"
		]["schema"] == ["return: inner schema."],
		(
			"API baseline snapshots must resolve index inner-class references to "
			f"their matching nested XML node: {api_inner_catalog_snapshot}"
		),
	)
	api_v2_catalog_snapshot = parse_api_catalog_snapshot(
		'<apiCatalog schemaVersion="2" classCount="0" methodCount="0" />',
		lambda _owner_path: "",
		"v2 fixture",
	)
	api_v3_catalog_snapshot = parse_api_catalog_snapshot(
		(
			'<apiCatalog schemaVersion="3" classCount="0" methodCount="0" '
			'autoloadCount="1" autoloadMethodCount="1"><module id="kernel" '
			'label="Kernel" classCount="0" methodCount="0" autoloadCount="1" '
			'autoloadMethodCount="1"><autoload name="Gf" path="autoloads/Gf.xml" '
			'sourcePath="addons/gf/kernel/core/gf.gd" extends="Node" '
			'packageId="gf.kernel" /></module></apiCatalog>'
		),
		lambda _owner_path: (
			'<autoload name="Gf" path="addons/gf/kernel/core/gf.gd" module="kernel" '
			'extends="Node" packageId="gf.kernel"><methods><member kind="method" '
			'name="get_architecture"><signature>func get_architecture() -&gt; GFArchitecture:'
			'</signature></member></methods></autoload>'
		),
		"v3 fixture",
	)
	api_invalid_v3_catalog_snapshot = parse_api_catalog_snapshot(
		(
			'<apiCatalog schemaVersion="3" autoloadCount="2" autoloadMethodCount="0">'
			'<module id="kernel"><autoload name="Gf" path="autoloads/Gf.xml" '
			'sourcePath="addons/gf/kernel/core/gf.gd" extends="Node" /></module>'
			'</apiCatalog>'
		),
		lambda _owner_path: (
			'<autoload name="Gf" path="addons/gf/kernel/core/gf.gd" module="kernel" '
			'extends="Node" />'
		),
		"invalid v3 fixture",
	)
	api_v2_to_v3_diff = compare_api_catalog_snapshots(
		api_v2_catalog_snapshot,
		api_v3_catalog_snapshot,
	)
	record_result(
		"api_baseline_snapshot_reads_v2_and_v3_autoload_owners",
		not api_v2_catalog_snapshot["errors"]
		and api_v2_catalog_snapshot["autoloads"] == {}
		and not api_v3_catalog_snapshot["errors"]
		and api_v3_catalog_snapshot["class_count"] == 0
		and api_v3_catalog_snapshot["autoload_count"] == 1
		and api_v3_catalog_snapshot["autoloads"]["Gf"]["kind"] == "autoload"
		and api_v3_catalog_snapshot["autoloads"]["Gf"]["package_id"] == "gf.kernel"
		and api_invalid_v3_catalog_snapshot["errors"]
		and len(api_v2_to_v3_diff["added_autoloads"]) == 1
		and not api_v2_to_v3_diff["added_classes"],
		f"v2/v3 autoload baseline migration must stay distinct from classes: {api_v3_catalog_snapshot}, {api_v2_to_v3_diff}",
	)

	api_base_snapshot = {
		"classes": {
			"GFStable": make_api_snapshot_class(
				"GFStable",
				"RefCounted",
				{
					"method:kept": make_api_snapshot_member("method", "kept", "func kept() -> int:"),
					"method:removed": make_api_snapshot_member("method", "removed", "func removed() -> void:"),
					"method:changed": make_api_snapshot_member("method", "changed", "func changed() -> int:"),
				},
			),
			"GFRemoved": make_api_snapshot_class("GFRemoved", "RefCounted", {}),
			"GFExtendsChanged": make_api_snapshot_class("GFExtendsChanged", "RefCounted", {}),
		},
	}
	api_current_snapshot = {
		"classes": {
			"GFStable": make_api_snapshot_class(
				"GFStable",
				"RefCounted",
				{
					"method:kept": make_api_snapshot_member("method", "kept", "func kept() -> int:"),
					"method:changed": make_api_snapshot_member("method", "changed", "func changed() -> String:"),
					"method:added": make_api_snapshot_member("method", "added", "func added() -> void:"),
				},
			),
			"GFAdded": make_api_snapshot_class("GFAdded", "RefCounted", {}),
			"GFExtendsChanged": make_api_snapshot_class("GFExtendsChanged", "Object", {}),
		},
	}
	api_catalog_diff = compare_api_catalog_snapshots(api_base_snapshot, api_current_snapshot)
	classified_api_catalog_diff = classify_api_signature_changes(api_catalog_diff["signature_changes"])
	record_result(
		"api_baseline_diff_reports_class_and_member_changes",
		len(api_catalog_diff["added_classes"]) == 1
		and len(api_catalog_diff["removed_classes"]) == 1
		and len(api_catalog_diff["added_members"]) == 1
		and len(api_catalog_diff["removed_members"]) == 1
		and len(api_catalog_diff["signature_changes"]) == 1
		and len(classified_api_catalog_diff["breaking"]) == 1
		and len(api_catalog_diff["extends_changes"]) == 1,
		f"unexpected api catalog diff fixture result: {api_catalog_diff}",
	)
	api_autoload_base_snapshot = {
		"autoloads": {
			"Gf": make_api_snapshot_autoload(
				"Gf",
				"Node",
				"gf.kernel",
				{
					"method:kept": make_api_snapshot_member("method", "kept", "func kept() -> int:"),
					"method:removed": make_api_snapshot_member("method", "removed", "func removed() -> void:"),
					"method:changed": make_api_snapshot_member("method", "changed", "func changed() -> int:"),
				},
			),
		},
	}
	api_autoload_current_snapshot = {
		"classes": {},
		"autoloads": {
			"Gf": make_api_snapshot_autoload(
				"Gf",
				"Control",
				"gf.runtime",
				{
					"method:kept": make_api_snapshot_member("method", "kept", "func kept() -> int:"),
					"method:changed": make_api_snapshot_member("method", "changed", "func changed() -> String:"),
					"method:added": make_api_snapshot_member("method", "added", "func added() -> void:"),
				},
				source_path="addons/gf/kernel/core/gf_runtime.gd",
			),
		},
	}
	api_autoload_diff = compare_api_catalog_snapshots(
		api_autoload_base_snapshot,
		api_autoload_current_snapshot,
	)
	classified_api_autoload_diff = classify_api_signature_changes(
		api_autoload_diff["autoload_signature_changes"],
		api_autoload_base_snapshot,
	)
	record_result(
		"api_baseline_diff_protects_autoload_identity_and_members",
		not api_autoload_diff["added_classes"]
		and not api_autoload_diff["removed_classes"]
		and not api_autoload_diff["added_autoloads"]
		and not api_autoload_diff["removed_autoloads"]
		and len(api_autoload_diff["autoload_identity_changes"]) == 1
		and set(api_autoload_diff["autoload_identity_changes"][0]["changed_fields"])
		== {"source_path", "package_id"}
		and len(api_autoload_diff["autoload_extends_changes"]) == 1
		and len(api_autoload_diff["autoload_added_members"]) == 1
		and len(api_autoload_diff["autoload_removed_members"]) == 1
		and len(api_autoload_diff["autoload_signature_changes"]) == 1
		and len(classified_api_autoload_diff["breaking"]) == 1,
		f"autoload identity and member changes must remain SemVer-visible without class coercion: {api_autoload_diff}",
	)
	api_compatible_base_snapshot = {
		"classes": {
			"GFStable": make_api_snapshot_class(
				"GFStable",
				"RefCounted",
				{
					"method:with_optional": make_api_snapshot_member(
						"method",
						"with_optional",
						"func with_optional(value: int) -> void:",
					),
					"method:widen": make_api_snapshot_member(
						"method",
						"widen",
						"func widen(rng: RandomNumberGenerator = null) -> void:",
					),
					"method:mode": make_api_snapshot_member(
						"method",
						"mode",
						"func mode(value: Mode = Mode.A) -> void:",
					),
					"method:default_change": make_api_snapshot_member(
						"method",
						"default_change",
						"func default_change(value: int = 1) -> void:",
					),
					"enum:Mode": make_api_snapshot_member("enum", "Mode", "enum Mode { A, B, }"),
				},
			),
		},
	}
	api_compatible_current_snapshot = {
		"classes": {
			"GFStable": make_api_snapshot_class(
				"GFStable",
				"RefCounted",
				{
					"method:with_optional": make_api_snapshot_member(
						"method",
						"with_optional",
						"func with_optional(value: int, options: Dictionary = {}) -> void:",
					),
					"method:widen": make_api_snapshot_member(
						"method",
						"widen",
						"func widen(rng: Variant = null) -> void:",
					),
					"method:mode": make_api_snapshot_member(
						"method",
						"mode",
						"func mode(value: int = Mode.A) -> void:",
					),
					"method:default_change": make_api_snapshot_member(
						"method",
						"default_change",
						"func default_change(value: int = 2) -> void:",
					),
					"enum:Mode": make_api_snapshot_member("enum", "Mode", "enum Mode { A, B, C, }"),
				},
			),
		},
	}
	api_compatible_diff = compare_api_catalog_snapshots(
		api_compatible_base_snapshot,
		api_compatible_current_snapshot,
	)
	classified_api_compatible_diff = classify_api_signature_changes(
		api_compatible_diff["signature_changes"],
		api_compatible_base_snapshot,
	)
	record_result(
		"api_baseline_diff_classifies_provable_call_compatibility",
		len(classified_api_compatible_diff["breaking"]) == 1
		and len(classified_api_compatible_diff["compatible"]) == 4,
		f"parameter widening, appended optional parameters, and enum additions should stay compatible while default changes remain breaking: {classified_api_compatible_diff}",
	)
	api_schema_base_snapshot = {
		"classes": {
			"GFStable": make_api_snapshot_class(
				"GFStable",
				"RefCounted",
				{
					"method:changed_schema": make_api_snapshot_member(
						"method",
						"changed_schema",
						"func changed_schema() -> Dictionary:",
						["return: Dictionary with current_bgm_loop."],
					),
					"method:documented_schema": make_api_snapshot_member(
						"method",
						"documented_schema",
						"func documented_schema() -> Dictionary:",
					),
				},
			),
		},
	}
	api_schema_current_snapshot = {
		"classes": {
			"GFStable": make_api_snapshot_class(
				"GFStable",
				"RefCounted",
				{
					"method:changed_schema": make_api_snapshot_member(
						"method",
						"changed_schema",
						"func changed_schema() -> Dictionary:",
						["return: Dictionary with current_bgm_region."],
					),
					"method:documented_schema": make_api_snapshot_member(
						"method",
						"documented_schema",
						"func documented_schema() -> Dictionary:",
						["return: Dictionary with stable fields."],
					),
				},
			),
		},
	}
	api_schema_diff = compare_api_catalog_snapshots(
		api_schema_base_snapshot,
		api_schema_current_snapshot,
	)
	classified_api_schema_diff = classify_api_schema_changes(
		api_schema_diff["schema_changes"],
	)
	record_result(
		"api_baseline_diff_classifies_schema_contract_changes",
		len(api_schema_diff["schema_changes"]) == 2
		and len(classified_api_schema_diff["breaking"]) == 1
		and len(classified_api_schema_diff["compatible"]) == 1
		and not api_schema_change_is_compatible({
			"old_schema": ["options: accepts arbitrary keys."],
			"new_schema": [
				"options: accepts arbitrary keys.",
				"options: key loop is forbidden.",
			],
		}),
		f"rewritten or restriction-appended free-text schema contracts must fail closed while newly documented contracts remain compatible: {classified_api_schema_diff}",
	)
	record_result(
		"api_baseline_diff_requires_major_for_breaking_changes",
		not api_diff_breaking_allowed("4.4.0", "4.5.0")
		and api_diff_breaking_allowed("4.4.0", "5.0.0")
		and api_diff_breaking_allowed("10.0.0", "11.0.0-dev.0")
		and not api_diff_breaking_allowed("10.0.0", "10.1.0-dev.0"),
		"breaking API baseline changes should require a major version bump.",
	)
	record_result(
		"api_baseline_diff_requires_minor_for_compatible_features",
		not api_diff_compatible_feature_allowed("8.0.1", "8.0.2")
		and api_diff_compatible_feature_allowed("8.0.1", "8.1.0")
		and api_diff_compatible_feature_allowed("8.0.1", "9.0.0")
		and api_diff_compatible_feature_allowed(
			"10.0.0",
			"11.0.0-dev.0",
		)
		and not api_diff_compatible_feature_allowed(
			"10.0.0",
			"10.0.1-dev.0",
		),
		"backward-compatible public API additions should require at least a minor version bump.",
	)
	record_result(
		"api_baseline_diff_derives_governed_release_target",
		api_diff_release_target_version("11.0.0-dev.0") == "11.0.0"
		and api_diff_release_target_version("11.0.0") == "11.0.0"
		and api_diff_release_target_version("11.0.0-rc.1") == ""
		and api_diff_release_target_version("11.0.0-dev.0+ci") == "",
		"API baseline selection and version enforcement must share the governed release core used by the Changelog gate.",
	)
	record_result(
		"changelog_policy_derives_governed_release_target",
		changelog_release_target_version("11.0.0-dev.0") == "11.0.0"
		and changelog_release_target_version("11.0.0") == "11.0.0"
		and changelog_release_target_version("11.0.0-rc.1") == ""
		and changelog_release_target_version("11.0.0-dev.0+ci") == "",
		"the current Changelog gate must enforce API SemVer against the stable core of only governed framework identities.",
	)
	valid_changelog_body = (
		"\n**版本概述**：Fixture release notes.\n\n"
		"### 🔄 机制更改 (Changed)\n\n"
		"- Describe the consumer-visible change.\n"
	)
	valid_changelog_preamble = (
		"# 更新日志 (Changelog)\n\n"
	)
	valid_changelog_report = audit_release_changelog(
		"7.0.0",
		(
			valid_changelog_preamble
			+ "## [7.0.0] - 2026-07-14\n"
			+ valid_changelog_body
		),
	)
	record_result(
		"release_changelog_accepts_exactly_one_current_release",
		len(valid_changelog_report["issues"]) == 0,
		f"valid release changelog fixture should pass: {valid_changelog_report}",
	)
	valid_stable_changelog_policy_report = audit_current_changelog(
		"7.0.0",
		valid_changelog_preamble
		+ "## [7.0.0] - 2026-07-14\n"
		+ valid_changelog_body,
	)
	record_result(
		"stable_changelog_policy_accepts_one_matching_formal_section",
		valid_stable_changelog_policy_report["ok"]
		and valid_stable_changelog_policy_report["mode"] == "stable"
		and valid_stable_changelog_policy_report["section_count"] == 1,
		f"one structured matching formal section should pass for a stable identity: {valid_stable_changelog_policy_report}",
	)
	invalid_changelog_report = audit_release_changelog(
		"7.0.0",
		(
			valid_changelog_preamble
			+ "## [未发布]\n"
			+ valid_changelog_body
			+ "\n## [7.0.0] - 2026-07-14\n"
			+ valid_changelog_body
			+ "\n## [6.2.0] - 2026-06-14\n"
			+ valid_changelog_body
		),
	)
	record_result(
		"release_changelog_rejects_unreleased_and_stale_current_history",
		any("unreleased section" in issue for issue in invalid_changelog_report["issues"])
		and any("must contain only the target" in issue for issue in invalid_changelog_report["issues"]),
		f"release changelog must reject pending notes and old current sections: {invalid_changelog_report}",
	)
	duplicate_changelog_report = audit_release_changelog(
		"7.0.0",
		(
			valid_changelog_preamble
			+ "## [7.0.0] - 2026-07-14\n"
			+ valid_changelog_body
			+ "\n## [7.0.0] - 2026-07-14\n"
			+ valid_changelog_body
		),
	)
	record_result(
		"release_changelog_rejects_duplicate_target_sections",
		any("exactly one section" in issue for issue in duplicate_changelog_report["issues"]),
		f"duplicate target sections must fail release validation: {duplicate_changelog_report}",
	)
	malformed_changelog_report = audit_release_changelog(
		"7.0.0",
		valid_changelog_preamble + "## [7.0.0] - 2026-02-30\n",
	)
	record_result(
		"release_changelog_rejects_empty_body_and_invalid_date",
		any("must not be empty" in issue for issue in malformed_changelog_report["issues"])
		and any("invalid calendar date" in issue for issue in malformed_changelog_report["issues"]),
		f"empty or invalid target sections must fail release validation: {malformed_changelog_report}",
	)
	valid_development_changelog_report = audit_current_changelog(
		"7.1.0-dev.0",
		valid_changelog_preamble + "## [未发布]\n" + valid_changelog_body,
	)
	record_result(
		"development_changelog_accepts_one_canonical_unreleased_section",
		valid_development_changelog_report["ok"]
		and valid_development_changelog_report["mode"] == "development"
		and valid_development_changelog_report["section_count"] == 1,
		f"one structured [未发布] section should pass during development: {valid_development_changelog_report}",
	)
	stale_development_changelog_report = audit_current_changelog(
		"7.1.0-dev.0",
		(
			valid_changelog_preamble
			+ "## [未发布]\n"
			+ valid_changelog_body
			+ "\n## [7.0.0] - 2026-07-14\n"
			+ valid_changelog_body
		),
	)
	record_result(
		"development_changelog_rejects_stale_formal_history",
		not stale_development_changelog_report["ok"]
		and any(
			"must not retain formal release sections" in issue
			for issue in stale_development_changelog_report["issues"]
		),
		f"published sections must leave the development working tree: {stale_development_changelog_report}",
	)
	duplicate_development_changelog_report = audit_current_changelog(
		"7.1.0-dev.0",
		(
			valid_changelog_preamble
			+ "## [未发布]\n"
			+ valid_changelog_body
			+ "\n## [未发布]\n"
			+ valid_changelog_body
		),
	)
	record_result(
		"development_changelog_rejects_duplicate_unreleased_sections",
		not duplicate_development_changelog_report["ok"]
		and any(
			"exactly one canonical [未发布]" in issue
			for issue in duplicate_development_changelog_report["issues"]
		),
		f"duplicate development candidates must fail: {duplicate_development_changelog_report}",
	)
	noncanonical_development_changelog_report = audit_current_changelog(
		"7.1.0-dev.0",
		valid_changelog_preamble + "## [Unreleased]\n" + valid_changelog_body,
	)
	record_result(
		"development_changelog_rejects_noncanonical_release_headings",
		not noncanonical_development_changelog_report["ok"]
		and any(
			"unsupported release headings" in issue
			for issue in noncanonical_development_changelog_report["issues"]
		),
		f"only the canonical Chinese development heading should pass: {noncanonical_development_changelog_report}",
	)
	unstructured_development_changelog_report = audit_current_changelog(
		"7.1.0-dev.0",
		(
			valid_changelog_preamble
			+ "## [未发布]\n\n"
			"### 📘 升级指南 (Migration Guide)\n\n"
			"### 🚀 新增特性 (Added)\n\n"
			"- Added after migration.\n"
		),
	)
	record_result(
		"changelog_entry_structure_requires_overview_order_and_nonempty_categories",
		not unstructured_development_changelog_report["ok"]
		and any("exactly one '**版本概述**" in issue for issue in unstructured_development_changelog_report["issues"])
		and any("must not be empty" in issue for issue in unstructured_development_changelog_report["issues"])
		and any("standard category order" in issue for issue in unstructured_development_changelog_report["issues"]),
		f"the documented entry template must be executable policy: {unstructured_development_changelog_report}",
	)
	late_overview_changelog_report = audit_current_changelog(
		"7.1.0-dev.0",
		(
			valid_changelog_preamble
			+ "## [未发布]\n\n"
			"### 🚀 新增特性 (Added)\n\n"
			"**版本概述**：This overview is too late.\n\n"
			"### 🔄 机制更改 (Changed)\n\n"
			"- Real changed body.\n"
		),
	)
	record_result(
		"changelog_entry_structure_rejects_late_overview_as_category_body",
		not late_overview_changelog_report["ok"]
		and any(
			"version overview must be the first visible entry" in issue
			for issue in late_overview_changelog_report["issues"]
		)
		and any(
			"category '### 🚀 新增特性 (Added)' must not be empty" in issue
			for issue in late_overview_changelog_report["issues"]
		),
		f"a late overview must not satisfy an otherwise empty category: {late_overview_changelog_report}",
	)
	rendered_prelude_reports = [
		audit_current_changelog(
			"7.1.0-dev.0",
			(
				valid_changelog_preamble
				+ "## [未发布]\n\n"
				+ prelude
				+ valid_changelog_body
			),
		)
		for prelude in (
			"```text\nVisible code before overview.\n```\n",
			"    Visible indented code before overview.\n",
		)
	]
	comment_before_overview_report = audit_current_changelog(
		"7.1.0-dev.0",
		(
			valid_changelog_preamble
			+ "## [未发布]\n\n"
			+ "<!-- Maintenance-only note. -->\n"
			+ valid_changelog_body
		),
	)
	record_result(
		"changelog_entry_structure_requires_overview_before_rendered_code",
		all(not report["ok"] for report in rendered_prelude_reports)
		and all(
			any(
				"version overview must be the first visible entry" in issue
				for issue in report["issues"]
			)
			for report in rendered_prelude_reports
		)
		and comment_before_overview_report["ok"],
		"fenced and indented code render as candidate content and cannot precede the overview; a standalone HTML comment remains non-rendered.",
	)
	unsupported_category_changelog_report = audit_current_changelog(
		"7.1.0-dev.0",
		(
			valid_changelog_preamble
			+ "## [未发布]\n\n"
			"**版本概述**：Unsupported category fixture.\n\n"
			"### Custom Changes\n\n"
			"- Not part of the documented schema.\n"
		),
	)
	record_result(
		"changelog_entry_structure_rejects_unsupported_categories",
		not unsupported_category_changelog_report["ok"]
		and any(
			"unsupported changelog category" in issue
			for issue in unsupported_category_changelog_report["issues"]
		)
		and any(
			"at least one standard change category" in issue
			for issue in unsupported_category_changelog_report["issues"]
		),
		f"custom headings must not bypass the documented category schema: {unsupported_category_changelog_report}",
	)
	fenced_heading_changelog_report = audit_current_changelog(
		"7.1.0-dev.0",
		(
			valid_changelog_preamble
			+ "## [未发布]\n"
			+ valid_changelog_body
			+ "\n```markdown\n"
			"## [7.0.0] - 2026-07-14\n"
			"```\n"
			"<!--\n"
			"## [6.0.0] - 2025-01-01\n"
			"-->\n"
		),
	)
	record_result(
		"changelog_parser_ignores_fenced_release_headings",
		fenced_heading_changelog_report["ok"]
		and fenced_heading_changelog_report["section_count"] == 1,
		f"release-looking examples inside fenced code must not become current sections: {fenced_heading_changelog_report}",
	)
	invalid_backtick_info_changelog_report = audit_current_changelog(
		"7.1.0-dev.0",
		(
			valid_changelog_preamble
			+ "## [未发布]\n"
			+ valid_changelog_body
			+ "\n```bad`info\n"
			"## [7.0.0] - 2026-07-14\n"
			+ valid_changelog_body
			+ "\n```\n"
		),
	)
	record_result(
		"changelog_parser_rejects_invalid_backtick_info_fence",
		not invalid_backtick_info_changelog_report["ok"]
		and invalid_backtick_info_changelog_report["section_count"] == 2
		and any(
			"must not retain formal release sections" in issue
			for issue in invalid_backtick_info_changelog_report["issues"]
		),
		"an invalid backtick info string must not hide a visible stale release heading.",
	)
	fenced_overview_changelog_report = audit_current_changelog(
		"7.1.0-dev.0",
		(
			valid_changelog_preamble
			+ "## [未发布]\n\n"
			"```text\n"
			"**版本概述**：Hidden in code.\n"
			"```\n\n"
			"### 🔄 机制更改 (Changed)\n\n"
			"- Real category body.\n"
		),
	)
	indented_category_changelog_report = audit_current_changelog(
		"7.1.0-dev.0",
		(
			valid_changelog_preamble
			+ "## [未发布]\n\n"
			"**版本概述**：Real overview.\n\n"
			"    ### 🔄 机制更改 (Changed)\n"
			"    - Hidden in indented code.\n"
		),
	)
	mixed_indented_category_reports = [
		audit_current_changelog(
			"7.1.0-dev.0",
			(
				valid_changelog_preamble
				+ "## [未发布]\n\n"
				"**版本概述**：Real overview.\n\n"
				f"{prefix}### 🔄 机制更改 (Changed)\n"
				f"{prefix}- Hidden in mixed-indented code.\n"
			),
		)
		for prefix in (" \t", "  \t", "   \t")
	]
	mixed_indented_overview_changelog_report = audit_current_changelog(
		"7.1.0-dev.0",
		(
			valid_changelog_preamble
			+ "## [未发布]\n\n"
			" \t**版本概述**：Hidden in mixed-indented code.\n\n"
			"### 🔄 机制更改 (Changed)\n\n"
			"- Real category body.\n"
		),
	)
	comment_only_category_changelog_report = audit_current_changelog(
		"7.1.0-dev.0",
		(
			valid_changelog_preamble
			+ "## [未发布]\n\n"
			"**版本概述**：Real overview.\n\n"
			"### 🔄 机制更改 (Changed)\n\n"
			"<!-- Hidden category body. -->\n"
		),
	)
	record_result(
		"changelog_structure_uses_visible_markdown_content",
		not fenced_overview_changelog_report["ok"]
		and any(
			"exactly one '**版本概述**" in issue
			for issue in fenced_overview_changelog_report["issues"]
		)
		and not indented_category_changelog_report["ok"]
		and any(
			"at least one standard change category" in issue
			for issue in indented_category_changelog_report["issues"]
		)
		and all(not report["ok"] for report in mixed_indented_category_reports)
		and all(
			any(
				"at least one standard change category" in issue
				for issue in report["issues"]
			)
			for report in mixed_indented_category_reports
		)
		and not mixed_indented_overview_changelog_report["ok"]
		and any(
			"exactly one '**版本概述**" in issue
			for issue in mixed_indented_overview_changelog_report["issues"]
		)
		and not comment_only_category_changelog_report["ok"]
		and any(
			"must not be empty" in issue
			for issue in comment_only_category_changelog_report["issues"]
		),
		"fenced code, indented code, and HTML comments must not satisfy the visible entry contract.",
	)
	raw_html_changelog_report = audit_current_changelog(
		"7.1.0-dev.0",
		(
			valid_changelog_preamble
			+ "## [未发布]\n"
			+ valid_changelog_body
			+ "\n<details><summary>hidden</summary></details>\n"
		),
	)
	comment_spliced_heading_report = audit_current_changelog(
		"7.1.0-dev.0",
		(
			valid_changelog_preamble
			+ "## [未发布]\n"
			+ valid_changelog_body
			+ "\n<!-- hidden -->## [7.0.0] - 2026-07-14\n"
		),
	)
	renamed_history_reports = [
		audit_current_changelog(
			"7.1.0-dev.0",
			source,
		)
		for source in (
			(
				valid_changelog_preamble
				+ "## 7.0.0\n\n"
				+ "Old history.\n\n"
				+ "## [未发布]\n"
				+ valid_changelog_body
			),
			(
				valid_changelog_preamble
				+ "## [未发布]\n"
				+ valid_changelog_body
				+ "\n## 7.0.0\n\n"
				+ "Old history.\n"
			),
		)
	]
	nested_structure_reports = [
		audit_current_changelog(
			"7.1.0-dev.0",
			source,
		)
		for source in (
			(
				valid_changelog_preamble
				+ "## [未发布]\n\n"
				+ "- **版本概述**：Nested overview.\n\n"
				+ "### 🔄 机制更改 (Changed)\n\n"
				+ "- Real body.\n"
			),
			(
				valid_changelog_preamble
				+ "## [未发布]\n\n"
				+ "**版本概述**：Top-level overview.\n\n"
				+ "  ### 🔄 机制更改 (Changed)\n\n"
				+ "- Nested category.\n"
			),
		)
	]
	nbsp_structure_reports = [
		audit_current_changelog(
			"7.1.0-dev.0",
			source,
		)
		for source in (
			valid_changelog_preamble
			+ "##\u00a0[未发布]\n"
			+ valid_changelog_body,
			(
				valid_changelog_preamble
				+ "## [未发布]\n\n"
				+ "**版本概述**：NBSP category.\n\n"
				+ "###\u00a0🔄 机制更改 (Changed)\n\n"
				+ "- Hidden category.\n"
			),
		)
	]
	empty_visible_content_reports = [
		audit_current_changelog(
			"7.1.0-dev.0",
			(
				valid_changelog_preamble
				+ "## [未发布]\n\n"
				+ "**版本概述**：Visible-content fixture.\n\n"
				+ "### 🔄 机制更改 (Changed)\n\n"
				+ body
				+ "\n"
			),
		)
		for body in ("***", "___", "----", "* * *", "&nbsp;")
	]
	render_empty_entry_reports = [
		audit_current_changelog(
			"7.1.0-dev.0",
			source,
		)
		for source in (
			(
				valid_changelog_preamble
				+ "## [未发布]\n\n"
				+ "**版本概述**：[](https://example.com)\n\n"
				+ "### 🔄 机制更改 (Changed)\n\n"
				+ "- Real category body.\n"
			),
			(
				valid_changelog_preamble
				+ "## [未发布]\n\n"
				+ "**版本概述**：[[]](https://example.com)\n\n"
				+ "### 🔄 机制更改 (Changed)\n\n"
				+ "[hidden]: https://example.com\n"
			),
		)
	]
	document_contract_reports = [
		audit_current_changelog(
			"7.1.0-dev.0",
			source,
		)
		for source in (
			(
				valid_changelog_preamble.replace("# 更新日志 (Changelog)\n\n", "")
				+ "## [未发布]\n"
				+ valid_changelog_body
			),
			(
				valid_changelog_preamble
				+ "## 📝 日志条目结构标准\n\nPublic authoring template.\n\n"
				+ "## [未发布]\n"
				+ valid_changelog_body
			),
			(
				valid_changelog_preamble
				+ "## 维护策略\n\nPublic maintenance policy.\n\n"
				+ "## [未发布]\n"
				+ valid_changelog_body
			),
			(
				valid_changelog_preamble
				+ "## [未发布]\n\n"
				+ "**版本概述**：Internal category fixture.\n\n"
				+ "### 📁 核心受影响文件 (Affected Files)\n\n"
				+ "- `tools/gf_maintenance.py`\n"
			),
			(
				valid_changelog_preamble
				+ "## [未发布]\n\n"
				+ "**版本概述**：Internal path fixture.\n\n"
				+ "### 🔄 机制更改 (Changed)\n\n"
				+ "- `addons/gf/kernel/core/gf.gd`\n"
			),
		)
	]
	comment_fence_and_hash_reports = [
		audit_current_changelog(
			"7.1.0-dev.0",
			source,
		)
		for source in (
			(
				valid_changelog_preamble
				+ "## [未发布]\n"
				+ valid_changelog_body
				+ "\n<!-- hidden -->```markdown\n"
				+ "## [7.0.0] - 2026-07-14\n"
				+ "```\n"
			),
			(
				valid_changelog_preamble
				+ "## [未发布]\n"
				+ valid_changelog_body
				+ "\n##<!-- hidden --># 🔄 机制更改 (Changed)\n"
			),
		)
	]
	setext_structure_reports = [
		audit_current_changelog(
			"7.1.0-dev.0",
			source,
		)
		for source in (
			(
				valid_changelog_preamble.replace(
					"# 更新日志 (Changelog)",
					"更新日志 (Changelog)\n====================",
				)
				+ "## [未发布]\n"
				+ valid_changelog_body
			),
			(
				valid_changelog_preamble
				+ "维护策略\n--------\n\n"
				+ "## [未发布]\n"
				+ valid_changelog_body
			),
			(
				valid_changelog_preamble
				+ "[未发布]\n--------\n"
				+ valid_changelog_body
			),
		)
	]
	container_heading_reports = [
		audit_current_changelog(
			"7.1.0-dev.0",
			valid_changelog_preamble
			+ "## [未发布]\n"
			+ valid_changelog_body
			+ container_suffix,
		)
		for container_suffix in (
			"\n- ### 🚀 新增特性 (Added)\n",
			"\n> ### 🚀 新增特性 (Added)\n",
			"\n> ## [7.0.0] - 2026-07-14\n",
			"\n> Old release\n> -----------\n",
		)
	]
	invisible_reference_report = audit_current_changelog(
		"7.1.0-dev.0",
		(
			valid_changelog_preamble
			+ "## [未发布]\n\n"
			"**版本概述**：[](https://example.invalid/hidden-overview)\n\n"
			"### 🔄 机制更改 (Changed)\n\n"
			"[hidden-body]: https://example.invalid/hidden-body\n"
		),
	)
	leading_visible_content_reports = [
		audit_current_changelog(
			"7.1.0-dev.0",
			prefix
			+ valid_changelog_preamble
			+ "## [未发布]\n"
			+ valid_changelog_body,
		)
		for prefix in (
			"Old release history.\n\n",
			"```text\nOld release history.\n```\n\n",
			"    Old release history.\n\n",
		)
	]
	record_result(
		"changelog_policy_rejects_ambiguous_or_hidden_document_structure",
		not raw_html_changelog_report["ok"]
		and any("raw HTML" in issue for issue in raw_html_changelog_report["issues"])
		and not comment_spliced_heading_report["ok"]
		and any(
			"mixes an HTML comment with visible content" in issue
			for issue in comment_spliced_heading_report["issues"]
		)
		and all(not report["ok"] for report in renamed_history_reports)
		and all(not report["ok"] for report in nested_structure_reports)
		and all(not report["ok"] for report in nbsp_structure_reports)
		and all(not report["ok"] for report in empty_visible_content_reports)
		and all(not report["ok"] for report in render_empty_entry_reports)
		and all(not report["ok"] for report in document_contract_reports)
		and any(
			"top-level headings" in issue
			for issue in document_contract_reports[1]["issues"]
		)
		and any(
			"Affected Files" in issue
			for issue in document_contract_reports[3]["issues"]
		)
		and any(
			"internal repository path" in issue
			for issue in document_contract_reports[4]["issues"]
		),
		"raw HTML, comment splicing, renamed history, container indentation, NBSP separators, render-empty links, decorative-only bodies, author-only headings, and path dumps must fail closed.",
	)
	record_result(
		"changelog_policy_rejects_comment_setext_and_container_heading_bypasses",
		all(not report["ok"] for report in comment_fence_and_hash_reports)
		and all(
			any(
				"mixes an HTML comment with visible content" in issue
				for issue in report["issues"]
			)
			for report in comment_fence_and_hash_reports
		)
		and all(not report["ok"] for report in setext_structure_reports)
		and all(not report["ok"] for report in container_heading_reports)
		and all(
			any(
				"heading inside a list or blockquote container" in issue
				for issue in report["issues"]
			)
			for report in container_heading_reports
		),
		"comment/fence or hash splicing, Setext headings, and list/blockquote headings must never create hidden changelog structure.",
	)
	record_result(
		"changelog_policy_requires_reader_visible_candidate_text",
		not invisible_reference_report["ok"]
		and any(
			"Markdown reference definition" in issue
			for issue in invisible_reference_report["issues"]
		)
		and any(
			"must use a top-level, non-empty" in issue
			for issue in invisible_reference_report["issues"]
		),
		"reference definitions and link destinations must not satisfy reader-visible release-note content.",
	)
	record_result(
		"changelog_policy_requires_title_as_first_visible_line",
		all(not report["ok"] for report in leading_visible_content_reports)
		and all(
			any(
				"first visible non-empty line" in issue
				for issue in report["issues"]
			)
			for report in leading_visible_content_reports
		),
		"plain prose, fenced code, and indented code must not precede the canonical changelog title.",
	)
	with tempfile.TemporaryDirectory(prefix="gf_changelog_release_notes_") as temp_dir:
		release_notes_path = Path(temp_dir) / "changelog.md"
		release_notes_path.write_text(
			(
				valid_changelog_preamble
				+ "## [7.0.0] - 2026-07-14\n"
				+ valid_changelog_body
				+ "\n```markdown\n"
				"## [6.0.0] - 2025-01-01\n"
				"```\n"
				"- Tail evidence.\n"
			),
			encoding="utf-8",
		)
		extracted_release_notes = gf_release_notes.extract_release_notes(
			release_notes_path,
			"7.0.0",
		)
		release_notes_path.write_text(
			(
				valid_changelog_preamble
				+ "## [7.0.0] - 2026-07-14\n"
				+ valid_changelog_body
				+ "\n```bad`info\n"
				"## [6.0.0] - 2025-01-01\n"
				+ valid_changelog_body
				+ "\n```\n"
			),
			encoding="utf-8",
		)
		invalid_info_release_notes_rejected = False
		try:
			gf_release_notes.extract_release_notes(
				release_notes_path,
				"7.0.0",
			)
		except SystemExit:
			invalid_info_release_notes_rejected = True
		release_notes_path.write_text(
			(
				valid_changelog_preamble
				+ "## [7.0.0] - 2026-07-14\n"
				+ valid_changelog_body
				+ "\n## [7.0.0] - 2026-07-15\n"
				+ valid_changelog_body
			),
			encoding="utf-8",
		)
		duplicate_release_notes_rejected = False
		try:
			gf_release_notes.extract_release_notes(release_notes_path, "7.0.0")
		except SystemExit:
			duplicate_release_notes_rejected = True
		invalid_release_contract_sources = (
			(
				valid_changelog_preamble
				+ "## [7.0.0] arbitrary suffix\n"
				+ valid_changelog_body
			),
			(
				valid_changelog_preamble
				+ "## [7.0.0] - 2026-07-14\n\n"
				+ "Plain text without the candidate entry contract.\n"
			),
			(
				valid_changelog_preamble
				+ "## [7.0.0] - 2026-07-14\n\n"
				+ "**版本概述**：Internal category fixture.\n\n"
				+ "### 📁 核心受影响文件 (Affected Files)\n\n"
				+ "- `tools/gf_maintenance.py`\n"
			),
			(
				valid_changelog_preamble
				+ "## [7.0.0] - 2026-07-14\n\n"
				+ "**版本概述**：Internal path fixture.\n\n"
				+ "### 🔄 机制更改 (Changed)\n\n"
				+ "- `addons/gf/kernel/core/gf.gd`\n"
			),
		)
		invalid_release_contract_results: list[bool] = []
		for source in invalid_release_contract_sources:
			release_notes_path.write_text(source, encoding="utf-8")
			rejected = False
			try:
				gf_release_notes.extract_release_notes(release_notes_path, "7.0.0")
			except SystemExit:
				rejected = True
			invalid_release_contract_results.append(rejected)
	record_result(
		"release_notes_share_markdown_aware_changelog_parser",
		"## [6.0.0] - 2025-01-01" in extracted_release_notes
		and "- Tail evidence." in extracted_release_notes
		and invalid_info_release_notes_rejected
		and duplicate_release_notes_rejected
		and all(invalid_release_contract_results),
		"release note extraction must ignore valid fenced headings, reject invalid fences, preserve the exact target body, and enforce the same complete document and candidate contract.",
	)
	record_result(
		"changelog_policy_rejects_ungoverned_prerelease_identities",
		not audit_current_changelog(
			"7.1.0-rc.1",
			valid_changelog_preamble + "## [未发布]\n" + valid_changelog_body,
		)["ok"]
		and not audit_current_changelog(
			"7.1.0-dev.0+ci",
			valid_changelog_preamble + "## [未发布]\n" + valid_changelog_body,
		)["ok"],
		"the source tree must use either stable SemVer or the governed x.y.z-dev.N identity without build metadata.",
	)

	project_extension_enabled_issues = audit_project_extension_settings_source(
		"[gf]\nextensions/enabled=Array[String]([\"gf.save\"])\nextensions/selection_mode=\"default\"",
		"project.godot",
	)
	record_result(
		"dependency_boundary_rejects_framework_project_default_enabled_extensions",
		issue_exists(project_extension_enabled_issues, "project_extensions_enabled_by_default"),
		"framework project defaults must not enable optional bundled extensions.",
	)

	project_extension_empty_issues = audit_project_extension_settings_source(
		"[gf]\nextensions/enabled=Array[String]([])\nextensions/selection_mode=\"default\"",
		"project.godot",
	)
	record_result(
		"dependency_boundary_accepts_empty_framework_project_extensions",
		len(project_extension_empty_issues) == 0,
		f"empty framework extension defaults should pass: {project_extension_empty_issues}",
	)

	project_extension_missing_selection_mode_issues = audit_project_extension_settings_source(
		"[gf]\nextensions/enabled=Array[String]([])",
		"project.godot",
	)
	record_result(
		"dependency_boundary_requires_framework_project_extension_selection_mode",
		issue_exists(project_extension_missing_selection_mode_issues, "missing_project_extension_selection_mode_setting"),
		"framework project defaults must explicitly preserve extension selection mode.",
	)

	return {
		"ok": len(failures) == 0,
		"root": str(ROOT),
		"test_count": len(tests),
		"failure_count": len(failures),
		"tests": tests,
		"failures": failures,
	}
