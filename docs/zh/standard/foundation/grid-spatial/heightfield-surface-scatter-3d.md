# 3D 高度场与表面散布采样

`GFHeightfield3D` 与 `GFSurfaceScatterSampler3D` 提供一组纯数据 3D 表面采样能力。它们适合把高度网格转换为可查询表面，再从区域或候选点生成 `Transform3D` 与诊断报告，但不会创建地形节点、对象实例、碰撞体、MultiMesh 或项目资源。

## 适用场景

- 从工具、导入器或项目数据中得到一组高度样本，并需要按世界 X/Z 坐标查询高度或法线。
- 在表面上生成植被、道具、占位点、调试点或后续烘焙输入的候选 `Transform3D`。
- 需要固定 `seed`、高度范围、坡度范围、旋转、缩放和 y 偏移等通用约束。
- 需要把采样结果交给项目层自己的节点生成、对象池、导航、碰撞、保存或可视化流程。

不适合把它们当成完整地形系统。区块生命周期、LOD、贴图、材质、碰撞生成、流式加载和内容语义仍应由项目层或专门扩展组合。

## 高度场

`GFHeightfield3D` 使用行优先的 `PackedFloat32Array` 保存高度。`grid_size.x` 对应世界 X 轴样本数，`grid_size.y` 对应世界 Z 轴样本数；`world_min` / `world_max` 描述高度场覆盖的 X/Z 世界矩形。

```gdscript
var samples: PackedFloat32Array = PackedFloat32Array([
	0.0, 1.0,
	2.0, 3.0,
])

var heightfield: GFHeightfield3D = GFHeightfield3D.from_samples(
	Vector2i(2, 2),
	samples,
	Vector2.ZERO,
	Vector2(10.0, 10.0)
)

var height: float = heightfield.sample_world(5.0, 5.0)
var normal: Vector3 = heightfield.sample_normal_world(5.0, 5.0)
var slope: float = heightfield.sample_slope_world(5.0, 5.0)
```

如果输入来自 Terrain-RGB 高度图，可以先解码成行优先样本报告，也可以直接配置高度场。GF 只处理像素到高度样本的转换；图像加载、瓦片来源、区块生命周期、网格和材质仍由项目层负责。

```gdscript
var terrain_image: Image = _load_height_image()
var report: Dictionary = GFHeightfield3D.samples_from_terrain_rgb_image(
	terrain_image,
	{ "height_scale": 1.0, "height_offset": 0.0 }
)

if report["ok"]:
	var terrain_heightfield: GFHeightfield3D = GFHeightfield3D.from_terrain_rgb_image(
		terrain_image,
		Vector2.ZERO,
		Vector2(256.0, 256.0)
	)
```

常用入口：

- `configure()`：验证并应用网格、样本和世界范围；无效输入不会覆盖旧数据。
- `from_terrain_rgb_image()` / `configure_from_terrain_rgb_image()`：从 Terrain-RGB 图像创建或配置高度场。
- `samples_from_terrain_rgb_image()` / `decode_terrain_rgb_height()`：只解码图像或像素，适合导入器和工具先生成诊断报告。
- `sample_cell()`：读取整数格点高度。
- `sample_grid_bilinear()`：按连续网格坐标双线性采样。
- `sample_world()` / `sample_world_position()`：按世界 X/Z 采样高度。
- `sample_normal_grid()` / `sample_normal_world()`：按邻近高度估算上半球法线。
- `normal_to_slope()` / `sample_slope_grid()` / `sample_slope_world()`：把表面法线或高度场坐标转换为 0 到 1 的归一化坡度；无效表面按 1.0 保守处理。
- `get_debug_snapshot()`：导出尺寸、范围、样本数和高度范围诊断。

采样入口的 `fallback` 可传入数字高度；省略或传入 `null` 时，无效坐标仍返回 `NAN`。公开签名不把 `NAN` 作为默认参数值暴露给编辑器和 LSP，避免 Godot 在序列化 API 信息时把非 JSON 数字写成 `null`。

## 表面散布

`GFSurfaceScatterSampler3D` 只输出数据报告。项目层可以把 `transforms` 交给实例化、MultiMesh、编辑器预览、碰撞预烘焙或存档流程。

