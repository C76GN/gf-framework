"""Exercise bundled extension export policies in fresh Windows consumer projects."""
from __future__ import annotations

import argparse
from collections.abc import Iterator
from contextlib import contextmanager
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import time
import zipfile

from gf_godot_process import resolve_godot_executable
from gf_extension_export_check import REJECTED, export_policy_error, policy_verdict
from gf_path_security import path_has_reparse_component
from gf_process_supervisor import SupervisedProcessCleanupError, exception_has_cleanup_debt, run_supervised_process


ROOT = Path(__file__).resolve().parents[1]
EXTENSION_PATH = "res://addons/gf/extensions/behavior_tree/runtime/gf_behavior_tree.gd"
STRICT_ERROR = "[GFExtensionExportPlugin][extension_export_plugin.disabled_extension_referenced_error]"
DIAGNOSTIC = re.compile(r"(?m)^(?:SCRIPT ERROR|ERROR|WARNING):|Parse Error|ObjectDB instances leaked")
ENABLED_PROBE = '''extends Node

func _ready() -> void:
	var singleton: Node = get_node_or_null("/root/Gf")
	if singleton == null or singleton.get_script() != preload("res://addons/gf/kernel/core/gf.gd"):
		push_error("The GF plugin must register its runtime AutoLoad.")
		get_tree().quit(3)
		return
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 1 or ResourceLoader.load(arguments[0]) != GFBehaviorTree:
		get_tree().quit(2)
		return
	var value: StringName = GFBehaviorTree.status_to_string(GFBehaviorTree.Status.SUCCESS)
	print("GF_EXTENSION_PROBE=", value)
	get_tree().quit(0 if value == &"success" else 1)
'''
DISABLED_PROBE = '''extends Node

func _ready() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 1 or not ResourceLoader.exists("res://main.tscn"):
		get_tree().quit(2)
		return
	var available: bool = ResourceLoader.exists(arguments[0])
	var bytecode_exists: bool = FileAccess.file_exists(arguments[0].get_basename() + ".gdc")
	var remap_exists: bool = FileAccess.file_exists(arguments[0] + ".remap")
	print("GF_EXTENSION_PRESENT=", available)
	get_tree().quit(1 if available or bytecode_exists or remap_exists else 0)
'''


@contextmanager
def owned_projects(build: Path) -> Iterator[Path]:
    if path_has_reparse_component(build):
        raise RuntimeError(f"Cannot verify the extension export fixture parent: {build}")
    root = Path(tempfile.mkdtemp(prefix="extension-export-", dir=build))
    identity = root.lstat()
    cleanup = True
    try:
        yield root
    except BaseException as error:
        if exception_has_cleanup_debt(error):
            cleanup = False
            print(f"Process cleanup unconfirmed. Retained extension export fixture: {root}", file=sys.stderr)
        raise
    finally:
        if cleanup:
            if (path_has_reparse_component(root) or root.resolve() != root or root.parent != build
                    or not root.is_dir() or not os.path.samestat(identity, root.lstat())):
                raise RuntimeError(f"Directory identity changed. Retained extension export fixture: {root}")
            shutil.rmtree(root)


def run_command(argv: list[str], cwd: Path, logs: Path, label: str, deadline: float) -> tuple[int, str]:
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise RuntimeError("Extension export acceptance deadline reached.")
    result = run_supervised_process(
        argv, cwd=cwd, environment=dict(os.environ), timeout_seconds=min(remaining, 240),
        max_stdout_characters=400_000, max_stderr_characters=200_000,
    )
    output = re.sub(r"\x1b\[[0-9;]*m", "", result.stdout + "\n" + result.stderr)
    if not result.process_boundary_quiescent:
        raise SupervisedProcessCleanupError(f"{label} process cleanup unconfirmed; see {logs}")
    (logs / (label + ".log")).write_text(output, encoding="utf-8")
    if (result.timed_out or result.cancelled or result.stdout_truncated or result.stderr_truncated
            or result.return_code is None):
        raise RuntimeError(f"{label} did not finish with complete output; see {logs}")
    return result.return_code, output


