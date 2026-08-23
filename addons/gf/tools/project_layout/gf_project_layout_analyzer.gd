## GFProjectLayoutAnalyzer: 只读的项目结构分析器。
##
## 捕获项目目录库存，并按可选 profile 分析目录分区、Feature 模块契约、命名、生成物边界和大桶目录增长。
## 所有公开操作都只读取项目；该类型不会创建、移动、删除或改写任何项目文件。
## 未知选项、字段、错误类型和非规范相对路径都会失败关闭；扫描预算在流式枚举期间全局生效。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since unreleased
class_name GFProjectLayoutAnalyzer
extends RefCounted


# --- 常量 ---

## Feature 内聚式示例 profile 路径。
## [br]
## @api public
## [br]
## @since unreleased
const EXAMPLE_FEATURE_COHESIVE_PROFILE_PATH: String = "res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json"

const _BOUNDED_JSON_OBJECT_READER_SCRIPT = preload(
	"res://addons/gf/kernel/core/gf_bounded_json_object_reader.gd"
)
const _ANALYSIS_CONTRACT_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_analysis_contract.gd"
)
const _EXPLAINER_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_explainer.gd"
)
const _IMPACT_ANALYZER_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_impact_analyzer.gd"
)
const _PROFILE_COMPILER_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_profile_compiler.gd")
const _RULE_BUCKET_SIZE: String = "bucket_size"
const _RULE_FEATURE_MODULE_CONTRACT: String = "feature_module_contract"
const _RULE_FORBID_ROOT_FILES: String = "forbid_root_files"
const _RULE_GENERATED_BOUNDARY: String = "generated_boundary"
const _RULE_NAMING_CONVENTION: String = "naming_convention"
const _SNAPSHOT_FIELDS: PackedStringArray = [
	"schema_version",
	"kind",
	"root_path",
	"scope",
	"complete",
	"capture_status",
	"files",
	"directories",
	"issues",
]
const _SNAPSHOT_CAPTURE_STATUSES: PackedStringArray = [
	"complete",
	"partial",
	"not_started",
]
const _SNAPSHOT_SCOPE_FIELDS: PackedStringArray = [
	"kind",
	"root_path",
	"include_hidden",
	"excluded_prefixes",
	"max_scanned_files",
	"max_scanned_directories",
	"max_scan_depth",
]
const _SNAPSHOT_ISSUE_FIELDS: PackedStringArray = [
	"severity",
	"kind",
	"path",
	"message",
]
const _MAX_SNAPSHOT_ISSUE_COUNT: int = 1024
const _MAX_SNAPSHOT_STRUCTURE_VALUES: int = 200000
const _MAX_SNAPSHOT_DEPTH: int = 64
const _MAX_COMPILATION_DEPTH: int = _MAX_SNAPSHOT_DEPTH + 1
const _MAX_OPTION_FIELDS: int = 6
const _ADMISSION_OK: int = 0
const _ADMISSION_INVALID: int = 1
const _ADMISSION_RESOURCE_LIMIT: int = 2
const _DEFAULT_MAX_SCANNED_FILES: int = \
	_ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_FILES
const _DEFAULT_MAX_SCANNED_DIRECTORIES: int = \
	_ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_DIRECTORIES
const _DEFAULT_MAX_SCAN_DEPTH: int = _ANALYSIS_CONTRACT_SCRIPT.MAX_SCAN_DEPTH
const _PROJECT_SOURCE_EXCLUDED_PREFIXES: PackedStringArray = [
	".git",
	".godot",
	".import",
]
const _ABSENCE_FINDING_KINDS: PackedStringArray = [
	"missing_required_zone_root",
	"missing_feature_subdir",
]
const _VALIDATOR_OPTION_FIELDS: PackedStringArray = [
	"root_path",
	"include_hidden",
	"max_scanned_files",
	"max_scanned_directories",
	"max_scan_depth",
	"allow_missing_root",
]
const _VALIDATOR_BOOL_OPTION_FIELDS: PackedStringArray = [
	"include_hidden",
	"allow_missing_root",
]
const _VALIDATOR_INTEGER_OPTION_FIELDS: PackedStringArray = [
	"max_scanned_files",
	"max_scanned_directories",
	"max_scan_depth",
]
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
const _COMPILATION_ISSUE_FIELDS: PackedStringArray = [
	"severity",
	"kind",
	"reason_code",
	"path",
	"message",
	"context",
]
const _COMPILATION_CAPABILITY_FIELDS: PackedStringArray = [
	"executor_id",
	"operation",
	"rule_kinds",
	"rule_fields",
	"zone_fields",
]
const _COMPILED_PROFILE_FIELDS: PackedStringArray = [
	"schema_version",
	"id",
	"display_name",
	"description",
	"zones",
	"rules",
	"metadata",
]
const _COMPILED_ZONE_FIELDS: PackedStringArray = [
	"id",
	"description",
	"roots",
	"required",
	"severity",
	"metadata",
]
const _COMPILED_RULE_COMMON_FIELDS: PackedStringArray = [
	"id",
	"description",
	"kind",
	"severity",
	"metadata",
]
const _COMPILED_RULE_FIELDS_BY_KIND: Dictionary = {
	"bucket_size": ["roots", "max_files"],
	"feature_module_contract": [
		"roots",
		"feature_id_pattern",
		"required_subdirs",
		"allowed_subdirs",
		"allow_root_files",
	],
	"forbid_root_files": ["allowed_files"],
	"generated_boundary": ["include", "roots"],
	"naming_convention": [
		"roots",
		"exclude",
		"pattern",
		"target",
	],
}
const _RUNTIME_FIELDS: PackedStringArray = [
	"cancel_check",
	"max_work_units",
	"max_findings",
]
const _DEFAULT_MAX_WORK_UNITS: int = 2_000_000
const _DEFAULT_MAX_FINDINGS: int = 1_024
const _ABSOLUTE_MAX_WORK_UNITS: int = _DEFAULT_MAX_WORK_UNITS
const _ABSOLUTE_MAX_FINDINGS: int = _DEFAULT_MAX_FINDINGS
const _RUNTIME_CANCEL_POLL_INTERVAL: int = 64
const _PROFILE_CONTRACT_ID: String = "gf.project_layout.profile.v1"


# --- 私有变量 ---

var _runtime_active: bool = false
var _runtime_cancel_check: Callable = Callable()
var _runtime_max_work_units: int = _DEFAULT_MAX_WORK_UNITS
var _runtime_max_findings: int = _DEFAULT_MAX_FINDINGS
var _runtime_work_units: int = 0
var _runtime_units_since_cancel_check: int = 0
var _runtime_abort_status: String = ""
var _runtime_terminal_finding_added: bool = false
var _runtime_report: Dictionary = {}


# --- 公共方法 ---

## 不加载 profile，只捕获并归一化当前项目结构。
##
## 该入口适合第一次使用 Project Layout 的项目：它只建立观察图，不假定任何推荐目录。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param options: 分析选项。
## [br]
## @schema options: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth 和 allow_missing_root；root_path 只能是规范 res:// 根或子根。
## [br]
## @return: 只读分析报告。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects；graph 精确包含 schema_version、kind、complete、capture_status、scope、dependency_coverage、nodes、edges 和 evidence；effects 精确包含 writes_project=false。
func analyze(options: Dictionary = {}) -> Dictionary:
	_reset_evaluation_runtime()
	var options_admission: int = _options_admission_status(options)
	if options_admission != _ADMISSION_OK:
		return _make_input_admission_report(options_admission)
	var root_path: String = _report_root_path(options)
	var report: Dictionary = _make_report("", root_path)
	_configure_evaluation_runtime({}, report)
	_validate_options(options, report)
	_validate_root_path(root_path, options, report)
	if _get_int(report, "error_count") > 0:
		return _finalize_report(report)
	var scan: Dictionary = _scan_project(root_path, options, report)
	_attach_scan_result(report, scan, true)
	return _finalize_report(report)

## 按 Feature 内聚式示例 profile 分析项目结构。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param options: 校验选项。
## [br]
## @schema options: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth 和 allow_missing_root；root_path 只能是规范 res:// 根或子根。
## [br]
## @return: 校验报告。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects；capabilities 在编译前或 contract/registry 失败时为 {}，否则精确包含 executor_id、operation、rule_kinds、rule_fields 和 zone_fields；effects 精确包含 writes_project=false。
func analyze_example_profile(options: Dictionary = {}) -> Dictionary:
	return analyze_profile_path(EXAMPLE_FEATURE_COHESIVE_PROFILE_PATH, options)


## 从项目结构 profile 文件分析项目结构。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile_path: JSON profile 路径。
## [br]
## @param options: 校验选项。
## [br]
## @schema options: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth 和 allow_missing_root；root_path 只能是规范 res:// 根或子根。
## [br]
## @return: 校验报告。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects；capabilities 在编译前或 contract/registry 失败时为 {}，否则精确包含 executor_id、operation、rule_kinds、rule_fields 和 zone_fields；effects 精确包含 writes_project=false。
func analyze_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:
	_reset_evaluation_runtime()
	var options_admission: int = _options_admission_status(options)
	if options_admission != _ADMISSION_OK:
		return _make_input_admission_report(options_admission)
	if profile_path.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH:
		return _make_input_admission_report(_ADMISSION_RESOURCE_LIMIT)
	var root_path: String = _report_root_path(options)
	var report: Dictionary = _make_report("", root_path)
	_configure_evaluation_runtime({}, report)
	_validate_options(options, report)
	_validate_root_path(root_path, options, report)
	if _get_int(report, "error_count") > 0:
		return _finalize_report(report)
	if (
		profile_path.strip_edges().is_empty()
		or not _is_canonical_project_source_root(profile_path)
	):
		_add_issue(
			report,
			"error",
			"invalid_profile_path",
			"",
			"项目结构 profile 路径必须是规范的 res:// 文件路径。"
		)
		return _finalize_report(report)
	var load_result: Dictionary = _load_profile(profile_path)
	if not _get_bool(load_result, "success"):
		var loaded_profile_path: String = _get_string(load_result, "source_path", profile_path)
		_add_issue(
			report,
			"error",
			_get_string(load_result, "kind", "profile_load_failed"),
			loaded_profile_path,
			_get_string(load_result, "error"),
			{ "profile_path": loaded_profile_path }
		)
		return _finalize_report(report)

	var profile_value: Variant = load_result.get("profile", {})
	if profile_value is Dictionary:
		var profile: Dictionary = profile_value
		return analyze_profile(profile, options)

	_add_issue(report, "error", "invalid_profile", "", "项目结构 profile 必须是 Dictionary。")
	return _finalize_report(report)


## 按已解析的项目结构 profile 分析项目结构。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile: 项目结构 profile 字典。
## [br]
## @schema profile: Dictionary，包含 schema_version、id、zones 和 rules。
## [br]
## @param options: 校验选项。
## [br]
## @schema options: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth 和 allow_missing_root；root_path 只能是规范 res:// 根或子根。
## [br]
## @return: 校验报告。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects；capabilities 在编译前或 contract/registry 失败时为 {}，否则精确包含 executor_id、operation、rule_kinds、rule_fields 和 zone_fields；effects 精确包含 writes_project=false。
func analyze_profile(profile: Dictionary, options: Dictionary = {}) -> Dictionary:
	_reset_evaluation_runtime()
	var options_admission: int = _options_admission_status(options)
	if options_admission != _ADMISSION_OK:
		return _make_input_admission_report(options_admission)
	var root_path: String = _report_root_path(options)
	var report: Dictionary = _make_report("", root_path)
	_configure_evaluation_runtime({}, report)
	_validate_options(options, report)
	_validate_root_path(root_path, options, report)
	if _get_int(report, "error_count") > 0:
		return _finalize_report(report)
	var rule_registry: Dictionary = _make_rule_registry()
	var compile_result: Dictionary = compile_profile(profile)
	_append_compiler_result(compile_result, report)
	if _get_int(report, "error_count") > 0:
		return _finalize_report(report)
	var compiled_profile: Dictionary = _get_dictionary(compile_result, "profile")
	report["profile_id"] = _get_string(compiled_profile, "id")

	var scan: Dictionary = _scan_project(root_path, options, report)
	_attach_scan_result(report, scan, true)
	if _get_int(report, "error_count") > 0:
		return _finalize_report(report)
	if not _get_bool(report, "input_complete"):
		return _finalize_report(report)

	_validate_zones(compiled_profile, scan, report)
	_validate_rules(compiled_profile, scan, report, rule_registry)
	return _finalize_report(report)


## 分析已经冻结的 data-only 项目库存，不再访问文件系统。
##
## Editor Dock 用主线程分批捕获 snapshot，再把该值交给后台 worker。snapshot 必须包含
## schema_version、kind、root_path、scope、complete、capture_status、files 和 directories。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param snapshot: data-only 项目库存。
## [br]
## @schema snapshot: Dictionary，字段闭集为 schema_version、kind、root_path、scope、complete、capture_status、files、directories 和可选 issues；root_path 必须是规范 res:// 根或子根，scope 精确包含 kind、root_path、include_hidden、excluded_prefixes 与三项捕获预算，files/directories 必须形成完整父目录闭包。
## [br]
## @return: observation-only 只读分析报告。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects。
func analyze_snapshot(snapshot: Dictionary) -> Dictionary:
	return analyze_snapshot_for_framework(snapshot, {})


## 按 profile 分析已经冻结的 data-only 项目库存，不再扫描项目目录。
##
## 该便捷入口会只读加载 canonical contract、编译 profile，并在传入的冻结库存上完成分析。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile: 已解析的严格 profile。
## [br]
## @schema profile: Dictionary，包含 schema_version、id、zones 和 rules。
## [br]
## @param snapshot: data-only 项目库存。
## [br]
## @schema snapshot: Dictionary，字段闭集为 schema_version、kind、root_path、scope、complete、capture_status、files、directories 和可选 issues；scope 必须描述 project_source 捕获范围，files/directories 必须形成完整父目录闭包。
## [br]
## @return: 带 policy findings 的只读分析报告。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects。
func analyze_profile_snapshot(
	profile: Dictionary,
	snapshot: Dictionary
) -> Dictionary:
	_reset_evaluation_runtime()
	if not _snapshot_envelope_is_admissible(snapshot):
		return _make_input_admission_report(_ADMISSION_RESOURCE_LIMIT)
	return analyze_compiled_profile_snapshot(compile_profile(profile), snapshot)


