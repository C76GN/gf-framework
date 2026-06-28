# GFAsyncResultSupport: internal async result dictionary helper.
#
# Keeps common async result field names and extra-payload merging in one place.
extends RefCounted


# --- 常量 ---

## 成功标记字段。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
const KEY_OK: String = "ok"

## 状态字段。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
const KEY_STATUS: String = "status"

## 取消/关闭原因字段。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
const KEY_REASON: String = "reason"

## 错误文本字段。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
const KEY_ERROR: String = "error"

## 元数据字段。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
const KEY_METADATA: String = "metadata"

## 完成标记字段。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
const KEY_COMPLETED: String = "completed"

## 取消标记字段。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
const KEY_CANCELLED: String = "cancelled"

## 超时标记字段。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
const KEY_TIMED_OUT: String = "timed_out"

## 失效标记字段。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
const KEY_INVALID: String = "invalid"

## Signal 参数字段。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
const KEY_ARGS: String = "args"


# --- 公共方法 ---

## 创建通用状态结果。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
## [br]
## @param status: 状态。
## [br]
## @param ok: 操作是否成功。
## [br]
## @param reason: 原因。
## [br]
## @param metadata: 元数据。
## [br]
## @param extra: 额外字段。
## [br]
## @return 结果字典。
## [br]
## @schema metadata: Dictionary caller-defined metadata copied into the result.
## [br]
## @schema extra: Dictionary extra fields copied into the result.
## [br]
## @schema return: Dictionary with ok, status, reason, metadata, and extra fields.
static func make_operation_result(
	status: StringName,
	ok: bool,
	reason: StringName = &"",
	metadata: Dictionary = {},
	extra: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {
		KEY_STATUS: status,
		KEY_OK: ok,
		KEY_REASON: reason,
		KEY_METADATA: metadata.duplicate(true),
	}
	merge_extra(result, extra)
	return result


## 创建等待结果。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
## [br]
## @param status: 等待状态。
## [br]
## @param completed: 是否完成。
## [br]
## @param cancelled: 是否取消。
## [br]
## @param timed_out: 是否超时。
## [br]
## @param invalid: 是否失效。
## [br]
## @param args: Signal 参数。
## [br]
## @param reason: 原因。
## [br]
## @param metadata: 元数据。
## [br]
## @param extra: 额外字段。
## [br]
## @return 等待结果字典。
## [br]
## @schema args: Array captured signal arguments copied into the result.
## [br]
## @schema metadata: Dictionary caller-defined metadata copied into the result.
## [br]
## @schema extra: Dictionary extra fields copied into the result.
## [br]
## @schema return: Dictionary with status, completed, cancelled, timed_out, invalid, reason, metadata, args, and extra fields.
static func make_wait_result(
	status: StringName,
	completed: bool,
	cancelled: bool,
	timed_out: bool,
	invalid: bool,
	args: Array = [],
	reason: StringName = &"",
	metadata: Dictionary = {},
	extra: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {
		KEY_STATUS: status,
		KEY_COMPLETED: completed,
		KEY_CANCELLED: cancelled,
		KEY_TIMED_OUT: timed_out,
		KEY_INVALID: invalid,
		KEY_REASON: reason,
		KEY_METADATA: metadata.duplicate(true),
		KEY_ARGS: args.duplicate(true),
	}
	merge_extra(result, extra)
	return result


## 将额外字段深拷贝合并到结果字典。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
## [br]
## @param result: 目标结果字典。
## [br]
## @param extra: 额外字段。
## [br]
## @schema result: Dictionary result payload mutated in place.
## [br]
## @schema extra: Dictionary extra fields copied into result.
static func merge_extra(result: Dictionary, extra: Dictionary) -> void:
	for key: Variant in extra.keys():
		result[key] = GFVariantData.duplicate_variant(extra[key])
