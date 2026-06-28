# GFSpatialHash3D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_spatial_hash_3d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

纯逻辑 3D 空间哈希。 适用于大量动态 3D 实体的粗粒度范围查询。它只维护 AABB 索引， 不负责物理碰撞、可见性或玩法规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MAX_COVERED_CELLS`](#member-gfspatialhash3d-constants-default_max_covered_cells) | `const DEFAULT_MAX_COVERED_CELLS: int = 262144` |
| 属性 | [`cell_size`](#member-gfspatialhash3d-properties-cell_size) | `var cell_size: float:` |
| 属性 | [`max_covered_cells`](#member-gfspatialhash3d-properties-max_covered_cells) | `var max_covered_cells: int:` |
| 方法 | [`configure`](#member-gfspatialhash3d-methods-configure) | `func configure(p_cell_size: float) -> void:` |
| 方法 | [`get_cell_for_position`](#member-gfspatialhash3d-methods-get_cell_for_position) | `func get_cell_for_position(position: Vector3) -> Vector3i:` |
| 方法 | [`insert`](#member-gfspatialhash3d-methods-insert) | `func insert(entity: Variant, bounds: AABB) -> bool:` |
| 方法 | [`remove`](#member-gfspatialhash3d-methods-remove) | `func remove(entity: Variant) -> void:` |
| 方法 | [`update`](#member-gfspatialhash3d-methods-update) | `func update(entity: Variant, bounds: AABB) -> bool:` |
| 方法 | [`has_entity`](#member-gfspatialhash3d-methods-has_entity) | `func has_entity(entity: Variant) -> bool:` |
| 方法 | [`get_entity_count`](#member-gfspatialhash3d-methods-get_entity_count) | `func get_entity_count() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfspatialhash3d-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`query_aabb`](#member-gfspatialhash3d-methods-query_aabb) | `func query_aabb(area: AABB) -> Array[Variant]:` |
| 方法 | [`query_radius`](#member-gfspatialhash3d-methods-query_radius) | `func query_radius(center: Vector3, radius: float) -> Array[Variant]:` |
| 方法 | [`query_cell`](#member-gfspatialhash3d-methods-query_cell) | `func query_cell(cell: Vector3i) -> Array[Variant]:` |
| 方法 | [`query_cell_range`](#member-gfspatialhash3d-methods-query_cell_range) | `func query_cell_range(center_cell: Vector3i, radius: Vector3i = Vector3i.ZERO) -> Array[Variant]:` |
| 方法 | [`prune_invalid_entities`](#member-gfspatialhash3d-methods-prune_invalid_entities) | `func prune_invalid_entities() -> void:` |
| 方法 | [`clear`](#member-gfspatialhash3d-methods-clear) | `func clear() -> void:` |

## 常量

<a id="member-gfspatialhash3d-constants-default_max_covered_cells"></a>

### `DEFAULT_MAX_COVERED_CELLS`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const DEFAULT_MAX_COVERED_CELLS: int = 262144
```

单次插入或查询允许覆盖的默认最大哈希格子数。

## 属性

<a id="member-gfspatialhash3d-properties-cell_size"></a>

### `cell_size`

- API：`public`

```gdscript
var cell_size: float:
```

单个哈希格子的世界尺寸。

<a id="member-gfspatialhash3d-properties-max_covered_cells"></a>

### `max_covered_cells`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_covered_cells: int:
```

单个 AABB 或格子范围允许覆盖的最大哈希格子数。 超过上限的插入会返回 false；超过上限的查询会返回空结果，避免误用超大范围导致 一帧内分配海量中间数组。

## 方法

<a id="member-gfspatialhash3d-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure(p_cell_size: float) -> void:
```

配置格子尺寸并清空索引。

参数：

| 名称 | 说明 |
|---|---|
| `p_cell_size` | 单格世界尺寸。 |

<a id="member-gfspatialhash3d-methods-get_cell_for_position"></a>

### `get_cell_for_position`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_cell_for_position(position: Vector3) -> Vector3i:
```

获取世界坐标所在的哈希格子。

参数：

| 名称 | 说明 |
|---|---|
| `position` | 世界坐标。 |

返回：哈希格子坐标。

<a id="member-gfspatialhash3d-methods-insert"></a>

### `insert`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func insert(entity: Variant, bounds: AABB) -> bool:
```

插入实体。

参数：

| 名称 | 说明 |
|---|---|
| `entity` | 实体标识或 Object。 |
| `bounds` | 实体 AABB。 |

返回：成功时返回 true。

结构：

- `entity`: Object, StringName, String, or int identity stored by value or weak Object reference.

<a id="member-gfspatialhash3d-methods-remove"></a>

### `remove`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func remove(entity: Variant) -> void:
```

移除实体。

参数：

| 名称 | 说明 |
|---|---|
| `entity` | 实体标识或 Object。 |

结构：

- `entity`: Object, StringName, String, or int identity stored by value or weak Object reference.

<a id="member-gfspatialhash3d-methods-update"></a>

### `update`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func update(entity: Variant, bounds: AABB) -> bool:
```

更新实体 AABB。

参数：

| 名称 | 说明 |
|---|---|
| `entity` | 实体标识或 Object。 |
| `bounds` | 新 AABB。 |

返回：成功时返回 true。

结构：

- `entity`: Object, StringName, String, or int identity stored by value or weak Object reference.

<a id="member-gfspatialhash3d-methods-has_entity"></a>

### `has_entity`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func has_entity(entity: Variant) -> bool:
```

检查实体是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `entity` | 实体标识或 Object。 |

返回：存在时返回 true。

结构：

- `entity`: Object, StringName, String, or int identity stored by value or weak Object reference.

<a id="member-gfspatialhash3d-methods-get_entity_count"></a>

### `get_entity_count`

- API：`public`

```gdscript
func get_entity_count() -> int:
```

获取实体数量。

返回：实体数量。

<a id="member-gfspatialhash3d-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取空间哈希调试快照。

返回：调试快照。

结构：

- `return`: Dictionary with cell_size, max_covered_cells, entity_count, bucket_count, max_bucket_size, and average_bucket_size.

<a id="member-gfspatialhash3d-methods-query_aabb"></a>

### `query_aabb`

- API：`public`

```gdscript
func query_aabb(area: AABB) -> Array[Variant]:
```

查询与 AABB 相交的实体。

参数：

| 名称 | 说明 |
|---|---|
| `area` | 查询 AABB。 |

返回：实体数组。

结构：

- `return`: Array entity values restored from spatial hash records.

<a id="member-gfspatialhash3d-methods-query_radius"></a>

### `query_radius`

- API：`public`

```gdscript
func query_radius(center: Vector3, radius: float) -> Array[Variant]:
```

查询与球体相交的实体。

参数：

| 名称 | 说明 |
|---|---|
| `center` | 球心。 |
| `radius` | 半径。 |

返回：实体数组。

结构：

- `return`: Array entity values restored from spatial hash records.

<a id="member-gfspatialhash3d-methods-query_cell"></a>

### `query_cell`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func query_cell(cell: Vector3i) -> Array[Variant]:
```

查询指定哈希格子中的候选实体。 返回值是该格子桶内的粗筛候选，调用方如需精确几何或玩法规则过滤，应继续使用自己的规则处理。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 哈希格子坐标。 |

返回：实体数组。

结构：

- `return`: Array entity values restored from spatial hash records.

<a id="member-gfspatialhash3d-methods-query_cell_range"></a>

### `query_cell_range`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func query_cell_range(center_cell: Vector3i, radius: Vector3i = Vector3i.ZERO) -> Array[Variant]:
```

查询以中心格子为基准的哈希格子范围。 `radius` 按轴表示要向外扩展的格子数；例如 `Vector3i(2, 0, 2)` 会查询同一 Y 层上 X/Z 各扩展 2 格的区域。

参数：

| 名称 | 说明 |
|---|---|
| `center_cell` | 中心哈希格子。 |
| `radius` | 各轴扩展格子数，负数会按绝对值处理。 |

返回：去重后的实体数组。

结构：

- `return`: Array entity values restored from spatial hash records.

<a id="member-gfspatialhash3d-methods-prune_invalid_entities"></a>

### `prune_invalid_entities`

- API：`public`

```gdscript
func prune_invalid_entities() -> void:
```

清理已释放 Object 实体。

<a id="member-gfspatialhash3d-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空索引。
