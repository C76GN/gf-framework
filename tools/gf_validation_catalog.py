#!/usr/bin/env python3
"""Canonical action, executor, timeout, dependency, group, and suite catalog."""

from __future__ import annotations

import re
from collections.abc import Iterable
from collections.abc import Sequence
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from types import MappingProxyType
from typing import Any
from typing import Mapping

from gf_maintenance_check_graph import CheckGraph


_ACTION_NAME_RE = re.compile(r"^[a-z][a-z0-9_]*$")
_CATALOG_NAME_RE = re.compile(r"^[a-z][a-z0-9_-]*$")


class ValidationCatalogError(ValueError):
	"""Raised when the canonical validation catalog is incomplete or ambiguous."""


class ValidationExecutorKind(str, Enum):
	"""Closed executor choices declared independently from runtime result states."""

	IN_PROCESS = "in_process"
	SUBPROCESS = "subprocess"

	def __str__(self) -> str:
		"""Keep the Python 3.11 StrEnum string contract on Python 3.10."""
		return self.value


@dataclass(frozen=True)
class ValidationCatalogContext:
	"""Runner-provided values needed to materialize canonical action commands."""

	python_executable: str
	root: Path
	godot_log_directory: Path
	gut_lifecycle_cli_resource_path: str
	gut_shard_config_disabled_argument: str
	gut_lifecycle_hook_arguments: tuple[str, ...]
	default_reference_project: str
	reference_boot_scene: str
	reference_smoke_scene: str


@dataclass(frozen=True)
class ValidationLane:
	"""One isolated runner lane with distinct ownership and execution closures."""

	name: str
	owned_actions: tuple[str, ...]
	execution_actions: tuple[str, ...]


@dataclass(frozen=True)
class ValidationPlan:
	"""One immutable effective action graph and ordered invocation plan."""

	suite: str
	requested_actions: tuple[str, ...]
	actions: tuple[str, ...]
	check_graph: CheckGraph
	lanes: tuple[ValidationLane, ...]

	def describe_graph(self) -> dict[str, Any]:
		"""Describe the exact effective graph used to build this plan."""
		return self.check_graph.describe(self.actions)


