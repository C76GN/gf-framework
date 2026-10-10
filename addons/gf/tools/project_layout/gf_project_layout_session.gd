## GFProjectLayoutSession: 拥有一次编译与一次冻结分析的只读 Layout 会话。
##
## 会话不执行目标项目代码；结果通过深复制导出，查询复用内部 compilation 与验证索引。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since unreleased
class_name GFProjectLayoutSession
extends RefCounted


# --- 常量 ---

## 唯一规则执行器与编译入口。
## [br]
## @api private
const _ANALYZER_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_analyzer.gd")

## 严格 JSON 文件/文本准入。
## [br]
## @api private
const _READER_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_profile_reader.gd")

## 来源和捕获根必须使用相同映射。
## [br]
## @api private
const _SCOPE_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_capture_scope.gd")

## 完整冻结数据的唯一验证索引。
## [br]
## @api private
const _CONTRACT_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_analysis_contract.gd")

## 只读规划投影。
## [br]
## @api private
const _PLANNER_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_planner.gd")

## 只读解释投影。
## [br]
## @api private
const _EXPLAINER_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_explainer.gd")

## 只读影响投影。
## [br]
## @api private
const _IMPACT_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_impact_analyzer.gd")


# --- 私有变量 ---

## 当前会话拥有的编译策略，不借用调用方容器。
## [br]
## @api private
var _compilation: Dictionary = {}

## 当前会话拥有的冻结分析，不随外部返回值修改。
## [br]
## @api private
var _analysis: Dictionary = {}

## 当前分析仅验证一次；索引不对外导出。
## [br]
## @api private
var _validation: Dictionary = {}


# --- 公共方法 ---

## 严格准入真实来源文件的原始 JSON，编译一次后捕获只读库存。
##
## source_path 必须位于 options.source_root 中且 bytes 与 text 完全一致。
## 失败不捕获来源；此入口不加载场景、资源脚本或目标项目配置。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param text: 有界严格 UTF-8 Profile JSON 原文。
## [br]
## @param source_path: 根内真实 Profile 文件路径。
## [br]
## @param options: 有限捕获配置。
## [br]
## @schema options: Dictionary，可包含 root_path、source_root、capture_scope、profile_source_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth 和 allow_missing_root；profile_source_path 若给出必须等于 source_path。
## [br]
## @return 闭合 v2 analysis report。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects。
func open_profile_text(text: String, source_path: String, options: Dictionary = {}) -> Dictionary:
	close()
	var analyzer: GFProjectLayoutAnalyzer = _make_analyzer()
	var root_value: Variant = options.get("root_path", "res://")
	var source_value: Variant = options.get("source_root", "res://")
	var root_path: String = root_value if root_value is String else ""
	if not source_value is String or source_path.length() > 16_384 or not _SCOPE_SCRIPT.root_is_canonical(source_path):
		return _adopt(analyzer.reject_profile_input("invalid_profile_source", "Profile 来源必须是根内规范真实文件。", root_path))
	var source_root: String = source_value
	if not _SCOPE_SCRIPT.root_is_canonical(source_root):
		return _adopt(analyzer.reject_profile_input("invalid_profile_source", "Profile 来源根不规范。", root_path))
	var physical_path: String = _SCOPE_SCRIPT.physical_root(source_path)
	var physical_source: String = _SCOPE_SCRIPT.physical_root(source_root)
	if not physical_path.begins_with(physical_source + "/") or (options.has("profile_source_path") and options["profile_source_path"] != source_path):
		return _adopt(analyzer.reject_profile_input("invalid_profile_source", "Profile 来源不属于声明来源根或来源字段不一致。", root_path))
	var reader: _READER_SCRIPT = _READER_SCRIPT.new()
	var parsed: Dictionary = reader.read_path(source_path)
	if not parsed["success"] or parsed["text"] != text:
		return _adopt(analyzer.reject_profile_input("invalid_profile_json", "Profile 文件必须为稳定严格 JSON，原文必须匹配真实来源。", root_path))
	var profile: Dictionary = parsed["profile"]
	_compilation = analyzer.compile_profile(profile)
	var capture_options: Dictionary = options.duplicate(true)
	capture_options["profile_source_path"] = source_path
	return _adopt(analyzer.analyze_compiled_profile(_compilation, capture_options))


