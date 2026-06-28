# GFEditorActionDefinition

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_editor_action_definition.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

编辑器动作声明。 把菜单、按钮、快捷键或面板入口与命令工厂解耦。动作只负责描述入口和创建命令， 具体执行、撤销和业务含义由调用方或命令实现决定。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`action_id`](#member-gfeditoractiondefinition-properties-action_id) | `var action_id: StringName = &""` |
| 属性 | [`label`](#member-gfeditoractiondefinition-properties-label) | `var label: String = ""` |
| 属性 | [`group`](#member-gfeditoractiondefinition-properties-group) | `var group: StringName = &""` |
| 属性 | [`tooltip`](#member-gfeditoractiondefinition-properties-tooltip) | `var tooltip: String = ""` |
| 属性 | [`shortcut_text`](#member-gfeditoractiondefinition-properties-shortcut_text) | `var shortcut_text: String = ""` |
| 属性 | [`source_id`](#member-gfeditoractiondefinition-properties-source_id) | `var source_id: StringName = &""` |
| 属性 | [`sort_order`](#member-gfeditoractiondefinition-properties-sort_order) | `var sort_order: int = 0` |
| 属性 | [`enabled`](#member-gfeditoractiondefinition-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`command_factory`](#member-gfeditoractiondefinition-properties-command_factory) | `var command_factory: Callable = Callable()` |
| 属性 | [`availability_callback`](#member-gfeditoractiondefinition-properties-availability_callback) | `var availability_callback: Callable = Callable()` |
| 属性 | [`metadata`](#member-gfeditoractiondefinition-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`create_command`](#member-gfeditoractiondefinition-methods-create_command) | `func create_command(context: Dictionary = {}) -> GFEditorCommandBase:` |
| 方法 | [`invoke`](#member-gfeditoractiondefinition-methods-invoke) | `func invoke(context: Dictionary = {}, undo_manager: Object = null) -> Error:` |
| 方法 | [`is_available`](#member-gfeditoractiondefinition-methods-is_available) | `func is_available(context: Dictionary = {}) -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfeditoractiondefinition-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfeditoractiondefinition-properties-action_id"></a>

### `action_id`

- API：`public`

```gdscript
var action_id: StringName = &""
```

动作稳定标识。

<a id="member-gfeditoractiondefinition-properties-label"></a>

### `label`

- API：`public`

```gdscript
var label: String = ""
```

动作显示名称。

<a id="member-gfeditoractiondefinition-properties-group"></a>

### `group`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var group: StringName = &""
```

动作分组。用于命令面板、工具栏或菜单按领域组织入口。

<a id="member-gfeditoractiondefinition-properties-tooltip"></a>

### `tooltip`

- API：`public`

```gdscript
var tooltip: String = ""
```

动作提示文本。

<a id="member-gfeditoractiondefinition-properties-shortcut_text"></a>

### `shortcut_text`

- API：`public`

```gdscript
var shortcut_text: String = ""
```

快捷键说明文本，由具体 UI 决定是否展示。

<a id="member-gfeditoractiondefinition-properties-source_id"></a>

### `source_id`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var source_id: StringName = &""
```

动作来源标识。通常是贡献该动作的 package、插件或工具 ID。

<a id="member-gfeditoractiondefinition-properties-sort_order"></a>

### `sort_order`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var sort_order: int = 0
```

同组内排序权重，数值越小越靠前。

<a id="member-gfeditoractiondefinition-properties-enabled"></a>

### `enabled`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var enabled: bool = true
```

动作是否启用。禁用动作不会创建命令或被调用。

<a id="member-gfeditoractiondefinition-properties-command_factory"></a>

### `command_factory`

- API：`public`

```gdscript
var command_factory: Callable = Callable()
```

命令工厂。推荐签名为 `func(context: Dictionary) -> GFEditorCommand`。

<a id="member-gfeditoractiondefinition-properties-availability_callback"></a>

### `availability_callback`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var availability_callback: Callable = Callable()
```

可用性回调。推荐签名为 `func(context: Dictionary) -> bool`，必须保持纯查询，不应创建或执行命令。

<a id="member-gfeditoractiondefinition-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

动作元数据。

结构：

- `metadata`: Dictionary for caller-defined editor action metadata.

## 方法

<a id="member-gfeditoractiondefinition-methods-create_command"></a>

### `create_command`

- API：`public`

```gdscript
func create_command(context: Dictionary = {}) -> GFEditorCommandBase:
```

根据上下文创建命令。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 调用方传入的编辑器上下文。 |

返回：命令对象，工厂无效或返回类型不匹配时为 null。

结构：

- `context`: Dictionary editor context passed to command_factory.

<a id="member-gfeditoractiondefinition-methods-invoke"></a>

### `invoke`

- API：`public`

```gdscript
func invoke(context: Dictionary = {}, undo_manager: Object = null) -> Error:
```

执行动作并可选接入 UndoRedo。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 调用方传入的编辑器上下文。 |
| `undo_manager` | EditorUndoRedoManager 或兼容对象；为空时直接执行命令。 |

返回：Godot 错误码。

结构：

- `context`: Dictionary editor context passed to create_command().

<a id="member-gfeditoractiondefinition-methods-is_available"></a>

### `is_available`

- API：`public`

```gdscript
func is_available(context: Dictionary = {}) -> bool:
```

动作是否具备可调用命令工厂。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 调用方传入的编辑器上下文。 |

返回：可创建且可执行命令时返回 true。

结构：

- `context`: Dictionary editor context passed to create_command().

<a id="member-gfeditoractiondefinition-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取动作快照。

返回：调试信息字典。

结构：

- `return`: Dictionary containing action_id, label, group, tooltip, shortcut_text, source_id, sort_order, enabled, has_command_factory, and metadata.
