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

const _ANALYZER_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_analyzer.gd"
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
const _PLANNER_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_planner.gd"
)
const _REQUEST_FIELDS: PackedStringArray = [
	"generation",
	"snapshot",
	"profile_compilation_present",
	"profile_compilation",
	"plan_options",
]
const _QUERY_REQUEST_FIELDS: PackedStringArray = [
	"generation",
	"analysis_digest",
	"query_kind",
	"query",
]
const _QUERY_KINDS: PackedStringArray = [
	"explain_finding",
	"analyze_change_impact",
]
const _EXPLANATION_QUERY_FIELDS: PackedStringArray = ["finding_id"]
const _IMPACT_QUERY_FIELDS: PackedStringArray = [
	"kind",
	"source_path",
	"target_path",
]
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
const _EFFECT_FIELDS: PackedStringArray = ["writes_project"]
const _ISSUE_FIELDS: PackedStringArray = ["severity", "kind", "message"]
const _BLOCKER_FIELDS: PackedStringArray = ["kind", "path", "message"]
const _INVENTORY_EVIDENCE_FIELDS: PackedStringArray = [
	"evidence_id",
	"kind",
	"root_path",
	"relative_path",
	"scope",
	"authority",
	"observed",
]
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
const _SCOPE_FIELDS: PackedStringArray = [
	"kind",
	"root_path",
	"include_hidden",
	"excluded_prefixes",
	"max_scanned_files",
	"max_scanned_directories",
	"max_scan_depth",
]
const _MAX_FINDING_ID_LENGTH: int = 256
const _MAX_CHANGE_KIND_LENGTH: int = 16
const _MAX_CHANGE_PATH_LENGTH: int = 16_379
const _ANALYSIS_MAX_WORK_UNITS: int = 2_000_000
const _ANALYSIS_MAX_FINDINGS: int = 1_024
const _PLANNER_MAX_WORK_UNITS: int = _PLANNER_SCRIPT.MAX_WORK_UNITS
const _QUERY_MAX_WORK_UNITS: int = 16_000_000
const _QUERY_CANCEL_POLL_INTERVAL: int = 64
const _MAX_DATA_ONLY_NODE_COUNT: int = 500_000
const _MAX_DATA_ONLY_DEPTH: int = 65
const _MAX_DATA_ONLY_COLLECTION_ITEMS: int = \
	_ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_NODES
const _MAX_DATA_ONLY_STRING_LENGTH: int = \
	_ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH
const _MAX_DATA_ONLY_STRING_BYTES: int = \
	_ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_STRING_BYTES


# --- 私有变量 ---

var _cancel_mutex: Mutex = Mutex.new()
var _cancel_requested: bool = false
var _data_only_nodes_since_cancel_check: int = 0
var _data_only_node_count: int = 0
var _data_only_string_bytes: int = 0
var _query_analysis: Dictionary = {}
var _query_generation: int = -1
var _query_analysis_digest: String = ""
var _query_work_units: int = 0
var _query_units_since_cancel_check: int = 0
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

func _is_cancel_requested() -> bool:
	_cancel_mutex.lock()
	var result: bool = _cancel_requested
	_cancel_mutex.unlock()
	return result


func _reset_data_only_envelope() -> void:
	_data_only_nodes_since_cancel_check = 0
	_data_only_node_count = 0
	_data_only_string_bytes = 0


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


func _query_session_matches(generation: int, analysis_digest: String) -> bool:
	return (
		generation == _query_generation
		and analysis_digest == _query_analysis_digest
		and not _query_analysis.is_empty()
		and _get_string(_query_analysis, "input_digest") == analysis_digest
	)


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


func _validate_query_analysis() -> Dictionary:
	var contract: _ANALYSIS_CONTRACT_SCRIPT = _ANALYSIS_CONTRACT_SCRIPT.new()
	var checkpoint: Callable = Callable(self, "_query_checkpoint_allows")
	return contract.validate_and_index(
		_query_analysis,
		checkpoint
	)


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


func _string_array_is_valid(values: Array, checkpoint: Callable) -> bool:
	for value: Variant in values:
		if not _call_query_checkpoint(checkpoint) or not value is String:
			return false
	return true


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


func _change_is_closed(change: Dictionary) -> bool:
	return (
		_has_exact_fields(change, _IMPACT_QUERY_FIELDS)
		and change.get("kind") is String
		and change.get("source_path") is String
		and change.get("target_path") is String
	)


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


func _effects_are_read_only(effects: Dictionary) -> bool:
	return (
		_has_exact_fields(effects, _EFFECT_FIELDS)
		and effects.get("writes_project") is bool
		and not _get_bool(effects, "writes_project", true)
	)


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


func _add_issue(result: Dictionary, kind: String, message: String) -> void:
	var issues: Array = _get_array(result, "issues")
	issues.append({
		"severity": "error",
		"kind": kind,
		"message": message,
	})


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


func _report_has_error_issue(report: Dictionary) -> bool:
	for issue_value: Variant in _get_array(report, "issues"):
		if not issue_value is Dictionary:
			continue
		var issue: Dictionary = issue_value
		if _get_string(issue, "severity") == "error":
			return true
	return false


func _get_int(source: Dictionary, key: String, default_value: int = 0) -> int:
	var value: Variant = source.get(key, default_value)
	return value if value is int else default_value


func _get_bool(source: Dictionary, key: String, default_value: bool = false) -> bool:
	var value: Variant = source.get(key, default_value)
	return value if value is bool else default_value


func _get_string(source: Dictionary, key: String, default_value: String = "") -> String:
	var value: Variant = source.get(key, default_value)
	return value if value is String else default_value


func _get_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	return value if value is Array else []


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return value if value is Dictionary else {}
