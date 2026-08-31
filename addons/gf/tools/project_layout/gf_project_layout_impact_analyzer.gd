# Project Layout 内部影响分析器。
#
# 该脚本没有 class_name，只在 Analyzer 的 data-only 图上模拟 change；不会执行任何项目修改。
extends RefCounted


# --- 常量 ---

const _CHANGE_FIELDS: PackedStringArray = ["kind", "source_path", "target_path"]
const _CHANGE_KINDS: PackedStringArray = ["delete", "move", "rename"]
const _MAX_CHANGE_FIELDS: int = 3
const _MAX_CHANGE_KEY_LENGTH: int = 32
const _MAX_CHANGE_KIND_LENGTH: int = 16
const _MAX_CHANGE_PATH_LENGTH: int = 16_379
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


# --- 框架内部方法 ---

## 在冻结 analysis 图上模拟删除、移动或重命名的影响。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param analysis: 通过闭合 Project Layout analysis contract 的报告。
## [br]
## @schema analysis: Dictionary，必须符合闭合 project_layout_analysis/graph/scope/node/edge/evidence/finding 契约。
## [br]
## @param change: 待模拟的 data-only 变更。
## [br]
## @schema change: Dictionary，字段闭集为 kind、source_path 和 target_path；kind 属于 delete、move、rename。
## [br]
## @return: 只读影响报告，status 属于 safe、unsafe、unknown。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、complete、status、source_analysis_digest、change、affected_node_ids、blockers、evidence_ids、issues 和 effects；effects 精确包含 writes_project=false。
func analyze_change(analysis: Dictionary, change: Dictionary) -> Dictionary:
	if not _change_is_intrinsically_admissible(change):
		return _make_resource_limited_result()
	var contract: _ANALYSIS_CONTRACT_SCRIPT = _ANALYSIS_CONTRACT_SCRIPT.new()
	var validation: Dictionary = contract.validate_and_index(analysis)
	return analyze_validated_change(
		analysis,
		validation,
		change
	)


