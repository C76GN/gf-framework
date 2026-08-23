# Project Layout 内部解释器。
#
# 该脚本没有 class_name，只处理 Analyzer 已冻结的 data-only 报告；不会访问文件系统或编辑器对象。
extends RefCounted


# --- 常量 ---

const _ANALYSIS_CONTRACT_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_analysis_contract.gd"
)
const _VALIDATION_FIELDS: PackedStringArray = [
	"valid",
	"errors",
	"capture_status",
	"complete",
	"index",
]
const _INDEX_FIELDS: PackedStringArray = [
	"node_by_id",
	"node_id_by_path",
	"children_by_id",
	"evidence_by_id",
	"finding_by_id",
]
const _MAX_FINDING_ID_LENGTH: int = 256


# --- 框架内部方法 ---

## 解释一条已冻结 finding 的观察、影响与人工下一步。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param analysis: 通过闭合 Project Layout analysis contract 的报告。
## [br]
## @schema analysis: Dictionary，必须符合闭合 project_layout_analysis/graph/scope/node/edge/evidence/finding 契约。
## [br]
## @param finding_id: analysis 中存在的稳定 finding ID。
## [br]
## @return: 不访问文件系统的只读解释。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、complete、finding_id、headline、observation、implication、next_steps、certainty、evidence、issues 和 effects；effects 精确包含 writes_project=false。
func explain_finding(analysis: Dictionary, finding_id: String) -> Dictionary:
	if finding_id.length() > _MAX_FINDING_ID_LENGTH:
		return _make_resource_limited_result()
	var contract: _ANALYSIS_CONTRACT_SCRIPT = _ANALYSIS_CONTRACT_SCRIPT.new()
	var validation: Dictionary = contract.validate_and_index(analysis)
	return explain_validated_analysis(
		analysis,
		validation,
		finding_id
	)


## 使用同一次 analysis contract 校验产生的局部 index 解释 finding。
##
## validation 只能来自紧邻本次调用的 validate_and_index()；本方法不会重新校验大型
## analysis，也不会把 index 写入返回值或长期状态。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param analysis: 已通过 validation 绑定校验的冻结分析报告。
## [br]
## @schema analysis: Dictionary，必须符合闭合 project_layout_analysis/graph 契约。
## [br]
## @param validation: 同一 analysis 的闭合 contract validation 和局部查询 index。
## [br]
## @schema validation: Dictionary，精确包含 valid、errors、capture_status、complete 和 index；index 精确包含 node_by_id、node_id_by_path、children_by_id、evidence_by_id 和 finding_by_id。
## [br]
## @param finding_id: analysis 中存在的稳定 finding ID。
## [br]
## @param checkpoint: 可选协作式工作检查；有效时接收本批正整数 work_units 并返回 bool。
## [br]
## @return: 不访问文件系统且不泄漏 validation index 的只读解释。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、complete、finding_id、headline、observation、implication、next_steps、certainty、evidence、issues 和 effects；effects 精确包含 writes_project=false。
func explain_validated_analysis(
	analysis: Dictionary,
	validation: Dictionary,
	finding_id: String,
	checkpoint: Callable = Callable()
) -> Dictionary:
	if finding_id.length() > _MAX_FINDING_ID_LENGTH:
		return _make_resource_limited_result()
	var result: Dictionary = _make_result(finding_id)
	if not _validation_is_usable(validation):
		_add_issue(result, "invalid_analysis", "输入不符合闭合 Project Layout analysis/graph 契约。")
		return result
	if not _checkpoint_allows(checkpoint):
		_stop_for_checkpoint(result)
		return result
	if finding_id.is_empty():
		_add_issue(result, "missing_finding_id", "finding_id 不能为空。")
		return result
	var analysis_index: Dictionary = _get_dictionary(validation, "index")
	var finding_by_id: Dictionary = _get_dictionary(analysis_index, "finding_by_id")
	var finding_value: Variant = finding_by_id.get(finding_id)
	var finding: Dictionary = {}
	if finding_value is Dictionary:
		finding = finding_value
	if finding.is_empty():
		_add_issue(result, "finding_not_found", "分析报告中不存在该 finding。")
		return result
	var severity: String = _get_string(finding, "severity", "info")
	var path: String = _get_string(finding, "path")
	result["headline"] = _make_headline(finding, path)
	result["observation"] = _get_string(finding, "message")
	result["implication"] = _make_implication(severity, _get_bool(analysis, "input_complete"))
	result["next_steps"] = _make_next_steps(severity, path)
	result["certainty"] = _get_string(finding, "confidence", "known")
	if not _collect_evidence(result, analysis_index, finding, path, checkpoint):
		return result
	if not _checkpoint_allows(checkpoint):
		_stop_for_checkpoint(result)
		return result
	result["complete"] = true
	return result


# --- 私有/辅助方法 ---

func _make_result(finding_id: String) -> Dictionary:
	return {
		"schema_version": 1,
		"kind": "project_layout_explanation",
		"complete": false,
		"finding_id": finding_id,
		"headline": "",
		"observation": "",
		"implication": "",
		"next_steps": [],
		"certainty": "unknown",
		"evidence": [],
		"issues": [],
		"effects": { "writes_project": false },
	}


