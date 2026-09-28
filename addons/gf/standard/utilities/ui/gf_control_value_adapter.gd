## GFControlValueAdapter: 常见 Control 节点的值读写适配器。
##
## 用于表单、设置页和编辑工具中统一读写控件值，不持有状态。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFControlValueAdapter
extends RefCounted


# --- 常量 ---

## 提供断开信号连接时校验弱引用 Control 实例的内部帮助脚本。
## [br]
## @api private
const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")


# --- 公共方法 ---

## 从控件读取值。
## [br]
## @api public
## [br]
## @param control: 控件节点。
## [br]
## @param fallback: 不支持读取时返回的值。
## [br]
## @schema fallback: Variant，控件无效或不支持读取时返回的回退值。
## [br]
## @return 控件值。
## [br]
## @schema return: Variant，控件当前值；无法读取时返回 fallback。
static func get_value(control: Control, fallback: Variant = null) -> Variant:
	if control == null:
		return fallback

	if control is LineEdit:
		var line_edit: LineEdit = control
		return line_edit.text
	if control is TextEdit:
		var text_edit: TextEdit = control
		return text_edit.text
	if control is OptionButton:
		var option_button: OptionButton = control
		return option_button.selected
	if control is ColorPickerButton:
		var color_picker: ColorPickerButton = control
		return color_picker.color
	if control is BaseButton:
		var base_button: BaseButton = control
		return base_button.button_pressed
	if control is Range:
		var range_control: Range = control
		return range_control.value
	if control is ItemList:
		var item_list: ItemList = control
		return item_list.get_selected_items()
	if control.has_method("get_value"):
		return control.call("get_value")
	if "value" in control:
		return GFObjectPropertyTools.read_property(control, NodePath("value"), fallback)

	return fallback


## 向控件写入值。
## [br]
## @api public
## [br]
## @param control: 控件节点。
## [br]
## @param value: 值。
## [br]
## @schema value: Variant，要写入控件的值，具体类型取决于控件类型。
## [br]
## @return 成功写入时返回 true。
static func set_value(control: Control, value: Variant) -> bool:
	if control == null:
		return false

	if control is LineEdit:
		var line_edit: LineEdit = control
		line_edit.text = GFVariantData.to_text(value)
		return true
	if control is TextEdit:
		var text_edit: TextEdit = control
		text_edit.text = GFVariantData.to_text(value)
		return true
	if control is OptionButton:
		var option_button: OptionButton = control
		option_button.selected = GFVariantData.to_int(value)
		return true
	if control is ColorPickerButton:
		if value is Color:
			var color_picker: ColorPickerButton = control
			var color: Color = value
			color_picker.color = color
			return true
		return false
	if control is BaseButton:
		var base_button: BaseButton = control
		base_button.button_pressed = GFVariantData.to_bool(value)
		return true
	if control is Range:
		var range_control: Range = control
		range_control.value = GFVariantData.to_float(value)
		return true
	if control is ItemList:
		var item_list: ItemList = control
		_set_item_list_selection(item_list, value)
		return true
	if control.has_method("set_value"):
		var _call_result: Variant = control.call("set_value", value)
		return true
	if "value" in control:
		control.set("value", value)
		return true

	return false


## 连接控件值变化信号。
## [br]
## @api public
## [br]
## @param control: 控件节点。
## [br]
## @param callback: 值变化后调用的回调，不接收参数。
## [br]
## @return 成功连接时返回 true。
static func connect_value_changed(control: Control, callback: Callable) -> bool:
	return not connect_value_changed_with_handles(control, callback).is_empty()


