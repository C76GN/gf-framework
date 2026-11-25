#!/usr/bin/env python3
"""集中描述维护动作的执行种类、超时、依赖、分组与套件。"""

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
from gf_maintenance_commands import BY_ACTION as ORDINARY_COMMANDS
from gf_validation_contracts import CheckInputSpec
from gf_validation_contracts import PathRule


_ACTION_NAME_RE = re.compile(r"^[a-z][a-z0-9_]*$")
_CATALOG_NAME_RE = re.compile(r"^[a-z][a-z0-9_-]*$")


class ValidationCatalogError(ValueError):
	"""验证目录不完整或动作身份存在歧义。"""


class ValidationExecutorKind(str, Enum):
	"""动作允许的执行器种类，与执行后的结果状态独立声明。"""

	IN_PROCESS = "in_process"
	SUBPROCESS = "subprocess"

	def __str__(self) -> str:
		"""在 Python 3.10 上保持与 Python 3.11 StrEnum 相同的字符串语义。"""
		return self.value


@dataclass(frozen=True)
class ValidationCatalogContext:
	"""由运行器提供、用来生成验证目录中实际命令的上下文。"""

	python_executable: str
	root: Path
	godot_log_directory: Path
	gut_lifecycle_cli_resource_path: str
	gut_shard_config_disabled_argument: str
	gut_lifecycle_hook_arguments: tuple[str, ...]


@dataclass(frozen=True)
class ValidationLane:
	"""一个隔离的执行分组，分别记录归属与实际运行所需的依赖闭包。"""

	name: str
	owned_actions: tuple[str, ...]
	execution_actions: tuple[str, ...]


@dataclass(frozen=True)
class ValidationPlan:
	"""记录本次调用实际采用的不可变动作图及有序执行计划。"""

	suite: str
	requested_actions: tuple[str, ...]
	actions: tuple[str, ...]
	check_graph: CheckGraph
	lanes: tuple[ValidationLane, ...]

	def describe_graph(self) -> dict[str, Any]:
		"""描述生成当前计划实际使用的依赖图。"""
		return self.check_graph.describe(self.actions)