def prepare_project(project: Path, enabled: bool, strong_reference: bool, archive: Path | None) -> None:
    project.mkdir()
    if archive is None:
        shutil.copytree(ROOT / "addons/gf", project / "addons/gf")
    else:
        with zipfile.ZipFile(archive) as package:
            package.extractall(project)
    selected = '"gf.behavior_tree"' if enabled else ""
    (project / "project.godot").write_text(
        'config_version=5\n[application]\nconfig/name="GF Extension Export"\nrun/main_scene="res://main.tscn"\n'
        '[editor_plugins]\nenabled=PackedStringArray("res://addons/gf/plugin.cfg")\n'
        '[gf]\nextensions/selection_mode="explicit"\n'
        f'extensions/enabled=Array[String]([{selected}])\n'
        'extensions/export_exclude_disabled=true\nextensions/export_fail_on_disabled_references=true\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
    (project / "probe.gd").write_text(ENABLED_PROBE if strong_reference else DISABLED_PROBE, encoding="utf-8")
    (project / "main.tscn").write_text(
        '[gd_scene format=3]\n[ext_resource type="Script" path="res://probe.gd" id="1"]\n'
        '[node name="Probe" type="Node"]\nscript = ExtResource("1")\n', encoding="utf-8")
    (project / "export_presets.cfg").write_text(
        '[preset.0]\nname="Windows"\nplatform="Windows Desktop"\nrunnable=true\n'
        'export_filter="all_resources"\ninclude_filter=""\nexclude_filter=""\n'
        '[preset.0.options]\nbinary_format/architecture="x86_64"\n'
        'binary_format/embed_pck=false\n', encoding="utf-8")


def run_acceptance(godot: str, archive: Path | None = None, *, deadline: float | None = None) -> dict:
    if os.name != "nt":
        raise RuntimeError("The export acceptance requires Windows x86_64 and its Godot export template.")
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    log_root = ROOT / "ai_analysis/godot_logs"
    log_root.mkdir(parents=True, exist_ok=True)
    logs = Path(tempfile.mkdtemp(prefix="extension-export-", dir=log_root))
    if deadline is None:
        deadline = time.monotonic() + 720
    results = {}
    print(f"Extension export evidence: {logs}", file=sys.stderr, flush=True)
    with owned_projects(build) as root:
        for name in ("enabled", "disabled", "strict"):
            project = root / name
            prepare_project(project, name == "enabled", name != "disabled", archive)
            artifact = root / (name + "-export")
            artifact.mkdir()
            exe = artifact / "game.exe"
            command = [godot, "--headless", "--path", str(project)]
            code, output = run_command([*command, "--import"], project, logs, name + "-import", deadline)
            if code or DIAGNOSTIC.search(output):
                raise RuntimeError(f"{name} import failed; see {logs}")
            if name == "enabled":
                # Export starts another editor. Check the project as the first editor left it.
                code, output = run_command([*command, "--", EXTENSION_PATH], project, logs,
                                           "enabled-source-run", deadline)
                if code or DIAGNOSTIC.search(output) or output.splitlines().count("GF_EXTENSION_PROBE=success") != 1:
                    raise RuntimeError(f"Source game lost its GF AutoLoad or enabled extension after editor exit; see {logs}")
            code, output = run_command([*command, "--export-release", "Windows", str(exe)],
                                       project, logs, name + "-export", deadline)
            policy_error = export_policy_error(code, output)
            result = {"export_exit": code, "policy_passed": not policy_error, "exe_created": exe.is_file(),
                      "pck_created": exe.with_suffix(".pck").is_file()}
            results[name] = result
            print(name, json.dumps(result), file=sys.stderr, flush=True)
            if name == "strict":
                if (not policy_error or STRICT_ERROR not in output or not re.search(r"(?m)^\s*res://probe\.gd:\d+\b", output)
                        or "(gf.behavior_tree)" not in output or policy_verdict(output) != REJECTED):
                    raise RuntimeError(f"Strict export did not identify the expected reference; see {logs}")
                continue
            if policy_error or DIAGNOSTIC.search(output) or not (result["exe_created"] and result["pck_created"]):
                raise RuntimeError(f"{name} export failed; see {logs}")
            code, output = run_command([str(exe), "--headless", "--", EXTENSION_PATH], artifact, logs, name + "-run", deadline)
            expected = "GF_EXTENSION_PRESENT=false" if name == "disabled" else "GF_EXTENSION_PROBE=success"
            if code or DIAGNOSTIC.search(output) or output.splitlines().count(expected) != 1:
                raise RuntimeError(f"{name} exported game did not produce {expected}; see {logs}")
            result["runtime_exit"] = code
    (logs / "acceptance.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, help="Test this locally built complete portable GF ZIP.")
    args = parser.parse_args()
    executable = resolve_godot_executable(environment=dict(os.environ), cwd=ROOT)
    print(json.dumps(run_acceptance(executable, args.archive), indent=2))
