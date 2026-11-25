"""从现有报告选择需要复验的动作，再按当前源码与检查目录重新构造执行命令。

报告只提供诊断和候选动作名称。调度前重新校验源码身份并展开依赖，
旧报告中的成功结果不会成为本次执行证据。
"""

from __future__ import annotations

import hashlib
import json
import math
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import gf_path_security


MAX_REPORT_BYTES = 16 * 1024 * 1024
MAX_CHECKS = 1024


@dataclass(frozen=True)
class RetrySelection:
	"""保存复验动作、原报告摘要与工作区指纹，先前通过的动作仅用于解释选择结果。"""
	workspace_fingerprint: str
	requested_checks: tuple[str, ...]
	previous_passing_checks: tuple[str, ...]
	report_sha256: str
	report_path: str

	def describe(self) -> dict[str, Any]:
		return {
			"mode": "focused_retry",
			"source_report": self.report_path,
			"source_report_sha256": self.report_sha256,
			"source_workspace_fingerprint": self.workspace_fingerprint,
			"requested_checks": list(self.requested_checks),
			"previous_passing_checks": list(self.previous_passing_checks),
			"previous_passes_are_informational": True,
			"reused_count": 0,
			"full_suite_passed": False,
			"merge_evidence": False,
		}


def report_path(root: Path, value: str) -> Path:
	"""解析 build 下的 JSON 报告路径，越界或扩展名不符时抛出 ValueError。"""
	path = Path(value)
	if not path.is_absolute():
		path = root / path
	path = gf_path_security.absolute_lexical_path(path)
	build = gf_path_security.absolute_lexical_path(root / "build")
	if not gf_path_security.path_is_inside_lexical(build, path) or path.suffix.lower() != ".json":
		raise ValueError("Retry input must be a .json report below build/.")
	return path


def _strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
	result: dict[str, Any] = {}
	for key, value in pairs:
		if key in result:
			raise ValueError("Retry report contains duplicate JSON keys.")
		result[key] = value
	return result


def _reject_nonfinite(_value: str) -> None:
	raise ValueError("Retry report contains a non-finite number.")


def _finite_float(value: str) -> float:
	parsed = float(value)
	if not math.isfinite(parsed):
		_reject_nonfinite(value)
	return parsed


def read_retry_selection(root: Path, value: str, known_actions: tuple[str, ...]) -> RetrySelection:
	"""从未通过的检查报告中选出须重新执行的动作。

	Args:
	    root: 用于定位 build 目录的仓库根。
	    value: 待读取的 JSON 报告路径。
	    known_actions: 当前目录接受的动作名称。

	Returns:
	    绑定到原报告和源指纹的复验选择。

	Raises:
	    ValueError: 报告内容矛盾、动作未知，或包含必须重新规划的发布上下文或清理失败。
	"""
	path = report_path(root, value)
	payload = gf_path_security.read_pinned_regular_file(
		root / "build", path.relative_to(root / "build").as_posix(), max_bytes=MAX_REPORT_BYTES,
	)
	try:
		report = json.loads(
			payload.decode("utf-8"), object_pairs_hook=_strict_object,
			parse_constant=_reject_nonfinite, parse_float=_finite_float,
		)
	except (UnicodeError, RecursionError, json.JSONDecodeError) as error:
		raise ValueError("Retry report is not bounded, valid UTF-8 JSON.") from error
	if not isinstance(report, dict) or report.get("ok") is not False:
		raise ValueError("Retry requires an unsuccessful check report; there is no successful Full result to import.")
	if report.get("suite") == "release" or any(report.get(key) for key in ("errors", "cleanup_errors")):
		raise ValueError("Release or orchestration/cleanup failures require a fresh validation plan.")
	fingerprint = report.get("workspace_fingerprint")
	if not isinstance(fingerprint, str) or re.fullmatch(r"[0-9a-f]{64}", fingerprint) is None or fingerprint == "0" * 64:
		raise ValueError("Retry report has no valid source fingerprint.")
	workspace = report.get("workspace")
	if workspace is not None and (not isinstance(workspace, dict) or workspace.get("fingerprint") != fingerprint):
		raise ValueError("Retry report source fingerprints disagree.")
	checks = report.get("checks")
	if (
		not isinstance(checks, list) or not 0 < len(checks) <= MAX_CHECKS
		or any(not isinstance(name, str) or name not in known_actions for name in checks)
		or len(set(checks)) != len(checks)
	):
		raise ValueError("Retry report check inventory is invalid or no longer in the Catalog.")
	if "release_metadata" in checks:
		raise ValueError("Release artifact checks require their original release context.")
	results = report.get("results")
	if not isinstance(results, list) or len(results) > len(checks):
		raise ValueError("Retry report result coverage is invalid.")
	seen: set[str] = set()
	passed: set[str] = set()
	for result in results:
		if not isinstance(result, dict):
			raise ValueError("Retry report result is invalid.")
		if result.get("cleanup_debt") or result.get("cleanup_errors") or result.get("process_boundary_quiescent") is False:
			raise ValueError("Retry cannot proceed with unresolved process or cleanup ownership.")
		name = result.get("name")
		if not isinstance(name, str) or name not in checks or name in seen:
			raise ValueError("Retry report contains duplicate, unknown or orchestration results.")
		seen.add(name)
		if type(result.get("exit_code")) is not int or type(result.get("timed_out")) is not bool:
			raise ValueError("Retry report result status is invalid.")
		if type(result.get("cancelled", False)) is not bool:
			raise ValueError("Retry report cancellation status is invalid.")
		execution = result.get("execution")
		if not isinstance(execution, str) or execution not in {"in_process", "subprocess", "blocked", "not_started"}:
			raise ValueError("Retry report contains an unrecognized execution result.")
		if result["exit_code"] == 0:
			if result["timed_out"] or result.get("cancelled") or result["execution"] in {"blocked", "not_started"}:
				raise ValueError("Retry report contains contradictory success evidence.")
			passed.add(name)
	requested = tuple(name for name in checks if name not in passed)
	if not requested:
		raise ValueError("Retry report has no failed or unexecuted checks; inspect its orchestration failure.")
	return RetrySelection(
		fingerprint, requested, tuple(name for name in checks if name in passed),
		hashlib.sha256(payload).hexdigest(), str(path),
	)
