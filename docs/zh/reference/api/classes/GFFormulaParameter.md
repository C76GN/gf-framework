# GFFormulaParameter

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/formula/gf_formula_parameter.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

通用公式运行时参数容器。 用于把施放者、目标、上下文对象和临时数值传给资源化公式。 它不规定任何业务字段，项目可通过 `set_value()` 写入自己的参数。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`source`](#member-gfformulaparameter-properties-source) | `var source: Object = null` |
| 属性 | [`target`](#member-gfformulaparameter-properties-target) | `var target: Object = null` |
| 属性 | [`context`](#member-gfformulaparameter-properties-context) | `var context: Object = null` |
| 属性 | [`values`](#member-gfformulaparameter-properties-values) | `var values: Dictionary = {}` |
| 方法 | [`set_value`](#member-gfformulaparameter-methods-set_value) | `func set_value(key: StringName, value: Variant) -> GFFormulaParameter:` |
| 方法 | [`get_value`](#member-gfformulaparameter-methods-get_value) | `func get_value(key: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`has_value`](#member-gfformulaparameter-methods-has_value) | `func has_value(key: StringName) -> bool:` |
| 方法 | [`duplicate_parameter`](#member-gfformulaparameter-methods-duplicate_parameter) | `func duplicate_parameter() -> GFFormulaParameter:` |

## 属性

<a id="member-gfformulaparameter-properties-source"></a>

### `source`

- API：`public`

```gdscript
var source: Object = null
```

公式发起者，例如攻击者、购买者、升级主体等。

<a id="member-gfformulaparameter-properties-target"></a>

### `target`

- API：`public`

```gdscript
var target: Object = null
```

公式目标，例如受击者、被购买对象、被升级对象等。

<a id="member-gfformulaparameter-properties-context"></a>

### `context`

- API：`public`

```gdscript
var context: Object = null
```

可选上下文对象，通常是系统、规则宿主或临时流程上下文。

<a id="member-gfformulaparameter-properties-values"></a>

### `values`

- API：`public`

```gdscript
var values: Dictionary = {}
```

额外参数表。Key 推荐使用 StringName。

结构：

- `values`: Dictionary keyed by StringName or String with caller-defined formula values.

## 方法

<a id="member-gfformulaparameter-methods-set_value"></a>

### `set_value`

- API：`public`

```gdscript
func set_value(key: StringName, value: Variant) -> GFFormulaParameter:
```

写入一个参数值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 参数键。 |
| `value` | 参数值。 |

返回：当前参数容器，便于链式构造。

结构：

- `value`: Variant caller-defined formula value.

<a id="member-gfformulaparameter-methods-get_value"></a>

### `get_value`

- API：`public`

```gdscript
func get_value(key: StringName, default_value: Variant = null) -> Variant:
```

读取一个参数值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 参数键。 |
| `default_value` | 参数不存在时返回的默认值。 |

返回：参数值或默认值。

结构：

- `default_value`: Variant fallback value returned when key is absent.
- `return`: Variant formula value or fallback.

<a id="member-gfformulaparameter-methods-has_value"></a>

### `has_value`

- API：`public`

```gdscript
func has_value(key: StringName) -> bool:
```

检查是否存在指定参数。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 参数键。 |

返回：存在时返回 true。

<a id="member-gfformulaparameter-methods-duplicate_parameter"></a>

### `duplicate_parameter`

- API：`public`

```gdscript
func duplicate_parameter() -> GFFormulaParameter:
```

创建当前参数容器的深拷贝。

返回：新的参数容器实例。
