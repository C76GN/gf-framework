## GFNetworkRequestResult: 网络请求关联的一次性只读终态。
##
## received 只表示收到匹配请求身份与 peer 的回复，不表示业务操作成功。
## 回复由关联器先完成有界传输值校验；结果保留隔离副本，读取时再次复制集合。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFNetworkRequestResult
extends RefCounted


# --- 常量 ---

## 已收到匹配的回复；不解释回复中的业务结果。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_RECEIVED: StringName = &"received"

## 发送入口返回错误，且请求尚未进入其他终态。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_SEND_FAILED: StringName = &"send_failed"

## 已达到本地单调截止时间。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_TIMED_OUT: StringName = &"timed_out"

## 调用方已取消本地等待；不代表服务器操作被撤销。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_CANCELLED: StringName = &"cancelled"

## 所属会话已关闭或被替换。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_SESSION_CLOSED: StringName = &"session_closed"

## 目标 peer 的连接已失效。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_PEER_DISCONNECTED: StringName = &"peer_disconnected"

## 所属关联器已释放或不再存在。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_DISPOSED: StringName = &"disposed"

## 请求未通过参数、会话或容量准入检查。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_REJECTED: StringName = &"rejected"

## 匹配身份的回复未通过有界传输值校验。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_INVALID_RESPONSE: StringName = &"invalid_response"


# --- 私有变量 ---

var _configured: bool = false
var _request_id: String = ""
var _peer_id: int = -1
var _status: StringName = STATUS_REJECTED
var _response: Variant = null
var _send_error: Error = OK


# --- 公共方法 ---

## 获取关联请求 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 请求 ID；尚未配置时为空。
func get_request_id() -> String:
	return _request_id


## 获取请求绑定的目标 peer。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 请求的目标 peer；尚未配置时为 -1。
func get_peer_id() -> int:
	return _peer_id


## 获取稳定终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: STATUS_* 常量之一；尚未配置时为 STATUS_REJECTED。
func get_status() -> StringName:
	return _status


## 检查是否收到匹配回复。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 已配置且状态为 received 时返回 true；不判断业务成功。
func is_successful() -> bool:
	return _configured and _status == STATUS_RECEIVED


## 获取回复的隔离副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 回复副本；非 received 终态或尚未配置时为 null。
## [br]
## @schema return: Variant，由关联器校验的有界纯传输值；不含 Object、Callable、Signal、RID、循环容器或非有限数，集合深拷贝。
func get_response() -> Variant:
	return GFVariantData.duplicate_variant(_response)


## 获取发送或准入阶段的错误码。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 关联器记录的发送或准入错误码；请求未发送也可能携带拒绝原因，无错误时为 OK。
func get_send_error() -> Error:
	return _send_error


# --- 层内方法 ---

## 一次性配置请求终态，只允许主线程调用。
##
## response 必须已由关联器完成传输值和容量校验。本方法只复制值，
## 不重复解析协议；只有 received 终态保留回复。重复配置不会改变结果。
## [br]
## @api layer_internal
## [br]
## @layer extensions/network
## [br]
## @since unreleased
## [br]
## @param request_id: 关联器分配的请求 ID。
## [br]
## @param peer_id: 请求绑定的目标 peer。
## [br]
## @param status: STATUS_* 常量之一。
## [br]
## @param response: 已通过关联器校验的回复值。
## [br]
## @schema response: Variant，有界且无 Object、Callable、Signal、RID、循环容器和非有限数的纯传输值；非 received 终态忽略。
## [br]
## @param send_error: 发送或准入阶段记录的 Godot 错误码，无错误时为 OK。
func configure_from_network_layer(
	request_id: String,
	peer_id: int,
	status: StringName,
	response: Variant = null,
	send_error: Error = OK
) -> void:
	if not Thread.is_main_thread() or _configured:
		return
	if status not in [
		STATUS_RECEIVED,
		STATUS_SEND_FAILED,
		STATUS_TIMED_OUT,
		STATUS_CANCELLED,
		STATUS_SESSION_CLOSED,
		STATUS_PEER_DISCONNECTED,
		STATUS_DISPOSED,
		STATUS_REJECTED,
		STATUS_INVALID_RESPONSE,
	]:
		return
	_request_id = request_id
	_peer_id = peer_id
	_status = status
	_response = GFVariantData.duplicate_variant(response) if status == STATUS_RECEIVED else null
	_send_error = send_error
	_configured = true