class ValidationCatalog:
	"""已校验的不可变检查目录，需要可变数据的运行器通过访问器获取副本。"""

	def __init__(
		self,
		*,
		actions: Iterable[
			tuple[str, Sequence[str] | None, ValidationExecutorKind]
		],
		input_specs: Iterable[CheckInputSpec],
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
		validated_input_specs = _validate_input_specs(input_specs, action_names)
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
		self._input_specs = validated_input_specs
		self._input_specs_by_name: Mapping[str, CheckInputSpec] = MappingProxyType({
			spec.check_name: spec for spec in validated_input_specs
		})
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
		"""按声明返回全部动作，包括需要执行时才能生成命令的动作。"""
		return self._action_names

	@property
	def input_specs(self) -> tuple[CheckInputSpec, ...]:
		"""按动作声明顺序返回供诊断的输入声明。"""
		return self._input_specs

	def input_spec(self, action_name: str) -> CheckInputSpec | None:
		"""返回指定动作的输入声明，已知动作尚未声明时返回 None。"""
		_validate_action_name(action_name)
		if action_name not in self._actions:
			raise ValidationCatalogError(
				f"Unknown validation action input spec: {action_name}"
			)
		return self._input_specs_by_name.get(action_name)

	def command_definitions(self) -> dict[str, list[str]]:
		"""按目录声明顺序返回已能确定实际参数的静态命令。"""
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
		"""将已捕获目录中依赖根路径的命令参数投影到指定工作区。"""
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
		"""返回静态命令的独立副本，已知的延迟动作返回 None。"""
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
		"""按目录声明顺序返回在当前进程内执行的动作。"""
		return self._in_process_action_names

	@property
	def deferred_action_names(self) -> tuple[str, ...]:
		"""返回实际命令须由运行器在调度前生成的动作。"""
		return self._deferred_action_names

	def executor_kind(self, action_name: str) -> ValidationExecutorKind:
		"""返回已知动作显式指定的执行器种类。"""
		_validate_action_name(action_name)
		try:
			return self._executors[action_name]
		except KeyError as error:
			raise ValidationCatalogError(
				f"Unknown validation action executor: {action_name}"
			) from error

	@property
	def default_timeout_seconds(self) -> int:
		"""返回默认动作时限的下限，以秒计。"""
		return self._default_timeout_seconds

	def timeout_overrides(self) -> dict[str, int]:
		"""返回各动作显式设置的超时下限映射副本。"""
		return dict(self._timeout_overrides)

	def timeout_floor_seconds(self, action_name: str) -> int:
		"""返回指定已知动作的超时下限，以秒计。"""
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
		"""按目录中的声明顺序返回动作的直接依赖。"""
		return {
			name: list(action_dependencies)
			for name, action_dependencies in self._dependencies.items()
		}

	@property
	def check_graph(self) -> CheckGraph:
		"""返回构建本目录时已经校验的依赖图。"""
		return self._check_graph

	def check_groups(self) -> dict[str, list[str]]:
		"""按目录声明顺序返回所有具名检查分组。"""
		return {
			name: list(actions)
			for name, actions in self._check_groups.items()
		}

	def check_group(self, name: str) -> list[str]:
		"""返回指定分组的可变副本，调用方更改不影响目录。"""
		try:
			return list(self._check_groups[name])
		except KeyError as error:
			raise ValidationCatalogError(
				f"Unknown validation check group: {name}"
			) from error

	def suites(self) -> dict[str, list[str]]:
		"""按目录声明顺序返回全部验证套件。"""
		return {
			name: list(actions)
			for name, actions in self._suites.items()
		}

	def plan(
		self,
		suite: str,
		actions: Sequence[str] | None = None,
	) -> ValidationPlan:
		"""为整个运行器调用建立同一份实际依赖图和执行闭包。"""
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
		"""返回 Full 套件各分片按执行顺序排列的套件拓扑。"""
		return self._parallel_full_shard_suites

	@property
	def command_projection_context(self) -> ValidationCatalogContext | None:
		"""返回产生全部投影命令参数的不可变上下文。"""
		return self._command_projection_context


def build_validation_catalog(context: ValidationCatalogContext) -> ValidationCatalog:
	"""从运行器提供的上下文建立 GF 的统一验证目录。"""
	python = context.python_executable

	def godot_log_path(check_name: str) -> str:
		return (context.godot_log_directory / f"{check_name}.log").as_posix()

	def maintenance_command(*arguments: str) -> tuple[str, ...]:
		return (python, "tools/gf_maintenance.py", *arguments)

	def ordinary_command(action_id: str, *, json_output: bool = False) -> tuple[str, ...]:
		return maintenance_command(*ORDINARY_COMMANDS[action_id].arguments(json_output=json_output))

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
		# 隔离导入与无界面原生编辑器各限 180 秒。动作预算至少 600 秒以容纳准备和清理，
		# 成功日志由外层按 --keep-logs 策略处理。
		subprocess_action(
			"scene_placement_editor_smoke",
			python_script("tests/gf_core/tools/scene_placement/run_editor_smoke.py", "--keep-logs"),
		),
		subprocess_action(
			"config_workbench_editor_smoke",
			python_script("tests/gf_core/tools/config_pipeline/run_editor_smoke.py"),
		),
		subprocess_action(
			"project_bootstrap_editor_smoke",
			python_script("tests/gf_core/tools/project_bootstrap/run_editor_smoke.py", "--keep-logs"),
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
			ordinary_command("changelog_policy", json_output=True),
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
			ordinary_command("codeql_suppression_policy", json_output=True),
		),
		subprocess_action(
			"codeql_suppression_policy_tests",
			python_script("tests/gf_core/tools/test_gf_codeql_suppression_policy.py"),
		),
		in_process_action(
			"diagnostic_policy",
			ordinary_command("diagnostic_policy", json_output=True),
		),
		subprocess_action(
			"diagnostic_policy_tests",
			python_script("tests/gf_core/tools/test_gf_diagnostic_policy.py"),
		),
		in_process_action(
			"gdscript_readability",
			ordinary_command("gdscript_readability", json_output=True),
		),
		subprocess_action(
			"gdscript_readability_tests",
			python_script("tests/gf_core/tools/test_gf_gdscript_readability.py"),
		),
		subprocess_action(
			"gdscript_list_layout_tests",
			python_script("tests/gf_core/tools/test_gf_gdscript_list_layout.py"),
		),
		subprocess_action(
			"gdscript_expression_layout_tests",
			python_script("tests/gf_core/tools/test_gf_gdscript_expression_layout.py"),
		),
		subprocess_action(
			"gdscript_layout_integrity_tests",
			python_script("tests/gf_core/tools/test_gf_gdscript_layout_integrity.py"),
		),
		in_process_action(
			"public_docs_boundary",
			ordinary_command("public_docs_boundary"),
		),
		in_process_action(
			"public_api_boundary",
			ordinary_command("public_api_boundary"),
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
			"project_profile_artifacts",
			ordinary_command("project_profile_artifacts"),
		),
		subprocess_action(
			"project_profile_native_acceptance",
			maintenance_command("project-profile-native-acceptance"),
		),
		subprocess_action(
			"code_quality_native_acceptance",
			python_script("tests/gf_core/tools/code_quality/run_native_acceptance.py"),
		),
		in_process_action("package_boundary", ordinary_command("package_boundary")),
		in_process_action(
			"package_closure_audit",
			ordinary_command("package_closure_audit"),
		),
		in_process_action(
			"package_source_boundary",
			ordinary_command("package_source_boundary"),
		),
		in_process_action(
			"package_external_command_audit",
			maintenance_command("package-external-command-audit", "--fail-on-warnings"),
		),
		in_process_action("core_only_smoke", ordinary_command("core_only_smoke")),
		subprocess_action(
			"core_plugin_bootstrap_smoke",
			maintenance_command("core-plugin-bootstrap-smoke"),
		),
		in_process_action(
			"package_focused_gut_mapping",
			ordinary_command("package_focused_gut_mapping"),
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
			ordinary_command("api_since_touched"),
		),
		in_process_action("path_hygiene", ordinary_command("path_hygiene")),
		in_process_action(
			"dependency_boundary",
			ordinary_command("dependency_boundary"),
		),
		in_process_action(
			"maintenance_self_test",
			ordinary_command("maintenance_self_test"),
		),
		subprocess_action(
			"maintenance_execution_tests",
			(
				python,
				"-m",
				"unittest",
				"tests/gf_core/tools/test_gf_maintenance_execution.py",
				"tests/gf_core/tools/test_gf_reactive_benchmark.py",
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
				"tests/gf_core/tools/test_gf_private_docs_queries.py",
			),
		),
		subprocess_action(
			"maintenance_generator_tests",
			(
				python, "-m", "unittest",
				"tests/gf_core/tools/test_gf_maintenance_generators.py",
				"tests/gf_core/tools/test_gf_review_hotspots.py",
				"tests/gf_core/tools/test_gf_review_hotspot_report.py",
			),
		),
		subprocess_action(
			"maintenance_test_evidence_tests",
			python_script("tests/gf_core/tools/test_gf_maintenance_test_evidence.py"),
		),
		subprocess_action(
			"module_descriptor_tests",
			python_script("tests/gf_core/tools/test_gf_module_descriptors.py"),
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
				"120",
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
			ordinary_command("project_settings_drift"),
		),
		subprocess_action("diff", ("git", "diff", "--check")),
		subprocess_action("release_metadata", None),
	)
	common_input_implementation_files = (
		"tools/gf_maintenance.py",
		"tools/gf_validation_catalog.py",
		"tools/gf_validation_contracts.py",
		"tools/gf_validation_inputs.py",
		"tools/gf_workspace_snapshot.py",
	)
	input_specs = (
		CheckInputSpec(
			check_name="public_docs_boundary",
			source_rules=(
				PathRule("exact", "addons/gf/extensions/README.md"),
				PathRule("exact", "addons/gf/README.md"),
				PathRule("exact", "ASSET_LIBRARY.md"),
				PathRule("exact", "ASSET_STORE.md"),
				PathRule("tree", "docs/wiki", suffixes=(".md",)),
				PathRule(
					"tree",
					"docs/zh",
					suffixes=(".md",),
					excluded_prefixes=("docs/zh/reference/api",),
				),
				PathRule("exact", "README.md"),
				PathRule("exact", "README.zh.md"),
			),
			implementation_files=common_input_implementation_files,
		),
		CheckInputSpec(
			check_name="public_api_boundary",
			source_rules=(
				PathRule("tree", "addons/gf", suffixes=(".gd",)),
				PathRule("tree", "docs/api_catalog", suffixes=(".xml",)),
				PathRule("tree", "docs/zh/reference/api", suffixes=(".md",)),
			),
			implementation_files=(
				"tools/gdscript_api_parser.py",
				"tools/gf_api_owners.py",
				*common_input_implementation_files,
			),
		),
	)
	default_timeout_seconds = 600
	timeout_overrides = (
		# 冷缓存 CLI 场景共用 70 秒的内部截止时间。
		("code_quality_native_acceptance", 90),
		# Windows 上的完整权威套件实测约 25 分钟。全套观察和验收对照共用 30 分钟的预算下限，
		# 落在既有 CI 时限内。
		("gut", 1800),
		# LSP 服务自身最多运行 600 秒，外层需要为进程树清理和报告发布留出时间。
		("gdscript_lsp_diagnostics", 660),
		# 共用一次项目导入，再执行六个进程级生命周期场景。
		("gut_lifecycle_smoke", 360),
		# 可执行适配器契约分别执行一次隔离导入和一次 GUT。Windows 实测约 5.5 分钟，外层留 15 分钟，
		# 各 Godot 阶段仍单独限时。
		("ai_developer_adapter_acceptance", 900),
		# 五个编辑器或运行时阶段各限 180 秒，另需为采集源码、清理进程与发布报告留出时间。
		("project_bootstrap_editor_smoke", 1200),
	)

	dependencies: tuple[tuple[str, tuple[str, ...]], ...] = (
		("gut_lifecycle_smoke", ("godot_import",)),
		("gut", ("godot_import",)),
		("gdscript_warnings", ("godot_import",)),
		("gdscript_lsp_diagnostics", ("godot_import",)),
		("mkdocs", ("docs", "public_docs_boundary")),
	)

	api_checks = ("api", "ai_api", "ai_developer_kit", "public_api_boundary")
	docs_checks = ("docs", "changelog_policy", "public_docs_boundary", "mkdocs")
	light_boundary_checks = (
		"resource_boundary",
		"content_package_boundary",
		"asset_lifecycle_boundary",
		"project_profile_artifacts",
		"package_boundary",
		"package_closure_audit",
		"package_source_boundary",
		"package_external_command_audit",
		"core_only_smoke",
		"package_focused_gut_mapping",
		"module_descriptor_tests",
		"api_since_touched",
		"repository_policy",
		"credential_gate",
		"credential_gate_tests",
		"codeql_suppression_policy",
		"codeql_suppression_policy_tests",
		"diagnostic_policy",
		"diagnostic_policy_tests",
		"gdscript_readability",
		"gdscript_readability_tests",
		"gdscript_list_layout_tests",
		"gdscript_expression_layout_tests",
		"gdscript_layout_integrity_tests",
		"maintenance_execution_tests",
		"maintenance_generator_tests",
		"maintenance_test_evidence_tests",
		"path_hygiene",
		"dependency_boundary",
		"diff",
	)
	module_boundary_checks = (
		"package_boundary",
		"package_closure_audit",
		"package_source_boundary",
		"package_external_command_audit",
		"core_only_smoke",
		"package_focused_gut_mapping",
		"module_descriptor_tests",
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
	framework_gut_checks = ("gut_lifecycle_smoke", "gut", "gdscript_warnings")
	framework_lsp_checks = ("gdscript_lsp_diagnostics",)
	framework_integration_checks = (
		"code_quality_native_acceptance",
		"project_profile_native_acceptance",
		"ai_developer_adapter_acceptance",
		"core_plugin_bootstrap_smoke",
		"scene_placement_editor_smoke",
		"config_workbench_editor_smoke",
		"project_bootstrap_editor_smoke",
	)
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
		"project_profile_artifacts",
		*module_boundary_checks,
		"mkdocs",
		"api_since_touched",
		"repository_policy",
		"credential_gate",
		"credential_gate_tests",
		"codeql_suppression_policy",
		"codeql_suppression_policy_tests",
		"diagnostic_policy",
		"diagnostic_policy_tests",
		"gdscript_readability",
		"gdscript_readability_tests",
		"gdscript_list_layout_tests",
		"gdscript_expression_layout_tests",
		"gdscript_layout_integrity_tests",
		"path_hygiene",
		"maintenance_self_test",
		"maintenance_execution_tests",
		"maintenance_generator_tests",
		"maintenance_test_evidence_tests",
		"dependency_boundary",
		"diff",
	)
	framework_checks = (
		*framework_gut_checks,
		*framework_lsp_checks,
		*framework_static_checks,
		*framework_integration_checks,
	)
	full_checks = framework_checks
	release_checks = (*framework_checks, "release_metadata")

	check_groups = (
		("api", api_checks),
		("docs", docs_checks),
		("light_boundary", light_boundary_checks),
		("module_boundary", module_boundary_checks),
		("quick", quick_checks),
		("full", full_checks),
		("release", release_checks),
		("framework_gut", framework_gut_checks),
		("framework_lsp", framework_lsp_checks),
		("framework_static", framework_static_checks),
		("framework_integration", framework_integration_checks),
		("framework", framework_checks),
	)

	suites = (
		("api", api_checks),
		("docs", docs_checks),
		("framework", framework_checks),
		("framework-gut", framework_gut_checks),
		("framework-lsp", framework_lsp_checks),
		("framework-static", framework_static_checks),
		("framework-integration", framework_integration_checks),
		("quick", quick_checks),
		("full", full_checks),
		("release", release_checks),
	)
	parallel_full_shard_suites = (
		"framework-static",
		"framework-integration",
		"framework-lsp",
		"framework-gut",
	)
	return ValidationCatalog(
		actions=actions,
		input_specs=input_specs,
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
			# 延迟生成命令与选用哪类执行器相互独立，实际参数在调度前才确定。
			validated[name] = None
			continue
		validated[name] = _validated_nonempty_strings(
			f"Validation action command for {name}",
			command,
		)
	return validated, validated_executors


def _validate_input_specs(
	input_specs: Iterable[CheckInputSpec],
	action_names: tuple[str, ...],
) -> tuple[CheckInputSpec, ...]:
	if isinstance(input_specs, (str, bytes)):
		raise ValidationCatalogError(
			"Validation input specs must be an iterable of CheckInputSpec values."
		)
	try:
		iterator = iter(input_specs)
	except TypeError as error:
		raise ValidationCatalogError(
			"Validation input specs must be an iterable of CheckInputSpec values."
		) from error
	known_actions = frozenset(action_names)
	by_name: dict[str, CheckInputSpec] = {}
	for spec in iterator:
		if type(spec) is not CheckInputSpec:
			raise ValidationCatalogError(
				"Validation input specs must contain CheckInputSpec values."
			)
		if spec.check_name not in known_actions:
			raise ValidationCatalogError(
				f"Validation input spec references an unknown action: {spec.check_name}"
			)
		if spec.check_name in by_name:
			raise ValidationCatalogError(
				f"Duplicate validation input spec: {spec.check_name}"
			)
		by_name[spec.check_name] = spec
	return tuple(by_name[name] for name in action_names if name in by_name)




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
