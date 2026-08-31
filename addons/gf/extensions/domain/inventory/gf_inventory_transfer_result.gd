## GFInventoryTransferResult: 槽位库存转移的类型化阶段结果。
##
## 结果只保存事务状态、稳定身份、数量与 revision，不保留库存模型或候选堆叠。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 11.0.0
class_name GFInventoryTransferResult
extends RefCounted


# --- 常量 ---

## 已完成隔离规划，可尝试提交。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_PREPARED: StringName = &"prepared"

## 两个库存已完成原子内存提交；不表示库存通知已经派发完毕。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_COMMITTED: StringName = &"committed"

## 请求参数、模型身份或槽位无效。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_INVALID_REQUEST: StringName = &"invalid_request"

## 模型正在处理其他变更或通知，无法取得协调锁。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_BUSY: StringName = &"busy"

## 来源槽位没有可转移堆叠或请求数量超过来源且不允许部分转移。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_NOT_ENOUGH_ITEMS: StringName = &"not_enough_items"

## 目标容量不足或目标槽位拒绝物品。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_NOT_ENOUGH_SPACE: StringName = &"not_enough_space"

## 实例数据或规则数据包含不支持、循环或超预算的结构。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_UNSUPPORTED_DATA: StringName = &"unsupported_data"

## 模型 identity 或 revision 在 prepare 后发生变化。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_STALE_REVISION: StringName = &"stale_revision"

## 重新规划结果与 prepare 阶段绑定的计划摘要不同。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_STALE_PLAN: StringName = &"stale_plan"

# --- 私有变量 ---

var _configured: bool = false
var _status: StringName = STATUS_INVALID_REQUEST
var _item_id: StringName = &""
var _requested_amount: int = 0
var _transferred_amount: int = 0
var _source_slot: int = -1
var _target_slot: int = -1
var _source_revision: int = -1
var _target_revision: int = -1


# --- 公共方法 ---

## 检查结果是否表示可继续的成功阶段。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 状态为 prepared 或 committed 时返回 true。
func is_successful() -> bool:
	return _status in [STATUS_PREPARED, STATUS_COMMITTED]


## 获取稳定状态。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: `STATUS_*` 常量之一。
func get_status() -> StringName:
	return _status


## 获取物品标识。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 转移物品 ID；请求尚未识别物品时为空。
func get_item_id() -> StringName:
	return _item_id


## 获取本次规划请求处理的数量。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 非负请求数量。
func get_requested_amount() -> int:
	return _requested_amount


## 获取规划或提交的实际转移数量。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 非负转移数量。
func get_transferred_amount() -> int:
	return _transferred_amount


## 获取未转移数量。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 请求数量减去实际转移数量。
func get_remaining_amount() -> int:
	return maxi(_requested_amount - _transferred_amount, 0)


## 获取来源槽位。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 来源槽位索引；无有效槽位时为 -1。
func get_source_slot() -> int:
	return _source_slot


## 获取显式目标槽位。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 显式目标槽位索引；自动选择时为 -1。
func get_target_slot() -> int:
	return _target_slot


## 获取结果绑定的来源 revision。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 非负 revision；无有效来源时为 -1。
func get_source_revision() -> int:
	return _source_revision


## 获取结果绑定的目标 revision。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 非负 revision；无有效目标时为 -1。
func get_target_revision() -> int:
	return _target_revision


## 创建隔离结果副本。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 不共享可变集合的新结果。
func duplicate_result() -> GFInventoryTransferResult:
	var result: GFInventoryTransferResult = GFInventoryTransferResult.new()
	var configured_result: bool = result.configure_for_framework(
		_status,
		_item_id,
		_requested_amount,
		_transferred_amount,
		_source_slot,
		_target_slot,
		_source_revision,
		_target_revision
	)
	assert(configured_result, "GFInventoryTransferResult 内部状态必须保持闭合。")
	return result


## 转换为稳定字典。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 只含状态、物品、数量、槽位与 revision 的字典。
## [br]
## @schema return: Dictionary with status, ok, item_id, requested_amount, transferred_amount, remaining_amount, source_slot, target_slot, source_revision, and target_revision.
func to_dict() -> Dictionary:
	return {
		"status": _status,
		"ok": is_successful(),
		"item_id": _item_id,
		"requested_amount": _requested_amount,
		"transferred_amount": _transferred_amount,
		"remaining_amount": get_remaining_amount(),
		"source_slot": _source_slot,
		"target_slot": _target_slot,
		"source_revision": _source_revision,
		"target_revision": _target_revision,
	}


# --- 框架内部方法 ---

## 一次性配置结果。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param status: `STATUS_*` 常量之一。
## [br]
## @param item_id: 物品标识。
## [br]
## @param requested_amount: 请求数量。
## [br]
## @param transferred_amount: 实际转移数量。
## [br]
## @param source_slot: 来源槽位。
## [br]
## @param target_slot: 目标槽位；自动选择时为 -1。
## [br]
## @param source_revision: 来源 revision。
## [br]
## @param target_revision: 目标 revision。
## [br]
## @return: 首次收到合法输入时返回 true。
func configure_for_framework(
	status: StringName,
	item_id: StringName,
	requested_amount: int,
	transferred_amount: int,
	source_slot: int,
	target_slot: int,
	source_revision: int,
	target_revision: int
) -> bool:
	if _configured or status not in _get_valid_statuses():
		return false
	if requested_amount < 0 or transferred_amount < 0 or transferred_amount > requested_amount:
		return false
	if source_slot < -1 or target_slot < -1 or source_revision < -1 or target_revision < -1:
		return false
	if (source_revision < 0) != (target_revision < 0):
		return false
	var successful_stage: bool = status in [STATUS_PREPARED, STATUS_COMMITTED]
	if successful_stage:
		if (
			String(item_id).strip_edges().is_empty()
			or requested_amount <= 0
			or transferred_amount <= 0
			or source_slot < 0
			or source_revision < 0
			or target_revision < 0
		):
			return false
	elif transferred_amount != 0:
		return false
	elif status not in [STATUS_INVALID_REQUEST, STATUS_BUSY]:
		if (
			String(item_id).strip_edges().is_empty()
			or requested_amount <= 0
			or source_slot < 0
		):
			return false
	_configured = true
	_status = status
	_item_id = item_id
	_requested_amount = requested_amount
	_transferred_amount = transferred_amount
	_source_slot = source_slot
	_target_slot = target_slot
	_source_revision = source_revision
	_target_revision = target_revision
	return true


# --- 私有/辅助方法 ---

static func _get_valid_statuses() -> Array[StringName]:
	return [
		STATUS_PREPARED,
		STATUS_COMMITTED,
		STATUS_INVALID_REQUEST,
		STATUS_BUSY,
		STATUS_NOT_ENOUGH_ITEMS,
		STATUS_NOT_ENOUGH_SPACE,
		STATUS_UNSUPPORTED_DATA,
		STATUS_STALE_REVISION,
		STATUS_STALE_PLAN,
	]
