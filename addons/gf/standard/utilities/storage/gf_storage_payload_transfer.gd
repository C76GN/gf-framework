## GFStoragePayloadTransfer: 异步 Storage 写入载荷的单所有者传递句柄。
##
## 调用方通过静态 `take_ownership()` 把 Dictionary 的逻辑唯一所有权移交给新句柄。
## 移交不会深拷贝；调用成功后，调用方必须永久放弃源 Dictionary 以及它的全部
## 嵌套 alias。失败操作只通过 `GFStorageAsyncOperation.reclaim_failed_payload()`
## 归还同一 opaque 句柄用于重试，任何阶段都不公开 payload getter。
## [br]
## 首次合法 Storage 请求会把句柄绑定到一个 Storage 实例、规范文件名、冻结的
## target file-family identity 和 codec options。同一绑定可取得多个只读 attempt
## lease，用于 timeout 后仍有旧 attempt 运行时复用同一逻辑快照。最终调用
## `release()`；若仍有活动 attempt，载荷会在最后一个 attempt 结束后才清空。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFStoragePayloadTransfer
extends RefCounted


# --- 枚举 ---

## 传递句柄的所有权状态。
## [br]
## @api public
## [br]
## @since unreleased
enum State {
	## 尚未接收载荷。
	EMPTY,
	## 已接收载荷，尚未被 Storage claim。
	READY,
	## 已由 Storage claim，可由同一冻结绑定建立 attempt。
	CLAIMED,
	## 已请求释放，等待活动 attempt 收敛。
	RELEASE_PENDING,
	## 载荷已清空，句柄不可再次使用。
	RELEASED,
}


# --- 私有变量 ---

var _state: State = State.EMPTY
var _payload: Dictionary = {}
var _bound_storage_id: int = 0
var _bound_file_name: String = ""
var _bound_target_file_key: String = ""
var _bound_codec_options: Dictionary = {}
var _next_attempt_id: int = 1
var _active_attempt_ids: Dictionary = {}


# --- 公共方法 ---

## 创建句柄并接收 Dictionary 的逻辑唯一所有权。
##
## 此方法不会深拷贝。返回句柄后，调用方必须立即并永久放弃源 Dictionary
## 以及所有嵌套 alias；继续读取或修改这些 alias 会破坏跨线程快照不变量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param payload: 要移交的纯 Variant Dictionary。
## [br]
## @schema payload: Dictionary whose source and nested aliases are abandoned after a successful ownership transfer.
## [br]
## @return 持有 payload 的新 opaque transfer。
static func take_ownership(payload: Dictionary) -> GFStoragePayloadTransfer:
	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.new()
	transfer._payload = payload
	transfer._state = State.READY
	return transfer


## 获取当前所有权状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `State` 枚举值。
func get_state() -> State:
	return _state


## 检查句柄是否已被 Storage claim。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return CLAIMED 或 RELEASE_PENDING 时返回 true。
func is_claimed() -> bool:
	return _state == State.CLAIMED or _state == State.RELEASE_PENDING


## 检查载荷是否已最终释放。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已清空且不可复用时返回 true。
func is_released() -> bool:
	return _state == State.RELEASED


## 获取当前活动 attempt 数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已取得且尚未完成的 attempt lease 数量。
func get_active_attempt_count() -> int:
	return _active_attempt_ids.size()


## 显式释放载荷所有权。
##
## 若仍有活动 attempt，本方法只进入 RELEASE_PENDING；最后一个 attempt 完成后
## 才真正清空载荷。释放请求只能成功一次。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 首次接受释放请求时返回 true。
func release() -> bool:
	if _state != State.READY and _state != State.CLAIMED:
		return false
	if _active_attempt_ids.is_empty():
		_release_payload()
	else:
		_state = State.RELEASE_PENDING
	return true


# --- 框架内部方法 ---

## 为一次 Storage 写入取得只读 attempt lease。
##
## 首次调用冻结 Storage、文件名、target file-family identity 和 codec options；
## 后续只接受完全相同的绑定。
## 返回值中的 payload 仅供 Storage worker 使用，不得向公共结果或信号泄露。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param storage_id: 发起请求的 Storage 实例 ID。
## [br]
## @param file_name: 规范化文件名。
## [br]
## @param target_file_key: 已冻结 target family 的 canonical final-path identity。
## [br]
## @param codec_options: 当前请求的冻结 codec 选项。
## [br]
## @schema codec_options: Dictionary with stable String keys and immutable codec option values.
## [br]
## @return 包含 ok、attempt_id 和内部 payload 引用的 Dictionary。
## [br]
## @schema return: Internal Dictionary with ok, attempt_id, and payload fields.
func begin_attempt_for_framework(
	storage_id: int,
	file_name: String,
	target_file_key: String,
	codec_options: Dictionary
) -> Dictionary:
	if storage_id == 0 or file_name.is_empty() or target_file_key.is_empty():
		return {"ok": false}
	if _state == State.READY:
		_bound_storage_id = storage_id
		_bound_file_name = file_name
		_bound_target_file_key = target_file_key
		_bound_codec_options = codec_options.duplicate(true)
		_state = State.CLAIMED
	elif (
		_state != State.CLAIMED
		or _bound_storage_id != storage_id
		or _bound_file_name != file_name
		or _bound_target_file_key != target_file_key
		or _bound_codec_options != codec_options
	):
		return {"ok": false}

	var attempt_id: int = _next_attempt_id
	_next_attempt_id += 1
	if _next_attempt_id <= 0:
		_next_attempt_id = 1
	while _active_attempt_ids.has(attempt_id):
		attempt_id = _next_attempt_id
		_next_attempt_id += 1
		if _next_attempt_id <= 0:
			_next_attempt_id = 1
	_active_attempt_ids[attempt_id] = true
	return {
		"ok": true,
		"attempt_id": attempt_id,
		"payload": _payload,
	}


## 结束一次 Storage attempt lease。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param attempt_id: begin_attempt_for_framework() 分配的 attempt ID。
## [br]
## @return 首次结束活动 attempt 时返回 true。
func finish_attempt_for_framework(attempt_id: int) -> bool:
	if attempt_id <= 0 or not _active_attempt_ids.has(attempt_id):
		return false
	var _erased: bool = _active_attempt_ids.erase(attempt_id)
	if _state == State.RELEASE_PENDING and _active_attempt_ids.is_empty():
		_release_payload()
	return true


# --- 私有/辅助方法 ---

func _release_payload() -> void:
	_payload = {}
	_bound_codec_options.clear()
	_bound_storage_id = 0
	_bound_file_name = ""
	_bound_target_file_key = ""
	_state = State.RELEASED
