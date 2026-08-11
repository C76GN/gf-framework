## GFLayeredSpriteVariant：分层精灵单层的帧资源变体。
##
## 变体只以稳定 ID 关联一组 [SpriteFrames]，不包含服装、装备或角色等业务语义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFLayeredSpriteVariant
extends Resource


# --- 导出变量 ---

## 变体稳定 ID。同一层内必须唯一、非空且无首尾空白。
## [br]
## @api public
## [br]
## @since unreleased
@export var variant_id: StringName = &""

## 该变体的帧资源。动画名称和每个动画的帧数必须与时间轴完全一致。
## [br]
## @api public
## [br]
## @since unreleased
@export var sprite_frames: SpriteFrames = null
