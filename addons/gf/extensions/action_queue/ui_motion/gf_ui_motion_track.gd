@tool

## GFUIMotionTrack: 在页面进入、退出或会话时钟上安排效果与标记。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFUIMotionTrack
extends Resource


# --- 枚举 ---

## 定义时刻和相对时长的参考区间。
## [br]
## @api public
## [br]
## @since unreleased
enum Clock {
	## 以新页入场区间为基准。
	ENTER,
	## 以旧页退出区间为基准。
	EXIT,
	## 以会话起点、以秒为单位安排动作。
	SESSION,
}


# --- 导出变量 ---

## 轨道开始时发送的标识。单独填写可通知页面播放自己的原生动画。
## [br]
## @api public
## [br]
## @since unreleased
@export var cue: StringName

## 从播放调用的绑定表中查找此目标；目标数组依次错峰。
## [br]
## @api public
## [br]
## @since unreleased
@export var target: StringName = &"incoming"

## 选择时间参考系。
## [br]
## @api public
## [br]
## @since unreleased
@export var clock: Clock = Clock.ENTER

## 页时钟下为 0 到 1 的起始比例，会话时钟下直接使用 delay_seconds。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(0, 1, 0.001) var at: float = 0.0

## 相对触发点的额外延迟，单位秒。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(0, 60, 0.001, "or_greater") var delay_seconds: float = 0.0

## 局部时长，可按参考区间比例或秒解释。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(0, 60, 0.001, "or_greater") var duration: float = 1.0

## 在页时钟中用参考页时长乘 duration。会话时钟始终使用秒。
## [br]
## @api public
## [br]
## @since unreleased
@export var relative_duration: bool = true

## 对目标数组每个后继元素增加的时间偏移，单位秒。
## [br]
## @api public
## [br]
## @since unreleased
@export_range(0, 5, 0.001, "or_greater") var stagger_seconds: float = 0.0

## 插值使用的 Godot 曲线类型。
## [br]
## @api public
## [br]
## @since unreleased
@export var transition: Tween.TransitionType = Tween.TRANS_LINEAR

## 插值曲线的缓入缓出方向。
## [br]
## @api public
## [br]
## @since unreleased
@export var easing: Tween.EaseType = Tween.EASE_IN_OUT

## 可选进度曲线，存在时覆盖原生缓动并允许中途超调。
## [br]
## @api public
## [br]
## @since unreleased
@export var curve: Curve

## 可复用的效果。留空并填写 cue 时只发送瞬时标记，目标及错峰照常生效。
## [br]
## @api public
## [br]
## @since unreleased
@export var effect: GFUIMotionEffect
