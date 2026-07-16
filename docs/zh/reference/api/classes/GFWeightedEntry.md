# GFWeightedEntry

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_weighted_entry.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

权重表中的单个候选项。 只保存值、权重和可选元数据，不约束 value 的业务类型。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`value`](#member-gfweightedentry-properties-value) | `var value: Variant = null` |
| 属性 | [`weight`](#member-gfweightedentry-properties-weight) | `var weight: float = 1.0:` |
| 属性 | [`metadata`](#member-gfweightedentry-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfweightedentry-methods-configure) | `func configure(p_value: Variant, p_weight: float = 1.0, p_metadata: Dictionary = {}) -> GFWeightedEntry:` |
| 方法 | [`is_selectable`](#member-gfweightedentry-methods-is_selectable) | `func is_selectable() -> bool:` |
| 方法 | [`duplicate_entry`](#member-gfweightedentry-methods-duplicate_entry) | `func duplicate_entry(deep: bool = true) -> GFWeightedEntry:` |
| 方法 | [`to_dict`](#member-gfweightedentry-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfweightedentry-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFWeightedEntry:` |

## 属性

<a id="member-gfweightedentry-properties-value"></a>

### `value`

- API：`public`

```gdscript
var value: Variant = null
```

被选择后返回的值。

结构：

- `value`: Variant selected value owned by project code.

<a id="member-gfweightedentry-properties-weight"></a>

### `weight`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var weight: float = 1.0:
```

权重；必须是有限正数才会被选择。

<a id="member-gfweightedentry-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目层可选元数据，框架不解释其含义。

结构：

- `metadata`: Dictionary extension metadata for the weighted entry.

## 方法

<a id="member-gfweightedentry-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure(p_value: Variant, p_weight: float = 1.0, p_metadata: Dictionary = {}) -> GFWeightedEntry:
```

配置条目内容。

参数：

| 名称 | 说明 |
|---|---|
| `p_value` | 被选择后返回的值。 |
| `p_weight` | 权重；非有限数或小于等于 0 表示不可被选择。 |
| `p_metadata` | 可选元数据。 |

返回：当前条目。

结构：

- `p_value`: Variant selected value owned by project code.
- `p_metadata`: Dictionary extension metadata for the weighted entry.

<a id="member-gfweightedentry-methods-is_selectable"></a>

### `is_selectable`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_selectable() -> bool:
```

判断该条目当前是否可被选择。

返回：权重为有限正数时返回 true。

<a id="member-gfweightedentry-methods-duplicate_entry"></a>

### `duplicate_entry`

- API：`public`

```gdscript
func duplicate_entry(deep: bool = true) -> GFWeightedEntry:
```

复制当前条目。

参数：

| 名称 | 说明 |
|---|---|
| `deep` | 是否深拷贝元数据。 |

返回：新条目实例。

<a id="member-gfweightedentry-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

导出为通用字典。

返回：包含 `value`、`weight` 与 `metadata` 的字典。

结构：

- `return`: Dictionary serialized weighted entry.

<a id="member-gfweightedentry-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
static func from_dict(data: Dictionary) -> GFWeightedEntry:
```

从通用字典创建条目。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 包含 `value`、`weight` 与 `metadata` 的字典。 |

返回：新条目实例。

结构：

- `data`: Dictionary serialized weighted entry.
