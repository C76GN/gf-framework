# 背包与槽位库存

Domain 扩展提供两层背包模型：轻量的 `GFInventoryModel` 适合按物品 ID 记录数量和元数据；`GFSlotInventoryModel` 适合固定槽位、堆叠、容量查询、格子 UI 和实例数据兼容规则。槽位中的单个堆叠由 `GFInventoryStack` 表示，它只保存物品 ID、数量和实例数据，不解释具体物品业务含义。

## 轻量背包

```gdscript
var inventory := GFInventoryModel.new()
inventory.add_item(&"item_a", 3, { "source": "runtime" })
```

`GFInventoryModel` 适合放在项目自己的 `Model` 或资源配置中。具体物品含义、标签体系和结算规则仍由项目层定义。

## 槽位库存

需要背包、格子 UI、带实例数据的物品或部分加入/移除时，不要把复杂度塞进轻量 `GFInventoryModel`，而是新增一个 `GFSlotInventoryModel`：

```gdscript
var definition := GFInventoryItemDefinition.new()
definition.item_id = &"item_a"
definition.max_stack_amount = 20
definition.stack_key_fields = PackedStringArray(["variant"])

var registry := GFInventoryItemRegistry.new()
registry.set_definition(definition)

var slots := GFSlotInventoryModel.new()
slots.registry = registry
slots.set_slot_count(24)

var result := slots.add_item(&"item_a", 35, { "variant": "basic" })
print(result.accepted_amount, result.remaining_amount)
```

`GFSlotInventoryModel` 手动 `new()` 后默认是 0 槽位且 `allow_growth = false`，因此不会在 `add_item()` 时隐式新增槽位。固定容量背包应先调用 `set_slot_count(count)`；如果模型由 GF 生命周期管理，也可以设置 `default_slot_count` 让 `init()` 自动应用初始槽位。需要无固定格子上限、但仍受物品 `max_stack_amount` / `max_stack_count` 约束的容器时，再显式启用 `allow_growth = true`。

需要“某些格子只能放某类物品”时，可给槽位配置 `GFInventorySlotDefinition`。槽位定义支持允许/拒绝物品 ID、按 `GFInventoryItemDefinition.categories` 匹配分类，以及项目层回调：

```gdscript
var weapon_slot := GFInventorySlotDefinition.new()
weapon_slot.accepted_categories = [&"weapon"]

slots.set_slot_definition(0, weapon_slot)

if slots.can_accept_item_at_slot(0, &"sword"):
	slots.add_item_to_slot(0, &"sword")
```

`add_item()` 会跳过不接收当前物品的空槽，`add_item_to_slot()` 和 `move_between_slots()` 会用 `slot_rejects_item` 拒绝非法目标槽。`validate_inventory()` 会报告 `slot_rejects_item`，`apply_registry_constraints(true)` 会清理违反槽位定义的堆叠。槽位定义只表达接收规则；快捷键、拖拽、装备效果、消耗行为和 UI 表现仍属于项目层。

`GFSlotInventoryModel.get_slots_for_item()` 会维护物品到槽位的惰性索引，适合 UI 局部刷新或规则查询；`get_remaining_capacity_for_item()` 会同时考虑已有兼容堆叠、空槽位、`allow_growth` 和注册表中的堆叠数量上限，适合在非部分加入前做容量预判。

`validate_inventory()` 和 `apply_registry_constraints()` 可检查或修复注册表约束，例如未注册物品、单堆叠超量或堆叠数量超限。`GFInventoryOperationResult.partial()` 会把“未完全接受”的结果规范为 `ok = false`，并在调用方误传 `reason = &"ok"` 时改为 `&"partial"` 或 `&"failed"`，避免 UI 和日志遇到“失败但原因是 ok”的冲突状态。

默认实例数据比较仍由 `stack_key_fields` 控制；需要更特殊的合并规则时，可给 `GFInventoryItemDefinition.compatibility_checker` 传入项目层回调，但 GF 不保存该回调到字典数据中。

## 通知与排序

槽位 UI 不应在 `slot_changed`、`slot_state_changed`、`slot_filled`、`slot_emptied`、`item_added` 或 `item_removed` 的同步回调里继续修改同一个库存模型；GF 会拒绝这种重入修改，避免第一个监听器排序或移动槽位后，第二个监听器收到的上下文已经被改写。

需要“物品移除后自动整理背包”时，把整理延迟到当前通知结束后：

```gdscript
slots.slot_emptied.connect(func(_slot_index: int, _previous_stack_data: Dictionary) -> void:
	slots.call_deferred("sort_slots")
)
```

`slot_state_changed(slot_index, before_stack_data, after_stack_data)` 会携带变化前后的稳定快照；`slot_filled` 只在空槽变为有内容时发出，`slot_emptied` 只在有内容变为空槽时发出。默认 `sort_slots()` 会把非空槽位前移，并按 `item_id` 和原槽位索引保持稳定顺序；项目可以传入一次性比较回调，或在子类中重写 `_should_sort_slot_before()`。

`get_index_debug_snapshot()` 中 `stack_count_by_item` 表示每个物品占用的堆叠数量，`slot_indices_by_item` 才是物品所在的槽位索引列表。
