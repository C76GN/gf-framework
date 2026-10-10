#!/usr/bin/env python3
"""Bounded, isolated maintainer benchmark; never changes the public reactive API."""

from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import math
import os
import shutil
import stat
import statistics
import sys
import tempfile
import time
from pathlib import Path
from typing import Any

from gf_process_supervisor import (
	SupervisedProcessStartError,
	add_exception_note,
	exception_has_cleanup_debt,
	run_supervised_process,
	safe_exception_detail,
)


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tests/gf_core/benchmarks/reactive"
KERNEL_FILES = (
	"gf_bindable_property.gd", "gf_computed_property.gd", "gf_reactive_effect.gd",
	"gf_variant_access.gd", "gf_instance_guard.gd", "gf_subscription_token.gd",
	"gf_lifetime_subscription.gd",
)
MODES = ("eager", "static_pull", "branch_pull")
WORKLOADS = ("sparse_expensive", "cheap_every_frame", "branch_view")
REPORT_KIND = "gf_reactive_benchmark"


class _ProcessCPU:
	"""Exact direct-process accounting on Windows; no synthetic POSIX substitute."""

	def __init__(self) -> None:
		self.handle: Any = None
		self.api: Any = None
		self.unavailable_reason = ""
		if os.name != "nt":
			self.unavailable_reason = "Direct-process CPU accounting is unavailable on this platform; monotonic elapsed is reported separately."
			return
		self.api = ctypes.WinDLL("kernel32", use_last_error=True)
		self.api.OpenProcess.argtypes = [ctypes.c_uint32, ctypes.c_int, ctypes.c_uint32]
		self.api.OpenProcess.restype = ctypes.c_void_p
		self.api.GetProcessTimes.argtypes = [ctypes.c_void_p, *[ctypes.POINTER(ctypes.c_uint64)] * 4]
		self.api.GetProcessTimes.restype = ctypes.c_int
		self.api.CloseHandle.argtypes = [ctypes.c_void_p]
		self.api.CloseHandle.restype = ctypes.c_int

	def start(self, pid: int) -> None:
		if self.api is None:
			return
		self.handle = self.api.OpenProcess(0x1000, False, pid)
		if not self.handle:
			self.unavailable_reason = f"OpenProcess CPU accounting unavailable (OS error {ctypes.get_last_error()})."

	def finish(self) -> dict[str, Any]:
		seconds: float | None = None
		if self.handle:
			creation, exit_time, kernel, user = (ctypes.c_uint64() for _ in range(4))
			try:
				if self.api.GetProcessTimes(self.handle, ctypes.byref(creation), ctypes.byref(exit_time), ctypes.byref(kernel), ctypes.byref(user)):
					seconds = (kernel.value + user.value) / 10_000_000
				else:
					self.unavailable_reason = f"GetProcessTimes unavailable (OS error {ctypes.get_last_error()})."
			finally:
				self.api.CloseHandle(self.handle)
				self.handle = None
		return {
			"available": seconds is not None, "seconds": seconds,
			"method": "Windows GetProcessTimes kernel+user; includes startup/shutdown" if seconds is not None else "unavailable",
			"unavailable_reason": self.unavailable_reason,
		}


def _sha256(path: Path) -> str:
	return hashlib.sha256(path.read_bytes()).hexdigest()


def _is_linked(path: Path) -> bool:
	metadata = path.lstat()
	return stat.S_ISLNK(metadata.st_mode) or bool(getattr(metadata, "st_file_attributes", 0) & 0x400)


def _validate_output(path: Path) -> Path:
	output = Path(os.path.abspath(path))
	if not output.is_relative_to(ROOT) or output.suffix != ".json":
		raise ValueError("Output must be a .json artifact inside this repository.")
	for ancestor in (*reversed(output.parents), output):
		if ancestor.exists() or ancestor.is_symlink():
			if _is_linked(ancestor):
				raise ValueError("Output and its parents cannot be linked or reparsed.")
	if output.exists():
		if not output.is_file() or output.stat().st_size > 1024 * 1024:
			raise ValueError("Existing output is not a bounded regular benchmark report.")
		old = json.loads(output.read_text(encoding="utf-8"))
		if not isinstance(old, dict) or old.get("kind") != REPORT_KIND or type(old.get("schema_version")) is not int or old.get("schema_version") != 1:
			raise ValueError("Refusing to overwrite a different artifact.")
	return output


