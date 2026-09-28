@tool

## GFProjectLayoutScanWorker: data-only 项目结构后台分析、规划与查询 worker。
##
## 扫描输入只包含 snapshot、可选的已编译 profile、规划选项和请求 generation；查询
## 会话绑定同代际冻结 analysis，线程请求只传 digest 与小型查询载荷。worker 不访问
## 文件系统、EditorInterface、EditorFileSystem、Node 或 Resource，也不执行项目写入。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since 11.0.0
class_name GFProjectLayoutScanWorker
extends RefCounted


# --- 常量 ---

## Analyzer 实现脚本。
## [br]
## @api private
## [br]
const _ANALYZER_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_analyzer.gd"
)

## analysis 与库存共享契约实现脚本。
## [br]
## @api private
## [br]
const _ANALYSIS_CONTRACT_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_analysis_contract.gd"
)

## finding explanation 实现脚本。
## [br]
## @api private
## [br]
const _EXPLAINER_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_explainer.gd"
)

## change impact 分析实现脚本。
## [br]
## @api private
## [br]
const _IMPACT_ANALYZER_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_impact_analyzer.gd"
)

## Project Layout Planner 实现脚本。
## [br]
## @api private
## [br]
const _PLANNER_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_planner.gd"
)

## worker analysis 请求的闭合字段名集合。
## [br]
## @api private
## [br]
const _REQUEST_FIELDS: PackedStringArray = [
	"generation",
	"snapshot",
	"profile_compilation_present",
	"profile_compilation",
	"plan_options",
]

## worker 后台查询请求的闭合字段名集合。
## [br]
## @api private
## [br]
const _QUERY_REQUEST_FIELDS: PackedStringArray = [
	"generation",
	"analysis_digest",
	"query_kind",
	"query",
]

## worker 接受的 query_kind 值集合。
## [br]
## @api private
## [br]
const _QUERY_KINDS: PackedStringArray = [
	"explain_finding",
	"analyze_change_impact",
]

## explanation 查询 payload 的闭合字段名集合。
## [br]
## @api private
## [br]
const _EXPLANATION_QUERY_FIELDS: PackedStringArray = ["finding_id"]

## impact 查询 payload 的闭合字段名集合。
## [br]
## @api private
## [br]
const _IMPACT_QUERY_FIELDS: PackedStringArray = [
	"kind",
	"source_path",
	"target_path",
]

## explanation 查询结果的闭合字段名集合。
## [br]
## @api private
## [br]
const _EXPLANATION_RESULT_FIELDS: PackedStringArray = [
	"schema_version",
	"kind",
	"complete",
	"finding_id",
	"headline",
	"observation",
	"implication",
	"next_steps",
	"certainty",
	"evidence",
	"issues",
	"effects",
]

## impact 查询结果的闭合字段名集合。
## [br]
## @api private
## [br]
const _IMPACT_RESULT_FIELDS: PackedStringArray = [
	"schema_version",
	"kind",
	"complete",
	"status",
	"source_analysis_digest",
	"change",
	"affected_node_ids",
	"blockers",
	"evidence_ids",
	"issues",
	"effects",
]

## effects 字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _EFFECT_FIELDS: PackedStringArray = ["writes_project"]

## issue 字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _ISSUE_FIELDS: PackedStringArray = ["severity", "kind", "message"]

## blocker 字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _BLOCKER_FIELDS: PackedStringArray = ["kind", "path", "message"]

## inventory evidence 字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _INVENTORY_EVIDENCE_FIELDS: PackedStringArray = [
	"evidence_id",
	"kind",
	"root_path",
	"relative_path",
	"scope",
	"authority",
	"observed",
]

## inventory boundary evidence 字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _BOUNDARY_EVIDENCE_FIELDS: PackedStringArray = [
	"evidence_id",
	"kind",
	"root_path",
	"scope",
	"capture_scope",
	"capture_status",
	"authority",
	"complete",
	"file_count",
	"directory_count",
	"input_digest",
]

## snapshot scope 字典的闭合字段名集合。
## [br]
## @api private
## [br]
const _SCOPE_FIELDS: PackedStringArray = [
	"kind",
	"root_path",
	"include_hidden",
	"excluded_prefixes",
	"max_scanned_files",
	"max_scanned_directories",
	"max_scan_depth",
]

## finding_id 查询值允许的最大字符数。
## [br]
## @api private
## [br]
const _MAX_FINDING_ID_LENGTH: int = 256

## change.kind 查询值允许的最大字符数。
## [br]
## @api private
## [br]
const _MAX_CHANGE_KIND_LENGTH: int = 16

## change 路径查询值允许的最大字符数。
## [br]
## @api private
## [br]
const _MAX_CHANGE_PATH_LENGTH: int = 16_379

## analysis 请求允许的最大工作单位数。
## [br]
## @api private
## [br]
const _ANALYSIS_MAX_WORK_UNITS: int = 2_000_000

## analysis 请求允许的最大 finding 数。
## [br]
## @api private
## [br]
const _ANALYSIS_MAX_FINDINGS: int = 1_024

## Planner 请求允许的工作量上限。
## [br]
## @api private
## [br]
const _PLANNER_MAX_WORK_UNITS: int = _PLANNER_SCRIPT.MAX_WORK_UNITS

