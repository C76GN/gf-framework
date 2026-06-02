# GFConfigSizeValidationRule

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/validation/gf_config_size_validation_rule.gd`
- 模块：`Standard`
- 继承：`GFConfigValidationRule`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

长度或数量校验规则。 用于校验 String、Array、Dictionary、PackedArray 字段，或整表记录数量。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`has_minimum_size`](#member-gfconfigsizevalidationrule-properties-has_minimum_size) | `var has_minimum_size: bool = false` |
| 属性 | [`minimum_size`](#member-gfconfigsizevalidationrule-properties-minimum_size) | `var minimum_size: int = 0` |
| 属性 | [`has_maximum_size`](#member-gfconfigsizevalidationrule-properties-has_maximum_size) | `var has_maximum_size: bool = false` |
| 属性 | [`maximum_size`](#member-gfconfigsizevalidationrule-properties-maximum_size) | `var maximum_size: int = 0` |
| 方法 | [`describe`](#member-gfconfigsizevalidationrule-methods-describe) | `func describe() -> Dictionary:` |

## 属性

<a id="member-gfconfigsizevalidationrule-properties-has_minimum_size"></a>

### `has_minimum_size`

- API：`public`

```gdscript
var has_minimum_size: bool = false
```

是否检查最小数量。

<a id="member-gfconfigsizevalidationrule-properties-minimum_size"></a>

### `minimum_size`

- API：`public`

```gdscript
var minimum_size: int = 0
```

最小数量。

<a id="member-gfconfigsizevalidationrule-properties-has_maximum_size"></a>

### `has_maximum_size`

- API：`public`

```gdscript
var has_maximum_size: bool = false
```

是否检查最大数量。

<a id="member-gfconfigsizevalidationrule-properties-maximum_size"></a>

### `maximum_size`

- API：`public`

```gdscript
var maximum_size: int = 0
```

最大数量。

## 方法

<a id="member-gfconfigsizevalidationrule-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出规则摘要。

返回：规则摘要字典。

结构：

- `return`: Dictionary，包含基础规则字段和数量边界设置。