## 解释分析报告中的一条 finding。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param analysis: 本类型生成的项目结构分析报告。
## [br]
## @schema analysis: Dictionary，必须是本类型生成并通过闭合 analysis/graph contract 的完整 project_layout_analysis 报告，不能手工拼装字段子集。
## [br]
## @param finding_id: finding 的稳定 ID。
## [br]
## @return: 只读解释，包含 observation、implication、next_steps、certainty 和 evidence。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、complete、finding_id、headline、observation、implication、next_steps、certainty、evidence、issues 和 effects；effects 精确包含 writes_project=false。
func explain_finding(analysis: Dictionary, finding_id: String) -> Dictionary:
	var explainer: _EXPLAINER_SCRIPT = _EXPLAINER_SCRIPT.new()
	return explainer.explain_finding(analysis, finding_id)


## 在冻结分析图上模拟 move、rename 或 delete 的影响。
##
## 该方法只返回影响状态和 blocker，不执行变更。依赖覆盖不完整时必须返回 unknown，
## 不能把“没有观察到引用”解释成安全。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param analysis: 本类型生成的项目结构分析报告。
## [br]
## @schema analysis: Dictionary，必须是本类型生成并通过闭合 analysis/graph contract 的完整 project_layout_analysis 报告，不能手工拼装字段子集。
## [br]
## @param change: Dictionary，包含 kind、source_path，move/rename 还需 target_path。
## [br]
## @schema change: Dictionary，字段闭集为 kind、source_path 和 target_path；kind 只能是 delete、move 或 rename。
## [br]
## @return: 只读影响报告，status 为 safe、unsafe 或 unknown。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、complete、status、source_analysis_digest、change、affected_node_ids、blockers、evidence_ids、issues 和 effects；effects 精确包含 writes_project=false。
func analyze_change_impact(analysis: Dictionary, change: Dictionary) -> Dictionary:
	var impact_analyzer: _IMPACT_ANALYZER_SCRIPT = _IMPACT_ANALYZER_SCRIPT.new()
	return impact_analyzer.analyze_change(analysis, change)


# --- 框架内部方法 ---

## 使用内部 runtime 边界分析冻结 snapshot。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param snapshot: data-only 项目库存。
## [br]
## @schema snapshot: Dictionary，字段闭集为 schema_version、kind、root_path、scope、complete、capture_status、files、directories 和可选 issues；scope 必须描述 project_source 捕获范围，files/directories 必须形成完整父目录闭包。
## [br]
## @param runtime: 协作式取消、工作量和 finding 数量边界。
## [br]
## @schema runtime: Dictionary，字段闭集为 cancel_check、max_work_units 和 max_findings；cancel_check 为零参数 Callable，两个正整数只能收紧框架默认上限，不能放大固有预算。
## [br]
## @return: observation-only 只读分析报告。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects。
func analyze_snapshot_for_framework(
	snapshot: Dictionary,
	runtime: Dictionary
) -> Dictionary:
	_reset_evaluation_runtime()
	if not _snapshot_envelope_is_admissible(snapshot):
		return _make_input_admission_report(_ADMISSION_RESOURCE_LIMIT)
	var root_path: String = _get_string(snapshot, "root_path")
	var report: Dictionary = _make_report("", root_path)
	_configure_evaluation_runtime(runtime, report)
	if _runtime_is_aborted():
		return _finalize_report(report)
	var scan: Dictionary = _scan_from_snapshot(snapshot, report)
	if _get_int(report, "error_count") == 0:
		_attach_scan_result(report, scan, true)
	return _finalize_report(report)


## 按 Analyzer 的真实规则 registry 编译 profile。
##
## Editor Dock 在主线程调用此入口，再把返回的 data-only 结果交给后台 worker。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param profile: 已解析的严格 profile。
## [br]
## @schema profile: Dictionary，包含 schema_version、id、zones、rules 与 canonical contract 允许的可选描述字段。
## [br]
## @return: canonical compiler 的 data-only 结果。
## [br]
## @schema return: Dictionary，字段闭集为 success、profile、issues、error_count、warning_count、contract_id、contract_digest 和 capabilities；contract_digest 精确绑定规范版本的 canonical contract bytes。
func compile_profile(profile: Dictionary) -> Dictionary:
	var rule_registry: Dictionary = _make_rule_registry()
	var compiler: _PROFILE_COMPILER_SCRIPT = _PROFILE_COMPILER_SCRIPT.new()
	return compiler.compile_profile(
		profile,
		{
			"executor_id": "godot_project_layout_analyzer",
			"operation": "analyze",
			"rule_registry": rule_registry,
			"unsupported_rule_policy": "error",
			"zone_executed_fields": PackedStringArray(["roots", "required", "severity"]),
		}
	)


## 在冻结 snapshot 上执行已经完成的 profile compilation。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param compilation: compile_profile() 返回的 data-only 结果。
## [br]
## @schema compilation: Dictionary，字段闭集为 success、profile、issues、error_count、warning_count、contract_id、contract_digest 和 capabilities；成功结果必须与 Analyzer registry、canonical contract identity 及规范 SHA-256 摘要精确一致。
## [br]
## @param snapshot: data-only 项目库存。
## [br]
## @schema snapshot: Dictionary，字段闭集为 schema_version、kind、root_path、scope、complete、capture_status、files、directories 和可选 issues；scope 必须描述 project_source 捕获范围，files/directories 必须形成完整父目录闭包。
## [br]
## @param runtime: 可选的协作式取消、工作量和 finding 数量边界。
## [br]
## @schema runtime: Dictionary，字段闭集为 cancel_check、max_work_units 和 max_findings；省略时使用框架默认边界，显式正整数只能收紧默认值。
## [br]
## @return: 不访问文件系统的只读分析报告。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects。
func analyze_compiled_profile_snapshot(
	compilation: Dictionary,
	snapshot: Dictionary,
	runtime: Dictionary = {}
) -> Dictionary:
	_reset_evaluation_runtime()
	if not _snapshot_envelope_is_admissible(snapshot):
		return _make_input_admission_report(_ADMISSION_RESOURCE_LIMIT)
	if not _compilation_envelope_is_admissible(compilation):
		return _make_input_admission_report(_ADMISSION_RESOURCE_LIMIT)
	var root_path: String = _get_string(snapshot, "root_path")
	var report: Dictionary = _make_report("", root_path)
	_configure_evaluation_runtime(runtime, report)
	if _runtime_is_aborted():
		return _finalize_report(report)
	var rule_registry: Dictionary = _make_rule_registry()
	if not _compilation_is_valid(compilation, rule_registry, report):
		return _finalize_report(report)
	var compiled_profile: Dictionary = _get_dictionary(compilation, "profile")
	var compile_result: Dictionary = compilation
	_append_compiler_result(compile_result, report)
	if _get_int(report, "error_count") > 0:
		return _finalize_report(report)
	var scan: Dictionary = _scan_from_snapshot(snapshot, report)
	if _get_int(report, "error_count") > 0:
		return _finalize_report(report)
	report["profile_id"] = _get_string(compiled_profile, "id")
	_attach_scan_result(report, scan, true)
	if not _get_bool(report, "input_complete"):
		return _finalize_report(report)
	_validate_zones(compiled_profile, scan, report)
	_validate_rules(compiled_profile, scan, report, rule_registry)
	return _finalize_report(report)


# --- 私有/辅助方法 ---

func _make_rule_registry() -> Dictionary:
	return {
		_RULE_BUCKET_SIZE: {
			"handler": Callable(self, "_validate_bucket_size"),
			"executed_fields": PackedStringArray(["roots", "max_files", "severity"]),
		},
		_RULE_FEATURE_MODULE_CONTRACT: {
			"handler": Callable(self, "_validate_feature_module_contract"),
			"executed_fields": PackedStringArray([
				"roots",
				"feature_id_pattern",
				"required_subdirs",
				"allowed_subdirs",
				"allow_root_files",
				"severity",
			]),
		},
		_RULE_FORBID_ROOT_FILES: {
			"handler": Callable(self, "_validate_forbid_root_files"),
			"executed_fields": PackedStringArray(["allowed_files", "severity"]),
		},
		_RULE_GENERATED_BOUNDARY: {
			"handler": Callable(self, "_validate_generated_boundary"),
			"executed_fields": PackedStringArray(["include", "roots", "severity"]),
		},
		_RULE_NAMING_CONVENTION: {
			"handler": Callable(self, "_validate_naming_convention"),
			"executed_fields": PackedStringArray(["roots", "exclude", "pattern", "target", "severity"]),
		},
	}


func _reset_evaluation_runtime() -> void:
	_runtime_active = false
	_runtime_cancel_check = Callable()
	_runtime_max_work_units = _DEFAULT_MAX_WORK_UNITS
	_runtime_max_findings = _DEFAULT_MAX_FINDINGS
	_runtime_work_units = 0
	_runtime_units_since_cancel_check = 0
	_runtime_abort_status = ""
	_runtime_terminal_finding_added = false
	_runtime_report = {}


func _configure_evaluation_runtime(runtime: Dictionary, report: Dictionary) -> void:
	_runtime_active = true
	_runtime_report = report
	if runtime.is_empty():
		return
	if (
		runtime.size() != _RUNTIME_FIELDS.size()
		or not _dictionary_has_only_fields(runtime, _RUNTIME_FIELDS)
		or not runtime.get("cancel_check") is Callable
		or not runtime.get("max_work_units") is int
		or not runtime.get("max_findings") is int
	):
		_set_runtime_abort(
			report,
			"evaluation_runtime_invalid",
			"内部分析 runtime 字段必须精确闭合且类型正确。"
		)
		return
	var cancel_check: Callable = runtime["cancel_check"]
	var max_work_units: int = runtime["max_work_units"]
	var max_findings: int = runtime["max_findings"]
	if (
		not cancel_check.is_valid()
		or cancel_check.get_argument_count() != 0
		or max_work_units <= 0
		or max_findings <= 0
		or max_work_units > _ABSOLUTE_MAX_WORK_UNITS
		or max_findings > _ABSOLUTE_MAX_FINDINGS
	):
		_set_runtime_abort(
			report,
			"evaluation_runtime_invalid",
			"内部分析 runtime 必须提供零参数取消检查和正整数边界。"
		)
		return
	_runtime_cancel_check = cancel_check
	_runtime_max_work_units = max_work_units
	_runtime_max_findings = max_findings


func _runtime_is_aborted() -> bool:
	return not _runtime_abort_status.is_empty()


func _evaluation_checkpoint(report: Dictionary, work_units: int = 1) -> bool:
	if not _runtime_active:
		return true
	if _runtime_is_aborted():
		return false
	_runtime_work_units += maxi(work_units, 1)
	_runtime_units_since_cancel_check += maxi(work_units, 1)
	if _runtime_units_since_cancel_check >= _RUNTIME_CANCEL_POLL_INTERVAL:
		_runtime_units_since_cancel_check = 0
		if _runtime_cancel_requested():
			_set_runtime_abort(
				report,
				"evaluation_cancelled",
				"项目结构分析已按取消请求安全停止。"
			)
			return false
	if _runtime_work_units > _runtime_max_work_units:
		# 预算与取消同时到达时，用户取消拥有稳定优先级。
		if _runtime_cancel_requested():
			_set_runtime_abort(
				report,
				"evaluation_cancelled",
				"项目结构分析已按取消请求安全停止。"
			)
		else:
			_set_runtime_abort(
				report,
				"evaluation_work_budget_exhausted",
				"项目结构分析达到工作量上限；结果保持不完整。"
			)
		return false
	return true


func _runtime_cancel_requested() -> bool:
	if not _runtime_cancel_check.is_valid():
		return false
	var cancel_value: Variant = _runtime_cancel_check.call()
	return not cancel_value is bool or cancel_value


func _runtime_checkpoint_callback() -> bool:
	if _runtime_report.is_empty():
		return false
	return _evaluation_checkpoint(_runtime_report)


func _set_runtime_abort(report: Dictionary, status: String, message: String) -> void:
	if _runtime_is_aborted():
		return
	_runtime_abort_status = status
	if _runtime_terminal_finding_added:
		return
	_runtime_terminal_finding_added = true
	_append_issue_unchecked(
		report,
		"error" if status == "evaluation_runtime_invalid" else "warning",
		status,
		"",
		message,
		{
			"max_work_units": _runtime_max_work_units,
			"max_findings": _runtime_max_findings,
			"work_units": _runtime_work_units,
		}
	)


func _compilation_is_valid(
	compilation: Dictionary,
	rule_registry: Dictionary,
	report: Dictionary
) -> bool:
	if (
		compilation.size() != _COMPILATION_FIELDS.size()
		or not _dictionary_has_only_fields(compilation, _COMPILATION_FIELDS)
	):
		_add_invalid_compilation_issue(report, "compilation 顶层字段必须精确闭合。")
		return false
	if (
		not compilation.get("success") is bool
		or not compilation.get("profile") is Dictionary
		or not compilation.get("issues") is Array
		or not compilation.get("error_count") is int
		or not compilation.get("warning_count") is int
		or not compilation.get("contract_id") is String
		or not compilation.get("contract_digest") is String
		or not compilation.get("capabilities") is Dictionary
	):
		_add_invalid_compilation_issue(report, "compilation 顶层字段类型无效。")
		return false
	var expected_error_count: int = 0
	var expected_warning_count: int = 0
	for issue_value: Variant in _get_array(compilation, "issues"):
		if not _evaluation_checkpoint(report):
			return false
		if not issue_value is Dictionary:
			_add_invalid_compilation_issue(report, "compilation issue 必须是 Dictionary。")
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
			_add_invalid_compilation_issue(report, "compilation issue 字段必须精确闭合且类型正确。")
			return false
		var severity: String = issue["severity"]
		if severity == "error":
			expected_error_count += 1
		elif severity == "warning":
			expected_warning_count += 1
		else:
			_add_invalid_compilation_issue(report, "compilation issue severity 无效。")
			return false
	if (
		_get_int(compilation, "error_count", -1) != expected_error_count
		or _get_int(compilation, "warning_count", -1) != expected_warning_count
		or _get_bool(compilation, "success") != (expected_error_count == 0)
	):
		_add_invalid_compilation_issue(report, "compilation success 与诊断计数不一致。")
		return false
	var contract_id: String = _get_string(compilation, "contract_id")
	if not contract_id.is_empty() and contract_id != _PROFILE_CONTRACT_ID:
		_add_invalid_compilation_issue(report, "compilation contract identity 无效。")
		return false
	var contract_digest: String = _get_string(compilation, "contract_digest")
	if (
		not contract_digest.is_empty()
		and not _PROFILE_COMPILER_SCRIPT.contract_digest_is_canonical_for_framework(
			contract_digest
		)
	):
		_add_invalid_compilation_issue(report, "compilation contract digest 无效。")
		return false
	var expected_capabilities: Dictionary = _expected_compilation_capabilities(
		rule_registry
	)
	var capabilities: Dictionary = _get_dictionary(compilation, "capabilities")
	if not capabilities.is_empty() and capabilities != expected_capabilities:
		_add_invalid_compilation_issue(report, "compilation capabilities 未绑定 Analyzer registry。")
		return false
	if not _get_bool(compilation, "success"):
		return true
	if (
		contract_id != _PROFILE_CONTRACT_ID
		or not _PROFILE_COMPILER_SCRIPT.contract_digest_is_canonical_for_framework(
			contract_digest
		)
		or capabilities != expected_capabilities
	):
		_add_invalid_compilation_issue(report, "成功 compilation 必须绑定 canonical contract、内容摘要与 Analyzer registry。")
		return false
	if not _compiled_profile_is_valid(
		_get_dictionary(compilation, "profile"),
		rule_registry,
		report
	):
		_add_invalid_compilation_issue(report, "成功 compilation 的 normalized profile 无效。")
		return false
	return true


