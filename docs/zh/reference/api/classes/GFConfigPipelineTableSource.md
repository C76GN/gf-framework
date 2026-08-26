# GFConfigPipelineTableSource

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_pipeline_table_source.gd`
- 模块：`Tools`
- 继承：`Resource`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`5.2.0`

配置导表工具的单表来源声明。 描述一张配置表的输入路径、格式、schema、解析选项和导出元数据。 该资源属于可选 tool package，只表达制作期或 CI 期通用导入来源，不规定项目表名、业务字段、目录结构或发布策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`FORMAT_AUTO`](#member-gfconfigpipelinetablesource-constants-format_auto) | `const FORMAT_AUTO: StringName = &"auto"` |
| 常量 | [`FORMAT_CSV`](#member-gfconfigpipelinetablesource-constants-format_csv) | `const FORMAT_CSV: StringName = &"csv"` |
| 常量 | [`FORMAT_JSON`](#member-gfconfigpipelinetablesource-constants-format_json) | `const FORMAT_JSON: StringName = &"json"` |
| 常量 | [`FORMAT_CONFIG_FILE`](#member-gfconfigpipelinetablesource-constants-format_config_file) | `const FORMAT_CONFIG_FILE: StringName = &"config_file"` |
| 常量 | [`FORMAT_XLSX`](#member-gfconfigpipelinetablesource-constants-format_xlsx) | `const FORMAT_XLSX: StringName = &"xlsx"` |
| 属性 | [`table_name`](#member-gfconfigpipelinetablesource-properties-table_name) | `var table_name: StringName = &""` |
| 属性 | [`source_path`](#member-gfconfigpipelinetablesource-properties-source_path) | `var source_path: String = ""` |
| 属性 | [`source_format`](#member-gfconfigpipelinetablesource-properties-source_format) | `var source_format: StringName = FORMAT_AUTO` |
| 属性 | [`schema`](#member-gfconfigpipelinetablesource-properties-schema) | `var schema: GFConfigTableSchema = null` |
| 属性 | [`infer_schema`](#member-gfconfigpipelinetablesource-properties-infer_schema) | `var infer_schema: bool = true` |
| 属性 | [`coerce_records`](#member-gfconfigpipelinetablesource-properties-coerce_records) | `var coerce_records: bool = true` |
| 属性 | [`parse_options`](#member-gfconfigpipelinetablesource-properties-parse_options) | `var parse_options: Dictionary = {}` |
| 属性 | [`schema_options`](#member-gfconfigpipelinetablesource-properties-schema_options) | `var schema_options: Dictionary = {}` |
| 属性 | [`metadata`](#member-gfconfigpipelinetablesource-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_table_key`](#member-gfconfigpipelinetablesource-methods-get_table_key) | `func get_table_key() -> StringName:` |
| 方法 | [`get_resolved_format`](#member-gfconfigpipelinetablesource-methods-get_resolved_format) | `func get_resolved_format() -> StringName:` |
| 方法 | [`duplicate_source`](#member-gfconfigpipelinetablesource-methods-duplicate_source) | `func duplicate_source() -> GFConfigPipelineTableSource:` |
| 方法 | [`describe`](#member-gfconfigpipelinetablesource-methods-describe) | `func describe() -> Dictionary:` |

## 常量

<a id="member-gfconfigpipelinetablesource-constants-format_auto"></a>

### `FORMAT_AUTO`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
const FORMAT_AUTO: StringName = &"auto"
```

根据 source_path 扩展名推断输入格式。

<a id="member-gfconfigpipelinetablesource-constants-format_csv"></a>

### `FORMAT_CSV`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
const FORMAT_CSV: StringName = &"csv"
```

CSV 输入格式。

<a id="member-gfconfigpipelinetablesource-constants-format_json"></a>

### `FORMAT_JSON`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
const FORMAT_JSON: StringName = &"json"
```

JSON 输入格式。

<a id="member-gfconfigpipelinetablesource-constants-format_config_file"></a>

### `FORMAT_CONFIG_FILE`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const FORMAT_CONFIG_FILE: StringName = &"config_file"
```

Godot ConfigFile 输入格式。

<a id="member-gfconfigpipelinetablesource-constants-format_xlsx"></a>

### `FORMAT_XLSX`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
const FORMAT_XLSX: StringName = &"xlsx"
```

XLSX 输入格式。

## 属性

<a id="member-gfconfigpipelinetablesource-properties-table_name"></a>

### `table_name`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var table_name: StringName = &""
```

表名。为空时会尝试使用 schema.table_name 或 source_path 文件名。

<a id="member-gfconfigpipelinetablesource-properties-source_path"></a>

### `source_path`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var source_path: String = ""
```

输入文件路径。支持 Godot 可读取的 res://、user:// 或绝对路径。

<a id="member-gfconfigpipelinetablesource-properties-source_format"></a>

### `source_format`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var source_format: StringName = FORMAT_AUTO
```

输入格式。使用 FORMAT_AUTO 时根据 source_path 扩展名推断。

<a id="member-gfconfigpipelinetablesource-properties-schema"></a>

### `schema`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var schema: GFConfigTableSchema = null
```

可选 schema。为空且 infer_schema 为 true 时，会从记录样本推导通用 schema。

<a id="member-gfconfigpipelinetablesource-properties-infer_schema"></a>

### `infer_schema`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var infer_schema: bool = true
```

是否在缺少 schema 时从导入记录推导通用 schema。

<a id="member-gfconfigpipelinetablesource-properties-coerce_records"></a>

### `coerce_records`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var coerce_records: bool = true
```

是否在 schema.coerce_values 为 true 时把保存进资源的记录也转换为 schema 类型。

<a id="member-gfconfigpipelinetablesource-properties-parse_options"></a>

### `parse_options`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var parse_options: Dictionary = {}
```

传给解析器的选项，例如 CSV delimiter、trim_cells、skip_empty_lines、comment_prefixes、condition_symbols，ConfigFile section_field、include_empty_sections，或 XLSX sheet_name、sheet_index、header_row。

结构：

- `parse_options`: Dictionary，可包含 GFConfigTableImporter 支持的 CSV / JSON / ConfigFile 解析选项，以及 XLSX sheet_name、sheet_index、header_row、trim_cells、skip_empty_lines、reject_duplicate_headers、comment_prefixes、comment_row_prefixes、comment_column_prefixes、condition_symbols 和 enable_condition_directives。

<a id="member-gfconfigpipelinetablesource-properties-schema_options"></a>

### `schema_options`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var schema_options: Dictionary = {}
```

schema 推导与表头声明选项，例如 id_field、allow_extra_fields、required_if_present_in_all_rows、typed_headers 或 typed_header_type_row。

结构：

- `schema_options`: Dictionary，可包含 GFConfigTableSchema.infer_from_records() 支持的选项，以及 typed_headers、typed_header_type_row、coerce_values、fail_on_coerce_error、require_unique_id。

<a id="member-gfconfigpipelinetablesource-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var metadata: Dictionary = {}
```

附加到生成表资源的元数据。

结构：

- `metadata`: Dictionary，保存项目工具、编辑器或 CI 附加的来源信息。

## 方法

<a id="member-gfconfigpipelinetablesource-methods-get_table_key"></a>

### `get_table_key`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_table_key() -> StringName:
```

获取稳定表键。

返回：表名；无法从 table_name、schema 或 source_path 推断时返回空 StringName。

<a id="member-gfconfigpipelinetablesource-methods-get_resolved_format"></a>

### `get_resolved_format`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_resolved_format() -> StringName:
```

获取声明或推断出的来源格式。

返回：FORMAT_CSV、FORMAT_JSON、FORMAT_CONFIG_FILE、FORMAT_AUTO 或调用方设置的自定义格式名。

<a id="member-gfconfigpipelinetablesource-methods-duplicate_source"></a>

### `duplicate_source`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func duplicate_source() -> GFConfigPipelineTableSource:
```

创建同内容拷贝。

返回：新来源声明资源。

<a id="member-gfconfigpipelinetablesource-methods-describe"></a>

### `describe`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func describe() -> Dictionary:
```

导出来源声明摘要。

返回：来源声明字典。

结构：

- `return`: Dictionary，包含 table_name、source_path、source_format、resolved_format、schema、schema_path、infer_schema、coerce_records、parse_options、schema_options 和 metadata。
