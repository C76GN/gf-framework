## GFInputConflictAnalyzer: 输入上下文冲突分析工具。
##
## 只读取输入资源与可选重映射配置，不参与运行时输入分发。适合设置界面、
## 编辑器工具或测试在应用重绑定前检查同一输入是否被多个抽象动作占用。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFInputConflictAnalyzer
extends RefCounted


# --- 常量 ---

const _INPUT_EVENT_TOOLS = preload("res://addons/gf/standard/input/common/gf_input_event_tools.gd")
const _INPUT_EVENT_IDENTITY = preload("res://addons/gf/standard/input/common/gf_input_event_identity.gd")


# --- 公共方法 ---

## 分析单个上下文内的绑定冲突。
## [br]
## @api public
## [br]
## @param context: 输入上下文。
## [br]
## @param remap_config: 可选重映射配置。
## [br]
## @param include_non_remappable: 是否包含不可重绑动作或绑定。
## [br]
## @schema return: Array，包含冲突 Dictionary 记录，字段包括 context/action/binding id、other_* id、event_text、signature 和 items。
## [br]
## @return 冲突列表。
static func analyze_context(
	context: GFInputContext,
	remap_config: GFInputRemapConfig = null,
	include_non_remappable: bool = true
) -> Array[Dictionary]:
	if context == null:
		return []
	return analyze_contexts([context], remap_config, false, include_non_remappable)


## 分析多个上下文的绑定冲突。
## [br]
## @api public
## [br]
## @param contexts: 输入上下文列表。
## [br]
## @param remap_config: 可选重映射配置。
## [br]
## @param include_cross_context: 是否报告跨上下文冲突。
## [br]
## @param include_non_remappable: 是否包含不可重绑动作或绑定。
## [br]
## @schema contexts: Array[GFInputContext] of contexts to analyze.
## [br]
## @schema return: Array，包含冲突 Dictionary 记录，字段包括 context/action/binding id、other_* id、event_text、signature 和 items。
## [br]
## @return 冲突列表。
static func analyze_contexts(
	contexts: Array[GFInputContext],
	remap_config: GFInputRemapConfig = null,
	include_cross_context: bool = false,
	include_non_remappable: bool = true
) -> Array[Dictionary]:
	var items: Array[Dictionary] = collect_binding_items(contexts, remap_config, include_non_remappable)
	return _analyze_items(items, include_cross_context)


## 构建重绑定诊断报告。
## [br]
## @api public
## [br]
## @param contexts: 输入上下文列表。
## [br]
## @param remap_config: 可选重映射配置。
## [br]
## @param include_cross_context: 是否报告跨上下文冲突。
## [br]
## @param include_non_remappable: 是否包含不可重绑动作或绑定。
## [br]
## @schema contexts: Array[GFInputContext] of contexts to analyze.
## [br]
## @schema return: Dictionary，包含 ok、context_count、item_count、conflict_count、items 和 conflicts。
## [br]
## @return 包含条目与冲突的报告。
static func build_rebind_report(
	contexts: Array[GFInputContext],
	remap_config: GFInputRemapConfig = null,
	include_cross_context: bool = false,
	include_non_remappable: bool = true
) -> Dictionary:
	var items: Array[Dictionary] = collect_binding_items(contexts, remap_config, include_non_remappable)
	var conflicts: Array[Dictionary] = _analyze_items(items, include_cross_context)
	return {
		"ok": conflicts.is_empty(),
		"context_count": _count_contexts(contexts),
		"item_count": items.size(),
		"conflict_count": conflicts.size(),
		"items": items,
		"conflicts": conflicts,
	}


## 收集上下文中的有效绑定条目。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param contexts: 输入上下文列表。
## [br]
## @param remap_config: 可选重映射配置。
## [br]
## @param include_non_remappable: 是否包含不可重绑动作或绑定。
## [br]
## @schema contexts: Array[GFInputContext] of contexts to inspect.
## [br]
## @schema return: Array，包含 item Dictionary 记录，字段包括 context/action/binding id、event_record、event_text、event_key、signature、device_scope 和 match_device。
## [br]
## @return 绑定条目列表。
static func collect_binding_items(
	contexts: Array[GFInputContext],
	remap_config: GFInputRemapConfig = null,
	include_non_remappable: bool = true
) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for context: GFInputContext in contexts:
		if context == null:
			continue
		_collect_context_binding_items(context, remap_config, include_non_remappable, items)
	return items


## 获取输入事件的稳定签名。
## [br]
## @api public
## [br]
## @param input_event: 输入事件。
## [br]
## @param match_device: 是否把设备 ID 纳入签名。
## [br]
## @return 签名字符串；空事件返回空字符串。
static func get_event_signature(input_event: InputEvent, match_device: bool = false) -> String:
	var event_key: String = _get_event_key(input_event)
	if event_key.is_empty():
		return ""
	var device_scope: String = _get_device_scope(input_event, match_device)
	return "%s@%s" % [event_key, device_scope]


