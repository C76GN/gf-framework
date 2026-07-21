# GFUIRouteOperation

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_ui_route_operation.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

单次异步路由打开的可观察句柄。 句柄由 GFUIRouterUtility 分配请求身份并只接受一个终态。相同 pending 路由 会返回同一句柄，调用方无需自行按路径合并请求。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`completed`](#member-gfuirouteoperation-signals-completed) | `signal completed(result: GFUIRouteResult)` |
| 常量 | [`OPERATION_PUSH`](#member-gfuirouteoperation-constants-operation_push) | `const OPERATION_PUSH: StringName = &"push"` |
| 常量 | [`OPERATION_REPLACE`](#member-gfuirouteoperation-constants-operation_replace) | `const OPERATION_REPLACE: StringName = &"replace"` |
| 方法 | [`get_request_id`](#member-gfuirouteoperation-methods-get_request_id) | `func get_request_id() -> int:` |
| 方法 | [`get_route_id`](#member-gfuirouteoperation-methods-get_route_id) | `func get_route_id() -> StringName:` |
| 方法 | [`get_operation`](#member-gfuirouteoperation-methods-get_operation) | `func get_operation() -> StringName:` |
| 方法 | [`get_preload_policy`](#member-gfuirouteoperation-methods-get_preload_policy) | `func get_preload_policy() -> StringName:` |
| 方法 | [`get_started_at_msec`](#member-gfuirouteoperation-methods-get_started_at_msec) | `func get_started_at_msec() -> int:` |
| 方法 | [`is_pending`](#member-gfuirouteoperation-methods-is_pending) | `func is_pending() -> bool:` |
| 方法 | [`is_completed`](#member-gfuirouteoperation-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`get_preload_session`](#member-gfuirouteoperation-methods-get_preload_session) | `func get_preload_session() -> GFAssetLoadSession:` |
| 方法 | [`get_result`](#member-gfuirouteoperation-methods-get_result) | `func get_result() -> GFUIRouteResult:` |
| 方法 | [`get_debug_snapshot`](#member-gfuirouteoperation-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfuirouteoperation-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal completed(result: GFUIRouteResult)
```

路由请求进入终态时发出一次。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 与当前请求 ID 匹配的隔离结果。 |

## 常量

<a id="member-gfuirouteoperation-constants-operation_push"></a>

### `OPERATION_PUSH`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const OPERATION_PUSH: StringName = &"push"
```

压入路由操作。

<a id="member-gfuirouteoperation-constants-operation_replace"></a>

### `OPERATION_REPLACE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const OPERATION_REPLACE: StringName = &"replace"
```

替换路由操作。

## 方法

<a id="member-gfuirouteoperation-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_request_id() -> int:
```

获取 Router 内唯一请求 ID。

返回：大于零的请求 ID。

<a id="member-gfuirouteoperation-methods-get_route_id"></a>

### `get_route_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_route_id() -> StringName:
```

获取规范化路由 ID。

返回：当前请求路由 ID。

<a id="member-gfuirouteoperation-methods-get_operation"></a>

### `get_operation`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_operation() -> StringName:
```

获取 push 或 replace 操作。

返回：`OPERATION_*` 常量之一。

<a id="member-gfuirouteoperation-methods-get_preload_policy"></a>

### `get_preload_policy`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_preload_policy() -> StringName:
```

获取请求预加载策略。

返回：Router 接受或拒绝的策略标识。

<a id="member-gfuirouteoperation-methods-get_started_at_msec"></a>

### `get_started_at_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_started_at_msec() -> int:
```

获取请求开始时间。

返回：单调时钟毫秒值。

<a id="member-gfuirouteoperation-methods-is_pending"></a>

### `is_pending`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_pending() -> bool:
```

检查请求是否仍在等待终态。

返回：已配置且未完成时返回 true。

<a id="member-gfuirouteoperation-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_completed() -> bool:
```

检查请求是否已有终态。

返回：已完成时返回 true。

<a id="member-gfuirouteoperation-methods-get_preload_session"></a>

### `get_preload_session`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_preload_session() -> GFAssetLoadSession:
```

获取当前预加载会话。

返回：已启动的会话；未启用或尚未启动时返回 null。

<a id="member-gfuirouteoperation-methods-get_result"></a>

### `get_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_result() -> GFUIRouteResult:
```

获取终态结果副本。

返回：已完成结果；等待中返回 null。

<a id="member-gfuirouteoperation-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取稳定调试快照。

返回：请求身份、pending 状态、预加载会话和终态摘要。

结构：

- `return`: Dictionary with request_id, route_id, operation, preload_policy, started_at_msec, pending, completed, preload_session_id, and result.
