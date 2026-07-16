# GFPlatformCapabilitySet

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/platform/gf_platform_capability_set.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`8.0.0`

平台能力集合。 用纯数据描述某个运行平台或外部 adapter 暴露的能力及其限制。GF 不内置 具体平台表，调用方应使用稳定的业务无关能力 ID。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`platform_id`](#member-gfplatformcapabilityset-properties-platform_id) | `var platform_id: StringName = &""` |
| 属性 | [`adapter_id`](#member-gfplatformcapabilityset-properties-adapter_id) | `var adapter_id: StringName = &""` |
| 属性 | [`capabilities`](#member-gfplatformcapabilityset-properties-capabilities) | `var capabilities: PackedStringArray = PackedStringArray()` |
| 属性 | [`limits`](#member-gfplatformcapabilityset-properties-limits) | `var limits: Dictionary = {}` |
| 属性 | [`metadata`](#member-gfplatformcapabilityset-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfplatformcapabilityset-methods-configure) | `func configure( p_platform_id: StringName, p_capabilities: PackedStringArray = PackedStringArray(), p_metadata: Dictionary = {}, p_adapter_id: StringName = &"" ) -> GFPlatformCapabilitySet:` |
| 方法 | [`clear`](#member-gfplatformcapabilityset-methods-clear) | `func clear() -> void:` |
| 方法 | [`add_capability`](#member-gfplatformcapabilityset-methods-add_capability) | `func add_capability(capability_id: StringName, capability_limits: Dictionary = {}) -> bool:` |
| 方法 | [`remove_capability`](#member-gfplatformcapabilityset-methods-remove_capability) | `func remove_capability(capability_id: StringName) -> bool:` |
| 方法 | [`has_capability`](#member-gfplatformcapabilityset-methods-has_capability) | `func has_capability(capability_id: StringName) -> bool:` |
| 方法 | [`has_all`](#member-gfplatformcapabilityset-methods-has_all) | `func has_all(required_capabilities: PackedStringArray) -> bool:` |
| 方法 | [`has_any`](#member-gfplatformcapabilityset-methods-has_any) | `func has_any(candidate_capabilities: PackedStringArray) -> bool:` |
| 方法 | [`set_limit`](#member-gfplatformcapabilityset-methods-set_limit) | `func set_limit(capability_id: StringName, key: StringName, value: Variant) -> bool:` |
| 方法 | [`get_limit`](#member-gfplatformcapabilityset-methods-get_limit) | `func get_limit(capability_id: StringName, key: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`get_capability_limits`](#member-gfplatformcapabilityset-methods-get_capability_limits) | `func get_capability_limits(capability_id: StringName) -> Dictionary:` |
| 方法 | [`merge_from`](#member-gfplatformcapabilityset-methods-merge_from) | `func merge_from(other: GFPlatformCapabilitySet, overwrite_existing: bool = true) -> GFPlatformCapabilitySet:` |
| 方法 | [`to_dict`](#member-gfplatformcapabilityset-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfplatformcapabilityset-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_set`](#member-gfplatformcapabilityset-methods-duplicate_set) | `func duplicate_set() -> GFPlatformCapabilitySet:` |
| 方法 | [`from_dict`](#member-gfplatformcapabilityset-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFPlatformCapabilitySet:` |

## 属性

<a id="member-gfplatformcapabilityset-properties-platform_id"></a>

### `platform_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var platform_id: StringName = &""
```

平台标识。

<a id="member-gfplatformcapabilityset-properties-adapter_id"></a>

### `adapter_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var adapter_id: StringName = &""
```

Adapter 标识。

<a id="member-gfplatformcapabilityset-properties-capabilities"></a>

### `capabilities`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var capabilities: PackedStringArray = PackedStringArray()
```

能力 ID 列表。

<a id="member-gfplatformcapabilityset-properties-limits"></a>

### `limits`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var limits: Dictionary = {}
```

能力限制表。

结构：

- `limits`: Dictionary[String, Dictionary]，key 为 capability_id。

<a id="member-gfplatformcapabilityset-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方元数据。

结构：

- `metadata`: Dictionary caller-defined metadata.

## 方法

<a id="member-gfplatformcapabilityset-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure( p_platform_id: StringName, p_capabilities: PackedStringArray = PackedStringArray(), p_metadata: Dictionary = {}, p_adapter_id: StringName = &"" ) -> GFPlatformCapabilitySet:
```

配置能力集合。

参数：

| 名称 | 说明 |
|---|---|
| `p_platform_id` | 平台标识。 |
| `p_capabilities` | 能力 ID 列表。 |
| `p_metadata` | 调用方元数据。 |
| `p_adapter_id` | Adapter 标识。 |

返回：当前能力集合。

结构：

- `p_metadata`: Dictionary caller-defined metadata.

<a id="member-gfplatformcapabilityset-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear() -> void:
```

清空能力集合。

<a id="member-gfplatformcapabilityset-methods-add_capability"></a>

### `add_capability`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func add_capability(capability_id: StringName, capability_limits: Dictionary = {}) -> bool:
```

添加能力。

参数：

| 名称 | 说明 |
|---|---|
| `capability_id` | 能力 ID。 |
| `capability_limits` | 能力限制字段。 |

返回：成功添加或已存在时返回 true。

结构：

- `capability_limits`: Dictionary capability limits.

<a id="member-gfplatformcapabilityset-methods-remove_capability"></a>

### `remove_capability`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func remove_capability(capability_id: StringName) -> bool:
```

移除能力。

参数：

| 名称 | 说明 |
|---|---|
| `capability_id` | 能力 ID。 |

返回：找到并移除时返回 true。

<a id="member-gfplatformcapabilityset-methods-has_capability"></a>

### `has_capability`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_capability(capability_id: StringName) -> bool:
```

检查能力是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `capability_id` | 能力 ID。 |

返回：存在返回 true。

<a id="member-gfplatformcapabilityset-methods-has_all"></a>

### `has_all`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_all(required_capabilities: PackedStringArray) -> bool:
```

检查是否包含全部能力。

参数：

| 名称 | 说明 |
|---|---|
| `required_capabilities` | 需要的能力 ID 列表。 |

返回：全部存在返回 true；空列表返回 true。

<a id="member-gfplatformcapabilityset-methods-has_any"></a>

### `has_any`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_any(candidate_capabilities: PackedStringArray) -> bool:
```

检查是否包含任一能力。

参数：

| 名称 | 说明 |
|---|---|
| `candidate_capabilities` | 候选能力 ID 列表。 |

返回：任一存在返回 true；空列表返回 false。

<a id="member-gfplatformcapabilityset-methods-set_limit"></a>

### `set_limit`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_limit(capability_id: StringName, key: StringName, value: Variant) -> bool:
```

设置能力限制字段。

参数：

| 名称 | 说明 |
|---|---|
| `capability_id` | 能力 ID。 |
| `key` | 限制字段名。 |
| `value` | 限制字段值。 |

返回：写入成功返回 true。

结构：

- `value`: Caller-defined limit value.

<a id="member-gfplatformcapabilityset-methods-get_limit"></a>

### `get_limit`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_limit(capability_id: StringName, key: StringName, default_value: Variant = null) -> Variant:
```

读取能力限制字段。

参数：

| 名称 | 说明 |
|---|---|
| `capability_id` | 能力 ID。 |
| `key` | 限制字段名。 |
| `default_value` | 缺失时返回的默认值。 |

返回：限制字段值。

结构：

- `default_value`: Caller-defined default value.
- `return`: Caller-defined limit value.

<a id="member-gfplatformcapabilityset-methods-get_capability_limits"></a>

### `get_capability_limits`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_capability_limits(capability_id: StringName) -> Dictionary:
```

读取能力限制字典。

参数：

| 名称 | 说明 |
|---|---|
| `capability_id` | 能力 ID。 |

返回：能力限制字典副本。

结构：

- `return`: Dictionary capability limits.

<a id="member-gfplatformcapabilityset-methods-merge_from"></a>

### `merge_from`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func merge_from(other: GFPlatformCapabilitySet, overwrite_existing: bool = true) -> GFPlatformCapabilitySet:
```

合并另一个能力集合。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个能力集合。 |
| `overwrite_existing` | 是否覆盖已有限制和元数据字段。 |

返回：当前能力集合。

<a id="member-gfplatformcapabilityset-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：能力集合字典。

结构：

- `return`: Dictionary with platform_id, adapter_id, capabilities, limits, and metadata.

<a id="member-gfplatformcapabilityset-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用能力集合字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 能力集合字典。 |

结构：

- `data`: Dictionary with platform_id, adapter_id, capabilities, limits, and metadata.

<a id="member-gfplatformcapabilityset-methods-duplicate_set"></a>

### `duplicate_set`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_set() -> GFPlatformCapabilitySet:
```

创建能力集合深拷贝。

返回：新能力集合。

<a id="member-gfplatformcapabilityset-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFPlatformCapabilitySet:
```

从字典创建能力集合。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 能力集合字典。 |

返回：新能力集合。

结构：

- `data`: Dictionary with platform_id, adapter_id, capabilities, limits, and metadata.
