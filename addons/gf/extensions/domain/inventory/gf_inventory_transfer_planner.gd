## GFInventoryTransferPlanner: 槽位库存原子转移的有界纯候选规划器。
##
## 规划器只在调用方已取得模型协调锁后读取内部堆叠引用，构建隔离候选并
## 计算内容、规则与配置摘要；它不写入模型、不派发信号，也不拥有事务生命周期。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since unreleased
class_name GFInventoryTransferPlanner
extends RefCounted


# --- 常量 ---

const _MAX_SLOTS: int = 4096
const _MAX_VALUE_ITEMS: int = 32768
const _MAX_VALUE_DEPTH: int = 32
const _MAX_VALUE_BYTES: int = 1048576


# --- 框架内部方法 ---

## 在协调锁内构建来源库存的隔离移除候选。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param model: 已由 owner 锁定的来源模型。
## [br]
## @param owner: 当前转移事务句柄。
## [br]
## @param source_slot: 来源槽位。
## [br]
## @param amount: 请求数量；小于等于 0 时请求整个来源堆叠。
## [br]
## @param allow_partial: 来源不足时是否允许转移现有数量。
## [br]
## @param budget: 跨两个模型共享的硬预算状态。
## [br]
## @return: 不改写模型的来源候选计划；失败时包含 status。
## [br]
## @schema budget: Internal Dictionary with slots, items, bytes, and active collection identities.
## [br]
## @schema return: Internal bounded transfer plan Dictionary.
static func plan_source(
	model: GFSlotInventoryModel,
	owner: Object,
	source_slot: int,
	amount: int,
	allow_partial: bool,
	budget: Dictionary
) -> Dictionary:
	var source_stack: GFInventoryStack = model.get_inventory_transfer_stack_for_framework(
		owner,
		source_slot
	)
	if source_stack == null:
		return { "status": GFInventoryTransferResult.STATUS_INVALID_REQUEST }
	var requested_amount: int = source_stack.amount if amount <= 0 else amount
	if requested_amount <= 0:
		return { "status": GFInventoryTransferResult.STATUS_INVALID_REQUEST }
	if requested_amount > source_stack.amount and not allow_partial:
		return {
			"status": GFInventoryTransferResult.STATUS_NOT_ENOUGH_ITEMS,
			"item_id": source_stack.item_id,
			"requested_amount": requested_amount,
		}
	var transferable_amount: int = mini(requested_amount, source_stack.amount)
	if not _reserve_slots(model.get_slot_count(), budget):
		return _source_failure(
			GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA,
			source_stack.item_id,
			requested_amount
		)
	var config_result: Dictionary = _build_config_evidence(model, source_stack.item_id, budget)
	if not GFVariantData.get_option_bool(config_result, "ok"):
		return _source_failure(
			GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA,
			source_stack.item_id,
			requested_amount
		)
	var before_result: Dictionary = _copy_slots(model, owner, budget)
	if not GFVariantData.get_option_bool(before_result, "ok"):
		return _source_failure(
			GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA,
			source_stack.item_id,
			requested_amount
		)
	var candidate_slots: Array = GFVariantData.get_option_array(before_result, "slots")
	var before_snapshots: Array = GFVariantData.get_option_array(before_result, "snapshots")
	var candidate_stack: GFInventoryStack = _get_stack_value(candidate_slots[source_slot])
	if candidate_stack == null:
		return _source_failure(
			GFInventoryTransferResult.STATUS_INVALID_REQUEST,
			source_stack.item_id,
			requested_amount
		)
	var instance_copy_result: Dictionary = _copy_dictionary(candidate_stack.instance_data, budget)
	if not GFVariantData.get_option_bool(instance_copy_result, "ok"):
		return _source_failure(
			GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA,
			source_stack.item_id,
			requested_amount
		)
	var removed_amount: int = mini(transferable_amount, candidate_stack.amount)
	candidate_stack.amount -= removed_amount
	if candidate_stack.amount <= 0:
		candidate_slots[source_slot] = null
	var changes_result: Dictionary = _build_slot_changes(before_snapshots, candidate_slots, budget)
	if not GFVariantData.get_option_bool(changes_result, "ok"):
		return _source_failure(
			GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA,
			source_stack.item_id,
			requested_amount
		)
	var config_after_result: Dictionary = _build_config_evidence(
		model,
		source_stack.item_id,
		budget
	)
	if (
		not GFVariantData.get_option_bool(config_after_result, "ok")
		or GFVariantData.get_option_string(config_result, "sha")
		!= GFVariantData.get_option_string(config_after_result, "sha")
	):
		return _source_failure(
			GFInventoryTransferResult.STATUS_STALE_PLAN,
			source_stack.item_id,
			requested_amount
		)
	var after_snapshots: Array = GFVariantData.get_option_array(changes_result, "after_snapshots")
	return {
		"status": GFInventoryTransferResult.STATUS_PREPARED,
		"item_id": source_stack.item_id,
		"requested_amount": requested_amount,
		"transferable_amount": removed_amount,
		"instance_data": GFVariantData.get_option_dictionary(instance_copy_result, "value"),
		"slots": candidate_slots,
		"slot_changes": GFVariantData.get_option_dictionary(changes_result, "slot_changes"),
		"slot_change_order": GFVariantData.get_option_array(changes_result, "slot_change_order"),
		"item_events": [{
			"slot_index": source_slot,
			"item_id": source_stack.item_id,
			"amount": removed_amount,
		}],
		"before_sha": _sha(before_snapshots),
		"after_sha": _sha(after_snapshots),
		"config_sha": GFVariantData.get_option_string(config_result, "sha"),
	}


