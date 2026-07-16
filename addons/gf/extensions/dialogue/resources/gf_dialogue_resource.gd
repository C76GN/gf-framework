## GFDialogueResource: 通用对话资源。
##
## 资源只保存对话行集合、起始行和自定义元数据。导入格式、剧本 DSL、
## 本地化表和编辑器 UI 均由项目或独立插件决定。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFDialogueResource
extends Resource


# --- 常量 ---

const _GF_VALIDATION_REPORT_DICTIONARY_SCRIPT = preload("res://addons/gf/standard/foundation/validation/gf_validation_report_dictionary.gd")
const _SNAPSHOT_COPY = preload("res://addons/gf/extensions/dialogue/resources/gf_dialogue_snapshot_copy.gd")


# --- 导出变量 ---

## 默认起始行 ID。
## [br]
## @api public
@export var start_line_id: StringName = &""

## 对话行集合。
## [br]
## @api public
@export var lines: Array[GFDialogueLine] = []

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: 项目自定义元数据 Dictionary；框架保留并复制该字段，但不解释其中键值。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 设置或追加对话行。
## [br]
## @api public
## [br]
## @param line: 对话行。
func set_line(line: GFDialogueLine) -> void:
	if line == null or line.line_id == &"":
		return
	for index: int in range(lines.size()):
		if lines[index] != null and lines[index].line_id == line.line_id:
			lines[index] = line
			emit_changed()
			return
	lines.append(line)
	emit_changed()


## 获取对话行。
## [br]
## @api public
## [br]
## @param line_id: 行 ID。
## [br]
## @return: 对话行；不存在时返回 null。
func get_line(line_id: StringName) -> GFDialogueLine:
	for line: GFDialogueLine in lines:
		if line != null and line.line_id == line_id:
			return line
	return null


## 获取起始行。
## [br]
## @api public
## [br]
## @param override_line_id: 可选覆盖起点。
## [br]
## @return: 起始行；不存在时返回 null。
func get_start_line(override_line_id: StringName = &"") -> GFDialogueLine:
	var resolved_id: StringName = override_line_id if override_line_id != &"" else start_line_id
	if resolved_id != &"":
		return get_line(resolved_id)
	for line: GFDialogueLine in lines:
		if line != null:
			return line
	return null


## 获取全部行 ID。
## [br]
## @api public
## [br]
## @return: 行 ID 列表。
func get_line_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for line: GFDialogueLine in lines:
		if line != null and line.line_id != &"":
			var _append_result_99: Variant = result.append(String(line.line_id))
	return result


## 校验资源结构。
## [br]
## @api public
## [br]
## @return: 兼容 GFValidationReportDictionary 的报告字典。
## [br]
## @schema return: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，包含 ok、healthy、summary、issues、next_action、error_count、warning_count 和 issue_count 等字段。
func validate_resource() -> Dictionary:
	var report: Dictionary = {
		"subject": "Dialogue resource",
		"issues": [],
	}
	if start_line_id != &"" and get_line(start_line_id) == null:
		_append_issue(
			report,
			&"missing_start_line",
			String(start_line_id),
			"Dialogue start_line_id does not reference an existing line."
		)

	var seen: Dictionary = {}
	for index: int in range(lines.size()):
		var line: GFDialogueLine = lines[index]
		if line == null:
			_append_issue(report, &"null_line", "lines[%d]" % index, "Dialogue line is null.")
			continue
		if line.line_id == &"":
			_append_issue(report, &"empty_line_id", "lines[%d]" % index, "Dialogue line_id is empty.")
			continue
		if seen.has(line.line_id):
			_append_issue(report, &"duplicate_line_id", String(line.line_id), "Dialogue line_id is duplicated.")
		seen[line.line_id] = true

		var next_ids: PackedStringArray = PackedStringArray()
		if line.next_line_id != &"":
			var _append_result_138: Variant = next_ids.append(String(line.next_line_id))
		if line.jump_line_id != &"":
			var _append_result_140: Variant = next_ids.append(String(line.jump_line_id))
		if line.fallback_line_id != &"":
			var _append_result_142: Variant = next_ids.append(String(line.fallback_line_id))
		var seen_response_ids: Dictionary = {}
		for response_index: int in range(line.responses.size()):
			var response: GFDialogueResponse = line.responses[response_index]
			if response == null:
				_append_issue(
					report,
					&"null_response",
					"%s.responses[%d]" % [line.line_id, response_index],
					"Dialogue response is null."
				)
				continue
			if response.response_id == &"":
				_append_issue(
					report,
					&"empty_response_id",
					"%s.responses[%d]" % [line.line_id, response_index],
					"Dialogue response_id is empty."
				)
			elif seen_response_ids.has(response.response_id):
				_append_issue(
					report,
					&"duplicate_response_id",
					"%s.responses.%s" % [line.line_id, response.response_id],
					"Dialogue response_id is duplicated within the line."
				)
			seen_response_ids[response.response_id] = true
			if response.next_line_id != &"":
				var _append_result_167: Variant = next_ids.append(String(response.next_line_id))
		for next_id: String in next_ids:
			if get_line(StringName(next_id)) == null:
				_append_issue(
					report,
					&"missing_next_line",
					"%s -> %s" % [line.line_id, next_id],
					"Dialogue transition references a missing line."
				)

	_validate_automatic_cycles(report)

	return _GF_VALIDATION_REPORT_DICTIONARY_SCRIPT.finalize_report(report, "Dialogue resource", {
		"include_issue_count": true,
		"next_actions": _get_validation_next_actions(),
	})