## 判断两个输入事件是否会在绑定层互相冲突。
## [br]
## @api public
## [br]
## @param left_event: 左侧输入事件。
## [br]
## @param right_event: 右侧输入事件。
## [br]
## @param left_match_device: 左侧是否要求设备精确匹配。
## [br]
## @param right_match_device: 右侧是否要求设备精确匹配。
## [br]
## @return 冲突返回 true。
static func are_events_equivalent(
	left_event: InputEvent,
	right_event: InputEvent,
	left_match_device: bool = false,
	right_match_device: bool = false
) -> bool:
	var left_key: String = _get_event_key(left_event)
	var right_key: String = _get_event_key(right_event)
	if left_key.is_empty() or not _event_keys_conflict(left_key, right_key):
		return false

	var left_device: String = _get_device_scope(left_event, left_match_device)
	var right_device: String = _get_device_scope(right_event, right_match_device)
	return left_device == "*" or right_device == "*" or left_device == right_device


# --- 私有/辅助方法 ---

static func _collect_context_binding_items(
	context: GFInputContext,
	remap_config: GFInputRemapConfig,
	include_non_remappable: bool,
	items: Array[Dictionary]
) -> void:
	var context_id: StringName = context.get_context_id()
	for mapping: GFInputMapping in context.mappings:
		if mapping == null:
			continue
		if not include_non_remappable and mapping.action != null and not mapping.action.remappable:
			continue

		var action_id: StringName = mapping.get_action_id()
		for binding_index: int in range(mapping.bindings.size()):
			var binding: GFInputBinding = mapping.bindings[binding_index]
			if binding == null:
				continue
			if not include_non_remappable and not binding.remappable:
				continue

			var event: InputEvent = binding.input_event
			if remap_config != null and remap_config.has_binding(context_id, action_id, binding_index):
				event = remap_config.get_bound_event_or_null(context_id, action_id, binding_index)
			if event == null:
				continue

			var event_key: String = _get_binding_event_key(event, binding)
			if event_key.is_empty():
				continue

			items.append({
				"context_id": String(context_id),
				"context_name": context.get_display_name(),
				"action_id": String(action_id),
				"action_name": mapping.get_display_name(),
				"binding_index": binding_index,
				"event_record": _INPUT_EVENT_TOOLS.input_event_to_record(event),
				"event_text": GFInputFormatter.input_event_as_text(event),
				"event_key": event_key,
				"signature": "%s@%s" % [event_key, _get_device_scope(event, binding.match_device)],
				"device_scope": _get_device_scope(event, binding.match_device),
				"match_device": binding.match_device,
			})


static func _analyze_items(items: Array[Dictionary], include_cross_context: bool) -> Array[Dictionary]:
	var conflicts: Array[Dictionary] = []
	var buckets: Dictionary = {}
	var bucket_order: PackedStringArray = PackedStringArray()
	for item: Dictionary in items:
		var bucket_key: String = _make_item_bucket_key(item, include_cross_context)
		if bucket_key.is_empty():
			continue
		if not buckets.has(bucket_key):
			buckets[bucket_key] = []
			var _append_bucket_result: bool = bucket_order.append(bucket_key)
		var bucket_value: Variant = buckets[bucket_key]
		if bucket_value is Array:
			var bucket_items: Array = bucket_value
			bucket_items.append(item)

	for bucket_key: String in bucket_order:
		var bucket_items: Array = GFVariantData.get_option_array(buckets, bucket_key)
		for left_index: int in range(bucket_items.size()):
			var left: Dictionary = GFVariantData.as_dictionary(bucket_items[left_index])
			for right_index: int in range(left_index + 1, bucket_items.size()):
				var right: Dictionary = GFVariantData.as_dictionary(bucket_items[right_index])
				if not _items_conflict(left, right):
					continue
				conflicts.append(_make_conflict(left, right))
	return conflicts


static func _count_contexts(contexts: Array[GFInputContext]) -> int:
	var count: int = 0
	for context: GFInputContext in contexts:
		if context != null:
			count += 1
	return count


static func _items_conflict(left: Dictionary, right: Dictionary) -> bool:
	if not _event_keys_conflict(_get_item_event_key(left), _get_item_event_key(right)):
		return false

	var left_device: String = _get_item_device_scope(left)
	var right_device: String = _get_item_device_scope(right)
	return left_device == "*" or right_device == "*" or left_device == right_device


