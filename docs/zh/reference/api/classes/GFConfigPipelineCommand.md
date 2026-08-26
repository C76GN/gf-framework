# GFConfigPipelineCommand

[API Reference](../index.md) / [Tools](../tools.md) / [类索引](index.md)

- 路径：`addons/gf/tools/config_pipeline/gf_config_pipeline_command.gd`
- 模块：`Tools`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`8.0.0`

配置导表工具的 Godot 命令参数适配器。 解析 Godot `--` 之后的用户参数，调用 GFConfigPipelineRunner，并返回适合 CI、 编辑器按钮或项目脚本消费的结构化报告。该类只封装 Godot 原生命令入口，不调用 外部进程，不绑定项目目录、表语义或发布策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`run`](#member-gfconfigpipelinecommand-methods-run) | `func run(arguments: PackedStringArray = PackedStringArray(), base_options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_output_text`](#member-gfconfigpipelinecommand-methods-make_output_text) | `func make_output_text(result: Dictionary, pretty: bool = true) -> String:` |
| 方法 | [`get_usage`](#member-gfconfigpipelinecommand-methods-get_usage) | `func get_usage() -> String:` |

## 方法

<a id="member-gfconfigpipelinecommand-methods-run"></a>

### `run`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func run(arguments: PackedStringArray = PackedStringArray(), base_options: Dictionary = {}) -> Dictionary:
```

执行一次导表命令。

参数：

| 名称 | 说明 |
|---|---|
| `arguments` | Godot \`--\` 之后的用户参数。 |
| `base_options` | 调用方直接注入的默认选项，命令行参数会覆盖同名字段。 |

返回：命令报告。

结构：

- `base_options`: Dictionary，可包含 GFConfigPipelineRunner 选项，以及 output_path、access_output_path、access_class_name、access_provider_accessor、dry_run、changed_only、manifest_path、write_manifest、manifest_options、max_freshness_file_bytes、max_freshness_total_bytes 和 max_freshness_entries；三个非空产物路径都必须位于 res:// 或 user://，各产物 options 可包含 allow_parent_output_path、allow_gf_source_output 和 allow_unowned_overwrite。
- `return`: Dictionary，包含 success、exit_code、operation、profile_path、options、runner_result、json_report、pretty_output、usage_requested、strict、dry_run、changed_only、manifest_path 和 error。

<a id="member-gfconfigpipelinecommand-methods-make_output_text"></a>

### `make_output_text`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func make_output_text(result: Dictionary, pretty: bool = true) -> String:
```

把命令报告格式化为可打印文本。

参数：

| 名称 | 说明 |
|---|---|
| `result` | run() 返回的命令报告。 |
| `pretty` | JSON 输出是否使用缩进。 |

返回：可打印文本；json_report 为 true 时返回 JSON 字符串。

结构：

- `result`: Dictionary，包含 success、exit_code、operation、profile_path、runner_result、json_report、pretty_output、usage_requested 和 error。

<a id="member-gfconfigpipelinecommand-methods-get_usage"></a>

### `get_usage`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_usage() -> String:
```

返回 Godot 命令行用法说明。

返回：用法说明文本。
