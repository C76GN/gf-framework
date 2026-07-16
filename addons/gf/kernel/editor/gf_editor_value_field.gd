@tool

## GFEditorValueField: 编辑器通用 Variant 值输入控件。
##
## 根据 Godot 属性信息创建基础输入控件，适合 Inspector、Dock 或批量资源表格复用。
## 支持调用方注册自定义控件工厂；自定义控件只需遵循 get_value、set_value、set_editable
## 和 value_changed 信号约定即可接入。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
## [br]
## @layer kernel/editor
class_name GFEditorValueField
extends HBoxContainer


# --- 信号 ---

## 控件值变化时发出。
## [br]
## @api public
## [br]
## @param value: 新值。
## [br]
## @schema value: Variant editor value read from the active control.
signal value_changed(value: Variant)

## 控件值变化防抖后发出。debounce_seconds 小于等于 0 时与 value_changed 同步发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param value: 防抖后的值。
## [br]
## @schema value: Variant editor value read from the active control.
signal debounced_value_changed(value: Variant)

## Array/Dictionary JSON 输入解析失败时发出。
## [br]
## @api public
## [br]
## @param text: 用户输入的原始文本。
## [br]
## @param error_message: JSON 解析错误说明。
signal value_parse_failed(text: String, error_message: String)


# --- 常量 ---

