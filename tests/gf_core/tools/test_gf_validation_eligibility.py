#!/usr/bin/env python3
"""Focused tests for immutable static eligibility shadow observation."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
TOOLS_ROOT = ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
	sys.path.insert(0, str(TOOLS_ROOT))

import gf_validation_eligibility as eligibility
import gf_validation_static_worker as static_worker


WORKSPACE_FINGERPRINT = "a" * 64


def _write(path: Path, text: str) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_text(text, encoding="utf-8", newline="\n")


def _fixture_root(parent: Path, name: str = "repository") -> Path:
	root = parent / name
	for path in (
		"ASSET_LIBRARY.md",
		"ASSET_STORE.md",
		"README.md",
		"README.zh.md",
		"addons/gf/README.md",
		"addons/gf/extensions/README.md",
		"docs/wiki/Home.md",
		"docs/zh/guide.md",
	):
		_write(root / path, f"{path}\n")
	for path in (
		"tools/gf_maintenance.py",
		"tools/gf_validation_inputs.py",
		"tools/gf_workspace_snapshot.py",
		"tools/gf_validation_static_worker.py",
		"tools/helper.py",
	):
		_write(root / path, f"# {path}\nVALUE = 1\n")
	return root


def _run_git(root: Path, *arguments: str) -> None:
	completed = subprocess.run(
		["git", *arguments],
		cwd=root,
		stdin=subprocess.DEVNULL,
		stdout=subprocess.PIPE,
		stderr=subprocess.PIPE,
		check=False,
		text=True,
		encoding="utf-8",
	)
	if completed.returncode != 0:
		raise AssertionError(f"git fixture failed with exit code {completed.returncode}")


def _initialize_git_fixture(root: Path) -> None:
	_run_git(root, "init", "--quiet")
	_run_git(root, "add", "--all")


def _docs_result(file_count: int = 8, *, ok: bool = True) -> dict[str, object]:
	issues = [] if ok else [{"kind": "fixture"}]
	return {
		"ok": ok,
		"root": "ignored-materialized-root",
		"file_count": file_count,
		"issue_count": len(issues),
		"issues": issues,
	}


def _runtime_manifest(runtime_digest_seed: str = "runtime") -> dict[str, object]:
	file_digest = eligibility.hashlib.sha256(runtime_digest_seed.encode()).hexdigest()
	manifest: dict[str, object] = {
		"schema_version": 1,
		"identity": {
			"implementation": "cpython",
			"cache_tag": "cpython-test",
			"hexversion": 1,
			"version": [3, 14, 0, "final", 0],
			"unicode_version": "16.0.0",
		},
		"file_count": 1,
		"total_bytes": 4,
		"files": [{
			"module": "json",
			"origin_name": "json.py",
			"size_bytes": 4,
			"sha256": file_digest,
		}],
	}
	manifest["digest"] = eligibility.gf_validation_evidence.canonical_json_sha256(
		manifest,
		domain=b"gf-python-runtime-manifest-v1\0",
	)
	return manifest


def _worker_payload(result: dict[str, object], runtime_seed: str = "runtime") -> dict[str, object]:
	return {
		"schema_version": 1,
		"check_name": "public_docs_boundary",
		"result": result,
		"runtime_manifest": _runtime_manifest(runtime_seed),
	}


class EligibilitySchemaTests(unittest.TestCase):
	def test_failure_is_exact_unknown_ineligible_and_never_reuses(self) -> None:
		report = eligibility.make_eligibility_failure(
			["public_docs_boundary", "gut"],
			"worker_failed",
		)
		self.assertEqual(frozenset(report), eligibility.ELIGIBILITY_REPORT_FIELDS)
		self.assertFalse(report["report_ok"])
		self.assertFalse(report["authoritative"])
		self.assertFalse(report["scheduling_effect"])
		self.assertFalse(report["reuse_permitted"])
		self.assertEqual(report["decision"], "execute")
		self.assertEqual(report["candidate_count"], 1)
		self.assertEqual(report["structurally_eligible_count"], 0)
		self.assertEqual(report["executed_count"], 0)
		for field in (
			"skip_count", "cache_read_count", "cache_write_count", "persist_count", "reused_count",
		):
			self.assertEqual(report[field], 0)
		projection = report["projections"][0]
		self.assertEqual(projection["projection"], "ineligible")
		self.assertEqual(projection["policy"]["reuse_scope"], "never")
		self.assertEqual(projection["policy"]["minimum_evidence_authority"], "none")
		json.dumps(report, allow_nan=False)

	def test_validator_rejects_any_scheduling_cache_or_count_claim(self) -> None:
		baseline = eligibility.make_eligibility_failure(
			["public_docs_boundary"], "worker_failed"
		)
		for field, value in (
			("authoritative", True),
			("scheduling_effect", True),
			("reuse_permitted", True),
			("decision", "skip"),
			("cache_write_count", 1),
			("persist_count", 1),
			("executed_count", 1),
			("collection_duration_seconds", float("nan")),
		):
			with self.subTest(field=field):
				mutated = {**baseline, field: value}
				with self.assertRaises(eligibility.ValidationEligibilityError):
					eligibility.validate_eligibility_report(mutated)

	def test_validator_rejects_hostile_nested_eligible_claims(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			projection = EligibilityObservationTests()._observe(
				_fixture_root(Path(temporary_directory)),
				toolchain={
					"python_executable_content": "1" * 64,
					"python_identity": "2" * 64,
					"python_runtime_manifest": "3" * 64,
				},
				environment={"controlled_environment": "4" * 64},
			)
		baseline = eligibility._make_report(
			["public_docs_boundary"],
			[projection],
			[],
			report_ok=True,
			collection_duration_seconds=0.0,
			workspace_fingerprint=WORKSPACE_FINGERPRINT,
		)
		self.assertTrue(eligibility.validate_eligibility_report(baseline)["report_ok"])
		mutations = []
		for field, value in (
			("reason_code", "worker_failed"),
			("policy", eligibility.gf_validation_contracts.CheckValidationPolicy.fail_closed(
				"public_docs_boundary"
			).to_dict()),
			("action_key_material", {"decision": "skip", "cache_write": True}),
			("structured_result_digest", "not-a-digest"),
			("evidence", [{"reused": True}, {"reused": True}]),
		):
			mutations.append({
				**baseline,
				"projections": [{**projection, field: value}],
			})
		mutations.append({
			**baseline,
			"projections": [{**projection, "execution_count": 2.0}],
		})
		hostile_evidence = [dict(item) for item in projection["evidence"]]
		hostile_evidence[0]["schema_version"] = True
		mutations.append({
			**baseline,
			"projections": [{**projection, "evidence": hostile_evidence}],
		})
		hostile_action_key_material = dict(projection["action_key_material"])
		hostile_action_key_material["schema_version"] = True
		mutations.append({
			**baseline,
			"projections": [{
				**projection,
				"action_key_material": hostile_action_key_material,
			}],
		})
		for payload in mutations:
			with self.subTest(payload=payload["projections"][0]):
				with self.assertRaises(eligibility.ValidationEligibilityError):
					eligibility.validate_eligibility_report(payload)

	def test_validator_binds_exact_requested_candidate_set(self) -> None:
		baseline = eligibility.make_eligibility_failure(
			["public_docs_boundary", "gut"],
			"worker_failed",
		)
		for mutation in (
			{**baseline, "requested_checks": ["public_api_boundary", "gut"]},
			{**baseline, "requested_check_count": 0},
			{
				**baseline,
				"projections": [*baseline["projections"], *baseline["projections"]],
				"candidate_count": 2,
				"ineligible_count": 2,
			},
		):
			with self.subTest(mutation=mutation):
				with self.assertRaises(eligibility.ValidationEligibilityError):
					eligibility.validate_eligibility_report(mutation)

	def test_result_schema_is_exact_and_relational(self) -> None:
		valid = _docs_result()
		self.assertEqual(eligibility._normalized_result(valid)["file_count"], 8)
		mutations = [
			{**valid, "extra": True},
			{**valid, "issue_count": 1},
			{**valid, "ok": False},
			{**valid, "file_count": True},
		]
		for payload in mutations:
			with self.subTest(payload=payload):
				with self.assertRaises(eligibility.ValidationEligibilityWorkerError):
					eligibility._normalized_result(payload)
		package = {
			"ok": False,
			"root": "root",
			"source_file_count": 2,
			"issue_count": 1,
			"issue_kind_counts": {"fixture": 1},
			"scan_roots": [
				"addons/gf/plugin.gd",
				"addons/gf/kernel/package",
				"addons/gf/kernel/editor/package",
			],
			"issues": [{"kind": "fixture"}],
		}
		self.assertFalse(eligibility._normalized_result(package)["ok"])
		with self.assertRaises(eligibility.ValidationEligibilityWorkerError):
			eligibility._normalized_result({**package, "issue_kind_counts": {}})


class EligibilityObservationTests(unittest.TestCase):
	def test_complete_input_capture_uses_the_eligibility_clock(self) -> None:
		base = eligibility.gf_validation_inputs.FrozenActionInputs(
			check_name="public_docs_boundary",
			input_spec_digest="1" * 64,
			source_manifest_digest="2" * 64,
			implementation_manifest_digest="3" * 64,
			discovery_digest="4" * 64,
			artifact_manifest_digest="5" * 64,
			capture_complete=True,
			source_entry_count=1,
			implementation_entry_count=1,
			artifact_count=0,
			total_bytes=2,
		)
		spec = eligibility.gf_validation_inputs.DEFAULT_AFFECTED_INPUT_SPEC_BY_NAME[
			"public_docs_boundary"
		]
		with mock.patch.object(
			eligibility.gf_validation_inputs,
			"freeze_action_inputs",
			return_value=base,
		) as freeze, mock.patch.object(
			eligibility,
			"_tools_manifest_digest",
			return_value="6" * 64,
		):
			captured = eligibility._freeze_complete_inputs(  # noqa: SLF001
				ROOT,
				spec,
				123.0,
			)

		self.assertTrue(captured.capture_complete)
		self.assertEqual(captured.implementation_manifest_digest, "6" * 64)
		freeze.assert_called_once_with(
			ROOT,
			spec,
			deadline_seconds=123.0,
			monotonic=time.perf_counter,
		)

	def _observe(
		self,
		root: Path,
		*,
		results: list[dict[str, object]] | None = None,
		toolchain: dict[str, str] | None = None,
		post_toolchain: dict[str, str] | None = None,
		environment: dict[str, str] | None = None,
		runtime_seeds: tuple[str, str] = ("runtime", "runtime"),
	) -> dict[str, object]:
		worker_results = results or [_docs_result(), _docs_result()]
		toolchain_before = toolchain or {"python": "1" * 64}
		toolchain_after = post_toolchain or toolchain_before
		with mock.patch.object(
			eligibility.gf_parallel_validation,
			"materialize_workspace",
			return_value=root,
		), mock.patch.object(
			eligibility,
			"_run_worker",
			side_effect=[
				_worker_payload(result, runtime_seeds[index])
				for index, result in enumerate(worker_results)
			],
		), mock.patch.object(
			eligibility,
			"_toolchain_digests",
			side_effect=[toolchain_before, toolchain_after],
		), mock.patch.object(
			eligibility,
			"_environment_digests",
			return_value=environment or {"environment": "2" * 64},
		):
			return eligibility._observe_candidate(
				mock.Mock(workspace_fingerprint=WORKSPACE_FINGERPRINT),
				"public_docs_boundary",
				deadline_seconds=time.perf_counter() + 30.0,
			)

	def test_double_run_builds_self_asserted_candidate_but_policy_never_reuses(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			projection = self._observe(_fixture_root(Path(temporary_directory)))
		self.assertTrue(projection["structurally_eligible"])
		self.assertEqual(projection["projection"], "structurally_eligible")
		self.assertEqual(projection["execution_count"], 2)
		self.assertEqual(projection["policy"]["reuse_scope"], "never")
		self.assertEqual(projection["policy"]["minimum_evidence_authority"], "none")
		self.assertEqual(
			{item["evidence_authority"] for item in projection["evidence"]},
			{"self_asserted"},
		)
		self.assertTrue(all(item["structurally_reusable_candidate"] for item in projection["evidence"]))

	def test_root_path_does_not_change_action_key(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parent = Path(temporary_directory)
			first = self._observe(_fixture_root(parent, "short"))
			second = self._observe(_fixture_root(parent, "different-long-root"))
		self.assertEqual(first["action_key"], second["action_key"])

	def test_source_implementation_toolchain_and_environment_change_action_key(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _fixture_root(Path(temporary_directory))
			baseline = self._observe(root)
			_write(root / "README.md", "changed source\n")
			source = self._observe(root)
			_write(root / "tools/helper.py", "VALUE = 2\n")
			implementation = self._observe(root)
			toolchain = self._observe(root, toolchain={"python": "3" * 64})
			environment = self._observe(root, environment={"environment": "4" * 64})
			runtime = self._observe(root, runtime_seeds=("new-runtime", "new-runtime"))
		self.assertNotEqual(baseline["action_key"], source["action_key"])
		self.assertNotEqual(source["action_key"], implementation["action_key"])
		self.assertNotEqual(implementation["action_key"], toolchain["action_key"])
		self.assertNotEqual(implementation["action_key"], environment["action_key"])
		self.assertNotEqual(implementation["action_key"], runtime["action_key"])

	def test_result_change_changes_result_digest_but_not_action_key(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _fixture_root(Path(temporary_directory))
			first = self._observe(root, results=[_docs_result(8), _docs_result(8)])
			second = self._observe(root, results=[_docs_result(9), _docs_result(9)])
		self.assertEqual(first["action_key"], second["action_key"])
		self.assertNotEqual(first["structured_result_digest"], second["structured_result_digest"])

	def test_postrun_input_drift_fails_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _fixture_root(Path(temporary_directory))
			calls = 0

			def worker(*_args: object, **_kwargs: object) -> dict[str, object]:
				nonlocal calls
				calls += 1
				if calls == 2:
					_write(root / "README.md", "drifted after run\n")
				return _worker_payload(_docs_result())

			with mock.patch.object(
				eligibility.gf_parallel_validation,
				"materialize_workspace",
				return_value=root,
			), mock.patch.object(eligibility, "_run_worker", side_effect=worker), mock.patch.object(
				eligibility, "_toolchain_digests", return_value={"python": "1" * 64}
			):
				with self.assertRaises(eligibility.ValidationEligibilityDriftError):
					eligibility._observe_candidate(
						mock.Mock(workspace_fingerprint=WORKSPACE_FINGERPRINT),
						"public_docs_boundary",
						deadline_seconds=time.perf_counter() + 30.0,
					)

	def test_postrun_toolchain_drift_fails_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _fixture_root(Path(temporary_directory))
			with self.assertRaises(eligibility.ValidationEligibilityDriftError):
				self._observe(
					root,
					toolchain={"python_executable_content": "1" * 64},
					post_toolchain={"python_executable_content": "2" * 64},
				)

	def test_mismatched_double_run_is_ineligible(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _fixture_root(Path(temporary_directory))
			with self.assertRaises(eligibility.ValidationEligibilityWorkerError):
				self._observe(root, results=[_docs_result(8), _docs_result(9)])
			with self.assertRaises(eligibility.ValidationEligibilityResultMismatchError):
				self._observe(root, runtime_seeds=("runtime-a", "runtime-b"))

	def test_deadline_fails_before_capture_and_never_runs_worker(self) -> None:
		with mock.patch.object(
			eligibility.gf_parallel_validation, "capture_workspace"
		) as capture, mock.patch.object(eligibility, "_run_worker") as worker:
			report = eligibility.run_eligibility_shadow(
				ROOT,
				["public_docs_boundary"],
				deadline_seconds=time.perf_counter() - 1.0,
			)
		self.assertFalse(report["report_ok"])
		self.assertEqual(report["errors"], ["deadline_exceeded"])
		capture.assert_not_called()
		worker.assert_not_called()

	def test_cleanup_debt_is_ineligible_and_no_cache_or_ledger_is_written(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parent = Path(temporary_directory)
			root = _fixture_root(parent)
			owned_root = parent / "owned"
			owned_root.mkdir()
			before = sorted(path.relative_to(root).as_posix() for path in root.rglob("*"))
			with mock.patch.object(
				eligibility.gf_parallel_validation,
				"capture_workspace",
				return_value=mock.Mock(workspace_fingerprint=WORKSPACE_FINGERPRINT),
			), mock.patch.object(
				eligibility.gf_parallel_validation, "materialize_workspace", return_value=root
			), mock.patch.object(
				eligibility.tempfile,
				"mkdtemp",
				return_value=str(owned_root),
			), mock.patch.object(
				eligibility, "_run_worker",
				return_value=_worker_payload(_docs_result()),
			), mock.patch.object(eligibility.shutil, "rmtree", side_effect=OSError("cleanup debt")):
				report = eligibility.run_eligibility_shadow(ROOT, ["public_docs_boundary"])
			after = sorted(path.relative_to(root).as_posix() for path in root.rglob("*"))
		self.assertEqual(before, after)
		self.assertEqual(report["errors"], ["cleanup_failed"])
		self.assertEqual(report["cache_write_count"], 0)
		self.assertEqual(report["persist_count"], 0)

	def test_replaced_temporary_root_is_never_removed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parent = Path(temporary_directory)
			root = _fixture_root(parent, "materialized")
			owned_root = parent / "owned"
			owned_root.mkdir()
			with mock.patch.object(
				eligibility.tempfile,
				"mkdtemp",
				return_value=str(owned_root),
			), mock.patch.object(
				eligibility,
				"_owned_directory_identity",
				side_effect=[(1, 2, 3), (1, 9, 3)],
			), mock.patch.object(eligibility.shutil, "rmtree") as remove_tree:
				with self.assertRaises(eligibility.ValidationEligibilityCleanupError):
					self._observe(root)
			remove_tree.assert_not_called()
			self.assertTrue(owned_root.is_dir())

	def test_git_standard_ignored_candidate_inputs_fail_closed_without_path_leak(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parent = Path(temporary_directory)
			fixtures = (
				("repository", "docs/zh/repository-hidden.md"),
				("info", "docs/wiki/info-hidden.md"),
				("global", "docs/zh/global-hidden.md"),
			)
			for source, hidden_path in fixtures:
				with self.subTest(source=source):
					root = _fixture_root(parent, f"ignored-{source}")
					if source == "repository":
						_write(root / ".gitignore", f"/{hidden_path}\n")
					_initialize_git_fixture(root)
					global_config = parent / f"{source}.gitconfig"
					if source == "info":
						_write(root / ".git/info/exclude", f"/{hidden_path}\n")
					elif source == "global":
						global_excludes = parent / "global-excludes"
						_write(global_excludes, f"/{hidden_path}\n")
						_write(
							global_config,
							"[core]\n"
							f"\texcludesFile = {global_excludes.as_posix()}\n",
						)
					_write(root / hidden_path, "ignored candidate input\n")
					environment = (
						{"GIT_CONFIG_GLOBAL": str(global_config)}
						if source == "global"
						else {}
					)
					with mock.patch.dict(eligibility.os.environ, environment, clear=False):
						for drift, expected_type, error_code in (
							(False, eligibility.ValidationEligibilityCaptureError, "capture_failed"),
							(True, eligibility.ValidationEligibilityDriftError, "input_drift"),
						):
							with self.subTest(source=source, drift=drift):
								with self.assertRaises(expected_type) as raised:
									eligibility._assert_no_ignored_candidate_inputs(
										root,
										("public_docs_boundary",),
										time.perf_counter() + 10.0,
										drift=drift,
									)
								self.assertEqual(
									eligibility.eligibility_error_code(raised.exception),
									error_code,
								)
								self.assertNotIn(hidden_path, str(raised.exception))

	def test_ignored_files_outside_source_rules_do_not_block_capture(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _fixture_root(Path(temporary_directory))
			_write(root / ".gitignore", "/build/\n**/__pycache__/\n/tools/hidden.txt\n")
			_initialize_git_fixture(root)
			_write(root / "build/cache.tmp", "ignored non-input\n")
			_write(root / "addons/gf/tools/ai/__pycache__/worker.pyc", "ignored bytecode\n")
			_write(root / "tools/__pycache__/worker.pyc", "ignored bytecode\n")
			_write(root / "tools/hidden.txt", "ignored non-Python tool input\n")
			eligibility._assert_no_ignored_candidate_inputs(
				root,
				("public_docs_boundary", "public_api_boundary"),
				time.perf_counter() + 10.0,
				drift=False,
			)

	def test_ignored_python_tools_fail_closed_before_and_after_observation(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = _fixture_root(Path(temporary_directory))
			hidden_path = "tools/argparse.py"
			_write(root / ".gitignore", f"/{hidden_path}\n")
			_initialize_git_fixture(root)
			_write(root / hidden_path, "raise RuntimeError('shadowed stdlib')\n")

			for drift, expected_type, error_code in (
				(False, eligibility.ValidationEligibilityCaptureError, "capture_failed"),
				(True, eligibility.ValidationEligibilityDriftError, "input_drift"),
			):
				with self.subTest(drift=drift):
					with self.assertRaises(expected_type) as raised:
						eligibility._assert_no_ignored_candidate_inputs(
							root,
							("public_docs_boundary",),
							time.perf_counter() + 10.0,
							drift=drift,
						)
					self.assertEqual(
						eligibility.eligibility_error_code(raised.exception),
						error_code,
					)
					self.assertNotIn(hidden_path, str(raised.exception))

	def test_ignored_git_replacement_character_fails_closed(self) -> None:
		result = SimpleNamespace(
			return_code=0,
			stdout="\ufffd/not-a-candidate.bin\0",
			stderr="",
			timed_out=False,
			cancelled=False,
			stdout_truncated=False,
			stderr_truncated=False,
			notes=(),
		)
		with mock.patch.object(
			eligibility.gf_process_supervisor,
			"run_supervised_process",
			return_value=result,
		):
			with self.assertRaises(eligibility.ValidationEligibilityCaptureError):
				eligibility._assert_no_ignored_candidate_inputs(
					ROOT,
					("public_docs_boundary",),
					time.perf_counter() + 10.0,
					drift=False,
				)

	def test_owned_temporary_identity_rejects_non_directory_link_and_reparse(self) -> None:
		metadata_values = (
			SimpleNamespace(
				st_mode=eligibility.stat.S_IFREG | 0o600,
				st_dev=1,
				st_ino=2,
				st_file_attributes=0,
			),
			SimpleNamespace(
				st_mode=eligibility.stat.S_IFLNK | 0o700,
				st_dev=1,
				st_ino=2,
				st_file_attributes=0,
			),
			SimpleNamespace(
				st_mode=eligibility.stat.S_IFDIR | 0o700,
				st_dev=1,
				st_ino=2,
				st_file_attributes=eligibility.FILE_ATTRIBUTE_REPARSE_POINT,
			),
		)
		for metadata in metadata_values:
			with self.subTest(mode=metadata.st_mode, attributes=metadata.st_file_attributes):
				path = SimpleNamespace(
					is_absolute=lambda: True,
					lstat=lambda: metadata,
				)
				with self.assertRaises(eligibility.ValidationEligibilityCleanupError):
					eligibility._owned_directory_identity(path)

	def test_worker_payload_rejects_mismatch_and_malformed_json(self) -> None:
		with self.assertRaises(eligibility.ValidationEligibilityWorkerError):
			eligibility._validate_worker_payload([], "public_docs_boundary")
		with self.assertRaises(eligibility.ValidationEligibilityWorkerError):
			eligibility._validate_worker_payload(
				{"schema_version": 1, "check_name": "public_api_boundary", "result": _docs_result()},
				"public_docs_boundary",
			)
		with self.assertRaises(eligibility.ValidationEligibilityWorkerError):
			eligibility._validate_worker_payload(
				{**_worker_payload(_docs_result()), "schema_version": True},
				"public_docs_boundary",
			)
		with self.assertRaises(eligibility.ValidationEligibilityWorkerError):
			eligibility._validate_worker_payload(
				_worker_payload(_docs_result()),
				"public_docs_boundary",
				expected_root=Path("sealed-root"),
			)
		with self.assertRaises(eligibility.ValidationEligibilityWorkerError):
			eligibility._validate_worker_payload(
				_worker_payload({
					"ok": True,
					"root": "root",
					"source_file_count": 0,
					"issue_count": 0,
					"issue_kind_counts": {},
					"scan_roots": [],
					"issues": [],
				}),
				"public_docs_boundary",
			)

	def test_runtime_manifest_rejects_budget_order_and_basename_drift(self) -> None:
		baseline = _runtime_manifest()
		mutations = [
			{**baseline, "total_bytes": eligibility.MAX_RUNTIME_TOTAL_BYTES + 1},
			{
				**baseline,
				"files": [{**baseline["files"][0], "size_bytes": eligibility.MAX_RUNTIME_FILE_BYTES + 1}],
				"total_bytes": eligibility.MAX_RUNTIME_FILE_BYTES + 1,
			},
			{
				**baseline,
				"files": [{**baseline["files"][0], "origin_name": "../json.py"}],
			},
		]
		for payload in mutations:
			material = dict(payload)
			material.pop("digest", None)
			payload["digest"] = eligibility.gf_validation_evidence.canonical_json_sha256(
				material,
				domain=b"gf-python-runtime-manifest-v1\0",
			)
			with self.subTest(payload=payload):
				with self.assertRaises(eligibility.ValidationEligibilityWorkerError):
					eligibility._validate_runtime_manifest(payload)

	def test_worker_json_rejects_duplicate_nonfinite_stderr_and_cleanup_notes(self) -> None:
		base = dict(
			return_code=0,
			stdout="{}",
			stderr="",
			timed_out=False,
			cancelled=False,
			stdout_truncated=False,
			stderr_truncated=False,
			notes=(),
		)
		for stdout in ('{"x":1,"x":2}', '{"x":NaN}'):
			with self.subTest(stdout=stdout), mock.patch.object(
				eligibility.gf_process_supervisor,
				"run_supervised_process",
				return_value=SimpleNamespace(**{**base, "stdout": stdout}),
			):
				with self.assertRaises(eligibility.ValidationEligibilityInvalidWorkerError):
					eligibility._run_worker(ROOT, "public_docs_boundary", None)
		for mutation in ({"stderr": "unexpected"}, {"notes": ("cleanup debt",)}):
			with self.subTest(mutation=mutation), mock.patch.object(
				eligibility.gf_process_supervisor,
				"run_supervised_process",
				return_value=SimpleNamespace(**{**base, **mutation}),
			):
				with self.assertRaises(eligibility.ValidationEligibilityWorkerError):
					eligibility._run_worker(ROOT, "public_docs_boundary", None)

	def test_expected_workspace_fingerprint_mismatch_fails_before_materialization(self) -> None:
		captured = mock.Mock(workspace_fingerprint="b" * 64)
		with mock.patch.object(
			eligibility.gf_parallel_validation,
			"capture_workspace",
			return_value=captured,
		), mock.patch.object(
			eligibility.gf_parallel_validation,
			"materialize_workspace",
		) as materialize:
			report = eligibility.run_eligibility_shadow(
				ROOT,
				["public_docs_boundary"],
				expected_workspace_fingerprint="a" * 64,
			)
		self.assertEqual(report["errors"], ["input_drift"])
		self.assertEqual(report["workspace_fingerprint"], "a" * 64)
		materialize.assert_not_called()

	def test_real_worker_supports_safe_path_no_site_no_bytecode_and_utf8(self) -> None:
		payload = eligibility._run_worker(
			ROOT,
			"public_docs_boundary",
			time.perf_counter() + 30.0,
		)
		self.assertEqual(payload["check_name"], "public_docs_boundary")
		self.assertTrue(payload["result"]["ok"])

	def test_worker_command_uses_declared_environment_instead_of_isolated_mode(self) -> None:
		captured: dict[str, object] = {}

		def run(command: list[str], **kwargs: object) -> SimpleNamespace:
			captured["command"] = command
			captured["environment"] = kwargs["environment"]
			return SimpleNamespace(
				return_code=0,
				stdout=json.dumps(_worker_payload({**_docs_result(), "root": str(ROOT)})),
				stderr="",
				timed_out=False,
				cancelled=False,
				stdout_truncated=False,
				stderr_truncated=False,
				notes=(),
			)

		with mock.patch.object(
			eligibility.gf_process_supervisor,
			"run_supervised_process",
			side_effect=run,
		):
			eligibility._run_worker(ROOT, "public_docs_boundary", None)
		command = captured["command"]
		self.assertNotIn("-I", command)
		self.assertIn("-P", command)
		self.assertIn("-S", command)
		self.assertIn("-B", command)
		self.assertEqual(captured["environment"]["PYTHONHASHSEED"], "0")
		self.assertEqual(captured["environment"]["PYTHONUTF8"], "1")

	def test_real_python_executable_identity_is_stable_across_path_and_handle(self) -> None:
		digests = eligibility._toolchain_digests(
			ROOT,
			time.perf_counter() + 30.0,
		)
		self.assertEqual(
			set(digests),
			{"python_executable_content", "python_identity"},
		)
		self.assertTrue(all(len(value) == 64 for value in digests.values()))

	def test_runtime_manifest_binds_existing_module_cached_bytecode(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			source = root / "loaded_module.py"
			cached = root / "__pycache__/loaded_module.pyc"
			_write(source, "VALUE = 1\n")
			_write(cached, "cached-one\n")
			module_name = "gf_cached_runtime_fixture"
			module = SimpleNamespace(__file__=str(source), __cached__=str(cached))
			with mock.patch.dict(sys.modules, {module_name: module}):
				first = static_worker._runtime_manifest(
					ROOT,
					eligibility.gf_validation_evidence,
				)
				_write(cached, "cached-two\n")
				second = static_worker._runtime_manifest(
					ROOT,
					eligibility.gf_validation_evidence,
				)
			first_cached = next(
				record for record in first["files"]
				if record["module"] == f"{module_name}:cached"
			)
			second_cached = next(
				record for record in second["files"]
				if record["module"] == f"{module_name}:cached"
			)
			self.assertNotEqual(first_cached["sha256"], second_cached["sha256"])
			self.assertNotEqual(first["digest"], second["digest"])


if __name__ == "__main__":
	unittest.main()