func _expected_compilation_capabilities(rule_registry: Dictionary) -> Dictionary:
	var rule_kinds: Array[String] = []
	var rule_fields: Dictionary = {}
	for kind_value: Variant in rule_registry.keys():
		var kind: String = _string_value(kind_value)
		if kind.is_empty():
			continue
		rule_kinds.append(kind)
		var registry_entry: Dictionary = _get_dictionary(rule_registry, kind)
		var fields: Array[String] = []
		for field_name: String in _get_string_list(registry_entry, "executed_fields"):
			fields.append(field_name)
		fields.sort()
		rule_fields[kind] = fields
	rule_kinds.sort()
	var zone_fields: Array[String] = ["required", "roots", "severity"]
	zone_fields.sort()
	return {
		"executor_id": "godot_project_layout_analyzer",
		"operation": "analyze",
		"rule_kinds": rule_kinds,
		"rule_fields": rule_fields,
		"zone_fields": zone_fields,
	}


func _compiled_profile_is_valid(
	profile: Dictionary,
	rule_registry: Dictionary,
	report: Dictionary
) -> bool:
	if not _dictionary_has_only_fields(profile, _COMPILED_PROFILE_FIELDS):
		return false
	if (
		profile.get("schema_version") != 1
		or not _is_non_empty_string_value(profile.get("id"))
		or not profile.get("zones") is Array
		or not profile.get("rules") is Array
	):
		return false
	for optional_string_field: String in ["display_name", "description"]:
		if profile.has(optional_string_field) and not profile[optional_string_field] is String:
			return false
	if profile.has("metadata") and not profile["metadata"] is Dictionary:
		return false
	var zone_ids: Dictionary = {}
	for zone_value: Variant in _get_array(profile, "zones"):
		if not _evaluation_checkpoint(report):
			return false
		if not zone_value is Dictionary:
			return false
		var zone: Dictionary = zone_value
		if (
			not _dictionary_has_only_fields(zone, _COMPILED_ZONE_FIELDS)
			or not _compiled_record_identity_is_valid(zone, zone_ids)
			or not _string_collection_value_is_valid(
				zone.get("roots"),
				false,
				report,
				"relative_path"
			)
			or not zone.get("required") is bool
			or not _severity_value_is_valid(zone.get("severity"))
		):
			return false
		if zone.has("description") and not zone["description"] is String:
			return false
		if zone.has("metadata") and not zone["metadata"] is Dictionary:
			return false
	var rule_ids: Dictionary = {}
	for rule_value: Variant in _get_array(profile, "rules"):
		if not _evaluation_checkpoint(report):
			return false
		if not rule_value is Dictionary:
			return false
		var rule: Dictionary = rule_value
		var kind: String = _get_string(rule, "kind")
		if not rule_registry.has(kind) or not _COMPILED_RULE_FIELDS_BY_KIND.has(kind):
			return false
		var allowed_fields: PackedStringArray = _COMPILED_RULE_COMMON_FIELDS.duplicate()
		var kind_fields: Array = _get_array(
			_COMPILED_RULE_FIELDS_BY_KIND,
			kind
		)
		for field_value: Variant in kind_fields:
			if not field_value is String:
				return false
			var field_name: String = field_value
			var _append_field: bool = allowed_fields.append(field_name)
		if (
			not _dictionary_has_only_fields(rule, allowed_fields)
			or not _compiled_record_identity_is_valid(rule, rule_ids)
			or not _severity_value_is_valid(rule.get("severity"))
			or not _compiled_rule_values_are_valid(rule, kind, report)
		):
			return false
		if rule.has("description") and not rule["description"] is String:
			return false
		if rule.has("metadata") and not rule["metadata"] is Dictionary:
			return false
	return true


func _compiled_record_identity_is_valid(record: Dictionary, ids: Dictionary) -> bool:
	if not _is_non_empty_string_value(record.get("id")):
		return false
	var record_id: String = _string_value(record["id"])
	if ids.has(record_id):
		return false
	ids[record_id] = true
	return true


func _compiled_rule_values_are_valid(
	rule: Dictionary,
	kind: String,
	report: Dictionary
) -> bool:
	for list_field: String in [
		"allowed_files",
		"roots",
		"required_subdirs",
		"allowed_subdirs",
	]:
		if rule.has(list_field) and not _string_collection_value_is_valid(
			rule[list_field],
			true,
			report,
			"relative_path"
		):
			return false
	for list_field: String in ["exclude", "include"]:
		if rule.has(list_field) and not _string_collection_value_is_valid(
			rule[list_field],
			true,
			report,
			"glob"
		):
			return false
	if kind == _RULE_BUCKET_SIZE:
		return (
			_string_collection_value_is_valid(
				rule.get("roots"), false, report, "relative_path"
			)
			and _get_int(rule, "max_files") > 0
		)
	if kind == _RULE_FEATURE_MODULE_CONTRACT:
		return (
			_string_collection_value_is_valid(
				rule.get("roots"), false, report, "relative_path"
			)
			and rule.get("feature_id_pattern") is String
			and _compile_regex(_get_string(rule, "feature_id_pattern")) != null
			and rule.get("allow_root_files") is bool
		)
	if kind == _RULE_GENERATED_BOUNDARY:
		return (
			_string_collection_value_is_valid(
				rule.get("include"), false, report, "glob"
			)
			and _string_collection_value_is_valid(
				rule.get("roots"), false, report, "relative_path"
			)
		)
	if kind == _RULE_NAMING_CONVENTION:
		return (
			rule.get("pattern") is String
			and _compile_regex(_get_string(rule, "pattern")) != null
			and ["path", "name", "stem"].has(_get_string(rule, "target"))
		)
	return true


func _string_collection_value_is_valid(
	value: Variant,
	allow_empty: bool,
	report: Dictionary = {},
	value_kind: String = ""
) -> bool:
	if not (value is Array or value is PackedStringArray):
		return false
	var values: Array = []
	if value is Array:
		var array_value: Array = value
		values = array_value
	else:
		var packed_value: PackedStringArray = value
		values = Array(packed_value)
	if values.is_empty() and not allow_empty:
		return false
	var seen: Dictionary = {}
	for item: Variant in values:
		if not report.is_empty() and not _evaluation_checkpoint(report):
			return false
		if not item is String:
			return false
		var item_string: String = item
		if item_string.strip_edges().is_empty() or seen.has(item_string):
			return false
		if (
			value_kind == "relative_path"
			and _PROFILE_COMPILER_SCRIPT._profile_relative_path_is_invalid(item_string)
		):
			return false
		if (
			value_kind == "glob"
			and _PROFILE_COMPILER_SCRIPT._profile_pattern_is_invalid(item_string)
		):
			return false
		seen[item_string] = true
	return true


func _severity_value_is_valid(value: Variant) -> bool:
	return value is String and ["error", "warning", "info"].has(value)


func _add_invalid_compilation_issue(report: Dictionary, message: String) -> void:
	_add_issue(
		report,
		"error",
		"invalid_profile_compilation",
		"",
		message,
		{},
		"PROJECT_LAYOUT_PROFILE_COMPILATION_INVALID"
	)


func _append_compiler_result(compile_result: Dictionary, report: Dictionary) -> void:
	report["capabilities"] = _get_dictionary(compile_result, "capabilities").duplicate(true)
	var issues: Array = _get_array(compile_result, "issues")
	for issue_value: Variant in issues:
		if not _evaluation_checkpoint(report):
			return
		if not issue_value is Dictionary:
			continue
		var issue: Dictionary = issue_value
		_add_issue(
			report,
			_get_string(issue, "severity", "error"),
			_get_string(issue, "kind", "profile_contract_invalid"),
			_get_string(issue, "path"),
			_get_string(issue, "message", "项目结构 profile 编译失败。"),
			_get_dictionary(issue, "context"),
			_get_string(issue, "reason_code")
		)


func _load_profile(profile_path: String) -> Dictionary:
	if profile_path.strip_edges().is_empty():
		return _make_load_result(false, {}, "missing_profile_path", "项目结构 profile 路径为空。", profile_path)

	var read_result: Dictionary = _BOUNDED_JSON_OBJECT_READER_SCRIPT.read_object(profile_path)
	var source_path: String = _get_string(read_result, "source_path", profile_path)
	if not _get_bool(read_result, "ok"):
		var error_kind: String = _get_string(read_result, "error_kind")
		if error_kind == "open_failed" and not FileAccess.file_exists(source_path):
			return _make_load_result(
				false,
				{},
				"profile_path_not_found",
				"项目结构 profile 不存在：%s。" % source_path,
				source_path
			)
		if error_kind == "open_failed" or error_kind == "read_failed":
			return _make_load_result(
				false,
				{},
				"profile_open_failed",
				"无法读取项目结构 profile：%s。%s" % [
					source_path,
					_get_string(read_result, "error"),
				],
				source_path
			)
		if error_kind == "invalid_root_type":
			return _make_load_result(false, {}, "invalid_profile_root", "项目结构 profile 根节点必须是 Dictionary。", source_path)
		return _make_load_result(
			false,
			{},
			"profile_json_parse_failed",
			"项目结构 profile JSON 解析失败：%s" % _get_string(
				read_result,
				"error",
				"输入超过读取边界或格式无效。"
			),
			source_path
		)

	var profile_value: Variant = read_result.get("data", {})
	if profile_value is Dictionary:
		var profile: Dictionary = profile_value
		return _make_load_result(true, profile, "", "", source_path)
	return _make_load_result(false, {}, "invalid_profile_root", "项目结构 profile 根节点必须是 Dictionary。", source_path)


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


func _make_report(profile_id: String, root_path: String) -> Dictionary:
	var report: Dictionary = {
		"schema_version": 1,
		"kind": "project_layout_analysis",
		"evaluation_status": "input_incomplete",
		"evaluation_complete": false,
		"input_complete": false,
		"success": true,
		"profile_id": profile_id,
		"root_path": root_path,
		"input_digest": "",
		"file_count": 0,
		"directory_count": 0,
		"graph": {},
		"issues": [],
		"error_count": 0,
		"warning_count": 0,
		"info_count": 0,
		"rule_results": [],
		"capabilities": {},
		"effects": { "writes_project": false },
		"_finding_ids": {},
		"_finding_occurrences": {},
	}
	_attach_scan_result(
		report,
		{
			"files": PackedStringArray(),
			"directories": PackedStringArray(),
			"complete": false,
			"capture_status": "not_started",
			"root_observed": false,
			"scope": _make_project_source_scope(
				root_path,
				true,
				_DEFAULT_MAX_SCANNED_FILES,
				_DEFAULT_MAX_SCANNED_DIRECTORIES,
				_DEFAULT_MAX_SCAN_DEPTH
			),
		}
	)
	return report


func _make_input_admission_report(admission_status: int) -> Dictionary:
	_reset_evaluation_runtime()
	var report: Dictionary = _make_report("", "res://")
	_configure_evaluation_runtime({}, report)
	var issue_kind: String = "analysis_input_invalid"
	var message: String = "项目结构分析输入未通过闭合字段与类型准入。"
	var reason_code: String = "PROJECT_LAYOUT_ANALYSIS_INPUT_INVALID"
	if admission_status == _ADMISSION_RESOURCE_LIMIT:
		issue_kind = "analysis_input_resource_limit_exceeded"
		message = "项目结构分析输入超过固有资源边界；分析未开始。"
		reason_code = "PROJECT_LAYOUT_ANALYSIS_INPUT_RESOURCE_LIMIT_EXCEEDED"
	_append_issue_unchecked(
		report,
		"error",
		issue_kind,
		"",
		message,
		{},
		reason_code
	)
	return _finalize_report(report)


func _options_admission_status(options: Dictionary) -> int:
	if options.size() > _MAX_OPTION_FIELDS:
		return _ADMISSION_RESOURCE_LIMIT
	for key_value: Variant in options.keys():
		if not key_value is String:
			return _ADMISSION_INVALID
		var key: String = key_value
		if key.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH:
			return _ADMISSION_RESOURCE_LIMIT
		if not _VALIDATOR_OPTION_FIELDS.has(key):
			return _ADMISSION_INVALID
		var option_value: Variant = options[key]
		if key == "root_path":
			if not (option_value is String or option_value is StringName):
				return _ADMISSION_INVALID
			var root_path: String = _string_value(option_value)
			if root_path.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH:
				return _ADMISSION_RESOURCE_LIMIT
			continue
		if _VALIDATOR_BOOL_OPTION_FIELDS.has(key):
			if not option_value is bool:
				return _ADMISSION_INVALID
			continue
		if not option_value is int:
			return _ADMISSION_INVALID
		var budget: int = option_value
		if budget <= 0:
			return _ADMISSION_INVALID
		if (
			key == "max_scanned_files"
			and budget > _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_FILES
		):
			return _ADMISSION_RESOURCE_LIMIT
		if (
			key == "max_scanned_directories"
			and budget > _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_DIRECTORIES
		):
			return _ADMISSION_RESOURCE_LIMIT
		if (
			key == "max_scan_depth"
			and budget > _ANALYSIS_CONTRACT_SCRIPT.MAX_SCAN_DEPTH
		):
			return _ADMISSION_RESOURCE_LIMIT
	return _ADMISSION_OK


