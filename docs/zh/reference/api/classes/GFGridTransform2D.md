# GFGridTransform2D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_grid_transform_2d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.21.0`

2D 矩形网格坐标变换工具。 提供旋转、镜像和对角翻转的纯坐标映射，可用于格子模板、画刷、 房间蓝图、棋盘片段或编辑器工具。它只处理 Vector2i / Vector2 坐标， 不绑定 TileMapLayer、TileSet、渲染、碰撞或项目业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Transform`](#member-gfgridtransform2d-enums-transform) | `enum Transform` |
| 常量 | [`INVALID_TRANSFORM`](#member-gfgridtransform2d-constants-invalid_transform) | `const INVALID_TRANSFORM: int = -1` |
| 方法 | [`is_transform_valid`](#member-gfgridtransform2d-methods-is_transform_valid) | `static func is_transform_valid(transform: int) -> bool:` |
| 方法 | [`is_axis_swapped`](#member-gfgridtransform2d-methods-is_axis_swapped) | `static func is_axis_swapped(transform: int) -> bool:` |
| 方法 | [`get_transformed_size`](#member-gfgridtransform2d-methods-get_transformed_size) | `static func get_transformed_size(size: Vector2i, transform: int) -> Vector2i:` |
| 方法 | [`get_inverse_transform`](#member-gfgridtransform2d-methods-get_inverse_transform) | `static func get_inverse_transform(transform: int) -> int:` |
| 方法 | [`transform_local_cell`](#member-gfgridtransform2d-methods-transform_local_cell) | `static func transform_local_cell(cell: Vector2i, source_size: Vector2i, transform: int) -> Vector2i:` |
| 方法 | [`transform_cell`](#member-gfgridtransform2d-methods-transform_cell) | `static func transform_cell( cell: Vector2i, source_rect: Rect2i, transform: int, target_origin: Vector2i = Vector2i.ZERO ) -> Vector2i:` |
| 方法 | [`transform_cells`](#member-gfgridtransform2d-methods-transform_cells) | `static func transform_cells( cells: Array[Vector2i], source_rect: Rect2i, transform: int, target_origin: Vector2i = Vector2i.ZERO ) -> Array[Vector2i]:` |
| 方法 | [`transform_cardinal_direction`](#member-gfgridtransform2d-methods-transform_cardinal_direction) | `static func transform_cardinal_direction(direction: Vector2i, transform: int) -> Vector2i:` |
| 方法 | [`transform_local_point`](#member-gfgridtransform2d-methods-transform_local_point) | `static func transform_local_point(point: Vector2, source_size: Vector2, transform: int) -> Vector2:` |
| 方法 | [`transform_point`](#member-gfgridtransform2d-methods-transform_point) | `static func transform_point( point: Vector2, source_rect: Rect2, transform: int, target_origin: Vector2 = Vector2.ZERO ) -> Vector2:` |

## 枚举

<a id="member-gfgridtransform2d-enums-transform"></a>

### `Transform`

- API：`public`

```gdscript
enum Transform {
	## 不变换。
	IDENTITY,
	## 顺时针旋转 90 度。
	ROTATE_90,
	## 旋转 180 度。
	ROTATE_180,
	## 顺时针旋转 270 度。
	ROTATE_270,
	## 沿 X 轴方向镜像，即左右翻转。
	MIRROR_X,
	## 沿 Y 轴方向镜像，即上下翻转。
	MIRROR_Y,
	## 沿左上到右下对角线翻转。
	DIAGONAL_MAIN,
	## 沿右上到左下对角线翻转。
	DIAGONAL_ANTI,
}
```

2D 矩形局部空间中的离散变换。

## 常量

<a id="member-gfgridtransform2d-constants-invalid_transform"></a>

### `INVALID_TRANSFORM`

- API：`public`

```gdscript
const INVALID_TRANSFORM: int = -1
```

无效变换哨兵值。

## 方法

<a id="member-gfgridtransform2d-methods-is_transform_valid"></a>

### `is_transform_valid`

- API：`public`

```gdscript
static func is_transform_valid(transform: int) -> bool:
```

判断变换编号是否有效。

参数：

| 名称 | 说明 |
|---|---|
| `transform` | Transform 枚举值。 |

返回：有效时返回 true。

<a id="member-gfgridtransform2d-methods-is_axis_swapped"></a>

### `is_axis_swapped`

- API：`public`

```gdscript
static func is_axis_swapped(transform: int) -> bool:
```

判断变换后宽高轴是否互换。

参数：

| 名称 | 说明 |
|---|---|
| `transform` | Transform 枚举值。 |

返回：旋转 90/270 或对角翻转时返回 true。

<a id="member-gfgridtransform2d-methods-get_transformed_size"></a>

### `get_transformed_size`

- API：`public`

```gdscript
static func get_transformed_size(size: Vector2i, transform: int) -> Vector2i:
```

获取变换后的矩形尺寸。

参数：

| 名称 | 说明 |
|---|---|
| `size` | 原始矩形尺寸。 |
| `transform` | Transform 枚举值。 |

返回：变换后的尺寸；无效尺寸时返回 Vector2i.ZERO。

<a id="member-gfgridtransform2d-methods-get_inverse_transform"></a>

### `get_inverse_transform`

- API：`public`

```gdscript
static func get_inverse_transform(transform: int) -> int:
```

获取逆变换。

参数：

| 名称 | 说明 |
|---|---|
| `transform` | Transform 枚举值。 |

返回：对应逆变换；无效输入返回 INVALID_TRANSFORM。

<a id="member-gfgridtransform2d-methods-transform_local_cell"></a>

### `transform_local_cell`

- API：`public`

```gdscript
static func transform_local_cell(cell: Vector2i, source_size: Vector2i, transform: int) -> Vector2i:
```

变换局部格坐标。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 原始局部格坐标，通常位于 \`[0, size)\`。 |
| `source_size` | 原始矩形尺寸。 |
| `transform` | Transform 枚举值。 |

返回：变换后的局部格坐标。

<a id="member-gfgridtransform2d-methods-transform_cell"></a>

### `transform_cell`

- API：`public`

```gdscript
static func transform_cell( cell: Vector2i, source_rect: Rect2i, transform: int, target_origin: Vector2i = Vector2i.ZERO ) -> Vector2i:
```

变换矩形内的全局格坐标。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 原始格坐标。 |
| `source_rect` | 原始矩形范围。 |
| `transform` | Transform 枚举值。 |
| `target_origin` | 变换后矩形的目标起点。 |

返回：变换后的格坐标。

<a id="member-gfgridtransform2d-methods-transform_cells"></a>

### `transform_cells`

- API：`public`

```gdscript
static func transform_cells( cells: Array[Vector2i], source_rect: Rect2i, transform: int, target_origin: Vector2i = Vector2i.ZERO ) -> Array[Vector2i]:
```

批量变换矩形内的全局格坐标。

参数：

| 名称 | 说明 |
|---|---|
| `cells` | 原始格坐标列表。 |
| `source_rect` | 原始矩形范围。 |
| `transform` | Transform 枚举值。 |
| `target_origin` | 变换后矩形的目标起点。 |

返回：变换后的格坐标列表，顺序与输入一致。

<a id="member-gfgridtransform2d-methods-transform_cardinal_direction"></a>

### `transform_cardinal_direction`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func transform_cardinal_direction(direction: Vector2i, transform: int) -> Vector2i:
```

