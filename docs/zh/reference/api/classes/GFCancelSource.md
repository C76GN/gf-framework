# GFCancelSource

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_cancel_source.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`7.0.0`

可触发取消的拥有者句柄。 source 负责创建和触发 [GFCancelToken]，并可把上游 token、节点生命周期或 SceneTree 超时 连接为统一取消信号。它不执行具体任务，也不假定取消后的业务回滚策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`cancelled`](#member-gfcancelsource-signals-cancelled) | `signal cancelled(reason: StringName, metadata: Dictionary)` |
| 方法 | [`_init`](#member-gfcancelsource-methods-_init) | `func _init() -> void:` |
| 方法 | [`get_token`](#member-gfcancelsource-methods-get_token) | `func get_token() -> GFCancelToken:` |
| 方法 | [`cancel`](#member-gfcancelsource-methods-cancel) | `func cancel(reason: StringName = &"cancelled", metadata: Dictionary = {}) -> bool:` |
| 方法 | [`is_cancelled`](#member-gfcancelsource-methods-is_cancelled) | `func is_cancelled() -> bool:` |
| 方法 | [`link_token`](#member-gfcancelsource-methods-link_token) | `func link_token(token: GFCancelToken, reason: StringName = &"", metadata: Dictionary = {}) -> bool:` |
| 方法 | [`cancel_when_node_exits`](#member-gfcancelsource-methods-cancel_when_node_exits) | `func cancel_when_node_exits(node: Node, reason: StringName = &"node_exited", metadata: Dictionary = {}) -> bool:` |
| 方法 | [`cancel_after_seconds`](#member-gfcancelsource-methods-cancel_after_seconds) | `func cancel_after_seconds( seconds: float, tree: SceneTree = null, reason: StringName = &"timeout", metadata: Dictionary = {}, process_always: bool = true, process_in_physics: bool = false, ignore_time_scale: bool = false ) -> bool:` |
| 方法 | [`dispose`](#member-gfcancelsource-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfcancelsource-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`create_linked`](#member-gfcancelsource-methods-create_linked) | `static func create_linked(tokens: Array, reason: StringName = &"", metadata: Dictionary = {}) -> GFCancelSource:` |

## 信号

<a id="member-gfcancelsource-signals-cancelled"></a>

### `cancelled`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal cancelled(reason: StringName, metadata: Dictionary)
```

source 首次取消时发出。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 稳定取消原因。 |
| `metadata` | 调用方附加的取消上下文。 |

结构：

- `metadata`: Dictionary，包含调用方定义的取消上下文。

## 方法

<a id="member-gfcancelsource-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func _init() -> void:
```

创建取消 source。

<a id="member-gfcancelsource-methods-get_token"></a>

### `get_token`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_token() -> GFCancelToken:
```

获取只读取消 token。

返回：当前 source 持有的取消 token。

<a id="member-gfcancelsource-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func cancel(reason: StringName = &"cancelled", metadata: Dictionary = {}) -> bool:
```

触发取消。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 稳定取消原因。 |
| `metadata` | 调用方附加的取消上下文。 |

返回：首次取消时返回 true。

结构：

- `metadata`: Dictionary，包含调用方定义的取消上下文。

<a id="member-gfcancelsource-methods-is_cancelled"></a>

### `is_cancelled`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_cancelled() -> bool:
```

判断 source 是否已经取消。

返回：已取消时返回 true。

<a id="member-gfcancelsource-methods-link_token"></a>

### `link_token`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func link_token(token: GFCancelToken, reason: StringName = &"", metadata: Dictionary = {}) -> bool:
```

连接上游 token；上游取消时当前 source 也会取消。

参数：

| 名称 | 说明 |
|---|---|
| `token` | 上游取消 token。 |
| `reason` | 可选覆盖原因；为空时使用上游原因。 |
| `metadata` | 当前连接附加的元数据，会覆盖同名上游字段。 |

返回：成功连接或上游已经触发取消时返回 true。

结构：

- `metadata`: Dictionary，包含调用方定义的取消上下文。

<a id="member-gfcancelsource-methods-cancel_when_node_exits"></a>

### `cancel_when_node_exits`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func cancel_when_node_exits(node: Node, reason: StringName = &"node_exited", metadata: Dictionary = {}) -> bool:
```

在节点离开场景树时取消。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 生命周期拥有者节点。 |
| `reason` | 取消原因。 |
| `metadata` | 取消上下文。 |

返回：成功连接或节点已经离树并触发取消时返回 true。

结构：

- `metadata`: Dictionary，包含调用方定义的取消上下文。

<a id="member-gfcancelsource-methods-cancel_after_seconds"></a>

### `cancel_after_seconds`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func cancel_after_seconds( seconds: float, tree: SceneTree = null, reason: StringName = &"timeout", metadata: Dictionary = {}, process_always: bool = true, process_in_physics: bool = false, ignore_time_scale: bool = false ) -> bool:
```

在指定秒数后自动取消。

参数：

| 名称 | 说明 |
|---|---|
| `seconds` | 超时时间；小于等于 0 时立即取消。 |
| `tree` | 可选 SceneTree；为空时使用当前主循环。 |
| `reason` | 超时取消原因。 |
| `metadata` | 取消上下文。 |
| `process_always` | 是否在暂停时继续计时。 |
| `process_in_physics` | 是否在物理帧处理。 |
| `ignore_time_scale` | 是否忽略 Engine.time_scale。 |

返回：成功安排或立即触发取消时返回 true。

结构：

- `metadata`: Dictionary，包含调用方定义的取消上下文。

<a id="member-gfcancelsource-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func dispose() -> void:
```

释放 source 持有的连接。

<a id="member-gfcancelsource-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取取消 source 调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 token 状态、linked_token_count、node_lifetime_count 和 has_timeout。

<a id="member-gfcancelsource-methods-create_linked"></a>

### `create_linked`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func create_linked(tokens: Array, reason: StringName = &"", metadata: Dictionary = {}) -> GFCancelSource:
```

创建一个连接多个上游 token 的 source。

参数：

| 名称 | 说明 |
|---|---|
| `tokens` | 上游 token 列表。 |
| `reason` | 可选覆盖原因；为空时使用上游原因。 |
| `metadata` | 当前连接附加的元数据。 |

返回：新建的取消 source。

结构：

- `tokens`: Array，元素应为 GFCancelToken。
- `metadata`: Dictionary，包含调用方定义的取消上下文。