## 在协调锁内按 add_item/add_item_to_slot 顺序构建目标候选。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param model: 已由 owner 锁定的目标模型。
## [br]
## @param owner: 当前转移事务句柄。
## [br]
## @param item_id: 转移物品 ID。
## [br]
## @param amount: 来源候选允许转移的正数量。
## [br]
## @param instance_data: 已有界复制的来源实例数据。
## [br]
## @param target_slot: -1 使用 add_item 顺序；非负值使用 add_item_to_slot 语义。
## [br]
## @param allow_partial: 容量不足时是否允许部分转移。
## [br]
## @param budget: 跨两个模型共享的硬预算状态。
## [br]
## @return: 不改写模型的目标候选计划；失败时包含 status。
## [br]
## @schema instance_data: Bounded, acyclic Dictionary without Object, Callable, Signal, or RID values.
## [br]
## @schema budget: Internal Dictionary with slots, items, bytes, and active collection identities.
## [br]
## @schema return: Internal bounded transfer plan Dictionary.
static func plan_target(
	model: GFSlotInventoryModel,
	owner: Object,
	item_id: StringName,
	amount: int,
	instance_data: Dictionary,
	target_slot: int,
	allow_partial: bool,
	budget: Dictionary
) -> Dictionary:
	if item_id == &"" or amount <= 0 or not _accepts_item(model, item_id):
		return { "status": GFInventoryTransferResult.STATUS_INVALID_REQUEST }
	if target_slot < -1 or (target_slot >= 0 and not model.is_valid_slot(target_slot)):
		return { "status": GFInventoryTransferResult.STATUS_INVALID_REQUEST }
	if not _reserve_slots(model.get_slot_count(), budget):
		return { "status": GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA }
	var config_result: Dictionary = _build_config_evidence(model, item_id, budget)
	if not GFVariantData.get_option_bool(config_result, "ok"):
		return { "status": GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA }
	var normalized_result: Dictionary = _normalize_instance_data(model, item_id, instance_data, budget)
	if not GFVariantData.get_option_bool(normalized_result, "ok"):
		return { "status": GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA }
	var normalized_data: Dictionary = GFVariantData.get_option_dictionary(normalized_result, "value")
	var before_result: Dictionary = _copy_slots(model, owner, budget)
	if not GFVariantData.get_option_bool(before_result, "ok"):
		return { "status": GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA }
	var candidate_slots: Array = GFVariantData.get_option_array(before_result, "slots")
	var before_snapshots: Array = GFVariantData.get_option_array(before_result, "snapshots")
	var item_events: Array[Dictionary] = []
	var remaining: int = amount
	if target_slot >= 0:
		remaining = _add_to_slot(
			model,
			candidate_slots,
			target_slot,
			item_id,
			remaining,
			normalized_data,
			item_events,
			budget
		)
	else:
		for slot_index: int in range(candidate_slots.size()):
			remaining = _add_to_existing(
				model,
				candidate_slots,
				slot_index,
				item_id,
				remaining,
				normalized_data,
				item_events,
				budget
			)
			if remaining <= 0:
				break
		while remaining > 0:
			if not _can_create_stack(model, candidate_slots, item_id):
				break
			var empty_slot: int = _find_empty_slot(
				model,
				candidate_slots,
				item_id,
				normalized_data
			)
			if empty_slot < 0 and model.allow_growth:
				if not _reserve_slots(1, budget):
					return { "status": GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA }
				candidate_slots.append(null)
				empty_slot = candidate_slots.size() - 1
			if empty_slot < 0:
				break
			var event_count_before: int = item_events.size()
			remaining = _add_to_empty(
				model,
				candidate_slots,
				empty_slot,
				item_id,
				remaining,
				normalized_data,
				item_events,
				budget
			)
			if item_events.size() == event_count_before:
				break
	if GFVariantData.get_option_bool(budget, "failed"):
		return { "status": GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA }
	var accepted_amount: int = amount - remaining
	if accepted_amount <= 0 or (remaining > 0 and not allow_partial):
		return { "status": GFInventoryTransferResult.STATUS_NOT_ENOUGH_SPACE }
	var changes_result: Dictionary = _build_slot_changes(before_snapshots, candidate_slots, budget)
	if not GFVariantData.get_option_bool(changes_result, "ok"):
		return { "status": GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA }
	var config_after_result: Dictionary = _build_config_evidence(model, item_id, budget)
	if (
		not GFVariantData.get_option_bool(config_after_result, "ok")
		or GFVariantData.get_option_string(config_result, "sha")
		!= GFVariantData.get_option_string(config_after_result, "sha")
	):
		return { "status": GFInventoryTransferResult.STATUS_STALE_PLAN }
	var after_snapshots: Array = GFVariantData.get_option_array(changes_result, "after_snapshots")
	return {
		"status": GFInventoryTransferResult.STATUS_PREPARED,
		"accepted_amount": accepted_amount,
		"slots": candidate_slots,
		"slot_changes": GFVariantData.get_option_dictionary(changes_result, "slot_changes"),
		"slot_change_order": GFVariantData.get_option_array(changes_result, "slot_change_order"),
		"item_events": item_events,
		"before_sha": _sha(before_snapshots),
		"after_sha": _sha(after_snapshots),
		"config_sha": GFVariantData.get_option_string(config_result, "sha"),
	}


