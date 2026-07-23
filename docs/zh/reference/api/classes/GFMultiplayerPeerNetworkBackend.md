# GFMultiplayerPeerNetworkBackend

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/backends/gf_multiplayer_peer_network_backend.gd`
- 模块：`Network`
- 继承：`GFNetworkBackend`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

可接管外部 MultiplayerPeer 的通用网络后端。 平台 Adapter 负责通过 Steam、小游戏或其他 SDK 创建 `MultiplayerPeer`，本类只负责 GF bytes 边界、轮询、连接事件和所有权。它不依赖任何第三方 SDK 类型。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Ownership`](#member-gfmultiplayerpeernetworkbackend-enums-ownership) | `enum Ownership` |
| 枚举 | [`Role`](#member-gfmultiplayerpeernetworkbackend-enums-role) | `enum Role` |
| 常量 | [`BROADCAST_PEER_ID`](#member-gfmultiplayerpeernetworkbackend-constants-broadcast_peer_id) | `const BROADCAST_PEER_ID: int = -1` |
| 属性 | [`max_packets_per_poll`](#member-gfmultiplayerpeernetworkbackend-properties-max_packets_per_poll) | `var max_packets_per_poll: int = 64` |
| 方法 | [`adopt_peer`](#member-gfmultiplayerpeernetworkbackend-methods-adopt_peer) | `func adopt_peer(peer: MultiplayerPeer, options: Dictionary = {}) -> Error:` |
| 方法 | [`get_peer`](#member-gfmultiplayerpeernetworkbackend-methods-get_peer) | `func get_peer() -> MultiplayerPeer:` |
| 方法 | [`take_peer`](#member-gfmultiplayerpeernetworkbackend-methods-take_peer) | `func take_peer() -> MultiplayerPeer:` |
| 方法 | [`owns_peer`](#member-gfmultiplayerpeernetworkbackend-methods-owns_peer) | `func owns_peer() -> bool:` |
| 方法 | [`get_session_bootstrap`](#member-gfmultiplayerpeernetworkbackend-methods-get_session_bootstrap) | `func get_session_bootstrap() -> Dictionary:` |
| 方法 | [`disconnect_backend`](#member-gfmultiplayerpeernetworkbackend-methods-disconnect_backend) | `func disconnect_backend() -> void:` |
| 方法 | [`send_bytes`](#member-gfmultiplayerpeernetworkbackend-methods-send_bytes) | `func send_bytes( peer_id: int, bytes: PackedByteArray, options: Dictionary = {} ) -> Error:` |
| 方法 | [`poll`](#member-gfmultiplayerpeernetworkbackend-methods-poll) | `func poll(_delta: float) -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfmultiplayerpeernetworkbackend-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 枚举

<a id="member-gfmultiplayerpeernetworkbackend-enums-ownership"></a>

### `Ownership`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Ownership {
	## Backend 只借用 Peer，释放时不得关闭它。
	BORROWED,
	## Backend 拥有 Peer，释放时负责关闭它。
	OWNED,
}
```

被接管 Peer 的所有权。

<a id="member-gfmultiplayerpeernetworkbackend-enums-role"></a>

### `Role`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Role {
	## Adapter 未声明角色。
	UNKNOWN,
	## 主机或服务器。
	SERVER,
	## 客户端。
	CLIENT,
}
```

Peer 在当前会话中的角色。

## 常量

<a id="member-gfmultiplayerpeernetworkbackend-constants-broadcast_peer_id"></a>

### `BROADCAST_PEER_ID`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const BROADCAST_PEER_ID: int = -1
```

广播 peer 标识。

## 属性

<a id="member-gfmultiplayerpeernetworkbackend-properties-max_packets_per_poll"></a>

### `max_packets_per_poll`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_packets_per_poll: int = 64
```

每次 poll 最多派发的入站包数量。小于等于 0 表示不限制。

## 方法

<a id="member-gfmultiplayerpeernetworkbackend-methods-adopt_peer"></a>

### `adopt_peer`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func adopt_peer(peer: MultiplayerPeer, options: Dictionary = {}) -> Error:
```

接管一个已由外部 Adapter 初始化的 MultiplayerPeer。 Peer 必须已经处于 connecting 或 connected。替换现有 Peer 时，旧 Peer 会按其 ownership 关闭或仅解除借用。

参数：

| 名称 | 说明 |
|---|---|
| `peer` | 外部创建的 MultiplayerPeer。 |
| `options` | 支持 ownership、role、endpoint、supports_channels 和 supports_transfer_modes。 |

返回：Godot 错误码。

结构：

- `options`: Dictionary adoptable MultiplayerPeer capabilities and ownership.

<a id="member-gfmultiplayerpeernetworkbackend-methods-get_peer"></a>

### `get_peer`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_peer() -> MultiplayerPeer:
```

获取当前 Peer 的借用引用。 该引用只用于 Provider 状态检查，不得 poll、读取包或装配到 SceneTree.multiplayer； Backend 独占 Peer 数据面。需要交给 SceneMultiplayer 时先使用 `take_peer()`。

返回：当前 Peer；未配置时返回 null。

<a id="member-gfmultiplayerpeernetworkbackend-methods-take_peer"></a>

### `take_peer`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func take_peer() -> MultiplayerPeer:
```

将 Peer 及其关闭责任转移给调用方。

返回：原 Peer；未配置时返回 null。

<a id="member-gfmultiplayerpeernetworkbackend-methods-owns_peer"></a>

### `owns_peer`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func owns_peer() -> bool:
```

检查 Backend 是否拥有当前 Peer。

返回：当前 Peer 存在且 ownership 为 OWNED 时返回 true。

<a id="member-gfmultiplayerpeernetworkbackend-methods-get_session_bootstrap"></a>

### `get_session_bootstrap`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_session_bootstrap() -> Dictionary:
```

获取外部 Peer 的会话接管字段。

返回：role 对应的 Session mode、端点和本地 peer ID。

结构：

- `return`: Dictionary network session bootstrap fields.

<a id="member-gfmultiplayerpeernetworkbackend-methods-disconnect_backend"></a>

### `disconnect_backend`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func disconnect_backend() -> void:
```

断开并释放当前 Peer。 OWNED Peer 会关闭；BORROWED Peer 只解除信号和引用，由外部 Adapter 继续管理。

<a id="member-gfmultiplayerpeernetworkbackend-methods-send_bytes"></a>

### `send_bytes`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func send_bytes( peer_id: int, bytes: PackedByteArray, options: Dictionary = {} ) -> Error:
```

发送 bytes。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 目标 peer；-1 表示广播。 |
| `bytes` | 消息 bytes。 |
| `options` | 支持 channel、transfer_mode 和 reliable。 |

返回：Godot 错误码。

结构：

- `options`: Dictionary generic MultiplayerPeer send options.

<a id="member-gfmultiplayerpeernetworkbackend-methods-poll"></a>

### `poll`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func poll(_delta: float) -> void:
```

轮询 Peer 状态和入站包。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 本帧时间增量；底层 MultiplayerPeer 自行维护时钟。 |

<a id="member-gfmultiplayerpeernetworkbackend-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取 Backend 调试快照。

返回：已脱敏 Backend 状态。

结构：

- `return`: Dictionary adoptable MultiplayerPeer backend snapshot.
