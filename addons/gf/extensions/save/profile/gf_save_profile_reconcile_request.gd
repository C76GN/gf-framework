## GFSaveProfileReconcileRequest: uncertain 写入对账的一次性请求句柄。
##
## 请求只携带调用方纯数据上下文和结果元数据，不携带 Recovery/Reconcile Lease
## 身份。Lease 必须作为独立类型化参数提交，避免从 Dictionary 恢复所有权。
## `create()` 隔离两个元数据字典，调用方可继续修改源数据。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 11.0.0
class_name GFSaveProfileReconcileRequest
extends RefCounted


# --- 常量 ---

## 隔离并限制普通请求元数据的共享边界。
## [br]
## @api private
## [br]
const _REQUEST_SNAPSHOT_SCRIPT = preload("res://addons/gf/extensions/save/profile/gf_save_request_snapshot.gd")


# --- 私有变量 ---

## 标记请求的输入校验是否已经完成。
## [br]
## @api private
## [br]
var _ready: bool = false

## 标记请求是否已被框架领取。
## [br]
## @api private
## [br]
var _claimed: bool = false

## 对账 Provider 使用的临时上下文。
## [br]
## @api private
## [br]
var _context: Dictionary = {}

## 写入对账终态结果的附加元数据。
## [br]
## @api private
## [br]
var _result_metadata: Dictionary = {}


# --- 公共方法 ---

## 创建请求并隔离 context 与 result_metadata 的纯数据快照。
##
## 输入必须是有界纯 Variant 数据，不能包含 Callable、Object、Signal、RID 或
## 循环集合或非有限数。两个字典合计最多 64 层、100000 节点、1 MiB 保守复制预算。
## 该请求不接受可执行恢复策略或 patch；项目策略应在提交前完成决策。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param context: 对账流程使用的临时纯数据上下文。
## [br]
## @param result_metadata: 只写入当前对账结果的调用方纯数据元数据。
## [br]
## @schema context: Bounded Dictionary without Callable, Signal, RID, Object, or circular references copied into an isolated snapshot.
## [br]
## @schema result_metadata: Bounded Dictionary without Callable, Signal, RID, Object, or circular references copied into an isolated snapshot.
## [br]
## @return 可用请求；输入无效时返回 null。
static func create(context: Dictionary = {}, result_metadata: Dictionary = {}) -> GFSaveProfileReconcileRequest:
	var snapshot: Dictionary = _REQUEST_SNAPSHOT_SCRIPT.capture(
		{},
		context,
		result_metadata
	)
	if snapshot.is_empty():
		return null
	var request: GFSaveProfileReconcileRequest = GFSaveProfileReconcileRequest.new()
	request._context = GFVariantData.as_dictionary(snapshot.get("context"))
	request._result_metadata = GFVariantData.as_dictionary(snapshot.get("result_metadata"))
	request._ready = true
	return request


## 检查请求是否仍可由协调器接管。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 尚未 claim 时返回 true。
func is_available() -> bool:
	return _ready and not _claimed


## 检查请求是否已经被协调器接管。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 已成功 claim 时返回 true。
func is_claimed() -> bool:
	return _claimed


# --- 框架内部方法 ---

## 获取不含请求载荷的所有权快照。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @return 包含 available 与 claimed 的快照。
## [br]
## @schema return: Payload-free Dictionary with available and claimed.
func inspect_for_framework() -> Dictionary:
	return { "available": is_available(), "claimed": _claimed, }


## 一次性移出 context 与 result_metadata。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @return 所有权记录；请求不可用时返回空字典。
## [br]
## @schema return: Internal Dictionary with context and result_metadata ownership fields.
func claim_for_framework() -> Dictionary:
	if not is_available():
		return {}
	var claim: Dictionary = { "context": _context, "result_metadata": _result_metadata, }
	_context = {}
	_result_metadata = {}
	_ready = false
	_claimed = true
	return claim
