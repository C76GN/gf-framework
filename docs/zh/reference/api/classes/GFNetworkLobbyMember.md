# GFNetworkLobbyMember

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_lobby_member.gd`
- 模块：`Network`
- 继承：`Resource`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`8.0.0`

平台中立的 lobby 成员描述。 成员只描述 peer 身份、owner/local 标记和 metadata，不承载玩家业务状态、 准备状态、角色选择或 UI 信息。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`peer_id`](#member-gfnetworklobbymember-properties-peer_id) | `var peer_id: int = -1` |
| 属性 | [`identity`](#member-gfnetworklobbymember-properties-identity) | `var identity: GFNetworkPeerIdentity = null` |
| 属性 | [`is_owner`](#member-gfnetworklobbymember-properties-is_owner) | `var is_owner: bool = false` |
| 属性 | [`is_local`](#member-gfnetworklobbymember-properties-is_local) | `var is_local: bool = false` |
| 属性 | [`metadata`](#member-gfnetworklobbymember-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfnetworklobbymember-methods-configure) | `func configure( p_peer_id: int = -1, p_identity: GFNetworkPeerIdentity = null, p_metadata: Dictionary = {}, options: Dictionary = {} ) -> GFNetworkLobbyMember:` |
| 方法 | [`get_display_name`](#member-gfnetworklobbymember-methods-get_display_name) | `func get_display_name() -> String:` |
| 方法 | [`to_dict`](#member-gfnetworklobbymember-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfnetworklobbymember-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_member`](#member-gfnetworklobbymember-methods-duplicate_member) | `func duplicate_member() -> GFNetworkLobbyMember:` |
| 方法 | [`from_dict`](#member-gfnetworklobbymember-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFNetworkLobbyMember:` |

## 属性

<a id="member-gfnetworklobbymember-properties-peer_id"></a>

### `peer_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var peer_id: int = -1
```

成员传输 peer 标识。

<a id="member-gfnetworklobbymember-properties-identity"></a>

### `identity`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var identity: GFNetworkPeerIdentity = null
```

成员身份描述。

<a id="member-gfnetworklobbymember-properties-is_owner"></a>

### `is_owner`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var is_owner: bool = false
```

是否为 lobby owner。

<a id="member-gfnetworklobbymember-properties-is_local"></a>

### `is_local`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var is_local: bool = false
```

是否为本地成员。

<a id="member-gfnetworklobbymember-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方自定义成员元数据。

结构：

- `metadata`: Dictionary caller-defined member metadata.

## 方法

<a id="member-gfnetworklobbymember-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure( p_peer_id: int = -1, p_identity: GFNetworkPeerIdentity = null, p_metadata: Dictionary = {}, options: Dictionary = {} ) -> GFNetworkLobbyMember:
```

配置成员。

参数：

| 名称 | 说明 |
|---|---|
| `p_peer_id` | 成员传输 peer 标识。 |
| `p_identity` | 成员身份。 |
| `p_metadata` | 成员元数据。 |
| `options` | 可选项，支持 is_owner 和 is_local。 |

返回：当前成员。

结构：

- `p_metadata`: Dictionary caller-defined member metadata.
- `options`: Dictionary member flags.

<a id="member-gfnetworklobbymember-methods-get_display_name"></a>

### `get_display_name`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_display_name() -> String:
```

获取展示名称。

返回：展示名称。

<a id="member-gfnetworklobbymember-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：成员字典。

结构：

- `return`: Dictionary with peer_id, identity, is_owner, is_local, and metadata.

<a id="member-gfnetworklobbymember-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用成员字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 成员字典。 |

结构：

- `data`: Dictionary with peer_id, identity, is_owner, is_local, and metadata.

<a id="member-gfnetworklobbymember-methods-duplicate_member"></a>

### `duplicate_member`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_member() -> GFNetworkLobbyMember:
```

创建成员深拷贝。

返回：新成员。

<a id="member-gfnetworklobbymember-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFNetworkLobbyMember:
```

从字典创建成员。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 成员字典。 |

返回：新成员。

结构：

- `data`: Dictionary with peer_id, identity, is_owner, is_local, and metadata.
