## GFInventoryOperationResult: 通用库存操作结果。
##
## 描述一次添加、移除、移动或合并操作的接受数量、剩余数量和失败原因。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFInventoryOperationResult
extends RefCounted


# --- 公共变量 ---

## 操作是否完全成功。
## [br]
## @api public
var ok: bool = false

## 物品标识。
## [br]
## @api public
var item_id: StringName = &""

## 请求处理的数量。
## [br]
## @api public
var requested_amount: int = 0

## 实际处理的数量。
## [br]
## @api public
var accepted_amount: int = 0

## 未处理的剩余数量。
## [br]
## @api public
var remaining_amount: int = 0

## 源槽位。没有源槽位时为 -1。
## [br]
## @api public
var source_slot: int = -1

## 目标槽位。没有目标槽位时为 -1。
## [br]
## @api public
var target_slot: int = -1

## 操作结果原因。
## [br]
## @api public
var reason: StringName = &""

## 项目自定义元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，项目自定义操作结果元数据；GF 会在 to_dict() 中复制输出。
var metadata: Dictionary = {}


# --- 公共方法 ---

## 创建成功结果。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param result_item_id: 物品标识。
## [br]
## @param amount: 处理数量；必须大于 0，否则返回规范化失败结果。
## [br]
## @param result_source_slot: 源槽位。
## [br]
## @param result_target_slot: 目标槽位。
## [br]
## @return: 操作结果。
static func success(
	result_item_id: StringName,
	amount: int,
	result_source_slot: int = -1,
	result_target_slot: int = -1
) -> GFInventoryOperationResult:
	return partial(
		result_item_id,
		amount,
		amount,
		&"ok",
		result_source_slot,
		result_target_slot
	)


## 创建失败或部分成功结果。
## [br]
## @api public
## [br]
## @param result_item_id: 物品标识。
## [br]
## @param requested: 请求数量。
## [br]
## @param accepted: 实际处理数量。
## [br]
## @param result_reason: 操作结果原因。
## [br]
## @param result_source_slot: 源槽位。
## [br]
## @param result_target_slot: 目标槽位。
## [br]
## @return: 操作结果。
static func partial(
	result_item_id: StringName,
	requested: int,
	accepted: int,
	result_reason: StringName,
	result_source_slot: int = -1,
	result_target_slot: int = -1
) -> GFInventoryOperationResult:
	var result: GFInventoryOperationResult = GFInventoryOperationResult.new()
	var normalized_requested: int = maxi(requested, 0)
	var normalized_accepted: int = clampi(accepted, 0, normalized_requested)
	result.ok = normalized_requested > 0 and normalized_accepted >= normalized_requested
	result.item_id = result_item_id
	result.requested_amount = normalized_requested
	result.accepted_amount = normalized_accepted
	result.remaining_amount = maxi(result.requested_amount - result.accepted_amount, 0)
	result.source_slot = result_source_slot
	result.target_slot = result_target_slot
	result.reason = _normalize_reason(result.ok, result.accepted_amount, result.requested_amount, result_reason)
	return result


## 检查操作是否处理了部分数量。
## [br]
## @api public
## [br]
## @return: 有部分处理返回 true。
func is_partial_success() -> bool:
	return not ok and accepted_amount > 0


## 转换为字典。
## [br]
## @api public
## [br]
## @return: 操作结果字典。
## [br]
## @schema return: Dictionary，包含 ok、item_id、requested_amount、accepted_amount、remaining_amount、source_slot、target_slot、reason 与 metadata。
func to_dict() -> Dictionary:
	return {
		"ok": ok,
		"item_id": String(item_id),
		"requested_amount": requested_amount,
		"accepted_amount": accepted_amount,
		"remaining_amount": remaining_amount,
		"source_slot": source_slot,
		"target_slot": target_slot,
		"reason": String(reason),
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

static func _normalize_reason(
	is_ok: bool,
	accepted: int,
	requested: int,
	result_reason: StringName
) -> StringName:
	if is_ok:
		return &"ok"
	if result_reason != &"" and result_reason != &"ok":
		return result_reason
	if accepted > 0 and accepted < requested:
		return &"partial"
	return &"failed"
