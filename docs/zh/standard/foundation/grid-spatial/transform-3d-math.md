# 3D Transform 数学

`GFTransform3DMath` 提供围绕平面的 3D 反射、射线命中、表面吸附和锚点对齐纯算法。它只处理 `Vector3`、`Basis` 与 `Transform3D`，不会创建镜面节点、相机、材质、Viewport、Portal、编辑器放置工具或项目对象。

这个能力适合项目层或扩展在需要纯空间计算时复用，例如预览反射位置、构建镜像相机输入、从屏幕射线投到编辑平面、让预览对象贴合表面法线、在表面切平面上做网格吸附、生成带轴锁的 3D 缩放，或把模型底部锚点对齐到命中点。

```gdscript
var mirror_plane_normal: Vector3 = Vector3.RIGHT
var mirror_plane_point: Vector3 = Vector3.ZERO

var reflected_point: Vector3 = GFTransform3DMath.reflect_point(
	global_position,
	mirror_plane_normal,
	mirror_plane_point
)

var reflected_transform: Transform3D = GFTransform3DMath.reflect_transform(
	global_transform,
	mirror_plane_normal,
	mirror_plane_point
)
```

```gdscript
var scale_value: Vector3 = GFTransform3DMath.interpolate_scale(
	Vector3.ONE,
	Vector3(2.0, 2.0, 4.0),
	Vector3(0.25, 0.5, 0.75),
	GFTransform3DMath.ScaleAxisMode.LOCK_XY
)
```

```gdscript
var ray := viewport_utility.screen_to_world_ray_3d(camera, mouse_position, 2000.0)
var hit := GFTransform3DMath.intersect_ray_plane(
	GFVariantData.get_option_vector3(ray, "origin"),
	GFVariantData.get_option_vector3(ray, "direction"),
	Vector3.UP,
	Vector3.ZERO
)

if GFVariantData.get_option_bool(hit, "ok"):
	var snapped := GFTransform3DMath.snap_point_to_plane_grid(
		GFVariantData.get_option_vector3(hit, "position"),
		GFVariantData.get_option_vector3(hit, "normal"),
		0.5
	)
	var basis := GFTransform3DMath.make_basis_from_up_and_z_hint(
		GFVariantData.get_option_vector3(hit, "normal"),
		preview.global_transform.basis.z
	)
	preview.global_transform = Transform3D(
		basis,
		GFVariantData.get_option_vector3(snapped, "point")
	)
```

## 核心入口

- `make_reflection_transform()`：构建可直接作用于世界点的反射 `Transform3D`。
- `reflect_point()`：把世界点按平面反射。
- `reflect_direction()`：只按法线反射方向向量，不使用平面偏移。
- `reflect_transform()`：同时反射 `origin` 和 `basis` 三个轴，输出新的 `Transform3D`。
- `intersect_ray_plane()`：计算归一化射线与平面的交点，并返回稳定的 `ok` / `reason` 报告。
- `make_basis_from_up_and_z_hint()`：把局部 Y 轴对齐到表面法线，同时尽量保持局部 Z 轴朝向。
- `apply_scale_axis_mode()` / `interpolate_scale()`：按 `UNIFORM`、`FREE`、`LOCK_XY`、`LOCK_XZ` 或 `LOCK_YZ` 处理 3D 缩放权重和缩放范围。
- `snap_point_to_plane_grid()`：在平面切向网格中吸附点，并保留点到平面的法线距离。
- `move_local_point_to_world()`：平移 `Transform3D`，让指定本地锚点落到目标世界点。

## 边界行为

法线和射线方向会被归一化；零向量、非有限数、平行射线或超出最大距离等情况会返回稳定失败报告或原始输入值。调用方仍应在项目语义层决定这个结果是否可接受，例如禁用预览、报告配置错误，或回退到默认相机。

`snap_point_to_plane_grid()` 的网格只在平面切向上吸附，不会把点强行压回平面。这样编辑器预览、地形放置和表面吸附可以保留已有高度、悬浮偏移或模型底部校正。

## 使用边界

`GFTransform3DMath` 是无状态纯算法。它不处理裁剪平面、渲染遮罩、反射材质、相机同步、碰撞、Terrain3D、撤销重做、节点实例化或资源库管理。需要完整镜面、Portal、编辑器操控器、资产面板或关卡工具时，应由项目层或扩展组合本页的数学结果与 Godot 节点系统。
