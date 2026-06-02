# GFTileMetadataLayer

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_tile_metadata_layer.gd`
- 模块：`Standard`
- 继承：`GFTileMapCache`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用格子元数据层。 在 Vector2i 格坐标上维护任意键值元数据，可服务于编辑器画刷、运行时标记、 规则查询或导出流程。它只管理数据结构，不绑定 TileSet、TileMapLayer 或项目业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`schema`](#member-gftilemetadatalayer-properties-schema) | `var schema: Dictionary = {}` |
| 方法 | [`set_cell_value`](#member-gftilemetadatalayer-methods-set_cell_value) | `func set_cell_value(cell: Vector2i, key: StringName, value: Variant) -> void:` |
| 方法 | [`get_cell_data`](#member-gftilemetadatalayer-methods-get_cell_data) | `func get_cell_data(cell: Vector2i) -> Dictionary:` |
| 方法 | [`get_cell_value`](#member-gftilemetadatalayer-methods-get_cell_value) | `func get_cell_value(cell: Vector2i, key: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`merge_cell_data`](#member-gftilemetadatalayer-methods-merge_cell_data) | `func merge_cell_data(cell: Vector2i, data: Dictionary, overwrite: bool = true) -> void:` |
| 方法 | [`erase_cell_key`](#member-gftilemetadatalayer-methods-erase_cell_key) | `func erase_cell_key(cell: Vector2i, key: StringName) -> bool:` |
| 方法 | [`has_cell_key`](#member-gftilemetadatalayer-methods-has_cell_key) | `func has_cell_key(cell: Vector2i, key: StringName) -> bool:` |
| 方法 | [`paint_cells`](#member-gftilemetadatalayer-methods-paint_cells) | `func paint_cells(target_cells: Array[Vector2i], key: StringName, value: Variant) -> int:` |
| 方法 | [`erase_cells_key`](#member-gftilemetadatalayer-methods-erase_cells_key) | `func erase_cells_key(target_cells: Array[Vector2i], key: StringName) -> int:` |
| 方法 | [`get_cells_with_value`](#member-gftilemetadatalayer-methods-get_cells_with_value) | `func get_cells_with_value(key: StringName, value: Variant) -> Array[Vector2i]:` |
| 方法 | [`set_schema_entry`](#member-gftilemetadatalayer-methods-set_schema_entry) | `func set_schema_entry(key: StringName, metadata: Dictionary) -> void:` |
| 方法 | [`get_schema_entry`](#member-gftilemetadatalayer-methods-get_schema_entry) | `func get_schema_entry(key: StringName) -> Dictionary:` |
| 方法 | [`erase_schema_entry`](#member-gftilemetadatalayer-methods-erase_schema_entry) | `func erase_schema_entry(key: StringName) -> void:` |
| 方法 | [`to_tile_map_cache`](#member-gftilemetadatalayer-methods-to_tile_map_cache) | `func to_tile_map_cache() -> GFTileMapCache:` |
| 方法 | [`from_tile_map_cache`](#member-gftilemetadatalayer-methods-from_tile_map_cache) | `func from_tile_map_cache(cache: GFTileMapCache, merge: bool = false) -> void:` |

## 属性

<a id="member-gftilemetadatalayer-properties-schema"></a>

### `schema`

- API：`public`

```gdscript
var schema: Dictionary = {}
```

可选字段 schema。框架不解释 schema 内容，项目可用于编辑器 UI、校验或导出。

结构：

- `schema`: Dictionary mapping metadata field names to project-defined field metadata.

## 方法

<a id="member-gftilemetadatalayer-methods-set_cell_value"></a>

### `set_cell_value`

- API：`public`

```gdscript
func set_cell_value(cell: Vector2i, key: StringName, value: Variant) -> void:
```

设置格子字段值。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格坐标。 |
| `key` | 字段名。 |
| `value` | 字段值。 |

结构：

- `value`: Variant metadata field value.

<a id="member-gftilemetadatalayer-methods-get_cell_data"></a>

### `get_cell_data`

- API：`public`

```gdscript
func get_cell_data(cell: Vector2i) -> Dictionary:
```

获取格子数据副本。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格坐标。 |

返回：格子数据。

结构：

- `return`: Dictionary metadata record stored on the cell.

<a id="member-gftilemetadatalayer-methods-get_cell_value"></a>

### `get_cell_value`

- API：`public`

```gdscript
func get_cell_value(cell: Vector2i, key: StringName, default_value: Variant = null) -> Variant:
```

获取格子字段值。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格坐标。 |
| `key` | 字段名。 |
| `default_value` | 默认值。 |

返回：字段值。

结构：

- `default_value`: Variant fallback value returned when the field is missing.
- `return`: Variant metadata field value or default_value.

<a id="member-gftilemetadatalayer-methods-merge_cell_data"></a>

### `merge_cell_data`

- API：`public`

```gdscript
func merge_cell_data(cell: Vector2i, data: Dictionary, overwrite: bool = true) -> void:
```

合并格子数据。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格坐标。 |
| `data` | 要合并的数据。 |
| `overwrite` | 为 false 时不覆盖已有字段。 |

结构：

- `data`: Dictionary metadata fields merged into the cell.

<a id="member-gftilemetadatalayer-methods-erase_cell_key"></a>

### `erase_cell_key`

- API：`public`

```gdscript
func erase_cell_key(cell: Vector2i, key: StringName) -> bool:
```

移除格子字段。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格坐标。 |
| `key` | 字段名。 |

返回：成功移除返回 true。

<a id="member-gftilemetadatalayer-methods-has_cell_key"></a>

### `has_cell_key`

- API：`public`

```gdscript
func has_cell_key(cell: Vector2i, key: StringName) -> bool:
```

检查格子字段是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格坐标。 |
| `key` | 字段名。 |

返回：存在时返回 true。

<a id="member-gftilemetadatalayer-methods-paint_cells"></a>

### `paint_cells`

- API：`public`

```gdscript
func paint_cells(target_cells: Array[Vector2i], key: StringName, value: Variant) -> int:
```

批量为格子绘制同一个字段值。

参数：

| 名称 | 说明 |
|---|---|
| `target_cells` | 目标格子。 |
| `key` | 字段名。 |
| `value` | 字段值。 |

返回：实际写入的格子数量。

结构：

- `value`: Variant metadata field value painted into target cells.

<a id="member-gftilemetadatalayer-methods-erase_cells_key"></a>

### `erase_cells_key`

- API：`public`

```gdscript
func erase_cells_key(target_cells: Array[Vector2i], key: StringName) -> int:
```

批量移除格子字段。

参数：

| 名称 | 说明 |
|---|---|
| `target_cells` | 目标格子。 |
| `key` | 字段名。 |

返回：实际移除的字段数量。

<a id="member-gftilemetadatalayer-methods-get_cells_with_value"></a>

### `get_cells_with_value`

- API：`public`

```gdscript
func get_cells_with_value(key: StringName, value: Variant) -> Array[Vector2i]:
```

查找拥有指定字段值的格子。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 字段名。 |
| `value` | 目标值。 |

返回：匹配格子列表。

结构：

- `value`: Variant metadata field value to match.

<a id="member-gftilemetadatalayer-methods-set_schema_entry"></a>

### `set_schema_entry`

- API：`public`

```gdscript
func set_schema_entry(key: StringName, metadata: Dictionary) -> void:
```

设置 schema 字段元数据。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 字段名。 |
| `metadata` | 字段元数据。 |

结构：

- `metadata`: Dictionary project-defined schema metadata for a field.

<a id="member-gftilemetadatalayer-methods-get_schema_entry"></a>

### `get_schema_entry`

- API：`public`

```gdscript
func get_schema_entry(key: StringName) -> Dictionary:
```

获取 schema 字段元数据。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 字段名。 |

返回：schema 元数据副本。

结构：

- `return`: Dictionary project-defined schema metadata for a field.

<a id="member-gftilemetadatalayer-methods-erase_schema_entry"></a>

### `erase_schema_entry`

- API：`public`

```gdscript
func erase_schema_entry(key: StringName) -> void:
```

移除 schema 字段元数据。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 字段名。 |

<a id="member-gftilemetadatalayer-methods-to_tile_map_cache"></a>

### `to_tile_map_cache`

- API：`public`

```gdscript
func to_tile_map_cache() -> GFTileMapCache:
```

转换为基础 TileMap 缓存。

返回：缓存副本。

<a id="member-gftilemetadatalayer-methods-from_tile_map_cache"></a>

### `from_tile_map_cache`

- API：`public`

```gdscript
func from_tile_map_cache(cache: GFTileMapCache, merge: bool = false) -> void:
```

从基础 TileMap 缓存复制数据。

参数：

| 名称 | 说明 |
|---|---|
| `cache` | 源缓存。 |
| `merge` | 为 true 时合并到现有数据，否则先清空。 |
