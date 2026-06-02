# GFGravityField3D

[API Reference](../index.md) / [Physics](../extensions-physics.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/physics/nodes/gf_gravity_field_3d.gd`
- 模块：`Physics`
- 继承：`Node3D`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用 3D 重力/加速度场。 提供点重力、远离中心和固定方向三种方向模式，以及常量、线性、平方反比 和曲线衰减。项目可继承并重写方向或强度计算以实现更复杂的场。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`field_changed`](#member-gfgravityfield3d-signals-field_changed) | `signal field_changed` |
| 枚举 | [`DirectionMode`](#member-gfgravityfield3d-enums-directionmode) | `enum DirectionMode` |
| 枚举 | [`FalloffMode`](#member-gfgravityfield3d-enums-falloffmode) | `enum FalloffMode` |
| 属性 | [`enabled`](#member-gfgravityfield3d-properties-enabled) | `var enabled: bool = true:` |
| 属性 | [`acceleration`](#member-gfgravityfield3d-properties-acceleration) | `var acceleration: float = 9.8:` |
| 属性 | [`radius`](#member-gfgravityfield3d-properties-radius) | `var radius: float = 0.0:` |
| 属性 | [`min_distance`](#member-gfgravityfield3d-properties-min_distance) | `var min_distance: float = 1.0:` |
| 属性 | [`direction_mode`](#member-gfgravityfield3d-properties-direction_mode) | `var direction_mode: DirectionMode = DirectionMode.TOWARD_ORIGIN:` |
| 属性 | [`constant_direction`](#member-gfgravityfield3d-properties-constant_direction) | `var constant_direction: Vector3 = Vector3.DOWN:` |
| 属性 | [`falloff_mode`](#member-gfgravityfield3d-properties-falloff_mode) | `var falloff_mode: FalloffMode = FalloffMode.CONSTANT:` |
| 属性 | [`falloff_curve`](#member-gfgravityfield3d-properties-falloff_curve) | `var falloff_curve: Curve = null:` |
| 方法 | [`get_acceleration_at`](#member-gfgravityfield3d-methods-get_acceleration_at) | `func get_acceleration_at(world_position: Vector3) -> Vector3:` |
| 方法 | [`get_strength_at_distance`](#member-gfgravityfield3d-methods-get_strength_at_distance) | `func get_strength_at_distance(distance: float) -> float:` |

## 信号

<a id="member-gfgravityfield3d-signals-field_changed"></a>

### `field_changed`

- API：`public`

```gdscript
signal field_changed
```

力场参数变化时发出。

## 枚举

<a id="member-gfgravityfield3d-enums-directionmode"></a>

### `DirectionMode`

- API：`public`

```gdscript
enum DirectionMode { ## 朝向力场节点原点。 TOWARD_ORIGIN, ## 远离力场节点原点。 AWAY_FROM_ORIGIN, ## 使用固定方向。 CONSTANT_DIRECTION, }
```

力场方向模式。

<a id="member-gfgravityfield3d-enums-falloffmode"></a>

### `FalloffMode`

- API：`public`

```gdscript
enum FalloffMode { ## 半径内保持恒定强度。 CONSTANT, ## 从中心到半径边缘线性衰减。 LINEAR, ## 按平方反比衰减。 INVERSE_SQUARE, ## 使用 Curve 采样衰减；横轴为距离占半径比例。 CURVE, }
```

强度衰减模式。

## 属性

<a id="member-gfgravityfield3d-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true:
```

是否启用力场。

<a id="member-gfgravityfield3d-properties-acceleration"></a>

### `acceleration`

- API：`public`

```gdscript
var acceleration: float = 9.8:
```

基础加速度强度。

<a id="member-gfgravityfield3d-properties-radius"></a>

### `radius`

- API：`public`

```gdscript
var radius: float = 0.0:
```

影响半径；小于等于 0 表示无限范围。

<a id="member-gfgravityfield3d-properties-min_distance"></a>

### `min_distance`

- API：`public`

```gdscript
var min_distance: float = 1.0:
```

平方反比模式下用于避免近距离发散的最小距离。

<a id="member-gfgravityfield3d-properties-direction_mode"></a>

### `direction_mode`

- API：`public`

```gdscript
var direction_mode: DirectionMode = DirectionMode.TOWARD_ORIGIN:
```

方向模式。

<a id="member-gfgravityfield3d-properties-constant_direction"></a>

### `constant_direction`

- API：`public`

```gdscript
var constant_direction: Vector3 = Vector3.DOWN:
```

固定方向模式使用的方向。

<a id="member-gfgravityfield3d-properties-falloff_mode"></a>

### `falloff_mode`

- API：`public`

```gdscript
var falloff_mode: FalloffMode = FalloffMode.CONSTANT:
```

强度衰减模式。

<a id="member-gfgravityfield3d-properties-falloff_curve"></a>

### `falloff_curve`

- API：`public`

```gdscript
var falloff_curve: Curve = null:
```

曲线衰减模式使用的 Curve。采样值会乘以 acceleration。

## 方法

<a id="member-gfgravityfield3d-methods-get_acceleration_at"></a>

### `get_acceleration_at`

- API：`public`

```gdscript
func get_acceleration_at(world_position: Vector3) -> Vector3:
```

获取指定世界坐标处的加速度向量。

参数：

| 名称 | 说明 |
|---|---|
| `world_position` | 世界坐标。 |

返回：加速度向量。

<a id="member-gfgravityfield3d-methods-get_strength_at_distance"></a>

### `get_strength_at_distance`

- API：`public`

```gdscript
func get_strength_at_distance(distance: float) -> float:
```

获取指定距离处的力场强度。

参数：

| 名称 | 说明 |
|---|---|
| `distance` | 距离。 |

返回：加速度强度。