## 连接控件值变化信号并返回可断开的连接句柄。
## [br]
## @api public
## [br]
## @param control: 控件节点。
## [br]
## @param callback: 值变化后调用的回调，不接收参数。
## [br]
## @return 连接句柄数组，可传给 disconnect_value_changed_handles()。
## [br]
## @schema return: Array[Dictionary]，每个条目包含 control_ref、signal_name 和 callable。
static func connect_value_changed_with_handles(control: Control, callback: Callable) -> Array[Dictionary]:
	var connections: Array[Dictionary] = []
	if control == null or not callback.is_valid():
		return connections

	if control is LineEdit:
		var line_edit_callback: Callable = func(_text: String) -> void:
			callback.call()
		_connect_control_signal(control, &"text_changed", line_edit_callback, connections)
		return connections
	if control is TextEdit:
		var text_edit_callback: Callable = func() -> void:
			callback.call()
		_connect_control_signal(control, &"text_changed", text_edit_callback, connections)
		return connections
	if control is OptionButton:
		var option_callback: Callable = func(_index: int) -> void:
			callback.call()
		_connect_control_signal(control, &"item_selected", option_callback, connections)
		return connections
	if control is ColorPickerButton:
		var color_callback: Callable = func(_color: Color) -> void:
			callback.call()
		_connect_control_signal(control, &"color_changed", color_callback, connections)
		return connections
	if control is BaseButton:
		var button_callback: Callable = func(_pressed: bool) -> void:
			callback.call()
		_connect_control_signal(control, &"toggled", button_callback, connections)
		return connections
	if control is Range:
		var range_callback: Callable = func(_value: float) -> void:
			callback.call()
		_connect_control_signal(control, &"value_changed", range_callback, connections)
		return connections
	if control is ItemList:
		var item_selected_callback: Callable = func(_index: int) -> void:
			callback.call()
		_connect_control_signal(control, &"item_selected", item_selected_callback, connections)
		var multi_selected_callback: Callable = func(_index: int, _selected: bool) -> void:
			callback.call()
		_connect_control_signal(control, &"multi_selected", multi_selected_callback, connections)
		return connections
	if control.has_signal("value_changed"):
		var value_callback: Callable = func(_value: Variant = null) -> void:
			callback.call()
		_connect_control_signal(control, &"value_changed", value_callback, connections)
		return connections

	return connections


## 断开 connect_value_changed_with_handles() 返回的连接句柄。
## [br]
## @api public
## [br]
## @param connections: 连接句柄数组。
## [br]
## @schema connections: Array，包含 connect_value_changed_with_handles() 返回的连接句柄 Dictionary。
static func disconnect_value_changed_handles(connections: Array) -> void:
	for connection_variant: Variant in connections:
		var connection: Dictionary = GFVariantData.as_dictionary(connection_variant)
		if connection.is_empty():
			continue
		var control_ref: WeakRef = _variant_to_weak_ref(GFVariantData.get_option_value(connection, "control_ref"))
		var control: Control = _INSTANCE_GUARD._get_live_control_from_ref(control_ref)
		if not is_instance_valid(control):
			continue
		var signal_name: StringName = GFVariantData.get_option_string_name(connection, "signal_name")
		var callable: Callable = _variant_to_callable(GFVariantData.get_option_value(connection, "callable"))
		if signal_name != &"" and callable.is_valid() and control.is_connected(signal_name, callable):
			control.disconnect(signal_name, callable)


# --- 私有/辅助方法 ---

## 仅在控件、信号和 Callable 有效且连接成功后，追加可断开的连接记录。
## [br]
## @api private
static func _connect_control_signal(
	control: Control,
	signal_name: StringName,
	callable: Callable,
	connections: Array[Dictionary]
) -> void:
	if control == null or signal_name == &"" or not callable.is_valid():
		return
	if not control.has_signal(signal_name):
		return
	var connection_result: int = control.connect(signal_name, callable)
	if connection_result != OK:
		return
	connections.append({
		"control_ref": weakref(control),
		"signal_name": signal_name,
		"callable": callable,
	})


## 先清空 ItemList 旧选择，再按整数、数组或 PackedInt32Array 输入选择项目。
## [br]
## @api private
static func _set_item_list_selection(item_list: ItemList, value: Variant) -> void:
	item_list.deselect_all()
	if value is PackedInt32Array:
		for index: int in value:
			item_list.select(index, false)
		return
	if value is Array:
		for index_variant: Variant in value:
			item_list.select(GFVariantData.to_int(index_variant), false)
		return
	item_list.select(GFVariantData.to_int(value), false)


## 将 WeakRef Variant 收窄为 WeakRef；其他类型返回 null。
## [br]
## @api private
static func _variant_to_weak_ref(value: Variant) -> WeakRef:
	if value is WeakRef:
		var control_ref: WeakRef = value
		return control_ref
	return null


## 将 Callable Variant 收窄为 Callable；其他类型返回无效 Callable。
## [br]
## @api private
static func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		var callable: Callable = value
		return callable
	return Callable()
