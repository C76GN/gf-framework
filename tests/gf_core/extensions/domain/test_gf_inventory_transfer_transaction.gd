extends GutTest


# --- 辅助类型 ---

class HostileMoveInventory:
	extends GFSlotInventoryModel

	var move_override_called: bool = false

	func move_between_slots(
		source_slot: int,
		target_slot: int,
		amount: int = 0
	) -> GFInventoryOperationResult:
		move_override_called = true
		return GFInventoryOperationResult.partial(
			&"",
			amount,
			0,
			&"hostile_override",
			source_slot,
			target_slot
		)


class FinalTargetRuleProbe:
	extends RefCounted

	var callback_count: int = 0
	var commit_phase: bool = false
	var source_rule: GFInventorySlotDefinition = null

	func accept(
		_item_id: StringName,
		_definition: GFInventoryItemDefinition,
		_instance_data: Dictionary,
		_slot_index: int,
		_candidate: GFInventoryReadView
	) -> bool:
		if commit_phase:
			callback_count += 1
			if callback_count == 3:
				source_rule.rejected_item_ids = [&"ore"]
		return true


class ReentrantMutationRuleProbe:
	extends RefCounted

	var attempted: bool = false
	var target: GFSlotInventoryModel = null

	func accept(
		_item_id: StringName,
		_definition: GFInventoryItemDefinition,
		_instance_data: Dictionary,
		_slot_index: int,
		_inventory: Object
	) -> bool:
		if not attempted:
			attempted = true
			target.clear()
		return true


class ReentrantCommitRuleProbe:
	extends RefCounted

	var transaction: GFInventoryTransferTransaction = null
	var nested_results: Array[GFInventoryTransferResult] = []

	func accept(
		_item_id: StringName,
		_definition: GFInventoryItemDefinition,
		_instance_data: Dictionary,
		_slot_index: int,
		_inventory: Object
	) -> bool:
		if transaction != null and nested_results.is_empty():
			nested_results.append(transaction.commit())
		return true


class IncrementalRuleProbe:
	extends RefCounted

	var inventory: GFSlotInventoryModel = null
	var observed_totals: Array[int] = []
	var received_live_model: bool = false

	func accept(
		item_id: StringName,
		_definition: GFInventoryItemDefinition,
		_instance_data: Dictionary,
		_slot_index: int,
		candidate: Object
	) -> bool:
		received_live_model = received_live_model or is_same(candidate, inventory)
		var candidate_total: int = GFVariantData.to_int(
			candidate.call("get_item_total", item_id),
			-1
		)
		observed_totals.append(candidate_total)
		return candidate_total < 1


class MutableInventoryRuleProbe:
	extends RefCounted

	var called: bool = false

	func accept(
		_item_id: StringName,
		_definition: GFInventoryItemDefinition,
		_instance_data: Dictionary,
		_slot_index: int,
		_inventory: GFSlotInventoryModel
	) -> bool:
		called = true
		return true


class ReadViewCaptureRuleProbe:
	extends RefCounted

	var captured_views: Array[GFInventoryReadView] = []

	func accept(
		item_id: StringName,
		_definition: GFInventoryItemDefinition,
		_instance_data: Dictionary,
		_slot_index: int,
		candidate: GFInventoryReadView
	) -> bool:
		captured_views.append(candidate)
		return candidate.get_item_total(item_id) < 1


func test_inventory_transfer_result_rejects_open_success_and_failure_states() -> void:
	var empty_success: GFInventoryTransferResult = GFInventoryTransferResult.new()
	assert_false(empty_success.configure_for_framework(
		GFInventoryTransferResult.STATUS_PREPARED,
		&"",
		0,
		0,
		-1,
		-1,
		-1,
		-1
	), "prepared 必须绑定非空物品、正数量、有效来源槽位和 revision。")
	var zero_transfer: GFInventoryTransferResult = GFInventoryTransferResult.new()
	assert_false(zero_transfer.configure_for_framework(
		GFInventoryTransferResult.STATUS_COMMITTED,
		&"ore",
		2,
		0,
		0,
		0,
		1,
		1
	), "committed 不得报告零转移。")
	var partial_failure: GFInventoryTransferResult = GFInventoryTransferResult.new()
	assert_false(partial_failure.configure_for_framework(
		GFInventoryTransferResult.STATUS_NOT_ENOUGH_SPACE,
		&"ore",
		2,
		1,
		0,
		0,
		1,
		1
	), "原子失败状态不得携带部分写入数量。")
	var open_capacity_failure: GFInventoryTransferResult = GFInventoryTransferResult.new()
	assert_false(open_capacity_failure.configure_for_framework(
		GFInventoryTransferResult.STATUS_NOT_ENOUGH_SPACE,
		&"",
		0,
		0,
		0,
		0,
		1,
		-1
	), "已识别阶段的失败必须闭合物品、数量、来源槽位和 revision 对。")
	var valid_prepared: GFInventoryTransferResult = GFInventoryTransferResult.new()
	assert_true(valid_prepared.configure_for_framework(
		GFInventoryTransferResult.STATUS_PREPARED,
		&"ore",
		2,
		1,
		0,
		-1,
		3,
		4
	), "自动目标槽仍应允许 target_slot=-1。")


func test_cross_inventory_transfer_commits_both_models_once() -> void:
	var source: GFSlotInventoryModel = _make_inventory(1)
	var target: GFSlotInventoryModel = _make_inventory(1)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 5, { "quality": "fine" })))
	var source_revision: int = source.get_revision()
	var target_revision: int = target.get_revision()
	var transaction: GFInventoryTransferTransaction = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		0,
		2,
		false
	)

	assert_true(transaction.is_prepared(), "有效跨库存转移应生成可提交计划。")
	var result: GFInventoryTransferResult = transaction.commit()

	assert_true(result.is_successful(), "预备计划应原子提交。")
	assert_eq(result.get_transferred_amount(), 2, "结果应报告实际转移数量。")
	assert_eq(source.get_stack(0).amount, 3, "来源库存应扣除转移数量。")
	assert_eq(target.get_stack(0).amount, 2, "目标库存应获得转移数量。")
	assert_eq(
		GFVariantData.get_option_string(target.get_stack(0).instance_data, "quality"),
		"fine",
		"实例数据应隔离复制到目标库存。"
	)
	assert_eq(source.get_revision(), source_revision + 1, "来源提交只应递增一次 revision。")
	assert_eq(target.get_revision(), target_revision + 1, "目标提交只应递增一次 revision。")


