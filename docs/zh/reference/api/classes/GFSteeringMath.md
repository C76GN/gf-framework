# GFSteeringMath

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_steering_math.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用 steering 行为的纯算法集合。 提供 seek、flee、arrive、pursue、separation、cohesion、blend、priority 等 可组合计算，不负责把结果应用到具体 Node、物理体或业务状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`acceleration`](#member-gfsteeringmath-methods-acceleration) | `static func acceleration(linear: Vector3 = Vector3.ZERO, angular: float = 0.0) -> GFSteeringAcceleration:` |
| 方法 | [`seek`](#member-gfsteeringmath-methods-seek) | `static func seek(agent: GFSteeringAgent, target_position: Vector3) -> GFSteeringAcceleration:` |
| 方法 | [`flee`](#member-gfsteeringmath-methods-flee) | `static func flee(agent: GFSteeringAgent, target_position: Vector3) -> GFSteeringAcceleration:` |
| 方法 | [`arrive`](#member-gfsteeringmath-methods-arrive) | `static func arrive( agent: GFSteeringAgent, target_position: Vector3, arrival_radius: float = 4.0, slow_radius: float = 64.0, time_to_target: float = 0.1 ) -> GFSteeringAcceleration:` |
| 方法 | [`pursue`](#member-gfsteeringmath-methods-pursue) | `static func pursue( agent: GFSteeringAgent, target_agent: GFSteeringAgent, max_prediction_seconds: float = 1.0 ) -> GFSteeringAcceleration:` |
| 方法 | [`evade`](#member-gfsteeringmath-methods-evade) | `static func evade( agent: GFSteeringAgent, target_agent: GFSteeringAgent, max_prediction_seconds: float = 1.0 ) -> GFSteeringAcceleration:` |
| 方法 | [`face`](#member-gfsteeringmath-methods-face) | `static func face( agent: GFSteeringAgent, target_position: Vector3, use_z_axis: bool = false, align_tolerance: float = 0.001, slow_angle: float = 0.5, time_to_target: float = 0.1 ) -> GFSteeringAcceleration:` |
| 方法 | [`look_where_you_go`](#member-gfsteeringmath-methods-look_where_you_go) | `static func look_where_you_go( agent: GFSteeringAgent, use_z_axis: bool = false, align_tolerance: float = 0.001, slow_angle: float = 0.5, time_to_target: float = 0.1 ) -> GFSteeringAcceleration:` |
| 方法 | [`align`](#member-gfsteeringmath-methods-align) | `static func align( agent: GFSteeringAgent, target_orientation: float, align_tolerance: float = 0.001, slow_angle: float = 0.5, time_to_target: float = 0.1 ) -> GFSteeringAcceleration:` |
| 方法 | [`separation`](#member-gfsteeringmath-methods-separation) | `static func separation( agent: GFSteeringAgent, neighbors: Array[GFSteeringAgent], decay_coefficient: float = 1.0, max_distance: float = -1.0 ) -> GFSteeringAcceleration:` |
| 方法 | [`cohesion`](#member-gfsteeringmath-methods-cohesion) | `static func cohesion(agent: GFSteeringAgent, neighbors: Array[GFSteeringAgent]) -> GFSteeringAcceleration:` |
| 方法 | [`blend`](#member-gfsteeringmath-methods-blend) | `static func blend( accelerations: Array[GFSteeringAcceleration], weights: Array[float] = [], max_linear: float = -1.0, max_angular: float = -1.0 ) -> GFSteeringAcceleration:` |
| 方法 | [`priority`](#member-gfsteeringmath-methods-priority) | `static func priority( accelerations: Array[GFSteeringAcceleration], threshold: float = 0.001 ) -> GFSteeringAcceleration:` |
| 方法 | [`radius_neighbors`](#member-gfsteeringmath-methods-radius_neighbors) | `static func radius_neighbors( agent: GFSteeringAgent, candidates: Array[GFSteeringAgent], radius: float = -1.0 ) -> Array[GFSteeringAgent]:` |
| 方法 | [`avoid_collisions`](#member-gfsteeringmath-methods-avoid_collisions) | `static func avoid_collisions( agent: GFSteeringAgent, targets: Array[GFSteeringAgent], max_prediction_seconds: float = 1.0, collision_radius: float = -1.0, minimum_separation: float = -1.0 ) -> GFSteeringAcceleration:` |
| 方法 | [`path_follow_target`](#member-gfsteeringmath-methods-path_follow_target) | `static func path_follow_target( agent: GFSteeringAgent, path: Array[Vector3], path_offset: float = 0.0 ) -> Vector3:` |

## 方法

<a id="member-gfsteeringmath-methods-acceleration"></a>

### `acceleration`

- API：`public`

```gdscript
static func acceleration(linear: Vector3 = Vector3.ZERO, angular: float = 0.0) -> GFSteeringAcceleration:
```

创建加速度结果。

参数：

| 名称 | 说明 |
|---|---|
| `linear` | 线性加速度。 |
| `angular` | 角加速度。 |

返回：新加速度结果。

<a id="member-gfsteeringmath-methods-seek"></a>

### `seek`

- API：`public`

```gdscript
static func seek(agent: GFSteeringAgent, target_position: Vector3) -> GFSteeringAcceleration:
```

计算朝目标点加速的 seek 行为。

参数：

| 名称 | 说明 |
|---|---|
| `agent` | 代理状态。 |
| `target_position` | 目标位置。 |

返回：steering 加速度。

<a id="member-gfsteeringmath-methods-flee"></a>

### `flee`

- API：`public`

```gdscript
static func flee(agent: GFSteeringAgent, target_position: Vector3) -> GFSteeringAcceleration:
```

计算远离目标点的 flee 行为。

参数：

| 名称 | 说明 |
|---|---|
| `agent` | 代理状态。 |
| `target_position` | 目标位置。 |

返回：steering 加速度。

<a id="member-gfsteeringmath-methods-arrive"></a>

### `arrive`

- API：`public`

```gdscript
static func arrive( agent: GFSteeringAgent, target_position: Vector3, arrival_radius: float = 4.0, slow_radius: float = 64.0, time_to_target: float = 0.1 ) -> GFSteeringAcceleration:
```

计算抵达目标点并在近处减速的 arrive 行为。

参数：

| 名称 | 说明 |
|---|---|
| `agent` | 代理状态。 |
| `target_position` | 目标位置。 |
| `arrival_radius` | 视为到达的半径。 |
| `slow_radius` | 开始减速的半径。 |
| `time_to_target` | 期望在多少秒内逼近目标速度。 |

返回：steering 加速度。

<a id="member-gfsteeringmath-methods-pursue"></a>

### `pursue`

- API：`public`

```gdscript
static func pursue( agent: GFSteeringAgent, target_agent: GFSteeringAgent, max_prediction_seconds: float = 1.0 ) -> GFSteeringAcceleration:
```

计算追逐移动目标的 pursue 行为。

参数：

| 名称 | 说明 |
|---|---|
| `agent` | 代理状态。 |
| `target_agent` | 目标代理状态。 |
| `max_prediction_seconds` | 最大预测秒数。 |

返回：steering 加速度。

<a id="member-gfsteeringmath-methods-evade"></a>

### `evade`

- API：`public`

```gdscript
static func evade( agent: GFSteeringAgent, target_agent: GFSteeringAgent, max_prediction_seconds: float = 1.0 ) -> GFSteeringAcceleration:
```

计算逃离移动目标的 evade 行为。

参数：

| 名称 | 说明 |
|---|---|
| `agent` | 代理状态。 |
| `target_agent` | 目标代理状态。 |
| `max_prediction_seconds` | 最大预测秒数。 |

返回：steering 加速度。

<a id="member-gfsteeringmath-methods-face"></a>

### `face`

- API：`public`

```gdscript
static func face( agent: GFSteeringAgent, target_position: Vector3, use_z_axis: bool = false, align_tolerance: float = 0.001, slow_angle: float = 0.5, time_to_target: float = 0.1 ) -> GFSteeringAcceleration:
```

计算面向目标点的角加速度。

参数：

| 名称 | 说明 |
|---|---|
| `agent` | 代理状态。 |
| `target_position` | 目标位置。 |
| `use_z_axis` | 为 true 时使用 x/z 平面，否则使用 x/y 平面。 |
| `align_tolerance` | 视为对齐的角度阈值。 |
| `slow_angle` | 开始减速的角度。 |
| `time_to_target` | 期望在多少秒内逼近目标角速度。 |

返回：steering 加速度。

<a id="member-gfsteeringmath-methods-look_where_you_go"></a>

### `look_where_you_go`

- API：`public`

```gdscript
static func look_where_you_go( agent: GFSteeringAgent, use_z_axis: bool = false, align_tolerance: float = 0.001, slow_angle: float = 0.5, time_to_target: float = 0.1 ) -> GFSteeringAcceleration:
```

计算朝当前速度方向转向的角加速度。

参数：

| 名称 | 说明 |
|---|---|
| `agent` | 代理状态。 |
| `use_z_axis` | 为 true 时使用 x/z 平面，否则使用 x/y 平面。 |
| `align_tolerance` | 视为对齐的角度阈值。 |
| `slow_angle` | 开始减速的角度。 |
| `time_to_target` | 期望在多少秒内逼近目标角速度。 |

返回：steering 加速度。

<a id="member-gfsteeringmath-methods-align"></a>

### `align`

- API：`public`

```gdscript
static func align( agent: GFSteeringAgent, target_orientation: float, align_tolerance: float = 0.001, slow_angle: float = 0.5, time_to_target: float = 0.1 ) -> GFSteeringAcceleration:
```

计算对齐指定朝向的角加速度。

参数：

| 名称 | 说明 |
|---|---|
| `agent` | 代理状态。 |
| `target_orientation` | 目标朝向弧度。 |
| `align_tolerance` | 视为对齐的角度阈值。 |
| `slow_angle` | 开始减速的角度。 |
| `time_to_target` | 期望在多少秒内逼近目标角速度。 |

返回：steering 加速度。

<a id="member-gfsteeringmath-methods-separation"></a>

### `separation`

- API：`public`

```gdscript
static func separation( agent: GFSteeringAgent, neighbors: Array[GFSteeringAgent], decay_coefficient: float = 1.0, max_distance: float = -1.0 ) -> GFSteeringAcceleration:
```

计算邻居分离行为。

参数：

| 名称 | 说明 |
|---|---|
| `agent` | 代理状态。 |
| `neighbors` | 邻居代理列表。 |
| `decay_coefficient` | 距离衰减系数。 |
| `max_distance` | 最大影响距离；小于等于 0 时使用双方半径之和。 |

返回：steering 加速度。

<a id="member-gfsteeringmath-methods-cohesion"></a>

### `cohesion`

- API：`public`

```gdscript
static func cohesion(agent: GFSteeringAgent, neighbors: Array[GFSteeringAgent]) -> GFSteeringAcceleration:
```

计算朝邻居中心靠拢的 cohesion 行为。

参数：

| 名称 | 说明 |
|---|---|
| `agent` | 代理状态。 |
| `neighbors` | 邻居代理列表。 |

返回：steering 加速度。

<a id="member-gfsteeringmath-methods-blend"></a>

### `blend`

- API：`public`

```gdscript
static func blend( accelerations: Array[GFSteeringAcceleration], weights: Array[float] = [], max_linear: float = -1.0, max_angular: float = -1.0 ) -> GFSteeringAcceleration:
```

混合多个 steering 加速度。

参数：

| 名称 | 说明 |
|---|---|
| `accelerations` | 加速度列表。 |
| `weights` | 对应权重；缺失时使用 1。 |
| `max_linear` | 最大线性加速度；小于 0 时不限制。 |
| `max_angular` | 最大角加速度；小于 0 时不限制。 |

返回：混合后的加速度。

<a id="member-gfsteeringmath-methods-priority"></a>

### `priority`

- API：`public`

```gdscript
static func priority( accelerations: Array[GFSteeringAcceleration], threshold: float = 0.001 ) -> GFSteeringAcceleration:
```

从多个 steering 加速度中选择第一个超过阈值的结果。

参数：

| 名称 | 说明 |
|---|---|
| `accelerations` | 加速度列表。 |
| `threshold` | 非零阈值。 |

返回：第一个有效加速度；没有时返回零加速度。

<a id="member-gfsteeringmath-methods-radius_neighbors"></a>

### `radius_neighbors`

- API：`public`

```gdscript
static func radius_neighbors( agent: GFSteeringAgent, candidates: Array[GFSteeringAgent], radius: float = -1.0 ) -> Array[GFSteeringAgent]:
```

获取半径内的邻居代理。

参数：

| 名称 | 说明 |
|---|---|
| `agent` | 代理状态。 |
| `candidates` | 候选代理列表。 |
| `radius` | 查询半径；小于 0 时使用 agent.radius。 |

返回：半径内邻居列表。

<a id="member-gfsteeringmath-methods-avoid_collisions"></a>

### `avoid_collisions`

- API：`public`

```gdscript
static func avoid_collisions( agent: GFSteeringAgent, targets: Array[GFSteeringAgent], max_prediction_seconds: float = 1.0, collision_radius: float = -1.0, minimum_separation: float = -1.0 ) -> GFSteeringAcceleration:
```

计算基于未来最近距离的动态碰撞避让行为。

参数：

| 名称 | 说明 |
|---|---|
| `agent` | 代理状态。 |
| `targets` | 需要避让的目标代理列表。 |
| `max_prediction_seconds` | 最大预测秒数；小于等于 0 时只处理当前重叠。 |
| `collision_radius` | 碰撞半径；小于 0 时使用双方半径之和。 |
| `minimum_separation` | 预测最近距离阈值；小于 0 时使用碰撞半径。 |

返回：steering 加速度。

<a id="member-gfsteeringmath-methods-path_follow_target"></a>

### `path_follow_target`

- API：`public`

```gdscript
static func path_follow_target( agent: GFSteeringAgent, path: Array[Vector3], path_offset: float = 0.0 ) -> Vector3:
```

计算路径跟随的下一个目标点。

参数：

| 名称 | 说明 |
|---|---|
| `agent` | 代理状态。 |
| `path` | 路径点列表。 |
| `path_offset` | 沿路径前进的距离。 |

返回：路径上的目标点；路径为空时返回代理当前位置。
