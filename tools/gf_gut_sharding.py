#!/usr/bin/env python3
"""Deterministic GUT inventory, shard-plan, and timing observation helpers.

This module is deliberately observation-only.  It does not run Godot, select a
subset of tests, skip work, or accept historical results as validation evidence.
"""

from __future__ import annotations

from collections.abc import Iterable, Mapping
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import stat
import time
from typing import Any
import unicodedata
import xml.etree.ElementTree as ET

from gf_package_paths import portable_literal_path_identity


SCHEMA_VERSION = 1
INVENTORY_ROOT = "res://tests/gf_core"
MANIFEST_RELATIVE_PATH = "tests/gf_core/gut_shard_manifest.json"
EXECUTION_POLICY = "observe_full_suite_no_skip"
BOOTSTRAP_BALANCING_BASIS = "bootstrap_unweighted"
REQUIRED_TIMING_OBSERVATION_RUN_COUNT = 5
CONTRACT_SHARD_NAME = "gut-contracts"
LANE_SHARD_NAMES = tuple(f"gut-lane-{letter}" for letter in "abcdefgh")
SHARD_NAMES = (CONTRACT_SHARD_NAME, *LANE_SHARD_NAMES)
LIFECYCLE_CONTRACT_SCRIPT = (
	"res://tests/gf_core/support/test_gf_test_lifecycle_scope.gd"
)

MAX_INVENTORY_ENTRIES = 20_000
MAX_INVENTORY_DIRECTORIES = 4_096
MAX_INVENTORY_SCRIPTS = 4_096
INVENTORY_DEADLINE_SECONDS = 30.0
MAX_INVENTORY_SCRIPT_BYTES = 2 * 1024 * 1024
MAX_INVENTORY_TOTAL_SCRIPT_BYTES = 64 * 1024 * 1024
MAX_INVENTORY_INHERITANCE_DEPTH = 64
MAX_MANIFEST_BYTES = 2 * 1024 * 1024
MAX_JUNIT_BYTES = 32 * 1024 * 1024
MAX_JUNIT_PROVENANCE_BYTES = 32 * 1024 * 1024
MAX_JUNIT_ELEMENTS = 120_000
MAX_JUNIT_SUITES = 4_096
MAX_JUNIT_TEST_CASES = 100_000
MAX_XML_ATTRIBUTES_PER_ELEMENT = 16
MAX_XML_ATTRIBUTE_BYTES = 4_096
MAX_XML_TEXT_BYTES = 8 * 1024 * 1024
MAX_TEST_NAME_BYTES = 4_096
JUNIT_DURATION_SERIALIZATION_TOLERANCE_SECONDS = 1e-6
JUNIT_TESTCASE_DURATION_SCOPE = "testcase_only_excludes_script_lifecycle"
JUNIT_LIFECYCLE_DURATION_SCOPE = "script_lifecycle_wall_time"
JUNIT_ASSERTION_COUNT_UNKNOWN_REASON = "script_lifecycle_assertions_not_exported"
JUNIT_COMPLETENESS_CONTROLLED_RUN = "controlled_unfiltered_run_provenance"
JUNIT_COMPLETENESS_SCRIPT_NAMES_ONLY = "script_names_only"

_MANIFEST_KEYS = frozenset({
	"schema_version",
	"inventory_root",
	"execution_policy",
	"balancing_basis",
	"timing_observation_run_count",
	"required_timing_observation_run_count",
	"script_count",
	"inventory_digest",
	"shards",
})
_SHARD_KEYS = frozenset({"name", "role", "scripts"})
_ROOT_JUNIT_ATTRIBUTES = frozenset({"name", "failures", "tests"})
_SUITE_JUNIT_ATTRIBUTES = frozenset({
	"name",
	"tests",
	"failures",
	"skipped",
	"time",
})
_TEST_JUNIT_REQUIRED_ATTRIBUTES = frozenset({
	"assertions",
	"name",
	"status",
	"classname",
	"time",
})
_JUNIT_REPORT_KEYS = frozenset({
	"schema_version",
	"ok",
	"source_format",
	"junit_sha256",
	"provenance_sha256",
	"input_complete",
	"completeness_basis",
	"script_count",
	"covered_script_count",
	"test_count",
	"duration_seconds",
	"testcase_duration_seconds",
	"duration_scope",
	"status_counts",
	"failure_test_count",
	"failure_assertion_count",
	"pending_assertion_count",
	"assertion_count",
	"lifecycle_assertion_count",
	"assertion_counts_complete",
	"assertion_count_unknown_reason",
	"scripts",
})
_JUNIT_SCRIPT_REPORT_KEYS = frozenset({
	"script",
	"duration_seconds",
	"testcase_duration_seconds",
	"testcase_duration_sum_seconds",
	"testcase_duration_serialization_tolerance_seconds",
	"duration_scope",
	"test_count",
	"status_counts",
	"failure_assertion_count",
	"pending_assertion_count",
	"failure_test_count_lower_bound",
	"failure_test_count_upper_bound",
	"assertion_count",
	"lifecycle_assertion_count",
	"assertion_counts_complete",
	"assertion_count_unknown_reason",
	"tests",
})
_JUNIT_TEST_REPORT_KEYS = frozenset({
	"name",
	"duration_seconds",
	"status",
	"assertion_count",
})
_JUNIT_PROVENANCE_KEYS = frozenset({
	"schema_version",
	"nonce",
	"junit_sha256",
	"unfiltered",
	"script_count",
	"scripts",
})
_JUNIT_PROVENANCE_SCRIPT_KEYS = frozenset({
	"script",
	"inner_class",
	"was_run",
	"was_skipped",
	"duration_seconds",
	"assertion_count",
	"lifecycle_assertion_count",
	"tests",
})
_JUNIT_PROVENANCE_TEST_KEYS = frozenset({
	"name",
	"was_run",
	"status",
	"assertion_count",
	"duration_seconds",
})
_STATUS_KEYS = ("passed", "failed", "pending", "no_asserts", "skipped")
_INTEGER_RE = re.compile(r"(?:0|[1-9][0-9]*)\Z")
_FLOAT_RE = re.compile(
	r"(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?\Z"
)
_EXPECTED_XML_DECLARATION = '<?xml version="1.0" encoding="UTF-8"?>\n'
_GDSCRIPT_CLASS_NAME_RE = re.compile(
	r"^class_name[ \t]+(?P<name>[A-Za-z_][A-Za-z0-9_]*)[ \t]*\Z"
)
_GDSCRIPT_INNER_CLASS_RE = re.compile(
	r"^(?P<indent>[ \t]*)class[ \t]+(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
	r"(?:[ \t]+extends[ \t]+(?P<base>[^:]+))?[ \t]*:[ \t]*\Z"
)


class GutShardingError(ValueError):
	"""A closed, stable failure emitted by the GUT sharding helpers."""

	def __init__(self, code: str, message: str) -> None:
		super().__init__(f"{code}: {message}")
		self.code = code
		self.message = message


def canonical_json_bytes(value: Any) -> bytes:
	"""Return the canonical UTF-8 JSON representation used for digests."""

	try:
		encoded = json.dumps(
			value,
			ensure_ascii=False,
			allow_nan=False,
			separators=(",", ":"),
			sort_keys=True,
		).encode("utf-8")
	except (TypeError, ValueError) as error:
		raise GutShardingError(
			"canonical_json_invalid",
			"Value cannot be represented as finite canonical JSON.",
		) from error
	return encoded


def canonical_digest(value: Any) -> str:
	"""Return a lowercase SHA-256 digest of canonical JSON bytes."""

	return hashlib.sha256(canonical_json_bytes(value)).hexdigest()


def discover_gut_test_scripts(
	root: Path,
	*,
	deadline: float | None = None,
) -> tuple[str, ...]:
	"""Discover the stable, complete set of real GF GUT test scripts.

	Each of the two independent stability scans receives the configured scan
	budget.  An optional caller deadline remains the hard upper bound for both
	scans, so a worker cannot extend its own total execution budget.
	"""

	root = Path(root)
	tests_root = root / "tests" / "gf_core"
	first = _scan_test_inventory(
		tests_root,
		_inventory_scan_deadline(deadline),
	)
	second = _scan_test_inventory(
		tests_root,
		_inventory_scan_deadline(deadline),
	)
	if first != second:
		raise GutShardingError(
			"inventory_changed_during_scan",
			"GUT test inventory changed while it was being captured.",
		)
	return tuple(sorted(first))


def _inventory_scan_deadline(overall_deadline: float | None) -> float:
	"""Return one scan deadline without exceeding a caller-owned deadline."""

	scan_deadline = time.monotonic() + INVENTORY_DEADLINE_SECONDS
	if overall_deadline is None:
		return scan_deadline
	return min(overall_deadline, scan_deadline)


def generate_bootstrap_manifest(root: Path) -> dict[str, Any]:
	"""Generate an unweighted deterministic bootstrap manifest.

	No timing balance is claimed: non-contract scripts are ordered by their path
	digest and distributed round-robin so only the script counts are balanced.
	"""

	inventory = discover_gut_test_scripts(root)
	manifest = _bootstrap_manifest_for_inventory(inventory)
	return validate_manifest(manifest, inventory)


def validate_manifest(
	payload: Any,
	expected_inventory: Iterable[str] | None = None,
) -> dict[str, Any]:
	"""Validate and return a normalized manifest or raise GutShardingError."""

	if type(payload) is not dict:
		raise GutShardingError(
			"manifest_root_invalid",
			"GUT shard manifest root must be a JSON object.",
		)
	_require_exact_keys(payload, _MANIFEST_KEYS, "manifest_schema_invalid")
	_require_exact_integer(payload["schema_version"], "schema_version", SCHEMA_VERSION)
	_require_exact_string(payload["inventory_root"], "inventory_root", INVENTORY_ROOT)
	_require_exact_string(payload["execution_policy"], "execution_policy", EXECUTION_POLICY)
	_require_exact_string(
		payload["balancing_basis"],
		"balancing_basis",
		BOOTSTRAP_BALANCING_BASIS,
	)
	_require_exact_integer(
		payload["timing_observation_run_count"],
		"timing_observation_run_count",
		0,
	)
	_require_exact_integer(
		payload["required_timing_observation_run_count"],
		"required_timing_observation_run_count",
		REQUIRED_TIMING_OBSERVATION_RUN_COUNT,
	)
	script_count = _require_nonnegative_integer(payload["script_count"], "script_count")
	inventory_digest = payload["inventory_digest"]
	if not _is_sha256_hex(inventory_digest):
		raise GutShardingError(
			"manifest_inventory_digest_invalid",
			"inventory_digest must be a lowercase SHA-256 hex digest.",
		)

	raw_shards = payload["shards"]
	if type(raw_shards) is not list or len(raw_shards) != len(SHARD_NAMES):
		raise GutShardingError(
			"manifest_shards_invalid",
			"Manifest must contain the fixed contracts shard and eight lane shards.",
		)

	normalized_shards: list[dict[str, Any]] = []
	all_scripts: list[str] = []
	portable_identities: dict[str, str] = {}
	for index, raw_shard in enumerate(raw_shards):
		if type(raw_shard) is not dict:
			raise GutShardingError(
				"manifest_shard_invalid",
				"Every shard entry must be a JSON object.",
			)
		_require_exact_keys(raw_shard, _SHARD_KEYS, "manifest_shard_schema_invalid")
		expected_name = SHARD_NAMES[index]
		_require_exact_string(raw_shard["name"], "shard.name", expected_name)
		expected_role = "contracts" if index == 0 else "lane"
		_require_exact_string(raw_shard["role"], "shard.role", expected_role)
		raw_scripts = raw_shard["scripts"]
		if type(raw_scripts) is not list:
			raise GutShardingError(
				"manifest_shard_scripts_invalid",
				"Every shard scripts field must be an array.",
			)
		normalized_scripts: list[str] = []
		for raw_script in raw_scripts:
			script = _normalize_test_script_path(raw_script)
			portable_key = _portable_identity(script)
			if script in all_scripts:
				raise GutShardingError(
					"manifest_script_duplicate",
					"Every test script must appear in exactly one shard.",
				)
			prior = portable_identities.get(portable_key)
			if prior is not None and prior != script:
				raise GutShardingError(
					"manifest_script_identity_collision",
					"Test script paths must have unique portable identities.",
				)
			portable_identities[portable_key] = script
			normalized_scripts.append(script)
			all_scripts.append(script)
		if normalized_scripts != sorted(normalized_scripts):
			raise GutShardingError(
				"manifest_shard_order_invalid",
				"Scripts inside every shard must be sorted canonically.",
			)
		normalized_shards.append({
			"name": expected_name,
			"role": expected_role,
			"scripts": normalized_scripts,
		})

	if script_count != len(all_scripts):
		raise GutShardingError(
			"manifest_script_count_mismatch",
			"script_count must equal the number of uniquely assigned scripts.",
		)
	if len(all_scripts) > MAX_INVENTORY_SCRIPTS:
		raise GutShardingError(
			"manifest_script_budget_exceeded",
			"Manifest exceeds the supported test-script budget.",
		)

	if expected_inventory is None:
		normalized_inventory = tuple(sorted(all_scripts))
	else:
		normalized_inventory = _normalize_expected_inventory(expected_inventory)
		assigned = set(all_scripts)
		expected = set(normalized_inventory)
		if assigned != expected:
			if expected - assigned:
				raise GutShardingError(
					"manifest_script_missing",
					"Manifest is missing one or more live GUT test scripts.",
				)
			raise GutShardingError(
				"manifest_script_extra",
				"Manifest contains one or more scripts outside the live inventory.",
			)
	if LIFECYCLE_CONTRACT_SCRIPT not in normalized_inventory:
		raise GutShardingError(
			"manifest_required_contract_missing",
			"The lifecycle-scope GUT contract must remain in every shard manifest.",
		)

	if inventory_digest != canonical_digest(list(normalized_inventory)):
		raise GutShardingError(
			"manifest_inventory_digest_mismatch",
			"inventory_digest does not bind the complete sorted inventory.",
		)

	expected_assignment = _bootstrap_shards_for_inventory(normalized_inventory)
	for shard in normalized_shards:
		if shard["scripts"] != expected_assignment[shard["name"]]:
			raise GutShardingError(
				"manifest_bootstrap_assignment_mismatch",
				"Bootstrap manifest must use the canonical unweighted assignment.",
			)

	return {
		"schema_version": SCHEMA_VERSION,
		"inventory_root": INVENTORY_ROOT,
		"execution_policy": EXECUTION_POLICY,
		"balancing_basis": BOOTSTRAP_BALANCING_BASIS,
		"timing_observation_run_count": 0,
		"required_timing_observation_run_count": (
			REQUIRED_TIMING_OBSERVATION_RUN_COUNT
		),
		"script_count": len(normalized_inventory),
		"inventory_digest": canonical_digest(list(normalized_inventory)),
		"shards": normalized_shards,
	}


