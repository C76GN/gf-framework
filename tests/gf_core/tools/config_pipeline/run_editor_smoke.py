"""Exercise the configuration workbench in an isolated native editor lifecycle."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import stat
import sys
import uuid

ROOT = next(parent for parent in Path(__file__).resolve().parents if (parent / "tools/gf_maintenance.py").is_file())
sys.path.insert(0, str(ROOT / "tools"))
import gf_maintenance as maintenance
import gf_path_security as path_security
import gf_process_supervisor as supervisor

FIXTURES = Path("tests/gf_core/tools/config_pipeline/fixtures")
SUCCESS = "GF_CONFIG_WORKBENCH_EDITOR_SMOKE_OK"
FAILURE = "GF_CONFIG_WORKBENCH_EDITOR_SMOKE_FAILED"
MAX_FILE_BYTES = 32 * 1024 * 1024


def inventory(source: Path) -> dict[str, str]:
	result: dict[str, str] = {}
	pending = [(source, 0)]
	total_bytes = 0
	entry_count = 0
	while pending:
		base, depth = pending.pop()
		if depth > 32 or path_security.path_has_reparse_component(base):
			raise RuntimeError("Smoke source directory violates its depth/link boundary.")
		with os.scandir(base) as entries:
			for entry in entries:
				entry_count += 1
				if entry_count > 20000:
					raise RuntimeError("Smoke source inventory exceeds its entry budget.")
				path = Path(entry.path)
				identity = path.lstat()
				if stat.S_ISLNK(identity.st_mode) or getattr(identity, "st_file_attributes", 0) & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0):
					raise RuntimeError("Linked sources are outside the smoke boundary.")
				if stat.S_ISDIR(identity.st_mode):
					pending.append((path, depth + 1))
				elif stat.S_ISREG(identity.st_mode):
					relative = path.relative_to(source).as_posix()
					payload = path_security.read_pinned_regular_file(source, relative, max_bytes=min(MAX_FILE_BYTES, 256 * 1024 * 1024 - total_bytes))
					total_bytes += len(payload)
					result[relative] = hashlib.sha256(payload).hexdigest()
				else:
					raise RuntimeError("Special files are outside the smoke boundary.")
	return result


def copy_inventory(source: Path, destination: Path, expected: dict[str, str]) -> None:
	for relative, digest in expected.items():
		payload = path_security.read_pinned_regular_file(source, relative, max_bytes=MAX_FILE_BYTES)
		if hashlib.sha256(payload).hexdigest() != digest:
			raise RuntimeError("Source changed during smoke capture.")
		target = destination / relative
		target.parent.mkdir(parents=True, exist_ok=True)
		target.write_bytes(payload)
	if inventory(destination) != expected or inventory(source) != expected:
		raise RuntimeError("Smoke capture did not preserve its pinned inventory.")


def run_phase(name: str, command: list[str], project: Path, environment: dict[str, str], logs: Path) -> dict[str, object]:
	result = supervisor.run_supervised_process(command, cwd=project, environment=environment, timeout_seconds=180, max_stdout_characters=1024 * 1024, max_stderr_characters=1024 * 1024)
	(logs / f"{name}.stdout.log").write_text(result.stdout, encoding="utf-8")
	(logs / f"{name}.stderr.log").write_text(result.stderr, encoding="utf-8")
	if result.process_boundary_quiescent is not True:
		raise maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError("Smoke process boundary is not quiescent.")
	log = path_security.read_pinned_regular_file(logs, f"{name}.godot.log", max_bytes=4 * 1024 * 1024).decode("utf-8")
	combined = "\n".join((result.stdout, result.stderr, log))
	issues = []
	if result.return_code != 0 or result.cancelled or result.timed_out or result.stdout_truncated or result.stderr_truncated or not log:
		issues.append("Godot did not provide a complete successful process/log result.")
	if maintenance.has_godot_script_error(combined, "") or maintenance.has_gdscript_reload_warning(combined, "") or any(marker in combined for marker in ("ERROR:", "WARNING:", FAILURE)):
		issues.append("Godot reported an error, warning or failed assertion.")
	if name == "editor" and (result.stdout.count(SUCCESS) != 1 or log.count(SUCCESS) != 1):
		issues.append("Native smoke success evidence is missing or duplicated.")
	if name == "import" and SUCCESS in combined:
		issues.append("Smoke executed before explicit plugin activation.")
	return {"ok": not issues, "name": name, "return_code": result.return_code, "issues": issues, "notes": list(result.notes)}


def main() -> int:
	logs = ROOT / "ai_analysis/godot_logs" / ("config-workbench-smoke-" + uuid.uuid4().hex)
	logs.mkdir(parents=True, exist_ok=False)
	report: dict[str, object] = {"ok": False, "log_directory": str(logs), "phases": []}
	try:
		framework = inventory(ROOT / "addons/gf")
		fixtures = inventory(ROOT / FIXTURES)
		(logs / "source-hashes.json").write_text(json.dumps({"framework": framework, "fixtures": fixtures}, sort_keys=True), encoding="utf-8")
		with maintenance.strict_process_boundary_temporary_directory(prefix="gfcw-") as temporary:
			base = Path(temporary)
			project = base / "project"
			copy_inventory(ROOT / "addons/gf", project / "addons/gf", framework)
			copy_inventory(ROOT / FIXTURES, project / FIXTURES, fixtures)
			plugin = project / "addons/config_smoke"
			plugin.mkdir(parents=True)
			for source_name, target_name in [("gf_config_workbench_editor_smoke.gd", "gf_config_workbench_editor_smoke.gd"), ("gf_config_workbench_editor_smoke_plugin.cfg", "plugin.cfg")]:
				(plugin / target_name).write_bytes(path_security.read_pinned_regular_file(project / FIXTURES, source_name, max_bytes=MAX_FILE_BYTES))
			environment = maintenance.make_core_plugin_bootstrap_smoke_environment(base, "resource_preview_translation", base_environment=maintenance.capture_maintenance_process_environment())
			executable = maintenance.resolve_godot_executable(environment=environment, cwd=ROOT)
			common = [str(executable), "--headless", "--editor", "--audio-driver", "Dummy", "--path", str(project)]
			project_text = 'config_version=5\n\n[application]\nconfig/name="GF Config Workbench Smoke"\n\n[editor_plugins]\nenabled=PackedStringArray(%s)\n'
			(project / "project.godot").write_text(project_text % "", encoding="utf-8")
			phases: list[dict[str, object]] = []
			report["phases"] = phases
			phase = run_phase("import", [*common, "--import", "--quit", "--log-file", str(logs / "import.godot.log")], project, environment, logs)
			phases.append(phase)
			if phase["ok"]:
				(project / "project.godot").write_text(project_text % '"res://addons/config_smoke/plugin.cfg"', encoding="utf-8")
				phases.append(run_phase("editor", [*common, "--log-file", str(logs / "editor.godot.log")], project, environment, logs))
				report["source_unchanged"] = inventory(ROOT / "addons/gf") == framework and inventory(ROOT / FIXTURES) == fixtures
				report["ok"] = report["source_unchanged"] and all(phase["ok"] for phase in phases)
	except Exception as error:
		report["error"] = f"{type(error).__name__}: {error}"
	(logs / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
	print(json.dumps(report, ensure_ascii=False, indent=2))
	return 0 if report["ok"] else 1


if __name__ == "__main__":
	raise SystemExit(main())
