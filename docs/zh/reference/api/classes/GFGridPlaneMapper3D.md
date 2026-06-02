# GFGridPlaneMapper3D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_grid_plane_mapper_3d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.18.0`

3D 轴对齐平面与 2D 邻域坐标映射工具。 将 axis-aligned 3D 表面上的格坐标映射为局部 2D 坐标，并可按 2D offset 采样邻域值。它只处理坐标和回调取值，不绑定 TileSet、GridMap、碰撞或玩法语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_CARDINAL_OFFSETS`](#member-gfgridplanemapper3d-constants-default_cardinal_offsets) | `const DEFAULT_CARDINAL_OFFSETS: Array[Vector2i] = [` |
| 方法 | [`is_axis_aligned_normal`](#member-gfgridplanemapper3d-methods-is_axis_aligned_normal) | `static func is_axis_aligned_normal(normal: Vector3i) -> bool:` |
| 方法 | [`normalize_axis_normal`](#member-gfgridplanemapper3d-methods-normalize_axis_normal) | `static func normalize_axis_normal(normal: Vector3i) -> Vector3i:` |
| 方法 | [`get_plane_basis`](#member-gfgridplanemapper3d-methods-get_plane_basis) | `static func get_plane_basis(normal: Vector3i) -> Dictionary:` |
| 方法 | [`map_cell_to_plane`](#member-gfgridplanemapper3d-methods-map_cell_to_plane) | `static func map_cell_to_plane(cell: Vector3i, origin: Vector3i, normal: Vector3i) -> Vector2i:` |
| 方法 | [`map_plane_to_cell`](#member-gfgridplanemapper3d-methods-map_plane_to_cell) | `static func map_plane_to_cell( plane_cell: Vector2i, origin: Vector3i, normal: Vector3i, depth: int = 0 ) -> Vector3i:` |
| 方法 | [`get_cell_depth`](#member-gfgridplanemapper3d-methods-get_cell_depth) | `static func get_cell_depth(cell: Vector3i, origin: Vector3i, normal: Vector3i) -> int:` |
| 方法 | [`get_neighbor_cells`](#member-gfgridplanemapper3d-methods-get_neighbor_cells) | `static func get_neighbor_cells(center: Vector3i, normal: Vector3i, offsets: Array[Vector2i] = []) -> Array[Vector3i]:` |
| 方法 | [`sample_neighbor_values`](#member-gfgridplanemapper3d-methods-sample_neighbor_values) | `static func sample_neighbor_values( center: Vector3i, normal: Vector3i, value_getter: Callable, offsets: Array[Vector2i] = [], fallback_value: Variant = null ) -> Array:` |

## 常量

<a id="member-gfgridplanemapper3d-constants-default_cardinal_offsets"></a>

### `DEFAULT_CARDINAL_OFFSETS`

- API：`public`

```gdscript
const DEFAULT_CARDINAL_OFFSETS: Array[Vector2i] = [
```

默认四邻域 offset 顺序：上、右、下、左。

## 方法

<a id="member-gfgridplanemapper3d-methods-is_axis_aligned_normal"></a>

### `is_axis_aligned_normal`

- API：`public`

```gdscript
static func is_axis_aligned_normal(normal: Vector3i) -> bool:
```

判断 normal 是否能表示单轴方向。

参数：

| 名称 | 说明 |
|---|---|
| `normal` | 3D 平面法线。 |

返回：normal 只有一个非零轴时返回 true。

<a id="member-gfgridplanemapper3d-methods-normalize_axis_normal"></a>

### `normalize_axis_normal`

- API：`public`

```gdscript
static func normalize_axis_normal(normal: Vector3i) -> Vector3i:
```

将单轴 normal 归一化为 -1/1 法线。

参数：

| 名称 | 说明 |
|---|---|
| `normal` | 3D 平面法线。 |

返回：归一化法线；无效 normal 返回 Vector3i.ZERO。

<a id="member-gfgridplanemapper3d-methods-get_plane_basis"></a>

### `get_plane_basis`

- API：`public`

```gdscript
static func get_plane_basis(normal: Vector3i) -> Dictionary:
```

获取轴对齐平面的局部基向量。

参数：

| 名称 | 说明 |
|---|---|
| `normal` | 3D 平面法线。 |

返回：Dictionary，包含 valid、normal、u、v。

结构：

- `return`: Dictionary with valid: bool, normal: Vector3i, u: Vector3i, and v: Vector3i.

<a id="member-gfgridplanemapper3d-methods-map_cell_to_plane"></a>

### `map_cell_to_plane`

- API：`public`

```gdscript
static func map_cell_to_plane(cell: Vector3i, origin: Vector3i, normal: Vector3i) -> Vector2i:
```

将 3D 格坐标映射为平面局部 2D 坐标。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 3D 格坐标。 |
| `origin` | 平面局部原点。 |
| `normal` | 3D 平面法线。 |

返回：局部 2D 坐标；normal 无效时返回 Vector2i.ZERO。

<a id="member-gfgridplanemapper3d-methods-map_plane_to_cell"></a>

### `map_plane_to_cell`

- API：`public`

```gdscript
static func map_plane_to_cell( plane_cell: Vector2i, origin: Vector3i, normal: Vector3i, depth: int = 0 ) -> Vector3i:
```

将平面局部 2D 坐标映射为 3D 格坐标。

参数：

| 名称 | 说明 |
|---|---|
| `plane_cell` | 局部 2D 坐标。 |
| `origin` | 平面局部原点。 |
| `normal` | 3D 平面法线。 |
| `depth` | 沿 normal 的偏移层数。 |

返回：3D 格坐标；normal 无效时返回 origin。

<a id="member-gfgridplanemapper3d-methods-get_cell_depth"></a>

### `get_cell_depth`

- API：`public`

```gdscript
static func get_cell_depth(cell: Vector3i, origin: Vector3i, normal: Vector3i) -> int:
```

获取格坐标相对平面的深度。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 3D 格坐标。 |
| `origin` | 平面局部原点。 |
| `normal` | 3D 平面法线。 |

返回：沿 normal 的偏移层数；normal 无效时返回 0。

<a id="member-gfgridplanemapper3d-methods-get_neighbor_cells"></a>

### `get_neighbor_cells`

- API：`public`

```gdscript
static func get_neighbor_cells(center: Vector3i, normal: Vector3i, offsets: Array[Vector2i] = []) -> Array[Vector3i]:
```

按 2D offset 获取同一平面上的 3D 邻居格。

参数：

| 名称 | 说明 |
|---|---|
| `center` | 中心 3D 格坐标。 |
| `normal` | 3D 平面法线。 |
| `offsets` | 局部 2D offset；为空时使用 DEFAULT_CARDINAL_OFFSETS。 |

返回：3D 邻居格列表。

<a id="member-gfgridplanemapper3d-methods-sample_neighbor_values"></a>

### `sample_neighbor_values`

- API：`public`

```gdscript
static func sample_neighbor_values( center: Vector3i, normal: Vector3i, value_getter: Callable, offsets: Array[Vector2i] = [], fallback_value: Variant = null ) -> Array:
```

按 2D offset 采样同一平面上的 3D 邻域值。

参数：

| 名称 | 说明 |
|---|---|
| `center` | 中心 3D 格坐标。 |
| `normal` | 3D 平面法线。 |
| `value_getter` | 取值回调，签名为 func(cell: Vector3i) -> Variant。 |
| `offsets` | 局部 2D offset；为空时使用 DEFAULT_CARDINAL_OFFSETS。 |
| `fallback_value` | 回调无效时填充的值。 |

返回：邻域值列表。

结构：

- `fallback_value`: Variant used for each neighbor when value_getter is invalid.
- `return`: Array ordered neighbor values sampled from mapped 3D cells.