def load_and_validate_manifest(
	path: Path,
	*,
	root: Path,
	expected_inventory: Iterable[str] | None = None,
) -> dict[str, Any]:
	"""Read a strict manifest and bind it to the stable live inventory."""

	data = _read_stable_regular_file(Path(path), MAX_MANIFEST_BYTES, "manifest")
	payload = _load_strict_json(data, "manifest")
	if expected_inventory is None:
		expected_inventory = discover_gut_test_scripts(root)
	return validate_manifest(payload, expected_inventory)


def render_manifest(payload: Any) -> str:
	"""Render a validated manifest as stable, human-reviewable UTF-8 JSON."""

	normalized = validate_manifest(payload)
	return json.dumps(
		normalized,
		ensure_ascii=False,
		allow_nan=False,
		indent=2,
	) + "\n"


def parse_gut_junit_xml(
	path: Path,
	*,
	expected_scripts: Iterable[str] | None = None,
	expected_file_identity: tuple[int, int, int, int, int, int] | None = None,
	trusted_unfiltered_run: bool = False,
	provenance_path: Path | None = None,
	expected_provenance_identity: tuple[int, int, int, int, int, int] | None = None,
	expected_provenance_nonce: str | None = None,
) -> dict[str, Any]:
	"""Parse one bounded, controlled GUT JUnit XML observation."""
	if type(trusted_unfiltered_run) is not bool:
		raise GutShardingError(
			"junit_completeness_provenance_invalid",
			"JUnit completeness provenance must be an exact boolean.",
		)
	provenance_requested = provenance_path is not None
	if provenance_requested != (expected_provenance_nonce is not None):
		raise GutShardingError(
			"junit_provenance_contract_invalid",
			"JUnit provenance path and expected nonce must be supplied together.",
		)
	if provenance_requested and not trusted_unfiltered_run:
		raise GutShardingError(
			"junit_provenance_untrusted",
			"JUnit provenance may be accepted only for the controlled full-run path.",
		)

	data = _read_stable_regular_file(
		Path(path),
		MAX_JUNIT_BYTES,
		"junit",
		expected_file_identity=expected_file_identity,
	)
	junit_sha256 = hashlib.sha256(data).hexdigest()
	if data.startswith(b"\xef\xbb\xbf"):
		raise GutShardingError(
			"junit_utf8_bom_forbidden",
			"GUT JUnit XML must use UTF-8 without a byte-order mark.",
		)
	try:
		text = data.decode("utf-8", errors="strict")
	except UnicodeDecodeError as error:
		raise GutShardingError(
			"junit_utf8_invalid",
			"GUT JUnit XML must be strict UTF-8.",
		) from error
	if not text.startswith(_EXPECTED_XML_DECLARATION):
		raise GutShardingError(
			"junit_xml_declaration_invalid",
			"GUT JUnit XML must use the controlled exporter declaration.",
		)
	_validate_xml_stream_budget(text)
	try:
		root_element = ET.fromstring(text)
	except ET.ParseError as error:
		raise GutShardingError(
			"junit_xml_invalid",
			"GUT JUnit XML is malformed.",
		) from error
	_validate_xml_tree_budget(root_element)
	if root_element.tag != "testsuites":
		raise GutShardingError(
			"junit_root_invalid",
			"GUT JUnit XML root must be testsuites.",
		)
	_require_formatting_whitespace(
		root_element.text,
		"junit_root_text_invalid",
		"testsuites may contain only formatting whitespace around suites.",
	)
	_require_formatting_whitespace(
		root_element.tail,
		"junit_root_text_invalid",
		"testsuites may not contain trailing document text.",
	)
	_require_exact_keys(
		root_element.attrib,
		_ROOT_JUNIT_ATTRIBUTES,
		"junit_root_attributes_invalid",
	)
	if root_element.attrib["name"] != "GutTests":
		raise GutShardingError(
			"junit_root_name_invalid",
			"GUT JUnit XML root name must be GutTests.",
		)
	declared_root_tests = _parse_nonnegative_integer(
		root_element.attrib["tests"],
		"junit_root_tests_invalid",
	)
	declared_root_failures = _parse_nonnegative_integer(
		root_element.attrib["failures"],
		"junit_root_failures_invalid",
	)

	scripts: list[dict[str, Any]] = []
	seen_scripts: set[str] = set()
	seen_test_identities: set[tuple[str, str]] = set()
	for suite_element in list(root_element):
		if suite_element.tag != "testsuite":
			raise GutShardingError(
				"junit_suite_element_invalid",
				"testsuites may contain only testsuite elements.",
			)
		if len(scripts) >= MAX_JUNIT_SUITES:
			raise GutShardingError(
				"junit_suite_budget_exceeded",
				"GUT JUnit XML exceeds the suite budget.",
			)
		script = _parse_junit_suite(suite_element, seen_test_identities)
		if script["script"] in seen_scripts:
			raise GutShardingError(
				"junit_script_duplicate",
				"Every GUT script may appear in only one JUnit testsuite.",
			)
		seen_scripts.add(script["script"])
		scripts.append(script)

	scripts.sort(key=lambda item: item["script"])
	normalized_expected: tuple[str, ...] | None = None
	if expected_scripts is not None:
		normalized_expected = _normalize_expected_inventory(expected_scripts)
		expected = set(normalized_expected)
		observed = {script["script"] for script in scripts}
		if observed != expected:
			if expected - observed:
				raise GutShardingError(
					"junit_script_missing",
					"JUnit observation is missing one or more expected scripts.",
				)
			raise GutShardingError(
				"junit_script_extra",
				"JUnit observation contains one or more unexpected scripts.",
			)

	test_count = sum(script["test_count"] for script in scripts)
	status_counts = _sum_status_counts(script["status_counts"] for script in scripts)
	if test_count != declared_root_tests:
		raise GutShardingError(
			"junit_root_test_count_mismatch",
			"Root tests count does not match parsed test cases.",
		)
	provenance_sha256: str | None = None
	input_complete = False
	if provenance_path is not None:
		provenance, provenance_sha256 = _parse_gut_junit_provenance(
			Path(provenance_path),
			expected_nonce=expected_provenance_nonce,
			expected_junit_sha256=junit_sha256,
			expected_scripts=normalized_expected,
			expected_file_identity=expected_provenance_identity,
		)
		input_complete = _apply_gut_junit_provenance(scripts, provenance)
	assertion_count = sum(int(script["assertion_count"]) for script in scripts)
	lifecycle_assertion_count = sum(
		int(script["lifecycle_assertion_count"]) for script in scripts
	)
	duration_seconds = _finite_sum(
		(script["duration_seconds"] for script in scripts),
		"junit_duration_total_invalid",
		"The aggregate GUT script duration must remain finite.",
	)
	testcase_duration_seconds = _finite_sum(
		(script["testcase_duration_seconds"] for script in scripts),
		"junit_duration_total_invalid",
		"The aggregate GUT JUnit testcase duration must remain finite.",
	)
	failure_assertion_count = sum(
		int(script["failure_assertion_count"]) for script in scripts
	)
	failure_test_count_lower_bound = sum(
		int(script["failure_test_count_lower_bound"]) for script in scripts
	)
	failure_test_count_upper_bound = sum(
		int(script["failure_test_count_upper_bound"]) for script in scripts
	)
	if not (
		failure_test_count_lower_bound
		<= declared_root_failures
		<= failure_test_count_upper_bound
	):
		raise GutShardingError(
			"junit_root_failure_count_mismatch",
			"Root failures count is inconsistent with controlled GUT testcase statuses.",
		)
	pending_assertion_count = sum(
		int(script["pending_assertion_count"]) for script in scripts
	)
	return {
		"schema_version": SCHEMA_VERSION,
		"ok": True,
		"source_format": "gut_junit_xml",
		"junit_sha256": junit_sha256,
		"provenance_sha256": provenance_sha256,
		"input_complete": input_complete,
		"completeness_basis": (
			JUNIT_COMPLETENESS_CONTROLLED_RUN
			if provenance_path is not None
			else JUNIT_COMPLETENESS_SCRIPT_NAMES_ONLY
		),
		"script_count": len(scripts),
		"covered_script_count": len(scripts),
		"test_count": test_count,
		"duration_seconds": duration_seconds,
		"testcase_duration_seconds": testcase_duration_seconds,
		"duration_scope": (
			JUNIT_LIFECYCLE_DURATION_SCOPE
			if input_complete
			else JUNIT_TESTCASE_DURATION_SCOPE
		),
		"status_counts": status_counts,
		"failure_test_count": declared_root_failures,
		"failure_assertion_count": failure_assertion_count,
		"pending_assertion_count": pending_assertion_count,
		"assertion_count": assertion_count,
		"lifecycle_assertion_count": lifecycle_assertion_count,
		"assertion_counts_complete": input_complete,
		"assertion_count_unknown_reason": (
			None if input_complete else JUNIT_ASSERTION_COUNT_UNKNOWN_REASON
		),
		"scripts": scripts,
	}


