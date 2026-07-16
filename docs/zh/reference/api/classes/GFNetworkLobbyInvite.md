# GFNetworkLobbyInvite

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_lobby_invite.gd`
- 模块：`Network`
- 继承：`Resource`
- API：`public`
- 类别：事件契约 (`event_contract`)
- 首次版本：`8.0.0`

平台中立的 lobby 邀请事件。 邀请只表达发送方、目标方和 lobby 入口信息。好友 UI、每日任务、奖励等业务策略 必须留在项目层或外部 adapter 中。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`invite_id`](#member-gfnetworklobbyinvite-properties-invite_id) | `var invite_id: String = ""` |
| 属性 | [`lobby_id`](#member-gfnetworklobbyinvite-properties-lobby_id) | `var lobby_id: String = ""` |
| 属性 | [`backend_id`](#member-gfnetworklobbyinvite-properties-backend_id) | `var backend_id: StringName = &""` |
| 属性 | [`sender`](#member-gfnetworklobbyinvite-properties-sender) | `var sender: GFNetworkPeerIdentity = null` |
| 属性 | [`target`](#member-gfnetworklobbyinvite-properties-target) | `var target: GFNetworkPeerIdentity = null` |
| 属性 | [`message`](#member-gfnetworklobbyinvite-properties-message) | `var message: String = ""` |
| 属性 | [`metadata`](#member-gfnetworklobbyinvite-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`to_dict`](#member-gfnetworklobbyinvite-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfnetworklobbyinvite-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_invite`](#member-gfnetworklobbyinvite-methods-duplicate_invite) | `func duplicate_invite() -> GFNetworkLobbyInvite:` |
| 方法 | [`from_dict`](#member-gfnetworklobbyinvite-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFNetworkLobbyInvite:` |

## 属性

<a id="member-gfnetworklobbyinvite-properties-invite_id"></a>

### `invite_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var invite_id: String = ""
```

邀请 ID。没有平台邀请 ID 时可为空。

<a id="member-gfnetworklobbyinvite-properties-lobby_id"></a>

### `lobby_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var lobby_id: String = ""
```

相关 lobby ID。

<a id="member-gfnetworklobbyinvite-properties-backend_id"></a>

### `backend_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var backend_id: StringName = &""
```

提供邀请的 backend 标识。

<a id="member-gfnetworklobbyinvite-properties-sender"></a>

### `sender`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var sender: GFNetworkPeerIdentity = null
```

邀请发送方身份。

<a id="member-gfnetworklobbyinvite-properties-target"></a>

### `target`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var target: GFNetworkPeerIdentity = null
```

邀请目标身份。

<a id="member-gfnetworklobbyinvite-properties-message"></a>

### `message`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var message: String = ""
```

人读说明或平台侧附带消息。

<a id="member-gfnetworklobbyinvite-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方自定义元数据。

结构：

- `metadata`: Dictionary caller-defined invite metadata.

## 方法

<a id="member-gfnetworklobbyinvite-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：邀请字典。

结构：

- `return`: Dictionary with invite_id, lobby_id, backend_id, sender, target, message, and metadata.

<a id="member-gfnetworklobbyinvite-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用邀请字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 邀请字典。 |

结构：

- `data`: Dictionary with invite_id, lobby_id, backend_id, sender, target, message, and metadata.

<a id="member-gfnetworklobbyinvite-methods-duplicate_invite"></a>

### `duplicate_invite`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_invite() -> GFNetworkLobbyInvite:
```

创建邀请深拷贝。

返回：新邀请。

<a id="member-gfnetworklobbyinvite-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFNetworkLobbyInvite:
```

从字典创建邀请。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 邀请字典。 |

返回：新邀请。

结构：

- `data`: Dictionary with invite_id, lobby_id, backend_id, sender, target, message, and metadata.
