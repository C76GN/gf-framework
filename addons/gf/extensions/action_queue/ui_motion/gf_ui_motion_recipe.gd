@tool

## GFUIMotionRecipe: 描述同一宿主的双页与局部动效，引用目标由每次播放调用显式提供。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFUIMotionRecipe
extends Resource


# --- 导出变量 ---

## 新页开始进入前的等待秒数。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(0, 60, 0.001, "or_greater") var enter_delay: float = 0.0

## 新页入场时长，独立于页内轨道和旧页。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(0, 60, 0.001, "or_greater") var enter_seconds: float = 0.4

## 旧页开始退出前的等待秒数。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(0, 60, 0.001, "or_greater") var exit_delay: float = 0.0

## 旧页退出时长，独立于新页。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(0, 60, 0.001, "or_greater") var exit_seconds: float = 0.3

## 同一时刻按声明顺序触发，各目标的局部持续时间可超过页时钟。
## [br]
## @api public
## [br]
## @since unreleased
@export var tracks: Array[GFUIMotionTrack] = []


# --- 公共方法 ---

## 深复制配方内嵌的轨道和效果，对外部资源保留显式引用。
## [br]
## @api public
## [br]
## @return: 可独立调整的配方副本；资源复制失败时为空。
## [br]
## @since unreleased
func duplicate_recipe() -> GFUIMotionRecipe:
	var resource: Resource = duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	if resource is GFUIMotionRecipe:
		var copy: GFUIMotionRecipe = resource
		return copy
	return null
