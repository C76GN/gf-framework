# GFNetworkSession

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_session.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

网络会话状态快照。 记录当前网络工具的主机/客户端意图与连接状态，不绑定房间、账号或匹配逻辑。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`session_started`](#member-gfnetworksession-signals-session_started) | `signal session_started(mode: int, endpoint: String)` |
| 信号 | [`session_connected`](#member-gfnetworksession-signals-session_connected) | `signal session_connected(local_peer_id: int)` |
| 信号 | [`session_closed`](#member-gfnetworksession-signals-session_closed) | `signal session_closed(reason: String)` |
| 枚举 | [`Mode`](#member-gfnetworksession-enums-mode) | `enum Mode` |
| 属性 | [`mode`](#member-gfnetworksession-properties-mode) | `var mode: Mode = Mode.NONE` |
| 属性 | [`endpoint`](#member-gfnetworksession-properties-endpoint) | `var endpoint: String = ""` |
| 属性 | [`local_peer_id`](#member-gfnetworksession-properties-local_peer_id) | `var local_peer_id: int = -1` |
| 属性 | [`max_peers`](#member-gfnetworksession-properties-max_peers) | `var max_peers: int = 0` |
| 属性 | [`is_active`](#member-gfnetworksession-properties-is_active) | `var is_active: bool = false` |
| 属性 | [`has_connection`](#member-gfnetworksession-properties-has_connection) | `var has_connection: bool = false` |
| 属性 | [`started_at_unix`](#member-gfnetworksession-properties-started_at_unix) | `var started_at_unix: float = 0.0` |
| 属性 | [`metadata`](#member-gfnetworksession-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`start_host`](#member-gfnetworksession-methods-start_host) | `func start_host(options: Dictionary = {}) -> void:` |
| 方法 | [`start_client`](#member-gfnetworksession-methods-start_client) | `func start_client(next_endpoint: String, options: Dictionary = {}) -> void:` |
| 方法 | [`mark_connected`](#member-gfnetworksession-methods-mark_connected) | `func mark_connected(next_local_peer_id: int = -1) -> void:` |
| 方法 | [`close`](#member-gfnetworksession-methods-close) | `func close(reason: String = "closed") -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfnetworksession-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfnetworksession-signals-session_started"></a>

### `session_started`

- API：`public`

```gdscript
signal session_started(mode: int, endpoint: String)
```

会话开始时发出。

参数：

| 名称 | 说明 |
|---|---|
| `mode` | Mode 枚举值。 |
| `endpoint` | 会话端点。 |

<a id="member-gfnetworksession-signals-session_connected"></a>

### `session_connected`

- API：`public`

```gdscript
signal session_connected(local_peer_id: int)
```

会话连接成功时发出。

参数：

| 名称 | 说明 |
|---|---|
| `local_peer_id` | 本地 peer 标识。 |

<a id="member-gfnetworksession-signals-session_closed"></a>

### `session_closed`

- API：`public`

```gdscript
signal session_closed(reason: String)
```

会话关闭时发出。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 关闭原因。 |

## 枚举

<a id="member-gfnetworksession-enums-mode"></a>

### `Mode`

- API：`public`

```gdscript
enum Mode {
	## 无活动会话。
	NONE,
	## 主机会话。
	HOST,
	## 客户端会话。
	CLIENT,
}
```

会话模式。

## 属性

<a id="member-gfnetworksession-properties-mode"></a>

### `mode`

- API：`public`

```gdscript
var mode: Mode = Mode.NONE
```

当前模式。

<a id="member-gfnetworksession-properties-endpoint"></a>

### `endpoint`

- API：`public`

```gdscript
var endpoint: String = ""
```

会话端点。

<a id="member-gfnetworksession-properties-local_peer_id"></a>

### `local_peer_id`

- API：`public`

```gdscript
var local_peer_id: int = -1
```

本地 peer 标识。

<a id="member-gfnetworksession-properties-max_peers"></a>

### `max_peers`

- API：`public`

```gdscript
var max_peers: int = 0
```

最大远端数量。

<a id="member-gfnetworksession-properties-is_active"></a>

### `is_active`

- API：`public`

```gdscript
var is_active: bool = false
```

会话是否已经启动。

<a id="member-gfnetworksession-properties-has_connection"></a>

### `has_connection`

- API：`public`

```gdscript
var has_connection: bool = false
```

后端是否已报告连接成功。

<a id="member-gfnetworksession-properties-started_at_unix"></a>

### `started_at_unix`

- API：`public`

```gdscript
var started_at_unix: float = 0.0
```

启动时间。

<a id="member-gfnetworksession-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。

结构：

- `metadata`: Dictionary，保存项目自定义会话元数据。

## 方法

<a id="member-gfnetworksession-methods-start_host"></a>

### `start_host`

- API：`public`

```gdscript
func start_host(options: Dictionary = {}) -> void:
```

标记主机会话已开始。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 启动选项。 |

结构：

- `options`: Dictionary，支持 endpoint、port、max_clients、max_peers、local_peer_id、metadata。

<a id="member-gfnetworksession-methods-start_client"></a>

### `start_client`

- API：`public`

```gdscript
func start_client(next_endpoint: String, options: Dictionary = {}) -> void:
```

标记客户端会话已开始。

参数：

| 名称 | 说明 |
|---|---|
| `next_endpoint` | 远端端点。 |
| `options` | 连接选项。 |

结构：

- `options`: Dictionary，支持 max_peers、local_peer_id、metadata。

<a id="member-gfnetworksession-methods-mark_connected"></a>

### `mark_connected`

- API：`public`

```gdscript
func mark_connected(next_local_peer_id: int = -1) -> void:
```

标记后端已经连接。

参数：

| 名称 | 说明 |
|---|---|
| `next_local_peer_id` | 本地 peer；小于 0 时保留原值。 |

<a id="member-gfnetworksession-methods-close"></a>

### `close`

- API：`public`

```gdscript
func close(reason: String = "closed") -> void:
```

关闭会话。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 关闭原因。 |

<a id="member-gfnetworksession-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：会话状态字典。

结构：

- `return`: Dictionary，包含 mode、mode_name、endpoint、local_peer_id、max_peers、is_active、has_connection、started_at_unix、metadata。