func test_cross_inventory_transfer_capacity_failure_keeps_state_and_revision() -> void:
	var registry: GFInventoryItemRegistry = GFInventoryItemRegistry.new()
	var definition: GFInventoryItemDefinition = GFInventoryItemDefinition.new()
	definition.item_id = &"ore"
	definition.max_stack_amount = 2
	registry.set_definition(definition)
	var source: GFSlotInventoryModel = _make_inventory(1, registry)
	var target: GFSlotInventoryModel = _make_inventory(1, registry)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 3)))
	assert_true(target.set_stack(0, GFInventoryStack.new(&"ore", 2)))
	var source_before: Dictionary = source.to_dict()
	var target_before: Dictionary = target.to_dict()
	var source_revision: int = source.get_revision()
	var target_revision: int = target.get_revision()
	var source_signal_count: Array[int] = [0]
	var target_signal_count: Array[int] = [0]
	var _source_connect_result: Variant = source.inventory_changed.connect(
		func() -> void: source_signal_count[0] += 1
	)
	var _target_connect_result: Variant = target.inventory_changed.connect(
		func() -> void: target_signal_count[0] += 1
	)

	var transaction: GFInventoryTransferTransaction = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		0,
		1,
		false
	)
	var result: GFInventoryTransferResult = transaction.commit()

	assert_false(result.is_successful(), "目标无容量时必须拒绝完整转移。")
	assert_eq(result.get_status(), GFInventoryTransferResult.STATUS_NOT_ENOUGH_SPACE)
	assert_eq(source.to_dict(), source_before, "失败不得改写来源库存。")
	assert_eq(target.to_dict(), target_before, "失败不得改写目标库存。")
	assert_eq(source.get_revision(), source_revision, "失败不得推进来源 revision。")
	assert_eq(target.get_revision(), target_revision, "失败不得推进目标 revision。")
	assert_eq(source_signal_count[0], 0, "失败不得发出来源信号。")
	assert_eq(target_signal_count[0], 0, "失败不得发出目标信号。")


func test_cross_inventory_transfer_partial_and_full_policy_are_explicit() -> void:
	var registry: GFInventoryItemRegistry = _make_registry(&"ore", 2)
	var source: GFSlotInventoryModel = _make_inventory(1, registry)
	var target: GFSlotInventoryModel = _make_inventory(2, registry)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 5)))
	var full: GFInventoryTransferTransaction = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		-1,
		5,
		false
	)

	assert_false(full.is_prepared(), "完整策略不得把容量不足静默降级为部分转移。")
	assert_eq(full.commit().get_status(), GFInventoryTransferResult.STATUS_NOT_ENOUGH_SPACE)
	assert_eq(source.get_item_total(&"ore"), 5)
	assert_eq(target.get_item_total(&"ore"), 0)

	var partial: GFInventoryTransferTransaction = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		-1,
		5,
		true
	)
	var result: GFInventoryTransferResult = partial.commit()

	assert_true(result.is_successful())
	assert_eq(result.get_requested_amount(), 5)
	assert_eq(result.get_transferred_amount(), 4)
	assert_eq(result.get_remaining_amount(), 1)
	assert_eq(source.get_item_total(&"ore"), 1)
	assert_eq(target.get_item_total(&"ore"), 4)


func test_cross_inventory_transfer_amount_non_positive_means_entire_stack() -> void:
	var source: GFSlotInventoryModel = _make_inventory(1)
	var target: GFSlotInventoryModel = _make_inventory(1)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 3)))

	var transaction: GFInventoryTransferTransaction = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		0,
		0,
		false
	)
	var result: GFInventoryTransferResult = transaction.commit()

	assert_true(result.is_successful())
	assert_eq(result.get_requested_amount(), 3)
	assert_eq(result.get_transferred_amount(), 3)
	assert_true(source.is_slot_empty(0))
	assert_eq(target.get_stack(0).amount, 3)


func test_cross_inventory_transfer_rejects_revision_drift_before_commit() -> void:
	var source: GFSlotInventoryModel = _make_inventory(2)
	var target: GFSlotInventoryModel = _make_inventory(1)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 3)))
	var transaction: GFInventoryTransferTransaction = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		0,
		1,
		false
	)
	assert_true(source.set_stack(1, GFInventoryStack.new(&"other", 1)))
	var target_before: Dictionary = target.to_dict()

	var result: GFInventoryTransferResult = transaction.commit()

	assert_eq(result.get_status(), GFInventoryTransferResult.STATUS_STALE_REVISION)
	assert_eq(source.get_stack(0).amount, 3, "过期计划不得扣除来源槽位。")
	assert_eq(target.to_dict(), target_before, "过期计划不得写入目标。")


func test_cross_inventory_transfer_replans_and_rejects_rule_drift() -> void:
	var source: GFSlotInventoryModel = _make_inventory(1)
	var target: GFSlotInventoryModel = _make_inventory(1)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 2)))
	var slot_rule: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	slot_rule.accepted_item_ids = [&"ore"]
	assert_true(target.set_slot_definition(0, slot_rule))
	var revision_before_rule_drift: int = target.get_revision()
	var transaction: GFInventoryTransferTransaction = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		0,
		1,
		false
	)
	slot_rule.rejected_item_ids = [&"ore"]
	assert_eq(target.get_revision(), revision_before_rule_drift, "资源内部漂移不伪装成模型 mutation。")

	var result: GFInventoryTransferResult = transaction.commit()

	assert_eq(result.get_status(), GFInventoryTransferResult.STATUS_STALE_PLAN)
	assert_eq(source.get_stack(0).amount, 2)
	assert_true(target.is_slot_empty(0))


