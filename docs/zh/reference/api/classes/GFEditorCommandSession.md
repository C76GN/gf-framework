# GFEditorCommandSession

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_editor_command_session.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`6.0.0`

编辑器命令会话。 为编辑器工具、Dock 或快捷键入口提供统一的命令预览、提交、撤销和结果字典格式。 会话只管理通用命令生命周期，不绑定具体资源、节点类型或项目业务。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`session_id`](#member-gfeditorcommandsession-properties-session_id) | `var session_id: StringName = &""` |
| 属性 | [`label`](#member-gfeditorcommandsession-properties-label) | `var label: String = ""` |
| 属性 | [`metadata`](#member-gfeditorcommandsession-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfeditorcommandsession-methods-configure) | `func configure( p_session_id: StringName, p_label: String = "", p_metadata: Dictionary = {} ) -> GFEditorCommandSession:` |
| 方法 | [`preview_command`](#member-gfeditorcommandsession-methods-preview_command) | `func preview_command(command: GFEditorCommandBase, context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`commit_command`](#member-gfeditorcommandsession-methods-commit_command) | `func commit_command( command: GFEditorCommandBase, context: GFEditorToolContextBase = null, use_undo: bool = true ) -> Dictionary:` |
| 方法 | [`revert_last`](#member-gfeditorcommandsession-methods-revert_last) | `func revert_last() -> Dictionary:` |
| 方法 | [`clear_history`](#member-gfeditorcommandsession-methods-clear_history) | `func clear_history() -> void:` |
| 方法 | [`get_history_count`](#member-gfeditorcommandsession-methods-get_history_count) | `func get_history_count() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfeditorcommandsession-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfeditorcommandsession-properties-session_id"></a>

### `session_id`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var session_id: StringName = &""
```

会话稳定标识。

<a id="member-gfeditorcommandsession-properties-label"></a>

### `label`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var label: String = ""
```

会话显示名称。

<a id="member-gfeditorcommandsession-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方附加元数据。

结构：

- `metadata`: Dictionary for caller-defined editor command session metadata.

## 方法

<a id="member-gfeditorcommandsession-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func configure( p_session_id: StringName, p_label: String = "", p_metadata: Dictionary = {} ) -> GFEditorCommandSession:
```

配置会话。

参数：

| 名称 | 说明 |
|---|---|
| `p_session_id` | 会话稳定标识。 |
| `p_label` | 会话显示名称。 |
| `p_metadata` | 调用方元数据。 |

返回：当前会话。

结构：

- `p_metadata`: Dictionary copied into metadata.

<a id="member-gfeditorcommandsession-methods-preview_command"></a>

### `preview_command`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func preview_command(command: GFEditorCommandBase, context: Dictionary = {}) -> Dictionary:
```

预览命令可执行性，不修改项目状态。

参数：

| 名称 | 说明 |
|---|---|
| `command` | 待预览命令。 |
| `context` | 调用方上下文字典，会复制到结果中便于诊断。 |

返回：预览结果字典。

结构：

- `context`: Dictionary command preview context.
- `return`: Dictionary with ok, status, command_name, executed, history_count, context, and metadata.

<a id="member-gfeditorcommandsession-methods-commit_command"></a>

### `commit_command`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func commit_command( command: GFEditorCommandBase, context: GFEditorToolContextBase = null, use_undo: bool = true ) -> Dictionary:
```

提交命令。存在上下文时可接入 UndoRedo，否则直接执行。

参数：

| 名称 | 说明 |
|---|---|
| `command` | 待提交命令。 |
| `context` | 可选编辑器工具上下文。 |
| `use_undo` | 为 true 且 context 拥有 undo_manager 时写入 UndoRedo。 |

返回：提交结果字典。

结构：

- `return`: Dictionary with ok, status, error, command_name, executed, history_count, and metadata.

<a id="member-gfeditorcommandsession-methods-revert_last"></a>

### `revert_last`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func revert_last() -> Dictionary:
```

撤销最近一次提交的命令。

返回：撤销结果字典。

结构：

- `return`: Dictionary with ok, status, error, command_name, executed, history_count, and metadata.

<a id="member-gfeditorcommandsession-methods-clear_history"></a>

### `clear_history`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func clear_history() -> void:
```

清空会话历史，不调用撤销。

<a id="member-gfeditorcommandsession-methods-get_history_count"></a>

### `get_history_count`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_history_count() -> int:
```

获取命令历史数量。

返回：已提交命令数量。

<a id="member-gfeditorcommandsession-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary containing session_id, label, history_count, command_names, and metadata.