func _snapshot_envelope_is_admissible(snapshot: Dictionary) -> bool:
	if snapshot.size() > _SNAPSHOT_FIELDS.size():
		return false
	for key_value: Variant in snapshot.keys():
		if not key_value is String:
			return false
		var key: String = key_value
		if (
			key.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH
			or not _SNAPSHOT_FIELDS.has(key)
		):
			return false

	for string_field: String in ["kind", "root_path", "capture_status"]:
		if not snapshot.has(string_field):
			continue
		var string_value: Variant = snapshot[string_field]
		if not string_value is String:
			return false
		var text: String = string_value
		if text.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH:
			return false
	if snapshot.has("schema_version") and not snapshot["schema_version"] is int:
		return false
	if snapshot.has("complete") and not snapshot["complete"] is bool:
		return false
	if snapshot.has("scope") and not snapshot["scope"] is Dictionary:
		return false

	var file_count: int = _snapshot_collection_size(snapshot.get("files"))
	var directory_count: int = _snapshot_collection_size(
		snapshot.get("directories")
	)
	if file_count < 0 or directory_count < 0:
		return false
	if (
		file_count > _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_FILES
		or directory_count > _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_DIRECTORIES
		or not _ANALYSIS_CONTRACT_SCRIPT.basic_inventory_counts_are_admissible(
			file_count,
			directory_count,
			true
		)
	):
		return false
	if (
		not _snapshot_path_collection_lengths_are_admissible(
			snapshot.get("files")
		)
		or not _snapshot_path_collection_lengths_are_admissible(
			snapshot.get("directories")
		)
	):
		return false

	if snapshot.has("issues"):
		var issues_value: Variant = snapshot["issues"]
		if not issues_value is Array:
			return false
		var issues: Array = issues_value
		if issues.size() > _MAX_SNAPSHOT_ISSUE_COUNT:
			return false
	if snapshot.has("scope"):
		var scope_value: Variant = snapshot["scope"]
		if not scope_value is Dictionary:
			return false
		var scope: Dictionary = scope_value
		if not _snapshot_scope_envelope_is_admissible(
			scope,
			file_count,
			directory_count
		):
			return false
	return _snapshot_tree_is_admissible(snapshot)


func _compilation_envelope_is_admissible(compilation: Dictionary) -> bool:
	return _snapshot_tree_is_admissible(compilation, _MAX_COMPILATION_DEPTH)


func _snapshot_scope_envelope_is_admissible(
	scope: Dictionary,
	file_count: int,
	directory_count: int
) -> bool:
	if scope.size() > _SNAPSHOT_SCOPE_FIELDS.size():
		return false
	for key_value: Variant in scope.keys():
		if not key_value is String:
			return false
		var key: String = key_value
		if (
			key.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH
			or not _SNAPSHOT_SCOPE_FIELDS.has(key)
		):
			return false
	for string_field: String in ["kind", "root_path"]:
		if not scope.has(string_field):
			continue
		var string_value: Variant = scope[string_field]
		if not string_value is String:
			return false
		var text: String = string_value
		if text.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH:
			return false
	if scope.has("include_hidden") and not scope["include_hidden"] is bool:
		return false
	if scope.has("excluded_prefixes"):
		var excluded_value: Variant = scope["excluded_prefixes"]
		var excluded_count: int = _snapshot_collection_size(excluded_value)
		if (
			excluded_count < 0
			or excluded_count > 64
			or not _snapshot_path_collection_lengths_are_admissible(
				excluded_value
			)
		):
			return false
	for budget_limit: Dictionary in [
		{
			"field": "max_scanned_files",
			"maximum": _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_FILES,
			"observed": file_count,
		},
		{
			"field": "max_scanned_directories",
			"maximum": _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_DIRECTORIES,
			"observed": directory_count,
		},
		{
			"field": "max_scan_depth",
			"maximum": _ANALYSIS_CONTRACT_SCRIPT.MAX_SCAN_DEPTH,
			"observed": 0,
		},
	]:
		var field_name: String = _get_string(budget_limit, "field")
		if not scope.has(field_name):
			continue
		var budget_value: Variant = scope[field_name]
		if not budget_value is int:
			return false
		var budget: int = budget_value
		if (
			budget <= 0
			or budget > _get_int(budget_limit, "maximum")
			or _get_int(budget_limit, "observed") > budget
		):
			return false
	return true


func _snapshot_collection_size(value: Variant) -> int:
	if value is Array:
		var array_value: Array = value
		return array_value.size()
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value.size()
	return -1


func _snapshot_path_collection_lengths_are_admissible(value: Variant) -> bool:
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		for path: String in packed_value:
			if path.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_RELATIVE_PATH_LENGTH:
				return false
		return true
	if not value is Array:
		return false
	var array_value: Array = value
	for path_value: Variant in array_value:
		if not path_value is String:
			return false
		var path: String = path_value
		if path.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_RELATIVE_PATH_LENGTH:
			return false
	return true


func _snapshot_tree_is_admissible(
	snapshot: Dictionary,
	max_depth: int = _MAX_SNAPSHOT_DEPTH
) -> bool:
	var stack: Array = [{
		"value": snapshot,
		"depth": 0,
		"exit": false,
	}]
	var active_containers: Array = []
	var structure_value_count: int = 0
	var string_bytes: int = 0
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
		structure_value_count += 1
		if structure_value_count > _MAX_SNAPSHOT_STRUCTURE_VALUES:
			return false
		var depth: int = _get_int(frame, "depth")
		if depth > max_depth:
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
			if text.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH:
				return false
			string_bytes += text.to_utf8_buffer().size()
			if string_bytes > _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_STRING_BYTES:
				return false
			continue
		if value is PackedStringArray:
			var packed_value: PackedStringArray = value
			if packed_value.size() > _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_NODES:
				return false
			for item: String in packed_value:
				structure_value_count += 1
				if (
					structure_value_count > _MAX_SNAPSHOT_STRUCTURE_VALUES
					or item.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH
				):
					return false
				string_bytes += item.to_utf8_buffer().size()
				if string_bytes > _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_STRING_BYTES:
					return false
			continue
		if value is Array:
			var array_value: Array = value
			if (
				array_value.size() > _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_NODES
				or _active_snapshot_container_exists(active_containers, array_value)
			):
				return false
			active_containers.append(array_value)
			stack.append({ "value": array_value, "depth": depth, "exit": true })
			for item_index: int in range(array_value.size() - 1, -1, -1):
				stack.append({
					"value": array_value[item_index],
					"depth": depth + 1,
					"exit": false,
				})
			continue
		if value is Dictionary:
			var dictionary_value: Dictionary = value
			if (
				dictionary_value.size() > _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_NODES
				or _active_snapshot_container_exists(
					active_containers,
					dictionary_value
				)
			):
				return false
			active_containers.append(dictionary_value)
			stack.append({
				"value": dictionary_value,
				"depth": depth,
				"exit": true,
			})
			var keys: Array = dictionary_value.keys()
			for key_value: Variant in keys:
				if not key_value is String:
					return false
				var key: String = key_value
				structure_value_count += 1
				if (
					structure_value_count > _MAX_SNAPSHOT_STRUCTURE_VALUES
					or key.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH
				):
					return false
				string_bytes += key.to_utf8_buffer().size()
				if string_bytes > _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_STRING_BYTES:
					return false
			for key_index: int in range(keys.size() - 1, -1, -1):
				var dictionary_key: Variant = keys[key_index]
				stack.append({
					"value": dictionary_value[dictionary_key],
					"depth": depth + 1,
					"exit": false,
				})
			continue
		return false
	return true


func _active_snapshot_container_exists(
	active_containers: Array,
	value: Variant
) -> bool:
	for active_value: Variant in active_containers:
		if is_same(active_value, value):
			return true
	return false


func _report_root_path(options: Dictionary) -> String:
	if not options.has("root_path"):
		return "res://"
	var root_value: Variant = options["root_path"]
	if not (root_value is String or root_value is StringName):
		return ""
	var root_path: String = _string_value(root_value)
	if root_path.strip_edges().is_empty():
		return ""
	return root_path


func _validate_options(options: Dictionary, report: Dictionary) -> void:
	for key_value: Variant in options.keys():
		var option_name: String = _string_value(key_value)
		if not option_name.is_empty() and _VALIDATOR_OPTION_FIELDS.has(option_name):
			continue
		_add_issue(
			report,
			"error",
			"unsupported_option",
			option_name,
			"项目结构 validator 包含不受支持的选项。",
			{ "actual": _describe_value(key_value) }
		)
	if options.has("root_path"):
		var root_value: Variant = options["root_path"]
		if not (root_value is String or root_value is StringName):
			_add_issue(report, "error", "invalid_option_type", "root_path", "root_path 必须是字符串。", { "actual": _describe_value(root_value) })
		elif _string_value(root_value).strip_edges().is_empty():
			_add_issue(report, "error", "invalid_option_value", "root_path", "root_path 不能为空。")
	for field_name: String in _VALIDATOR_BOOL_OPTION_FIELDS:
		if options.has(field_name) and not options[field_name] is bool:
			_add_issue(report, "error", "invalid_option_type", field_name, "%s 必须是 bool。" % field_name, { "actual": _describe_value(options[field_name]) })
	for field_name: String in _VALIDATOR_INTEGER_OPTION_FIELDS:
		if not options.has(field_name):
			continue
		var value: Variant = options[field_name]
		if value is int and value > 0:
			continue
		_add_issue(
			report,
			"error",
			"invalid_integer_option",
			field_name,
			"项目结构扫描选项 %s 必须是正整数。" % field_name,
			{ "option": field_name, "actual": _describe_value(value) }
		)


func _validate_root_path(root_path: String, _options: Dictionary, report: Dictionary) -> void:
	if not _is_canonical_project_source_root(root_path):
		_add_issue(report, "error", "unsupported_root_path", root_path, "项目源码根必须是规范 res:// 根或子根，不能使用 user://、绝对路径或路径 alias。")
		return
	if _path_crosses_link(root_path):
		_add_issue(report, "error", "linked_path_not_allowed", root_path, "项目根路径不能穿过符号链接或目录联接。")


func _scan_project(root_path: String, options: Dictionary, report: Dictionary) -> Dictionary:
	var include_hidden: bool = _get_bool(options, "include_hidden", true)
	var max_scanned_files: int = _get_positive_integer_option(
		options,
		"max_scanned_files",
		_DEFAULT_MAX_SCANNED_FILES,
		report
	)
	var max_scanned_directories: int = _get_positive_integer_option(
		options,
		"max_scanned_directories",
		_DEFAULT_MAX_SCANNED_DIRECTORIES,
		report
	)
	var max_scan_depth: int = _get_positive_integer_option(
		options,
		"max_scan_depth",
		_DEFAULT_MAX_SCAN_DEPTH,
		report
	)
	var result: Dictionary = {
		"files": PackedStringArray(),
		"directories": PackedStringArray(),
		"file_count": 0,
		"directory_count": 0,
		"complete": false,
		"capture_status": "not_started",
		"capture_issues": [],
		"root_observed": false,
		"scope": _make_project_source_scope(
			root_path,
			include_hidden,
			max_scanned_files,
			max_scanned_directories,
			max_scan_depth
		),
		"_scan_aborted": false,
	}
	if _get_int(report, "error_count") > 0:
		var _invalid_budget_scan_state_removed: bool = result.erase("_scan_aborted")
		return result
	var absolute_root: String = ProjectSettings.globalize_path(root_path)
	if not DirAccess.dir_exists_absolute(absolute_root):
		var missing_severity: String = (
			"warning" if _get_bool(options, "allow_missing_root") else "error"
		)
		var missing_kind: String = (
			"root_path_not_observed"
			if _get_bool(options, "allow_missing_root")
			else "root_path_not_found"
		)
		var missing_message: String = (
			"项目根目录不存在；库存保持不完整，profile 规则不会执行。"
			if _get_bool(options, "allow_missing_root")
			else "项目根目录不存在。"
		)
		_add_issue(report, missing_severity, missing_kind, root_path, missing_message)
		_append_capture_issue(
			result,
			missing_severity,
			missing_kind,
			root_path,
			missing_message
		)
		var _missing_root_scan_state_removed: bool = result.erase("_scan_aborted")
		return result

	result["root_observed"] = true
	result["_inventory_string_bytes"] = _initial_scan_inventory_string_bytes(
		root_path
	)
	if (
		_get_int(result, "_inventory_string_bytes")
		> _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_STRING_BYTES
	):
		_abort_scan_resource_limit(result, report)
	if (
		not include_hidden
		and not _get_bool(result, "_input_resource_limit_exceeded")
	):
		_add_issue(
			report,
			"warning",
			"project_source_scope_incomplete",
			"include_hidden",
			"include_hidden=false 会遗漏隐藏源码路径；profile 规则不会执行。"
		)
	if not _get_bool(result, "_input_resource_limit_exceeded"):
		_scan_directory(
			root_path,
			"",
			include_hidden,
			max_scanned_files,
			max_scanned_directories,
			max_scan_depth,
			0,
			result,
			report
		)
	var capture_status: String = (
		"partial"
		if _get_bool(result, "_scan_aborted") or not include_hidden
		else "complete"
	)
	result["capture_status"] = capture_status
	result["complete"] = capture_status == "complete"
	if (
		not _get_bool(result, "_input_resource_limit_exceeded")
		and not _reserve_scan_inventory_text(
			result,
			capture_status,
			_ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH
		)
	):
		_abort_scan_resource_limit(result, report)
	if not _get_bool(result, "_input_resource_limit_exceeded"):
		var files: PackedStringArray = _get_packed_string_array(result, "files")
		files.sort()
		result["files"] = files
		var directories: PackedStringArray = _get_packed_string_array(
			result,
			"directories"
		)
		directories.sort()
		result["directories"] = directories
	var _string_budget_removed: bool = result.erase("_inventory_string_bytes")
	var _scan_state_removed: bool = result.erase("_scan_aborted")
	return result


