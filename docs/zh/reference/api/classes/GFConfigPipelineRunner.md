# GFConfigPipelineRunner

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_pipeline_runner.gd`
- 模块：`Tools`
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
| 方法 | [`inspect_profile_path`](#member-gfconfigpipelinerunner-methods-inspect_profile_path) | `func inspect_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`export_profile_path`](#member-gfconfigpipelinerunner-methods-export_profile_path) | `func export_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`diff_profile_path`](#member-gfconfigpipelinerunner-methods-diff_profile_path) | `func diff_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:` |

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
- 首次版本：`unreleased`

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

- `options`: Dictionary，可包含 type_hint、cache_mode、build_options、database_id、version、metadata、validate_database、validate_schema、parse_options 和 rebuild_indexes。可另含target:String/StringName选择Profile消费目标。
- `return`: Dictionary，包含 success、operation、profile_path、profile_id、output_path、database、report、table_results、load_result、build_result、error_code 和 error。build_result包含author_ir、consumer_target与只读stable_id_plan，形状同GFConfigPipeline.build_profile。

<a id="member-gfconfigpipelinerunner-methods-inspect_profile_path"></a>

### `inspect_profile_path`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func inspect_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:
```

加载并完整校验 Profile，返回本次已封存 IR 的结构与来源摘要，不写入任何产物。 摘要只在整批构建成功后交付，不包含记录值；失败保留原校验报告，不显示部分表为已生效。 来源收据取自本次实际读取，结构取自同一次构建的 IR，不重新推导或重新读取来源。

参数：

| 名称 | 说明 |
|---|---|
| `profile_path` | Profile 的 res:// 或 user:// 资源路径。 |
| `options` | 与 build_profile_path 相同的加载和构建覆盖选项。 |

返回：无数据记录载荷的只读检查报告。

结构：

- `options`: Dictionary，可包含 type_hint、cache_mode、build_options、database_id、version、metadata、validate_database、validate_schema、parse_options、rebuild_indexes 和 work_limits；inspect 强制完整数据库与 Schema 校验。可另含target:String/StringName；报告所选目标的生效字段及其原始来源收据。
- `return`: Dictionary，包含 success、operation、profile_path、profile_id、report、schema_report、error_code 和 error；schema_report 成功时包含 format、format_version、database_id、version、table_count、tables 和 target_capabilities，每表含 table_name、source_path、source_format、record_count、schema、schema_origin、source_receipt 和 header_location；schema_origin 为 explicit、typed_headers、inferred 或 none；失败时 schema_report 为空。

<a id="member-gfconfigpipelinerunner-methods-export_profile_path"></a>

### `export_profile_path`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func export_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:
```

从 Profile 路径构建并保存配置数据库资源。

参数：

| 名称 | 说明 |
|---|---|
| `profile_path` | Profile 资源路径，通常为 .tres 或 .res。 |
| `options` | 加载、构建、保存、访问器生成和增量导出覆盖选项；output_path、非空 access_output_path 与使用中的 manifest_path 必须位于 res:// 或 user:// URI 域，并在 freshness 判断前完成规范化与校验。 |

返回：运行结果。

结构：

- `options`: Dictionary，可包含 type_hint、cache_mode、output_path、build_options、save_options、access_output_path、access_options、access_class_name、access_provider_accessor、database_id、version、metadata、validate_database、validate_schema、parse_options、rebuild_indexes、changed_only、manifest_path、write_manifest、manifest_options、manifest_metadata、max_freshness_file_bytes、max_freshness_total_bytes 和 max_freshness_entries；各产物 options 可包含 allow_parent_output_path、allow_gf_source_output 和 allow_unowned_overwrite，其中 parent opt-in 不能越过 resource URI 根。可另含target:String/StringName、register_ids:bool及expected_input_digest:String，沿用GFConfigPipeline.export_profile的登记和输入凭据契约。
- `return`: Dictionary，包含 success、operation、profile_path、profile_id、output_path、database、report、table_results、load_result、build_result、save_result、access_result、export_result、manifest_path、manifest、manifest_result、freshness_report、skipped、changed_only、error_code 和 error。

<a id="member-gfconfigpipelinerunner-methods-diff_profile_path"></a>

### `diff_profile_path`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func diff_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:
```

比较两个作者 Profile 的已验收 IR；不依赖产物格式，不写产物或登记簿。 基线 Profile 可来自另一个目录或版本检出；必须显式提供，不能把缺失基线当作没有变化。 两边均使用相同 target 选择；比较完整作者数据，消费目标影响是保守上界。

参数：

| 名称 | 说明 |
|---|---|
| `profile_path` | 当前 Profile 资源路径。 |
| `options` | 构建选项及明确的基线。 |

返回：不含业务值、工作 Resource 或登记候选的只读报告。

结构：

- `options`: Dictionary，必须包含 baseline_profile:String；其余为 build_profile_path 选项。目标选择对两边一致。
- `return`: Dictionary，success:bool、operation:StringName=diff、profile_path:String、baseline_profile:String、diff_report:Dictionary（schema变化、记录增删、字段变化及保守引用/目标影响）、stable_id_changes:Array[Dictionary]、input_capture:Dictionary、error:String、error_code:int。
