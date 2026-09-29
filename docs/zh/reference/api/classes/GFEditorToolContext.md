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
| 方法 | [`get_workspace_tasks`](#member-gfeditortoolcontext-methods-get_workspace_tasks) | `func get_workspace_tasks() -> Array[Dictionary]:` |
| 方法 | [`request_workspace_task`](#member-gfeditortoolcontext-methods-request_workspace_task) | `func request_workspace_task(source_id: String) -> Dictionary:` |
| 方法 | [`get_resource_actions`](#member-gfeditortoolcontext-methods-get_resource_actions) | `func get_resource_actions(paths: PackedStringArray) -> Array[Dictionary]:` |
| 方法 | [`request_resource_action`](#member-gfeditortoolcontext-methods-request_resource_action) | `func request_resource_action(action_id: String, paths: PackedStringArray) -> Dictionary:` |
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

<a id="member-gfeditortoolcontext-methods-get_workspace_tasks"></a>

### `get_workspace_tasks`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_workspace_tasks() -> Array[Dictionary]:
```

获取当前任务入口的纯数据快照；不会创建工具页面。

返回：任务记录副本。

结构：

- `return`: Array of Dictionary with source_id, title, description, group, keywords, available, and reason.

<a id="member-gfeditortoolcontext-methods-request_workspace_task"></a>

### `request_workspace_task`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func request_workspace_task(source_id: String) -> Dictionary:
```

请求打开一项任务；不可用的扩展入口转到扩展选择页面。

参数：

| 名称 | 说明 |
|---|---|
| `source_id` | 任务的稳定来源标识。 |

返回：路由结果。

结构：

- `return`: Dictionary with ok: bool and message: String, plus optional error_code, status, action_id, replaced and metadata from routing. A same-generation receiver response adds receiver_report: Dictionary (deep copy retaining receiver status, reason, data and other fields) and registry_status; a nonempty receiver text status becomes status, and message falls back through receiver message, reason and status. Registry ok, error_code, action_id, replaced and metadata remain authoritative; unavailable, invalid or revoked routes retain their registry failure without a receiver report.

<a id="member-gfeditortoolcontext-methods-get_resource_actions"></a>

### `get_resource_actions`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_resource_actions(paths: PackedStringArray) -> Array[Dictionary]:
```

查询当前资源选择可交给哪些工具；不会加载资源或创建页面。

参数：

| 名称 | 说明 |
|---|---|
| `paths` | 当前资源路径快照。 |

返回：资源动作记录副本。

结构：

- `return`: Array of Dictionary with action_id, title, available, and reason.

<a id="member-gfeditortoolcontext-methods-request_resource_action"></a>

### `request_resource_action`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func request_resource_action(action_id: String, paths: PackedStringArray) -> Dictionary:
```

将资源交给声明的接收工具；实际修改仍由接收工具显式提交。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 查询返回的稳定动作标识。 |
| `paths` | 当前资源路径快照。 |

返回：路由结果。

结构：

- `return`: Dictionary with ok: bool and message: String, plus optional error_code, status, action_id, replaced and metadata from routing. A same-generation receiver response adds receiver_report: Dictionary (deep copy retaining receiver status, reason, data and other fields) and registry_status; a nonempty receiver text status becomes status, and message falls back through receiver message, reason and status. Registry ok, error_code, action_id, replaced and metadata remain authoritative; unavailable, invalid or revoked routes retain their registry failure without a receiver report.

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