func test_cross_inventory_final_target_callback_cannot_stale_the_source_plan() -> void:
	var source: GFSlotInventoryModel = _make_inventory(1)
	var target: GFSlotInventoryModel = _make_inventory(1)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 2)))
	var source_rule: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	source_rule.accepted_item_ids = [&"ore"]
	assert_true(source.set_slot_definition(0, source_rule))
	var rule_probe: FinalTargetRuleProbe = FinalTargetRuleProbe.new()
	rule_probe.source_rule = source_rule
	var target_rule: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	target_rule.acceptance_checker = Callable(rule_probe, &"accept")
	assert_true(target.set_slot_definition(0, target_rule))
	var transaction: GFInventoryTransferTransaction = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		0,
		1,
		false
	)
	assert_true(transaction.is_prepared())
	var source_revision: int = source.get_revision()
	var target_revision: int = target.get_revision()
	var source_signal_count: Array[int] = [0]
	var target_signal_count: Array[int] = [0]
	var _source_connection: Variant = source.inventory_changed.connect(
		func() -> void: source_signal_count[0] += 1
	)
	var _target_connection: Variant = target.inventory_changed.connect(
		func() -> void: target_signal_count[0] += 1
	)
	rule_probe.commit_phase = true

	var result: GFInventoryTransferResult = transaction.commit()

	assert_eq(rule_probe.callback_count, 4, "commit 必须执行 initial/final 两轮目标规划。")
	assert_eq(result.get_status(), GFInventoryTransferResult.STATUS_STALE_PLAN)
	assert_eq(source.get_stack(0).amount, 2)
	assert_true(target.is_slot_empty(0))
	assert_eq(source.get_revision(), source_revision)
	assert_eq(target.get_revision(), target_revision)
	assert_eq(source_signal_count[0], 0)
	assert_eq(target_signal_count[0], 0)
	target_rule.acceptance_checker = Callable()


func test_transfer_rule_callback_is_read_only_and_reentrant_mutation_fails_closed() -> void:
	var source: GFSlotInventoryModel = _make_inventory(1)
	var target: GFSlotInventoryModel = _make_inventory(1)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 2)))
	var rule_probe: ReentrantMutationRuleProbe = ReentrantMutationRuleProbe.new()
	rule_probe.target = target
	var slot_rule: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	slot_rule.acceptance_checker = Callable(rule_probe, &"accept")
	assert_true(target.set_slot_definition(0, slot_rule))

	var transaction: GFInventoryTransferTransaction = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		0,
		1,
		false
	)
	slot_rule.acceptance_checker = Callable()

	assert_true(rule_probe.attempted, "规划必须同步调用目标槽规则。")
	assert_true(transaction.is_prepared(), "被拒绝的规则重入不得污染外层规划。")
	assert_true(target.is_slot_empty(0), "prepare 不得产生目标写入。")
	assert_push_error("[GFSlotInventoryModel] clear 失败：库存原子转移期间不允许同步修改库存。请在事务终态后再修改。")


func test_transfer_rule_reentrant_commit_fails_closed_once() -> void:
	var source: GFSlotInventoryModel = _make_inventory(1)
	var target: GFSlotInventoryModel = _make_inventory(1)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 2)))
	var rule_probe: ReentrantCommitRuleProbe = ReentrantCommitRuleProbe.new()
	var slot_rule: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	slot_rule.acceptance_checker = Callable(rule_probe, &"accept")
	assert_true(target.set_slot_definition(0, slot_rule))
	var transaction: GFInventoryTransferTransaction = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		0,
		1,
		false
	)
	rule_probe.transaction = transaction
	var source_revision: int = source.get_revision()
	var target_revision: int = target.get_revision()
	var completed_count: Array[int] = [0]
	var _completed_connect_result: Variant = transaction.completed.connect(
		func(_result: GFInventoryTransferResult) -> void: completed_count[0] += 1
	)

	var result: GFInventoryTransferResult = transaction.commit()

	assert_eq(result.get_status(), GFInventoryTransferResult.STATUS_BUSY)
	assert_eq(rule_probe.nested_results.size(), 1)
	assert_eq(rule_probe.nested_results[0].to_dict(), result.to_dict())
	assert_eq(completed_count[0], 1, "重入和外层提交必须共享唯一终态通知。")
	assert_eq(source.get_stack(0).amount, 2)
	assert_true(target.is_slot_empty(0))
	assert_eq(source.get_revision(), source_revision)
	assert_eq(target.get_revision(), target_revision)
	slot_rule.acceptance_checker = Callable()
	rule_probe.transaction = null


func test_cross_inventory_signals_observe_both_new_states_and_reject_mutation() -> void:
	var source: GFSlotInventoryModel = _make_inventory(1)
	var target: GFSlotInventoryModel = _make_inventory(1)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 3)))
	var observations: Array[String] = []
	var source_removed_callback: Callable = func(
		_slot: int,
		_item_id: StringName,
		_amount: int
	) -> void:
		observations.append("source:%d:%d" % [
			source.get_item_total(&"ore"),
			target.get_item_total(&"ore"),
		])
		target.clear()
	var _source_removed_connect_result: Variant = source.item_removed.connect(
		source_removed_callback
	)
	var target_added_callback: Callable = func(
		_slot: int,
		_item_id: StringName,
		_amount: int
	) -> void:
		observations.append("target:%d:%d" % [
			source.get_item_total(&"ore"),
			target.get_item_total(&"ore"),
		])
		source.clear()
	var _target_added_connect_result: Variant = target.item_added.connect(
		target_added_callback
	)
	var transaction: GFInventoryTransferTransaction = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		0,
		2,
		false
	)
	var completed_callback: Callable = func(
		_result: GFInventoryTransferResult
	) -> void:
		observations.append("terminal:%d:%d" % [
			source.get_item_total(&"ore"),
			target.get_item_total(&"ore"),
		])
		source.clear()
	var _completed_connect_result: Variant = transaction.completed.connect(
		completed_callback
	)

	var result: GFInventoryTransferResult = transaction.commit()

	assert_true(result.is_successful())
	assert_eq(observations, ["source:1:2", "target:1:2", "terminal:1:2"])
	assert_eq(source.get_item_total(&"ore"), 1)
	assert_eq(target.get_item_total(&"ore"), 2)
	assert_push_error("[GFSlotInventoryModel] clear 失败：库存原子转移期间不允许同步修改库存。请在事务终态后再修改。")
	assert_push_error("[GFSlotInventoryModel] clear 失败：库存原子转移期间不允许同步修改库存。请在事务终态后再修改。")
	assert_push_error("[GFSlotInventoryModel] clear 失败：库存原子转移期间不允许同步修改库存。请在事务终态后再修改。")
	source.item_removed.disconnect(source_removed_callback)
	target.item_added.disconnect(target_added_callback)
	transaction.completed.disconnect(completed_callback)


