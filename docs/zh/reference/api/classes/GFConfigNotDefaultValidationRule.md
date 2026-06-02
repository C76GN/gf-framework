# GFConfigNotDefaultValidationRule

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/validation/gf_config_not_default_validation_rule.gd`
- 模块：`Standard`
- 继承：`GFConfigValidationRule`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

非默认值校验规则。 用于要求字段显式填写有效值。默认值可以按类型推导，也可以由项目指定。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`use_type_default`](#member-gfconfignotdefaultvalidationrule-properties-use_type_default) | `var use_type_default: bool = true` |
| 属性 | [`default_value`](#member-gfconfignotdefaultvalidationrule-properties-default_value) | `var default_value: Variant = null` |
| 方法 | [`describe`](#member-gfconfignotdefaultvalidationrule-methods-describe) | `func describe() -> Dictionary:` |

## 属性

<a id="member-gfconfignotdefaultvalidationrule-properties-use_type_default"></a>

### `use_type_default`

- API：`public`

```gdscript
var use_type_default: bool = true
```

是否按输入值类型推导默认值。

<a id="member-gfconfignotdefaultvalidationrule-properties-default_value"></a>

### `default_value`

- API：`public`

```gdscript
var default_value: Variant = null
```

use_type_default 为 false 时使用的默认值。

结构：

- `default_value`: Variant，use_type_default 为 false 时被当前规则拒绝的显式默认值。

## 方法

<a id="member-gfconfignotdefaultvalidationrule-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出规则摘要。

返回：规则摘要字典。

结构：

- `return`: Dictionary，包含基础规则字段、use_type_default 和 default_value。
