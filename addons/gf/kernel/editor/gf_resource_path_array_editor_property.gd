@tool

# GFResourcePathArrayEditorProperty: 用窗口安全的路径控件编辑资源引用数组。
extends EditorProperty


# --- 常量 ---

## 提供路径编辑器默认类型和资源状态查询的基础脚本。
## [br]
## @api private
const _GF_RESOURCE_PATH_EDITOR_PROPERTY = preload("res://addons/gf/kernel/editor/gf_resource_path_editor_property.gd")

## 提供资源路径数组属性 hint 的脚本。
## [br]
## @api private
const _GF_RESOURCE_PATH_HINT_SCRIPT = preload("res://addons/gf/kernel/editor/gf_resource_path_hint.gd")

## 构造可选择单个资源路径的行控件。
## [br]
## @api private
const _GF_RESOURCE_PATH_PICKER_CONTROL_SCRIPT = preload("res://addons/gf/kernel/editor/gf_resource_path_picker_control.gd")

## 为编辑器属性提供普通 Tooltip 的脚本。
## [br]
## @api private
const _GF_EDITOR_PROPERTY_PLAIN_TOOLTIP_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_property_plain_tooltip.gd")

## 行号标签的最小宽度，单位为 Control 尺寸单位。
## [br]
## @api private
const _ROW_INDEX_MIN_WIDTH: float = 34.0

## 有效路径摘要和状态文本使用的颜色。
## [br]
## @api private
const _INFO_TEXT_COLOR: Color = Color(0.62, 0.66, 0.72, 1.0)

## 无效资源路径状态文本使用的颜色。
## [br]
## @api private
const _WARNING_TEXT_COLOR: Color = Color(1.0, 0.58, 0.30, 1.0)


# --- 私有变量 ---

## 数组编辑器的根容器。
## [br]
## @api private
var _root: VBoxContainer

## 放置摘要标签与添加按钮的工具栏。
## [br]
## @api private
var _toolbar: HBoxContainer

## 显示路径总数及无效路径数的摘要标签。
## [br]
## @api private
var _summary_label: Label

## 向路径列表追加空项的按钮。
## [br]
## @api private
var _add_button: Button

## 当前动态路径行的父容器。
## [br]
## @api private
var _rows_root: VBoxContainer

## ResourcePicker 接受的基础资源类型。
## [br]
## @api private
var _base_type: String = _GF_RESOURCE_PATH_EDITOR_PROPERTY.DEFAULT_BASE_TYPE

## 写回属性时使用的 Godot Variant 类型。
## [br]
## @api private
var _property_type: Variant.Type = TYPE_ARRAY

## 选择资源后是否优先写入 UID 路径。
## [br]
## @api private
var _prefer_uid: bool = true

## 正在编辑和展示的路径序列；从属性读取时会逐项修剪空白。
## [br]
## @api private
var _paths: PackedStringArray = PackedStringArray()

## 属性更新或重建行期间的抑制标记，信号处理器据此跳过重入写回。
## [br]
## @api private
var _is_updating: bool = false


# --- Godot 生命周期方法 ---

## 构建路径数组的工具栏、摘要、添加按钮和条目容器，并刷新初始摘要。
## [br]
## @api private
func _init() -> void:
	_root = VBoxContainer.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_root)

	_toolbar = HBoxContainer.new()
	_toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(_toolbar)

	_summary_label = Label.new()
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_toolbar.add_child(_summary_label)

	_add_button = Button.new()
	_add_button.text = "添加"
	_add_button.tooltip_text = "添加资源路径"
	var _add_pressed_connected: Error = _add_button.pressed.connect(_on_add_pressed) as Error
	_toolbar.add_child(_add_button)

	_rows_root = VBoxContainer.new()
	_rows_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(_rows_root)

	_apply_summary()


# --- Godot 回调方法 ---

## 把当前属性收窄为资源路径数组并重建各行；更新标记覆盖整个刷新过程。
## [br]
## @api private
func _update_property() -> void:
	var edited_object: Object = get_edited_object()
	if edited_object == null:
		return

	var property_name: String = get_edited_property()
	_is_updating = true
	_paths = to_resource_path_array(edited_object.get(property_name))
	_rebuild_rows()
	_is_updating = false


## 通过统一的纯文本提示构造器为路径数组属性创建提示控件。
## [br]
## @api private
func _make_custom_tooltip(_for_text: String) -> Object:
	return _GF_EDITOR_PROPERTY_PLAIN_TOOLTIP_SCRIPT.make_tooltip(self)


# --- 框架内部方法 ---