class ValidationCatalog:
	"""Validated immutable catalog with copy-out accessors for the legacy runner."""

	def __init__(
		self,
		*,
		actions: Iterable[
			tuple[str, Sequence[str] | None, ValidationExecutorKind]
		],
		dependencies: Iterable[tuple[str, Sequence[str]]],
		check_groups: Iterable[tuple[str, Sequence[str]]],
		suites: Iterable[tuple[str, Sequence[str]]],
		parallel_full_shard_suites: Sequence[str],
		default_timeout_seconds: int,
		timeout_overrides: Iterable[tuple[str, int]],
		command_projection_context: ValidationCatalogContext | None = None,
	) -> None:
		validated_actions, validated_executors = _validate_actions(actions)
		action_names = tuple(validated_actions)
		known_actions = frozenset(action_names)
		validated_default_timeout_seconds = _validated_positive_timeout_seconds(
			"Default validation action timeout",
			default_timeout_seconds,
		)
		validated_timeout_overrides = _validate_timeout_overrides(
			timeout_overrides,
			known_actions,
		)
		validated_dependencies = _validate_dependencies(
			dependencies,
		)
		try:
			check_graph = CheckGraph(action_names, validated_dependencies)
		except ValueError as error:
			raise ValidationCatalogError(str(error)) from error
		validated_groups = _validate_action_collections(
			"check group",
			check_groups,
			known_actions,
		)
		validated_suites = _validate_action_collections(
			"suite",
			suites,
			known_actions,
		)
		validated_parallel_suites = _validate_parallel_full_shard_suites(
			parallel_full_shard_suites,
			frozenset(validated_suites),
		)
		self._actions: Mapping[str, tuple[str, ...] | None] = MappingProxyType(
			validated_actions
		)
		self._executors: Mapping[str, ValidationExecutorKind] = MappingProxyType(
			validated_executors
		)
		self._action_names = action_names
		self._in_process_action_names = tuple(
			name
			for name, executor_kind in self._executors.items()
			if executor_kind is ValidationExecutorKind.IN_PROCESS
		)
		self._deferred_action_names = tuple(
			name
			for name, command in self._actions.items()
			if command is None
		)
		self._default_timeout_seconds = validated_default_timeout_seconds
		self._timeout_overrides: Mapping[str, int] = MappingProxyType(
			validated_timeout_overrides
		)
		self._dependencies: Mapping[str, tuple[str, ...]] = MappingProxyType(
			validated_dependencies
		)
		self._check_graph = check_graph
		self._check_groups: Mapping[str, tuple[str, ...]] = MappingProxyType(
			validated_groups
		)
		self._suites: Mapping[str, tuple[str, ...]] = MappingProxyType(
			validated_suites
		)
		self._parallel_full_shard_suites = validated_parallel_suites
		if (
			command_projection_context is not None
			and type(command_projection_context) is not ValidationCatalogContext
		):
			raise ValidationCatalogError(
				"Validation command projection context must be a ValidationCatalogContext."
			)
		self._command_projection_context = command_projection_context

	@property
	def action_names(self) -> tuple[str, ...]:
		"""Return every action, including actions without a static command."""
		return self._action_names

	def command_definitions(self) -> dict[str, list[str]]:
		"""Return statically materialized commands in canonical declaration order."""
		return {
			name: list(command)
			for name, command in self._actions.items()
			if command is not None
		}

	def project_static_commands(
		self,
		*,
		root: Path,
		godot_log_directory: Path,
	) -> dict[str, list[str]]:
		"""Project only root-bound argv from this captured Catalog to one workspace."""
		context = self._command_projection_context
		if context is None:
			raise ValidationCatalogError(
				"Validation Catalog has no static-command projection context."
			)
		if not isinstance(root, Path) or not isinstance(godot_log_directory, Path):
			raise ValidationCatalogError(
				"Validation command projection paths must be pathlib.Path values."
			)
		path_projections = (
			(
				context.godot_log_directory.as_posix(),
				godot_log_directory.as_posix(),
			),
			(
				(context.root / "ai_analysis/mkdocs_site").as_posix(),
				(root / "ai_analysis/mkdocs_site").as_posix(),
			),
		)
		return {
			name: [
				_project_static_command_argument(argument, path_projections)
				for argument in command
			]
			for name, command in self._actions.items()
			if command is not None
		}

	def static_command(self, action_name: str) -> list[str] | None:
		"""Return one detached static command, or None for a known deferred action."""
		_validate_action_name(action_name)
		try:
			command = self._actions[action_name]
		except KeyError as error:
			raise ValidationCatalogError(
				f"Unknown validation action command: {action_name}"
			) from error
		return list(command) if command is not None else None

	@property
	def in_process_action_names(self) -> tuple[str, ...]:
		"""Return in-process actions in canonical declaration order."""
		return self._in_process_action_names

	@property
	def deferred_action_names(self) -> tuple[str, ...]:
		"""Return actions whose commands must be materialized by the runner."""
		return self._deferred_action_names

	def executor_kind(self, action_name: str) -> ValidationExecutorKind:
		"""Return the explicitly declared executor for one known action."""
		_validate_action_name(action_name)
		try:
			return self._executors[action_name]
		except KeyError as error:
			raise ValidationCatalogError(
				f"Unknown validation action executor: {action_name}"
			) from error

	@property
	def default_timeout_seconds(self) -> int:
		"""Return the default action timeout floor in seconds."""
		return self._default_timeout_seconds

	def timeout_overrides(self) -> dict[str, int]:
		"""Return explicit per-action timeout floors as a detached mapping."""
		return dict(self._timeout_overrides)

	def timeout_floor_seconds(self, action_name: str) -> int:
		"""Return the declared timeout floor for one known validation action."""
		_validate_action_name(action_name)
		if action_name not in self._actions:
			raise ValidationCatalogError(
				f"Unknown validation action timeout: {action_name}"
			)
		return self._timeout_overrides.get(
			action_name,
			self._default_timeout_seconds,
		)

	def dependencies(self) -> dict[str, list[str]]:
		"""Return direct action dependencies in canonical declaration order."""
		return {
			name: list(action_dependencies)
			for name, action_dependencies in self._dependencies.items()
		}

	@property
	def check_graph(self) -> CheckGraph:
		"""Return the dependency graph validated with this catalog."""
		return self._check_graph

	def check_groups(self) -> dict[str, list[str]]:
		"""Return every named check group in canonical declaration order."""
		return {
			name: list(actions)
			for name, actions in self._check_groups.items()
		}

	def check_group(self, name: str) -> list[str]:
		"""Return one named check group as a mutable compatibility copy."""
		try:
			return list(self._check_groups[name])
		except KeyError as error:
			raise ValidationCatalogError(
				f"Unknown validation check group: {name}"
			) from error

	def suites(self) -> dict[str, list[str]]:
		"""Return every suite in canonical declaration order."""
		return {
			name: list(actions)
			for name, actions in self._suites.items()
		}

	def plan(
		self,
		suite: str,
		actions: Sequence[str] | None = None,
		*,
		sync_examples: bool = False,
	) -> ValidationPlan:
		"""Build one effective graph and closure for the complete runner invocation."""
		try:
			suite_actions = self._suites[suite]
		except (KeyError, TypeError) as error:
			raise ValidationCatalogError(f"Unknown validation suite: {suite!r}") from error
		requested_actions = (
			_validated_nonempty_strings("Requested validation actions", actions)
			if actions
			else suite_actions
		)
		check_graph = self._check_graph
		if sync_examples:
			requested_actions = tuple(
				_replace_sync_examples_action(name)
				for name in requested_actions
			)
			effective_dependencies = {
				name: tuple(
					_replace_sync_examples_action(dependency)
					for dependency in dependencies
				)
				for name, dependencies in self._dependencies.items()
			}
			try:
				check_graph = CheckGraph(self._action_names, effective_dependencies)
			except ValueError as error:
				raise ValidationCatalogError(str(error)) from error
		try:
			expanded_actions = tuple(check_graph.expand(requested_actions))
		except ValueError as error:
			raise ValidationCatalogError(str(error)) from error
		lanes = (
			self._plan_parallel_full_lanes(check_graph)
			if suite == "full" and not actions
			else ()
		)
		return ValidationPlan(
			suite=suite,
			requested_actions=requested_actions,
			actions=expanded_actions,
			check_graph=check_graph,
			lanes=lanes,
		)

	def _plan_parallel_full_lanes(
		self,
		check_graph: CheckGraph,
	) -> tuple[ValidationLane, ...]:
		full_actions = self._suites["full"]
		full_action_set = set(full_actions)
		claimed_actions: set[str] = set()
		lanes: list[ValidationLane] = []
		for suite_name in self._parallel_full_shard_suites:
			owned_actions = tuple(
				action
				for action in self._suites[suite_name]
				if action in full_action_set and action not in claimed_actions
			)
			if not owned_actions:
				raise ValidationCatalogError(
					f"Parallel Full lane owns no actions: {suite_name}"
				)
			claimed_actions.update(owned_actions)
			lanes.append(ValidationLane(
				name=suite_name,
				owned_actions=owned_actions,
				execution_actions=tuple(check_graph.expand(owned_actions)),
			))
		missing_actions = [
			action
			for action in full_actions
			if action not in claimed_actions
		]
		extra_actions = sorted(claimed_actions.difference(full_action_set))
		if missing_actions or extra_actions:
			raise ValidationCatalogError(
				"Parallel Full lane plan is not set-equivalent to Full: "
				f"missing={missing_actions}, extra={extra_actions}"
			)
		return tuple(lanes)

	@property
	def parallel_full_shard_suites(self) -> tuple[str, ...]:
		"""Return the ordered Full-shard suite topology."""
		return self._parallel_full_shard_suites

	@property
	def command_projection_context(self) -> ValidationCatalogContext | None:
		"""Return the immutable context that owns all projected command arguments."""
		return self._command_projection_context


