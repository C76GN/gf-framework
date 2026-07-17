# GFBuoyancyField3D

[API Reference](../index.md) / [Physics](../extensions-physics.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/physics/nodes/gf_buoyancy_field_3d.gd`
- 模块：`Physics`
- 继承：`Node3D`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

可扩展的 3D 浮力点采样场。 默认以节点局部 Y 平面作为无限流体表面，把几何采样和浮力数学组合成纯结果字典。 项目可以重写表面、流速钩子实现有限水体、高度场或移动流体，但刚体施力、探针布局、 Area 检测、网络同步和玩法规则仍由项目层决定。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`FIELD_GROUP`](#member-gfbuoyancyfield3d-constants-field_group) | `const FIELD_GROUP: StringName = &"gf_buoyancy_field_3d"` |
| 属性 | [`enabled`](#member-gfbuoyancyfield3d-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`priority`](#member-gfbuoyancyfield3d-properties-priority) | `var priority: int = 0` |
| 属性 | [`surface_offset`](#member-gfbuoyancyfield3d-properties-surface_offset) | `var surface_offset: float = 0.0:` |
| 属性 | [`fluid_density`](#member-gfbuoyancyfield3d-properties-fluid_density) | `var fluid_density: float = 1000.0:` |
| 属性 | [`fluid_velocity`](#member-gfbuoyancyfield3d-properties-fluid_velocity) | `var fluid_velocity: Vector3 = Vector3.ZERO:` |
| 属性 | [`linear_drag_coefficient`](#member-gfbuoyancyfield3d-properties-linear_drag_coefficient) | `var linear_drag_coefficient: float = 0.0:` |
| 属性 | [`quadratic_drag_coefficient`](#member-gfbuoyancyfield3d-properties-quadratic_drag_coefficient) | `var quadratic_drag_coefficient: float = 0.0:` |
| 方法 | [`get_surface_origin`](#member-gfbuoyancyfield3d-methods-get_surface_origin) | `func get_surface_origin() -> Vector3:` |
| 方法 | [`get_signed_depth_at`](#member-gfbuoyancyfield3d-methods-get_signed_depth_at) | `func get_signed_depth_at(world_position: Vector3) -> float:` |
| 方法 | [`get_surface_normal_at`](#member-gfbuoyancyfield3d-methods-get_surface_normal_at) | `func get_surface_normal_at(world_position: Vector3) -> Vector3:` |
| 方法 | [`get_fluid_velocity_at`](#member-gfbuoyancyfield3d-methods-get_fluid_velocity_at) | `func get_fluid_velocity_at(world_position: Vector3) -> Vector3:` |
| 方法 | [`get_buoyancy_priority`](#member-gfbuoyancyfield3d-methods-get_buoyancy_priority) | `func get_buoyancy_priority() -> int:` |
| 方法 | [`sample_point`](#member-gfbuoyancyfield3d-methods-sample_point) | `func sample_point( world_position: Vector3, point_velocity: Vector3, displaced_volume: float, immersion_radius: float, gravity_acceleration: Vector3 ) -> Dictionary:` |
| 方法 | [`_get_signed_depth_at`](#member-gfbuoyancyfield3d-methods-_get_signed_depth_at) | `func _get_signed_depth_at(world_position: Vector3) -> float:` |
| 方法 | [`_get_surface_normal_at`](#member-gfbuoyancyfield3d-methods-_get_surface_normal_at) | `func _get_surface_normal_at(world_position: Vector3) -> Vector3:` |
| 方法 | [`_get_fluid_velocity_at`](#member-gfbuoyancyfield3d-methods-_get_fluid_velocity_at) | `func _get_fluid_velocity_at(world_position: Vector3) -> Vector3:` |

## 常量

<a id="member-gfbuoyancyfield3d-constants-field_group"></a>

### `FIELD_GROUP`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const FIELD_GROUP: StringName = &"gf_buoyancy_field_3d"
```

浮力场默认场景树分组。

## 属性

<a id="member-gfbuoyancyfield3d-properties-enabled"></a>

### `enabled`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var enabled: bool = true
```

是否启用采样场。

<a id="member-gfbuoyancyfield3d-properties-priority"></a>

### `priority`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var priority: int = 0
```

调用方组合多个流体场时可读取的优先级；数值越大优先级越高。

<a id="member-gfbuoyancyfield3d-properties-surface_offset"></a>

### `surface_offset`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var surface_offset: float = 0.0:
```

默认平面相对节点局部原点的 Y 偏移。

<a id="member-gfbuoyancyfield3d-properties-fluid_density"></a>

### `fluid_density`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var fluid_density: float = 1000.0:
```

流体密度。

<a id="member-gfbuoyancyfield3d-properties-fluid_velocity"></a>

### `fluid_velocity`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var fluid_velocity: Vector3 = Vector3.ZERO:
```

默认世界空间流体速度。

<a id="member-gfbuoyancyfield3d-properties-linear_drag_coefficient"></a>

### `linear_drag_coefficient`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var linear_drag_coefficient: float = 0.0:
```

点采样线性阻力有效系数。

<a id="member-gfbuoyancyfield3d-properties-quadratic_drag_coefficient"></a>

### `quadratic_drag_coefficient`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var quadratic_drag_coefficient: float = 0.0:
```

点采样二次阻力有效系数。

## 方法

<a id="member-gfbuoyancyfield3d-methods-get_surface_origin"></a>

### `get_surface_origin`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_surface_origin() -> Vector3:
```

获取默认平面的世界空间原点。

返回：默认流体表面原点。

<a id="member-gfbuoyancyfield3d-methods-get_signed_depth_at"></a>

### `get_signed_depth_at`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_signed_depth_at(world_position: Vector3) -> float:
```

获取世界坐标相对流体表面的有符号深度。

参数：

| 名称 | 说明 |
|---|---|
| `world_position` | 世界空间采样点。 |

返回：正数表示表面下方，负数表示表面上方；输入或表面无效时返回 0。

<a id="member-gfbuoyancyfield3d-methods-get_surface_normal_at"></a>

### `get_surface_normal_at`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_surface_normal_at(world_position: Vector3) -> Vector3:
```

获取采样点处的流体表面法线。

参数：

| 名称 | 说明 |
|---|---|
| `world_position` | 世界空间采样点。 |

返回：归一化世界空间法线；无效时返回 Vector3.UP。

<a id="member-gfbuoyancyfield3d-methods-get_fluid_velocity_at"></a>

### `get_fluid_velocity_at`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_fluid_velocity_at(world_position: Vector3) -> Vector3:
```

获取采样点处的世界空间流体速度。

参数：

| 名称 | 说明 |
|---|---|
| `world_position` | 世界空间采样点。 |

返回：世界空间流体速度；无效时返回零向量。

<a id="member-gfbuoyancyfield3d-methods-get_buoyancy_priority"></a>

### `get_buoyancy_priority`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_buoyancy_priority() -> int:
```

获取调用方组合多个浮力场时使用的优先级。

返回：优先级数值，越大越优先。

<a id="member-gfbuoyancyfield3d-methods-sample_point"></a>

### `sample_point`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func sample_point( world_position: Vector3, point_velocity: Vector3, displaced_volume: float, immersion_radius: float, gravity_acceleration: Vector3 ) -> Dictionary:
```

采样单个排水点的浸没状态、浮力和阻力。 方法不修改 RigidBody3D。调用方可把 `force` 传给 `apply_force()`，也可以只读取 浸没比例驱动音效、粒子、控制器或自定义物理积分。

参数：

| 名称 | 说明 |
|---|---|
| `world_position` | 排水点世界坐标。 |
| `point_velocity` | 排水点世界空间速度。 |
| `displaced_volume` | 排水点代表的最大排水体积。 |
| `immersion_radius` | 从半浸没到完全浸没所需距离。 |
| `gravity_acceleration` | 当前排水点的重力加速度向量。 |

返回：采样结果字典。

结构：

- `return`: Dictionary，包含 available、active、reason、signed_depth、submersion_ratio、surface_normal、fluid_velocity、buoyancy_force、drag_force 和 force。

<a id="member-gfbuoyancyfield3d-methods-_get_signed_depth_at"></a>

### `_get_signed_depth_at`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _get_signed_depth_at(world_position: Vector3) -> float:
```

计算世界坐标相对流体表面的有符号深度。 默认实现使用节点局部 Y 平面；子类可实现有限体积、高度场或其他连续表面。

参数：

| 名称 | 说明 |
|---|---|
| `world_position` | 世界空间采样点。 |

返回：正数表示流体内部，负数表示外部。

<a id="member-gfbuoyancyfield3d-methods-_get_surface_normal_at"></a>

### `_get_surface_normal_at`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _get_surface_normal_at(world_position: Vector3) -> Vector3:
```

计算采样点处的世界空间流体表面法线。

参数：

| 名称 | 说明 |
|---|---|
| `world_position` | 世界空间采样点。 |

返回：世界空间表面法线。

<a id="member-gfbuoyancyfield3d-methods-_get_fluid_velocity_at"></a>

### `_get_fluid_velocity_at`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _get_fluid_velocity_at(world_position: Vector3) -> Vector3:
```

计算采样点处的世界空间流体速度。

参数：

| 名称 | 说明 |
|---|---|
| `world_position` | 世界空间采样点。 |

返回：世界空间流体速度。
