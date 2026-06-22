## GFInputContextDiagnostics: 输入上下文资源诊断工具。
##
## 只读取 GFInputContext / GFInputMapping / GFInputBinding 资源和可选重映射配置，
## 不参与运行时输入派发。适合编辑器页面、CI、项目设置界面或自定义工具复用同一套
## 结构校验与绑定冲突报告。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 5.2.0
class_name GFInputContextDiagnostics
extends RefCounted


# --- 公共方法 ---

## 构建单个输入上下文诊断报告。
## [br]
## @api public
## [br]
## @param context: 输入上下文。
## [br]
## @param remap_config: 可选重映射配置。
## [br]
## @param include_non_remappable: 是否包含不可重绑动作或绑定。
## [br]
## @param options: 可选诊断设置，支持 include_project_input_map_checks。
## [br]
## @return 标准诊断报告字典。
## [br]
## @schema options: Dictionary with optional `include_project_input_map_checks: bool`.
## [br]
## @schema return: Dictionary report payload with context, mapping, binding, conflict, item, and issue fields.
## [br]
## @since 5.2.0
static func build_context_report(
	context: GFInputContext,
	remap_config: GFInputRemapConfig = null,
	include_non_remappable: bool = true,
	options: Dictionary = {}
) -> Dictionary:
	return build_contexts_report([context], remap_config, false, include_non_remappable, options)


