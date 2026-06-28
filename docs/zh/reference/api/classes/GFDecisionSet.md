# GFDecisionSet

[API Reference](../index.md) / [Decision](../extensions-decision.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/decision/resources/gf_decision_set.gd`
- 模块：`Decision`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`4.3.0`

候选决策集合。 负责对多个 GFDecisionOption 统一评分、排序并选择分数最高的候选。 集合只返回评分结果，不直接执行业务动作。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`decision_set_id`](#member-gfdecisionset-properties-decision_set_id) | `var decision_set_id: StringName = &""` |
| 属性 | [`decisions`](#member-gfdecisionset-properties-decisions) | `var decisions: Array[GFDecisionOption] = []` |
| 属性 | [`minimum_score`](#member-gfdecisionset-properties-minimum_score) | `var minimum_score: float = 0.0` |
| 属性 | [`include_disabled_in_reports`](#member-gfdecisionset-properties-include_disabled_in_reports) | `var include_disabled_in_reports: bool = false` |
| 属性 | [`metadata`](#member-gfdecisionset-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`add_decision`](#member-gfdecisionset-methods-add_decision) | `func add_decision(decision: GFDecisionOption) -> bool:` |
| 方法 | [`get_decision`](#member-gfdecisionset-methods-get_decision) | `func get_decision(decision_id: StringName) -> GFDecisionOption:` |
| 方法 | [`has_decision`](#member-gfdecisionset-methods-has_decision) | `func has_decision(decision_id: StringName) -> bool:` |
| 方法 | [`remove_decision`](#member-gfdecisionset-methods-remove_decision) | `func remove_decision(decision_id: StringName) -> bool:` |
| 方法 | [`clear_decisions`](#member-gfdecisionset-methods-clear_decisions) | `func clear_decisions() -> void:` |
| 方法 | [`score_all`](#member-gfdecisionset-methods-score_all) | `func score_all(context: GFDecisionContext) -> Array[GFDecisionScore]:` |
| 方法 | [`select_best`](#member-gfdecisionset-methods-select_best) | `func select_best(context: GFDecisionContext) -> GFDecisionScore:` |
| 方法 | [`get_debug_snapshot`](#member-gfdecisionset-methods-get_debug_snapshot) | `func get_debug_snapshot(context: GFDecisionContext = null, scores: Array[GFDecisionScore] = []) -> Dictionary:` |

## 属性

<a id="member-gfdecisionset-properties-decision_set_id"></a>

### `decision_set_id`

- API：`public`

```gdscript
var decision_set_id: StringName = &""
```

候选决策集合标识。

<a id="member-gfdecisionset-properties-decisions"></a>

### `decisions`

- API：`public`

```gdscript
var decisions: Array[GFDecisionOption] = []
```

候选决策列表。

结构：

- `decisions`: Array[GFDecisionOption]，按顺序评分并用于同分时稳定排序。

<a id="member-gfdecisionset-properties-minimum_score"></a>

### `minimum_score`

- API：`public`

```gdscript
var minimum_score: float = 0.0
```

可被选择的最低分数。

<a id="member-gfdecisionset-properties-include_disabled_in_reports"></a>

### `include_disabled_in_reports`

- API：`public`

```gdscript
var include_disabled_in_reports: bool = false
```

是否在 score_all() 中包含禁用候选。

<a id="member-gfdecisionset-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据，框架不解释其中内容。

结构：

- `metadata`: Dictionary[StringName, Variant] project-defined decision-set metadata.

## 方法

<a id="member-gfdecisionset-methods-add_decision"></a>

### `add_decision`

- API：`public`

```gdscript
func add_decision(decision: GFDecisionOption) -> bool:
```

添加候选决策。

参数：

| 名称 | 说明 |
|---|---|
| `decision` | 要添加的候选决策。 |

返回：添加成功返回 true。

<a id="member-gfdecisionset-methods-get_decision"></a>

### `get_decision`

- API：`public`

```gdscript
func get_decision(decision_id: StringName) -> GFDecisionOption:
```

获取候选决策。

参数：

| 名称 | 说明 |
|---|---|
| `decision_id` | 候选决策标识。 |

返回：找到的候选决策；不存在时返回 null。

<a id="member-gfdecisionset-methods-has_decision"></a>

### `has_decision`

- API：`public`

```gdscript
func has_decision(decision_id: StringName) -> bool:
```

检查候选决策是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `decision_id` | 候选决策标识。 |

返回：存在返回 true。

<a id="member-gfdecisionset-methods-remove_decision"></a>

### `remove_decision`

- API：`public`

```gdscript
func remove_decision(decision_id: StringName) -> bool:
```

移除候选决策。

参数：

| 名称 | 说明 |
|---|---|
| `decision_id` | 候选决策标识。 |

返回：移除成功返回 true。

<a id="member-gfdecisionset-methods-clear_decisions"></a>

### `clear_decisions`

- API：`public`

```gdscript
func clear_decisions() -> void:
```

清空候选决策。

<a id="member-gfdecisionset-methods-score_all"></a>

### `score_all`

- API：`public`

```gdscript
func score_all(context: GFDecisionContext) -> Array[GFDecisionScore]:
```

计算所有候选决策分数。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 决策上下文。 |

返回：按分数降序排列的评分结果。

结构：

- `return`: Array[GFDecisionScore]，每个候选的评分结果。

<a id="member-gfdecisionset-methods-select_best"></a>

### `select_best`

- API：`public`

```gdscript
func select_best(context: GFDecisionContext) -> GFDecisionScore:
```

选择分数最高的候选决策。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 决策上下文。 |

返回：最佳评分结果；没有可选候选时返回 rejected score。

<a id="member-gfdecisionset-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot(context: GFDecisionContext = null, scores: Array[GFDecisionScore] = []) -> Dictionary:
```

获取集合调试快照。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 决策上下文；scores 为空时用于现场评分。 |
| `scores` | 已计算的评分快照；传入时不会重新评分。 |

返回：调试快照字典。

结构：

- `return`: 包含 decision_set_id、decision_count、minimum_score、scores 和 metadata 字段的 Dictionary。
- `scores`: Array[GFDecisionScore]，可复用 score_all() 的结果以避免调试快照二次评分。
