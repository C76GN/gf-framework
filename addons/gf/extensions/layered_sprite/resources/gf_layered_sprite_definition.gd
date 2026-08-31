## GFLayeredSpriteDefinition：分层精灵的时间轴和层集合。
##
## 时间轴唯一拥有动画速度、循环和帧时长；各层变体只提供同拓扑的帧纹理。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 11.0.0
class_name GFLayeredSpriteDefinition
extends Resource


# --- 导出变量 ---

## 共享时间轴。其动画名称、帧数、帧时长和循环设置驱动全部层。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var timeline_frames: SpriteFrames = null

## 配置完成后使用的初始动画。为空时按动画名称稳定排序后选择第一项。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var default_animation: StringName = &""

## 分层定义集合。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var layers: Array[GFLayeredSpriteLayerDefinition] = []
