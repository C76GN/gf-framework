# GFSceneOperation

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/scene/gf_scene_operation.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`11.0.0`

单次类型化场景加载或预加载请求的 caller Operation。 每个请求持有独立 ID、资源身份快照与取消能力。同一路径请求可以共享 Broker 的物理加载，但每个 Operation 只观察并终结自己的 consumer Lease。 Operation 只能由 [method GFSceneUtility.load_scene_request_async] 或 [method GFSceneUtility.preload_scene_request_async] 取得。它是可由 caller 保留的 RefCounted handle，无需显式 release，也不拥有 Utility、Broker 或底层 Lease。 进入终态或 Utility dispose 后，身份、最终进度与结果快照仍可读取；pending 期间 只有 [method cancel] 能力依赖创建它的 Utility 仍然存活。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`progressed`](#member-gfsceneoperation-signals-progressed) | `signal progressed(progress_ratio: float)` |
| 信号 | [`completed`](#member-gfsceneoperation-signals-completed) | `signal completed(result: GFSceneOperationResult)` |
| 枚举 | [`Kind`](#member-gfsceneoperation-enums-kind) | `enum Kind` |
| 方法 | [`get_request_id`](#member-gfsceneoperation-methods-get_request_id) | `func get_request_id() -> int:` |
| 方法 | [`get_kind`](#member-gfsceneoperation-methods-get_kind) | `func get_kind() -> Kind:` |
| 方法 | [`get_scene_identity`](#member-gfsceneoperation-methods-get_scene_identity) | `func get_scene_identity() -> GFResourceIdentity:` |
| 方法 | [`get_progress_ratio`](#member-gfsceneoperation-methods-get_progress_ratio) | `func get_progress_ratio() -> float:` |
| 方法 | [`is_pending`](#member-gfsceneoperation-methods-is_pending) | `func is_pending() -> bool:` |
| 方法 | [`is_completed`](#member-gfsceneoperation-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`get_result`](#member-gfsceneoperation-methods-get_result) | `func get_result() -> GFSceneOperationResult:` |
| 方法 | [`cancel`](#member-gfsceneoperation-methods-cancel) | `func cancel() -> bool:` |

## 信号

<a id="member-gfsceneoperation-signals-progressed"></a>

### `progressed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal progressed(progress_ratio: float)
```

当前 consumer 的加载进度发生变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `progress_ratio` | 当前进度，范围为 \`0.0\` 到 \`1.0\`。 |

<a id="member-gfsceneoperation-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal completed(result: GFSceneOperationResult)
```

当前 consumer 进入唯一终态时发出一次。 同步 validation、cache hit 或生命周期拒绝可能在 request 方法返回前完成；调用方 必须先查询 `is_completed()`，只在仍 pending 时连接该信号。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 当前请求的隔离终态结果。 |

## 枚举

<a id="member-gfsceneoperation-enums-kind"></a>

### `Kind`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
enum Kind {
	## 加载资源并在安全帧切换场景。
	LOAD,
	## 预加载场景资源；是否继续保留在缓存由容量与 fixed 策略决定。
	PRELOAD,
}
```

类型化场景请求的执行种类。

## 方法

<a id="member-gfsceneoperation-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_request_id() -> int:
```

获取 Scene Utility 分配的请求 ID。

返回：大于零的请求 ID；尚未配置时返回 0。

<a id="member-gfsceneoperation-methods-get_kind"></a>

### `get_kind`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_kind() -> Kind:
```

获取请求执行种类。

返回：`LOAD` 或 `PRELOAD`。

<a id="member-gfsceneoperation-methods-get_scene_identity"></a>

### `get_scene_identity`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_scene_identity() -> GFResourceIdentity:
```

获取请求冻结的资源身份副本。

返回：隔离的 GFResourceIdentity 快照；尚未配置时返回 null。

<a id="member-gfsceneoperation-methods-get_progress_ratio"></a>

### `get_progress_ratio`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_progress_ratio() -> float:
```

获取当前 consumer 的进度。

返回：范围为 `0.0` 到 `1.0` 的进度。

<a id="member-gfsceneoperation-methods-is_pending"></a>

### `is_pending`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_pending() -> bool:
```

检查请求是否仍等待 caller 终态。

返回：已配置且尚未完成时返回 true。

<a id="member-gfsceneoperation-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_completed() -> bool:
```

检查请求是否已经进入 caller 终态。

返回：已有终态结果时返回 true。

<a id="member-gfsceneoperation-methods-get_result"></a>

### `get_result`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_result() -> GFSceneOperationResult:
```

获取 caller 终态结果副本。

返回：已完成时返回隔离结果；等待中返回 null。

<a id="member-gfsceneoperation-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func cancel() -> bool:
```

取消当前 caller 仍在等待的请求。 preload 取消只释放当前 consumer Lease；同路径的其它 consumer 继续等待。load 取消只终结当前切换请求，不会替换或接纳另一个 load。

返回：Scene Utility 首次接受当前 caller 的取消 intent 时返回 true。
