# GFConfigPipelineTargetStage

[API Reference](../index.md) / [Tool Packages](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_pipeline_target_stage.gd`
- 模块：`Tool Packages`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`unreleased`

Config Pipeline 的内置目标物化阶段。 只接受版本化 IR，并将其物化为 GFConfigTableResource、GFConfigDatabaseResource 或 JSON 兼容数据。 Target 不读取来源，也不重新推导 schema 或解释项目业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STAGE_ID`](#member-gfconfigpipelinetargetstage-constants-stage_id) | `const STAGE_ID: String = "gf.config.target.godot_resource"` |
| 常量 | [`IMPLEMENTATION_VERSION`](#member-gfconfigpipelinetargetstage-constants-implementation_version) | `const IMPLEMENTATION_VERSION: int = 1` |
| 方法 | [`materialize_table`](#member-gfconfigpipelinetargetstage-methods-materialize_table) | `func materialize_table( table_ir: GFConfigPipelineTableIR, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`materialize_database`](#member-gfconfigpipelinetargetstage-methods-materialize_database) | `func materialize_database( compilation_ir: GFConfigPipelineIR, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`make_database_export`](#member-gfconfigpipelinetargetstage-methods-make_database_export) | `func make_database_export( database: GFConfigDatabaseResource, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`make_database_json`](#member-gfconfigpipelinetargetstage-methods-make_database_json) | `func make_database_json( database: GFConfigDatabaseResource, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`get_stage_descriptor`](#member-gfconfigpipelinetargetstage-methods-get_stage_descriptor) | `func get_stage_descriptor() -> Dictionary:` |

## 常量

<a id="member-gfconfigpipelinetargetstage-constants-stage_id"></a>

### `STAGE_ID`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STAGE_ID: String = "gf.config.target.godot_resource"
```

Target 阶段的稳定实现标识。

<a id="member-gfconfigpipelinetargetstage-constants-implementation_version"></a>

### `IMPLEMENTATION_VERSION`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const IMPLEMENTATION_VERSION: int = 1
```

Target 阶段的实现版本；改变 Resource 或 JSON 物化语义时递增。

## 方法

<a id="member-gfconfigpipelinetargetstage-methods-materialize_table"></a>

### `materialize_table`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func materialize_table( table_ir: GFConfigPipelineTableIR, options: Dictionary = {} ) -> Dictionary:
```

将单表 IR 物化为 Godot Resource。

参数：

| 名称 | 说明 |
|---|---|
| `table_ir` | 已通过 Validation 的版本化单表 IR。 |
| `options` | 目标选项。 |

返回：单表物化结果。

结构：

- `options`: Dictionary，可包含 rebuild_indexes。
- `return`: Dictionary，包含 success、phase、table、ir、error_kind 和 error。

<a id="member-gfconfigpipelinetargetstage-methods-materialize_database"></a>

### `materialize_database`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func materialize_database( compilation_ir: GFConfigPipelineIR, options: Dictionary = {} ) -> Dictionary:
```

将数据库 IR 物化为 Godot Resource，并可执行数据库级引用校验。

参数：

| 名称 | 说明 |
|---|---|
| `compilation_ir` | 已完成单表校验的版本化数据库 IR。 |
| `options` | 目标选项。 |

返回：数据库物化结果。

结构：

- `options`: Dictionary，可包含 rebuild_indexes、validate_database 和 validate_schema。
- `return`: Dictionary，包含 success、phase、database、report、ir、error_kind 和 error。

<a id="member-gfconfigpipelinetargetstage-methods-make_database_export"></a>

### `make_database_export`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func make_database_export( database: GFConfigDatabaseResource, options: Dictionary = {} ) -> Dictionary:
```

把数据库 Resource 转换为稳定、JSON 兼容的导出数据。

参数：

| 名称 | 说明 |
|---|---|
| `database` | 待导出的数据库资源。 |
| `options` | JSON 目标选项。 |

返回：JSON 兼容导出结果。

结构：

- `options`: Dictionary，可包含 include_schema、include_indexes 和 max_depth。
- `return`: Dictionary，包含 success、data 和 error。

<a id="member-gfconfigpipelinetargetstage-methods-make_database_json"></a>

### `make_database_json`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func make_database_json( database: GFConfigDatabaseResource, options: Dictionary = {} ) -> Dictionary:
```

把数据库 Resource 序列化为稳定 JSON 文本。

参数：

| 名称 | 说明 |
|---|---|
| `database` | 待导出的数据库资源。 |
| `options` | JSON 目标选项。 |

返回：JSON 目标结果。

结构：

- `options`: Dictionary，可包含 include_schema、include_indexes、max_depth、indent 和 sort_keys。
- `return`: Dictionary，包含 success、data、text 和 error。

<a id="member-gfconfigpipelinetargetstage-methods-get_stage_descriptor"></a>

### `get_stage_descriptor`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_stage_descriptor() -> Dictionary:
```

返回阶段实现的稳定描述，用于流水线诊断和编译指纹。

返回：阶段描述。

结构：

- `return`: Dictionary，包含 stage_id、implementation_version、input_contracts 和 output_contracts。
