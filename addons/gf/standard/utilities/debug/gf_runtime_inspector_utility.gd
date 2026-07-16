## GFRuntimeInspectorUtility: 显式 schema 驱动的运行时调参注册表。
##
## 项目主动注册可调对象和属性后，工具提供快照、读取和受控写入能力。
## 它不自动暴露业务对象，也不内置具体 UI 或玩法语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFRuntimeInspectorUtility
extends GFUtility


# --- 信号 ---

## 目标注册后发出。
## [br]
## @api public
## [br]
## @param target_id: 目标 ID。
signal target_registered(target_id: StringName)

## 目标注销后发出。
## [br]
## @api public
## [br]
## @param target_id: 目标 ID。
signal target_unregistered(target_id: StringName)

## 属性成功写入后发出。
## [br]
## @api public
## [br]
## @param target_id: 目标 ID。
## [br]
## @param property_id: 属性 ID。
## [br]
## @param old_value: 写入前的值。
## [br]
## @param new_value: 写入后的值。
## [br]
## @schema old_value: Variant，写入前的属性值。
## [br]
## @schema new_value: Variant，写入后的属性值。
signal property_changed(target_id: StringName, property_id: StringName, old_value: Variant, new_value: Variant)


# --- 公共变量 ---

## 是否允许通过本工具写入值。
## [br]
## @api public
var allow_writes: bool = true

## 为 true 时，非 debug 构建禁止写入。
## [br]
## @api public
var debug_build_writes_only: bool = true


# --- 私有变量 ---

var _targets: Dictionary = {}
var _target_order_counter: int = 0
var _attached_overlay_panel_id: StringName = &""


# --- GF 生命周期方法 ---

## 释放 Inspector 注册状态并解除 Overlay 面板。
## [br]
## @api public
func dispose() -> void:
	detach_from_debug_overlay()
	clear_targets()


# --- 公共方法 ---

## 注册一个运行时可检查目标。
## [br]
## @api public
## [br]
## @param target_id: 目标 ID。
## [br]
## @param target: 目标对象。
## [br]
## @param properties: 可调属性列表。
## [br]
## @param options: 可选显示参数，支持 label、group、visible。
## [br]
## @return 注册成功返回 true。
## [br]
## @schema properties: Array[GFRuntimeTunableProperty]，目标允许检查或写入的属性声明列表。
## [br]
## @schema options: Dictionary，支持 label、group 和 visible。
func register_target(
	target_id: StringName,
	target: Object,
	properties: Array[GFRuntimeTunableProperty] = [],
	options: Dictionary = {}
) -> bool:
	if target_id == &"" or not is_instance_valid(target):
		return false

	var entry: Dictionary = {
		"target_ref": weakref(target),
		"label": GFVariantData.get_option_string(options, "label", String(target_id)),
		"group": GFVariantData.get_option_string(options, "group", "Runtime"),
		"visible": GFVariantData.get_option_bool(options, "visible", true),
		"order": _target_order_counter,
		"properties": [],
		"properties_by_id": {},
	}
	if _targets.has(target_id):
		var old_entry: Dictionary = _get_entry(target_id)
		entry["order"] = GFVariantData.get_option_int(old_entry, "order", _target_order_counter)
	else:
		_target_order_counter += 1

	_targets[target_id] = entry
	for property: GFRuntimeTunableProperty in properties:
		var _registered: bool = register_property(target_id, property)
	target_registered.emit(target_id)
	_refresh_attached_overlay_panel()
	return true


## 注销运行时目标。
## [br]
## @api public
## [br]
## @param target_id: 目标 ID。
## [br]
## @return 找到并移除时返回 true。
func unregister_target(target_id: StringName) -> bool:
	if not _targets.has(target_id):
		return false
	_erase_dictionary_key(_targets, target_id)
	target_unregistered.emit(target_id)
	_refresh_attached_overlay_panel()
	return true


