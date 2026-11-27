@tool

## GFUIMotionBinding: 一次目标绑定的采样和回收操作。每个目标及播放会话有独立实例。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFUIMotionBinding
extends RefCounted


# --- 枚举 ---

## 会话结束原因。
## [br]
## @api public
## [br]
## @since unreleased
enum EndReason {
	## 自然走到最后一条轨道的末端。
	COMPLETED,
	## 调用方直接提交终态。
	FINISHED,
	## 会话中断，或旧页交还路由历史，恢复本绑定的初始姿态。
	CANCELLED,
	## 另一播放器已接管属性。释放临时资源并保留当前姿态。
	REPLACED,
}


# --- 公共变量 ---

## 接受一个经缓动的局部进度。按相同进度重采样时应得到相同姿态。
## [br]
## @api public
## [br]
## @since unreleased
var sample: Callable

## 可选结束钩子，接受 EndReason，释放本实例占有的资源。
## [br]
## @api public
## [br]
## @since unreleased
var release: Callable

## 可选的实播动作。按轨道开始时执行一次，结束时释放；含实播动作的配方不接受拖动定位。
## [br]
## @api public
## [br]
## @since unreleased
var action: GFVisualAction


# --- Godot 生命周期方法 ---

func _init(sample_callback: Callable = Callable(), release_callback: Callable = Callable()) -> void:
	sample = sample_callback
	release = release_callback
