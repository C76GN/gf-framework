# GFConsoleUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_console_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

运行时开发者控制台。 提供命令注册、解析与执行能力，并在初始化时构建覆盖全屏的调试 GUI。 默认通过快捷键呼出，同时会消费 `GFLogUtility` 的日志信号进行彩色输出。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`CommandTier`](#member-gfconsoleutility-enums-commandtier) | `enum CommandTier` |
| 常量 | [`DANGER_CONFIRMATION_ARGUMENT`](#member-gfconsoleutility-constants-danger_confirmation_argument) | `const DANGER_CONFIRMATION_ARGUMENT: String = "--confirm"` |
| 属性 | [`toggle_key`](#member-gfconsoleutility-properties-toggle_key) | `var toggle_key: Key = KEY_F1` |
| 属性 | [`max_output_lines`](#member-gfconsoleutility-properties-max_output_lines) | `var max_output_lines: int = 1000:` |
| 属性 | [`max_history_size`](#member-gfconsoleutility-properties-max_history_size) | `var max_history_size: int = 100:` |
| 属性 | [`background_alpha`](#member-gfconsoleutility-properties-background_alpha) | `var background_alpha: float = 0.85:` |
| 属性 | [`windowed`](#member-gfconsoleutility-properties-windowed) | `var windowed: bool = false:` |
| 属性 | [`initial_window_size_ratio`](#member-gfconsoleutility-properties-initial_window_size_ratio) | `var initial_window_size_ratio: Vector2 = Vector2(0.72, 0.55):` |
| 属性 | [`minimum_window_size`](#member-gfconsoleutility-properties-minimum_window_size) | `var minimum_window_size: Vector2 = Vector2(360.0, 220.0):` |
| 属性 | [`keep_topmost`](#member-gfconsoleutility-properties-keep_topmost) | `var keep_topmost: bool = true:` |
| 属性 | [`debug_only`](#member-gfconsoleutility-properties-debug_only) | `var debug_only: bool = true` |
| 属性 | [`max_command_tier`](#member-gfconsoleutility-properties-max_command_tier) | `var max_command_tier: CommandTier = CommandTier.CONTROL` |
| 属性 | [`require_danger_confirmation`](#member-gfconsoleutility-properties-require_danger_confirmation) | `var require_danger_confirmation: bool = true` |
| 方法 | [`init`](#member-gfconsoleutility-methods-init) | `func init() -> void:` |
| 方法 | [`ready`](#member-gfconsoleutility-methods-ready) | `func ready() -> void:` |
| 方法 | [`dispose`](#member-gfconsoleutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`register_command`](#member-gfconsoleutility-methods-register_command) | `func register_command( owner: Object, cmd_name: String, callback: Callable, description: String, metadata: Dictionary = {} ) -> GFLifetimeSubscription:` |
| 方法 | [`register_command_definition`](#member-gfconsoleutility-methods-register_command_definition) | `func register_command_definition( owner: Object, definition: GFConsoleCommandDefinition, callback: Callable ) -> GFLifetimeSubscription:` |
| 方法 | [`has_command`](#member-gfconsoleutility-methods-has_command) | `func has_command(cmd_name: String) -> bool:` |
| 方法 | [`get_command_names`](#member-gfconsoleutility-methods-get_command_names) | `func get_command_names() -> PackedStringArray:` |
| 方法 | [`get_command_catalog`](#member-gfconsoleutility-methods-get_command_catalog) | `func get_command_catalog() -> Dictionary:` |
| 方法 | [`suggest_commands`](#member-gfconsoleutility-methods-suggest_commands) | `func suggest_commands(prefix: String) -> PackedStringArray:` |
| 方法 | [`suggest_command_arguments`](#member-gfconsoleutility-methods-suggest_command_arguments) | `func suggest_command_arguments(raw_input: String) -> PackedStringArray:` |
| 方法 | [`suggest_similar_commands`](#member-gfconsoleutility-methods-suggest_similar_commands) | `func suggest_similar_commands(cmd_name: String, limit: int = 3, threshold: float = 0.5) -> PackedStringArray:` |
| 方法 | [`execute_command`](#member-gfconsoleutility-methods-execute_command) | `func execute_command(raw_input: String) -> bool:` |
| 方法 | [`set_console_visible`](#member-gfconsoleutility-methods-set_console_visible) | `func set_console_visible(console_visible: bool) -> void:` |
| 方法 | [`is_console_visible`](#member-gfconsoleutility-methods-is_console_visible) | `func is_console_visible() -> bool:` |
| 方法 | [`append_output_line`](#member-gfconsoleutility-methods-append_output_line) | `func append_output_line(bbcode_line: String) -> void:` |
| 方法 | [`append_output_lines`](#member-gfconsoleutility-methods-append_output_lines) | `func append_output_lines(bbcode_lines: PackedStringArray) -> void:` |
| 方法 | [`clear_output`](#member-gfconsoleutility-methods-clear_output) | `func clear_output() -> void:` |
| 方法 | [`flush_output`](#member-gfconsoleutility-methods-flush_output) | `func flush_output() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfconsoleutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 枚举

<a id="member-gfconsoleutility-enums-commandtier"></a>

### `CommandTier`

- API：`public`

```gdscript
enum CommandTier {
	## 只读观察类命令。
	OBSERVE,
	## 修改调试输入、过滤器或临时可视化状态的命令。
	INPUT,
	## 会改变运行时状态的控制类命令。
	CONTROL,
	## 删档、跳关、重连等高风险命令。
	DANGER,
}
```

控制台命令风险等级。

## 常量

<a id="member-gfconsoleutility-constants-danger_confirmation_argument"></a>

### `DANGER_CONFIRMATION_ARGUMENT`

- API：`public`

```gdscript
const DANGER_CONFIRMATION_ARGUMENT: String = "--confirm"
```

DANGER 命令的确认参数。

## 属性

<a id="member-gfconsoleutility-properties-toggle_key"></a>

### `toggle_key`

- API：`public`

```gdscript
var toggle_key: Key = KEY_F1
```

呼出或隐藏控制台的快捷键；默认为 `KEY_F1`。

<a id="member-gfconsoleutility-properties-max_output_lines"></a>

### `max_output_lines`

- API：`public`

```gdscript
var max_output_lines: int = 1000:
```

控制台最多保留的输出行数，避免高频日志无限增长。

<a id="member-gfconsoleutility-properties-max_history_size"></a>

### `max_history_size`

- API：`public`

```gdscript
var max_history_size: int = 100:
```

控制台最多保留的历史命令数量。

<a id="member-gfconsoleutility-properties-background_alpha"></a>

### `background_alpha`

- API：`public`

```gdscript
var background_alpha: float = 0.85:
```

控制台背景透明度，范围 0 到 1。

<a id="member-gfconsoleutility-properties-windowed"></a>

### `windowed`

- API：`public`

```gdscript
var windowed: bool = false:
```

是否使用可拖拽、可缩放的窗口模式。默认 false 保持全屏覆盖。

<a id="member-gfconsoleutility-properties-initial_window_size_ratio"></a>

### `initial_window_size_ratio`

- API：`public`

```gdscript
var initial_window_size_ratio: Vector2 = Vector2(0.72, 0.55):
```

窗口模式初始尺寸相对视口比例。

<a id="member-gfconsoleutility-properties-minimum_window_size"></a>

### `minimum_window_size`

- API：`public`

```gdscript
var minimum_window_size: Vector2 = Vector2(360.0, 220.0):
```

窗口模式最小尺寸。

<a id="member-gfconsoleutility-properties-keep_topmost"></a>

### `keep_topmost`

- API：`public`

```gdscript
var keep_topmost: bool = true:
```

是否把控制台放在较高 CanvasLayer 层级。

<a id="member-gfconsoleutility-properties-debug_only"></a>

### `debug_only`

- API：`public`

```gdscript
var debug_only: bool = true
```

是否只在 debug 构建中创建控制台 GUI。发布构建需要显式关闭此项才会创建控制台。

<a id="member-gfconsoleutility-properties-max_command_tier"></a>

### `max_command_tier`

- API：`public`

```gdscript
var max_command_tier: CommandTier = CommandTier.CONTROL
```

允许执行的最高命令风险等级。

<a id="member-gfconsoleutility-properties-require_danger_confirmation"></a>

### `require_danger_confirmation`

- API：`public`

```gdscript
var require_danger_confirmation: bool = true
```

执行 DANGER 命令时是否要求传入 `--confirm` 参数。

## 方法

<a id="member-gfconsoleutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化控制台命令表和运行时 GUI。

<a id="member-gfconsoleutility-methods-ready"></a>

### `ready`

- API：`public`

```gdscript
func ready() -> void:
```

连接日志工具信号。

<a id="member-gfconsoleutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放 GUI 并断开日志信号。

<a id="member-gfconsoleutility-methods-register_command"></a>

### `register_command`

- API：`public`
- 首次版本：`3.0.0`

```gdscript
func register_command( owner: Object, cmd_name: String, callback: Callable, description: String, metadata: Dictionary = {} ) -> GFLifetimeSubscription:
```

注册控制台命令。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 命令生命周期 owner。 |
| `cmd_name` | 指令名称。 |
| `callback` | 指令回调，签名为 \`func(args: PackedStringArray) -> void\`。 |
| `description` | 指令说明文本。 |
| `metadata` | 项目自定义元数据。 |

返回：owner-bound 注册句柄；注册失败时返回 inactive token。

结构：

- `metadata`: Dictionary，支持 tier 等项目自定义命令元数据。

<a id="member-gfconsoleutility-methods-register_command_definition"></a>

### `register_command_definition`

- API：`public`
- 首次版本：`3.0.0`

```gdscript
func register_command_definition( owner: Object, definition: GFConsoleCommandDefinition, callback: Callable ) -> GFLifetimeSubscription:
```

注册资源化控制台命令。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 命令生命周期 owner。 |
| `definition` | 命令资源定义。 |
| `callback` | 指令回调，签名为 \`func(args: PackedStringArray) -> void\`。 |

返回：owner-bound 注册句柄；注册失败时返回 inactive token。

<a id="member-gfconsoleutility-methods-has_command"></a>

### `has_command`

- API：`public`

```gdscript
func has_command(cmd_name: String) -> bool:
```

检查控制台命令是否已注册。

参数：

| 名称 | 说明 |
|---|---|
| `cmd_name` | 指令名称。 |

返回：已注册返回 true。

<a id="member-gfconsoleutility-methods-get_command_names"></a>

### `get_command_names`

- API：`public`

```gdscript
func get_command_names() -> PackedStringArray:
```

获取当前已注册命令名称。

返回：排序后的命令名称数组。

<a id="member-gfconsoleutility-methods-get_command_catalog"></a>

### `get_command_catalog`

- API：`public`

```gdscript
func get_command_catalog() -> Dictionary:
```

获取控制台命令目录。

返回：命令元数据字典。

结构：

- `return`: Dictionary[String, Dictionary]，每个值包含 description、metadata 和 tier。

<a id="member-gfconsoleutility-methods-suggest_commands"></a>

### `suggest_commands`

- API：`public`

```gdscript
func suggest_commands(prefix: String) -> PackedStringArray:
```

根据前缀获取命令补全候选。

参数：

| 名称 | 说明 |
|---|---|
| `prefix` | 命令名前缀。 |

返回：排序后的候选命令名数组。

<a id="member-gfconsoleutility-methods-suggest_command_arguments"></a>

### `suggest_command_arguments`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func suggest_command_arguments(raw_input: String) -> PackedStringArray:
```

根据当前输入获取命令参数补全候选。 命令通过 metadata.argument_suggester 或 GFConsoleCommandDefinition.argument_suggester 提供候选。回调接收的上下文字典包含 command_name、args、argument_index、 prefix 和 raw_input。GF 会按当前参数前缀做一次稳定过滤。

参数：

| 名称 | 说明 |
|---|---|
| `raw_input` | 控制台当前输入。 |

返回：排序后的参数候选。

<a id="member-gfconsoleutility-methods-suggest_similar_commands"></a>

### `suggest_similar_commands`

- API：`public`

```gdscript
func suggest_similar_commands(cmd_name: String, limit: int = 3, threshold: float = 0.5) -> PackedStringArray:
```

根据字符串相似度获取可能的命令名，用于未知命令诊断。

参数：

| 名称 | 说明 |
|---|---|
| `cmd_name` | 用户输入的命令名。 |
| `limit` | 最多返回的候选数量。 |
| `threshold` | 最低相似度，范围 0 到 1。 |

返回：按相似度降序排列的候选命令名。

<a id="member-gfconsoleutility-methods-execute_command"></a>

### `execute_command`

- API：`public`

```gdscript
func execute_command(raw_input: String) -> bool:
```

解析并执行一条原始输入。

参数：

| 名称 | 说明 |
|---|---|
| `raw_input` | 用户输入的完整字符串。 |

返回：找到并成功执行命令时返回 `true`。

<a id="member-gfconsoleutility-methods-set_console_visible"></a>

### `set_console_visible`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func set_console_visible(console_visible: bool) -> void:
```

设置控制台 GUI 可见性。GUI 未创建或已释放时不会执行任何操作。

参数：

| 名称 | 说明 |
|---|---|
| `console_visible` | 为 true 时显示控制台 GUI。 |

<a id="member-gfconsoleutility-methods-is_console_visible"></a>

### `is_console_visible`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_console_visible() -> bool:
```

检查控制台 GUI 是否可见。GUI 未创建或已释放时返回 false。

返回：控制台 GUI 可见时返回 true。

<a id="member-gfconsoleutility-methods-append_output_line"></a>

### `append_output_line`

- API：`public`

```gdscript
func append_output_line(bbcode_line: String) -> void:
```

向控制台输出追加一行 BBCode 文本。

参数：

| 名称 | 说明 |
|---|---|
| `bbcode_line` | 要追加的一行 BBCode 文本。 |

<a id="member-gfconsoleutility-methods-append_output_lines"></a>

### `append_output_lines`

- API：`public`

```gdscript
func append_output_lines(bbcode_lines: PackedStringArray) -> void:
```

向控制台输出追加多行 BBCode 文本。

参数：

| 名称 | 说明 |
|---|---|
| `bbcode_lines` | 要追加的 BBCode 文本行列表。 |

<a id="member-gfconsoleutility-methods-clear_output"></a>

### `clear_output`

- API：`public`

```gdscript
func clear_output() -> void:
```

清空控制台输出。

<a id="member-gfconsoleutility-methods-flush_output"></a>

### `flush_output`

- API：`public`

```gdscript
func flush_output() -> void:
```

立即刷新待追加的控制台输出。

<a id="member-gfconsoleutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取控制台调试快照。

返回：控制台命令、GUI 和配置状态。

结构：

- `return`: Dictionary，包含 command_count、command_names、command_catalog、has_console_gui、gui、配置字段。