def _parse_gut_junit_provenance(
	path: Path,
	*,
	expected_nonce: str | None,
	expected_junit_sha256: str,
	expected_scripts: tuple[str, ...] | None,
	expected_file_identity: tuple[int, int, int, int, int, int] | None,
) -> tuple[dict[str, Any], str]:
	if not _is_sha256_hex(expected_nonce):
		raise GutShardingError(
			"junit_provenance_nonce_invalid",
			"Controlled GUT provenance requires the expected 64-hex nonce.",
		)
	data = _read_stable_regular_file(
		path,
		MAX_JUNIT_PROVENANCE_BYTES,
		"junit_provenance",
		expected_file_identity=expected_file_identity,
	)
	payload = _load_strict_json(data, "junit_provenance")
	if type(payload) is not dict:
		raise GutShardingError(
			"junit_provenance_root_invalid",
			"Controlled GUT provenance must be a JSON object.",
		)
	_require_exact_keys(
		payload,
		_JUNIT_PROVENANCE_KEYS,
		"junit_provenance_schema_invalid",
	)
	if type(payload["schema_version"]) is not int or payload["schema_version"] != 1:
		raise GutShardingError(
			"junit_provenance_schema_invalid",
			"Controlled GUT provenance schema_version must equal 1.",
		)
	if payload["nonce"] != expected_nonce:
		raise GutShardingError(
			"junit_provenance_nonce_mismatch",
			"Controlled GUT provenance nonce does not match its invocation.",
		)
	if payload["junit_sha256"] != expected_junit_sha256:
		raise GutShardingError(
			"junit_provenance_junit_digest_mismatch",
			"Controlled GUT provenance does not bind the parsed JUnit bytes.",
		)
	if type(payload["unfiltered"]) is not bool:
		raise GutShardingError(
			"junit_provenance_value_invalid",
			"Controlled GUT provenance unfiltered must be a boolean.",
		)
	if type(payload["script_count"]) is not int or payload["script_count"] < 0:
		raise GutShardingError(
			"junit_provenance_value_invalid",
			"Controlled GUT provenance script_count must be non-negative.",
		)
	raw_scripts = payload["scripts"]
	if type(raw_scripts) is not list or len(raw_scripts) != payload["script_count"]:
		raise GutShardingError(
			"junit_provenance_count_mismatch",
			"Controlled GUT provenance scripts must match script_count.",
		)
	if len(raw_scripts) > MAX_JUNIT_SUITES:
		raise GutShardingError(
			"junit_provenance_script_budget_exceeded",
			"Controlled GUT provenance exceeds the script budget.",
		)
	scripts: list[dict[str, Any]] = []
	seen_scripts: set[str] = set()
	total_test_count = 0
	for raw_script in raw_scripts:
		script = _normalize_gut_junit_provenance_script(raw_script)
		if script["script"] in seen_scripts:
			raise GutShardingError(
				"junit_provenance_script_duplicate",
				"Controlled GUT provenance script identities must be unique.",
			)
		seen_scripts.add(script["script"])
		total_test_count += len(script["tests"])
		if total_test_count > MAX_JUNIT_TEST_CASES:
			raise GutShardingError(
				"junit_provenance_test_budget_exceeded",
				"Controlled GUT provenance exceeds the testcase budget.",
			)
		scripts.append(script)
	scripts.sort(key=lambda item: item["script"])
	if expected_scripts is None or tuple(item["script"] for item in scripts) != expected_scripts:
		raise GutShardingError(
			"junit_provenance_inventory_mismatch",
			"Controlled GUT provenance must cover the exact expected script inventory.",
		)
	return {
		"schema_version": 1,
		"nonce": expected_nonce,
		"junit_sha256": expected_junit_sha256,
		"unfiltered": payload["unfiltered"],
		"script_count": len(scripts),
		"scripts": scripts,
	}, hashlib.sha256(data).hexdigest()


def _normalize_gut_junit_provenance_script(value: Any) -> dict[str, Any]:
	if type(value) is not dict:
		raise GutShardingError(
			"junit_provenance_script_invalid",
			"Controlled GUT provenance script records must be objects.",
		)
	_require_exact_keys(
		value,
		_JUNIT_PROVENANCE_SCRIPT_KEYS,
		"junit_provenance_script_schema_invalid",
	)
	script = _normalize_test_script_path(value["script"])
	if type(value["inner_class"]) is not str:
		raise GutShardingError(
			"junit_provenance_script_invalid",
			"Controlled GUT provenance inner_class must be a string.",
		)
	for field in ("was_run", "was_skipped"):
		if type(value[field]) is not bool:
			raise GutShardingError(
				"junit_provenance_script_invalid",
				"Controlled GUT provenance execution flags must be booleans.",
			)
	duration = _normalize_json_nonnegative_float(
		value["duration_seconds"],
		"junit_provenance_script_invalid",
	)
	for field in ("assertion_count", "lifecycle_assertion_count"):
		if type(value[field]) is not int or value[field] < 0:
			raise GutShardingError(
				"junit_provenance_script_invalid",
				"Controlled GUT provenance assertion counts must be non-negative.",
			)
	raw_tests = value["tests"]
	if type(raw_tests) is not list:
		raise GutShardingError(
			"junit_provenance_script_invalid",
			"Controlled GUT provenance tests must be an array.",
		)
	tests: list[dict[str, Any]] = []
	seen_names: set[str] = set()
	for raw_test in raw_tests:
		test = _normalize_gut_junit_provenance_test(raw_test)
		if test["name"] in seen_names:
			raise GutShardingError(
				"junit_provenance_test_duplicate",
				"Controlled GUT provenance testcase names must be unique per script.",
			)
		seen_names.add(test["name"])
		tests.append(test)
	tests.sort(key=lambda item: item["name"])
	test_assertion_count = sum(test["assertion_count"] for test in tests)
	if (
		value["lifecycle_assertion_count"] > value["assertion_count"]
		or test_assertion_count + value["lifecycle_assertion_count"]
		!= value["assertion_count"]
	):
		raise GutShardingError(
			"junit_provenance_assertion_count_mismatch",
			"Controlled GUT provenance lifecycle and testcase assertions must match the script total.",
		)
	return {
		"script": script,
		"inner_class": value["inner_class"],
		"was_run": value["was_run"],
		"was_skipped": value["was_skipped"],
		"duration_seconds": duration,
		"assertion_count": value["assertion_count"],
		"lifecycle_assertion_count": value["lifecycle_assertion_count"],
		"tests": tests,
	}


def _normalize_gut_junit_provenance_test(value: Any) -> dict[str, Any]:
	if type(value) is not dict:
		raise GutShardingError(
			"junit_provenance_test_invalid",
			"Controlled GUT provenance testcase records must be objects.",
		)
	_require_exact_keys(
		value,
		_JUNIT_PROVENANCE_TEST_KEYS,
		"junit_provenance_test_schema_invalid",
	)
	name = value["name"]
	if (
		type(name) is not str
		or not name.startswith("test_")
		or len(name.encode("utf-8")) > MAX_TEST_NAME_BYTES
		or any(ord(character) < 32 for character in name)
	):
		raise GutShardingError(
			"junit_provenance_test_invalid",
			"Controlled GUT provenance testcase name is invalid.",
		)
	if type(value["was_run"]) is not bool:
		raise GutShardingError(
			"junit_provenance_test_invalid",
			"Controlled GUT provenance was_run must be a boolean.",
		)
	status_mapping = {
		"pass": "passed",
		"fail": "failed",
		"pending": "pending",
		"no asserts": "no_asserts",
		"skipped": "skipped",
		"not run": "not_run",
	}
	status = status_mapping.get(value["status"])
	if status is None:
		raise GutShardingError(
			"junit_provenance_test_invalid",
			"Controlled GUT provenance testcase status is invalid.",
		)
	if type(value["assertion_count"]) is not int or value["assertion_count"] < 0:
		raise GutShardingError(
			"junit_provenance_test_invalid",
			"Controlled GUT provenance testcase assertions must be non-negative.",
		)
	return {
		"name": name,
		"was_run": value["was_run"],
		"status": status,
		"assertion_count": value["assertion_count"],
		"duration_seconds": _normalize_json_nonnegative_float(
			value["duration_seconds"],
			"junit_provenance_test_invalid",
		),
	}


def _normalize_json_nonnegative_float(value: Any, code: str) -> float:
	if type(value) not in {int, float}:
		raise GutShardingError(code, "Expected a finite non-negative JSON number.")
	result = float(value)
	if not math.isfinite(result) or result < 0.0:
		raise GutShardingError(code, "Expected a finite non-negative JSON number.")
	return result


def _apply_gut_junit_provenance(
	scripts: list[dict[str, Any]],
	provenance: Mapping[str, Any],
) -> bool:
	provenance_by_script = {
		record["script"]: record
		for record in provenance["scripts"]
	}
	complete = provenance["unfiltered"] is True
	for script in scripts:
		record = provenance_by_script[script["script"]]
		junit_tests = {test["name"]: test for test in script["tests"]}
		provenance_tests = {test["name"]: test for test in record["tests"]}
		if (
			record["inner_class"] != ""
			or record["was_run"] is not True
			or record["was_skipped"] is not False
			or set(junit_tests) != set(provenance_tests)
		):
			complete = False
		for name in set(junit_tests) & set(provenance_tests):
			junit_test = junit_tests[name]
			provenance_test = provenance_tests[name]
			if (
				provenance_test["was_run"] is not True
				or provenance_test["status"] in {"not_run", "skipped"}
			):
				complete = False
			if (
				provenance_test["status"] != junit_test["status"]
				or provenance_test["assertion_count"] != junit_test["assertion_count"]
				or not math.isclose(
					provenance_test["duration_seconds"],
					junit_test["duration_seconds"],
					rel_tol=0.0,
					abs_tol=JUNIT_DURATION_SERIALIZATION_TOLERANCE_SECONDS,
				)
			):
				raise GutShardingError(
					"junit_provenance_test_mismatch",
					"Controlled GUT provenance does not match the JUnit testcase record.",
				)
	if not complete:
		return False
	for script in scripts:
		record = provenance_by_script[script["script"]]
		if (
			record["duration_seconds"]
			+ script["testcase_duration_serialization_tolerance_seconds"]
			< script["testcase_duration_seconds"]
		):
			raise GutShardingError(
				"junit_provenance_duration_mismatch",
				"Lifecycle-inclusive script duration cannot be shorter than its testcase sum.",
			)
		script["duration_seconds"] = record["duration_seconds"]
		script["duration_scope"] = JUNIT_LIFECYCLE_DURATION_SCOPE
		script["assertion_count"] = record["assertion_count"]
		script["lifecycle_assertion_count"] = record["lifecycle_assertion_count"]
		script["assertion_counts_complete"] = True
		script["assertion_count_unknown_reason"] = None
	return True


def build_observation_report(
	manifest: Any,
	junit_report: Mapping[str, Any],
) -> dict[str, Any]:
	"""Aggregate one full-suite JUnit observation by the bootstrap shards."""

	if type(junit_report) is not dict:
		raise GutShardingError(
			"observation_junit_invalid",
			"JUnit observation must be the parser's JSON object.",
		)
	_validate_observation_junit_report(junit_report)
	return build_observation_report_from_script_records(
		manifest,
		junit_report["scripts"],
		failure_test_count=junit_report["failure_test_count"],
	)


