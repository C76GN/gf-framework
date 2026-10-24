## 单次资源请求的终态事实；scope 关闭后成功事实保留，但句柄不再可用。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFAssetLoadResult
extends RefCounted


# --- 枚举 ---

## 请求终态。
## [br]
## @api public
## [br]
## @since unreleased
enum Status {
	## 资源已成功交付到请求 scope；之后释放句柄不改变此终态。
	SUCCEEDED,
	## 请求未取得可交付句柄，具体原因由错误码表达。
	FAILED,
	## 请求已取消，不代表底层共享加载已经停止。
	CANCELLED,
}


# --- 私有变量 ---

## 只在构造时写入的终态。
## [br]
## @api private
var _status: Status = Status.FAILED

## 与请求 scope 共享的同一个句柄，不产生额外租约。
## [br]
## @api private
var _handle: GFAssetHandle

## 请求错误码。
## [br]
## @api private
var _error_code: Error = FAILED


# --- Godot 生命周期方法 ---

## 初始化终态。
## [br]
## @api framework_internal
## [br]
## @param status: 请求终态。
## [br]
## @param handle: 成功句柄。
## [br]
## @param error_code: 错误码。
func _init(
	status: Status = Status.FAILED,
	handle: GFAssetHandle = null,
	error_code: Error = FAILED
) -> void:
	_status = status
	_handle = handle
	_error_code = error_code


# --- 公共方法 ---

## 返回请求是否成功；之后关闭 scope 不改写此历史事实。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功时为 true。
func is_successful() -> bool:
	return _status == Status.SUCCEEDED


## 返回请求终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 请求终态。
func get_status() -> Status:
	return _status


## 返回同一 scope 所拥有的句柄。重复调用不增加引用计数。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功句柄或 null；scope 已关闭时句柄已释放。
func get_handle() -> GFAssetHandle:
	return _handle


## 返回错误码。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功为 OK，取消为 ERR_SKIP，其他错误为失败码。
func get_error_code() -> Error:
	return _error_code
