#!/usr/bin/env python3
"""Run Godot-backed code quality acceptance in the integration shard."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
import uuid
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools"))

from gf_godot_process import resolve_godot_executable
from gf_maintenance import managed_validation_directory, parallel_shard_environment
from gf_process_authority import FrozenProcessEnvironment
from gf_process_supervisor import run_supervised_process


TOOL = "addons/gf/tools/code_quality"
RUNNER = f"res://{TOOL}/cli/gf_code_quality_cli.gd"
PREFIX = "GF_CODE_QUALITY_REPORT="
FIXTURES = Path(__file__).with_name("fixtures")
FAILURE_MARKERS = (
	"SCRIPT ERROR", "Parse Error", "ERROR:", "WARNING:",
	"ObjectDB instances leaked", "Resources still in use", "reload warning",
)


def _source_hashes(root: Path) -> dict[str, str]:
	return {
		path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
		for path in root.rglob("*")
		if path.is_file() and ".godot" not in path.relative_to(root).parts
	}


def _write_config(root: Path, rules: dict[str, str]) -> None:
	(root / ".gf").mkdir(exist_ok=True)
	(root / ".gf/code_quality.json").write_text(
		json.dumps({
			"schema_version": 1,
			"include": ["res://scripts"],
			"rules": rules,
		}, ensure_ascii=False),
		encoding="utf-8", newline="\n",
	)


def run_acceptance() -> dict[str, Any]:
	"""Use fresh host bytes without importing its executable sentinel scripts."""
	cleanup_errors: list[str] = []
	cleanup = {"permitted": True}
	base = FrozenProcessEnvironment.capture(os.environ)
	deadline = time.monotonic() + 70.0
	with managed_validation_directory(
		prefix="gfcq-", cleanup_errors=cleanup_errors, windows_max_characters=40,
		cleanup_permitted=lambda: cleanup["permitted"],
	) as owned:
		host = owned / "p"
		host.mkdir()
		for source in (ROOT / TOOL).rglob("*.gd"):
			# The CLI needs no editor UI or global class import cache.
			if "editor" in source.relative_to(ROOT / TOOL).parts:
				continue
			target = host / source.relative_to(ROOT)
			target.parent.mkdir(parents=True, exist_ok=True)
			target.write_bytes(source.read_bytes())
		for dependency in ("gf_bounded_json_object_reader.gd", "gf_path_tools.gd"):
			reader = Path("addons/gf/kernel/core") / dependency
			(host / reader).parent.mkdir(parents=True, exist_ok=True)
			(host / reader).write_bytes((ROOT / reader).read_bytes())
		(host / "project.godot").write_text(
			'config_version=5\n[application]\nconfig/name="GF Code Quality CLI"\n'
			'[autoload]\nExecutionSentinel="*res://autoload.gd"\n'
			'[rendering]\nrenderer/rendering_method="gl_compatibility"\n',
			encoding="utf-8", newline="\n",
		)
		(host / "scripts").mkdir()
		(host / "autoload.gd").write_bytes((FIXTURES / "autoload_sentinel.gd.txt").read_bytes())
		(host / "scripts/target.gd").write_bytes((FIXTURES / "target_sentinel.gd.txt").read_bytes())
		clean_source = "extends RefCounted\n"
		(host / "scripts/subject.gd").write_text(clean_source, encoding="utf-8", newline="\n")
		environment, _private_root = parallel_shard_environment(
			host, owned / "u", base_environment=base.values(),
		)
		engine = resolve_godot_executable(environment=environment, cwd=host)
		logs = ROOT / "ai_analysis/godot_logs"
		logs.mkdir(parents=True, exist_ok=True)
		run_id = uuid.uuid4().hex
		cases: list[dict[str, Any]] = []

		def invoke(
			name: str, arguments: list[str], *, runner: str = RUNNER,
			project: Path = host, private: dict[str, str] = environment,
			editor_mode: bool = False,
		) -> Any:
			phase_limit = 40.0 if name == "editor-behavior" else 35.0
			remaining = min(phase_limit, deadline - time.monotonic())
			assert remaining > 0.0, "CLI acceptance exceeded its total deadline"
			log = logs / f"code-quality-cli-{run_id}-{name}.log"
			command = [engine, "--headless", "--path", str(project), "--log-file", str(log)]
			command.extend(arguments if editor_mode else ["--script", runner, "--", *arguments])
			cleanup["permitted"] = False
			result = run_supervised_process(
				command, cwd=project, environment=private, timeout_seconds=remaining,
				max_stdout_characters=4 * 1024 * 1024, max_stderr_characters=256 * 1024,
				heartbeat_callback=lambda elapsed, _pid: print(
					f"CLI {name}: {elapsed:.1f}s", file=sys.stderr, flush=True,
				),
			)
			cleanup["permitted"] = result.process_boundary_quiescent
			assert result.process_boundary_quiescent, f"{name}: process cleanup is not proven"
			assert not result.timed_out and not result.cancelled, f"{name}: interrupted"
			assert not result.stdout_truncated and not result.stderr_truncated, f"{name}: output truncated"
			assert log.is_file(), f"{name}: Godot log missing"
			output = result.stdout + result.stderr + log.read_text(encoding="utf-8")
			assert not any(marker in output for marker in FAILURE_MARKERS), f"{name}: native diagnostics:\n{output}"
			return result

		def check(name: str, exit_code: int, status: str | None, *extra: str) -> dict[str, Any]:
			before = _source_hashes(host)
			result = invoke(name, ["--root", str(host), "--json", *extra])
			assert result.return_code == exit_code, f"{name}: exit {result.return_code}, expected {exit_code}\n{result.stdout}"
			lines = [line[len(PREFIX):] for line in result.stdout.splitlines() if line.startswith(PREFIX)]
			assert len(lines) == 1, f"{name}: expected exactly one marked JSON report; stdout={result.stdout!r}"
			report = json.loads(lines[0])
			assert report["schema_version"] == 1, name
			if status is not None:
				assert report["status"] == status, f"{name}: {report}"
			assert _source_hashes(host) == before, f"{name}: source or configuration changed"
			assert not (host / "autoload_executed.flag").exists(), f"{name}: AutoLoad executed"
			assert not (host / "target_executed.flag").exists(), f"{name}: inspected script executed"
			cases.append({"name": name, "exit_code": result.return_code, "status": report.get("status", "metadata")})
			return report

		_write_config(host, {"doc_private_summary": "error"})
		clean = check("clean", 0, "clean")
		assert clean["files_checked"] == 2 and clean["complete"] is True
		(host / "scripts/subject.gd").write_text(
			clean_source + "\n\nfunc _missing_summary() -> void:\n\tpass\n",
			encoding="utf-8", newline="\n",
		)
		blocked = check("blocking-rule", 1, "violations")
		assert any(issue["rule"] == "doc_private_summary" for issue in blocked["diagnostics"])
		_write_config(host, {"doc_private_summary": "warning"})
		warning = check("warning-only", 0, "violations")
		assert warning["ok"] is True and warning["diagnostics"]
		_write_config(host, {"unknown_rule": "error"})
		check("invalid-configuration", 2, "incomplete")
		(host / ".gf/code_quality.json").unlink()
		check("unconfigured", 2, "unconfigured")
		check("unknown-argument", 2, "incomplete", "--unsupported")
		rules = check("list-rules", 0, None, "--list-rules")
		assert "doc_private_summary" in rules["rules"]
		help_report = check("help", 0, None, "--help")
		assert "--list-rules" in help_report["usage"]
		_write_config(host, {"doc_private_summary": "error"})
		(host / "scripts/subject.gd").write_text(
			'extends RefCounted\nvar broken: String = "unterminated\n',
			encoding="utf-8", newline="\n",
		)
		check("incomplete-source", 2, "incomplete")

		# Prove both sentinels are effective with an intentionally executable control.
		(host / "positive_control.gd").write_bytes((FIXTURES / "positive_control.gd.txt").read_bytes())
		control = invoke("positive-control", [], runner="res://positive_control.gd")
		assert control.return_code == 0
		assert (host / "autoload_executed.flag").is_file(), "AutoLoad sentinel control did not execute"
		assert (host / "target_executed.flag").is_file(), "target sentinel control did not execute"

		# A separate real editor proves the two UI sources and publication revocation.
		editor_host = owned / "e"
		editor_host.mkdir()
		for source in (ROOT / TOOL).rglob("*.gd"):
			target = editor_host / source.relative_to(ROOT)
			target.parent.mkdir(parents=True, exist_ok=True)
			target.write_bytes(source.read_bytes())
		for dependency in (
			"core/gf_bounded_json_object_reader.gd", "core/gf_path_tools.gd",
			"core/gf_variant_access.gd", "editor/gf_editor_workspace_ui.gd",
			"editor/gf_editor_background_request_task.gd",
		):
			relative = Path("addons/gf/kernel") / dependency
			(editor_host / relative).parent.mkdir(parents=True, exist_ok=True)
			(editor_host / relative).write_bytes((ROOT / relative).read_bytes())
		(editor_host / "scripts").mkdir()
		(editor_host / "scripts/subject.gd").write_text(clean_source, encoding="utf-8", newline="\n")
		_write_config(editor_host, {"doc_private_summary": "error"})
		plugin_root = editor_host / "addons/cq_probe"
		plugin_root.mkdir()
		(plugin_root / "plugin.gd").write_bytes((FIXTURES / "editor_probe.gd.txt").read_bytes())
		(plugin_root / "plugin.cfg").write_text(
			'[plugin]\nname="Code quality acceptance"\n'
			'description=""\nauthor="GF"\nversion="1"\nscript="plugin.gd"\n',
			encoding="utf-8", newline="\n",
		)
		editor_project = (
			'config_version=5\n[application]\nconfig/name="GF Code Quality Editor"\n'
			'[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
		)
		(editor_host / "project.godot").write_text(editor_project, encoding="utf-8", newline="\n")
		editor_environment, _editor_private_root = parallel_shard_environment(
			editor_host, owned / "v", base_environment=base.values(),
		)
		imported = invoke(
			"editor-import", ["--editor", "--import"], project=editor_host,
			private=editor_environment, editor_mode=True,
		)
		assert imported.return_code == 0
		(editor_host / "project.godot").write_text(
			editor_project + '[editor_plugins]\nenabled=PackedStringArray("res://addons/cq_probe/plugin.cfg")\n',
			encoding="utf-8", newline="\n",
		)
		editor_result = invoke(
			"editor-behavior", ["--editor"], project=editor_host,
			private=editor_environment, editor_mode=True,
		)
		ui_report_path = editor_host / "ui_result.json"
		assert ui_report_path.is_file(), "The editor probe did not publish its owned report"
		ui_report = json.loads(ui_report_path.read_text(encoding="utf-8"))
		assert editor_result.return_code == 0 and ui_report["ok"], ui_report
		assert (editor_host / "scripts/subject.gd").read_bytes() == clean_source.encode("utf-8")
		assert not (editor_host / ".gf/code_quality.json").exists(), "The tool recreated removed project configuration"

	assert not cleanup_errors, cleanup_errors
	return {
		"ok": True, "cases": cases,
		"autoload_inert": True, "target_script_inert": True,
		"source_unchanged": True, "sentinel_positive_control": True,
		"editor_buffer_and_disk_distinct": True,
		"editor_stale_cancelled_hidden_results_revoked": True,
		"editor_does_not_adopt_configuration": True,
		"process_boundaries_quiescent": True,
	}


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--json", action="store_true", help="Print the machine acceptance result.")
	args = parser.parse_args()
	try:
		result = run_acceptance()
	except (AssertionError, OSError, RuntimeError, ValueError) as error:
		result = {"ok": False, "error": str(error)}
	print(json.dumps(result, ensure_ascii=False) if args.json else result)
	return 0 if result["ok"] else 1


if __name__ == "__main__":
	raise SystemExit(main())
