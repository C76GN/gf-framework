# GFCollisionNarrowphase2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_collision_narrowphase_2d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`5.0.0`

纯 2D 凸形状 SAT 精确重叠测试工具。 使用 Separating Axis Theorem 检测凸多边形和旋转盒是否重叠，并返回相切、 穿透深度、法线和最小平移向量。它只做 narrowphase 几何判定，不维护空间索引、 不生成 broadphase 候选对，不执行物理响应、接触点求解、命中分发或玩法规则判断。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`SHAPE_POLYGON`](#member-gfcollisionnarrowphase2d-constants-shape_polygon) | `const SHAPE_POLYGON: StringName = &"polygon"` |
| 常量 | [`REASON_OVERLAP`](#member-gfcollisionnarrowphase2d-constants-reason_overlap) | `const REASON_OVERLAP: StringName = &"overlap"` |
| 常量 | [`REASON_SEPARATED`](#member-gfcollisionnarrowphase2d-constants-reason_separated) | `const REASON_SEPARATED: StringName = &"separated"` |
| 常量 | [`REASON_TOUCHING`](#member-gfcollisionnarrowphase2d-constants-reason_touching) | `const REASON_TOUCHING: StringName = &"touching"` |
| 常量 | [`REASON_INVALID_SHAPE`](#member-gfcollisionnarrowphase2d-constants-reason_invalid_shape) | `const REASON_INVALID_SHAPE: StringName = &"invalid_shape"` |
| 常量 | [`DEFAULT_EPSILON`](#member-gfcollisionnarrowphase2d-constants-default_epsilon) | `const DEFAULT_EPSILON: float = 0.00001` |
| 方法 | [`make_polygon`](#member-gfcollisionnarrowphase2d-methods-make_polygon) | `static func make_polygon( points: PackedVector2Array, transform: Transform2D = Transform2D.IDENTITY, metadata: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`make_box`](#member-gfcollisionnarrowphase2d-methods-make_box) | `static func make_box( center: Vector2, size: Vector2, rotation_radians: float = 0.0, metadata: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`is_convex_polygon`](#member-gfcollisionnarrowphase2d-methods-is_convex_polygon) | `static func is_convex_polygon(points: PackedVector2Array, epsilon: float = DEFAULT_EPSILON) -> bool:` |
| 方法 | [`project_polygon`](#member-gfcollisionnarrowphase2d-methods-project_polygon) | `static func project_polygon(points: PackedVector2Array, axis: Vector2) -> Dictionary:` |
| 方法 | [`test_polygon_overlap`](#member-gfcollisionnarrowphase2d-methods-test_polygon_overlap) | `static func test_polygon_overlap( a_points: PackedVector2Array, b_points: PackedVector2Array, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`test_shapes_overlap`](#member-gfcollisionnarrowphase2d-methods-test_shapes_overlap) | `static func test_shapes_overlap( a_shape: Dictionary, b_shape: Dictionary, options: Dictionary = {} ) -> Dictionary:` |

## 常量

<a id="member-gfcollisionnarrowphase2d-constants-shape_polygon"></a>

### `SHAPE_POLYGON`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const SHAPE_POLYGON: StringName = &"polygon"
```

凸多边形 shape 类型。

<a id="member-gfcollisionnarrowphase2d-constants-reason_overlap"></a>

### `REASON_OVERLAP`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const REASON_OVERLAP: StringName = &"overlap"
```

几何重叠。

<a id="member-gfcollisionnarrowphase2d-constants-reason_separated"></a>

### `REASON_SEPARATED`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const REASON_SEPARATED: StringName = &"separated"
```

几何分离。

<a id="member-gfcollisionnarrowphase2d-constants-reason_touching"></a>

### `REASON_TOUCHING`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const REASON_TOUCHING: StringName = &"touching"
```

仅边界相切。

<a id="member-gfcollisionnarrowphase2d-constants-reason_invalid_shape"></a>

### `REASON_INVALID_SHAPE`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const REASON_INVALID_SHAPE: StringName = &"invalid_shape"
```

shape 无效或不是凸多边形。

<a id="member-gfcollisionnarrowphase2d-constants-default_epsilon"></a>

### `DEFAULT_EPSILON`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
const DEFAULT_EPSILON: float = 0.00001
```

默认浮点容差。

## 方法

<a id="member-gfcollisionnarrowphase2d-methods-make_polygon"></a>

### `make_polygon`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func make_polygon( points: PackedVector2Array, transform: Transform2D = Transform2D.IDENTITY, metadata: Dictionary = {} ) -> Dictionary:
```

创建凸多边形 shape 记录。

参数：

| 名称 | 说明 |
|---|---|
| `points` | 多边形顶点，按顺时针或逆时针顺序排列。 |
| `transform` | 写入 shape 前应用到每个顶点的变换。 |
| `metadata` | 调用方附加元数据；SAT 不解释这些字段。 |

返回：shape 字典。

结构：

- `return`: Dictionary with `type: StringName`, `points: PackedVector2Array`, and `metadata: Dictionary`.
- `metadata`: Dictionary caller metadata copied by value.

<a id="member-gfcollisionnarrowphase2d-methods-make_box"></a>

### `make_box`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func make_box( center: Vector2, size: Vector2, rotation_radians: float = 0.0, metadata: Dictionary = {} ) -> Dictionary:
```

创建旋转盒 shape 记录。

参数：

| 名称 | 说明 |
|---|---|
| `center` | 盒中心点。 |
| `size` | 盒尺寸；负尺寸会按绝对值处理。 |
| `rotation_radians` | 盒的旋转角度，单位为弧度。 |
| `metadata` | 调用方附加元数据；SAT 不解释这些字段。 |

返回：shape 字典。

结构：

- `return`: Dictionary with `type: StringName`, `points: PackedVector2Array`, and `metadata: Dictionary`.
- `metadata`: Dictionary caller metadata copied by value.

<a id="member-gfcollisionnarrowphase2d-methods-is_convex_polygon"></a>

### `is_convex_polygon`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func is_convex_polygon(points: PackedVector2Array, epsilon: float = DEFAULT_EPSILON) -> bool:
```

检查点序列是否构成凸多边形。

参数：

| 名称 | 说明 |
|---|---|
| `points` | 多边形顶点，按顺时针或逆时针顺序排列。 |
| `epsilon` | 浮点容差。 |

返回：顶点数量充足、面积非零且没有凹角时返回 true。

<a id="member-gfcollisionnarrowphase2d-methods-project_polygon"></a>

### `project_polygon`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func project_polygon(points: PackedVector2Array, axis: Vector2) -> Dictionary:
```

把凸多边形投影到轴上。

参数：

| 名称 | 说明 |
|---|---|
| `points` | 多边形顶点。 |
| `axis` | 投影轴；会先归一化。 |

返回：投影区间。

结构：

- `return`: Dictionary with `valid: bool`, `min: float`, `max: float`, and `axis: Vector2`.

<a id="member-gfcollisionnarrowphase2d-methods-test_polygon_overlap"></a>

### `test_polygon_overlap`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func test_polygon_overlap( a_points: PackedVector2Array, b_points: PackedVector2Array, options: Dictionary = {} ) -> Dictionary:
```

使用 SAT 检查两个凸多边形是否重叠。

参数：

| 名称 | 说明 |
|---|---|
| `a_points` | 第一个凸多边形顶点。 |
| `b_points` | 第二个凸多边形顶点。 |
| `options` | 可选控制，支持 `include_touching` 与 `epsilon`。 |

返回：SAT 重叠报告。

结构：

- `options`: Dictionary with optional `include_touching: bool` and `epsilon: float`.
- `return`: Dictionary with `overlap: bool`, `touching: bool`, `reason: StringName`, `penetration_depth: float`, `normal: Vector2`, `minimum_translation: Vector2`, and `axis_count: int`.

<a id="member-gfcollisionnarrowphase2d-methods-test_shapes_overlap"></a>

### `test_shapes_overlap`

- API：`public`
- 首次版本：`5.0.0`

```gdscript
static func test_shapes_overlap( a_shape: Dictionary, b_shape: Dictionary, options: Dictionary = {} ) -> Dictionary:
```

使用 SAT 检查两个 shape 是否重叠。

参数：

| 名称 | 说明 |
|---|---|
| `a_shape` | 第一个 shape，建议由 `make_polygon()` 或 `make_box()` 创建。 |
| `b_shape` | 第二个 shape，建议由 `make_polygon()` 或 `make_box()` 创建。 |
| `options` | 可选控制，支持 `include_touching` 与 `epsilon`。 |

返回：SAT 重叠报告。

结构：

- `a_shape`: Dictionary with `type: StringName` and `points: PackedVector2Array`.
- `b_shape`: Dictionary with `type: StringName` and `points: PackedVector2Array`.
- `options`: Dictionary with optional `include_touching: bool` and `epsilon: float`.
- `return`: Dictionary with `overlap: bool`, `touching: bool`, `reason: StringName`, `penetration_depth: float`, `normal: Vector2`, `minimum_translation: Vector2`, and `axis_count: int`.
