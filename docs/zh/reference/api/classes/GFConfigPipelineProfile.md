# GFConfigPipelineProfile

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_pipeline_profile.gd`
- 模块：`Tools`
- 继承：`Resource`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`5.2.0`

配置导表工具的批量构建声明。 描述一组表来源、数据库标识、输出路径和构建选项，供编辑器工具、CI 或项目脚本复用。 该资源属于可选 tool package，只表达制作期或 CI 期通用导表任务，不规定项目目录结构、业务字段语义或发布流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`profile_id`](#member-gfconfigpipelineprofile-properties-profile_id) | `var profile_id: StringName = &""` |
| 属性 | [`database_id`](#member-gfconfigpipelineprofile-properties-database_id) | `var database_id: StringName = &""` |
| 属性 | [`version`](#member-gfconfigpipelineprofile-properties-version) | `var version: String = ""` |
| 属性 | [`output_path`](#member-gfconfigpipelineprofile-properties-output_path) | `var output_path: String = ""` |
| 属性 | [`access_output_path`](#member-gfconfigpipelineprofile-properties-access_output_path) | `var access_output_path: String = ""` |
| 属性 | [`access_class_name`](#member-gfconfigpipelineprofile-properties-access_class_name) | `var access_class_name: String = "GFConfigAccess"` |
| 属性 | [`access_provider_accessor`](#member-gfconfigpipelineprofile-properties-access_provider_accessor) | `var access_provider_accessor: String = "null"` |
| 属性 | [`sources`](#member-gfconfigpipelineprofile-properties-sources) | `var sources: Array[GFConfigPipelineTableSource] = []` |
| 属性 | [`build_options`](#member-gfconfigpipelineprofile-properties-build_options) | `var build_options: Dictionary = {}` |
| 属性 | [`save_options`](#member-gfconfigpipelineprofile-properties-save_options) | `var save_options: Dictionary = {}` |
| 属性 | [`access_options`](#member-gfconfigpipelineprofile-properties-access_options) | `var access_options: Dictionary = {}` |
| 属性 | [`metadata`](#member-gfconfigpipelineprofile-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`consumer_targets`](#member-gfconfigpipelineprofile-properties-consumer_targets) | `var consumer_targets: Array[GFConfigPipelineConsumerTarget] = []` |
| 属性 | [`default_consumer_target`](#member-gfconfigpipelineprofile-properties-default_consumer_target) | `var default_consumer_target: StringName = &""` |
| 属性 | [`stable_id_registry_path`](#member-gfconfigpipelineprofile-properties-stable_id_registry_path) | `var stable_id_registry_path: String = ""` |
| 属性 | [`stable_id_bindings`](#member-gfconfigpipelineprofile-properties-stable_id_bindings) | `var stable_id_bindings: Dictionary = {}` |
| 属性 | [`stable_id_scope_tables`](#member-gfconfigpipelineprofile-properties-stable_id_scope_tables) | `var stable_id_scope_tables: Array[String] = []` |
| 属性 | [`stable_id_restorations`](#member-gfconfigpipelineprofile-properties-stable_id_restorations) | `var stable_id_restorations: Dictionary = {}` |
| 方法 | [`resolve_consumer`](#member-gfconfigpipelineprofile-methods-resolve_consumer) | `func resolve_consumer(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_build_options`](#member-gfconfigpipelineprofile-methods-make_build_options) | `func make_build_options(overrides: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_save_options`](#member-gfconfigpipelineprofile-methods-make_save_options) | `func make_save_options(overrides: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_access_options`](#member-gfconfigpipelineprofile-methods-make_access_options) | `func make_access_options(overrides: Dictionary = {}) -> Dictionary:` |
| 方法 | [`resolve_output_path`](#member-gfconfigpipelineprofile-methods-resolve_output_path) | `func resolve_output_path(overrides: Dictionary = {}) -> String:` |
| 方法 | [`resolve_access_output_path`](#member-gfconfigpipelineprofile-methods-resolve_access_output_path) | `func resolve_access_output_path(overrides: Dictionary = {}) -> String:` |
| 方法 | [`resolve_access_class_name`](#member-gfconfigpipelineprofile-methods-resolve_access_class_name) | `func resolve_access_class_name(overrides: Dictionary = {}) -> String:` |
| 方法 | [`resolve_access_provider_accessor`](#member-gfconfigpipelineprofile-methods-resolve_access_provider_accessor) | `func resolve_access_provider_accessor(overrides: Dictionary = {}) -> String:` |
| 方法 | [`duplicate_profile`](#member-gfconfigpipelineprofile-methods-duplicate_profile) | `func duplicate_profile() -> GFConfigPipelineProfile:` |
| 方法 | [`describe`](#member-gfconfigpipelineprofile-methods-describe) | `func describe() -> Dictionary:` |

## 属性

<a id="member-gfconfigpipelineprofile-properties-profile_id"></a>

### `profile_id`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
@export
var profile_id: StringName = &""
```

Profile 稳定标识。

<a id="member-gfconfigpipelineprofile-properties-database_id"></a>

### `database_id`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
@export
var database_id: StringName = &""
```

生成数据库资源的标识。

<a id="member-gfconfigpipelineprofile-properties-version"></a>

### `version`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
@export
var version: String = ""
```

写入数据库资源的版本字符串。

<a id="member-gfconfigpipelineprofile-properties-output_path"></a>

### `output_path`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
@export
var output_path: String = ""
```

导出目标 URI。导出时必须位于 res:// 或 user://，通常以 .tres、.res 或 .json 结尾。

<a id="member-gfconfigpipelineprofile-properties-access_output_path"></a>

### `access_output_path`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
@export
var access_output_path: String = ""
```

可选访问器脚本输出 URI。非空时必须位于 res:// 或 user://；为空时不生成访问器。

<a id="member-gfconfigpipelineprofile-properties-access_class_name"></a>

### `access_class_name`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
@export
var access_class_name: String = "GFConfigAccess"
```

可选访问器脚本 class_name。

<a id="member-gfconfigpipelineprofile-properties-access_provider_accessor"></a>

### `access_provider_accessor`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
@export
var access_provider_accessor: String = "null"
```

可选访问器脚本默认 provider 获取表达式。

<a id="member-gfconfigpipelineprofile-properties-sources"></a>

### `sources`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
@export
var sources: Array[GFConfigPipelineTableSource] = []
```

单表来源列表。

结构：

- `sources`: Array[GFConfigPipelineTableSource]。

<a id="member-gfconfigpipelineprofile-properties-build_options"></a>

### `build_options`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
@export
var build_options: Dictionary = {}
```

传给 GFConfigPipeline.build_database() 的构建选项。

结构：

- `build_options`: Dictionary，可包含 database_id、version、metadata、validate_database、validate_schema、parse_options、rebuild_indexes 和 work_limits。work_limits 是 GFConfigWorkBudget 的有限限额；Profile 不持有 work_budget，每次构建创建新会话。

<a id="member-gfconfigpipelineprofile-properties-save_options"></a>

### `save_options`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
@export
var save_options: Dictionary = {}
```

传给 GFConfigPipeline.save_database() 的保存选项。

结构：

- `save_options`: Dictionary，可包含 output_format、include_schema、include_indexes、indent、sort_keys、overwrite_existing、allow_parent_output_path、allow_gf_source_output、allow_unowned_overwrite 和 dry_run；parent opt-in 不能越过 resource URI 根。

<a id="member-gfconfigpipelineprofile-properties-access_options"></a>

### `access_options`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
@export
var access_options: Dictionary = {}
```

传给 GFConfigAccessGenerator 的访问器生成选项。

结构：

- `access_options`: Dictionary，可包含 method_name_style、constant_prefix、record_method_pattern、table_method_pattern、include_schema_comments、include_typed_records、typed_record_method_pattern、typed_record_class_suffix、overwrite_existing、allow_parent_output_path、allow_gf_source_output、allow_unowned_overwrite 和 dry_run；parent opt-in 不能越过 resource URI 根。

<a id="member-gfconfigpipelineprofile-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
@export
var metadata: Dictionary = {}
```

附加到生成数据库资源的元数据。

结构：

- `metadata`: Dictionary，保存项目工具、编辑器或 CI 附加的构建信息。

<a id="member-gfconfigpipelineprofile-properties-consumer_targets"></a>

### `consumer_targets`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var consumer_targets: Array[GFConfigPipelineConsumerTarget] = []
```

可选消费目标；声明后每次构建必须选中一个目标。

结构：

- `consumer_targets`: Array[GFConfigPipelineConsumerTarget]，最多64项，ID唯一；每个目标需要独立的非空输出路径。

<a id="member-gfconfigpipelineprofile-properties-default_consumer_target"></a>

### `default_consumer_target`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var default_consumer_target: StringName = &""
```

没有显式 target 选项时使用的消费目标；不自动选中第一项。

<a id="member-gfconfigpipelineprofile-properties-stable_id_registry_path"></a>

### `stable_id_registry_path`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var stable_id_registry_path: String = ""
```

可选项目所有的稳定 ID 登记簿 JSON URI；空值时不启用登记。

<a id="member-gfconfigpipelineprofile-properties-stable_id_bindings"></a>

### `stable_id_bindings`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var stable_id_bindings: Dictionary = {}
```

明确选择需要数字 ID 稳定性检查的作者表；其他表的 ID 类型不受影响。

结构：

- `stable_id_bindings`: Dictionary[String,Dictionary]，每表仅包含 symbol_field:String、id_field:String；来源记录必须提供非空精确符号及1至2147483647的int ID。最多4096表、总计65536条记录；完整作者表参与登记，不受消费目标裁剪影响。

<a id="member-gfconfigpipelineprofile-properties-stable_id_scope_tables"></a>

### `stable_id_scope_tables`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var stable_id_scope_tables: Array[String] = []
```

显式限制本次稳定 ID 对账的表范围；空数组保留整簿对账，未绑定的历史表会退役。

结构：

- `stable_id_scope_tables`: Array[String]，最多4096个唯一精确表名；非空时必须与stable_id_bindings的表集合相同，范围外历史表保持不变。范围内需要整表退役时，绑定一张有schema但没有记录的作者表。

<a id="member-gfconfigpipelineprofile-properties-stable_id_restorations"></a>

### `stable_id_restorations`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var stable_id_restorations: Dictionary = {}
```

明确允许原身份从退役状态恢复；不分配 ID、不改号，也不允许把历史 ID 交给其他符号。

结构：

- `stable_id_restorations`: Dictionary[String,Dictionary[String,String]]，table到symbol到原ID的规范十进制文本，例如{"items":{"potion":"1"}}。作者表ID仍必须为int；表和符号必须同时存在于本次对账映射及历史登记中。已活动的同一声明幂等；声明随Profile进入预览摘要并通过register-ids事务提交。

## 方法

<a id="member-gfconfigpipelineprofile-methods-resolve_consumer"></a>

### `resolve_consumer`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func resolve_consumer(options: Dictionary = {}) -> Dictionary:
```

解析消费目标并冻结声明；无目标声明的 Profile 沿用完整数据库构建。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 本次选项；target 选择目标，显式输出路径覆盖目标默认路径。 |

返回：解析结果；失败时不提供可执行选项。

结构：

- `options`: Dictionary，可含 target:String/StringName、output_path:String 和 access_output_path:String；其他选项原样转交既有构建链。
- `return`: 封闭 Dictionary，success:bool、target:GFConfigPipelineConsumerTarget/null、options:Dictionary、error:String；成功目标是声明的独立副本。

<a id="member-gfconfigpipelineprofile-methods-make_build_options"></a>

### `make_build_options`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func make_build_options(overrides: Dictionary = {}) -> Dictionary:
```

合成构建选项。

参数：

| 名称 | 说明 |
|---|---|
| `overrides` | 本次构建的覆盖选项；build_options 子字典和直接字段都会覆盖 Profile 默认值。 |

返回：传给 GFConfigPipeline.build_database() 的选项。

结构：

- `overrides`: Dictionary，可包含 build_options、database_id、version、metadata、validate_database、validate_schema、parse_options、rebuild_indexes、max_validation_cells、max_source_file_bytes、max_xlsx_file_bytes 和 work_limits；直接字段覆盖 Profile 同名选项。work_limits 由 Pipeline 在复制前解析为本次新会话，parse_options 不得设置预算。
- `return`: Dictionary，包含合成后的构建选项。

<a id="member-gfconfigpipelineprofile-methods-make_save_options"></a>

### `make_save_options`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func make_save_options(overrides: Dictionary = {}) -> Dictionary:
```

合成保存选项。

参数：

| 名称 | 说明 |
|---|---|
| `overrides` | 本次导出的覆盖选项。 |

返回：传给 GFConfigPipeline.save_database() 的选项。

结构：

- `overrides`: Dictionary，可包含 save_options；save_options 可包含 output_format、include_schema、include_indexes、indent、sort_keys、overwrite_existing、allow_parent_output_path、allow_gf_source_output、allow_unowned_overwrite 和 dry_run。
- `return`: Dictionary，包含合成后的保存选项。

<a id="member-gfconfigpipelineprofile-methods-make_access_options"></a>

### `make_access_options`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func make_access_options(overrides: Dictionary = {}) -> Dictionary:
```

合成访问器生成选项。

参数：

| 名称 | 说明 |
|---|---|
| `overrides` | 本次访问器生成的覆盖选项。 |

返回：传给 GFConfigAccessGenerator 的生成选项。

结构：

- `overrides`: Dictionary，可包含 access_options；access_options 可包含生成器选项、overwrite_existing、allow_parent_output_path、allow_gf_source_output、allow_unowned_overwrite 和 dry_run。
- `return`: Dictionary，包含合成后的访问器生成选项。

<a id="member-gfconfigpipelineprofile-methods-resolve_output_path"></a>

### `resolve_output_path`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func resolve_output_path(overrides: Dictionary = {}) -> String:
```

获取本次导出的输出路径。

参数：

| 名称 | 说明 |
|---|---|
| `overrides` | 本次导出的覆盖选项。 |

返回：覆盖后的输出路径；未覆盖时返回 output_path。

结构：

- `overrides`: Dictionary，可包含 output_path。

<a id="member-gfconfigpipelineprofile-methods-resolve_access_output_path"></a>

### `resolve_access_output_path`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func resolve_access_output_path(overrides: Dictionary = {}) -> String:
```

获取本次访问器生成的输出路径。

参数：

| 名称 | 说明 |
|---|---|
| `overrides` | 本次访问器生成的覆盖选项。 |

返回：覆盖后的访问器输出路径；未配置时返回空字符串。

结构：

- `overrides`: Dictionary，可包含 access_output_path。

<a id="member-gfconfigpipelineprofile-methods-resolve_access_class_name"></a>

### `resolve_access_class_name`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func resolve_access_class_name(overrides: Dictionary = {}) -> String:
```

获取本次访问器生成的 class_name。

参数：

| 名称 | 说明 |
|---|---|
| `overrides` | 本次访问器生成的覆盖选项。 |

返回：覆盖后的访问器 class_name。

结构：

- `overrides`: Dictionary，可包含 access_class_name。

<a id="member-gfconfigpipelineprofile-methods-resolve_access_provider_accessor"></a>

### `resolve_access_provider_accessor`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func resolve_access_provider_accessor(overrides: Dictionary = {}) -> String:
```

获取本次访问器生成的默认 provider 获取表达式。

参数：

| 名称 | 说明 |
|---|---|
| `overrides` | 本次访问器生成的覆盖选项。 |

返回：覆盖后的 provider 获取表达式。

结构：

- `overrides`: Dictionary，可包含 access_provider_accessor。

<a id="member-gfconfigpipelineprofile-methods-duplicate_profile"></a>

### `duplicate_profile`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func duplicate_profile() -> GFConfigPipelineProfile:
```

创建同内容拷贝；逐来源确认显式 Schema 可复制后，才采用完整 Profile 副本。 来源委托 duplicate_source()，嵌套声明遵循各自领域复制方法的扩展契约。

返回：新 Profile 资源；任一非空来源或 Profile 无法复制时返回 null，不交付部分来源列表。

<a id="member-gfconfigpipelineprofile-methods-describe"></a>

### `describe`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func describe() -> Dictionary:
```

导出 Profile 摘要。

返回：Profile 摘要字典。

结构：

- `return`: Dictionary，包含 profile_id、database_id、version、output_path、access_output_path、access_class_name、access_provider_accessor、source_count、sources、build_options、save_options、access_options 和 metadata。另含consumer_targets:Array[Dictionary]（各目标capture结果）、default_consumer_target:String、stable_id_registry_path:String、stable_id_bindings:Dictionary、stable_id_scope_tables:Array[String]和stable_id_restorations:Dictionary[String,Dictionary[String,String]]；对账范围和恢复声明均保留到输入摘要。