```gdscript
var report: Dictionary = GFSurfaceScatterSampler3D.sample_heightfield(
	heightfield,
	Rect2(Vector2.ZERO, Vector2(10.0, 10.0)),
	64,
	{
		"seed": 42,
		"height_min": 0.0,
		"height_max": 8.0,
		"slope_max": 0.35,
		"scale_min": 0.8,
		"scale_max": 1.2,
		"scale_axis_mode": "uniform",
	}
)

if report["ok"]:
	var transforms: Array = report["transforms"]
	for transform_value: Variant in transforms:
		if transform_value is Transform3D:
			var transform: Transform3D = transform_value
			_spawn_from_transform(transform)
```

如果项目已经有自己的候选点分布，可以用 `sample_points()` 或 `sample_heightfield_points()`。这让点分布、距离约束和表面投射保持解耦，例如先用 `GFPoissonDisc2D` 生成 X/Z 点，再投射到高度场。

```gdscript
var points: PackedVector2Array = PackedVector2Array([
	Vector2(2.0, 2.0),
	Vector2(4.0, 5.0),
])

var projected: Dictionary = GFSurfaceScatterSampler3D.sample_heightfield_points(
	heightfield,
	points,
	{ "seed": 11, "align_to_normal": true }
)
```

自定义表面提供者也可以直接接入：

```gdscript
var custom: Dictionary = GFSurfaceScatterSampler3D.sample(
	Rect2(Vector2.ZERO, Vector2(32.0, 32.0)),
	16,
	func(world_x: float, world_z: float) -> float:
		return _sample_project_height(world_x, world_z),
	func(world_x: float, world_z: float, vertical_scale: float) -> Vector3:
		return _sample_project_normal(world_x, world_z, vertical_scale),
	{ "seed": 5 }
)
```

## 报告字段

散布报告包含：

- `ok` / `error`：输入是否有效。
- `area`：采样区域或候选点包围矩形。
- `target_count`：目标 Transform 数量。
- `accepted_count`：实际接受数量。
- `attempt_count` / `max_attempts`：候选尝试数量与上限。
- `seed`：固定随机源种子。
- `transforms`：`Array[Transform3D]`。
- `points`：被接受的 `PackedVector3Array` 世界坐标。
- `normals`：被接受的 `PackedVector3Array` 法线。
- `exhausted_attempts`：候选耗尽或达到尝试上限但未满足目标数量。
- `rejected_height_count` / `rejected_slope_count` / `rejected_invalid_count`：拒绝原因统计。

报告中的 `Transform3D`、`Vector3`、`Rect2` 和 packed 数组适合项目内继续使用。需要把报告交给 `JSON.stringify()`、外部工具、日志管线或 CI 时，先调用 `GFSurfaceScatterSampler3D.to_json_compatible_report(report)`，避免 Godot Variant 或非有限浮点在 JSON 边界被隐式丢失。

## 选项

- `seed`：固定随机源种子，默认 `0`。
- `max_attempt_multiplier`：区域随机采样的最大尝试倍数，默认 `GFSurfaceScatterSampler3D.DEFAULT_MAX_ATTEMPT_MULTIPLIER`。
- `max_random_attempts`：区域随机采样的绝对尝试上限。
- `max_points`：`sample_points()` 的最大接受数量；小于等于 0 时使用全部候选点。
- `height_min` / `height_max`：接受的高度范围。
- `slope_min` / `slope_max`：接受的坡度范围，语义与 `GFHeightfield3D.sample_slope_*()` 一致；0 表示平面，1 表示垂直、倒置或无效表面。
- `yaw_min` / `yaw_max`：绕上方向的随机 yaw 范围。
- `scale_min` / `scale_max`：缩放范围，可传数字表示统一缩放，也可传 `Vector3` 表示每轴范围。
- `scale_axis_mode`：缩放随机权重的轴向锁定模式，支持 `uniform`、`free`、`lock_xy`、`lock_xz` 和 `lock_yz`；也可传 `GFTransform3DMath.ScaleAxisMode` 枚举值。
- `y_offset`：写入 Transform 原点前叠加的 Y 偏移。
- `align_to_normal`：是否把 Transform 的局部 Y 轴对齐到采样法线。
- `vertical_scale`：传给法线提供者的高度缩放。

## 与其他模块的关系

- `GFPoissonDisc2D` 可先生成带最小距离的二维候选点，再由 `sample_heightfield_points()` 投射到表面。
- `GFSpatialHash3D` 可在散布结果进入项目实体前做空间粗筛、邻近查询或工具预览索引。
- `GFDeterministicRandom` 提供固定随机序列；输出仍是浮点几何数据，不应直接作为跨平台锁步真值。
