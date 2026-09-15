## GFStorageRevisionResult: 一次 committed revision 查询的不可变结果。
##
## revision 是只用于相等比较的不透明字符串，不表示时间顺序或内容完整性。
## 通过工厂创建结果；未使用工厂创建的实例保持 INVALID_REQUEST 失败状态。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFStorageRevisionResult
extends RefCounted


# --- 枚举 ---

## committed revision 的可用性与失败分类。
## [br]
## @api public
## [br]
## @since unreleased
enum Status {
	## 已取得成功提交对应的非空 revision。
	AVAILABLE,
	## 目标不存在 committed payload。
	NOT_FOUND,
	## 当前存储布局不支持 committed revision。
	UNSUPPORTED,
	## 查询参数或结果工厂参数无效。
	INVALID_REQUEST,
	## 当前生命周期或存储准入不可用。
	UNAVAILABLE,
	## 同 family 操作或恢复尚未收敛。
	BUSY,
	## 存储身份、提交状态或事务证据损坏。
	CORRUPT,
	## 底层存储 I/O 失败。
	IO_FAILED,
}


# --- 私有变量 ---

var _status: Status = Status.INVALID_REQUEST
var _error_code: Error = ERR_INVALID_PARAMETER
var _revision: String = ""


# --- 公共方法 ---

## 创建包含 committed revision 的成功结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param revision: 非空不透明字符串；原样保存，不裁剪或解析。
## [br]
## @return AVAILABLE 结果；空字符串返回 INVALID_REQUEST 与 ERR_INVALID_PARAMETER。
static func available(revision: String) -> GFStorageRevisionResult:
	if revision.is_empty():
		return failure(Status.INVALID_REQUEST, ERR_INVALID_PARAMETER)
	var result: GFStorageRevisionResult = GFStorageRevisionResult.new()
	result._status = Status.AVAILABLE
	result._error_code = OK
	result._revision = revision
	return result


## 创建不包含 revision 的失败结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param status: 除 AVAILABLE 外的有效 Status。
## [br]
## @param error: 非 OK 的 Godot Error 码。
## [br]
## @return 失败结果；无效 status 或 OK 归一为 INVALID_REQUEST 与 ERR_INVALID_PARAMETER。
static func failure(status: Status, error: Error) -> GFStorageRevisionResult:
	var result: GFStorageRevisionResult = GFStorageRevisionResult.new()
	if status == Status.AVAILABLE or not Status.values().has(status) or error == OK:
		return result
	result._status = status
	result._error_code = error
	return result


## 检查是否取得可用的 committed revision。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 仅 AVAILABLE、OK 与非空 revision 同时成立时返回 true。
func is_successful() -> bool:
	return _status == Status.AVAILABLE and _error_code == OK and not _revision.is_empty()


## 获取查询的 Godot Error 码。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功时为 OK；失败时为非 OK 错误码。
func get_error_code() -> Error:
	return _error_code


## 获取 revision 的可用性或失败分类。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Status 枚举值。
func get_status() -> Status:
	return _status


## 获取只用于相等比较的 committed revision。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功时为原始 revision；失败时为空字符串。
func get_revision() -> String:
	return _revision


## 创建不含物理路径的独立结果字典。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 修改返回字典不会改变当前结果或其他字典副本。
## [br]
## @schema return: 精确 Dictionary，包含 status: int (Status)、error_code: int (Error)、revision: String 三个字段。
func to_dict() -> Dictionary:
	return {
		"status": int(_status),
		"error_code": int(_error_code),
		"revision": _revision,
	}