static func _make_conflict(left: Dictionary, right: Dictionary) -> Dictionary:
	return {
		"context_id": String(_get_item_context_id(left)),
		"action_id": String(_get_item_action_id(left)),
		"binding_index": _get_item_binding_index(left),
		"other_context_id": String(_get_item_context_id(right)),
		"other_action_id": String(_get_item_action_id(right)),
		"other_binding_index": _get_item_binding_index(right),
		"event_text": _get_item_event_text(left),
		"signature": _get_item_signature(left),
		"items": [left, right],
	}


static func _get_item_context_id(item: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(item, "context_id")


static func _get_item_action_id(item: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(item, "action_id")


static func _get_item_binding_index(item: Dictionary) -> int:
	return GFVariantData.get_option_int(item, "binding_index")


static func _get_item_event_key(item: Dictionary) -> String:
	return GFVariantData.get_option_string(item, "event_key")


static func _get_item_device_scope(item: Dictionary) -> String:
	return GFVariantData.get_option_string(item, "device_scope", "*")


static func _get_item_event_text(item: Dictionary) -> String:
	return GFVariantData.get_option_string(item, "event_text")


static func _get_item_signature(item: Dictionary) -> String:
	return GFVariantData.get_option_string(item, "signature")


static func _get_event_key(input_event: InputEvent) -> String:
	var identity: GFInputEventIdentity = _INPUT_EVENT_IDENTITY.from_event(input_event)
	return identity.conflict_key


static func _get_binding_event_key(input_event: InputEvent, binding: GFInputBinding) -> String:
	if input_event is InputEventJoypadMotion:
		var identity: GFInputEventIdentity = _INPUT_EVENT_IDENTITY.from_event(input_event, {
			&"joy_axis_sign": _get_joy_axis_sign_for_binding(binding),
		})
		return identity.conflict_key
	return _get_event_key(input_event)


static func _get_joy_axis_sign_for_binding(binding: GFInputBinding) -> int:
	var direction: String = _get_joy_axis_direction_for_binding(binding)
	if direction == "+":
		return 1
	if direction == "-":
		return -1
	return 0


static func _get_joy_axis_direction_for_binding(binding: GFInputBinding) -> String:
	if binding == null:
		return "*"
	var target: GFInputBinding.ValueTarget = binding.value_target
	if (
		target == GFInputBinding.ValueTarget.AXIS_1D_POSITIVE
		or target == GFInputBinding.ValueTarget.AXIS_2D_X_POSITIVE
		or target == GFInputBinding.ValueTarget.AXIS_2D_Y_POSITIVE
		or target == GFInputBinding.ValueTarget.AXIS_3D_X_POSITIVE
		or target == GFInputBinding.ValueTarget.AXIS_3D_Y_POSITIVE
		or target == GFInputBinding.ValueTarget.AXIS_3D_Z_POSITIVE
	):
		return "+"
	if (
		target == GFInputBinding.ValueTarget.AXIS_1D_NEGATIVE
		or target == GFInputBinding.ValueTarget.AXIS_2D_X_NEGATIVE
		or target == GFInputBinding.ValueTarget.AXIS_2D_Y_NEGATIVE
		or target == GFInputBinding.ValueTarget.AXIS_3D_X_NEGATIVE
		or target == GFInputBinding.ValueTarget.AXIS_3D_Y_NEGATIVE
		or target == GFInputBinding.ValueTarget.AXIS_3D_Z_NEGATIVE
	):
		return "-"
	return "*"


static func _event_keys_conflict(left_key: String, right_key: String) -> bool:
	if left_key == right_key:
		return true
	if not left_key.begins_with("joy_axis:") or not right_key.begins_with("joy_axis:"):
		return false
	var left_parts: PackedStringArray = left_key.split(":")
	var right_parts: PackedStringArray = right_key.split(":")
	if left_parts.size() != 3 or right_parts.size() != 3:
		return false
	if left_parts[1] != right_parts[1]:
		return false
	return left_parts[2] == "*" or right_parts[2] == "*"


static func _make_item_bucket_key(item: Dictionary, include_cross_context: bool) -> String:
	var event_key: String = _get_item_event_key(item)
	if event_key.is_empty():
		return ""
	var bucket_key: String = _make_event_bucket_key(event_key)
	if not include_cross_context:
		bucket_key = "%s@%s" % [_get_item_context_id(item), bucket_key]
	return bucket_key


static func _make_event_bucket_key(event_key: String) -> String:
	if not event_key.begins_with("joy_axis:"):
		return event_key
	var parts: PackedStringArray = event_key.split(":")
	if parts.size() < 2:
		return event_key
	return "joy_axis:%s" % parts[1]


static func _get_device_scope(input_event: InputEvent, match_device: bool) -> String:
	if input_event == null or not match_device:
		return "*"
	return str(input_event.device)
