## GFSaveProfileReconcileRequest: uncertain 写入对账的一次性请求句柄。
##
## 请求只携带调用方纯数据上下文和结果元数据，不携带 Recovery/Reconcile Lease
## 身份。Lease 必须作为独立类型化参数提交，避免从 Dictionary 恢复所有权。
## `take_ownership()` 成功后，调用方必须放弃两个 Dictionary 及其嵌套 alias。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFSaveProfileReconcileRequest
extends RefCounted


# --- 常量 ---

const _MAX_DEPTH: int = 64
const _MAX_ITEMS: int = 100_000


# --- 私有变量 ---

var _ready: bool = false
var _claimed: bool = false
var _context: Dictionary = {}
var _result_metadata: Dictionary = {}


# --- 公共方法 ---

## 创建请求并接管 context 与 result_metadata 的逻辑唯一所有权。
##
## 输入必须是有界纯 Variant 数据，不能包含 Callable、Object、Signal、RID 或
## 循环集合。该请求不接受可执行恢复策略或 patch；项目策略应在提交前完成决策。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param context: 对账流程使用的临时纯数据上下文。
## [br]
## @param result_metadata: 只写入当前对账结果的调用方纯数据元数据。
## [br]
## @schema context: Bounded Dictionary without Callable, Signal, RID, Object, or circular references whose source aliases are abandoned after success.
## [br]
## @schema result_metadata: Bounded Dictionary without Callable, Signal, RID, Object, or circular references whose source aliases are abandoned after success.
## [br]
## @return 可用请求；输入无效时返回 null。
static func take_ownership(
	context: Dictionary = {},
	result_metadata: Dictionary = {}
) -> GFSaveProfileReconcileRequest:
	if not _is_dictionary_supported(context) or not _is_dictionary_supported(result_metadata):
		return null
	var request: GFSaveProfileReconcileRequest = GFSaveProfileReconcileRequest.new()
	request._context = context
	request._result_metadata = result_metadata
	request._ready = true
	return request


## 检查请求是否仍可由协调器接管。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 尚未 claim 时返回 true。
func is_available() -> bool:
	return _ready and not _claimed


## 检查请求是否已经被协调器接管。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已成功 claim 时返回 true。
func is_claimed() -> bool:
	return _claimed


# --- 框架内部方法 ---

## 获取不含请求载荷的所有权快照。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 包含 available 与 claimed 的快照。
## [br]
## @schema return: Payload-free Dictionary with available and claimed.
func inspect_for_framework() -> Dictionary:
	return {
		"available": is_available(),
		"claimed": _claimed,
	}


## 一次性移出 context 与 result_metadata。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 所有权记录；请求不可用时返回空字典。
## [br]
## @schema return: Internal Dictionary with context and result_metadata ownership fields.
func claim_for_framework() -> Dictionary:
	if not is_available():
		return {}
	var claim: Dictionary = {
		"context": _context,
		"result_metadata": _result_metadata,
	}
	_context = {}
	_result_metadata = {}
	_ready = false
	_claimed = true
	return claim


# --- 私有/辅助方法 ---

static func _is_dictionary_supported(value: Dictionary) -> bool:
	var state: Dictionary = {
		"items": 0,
		"visited": [],
	}
	return _is_value_supported(value, 0, state)


static func _is_value_supported(value: Variant, depth: int, state: Dictionary) -> bool:
	if depth > _MAX_DEPTH:
		return false
	var item_count: int = GFVariantData.get_option_int(state, "items") + 1
	state["items"] = item_count
	if item_count > _MAX_ITEMS:
		return false

	match typeof(value):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return false
		TYPE_ARRAY:
			var array_value: Array = value
			var visited: Array = _get_visited(state)
			if _contains_collection_identity(visited, array_value):
				return false
			visited.append(array_value)
			for entry: Variant in array_value:
				if not _is_value_supported(entry, depth + 1, state):
					var _removed_array_failure: Variant = visited.pop_back()
					return false
			var _removed_array: Variant = visited.pop_back()
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			var visited: Array = _get_visited(state)
			if _contains_collection_identity(visited, dictionary_value):
				return false
			visited.append(dictionary_value)
			for key: Variant in dictionary_value.keys():
				if (
					not _is_value_supported(key, depth + 1, state)
					or not _is_value_supported(dictionary_value[key], depth + 1, state)
				):
					var _removed_dictionary_failure: Variant = visited.pop_back()
					return false
			var _removed_dictionary: Variant = visited.pop_back()
	return true


static func _get_visited(state: Dictionary) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(state, "visited"))


static func _contains_collection_identity(collections: Array, candidate: Variant) -> bool:
	for collection: Variant in collections:
		if is_same(collection, candidate):
			return true
	return false
