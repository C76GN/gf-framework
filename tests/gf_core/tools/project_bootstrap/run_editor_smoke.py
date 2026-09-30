"""Validate project bootstrap creation and generated runtime scenes in a private project.

Uses the repository's bounded source-capture helper and owned process supervisor;
it never enables the fixture in the caller's project or saves caller settings.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import uuid

ROOT = next(
	parent for parent in Path(__file__).resolve().parents
	if (parent / "tools/gf_maintenance.py").is_file() and (parent / "addons/gf").is_dir()
)
sys.path.insert(0, str(ROOT / "tools"))
import gf_maintenance as maintenance
import gf_path_security as path_security
import gf_process_supervisor as supervisor

# Reuse existing bounded/pinned inventory capture; this is test support only.
_SPEC = importlib.util.spec_from_file_location(
	"gf_bootstrap_smoke_capture", ROOT / "tests/gf_core/tools/scene_placement/run_editor_smoke.py",
)
assert _SPEC is not None and _SPEC.loader is not None
capture = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(capture)

FIXTURES = Path("tests/gf_core/tools/project_bootstrap/fixtures")
EDITOR_SUCCESS = "GF_PROJECT_BOOTSTRAP_EDITOR_SMOKE_OK"
RUNTIME_SUCCESS = "GF_PROJECT_BOOTSTRAP_RUNTIME_SMOKE_OK"
EXPECTED_BOOT_FAILURE = (
	"ERROR: [GFProjectBootstrap][project_bootstrap.init_failed] "
	"GF initialization did not complete; startup was stopped."
)
LOG_LIMIT = 4 * 1024 * 1024


def run_phase(
	name: str, command: list[str], project: Path, environment: dict[str, str],
	logs: Path, marker: str = "",
) -> dict[str, object]:
	log = logs / f"{name}.godot.log"
	engine_command = list(command)
	separator = engine_command.index("--") if "--" in engine_command else len(engine_command)
	engine_command[separator:separator] = ["--log-file", str(log)]
	result = supervisor.run_supervised_process(
		engine_command, cwd=project, timeout_seconds=180,
		environment=environment, max_stdout_characters=1024 * 1024,
		max_stderr_characters=1024 * 1024,
		heartbeat_callback=lambda elapsed, pid: print(
			f"project-bootstrap {name}: {elapsed:.0f}s pid={pid}", file=sys.stderr, flush=True,
		),
	)
	(logs / f"{name}.stdout.log").write_text(result.stdout, encoding="utf-8", newline="\n")
	(logs / f"{name}.stderr.log").write_text(result.stderr, encoding="utf-8", newline="\n")
	if result.process_boundary_quiescent is not True:
		raise maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError("Smoke process boundary was not proven quiet.")
	issues: list[str] = []
	if result.return_code != 0 or result.timed_out or result.cancelled:
		issues.append(f"Godot did not complete normally: code={result.return_code}.")
	if result.stdout_truncated or result.stderr_truncated:
		issues.append("Godot output exceeded its bounded capture.")
	log_text = ""
	try:
		payload = path_security.read_pinned_regular_file(logs, log.name, max_bytes=LOG_LIMIT)
		if not payload:
			raise RuntimeError("Required Godot log is empty.")
		log_text = payload.decode("utf-8", errors="strict")
	except (OSError, RuntimeError, UnicodeError) as error:
		issues.append(str(error))
	combined = "\n".join((result.stdout, result.stderr, log_text))
	if maintenance.has_godot_script_error(combined, "") or maintenance.has_gdscript_reload_warning(combined, ""):
		issues.append("Godot reported a script error or reload warning.")
	diagnostics = {
		channel: [line.strip() for line in text.splitlines() if "ERROR:" in line or "WARNING:" in line]
		for channel, text in (("stdout", result.stdout), ("stderr", result.stderr), ("godot_log", log_text))
	}
	if name == "runtime_empty":
		# This one phase intentionally removes the real Gf AutoLoad from the tree.
		# Require the sole exact product diagnostic independently in both channels;
		# missing, repeated, additional or differently worded diagnostics fail closed.
		if diagnostics != {"stdout": [], "stderr": [EXPECTED_BOOT_FAILURE], "godot_log": [EXPECTED_BOOT_FAILURE]}:
			issues.append("The real Boot failure must produce exactly the expected stderr/log diagnostic and no other diagnostics.")
	elif any(diagnostics.values()):
		issues.append("Godot reported an unexpected error or warning.")
	if any(token in combined for token in ("GF_PROJECT_BOOTSTRAP_EDITOR_SMOKE_FAILED", "GF_PROJECT_BOOTSTRAP_RUNTIME_SMOKE_FAILED")):
		issues.append("A fixture assertion failed.")
	fixture: dict[str, object] = {}
	if marker:
		try:
			if result.stdout.count(marker) != 1 or log_text.count(marker) != 1:
				raise ValueError("Expected exactly one success marker in stdout and the required log.")
			stdout_marker = next(line for line in result.stdout.splitlines() if line.startswith(marker + " "))
			log_marker = next(line for line in log_text.splitlines() if line.startswith(marker + " "))
			if stdout_marker != log_marker:
				raise ValueError("Stdout and Godot log evidence disagree.")
			fixture = json.loads(stdout_marker[len(marker) + 1:])
			if type(fixture) is not dict or type(fixture.get("assertions")) is not int or fixture["assertions"] < 1:
				raise ValueError("Fixture must prove a positive assertion count.")
			if fixture.get("native_private_directories_verified") is not True:
				raise ValueError("Native private directory observations are missing.")
			if marker == EDITOR_SUCCESS:
				keys = (
					"new_project_default_created", "existing_preserves_main_and_installers",
					"guidance_only_no_writes", "readme_only_no_settings_save", "settings_failure_compensated",
					"create_only_and_preview_stale", "retired_callbacks_rejected", "recovery_ui_preserved",
					"legacy_sample_preserved", "canonical_autoload_guarded",
				)
			elif name == "runtime_empty":
				keys = (
					"normal_project_entry_used", "no_counter_modules", "boot_waits_for_init_before_main",
					"boot_exit_preserves_global_gf", "owner_retired_no_late_switch", "failure_stays_on_boot",
				)
				for key, expected in (("boot_entry_count", 3), ("main_entry_count", 1), ("expected_boot_failure_count", 1)):
					if type(fixture.get(key)) is not int or fixture[key] != expected:
						raise ValueError("Incomplete actual Boot lifecycle observation: " + key)
			else:
				keys = (
					"normal_project_entry_used", "no_counter_modules", "existing_entry_preserved",
					"existing_installer_order_preserved", "empty_installer_registers_no_business",
				)
			for key in keys:
				if fixture.get(key) is not True:
					raise ValueError("Missing actual fixture observation: " + key)
		except (StopIteration, TypeError, ValueError) as error:
			issues.append(str(error))
	elif EDITOR_SUCCESS in combined or RUNTIME_SUCCESS in combined:
		issues.append("A fixture ran during import instead of explicit activation.")
	return {
		"phase": name, "ok": not issues, "issues": issues, "return_code": result.return_code,
		"duration_seconds": result.duration_seconds, "process_boundary_quiescent": True,
		"fixture_report": fixture,
		"diagnostics": diagnostics,
		"expected_boot_failure_verified": name == "runtime_empty" and diagnostics == {
			"stdout": [], "stderr": [EXPECTED_BOOT_FAILURE], "godot_log": [EXPECTED_BOOT_FAILURE],
		},
	}


def write_project(project: Path, enabled: bool) -> None:
	plugins = '"res://addons/bootstrap_smoke/plugin.cfg"' if enabled else ""
	(project / "project.godot").write_text(
		'config_version=5\n\n[application]\nconfig/name="GF Project Bootstrap Smoke"\n\n'
		'[autoload]\nGf="*res://addons/gf/kernel/core/gf.gd"\n\n'
		'[rendering]\nrenderer/rendering_method="gl_compatibility"\n\n'
		f"[editor_plugins]\nenabled=PackedStringArray({plugins})\n",
		encoding="utf-8", newline="\n",
	)


def write_runtime_fixtures(project: Path) -> None:
	"""Seed only the disposable project's existing application and test observers."""
	for name, label in (("existing_installer.gd", "one"), ("legacy_counter_installer.gd", "legacy")):
		(project / name).write_text(
			'extends GFInstaller\n\n\n# --- Public methods ---\n\n'
			'func install(_architecture: GFArchitecture, _scope: GFAsyncScope) -> void:\n'
			'\tvar tree: SceneTree = Engine.get_main_loop()\n'
			'\tvar observer: Node = tree.root.get_node("BootstrapObserver")\n'
			f'\tvar _observed: Variant = observer.call(&"record_installer", "{label}")\n',
			encoding="utf-8", newline="\n",
		)
	(project / "delayed_installer.gd").write_text(
		'extends GFInstaller\n\n\n# --- Public methods ---\n\n'
		'func install(architecture: GFArchitecture, _scope: GFAsyncScope) -> void:\n'
		'\tvar tree: SceneTree = Engine.get_main_loop()\n'
		'\tvar observer: Node = tree.root.get_node("BootstrapObserver")\n'
		'\tvar _held: Variant = await observer.call(&"hold_installer", architecture)\n',
		encoding="utf-8", newline="\n",
	)
	(project / "existing.gd").write_text(
		'extends Node\n\n\n# --- Godot callbacks ---\n\n'
		'func _ready() -> void:\n'
		'\tvar observer: Node = get_tree().root.get_node("BootstrapObserver")\n'
		'\tvar _started: Variant = observer.call(&"observe_existing_start")\n'
		'\tvar initialized: bool = await Gf.init()\n'
		'\tvar _finished: Variant = observer.call(&"observe_existing_complete", initialized)\n',
		encoding="utf-8", newline="\n",
	)
	(project / "existing.tscn").write_text(
		'[gd_scene load_steps=2 format=3]\n\n'
		'[ext_resource type="Script" path="res://existing.gd" id="1"]\n\n'
		'[node name="Existing" type="Node"]\nscript = ExtResource("1")\n',
		encoding="utf-8", newline="\n",
	)
	(project / "sentinel.tscn").write_text(
		'[gd_scene format=3]\n\n[node name="Sentinel" type="Node"]\n',
		encoding="utf-8", newline="\n",
	)