## 在协调锁内按 `move_between_slots()` 规则构建同模型候选。
##
## 规划器只读取模型与同步规则；最终提交直接替换此处生成的已验证候选，
## 不动态调用可重写的公共变更方法。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param model: 已由 owner 锁定的库存模型。
## [br]
## @param owner: 当前转移事务句柄。
## [br]
## @param source_slot: 来源槽位。
## [br]
## @param target_slot: 显式目标槽位。
## [br]
## @param amount: 请求数量；小于等于 0 时请求全部。
## [br]
## @param allow_partial: 容量或来源不足时是否允许部分转移。
## [br]
## @param budget: 本次规划的硬预算状态。
## [br]
## @return: 不改写模型的同模型计划；失败时包含 status。
## [br]
## @schema budget: Internal Dictionary with slots, items, bytes, and active collection identities.
## [br]
## @schema return: Internal bounded same-model transfer plan Dictionary.
static func plan_same_model(
	model: GFSlotInventoryModel,
	owner: Object,
	source_slot: int,
	target_slot: int,
	amount: int,
	allow_partial: bool,
	budget: Dictionary
) -> Dictionary:
	if source_slot == target_slot or target_slot < 0 or not model.is_valid_slot(target_slot):
		return { "status": GFInventoryTransferResult.STATUS_INVALID_REQUEST }
	var source_stack: GFInventoryStack = model.get_inventory_transfer_stack_for_framework(
		owner,
		source_slot
	)
	if source_stack == null:
		return { "status": GFInventoryTransferResult.STATUS_INVALID_REQUEST }
	var requested_amount: int = source_stack.amount if amount <= 0 else amount
	if requested_amount <= 0:
		return { "status": GFInventoryTransferResult.STATUS_INVALID_REQUEST }
	if requested_amount > source_stack.amount and not allow_partial:
		return {
			"status": GFInventoryTransferResult.STATUS_NOT_ENOUGH_ITEMS,
			"item_id": source_stack.item_id,
			"requested_amount": requested_amount,
		}
	if not _reserve_slots(model.get_slot_count(), budget):
		return _source_failure(
			GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA,
			source_stack.item_id,
			requested_amount
		)
	var before_result: Dictionary = _copy_slots(model, owner, budget)
	if not GFVariantData.get_option_bool(before_result, "ok"):
		return _source_failure(
			GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA,
			source_stack.item_id,
			requested_amount
		)
	var candidate_slots: Array = GFVariantData.get_option_array(before_result, "slots")
	var before_snapshots: Array = GFVariantData.get_option_array(before_result, "snapshots")
	var candidate_source: GFInventoryStack = _get_stack_value(candidate_slots[source_slot])
	if candidate_source == null:
		return _source_failure(
			GFInventoryTransferResult.STATUS_INVALID_REQUEST,
			source_stack.item_id,
			requested_amount
		)
	var config_result: Dictionary = _build_config_evidence(model, candidate_source.item_id, budget)
	if not GFVariantData.get_option_bool(config_result, "ok"):
		return _source_failure(
			GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA,
			candidate_source.item_id,
			requested_amount
		)
	if not _slot_accepts(model, candidate_slots, target_slot, candidate_source.item_id, candidate_source.instance_data):
		return _source_failure(
			GFInventoryTransferResult.STATUS_NOT_ENOUGH_SPACE,
			candidate_source.item_id,
			requested_amount
		)
	var move_amount: int = mini(requested_amount, candidate_source.amount)
	var candidate_target: GFInventoryStack = _get_stack_value(candidate_slots[target_slot])
	var accepted_amount: int = move_amount
	if candidate_target == null:
		if (
			candidate_source.amount > move_amount
			and not _can_create_stack(model, candidate_slots, candidate_source.item_id)
		):
			accepted_amount = 0
	else:
		if not _stack_can_merge(
			model,
			candidate_target,
			candidate_source.item_id,
			candidate_source.instance_data,
			budget
		):
			accepted_amount = 0
		else:
			accepted_amount = mini(
				move_amount,
				maxi(_max_stack_amount(model, candidate_source.item_id) - candidate_target.amount, 0)
			)
	if GFVariantData.get_option_bool(budget, "failed"):
		return _source_failure(
			GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA,
			candidate_source.item_id,
			requested_amount
		)
	if accepted_amount <= 0 or (accepted_amount < requested_amount and not allow_partial):
		return _source_failure(
			GFInventoryTransferResult.STATUS_NOT_ENOUGH_SPACE,
			candidate_source.item_id,
			requested_amount
		)
	if candidate_target == null:
		if candidate_source.amount == accepted_amount:
			candidate_slots[source_slot] = null
			candidate_slots[target_slot] = candidate_source
		else:
			var target_data_result: Dictionary = _copy_dictionary(
				candidate_source.instance_data,
				budget
			)
			if not GFVariantData.get_option_bool(target_data_result, "ok"):
				return _source_failure(
					GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA,
					candidate_source.item_id,
					requested_amount
				)
			var moved_stack: GFInventoryStack = GFInventoryStack.new()
			moved_stack.item_id = candidate_source.item_id
			moved_stack.amount = accepted_amount
			moved_stack.instance_data = GFVariantData.get_option_dictionary(
				target_data_result,
				"value"
			)
			candidate_source.amount -= accepted_amount
			candidate_slots[target_slot] = moved_stack
	else:
		candidate_target.amount += accepted_amount
		candidate_source.amount -= accepted_amount
		if candidate_source.amount <= 0:
			candidate_slots[source_slot] = null
	var changes_result: Dictionary = _build_slot_changes(
		before_snapshots,
		candidate_slots,
		budget
	)
	if not GFVariantData.get_option_bool(changes_result, "ok"):
		return _source_failure(
			GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA,
			source_stack.item_id,
			requested_amount
		)
	var config_after_result: Dictionary = _build_config_evidence(model, candidate_source.item_id, budget)
	if (
		not GFVariantData.get_option_bool(config_after_result, "ok")
		or GFVariantData.get_option_string(config_result, "sha")
		!= GFVariantData.get_option_string(config_after_result, "sha")
	):
		return _source_failure(
			GFInventoryTransferResult.STATUS_STALE_PLAN,
			candidate_source.item_id,
			requested_amount
		)
	var after_snapshots: Array = GFVariantData.get_option_array(changes_result, "after_snapshots")
	return {
		"status": GFInventoryTransferResult.STATUS_PREPARED,
		"item_id": candidate_source.item_id,
		"requested_amount": requested_amount,
		"accepted_amount": accepted_amount,
		"slots": candidate_slots,
		"slot_changes": GFVariantData.get_option_dictionary(changes_result, "slot_changes"),
		"slot_change_order": GFVariantData.get_option_array(changes_result, "slot_change_order"),
		"item_events": [],
		"before_sha": _sha(before_snapshots),
		"after_sha": _sha(after_snapshots),
		"config_sha": GFVariantData.get_option_string(config_result, "sha"),
	}


