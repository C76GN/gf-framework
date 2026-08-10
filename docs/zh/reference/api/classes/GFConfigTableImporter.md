# GFConfigTableImporter

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_table_importer.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用导表文本解析与 schema 校验入口。 提供 JSON、CSV、ConfigFile 与二维文本行的轻量解析，适合编辑器工具或 CI 在进入项目 Provider 前做结构检查。 直接接收内存文本/行的入口不执行字节、行、列或累计单元格预算；调用方必须只传受信数据，或在调用前完成容量预检。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`parse_json_table`](#member-gfconfigtableimporter-methods-parse_json_table) | `static func parse_json_table(text: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`parse_rows_table`](#member-gfconfigtableimporter-methods-parse_rows_table) | `static func parse_rows_table(rows: Array[PackedStringArray], options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`parse_csv_table`](#member-gfconfigtableimporter-methods-parse_csv_table) | `static func parse_csv_table(text: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`parse_config_file_table`](#member-gfconfigtableimporter-methods-parse_config_file_table) | `static func parse_config_file_table(text: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`validate_json_table`](#member-gfconfigtableimporter-methods-validate_json_table) | `static func validate_json_table(text: String, schema: GFConfigTableSchema, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`validate_json_record`](#member-gfconfigtableimporter-methods-validate_json_record) | `static func validate_json_record( text: String, schema: GFConfigTableSchema, row_key: Variant = null, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`validate_csv_table`](#member-gfconfigtableimporter-methods-validate_csv_table) | `static func validate_csv_table(text: String, schema: GFConfigTableSchema, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`validate_config_file_table`](#member-gfconfigtableimporter-methods-validate_config_file_table) | `static func validate_config_file_table(text: String, schema: GFConfigTableSchema, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`export_csv_table`](#member-gfconfigtableimporter-methods-export_csv_table) | `static func export_csv_table( table_data: Variant, schema: GFConfigTableSchema = null, options: Dictionary = {} ) -> Dictionary:` |

## 方法

<a id="member-gfconfigtableimporter-methods-parse_json_table"></a>

### `parse_json_table`

- API：`public`

```gdscript
static func parse_json_table(text: String, options: Dictionary = {}) -> Dictionary:
```

解析 JSON 表文本。

参数：

| 名称 | 说明 |
|---|---|
| `text` | JSON 文本。 |
| `options` | 可选参数，支持 source。 |

返回：结果字典，包含 success、data、error、error_line 与 source。

结构：

- `options`: Dictionary，可包含 source。
- `return`: Dictionary，包含 success、data、error、error_line 和 source。

<a id="member-gfconfigtableimporter-methods-parse_rows_table"></a>

### `parse_rows_table`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func parse_rows_table(rows: Array[PackedStringArray], options: Dictionary = {}) -> Dictionary:
```

把已解析的二维文本表转换为记录数组。 未显式传 header_row 时，传入 rows 的第一行作为表头；显式传 header_row 时按 1-based 源行号定位表头。可通过注释前缀与条件块过滤行列。 条件块只支持 `#if SYMBOL ...` 与 `#endif`，所有 SYMBOL 都在 condition_symbols 中时才保留块内数据行。

参数：

| 名称 | 说明 |
|---|---|
| `rows` | 已解析的二维文本行。 |
| `options` | 可选参数，支持 source、row_numbers、header_row、trim_cells、skip_empty_lines、reject_duplicate_headers、reject_empty_header、require_header、comment_prefixes、comment_row_prefixes、comment_column_prefixes、comment_prefix_case_sensitive、enable_condition_directives、condition_symbols、condition_directive_prefix 和 error_prefix。 |

返回：结果字典，包含 success、data、header、row_locations 与 error。

结构：

- `rows`: Array[PackedStringArray]，每个条目是一行单元格文本。
- `options`: Dictionary，可包含 source、row_numbers、header_row、trim_cells、skip_empty_lines、reject_duplicate_headers、reject_empty_header、require_header、comment_prefixes、comment_row_prefixes、comment_column_prefixes、comment_prefix_case_sensitive、enable_condition_directives、condition_symbols、condition_directive_prefix 和 error_prefix。
- `return`: Dictionary，包含 success、data、header、row_locations、error、error_line、error_column 和 source。

<a id="member-gfconfigtableimporter-methods-parse_csv_table"></a>

### `parse_csv_table`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
static func parse_csv_table(text: String, options: Dictionary = {}) -> Dictionary:
```

解析 CSV 表文本。

参数：

| 名称 | 说明 |
|---|---|
| `text` | CSV 文本。 |
| `options` | 可选参数，支持 delimiter、trim_cells、skip_empty_lines、reject_duplicate_headers、header_row、comment_prefixes、comment_row_prefixes、comment_column_prefixes、comment_prefix_case_sensitive、enable_condition_directives、condition_symbols、condition_directive_prefix、source。 |

返回：结果字典，包含 success、data、header、row_locations 与 error。

结构：

- `options`: Dictionary，可包含 delimiter、trim_cells、skip_empty_lines、reject_duplicate_headers、header_row、comment_prefixes、comment_row_prefixes、comment_column_prefixes、comment_prefix_case_sensitive、enable_condition_directives、condition_symbols、condition_directive_prefix 和 source。
- `return`: Dictionary，包含 success、data、header、row_locations、error、error_line、error_column 和 source。

<a id="member-gfconfigtableimporter-methods-parse_config_file_table"></a>

### `parse_config_file_table`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func parse_config_file_table(text: String, options: Dictionary = {}) -> Dictionary:
```

解析 Godot ConfigFile 表文本。

参数：

| 名称 | 说明 |
|---|---|
| `text` | ConfigFile 文本。 |
| `options` | 可选参数，支持 source、section_field、include_empty_sections。 |

返回：结果字典，包含 success、data、sections、row_locations 与 error。

结构：

- `options`: Dictionary，可包含 source、section_field、include_empty_sections 字段；section_field 为空 StringName 时不写入 section 名字段。
- `return`: Dictionary，包含 success、data、sections、row_locations、error、error_line、error_column 和 source。

<a id="member-gfconfigtableimporter-methods-validate_json_table"></a>

### `validate_json_table`

- API：`public`

```gdscript
static func validate_json_table(text: String, schema: GFConfigTableSchema, options: Dictionary = {}) -> Dictionary:
```

解析并校验 JSON 表文本。

参数：

| 名称 | 说明 |
|---|---|
| `text` | JSON 文本。 |
| `schema` | 表结构声明。 |
| `options` | 可选参数，支持 source。 |

返回：校验报告；解析失败时返回失败报告。

结构：

- `options`: Dictionary，可包含 source。
- `return`: GFConfigValidationReport 兼容 Dictionary。

<a id="member-gfconfigtableimporter-methods-validate_json_record"></a>

### `validate_json_record`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
static func validate_json_record( text: String, schema: GFConfigTableSchema, row_key: Variant = null, options: Dictionary = {} ) -> Dictionary:
```

解析并校验 JSON 单记录文本。

参数：

| 名称 | 说明 |
|---|---|
| `text` | JSON 文本，根节点必须是 Dictionary。 |
| `schema` | 表结构声明；当前方法复用其字段声明校验单条记录。 |
| `row_key` | 可选行标识；为空且 schema 声明了 id_field 时会尝试从记录字段读取。 |
| `options` | 可选参数，支持 source。 |

返回：校验报告；解析失败或根节点不是 Dictionary 时返回失败报告。

结构：

- `row_key`: Variant，写入校验报告 issue 的行标识。
- `options`: Dictionary，可包含 source。
- `return`: GFConfigValidationReport 兼容 Dictionary。

<a id="member-gfconfigtableimporter-methods-validate_csv_table"></a>

### `validate_csv_table`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
static func validate_csv_table(text: String, schema: GFConfigTableSchema, options: Dictionary = {}) -> Dictionary:
```

解析并校验 CSV 表文本。

参数：

| 名称 | 说明 |
|---|---|
| `text` | CSV 文本。 |
| `schema` | 表结构声明。 |
| `options` | 可选参数，支持 delimiter、trim_cells、skip_empty_lines、reject_duplicate_headers、header_row、comment_prefixes、comment_row_prefixes、comment_column_prefixes、comment_prefix_case_sensitive、enable_condition_directives、condition_symbols、condition_directive_prefix 和 source。 |

返回：校验报告；解析失败时返回失败报告。

结构：

- `options`: Dictionary，可包含 delimiter、trim_cells、skip_empty_lines、reject_duplicate_headers、header_row、comment_prefixes、comment_row_prefixes、comment_column_prefixes、comment_prefix_case_sensitive、enable_condition_directives、condition_symbols、condition_directive_prefix 和 source。
- `return`: GFConfigValidationReport 兼容 Dictionary。

<a id="member-gfconfigtableimporter-methods-validate_config_file_table"></a>

### `validate_config_file_table`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func validate_config_file_table(text: String, schema: GFConfigTableSchema, options: Dictionary = {}) -> Dictionary:
```

解析并校验 Godot ConfigFile 表文本。

参数：

| 名称 | 说明 |
|---|---|
| `text` | ConfigFile 文本。 |
| `schema` | 表结构声明。 |
| `options` | 可选参数，支持 source、section_field、include_empty_sections。 |

返回：校验报告；解析失败时返回失败报告。

结构：

- `options`: Dictionary，可包含 source、section_field 和 include_empty_sections 字段。
- `return`: GFConfigValidationReport 兼容 Dictionary。

<a id="member-gfconfigtableimporter-methods-export_csv_table"></a>

### `export_csv_table`

- API：`public`

```gdscript
static func export_csv_table( table_data: Variant, schema: GFConfigTableSchema = null, options: Dictionary = {} ) -> Dictionary:
```

导出 CSV 表文本。

参数：

| 名称 | 说明 |
|---|---|
| `table_data` | Array[Dictionary] 或 Dictionary 形式的表数据。 |
| `schema` | 可选 schema；提供时默认按 schema.columns 排列列。 |
| `options` | 可选参数，支持 delimiter、columns、include_header、coerce_values。 |

返回：结果字典，包含 success、text 与 error。

结构：

- `table_data`: Variant，支持 Array[Dictionary] 或 Dictionary，记录值必须为 Dictionary。
- `options`: Dictionary，可包含 delimiter、columns、include_header 和 coerce_values。
- `return`: Dictionary，包含 success、text 和 error。