## query 请求允许的最大工作单位数。
## [br]
## @api private
## [br]
const _QUERY_MAX_WORK_UNITS: int = 16_000_000

## query data-only 遍历间允许累计的节点数。
## [br]
## @api private
## [br]
const _QUERY_CANCEL_POLL_INTERVAL: int = 64

## data-only 输入允许遍历的最大结构节点数。
## [br]
## @api private
## [br]
const _MAX_DATA_ONLY_NODE_COUNT: int = 500_000

## data-only 输入允许的最大嵌套深度。
## [br]
## @api private
## [br]
const _MAX_DATA_ONLY_DEPTH: int = 65

## data-only 输入单个容器允许的最大元素数。
## [br]
## @api private
## [br]
const _MAX_DATA_ONLY_COLLECTION_ITEMS: int = \
	_ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_NODES

## data-only 字符串允许的最大字符数。
## [br]
## @api private
## [br]
const _MAX_DATA_ONLY_STRING_LENGTH: int = \
	_ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH

## data-only 字符串总 UTF-8 字节数允许的最大值。
## [br]
## @api private
## [br]
const _MAX_DATA_ONLY_STRING_BYTES: int = \
	_ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_STRING_BYTES


# --- 私有变量 ---

## 保护跨线程取消标志的互斥锁。
## [br]
## @api private
## [br]
var _cancel_mutex: Mutex = Mutex.new()

## worker 当前是否收到取消请求。
## [br]
## @api private
## [br]
var _cancel_requested: bool = false

## data-only 检查后自上次取消轮询以来累计的节点数。
## [br]
## @api private
## [br]
var _data_only_nodes_since_cancel_check: int = 0

## 当前请求已检查的 data-only 结构节点数。
## [br]
## @api private
## [br]
var _data_only_node_count: int = 0

## 当前请求已检查的 data-only 字符串字节数。
## [br]
## @api private
## [br]
var _data_only_string_bytes: int = 0

## 当前 worker 查询会话冻结的 analysis。
## [br]
## @api private
## [br]
var _query_analysis: Dictionary = {}

## 当前查询会话绑定的 generation。
## [br]
## @api private
## [br]
var _query_generation: int = -1

## 当前查询会话绑定的 analysis digest。
## [br]
## @api private
## [br]
var _query_analysis_digest: String = ""

## 当前查询操作累计消费的工作单位数。
## [br]
## @api private
## [br]
var _query_work_units: int = 0

## 自上次查询取消轮询以来累计的工作单位数。
## [br]
## @api private
## [br]
var _query_units_since_cancel_check: int = 0

## 当前查询是否耗尽工作量预算。
## [br]
## @api private
## [br]
var _query_work_budget_exhausted: bool = false


# --- 框架内部方法 ---

