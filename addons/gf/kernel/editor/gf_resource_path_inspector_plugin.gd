@tool

# GFResourcePathInspectorPlugin: 为资源路径字符串提供 ResourcePicker Inspector。
extends EditorInspectorPlugin


# --- 常量 ---

const _GF_RESOURCE_PATH_EDITOR_PROPERTY = preload("res://addons/gf/kernel/editor/gf_resource_path_editor_property.gd")


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
	if not _GF_RESOURCE_PATH_EDITOR_PROPERTY.should_handle_property(type, hint_type, hint_string):
		return false

	var editor_property: EditorProperty = _GF_RESOURCE_PATH_EDITOR_PROPERTY.new()
	editor_property.call(
		&"setup",
		_GF_RESOURCE_PATH_EDITOR_PROPERTY.get_base_type_for_hint(hint_type, hint_string),
		true
	)
	add_property_editor(name, editor_property)
	return true
