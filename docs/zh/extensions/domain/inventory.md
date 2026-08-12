# 背包与槽位库存

Domain 扩展提供两层背包模型：轻量的 `GFInventoryModel` 适合按物品 ID 记录数量和元数据；`GFSlotInventoryModel` 适合固定槽位、堆叠、容量查询、格子 UI 和实例数据兼容规则。槽位中的单个堆叠由 `GFInventoryStack` 表示，它只保存物品 ID、数量和实例数据，不解释具体物品业务含义。

`GFInventoryItemRegistry` 维护物品 ID 到通用堆叠、分类和实例数据定义的映射，槽位模型只通过该注册表读取约束，不把项目物品配置写死在运行逻辑中。

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

`add_item()` 会跳过不接收当前物品的空槽，`add_item_to_slot()` 和 `move_between_slots()` 会用 `slot_rejects_item` 拒绝非法目标槽。`swap_slots()` 和 `sort_slots()` 会先验证完整目标布局，任一目标槽拒绝对应堆叠时原子返回 `false`，不会留下半排序状态。`validate_inventory()` 会报告 `slot_rejects_item`，`apply_registry_constraints(true)` 会清理违反槽位定义的堆叠。槽位定义只表达接收规则；快捷键、拖拽、装备效果、消耗行为和 UI 表现仍属于项目层。

`acceptance_checker` 的第五个参数统一为短生命周期 `GFInventoryReadView`，`GFInventorySlotDefinition.can_accept()` 也只接受该视图或 `null`；普通模型 mutation 与跨库存事务都遵循同一只读查询协议。视图会反映当前逐步候选，因此同一操作中后续槽位可以看到此前槽位已经接受的数量；可用 `get_stack()`、`get_item_total()`、`has_item()`、`get_*_slot_indices()` 与 `get_slots_for_item()` 查询，但不得保存视图或把参数声明为 `GFSlotInventoryModel`。回调返回后视图立即失效。`acceptance_checker` 与 `compatibility_checker` 都必须使用 `Callable(object, &"method_name")` 指向可反射参数元数据的具名方法；匿名 lambda、内建 Variant Callable 或参数类型不兼容的方法会在调用前按 `false` 静默失败关闭，不会产生引擎脚本错误。

`GFSlotInventoryModel.get_slots_for_item()` 会维护物品到槽位的惰性索引，适合 UI 局部刷新或规则查询；`get_remaining_capacity_for_item()` 会同时考虑已有兼容堆叠、空槽位、`allow_growth` 和注册表中的堆叠数量上限，适合在非部分加入前做容量预判。

`validate_inventory()` 和 `apply_registry_constraints()` 可检查或修复注册表约束，例如未注册物品、单堆叠超量或堆叠数量超限。报告的精确顶层字段是 `ok: bool`、`error_count: int`、`warning_count: int` 和 `issues: Array`；每个 issue 包含 `severity`、`kind`、`slot_index`、`item_id` 与 `message`。`GFInventoryOperationResult.partial()` 会把“未完全接受”的结果规范为 `ok = false`，并在调用方误传 `reason = &"ok"` 时改为 `&"partial"` 或 `&"failed"`；`success()` 只接受正数量，非正数量也会规范为失败结果，避免 UI 和日志遇到自相矛盾的状态。

默认实例数据的“能否合并”仍由 `stack_key_fields` 控制；“能否把实例数据压缩为空字典”则要求应用默认值后的完整数据精确等价。因此，即使非堆叠键不影响合并，它也会被完整保留并通过库存快照往返。需要更特殊的合并规则时，可给 `GFInventoryItemDefinition.compatibility_checker` 传入项目层回调，但 GF 不保存该回调到字典数据中。

`acceptance_checker` 与 `compatibility_checker` 都是受信的同步判断边界，而不是事件钩子。一次普通 mutation 或事务的 prepare/commit 重规划可能根据候选形状调用它们零次或多次；回调必须确定、只读且有界，不得执行 I/O、修改外部状态、重入库存/事务，或依赖“恰好调用一次”等次数假设。同一输入应返回同一结果，项目若需要记录业务事件，应只在事务成功后的库存通知或 `completed` 中处理。

`GFInventoryItemDefinition.item_id` 是注册表中的规范身份。修改已注册资源的 ID 后再次调用 `set_definition()`，注册表会移除同一资源的旧键并写入新键；长期运行中仍应优先把 ID 当作稳定字段，而不是频繁改名。

## 跨槽位库存原子转移

两个 `GFSlotInventoryModel` 之间转移物品时，使用 `GFInventoryTransferTransaction`，不要把 `remove_item*()` 和 `add_item*()` 顺序拼接，也不要用失败补偿模拟原子性：前者会让监听器观察到半完成状态，后者无法撤回已经执行的项目回调。

```gdscript
var transaction := GFInventoryTransferTransaction.prepare(
	player_inventory,
	chest_inventory,
	0,    # source_slot
	-1,   # target_slot；-1 按 add_item() 规则自动选槽
	5,
	false # allow_partial
)

if transaction.is_prepared():
	var result := transaction.commit()
	if result.is_successful():
		print(result.get_transferred_amount())
else:
	print(transaction.get_prepare_result().get_status())
```

`prepare()` 在两个模型按 `instance_id` 排序取得协调锁，只构建有界隔离候选，不改写任何槽位，也不发信号。`commit()` 会重新取得相同顺序的锁，校验模型 identity 与 `get_revision()`，并重新执行容量、兼容性和槽位规则规划；revision、规则配置或规划摘要漂移时失败且保持两边零写入。最终精确目标候选先基于初始来源的隔离物品/实例数据规划，再重建来源候选，关闭目标回调改变来源规则后提交陈旧来源计划的窗口。全部验证通过后，最终提交阶段只替换已经验证的内存候选，不再调用规则或项目回调，因此没有 rollback 或 outcome unknown 状态。