func test_cross_inventory_transfer_can_grow_and_fill_multiple_slots() -> void:
	var registry: GFInventoryItemRegistry = _make_registry(&"ore", 2)
	var source: GFSlotInventoryModel = _make_inventory(1, registry)
	var target: GFSlotInventoryModel = _make_inventory(0, registry)
	target.allow_growth = true
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 5)))

	var result: GFInventoryTransferResult = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		-1,
		5,
		false
	).commit()

	assert_true(result.is_successful())
	assert_eq(target.get_slot_count(), 3)
	assert_eq(target.get_stack(0).amount, 2)
	assert_eq(target.get_stack(1).amount, 2)
	assert_eq(target.get_stack(2).amount, 1)


func test_same_inventory_transfer_preserves_existing_move_semantics_atomically() -> void:
	var inventory: GFSlotInventoryModel = _make_inventory(2)
	assert_true(inventory.set_stack(0, GFInventoryStack.new(&"ore", 4, { "batch": 7 })))
	var revision: int = inventory.get_revision()
	var transaction: GFInventoryTransferTransaction = GFInventoryTransferTransaction.prepare(
		inventory,
		inventory,
		0,
		1,
		2,
		false
	)

	var result: GFInventoryTransferResult = transaction.commit()

	assert_true(result.is_successful())
	assert_eq(inventory.get_stack(0).amount, 2)
	assert_eq(inventory.get_stack(1).amount, 2)
	assert_eq(inventory.get_revision(), revision + 1)
	assert_eq(transaction.commit().to_dict(), result.to_dict(), "一次性句柄重复提交应返回首次终态。")


func test_same_inventory_commit_does_not_dispatch_public_move_override() -> void:
	var inventory: HostileMoveInventory = HostileMoveInventory.new()
	inventory.set_slot_count(2)
	assert_true(inventory.set_stack(0, GFInventoryStack.new(&"ore", 3)))
	var revision: int = inventory.get_revision()
	var transaction: GFInventoryTransferTransaction = GFInventoryTransferTransaction.prepare(
		inventory,
		inventory,
		0,
		1,
		2,
		false
	)

	var result: GFInventoryTransferResult = transaction.commit()

	assert_true(result.is_successful(), "同模型提交应使用已验证候选，不依赖可重写公共方法。")
	assert_false(inventory.move_override_called, "最终提交不得动态调用 move_between_slots override。")
	assert_eq(inventory.get_stack(0).amount, 1)
	assert_eq(inventory.get_stack(1).amount, 2)
	assert_eq(inventory.get_revision(), revision + 1)


func test_slot_inventory_revision_ignores_no_ops_and_rejections() -> void:
	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	var initial_revision: int = inventory.get_revision()
	inventory.set_slot_count(0)
	inventory.clear()
	inventory.registry = null
	inventory.allow_growth = false
	assert_eq(inventory.get_revision(), initial_revision)

	inventory.set_slot_count(1)
	var structural_revision: int = inventory.get_revision()
	inventory.set_slot_count(1)
	assert_true(inventory.set_stack(0, null))
	assert_true(inventory.clear_slot(0))
	assert_true(inventory.set_slot_definition(0, null))
	var rejected: GFInventoryOperationResult = inventory.add_item_to_slot(4, &"ore", 1)

	assert_false(rejected.ok)
	assert_eq(inventory.get_revision(), structural_revision, "no-op 和拒绝不得推进 revision。")


func test_slot_definition_array_requires_exact_slot_count_and_rejects_atomically() -> void:
	var inventory: GFSlotInventoryModel = _make_inventory(2)
	var slot_rule: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	slot_rule.accepted_item_ids = [&"ore"]
	var revision: int = inventory.get_revision()
	var signal_count: Array[int] = [0]
	var _connection: Variant = inventory.inventory_changed.connect(
		func() -> void: signal_count[0] += 1
	)

	inventory.slot_definitions = [slot_rule]

	assert_push_error("[GFSlotInventoryModel] slot_definitions 失败：规则数量必须与槽位数量一致")
	assert_eq(inventory.slot_definitions.size(), 2)
	assert_null(inventory.get_slot_definition(0))
	assert_null(inventory.get_slot_definition(1))
	assert_eq(inventory.get_revision(), revision)
	assert_eq(signal_count[0], 0)

	inventory.slot_definitions = [slot_rule, null]

	assert_eq(inventory.get_slot_definition(0), slot_rule)
	assert_null(inventory.get_slot_definition(1))
	assert_eq(inventory.get_revision(), revision + 1)


func test_growth_appends_only_unrestricted_null_slot_definitions() -> void:
	var inventory: GFSlotInventoryModel = _make_inventory(0, _make_registry(&"ore", 1))
	inventory.allow_growth = true
	var future_rule: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	future_rule.rejected_item_ids = [&"ore"]
	var revision: int = inventory.get_revision()
	var signal_count: Array[int] = [0]
	var _connection: Variant = inventory.inventory_changed.connect(
		func() -> void: signal_count[0] += 1
	)

	inventory.slot_definitions = [future_rule]

	assert_push_error("[GFSlotInventoryModel] slot_definitions 失败：规则数量必须与槽位数量一致")
	assert_eq(inventory.get_revision(), revision)
	assert_eq(inventory.slot_definitions.size(), 0)
	assert_eq(signal_count[0], 0)

	var result: GFInventoryOperationResult = inventory.add_item(&"ore", 2)

	assert_true(result.ok)
	assert_eq(result.accepted_amount, 2)
	assert_eq(inventory.get_slot_count(), 2)
	assert_eq(inventory.slot_definitions.size(), 2)
	assert_null(inventory.get_slot_definition(0))
	assert_null(inventory.get_slot_definition(1))
	assert_eq(inventory.get_revision(), revision + 1, "一次成长 mutation 只推进一次 revision。")
	assert_eq(signal_count[0], 1)
	assert_true(inventory.set_slot_definition(1, future_rule), "应先扩槽，再为现有索引配置规则。")


