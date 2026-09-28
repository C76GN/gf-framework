@tool

## GFTouchControl2D: 触屏 Node2D 控件共享底座。
##
## 提供触点捕获、隐藏/离树/process mode 禁用释放、屏幕坐标到画布坐标转换和输入 handled 标记。
## 具体按钮、摇杆、滑条或项目自定义触屏控件仍负责自己的形状、输出和业务无关配置。
## 直接调用 set_process_input(false) 不会产生可拦截的 Node 禁用通知；调用方必须先 release()。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 8.0.0
class_name GFTouchControl2D
extends Node2D


# --- 常量 ---

## 表示当前没有被捕获的指针索引。
## [br]
## @api private
## [br]
const _NO_POINTER_ID: int = -1


# --- 私有变量 ---

## 当前捕获的触点索引；未捕获时为 _NO_POINTER_ID。
## [br]
## @api private
## [br]
var _active_touch_index: int = _NO_POINTER_ID


# --- Godot 生命周期方法 ---

func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		return
	if (
		what == Node.NOTIFICATION_DISABLED
		or (
			what == CanvasItem.NOTIFICATION_VISIBILITY_CHANGED
			and not is_visible_in_tree()
		)
	):
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

## 捕获指定触点；拒绝哨兵索引，已有捕获时仅允许同一触点继续匹配。
## [br]
## @api private
## [br]
func _try_capture_touch_index(touch_index: int) -> bool:
	if touch_index == _NO_POINTER_ID:
		return false
	if _active_touch_index == _NO_POINTER_ID:
		_active_touch_index = touch_index
		return true
	return _active_touch_index == touch_index


## 释放触点捕获；可选索引必须匹配当前捕获，省略或传哨兵值时释放任意当前捕获。
## [br]
## @api private
## [br]
func _release_touch_capture(touch_index: int = _NO_POINTER_ID) -> bool:
	if _active_touch_index == _NO_POINTER_ID:
		return false
	if touch_index != _NO_POINTER_ID and touch_index != _active_touch_index:
		return false
	_active_touch_index = _NO_POINTER_ID
	return true


## 检查给定触点索引是否等于当前捕获索引。
## [br]
## @api private
## [br]
func _touch_matches(touch_index: int) -> bool:
	return _active_touch_index == touch_index


## 将屏幕位置经当前 Viewport 的 canvas 逆变换换算到画布坐标；无 Viewport 时原样返回。
## [br]
## @api private
## [br]
func _screen_to_global_position(screen_position: Vector2) -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return screen_position
	return viewport.get_canvas_transform().affine_inverse() * screen_position


## 若存在当前 Viewport，将本次输入标记为已处理。
## [br]
## @api private
## [br]
func _mark_input_as_handled() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
