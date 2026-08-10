# GFPlatformBridgeRequest

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/platform/gf_platform_bridge_request.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`8.0.0`

平台桥接请求。 用纯数据描述从 GF 或项目侧发往外部平台 adapter 的一次调用。它不执行调用， 只为 JS bridge、native SDK bridge 或进程桥接提供统一请求载体。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`request_id`](#member-gfplatformbridgerequest-properties-request_id) | `var request_id: StringName = &""` |
| 属性 | [`contract_id`](#member-gfplatformbridgerequest-properties-contract_id) | `var contract_id: StringName = &""` |
| 属性 | [`method_id`](#member-gfplatformbridgerequest-properties-method_id) | `var method_id: StringName = &""` |
| 属性 | [`payload`](#member-gfplatformbridgerequest-properties-payload) | `var payload: Dictionary = {}` |
| 属性 | [`timeout_msec`](#member-gfplatformbridgerequest-properties-timeout_msec) | `var timeout_msec: int = 0` |
| 属性 | [`metadata`](#member-gfplatformbridgerequest-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfplatformbridgerequest-methods-configure) | `func configure( p_request_id: StringName, p_contract_id: StringName, p_method_id: StringName, p_payload: Dictionary = {}, p_timeout_msec: int = 0, p_metadata: Dictionary = {} ) -> GFPlatformBridgeRequest:` |
| 方法 | [`is_empty`](#member-gfplatformbridgerequest-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`to_dict`](#member-gfplatformbridgerequest-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfplatformbridgerequest-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_request`](#member-gfplatformbridgerequest-methods-duplicate_request) | `func duplicate_request() -> GFPlatformBridgeRequest:` |
| 方法 | [`from_dict`](#member-gfplatformbridgerequest-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFPlatformBridgeRequest:` |

## 属性

<a id="member-gfplatformbridgerequest-properties-request_id"></a>

### `request_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var request_id: StringName = &""
```

请求 ID。

<a id="member-gfplatformbridgerequest-properties-contract_id"></a>

### `contract_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var contract_id: StringName = &""
```

桥接契约 ID。

<a id="member-gfplatformbridgerequest-properties-method_id"></a>

### `method_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var method_id: StringName = &""
```

方法 ID。

<a id="member-gfplatformbridgerequest-properties-payload"></a>

### `payload`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var payload: Dictionary = {}
```

请求载荷。

结构：

- `payload`: Dictionary adapter-defined request payload.

<a id="member-gfplatformbridgerequest-properties-timeout_msec"></a>

### `timeout_msec`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var timeout_msec: int = 0
```

超时时间，单位毫秒；小于等于 0 表示由调用方决定。

<a id="member-gfplatformbridgerequest-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方元数据。

结构：

- `metadata`: Dictionary caller-defined request metadata.

## 方法

<a id="member-gfplatformbridgerequest-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure( p_request_id: StringName, p_contract_id: StringName, p_method_id: StringName, p_payload: Dictionary = {}, p_timeout_msec: int = 0, p_metadata: Dictionary = {} ) -> GFPlatformBridgeRequest:
```

配置桥接请求。 三个稳定 ID 会移除首尾空白；直接写入导出属性的请求也会在 Runtime / Adapter 边界复制为同一规范身份。

参数：

| 名称 | 说明 |
|---|---|
| `p_request_id` | 请求 ID。 |
| `p_contract_id` | 桥接契约 ID。 |
| `p_method_id` | 方法 ID。 |
| `p_payload` | 请求载荷。 |
| `p_timeout_msec` | 超时时间，单位毫秒。 |
| `p_metadata` | 调用方元数据。 |

返回：当前请求。

结构：

- `p_payload`: Dictionary adapter-defined request payload.
- `p_metadata`: Dictionary caller-defined request metadata.

<a id="member-gfplatformbridgerequest-methods-is_empty"></a>

### `is_empty`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_empty() -> bool:
```

检查请求是否缺少最小契约字段。

返回：缺少 request_id、contract_id 或 method_id 时返回 true。

<a id="member-gfplatformbridgerequest-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：桥接请求字典。

结构：

- `return`: Dictionary platform bridge request.

<a id="member-gfplatformbridgerequest-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用桥接请求字段。 request_id、contract_id 与 method_id 会移除首尾空白。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 桥接请求字典。 |

结构：

- `data`: Dictionary platform bridge request.

<a id="member-gfplatformbridgerequest-methods-duplicate_request"></a>

### `duplicate_request`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_request() -> GFPlatformBridgeRequest:
```

创建桥接请求深拷贝。

返回：新桥接请求。

<a id="member-gfplatformbridgerequest-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFPlatformBridgeRequest:
```

从字典创建桥接请求。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 桥接请求字典。 |

返回：新桥接请求。

结构：

- `data`: Dictionary platform bridge request.
