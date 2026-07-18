"""Conservative installation and removal of project-local agent instructions."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from .constants import MANAGED_BLOCK_END, MANAGED_BLOCK_START, TEMPLATE_ROOT
from .paths import atomic_write_bytes, atomic_write_text, resolve_project_path, sha256_bytes


SUPPORTED_TARGETS = ("agents", "claude", "codex", "copilot", "cursor", "gemini")
_BLOCK_TARGETS = {
	"agents": "AGENTS.md",
	"claude": "CLAUDE.md",
	"copilot": ".github/copilot-instructions.md",
	"gemini": "GEMINI.md",
}
_CURSOR_PATH = ".cursor/rules/gf-framework.mdc"
_CODEX_ROOT = ".codex/skills/gf-project-development"


def install_agents(
	project_root: Path,
	targets: list[str],
	dry_run: bool = False,
	replace_drifted: bool = False,
) -> dict[str, Any]:
	normalized = _normalize_targets(targets, _default_install_targets(project_root))
	if "codex" in normalized and not _project_package_available(project_root):
		return {
			"ok": False,
			"dry_run": dry_run,
			"targets": normalized,
			"operations": [],
			"issues": [
				"Project-local Codex Skill installation requires gf.tool.ai_developer in the project; "
				"the standalone plugin already contributes its own Skill."
			],
		}
	drifted = set(agent_status(project_root)["drifted"])
	blocked = sorted(set(normalized).intersection(drifted))
	if blocked and not replace_drifted:
		return {
			"ok": False,
			"dry_run": dry_run,
			"targets": normalized,
			"operations": [],
			"issues": ["Refusing to replace modified managed files without explicit approval: " + ", ".join(blocked)],
		}
	operations = _install_operations(project_root, normalized)
	if dry_run:
		return {"ok": True, "dry_run": True, "targets": normalized, "operations": operations, "issues": []}
	backups: dict[Path, bytes | None] = {}
	try:
		for operation in operations:
			path = resolve_project_path(project_root, str(operation["path"]))
			backups.setdefault(path, path.read_bytes() if path.is_file() else None)
			atomic_write_text(path, str(operation["content"]))
	except (OSError, UnicodeDecodeError, ValueError) as exc:
		rollback_issues = _restore_files(backups)
		return {
			"ok": False,
			"dry_run": False,
			"targets": normalized,
			"operations": operations,
			"issues": [str(exc), *rollback_issues],
		}
	return {"ok": True, "dry_run": False, "targets": normalized, "operations": operations, "issues": []}


def uninstall_agents(project_root: Path, targets: list[str], dry_run: bool = False) -> dict[str, Any]:
	normalized = _normalize_targets(targets, _default_install_targets(project_root))
	status = agent_status(project_root)
	drifted = set(status["drifted"])
	blocked = sorted(set(normalized).intersection(drifted))
	if blocked:
		return {
			"ok": False,
			"dry_run": dry_run,
			"targets": normalized,
			"operations": [],
			"issues": ["Refusing to remove modified managed files: " + ", ".join(blocked)],
		}
	operations: list[dict[str, str]] = []
	for target in normalized:
		if target in _BLOCK_TARGETS:
			relative = _BLOCK_TARGETS[target]
			path = resolve_project_path(project_root, relative)
			if path.is_file():
				text = path.read_text(encoding="utf-8")
				updated = _remove_managed_block(text)
				operations.append({"action": "update", "target": target, "path": relative, "content": updated})
		elif target == "cursor":
			path = resolve_project_path(project_root, _CURSOR_PATH)
			if path.is_file():
				operations.append({"action": "delete", "target": target, "path": _CURSOR_PATH, "content": ""})
		elif target == "codex":
			for relative in _codex_relative_paths():
				path = resolve_project_path(project_root, relative)
				if path.is_file():
					operations.append({"action": "delete", "target": target, "path": relative, "content": ""})
	if dry_run:
		return {"ok": True, "dry_run": True, "targets": normalized, "operations": operations, "issues": []}
	backups: dict[Path, bytes | None] = {}
	try:
		for operation in operations:
			path = resolve_project_path(project_root, operation["path"])
			backups.setdefault(path, path.read_bytes() if path.is_file() else None)
			if operation["action"] == "delete":
				path.unlink()
			else:
				content = operation["content"]
				if content.strip():
					atomic_write_text(path, content)
				else:
					path.unlink()
		_prune_owned_directories(project_root)
	except (OSError, UnicodeDecodeError, ValueError) as exc:
		rollback_issues = _restore_files(backups)
		return {
			"ok": False,
			"dry_run": False,
			"targets": normalized,
			"operations": operations,
			"issues": [str(exc), *rollback_issues],
		}
	return {"ok": True, "dry_run": False, "targets": normalized, "operations": operations, "issues": []}


def agent_status(project_root: Path) -> dict[str, Any]:
	installed: list[str] = []
	drifted: list[str] = []
	for target, relative in _BLOCK_TARGETS.items():
		path = resolve_project_path(project_root, relative)
		if not path.is_file():
			continue
		try:
			text = path.read_text(encoding="utf-8")
		except (OSError, UnicodeDecodeError):
			drifted.append(target)
			continue
		state = _managed_block_state(text)
		if state == "missing":
			continue
		if state == "installed":
			installed.append(target)
		else:
			drifted.append(target)

	cursor_path = resolve_project_path(project_root, _CURSOR_PATH)
	if cursor_path.is_file():
		try:
			if cursor_path.read_text(encoding="utf-8") == _cursor_content():
				installed.append("cursor")
			else:
				drifted.append("cursor")
		except (OSError, UnicodeDecodeError):
			drifted.append("cursor")

	codex_state = _codex_status(project_root)
	if codex_state == "installed":
		installed.append("codex")
	elif codex_state == "drifted":
		drifted.append("codex")
	return {
		"ok": not drifted,
		"installed": sorted(installed),
		"drifted": sorted(drifted),
		"supported": list(SUPPORTED_TARGETS),
		"instruction_sha256": sha256_bytes(_instruction_source().encode("utf-8")),
	}


def _install_operations(project_root: Path, targets: list[str]) -> list[dict[str, str]]:
	operations: list[dict[str, str]] = []
	for target in targets:
		if target in _BLOCK_TARGETS:
			relative = _BLOCK_TARGETS[target]
			path = resolve_project_path(project_root, relative)
			existing = path.read_text(encoding="utf-8") if path.is_file() else ""
			content = _replace_managed_block(existing, _managed_block())
			operations.append({"action": "update", "target": target, "path": relative, "content": content})
		elif target == "cursor":
			operations.append({"action": "update", "target": target, "path": _CURSOR_PATH, "content": _cursor_content()})
		elif target == "codex":
			for source, relative in _codex_sources():
				operations.append({
					"action": "update",
					"target": target,
					"path": relative,
					"content": source.read_text(encoding="utf-8"),
				})
	return operations


def _instruction_source() -> str:
	return (TEMPLATE_ROOT / "agent/project_instructions.md").read_text(encoding="utf-8").strip() + "\n"


def _managed_block() -> str:
	return f"{MANAGED_BLOCK_START}\n{_instruction_source().rstrip()}\n{MANAGED_BLOCK_END}"


def _cursor_content() -> str:
	return (
		"---\n"
		"description: Verified GF Framework project development rules\n"
		"alwaysApply: true\n"
		"---\n\n"
		+ _managed_block()
		+ "\n"
	)


def _replace_managed_block(existing: str, block: str) -> str:
	start_count = existing.count(MANAGED_BLOCK_START)
	end_count = existing.count(MANAGED_BLOCK_END)
	if start_count != end_count or start_count > 1:
		raise ValueError("Agent instruction file contains malformed or duplicate GF managed blocks.")
	start = existing.find(MANAGED_BLOCK_START)
	end = existing.find(MANAGED_BLOCK_END)
	if start >= 0 and end < start:
		raise ValueError("Agent instruction file contains a malformed GF managed block.")
	if start >= 0:
		end += len(MANAGED_BLOCK_END)
		return (existing[:start] + block + existing[end:]).strip() + "\n"
	prefix = existing.rstrip()
	return (prefix + "\n\n" if prefix else "") + block + "\n"


def _remove_managed_block(existing: str) -> str:
	start_count = existing.count(MANAGED_BLOCK_START)
	end_count = existing.count(MANAGED_BLOCK_END)
	if start_count != end_count or start_count > 1:
		raise ValueError("Agent instruction file contains malformed or duplicate GF managed blocks.")
	start = existing.find(MANAGED_BLOCK_START)
	end = existing.find(MANAGED_BLOCK_END)
	if start < 0 or end < start:
		return existing
	end += len(MANAGED_BLOCK_END)
	return (existing[:start].rstrip() + "\n\n" + existing[end:].lstrip()).strip() + "\n"


def _managed_block_state(existing: str) -> str:
	start_count = existing.count(MANAGED_BLOCK_START)
	end_count = existing.count(MANAGED_BLOCK_END)
	if start_count == 0 and end_count == 0:
		return "missing"
	if start_count != 1 or end_count != 1:
		return "drifted"
	start = existing.find(MANAGED_BLOCK_START)
	end = existing.find(MANAGED_BLOCK_END)
	if end < start:
		return "drifted"
	end += len(MANAGED_BLOCK_END)
	return "installed" if existing[start:end] == _managed_block() else "drifted"


def _codex_sources() -> list[tuple[Path, str]]:
	root = TEMPLATE_ROOT / "skills/gf-project-development"
	return [
		(root / "SKILL.md", f"{_CODEX_ROOT}/SKILL.md"),
		(root / "agents/openai.yaml", f"{_CODEX_ROOT}/agents/openai.yaml"),
	]


def _codex_relative_paths() -> list[str]:
	return [relative for _source, relative in _codex_sources()]


def _codex_status(project_root: Path) -> str:
	found_count = 0
	expected_count = 0
	for source, relative in _codex_sources():
		expected_count += 1
		path = resolve_project_path(project_root, relative)
		if not path.is_file():
			continue
		found_count += 1
		try:
			if path.read_bytes() != source.read_bytes():
				return "drifted"
		except OSError:
			return "drifted"
	if found_count == 0:
		return "missing"
	return "installed" if found_count == expected_count else "drifted"


def _normalize_targets(targets: list[str], default_targets: list[str]) -> list[str]:
	values = targets or default_targets
	if "all" in values:
		values = list(SUPPORTED_TARGETS)
	normalized = sorted(set(value.strip().casefold() for value in values if value.strip()))
	unknown = sorted(set(normalized) - set(SUPPORTED_TARGETS))
	if unknown:
		raise ValueError("Unsupported agent targets: " + ", ".join(unknown))
	return normalized


def _default_install_targets(project_root: Path) -> list[str]:
	return ["agents", "codex"] if _project_package_available(project_root) else ["agents"]


def _project_package_available(project_root: Path) -> bool:
	try:
		cli_path = resolve_project_path(
			project_root,
			"addons/gf/tools/ai_developer/gf_ai_project.py",
			must_exist=True,
		)
	except ValueError:
		return False
	return cli_path.is_file()


def _restore_files(backups: dict[Path, bytes | None]) -> list[str]:
	issues: list[str] = []
	for path, content in backups.items():
		try:
			if content is None:
				if path.is_symlink():
					raise ValueError(f"Refusing to remove a linked rollback target: {path}")
				if path.is_file():
					path.unlink()
				elif path.exists():
					raise ValueError(f"Rollback target changed to a non-file path: {path}")
			else:
				atomic_write_bytes(path, content)
		except (OSError, ValueError) as exc:
			issues.append(f"Agent adapter rollback failed for {path}: {exc}")
	return issues


def _prune_owned_directories(project_root: Path) -> None:
	for relative in (
		f"{_CODEX_ROOT}/agents",
		_CODEX_ROOT,
	):
		path = resolve_project_path(project_root, relative)
		if path.is_dir() and not any(path.iterdir()):
			path.rmdir()
