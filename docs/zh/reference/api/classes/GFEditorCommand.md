# GFEditorCommand

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_editor_command.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

可撤销编辑器操作的通用基类。 用于把编辑器 UI、快捷键或交互工具产生的修改收敛成可执行、可撤销的命令。 命令只描述操作协议，不绑定具体资源、节点类型或业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`command_name`](#member-gfeditorcommand-properties-command_name) | `var command_name: String = "GF Editor Command"` |
| 属性 | [`metadata`](#member-gfeditorcommand-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`execute`](#member-gfeditorcommand-methods-execute) | `func execute() -> Error:` |
| 方法 | [`revert`](#member-gfeditorcommand-methods-revert) | `func revert() -> Error:` |
| 方法 | [`add_to_undo_manager`](#member-gfeditorcommand-methods-add_to_undo_manager) | `func add_to_undo_manager(undo_manager: Object, execute_immediately: bool = true) -> Error:` |
| 方法 | [`is_executed`](#member-gfeditorcommand-methods-is_executed) | `func is_executed() -> bool:` |
| 方法 | [`can_execute`](#member-gfeditorcommand-methods-can_execute) | `func can_execute() -> bool:` |
| 方法 | [`can_revert_before_execute`](#member-gfeditorcommand-methods-can_revert_before_execute) | `func can_revert_before_execute() -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfeditorcommand-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfeditorcommand-properties-command_name"></a>

### `command_name`

- API：`public`

```gdscript
var command_name: String = "GF Editor Command"
```

命令显示名称，会作为 UndoRedo action 名称使用。

<a id="member-gfeditorcommand-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

调用方可附加的上下文数据。

结构：

- `metadata`: Dictionary for caller-defined command metadata.

## 方法

<a id="member-gfeditorcommand-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute() -> Error:
```

执行命令。

返回：Godot 错误码。

<a id="member-gfeditorcommand-methods-revert"></a>

### `revert`

- API：`public`

```gdscript
func revert() -> Error:
```

撤销命令。

返回：Godot 错误码。

<a id="member-gfeditorcommand-methods-add_to_undo_manager"></a>

### `add_to_undo_manager`

- API：`public`

```gdscript
func add_to_undo_manager(undo_manager: Object, execute_immediately: bool = true) -> Error:
```

将命令写入 Godot 编辑器 UndoRedo 管理器。

参数：

| 名称 | 说明 |
|---|---|
| `undo_manager` | EditorUndoRedoManager 或兼容对象。 |
| `execute_immediately` | 提交 action 时是否立即执行 do 方法。 |

返回：Godot 错误码。

<a id="member-gfeditorcommand-methods-is_executed"></a>

### `is_executed`

- API：`public`

```gdscript
func is_executed() -> bool:
```

当前命令是否已执行。

返回：已执行时返回 true。

<a id="member-gfeditorcommand-methods-can_execute"></a>

### `can_execute`

- API：`public`

```gdscript
func can_execute() -> bool:
```

命令当前是否允许执行。

返回：允许执行时返回 true。

<a id="member-gfeditorcommand-methods-can_revert_before_execute"></a>

### `can_revert_before_execute`

- API：`public`

```gdscript
func can_revert_before_execute() -> bool:
```

未执行时是否仍允许调用 revert()。

返回：未执行时允许撤销返回 true。

<a id="member-gfeditorcommand-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary containing command_name, executed, and metadata.
