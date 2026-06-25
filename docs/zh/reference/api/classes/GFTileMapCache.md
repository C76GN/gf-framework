# GFTileMapCache

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_tile_map_cache.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用格子数据快照与差分缓存。 用 Vector2i 管理格子字典数据，既可手动写入，也可从 TileMapLayer 采集基础 source/atlas/alternative/terrain 信息。它不规定字段语义，项目可扩展记录内容。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`cells`](#member-gftilemapcache-properties-cells) | `var cells: Dictionary = {}` |
| 方法 | [`update_from_tile_map`](#member-gftilemapcache-methods-update_from_tile_map) | `func update_from_tile_map(layer: TileMapLayer, target_cells: Array[Vector2i] = []) -> void:` |
| 方法 | [`apply_to_tile_map`](#member-gftilemapcache-methods-apply_to_tile_map) | `func apply_to_tile_map( layer: TileMapLayer, origin: Vector2i = Vector2i.ZERO, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`extract_region`](#member-gftilemapcache-methods-extract_region) | `func extract_region(region: Rect2i, normalize_origin: bool = true) -> GFTileMapCache:` |
| 方法 | [`translated`](#member-gftilemapcache-methods-translated) | `func translated(offset: Vector2i) -> GFTileMapCache:` |
| 方法 | [`get_used_rect`](#member-gftilemapcache-methods-get_used_rect) | `func get_used_rect() -> Rect2i:` |
| 方法 | [`set_cell_data`](#member-gftilemapcache-methods-set_cell_data) | `func set_cell_data(cell: Vector2i, data: Dictionary) -> void:` |
| 方法 | [`erase_cell`](#member-gftilemapcache-methods-erase_cell) | `func erase_cell(cell: Vector2i) -> void:` |
| 方法 | [`has_cell`](#member-gftilemapcache-methods-has_cell) | `func has_cell(cell: Vector2i) -> bool:` |
| 方法 | [`get_cell_data`](#member-gftilemapcache-methods-get_cell_data) | `func get_cell_data(cell: Vector2i) -> Dictionary:` |
| 方法 | [`get_value`](#member-gftilemapcache-methods-get_value) | `func get_value(cell: Vector2i, key: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`clear`](#member-gftilemapcache-methods-clear) | `func clear() -> void:` |
| 方法 | [`diff_cells`](#member-gftilemapcache-methods-diff_cells) | `func diff_cells(other: GFTileMapCache, compare_key: StringName = &"") -> Array[Vector2i]:` |
| 方法 | [`to_dict`](#member-gftilemapcache-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`from_dict`](#member-gftilemapcache-methods-from_dict) | `func from_dict(data: Dictionary) -> void:` |

## 属性

<a id="member-gftilemapcache-properties-cells"></a>

### `cells`

- API：`public`

```gdscript
var cells: Dictionary = {}
```

格子数据，结构为 Vector2i -> Dictionary。

结构：

- `cells`: Dictionary mapping Vector2i cells to Dictionary cell records.

## 方法

<a id="member-gftilemapcache-methods-update_from_tile_map"></a>

### `update_from_tile_map`

- API：`public`

```gdscript
func update_from_tile_map(layer: TileMapLayer, target_cells: Array[Vector2i] = []) -> void:
```

从 TileMapLayer 更新缓存。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 目标 TileMapLayer。 |
| `target_cells` | 要更新的格子；为空时采集 layer.get_used_cells()。 |

<a id="member-gftilemapcache-methods-apply_to_tile_map"></a>

### `apply_to_tile_map`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func apply_to_tile_map( layer: TileMapLayer, origin: Vector2i = Vector2i.ZERO, options: Dictionary = {} ) -> Dictionary:
```

将缓存写回 TileMapLayer。

参数：

| 名称 | 说明 |
|---|---|
| `layer` | 目标 TileMapLayer。 |
| `origin` | 写回偏移，缓存坐标会加上该偏移。 |
| `options` | 可选参数，支持 overwrite、erase_empty。 |

返回：写回报告。

结构：

- `options`: Dictionary with optional `overwrite: bool` and `erase_empty: bool`.
- `return`: Dictionary with ok, applied_count, skipped_count, erased_count, failed_count, applied_cells, skipped_cells, erased_cells, failed_cells, and error.

<a id="member-gftilemapcache-methods-extract_region"></a>

### `extract_region`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func extract_region(region: Rect2i, normalize_origin: bool = true) -> GFTileMapCache:
```

提取区域片段。

参数：

| 名称 | 说明 |
|---|---|
| `region` | 要提取的区域。 |
| `normalize_origin` | 为 true 时把区域左上角归一到 Vector2i.ZERO。 |

返回：新缓存。

<a id="member-gftilemapcache-methods-translated"></a>

### `translated`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func translated(offset: Vector2i) -> GFTileMapCache:
```

创建坐标平移后的缓存副本。

参数：

| 名称 | 说明 |
|---|---|
| `offset` | 坐标偏移。 |

返回：新缓存。

<a id="member-gftilemapcache-methods-get_used_rect"></a>

### `get_used_rect`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_used_rect() -> Rect2i:
```

获取缓存覆盖区域。

返回：覆盖区域；缓存为空时返回空 Rect2i。

<a id="member-gftilemapcache-methods-set_cell_data"></a>

### `set_cell_data`

- API：`public`

```gdscript
func set_cell_data(cell: Vector2i, data: Dictionary) -> void:
```

设置一个格子的字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格坐标。 |
| `data` | 格子数据。 |

结构：

- `data`: Dictionary cell record copied into the cache.

<a id="member-gftilemapcache-methods-erase_cell"></a>

### `erase_cell`

- API：`public`

```gdscript
func erase_cell(cell: Vector2i) -> void:
```

移除一个格子。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格坐标。 |

<a id="member-gftilemapcache-methods-has_cell"></a>

### `has_cell`

- API：`public`

```gdscript
func has_cell(cell: Vector2i) -> bool:
```

检查格子是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格坐标。 |

返回：存在时返回 true。

<a id="member-gftilemapcache-methods-get_cell_data"></a>

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

- `return`: Dictionary cell record copy.

<a id="member-gftilemapcache-methods-get_value"></a>

### `get_value`

- API：`public`

```gdscript
func get_value(cell: Vector2i, key: StringName, default_value: Variant = null) -> Variant:
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
- `return`: Variant field value or default_value.

<a id="member-gftilemapcache-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空缓存。

<a id="member-gftilemapcache-methods-diff_cells"></a>

### `diff_cells`

- API：`public`

```gdscript
func diff_cells(other: GFTileMapCache, compare_key: StringName = &"") -> Array[Vector2i]:
```

和另一个缓存做差分。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个缓存。 |
| `compare_key` | 为空时比较完整字典；否则只比较指定字段。 |

返回：发生变化的格子列表。

<a id="member-gftilemapcache-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

序列化为字典。

返回：可保存的字典。

结构：

- `return`: Dictionary mapping string cell keys to Dictionary cell records.

<a id="member-gftilemapcache-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
func from_dict(data: Dictionary) -> void:
```

从字典恢复。

参数：

| 名称 | 说明 |
|---|---|
| `data` | to_dict() 生成的数据。 |

结构：

- `data`: Dictionary mapping string cell keys to Dictionary cell records.
