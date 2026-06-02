# GFSteeringAgent

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_steering_agent.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

steering 计算使用的通用代理状态。 只描述位置、速度、朝向和运动上限，不持有 Node 或物理体。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`position`](#member-gfsteeringagent-properties-position) | `var position: Vector3 = Vector3.ZERO` |
| 属性 | [`velocity`](#member-gfsteeringagent-properties-velocity) | `var velocity: Vector3 = Vector3.ZERO` |
| 属性 | [`orientation`](#member-gfsteeringagent-properties-orientation) | `var orientation: float = 0.0` |
| 属性 | [`angular_velocity`](#member-gfsteeringagent-properties-angular_velocity) | `var angular_velocity: float = 0.0` |
| 属性 | [`radius`](#member-gfsteeringagent-properties-radius) | `var radius: float = 8.0` |
| 属性 | [`linear_speed_max`](#member-gfsteeringagent-properties-linear_speed_max) | `var linear_speed_max: float = 240.0` |
| 属性 | [`linear_acceleration_max`](#member-gfsteeringagent-properties-linear_acceleration_max) | `var linear_acceleration_max: float = 800.0` |
| 属性 | [`angular_speed_max`](#member-gfsteeringagent-properties-angular_speed_max) | `var angular_speed_max: float = TAU` |
| 属性 | [`angular_acceleration_max`](#member-gfsteeringagent-properties-angular_acceleration_max) | `var angular_acceleration_max: float = TAU * 4.0` |
| 方法 | [`set_from_node_2d`](#member-gfsteeringagent-methods-set_from_node_2d) | `func set_from_node_2d(node: Node2D, linear_velocity: Vector2 = Vector2.ZERO) -> void:` |
| 方法 | [`set_from_node_3d`](#member-gfsteeringagent-methods-set_from_node_3d) | `func set_from_node_3d(node: Node3D, linear_velocity: Vector3 = Vector3.ZERO) -> void:` |
| 方法 | [`duplicate_agent`](#member-gfsteeringagent-methods-duplicate_agent) | `func duplicate_agent() -> GFSteeringAgent:` |

## 属性

<a id="member-gfsteeringagent-properties-position"></a>

### `position`

- API：`public`

```gdscript
var position: Vector3 = Vector3.ZERO
```

当前世界位置。2D 项目可使用 x/y，z 保持 0。

<a id="member-gfsteeringagent-properties-velocity"></a>

### `velocity`

- API：`public`

```gdscript
var velocity: Vector3 = Vector3.ZERO
```

当前线性速度。2D 项目可使用 x/y，z 保持 0。

<a id="member-gfsteeringagent-properties-orientation"></a>

### `orientation`

- API：`public`

```gdscript
var orientation: float = 0.0
```

当前朝向角，单位为弧度。

<a id="member-gfsteeringagent-properties-angular_velocity"></a>

### `angular_velocity`

- API：`public`

```gdscript
var angular_velocity: float = 0.0
```

当前角速度，单位为弧度每秒。

<a id="member-gfsteeringagent-properties-radius"></a>

### `radius`

- API：`public`

```gdscript
var radius: float = 8.0
```

代理半径，用于邻域或避让计算。

<a id="member-gfsteeringagent-properties-linear_speed_max"></a>

### `linear_speed_max`

- API：`public`

```gdscript
var linear_speed_max: float = 240.0
```

最大线性速度。

<a id="member-gfsteeringagent-properties-linear_acceleration_max"></a>

### `linear_acceleration_max`

- API：`public`

```gdscript
var linear_acceleration_max: float = 800.0
```

最大线性加速度。

<a id="member-gfsteeringagent-properties-angular_speed_max"></a>

### `angular_speed_max`

- API：`public`

```gdscript
var angular_speed_max: float = TAU
```

最大角速度。

<a id="member-gfsteeringagent-properties-angular_acceleration_max"></a>

### `angular_acceleration_max`

- API：`public`

```gdscript
var angular_acceleration_max: float = TAU * 4.0
```

最大角加速度。

## 方法

<a id="member-gfsteeringagent-methods-set_from_node_2d"></a>

### `set_from_node_2d`

- API：`public`

```gdscript
func set_from_node_2d(node: Node2D, linear_velocity: Vector2 = Vector2.ZERO) -> void:
```

从 Node2D 同步位置与朝向。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 目标 Node2D。 |
| `linear_velocity` | 可选线性速度。 |

<a id="member-gfsteeringagent-methods-set_from_node_3d"></a>

### `set_from_node_3d`

- API：`public`

```gdscript
func set_from_node_3d(node: Node3D, linear_velocity: Vector3 = Vector3.ZERO) -> void:
```

从 Node3D 同步位置与朝向。

参数：

| 名称 | 说明 |
|---|---|
| `node` | 目标 Node3D。 |
| `linear_velocity` | 可选线性速度。 |

<a id="member-gfsteeringagent-methods-duplicate_agent"></a>

### `duplicate_agent`

- API：`public`

```gdscript
func duplicate_agent() -> GFSteeringAgent:
```

创建深拷贝。

返回：新代理状态。
