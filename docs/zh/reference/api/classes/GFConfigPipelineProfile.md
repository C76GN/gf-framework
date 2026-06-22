# GFConfigPipelineProfile

[API Reference](../index.md) / [Tool Packages](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_pipeline_profile.gd`
- 模块：`Tool Packages`
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
var profile_id: StringName = &""
```

Profile 稳定标识。

<a id="member-gfconfigpipelineprofile-properties-database_id"></a>

### `database_id`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var database_id: StringName = &""
```

生成数据库资源的标识。

<a id="member-gfconfigpipelineprofile-properties-version"></a>

### `version`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var version: String = ""
```

写入数据库资源的版本字符串。

<a id="member-gfconfigpipelineprofile-properties-output_path"></a>

### `output_path`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var output_path: String = ""
```

导出目标路径。通常指向 .tres、.res 或 .json。

<a id="member-gfconfigpipelineprofile-properties-access_output_path"></a>

### `access_output_path`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var access_output_path: String = ""
```

可选访问器脚本输出路径。为空时不生成访问器。

<a id="member-gfconfigpipelineprofile-properties-access_class_name"></a>

### `access_class_name`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var access_class_name: String = "GFConfigAccess"
```

可选访问器脚本 class_name。

<a id="member-gfconfigpipelineprofile-properties-access_provider_accessor"></a>

### `access_provider_accessor`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var access_provider_accessor: String = "null"
```

可选访问器脚本默认 provider 获取表达式。

<a id="member-gfconfigpipelineprofile-properties-sources"></a>

### `sources`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
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
var build_options: Dictionary = {}
```

传给 GFConfigPipeline.build_database() 的构建选项。

结构：

- `build_options`: Dictionary，可包含 database_id、version、metadata、validate_database、validate_schema、parse_options 和 rebuild_indexes。

<a id="member-gfconfigpipelineprofile-properties-save_options"></a>

### `save_options`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var save_options: Dictionary = {}
```

传给 GFConfigPipeline.save_database() 的保存选项。

结构：

- `save_options`: Dictionary，可包含 output_format、include_schema、include_indexes、indent 和 sort_keys。

<a id="member-gfconfigpipelineprofile-properties-access_options"></a>

### `access_options`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var access_options: Dictionary = {}
```

传给 GFConfigAccessGenerator 的访问器生成选项。

结构：

- `access_options`: Dictionary，可包含 method_name_style、constant_prefix、record_method_pattern、table_method_pattern、include_schema_comments、include_typed_records、typed_record_method_pattern、typed_record_class_suffix 和 overwrite_existing。

<a id="member-gfconfigpipelineprofile-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var metadata: Dictionary = {}
```

附加到生成数据库资源的元数据。

结构：

- `metadata`: Dictionary，保存项目工具、编辑器或 CI 附加的构建信息。

## 方法

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

- `overrides`: Dictionary，可包含 build_options、database_id、version、metadata、validate_database、validate_schema、parse_options 和 rebuild_indexes。
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

- `overrides`: Dictionary，可包含 save_options。
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

- `overrides`: Dictionary，可包含 access_options。
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

创建同内容拷贝。

返回：新 Profile 资源。

<a id="member-gfconfigpipelineprofile-methods-describe"></a>

### `describe`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func describe() -> Dictionary:
```

导出 Profile 摘要。

返回：Profile 摘要字典。

结构：

- `return`: Dictionary，包含 profile_id、database_id、version、output_path、access_output_path、access_class_name、access_provider_accessor、source_count、sources、build_options、save_options、access_options 和 metadata。
