# GFEditorToolOptionSchema

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_editor_tool_option_schema.gd`
- 模块：`Kernel`
- 继承：`Resource`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

编辑器工具选项集合声明。 为工具面板、持久化和调试快照提供稳定的选项描述与值规范化入口。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`options`](#member-gfeditortooloptionschema-properties-options) | `var options: Array[GFEditorToolOption] = []` |
| 属性 | [`metadata`](#member-gfeditortooloptionschema-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`add_option`](#member-gfeditortooloptionschema-methods-add_option) | `func add_option(option: GFEditorToolOption) -> bool:` |
| 方法 | [`remove_option`](#member-gfeditortooloptionschema-methods-remove_option) | `func remove_option(option_id: StringName) -> bool:` |
| 方法 | [`clear_options`](#member-gfeditortooloptionschema-methods-clear_options) | `func clear_options() -> void:` |
| 方法 | [`get_option`](#member-gfeditortooloptionschema-methods-get_option) | `func get_option(option_id: StringName) -> GFEditorToolOption:` |
| 方法 | [`has_option`](#member-gfeditortooloptionschema-methods-has_option) | `func has_option(option_id: StringName) -> bool:` |
| 方法 | [`get_option_ids`](#member-gfeditortooloptionschema-methods-get_option_ids) | `func get_option_ids() -> PackedStringArray:` |
| 方法 | [`get_default_values`](#member-gfeditortooloptionschema-methods-get_default_values) | `func get_default_values() -> Dictionary:` |
| 方法 | [`normalize_values`](#member-gfeditortooloptionschema-methods-normalize_values) | `func normalize_values(values: Dictionary, include_defaults: bool = true) -> Dictionary:` |
| 方法 | [`validate_values`](#member-gfeditortooloptionschema-methods-validate_values) | `func validate_values(values: Dictionary) -> Dictionary:` |
| 方法 | [`duplicate_schema`](#member-gfeditortooloptionschema-methods-duplicate_schema) | `func duplicate_schema() -> GFEditorToolOptionSchema:` |
| 方法 | [`describe`](#member-gfeditortooloptionschema-methods-describe) | `func describe() -> Dictionary:` |

## 属性

<a id="member-gfeditortooloptionschema-properties-options"></a>

### `options`

- API：`public`

```gdscript
var options: Array[GFEditorToolOption] = []
```

工具选项列表。

<a id="member-gfeditortooloptionschema-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据，供项目层扩展使用。

结构：

- `metadata`: Dictionary for caller-defined option schema metadata.

## 方法

<a id="member-gfeditortooloptionschema-methods-add_option"></a>

### `add_option`

- API：`public`

```gdscript
func add_option(option: GFEditorToolOption) -> bool:
```

添加或替换选项声明。

参数：

| 名称 | 说明 |
|---|---|
| `option` | 选项声明。 |

返回：添加成功返回 true。

<a id="member-gfeditortooloptionschema-methods-remove_option"></a>

### `remove_option`

- API：`public`

```gdscript
func remove_option(option_id: StringName) -> bool:
```

移除选项声明。

参数：

| 名称 | 说明 |
|---|---|
| `option_id` | 选项标识。 |

返回：移除成功返回 true。

<a id="member-gfeditortooloptionschema-methods-clear_options"></a>

### `clear_options`

- API：`public`

```gdscript
func clear_options() -> void:
```

清空选项声明。

<a id="member-gfeditortooloptionschema-methods-get_option"></a>

### `get_option`

- API：`public`

```gdscript
func get_option(option_id: StringName) -> GFEditorToolOption:
```

获取选项声明。

参数：

| 名称 | 说明 |
|---|---|
| `option_id` | 选项标识。 |

返回：找到时返回选项声明，否则返回 null。

<a id="member-gfeditortooloptionschema-methods-has_option"></a>

### `has_option`

- API：`public`

```gdscript
func has_option(option_id: StringName) -> bool:
```

检查选项声明是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `option_id` | 选项标识。 |

返回：存在返回 true。

<a id="member-gfeditortooloptionschema-methods-get_option_ids"></a>

### `get_option_ids`

- API：`public`

```gdscript
func get_option_ids() -> PackedStringArray:
```

获取选项 ID 列表。

返回：排序后的选项 ID。

<a id="member-gfeditortooloptionschema-methods-get_default_values"></a>

### `get_default_values`

- API：`public`

```gdscript
func get_default_values() -> Dictionary:
```

获取默认值字典。

返回：选项 ID 到默认值的字典。

结构：

- `return`: Dictionary keyed by option_id, storing normalized default values.

<a id="member-gfeditortooloptionschema-methods-normalize_values"></a>

### `normalize_values`

- API：`public`

```gdscript
func normalize_values(values: Dictionary, include_defaults: bool = true) -> Dictionary:
```

规范化一组选项值。

参数：

| 名称 | 说明 |
|---|---|
| `values` | 输入选项值。 |
| `include_defaults` | 为 true 时补齐缺失默认值。 |

返回：规范化后的选项字典。

结构：

- `values`: Dictionary keyed by option_id, storing raw option values.
- `return`: Dictionary keyed by option_id, storing normalized option values.

<a id="member-gfeditortooloptionschema-methods-validate_values"></a>

### `validate_values`

- API：`public`

```gdscript
func validate_values(values: Dictionary) -> Dictionary:
```

校验一组选项值。

参数：

| 名称 | 说明 |
|---|---|
| `values` | 输入选项值。 |

返回：校验报告字典。

结构：

- `values`: Dictionary keyed by option_id, storing option values to validate.
- `return`: Dictionary containing ok, error_count, warning_count, and issues.

<a id="member-gfeditortooloptionschema-methods-duplicate_schema"></a>

### `duplicate_schema`

- API：`public`

```gdscript
func duplicate_schema() -> GFEditorToolOptionSchema:
```

创建同内容拷贝。

返回：新选项集合声明。

<a id="member-gfeditortooloptionschema-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出选项集合摘要。

返回：选项集合字典。

结构：

- `return`: Dictionary containing option descriptions and metadata.
