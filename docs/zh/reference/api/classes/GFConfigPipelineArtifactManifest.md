# GFConfigPipelineArtifactManifest

[API Reference](../index.md) / [Tool Packages](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_pipeline_artifact_manifest.gd`
- 模块：`Tool Packages`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`8.0.0`

配置导表产物 manifest 辅助。 为 GFConfigPipelineProfile 生成输入摘要、输出摘要和 freshness 报告，支持 CI、 编辑器按钮或命令行在导表前判断是否可以跳过未变化的产物。 该工具记录 Profile 资源依赖、数据来源、编译阶段、输出和导表选项摘要， 不表达项目业务版本、热更新策略或远端发布流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`FORMAT`](#member-gfconfigpipelineartifactmanifest-constants-format) | `const FORMAT: String = "gf.config_pipeline.artifact_manifest"` |
| 常量 | [`FORMAT_VERSION`](#member-gfconfigpipelineartifactmanifest-constants-format_version) | `const FORMAT_VERSION: int = 1` |
| 方法 | [`make_manifest`](#member-gfconfigpipelineartifactmanifest-methods-make_manifest) | `func make_manifest( profile_path: String, profile: GFConfigPipelineProfile, options: Dictionary = {}, run_result: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`load_manifest`](#member-gfconfigpipelineartifactmanifest-methods-load_manifest) | `func load_manifest(manifest_path: String) -> Dictionary:` |
| 方法 | [`save_manifest`](#member-gfconfigpipelineartifactmanifest-methods-save_manifest) | `func save_manifest(manifest_path: String, manifest: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_freshness_report`](#member-gfconfigpipelineartifactmanifest-methods-make_freshness_report) | `func make_freshness_report( manifest_path: String, profile_path: String, profile: GFConfigPipelineProfile, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`get_default_manifest_path`](#member-gfconfigpipelineartifactmanifest-methods-get_default_manifest_path) | `func get_default_manifest_path(output_path: String) -> String:` |

## 常量

<a id="member-gfconfigpipelineartifactmanifest-constants-format"></a>

### `FORMAT`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const FORMAT: String = "gf.config_pipeline.artifact_manifest"
```

manifest JSON 格式标识。

<a id="member-gfconfigpipelineartifactmanifest-constants-format_version"></a>

### `FORMAT_VERSION`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const FORMAT_VERSION: int = 1
```

manifest 格式版本。

## 方法

<a id="member-gfconfigpipelineartifactmanifest-methods-make_manifest"></a>

### `make_manifest`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func make_manifest( profile_path: String, profile: GFConfigPipelineProfile, options: Dictionary = {}, run_result: Dictionary = {} ) -> Dictionary:
```

根据 Profile 和本次选项生成 manifest 字典。

参数：

| 名称 | 说明 |
|---|---|
| `profile_path` | Profile 资源路径。 |
| `profile` | 导表 Profile 资源。 |
| `options` | 本次导表选项。 |
| `run_result` | 可选 Runner 或 Pipeline 结果；只会提取 JSON 兼容摘要。 |

返回：manifest 字典。

结构：

- `options`: Dictionary，可包含 output_path、access_output_path、access_class_name、access_provider_accessor、build_options、save_options、access_options、manifest_metadata、max_freshness_file_bytes、max_freshness_total_bytes 和 max_freshness_entries；三个 freshness 预算必须为非负整数，分别限制单文件字节数、累计哈希字节数和扫描条目数。
- `run_result`: Dictionary，可包含 success、operation、profile_id、output_path、save_result、access_result、report 和 error。
- `return`: Dictionary，包含 format、format_version、artifact_owner、profile_path、profile_id、profile_digest、input_digest、output_digest、options_digest、compiler_digest、compiler_fingerprint、profile_entries、source_entries、output_entries、scan_report、metadata、run_summary 和 manifest_digest。

<a id="member-gfconfigpipelineartifactmanifest-methods-load_manifest"></a>

### `load_manifest`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func load_manifest(manifest_path: String) -> Dictionary:
```

读取 manifest JSON 文件。

参数：

| 名称 | 说明 |
|---|---|
| `manifest_path` | manifest JSON 路径。 |

返回：读取报告。

结构：

- `return`: Dictionary，包含 success、path、manifest、error_code 和 error。

<a id="member-gfconfigpipelineartifactmanifest-methods-save_manifest"></a>

### `save_manifest`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func save_manifest(manifest_path: String, manifest: Dictionary, options: Dictionary = {}) -> Dictionary:
```

保存 manifest JSON 文件。

参数：

| 名称 | 说明 |
|---|---|
| `manifest_path` | manifest JSON 输出路径。 |
| `manifest` | make_manifest() 返回的字典。 |
| `options` | 保存选项。 |

返回：保存报告。

结构：

- `manifest`: Dictionary，包含 format、format_version、artifact_owner、profile_digest、input_digest、output_digest、options_digest、compiler_digest、compiler_fingerprint、profile_entries、source_entries、output_entries 和 scan_report。
- `options`: Dictionary，可包含 dry_run、overwrite_existing、allow_unowned_overwrite、indent、sort_keys、allow_parent_output_path、allow_gf_source_output 和 allow_absolute_output_path；allow_unowned_overwrite 仅用于调用方已明确确认现有文件所有权的迁移场景。
- `return`: Dictionary，包含 success、path、status、error_code、error、artifact_report、written、changed 和 dry_run。

<a id="member-gfconfigpipelineartifactmanifest-methods-make_freshness_report"></a>

### `make_freshness_report`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func make_freshness_report( manifest_path: String, profile_path: String, profile: GFConfigPipelineProfile, options: Dictionary = {} ) -> Dictionary:
```

生成当前 Profile 相对已有 manifest 的 freshness 报告。

参数：

| 名称 | 说明 |
|---|---|
| `manifest_path` | 已保存 manifest 路径。 |
| `profile_path` | Profile 资源路径。 |
| `profile` | 导表 Profile 资源。 |
| `options` | 本次导表选项。 |

返回：freshness 报告。

结构：

- `options`: Dictionary，可包含 output_path、access_output_path、access_class_name、access_provider_accessor、build_options、save_options、access_options、max_freshness_file_bytes、max_freshness_total_bytes 和 max_freshness_entries。
- `return`: Dictionary，包含 fresh、success、manifest_path、current_manifest、stored_manifest、load_result、scan_report、reasons、missing_outputs 和 changed_fields。

<a id="member-gfconfigpipelineartifactmanifest-methods-get_default_manifest_path"></a>

### `get_default_manifest_path`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_default_manifest_path(output_path: String) -> String:
```

根据输出路径推导默认 manifest 路径。

参数：

| 名称 | 说明 |
|---|---|
| `output_path` | 数据库输出路径。 |

返回：默认 manifest 路径；output_path 为空时返回空字符串。
