# GFResourceRegistry

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_resource_registry.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.21.0`

通用资源注册表。 通过稳定 ID 管理资源路径、类型提示和字段索引，便于项目用统一方式查询、 预加载或加载资源定义。注册表只描述资源位置和通用字段，不规定物品、技能、 关卡、UI 或其他业务规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`entries`](#member-gfresourceregistry-properties-entries) | `var entries: Array[GFResourceRegistryEntry] = []` |
| 方法 | [`set_entry`](#member-gfresourceregistry-methods-set_entry) | `func set_entry(entry: Resource) -> bool:` |
| 方法 | [`remove_entry`](#member-gfresourceregistry-methods-remove_entry) | `func remove_entry(entry_id: StringName) -> bool:` |
| 方法 | [`clear`](#member-gfresourceregistry-methods-clear) | `func clear() -> void:` |
| 方法 | [`mark_index_dirty`](#member-gfresourceregistry-methods-mark_index_dirty) | `func mark_index_dirty() -> void:` |
| 方法 | [`rebuild_index`](#member-gfresourceregistry-methods-rebuild_index) | `func rebuild_index() -> void:` |
| 方法 | [`has_entry`](#member-gfresourceregistry-methods-has_entry) | `func has_entry(entry_id: StringName) -> bool:` |
| 方法 | [`get_entry`](#member-gfresourceregistry-methods-get_entry) | `func get_entry(entry_id: StringName) -> Resource:` |
| 方法 | [`get_entry_path`](#member-gfresourceregistry-methods-get_entry_path) | `func get_entry_path(entry_id: StringName) -> String:` |
| 方法 | [`get_entry_type_hint`](#member-gfresourceregistry-methods-get_entry_type_hint) | `func get_entry_type_hint(entry_id: StringName) -> String:` |
| 方法 | [`get_entry_fields`](#member-gfresourceregistry-methods-get_entry_fields) | `func get_entry_fields(entry_id: StringName) -> Dictionary:` |
| 方法 | [`get_all_ids`](#member-gfresourceregistry-methods-get_all_ids) | `func get_all_ids() -> PackedStringArray:` |
| 方法 | [`get_all_paths`](#member-gfresourceregistry-methods-get_all_paths) | `func get_all_paths() -> PackedStringArray:` |
| 方法 | [`query`](#member-gfresourceregistry-methods-query) | `func query(field_id: StringName, field_value: Variant) -> PackedStringArray:` |
| 方法 | [`query_many`](#member-gfresourceregistry-methods-query_many) | `func query_many(criteria: Dictionary, match_all: bool = true) -> PackedStringArray:` |
| 方法 | [`load_entry`](#member-gfresourceregistry-methods-load_entry) | `func load_entry( entry_id: StringName, type_hint_override: String = "", cache_mode: int = ResourceLoader.CACHE_MODE_REUSE ) -> Resource:` |
| 方法 | [`request_entry_async`](#member-gfresourceregistry-methods-request_entry_async) | `func request_entry_async( asset_utility: GFAssetUtility, entry_id: StringName, on_loaded: Callable, type_hint_override: String = "" ) -> void:` |
| 方法 | [`request_entry_handle_async`](#member-gfresourceregistry-methods-request_entry_handle_async) | `func request_entry_handle_async( asset_utility: GFAssetUtility, entry_id: StringName, on_loaded: Callable, owner: Object = null, group_id: StringName = &"", type_hint_override: String = "" ) -> void:` |
| 方法 | [`make_asset_group_entries`](#member-gfresourceregistry-methods-make_asset_group_entries) | `func make_asset_group_entries(entry_ids: PackedStringArray = PackedStringArray()) -> Array:` |
| 方法 | [`get_debug_snapshot`](#member-gfresourceregistry-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`to_dict`](#member-gfresourceregistry-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfresourceregistry-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`from_dict`](#member-gfresourceregistry-methods-from_dict) | `static func from_dict(data: Dictionary) -> Resource:` |

## 属性

<a id="member-gfresourceregistry-properties-entries"></a>

### `entries`

- API：`public`

```gdscript
var entries: Array[GFResourceRegistryEntry] = []
```

注册表条目列表。重复 ID 会以后出现的有效条目为准。

结构：

- `entries`: Array[GFResourceRegistryEntry] resource registry entries.

## 方法

<a id="member-gfresourceregistry-methods-set_entry"></a>

### `set_entry`

- API：`public`

```gdscript
func set_entry(entry: Resource) -> bool:
```

添加或替换条目。

参数：

| 名称 | 说明 |
|---|---|
| `entry` | 要写入的注册表条目。 |

返回：写入成功返回 true。

<a id="member-gfresourceregistry-methods-remove_entry"></a>

### `remove_entry`

- API：`public`

```gdscript
func remove_entry(entry_id: StringName) -> bool:
```

移除条目。

参数：

| 名称 | 说明 |
|---|---|
| `entry_id` | 条目稳定 ID。 |

返回：移除成功返回 true。

<a id="member-gfresourceregistry-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空注册表。

<a id="member-gfresourceregistry-methods-mark_index_dirty"></a>

### `mark_index_dirty`

- API：`public`

```gdscript
func mark_index_dirty() -> void:
```

标记运行时索引需要重建。 直接修改 entries 数组或条目字段后，应调用本方法。

<a id="member-gfresourceregistry-methods-rebuild_index"></a>

### `rebuild_index`

- API：`public`

```gdscript
func rebuild_index() -> void:
```

立即重建运行时索引。

<a id="member-gfresourceregistry-methods-has_entry"></a>

### `has_entry`

- API：`public`

```gdscript
func has_entry(entry_id: StringName) -> bool:
```

检查条目是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `entry_id` | 条目稳定 ID。 |

返回：条目存在时返回 true。

<a id="member-gfresourceregistry-methods-get_entry"></a>

### `get_entry`

- API：`public`

```gdscript
func get_entry(entry_id: StringName) -> Resource:
```

获取条目副本。

参数：

| 名称 | 说明 |
|---|---|
| `entry_id` | 条目稳定 ID。 |

返回：条目副本；不存在时返回 null。

<a id="member-gfresourceregistry-methods-get_entry_path"></a>

### `get_entry_path`

- API：`public`

```gdscript
func get_entry_path(entry_id: StringName) -> String:
```

获取条目资源路径。

参数：

| 名称 | 说明 |
|---|---|
| `entry_id` | 条目稳定 ID。 |

返回：资源路径；不存在时返回空字符串。

<a id="member-gfresourceregistry-methods-get_entry_type_hint"></a>

### `get_entry_type_hint`

- API：`public`

```gdscript
func get_entry_type_hint(entry_id: StringName) -> String:
```

获取条目类型提示。

参数：

| 名称 | 说明 |
|---|---|
| `entry_id` | 条目稳定 ID。 |

返回：类型提示；不存在时返回空字符串。

<a id="member-gfresourceregistry-methods-get_entry_fields"></a>

### `get_entry_fields`

- API：`public`

```gdscript
func get_entry_fields(entry_id: StringName) -> Dictionary:
```

获取条目字段副本。

参数：

| 名称 | 说明 |
|---|---|
| `entry_id` | 条目稳定 ID。 |

返回：字段字典副本。

结构：

- `return`: Dictionary indexed field values.

<a id="member-gfresourceregistry-methods-get_all_ids"></a>

### `get_all_ids`

- API：`public`

```gdscript
func get_all_ids() -> PackedStringArray:
```

获取全部有效条目 ID。

返回：排序后的条目 ID 列表。

<a id="member-gfresourceregistry-methods-get_all_paths"></a>

### `get_all_paths`

- API：`public`

```gdscript
func get_all_paths() -> PackedStringArray:
```

获取全部有效资源路径。

返回：排序后的资源路径列表。

<a id="member-gfresourceregistry-methods-query"></a>

### `query`

- API：`public`

```gdscript
func query(field_id: StringName, field_value: Variant) -> PackedStringArray:
```

按单个字段值查询条目 ID。

参数：

| 名称 | 说明 |
|---|---|
| `field_id` | 字段标识。 |
| `field_value` | 字段值。 |

返回：匹配的条目 ID。

结构：

- `field_value`: Variant indexed field value.

<a id="member-gfresourceregistry-methods-query_many"></a>

### `query_many`

- API：`public`

```gdscript
func query_many(criteria: Dictionary, match_all: bool = true) -> PackedStringArray:
```

按多个字段查询条目 ID。

参数：

| 名称 | 说明 |
|---|---|
| `criteria` | 字段到值的查询条件。 |
| `match_all` | true 表示交集查询，false 表示并集查询。 |

返回：匹配的条目 ID。

结构：

- `criteria`: Dictionary from field id to query value.

<a id="member-gfresourceregistry-methods-load_entry"></a>

### `load_entry`

- API：`public`

```gdscript
func load_entry( entry_id: StringName, type_hint_override: String = "", cache_mode: int = ResourceLoader.CACHE_MODE_REUSE ) -> Resource:
```

同步加载条目资源。

参数：

| 名称 | 说明 |
|---|---|
| `entry_id` | 条目稳定 ID。 |
| `type_hint_override` | 可选类型提示覆盖；为空时使用条目自己的 type_hint。 |
| `cache_mode` | ResourceLoader 缓存模式。 |

返回：加载到的资源；不存在或加载失败时返回 null。

<a id="member-gfresourceregistry-methods-request_entry_async"></a>

### `request_entry_async`

- API：`public`

```gdscript
func request_entry_async( asset_utility: GFAssetUtility, entry_id: StringName, on_loaded: Callable, type_hint_override: String = "" ) -> void:
```

通过 GFAssetUtility 异步加载条目资源。

参数：

| 名称 | 说明 |
|---|---|
| `asset_utility` | 资源加载工具。 |
| `entry_id` | 条目稳定 ID。 |
| `on_loaded` | 加载完成回调，签名为 func(resource: Resource)。 |
| `type_hint_override` | 可选类型提示覆盖；为空时使用条目自己的 type_hint。 |

<a id="member-gfresourceregistry-methods-request_entry_handle_async"></a>

### `request_entry_handle_async`

- API：`public`

```gdscript
func request_entry_handle_async( asset_utility: GFAssetUtility, entry_id: StringName, on_loaded: Callable, owner: Object = null, group_id: StringName = &"", type_hint_override: String = "" ) -> void:
```

通过 GFAssetUtility 异步加载条目资源并返回所有权句柄。

参数：

| 名称 | 说明 |
|---|---|
| `asset_utility` | 资源加载工具。 |
| `entry_id` | 条目稳定 ID。 |
| `on_loaded` | 加载完成回调，签名为 func(handle: GFAssetHandle)。 |
| `owner` | 可选拥有者。 |
| `group_id` | 可选资源分组。 |
| `type_hint_override` | 可选类型提示覆盖；为空时使用条目自己的 type_hint。 |

<a id="member-gfresourceregistry-methods-make_asset_group_entries"></a>

### `make_asset_group_entries`

- API：`public`

```gdscript
func make_asset_group_entries(entry_ids: PackedStringArray = PackedStringArray()) -> Array:
```

构建可传给 GFAssetUtility.preload_group_async() 的资源请求列表。

参数：

| 名称 | 说明 |
|---|---|
| `entry_ids` | 要导出的条目 ID；为空时导出全部有效条目。 |

返回：资源请求列表。

结构：

- `entry_ids`: PackedStringArray selected entry ids.
- `return`: Array[Dictionary] where each item contains path and type_hint.

<a id="member-gfresourceregistry-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：注册表诊断信息。

结构：

- `return`: Dictionary with entry_count, indexed_field_count, and ids.

<a id="member-gfresourceregistry-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

转换为可序列化字典。

返回：注册表字典。

结构：

- `return`: Dictionary with entries array.

<a id="member-gfresourceregistry-methods-apply_dict"></a>

### `apply_dict`

- API：`public`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

应用字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 注册表字典。 |

结构：

- `data`: Dictionary with entries array.

<a id="member-gfresourceregistry-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
static func from_dict(data: Dictionary) -> Resource:
```

从字典创建注册表。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 注册表字典。 |

返回：新注册表。

结构：

- `data`: Dictionary with entries array.
