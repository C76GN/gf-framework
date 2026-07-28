# GFAnalyticsEventSchema

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/analytics/gf_analytics_event_schema.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`10.0.0`

版本化 Analytics 事件属性契约。 用不超过 4096 字符且不含 C0/DEL 控制字符的稳定事件名、1..2_147_483_647 范围内的 精确版本和严格 GFDictionarySchema 描述编码前的事件属性。 校验会先执行有界、无复制的集合遍历，再进入通用 Dictionary Schema， 避免不可信属性在深复制前消耗无界资源。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`event_name`](#member-gfanalyticseventschema-properties-event_name) | `var event_name: StringName = &""` |
| 属性 | [`schema_version`](#member-gfanalyticseventschema-properties-schema_version) | `var schema_version: int = 1` |
| 属性 | [`properties_schema`](#member-gfanalyticseventschema-properties-properties_schema) | `var properties_schema: GFDictionarySchema = null` |
| 方法 | [`configure`](#member-gfanalyticseventschema-methods-configure) | `func configure( p_event_name: StringName, p_schema_version: int, p_properties_schema: GFDictionarySchema ) -> GFAnalyticsEventSchema:` |
| 方法 | [`validate_definition`](#member-gfanalyticseventschema-methods-validate_definition) | `func validate_definition(options: Dictionary = {}) -> GFValidationReport:` |
| 方法 | [`validate_properties`](#member-gfanalyticseventschema-methods-validate_properties) | `func validate_properties(properties: Dictionary, options: Dictionary = {}) -> GFValidationReport:` |
| 方法 | [`duplicate_schema`](#member-gfanalyticseventschema-methods-duplicate_schema) | `func duplicate_schema() -> GFAnalyticsEventSchema:` |
| 方法 | [`describe`](#member-gfanalyticseventschema-methods-describe) | `func describe() -> Dictionary:` |

## 属性

<a id="member-gfanalyticseventschema-properties-event_name"></a>

### `event_name`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var event_name: StringName = &""
```

稳定事件名；不得为空、超过 4096 字符或包含 C0/DEL 控制字符。

<a id="member-gfanalyticseventschema-properties-schema_version"></a>

### `schema_version`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var schema_version: int = 1
```

事件属性 Schema 版本；必须位于 1..2_147_483_647。

<a id="member-gfanalyticseventschema-properties-properties_schema"></a>

### `properties_schema`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var properties_schema: GFDictionarySchema = null
```

事件属性 Dictionary Schema。 Analytics 契约要求根与所有嵌套 Dictionary 禁止额外字段和类型转换。

## 方法

<a id="member-gfanalyticseventschema-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func configure( p_event_name: StringName, p_schema_version: int, p_properties_schema: GFDictionarySchema ) -> GFAnalyticsEventSchema:
```

配置事件属性契约。

参数：

| 名称 | 说明 |
|---|---|
| `p_event_name` | 稳定事件名。 |
| `p_schema_version` | 1..2_147_483_647 范围内的 Schema 版本。 |
| `p_properties_schema` | 严格事件属性 Dictionary Schema。 |

返回：当前事件 Schema。

<a id="member-gfanalyticseventschema-methods-validate_definition"></a>

### `validate_definition`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func validate_definition(options: Dictionary = {}) -> GFValidationReport:
```

校验事件 Schema 定义、递归严格性、图预算和回调纯度边界。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选上下文，支持 subject、path、source_path 和 source。 |

返回：校验报告。

结构：

- `options`: Dictionary validation context.

<a id="member-gfanalyticseventschema-methods-validate_properties"></a>

### `validate_properties`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func validate_properties(properties: Dictionary, options: Dictionary = {}) -> GFValidationReport:
```

校验编码前的 Analytics 事件属性。 该入口不会返回转换后的值，也不会把 Schema 描述为最终 JSON wire schema。

参数：

| 名称 | 说明 |
|---|---|
| `properties` | 待校验事件属性。 |
| `options` | 可选上下文与预算，支持 subject、path、source_path、source、max_depth、max_property_count、max_string_length、max_collection_items、max_total_nodes 和 max_total_bytes。 |

返回：校验报告。

结构：

- `properties`: Dictionary analytics event properties before report encoding.
- `options`: Dictionary validation context and bounded traversal options.

<a id="member-gfanalyticseventschema-methods-duplicate_schema"></a>

### `duplicate_schema`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func duplicate_schema() -> GFAnalyticsEventSchema:
```

创建隔离的事件 Schema 副本。 嵌套 Dictionary Schema、字段和规则通过 GFDictionarySchema.duplicate_schema() 复制； 规则中的 Callable 仍遵循原规则的引用语义，但有效 callback 会被定义校验拒绝。

返回：新事件 Schema。

<a id="member-gfanalyticseventschema-methods-describe"></a>

### `describe`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func describe() -> Dictionary:
```

导出事件 Schema 摘要。

返回：事件 Schema 描述。

结构：

- `return`: Dictionary with event_name, schema_version, and properties_schema.
