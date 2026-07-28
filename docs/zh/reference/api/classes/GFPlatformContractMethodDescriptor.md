# GFPlatformContractMethodDescriptor

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/platform/gf_platform_contract_method_descriptor.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`10.0.0`

平台桥接方法契约。 描述单个 provider-neutral 方法的请求/结果 schema、能力前置条件、载荷预算、 并发上限与取消语义。具体 SDK 错误码和项目业务规则不得写入该描述符。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`method_id`](#member-gfplatformcontractmethoddescriptor-properties-method_id) | `var method_id: StringName = &""` |
| 属性 | [`request_schema`](#member-gfplatformcontractmethoddescriptor-properties-request_schema) | `var request_schema: GFDictionarySchema = null` |
| 属性 | [`result_schema`](#member-gfplatformcontractmethoddescriptor-properties-result_schema) | `var result_schema: GFDictionarySchema = null` |
| 属性 | [`required_capability_ids`](#member-gfplatformcontractmethoddescriptor-properties-required_capability_ids) | `var required_capability_ids: PackedStringArray = PackedStringArray()` |
| 属性 | [`max_request_bytes`](#member-gfplatformcontractmethoddescriptor-properties-max_request_bytes) | `var max_request_bytes: int = 0` |
| 属性 | [`max_result_bytes`](#member-gfplatformcontractmethoddescriptor-properties-max_result_bytes) | `var max_result_bytes: int = 0` |
| 属性 | [`max_concurrent_requests`](#member-gfplatformcontractmethoddescriptor-properties-max_concurrent_requests) | `var max_concurrent_requests: int = 0` |
| 属性 | [`supports_cancellation`](#member-gfplatformcontractmethoddescriptor-properties-supports_cancellation) | `var supports_cancellation: bool = true` |
| 属性 | [`sensitive_fields`](#member-gfplatformcontractmethoddescriptor-properties-sensitive_fields) | `var sensitive_fields: PackedStringArray = PackedStringArray()` |
| 属性 | [`metadata`](#member-gfplatformcontractmethoddescriptor-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfplatformcontractmethoddescriptor-methods-configure) | `func configure( p_method_id: StringName, options: Dictionary = {} ) -> GFPlatformContractMethodDescriptor:` |
| 方法 | [`validate_definition`](#member-gfplatformcontractmethoddescriptor-methods-validate_definition) | `func validate_definition() -> GFValidationReport:` |
| 方法 | [`validate_request`](#member-gfplatformcontractmethoddescriptor-methods-validate_request) | `func validate_request( payload: Dictionary, capabilities: GFPlatformCapabilitySet = null ) -> GFValidationReport:` |
| 方法 | [`validate_result`](#member-gfplatformcontractmethoddescriptor-methods-validate_result) | `func validate_result(value: Variant) -> GFValidationReport:` |
| 方法 | [`duplicate_descriptor`](#member-gfplatformcontractmethoddescriptor-methods-duplicate_descriptor) | `func duplicate_descriptor() -> GFPlatformContractMethodDescriptor:` |
| 方法 | [`to_dict`](#member-gfplatformcontractmethoddescriptor-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 属性

<a id="member-gfplatformcontractmethoddescriptor-properties-method_id"></a>

### `method_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var method_id: StringName = &""
```

方法稳定标识。

<a id="member-gfplatformcontractmethoddescriptor-properties-request_schema"></a>

### `request_schema`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var request_schema: GFDictionarySchema = null
```

可选请求 Dictionary schema。

<a id="member-gfplatformcontractmethoddescriptor-properties-result_schema"></a>

### `result_schema`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var result_schema: GFDictionarySchema = null
```

可选成功结果 Dictionary schema。为空时允许任意结果值。

<a id="member-gfplatformcontractmethoddescriptor-properties-required_capability_ids"></a>

### `required_capability_ids`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var required_capability_ids: PackedStringArray = PackedStringArray()
```

调用该方法前 adapter 必须声明的全部能力。

<a id="member-gfplatformcontractmethoddescriptor-properties-max_request_bytes"></a>

### `max_request_bytes`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var max_request_bytes: int = 0
```

请求 JSON-compatible 编码后的最大字节数；0 表示不额外限制。

<a id="member-gfplatformcontractmethoddescriptor-properties-max_result_bytes"></a>

### `max_result_bytes`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var max_result_bytes: int = 0
```

成功结果 JSON-compatible 编码后的最大字节数；0 表示不额外限制。

<a id="member-gfplatformcontractmethoddescriptor-properties-max_concurrent_requests"></a>

### `max_concurrent_requests`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var max_concurrent_requests: int = 0
```

同一 adapter 上该方法允许的最大并发请求数；0 表示不额外限制。

<a id="member-gfplatformcontractmethoddescriptor-properties-supports_cancellation"></a>

### `supports_cancellation`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var supports_cancellation: bool = true
```

底层 provider 是否支持主动取消。

<a id="member-gfplatformcontractmethoddescriptor-properties-sensitive_fields"></a>

### `sensitive_fields`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var sensitive_fields: PackedStringArray = PackedStringArray()
```

请求或结果中必须在日志、诊断和支持报告中脱敏的字段名。

<a id="member-gfplatformcontractmethoddescriptor-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var metadata: Dictionary = {}
```

Adapter 作者定义的非业务元数据。

结构：

- `metadata`: Dictionary adapter-authoring metadata.

## 方法

<a id="member-gfplatformcontractmethoddescriptor-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func configure( p_method_id: StringName, options: Dictionary = {} ) -> GFPlatformContractMethodDescriptor:
```

配置方法契约。

参数：

| 名称 | 说明 |
|---|---|
| `p_method_id` | 方法稳定标识。 |
| `options` | 可包含 request_schema、result_schema、required_capability_ids、max_request_bytes、max_result_bytes、max_concurrent_requests、supports_cancellation、sensitive_fields 和 metadata。 |

返回：当前描述符。

结构：

- `options`: Dictionary platform contract method options.

<a id="member-gfplatformcontractmethoddescriptor-methods-validate_definition"></a>

### `validate_definition`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func validate_definition() -> GFValidationReport:
```

校验描述符定义。

返回：标准校验报告。

<a id="member-gfplatformcontractmethoddescriptor-methods-validate_request"></a>

### `validate_request`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func validate_request( payload: Dictionary, capabilities: GFPlatformCapabilitySet = null ) -> GFValidationReport:
```

校验请求载荷和能力前置条件。

参数：

| 名称 | 说明 |
|---|---|
| `payload` | 请求载荷。 |
| `capabilities` | Adapter 当前能力集合。 |

返回：标准校验报告。

结构：

- `payload`: Dictionary platform method request payload.

<a id="member-gfplatformcontractmethoddescriptor-methods-validate_result"></a>

### `validate_result`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func validate_result(value: Variant) -> GFValidationReport:
```

校验成功结果的 schema 与字节预算。

参数：

| 名称 | 说明 |
|---|---|
| `value` | Adapter 成功结果值。 |

返回：标准校验报告。

结构：

- `value`: Adapter-defined result value.

<a id="member-gfplatformcontractmethoddescriptor-methods-duplicate_descriptor"></a>

### `duplicate_descriptor`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func duplicate_descriptor() -> GFPlatformContractMethodDescriptor:
```

创建描述符深拷贝。

返回：新描述符。

<a id="member-gfplatformcontractmethoddescriptor-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为不包含敏感载荷的描述字典。

返回：方法契约摘要。

结构：

- `return`: Dictionary platform contract method descriptor summary.