const _GF_REPORT_VALUE_CODEC_SCRIPT = preload("res://addons/gf/kernel/core/gf_report_value_codec.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

const _CUSTOM_EDITOR_META: StringName = &"gf_editor_value_field_custom"
const _VECTOR_EDITOR_META: StringName = &"gf_editor_value_field_vector"
const _ENUM_ITEMS_META: StringName = &"gf_editor_value_field_enum_items"


# --- 公共变量 ---

## 标签文本。show_label 为 true 时会显示在输入控件左侧。
## [br]
## @api public
## [br]
## @since 8.0.0
var label_text: String = ""

## 是否显示标签。
## [br]
## @api public
## [br]
## @since 8.0.0
var show_label: bool = false

## 防抖秒数。小于等于 0 时立即发出 debounced_value_changed。
## [br]
## @api public
## [br]
## @since 8.0.0
var debounce_seconds: float = 0.0


# --- 私有变量 ---

var _property_info: Dictionary = {}
var _value: Variant = null
var _editor: Control = null
var _label: Label = null
var _debounce_timer: Timer = null
var _editable: bool = true
var _is_updating: bool = false
var _editor_factories: Dictionary = {}


# --- 公共方法 ---

## 配置字段输入控件。
## [br]
## @api public
## [br]
## @param property_info: Godot 属性信息字典，常用键为 name、type、hint、hint_string。
## [br]
## @schema property_info: Godot property info dictionary.
## [br]
## @param value: 初始值。
## [br]
## @schema value: Variant initial editor value.
func configure(property_info: Dictionary, value: Variant = null) -> void:
	_property_info = property_info.duplicate(true)
	_value = value
	if label_text.is_empty():
		label_text = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(_property_info, "label", _GF_VARIANT_ACCESS_SCRIPT.get_option_string(_property_info, "name"))
	_rebuild_editor()


## 设置当前值。
## [br]
## @api public
## [br]
## @param value: 新值。
## [br]
## @schema value: Variant value assigned to the editor.
func set_value(value: Variant) -> void:
	_value = value
	_sync_editor_from_value()


## 获取当前值。
## [br]
## @api public
## [br]
## @return 当前值。
## [br]
## @schema return: Variant value read from the active editor control.
func get_value() -> Variant:
	return _read_editor_value()


## 设置控件是否可编辑。
## [br]
## @api public
## [br]
## @param editable: 为 true 时允许编辑。
func set_editable(editable: bool) -> void:
	_editable = editable
	if _editor != null:
		_apply_editable_state(_editor)


## 获取当前属性信息。
## [br]
## @api public
## [br]
## @return 属性信息字典。
## [br]
## @schema return: Godot property info dictionary copy.
func get_property_info() -> Dictionary:
	return _property_info.duplicate(true)


## 设置左侧标签。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param text: 标签文本。
## [br]
## @param label_visible: 是否显示标签。
func set_label(text: String, label_visible: bool = true) -> void:
	label_text = text
	show_label = label_visible
	_sync_label()


## 设置防抖时间。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param seconds: 防抖秒数；小于等于 0 时禁用等待。
func set_debounce_seconds(seconds: float) -> void:
	debounce_seconds = maxf(seconds, 0.0)
	if _debounce_timer != null:
		_debounce_timer.stop()


## 注册指定 Variant 类型的自定义编辑控件工厂。
## [br]
## 工厂建议签名为 func(property_info: Dictionary, value: Variant) -> Control。
## 返回控件若实现 get_value、set_value、set_editable 或 value_changed，GFEditorValueField 会按约定调用。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param value_type: Godot Variant.Type。
## [br]
## @param factory: 控件工厂回调。
## [br]
## @return 注册成功返回 true。
func register_editor_factory(value_type: Variant.Type, factory: Callable) -> bool:
	if value_type < TYPE_NIL or not factory.is_valid():
		return false
	_editor_factories[value_type] = factory
	return true


## 注销指定 Variant 类型的自定义编辑控件工厂。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param value_type: Godot Variant.Type。
## [br]
## @return 原先存在并删除时返回 true。
func unregister_editor_factory(value_type: Variant.Type) -> bool:
	return _editor_factories.erase(value_type)


## 清空自定义编辑控件工厂。
## [br]
## @api public
## [br]
## @since 8.0.0
func clear_editor_factories() -> void:
	_editor_factories.clear()


## 获取已注册工厂的 Variant 类型。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return Variant.Type 数值列表。
func get_registered_editor_types() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for key: Variant in _editor_factories.keys():
		var _append_result: bool = result.append(_GF_VARIANT_ACCESS_SCRIPT.to_int(key))
	result.sort()
	return result


# --- 私有/辅助方法 ---

func _rebuild_editor() -> void:
	if _editor != null:
		remove_child(_editor)
		_editor.queue_free()
		_editor = null

	_sync_label()
	_editor = _create_editor_for_type(_get_property_type())
	add_child(_editor)
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_editable_state(_editor)
	_sync_editor_from_value()


func _sync_label() -> void:
	if show_label and _label == null:
		_label = Label.new()
		add_child(_label)
		move_child(_label, 0)
	if _label == null:
		return
	_label.text = label_text
	_label.visible = show_label
	_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _create_editor_for_type(value_type: Variant.Type) -> Control:
	var custom_editor: Control = _create_custom_editor(value_type)
	if custom_editor != null:
		return custom_editor

	if _is_enum_property(value_type):
		return _create_enum_editor()

	match value_type:
		TYPE_BOOL:
			var checkbox: CheckBox = CheckBox.new()
			var _connect_result_bool: Error = checkbox.toggled.connect(_on_bool_toggled) as Error
			return checkbox
		TYPE_INT:
			var int_spin: SpinBox = SpinBox.new()
			int_spin.rounded = true
			_apply_spin_options(int_spin, true)
			var _connect_result_int: Error = int_spin.value_changed.connect(_on_number_changed) as Error
			return int_spin
		TYPE_FLOAT:
			var float_spin: SpinBox = SpinBox.new()
			float_spin.step = 0.01
			_apply_spin_options(float_spin, false)
			var _connect_result_float: Error = float_spin.value_changed.connect(_on_number_changed) as Error
			return float_spin
		TYPE_VECTOR2:
			return _create_vector_editor(2, false)
		TYPE_VECTOR2I:
			return _create_vector_editor(2, true)
		TYPE_VECTOR3:
			return _create_vector_editor(3, false)
		TYPE_VECTOR3I:
			return _create_vector_editor(3, true)
		TYPE_VECTOR4:
			return _create_vector_editor(4, false)
		TYPE_VECTOR4I:
			return _create_vector_editor(4, true)
		TYPE_COLOR:
			var color_picker: ColorPickerButton = ColorPickerButton.new()
			var _connect_result_color: Error = color_picker.color_changed.connect(_on_color_changed) as Error
			return color_picker
		_:
			var line_edit: LineEdit = LineEdit.new()
			var _connect_result_text: Error = line_edit.text_changed.connect(_on_text_changed) as Error
			return line_edit


func _create_custom_editor(value_type: Variant.Type) -> Control:
	if not _editor_factories.has(value_type):
		return null
	var factory: Callable = _variant_to_callable(_editor_factories[value_type])
	if not factory.is_valid():
		return null

	var control_value: Variant = factory.call(_property_info.duplicate(true), _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(_value))
	if control_value is Control:
		var control: Control = control_value
		control.set_meta(_CUSTOM_EDITOR_META, true)
		_connect_custom_editor(control)
		return control
	return null


func _create_enum_editor() -> OptionButton:
	var option_button: OptionButton = OptionButton.new()
	var enum_items: Array[Dictionary] = _parse_enum_items(_get_property_hint_string())
	option_button.set_meta(_ENUM_ITEMS_META, enum_items)
	for item: Dictionary in enum_items:
		option_button.add_item(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(item, "label"),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(item, "value")
		)
	var _connect_result_enum: Error = option_button.item_selected.connect(_on_enum_item_selected) as Error
	return option_button


func _create_vector_editor(component_count: int, integer_components: bool) -> HBoxContainer:
	var container: HBoxContainer = HBoxContainer.new()
	container.set_meta(_VECTOR_EDITOR_META, {
		"component_count": component_count,
		"integer_components": integer_components,
	})
	var component_names: PackedStringArray = PackedStringArray(["x", "y", "z", "w"])
	for index: int in range(component_count):
		var spin: SpinBox = SpinBox.new()
		spin.name = component_names[index]
		spin.rounded = integer_components
		spin.step = 1.0 if integer_components else 0.01
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_spin_options(spin, integer_components)
		var _connect_result_vector: Error = spin.value_changed.connect(_on_vector_component_changed) as Error
		container.add_child(spin)
	return container


func _sync_editor_from_value() -> void:
	if _editor == null:
		return

	_is_updating = true
	var value_type: Variant.Type = _get_property_type()
	if _is_custom_editor(_editor):
		_sync_custom_editor_from_value(_editor)
		_is_updating = false
		return

	if _is_enum_property(value_type):
		_sync_enum_from_value()
		_is_updating = false
		return

	match value_type:
		TYPE_BOOL:
			var checkbox: CheckBox = _get_checkbox_editor()
			if checkbox != null:
				checkbox.button_pressed = _GF_VARIANT_ACCESS_SCRIPT.to_bool(_value)
		TYPE_INT, TYPE_FLOAT:
			var spin: SpinBox = _get_spin_editor()
			if spin != null:
				spin.value = _GF_VARIANT_ACCESS_SCRIPT.to_float(_value)
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I:
			_sync_vector_from_value()
		TYPE_COLOR:
			var color_picker: ColorPickerButton = _get_color_picker_editor()
			if color_picker != null:
				color_picker.color = _variant_to_color(_value, Color.WHITE)
		_:
			var line_edit: LineEdit = _get_line_edit_editor()
			if line_edit != null:
				line_edit.text = _stringify_value(_value)
	_is_updating = false


func _read_editor_value() -> Variant:
	if _editor == null:
		return _value

	if _is_custom_editor(_editor):
		return _read_custom_editor_value(_editor)

	var value_type: Variant.Type = _get_property_type()
	if _is_enum_property(value_type):
		var option_button: OptionButton = _get_option_button_editor()
		return option_button.get_selected_id() if option_button != null else _value

	match value_type:
		TYPE_BOOL:
			var checkbox: CheckBox = _get_checkbox_editor()
			return checkbox.button_pressed if checkbox != null else _value
		TYPE_INT:
			var spin: SpinBox = _get_spin_editor()
			return int(spin.value) if spin != null else _value
		TYPE_FLOAT:
			var spin: SpinBox = _get_spin_editor()
			return float(spin.value) if spin != null else _value
		TYPE_STRING_NAME:
			var line_edit: LineEdit = _get_line_edit_editor()
			return StringName(line_edit.text) if line_edit != null else _value
		TYPE_NODE_PATH:
			var line_edit: LineEdit = _get_line_edit_editor()
			return NodePath(line_edit.text) if line_edit != null else _value
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I:
			return _read_vector_editor_value()
		TYPE_COLOR:
			var color_picker: ColorPickerButton = _get_color_picker_editor()
			return color_picker.color if color_picker != null else _value
		TYPE_ARRAY, TYPE_DICTIONARY:
			var line_edit: LineEdit = _get_line_edit_editor()
			if line_edit == null:
				return _value
			var parse_result: Dictionary = _try_parse_json_value(line_edit.text, value_type)
			if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(parse_result, "ok", false):
				return _value
			return _GF_VARIANT_ACCESS_SCRIPT.get_option_value(parse_result, "value")
		_:
			var line_edit: LineEdit = _get_line_edit_editor()
			return line_edit.text if line_edit != null else _value


func _apply_editable_state(control: Control) -> void:
	if control is BaseButton:
		var button: BaseButton = control
		button.disabled = not _editable
	elif control is LineEdit:
		var line_edit: LineEdit = control
		line_edit.editable = _editable
	elif control is SpinBox:
		var spin: SpinBox = control
		spin.editable = _editable
	elif control is ColorPickerButton:
		var color_picker: ColorPickerButton = control
		color_picker.disabled = not _editable
	elif _is_custom_editor(control) and control.has_method("set_editable"):
		control.call("set_editable", _editable)

	for child: Node in control.get_children():
		if child is Control:
			var child_control: Control = child
			_apply_editable_state(child_control)


func _apply_spin_options(spin: SpinBox, integer_value: bool) -> void:
	if _get_property_hint() != PROPERTY_HINT_RANGE:
		return
	var parts: PackedStringArray = _get_property_hint_string().split(",", false)
	if parts.size() >= 1 and parts[0].is_valid_float():
		spin.min_value = parts[0].to_float()
	if parts.size() >= 2 and parts[1].is_valid_float():
		spin.max_value = parts[1].to_float()
	if parts.size() >= 3 and parts[2].is_valid_float():
		if integer_value:
			spin.step = float(maxi(parts[2].to_int(), 1))
		else:
			spin.step = parts[2].to_float()


func _sync_custom_editor_from_value(control: Control) -> void:
	if control.has_method("set_value"):
		control.call("set_value", _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(_value))


func _read_custom_editor_value(control: Control) -> Variant:
	if control.has_method("get_value"):
		return control.call("get_value")
	return _value


func _connect_custom_editor(control: Control) -> void:
	if control.has_signal("value_changed"):
		var _connect_result_custom: Error = control.connect("value_changed", Callable(self, "_on_custom_value_changed")) as Error


func _is_custom_editor(control: Control) -> bool:
	return control != null and control.has_meta(_CUSTOM_EDITOR_META)


func _is_enum_property(value_type: Variant.Type) -> bool:
	return value_type == TYPE_INT and _get_property_hint() == PROPERTY_HINT_ENUM


func _parse_enum_items(hint_string: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var next_value: int = 0
	for raw_item: String in hint_string.split(",", false):
		var item_text: String = raw_item.strip_edges()
		if item_text.is_empty():
			continue
		var label: String = item_text
		var value: int = next_value
		var separator_index: int = item_text.find(":")
		if separator_index >= 0:
			label = item_text.substr(0, separator_index).strip_edges()
			var value_text: String = item_text.substr(separator_index + 1).strip_edges()
			if value_text.is_valid_int():
				value = value_text.to_int()
		result.append({
			"label": label,
			"value": value,
		})
		next_value = value + 1
	return result


func _sync_enum_from_value() -> void:
	var option_button: OptionButton = _get_option_button_editor()
	if option_button == null:
		return
	var target_value: int = _GF_VARIANT_ACCESS_SCRIPT.to_int(_value)
	for index: int in range(option_button.item_count):
		if option_button.get_item_id(index) == target_value:
			option_button.select(index)
			return
	if option_button.item_count > 0:
		option_button.select(0)


func _sync_vector_from_value() -> void:
	var container: HBoxContainer = _get_vector_editor()
	if container == null:
		return
	var components: Array[float] = _get_vector_components(_value, _get_property_type())
	var index: int = 0
	for child: Node in container.get_children():
		if child is SpinBox and index < components.size():
			var spin: SpinBox = child
			spin.value = components[index]
			index += 1


func _read_vector_editor_value() -> Variant:
	var container: HBoxContainer = _get_vector_editor()
	if container == null:
		return _value
	var components: Array[float] = []
	for child: Node in container.get_children():
		if child is SpinBox:
			var spin: SpinBox = child
			components.append(spin.value)
	return _make_vector_value(components, _get_property_type())


func _get_vector_components(value: Variant, value_type: Variant.Type) -> Array[float]:
	match value_type:
		TYPE_VECTOR2:
			if value is Vector2:
				var vector2_value: Vector2 = value
				return [vector2_value.x, vector2_value.y]
		TYPE_VECTOR2I:
			if value is Vector2i:
				var vector2i_value: Vector2i = value
				return [vector2i_value.x, vector2i_value.y]
		TYPE_VECTOR3:
			if value is Vector3:
				var vector3_value: Vector3 = value
				return [vector3_value.x, vector3_value.y, vector3_value.z]
		TYPE_VECTOR3I:
			if value is Vector3i:
				var vector3i_value: Vector3i = value
				return [vector3i_value.x, vector3i_value.y, vector3i_value.z]
		TYPE_VECTOR4:
			if value is Vector4:
				var vector4_value: Vector4 = value
				return [vector4_value.x, vector4_value.y, vector4_value.z, vector4_value.w]
		TYPE_VECTOR4I:
			if value is Vector4i:
				var vector4i_value: Vector4i = value
				return [vector4i_value.x, vector4i_value.y, vector4i_value.z, vector4i_value.w]

	var component_count: int = 4 if value_type == TYPE_VECTOR4 or value_type == TYPE_VECTOR4I else 3 if value_type == TYPE_VECTOR3 or value_type == TYPE_VECTOR3I else 2
	var result: Array[float] = []
	for _index: int in range(component_count):
		result.append(0.0)
	return result


func _make_vector_value(components: Array[float], value_type: Variant.Type) -> Variant:
	match value_type:
		TYPE_VECTOR2:
			return Vector2(_get_component_float(components, 0), _get_component_float(components, 1))
		TYPE_VECTOR2I:
			return Vector2i(_get_component_int(components, 0), _get_component_int(components, 1))
		TYPE_VECTOR3:
			return Vector3(_get_component_float(components, 0), _get_component_float(components, 1), _get_component_float(components, 2))
		TYPE_VECTOR3I:
			return Vector3i(_get_component_int(components, 0), _get_component_int(components, 1), _get_component_int(components, 2))
		TYPE_VECTOR4:
			return Vector4(_get_component_float(components, 0), _get_component_float(components, 1), _get_component_float(components, 2), _get_component_float(components, 3))
		TYPE_VECTOR4I:
			return Vector4i(_get_component_int(components, 0), _get_component_int(components, 1), _get_component_int(components, 2), _get_component_int(components, 3))
	return _value


func _get_component_float(components: Array[float], index: int) -> float:
	return components[index] if index >= 0 and index < components.size() else 0.0


func _get_component_int(components: Array[float], index: int) -> int:
	return int(roundf(_get_component_float(components, index)))


func _get_property_type() -> Variant.Type:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_property_info, "type", TYPE_STRING) as Variant.Type


func _get_property_hint() -> PropertyHint:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_property_info, "hint", PROPERTY_HINT_NONE) as PropertyHint


