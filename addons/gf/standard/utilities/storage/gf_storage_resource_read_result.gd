## GFStorageResourceReadResult: Resource 及其实际读取来源 revision 的不可变配对结果。
##
## 结果保存原 Resource 对象引用，不复制或冻结 Resource 的运行时属性。
## committed revision 描述读取时的存储来源，不随 Resource 后续修改而变化。
## 通过工厂创建结果；失败不保留 Resource 或 committed revision。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFStorageResourceReadResult
extends RefCounted


# --- 私有变量 ---

var _error_code: Error = ERR_INVALID_PARAMETER
var _resource: Resource = null
var _committed_revision: GFStorageRevisionResult = null


# --- 公共方法 ---

## 创建 Resource 与成功 committed revision 的配对结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param resource: 读取到的非 null Resource；保存同一对象引用。
## [br]
## @param revision: 本次读取对应的成功 revision 结果。
## [br]
## @return 成功配对；任一参数无效时返回 ERR_INVALID_PARAMETER 且不保留参数引用。
static func success(
	resource: Resource,
	revision: GFStorageRevisionResult
) -> GFStorageResourceReadResult:
	if resource == null or revision == null or not revision.is_successful():
		return failure(ERR_INVALID_PARAMETER)
	var result: GFStorageResourceReadResult = GFStorageResourceReadResult.new()
	result._error_code = OK
	result._resource = resource
	result._committed_revision = revision
	return result


## 创建不包含 Resource 或 committed revision 的失败结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param error: 非 OK 的 Godot Error 码；OK 归一为 ERR_INVALID_PARAMETER。
## [br]
## @return 不保留 Resource 或 committed revision 的失败结果。
static func failure(error: Error) -> GFStorageResourceReadResult:
	var result: GFStorageResourceReadResult = GFStorageResourceReadResult.new()
	result._error_code = ERR_INVALID_PARAMETER if error == OK else error
	return result


## 检查是否成功取得 Resource 及其 committed revision。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 仅成功结果返回 true。
func is_successful() -> bool:
	return (
		_error_code == OK
		and _resource != null
		and _committed_revision != null
		and _committed_revision.is_successful()
	)


## 获取读取的 Godot Error 码。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功时为 OK；失败时为非 OK 错误码。
func get_error_code() -> Error:
	return _error_code


## 获取读取到的原 Resource 对象引用。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功时返回同一 Resource；失败时为 null。调用方修改该对象会被其他持有者观察到。
func get_resource() -> Resource:
	return _resource


## 获取与本次 Resource 读取配对的 committed revision。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功时返回不可变 revision 结果；失败时为 null。
func get_committed_revision() -> GFStorageRevisionResult:
	return _committed_revision
