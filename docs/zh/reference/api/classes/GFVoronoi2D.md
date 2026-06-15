# GFVoronoi2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_voronoi_2d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`5.0.0`

通用二维 Delaunay 三角剖分与 Voronoi 图计算工具。 输入为纯 Vector2 点集，输出结构化 Dictionary 数据。工具不生成 Mesh、Node、场景、 地形、材质或编辑器交互，项目层负责解释点和多边形的业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_EPSILON`](#member-gfvoronoi2d-constants-default_epsilon) | `const DEFAULT_EPSILON: float = 0.000001` |
| 常量 | [`DEFAULT_MAX_POINTS`](#member-gfvoronoi2d-constants-default_max_points) | `const DEFAULT_MAX_POINTS: int = 512` |
| 方法 | [`build_delaunay`](#member-gfvoronoi2d-methods-build_delaunay) | `static func build_delaunay(points: PackedVector2Array, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`build_voronoi`](#member-gfvoronoi2d-methods-build_voronoi) | `static func build_voronoi(points: PackedVector2Array, options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfvoronoi2d-constants-default_epsilon"></a>

### `DEFAULT_EPSILON`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const DEFAULT_EPSILON: float = 0.000001
```

默认浮点容差。

<a id="member-gfvoronoi2d-constants-default_max_points"></a>

### `DEFAULT_MAX_POINTS`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const DEFAULT_MAX_POINTS: int = 512
```

默认最大输入点数，用于避免误把实时大批量数据交给 O(n²) 纯 GDScript 计算。

## 方法

<a id="member-gfvoronoi2d-methods-build_delaunay"></a>

### `build_delaunay`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func build_delaunay(points: PackedVector2Array, options: Dictionary = {}) -> Dictionary:
```

基于点集生成 Delaunay 三角剖分。

参数：

| 名称 | 说明 |
|---|---|
| `points` | 输入点集。 |
| `options` | 可选参数，支持 epsilon 和 max_points。 |

返回：结构化三角剖分结果。

结构：

- `options`: Dictionary with optional epsilon: float and max_points: int.
- `return`: Dictionary with ok: bool, error: String, input_point_count: int, point_count: int, duplicate_count: int, points: PackedVector2Array, triangles: Array[PackedInt32Array], and edges: Array[PackedInt32Array].

<a id="member-gfvoronoi2d-methods-build_voronoi"></a>

### `build_voronoi`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func build_voronoi(points: PackedVector2Array, options: Dictionary = {}) -> Dictionary:
```

基于点集生成 Voronoi 图。

参数：

| 名称 | 说明 |
|---|---|
| `points` | 输入点集。 |
| `options` | 可选参数，支持 epsilon 和 max_points。 |

返回：结构化 Voronoi 结果。

结构：

- `options`: Dictionary with optional epsilon: float and max_points: int.
- `return`: Dictionary with Delaunay fields plus vertices: PackedVector2Array and cells: Array[Dictionary]. Each cell contains point_index: int, point: Vector2, vertex_indices: PackedInt32Array, polygon: PackedVector2Array, and is_open: bool.