def build_observation_report_from_script_records(
	manifest: Any,
	scripts: Any,
	*,
	failure_test_count: Any,
) -> dict[str, Any]:
	"""Aggregate exact normalized script records by the bootstrap shards."""

	if type(scripts) is not list:
		raise GutShardingError(
			"observation_junit_invalid",
			"JUnit observation scripts must be an array.",
		)
	observed_by_path: dict[str, dict[str, Any]] = {}
	for raw_script in scripts:
		if type(raw_script) is not dict or type(raw_script.get("script")) is not str:
			raise GutShardingError(
				"observation_junit_invalid",
				"JUnit observation contains an invalid script record.",
			)
		script_path = _normalize_test_script_path(raw_script["script"])
		_validate_observation_script_record(raw_script)
		if script_path in observed_by_path:
			raise GutShardingError(
				"observation_script_duplicate",
				"JUnit observation contains duplicate script identities.",
			)
		observed_by_path[script_path] = raw_script
	normalized_manifest = validate_manifest(manifest, observed_by_path)
	if type(failure_test_count) is not int or failure_test_count < 0:
		raise GutShardingError(
			"observation_failure_test_count_invalid",
			"Observation failure-test count must be a non-negative integer.",
		)
	failure_test_count_lower_bound = sum(
		report["failure_test_count_lower_bound"]
		for report in observed_by_path.values()
	)
	failure_test_count_upper_bound = sum(
		report["failure_test_count_upper_bound"]
		for report in observed_by_path.values()
	)
	if not (
		failure_test_count_lower_bound
		<= failure_test_count
		<= failure_test_count_upper_bound
	):
		raise GutShardingError(
			"observation_failure_test_count_mismatch",
			"Observation failure-test count is outside the script-record bounds.",
		)

	shard_reports: list[dict[str, Any]] = []
	for shard in normalized_manifest["shards"]:
		script_reports = [observed_by_path[path] for path in shard["scripts"]]
		shard_duration = _finite_sum(
			(report["duration_seconds"] for report in script_reports),
			"observation_duration_total_invalid",
			"A shard lifecycle-inclusive duration must remain finite.",
		)
		shard_testcase_duration = _finite_sum(
			(report["testcase_duration_seconds"] for report in script_reports),
			"observation_duration_total_invalid",
			"A shard observation testcase duration must remain finite.",
		)
		shard_reports.append({
			"name": shard["name"],
			"role": shard["role"],
			"script_count": len(script_reports),
			"test_count": sum(report["test_count"] for report in script_reports),
			"duration_seconds": shard_duration,
			"testcase_duration_seconds": shard_testcase_duration,
			"duration_scope": JUNIT_LIFECYCLE_DURATION_SCOPE,
			"status_counts": _sum_status_counts(
				report["status_counts"] for report in script_reports
			),
			"assertion_count": sum(
				report["assertion_count"] for report in script_reports
			),
			"lifecycle_assertion_count": sum(
				report["lifecycle_assertion_count"] for report in script_reports
			),
			"assertion_counts_complete": True,
			"assertion_count_unknown_reason": None,
			"failure_assertion_count": sum(
				report["failure_assertion_count"] for report in script_reports
			),
			"pending_assertion_count": sum(
				report["pending_assertion_count"] for report in script_reports
			),
		})
	test_count = sum(int(shard["test_count"]) for shard in shard_reports)
	duration_seconds = _finite_sum(
		(shard["duration_seconds"] for shard in shard_reports),
		"observation_duration_total_invalid",
		"The full lifecycle-inclusive observation duration must remain finite.",
	)
	testcase_duration_seconds = _finite_sum(
		(shard["testcase_duration_seconds"] for shard in shard_reports),
		"observation_duration_total_invalid",
		"The full observation testcase duration must remain finite.",
	)
	status_counts = _sum_status_counts(
		shard["status_counts"] for shard in shard_reports
	)
	return {
		"schema_version": SCHEMA_VERSION,
		"observation_only": True,
		"execution_policy": EXECUTION_POLICY,
		"execution_changed": False,
		"skip_count": 0,
		"reuse_count": 0,
		"balancing_basis": normalized_manifest["balancing_basis"],
		"performance_balance_claimed": False,
		"manifest_digest": canonical_digest(normalized_manifest),
		"script_count": normalized_manifest["script_count"],
		"test_count": test_count,
		"duration_seconds": duration_seconds,
		"testcase_duration_seconds": testcase_duration_seconds,
		"duration_scope": JUNIT_LIFECYCLE_DURATION_SCOPE,
		"status_counts": status_counts,
		"failure_test_count": failure_test_count,
		"failure_assertion_count": sum(
			int(shard["failure_assertion_count"]) for shard in shard_reports
		),
		"pending_assertion_count": sum(
			int(shard["pending_assertion_count"]) for shard in shard_reports
		),
		"assertion_count": sum(
			int(shard["assertion_count"]) for shard in shard_reports
		),
		"lifecycle_assertion_count": sum(
			int(shard["lifecycle_assertion_count"]) for shard in shard_reports
		),
		"assertion_counts_complete": True,
		"assertion_count_unknown_reason": None,
		"shards": shard_reports,
	}


def _validate_observation_script_record(report: Mapping[str, Any]) -> None:
	"""Accept only the exact, already-normalized script records emitted by the parser."""
	_require_exact_keys(
		report,
		_JUNIT_SCRIPT_REPORT_KEYS,
		"observation_script_schema_invalid",
	)
	for field in (
		"test_count",
		"failure_assertion_count",
		"pending_assertion_count",
		"assertion_count",
		"lifecycle_assertion_count",
		"failure_test_count_lower_bound",
		"failure_test_count_upper_bound",
	):
		if type(report[field]) is not int or report[field] < 0:
			raise GutShardingError(
				"observation_script_value_invalid",
				"Observation script counts must be non-negative integers.",
			)
	for field in (
		"duration_seconds",
		"testcase_duration_seconds",
		"testcase_duration_sum_seconds",
		"testcase_duration_serialization_tolerance_seconds",
	):
		if type(report[field]) is not float or not math.isfinite(report[field]) or report[field] < 0.0:
			raise GutShardingError(
				"observation_script_value_invalid",
				"Observation script durations must be finite non-negative floats.",
			)
	if report["duration_scope"] != JUNIT_LIFECYCLE_DURATION_SCOPE:
		raise GutShardingError(
			"observation_script_value_invalid",
			"Controlled GUT timing must be lifecycle-inclusive.",
		)
	if report["assertion_counts_complete"] is not True:
		raise GutShardingError(
			"observation_script_value_invalid",
			"Controlled GUT assertion counts must include lifecycle assertions.",
		)
	if report["assertion_count_unknown_reason"] is not None:
		raise GutShardingError(
			"observation_script_value_invalid",
			"Complete GUT assertion counts cannot have an unknown reason.",
		)
	status_counts = report["status_counts"]
	if type(status_counts) is not dict:
		raise GutShardingError(
			"observation_script_value_invalid",
			"Observation status counts must be a closed object.",
		)
	_require_exact_keys(status_counts, frozenset(_STATUS_KEYS), "observation_status_schema_invalid")
	validated_status_counts = _sum_status_counts((status_counts,))
	if sum(validated_status_counts.values()) != report["test_count"]:
		raise GutShardingError(
			"observation_script_count_mismatch",
			"Observation status counts must equal its testcase count.",
		)
	if type(report["tests"]) is not list or len(report["tests"]) != report["test_count"]:
		raise GutShardingError(
			"observation_script_count_mismatch",
			"Observation testcase records must equal its testcase count.",
		)
	seen_names: set[str] = set()
	calculated_status_counts = {status: 0 for status in _STATUS_KEYS}
	calculated_assertion_count = 0
	calculated_duration = 0.0
	for test in report["tests"]:
		if type(test) is not dict:
			raise GutShardingError(
				"observation_test_schema_invalid",
				"Observation testcase records must be objects.",
			)
		_require_exact_keys(test, _JUNIT_TEST_REPORT_KEYS, "observation_test_schema_invalid")
		name = test["name"]
		status = test["status"]
		if (
			type(name) is not str
			or not name.startswith("test_")
			or len(name.encode("utf-8")) > MAX_TEST_NAME_BYTES
			or any(ord(character) < 32 for character in name)
			or name in seen_names
		):
			raise GutShardingError(
				"observation_test_value_invalid",
				"Observation testcase names must be unique non-empty strings.",
			)
		seen_names.add(name)
		if type(status) is not str or status not in _STATUS_KEYS:
			raise GutShardingError(
				"observation_test_value_invalid",
				"Observation testcase status is invalid.",
			)
		if type(test["assertion_count"]) is not int or test["assertion_count"] < 0:
			raise GutShardingError(
				"observation_test_value_invalid",
				"Observation testcase assertion count is invalid.",
			)
		if (
			(status in {"passed", "failed"} and test["assertion_count"] == 0)
			or (
				status in {"no_asserts", "skipped"}
				and test["assertion_count"] != 0
			)
		):
			raise GutShardingError(
				"observation_test_value_invalid",
				"Observation testcase status and assertion count are inconsistent.",
			)
		if (
			type(test["duration_seconds"]) is not float
			or not math.isfinite(test["duration_seconds"])
			or test["duration_seconds"] < 0.0
		):
			raise GutShardingError(
				"observation_test_value_invalid",
				"Observation testcase duration is invalid.",
			)
		calculated_status_counts[status] += 1
		calculated_assertion_count += test["assertion_count"]
		calculated_duration += test["duration_seconds"]
	if calculated_status_counts != status_counts:
		raise GutShardingError(
			"observation_script_count_mismatch",
			"Observation testcase statuses do not match script status counts.",
		)
	if (
		calculated_assertion_count + report["lifecycle_assertion_count"]
		!= report["assertion_count"]
	):
		raise GutShardingError(
			"observation_script_count_mismatch",
			"Observation testcase and lifecycle assertions do not match the script total.",
		)
	if not math.isclose(
		calculated_duration,
		report["testcase_duration_sum_seconds"],
		rel_tol=0.0,
		abs_tol=report["testcase_duration_serialization_tolerance_seconds"],
	):
		raise GutShardingError(
			"observation_script_count_mismatch",
			"Observation testcase durations do not match the script total.",
		)
	if not math.isclose(
		report["testcase_duration_seconds"],
		report["testcase_duration_sum_seconds"],
		rel_tol=0.0,
		abs_tol=report["testcase_duration_serialization_tolerance_seconds"],
	):
		raise GutShardingError(
			"observation_script_count_mismatch",
			"Observation exporter testcase duration does not match its testcase sum.",
		)
	if (
		report["duration_seconds"]
		+ report["testcase_duration_serialization_tolerance_seconds"]
		< report["testcase_duration_seconds"]
	):
		raise GutShardingError(
			"observation_script_count_mismatch",
			"Observation lifecycle duration cannot be shorter than its testcase sum.",
		)
	expected_duration_tolerance = max(
		1e-9,
		(report["test_count"] + 1) * JUNIT_DURATION_SERIALIZATION_TOLERANCE_SECONDS,
	)
	if (
		report["testcase_duration_serialization_tolerance_seconds"]
		!= expected_duration_tolerance
	):
		raise GutShardingError(
			"observation_script_count_mismatch",
			"Observation script duration tolerance does not match the parser contract.",
		)
	hidden_failure_candidates = sum(
		1
		for test in report["tests"]
		if test["status"] == "pending" and test["assertion_count"] > 0
	)
	expected_lower = status_counts["failed"]
	expected_upper = expected_lower + min(
		hidden_failure_candidates,
		report["failure_assertion_count"] - expected_lower,
	)
	if not (
		report["failure_assertion_count"] >= expected_lower
		and report["pending_assertion_count"] >= status_counts["pending"]
		and (
			report["pending_assertion_count"] == 0
			or status_counts["pending"] > 0
		)
		and report["failure_test_count_lower_bound"] == expected_lower
		and report["failure_test_count_upper_bound"] == expected_upper
	):
		raise GutShardingError(
			"observation_script_count_mismatch",
			"Observation failure-test bounds are inconsistent.",
		)