`target_slot == -1` 采用目标模型 `add_item()` 的“兼容堆叠 → 空槽 → 显式允许增长”顺序；显式槽位采用 `add_item_to_slot()` 的单槽规则。`amount <= 0` 表示来源槽位全部数量，容量或来源不足时是否接受部分数量只由 `allow_partial` 决定。同一模型转移必须给出显式目标槽；规划器复用 `move_between_slots()` 的规则生成完整候选，最终提交只做框架内部原子替换，不动态调用可重写公共方法。

跨模型成功提交会先同时替换来源与目标状态，再严格按“来源库存通知 → 目标库存通知 → `GFInventoryTransferTransaction.completed`”派发。`GFInventoryTransferResult.STATUS_COMMITTED` 只证明双边内存提交已经完成；库存通知期间可以观察到该状态，但只有 `completed` 才证明两边库存通知都已派发完毕。整个通知窗口两个模型都保持锁定：来源监听器已经能读取目标新状态，目标监听器也能读取来源新状态；任何同步回调重入 mutation 都会 fail-closed。槽位接收回调获得逐步候选 `GFInventoryReadView`，而不是参与事务的 live model；兼容性回调也必须保持只读。规则不能修改任一参与模型，也不能重入提交同一个事务；后者会以唯一 `busy` 终态零写入结束。

隔离候选对两个库存合计执行硬上限：最多 4096 个槽位、32768 个 Variant 节点、32 层深度和 1 MiB 估算数据；物品 ID、槽位、容器条目、packed 条目、回调绑定参数与字符串字节都在哈希、序列化或复制前进入预算。Array/Dictionary 循环、所有含浮点 Variant 或 packed 向量/颜色数组中的非有限值、超预算结构，以及实例数据或回调绑定参数中的 Object/Resource、Callable、Signal 或 RID 会以 `unsupported_data` 拒绝。primitive typed Array/Dictionary 会保留类型约束；builtin 类型为 Object、Callable、Signal、RID 或携带 class/script 的 typed 容器即使为空也会闭合拒绝，避免类型元数据绕过能力边界。事务不会对未知图调用无界 `duplicate(true)`，也不会在预算前对整个 Callable 求 hash。需要携带资源身份时，请在项目层把稳定资源 ID 或路径写入实例数据，并由项目自己的资源域解析。

`get_revision()` 是模型单调语义版本：每次实际内容、结构或转移相关配置 mutation 最多递增一次；拒绝和 no-op 不变。`registry`、`allow_growth` 和合法的完整 `slot_definitions` 赋值也会经过重入保护并推进 revision。`slot_definitions.size()` 必须始终精确等于 `get_slot_count()`；错长赋值会报错并保持内容、revision 与信号不变。修改单个规则引用应调用 `set_slot_definition()`；批量配置前先用 `set_slot_count()` 建立槽位，再提交同长度数组。自动增长只为新槽追加 `null` 规则，不会消费预先越界配置。规则资源自身的字段漂移不会伪装成模型 mutation，但 commit 的重新规划与配置摘要仍会拒绝过期计划。

如果旧代码曾直接调用 `slots.slot_definitions.append(rule)` 或修改 getter 返回数组，现在应改成单槽 setter，或在本地组装完整数组后重新赋值：

```gdscript
slots.set_slot_definition(slot_index, rule)

# 扩槽优先；随后提交与当前槽位数精确等长的完整数组。
slots.set_slot_count(new_slot_count)
var rules := slots.slot_definitions
rules[slot_index] = rule
slots.slot_definitions = rules
```

`registry` 与 `allow_growth` 仍可通过属性赋值；需要显式方法调用时分别使用 `set_registry()` 与 `set_allow_growth()`。直接修改已经绑定的 `GFInventoryItemRegistry`、`GFInventoryItemDefinition` 或 `GFInventorySlotDefinition` 资源字段不会自动推进模型 revision；已有 prepared transfer 会在 commit 的重新规划和 plan SHA 校验中按当前规则重验，结果漂移时以 `stale_plan` 拒绝。

## 通知与排序

槽位 UI 不应在 `slot_changed`、`slot_state_changed`、`slot_filled`、`slot_emptied`、`item_added` 或 `item_removed` 的同步回调里继续修改同一个库存模型；GF 会拒绝这种重入修改，避免第一个监听器排序或移动槽位后，第二个监听器收到的上下文已经被改写。

需要“物品移除后自动整理背包”时，把整理延迟到当前通知结束后：

```gdscript
slots.slot_emptied.connect(func(_slot_index: int, _previous_stack_data: Dictionary) -> void:
	slots.call_deferred("sort_slots")
)
```

`slot_state_changed(slot_index, before_stack_data, after_stack_data)` 会携带变化前后的稳定快照；`slot_filled` 只在空槽变为有内容时发出，`slot_emptied` 只在有内容变为空槽时发出。默认 `sort_slots()` 会把非空槽位前移，并按 `item_id` 和原槽位索引保持稳定顺序；项目可以传入一次性比较回调，或在子类中重写 `_should_sort_slot_before()`。排序比较完成后仍会统一验证槽位定义，项目排序规则不能绕过接收约束。

`get_index_debug_snapshot()` 中 `stack_count_by_item` 表示每个物品占用的堆叠数量，`slot_indices_by_item` 才是物品所在的槽位索引列表。