# --- 私有/辅助方法 ---

static func _source_failure(
	status: StringName,
	item_id: StringName,
	requested_amount: int
) -> Dictionary:
	return {
		"status": status,
		"item_id": item_id,
		"requested_amount": requested_amount,
	}

static func _copy_slots(
	model: GFSlotInventoryModel,
	owner: Object,
	budget: Dictionary
) -> Dictionary:
	var copied_slots: Array = []
	var snapshots: Array = []
	for slot_index: int in range(model.get_slot_count()):
		var stack: GFInventoryStack = model.get_inventory_transfer_stack_for_framework(
			owner,
			slot_index
		)
		if stack == null or stack.is_empty():
			copied_slots.append(null)
			snapshots.append({})
			continue
		var candidate_data_result: Dictionary = _copy_dictionary(stack.instance_data, budget)
		var snapshot_data_result: Dictionary = _copy_dictionary(stack.instance_data, budget)
		if (
			not GFVariantData.get_option_bool(candidate_data_result, "ok")
			or not GFVariantData.get_option_bool(snapshot_data_result, "ok")
		):
			return { "ok": false }
		var copied_stack: GFInventoryStack = GFInventoryStack.new()
		copied_stack.item_id = stack.item_id
		copied_stack.amount = stack.amount
		copied_stack.instance_data = GFVariantData.get_option_dictionary(candidate_data_result, "value")
		copied_slots.append(copied_stack)
		snapshots.append({
			"item_id": String(stack.item_id),
			"amount": stack.amount,
			"instance_data": GFVariantData.get_option_dictionary(snapshot_data_result, "value"),
		})
	return { "ok": true, "slots": copied_slots, "snapshots": snapshots }


static func _build_slot_changes(
	before_snapshots: Array,
	after_slots: Array,
	budget: Dictionary
) -> Dictionary:
	var after_snapshots: Array = []
	var slot_changes: Dictionary = {}
	var slot_change_order: Array[int] = []
	var count: int = maxi(before_snapshots.size(), after_slots.size())
	for slot_index: int in range(count):
		var after_snapshot: Dictionary = {}
		if slot_index < after_slots.size():
			var stack: GFInventoryStack = _get_stack_value(after_slots[slot_index])
			if stack != null and not stack.is_empty():
				var data_result: Dictionary = _copy_dictionary(stack.instance_data, budget)
				if not GFVariantData.get_option_bool(data_result, "ok"):
					return { "ok": false }
				after_snapshot = {
					"item_id": String(stack.item_id),
					"amount": stack.amount,
					"instance_data": GFVariantData.get_option_dictionary(data_result, "value"),
				}
		after_snapshots.append(after_snapshot)
		var before_snapshot: Dictionary = {}
		if slot_index < before_snapshots.size():
			before_snapshot = GFVariantData.as_dictionary(before_snapshots[slot_index])
		if before_snapshot == after_snapshot:
			continue
		slot_change_order.append(slot_index)
		slot_changes[slot_index] = { "before": before_snapshot, "after": after_snapshot }
	return {
		"ok": true,
		"after_snapshots": after_snapshots,
		"slot_changes": slot_changes,
		"slot_change_order": slot_change_order,
	}


static func _add_to_slot(
	model: GFSlotInventoryModel,
	candidate_slots: Array,
	slot_index: int,
	item_id: StringName,
	remaining: int,
	instance_data: Dictionary,
	item_events: Array[Dictionary],
	budget: Dictionary
) -> int:
	if remaining <= 0 or not _slot_accepts(model, candidate_slots, slot_index, item_id, instance_data):
		return remaining
	var stack: GFInventoryStack = _get_stack_value(candidate_slots[slot_index])
	if stack == null:
		if not _can_create_stack(model, candidate_slots, item_id):
			return remaining
		return _add_to_empty(
			model, candidate_slots, slot_index, item_id, remaining,
			instance_data, item_events, budget
		)
	if not _stack_can_merge(model, stack, item_id, instance_data, budget):
		return remaining
	return _add_to_existing(
		model, candidate_slots, slot_index, item_id, remaining,
		instance_data, item_events, budget
	)


static func _add_to_existing(
	model: GFSlotInventoryModel,
	candidate_slots: Array,
	slot_index: int,
	item_id: StringName,
	remaining: int,
	instance_data: Dictionary,
	item_events: Array[Dictionary],
	budget: Dictionary
) -> int:
	if remaining <= 0 or slot_index < 0 or slot_index >= candidate_slots.size():
		return remaining
	var stack: GFInventoryStack = _get_stack_value(candidate_slots[slot_index])
	if (
		stack == null
		or not _stack_can_merge(model, stack, item_id, instance_data, budget)
		or not _slot_accepts(model, candidate_slots, slot_index, item_id, instance_data)
	):
		return remaining
	var accepted: int = mini(remaining, maxi(_max_stack_amount(model, item_id) - stack.amount, 0))
	if accepted <= 0:
		return remaining
	stack.amount += accepted
	item_events.append({ "slot_index": slot_index, "item_id": item_id, "amount": accepted })
	return remaining - accepted


static func _add_to_empty(
	model: GFSlotInventoryModel,
	candidate_slots: Array,
	slot_index: int,
	item_id: StringName,
	remaining: int,
	instance_data: Dictionary,
	item_events: Array[Dictionary],
	budget: Dictionary
) -> int:
	if (
		remaining <= 0
		or slot_index < 0
		or slot_index >= candidate_slots.size()
		or _get_stack_value(candidate_slots[slot_index]) != null
		or not _slot_accepts(model, candidate_slots, slot_index, item_id, instance_data)
	):
		return remaining
	var accepted: int = mini(remaining, _max_stack_amount(model, item_id))
	if accepted <= 0:
		return remaining
	var data_result: Dictionary = _copy_dictionary(instance_data, budget)
	if not GFVariantData.get_option_bool(data_result, "ok"):
		return remaining
	var stack: GFInventoryStack = GFInventoryStack.new()
	stack.item_id = item_id
	stack.amount = accepted
	stack.instance_data = GFVariantData.get_option_dictionary(data_result, "value")
	candidate_slots[slot_index] = stack
	item_events.append({ "slot_index": slot_index, "item_id": item_id, "amount": accepted })
	return remaining - accepted