func test_transfer_rejects_deep_instance_data_without_writes() -> void:
	var metadata: Dictionary = {}
	var cursor: Dictionary = metadata
	for index: int in range(40):
		var child: Dictionary = { "index": index }
		cursor["child"] = child
		cursor = child
	var source: GFSlotInventoryModel = _make_inventory(1)
	var stack: GFInventoryStack = GFInventoryStack.new()
	stack.item_id = &"ore"
	stack.amount = 1
	stack.instance_data = metadata
	assert_true(source.set_stack(0, stack))
	var target: GFSlotInventoryModel = _make_inventory(1)
	var source_before: Dictionary = source.to_dict()
	var target_before: Dictionary = target.to_dict()

	var transaction: GFInventoryTransferTransaction = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		0,
		1,
		false
	)
	var result: GFInventoryTransferResult = transaction.commit()

	assert_eq(result.get_status(), GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA)
	assert_eq(source.to_dict(), source_before)
	assert_eq(target.to_dict(), target_before)


func test_transfer_rejects_cyclic_instance_data_without_writes() -> void:
	var source: GFSlotInventoryModel = _make_inventory(1)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 1)))
	var cyclic_data: Dictionary = {}
	cyclic_data["self"] = cyclic_data
	_inject_instance_data(source, cyclic_data)
	var target: GFSlotInventoryModel = _make_inventory(1)
	var source_revision: int = source.get_revision()
	var target_revision: int = target.get_revision()
	var source_signal_count: Array[int] = [0]
	var target_signal_count: Array[int] = [0]
	var _source_connection: Variant = source.inventory_changed.connect(
		func() -> void: source_signal_count[0] += 1
	)
	var _target_connection: Variant = target.inventory_changed.connect(
		func() -> void: target_signal_count[0] += 1
	)

	var transaction: GFInventoryTransferTransaction = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		0,
		1,
		false
	)
	var result: GFInventoryTransferResult = transaction.commit()

	assert_eq(result.get_status(), GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA)
	assert_eq(source.get_item_total(&"ore"), 1)
	assert_true(target.is_slot_empty(0))
	assert_eq(source.get_revision(), source_revision)
	assert_eq(target.get_revision(), target_revision)
	assert_eq(source_signal_count[0], 0)
	assert_eq(target_signal_count[0], 0)


func test_transfer_rejects_oversized_string_and_packed_metadata_without_writes() -> void:
	_assert_metadata_transfer_rejected_without_effect(
		{ "text": "x".repeat(1048577) },
		"超过字节预算的 String 必须在分配 UTF-8 缓冲前闭合失败。"
	)
	var oversized_packed: PackedStringArray = PackedStringArray()
	var _resize_result: int = oversized_packed.resize(32769)
	_assert_metadata_transfer_rejected_without_effect(
		{ "values": oversized_packed },
		"超过条目预算的 PackedStringArray 必须在逐项扫描前闭合失败。"
	)


func test_transfer_rejects_oversized_callable_bind_without_writes() -> void:
	var source: GFSlotInventoryModel = _make_inventory(1)
	var target: GFSlotInventoryModel = _make_inventory(1)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 1)))
	var oversized_bind: PackedByteArray = PackedByteArray()
	var _resize_result: int = oversized_bind.resize(32769)
	var slot_rule: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	slot_rule.acceptance_checker = Callable(
		self,
		"_accept_with_bound_payload"
	).bind(oversized_bind)
	assert_true(target.set_slot_definition(0, slot_rule))
	var source_revision: int = source.get_revision()
	var target_revision: int = target.get_revision()
	var source_signal_count: Array[int] = [0]
	var target_signal_count: Array[int] = [0]
	var _source_connection: Variant = source.inventory_changed.connect(
		func() -> void: source_signal_count[0] += 1
	)
	var _target_connection: Variant = target.inventory_changed.connect(
		func() -> void: target_signal_count[0] += 1
	)

	var result: GFInventoryTransferResult = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		0,
		1,
		false
	).commit()

	assert_eq(result.get_status(), GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA)
	assert_eq(source.get_item_total(&"ore"), 1)
	assert_true(target.is_slot_empty(0))
	assert_eq(source.get_revision(), source_revision)
	assert_eq(target.get_revision(), target_revision)
	assert_eq(source_signal_count[0], 0)
	assert_eq(target_signal_count[0], 0)


func test_transfer_rejects_oversized_item_id_before_snapshot_serialization() -> void:
	var source: GFSlotInventoryModel = _make_inventory(1)
	var target: GFSlotInventoryModel = _make_inventory(1)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 1)))
	var oversized_item_id: StringName = StringName("x".repeat(1048577))
	_inject_item_id(source, oversized_item_id)
	var source_revision: int = source.get_revision()
	var target_revision: int = target.get_revision()
	var source_signal_count: Array[int] = [0]
	var target_signal_count: Array[int] = [0]
	var _source_connection: Variant = source.inventory_changed.connect(
		func() -> void: source_signal_count[0] += 1
	)
	var _target_connection: Variant = target.inventory_changed.connect(
		func() -> void: target_signal_count[0] += 1
	)

	var result: GFInventoryTransferResult = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		0,
		1,
		false
	).commit()

	assert_eq(result.get_status(), GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA)
	var source_stack: GFInventoryStack = source.get_stack(0)
	assert_not_null(source_stack)
	if source_stack != null:
		assert_eq(source_stack.item_id, oversized_item_id)
		assert_eq(source_stack.amount, 1)
	assert_true(target.is_slot_empty(0))
	assert_eq(source.get_revision(), source_revision)
	assert_eq(target.get_revision(), target_revision)
	assert_eq(source_signal_count[0], 0)
	assert_eq(target_signal_count[0], 0)


