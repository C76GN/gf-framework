"""Conservative installation and removal of project-local agent instructions."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .constants import MANAGED_BLOCK_END, MANAGED_BLOCK_START, TEMPLATE_ROOT
from .paths import (
	atomic_write_bytes,
	atomic_write_text,
	read_bounded_bytes,
	resolve_project_path,
	sha256_bytes,
)


SUPPORTED_TARGETS = ("agents", "claude", "codex", "copilot", "cursor", "gemini")
_BLOCK_TARGETS = {
	"agents": "AGENTS.md",
	"claude": "CLAUDE.md",
	"copilot": ".github/copilot-instructions.md",
	"gemini": "GEMINI.md",
}
_CURSOR_PATH = ".cursor/rules/gf-framework.mdc"
_CODEX_ROOT = ".codex/skills/gf-project-development"
_AGENT_TARGET_MAX_BYTES = 2 * 1024 * 1024
_AGENT_INVOCATION_MAX_BYTES = 64 * 1024 * 1024


@dataclass
class _AgentReadBudget:
	remaining_bytes: int | None = None

	def __post_init__(self) -> None:
		if self.remaining_bytes is None:
			self.remaining_bytes = _AGENT_INVOCATION_MAX_BYTES

	def read_optional(self, path: Path, relative_path: str) -> bytes | None:
		if not path.exists():
			return None
		remaining = int(self.remaining_bytes or 0)
		if remaining <= 0:
			raise ValueError("Agent target aggregate read budget is exhausted.")
		try:
			payload = read_bounded_bytes(
				path,
				min(_AGENT_TARGET_MAX_BYTES, remaining),
			)
		except ValueError:
			raise ValueError(
				f"Agent target is unsafe, unreadable, or exceeds its byte budget: {relative_path}."
			) from None
		self.remaining_bytes = remaining - len(payload)
		return payload


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
	read_budget = _AgentReadBudget()
	status = agent_status(project_root, read_budget)
	drifted = set(status["drifted"])
	blocked = sorted(set(normalized).intersection(drifted))
	if blocked and not replace_drifted:
		return {
			"ok": False,
			"dry_run": dry_run,
			"targets": normalized,
			"operations": [],
			"issues": ["Refusing to replace modified managed files without explicit approval: " + ", ".join(blocked)],
		}
	try:
		operations = _install_operations(project_root, normalized, read_budget)
	except (OSError, UnicodeDecodeError, ValueError) as exc:
		return {
			"ok": False,
			"dry_run": dry_run,
			"targets": normalized,
			"operations": [],
			"issues": [str(exc)],
		}
	if dry_run:
		return {"ok": True, "dry_run": True, "targets": normalized, "operations": operations, "issues": []}
	commit = _commit_agent_operations(project_root, operations, read_budget)
	if not commit["ok"]:
		return {
			"ok": False,
			"dry_run": False,
			"targets": normalized,
			"operations": operations,
			"issues": commit["issues"],
		}
	return {"ok": True, "dry_run": False, "targets": normalized, "operations": operations, "issues": []}


def uninstall_agents(project_root: Path, targets: list[str], dry_run: bool = False) -> dict[str, Any]:
	normalized = _normalize_targets(targets, _default_install_targets(project_root))
	read_budget = _AgentReadBudget()
	status = agent_status(project_root, read_budget)
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
	try:
		operations = _uninstall_operations(project_root, normalized, read_budget)
	except (OSError, UnicodeDecodeError, ValueError) as exc:
		return {
			"ok": False,
			"dry_run": dry_run,
			"targets": normalized,
			"operations": [],
			"issues": [str(exc)],
		}
	if dry_run:
		return {"ok": True, "dry_run": True, "targets": normalized, "operations": operations, "issues": []}
	commit = _commit_agent_operations(
		project_root,
		operations,
		read_budget,
		prune_owned_directories=True,
	)
	if not commit["ok"]:
		return {
			"ok": False,
			"dry_run": False,
			"targets": normalized,
			"operations": operations,
			"issues": commit["issues"],
		}
	return {"ok": True, "dry_run": False, "targets": normalized, "operations": operations, "issues": []}


def agent_status(
	project_root: Path,
	_read_budget: _AgentReadBudget | None = None,
) -> dict[str, Any]:
	read_budget = _read_budget or _AgentReadBudget()
	installed: list[str] = []
	drifted: list[str] = []
	issues: list[str] = []
	for target, relative in _BLOCK_TARGETS.items():
		try:
			path = resolve_project_path(project_root, relative)
			payload = read_budget.read_optional(path, relative)
			if payload is None:
				continue
			text = payload.decode("utf-8", errors="strict")
		except (OSError, UnicodeDecodeError, ValueError) as exc:
			drifted.append(target)
			issues.append(f"{target}: {exc}")
			continue
		state = _managed_block_state(text)
		if state == "missing":
			continue
		if state == "installed":
			installed.append(target)
		else:
			drifted.append(target)

	try:
		cursor_path = resolve_project_path(project_root, _CURSOR_PATH)
		cursor_payload = read_budget.read_optional(cursor_path, _CURSOR_PATH)
		if cursor_payload is not None:
			if cursor_payload.decode("utf-8", errors="strict") == _cursor_content():
				installed.append("cursor")
			else:
				drifted.append("cursor")
	except (OSError, UnicodeDecodeError, ValueError) as exc:
		drifted.append("cursor")
		issues.append(f"cursor: {exc}")

	codex_state = _codex_status(project_root, read_budget, issues)
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
		"issues": issues,
	}


def _install_operations(
	project_root: Path,
	targets: list[str],
	read_budget: _AgentReadBudget,
) -> list[dict[str, Any]]:
	operations: list[dict[str, Any]] = []
	for target in targets:
		if target in _BLOCK_TARGETS:
			relative = _BLOCK_TARGETS[target]
			path = resolve_project_path(project_root, relative)
			source = read_budget.read_optional(path, relative)
			existing = _decode_agent_target(source, relative)
			content = _replace_managed_block(existing, _managed_block())
			operations.append(_make_operation("update", target, relative, content, source))
		elif target == "cursor":
			path = resolve_project_path(project_root, _CURSOR_PATH)
			source = read_budget.read_optional(path, _CURSOR_PATH)
			operations.append(_make_operation("update", target, _CURSOR_PATH, _cursor_content(), source))
		elif target == "codex":
			for source, relative in _codex_sources():
				path = resolve_project_path(project_root, relative)
				existing = read_budget.read_optional(path, relative)
				operations.append(_make_operation(
					"update",
					target,
					relative,
					source.read_text(encoding="utf-8"),
					existing,
				))
	return operations


def _uninstall_operations(
	project_root: Path,
	targets: list[str],
	read_budget: _AgentReadBudget,
) -> list[dict[str, Any]]:
	operations: list[dict[str, Any]] = []
	for target in targets:
		if target in _BLOCK_TARGETS:
			relative = _BLOCK_TARGETS[target]
			path = resolve_project_path(project_root, relative)
			source = read_budget.read_optional(path, relative)
			if source is None:
				continue
			text = _decode_agent_target(source, relative)
			updated = _remove_managed_block(text)
			if updated == text:
				continue
			if updated:
				operations.append(_make_operation("update", target, relative, updated, source))
			else:
				operations.append(_make_operation("delete", target, relative, "", source))
		elif target == "cursor":
			path = resolve_project_path(project_root, _CURSOR_PATH)
			source = read_budget.read_optional(path, _CURSOR_PATH)
			if source is not None:
				operations.append(_make_operation("delete", target, _CURSOR_PATH, "", source))
		elif target == "codex":
			for relative in _codex_relative_paths():
				path = resolve_project_path(project_root, relative)
				source = read_budget.read_optional(path, relative)
				if source is not None:
					operations.append(_make_operation("delete", target, relative, "", source))
	return operations


def _make_operation(
	action: str,
	target: str,
	relative_path: str,
	content: str,
	source: bytes | None,
) -> dict[str, Any]:
	return {
		"action": action,
		"target": target,
		"path": relative_path,
		"content": content,
		"source_exists": source is not None,
		"source_sha256": sha256_bytes(source or b""),
	}


def _decode_agent_target(source: bytes | None, relative_path: str) -> str:
	if source is None:
		return ""
	try:
		return source.decode("utf-8", errors="strict")
	except UnicodeDecodeError:
		raise ValueError(f"Agent target is not valid UTF-8: {relative_path}.") from None


def _commit_agent_operations(
	project_root: Path,
	operations: list[dict[str, Any]],
	read_budget: _AgentReadBudget,
	*,
	prune_owned_directories: bool = False,
) -> dict[str, Any]:
	resolved: list[tuple[dict[str, Any], Path]] = []
	attempted: list[tuple[Path, bytes | None, bytes | None]] = []
	try:
		# Validate the whole reviewed source set before the first mutation.
		for operation in operations:
			relative = str(operation["path"])
			path = resolve_project_path(project_root, relative)
			current = read_budget.read_optional(path, relative)
			_assert_operation_source(operation, current)
			resolved.append((operation, path))
		# Recheck each source immediately before its mutation. The remaining
		# uncooperative parent-directory race is tracked by TOOL-AI-DEV-005.
		for operation, path in resolved:
			current = read_budget.read_optional(path, str(operation["path"]))
			_assert_operation_source(operation, current)
			if operation["action"] == "delete":
				attempted.append((path, current, None))
				path.unlink()
			else:
				planned_content = str(operation["content"])
				planned_payload = planned_content.encode("utf-8")
				attempted.append((path, current, planned_payload))
				atomic_write_text(path, planned_content)
		if prune_owned_directories:
			_prune_owned_directories(project_root)
	except (OSError, UnicodeDecodeError, ValueError) as exc:
		rollback_issues = _restore_attempted_operations(attempted)
		return {"ok": False, "issues": [str(exc), *rollback_issues]}
	return {"ok": True, "issues": []}


def _assert_operation_source(operation: dict[str, Any], current: bytes | None) -> None:
	if bool(operation.get("source_exists")) != (current is not None):
		raise ValueError(f"Agent target changed after planning: {operation.get('path', '')}.")
	if sha256_bytes(current or b"") != operation.get("source_sha256"):
		raise ValueError(f"Agent target changed after planning: {operation.get('path', '')}.")


def _restore_attempted_operations(
	attempted: list[tuple[Path, bytes | None, bytes | None]],
) -> list[str]:
	issues: list[str] = []
	for path, original, planned in reversed(attempted):
		try:
			current = (
				read_bounded_bytes(
					path,
					max(_AGENT_TARGET_MAX_BYTES, len(original or b""), len(planned or b"")),
				)
				if path.exists()
				else None
			)
			if current == original:
				continue
			if current != planned:
				raise ValueError("Target changed after the adapter mutation; refusing to overwrite it during rollback.")
			if original is None:
				path.unlink()
			else:
				atomic_write_bytes(path, original)
		except (OSError, ValueError) as exc:
			issues.append(f"Agent adapter rollback failed for {path}: {exc}")
	return issues


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
		return existing[:start] + block + existing[end:]
	return existing + ("\n\n" if existing else "") + block + "\n"


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
	prefix = existing[:start]
	suffix = existing[end:]
	if suffix == "\n":
		if not prefix:
			return ""
		if prefix.endswith("\n\n"):
			return prefix[:-2]
	return prefix + suffix


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


def _codex_status(
	project_root: Path,
	read_budget: _AgentReadBudget,
	issues: list[str],
) -> str:
	found_count = 0
	expected_count = 0
	for source, relative in _codex_sources():
		expected_count += 1
		found_count += 1
		try:
			path = resolve_project_path(project_root, relative)
			payload = read_budget.read_optional(path, relative)
			if payload is None:
				found_count -= 1
				continue
			if payload != source.read_bytes():
				return "drifted"
		except (OSError, ValueError) as exc:
			issues.append(f"codex: {exc}")
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
