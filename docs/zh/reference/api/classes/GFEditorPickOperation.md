# GFEditorPickOperation

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_editor_pick_operation.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

编辑器工具的分阶段拾取操作协议。 用于描述 pick、preview、ready、apply 和 cancel 这类持续交互流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`State`](#member-gfeditorpickoperation-enums-state) | `enum State` |
| 属性 | [`operation_id`](#member-gfeditorpickoperation-properties-operation_id) | `var operation_id: StringName = &""` |
| 属性 | [`label`](#member-gfeditorpickoperation-properties-label) | `var label: String = ""` |
| 属性 | [`metadata`](#member-gfeditorpickoperation-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`begin`](#member-gfeditorpickoperation-methods-begin) | `func begin(context: GFEditorToolContextBase) -> bool:` |
| 方法 | [`pick`](#member-gfeditorpickoperation-methods-pick) | `func pick(input_data: Dictionary) -> State:` |
| 方法 | [`can_apply`](#member-gfeditorpickoperation-methods-can_apply) | `func can_apply() -> bool:` |
| 方法 | [`apply`](#member-gfeditorpickoperation-methods-apply) | `func apply() -> Dictionary:` |
| 方法 | [`cancel`](#member-gfeditorpickoperation-methods-cancel) | `func cancel() -> void:` |
| 方法 | [`get_state`](#member-gfeditorpickoperation-methods-get_state) | `func get_state() -> State:` |
| 方法 | [`get_preview`](#member-gfeditorpickoperation-methods-get_preview) | `func get_preview() -> Dictionary:` |
| 方法 | [`get_result`](#member-gfeditorpickoperation-methods-get_result) | `func get_result() -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfeditorpickoperation-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`_on_begin`](#member-gfeditorpickoperation-methods-_on_begin) | `func _on_begin(_tool_context: GFEditorToolContextBase) -> void:` |
| 方法 | [`_on_pick`](#member-gfeditorpickoperation-methods-_on_pick) | `func _on_pick(_input_data: Dictionary) -> Dictionary:` |
| 方法 | [`_on_can_apply`](#member-gfeditorpickoperation-methods-_on_can_apply) | `func _on_can_apply() -> bool:` |
| 方法 | [`_on_apply`](#member-gfeditorpickoperation-methods-_on_apply) | `func _on_apply(_tool_context: GFEditorToolContextBase, result: Dictionary) -> Dictionary:` |
| 方法 | [`_on_cancel`](#member-gfeditorpickoperation-methods-_on_cancel) | `func _on_cancel(_tool_context: GFEditorToolContextBase) -> void:` |

## 枚举

<a id="member-gfeditorpickoperation-enums-state"></a>

### `State`

- API：`public`

```gdscript
enum State { ## 尚未开始。 IDLE, ## 正在拾取。 PICKING, ## 已准备好应用。 READY, ## 已应用。 APPLIED, ## 已取消。 CANCELLED, }
```

拾取操作状态。

## 属性

<a id="member-gfeditorpickoperation-properties-operation_id"></a>

### `operation_id`

- API：`public`

```gdscript
var operation_id: StringName = &""
```

操作稳定标识。

<a id="member-gfeditorpickoperation-properties-label"></a>

### `label`

- API：`public`

```gdscript
var label: String = ""
```

操作显示名称。

<a id="member-gfeditorpickoperation-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

调用方附加元数据。

结构：

- `metadata`: Dictionary for caller-defined pick operation metadata.

## 方法

<a id="member-gfeditorpickoperation-methods-begin"></a>

### `begin`

- API：`public`

```gdscript
func begin(context: GFEditorToolContextBase) -> bool:
```

开始拾取操作。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 编辑器工具上下文。 |

返回：成功开始返回 true。

<a id="member-gfeditorpickoperation-methods-pick"></a>

### `pick`

- API：`public`

```gdscript
func pick(input_data: Dictionary) -> State:
```

输入一次拾取数据。

参数：

| 名称 | 说明 |
|---|---|
| `input_data` | 调用方传入的通用拾取数据。 |

返回：操作状态。

结构：

- `input_data`: Dictionary containing tool-specific pick input.

<a id="member-gfeditorpickoperation-methods-can_apply"></a>

### `can_apply`

- API：`public`

```gdscript
func can_apply() -> bool:
```

检查当前操作是否可应用。

返回：可应用返回 true。

<a id="member-gfeditorpickoperation-methods-apply"></a>

### `apply`

- API：`public`

```gdscript
func apply() -> Dictionary:
```

应用拾取结果。

返回：应用结果字典。

结构：

- `return`: Dictionary result produced by _on_apply().

<a id="member-gfeditorpickoperation-methods-cancel"></a>

### `cancel`

- API：`public`

```gdscript
func cancel() -> void:
```

取消拾取操作。

<a id="member-gfeditorpickoperation-methods-get_state"></a>

### `get_state`

- API：`public`

```gdscript
func get_state() -> State:
```

获取当前状态。

返回：当前操作状态。

<a id="member-gfeditorpickoperation-methods-get_preview"></a>

### `get_preview`

- API：`public`

```gdscript
func get_preview() -> Dictionary:
```

获取预览数据副本。

返回：预览数据。

结构：

- `return`: Dictionary preview data produced by _on_pick().

<a id="member-gfeditorpickoperation-methods-get_result"></a>

### `get_result`

- API：`public`

```gdscript
func get_result() -> Dictionary:
```

获取拾取结果副本。

返回：拾取结果。

结构：

- `return`: Dictionary result data produced by _on_pick().

<a id="member-gfeditorpickoperation-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照字典。

结构：

- `return`: Dictionary containing operation_id, label, state, preview, result, and metadata.

<a id="member-gfeditorpickoperation-methods-_on_begin"></a>

### `_on_begin`

- API：`protected`

```gdscript
func _on_begin(_tool_context: GFEditorToolContextBase) -> void:
```

拾取流程开始时调用，供子类重写。

参数：

| 名称 | 说明 |
|---|---|
| `_tool_context` | 编辑器工具上下文。 |

<a id="member-gfeditorpickoperation-methods-_on_pick"></a>

### `_on_pick`

- API：`protected`

```gdscript
func _on_pick(_input_data: Dictionary) -> Dictionary:
```

处理一次拾取输入，供子类重写。

参数：

| 名称 | 说明 |
|---|---|
| `_input_data` | 调用方传入的通用拾取数据。 |

返回：拾取响应字典，可包含 preview、result 和 ready。

结构：

- `_input_data`: Dictionary containing tool-specific pick input.
- `return`: Dictionary pick response.

<a id="member-gfeditorpickoperation-methods-_on_can_apply"></a>

### `_on_can_apply`

- API：`protected`

```gdscript
func _on_can_apply() -> bool:
```

判断当前拾取结果是否可以应用，供子类重写。

返回：可应用返回 true。

<a id="member-gfeditorpickoperation-methods-_on_apply"></a>

### `_on_apply`

- API：`protected`

```gdscript
func _on_apply(_tool_context: GFEditorToolContextBase, result: Dictionary) -> Dictionary:
```

应用拾取结果，供子类重写。

参数：

| 名称 | 说明 |
|---|---|
| `_tool_context` | 编辑器工具上下文。 |
| `result` | 拾取结果副本。 |

返回：应用结果字典。

结构：

- `result`: Dictionary pick result data.
- `return`: Dictionary apply result.

<a id="member-gfeditorpickoperation-methods-_on_cancel"></a>

### `_on_cancel`

- API：`protected`

```gdscript
func _on_cancel(_tool_context: GFEditorToolContextBase) -> void:
```

取消拾取流程时调用，供子类重写。

参数：

| 名称 | 说明 |
|---|---|
| `_tool_context` | 编辑器工具上下文。 |