func test_transfer_rejects_oversized_slot_graph_without_writes() -> void:
	var source: GFSlotInventoryModel = _make_inventory(4097)
	var target: GFSlotInventoryModel = _make_inventory(1)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 1)))
	var source_revision: int = source.get_revision()
	var target_revision: int = target.get_revision()
	var source_signal_count: Array[int] = [0]
	var target_signal_count: Array[int] = [0]
	var _source_connection: Variant = source.inventory_changed.connect(
		func() -> void: source_signal_count[0] += 1
	)
	var _target_connection: Variant = target.inventory_changed.connect(
		func() -> void: target_signal_count[0] += 1
	)

	var result: GFInventoryTransferResult = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		0,
		1,
		false
	).commit()

	assert_eq(result.get_status(), GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA)
	assert_eq(source.get_item_total(&"ore"), 1)
	assert_true(target.is_slot_empty(0))
	assert_eq(source.get_revision(), source_revision)
	assert_eq(target.get_revision(), target_revision)
	assert_eq(source_signal_count[0], 0)
	assert_eq(target_signal_count[0], 0)


func test_transfer_preserves_primitive_typed_metadata_containers() -> void:
	var typed_numbers: Array[int] = [2, 3, 5]
	var typed_lookup: Dictionary[String, int] = { "level": 7 }
	var source: GFSlotInventoryModel = _make_inventory(1)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 2)))
	_inject_instance_data(source, {
		"numbers": typed_numbers,
		"lookup": typed_lookup,
	})
	var target: GFSlotInventoryModel = _make_inventory(1)

	var result: GFInventoryTransferResult = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		0,
		1,
		false
	).commit()

	assert_true(result.is_successful())
	var source_data: Dictionary = source.get_stack(0).instance_data
	var target_data: Dictionary = target.get_stack(0).instance_data
	var source_numbers_value: Variant = source_data["numbers"]
	var target_numbers_value: Variant = target_data["numbers"]
	var source_lookup_value: Variant = source_data["lookup"]
	var target_lookup_value: Variant = target_data["lookup"]
	assert_true(source_numbers_value is Array)
	assert_true(target_numbers_value is Array)
	assert_true(source_lookup_value is Dictionary)
	assert_true(target_lookup_value is Dictionary)
	var source_numbers: Array = source_numbers_value
	var target_numbers: Array = target_numbers_value
	var source_lookup: Dictionary = source_lookup_value
	var target_lookup: Dictionary = target_lookup_value
	assert_true(source_numbers.is_same_typed(typed_numbers))
	assert_true(target_numbers.is_same_typed(typed_numbers))
	assert_true(source_lookup.is_same_typed(typed_lookup))
	assert_true(target_lookup.is_same_typed(typed_lookup))


func test_transfer_rejects_object_typed_metadata_contracts_without_writes() -> void:
	var object_array: Array[GFInventoryStack] = []
	_assert_metadata_transfer_rejected_without_effect(
		{ "objects": object_array },
		"即使容器为空，携带 Object/class/script 元数据类型合约也必须闭合失败。"
	)
	var object_dictionary: Dictionary[String, GFInventoryStack] = {}
	_assert_metadata_transfer_rejected_without_effect(
		{ "objects": object_dictionary },
		"Dictionary 的 Object/class/script 值类型合约不得绕过 no-Object 策略。"
	)


func test_transfer_rejects_empty_capability_typed_metadata_contracts_without_writes() -> void:
	var forbidden_builtins: Array[int] = [TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]
	for builtin_type: int in forbidden_builtins:
		var typed_array: Array = Array([], builtin_type, &"", null)
		_assert_metadata_transfer_rejected_without_effect(
			{ "value": typed_array },
			"空 Array 的 capability 类型元数据必须闭合拒绝（type=%d）。" % builtin_type
		)
		var typed_key_dictionary: Dictionary = Dictionary(
			{},
			builtin_type,
			&"",
			null,
			TYPE_INT,
			&"",
			null
		)
		_assert_metadata_transfer_rejected_without_effect(
			{ "value": typed_key_dictionary },
			"空 Dictionary 的 capability 键类型元数据必须闭合拒绝（type=%d）。" % builtin_type
		)
		var typed_value_dictionary: Dictionary = Dictionary(
			{},
			TYPE_STRING,
			&"",
			null,
			builtin_type,
			&"",
			null
		)
		_assert_metadata_transfer_rejected_without_effect(
			{ "value": typed_value_dictionary },
			"空 Dictionary 的 capability 值类型元数据必须闭合拒绝（type=%d）。" % builtin_type
		)


func test_transfer_rejects_every_non_finite_float_bearing_variant_without_writes() -> void:
	var transform_2d: Transform2D = Transform2D.IDENTITY
	transform_2d.origin = Vector2(NAN, 0.0)
	var basis: Basis = Basis.IDENTITY
	basis.x = Vector3(NAN, 0.0, 0.0)
	var transform_3d: Transform3D = Transform3D.IDENTITY
	transform_3d.origin = Vector3(0.0, INF, 0.0)
	var projection: Projection = Projection.IDENTITY
	projection.x = Vector4(0.0, 0.0, NAN, 0.0)
	var cases: Array[Dictionary] = [
		{ "name": "Float", "value": NAN },
		{ "name": "Vector2", "value": Vector2(INF, 0.0) },
		{ "name": "Rect2", "value": Rect2(Vector2.ZERO, Vector2(NAN, 1.0)) },
		{ "name": "Vector3", "value": Vector3(0.0, NAN, 0.0) },
		{ "name": "Transform2D", "value": transform_2d },
		{ "name": "Vector4", "value": Vector4(0.0, 0.0, 0.0, INF) },
		{ "name": "Plane", "value": Plane(0.0, NAN, 0.0, 0.0) },
		{ "name": "Quaternion", "value": Quaternion(0.0, 0.0, INF, 1.0) },
		{ "name": "AABB", "value": AABB(Vector3.ZERO, Vector3(NAN, 1.0, 1.0)) },
		{ "name": "Basis", "value": basis },
		{ "name": "Transform3D", "value": transform_3d },
		{ "name": "Projection", "value": projection },
		{ "name": "Color", "value": Color(1.0, NAN, 1.0, 1.0) },
		{ "name": "PackedFloat32Array", "value": PackedFloat32Array([NAN]) },
		{ "name": "PackedFloat64Array", "value": PackedFloat64Array([INF]) },
		{ "name": "PackedVector2Array", "value": PackedVector2Array([Vector2(NAN, 0.0)]) },
		{ "name": "PackedVector3Array", "value": PackedVector3Array([Vector3(0.0, INF, 0.0)]) },
		{ "name": "PackedVector4Array", "value": PackedVector4Array([Vector4(0.0, NAN, 0.0, 0.0)]) },
		{ "name": "PackedColorArray", "value": PackedColorArray([Color(1.0, 1.0, INF, 1.0)]) },
	]
	for case_data: Dictionary in cases:
		_assert_metadata_transfer_rejected_without_effect(
			{ "value": case_data["value"] },
			"%s 含非有限浮点时必须闭合失败且零可见写入。" % case_data["name"]
		)


