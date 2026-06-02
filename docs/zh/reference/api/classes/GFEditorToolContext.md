# GFEditorToolContext

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_editor_tool_context.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

编辑器交互工具上下文。 用于在工具、动作和命令之间传递 EditorPlugin、UndoRedo、选中节点和额外元数据。 该对象只保存通用编辑器上下文，不假设具体工具会编辑哪类资源。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`plugin`](#member-gfeditortoolcontext-properties-plugin) | `var plugin: EditorPlugin = null` |
| 属性 | [`undo_manager`](#member-gfeditortoolcontext-properties-undo_manager) | `var undo_manager: Object = null` |
| 属性 | [`edited_scene_root`](#member-gfeditortoolcontext-properties-edited_scene_root) | `var edited_scene_root: Node = null` |
| 属性 | [`selected_nodes`](#member-gfeditortoolcontext-properties-selected_nodes) | `var selected_nodes: Array[Node] = []` |
| 属性 | [`metadata`](#member-gfeditortoolcontext-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`from_plugin`](#member-gfeditortoolcontext-methods-from_plugin) | `static func from_plugin(editor_plugin: EditorPlugin, extra_metadata: Dictionary = {}) -> GFEditorToolContext:` |
| 方法 | [`commit_command`](#member-gfeditortoolcontext-methods-commit_command) | `func commit_command(command: GFEditorCommandBase, use_undo: bool = true) -> Error:` |
| 方法 | [`get_selected_nodes`](#member-gfeditortoolcontext-methods-get_selected_nodes) | `func get_selected_nodes() -> Array[Node]:` |
| 方法 | [`to_dictionary`](#member-gfeditortoolcontext-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |

## 属性

<a id="member-gfeditortoolcontext-properties-plugin"></a>

### `plugin`

- API：`public`

```gdscript
var plugin: EditorPlugin = null
```

当前 EditorPlugin。

<a id="member-gfeditortoolcontext-properties-undo_manager"></a>

### `undo_manager`

- API：`public`

```gdscript
var undo_manager: Object = null
```

UndoRedo 管理器或兼容对象。

<a id="member-gfeditortoolcontext-properties-edited_scene_root"></a>

### `edited_scene_root`

- API：`public`

```gdscript
var edited_scene_root: Node = null
```

当前编辑场景根节点。

<a id="member-gfeditortoolcontext-properties-selected_nodes"></a>

### `selected_nodes`

- API：`public`

```gdscript
var selected_nodes: Array[Node] = []
```

当前选中节点快照。

<a id="member-gfeditortoolcontext-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

调用方附加元数据。

结构：

- `metadata`: Dictionary for caller-defined editor tool context metadata.

## 方法

<a id="member-gfeditortoolcontext-methods-from_plugin"></a>

### `from_plugin`

- API：`public`

```gdscript
static func from_plugin(editor_plugin: EditorPlugin, extra_metadata: Dictionary = {}) -> GFEditorToolContext:
```

从 EditorPlugin 构建上下文。

参数：

| 名称 | 说明 |
|---|---|
| `editor_plugin` | 当前编辑器插件。 |
| `extra_metadata` | 额外元数据。 |

返回：新上下文。

结构：

- `extra_metadata`: Dictionary copied into metadata.

<a id="member-gfeditortoolcontext-methods-commit_command"></a>

### `commit_command`

- API：`public`

```gdscript
func commit_command(command: GFEditorCommandBase, use_undo: bool = true) -> Error:
```

提交一个命令。

参数：

| 名称 | 说明 |
|---|---|
| `command` | 需要执行或写入 UndoRedo 的命令。 |
| `use_undo` | 为 true 且存在 undo_manager 时写入 UndoRedo。 |

返回：Godot 错误码。

<a id="member-gfeditortoolcontext-methods-get_selected_nodes"></a>

### `get_selected_nodes`

- API：`public`

```gdscript
func get_selected_nodes() -> Array[Node]:
```

获取选中节点副本。

返回：选中节点数组。

<a id="member-gfeditortoolcontext-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

获取上下文字典。

返回：普通字典快照。

结构：

- `return`: Dictionary containing plugin, undo_manager, edited_scene_root, selected_nodes, and metadata.
