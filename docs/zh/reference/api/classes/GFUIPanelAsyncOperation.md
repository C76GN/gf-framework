# GFUIPanelAsyncOperation

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_ui_panel_async_operation.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`11.0.0`

单次异步 UI 面板请求的可观察句柄。 句柄冻结 UI 分配的请求序号、路径、层级与操作类型，并且只接受一个终态。 成功面板仅以弱引用保存，句柄不会延长面板节点的生命周期。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`completed`](#member-gfuipanelasyncoperation-signals-completed) | `signal completed(handle: GFUIPanelAsyncOperation)` |
| 常量 | [`STATUS_PENDING`](#member-gfuipanelasyncoperation-constants-status_pending) | `const STATUS_PENDING: int = -1` |
| 常量 | [`OPERATION_PUSH`](#member-gfuipanelasyncoperation-constants-operation_push) | `const OPERATION_PUSH: StringName = &"push"` |
| 常量 | [`OPERATION_REPLACE`](#member-gfuipanelasyncoperation-constants-operation_replace) | `const OPERATION_REPLACE: StringName = &"replace"` |
| 方法 | [`get_serial`](#member-gfuipanelasyncoperation-methods-get_serial) | `func get_serial() -> int:` |
| 方法 | [`get_path`](#member-gfuipanelasyncoperation-methods-get_path) | `func get_path() -> String:` |
| 方法 | [`get_layer`](#member-gfuipanelasyncoperation-methods-get_layer) | `func get_layer() -> int:` |
| 方法 | [`get_operation`](#member-gfuipanelasyncoperation-methods-get_operation) | `func get_operation() -> StringName:` |
| 方法 | [`is_pending`](#member-gfuipanelasyncoperation-methods-is_pending) | `func is_pending() -> bool:` |
| 方法 | [`is_completed`](#member-gfuipanelasyncoperation-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`get_status`](#member-gfuipanelasyncoperation-methods-get_status) | `func get_status() -> int:` |
| 方法 | [`get_panel`](#member-gfuipanelasyncoperation-methods-get_panel) | `func get_panel() -> Node:` |
| 方法 | [`get_debug_snapshot`](#member-gfuipanelasyncoperation-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfuipanelasyncoperation-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal completed(handle: GFUIPanelAsyncOperation)
```

请求进入终态时发出一次。

参数：

| 名称 | 说明 |
|---|---|
| `handle` | 已完成的当前句柄。 |

## 常量

<a id="member-gfuipanelasyncoperation-constants-status_pending"></a>

### `STATUS_PENDING`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATUS_PENDING: int = -1
```

请求尚未进入终态时由 get_status() 返回的状态。

<a id="member-gfuipanelasyncoperation-constants-operation_push"></a>

### `OPERATION_PUSH`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const OPERATION_PUSH: StringName = &"push"
```

压入面板操作。

<a id="member-gfuipanelasyncoperation-constants-operation_replace"></a>

### `OPERATION_REPLACE`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const OPERATION_REPLACE: StringName = &"replace"
```

替换层级操作。

## 方法

<a id="member-gfuipanelasyncoperation-methods-get_serial"></a>

### `get_serial`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_serial() -> int:
```

获取 UI 分配的请求序号。

返回：配置后为大于零的请求序号；未配置时为 0。

<a id="member-gfuipanelasyncoperation-methods-get_path"></a>

### `get_path`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_path() -> String:
```

获取面板场景路径。

返回：请求创建时冻结的场景路径。

<a id="member-gfuipanelasyncoperation-methods-get_layer"></a>

### `get_layer`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_layer() -> int:
```

获取目标 UI 层级。

返回：请求创建时冻结的逻辑层 ID。

<a id="member-gfuipanelasyncoperation-methods-get_operation"></a>

### `get_operation`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_operation() -> StringName:
```

获取 push 或 replace 操作。

返回：`OPERATION_*` 常量之一。

<a id="member-gfuipanelasyncoperation-methods-is_pending"></a>

### `is_pending`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_pending() -> bool:
```

检查请求是否仍在等待终态。

返回：已配置且尚未完成时返回 true。

<a id="member-gfuipanelasyncoperation-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_completed() -> bool:
```

检查请求是否已有终态。

返回：已完成时返回 true。

<a id="member-gfuipanelasyncoperation-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_status() -> int:
```

获取请求状态。

返回：等待中返回 STATUS_PENDING；完成后返回 GFUIUtility.AsyncPanelLoadStatus。

<a id="member-gfuipanelasyncoperation-methods-get_panel"></a>

### `get_panel`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_panel() -> Node:
```

获取成功打开的面板。 句柄只保存弱引用；面板已释放、请求失败或请求取消时返回 null。

返回：当前仍有效的成功面板；否则返回 null。

<a id="member-gfuipanelasyncoperation-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取稳定调试快照。

返回：请求身份与终态摘要。

结构：

- `return`: Dictionary，包含 serial、path、layer、operation、pending、completed、status、has_panel 和 panel_instance_id。