static func _find_empty_slot(
	model: GFSlotInventoryModel,
	candidate_slots: Array,
	item_id: StringName,
	instance_data: Dictionary
) -> int:
	for slot_index: int in range(candidate_slots.size()):
		if (
			_get_stack_value(candidate_slots[slot_index]) == null
			and _slot_accepts(model, candidate_slots, slot_index, item_id, instance_data)
		):
			return slot_index
	return -1


static func _slot_accepts(
	model: GFSlotInventoryModel,
	candidate_slots: Array,
	slot_index: int,
	item_id: StringName,
	instance_data: Dictionary
) -> bool:
	if slot_index < 0 or slot_index >= candidate_slots.size():
		return false
	if slot_index >= model.get_slot_count():
		return true
	var slot_definition: GFInventorySlotDefinition = model.get_slot_definition(slot_index)
	if slot_definition == null:
		return true
	var item_definition: GFInventoryItemDefinition = null
	if model.registry != null:
		item_definition = model.registry.get_definition(item_id)
	if not slot_definition.acceptance_checker.is_valid():
		return slot_definition.can_accept(
			item_id,
			item_definition,
			instance_data,
			slot_index,
			null
		)
	var candidate_view: GFInventoryReadView = GFInventoryReadView.new()
	if not candidate_view.configure_for_framework(candidate_slots, model.registry):
		return false
	var accepted: bool = slot_definition.can_accept(
		item_id,
		item_definition,
		instance_data,
		slot_index,
		candidate_view
	)
	candidate_view.invalidate_for_framework()
	return accepted


static func _can_create_stack(
	model: GFSlotInventoryModel,
	candidate_slots: Array,
	item_id: StringName
) -> bool:
	var max_stack_count: int = _max_stack_count(model, item_id)
	if max_stack_count <= 0:
		return true
	var stack_count: int = 0
	for stack_variant: Variant in candidate_slots:
		var stack: GFInventoryStack = _get_stack_value(stack_variant)
		if stack != null and stack.item_id == item_id:
			stack_count += 1
	return stack_count < max_stack_count


static func _stack_can_merge(
	model: GFSlotInventoryModel,
	stack: GFInventoryStack,
	item_id: StringName,
	instance_data: Dictionary,
	budget: Dictionary
) -> bool:
	if stack == null or stack.is_empty():
		return true
	if stack.item_id != item_id:
		return false
	if model.registry == null:
		return stack.instance_data == instance_data
	var definition: GFInventoryItemDefinition = model.registry.get_definition(item_id)
	if definition == null:
		return stack.instance_data == instance_data
	var left_result: Dictionary = _merge_defaults(
		definition.default_instance_data, stack.instance_data, budget
	)
	var right_result: Dictionary = _merge_defaults(
		definition.default_instance_data, instance_data, budget
	)
	if (
		not GFVariantData.get_option_bool(left_result, "ok")
		or not GFVariantData.get_option_bool(right_result, "ok")
	):
		return false
	var left: Dictionary = GFVariantData.get_option_dictionary(left_result, "value")
	var right: Dictionary = GFVariantData.get_option_dictionary(right_result, "value")
	if definition.compatibility_checker.is_valid():
		return GFVariantData.to_bool(definition.compatibility_checker.call(
			left, right, definition
		))
	if definition.stack_key_fields.is_empty():
		return left == right
	for field_name: String in definition.stack_key_fields:
		if GFVariantData.get_option_value(left, field_name) != GFVariantData.get_option_value(right, field_name):
			return false
	return true


static func _normalize_instance_data(
	model: GFSlotInventoryModel,
	item_id: StringName,
	instance_data: Dictionary,
	budget: Dictionary
) -> Dictionary:
	var input_result: Dictionary = _copy_dictionary(instance_data, budget)
	if not GFVariantData.get_option_bool(input_result, "ok"):
		return { "ok": false }
	var input_copy: Dictionary = GFVariantData.get_option_dictionary(input_result, "value")
	if model.registry == null:
		return { "ok": true, "value": input_copy }
	var definition: GFInventoryItemDefinition = model.registry.get_definition(item_id)
	if definition == null:
		return { "ok": true, "value": input_copy }
	var normalized_result: Dictionary = _merge_defaults(
		definition.default_instance_data, input_copy, budget
	)
	var defaults_result: Dictionary = _copy_dictionary(definition.default_instance_data, budget)
	if (
		not GFVariantData.get_option_bool(normalized_result, "ok")
		or not GFVariantData.get_option_bool(defaults_result, "ok")
	):
		return { "ok": false }
	if (
		GFVariantData.get_option_dictionary(normalized_result, "value")
		== GFVariantData.get_option_dictionary(defaults_result, "value")
	):
		return { "ok": true, "value": {} }
	return { "ok": true, "value": input_copy }


static func _merge_defaults(
	defaults: Dictionary,
	overrides: Dictionary,
	budget: Dictionary
) -> Dictionary:
	var defaults_result: Dictionary = _copy_dictionary(defaults, budget)
	var overrides_result: Dictionary = _copy_dictionary(overrides, budget)
	if (
		not GFVariantData.get_option_bool(defaults_result, "ok")
		or not GFVariantData.get_option_bool(overrides_result, "ok")
	):
		return { "ok": false }
	var merged: Dictionary = GFVariantData.get_option_dictionary(defaults_result, "value")
	var override_values: Dictionary = GFVariantData.get_option_dictionary(overrides_result, "value")
	for key: Variant in override_values:
		merged[key] = override_values[key]
	return { "ok": true, "value": merged }


