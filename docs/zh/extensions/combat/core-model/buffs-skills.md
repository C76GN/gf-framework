# Buff 与技能

`GFBuff` 和 `GFSkill` 是 Combat 运行时流程的核心对象。它们只提供生命周期、冷却、条件和通用执行协议，不定义具体伤害、治疗、动画或输入来源。

## Buff

`GFBuff` 是状态效果基类，负责管理生命周期和效果应用。

能力：

- 生命周期：支持 `duration` 和 `on_tick(delta)`。
- 效果携带：Buff 可以携带多个 `GFModifier` 和 tags，在应用时自动挂载至宿主。
- 刷新语义：同 ID Buff 默认通过已有实例的 `refresh_from(new_buff)` 刷新持续时间并按 `max_stacks` 增加层数，不自动替换新 Buff 的 tags、modifiers 或 max_stacks。
- 生命周期报告：`on_apply()` / `on_remove()` / `on_refresh()` / `refresh_from()` 返回结构化报告；应用或刷新失败会回滚本次内置 tag / modifier 变更。
- 可配置策略：`stack_mode` 可选择只刷新、叠层或忽略重复添加；`duration_refresh_policy` 可选择保持、重置、追加或保留更长剩余时间。
- 周期 Tick：`tick_interval_seconds <= 0` 时保持每帧调用 `on_tick(delta)`；大于 0 时按固定间隔触发。
- 数据化扩展：`GFBuffRecipe` 可创建通用运行时 Buff，`GFBuffCheck` 可组合应用检查，`GFBuffEffect` 可响应 apply、remove、refresh 和 tick。
- 状态快照：`get_state_snapshot()` / `restore_state_snapshot()` 保存持续时间、层数、标签、修饰器、metadata 和 effect 状态。

`max_periodic_ticks_per_update` 会限制单次卡顿后的补偿 tick 数，避免大量 Buff 在一帧内无上限追赶。`on_tick(delta)` 只在 Buff 存活帧调用，过期帧不会额外补一次 tick。`remove_on_expire = false` 时，持续时间耗尽后不会要求 `GFCombatSystem` 移除该 Buff，项目可自行决定何时清理或复用。

需要替换强度、合并配置或触发项目事件时，继承 Buff 并覆写 `refresh_from()`。重复添加被 `StackMode.IGNORE` 忽略，或刷新后持续时间、剩余时间和层数都没有变化时，不会发出 Buff refreshed 事件。

需要让策划或编辑器资源创建 Buff 时，可以使用 `GFBuffRecipe`。配方只描述通用字段，不内置伤害、治疗、阵营或状态名：

```gdscript
var recipe := GFBuffRecipe.new()
recipe.id = &"runtime.power"
recipe.duration = 5.0
recipe.modifier_entries = [{
	"type": "base_add",
	"value": 5.0,
	"attribute_id": &"power",
	"source_id": &"runtime.power",
}]

combat_system.add_buff(entity, recipe.create_buff(entity))
```

## 技能

`GFSkill` 提供技能的基础框架。

能力：

- 冷却管理：内置冷却计时逻辑。
- 条件检查：支持 `require_tags` / `ignore_tags`、可选 `activation_query` 和项目自定义 `activation_checks`。
- 激活上下文：`build_activation_context()` 会生成 `GFSkillActivationContext`，保存 owner、手动目标、解析位置、最终目标和项目元数据。
- 激活事务：`activation_steps` 在检查和目标解析通过后先整体验证，再按顺序应用；后续步骤或技能执行失败时按逆序回滚已应用步骤，适合项目扣除抽象成本、确认预留资源或写入诊断数据。
- 自动化索敌：可集成 `GFSkillTargetingRule2D` 实现显式 2D 管线化自动索敌。
- 执行结果：`execute()` 返回是否真正施放成功。

需要在子类中拒绝施放或等待项目校验时，可继续重写 `_try_execute(targets) -> bool`，也可重写 `_try_activate(context) -> bool` 读取完整上下文。只有最终返回 `true`，技能事务才提交、发出 `activation_committed` 并进入冷却；检查、步骤应用或执行失败会回滚事务并发出 `activation_failed`。`GFSkillActivationStep` 钩子必须同步完成，异步成本流程应在项目层先完成预留，再进入技能激活事务。