## 使用同一次 analysis contract 校验产生的局部 index 模拟结构变更。
##
## validation 只能来自紧邻本次调用的 validate_and_index()；本方法不会重新校验大型
## analysis，也不会把 index 写入影响报告或长期状态。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param analysis: 已通过 validation 绑定校验的冻结分析报告。
## [br]
## @schema analysis: Dictionary，必须符合闭合 project_layout_analysis/graph 契约。
## [br]
## @param validation: 同一 analysis 的闭合 contract validation 和局部查询 index。
## [br]
## @schema validation: Dictionary，精确包含 valid、errors、capture_status、complete 和 index；index 精确包含 node_by_id、node_id_by_path、children_by_id、evidence_by_id 和 finding_by_id。
## [br]
## @param change: 待模拟的 data-only 变更。
## [br]
## @schema change: Dictionary，字段闭集为 kind、source_path 和 target_path；kind 属于 delete、move、rename。
## [br]
## @param checkpoint: 可选协作式工作检查；有效时接收本批正整数 work_units 并返回 bool。
## [br]
## @return: 不执行写入且不泄漏 validation index 的只读影响报告。
## [br]
## @schema return: Dictionary，精确包含 schema_version、kind、complete、status、source_analysis_digest、change、affected_node_ids、blockers、evidence_ids、issues 和 effects；effects 精确包含 writes_project=false。
func analyze_validated_change(
	analysis: Dictionary,
	validation: Dictionary,
	change: Dictionary,
	checkpoint: Callable = Callable()
) -> Dictionary:
	if not _change_is_intrinsically_admissible(change):
		return _make_resource_limited_result()
	var result: Dictionary = _make_result("")
	if not _validation_is_usable(validation):
		_add_issue(result, "invalid_analysis", "输入不符合闭合 Project Layout analysis/graph 契约。")
		result["status"] = "unsafe"
		return result
	if not _checkpoint_allows(checkpoint):
		_stop_for_checkpoint(result)
		return result
	result["source_analysis_digest"] = _get_string(analysis, "input_digest")
	var normalized_change: Dictionary = _normalize_change(change, result)
	result["change"] = normalized_change
	if not _get_array(result, "issues").is_empty():
		result["status"] = "unsafe"
		return result
	var graph: Dictionary = _get_dictionary(analysis, "graph")
	if (
		not _get_bool(validation, "complete")
		or not _get_bool(analysis, "evaluation_complete")
	):
		_add_blocker(result, "analysis_incomplete", "", "分析输入或求值不完整；当前影响只能保持 unknown。")
		_add_blocker(result, "dependency_coverage_incomplete", "", "当前图未证明完整依赖覆盖。")
		result["status"] = "unknown"
		result["complete"] = false
		return result
	var analysis_index: Dictionary = _get_dictionary(validation, "index")
	var source_path: String = _get_string(normalized_change, "source_path")
	var source_node_id: String = _find_node_id(analysis_index, source_path)
	if source_node_id.is_empty():
		_add_blocker(result, "source_not_observed", source_path, "源路径不在冻结库存中。")
		return _finalize_result(result, analysis, graph, checkpoint)
	if source_path == ".":
		_add_blocker(result, "project_root_protected", source_path, "项目根目录不能作为结构变更目标。")
	var affected_node_ids: PackedStringArray = _collect_descendants(
		result,
		analysis_index,
		source_node_id,
		checkpoint
	)
	if _has_issue_kind(result, "impact_checkpoint_stopped"):
		return result
	result["affected_node_ids"] = Array(affected_node_ids)
	var evidence_ids: Array[String] = _collect_evidence_ids(
		result,
		analysis_index,
		affected_node_ids,
		checkpoint
	)
	if _has_issue_kind(result, "impact_checkpoint_stopped"):
		return result
	result["evidence_ids"] = evidence_ids
	var target_path: String = _get_string(normalized_change, "target_path")
	if (
		not target_path.is_empty()
		and (target_path == source_path or target_path.begins_with("%s/" % source_path))
	):
		_add_blocker(result, "target_inside_source", target_path, "移动或重命名目标不能位于源路径内部。")
	if not target_path.is_empty() and not _find_node_id(analysis_index, target_path).is_empty():
		_add_blocker(result, "target_already_exists", target_path, "目标路径已存在。")
	return _finalize_result(result, analysis, graph, checkpoint)


# --- 私有/辅助方法 ---

func _make_result(source_analysis_digest: String) -> Dictionary:
	return {
		"schema_version": 1,
		"kind": "project_layout_impact",
		"complete": false,
		"status": "unknown",
		"source_analysis_digest": source_analysis_digest,
		"change": {},
		"affected_node_ids": [],
		"blockers": [],
		"evidence_ids": [],
		"issues": [],
		"effects": { "writes_project": false },
	}