func test_full_transfer_rule_reads_incremental_isolated_candidate_state() -> void:
	var registry: GFInventoryItemRegistry = _make_registry(&"ore", 1)
	var source: GFSlotInventoryModel = _make_inventory(1, registry)
	var target: GFSlotInventoryModel = _make_inventory(2, registry)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 2)))
	var rule_probe: IncrementalRuleProbe = IncrementalRuleProbe.new()
	rule_probe.inventory = target
	var slot_rule: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	slot_rule.acceptance_checker = Callable(rule_probe, &"accept")
	assert_true(target.set_slot_definition(0, slot_rule))
	assert_true(target.set_slot_definition(1, slot_rule))
	var source_revision: int = source.get_revision()
	var target_revision: int = target.get_revision()
	var source_signal_count: Array[int] = [0]
	var target_signal_count: Array[int] = [0]
	var _source_connection: Variant = source.inventory_changed.connect(
		func() -> void: source_signal_count[0] += 1
	)
	var _target_connection: Variant = target.inventory_changed.connect(
		func() -> void: target_signal_count[0] += 1
	)

	var result: GFInventoryTransferResult = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		-1,
		2,
		false
	).commit()

	assert_eq(result.get_status(), GFInventoryTransferResult.STATUS_NOT_ENOUGH_SPACE)
	assert_false(rule_probe.received_live_model, "规则不得获得可变 live model。")
	assert_true(rule_probe.observed_totals.has(1), "后续槽规则必须看到此前候选槽已加入的数量。")
	assert_eq(source.get_item_total(&"ore"), 2)
	assert_eq(target.get_item_total(&"ore"), 0)
	assert_eq(source.get_revision(), source_revision)
	assert_eq(target.get_revision(), target_revision)
	assert_eq(source_signal_count[0], 0)
	assert_eq(target_signal_count[0], 0)
	slot_rule.acceptance_checker = Callable()


func test_direct_mutation_rule_uses_the_same_incremental_read_only_projection() -> void:
	var registry: GFInventoryItemRegistry = _make_registry(&"ore", 1)
	var inventory: GFSlotInventoryModel = _make_inventory(2, registry)
	var rule_probe: IncrementalRuleProbe = IncrementalRuleProbe.new()
	rule_probe.inventory = inventory
	var slot_rule: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	slot_rule.acceptance_checker = Callable(rule_probe, &"accept")
	assert_true(inventory.set_slot_definition(0, slot_rule))
	assert_true(inventory.set_slot_definition(1, slot_rule))

	var result: GFInventoryOperationResult = inventory.add_item(&"ore", 2)

	assert_eq(result.accepted_amount, 1)
	assert_eq(inventory.get_item_total(&"ore"), 1)
	assert_false(rule_probe.received_live_model, "普通 mutation 也不得向规则暴露可变 live model。")
	assert_true(rule_probe.observed_totals.has(1), "普通 mutation 的后续规则必须看到此前写入。")
	slot_rule.acceptance_checker = Callable()


func test_rule_typed_as_mutable_model_fails_closed_without_engine_error() -> void:
	var inventory: GFSlotInventoryModel = _make_inventory(1)
	var rule_probe: MutableInventoryRuleProbe = MutableInventoryRuleProbe.new()
	var slot_rule: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	slot_rule.acceptance_checker = Callable(rule_probe, &"accept")
	assert_true(inventory.set_slot_definition(0, slot_rule))
	var revision: int = inventory.get_revision()

	var result: GFInventoryOperationResult = inventory.add_item_to_slot(0, &"ore", 1)

	assert_false(result.ok)
	assert_eq(result.accepted_amount, 0)
	assert_true(inventory.is_slot_empty(0))
	assert_eq(inventory.get_revision(), revision)
	assert_false(rule_probe.called, "不兼容的具名规则回调不得被调用。")
	assert_engine_error_count(0, "不兼容的规则回调必须在调用前静默失败关闭。")
	slot_rule.acceptance_checker = Callable()


func test_anonymous_acceptance_checker_fails_closed_without_engine_error() -> void:
	var inventory: GFSlotInventoryModel = _make_inventory(1)
	var callback_called: Array[bool] = [false]
	var slot_rule: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	slot_rule.acceptance_checker = func(
		_item_id: StringName,
		_definition: GFInventoryItemDefinition,
		_instance_data: Dictionary,
		_slot_index: int,
		_candidate: GFInventoryReadView
	) -> bool:
		callback_called[0] = true
		return true
	assert_true(inventory.set_slot_definition(0, slot_rule))
	var revision: int = inventory.get_revision()

	var result: GFInventoryOperationResult = inventory.add_item_to_slot(0, &"ore", 1)

	assert_false(result.ok)
	assert_eq(result.accepted_amount, 0)
	assert_false(callback_called[0], "无法反射签名的匿名规则回调不得被调用。")
	assert_true(inventory.is_slot_empty(0))
	assert_eq(inventory.get_revision(), revision)
	assert_engine_error_count(0, "匿名规则回调必须在调用前静默失败关闭。")
	slot_rule.acceptance_checker = Callable()