## 检查目标是否存在且仍有效。
## [br]
## @api public
## [br]
## @param target_id: 目标 ID。
## [br]
## @return 目标存在且对象有效时返回 true。
func has_target(target_id: StringName) -> bool:
	if _resolve_target(target_id) != null:
		return true
	if _targets.has(target_id):
		_erase_dictionary_key(_targets, target_id)
	return false


## 为目标注册或替换一个可调属性。
## [br]
## @api public
## [br]
## @param target_id: 目标 ID。
## [br]
## @param property: 可调属性声明。
## [br]
## @return 注册成功返回 true。
func register_property(target_id: StringName, property: GFRuntimeTunableProperty) -> bool:
	if property == null or property.property_id == &"":
		return false
	var entry: Dictionary = _get_entry(target_id)
	if entry.is_empty():
		return false

	var properties: Array = _get_array_ref(entry, "properties")
	var properties_by_id: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(entry, "properties_by_id", {}))
	if properties_by_id.has(property.property_id):
		var existing: Variant = properties_by_id[property.property_id]
		var index: int = properties.find(existing)
		if index >= 0:
			properties[index] = property
	else:
		properties.append(property)
	properties_by_id[property.property_id] = property
	_refresh_attached_overlay_panel()
	return true


## 移除目标上的可调属性。
## [br]
## @api public
## [br]
## @param target_id: 目标 ID。
## [br]
## @param property_id: 属性 ID。
## [br]
## @return 找到并移除时返回 true。
func remove_property(target_id: StringName, property_id: StringName) -> bool:
	var entry: Dictionary = _get_entry(target_id)
	if entry.is_empty():
		return false
	var properties_by_id: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(entry, "properties_by_id", {}))
	if not properties_by_id.has(property_id):
		return false

	var property: Variant = properties_by_id[property_id]
	_erase_array_value(_get_array_ref(entry, "properties"), property)
	_erase_dictionary_key(properties_by_id, property_id)
	_refresh_attached_overlay_panel()
	return true


## 获取目标 ID 列表。
## [br]
## @api public
## [br]
## @param include_hidden: 为 true 时包含隐藏目标。
## [br]
## @return 排序后的目标 ID。
func get_target_ids(include_hidden: bool = false) -> PackedStringArray:
	_prune_invalid_targets()
	var entries: Array[Dictionary] = _get_sorted_entries(include_hidden)
	var result: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		_append_packed_string(result, GFVariantData.get_option_string(entry, "id"))
	return result


## 读取目标属性当前值。
## [br]
## @api public
## [br]
## @param target_id: 目标 ID。
## [br]
## @param property_id: 属性 ID。
## [br]
## @return 当前值；找不到时返回 null。
## [br]
## @schema return: Variant，当前属性值，类型由对应 GFRuntimeTunableProperty 决定。
func get_property_value(target_id: StringName, property_id: StringName) -> Variant:
	var target: Object = _resolve_target(target_id)
	var property: GFRuntimeTunableProperty = _resolve_property(target_id, property_id)
	if target == null or property == null:
		return null
	return property.read_value(target)


## 写入目标属性。
## [br]
## @api public
## [br]
## @param target_id: 目标 ID。
## [br]
## @param property_id: 属性 ID。
## [br]
## @param value: 请求写入的值。
## [br]
## @return 写入成功返回 true。
## [br]
## @schema value: Variant，请求写入的原始值，会由属性 schema 归一化。
func set_property_value(target_id: StringName, property_id: StringName, value: Variant) -> bool:
	if not _writes_are_allowed():
		return false
	var target: Object = _resolve_target(target_id)
	var property: GFRuntimeTunableProperty = _resolve_property(target_id, property_id)
	if target == null or property == null:
		return false

	var old_value: Variant = property.read_value(target)
	if not property.write_value(target, value):
		return false
	var new_value: Variant = property.read_value(target)
	property_changed.emit(target_id, property_id, old_value, new_value)
	_refresh_attached_overlay_panel()
	return true


