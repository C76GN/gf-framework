# Capability 能力启停、索引与诊断

这一页说明能力的 `active` 状态、反向索引、轻量分组查询和 receiver 诊断报告。

## 能力启停

`GFCapability` 与节点能力基类都内置 `active` 状态。建议通过 Utility 修改启停状态：

```gdscript
var capabilities := Gf.get_utility(GFCapabilityUtility) as GFCapabilityUtility
capabilities.set_capability_active(enemy, HitboxCapability, false)
```

停用 Node 能力时，框架会临时禁用该能力节点树的 `process_mode`，重新启用时恢复原状态。若停用期间项目层主动把某个子节点的 `process_mode` 改成其他值，重新启用时会保留这次运行时修改，避免覆盖项目层控制。能力可实现 Hook 响应状态变化：

```gdscript
func on_gf_capability_active_changed(receiver: Object, active: bool) -> void:
	pass
```

Node 能力启停是一项有界原子操作。框架会先在 `max_capability_tree_nodes` 预算内收集完整目标树，再写入 `active`、状态元数据和 `process_mode`；节点树超限时整次操作保持原状态，并且不会调用 active Hook 或发出 `capability_active_changed` 成功信号。Inspector 使用相同的“先预检、后提交”顺序。


## 反向索引与分组查询

能力挂载后会进入运行时索引，便于从全局角度查询“哪些对象拥有某个能力”：

```gdscript
var damageables := capabilities.get_receivers_with(DamageableCapability)
var all_health_caps := capabilities.get_capabilities(HealthCapability)
```

也可以把 receiver 加入轻量分组，并执行分组与能力交集查询：

```gdscript
capabilities.add_receiver_to_group(enemy, &"enemies")

var enemy_targets := capabilities.get_receivers_in_group_with(
	&"enemies",
	DamageableCapability
)
```

需要组合多个能力条件时，可直接使用多条件查询。`required` 列表会全部命中，`rejected` 列表命中任意一项都会排除；传入分组名时只在该分组内筛选：

```gdscript
var selectable_damageables := capabilities.get_receivers_matching_capabilities(
	[SelectableCapability, DamageableCapability],
	[DeadCapability],
	true,
	&"enemies"
)
```

如果查询条件需要保存成资源、挂到编辑器工具或被多个系统复用，可以使用 `GFCapabilityQuery`：

```gdscript
var query: GFCapabilityQuery = GFCapabilityQuery.new()
query.required_capability_types = [SelectableCapability, DamageableCapability]
query.rejected_capability_types = [DeadCapability]
query.group_name = &"enemies"

var receivers := capabilities.get_receivers_matching_query(query)
```

真正的空 `required_capability_types` 表示“没有必需能力”；列表中出现 `null` 则违反查询契约，整次查询失败关闭为空结果（单 receiver 判断返回 `false`），不会把 `[null]` 或 `[ValidType, null]` 静默降级为更宽的条件。重复的有效 Script 会稳定去重。`rejected_capability_types` 也采用同一非法输入策略。

分组只负责查询索引，不改变 Godot 场景树分组，也不接管 receiver 生命周期。receiver 释放后，查询路径会自动清理失效索引；如果索引中的能力实例已经失效，`get_receivers_with()` 也会在返回前清理对应记录。`tick()` 中的周期性清理会按 `prune_invalid_receivers_per_tick` 分批推进，避免大量 receiver 同时失效时造成单帧尖峰；如果需要立刻得到精确索引，仍可主动调用 `prune_invalid_receivers()` 做全量清理。`get_capability()`、`get_capability_types()` 和空 receiver 诊断不会为了表示“未注册”而写入 `_gf_capability_types` 元数据，因此只读探测不会把空状态带入场景序列化。


## 能力诊断

复杂实体组合能力时，可以用 `inspect_receiver()` 获取当前 receiver 的能力、依赖、自动补齐关系和分组信息，便于调试面板、编辑器工具或测试断言使用。

```gdscript
var report := capabilities.inspect_receiver(enemy)
if not report["ok"]:
	for item in report["missing_dependencies"]:
		push_warning("%s missing %s" % [item["capability"], item["required"]])

var dependency_check := capabilities.validate_receiver_dependencies(enemy)
```

诊断报告只描述“能力是否完整”和“索引中有什么”，不替代项目自己的实体合法性规则。
