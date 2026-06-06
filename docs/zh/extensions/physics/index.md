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
- 同一帧重复采样默认会缓存结果；缓存键包含位置、分组、组合策略和 fallback 配置。如果项目在同一帧内移动 field 或需要强制重新采样，可以关闭 `cache_samples_per_frame`。

## API Reference

完整类、方法和信号列表见 [Physics API Reference](../../reference/api/extensions-physics.md)。
