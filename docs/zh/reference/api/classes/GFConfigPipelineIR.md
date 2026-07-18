# GFConfigPipelineIR

[API Reference](../index.md) / [Tool Packages](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_pipeline_ir.gd`
- 模块：`Tool Packages`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`unreleased`

Config Pipeline 的版本化数据库中间表示。 聚合已经通过单表语义校验的 GFConfigPipelineTableIR，并作为 Target 阶段的唯一输入。 IR 不持有导出路径或文件事务策略，确保同一编译结果可以交给多个目标实现。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`FORMAT`](#member-gfconfigpipelineir-constants-format) | `const FORMAT: String = "gf.config_pipeline.ir"` |
| 常量 | [`FORMAT_VERSION`](#member-gfconfigpipelineir-constants-format_version) | `const FORMAT_VERSION: int = 1` |
| 方法 | [`create`](#member-gfconfigpipelineir-methods-create) | `static func create( database_id: StringName = &"", version: String = "", metadata: Dictionary = {} ) -> GFConfigPipelineIR:` |
| 方法 | [`add_table`](#member-gfconfigpipelineir-methods-add_table) | `func add_table(table_ir: GFConfigPipelineTableIR) -> Dictionary:` |
| 方法 | [`seal`](#member-gfconfigpipelineir-methods-seal) | `func seal() -> Dictionary:` |
| 方法 | [`is_sealed`](#member-gfconfigpipelineir-methods-is_sealed) | `func is_sealed() -> bool:` |
| 方法 | [`validate_contract`](#member-gfconfigpipelineir-methods-validate_contract) | `func validate_contract() -> Dictionary:` |
| 方法 | [`get_database_id`](#member-gfconfigpipelineir-methods-get_database_id) | `func get_database_id() -> StringName:` |
| 方法 | [`get_version`](#member-gfconfigpipelineir-methods-get_version) | `func get_version() -> String:` |
| 方法 | [`get_metadata`](#member-gfconfigpipelineir-methods-get_metadata) | `func get_metadata() -> Dictionary:` |
| 方法 | [`get_table`](#member-gfconfigpipelineir-methods-get_table) | `func get_table(table_name: StringName) -> GFConfigPipelineTableIR:` |
| 方法 | [`get_tables`](#member-gfconfigpipelineir-methods-get_tables) | `func get_tables() -> Array[GFConfigPipelineTableIR]:` |
| 方法 | [`duplicate_ir`](#member-gfconfigpipelineir-methods-duplicate_ir) | `func duplicate_ir() -> GFConfigPipelineIR:` |
| 方法 | [`describe`](#member-gfconfigpipelineir-methods-describe) | `func describe() -> Dictionary:` |

## 常量

<a id="member-gfconfigpipelineir-constants-format"></a>

### `FORMAT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const FORMAT: String = "gf.config_pipeline.ir"
```

数据库 IR 的稳定格式标识。

<a id="member-gfconfigpipelineir-constants-format_version"></a>

### `FORMAT_VERSION`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const FORMAT_VERSION: int = 1
```

数据库 IR 的格式版本。

## 方法

<a id="member-gfconfigpipelineir-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create( database_id: StringName = &"", version: String = "", metadata: Dictionary = {} ) -> GFConfigPipelineIR:
```

创建空数据库 IR，并取得元数据的副本所有权。

参数：

| 名称 | 说明 |
|---|---|
| `database_id` | 数据库标识；可为空。 |
| `version` | 项目侧配置版本；可为空。 |
| `metadata` | 与目标无关的数据库元数据。 |

返回：新建的数据库 IR。

结构：

- `metadata`: Dictionary，保存构建上下文或项目侧附加元数据。

<a id="member-gfconfigpipelineir-methods-add_table"></a>

### `add_table`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func add_table(table_ir: GFConfigPipelineTableIR) -> Dictionary:
```

注册不可变单表 IR。重复表名和损坏契约会 fail closed，且不会污染当前 IR。

参数：

| 名称 | 说明 |
|---|---|
| `table_ir` | 已完成语义校验的单表 IR。 |

返回：注册结果。

结构：

- `return`: Dictionary，包含 success、error_code、error_kind、error 和 table_name。

<a id="member-gfconfigpipelineir-methods-seal"></a>

### `seal`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func seal() -> Dictionary:
```

封存数据库 IR。封存成功后不能再注册表，且 IR 才能交给 Target。

返回：封存结果。

结构：

- `return`: Dictionary，包含 success、error_code、error_kind、error 和 table_name。

<a id="member-gfconfigpipelineir-methods-is_sealed"></a>

### `is_sealed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_sealed() -> bool:
```

返回 IR 是否已封存。

返回：已封存时为 true。

<a id="member-gfconfigpipelineir-methods-validate_contract"></a>

### `validate_contract`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func validate_contract() -> Dictionary:
```

校验数据库 IR 已封存，且自身及全部单表 IR 满足结构契约。

返回：契约校验结果。

结构：

- `return`: Dictionary，包含 success、error_code、error_kind、error 和 table_name。

<a id="member-gfconfigpipelineir-methods-get_database_id"></a>

### `get_database_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_database_id() -> StringName:
```

获取数据库标识。

返回：数据库标识。

<a id="member-gfconfigpipelineir-methods-get_version"></a>

### `get_version`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_version() -> String:
```

获取项目侧配置版本。

返回：配置版本。

<a id="member-gfconfigpipelineir-methods-get_metadata"></a>

### `get_metadata`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_metadata() -> Dictionary:
```

获取数据库元数据。

返回：数据库元数据的深拷贝。

结构：

- `return`: Dictionary，保存构建上下文或项目侧附加元数据。

<a id="member-gfconfigpipelineir-methods-get_table"></a>

### `get_table`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_table(table_name: StringName) -> GFConfigPipelineTableIR:
```

获取不可变单表 IR。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 稳定表名。 |

返回：找到时返回不可变单表 IR，否则返回 null。

<a id="member-gfconfigpipelineir-methods-get_tables"></a>

### `get_tables`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_tables() -> Array[GFConfigPipelineTableIR]:
```

获取按注册顺序排列的不可变单表 IR。

返回：单表 IR 列表；数组容器是副本，元素是不可变 IR。

结构：

- `return`: Array[GFConfigPipelineTableIR]，按注册顺序排列。

<a id="member-gfconfigpipelineir-methods-duplicate_ir"></a>

### `duplicate_ir`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_ir() -> GFConfigPipelineIR:
```

创建内容等价且不共享可变载荷的数据库 IR。

返回：数据库 IR 副本；原 IR 已封存时，副本也会封存。

<a id="member-gfconfigpipelineir-methods-describe"></a>

### `describe`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func describe() -> Dictionary:
```

导出不包含完整记录载荷的稳定摘要。

返回：IR 摘要。

结构：

- `return`: Dictionary，包含 format、format_version、database_id、version、sealed、metadata、table_count 和 tables。
