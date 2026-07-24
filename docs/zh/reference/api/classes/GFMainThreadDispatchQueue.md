# GFMainThreadDispatchQueue

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_main_thread_dispatch_queue.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

主线程回调派发队列。 用于让后台线程、资源加载回调或项目侧异步流程把最终应用逻辑排回主线程。 post() 保存无 owner 的强 Callable；post_method() 通过弱 owner 和方法名保存生命周期调用。 队列不创建线程、不校验线程身份，也不解释调用方的业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`max_callbacks_per_tick`](#member-gfmainthreaddispatchqueue-properties-max_callbacks_per_tick) | `var max_callbacks_per_tick: int = 16:` |
| 属性 | [`max_seconds_per_tick`](#member-gfmainthreaddispatchqueue-properties-max_seconds_per_tick) | `var max_seconds_per_tick: float = 0.0:` |
| 方法 | [`init`](#member-gfmainthreaddispatchqueue-methods-init) | `func init() -> void:` |
| 方法 | [`tick`](#member-gfmainthreaddispatchqueue-methods-tick) | `func tick(_delta: float = 0.0) -> void:` |
| 方法 | [`dispose`](#member-gfmainthreaddispatchqueue-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`post`](#member-gfmainthreaddispatchqueue-methods-post) | `func post(callback: Callable, options: Dictionary = {}) -> int:` |
| 方法 | [`post_method`](#member-gfmainthreaddispatchqueue-methods-post_method) | `func post_method(owner: Object, method_name: StringName, options: Dictionary = {}) -> int:` |
| 方法 | [`dispatch`](#member-gfmainthreaddispatchqueue-methods-dispatch) | `func dispatch(max_count: int = 0, max_seconds: float = 0.0) -> Dictionary:` |
| 方法 | [`cancel`](#member-gfmainthreaddispatchqueue-methods-cancel) | `func cancel(handle: int) -> bool:` |
| 方法 | [`cancel_owner`](#member-gfmainthreaddispatchqueue-methods-cancel_owner) | `func cancel_owner(owner: Object) -> int:` |
| 方法 | [`clear`](#member-gfmainthreaddispatchqueue-methods-clear) | `func clear() -> void:` |
| 方法 | [`mark_dispatch_context`](#member-gfmainthreaddispatchqueue-methods-mark_dispatch_context) | `func mark_dispatch_context() -> void:` |
| 方法 | [`has_dispatch_context`](#member-gfmainthreaddispatchqueue-methods-has_dispatch_context) | `func has_dispatch_context() -> bool:` |
| 方法 | [`get_pending_count`](#member-gfmainthreaddispatchqueue-methods-get_pending_count) | `func get_pending_count() -> int:` |
| 方法 | [`is_empty`](#member-gfmainthreaddispatchqueue-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfmainthreaddispatchqueue-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfmainthreaddispatchqueue-properties-max_callbacks_per_tick"></a>

### `max_callbacks_per_tick`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_callbacks_per_tick: int = 16:
```

tick() 每次最多派发多少个回调。

<a id="member-gfmainthreaddispatchqueue-properties-max_seconds_per_tick"></a>

### `max_seconds_per_tick`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_seconds_per_tick: float = 0.0:
```

tick() 每次最多占用多少秒。小于等于 0 时不启用时间预算。

## 方法

<a id="member-gfmainthreaddispatchqueue-methods-init"></a>

### `init`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func init() -> void:
```

初始化队列，并标记该实例已有显式派发点。

<a id="member-gfmainthreaddispatchqueue-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func tick(_delta: float = 0.0) -> void:
```

按当前预算派发队列中的回调。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 为兼容 GF tick 签名而保留。 |

<a id="member-gfmainthreaddispatchqueue-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func dispose() -> void:
```

清空队列。

<a id="member-gfmainthreaddispatchqueue-methods-post"></a>

### `post`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func post(callback: Callable, options: Dictionary = {}) -> int:
```

把无 owner 的回调加入主线程派发队列。 该入口会强持有 callback；需要绑定 owner 生命周期时使用 post_method()。

参数：

| 名称 | 说明 |
|---|---|
| `callback` | 需要在显式派发点执行的回调。 |
| `options` | 队列选项，支持 metadata、label 和 front。 |

返回：派发句柄；callback 无效时返回 0。

结构：

- `options`: Dictionary，可包含 metadata: Dictionary、label: String、front: bool。

<a id="member-gfmainthreaddispatchqueue-methods-post_method"></a>

### `post_method`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func post_method(owner: Object, method_name: StringName, options: Dictionary = {}) -> int:
```

把弱 owner 方法调用加入主线程派发队列。 队列只保存 owner 的弱引用与方法名，不保存绑定 Callable、调用参数或 owner 强引用。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 方法调用拥有者。 |
| `method_name` | 派发时调用的方法名。 |
| `options` | 队列选项，支持 label 和 front。 |

返回：派发句柄；owner 或 method_name 无效时返回 0。

结构：

- `options`: Dictionary，可包含 label: String、front: bool。

<a id="member-gfmainthreaddispatchqueue-methods-dispatch"></a>

### `dispatch`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func dispatch(max_count: int = 0, max_seconds: float = 0.0) -> Dictionary:
```

派发队列中的回调。

参数：

| 名称 | 说明 |
|---|---|
| `max_count` | 最大派发数量；小于等于 0 时不限制数量。 |
| `max_seconds` | 最大派发秒数；小于等于 0 时不启用时间预算。 |

返回：派发报告。

结构：

- `return`: Dictionary，包含 dispatched_count、failed_count、skipped_owner_count、pending_count、budget_exhausted 和 dispatch_context_marked。

<a id="member-gfmainthreaddispatchqueue-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func cancel(handle: int) -> bool:
```

取消一个尚未派发的回调。

参数：

| 名称 | 说明 |
|---|---|
| `handle` | post() 或 post_method() 返回的派发句柄。 |

返回：找到并取消时返回 true。

<a id="member-gfmainthreaddispatchqueue-methods-cancel_owner"></a>

### `cancel_owner`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func cancel_owner(owner: Object) -> int:
```

取消指定 owner 的全部待派发弱方法调用。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 回调拥有者。 |

返回：取消数量。

<a id="member-gfmainthreaddispatchqueue-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空全部待派发回调和统计。

<a id="member-gfmainthreaddispatchqueue-methods-mark_dispatch_context"></a>

### `mark_dispatch_context`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func mark_dispatch_context() -> void:
```

标记该实例已有显式派发点。

<a id="member-gfmainthreaddispatchqueue-methods-has_dispatch_context"></a>

### `has_dispatch_context`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_dispatch_context() -> bool:
```

当前实例是否已经标记显式派发点。

返回：已标记显式派发点时返回 true。

<a id="member-gfmainthreaddispatchqueue-methods-get_pending_count"></a>

### `get_pending_count`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_pending_count() -> int:
```

获取待派发数量。

返回：队列长度。

<a id="member-gfmainthreaddispatchqueue-methods-is_empty"></a>

### `is_empty`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_empty() -> bool:
```

检查队列是否为空。

返回：队列为空时返回 true。

<a id="member-gfmainthreaddispatchqueue-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取队列调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 pending_count、pending_handles、posted_count、dispatched_count、cancelled_count、failed_count、skipped_owner_count 和 dispatch_context_marked。