def _validate_observation_junit_report(report: Mapping[str, Any]) -> None:
	_require_exact_keys(report, _JUNIT_REPORT_KEYS, "observation_junit_schema_invalid")
	if (
		type(report["schema_version"]) is not int
		or report["schema_version"] != SCHEMA_VERSION
		or report["ok"] is not True
		or type(report["source_format"]) is not str
		or report["source_format"] != "gut_junit_xml"
		or not _is_sha256_hex(report["junit_sha256"])
		or not _is_sha256_hex(report["provenance_sha256"])
		or report["input_complete"] is not True
		or report["completeness_basis"] != JUNIT_COMPLETENESS_CONTROLLED_RUN
		or report["duration_scope"] != JUNIT_LIFECYCLE_DURATION_SCOPE
		or report["assertion_counts_complete"] is not True
		or report["assertion_count_unknown_reason"] is not None
	):
		raise GutShardingError(
			"observation_junit_value_invalid",
			"JUnit observation must be a complete successful parser result.",
		)
	for field in (
		"script_count",
		"covered_script_count",
		"test_count",
		"failure_test_count",
		"failure_assertion_count",
		"pending_assertion_count",
		"assertion_count",
		"lifecycle_assertion_count",
	):
		if type(report[field]) is not int or report[field] < 0:
			raise GutShardingError(
				"observation_junit_value_invalid",
				"JUnit observation counts must be non-negative integers.",
			)
	if (
		any(
			type(report[field]) is not float
			or not math.isfinite(report[field])
			or report[field] < 0.0
			for field in ("duration_seconds", "testcase_duration_seconds")
		)
	):
		raise GutShardingError(
			"observation_junit_value_invalid",
			"JUnit observation duration must be a finite non-negative float.",
		)
	if type(report["status_counts"]) is not dict:
		raise GutShardingError(
			"observation_junit_value_invalid",
			"JUnit observation status counts must be an object.",
		)
	_require_exact_keys(
		report["status_counts"],
		frozenset(_STATUS_KEYS),
		"observation_status_schema_invalid",
	)
	validated_status_counts = _sum_status_counts((report["status_counts"],))
	scripts = report["scripts"]
	if type(scripts) is not list:
		raise GutShardingError(
			"observation_junit_value_invalid",
			"JUnit observation scripts must be an array.",
		)
	for script in scripts:
		if type(script) is not dict:
			raise GutShardingError(
				"observation_script_schema_invalid",
				"JUnit observation scripts must be objects.",
			)
		_validate_observation_script_record(script)
	calculated_status_counts = _sum_status_counts(
		script["status_counts"] for script in scripts
	)
	calculated_test_count = sum(script["test_count"] for script in scripts)
	calculated_assertion_count = sum(script["assertion_count"] for script in scripts)
	calculated_failure_assertions = sum(
		script["failure_assertion_count"] for script in scripts
	)
	calculated_pending_assertions = sum(
		script["pending_assertion_count"] for script in scripts
	)
	calculated_lifecycle_assertions = sum(
		script["lifecycle_assertion_count"] for script in scripts
	)
	calculated_duration = _finite_sum(
		(script["duration_seconds"] for script in scripts),
		"observation_junit_value_invalid",
		"JUnit observation script durations must remain finite.",
	)
	calculated_testcase_duration = _finite_sum(
		(script["testcase_duration_seconds"] for script in scripts),
		"observation_junit_value_invalid",
		"JUnit observation testcase durations must remain finite.",
	)
	failure_lower = sum(
		script["failure_test_count_lower_bound"] for script in scripts
	)
	failure_upper = sum(
		script["failure_test_count_upper_bound"] for script in scripts
	)
	if (
		sum(validated_status_counts.values()) != report["test_count"]
		or report["covered_script_count"] != report["script_count"]
		or report["script_count"] != len(scripts)
		or calculated_test_count != report["test_count"]
		or calculated_status_counts != validated_status_counts
		or calculated_assertion_count != report["assertion_count"]
		or calculated_failure_assertions != report["failure_assertion_count"]
		or calculated_pending_assertions != report["pending_assertion_count"]
		or calculated_lifecycle_assertions != report["lifecycle_assertion_count"]
		or calculated_duration != report["duration_seconds"]
		or calculated_testcase_duration != report["testcase_duration_seconds"]
		or not failure_lower <= report["failure_test_count"] <= failure_upper
	):
		raise GutShardingError(
			"observation_junit_count_mismatch",
			"JUnit observation top-level counts are inconsistent.",
		)


def _bootstrap_manifest_for_inventory(inventory: Iterable[str]) -> dict[str, Any]:
	normalized_inventory = _normalize_expected_inventory(inventory)
	assignment = _bootstrap_shards_for_inventory(normalized_inventory)
	return {
		"schema_version": SCHEMA_VERSION,
		"inventory_root": INVENTORY_ROOT,
		"execution_policy": EXECUTION_POLICY,
		"balancing_basis": BOOTSTRAP_BALANCING_BASIS,
		"timing_observation_run_count": 0,
		"required_timing_observation_run_count": (
			REQUIRED_TIMING_OBSERVATION_RUN_COUNT
		),
		"script_count": len(normalized_inventory),
		"inventory_digest": canonical_digest(list(normalized_inventory)),
		"shards": [
			{
				"name": name,
				"role": "contracts" if name == CONTRACT_SHARD_NAME else "lane",
				"scripts": assignment[name],
			}
			for name in SHARD_NAMES
		],
	}


def _bootstrap_shards_for_inventory(
	inventory: Iterable[str],
) -> dict[str, list[str]]:
	scripts = tuple(sorted(inventory))
	contracts = sorted(script for script in scripts if _is_contract_script(script))
	lanes = {name: [] for name in LANE_SHARD_NAMES}
	remaining = sorted(
		(script for script in scripts if script not in set(contracts)),
		key=lambda script: (
			hashlib.sha256(script.encode("utf-8")).hexdigest(),
			script,
		),
	)
	for index, script in enumerate(remaining):
		lanes[LANE_SHARD_NAMES[index % len(LANE_SHARD_NAMES)]].append(script)
	return {
		CONTRACT_SHARD_NAME: contracts,
		**{name: sorted(lanes[name]) for name in LANE_SHARD_NAMES},
	}


def _is_contract_script(script: str) -> bool:
	return (
		script.startswith(f"{INVENTORY_ROOT}/maintenance/test_")
		or script == LIFECYCLE_CONTRACT_SCRIPT
	)


def _scan_test_inventory(
	tests_root: Path,
	deadline: float,
) -> dict[str, tuple[int, int, int, int, int, int, str]]:
	tests_root = Path(os.path.abspath(tests_root))
	root_chain = _snapshot_directory_chain(tests_root, "inventory_root_invalid")
	stack = [(tests_root, root_chain)]
	entry_count = 0
	directory_count = 0
	sources: dict[str, dict[str, Any]] = {}
	candidate_paths: list[str] = []
	portable_identities: dict[str, str] = {}
	total_script_bytes = 0
	while stack:
		_check_deadline(deadline)
		directory, directory_chain = stack.pop()
		_validate_directory_chain(directory_chain, "inventory_directory_changed")
		directory_count += 1
		if directory_count > MAX_INVENTORY_DIRECTORIES:
			raise GutShardingError(
				"inventory_directory_budget_exceeded",
				"GUT inventory exceeds the directory budget.",
			)
		entries = []
		try:
			with os.scandir(directory) as iterator:
				while True:
					_check_deadline(deadline)
					try:
						entry = next(iterator)
					except StopIteration:
						_check_deadline(deadline)
						break
					_check_deadline(deadline)
					entry_count += 1
					if entry_count > MAX_INVENTORY_ENTRIES:
						raise GutShardingError(
							"inventory_entry_budget_exceeded",
							"GUT inventory exceeds the filesystem-entry budget.",
						)
					entries.append(entry)
		except GutShardingError:
			raise
		except OSError as error:
			raise GutShardingError(
				"inventory_scan_failed",
				"GUT inventory directory cannot be enumerated.",
			) from error
		_validate_directory_chain(directory_chain, "inventory_directory_changed")
		for entry in sorted(entries, key=lambda item: item.name):
			_check_deadline(deadline)
			_validate_directory_chain(directory_chain, "inventory_directory_changed")
			try:
				entry_stat = entry.stat(follow_symlinks=False)
			except OSError as error:
				raise GutShardingError(
					"inventory_entry_unreadable",
					"GUT inventory contains an unreadable entry.",
				) from error
			_check_deadline(deadline)
			_validate_directory_chain(directory_chain, "inventory_directory_changed")
			if entry.is_symlink() or _stat_is_reparse(entry_stat):
				raise GutShardingError(
					"inventory_link_forbidden",
					"GUT inventory must not contain links or reparse points.",
				)
			if stat.S_ISDIR(entry_stat.st_mode):
				child_path = Path(entry.path)
				child_identity = _validated_directory_identity(
					child_path,
					"inventory_directory_changed",
				)
				entry_identity = _directory_identity(entry_stat)
				if (
					entry_identity[0] != 0
					or entry_identity[1] != 0
				) and child_identity != entry_identity:
					raise GutShardingError(
						"inventory_directory_changed",
						"GUT inventory directory identity changed after enumeration.",
					)
				stack.append((child_path, (*directory_chain, (child_path, child_identity))))
				continue
			if not stat.S_ISREG(entry_stat.st_mode):
				raise GutShardingError(
					"inventory_special_file_forbidden",
					"GUT inventory must contain only regular files and directories.",
				)
			entry_path = Path(entry.path)
			if entry_path.suffix != ".gd":
				continue
			relative = entry_path.relative_to(tests_root).as_posix()
			resource_path = f"{INVENTORY_ROOT}/{relative}"
			expected_file_identity = _inventory_file_identity(entry_stat)
			path_file_identity = _inventory_file_identity(entry_path.lstat())
			if not _compatible_inventory_file_identity(
				expected_file_identity,
				path_file_identity,
			):
				raise GutShardingError(
					"inventory_script_file_changed",
					"GUT test source identity changed after enumeration.",
				)
			script_bytes = _read_stable_regular_file(
				entry_path,
				MAX_INVENTORY_SCRIPT_BYTES,
				"inventory_script",
				expected_file_identity=path_file_identity,
			)
			_check_deadline(deadline)
			_validate_directory_chain(directory_chain, "inventory_directory_changed")
			total_script_bytes += len(script_bytes)
			if total_script_bytes > MAX_INVENTORY_TOTAL_SCRIPT_BYTES:
				raise GutShardingError(
					"inventory_script_total_budget_exceeded",
					"GUT inventory exceeds the total test-source byte budget.",
				)
			if script_bytes.startswith(b"\xef\xbb\xbf"):
				raise GutShardingError(
					"inventory_script_utf8_bom_forbidden",
					"GUT test scripts must use UTF-8 without a byte-order mark.",
				)
			try:
				script_text = script_bytes.decode("utf-8", errors="strict")
			except UnicodeDecodeError as error:
				raise GutShardingError(
					"inventory_script_utf8_invalid",
					"GUT test scripts must use strict UTF-8.",
				) from error
			sources[resource_path] = {
				"path": entry_path,
				"text": script_text,
				"sha256": hashlib.sha256(script_bytes).hexdigest(),
				"identity": path_file_identity,
			}
			if not _looks_like_real_test_script(resource_path):
				continue
			normalized = _normalize_test_script_path(resource_path)
			identity_key = _portable_identity(normalized)
			prior = portable_identities.get(identity_key)
			if prior is not None and prior != normalized:
				raise GutShardingError(
					"inventory_script_identity_collision",
					"GUT script paths have a portable identity collision.",
				)
			portable_identities[identity_key] = normalized
			candidate_paths.append(normalized)
			if len(candidate_paths) > MAX_INVENTORY_SCRIPTS:
				raise GutShardingError(
					"inventory_script_budget_exceeded",
					"GUT inventory exceeds the test-script budget.",
				)
		_check_deadline(deadline)
		_validate_directory_chain(directory_chain, "inventory_directory_changed")
	_validate_directory_chain(root_chain, "inventory_directory_changed")
	_check_deadline(deadline)
	class_name_index = _inventory_class_name_index(sources)
	candidates: dict[str, tuple[int, int, int, int, int, int, str]] = {}
	for resource_path in sorted(candidate_paths):
		_check_deadline(deadline)
		visited: set[str] = set()
		if not _source_inherits_gut_test(
			resource_path,
			sources,
			class_name_index,
			visited,
			(),
		):
			raise GutShardingError(
				"inventory_test_contract_invalid",
				"Every discovered test_*.gd script must inherit GutTest.",
			)
		if _source_has_inner_gut_test(
			resource_path,
			sources,
			class_name_index,
			visited,
		):
			raise GutShardingError(
				"inventory_inner_test_class_unsupported",
				"GUT shard observations do not yet support inner GutTest classes.",
			)
		source = sources[resource_path]
		final_identity = _inventory_file_identity(source["path"].lstat())
		if not _compatible_inventory_file_identity(source["identity"], final_identity):
			raise GutShardingError(
				"inventory_script_file_changed",
				"GUT test source identity changed during inheritance resolution.",
			)
		dependency_material = [
			[path, sources[path]["sha256"]]
			for path in sorted(visited)
		]
		candidates[resource_path] = (
			*final_identity,
			hashlib.sha256(canonical_json_bytes(dependency_material)).hexdigest(),
		)
	for source in sources.values():
		_check_deadline(deadline)
		try:
			final_identity = _inventory_file_identity(source["path"].lstat())
		except OSError as error:
			raise GutShardingError(
				"inventory_script_file_changed",
				"GUT source identity became unavailable during inheritance resolution.",
			) from error
		if not _compatible_inventory_file_identity(source["identity"], final_identity):
			raise GutShardingError(
				"inventory_script_file_changed",
				"GUT source identity changed during inheritance resolution.",
			)
	_validate_directory_chain(root_chain, "inventory_directory_changed")
	_check_deadline(deadline)
	return candidates


