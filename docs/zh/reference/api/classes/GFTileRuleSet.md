# GFTileRuleSet

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_tile_rule_set.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用瓦片邻域规则表。 使用邻域值序列匹配结果，可用于自动铺砖、地形变体、网格装饰或任意 基于相邻格子状态的选择逻辑。规则只处理 Variant 值，不绑定 TileSet 语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`fallback_neighbor_value`](#member-gftileruleset-properties-fallback_neighbor_value) | `var fallback_neighbor_value: Variant = 0` |
| 属性 | [`default_result`](#member-gftileruleset-properties-default_result) | `var default_result: Variant = null` |
| 属性 | [`deterministic_seed`](#member-gftileruleset-properties-deterministic_seed) | `var deterministic_seed: int = 0` |
| 方法 | [`register_rule`](#member-gftileruleset-methods-register_rule) | `func register_rule(neighbor_values: Array, result: Variant, weight: float = 1.0) -> void:` |
| 方法 | [`clear`](#member-gftileruleset-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_rule_count`](#member-gftileruleset-methods-get_rule_count) | `func get_rule_count() -> int:` |
| 方法 | [`resolve`](#member-gftileruleset-methods-resolve) | `func resolve(neighbor_values: Array, cell: Vector2i = Vector2i.ZERO, selection_seed: int = 0) -> Variant:` |
| 方法 | [`has_rule`](#member-gftileruleset-methods-has_rule) | `func has_rule(neighbor_values: Array) -> bool:` |

## 属性

<a id="member-gftileruleset-properties-fallback_neighbor_value"></a>

### `fallback_neighbor_value`

- API：`public`

```gdscript
var fallback_neighbor_value: Variant = 0
```

规则匹配失败时尝试使用的邻域回退值。

结构：

- `fallback_neighbor_value`: Variant fallback neighbor value used while resolving rules.

<a id="member-gftileruleset-properties-default_result"></a>

### `default_result`

- API：`public`

```gdscript
var default_result: Variant = null
```

没有匹配规则时返回的值。

结构：

- `default_result`: Variant fallback result returned when no rule matches.

<a id="member-gftileruleset-properties-deterministic_seed"></a>

### `deterministic_seed`

- API：`public`

```gdscript
var deterministic_seed: int = 0
```

参与确定性加权选择的默认种子。

## 方法

<a id="member-gftileruleset-methods-register_rule"></a>

### `register_rule`

- API：`public`

```gdscript
func register_rule(neighbor_values: Array, result: Variant, weight: float = 1.0) -> void:
```

注册一条邻域规则。

参数：

| 名称 | 说明 |
|---|---|
| `neighbor_values` | 邻域值序列。 |
| `result` | 匹配结果。 |
| `weight` | 同一邻域下多个结果的权重。 |

结构：

- `neighbor_values`: Array ordered neighbor values used as a rule key.
- `result`: Variant result returned when the rule matches.

<a id="member-gftileruleset-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空全部规则。

<a id="member-gftileruleset-methods-get_rule_count"></a>

### `get_rule_count`

- API：`public`

```gdscript
func get_rule_count() -> int:
```

获取已注册规则数量。

返回：规则数量。

<a id="member-gftileruleset-methods-resolve"></a>

### `resolve`

- API：`public`

```gdscript
func resolve(neighbor_values: Array, cell: Vector2i = Vector2i.ZERO, selection_seed: int = 0) -> Variant:
```

根据邻域值解析结果。

参数：

| 名称 | 说明 |
|---|---|
| `neighbor_values` | 邻域值序列。 |
| `cell` | 可选格坐标，用于确定性加权选择。 |
| `selection_seed` | 可选选择种子；为 0 时使用 deterministic_seed。 |

返回：匹配结果；没有匹配时返回 default_result。

结构：

- `neighbor_values`: Array ordered neighbor values used as a rule key.
- `return`: Variant matched result or default_result.

<a id="member-gftileruleset-methods-has_rule"></a>

### `has_rule`

- API：`public`

```gdscript
func has_rule(neighbor_values: Array) -> bool:
```

检查邻域值是否存在明确规则。

参数：

| 名称 | 说明 |
|---|---|
| `neighbor_values` | 邻域值序列。 |

返回：存在规则时返回 true。

结构：

- `neighbor_values`: Array ordered neighbor values used as a rule key.
