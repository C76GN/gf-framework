# GFNetworkPeerIdentity

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_peer_identity.gd`
- 模块：`Network`
- 继承：`Resource`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`8.0.0`

网络 peer 与外部平台账号之间的中立身份描述。 该资源只保存传输 peer、平台账号和展示元信息之间的映射，不绑定 Steam、微信、 Epic、自建账号或任何具体平台 SDK。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`peer_id`](#member-gfnetworkpeeridentity-properties-peer_id) | `var peer_id: int = -1` |
| 属性 | [`platform_id`](#member-gfnetworkpeeridentity-properties-platform_id) | `var platform_id: StringName = &""` |
| 属性 | [`platform_user_id`](#member-gfnetworkpeeridentity-properties-platform_user_id) | `var platform_user_id: String = ""` |
| 属性 | [`display_name`](#member-gfnetworkpeeridentity-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`avatar_uri`](#member-gfnetworkpeeridentity-properties-avatar_uri) | `var avatar_uri: String = ""` |
| 属性 | [`capabilities`](#member-gfnetworkpeeridentity-properties-capabilities) | `var capabilities: PackedStringArray = PackedStringArray()` |
| 属性 | [`metadata`](#member-gfnetworkpeeridentity-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfnetworkpeeridentity-methods-configure) | `func configure( p_peer_id: int = -1, p_platform_id: StringName = &"", p_platform_user_id: String = "", p_display_name: String = "", p_metadata: Dictionary = {}, p_capabilities: PackedStringArray = PackedStringArray() ) -> GFNetworkPeerIdentity:` |
| 方法 | [`add_capability`](#member-gfnetworkpeeridentity-methods-add_capability) | `func add_capability(capability_id: StringName) -> bool:` |
| 方法 | [`has_capability`](#member-gfnetworkpeeridentity-methods-has_capability) | `func has_capability(capability_id: StringName) -> bool:` |
| 方法 | [`get_stable_key`](#member-gfnetworkpeeridentity-methods-get_stable_key) | `func get_stable_key() -> String:` |
| 方法 | [`to_dict`](#member-gfnetworkpeeridentity-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfnetworkpeeridentity-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_identity`](#member-gfnetworkpeeridentity-methods-duplicate_identity) | `func duplicate_identity() -> GFNetworkPeerIdentity:` |
| 方法 | [`get_debug_snapshot`](#member-gfnetworkpeeridentity-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfnetworkpeeridentity-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFNetworkPeerIdentity:` |

## 属性

<a id="member-gfnetworkpeeridentity-properties-peer_id"></a>

### `peer_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var peer_id: int = -1
```

传输层 peer 标识。-1 表示未知或尚未绑定传输连接。

<a id="member-gfnetworkpeeridentity-properties-platform_id"></a>

### `platform_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var platform_id: StringName = &""
```

平台标识，例如 steam、wechat、lan 或 custom。GF 不解释具体平台语义。

<a id="member-gfnetworkpeeridentity-properties-platform_user_id"></a>

### `platform_user_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var platform_user_id: String = ""
```

平台侧用户标识。动态外部 ID 使用 String 保存，避免把第三方账号体系写入 GF 类型系统。

<a id="member-gfnetworkpeeridentity-properties-display_name"></a>

### `display_name`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var display_name: String = ""
```

面向 UI 的显示名。框架不保证唯一性。

<a id="member-gfnetworkpeeridentity-properties-avatar_uri"></a>

### `avatar_uri`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var avatar_uri: String = ""
```

可选头像或资料图标 URI。由项目或 adapter 解释。

<a id="member-gfnetworkpeeridentity-properties-capabilities"></a>

### `capabilities`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var capabilities: PackedStringArray = PackedStringArray()
```

身份具备的平台能力标识。

<a id="member-gfnetworkpeeridentity-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary caller-defined identity metadata.

## 方法

<a id="member-gfnetworkpeeridentity-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure( p_peer_id: int = -1, p_platform_id: StringName = &"", p_platform_user_id: String = "", p_display_name: String = "", p_metadata: Dictionary = {}, p_capabilities: PackedStringArray = PackedStringArray() ) -> GFNetworkPeerIdentity:
```

配置身份资源。

参数：

| 名称 | 说明 |
|---|---|
| `p_peer_id` | 传输层 peer 标识。 |
| `p_platform_id` | 平台标识。 |
| `p_platform_user_id` | 平台侧用户标识。 |
| `p_display_name` | 显示名。 |
| `p_metadata` | 调用方元数据。 |
| `p_capabilities` | 平台能力标识列表。 |

返回：当前身份资源。

结构：

- `p_metadata`: Dictionary caller-defined identity metadata.

<a id="member-gfnetworkpeeridentity-methods-add_capability"></a>

### `add_capability`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func add_capability(capability_id: StringName) -> bool:
```

添加能力标识。

参数：

| 名称 | 说明 |
|---|---|
| `capability_id` | 能力标识。 |

返回：成功添加或已存在时返回 true。

<a id="member-gfnetworkpeeridentity-methods-has_capability"></a>

### `has_capability`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_capability(capability_id: StringName) -> bool:
```

检查能力标识是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `capability_id` | 能力标识。 |

返回：存在返回 true。

<a id="member-gfnetworkpeeridentity-methods-get_stable_key"></a>

### `get_stable_key`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_stable_key() -> String:
```

获取稳定身份 key。

返回：身份 key；优先使用 platform_id:platform_user_id，缺失时回退到 peer:<peer_id>。

<a id="member-gfnetworkpeeridentity-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：身份字典。

结构：

- `return`: Dictionary with peer_id, platform_id, platform_user_id, display_name, avatar_uri, capabilities, and metadata.

<a id="member-gfnetworkpeeridentity-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用身份字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 身份字典。 |

结构：

- `data`: Dictionary with peer_id, platform_id, platform_user_id, display_name, avatar_uri, capabilities, and metadata.

<a id="member-gfnetworkpeeridentity-methods-duplicate_identity"></a>

### `duplicate_identity`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_identity() -> GFNetworkPeerIdentity:
```

创建身份深拷贝。

返回：新身份资源。

<a id="member-gfnetworkpeeridentity-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照。

结构：

- `return`: Dictionary JSON-safe identity debug snapshot.

<a id="member-gfnetworkpeeridentity-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFNetworkPeerIdentity:
```

从字典创建身份资源。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 身份字典。 |

返回：新身份资源。

结构：

- `data`: Dictionary with peer_id, platform_id, platform_user_id, display_name, avatar_uri, capabilities, and metadata.
