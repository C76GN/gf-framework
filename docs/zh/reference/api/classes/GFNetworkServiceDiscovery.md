# GFNetworkServiceDiscovery

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_service_discovery.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`8.0.0`

传输无关的网络服务发现记录器。 负责生成服务广告字典、JSON bytes 编解码、接收入站广告并维护带 TTL 的服务列表。 它不打开 socket、不决定广播地址，也不规定房间、账号、鉴权或同步协议。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`service_found`](#member-gfnetworkservicediscovery-signals-service_found) | `signal service_found(service_key: String, record: Dictionary)` |
| 信号 | [`service_updated`](#member-gfnetworkservicediscovery-signals-service_updated) | `signal service_updated(service_key: String, record: Dictionary)` |
| 信号 | [`service_lost`](#member-gfnetworkservicediscovery-signals-service_lost) | `signal service_lost(service_key: String, record: Dictionary, reason: String)` |
| 常量 | [`MESSAGE_KIND`](#member-gfnetworkservicediscovery-constants-message_kind) | `const MESSAGE_KIND: String = "gf.service.discovery"` |
| 常量 | [`SCHEMA_VERSION`](#member-gfnetworkservicediscovery-constants-schema_version) | `const SCHEMA_VERSION: int = 1` |
| 属性 | [`default_ttl_seconds`](#member-gfnetworkservicediscovery-properties-default_ttl_seconds) | `var default_ttl_seconds: float = 5.0:` |
| 方法 | [`make_advertisement`](#member-gfnetworkservicediscovery-methods-make_advertisement) | `func make_advertisement( service_id: StringName, endpoint: String, metadata: Dictionary = {}, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`accept_advertisement`](#member-gfnetworkservicediscovery-methods-accept_advertisement) | `func accept_advertisement(advertisement: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`accept_packet`](#member-gfnetworkservicediscovery-methods-accept_packet) | `func accept_packet( bytes: PackedByteArray, remote_address: String = "", remote_port: int = 0, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`tick`](#member-gfnetworkservicediscovery-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`get_service`](#member-gfnetworkservicediscovery-methods-get_service) | `func get_service(service_key: String) -> Dictionary:` |
| 方法 | [`get_service_keys`](#member-gfnetworkservicediscovery-methods-get_service_keys) | `func get_service_keys() -> PackedStringArray:` |
| 方法 | [`get_services`](#member-gfnetworkservicediscovery-methods-get_services) | `func get_services(service_id: StringName = &"") -> Array[Dictionary]:` |
| 方法 | [`remove_service`](#member-gfnetworkservicediscovery-methods-remove_service) | `func remove_service(service_key: String, reason: String = "removed") -> bool:` |
| 方法 | [`clear_services`](#member-gfnetworkservicediscovery-methods-clear_services) | `func clear_services(reason: String = "cleared") -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfnetworkservicediscovery-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`encode_advertisement`](#member-gfnetworkservicediscovery-methods-encode_advertisement) | `static func encode_advertisement(advertisement: Dictionary, options: Dictionary = {}) -> PackedByteArray:` |
| 方法 | [`decode_advertisement`](#member-gfnetworkservicediscovery-methods-decode_advertisement) | `static func decode_advertisement(bytes: PackedByteArray, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`validate_advertisement`](#member-gfnetworkservicediscovery-methods-validate_advertisement) | `static func validate_advertisement(advertisement: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_service_key`](#member-gfnetworkservicediscovery-methods-make_service_key) | `static func make_service_key(service_id: StringName, endpoint: String) -> String:` |

## 信号

<a id="member-gfnetworkservicediscovery-signals-service_found"></a>

### `service_found`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal service_found(service_key: String, record: Dictionary)
```

首次看到某个服务 endpoint 时发出。

参数：

| 名称 | 说明 |
|---|---|
| `service_key` | 服务发现内部稳定 key。 |
| `record` | 服务记录副本。 |

结构：

- `record`: Dictionary with service_key, service_id, endpoint, display_name, tags, metadata, ttl_seconds, first_seen_seconds, last_seen_seconds, expires_at_seconds, remote_address, remote_port, and sequence.

<a id="member-gfnetworkservicediscovery-signals-service_updated"></a>

### `service_updated`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal service_updated(service_key: String, record: Dictionary)
```

已知服务 endpoint 被新广告刷新时发出。

参数：

| 名称 | 说明 |
|---|---|
| `service_key` | 服务发现内部稳定 key。 |
| `record` | 服务记录副本。 |

结构：

- `record`: Dictionary with service_key, service_id, endpoint, display_name, tags, metadata, ttl_seconds, first_seen_seconds, last_seen_seconds, expires_at_seconds, remote_address, remote_port, and sequence.

<a id="member-gfnetworkservicediscovery-signals-service_lost"></a>

### `service_lost`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal service_lost(service_key: String, record: Dictionary, reason: String)
```

服务过期、被清空或被手动移除时发出。

参数：

| 名称 | 说明 |
|---|---|
| `service_key` | 服务发现内部稳定 key。 |
| `record` | 服务记录副本。 |
| `reason` | 移除原因。 |

结构：

- `record`: Dictionary with service_key, service_id, endpoint, display_name, tags, metadata, ttl_seconds, first_seen_seconds, last_seen_seconds, expires_at_seconds, remote_address, remote_port, and sequence.

## 常量

<a id="member-gfnetworkservicediscovery-constants-message_kind"></a>

### `MESSAGE_KIND`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const MESSAGE_KIND: String = "gf.service.discovery"
```

服务广告消息类型标记。

<a id="member-gfnetworkservicediscovery-constants-schema_version"></a>

### `SCHEMA_VERSION`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const SCHEMA_VERSION: int = 1
```

当前服务广告 schema 版本。

## 属性

<a id="member-gfnetworkservicediscovery-properties-default_ttl_seconds"></a>

### `default_ttl_seconds`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var default_ttl_seconds: float = 5.0:
```

缺省服务广告 TTL，单位秒。

## 方法

<a id="member-gfnetworkservicediscovery-methods-make_advertisement"></a>

### `make_advertisement`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func make_advertisement( service_id: StringName, endpoint: String, metadata: Dictionary = {}, options: Dictionary = {} ) -> Dictionary:
```

构造服务广告字典。

参数：

| 名称 | 说明 |
|---|---|
| `service_id` | 服务类型或协议标识。 |
| `endpoint` | 项目可连接的 endpoint 文本。 |
| `metadata` | 项目自定义元数据。 |
| `options` | 可选项，支持 display_name、tags、ttl_seconds、sequence 和 time_msec。 |

返回：服务广告字典。

结构：

- `metadata`: Dictionary[String, Variant] copied into the advertisement without GF interpreting project fields.
- `options`: Dictionary with display_name: String, tags: PackedStringArray|Array[String], ttl_seconds: float, sequence: int, and time_msec: int.
- `return`: Dictionary with kind, schema_version, service_id, endpoint, display_name, tags, metadata, ttl_seconds, sequence, and time_msec.

<a id="member-gfnetworkservicediscovery-methods-accept_advertisement"></a>

### `accept_advertisement`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func accept_advertisement(advertisement: Dictionary, options: Dictionary = {}) -> Dictionary:
```

接收已解码的服务广告并更新本地服务列表。

参数：

| 名称 | 说明 |
|---|---|
| `advertisement` | 服务广告字典。 |
| `options` | 可选项，支持 remote_address、remote_port 和 now_seconds。 |

返回：接收报告。

结构：

- `advertisement`: Dictionary produced by make_advertisement() or decode_advertisement().
- `options`: Dictionary with remote_address: String, remote_port: int, and now_seconds: float.
- `return`: Dictionary with ok, status, service_key, record, error, issues, issue_count, and next_action.

<a id="member-gfnetworkservicediscovery-methods-accept_packet"></a>

### `accept_packet`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func accept_packet( bytes: PackedByteArray, remote_address: String = "", remote_port: int = 0, options: Dictionary = {} ) -> Dictionary:
```

解码并接收服务广告 bytes。

参数：

| 名称 | 说明 |
|---|---|
| `bytes` | UTF-8 JSON bytes。 |
| `remote_address` | 底层传输报告的远端地址。 |
| `remote_port` | 底层传输报告的远端端口。 |
| `options` | 可选项，支持 json_codec_options、now_seconds 和广告结构预算。 |

返回：接收报告。

结构：

- `options`: Dictionary with json_codec_options, now_seconds, max_advertisement_bytes, max_metadata_depth, and max_metadata_entries.
- `return`: Dictionary with ok, status, service_key, record, error, issues, issue_count, and next_action.

<a id="member-gfnetworkservicediscovery-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func tick(delta: float) -> void:
```

推进发现列表时间并移除过期服务。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 本帧时间增量，单位秒。 |

<a id="member-gfnetworkservicediscovery-methods-get_service"></a>

### `get_service`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_service(service_key: String) -> Dictionary:
```

获取指定服务记录。

参数：

| 名称 | 说明 |
|---|---|
| `service_key` | 服务发现内部稳定 key。 |

返回：服务记录副本；不存在时返回空字典。

结构：

- `return`: Dictionary service record or empty Dictionary.

<a id="member-gfnetworkservicediscovery-methods-get_service_keys"></a>

### `get_service_keys`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_service_keys() -> PackedStringArray:
```

获取当前服务 key 列表。

返回：排序后的服务 key。

<a id="member-gfnetworkservicediscovery-methods-get_services"></a>

### `get_services`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_services(service_id: StringName = &"") -> Array[Dictionary]:
```

获取当前服务记录列表。

参数：

| 名称 | 说明 |
|---|---|
| `service_id` | 可选服务类型过滤；为空时返回全部。 |

返回：服务记录副本数组。

结构：

- `return`: Array[Dictionary] of service records.

<a id="member-gfnetworkservicediscovery-methods-remove_service"></a>

### `remove_service`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func remove_service(service_key: String, reason: String = "removed") -> bool:
```

手动移除服务记录。

参数：

| 名称 | 说明 |
|---|---|
| `service_key` | 服务发现内部稳定 key。 |
| `reason` | 移除原因。 |

返回：成功移除返回 true。

<a id="member-gfnetworkservicediscovery-methods-clear_services"></a>

### `clear_services`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear_services(reason: String = "cleared") -> void:
```

清空服务列表。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 移除原因。 |

<a id="member-gfnetworkservicediscovery-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试状态字典。

结构：

- `return`: Dictionary with service_count, service_keys, default_ttl_seconds, and elapsed_seconds.

<a id="member-gfnetworkservicediscovery-methods-encode_advertisement"></a>

### `encode_advertisement`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func encode_advertisement(advertisement: Dictionary, options: Dictionary = {}) -> PackedByteArray:
```

编码服务广告为 UTF-8 JSON bytes。

参数：

| 名称 | 说明 |
|---|---|
| `advertisement` | 服务广告字典。 |
| `options` | 可选项，支持 json_codec_options 和广告结构预算。 |

返回：UTF-8 JSON bytes。

结构：

- `advertisement`: Dictionary produced by make_advertisement().
- `options`: Dictionary with json_codec_options, max_advertisement_bytes, max_metadata_depth, and max_metadata_entries.

<a id="member-gfnetworkservicediscovery-methods-decode_advertisement"></a>

### `decode_advertisement`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func decode_advertisement(bytes: PackedByteArray, options: Dictionary = {}) -> Dictionary:
```

解码 UTF-8 JSON bytes 为服务广告字典。

参数：

| 名称 | 说明 |
|---|---|
| `bytes` | UTF-8 JSON bytes。 |
| `options` | 可选项，支持 json_codec_options。 |

返回：解码报告。

结构：

- `options`: Dictionary with json_codec_options: Dictionary passed to GFVariantJsonCodec.
- `return`: Dictionary with ok, data, error, issues, issue_count, and next_action.

<a id="member-gfnetworkservicediscovery-methods-validate_advertisement"></a>

### `validate_advertisement`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func validate_advertisement(advertisement: Dictionary, options: Dictionary = {}) -> Dictionary:
```

校验并规范化服务广告字典。

参数：

| 名称 | 说明 |
|---|---|
| `advertisement` | 服务广告字典。 |
| `options` | 与 encode_advertisement()/decode_advertisement() 共享的结构预算。 |

返回：校验报告。

结构：

- `advertisement`: Dictionary service advertisement payload.
- `options`: Dictionary with max_metadata_depth and max_metadata_entries.
- `return`: Dictionary with ok, data, error, issues, issue_count, and next_action.

<a id="member-gfnetworkservicediscovery-methods-make_service_key"></a>

### `make_service_key`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func make_service_key(service_id: StringName, endpoint: String) -> String:
```

生成服务发现内部稳定 key。

参数：

| 名称 | 说明 |
|---|---|
| `service_id` | 服务类型或协议标识。 |
| `endpoint` | 项目可连接的 endpoint 文本。 |

返回：服务 key。
