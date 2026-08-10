# GFConfigPipeline

[API Reference](../index.md) / [Tool Packages](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_pipeline.gd`
- 模块：`Tool Packages`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`5.2.0`

配置导表工具的资源构建入口。 负责把 CSV / JSON / ConfigFile / XLSX 文件来源构建为 GFConfigTableResource 与 GFConfigDatabaseResource。 该工具只处理通用导入、校验、索引重建和 Resource 保存，不绑定任何项目业务表或发布流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`configure_stages`](#member-gfconfigpipeline-methods-configure_stages) | `func configure_stages( reader_stage: GFConfigPipelineReaderStage = null, layout_stage: GFConfigPipelineLayoutStage = null, validation_stage: GFConfigPipelineValidationStage = null, target_stage: GFConfigPipelineTargetStage = null, commit_stage: GFConfigPipelineCommitStage = null ) -> GFConfigPipeline:` |
| 方法 | [`get_stage_descriptors`](#member-gfconfigpipeline-methods-get_stage_descriptors) | `func get_stage_descriptors() -> Array[Dictionary]:` |
| 方法 | [`build_table`](#member-gfconfigpipeline-methods-build_table) | `func build_table(source: GFConfigPipelineTableSource, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`build_table_from_text`](#member-gfconfigpipeline-methods-build_table_from_text) | `func build_table_from_text( source: GFConfigPipelineTableSource, text: String, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`build_database`](#member-gfconfigpipeline-methods-build_database) | `func build_database( sources: Array, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`build_profile`](#member-gfconfigpipeline-methods-build_profile) | `func build_profile(profile: GFConfigPipelineProfile, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`export_profile`](#member-gfconfigpipeline-methods-export_profile) | `func export_profile(profile: GFConfigPipelineProfile, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_database_export`](#member-gfconfigpipeline-methods-make_database_export) | `func make_database_export(database: GFConfigDatabaseResource, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`save_database`](#member-gfconfigpipeline-methods-save_database) | `func save_database( database: GFConfigDatabaseResource, output_path: String, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`generate_access`](#member-gfconfigpipeline-methods-generate_access) | `func generate_access( database: GFConfigDatabaseResource, output_path: String, access_class_name: String = "GFConfigAccess", provider_accessor: String = "null", options: Dictionary = {} ) -> Dictionary:` |

## 方法

<a id="member-gfconfigpipeline-methods-configure_stages"></a>

### `configure_stages`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func configure_stages( reader_stage: GFConfigPipelineReaderStage = null, layout_stage: GFConfigPipelineLayoutStage = null, validation_stage: GFConfigPipelineValidationStage = null, target_stage: GFConfigPipelineTargetStage = null, commit_stage: GFConfigPipelineCommitStage = null ) -> GFConfigPipeline:
```

替换 Pipeline 使用的阶段实现。传入 null 的阶段保持当前实现不变。 自定义实现应继承对应内置阶段并保持其输入、输出契约；Pipeline 只负责编排，不探测项目业务类型。

参数：

| 名称 | 说明 |
|---|---|
| `reader_stage` | 可选来源读取阶段。 |
| `layout_stage` | 可选布局解析阶段。 |
| `validation_stage` | 可选语义校验阶段。 |
| `target_stage` | 可选目标物化阶段。 |
| `commit_stage` | 可选文件提交事务阶段。 |

返回：当前 Pipeline，便于链式配置。

<a id="member-gfconfigpipeline-methods-get_stage_descriptors"></a>

### `get_stage_descriptors`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_stage_descriptors() -> Array[Dictionary]:
```

获取当前阶段组合的稳定描述。

返回：按 Reader、Layout、Validation、Target、Commit 排列的阶段描述。

结构：

- `return`: Array[Dictionary]，每项包含 stage_id、implementation_version、implementation_path、implementation_dependencies 和阶段契约字段。

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
- `return`: Dictionary，包含 success、table、ir、report、source_path、format、source_receipt 和 error。

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
| `text` | CSV、JSON 或 ConfigFile 文本。 |
| `options` | 可选构建选项，支持 parse_options、rebuild_indexes。 |

返回：构建结果。

结构：

- `options`: Dictionary，可包含 parse_options 和 rebuild_indexes。
- `return`: Dictionary，包含 success、table、ir、report、source_path、format 和 error。

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
- `return`: Dictionary，包含 success、database、ir、report、table_results 和 error；每个成功 table_result 都包含绑定实际读取字节的 source_receipt。

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
- `return`: Dictionary，包含 success、database、report、table_results、profile_id、output_path 和 error；每个成功 table_result 都包含绑定实际读取字节的 source_receipt。

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
| `options` | 本次导出覆盖选项，支持 output_path、build_options、save_options、access_output_path、access_options、access_class_name、access_provider_accessor、changed_only、manifest_path、write_manifest、manifest_options、manifest_metadata、scan_filesystem 以及 build_database() 的直接选项。 |

返回：导出结果。

结构：

- `profile`: GFConfigPipelineProfile resource。
- `options`: Dictionary，可包含 output_path、build_options、save_options、access_output_path、access_options、access_class_name、access_provider_accessor、database_id、version、metadata、validate_database、validate_schema、parse_options、rebuild_indexes、changed_only、manifest_path、write_manifest、manifest_options、manifest_metadata、scan_filesystem、max_freshness_file_bytes、max_freshness_total_bytes 和 max_freshness_entries；save_options、access_options 与 manifest_options 可分别包含 allow_unowned_overwrite。批量导出会强制所有 constituent 禁止 scan，并且仅在整批事务成功后按顶层 scan_filesystem 执行一次编辑器扫描。
- `return`: Dictionary，包含 success、database、report、table_results、build_result、save_result、access_result、manifest_path、manifest、manifest_result、source_validation_report、profile_id、output_path、error、transaction_result、recovery_required、recovery_action 和 recovery_transaction；写 manifest 时会在事务完成前复核 source_receipt，来源变化会回滚整批产物；recovery_required 为 true 时调用方必须按 recovery_action 使用 recovery_transaction 完成结果要求的终态动作。

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
| `options` | 可选导出选项，支持 include_schema、include_indexes、max_depth、max_nodes 和 max_output_bytes。 |

返回：JSON 兼容导出字典；数据库为空或存在不支持的 Variant 时返回空字典。

结构：

- `options`: Dictionary，可包含 include_schema、include_indexes、max_depth、max_nodes 和 max_output_bytes；调用方值会被框架绝对上限约束。
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
| `options` | 保存选项，支持 output_format、include_schema、include_indexes、indent、sort_keys、overwrite_existing、allow_unowned_overwrite、dry_run 和 artifact_metadata。 |

返回：保存结果。

结构：

- `options`: Dictionary，可包含 output_format、include_schema、include_indexes、max_depth、max_nodes、max_output_bytes、indent、sort_keys、overwrite_existing、allow_unowned_overwrite、dry_run 和 artifact_metadata；三个 JSON 预算会被框架绝对上限约束，allow_unowned_overwrite 仅用于调用方已明确确认现有文件所有权的迁移场景。
- `return`: Dictionary，包含 success、path、format、error_code、error、artifact_report、status、written、changed 和 dry_run。

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
| `options` | 访问器生成选项，支持 GFConfigAccessGenerator 选项、overwrite_existing、allow_unowned_overwrite、dry_run、scan_filesystem 和 metadata。 |

返回：访问器生成结果。

结构：

- `options`: Dictionary，可包含 method_name_style、constant_prefix、record_method_pattern、table_method_pattern、include_schema_comments、include_typed_records、typed_record_method_pattern、typed_record_class_suffix、overwrite_existing、allow_unowned_overwrite、dry_run、scan_filesystem 和 metadata；allow_unowned_overwrite 仅用于调用方已明确确认现有文件所有权的迁移场景。
- `return`: Dictionary，包含 success、skipped、path、class_name、schema_count、input_schema_count、emitted_schema_count、skipped_schema_count、issues、error_code、error 和 artifact_report；schema_count 是 emitted_schema_count 的兼容字段。
