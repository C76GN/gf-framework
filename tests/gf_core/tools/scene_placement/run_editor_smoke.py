"""Run scene placement through an isolated, supervised native editor lifecycle."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
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

FIXTURES = Path("tests/gf_core/tools/scene_placement/fixtures")
SUCCESS = "GF_SCENE_PLACEMENT_EDITOR_SMOKE_OK"
FAILURE = "GF_SCENE_PLACEMENT_EDITOR_SMOKE_FAILED"
LOG_LIMIT = 4 * 1024 * 1024
MAX_ENTRIES = 20000
MAX_FILES = 16000
MAX_DEPTH = 32
MAX_FILE_BYTES = 32 * 1024 * 1024
MAX_TOTAL_BYTES = 256 * 1024 * 1024


def require_regular(path: Path) -> None:
	identity = path.lstat()
	if stat.S_ISLNK(identity.st_mode) or (
		getattr(identity, "st_file_attributes", 0)
		& getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
	):
		raise RuntimeError(f"A linked source is outside the smoke boundary: {path}")
	if not (stat.S_ISDIR(identity.st_mode) or stat.S_ISREG(identity.st_mode)):
		raise RuntimeError(f"A special file is outside the smoke boundary: {path}")


def inventory(source: Path) -> dict[str, str]:
	require_regular(source)
	result: dict[str, str] = {}
	pending = [(source, 0)]
	entry_count = 0
	total_bytes = 0
	while pending:
		base, depth = pending.pop()
		if path_security.path_has_reparse_component(base):
			raise RuntimeError(f"A linked directory is outside the smoke boundary: {base}")
		with os.scandir(base) as entries:
			for entry in entries:
				entry_count += 1
				if entry_count > MAX_ENTRIES:
					raise RuntimeError("Smoke source inventory exceeded its entry budget.")
				path = Path(entry.path)
				require_regular(path)
				if entry.is_dir(follow_symlinks=False):
					if depth + 1 > MAX_DEPTH:
						raise RuntimeError("Smoke source inventory exceeded its depth budget.")
					pending.append((path, depth + 1))
					continue
				if len(result) >= MAX_FILES:
					raise RuntimeError("Smoke source inventory exceeded its file budget.")
				name = path.relative_to(source).as_posix()
				payload = path_security.read_pinned_regular_file(
					source, name, max_bytes=min(MAX_FILE_BYTES, MAX_TOTAL_BYTES - total_bytes),
				)
				total_bytes += len(payload)
				result[name] = hashlib.sha256(payload).hexdigest()
	return result


def copy_inventory(source: Path, destination: Path, expected: dict[str, str]) -> None:
	destination.mkdir(parents=True, exist_ok=True)
	for name, digest in expected.items():
		content = path_security.read_pinned_regular_file(source, name, max_bytes=MAX_FILE_BYTES)
		if hashlib.sha256(content).hexdigest() != digest:
			raise RuntimeError(f"Source changed before smoke capture: {source / name}")
		target = destination / name
		target.parent.mkdir(parents=True, exist_ok=True)
		target.write_bytes(content)
	if inventory(source) != expected or inventory(destination) != expected:
		raise RuntimeError("Source or captured inventory changed during smoke setup.")


def write_project(project: Path, enabled: bool) -> None:
	plugins = (
		'"res://addons/gf/tools/scene_placement/plugin.cfg", '
		'"res://addons/scene_placement_smoke/plugin.cfg"'
	) if enabled else ""
	(project / "project.godot").write_text(
		'config_version=5\n\n[application]\nconfig/name="GF Scene Placement Smoke"\n\n'
		'[rendering]\nrenderer/rendering_method="gl_compatibility"\n\n'
		f"[editor_plugins]\nenabled=PackedStringArray({plugins})\n",
		encoding="utf-8", newline="\n",
	)


def run_phase(name: str, command: list[str], project: Path, environment: dict[str, str], logs: Path) -> dict[str, object]:
	result = supervisor.run_supervised_process(
		command, cwd=project, timeout_seconds=180, environment=environment,
		max_stdout_characters=1024 * 1024, max_stderr_characters=1024 * 1024,
	)
	(logs / f"{name}.stdout.log").write_text(result.stdout, encoding="utf-8")
	(logs / f"{name}.stderr.log").write_text(result.stderr, encoding="utf-8")
	if result.process_boundary_quiescent is not True:
		raise maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError("The smoke process boundary was not proven quiet.")
	issues: list[str] = []
	if result.return_code != 0 or result.cancelled or result.timed_out:
		issues.append(f"Godot did not complete normally: code={result.return_code}.")
	if result.stdout_truncated or result.stderr_truncated:
		issues.append("Godot output was truncated.")
	log_text = ""
	try:
		content = path_security.read_pinned_regular_file(logs, f"{name}.godot.log", max_bytes=LOG_LIMIT)
		if not content:
			raise RuntimeError("Required Godot log is empty.")
		log_text = content.decode("utf-8", errors="strict")
	except (OSError, RuntimeError, UnicodeError) as error:
		issues.append(str(error))
	combined = "\n".join((result.stdout, result.stderr, log_text))
	if maintenance.has_godot_script_error(combined, "") or maintenance.has_gdscript_reload_warning(combined, ""):
		issues.append("Godot reported a script error or reload warning.")
	if any(token in combined for token in ("ERROR:", "WARNING:", FAILURE)):
		issues.append("Godot reported an error, lifecycle warning, or failed assertion.")
	# CI consumes this report even when the standalone log tree is unavailable.
	# Keep the fixture's first failed assertion visible without copying full logs.
	failed_assertion = next((line for line in combined.splitlines() if line.startswith(FAILURE + " ")), "")
	if failed_assertion:
		issues.append(failed_assertion[:2000])
	if name == "editor":
		if result.stdout.count(SUCCESS) != 1 or log_text.count(SUCCESS) != 1:
			issues.append("Expected exactly one smoke success marker in stdout and the required log.")
	elif SUCCESS in combined:
		issues.append("Smoke ran before explicit plugin activation.")
	fixture_report: dict[str, object] = {}
	if name == "editor" and not issues:
		try:
			stdout_marker = next(line for line in result.stdout.splitlines() if line.startswith(SUCCESS + " "))
			log_marker = next(line for line in log_text.splitlines() if line.startswith(SUCCESS + " "))
			if stdout_marker != log_marker:
				raise ValueError("Stdout and Godot log fixture evidence disagree.")
			fixture_report = json.loads(stdout_marker[len(SUCCESS) + 1:])
			if type(fixture_report.get("assertions")) is not int or fixture_report["assertions"] < 1:
				raise ValueError("Fixture success has no positive assertion count.")
			for key in (
				"native_private_directories_verified",
				"native_undo_redo_anchor_parent_transform_save_reload",
				"native_gui_forwarded",
				"native_pointer_plane_cancel_and_confirm",
				"actual_editor_world_collision_surface",
				"scene_switch_cancels_stale_pointer",
				"unloaded_plugin_history_replay",
				"independent_plugin_survives_context_clear",
				"independent_plugin_survives_page_replacement",
				"independent_plugin_open_does_not_claim_ownership",
				"independent_plugin_close_then_open_preserves_child",
				"independent_plugin_explicit_close_releases_child",
				"independent_reenabled_plugin_survives_old_owner",
				"launcher_context_clear_releases_child",
				"launcher_exit_releases_child",
				"launcher_same_frame_replacement_preserves_child",
				"launcher_left_enabled_for_editor_exit",
			):
				if fixture_report.get(key) is not True:
					raise ValueError(f"Fixture did not prove required observation: {key}")
		except (StopIteration, TypeError, ValueError) as error:
			issues.append(f"Invalid structured native fixture evidence: {error}")
	return {
		"phase": name, "ok": not issues, "issues": issues,
		"return_code": result.return_code, "duration_seconds": result.duration_seconds,
		"process_boundary_quiescent": True,
		"fixture_report": fixture_report,
	}


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--keep-logs", action="store_true")
	parser.add_argument("--rendered", action="store_true")
	args = parser.parse_args()
	process_environment = maintenance.FrozenProcessEnvironment.capture(
		maintenance.capture_maintenance_process_environment(),
	)
	keep_logs = args.keep_logs or maintenance.maintenance_logs_kept_from_environment(process_environment)
	logs = ROOT / "ai_analysis/godot_logs" / f"scene-placement-smoke-{uuid.uuid4().hex}"
	logs.mkdir(parents=True, exist_ok=False)
	log_identity = logs.lstat()
	report: dict[str, object] = {"ok": False, "phases": [], "log_directory": str(logs)}
	try:
		gf_hashes = inventory(ROOT / "addons/gf")
		fixture_hashes = inventory(ROOT / FIXTURES)
		source_payload = json.dumps(gf_hashes, sort_keys=True)
		report["gf_source_snapshot_sha256"] = hashlib.sha256(source_payload.encode("utf-8")).hexdigest()
		(logs / "gf-source-hashes.json").write_text(source_payload + "\n", encoding="utf-8")
		with maintenance.strict_process_boundary_temporary_directory(prefix="gfsp-") as temporary:
			base = Path(temporary)
			project = base / "project"
			report["temporary_project"] = str(project)
			copy_inventory(ROOT / "addons/gf", project / "addons/gf", gf_hashes)
			copy_inventory(ROOT / FIXTURES, project / FIXTURES, fixture_hashes)
			plugin_root = project / "addons/scene_placement_smoke"
			plugin_root.mkdir(parents=True)
			(plugin_root / "gf_scene_placement_editor_smoke.gd").write_bytes(path_security.read_pinned_regular_file(
				project / FIXTURES, "gf_scene_placement_editor_smoke.gd", max_bytes=MAX_FILE_BYTES,
			))
			(plugin_root / "plugin.cfg").write_bytes(path_security.read_pinned_regular_file(
				project / FIXTURES, "gf_scene_placement_editor_smoke_plugin.cfg", max_bytes=MAX_FILE_BYTES,
			))
			environment = maintenance.make_core_plugin_bootstrap_smoke_environment(
				base, "resource_preview_translation", base_environment=process_environment.values(),
			)
			environment["GF_SCENE_PLACEMENT_SMOKE_PRIVATE_ROOT"] = str(base / "resource_preview_translation/user")
			if args.rendered:
				environment["GF_SCENE_PLACEMENT_SMOKE_IMAGE_DIR"] = str(logs)
			else:
				environment.pop("GF_SCENE_PLACEMENT_SMOKE_IMAGE_DIR", None)
			executable = maintenance.resolve_godot_executable(environment=environment, cwd=ROOT)
			common = [str(executable), "--editor", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--path", str(project)]
			write_project(project, enabled=False)
			phases: list[dict[str, object]] = []
			report["phases"] = phases
			import_report = run_phase("import", [*common, "--headless", "--import", "--quit", "--log-file", str(logs / "import.godot.log")], project, environment, logs)
			phases.append(import_report)
			if import_report["ok"]:
				write_project(project, enabled=True)
				display = "--minimized" if args.rendered else "--headless"
				editor_report = run_phase("editor", [*common, display, "--log-file", str(logs / "editor.godot.log")], project, environment, logs)
				phases.append(editor_report)
				report["source_fixtures_unchanged"] = inventory(ROOT / FIXTURES) == fixture_hashes
				report["copied_fixtures_unchanged"] = all(
					hashlib.sha256(path_security.read_pinned_regular_file(
						project / FIXTURES, name, max_bytes=MAX_FILE_BYTES,
					)).hexdigest() == expected
					for name, expected in fixture_hashes.items()
				)
				report["gf_sources_unchanged"] = inventory(ROOT / "addons/gf") == gf_hashes
				report["ok"] = all(bool(report[key]) for key in ("source_fixtures_unchanged", "copied_fixtures_unchanged", "gf_sources_unchanged")) and bool(editor_report["ok"])
				if args.rendered and report["ok"]:
					image = logs / "scene_placement_preview.png"
					image_bytes = path_security.read_pinned_regular_file(logs, image.name, max_bytes=LOG_LIMIT)
					if len(image_bytes) <= 8 or image_bytes[:8] != b"\x89PNG\r\n\x1a\n":
						raise RuntimeError("Rendered placement evidence is missing or is not a bounded PNG.")
					report["rendered_preview_image"] = str(image)
	except Exception as error:
		report["error"] = f"{type(error).__name__}: {error}"
		report["exception_notes"] = list(getattr(error, "__notes__", ()))
		report["ok"] = False
	(logs / "result.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
	if report["ok"] and not keep_logs and not args.rendered:
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
