# GFPlatformContractDescriptor

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/platform/gf_platform_contract_descriptor.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`unreleased`

平台桥接契约描述。 将一个 provider-neutral contract 的版本和方法集合固定为可校验数据。描述符不包含 Steam、微信、主机厂商或项目业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`contract_id`](#member-gfplatformcontractdescriptor-properties-contract_id) | `var contract_id: StringName = &""` |
| 属性 | [`contract_version`](#member-gfplatformcontractdescriptor-properties-contract_version) | `var contract_version: String = "1.0.0"` |
| 属性 | [`methods`](#member-gfplatformcontractdescriptor-properties-methods) | `var methods: Array[GFPlatformContractMethodDescriptor] = []` |
| 属性 | [`metadata`](#member-gfplatformcontractdescriptor-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfplatformcontractdescriptor-methods-configure) | `func configure( p_contract_id: StringName, p_contract_version: String, p_methods: Array[GFPlatformContractMethodDescriptor], p_metadata: Dictionary = {} ) -> GFPlatformContractDescriptor:` |
| 方法 | [`get_method`](#member-gfplatformcontractdescriptor-methods-get_method) | `func get_method(method_id: StringName) -> GFPlatformContractMethodDescriptor:` |
| 方法 | [`validate_definition`](#member-gfplatformcontractdescriptor-methods-validate_definition) | `func validate_definition() -> GFValidationReport:` |
| 方法 | [`duplicate_descriptor`](#member-gfplatformcontractdescriptor-methods-duplicate_descriptor) | `func duplicate_descriptor() -> GFPlatformContractDescriptor:` |
| 方法 | [`to_dict`](#member-gfplatformcontractdescriptor-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 属性

<a id="member-gfplatformcontractdescriptor-properties-contract_id"></a>

### `contract_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var contract_id: StringName = &""
```

契约稳定标识。

<a id="member-gfplatformcontractdescriptor-properties-contract_version"></a>

### `contract_version`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var contract_version: String = "1.0.0"
```

契约版本。Adapter 应使用双方明确支持的版本，不做隐式降级。

<a id="member-gfplatformcontractdescriptor-properties-methods"></a>

### `methods`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var methods: Array[GFPlatformContractMethodDescriptor] = []
```

方法描述符列表。

结构：

- `methods`: Array[GFPlatformContractMethodDescriptor] platform contract methods.

<a id="member-gfplatformcontractdescriptor-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var metadata: Dictionary = {}
```

Adapter 作者定义的非业务元数据。

结构：

- `metadata`: Dictionary adapter-authoring metadata.

## 方法

<a id="member-gfplatformcontractdescriptor-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func configure( p_contract_id: StringName, p_contract_version: String, p_methods: Array[GFPlatformContractMethodDescriptor], p_metadata: Dictionary = {} ) -> GFPlatformContractDescriptor:
```

配置平台契约。

参数：

| 名称 | 说明 |
|---|---|
| `p_contract_id` | 契约稳定标识。 |
| `p_contract_version` | 契约版本。 |
| `p_methods` | 方法描述符列表。 |
| `p_metadata` | Adapter 作者元数据。 |

返回：当前描述符。

结构：

- `p_methods`: Array[GFPlatformContractMethodDescriptor] platform contract methods.
- `p_metadata`: Dictionary adapter-authoring metadata.

<a id="member-gfplatformcontractdescriptor-methods-get_method"></a>

### `get_method`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_method(method_id: StringName) -> GFPlatformContractMethodDescriptor:
```

获取方法描述符副本。

参数：

| 名称 | 说明 |
|---|---|
| `method_id` | 方法稳定标识。 |

返回：找到时返回描述符副本，否则返回 null。

<a id="member-gfplatformcontractdescriptor-methods-validate_definition"></a>

### `validate_definition`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func validate_definition() -> GFValidationReport:
```

校验契约定义和重复方法。

返回：标准校验报告。

<a id="member-gfplatformcontractdescriptor-methods-duplicate_descriptor"></a>

### `duplicate_descriptor`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_descriptor() -> GFPlatformContractDescriptor:
```

创建契约描述符深拷贝。

返回：新描述符。

<a id="member-gfplatformcontractdescriptor-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_dict() -> Dictionary:
```

转换为不包含请求和结果载荷的摘要字典。

返回：契约摘要。

结构：

- `return`: Dictionary platform contract descriptor summary.
