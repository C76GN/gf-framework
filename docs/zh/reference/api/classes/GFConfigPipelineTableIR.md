# GFConfigPipelineTableIR

[API Reference](../index.md) / [Tool Packages](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_pipeline_table_ir.gd`
- 模块：`Tool Packages`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`unreleased`

Config Pipeline 的版本化单表中间表示。 保存布局解析与语义校验后的规范记录、schema、来源映射和元数据。 IR 只描述可物化的数据，不负责读取来源、生成 Resource 或提交文件。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`FORMAT`](#member-gfconfigpipelinetableir-constants-format) | `const FORMAT: String = "gf.config_pipeline.table_ir"` |
| 常量 | [`FORMAT_VERSION`](#member-gfconfigpipelinetableir-constants-format_version) | `const FORMAT_VERSION: int = 1` |
| 方法 | [`create`](#member-gfconfigpipelinetableir-methods-create) | `static func create( table_name: StringName, source_path: String, source_format: StringName, records: Array[Dictionary], schema: GFConfigTableSchema = null, source_map: Dictionary = {}, metadata: Dictionary = {} ) -> GFConfigPipelineTableIR:` |
| 方法 | [`validate_contract`](#member-gfconfigpipelinetableir-methods-validate_contract) | `func validate_contract() -> Dictionary:` |
| 方法 | [`get_table_name`](#member-gfconfigpipelinetableir-methods-get_table_name) | `func get_table_name() -> StringName:` |
| 方法 | [`get_source_path`](#member-gfconfigpipelinetableir-methods-get_source_path) | `func get_source_path() -> String:` |
| 方法 | [`get_source_format`](#member-gfconfigpipelinetableir-methods-get_source_format) | `func get_source_format() -> StringName:` |
| 方法 | [`get_records`](#member-gfconfigpipelinetableir-methods-get_records) | `func get_records() -> Array[Dictionary]:` |
| 方法 | [`get_schema`](#member-gfconfigpipelinetableir-methods-get_schema) | `func get_schema() -> GFConfigTableSchema:` |
| 方法 | [`get_source_map`](#member-gfconfigpipelinetableir-methods-get_source_map) | `func get_source_map() -> Dictionary:` |
| 方法 | [`get_metadata`](#member-gfconfigpipelinetableir-methods-get_metadata) | `func get_metadata() -> Dictionary:` |
| 方法 | [`duplicate_ir`](#member-gfconfigpipelinetableir-methods-duplicate_ir) | `func duplicate_ir() -> GFConfigPipelineTableIR:` |
| 方法 | [`describe`](#member-gfconfigpipelinetableir-methods-describe) | `func describe() -> Dictionary:` |

## 常量

<a id="member-gfconfigpipelinetableir-constants-format"></a>

### `FORMAT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const FORMAT: String = "gf.config_pipeline.table_ir"
```

单表 IR 的稳定格式标识。

<a id="member-gfconfigpipelinetableir-constants-format_version"></a>

### `FORMAT_VERSION`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const FORMAT_VERSION: int = 1
```

单表 IR 的格式版本。

## 方法

<a id="member-gfconfigpipelinetableir-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create( table_name: StringName, source_path: String, source_format: StringName, records: Array[Dictionary], schema: GFConfigTableSchema = null, source_map: Dictionary = {}, metadata: Dictionary = {} ) -> GFConfigPipelineTableIR:
```

创建单表 IR，并取得所有可变输入的副本所有权。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 稳定表名。 |
| `source_path` | 原始来源路径；内存来源可为空。 |
| `source_format` | 已解析的来源格式。 |
| `records` | 已规范化并完成类型转换的记录。 |
| `schema` | 已解析的表结构；可为空。 |
| `source_map` | 来源定位信息。 |
| `metadata` | 与目标无关的表元数据。 |

返回：新建的单表 IR。

结构：

- `records`: Array[Dictionary]，每个 Dictionary 是一条规范配置记录。
- `source_map`: Dictionary，可包含 header、row_locations、source 和格式专属定位数据。
- `metadata`: Dictionary，保存来源摘要和调用方附加元数据。

<a id="member-gfconfigpipelinetableir-methods-validate_contract"></a>

### `validate_contract`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func validate_contract() -> Dictionary:
```

校验 IR 自身的版本和结构契约。

返回：契约校验结果。

结构：

- `return`: Dictionary，包含 success、error_code、error_kind 和 error。

<a id="member-gfconfigpipelinetableir-methods-get_table_name"></a>

### `get_table_name`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_table_name() -> StringName:
```

获取表名。

返回：稳定表名。

<a id="member-gfconfigpipelinetableir-methods-get_source_path"></a>

### `get_source_path`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_source_path() -> String:
```

获取来源路径。

返回：原始来源路径。

<a id="member-gfconfigpipelinetableir-methods-get_source_format"></a>

### `get_source_format`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_source_format() -> StringName:
```

获取已解析的来源格式。

返回：来源格式。

<a id="member-gfconfigpipelinetableir-methods-get_records"></a>

### `get_records`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_records() -> Array[Dictionary]:
```

获取规范记录。

返回：规范记录列表。

结构：

- `return`: Array[Dictionary]，每个 Dictionary 是一条规范配置记录。

<a id="member-gfconfigpipelinetableir-methods-get_schema"></a>

### `get_schema`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_schema() -> GFConfigTableSchema:
```

获取表结构。

返回：表结构；未声明时返回 null。

<a id="member-gfconfigpipelinetableir-methods-get_source_map"></a>

### `get_source_map`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_source_map() -> Dictionary:
```

获取来源定位映射。

返回：来源定位映射的深拷贝。

结构：

- `return`: Dictionary，可包含 header、row_locations、source 和格式专属定位数据。

<a id="member-gfconfigpipelinetableir-methods-get_metadata"></a>

### `get_metadata`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_metadata() -> Dictionary:
```

获取表元数据。

返回：表元数据的深拷贝。

结构：

- `return`: Dictionary，保存来源摘要和调用方附加元数据。

<a id="member-gfconfigpipelinetableir-methods-duplicate_ir"></a>

### `duplicate_ir`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_ir() -> GFConfigPipelineTableIR:
```

创建内容等价且不共享可变状态的 IR。

返回：单表 IR 副本。

<a id="member-gfconfigpipelinetableir-methods-describe"></a>

### `describe`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func describe() -> Dictionary:
```

导出不包含完整记录载荷的稳定摘要。

返回：IR 摘要。

结构：

- `return`: Dictionary，包含 format、format_version、table_name、source_path、source_format、record_count、schema、source_map 和 metadata。