def build_validation_catalog(context: ValidationCatalogContext) -> ValidationCatalog:
	"""Build the canonical GF validation catalog from runner-provided context."""
	python = context.python_executable

	def godot_log_path(check_name: str) -> str:
		return (context.godot_log_directory / f"{check_name}.log").as_posix()

	def maintenance_command(*arguments: str) -> tuple[str, ...]:
		return (python, "tools/gf_maintenance.py", *arguments)

	def python_script(script: str, *arguments: str) -> tuple[str, ...]:
		return (python, script, *arguments)

	def in_process_action(
		name: str,
		command: tuple[str, ...] | None,
	) -> tuple[str, tuple[str, ...] | None, ValidationExecutorKind]:
		return (name, command, ValidationExecutorKind.IN_PROCESS)

	def subprocess_action(
		name: str,
		command: tuple[str, ...] | None,
	) -> tuple[str, tuple[str, ...] | None, ValidationExecutorKind]:
		return (name, command, ValidationExecutorKind.SUBPROCESS)

	actions: tuple[
		tuple[str, tuple[str, ...] | None, ValidationExecutorKind],
		...,
	] = (
		subprocess_action(
			"godot_import",
			(
				"godot",
				"--headless",
				"--log-file",
				godot_log_path("godot_import"),
				"--path",
				".",
				"--import",
			),
		),
		subprocess_action(
			"gut_lifecycle_smoke",
			python_script("tools/gf_gut_lifecycle_smoke.py", "--json"),
		),
		subprocess_action(
			"gut",
			(
				"godot",
				"--headless",
				"--log-file",
				godot_log_path("gut"),
				"--path",
				".",
				"-s",
				context.gut_lifecycle_cli_resource_path,
				context.gut_shard_config_disabled_argument,
				"-gdir=res://tests/gf_core",
				"-ginclude_subdirs",
				*context.gut_lifecycle_hook_arguments,
				"-gexit",
			),
		),
		in_process_action(
			"api",
			python_script("tools/generate_api_reference.py", "--check"),
		),
		in_process_action(
			"ai_api",
			python_script(
				"tools/generate_ai_api.py",
				"--source",
				"addons/gf",
				"--output",
				"ai_analysis/generated_api",
				"--check-or-generate",
				"--check-wiki-coverage",
			),
		),
		subprocess_action(
			"ai_developer_kit",
			python_script("tests/gf_core/tools/ai_developer/test_gf_ai_project_tool.py"),
		),
		subprocess_action(
			"ai_developer_adapter_acceptance",
			python_script(
				"tools/build_gf_ai_developer_kit.py",
				"--storage-backend-acceptance",
				"--json",
			),
		),
		subprocess_action(
			"ai_developer_kit_source",
			python_script(
				"tools/build_gf_ai_developer_kit.py",
				"--check-source",
				"--json",
			),
		),
		in_process_action(
			"docs",
			python_script("tools/check_docs_quality.py", "--strict"),
		),
		in_process_action(
			"changelog_policy",
			maintenance_command("changelog-policy", "--json"),
		),
		subprocess_action(
			"repository_policy",
			python_script("tools/gf_repository_policy.py", "validate", "--json"),
		),
		subprocess_action(
			"credential_gate",
			python_script("tools/gf_credential_gate.py", "--json"),
		),
		subprocess_action(
			"credential_gate_tests",
			python_script("tests/gf_core/tools/test_gf_credential_gate.py"),
		),
		in_process_action(
			"codeql_suppression_policy",
			maintenance_command("codeql-suppression-policy", "--json"),
		),
		subprocess_action(
			"codeql_suppression_policy_tests",
			python_script("tests/gf_core/tools/test_gf_codeql_suppression_policy.py"),
		),
		in_process_action(
			"public_docs_boundary",
			maintenance_command("public-docs-boundary"),
		),
		in_process_action(
			"public_api_boundary",
			maintenance_command("public-api-boundary"),
		),
		in_process_action(
			"resource_boundary",
			maintenance_command("resource-boundary", "--fail-on-issues"),
		),
		in_process_action(
			"content_package_boundary",
			maintenance_command("content-package-boundary"),
		),
		in_process_action(
			"asset_lifecycle_boundary",
			maintenance_command("asset-lifecycle-boundary"),
		),
		in_process_action(
			"project_profile_boundary",
			maintenance_command("project-profile-boundary"),
		),
		in_process_action("package_boundary", maintenance_command("package-boundary")),
		in_process_action(
			"package_closure_audit",
			maintenance_command("package-closure-audit"),
		),
		in_process_action(
			"package_source_boundary",
			maintenance_command("package-source-boundary"),
		),
		subprocess_action(
			"package_build_boundary",
			maintenance_command("package-build-boundary"),
		),
		in_process_action(
			"package_user_dependency_boundary",
			maintenance_command("package-user-dependency-boundary"),
		),
		in_process_action(
			"package_external_command_audit",
			maintenance_command("package-external-command-audit", "--fail-on-warnings"),
		),
		in_process_action("core_only_smoke", maintenance_command("core-only-smoke")),
		subprocess_action(
			"core_plugin_bootstrap_smoke",
			maintenance_command("core-plugin-bootstrap-smoke"),
		),
		subprocess_action(
			"package_editor_wizard_smoke",
			maintenance_command("package-editor-wizard-smoke"),
		),
		in_process_action(
			"package_focused_gut_mapping",
			maintenance_command("package-focused-gut-mapping"),
		),
		subprocess_action(
			"package_godot_cli_smoke",
			maintenance_command("package-godot-cli-smoke"),
		),
		subprocess_action(
			"package_godot_cli_local_smoke",
			maintenance_command("package-godot-cli-smoke", "--profile", "local"),
		),
		subprocess_action(
			"package_godot_cli_network_smoke",
			maintenance_command("package-godot-cli-smoke", "--profile", "network"),
		),
		subprocess_action(
			"package_godot_smoke",
			maintenance_command("package-godot-smoke"),
		),
		subprocess_action(
			"package_godot_matrix_smoke",
			maintenance_command("package-godot-smoke", "--all-packages"),
		),
		subprocess_action(
			"mkdocs",
			(
				python,
				"-m",
				"mkdocs",
				"build",
				"--strict",
				"--site-dir",
				(context.root / "ai_analysis/mkdocs_site").as_posix(),
			),
		),
		in_process_action(
			"api_since_touched",
			maintenance_command("api-since-touched"),
		),
		in_process_action("path_hygiene", maintenance_command("path-hygiene")),
		in_process_action(
			"dependency_boundary",
			maintenance_command("dependency-boundary"),
		),
		in_process_action(
			"maintenance_self_test",
			maintenance_command("maintenance-self-test"),
		),
		subprocess_action(
			"maintenance_execution_tests",
			(
				python,
				"-m",
				"unittest",
				"tests/gf_core/tools/test_gf_maintenance_execution.py",
				"tests/gf_core/tools/test_gf_posix_process_watchdog.py",
				"tests/gf_core/tools/test_gf_maintenance_check_graph.py",
				"tests/gf_core/tools/test_gf_parallel_validation.py",
				"tests/gf_core/tools/test_gf_validation_contracts.py",
				"tests/gf_core/tools/test_gf_validation_evidence.py",
				"tests/gf_core/tools/test_gf_validation_inputs.py",
				"tests/gf_core/tools/test_gf_validation_test_inventory.py",
				"tests/gf_core/tools/test_gf_gut_sharding.py",
				"tests/gf_core/tools/test_gf_gut_shard_worker.py",
				"tests/gf_core/tools/test_build_gf_release_artifacts.py",
			),
		),
		subprocess_action(
			"maintenance_generator_tests",
			python_script("tests/gf_core/tools/test_gf_maintenance_generators.py"),
		),
		subprocess_action(
			"maintenance_test_evidence_tests",
			python_script("tests/gf_core/tools/test_gf_maintenance_test_evidence.py"),
		),
		subprocess_action(
			"package_distribution_tests",
			python_script("tests/gf_core/kernel/package/test_gf_package_distribution.py"),
		),
		subprocess_action(
			"package_schema_contract_tests",
			python_script("tests/gf_core/kernel/package/test_gf_package_schema_contracts.py"),
		),
		subprocess_action(
			"gdscript_warnings",
			(
				"godot",
				"--headless",
				"--log-file",
				godot_log_path("gdscript_warnings"),
				"--path",
				".",
				"--editor",
				"--quit",
			),
		),
		subprocess_action(
			"gdscript_lsp_diagnostics",
			python_script(
				"tools/gdscript_lsp_diagnostics.py",
				"--spawn-lsp",
				"--port",
				"0",
				"--startup-timeout",
				"120",
				"--lsp-process-timeout",
				"600",
				"--request-timeout",
				"60",
				"--per-file-timeout",
				"3",
				"--max-file-timeout",
				"12",
				"--timeout-retries",
				"2",
				"--include",
				"addons/gf",
				"--include",
				"tests/gf_core",
				"--exclude-prefix",
				"addons/gut",
				"--fail-severity",
				"error,warning",
				"--log-file",
				godot_log_path("gdscript_lsp_diagnostics"),
				"--keep-log",
				"--format",
				"json",
			),
		),
		in_process_action(
			"project_settings_drift",
			maintenance_command("project-settings-drift"),
		),
		subprocess_action("diff", ("git", "diff", "--check")),
		subprocess_action(
			"examples_sync",
			python_script(
				"tools/sync_reference_project.py",
				"--project-root",
				context.default_reference_project,
				"--check",
			),
		),
		subprocess_action(
			"examples_sync_write",
			python_script(
				"tools/sync_reference_project.py",
				"--project-root",
				context.default_reference_project,
				"--apply",
			),
		),
		subprocess_action(
			"examples_scan",
			(
				"godot",
				"--headless",
				"--log-file",
				godot_log_path("examples_scan"),
				"--path",
				context.default_reference_project,
				"--editor",
				"--quit-after",
				"2",
			),
		),
		subprocess_action(
			"examples_boot",
			(
				"godot",
				"--headless",
				"--log-file",
				godot_log_path("examples_boot"),
				"--quit-after",
				"10",
				"--path",
				context.default_reference_project,
				"--scene",
				context.reference_boot_scene,
			),
		),
		subprocess_action(
			"examples_smoke",
			(
				"godot",
				"--headless",
				"--log-file",
				godot_log_path("examples_smoke"),
				"--quit-after",
				"10",
				"--path",
				context.default_reference_project,
				"--scene",
				context.reference_smoke_scene,
			),
		),
		subprocess_action(
			"examples_coverage",
			python_script(
				"tools/generate_api_coverage_matrix.py",
				"--examples",
				context.default_reference_project,
				"--output",
				"ai_analysis/api_coverage_reference_project",
				"--allow-unsafe-output-root",
				"--check",
			),
		),
		subprocess_action("release_metadata", None),
	)
	default_timeout_seconds = 600
	timeout_overrides = (
		# The unfiltered authoritative suite exceeds the generic ten-minute
		# budget on clean Windows runs. Keep the same measured floor as the explicit
		# full-suite observation and qualification control.
		("gut", 1200),
		# The owned LSP server has a 600-second inner lifetime. Preserve a bounded
		# cleanup and report-publication margin outside that process-tree boundary.
		("gdscript_lsp_diagnostics", 660),
		# Runs six focused process-level lifecycle scenarios after a shared import.
		("gut_lifecycle_smoke", 360),
		# The executable Adapter contract performs one isolated import and one GUT
		# run. A measured Windows run takes about 5.5 minutes, so retain a bounded
		# 15-minute outer budget while each supervised Godot phase stays capped.
		("ai_developer_adapter_acceptance", 900),
		# The editor wizard smoke launches and tears down isolated editor projects;
		# a clean Windows run is routinely longer than the generic ten-minute budget.
		("package_editor_wizard_smoke", 1200),
		# This check runs 24 isolated Godot CLI scenarios. A measured Windows release
		# run reaches its late failure-path scenarios after 20 minutes, so keep a
		# dedicated 40-minute outer budget while each Godot command remains capped.
		("package_godot_cli_smoke", 2400),
		# The split profiles measure around ten minutes on Windows. Keep a 2x
		# scenario-level margin while failing materially earlier than the aggregate.
		("package_godot_cli_local_smoke", 1200),
		("package_godot_cli_network_smoke", 1200),
		# The release matrix installs and parses every registry package in an isolated
		# project. At 52 packages it exceeds the generic ten-minute budget on Windows.
		("package_godot_matrix_smoke", 2400),
	)

	dependencies: tuple[tuple[str, tuple[str, ...]], ...] = (
		("gut_lifecycle_smoke", ("godot_import",)),
		("gut", ("godot_import",)),
		("gdscript_warnings", ("godot_import",)),
		("gdscript_lsp_diagnostics", ("godot_import",)),
		("mkdocs", ("docs", "public_docs_boundary")),
		("examples_scan", ("examples_sync",)),
		("examples_boot", ("examples_scan",)),
		("examples_smoke", ("examples_scan",)),
		("examples_coverage", ("examples_sync",)),
	)

	api_checks = ("api", "ai_api", "ai_developer_kit", "public_api_boundary")
	docs_checks = ("docs", "changelog_policy", "public_docs_boundary", "mkdocs")
	examples_checks = (
		"examples_sync",
		"examples_scan",
		"examples_boot",
		"examples_smoke",
		"examples_coverage",
	)
	light_boundary_checks = (
		"resource_boundary",
		"content_package_boundary",
		"asset_lifecycle_boundary",
		"project_profile_boundary",
		"package_boundary",
		"package_closure_audit",
		"package_source_boundary",
		"package_user_dependency_boundary",
		"package_external_command_audit",
		"core_only_smoke",
		"package_focused_gut_mapping",
		"api_since_touched",
		"repository_policy",
		"credential_gate",
		"credential_gate_tests",
		"codeql_suppression_policy",
		"codeql_suppression_policy_tests",
		"maintenance_execution_tests",
		"maintenance_generator_tests",
		"maintenance_test_evidence_tests",
		"path_hygiene",
		"dependency_boundary",
		"diff",
	)
	package_contract_smoke_checks = ("package_build_boundary",)
	package_editor_checks = ("package_editor_wizard_smoke",)
	package_cli_local_checks = ("package_godot_cli_local_smoke",)
	package_cli_network_checks = ("package_godot_cli_network_smoke",)
	package_cli_checks = (*package_cli_local_checks, *package_cli_network_checks)
	package_smoke_checks = (
		*package_contract_smoke_checks,
		*package_editor_checks,
		*package_cli_checks,
	)
	package_contract_checks = (
		"ai_developer_adapter_acceptance",
		"package_boundary",
		"package_closure_audit",
		"package_source_boundary",
		"package_user_dependency_boundary",
		"package_external_command_audit",
		"core_only_smoke",
		"core_plugin_bootstrap_smoke",
		"package_focused_gut_mapping",
		"package_distribution_tests",
		"package_schema_contract_tests",
		*package_contract_smoke_checks,
	)
	package_checks = (
		*package_contract_checks,
		*package_editor_checks,
		*package_cli_checks,
	)
	quick_checks = (
		"api",
		"ai_api",
		"ai_developer_kit_source",
		"docs",
		"changelog_policy",
		"public_docs_boundary",
		"public_api_boundary",
		*light_boundary_checks,
	)
	full_checks = (
		"gut_lifecycle_smoke",
		"gut",
		"api",
		"ai_api",
		"ai_developer_kit",
		"docs",
		"changelog_policy",
		"public_docs_boundary",
		"public_api_boundary",
		"resource_boundary",
		"content_package_boundary",
		"asset_lifecycle_boundary",
		"project_profile_boundary",
		*package_checks,
		"package_godot_smoke",
		"mkdocs",
		"api_since_touched",
		"repository_policy",
		"credential_gate",
		"credential_gate_tests",
		"codeql_suppression_policy",
		"codeql_suppression_policy_tests",
		"path_hygiene",
		"maintenance_self_test",
		"maintenance_execution_tests",
		"maintenance_generator_tests",
		"maintenance_test_evidence_tests",
		"dependency_boundary",
		"gdscript_warnings",
		"gdscript_lsp_diagnostics",
		"diff",
	)
	release_checks = (
		"gut_lifecycle_smoke",
		"gut",
		"api",
		"ai_api",
		"ai_developer_kit",
		"docs",
		"changelog_policy",
		"public_docs_boundary",
		"public_api_boundary",
		"resource_boundary",
		"content_package_boundary",
		"asset_lifecycle_boundary",
		"project_profile_boundary",
		*package_checks,
		"package_godot_matrix_smoke",
		"mkdocs",
		"api_since_touched",
		"repository_policy",
		"credential_gate",
		"credential_gate_tests",
		"codeql_suppression_policy",
		"codeql_suppression_policy_tests",
		"path_hygiene",
		"maintenance_self_test",
		"maintenance_execution_tests",
		"maintenance_generator_tests",
		"maintenance_test_evidence_tests",
		"dependency_boundary",
		"gdscript_warnings",
		"gdscript_lsp_diagnostics",
		"diff",
		"release_metadata",
	)
	framework_gut_checks = ("gut_lifecycle_smoke", "gut", "gdscript_warnings")
	framework_lsp_checks = ("gdscript_lsp_diagnostics",)
	framework_static_checks = (
		"api",
		"ai_api",
		"ai_developer_kit",
		"docs",
		"changelog_policy",
		"public_docs_boundary",
		"public_api_boundary",
		"resource_boundary",
		"content_package_boundary",
		"asset_lifecycle_boundary",
		"project_profile_boundary",
		"mkdocs",
		"api_since_touched",
		"repository_policy",
		"credential_gate",
		"credential_gate_tests",
		"codeql_suppression_policy",
		"codeql_suppression_policy_tests",
		"path_hygiene",
		"maintenance_self_test",
		"maintenance_execution_tests",
		"maintenance_generator_tests",
		"maintenance_test_evidence_tests",
		"dependency_boundary",
		"diff",
	)
	framework_checks = (
		"gut_lifecycle_smoke",
		"gut",
		"api",
		"ai_api",
		"ai_developer_kit",
		"docs",
		"changelog_policy",
		"public_docs_boundary",
		"public_api_boundary",
		"resource_boundary",
		"content_package_boundary",
		"asset_lifecycle_boundary",
		"project_profile_boundary",
		"mkdocs",
		"api_since_touched",
		"repository_policy",
		"credential_gate",
		"credential_gate_tests",
		"codeql_suppression_policy",
		"codeql_suppression_policy_tests",
		"path_hygiene",
		"maintenance_self_test",
		"maintenance_execution_tests",
		"maintenance_generator_tests",
		"maintenance_test_evidence_tests",
		"dependency_boundary",
		"gdscript_warnings",
		"gdscript_lsp_diagnostics",
		"diff",
	)
	package_ci_checks = (*package_checks, "package_godot_smoke")
	package_release_checks = (*package_checks, "package_godot_matrix_smoke")
	package_artifact_consumer_checks = (
		"package_build_boundary",
		"package_editor_wizard_smoke",
		"package_godot_cli_smoke",
		"package_godot_cli_local_smoke",
		"package_godot_cli_network_smoke",
		"package_godot_smoke",
		"package_godot_matrix_smoke",
	)

	check_groups = (
		("api", api_checks),
		("docs", docs_checks),
		("examples", examples_checks),
		("light_boundary", light_boundary_checks),
		("package_contract_smoke", package_contract_smoke_checks),
		("package_editor", package_editor_checks),
		("package_cli_local", package_cli_local_checks),
		("package_cli_network", package_cli_network_checks),
		("package_cli", package_cli_checks),
		("package_smoke", package_smoke_checks),
		("package_contract", package_contract_checks),
		("package", package_checks),
		("quick", quick_checks),
		("full", full_checks),
		("release", release_checks),
		("framework_gut", framework_gut_checks),
		("framework_lsp", framework_lsp_checks),
		("framework_static", framework_static_checks),
		("framework", framework_checks),
		("package_ci", package_ci_checks),
		("package_release", package_release_checks),
		("package_artifact_consumers", package_artifact_consumer_checks),
	)

	suites = (
		("api", api_checks),
		("docs", docs_checks),
		("examples", examples_checks),
		("framework", framework_checks),
		("framework-gut", framework_gut_checks),
		("framework-lsp", framework_lsp_checks),
		("framework-static", framework_static_checks),
		("quick", quick_checks),
		("package", package_checks),
		("package-contract", package_contract_checks),
		("package-editor", package_editor_checks),
		("package-cli", package_cli_checks),
		("package-cli-local", package_cli_local_checks),
		("package-cli-network", package_cli_network_checks),
		("package-godot-ci", ("package_godot_smoke",)),
		("package-godot-release", ("package_godot_matrix_smoke",)),
		("package-ci", package_ci_checks),
		("package-release", package_release_checks),
		("full", full_checks),
		("release", release_checks),
	)
	parallel_full_shard_suites = (
		"package-editor",
		"framework-static",
		"package-godot-ci",
		"package-cli-local",
		"package-cli-network",
		"package-contract",
		"framework-gut",
		"framework-lsp",
	)
	return ValidationCatalog(
		actions=actions,
		dependencies=dependencies,
		check_groups=check_groups,
		suites=suites,
		parallel_full_shard_suites=parallel_full_shard_suites,
		default_timeout_seconds=default_timeout_seconds,
		timeout_overrides=timeout_overrides,
		command_projection_context=context,
	)


