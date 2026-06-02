# GFDiagnosticsUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_diagnostics_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

运行时诊断聚合工具。 提供架构生命周期、事件系统、性能、日志和外部贡献诊断的统一快照。 诊断命令、监控项和快照分区通过 Callable 注册，框架只负责调度和包装结果，不解释项目业务数据。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`snapshot_collected`](#member-gfdiagnosticsutility-signals-snapshot_collected) | `signal snapshot_collected(snapshot: Dictionary)` |
| 信号 | [`diagnostic_command_executed`](#member-gfdiagnosticsutility-signals-diagnostic_command_executed) | `signal diagnostic_command_executed(command_name: StringName, result: Dictionary)` |
| 信号 | [`monitor_sampled`](#member-gfdiagnosticsutility-signals-monitor_sampled) | `signal monitor_sampled(monitor_id: StringName, sample: Dictionary)` |
| 枚举 | [`CommandTier`](#member-gfdiagnosticsutility-enums-commandtier) | `enum CommandTier` |
| 属性 | [`include_performance_monitors`](#member-gfdiagnosticsutility-properties-include_performance_monitors) | `var include_performance_monitors: bool = true` |
| 属性 | [`default_recent_log_count`](#member-gfdiagnosticsutility-properties-default_recent_log_count) | `var default_recent_log_count: int = 20` |
| 属性 | [`max_command_tier`](#member-gfdiagnosticsutility-properties-max_command_tier) | `var max_command_tier: CommandTier = CommandTier.OBSERVE` |
| 属性 | [`require_auth_token`](#member-gfdiagnosticsutility-properties-require_auth_token) | `var require_auth_token: bool = false` |
| 属性 | [`auth_token`](#member-gfdiagnosticsutility-properties-auth_token) | `var auth_token: String = ""` |
| 属性 | [`allow_danger_commands`](#member-gfdiagnosticsutility-properties-allow_danger_commands) | `var allow_danger_commands: bool = false` |
| 属性 | [`encode_command_results_for_json`](#member-gfdiagnosticsutility-properties-encode_command_results_for_json) | `var encode_command_results_for_json: bool = false` |
| 属性 | [`default_scene_tree_max_depth`](#member-gfdiagnosticsutility-properties-default_scene_tree_max_depth) | `var default_scene_tree_max_depth: int = 4` |
| 属性 | [`default_scene_tree_max_nodes`](#member-gfdiagnosticsutility-properties-default_scene_tree_max_nodes) | `var default_scene_tree_max_nodes: int = 128` |
| 方法 | [`init`](#member-gfdiagnosticsutility-methods-init) | `func init() -> void:` |
| 方法 | [`ready`](#member-gfdiagnosticsutility-methods-ready) | `func ready() -> void:` |
| 方法 | [`dispose`](#member-gfdiagnosticsutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`register_command`](#member-gfdiagnosticsutility-methods-register_command) | `func register_command( command_name: StringName, callback: Callable, description: String = "", tier: CommandTier = CommandTier.OBSERVE, options: Dictionary = {} ) -> void:` |
| 方法 | [`unregister_command`](#member-gfdiagnosticsutility-methods-unregister_command) | `func unregister_command(command_name: StringName) -> void:` |
| 方法 | [`has_command`](#member-gfdiagnosticsutility-methods-has_command) | `func has_command(command_name: StringName) -> bool:` |
| 方法 | [`set_command_parameter_schema`](#member-gfdiagnosticsutility-methods-set_command_parameter_schema) | `func set_command_parameter_schema(command_name: StringName, parameters: Variant) -> bool:` |
| 方法 | [`set_command_enabled`](#member-gfdiagnosticsutility-methods-set_command_enabled) | `func set_command_enabled(command_name: StringName, enabled: bool) -> bool:` |
| 方法 | [`set_all_commands_enabled`](#member-gfdiagnosticsutility-methods-set_all_commands_enabled) | `func set_all_commands_enabled( enabled: bool, command_names: PackedStringArray = PackedStringArray() ) -> int:` |
| 方法 | [`is_command_enabled`](#member-gfdiagnosticsutility-methods-is_command_enabled) | `func is_command_enabled(command_name: StringName) -> bool:` |
| 方法 | [`get_command_descriptions`](#member-gfdiagnosticsutility-methods-get_command_descriptions) | `func get_command_descriptions() -> Dictionary:` |
| 方法 | [`get_command_catalog`](#member-gfdiagnosticsutility-methods-get_command_catalog) | `func get_command_catalog() -> Dictionary:` |
| 方法 | [`register_monitor`](#member-gfdiagnosticsutility-methods-register_monitor) | `func register_monitor(monitor_id: StringName, provider: Callable, options: Dictionary = {}) -> bool:` |
| 方法 | [`unregister_monitor`](#member-gfdiagnosticsutility-methods-unregister_monitor) | `func unregister_monitor(monitor_id: StringName) -> void:` |
| 方法 | [`has_monitor`](#member-gfdiagnosticsutility-methods-has_monitor) | `func has_monitor(monitor_id: StringName) -> bool:` |
| 方法 | [`get_monitor_catalog`](#member-gfdiagnosticsutility-methods-get_monitor_catalog) | `func get_monitor_catalog() -> Dictionary:` |
| 方法 | [`register_monitor_preset`](#member-gfdiagnosticsutility-methods-register_monitor_preset) | `func register_monitor_preset( preset_id: StringName, monitor_ids: PackedStringArray, options: Dictionary = {} ) -> bool:` |
| 方法 | [`add_monitor_to_preset`](#member-gfdiagnosticsutility-methods-add_monitor_to_preset) | `func add_monitor_to_preset(preset_id: StringName, monitor_id: StringName) -> bool:` |
| 方法 | [`unregister_monitor_preset`](#member-gfdiagnosticsutility-methods-unregister_monitor_preset) | `func unregister_monitor_preset(preset_id: StringName) -> void:` |
| 方法 | [`has_monitor_preset`](#member-gfdiagnosticsutility-methods-has_monitor_preset) | `func has_monitor_preset(preset_id: StringName) -> bool:` |
| 方法 | [`get_monitor_preset_ids`](#member-gfdiagnosticsutility-methods-get_monitor_preset_ids) | `func get_monitor_preset_ids() -> PackedStringArray:` |
| 方法 | [`register_snapshot_section_provider`](#member-gfdiagnosticsutility-methods-register_snapshot_section_provider) | `func register_snapshot_section_provider(section_id: StringName, provider: Callable) -> bool:` |
| 方法 | [`unregister_snapshot_section_provider`](#member-gfdiagnosticsutility-methods-unregister_snapshot_section_provider) | `func unregister_snapshot_section_provider(section_id: StringName) -> void:` |
| 方法 | [`has_snapshot_section_provider`](#member-gfdiagnosticsutility-methods-has_snapshot_section_provider) | `func has_snapshot_section_provider(section_id: StringName) -> bool:` |
| 方法 | [`register_tool_snapshot_provider`](#member-gfdiagnosticsutility-methods-register_tool_snapshot_provider) | `func register_tool_snapshot_provider(tool_id: StringName, provider: Callable) -> bool:` |
| 方法 | [`unregister_tool_snapshot_provider`](#member-gfdiagnosticsutility-methods-unregister_tool_snapshot_provider) | `func unregister_tool_snapshot_provider(tool_id: StringName) -> void:` |
| 方法 | [`has_tool_snapshot_provider`](#member-gfdiagnosticsutility-methods-has_tool_snapshot_provider) | `func has_tool_snapshot_provider(tool_id: StringName) -> bool:` |
| 方法 | [`collect_monitor_snapshot`](#member-gfdiagnosticsutility-methods-collect_monitor_snapshot) | `func collect_monitor_snapshot( monitor_ids: PackedStringArray = PackedStringArray(), include_hidden: bool = false ) -> Dictionary:` |
| 方法 | [`collect_monitor_preset`](#member-gfdiagnosticsutility-methods-collect_monitor_preset) | `func collect_monitor_preset(preset_id: StringName, include_hidden: bool = false) -> Dictionary:` |
| 方法 | [`export_monitor_snapshot`](#member-gfdiagnosticsutility-methods-export_monitor_snapshot) | `func export_monitor_snapshot(snapshot: Dictionary, format: StringName = &"json") -> String:` |
| 方法 | [`set_auth_token`](#member-gfdiagnosticsutility-methods-set_auth_token) | `func set_auth_token(token: String, required: bool = true) -> void:` |
| 方法 | [`execute_command`](#member-gfdiagnosticsutility-methods-execute_command) | `func execute_command(command_name: StringName, args: Dictionary = {}) -> Dictionary:` |
| 方法 | [`execute_command_json_safe`](#member-gfdiagnosticsutility-methods-execute_command_json_safe) | `func execute_command_json_safe(command_name: StringName, args: Dictionary = {}) -> Dictionary:` |
| 方法 | [`command_result_to_json_compatible`](#member-gfdiagnosticsutility-methods-command_result_to_json_compatible) | `func command_result_to_json_compatible(result: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`collect_snapshot`](#member-gfdiagnosticsutility-methods-collect_snapshot) | `func collect_snapshot(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`collect_performance_snapshot`](#member-gfdiagnosticsutility-methods-collect_performance_snapshot) | `func collect_performance_snapshot() -> Dictionary:` |
| 方法 | [`collect_log_snapshot`](#member-gfdiagnosticsutility-methods-collect_log_snapshot) | `func collect_log_snapshot(recent_log_count: int = 20, include_recent_logs: bool = true) -> Dictionary:` |
| 方法 | [`collect_scene_tree_snapshot`](#member-gfdiagnosticsutility-methods-collect_scene_tree_snapshot) | `func collect_scene_tree_snapshot(root: Node = null, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`collect_signal_graph_snapshot`](#member-gfdiagnosticsutility-methods-collect_signal_graph_snapshot) | `func collect_signal_graph_snapshot(root: Node = null, options: Dictionary = {}) -> Dictionary:` |

## 信号

<a id="member-gfdiagnosticsutility-signals-snapshot_collected"></a>

### `snapshot_collected`

- API：`public`

```gdscript
signal snapshot_collected(snapshot: Dictionary)
```

采集快照后发出。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 刚采集到的诊断快照。 |

结构：

- `snapshot`: Dictionary，包含 collect_snapshot() 返回的顶层诊断分区。

<a id="member-gfdiagnosticsutility-signals-diagnostic_command_executed"></a>

### `diagnostic_command_executed`

- API：`public`

```gdscript
signal diagnostic_command_executed(command_name: StringName, result: Dictionary)
```

执行诊断命令后发出。

参数：

| 名称 | 说明 |
|---|---|
| `command_name` | 已执行的诊断命令名。 |
| `result` | 命令执行结果。 |

结构：

- `result`: Dictionary，包含 ok、value、error、metadata 等字段。

<a id="member-gfdiagnosticsutility-signals-monitor_sampled"></a>

### `monitor_sampled`

- API：`public`

```gdscript
signal monitor_sampled(monitor_id: StringName, sample: Dictionary)
```

采样诊断监控项后发出。

参数：

| 名称 | 说明 |
|---|---|
| `monitor_id` | 监控项标识。 |
| `sample` | 采样结果。 |

结构：

- `sample`: Dictionary，包含 id、label、group、value、valid、error、metadata 和 sampled_at_unix。

## 枚举

<a id="member-gfdiagnosticsutility-enums-commandtier"></a>

### `CommandTier`

- API：`public`

```gdscript
enum CommandTier { ## 只读取状态。 OBSERVE, ## 修改调试输入或临时过滤条件。 INPUT, ## 控制运行时行为。 CONTROL, ## 可能破坏状态、存档或远端连接。 DANGER, }
```

诊断命令风险等级。

## 属性

<a id="member-gfdiagnosticsutility-properties-include_performance_monitors"></a>

### `include_performance_monitors`

- API：`public`

```gdscript
var include_performance_monitors: bool = true
```

是否采集 Godot Performance 监视器。

<a id="member-gfdiagnosticsutility-properties-default_recent_log_count"></a>

### `default_recent_log_count`

- API：`public`

```gdscript
var default_recent_log_count: int = 20
```

快照中默认包含的最近日志数量。

<a id="member-gfdiagnosticsutility-properties-max_command_tier"></a>

### `max_command_tier`

- API：`public`

```gdscript
var max_command_tier: CommandTier = CommandTier.OBSERVE
```

当前允许执行的最高命令等级。

<a id="member-gfdiagnosticsutility-properties-require_auth_token"></a>

### `require_auth_token`

- API：`public`

```gdscript
var require_auth_token: bool = false
```

是否要求命令参数提供 auth_token 或 _auth_token。

<a id="member-gfdiagnosticsutility-properties-auth_token"></a>

### `auth_token`

- API：`public`

```gdscript
var auth_token: String = ""
```

诊断命令认证 token。为空时无法通过认证。

<a id="member-gfdiagnosticsutility-properties-allow_danger_commands"></a>

### `allow_danger_commands`

- API：`public`

```gdscript
var allow_danger_commands: bool = false
```

是否允许执行 DANGER 等级命令。即使 max_command_tier 足够，也需要显式开启。

<a id="member-gfdiagnosticsutility-properties-encode_command_results_for_json"></a>

### `encode_command_results_for_json`

- API：`public`

```gdscript
var encode_command_results_for_json: bool = false
```

是否把诊断命令结果转换为 JSON 兼容 Variant。

<a id="member-gfdiagnosticsutility-properties-default_scene_tree_max_depth"></a>

### `default_scene_tree_max_depth`

- API：`public`

```gdscript
var default_scene_tree_max_depth: int = 4
```

场景树快照默认递归深度。

<a id="member-gfdiagnosticsutility-properties-default_scene_tree_max_nodes"></a>

### `default_scene_tree_max_nodes`

- API：`public`

```gdscript
var default_scene_tree_max_nodes: int = 128
```

场景树快照默认最多采集节点数。

## 方法

<a id="member-gfdiagnosticsutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化内置诊断命令和监控项。

<a id="member-gfdiagnosticsutility-methods-ready"></a>

### `ready`

- API：`public`

```gdscript
func ready() -> void:
```

绑定控制台诊断命令。

<a id="member-gfdiagnosticsutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放诊断注册表并解绑控制台命令。

<a id="member-gfdiagnosticsutility-methods-register_command"></a>

### `register_command`

- API：`public`

```gdscript
func register_command( command_name: StringName, callback: Callable, description: String = "", tier: CommandTier = CommandTier.OBSERVE, options: Dictionary = {} ) -> void:
```

注册诊断命令。

参数：

| 名称 | 说明 |
|---|---|
| `command_name` | 命令名。 |
| `callback` | 回调，签名建议为 func(args: Dictionary) -> Variant。 |
| `description` | 描述文本。 |
| `tier` | 命令风险等级。 |
| `options` | 可选元数据，支持 parameters、metadata、enabled。 |

结构：

- `options`: Dictionary，支持 parameters、metadata 和 enabled。

<a id="member-gfdiagnosticsutility-methods-unregister_command"></a>

### `unregister_command`

- API：`public`

```gdscript
func unregister_command(command_name: StringName) -> void:
```

注销诊断命令。

参数：

| 名称 | 说明 |
|---|---|
| `command_name` | 命令名。 |

<a id="member-gfdiagnosticsutility-methods-has_command"></a>

### `has_command`

- API：`public`

```gdscript
func has_command(command_name: StringName) -> bool:
```

检查诊断命令是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `command_name` | 命令名。 |

返回：存在返回 true。

<a id="member-gfdiagnosticsutility-methods-set_command_parameter_schema"></a>

### `set_command_parameter_schema`

- API：`public`

```gdscript
func set_command_parameter_schema(command_name: StringName, parameters: Variant) -> bool:
```

设置诊断命令参数 schema。

参数：

| 名称 | 说明 |
|---|---|
| `command_name` | 命令名。 |
| `parameters` | 参数 schema，可为数组或按参数名索引的字典。 |

返回：设置成功返回 true。

结构：

- `parameters`: Variant，支持 Array[Dictionary] 或 Dictionary 形式的参数 schema。

<a id="member-gfdiagnosticsutility-methods-set_command_enabled"></a>

### `set_command_enabled`

- API：`public`

```gdscript
func set_command_enabled(command_name: StringName, enabled: bool) -> bool:
```

设置诊断命令是否启用。

参数：

| 名称 | 说明 |
|---|---|
| `command_name` | 命令名。 |
| `enabled` | 是否启用。 |

返回：命令存在时返回 true。

<a id="member-gfdiagnosticsutility-methods-set_all_commands_enabled"></a>

### `set_all_commands_enabled`

- API：`public`

```gdscript
func set_all_commands_enabled( enabled: bool, command_names: PackedStringArray = PackedStringArray() ) -> int:
```

批量设置命令是否启用。

参数：

| 名称 | 说明 |
|---|---|
| `enabled` | 是否启用。 |
| `command_names` | 指定命令；为空时作用于全部已注册命令。 |

返回：实际处理的命令数量。

<a id="member-gfdiagnosticsutility-methods-is_command_enabled"></a>

### `is_command_enabled`

- API：`public`

```gdscript
func is_command_enabled(command_name: StringName) -> bool:
```

检查命令是否启用。

参数：

| 名称 | 说明 |
|---|---|
| `command_name` | 命令名。 |

返回：命令存在且启用时返回 true。

<a id="member-gfdiagnosticsutility-methods-get_command_descriptions"></a>

### `get_command_descriptions`

- API：`public`

```gdscript
func get_command_descriptions() -> Dictionary:
```

获取诊断命令描述。

返回：命令名到描述的字典。

结构：

- `return`: Dictionary[StringName, String]，以命令名为键。

<a id="member-gfdiagnosticsutility-methods-get_command_catalog"></a>

### `get_command_catalog`

- API：`public`

```gdscript
func get_command_catalog() -> Dictionary:
```

获取诊断命令目录。

返回：命令名到命令元数据的字典。

结构：

- `return`: Dictionary[StringName, Dictionary]，每个值包含 description、tier、tier_name、enabled、parameters 和 metadata。

<a id="member-gfdiagnosticsutility-methods-register_monitor"></a>

### `register_monitor`

- API：`public`

```gdscript
func register_monitor(monitor_id: StringName, provider: Callable, options: Dictionary = {}) -> bool:
```

注册诊断监控项。

参数：

| 名称 | 说明 |
|---|---|
| `monitor_id` | 监控项唯一标识。 |
| `provider` | 无参数采样回调。 |
| `options` | 可选元数据，支持 label、group、visible、metadata、min_interval_seconds。 |

返回：注册成功返回 true。

结构：

- `options`: Dictionary，支持 label、group、visible、metadata 和 min_interval_seconds。

<a id="member-gfdiagnosticsutility-methods-unregister_monitor"></a>

### `unregister_monitor`

- API：`public`

```gdscript
func unregister_monitor(monitor_id: StringName) -> void:
```

注销诊断监控项。

参数：

| 名称 | 说明 |
|---|---|
| `monitor_id` | 监控项唯一标识。 |

<a id="member-gfdiagnosticsutility-methods-has_monitor"></a>

### `has_monitor`

- API：`public`

```gdscript
func has_monitor(monitor_id: StringName) -> bool:
```

检查诊断监控项是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `monitor_id` | 监控项唯一标识。 |

返回：存在返回 true。

<a id="member-gfdiagnosticsutility-methods-get_monitor_catalog"></a>

### `get_monitor_catalog`

- API：`public`

```gdscript
func get_monitor_catalog() -> Dictionary:
```

获取诊断监控项目录。

返回：监控项元数据字典。

结构：

- `return`: Dictionary[StringName, Dictionary]，每个值包含 label、group、visible、metadata 和 min_interval_seconds。

<a id="member-gfdiagnosticsutility-methods-register_monitor_preset"></a>

### `register_monitor_preset`

- API：`public`

```gdscript
func register_monitor_preset( preset_id: StringName, monitor_ids: PackedStringArray, options: Dictionary = {} ) -> bool:
```

注册诊断监控预设。

参数：

| 名称 | 说明 |
|---|---|
| `preset_id` | 预设唯一标识。 |
| `monitor_ids` | 预设包含的监控项标识。 |
| `options` | 可选元数据，支持 label、metadata。 |

返回：注册成功返回 true。

结构：

- `options`: Dictionary，支持 label 和 metadata。

<a id="member-gfdiagnosticsutility-methods-add_monitor_to_preset"></a>

### `add_monitor_to_preset`

- API：`public`

```gdscript
func add_monitor_to_preset(preset_id: StringName, monitor_id: StringName) -> bool:
```

将一个监控项追加到已有预设；预设不存在时会创建。

参数：

| 名称 | 说明 |
|---|---|
| `preset_id` | 预设唯一标识。 |
| `monitor_id` | 监控项唯一标识。 |

返回：追加成功返回 true。

<a id="member-gfdiagnosticsutility-methods-unregister_monitor_preset"></a>

### `unregister_monitor_preset`

- API：`public`

```gdscript
func unregister_monitor_preset(preset_id: StringName) -> void:
```

注销诊断监控预设。

参数：

| 名称 | 说明 |
|---|---|
| `preset_id` | 预设唯一标识。 |

<a id="member-gfdiagnosticsutility-methods-has_monitor_preset"></a>

### `has_monitor_preset`

- API：`public`

```gdscript
func has_monitor_preset(preset_id: StringName) -> bool:
```

检查诊断监控预设是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `preset_id` | 预设唯一标识。 |

返回：存在返回 true。

<a id="member-gfdiagnosticsutility-methods-get_monitor_preset_ids"></a>

### `get_monitor_preset_ids`

- API：`public`

```gdscript
func get_monitor_preset_ids() -> PackedStringArray:
```

获取诊断监控预设列表。

返回：预设标识列表。

<a id="member-gfdiagnosticsutility-methods-register_snapshot_section_provider"></a>

### `register_snapshot_section_provider`

- API：`public`

```gdscript
func register_snapshot_section_provider(section_id: StringName, provider: Callable) -> bool:
```

注册快照分区 provider。用于扩展或项目把自己的诊断数据贡献到 collect_snapshot() 顶层字段。

参数：

| 名称 | 说明 |
|---|---|
| `section_id` | 快照顶层字段名。 |
| `provider` | 无参数采样回调，建议返回 Dictionary。 |

返回：注册成功返回 true。

<a id="member-gfdiagnosticsutility-methods-unregister_snapshot_section_provider"></a>

### `unregister_snapshot_section_provider`

- API：`public`

```gdscript
func unregister_snapshot_section_provider(section_id: StringName) -> void:
```

注销快照分区 provider。

参数：

| 名称 | 说明 |
|---|---|
| `section_id` | 快照顶层字段名。 |

<a id="member-gfdiagnosticsutility-methods-has_snapshot_section_provider"></a>

### `has_snapshot_section_provider`

- API：`public`

```gdscript
func has_snapshot_section_provider(section_id: StringName) -> bool:
```

检查快照分区 provider 是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `section_id` | 快照顶层字段名。 |

返回：存在返回 true。

<a id="member-gfdiagnosticsutility-methods-register_tool_snapshot_provider"></a>

### `register_tool_snapshot_provider`

- API：`public`

```gdscript
func register_tool_snapshot_provider(tool_id: StringName, provider: Callable) -> bool:
```

注册工具快照 provider。用于扩展或项目把 get_debug_snapshot() 风格数据贡献到 tools 字段。

参数：

| 名称 | 说明 |
|---|---|
| `tool_id` | tools 内部字段名。 |
| `provider` | 无参数采样回调，建议返回 Dictionary。 |

返回：注册成功返回 true。

<a id="member-gfdiagnosticsutility-methods-unregister_tool_snapshot_provider"></a>

### `unregister_tool_snapshot_provider`

- API：`public`

```gdscript
func unregister_tool_snapshot_provider(tool_id: StringName) -> void:
```

注销工具快照 provider。

参数：

| 名称 | 说明 |
|---|---|
| `tool_id` | tools 内部字段名。 |

<a id="member-gfdiagnosticsutility-methods-has_tool_snapshot_provider"></a>

### `has_tool_snapshot_provider`

- API：`public`

```gdscript
func has_tool_snapshot_provider(tool_id: StringName) -> bool:
```

检查工具快照 provider 是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `tool_id` | tools 内部字段名。 |

返回：存在返回 true。

<a id="member-gfdiagnosticsutility-methods-collect_monitor_snapshot"></a>

### `collect_monitor_snapshot`

- API：`public`

```gdscript
func collect_monitor_snapshot( monitor_ids: PackedStringArray = PackedStringArray(), include_hidden: bool = false ) -> Dictionary:
```

采集诊断监控快照。

参数：

| 名称 | 说明 |
|---|---|
| `monitor_ids` | 指定监控项；为空时采集全部可见监控项。 |
| `include_hidden` | 为 true 时包含 visible=false 的监控项。 |

返回：监控快照字典。

结构：

- `return`: Dictionary，包含 timestamp_unix、monitor_count 和 monitors。

<a id="member-gfdiagnosticsutility-methods-collect_monitor_preset"></a>

### `collect_monitor_preset`

- API：`public`

```gdscript
func collect_monitor_preset(preset_id: StringName, include_hidden: bool = false) -> Dictionary:
```

按预设采集诊断监控快照。

参数：

| 名称 | 说明 |
|---|---|
| `preset_id` | 预设唯一标识。 |
| `include_hidden` | 为 true 时包含 visible=false 的监控项。 |

返回：监控快照字典。

结构：

- `return`: Dictionary，包含 collect_monitor_snapshot() 字段以及 preset_id、preset_label、preset_metadata。

<a id="member-gfdiagnosticsutility-methods-export_monitor_snapshot"></a>

### `export_monitor_snapshot`

- API：`public`

```gdscript
func export_monitor_snapshot(snapshot: Dictionary, format: StringName = &"json") -> String:
```

导出诊断监控快照。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | collect_monitor_snapshot() 或 collect_monitor_preset() 返回值。 |
| `format` | 导出格式，支持 json、text、csv。 |

返回：导出文本。

结构：

- `snapshot`: Dictionary，collect_monitor_snapshot() 或 collect_monitor_preset() 返回结构。

<a id="member-gfdiagnosticsutility-methods-set_auth_token"></a>

### `set_auth_token`

- API：`public`

```gdscript
func set_auth_token(token: String, required: bool = true) -> void:
```

设置诊断认证 token。

参数：

| 名称 | 说明 |
|---|---|
| `token` | token 文本。 |
| `required` | 是否立即启用 token 校验。 |

<a id="member-gfdiagnosticsutility-methods-execute_command"></a>

### `execute_command`

- API：`public`

```gdscript
func execute_command(command_name: StringName, args: Dictionary = {}) -> Dictionary:
```

执行诊断命令。

参数：

| 名称 | 说明 |
|---|---|
| `command_name` | 命令名。 |
| `args` | 命令参数。 |

返回：统一结果字典。

结构：

- `args`: Dictionary，命令参数；可包含 auth_token 以及该命令 parameter_schema 定义的字段。
- `return`: Dictionary，包含 ok、value、error、metadata。

<a id="member-gfdiagnosticsutility-methods-execute_command_json_safe"></a>

### `execute_command_json_safe`

- API：`public`

```gdscript
func execute_command_json_safe(command_name: StringName, args: Dictionary = {}) -> Dictionary:
```

执行诊断命令并返回 JSON 兼容结果。

参数：

| 名称 | 说明 |
|---|---|
| `command_name` | 命令名。 |
| `args` | 命令参数。 |

返回：JSON 兼容结果字典。

结构：

- `args`: Dictionary，命令参数；可包含 auth_token 以及该命令 parameter_schema 定义的字段。
- `return`: Dictionary，包含 JSON 兼容的 ok、value、error、metadata。

<a id="member-gfdiagnosticsutility-methods-command_result_to_json_compatible"></a>

### `command_result_to_json_compatible`

- API：`public`

```gdscript
func command_result_to_json_compatible(result: Dictionary, options: Dictionary = {}) -> Dictionary:
```

将命令结果转换为 JSON 兼容字典。

参数：

| 名称 | 说明 |
|---|---|
| `result` | execute_command() 返回的结果。 |
| `options` | 传给 GFVariantJsonCodec.variant_to_json_compatible() 的选项。 |

返回：JSON 兼容结果字典。

结构：

- `result`: Dictionary，execute_command() 返回结构。
- `options`: Dictionary，传给 GFVariantJsonCodec.variant_to_json_compatible() 的编码选项。
- `return`: Dictionary，JSON 兼容命令结果。

<a id="member-gfdiagnosticsutility-methods-collect_snapshot"></a>

### `collect_snapshot`

- API：`public`

```gdscript
func collect_snapshot(options: Dictionary = {}) -> Dictionary:
```

采集运行时诊断快照。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选参数，支持 recent_log_count、include_recent_logs、include_scene_tree、scene_tree_options、include_signal_graph、signal_graph_options。 |

返回：快照字典。

结构：

- `options`: Dictionary，支持 recent_log_count、include_recent_logs、include_scene_tree、scene_tree_options、include_signal_graph、signal_graph_options、include_monitors、monitor_preset、monitor_ids、include_hidden_monitors。
- `return`: Dictionary，包含 timestamp_unix、engine、build、architecture、event_system、performance、logs、network、tools，可选 scene_tree、signal_graph、monitors 和注册分区。

<a id="member-gfdiagnosticsutility-methods-collect_performance_snapshot"></a>

### `collect_performance_snapshot`

- API：`public`

```gdscript
func collect_performance_snapshot() -> Dictionary:
```

采集性能监视器快照。

返回：性能数据字典。

结构：

- `return`: Dictionary，包含 fps、process_time、physics_process_time、static_memory、object_count、node_count、resource_count。

<a id="member-gfdiagnosticsutility-methods-collect_log_snapshot"></a>

### `collect_log_snapshot`

- API：`public`

```gdscript
func collect_log_snapshot(recent_log_count: int = 20, include_recent_logs: bool = true) -> Dictionary:
```

采集日志缓存快照。

参数：

| 名称 | 说明 |
|---|---|
| `recent_log_count` | 最近日志数量。 |
| `include_recent_logs` | 是否包含日志条目。 |

返回：日志数据字典。

结构：

- `return`: Dictionary，包含 available、memory_count、dropped_count、recent。

<a id="member-gfdiagnosticsutility-methods-collect_scene_tree_snapshot"></a>

### `collect_scene_tree_snapshot`

- API：`public`

```gdscript
func collect_scene_tree_snapshot(root: Node = null, options: Dictionary = {}) -> Dictionary:
```

采集只读场景树快照。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 可选根节点；为空时优先使用当前场景，再回退到 Viewport root。 |
| `options` | 可选参数，支持 max_depth、max_nodes、include_groups、include_owner_path、include_script_path、include_internal。 |

返回：场景树快照字典。

结构：

- `options`: Dictionary，支持 max_depth、max_nodes、include_groups、include_owner_path、include_script_path、include_internal、root_path、prefer_current_scene。
- `return`: Dictionary，包含 available、node_count、truncated、root_path、root。

<a id="member-gfdiagnosticsutility-methods-collect_signal_graph_snapshot"></a>

### `collect_signal_graph_snapshot`

- API：`public`

```gdscript
func collect_signal_graph_snapshot(root: Node = null, options: Dictionary = {}) -> Dictionary:
```

采集只读信号连接图快照。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 可选根节点；为空时优先使用当前场景，再回退到 Viewport root。 |
| `options` | 可选参数，支持 include_internal、persistent_only、include_empty_signals、include_external_targets、include_index。 |

返回：信号图快照字典。

结构：

- `options`: Dictionary，支持 include_internal、persistent_only、include_empty_signals、include_external_targets、include_index、root_path、prefer_current_scene。
- `return`: Dictionary，包含 ok、root_path、node_count、signal_count、connection_count、nodes、signals、connections，可选 index。