func _get_property_hint_string() -> String:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_string(_property_info, "hint_string")


func _get_checkbox_editor() -> CheckBox:
	if _editor is CheckBox:
		var checkbox: CheckBox = _editor
		return checkbox
	return null


func _get_spin_editor() -> SpinBox:
	if _editor is SpinBox:
		var spin: SpinBox = _editor
		return spin
	return null


func _get_option_button_editor() -> OptionButton:
	if _editor is OptionButton:
		var option_button: OptionButton = _editor
		return option_button
	return null


func _get_vector_editor() -> HBoxContainer:
	if _editor is HBoxContainer and _editor.has_meta(_VECTOR_EDITOR_META):
		var container: HBoxContainer = _editor
		return container
	return null


func _get_color_picker_editor() -> ColorPickerButton:
	if _editor is ColorPickerButton:
		var color_picker: ColorPickerButton = _editor
		return color_picker
	return null


func _get_line_edit_editor() -> LineEdit:
	if _editor is LineEdit:
		var line_edit: LineEdit = _editor
		return line_edit
	return null


func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


func _variant_to_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		var color: Color = value
		return color
	return fallback


func _stringify_value(value: Variant) -> String:
	if value is Dictionary or value is Array:
		return _GF_REPORT_VALUE_CODEC_SCRIPT.stringify_json_compatible(
			value,
			"",
			false,
			_GF_REPORT_VALUE_CODEC_SCRIPT.make_redaction_options(
				_GF_REPORT_VALUE_CODEC_SCRIPT.REDACTION_PROFILE_DEBUG
			)
		)
	if value == null:
		return ""
	return str(value)


