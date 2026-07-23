# GFPlatformBridgeResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/platform/gf_platform_bridge_result.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`8.0.0`

平台桥接结果。 用纯数据表达外部平台 adapter 对一次桥接请求的成功、失败、状态、返回值和耗时。 它不包含平台 SDK 依赖，也不假设同步或异步实现方式。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`request_id`](#member-gfplatformbridgeresult-properties-request_id) | `var request_id: StringName = &""` |
| 属性 | [`contract_id`](#member-gfplatformbridgeresult-properties-contract_id) | `var contract_id: StringName = &""` |
| 属性 | [`method_id`](#member-gfplatformbridgeresult-properties-method_id) | `var method_id: StringName = &""` |
| 属性 | [`ok`](#member-gfplatformbridgeresult-properties-ok) | `var ok: bool = false` |
| 属性 | [`status`](#member-gfplatformbridgeresult-properties-status) | `var status: StringName = &""` |
| 属性 | [`value`](#member-gfplatformbridgeresult-properties-value) | `var value: Variant = null` |
| 属性 | [`error`](#member-gfplatformbridgeresult-properties-error) | `var error: String = ""` |
| 属性 | [`started_at_msec`](#member-gfplatformbridgeresult-properties-started_at_msec) | `var started_at_msec: int = -1` |
| 属性 | [`completed_at_msec`](#member-gfplatformbridgeresult-properties-completed_at_msec) | `var completed_at_msec: int = -1` |
| 属性 | [`metadata`](#member-gfplatformbridgeresult-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure_success`](#member-gfplatformbridgeresult-methods-configure_success) | `func configure_success( request: GFPlatformBridgeRequest, p_value: Variant = null, p_status: StringName = &"ok", p_started_at_msec: int = -1, p_completed_at_msec: int = -1, p_metadata: Dictionary = {} ) -> GFPlatformBridgeResult:` |
| 方法 | [`configure_failure`](#member-gfplatformbridgeresult-methods-configure_failure) | `func configure_failure( request: GFPlatformBridgeRequest, p_error: String, p_status: StringName = &"failed", p_started_at_msec: int = -1, p_completed_at_msec: int = -1, p_metadata: Dictionary = {} ) -> GFPlatformBridgeResult:` |
| 方法 | [`get_duration_msec`](#member-gfplatformbridgeresult-methods-get_duration_msec) | `func get_duration_msec() -> int:` |
| 方法 | [`to_dict`](#member-gfplatformbridgeresult-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfplatformbridgeresult-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_result`](#member-gfplatformbridgeresult-methods-duplicate_result) | `func duplicate_result() -> GFPlatformBridgeResult:` |
| 方法 | [`from_dict`](#member-gfplatformbridgeresult-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFPlatformBridgeResult:` |

## 属性

<a id="member-gfplatformbridgeresult-properties-request_id"></a>

### `request_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var request_id: StringName = &""
```

请求 ID。

<a id="member-gfplatformbridgeresult-properties-contract_id"></a>

### `contract_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var contract_id: StringName = &""
```

桥接契约 ID。

<a id="member-gfplatformbridgeresult-properties-method_id"></a>

### `method_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var method_id: StringName = &""
```

方法 ID。

<a id="member-gfplatformbridgeresult-properties-ok"></a>

### `ok`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var ok: bool = false
```

是否成功。

<a id="member-gfplatformbridgeresult-properties-status"></a>

### `status`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var status: StringName = &""
```

状态码。

<a id="member-gfplatformbridgeresult-properties-value"></a>

### `value`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var value: Variant = null
```

返回值。

结构：

- `value`: Adapter-defined result value.

<a id="member-gfplatformbridgeresult-properties-error"></a>

### `error`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var error: String = ""
```

错误描述。

<a id="member-gfplatformbridgeresult-properties-started_at_msec"></a>

### `started_at_msec`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var started_at_msec: int = -1
```

开始时间戳，单位毫秒；-1 表示未知。

<a id="member-gfplatformbridgeresult-properties-completed_at_msec"></a>

### `completed_at_msec`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var completed_at_msec: int = -1
```

完成时间戳，单位毫秒；-1 表示未知。

<a id="member-gfplatformbridgeresult-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方元数据。

结构：

- `metadata`: Dictionary caller-defined result metadata.

## 方法

<a id="member-gfplatformbridgeresult-methods-configure_success"></a>

### `configure_success`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure_success( request: GFPlatformBridgeRequest, p_value: Variant = null, p_status: StringName = &"ok", p_started_at_msec: int = -1, p_completed_at_msec: int = -1, p_metadata: Dictionary = {} ) -> GFPlatformBridgeResult:
```

配置成功结果。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 对应请求。 |
| `p_value` | 返回值。 |
| `p_status` | 状态码。 |
| `p_started_at_msec` | 开始时间戳。 |
| `p_completed_at_msec` | 完成单调时间戳；-1 表示调用方未提供。 |
| `p_metadata` | 调用方元数据。 |

返回：当前结果。

结构：

- `p_value`: Adapter-defined result value.
- `p_metadata`: Dictionary caller-defined result metadata.

<a id="member-gfplatformbridgeresult-methods-configure_failure"></a>

### `configure_failure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure_failure( request: GFPlatformBridgeRequest, p_error: String, p_status: StringName = &"failed", p_started_at_msec: int = -1, p_completed_at_msec: int = -1, p_metadata: Dictionary = {} ) -> GFPlatformBridgeResult:
```

配置失败结果。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 对应请求。 |
| `p_error` | 错误描述。 |
| `p_status` | 状态码。 |
| `p_started_at_msec` | 开始时间戳。 |
| `p_completed_at_msec` | 完成单调时间戳；-1 表示调用方未提供。 |
| `p_metadata` | 调用方元数据。 |

返回：当前结果。

结构：

- `p_metadata`: Dictionary caller-defined result metadata.

<a id="member-gfplatformbridgeresult-methods-get_duration_msec"></a>

### `get_duration_msec`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_duration_msec() -> int:
```

获取耗时，单位毫秒。

返回：完成时间减开始时间；缺少时间戳时返回 0。

<a id="member-gfplatformbridgeresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：桥接结果字典。

结构：

- `return`: Dictionary platform bridge result.

<a id="member-gfplatformbridgeresult-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用桥接结果字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 桥接结果字典。 |

结构：

- `data`: Dictionary platform bridge result.

<a id="member-gfplatformbridgeresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_result() -> GFPlatformBridgeResult:
```

创建桥接结果深拷贝。

返回：新桥接结果。

<a id="member-gfplatformbridgeresult-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFPlatformBridgeResult:
```

从字典创建桥接结果。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 桥接结果字典。 |

返回：新桥接结果。

结构：

- `data`: Dictionary platform bridge result.