def _cleanup_allowed(stage: Path, parent: Path, receipt: bytes, identity: tuple[int, int]) -> bool:
	try:
		metadata = stage.lstat()
		owner = stage / "owner.receipt"
		if (
			stage.parent != parent or _is_linked(stage) or stage.resolve(strict=True) != stage
			or (metadata.st_dev, metadata.st_ino) != identity or not stat.S_ISDIR(metadata.st_mode)
			or _is_linked(owner) or not owner.is_file() or owner.stat().st_size != len(receipt)
		):
			return False
		with owner.open("rb") as stream:
			return stream.read(len(receipt) + 1) == receipt
	except (OSError, RuntimeError):
		return False


def _write_report(path: Path, report: dict[str, Any]) -> None:
	path = _validate_output(path)
	path.parent.mkdir(parents=True, exist_ok=True)
	payload = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False).encode("utf-8")
	pending: Path | None = None
	pending_identity: tuple[int, int] | None = None
	primary_error: BaseException | None = None
	try:
		with tempfile.NamedTemporaryFile(dir=path.parent, suffix=".pending", delete=False) as stream:
			pending = Path(stream.name)
			metadata = os.fstat(stream.fileno())
			pending_identity = (metadata.st_dev, metadata.st_ino)
			stream.write(payload)
		pending.replace(path)
	except BaseException as error:
		primary_error = error
		raise
	finally:
		if pending is not None:
			try:
				try:
					metadata = pending.lstat()
				except FileNotFoundError:
					pass
				else:
					if (stat.S_ISREG(metadata.st_mode)
						and not (getattr(metadata, "st_file_attributes", 0) & 0x400)
						and (metadata.st_dev, metadata.st_ino) == pending_identity):
						pending.unlink()
			except BaseException as cleanup_error:
				if primary_error is None:
					raise
				add_exception_note(primary_error, f"Report temporary-file cleanup failed: {safe_exception_detail(cleanup_error)}")


def _summarize(runs: list[dict[str, Any]]) -> dict[str, Any]:
	result = {}
	for workload in WORKLOADS:
		selected = [run for run in runs if run["workload"] == workload]
		checksums = {sample["checksum"] for run in selected for sample in run["samples"]}
		if len(checksums) != 1:
			raise ValueError(f"Results are not equivalent for {workload}: {checksums}")
		modes = []
		for mode in MODES:
			mode_runs = [run for run in selected if run["mode"] == mode]
			samples = [sample for run in mode_runs for sample in run["samples"]]
			cpu_values = [run["process_cpu"]["seconds"] for run in mode_runs if run["process_cpu"]["available"]]
			modes.append({
				"mode": mode,
				"process_cpu_seconds_median": statistics.median(cpu_values) if len(cpu_values) == len(mode_runs) else None,
				**{key + "_median": statistics.median(sample[key] for sample in samples) for key in (
					"active_usec", "frame_p95_usec", "read_p95_usec", "computes", "invalidations",
					"rebinds", "subscription_peak", "remaining_subscriptions",
				)},
			})
		result[workload] = modes
	return result