static func _build_config_evidence(
	model: GFSlotInventoryModel,
	item_id: StringName,
	budget: Dictionary
) -> Dictionary:
	var evidence: Dictionary = {
		"allow_growth": model.allow_growth,
		"item_id": item_id,
		"registry_id": model.registry.get_instance_id() if model.registry != null else 0,
		"registry": {},
		"slots": [],
	}
	if model.registry != null:
		var registry_evidence: Dictionary = {
			"allow_unregistered_items": model.registry.allow_unregistered_items,
			"default_max_stack_amount": model.registry.default_max_stack_amount,
			"default_max_stack_count": model.registry.default_max_stack_count,
		}
		var definition: GFInventoryItemDefinition = model.registry.get_definition(item_id)
		if definition != null:
			var default_data_result: Dictionary = _copy_dictionary(
				definition.default_instance_data, budget
			)
			var compatibility_result: Dictionary = _build_callable_evidence(
				definition.compatibility_checker, budget
			)
			if (
				not GFVariantData.get_option_bool(default_data_result, "ok")
				or not GFVariantData.get_option_bool(compatibility_result, "ok")
			):
				return { "ok": false }
			registry_evidence["definition"] = {
				"identity": definition.get_instance_id(),
				"item_id": definition.item_id,
				"max_stack_amount": definition.max_stack_amount,
				"max_stack_count": definition.max_stack_count,
				"categories": definition.categories,
				"default_instance_data": GFVariantData.get_option_dictionary(
					default_data_result, "value"
				),
				"stack_key_fields": definition.stack_key_fields,
				"compatibility_checker": GFVariantData.get_option_value(
					compatibility_result, "value"
				),
			}
		evidence["registry"] = registry_evidence
	var slot_evidence: Array = []
	for slot_index: int in range(model.get_slot_count()):
		var slot_definition: GFInventorySlotDefinition = model.get_slot_definition(slot_index)
		if slot_definition == null:
			slot_evidence.append(null)
			continue
		var acceptance_result: Dictionary = _build_callable_evidence(
			slot_definition.acceptance_checker, budget
		)
		if not GFVariantData.get_option_bool(acceptance_result, "ok"):
			return { "ok": false }
		slot_evidence.append({
			"identity": slot_definition.get_instance_id(),
			"accepted_item_ids": slot_definition.accepted_item_ids,
			"rejected_item_ids": slot_definition.rejected_item_ids,
			"accepted_categories": slot_definition.accepted_categories,
			"require_all_categories": slot_definition.require_all_categories,
			"acceptance_checker": GFVariantData.get_option_value(acceptance_result, "value"),
		})
	evidence["slots"] = slot_evidence
	var copy_result: Dictionary = _copy_variant_root(evidence, budget)
	if not GFVariantData.get_option_bool(copy_result, "ok"):
		return { "ok": false }
	return { "ok": true, "sha": _sha(GFVariantData.get_option_value(copy_result, "value")) }


static func _accepts_item(model: GFSlotInventoryModel, item_id: StringName) -> bool:
	if model.registry == null:
		return item_id != &""
	return model.registry.accepts_item(item_id)


static func _max_stack_amount(model: GFSlotInventoryModel, item_id: StringName) -> int:
	return 99 if model.registry == null else model.registry.get_max_stack_amount(item_id)


static func _max_stack_count(model: GFSlotInventoryModel, item_id: StringName) -> int:
	return 0 if model.registry == null else model.registry.get_max_stack_count(item_id)


static func _get_stack_value(value: Variant) -> GFInventoryStack:
	if value is GFInventoryStack:
		var stack: GFInventoryStack = value
		return stack
	return null


static func _build_callable_evidence(callback: Callable, budget: Dictionary) -> Dictionary:
	if not callback.is_valid():
		return { "ok": true, "value": null }
	var bound_count: int = callback.get_bound_arguments_count()
	if bound_count < 0 or not _can_reserve_items(bound_count + 1, budget):
		return { "ok": false }
	var bound_arguments: Array = callback.get_bound_arguments()
	if bound_arguments.size() != bound_count:
		_fail_budget(budget)
		return { "ok": false }
	return {
		"ok": true,
		"value": {
			"object_id": callback.get_object_id(),
			"method": callback.get_method(),
			"bound_count": bound_count,
			"bound_arguments": bound_arguments,
		},
	}


static func _copy_dictionary(value: Dictionary, budget: Dictionary) -> Dictionary:
	var result: Dictionary = _copy_variant_root(value, budget)
	if (
		not GFVariantData.get_option_bool(result, "ok")
		or not (GFVariantData.get_option_value(result, "value") is Dictionary)
	):
		return { "ok": false }
	return result


static func _copy_variant_root(value: Variant, budget: Dictionary) -> Dictionary:
	var output: Array = []
	if not _copy_variant(value, 0, budget, output):
		return { "ok": false }
	return { "ok": true, "value": output[0] }


