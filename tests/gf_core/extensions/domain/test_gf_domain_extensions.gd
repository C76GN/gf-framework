## 测试通用领域扩展中的特征、库存与槽位集合。
extends GutTest


# --- 常量 ---

const GFDerivedAttributeRuleBase = preload("res://addons/gf/extensions/domain/attributes/gf_derived_attribute_rule.gd")


# --- 测试方法 ---

## 验证特征集合按优先级合并数值。
func test_trait_set_calculates_number() -> void:
	var trait_set: GFTraitSet = GFTraitSet.new()

	var add_trait: GFTrait = GFTrait.new()
	add_trait.target_id = &"power"
	add_trait.value = 5.0
	add_trait.combine_mode = GFTrait.CombineMode.ADD
	add_trait.priority = 0

	var multiply_trait: GFTrait = GFTrait.new()
	multiply_trait.target_id = &"power"
	multiply_trait.value = 2.0
	multiply_trait.combine_mode = GFTrait.CombineMode.MULTIPLY
	multiply_trait.priority = 1

	trait_set.add_trait(multiply_trait)
	trait_set.add_trait(add_trait)

	assert_eq(trait_set.calculate_number(&"power", 10.0), 30.0, "应先加值再乘值。")


func test_trait_set_ignores_non_finite_traits_and_results() -> void:
	var trait_set: GFTraitSet = GFTraitSet.new()
	var invalid_trait: GFTrait = GFTrait.new()
	invalid_trait.target_id = &"power"
	invalid_trait.value = NAN
	invalid_trait.combine_mode = GFTrait.CombineMode.SET
	var overflow_trait: GFTrait = GFTrait.new()
	overflow_trait.target_id = &"power"
	overflow_trait.value = 1.0e308
	overflow_trait.combine_mode = GFTrait.CombineMode.MULTIPLY
	trait_set.add_trait(invalid_trait)
	trait_set.add_trait(overflow_trait)

	var result: float = trait_set.calculate_number(&"power", 1.0e308)

	assert_false(is_nan(result), "Trait 计算结果不应传播 NaN。")
	assert_false(is_inf(result), "Trait 计算结果不应传播 Infinity。")
	assert_eq(result, 1.0e308, "无效 trait 或溢出结果应保持最后一个有限值。")


## 验证库存模型可增减、序列化和恢复。
func test_inventory_model_serializes_items() -> void:
	var inventory: GFInventoryModel = GFInventoryModel.new()
	inventory.add_item(&"item_a", 2, { "tag": "test" })
	inventory.add_item(&"item_a", 3)

	assert_eq(inventory.get_item_amount(&"item_a"), 5, "同一 item_id 应堆叠数量。")
	assert_true(inventory.remove_item(&"item_a", 4), "数量足够时应允许移除。")
	assert_eq(inventory.get_item_amount(&"item_a"), 1, "移除后数量应更新。")

	var restored: GFInventoryModel = GFInventoryModel.new()
	restored.from_dict(inventory.to_dict())

	assert_eq(restored.get_item_amount(&"item_a"), 1, "恢复后数量应一致。")
	assert_eq(GFVariantData.get_option_string(restored.get_item_metadata(&"item_a"), "tag"), "test", "恢复后元数据应一致。")


func test_inventory_model_from_dict_rejects_invalid_stacks() -> void:
	var inventory: GFInventoryModel = GFInventoryModel.new()

	inventory.from_dict({
		"items": {
			"": { "amount": 5, "metadata": {} },
			"zero": { "amount": 0, "metadata": {} },
			"negative": { "amount": -2, "metadata": {} },
			"valid": { "amount": 3, "metadata": { "tag": "kept" } },
		},
	})

	assert_eq(inventory.get_item_amount(&""), 0, "空 item_id 不应从存档恢复。")
	assert_eq(inventory.get_item_amount(&"zero"), 0, "非正数量不应从存档恢复。")
	assert_eq(inventory.get_item_amount(&"negative"), 0, "负数数量不应从存档恢复。")
	assert_eq(inventory.get_item_amount(&"valid"), 3, "合法堆叠应正常恢复。")
	assert_eq(GFVariantData.get_option_string(inventory.get_item_metadata(&"valid"), "tag"), "kept", "合法堆叠元数据应保留。")


## 验证槽位库存遵守堆叠容量、堆叠数量上限与序列化。
func test_slot_inventory_respects_stack_rules_and_serializes() -> void:
	var definition: GFInventoryItemDefinition = GFInventoryItemDefinition.new()
	definition.item_id = &"item_a"
	definition.max_stack_amount = 5
	definition.max_stack_count = 2
	definition.stack_key_fields = PackedStringArray(["grade"])

	var registry: GFInventoryItemRegistry = GFInventoryItemRegistry.new()
	registry.set_definition(definition)

	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.registry = registry
	inventory.set_slot_count(3)

	var result: GFInventoryOperationResult = inventory.add_item(&"item_a", 12, { "grade": "basic" })

	assert_false(result.ok, "容量不足时应返回部分成功。")
	assert_eq(result.accepted_amount, 10, "两个堆叠最多应接受 10 个。")
	assert_eq(result.remaining_amount, 2, "剩余数量应写入操作结果。")
	assert_eq(inventory.get_item_total(&"item_a"), 10, "库存总数应统计全部兼容堆叠。")
	assert_eq(inventory.get_occupied_slot_indices().size(), 2, "应占用两个槽位。")

	var restored: GFSlotInventoryModel = GFSlotInventoryModel.new()
	restored.registry = registry
	restored.from_dict(inventory.to_dict())

	assert_eq(restored.get_slot_count(), 3, "恢复后槽位数量应一致。")
	assert_eq(restored.get_item_total(&"item_a"), 10, "恢复后物品总数应一致。")


