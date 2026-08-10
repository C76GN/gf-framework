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
| 属性 | [`command_name`](#member-gfeditorcommand-properties-command_name) | `var command_name: String:` |
| 属性 | [`metadata`](#member-gfeditorcommand-properties-metadata) | `var metadata: Dictionary:` |
| 方法 | [`execute`](#member-gfeditorcommand-methods-execute) | `func execute() -> Error:` |
| 方法 | [`revert`](#member-gfeditorcommand-methods-revert) | `func revert() -> Error:` |
| 方法 | [`add_to_undo_manager`](#member-gfeditorcommand-methods-add_to_undo_manager) | `func add_to_undo_manager(undo_manager: Object, execute_immediately: bool = true) -> Error:` |
| 方法 | [`get_last_execute_error`](#member-gfeditorcommand-methods-get_last_execute_error) | `func get_last_execute_error() -> Error:` |
| 方法 | [`get_last_revert_error`](#member-gfeditorcommand-methods-get_last_revert_error) | `func get_last_revert_error() -> Error:` |
| 方法 | [`is_executed`](#member-gfeditorcommand-methods-is_executed) | `func is_executed() -> bool:` |
| 方法 | [`is_sealed`](#member-gfeditorcommand-methods-is_sealed) | `func is_sealed() -> bool:` |
| 方法 | [`can_execute`](#member-gfeditorcommand-methods-can_execute) | `func can_execute() -> bool:` |
| 方法 | [`can_revert_before_execute`](#member-gfeditorcommand-methods-can_revert_before_execute) | `func can_revert_before_execute() -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfeditorcommand-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`_do_it`](#member-gfeditorcommand-methods-_do_it) | `func _do_it() -> Error:` |
| 方法 | [`_undo_it`](#member-gfeditorcommand-methods-_undo_it) | `func _undo_it() -> Error:` |
| 方法 | [`_get_undo_context`](#member-gfeditorcommand-methods-_get_undo_context) | `func _get_undo_context() -> Object:` |
| 方法 | [`_get_undo_targets`](#member-gfeditorcommand-methods-_get_undo_targets) | `func _get_undo_targets() -> Array[Object]:` |
| 方法 | [`_can_change_configuration`](#member-gfeditorcommand-methods-_can_change_configuration) | `func _can_change_configuration(field_name: String) -> bool:` |
| 方法 | [`_seal_configuration_for_execution`](#member-gfeditorcommand-methods-_seal_configuration_for_execution) | `func _seal_configuration_for_execution() -> void:` |

## 属性

<a id="member-gfeditorcommand-properties-command_name"></a>

### `command_name`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var command_name: String:
```

命令显示名称，会作为 UndoRedo action 名称使用。

<a id="member-gfeditorcommand-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var metadata: Dictionary:
```

调用方可附加的上下文数据。

结构：

- `metadata`: Dictionary for caller-defined command metadata.

## 方法

<a id="member-gfeditorcommand-methods-execute"></a>

### `execute`

- API：`public`
- 首次版本：`3.17.0`

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
- 首次版本：`3.17.0`

```gdscript
func add_to_undo_manager(undo_manager: Object, execute_immediately: bool = true) -> Error:
```

将命令写入 Godot 编辑器 UndoRedo 管理器。 返回值只表示 action 已成功写入并提交给 UndoRedo 管理器；Godot 原生 `EditorUndoRedoManager` 不会把 do/undo 回调的错误码回传给提交方。需要诊断 回调执行结果时，读取命令自身的最近执行/撤销错误或调试快照。

参数：

| 名称 | 说明 |
|---|---|
| `undo_manager` | EditorUndoRedoManager 或兼容对象。 |
| `execute_immediately` | 提交 action 时是否立即执行 do 方法。 |

返回：Godot 错误码。

<a id="member-gfeditorcommand-methods-get_last_execute_error"></a>

### `get_last_execute_error`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_last_execute_error() -> Error:
```

获取最近一次 execute() 的错误码。

返回：最近 execute() 返回的 Godot 错误码。

<a id="member-gfeditorcommand-methods-get_last_revert_error"></a>

### `get_last_revert_error`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_last_revert_error() -> Error:
```

获取最近一次 revert() 的错误码。

返回：最近 revert() 返回的 Godot 错误码。

<a id="member-gfeditorcommand-methods-is_executed"></a>

### `is_executed`

- API：`public`

```gdscript
func is_executed() -> bool:
```

当前命令是否已执行。

返回：已执行时返回 true。

<a id="member-gfeditorcommand-methods-is_sealed"></a>

### `is_sealed`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_sealed() -> bool:
```

返回命令配置是否已经冻结。 已执行或写入 UndoRedo 的命令实例代表一次编辑动作，冻结后不应再修改配置字段。

返回：配置已冻结时返回 true。

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

<a id="member-gfeditorcommand-methods-_do_it"></a>

### `_do_it`

- API：`protected`

```gdscript
func _do_it() -> Error:
```

执行具体编辑器操作，供子类重写。

返回：Godot 错误码。

<a id="member-gfeditorcommand-methods-_undo_it"></a>

### `_undo_it`

- API：`protected`

```gdscript
func _undo_it() -> Error:
```

撤销具体编辑器操作，供子类重写。

返回：Godot 错误码。

<a id="member-gfeditorcommand-methods-_get_undo_context"></a>

### `_get_undo_context`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _get_undo_context() -> Object:
```

返回用于 EditorUndoRedoManager 历史路由的实际变更上下文。 修改 Node 或 Resource 的命令应返回被修改对象，而不是命令自身。没有明确目标、 或使用普通 UndoRedo 兼容对象时可返回 null。

返回：用于选择 UndoRedo history 的对象。

<a id="member-gfeditorcommand-methods-_get_undo_targets"></a>

### `_get_undo_targets`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _get_undo_targets() -> Array[Object]:
```

返回命令会修改的全部对象，用于拒绝跨 UndoRedo history 的混合事务。 默认只包含 `_get_undo_context()`。多目标命令应返回所有实际目标。

返回：命令的全部变更目标。

<a id="member-gfeditorcommand-methods-_can_change_configuration"></a>

### `_can_change_configuration`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _can_change_configuration(field_name: String) -> bool:
```

返回指定配置字段当前是否可修改。

参数：

| 名称 | 说明 |
|---|---|
| `field_name` | 配置字段名。 |

返回：配置未冻结时返回 true；已冻结时报告错误并返回 false。

<a id="member-gfeditorcommand-methods-_seal_configuration_for_execution"></a>

### `_seal_configuration_for_execution`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _seal_configuration_for_execution() -> void:
```

冻结命令配置。 会在命令成功执行或注册到 UndoRedo 后由基类调用。可能发生部分写入的事务子类 应在第一笔实际写入前主动调用，确保失败恢复仍使用不可变配置与首次快照。