## 配置资源路径数组编辑器。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param base_type: ResourcePicker 接受的资源基类。
## [br]
## @param property_type: 被编辑属性的 Godot Variant 类型。
## [br]
## @param prefer_uid: 保存资源路径时是否优先写入 uid://。
func setup(
	base_type: String = _GF_RESOURCE_PATH_EDITOR_PROPERTY.DEFAULT_BASE_TYPE,
	property_type: Variant.Type = TYPE_ARRAY,
	prefer_uid: bool = true
) -> void:
	_base_type = base_type if not base_type.strip_edges().is_empty() else _GF_RESOURCE_PATH_EDITOR_PROPERTY.DEFAULT_BASE_TYPE
	_property_type = property_type
	_prefer_uid = prefer_uid


## 判断属性是否适合用资源路径数组编辑器接管。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param type: Godot 属性类型。
## [br]
## @param hint_type: Godot 属性 hint 类型。
## [br]
## @param hint_string: Godot 属性 hint 字符串。
## [br]
## @return 适合接管时返回 true。
static func should_handle_property(type: Variant.Type, hint_type: int, hint_string: String) -> bool:
	if type != TYPE_ARRAY and type != TYPE_PACKED_STRING_ARRAY:
		return false
	if hint_type != _GF_RESOURCE_PATH_HINT_SCRIPT.RESOURCE_PATH_ARRAY:
		return false
	return not get_base_type_for_hint(hint_type, hint_string).is_empty()


## 从资源路径数组 hint 推导 ResourcePicker 基础类型。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param hint_type: Godot 属性 hint 类型。
## [br]
## @param hint_string: Godot 属性 hint 字符串。
## [br]
## @return 可用于 EditorResourcePicker.base_type 的类型名；无法安全推导时返回空字符串。
static func get_base_type_for_hint(hint_type: int, hint_string: String) -> String:
	if hint_type != _GF_RESOURCE_PATH_HINT_SCRIPT.RESOURCE_PATH_ARRAY:
		return ""
	return _GF_RESOURCE_PATH_EDITOR_PROPERTY.get_base_type_for_hint(hint_type, hint_string)


