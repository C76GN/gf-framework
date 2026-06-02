# GFSignalUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/signals/gf_signal_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

Godot 原生 Signal 的安全连接与链式处理工具。 用于连接不适合进入 GF 业务事件总线的节点信号，支持 owner 归属清理、 默认参数、过滤、映射、延迟、防抖和一次性触发。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`dispose`](#member-gfsignalutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`connect_signal`](#member-gfsignalutility-methods-connect_signal) | `func connect_signal( source_signal: Signal, callback: Callable, owner: Object = null, default_args: Array = [], connect_flags: int = 0 ) -> GFSignalConnection:` |
| 方法 | [`connect_once`](#member-gfsignalutility-methods-connect_once) | `func connect_once( source_signal: Signal, callback: Callable, owner: Object = null, default_args: Array = [], connect_flags: int = 0 ) -> GFSignalConnection:` |
| 方法 | [`connect_any`](#member-gfsignalutility-methods-connect_any) | `func connect_any( source_signals: Array, callback: Callable, owner: Object = null, default_args: Array = [], connect_flags: int = 0 ) -> Array[GFSignalConnection]:` |
| 方法 | [`disconnect_signal`](#member-gfsignalutility-methods-disconnect_signal) | `func disconnect_signal(source_signal: Signal, callback: Callable, owner: Object = null) -> void:` |
| 方法 | [`disconnect_owner`](#member-gfsignalutility-methods-disconnect_owner) | `func disconnect_owner(owner: Object) -> void:` |
| 方法 | [`disconnect_connections`](#member-gfsignalutility-methods-disconnect_connections) | `func disconnect_connections(connections: Array) -> void:` |
| 方法 | [`disconnect_all`](#member-gfsignalutility-methods-disconnect_all) | `func disconnect_all() -> void:` |
| 方法 | [`prune_invalid_connections`](#member-gfsignalutility-methods-prune_invalid_connections) | `func prune_invalid_connections() -> void:` |
| 方法 | [`get_connection_count`](#member-gfsignalutility-methods-get_connection_count) | `func get_connection_count() -> int:` |

## 方法

<a id="member-gfsignalutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放工具持有的所有 Signal 连接。

<a id="member-gfsignalutility-methods-connect_signal"></a>

### `connect_signal`

- API：`public`

```gdscript
func connect_signal( source_signal: Signal, callback: Callable, owner: Object = null, default_args: Array = [], connect_flags: int = 0 ) -> GFSignalConnection:
```

安全连接一个 Signal，并返回可继续链式配置的连接对象。

参数：

| 名称 | 说明 |
|---|---|
| `source_signal` | 要连接或断开的 Godot 信号。 |
| `callback` | 操作完成或事件触发时执行的回调。 |
| `owner` | 监听或连接的拥有者。 |
| `default_args` | 回调调用时追加的默认参数。 |
| `connect_flags` | Godot 信号连接标记。 |

返回：创建或复用的连接对象。

结构：

- `default_args`: Array，调用回调时前置于信号参数之前的参数。

<a id="member-gfsignalutility-methods-connect_once"></a>

### `connect_once`

- API：`public`

```gdscript
func connect_once( source_signal: Signal, callback: Callable, owner: Object = null, default_args: Array = [], connect_flags: int = 0 ) -> GFSignalConnection:
```

创建一次性 Signal 连接。

参数：

| 名称 | 说明 |
|---|---|
| `source_signal` | 要连接或断开的 Godot 信号。 |
| `callback` | 操作完成或事件触发时执行的回调。 |
| `owner` | 监听或连接的拥有者。 |
| `default_args` | 回调调用时追加的默认参数。 |
| `connect_flags` | Godot 信号连接标记。 |

返回：创建或复用的一次性连接对象。

结构：

- `default_args`: Array，调用回调时前置于信号参数之前的参数。

<a id="member-gfsignalutility-methods-connect_any"></a>

### `connect_any`

- API：`public`

```gdscript
func connect_any( source_signals: Array, callback: Callable, owner: Object = null, default_args: Array = [], connect_flags: int = 0 ) -> Array[GFSignalConnection]:
```

批量连接多个 Signal 到同一个回调。

参数：

| 名称 | 说明 |
|---|---|
| `source_signals` | 要连接的一组 Godot 信号。 |
| `callback` | 操作完成或事件触发时执行的回调。 |
| `owner` | 监听或连接的拥有者。 |
| `default_args` | 回调调用时追加的默认参数。 |
| `connect_flags` | Godot 信号连接标记。 |

返回：成功创建或复用的连接列表。

结构：

- `source_signals`: Array，要连接到回调的 Signal 值。
- `default_args`: Array，调用回调时前置于信号参数之前的参数。

<a id="member-gfsignalutility-methods-disconnect_signal"></a>

### `disconnect_signal`

- API：`public`

```gdscript
func disconnect_signal(source_signal: Signal, callback: Callable, owner: Object = null) -> void:
```

断开指定 Signal 与回调的连接。

参数：

| 名称 | 说明 |
|---|---|
| `source_signal` | 要连接或断开的 Godot 信号。 |
| `callback` | 操作完成或事件触发时执行的回调。 |
| `owner` | 监听或连接的拥有者。 |

<a id="member-gfsignalutility-methods-disconnect_owner"></a>

### `disconnect_owner`

- API：`public`

```gdscript
func disconnect_owner(owner: Object) -> void:
```

断开某个 owner 拥有的全部连接。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 监听或连接的拥有者。 |

<a id="member-gfsignalutility-methods-disconnect_connections"></a>

### `disconnect_connections`

- API：`public`

```gdscript
func disconnect_connections(connections: Array) -> void:
```

断开一组由 connect_signal/connect_any 返回的连接。

参数：

| 名称 | 说明 |
|---|---|
| `connections` | 连接对象列表。 |

结构：

- `connections`: Array，由 connect_signal()、connect_once() 或 connect_any() 返回的 GFSignalConnection 句柄。

<a id="member-gfsignalutility-methods-disconnect_all"></a>

### `disconnect_all`

- API：`public`

```gdscript
func disconnect_all() -> void:
```

断开所有连接。

<a id="member-gfsignalutility-methods-prune_invalid_connections"></a>

### `prune_invalid_connections`

- API：`public`

```gdscript
func prune_invalid_connections() -> void:
```

清理已经失效的连接。

<a id="member-gfsignalutility-methods-get_connection_count"></a>

### `get_connection_count`

- API：`public`

```gdscript
func get_connection_count() -> int:
```

获取当前仍被工具追踪的连接数量。

返回：仍被工具追踪的有效连接数量。
