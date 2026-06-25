# GFQuerySignature

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/collections/gf_query_signature.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`6.0.0`

域分离的通用查询签名。 用稳定的 domain/value 结构生成可缓存的查询 key，避免把不同语义域的条件简单合并后产生歧义。 它只负责签名构建，不规定查询含义或匹配规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`clear`](#member-gfquerysignature-methods-clear) | `func clear() -> void:` |
| 方法 | [`add_value`](#member-gfquerysignature-methods-add_value) | `func add_value(domain: StringName, value: Variant) -> GFQuerySignature:` |
| 方法 | [`add_values`](#member-gfquerysignature-methods-add_values) | `func add_values(domain: StringName, values: Variant) -> GFQuerySignature:` |
| 方法 | [`add_flag`](#member-gfquerysignature-methods-add_flag) | `func add_flag(domain: StringName, enabled: bool) -> GFQuerySignature:` |
| 方法 | [`has_domain`](#member-gfquerysignature-methods-has_domain) | `func has_domain(domain: StringName) -> bool:` |
| 方法 | [`get_domain_values`](#member-gfquerysignature-methods-get_domain_values) | `func get_domain_values(domain: StringName) -> PackedStringArray:` |
| 方法 | [`to_dictionary`](#member-gfquerysignature-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`to_text`](#member-gfquerysignature-methods-to_text) | `func to_text() -> String:` |
| 方法 | [`to_hash`](#member-gfquerysignature-methods-to_hash) | `func to_hash() -> int:` |
| 方法 | [`from_dictionary`](#member-gfquerysignature-methods-from_dictionary) | `static func from_dictionary(domains: Dictionary) -> GFQuerySignature:` |

## 方法

<a id="member-gfquerysignature-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func clear() -> void:
```

清空签名内容。

<a id="member-gfquerysignature-methods-add_value"></a>

### `add_value`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func add_value(domain: StringName, value: Variant) -> GFQuerySignature:
```

添加单个域值。

参数：

| 名称 | 说明 |
|---|---|
| `domain` | 条件域，例如 all、any、none、group。 |
| `value` | 条件值。 |

返回：当前签名，便于链式调用。

结构：

- `value`: Variant condition value encoded with typeof() and var_to_str().

<a id="member-gfquerysignature-methods-add_values"></a>

### `add_values`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func add_values(domain: StringName, values: Variant) -> GFQuerySignature:
```

添加一组域值。

参数：

| 名称 | 说明 |
|---|---|
| `domain` | 条件域。 |
| `values` | 条件值集合。 |

返回：当前签名，便于链式调用。

结构：

- `values`: Variant accepted as Array, Dictionary keys, PackedStringArray, PackedInt32Array, PackedInt64Array, PackedFloat32Array, PackedFloat64Array, or scalar value.

<a id="member-gfquerysignature-methods-add_flag"></a>

### `add_flag`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func add_flag(domain: StringName, enabled: bool) -> GFQuerySignature:
```

添加布尔标记域。

参数：

| 名称 | 说明 |
|---|---|
| `domain` | 条件域。 |
| `enabled` | 标记值。 |

返回：当前签名，便于链式调用。

<a id="member-gfquerysignature-methods-has_domain"></a>

### `has_domain`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func has_domain(domain: StringName) -> bool:
```

检查域是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `domain` | 条件域。 |

返回：存在返回 true。

<a id="member-gfquerysignature-methods-get_domain_values"></a>

### `get_domain_values`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_domain_values(domain: StringName) -> PackedStringArray:
```

获取域内规范化值列表。

参数：

| 名称 | 说明 |
|---|---|
| `domain` | 条件域。 |

返回：已排序的规范化值列表。

<a id="member-gfquerysignature-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func to_dictionary() -> Dictionary:
```

导出为稳定字典。

返回：签名字典。

结构：

- `return`: Dictionary mapping domain names to sorted PackedStringArray encoded values.

<a id="member-gfquerysignature-methods-to_text"></a>

### `to_text`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func to_text() -> String:
```

导出为稳定文本。

返回：可作为缓存 key 的签名文本。

<a id="member-gfquerysignature-methods-to_hash"></a>

### `to_hash`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func to_hash() -> int:
```

获取签名 hash。

返回：基于 to_text() 的运行时 hash。

<a id="member-gfquerysignature-methods-from_dictionary"></a>

### `from_dictionary`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func from_dictionary(domains: Dictionary) -> GFQuerySignature:
```

从域字典创建签名。

参数：

| 名称 | 说明 |
|---|---|
| `domains` | 域到值集合的字典。 |

返回：新签名。

结构：

- `domains`: Dictionary mapping domain names to value collections.
