## GFStorageCatalogResult: 单次 Storage logical catalog 查询的不可变结果。
##
## 完整性只相对于发起查询时的 directory、extension、recursive 与 logical depth 范围。
## 成功但不完整表示 max_file_count 实际截断结果；失败不携带部分文件。
## 文件存在不代表 payload 已通过解码或完整性校验，也不提供跨 writer 快照。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFStorageCatalogResult
extends RefCounted


# --- 枚举 ---

## 查询失败的阶段分类；具体底层原因由 Error 码补充。
## [br]
## @api public
## [br]
## @since unreleased
enum FailureKind {
	## 查询成功，可能受结果数量上限截断。
	NONE,
	## logical selector 或 options 不满足请求契约。
	INVALID_REQUEST,
	## Utility 已关闭准入，或 drain 期间生命周期与 helper 已更换。
	UNAVAILABLE,
	## drain 后仍有本 Utility 的异步工作或文件锁。
	BUSY,
	## Storage layout 准备或首次恢复失败。
	PREPARATION_FAILED,
	## drain 后的全 catalog 事务恢复失败，包括无法验证恢复所需的 catalog。
	RECOVERY_FAILED,
	## 恢复后的 catalog 枚举或结果验证失败。
	CATALOG_FAILED,
}


# --- 私有变量 ---

var _configured: bool = false
var _error_code: Error = FAILED
var _failure_kind: FailureKind = FailureKind.PREPARATION_FAILED
var _complete: bool = false
var _files: PackedStringArray = PackedStringArray()


# --- 公共方法 ---

## 检查本次查询是否成功完成；结果数量受限仍属于成功。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已配置且 Error 为 OK 时返回 true。
func is_successful() -> bool:
	return _configured and _error_code == OK


## 获取本次查询的 Error 码。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功为 OK；未配置实例为 FAILED。
func get_error_code() -> Error:
	return _error_code


## 获取失败阶段；它不替代底层 Error，也不证明损坏的具体物理成员。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功为 FailureKind.NONE。
func get_failure_kind() -> FailureKind:
	return _failure_kind


## 检查本次 selector 范围内的 committed logical identity 是否已全部返回。
##
## 成功但 false 只表示 max_file_count 实际省略条目。深度、递归和扩展名是查询范围，
## 范围之外的文件不影响此值。不得用有限范围的 true 推断整个 root 中的文件已删除。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功且未截断时为 true；失败或未配置时为 false。
func is_complete() -> bool:
	return is_successful() and _complete


## 获取按 logical identity 排序的文件副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 无重复 logical identity 的隔离数组；失败为空。
func get_files() -> PackedStringArray:
	return _files.duplicate()


## 创建只包含查询终态与 logical files 的隔离字典。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 不包含物理路径、payload 或 revision 的查询结果。
## [br]
## @schema return: Dictionary，精确包含 ok: bool、error_code: int (Error)、failure_kind: int (FailureKind)、complete: bool 和 files: PackedStringArray；files 是隔离副本，完整性相对于原查询 selector。
func to_dict() -> Dictionary:
	return {
		"ok": is_successful(),
		"error_code": int(_error_code),
		"failure_kind": int(_failure_kind),
		"complete": is_complete(),
		"files": get_files(),
	}


# --- 框架内部方法 ---

## 由 Storage 一次性写入合法终态；输入文件数组会复制。
## [br]
## @api framework_internal
## [br]
## @param error_code: 查询 Error。
## [br]
## @param failure_kind: 失败阶段。
## [br]
## @param files: 已排序、无重复的 portable logical files。
## [br]
## @param complete: selector 范围内是否未发生结果截断。
## [br]
## @return 首次合法配置成功时返回 true；失败不修改实例。
func configure_for_framework(
	error_code: Error,
	failure_kind: FailureKind,
	files: PackedStringArray = PackedStringArray(),
	complete: bool = false
) -> bool:
	if _configured or not FailureKind.values().has(int(failure_kind)):
		return false
	if (error_code == OK) != (failure_kind == FailureKind.NONE):
		return false
	if error_code != OK and (complete or not files.is_empty()):
		return false
	if error_code == OK and not complete and files.is_empty():
		return false
	if failure_kind == FailureKind.INVALID_REQUEST and error_code != ERR_INVALID_PARAMETER:
		return false
	if failure_kind == FailureKind.UNAVAILABLE and error_code != ERR_UNAVAILABLE:
		return false
	if failure_kind == FailureKind.BUSY and error_code != ERR_BUSY:
		return false
	var previous_file: String = ""
	for file_name: String in files:
		if (
			not GFStorageFamilyStore.is_valid_logical_file_path_for_framework(file_name)
			or (not previous_file.is_empty() and file_name <= previous_file)
		):
			return false
		previous_file = file_name
	_error_code = error_code
	_failure_kind = failure_kind
	_files = files.duplicate()
	_complete = complete
	_configured = true
	return true
