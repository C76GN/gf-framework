# GFDecisionConsideration

[API Reference](../index.md) / [Decision](../extensions-decision.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/decision/resources/gf_decision_consideration.gd`
- 模块：`Decision`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`4.3.0`

单个效用评分考虑项。 从决策上下文读取一个输入值，将它映射为 0 到 1 的效用分数。 子类可以重写 `_score()` 扩展项目自己的评分逻辑。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`InputSource`](#member-gfdecisionconsideration-enums-inputsource) | `enum InputSource` |
| 属性 | [`consideration_id`](#member-gfdecisionconsideration-properties-consideration_id) | `var consideration_id: StringName = &""` |
| 属性 | [`enabled`](#member-gfdecisionconsideration-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`weight`](#member-gfdecisionconsideration-properties-weight) | `var weight: float = 1.0` |
| 属性 | [`input_source`](#member-gfdecisionconsideration-properties-input_source) | `var input_source: InputSource = InputSource.BLACKBOARD` |
| 属性 | [`input_key`](#member-gfdecisionconsideration-properties-input_key) | `var input_key: StringName = &""` |
| 属性 | [`default_input`](#member-gfdecisionconsideration-properties-default_input) | `var default_input: float = 0.0` |
| 属性 | [`input_min`](#member-gfdecisionconsideration-properties-input_min) | `var input_min: float = 0.0` |
| 属性 | [`input_max`](#member-gfdecisionconsideration-properties-input_max) | `var input_max: float = 1.0` |
| 属性 | [`missing_score`](#member-gfdecisionconsideration-properties-missing_score) | `var missing_score: float = 0.0` |
| 属性 | [`response_curve`](#member-gfdecisionconsideration-properties-response_curve) | `var response_curve: Curve = null` |
| 属性 | [`invert`](#member-gfdecisionconsideration-properties-invert) | `var invert: bool = false` |
| 方法 | [`score`](#member-gfdecisionconsideration-methods-score) | `func score(context: GFDecisionContext) -> float:` |
| 方法 | [`get_debug_snapshot`](#member-gfdecisionconsideration-methods-get_debug_snapshot) | `func get_debug_snapshot(context: GFDecisionContext) -> Dictionary:` |
| 方法 | [`get_debug_snapshot_from_score`](#member-gfdecisionconsideration-methods-get_debug_snapshot_from_score) | `func get_debug_snapshot_from_score(score_value: float) -> Dictionary:` |
| 方法 | [`get_validation_report`](#member-gfdecisionconsideration-methods-get_validation_report) | `func get_validation_report() -> Dictionary:` |
| 方法 | [`_score`](#member-gfdecisionconsideration-methods-_score) | `func _score(context: GFDecisionContext) -> float:` |

## 枚举

<a id="member-gfdecisionconsideration-enums-inputsource"></a>

### `InputSource`

- API：`public`

```gdscript
enum InputSource {
	## 从 GFDecisionContext 黑板读取。
	BLACKBOARD,
	## 从 GFDecisionContext metadata 读取。
	METADATA,
	## 从 GFDecisionContext subject 读取。
	SUBJECT,
	## 从 GFDecisionContext target 读取。
	TARGET,
}
```

考虑项读取输入值的位置。

## 属性

<a id="member-gfdecisionconsideration-properties-consideration_id"></a>

### `consideration_id`

- API：`public`

```gdscript
var consideration_id: StringName = &""
```

考虑项标识，用于调试报告。

<a id="member-gfdecisionconsideration-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用该考虑项。禁用时返回中性分数 1.0。

<a id="member-gfdecisionconsideration-properties-weight"></a>

### `weight`

- API：`public`

```gdscript
var weight: float = 1.0
```

考虑项权重。具体聚合方式由 GFDecisionOption 决定。

<a id="member-gfdecisionconsideration-properties-input_source"></a>

### `input_source`

- API：`public`

```gdscript
var input_source: InputSource = InputSource.BLACKBOARD
```

输入来源。

<a id="member-gfdecisionconsideration-properties-input_key"></a>

### `input_key`

- API：`public`

```gdscript
var input_key: StringName = &""
```

输入键。为空时使用 default_input。

<a id="member-gfdecisionconsideration-properties-default_input"></a>

### `default_input`

- API：`public`

```gdscript
var default_input: float = 0.0
```

缺失或没有输入键时使用的默认输入值。

<a id="member-gfdecisionconsideration-properties-input_min"></a>

### `input_min`

- API：`public`

```gdscript
var input_min: float = 0.0
```

输入最小值，映射为 0。

<a id="member-gfdecisionconsideration-properties-input_max"></a>

### `input_max`

- API：`public`

```gdscript
var input_max: float = 1.0
```

输入最大值，映射为 1。

<a id="member-gfdecisionconsideration-properties-missing_score"></a>

### `missing_score`

- API：`public`

```gdscript
var missing_score: float = 0.0
```

输入存在但无法转换为数字时返回的分数。输入缺失时优先使用 default_input。

<a id="member-gfdecisionconsideration-properties-response_curve"></a>

### `response_curve`

- API：`public`

```gdscript
var response_curve: Curve = null
```

可选响应曲线。为空时使用线性归一化值。

<a id="member-gfdecisionconsideration-properties-invert"></a>

### `invert`

- API：`public`

```gdscript
var invert: bool = false
```

是否反转最终分数。

## 方法

<a id="member-gfdecisionconsideration-methods-score"></a>

### `score`

- API：`public`

```gdscript
func score(context: GFDecisionContext) -> float:
```

计算考虑项分数。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 决策上下文。 |

返回：0 到 1 之间的效用分数。

<a id="member-gfdecisionconsideration-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`4.3.0`

```gdscript
func get_debug_snapshot(context: GFDecisionContext) -> Dictionary:
```

现场评分并获取考虑项调试快照。 该入口会执行一次 score()，因此自定义 _score() 的项目逻辑也会执行。 已有预计算分数时应使用 get_debug_snapshot_from_score()，避免观察阶段重放评分。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 决策上下文。 |

返回：调试快照字典。

结构：

- `return`: 包含 consideration_id、enabled、score、weight、input_source 和 input_key 字段的 Dictionary。

<a id="member-gfdecisionconsideration-methods-get_debug_snapshot_from_score"></a>

### `get_debug_snapshot_from_score`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_debug_snapshot_from_score(score_value: float) -> Dictionary:
```

从预计算分数获取考虑项调试快照，不执行自定义评分逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `score_value` | 已计算的考虑项分数。 |

返回：调试快照字典。

结构：

- `return`: 包含 consideration_id、enabled、score、weight、input_source 和 input_key 字段的 Dictionary。

<a id="member-gfdecisionconsideration-methods-get_validation_report"></a>

### `get_validation_report`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_validation_report() -> Dictionary:
```

获取考虑项 authoring 校验报告。

返回：GFValidationReportDictionary 兼容报告。

结构：

- `return`: Dictionary with ok, healthy, consideration_id, issues, summary, and next_action.

<a id="member-gfdecisionconsideration-methods-_score"></a>

### `_score`

- API：`protected`

```gdscript
func _score(context: GFDecisionContext) -> float:
```

自定义考虑项评分。 默认实现从 context 读取 input_key，并按 input_min/input_max 归一化。 子类重写时仍应返回 0 到 1 之间的值。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 决策上下文。 |

返回：0 到 1 之间的原始效用分数。
