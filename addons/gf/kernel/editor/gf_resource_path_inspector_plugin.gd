@tool

# GFResourcePathInspectorPlugin: 为资源路径字符串提供 ResourcePicker Inspector。
extends EditorInspectorPlugin


# --- 常量 ---

## 创建单路径 EditorProperty 并提供资源状态辅助方法的脚本。
## [br]
## @api private
const _GF_RESOURCE_PATH_EDITOR_PROPERTY = preload("res://addons/gf/kernel/editor/gf_resource_path_editor_property.gd")

## 创建资源路径数组 EditorProperty 的脚本。
## [br]
## @api private
const _GF_RESOURCE_PATH_ARRAY_EDITOR_PROPERTY = preload("res://addons/gf/kernel/editor/gf_resource_path_array_editor_property.gd")


# --- Godot 回调方法 ---

## 允许检查任意非空对象，具体属性是否接管由解析回调决定。
## [br]
## @api private
func _can_handle(object: Object) -> bool:
	return object != null


## 仅处理可在编辑器显示且能创建路径控件的属性，成功添加控件时返回 true。
## [br]
## @api private
func _parse_property(
	_object: Object,
	type: Variant.Type,
	name: String,
	hint_type: PropertyHint,
	hint_string: String,
	usage_flags: int,
	_wide: bool
) -> bool:
	if (usage_flags & PROPERTY_USAGE_EDITOR) == 0:
		return false

	var editor_property: EditorProperty = create_editor_property(type, hint_type, hint_string)
	if editor_property == null:
		return false
	add_property_editor(name, editor_property)
	return true


# --- 框架内部方法 ---

## 创建与资源路径 hint 匹配的 GF EditorProperty。
##
## Project Settings 本地化适配器也使用该工厂，确保包装可见标签时不会丢失专用控件。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param type: Godot 属性类型。
## [br]
## @param hint_type: Godot 属性 hint 或 GFResourcePathHint 常量。
## [br]
## @param hint_string: 资源基类或扩展名提示。
## [br]
## @return 匹配时返回专用 EditorProperty，否则返回 null。
static func create_editor_property(
	type: Variant.Type,
	hint_type: int,
	hint_string: String
) -> EditorProperty:
	if _GF_RESOURCE_PATH_EDITOR_PROPERTY.should_handle_property(type, hint_type, hint_string):
		var editor_property: EditorProperty = _GF_RESOURCE_PATH_EDITOR_PROPERTY.new()
		editor_property.call(
			&"setup",
			_GF_RESOURCE_PATH_EDITOR_PROPERTY.get_base_type_for_hint(hint_type, hint_string),
			true
		)
		return editor_property

	if _GF_RESOURCE_PATH_ARRAY_EDITOR_PROPERTY.should_handle_property(type, hint_type, hint_string):
		var array_editor_property: EditorProperty = _GF_RESOURCE_PATH_ARRAY_EDITOR_PROPERTY.new()
		array_editor_property.call(
			&"setup",
			_GF_RESOURCE_PATH_ARRAY_EDITOR_PROPERTY.get_base_type_for_hint(hint_type, hint_string),
			type,
			true
		)
		return array_editor_property
	return null