def run_benchmark(args: argparse.Namespace) -> dict[str, Any]:
	output = _validate_output(args.output)
	godot = args.godot.resolve(strict=True)
	if not godot.is_file():
		raise ValueError("Godot must be an explicit executable file.")
	temp_parent = args.temp_parent.resolve(strict=True)
	if not temp_parent.is_dir():
		raise ValueError("Temporary parent must be an existing directory.")
	owner_bytes = os.urandom(32)
	stage_identity: tuple[int, int] | None = None
	manifest = []
	report: dict[str, Any] = {
		"kind": REPORT_KIND, "schema_version": 1, "valid": False,
		"kernel_manifest": manifest, "runs": [],
		"correctness_only": args.correctness_only, "summary": {},
		"p95_metric": "Godot monotonic active elapsed usec per simulated frame, not per-frame CPU time",
		"schedule": "24 views; 120-frame warmup; 9 samples of 1200 simulated 60Hz frames; 3 rotated process repetitions",
		"performance_ci_gate": False,
	}
	deadline = time.monotonic() + args.deadline_seconds
	boundary_quiescent = True
	primary_error: BaseException | None = None

	def execute(label: str, command_args: list[str], *, record: bool = False) -> dict[str, Any]:
		nonlocal boundary_quiescent
		remaining = deadline - time.monotonic()
		if remaining <= 0:
			raise TimeoutError("Overall reactive benchmark deadline exceeded.")
		cpu = _ProcessCPU()
		callback_error: BaseException | None = None
		run_error: BaseException | None = None

		def process_started(pid: int) -> None:
			nonlocal callback_error
			try:
				cpu.start(pid)
			except BaseException as error:
				callback_error = error
				raise

		boundary_quiescent = False
		try:
			result = run_supervised_process(
				[str(godot), *command_args], cwd=project, timeout_seconds=min(60.0, remaining),
				environment=environment, process_started_callback=process_started,
				max_stdout_characters=2 * 1024 * 1024, max_stderr_characters=2 * 1024 * 1024,
				heartbeat_callback=lambda elapsed, pid: print(f"heartbeat {label} {elapsed:.1f}s pid={pid}", flush=True),
			)
			boundary_quiescent = result.process_boundary_quiescent is True
		except BaseException as error:
			run_error = error
			# The supervisor rethrows our exact callback exception only after quiet
			# cleanup; unproven cleanup instead wraps it in CleanupError. Generic
			# supervision failures carry no positive proof and retain the sandbox.
			boundary_quiescent = (
				((isinstance(error, SupervisedProcessStartError) and error.process_boundary_quiescent is True)
					or error is callback_error)
				and not exception_has_cleanup_debt(error)
			)
			raise
		finally:
			try:
				process_cpu = cpu.finish()
			except BaseException as accounting_error:
				if run_error is None:
					raise
				add_exception_note(run_error, f"Process CPU accounting cleanup failed: {safe_exception_detail(accounting_error)}")
		log = log_root / f"{label}_{result.pid}.log"
		log.write_text(result.stdout + result.stderr, encoding="utf-8")
		if result.return_code != 0 or result.timed_out or not boundary_quiescent or result.stdout_truncated or result.stderr_truncated:
			raise RuntimeError(f"Owned run {label} failed: exit={result.return_code}; see {log}")
		if any(marker in result.stdout + result.stderr for marker in ("SCRIPT ERROR", "ERROR:", "WARNING:")):
			raise RuntimeError(f"Diagnostics in {label}; see {log}")
		print(f"{label}: process CPU={process_cpu['seconds']}s; elapsed={result.duration_seconds:.3f}s", flush=True)
		if not record:
			return {}
		markers = [line.removeprefix("GF_REACTIVE_RESULT=") for line in result.stdout.splitlines() if line.startswith("GF_REACTIVE_RESULT=")]
		if len(markers) != 1:
			raise ValueError(f"Missing exact result marker for {label}.")
		payload = json.loads(markers[0])
		if not Path(payload["user_data_dir"]).resolve().is_relative_to(stage):
			raise ValueError("Godot user data escaped the private root.")
		payload.update({"process_cpu": process_cpu, "wall_seconds": result.duration_seconds, "pid": result.pid, "log": str(log), "command": [str(godot), *command_args]})
		report["runs"].append(payload)
		_write_report(output, report)
		return payload

	stage = Path(tempfile.mkdtemp(prefix="gfr-", dir=temp_parent))
	try:
		stage_metadata = stage.stat()
		stage_identity = (stage_metadata.st_dev, stage_metadata.st_ino)
		# Establish ownership before any project or environment staging can fail.
		(stage / "owner.receipt").write_bytes(owner_bytes)
		report["stage"] = str(stage)
		project = stage / "project"
		closure = project / "addons/gf/kernel/core"
		log_root = ROOT / "ai_analysis/godot_logs/reactive_benchmark" / stage.name
		closure.mkdir(parents=True)
		for name in KERNEL_FILES:
			source = ROOT / "addons/gf/kernel/core" / name
			frozen = source.read_bytes()
			(closure / name).write_bytes(frozen)
			manifest.append({"path": f"addons/gf/kernel/core/{name}", "bytes": len(frozen), "sha256": hashlib.sha256(frozen).hexdigest()})
		shutil.copyfile(FIXTURE / "project.godot.fixture", project / "project.godot")
		shutil.copyfile(FIXTURE / "reactive_pull_benchmark.gd", project / "benchmark.gd")
		environment = {key: value for key, value in os.environ.items() if not key.upper().startswith("GIT_")}
		for key, child in {
			"USERPROFILE": "profile", "HOME": "home", "APPDATA": "roaming", "LOCALAPPDATA": "local",
			"TEMP": "temp", "TMP": "temp", "XDG_DATA_HOME": "xdg_data", "XDG_CONFIG_HOME": "xdg_config", "XDG_CACHE_HOME": "xdg_cache",
		}.items():
			path = stage / child
			path.mkdir(exist_ok=True)
			environment[key] = str(path)
		environment["GF_MAINTENANCE_KEEP_LOGS"] = "1"
		log_root.mkdir(parents=True)
		report["fixture_sha256"] = _sha256(project / "benchmark.gd")
		report["runner_sha256"] = _sha256(Path(__file__))
		inputs_manifest = [
			{"path": str(path.relative_to(ROOT)), "sha256": _sha256(path)}
			for path in (Path(__file__).resolve(), FIXTURE / "project.godot.fixture", FIXTURE / "reactive_pull_benchmark.gd")
		]
		report["harness_manifest"] = inputs_manifest
		execute("import", ["--headless", "--path", str(project), "--editor", "--import", "--quit", "--log-file", str(log_root / "import_engine.log")])
		correctness = execute("correctness", ["--headless", "--path", str(project), "--script", "res://benchmark.gd", "--log-file", str(log_root / "correctness_engine.log"), "--", "correctness", "static_pull"], record=True)
		if not correctness.get("ok"):
			raise ValueError("Private prototype correctness failed.")
		if not args.correctness_only:
			for repetition in range(3):
				for workload in WORKLOADS:
					for mode in MODES[repetition:] + MODES[:repetition]:
						label = f"r{repetition}_{workload}_{mode}"
						execute(label, ["--headless", "--path", str(project), "--script", "res://benchmark.gd", "--log-file", str(log_root / (label + "_engine.log")), "--", workload, mode], record=True)
			report["summary"] = _summarize(report["runs"])
		for item in manifest:
			if _sha256(ROOT / item["path"]) != item["sha256"] or _sha256(project / item["path"]) != item["sha256"]:
				raise ValueError(f"Kernel closure drifted: {item['path']}")
		for item in inputs_manifest:
			if _sha256(ROOT / item["path"]) != item["sha256"]:
				raise ValueError(f"Benchmark harness input drifted: {item['path']}")
		report["kernel_integrity"] = "live inputs and frozen copies match the captured SHA256 manifest"
		report["valid"] = True
	except BaseException as error:
		primary_error = error
		report["error"] = safe_exception_detail(error)
		raise
	finally:
		# Only delete this exact created sandbox with its unchanged ownership receipt,
		# after the supervisor has proven the last process boundary quiescent.
		try:
			report["stage"] = str(stage)
			can_cleanup = (
				boundary_quiescent and not args.keep_sandbox and stage_identity is not None
				and _cleanup_allowed(stage, temp_parent, owner_bytes, stage_identity)
			)
			report["sandbox_cleanup"] = "retained; requested or cleanup ownership/boundary not proven"
			if can_cleanup:
				shutil.rmtree(stage)
				report["sandbox_cleanup"] = "owned sandbox removed after quiescent process boundary"
		except BaseException as cleanup_error:
			report["valid"] = False
			report["cleanup_error"] = safe_exception_detail(cleanup_error)
			if primary_error is None:
				primary_error = cleanup_error
				raise
			add_exception_note(primary_error, f"Owned sandbox cleanup failed: {safe_exception_detail(cleanup_error)}")
		finally:
			try:
				_write_report(output, report)
			except BaseException as report_error:
				if primary_error is None:
					raise
				add_exception_note(primary_error, f"Benchmark report write failed: {safe_exception_detail(report_error)}")
	return report


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--godot", type=Path, required=True, help="Explicit trusted Godot executable.")
	parser.add_argument("--output", type=Path, default=ROOT / "build/reactive-benchmark.json")
	parser.add_argument("--temp-parent", type=Path, default=Path(tempfile.gettempdir()))
	parser.add_argument("--deadline-seconds", type=float, default=180.0, help="Overall finite deadline, 1..600 seconds.")
	parser.add_argument("--correctness-only", action="store_true")
	parser.add_argument("--keep-sandbox", action="store_true")
	args = parser.parse_args()
	if not math.isfinite(args.deadline_seconds) or not 1.0 <= args.deadline_seconds <= 600.0:
		parser.error("deadline-seconds must be finite and between 1 and 600.")
	try:
		report = run_benchmark(args)
	except (OSError, ValueError, RuntimeError, TimeoutError) as error:
		print(f"Reactive benchmark failed: {error}", file=sys.stderr)
		return 1
	print(json.dumps({"valid": report["valid"], "output": str(args.output), "summary": report["summary"]}, ensure_ascii=False, indent=2))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