## 执行 data-only 后台分析与规划请求。
## [br]
## @api framework_internal
## [br]
## @param request: Dictionary，字段闭集为 generation、snapshot、profile_compilation_present、profile_compilation 和 plan_options。
## [br]
## @schema request: Dictionary，generation 为 int；snapshot、profile_compilation 与 plan_options 为 data-only Dictionary，三者分别独立受单串、集合和 16 MiB UTF-8 文本封套约束；profile_compilation_present 为 bool；未提供 profile compilation 时后二者必须为空。
## [br]
## @return: Dictionary，包含 generation、status、analysis、plan 和 issues。
## [br]
## @schema return: Dictionary，字段闭集为 schema_version、kind、generation、status、analysis、plan 和 issues；status 属于 complete、partial、cancelled、failed；cancelled 与 failed 结果的 analysis、plan 必须同时为空。
func run_request(request: Dictionary) -> Dictionary:
	_reset_data_only_envelope()
	var generation: int = _get_int(request, "generation", -1)
	var result: Dictionary = {
		"schema_version": 1,
		"kind": "project_layout_worker_result",
		"generation": generation,
		"status": "failed",
		"analysis": {},
		"plan": {},
		"issues": [],
	}
	if _is_cancel_requested():
		result["status"] = "cancelled"
		return result
	if not _request_is_well_formed(request):
		_add_issue(result, "invalid_worker_request", "后台分析请求字段必须精确闭合且类型正确。")
		return result
	var snapshot: Dictionary = _get_dictionary(request, "snapshot")
	if snapshot.is_empty() or not _is_data_only(snapshot, 0):
		if _is_cancel_requested():
			result["status"] = "cancelled"
			return result
		_add_issue(result, "invalid_snapshot", "后台分析 snapshot 必须是有界 data-only Dictionary。")
		return result
	if _is_cancel_requested():
		result["status"] = "cancelled"
		return result
	_reset_data_only_envelope()
	var profile_compilation_present: bool = _get_bool(
		request,
		"profile_compilation_present"
	)
	var profile_compilation: Dictionary = _get_dictionary(
		request,
		"profile_compilation"
	)
	if profile_compilation_present and (
		profile_compilation.is_empty()
		or not _is_data_only(profile_compilation, 0)
	):
		if _is_cancel_requested():
			result["status"] = "cancelled"
			return result
		_add_issue(result, "invalid_profile_compilation", "后台分析 profile compilation 必须是有界 data-only Dictionary。")
		return result
	_reset_data_only_envelope()
	var plan_options: Dictionary = _get_dictionary(request, "plan_options")
	if not _is_data_only(plan_options, 0):
		if _is_cancel_requested():
			result["status"] = "cancelled"
			return result
		_add_issue(result, "invalid_plan_options", "后台规划选项必须是有界 data-only Dictionary。")
		return result
	if _is_cancel_requested():
		result["status"] = "cancelled"
		return result
	var analyzer: _ANALYZER_SCRIPT = _ANALYZER_SCRIPT.new()
	var cancel_check: Callable = Callable(self, "_is_cancel_requested")
	var analyzer_runtime: Dictionary = {
		"cancel_check": cancel_check,
		"max_work_units": _ANALYSIS_MAX_WORK_UNITS,
		"max_findings": _ANALYSIS_MAX_FINDINGS,
	}
	var analysis: Dictionary
	if profile_compilation_present:
		analysis = analyzer.analyze_compiled_profile_snapshot(
			profile_compilation,
			snapshot,
			analyzer_runtime
		)
	else:
		analysis = analyzer.analyze_snapshot_for_framework(
			snapshot,
			analyzer_runtime
		)
	if _is_cancel_requested():
		result["status"] = "cancelled"
		return result
	var analysis_complete: bool = (
		_get_bool(analysis, "input_complete")
		and _get_bool(analysis, "evaluation_complete")
	)
	if not analysis_complete:
		if _get_int(analysis, "error_count") > 0:
			_forward_first_error_issue(
				result,
				analysis,
				"analysis_failed",
				"后台分析未能形成可信的闭合结果。"
			)
			return result
		# Analyzer 为本次 worker 新建；线程结束后不会继续修改结果，可直接转移所有权，
		# 避免取消请求恰好落在大型 graph 深复制期间却无法及时结束。
		result["analysis"] = analysis
		result["status"] = "partial"
		return result
	if not profile_compilation_present:
		result["analysis"] = analysis
		result["status"] = "complete"
		return result

	var planner: _PLANNER_SCRIPT = _PLANNER_SCRIPT.new()
	var planner_runtime: Dictionary = {
		"cancel_check": cancel_check,
		"max_work_units": _PLANNER_MAX_WORK_UNITS,
	}
	var plan: Dictionary = planner.plan_compiled_profile_analysis(
		profile_compilation,
		analysis,
		plan_options,
		planner_runtime
	)
	if _is_cancel_requested():
		result["status"] = "cancelled"
		return result
	_reset_data_only_envelope()
	if plan.is_empty() or not _is_data_only(plan, 0):
		_add_issue(result, "invalid_plan_result", "后台规划未返回有界 data-only Dictionary。")
		return result
	if _report_has_error_issue(plan):
		_forward_first_error_issue(
			result,
			plan,
			"planning_failed",
			"后台规划未能形成可信的闭合结果。"
		)
		return result
	result["analysis"] = analysis
	result["plan"] = plan
	result["status"] = "complete" if _get_bool(plan, "complete") else "partial"
	return result


## 绑定一份由当前 Dock 扫描代际拥有的冻结 analysis 查询会话。
##
## 该入口只转移只读引用，不在调用线程复制、校验或索引大型 graph；完整校验与
## 查询都由 run_query_request() 在后台线程执行。
## [br]
## @api framework_internal
## [br]
## @param analysis: 最近一次 worker 生成且之后不再修改的 analysis。
## [br]
## @schema analysis: Dictionary，必须符合闭合 project_layout_analysis 契约；本入口不在调用线程验证。
## [br]
## @param generation: analysis 所属的 Dock 请求代际。
## [br]
## @param analysis_digest: analysis.input_digest 的 64 位小写 SHA-256。
## [br]
## @return: 当前 worker。
func configure_query_session(
	analysis: Dictionary,
	generation: int,
	analysis_digest: String
) -> GFProjectLayoutScanWorker:
	_query_analysis = analysis
	_query_generation = generation
	_query_analysis_digest = analysis_digest
	return self


