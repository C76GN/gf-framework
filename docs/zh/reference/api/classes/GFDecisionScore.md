# GFDecisionScore

[API Reference](../index.md) / [Decision](../extensions-decision.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/decision/runtime/gf_decision_score.gd`
- 模块：`Decision`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`4.3.0`

单个候选决策的评分结果。 保存候选 ID、最终分数、考虑项明细、排序序号和元数据，便于测试、调试面板或导演系统审计。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`decision_id`](#member-gfdecisionscore-properties-decision_id) | `var decision_id: StringName = &""` |
| 属性 | [`decision_order`](#member-gfdecisionscore-properties-decision_order) | `var decision_order: int = -1` |
| 属性 | [`score`](#member-gfdecisionscore-properties-score) | `var score: float = 0.0` |
| 属性 | [`accepted`](#member-gfdecisionscore-properties-accepted) | `var accepted: bool = false` |
| 属性 | [`consideration_scores`](#member-gfdecisionscore-properties-consideration_scores) | `var consideration_scores: Array[Dictionary] = []` |
| 属性 | [`metadata`](#member-gfdecisionscore-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`to_dictionary`](#member-gfdecisionscore-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfdecisionscore-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfdecisionscore-properties-decision_id"></a>

### `decision_id`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var decision_id: StringName = &""
```

候选决策标识。

<a id="member-gfdecisionscore-properties-decision_order"></a>

### `decision_order`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var decision_order: int = -1
```

候选在所属集合中的原始顺序。独立候选评分时为 -1。

<a id="member-gfdecisionscore-properties-score"></a>

### `score`

- API：`public`

```gdscript
var score: float = 0.0
```

最终分数。

<a id="member-gfdecisionscore-properties-accepted"></a>

### `accepted`

- API：`public`

```gdscript
var accepted: bool = false
```

该候选是否可被选择。

<a id="member-gfdecisionscore-properties-consideration_scores"></a>

### `consideration_scores`

- API：`public`

```gdscript
var consideration_scores: Array[Dictionary] = []
```

考虑项评分明细。

结构：

- `consideration_scores`: Array[Dictionary]，每项包含 consideration_id、score、weight 和 weighted_score 字段。

<a id="member-gfdecisionscore-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

候选决策元数据副本。

结构：

- `metadata`: Dictionary[StringName, Variant] copied from the scored decision option.

## 方法

<a id="member-gfdecisionscore-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为字典。

返回：评分结果字典。

结构：

- `return`: 包含 decision_id、decision_order、score、accepted、consideration_scores 和 metadata 字段的 Dictionary。

<a id="member-gfdecisionscore-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照字典。

结构：

- `return`: 与 to_dictionary() 相同的评分结果 Dictionary。