func _scan_from_snapshot(snapshot: Dictionary, report: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"files": PackedStringArray(),
		"directories": PackedStringArray(),
		"file_count": 0,
		"directory_count": 0,
		"complete": false,
		"capture_status": "not_started",
		"capture_issues": [],
		"root_observed": false,
		"scope": {},
	}
	if not _evaluation_checkpoint(report):
		return result
	_validate_snapshot_fields(snapshot, report)
	if _runtime_is_aborted():
		return result
	if _get_int(snapshot, "schema_version") != 1:
		_add_issue(report, "error", "invalid_snapshot_schema", "schema_version", "项目结构 snapshot schema_version 必须为 1。")
	if _get_string(snapshot, "kind") != "project_layout_snapshot":
		_add_issue(report, "error", "invalid_snapshot_kind", "kind", "项目结构 snapshot kind 无效。")
	var root_path: String = _get_string(snapshot, "root_path")
	if not _is_canonical_snapshot_root(root_path):
		_add_issue(report, "error", "invalid_snapshot_root", "root_path", "项目结构 snapshot root_path 必须是规范 res:// 根或子根。")
	if not snapshot.has("complete") or not snapshot["complete"] is bool:
		_add_issue(report, "error", "invalid_snapshot_complete", "complete", "项目结构 snapshot complete 必须是 bool。")
	_validate_snapshot_capture_status(snapshot, report)
	var scope_result: Dictionary = _validate_snapshot_scope(
		snapshot,
		root_path,
		report
	)
	var directories: PackedStringArray = _snapshot_path_list(snapshot, "directories", report)
	if _runtime_is_aborted():
		return result
	var files: PackedStringArray = _snapshot_path_list(snapshot, "files", report)
	if _runtime_is_aborted():
		return result
	var directory_set: Dictionary = _make_string_set(directories, report)
	if _runtime_is_aborted():
		return result
	for file_path: String in files:
		if not _evaluation_checkpoint(report):
			return result
		if directory_set.has(file_path):
			_add_issue(
				report,
				"error",
				"snapshot_path_role_conflict",
				file_path,
				"同一路径不能同时声明为文件和目录。"
			)
	_validate_snapshot_parent_closure(directories, files, directory_set, report)
	if _runtime_is_aborted():
		return result
	_validate_snapshot_scope_inventory(
		_get_dictionary(scope_result, "scope"),
		directories,
		files,
		report
	)
	if _runtime_is_aborted():
		return result
	_append_snapshot_capture_issues(snapshot, result, report)
	if _runtime_is_aborted():
		return result
	var capture_status: String = _get_string(snapshot, "capture_status")
	if (
		capture_status != "complete"
		and _get_array(result, "capture_issues").is_empty()
	):
		_add_issue(
			report,
			"error",
			(
				"snapshot_partial_without_capture_issue"
				if capture_status == "partial"
				else "snapshot_not_started_without_capture_issue"
			),
			"",
			"partial 或 not_started snapshot 必须保留至少一条合法捕获原因。"
		)
	if (
		capture_status == "not_started"
		and (not directories.is_empty() or not files.is_empty())
	):
		_add_issue(
			report,
			"error",
			"snapshot_not_started_with_inventory",
			"",
			"not_started snapshot 不能包含库存路径。"
		)
	result["directories"] = directories
	result["files"] = files
	result["directory_count"] = directories.size()
	result["file_count"] = files.size()
	var authoritative_scope: bool = _get_bool(scope_result, "authoritative")
	result["capture_status"] = (
		"partial"
		if capture_status == "complete" and not authoritative_scope
		else capture_status
	)
	result["root_observed"] = capture_status != "not_started"
	result["scope"] = _get_dictionary(scope_result, "scope").duplicate(true)
	result["complete"] = (
		_get_bool(snapshot, "complete")
		and capture_status == "complete"
		and authoritative_scope
	)
	return result


func _snapshot_path_list(
	snapshot: Dictionary,
	field_name: String,
	report: Dictionary
) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var seen_paths: Dictionary = {}
	var raw_value: Variant = snapshot.get(field_name)
	if not raw_value is Array and not raw_value is PackedStringArray:
		_add_issue(
			report,
			"error",
			"invalid_snapshot_path_list",
			field_name,
			"项目结构 snapshot %s 必须是字符串数组。" % field_name
		)
		return result
	var values: Array = []
	if raw_value is Array:
		var array_value: Array = raw_value
		values = array_value
	else:
		var packed_value: PackedStringArray = raw_value
		values = Array(packed_value)
	var maximum_count: int = (
		_ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_FILES
		if field_name == "files"
		else _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_DIRECTORIES
	)
	if values.size() > maximum_count:
		_add_issue(
			report,
			"error",
			"snapshot_path_limit_reached",
			field_name,
			"项目结构 snapshot %s 超过 %d 条路径上限。" % [
				field_name,
				maximum_count,
			]
		)
		return result
	for index: int in values.size():
		if not _evaluation_checkpoint(report):
			return result
		var path_value: Variant = values[index]
		if not path_value is String:
			_add_issue(
				report,
				"error",
				"invalid_snapshot_path",
				"%s[%d]" % [field_name, index],
				"项目结构 snapshot 路径必须是字符串。"
			)
			continue
		var relative_path: String = path_value
		if not _is_canonical_snapshot_path(relative_path):
			_add_issue(
				report,
				"error",
				"invalid_snapshot_path",
				"%s[%d]" % [field_name, index],
				"项目结构 snapshot 路径必须是规范项目相对路径。"
			)
			continue
		if seen_paths.has(relative_path):
			_add_issue(
				report,
				"error",
				"duplicate_snapshot_path",
				relative_path,
				"项目结构 snapshot 路径不能重复。"
			)
			continue
		seen_paths[relative_path] = true
		var _append_path: bool = result.append(relative_path)
	result.sort()
	return result


func _validate_snapshot_fields(snapshot: Dictionary, report: Dictionary) -> void:
	for key_value: Variant in snapshot.keys():
		if not _evaluation_checkpoint(report):
			return
		if not key_value is String:
			_add_issue(report, "error", "unsupported_snapshot_field", "", "项目结构 snapshot 字段名必须是字符串。")
			continue
		var key: String = key_value
		if not _SNAPSHOT_FIELDS.has(key):
			_add_issue(report, "error", "unsupported_snapshot_field", key, "项目结构 snapshot 包含不受支持的字段。")


func _validate_snapshot_capture_status(snapshot: Dictionary, report: Dictionary) -> void:
	if not snapshot.has("capture_status"):
		_add_issue(
			report,
			"error",
			"missing_snapshot_capture_status",
			"capture_status",
			"项目结构 snapshot 必须声明 terminal capture_status。"
		)
		return
	var status_value: Variant = snapshot["capture_status"]
	if not status_value is String:
		_add_issue(report, "error", "invalid_snapshot_capture_status", "capture_status", "capture_status 必须是字符串。")
		return
	var capture_status: String = status_value
	if not _SNAPSHOT_CAPTURE_STATUSES.has(capture_status):
		_add_issue(report, "error", "invalid_snapshot_capture_status", "capture_status", "capture_status 不属于支持的状态闭集。")
		return
	if snapshot.get("complete") is bool:
		var complete: bool = snapshot["complete"]
		if complete != (capture_status == "complete"):
			_add_issue(report, "error", "snapshot_capture_status_mismatch", "capture_status", "capture_status 与 complete 不一致。")


func _validate_snapshot_scope(
	snapshot: Dictionary,
	root_path: String,
	report: Dictionary
) -> Dictionary:
	var result: Dictionary = {
		"scope": {},
		"authoritative": false,
	}
	if not snapshot.has("scope"):
		_add_issue(
			report,
			"error",
			"missing_snapshot_scope",
			"scope",
			"项目结构 snapshot 必须声明闭合的 project_source scope。"
		)
		return result
	var scope_value: Variant = snapshot["scope"]
	if not scope_value is Dictionary:
		_add_issue(report, "error", "invalid_snapshot_scope", "scope", "snapshot scope 必须是 Dictionary。")
		return result
	var scope: Dictionary = scope_value
	if (
		scope.size() != _SNAPSHOT_SCOPE_FIELDS.size()
		or not _dictionary_has_only_fields(scope, _SNAPSHOT_SCOPE_FIELDS)
	):
		_add_issue(report, "error", "invalid_snapshot_scope", "scope", "snapshot scope 字段必须精确闭合。")
		return result

	var valid: bool = true
	if _get_string(scope, "kind") != "project_source":
		_add_issue(report, "error", "invalid_snapshot_scope", "scope.kind", "snapshot scope kind 必须为 project_source。")
		valid = false
	if _get_string(scope, "root_path") != root_path:
		_add_issue(report, "error", "snapshot_scope_root_mismatch", "scope.root_path", "snapshot scope root_path 必须与顶层 root_path 一致。")
		valid = false
	var include_hidden_value: Variant = scope.get("include_hidden")
	if not include_hidden_value is bool:
		_add_issue(report, "error", "invalid_snapshot_scope", "scope.include_hidden", "scope.include_hidden 必须是 bool。")
		valid = false
	var excluded_prefixes: PackedStringArray = _snapshot_scope_excluded_prefixes(
		scope,
		report
	)
	for budget_field: String in [
		"max_scanned_files",
		"max_scanned_directories",
		"max_scan_depth",
	]:
		if not _evaluation_checkpoint(report):
			return result
		var budget_value: Variant = scope.get(budget_field)
		if budget_value is int:
			var budget: int = budget_value
			if budget > 0:
				continue
		_add_issue(report, "error", "invalid_snapshot_scope", "scope.%s" % budget_field, "scope 捕获预算必须是正整数。")
		valid = false
	if not valid:
		return result

	var include_hidden: bool = false
	if include_hidden_value is bool:
		include_hidden = include_hidden_value
	var normalized_scope: Dictionary = _make_project_source_scope(
		root_path,
		include_hidden,
		_get_int(scope, "max_scanned_files"),
		_get_int(scope, "max_scanned_directories"),
		_get_int(scope, "max_scan_depth")
	)
	normalized_scope["excluded_prefixes"] = Array(excluded_prefixes)
	result["scope"] = normalized_scope
	var authoritative: bool = (
		include_hidden
		and excluded_prefixes == _PROJECT_SOURCE_EXCLUDED_PREFIXES
	)
	result["authoritative"] = authoritative
	if not authoritative:
		_add_issue(
			report,
			"warning",
			"project_source_scope_incomplete",
			"scope",
			"只有包含隐藏路径并精确排除 .git、.godot、.import 的库存才能证明 project_source 完整。"
		)
	return result


func _snapshot_scope_excluded_prefixes(
	scope: Dictionary,
	report: Dictionary
) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var seen_prefixes: Dictionary = {}
	var prefixes_value: Variant = scope.get("excluded_prefixes")
	if not (prefixes_value is Array or prefixes_value is PackedStringArray):
		_add_issue(report, "error", "invalid_snapshot_scope", "scope.excluded_prefixes", "scope.excluded_prefixes 必须是字符串数组。")
		return result
	var prefixes: Array = []
	if prefixes_value is Array:
		var array_prefixes: Array = prefixes_value
		prefixes = array_prefixes
	else:
		var packed_prefixes: PackedStringArray = prefixes_value
		prefixes = Array(packed_prefixes)
	for index: int in prefixes.size():
		if not _evaluation_checkpoint(report):
			return result
		var prefix_value: Variant = prefixes[index]
		if not prefix_value is String:
			_add_issue(report, "error", "invalid_snapshot_scope", "scope.excluded_prefixes[%d]" % index, "scope 排除前缀必须是字符串。")
			return PackedStringArray()
		var excluded_prefix: String = prefix_value
		if (
			not _is_canonical_snapshot_path(excluded_prefix)
			or seen_prefixes.has(excluded_prefix)
		):
			_add_issue(report, "error", "invalid_snapshot_scope", "scope.excluded_prefixes[%d]" % index, "scope 排除前缀必须是唯一的规范相对路径。")
			return PackedStringArray()
		seen_prefixes[excluded_prefix] = true
		var _append_prefix: bool = result.append(excluded_prefix)
	return result


func _validate_snapshot_scope_inventory(
	scope: Dictionary,
	directories: PackedStringArray,
	files: PackedStringArray,
	report: Dictionary
) -> void:
	if scope.is_empty():
		return
	if files.size() > _get_int(scope, "max_scanned_files"):
		_add_issue(report, "error", "snapshot_scope_budget_mismatch", "files", "snapshot 文件数超过 scope 声明的捕获预算。")
	if directories.size() > _get_int(scope, "max_scanned_directories"):
		_add_issue(report, "error", "snapshot_scope_budget_mismatch", "directories", "snapshot 目录数超过 scope 声明的捕获预算。")
	var max_scan_depth: int = _get_int(scope, "max_scan_depth")
	var excluded_prefixes: PackedStringArray = _get_string_list(
		scope,
		"excluded_prefixes"
	)
	var include_hidden: bool = _get_bool(scope, "include_hidden")
	for directory_path: String in directories:
		if not _evaluation_checkpoint(report):
			return
		_validate_snapshot_path_against_scope(
			directory_path,
			true,
			include_hidden,
			excluded_prefixes,
			max_scan_depth,
			report
		)
	for file_path: String in files:
		if not _evaluation_checkpoint(report):
			return
		_validate_snapshot_path_against_scope(
			file_path,
			false,
			include_hidden,
			excluded_prefixes,
			max_scan_depth,
			report
		)


func _validate_snapshot_path_against_scope(
	relative_path: String,
	is_directory: bool,
	include_hidden: bool,
	excluded_prefixes: PackedStringArray,
	max_scan_depth: int,
	report: Dictionary
) -> void:
	if is_directory and relative_path.split("/", false).size() > max_scan_depth:
		_add_issue(report, "error", "snapshot_scope_budget_mismatch", relative_path, "snapshot 目录深度超过 scope 声明的捕获预算。")
	if _is_under_excluded_prefix(relative_path, excluded_prefixes):
		_add_issue(report, "error", "snapshot_scope_exclusion_mismatch", relative_path, "snapshot 包含 scope 声明已排除的路径。")
	if not include_hidden and _path_contains_hidden_segment(relative_path):
		_add_issue(report, "error", "snapshot_scope_hidden_mismatch", relative_path, "snapshot 包含 scope 声明未捕获的隐藏路径。")


func _validate_snapshot_parent_closure(
	directories: PackedStringArray,
	files: PackedStringArray,
	directory_set: Dictionary,
	report: Dictionary
) -> void:
	for relative_path: String in directories:
		if not _evaluation_checkpoint(report):
			return
		_validate_snapshot_parent(relative_path, directory_set, report)
	for relative_path: String in files:
		if not _evaluation_checkpoint(report):
			return
		_validate_snapshot_parent(relative_path, directory_set, report)


