# 运行时 Buff 管理

运行时可通过 `get_buff(entity, buff_id)` 取得正在系统中生效的 Buff 实例，通过 `has_buff(entity, buff_id)` 判断是否存在，通过 `get_buffs(entity)` 取得 Buff 列表副本。

空 `id` 的 Buff 会作为匿名实例加入，不参与同 ID 刷新，避免多个不同的临时 Buff 因为都没填 ID 而互相覆盖。需要刷新、叠层或按 ID 驱散时，应显式设置稳定 `id`。

列表副本可安全排序、过滤或清空，不会修改系统内部数组；但数组里的 `GFBuff` 仍是运行中的对象引用，适合调整剩余时间、层数或周期参数。

```gdscript
var buff := combat_system.get_buff(entity, &"StrBoost")
if buff != null:
	buff.time_left = 8.0
	buff.stacks = mini(buff.stacks + 1, buff.max_stacks)
```

## 刷新修饰器

如果只修改已挂载 `GFModifier` 的 `value`，需要让目标属性重新计算。可以调用 `refresh_buff_modifiers(entity, buff_id)`，它会刷新该 Buff 当前修饰器影响到的属性。

```gdscript
var buff := combat_system.get_buff(entity, &"StrBoost")
if buff != null and not buff.modifiers.is_empty():
	buff.modifiers[0].value = 0.35
	combat_system.refresh_buff_modifiers(entity, &"StrBoost")
```

如果要增删 `modifiers` 或 `tags` 列表本身，应优先 `remove_buff()` 后重新构造并 `add_buff()`，因为标签和修饰器的挂载/卸载由 Buff 生命周期负责。

## 移除与目标校验

运行时可通过 `remove_buff(entity, buff_id)` 驱散单个 Buff，通过 `clear_buffs(entity, predicate)` 清理全部或部分 Buff，通过 `remove_skill(entity, skill)` 取消某个技能的系统驱动与冷却信号监听。

`clear_buffs()` 会在调用 predicate 前冻结候选身份；predicate 可以同步移除 Buff、清空列表或注销实体。每次回调返回后系统都会重新验证实体记录并按 Buff 身份定位，已由回调完成的移除不会重复执行或计入本次外层清理数量。

需要给诊断、存档或项目日志记录来源时，可以使用 `remove_buff_with_reason(entity, buff_id, reason)` 或 `clear_buffs_with_reason(entity, predicate, reason)`。Buff 会在 `removal_reason` 中保留最近一次移除原因，默认原因包括 `expired`、`removed`、`cleared`、`entity_unregistered` 和 `disposed`。

运行时状态可用 `get_state_snapshot()` 保存，再用 `restore_state_snapshot(snapshot, owner)` 恢复到新的 Buff 实例。快照只保存通用数据和 effect 状态，不把 owner 对象序列化进数据。

手动目标施放会先经过 `targeting_rule` 校验；即使 `max_count <= 0` 表示不截断目标，未通过校验的手动目标也不会让技能以空目标执行。若技能 owner 没有 `global_position` 且调用时未传入 `cast_center`，索敌中心会回退到 `Vector2.ZERO`，项目应为非空间对象显式传入施法中心。
