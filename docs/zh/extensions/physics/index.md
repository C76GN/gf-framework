# Physics 物理辅助

Physics 扩展提供通用 3D 重力场和浮力点采样。它适合局部重力、行星引力、磁力、推斥场、风场，以及船体、漂浮物或液体区域中的分布式浮力计算。

它不直接接管角色控制器、RigidBody、相机或网络状态；项目代码仍负责运动积分、探针布局、碰撞区域、施力时机和玩法解释。

## 核心模型

- `GFGravityField3D`：提供一个可采样的加速度场，支持朝向原点、远离原点或固定方向。
- `GFGravityProbe3D`：从场景树分组采样所有暴露 `get_acceleration_at(world_position)` 的对象，并按组合策略计算当前位置的加速度、上方向和下方向。
- 默认分组是 `gf_gravity_field_3d`，`GFGravityField3D` 进树时会自动加入。
- `GFBuoyancyMath3D`：根据浸没比例、排水体积、重力与相对流速计算单个采样点的浮力和阻力。
- `GFBuoyancyField3D`：默认提供可旋转的局部 Y 平面流体表面，并返回纯采样结果；子类可替换表面深度、法线或流速。

## 最小流程

```gdscript
var field := GFGravityField3D.new()
field.direction_mode = GFGravityField3D.DirectionMode.TOWARD_ORIGIN
field.acceleration = 12.0
field.radius = 20.0
add_child(field)

var probe := GFGravityProbe3D.new()
add_child(probe)

func _physics_process(delta: float) -> void:
	var acceleration := probe.sample()
	velocity += acceleration * delta
	up_direction = probe.get_up_direction()
```

## 重叠力场组合

`GFGravityProbe3D.combination_mode` 默认使用 `SUM`，会把所有有效力场相加。需要避免多个局部重力区互相抵消时，可以改用 `STRONGEST` 只取当前位置加速度长度最大的力场，或改用 `HIGHEST_PRIORITY` 只组合非零加速度中最高优先级的力场。

`GFGravityField3D.priority` 用于最高优先级模式；自定义采样对象也可以实现 `get_gravity_priority()`，让 Probe 在不认识具体类的情况下读取优先级。

## 浮力点采样

一个刚体通常用多个排水点近似体积。比如小木箱可以使用中心点，长船可以在船头、船尾和两侧分布采样点；每个点的 `displaced_volume` 之和代表希望参与浮力计算的总体积。GF 不自动猜测 Mesh 体积或刚体质量，避免不同资产尺度、空心物体和非均匀载荷被错误套用同一规则。

`GFBuoyancyField3D.sample_point()` 只返回 `submersion_ratio`、`buoyancy_force`、`drag_force` 和总 `force`。项目可以在自己的物理组件中把力施加到对应位置，也可以只用浸没比例驱动水花、音效或控制参数：

```gdscript
var offset: Vector3 = sample_position - body.global_position
var point_velocity: Vector3 = (
	body.linear_velocity
	+ body.angular_velocity.cross(offset)
)
var sample: Dictionary = water_field.sample_point(
	sample_position,
	point_velocity,
	point_displaced_volume,
	point_immersion_radius,
	gravity_acceleration
)

if GFVariantData.get_option_bool(sample, "active"):
	var force_value: Variant = GFVariantData.get_option_value(sample, "force")
	if force_value is Vector3:
		var force: Vector3 = force_value
		body.apply_force(force, offset)
```

默认表面经过节点局部 Y 轴和 `surface_offset`，因此旋转节点即可得到倾斜平面。海面、测试水槽或均匀液体层可以直接使用；河流可重写 `_get_fluid_velocity_at()`，高度图海浪可重写 `_get_signed_depth_at()` / `_get_surface_normal_at()`，有限水池则由项目的 `Area3D` 先筛选是否应该采样。所有几何变体继续复用同一浸没和力计算契约。

## 使用边界

- Physics 只提供场采样、方向和点力计算；不会自动发现刚体或决定每帧施力顺序。
- 角色移动、碰撞响应、朝向修正、相机控制、网络同步、性能分区和具体玩法规则由项目代码负责。
- 项目可以继承 `GFGravityField3D` 重写方向计算，也可以把自定义对象加入同一分组，只要实现 `get_acceleration_at()`。
- 项目也可以用 `GFObjectCandidateRegistry` 或自定义 provider 提供候选力场，再调用 `sample_field_provider(provider, options)` 采样。provider 适合把空间分区、可见性、LOD 或编辑器工具选集先收敛成候选对象；Probe 仍只读取 `get_acceleration_at()` 和可选 `get_gravity_priority()`。
- Probe 只会采样同一 `World3D` 中的分组对象；自定义 field 的 `get_acceleration_at(world_position)` 必须能接收一个位置参数并返回有限 `Vector3`。
- 同一帧重复采样默认会缓存结果；缓存键包含位置、分组、组合策略、fallback 配置和内置 field 的关键参数。如果项目在同一帧内移动自定义 field 或需要强制重新采样，可以关闭 `cache_samples_per_frame`。
- `STRONGEST` 模式在加速度长度相同时使用稳定顺序打破平局，避免场景树分组枚举顺序影响结果。
- 浮力大小使用调用方传入的重力加速度，因此局部重力项目可以先用 `GFGravityProbe3D` 采样，再把结果传给浮力场；二者仍是显式组合，不形成隐藏依赖。
- 线性和二次阻力参数是点采样的有效力系数，不假设固定几何体。项目应按对象尺度、探针数量和目标手感标定，并避免多个探针重复使用整个物体的排水体积。

## API Reference

完整类、方法和信号列表见 [Physics API Reference](../../reference/api/extensions-physics.md)。
