# GFNetworkLobbyJoinResult

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_lobby_join_result.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`8.0.0`

Lobby 创建或加入结果。 该值对象统一表达同步或异步 backend 的最终结果，避免项目代码直接依赖 平台 SDK 的错误码枚举。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`ok`](#member-gfnetworklobbyjoinresult-properties-ok) | `var ok: bool = false` |
| 属性 | [`lobby_id`](#member-gfnetworklobbyjoinresult-properties-lobby_id) | `var lobby_id: String = ""` |
| 属性 | [`lobby`](#member-gfnetworklobbyjoinresult-properties-lobby) | `var lobby: GFNetworkLobbyDescriptor = null` |
| 属性 | [`error`](#member-gfnetworklobbyjoinresult-properties-error) | `var error: StringName = &""` |
| 属性 | [`message`](#member-gfnetworklobbyjoinresult-properties-message) | `var message: String = ""` |
| 属性 | [`metadata`](#member-gfnetworklobbyjoinresult-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure_success`](#member-gfnetworklobbyjoinresult-methods-configure_success) | `func configure_success(p_lobby: GFNetworkLobbyDescriptor, p_metadata: Dictionary = {}) -> GFNetworkLobbyJoinResult:` |
| 方法 | [`configure_failure`](#member-gfnetworklobbyjoinresult-methods-configure_failure) | `func configure_failure( p_lobby_id: String, p_error: StringName, p_message: String = "", p_metadata: Dictionary = {} ) -> GFNetworkLobbyJoinResult:` |
| 方法 | [`to_dict`](#member-gfnetworklobbyjoinresult-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfnetworklobbyjoinresult-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_result`](#member-gfnetworklobbyjoinresult-methods-duplicate_result) | `func duplicate_result() -> GFNetworkLobbyJoinResult:` |
| 方法 | [`success`](#member-gfnetworklobbyjoinresult-methods-success) | `static func success(lobby_value: GFNetworkLobbyDescriptor, metadata_value: Dictionary = {}) -> GFNetworkLobbyJoinResult:` |
| 方法 | [`failure`](#member-gfnetworklobbyjoinresult-methods-failure) | `static func failure( lobby_id_value: String, error_value: StringName, message_value: String = "", metadata_value: Dictionary = {} ) -> GFNetworkLobbyJoinResult:` |
| 方法 | [`from_dict`](#member-gfnetworklobbyjoinresult-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFNetworkLobbyJoinResult:` |

## 属性

<a id="member-gfnetworklobbyjoinresult-properties-ok"></a>

### `ok`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var ok: bool = false
```

操作是否成功。

<a id="member-gfnetworklobbyjoinresult-properties-lobby_id"></a>

### `lobby_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var lobby_id: String = ""
```

相关 lobby ID。

<a id="member-gfnetworklobbyjoinresult-properties-lobby"></a>

### `lobby`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var lobby: GFNetworkLobbyDescriptor = null
```

成功时的 lobby 快照。

<a id="member-gfnetworklobbyjoinresult-properties-error"></a>

### `error`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var error: StringName = &""
```

失败原因标识。

<a id="member-gfnetworklobbyjoinresult-properties-message"></a>

### `message`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var message: String = ""
```

人读说明。

<a id="member-gfnetworklobbyjoinresult-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方自定义元数据。

结构：

- `metadata`: Dictionary caller-defined result metadata.

## 方法

<a id="member-gfnetworklobbyjoinresult-methods-configure_success"></a>

### `configure_success`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure_success(p_lobby: GFNetworkLobbyDescriptor, p_metadata: Dictionary = {}) -> GFNetworkLobbyJoinResult:
```

配置成功结果。

参数：

| 名称 | 说明 |
|---|---|
| `p_lobby` | Lobby 快照。 |
| `p_metadata` | 调用方元数据。 |

返回：当前结果。

结构：

- `p_metadata`: Dictionary caller-defined result metadata.

<a id="member-gfnetworklobbyjoinresult-methods-configure_failure"></a>

### `configure_failure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure_failure( p_lobby_id: String, p_error: StringName, p_message: String = "", p_metadata: Dictionary = {} ) -> GFNetworkLobbyJoinResult:
```

配置失败结果。

参数：

| 名称 | 说明 |
|---|---|
| `p_lobby_id` | 相关 lobby ID。 |
| `p_error` | 失败原因标识。 |
| `p_message` | 人读说明。 |
| `p_metadata` | 调用方元数据。 |

返回：当前结果。

结构：

- `p_metadata`: Dictionary caller-defined result metadata.

<a id="member-gfnetworklobbyjoinresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：结果字典。

结构：

- `return`: Dictionary with ok, lobby_id, lobby, error, message, and metadata.

<a id="member-gfnetworklobbyjoinresult-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用结果字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 结果字典。 |

结构：

- `data`: Dictionary with ok, lobby_id, lobby, error, message, and metadata.

<a id="member-gfnetworklobbyjoinresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_result() -> GFNetworkLobbyJoinResult:
```

创建结果深拷贝。

返回：新结果。

<a id="member-gfnetworklobbyjoinresult-methods-success"></a>

### `success`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func success(lobby_value: GFNetworkLobbyDescriptor, metadata_value: Dictionary = {}) -> GFNetworkLobbyJoinResult:
```

创建成功结果。

参数：

| 名称 | 说明 |
|---|---|
| `lobby_value` | Lobby 快照。 |
| `metadata_value` | 调用方元数据。 |

返回：成功结果。

结构：

- `metadata_value`: Dictionary caller-defined result metadata.

<a id="member-gfnetworklobbyjoinresult-methods-failure"></a>

### `failure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func failure( lobby_id_value: String, error_value: StringName, message_value: String = "", metadata_value: Dictionary = {} ) -> GFNetworkLobbyJoinResult:
```

创建失败结果。

参数：

| 名称 | 说明 |
|---|---|
| `lobby_id_value` | 相关 lobby ID。 |
| `error_value` | 失败原因标识。 |
| `message_value` | 人读说明。 |
| `metadata_value` | 调用方元数据。 |

返回：失败结果。

结构：

- `metadata_value`: Dictionary caller-defined result metadata.

<a id="member-gfnetworklobbyjoinresult-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFNetworkLobbyJoinResult:
```

从字典创建结果。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 结果字典。 |

返回：新结果。

结构：

- `data`: Dictionary with ok, lobby_id, lobby, error, message, and metadata.