def _project_static_command_argument(
	argument: str,
	path_projections: tuple[tuple[str, str], ...],
) -> str:
	for source, target in path_projections:
		if argument == source:
			return target
		source_prefix = source.rstrip("/") + "/"
		if argument.startswith(source_prefix):
			return target.rstrip("/") + "/" + argument[len(source_prefix):]
	return argument


def _validate_actions(
	actions: Iterable[
		tuple[str, Sequence[str] | None, ValidationExecutorKind]
	],
) -> tuple[
	dict[str, tuple[str, ...] | None],
	dict[str, ValidationExecutorKind],
]:
	validated: dict[str, tuple[str, ...] | None] = {}
	validated_executors: dict[str, ValidationExecutorKind] = {}
	for declaration in actions:
		if type(declaration) is not tuple or len(declaration) != 3:
			raise ValidationCatalogError("Validation action declarations must be triples.")
		name, command, executor_kind = declaration
		_validate_action_name(name)
		if name in validated:
			raise ValidationCatalogError(f"Duplicate validation action: {name}")
		if type(executor_kind) is not ValidationExecutorKind:
			raise ValidationCatalogError(
				f"Validation action executor for {name} must be a ValidationExecutorKind."
			)
		validated_executors[name] = executor_kind
		if command is None:
			# A deferred command is orthogonal to executor choice.  The runner still
			# materializes live arguments before dispatch.
			validated[name] = None
			continue
		validated[name] = _validated_nonempty_strings(
			f"Validation action command for {name}",
			command,
		)
	return validated, validated_executors