func test_partial_transfer_commits_only_the_incrementally_accepted_candidate() -> void:
	var registry: GFInventoryItemRegistry = _make_registry(&"ore", 1)
	var source: GFSlotInventoryModel = _make_inventory(1, registry)
	var target: GFSlotInventoryModel = _make_inventory(2, registry)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 2)))
	var rule_probe: ReadViewCaptureRuleProbe = ReadViewCaptureRuleProbe.new()
	var slot_rule: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	slot_rule.acceptance_checker = Callable(rule_probe, &"accept")
	assert_true(target.set_slot_definition(0, slot_rule))
	assert_true(target.set_slot_definition(1, slot_rule))
	var source_revision: int = source.get_revision()
	var target_revision: int = target.get_revision()

	var result: GFInventoryTransferResult = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		-1,
		2,
		true
	).commit()

	assert_true(result.is_successful())
	assert_eq(result.get_transferred_amount(), 1)
	assert_eq(source.get_item_total(&"ore"), 1)
	assert_eq(target.get_item_total(&"ore"), 1)
	assert_eq(source.get_revision(), source_revision + 1)
	assert_eq(target.get_revision(), target_revision + 1)
	assert_false(rule_probe.captured_views.is_empty())
	for captured_view: GFInventoryReadView in rule_probe.captured_views:
		assert_false(captured_view.is_active(), "回调返回后捕获的只读投影必须失效。")
		assert_eq(captured_view.get_slot_count(), 0, "失效投影不得保留候选引用。")
	slot_rule.acceptance_checker = Callable()


func test_expired_weak_models_close_once_without_retaining_inventory() -> void:
	var transaction: GFInventoryTransferTransaction = _prepare_ephemeral_transfer()
	assert_true(transaction.is_prepared())
	var completed_count: Array[int] = [0]
	var _connection: Variant = transaction.completed.connect(
		func(_result: GFInventoryTransferResult) -> void: completed_count[0] += 1
	)

	var first_result: GFInventoryTransferResult = transaction.commit()
	var repeated_result: GFInventoryTransferResult = transaction.commit()

	assert_eq(first_result.get_status(), GFInventoryTransferResult.STATUS_STALE_REVISION)
	assert_eq(repeated_result.to_dict(), first_result.to_dict())
	assert_true(transaction.is_completed())
	assert_false(transaction.is_prepared())
	assert_eq(completed_count[0], 1, "弱引用失效与重复 commit 只能闭合并通知一次。")


func _make_inventory(
	slot_count: int,
	registry: GFInventoryItemRegistry = null
) -> GFSlotInventoryModel:
	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.registry = registry
	inventory.set_slot_count(slot_count)
	return inventory


func _make_registry(item_id: StringName, max_stack_amount: int) -> GFInventoryItemRegistry:
	var definition: GFInventoryItemDefinition = GFInventoryItemDefinition.new()
	definition.item_id = item_id
	definition.max_stack_amount = max_stack_amount
	var registry: GFInventoryItemRegistry = GFInventoryItemRegistry.new()
	registry.set_definition(definition)
	return registry


func _inject_instance_data(inventory: GFSlotInventoryModel, instance_data: Dictionary) -> void:
	var lock_owner: RefCounted = RefCounted.new()
	assert_true(inventory.lock_inventory_transfer_for_framework(lock_owner))
	var stack: GFInventoryStack = inventory.get_inventory_transfer_stack_for_framework(lock_owner, 0)
	stack.instance_data = instance_data
	inventory.unlock_inventory_transfer_for_framework(lock_owner)


func _inject_item_id(inventory: GFSlotInventoryModel, item_id: StringName) -> void:
	var lock_owner: RefCounted = RefCounted.new()
	assert_true(inventory.lock_inventory_transfer_for_framework(lock_owner))
	var stack: GFInventoryStack = inventory.get_inventory_transfer_stack_for_framework(lock_owner, 0)
	stack.item_id = item_id
	inventory.unlock_inventory_transfer_for_framework(lock_owner)


func _accept_with_bound_payload(
	_item_id: StringName,
	_definition: GFInventoryItemDefinition,
	_instance_data: Dictionary,
	_slot_index: int,
	_candidate: GFInventoryReadView,
	_payload: Variant
) -> bool:
	return true


func _assert_metadata_transfer_rejected_without_effect(
	instance_data: Dictionary,
	message: String
) -> void:
	var source: GFSlotInventoryModel = _make_inventory(1)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 1)))
	_inject_instance_data(source, instance_data)
	var target: GFSlotInventoryModel = _make_inventory(1)
	var source_revision: int = source.get_revision()
	var target_revision: int = target.get_revision()
	var source_signal_count: Array[int] = [0]
	var target_signal_count: Array[int] = [0]
	var _source_connection: Variant = source.inventory_changed.connect(
		func() -> void: source_signal_count[0] += 1
	)
	var _target_connection: Variant = target.inventory_changed.connect(
		func() -> void: target_signal_count[0] += 1
	)
	var transaction: GFInventoryTransferTransaction = GFInventoryTransferTransaction.prepare(
		source,
		target,
		0,
		0,
		1,
		false
	)

	assert_eq(
		transaction.commit().get_status(),
		GFInventoryTransferResult.STATUS_UNSUPPORTED_DATA,
		message
	)
	assert_eq(source.get_item_total(&"ore"), 1, message)
	assert_true(target.is_slot_empty(0), message)
	assert_eq(source.get_revision(), source_revision, message)
	assert_eq(target.get_revision(), target_revision, message)
	assert_eq(source_signal_count[0], 0, message)
	assert_eq(target_signal_count[0], 0, message)


func _prepare_ephemeral_transfer() -> GFInventoryTransferTransaction:
	var source: GFSlotInventoryModel = _make_inventory(1)
	var target: GFSlotInventoryModel = _make_inventory(1)
	assert_true(source.set_stack(0, GFInventoryStack.new(&"ore", 1)))
	return GFInventoryTransferTransaction.prepare(source, target, 0, 0, 1, false)