func _try_parse_json_value(text: String, expected_type: Variant.Type = TYPE_NIL) -> Dictionary:
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {
			"ok": false,
			"value": _value,
			"error": json.get_error_message(),
		}
	if expected_type == TYPE_ARRAY and not (json.data is Array):
		return {
			"ok": false,
			"value": _value,
			"error": "Expected Array JSON.",
		}
	if expected_type == TYPE_DICTIONARY and not (json.data is Dictionary):
		return {
			"ok": false,
			"value": _value,
			"error": "Expected Dictionary JSON.",
		}
	return {
		"ok": true,
		"value": json.data,
		"error": "",
	}


func _emit_value_changed(value: Variant) -> void:
	if _is_updating:
		return
	_value = value
	value_changed.emit(value)
	_emit_or_schedule_debounced_value()


func _emit_or_schedule_debounced_value() -> void:
	if debounce_seconds <= 0.0:
		debounced_value_changed.emit(_value)
		return
	var timer: Timer = _ensure_debounce_timer()
	timer.wait_time = maxf(debounce_seconds, 0.001)
	timer.start()


func _ensure_debounce_timer() -> Timer:
	if _debounce_timer != null:
		return _debounce_timer
	_debounce_timer = Timer.new()
	_debounce_timer.one_shot = true
	var _connect_result_timer: Error = _debounce_timer.timeout.connect(_on_debounce_timeout) as Error
	add_child(_debounce_timer)
	return _debounce_timer