## 构建多个输入上下文诊断报告。
## [br]
## @api public
## [br]
## @param contexts: 输入上下文列表。
## [br]
## @param remap_config: 可选重映射配置。
## [br]
## @param include_cross_context: 是否报告跨上下文绑定冲突。
## [br]
## @param include_non_remappable: 是否包含不可重绑动作或绑定。
## [br]
## @param options: 可选诊断设置，支持 include_project_input_map_checks。
## [br]
## @return 标准诊断报告字典。
## [br]
## @schema contexts: Array[GFInputContext] of contexts to inspect.
## [br]
## @schema options: Dictionary with optional `include_project_input_map_checks: bool`.
## [br]
## @schema return: Dictionary report payload with context, mapping, binding, conflict, item, and issue fields.
## [br]
## @since 5.2.0
static func build_contexts_report(
	contexts: Array[GFInputContext],
	remap_config: GFInputRemapConfig = null,
	include_cross_context: bool = false,
	include_non_remappable: bool = true,
	options: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = GFInputConflictAnalyzer.build_rebind_report(
		contexts,
		remap_config,
		include_cross_context,
		include_non_remappable
	)
	var issues: Array[Dictionary] = []
	for context_index: int in range(contexts.size()):
		_collect_context_structure_issues(contexts[context_index], context_index, issues, options)
	for conflict_variant: Variant in GFVariantData.get_option_array(report, "conflicts"):
		if conflict_variant is Dictionary:
			var conflict: Dictionary = GFVariantData.as_dictionary(conflict_variant)
			issues.append(_make_conflict_issue(conflict))

	var stats: Dictionary = _count_context_resources(contexts)
	report["mapping_count"] = GFVariantData.get_option_int(stats, "mapping_count")
	report["binding_count"] = GFVariantData.get_option_int(stats, "binding_count")
	report["contexts"] = _collect_context_summaries(contexts)
	if contexts.size() == 1 and contexts[0] != null:
		var context: GFInputContext = contexts[0]
		report["context_id"] = context.get_context_id()
		report["context_name"] = context.get_display_name()
	report["issues"] = issues
	report["resource_summary"] = "上下文：%d  动作：%d  绑定：%d  冲突：%d  问题：%d" % [
		GFVariantData.get_option_int(report, "context_count"),
		GFVariantData.get_option_int(report, "mapping_count"),
		GFVariantData.get_option_int(report, "binding_count"),
		GFVariantData.get_option_int(report, "conflict_count"),
		issues.size(),
	]
	return GFValidationReportDictionary.finalize_report(report, "Input mapping", {
		"include_issue_count": true,
		"next_actions": get_next_actions(),
		"fallback_action": "检查输入映射诊断中的第一条问题。",
		"no_action": "当前输入上下文结构健康。",
	})


## 收集单个输入上下文的结构问题。
## [br]
## @api public
## [br]
## @param context: 输入上下文。
## [br]
## @param options: 可选诊断设置，支持 include_project_input_map_checks。
## [br]
## @return 结构问题列表。
## [br]
## @schema options: Dictionary with optional `include_project_input_map_checks: bool`.
## [br]
## @schema return: Array[Dictionary] of standardized validation issue payloads.
## [br]
## @since 5.2.0
static func collect_structure_issues(context: GFInputContext, options: Dictionary = {}) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	_collect_context_structure_issues(context, 0, issues, options)
	return issues


## 获取输入诊断问题的默认下一步建议。
## [br]
## @api public
## [br]
## @return 按问题 kind 索引的建议文本。
## [br]
## @schema return: Dictionary keyed by issue kind with action text.
## [br]
## @since 5.2.0
static func get_next_actions() -> Dictionary:
	return {
		"binding_conflict": "检查冲突输入绑定并决定是否保留、改键或拆分上下文。",
		"null_context": "移除空上下文或补齐 GFInputContext 资源。",
		"empty_context_id": "为输入上下文设置稳定 context_id。",
		"null_mapping": "移除空映射或补齐 GFInputMapping 资源。",
		"missing_action": "为映射补齐 GFInputAction。",
		"empty_action_id": "为动作设置稳定 action_id。",
		"duplicate_action_id": "合并重复 action_id 的映射，或为动作分配不同稳定标识。",
		"invalid_activation_threshold": "把动作 activation_threshold 调整到 0.0 到 1.0。",
		"empty_bindings": "按需补齐输入绑定，或确认该动作只由虚拟输入驱动。",
		"null_mapping_modifier": "移除空映射修饰器槽位或补齐 GFInputModifier。",
		"null_trigger": "移除空触发器槽位或补齐 GFInputTrigger。",
		"null_binding": "移除空绑定或补齐 GFInputBinding 资源。",
		"empty_input_event": "为绑定设置 InputEvent，或移除该空绑定。",
		"empty_input_event_action": "为 InputEventAction 设置 Godot InputMap action 名称，或改用具体 InputEvent。",
		"missing_project_input_action": "在 ProjectSettings/Input Map 中创建该 action，或改用具体 InputEvent。",
		"invalid_deadzone": "把绑定 deadzone 调整到 0.0 到 1.0。",
		"null_binding_modifier": "移除空绑定修饰器槽位或补齐 GFInputModifier。",
	}


# --- 私有/辅助方法 ---

static func _collect_context_structure_issues(
	context: GFInputContext,
	context_index: int,
	issues: Array[Dictionary],
	options: Dictionary
) -> void:
	if context == null:
		issues.append(_make_issue("error", "null_context", "contexts/%d" % context_index, "输入上下文为空。"))
		return
	if context.get_context_id() == &"":
		issues.append(_make_issue("warning", "empty_context_id", "contexts/%d" % context_index, "输入上下文缺少稳定 context_id。"))

	var action_paths_by_id: Dictionary = {}
	for mapping_index: int in range(context.mappings.size()):
		var mapping: GFInputMapping = context.mappings[mapping_index]
		var mapping_path: String = _make_mapping_path(context_index, mapping_index)
		if mapping == null:
			issues.append(_make_issue("error", "null_mapping", mapping_path, "映射为空。"))
			continue
		_collect_mapping_issues(mapping, mapping_path, action_paths_by_id, issues, options)


static func _collect_mapping_issues(
	mapping: GFInputMapping,
	mapping_path: String,
	action_paths_by_id: Dictionary,
	issues: Array[Dictionary],
	options: Dictionary
) -> void:
	if mapping.action == null:
		issues.append(_make_issue("error", "missing_action", mapping_path, "映射缺少 GFInputAction。"))
	elif mapping.get_action_id() == &"":
		issues.append(_make_issue("warning", "empty_action_id", mapping_path, "动作缺少稳定 action_id。"))
	else:
		_collect_action_id_issue(mapping, mapping_path, action_paths_by_id, issues)
		_collect_action_threshold_issue(mapping, mapping_path, issues)

	if mapping.bindings.is_empty():
		issues.append(_make_issue("warning", "empty_bindings", mapping_path, "动作没有任何输入绑定。"))

	_collect_null_slots(mapping.modifiers, "%s/modifiers" % mapping_path, "null_mapping_modifier", "映射修饰器为空。", issues)
	_collect_null_slots(mapping.triggers, "%s/triggers" % mapping_path, "null_trigger", "触发器为空。", issues)
	for binding_index: int in range(mapping.bindings.size()):
		var binding: GFInputBinding = mapping.bindings[binding_index]
		var binding_path: String = "%s/bindings/%d" % [mapping_path, binding_index]
		_collect_binding_issues(binding, binding_path, issues, options)


static func _collect_action_id_issue(
	mapping: GFInputMapping,
	mapping_path: String,
	action_paths_by_id: Dictionary,
	issues: Array[Dictionary]
) -> void:
	var action_id: String = String(mapping.get_action_id())
	if action_paths_by_id.has(action_id):
		issues.append(_make_issue(
			"warning",
			"duplicate_action_id",
			mapping_path,
			"动作 action_id 重复：%s。" % action_id,
			{
				"action_id": action_id,
				"first_path": GFVariantData.get_option_string(action_paths_by_id, action_id),
			}
		))
	else:
		action_paths_by_id[action_id] = mapping_path


static func _collect_action_threshold_issue(mapping: GFInputMapping, mapping_path: String, issues: Array[Dictionary]) -> void:
	if mapping.action == null:
		return
	var threshold: float = mapping.action.activation_threshold
	if threshold < 0.0 or threshold > 1.0:
		issues.append(_make_issue(
			"warning",
			"invalid_activation_threshold",
			"%s/action" % mapping_path,
			"动作 activation_threshold 超出 0.0 到 1.0：%.3f。" % threshold,
			{ "value": threshold }
		))


static func _collect_binding_issues(
	binding: GFInputBinding,
	binding_path: String,
	issues: Array[Dictionary],
	options: Dictionary
) -> void:
	if binding == null:
		issues.append(_make_issue("error", "null_binding", binding_path, "绑定为空。"))
		return
	if binding.input_event == null:
		issues.append(_make_issue("warning", "empty_input_event", binding_path, "绑定没有输入事件。"))
	else:
		_collect_input_event_action_issue(binding.input_event, binding_path, issues, options)
	if binding.deadzone < 0.0 or binding.deadzone > 1.0:
		issues.append(_make_issue(
			"warning",
			"invalid_deadzone",
			binding_path,
			"绑定 deadzone 超出 0.0 到 1.0：%.3f。" % binding.deadzone,
			{ "value": binding.deadzone }
		))
	_collect_null_slots(binding.modifiers, "%s/modifiers" % binding_path, "null_binding_modifier", "绑定修饰器为空。", issues)


static func _collect_input_event_action_issue(
	input_event: InputEvent,
	binding_path: String,
	issues: Array[Dictionary],
	options: Dictionary
) -> void:
	if not GFVariantData.get_option_bool(options, "include_project_input_map_checks", true):
		return
	if not (input_event is InputEventAction):
		return

	var action_event: InputEventAction = input_event
	var action_name: StringName = action_event.action
	if action_name == &"":
		issues.append(_make_issue("warning", "empty_input_event_action", binding_path, "InputEventAction 缺少 action 名称。"))
	elif not InputMap.has_action(action_name):
		issues.append(_make_issue(
			"warning",
			"missing_project_input_action",
			binding_path,
			"ProjectSettings/Input Map 中不存在 action：%s。" % String(action_name),
			{ "action": String(action_name) }
		))


static func _collect_null_slots(
	values: Array,
	path: String,
	kind: String,
	message: String,
	issues: Array[Dictionary]
) -> void:
	for index: int in range(values.size()):
		if values[index] == null:
			issues.append(_make_issue("warning", kind, "%s/%d" % [path, index], message))


static func _make_conflict_issue(conflict: Dictionary) -> Dictionary:
	return _make_issue(
		"warning",
		"binding_conflict",
		"%s/%s" % [
			GFVariantData.get_option_string(conflict, "context_id", ""),
			GFVariantData.get_option_string(conflict, "action_id", ""),
		],
		"输入绑定冲突：%s" % GFVariantData.get_option_string(conflict, "event_text", ""),
		{ "conflict": _sanitize_for_report(conflict) }
	)


static func _count_context_resources(contexts: Array[GFInputContext]) -> Dictionary:
	var mapping_count: int = 0
	var binding_count: int = 0
	for context: GFInputContext in contexts:
		if context == null:
			continue
		mapping_count += context.mappings.size()
		for mapping: GFInputMapping in context.mappings:
			if mapping != null:
				binding_count += mapping.bindings.size()
	return {
		"mapping_count": mapping_count,
		"binding_count": binding_count,
	}


static func _collect_context_summaries(contexts: Array[GFInputContext]) -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for context_index: int in range(contexts.size()):
		var context: GFInputContext = contexts[context_index]
		if context == null:
			summaries.append({
				"index": context_index,
				"valid": false,
			})
			continue
		summaries.append({
			"index": context_index,
			"valid": true,
			"context_id": context.get_context_id(),
			"display_name": context.get_display_name(),
			"resource_path": context.resource_path,
			"mapping_count": context.mappings.size(),
			"binding_count": _count_context_bindings(context),
		})
	return summaries


static func _count_context_bindings(context: GFInputContext) -> int:
	var count: int = 0
	for mapping: GFInputMapping in context.mappings:
		if mapping != null:
			count += mapping.bindings.size()
	return count


static func _make_mapping_path(context_index: int, mapping_index: int) -> String:
	return "contexts/%d/mappings/%d" % [context_index, mapping_index]


static func _make_issue(
	severity: String,
	kind: String,
	path: String,
	message: String,
	metadata: Dictionary = {}
) -> Dictionary:
	var issue: Dictionary = {
		"severity": severity,
		"kind": kind,
		"path": path,
		"message": message,
	}
	if not metadata.is_empty():
		issue["metadata"] = metadata.duplicate(true)
	return issue


static func _sanitize_for_report(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary: Dictionary = GFVariantData.as_dictionary(value)
		var result: Dictionary = {}
		for key: Variant in dictionary.keys():
			result[str(key)] = _sanitize_for_report(dictionary[key])
		return result
	if value is Array:
		var array: Array = GFVariantData.as_array(value)
		var array_result: Array = []
		for item: Variant in array:
			array_result.append(_sanitize_for_report(item))
		return array_result
	if value is InputEvent:
		var event: InputEvent = value
		return GFInputFormatter.input_event_as_text(event)
	if value is Object:
		return str(value)
	return value