## 读取运行时 Inspector 快照。
## [br]
## @api public
## [br]
## @param include_hidden: 为 true 时包含隐藏目标和属性。
## [br]
## @return 目标快照数组。
## [br]
## @schema return: Array[Dictionary]，每个元素包含 id、label、group、visible、valid 和 properties。
func get_target_snapshot(include_hidden: bool = false) -> Array[Dictionary]:
	_prune_invalid_targets()
	var result: Array[Dictionary] = []
	for entry: Dictionary in _get_sorted_entries(include_hidden):
		result.append(_build_target_snapshot(entry, include_hidden))
	return result


## 清空所有目标。
## [br]
## @api public
func clear_targets() -> void:
	_targets.clear()
	_target_order_counter = 0
	_refresh_attached_overlay_panel()


## 将 Inspector 快照作为文本面板注册到 GFDebugOverlayUtility。
## [br]
## @api public
## [br]
## @param panel_id: Overlay 面板 ID。
## [br]
## @return 注册成功返回 true。
func attach_to_debug_overlay(panel_id: StringName = &"gf.runtime_inspector") -> bool:
	var overlay: GFDebugOverlayUtility = _get_debug_overlay_utility()
	if overlay == null:
		return false
	_attached_overlay_panel_id = panel_id
	return overlay.push_panel_text(panel_id, _build_overlay_panel_text(), {
		"label": "Runtime Inspector",
		"group": "Diagnostics",
	})


## 把 Inspector 当前状态重新发布到已附加的 Overlay 面板。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 已附加且发布成功时返回 true。
func refresh_debug_overlay_panel() -> bool:
	if _attached_overlay_panel_id == &"":
		return false
	var overlay: GFDebugOverlayUtility = _get_debug_overlay_utility()
	if overlay == null:
		return false
	return overlay.push_panel_text(
		_attached_overlay_panel_id,
		_build_overlay_panel_text(),
		{
			"label": "Runtime Inspector",
			"group": "Diagnostics",
		}
	)


## 从 GFDebugOverlayUtility 移除 Inspector 面板。
## [br]
## @api public
## [br]
## @param panel_id: Overlay 面板 ID；为空时使用当前附加的面板 ID。
func detach_from_debug_overlay(panel_id: StringName = &"") -> void:
	var effective_id: StringName = panel_id if panel_id != &"" else _attached_overlay_panel_id
	if effective_id == &"":
		return
	var overlay: GFDebugOverlayUtility = _get_debug_overlay_utility()
	if overlay != null:
		overlay.remove_panel(effective_id)
	if effective_id == _attached_overlay_panel_id:
		_attached_overlay_panel_id = &""


## 获取诊断快照。
## [br]
## @api public
## [br]
## @return 当前注册状态。
## [br]
## @schema return: Dictionary，包含 target_count、target_ids 和 writes_allowed。
func get_debug_snapshot() -> Dictionary:
	_prune_invalid_targets()
	return {
		"target_count": _targets.size(),
		"target_ids": get_target_ids(true),
		"writes_allowed": _writes_are_allowed(),
	}


# --- 私有/辅助方法 ---

func _get_entry(target_id: StringName) -> Dictionary:
	if not _targets.has(target_id):
		return {}
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_targets, target_id, {}))


func _get_debug_overlay_utility() -> GFDebugOverlayUtility:
	var utility: Variant = get_utility(GFDebugOverlayUtility)
	if utility is GFDebugOverlayUtility:
		var overlay: GFDebugOverlayUtility = utility
		return overlay
	return null


func _resolve_target(target_id: StringName) -> Object:
	var entry: Dictionary = _get_entry(target_id)
	if entry.is_empty():
		return null
	var target_ref: WeakRef = _get_dictionary_weak_ref(entry, "target_ref")
	if target_ref == null:
		return null
	var target: Object = target_ref.get_ref()
	return target if is_instance_valid(target) else null


func _resolve_property(target_id: StringName, property_id: StringName) -> GFRuntimeTunableProperty:
	var entry: Dictionary = _get_entry(target_id)
	if entry.is_empty():
		return null
	var properties_by_id: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(entry, "properties_by_id", {}))
	return _get_tunable_property(properties_by_id, property_id)


