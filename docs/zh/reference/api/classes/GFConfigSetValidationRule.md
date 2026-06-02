# GFConfigSetValidationRule

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/validation/gf_config_set_validation_rule.gd`
- 模块：`Standard`
- 继承：`GFConfigValidationRule`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

值集合校验规则。 用于限制字段值必须出现在一个显式白名单中，不解释白名单背后的业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`allowed_values`](#member-gfconfigsetvalidationrule-properties-allowed_values) | `var allowed_values: Array = []` |
| 属性 | [`case_sensitive`](#member-gfconfigsetvalidationrule-properties-case_sensitive) | `var case_sensitive: bool = true` |
| 方法 | [`describe`](#member-gfconfigsetvalidationrule-methods-describe) | `func describe() -> Dictionary:` |

## 属性

<a id="member-gfconfigsetvalidationrule-properties-allowed_values"></a>

### `allowed_values`

- API：`public`

```gdscript
var allowed_values: Array = []
```

允许出现的值列表。

结构：

- `allowed_values`: Array，包含当前规则允许的 Variant 值。

<a id="member-gfconfigsetvalidationrule-properties-case_sensitive"></a>

### `case_sensitive`

- API：`public`

```gdscript
var case_sensitive: bool = true
```

字符串比较是否区分大小写。

## 方法

<a id="member-gfconfigsetvalidationrule-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出规则摘要。

返回：规则摘要字典。

结构：

- `return`: Dictionary，包含基础规则字段、allowed_values 和 case_sensitive。
