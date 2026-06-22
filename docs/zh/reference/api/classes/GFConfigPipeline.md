# GFConfigPipeline

[API Reference](../index.md) / [Tool Packages](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_pipeline.gd`
- 模块：`Tool Packages`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`5.2.0`

配置导表工具的资源构建入口。 负责把 CSV / JSON / XLSX 文件来源构建为 GFConfigTableResource 与 GFConfigDatabaseResource。 该工具只处理通用导入、校验、索引重建和 Resource 保存，不绑定任何项目业务表或发布流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`build_table`](#member-gfconfigpipeline-methods-build_table) | `func build_table(source: GFConfigPipelineTableSource, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`build_table_from_text`](#member-gfconfigpipeline-methods-build_table_from_text) | `func build_table_from_text( source: GFConfigPipelineTableSource, text: String, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`build_database`](#member-gfconfigpipeline-methods-build_database) | `func build_database( sources: Array, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`build_profile`](#member-gfconfigpipeline-methods-build_profile) | `func build_profile(profile: GFConfigPipelineProfile, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`export_profile`](#member-gfconfigpipeline-methods-export_profile) | `func export_profile(profile: GFConfigPipelineProfile, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_database_export`](#member-gfconfigpipeline-methods-make_database_export) | `func make_database_export(database: GFConfigDatabaseResource, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`save_database`](#member-gfconfigpipeline-methods-save_database) | `func save_database( database: GFConfigDatabaseResource, output_path: String, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`generate_access`](#member-gfconfigpipeline-methods-generate_access) | `func generate_access( database: GFConfigDatabaseResource, output_path: String, access_class_name: String = "GFConfigAccess", provider_accessor: String = "null", options: Dictionary = {} ) -> Dictionary:` |

## 方法

<a id="member-gfconfigpipeline-methods-build_table"></a>

### `build_table`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func build_table(source: GFConfigPipelineTableSource, options: Dictionary = {}) -> Dictionary:
```

从来源文件构建单表资源。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 单表来源声明。 |
| `options` | 可选构建选项，支持 parse_options、rebuild_indexes。 |

返回：构建结果。

结构：

- `options`: Dictionary，可包含 parse_options 和 rebuild_indexes。
- `return`: Dictionary，包含 success、table、report、source_path、format 和 error。

<a id="member-gfconfigpipeline-methods-build_table_from_text"></a>

### `build_table_from_text`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func build_table_from_text( source: GFConfigPipelineTableSource, text: String, options: Dictionary = {} ) -> Dictionary:
```

从文本构建单表资源。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 单表来源声明。 |
| `text` | CSV 或 JSON 文本。 |
| `options` | 可选构建选项，支持 parse_options、rebuild_indexes。 |

返回：构建结果。

结构：

- `options`: Dictionary，可包含 parse_options 和 rebuild_indexes。
- `return`: Dictionary，包含 success、table、report、source_path、format 和 error。

<a id="member-gfconfigpipeline-methods-build_database"></a>

### `build_database`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func build_database( sources: Array, options: Dictionary = {} ) -> Dictionary:
```

从一组来源文件构建配置数据库资源。

参数：

| 名称 | 说明 |
|---|---|
| `sources` | 单表来源声明列表。 |
| `options` | 可选构建选项，支持 database_id、version、metadata、validate_database、validate_schema、parse_options、rebuild_indexes。 |

返回：构建结果。

结构：

- `sources`: Array[GFConfigPipelineTableSource]。
- `options`: Dictionary，可包含 database_id、version、metadata、validate_database、validate_schema、parse_options 和 rebuild_indexes。
- `return`: Dictionary，包含 success、database、report、table_results 和 error。

<a id="member-gfconfigpipeline-methods-build_profile"></a>

### `build_profile`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func build_profile(profile: GFConfigPipelineProfile, options: Dictionary = {}) -> Dictionary:
```

从导表 Profile 构建配置数据库资源。

参数：

| 名称 | 说明 |
|---|---|
| `profile` | 导表 Profile 资源。 |
| `options` | 本次构建覆盖选项，支持 build_options 以及 build_database() 的直接选项。 |

返回：构建结果。

结构：

- `profile`: GFConfigPipelineProfile resource。
- `options`: Dictionary，可包含 build_options、database_id、version、metadata、validate_database、validate_schema、parse_options 和 rebuild_indexes。
- `return`: Dictionary，包含 success、database、report、table_results、profile_id、output_path 和 error。

<a id="member-gfconfigpipeline-methods-export_profile"></a>

### `export_profile`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func export_profile(profile: GFConfigPipelineProfile, options: Dictionary = {}) -> Dictionary:
```

从导表 Profile 构建并保存配置数据库资源。

参数：

| 名称 | 说明 |
|---|---|
| `profile` | 导表 Profile 资源。 |
| `options` | 本次导出覆盖选项，支持 output_path、build_options、save_options、access_output_path、access_options、access_class_name、access_provider_accessor 以及 build_database() 的直接选项。 |

返回：导出结果。

结构：

- `profile`: GFConfigPipelineProfile resource。
- `options`: Dictionary，可包含 output_path、build_options、save_options、access_output_path、access_options、access_class_name、access_provider_accessor、database_id、version、metadata、validate_database、validate_schema、parse_options 和 rebuild_indexes。
- `return`: Dictionary，包含 success、database、report、table_results、build_result、save_result、access_result、profile_id、output_path 和 error。

<a id="member-gfconfigpipeline-methods-make_database_export"></a>

### `make_database_export`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func make_database_export(database: GFConfigDatabaseResource, options: Dictionary = {}) -> Dictionary:
```

创建可保存为 JSON 的配置数据库导出字典。

参数：

| 名称 | 说明 |
|---|---|
| `database` | 要导出的配置数据库资源。 |
| `options` | 可选导出选项，支持 include_schema、include_indexes 和 max_depth。 |

返回：JSON 兼容导出字典；数据库为空或存在不支持的 Variant 时返回空字典。

结构：

- `options`: Dictionary，可包含 include_schema、include_indexes 和 max_depth。
- `return`: Dictionary，包含 format、format_version、database_id、version、metadata 和 tables。

<a id="member-gfconfigpipeline-methods-save_database"></a>

### `save_database`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func save_database( database: GFConfigDatabaseResource, output_path: String, options: Dictionary = {} ) -> Dictionary:
```

保存配置数据库资源。

参数：

| 名称 | 说明 |
|---|---|
| `database` | 要保存的配置数据库资源。 |
| `output_path` | 输出路径，通常为 .tres、.res 或 .json。 |
| `options` | 保存选项，支持 output_format、include_schema、include_indexes、indent 和 sort_keys。 |

返回：保存结果。

结构：

- `options`: Dictionary，可包含 output_format、include_schema、include_indexes、indent 和 sort_keys。
- `return`: Dictionary，包含 success、path、format、error_code 和 error。

<a id="member-gfconfigpipeline-methods-generate_access"></a>

### `generate_access`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func generate_access( database: GFConfigDatabaseResource, output_path: String, access_class_name: String = "GFConfigAccess", provider_accessor: String = "null", options: Dictionary = {} ) -> Dictionary:
```

根据配置数据库生成静态访问器脚本。

参数：

| 名称 | 说明 |
|---|---|
| `database` | 要生成访问器的配置数据库资源。 |
| `output_path` | 访问器脚本输出路径。 |
| `access_class_name` | 生成脚本的 class_name。 |
| `provider_accessor` | 无显式 provider 参数时用于获取 provider 的表达式。 |
| `options` | 访问器生成选项，支持 GFConfigAccessGenerator 选项和 overwrite_existing。 |

返回：访问器生成结果。

结构：

- `options`: Dictionary，可包含 method_name_style、constant_prefix、record_method_pattern、table_method_pattern、include_schema_comments、include_typed_records、typed_record_method_pattern、typed_record_class_suffix 和 overwrite_existing。
- `return`: Dictionary，包含 success、skipped、path、class_name、schema_count、error_code 和 error。
