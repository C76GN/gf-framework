# Combat 通用动作与数值槽

这一页说明如何用动作对象和数值槽表达“某个效果改变某个数值”。它适合做伤害、治疗、护盾、耐久、能量、姿态条或项目自定义计量，但这些语义由项目层定义。

## 通用动作与数值槽

当项目需要把“某个效果改变一个数值”抽象成可配置数据时，可以使用 `GFCombatAction`、`GFCombatActionModifier`、`GFCombatActionResult` 和 `GFCombatGauge`。

- `GFCombatAction` 保存动作类别、操作类型、数值、标签、payload 和元数据。
- `GFCombatActionModifier` 按动作类别和标签过滤后调整动作数值、操作或类别。
- `GFCombatGauge` 是可选节点组件，维护一个带上下限的通用数值，并通过动作应用、校验回调和信号输出结果。
- `GFCombatActionResult` 记录原始动作、最终动作、该动作自身提交前后的数值、原因和元数据，方便日志、表现或事件系统消费。若 `value_changed` 监听者同步触发下一次数值变更，外层结果仍保持自己那一次状态转换的快照，`gauge.current_value` 则反映所有嵌套变更完成后的实时状态。

这套 API 不把 `damage`、`heal`、`hp`、`shield` 写成框架规则。项目可以把 `action_kind = &"damage"` 配成减少值，也可以把同一套机制用于耐久、能量、姿态条、资源槽或自定义交互计量。

```gdscript
var gauge := GFCombatGauge.new()
gauge.configure(0.0, 100.0, 100.0)
gauge.accepted_action_kinds = [&"impact"]

var guard := GFCombatActionModifier.new()
guard.accepted_action_kinds = [&"impact"]
guard.amount_multiplier = 0.5
gauge.add_modifier(guard)

var action := GFCombatAction.new()
action.action_kind = &"impact"
action.operation = GFCombatAction.Operation.SUBTRACT
action.amount = 40.0

var result := gauge.apply_action(action)
print(result.ok, gauge.current_value) # true, 80.0
```
