# Physics 物理辅助

Physics 扩展当前提供通用 3D 重力场采样。它适合局部重力、行星引力、磁力、推斥场、风场或任何“按位置采样一个加速度向量”的 3D 项目。

它不直接修改角色控制器、RigidBody、相机或网络状态；项目代码仍负责运动积分、碰撞响应和玩法解释。

## 核心模型

- `GFGravityField3D`：提供一个可采样的加速度场，支持朝向原点、远离原点或固定方向。
- `GFGravityProbe3D`：从场景树分组采样所有暴露 `get_acceleration_at(world_position)` 的对象，并按组合策略计算当前位置的加速度、上方向和下方向。
- 默认分组是 `gf_gravity_field_3d`，`GFGravityField3D` 进树时会自动加入。

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

## 使用边界

- Physics 只提供场采样和方向计算。
- 角色移动、碰撞响应、朝向修正、相机控制、网络同步、性能分区和具体玩法规则由项目代码负责。
- 项目可以继承 `GFGravityField3D` 重写方向计算，也可以把自定义对象加入同一分组，只要实现 `get_acceleration_at()`。
- 项目也可以用 `GFObjectCandidateRegistry` 或自定义 provider 提供候选力场，再调用 `sample_field_provider(provider, options)` 采样。provider 适合把空间分区、可见性、LOD 或编辑器工具选集先收敛成候选对象；Probe 仍只读取 `get_acceleration_at()` 和可选 `get_gravity_priority()`。
- Probe 只会采样同一 `World3D` 中的分组对象；自定义 field 的 `get_acceleration_at(world_position)` 必须能接收一个位置参数并返回有限 `Vector3`。
- 同一帧重复采样默认会缓存结果；缓存键包含位置、分组、组合策略、fallback 配置和内置 field 的关键参数。如果项目在同一帧内移动自定义 field 或需要强制重新采样，可以关闭 `cache_samples_per_frame`。
- `STRONGEST` 模式在加速度长度相同时使用稳定顺序打破平局，避免场景树分组枚举顺序影响结果。

## API Reference

完整类、方法和信号列表见 [Physics API Reference](../../reference/api/extensions-physics.md)。