func _validate_snapshot_parent(
	relative_path: String,
	directory_set: Dictionary,
	report: Dictionary
) -> void:
	var parent_path: String = _get_parent_path(relative_path)
	if parent_path.is_empty() or directory_set.has(parent_path):
		return
	_add_issue(
		report,
		"error",
		"snapshot_parent_not_observed",
		relative_path,
		"项目结构 snapshot 必须显式包含每个路径的父目录。",
		{ "parent_path": parent_path }
	)


func _append_snapshot_capture_issues(
	snapshot: Dictionary,
	result: Dictionary,
	report: Dictionary
) -> void:
	if not snapshot.has("issues"):
		return
	var issues_value: Variant = snapshot["issues"]
	if not issues_value is Array:
		_add_issue(report, "error", "invalid_snapshot_issues", "issues", "项目结构 snapshot issues 必须是数组。")
		return
	var issues: Array = issues_value
	if issues.size() > _MAX_SNAPSHOT_ISSUE_COUNT:
		_add_issue(report, "error", "snapshot_issue_limit_reached", "issues", "项目结构 snapshot issues 超过数量上限。")
		return
	var capture_issues: Array = _get_array(result, "capture_issues")
	for issue_index: int in issues.size():
		if not _evaluation_checkpoint(report):
			return
		var issue_value: Variant = issues[issue_index]
		if not issue_value is Dictionary:
			_add_issue(report, "error", "invalid_snapshot_issue", "issues[%d]" % issue_index, "snapshot issue 必须是 Dictionary。")
			continue
		var issue: Dictionary = issue_value
		if not _dictionary_has_only_fields(issue, _SNAPSHOT_ISSUE_FIELDS):
			_add_issue(report, "error", "invalid_snapshot_issue", "issues[%d]" % issue_index, "snapshot issue 包含未知字段。")
			continue
		var issue_kind: String = _get_string(issue, "kind")
		var issue_path: String = _get_string(issue, "path")
		var issue_message: String = _get_string(issue, "message")
		var issue_severity: String = _get_string(issue, "severity")
		if issue_kind.is_empty() or issue_message.is_empty() or not ["error", "warning", "info"].has(issue_severity):
			_add_issue(report, "error", "invalid_snapshot_issue", "issues[%d]" % issue_index, "snapshot issue 缺少合法 severity、kind 或 message。")
			continue
		if not issue_path.is_empty() and not _is_canonical_snapshot_path(issue_path):
			_add_issue(report, "error", "invalid_snapshot_issue", "issues[%d].path" % issue_index, "snapshot issue path 必须为空或规范项目相对路径。")
			continue
		var normalized_issue: Dictionary = {
			"severity": issue_severity,
			"kind": issue_kind,
			"path": issue_path,
			"message": issue_message,
		}
		capture_issues.append(normalized_issue)
		if _get_bool(snapshot, "complete"):
			var complete_issue_kind: String = (
				"snapshot_complete_with_capture_error"
				if issue_severity == "error"
				else "snapshot_complete_with_capture_issue"
			)
			_add_issue(
				report,
				"error",
				complete_issue_kind,
				issue_path,
				"标记为 complete 的 snapshot 不能同时包含捕获 issue。",
				{ "capture_kind": issue_kind }
			)
			continue
		_add_issue(
			report,
			"warning",
			issue_kind,
			issue_path,
			issue_message,
			{ "capture_severity": issue_severity }
		)


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


func _make_project_source_scope(
	root_path: String,
	include_hidden: bool,
	max_scanned_files: int,
	max_scanned_directories: int,
	max_scan_depth: int
) -> Dictionary:
	return {
		"kind": "project_source",
		"root_path": root_path,
		"include_hidden": include_hidden,
		"excluded_prefixes": Array(_PROJECT_SOURCE_EXCLUDED_PREFIXES),
		"max_scanned_files": max_scanned_files,
		"max_scanned_directories": max_scanned_directories,
		"max_scan_depth": max_scan_depth,
	}