## 创建深拷贝。
## [br]
## @api public
## [br]
## @return: 对话资源副本。
func duplicate_dialogue() -> GFDialogueResource:
	var resource: GFDialogueResource = _get_dialogue_resource_value(duplicate(true))
	return resource if resource != null else GFDialogueResource.new()


## 转换为字典。
## [br]
## @api public
## [br]
## @return: 资源快照。
## [br]
## @schema return: 包含 start_line_id、lines 和 metadata 字段的 Dictionary；lines 为行快照字典数组。
func to_dictionary() -> Dictionary:
	return _SNAPSHOT_COPY.copy_snapshot_dictionary(create_serialization_source())


## 创建对话序列化操作的原始结构。
##
## 返回值只供共享预算复制器立即消费；调用方不得将其视为隔离快照。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @return: 包含资源及全部行身份字段的原始结构。
## [br]
## @schema return: 包含 start_line_id、lines 和 metadata 字段的 Dictionary；null 行槽位会被保留。
func create_serialization_source() -> Dictionary:
	var line_data: Array = []
	for line: GFDialogueLine in lines:
		if line != null:
			line_data.append(line.create_serialization_source())
		else:
			line_data.append(null)
	return {
		"start_line_id": start_line_id,
		"lines": line_data,
		"metadata": metadata,
	}


## 创建完整且稳定的资源身份输入报告。
##
## 循环引用、对象值或任一操作级预算超限都会失败，不会返回截断身份。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param options: 可选身份复制预算。
## [br]
## @schema options: 可包含 max_depth、max_nodes、max_bytes 和 max_packed_length 正整数。
## [br]
## @return: 完整副本报告。
## [br]
## @schema return: 包含 ok、value、error、path、node_count、byte_count 和 packed_length 字段的 Dictionary。
func build_identity_report(options: Dictionary = {}) -> Dictionary:
	return _SNAPSHOT_COPY.copy_complete_report(create_serialization_source(), options)


# --- 私有/辅助方法 ---

func _append_issue(
	report: Dictionary,
	kind: StringName,
	subject: String,
	message: String
) -> void:
	var _append_issue_result_198: Variant = _GF_VALIDATION_REPORT_DICTIONARY_SCRIPT.append_issue(report, "error", kind, message, {
		"subject": subject,
		"path": subject,
	})


func _get_validation_next_actions() -> Dictionary:
	return {
		"missing_start_line": "Create the configured start line or clear start_line_id to use the first available line.",
		"null_line": "Remove empty dialogue line slots or assign a GFDialogueLine resource.",
		"empty_line_id": "Assign every dialogue line a stable line_id.",
		"duplicate_line_id": "Make every dialogue line_id unique.",
		"null_response": "Remove empty dialogue response slots or assign a GFDialogueResponse resource.",
		"empty_response_id": "Assign every response on a line a stable non-empty response_id.",
		"duplicate_response_id": "Make response_id values unique within each dialogue line.",
		"missing_next_line": "Create the referenced dialogue line or update the transition id.",
		"automatic_cycle": "Break the automatic JUMP/MUTATION chain with a TEXT/END line or a conditional fallback.",
	}


func _validate_automatic_cycles(report: Dictionary) -> void:
	var reported_cycles: Dictionary = {}
	for line: GFDialogueLine in lines:
		if not _is_automatic_line(line):
			continue
		_validate_automatic_chain(line.line_id, reported_cycles, report)


func _validate_automatic_chain(
	start_id: StringName,
	reported_cycles: Dictionary,
	report: Dictionary
) -> void:
	var visited: Dictionary = {}
	var current_id: StringName = start_id
	while current_id != &"":
		var line: GFDialogueLine = get_line(current_id)
		if not _is_automatic_line(line):
			return
		if line.condition_id != &"" or line.fallback_line_id != &"":
			return
		if visited.has(current_id):
			if reported_cycles.has(current_id):
				return
			reported_cycles[current_id] = true
			_append_issue(
				report,
				&"automatic_cycle",
				String(current_id),
				"Dialogue automatic JUMP/MUTATION chain contains a cycle."
			)
			return
		visited[current_id] = true
		current_id = line.get_default_next_line_id()


func _is_automatic_line(line: GFDialogueLine) -> bool:
	return (
		line != null
		and (
			line.kind == GFDialogueLine.LineKind.JUMP
			or line.kind == GFDialogueLine.LineKind.MUTATION
		)
	)


func _get_dialogue_resource_value(value: Variant) -> GFDialogueResource:
	if value is GFDialogueResource:
		var resource: GFDialogueResource = value
		return resource
	return null
