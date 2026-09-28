@tool

# GF Pattern2D Inspector: 为 GFPattern2D 提供网格化 cells 编辑器。
extends EditorInspectorPlugin


# --- 常量 ---

## 用于识别可由自定义网格属性编辑器处理的 Pattern2D 类型。
## [br]
## @api private
## [br]
const _GF_PATTERN_2D_BASE = preload("res://addons/gf/standard/foundation/math/gf_pattern_2d.gd")

## 提供 GFPattern2D.cells 网格编辑界面的 InspectorProperty 类型。
## [br]
## @api private
## [br]
const _GF_PATTERN_2D_EDITOR_PROPERTY = preload("res://addons/gf/standard/foundation/math/editor/gf_pattern_2d_editor_property.gd")


# --- Godot 回调方法 ---

func _can_handle(object: Object) -> bool:
	return object is _GF_PATTERN_2D_BASE


func _parse_property(
	_object: Object,
	_type: Variant.Type,
	name: String,
	_hint_type: PropertyHint,
	_hint_string: String,
	_usage_flags: int,
	_wide: bool
) -> bool:
	if name != "cells":
		return false

	add_property_editor("cells", _GF_PATTERN_2D_EDITOR_PROPERTY.new())
	return true
