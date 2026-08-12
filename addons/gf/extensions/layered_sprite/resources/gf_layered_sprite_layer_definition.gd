## GFLayeredSpriteLayerDefinition：分层精灵的单层定义。
##
## 层定义只描述稳定身份、绘制属性和可选帧变体；具体业务含义由项目自行解释。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFLayeredSpriteLayerDefinition
extends Resource


# --- 导出变量 ---

## 层稳定 ID。同一定义内必须唯一、非空且无首尾空白。
## [br]
## @api public
## [br]
## @since unreleased
@export var layer_id: StringName = &""

## 初始变体 ID，必须引用 [member variants] 中的条目。
## [br]
## @api public
## [br]
## @since unreleased
@export var default_variant_id: StringName = &""

## 同一层可切换的帧变体。
## [br]
## @api public
## [br]
## @since unreleased
@export var variants: Array[GFLayeredSpriteVariant] = []

## 相对节点原点的绘制偏移。
## [br]
## @api public
## [br]
## @since unreleased
@export var offset: Vector2 = Vector2.ZERO

## 初始调制颜色。
## [br]
## @api public
## [br]
## @since unreleased
@export var modulate: Color = Color.WHITE

## 初始可见性。
## [br]
## @api public
## [br]
## @since unreleased
@export var visible: bool = true

## 层内绘制顺序；数值较小的层先绘制。相同值保持定义顺序。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(-4096, 4096, 1) var draw_order: int = 0