func _make_string_set(
	values: PackedStringArray,
	report: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {}
	for value: String in values:
		if not report.is_empty() and not _evaluation_checkpoint(report):
			return result
		result[value] = true
	return result


func _is_under_excluded_prefix(
	relative_path: String,
	excluded_prefixes: PackedStringArray
) -> bool:
	for excluded_prefix: String in excluded_prefixes:
		if (
			relative_path == excluded_prefix
			or relative_path.begins_with("%s/" % excluded_prefix)
		):
			return true
	return false


func _path_contains_hidden_segment(relative_path: String) -> bool:
	for segment: String in relative_path.split("/", false):
		if segment.begins_with("."):
			return true
	return false


func _is_canonical_snapshot_root(root_path: String) -> bool:
	return _is_canonical_project_source_root(root_path)


func _is_canonical_project_source_root(root_path: String) -> bool:
	if (
		root_path.is_empty()
		or root_path != root_path.strip_edges()
		or root_path.contains("\\")
		or not root_path.begins_with("res://")
	):
		return false
	var relative_part: String = root_path.substr("res://".length())
	if relative_part.is_empty():
		return true
	return _is_canonical_snapshot_path(relative_part)


func _is_canonical_snapshot_path(relative_path: String) -> bool:
	if relative_path.is_empty() or relative_path != relative_path.strip_edges():
		return false
	if relative_path.contains("\\") or relative_path.begins_with("/"):
		return false
	if relative_path.ends_with("/") or relative_path.contains(":"):
		return false
	for part: String in relative_path.split("/", true):
		if part.is_empty() or part == "." or part == "..":
			return false
	return true

func _scan_directory(
	root_path: String,
	relative_path: String,
	include_hidden: bool,
	max_scanned_files: int,
	max_scanned_directories: int,
	max_scan_depth: int,
	depth: int,
	result: Dictionary,
	report: Dictionary
) -> void:
	if _get_bool(result, "_scan_aborted"):
		return
	if depth > max_scan_depth:
		_abort_scan(result, report, "scan_depth_limit_reached", root_path, "项目结构扫描超过目录深度上限，无法证明项目结构有效。")
		return

	var current_path: String = root_path if relative_path.is_empty() else root_path.path_join(relative_path)
	if _path_crosses_link(current_path):
		_abort_scan(
			result,
			report,
			"linked_path_not_allowed",
			current_path,
			"项目结构扫描不允许打开穿过符号链接或目录联接的目录。"
		)
		return
	var directory: DirAccess = DirAccess.open(ProjectSettings.globalize_path(current_path))
	if directory == null:
		_abort_scan(result, report, "directory_scan_failed", current_path, "目录无法扫描，无法证明项目结构有效。")
		return
	if _path_crosses_link(current_path):
		_abort_scan(
			result,
			report,
			"linked_path_not_allowed",
			current_path,
			"目录打开后路径链发生变化，项目结构扫描拒绝开始枚举。"
		)
		return
	directory.include_hidden = include_hidden
	var list_begin_result: Error = directory.list_dir_begin()
	if list_begin_result != OK:
		_abort_scan(result, report, "directory_scan_failed", current_path, "目录无法枚举，无法证明项目结构有效。")
		return

	var entry_name: String = directory.get_next()
	while not entry_name.is_empty() and not _get_bool(result, "_scan_aborted"):
		if not _evaluation_checkpoint(report):
			result["_scan_aborted"] = true
			break
		if entry_name == "." or entry_name == ".." or (not include_hidden and entry_name.begins_with(".")):
			entry_name = directory.get_next()
			continue
		if not _scan_joined_path_length_is_admissible(relative_path, entry_name):
			_abort_scan_resource_limit(result, report)
			break
		var entry_path: String = _join_relative_path(relative_path, entry_name)
		if (
			entry_path.length()
			> _ANALYSIS_CONTRACT_SCRIPT.MAX_RELATIVE_PATH_LENGTH
		):
			_abort_scan_resource_limit(result, report)
			break
		if _is_under_excluded_prefix(
			entry_path,
			_PROJECT_SOURCE_EXCLUDED_PREFIXES
		):
			entry_name = directory.get_next()
			continue
		if directory.is_link(entry_name):
			_abort_scan(
				result,
				report,
				"linked_path_not_allowed",
				root_path.path_join(entry_path),
				"项目结构扫描不允许符号链接或目录联接。"
			)
			break
		if directory.current_is_dir():
			if _get_int(result, "directory_count") >= max_scanned_directories:
				_abort_scan(result, report, "scan_directory_limit_reached", root_path, "项目结构扫描超过目录数量上限，无法证明项目结构有效。")
				break
			if not _reserve_scan_inventory_path(result, entry_path):
				_abort_scan_resource_limit(result, report)
				break
			var directory_list: PackedStringArray = _get_packed_string_array(result, "directories")
			var _append_directory: bool = directory_list.append(entry_path)
			result["directories"] = directory_list
			result["directory_count"] = _get_int(result, "directory_count") + 1
			_scan_directory(
				root_path,
				entry_path,
				include_hidden,
				max_scanned_files,
				max_scanned_directories,
				max_scan_depth,
				depth + 1,
				result,
				report
			)
		else:
			if _get_int(result, "file_count") >= max_scanned_files:
				_abort_scan(result, report, "scan_file_limit_reached", root_path, "项目结构扫描超过文件数量上限，无法证明项目结构有效。")
				break
			if not _reserve_scan_inventory_path(result, entry_path):
				_abort_scan_resource_limit(result, report)
				break
			var file_list: PackedStringArray = _get_packed_string_array(result, "files")
			var _append_file: bool = file_list.append(entry_path)
			result["files"] = file_list
			result["file_count"] = _get_int(result, "file_count") + 1
		entry_name = directory.get_next()
	directory.list_dir_end()


func _initial_scan_inventory_string_bytes(root_path: String) -> int:
	var result: int = 0
	for text: String in [
		"root_path",
		"scope",
		"capture_status",
		"directories",
		"files",
		root_path,
		"kind",
		"root_path",
		"include_hidden",
		"excluded_prefixes",
		"max_scanned_files",
		"max_scanned_directories",
		"max_scan_depth",
		"project_source",
		root_path,
		".git",
		".godot",
		".import",
	]:
		result += text.to_utf8_buffer().size()
	return result


func _scan_joined_path_length_is_admissible(
	relative_path: String,
	entry_name: String
) -> bool:
	if entry_name.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_RELATIVE_PATH_LENGTH:
		return false
	var separator_length: int = 0 if relative_path.is_empty() else 1
	return (
		relative_path.length()
		<= _ANALYSIS_CONTRACT_SCRIPT.MAX_RELATIVE_PATH_LENGTH
		- separator_length
		- entry_name.length()
	)


func _reserve_scan_inventory_path(result: Dictionary, relative_path: String) -> bool:
	if relative_path.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_RELATIVE_PATH_LENGTH:
		return false
	return _reserve_scan_inventory_text(
		result,
		relative_path,
		_ANALYSIS_CONTRACT_SCRIPT.MAX_RELATIVE_PATH_LENGTH
	)


func _reserve_scan_inventory_text(
	result: Dictionary,
	text: String,
	max_length: int
) -> bool:
	if text.length() > max_length:
		return false
	var consumed_bytes: int = _get_int(result, "_inventory_string_bytes")
	var text_bytes: int = text.to_utf8_buffer().size()
	if (
		consumed_bytes < 0
		or text_bytes > (
			_ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_STRING_BYTES
			- consumed_bytes
		)
	):
		return false
	result["_inventory_string_bytes"] = consumed_bytes + text_bytes
	return true


func _abort_scan_resource_limit(result: Dictionary, report: Dictionary) -> void:
	if _get_bool(result, "_input_resource_limit_exceeded"):
		return
	result["_scan_aborted"] = true
	result["_input_resource_limit_exceeded"] = true
	result["files"] = PackedStringArray()
	result["directories"] = PackedStringArray()
	result["file_count"] = 0
	result["directory_count"] = 0
	result["complete"] = false
	result["capture_status"] = "partial"
	result["capture_issues"] = []
	_append_capture_issue(
		result,
		"error",
		"analysis_input_resource_limit_exceeded",
		"",
		"项目结构分析输入超过固有资源边界；分析未开始。"
	)
	_replace_report_with_input_resource_terminal(report)


func _replace_report_with_input_resource_terminal(report: Dictionary) -> void:
	var terminal_report: Dictionary = _make_input_admission_report(
		_ADMISSION_RESOURCE_LIMIT
	)
	report.clear()
	for key_value: Variant in terminal_report.keys():
		report[key_value] = terminal_report[key_value]


func _abort_scan(
	result: Dictionary,
	report: Dictionary,
	kind: String,
	path: String,
	message: String
) -> void:
	if _get_bool(result, "_scan_aborted"):
		return
	result["_scan_aborted"] = true
	_append_capture_issue(result, "error", kind, path, message)
	_add_issue(report, "error", kind, path, message)


func _append_capture_issue(
	result: Dictionary,
	severity: String,
	kind: String,
	path: String,
	message: String
) -> void:
	var capture_issues: Array = _get_array(result, "capture_issues")
	capture_issues.append({
		"severity": severity,
		"kind": kind,
		"path": path,
		"message": message,
	})


func _validate_zones(profile: Dictionary, scan: Dictionary, report: Dictionary) -> void:
	var zones: Array = _get_array(profile, "zones")
	for zone_value: Variant in zones:
		if not _evaluation_checkpoint(report):
			return
		if not (zone_value is Dictionary):
			_add_issue(report, "error", "invalid_zone", "", "项目结构 profile zones 条目必须是 Dictionary。")
			continue

		var zone: Dictionary = zone_value
		var severity: String = _get_string(zone, "severity")
		if not _get_bool(zone, "required"):
			continue

		var roots: PackedStringArray = _get_string_list(zone, "roots")
		for relative_root: String in roots:
			if not _evaluation_checkpoint(report):
				return
			if relative_root.is_empty():
				continue
			if not _path_exists_in_scan(relative_root, scan, report):
				_add_issue(
					report,
					severity,
					"missing_required_zone_root",
					relative_root,
					"项目结构缺少必需目录：%s。" % relative_root,
					{ "zone_id": _get_string(zone, "id") }
				)


func _validate_rules(profile: Dictionary, scan: Dictionary, report: Dictionary, rule_registry: Dictionary) -> void:
	var execution_scan: Dictionary = scan.duplicate()
	execution_scan["_feature_contract_rules_by_root"] = (
		_index_feature_contract_rules_by_root(profile, report)
	)
	if _runtime_is_aborted():
		return
	var rules: Array = _get_array(profile, "rules")
	for rule_value: Variant in rules:
		if not _evaluation_checkpoint(report):
			return
		if not (rule_value is Dictionary):
			_add_issue(report, "error", "invalid_rule", "", "项目结构 profile rules 条目必须是 Dictionary。")
			continue

		var rule: Dictionary = rule_value
		var rule_result: Dictionary = _make_rule_result(rule)
		var kind: String = _get_string(rule, "kind")
		if not rule_registry.has(kind):
			_add_issue(
				report,
				"error",
				"invalid_profile_compilation",
				kind,
				"normalized profile 包含 Analyzer registry 未声明的规则。",
				{ "rule_id": _get_string(rule, "id") },
				"PROJECT_LAYOUT_PROFILE_COMPILATION_INVALID"
			)
			return
		var registry_entry: Dictionary = rule_registry[kind]
		var handler: Callable = registry_entry["handler"]
		var _handler_result: Variant = handler.call(
			rule,
			execution_scan,
			report,
			rule_result
		)
		if _runtime_is_aborted():
			return
		_finalize_rule_result(rule_result, report)


func _index_feature_contract_rules_by_root(
	profile: Dictionary,
	report: Dictionary
) -> Dictionary:
	var result: Dictionary = {}
	for rule_value: Variant in _get_array(profile, "rules"):
		if not _evaluation_checkpoint(report):
			return result
		if not rule_value is Dictionary:
			continue
		var rule: Dictionary = rule_value
		if _get_string(rule, "kind") != _RULE_FEATURE_MODULE_CONTRACT:
			continue
		for root: String in _get_string_list(rule, "roots"):
			if not _evaluation_checkpoint(report):
				return result
			var contracts_value: Variant = result.get(root, [])
			var contracts: Array = contracts_value if contracts_value is Array else []
			contracts.append(rule)
			result[root] = contracts
	return result


func _validate_forbid_root_files(rule: Dictionary, scan: Dictionary, report: Dictionary, rule_result: Dictionary) -> void:
	var allowed_files: PackedStringArray = _get_string_list(rule, "allowed_files")
	var allowed_file_set: Dictionary = _make_string_set(allowed_files, report)
	if _runtime_is_aborted():
		return
	var severity: String = _get_string(rule, "severity")
	var files: PackedStringArray = _get_packed_string_array(scan, "files")
	for file_path: String in files:
		if not _evaluation_checkpoint(report):
			return
		if file_path.contains("/"):
			continue
		rule_result["checked_count"] = _get_int(rule_result, "checked_count") + 1
		if not allowed_file_set.has(file_path):
			_add_rule_issue(
				report,
				rule_result,
				severity,
				"forbidden_root_file",
				file_path,
				"项目根目录文件未被 profile 声明：%s。" % file_path
			)


func _validate_naming_convention(rule: Dictionary, scan: Dictionary, report: Dictionary, rule_result: Dictionary) -> void:
	var pattern: String = _get_string(rule, "pattern")
	var target: String = _get_string(rule, "target")
	var expression: RegEx = _compile_regex(pattern)
	if expression == null:
		_add_rule_issue(report, rule_result, "error", "invalid_naming_pattern", "", "路径命名规则正则无法编译。")
		return

	var severity: String = _get_string(rule, "severity")
	var roots: PackedStringArray = _get_string_list(rule, "roots")
	var exclude: PackedStringArray = _get_string_list(rule, "exclude")
	var all_paths: PackedStringArray = _make_scanned_paths(scan, report)
	if _runtime_is_aborted():
		return
	for relative_path: String in all_paths:
		if not _evaluation_checkpoint(report):
			return
		if not _is_under_any_root(relative_path, roots, report):
			continue
		if _matches_any_pattern(relative_path, exclude, report):
			continue
		rule_result["checked_count"] = _get_int(rule_result, "checked_count") + 1
		var target_value: String = _naming_target_value(relative_path, target)
		if expression.search(target_value) == null:
			_add_rule_issue(
				report,
				rule_result,
				severity,
				"path_naming_mismatch",
				relative_path,
				"项目路径不符合命名约定：%s。" % relative_path,
				{ "pattern": pattern, "target": target, "target_value": target_value }
			)


func _naming_target_value(relative_path: String, target: String) -> String:
	if target == "name":
		return relative_path.get_file()
	if target == "stem":
		return relative_path.get_file().get_basename()
	return relative_path


func _validate_feature_module_contract(rule: Dictionary, scan: Dictionary, report: Dictionary, rule_result: Dictionary) -> void:
	var severity: String = _get_string(rule, "severity")
	var feature_id_pattern: String = _get_string(rule, "feature_id_pattern")
	var expression: RegEx = _compile_regex(feature_id_pattern)
	if expression == null:
		_add_rule_issue(report, rule_result, "error", "invalid_feature_id_pattern", "", "Feature ID 正则无法编译。")
		return

	var roots: PackedStringArray = _get_string_list(rule, "roots")
	var required_subdirs: PackedStringArray = _get_string_list(rule, "required_subdirs")
	for root: String in roots:
		if not _evaluation_checkpoint(report):
			return
		# required/pattern/root-file 诊断继续归属来源规则；逐规则 dispatch 共同形成
		# all-match/required union。共享 root 的 allowlist 必须显式取并集，避免
		# 另一条 contract 已声明的路径被当前规则误判。
		var allowed_subdirs: PackedStringArray = _feature_allowed_subdirs_for_root(
			scan,
			root,
			_get_string_list(rule, "allowed_subdirs"),
			report
		)
		if _runtime_is_aborted():
			return
		var feature_ids: PackedStringArray = _get_direct_child_directories(scan, root, report)
		for feature_id: String in feature_ids:
			if not _evaluation_checkpoint(report):
				return
			rule_result["checked_count"] = _get_int(rule_result, "checked_count") + 1
			var feature_root: String = root.path_join(feature_id)
			if expression.search(feature_id) == null:
				_add_rule_issue(
					report,
					rule_result,
					severity,
					"invalid_feature_id",
					feature_root,
					"Feature 目录名不符合 profile 约定：%s。" % feature_id,
					{ "pattern": feature_id_pattern }
				)
			_validate_feature_subdirs(rule, scan, report, rule_result, feature_root, required_subdirs, allowed_subdirs, severity)
			if not _get_bool(rule, "allow_root_files"):
				_validate_feature_root_files(scan, report, rule_result, feature_root, severity)


func _feature_allowed_subdirs_for_root(
	scan: Dictionary,
	root: String,
	fallback: PackedStringArray,
	report: Dictionary
) -> PackedStringArray:
	var rules_by_root_value: Variant = scan.get("_feature_contract_rules_by_root")
	if not rules_by_root_value is Dictionary:
		return fallback.duplicate()
	var rules_by_root: Dictionary = rules_by_root_value
	var contracts_value: Variant = rules_by_root.get(root)
	if not contracts_value is Array:
		return fallback.duplicate()
	var contracts: Array = contracts_value
	var result: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for contract_value: Variant in contracts:
		if not _evaluation_checkpoint(report):
			return result
		if not contract_value is Dictionary:
			continue
		var contract: Dictionary = contract_value
		for allowed_subdir: String in _get_string_list(contract, "allowed_subdirs"):
			if not _evaluation_checkpoint(report, 2):
				return result
			if seen.has(allowed_subdir):
				continue
			seen[allowed_subdir] = true
			var _append_allowed_subdir: bool = result.append(allowed_subdir)
	return result


func _validate_feature_subdirs(
	rule: Dictionary,
	scan: Dictionary,
	report: Dictionary,
	rule_result: Dictionary,
	feature_root: String,
	required_subdirs: PackedStringArray,
	allowed_subdirs: PackedStringArray,
	severity: String
) -> void:
	var child_dirs: PackedStringArray = _get_direct_child_directories(scan, feature_root, report)
	if _runtime_is_aborted():
		return
	var child_dir_set: Dictionary = _make_string_set(child_dirs, report)
	if _runtime_is_aborted():
		return
	var allowed_subdir_set: Dictionary = _make_string_set(
		allowed_subdirs,
		report
	)
	if _runtime_is_aborted():
		return
	for required_subdir: String in required_subdirs:
		if not _evaluation_checkpoint(report):
			return
		var required_path: String = feature_root.path_join(required_subdir)
		if not child_dir_set.has(required_subdir):
			_add_rule_issue(
				report,
				rule_result,
				severity,
				"missing_feature_subdir",
				required_path,
				"Feature 模块缺少必需子目录：%s。" % required_path
			)

	for child_dir: String in child_dirs:
		if not _evaluation_checkpoint(report):
			return
		if allowed_subdir_set.has(child_dir):
			continue
		_add_rule_issue(
			report,
			rule_result,
			severity,
			"unsupported_feature_subdir",
			feature_root.path_join(child_dir),
			"Feature 模块包含未声明子目录：%s。" % child_dir,
			{ "rule_id": _get_string(rule, "id") }
		)


func _validate_feature_root_files(
	scan: Dictionary,
	report: Dictionary,
	rule_result: Dictionary,
	feature_root: String,
	severity: String
) -> void:
	var files: PackedStringArray = _get_packed_string_array(scan, "files")
	for file_path: String in files:
		if not _evaluation_checkpoint(report):
			return
		if _get_parent_path(file_path) != feature_root:
			continue
		_add_rule_issue(
			report,
			rule_result,
			severity,
			"feature_root_file",
			file_path,
			"Feature 模块根目录不应直接放置文件：%s。" % file_path
		)


func _validate_generated_boundary(rule: Dictionary, scan: Dictionary, report: Dictionary, rule_result: Dictionary) -> void:
	var include: PackedStringArray = _get_string_list(rule, "include")
	var roots: PackedStringArray = _get_string_list(rule, "roots")
	var severity: String = _get_string(rule, "severity")
	var all_paths: PackedStringArray = _make_scanned_paths(scan, report)
	if _runtime_is_aborted():
		return
	for relative_path: String in all_paths:
		if not _evaluation_checkpoint(report):
			return
		if not _matches_any_pattern(relative_path, include, report):
			continue
		rule_result["checked_count"] = _get_int(rule_result, "checked_count") + 1
		if not _is_under_any_root(relative_path, roots, report):
			_add_rule_issue(
				report,
				rule_result,
				severity,
				"generated_path_outside_roots",
				relative_path,
				"生成物路径必须位于 profile 声明的 generated roots 中：%s。" % relative_path
			)


func _validate_bucket_size(rule: Dictionary, scan: Dictionary, report: Dictionary, rule_result: Dictionary) -> void:
	var max_files: int = _get_int(rule, "max_files")
	var severity: String = _get_string(rule, "severity")
	var roots: PackedStringArray = _get_string_list(rule, "roots")
	for root: String in roots:
		if not _evaluation_checkpoint(report):
			return
		var count: int = _count_files_under_root(scan, root, report)
		if _runtime_is_aborted():
			return
		rule_result["checked_count"] = _get_int(rule_result, "checked_count") + 1
		if count > max_files:
			_add_rule_issue(
				report,
				rule_result,
				severity,
				"bucket_size_exceeded",
				root,
				"大桶目录文件数量超过上限：%d > %d。" % [count, max_files],
				{ "file_count": count, "max_files": max_files }
			)


func _make_rule_result(rule: Dictionary) -> Dictionary:
	return {
		"id": _get_string(rule, "id"),
		"kind": _get_string(rule, "kind"),
		"severity": _get_string(rule, "severity"),
		"checked_count": 0,
		"issue_count": 0,
		"success": true,
	}


func _finalize_rule_result(rule_result: Dictionary, report: Dictionary) -> void:
	rule_result["success"] = _get_int(rule_result, "issue_count") == 0
	var rule_results: Array = _get_array(report, "rule_results")
	rule_results.append(rule_result.duplicate(true))


func _add_rule_issue(
	report: Dictionary,
	rule_result: Dictionary,
	severity: String,
	kind: String,
	path: String,
	message: String,
	context: Dictionary = {}
) -> void:
	var semantic_context: Dictionary = context.duplicate(true)
	semantic_context["rule_id"] = _get_string(rule_result, "id")
	if _try_add_issue(report, severity, kind, path, message, semantic_context):
		rule_result["issue_count"] = _get_int(rule_result, "issue_count") + 1


func _add_issue(
	report: Dictionary,
	severity: String,
	kind: String,
	path: String,
	message: String,
	context: Dictionary = {},
	reason_code: String = ""
) -> void:
	var _issue_added: bool = _try_add_issue(
		report,
		severity,
		kind,
		path,
		message,
		context,
		reason_code
	)


func _try_add_issue(
	report: Dictionary,
	severity: String,
	kind: String,
	path: String,
	message: String,
	context: Dictionary = {},
	reason_code: String = ""
) -> bool:
	if _runtime_active:
		if _runtime_is_aborted():
			return false
		var issues: Array = _get_array(report, "issues")
		if issues.size() >= maxi(_runtime_max_findings - 1, 0):
			if _runtime_cancel_requested():
				_set_runtime_abort(
					report,
					"evaluation_cancelled",
					"项目结构分析已按取消请求安全停止。"
				)
			else:
				_set_runtime_abort(
					report,
					"evaluation_finding_budget_exhausted",
					"项目结构分析达到 finding 数量上限；结果保持不完整。"
				)
			return false
	_append_issue_unchecked(
		report,
		severity,
		kind,
		path,
		message,
		context,
		reason_code
	)
	return true


func _append_issue_unchecked(
	report: Dictionary,
	severity: String,
	kind: String,
	path: String,
	message: String,
	context: Dictionary = {},
	reason_code: String = ""
) -> void:
	var issues: Array = _get_array(report, "issues")
	var issue: Dictionary = {
		"finding_id": "",
		"severity": severity,
		"kind": kind,
		"path": path,
		"message": message,
		"context": _sanitize_issue_context(context),
		"confidence": "known",
		"evidence_ids": [],
	}
	if not reason_code.is_empty():
		issue["reason_code"] = reason_code
	var contract: _ANALYSIS_CONTRACT_SCRIPT = _ANALYSIS_CONTRACT_SCRIPT.new()
	var finding_ids: Dictionary = _get_dictionary(report, "_finding_ids")
	var finding_occurrences: Dictionary = _get_dictionary(
		report,
		"_finding_occurrences"
	)
	var identity_key: String = contract.stable_finding_id(issue, 0)
	var occurrence: int = _get_int(finding_occurrences, identity_key)
	var finding_id: String = contract.stable_finding_id(issue, occurrence)
	finding_occurrences[identity_key] = occurrence + 1
	issue["finding_id"] = finding_id
	finding_ids[finding_id] = true
	issues.append(issue)
	if severity == "error":
		report["error_count"] = _get_int(report, "error_count") + 1
	elif severity == "warning":
		report["warning_count"] = _get_int(report, "warning_count") + 1
	else:
		report["info_count"] = _get_int(report, "info_count") + 1


func _sanitize_issue_context(context: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var entry_index: int = 0
	for key_value: Variant in context.keys():
		var key: String = _string_value(key_value)
		if key.is_empty():
			key = "entry_%d" % entry_index
		result[key] = _sanitize_report_value(context[key_value], 0)
		entry_index += 1
	return result


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


func _describe_value(value: Variant) -> Dictionary:
	var value_type: int = typeof(value)
	var result: Dictionary = {
		"type": value_type,
		"type_name": type_string(value_type),
	}
	if value == null or value is bool or value is int or value is String:
		result["value"] = value
	elif value is StringName:
		var string_name_value: StringName = value
		result["value"] = String(string_name_value)
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


func _finalize_report(report: Dictionary) -> Dictionary:
	if not _runtime_is_aborted():
		_attach_absence_evidence(report)
	report["success"] = _get_int(report, "error_count") == 0
	var graph: Dictionary = _get_dictionary(report, "graph")
	var capture_status: String = _get_string(graph, "capture_status", "not_started")
	var evaluation_complete: bool = (
		not _runtime_is_aborted()
		and
		_get_bool(report, "input_complete")
		and capture_status == "complete"
	)
	report["evaluation_complete"] = evaluation_complete
	if evaluation_complete:
		report["evaluation_status"] = "complete"
	elif _runtime_is_aborted():
		report["evaluation_status"] = _runtime_abort_status
	else:
		report["evaluation_status"] = "input_incomplete"
	report["findings"] = _get_array(report, "issues").duplicate(true)
	var _finding_ids_removed: bool = report.erase("_finding_ids")
	var _finding_occurrences_removed: bool = report.erase("_finding_occurrences")
	return report


func _attach_scan_result(
	report: Dictionary,
	scan: Dictionary,
	fail_on_empty: bool = false
) -> void:
	if _get_bool(scan, "_input_resource_limit_exceeded"):
		return
	var contract: _ANALYSIS_CONTRACT_SCRIPT = _ANALYSIS_CONTRACT_SCRIPT.new()
	var inventory: Dictionary = {
		"scope": scan.get("scope"),
		"capture_status": scan.get("capture_status"),
		"complete": scan.get("complete"),
		"root_observed": scan.get("root_observed"),
		"directories": scan.get("directories"),
		"files": scan.get("files"),
	}
	var attachment: Dictionary = contract.build_inventory_attachment(
		_get_string(report, "root_path"),
		inventory,
		Callable(self, "_runtime_checkpoint_callback") if _runtime_active else Callable()
	)
	if attachment.is_empty():
		if (
			fail_on_empty
			and not _runtime_is_aborted()
			and not _report_has_equivalent_unobserved_attachment(report, scan)
		):
			_replace_report_with_input_resource_terminal(report)
		return
	report["file_count"] = _get_int(attachment, "file_count")
	report["directory_count"] = _get_int(attachment, "directory_count")
	report["input_complete"] = _get_bool(scan, "complete")
	report["input_digest"] = _get_string(attachment, "input_digest")
	report["graph"] = _get_dictionary(attachment, "graph")


func _report_has_equivalent_unobserved_attachment(
	report: Dictionary,
	scan: Dictionary
) -> bool:
	if (
		_get_bool(scan, "root_observed")
		or _get_bool(scan, "complete")
		or _get_string(scan, "capture_status") != "not_started"
		or not _get_packed_string_array(scan, "directories").is_empty()
		or not _get_packed_string_array(scan, "files").is_empty()
		or _get_string(report, "input_digest").is_empty()
	):
		return false
	var graph: Dictionary = _get_dictionary(report, "graph")
	return (
		not _get_bool(graph, "complete")
		and _get_string(graph, "capture_status") == "not_started"
		and _get_dictionary(graph, "scope") == _get_dictionary(scan, "scope")
		and _get_array(graph, "nodes").is_empty()
		and _get_array(graph, "edges").is_empty()
		and _get_array(graph, "evidence").is_empty()
	)


func _attach_absence_evidence(report: Dictionary) -> void:
	var graph: Dictionary = _get_dictionary(report, "graph")
	if not _get_bool(graph, "complete"):
		return
	var inventory_evidence_id: String = ""
	for evidence_value: Variant in _get_array(graph, "evidence"):
		if not _evaluation_checkpoint(report):
			return
		if not evidence_value is Dictionary:
			continue
		var evidence: Dictionary = evidence_value
		if _get_string(evidence, "kind") == "filesystem_inventory_boundary":
			inventory_evidence_id = _get_string(evidence, "evidence_id")
			break
	if inventory_evidence_id.is_empty():
		return
	var observed_paths: Dictionary = {}
	for node_value: Variant in _get_array(graph, "nodes"):
		if not _evaluation_checkpoint(report):
			return
		if node_value is Dictionary:
			var node: Dictionary = node_value
			observed_paths[_get_string(node, "relative_path")] = true
	for issue_value: Variant in _get_array(report, "issues"):
		if not _evaluation_checkpoint(report):
			return
		if not issue_value is Dictionary:
			continue
		var issue: Dictionary = issue_value
		if not _ABSENCE_FINDING_KINDS.has(_get_string(issue, "kind")):
			continue
		if not _get_array(issue, "evidence_ids").is_empty():
			continue
		var issue_path: String = _get_string(issue, "path")
		if issue_path.is_empty() or observed_paths.has(issue_path):
			continue
		issue["evidence_ids"] = [inventory_evidence_id]


func _path_exists_in_scan(
	relative_path: String,
	scan: Dictionary,
	report: Dictionary
) -> bool:
	var directories: PackedStringArray = _get_packed_string_array(scan, "directories")
	for directory_path: String in directories:
		if not _evaluation_checkpoint(report):
			return false
		if directory_path == relative_path:
			return true
	var files: PackedStringArray = _get_packed_string_array(scan, "files")
	for file_path: String in files:
		if not _evaluation_checkpoint(report):
			return false
		if file_path == relative_path:
			return true
	return false


func _make_scanned_paths(scan: Dictionary, report: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var directories: PackedStringArray = _get_packed_string_array(scan, "directories")
	for directory_path: String in directories:
		if not _evaluation_checkpoint(report):
			return result
		var _append_directory: bool = result.append(directory_path)
	var files: PackedStringArray = _get_packed_string_array(scan, "files")
	for file_path: String in files:
		if not _evaluation_checkpoint(report):
			return result
		var _append_file: bool = result.append(file_path)
	return result


func _get_direct_child_directories(
	scan: Dictionary,
	root: String,
	report: Dictionary
) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	var directories: PackedStringArray = _get_packed_string_array(scan, "directories")
	for directory_path: String in directories:
		if not _evaluation_checkpoint(report, 2):
			return result
		if not _is_path_under_root(directory_path, root):
			continue
		var remainder: String = _relative_remainder(directory_path, root)
		if remainder.is_empty() or remainder.contains("/"):
			continue
		if not seen.has(remainder):
			seen[remainder] = true
			var _append_child: bool = result.append(remainder)
	return result


func _count_files_under_root(
	scan: Dictionary,
	root: String,
	report: Dictionary
) -> int:
	var count: int = 0
	var files: PackedStringArray = _get_packed_string_array(scan, "files")
	for file_path: String in files:
		if not _evaluation_checkpoint(report):
			return count
		if _is_path_under_root(file_path, root):
			count += 1
	return count


func _is_under_any_root(
	relative_path: String,
	roots: PackedStringArray,
	report: Dictionary
) -> bool:
	if roots.is_empty():
		return true
	for root: String in roots:
		if not _evaluation_checkpoint(report):
			return false
		if _is_path_under_root(relative_path, root):
			return true
	return false


func _is_path_under_root(relative_path: String, root: String) -> bool:
	if root.is_empty():
		return true
	return relative_path == root or relative_path.begins_with("%s/" % root)


func _relative_remainder(relative_path: String, root: String) -> String:
	if root.is_empty():
		return relative_path
	if relative_path == root:
		return ""
	if relative_path.begins_with("%s/" % root):
		return relative_path.substr(root.length() + 1)
	return ""


func _matches_any_pattern(
	relative_path: String,
	patterns: PackedStringArray,
	report: Dictionary
) -> bool:
	if patterns.is_empty():
		return false
	for pattern: String in patterns:
		if not _evaluation_checkpoint(report):
			return false
		if _matches_pattern(relative_path, pattern):
			return true
	return false


func _matches_pattern(relative_path: String, pattern: String) -> bool:
	if pattern.contains("*"):
		var expression: RegEx = _compile_glob(pattern)
		return expression != null and expression.search(relative_path) != null
	return relative_path == pattern


func _compile_glob(pattern: String) -> RegEx:
	var escaped: String = ""
	var index: int = 0
	while index < pattern.length():
		var character: String = pattern.substr(index, 1)
		if character == "*":
			if index + 1 < pattern.length() and pattern.substr(index + 1, 1) == "*":
				if index + 2 < pattern.length() and pattern.substr(index + 2, 1) == "/":
					escaped += "(?:.*/)?"
					index += 3
				else:
					escaped += ".*"
					index += 2
			else:
				escaped += "[^/]*"
				index += 1
			continue
		if character == "?":
			escaped += "[^/]"
			index += 1
			continue
		if "\\.^$+{}[]()|".contains(character):
			escaped += "\\%s" % character
		else:
			escaped += character
		index += 1
	var expression: RegEx = RegEx.new()
	var compile_result: Error = expression.compile("^%s$" % escaped)
	if compile_result != OK:
		return null
	return expression


func _compile_regex(pattern: String) -> RegEx:
	var expression: RegEx = RegEx.new()
	var compile_result: Error = expression.compile(pattern)
	if compile_result != OK:
		return null
	return expression


func _join_relative_path(base_path: String, file_name: String) -> String:
	if base_path.is_empty():
		return file_name.replace("\\", "/")
	return base_path.path_join(file_name).replace("\\", "/")


func _get_parent_path(relative_path: String) -> String:
	var slash_index: int = relative_path.rfind("/")
	if slash_index < 0:
		return ""
	return relative_path.substr(0, slash_index)


func _path_has_parent_segment(path: String) -> bool:
	var normalized_path: String = path.replace("\\", "/")
	var body: String = normalized_path
	if normalized_path.contains("://"):
		body = normalized_path.get_slice("://", 1)
	var parts: PackedStringArray = body.split("/", false)
	for part: String in parts:
		if part == "..":
			return true
	return false


func _path_crosses_link(path: String) -> bool:
	var probe_path: String = ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
	while not probe_path.is_empty():
		var parent_path: String = probe_path.get_base_dir()
		if parent_path == probe_path or parent_path.is_empty():
			return false
		var parent_exists: bool = (
			DirAccess.dir_exists_absolute(parent_path)
			or FileAccess.file_exists(parent_path)
		)
		if not parent_exists:
			probe_path = parent_path
			continue
		var parent_directory: DirAccess = DirAccess.open(parent_path)
		if parent_directory == null:
			return true
		if parent_directory.is_link(probe_path.get_file()):
			return true
		probe_path = parent_path
	return false


func _string_value(value: Variant) -> String:
	if value is String:
		var string_value: String = value
		return string_value
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value)
	return ""


func _is_non_empty_string_value(value: Variant) -> bool:
	return not _string_value(value).strip_edges().is_empty()


func _get_string(source: Dictionary, key: String, default_value: String = "") -> String:
	if not source.has(key):
		return default_value
	var value: Variant = source[key]
	if value is String:
		var string_value: String = value
		return string_value
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value)
	return default_value


func _get_bool(source: Dictionary, key: String, default_value: bool = false) -> bool:
	if not source.has(key):
		return default_value
	var value: Variant = source[key]
	if value is bool:
		var bool_value: bool = value
		return bool_value
	return default_value


func _get_int(source: Dictionary, key: String, default_value: int = 0) -> int:
	if not source.has(key):
		return default_value
	var value: Variant = source[key]
	if value is int:
		var int_value: int = value
		return int_value
	if value is float and _is_exact_integer(value):
		return _exact_integer_value(value)
	return default_value


func _is_exact_integer(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float:
		return false
	var float_value: float = value
	return is_finite(float_value) and float_value == floorf(float_value)


func _exact_integer_value(value: Variant, default_value: int = 0) -> int:
	if value is int:
		return value
	if value is float:
		var float_value: float = value
		if _is_exact_integer(float_value):
			return int(float_value)
	return default_value


func _get_positive_integer_option(options: Dictionary, key: String, default_value: int, report: Dictionary) -> int:
	if not options.has(key):
		return default_value
	var value: Variant = options[key]
	if value is int and value > 0:
		return value
	_add_issue(
		report,
		"error",
		"invalid_integer_option",
		key,
		"项目结构扫描选项 %s 必须是正整数。" % key,
		{ "option": key, "actual_value": value }
	)
	return default_value


func _get_array(source: Dictionary, key: String) -> Array:
	if not source.has(key):
		return []
	var value: Variant = source[key]
	if value is Array:
		var array_value: Array = value
		return array_value
	return []


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {}
	var value: Variant = source[key]
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value
	return {}


func _get_packed_string_array(source: Dictionary, key: String) -> PackedStringArray:
	if not source.has(key):
		return PackedStringArray()
	var value: Variant = source[key]
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value
	return PackedStringArray()


func _get_string_list(source: Dictionary, key: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if not source.has(key):
		return result

	var value: Variant = source[key]
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value.duplicate()
	if value is String:
		var string_value: String = value
		if not string_value.is_empty():
			var _append_string: bool = result.append(string_value)
		return result
	if value is StringName:
		var string_name_value: StringName = value
		if string_name_value != &"":
			var _append_string_name: bool = result.append(String(string_name_value))
		return result
	if value is Array:
		var array_value: Array = value
		for item: Variant in array_value:
			if item is String:
				var item_string: String = item
				if not item_string.is_empty():
					var _append_item_string: bool = result.append(item_string)
			elif item is StringName:
				var item_string_name: StringName = item
				if item_string_name != &"":
					var _append_item_string_name: bool = result.append(String(item_string_name))
	return result
