"""Check one Godot export's exit code and GF extension-policy result before publication."""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys


RESULT = "[GFExtensionExportPlugin][extension_export_plugin.policy_result] "
PASSED = RESULT + "Export policy passed."
REJECTED = RESULT + "Export policy rejected."


def policy_verdict(output: str) -> str:
    """从单次导出日志提取唯一一行策略结果，缺失或重复时返回空串。"""
    plain = re.sub(r"\x1b\[[0-9;]*m", "", output)
    verdicts = [line for line in plain.splitlines() if line.startswith(RESULT)]
    return verdicts[0] if len(verdicts) == 1 else ""


def export_policy_error(exit_code: int, output: str) -> str:
    """综合 Godot 退出码和唯一策略结果，只有两者均通过时返回空串。"""
    if exit_code != 0:
        return f"Godot export exited with status {exit_code}."
    verdict = policy_verdict(output)
    if verdict == PASSED:
        return ""
    if verdict == REJECTED:
        return "GF extension export policy rejected this export. See the GF Extensions diagnostic."
    return "Expected exactly one GF extension export policy result in this export's log."


def main() -> int:
    """核对一次新导出的退出码与日志中唯一的策略判定，两者均通过才返回零。"""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path, help="Combined UTF-8 output from one fresh Godot export.")
    parser.add_argument("--godot-exit", type=int, required=True, help="Exit code of that Godot process.")
    args = parser.parse_args()
    try:
        problem = export_policy_error(args.godot_exit, args.log.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError) as error:
        problem = str(error)
    if problem:
        print(problem, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
