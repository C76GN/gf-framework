# GFRuntimeDebuggerTab

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/editor/gf_runtime_debugger_tab.gd`
- 模块：`Standard`
- 继承：`Control`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`6.0.0`

GF 运行时调试会话页。 通过 Godot EditorDebuggerSession 向正在运行的游戏请求 GFDiagnosticsUtility 快照， 并以只读树和 JSON 详情展示返回数据。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`setup_session`](#member-gfruntimedebuggertab-methods-setup_session) | `func setup_session(session: EditorDebuggerSession, session_id: int) -> void:` |
| 方法 | [`request_snapshot`](#member-gfruntimedebuggertab-methods-request_snapshot) | `func request_snapshot() -> bool:` |
| 方法 | [`request_catalog`](#member-gfruntimedebuggertab-methods-request_catalog) | `func request_catalog() -> bool:` |
| 方法 | [`execute_command`](#member-gfruntimedebuggertab-methods-execute_command) | `func execute_command(command_name: StringName, args: Dictionary = {}) -> bool:` |
| 方法 | [`handle_snapshot`](#member-gfruntimedebuggertab-methods-handle_snapshot) | `func handle_snapshot(payload: Dictionary) -> void:` |
| 方法 | [`handle_catalog`](#member-gfruntimedebuggertab-methods-handle_catalog) | `func handle_catalog(payload: Dictionary) -> void:` |
| 方法 | [`handle_command_result`](#member-gfruntimedebuggertab-methods-handle_command_result) | `func handle_command_result(command_name: StringName, payload: Dictionary) -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfruntimedebuggertab-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 方法

<a id="member-gfruntimedebuggertab-methods-setup_session"></a>

### `setup_session`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func setup_session(session: EditorDebuggerSession, session_id: int) -> void:
```

绑定调试会话。

参数：

| 名称 | 说明 |
|---|---|
| `session` | Godot 调试会话。 |
| `session_id` | 会话 ID。 |

<a id="member-gfruntimedebuggertab-methods-request_snapshot"></a>

### `request_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func request_snapshot() -> bool:
```

请求运行时诊断快照。

返回：消息是否已发送。

<a id="member-gfruntimedebuggertab-methods-request_catalog"></a>

### `request_catalog`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func request_catalog() -> bool:
```

请求运行时诊断目录。

返回：消息是否已发送。

<a id="member-gfruntimedebuggertab-methods-execute_command"></a>

### `execute_command`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func execute_command(command_name: StringName, args: Dictionary = {}) -> bool:
```

执行运行时诊断命令。

参数：

| 名称 | 说明 |
|---|---|
| `command_name` | 命令名。 |
| `args` | 命令参数。 |

返回：消息是否已发送。

结构：

- `args`: Dictionary diagnostic command arguments.

<a id="member-gfruntimedebuggertab-methods-handle_snapshot"></a>

### `handle_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func handle_snapshot(payload: Dictionary) -> void:
```

处理运行时快照 payload。

参数：

| 名称 | 说明 |
|---|---|
| `payload` | 运行时返回的快照。 |

结构：

- `payload`: Dictionary snapshot payload.

<a id="member-gfruntimedebuggertab-methods-handle_catalog"></a>

### `handle_catalog`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func handle_catalog(payload: Dictionary) -> void:
```

处理运行时目录 payload。

参数：

| 名称 | 说明 |
|---|---|
| `payload` | 运行时返回的目录。 |

结构：

- `payload`: Dictionary catalog payload.

<a id="member-gfruntimedebuggertab-methods-handle_command_result"></a>

### `handle_command_result`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func handle_command_result(command_name: StringName, payload: Dictionary) -> void:
```

处理诊断命令结果。

参数：

| 名称 | 说明 |
|---|---|
| `command_name` | 命令名。 |
| `payload` | 命令结果。 |

结构：

- `payload`: Dictionary command result payload.

<a id="member-gfruntimedebuggertab-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取页面调试快照。

返回：页面调试快照。

结构：

- `return`: Dictionary containing session_id, last_snapshot, last_catalog, last_command_result, and ui fields.