func _make_resource_limited_result() -> Dictionary:
	var result: Dictionary = _make_result("")
	_add_issue(
		result,
		"impact_resource_limit_exceeded",
		"Project Layout impact 输入超出不可关闭的资源边界。"
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
	result["complete"] = false
	result["status"] = "unknown"
	result["affected_node_ids"] = []
	result["blockers"] = []
	result["evidence_ids"] = []
	if not _has_issue_kind(result, "impact_checkpoint_stopped"):
		_add_issue(
			result,
			"impact_checkpoint_stopped",
			"Project Layout impact 已在协作式工作检查处停止。"
		)


func _change_is_intrinsically_admissible(change: Dictionary) -> bool:
	if change.size() > _MAX_CHANGE_FIELDS:
		return false
	for key_value: Variant in change.keys():
		if not key_value is String:
			return false
		var key: String = key_value
		if (
			key.length() > _MAX_CHANGE_KEY_LENGTH
			or not _CHANGE_FIELDS.has(key)
		):
			return false
		var field_value: Variant = change[key]
		if not field_value is String:
			return false
		var text: String = field_value
		var maximum_length: int = (
			_MAX_CHANGE_KIND_LENGTH if key == "kind" else _MAX_CHANGE_PATH_LENGTH
		)
		if text.length() > maximum_length:
			return false
	return true


func _normalize_change(change: Dictionary, result: Dictionary) -> Dictionary:
	for key_value: Variant in change.keys():
		if not key_value is String:
			_add_issue(result, "unsupported_change_field", "change 包含不受支持的字段。")
			continue
		var key: String = key_value
		if not _CHANGE_FIELDS.has(key):
			_add_issue(result, "unsupported_change_field", "change 包含不受支持的字段。")
	var change_kind: String = _get_string(change, "kind")
	if not _CHANGE_KINDS.has(change_kind):
		_add_issue(result, "unsupported_change_kind", "change.kind 必须是 delete、move 或 rename。")
	var source_path: String = _canonical_relative_path(_get_string(change, "source_path"))
	if source_path.is_empty():
		_add_issue(result, "invalid_source_path", "source_path 必须是规范项目相对路径。")
	var target_path: String = ""
	if change_kind == "move" or change_kind == "rename":
		target_path = _canonical_relative_path(_get_string(change, "target_path"))
		if target_path.is_empty() or target_path == ".":
			_add_issue(result, "invalid_target_path", "target_path 必须是非根规范项目相对路径。")
	return {
		"kind": change_kind,
		"source_path": source_path,
		"target_path": target_path,
	}


func _canonical_relative_path(path: String) -> String:
	if path == ".":
		return path
	if path.is_empty() or path != path.strip_edges() or path.contains("\\"):
		return ""
	if path.begins_with("/") or path.contains(":") or path.ends_with("/"):
		return ""
	var parts: PackedStringArray = path.split("/", true)
	for part: String in parts:
		if part.is_empty() or part == "." or part == "..":
			return ""
	return path


func _find_node_id(analysis_index: Dictionary, relative_path: String) -> String:
	var node_id_by_path: Dictionary = _get_dictionary(
		analysis_index,
		"node_id_by_path"
	)
	var node_id_value: Variant = node_id_by_path.get(relative_path)
	return node_id_value if node_id_value is String else ""


func _collect_descendants(
	impact: Dictionary,
	analysis_index: Dictionary,
	source_node_id: String,
	checkpoint: Callable
) -> PackedStringArray:
	var collected_ids: PackedStringArray = PackedStringArray([source_node_id])
	var visited: Dictionary = { source_node_id: true }
	var children_by_id: Dictionary = _get_dictionary(
		analysis_index,
		"children_by_id"
	)
	var cursor: int = 0
	while cursor < collected_ids.size():
		if not _checkpoint_allows(checkpoint):
			_stop_for_checkpoint(impact)
			return PackedStringArray()
		var parent_id: String = collected_ids[cursor]
		var child_values_value: Variant = children_by_id.get(parent_id)
		if child_values_value is Array:
			var child_values: Array = child_values_value
			for child_id_value: Variant in child_values:
				if not _checkpoint_allows(checkpoint):
					_stop_for_checkpoint(impact)
					return PackedStringArray()
				if not child_id_value is String:
					continue
				var child_id: String = child_id_value
				if visited.has(child_id):
					continue
				visited[child_id] = true
				var _append_child: bool = collected_ids.append(child_id)
		cursor += 1
	if not _checkpoint_allows(checkpoint, maxi(1, _sort_work_units(collected_ids.size()))):
		_stop_for_checkpoint(impact)
		return PackedStringArray()
	collected_ids.sort()
	if not _checkpoint_allows(checkpoint):
		_stop_for_checkpoint(impact)
		return PackedStringArray()
	return collected_ids


func _collect_evidence_ids(
	impact: Dictionary,
	analysis_index: Dictionary,
	affected_node_ids: PackedStringArray,
	checkpoint: Callable
) -> Array[String]:
	var collected_ids: Array[String] = []
	var seen_ids: Dictionary = {}
	var node_by_id: Dictionary = _get_dictionary(analysis_index, "node_by_id")
	for node_id: String in affected_node_ids:
		if not _checkpoint_allows(checkpoint):
			_stop_for_checkpoint(impact)
			return []
		var node_value: Variant = node_by_id.get(node_id)
		if not node_value is Dictionary:
			continue
		var node: Dictionary = node_value
		for evidence_id_value: Variant in _get_array(node, "evidence_ids"):
			if not _checkpoint_allows(checkpoint):
				_stop_for_checkpoint(impact)
				return []
			if not evidence_id_value is String:
				continue
			var evidence_id: String = evidence_id_value
			if seen_ids.has(evidence_id):
				continue
			seen_ids[evidence_id] = true
			collected_ids.append(evidence_id)
	if not _checkpoint_allows(checkpoint, maxi(1, _sort_work_units(collected_ids.size()))):
		_stop_for_checkpoint(impact)
		return []
	collected_ids.sort()
	if not _checkpoint_allows(checkpoint):
		_stop_for_checkpoint(impact)
		return []
	return collected_ids


func _finalize_result(
	result: Dictionary,
	analysis: Dictionary,
	graph: Dictionary,
	checkpoint: Callable
) -> Dictionary:
	var blockers: Array = _get_array(result, "blockers")
	var has_dependency_coverage_blocker: bool = false
	if not blockers.is_empty():
		var has_hard_blocker: bool = false
		for blocker_value: Variant in blockers:
			if not _checkpoint_allows(checkpoint):
				_stop_for_checkpoint(result)
				return result
			if blocker_value is Dictionary:
				var blocker: Dictionary = blocker_value
				var blocker_kind: String = _get_string(blocker, "kind")
				if blocker_kind == "dependency_coverage_incomplete":
					has_dependency_coverage_blocker = true
				else:
					has_hard_blocker = true
		result["status"] = "unsafe" if has_hard_blocker else "unknown"
	else:
		result["status"] = "unknown"
	if not has_dependency_coverage_blocker:
		_add_blocker(
			result,
			"dependency_coverage_incomplete",
			"",
			"当前图只证明文件系统库存，尚不能证明所有资源和运行时依赖已覆盖。"
		)
	if not _checkpoint_allows(checkpoint):
		_stop_for_checkpoint(result)
		return result
	result["complete"] = _get_bool(analysis, "input_complete") and _get_bool(graph, "complete")
	return result


func _sort_work_units(item_count: int) -> int:
	if item_count <= 1:
		return item_count
	var levels: int = 0
	var remaining: int = item_count
	while remaining > 1:
		levels += 1
		remaining = ceili(float(remaining) / 2.0)
	return item_count * levels


func _has_issue_kind(result: Dictionary, expected_kind: String) -> bool:
	for issue_value: Variant in _get_array(result, "issues"):
		if issue_value is Dictionary:
			var issue: Dictionary = issue_value
			if _get_string(issue, "kind") == expected_kind:
				return true
	return false


func _add_blocker(
	result: Dictionary,
	blocker_kind: String,
	path: String,
	message: String
) -> void:
	var blockers: Array = _get_array(result, "blockers")
	blockers.append({
		"kind": blocker_kind,
		"path": path,
		"message": message,
	})


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


func _get_int(source: Dictionary, key: String, default_value: int = 0) -> int:
	var value: Variant = source.get(key, default_value)
	return value if value is int else default_value


func _get_bool(source: Dictionary, key: String, default_value: bool = false) -> bool:
	var value: Variant = source.get(key, default_value)
	return value if value is bool else default_value


func _get_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	return value if value is Array else []


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return value if value is Dictionary else {}
