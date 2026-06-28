# GFBridgeContractReport

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/validation/gf_bridge_contract_report.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

外部桥接契约覆盖报告构建器。 用于比较“框架或工具期望存在的桥接契约”和“项目、SDK、GDExtension 或编辑器工具实际注册的适配器”。它只处理纯数据报告，不注册适配器、 不调用 handler，也不规定项目侧路由策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`KIND_CONTRACT_INVALID`](#member-gfbridgecontractreport-constants-kind_contract_invalid) | `const KIND_CONTRACT_INVALID: StringName = &"bridge_contract_invalid"` |
| 常量 | [`KIND_CONTRACT_DUPLICATE`](#member-gfbridgecontractreport-constants-kind_contract_duplicate) | `const KIND_CONTRACT_DUPLICATE: StringName = &"bridge_contract_duplicate"` |
| 常量 | [`KIND_CONTRACT_MISSING`](#member-gfbridgecontractreport-constants-kind_contract_missing) | `const KIND_CONTRACT_MISSING: StringName = &"bridge_contract_missing"` |
| 常量 | [`KIND_ADAPTER_INVALID`](#member-gfbridgecontractreport-constants-kind_adapter_invalid) | `const KIND_ADAPTER_INVALID: StringName = &"bridge_adapter_invalid"` |
| 常量 | [`KIND_ADAPTER_EXTRA`](#member-gfbridgecontractreport-constants-kind_adapter_extra) | `const KIND_ADAPTER_EXTRA: StringName = &"bridge_adapter_extra"` |
| 常量 | [`KIND_ADAPTER_DISABLED`](#member-gfbridgecontractreport-constants-kind_adapter_disabled) | `const KIND_ADAPTER_DISABLED: StringName = &"bridge_adapter_disabled"` |
| 常量 | [`KIND_ADAPTER_DUPLICATE`](#member-gfbridgecontractreport-constants-kind_adapter_duplicate) | `const KIND_ADAPTER_DUPLICATE: StringName = &"bridge_adapter_duplicate"` |
| 常量 | [`KIND_ADAPTER_SIGNATURE_MISMATCH`](#member-gfbridgecontractreport-constants-kind_adapter_signature_mismatch) | `const KIND_ADAPTER_SIGNATURE_MISMATCH: StringName = &"bridge_adapter_signature_mismatch"` |
| 常量 | [`KIND_ADAPTER_VERSION_MISMATCH`](#member-gfbridgecontractreport-constants-kind_adapter_version_mismatch) | `const KIND_ADAPTER_VERSION_MISMATCH: StringName = &"bridge_adapter_version_mismatch"` |
| 常量 | [`KIND_ADAPTER_CAPABILITY_MISSING`](#member-gfbridgecontractreport-constants-kind_adapter_capability_missing) | `const KIND_ADAPTER_CAPABILITY_MISSING: StringName = &"bridge_adapter_capability_missing"` |
| 属性 | [`subject`](#member-gfbridgecontractreport-properties-subject) | `var subject: String = _DEFAULT_SUBJECT` |
| 属性 | [`contracts`](#member-gfbridgecontractreport-properties-contracts) | `var contracts: Array[Dictionary] = []` |
| 属性 | [`adapters`](#member-gfbridgecontractreport-properties-adapters) | `var adapters: Array[Dictionary] = []` |
| 属性 | [`metadata`](#member-gfbridgecontractreport-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfbridgecontractreport-methods-configure) | `func configure(p_subject: String = _DEFAULT_SUBJECT, p_metadata: Dictionary = {}) -> GFBridgeContractReport:` |
| 方法 | [`clear`](#member-gfbridgecontractreport-methods-clear) | `func clear() -> void:` |
| 方法 | [`add_contract`](#member-gfbridgecontractreport-methods-add_contract) | `func add_contract(contract_id: StringName, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`add_contracts`](#member-gfbridgecontractreport-methods-add_contracts) | `func add_contracts(entries: Array[Dictionary]) -> GFBridgeContractReport:` |
| 方法 | [`add_adapter`](#member-gfbridgecontractreport-methods-add_adapter) | `func add_adapter( adapter_id: StringName, contract_id: StringName = &"", options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`add_adapters`](#member-gfbridgecontractreport-methods-add_adapters) | `func add_adapters(entries: Array[Dictionary]) -> GFBridgeContractReport:` |
| 方法 | [`get_report`](#member-gfbridgecontractreport-methods-get_report) | `func get_report(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`from_entries`](#member-gfbridgecontractreport-methods-from_entries) | `static func from_entries( contract_entries: Array[Dictionary], adapter_entries: Array[Dictionary], options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`report_request_handlers`](#member-gfbridgecontractreport-methods-report_request_handlers) | `static func report_request_handlers( required_request_types: PackedStringArray, registry: GFRequestHandlerRegistry, options: Dictionary = {} ) -> Dictionary:` |

## 常量

<a id="member-gfbridgecontractreport-constants-kind_contract_invalid"></a>

### `KIND_CONTRACT_INVALID`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KIND_CONTRACT_INVALID: StringName = &"bridge_contract_invalid"
```

契约条目缺少有效 contract_id。

<a id="member-gfbridgecontractreport-constants-kind_contract_duplicate"></a>

### `KIND_CONTRACT_DUPLICATE`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KIND_CONTRACT_DUPLICATE: StringName = &"bridge_contract_duplicate"
```

同一 contract_id 被重复声明。

<a id="member-gfbridgecontractreport-constants-kind_contract_missing"></a>

### `KIND_CONTRACT_MISSING`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KIND_CONTRACT_MISSING: StringName = &"bridge_contract_missing"
```

必需契约没有任何启用的适配器覆盖。

<a id="member-gfbridgecontractreport-constants-kind_adapter_invalid"></a>

### `KIND_ADAPTER_INVALID`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KIND_ADAPTER_INVALID: StringName = &"bridge_adapter_invalid"
```

适配器条目缺少有效 adapter_id 或 contract_ids。

<a id="member-gfbridgecontractreport-constants-kind_adapter_extra"></a>

### `KIND_ADAPTER_EXTRA`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KIND_ADAPTER_EXTRA: StringName = &"bridge_adapter_extra"
```

适配器引用了未知契约。

<a id="member-gfbridgecontractreport-constants-kind_adapter_disabled"></a>

### `KIND_ADAPTER_DISABLED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KIND_ADAPTER_DISABLED: StringName = &"bridge_adapter_disabled"
```

适配器已声明但当前未启用。

<a id="member-gfbridgecontractreport-constants-kind_adapter_duplicate"></a>

### `KIND_ADAPTER_DUPLICATE`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KIND_ADAPTER_DUPLICATE: StringName = &"bridge_adapter_duplicate"
```

不允许多适配器的契约被多个启用适配器覆盖。

<a id="member-gfbridgecontractreport-constants-kind_adapter_signature_mismatch"></a>

### `KIND_ADAPTER_SIGNATURE_MISMATCH`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KIND_ADAPTER_SIGNATURE_MISMATCH: StringName = &"bridge_adapter_signature_mismatch"
```

适配器签名不满足契约签名。

<a id="member-gfbridgecontractreport-constants-kind_adapter_version_mismatch"></a>

### `KIND_ADAPTER_VERSION_MISMATCH`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KIND_ADAPTER_VERSION_MISMATCH: StringName = &"bridge_adapter_version_mismatch"
```

适配器版本不满足契约版本。

<a id="member-gfbridgecontractreport-constants-kind_adapter_capability_missing"></a>

### `KIND_ADAPTER_CAPABILITY_MISSING`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const KIND_ADAPTER_CAPABILITY_MISSING: StringName = &"bridge_adapter_capability_missing"
```

适配器缺少契约要求的能力。

## 属性

<a id="member-gfbridgecontractreport-properties-subject"></a>

### `subject`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var subject: String = _DEFAULT_SUBJECT
```

报告主题。

<a id="member-gfbridgecontractreport-properties-contracts"></a>

### `contracts`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var contracts: Array[Dictionary] = []
```

期望存在的桥接契约条目。

结构：

- `contracts`: Array[Dictionary]，每项可包含 contract_id/id、kind、signature、version、required、allow_multiple、capabilities 和 metadata。

<a id="member-gfbridgecontractreport-properties-adapters"></a>

### `adapters`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var adapters: Array[Dictionary] = []
```

实际注册或发现的适配器条目。

结构：

- `adapters`: Array[Dictionary]，每项可包含 adapter_id/id、contract_id、contract_ids、kind、signature、version、enabled、capabilities 和 metadata。

<a id="member-gfbridgecontractreport-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方自定义元数据。

结构：

- `metadata`: Dictionary caller-defined report metadata.

## 方法

<a id="member-gfbridgecontractreport-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func configure(p_subject: String = _DEFAULT_SUBJECT, p_metadata: Dictionary = {}) -> GFBridgeContractReport:
```

配置报告构建器。

参数：

| 名称 | 说明 |
|---|---|
| `p_subject` | 报告主题。 |
| `p_metadata` | 调用方元数据。 |

返回：当前构建器。

结构：

- `p_metadata`: Dictionary caller-defined report metadata.

<a id="member-gfbridgecontractreport-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空契约、适配器和元数据。

<a id="member-gfbridgecontractreport-methods-add_contract"></a>

### `add_contract`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_contract(contract_id: StringName, options: Dictionary = {}) -> Dictionary:
```

添加一个期望桥接契约。

参数：

| 名称 | 说明 |
|---|---|
| `contract_id` | 稳定契约 ID。 |
| `options` | 契约选项，支持 kind、signature、version、required、allow_multiple、capabilities 和 metadata。 |

返回：添加后的契约条目副本。

结构：

- `options`: Dictionary bridge contract metadata.
- `return`: Dictionary normalized bridge contract entry.

<a id="member-gfbridgecontractreport-methods-add_contracts"></a>

### `add_contracts`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_contracts(entries: Array[Dictionary]) -> GFBridgeContractReport:
```

批量添加期望桥接契约。

参数：

| 名称 | 说明 |
|---|---|
| `entries` | 契约条目数组。 |

返回：当前构建器。

结构：

- `entries`: Array[Dictionary] bridge contract entries.

<a id="member-gfbridgecontractreport-methods-add_adapter"></a>

### `add_adapter`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_adapter( adapter_id: StringName, contract_id: StringName = &"", options: Dictionary = {} ) -> Dictionary:
```

添加一个实际桥接适配器。

参数：

| 名称 | 说明 |
|---|---|
| `adapter_id` | 稳定适配器 ID。 |
| `contract_id` | 适配器覆盖的主要契约 ID；为空时可通过 options.contract_ids 提供。 |
| `options` | 适配器选项，支持 contract_ids、kind、signature、version、enabled、capabilities 和 metadata。 |

返回：添加后的适配器条目副本。

结构：

- `options`: Dictionary bridge adapter metadata.
- `return`: Dictionary normalized bridge adapter entry.

<a id="member-gfbridgecontractreport-methods-add_adapters"></a>

### `add_adapters`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func add_adapters(entries: Array[Dictionary]) -> GFBridgeContractReport:
```

批量添加实际桥接适配器。

参数：

| 名称 | 说明 |
|---|---|
| `entries` | 适配器条目数组。 |

返回：当前构建器。

结构：

- `entries`: Array[Dictionary] bridge adapter entries.

<a id="member-gfbridgecontractreport-methods-get_report"></a>

### `get_report`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_report(options: Dictionary = {}) -> Dictionary:
```

构建桥接契约覆盖报告。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 报告选项，支持 default_allow_multiple、missing_severity、extra_severity、duplicate_severity、disabled_severity、mismatch_severity、warnings_as_errors、fallback_action 和 no_action。 |

返回：GFValidationReportDictionary 兼容报告。

结构：

- `options`: Dictionary report options.
- `return`: Dictionary with ok、healthy、contracts、adapters、coverage counts、issues、summary and next_action.

<a id="member-gfbridgecontractreport-methods-from_entries"></a>

### `from_entries`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func from_entries( contract_entries: Array[Dictionary], adapter_entries: Array[Dictionary], options: Dictionary = {} ) -> Dictionary:
```

从契约和适配器数组直接创建覆盖报告。

参数：

| 名称 | 说明 |
|---|---|
| `contract_entries` | 契约条目数组。 |
| `adapter_entries` | 适配器条目数组。 |
| `options` | 构建器与报告选项，支持 subject、metadata 以及 get_report() 选项。 |

返回：GFValidationReportDictionary 兼容报告。

结构：

- `contract_entries`: Array[Dictionary] bridge contract entries.
- `adapter_entries`: Array[Dictionary] bridge adapter entries.
- `options`: Dictionary builder and report options.
- `return`: Dictionary bridge contract coverage report.

<a id="member-gfbridgecontractreport-methods-report_request_handlers"></a>

### `report_request_handlers`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func report_request_handlers( required_request_types: PackedStringArray, registry: GFRequestHandlerRegistry, options: Dictionary = {} ) -> Dictionary:
```

为 GFRequestHandlerRegistry 生成请求 handler 覆盖报告。

参数：

| 名称 | 说明 |
|---|---|
| `required_request_types` | 必需请求类型列表。 |
| `registry` | 请求 handler 注册表。 |
| `options` | 构建器与报告选项，支持 subject、metadata、kind、signature、adapter_kind 以及 get_report() 选项。 |

返回：GFValidationReportDictionary 兼容报告。

结构：

- `options`: Dictionary builder and report options.
- `return`: Dictionary request handler bridge coverage report.