# --- 信号处理函数 ---

func _on_bool_toggled(pressed: bool) -> void:
	_emit_value_changed(pressed)


func _on_number_changed(_value_float: float) -> void:
	_emit_value_changed(_read_editor_value())


func _on_enum_item_selected(_index: int) -> void:
	_emit_value_changed(_read_editor_value())


func _on_vector_component_changed(_component_value: float) -> void:
	_emit_value_changed(_read_editor_value())


func _on_color_changed(color: Color) -> void:
	_emit_value_changed(color)


func _on_custom_value_changed(value: Variant = null) -> void:
	if value == null:
		_emit_value_changed(_read_editor_value())
	else:
		_emit_value_changed(value)


func _on_text_changed(_text: String) -> void:
	var value_type: Variant.Type = _get_property_type()
	if value_type == TYPE_ARRAY or value_type == TYPE_DICTIONARY:
		var line_edit: LineEdit = _get_line_edit_editor()
		if line_edit == null:
			return
		var parse_result: Dictionary = _try_parse_json_value(line_edit.text, value_type)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(parse_result, "ok", false):
			value_parse_failed.emit(
				line_edit.text,
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(parse_result, "error", "")
			)
			return
		_emit_value_changed(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(parse_result, "value"))
		return

	_emit_value_changed(_read_editor_value())


func _on_debounce_timeout() -> void:
	debounced_value_changed.emit(_value)
