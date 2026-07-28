# GFPlatformAdapterConformance

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/platform/gf_platform_adapter_conformance.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`10.0.0`

Platform Adapter 静态一致性审查器。 在不调用外部 SDK 的前提下检查 Adapter 身份、状态、契约描述符、必需方法、 运行时能力和桥接覆盖。动态单终态、取消和结果 schema 由 GFPlatformAdapter 基类保证，并应由 Adapter 自己的契约测试覆盖。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`KIND_ADAPTER_INVALID`](#member-gfplatformadapterconformance-constants-kind_adapter_invalid) | `const KIND_ADAPTER_INVALID: StringName = &"platform_adapter_invalid"` |
| 常量 | [`KIND_ADAPTER_STATE_INVALID`](#member-gfplatformadapterconformance-constants-kind_adapter_state_invalid) | `const KIND_ADAPTER_STATE_INVALID: StringName = &"platform_adapter_state_invalid"` |
| 常量 | [`KIND_CONTRACT_MISSING`](#member-gfplatformadapterconformance-constants-kind_contract_missing) | `const KIND_CONTRACT_MISSING: StringName = &"platform_contract_missing"` |
| 常量 | [`KIND_DESCRIPTOR_MISSING`](#member-gfplatformadapterconformance-constants-kind_descriptor_missing) | `const KIND_DESCRIPTOR_MISSING: StringName = &"platform_contract_descriptor_missing"` |
| 常量 | [`KIND_DESCRIPTOR_INVALID`](#member-gfplatformadapterconformance-constants-kind_descriptor_invalid) | `const KIND_DESCRIPTOR_INVALID: StringName = &"platform_contract_descriptor_invalid"` |
| 常量 | [`KIND_CONTRACT_VERSION_MISMATCH`](#member-gfplatformadapterconformance-constants-kind_contract_version_mismatch) | `const KIND_CONTRACT_VERSION_MISMATCH: StringName = &"platform_contract_version_mismatch"` |
| 常量 | [`KIND_METHOD_MISSING`](#member-gfplatformadapterconformance-constants-kind_method_missing) | `const KIND_METHOD_MISSING: StringName = &"platform_contract_method_missing"` |
| 常量 | [`KIND_CAPABILITY_MISSING`](#member-gfplatformadapterconformance-constants-kind_capability_missing) | `const KIND_CAPABILITY_MISSING: StringName = &"platform_capability_missing"` |
| 方法 | [`validate`](#member-gfplatformadapterconformance-methods-validate) | `static func validate( adapter: GFPlatformAdapter, options: Dictionary = {} ) -> GFValidationReport:` |
| 方法 | [`inspect`](#member-gfplatformadapterconformance-methods-inspect) | `static func inspect( adapter: GFPlatformAdapter, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`make_bridge_entries`](#member-gfplatformadapterconformance-methods-make_bridge_entries) | `static func make_bridge_entries( adapter: GFPlatformAdapter, options: Dictionary = {} ) -> Dictionary:` |

## 常量

<a id="member-gfplatformadapterconformance-constants-kind_adapter_invalid"></a>

### `KIND_ADAPTER_INVALID`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const KIND_ADAPTER_INVALID: StringName = &"platform_adapter_invalid"
```

Adapter 为空或身份未配置。

<a id="member-gfplatformadapterconformance-constants-kind_adapter_state_invalid"></a>

### `KIND_ADAPTER_STATE_INVALID`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const KIND_ADAPTER_STATE_INVALID: StringName = &"platform_adapter_state_invalid"
```

Adapter 处于不可用终态。

<a id="member-gfplatformadapterconformance-constants-kind_contract_missing"></a>

### `KIND_CONTRACT_MISSING`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const KIND_CONTRACT_MISSING: StringName = &"platform_contract_missing"
```

缺少必需契约。

<a id="member-gfplatformadapterconformance-constants-kind_descriptor_missing"></a>

### `KIND_DESCRIPTOR_MISSING`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const KIND_DESCRIPTOR_MISSING: StringName = &"platform_contract_descriptor_missing"
```

缺少契约描述符。

<a id="member-gfplatformadapterconformance-constants-kind_descriptor_invalid"></a>

### `KIND_DESCRIPTOR_INVALID`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const KIND_DESCRIPTOR_INVALID: StringName = &"platform_contract_descriptor_invalid"
```

契约描述符定义无效。

<a id="member-gfplatformadapterconformance-constants-kind_contract_version_mismatch"></a>

### `KIND_CONTRACT_VERSION_MISMATCH`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const KIND_CONTRACT_VERSION_MISMATCH: StringName = &"platform_contract_version_mismatch"
```

契约版本与消费方要求不一致。

<a id="member-gfplatformadapterconformance-constants-kind_method_missing"></a>

### `KIND_METHOD_MISSING`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const KIND_METHOD_MISSING: StringName = &"platform_contract_method_missing"
```

契约缺少必需方法。

<a id="member-gfplatformadapterconformance-constants-kind_capability_missing"></a>

### `KIND_CAPABILITY_MISSING`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const KIND_CAPABILITY_MISSING: StringName = &"platform_capability_missing"
```

运行时上下文缺少必需能力。

## 方法

<a id="member-gfplatformadapterconformance-methods-validate"></a>

### `validate`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
static func validate( adapter: GFPlatformAdapter, options: Dictionary = {} ) -> GFValidationReport:
```

校验 Platform Adapter 的静态契约。 options 支持 required_contract_ids、required_contract_versions、 required_capability_ids、required_methods、require_descriptors（默认 true）和 require_ready（默认 false）。版本采用精确匹配；required_methods 是 contract_id 到 method ID 列表的字典。

参数：

| 名称 | 说明 |
|---|---|
| `adapter` | 待审查 Adapter。 |
| `options` | 审查约束。 |

返回：强类型校验报告。

结构：

- `options`: Dictionary platform adapter conformance requirements.

<a id="member-gfplatformadapterconformance-methods-inspect"></a>

### `inspect`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
static func inspect( adapter: GFPlatformAdapter, options: Dictionary = {} ) -> Dictionary:
```

生成 JSON 安全的一致性报告和桥接覆盖附录。

参数：

| 名称 | 说明 |
|---|---|
| `adapter` | 待审查 Adapter。 |
| `options` | 传给 validate 的审查约束。 |

返回：JSON 安全报告字典。

结构：

- `options`: Dictionary platform adapter conformance requirements.
- `return`: Dictionary validation report with bridge_coverage.

<a id="member-gfplatformadapterconformance-methods-make_bridge_entries"></a>

### `make_bridge_entries`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
static func make_bridge_entries( adapter: GFPlatformAdapter, options: Dictionary = {} ) -> Dictionary:
```

构建通用 GFBridgeContractReport 输入条目。

参数：

| 名称 | 说明 |
|---|---|
| `adapter` | Platform Adapter。 |
| `options` | 可包含 required_contract_ids。 |

返回：contract_entries 与 adapter_entries。

结构：

- `options`: Dictionary platform adapter conformance requirements.
- `return`: Dictionary bridge contract and adapter entry arrays.