def _looks_like_real_test_script(script: str) -> bool:
	path = PurePosixPath(script.removeprefix("res://"))
	return path.name.startswith("test_") and path.suffix == ".gd"


def _inventory_class_name_index(
	sources: Mapping[str, Mapping[str, Any]],
) -> dict[str, str]:
	result: dict[str, str] = {}
	for resource_path, source in sorted(sources.items()):
		class_name = _top_level_class_name(source["text"])
		if class_name is None:
			continue
		prior = result.get(class_name)
		if prior is not None and prior != resource_path:
			raise GutShardingError(
				"inventory_class_name_duplicate",
				"GUT inheritance resolution found a duplicate class_name.",
			)
		result[class_name] = resource_path
	return result


def _source_inherits_gut_test(
	resource_path: str,
	sources: Mapping[str, Mapping[str, Any]],
	class_name_index: Mapping[str, str],
	visited: set[str],
	ancestry: tuple[str, ...],
) -> bool:
	if resource_path in ancestry:
		raise GutShardingError(
			"inventory_inheritance_cycle",
			"GUT test inheritance must be acyclic.",
		)
	if len(ancestry) >= MAX_INVENTORY_INHERITANCE_DEPTH:
		raise GutShardingError(
			"inventory_inheritance_depth_exceeded",
			"GUT test inheritance exceeds the bounded resolution depth.",
		)
	source = sources.get(resource_path)
	if source is None:
		return False
	visited.add(resource_path)
	reference = _top_level_extends_reference(source["text"])
	return _reference_inherits_gut_test(
		reference,
		resource_path,
		sources,
		class_name_index,
		visited,
		(*ancestry, resource_path),
		{},
	)


def _reference_inherits_gut_test(
	reference: tuple[str, str] | None,
	owner_path: str,
	sources: Mapping[str, Mapping[str, Any]],
	class_name_index: Mapping[str, str],
	visited: set[str],
	ancestry: tuple[str, ...],
	local_classes: Mapping[str, tuple[str, str] | None],
	local_ancestry: tuple[str, ...] = (),
) -> bool:
	if reference is None:
		return False
	kind, value = reference
	if kind == "symbol":
		if value == "GutTest":
			return True
		if value in local_classes:
			if value in local_ancestry:
				raise GutShardingError(
					"inventory_inner_inheritance_cycle",
					"Inner GUT test inheritance must be acyclic.",
				)
			if len(local_ancestry) >= MAX_INVENTORY_INHERITANCE_DEPTH:
				raise GutShardingError(
					"inventory_inheritance_depth_exceeded",
					"Inner GUT test inheritance exceeds the bounded resolution depth.",
				)
			return _reference_inherits_gut_test(
				local_classes[value],
				owner_path,
				sources,
				class_name_index,
				visited,
				ancestry,
				local_classes,
				(*local_ancestry, value),
			)
		base_path = class_name_index.get(value)
		if base_path is None:
			return False
		return _source_inherits_gut_test(
			base_path,
			sources,
			class_name_index,
			visited,
			ancestry,
		)
	if kind != "path":
		return False
	if value == "res://addons/gut/test.gd":
		return True
	base_path = _normalize_inventory_base_path(value)
	if base_path is None:
		return False
	return _source_inherits_gut_test(
		base_path,
		sources,
		class_name_index,
		visited,
		ancestry,
	)


def _source_has_inner_gut_test(
	resource_path: str,
	sources: Mapping[str, Mapping[str, Any]],
	class_name_index: Mapping[str, str],
	visited: set[str],
) -> bool:
	source = sources[resource_path]
	local_classes = _inner_class_bases(source["text"])
	for name, reference in sorted(local_classes.items()):
		if not name.startswith("Test"):
			continue
		if _reference_inherits_gut_test(
			reference,
			resource_path,
			sources,
			class_name_index,
			visited,
			(resource_path,),
			local_classes,
			(name,),
		):
			return True
	return False


def _top_level_class_name(script_text: str) -> str | None:
	masked_lines = _mask_gdscript_noncode(script_text).splitlines()
	for line in masked_lines:
		if line != line.lstrip(" \t"):
			continue
		match = _GDSCRIPT_CLASS_NAME_RE.fullmatch(line.strip())
		if match is not None:
			return match.group("name")
	return None


def _top_level_extends_reference(
	script_text: str,
) -> tuple[str, str] | None:
	raw_lines = script_text.splitlines()
	masked_lines = _mask_gdscript_noncode(script_text).splitlines()
	for raw_line, masked_line in zip(raw_lines, masked_lines, strict=True):
		if raw_line != raw_line.lstrip(" \t"):
			continue
		if not masked_line.strip().startswith("extends"):
			continue
		return _parse_extends_clause(
			_strip_gdscript_comment_preserving_strings(raw_line).strip()
		)
	return None


def _inner_class_bases(
	script_text: str,
) -> dict[str, tuple[str, str] | None]:
	raw_lines = script_text.splitlines()
	masked_lines = _mask_gdscript_noncode(script_text).splitlines()
	result: dict[str, tuple[str, str] | None] = {}
	for line_index, (raw_line, masked_line) in enumerate(
		zip(raw_lines, masked_lines, strict=True)
	):
		if raw_line != raw_line.lstrip(" \t"):
			continue
		match = _GDSCRIPT_INNER_CLASS_RE.fullmatch(masked_line.rstrip())
		if match is None:
			continue
		name = match.group("name")
		code = _strip_gdscript_comment_preserving_strings(raw_line).strip()
		raw_match = re.fullmatch(
			r"class[ \t]+[A-Za-z_][A-Za-z0-9_]*"
			r"(?:[ \t]+extends[ \t]+(?P<base>[^:]+))?[ \t]*:",
			code,
		)
		base_clause = raw_match.group("base") if raw_match is not None else None
		reference = (
			_parse_extends_clause(f"extends {base_clause}")
			if base_clause is not None
			else _block_inner_extends_reference(raw_lines, masked_lines, line_index)
		)
		result[name] = reference
	return result


def _block_inner_extends_reference(
	raw_lines: list[str],
	masked_lines: list[str],
	class_line_index: int,
) -> tuple[str, str] | None:
	for line_index in range(class_line_index + 1, len(raw_lines)):
		raw_line = raw_lines[line_index]
		masked_line = masked_lines[line_index]
		if not masked_line.strip():
			continue
		if raw_line == raw_line.lstrip(" \t"):
			return None
		if masked_line.strip().startswith("extends"):
			return _parse_extends_clause(
				_strip_gdscript_comment_preserving_strings(raw_line).strip()
			)
		return None
	return None


def _parse_extends_clause(value: str) -> tuple[str, str] | None:
	match = re.fullmatch(
		r"extends[ \t]+(?P<base>[A-Za-z_][A-Za-z0-9_.]*)[ \t]*",
		value,
	)
	if match is not None:
		return "symbol", match.group("base")
	match = re.fullmatch(
		r"extends[ \t]+(?:(?:preload|load)\([ \t]*)?"
		r"(?P<quote>['\"])(?P<path>res://[^'\"\\\r\n]+\.gd)(?P=quote)"
		r"[ \t]*(?P<close>\))?[ \t]*",
		value,
	)
	if match is None:
		return None
	has_loader = "(" in value[:value.find(match.group("quote"))]
	if has_loader != (match.group("close") is not None):
		return None
	return "path", match.group("path")


def _strip_gdscript_comment_preserving_strings(line: str) -> str:
	quote = ""
	escaped = False
	for index, character in enumerate(line):
		if escaped:
			escaped = False
			continue
		if character == "\\" and quote:
			escaped = True
			continue
		if character in {"'", '"'}:
			if not quote:
				quote = character
			elif quote == character:
				quote = ""
			continue
		if character == "#" and not quote:
			return line[:index]
	return line


def _normalize_inventory_base_path(value: str) -> str | None:
	prefix = f"{INVENTORY_ROOT}/"
	if not value.startswith(prefix):
		return None
	relative = value[len(prefix):]
	path = PurePosixPath(relative)
	if (
		not relative
		or relative.startswith("/")
		or "//" in relative
		or any(part in {"", ".", ".."} for part in path.parts)
		or path.as_posix() != relative
		or path.suffix != ".gd"
	):
		return None
	return value


def _mask_gdscript_noncode(script_text: str) -> str:
	"""Mask comments and string contents while preserving code line structure."""

	masked: list[str] = []
	index = 0
	state = "code"
	quote = ""
	while index < len(script_text):
		character = script_text[index]
		if state == "comment":
			if character in "\r\n":
				state = "code"
				masked.append(character)
			else:
				masked.append(" ")
			index += 1
			continue
		if state == "string":
			if character == "\\":
				masked.append(" ")
				index += 1
				if index < len(script_text):
					masked.append("\n" if script_text[index] == "\n" else " ")
					index += 1
				continue
			if character == quote:
				state = "code"
			masked.append("\n" if character == "\n" else " ")
			index += 1
			continue
		if state == "triple":
			if character == "\\":
				masked.append(" ")
				index += 1
				if index < len(script_text):
					masked.append("\n" if script_text[index] == "\n" else " ")
					index += 1
				continue
			if script_text.startswith(quote * 3, index):
				masked.extend("   ")
				index += 3
				state = "code"
				continue
			masked.append("\n" if character == "\n" else " ")
			index += 1
			continue
		if character == "#":
			state = "comment"
			masked.append(" ")
			index += 1
			continue
		if character in {"'", '"'}:
			quote = character
			if script_text.startswith(character * 3, index):
				state = "triple"
				masked.extend("   ")
				index += 3
			else:
				state = "string"
				masked.append(" ")
				index += 1
			continue
		masked.append(character)
		index += 1
	return "".join(masked)


def _normalize_expected_inventory(scripts: Iterable[str]) -> tuple[str, ...]:
	if isinstance(scripts, (str, bytes)):
		raise GutShardingError(
			"inventory_expected_invalid",
			"Expected inventory must be an iterable of script paths.",
		)
	normalized: list[str] = []
	seen: set[str] = set()
	portable: dict[str, str] = {}
	try:
		iterator = iter(scripts)
	except TypeError as error:
		raise GutShardingError(
			"inventory_expected_invalid",
			"Expected inventory must be an iterable of script paths.",
		) from error
	for raw_script in iterator:
		script = _normalize_test_script_path(raw_script)
		if script in seen:
			raise GutShardingError(
				"inventory_expected_duplicate",
				"Expected inventory contains a duplicate script path.",
			)
		identity_key = _portable_identity(script)
		prior = portable.get(identity_key)
		if prior is not None and prior != script:
			raise GutShardingError(
				"inventory_expected_identity_collision",
				"Expected inventory has a portable identity collision.",
			)
		seen.add(script)
		portable[identity_key] = script
		normalized.append(script)
		if len(normalized) > MAX_INVENTORY_SCRIPTS:
			raise GutShardingError(
				"inventory_expected_budget_exceeded",
				"Expected inventory exceeds the test-script budget.",
			)
	return tuple(sorted(normalized))


def _normalize_test_script_path(value: Any) -> str:
	if type(value) is not str or not value:
		raise GutShardingError(
			"test_script_path_invalid",
			"Test script path must be a non-empty string.",
		)
	if value != unicodedata.normalize("NFC", value):
		raise GutShardingError(
			"test_script_path_not_nfc",
			"Test script paths must use NFC Unicode normalization.",
		)
	if "\\" in value or any(ord(character) < 32 for character in value):
		raise GutShardingError(
			"test_script_path_invalid",
			"Test script paths must use portable forward-slash syntax.",
		)
	if not _is_unescaped_xml_attribute_safe(value.removeprefix("res://")):
		raise GutShardingError(
			"test_script_path_xml_unsafe",
			"Test script path cannot be serialized by the controlled GUT XML exporter.",
		)
	prefix = f"{INVENTORY_ROOT}/"
	if not value.startswith(prefix):
		raise GutShardingError(
			"test_script_path_outside_inventory",
			"Test script path must stay under the GF GUT inventory root.",
		)
	relative = value[len(prefix):]
	path = PurePosixPath(relative)
	if (
		not relative
		or relative.startswith("/")
		or "//" in relative
		or any(part in {"", ".", ".."} for part in path.parts)
		or path.as_posix() != relative
	):
		raise GutShardingError(
			"test_script_path_invalid",
			"Test script path must be canonical and traversal-free.",
		)
	if not portable_literal_path_identity(relative):
		raise GutShardingError(
			"test_script_path_not_portable",
			"Test script path must use portable literal path components.",
		)
	if not _looks_like_real_test_script(value):
		raise GutShardingError(
			"test_script_path_not_test",
			"Path is not a real GF GUT test script.",
		)
	return value


