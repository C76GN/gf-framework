@tool

## GFTouchControl2D: 触屏 Node2D 控件共享底座。
##
## 提供触点捕获、隐藏/离树释放、屏幕坐标到画布坐标转换和输入 handled 标记。
## 具体按钮、摇杆、滑条或项目自定义触屏控件仍负责自己的形状、输出和业务无关配置。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 8.0.0
class_name GFTouchControl2D
extends Node2D


# --- 常量 ---

const _NO_POINTER_ID: int = -1


# --- 私有变量 ---

var _active_touch_index: int = _NO_POINTER_ID


# --- Godot 生命周期方法 ---

func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		return
	if what == CanvasItem.NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		release()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	release()


# --- 公共方法 ---

## 手动释放触屏控件。
## [br]
## 子类应重写该方法并清理自己的输出状态；底座默认只释放触点捕获。
## [br]
## @api public
## [br]
## @since 8.0.0
func release() -> void:
	var _released_touch: bool = _release_touch_capture()


## 检查当前是否捕获了触点。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 有活动触点捕获时返回 true。
func is_touch_active() -> bool:
	return _active_touch_index != _NO_POINTER_ID


## 获取当前活动触点 index。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前活动触点 index；没有捕获时返回 -1。
func get_active_touch_index() -> int:
	return _active_touch_index


# --- 私有/辅助方法 ---

func _try_capture_touch_index(touch_index: int) -> bool:
	if _active_touch_index == _NO_POINTER_ID:
		_active_touch_index = touch_index
		return true
	return _active_touch_index == touch_index


func _release_touch_capture(touch_index: int = _NO_POINTER_ID) -> bool:
	if _active_touch_index == _NO_POINTER_ID:
		return false
	if touch_index != _NO_POINTER_ID and touch_index != _active_touch_index:
		return false
	_active_touch_index = _NO_POINTER_ID
	return true


func _touch_matches(touch_index: int) -> bool:
	return _active_touch_index == touch_index


func _screen_to_global_position(screen_position: Vector2) -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return screen_position
	return viewport.get_canvas_transform().affine_inverse() * screen_position


func _mark_input_as_handled() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
