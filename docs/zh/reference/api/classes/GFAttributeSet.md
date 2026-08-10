# GFAttributeSet

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/attributes/gf_attribute_set.gd`
- 模块：`Domain`
- 继承：`Resource`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

通用数值属性集合。 用 StringName 管理一组可保存、可恢复、可限制范围的数值属性。它不规定 属性含义，生命值、耐久、温度、声望或任意项目数值都由项目层命名和解释。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`attribute_defined`](#member-gfattributeset-signals-attribute_defined) | `signal attribute_defined(attribute_id: StringName)` |
| 信号 | [`attribute_changed`](#member-gfattributeset-signals-attribute_changed) | `signal attribute_changed(attribute_id: StringName, current_value: float, previous_value: float)` |
| 常量 | [`DEFAULT_MIN_VALUE`](#member-gfattributeset-constants-default_min_value) | `const DEFAULT_MIN_VALUE: float = -1.0e20` |
| 常量 | [`DEFAULT_MAX_VALUE`](#member-gfattributeset-constants-default_max_value) | `const DEFAULT_MAX_VALUE: float = 1.0e20` |
| 属性 | [`attributes`](#member-gfattributeset-properties-attributes) | `var attributes: Dictionary = {}` |
| 属性 | [`derived_rules`](#member-gfattributeset-properties-derived_rules) | `var derived_rules: Array[GFDerivedAttributeRule] = []` |
| 方法 | [`define_attribute`](#member-gfattributeset-methods-define_attribute) | `func define_attribute( attribute_id: StringName, base_value: float = 0.0, current_value: Variant = null, min_value: float = DEFAULT_MIN_VALUE, max_value: float = DEFAULT_MAX_VALUE, metadata: Dictionary = {} ) -> void:` |
| 方法 | [`has_attribute`](#member-gfattributeset-methods-has_attribute) | `func has_attribute(attribute_id: StringName) -> bool:` |
| 方法 | [`remove_attribute`](#member-gfattributeset-methods-remove_attribute) | `func remove_attribute(attribute_id: StringName) -> void:` |
| 方法 | [`clear`](#member-gfattributeset-methods-clear) | `func clear() -> void:` |
| 方法 | [`set_value`](#member-gfattributeset-methods-set_value) | `func set_value(attribute_id: StringName, value: float) -> bool:` |
| 方法 | [`adjust_value`](#member-gfattributeset-methods-adjust_value) | `func adjust_value(attribute_id: StringName, delta: float) -> bool:` |
| 方法 | [`set_base_value`](#member-gfattributeset-methods-set_base_value) | `func set_base_value(attribute_id: StringName, value: float, sync_current: bool = false) -> bool:` |
| 方法 | [`set_limits`](#member-gfattributeset-methods-set_limits) | `func set_limits(attribute_id: StringName, min_value: float, max_value: float) -> bool:` |
| 方法 | [`get_value`](#member-gfattributeset-methods-get_value) | `func get_value(attribute_id: StringName, default_value: float = 0.0) -> float:` |
| 方法 | [`get_base_value`](#member-gfattributeset-methods-get_base_value) | `func get_base_value(attribute_id: StringName, default_value: float = 0.0) -> float:` |
| 方法 | [`get_value_with_traits`](#member-gfattributeset-methods-get_value_with_traits) | `func get_value_with_traits(attribute_id: StringName, trait_set: GFTraitSet) -> float:` |
| 方法 | [`get_metadata`](#member-gfattributeset-methods-get_metadata) | `func get_metadata(attribute_id: StringName) -> Dictionary:` |
| 方法 | [`set_metadata`](#member-gfattributeset-methods-set_metadata) | `func set_metadata(attribute_id: StringName, metadata: Dictionary) -> bool:` |
| 方法 | [`add_derived_rule`](#member-gfattributeset-methods-add_derived_rule) | `func add_derived_rule(rule: GFDerivedAttributeRule) -> bool:` |
| 方法 | [`remove_derived_rule`](#member-gfattributeset-methods-remove_derived_rule) | `func remove_derived_rule(attribute_id: StringName) -> bool:` |
| 方法 | [`get_derived_rule`](#member-gfattributeset-methods-get_derived_rule) | `func get_derived_rule(attribute_id: StringName) -> GFDerivedAttributeRule:` |
| 方法 | [`recalculate_derived`](#member-gfattributeset-methods-recalculate_derived) | `func recalculate_derived(attribute_id: StringName = &"") -> void:` |
| 方法 | [`get_snapshot`](#member-gfattributeset-methods-get_snapshot) | `func get_snapshot() -> Dictionary:` |
| 方法 | [`restore_snapshot`](#member-gfattributeset-methods-restore_snapshot) | `func restore_snapshot(snapshot: Dictionary) -> void:` |
| 方法 | [`to_dict`](#member-gfattributeset-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfattributeset-methods-from_dict) | `func from_dict(data: Dictionary) -> void:` |

## 信号

<a id="member-gfattributeset-signals-attribute_defined"></a>

### `attribute_defined`

- API：`public`

```gdscript
signal attribute_defined(attribute_id: StringName)
```

属性被定义时发出。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 被定义或替换的属性 ID。 |

<a id="member-gfattributeset-signals-attribute_changed"></a>

### `attribute_changed`

- API：`public`

```gdscript
signal attribute_changed(attribute_id: StringName, current_value: float, previous_value: float)
```

当前值变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 发生变化的属性 ID。 |
| `current_value` | 新当前值。 |
| `previous_value` | 旧当前值。 |

## 常量

<a id="member-gfattributeset-constants-default_min_value"></a>

### `DEFAULT_MIN_VALUE`

- API：`public`

```gdscript
const DEFAULT_MIN_VALUE: float = -1.0e20
```

默认属性最小值。

<a id="member-gfattributeset-constants-default_max_value"></a>

### `DEFAULT_MAX_VALUE`

- API：`public`

```gdscript
const DEFAULT_MAX_VALUE: float = 1.0e20
```

默认属性最大值。

## 属性

<a id="member-gfattributeset-properties-attributes"></a>

### `attributes`

- API：`public`

```gdscript
var attributes: Dictionary = {}
```

属性记录。结构为 attribute_id -> { base, current, min, max, metadata }。

结构：

- `attributes`: Dictionary，键为 StringName 属性 ID，值为包含 base: float、current: float、min: float、max: float、metadata: Dictionary 的记录。

<a id="member-gfattributeset-properties-derived_rules"></a>

### `derived_rules`

- API：`public`

```gdscript
var derived_rules: Array[GFDerivedAttributeRule] = []
```

派生属性规则列表。规则只计算属性值，不改变属性命名含义。

结构：

- `derived_rules`: Array[GFDerivedAttributeRule]，按顺序保存的派生属性规则资源。

## 方法

<a id="member-gfattributeset-methods-define_attribute"></a>

### `define_attribute`

- API：`public`

```gdscript
func define_attribute( attribute_id: StringName, base_value: float = 0.0, current_value: Variant = null, min_value: float = DEFAULT_MIN_VALUE, max_value: float = DEFAULT_MAX_VALUE, metadata: Dictionary = {} ) -> void:
```

定义或替换属性。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `base_value` | 基础值。 |
| `current_value` | 当前值；为 null 或 NAN 时使用 base_value。 |
| `min_value` | 最小值。 |
| `max_value` | 最大值。 |
| `metadata` | 项目自定义元数据。 |

结构：

- `current_value`: Variant，null 或 NAN 表示使用 base_value，数字值会转换为 float。
- `metadata`: Dictionary，项目自定义属性元数据；GF 会深拷贝保存。

<a id="member-gfattributeset-methods-has_attribute"></a>

### `has_attribute`

- API：`public`

```gdscript
func has_attribute(attribute_id: StringName) -> bool:
```

检查属性是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |

返回：存在返回 true。

<a id="member-gfattributeset-methods-remove_attribute"></a>

### `remove_attribute`

- API：`public`

```gdscript
func remove_attribute(attribute_id: StringName) -> void:
```

移除属性。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |

<a id="member-gfattributeset-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空所有属性。

<a id="member-gfattributeset-methods-set_value"></a>

### `set_value`

- API：`public`

```gdscript
func set_value(attribute_id: StringName, value: float) -> bool:
```

设置当前值。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `value` | 新值。 |

返回：成功返回 true。

<a id="member-gfattributeset-methods-adjust_value"></a>

### `adjust_value`

- API：`public`

```gdscript
func adjust_value(attribute_id: StringName, delta: float) -> bool:
```

增减当前值。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `delta` | 增量。 |

返回：成功返回 true。

<a id="member-gfattributeset-methods-set_base_value"></a>

### `set_base_value`

- API：`public`

```gdscript
func set_base_value(attribute_id: StringName, value: float, sync_current: bool = false) -> bool:
```

设置基础值。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `value` | 新基础值。 |
| `sync_current` | 是否同步当前值。 |

返回：成功返回 true。

<a id="member-gfattributeset-methods-set_limits"></a>

### `set_limits`

- API：`public`

```gdscript
func set_limits(attribute_id: StringName, min_value: float, max_value: float) -> bool:
```

设置属性范围。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `min_value` | 最小值。 |
| `max_value` | 最大值。 |

返回：成功返回 true。

<a id="member-gfattributeset-methods-get_value"></a>

### `get_value`

- API：`public`

```gdscript
func get_value(attribute_id: StringName, default_value: float = 0.0) -> float:
```

获取当前值。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `default_value` | 默认值。 |

返回：当前值。

<a id="member-gfattributeset-methods-get_base_value"></a>

### `get_base_value`

- API：`public`

```gdscript
func get_base_value(attribute_id: StringName, default_value: float = 0.0) -> float:
```

获取基础值。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `default_value` | 默认值。 |

返回：基础值。

<a id="member-gfattributeset-methods-get_value_with_traits"></a>

### `get_value_with_traits`

- API：`public`

```gdscript
func get_value_with_traits(attribute_id: StringName, trait_set: GFTraitSet) -> float:
```

通过 TraitSet 计算属性值。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `trait_set` | 特征集合。 |

返回：Trait 修饰后的值。

<a id="member-gfattributeset-methods-get_metadata"></a>

### `get_metadata`

- API：`public`

```gdscript
func get_metadata(attribute_id: StringName) -> Dictionary:
```

获取属性元数据。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |

返回：元数据副本。

结构：

- `return`: Dictionary，属性的项目自定义 metadata 副本；属性不存在时为空字典。

<a id="member-gfattributeset-methods-set_metadata"></a>

### `set_metadata`

- API：`public`

```gdscript
func set_metadata(attribute_id: StringName, metadata: Dictionary) -> bool:
```

设置属性元数据。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `metadata` | 元数据。 |

返回：成功返回 true。

结构：

- `metadata`: Dictionary，项目自定义属性元数据；GF 会深拷贝保存。

<a id="member-gfattributeset-methods-add_derived_rule"></a>

### `add_derived_rule`

- API：`public`

```gdscript
func add_derived_rule(rule: GFDerivedAttributeRule) -> bool:
```

添加或替换派生属性规则。

参数：

| 名称 | 说明 |
|---|---|
| `rule` | 派生属性规则。 |

返回：成功返回 true。

<a id="member-gfattributeset-methods-remove_derived_rule"></a>

### `remove_derived_rule`

- API：`public`

```gdscript
func remove_derived_rule(attribute_id: StringName) -> bool:
```

移除指定目标属性的派生规则。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 目标属性 ID。 |

返回：至少移除一个规则时返回 true。

<a id="member-gfattributeset-methods-get_derived_rule"></a>

### `get_derived_rule`

- API：`public`

```gdscript
func get_derived_rule(attribute_id: StringName) -> GFDerivedAttributeRule:
```

获取指定目标属性的派生规则。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 目标属性 ID。 |

返回：派生规则；不存在时返回 null。

<a id="member-gfattributeset-methods-recalculate_derived"></a>

### `recalculate_derived`

- API：`public`

```gdscript
func recalculate_derived(attribute_id: StringName = &"") -> void:
```

重新计算派生属性。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 目标属性 ID；为空时重算全部规则。 |

<a id="member-gfattributeset-methods-get_snapshot"></a>

### `get_snapshot`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_snapshot() -> Dictionary:
```

导出快照。

返回：Godot Variant 字典；不保证可直接编码为 JSON。

结构：

- `return`: Dictionary，键为 String 属性 ID，值为包含 base、current、min、max 与 metadata 的属性记录。

<a id="member-gfattributeset-methods-restore_snapshot"></a>

### `restore_snapshot`

- API：`public`

```gdscript
func restore_snapshot(snapshot: Dictionary) -> void:
```

从快照恢复。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 由 get_snapshot() 或 to_dict() 返回的数据。 |

结构：

- `snapshot`: Dictionary，键为 String 或 StringName 属性 ID，值为包含 base、current、min、max 与 metadata 的属性记录。

<a id="member-gfattributeset-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func to_dict() -> Dictionary:
```

序列化为字典。

返回：Godot Variant 字典；不保证可直接编码为 JSON。

结构：

- `return`: Dictionary，键为 String 属性 ID，值为包含 base、current、min、max 与 metadata 的属性记录。

<a id="member-gfattributeset-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
func from_dict(data: Dictionary) -> void:
```

从字典恢复。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 属性数据。 |

结构：

- `data`: Dictionary，键为 String 或 StringName 属性 ID，值为包含 base、current、min、max 与 metadata 的属性记录。