def _is_unescaped_xml_attribute_safe(value: str) -> bool:
	for character in value:
		codepoint = ord(character)
		if character in {'&', '<', '"'}:
			return False
		if not (
			codepoint in {0x09, 0x0A, 0x0D}
			or 0x20 <= codepoint <= 0xD7FF
			or 0xE000 <= codepoint <= 0xFFFD
			or 0x10000 <= codepoint <= 0x10FFFF
		):
			return False
	return True


def _portable_identity(path: str) -> str:
	return unicodedata.normalize("NFC", path).casefold()


def _parse_junit_suite(
	element: ET.Element,
	seen_test_identities: set[tuple[str, str]],
) -> dict[str, Any]:
	_require_formatting_whitespace(
		element.text,
		"junit_suite_text_invalid",
		"testsuite may contain only formatting whitespace around testcases.",
	)
	_require_formatting_whitespace(
		element.tail,
		"junit_suite_text_invalid",
		"testsuite may contain only formatting whitespace after the suite.",
	)
	_require_exact_keys(
		element.attrib,
		_SUITE_JUNIT_ATTRIBUTES,
		"junit_suite_attributes_invalid",
	)
	script = _normalize_junit_script_path(element.attrib["name"])
	declared_tests = _parse_nonnegative_integer(
		element.attrib["tests"],
		"junit_suite_tests_invalid",
	)
	declared_failures = _parse_nonnegative_integer(
		element.attrib["failures"],
		"junit_suite_failures_invalid",
	)
	declared_skipped = _parse_nonnegative_integer(
		element.attrib["skipped"],
		"junit_suite_skipped_invalid",
	)
	declared_duration = _parse_nonnegative_float(
		element.attrib["time"],
		"junit_suite_time_invalid",
	)
	tests: list[dict[str, Any]] = []
	for test_element in list(element):
		if test_element.tag != "testcase":
			raise GutShardingError(
				"junit_test_element_invalid",
				"testsuite may contain only testcase elements.",
			)
		if len(seen_test_identities) >= MAX_JUNIT_TEST_CASES:
			raise GutShardingError(
				"junit_test_budget_exceeded",
				"GUT JUnit XML exceeds the testcase budget.",
			)
		test = _parse_junit_test(test_element, script)
		identity = (script, test["name"])
		if identity in seen_test_identities:
			raise GutShardingError(
				"junit_test_identity_duplicate",
				"Every script and test-name identity must be unique.",
			)
		seen_test_identities.add(identity)
		tests.append(test)
	tests.sort(key=lambda item: item["name"])
	status_counts = _sum_status_counts(
		{status: int(test["status"] == status) for status in _STATUS_KEYS}
		for test in tests
	)
	hidden_failure_candidates = sum(
		1
		for test in tests
		if test["status"] == "pending" and test["assertion_count"] > 0
	)
	if declared_failures < status_counts["failed"]:
		raise GutShardingError(
			"junit_suite_failure_assertion_count_mismatch",
			"Suite failure assertions cannot be fewer than failed testcases.",
		)
	if declared_skipped < status_counts["pending"]:
		raise GutShardingError(
			"junit_suite_pending_assertion_count_mismatch",
			"Suite pending assertions cannot be fewer than pending testcases.",
		)
	if declared_skipped > 0 and status_counts["pending"] == 0:
		raise GutShardingError(
			"junit_suite_pending_assertion_count_mismatch",
			"Suite pending assertions require a pending testcase.",
		)
	if len(tests) != declared_tests:
		raise GutShardingError(
			"junit_suite_test_count_mismatch",
			"Suite tests count does not match parsed test cases.",
		)
	calculated_duration = _finite_sum(
		(test["duration_seconds"] for test in tests),
		"junit_duration_total_invalid",
		"A GUT JUnit suite testcase-duration sum must remain finite.",
	)
	duration_tolerance = max(
		1e-9,
		(len(tests) + 1) * JUNIT_DURATION_SERIALIZATION_TOLERANCE_SECONDS,
	)
	if not math.isclose(
		declared_duration,
		calculated_duration,
		rel_tol=0.0,
		abs_tol=duration_tolerance,
	):
		raise GutShardingError(
			"junit_suite_duration_mismatch",
			"Suite time does not match the sum of testcase durations.",
		)
	return {
		"script": script,
		"duration_seconds": declared_duration,
		"testcase_duration_seconds": declared_duration,
		"testcase_duration_sum_seconds": calculated_duration,
		"testcase_duration_serialization_tolerance_seconds": duration_tolerance,
		"duration_scope": JUNIT_TESTCASE_DURATION_SCOPE,
		"test_count": len(tests),
		"status_counts": status_counts,
		# GUT 9.7.1 exports per-suite failing and pending assertion counts
		# under the conventional JUnit failures/skipped attribute names.
		"failure_assertion_count": declared_failures,
		"pending_assertion_count": declared_skipped,
		"failure_test_count_lower_bound": status_counts["failed"],
		"failure_test_count_upper_bound": (
			status_counts["failed"]
			+ min(
				hidden_failure_candidates,
				declared_failures - status_counts["failed"],
			)
		),
		"assertion_count": sum(int(test["assertion_count"]) for test in tests),
		"lifecycle_assertion_count": 0,
		"assertion_counts_complete": False,
		"assertion_count_unknown_reason": JUNIT_ASSERTION_COUNT_UNKNOWN_REASON,
		"tests": tests,
	}


def _parse_junit_test(element: ET.Element, script: str) -> dict[str, Any]:
	_require_formatting_whitespace(
		element.text,
		"junit_test_text_invalid",
		"testcase may contain only formatting whitespace before its result.",
	)
	_require_formatting_whitespace(
		element.tail,
		"junit_test_text_invalid",
		"testcase may contain only formatting whitespace after the testcase.",
	)
	if frozenset(element.attrib) != _TEST_JUNIT_REQUIRED_ATTRIBUTES:
		raise GutShardingError(
			"junit_test_attributes_invalid",
			"testcase attributes do not match the controlled GUT schema.",
		)
	name = element.attrib["name"]
	if (
		not name
		or not name.startswith("test_")
		or len(name.encode("utf-8")) > MAX_TEST_NAME_BYTES
		or any(ord(character) < 32 for character in name)
	):
		raise GutShardingError(
			"junit_test_name_invalid",
			"GUT testcase name is empty, invalid, or oversized.",
		)
	classname = _normalize_junit_script_path(element.attrib["classname"])
	if classname != script:
		raise GutShardingError(
			"junit_test_classname_mismatch",
			"testcase classname must match its testsuite script.",
		)
	duration = _parse_nonnegative_float(
		element.attrib["time"],
		"junit_test_time_invalid",
	)
	assertion_count = _parse_nonnegative_integer(
		element.attrib["assertions"],
		"junit_test_assertions_invalid",
	)
	raw_status = element.attrib["status"]
	status_mapping = {
		"pass": "passed",
		"fail": "failed",
		"pending": "pending",
		"no asserts": "no_asserts",
		"skipped": "skipped",
	}
	if raw_status not in status_mapping:
		raise GutShardingError(
			"junit_test_status_invalid",
			"testcase status is not emitted by the controlled GUT exporter.",
		)
	status = status_mapping[raw_status]
	if (
		(status in {"passed", "failed"} and assertion_count == 0)
		or (status in {"no_asserts", "skipped"} and assertion_count != 0)
	):
		raise GutShardingError(
			"junit_test_assertion_status_mismatch",
			"testcase assertion count does not match its controlled GUT status.",
		)
	children = list(element)
	if len(children) > 1:
		raise GutShardingError(
			"junit_test_result_invalid",
			"testcase may contain at most one failure or skipped result.",
		)
	expected_child = None
	if status == "failed":
		expected_child = "failure"
	elif status == "pending":
		expected_child = "skipped"
	if expected_child is None and children:
		raise GutShardingError(
			"junit_test_result_mismatch",
			"This testcase status must not contain a failure or skipped result.",
		)
	if expected_child is not None:
		if len(children) != 1 or children[0].tag != expected_child:
			raise GutShardingError(
				"junit_test_result_mismatch",
				"testcase status and result element must agree.",
			)
		_require_exact_keys(
			children[0].attrib,
			frozenset({"message"}),
			"junit_test_result_attributes_invalid",
		)
		expected_message = "failed" if status == "failed" else "pending"
		if children[0].attrib["message"] != expected_message:
			raise GutShardingError(
				"junit_test_result_message_invalid",
				"testcase result message does not match the controlled GUT exporter.",
			)
		if list(children[0]):
			raise GutShardingError(
				"junit_test_result_nested_invalid",
				"failure and skipped results must not contain nested XML.",
			)
		_require_formatting_whitespace(
			children[0].tail,
			"junit_test_text_invalid",
			"testcase result elements may contain only formatting whitespace after the result.",
		)
	return {
		"name": name,
		"duration_seconds": duration,
		"status": status,
		"assertion_count": assertion_count,
	}


def _require_formatting_whitespace(value: str | None, code: str, message: str) -> None:
	if value is not None and value.strip(" \t\r\n"):
		raise GutShardingError(code, message)


def _normalize_junit_script_path(value: Any) -> str:
	if type(value) is not str:
		raise GutShardingError(
			"junit_script_path_invalid",
			"JUnit script identity must be a string.",
		)
	path = value if value.startswith("res://") else f"res://{value}"
	return _normalize_test_script_path(path)


def _sum_status_counts(
	counts: Iterable[Mapping[str, Any]],
) -> dict[str, int]:
	total = {status: 0 for status in _STATUS_KEYS}
	for item in counts:
		for status in _STATUS_KEYS:
			value = item.get(status)
			if type(value) is not int or value < 0:
				raise GutShardingError(
					"status_count_invalid",
					"Status counts must be non-negative integers.",
				)
			total[status] += value
	return total


def _parse_nonnegative_integer(value: Any, code: str) -> int:
	if type(value) is not str or _INTEGER_RE.fullmatch(value) is None:
		raise GutShardingError(code, "Expected a canonical non-negative integer.")
	return int(value)


def _parse_nonnegative_float(value: Any, code: str) -> float:
	if type(value) is not str or _FLOAT_RE.fullmatch(value) is None:
		raise GutShardingError(code, "Expected a finite non-negative number.")
	parsed = float(value)
	if not math.isfinite(parsed) or parsed < 0.0:
		raise GutShardingError(code, "Expected a finite non-negative number.")
	return parsed


def _finite_sum(values: Iterable[Any], code: str, message: str) -> float:
	total = 0.0
	for value in values:
		try:
			total += float(value)
		except (TypeError, ValueError, OverflowError) as error:
			raise GutShardingError(code, message) from error
		if not math.isfinite(total) or total < 0.0:
			raise GutShardingError(code, message)
	return total


def _validate_xml_tree_budget(root: ET.Element) -> None:
	element_count = 0
	text_bytes = 0
	for element in root.iter():
		element_count += 1
		if element_count > MAX_JUNIT_ELEMENTS:
			raise GutShardingError(
				"junit_element_budget_exceeded",
				"GUT JUnit XML exceeds the element budget.",
			)
		if type(element.tag) is not str or "}" in element.tag or ":" in element.tag:
			raise GutShardingError(
				"junit_namespace_forbidden",
				"XML namespaces and non-element nodes are forbidden.",
			)
		if len(element.attrib) > MAX_XML_ATTRIBUTES_PER_ELEMENT:
			raise GutShardingError(
				"junit_attribute_budget_exceeded",
				"An XML element exceeds the attribute-count budget.",
			)
		for key, value in element.attrib.items():
			if (
				len(key.encode("utf-8")) > MAX_XML_ATTRIBUTE_BYTES
				or len(value.encode("utf-8")) > MAX_XML_ATTRIBUTE_BYTES
			):
				raise GutShardingError(
					"junit_attribute_budget_exceeded",
					"An XML attribute exceeds the text budget.",
				)
		for value in (element.text, element.tail):
			if value:
				text_bytes += len(value.encode("utf-8"))
				if text_bytes > MAX_XML_TEXT_BYTES:
					raise GutShardingError(
						"junit_text_budget_exceeded",
						"GUT JUnit XML exceeds the text budget.",
					)