## 在绑定的冻结 analysis 上执行解释或影响查询。
## [br]
## @api framework_internal
## [br]
## @param request: 只含代际、analysis digest、查询类型和小型 data-only 查询载荷。
## [br]
## @schema request: Dictionary，字段闭集为 generation、analysis_digest、query_kind 和 query；query_kind 属于 explain_finding、analyze_change_impact。
## [br]
## @return: 代际和 digest 绑定的闭合 data-only 查询结果。
## [br]
## @schema return: Dictionary，字段闭集为 schema_version、kind、generation、analysis_digest、query_kind、status、explanation、impact 和 issues；cancelled/failed 时 explanation 与 impact 均为空。
func run_query_request(request: Dictionary) -> Dictionary:
	var generation: int = _get_int(request, "generation", -1)
	var raw_analysis_digest: String = _get_string(request, "analysis_digest")
	var raw_query_kind: String = _get_string(request, "query_kind")
	var analysis_digest: String = (
		raw_analysis_digest if _is_lower_sha256(raw_analysis_digest) else ""
	)
	var query_kind: String = (
		raw_query_kind if _QUERY_KINDS.has(raw_query_kind) else ""
	)
	var result: Dictionary = _make_query_result(
		generation,
		analysis_digest,
		query_kind
	)
	if _is_cancel_requested():
		result["status"] = "cancelled"
		return result
	if not _query_request_is_well_formed(request):
		_add_issue(result, "invalid_query_request", "后台查询请求字段必须精确闭合且类型正确。")
		return result
	if not _query_session_matches(generation, analysis_digest):
		_add_issue(result, "query_session_mismatch", "后台查询与冻结 analysis 的代际或摘要不匹配。")
		return result

	_query_work_units = 0
	_query_units_since_cancel_check = 0
	_query_work_budget_exhausted = false
	var validation: Dictionary = _validate_query_analysis()
	if _apply_query_terminal(result):
		return result
	if not _get_bool(validation, "valid"):
		_add_issue(result, "invalid_query_analysis", "后台查询 analysis 未通过闭合契约校验。")
		return result
	# validation/index 只在当前 worker 栈帧内复用；不会进入请求、结果或长生命周期 session。
	if _apply_query_terminal(result):
		return result

	var checkpoint: Callable = Callable(self, "_query_checkpoint_allows")
	var query: Dictionary = _get_dictionary(request, "query")
	if query_kind == "explain_finding":
		var explainer: _EXPLAINER_SCRIPT = _EXPLAINER_SCRIPT.new()
		var explanation: Dictionary = explainer.explain_validated_analysis(
			_query_analysis,
			validation,
			_get_string(query, "finding_id"),
			checkpoint
		)
		if _apply_query_terminal(result):
			return result
		var explanation_is_valid: bool = _query_report_is_valid(
			explanation,
			query_kind,
			analysis_digest,
			checkpoint
		)
		if _apply_query_terminal(result):
			return result
		if not explanation_is_valid:
			_add_issue(result, "invalid_query_result", "后台解释未返回闭合 data-only 结果。")
			return result
		result["explanation"] = explanation
	else:
		var impact_analyzer: _IMPACT_ANALYZER_SCRIPT = _IMPACT_ANALYZER_SCRIPT.new()
		var impact: Dictionary = impact_analyzer.analyze_validated_change(
			_query_analysis,
			validation,
			query,
			checkpoint
		)
		if _apply_query_terminal(result):
			return result
		var impact_is_valid: bool = _query_report_is_valid(
			impact,
			query_kind,
			analysis_digest,
			checkpoint
		)
		if _apply_query_terminal(result):
			return result
		if not impact_is_valid:
			_add_issue(result, "invalid_query_result", "后台影响分析未返回闭合 data-only 结果。")
			return result
		result["impact"] = impact
	result["status"] = "complete"
	return result


## 请求后台 worker 在安全边界停止。
## [br]
## @api framework_internal
func cancel() -> void:
	_cancel_mutex.lock()
	_cancel_requested = true
	_cancel_mutex.unlock()


# --- 私有/辅助方法 ---

## 在取消互斥锁内读取标志，供后台检查点查询；不消费请求，也不检查查询会话身份。
## [br]
## @api private
func _is_cancel_requested() -> bool:
	_cancel_mutex.lock()
	var result: bool = _cancel_requested
	_cancel_mutex.unlock()
	return result


## 清零下一次数据边界校验的节点、文本及取消轮询计数，不改变当前请求或结果。
## [br]
## @api private
func _reset_data_only_envelope() -> void:
	_data_only_nodes_since_cancel_check = 0
	_data_only_node_count = 0
	_data_only_string_bytes = 0


## 按请求身份创建默认失败的闭合查询信封，解释、影响及问题容器各自新建。
## [br]
## @api private
func _make_query_result(
	generation: int,
	analysis_digest: String,
	query_kind: String
) -> Dictionary:
	return {
		"schema_version": 1,
		"kind": "project_layout_query_result",
		"generation": generation,
		"analysis_digest": analysis_digest,
		"query_kind": query_kind,
		"status": "failed",
		"explanation": {},
		"impact": {},
		"issues": [],
	}


## 检查查询信封和对应查询体的精确字段、类型及文本上限；摘要必须为小写 SHA-256，实际会话匹配另行检查。
## [br]
## @api private
func _query_request_is_well_formed(request: Dictionary) -> bool:
	if not _has_exact_fields(request, _QUERY_REQUEST_FIELDS):
		return false
	if (
		not request.get("generation") is int
		or not request.get("analysis_digest") is String
		or not request.get("query_kind") is String
		or not request.get("query") is Dictionary
	):
		return false
	var analysis_digest: String = _get_string(request, "analysis_digest")
	var query_kind: String = _get_string(request, "query_kind")
	var query: Dictionary = _get_dictionary(request, "query")
	if not _is_lower_sha256(analysis_digest) or not _QUERY_KINDS.has(query_kind):
		return false
	if query_kind == "explain_finding":
		if (
			not _has_exact_fields(query, _EXPLANATION_QUERY_FIELDS)
			or not query.get("finding_id") is String
		):
			return false
		return _get_string(query, "finding_id").length() <= _MAX_FINDING_ID_LENGTH
	if not _has_exact_fields(query, _IMPACT_QUERY_FIELDS):
		return false
	for field_name: String in _IMPACT_QUERY_FIELDS:
		if not query.get(field_name) is String:
			return false
		var field_text: String = _get_string(query, field_name)
		var maximum_length: int = (
			_MAX_CHANGE_KIND_LENGTH
			if field_name == "kind"
			else _MAX_CHANGE_PATH_LENGTH
		)
		if field_text.length() > maximum_length:
			return false
	return true


