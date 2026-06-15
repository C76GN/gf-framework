# GFWeightedTable

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_weighted_table.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用权重选择表。 适合需要“按权重从候选集合中选择值”的纯算法场景。 该类只处理权重和随机源，不绑定掉落、奖励、AI 等业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`entries`](#member-gfweightedtable-properties-entries) | `var entries: Array[GFWeightedEntry] = []` |
| 属性 | [`default_value`](#member-gfweightedtable-properties-default_value) | `var default_value: Variant = null` |
| 属性 | [`deterministic_seed`](#member-gfweightedtable-properties-deterministic_seed) | `var deterministic_seed: int = 0` |
| 方法 | [`add_entry`](#member-gfweightedtable-methods-add_entry) | `func add_entry(value: Variant, weight: float = 1.0, metadata: Dictionary = {}) -> GFWeightedEntry:` |
| 方法 | [`add_weighted_entry`](#member-gfweightedtable-methods-add_weighted_entry) | `func add_weighted_entry(entry: GFWeightedEntry) -> bool:` |
| 方法 | [`remove_entry`](#member-gfweightedtable-methods-remove_entry) | `func remove_entry(entry: GFWeightedEntry) -> bool:` |
| 方法 | [`clear`](#member-gfweightedtable-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_selectable_entries`](#member-gfweightedtable-methods-get_selectable_entries) | `func get_selectable_entries() -> Array[GFWeightedEntry]:` |
| 方法 | [`get_total_weight`](#member-gfweightedtable-methods-get_total_weight) | `func get_total_weight() -> float:` |
| 方法 | [`is_empty`](#member-gfweightedtable-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`pick_entry`](#member-gfweightedtable-methods-pick_entry) | `func pick_entry(rng: Variant = null) -> GFWeightedEntry:` |
| 方法 | [`pick_value`](#member-gfweightedtable-methods-pick_value) | `func pick_value(rng: Variant = null) -> Variant:` |
| 方法 | [`pick_many`](#member-gfweightedtable-methods-pick_many) | `func pick_many( count: int, rng: Variant = null, allow_repeats: bool = true ) -> Array[Variant]:` |
| 方法 | [`duplicate_table`](#member-gfweightedtable-methods-duplicate_table) | `func duplicate_table(deep: bool = true) -> GFWeightedTable:` |
| 方法 | [`to_dict`](#member-gfweightedtable-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfweightedtable-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`from_dict`](#member-gfweightedtable-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFWeightedTable:` |

## 属性

<a id="member-gfweightedtable-properties-entries"></a>

### `entries`

- API：`public`

```gdscript
var entries: Array[GFWeightedEntry] = []
```

候选条目列表。

<a id="member-gfweightedtable-properties-default_value"></a>

### `default_value`

- API：`public`

```gdscript
var default_value: Variant = null
```

没有可选条目时返回的默认值。

结构：

- `default_value`: Variant fallback value returned when no entry can be selected.

<a id="member-gfweightedtable-properties-deterministic_seed"></a>

### `deterministic_seed`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var deterministic_seed: int = 0
```

可选 GF 固定随机源后备种子；为 0 时使用随机化 Godot RNG。

## 方法

<a id="member-gfweightedtable-methods-add_entry"></a>

### `add_entry`

- API：`public`

```gdscript
func add_entry(value: Variant, weight: float = 1.0, metadata: Dictionary = {}) -> GFWeightedEntry:
```

追加一个候选条目。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 被选择后返回的值。 |
| `weight` | 权重；小于等于 0 的条目会保留但不会被选择。 |
| `metadata` | 可选元数据。 |

返回：新增的条目实例。

结构：

- `value`: Variant selected value owned by project code.
- `metadata`: Dictionary extension metadata for the new weighted entry.

<a id="member-gfweightedtable-methods-add_weighted_entry"></a>

### `add_weighted_entry`

- API：`public`

```gdscript
func add_weighted_entry(entry: GFWeightedEntry) -> bool:
```

追加已有候选条目。

参数：

| 名称 | 说明 |
|---|---|
| `entry` | 要追加的条目。 |

返回：添加成功时返回 true。

<a id="member-gfweightedtable-methods-remove_entry"></a>

### `remove_entry`

- API：`public`

```gdscript
func remove_entry(entry: GFWeightedEntry) -> bool:
```

移除候选条目。

参数：

| 名称 | 说明 |
|---|---|
| `entry` | 要移除的条目。 |

返回：找到并移除时返回 true。

<a id="member-gfweightedtable-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空候选条目。

<a id="member-gfweightedtable-methods-get_selectable_entries"></a>

### `get_selectable_entries`

- API：`public`

```gdscript
func get_selectable_entries() -> Array[GFWeightedEntry]:
```

获取当前可被选择的条目。

返回：权重大于 0 的条目数组。

<a id="member-gfweightedtable-methods-get_total_weight"></a>

### `get_total_weight`

- API：`public`

```gdscript
func get_total_weight() -> float:
```

计算当前总权重。

返回：所有可选条目的权重总和。

<a id="member-gfweightedtable-methods-is_empty"></a>

### `is_empty`

- API：`public`

```gdscript
func is_empty() -> bool:
```

判断当前是否没有可选条目。

返回：没有可选条目时返回 true。

<a id="member-gfweightedtable-methods-pick_entry"></a>

### `pick_entry`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func pick_entry(rng: Variant = null) -> GFWeightedEntry:
```

按权重选择一个条目。

参数：

| 名称 | 说明 |
|---|---|
| `rng` | 可选随机源；支持 `RandomNumberGenerator` 或 `GFDeterministicRandom`。 |

返回：选中的条目；没有可选条目时返回 null。

结构：

- `rng`: RandomNumberGenerator or GFDeterministicRandom. Null uses deterministic_seed fallback or a randomized Godot RNG.

<a id="member-gfweightedtable-methods-pick_value"></a>

### `pick_value`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func pick_value(rng: Variant = null) -> Variant:
```

按权重选择一个值。

参数：

| 名称 | 说明 |
|---|---|
| `rng` | 可选随机源；支持 `RandomNumberGenerator` 或 `GFDeterministicRandom`。 |

返回：选中条目的 value；没有可选条目时返回 default_value。

结构：

- `rng`: RandomNumberGenerator or GFDeterministicRandom. Null uses deterministic_seed fallback or a randomized Godot RNG.
- `return`: Variant selected value or default_value.

<a id="member-gfweightedtable-methods-pick_many"></a>

### `pick_many`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func pick_many( count: int, rng: Variant = null, allow_repeats: bool = true ) -> Array[Variant]:
```

按权重选择多个值。

参数：

| 名称 | 说明 |
|---|---|
| `count` | 选择次数。 |
| `rng` | 可选随机源；支持 `RandomNumberGenerator` 或 `GFDeterministicRandom`。 |
| `allow_repeats` | 是否允许同一条目被重复选择。 |

返回：选中的 value 数组。

结构：

- `rng`: RandomNumberGenerator or GFDeterministicRandom. Null uses deterministic_seed fallback or a randomized Godot RNG.
- `return`: Array selected values.

<a id="member-gfweightedtable-methods-duplicate_table"></a>

### `duplicate_table`

- API：`public`

```gdscript
func duplicate_table(deep: bool = true) -> GFWeightedTable:
```

复制当前权重表。

参数：

| 名称 | 说明 |
|---|---|
| `deep` | 是否深拷贝条目和元数据。 |

返回：新权重表实例。

<a id="member-gfweightedtable-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

导出为通用字典。

返回：包含条目、默认值和确定性种子的字典。

结构：

- `return`: Dictionary serialized weighted table.

<a id="member-gfweightedtable-methods-apply_dict"></a>

### `apply_dict`

- API：`public`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

使用通用字典覆盖当前权重表。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 包含 `entries`、`default_value` 与 `deterministic_seed` 的字典。 |

结构：

- `data`: Dictionary serialized weighted table.

<a id="member-gfweightedtable-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
static func from_dict(data: Dictionary) -> GFWeightedTable:
```

从通用字典创建权重表。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 包含 `entries`、`default_value` 与 `deterministic_seed` 的字典。 |

返回：新权重表实例。

结构：

- `data`: Dictionary serialized weighted table.
