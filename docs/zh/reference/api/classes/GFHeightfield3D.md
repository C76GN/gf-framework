# GFHeightfield3D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_heightfield_3d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

通用 X/Z 平面高度场采样数据。 保存一组行优先高度样本，并提供世界坐标到网格坐标转换、双线性高度采样、 法线估算和诊断快照。它只处理纯数据，不创建地形节点、碰撞体、材质或渲染资源。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`from_samples`](#member-gfheightfield3d-methods-from_samples) | `static func from_samples( grid_size: Vector2i, height_samples: PackedFloat32Array, world_min: Vector2 = Vector2.ZERO, world_max: Vector2 = Vector2.ONE ) -> GFHeightfield3D:` |
| 方法 | [`from_terrain_rgb_image`](#member-gfheightfield3d-methods-from_terrain_rgb_image) | `static func from_terrain_rgb_image( image: Image, world_min: Vector2 = Vector2.ZERO, world_max: Vector2 = Vector2.ONE, options: Dictionary = {} ) -> GFHeightfield3D:` |
| 方法 | [`decode_terrain_rgb_height`](#member-gfheightfield3d-methods-decode_terrain_rgb_height) | `static func decode_terrain_rgb_height(color: Color) -> float:` |
| 方法 | [`normal_to_slope`](#member-gfheightfield3d-methods-normal_to_slope) | `static func normal_to_slope(normal: Vector3) -> float:` |
| 方法 | [`samples_from_terrain_rgb_image`](#member-gfheightfield3d-methods-samples_from_terrain_rgb_image) | `static func samples_from_terrain_rgb_image(image: Image, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`configure`](#member-gfheightfield3d-methods-configure) | `func configure( grid_size: Vector2i, height_samples: PackedFloat32Array, world_min: Vector2 = Vector2.ZERO, world_max: Vector2 = Vector2.ONE ) -> bool:` |
| 方法 | [`configure_from_terrain_rgb_image`](#member-gfheightfield3d-methods-configure_from_terrain_rgb_image) | `func configure_from_terrain_rgb_image( image: Image, world_min: Vector2 = Vector2.ZERO, world_max: Vector2 = Vector2.ONE, options: Dictionary = {} ) -> bool:` |
| 方法 | [`clear`](#member-gfheightfield3d-methods-clear) | `func clear() -> void:` |
| 方法 | [`is_valid`](#member-gfheightfield3d-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`get_grid_size`](#member-gfheightfield3d-methods-get_grid_size) | `func get_grid_size() -> Vector2i:` |
| 方法 | [`get_world_min`](#member-gfheightfield3d-methods-get_world_min) | `func get_world_min() -> Vector2:` |
| 方法 | [`get_world_max`](#member-gfheightfield3d-methods-get_world_max) | `func get_world_max() -> Vector2:` |
| 方法 | [`get_world_rect`](#member-gfheightfield3d-methods-get_world_rect) | `func get_world_rect() -> Rect2:` |
| 方法 | [`get_height_samples`](#member-gfheightfield3d-methods-get_height_samples) | `func get_height_samples() -> PackedFloat32Array:` |
| 方法 | [`get_sample_count`](#member-gfheightfield3d-methods-get_sample_count) | `func get_sample_count() -> int:` |
| 方法 | [`contains_world_xz`](#member-gfheightfield3d-methods-contains_world_xz) | `func contains_world_xz(world_x: float, world_z: float) -> bool:` |
| 方法 | [`contains_world_position`](#member-gfheightfield3d-methods-contains_world_position) | `func contains_world_position(position: Vector3) -> bool:` |
| 方法 | [`world_to_grid`](#member-gfheightfield3d-methods-world_to_grid) | `func world_to_grid(world_x: float, world_z: float) -> Vector2:` |
| 方法 | [`grid_to_world`](#member-gfheightfield3d-methods-grid_to_world) | `func grid_to_world(grid_position: Vector2, height: float = 0.0) -> Vector3:` |
| 方法 | [`sample_cell`](#member-gfheightfield3d-methods-sample_cell) | `func sample_cell(cell: Vector2i, fallback: Variant = null) -> float:` |
| 方法 | [`sample_grid_bilinear`](#member-gfheightfield3d-methods-sample_grid_bilinear) | `func sample_grid_bilinear(grid_position: Vector2, fallback: Variant = null) -> float:` |
| 方法 | [`sample_world`](#member-gfheightfield3d-methods-sample_world) | `func sample_world(world_x: float, world_z: float, fallback: Variant = null) -> float:` |
| 方法 | [`sample_world_position`](#member-gfheightfield3d-methods-sample_world_position) | `func sample_world_position(position: Vector3, fallback: Variant = null) -> float:` |
| 方法 | [`sample_normal_grid`](#member-gfheightfield3d-methods-sample_normal_grid) | `func sample_normal_grid(grid_position: Vector2, vertical_scale: float = 1.0) -> Vector3:` |
| 方法 | [`sample_slope_grid`](#member-gfheightfield3d-methods-sample_slope_grid) | `func sample_slope_grid(grid_position: Vector2, vertical_scale: float = 1.0) -> float:` |
| 方法 | [`sample_normal_world`](#member-gfheightfield3d-methods-sample_normal_world) | `func sample_normal_world(world_x: float, world_z: float, vertical_scale: float = 1.0) -> Vector3:` |
| 方法 | [`sample_slope_world`](#member-gfheightfield3d-methods-sample_slope_world) | `func sample_slope_world(world_x: float, world_z: float, vertical_scale: float = 1.0) -> float:` |
| 方法 | [`get_min_height`](#member-gfheightfield3d-methods-get_min_height) | `func get_min_height(fallback: float = 0.0) -> float:` |
| 方法 | [`get_max_height`](#member-gfheightfield3d-methods-get_max_height) | `func get_max_height(fallback: float = 0.0) -> float:` |
| 方法 | [`get_debug_snapshot`](#member-gfheightfield3d-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 方法

<a id="member-gfheightfield3d-methods-from_samples"></a>

### `from_samples`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func from_samples( grid_size: Vector2i, height_samples: PackedFloat32Array, world_min: Vector2 = Vector2.ZERO, world_max: Vector2 = Vector2.ONE ) -> GFHeightfield3D:
```

从样本创建高度场。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 高度网格尺寸，x 为世界 X 轴样本数，y 为世界 Z 轴样本数。 |
| `height_samples` | 行优先高度样本，数量必须等于 grid_size.x * grid_size.y。 |
| `world_min` | 高度场覆盖的最小 X/Z 世界坐标。 |
| `world_max` | 高度场覆盖的最大 X/Z 世界坐标。 |

返回：新高度场实例；输入无效时返回未配置实例。

<a id="member-gfheightfield3d-methods-from_terrain_rgb_image"></a>

### `from_terrain_rgb_image`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func from_terrain_rgb_image( image: Image, world_min: Vector2 = Vector2.ZERO, world_max: Vector2 = Vector2.ONE, options: Dictionary = {} ) -> GFHeightfield3D:
```

从 Terrain-RGB 图像创建高度场。 Terrain-RGB 使用 RGB 三通道编码米制高度：-10000 + (R * 65536 + G * 256 + B) * 0.1。 该方法只读取 Image 像素并生成高度样本，不加载网络瓦片、创建网格或绑定地图服务。

参数：

| 名称 | 说明 |
|---|---|
| `image` | Terrain-RGB 图像。 |
| `world_min` | 高度场覆盖的最小 X/Z 世界坐标。 |
| `world_max` | 高度场覆盖的最大 X/Z 世界坐标。 |
| `options` | 可选项，支持 height_scale 和 height_offset。 |

返回：新高度场实例；输入无效时返回未配置实例。

结构：

- `options`: Dictionary，可包含 height_scale 和 height_offset，用于在解码米制高度后进行线性变换。

<a id="member-gfheightfield3d-methods-decode_terrain_rgb_height"></a>

### `decode_terrain_rgb_height`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func decode_terrain_rgb_height(color: Color) -> float:
```

解码 Terrain-RGB 像素高度。

参数：

| 名称 | 说明 |
|---|---|
| `color` | Terrain-RGB 像素颜色。 |

返回：解码后的米制高度。

<a id="member-gfheightfield3d-methods-normal_to_slope"></a>

### `normal_to_slope`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func normal_to_slope(normal: Vector3) -> float:
```

将表面法线转换为归一化坡度。 返回值范围为 0.0 到 1.0；0.0 表示朝上的平面，1.0 表示垂直、倒置或无效法线。

参数：

| 名称 | 说明 |
|---|---|
| `normal` | 表面法线。 |

返回：归一化坡度。

<a id="member-gfheightfield3d-methods-samples_from_terrain_rgb_image"></a>

### `samples_from_terrain_rgb_image`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func samples_from_terrain_rgb_image(image: Image, options: Dictionary = {}) -> Dictionary:
```

从 Terrain-RGB 图像生成行优先高度样本报告。 报告中的 grid_size.x 对应图像宽度，grid_size.y 对应图像高度；samples 使用行优先顺序。

参数：

| 名称 | 说明 |
|---|---|
| `image` | Terrain-RGB 图像。 |
| `options` | 可选项，支持 height_scale 和 height_offset。 |

返回：样本生成报告。

结构：

- `options`: Dictionary，可包含 height_scale 和 height_offset，用于在解码米制高度后进行线性变换。
- `return`: Dictionary，包含 ok、grid_size、samples、sample_count、min_height、max_height、issues、counts 与 summary 字段。

<a id="member-gfheightfield3d-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func configure( grid_size: Vector2i, height_samples: PackedFloat32Array, world_min: Vector2 = Vector2.ZERO, world_max: Vector2 = Vector2.ONE ) -> bool:
```

配置高度场数据。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 高度网格尺寸，x 为世界 X 轴样本数，y 为世界 Z 轴样本数。 |
| `height_samples` | 行优先高度样本，数量必须等于 grid_size.x * grid_size.y。 |
| `world_min` | 高度场覆盖的最小 X/Z 世界坐标。 |
| `world_max` | 高度场覆盖的最大 X/Z 世界坐标。 |

返回：输入有效并已应用时返回 true；无效输入不会覆盖现有数据。

<a id="member-gfheightfield3d-methods-configure_from_terrain_rgb_image"></a>

### `configure_from_terrain_rgb_image`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func configure_from_terrain_rgb_image( image: Image, world_min: Vector2 = Vector2.ZERO, world_max: Vector2 = Vector2.ONE, options: Dictionary = {} ) -> bool:
```

使用 Terrain-RGB 图像配置高度场。 输入无效时不会覆盖现有数据。

参数：

| 名称 | 说明 |
|---|---|
| `image` | Terrain-RGB 图像。 |
| `world_min` | 高度场覆盖的最小 X/Z 世界坐标。 |
| `world_max` | 高度场覆盖的最大 X/Z 世界坐标。 |
| `options` | 可选项，支持 height_scale 和 height_offset。 |

返回：输入有效并已应用时返回 true；无效输入不会覆盖现有数据。

结构：

- `options`: Dictionary，可包含 height_scale 和 height_offset，用于在解码米制高度后进行线性变换。

<a id="member-gfheightfield3d-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空高度场数据。

<a id="member-gfheightfield3d-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_valid() -> bool:
```

判断当前高度场是否可采样。

返回：高度场尺寸、范围和样本数量有效时返回 true。

<a id="member-gfheightfield3d-methods-get_grid_size"></a>

### `get_grid_size`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_grid_size() -> Vector2i:
```

获取高度网格尺寸。

返回：网格尺寸，x 对应世界 X，y 对应世界 Z。

<a id="member-gfheightfield3d-methods-get_world_min"></a>

### `get_world_min`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_world_min() -> Vector2:
```

获取高度场最小 X/Z 世界坐标。

返回：最小 X/Z 世界坐标。

<a id="member-gfheightfield3d-methods-get_world_max"></a>

### `get_world_max`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_world_max() -> Vector2:
```

获取高度场最大 X/Z 世界坐标。

返回：最大 X/Z 世界坐标。

<a id="member-gfheightfield3d-methods-get_world_rect"></a>

### `get_world_rect`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_world_rect() -> Rect2:
```

获取高度场覆盖的 X/Z 世界矩形。

返回：世界矩形。

<a id="member-gfheightfield3d-methods-get_height_samples"></a>

### `get_height_samples`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_height_samples() -> PackedFloat32Array:
```

获取高度样本副本。

返回：行优先高度样本副本。

<a id="member-gfheightfield3d-methods-get_sample_count"></a>

### `get_sample_count`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_sample_count() -> int:
```

获取样本数量。

返回：当前样本数量。

<a id="member-gfheightfield3d-methods-contains_world_xz"></a>

### `contains_world_xz`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func contains_world_xz(world_x: float, world_z: float) -> bool:
```

判断 X/Z 世界坐标是否位于高度场范围内。

参数：

| 名称 | 说明 |
|---|---|
| `world_x` | 世界 X 坐标。 |
| `world_z` | 世界 Z 坐标。 |

返回：坐标位于高度场范围内时返回 true。

<a id="member-gfheightfield3d-methods-contains_world_position"></a>

### `contains_world_position`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func contains_world_position(position: Vector3) -> bool:
```

判断 3D 世界坐标的 X/Z 是否位于高度场范围内。

参数：

| 名称 | 说明 |
|---|---|
| `position` | 3D 世界坐标。 |

返回：坐标位于高度场范围内时返回 true。

<a id="member-gfheightfield3d-methods-world_to_grid"></a>

### `world_to_grid`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func world_to_grid(world_x: float, world_z: float) -> Vector2:
```

将 X/Z 世界坐标映射为连续网格坐标。

参数：

| 名称 | 说明 |
|---|---|
| `world_x` | 世界 X 坐标。 |
| `world_z` | 世界 Z 坐标。 |

返回：连续网格坐标；无效高度场返回 Vector2.ZERO。

<a id="member-gfheightfield3d-methods-grid_to_world"></a>

### `grid_to_world`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func grid_to_world(grid_position: Vector2, height: float = 0.0) -> Vector3:
```

将连续网格坐标映射为 3D 世界坐标。

参数：

| 名称 | 说明 |
|---|---|
| `grid_position` | 连续网格坐标。 |
| `height` | 返回坐标使用的 Y 值。 |

返回：3D 世界坐标；无效高度场返回 Vector3.ZERO。

<a id="member-gfheightfield3d-methods-sample_cell"></a>

### `sample_cell`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func sample_cell(cell: Vector2i, fallback: Variant = null) -> float:
```

读取整数网格格点高度。

参数：

| 名称 | 说明 |
|---|---|
| `cell` | 网格格点坐标，x 对应世界 X，y 对应世界 Z。 |
| `fallback` | 坐标无效时返回的高度；为 null 时返回 NAN。 |

返回：格点高度或 fallback。

结构：

- `fallback`: Variant，null 或数字高度。

<a id="member-gfheightfield3d-methods-sample_grid_bilinear"></a>

### `sample_grid_bilinear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func sample_grid_bilinear(grid_position: Vector2, fallback: Variant = null) -> float:
```

按连续网格坐标双线性采样高度。

参数：

| 名称 | 说明 |
|---|---|
| `grid_position` | 连续网格坐标。 |
| `fallback` | 坐标无效时返回的高度；为 null 时返回 NAN。 |

返回：双线性高度或 fallback。

结构：

- `fallback`: Variant，null 或数字高度。

<a id="member-gfheightfield3d-methods-sample_world"></a>

### `sample_world`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func sample_world(world_x: float, world_z: float, fallback: Variant = null) -> float:
```

按 X/Z 世界坐标采样高度。

参数：

| 名称 | 说明 |
|---|---|
| `world_x` | 世界 X 坐标。 |
| `world_z` | 世界 Z 坐标。 |
| `fallback` | 坐标无效时返回的高度；为 null 时返回 NAN。 |

返回：双线性高度或 fallback。

结构：

- `fallback`: Variant，null 或数字高度。

<a id="member-gfheightfield3d-methods-sample_world_position"></a>

### `sample_world_position`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func sample_world_position(position: Vector3, fallback: Variant = null) -> float:
```

按 3D 世界坐标的 X/Z 采样高度。

参数：

| 名称 | 说明 |
|---|---|
| `position` | 3D 世界坐标。 |
| `fallback` | 坐标无效时返回的高度；为 null 时返回 NAN。 |

返回：双线性高度或 fallback。

结构：

- `fallback`: Variant，null 或数字高度。

<a id="member-gfheightfield3d-methods-sample_normal_grid"></a>

### `sample_normal_grid`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func sample_normal_grid(grid_position: Vector2, vertical_scale: float = 1.0) -> Vector3:
```

按连续网格坐标估算表面法线。

参数：

| 名称 | 说明 |
|---|---|
| `grid_position` | 连续网格坐标。 |
| `vertical_scale` | 高度差缩放，用于匹配项目世界单位。 |

返回：归一化法线；无效高度场返回 Vector3.UP。

<a id="member-gfheightfield3d-methods-sample_slope_grid"></a>

### `sample_slope_grid`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func sample_slope_grid(grid_position: Vector2, vertical_scale: float = 1.0) -> float:
```

按连续网格坐标估算归一化坡度。 返回值范围为 0.0 到 1.0；无效高度场或坐标返回 1.0，便于调用方按保守策略拒绝无效表面。

参数：

| 名称 | 说明 |
|---|---|
| `grid_position` | 连续网格坐标。 |
| `vertical_scale` | 高度差缩放，用于匹配项目世界单位。 |

返回：归一化坡度。

<a id="member-gfheightfield3d-methods-sample_normal_world"></a>

### `sample_normal_world`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func sample_normal_world(world_x: float, world_z: float, vertical_scale: float = 1.0) -> Vector3:
```

按 X/Z 世界坐标估算表面法线。

参数：

| 名称 | 说明 |
|---|---|
| `world_x` | 世界 X 坐标。 |
| `world_z` | 世界 Z 坐标。 |
| `vertical_scale` | 高度差缩放，用于匹配项目世界单位。 |

返回：归一化法线；无效坐标返回 Vector3.UP。

<a id="member-gfheightfield3d-methods-sample_slope_world"></a>

### `sample_slope_world`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func sample_slope_world(world_x: float, world_z: float, vertical_scale: float = 1.0) -> float:
```

按 X/Z 世界坐标估算归一化坡度。 返回值范围为 0.0 到 1.0；无效高度场或坐标返回 1.0，便于调用方按保守策略拒绝无效表面。

参数：

| 名称 | 说明 |
|---|---|
| `world_x` | 世界 X 坐标。 |
| `world_z` | 世界 Z 坐标。 |
| `vertical_scale` | 高度差缩放，用于匹配项目世界单位。 |

返回：归一化坡度。

<a id="member-gfheightfield3d-methods-get_min_height"></a>

### `get_min_height`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_min_height(fallback: float = 0.0) -> float:
```

获取最小高度。

参数：

| 名称 | 说明 |
|---|---|
| `fallback` | 高度场无效时返回的值。 |

返回：最小高度或 fallback。

<a id="member-gfheightfield3d-methods-get_max_height"></a>

### `get_max_height`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_max_height(fallback: float = 0.0) -> float:
```

获取最大高度。

参数：

| 名称 | 说明 |
|---|---|
| `fallback` | 高度场无效时返回的值。 |

返回：最大高度或 fallback。

<a id="member-gfheightfield3d-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取高度场诊断快照。

返回：诊断快照。

结构：

- `return`: Dictionary with valid, grid_size, world_min, world_max, sample_count, min_height, and max_height.
