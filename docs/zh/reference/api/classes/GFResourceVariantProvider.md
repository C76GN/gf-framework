# GFResourceVariantProvider

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_resource_variant_provider.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`6.0.0`

资源键变体解析 provider。 为 GFResourceResolverUtility 提供按变体键选择资源路径的通用 provider。变体键可以表示语言、 平台、皮肤、质量档位或项目自定义域；本类只处理优先级和回退，不解释变体业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_VARIANT_KEY`](#member-gfresourcevariantprovider-constants-default_variant_key) | `const DEFAULT_VARIANT_KEY: StringName = &"default"` |
| 方法 | [`clear`](#member-gfresourcevariantprovider-methods-clear) | `func clear() -> void:` |
| 方法 | [`set_default_variant_order`](#member-gfresourcevariantprovider-methods-set_default_variant_order) | `func set_default_variant_order(variant_keys: PackedStringArray) -> void:` |
| 方法 | [`get_default_variant_order`](#member-gfresourcevariantprovider-methods-get_default_variant_order) | `func get_default_variant_order() -> PackedStringArray:` |
| 方法 | [`register_variant`](#member-gfresourcevariantprovider-methods-register_variant) | `func register_variant( resource_key: StringName, variant_key: StringName, path: String, type_hint: String = "", priority: int = 0, metadata: Dictionary = {} ) -> bool:` |
| 方法 | [`unregister_variant`](#member-gfresourcevariantprovider-methods-unregister_variant) | `func unregister_variant(resource_key: StringName, variant_key: StringName) -> bool:` |
| 方法 | [`has_variant`](#member-gfresourcevariantprovider-methods-has_variant) | `func has_variant(resource_key: StringName, variant_key: StringName) -> bool:` |
| 方法 | [`get_variant_keys`](#member-gfresourcevariantprovider-methods-get_variant_keys) | `func get_variant_keys(resource_key: StringName) -> PackedStringArray:` |
| 方法 | [`resolve_resource`](#member-gfresourcevariantprovider-methods-resolve_resource) | `func resolve_resource(request: Dictionary) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfresourcevariantprovider-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 常量

<a id="member-gfresourcevariantprovider-constants-default_variant_key"></a>

### `DEFAULT_VARIANT_KEY`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const DEFAULT_VARIANT_KEY: StringName = &"default"
```

默认变体键。注册为空变体时可作为最后回退。

## 方法

<a id="member-gfresourcevariantprovider-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func clear() -> void:
```

清空全部变体注册。

<a id="member-gfresourcevariantprovider-methods-set_default_variant_order"></a>

### `set_default_variant_order`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func set_default_variant_order(variant_keys: PackedStringArray) -> void:
```

设置默认变体回退顺序。

参数：

| 名称 | 说明 |
|---|---|
| `variant_keys` | 变体键列表，越靠前越优先。 |

<a id="member-gfresourcevariantprovider-methods-get_default_variant_order"></a>

### `get_default_variant_order`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_default_variant_order() -> PackedStringArray:
```

获取默认变体回退顺序副本。

返回：变体键列表。

<a id="member-gfresourcevariantprovider-methods-register_variant"></a>

### `register_variant`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func register_variant( resource_key: StringName, variant_key: StringName, path: String, type_hint: String = "", priority: int = 0, metadata: Dictionary = {} ) -> bool:
```

注册资源键的某个变体路径。

参数：

| 名称 | 说明 |
|---|---|
| `resource_key` | 稳定资源键。 |
| `variant_key` | 变体键；为空时归一为 default。 |
| `path` | Godot 资源路径。 |
| `type_hint` | 可选 ResourceLoader 类型提示。 |
| `priority` | 同一资源键和变体键重复注册时，数值越大越优先。 |
| `metadata` | 调用方自定义元数据。 |

返回：注册成功返回 true。

结构：

- `metadata`: Dictionary project-defined metadata copied into resolution reports.

<a id="member-gfresourcevariantprovider-methods-unregister_variant"></a>

### `unregister_variant`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func unregister_variant(resource_key: StringName, variant_key: StringName) -> bool:
```

注销资源键的某个变体。

参数：

| 名称 | 说明 |
|---|---|
| `resource_key` | 稳定资源键。 |
| `variant_key` | 变体键；为空时归一为 default。 |

返回：成功移除返回 true。

<a id="member-gfresourcevariantprovider-methods-has_variant"></a>

### `has_variant`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func has_variant(resource_key: StringName, variant_key: StringName) -> bool:
```

检查资源键是否有指定变体。

参数：

| 名称 | 说明 |
|---|---|
| `resource_key` | 稳定资源键。 |
| `variant_key` | 变体键；为空时归一为 default。 |

返回：存在返回 true。

<a id="member-gfresourcevariantprovider-methods-get_variant_keys"></a>

### `get_variant_keys`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_variant_keys(resource_key: StringName) -> PackedStringArray:
```

获取资源键已注册的变体键。

参数：

| 名称 | 说明 |
|---|---|
| `resource_key` | 稳定资源键。 |

返回：排序后的变体键列表。

<a id="member-gfresourcevariantprovider-methods-resolve_resource"></a>

### `resolve_resource`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func resolve_resource(request: Dictionary) -> Dictionary:
```

GFResourceResolverUtility provider 协议入口。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 资源解析请求。 |

返回：provider 解析报告。

结构：

- `request`: Dictionary from GFResourceResolverUtility containing key, type_hint, and options.
- `return`: Dictionary with ok, path, type_hint, provider_id, reason, and metadata.

<a id="member-gfresourcevariantprovider-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取诊断快照。

返回：诊断快照。

结构：

- `return`: Dictionary with resource_key_count, variant_count, default_variant_order, and keys.