static func _copy_variant(
	value: Variant,
	depth: int,
	budget: Dictionary,
	output: Array
) -> bool:
	if depth > _MAX_VALUE_DEPTH or not _reserve_items(1, budget):
		_fail_budget(budget)
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			if not _reserve_bytes(16, budget):
				return false
			output.append(value)
			return true
		TYPE_FLOAT:
			var number: float = value
			if is_nan(number) or is_inf(number) or not _reserve_bytes(16, budget):
				_fail_budget(budget)
				return false
			output.append(number)
			return true
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			var text: String = str(value)
			var remaining_bytes: int = (
				_MAX_VALUE_BYTES - GFVariantData.get_option_int(budget, "bytes")
			)
			if text.length() > remaining_bytes:
				_fail_budget(budget)
				return false
			if not _reserve_bytes(text.to_utf8_buffer().size(), budget):
				return false
			output.append(value)
			return true
		TYPE_ARRAY:
			var array_value: Array = value
			if not _is_supported_typed_array(array_value):
				_fail_budget(budget)
				return false
			if not _can_reserve_items(array_value.size(), budget):
				return false
			if not _enter_container(array_value, budget):
				return false
			var array_copy: Array = _create_typed_array_copy(array_value)
			for entry: Variant in array_value:
				var entry_output: Array = []
				if not _copy_variant(entry, depth + 1, budget, entry_output):
					_leave_container(budget)
					return false
				array_copy.append(entry_output[0])
			_leave_container(budget)
			output.append(array_copy)
			return true
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			if not _is_supported_typed_dictionary(dictionary_value):
				_fail_budget(budget)
				return false
			if not _can_reserve_items(dictionary_value.size() * 2, budget):
				return false
			if not _enter_container(dictionary_value, budget):
				return false
			var dictionary_copy: Dictionary = _create_typed_dictionary_copy(dictionary_value)
			for key: Variant in dictionary_value:
				var key_output: Array = []
				var value_output: Array = []
				if (
					not _copy_variant(key, depth + 1, budget, key_output)
					or not _copy_variant(
						dictionary_value[key], depth + 1, budget, value_output
					)
				):
					_leave_container(budget)
					return false
				dictionary_copy[key_output[0]] = value_output[0]
			_leave_container(budget)
			output.append(dictionary_copy)
			return true
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, \
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, \
		TYPE_PACKED_VECTOR4_ARRAY:
			var packed_count: int = len(value)
			if not _reserve_items(packed_count, budget):
				return false
			var packed_bytes: int = _estimate_packed_bytes(
				value,
				_MAX_VALUE_BYTES - GFVariantData.get_option_int(budget, "bytes")
			)
			if packed_bytes < 0:
				_fail_budget(budget)
				return false
			if not _reserve_bytes(packed_bytes, budget):
				return false
			output.append(_duplicate_packed_value(value))
			return true
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			_fail_budget(budget)
			return false
		_:
			if not _has_only_finite_float_components(value):
				_fail_budget(budget)
				return false
			if not _reserve_bytes(64, budget):
				return false
			output.append(value)
			return true


static func _is_supported_typed_array(value: Array) -> bool:
	if not value.is_typed():
		return true
	return (
		_is_supported_container_builtin(value.get_typed_builtin())
		and value.get_typed_class_name() == &""
		and value.get_typed_script() == null
	)


static func _create_typed_array_copy(value: Array) -> Array:
	if not value.is_typed():
		return []
	return Array(
		[],
		value.get_typed_builtin(),
		value.get_typed_class_name(),
		value.get_typed_script()
	)


static func _is_supported_typed_dictionary(value: Dictionary) -> bool:
	if not value.is_typed():
		return true
	return (
		_is_supported_container_builtin(value.get_typed_key_builtin())
		and value.get_typed_key_class_name() == &""
		and value.get_typed_key_script() == null
		and _is_supported_container_builtin(value.get_typed_value_builtin())
		and value.get_typed_value_class_name() == &""
		and value.get_typed_value_script() == null
	)


static func _is_supported_container_builtin(builtin_type: int) -> bool:
	return (
		builtin_type != TYPE_OBJECT
		and builtin_type != TYPE_CALLABLE
		and builtin_type != TYPE_SIGNAL
		and builtin_type != TYPE_RID
	)


static func _create_typed_dictionary_copy(value: Dictionary) -> Dictionary:
	if not value.is_typed():
		return {}
	return Dictionary(
		{},
		value.get_typed_key_builtin(),
		value.get_typed_key_class_name(),
		value.get_typed_key_script(),
		value.get_typed_value_builtin(),
		value.get_typed_value_class_name(),
		value.get_typed_value_script()
	)


static func _estimate_packed_bytes(value: Variant, remaining_bytes: int) -> int:
	match typeof(value):
		TYPE_PACKED_BYTE_ARRAY:
			return len(value)
		TYPE_PACKED_INT32_ARRAY:
			return len(value) * 4
		TYPE_PACKED_INT64_ARRAY:
			return len(value) * 8
		TYPE_PACKED_FLOAT32_ARRAY:
			var float32_values: PackedFloat32Array = value
			for number: float in float32_values:
				if is_nan(number) or is_inf(number):
					return -1
			return len(value) * 4
		TYPE_PACKED_FLOAT64_ARRAY:
			var float64_values: PackedFloat64Array = value
			for number: float in float64_values:
				if is_nan(number) or is_inf(number):
					return -1
			return len(value) * 8
		TYPE_PACKED_VECTOR2_ARRAY:
			var vector2_values: PackedVector2Array = value
			for vector: Vector2 in vector2_values:
				if not _is_finite_vector2(vector):
					return -1
			return len(value) * 8
		TYPE_PACKED_VECTOR3_ARRAY:
			var vector3_values: PackedVector3Array = value
			for vector: Vector3 in vector3_values:
				if not _is_finite_vector3(vector):
					return -1
			return len(value) * 12
		TYPE_PACKED_VECTOR4_ARRAY:
			var vector4_values: PackedVector4Array = value
			for vector: Vector4 in vector4_values:
				if not _is_finite_vector4(vector):
					return -1
			return len(value) * 16
		TYPE_PACKED_COLOR_ARRAY:
			var color_values: PackedColorArray = value
			for color: Color in color_values:
				if not _is_finite_color(color):
					return -1
			return len(value) * 16
		TYPE_PACKED_STRING_ARRAY:
			var total: int = 0
			var strings: PackedStringArray = value
			for text: String in strings:
				if text.length() > remaining_bytes - total:
					return -1
				var size: int = text.to_utf8_buffer().size()
				if size > remaining_bytes - total:
					return -1
				total += size
			return total
	return -1