## 要求代次、摘要与已保存会话同时匹配，且冻结 analysis 非空并带有相同输入摘要。
## [br]
## @api private
func _query_session_matches(generation: int, analysis_digest: String) -> bool:
	return (
		generation == _query_generation
		and analysis_digest == _query_analysis_digest
		and not _query_analysis.is_empty()
		and _get_string(_query_analysis, "input_digest") == analysis_digest
	)


## 先扣除不可关闭的总工作预算，再按累计间隔轮询取消；非法工作量或超限标记预算耗尽。
## [br]
## @api private
func _query_checkpoint_allows(work_units: int) -> bool:
	if (
		work_units <= 0
		or _query_work_units > _QUERY_MAX_WORK_UNITS - work_units
	):
		_query_work_budget_exhausted = true
		return false
	_query_work_units += work_units
	_query_units_since_cancel_check += work_units
	if _query_units_since_cancel_check >= _QUERY_CANCEL_POLL_INTERVAL:
		_query_units_since_cancel_check %= _QUERY_CANCEL_POLL_INTERVAL
		if _is_cancel_requested():
			return false
	return true


## 以查询工作量检查点验证冻结 analysis 并构建索引，将契约验证结果原样交给查询入口。
## [br]
## @api private
func _validate_query_analysis() -> Dictionary:
	var contract: _ANALYSIS_CONTRACT_SCRIPT = _ANALYSIS_CONTRACT_SCRIPT.new()
	var checkpoint: Callable = Callable(self, "_query_checkpoint_allows")
	return contract.validate_and_index(
		_query_analysis,
		checkpoint
	)


## 取消优先于预算耗尽；命中任一终止条件就清空查询载荷与旧问题，预算失败另写单个错误并返回已终止。
## [br]
## @api private
func _apply_query_terminal(result: Dictionary) -> bool:
	if _is_cancel_requested():
		result["status"] = "cancelled"
		result["explanation"] = {}
		result["impact"] = {}
		result["issues"] = []
		return true
	if not _query_work_budget_exhausted:
		return false
	result["status"] = "failed"
	result["explanation"] = {}
	result["impact"] = {}
	result["issues"] = []
	_add_issue(
		result,
		"query_work_budget_exhausted",
		"后台查询超出不可关闭的总工作量边界。"
	)
	return true


## 重置数据预算后验证查询报告的只读 effects、闭合字段及嵌套列表；影响报告还必须回指请求的 analysis 摘要。
## [br]
## @api private
func _query_report_is_valid(
	report: Dictionary,
	query_kind: String,
	analysis_digest: String,
	checkpoint: Callable
) -> bool:
	_reset_data_only_envelope()
	if not _query_value_is_data_only(report, 0, [], checkpoint):
		return false
	if not _effects_are_read_only(_get_dictionary(report, "effects")):
		return false
	if query_kind == "explain_finding":
		return (
			_has_exact_fields(report, _EXPLANATION_RESULT_FIELDS)
			and report.get("schema_version") == 1
			and report.get("kind") == "project_layout_explanation"
			and report.get("complete") is bool
			and report.get("finding_id") is String
			and report.get("headline") is String
			and report.get("observation") is String
			and report.get("implication") is String
			and report.get("next_steps") is Array
			and report.get("certainty") is String
			and report.get("evidence") is Array
			and report.get("issues") is Array
			and _string_array_is_valid(_get_array(report, "next_steps"), checkpoint)
			and _evidence_array_is_valid(_get_array(report, "evidence"), checkpoint)
			and _issue_array_is_valid(_get_array(report, "issues"), checkpoint)
		)
	return (
		_has_exact_fields(report, _IMPACT_RESULT_FIELDS)
		and report.get("schema_version") == 1
		and report.get("kind") == "project_layout_impact"
		and report.get("complete") is bool
		and report.get("status") is String
		and ["safe", "unsafe", "unknown"].has(_get_string(report, "status"))
		and report.get("source_analysis_digest") == analysis_digest
		and report.get("change") is Dictionary
		and report.get("affected_node_ids") is Array
		and report.get("blockers") is Array
		and report.get("evidence_ids") is Array
		and report.get("issues") is Array
		and _change_is_closed(_get_dictionary(report, "change"))
		and _string_array_is_valid(_get_array(report, "affected_node_ids"), checkpoint)
		and _blocker_array_is_valid(_get_array(report, "blockers"), checkpoint)
		and _string_array_is_valid(_get_array(report, "evidence_ids"), checkpoint)
		and _issue_array_is_valid(_get_array(report, "issues"), checkpoint)
	)