def _replace_sync_examples_action(name: str) -> str:
	return "examples_sync_write" if name == "examples_sync" else name


def _validate_timeout_overrides(
	declarations: Iterable[tuple[str, int]],
	known_actions: frozenset[str],
) -> dict[str, int]:
	validated: dict[str, int] = {}
	for declaration in declarations:
		if type(declaration) is not tuple or len(declaration) != 2:
			raise ValidationCatalogError(
				"Validation timeout override declarations must be pairs."
			)
		action_name, timeout_seconds = declaration
		_validate_action_name(action_name)
		if action_name not in known_actions:
			raise ValidationCatalogError(
				f"Validation timeout override references an unknown action: {action_name}"
			)
		if action_name in validated:
			raise ValidationCatalogError(
				f"Duplicate validation timeout override: {action_name}"
			)
		validated[action_name] = _validated_positive_timeout_seconds(
			f"Validation timeout override for {action_name}",
			timeout_seconds,
		)
	return validated


def _validated_positive_timeout_seconds(label: str, value: Any) -> int:
	if type(value) is not int or value <= 0:
		raise ValidationCatalogError(f"{label} must be a positive integer.")
	return value


def _validate_dependencies(
	dependencies: Iterable[tuple[str, Sequence[str]]],
) -> dict[str, tuple[str, ...]]:
	validated: dict[str, tuple[str, ...]] = {}
	for declaration in dependencies:
		if type(declaration) is not tuple or len(declaration) != 2:
			raise ValidationCatalogError("Validation dependency declarations must be pairs.")
		name, values = declaration
		_validate_action_name(name)
		if name in validated:
			raise ValidationCatalogError(
				f"Duplicate validation dependency owner: {name}"
			)
		validated_values = _validated_nonempty_strings(
			f"Validation dependencies for {name}",
			values,
		)
		validated[name] = validated_values
	return validated


