## GFPointerCapture: 单指针捕获状态句柄。
##
## 用于触屏控件、虚拟光标或拖放控制器记录当前由哪个 pointer/touch id
## 拥有交互。它只保存捕获身份，不读取输入事件，也不规定 UI 行为。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 8.0.0
class_name GFPointerCapture
extends RefCounted


# --- 常量 ---

## 无活动指针。
## [br]
## @api public
## [br]
## @since 8.0.0
const NO_POINTER_ID: int = -1


# --- 公共变量 ---

## 当前捕获的指针 ID；没有捕获时为 -1。
## [br]
## @api public
## [br]
## @since 8.0.0
var active_pointer_id: int = NO_POINTER_ID


# --- 公共方法 ---

## 检查是否已有活动捕获。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 有活动捕获时返回 true。
func is_active() -> bool:
	return active_pointer_id != NO_POINTER_ID


## 检查传入指针是否匹配当前捕获。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param pointer_id: 要检查的指针 ID。
## [br]
## @return 匹配当前捕获时返回 true。
func matches(pointer_id: int) -> bool:
	return active_pointer_id == pointer_id


## 尝试捕获指针。
## [br]
## 若当前没有捕获，则记录传入指针；若已经捕获同一指针，也视为成功。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param pointer_id: 要捕获的指针 ID。
## [br]
## @return 捕获成功或已经捕获同一指针时返回 true。
func try_capture(pointer_id: int) -> bool:
	if active_pointer_id == NO_POINTER_ID:
		active_pointer_id = pointer_id
		return true
	return active_pointer_id == pointer_id


## 释放当前捕获。
## [br]
## `pointer_id` 为 -1 时释放任意当前捕获；否则只释放匹配的指针。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param pointer_id: 要释放的指针 ID；-1 表示释放任意当前捕获。
## [br]
## @return 实际释放了活动捕获时返回 true。
func release(pointer_id: int = NO_POINTER_ID) -> bool:
	if active_pointer_id == NO_POINTER_ID:
		return false
	if pointer_id != NO_POINTER_ID and pointer_id != active_pointer_id:
		return false
	active_pointer_id = NO_POINTER_ID
	return true


## 强制清空捕获状态。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 实际清空了活动捕获时返回 true。
func reset() -> bool:
	return release(NO_POINTER_ID)


## 转换为调试字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 捕获状态快照。
## [br]
## @schema return: Dictionary，包含 active_pointer_id 和 active。
func to_dictionary() -> Dictionary:
	return {
		"active_pointer_id": active_pointer_id,
		"active": is_active(),
	}