## 在工作量检查点下递归验证有限标量和有界容器，累计节点及 UTF-8 字节；活动容器栈拒绝循环但允许非循环共享引用。
## [br]
## @api private
func _query_value_is_data_only(
	value: Variant,
	depth: int,
	active_containers: Array,
	checkpoint: Callable
) -> bool:
	if not _call_query_checkpoint(checkpoint):
		return false
	_data_only_node_count += 1
	if _data_only_node_count > _MAX_DATA_ONLY_NODE_COUNT or depth > _MAX_DATA_ONLY_DEPTH:
		return false
	if value == null or value is bool or value is int:
		return true
	if value is float:
		var float_value: float = value
		return is_finite(float_value)
	if value is String:
		var text: String = value
		if text.length() > _MAX_DATA_ONLY_STRING_LENGTH:
			return false
		var text_bytes: int = text.to_utf8_buffer().size()
		if _data_only_string_bytes > _MAX_DATA_ONLY_STRING_BYTES - text_bytes:
			return false
		_data_only_string_bytes += text_bytes
		return _call_query_checkpoint(
			checkpoint,
			maxi(1, ceili(float(text_bytes) / 256.0))
		)
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		if packed_value.size() > _MAX_DATA_ONLY_COLLECTION_ITEMS:
			return false
		for item: String in packed_value:
			if not _query_value_is_data_only(
				item,
				depth + 1,
				active_containers,
				checkpoint
			):
				return false
		return true
	if value is Array:
		var array_value: Array = value
		if (
			array_value.size() > _MAX_DATA_ONLY_COLLECTION_ITEMS
			or not _query_container_can_enter(array_value, active_containers, checkpoint)
		):
			return false
		active_containers.append(array_value)
		for item: Variant in array_value:
			if not _query_value_is_data_only(
				item,
				depth + 1,
				active_containers,
				checkpoint
			):
				var _discarded_array_on_failure: Variant = active_containers.pop_back()
				return false
		var _discarded_array_on_success: Variant = active_containers.pop_back()
		return true
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		if (
			dictionary_value.size() > _MAX_DATA_ONLY_COLLECTION_ITEMS
			or not _query_container_can_enter(dictionary_value, active_containers, checkpoint)
		):
			return false
		active_containers.append(dictionary_value)
		for key_value: Variant in dictionary_value.keys():
			if not key_value is String:
				var _discarded_invalid_dictionary: Variant = active_containers.pop_back()
				return false
			var key: String = key_value
			if not _query_value_is_data_only(
				key,
				depth + 1,
				active_containers,
				checkpoint
			):
				var _discarded_dictionary_key: Variant = active_containers.pop_back()
				return false
			if not _query_value_is_data_only(
				dictionary_value[key],
				depth + 1,
				active_containers,
				checkpoint
			):
				var _discarded_dictionary_value: Variant = active_containers.pop_back()
				return false
		var _discarded_dictionary_container: Variant = active_containers.pop_back()
		return true
	return false


## 先为活动栈比较扣除工作量，再按引用身份拒绝循环；不自行压栈，由递归调用者配对维护。
## [br]
## @api private
func _query_container_can_enter(
	container: Variant,
	active_containers: Array,
	checkpoint: Callable
) -> bool:
	if not _call_query_checkpoint(
		checkpoint,
		maxi(1, active_containers.size())
	):
		return false
	for active_container: Variant in active_containers:
		if is_same(active_container, container):
			return false
	return true


## 仅调用有效且恰有一个参数的检查点，严格要求布尔返回；其他返回类型一律视为拒绝。
## [br]
## @api private
func _call_query_checkpoint(
	checkpoint: Callable,
	work_units: int = 1
) -> bool:
	if not checkpoint.is_valid() or checkpoint.get_argument_count() != 1:
		return false
	var checkpoint_value: Variant = checkpoint.call(work_units)
	if checkpoint_value is bool:
		var checkpoint_result: bool = checkpoint_value
		return checkpoint_result
	return false


## 逐项执行工作量检查点并要求精确 String 类型，遇拒绝或其他类型立即失败。
## [br]
## @api private
func _string_array_is_valid(values: Array, checkpoint: Callable) -> bool:
	for value: Variant in values:
		if not _call_query_checkpoint(checkpoint) or not value is String:
			return false
	return true


## 逐项扣除工作量并要求问题仅含 severity、kind、message 三个文本字段；不在此限定严重性取值。
## [br]
## @api private
func _issue_array_is_valid(values: Array, checkpoint: Callable) -> bool:
	for value: Variant in values:
		if not _call_query_checkpoint(checkpoint) or not value is Dictionary:
			return false
		var issue: Dictionary = value
		if (
			not _has_exact_fields(issue, _ISSUE_FIELDS)
			or not issue.get("severity") is String
			or not issue.get("kind") is String
			or not issue.get("message") is String
		):
			return false
	return true


## 逐项扣除工作量，要求阻碍项具有闭合的 kind、path、message 文本字段。
## [br]
## @api private
func _blocker_array_is_valid(values: Array, checkpoint: Callable) -> bool:
	for value: Variant in values:
		if not _call_query_checkpoint(checkpoint) or not value is Dictionary:
			return false
		var blocker: Dictionary = value
		if (
			not _has_exact_fields(blocker, _BLOCKER_FIELDS)
			or not blocker.get("kind") is String
			or not blocker.get("path") is String
			or not blocker.get("message") is String
		):
			return false
	return true


