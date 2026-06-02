# GFRegionMap3D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_region_map_3d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.18.0`

通用三维区域分块数据映射。 按固定三维区域尺寸管理格子数据，并追踪发生变化的区域，适合大世界格子缓存、局部保存或编辑器批处理。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`region_size`](#member-gfregionmap3d-properties-region_size) | `var region_size: Vector3i = Vector3i(32, 32, 32)` |
| 属性 | [`duplicate_values`](#member-gfregionmap3d-properties-duplicate_values) | `var duplicate_values: bool = true` |
| 方法 | [`get_region_key_for_cell`](#member-gfregionmap3d-methods-get_region_key_for_cell) | `func get_region_key_for_cell(cell: Vector3i) -> Vector3i:` |
| 方法 | [`get_region_keys_for_cell_bounds`](#member-gfregionmap3d-methods-get_region_keys_for_cell_bounds) | `func get_region_keys_for_cell_bounds(min_cell: Vector3i, max_cell: Vector3i) -> Array[Vector3i]:` |
| 方法 | [`set_cell`](#member-gfregionmap3d-methods-set_cell) | `func set_cell(cell: Vector3i, value: Variant) -> void:` |
| 方法 | [`get_cell`](#member-gfregionmap3d-methods-get_cell) | `func get_cell(cell: Vector3i, default_value: Variant = null) -> Variant:` |
| 方法 | [`erase_cell`](#member-gfregionmap3d-methods-erase_cell) | `func erase_cell(cell: Vector3i) -> bool:` |
| 方法 | [`has_cell`](#member-gfregionmap3d-methods-has_cell) | `func has_cell(cell: Vector3i) -> bool:` |
| 方法 | [`get_region_cells`](#member-gfregionmap3d-methods-get_region_cells) | `func get_region_cells(region_key: Vector3i) -> Array[Vector3i]:` |
| 方法 | [`get_region_snapshot`](#member-gfregionmap3d-methods-get_region_snapshot) | `func get_region_snapshot(region_key: Vector3i) -> Dictionary:` |
| 方法 | [`get_region_keys`](#member-gfregionmap3d-methods-get_region_keys) | `func get_region_keys() -> Array[Vector3i]:` |
| 方法 | [`get_dirty_region_keys`](#member-gfregionmap3d-methods-get_dirty_region_keys) | `func get_dirty_region_keys() -> Array[Vector3i]:` |
| 方法 | [`clear_dirty`](#member-gfregionmap3d-methods-clear_dirty) | `func clear_dirty(region_key: Variant = null) -> void:` |
| 方法 | [`clear`](#member-gfregionmap3d-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfregionmap3d-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfregionmap3d-properties-region_size"></a>

### `region_size`

- API：`public`

```gdscript
var region_size: Vector3i = Vector3i(32, 32, 32)
```

每个区域包含的格子尺寸。

<a id="member-gfregionmap3d-properties-duplicate_values"></a>

### `duplicate_values`

- API：`public`

```gdscript
var duplicate_values: bool = true
```

读写值时是否复制集合类型。

## 方法

<a id="member-gfregionmap3d-methods-get_region_key_for_cell"></a>

### `get_region_key_for_cell`

- API：`public`

```gdscript
func get_region_key_for_cell(cell: Vector3i) -> Vector3i:
```

根据格坐标获取区域键。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格坐标。 |

返回：区域键。

<a id="member-gfregionmap3d-methods-get_region_keys_for_cell_bounds"></a>

### `get_region_keys_for_cell_bounds`

- API：`public`

```gdscript
func get_region_keys_for_cell_bounds(min_cell: Vector3i, max_cell: Vector3i) -> Array[Vector3i]:
```

获取闭区间格子范围覆盖的全部区域键。

参数：

| 名称 | 说明 |
|---|---|
| `min_cell` | 范围起点格坐标。 |
| `max_cell` | 范围终点格坐标。 |

返回：区域键列表。

<a id="member-gfregionmap3d-methods-set_cell"></a>

### `set_cell`

- API：`public`

```gdscript
func set_cell(cell: Vector3i, value: Variant) -> void:
```

设置格子数据。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格坐标。 |
| `value` | 格子数据。 |

结构：

- `value`: Variant cell value stored in the region map.

<a id="member-gfregionmap3d-methods-get_cell"></a>

### `get_cell`

- API：`public`

```gdscript
func get_cell(cell: Vector3i, default_value: Variant = null) -> Variant:
```

获取格子数据。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格坐标。 |
| `default_value` | 缺失时返回的默认值。 |

返回：格子数据。

结构：

- `default_value`: Variant fallback value returned when the cell is missing.
- `return`: Variant cell value or default_value.

<a id="member-gfregionmap3d-methods-erase_cell"></a>

### `erase_cell`

- API：`public`

```gdscript
func erase_cell(cell: Vector3i) -> bool:
```

移除格子数据。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格坐标。 |

返回：移除成功返回 true。

<a id="member-gfregionmap3d-methods-has_cell"></a>

### `has_cell`

- API：`public`

```gdscript
func has_cell(cell: Vector3i) -> bool:
```

检查格子是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 格坐标。 |

返回：存在返回 true。

<a id="member-gfregionmap3d-methods-get_region_cells"></a>

### `get_region_cells`

- API：`public`

```gdscript
func get_region_cells(region_key: Vector3i) -> Array[Vector3i]:
```

获取区域内全部格子坐标。

参数：

| 名称 | 说明 |
|---|---|
| `region_key` | 区域键。 |

返回：格坐标列表。

<a id="member-gfregionmap3d-methods-get_region_snapshot"></a>

### `get_region_snapshot`

- API：`public`

```gdscript
func get_region_snapshot(region_key: Vector3i) -> Dictionary:
```

获取区域数据快照。

参数：

| 名称 | 说明 |
|---|---|
| `region_key` | 区域键。 |

返回：区域数据字典。

结构：

- `return`: Dictionary mapping Vector3i cells to stored cell values.

<a id="member-gfregionmap3d-methods-get_region_keys"></a>

### `get_region_keys`

- API：`public`

```gdscript
func get_region_keys() -> Array[Vector3i]:
```

获取已存在的区域键。

返回：区域键列表。

<a id="member-gfregionmap3d-methods-get_dirty_region_keys"></a>

### `get_dirty_region_keys`

- API：`public`

```gdscript
func get_dirty_region_keys() -> Array[Vector3i]:
```

获取脏区域键。

返回：脏区域键列表。

<a id="member-gfregionmap3d-methods-clear_dirty"></a>

### `clear_dirty`

- API：`public`

```gdscript
func clear_dirty(region_key: Variant = null) -> void:
```

清理脏区域标记。

参数：

| 名称 | 说明 |
|---|---|
| `region_key` | 指定区域；为 null 时清空全部。 |

结构：

- `region_key`: Variant null or Vector3i region key.

<a id="member-gfregionmap3d-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空全部区域数据。

<a id="member-gfregionmap3d-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照字典。

结构：

- `return`: Dictionary with region_size, region_count, cell_count, and dirty_region_count.
