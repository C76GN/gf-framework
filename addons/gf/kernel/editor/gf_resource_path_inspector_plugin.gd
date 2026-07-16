@tool

# GFResourcePathInspectorPlugin: 为资源路径字符串提供 ResourcePicker Inspector。
extends EditorInspectorPlugin


# --- 常量 ---

const _GF_RESOURCE_PATH_EDITOR_PROPERTY = preload("res://addons/gf/kernel/editor/gf_resource_path_editor_property.gd")
const _GF_RESOURCE_PATH_ARRAY_EDITOR_PROPERTY = preload("res://addons/gf/kernel/editor/gf_resource_path_array_editor_property.gd")


# --- Godot 回调方法 ---

func _can_handle(object: Object) -> bool:
	return object != null


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