## 检查变更只有 kind、source_path、target_path 三个文本字段；路径语义由其他契约层负责。
## [br]
## @api private
func _change_is_closed(change: Dictionary) -> bool:
	return (
		_has_exact_fields(change, _IMPACT_QUERY_FIELDS)
		and change.get("kind") is String
		and change.get("source_path") is String
		and change.get("target_path") is String
	)


## 逐项检查工作量，只接受文件清单或清单边界两种证据并委派相应闭合字段检查。
## [br]
## @api private
func _evidence_array_is_valid(values: Array, checkpoint: Callable) -> bool:
	for value: Variant in values:
		if not _call_query_checkpoint(checkpoint) or not value is Dictionary:
			return false
		var evidence: Dictionary = value
		var evidence_kind: String = _get_string(evidence, "kind")
		if evidence_kind == "filesystem_inventory":
			if not _inventory_evidence_is_closed(evidence):
				return false
		elif evidence_kind == "filesystem_inventory_boundary":
			if not _boundary_evidence_is_closed(evidence, checkpoint):
				return false
		else:
			return false
	return true


## 检查单路径清单证据的精确字段和类型；不据此重新访问文件系统或验证证据权威性。
## [br]
## @api private
func _inventory_evidence_is_closed(evidence: Dictionary) -> bool:
	return (
		_has_exact_fields(evidence, _INVENTORY_EVIDENCE_FIELDS)
		and evidence.get("evidence_id") is String
		and evidence.get("kind") == "filesystem_inventory"
		and evidence.get("root_path") is String
		and evidence.get("relative_path") is String
		and evidence.get("scope") is String
		and evidence.get("authority") is String
		and evidence.get("observed") is bool
	)


## 验证清单边界证据字段后继续校验嵌套 capture_scope；完整性及数量只检查类型。
## [br]
## @api private
func _boundary_evidence_is_closed(
	evidence: Dictionary,
	checkpoint: Callable
) -> bool:
	if (
		not _has_exact_fields(evidence, _BOUNDARY_EVIDENCE_FIELDS)
		or not evidence.get("evidence_id") is String
		or evidence.get("kind") != "filesystem_inventory_boundary"
		or not evidence.get("root_path") is String
		or not evidence.get("scope") is String
		or not evidence.get("capture_scope") is Dictionary
		or not evidence.get("capture_status") is String
		or not evidence.get("authority") is String
		or not evidence.get("complete") is bool
		or not evidence.get("file_count") is int
		or not evidence.get("directory_count") is int
		or not evidence.get("input_digest") is String
	):
		return false
	var scope: Dictionary = _get_dictionary(evidence, "capture_scope")
	return _scope_is_closed(scope, checkpoint)


## 按 scope 字段数扣除工作量，校验闭合扫描范围及排除路径文本数组；预算数值的有效范围由分析契约负责。
## [br]
## @api private
func _scope_is_closed(scope: Dictionary, checkpoint: Callable) -> bool:
	return (
		_call_query_checkpoint(checkpoint, 1 + scope.size())
		and _has_exact_fields(scope, _SCOPE_FIELDS)
		and scope.get("kind") is String
		and scope.get("root_path") is String
		and scope.get("include_hidden") is bool
		and scope.get("excluded_prefixes") is Array
		and _string_array_is_valid(_get_array(scope, "excluded_prefixes"), checkpoint)
		and scope.get("max_scanned_files") is int
		and scope.get("max_scanned_directories") is int
		and scope.get("max_scan_depth") is int
	)


## 只接受仅含布尔 writes_project 且值为 false 的副作用声明。
## [br]
## @api private
func _effects_are_read_only(effects: Dictionary) -> bool:
	return (
		_has_exact_fields(effects, _EFFECT_FIELDS)
		and effects.get("writes_project") is bool
		and not _get_bool(effects, "writes_project", true)
	)


## 判断字典键是否全部为字符串且与给定字段集合完全相同。
## [br]
## @api private
## [br]
func _has_exact_fields(source: Dictionary, fields: PackedStringArray) -> bool:
	if source.size() != fields.size():
		return false
	for key_value: Variant in source.keys():
		if not key_value is String:
			return false
		var key: String = key_value
		if not fields.has(key):
			return false
	return true


## 检查字符串是否为 64 个小写十六进制字符。
## [br]
## @api private
## [br]
func _is_lower_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character_index: int in value.length():
		var codepoint: int = value.unicode_at(character_index)
		if (
			(codepoint < 48 or codepoint > 57)
			and (codepoint < 97 or codepoint > 102)
		):
			return false
	return true


## 检查后台分析请求的精确字段及类型；未提供 profile compilation 时要求编译结果和规划选项同时为空。
## [br]
## @api private
func _request_is_well_formed(request: Dictionary) -> bool:
	if request.size() != _REQUEST_FIELDS.size():
		return false
	for key_value: Variant in request.keys():
		if not key_value is String:
			return false
		var key: String = key_value
		if not _REQUEST_FIELDS.has(key):
			return false
	return (
		request.get("generation") is int
		and request.get("snapshot") is Dictionary
		and request.get("profile_compilation_present") is bool
		and request.get("profile_compilation") is Dictionary
		and request.get("plan_options") is Dictionary
		and (
			_get_bool(request, "profile_compilation_present")
			or (
				_get_dictionary(request, "profile_compilation").is_empty()
				and _get_dictionary(request, "plan_options").is_empty()
			)
		)
	)


