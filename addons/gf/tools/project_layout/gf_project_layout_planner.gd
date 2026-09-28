## GFProjectLayoutPlanner: 基于项目结构分析快照生成只读改进计划。
##
## Planner 的规划核心只消费已经编译的 profile 与完整冻结分析图，不访问当前文件系统，
## 也不创建、移动、删除或改写项目内容。它输出可审查的相对路径步骤，并用 blocker
## 显式报告冻结图中已观察到的文件阻塞。
## Feature 内聚式 profile 只是显式示例，不是所有项目都必须采用的默认目录规范。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 11.0.0
class_name GFProjectLayoutPlanner
extends RefCounted


# --- 常量 ---

## Feature 内聚式项目结构示例 profile 路径。
## [br]
## @api public
## [br]
## @since 11.0.0
const EXAMPLE_FEATURE_COHESIVE_PROFILE_PATH: String = "res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json"

## 用于读取有界 JSON 对象的解析器脚本。
## [br]
## @api private
## [br]
const _BOUNDED_JSON_OBJECT_READER_SCRIPT = preload(
	"res://addons/gf/kernel/core/gf_bounded_json_object_reader.gd"
)

## Project Layout analysis 与库存契约实现脚本。
## [br]
## @api private
## [br]
const _ANALYSIS_CONTRACT_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_analysis_contract.gd"
)

## Project Layout profile 编译器实现脚本。
## [br]
## @api private
## [br]
const _PROFILE_COMPILER_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_profile_compiler.gd")

## Planner 识别的 Feature 契约规则 kind。
## [br]
## @api private
## [br]
const _RULE_FEATURE_MODULE_CONTRACT: String = "feature_module_contract"

## Project Layout profile compiler contract 标识符。
## [br]
## @api private
## [br]
const _PROFILE_CONTRACT_ID: String = "gf.project_layout.profile.v1"

## Planner 输出报告的 kind 值。
## [br]
## @api private
## [br]
const _PLAN_KIND: String = "project_layout_plan"

## Planner 输出报告的 schema 版本。
## [br]
## @api private
## [br]
const _PLAN_SCHEMA_VERSION: int = 1

## Planner 接受的 options 字段名集合。
## [br]
## @api private
## [br]
const _OPTION_FIELDS: PackedStringArray = [
	"feature_ids",
	"include_optional_zones",
	"include_optional_feature_subdirs",
]

## Planner options 中类型为 bool 的字段名集合。
## [br]
## @api private
## [br]
const _BOOL_OPTION_FIELDS: PackedStringArray = [
	"include_optional_zones",
	"include_optional_feature_subdirs",
]

## options 中会影响 Feature 目标路径的字段名集合。
## [br]
## @api private
## [br]
const _FEATURE_PATH_OPTION_FIELDS: PackedStringArray = ["include_optional_feature_subdirs"]

## options 字典允许的最大字段数。
## [br]
## @api private
## [br]
const _MAX_OPTION_FIELDS: int = 3

## 单次规划允许的最大 feature_ids 数。
## [br]
## @api private
## [br]
const _MAX_FEATURE_IDS: int = 256

## 编译 profile 中允许的最大 Feature 契约规则数。
## [br]
## @api private
## [br]
const _MAX_FEATURE_CONTRACTS: int = 256

## feature id 允许的最大字符数。
## [br]
## @api private
## [br]
const _MAX_FEATURE_ID_LENGTH: int = 256

## Planner 接受的路径字段允许的最大字符数。
## [br]
## @api private
## [br]
const _MAX_PLANNER_PATH_LENGTH: int = 16_379

## 候选目标路径集合允许的最大元素数。
## [br]
## @api private
## [br]
const _MAX_CANDIDATE_PATHS: int = 1_024

## 计划步骤数组允许的最大元素数。
## [br]
## @api private
## [br]
const _MAX_PLAN_STEPS: int = 1_024

## blocker 数组允许的最大元素数。
## [br]
## @api private
## [br]
const _MAX_PLAN_BLOCKERS: int = 1_024

## 计划诊断数组允许的最大元素数。
## [br]
## @api private
## [br]
const _MAX_PLAN_DIAGNOSTICS: int = 256

## 不含 analysis contract 校验的 Planner 工作量上限。
## [br]
## @api private
## [br]
const _MAX_PLANNER_OWN_WORK_UNITS: int = 2_000_000

## Planner runtime 工作量检查间允许累计的工作单位数。
## [br]
## @api private
## [br]
const _RUNTIME_CANCEL_POLL_INTERVAL: int = 64

## profile compilation envelope 遍历允许检查的最大结构值数。
## [br]
## @api private
## [br]
const _MAX_COMPILATION_STRUCTURE_VALUES: int = 200_000

## profile compilation envelope 遍历允许的最大嵌套深度。
## [br]
## @api private
## [br]
const _MAX_COMPILATION_DEPTH: int = 65

## profile compilation envelope 单个容器允许的最大元素数。
## [br]
## @api private
## [br]
const _MAX_COMPILATION_COLLECTION_ITEMS: int = 8_192

## profile compilation envelope 字符串允许的最大字符数。
## [br]
## @api private
## [br]
const _MAX_COMPILATION_STRING_LENGTH: int = _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH

## Planner 接受的 compilation 字段名集合。
## [br]
## @api private
## [br]
const _COMPILATION_FIELDS: PackedStringArray = [
	"success",
	"profile",
	"issues",
	"error_count",
	"warning_count",
	"contract_id",
	"contract_digest",
	"capabilities",
]

## compilation issue 字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _COMPILATION_ISSUE_FIELDS: PackedStringArray = [
	"severity",
	"kind",
	"reason_code",
	"path",
	"message",
	"context",
]

## compilation capability 字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _COMPILATION_CAPABILITY_FIELDS: PackedStringArray = [
	"executor_id",
	"operation",
	"rule_kinds",
	"rule_fields",
	"zone_fields",
]

## compiled profile 字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _COMPILED_PROFILE_FIELDS: PackedStringArray = [
	"schema_version",
	"id",
	"display_name",
	"description",
	"zones",
	"rules",
	"metadata",
]

## compiled zone 字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _COMPILED_ZONE_FIELDS: PackedStringArray = [
	"id",
	"description",
	"roots",
	"required",
	"allow_extensions",
	"deny_extensions",
	"exclude",
	"severity",
	"metadata",
]

## 各 compiled rule 共用的字段名集合。
## [br]
## @api private
## [br]
const _COMPILED_RULE_COMMON_FIELDS: PackedStringArray = [
	"id",
	"description",
	"kind",
	"severity",
	"metadata",
]

## 旧式 compiled rule 可选择携带的兼容字段名集合。
## [br]
## @api private
## [br]
const _COMPILED_RULE_COMPATIBILITY_FIELDS: PackedStringArray = [
	"paths",
	"any",
	"extensions",
]

## 各 compiled rule kind 对应的专属字段名集合。
## [br]
## @api private
## [br]
const _COMPILED_RULE_FIELDS_BY_KIND: Dictionary = {
	"path_exists": ["paths", "any"],
	"files_under_roots": ["roots", "include", "exclude", "extensions"],
	"extension_allowlist": ["roots", "include", "exclude", "extensions"],
	"extension_denylist": ["roots", "include", "exclude", "extensions"],
	"forbid_root_files": ["allowed_files"],
	"naming_convention": ["roots", "exclude", "pattern", "target"],
	"feature_module_contract": [
		"roots",
		"feature_id_pattern",
		"required_subdirs",
		"allowed_subdirs",
		"allow_root_files",
	],
	"generated_boundary": ["include", "roots"],
	"bucket_size": ["roots", "max_files"],
}

## runtime 配置字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _RUNTIME_FIELDS: PackedStringArray = ["cancel_check", "max_work_units"]

## Planner 完整校验最大 analysis 后仍可使用的不可关闭总工作量上限。
##
## 总量由 AnalysisContract 的唯一校验硬上限与 Planner 自身候选、阻塞项和计划步骤
## 上限相加得到；runtime 只能收紧该值，不能放大。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
const MAX_WORK_UNITS: int = (
	_ANALYSIS_CONTRACT_SCRIPT.MAX_VALIDATION_WORK_UNITS
	+ _MAX_PLANNER_OWN_WORK_UNITS
)


# --- 私有变量 ---

## 当前规划操作累计消费的工作单位数。
## [br]
## @api private
## [br]
var _planner_work_units: int = 0

## 当前规划操作生效的总工作量上限。
## [br]
## @api private
## [br]
var _planner_max_work_units: int = MAX_WORK_UNITS

## 当前规划操作的取消检查回调。
## [br]
## @api private
## [br]
var _planner_cancel_check: Callable = Callable()

## 当前 runtime 配置是否启用了取消回调。
## [br]
## @api private
## [br]
var _planner_cancel_configured: bool = false

## 自上次取消检查后累计的工作单位数。
## [br]
## @api private
## [br]
var _planner_units_since_cancel_check: int = 0

## 当前规划操作是否已进入终止状态。
## [br]
## @api private
## [br]
var _planner_terminal: bool = false

## 当前正在构建的计划字典。
## [br]
## @api private
## [br]
var _active_plan: Dictionary = {}

## 当前计划已接纳的候选路径集合。
## [br]
## @api private
## [br]
var _candidate_path_set: Dictionary = {}

## 当前计划要求处理的 Feature ID 列表。
## [br]
## @api private
## [br]
var _active_feature_ids: PackedStringArray = PackedStringArray()


# --- 公共方法 ---