def configure_runtime_observer(project: Path, *, empty: bool) -> None:
	"""Activate the observer after import; retain the real project startup path."""
	path = project / "project.godot"
	lines = path.read_text(encoding="utf-8").splitlines()

	def set_value(section: str, key: str, value: str) -> None:
		headers = [index for index, line in enumerate(lines) if line == f"[{section}]"]
		if len(headers) != 1:
			raise RuntimeError("The fixture project must have one settings section: " + section)
		start = headers[0] + 1
		end = next((index for index in range(start, len(lines)) if lines[index].startswith("[")), len(lines))
		matches = [index for index in range(start, end) if lines[index].startswith(key + "=")]
		if len(matches) > 1:
			raise RuntimeError("The fixture project has duplicate settings: " + key)
		if matches:
			lines[matches[0]] = key + "=" + value
		else:
			lines.insert(end, key + "=" + value)

	set_value("autoload", "BootstrapObserver", '"*res://' + FIXTURES.as_posix() + '/gf_project_bootstrap_runtime_smoke.gd"')
	if empty:
		set_value("application", "run/main_scene", '"res://app/boot.tscn"')
		set_value("gf", "project/installers", '["res://app/project_installer.gd"]')
	path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--keep-logs", action="store_true")
	args = parser.parse_args()
	frozen_environment = maintenance.FrozenProcessEnvironment.capture(maintenance.capture_maintenance_process_environment())
	keep_logs = args.keep_logs or maintenance.maintenance_logs_kept_from_environment(frozen_environment)
	logs = ROOT / "ai_analysis/godot_logs" / ("project-bootstrap-smoke-" + uuid.uuid4().hex)
	logs.mkdir(parents=True, exist_ok=False)
	log_identity = logs.lstat()
	phases: list[dict[str, object]] = []
	report: dict[str, object] = {"ok": False, "phases": phases, "log_directory": str(logs)}
	try:
		gf_hashes = capture.inventory(ROOT / "addons/gf")
		fixture_hashes = capture.inventory(ROOT / FIXTURES)
		source_payload = json.dumps({"gf": gf_hashes, "fixtures": fixture_hashes}, sort_keys=True)
		report["source_snapshot_sha256"] = hashlib.sha256(source_payload.encode("utf-8")).hexdigest()
		(logs / "source-hashes.json").write_text(source_payload + "\n", encoding="utf-8", newline="\n")
		with maintenance.strict_process_boundary_temporary_directory(prefix="gfpb-") as temporary:
			base = Path(temporary)
			project = base / "project"
			capture.copy_inventory(ROOT / "addons/gf", project / "addons/gf", gf_hashes)
			capture.copy_inventory(ROOT / FIXTURES, project / FIXTURES, fixture_hashes)
			plugin = project / "addons/bootstrap_smoke"
			plugin.mkdir(parents=True)
			for target, source in {"plugin.cfg": "gf_project_bootstrap_editor_smoke_plugin.cfg", "gf_project_bootstrap_editor_smoke.gd": "gf_project_bootstrap_editor_smoke.gd"}.items():
				(plugin / target).write_bytes(path_security.read_pinned_regular_file(project / FIXTURES, source, max_bytes=capture.MAX_FILE_BYTES))
			write_runtime_fixtures(project)
			environment = maintenance.make_core_plugin_bootstrap_smoke_environment(base, "resource_preview_translation", base_environment=frozen_environment.values())
			environment["GF_PROJECT_BOOTSTRAP_SMOKE_PRIVATE_ROOT"] = str(base / "resource_preview_translation/user")
			godot = maintenance.resolve_godot_executable(environment=environment, cwd=ROOT)
			common = [godot, "--headless", "--editor", "--path", str(project), "--audio-driver", "Dummy"]
			write_project(project, False)
			phases.append(run_phase("import", [*common, "--import", "--quit"], project, environment, logs))
			if phases[-1]["ok"]:
				write_project(project, True)
				phases.append(run_phase("editor", common, project, environment, logs, EDITOR_SUCCESS))
			if phases[-1]["ok"]:
				phases.append(run_phase("generated_import", [*common, "--import", "--quit"], project, environment, logs))
			if phases[-1]["ok"]:
				configure_runtime_observer(project, empty=False)
				runtime = [godot, "--headless", "--path", str(project), "--audio-driver", "Dummy"]
				phases.append(run_phase("runtime", runtime, project, environment, logs, RUNTIME_SUCCESS))
				if phases[-1]["ok"]:
					configure_runtime_observer(project, empty=True)
					# Engine flags precede the user-argument separator, including log-file.
					empty_runtime = [*runtime, "--", "--empty-project"]
					phases.append(run_phase("runtime_empty", empty_runtime, project, environment, logs, RUNTIME_SUCCESS))
			report["source_fixtures_unchanged"] = capture.inventory(ROOT / FIXTURES) == fixture_hashes
			report["gf_sources_unchanged"] = capture.inventory(ROOT / "addons/gf") == gf_hashes
			report["copied_sources_unchanged"] = all(
				hashlib.sha256(path_security.read_pinned_regular_file(project / directory, name, max_bytes=capture.MAX_FILE_BYTES)).hexdigest() == digest
				for directory, hashes in ((Path("addons/gf"), gf_hashes), (FIXTURES, fixture_hashes))
				for name, digest in hashes.items()
			)
			report["ok"] = len(phases) == 5 and all(phase["ok"] for phase in phases) and all(report[key] for key in ("source_fixtures_unchanged", "gf_sources_unchanged", "copied_sources_unchanged"))
	except Exception as error:
		report["error"] = f"{type(error).__name__}: {error}"
		report["exception_notes"] = list(getattr(error, "__notes__", ()))
		report["ok"] = False
	(logs / "result.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
	if report["ok"] and not keep_logs:
		cleanup_error = maintenance.remove_managed_temporary_tree(logs, expected_identity=log_identity)
		if cleanup_error:
			report["ok"] = False
			report["cleanup_error"] = cleanup_error
		else:
			report["logs_removed"] = True
	print(json.dumps(report, ensure_ascii=False, indent=2))
	return 0 if report["ok"] else 1


if __name__ == "__main__":
	raise SystemExit(main())