func _make_resource_limited_result() -> Dictionary:
	var result: Dictionary = _make_result("")
	_add_issue(
		result,
		"explanation_resource_limit_exceeded",
		"Project Layout explanation 输入超出不可关闭的资源边界。"
	)
	return result


func _validation_is_usable(validation: Dictionary) -> bool:
	if not _has_exact_fields(validation, _VALIDATION_FIELDS):
		return false
	if not _get_bool(validation, "valid"):
		return false
	var analysis_index: Dictionary = _get_dictionary(validation, "index")
	return _has_exact_fields(analysis_index, _INDEX_FIELDS)


func _checkpoint_allows(checkpoint: Callable, work_units: int = 1) -> bool:
	if not checkpoint.is_valid():
		return true
	if checkpoint.get_argument_count() != 1 or work_units <= 0:
		return false
	var checkpoint_value: Variant = checkpoint.call(work_units)
	if checkpoint_value is bool:
		var checkpoint_result: bool = checkpoint_value
		return checkpoint_result
	return false


func _stop_for_checkpoint(result: Dictionary) -> void:
	result["evidence"] = []
	_add_issue(
		result,
		"explanation_checkpoint_stopped",
		"Project Layout explanation 已在协作式工作检查处停止。"
	)


func _make_headline(finding: Dictionary, path: String) -> String:
	var kind: String = _get_string(finding, "kind", "project_layout_finding")
	if path.is_empty():
		return kind
	return "%s · %s" % [kind, path]


func _make_implication(severity: String, input_complete: bool) -> String:
	if not input_complete:
		return "项目输入未完整捕获；当前结论不能用于证明变更安全。"
	if severity == "error":
		return "该问题阻止当前结构通过所选 profile；应先核对证据和 profile 权威。"
	if severity == "warning":
		return "该问题需要人工复核，但不代表目录或文件可以自动修改。"
	return "这是用于理解项目结构的观察信息，不会触发自动修复。"


func _make_next_steps(severity: String, path: String) -> Array[String]:
	var result: Array[String] = ["核对观察证据与所选 profile 是否属于同一项目范围。"]
	if not path.is_empty():
		result.append("检查路径 %s 的真实消费者、生成来源和发布范围。" % path)
	if severity == "error":
		result.append("在修改 profile 或项目结构前，先生成只读影响分析与计划。")
	else:
		result.append("若无需调整，可保留现状或在 profile 中显式记录例外。")
	return result


func _collect_evidence(
	explanation: Dictionary,
	analysis_index: Dictionary,
	finding: Dictionary,
	path: String,
	checkpoint: Callable
) -> bool:
	var evidence_ids: PackedStringArray = PackedStringArray()
	var seen_ids: Dictionary = {}
	for evidence_id_value: Variant in _get_array(finding, "evidence_ids"):
		if not _checkpoint_allows(checkpoint):
			_stop_for_checkpoint(explanation)
			return false
		if evidence_id_value is String:
			var evidence_id: String = evidence_id_value
			if not seen_ids.has(evidence_id):
				seen_ids[evidence_id] = true
				var _append_finding_evidence: bool = evidence_ids.append(evidence_id)
	var node_id_by_path: Dictionary = _get_dictionary(analysis_index, "node_id_by_path")
	var node_by_id: Dictionary = _get_dictionary(analysis_index, "node_by_id")
	var node_id_value: Variant = node_id_by_path.get(path)
	if node_id_value is String:
		if not _checkpoint_allows(checkpoint):
			_stop_for_checkpoint(explanation)
			return false
		var node_id: String = node_id_value
		var node_value: Variant = node_by_id.get(node_id)
		var node: Dictionary = node_value if node_value is Dictionary else {}
		for evidence_id_value: Variant in _get_array(node, "evidence_ids"):
			if not _checkpoint_allows(checkpoint):
				_stop_for_checkpoint(explanation)
				return false
			if evidence_id_value is String:
				var evidence_id: String = evidence_id_value
				if not seen_ids.has(evidence_id):
					seen_ids[evidence_id] = true
					var _append_node_evidence: bool = evidence_ids.append(evidence_id)
	var collected_evidence: Array[Dictionary] = []
	var evidence_by_id: Dictionary = _get_dictionary(analysis_index, "evidence_by_id")
	for evidence_id: String in evidence_ids:
		if not _checkpoint_allows(checkpoint):
			_stop_for_checkpoint(explanation)
			return false
		var evidence_value: Variant = evidence_by_id.get(evidence_id)
		if evidence_value is Dictionary:
			var evidence: Dictionary = evidence_value
			if not _checkpoint_allows(checkpoint, 1 + evidence.size()):
				_stop_for_checkpoint(explanation)
				return false
			collected_evidence.append(evidence.duplicate(true))
	explanation["evidence"] = collected_evidence
	return true


func _add_issue(result: Dictionary, issue_kind: String, message: String) -> void:
	var issues: Array = _get_array(result, "issues")
	issues.append({
		"severity": "error",
		"kind": issue_kind,
		"message": message,
	})


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


func _get_string(source: Dictionary, key: String, default_value: String = "") -> String:
	var value: Variant = source.get(key, default_value)
	return value if value is String else default_value


func _get_bool(source: Dictionary, key: String, default_value: bool = false) -> bool:
	var value: Variant = source.get(key, default_value)
	return value if value is bool else default_value


func _get_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	return value if value is Array else []


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return value if value is Dictionary else {}
