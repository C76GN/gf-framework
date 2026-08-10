# GFResourceRegistryEntry

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_resource_registry_entry.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.21.0`

通用资源注册表条目。 用稳定 ID 描述一个可通过 ResourceLoader 读取的资源路径、可选类型提示和可索引字段。 条目不解释字段业务含义，只为 GFResourceRegistry 提供数据。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`id`](#member-gfresourceregistryentry-properties-id) | `var id: StringName = &""` |
| 属性 | [`path`](#member-gfresourceregistryentry-properties-path) | `var path: String = ""` |
| 属性 | [`type_hint`](#member-gfresourceregistryentry-properties-type_hint) | `var type_hint: String = ""` |
| 属性 | [`fields`](#member-gfresourceregistryentry-properties-fields) | `var fields: Dictionary = {}` |
| 方法 | [`configure`](#member-gfresourceregistryentry-methods-configure) | `func configure( entry_id: StringName, entry_path: String, hint: String = "", indexed_fields: Dictionary = {} ) -> Resource:` |
| 方法 | [`is_valid_entry`](#member-gfresourceregistryentry-methods-is_valid_entry) | `func is_valid_entry() -> bool:` |
| 方法 | [`duplicate_entry`](#member-gfresourceregistryentry-methods-duplicate_entry) | `func duplicate_entry() -> Resource:` |
| 方法 | [`get_resource_identity`](#member-gfresourceregistryentry-methods-get_resource_identity) | `func get_resource_identity() -> GFResourceIdentity:` |
| 方法 | [`get_cache_key`](#member-gfresourceregistryentry-methods-get_cache_key) | `func get_cache_key() -> String:` |
| 方法 | [`to_dict`](#member-gfresourceregistryentry-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfresourceregistryentry-methods-from_dict) | `static func from_dict(data: Dictionary) -> Resource:` |

## 属性

<a id="member-gfresourceregistryentry-properties-id"></a>

### `id`

- API：`public`

```gdscript
var id: StringName = &""
```

条目稳定 ID。推荐使用 StringName，不应把资源路径当作项目逻辑 ID。

<a id="member-gfresourceregistryentry-properties-path"></a>

### `path`

- API：`public`

```gdscript
var path: String = ""
```

资源路径。支持普通 `res://` 路径，也支持 Godot 的 `uid://` 路径。

<a id="member-gfresourceregistryentry-properties-type_hint"></a>

### `type_hint`

- API：`public`

```gdscript
var type_hint: String = ""
```

可选资源类型提示，会传给 ResourceLoader 或 GFAssetUtility。

<a id="member-gfresourceregistryentry-properties-fields"></a>

### `fields`

- API：`public`

```gdscript
var fields: Dictionary = {}
```

可索引字段。字段值可为单值、Array 或 PackedStringArray。

结构：

- `fields`: Dictionary from field id to scalar, Array, or PackedStringArray values.

## 方法

<a id="member-gfresourceregistryentry-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure( entry_id: StringName, entry_path: String, hint: String = "", indexed_fields: Dictionary = {} ) -> Resource:
```

配置条目并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `entry_id` | 条目稳定 ID。 |
| `entry_path` | 资源路径，支持 \`res://\` 或 \`uid://\`。 |
| `hint` | 可选资源类型提示。 |
| `indexed_fields` | 可索引字段。 |

返回：当前条目。

结构：

- `indexed_fields`: Dictionary from field id to scalar, Array, or PackedStringArray values.

<a id="member-gfresourceregistryentry-methods-is_valid_entry"></a>

### `is_valid_entry`

- API：`public`

```gdscript
func is_valid_entry() -> bool:
```

检查条目是否包含可用 ID 和资源路径。

返回：条目可被注册表使用时返回 true。

<a id="member-gfresourceregistryentry-methods-duplicate_entry"></a>

### `duplicate_entry`

- API：`public`

```gdscript
func duplicate_entry() -> Resource:
```

创建条目副本。

返回：条目副本。

<a id="member-gfresourceregistryentry-methods-get_resource_identity"></a>

### `get_resource_identity`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_resource_identity() -> GFResourceIdentity:
```

获取条目的规范资源身份。

返回：资源身份对象。

<a id="member-gfresourceregistryentry-methods-get_cache_key"></a>

### `get_cache_key`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_cache_key() -> String:
```

获取条目的推荐缓存键。

返回：资源身份 cache_key。

<a id="member-gfresourceregistryentry-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`3.21.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为可序列化字典。

返回：条目字典。

结构：

- `return`: Dictionary with id, resource_path, type_hint, cache_key, resource_identity, and fields.

<a id="member-gfresourceregistryentry-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`3.21.0`

```gdscript
static func from_dict(data: Dictionary) -> Resource:
```

从字典创建条目。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 条目字典。 |

返回：新条目。

结构：

- `data`: Dictionary with optional id, resource_path, type_hint, cache_key, resource_identity, and fields.