## 按 Feature 内聚式示例 profile 生成只读改进计划。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param source_analysis: GFProjectLayoutAnalyzer 返回的完整只读分析快照。
## [br]
## @schema source_analysis: Dictionary，必须是 GFProjectLayoutAnalyzer 生成并通过闭合 analysis/graph contract 的完整报告，不能手工拼装字段子集。
## [br]
## @param options: 规划选项。
## [br]
## @schema options: Dictionary，可包含 feature_ids、include_optional_zones 和 include_optional_feature_subdirs。
## [br]
## @return: 闭合的只读计划。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、complete、profile_id、source_analysis_digest、contract_digest、project_root、capabilities、steps、blockers 和 issues；capabilities 精确包含 writes_project、planning_scope、supported_rule_kinds 和 ignored_rule_kinds；每个 step 精确包含 step_id、kind、relative_path、requires、evidence_ids、preconditions 和 risk。
func plan_example_profile(source_analysis: Dictionary, options: Dictionary = {}) -> Dictionary:
	return plan_profile_path(EXAMPLE_FEATURE_COHESIVE_PROFILE_PATH, source_analysis, options)


## 从项目结构 profile 文件生成只读改进计划。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param profile_path: JSON profile 路径。
## [br]
## @param source_analysis: GFProjectLayoutAnalyzer 返回的完整只读分析快照。
## [br]
## @schema source_analysis: Dictionary，必须是 GFProjectLayoutAnalyzer 生成并通过闭合 analysis/graph contract 的完整报告，不能手工拼装字段子集。
## [br]
## @param options: 规划选项。
## [br]
## @schema options: Dictionary，可包含 feature_ids、include_optional_zones 和 include_optional_feature_subdirs。
## [br]
## @return: 闭合的只读计划。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、complete、profile_id、source_analysis_digest、contract_digest、project_root、capabilities、steps、blockers 和 issues；capabilities 精确包含 writes_project、planning_scope、supported_rule_kinds 和 ignored_rule_kinds；每个 step 精确包含 step_id、kind、relative_path、requires、evidence_ids、preconditions 和 risk。
func plan_profile_path(
	profile_path: String,
	source_analysis: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	_begin_planner_operation()
	var plan: Dictionary = _make_plan()
	_active_plan = plan
	if not _options_are_intrinsically_admissible(options, false):
		_fail_planner_resource_limit()
		return _finalize_plan(plan, false)
	_validate_options(options, plan)
	if _planner_terminal:
		return _finalize_plan(plan, false)
	_validate_source_analysis(source_analysis, plan)
	if _planner_terminal or _has_error_issue(plan):
		return _finalize_plan(plan, false)
	if profile_path.length() > _MAX_PLANNER_PATH_LENGTH:
		_fail_planner_resource_limit()
		return _finalize_plan(plan, false)
	if not _is_canonical_resource_path(profile_path):
		_add_issue(plan, "error", "invalid_profile_path", "", "项目结构 profile 路径必须是规范 res:// 文件路径。")
		return _finalize_plan(plan, false)
	var load_result: Dictionary = _load_profile(profile_path)
	if not _get_bool(load_result, "success"):
		var loaded_profile_path: String = _get_string(load_result, "source_path", profile_path)
		_add_issue(
			plan,
			"error",
			_get_string(load_result, "kind", "profile_load_failed"),
			loaded_profile_path,
			_get_string(load_result, "error", "项目结构 profile 读取失败。"),
			{ "profile_path": loaded_profile_path }
		)
		return _finalize_plan(plan, false)

	var profile_value: Variant = load_result.get("profile", {})
	if profile_value is Dictionary:
		var profile: Dictionary = profile_value
		return plan_profile(profile, source_analysis, options)

	_add_issue(plan, "error", "invalid_profile", profile_path, "项目结构 profile 必须是 Dictionary。")
	return _finalize_plan(plan, false)


## 按已解析的项目结构 profile 生成只读改进计划。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param profile: 项目结构 profile 字典。
## [br]
## @schema profile: Dictionary，包含 schema_version、id、zones 和 rules。
## [br]
## @param source_analysis: GFProjectLayoutAnalyzer 返回的完整只读分析快照。
## [br]
## @schema source_analysis: Dictionary，必须是 GFProjectLayoutAnalyzer 生成并通过闭合 analysis/graph contract 的完整报告，不能手工拼装字段子集。
## [br]
## @param options: 规划选项。
## [br]
## @schema options: Dictionary，可包含 feature_ids、include_optional_zones 和 include_optional_feature_subdirs。
## [br]
## @return: 闭合的只读计划。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、complete、profile_id、source_analysis_digest、contract_digest、project_root、capabilities、steps、blockers 和 issues；capabilities 精确包含 writes_project、planning_scope、supported_rule_kinds 和 ignored_rule_kinds；每个 step 精确包含 step_id、kind、relative_path、requires、evidence_ids、preconditions 和 risk。
func plan_profile(
	profile: Dictionary,
	source_analysis: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var compile_result: Dictionary = _compile_profile(
		profile,
		_make_planner_registry()
	)
	return plan_compiled_profile_analysis(
		compile_result,
		source_analysis,
		options,
		{}
	)


## 根据 Feature 模块契约计算某个 Feature 的相对目录并集。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param profile: 项目结构 profile 字典。
## [br]
## @schema profile: Dictionary，包含一条或多条 feature_module_contract 规则。
## [br]
## @param feature_id: Feature 模块 ID。
## [br]
## @param options: 计算选项。
## [br]
## @schema options: Dictionary，可包含 include_optional_feature_subdirs。
## [br]
## @return: 去重后的相对目录列表，例如 features/inventory/scripts。
func make_feature_module_paths(
	profile: Dictionary,
	feature_id: String,
	options: Dictionary = {}
) -> PackedStringArray:
	_begin_planner_operation()
	if (
		not _options_are_intrinsically_admissible(options, true)
		or feature_id.length() > _MAX_FEATURE_ID_LENGTH
		or not _consume_planner_work(1 + feature_id.length())
		or not _feature_path_options_are_valid(options)
	):
		return PackedStringArray()
	var compile_result: Dictionary = _compile_profile(profile, _make_planner_registry())
	if not _get_bool(compile_result, "success"):
		return PackedStringArray()
	var compiled_profile: Dictionary = _get_dictionary(compile_result, "profile")
	var result: PackedStringArray = _make_feature_module_paths_from_compiled_profile(
		compiled_profile,
		feature_id,
		options
	)
	return PackedStringArray() if _planner_terminal else result


# --- 框架内部方法 ---

## 基于已验证 compilation 与完整冻结 analysis graph 生成纯只读计划。
##
## 该入口不加载 profile/contract、不计算文件摘要，也不读取当前文件系统；适合把
## Analyzer 产生的 data-only compilation 与 analysis 一起交给后台 worker。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param compilation: canonical compiler 返回的 Analyzer 或 Planner compilation。
## [br]
## @schema compilation: Dictionary，字段闭集为 success、profile、issues、error_count、warning_count、contract_id、contract_digest 和 capabilities；成功结果必须精确绑定 canonical contract 规范 SHA-256 与受支持 executor capability。
## [br]
## @param source_analysis: GFProjectLayoutAnalyzer 返回的完整冻结分析快照。
## [br]
## @schema source_analysis: Dictionary，必须通过闭合 analysis/graph contract；规划决策只使用该图。
## [br]
## @param options: 规划选项。
## [br]
## @schema options: Dictionary，可包含 feature_ids、include_optional_zones 和 include_optional_feature_subdirs。
## [br]
## @param runtime: 协作式取消与工作量边界。
## [br]
## @schema runtime: Dictionary，省略时为 {}；非空时字段闭集精确为 cancel_check 和 max_work_units，cancel_check 为零参数 Callable，max_work_units 只能收紧固有上限。
## [br]
## @return: 闭合的 data-only 只读计划。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、complete、profile_id、source_analysis_digest、contract_digest、project_root、capabilities、steps、blockers 和 issues。
func plan_compiled_profile_analysis(
	compilation: Dictionary,
	source_analysis: Dictionary,
	options: Dictionary = {},
	runtime: Dictionary = {}
) -> Dictionary:
	_begin_planner_operation()
	var plan: Dictionary = _make_plan()
	_active_plan = plan
	if not _configure_planner_runtime(runtime):
		return _finalize_plan(plan, false)
	if not _options_are_intrinsically_admissible(options, false):
		_fail_planner_resource_limit()
		return _finalize_plan(plan, false)
	_validate_options(options, plan)
	if _planner_terminal:
		return _finalize_plan(plan, false)
	if not _planning_compilation_is_valid(compilation, plan):
		return _finalize_plan(plan, false)
	_append_compiler_result(compilation, plan)
	if _planner_terminal or not _get_bool(compilation, "success"):
		return _finalize_plan(plan, false)
	_validate_source_analysis(source_analysis, plan)
	if _planner_terminal or _has_error_issue(plan):
		return _finalize_plan(plan, false)
	var planner_registry: Dictionary = _make_planner_registry()

	var compiled_profile: Dictionary = _get_dictionary(compilation, "profile")
	plan["profile_id"] = _get_string(compiled_profile, "id")
	_validate_feature_planning_inputs(compiled_profile, options, plan)
	if _has_error_issue(plan):
		return _finalize_plan(plan, false)

	var candidate_paths: PackedStringArray = PackedStringArray()
	_queue_zone_paths(compiled_profile, options, candidate_paths)
	_queue_feature_paths(compiled_profile, options, planner_registry, candidate_paths, plan)
	if _has_error_issue(plan):
		return _finalize_plan(plan, false)

	_plan_candidate_paths(candidate_paths, plan)
	return _finalize_plan(plan, true)


# --- 私有/辅助方法 ---

## 创建默认不完整的只读目录候选计划，并预留仅供规划过程使用的来源索引；导出前须移除该索引。
## [br]
## @api private
func _make_plan() -> Dictionary:
	return {
		"schema_version": _PLAN_SCHEMA_VERSION,
		"kind": _PLAN_KIND,
		"complete": false,
		"profile_id": "",
		"source_analysis_digest": "",
		"contract_digest": "",
		"project_root": "",
		"capabilities": {
			"writes_project": false,
			"planning_scope": "directory_candidates_only",
			"supported_rule_kinds": [],
			"ignored_rule_kinds": [],
		},
		"steps": [],
		"blockers": [],
		"issues": [],
		"_source_analysis_index": {},
	}


## 创建本实例的 feature_module_contract 处理器注册表，仅声明规划器实际消费的字段。
## [br]
## @api private
func _make_planner_registry() -> Dictionary:
	return {
		_RULE_FEATURE_MODULE_CONTRACT: {
			"handler": Callable(self, "_queue_feature_contract"),
			"executed_fields": PackedStringArray([
				"roots",
				"feature_id_pattern",
				"required_subdirs",
				"allowed_subdirs",
			]),
		},
	}


## 以规划执行器身份编译 profile，未实现规则仅校验 schema，并限定实际执行的 zone 字段。
## [br]
## @api private
func _compile_profile(profile: Dictionary, planner_registry: Dictionary) -> Dictionary:
	var compiler: _PROFILE_COMPILER_SCRIPT = _PROFILE_COMPILER_SCRIPT.new()
	return compiler.compile_profile(
		profile,
		{
			"executor_id": "godot_project_layout_planner",
			"operation": "plan",
			"rule_registry": planner_registry,
			"unsupported_rule_policy": "schema_only",
			"zone_executed_fields": PackedStringArray(["roots", "required"]),
		}
	)


## 按工作预算汇总支持和忽略的规则种类，成功编译才接管契约摘要，再将编译诊断投影到计划。
## [br]
## @api private
func _append_compiler_result(compile_result: Dictionary, plan: Dictionary) -> void:
	var plan_capabilities: Dictionary = _get_dictionary(plan, "capabilities")
	var supported_rule_kinds: PackedStringArray = PackedStringArray()
	for kind_value: Variant in _make_planner_registry().keys():
		var kind: String = _string_value(kind_value)
		if not kind.is_empty():
			var _append_supported_kind: bool = supported_rule_kinds.append(kind)
	var ignored_rule_kinds: PackedStringArray = PackedStringArray()
	var compiled_profile: Dictionary = _get_dictionary(compile_result, "profile")
	for rule_value: Variant in _get_array(compiled_profile, "rules"):
		if not _consume_planner_work():
			return
		if not rule_value is Dictionary:
			continue
		var rule: Dictionary = rule_value
		var rule_kind: String = _get_string(rule, "kind")
		if (
			not rule_kind.is_empty()
			and not supported_rule_kinds.has(rule_kind)
			and not ignored_rule_kinds.has(rule_kind)
		):
			var _append_ignored_kind: bool = ignored_rule_kinds.append(rule_kind)
	supported_rule_kinds.sort()
	ignored_rule_kinds.sort()
	plan_capabilities["supported_rule_kinds"] = Array(supported_rule_kinds)
	plan_capabilities["ignored_rule_kinds"] = Array(ignored_rule_kinds)
	if _get_bool(compile_result, "success"):
		plan["contract_digest"] = _get_string(compile_result, "contract_digest")
	for issue_value: Variant in _get_array(compile_result, "issues"):
		if not _consume_planner_work():
			return
		if not issue_value is Dictionary:
			continue
		var issue: Dictionary = issue_value
		_add_issue(
			plan,
			_get_string(issue, "severity", "error"),
			_get_string(issue, "kind", "profile_contract_invalid"),
			_get_string(issue, "path"),
			_get_string(issue, "message", "项目结构 profile 编译失败。"),
			_get_dictionary(issue, "context"),
			_get_string(issue, "reason_code")
		)


## 验证有界编译信封、诊断计数和受支持执行器能力；成功结果还必须绑定当前框架契约及有效规范 profile。
## [br]
## @api private
func _planning_compilation_is_valid(
	compilation: Dictionary,
	plan: Dictionary
) -> bool:
	if not _compilation_envelope_is_admissible(compilation):
		if not _planner_terminal:
			_add_invalid_compilation_issue(plan, "compilation 不是有界 data-only 值。")
		return false
	if (
		compilation.size() != _COMPILATION_FIELDS.size()
		or not _dictionary_has_only_fields(compilation, _COMPILATION_FIELDS)
		or not compilation.get("success") is bool
		or not compilation.get("profile") is Dictionary
		or not compilation.get("issues") is Array
		or not compilation.get("error_count") is int
		or not compilation.get("warning_count") is int
		or not compilation.get("contract_id") is String
		or not compilation.get("contract_digest") is String
		or not compilation.get("capabilities") is Dictionary
	):
		_add_invalid_compilation_issue(plan, "compilation 顶层字段必须精确闭合且类型正确。")
		return false
	var expected_error_count: int = 0
	var expected_warning_count: int = 0
	for issue_value: Variant in _get_array(compilation, "issues"):
		if not _consume_planner_work():
			return false
		if not issue_value is Dictionary:
			_add_invalid_compilation_issue(plan, "compilation issue 必须是 Dictionary。")
			return false
		var issue: Dictionary = issue_value
		if (
			issue.size() != _COMPILATION_ISSUE_FIELDS.size()
			or not _dictionary_has_only_fields(issue, _COMPILATION_ISSUE_FIELDS)
			or not issue.get("severity") is String
			or not issue.get("kind") is String
			or not issue.get("reason_code") is String
			or not issue.get("path") is String
			or not issue.get("message") is String
			or not issue.get("context") is Dictionary
		):
			_add_invalid_compilation_issue(plan, "compilation issue 字段无效。")
			return false
		var severity: String = issue["severity"]
		if severity == "error":
			expected_error_count += 1
		elif severity == "warning":
			expected_warning_count += 1
		else:
			_add_invalid_compilation_issue(plan, "compilation issue severity 无效。")
			return false
	if (
		_get_int(compilation, "error_count", -1) != expected_error_count
		or _get_int(compilation, "warning_count", -1) != expected_warning_count
		or _get_bool(compilation, "success") != (expected_error_count == 0)
	):
		_add_invalid_compilation_issue(plan, "compilation success 与诊断计数不一致。")
		return false
	var contract_id: String = _get_string(compilation, "contract_id")
	var contract_digest: String = _get_string(compilation, "contract_digest")
	if not contract_id.is_empty() and contract_id != _PROFILE_CONTRACT_ID:
		_add_invalid_compilation_issue(plan, "compilation contract identity 无效。")
		return false
	if (
		not contract_digest.is_empty()
		and not _PROFILE_COMPILER_SCRIPT.contract_digest_is_canonical_for_framework(
			contract_digest
		)
	):
		_add_invalid_compilation_issue(plan, "compilation contract digest 无效。")
		return false
	var capabilities: Dictionary = _get_dictionary(compilation, "capabilities")
	if (
		not capabilities.is_empty()
		and (
			capabilities.size() != _COMPILATION_CAPABILITY_FIELDS.size()
			or not _dictionary_has_only_fields(
				capabilities,
				_COMPILATION_CAPABILITY_FIELDS
			)
			or (
				capabilities != _expected_planner_compilation_capabilities()
				and capabilities != _expected_analyzer_compilation_capabilities()
			)
		)
	):
		_add_invalid_compilation_issue(plan, "compilation capabilities 未绑定受支持 executor registry。")
		return false
	if not _get_bool(compilation, "success"):
		return true
	if (
		contract_id != _PROFILE_CONTRACT_ID
		or not _PROFILE_COMPILER_SCRIPT.contract_digest_is_canonical_for_framework(
			contract_digest
		)
		or capabilities.is_empty()
		or not _compiled_profile_is_valid_for_planning(
			_get_dictionary(compilation, "profile"),
			capabilities
		)
	):
		_add_invalid_compilation_issue(plan, "成功 compilation 未绑定有效 contract、capabilities 或 normalized profile。")
		return false
	return true


## 用显式栈验证纯数据、深度及集合边界，文本长度和字节工作量均计费；活动引用栈拒绝循环，允许分支共享容器。
## [br]
## @api private
func _compilation_envelope_is_admissible(compilation: Dictionary) -> bool:
	var stack: Array = [{ "value": compilation, "depth": 0, "exit": false }]
	var active_containers: Array = []
	var structure_value_count: int = 0
	while not stack.is_empty():
		var frame_value: Variant = stack.pop_back()
		if not frame_value is Dictionary:
			return false
		var frame: Dictionary = frame_value
		var value: Variant = frame.get("value")
		if _get_bool(frame, "exit"):
			if not active_containers.is_empty():
				var _removed_container: Variant = active_containers.pop_back()
			continue
		if not _consume_planner_work():
			return false
		structure_value_count += 1
		if structure_value_count > _MAX_COMPILATION_STRUCTURE_VALUES:
			return false
		var depth: int = _get_int(frame, "depth")
		if depth > _MAX_COMPILATION_DEPTH:
			return false
		if value == null or value is bool or value is int:
			continue
		if value is float:
			var float_value: float = value
			if not is_finite(float_value):
				return false
			continue
		if value is String:
			var text: String = value
			if text.length() > _MAX_COMPILATION_STRING_LENGTH:
				return false
			if not _consume_planner_work(ceili(float(text.to_utf8_buffer().size()) / 256.0)):
				return false
			continue
		if value is PackedStringArray:
			var packed_values: PackedStringArray = value
			if packed_values.size() > _MAX_COMPILATION_COLLECTION_ITEMS:
				return false
			for text: String in packed_values:
				structure_value_count += 1
				if (
					structure_value_count > _MAX_COMPILATION_STRUCTURE_VALUES
					or text.length() > _MAX_COMPILATION_STRING_LENGTH
					or not _consume_planner_work(
						1 + ceili(float(text.to_utf8_buffer().size()) / 256.0)
					)
				):
					return false
			continue
		if value is Dictionary:
			var dictionary_value: Dictionary = value
			if (
				dictionary_value.size() > _MAX_COMPILATION_COLLECTION_ITEMS
				or _active_container_exists(active_containers, dictionary_value)
			):
				return false
			active_containers.append(dictionary_value)
			stack.append({ "value": dictionary_value, "depth": depth, "exit": true })
			var keys: Array = dictionary_value.keys()
			for key_index: int in range(keys.size() - 1, -1, -1):
				var key: Variant = keys[key_index]
				if not key is String:
					return false
				stack.append({ "value": dictionary_value[key], "depth": depth + 1, "exit": false })
				stack.append({ "value": key, "depth": depth + 1, "exit": false })
			continue
		if value is Array:
			var array_value: Array = value
			if (
				array_value.size() > _MAX_COMPILATION_COLLECTION_ITEMS
				or _active_container_exists(active_containers, array_value)
			):
				return false
			active_containers.append(array_value)
			stack.append({ "value": array_value, "depth": depth, "exit": true })
			for item_index: int in range(array_value.size() - 1, -1, -1):
				stack.append({ "value": array_value[item_index], "depth": depth + 1, "exit": false })
			continue
		return false
	return true


## 按引用身份查找当前递归路径上的容器，用于区分循环和非循环共享。
## [br]
## @api private
func _active_container_exists(active_containers: Array, value: Variant) -> bool:
	for active_value: Variant in active_containers:
		if is_same(active_value, value):
			return true
	return false


## 检查规范 profile、zone 和规则的允许字段及类型；分析器结果还须满足其能力列表，功能模块规则另作路径字段校验。
## [br]
## @api private
func _compiled_profile_is_valid_for_planning(
	profile: Dictionary,
	capabilities: Dictionary
) -> bool:
	if (
		not _dictionary_has_only_fields(profile, _COMPILED_PROFILE_FIELDS)
		or profile.get("schema_version") != 1
		or not _is_non_empty_string_value(profile.get("id"))
		or not profile.get("zones") is Array
		or not profile.get("rules") is Array
	):
		return false
	for optional_text_field: String in ["display_name", "description"]:
		if profile.has(optional_text_field) and not profile[optional_text_field] is String:
			return false
	if profile.has("metadata") and not profile["metadata"] is Dictionary:
		return false
	for zone_value: Variant in _get_array(profile, "zones"):
		if not _consume_planner_work() or not zone_value is Dictionary:
			return false
		var zone: Dictionary = zone_value
		if (
			not _dictionary_has_only_fields(zone, _COMPILED_ZONE_FIELDS)
			or not _is_non_empty_string_value(zone.get("id"))
			or not zone.get("required") is bool
			or not _compiled_string_collection_is_valid(zone.get("roots"), false, true)
		):
			return false
		if zone.has("severity") and not _valid_severity_value(zone["severity"]):
			return false
		if zone.has("metadata") and not zone["metadata"] is Dictionary:
			return false
	var allowed_capability_rule_kinds: PackedStringArray = _get_string_list(
		capabilities,
		"rule_kinds"
	)
	var analyzer_compilation: bool = capabilities == _expected_analyzer_compilation_capabilities()
	for rule_value: Variant in _get_array(profile, "rules"):
		if not _consume_planner_work() or not rule_value is Dictionary:
			return false
		var rule: Dictionary = rule_value
		var kind: String = _get_string(rule, "kind")
		if (
			not _is_non_empty_string_value(rule.get("id"))
			or not _COMPILED_RULE_FIELDS_BY_KIND.has(kind)
			or (analyzer_compilation and not allowed_capability_rule_kinds.has(kind))
		):
			return false
		var allowed_fields: PackedStringArray = _COMPILED_RULE_COMMON_FIELDS.duplicate()
		for field_name: String in _COMPILED_RULE_COMPATIBILITY_FIELDS:
			if not allowed_fields.has(field_name):
				var _append_compatibility_field: bool = allowed_fields.append(field_name)
		for field_value: Variant in _COMPILED_RULE_FIELDS_BY_KIND[kind]:
			var field_name: String = _string_value(field_value)
			if not field_name.is_empty() and not allowed_fields.has(field_name):
				var _append_kind_field: bool = allowed_fields.append(field_name)
		if not _dictionary_has_only_fields(rule, allowed_fields):
			return false
		if rule.has("severity") and not _valid_severity_value(rule["severity"]):
			return false
		if rule.has("metadata") and not rule["metadata"] is Dictionary:
			return false
		if kind == _RULE_FEATURE_MODULE_CONTRACT and not _feature_contract_is_valid(rule):
			return false
	return true


## 要求功能根和 ID 模式存在，按需验证必需、允许子目录及根文件开关；本层不编译正则。
## [br]
## @api private
func _feature_contract_is_valid(rule: Dictionary) -> bool:
	return (
		_compiled_string_collection_is_valid(rule.get("roots"), false, true)
		and rule.get("feature_id_pattern") is String
		and not _get_string(rule, "feature_id_pattern").is_empty()
		and (
			not rule.has("required_subdirs")
			or _compiled_string_collection_is_valid(
				rule.get("required_subdirs"),
				true,
				true
			)
		)
		and (
			not rule.has("allowed_subdirs")
			or _compiled_string_collection_is_valid(
				rule.get("allowed_subdirs"),
				true,
				true
			)
		)
		and (
			not rule.has("allow_root_files")
			or rule.get("allow_root_files") is bool
		)
	)


## 接受 Array 或 PackedStringArray，按预算检查非空文本及重复项，并可要求规范相对路径；空集合是否允许由调用者指定。
## [br]
## @api private
func _compiled_string_collection_is_valid(
	value: Variant,
	allow_empty: bool,
	require_relative_paths: bool
) -> bool:
	if not (value is Array or value is PackedStringArray):
		return false
	var values: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		var packed_values: PackedStringArray = value
		values = packed_values
	else:
		var array_values: Array = value
		for item: Variant in array_values:
			if not _consume_planner_work() or not item is String:
				return false
			var text: String = item
			var _append_text: bool = values.append(text)
	if values.is_empty() and not allow_empty:
		return false
	var seen: Dictionary = {}
	for text: String in values:
		if (
			not _consume_planner_work(1 + text.length())
			or text.strip_edges().is_empty()
			or seen.has(text)
			or (
				require_relative_paths
				and _PROFILE_COMPILER_SCRIPT._profile_relative_path_is_invalid(text)
			)
		):
			return false
		seen[text] = true
	return true


## 返回规划器接受的精确能力身份和字段集合，用于阻止编译信封冒用其他执行范围。
## [br]
## @api private
func _expected_planner_compilation_capabilities() -> Dictionary:
	return {
		"executor_id": "godot_project_layout_planner",
		"operation": "plan",
		"rule_kinds": ["feature_module_contract"],
		"rule_fields": {
			"feature_module_contract": [
				"allowed_subdirs",
				"feature_id_pattern",
				"required_subdirs",
				"roots",
			],
		},
		"zone_fields": ["required", "roots"],
	}


## 返回可复用分析器编译结果的精确能力声明，规划只消费其中已实现的目录候选规则。
## [br]
## @api private
func _expected_analyzer_compilation_capabilities() -> Dictionary:
	return {
		"executor_id": "godot_project_layout_analyzer",
		"operation": "analyze",
		"rule_kinds": [
			"bucket_size",
			"feature_module_contract",
			"forbid_root_files",
			"generated_boundary",
			"naming_convention",
		],
		"rule_fields": {
			"bucket_size": ["max_files", "roots", "severity"],
			"feature_module_contract": [
				"allow_root_files",
				"allowed_subdirs",
				"feature_id_pattern",
				"required_subdirs",
				"roots",
				"severity",
			],
			"forbid_root_files": ["allowed_files", "severity"],
			"generated_boundary": ["include", "roots", "severity"],
			"naming_convention": ["exclude", "pattern", "roots", "severity", "target"],
		},
		"zone_fields": ["required", "roots", "severity"],
	}


## 通过统一诊断入口记录固定种类和原因码的编译信封失败。
## [br]
## @api private
func _add_invalid_compilation_issue(plan: Dictionary, message: String) -> void:
	_add_issue(
		plan,
		"error",
		"invalid_profile_compilation",
		"",
		message,
		{},
		"PROJECT_LAYOUT_PROFILE_COMPILATION_INVALID"
	)


## 有界读取 JSON profile，将缺失、读取和根类型错误映射为规划诊断；成功保留读取器返回的字典及源路径。
## [br]
## @api private
func _load_profile(profile_path: String) -> Dictionary:
	if profile_path.strip_edges().is_empty():
		return _make_load_result(false, {}, "missing_profile_path", "项目结构 profile 路径为空。", profile_path)

	var read_result: Dictionary = _BOUNDED_JSON_OBJECT_READER_SCRIPT.read_object(profile_path)
	var source_path: String = _get_string(read_result, "source_path", profile_path)
	if not _get_bool(read_result, "ok"):
		var error_kind: String = _get_string(read_result, "error_kind")
		if error_kind == "open_failed" and not FileAccess.file_exists(source_path):
			return _make_load_result(false, {}, "profile_path_not_found", "项目结构 profile 不存在：%s。" % source_path, source_path)
		if error_kind == "open_failed" or error_kind == "read_failed":
			return _make_load_result(
				false,
				{},
				"profile_open_failed",
				"无法读取项目结构 profile：%s。%s" % [source_path, _get_string(read_result, "error")],
				source_path
			)
		if error_kind == "invalid_root_type":
			return _make_load_result(false, {}, "invalid_profile_root", "项目结构 profile 根节点必须是 Dictionary。", source_path)
		return _make_load_result(
			false,
			{},
			"profile_json_parse_failed",
			"项目结构 profile JSON 解析失败：%s" % _get_string(read_result, "error", "输入超过读取边界或格式无效。"),
			source_path
		)

	var profile_value: Variant = read_result.get("data", {})
	if profile_value is Dictionary:
		var profile: Dictionary = profile_value
		return _make_load_result(true, profile, "", "", source_path)
	return _make_load_result(false, {}, "invalid_profile_root", "项目结构 profile 根节点必须是 Dictionary。", source_path)


## 包装 profile 读取结果和来源路径，借用 profile 引用，不在此复制或校验内容。
## [br]
## @api private
func _make_load_result(
	success: bool,
	profile: Dictionary,
	kind: String,
	message: String,
	source_path: String
) -> Dictionary:
	return {
		"success": success,
		"profile": profile,
		"kind": kind,
		"error": message,
		"source_path": source_path,
	}


## 仅接受输入与评估都完整的分析，经闭合契约校验后保存来源摘要、根及内部查询索引。
## [br]
## @api private
func _validate_source_analysis(source_analysis: Dictionary, plan: Dictionary) -> void:
	if not _get_bool(source_analysis, "evaluation_complete") or not _get_bool(source_analysis, "input_complete"):
		_add_issue(plan, "error", "incomplete_source_analysis", "", "分析快照不完整，不能生成可信计划。")
		return
	var contract: _ANALYSIS_CONTRACT_SCRIPT = _ANALYSIS_CONTRACT_SCRIPT.new()
	var validation: Dictionary = contract.validate_and_index(
		source_analysis,
		Callable(self, "_planner_checkpoint_allows")
	)
	if _planner_terminal:
		return
	if not _get_bool(validation, "valid"):
		_add_issue(plan, "error", "invalid_source_analysis", "", "分析快照不符合闭合 Project Layout analysis/graph 契约。")
		return
	plan["source_analysis_digest"] = _get_string(source_analysis, "input_digest")
	plan["project_root"] = _normalize_project_root(
		_get_string(source_analysis, "root_path")
	)
	plan["_source_analysis_index"] = _get_dictionary(validation, "index")


## 重置本次规划的工作量、取消回调、终态、活动计划及候选去重状态；同一实例不提供并发隔离。
## [br]
## @api private
func _begin_planner_operation() -> void:
	_planner_work_units = 0
	_planner_max_work_units = MAX_WORK_UNITS
	_planner_cancel_check = Callable()
	_planner_cancel_configured = false
	_planner_units_since_cancel_check = 0
	_planner_terminal = false
	_active_plan = {}
	_candidate_path_set = {}
	_active_feature_ids = PackedStringArray()


## 空 runtime 保留默认限制；非空必须精确提供无参取消回调及有界总工作量，配置后立即轮询一次。
## [br]
## @api private
func _configure_planner_runtime(runtime: Dictionary) -> bool:
	if runtime.is_empty():
		return true
	if (
		runtime.size() != _RUNTIME_FIELDS.size()
		or not _dictionary_has_only_fields(runtime, _RUNTIME_FIELDS)
		or not runtime.get("cancel_check") is Callable
		or not runtime.get("max_work_units") is int
	):
		_fail_planner_runtime_invalid()
		return false
	var cancel_check: Callable = runtime["cancel_check"]
	var max_work_units: int = runtime["max_work_units"]
	if (
		not cancel_check.is_valid()
		or cancel_check.get_argument_count() != 0
		or max_work_units <= 0
		or max_work_units > MAX_WORK_UNITS
	):
		_fail_planner_runtime_invalid()
		return false
	_planner_cancel_check = cancel_check
	_planner_cancel_configured = true
	_planner_max_work_units = max_work_units
	return _poll_planner_cancel()


## 先约束选项数量、键长度和 feature ID 集合资源量；未知字段及部分错误类型留给后续语义校验报告。
## [br]
## @api private
func _options_are_intrinsically_admissible(
	options: Dictionary,
	feature_path_only: bool
) -> bool:
	var maximum_fields: int = 1 if feature_path_only else _MAX_OPTION_FIELDS
	if options.size() > maximum_fields:
		return false
	var allowed_fields: PackedStringArray = (
		_FEATURE_PATH_OPTION_FIELDS if feature_path_only else _OPTION_FIELDS
	)
	for key_value: Variant in options.keys():
		if not _consume_planner_work():
			return false
		if not (key_value is String or key_value is StringName):
			return false
		var option_name: String = _string_value(key_value)
		if option_name.length() > 64:
			return false
		if not allowed_fields.has(option_name):
			continue
		var option_value: Variant = options[key_value]
		if option_name != "feature_ids":
			continue
		if not (option_value is Array or option_value is PackedStringArray):
			continue
		var feature_count: int = 0
		if option_value is Array:
			var count_feature_array: Array = option_value
			feature_count = count_feature_array.size()
		else:
			var count_packed_features: PackedStringArray = option_value
			feature_count = count_packed_features.size()
		if feature_count > _MAX_FEATURE_IDS:
			return false
		if option_value is Array:
			var feature_values: Array = option_value
			for feature_value: Variant in feature_values:
				if not _consume_planner_work():
					return false
				if not (feature_value is String or feature_value is StringName):
					return false
				var feature_id: String = _string_value(feature_value)
				if feature_id.length() > _MAX_FEATURE_ID_LENGTH:
					return false
		else:
			var packed_feature_values: PackedStringArray = option_value
			for feature_id: String in packed_feature_values:
				if (
					not _consume_planner_work()
					or feature_id.length() > _MAX_FEATURE_ID_LENGTH
				):
					return false
	return true


## 累加规划工作量并按间隔轮询取消；负工作量或预算超限进入终态，超限前优先检查取消。
## [br]
## @api private
func _consume_planner_work(work_units: int = 1) -> bool:
	if _planner_terminal:
		return false
	if work_units < 0:
		_fail_planner_resource_limit()
		return false
	if _planner_work_units > _planner_max_work_units - work_units:
		if not _poll_planner_cancel():
			return false
		_fail_planner_resource_limit()
		return false
	_planner_work_units += work_units
	_planner_units_since_cancel_check += work_units
	if _planner_units_since_cancel_check >= _RUNTIME_CANCEL_POLL_INTERVAL:
		_planner_units_since_cancel_check = 0
		return _poll_planner_cancel()
	return true


## 将来源契约验证器的工作量回调转入同一规划预算和取消机制。
## [br]
## @api private
func _planner_checkpoint_allows(work_units: int) -> bool:
	return _consume_planner_work(work_units)


## 调用已配置的无参取消回调，要求严格布尔值；失效回调或错误返回进入 runtime 失败，请求取消则进入取消终态。
## [br]
## @api private
func _poll_planner_cancel() -> bool:
	if not _planner_cancel_configured:
		return true
	if not _planner_cancel_check.is_valid():
		_fail_planner_runtime_invalid()
		return false
	var cancel_value: Variant = _planner_cancel_check.call()
	if not cancel_value is bool:
		_fail_planner_runtime_invalid()
		return false
	var cancel_requested: bool = cancel_value
	if cancel_requested:
		_fail_planner_cancelled()
		return false
	return true


## 以统一终态入口将本次规划转换为资源边界失败，丢弃可误用的候选结果。
## [br]
## @api private
func _fail_planner_resource_limit() -> void:
	_set_planner_terminal(
		"error",
		"planner_resource_limit_exceeded",
		"Project Layout Planner 超出不可关闭的资源边界。"
	)


## 以 warning 终态结束协作式取消，清除已积累的规划载荷。
## [br]
## @api private
func _fail_planner_cancelled() -> void:
	_set_planner_terminal(
		"warning",
		"planning_cancelled",
		"Project Layout Planner 已协作式取消。"
	)


## 以错误终态处理 runtime 结构或取消回调失效，禁止继续积累计划。
## [br]
## @api private
func _fail_planner_runtime_invalid() -> void:
	_set_planner_terminal(
		"error",
		"planner_runtime_invalid",
		"Project Layout Planner 内部 runtime 字段或取消回调无效。"
	)


## 只接受首个终止原因；清空活动计划身份、步骤、阻碍项及旧问题，保留单个终态诊断。
## [br]
## @api private
func _set_planner_terminal(
	severity: String,
	kind: String,
	message: String
) -> void:
	if _planner_terminal:
		return
	_planner_terminal = true
	if _active_plan.is_empty():
		return
	_active_plan["complete"] = false
	_active_plan["profile_id"] = ""
	_active_plan["source_analysis_digest"] = ""
	_active_plan["contract_digest"] = ""
	_active_plan["project_root"] = ""
	var capabilities: Dictionary = _get_dictionary(_active_plan, "capabilities")
	capabilities["supported_rule_kinds"] = []
	capabilities["ignored_rule_kinds"] = []
	_get_array(_active_plan, "steps").clear()
	_get_array(_active_plan, "blockers").clear()
	var issues: Array = _get_array(_active_plan, "issues")
	issues.clear()
	issues.append({
		"severity": severity,
		"kind": kind,
		"path": "",
		"message": message,
		"context": {},
	})


## 在预算内报告未知选项及布尔类型错误，再读取并去重 feature ID；诊断写入共享计划。
## [br]
## @api private
func _validate_options(options: Dictionary, plan: Dictionary) -> void:
	for key_value: Variant in options.keys():
		if not _consume_planner_work():
			return
		var option_name: String = _string_value(key_value)
		if not option_name.is_empty() and _OPTION_FIELDS.has(option_name):
			continue
		_add_issue(
			plan,
			"error",
			"unsupported_option",
			option_name,
			"项目结构 Planner 包含不受支持的选项。",
			{ "actual": _describe_value(key_value) }
		)
	for field_name: String in _BOOL_OPTION_FIELDS:
		if not _consume_planner_work():
			return
		if options.has(field_name) and not options[field_name] is bool:
			_add_issue(plan, "error", "invalid_option_type", field_name, "%s 必须是 bool。" % field_name, { "actual": _describe_value(options[field_name]) })
	_validate_feature_ids_option(options, plan)


## 清空旧 ID 列表后接受文本集合，报告非法项并按首次出现顺序去重；路径片段及模式语义稍后验证。
## [br]
## @api private
func _validate_feature_ids_option(options: Dictionary, plan: Dictionary) -> void:
	_active_feature_ids = PackedStringArray()
	if not options.has("feature_ids"):
		return
	var feature_ids_value: Variant = options["feature_ids"]
	if not (feature_ids_value is Array or feature_ids_value is PackedStringArray):
		_add_issue(plan, "error", "invalid_option_type", "feature_ids", "feature_ids 必须是字符串数组。", { "actual": _describe_value(feature_ids_value) })
		return
	var feature_ids: Array = []
	if feature_ids_value is Array:
		feature_ids = feature_ids_value
	else:
		var packed_feature_ids: PackedStringArray = feature_ids_value
		for feature_id: String in packed_feature_ids:
			if not _consume_planner_work():
				return
			feature_ids.append(feature_id)
	var seen_feature_ids: Dictionary = {}
	for feature_id_value: Variant in feature_ids:
		if not _consume_planner_work():
			return
		if not _is_non_empty_string_value(feature_id_value):
			_add_issue(plan, "error", "invalid_option_type", "feature_ids", "feature_ids 只能包含非空字符串。", { "actual": _describe_value(feature_id_value) })
			continue
		var feature_id: String = _string_value(feature_id_value)
		if seen_feature_ids.has(feature_id):
			continue
		seen_feature_ids[feature_id] = true
		var _append_feature_id: bool = _active_feature_ids.append(feature_id)


## 仅允许功能路径接口支持的选项，并要求可选子目录开关为布尔值。
## [br]
## @api private
func _feature_path_options_are_valid(options: Dictionary) -> bool:
	for key_value: Variant in options.keys():
		if not _consume_planner_work():
			return false
		var option_name: String = _string_value(key_value)
		if option_name.is_empty() or not _FEATURE_PATH_OPTION_FIELDS.has(option_name):
			return false
	if options.has("include_optional_feature_subdirs") and not options["include_optional_feature_subdirs"] is bool:
		return false
	return true


## 按必需标记和可选 zone 开关收集根路径，使用本次候选去重集合并遵守数量及工作量上限。
## [br]
## @api private
func _queue_zone_paths(
	profile: Dictionary,
	options: Dictionary,
	candidate_paths: PackedStringArray
) -> void:
	var include_optional_zones: bool = _get_bool(options, "include_optional_zones")
	for zone_value: Variant in _get_array(profile, "zones"):
		if not _consume_planner_work():
			return
		if not zone_value is Dictionary:
			continue
		var zone: Dictionary = zone_value
		if not _get_bool(zone, "required") and not include_optional_zones:
			continue
		var roots_value: Variant = zone.get("roots")
		if _collection_size(roots_value) > _MAX_CANDIDATE_PATHS:
			_fail_planner_resource_limit()
			return
		for relative_root: String in _get_string_list(zone, "roots"):
			if not _append_candidate_path(candidate_paths, relative_root):
				return


## 有 feature ID 时调用注册规则的规划处理器；没有匹配处理器记录错误，终态时立即停止。
## [br]
## @api private
func _queue_feature_paths(
	profile: Dictionary,
	options: Dictionary,
	planner_registry: Dictionary,
	candidate_paths: PackedStringArray,
	plan: Dictionary
) -> void:
	var feature_ids: PackedStringArray = _get_string_list(options, "feature_ids")
	if feature_ids.is_empty():
		return
	var matched_planner: bool = false
	for rule_value: Variant in _get_array(profile, "rules"):
		if not _consume_planner_work():
			return
		if not rule_value is Dictionary:
			continue
		var rule: Dictionary = rule_value
		var registry_entry_value: Variant = planner_registry.get(_get_string(rule, "kind"))
		if not registry_entry_value is Dictionary:
			continue
		var registry_entry: Dictionary = registry_entry_value
		var handler_value: Variant = registry_entry.get("handler")
		if not handler_value is Callable:
			continue
		matched_planner = true
		var handler: Callable = handler_value
		var _handler_result: Variant = handler.call(rule, options, candidate_paths)
		if _planner_terminal:
			return
	if not matched_planner:
		_add_issue(plan, "error", "missing_feature_module_contract", "", "项目结构 profile 没有 feature_module_contract 规则。")


## 为已验证的活动 ID 生成契约目录路径，按是否包含可选子目录的开关加入全局候选集。
## [br]
## @api private
func _queue_feature_contract(
	rule: Dictionary,
	options: Dictionary,
	candidate_paths: PackedStringArray
) -> void:
	var feature_path_options: Dictionary = {
		"include_optional_feature_subdirs": _get_bool(options, "include_optional_feature_subdirs"),
	}
	for feature_id: String in _active_feature_ids:
		if not _consume_planner_work():
			return
		for relative_path: String in _make_feature_module_paths_from_contract(rule, feature_id, feature_path_options):
			if not _append_candidate_path(candidate_paths, relative_path):
				return


## 要求存在功能模块契约，并逐一验证每个活动 ID 满足每份契约的路径片段及模式要求。
## [br]
## @api private
func _validate_feature_planning_inputs(
	profile: Dictionary,
	_options: Dictionary,
	plan: Dictionary
) -> void:
	var feature_ids: PackedStringArray = _active_feature_ids
	if feature_ids.is_empty():
		return
	var contracts: Array[Dictionary] = _find_feature_contracts(profile)
	if contracts.is_empty():
		_add_issue(plan, "error", "missing_feature_module_contract", "", "项目结构 profile 没有 feature_module_contract 规则。")
		return
	for contract: Dictionary in contracts:
		if not _consume_planner_work():
			return
		var feature_id_pattern: String = _get_string(contract, "feature_id_pattern")
		for feature_id: String in feature_ids:
			if not _consume_planner_work(
				1 + feature_id.length() + feature_id_pattern.length()
			):
				return
			if _is_valid_feature_id(feature_id, feature_id_pattern):
				continue
			_add_issue(
				plan,
				"error",
				"invalid_feature_id",
				feature_id,
				"Feature ID 不符合 profile 约定：%s。" % feature_id,
				{ "pattern": feature_id_pattern }
			)


## 先确保 ID 通过全部功能契约，再汇总去重路径；任一验证、预算或追加失败都返回空结果。
## [br]
## @api private
func _make_feature_module_paths_from_compiled_profile(
	profile: Dictionary,
	feature_id: String,
	options: Dictionary
) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var result_seen: Dictionary = {}
	var contracts: Array[Dictionary] = _find_feature_contracts(profile)
	if _planner_terminal or contracts.is_empty() or feature_id.is_empty():
		return result
	for contract: Dictionary in contracts:
		if not _consume_planner_work(
			1 + feature_id.length() + _get_string(contract, "feature_id_pattern").length()
		):
			return PackedStringArray()
		if not _is_valid_feature_id(feature_id, _get_string(contract, "feature_id_pattern")):
			return PackedStringArray()
	for contract: Dictionary in contracts:
		if not _consume_planner_work():
			return PackedStringArray()
		for relative_path: String in _make_feature_module_paths_from_contract(contract, feature_id, options):
			if not _append_unique_path(result, result_seen, relative_path):
				return PackedStringArray()
	return result


## 为各根生成功能目录和必需子目录，按开关合并允许子目录；先约束集合及乘积数量，失败丢弃本次路径列表。
## [br]
## @api private
func _make_feature_module_paths_from_contract(
	contract: Dictionary,
	feature_id: String,
	options: Dictionary
) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var result_seen: Dictionary = {}
	for collection_field: String in ["roots", "required_subdirs", "allowed_subdirs"]:
		if _collection_size(contract.get(collection_field)) > _MAX_CANDIDATE_PATHS:
			_fail_planner_resource_limit()
			return PackedStringArray()
	var subdirectories: PackedStringArray = _get_string_list(contract, "required_subdirs")
	if subdirectories.size() > _MAX_CANDIDATE_PATHS:
		_fail_planner_resource_limit()
		return PackedStringArray()
	var subdirectory_seen: Dictionary = {}
	for subdirectory: String in subdirectories:
		if not _append_unique_path(
			PackedStringArray(),
			subdirectory_seen,
			subdirectory,
			false
		):
			return PackedStringArray()
	if _get_bool(options, "include_optional_feature_subdirs"):
		for allowed_subdirectory: String in _get_string_list(contract, "allowed_subdirs"):
			if not _append_unique_path(
				subdirectories,
				subdirectory_seen,
				allowed_subdirectory
			):
				return PackedStringArray()
	var roots: PackedStringArray = _get_string_list(contract, "roots")
	if (
		roots.size() > _MAX_CANDIDATE_PATHS
		or roots.size() * (subdirectories.size() + 1) > _MAX_CANDIDATE_PATHS
	):
		_fail_planner_resource_limit()
		return PackedStringArray()
	for root: String in roots:
		if not _consume_planner_work():
			return PackedStringArray()
		var feature_root: String = root.path_join(feature_id)
		if not _append_unique_path(result, result_seen, feature_root):
			return PackedStringArray()
		for subdirectory: String in subdirectories:
			if not _append_unique_path(
				result,
				result_seen,
				feature_root.path_join(subdirectory)
			):
				return PackedStringArray()
	return result


## 去重并按父路径优先排序候选，跳过已有目录，以源分析中的文件阻挡生成 blocker，其余生成目录步骤并连接依赖。
## [br]
## @api private
func _plan_candidate_paths(
	candidate_paths: PackedStringArray,
	plan: Dictionary
) -> void:
	if candidate_paths.size() > _MAX_CANDIDATE_PATHS:
		_fail_planner_resource_limit()
		return
	var source_index: Dictionary = _get_dictionary(plan, "_source_analysis_index")
	var sorted_paths: Array[String] = []
	var sorted_path_set: Dictionary = {}
	for relative_path: String in candidate_paths:
		if not _consume_planner_work(1 + relative_path.length()):
			return
		if not sorted_path_set.has(relative_path):
			sorted_path_set[relative_path] = true
			sorted_paths.append(relative_path)
	if not _consume_planner_work(_sort_work_units(sorted_paths.size())):
		return
	sorted_paths.sort_custom(Callable(self, "_relative_path_precedes"))
	for relative_path: String in sorted_paths:
		if not _consume_planner_work(1 + relative_path.length()):
			return
		var analysis_kind: String = _analysis_node_kind(
			source_index,
			relative_path
		)
		if analysis_kind == "directory":
			continue
		var blocking_relative_path: String = _find_non_directory_ancestor_in_analysis(
			source_index,
			relative_path
		)
		if _planner_terminal:
			return
		if not blocking_relative_path.is_empty():
			_add_blocker(plan, "path_blocked_by_file", relative_path, _analysis_evidence_ids_for_path(source_index, blocking_relative_path), "目标或祖先路径是文件，不能形成目录步骤。")
			continue
		_append_plan_step(plan, relative_path, source_index)
	_attach_step_dependencies(plan)


## 从候选自身向父级查找文件阻挡，遇已有目录即停止；空返回也可能来自终态，调用者须同时检查规划状态。
## [br]
## @api private
func _find_non_directory_ancestor_in_analysis(
	source_index: Dictionary,
	relative_path: String
) -> String:
	var probe_path: String = relative_path
	while not probe_path.is_empty():
		if not _consume_planner_work(1 + probe_path.length()):
			return ""
		var node_kind: String = _analysis_node_kind(source_index, probe_path)
		if node_kind == "file":
			return probe_path
		if node_kind == "directory":
			return ""
		probe_path = _get_parent_relative_path(probe_path)
	return ""


## 在数量及工作预算内追加只读 ensure_directory 候选，附来源证据和必须重新满足的前置条件。
## [br]
## @api private
func _append_plan_step(
	plan: Dictionary,
	relative_path: String,
	source_index: Dictionary
) -> void:
	var steps: Array = _get_array(plan, "steps")
	if steps.size() >= _MAX_PLAN_STEPS:
		_fail_planner_resource_limit()
		return
	if not _consume_planner_work(1 + relative_path.length()):
		return
	steps.append({
		"step_id": _step_id(relative_path),
		"kind": "ensure_directory",
		"relative_path": relative_path,
		"requires": [],
		"evidence_ids": _analysis_evidence_ids_for_path(source_index, relative_path),
		"preconditions": [
			"source_analysis_digest_matches",
			"path_absent_in_source_analysis",
			"ancestor_chain_contains_no_files_in_source_analysis",
		],
		"risk": "low",
	})


## 为每个步骤寻找最近的已规划祖先，并将其 step ID 设为唯一依赖；修改现有步骤字典。
## [br]
## @api private
func _attach_step_dependencies(plan: Dictionary) -> void:
	var steps: Array = _get_array(plan, "steps")
	if steps.size() > _MAX_PLAN_STEPS:
		_fail_planner_resource_limit()
		return
	var step_ids_by_path: Dictionary = {}
	for step_value: Variant in steps:
		if not _consume_planner_work():
			return
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value
		step_ids_by_path[_get_string(step, "relative_path")] = _get_string(step, "step_id")
	for step_value: Variant in steps:
		if not _consume_planner_work():
			return
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value
		var parent_path: String = _get_parent_relative_path(_get_string(step, "relative_path"))
		while not parent_path.is_empty():
			if not _consume_planner_work():
				return
			if step_ids_by_path.has(parent_path):
				step["requires"] = [step_ids_by_path[parent_path]]
				break
			parent_path = _get_parent_relative_path(parent_path)


## 向上查找最近已观察节点的证据，最后回退项目根；工作终止时返回空数组。
## [br]
## @api private
func _analysis_evidence_ids_for_path(
	source_index: Dictionary,
	relative_path: String
) -> Array[String]:
	var probe_path: String = relative_path
	while not probe_path.is_empty():
		if not _consume_planner_work():
			return []
		var node: Dictionary = _analysis_node(source_index, probe_path)
		if not node.is_empty():
			return _string_array(_get_array(node, "evidence_ids"))
		probe_path = _get_parent_relative_path(probe_path)
	var root_node: Dictionary = _analysis_node(source_index, ".")
	return _string_array(_get_array(root_node, "evidence_ids"))


## 通过路径索引读取节点种类，缺失或字段类型错误时返回空串。
## [br]
## @api private
func _analysis_node_kind(source_index: Dictionary, relative_path: String) -> String:
	return _get_string(_analysis_node(source_index, relative_path), "node_kind")


## 由相对路径取得节点 ID，再返回索引中的节点字典引用；索引缺失或类型不符返回空字典。
## [br]
## @api private
func _analysis_node(source_index: Dictionary, relative_path: String) -> Dictionary:
	var node_id_by_path: Dictionary = _get_dictionary(source_index, "node_id_by_path")
	var node_id_value: Variant = node_id_by_path.get(relative_path)
	if not node_id_value is String:
		return {}
	var node_id: String = node_id_value
	var node_by_id: Dictionary = _get_dictionary(source_index, "node_by_id")
	var node_value: Variant = node_by_id.get(node_id)
	if node_value is Dictionary:
		var node: Dictionary = node_value
		return node
	return {}


## 按数量及工作预算追加带稳定 ID 的阻碍项，复制证据 ID 数组以隔离调用者容器。
## [br]
## @api private
func _add_blocker(
	plan: Dictionary,
	kind: String,
	relative_path: String,
	evidence_ids: Array[String],
	message: String
) -> void:
	var blockers: Array = _get_array(plan, "blockers")
	if blockers.size() >= _MAX_PLAN_BLOCKERS:
		_fail_planner_resource_limit()
		return
	if not _consume_planner_work(1 + relative_path.length()):
		return
	blockers.append({
		"blocker_id": "blocker:%s" % ("%s\n%s" % [kind, relative_path]).sha256_text().substr(0, 16),
		"kind": kind,
		"relative_path": relative_path,
		"evidence_ids": evidence_ids.duplicate(),
		"message": message,
	})


## 结合调用结果、终态及错误诊断设置 complete，移除内部来源索引并释放活动计划引用，返回同一计划字典。
## [br]
## @api private
func _finalize_plan(plan: Dictionary, planning_complete: bool) -> Dictionary:
	plan["complete"] = (
		planning_complete
		and not _planner_terminal
		and not _has_error_issue(plan)
	)
	var _source_index_removed: bool = plan.erase("_source_analysis_index")
	_active_plan = {}
	return plan


## 在非终态及诊断预算内追加问题，清理 context 为报告数据；名额耗尽转成统一资源失败。
## [br]
## @api private
func _add_issue(
	plan: Dictionary,
	severity: String,
	kind: String,
	path: String,
	message: String,
	context: Dictionary = {},
	reason_code: String = ""
) -> void:
	if _planner_terminal:
		return
	var issues: Array = _get_array(plan, "issues")
	if issues.size() >= _MAX_PLAN_DIAGNOSTICS - 1:
		_fail_planner_resource_limit()
		return
	if not _consume_planner_work():
		return
	var issue: Dictionary = {
		"severity": severity,
		"kind": kind,
		"path": path,
		"message": message,
		"context": _sanitize_issue_context(context),
	}
	if not reason_code.is_empty():
		issue["reason_code"] = reason_code
	issues.append(issue)


## 按工作预算查找 error 诊断；检查中进入终态也按有错误处理，防止误报完整。
## [br]
## @api private
func _has_error_issue(plan: Dictionary) -> bool:
	for issue_value: Variant in _get_array(plan, "issues"):
		if not _consume_planner_work():
			return true
		if issue_value is Dictionary:
			var issue: Dictionary = issue_value
			if _get_string(issue, "severity") == "error":
				return true
	return false


## 保序收集功能模块规则的原字典引用，数量或工作预算超限返回空数组。
## [br]
## @api private
func _find_feature_contracts(profile: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rule_value: Variant in _get_array(profile, "rules"):
		if not _consume_planner_work():
			return []
		if not rule_value is Dictionary:
			continue
		var rule: Dictionary = rule_value
		if _get_string(rule, "kind") == _RULE_FEATURE_MODULE_CONTRACT:
			if result.size() >= _MAX_FEATURE_CONTRACTS:
				_fail_planner_resource_limit()
				return []
			result.append(rule)
	return result


## 使用本次规划共享的候选集合去重并追加路径，转交统一数量及工作预算检查。
## [br]
## @api private
func _append_candidate_path(
	paths: PackedStringArray,
	relative_path: String
) -> bool:
	return _append_unique_path(
		paths,
		_candidate_path_set,
		relative_path
	)


## 计费并限制路径长度后忽略空项和重复项；新项先写入 seen，可选择只登记而不追加结果数组。
## [br]
## @api private
func _append_unique_path(
	paths: PackedStringArray,
	seen_paths: Dictionary,
	relative_path: String,
	append_to_paths: bool = true
) -> bool:
	if (
		not _consume_planner_work(1 + relative_path.length())
		or relative_path.length() > _MAX_PLANNER_PATH_LENGTH
	):
		_fail_planner_resource_limit()
		return false
	if relative_path.is_empty() or seen_paths.has(relative_path):
		return true
	if seen_paths.size() >= _MAX_CANDIDATE_PATHS:
		_fail_planner_resource_limit()
		return false
	seen_paths[relative_path] = true
	if not append_to_paths:
		return true
	var _append_result: bool = paths.append(relative_path)
	return true


## 路径较浅者优先；层数相同时按字符串升序比较。
## [br]
## @api private
## [br]
func _relative_path_precedes(left_path: String, right_path: String) -> bool:
	var left_depth: int = left_path.count("/")
	var right_depth: int = right_path.count("/")
	if left_depth != right_depth:
		return left_depth < right_depth
	return left_path < right_path


## 返回 Array 或 PackedStringArray 的元素数；其他类型返回 -1。
## [br]
## @api private
## [br]
func _collection_size(value: Variant) -> int:
	if value is Array:
		var array_value: Array = value
		return array_value.size()
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value.size()
	return -1


## 按元素数和逐次折半层数估算排序工作单位数。
## [br]
## @api private
## [br]
func _sort_work_units(item_count: int) -> int:
	if item_count <= 1:
		return item_count
	var levels: int = 0
	var remaining: int = item_count
	while remaining > 1:
		levels += 1
		remaining = ceili(float(remaining) / 2.0)
	return item_count * levels


## 只接受规范 res:// 文件路径，拒绝空路径、空白、反斜线、尾分隔符、冒号及点段。
## [br]
## @api private
func _is_canonical_resource_path(path: String) -> bool:
	if (
		path.is_empty()
		or path != path.strip_edges()
		or path.contains("\\")
		or not path.begins_with("res://")
		or path.ends_with("/")
	):
		return false
	var relative_path: String = path.substr("res://".length())
	if relative_path.is_empty() or relative_path.contains(":"):
		return false
	for part: String in relative_path.split("/", true):
		if part.is_empty() or part == "." or part == "..":
			return false
	return true


## 以步骤种类和相对路径的 SHA-256 前缀构造稳定计划步骤 ID。
## [br]
## @api private
func _step_id(relative_path: String) -> String:
	return "step:%s" % ("ensure_directory\n%s" % relative_path).sha256_text().substr(0, 16)


## 返回最后一个斜杠之前的相对路径；无斜杠时返回空字符串。
## [br]
## @api private
## [br]
func _get_parent_relative_path(relative_path: String) -> String:
	var separator_index: int = relative_path.rfind("/")
	if separator_index < 0:
		return ""
	return relative_path.substr(0, separator_index)


## 先检查跨平台单路径片段，再编译并搜索契约正则；正则是否要求全串匹配由契约锚点决定。
## [br]
## @api private
func _is_valid_feature_id(feature_id: String, pattern: String) -> bool:
	if not _is_portable_feature_id_segment(feature_id):
		return false
	var expression: RegEx = RegEx.new()
	var compile_result: Error = expression.compile(pattern, false)
	if compile_result != OK:
		return false
	return expression.search(feature_id) != null


## 拒绝空白边界、点段、尾点、Windows 设备名、路径及通配字符和控制码，保证 ID 可用作单个目录片段。
## [br]
## @api private
func _is_portable_feature_id_segment(feature_id: String) -> bool:
	if feature_id.is_empty() or feature_id != feature_id.strip_edges():
		return false
	if feature_id == "." or feature_id == ".." or feature_id.ends_with("."):
		return false
	if _is_windows_reserved_device_stem(feature_id.get_slice(".", 0).to_lower()):
		return false
	for forbidden_character: String in ["/", "\\", ":", "*", "?", "[", "]", "<", ">", "\"", "|"]:
		if feature_id.contains(forbidden_character):
			return false
	for character_index: int in feature_id.length():
		var codepoint: int = feature_id.unicode_at(character_index)
		if codepoint < 32 or codepoint == 127:
			return false
	return true


## 检查调用者已转小写的名称干，识别固定设备名及 COM1–9、LPT1–9。
## [br]
## @api private
func _is_windows_reserved_device_stem(stem: String) -> bool:
	if stem == "con" or stem == "prn" or stem == "aux" or stem == "nul":
		return true
	if stem.length() != 4:
		return false
	var prefix: String = stem.substr(0, 3)
	var suffix_codepoint: int = stem.unicode_at(3)
	return (
		(prefix == "com" or prefix == "lpt")
		and suffix_codepoint >= 49
		and suffix_codepoint <= 57
	)


## 统一分隔符并跳过协议前缀后检查精确父目录段，不因名称中包含两个点而拒绝。
## [br]
## @api private
func _path_has_parent_segment(path: String) -> bool:
	var normalized_path: String = path.replace("\\", "/")
	var body: String = normalized_path
	if normalized_path.contains("://"):
		body = normalized_path.get_slice("://", 1)
	for part: String in body.split("/", false):
		if part == "..":
			return true
	return false


## 当前实现原样返回传入的项目根路径。
## [br]
## @api private
## [br]
func _normalize_project_root(project_root: String) -> String:
	return project_root


## 最多投影前 128 个 context 条目，空或非文本键改用位置名称，值转为报告数据；规范键碰撞由后项覆盖。
## [br]
## @api private
func _sanitize_issue_context(context: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var entry_index: int = 0
	for key_value: Variant in context.keys():
		if entry_index >= 128:
			break
		var key: String = _string_value(key_value)
		if key.is_empty():
			key = "entry_%d" % entry_index
		result[key] = _sanitize_report_value(context[key_value], 0)
		entry_index += 1
	return result


## 递归复制普通容器并限制层数及每层条目，非有限浮点转文本，其他对象降为类型摘要；PackedStringArray 整体复制。
## [br]
## @api private
func _sanitize_report_value(value: Variant, depth: int) -> Variant:
	if depth >= 8:
		return _describe_value(value)
	if value == null or value is bool or value is int or value is String:
		return value
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value)
	if value is float:
		var float_value: float = value
		if is_finite(float_value):
			return float_value
		return "NaN" if is_nan(float_value) else ("+Inf" if float_value > 0.0 else "-Inf")
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value.duplicate()
	if value is Array:
		var array_result: Array = []
		var array_value: Array = value
		for index: int in mini(array_value.size(), 128):
			array_result.append(_sanitize_report_value(array_value[index], depth + 1))
		return array_result
	if value is Dictionary:
		var dictionary_result: Dictionary = {}
		var dictionary_value: Dictionary = value
		var entry_index: int = 0
		for key_value: Variant in dictionary_value.keys():
			if entry_index >= 128:
				break
			var key: String = _string_value(key_value)
			if key.is_empty():
				key = "entry_%d" % entry_index
			dictionary_result[key] = _sanitize_report_value(dictionary_value[key_value], depth + 1)
			entry_index += 1
		return dictionary_result
	return _describe_value(value)


## 生成不展开对象的类型摘要；标量保留可序列化值，普通及文本数组、字典仅附数量。
## [br]
## @api private
func _describe_value(value: Variant) -> Dictionary:
	var value_type: int = typeof(value)
	var result: Dictionary = {
		"type": value_type,
		"type_name": type_string(value_type),
	}
	if value == null or value is bool or value is int or value is String:
		result["value"] = value
	elif value is StringName:
		result["value"] = _string_value(value)
	elif value is float:
		var float_value: float = value
		if is_finite(float_value):
			result["value"] = float_value
		elif is_nan(float_value):
			result["value"] = "NaN"
		else:
			result["value"] = "+Inf" if float_value > 0.0 else "-Inf"
	elif value is Array:
		var array_value: Array = value
		result["count"] = array_value.size()
	elif value is Dictionary:
		var dictionary_value: Dictionary = value
		result["count"] = dictionary_value.size()
	elif value is PackedStringArray:
		var packed_value: PackedStringArray = value
		result["count"] = packed_value.size()
	return result


## 判断字典的所有键是否都是字符串且属于允许字段集合。
## [br]
## @api private
## [br]
func _dictionary_has_only_fields(
	value: Dictionary,
	allowed_fields: PackedStringArray
) -> bool:
	for key_value: Variant in value.keys():
		if not key_value is String:
			return false
		var key: String = key_value
		if not allowed_fields.has(key):
			return false
	return true


## 判断 severity 是否为 error、warning 或 info 字符串。
## [br]
## @api private
## [br]
func _valid_severity_value(value: Variant) -> bool:
	return value is String and ["error", "warning", "info"].has(value)


## 复制数组中的 String 与 StringName 项为类型化 String 数组，跳过其他类型。
## [br]
## @api private
## [br]
func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		if value is String or value is StringName:
			result.append(_string_value(value))
	return result


## 将 StringName 转为 String；String 原样返回，其他类型返回空字符串。
## [br]
## @api private
## [br]
func _string_value(value: Variant) -> String:
	if value is String:
		var string_value: String = value
		return string_value
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value)
	return ""


## 判断 String 或 StringName 去除首尾空白后是否非空。
## [br]
## @api private
## [br]
func _is_non_empty_string_value(value: Variant) -> bool:
	return not _string_value(value).strip_edges().is_empty()


## 读取字典中的 String 或 StringName 字段；缺失或类型不匹配时返回默认值。
## [br]
## @api private
## [br]
func _get_string(source: Dictionary, key: String, default_value: String = "") -> String:
	if not source.has(key):
		return default_value
	var value: Variant = source[key]
	if value is String or value is StringName:
		return _string_value(value)
	return default_value


## 读取字典中的 bool 字段；缺失或类型不匹配时返回默认值。
## [br]
## @api private
## [br]
func _get_bool(source: Dictionary, key: String, default_value: bool = false) -> bool:
	if not source.has(key) or not source[key] is bool:
		return default_value
	var value: bool = source[key]
	return value


## 读取字典中的 int 或精确整数 float；其他值返回默认值。
## [br]
## @api private
## [br]
func _get_int(source: Dictionary, key: String, default_value: int = 0) -> int:
	if not source.has(key):
		return default_value
	var value: Variant = source[key]
	if value is int:
		var integer_value: int = value
		return integer_value
	if value is float:
		var float_value: float = value
		if is_finite(float_value) and float_value == floorf(float_value):
			return int(float_value)
	return default_value


## 返回指定字段中的 Array；缺失或类型不匹配时返回空数组。
## [br]
## @api private
## [br]
func _get_array(source: Dictionary, key: String) -> Array:
	if not source.has(key):
		return []
	var value: Variant = source[key]
	if value is Array:
		var array_value: Array = value
		return array_value
	return []


## 返回指定字段中的 Dictionary；缺失或类型不匹配时返回空字典。
## [br]
## @api private
## [br]
func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {}
	var value: Variant = source[key]
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value
	return {}


## 将 String、StringName、PackedStringArray 或对应数组读取为字符串列表。
## [br]
## @api private
## [br]
func _get_string_list(source: Dictionary, key: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if not source.has(key):
		return result
	var value: Variant = source[key]
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value.duplicate()
	if value is String or value is StringName:
		var string_value: String = _string_value(value)
		if not string_value.is_empty():
			var _append_string: bool = result.append(string_value)
		return result
	if value is Array:
		var array_value: Array = value
		for item: Variant in array_value:
			if item is String or item is StringName:
				var item_string: String = _string_value(item)
				if not item_string.is_empty():
					var _append_item: bool = result.append(item_string)
	return result