变换四向单位方向。 该方法只接受 `Vector2i.RIGHT`、`LEFT`、`DOWN`、`UP`。无效方向或无效变换返回 `Vector2i.ZERO`，便于调用方把它作为非方向哨兵处理。

参数：

| 名称 | 说明 |
|---|---|
| `direction` | 原始四向单位方向。 |
| `transform` | Transform 枚举值。 |

返回：变换后的四向单位方向；无效输入返回 Vector2i.ZERO。

<a id="member-gfgridtransform2d-methods-transform_local_point"></a>

### `transform_local_point`

- API：`public`

```gdscript
static func transform_local_point(point: Vector2, source_size: Vector2, transform: int) -> Vector2:
```

变换局部连续坐标。

参数：

| 名称 | 说明 |
|---|---|
| `point` | 原始局部坐标，通常位于 \`[0, size]\`。 |
| `source_size` | 原始矩形尺寸。 |
| `transform` | Transform 枚举值。 |

返回：变换后的局部坐标。

<a id="member-gfgridtransform2d-methods-transform_point"></a>

### `transform_point`

- API：`public`

```gdscript
static func transform_point( point: Vector2, source_rect: Rect2, transform: int, target_origin: Vector2 = Vector2.ZERO ) -> Vector2:
```

变换矩形内的全局连续坐标。

参数：

| 名称 | 说明 |
|---|---|
| `point` | 原始坐标。 |
| `source_rect` | 原始矩形范围。 |
| `transform` | Transform 枚举值。 |
| `target_origin` | 变换后矩形的目标起点。 |

返回：变换后的坐标。