static func _has_only_finite_float_components(value: Variant) -> bool:
	match typeof(value):
		TYPE_VECTOR2:
			var vector_2: Vector2 = value
			return _is_finite_vector2(vector_2)
		TYPE_RECT2:
			var rect: Rect2 = value
			return _is_finite_vector2(rect.position) and _is_finite_vector2(rect.size)
		TYPE_VECTOR3:
			var vector_3: Vector3 = value
			return _is_finite_vector3(vector_3)
		TYPE_TRANSFORM2D:
			var transform_2d: Transform2D = value
			return (
				_is_finite_vector2(transform_2d.x)
				and _is_finite_vector2(transform_2d.y)
				and _is_finite_vector2(transform_2d.origin)
			)
		TYPE_VECTOR4:
			var vector_4: Vector4 = value
			return _is_finite_vector4(vector_4)
		TYPE_PLANE:
			var plane: Plane = value
			return _is_finite_vector3(plane.normal) and _is_finite_number(plane.d)
		TYPE_QUATERNION:
			var quaternion: Quaternion = value
			return (
				_is_finite_number(quaternion.x)
				and _is_finite_number(quaternion.y)
				and _is_finite_number(quaternion.z)
				and _is_finite_number(quaternion.w)
			)
		TYPE_AABB:
			var bounds: AABB = value
			return _is_finite_vector3(bounds.position) and _is_finite_vector3(bounds.size)
		TYPE_BASIS:
			var basis: Basis = value
			return _is_finite_basis(basis)
		TYPE_TRANSFORM3D:
			var transform_3d: Transform3D = value
			return (
				_is_finite_basis(transform_3d.basis)
				and _is_finite_vector3(transform_3d.origin)
			)
		TYPE_PROJECTION:
			var projection: Projection = value
			return (
				_is_finite_vector4(projection.x)
				and _is_finite_vector4(projection.y)
				and _is_finite_vector4(projection.z)
				and _is_finite_vector4(projection.w)
			)
		TYPE_COLOR:
			var color: Color = value
			return _is_finite_color(color)
	return true


static func _is_finite_number(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _is_finite_vector2(value: Vector2) -> bool:
	return _is_finite_number(value.x) and _is_finite_number(value.y)


static func _is_finite_vector3(value: Vector3) -> bool:
	return (
		_is_finite_number(value.x)
		and _is_finite_number(value.y)
		and _is_finite_number(value.z)
	)


static func _is_finite_vector4(value: Vector4) -> bool:
	return (
		_is_finite_number(value.x)
		and _is_finite_number(value.y)
		and _is_finite_number(value.z)
		and _is_finite_number(value.w)
	)


static func _is_finite_basis(value: Basis) -> bool:
	return (
		_is_finite_vector3(value.x)
		and _is_finite_vector3(value.y)
		and _is_finite_vector3(value.z)
	)


static func _is_finite_color(value: Color) -> bool:
	return (
		_is_finite_number(value.r)
		and _is_finite_number(value.g)
		and _is_finite_number(value.b)
		and _is_finite_number(value.a)
	)


static func _duplicate_packed_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_PACKED_BYTE_ARRAY:
			var values: PackedByteArray = value
			return values.duplicate()
		TYPE_PACKED_INT32_ARRAY:
			var values: PackedInt32Array = value
			return values.duplicate()
		TYPE_PACKED_INT64_ARRAY:
			var values: PackedInt64Array = value
			return values.duplicate()
		TYPE_PACKED_FLOAT32_ARRAY:
			var values: PackedFloat32Array = value
			return values.duplicate()
		TYPE_PACKED_FLOAT64_ARRAY:
			var values: PackedFloat64Array = value
			return values.duplicate()
		TYPE_PACKED_STRING_ARRAY:
			var values: PackedStringArray = value
			return values.duplicate()
		TYPE_PACKED_VECTOR2_ARRAY:
			var values: PackedVector2Array = value
			return values.duplicate()
		TYPE_PACKED_VECTOR3_ARRAY:
			var values: PackedVector3Array = value
			return values.duplicate()
		TYPE_PACKED_VECTOR4_ARRAY:
			var values: PackedVector4Array = value
			return values.duplicate()
		TYPE_PACKED_COLOR_ARRAY:
			var values: PackedColorArray = value
			return values.duplicate()
	return null


static func _enter_container(value: Variant, budget: Dictionary) -> bool:
	var active_value: Variant = budget.get("active")
	if not (active_value is Array):
		_fail_budget(budget)
		return false
	var active: Array = active_value
	for active_container: Variant in active:
		if is_same(active_container, value):
			_fail_budget(budget)
			return false
	active.append(value)
	return true


static func _leave_container(budget: Dictionary) -> void:
	var active_value: Variant = budget.get("active")
	if not (active_value is Array):
		_fail_budget(budget)
		return
	var active: Array = active_value
	if not active.is_empty():
		var _removed: Variant = active.pop_back()


static func _reserve_slots(count: int, budget: Dictionary) -> bool:
	var used: int = GFVariantData.get_option_int(budget, "slots")
	if count < 0 or count > _MAX_SLOTS - used:
		_fail_budget(budget)
		return false
	budget["slots"] = used + count
	return true


static func _reserve_items(count: int, budget: Dictionary) -> bool:
	var used: int = GFVariantData.get_option_int(budget, "items")
	if count < 0 or count > _MAX_VALUE_ITEMS - used:
		_fail_budget(budget)
		return false
	budget["items"] = used + count
	return true


static func _can_reserve_items(count: int, budget: Dictionary) -> bool:
	var used: int = GFVariantData.get_option_int(budget, "items")
	if count < 0 or count > _MAX_VALUE_ITEMS - used:
		_fail_budget(budget)
		return false
	return true


static func _reserve_bytes(count: int, budget: Dictionary) -> bool:
	var used: int = GFVariantData.get_option_int(budget, "bytes")
	if count < 0 or count > _MAX_VALUE_BYTES - used:
		_fail_budget(budget)
		return false
	budget["bytes"] = used + count
	return true


static func _fail_budget(budget: Dictionary) -> void:
	budget["failed"] = true


static func _sha(value: Variant) -> String:
	return var_to_str(value).sha256_text()
