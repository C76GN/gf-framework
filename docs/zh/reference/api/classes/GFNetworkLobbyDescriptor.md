# GFNetworkLobbyDescriptor

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_lobby_descriptor.gd`
- 模块：`Network`
- 继承：`Resource`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`8.0.0`

平台中立的 lobby 快照。 描述外部平台、局域网或自建服务中的房间状态。它只承载可复用的联机结构， 不把玩家准备、队伍、角色或具体玩法写入框架层。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Visibility`](#member-gfnetworklobbydescriptor-enums-visibility) | `enum Visibility` |
| 属性 | [`lobby_id`](#member-gfnetworklobbydescriptor-properties-lobby_id) | `var lobby_id: String = ""` |
| 属性 | [`backend_id`](#member-gfnetworklobbydescriptor-properties-backend_id) | `var backend_id: StringName = &""` |
| 属性 | [`display_name`](#member-gfnetworklobbydescriptor-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`owner_peer_id`](#member-gfnetworklobbydescriptor-properties-owner_peer_id) | `var owner_peer_id: int = -1` |
| 属性 | [`owner_platform_user_id`](#member-gfnetworklobbydescriptor-properties-owner_platform_user_id) | `var owner_platform_user_id: String = ""` |
| 属性 | [`max_members`](#member-gfnetworklobbydescriptor-properties-max_members) | `var max_members: int = 0` |
| 属性 | [`joinable`](#member-gfnetworklobbydescriptor-properties-joinable) | `var joinable: bool = true` |
| 属性 | [`visibility`](#member-gfnetworklobbydescriptor-properties-visibility) | `var visibility: Visibility = Visibility.DEFAULT` |
| 属性 | [`members`](#member-gfnetworklobbydescriptor-properties-members) | `var members: Array[GFNetworkLobbyMember] = []` |
| 属性 | [`tags`](#member-gfnetworklobbydescriptor-properties-tags) | `var tags: PackedStringArray = PackedStringArray()` |
| 属性 | [`metadata`](#member-gfnetworklobbydescriptor-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfnetworklobbydescriptor-methods-configure) | `func configure(p_lobby_id: String, options: Dictionary = {}) -> GFNetworkLobbyDescriptor:` |
| 方法 | [`get_display_name`](#member-gfnetworklobbydescriptor-methods-get_display_name) | `func get_display_name() -> String:` |
| 方法 | [`get_member_count`](#member-gfnetworklobbydescriptor-methods-get_member_count) | `func get_member_count() -> int:` |
| 方法 | [`is_full`](#member-gfnetworklobbydescriptor-methods-is_full) | `func is_full() -> bool:` |
| 方法 | [`get_member`](#member-gfnetworklobbydescriptor-methods-get_member) | `func get_member(peer_id: int) -> GFNetworkLobbyMember:` |
| 方法 | [`set_member`](#member-gfnetworklobbydescriptor-methods-set_member) | `func set_member(member: GFNetworkLobbyMember) -> void:` |
| 方法 | [`remove_member`](#member-gfnetworklobbydescriptor-methods-remove_member) | `func remove_member(peer_id: int) -> bool:` |
| 方法 | [`to_dict`](#member-gfnetworklobbydescriptor-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfnetworklobbydescriptor-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_lobby`](#member-gfnetworklobbydescriptor-methods-duplicate_lobby) | `func duplicate_lobby() -> GFNetworkLobbyDescriptor:` |
| 方法 | [`get_debug_snapshot`](#member-gfnetworklobbydescriptor-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfnetworklobbydescriptor-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFNetworkLobbyDescriptor:` |

## 枚举

<a id="member-gfnetworklobbydescriptor-enums-visibility"></a>

### `Visibility`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
enum Visibility {
	## 由 backend 或平台默认策略决定。
	DEFAULT,
	## 可公开查询。
	PUBLIC,
	## 仅好友、群组或平台关系可见。
	RELATIONSHIP,
	## 只能通过邀请或精确 ID 加入。
	PRIVATE,
	## 不可查询且不可加入。
	HIDDEN,
}
```

Lobby 可见性。

## 属性

<a id="member-gfnetworklobbydescriptor-properties-lobby_id"></a>

### `lobby_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var lobby_id: String = ""
```

Lobby 外部稳定 ID。动态平台 ID 使用 String 保存。

<a id="member-gfnetworklobbydescriptor-properties-backend_id"></a>

### `backend_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var backend_id: StringName = &""
```

提供该 lobby 的 backend 标识。

<a id="member-gfnetworklobbydescriptor-properties-display_name"></a>

### `display_name`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var display_name: String = ""
```

编辑器或 UI 可显示名称。

<a id="member-gfnetworklobbydescriptor-properties-owner_peer_id"></a>

### `owner_peer_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var owner_peer_id: int = -1
```

owner 的传输 peer 标识。未知时为 -1。

<a id="member-gfnetworklobbydescriptor-properties-owner_platform_user_id"></a>

### `owner_platform_user_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var owner_platform_user_id: String = ""
```

owner 的平台用户 ID。用于尚未建立传输连接但平台已返回 owner 的场景。

<a id="member-gfnetworklobbydescriptor-properties-max_members"></a>

### `max_members`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_members: int = 0
```

最大成员数。小于等于 0 表示 backend 未声明。

<a id="member-gfnetworklobbydescriptor-properties-joinable"></a>

### `joinable`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var joinable: bool = true
```

当前是否允许加入。

<a id="member-gfnetworklobbydescriptor-properties-visibility"></a>

### `visibility`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var visibility: Visibility = Visibility.DEFAULT
```

Lobby 可见性。

<a id="member-gfnetworklobbydescriptor-properties-members"></a>

### `members`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var members: Array[GFNetworkLobbyMember] = []
```

成员列表。

结构：

- `members`: Array[GFNetworkLobbyMember] lobby member snapshots.

<a id="member-gfnetworklobbydescriptor-properties-tags"></a>

### `tags`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var tags: PackedStringArray = PackedStringArray()
```

Lobby 标签，用于轻量查询或展示。

<a id="member-gfnetworklobbydescriptor-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方自定义 lobby metadata。

结构：

- `metadata`: Dictionary caller-defined lobby metadata.

## 方法

<a id="member-gfnetworklobbydescriptor-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure(p_lobby_id: String, options: Dictionary = {}) -> GFNetworkLobbyDescriptor:
```

配置 lobby 快照。

参数：

| 名称 | 说明 |
|---|---|
| `p_lobby_id` | Lobby 外部稳定 ID。 |
| `options` | 可选字段，支持 backend_id、display_name、owner_peer_id、owner_platform_user_id、max_members、joinable、visibility、members、tags 和 metadata。 |

返回：当前 lobby。

结构：

- `options`: Dictionary lobby fields.

<a id="member-gfnetworklobbydescriptor-methods-get_display_name"></a>

### `get_display_name`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_display_name() -> String:
```

获取展示名称。

返回：展示名称。

<a id="member-gfnetworklobbydescriptor-methods-get_member_count"></a>

### `get_member_count`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_member_count() -> int:
```

获取成员数量。

返回：成员数量。

<a id="member-gfnetworklobbydescriptor-methods-is_full"></a>

### `is_full`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_full() -> bool:
```

检查 lobby 是否已满。

返回：已满返回 true；未声明 max_members 时返回 false。

<a id="member-gfnetworklobbydescriptor-methods-get_member"></a>

### `get_member`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_member(peer_id: int) -> GFNetworkLobbyMember:
```

获取成员。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 传输 peer 标识。 |

返回：成员；不存在时返回 null。

<a id="member-gfnetworklobbydescriptor-methods-set_member"></a>

### `set_member`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_member(member: GFNetworkLobbyMember) -> void:
```

设置或替换成员。

参数：

| 名称 | 说明 |
|---|---|
| `member` | 成员。 |

<a id="member-gfnetworklobbydescriptor-methods-remove_member"></a>

### `remove_member`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func remove_member(peer_id: int) -> bool:
```

移除成员。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 传输 peer 标识。 |

返回：找到并移除时返回 true。

<a id="member-gfnetworklobbydescriptor-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：Lobby 字典。

结构：

- `return`: Dictionary with lobby_id, backend_id, display_name, owner_peer_id, owner_platform_user_id, max_members, joinable, visibility, members, tags, and metadata.

<a id="member-gfnetworklobbydescriptor-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用 lobby 字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | Lobby 字典。 |

结构：

- `data`: Dictionary with lobby_id, backend_id, display_name, owner_peer_id, owner_platform_user_id, max_members, joinable, visibility, members, tags, and metadata.

<a id="member-gfnetworklobbydescriptor-methods-duplicate_lobby"></a>

### `duplicate_lobby`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_lobby() -> GFNetworkLobbyDescriptor:
```

创建 lobby 深拷贝。

返回：新 lobby。

<a id="member-gfnetworklobbydescriptor-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照。

结构：

- `return`: Dictionary JSON-safe lobby debug snapshot.

<a id="member-gfnetworklobbydescriptor-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFNetworkLobbyDescriptor:
```

从字典创建 lobby。

参数：

| 名称 | 说明 |
|---|---|
| `data` | Lobby 字典。 |

返回：新 lobby。

结构：

- `data`: Dictionary with lobby_id, backend_id, display_name, owner_peer_id, owner_platform_user_id, max_members, joinable, visibility, members, tags, and metadata.
