# GFFormulaSet

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/formula/gf_formula_set.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

按键管理资源化公式的轻量集合。 适合把一组项目公式集中到配置资源里，再由 System 或 Utility 按 `StringName` 获取并计算。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`formulas`](#member-gfformulaset-properties-formulas) | `var formulas: Dictionary = {}` |
| 方法 | [`set_formula`](#member-gfformulaset-methods-set_formula) | `func set_formula(formula_id: StringName, formula: GFFormula) -> void:` |
| 方法 | [`get_formula`](#member-gfformulaset-methods-get_formula) | `func get_formula(formula_id: StringName) -> GFFormula:` |
| 方法 | [`has_formula`](#member-gfformulaset-methods-has_formula) | `func has_formula(formula_id: StringName) -> bool:` |
| 方法 | [`calculate`](#member-gfformulaset-methods-calculate) | `func calculate(formula_id: StringName, parameter: GFFormulaParameter = null, fallback: Variant = null) -> Variant:` |

## 属性

<a id="member-gfformulaset-properties-formulas"></a>

### `formulas`

- API：`public`

```gdscript
var formulas: Dictionary = {}
```

公式表。Key 推荐为 StringName，Value 应为 GFFormula。

结构：

- `formulas`: Dictionary keyed by StringName or String with GFFormula resources.

## 方法

<a id="member-gfformulaset-methods-set_formula"></a>

### `set_formula`

- API：`public`

```gdscript
func set_formula(formula_id: StringName, formula: GFFormula) -> void:
```

注册或替换一个公式。

参数：

| 名称 | 说明 |
|---|---|
| `formula_id` | 公式标识。 |
| `formula` | 公式资源。 |

<a id="member-gfformulaset-methods-get_formula"></a>

### `get_formula`

- API：`public`

```gdscript
func get_formula(formula_id: StringName) -> GFFormula:
```

获取一个公式。

参数：

| 名称 | 说明 |
|---|---|
| `formula_id` | 公式标识。 |

返回：公式资源；不存在时返回 null。

<a id="member-gfformulaset-methods-has_formula"></a>

### `has_formula`

- API：`public`

```gdscript
func has_formula(formula_id: StringName) -> bool:
```

检查是否存在指定公式。

参数：

| 名称 | 说明 |
|---|---|
| `formula_id` | 公式标识。 |

返回：存在时返回 true。

<a id="member-gfformulaset-methods-calculate"></a>

### `calculate`

- API：`public`

```gdscript
func calculate(formula_id: StringName, parameter: GFFormulaParameter = null, fallback: Variant = null) -> Variant:
```

计算指定公式。

参数：

| 名称 | 说明 |
|---|---|
| `formula_id` | 公式标识。 |
| `parameter` | 公式参数。 |
| `fallback` | 公式不存在时返回的结果。 |

返回：公式结果或 fallback。

结构：

- `fallback`: Variant result returned when formula_id is absent.
- `return`: Variant formula result or fallback.
