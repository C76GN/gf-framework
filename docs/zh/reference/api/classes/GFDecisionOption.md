# GFDecisionOption

[API Reference](../index.md) / [Decision](../extensions-decision.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/decision/resources/gf_decision_option.gd`
- 模块：`Decision`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`4.3.0`

可评分的候选决策资源。 候选决策由一组 GFDecisionConsideration 评分，并按聚合策略得到最终效用分数。 它描述“如何比较候选”，不执行具体业务动作。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Aggregation`](#member-gfdecisionoption-enums-aggregation) | `enum Aggregation` |
| 属性 | [`decision_id`](#member-gfdecisionoption-properties-decision_id) | `var decision_id: StringName = &""` |
| 属性 | [`display_name`](#member-gfdecisionoption-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`enabled`](#member-gfdecisionoption-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`base_score`](#member-gfdecisionoption-properties-base_score) | `var base_score: float = 1.0` |
| 属性 | [`aggregation`](#member-gfdecisionoption-properties-aggregation) | `var aggregation: Aggregation = Aggregation.MULTIPLY` |
| 属性 | [`considerations`](#member-gfdecisionoption-properties-considerations) | `var considerations: Array[GFDecisionConsideration] = []` |
| 属性 | [`metadata`](#member-gfdecisionoption-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`add_consideration`](#member-gfdecisionoption-methods-add_consideration) | `func add_consideration(consideration: GFDecisionConsideration) -> bool:` |
| 方法 | [`get_consideration`](#member-gfdecisionoption-methods-get_consideration) | `func get_consideration(consideration_id: StringName) -> GFDecisionConsideration:` |
| 方法 | [`has_consideration`](#member-gfdecisionoption-methods-has_consideration) | `func has_consideration(consideration_id: StringName) -> bool:` |
| 方法 | [`remove_consideration`](#member-gfdecisionoption-methods-remove_consideration) | `func remove_consideration(consideration_id: StringName) -> bool:` |
| 方法 | [`clear_considerations`](#member-gfdecisionoption-methods-clear_considerations) | `func clear_considerations() -> void:` |
| 方法 | [`score`](#member-gfdecisionoption-methods-score) | `func score(context: GFDecisionContext) -> GFDecisionScore:` |
| 方法 | [`get_debug_snapshot`](#member-gfdecisionoption-methods-get_debug_snapshot) | `func get_debug_snapshot(score_snapshot: GFDecisionScore = null) -> Dictionary:` |
| 方法 | [`get_validation_report`](#member-gfdecisionoption-methods-get_validation_report) | `func get_validation_report() -> Dictionary:` |

## 枚举

<a id="member-gfdecisionoption-enums-aggregation"></a>

### `Aggregation`

- API：`public`

```gdscript
enum Aggregation {
	## 将 base_score 与各考虑项分数相乘，权重作为指数影响。
	MULTIPLY,
	## 按考虑项权重计算平均值，再乘以 base_score。
	WEIGHTED_AVERAGE,
	## 将 base_score 与加权分数相加，并钳制到 0 到 1。
	SUM,
	## 使用所有考虑项中的最低分。
	MIN,
	## 使用所有考虑项中的最高分。
	MAX,
}
```

候选分数聚合策略。

## 属性

<a id="member-gfdecisionoption-properties-decision_id"></a>

### `decision_id`

- API：`public`

```gdscript
var decision_id: StringName = &""
```

候选决策标识。

<a id="member-gfdecisionoption-properties-display_name"></a>

### `display_name`

- API：`public`

```gdscript
var display_name: String = ""
```

编辑器或调试显示名。

<a id="member-gfdecisionoption-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用该候选。

<a id="member-gfdecisionoption-properties-base_score"></a>

### `base_score`

- API：`public`

```gdscript
var base_score: float = 1.0
```

基础分数，范围 0 到 1。

<a id="member-gfdecisionoption-properties-aggregation"></a>

### `aggregation`

- API：`public`

```gdscript
var aggregation: Aggregation = Aggregation.MULTIPLY
```

分数聚合策略。

<a id="member-gfdecisionoption-properties-considerations"></a>

### `considerations`

- API：`public`

```gdscript
var considerations: Array[GFDecisionConsideration] = []
```

候选考虑项列表。

结构：

- `considerations`: Array[GFDecisionConsideration]，按顺序参与评分。

<a id="member-gfdecisionoption-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据，框架不解释其中内容。

结构：

- `metadata`: Dictionary[StringName, Variant] project-defined decision metadata.

## 方法

<a id="member-gfdecisionoption-methods-add_consideration"></a>

### `add_consideration`

- API：`public`

```gdscript
func add_consideration(consideration: GFDecisionConsideration) -> bool:
```

添加考虑项。

参数：

| 名称 | 说明 |
|---|---|
| `consideration` | 要添加的考虑项。 |

返回：添加成功返回 true。

<a id="member-gfdecisionoption-methods-get_consideration"></a>

### `get_consideration`

- API：`public`

```gdscript
func get_consideration(consideration_id: StringName) -> GFDecisionConsideration:
```

获取考虑项。

参数：

| 名称 | 说明 |
|---|---|
| `consideration_id` | 考虑项标识。 |

返回：找到的考虑项；不存在时返回 null。

<a id="member-gfdecisionoption-methods-has_consideration"></a>

### `has_consideration`

- API：`public`

```gdscript
func has_consideration(consideration_id: StringName) -> bool:
```

检查考虑项是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `consideration_id` | 考虑项标识。 |

返回：存在返回 true。

<a id="member-gfdecisionoption-methods-remove_consideration"></a>

### `remove_consideration`

- API：`public`

```gdscript
func remove_consideration(consideration_id: StringName) -> bool:
```

移除考虑项。

参数：

| 名称 | 说明 |
|---|---|
| `consideration_id` | 考虑项标识。 |

返回：移除成功返回 true。

<a id="member-gfdecisionoption-methods-clear_considerations"></a>

### `clear_considerations`

- API：`public`

```gdscript
func clear_considerations() -> void:
```

清空考虑项。

<a id="member-gfdecisionoption-methods-score"></a>

### `score`

- API：`public`
- 首次版本：`4.3.0`

```gdscript
func score(context: GFDecisionContext) -> GFDecisionScore:
```

计算候选决策分数。 本次调用会冻结考虑项数组成员；评分回调对 live 数组的修改只影响后续调用。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 决策上下文。 |

返回：评分结果。

<a id="member-gfdecisionoption-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot(score_snapshot: GFDecisionScore = null) -> Dictionary:
```

获取候选决策调试快照。

参数：

| 名称 | 说明 |
|---|---|
| `score_snapshot` | 已计算的评分快照；为空时 score 字段返回空字典。 |

返回：调试快照字典。

结构：

- `return`: 包含 decision_id、display_name、enabled、aggregation、base_score 和 score 字段的 Dictionary。

<a id="member-gfdecisionoption-methods-get_validation_report"></a>

### `get_validation_report`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_validation_report() -> Dictionary:
```

获取候选资源的 authoring 校验报告。

返回：GFValidationReportDictionary 兼容报告。

结构：

- `return`: Dictionary with ok, healthy, decision_id, issues, summary, and next_action.
