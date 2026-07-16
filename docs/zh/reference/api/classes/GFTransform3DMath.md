# GFTransform3DMath

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_transform_3d_math.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

通用 3D Transform 纯数学工具。 提供点、方向与 Transform3D 的平面反射、射线平面命中、表面吸附和锚点对齐计算。 它不创建节点、不处理镜面渲染，也不决定相机、材质、Portal、关卡编辑器或放置工具的业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`ScaleAxisMode`](#member-gftransform3dmath-enums-scaleaxismode) | `enum ScaleAxisMode` |
| 方法 | [`make_reflection_transform`](#member-gftransform3dmath-methods-make_reflection_transform) | `static func make_reflection_transform(plane_normal: Vector3, plane_point: Vector3) -> Transform3D:` |
| 方法 | [`reflect_point`](#member-gftransform3dmath-methods-reflect_point) | `static func reflect_point(point: Vector3, plane_normal: Vector3, plane_point: Vector3) -> Vector3:` |
| 方法 | [`reflect_direction`](#member-gftransform3dmath-methods-reflect_direction) | `static func reflect_direction(direction: Vector3, plane_normal: Vector3) -> Vector3:` |
| 方法 | [`reflect_transform`](#member-gftransform3dmath-methods-reflect_transform) | `static func reflect_transform( transform: Transform3D, plane_normal: Vector3, plane_point: Vector3 ) -> Transform3D:` |
| 方法 | [`intersect_ray_plane`](#member-gftransform3dmath-methods-intersect_ray_plane) | `static func intersect_ray_plane( ray_origin: Vector3, ray_direction: Vector3, plane_normal: Vector3, plane_point: Vector3, max_distance: float = -1.0, face_normal_to_ray: bool = true ) -> Dictionary:` |
| 方法 | [`make_basis_from_up_and_z_hint`](#member-gftransform3dmath-methods-make_basis_from_up_and_z_hint) | `static func make_basis_from_up_and_z_hint( up_axis: Vector3, z_axis_hint: Vector3 = Vector3.BACK ) -> Basis:` |
| 方法 | [`apply_scale_axis_mode`](#member-gftransform3dmath-methods-apply_scale_axis_mode) | `static func apply_scale_axis_mode( weight: Vector3, mode: ScaleAxisMode = ScaleAxisMode.UNIFORM ) -> Vector3:` |
| 方法 | [`interpolate_scale`](#member-gftransform3dmath-methods-interpolate_scale) | `static func interpolate_scale( min_scale: Vector3, max_scale: Vector3, weight: Vector3, mode: ScaleAxisMode = ScaleAxisMode.UNIFORM ) -> Vector3:` |
| 方法 | [`snap_point_to_plane_grid`](#member-gftransform3dmath-methods-snap_point_to_plane_grid) | `static func snap_point_to_plane_grid( point: Vector3, plane_normal: Vector3, grid_step: float, plane_origin: Vector3 = Vector3.ZERO ) -> Dictionary:` |
| 方法 | [`move_local_point_to_world`](#member-gftransform3dmath-methods-move_local_point_to_world) | `static func move_local_point_to_world( transform: Transform3D, local_point: Vector3, world_point: Vector3 ) -> Transform3D:` |

## 枚举

<a id="member-gftransform3dmath-enums-scaleaxismode"></a>

### `ScaleAxisMode`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
enum ScaleAxisMode {
	## X/Y/Z 使用同一个权重。
	UNIFORM,
	## X/Y/Z 分别使用输入权重。
	FREE,
	## X/Y 共用 X 权重，Z 保留自身权重。
	LOCK_XY,
	## X/Z 共用 X 权重，Y 保留自身权重。
	LOCK_XZ,
	## Y/Z 共用 Y 权重，X 保留自身权重。
	LOCK_YZ,
}
```

3D 缩放权重的轴向锁定模式。

## 方法

<a id="member-gftransform3dmath-methods-make_reflection_transform"></a>

### `make_reflection_transform`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func make_reflection_transform(plane_normal: Vector3, plane_point: Vector3) -> Transform3D:
```

构建相对指定平面的反射 Transform3D。

参数：

| 名称 | 说明 |
|---|---|
| `plane_normal` | 平面法线；函数会归一化。零向量时返回 Transform3D.IDENTITY。 |
| `plane_point` | 平面上的任意一点。 |

返回：将世界点反射到平面另一侧的 Transform3D。

<a id="member-gftransform3dmath-methods-reflect_point"></a>

### `reflect_point`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func reflect_point(point: Vector3, plane_normal: Vector3, plane_point: Vector3) -> Vector3:
```

将点按指定平面反射。

参数：

| 名称 | 说明 |
|---|---|
| `point` | 待反射的世界点。 |
| `plane_normal` | 平面法线；函数会归一化。零向量时返回原点值。 |
| `plane_point` | 平面上的任意一点。 |

返回：反射后的世界点。

<a id="member-gftransform3dmath-methods-reflect_direction"></a>

### `reflect_direction`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func reflect_direction(direction: Vector3, plane_normal: Vector3) -> Vector3:
```

将方向向量按指定平面法线反射。

参数：

| 名称 | 说明 |
|---|---|
| `direction` | 待反射方向；不会被额外归一化。 |
| `plane_normal` | 平面法线；函数会归一化。零向量时返回原方向。 |

返回：反射后的方向向量。

<a id="member-gftransform3dmath-methods-reflect_transform"></a>

### `reflect_transform`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func reflect_transform( transform: Transform3D, plane_normal: Vector3, plane_point: Vector3 ) -> Transform3D:
```

将 Transform3D 的 basis 与 origin 一起按指定平面反射。

参数：

| 名称 | 说明 |
|---|---|
| `transform` | 待反射 Transform3D。 |
| `plane_normal` | 平面法线；函数会归一化。零向量时返回原 Transform。 |
| `plane_point` | 平面上的任意一点。 |

返回：反射后的 Transform3D。

<a id="member-gftransform3dmath-methods-intersect_ray_plane"></a>

### `intersect_ray_plane`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func intersect_ray_plane( ray_origin: Vector3, ray_direction: Vector3, plane_normal: Vector3, plane_point: Vector3, max_distance: float = -1.0, face_normal_to_ray: bool = true ) -> Dictionary:
```

计算射线与平面的交点。 返回字典中的 distance 使用归一化后的 ray_direction 计算；当 face_normal_to_ray 为 true 时， 返回 normal 会朝向射线来源，便于后续表面放置、预览朝向或命中提示使用。

参数：

| 名称 | 说明 |
|---|---|
| `ray_origin` | 射线起点。 |
| `ray_direction` | 射线方向；函数会归一化。 |
| `plane_normal` | 平面法线；函数会归一化。 |
| `plane_point` | 平面上的任意一点。 |
| `max_distance` | 最大命中距离；小于等于 0 时不限制。 |
| `face_normal_to_ray` | 是否让返回法线朝向射线来源。 |

返回：命中报告。

结构：

- `return`: Dictionary，包含 ok: bool、reason: StringName、position: Vector3、normal: Vector3、distance: float、ray_origin: Vector3 和 ray_direction: Vector3。

<a id="member-gftransform3dmath-methods-make_basis_from_up_and_z_hint"></a>

### `make_basis_from_up_and_z_hint`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func make_basis_from_up_and_z_hint( up_axis: Vector3, z_axis_hint: Vector3 = Vector3.BACK ) -> Basis:
```

用目标 Y 轴和候选 Z 轴构建稳定正交 basis。 适合把物体局部 Y 轴贴合表面法线，同时尽量保持原本局部 Z 轴朝向。 z_axis_hint 与 up_axis 近似平行时，会自动选择稳定的兜底轴。

参数：

| 名称 | 说明 |
|---|---|
| `up_axis` | 目标局部 Y 轴方向。 |
| `z_axis_hint` | 期望局部 Z 轴尽量接近的方向。 |

返回：正交 basis；输入无效时返回 Basis.IDENTITY。

<a id="member-gftransform3dmath-methods-apply_scale_axis_mode"></a>

### `apply_scale_axis_mode`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func apply_scale_axis_mode( weight: Vector3, mode: ScaleAxisMode = ScaleAxisMode.UNIFORM ) -> Vector3:
```

按轴向锁定模式归一 3D 缩放插值权重。 该方法只处理权重复制关系，不钳制 0 到 1 范围；调用方可以用超出范围的权重做外插。 输入包含非有限数时返回 Vector3.ZERO。

参数：

| 名称 | 说明 |
|---|---|
| `weight` | 原始 X/Y/Z 权重。 |
| `mode` | 轴向锁定模式。 |

返回：应用于 X/Y/Z 的权重。

<a id="member-gftransform3dmath-methods-interpolate_scale"></a>

### `interpolate_scale`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func interpolate_scale( min_scale: Vector3, max_scale: Vector3, weight: Vector3, mode: ScaleAxisMode = ScaleAxisMode.UNIFORM ) -> Vector3:
```

按轴向锁定模式在两个 3D 缩放向量之间插值。 输入包含非有限数时返回 Vector3.ONE。该方法不钳制权重，也不限制缩放正负。

参数：

| 名称 | 说明 |
|---|---|
| `min_scale` | 起始缩放向量。 |
| `max_scale` | 结束缩放向量。 |
| `weight` | 原始 X/Y/Z 插值权重。 |
| `mode` | 轴向锁定模式。 |

返回：插值后的缩放向量。

<a id="member-gftransform3dmath-methods-snap_point_to_plane_grid"></a>

### `snap_point_to_plane_grid`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func snap_point_to_plane_grid( point: Vector3, plane_normal: Vector3, grid_step: float, plane_origin: Vector3 = Vector3.ZERO ) -> Dictionary:
```

在平面切向网格上吸附点，同时保留点到平面的法线距离。 grid_step 小于等于 0 或输入包含非有限数时返回 ok=false，并给出稳定零向量结果。

参数：

| 名称 | 说明 |
|---|---|
| `point` | 要吸附的世界点。 |
| `plane_normal` | 平面法线；函数会归一化。 |
| `grid_step` | 切向网格间距。 |
| `plane_origin` | 网格原点。 |

返回：吸附报告。

结构：

- `return`: Dictionary，包含 ok: bool、reason: StringName、point: Vector3、normal: Vector3、x_axis: Vector3、z_axis: Vector3、grid_step: float、normal_distance: float、x_distance: float 和 z_distance: float。

<a id="member-gftransform3dmath-methods-move_local_point_to_world"></a>

### `move_local_point_to_world`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func move_local_point_to_world( transform: Transform3D, local_point: Vector3, world_point: Vector3 ) -> Transform3D:
```

平移 Transform3D，使指定本地锚点落到目标世界点。 常用于把模型底部、抓取点、吸附点或自定义 pivot 对齐到命中位置。

参数：

| 名称 | 说明 |
|---|---|
| `transform` | 原始世界 Transform3D。 |
| `local_point` | transform 本地空间中的锚点。 |
| `world_point` | 锚点应对齐到的世界点。 |

返回：平移后的 Transform3D；输入无效时返回原 Transform。
