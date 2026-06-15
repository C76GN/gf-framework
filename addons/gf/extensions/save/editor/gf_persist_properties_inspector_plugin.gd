@tool

# GFPersistPropertiesSource Inspector: 为属性白名单 Source 提供目标属性选择器。
extends EditorInspectorPlugin


# --- 常量 ---

const _GF_PERSIST_PROPERTIES_SOURCE_BASE = preload("res://addons/gf/extensions/save/core/gf_persist_properties_source.gd")
const _GF_PERSIST_PROPERTIES_EDITOR_PROPERTY = preload("res://addons/gf/extensions/save/editor/gf_persist_properties_editor_property.gd")


# --- Godot 回调方法 ---

func _can_handle(object: Object) -> bool:
	return can_handle_object(object)


func _parse_property(
	_object: Object,
	_type: Variant.Type,
	name: String,
	_hint_type: PropertyHint,
	_hint_string: String,
	_usage_flags: int,
	_wide: bool
) -> bool:
	if name != "properties":
		return false

	add_property_editor("properties", _GF_PERSIST_PROPERTIES_EDITOR_PROPERTY.new())
	return true


# --- 框架内部方法 ---

## 判断对象是否应由属性白名单 Inspector 处理。
## [br]
## @api framework_internal
## [br]
## @layer extensions/save/editor
## [br]
## @param object: 待判断对象。
## [br]
## @return 是否为 GFPersistPropertiesSource。
static func can_handle_object(object: Object) -> bool:
	return object is _GF_PERSIST_PROPERTIES_SOURCE_BASE
