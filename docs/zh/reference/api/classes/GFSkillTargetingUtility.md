# GFSkillTargetingUtility

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/skills/gf_skill_targeting_utility.gd`
- 模块：`Combat`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

技能索敌处理工具。 提供统一的目标筛选流程：先做空间过滤， 再执行标签过滤、排序与数量截断。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`find_targets`](#member-gfskilltargetingutility-methods-find_targets) | `func find_targets(p_center: Vector2, p_rule: GFSkillTargetingRule, p_available_entities: Array) -> Array[Object]:` |

## 方法

<a id="member-gfskilltargetingutility-methods-find_targets"></a>

### `find_targets`

- API：`public`

```gdscript
func find_targets(p_center: Vector2, p_rule: GFSkillTargetingRule, p_available_entities: Array) -> Array[Object]:
```

执行索敌 pipeline。

参数：

| 名称 | 说明 |
|---|---|
| `p_center` | 索敌中心点。 |
| `p_rule` | 索敌规则资源。 |
| `p_available_entities` | 候选实体池。 |

返回：最终筛选出的目标数组。

结构：

- `p_available_entities`: Array，元素为候选实体 Object；无效实例会被跳过。
