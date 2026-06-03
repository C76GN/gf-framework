# GFConfigRegexValidationRule

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/validation/gf_config_regex_validation_rule.gd`
- 模块：`Standard`
- 继承：`GFConfigValidationRule`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

字符串正则校验规则。 用于检查字符串字段是否匹配给定表达式，可选择部分匹配或完整匹配。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`pattern`](#member-gfconfigregexvalidationrule-properties-pattern) | `var pattern: String = ""` |
| 属性 | [`require_full_match`](#member-gfconfigregexvalidationrule-properties-require_full_match) | `var require_full_match: bool = false` |
| 属性 | [`allow_empty`](#member-gfconfigregexvalidationrule-properties-allow_empty) | `var allow_empty: bool = true` |
| 方法 | [`describe`](#member-gfconfigregexvalidationrule-methods-describe) | `func describe() -> Dictionary:` |
| 方法 | [`_get_default_rule_id`](#member-gfconfigregexvalidationrule-methods-_get_default_rule_id) | `func _get_default_rule_id() -> StringName:` |
| 方法 | [`_validate_value`](#member-gfconfigregexvalidationrule-methods-_validate_value) | `func _validate_value(value: Variant, context: Dictionary, report: Dictionary) -> void:` |

## 属性

<a id="member-gfconfigregexvalidationrule-properties-pattern"></a>

### `pattern`

- API：`public`

```gdscript
var pattern: String = ""
```

正则表达式。

<a id="member-gfconfigregexvalidationrule-properties-require_full_match"></a>

### `require_full_match`

- API：`public`

```gdscript
var require_full_match: bool = false
```

是否要求整个字符串都匹配。

<a id="member-gfconfigregexvalidationrule-properties-allow_empty"></a>

### `allow_empty`

- API：`public`

```gdscript
var allow_empty: bool = true
```

空字符串是否直接视为通过。

## 方法

<a id="member-gfconfigregexvalidationrule-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出规则摘要。

返回：规则摘要字典。

结构：

- `return`: Dictionary，包含基础规则字段、pattern、require_full_match 和 allow_empty。

<a id="member-gfconfigregexvalidationrule-methods-_get_default_rule_id"></a>

### `_get_default_rule_id`

- API：`protected`

```gdscript
func _get_default_rule_id() -> StringName:
```

返回正则规则的默认稳定标识。

返回：默认规则标识。

<a id="member-gfconfigregexvalidationrule-methods-_validate_value"></a>

### `_validate_value`

- API：`protected`

```gdscript
func _validate_value(value: Variant, context: Dictionary, report: Dictionary) -> void:
```

校验单个字符串值是否匹配正则表达式。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待校验值。 |
| `context` | 校验上下文。 |
| `report` | 当前校验报告。 |

结构：

- `value`: Variant，期望为 String 或 StringName。
- `context`: Dictionary，可包含 table_name、row_key、field、source、line 和 column 字段。
- `report`: GFConfigValidationReport 兼容 Dictionary，会被当前规则修改。
