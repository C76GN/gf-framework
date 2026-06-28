# GFSurfaceScatterSampler3D

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_surface_scatter_sampler_3d.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

通用 3D 表面散布 Transform 采样器。 在 X/Z 区域或候选点集上调用高度/法线提供者，按高度、坡度、旋转和缩放约束 输出纯 Transform3D 与诊断报告。它不创建 Node、MultiMesh、碰撞体或项目对象。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MAX_ATTEMPT_MULTIPLIER`](#member-gfsurfacescattersampler3d-constants-default_max_attempt_multiplier) | `const DEFAULT_MAX_ATTEMPT_MULTIPLIER: int = 12` |
| 常量 | [`DEFAULT_MAX_RANDOM_ATTEMPTS`](#member-gfsurfacescattersampler3d-constants-default_max_random_attempts) | `const DEFAULT_MAX_RANDOM_ATTEMPTS: int = 65536` |
| 方法 | [`sample_heightfield`](#member-gfsurfacescattersampler3d-methods-sample_heightfield) | `static func sample_heightfield( heightfield: GFHeightfield3D, area: Rect2, count: int, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`sample_heightfield_points`](#member-gfsurfacescattersampler3d-methods-sample_heightfield_points) | `static func sample_heightfield_points( heightfield: GFHeightfield3D, points: PackedVector2Array, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`sample`](#member-gfsurfacescattersampler3d-methods-sample) | `static func sample( area: Rect2, count: int, height_provider: Callable, normal_provider: Callable = Callable(), options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`sample_points`](#member-gfsurfacescattersampler3d-methods-sample_points) | `static func sample_points( points: PackedVector2Array, height_provider: Callable, normal_provider: Callable = Callable(), options: Dictionary = {} ) -> Dictionary:` |

## 常量

<a id="member-gfsurfacescattersampler3d-constants-default_max_attempt_multiplier"></a>

### `DEFAULT_MAX_ATTEMPT_MULTIPLIER`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const DEFAULT_MAX_ATTEMPT_MULTIPLIER: int = 12
```

区域随机采样的默认最大尝试倍数。

<a id="member-gfsurfacescattersampler3d-constants-default_max_random_attempts"></a>

### `DEFAULT_MAX_RANDOM_ATTEMPTS`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const DEFAULT_MAX_RANDOM_ATTEMPTS: int = 65536
```

默认最大候选点数量，避免误把超大散布任务交给单帧纯 GDScript。

## 方法

<a id="member-gfsurfacescattersampler3d-methods-sample_heightfield"></a>

### `sample_heightfield`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func sample_heightfield( heightfield: GFHeightfield3D, area: Rect2, count: int, options: Dictionary = {} ) -> Dictionary:
```

在高度场覆盖的 X/Z 区域中生成散布 Transform。

参数：

| 名称 | 说明 |
|---|---|
| `heightfield` | 高度场数据。 |
| `area` | X/Z 采样区域，Rect2.position 为最小 X/Z，Rect2.size 为范围尺寸。 |
| `count` | 目标 Transform 数量。 |
| `options` | 采样选项。 |

返回：散布报告。

结构：

- `options`: Dictionary supports seed, max_attempt_multiplier, max_random_attempts, height_min, height_max, slope_min, slope_max, yaw_min, yaw_max, scale_min, scale_max, y_offset, align_to_normal, and vertical_scale.
- `return`: Dictionary with ok, error, area, target_count, accepted_count, attempt_count, max_attempts, seed, transforms, points, normals, exhausted_attempts, rejected_height_count, rejected_slope_count, and rejected_invalid_count.

<a id="member-gfsurfacescattersampler3d-methods-sample_heightfield_points"></a>

### `sample_heightfield_points`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func sample_heightfield_points( heightfield: GFHeightfield3D, points: PackedVector2Array, options: Dictionary = {} ) -> Dictionary:
```

将候选 X/Z 点投射到高度场并生成散布 Transform。

参数：

| 名称 | 说明 |
|---|---|
| `heightfield` | 高度场数据。 |
| `points` | 候选 X/Z 点集。 |
| `options` | 采样选项。 |

返回：散布报告。

结构：

- `options`: Dictionary supports seed, max_points, height_min, height_max, slope_min, slope_max, yaw_min, yaw_max, scale_min, scale_max, y_offset, align_to_normal, and vertical_scale.
- `return`: Dictionary with ok, error, area, target_count, accepted_count, attempt_count, max_attempts, seed, transforms, points, normals, exhausted_attempts, rejected_height_count, rejected_slope_count, and rejected_invalid_count.

<a id="member-gfsurfacescattersampler3d-methods-sample"></a>

### `sample`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func sample( area: Rect2, count: int, height_provider: Callable, normal_provider: Callable = Callable(), options: Dictionary = {} ) -> Dictionary:
```

在 X/Z 区域中随机生成候选点并采样散布 Transform。

参数：

| 名称 | 说明 |
|---|---|
| `area` | X/Z 采样区域，Rect2.position 为最小 X/Z，Rect2.size 为范围尺寸。 |
| `count` | 目标 Transform 数量。 |
| `height_provider` | 高度回调，签名为 func(world_x: float, world_z: float) -> float。 |
| `normal_provider` | 法线回调，签名为 func(world_x: float, world_z: float, vertical_scale: float) -> Vector3；无效时使用 Vector3.UP。 |
| `options` | 采样选项。 |

返回：散布报告。

结构：

- `options`: Dictionary supports seed, max_attempt_multiplier, max_random_attempts, height_min, height_max, slope_min, slope_max, yaw_min, yaw_max, scale_min, scale_max, y_offset, align_to_normal, and vertical_scale.
- `return`: Dictionary with ok, error, area, target_count, accepted_count, attempt_count, max_attempts, seed, transforms, points, normals, exhausted_attempts, rejected_height_count, rejected_slope_count, and rejected_invalid_count.

<a id="member-gfsurfacescattersampler3d-methods-sample_points"></a>

### `sample_points`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func sample_points( points: PackedVector2Array, height_provider: Callable, normal_provider: Callable = Callable(), options: Dictionary = {} ) -> Dictionary:
```

将已有候选 X/Z 点投射为散布 Transform。

参数：

| 名称 | 说明 |
|---|---|
| `points` | 候选 X/Z 点集。 |
| `height_provider` | 高度回调，签名为 func(world_x: float, world_z: float) -> float。 |
| `normal_provider` | 法线回调，签名为 func(world_x: float, world_z: float, vertical_scale: float) -> Vector3；无效时使用 Vector3.UP。 |
| `options` | 采样选项。 |

返回：散布报告。

结构：

- `options`: Dictionary supports seed, max_points, height_min, height_max, slope_min, slope_max, yaw_min, yaw_max, scale_min, scale_max, y_offset, align_to_normal, and vertical_scale.
- `return`: Dictionary with ok, error, area, target_count, accepted_count, attempt_count, max_attempts, seed, transforms, points, normals, exhausted_attempts, rejected_height_count, rejected_slope_count, and rejected_invalid_count.