## 编译已拥有的纯数据 Profile 并捕获一次库存；不授予任何文件来源身份。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile: 闭合 schema v2 Profile。
## [br]
## @schema profile: Dictionary，必需 schema_version、id、zones、rules；可选 display_name、description、metadata、capture_scope。
## [br]
## @param options: 与 open_profile_text 相同的有限捕获选项。
## [br]
## @schema options: Dictionary，可包含 root_path、source_root、capture_scope、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth 和 allow_missing_root；不允许 profile_source_path。
## [br]
## @return 与 open_profile_text 相同的闭合 v2 analysis report。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects。
func open_profile(profile: Dictionary, options: Dictionary = {}) -> Dictionary:
	close()
	var analyzer: GFProjectLayoutAnalyzer = _make_analyzer()
	if options.has("profile_source_path"):
		return _adopt(analyzer.reject_profile_input("invalid_profile_source", "纯数据 Profile 不声明文件来源。", ""))
	_compilation = analyzer.compile_profile(profile)
	return _adopt(analyzer.analyze_compiled_profile(_compilation, options))


## 无 Profile 时只观察明确捕获范围，不执行项目结构规则。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param options: 有限来源捕获选项。
## [br]
## @schema options: Dictionary，与 open_profile 的捕获字段相同。
## [br]
## @return 闭合 v2 analysis report，rule_results 为空。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、evaluation_status、evaluation_complete、input_complete、success、profile_id、root_path、input_digest、file_count、directory_count、graph、issues、findings、error_count、warning_count、info_count、rule_results、capabilities 和 effects。
func observe(options: Dictionary = {}) -> Dictionary:
	close()
	var analyzer: GFProjectLayoutAnalyzer = _make_analyzer()
	return _adopt(analyzer.analyze(options))


## 返回当前冻结报告的深复制；外部修改不会改变会话查询。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 最近报告，未打开或 close 后为空字典。
## [br]
## @schema return: Dictionary，空字典或 open_profile_text 的完整 report。
func get_analysis() -> Dictionary:
	return _analysis.duplicate(true)


## 用当前已编译策略及已验证冻结库存生成只读目录候选计划。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param options: 有限规划选项。
## [br]
## @schema options: Dictionary，可包含 feature_ids、include_optional_zones、include_optional_feature_subdirs。
## [br]
## @return 闭合 v2 plan；会话未准备好时 complete=false。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、complete、profile_id、source_analysis_digest、contract_digest、project_root、capabilities、steps、blockers、issues。
func plan(options: Dictionary = {}) -> Dictionary:
	return plan_for_framework(options)


## 从当前冻结 finding 与证据解释，不重新扫描或编译。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param finding_id: 当前报告中的 finding ID。
## [br]
## @return 闭合只读解释。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、complete、finding_id、headline、observation、implication、next_steps、certainty、evidence、issues、effects。
func explain(finding_id: String) -> Dictionary:
	var explainer: _EXPLAINER_SCRIPT = _EXPLAINER_SCRIPT.new()
	return explainer.explain_validated_analysis(_analysis, _validation, finding_id)


## 对显式路径变更计算冻结库存影响；不执行变更。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param change: 有限变更声明。
## [br]
## @schema change: Dictionary，精确包含 kind、source_path、target_path；kind 为 delete、move 或 rename。
## [br]
## @return 闭合只读影响报告。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、complete、status、source_analysis_digest、change、affected_node_ids、blockers、evidence_ids、issues、effects。
func impact(change: Dictionary) -> Dictionary:
	var impact_analyzer: _IMPACT_SCRIPT = _IMPACT_SCRIPT.new()
	return impact_analyzer.analyze_validated_change(_analysis, _validation, change)


