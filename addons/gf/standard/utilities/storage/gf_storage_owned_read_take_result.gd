## GFStorageOwnedReadTakeResult: 一次独占读取领取的结果。
##
## SUCCESS 时持有从句柄移交的完整读取结果，不复制业务载荷。重复调用
## `get_read_result()` 返回同一对象；此后的引用共享由领取方负责。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFStorageOwnedReadTakeResult
extends RefCounted


# --- 枚举 ---

## 领取结果的闭合分类，成功的空载荷与失败明确分离。
## [br]
## @api public
## [br]
## @since unreleased
enum Status {
	## 本次调用取得完整读取结果。
	SUCCESS,
	## caller 尚未完成，稍后可以再次领取。
	NOT_READY,
	## 结果已经被同一句柄的另一调用领取。
	ALREADY_TAKEN,
	## 句柄已经放弃领取权。
	RELEASED,
	## caller 已失败或取消，没有可领取结果。
	FAILED,
	## 句柄未绑定到合法请求。
	INVALID,
	## 领取必须在主线程执行；本次调用未改变句柄。
	WRONG_THREAD,
}


# --- 私有变量 ---

var _configured: bool = false
var _status: Status = Status.INVALID
var _read_result: GFStorageReadResult = null


# --- 公共方法 ---

## 获取本次领取的状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 领取状态；手动构造的实例返回 INVALID。
func get_status() -> Status:
	return _status


## 检查本次调用是否取得读取结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 仅 SUCCESS 时返回 true，成功的空 Dictionary 同样为 true。
func is_ok() -> bool:
	return _status == Status.SUCCESS


## 获取已经移交给领取方的完整读取结果。
##
## 返回同一个可变对象，不执行复制。句柄释放、Utility dispose 或原 owner
## 释放均不会撤销此对象；领取方自行管理后续引用。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return SUCCESS 时返回完整结果，其他状态返回 null。
func get_read_result() -> GFStorageReadResult:
	return _read_result


# --- 框架内部方法 ---

## 一次性接收领取状态与已移交的读取结果。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param status: 闭合的领取状态。
## [br]
## @param read_result: 仅 SUCCESS 接收非空成功读取结果；直接保存，不复制。
## [br]
## @return 首次配置成功时返回 true。
func configure_for_framework(
	status: Status,
	read_result: GFStorageReadResult = null
) -> bool:
	if _configured or not Status.values().has(int(status)):
		return false
	if status == Status.SUCCESS:
		if read_result == null or not read_result.ok or read_result.error_code != OK:
			return false
	elif read_result != null:
		return false
	_configured = true
	_status = status
	_read_result = read_result
	return true
