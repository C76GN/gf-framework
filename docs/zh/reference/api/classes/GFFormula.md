# GFFormula

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/formula/gf_formula.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

资源化公式基类。 公式是纯计算策略，不持有运行时生命周期。 项目可继承并重写 `calculate()`，也可通过 `calculate_float()`、 `calculate_int()` 和 `calculate_bool()` 获得稳定的类型兜底。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`fallback_value`](#member-gfformula-properties-fallback_value) | `var fallback_value: Variant = 0.0` |
| 方法 | [`calculate`](#member-gfformula-methods-calculate) | `func calculate(_parameter: GFFormulaParameter = null) -> Variant:` |
| 方法 | [`calculate_float`](#member-gfformula-methods-calculate_float) | `func calculate_float(parameter: GFFormulaParameter = null, fallback: float = 0.0) -> float:` |
| 方法 | [`calculate_int`](#member-gfformula-methods-calculate_int) | `func calculate_int(parameter: GFFormulaParameter = null, fallback: int = 0) -> int:` |
| 方法 | [`calculate_bool`](#member-gfformula-methods-calculate_bool) | `func calculate_bool(parameter: GFFormulaParameter = null, fallback: bool = false) -> bool:` |

## 属性

<a id="member-gfformula-properties-fallback_value"></a>

### `fallback_value`

- API：`public`

```gdscript
var fallback_value: Variant = 0.0
```

当子类没有返回有效数值时使用的兜底结果。

结构：

- `fallback_value`: Variant default formula result.

## 方法

<a id="member-gfformula-methods-calculate"></a>

### `calculate`

- API：`public`

```gdscript
func calculate(_parameter: GFFormulaParameter = null) -> Variant:
```

执行公式计算。

参数：

| 名称 | 说明 |
|---|---|
| `_parameter` | 公式参数容器。 |

返回：公式结果。子类应重写该方法。

结构：

- `return`: Variant formula result.

<a id="member-gfformula-methods-calculate_float"></a>

### `calculate_float`

- API：`public`

```gdscript
func calculate_float(parameter: GFFormulaParameter = null, fallback: float = 0.0) -> float:
```

以 float 形式执行公式。

参数：

| 名称 | 说明 |
|---|---|
| `parameter` | 公式参数容器。 |
| `fallback` | 结果无法转为数字时使用的兜底值。 |

返回：float 结果。

<a id="member-gfformula-methods-calculate_int"></a>

### `calculate_int`

- API：`public`

```gdscript
func calculate_int(parameter: GFFormulaParameter = null, fallback: int = 0) -> int:
```

以 int 形式执行公式。

参数：

| 名称 | 说明 |
|---|---|
| `parameter` | 公式参数容器。 |
| `fallback` | 结果无法转为数字时使用的兜底值。 |

返回：int 结果。

<a id="member-gfformula-methods-calculate_bool"></a>

### `calculate_bool`

- API：`public`

```gdscript
func calculate_bool(parameter: GFFormulaParameter = null, fallback: bool = false) -> bool:
```

以 bool 形式执行公式。

参数：

| 名称 | 说明 |
|---|---|
| `parameter` | 公式参数容器。 |
| `fallback` | 结果无法转为布尔语义时使用的兜底值。 |

返回：bool 结果。
