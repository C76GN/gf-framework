# GFConfigPipelineRunner

[API Reference](../index.md) / [Tool Packages](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_pipeline_runner.gd`
- 模块：`Tool Packages`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`5.2.0`

配置导表 Profile 的 Godot 原生运行入口。 负责从 Godot 资源路径加载 GFConfigPipelineProfile，并调用 GFConfigPipeline 构建或导出。 Runner 不处理命令行参数、编辑器 UI、外部进程、项目目录约定或发布策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`load_profile`](#member-gfconfigpipelinerunner-methods-load_profile) | `func load_profile(profile_path: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`build_profile_path`](#member-gfconfigpipelinerunner-methods-build_profile_path) | `func build_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`export_profile_path`](#member-gfconfigpipelinerunner-methods-export_profile_path) | `func export_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:` |

## 方法

<a id="member-gfconfigpipelinerunner-methods-load_profile"></a>

### `load_profile`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func load_profile(profile_path: String, options: Dictionary = {}) -> Dictionary:
```

加载导表 Profile 资源。

参数：

| 名称 | 说明 |
|---|---|
| `profile_path` | Profile 资源路径，通常为 .tres 或 .res。 |
| `options` | 加载选项，支持 type_hint 和 cache_mode。 |

返回：加载结果。

结构：

- `options`: Dictionary，可包含 type_hint: String 和 cache_mode: ResourceLoader.CacheMode 对应整数。
- `return`: Dictionary，包含 success、operation、profile_path、profile、profile_id、report、error_code 和 error。

<a id="member-gfconfigpipelinerunner-methods-build_profile_path"></a>

### `build_profile_path`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func build_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:
```

从 Profile 路径构建配置数据库资源。

参数：

| 名称 | 说明 |
|---|---|
| `profile_path` | Profile 资源路径，通常为 .tres 或 .res。 |
| `options` | 加载和构建覆盖选项。 |

返回：运行结果。

结构：

- `options`: Dictionary，可包含 type_hint、cache_mode、build_options、database_id、version、metadata、validate_database、validate_schema、parse_options 和 rebuild_indexes。
- `return`: Dictionary，包含 success、operation、profile_path、profile_id、output_path、database、report、table_results、load_result、build_result、error_code 和 error。

<a id="member-gfconfigpipelinerunner-methods-export_profile_path"></a>

### `export_profile_path`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func export_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:
```

从 Profile 路径构建并保存配置数据库资源。

参数：

| 名称 | 说明 |
|---|---|
| `profile_path` | Profile 资源路径，通常为 .tres 或 .res。 |
| `options` | 加载、构建、保存、访问器生成和增量导出覆盖选项。 |

返回：运行结果。

结构：

- `options`: Dictionary，可包含 type_hint、cache_mode、output_path、build_options、save_options、access_output_path、access_options、access_class_name、access_provider_accessor、database_id、version、metadata、validate_database、validate_schema、parse_options、rebuild_indexes、changed_only、manifest_path、write_manifest、manifest_options、manifest_metadata、max_freshness_file_bytes、max_freshness_total_bytes 和 max_freshness_entries；各产物 options 可包含 allow_unowned_overwrite。
- `return`: Dictionary，包含 success、operation、profile_path、profile_id、output_path、database、report、table_results、load_result、build_result、save_result、access_result、export_result、manifest_path、manifest、manifest_result、freshness_report、skipped、changed_only、error_code 和 error。
