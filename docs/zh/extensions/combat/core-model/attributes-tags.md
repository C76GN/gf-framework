# 属性与标签

Combat 的属性与标签组件只提供运行时数值和状态标记的通用结构。属性名、标签名、数值含义和过滤规则由项目层定义。

## 可修饰属性

`GFModifiedAttribute` 管理实体的可修饰核心数值。它支持多重修饰器叠加，并自动执行标准战斗公式：

```text
(基础值 + 基础加值) * (1.0 + 百分比加值) + 最终加值
```

能力：

- 响应式更新：对外暴露为 `GFBindableProperty`，UI 可直接绑定。
- 修饰器：支持 `BASE_ADD`、`PERCENT_ADD`、`FINAL_ADD` 三种计算方式，并区分目标属性 `attribute_id` 与来源标识 `source_id`。
- 强制重算：通过 `force_recalculate()` 手动触发数值更新，适用于 Modifier 数值动态变动的场景。

`GFModifiedAttributeSet` 用 `StringName` 管理一组 `GFModifiedAttribute`，适合角色、装备或能力对象集中维护移动速度、攻击、防御等运行时属性。它提供定义、查询、修饰器转发、值变化信号和基础值快照，但不规定属性业务含义，也不直接处理 Buff 生命周期。

`clear()` 会先把原属性从索引和响应式信号中全部脱离，再逐项发送 `attribute_removed`。因此通知回调中重新定义的属性属于清理完成后的新状态，会继续留在集合中并保持正确连接，不会形成“索引已删除但仍发信号”的幽灵属性。

```gdscript
var attrs := GFModifiedAttributeSet.new()
attrs.define_defaults({
	&"MoveSpeed": 0.0,
	&"Attack": 10.0,
	&"Defense": 2.0,
})

attrs.add_modifier(&"Attack", GFModifier.create_base_add(5.0, &"Attack", &"Sword"))
print(attrs.get_value(&"Attack"))
attrs.remove_modifiers_by_source(&"Sword")
```

如果项目只需要一组可保存、可派生的通用数值记录，应使用领域层的 `GFAttributeSet`。`GFModifiedAttribute` / `GFModifiedAttributeSet` 更适合需要实时挂载 `GFModifier`、响应 Buff 或驱动 UI 绑定的运行时数值。

## 标签组件

`GFTagComponent` 记录实体的状态标签及其层数。它适合技能释放前提判断，例如必须包含 `&"State.Normal"` 且不包含 `&"State.Stun"`。

能力：

- 层数堆叠：支持标签层数的增减与查询。
- 快照枚举：`get_tags()` 返回当前标签名，`get_tag_snapshot()` 返回层数字典副本。
- 查询接入：标签快照可接入通用 `GFTagQuery`、调试面板或项目自己的过滤工具。