func _get_sorted_entries(include_hidden: bool) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for target_id: StringName in _targets:
		var entry: Dictionary = GFVariantData.to_dictionary(GFVariantData.get_option_value(_targets, target_id, {}))
		entry["id"] = target_id
		if not include_hidden and not GFVariantData.get_option_bool(entry, "visible", true):
			continue
		entries.append(entry)
	entries.sort_custom(_sort_entries)
	return entries


func _prune_invalid_targets() -> void:
	var invalid_target_ids: PackedStringArray = PackedStringArray()
	for target_id: StringName in _targets.keys():
		if _resolve_target(target_id) == null:
			_append_packed_string(invalid_target_ids, String(target_id))
	for target_id_text: String in invalid_target_ids:
		_erase_dictionary_key(_targets, StringName(target_id_text))


func _sort_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_order: int = GFVariantData.get_option_int(left, "order")
	var right_order: int = GFVariantData.get_option_int(right, "order")
	if left_order != right_order:
		return left_order < right_order
	return GFVariantData.get_option_string(left, "id") < GFVariantData.get_option_string(right, "id")


func _build_target_snapshot(entry: Dictionary, include_hidden: bool) -> Dictionary:
	var target_id: StringName = GFVariantData.get_option_string_name(entry, "id")
	var target: Object = _resolve_target(target_id)
	var properties: Array[Dictionary] = []
	var source_properties: Array = GFVariantData.get_option_array(entry, "properties")
	for property: GFRuntimeTunableProperty in source_properties:
		if property == null:
			continue
		if not include_hidden and not property.visible:
			continue
		var schema: Dictionary = property.to_schema()
		schema["value"] = property.read_value(target) if target != null else null
		properties.append(schema)

	return {
		"id": target_id,
		"label": GFVariantData.get_option_string(entry, "label", String(target_id)),
		"group": GFVariantData.get_option_string(entry, "group", "Runtime"),
		"visible": GFVariantData.get_option_bool(entry, "visible", true),
		"valid": target != null,
		"properties": properties,
	}


func _writes_are_allowed() -> bool:
	if not allow_writes:
		return false
	if debug_build_writes_only and not OS.is_debug_build():
		return false
	return true


func _refresh_attached_overlay_panel() -> void:
	if _attached_overlay_panel_id == &"":
		return
	var _refreshed: bool = refresh_debug_overlay_panel()


func _build_overlay_panel_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for target: Dictionary in get_target_snapshot(false):
		_append_packed_string(lines, "[%s] %s" % [
			GFVariantData.get_option_string(target, "group", "Runtime"),
			GFVariantData.get_option_string(target, "label", GFVariantData.get_option_string(target, "id")),
		])
		var properties: Array = GFVariantData.get_option_array(target, "properties")
		for property: Dictionary in properties:
			_append_packed_string(lines, "  %s: %s" % [
				GFVariantData.get_option_string(property, "label", GFVariantData.get_option_string(property, "property_id")),
				str(GFVariantData.get_option_value(property, "value", null)),
			])
	if lines.is_empty():
		return "No runtime inspector targets."
	return "\n".join(lines)


func _get_array_ref(source: Dictionary, key: Variant) -> Array:
	var value: Variant = GFVariantData.get_option_value(source, key, [])
	if value is Array:
		var array_value: Array = value
		return array_value
	var new_array: Array = []
	source[key] = new_array
	return new_array


func _get_dictionary_weak_ref(source: Dictionary, key: Variant) -> WeakRef:
	var value: Variant = GFVariantData.get_option_value(source, key, null)
	if value is WeakRef:
		var weak_ref: WeakRef = value
		return weak_ref
	return null


func _get_tunable_property(source: Dictionary, key: Variant) -> GFRuntimeTunableProperty:
	var value: Variant = GFVariantData.get_option_value(source, key, null)
	if value is GFRuntimeTunableProperty:
		var property: GFRuntimeTunableProperty = value
		return property
	return null


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var erased: bool = target.erase(key)
	if erased:
		return


func _erase_array_value(target: Array, value: Variant) -> void:
	target.erase(value)