def _validate_action_collections(
	label: str,
	declarations: Iterable[tuple[str, Sequence[str]]],
	known_actions: frozenset[str],
) -> dict[str, tuple[str, ...]]:
	validated: dict[str, tuple[str, ...]] = {}
	for declaration in declarations:
		if type(declaration) is not tuple or len(declaration) != 2:
			raise ValidationCatalogError(
				f"Validation {label} declarations must be pairs."
			)
		name, values = declaration
		_validate_catalog_name(name, label)
		if name in validated:
			raise ValidationCatalogError(f"Duplicate validation {label}: {name}")
		validated[name] = _validated_unique_members(
			f"Validation {label} {name}",
			values,
			known_actions,
		)
	return validated


def _validate_parallel_full_shard_suites(
	values: Sequence[str],
	known_suites: frozenset[str],
) -> tuple[str, ...]:
	return _validated_unique_members(
		"Parallel Full shard suites",
		values,
		known_suites,
		member_label="suite",
	)


def _validated_unique_members(
	label: str,
	values: Sequence[str],
	known_values: frozenset[str],
	*,
	member_label: str = "action",
) -> tuple[str, ...]:
	validated = _validated_nonempty_strings(label, values)
	if len(validated) != len(set(validated)):
		raise ValidationCatalogError(f"{label} contains a duplicate {member_label}.")
	for value in validated:
		if value not in known_values:
			raise ValidationCatalogError(
				f"{label} references an unknown {member_label}: {value}"
			)
	return validated


def _validated_nonempty_strings(
	label: str,
	values: Sequence[str],
) -> tuple[str, ...]:
	if isinstance(values, (str, bytes)) or not isinstance(values, Sequence):
		raise ValidationCatalogError(f"{label} must be a sequence of strings.")
	validated = tuple(values)
	if not validated:
		raise ValidationCatalogError(f"{label} cannot be empty.")
	if any(type(value) is not str or not value for value in validated):
		raise ValidationCatalogError(f"{label} contains an empty or non-string value.")
	return validated


def _validate_action_name(value: Any) -> None:
	if type(value) is not str or _ACTION_NAME_RE.fullmatch(value) is None:
		raise ValidationCatalogError(f"Invalid validation action name: {value!r}")


def _validate_catalog_name(value: Any, label: str) -> None:
	if type(value) is not str or _CATALOG_NAME_RE.fullmatch(value) is None:
		raise ValidationCatalogError(
			f"Invalid validation {label} name: {value!r}"
		)


__all__ = [
	"ValidationCatalog",
	"ValidationCatalogContext",
	"ValidationCatalogError",
	"ValidationExecutorKind",
	"ValidationLane",
	"ValidationPlan",
	"build_validation_catalog",
]
