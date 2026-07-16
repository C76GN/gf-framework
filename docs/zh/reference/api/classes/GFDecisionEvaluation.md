# GFDecisionEvaluation

[API Reference](../index.md) / [Decision](../extensions-decision.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/decision/runtime/gf_decision_evaluation.gd`
- 模块：`Decision`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`8.0.0`

一次决策集合评价的结果快照。 保存同一次评分产生的 scores、best_score 和调试快照，避免调用方为了选择、 诊断和记录日志重复触发评分。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`decision_set_id`](#member-gfdecisionevaluation-properties-decision_set_id) | `var decision_set_id: StringName = &""` |
| 属性 | [`scores`](#member-gfdecisionevaluation-properties-scores) | `var scores: Array[GFDecisionScore] = []` |
| 属性 | [`best_score`](#member-gfdecisionevaluation-properties-best_score) | `var best_score: GFDecisionScore = null` |
| 属性 | [`debug_snapshot`](#member-gfdecisionevaluation-properties-debug_snapshot) | `var debug_snapshot: Dictionary = {}` |
| 方法 | [`configure`](#member-gfdecisionevaluation-methods-configure) | `func configure( p_decision_set_id: StringName, p_scores: Array[GFDecisionScore], p_best_score: GFDecisionScore, p_debug_snapshot: Dictionary = {} ) -> GFDecisionEvaluation:` |
| 方法 | [`to_dictionary`](#member-gfdecisionevaluation-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfdecisionevaluation-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`to_report_dictionary`](#member-gfdecisionevaluation-methods-to_report_dictionary) | `func to_report_dictionary(options: Dictionary = {}) -> Dictionary:` |

## 属性

<a id="member-gfdecisionevaluation-properties-decision_set_id"></a>

### `decision_set_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var decision_set_id: StringName = &""
```

决策集合标识。

<a id="member-gfdecisionevaluation-properties-scores"></a>

### `scores`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var scores: Array[GFDecisionScore] = []
```

本次评价的评分结果。

结构：

- `scores`: Array[GFDecisionScore] copied from one score_all() pass.

<a id="member-gfdecisionevaluation-properties-best_score"></a>

### `best_score`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var best_score: GFDecisionScore = null
```

本次评价选出的最佳分数。

<a id="member-gfdecisionevaluation-properties-debug_snapshot"></a>

### `debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var debug_snapshot: Dictionary = {}
```

本次评价的调试快照。

结构：

- `debug_snapshot`: Dictionary copied from GFDecisionSet.get_debug_snapshot().

## 方法

<a id="member-gfdecisionevaluation-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure( p_decision_set_id: StringName, p_scores: Array[GFDecisionScore], p_best_score: GFDecisionScore, p_debug_snapshot: Dictionary = {} ) -> GFDecisionEvaluation:
```

配置评价结果。

参数：

| 名称 | 说明 |
|---|---|
| `p_decision_set_id` | 决策集合标识。 |
| `p_scores` | 本次评分结果。 |
| `p_best_score` | 本次最佳分数。 |
| `p_debug_snapshot` | 本次调试快照。 |

返回：当前评价对象。

结构：

- `p_scores`: Array[GFDecisionScore] copied into the evaluation.
- `p_debug_snapshot`: Dictionary copied from GFDecisionSet.get_debug_snapshot().

<a id="member-gfdecisionevaluation-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为字典。

返回：评价结果字典。

结构：

- `return`: Dictionary with decision_set_id, scores, best_score, and debug_snapshot.

<a id="member-gfdecisionevaluation-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：评价结果调试快照。

结构：

- `return`: 基于 to_dictionary() 编码的 JSON-safe 评价结果 Dictionary。

<a id="member-gfdecisionevaluation-methods-to_report_dictionary"></a>

### `to_report_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_report_dictionary(options: Dictionary = {}) -> Dictionary:
```

转换为 JSON-safe 报告字典。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 传给 GFReportValueCodec 的编码选项。 |

返回：评价报告字典。

结构：

- `options`: Dictionary with GFReportValueCodec encoding options.
- `return`: JSON-safe Dictionary based on to_dictionary().
