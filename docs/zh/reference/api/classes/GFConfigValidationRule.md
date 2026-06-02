# GFConfigValidationRule

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/validation/gf_config_validation_rule.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

导表校验规则基类。 用于把字段、记录或整表校验拆成可组合 Resource，便于项目按需声明范围、 正则、资源路径或本地化 key 等规则，而不把业务表结构写进框架。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`IssueSeverity`](#member-gfconfigvalidationrule-enums-issueseverity) | `enum IssueSeverity` |
| 属性 | [`rule_id`](#member-gfconfigvalidationrule-properties-rule_id) | `var rule_id: StringName = &""` |
| 属性 | [`enabled`](#member-gfconfigvalidationrule-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`severity`](#member-gfconfigvalidationrule-properties-severity) | `var severity: IssueSeverity = IssueSeverity.ERROR` |
| 属性 | [`allow_null`](#member-gfconfigvalidationrule-properties-allow_null) | `var allow_null: bool = true` |
| 属性 | [`metadata`](#member-gfconfigvalidationrule-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_rule_id`](#member-gfconfigvalidationrule-methods-get_rule_id) | `func get_rule_id() -> StringName:` |
| 方法 | [`validate_value`](#member-gfconfigvalidationrule-methods-validate_value) | `func validate_value(value: Variant, context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`validate_record`](#member-gfconfigvalidationrule-methods-validate_record) | `func validate_record(record: Dictionary, context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`validate_table`](#member-gfconfigvalidationrule-methods-validate_table) | `func validate_table(rows: Array[Dictionary], context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`duplicate_rule`](#member-gfconfigvalidationrule-methods-duplicate_rule) | `func duplicate_rule() -> GFConfigValidationRule:` |
| 方法 | [`describe`](#member-gfconfigvalidationrule-methods-describe) | `func describe() -> Dictionary:` |

## 枚举

<a id="member-gfconfigvalidationrule-enums-issueseverity"></a>

### `IssueSeverity`

- API：`public`

```gdscript
enum IssueSeverity { ## 警告，不阻止报告通过。 WARNING, ## 错误，会让报告失败。 ERROR, }
```

校验问题严重级别。

## 属性

<a id="member-gfconfigvalidationrule-properties-rule_id"></a>

### `rule_id`

- API：`public`

```gdscript
var rule_id: StringName = &""
```

规则稳定标识。为空时使用规则类型默认标识。

<a id="member-gfconfigvalidationrule-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用当前规则。

<a id="member-gfconfigvalidationrule-properties-severity"></a>

### `severity`

- API：`public`

```gdscript
var severity: IssueSeverity = IssueSeverity.ERROR
```

规则触发时写入报告的严重级别。

<a id="member-gfconfigvalidationrule-properties-allow_null"></a>

### `allow_null`

- API：`public`

```gdscript
var allow_null: bool = true
```

值为 null 时是否直接跳过值校验。

<a id="member-gfconfigvalidationrule-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据，供编辑器或项目工具扩展使用。

结构：

- `metadata`: Dictionary，保存编辑器或项目层附加到当前规则的元数据。

## 方法

<a id="member-gfconfigvalidationrule-methods-get_rule_id"></a>

### `get_rule_id`

- API：`public`

```gdscript
func get_rule_id() -> StringName:
```

获取稳定规则标识。

返回：规则标识。

<a id="member-gfconfigvalidationrule-methods-validate_value"></a>

### `validate_value`

- API：`public`

```gdscript
func validate_value(value: Variant, context: Dictionary = {}) -> Dictionary:
```

校验单个字段值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待校验值。 |
| `context` | 可选上下文，支持 table_name、row_key、field、source、line、column。 |

返回：校验报告字典。

结构：

- `value`: Variant，来自配置表或项目导入器的字段值。
- `context`: Dictionary，可包含 table_name、row_key、field、source、line 和 column 字段。
- `return`: GFConfigValidationReport 兼容 Dictionary。

<a id="member-gfconfigvalidationrule-methods-validate_record"></a>

### `validate_record`

- API：`public`

```gdscript
func validate_record(record: Dictionary, context: Dictionary = {}) -> Dictionary:
```

校验单条记录。

参数：

| 名称 | 说明 |
|---|---|
| `record` | 待校验记录。 |
| `context` | 可选上下文，支持 table_name、row_key、source、line。 |

返回：校验报告字典。

结构：

- `record`: Dictionary，正在校验的配置记录。
- `context`: Dictionary，可包含 table_name、row_key、source 和 line 字段。
- `return`: GFConfigValidationReport 兼容 Dictionary。

<a id="member-gfconfigvalidationrule-methods-validate_table"></a>

### `validate_table`

- API：`public`

```gdscript
func validate_table(rows: Array[Dictionary], context: Dictionary = {}) -> Dictionary:
```

校验整张表。

参数：

| 名称 | 说明 |
|---|---|
| `rows` | 规范化行列表，每项通常包含 row_key、record 和 row_index。 |
| `context` | 可选上下文，支持 table_name、source。 |

返回：校验报告字典。

结构：

- `rows`: Array[Dictionary]，元素通常包含 row_key、record 和 row_index。
- `context`: Dictionary，可包含 table_name 和 source 字段。
- `return`: GFConfigValidationReport 兼容 Dictionary。

<a id="member-gfconfigvalidationrule-methods-duplicate_rule"></a>

### `duplicate_rule`

- API：`public`

```gdscript
func duplicate_rule() -> GFConfigValidationRule:
```

创建同内容拷贝。

返回：新规则。

<a id="member-gfconfigvalidationrule-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出规则摘要。

返回：规则摘要字典。

结构：

- `return`: Dictionary，包含 rule_id、enabled、severity、allow_null、metadata 和 script_path。
