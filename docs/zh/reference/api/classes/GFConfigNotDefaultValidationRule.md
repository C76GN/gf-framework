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
| 方法 | [`_get_default_rule_id`](#member-gfconfignotdefaultvalidationrule-methods-_get_default_rule_id) | `func _get_default_rule_id() -> StringName:` |
| 方法 | [`_validate_value`](#member-gfconfignotdefaultvalidationrule-methods-_validate_value) | `func _validate_value(value: Variant, context: Dictionary, report: Dictionary) -> void:` |

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

<a id="member-gfconfignotdefaultvalidationrule-methods-_get_default_rule_id"></a>

### `_get_default_rule_id`

- API：`protected`

```gdscript
func _get_default_rule_id() -> StringName:
```

返回非默认值规则的默认稳定标识。

返回：默认规则标识。

<a id="member-gfconfignotdefaultvalidationrule-methods-_validate_value"></a>

### `_validate_value`

- API：`protected`

```gdscript
func _validate_value(value: Variant, context: Dictionary, report: Dictionary) -> void:
```

校验单个字段值是否不同于推导或显式默认值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待校验值。 |
| `context` | 校验上下文。 |
| `report` | 当前校验报告。 |

结构：

- `value`: Variant，与推导默认值或显式默认值比较的字段值。
- `context`: Dictionary，可包含 table_name、row_key、field、source、line 和 column 字段。
- `report`: GFConfigValidationReport 兼容 Dictionary，会被当前规则修改。
