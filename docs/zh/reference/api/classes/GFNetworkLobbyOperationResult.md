# GFNetworkLobbyOperationResult

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_lobby_operation_result.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

Lobby 操作终态结果。 通过 request_id 和 operation 将 SDK 回调关联到唯一请求，并统一承载单个 Lobby、 查询列表、失败状态与耗时。结果是不可回写到 Handle 的深拷贝快照。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`request_id`](#member-gfnetworklobbyoperationresult-properties-request_id) | `var request_id: StringName = &""` |
| 属性 | [`operation`](#member-gfnetworklobbyoperationresult-properties-operation) | `var operation: StringName = &""` |
| 属性 | [`ok`](#member-gfnetworklobbyoperationresult-properties-ok) | `var ok: bool = false` |
| 属性 | [`status`](#member-gfnetworklobbyoperationresult-properties-status) | `var status: StringName = &""` |
| 属性 | [`lobby_id`](#member-gfnetworklobbyoperationresult-properties-lobby_id) | `var lobby_id: String = ""` |
| 属性 | [`lobby`](#member-gfnetworklobbyoperationresult-properties-lobby) | `var lobby: GFNetworkLobbyDescriptor = null` |
| 属性 | [`lobbies`](#member-gfnetworklobbyoperationresult-properties-lobbies) | `var lobbies: Array[GFNetworkLobbyDescriptor] = []` |
| 属性 | [`error`](#member-gfnetworklobbyoperationresult-properties-error) | `var error: StringName = &""` |
| 属性 | [`message`](#member-gfnetworklobbyoperationresult-properties-message) | `var message: String = ""` |
| 属性 | [`started_at_msec`](#member-gfnetworklobbyoperationresult-properties-started_at_msec) | `var started_at_msec: int = -1` |
| 属性 | [`completed_at_msec`](#member-gfnetworklobbyoperationresult-properties-completed_at_msec) | `var completed_at_msec: int = -1` |
| 属性 | [`metadata`](#member-gfnetworklobbyoperationresult-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure_success`](#member-gfnetworklobbyoperationresult-methods-configure_success) | `func configure_success( request: GFNetworkLobbyOperationRequest, options: Dictionary = {} ) -> GFNetworkLobbyOperationResult:` |
| 方法 | [`configure_failure`](#member-gfnetworklobbyoperationresult-methods-configure_failure) | `func configure_failure( request: GFNetworkLobbyOperationRequest, p_error: StringName, p_message: String = "", options: Dictionary = {} ) -> GFNetworkLobbyOperationResult:` |
| 方法 | [`get_duration_msec`](#member-gfnetworklobbyoperationresult-methods-get_duration_msec) | `func get_duration_msec() -> int:` |
| 方法 | [`is_valid`](#member-gfnetworklobbyoperationresult-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`matches_request`](#member-gfnetworklobbyoperationresult-methods-matches_request) | `func matches_request(request: GFNetworkLobbyOperationRequest) -> bool:` |
| 方法 | [`to_dict`](#member-gfnetworklobbyoperationresult-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfnetworklobbyoperationresult-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_result`](#member-gfnetworklobbyoperationresult-methods-duplicate_result) | `func duplicate_result() -> GFNetworkLobbyOperationResult:` |
| 方法 | [`from_dict`](#member-gfnetworklobbyoperationresult-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFNetworkLobbyOperationResult:` |

## 属性

<a id="member-gfnetworklobbyoperationresult-properties-request_id"></a>

### `request_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var request_id: StringName = &""
```

请求 ID。

<a id="member-gfnetworklobbyoperationresult-properties-operation"></a>

### `operation`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var operation: StringName = &""
```

操作类型。

<a id="member-gfnetworklobbyoperationresult-properties-ok"></a>

### `ok`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var ok: bool = false
```

操作是否成功。

<a id="member-gfnetworklobbyoperationresult-properties-status"></a>

### `status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var status: StringName = &""
```

稳定终态状态。

<a id="member-gfnetworklobbyoperationresult-properties-lobby_id"></a>

### `lobby_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var lobby_id: String = ""
```

相关 Lobby ID。

<a id="member-gfnetworklobbyoperationresult-properties-lobby"></a>

### `lobby`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var lobby: GFNetworkLobbyDescriptor = null
```

单个 Lobby 快照。

<a id="member-gfnetworklobbyoperationresult-properties-lobbies"></a>

### `lobbies`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var lobbies: Array[GFNetworkLobbyDescriptor] = []
```

查询操作返回的 Lobby 快照列表。

结构：

- `lobbies`: Array[GFNetworkLobbyDescriptor] queried lobby snapshots.

<a id="member-gfnetworklobbyoperationresult-properties-error"></a>

### `error`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var error: StringName = &""
```

失败原因标识。

<a id="member-gfnetworklobbyoperationresult-properties-message"></a>

### `message`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var message: String = ""
```

人读说明。

<a id="member-gfnetworklobbyoperationresult-properties-started_at_msec"></a>

### `started_at_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var started_at_msec: int = -1
```

开始单调时间戳，单位毫秒；-1 表示未知。

<a id="member-gfnetworklobbyoperationresult-properties-completed_at_msec"></a>

### `completed_at_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var completed_at_msec: int = -1
```

完成单调时间戳，单位毫秒；-1 表示未知。

<a id="member-gfnetworklobbyoperationresult-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var metadata: Dictionary = {}
```

调用方或 Adapter 结果元数据。

结构：

- `metadata`: Dictionary caller-defined result metadata.

## 方法

<a id="member-gfnetworklobbyoperationresult-methods-configure_success"></a>

### `configure_success`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func configure_success( request: GFNetworkLobbyOperationRequest, options: Dictionary = {} ) -> GFNetworkLobbyOperationResult:
```

配置成功结果。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 对应请求。 |
| `options` | 可包含 status、lobby、lobbies、lobby_id、started_at_msec、completed_at_msec 和 metadata。 |

返回：当前结果。

结构：

- `options`: Dictionary successful lobby result fields.

<a id="member-gfnetworklobbyoperationresult-methods-configure_failure"></a>

### `configure_failure`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func configure_failure( request: GFNetworkLobbyOperationRequest, p_error: StringName, p_message: String = "", options: Dictionary = {} ) -> GFNetworkLobbyOperationResult:
```

配置失败结果。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 对应请求。 |
| `p_error` | 稳定失败原因。 |
| `p_message` | 人读说明。 |
| `options` | 可包含 status、started_at_msec、completed_at_msec 和 metadata。 |

返回：当前结果。

结构：

- `options`: Dictionary failed lobby result fields.

<a id="member-gfnetworklobbyoperationresult-methods-get_duration_msec"></a>

### `get_duration_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_duration_msec() -> int:
```

获取操作耗时，单位毫秒。

返回：完成时间减开始时间；缺少时间戳时返回 0。

<a id="member-gfnetworklobbyoperationresult-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_valid() -> bool:
```

校验终态结构是否满足操作契约。

返回：结果身份、时间和操作特定载荷均有效时返回 true。

<a id="member-gfnetworklobbyoperationresult-methods-matches_request"></a>

### `matches_request`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func matches_request(request: GFNetworkLobbyOperationRequest) -> bool:
```

检查结果是否属于给定请求。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 待匹配请求。 |

返回：request_id 和 operation 同时匹配时返回 true。

<a id="member-gfnetworklobbyoperationresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：Lobby 操作结果字典。

结构：

- `return`: Dictionary lobby operation result.

<a id="member-gfnetworklobbyoperationresult-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用结果字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | Lobby 操作结果字典。 |

结构：

- `data`: Dictionary lobby operation result.

<a id="member-gfnetworklobbyoperationresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_result() -> GFNetworkLobbyOperationResult:
```

创建结果深拷贝。

返回：新结果。

<a id="member-gfnetworklobbyoperationresult-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func from_dict(data: Dictionary) -> GFNetworkLobbyOperationResult:
```

从字典创建结果。

参数：

| 名称 | 说明 |
|---|---|
| `data` | Lobby 操作结果字典。 |

返回：新结果。

结构：

- `data`: Dictionary lobby operation result.
