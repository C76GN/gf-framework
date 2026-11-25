#!/usr/bin/env python3
"""将纯 Python 静态脚本的标准输出和退出状态转换为维护检查结果。"""

from __future__ import annotations

import contextlib
import io
from collections.abc import Callable
from typing import Any

import check_docs_quality
import generate_ai_api
import generate_api_reference


def api_reference_check() -> dict[str, Any]:
	"""运行 API 参考的只读比对，并将生成器的文本与退出码装入检查结果。"""
	return capture_check(lambda: generate_api_reference.main(["--check"]))


def ai_api_check() -> dict[str, Any]:
	"""核实或首次生成维护用 AI 索引，并检查 Wiki 覆盖。"""
	return capture_check(lambda: generate_ai_api.main([
		"--source",
		"addons/gf",
		"--output",
		"ai_analysis/generated_api",
		"--check-or-generate",
		"--check-wiki-coverage",
	]))


def docs_quality_check() -> dict[str, Any]:
	"""以严格模式运行文档质量检查，返回统一的维护结果。"""
	return capture_check(lambda: check_docs_quality.main(["--strict"]))


def capture_check(callback: Callable[[], int]) -> dict[str, Any]:
	"""在当前进程捕获回调的标准输出、错误输出与退出码，回调抛出的异常继续向外传播。"""
	stdout = io.StringIO()
	stderr = io.StringIO()
	with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
		exit_code = callback()
	return {
		"ok": exit_code == 0,
		"exit_code": exit_code,
		"_maintenance_stdout": stdout.getvalue(),
		"_maintenance_stderr": stderr.getvalue(),
	}
