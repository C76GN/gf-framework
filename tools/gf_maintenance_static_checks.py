#!/usr/bin/env python3
"""In-process adapters for GF static maintenance scripts."""

from __future__ import annotations

import contextlib
import io
from collections.abc import Callable
from typing import Any

import check_docs_quality
import generate_ai_api
import generate_api_reference


def api_reference_check() -> dict[str, Any]:
	return capture_check(lambda: generate_api_reference.main(["--check"]))


def ai_api_check() -> dict[str, Any]:
	return capture_check(lambda: generate_ai_api.main([
		"--source",
		"addons/gf",
		"--output",
		"ai_analysis/generated_api",
		"--check-or-generate",
		"--check-wiki-coverage",
	]))


def docs_quality_check() -> dict[str, Any]:
	return capture_check(lambda: check_docs_quality.main(["--strict"]))


def capture_check(callback: Callable[[], int]) -> dict[str, Any]:
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
