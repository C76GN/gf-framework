# GFConfigRangeValidationRule

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/validation/gf_config_range_validation_rule.gd`
- 模块：`Standard`
- 继承：`GFConfigValidationRule`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

数值范围校验规则。 用于声明字段数值上下限。上下限可以单独启用，比较方式可选择是否包含边界。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`has_minimum`](#member-gfconfigrangevalidationrule-properties-has_minimum) | `var has_minimum: bool = false` |
| 属性 | [`minimum`](#member-gfconfigrangevalidationrule-properties-minimum) | `var minimum: float = 0.0` |
| 属性 | [`inclusive_minimum`](#member-gfconfigrangevalidationrule-properties-inclusive_minimum) | `var inclusive_minimum: bool = true` |
| 属性 | [`has_maximum`](#member-gfconfigrangevalidationrule-properties-has_maximum) | `var has_maximum: bool = false` |
| 属性 | [`maximum`](#member-gfconfigrangevalidationrule-properties-maximum) | `var maximum: float = 0.0` |
| 属性 | [`inclusive_maximum`](#member-gfconfigrangevalidationrule-properties-inclusive_maximum) | `var inclusive_maximum: bool = true` |
| 方法 | [`describe`](#member-gfconfigrangevalidationrule-methods-describe) | `func describe() -> Dictionary:` |

## 属性

<a id="member-gfconfigrangevalidationrule-properties-has_minimum"></a>

### `has_minimum`

- API：`public`

```gdscript
var has_minimum: bool = false
```

是否检查最小值。

<a id="member-gfconfigrangevalidationrule-properties-minimum"></a>

### `minimum`

- API：`public`

```gdscript
var minimum: float = 0.0
```

最小值。

<a id="member-gfconfigrangevalidationrule-properties-inclusive_minimum"></a>

### `inclusive_minimum`

- API：`public`

```gdscript
var inclusive_minimum: bool = true
```

最小值是否包含边界。

<a id="member-gfconfigrangevalidationrule-properties-has_maximum"></a>

### `has_maximum`

- API：`public`

```gdscript
var has_maximum: bool = false
```

是否检查最大值。

<a id="member-gfconfigrangevalidationrule-properties-maximum"></a>

### `maximum`

- API：`public`

```gdscript
var maximum: float = 0.0
```

最大值。

<a id="member-gfconfigrangevalidationrule-properties-inclusive_maximum"></a>

### `inclusive_maximum`

- API：`public`

```gdscript
var inclusive_maximum: bool = true
```

最大值是否包含边界。

## 方法

<a id="member-gfconfigrangevalidationrule-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出规则摘要。

返回：规则摘要字典。

结构：

- `return`: Dictionary，包含基础规则字段和数值范围设置。
