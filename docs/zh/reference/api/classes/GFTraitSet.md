# GFTraitSet

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/traits/gf_trait_set.gd`
- 模块：`Domain`
- 继承：`Resource`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

通用特征集合。 可从任意来源收集 `GFTrait`，再按目标键与分类计算最终数值。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`traits`](#member-gftraitset-properties-traits) | `var traits: Array[GFTrait] = []` |
| 方法 | [`add_trait`](#member-gftraitset-methods-add_trait) | `func add_trait(p_trait: GFTrait) -> void:` |
| 方法 | [`remove_traits_by_id`](#member-gftraitset-methods-remove_traits_by_id) | `func remove_traits_by_id(trait_id: StringName) -> void:` |
| 方法 | [`get_traits`](#member-gftraitset-methods-get_traits) | `func get_traits(target_id: StringName, category: StringName = &"") -> Array[GFTrait]:` |
| 方法 | [`calculate_number`](#member-gftraitset-methods-calculate_number) | `func calculate_number(target_id: StringName, base_value: float, category: StringName = &"") -> float:` |
| 方法 | [`clear`](#member-gftraitset-methods-clear) | `func clear() -> void:` |

## 属性

<a id="member-gftraitset-properties-traits"></a>

### `traits`

- API：`public`

```gdscript
var traits: Array[GFTrait] = []
```

特征列表。

结构：

- `traits`: Array[GFTrait]，按 priority 排序保存的特征资源列表。

## 方法

<a id="member-gftraitset-methods-add_trait"></a>

### `add_trait`

- API：`public`

```gdscript
func add_trait(p_trait: GFTrait) -> void:
```

添加一个特征。

参数：

| 名称 | 说明 |
|---|---|
| `p_trait` | 特征资源。 |

<a id="member-gftraitset-methods-remove_traits_by_id"></a>

### `remove_traits_by_id`

- API：`public`

```gdscript
func remove_traits_by_id(trait_id: StringName) -> void:
```

按 ID 移除特征。

参数：

| 名称 | 说明 |
|---|---|
| `trait_id` | 特征 ID。 |

<a id="member-gftraitset-methods-get_traits"></a>

### `get_traits`

- API：`public`

```gdscript
func get_traits(target_id: StringName, category: StringName = &"") -> Array[GFTrait]:
```

查询匹配的特征。

参数：

| 名称 | 说明 |
|---|---|
| `target_id` | 目标键。 |
| `category` | 可选分类；为空时不按分类过滤。 |

返回：匹配特征数组。

结构：

- `return`: Array[GFTrait]，匹配目标键和分类过滤条件的特征资源。

<a id="member-gftraitset-methods-calculate_number"></a>

### `calculate_number`

- API：`public`

```gdscript
func calculate_number(target_id: StringName, base_value: float, category: StringName = &"") -> float:
```

计算目标键的最终数值。

参数：

| 名称 | 说明 |
|---|---|
| `target_id` | 目标键。 |
| `base_value` | 基础值。 |
| `category` | 可选分类。 |

返回：合并后的数值。

<a id="member-gftraitset-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空特征。
