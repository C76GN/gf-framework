## GFSaveProfileRequest: Save Profile 保存请求的一次性所有权句柄。
##
## `create()` 在大小预算内隔离 document metadata、Provider context 和 result
## metadata。调用方可继续使用源字典；后续修改不会改变已提交请求。
## Utility 只允许 claim 一次，且不会公开任何 payload getter。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 11.0.0
class_name GFSaveProfileRequest
extends RefCounted


# --- 常量 ---

## 隔离并限制普通请求元数据的共享边界。
## [br]
## @api private
## [br]
const _REQUEST_SNAPSHOT_SCRIPT = preload("res://addons/gf/extensions/save/profile/gf_save_request_snapshot.gd")


# --- 私有变量 ---

## 标记三个输入字典是否通过请求校验。
## [br]
## @api private
## [br]
var _ready: bool = false

## 标记请求是否已被框架领取。
## [br]
## @api private
## [br]
var _claimed: bool = false

## 保存请求持有的文档元数据。
## [br]
## @api private
## [br]
var _document_metadata: Dictionary = {}

## 保存 Provider 操作所用上下文。
## [br]
## @api private
## [br]
var _context: Dictionary = {}

## 保存要附加到操作终态的元数据。
## [br]
## @api private
## [br]
var _result_metadata: Dictionary = {}


# --- 公共方法 ---

## 创建拥有独立元数据快照的请求。
##
## 输入必须是纯数据；三个字典合计最多 64 层、100000 节点、1 MiB 保守复制
## 预算。对象、循环、非有限数与超预算输入被拒绝；大型 section 应由 Provider 准备。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param document_metadata: 写入文档的持久化元数据。
## [br]
## @schema document_metadata: Bounded pure-data Dictionary copied into an isolated snapshot.
## [br]
## @param context: Provider 保存准备使用的临时上下文。
## [br]
## @schema context: Bounded pure-data Dictionary copied into an isolated snapshot.
## [br]
## @param result_metadata: 只写入当前操作终态的调用方元数据。
## [br]
## @schema result_metadata: Bounded pure-data Dictionary copied into an isolated snapshot.
## [br]
## @return 持有隔离快照的一次性句柄；输入无效或超预算时返回 null。
static func create(
	document_metadata: Dictionary,
	context: Dictionary,
	result_metadata: Dictionary
) -> GFSaveProfileRequest:
	var snapshot: Dictionary = _REQUEST_SNAPSHOT_SCRIPT.capture(
		document_metadata,
		context,
		result_metadata
	)
	if snapshot.is_empty():
		return null
	var request: GFSaveProfileRequest = GFSaveProfileRequest.new()
	request._document_metadata = GFVariantData.as_dictionary(snapshot.get("document_metadata"))
	request._context = GFVariantData.as_dictionary(snapshot.get("context"))
	request._result_metadata = GFVariantData.as_dictionary(snapshot.get("result_metadata"))
	request._ready = true
	return request


## 检查请求是否已经被 Save Profile Utility 接管。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 已成功 claim 时返回 true。
func is_claimed() -> bool:
	return _claimed


# --- 框架内部方法 ---

## 查询请求是否仍可由框架接管，不暴露任何请求载荷。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
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
## @since 11.0.0
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
