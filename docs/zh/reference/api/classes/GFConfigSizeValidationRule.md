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
| 方法 | [`_get_default_rule_id`](#member-gfconfigsizevalidationrule-methods-_get_default_rule_id) | `func _get_default_rule_id() -> StringName:` |
| 方法 | [`_validate_value`](#member-gfconfigsizevalidationrule-methods-_validate_value) | `func _validate_value(value: Variant, context: Dictionary, report: Dictionary) -> void:` |
| 方法 | [`_validate_table`](#member-gfconfigsizevalidationrule-methods-_validate_table) | `func _validate_table(rows: Array[Dictionary], context: Dictionary, report: Dictionary) -> void:` |

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

<a id="member-gfconfigsizevalidationrule-methods-_get_default_rule_id"></a>

### `_get_default_rule_id`

- API：`protected`

```gdscript
func _get_default_rule_id() -> StringName:
```

返回数量规则的默认稳定标识。

返回：默认规则标识。

<a id="member-gfconfigsizevalidationrule-methods-_validate_value"></a>

### `_validate_value`

- API：`protected`

```gdscript
func _validate_value(value: Variant, context: Dictionary, report: Dictionary) -> void:
```

校验单个字段值长度或数量。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待校验值。 |
| `context` | 校验上下文。 |
| `report` | 当前校验报告。 |

结构：

- `value`: Variant，期望为 String、StringName、Array、Dictionary 或 PackedArray。
- `context`: Dictionary，可包含 table_name、row_key、field、source、line 和 column 字段。
- `report`: GFConfigValidationReport 兼容 Dictionary，会被当前规则修改。

<a id="member-gfconfigsizevalidationrule-methods-_validate_table"></a>

### `_validate_table`

- API：`protected`

```gdscript
func _validate_table(rows: Array[Dictionary], context: Dictionary, report: Dictionary) -> void:
```

校验整张表的行数。

参数：

| 名称 | 说明 |
|---|---|
| `rows` | 规范化行列表。 |
| `context` | 校验上下文。 |
| `report` | 当前校验报告。 |

结构：

- `rows`: Array[Dictionary]，元素通常包含 row_key、record 和 row_index。
- `context`: Dictionary，可包含 table_name 和 source 字段。
- `report`: GFConfigValidationReport 兼容 Dictionary，会被当前规则修改。
