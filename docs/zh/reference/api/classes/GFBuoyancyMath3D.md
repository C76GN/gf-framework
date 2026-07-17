# GFBuoyancyMath3D

[API Reference](../index.md) / [Physics](../extensions-physics.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/physics/core/gf_buoyancy_math_3d.gd`
- 模块：`Physics`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

通用 3D 浮力点采样数学工具。 只根据浸没深度、排水体积、重力和相对速度计算浸没比例与力， 不查询水体、不持有刚体，也不决定探针布局或施力时机。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`calculate_submersion_ratio`](#member-gfbuoyancymath3d-methods-calculate_submersion_ratio) | `static func calculate_submersion_ratio(signed_depth: float, immersion_radius: float) -> float:` |
| 方法 | [`calculate_buoyancy_force`](#member-gfbuoyancymath3d-methods-calculate_buoyancy_force) | `static func calculate_buoyancy_force( gravity_acceleration: Vector3, fluid_density: float, displaced_volume: float, submersion_ratio: float ) -> Vector3:` |
| 方法 | [`calculate_drag_force`](#member-gfbuoyancymath3d-methods-calculate_drag_force) | `static func calculate_drag_force( relative_velocity: Vector3, linear_coefficient: float, quadratic_coefficient: float, submersion_ratio: float ) -> Vector3:` |
| 方法 | [`calculate_point_force`](#member-gfbuoyancymath3d-methods-calculate_point_force) | `static func calculate_point_force( gravity_acceleration: Vector3, point_velocity: Vector3, fluid_velocity: Vector3, fluid_density: float, displaced_volume: float, submersion_ratio: float, linear_coefficient: float, quadratic_coefficient: float ) -> Vector3:` |

## 方法

<a id="member-gfbuoyancymath3d-methods-calculate_submersion_ratio"></a>

### `calculate_submersion_ratio`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func calculate_submersion_ratio(signed_depth: float, immersion_radius: float) -> float:
```

根据采样点到流体表面的有符号深度计算浸没比例。 深度为正表示位于表面下方；`-immersion_radius` 为完全离水， `0` 为一半浸没，`immersion_radius` 为完全浸没。

参数：

| 名称 | 说明 |
|---|---|
| `signed_depth` | 采样点相对流体表面的有符号深度。 |
| `immersion_radius` | 从半浸没到完全浸没所需的距离，必须大于 0。 |

返回：0 到 1 的浸没比例；输入无效时返回 0。

<a id="member-gfbuoyancymath3d-methods-calculate_buoyancy_force"></a>

### `calculate_buoyancy_force`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func calculate_buoyancy_force( gravity_acceleration: Vector3, fluid_density: float, displaced_volume: float, submersion_ratio: float ) -> Vector3:
```

计算一个采样点的阿基米德浮力。

参数：

| 名称 | 说明 |
|---|---|
| `gravity_acceleration` | 当前点的重力加速度向量。 |
| `fluid_density` | 流体密度。 |
| `displaced_volume` | 该采样点代表的最大排水体积。 |
| `submersion_ratio` | 0 到 1 的浸没比例。 |

返回：与重力方向相反的浮力；输入或计算结果无效时返回零向量。

<a id="member-gfbuoyancymath3d-methods-calculate_drag_force"></a>

### `calculate_drag_force`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func calculate_drag_force( relative_velocity: Vector3, linear_coefficient: float, quadratic_coefficient: float, submersion_ratio: float ) -> Vector3:
```

计算流体相对速度产生的线性与二次阻力。 两个系数都是点采样的有效力系数，由调用方按对象尺度和期望响应标定； GF 不把它们解释为某种固定形状的阻力面积或黏度模型。

参数：

| 名称 | 说明 |
|---|---|
| `relative_velocity` | 物体采样点相对流体的速度。 |
| `linear_coefficient` | 线性阻力有效系数。 |
| `quadratic_coefficient` | 二次阻力有效系数。 |
| `submersion_ratio` | 0 到 1 的浸没比例。 |

返回：与相对速度相反的阻力；输入或计算结果无效时返回零向量。

<a id="member-gfbuoyancymath3d-methods-calculate_point_force"></a>

### `calculate_point_force`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func calculate_point_force( gravity_acceleration: Vector3, point_velocity: Vector3, fluid_velocity: Vector3, fluid_density: float, displaced_volume: float, submersion_ratio: float, linear_coefficient: float, quadratic_coefficient: float ) -> Vector3:
```

组合一个采样点的浮力与阻力。

参数：

| 名称 | 说明 |
|---|---|
| `gravity_acceleration` | 当前点的重力加速度向量。 |
| `point_velocity` | 物体采样点速度。 |
| `fluid_velocity` | 流体在采样点的速度。 |
| `fluid_density` | 流体密度。 |
| `displaced_volume` | 采样点代表的最大排水体积。 |
| `submersion_ratio` | 0 到 1 的浸没比例。 |
| `linear_coefficient` | 线性阻力有效系数。 |
| `quadratic_coefficient` | 二次阻力有效系数。 |

返回：浮力与阻力之和。
