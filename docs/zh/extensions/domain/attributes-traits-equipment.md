# 属性、特征与装备

Domain 扩展提供通用属性集、特征集和装备槽。它们只表达数值依赖、修饰器聚合和标签匹配，不规定属性名称、装备类型或结算规则。

## 属性与特征

```gdscript
var traits := GFTraitSet.new()
var bonus := GFTrait.new()
bonus.target_id = &"speed"
bonus.value = 2.0
traits.add_trait(bonus)

var attributes := GFAttributeSet.new()
attributes.define_attribute(&"speed", 10.0, 10.0, 0.0, 99.0)
var speed := attributes.get_value_with_traits(&"speed", traits)
```

`GFTrait` 描述一项带目标、分类、优先级和有限数值的修饰记录；`GFTraitSet` 按 `target_id` 和可选 `category` 收集这些记录，并按优先级合并。`GFAttributeSet` 按 `attribute_id` 管理基础值、当前值、上下限和元数据，支持快照恢复，也可以接入 `GFTraitSet` 计算修饰后数值。

## 派生属性

`GFDerivedAttributeRule` 描述一个目标属性如何由其他属性按权重或回调派生，适合把“最大值、评分、容量、派生速度”等通用依赖关系留在数据层。

```gdscript
var power_rule := GFDerivedAttributeRule.new()
power_rule.attribute_id = &"power"
power_rule.source_attribute_ids = [&"speed"]
power_rule.source_weights = { &"speed": 2.0 }
attributes.add_derived_rule(power_rule)
```

`GFDerivedAttributeRule` 默认使用 `source_attribute_ids` 和 `source_weights` 做线性组合，再加上 `flat_bonus` 并按规则上下限钳制；需要更复杂的项目公式时，可以设置 `compute_callback`。

`GFAttributeSet` 会在来源属性当前值、基础值或上下限变化后重算依赖它的规则，并用循环保护避免派生属性互相递归。规则只描述数值依赖，不规定属性名称含义；存档快照仍只保存属性记录，派生规则应作为配置或资源由项目层加载。

## 装备槽

`GFEquipmentSet` 管理一组 `GFEquipmentSlot`，通过标签判断某个 `item_id` 是否可挂载：

```gdscript
var equipment := GFEquipmentSet.new()
var weapon_slot := GFEquipmentSlot.new()
weapon_slot.slot_id = &"weapon"
weapon_slot.accepted_tags = [&"weapon"]
equipment.set_slot(weapon_slot)
equipment.equip(&"weapon", &"iron_sword", [&"weapon"])
```

装备槽只表达槽位、物品 ID 和标签匹配。装备带来的属性变化、模型挂点、技能解锁、耐久消耗或网络同步仍由项目层组合。