## 递归限制节点、深度、集合和 UTF-8 文本总量，并每 64 个节点轮询取消；只接受有限标量及文本键容器，循环最终由深度或节点预算拒绝。
## [br]
## @api private
func _is_data_only(value: Variant, depth: int) -> bool:
	_data_only_nodes_since_cancel_check += 1
	_data_only_node_count += 1
	if _data_only_node_count > _MAX_DATA_ONLY_NODE_COUNT:
		return false
	if _data_only_nodes_since_cancel_check >= 64:
		_data_only_nodes_since_cancel_check = 0
		if _is_cancel_requested():
			return false
	# compilation 为 profile 外再包一层结果；与 compiler 的 64 层 profile
	# 和 Analyzer 的 65 层 compilation envelope 闭合。
	if depth > _MAX_DATA_ONLY_DEPTH:
		return false
	if value == null or value is bool or value is int:
		return true
	if value is String:
		var string_value: String = value
		if string_value.length() > _MAX_DATA_ONLY_STRING_LENGTH:
			return false
		_data_only_string_bytes += string_value.to_utf8_buffer().size()
		return _data_only_string_bytes <= _MAX_DATA_ONLY_STRING_BYTES
	if value is float:
		var float_value: float = value
		return is_finite(float_value)
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		if packed_value.size() > _MAX_DATA_ONLY_COLLECTION_ITEMS:
			return false
		for item: String in packed_value:
			if not _is_data_only(item, depth + 1):
				return false
		return true
	if value is Array:
		var array_value: Array = value
		if array_value.size() > _MAX_DATA_ONLY_COLLECTION_ITEMS:
			return false
		for item: Variant in array_value:
			if not _is_data_only(item, depth + 1):
				return false
		return true
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		if dictionary_value.size() > _MAX_DATA_ONLY_COLLECTION_ITEMS:
			return false
		for key_value: Variant in dictionary_value.keys():
			if not key_value is String:
				return false
			var key: String = key_value
			if key.length() > _MAX_DATA_ONLY_STRING_LENGTH:
				return false
			_data_only_string_bytes += key.to_utf8_buffer().size()
			if _data_only_string_bytes > _MAX_DATA_ONLY_STRING_BYTES:
				return false
			if not _is_data_only(dictionary_value[key_value], depth + 1):
				return false
		return true
	return false


## 向结果已有的 issues 数组追加仅含严重性、种类及消息的错误；调用者须准备该数组。
## [br]
## @api private
func _add_issue(result: Dictionary, kind: String, message: String) -> void:
	var issues: Array = _get_array(result, "issues")
	issues.append({
		"severity": "error",
		"kind": kind,
		"message": message,
	})


## 只转发报告中的首个 error 字典，缺失种类或消息使用回退值；无可转发错误时写入通用失败。
## [br]
## @api private
func _forward_first_error_issue(
	result: Dictionary,
	report: Dictionary,
	fallback_kind: String,
	fallback_message: String
) -> void:
	for issue_value: Variant in _get_array(report, "issues"):
		if not issue_value is Dictionary:
			continue
		var issue: Dictionary = issue_value
		if _get_string(issue, "severity") != "error":
			continue
		_add_issue(
			result,
			_get_string(issue, "kind", fallback_kind),
			_get_string(issue, "message", fallback_message)
		)
		return
	_add_issue(result, fallback_kind, fallback_message)


## 在报告问题数组中查找 severity 为 error 的字典，跳过非字典项。
## [br]
## @api private
func _report_has_error_issue(report: Dictionary) -> bool:
	for issue_value: Variant in _get_array(report, "issues"):
		if not issue_value is Dictionary:
			continue
		var issue: Dictionary = issue_value
		if _get_string(issue, "severity") == "error":
			return true
	return false


## 读取字典中的 int 字段；类型不匹配时返回默认值。
## [br]
## @api private
## [br]
func _get_int(source: Dictionary, key: String, default_value: int = 0) -> int:
	var value: Variant = source.get(key, default_value)
	return value if value is int else default_value


## 读取字典中的 bool 字段；类型不匹配时返回默认值。
## [br]
## @api private
## [br]
func _get_bool(source: Dictionary, key: String, default_value: bool = false) -> bool:
	var value: Variant = source.get(key, default_value)
	return value if value is bool else default_value


## 读取字典中的 String 字段；类型不匹配时返回默认值。
## [br]
## @api private
## [br]
func _get_string(source: Dictionary, key: String, default_value: String = "") -> String:
	var value: Variant = source.get(key, default_value)
	return value if value is String else default_value


## 返回指定字段中的 Array；类型不匹配时返回空数组。
## [br]
## @api private
## [br]
func _get_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	return value if value is Array else []


## 返回指定字段中的 Dictionary；类型不匹配时返回空字典。
## [br]
## @api private
## [br]
func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return value if value is Dictionary else {}
