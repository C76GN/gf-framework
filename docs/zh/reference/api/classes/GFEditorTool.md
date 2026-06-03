# GFEditorTool

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_editor_tool.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

持续式编辑器交互工具基类。 用于封装需要激活、停用、接收输入并最终产生命令的编辑器工具。 基类只定义生命周期协议，具体绘制和资源修改由子类实现。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`tool_id`](#member-gfeditortool-properties-tool_id) | `var tool_id: StringName = &""` |
| 属性 | [`label`](#member-gfeditortool-properties-label) | `var label: String = ""` |
| 属性 | [`tooltip`](#member-gfeditortool-properties-tooltip) | `var tooltip: String = ""` |
| 属性 | [`priority`](#member-gfeditortool-properties-priority) | `var priority: int = 0` |
| 属性 | [`metadata`](#member-gfeditortool-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`option_schema`](#member-gfeditortool-properties-option_schema) | `var option_schema: GFEditorToolOptionSchemaBase = null` |
| 方法 | [`activate`](#member-gfeditortool-methods-activate) | `func activate(context: GFEditorToolContextBase) -> void:` |
| 方法 | [`deactivate`](#member-gfeditortool-methods-deactivate) | `func deactivate() -> void:` |
| 方法 | [`is_active`](#member-gfeditortool-methods-is_active) | `func is_active() -> bool:` |
| 方法 | [`get_context`](#member-gfeditortool-methods-get_context) | `func get_context() -> GFEditorToolContextBase:` |
| 方法 | [`set_option_schema`](#member-gfeditortool-methods-set_option_schema) | `func set_option_schema(schema: GFEditorToolOptionSchemaBase, reset_values: bool = true) -> void:` |
| 方法 | [`set_tool_option`](#member-gfeditortool-methods-set_tool_option) | `func set_tool_option(option_id: StringName, value: Variant) -> bool:` |
| 方法 | [`get_tool_option`](#member-gfeditortool-methods-get_tool_option) | `func get_tool_option(option_id: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`get_tool_options`](#member-gfeditortool-methods-get_tool_options) | `func get_tool_options() -> Dictionary:` |
| 方法 | [`clear_tool_options`](#member-gfeditortool-methods-clear_tool_options) | `func clear_tool_options() -> void:` |
| 方法 | [`can_handle`](#member-gfeditortool-methods-can_handle) | `func can_handle(context: GFEditorToolContextBase) -> bool:` |
| 方法 | [`begin_pick_operation`](#member-gfeditortool-methods-begin_pick_operation) | `func begin_pick_operation(operation: GFEditorPickOperationBase) -> bool:` |
| 方法 | [`pick`](#member-gfeditortool-methods-pick) | `func pick(input_data: Dictionary) -> int:` |
| 方法 | [`apply_pick_operation`](#member-gfeditortool-methods-apply_pick_operation) | `func apply_pick_operation() -> Dictionary:` |
| 方法 | [`cancel_pick_operation`](#member-gfeditortool-methods-cancel_pick_operation) | `func cancel_pick_operation() -> void:` |
| 方法 | [`get_pick_operation`](#member-gfeditortool-methods-get_pick_operation) | `func get_pick_operation() -> GFEditorPickOperationBase:` |
| 方法 | [`gui_input`](#member-gfeditortool-methods-gui_input) | `func gui_input(event: InputEvent) -> bool:` |
| 方法 | [`draw_tool`](#member-gfeditortool-methods-draw_tool) | `func draw_tool(viewport: Viewport) -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfeditortool-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`_on_activated`](#member-gfeditortool-methods-_on_activated) | `func _on_activated(_tool_context: GFEditorToolContextBase) -> void:` |
| 方法 | [`_on_deactivated`](#member-gfeditortool-methods-_on_deactivated) | `func _on_deactivated(_tool_context: GFEditorToolContextBase) -> void:` |
| 方法 | [`_handle_gui_input`](#member-gfeditortool-methods-_handle_gui_input) | `func _handle_gui_input(_event: InputEvent) -> bool:` |
| 方法 | [`_draw_tool`](#member-gfeditortool-methods-_draw_tool) | `func _draw_tool(_viewport: Viewport) -> void:` |

## 属性

<a id="member-gfeditortool-properties-tool_id"></a>

### `tool_id`

- API：`public`

```gdscript
var tool_id: StringName = &""
```

工具稳定标识。

<a id="member-gfeditortool-properties-label"></a>

### `label`

- API：`public`

```gdscript
var label: String = ""
```

工具显示名称。

<a id="member-gfeditortool-properties-tooltip"></a>

### `tooltip`

- API：`public`

```gdscript
var tooltip: String = ""
```

工具提示文本。

<a id="member-gfeditortool-properties-priority"></a>

### `priority`

- API：`public`

```gdscript
var priority: int = 0
```

工具排序权重。

<a id="member-gfeditortool-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

调用方附加元数据。

结构：

- `metadata`: Dictionary for caller-defined editor tool metadata.

<a id="member-gfeditortool-properties-option_schema"></a>

### `option_schema`

- API：`public`

```gdscript
var option_schema: GFEditorToolOptionSchemaBase = null
```

可选工具选项声明。

## 方法

<a id="member-gfeditortool-methods-activate"></a>

### `activate`

- API：`public`

```gdscript
func activate(context: GFEditorToolContextBase) -> void:
```

激活工具。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 编辑器工具上下文。 |

<a id="member-gfeditortool-methods-deactivate"></a>

### `deactivate`

- API：`public`

```gdscript
func deactivate() -> void:
```

停用工具。

<a id="member-gfeditortool-methods-is_active"></a>

### `is_active`

- API：`public`

```gdscript
func is_active() -> bool:
```

工具是否处于激活状态。

返回：激活时返回 true。

<a id="member-gfeditortool-methods-get_context"></a>

### `get_context`

- API：`public`

```gdscript
func get_context() -> GFEditorToolContextBase:
```

获取当前上下文。

返回：当前上下文；未激活时返回 null。

<a id="member-gfeditortool-methods-set_option_schema"></a>

### `set_option_schema`

- API：`public`

```gdscript
func set_option_schema(schema: GFEditorToolOptionSchemaBase, reset_values: bool = true) -> void:
```

设置工具选项声明。

参数：

| 名称 | 说明 |
|---|---|
| `schema` | 工具选项声明。 |
| `reset_values` | 是否重置当前选项值。 |

<a id="member-gfeditortool-methods-set_tool_option"></a>

### `set_tool_option`

- API：`public`

```gdscript
func set_tool_option(option_id: StringName, value: Variant) -> bool:
```

设置工具选项值。

参数：

| 名称 | 说明 |
|---|---|
| `option_id` | 选项标识。 |
| `value` | 选项值。 |

返回：设置成功返回 true。

结构：

- `value`: Variant raw option value.

<a id="member-gfeditortool-methods-get_tool_option"></a>

### `get_tool_option`

- API：`public`

```gdscript
func get_tool_option(option_id: StringName, default_value: Variant = null) -> Variant:
```

获取工具选项值。

参数：

| 名称 | 说明 |
|---|---|
| `option_id` | 选项标识。 |
| `default_value` | 缺失时返回的默认值。 |

返回：选项值。

结构：

- `default_value`: Variant fallback returned when the option is missing.
- `return`: Variant option value copy or fallback.

<a id="member-gfeditortool-methods-get_tool_options"></a>

### `get_tool_options`

- API：`public`

```gdscript
func get_tool_options() -> Dictionary:
```

获取工具选项快照。

返回：选项值副本。

结构：

- `return`: Dictionary keyed by option_id, storing option values.

<a id="member-gfeditortool-methods-clear_tool_options"></a>

### `clear_tool_options`

- API：`public`

```gdscript
func clear_tool_options() -> void:
```

清空工具选项值。

<a id="member-gfeditortool-methods-can_handle"></a>

### `can_handle`

- API：`public`

```gdscript
func can_handle(context: GFEditorToolContextBase) -> bool:
```

工具是否可以处理当前上下文。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 编辑器工具上下文。 |

返回：可处理时返回 true。

<a id="member-gfeditortool-methods-begin_pick_operation"></a>

### `begin_pick_operation`

- API：`public`

```gdscript
func begin_pick_operation(operation: GFEditorPickOperationBase) -> bool:
```

开始分阶段拾取操作。

参数：

| 名称 | 说明 |
|---|---|
| `operation` | 拾取操作。 |

返回：成功开始返回 true。

<a id="member-gfeditortool-methods-pick"></a>

### `pick`

- API：`public`

```gdscript
func pick(input_data: Dictionary) -> int:
```

向当前拾取操作输入数据。

参数：

| 名称 | 说明 |
|---|---|
| `input_data` | 通用拾取数据。 |

返回：当前拾取状态；没有操作时返回 IDLE。

结构：

- `input_data`: Dictionary pick input forwarded to the active pick operation.

<a id="member-gfeditortool-methods-apply_pick_operation"></a>

### `apply_pick_operation`

- API：`public`

```gdscript
func apply_pick_operation() -> Dictionary:
```

应用当前拾取操作。

返回：应用结果字典。

结构：

- `return`: Dictionary apply result from the active pick operation.

<a id="member-gfeditortool-methods-cancel_pick_operation"></a>

### `cancel_pick_operation`

- API：`public`

```gdscript
func cancel_pick_operation() -> void:
```

取消当前拾取操作。

<a id="member-gfeditortool-methods-get_pick_operation"></a>

### `get_pick_operation`

- API：`public`

```gdscript
func get_pick_operation() -> GFEditorPickOperationBase:
```

获取当前拾取操作。

返回：拾取操作；不存在时返回 null。

<a id="member-gfeditortool-methods-gui_input"></a>

### `gui_input`

- API：`public`

```gdscript
func gui_input(event: InputEvent) -> bool:
```

向工具转发输入事件。

参数：

| 名称 | 说明 |
|---|---|
| `event` | 输入事件。 |

返回：true 表示事件已被工具消费。

<a id="member-gfeditortool-methods-draw_tool"></a>

### `draw_tool`

- API：`public`

```gdscript
func draw_tool(viewport: Viewport) -> void:
```

请求工具绘制调试或交互辅助。

参数：

| 名称 | 说明 |
|---|---|
| `viewport` | 绘制目标视口。 |

<a id="member-gfeditortool-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取工具快照。

返回：调试信息字典。

结构：

- `return`: Dictionary containing tool_id, label, tooltip, priority, active, options, pick_operation, and metadata.

<a id="member-gfeditortool-methods-_on_activated"></a>

### `_on_activated`

- API：`protected`

```gdscript
func _on_activated(_tool_context: GFEditorToolContextBase) -> void:
```

工具激活时调用，供子类重写。

参数：

| 名称 | 说明 |
|---|---|
| `_tool_context` | 编辑器工具上下文。 |

<a id="member-gfeditortool-methods-_on_deactivated"></a>

### `_on_deactivated`

- API：`protected`

```gdscript
func _on_deactivated(_tool_context: GFEditorToolContextBase) -> void:
```

工具停用时调用，供子类重写。

参数：

| 名称 | 说明 |
|---|---|
| `_tool_context` | 编辑器工具上下文。 |

<a id="member-gfeditortool-methods-_handle_gui_input"></a>

### `_handle_gui_input`

- API：`protected`

```gdscript
func _handle_gui_input(_event: InputEvent) -> bool:
```

处理 GUI 输入事件，供子类重写。

参数：

| 名称 | 说明 |
|---|---|
| `_event` | 输入事件。 |

返回：事件被消费时返回 true。

<a id="member-gfeditortool-methods-_draw_tool"></a>

### `_draw_tool`

- API：`protected`

```gdscript
func _draw_tool(_viewport: Viewport) -> void:
```

绘制工具辅助内容，供子类重写。

参数：

| 名称 | 说明 |
|---|---|
| `_viewport` | 绘制目标视口。 |