class _XmlBudgetTarget:
	"""Validate bounded XML tokens without allocating an Element tree."""

	def __init__(self) -> None:
		self.element_count = 0
		self.text_bytes = 0

	def start(self, tag: str, attributes: dict[str, str]) -> None:
		self.element_count += 1
		if self.element_count > MAX_JUNIT_ELEMENTS:
			raise GutShardingError(
				"junit_element_budget_exceeded",
				"GUT JUnit XML exceeds the element budget.",
			)
		if type(tag) is not str or "}" in tag or ":" in tag:
			raise GutShardingError(
				"junit_namespace_forbidden",
				"XML namespaces and non-element nodes are forbidden.",
			)
		if len(attributes) > MAX_XML_ATTRIBUTES_PER_ELEMENT:
			raise GutShardingError(
				"junit_attribute_budget_exceeded",
				"An XML element exceeds the attribute-count budget.",
			)
		for key, value in attributes.items():
			if (
				len(key.encode("utf-8")) > MAX_XML_ATTRIBUTE_BYTES
				or len(value.encode("utf-8")) > MAX_XML_ATTRIBUTE_BYTES
			):
				raise GutShardingError(
					"junit_attribute_budget_exceeded",
					"An XML attribute exceeds the text budget.",
				)

	def end(self, _tag: str) -> None:
		return None

	def data(self, value: str) -> None:
		self.text_bytes += len(value.encode("utf-8"))
		if self.text_bytes > MAX_XML_TEXT_BYTES:
			raise GutShardingError(
				"junit_text_budget_exceeded",
				"GUT JUnit XML exceeds the text budget.",
			)

	def doctype(self, _name: str, _pubid: str | None, _system: str | None) -> None:
		raise GutShardingError(
			"junit_xml_declaration_forbidden",
			"DTD and entity declarations are forbidden in GUT JUnit XML.",
		)

	def pi(self, _target: str, _data: str) -> None:
		raise GutShardingError(
			"junit_xml_processing_instruction_forbidden",
			"XML processing instructions are forbidden.",
		)

	def comment(self, _text: str) -> None:
		raise GutShardingError(
			"junit_xml_comment_forbidden",
			"XML comments are not emitted by the controlled GUT exporter.",
		)

	def start_ns(self, _prefix: str | None, _uri: str) -> None:
		raise GutShardingError(
			"junit_namespace_forbidden",
			"XML namespaces are not emitted by the controlled GUT exporter.",
		)

	def close(self) -> None:
		return None


def _validate_xml_stream_budget(text: str) -> None:
	"""Reject oversized XML structures before the full tree is allocated."""
	parser = ET.XMLParser(target=_XmlBudgetTarget())
	try:
		for offset in range(0, len(text), 64 * 1024):
			parser.feed(text[offset:offset + 64 * 1024])
		parser.close()
	except GutShardingError:
		raise
	except ET.ParseError as error:
		raise GutShardingError(
			"junit_xml_invalid",
			"GUT JUnit XML is malformed.",
		) from error


def _load_strict_json(data: bytes, label: str) -> Any:
	try:
		text = data.decode("utf-8", errors="strict")
	except UnicodeDecodeError as error:
		raise GutShardingError(
			f"{label}_utf8_invalid",
			f"{label.capitalize()} must be strict UTF-8.",
		) from error
	if text.startswith("\ufeff"):
		raise GutShardingError(
			f"{label}_utf8_bom_forbidden",
			f"{label.capitalize()} must not contain a UTF-8 BOM.",
		)

	def reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
		result: dict[str, Any] = {}
		for key, value in pairs:
			if key in result:
				raise GutShardingError(
					f"{label}_json_duplicate_key",
					f"{label.capitalize()} JSON keys must be unique.",
				)
			result[key] = value
		return result

	def reject_constant(_value: str) -> Any:
		raise GutShardingError(
			f"{label}_json_nonfinite",
			f"{label.capitalize()} JSON numbers must be finite.",
		)

	try:
		return json.loads(
			text,
			object_pairs_hook=reject_duplicates,
			parse_constant=reject_constant,
		)
	except GutShardingError:
		raise
	except (json.JSONDecodeError, RecursionError) as error:
		raise GutShardingError(
			f"{label}_json_invalid",
			f"{label.capitalize()} must be valid bounded JSON.",
		) from error


def _read_stable_regular_file(
	path: Path,
	max_bytes: int,
	label: str,
	*,
	expected_file_identity: tuple[int, int, int, int, int, int] | None = None,
) -> bytes:
	try:
		before = path.lstat()
	except OSError as error:
		raise GutShardingError(
			f"{label}_file_unreadable",
			f"{label.capitalize()} input cannot be inspected.",
		) from error
	if (
		not stat.S_ISREG(before.st_mode)
		or _stat_is_reparse(before)
		or path.is_symlink()
	):
		raise GutShardingError(
			f"{label}_file_not_regular",
			f"{label.capitalize()} input must be a regular non-link file.",
		)
	if (
		expected_file_identity is not None
		and stable_file_identity(before) != expected_file_identity
	):
		raise GutShardingError(
			f"{label}_file_changed",
			f"{label.capitalize()} input changed before it was opened.",
		)
	if before.st_size > max_bytes:
		raise GutShardingError(
			f"{label}_file_budget_exceeded",
			f"{label.capitalize()} input exceeds its byte budget.",
		)
	flags = os.O_RDONLY | getattr(os, "O_BINARY", 0) | getattr(os, "O_NOFOLLOW", 0)
	try:
		file_descriptor = os.open(path, flags)
	except OSError as error:
		raise GutShardingError(
			f"{label}_file_unreadable",
			f"{label.capitalize()} input cannot be opened.",
		) from error
	try:
		opened = os.fstat(file_descriptor)
		if not stat.S_ISREG(opened.st_mode) or _stat_is_reparse(opened):
			raise GutShardingError(
				f"{label}_file_not_regular",
				f"{label.capitalize()} input must remain a regular file.",
			)
		if _stat_identity(opened) != _stat_identity(before):
			raise GutShardingError(
				f"{label}_file_changed",
				f"{label.capitalize()} input changed before it was opened.",
			)
		chunks: list[bytes] = []
		total = 0
		while True:
			chunk = os.read(file_descriptor, min(1024 * 1024, max_bytes + 1 - total))
			if not chunk:
				break
			total += len(chunk)
			if total > max_bytes:
				raise GutShardingError(
					f"{label}_file_budget_exceeded",
					f"{label.capitalize()} input exceeds its byte budget.",
				)
			chunks.append(chunk)
		after_handle = os.fstat(file_descriptor)
	finally:
		os.close(file_descriptor)
	try:
		after_path = path.lstat()
	except OSError as error:
		raise GutShardingError(
			f"{label}_file_changed",
			f"{label.capitalize()} input changed while it was read.",
		) from error
	if (
		_stat_identity(after_handle) != _stat_identity(opened)
		or _stat_identity(after_path) != _stat_identity(opened)
		or _stat_is_reparse(after_path)
		or path.is_symlink()
	):
		raise GutShardingError(
			f"{label}_file_changed",
			f"{label.capitalize()} input changed while it was read.",
		)
	return b"".join(chunks)


def stable_file_identity(
	metadata: os.stat_result,
) -> tuple[int, int, int, int, int, int]:
	"""Return metadata used to detect ordinary replacement around a stable read."""
	return (
		int(getattr(metadata, "st_dev", 0)),
		int(getattr(metadata, "st_ino", 0)),
		int(metadata.st_mode),
		int(metadata.st_size),
		int(metadata.st_mtime_ns),
		int(metadata.st_ctime_ns),
	)


def _inventory_file_identity(
	metadata: os.stat_result,
) -> tuple[int, int, int, int, int, int]:
	return stable_file_identity(metadata)


def _compatible_inventory_file_identity(
	entry_identity: tuple[int, int, int, int, int, int],
	path_identity: tuple[int, int, int, int, int, int],
) -> bool:
	entry_device, entry_inode, *entry_metadata = entry_identity
	path_device, path_inode, *path_metadata = path_identity
	return (
		entry_metadata == path_metadata
		and (
			(entry_device == 0 and entry_inode == 0)
			or (entry_device == path_device and entry_inode == path_inode)
		)
	)


def _snapshot_directory_chain(
	path: Path,
	code: str,
) -> tuple[tuple[Path, tuple[int, int, int]], ...]:
	absolute = Path(os.path.abspath(path))
	if not absolute.anchor:
		raise GutShardingError(code, "Required directory path must be absolute.")
	current = Path(absolute.anchor)
	chain: list[tuple[Path, tuple[int, int, int]]] = [
		(current, _validated_directory_identity(current, code)),
	]
	for component in absolute.parts[1:]:
		current /= component
		chain.append((current, _validated_directory_identity(current, code)))
	return tuple(chain)


def _validated_directory_identity(
	path: Path,
	code: str,
) -> tuple[int, int, int]:
	try:
		path_stat = path.lstat()
	except OSError as error:
		raise GutShardingError(code, "Required directory is missing or unreadable.") from error
	if (
		not stat.S_ISDIR(path_stat.st_mode)
		or path.is_symlink()
		or _stat_is_reparse(path_stat)
	):
		raise GutShardingError(
			code,
			"Required directory must be a real non-link directory.",
		)
	identity = _directory_identity(path_stat)
	if identity[0] == 0 and identity[1] == 0:
		raise GutShardingError(code, "Required directory has no stable filesystem identity.")
	return identity


def _validate_directory_chain(
	chain: tuple[tuple[Path, tuple[int, int, int]], ...],
	code: str,
) -> None:
	for path, expected in chain:
		if _validated_directory_identity(path, code) != expected:
			raise GutShardingError(code, "GUT inventory directory identity changed.")


def _directory_identity(path_stat: os.stat_result) -> tuple[int, int, int]:
	return (
		int(getattr(path_stat, "st_dev", 0)),
		int(getattr(path_stat, "st_ino", 0)),
		int(path_stat.st_mode),
	)


def _stat_is_reparse(path_stat: os.stat_result) -> bool:
	attributes = int(getattr(path_stat, "st_file_attributes", 0))
	reparse_flag = int(getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400))
	return bool(attributes & reparse_flag)


def _stat_identity(path_stat: os.stat_result) -> tuple[int, int, int, int, int]:
	return (
		int(path_stat.st_dev),
		int(path_stat.st_ino),
		int(path_stat.st_size),
		int(path_stat.st_mtime_ns),
		int(path_stat.st_mode),
	)


def _check_deadline(deadline: float) -> None:
	if time.monotonic() > deadline:
		raise GutShardingError(
			"inventory_deadline_exceeded",
			"GUT inventory exceeded its wall-clock deadline.",
		)


def _require_exact_keys(
	value: Mapping[str, Any],
	expected: frozenset[str],
	code: str,
) -> None:
	if any(type(key) is not str for key in value) or frozenset(value) != expected:
		raise GutShardingError(code, "Object keys do not match the closed schema.")


def _require_exact_integer(value: Any, field: str, expected: int) -> None:
	if type(value) is not int or value != expected:
		raise GutShardingError(
			"manifest_field_invalid",
			f"{field} must equal the schema-defined value.",
		)


def _require_nonnegative_integer(value: Any, field: str) -> int:
	if type(value) is not int or value < 0:
		raise GutShardingError(
			"manifest_field_invalid",
			f"{field} must be a non-negative integer.",
		)
	return value


def _require_exact_string(value: Any, field: str, expected: str) -> None:
	if type(value) is not str or value != expected:
		raise GutShardingError(
			"manifest_field_invalid",
			f"{field} must equal the schema-defined value.",
		)


def _is_sha256_hex(value: Any) -> bool:
	return (
		type(value) is str
		and len(value) == 64
		and all(character in "0123456789abcdef" for character in value)
	)
