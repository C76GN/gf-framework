## GFFormBinder: 轻量 Control 表单读写绑定器。
##
## 将 StringName 字段映射到 Control 节点，提供批量 read/write 和变化信号。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFFormBinder
extends RefCounted


# --- 信号 ---

## 字段值变化时发出。
## [br]
## @api public
## [br]
## @param key: 字段键。
## [br]
## @param value: 当前控件值。
## [br]
## @schema value: Variant，当前控件值，类型取决于绑定控件。
signal field_changed(key: StringName, value: Variant)


# --- 常量 ---

const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")


# --- 私有变量 ---

var _fields: Dictionary = {}


# --- 公共方法 ---

## 绑定字段到控件。
## [br]
## @api public
## [br]
## @param key: 字段键。
## [br]
## @param control: 控件节点。
## [br]
## @param default_value: 控件失效或读取失败时的默认值。
## [br]
## @schema default_value: Variant，控件失效或读取失败时返回的默认值。
func bind_field(key: StringName, control: Control, default_value: Variant = null) -> void:
	if key == &"":
		push_error("[GFFormBinder] bind_field 失败：字段键为空。")
		return
	if not is_instance_valid(control):
		push_error("[GFFormBinder] bind_field 失败：控件无效。")
		return

	unbind_field(key)
	var value_changed_connections: Array[Dictionary] = GFControlValueAdapter.connect_value_changed_with_handles(control, func() -> void:
		_on_field_changed(key)
	)
	var tree_exited_callback: Callable = func() -> void:
		unbind_field(key)
	var _tree_exited_connection_result: int = control.tree_exited.connect(
		tree_exited_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	)
	_fields[key] = {
		"control_ref": weakref(control),
		"default_value": default_value,
		"value_changed_connections": value_changed_connections,
		"tree_exited_callable": tree_exited_callback,
	}


## 解绑字段。
## [br]
## @api public
## [br]
## @param key: 字段键。
func unbind_field(key: StringName) -> void:
	if _fields.has(key):
		_disconnect_field_info(_get_field_info(key))
	var _erased: bool = _fields.erase(key)


## 清空所有字段绑定。
## [br]
## @api public
func clear() -> void:
	var keys: Array = _fields.keys()
	for key_variant: Variant in keys:
		unbind_field(GFVariantData.to_string_name(key_variant))


## 获取绑定字段列表。
## [br]
## @api public
## [br]
## @return 字段键数组。
func get_bound_fields() -> Array[StringName]:
	var result: Array[StringName] = []
	var keys: Array = _fields.keys()
	for key_variant: Variant in keys:
		var key: StringName = GFVariantData.to_string_name(key_variant)
		if _get_control(key) != null:
			result.append(key)
		else:
			var _erased: bool = _fields.erase(key)
	return result


## 读取单个字段值。
## [br]
## @api public
## [br]
## @param key: 字段键。
## [br]
## @param fallback: 回退值。
## [br]
## @schema fallback: Variant，字段未绑定或控件无法读取时返回的回退值。
## [br]
## @return 字段值。
## [br]
## @schema return: Variant，字段当前值；无法读取时返回 fallback。
func get_field_value(key: StringName, fallback: Variant = null) -> Variant:
	var control: Control = _get_control(key)
	if control == null:
		return fallback

	var info: Dictionary = _get_field_info(key)
	var default_value: Variant = GFVariantData.get_option_value(info, "default_value", fallback)
	return GFControlValueAdapter.get_value(control, default_value)


## 写入单个字段值。
## [br]
## @api public
## [br]
## @param key: 字段键。
## [br]
## @param value: 字段值。
## [br]
## @schema value: Variant，要写入绑定控件的字段值。
## [br]
## @return 成功写入时返回 true。
func set_field_value(key: StringName, value: Variant) -> bool:
	var control: Control = _get_control(key)
	if control == null:
		return false
	return GFControlValueAdapter.set_value(control, value)


## 读取全部字段值。
## [br]
## @api public
## [br]
## @return 字段值字典。
## [br]
## @schema return: Dictionary，键为字段 StringName，值为对应控件当前值。
func read_values() -> Dictionary:
	var data: Dictionary = {}
	for key: StringName in get_bound_fields():
		data[key] = get_field_value(key)
	return data


## 批量写入字段值。
## [br]
## @api public
## [br]
## @param data: 字段值字典。
## [br]
## @schema data: Dictionary，键为字段名，值为要写入绑定控件的字段值。
## [br]
## @param ignore_missing_fields: true 时忽略未绑定字段，false 时输出 warning。
func write_values(data: Dictionary, ignore_missing_fields: bool = true) -> void:
	for key_variant: Variant in data.keys():
		var key: StringName = GFVariantData.to_string_name(key_variant)
		if not _fields.has(key):
			if not ignore_missing_fields:
				push_warning("[GFFormBinder] 未绑定字段：%s" % String(key))
			continue
		var _set_field_value_result_182: Variant = set_field_value(key, data[key_variant])


# --- 私有/辅助方法 ---

func _get_control(key: StringName) -> Control:
	var info: Dictionary = _get_field_info(key)
	if info.is_empty():
		return null

	var control_ref: WeakRef = _variant_to_weak_ref(GFVariantData.get_option_value(info, "control_ref"))
	var control: Control = _INSTANCE_GUARD._get_live_control_from_ref(control_ref)
	if not is_instance_valid(control):
		unbind_field(key)
		return null
	return control


func _on_field_changed(key: StringName) -> void:
	if not _fields.has(key):
		return
	field_changed.emit(key, get_field_value(key))


func _get_field_info(key: StringName) -> Dictionary:
	var info_variant: Variant = GFVariantData.get_option_value(_fields, key, {})
	if info_variant is Dictionary:
		var info: Dictionary = info_variant
		return info
	return {}


func _disconnect_field_info(info: Dictionary) -> void:
	if info.is_empty():
		return

	var connections: Array = GFVariantData.get_option_array(info, "value_changed_connections")
	GFControlValueAdapter.disconnect_value_changed_handles(connections)

	var control_ref: WeakRef = _variant_to_weak_ref(GFVariantData.get_option_value(info, "control_ref"))
	var control: Control = _INSTANCE_GUARD._get_live_control_from_ref(control_ref)
	var tree_exited_callable: Callable = _variant_to_callable(GFVariantData.get_option_value(info, "tree_exited_callable"))
	if (
		is_instance_valid(control)
		and tree_exited_callable.is_valid()
		and control.tree_exited.is_connected(tree_exited_callable)
	):
		control.tree_exited.disconnect(tree_exited_callable)


func _variant_to_weak_ref(value: Variant) -> WeakRef:
	if value is WeakRef:
		var control_ref: WeakRef = value
		return control_ref
	return null


func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		var callable: Callable = value
		return callable
	return Callable()