## 将属性值转换为资源路径数组。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param value: Array[String] 或 PackedStringArray 属性值。
## [br]
## @return 规范化后的路径数组。
## [br]
## @schema value: Variant，可为 PackedStringArray 或 Array；Array 元素会按字符串形式规范化为资源路径。
static func to_resource_path_array(value: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		for path: String in packed_value:
			var _append_packed_result: bool = result.append(path.strip_edges())
		return result

	if value is Array:
		var array_value: Array = value
		for item: Variant in array_value:
			var _append_array_result: bool = result.append(_to_path_string(item))
	return result


## 将资源路径数组转换为目标属性类型。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param paths: 资源路径数组。
## [br]
## @param property_type: 目标 Godot Variant 类型。
## [br]
## @return 可写回属性的数组值。
## [br]
## @schema return: Variant；property_type 为 TYPE_PACKED_STRING_ARRAY 时返回 PackedStringArray，否则返回 Array[String]。
static func make_property_value(paths: PackedStringArray, property_type: Variant.Type) -> Variant:
	if property_type == TYPE_PACKED_STRING_ARRAY:
		return paths

	var result: Array[String] = []
	for path: String in paths:
		result.append(path)
	return result


# --- 私有/辅助方法 ---

## 将 String 或 StringName 转为修剪空白后的路径；其他 Variant 转为空字符串。
## [br]
## @api private
static func _to_path_string(value: Variant) -> String:
	if value is String:
		var text_value: String = value
		return text_value.strip_edges()
	if value is StringName:
		var name_value: StringName = value
		return String(name_value).strip_edges()
	return ""


## 从选项字典读取 String 或 StringName；其他类型或缺失键返回空字符串，不修剪文本。
## [br]
## @api private
static func _get_string_option(options: Dictionary, key: String) -> String:
	var value: Variant = options.get(key, "")
	if value is String:
		var text_value: String = value
		return text_value
	if value is StringName:
		var name_value: StringName = value
		return String(name_value)
	return ""


## 从选项字典读取 bool；键缺失或值不是 bool 时返回 false。
## [br]
## @api private
static func _get_bool_option(options: Dictionary, key: String) -> bool:
	var value: Variant = options.get(key, false)
	if value is bool:
		var bool_value: bool = value
		return bool_value
	return false


## 移除并排队释放现有路径行，再按 _paths 重建行并更新摘要。
## [br]
## @api private
func _rebuild_rows() -> void:
	for child: Node in _rows_root.get_children():
		_rows_root.remove_child(child)
		child.queue_free()

	for index: int in range(_paths.size()):
		_rows_root.add_child(_create_row(index))
	_apply_summary()


## 创建含序号、资源路径选择器、移动/移除按钮及可选状态提示的路径行。
## [br]
## @api private
func _create_row(index: int) -> Control:
	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(row)

	var index_label: Label = Label.new()
	index_label.text = str(index + 1)
	index_label.custom_minimum_size.x = _ROW_INDEX_MIN_WIDTH
	index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(index_label)

	var picker_value: Variant = _GF_RESOURCE_PATH_PICKER_CONTROL_SCRIPT.new()
	if not picker_value is Control:
		return wrapper
	var picker: Control = picker_value
	picker.call(
		&"setup",
		_GF_RESOURCE_PATH_EDITOR_PROPERTY.get_resource_file_filters(_base_type)
	)
	picker.call(&"set_path", _paths[index])
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var status: Dictionary = _GF_RESOURCE_PATH_EDITOR_PROPERTY.get_resource_path_status(_paths[index], _base_type)
	var message: String = _get_string_option(status, "message")
	picker.tooltip_text = message if not message.is_empty() else _paths[index]
	var _path_changed_connected: Error = picker.connect(
		&"path_changed",
		_on_row_path_changed.bind(index)
	)
	row.add_child(picker)

	var up_button: Button = Button.new()
	up_button.text = "上移"
	up_button.tooltip_text = "上移该资源路径"
	up_button.disabled = index <= 0
	var _up_pressed_connected: Error = up_button.pressed.connect(_on_move_pressed.bind(index, -1)) as Error
	row.add_child(up_button)

	var down_button: Button = Button.new()
	down_button.text = "下移"
	down_button.tooltip_text = "下移该资源路径"
	down_button.disabled = index >= _paths.size() - 1
	var _down_pressed_connected: Error = down_button.pressed.connect(_on_move_pressed.bind(index, 1)) as Error
	row.add_child(down_button)

	var remove_button: Button = Button.new()
	remove_button.text = "移除"
	remove_button.tooltip_text = "移除该资源路径"
	var _remove_pressed_connected: Error = remove_button.pressed.connect(_on_remove_pressed.bind(index)) as Error
	row.add_child(remove_button)

	if not message.is_empty():
		var status_label: Label = Label.new()
		status_label.text = message
		status_label.tooltip_text = message
		status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		status_label.modulate = _INFO_TEXT_COLOR if _get_bool_option(status, "valid") else _WARNING_TEXT_COLOR
		wrapper.add_child(status_label)

	return wrapper


## 统计无效路径并更新摘要文本及对应颜色。
## [br]
## @api private
func _apply_summary() -> void:
	var invalid_count: int = _count_invalid_paths()
	if invalid_count > 0:
		_summary_label.text = "%d 个资源路径，%d 个无效" % [_paths.size(), invalid_count]
		_summary_label.modulate = _WARNING_TEXT_COLOR
	else:
		_summary_label.text = "%d 个资源路径" % _paths.size()
		_summary_label.modulate = _INFO_TEXT_COLOR


## 查询 _paths 中每个路径的资源状态并返回无效项数量。
## [br]
## @api private
func _count_invalid_paths() -> int:
	var count: int = 0
	for path: String in _paths:
		var status: Dictionary = _GF_RESOURCE_PATH_EDITOR_PROPERTY.get_resource_path_status(path, _base_type)
		if not _get_bool_option(status, "valid"):
			count += 1
	return count


## 暂停属性更新反馈，重建行后恢复标记，并按配置类型发出属性变更。
## [br]
## @api private
func _emit_paths_changed() -> void:
	var property_name: String = get_edited_property()
	_is_updating = true
	_rebuild_rows()
	_is_updating = false
	emit_changed(property_name, make_property_value(_paths, _property_type))


# --- 信号处理函数 ---

## 若当前不在更新过程中，则向路径序列末尾添加空项并提交变更。
## [br]
## @api private
func _on_add_pressed() -> void:
	if _is_updating:
		return
	var _append_result: bool = _paths.append("")
	_emit_paths_changed()


## 校验索引后修剪新路径；资源可加载时改用稳定资源路径，再提交变更。
## [br]
## @api private
func _on_row_path_changed(path: String, index: int) -> void:
	if _is_updating or index < 0 or index >= _paths.size():
		return

	var next_path: String = path.strip_edges()
	var resource: Resource = _GF_RESOURCE_PATH_EDITOR_PROPERTY.load_resource_from_path(
		next_path,
		_base_type
	)
	if resource != null:
		next_path = _GF_RESOURCE_PATH_EDITOR_PROPERTY.get_stable_resource_path(
			resource,
			_prefer_uid
		)
	_paths[index] = next_path
	_emit_paths_changed()


## 若不在更新过程中且索引有效，则移除对应路径并提交变更。
## [br]
## @api private
func _on_remove_pressed(index: int) -> void:
	if _is_updating or index < 0 or index >= _paths.size():
		return

	_paths.remove_at(index)
	_emit_paths_changed()


## 校验当前位置与目标位置后交换两项，并提交变更。
## [br]
## @api private
func _on_move_pressed(index: int, delta: int) -> void:
	if _is_updating:
		return

	var next_index: int = index + delta
	if index < 0 or index >= _paths.size() or next_index < 0 or next_index >= _paths.size():
		return

	var path: String = _paths[index]
	_paths[index] = _paths[next_index]
	_paths[next_index] = path
	_emit_paths_changed()