func test_slot_inventory_shrink_removes_dropped_slots_from_index_and_signals() -> void:
	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.set_slot_count(2)
	var _add_first_result: Variant = inventory.add_item_to_slot(0, &"item_a", 1)
	var _add_second_result: Variant = inventory.add_item_to_slot(1, &"item_b", 2)
	var emptied_events: Array[Dictionary] = []
	var _connect_emptied_result: Variant = inventory.slot_emptied.connect(func(slot_index: int, previous_stack_data: Dictionary) -> void:
		emptied_events.append({
			"slot_index": slot_index,
			"stack": previous_stack_data.duplicate(true),
		})
	)

	inventory.set_slot_count(1)

	assert_eq(inventory.get_slot_count(), 1, "缩容后槽位数量应更新。")
	assert_eq(inventory.get_item_total(&"item_b"), 0, "被删除槽位中的物品不应继续进入总数。")
	assert_eq(inventory.get_slots_for_item(&"item_b"), PackedInt32Array(), "被删除槽位不应残留在索引中。")
	assert_eq(emptied_events.size(), 1, "缩容删除非空槽位应发出 slot_emptied。")
	if emptied_events.is_empty():
		return
	var emptied_event: Dictionary = emptied_events[0]
	assert_eq(GFVariantData.get_option_int(emptied_event, "slot_index"), 1, "事件应指向被删除的槽位索引。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.get_option_dictionary(emptied_event, "stack"), "item_id"), "item_b", "事件应携带被删除槽位的堆叠快照。")


func test_slot_inventory_from_dict_shrink_removes_dropped_slots_from_index_and_signals() -> void:
	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.set_slot_count(2)
	var _add_first_result: Variant = inventory.add_item_to_slot(0, &"item_a", 1)
	var _add_second_result: Variant = inventory.add_item_to_slot(1, &"item_b", 2)
	var emptied_events: Array[Dictionary] = []
	var _connect_emptied_result: Variant = inventory.slot_emptied.connect(func(slot_index: int, previous_stack_data: Dictionary) -> void:
		emptied_events.append({
			"slot_index": slot_index,
			"stack": previous_stack_data.duplicate(true),
		})
	)

	inventory.from_dict({
		"slot_count": 1,
		"allow_growth": false,
		"slots": [
			{ "item_id": "item_a", "amount": 4, "instance_data": {} },
		],
	})

	assert_eq(inventory.get_slot_count(), 1, "恢复较小存档后槽位数量应收缩。")
	assert_eq(inventory.get_item_total(&"item_b"), 0, "恢复较小存档后旧槽位物品不应残留。")
	assert_eq(inventory.get_slots_for_item(&"item_b"), PackedInt32Array(), "恢复较小存档后旧槽位索引应失效。")
	assert_eq(inventory.get_item_total(&"item_a"), 4, "恢复后保留槽位应使用新存档内容。")
	assert_eq(emptied_events.size(), 1, "恢复较小存档删除非空旧槽位应发出 slot_emptied。")


func test_slot_inventory_from_dict_rejects_malformed_schema_atomically() -> void:
	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.set_slot_count(1)
	var _add_result: GFInventoryOperationResult = inventory.add_item_to_slot(0, &"item_a", 2)

	inventory.from_dict({
		"allow_growth": true,
		"slots": [
			{ "item_id": "item_b", "amount": 3, "instance_data": {} },
		],
	})

	assert_eq(inventory.get_slot_count(), 1, "缺少 slot_count 的快照不应改变槽位数量。")
	assert_eq(inventory.get_item_total(&"item_a"), 2, "畸形快照不应清空既有库存。")
	assert_eq(inventory.get_item_total(&"item_b"), 0, "畸形快照不应部分写入新堆叠。")
	assert_false(inventory.allow_growth, "畸形快照不应提前写入其他字段。")
	assert_push_error("[GFSlotInventoryModel] from_dict 失败：快照必须包含非负整数 slot_count，且 slots 数量必须与其一致。")


## 验证 0 槽位库存默认不会隐式新增槽位。
func test_slot_inventory_zero_slots_require_explicit_capacity() -> void:
	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()

	var result: GFInventoryOperationResult = inventory.add_item(&"item_a")

	assert_false(result.ok, "未配置槽位且未启用增长时不应接受新物品。")
	assert_eq(result.reason, &"not_enough_space", "失败原因应说明容量不足。")
	assert_eq(result.accepted_amount, 0, "不应部分接受物品。")
	assert_eq(inventory.get_slot_count(), 0, "默认 0 槽位库存不应隐式增长。")


## 验证可增长槽位会按有限堆叠数量上限计算容量。
func test_slot_inventory_growth_counts_finite_stack_capacity() -> void:
	var definition: GFInventoryItemDefinition = GFInventoryItemDefinition.new()
	definition.item_id = &"item_a"
	definition.max_stack_amount = 5
	definition.max_stack_count = 2

	var registry: GFInventoryItemRegistry = GFInventoryItemRegistry.new()
	registry.set_definition(definition)

	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.registry = registry
	inventory.allow_growth = true

	var remaining_capacity: int = inventory.get_remaining_capacity_for_item(&"item_a")
	var result: GFInventoryOperationResult = inventory.add_item(&"item_a", 10, {}, -1, false)

	assert_eq(remaining_capacity, 10, "可增长库存应把有限堆叠上限计入剩余容量。")
	assert_true(result.ok, "非部分加入应在增长容量足够时成功。")
	assert_eq(inventory.get_slot_count(), 2, "应只增长到需要的堆叠数量。")
	assert_eq(inventory.get_item_total(&"item_a"), 10, "新增槽位中的物品数量应完整写入。")


## 验证可增长槽位达到堆叠数量上限时不会多创建空槽。
func test_slot_inventory_growth_does_not_create_spare_slot_after_stack_limit() -> void:
	var definition: GFInventoryItemDefinition = GFInventoryItemDefinition.new()
	definition.item_id = &"item_a"
	definition.max_stack_amount = 5
	definition.max_stack_count = 2

	var registry: GFInventoryItemRegistry = GFInventoryItemRegistry.new()
	registry.set_definition(definition)

	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.registry = registry
	inventory.allow_growth = true

	var result: GFInventoryOperationResult = inventory.add_item(&"item_a", 12)

	assert_false(result.ok, "超过有限增长容量时应返回部分成功。")
	assert_eq(result.accepted_amount, 10, "只应接受两个堆叠的容量。")
	assert_eq(result.remaining_amount, 2, "超出堆叠数量上限的部分应保留为剩余数量。")
	assert_eq(inventory.get_slot_count(), 2, "达到堆叠数量上限后不应额外创建空槽。")


func test_inventory_partial_result_normalizes_ok_reason() -> void:
	var partial: GFInventoryOperationResult = GFInventoryOperationResult.partial(&"item_a", 5, 2, &"ok")
	var failed: GFInventoryOperationResult = GFInventoryOperationResult.partial(&"item_a", 5, 0, &"ok")
	var invalid: GFInventoryOperationResult = GFInventoryOperationResult.partial(&"item_a", 0, 0, &"invalid_request")

	assert_false(partial.ok, "未处理完整请求时 ok 应为 false。")
	assert_eq(partial.reason, &"partial", "部分成功不应继续报告 ok 原因。")
	assert_eq(partial.remaining_amount, 3, "部分成功应保留剩余数量。")
	assert_eq(failed.reason, &"failed", "完全未处理且未提供失败原因时应归一化为 failed。")
	assert_false(invalid.ok, "请求数量为 0 的结果不应被误判为成功。")
	assert_eq(invalid.reason, &"invalid_request", "显式失败原因应保留。")


## 验证槽位拆分不会绕过最大堆叠数量上限。
func test_slot_inventory_split_respects_stack_count_limit() -> void:
	var definition: GFInventoryItemDefinition = GFInventoryItemDefinition.new()
	definition.item_id = &"item_a"
	definition.max_stack_amount = 10
	definition.max_stack_count = 1

	var registry: GFInventoryItemRegistry = GFInventoryItemRegistry.new()
	registry.set_definition(definition)

	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.registry = registry
	inventory.set_slot_count(2)
	var _add_item_to_slot_result_165: Variant = inventory.add_item_to_slot(0, &"item_a", 5)

	var result: GFInventoryOperationResult = inventory.move_between_slots(0, 1, 2)

	assert_false(result.ok, "拆分会增加堆叠数量时应失败。")
	assert_eq(result.reason, &"stack_count_limit", "失败原因应说明堆叠数量上限。")
	assert_true(inventory.is_slot_empty(1), "失败后目标槽位应保持为空。")


func test_slot_inventory_rejects_same_slot_move_without_mutation() -> void:
	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.set_slot_count(1)
	var _add_result: GFInventoryOperationResult = inventory.add_item_to_slot(0, &"item_a", 3)
	var before_stack_data: Dictionary = inventory.get_stack_data(0)

	var result: GFInventoryOperationResult = inventory.move_between_slots(0, 0, 2)

	assert_false(result.ok, "源槽位和目标槽位相同时应显式拒绝，而不是伪装成成功移动。")
	assert_eq(result.reason, &"same_slot", "失败原因应明确 same_slot。")
	assert_eq(inventory.get_stack_data(0), before_stack_data, "同槽移动失败后槽位内容不应变化。")


func test_inventory_registry_removes_string_and_string_name_aliases() -> void:
	var definition: GFInventoryItemDefinition = GFInventoryItemDefinition.new()
	definition.item_id = &"potion"
	var registry: GFInventoryItemRegistry = GFInventoryItemRegistry.new()
	registry.definitions["potion"] = definition

	registry.remove_definition(&"potion")

	assert_false(registry.has_definition(&"potion"), "移除定义时应同时清理 String 与 StringName 键。")


func test_trait_set_discards_null_entries_before_sorting() -> void:
	var slow_trait: GFTrait = GFTrait.new()
	slow_trait.target_id = &"speed"
	slow_trait.value = 1.0
	slow_trait.priority = 10
	var fast_trait: GFTrait = GFTrait.new()
	fast_trait.target_id = &"speed"
	fast_trait.value = 2.0
	fast_trait.priority = 1
	var trait_set: GFTraitSet = GFTraitSet.new()
	trait_set.traits = [null, slow_trait]

	trait_set.add_trait(fast_trait)

	assert_eq(trait_set.traits.size(), 2, "排序前应剔除导出数组中的空特征。")
	assert_eq(trait_set.traits[0], fast_trait, "剩余特征应继续按 priority 稳定排序。")


func test_inventory_slot_definition_accepts_ids_categories_and_callback() -> void:
	var weapon: GFInventoryItemDefinition = GFInventoryItemDefinition.new()
	weapon.item_id = &"bow"
	weapon.categories = [&"weapon", &"ranged"]
	var potion: GFInventoryItemDefinition = GFInventoryItemDefinition.new()
	potion.item_id = &"potion"
	potion.categories = [&"consumable"]
	var registry: GFInventoryItemRegistry = GFInventoryItemRegistry.new()
	registry.set_definition(weapon)
	registry.set_definition(potion)

	var slot_definition: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	slot_definition.accepted_categories = [&"weapon"]
	slot_definition.acceptance_checker = func(_item_id: StringName, _definition: GFInventoryItemDefinition, instance_data: Dictionary, _slot_index: int, _inventory: Object) -> bool:
		return not GFVariantData.get_option_bool(instance_data, "broken")

	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.registry = registry
	inventory.set_slot_count(1)
	var _set_slot_definition_result_193: Variant = inventory.set_slot_definition(0, slot_definition)

	assert_false(inventory.can_accept_item_at_slot(0, &"potion"), "缺少必需分类的物品不应被槽位接收。")
	assert_true(inventory.can_accept_item_at_slot(0, &"bow"), "满足分类规则的物品应被槽位接收。")
	assert_false(inventory.can_accept_item_at_slot(0, &"bow", { "broken": true }), "自定义回调可拒绝指定实例。")


func test_slot_inventory_add_item_skips_restricted_empty_slots() -> void:
	var weapon: GFInventoryItemDefinition = GFInventoryItemDefinition.new()
	weapon.item_id = &"bow"
	weapon.categories = [&"weapon"]
	var potion: GFInventoryItemDefinition = GFInventoryItemDefinition.new()
	potion.item_id = &"potion"
	potion.categories = [&"consumable"]
	var registry: GFInventoryItemRegistry = GFInventoryItemRegistry.new()
	registry.set_definition(weapon)
	registry.set_definition(potion)

	var weapon_slot: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	weapon_slot.accepted_categories = [&"weapon"]
	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.registry = registry
	inventory.set_slot_count(2)
	var _set_slot_definition_result_216: Variant = inventory.set_slot_definition(0, weapon_slot)

	var result: GFInventoryOperationResult = inventory.add_item(&"potion", 1)

	assert_true(result.ok, "存在可接受空槽时应能加入物品。")
	assert_true(inventory.is_slot_empty(0), "不接受该物品的空槽应被跳过。")
	assert_eq(GFVariantData.get_option_string(inventory.get_stack_data(1), "item_id"), "potion", "物品应落到可接收的槽位。")


func test_slot_inventory_rejects_move_to_disallowed_slot_and_reports_validation() -> void:
	var weapon: GFInventoryItemDefinition = GFInventoryItemDefinition.new()
	weapon.item_id = &"bow"
	weapon.categories = [&"weapon"]
	var potion: GFInventoryItemDefinition = GFInventoryItemDefinition.new()
	potion.item_id = &"potion"
	potion.categories = [&"consumable"]
	var registry: GFInventoryItemRegistry = GFInventoryItemRegistry.new()
	registry.set_definition(weapon)
	registry.set_definition(potion)

	var weapon_slot: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	weapon_slot.accepted_categories = [&"weapon"]
	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.registry = registry
	inventory.set_slot_count(2)
	var _set_slot_definition_result_241: Variant = inventory.set_slot_definition(1, weapon_slot)
	var _add_item_to_slot_result_242: Variant = inventory.add_item_to_slot(0, &"potion", 1)

	var move_result: GFInventoryOperationResult = inventory.move_between_slots(0, 1)
	var _set_stack_result_245: Variant = inventory.set_stack(1, GFInventoryStack.new(&"potion", 1))
	var report: Dictionary = inventory.validate_inventory()
	var repair_report: Dictionary = inventory.apply_registry_constraints(true)

	assert_false(move_result.ok, "移动到不接受该物品的槽位应失败。")
	assert_eq(move_result.reason, &"slot_rejects_item", "失败原因应说明槽位规则拒绝物品。")
	assert_true(_has_domain_issue_kind(GFVariantData.get_option_array(report, "issues"), "slot_rejects_item"), "校验报告应识别被槽位规则拒绝的堆叠。")
	assert_false(GFVariantData.get_option_bool(repair_report, "ok"), "修复前报告仍应反映原始非法状态。")
	assert_true(inventory.is_slot_empty(1), "启用 repair 时应清除违反槽位规则的堆叠。")


func test_inventory_slot_definition_dictionary_roundtrip() -> void:
	var definition: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	definition.display_name = "Weapon Slot"
	definition.accepted_item_ids = [&"bow"]
	definition.rejected_item_ids = [&"broken_bow"]
	definition.accepted_categories = [&"weapon", &"ranged"]
	definition.require_all_categories = true
	definition.metadata = { "ui": "hotbar" }

	var restored: GFInventorySlotDefinition = GFInventorySlotDefinition.from_dict(definition.to_dict())

	assert_eq(restored.display_name, "Weapon Slot", "槽位定义应恢复显示名称。")
	assert_eq(restored.accepted_item_ids, [&"bow"], "槽位定义应恢复允许物品 ID。")
	assert_eq(restored.rejected_item_ids, [&"broken_bow"], "槽位定义应恢复拒绝物品 ID。")
	assert_eq(restored.accepted_categories, [&"weapon", &"ranged"], "槽位定义应恢复分类规则。")
	assert_true(restored.require_all_categories, "槽位定义应恢复分类匹配模式。")
	assert_eq(GFVariantData.get_option_string(restored.metadata, "ui"), "hotbar", "槽位定义应恢复元数据。")


## 验证槽位库存索引与约束报告。
func test_slot_inventory_index_and_constraint_report() -> void:
	var definition: GFInventoryItemDefinition = GFInventoryItemDefinition.new()
	definition.item_id = &"item_a"
	definition.max_stack_amount = 5
	definition.max_stack_count = 1
	definition.compatibility_checker = func(left: Dictionary, right: Dictionary, _definition: GFInventoryItemDefinition) -> bool:
		return GFVariantData.get_option_string(left, "variant", "base") == GFVariantData.get_option_string(right, "variant", "base")

	var registry: GFInventoryItemRegistry = GFInventoryItemRegistry.new()
	registry.set_definition(definition)

	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.registry = registry
	inventory.set_slot_count(3)
	var _set_stack_result_290: Variant = inventory.set_stack(0, GFInventoryStack.new(&"item_a", 5, { "variant": "base" }))
	var _set_stack_result_291: Variant = inventory.set_stack(1, GFInventoryStack.new(&"item_a", 2, { "variant": "rare" }))
	var _set_stack_result_292: Variant = inventory.set_stack(2, GFInventoryStack.new(&"item_a", 8, { "variant": "base" }))

	var base_slots: PackedInt32Array = inventory.get_slots_for_item(&"item_a", { "variant": "base" })
	var report: Dictionary = inventory.validate_inventory()
	var index_snapshot: Dictionary = inventory.get_index_debug_snapshot()
	var stack_count_by_item: Dictionary = GFVariantData.get_option_dictionary(index_snapshot, "stack_count_by_item")
	var slot_indices_by_item: Dictionary = GFVariantData.get_option_dictionary(index_snapshot, "slot_indices_by_item")
	assert_eq(base_slots, PackedInt32Array([0, 2]), "索引查询应支持实例数据兼容筛选。")
	assert_false(index_snapshot.has("items"), "索引调试快照不应使用容易误读的 items 字段。")
	assert_eq(GFVariantData.get_option_int(stack_count_by_item, "item_a"), 3, "索引调试快照应明确报告每个物品占用的堆叠数量。")
	assert_eq(_packed_int32_array(GFVariantData.get_option_value(slot_indices_by_item, "item_a")), PackedInt32Array([0, 1, 2]), "索引调试快照应明确报告物品所在槽位。")
	assert_false(GFVariantData.get_option_bool(report, "ok"), "违反注册表约束时应返回失败报告。")
	assert_true(_has_domain_issue_kind(GFVariantData.get_option_array(report, "issues"), "stack_amount_exceeds_limit"), "报告应包含单堆叠超限。")
	assert_true(_has_domain_issue_kind(GFVariantData.get_option_array(report, "issues"), "stack_count_exceeds_limit"), "报告应包含堆叠数量超限。")


## 验证槽位变化信号携带稳定快照，并能区分空槽和有内容的切换。
func test_slot_inventory_emits_stable_slot_snapshots_and_occupancy_events() -> void:
	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.set_slot_count(1)
	var state_events: Array = []
	var filled_events: Array = []
	var emptied_events: Array = []
	var _connect_result_315: Variant = inventory.slot_state_changed.connect(func(slot_index: int, before_stack_data: Dictionary, after_stack_data: Dictionary) -> void:
		state_events.append({
			"slot_index": slot_index,
			"before": before_stack_data.duplicate(true),
			"after": after_stack_data.duplicate(true),
		})
	)
	var _connect_result_322: Variant = inventory.slot_filled.connect(func(slot_index: int, stack_data: Dictionary) -> void:
		filled_events.append({
			"slot_index": slot_index,
			"stack": stack_data.duplicate(true),
		})
	)
	var _connect_result_328: Variant = inventory.slot_emptied.connect(func(slot_index: int, previous_stack_data: Dictionary) -> void:
		emptied_events.append({
			"slot_index": slot_index,
			"stack": previous_stack_data.duplicate(true),
		})
	)

	var _add_item_to_slot_result_335: Variant = inventory.add_item_to_slot(0, &"HealthPotion", 2)
	var _remove_item_from_slot_result_336: Variant = inventory.remove_item_from_slot(0, 2)

	assert_eq(state_events.size(), 2, "加入和移除应各产生一次槽位状态变化。")
	assert_eq(filled_events.size(), 1, "空槽变为有内容时应发出 slot_filled。")
	assert_eq(emptied_events.size(), 1, "有内容变为空槽时应发出 slot_emptied。")
	if state_events.size() != 2 or filled_events.size() != 1 or emptied_events.size() != 1:
		return
	var first_event: Dictionary = GFVariantData.as_dictionary(state_events[0])
	var second_event: Dictionary = GFVariantData.as_dictionary(state_events[1])
	var filled_event: Dictionary = GFVariantData.as_dictionary(filled_events[0])
	var emptied_event: Dictionary = GFVariantData.as_dictionary(emptied_events[0])
	var first_after: Dictionary = GFVariantData.get_option_dictionary(first_event, "after")
	var second_before: Dictionary = GFVariantData.get_option_dictionary(second_event, "before")
	var second_after: Dictionary = GFVariantData.get_option_dictionary(second_event, "after")
	var filled_stack: Dictionary = GFVariantData.get_option_dictionary(filled_event, "stack")
	var emptied_stack: Dictionary = GFVariantData.get_option_dictionary(emptied_event, "stack")
	assert_eq(GFVariantData.get_option_dictionary(first_event, "before"), {}, "空槽加入物品前应给出空快照。")
	assert_eq(GFVariantData.get_option_string(first_after, "item_id"), "HealthPotion", "加入后的快照应描述新堆叠。")
	assert_eq(GFVariantData.get_option_int(first_after, "amount"), 2, "加入后的快照应保留数量。")
	assert_eq(GFVariantData.get_option_string(second_before, "item_id"), "HealthPotion", "清空前快照应描述被移除的堆叠。")
	assert_eq(second_after, {}, "清空后快照应为空字典。")
	assert_eq(GFVariantData.get_option_string(filled_stack, "item_id"), "HealthPotion", "slot_filled 应携带新堆叠快照。")
	assert_eq(GFVariantData.get_option_string(emptied_stack, "item_id"), "HealthPotion", "slot_emptied 应携带原堆叠快照。")


## 验证通知派发中同步排序会被拒绝，避免后续监听器看到被重入改写的数据。
func test_slot_inventory_rejects_reentrant_sort_during_change_signal() -> void:
	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.set_slot_count(2)
	var _add_item_to_slot_result_361: Variant = inventory.add_item_to_slot(0, &"HealthPotion", 1)
	var sort_results: Array = []
	var listener_snapshots: Array = []
	var _connect_result_364: Variant = inventory.slot_state_changed.connect(func(_slot_index: int, _before_stack_data: Dictionary, _after_stack_data: Dictionary) -> void:
		sort_results.append(inventory.sort_slots())
	)
	var _connect_result_367: Variant = inventory.slot_state_changed.connect(func(_slot_index: int, _before_stack_data: Dictionary, after_stack_data: Dictionary) -> void:
		listener_snapshots.append(after_stack_data.duplicate(true))
	)

	var _remove_item_from_slot_result_371: Variant = inventory.remove_item_from_slot(0, 1)

	assert_push_error("[GFSlotInventoryModel] sort_slots 失败：库存变更通知派发中不允许同步修改库存。请使用 call_deferred() 或在当前通知结束后再修改。")
	assert_eq(sort_results, [false], "通知派发中的同步排序应失败。")
	assert_eq(listener_snapshots.size(), 1, "后续监听器仍应收到原始变化通知。")
	if listener_snapshots.size() != 1:
		return
	assert_eq(GFVariantData.as_dictionary(listener_snapshots[0]), {}, "后续监听器看到的 after 快照不应被前一个监听器改写。")


## 验证需要由信号触发的排序可以延迟到当前通知结束后执行。
func test_slot_inventory_deferred_sort_after_signal_is_safe() -> void:
	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.set_slot_count(3)
	var _add_item_to_slot_result_385: Variant = inventory.add_item_to_slot(0, &"z_item", 1)
	var _add_item_to_slot_result_386: Variant = inventory.add_item_to_slot(1, &"a_item", 1)
	var _connect_result_387: Variant = inventory.slot_emptied.connect(func(_slot_index: int, _previous_stack_data: Dictionary) -> void:
		inventory.call_deferred("sort_slots")
	)

	var _remove_item_from_slot_result_391: Variant = inventory.remove_item_from_slot(0, 1)
	await get_tree().process_frame

	assert_eq(GFVariantData.get_option_string(inventory.get_stack_data(0), "item_id"), "a_item", "延迟排序应在通知结束后把非空槽位前移。")
	assert_true(inventory.is_slot_empty(1), "排序后原第二槽位应变为空。")


## 验证槽位排序支持调用方传入一次性的比较规则。
func test_slot_inventory_sort_slots_uses_custom_resolver() -> void:
	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.set_slot_count(3)
	var _add_item_to_slot_result_402: Variant = inventory.add_item_to_slot(0, &"z_item", 1)
	var _add_item_to_slot_result_403: Variant = inventory.add_item_to_slot(1, &"a_item", 3)
	var _add_item_to_slot_result_404: Variant = inventory.add_item_to_slot(2, &"b_item", 2)

	var changed: bool = inventory.sort_slots(func(left_slot_index: int, left_stack_data: Dictionary, right_slot_index: int, right_stack_data: Dictionary) -> bool:
		var left_empty: bool = left_stack_data.is_empty()
		var right_empty: bool = right_stack_data.is_empty()
		if left_empty != right_empty:
			return not left_empty
		var left_amount: int = GFVariantData.get_option_int(left_stack_data, "amount")
		var right_amount: int = GFVariantData.get_option_int(right_stack_data, "amount")
		if left_amount != right_amount:
			return left_amount > right_amount
		return left_slot_index < right_slot_index
	)

	assert_true(changed, "自定义比较规则应能改变槽位顺序。")
	assert_eq(GFVariantData.get_option_string(inventory.get_stack_data(0), "item_id"), "a_item", "数量最多的堆叠应排到最前。")
	assert_eq(GFVariantData.get_option_string(inventory.get_stack_data(1), "item_id"), "b_item", "第二多的堆叠应排在第二位。")


func test_slot_inventory_rejects_mutation_from_sort_resolver() -> void:
	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.set_slot_count(2)
	var _first_add: GFInventoryOperationResult = inventory.add_item_to_slot(0, &"b_item", 1)
	var _second_add: GFInventoryOperationResult = inventory.add_item_to_slot(1, &"a_item", 1)
	var nested_result: Array[bool] = [true]
	var attempted: Array[bool] = [false]

	var _changed: bool = inventory.sort_slots(func(
		_left_slot_index: int,
		_left_stack_data: Dictionary,
		_right_slot_index: int,
		_right_stack_data: Dictionary
	) -> bool:
		if not attempted[0]:
			attempted[0] = true
			nested_result[0] = inventory.set_slot_definition(0, GFInventorySlotDefinition.new())
		return false
	)

	assert_false(nested_result[0], "排序回调不应同步修改同一个库存。")
	assert_null(inventory.get_slot_definition(0), "被拒绝的回调写入不应留下部分状态。")
	assert_push_error("[GFSlotInventoryModel] set_slot_definition 失败：库存变更处理中不允许同步修改库存。请在当前操作结束后再修改。")


func test_slot_inventory_rejects_mutation_from_acceptance_checker() -> void:
	var inventory: GFSlotInventoryModel = GFSlotInventoryModel.new()
	inventory.set_slot_count(1)
	var attempted_clear: Array[bool] = [false]
	var slot_definition: GFInventorySlotDefinition = GFInventorySlotDefinition.new()
	slot_definition.acceptance_checker = func(
		_item_id: StringName,
		_definition: GFInventoryItemDefinition,
		_instance_data: Dictionary,
		_slot_index: int,
		_inventory: Object
	) -> bool:
		if not attempted_clear[0]:
			attempted_clear[0] = true
			inventory.clear()
		return true
	assert_true(inventory.set_slot_definition(0, slot_definition))

	var result: GFInventoryOperationResult = inventory.add_item_to_slot(0, &"item_a", 1)

	assert_true(result.ok, "只读接收回调仍应能返回接收结果。")
	assert_true(attempted_clear[0], "测试回调应尝试一次嵌套 clear。")
	assert_eq(inventory.get_item_total(&"item_a"), 1, "被拒绝的嵌套 clear 不应干扰外层加入事务。")
	assert_push_error("[GFSlotInventoryModel] clear 失败：库存变更处理中不允许同步修改库存。请在当前操作结束后再修改。")


## 验证槽位集合按标签规则挂载物品。
func test_equipment_set_checks_slot_tags() -> void:
	var slot: GFEquipmentSlot = GFEquipmentSlot.new()
	slot.slot_id = &"slot_a"
	slot.accepted_tags = [&"usable", &"rare"]
	slot.require_all_tags = true

	var equipment: GFEquipmentSet = GFEquipmentSet.new()
	equipment.set_slot(slot)

	var incomplete_tags: Array[StringName] = [&"usable"]
	var complete_tags: Array[StringName] = [&"usable", &"rare"]

	assert_false(equipment.equip(&"slot_a", &"item_a", incomplete_tags), "缺少任一必需标签时不应挂载。")
	assert_true(equipment.equip(&"slot_a", &"item_a", complete_tags), "满足全部标签时应挂载。")
	assert_eq(equipment.get_equipped_item(&"slot_a"), &"item_a", "挂载后应能读取 item_id。")

	equipment.unequip(&"slot_a")

	assert_eq(equipment.get_equipped_item(&"slot_a"), &"", "卸载后槽位应为空。")


## 验证通用属性集合可限制范围、序列化并接入 Trait 计算。
func test_attribute_set_clamps_serializes_and_applies_traits() -> void:
	var attributes: GFAttributeSet = GFAttributeSet.new()
	attributes.define_attribute(&"stamina", 10.0, 8.0, 0.0, 12.0, { "group": "core" })
	var _adjust_value_result_449: Variant = attributes.adjust_value(&"stamina", 10.0)

	assert_eq(attributes.get_value(&"stamina"), 12.0, "属性当前值应被范围限制。")

	var stamina_trait: GFTrait = GFTrait.new()
	stamina_trait.target_id = &"stamina"
	stamina_trait.value = 3.0
	stamina_trait.combine_mode = GFTrait.CombineMode.ADD
	var traits: GFTraitSet = GFTraitSet.new()
	traits.add_trait(stamina_trait)

	assert_eq(attributes.get_value_with_traits(&"stamina", traits), 15.0, "Trait 应能在属性当前值上计算。")

	var restored: GFAttributeSet = GFAttributeSet.new()
	restored.from_dict(attributes.to_dict())

	assert_eq(restored.get_value(&"stamina"), 12.0, "恢复后当前值应一致。")
	assert_eq(GFVariantData.get_option_string(restored.get_metadata(&"stamina"), "group"), "core", "恢复后元数据应一致。")


func test_attribute_set_rejects_non_finite_runtime_values() -> void:
	var attributes: GFAttributeSet = GFAttributeSet.new()
	attributes.define_attribute(&"heat", INF, NAN, -INF, INF)
	var snapshot: Dictionary = attributes.get_snapshot()
	var heat_snapshot: Dictionary = GFVariantData.as_dictionary(snapshot.get(String(&"heat"), {}))

	assert_eq(attributes.get_base_value(&"heat"), 0.0, "定义属性时非有限 base 应回落为有限默认值。")
	assert_eq(attributes.get_value(&"heat"), 0.0, "定义属性时非有限 current 应回落为有限默认值。")
	assert_eq(GFVariantData.get_option_float(heat_snapshot, "min"), GFAttributeSet.DEFAULT_MIN_VALUE, "非有限 min 应回落为框架默认边界。")
	assert_eq(GFVariantData.get_option_float(heat_snapshot, "max"), GFAttributeSet.DEFAULT_MAX_VALUE, "非有限 max 应回落为框架默认边界。")
	assert_false(attributes.set_value(&"heat", NAN), "运行时设置 NaN 应被拒绝。")
	assert_false(attributes.set_base_value(&"heat", INF), "运行时设置 Infinity base 应被拒绝。")
	assert_false(attributes.set_limits(&"heat", NAN, INF), "运行时设置非有限边界应被拒绝。")


## 验证属性集合可通过通用规则计算派生属性。
func test_attribute_set_updates_derived_attribute_rules() -> void:
	var attributes: GFAttributeSet = GFAttributeSet.new()
	attributes.define_attribute(&"strength", 5.0)
	attributes.define_attribute(&"power", 0.0)
	var rule: GFDerivedAttributeRuleBase = GFDerivedAttributeRuleBase.new()
	rule.attribute_id = &"power"
	rule.source_attribute_ids = [&"strength"]
	rule.source_weights = {
		&"strength": 2.0,
	}
	rule.flat_bonus = 1.0

	assert_true(attributes.add_derived_rule(rule), "有效派生规则应可注册。")
	assert_eq(attributes.get_value(&"power"), 11.0, "注册后应立即计算目标属性。")

	var _set_value_result_485: Variant = attributes.set_value(&"strength", 7.0)

	assert_eq(attributes.get_value(&"power"), 15.0, "来源属性变化后应自动重算派生属性。")


## 验证派生属性规则可使用自定义回调。
func test_derived_attribute_rule_can_use_callback() -> void:
	var attributes: GFAttributeSet = GFAttributeSet.new()
	attributes.define_attribute(&"base", 3.0)
	var rule: GFDerivedAttributeRuleBase = GFDerivedAttributeRuleBase.new()
	rule.attribute_id = &"score"
	rule.compute_callback = func(attribute_set: GFAttributeSet, _rule: GFDerivedAttributeRuleBase) -> float:
		return attribute_set.get_value(&"base") * 4.0

	var _add_derived_rule_result_499: Variant = attributes.add_derived_rule(rule)

	assert_true(attributes.has_attribute(&"score"), "派生规则应能创建缺失的目标属性。")
	assert_eq(attributes.get_value(&"score"), 12.0, "自定义回调结果应写入目标属性。")


func test_derived_attribute_callback_cannot_mutate_same_attribute_set() -> void:
	var attributes: GFAttributeSet = GFAttributeSet.new()
	attributes.define_attribute(&"source", 3.0)
	var mutation_result: Array[bool] = [true]
	var rule: GFDerivedAttributeRuleBase = GFDerivedAttributeRuleBase.new()
	rule.attribute_id = &"derived"
	rule.source_attribute_ids = [&"source"]
	rule.compute_callback = func(attribute_set: GFAttributeSet, _rule: GFDerivedAttributeRuleBase) -> float:
		mutation_result[0] = attribute_set.set_value(&"source", 9.0)
		return attribute_set.get_value(&"source") * 2.0

	var _added: bool = attributes.add_derived_rule(rule)

	assert_false(mutation_result[0], "派生计算回调不应同步写入同一个 AttributeSet。")
	assert_eq(attributes.get_value(&"source"), 3.0, "被拒绝的回调写入不应改变来源属性。")
	assert_eq(attributes.get_value(&"derived"), 6.0, "派生结果应基于稳定的只读输入计算。")
	assert_push_warning("[GFAttributeSet] set_value 失败：派生规则计算期间不允许修改同一个属性集合。")


func test_attribute_set_recalculates_derived_rules_when_base_changes_with_synced_current() -> void:
	var attributes: GFAttributeSet = GFAttributeSet.new()
	attributes.define_attribute(&"strength", 5.0, 10.0)
	var rule: GFDerivedAttributeRuleBase = GFDerivedAttributeRuleBase.new()
	rule.attribute_id = &"score"
	rule.source_attribute_ids = [&"strength"]
	rule.compute_callback = func(attribute_set: GFAttributeSet, _rule: GFDerivedAttributeRuleBase) -> float:
		return attribute_set.get_base_value(&"strength")
	var _add_derived_rule_result_513: Variant = attributes.add_derived_rule(rule)

	var _set_base_value_result_515: Variant = attributes.set_base_value(&"strength", 10.0, true)

	assert_eq(attributes.get_value(&"score"), 10.0, "base 改变但 current 未变化时也应重算派生属性。")


func test_attribute_set_recalculates_derived_rules_when_limits_clamp_base() -> void:
	var attributes: GFAttributeSet = GFAttributeSet.new()
	attributes.define_attribute(&"strength", 20.0, 5.0, 0.0, 30.0)
	var rule: GFDerivedAttributeRuleBase = GFDerivedAttributeRuleBase.new()
	rule.attribute_id = &"score"
	rule.source_attribute_ids = [&"strength"]
	rule.compute_callback = func(attribute_set: GFAttributeSet, _rule: GFDerivedAttributeRuleBase) -> float:
		return attribute_set.get_base_value(&"strength")
	var _add_derived_rule_result_528: Variant = attributes.add_derived_rule(rule)

	var _set_limits_result_530: Variant = attributes.set_limits(&"strength", 0.0, 10.0)

	assert_eq(attributes.get_value(&"score"), 10.0, "limits 改变并夹取 base 时应重算派生属性。")


func test_attribute_set_skips_entire_derived_cycle_without_partial_writes() -> void:
	var attributes: GFAttributeSet = GFAttributeSet.new()
	attributes.define_attribute(&"a", 5.0)
	attributes.define_attribute(&"b", 7.0)
	var rule_a: GFDerivedAttributeRuleBase = GFDerivedAttributeRuleBase.new()
	rule_a.attribute_id = &"a"
	rule_a.source_attribute_ids = [&"b"]
	rule_a.compute_callback = func(_attribute_set: GFAttributeSet, _rule: GFDerivedAttributeRuleBase) -> float:
		return 10.0
	var rule_b: GFDerivedAttributeRuleBase = GFDerivedAttributeRuleBase.new()
	rule_b.attribute_id = &"b"
	rule_b.source_attribute_ids = [&"a"]
	rule_b.compute_callback = func(_attribute_set: GFAttributeSet, _rule: GFDerivedAttributeRuleBase) -> float:
		return 20.0
	attributes.derived_rules = [rule_a, rule_b]

	attributes.recalculate_derived()

	assert_eq(attributes.get_value(&"a"), 5.0, "派生规则成环时环内目标不应被部分写入。")
	assert_eq(attributes.get_value(&"b"), 7.0, "派生规则成环时整组环内目标都应跳过。")


# --- 私有/辅助方法 ---

func _has_domain_issue_kind(issues: Array, kind: String) -> bool:
	for issue: Dictionary in issues:
		if GFVariantData.get_option_string(issue, "kind") == kind:
			return true
	return false


func _packed_int32_array(value: Variant) -> PackedInt32Array:
	if value is PackedInt32Array:
		var packed: PackedInt32Array = value
		return packed
	if value is Array:
		var values: Array = value
		return PackedInt32Array(values)
	return PackedInt32Array()