## 释放本次 compilation、冻结报告与查询索引。
## [br]
## @api public
## [br]
## @since unreleased
func close() -> void:
	_compilation = {}
	_analysis = {}
	_validation = {}


# --- 框架内部方法 ---

## 接管由同代际 Analyzer 新建的独占策略及报告；调用方之后不得修改它们。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param compilation: 已编译策略，无 Profile 时为空。
## [br]
## @schema compilation: Dictionary，空字典或 canonical compilation 闭合结果。
## [br]
## @param analysis: 当前代际新建且不再修改的完整 report。
## [br]
## @schema analysis: Dictionary，闭合 v2 analysis report。
func adopt_owned_analysis(compilation: Dictionary, analysis: Dictionary) -> void:
	close()
	_compilation = compilation
	_analysis = analysis


## 确认 worker 借用的冻结 report 正是本会话拥有的容器。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param analysis: 只读借用 report。
## [br]
## @schema analysis: Dictionary，闭合 v2 analysis report。
## [br]
## @return 是否相同容器身份。
func owns_analysis_for_framework(analysis: Dictionary) -> bool:
	return is_same(_analysis, analysis)


## 在后台按有限 checkpoint 验证一次；有效缓存仅供同一独占报告的内部查询借用。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param checkpoint: 可选 Callable，接收正整数工作量，返回是否继续。
## [br]
## @return 同一 report 的内部验证与索引，调用方不得修改。
## [br]
## @schema return: Dictionary，空字典或精确 valid、errors、capture_status、complete、index。
func get_owned_validation_for_framework(checkpoint: Callable = Callable()) -> Dictionary:
	if _validation.is_empty() and not _analysis.is_empty():
		var contract: _CONTRACT_SCRIPT = _CONTRACT_SCRIPT.new()
		var validation: Dictionary = contract.validate_and_index(_analysis, checkpoint)
		if validation.get("valid", false):
			_validation = validation
		return validation
	return _validation


## 使用独占策略生成支持协作式取消的后台计划，不再编译或反复校验完整图。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param options: 有限规划选项。
## [br]
## @schema options: Dictionary，可包含 feature_ids、include_optional_zones、include_optional_feature_subdirs。
## [br]
## @param runtime: 规划协作边界。
## [br]
## @schema runtime: Dictionary，空字典或精确 cancel_check: Callable、max_work_units: int。
## [br]
## @param checkpoint: 完整验证的有限工作检查。
## [br]
## @return 闭合只读计划。
## [br]
## @schema return: Dictionary，schema_version、kind、complete、profile_id、source_analysis_digest、contract_digest、project_root、capabilities、steps、blockers、issues。
func plan_for_framework(options: Dictionary = {}, runtime: Dictionary = {}, checkpoint: Callable = Callable()) -> Dictionary:
	var validation: Dictionary = get_owned_validation_for_framework(checkpoint)
	var planner: _PLANNER_SCRIPT = _PLANNER_SCRIPT.new()
	return planner.plan_owned_policy(_compilation, _analysis, validation, options, runtime)


# --- 私有/辅助方法 ---

## 每次打开创建唯一执行器；查询不会调用此工厂或重新编译。
## [br]
## @api private
func _make_analyzer() -> GFProjectLayoutAnalyzer:
	return _ANALYZER_SCRIPT.new()

## 接管独占报告并验证一次；外部只收到深复制。
## [br]
## @api private
func _adopt(analysis: Dictionary) -> Dictionary:
	_analysis = analysis
	if analysis.get("input_complete", false) and analysis.get("evaluation_complete", false):
		var contract: _CONTRACT_SCRIPT = _CONTRACT_SCRIPT.new()
		_validation = contract.validate_and_index(_analysis)
	return _analysis.duplicate(true)
