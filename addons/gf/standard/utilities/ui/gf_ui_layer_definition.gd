## GFUILayerDefinition: UI 逻辑层定义。
##
## 将稳定逻辑层 ID、Godot CanvasLayer 排序值和默认遮挡策略解耦，
## 供项目按窗口区域、导航域或显示优先级扩展 GFUIUtility。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 8.1.0
class_name GFUILayerDefinition
extends Resource


# --- 公共变量 ---

## 稳定逻辑层 ID。必须为非负整数。
## [br]
## @api public
## [br]
## @since 8.1.0
@export var layer_id: int = -1

## 用于诊断和 CanvasLayer 节点命名的稳定名称。
## [br]
## @api public
## [br]
## @since 8.1.0
@export var display_name: StringName = &""

## 对应 Godot CanvasLayer.layer 的显示排序值。
## [br]
## @api public
## [br]
## @since 8.1.0
@export var canvas_layer: int = 0

## 新面板未显式指定 hide_under 时，是否隐藏同一逻辑层中的下方页面。
## [br]
## @api public
## [br]
## @since 8.1.0
@export var auto_hide_under: bool = true


# --- 公共方法 ---

## 配置层定义。
## [br]
## @api public
## [br]
## @since 8.1.0
## [br]
## @param next_layer_id: 稳定逻辑层 ID。
## [br]
## @param next_display_name: 稳定显示名。
## [br]
## @param next_canvas_layer: Godot CanvasLayer 排序值。
## [br]
## @param next_auto_hide_under: 默认是否隐藏同栈下方页面。
## [br]
## @return 当前层定义。
func configure(
	next_layer_id: int,
	next_display_name: StringName,
	next_canvas_layer: int,
	next_auto_hide_under: bool = true
) -> GFUILayerDefinition:
	layer_id = next_layer_id
	display_name = next_display_name
	canvas_layer = next_canvas_layer
	auto_hide_under = next_auto_hide_under
	return self


## 检查层定义是否可注册。
## [br]
## @api public
## [br]
## @since 8.1.0
## [br]
## @return 逻辑层 ID 非负且显示名非空时返回 true。
func is_valid() -> bool:
	return layer_id >= 0 and display_name != &""


## 创建不共享可变状态的定义副本。
## [br]
## @api public
## [br]
## @since 8.1.0
## [br]
## @return 当前层定义的独立副本。
func duplicate_definition() -> GFUILayerDefinition:
	var result: GFUILayerDefinition = GFUILayerDefinition.new()
	result.layer_id = layer_id
	result.display_name = display_name
	result.canvas_layer = canvas_layer
	result.auto_hide_under = auto_hide_under
	return result
