# GFBlackboardSchema

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/blackboard/gf_blackboard_schema.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用黑板数据结构声明与校验器。 用于为行为树、状态机、任务系统或项目自定义运行时字典提供可复用字段契约。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`schema_id`](#member-gfblackboardschema-properties-schema_id) | `var schema_id: StringName = &""` |
| 属性 | [`entries`](#member-gfblackboardschema-properties-entries) | `var entries: Array[GFBlackboardEntry] = []` |
| 属性 | [`allow_extra_keys`](#member-gfblackboardschema-properties-allow_extra_keys) | `var allow_extra_keys: bool = true` |
| 属性 | [`coerce_values`](#member-gfblackboardschema-properties-coerce_values) | `var coerce_values: bool = false` |
| 属性 | [`fail_on_coerce_error`](#member-gfblackboardschema-properties-fail_on_coerce_error) | `var fail_on_coerce_error: bool = true` |
| 属性 | [`metadata`](#member-gfblackboardschema-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_schema_key`](#member-gfblackboardschema-methods-get_schema_key) | `func get_schema_key() -> StringName:` |
| 方法 | [`get_entry`](#member-gfblackboardschema-methods-get_entry) | `func get_entry(entry_key: StringName) -> GFBlackboardEntry:` |
| 方法 | [`has_entry`](#member-gfblackboardschema-methods-has_entry) | `func has_entry(entry_key: StringName) -> bool:` |
| 方法 | [`get_entry_keys`](#member-gfblackboardschema-methods-get_entry_keys) | `func get_entry_keys() -> PackedStringArray:` |
| 方法 | [`build_defaults`](#member-gfblackboardschema-methods-build_defaults) | `func build_defaults(include_optional: bool = true) -> Dictionary:` |
| 方法 | [`apply_defaults`](#member-gfblackboardschema-methods-apply_defaults) | `func apply_defaults(values: Dictionary, include_optional: bool = true, should_coerce: bool = true) -> Dictionary:` |
| 方法 | [`coerce_dictionary`](#member-gfblackboardschema-methods-coerce_dictionary) | `func coerce_dictionary(values: Dictionary, include_defaults: bool = true) -> Dictionary:` |
| 方法 | [`validate_values`](#member-gfblackboardschema-methods-validate_values) | `func validate_values(values: Dictionary) -> Dictionary:` |
| 方法 | [`duplicate_schema`](#member-gfblackboardschema-methods-duplicate_schema) | `func duplicate_schema() -> GFBlackboardSchema:` |
| 方法 | [`describe`](#member-gfblackboardschema-methods-describe) | `func describe() -> Dictionary:` |

## 属性

<a id="member-gfblackboardschema-properties-schema_id"></a>

### `schema_id`

- API：`public`

```gdscript
var schema_id: StringName = &""
```

Schema 标识。为空时可由调用方自行决定命名。

<a id="member-gfblackboardschema-properties-entries"></a>

### `entries`

- API：`public`

```gdscript
var entries: Array[GFBlackboardEntry] = []
```

字段声明列表。

<a id="member-gfblackboardschema-properties-allow_extra_keys"></a>

### `allow_extra_keys`

- API：`public`

```gdscript
var allow_extra_keys: bool = true
```

是否允许包含 schema 未声明的字段。

<a id="member-gfblackboardschema-properties-coerce_values"></a>

### `coerce_values`

- API：`public`

```gdscript
var coerce_values: bool = false
```

是否在校验前按字段声明尝试类型转换。

<a id="member-gfblackboardschema-properties-fail_on_coerce_error"></a>

### `fail_on_coerce_error`

- API：`public`

```gdscript
var fail_on_coerce_error: bool = true
```

启用 coerce_values 时，转换失败是否作为校验错误。

<a id="member-gfblackboardschema-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据，供编辑器、调试器或项目工具使用。

结构：

- `metadata`: Dictionary metadata for editor, debugger, or project tooling.

## 方法

<a id="member-gfblackboardschema-methods-get_schema_key"></a>

### `get_schema_key`

- API：`public`

```gdscript
func get_schema_key() -> StringName:
```

获取稳定 schema 键。

返回：Schema 标识。

<a id="member-gfblackboardschema-methods-get_entry"></a>

### `get_entry`

- API：`public`

```gdscript
func get_entry(entry_key: StringName) -> GFBlackboardEntry:
```

获取字段声明。

参数：

| 名称 | 说明 |
|---|---|
| `entry_key` | 字段键。 |

返回：找到时返回字段声明，否则返回 null。

<a id="member-gfblackboardschema-methods-has_entry"></a>

### `has_entry`

- API：`public`

```gdscript
func has_entry(entry_key: StringName) -> bool:
```

检查字段声明是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `entry_key` | 字段键。 |

返回：存在返回 true。

<a id="member-gfblackboardschema-methods-get_entry_keys"></a>

### `get_entry_keys`

- API：`public`

```gdscript
func get_entry_keys() -> PackedStringArray:
```

获取当前 schema 的字段键列表。

返回：排序后的字段键。

<a id="member-gfblackboardschema-methods-build_defaults"></a>

### `build_defaults`

- API：`public`

```gdscript
func build_defaults(include_optional: bool = true) -> Dictionary:
```

创建默认黑板数据。

参数：

| 名称 | 说明 |
|---|---|
| `include_optional` | 为 true 时包含非必填字段。 |

返回：默认数据字典。

结构：

- `return`: Dictionary default blackboard values.

<a id="member-gfblackboardschema-methods-apply_defaults"></a>

### `apply_defaults`

- API：`public`

```gdscript
func apply_defaults(values: Dictionary, include_optional: bool = true, should_coerce: bool = true) -> Dictionary:
```

为输入数据补齐默认值。

参数：

| 名称 | 说明 |
|---|---|
| `values` | 输入黑板数据。 |
| `include_optional` | 为 true 时补齐非必填字段。 |
| `should_coerce` | 为 true 时按字段声明转换已有值与默认值。 |

返回：补齐后的新字典。

结构：

- `values`: Dictionary source blackboard values.
- `return`: Dictionary normalized blackboard values.

<a id="member-gfblackboardschema-methods-coerce_dictionary"></a>

### `coerce_dictionary`

- API：`public`

```gdscript
func coerce_dictionary(values: Dictionary, include_defaults: bool = true) -> Dictionary:
```

按字段声明转换黑板数据。

参数：

| 名称 | 说明 |
|---|---|
| `values` | 输入黑板数据。 |
| `include_defaults` | 为 true 时同时补默认值。 |

返回：转换后的新字典。

结构：

- `values`: Dictionary source blackboard values.
- `return`: Dictionary coerced blackboard values.

<a id="member-gfblackboardschema-methods-validate_values"></a>

### `validate_values`

- API：`public`

```gdscript
func validate_values(values: Dictionary) -> Dictionary:
```

校验黑板数据。

参数：

| 名称 | 说明 |
|---|---|
| `values` | 输入黑板数据。 |

返回：校验报告字典。

结构：

- `values`: Dictionary source blackboard values.
- `return`: Dictionary validation report.

<a id="member-gfblackboardschema-methods-duplicate_schema"></a>

### `duplicate_schema`

- API：`public`

```gdscript
func duplicate_schema() -> GFBlackboardSchema:
```

创建同内容拷贝，避免运行时修改污染共享 Resource。

返回：新 schema。

<a id="member-gfblackboardschema-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出 schema 摘要。

返回：schema 字典。

结构：

- `return`: Dictionary schema description.
