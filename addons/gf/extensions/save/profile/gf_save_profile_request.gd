## GFSaveProfileRequest: Save Profile 保存请求的一次性所有权句柄。
##
## `take_ownership()` 不会深复制输入。成功创建后，调用方必须立即且永久放弃
## document metadata、Provider context、result metadata 及其全部嵌套集合 alias。
## Utility 只允许 claim 一次，且不会公开任何 payload getter。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFSaveProfileRequest
extends RefCounted


# --- 私有变量 ---

var _ready: bool = false
var _claimed: bool = false
var _document_metadata: Dictionary = {}
var _context: Dictionary = {}
var _result_metadata: Dictionary = {}


# --- 公共方法 ---

## 创建请求并接收三个 Dictionary 的逻辑唯一所有权。
##
## 此方法不会深复制。返回请求后，调用方必须立即且永久放弃三个源 Dictionary
## 以及所有嵌套 `Dictionary` / `Array` alias；继续访问或修改会破坏请求快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param document_metadata: 写入文档的持久化元数据。
## [br]
## @schema document_metadata: Dictionary whose source and nested aliases are abandoned after a successful ownership transfer.
## [br]
## @param context: Provider 保存准备使用的临时上下文。
## [br]
## @schema context: Dictionary whose source and nested aliases are abandoned after a successful ownership transfer.
## [br]
## @param result_metadata: 只写入当前操作终态的调用方元数据。
## [br]
## @schema result_metadata: Dictionary whose source and nested aliases are abandoned after a successful ownership transfer.
## [br]
## @return 持有三个请求载荷的新 opaque 句柄。
static func take_ownership(
	document_metadata: Dictionary,
	context: Dictionary,
	result_metadata: Dictionary
) -> GFSaveProfileRequest:
	var request: GFSaveProfileRequest = GFSaveProfileRequest.new()
	request._document_metadata = document_metadata
	request._context = context
	request._result_metadata = result_metadata
	request._ready = true
	return request


## 检查请求是否已经被 Save Profile Utility 接管。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已成功 claim 时返回 true。
func is_claimed() -> bool:
	return _claimed


# --- 框架内部方法 ---

## 查询请求是否仍可由框架接管，不暴露任何请求载荷。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 请求已经初始化且尚未 claim 时返回 true。
func is_available_for_framework() -> bool:
	return _ready and not _claimed


## 一次性移出请求持有的三个 Dictionary。
##
## 该操作只转移引用，不遍历或深复制集合。失败返回空字典；成功后请求不可复用。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 包含 document_metadata、context 和 result_metadata 的所有权记录。
## [br]
## @schema return: Internal Dictionary with document_metadata, context, and result_metadata ownership fields.
func claim_for_framework() -> Dictionary:
	if not is_available_for_framework():
		return {}
	var claim: Dictionary = {
		"document_metadata": _document_metadata,
		"context": _context,
		"result_metadata": _result_metadata,
	}
	_document_metadata = {}
	_context = {}
	_result_metadata = {}
	_ready = false
	_claimed = true
	return claim
