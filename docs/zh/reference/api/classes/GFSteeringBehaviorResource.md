# GFSteeringBehaviorResource

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_steering_behavior_resource.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

可资源化配置的 steering 行为。 包装 GFSteeringMath 的纯算法，允许项目用 Resource 组合 seek、arrive、avoid 等 通用行为。动态目标、邻居和路径通过 context 传入，避免把业务对象写死进资源。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`BehaviorType`](#member-gfsteeringbehaviorresource-enums-behaviortype) | `enum BehaviorType` |
| 属性 | [`behavior_type`](#member-gfsteeringbehaviorresource-properties-behavior_type) | `var behavior_type: BehaviorType = BehaviorType.SEEK` |
| 属性 | [`enabled`](#member-gfsteeringbehaviorresource-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`weight`](#member-gfsteeringbehaviorresource-properties-weight) | `var weight: float = 1.0` |
| 属性 | [`target_position`](#member-gfsteeringbehaviorresource-properties-target_position) | `var target_position: Vector3 = Vector3.ZERO` |
| 属性 | [`target_orientation`](#member-gfsteeringbehaviorresource-properties-target_orientation) | `var target_orientation: float = 0.0` |
| 属性 | [`arrival_radius`](#member-gfsteeringbehaviorresource-properties-arrival_radius) | `var arrival_radius: float = 4.0` |
| 属性 | [`slow_radius`](#member-gfsteeringbehaviorresource-properties-slow_radius) | `var slow_radius: float = 64.0` |
| 属性 | [`time_to_target`](#member-gfsteeringbehaviorresource-properties-time_to_target) | `var time_to_target: float = 0.1` |
| 属性 | [`align_tolerance`](#member-gfsteeringbehaviorresource-properties-align_tolerance) | `var align_tolerance: float = 0.001` |
| 属性 | [`slow_angle`](#member-gfsteeringbehaviorresource-properties-slow_angle) | `var slow_angle: float = 0.5` |
| 属性 | [`use_z_axis`](#member-gfsteeringbehaviorresource-properties-use_z_axis) | `var use_z_axis: bool = false` |
| 属性 | [`max_prediction_seconds`](#member-gfsteeringbehaviorresource-properties-max_prediction_seconds) | `var max_prediction_seconds: float = 1.0` |
| 属性 | [`decay_coefficient`](#member-gfsteeringbehaviorresource-properties-decay_coefficient) | `var decay_coefficient: float = 1.0` |
| 属性 | [`max_distance`](#member-gfsteeringbehaviorresource-properties-max_distance) | `var max_distance: float = -1.0` |
| 属性 | [`collision_radius`](#member-gfsteeringbehaviorresource-properties-collision_radius) | `var collision_radius: float = -1.0` |
| 属性 | [`minimum_separation`](#member-gfsteeringbehaviorresource-properties-minimum_separation) | `var minimum_separation: float = -1.0` |
| 属性 | [`path_offset`](#member-gfsteeringbehaviorresource-properties-path_offset) | `var path_offset: float = 0.0` |
| 方法 | [`calculate`](#member-gfsteeringbehaviorresource-methods-calculate) | `func calculate(agent: GFSteeringAgent, context: Dictionary = {}) -> GFSteeringAcceleration:` |
| 方法 | [`duplicate_behavior`](#member-gfsteeringbehaviorresource-methods-duplicate_behavior) | `func duplicate_behavior() -> Resource:` |

## 枚举

<a id="member-gfsteeringbehaviorresource-enums-behaviortype"></a>

### `BehaviorType`

- API：`public`

```gdscript
enum BehaviorType { ## 朝目标位置加速。 SEEK, ## 远离目标位置。 FLEE, ## 抵达目标位置并减速。 ARRIVE, ## 追逐目标代理。 PURSUE, ## 躲避目标代理。 EVADE, ## 面向目标位置。 FACE, ## 朝当前速度方向转向。 LOOK_WHERE_YOU_GO, ## 对齐指定朝向。 ALIGN, ## 与邻居保持距离。 SEPARATION, ## 朝邻居中心靠拢。 COHESION, ## 基于预测最近距离避让碰撞。 AVOID_COLLISIONS, ## 沿路径计算目标点并 seek。 PATH_FOLLOW_SEEK, }
```

Steering 行为类型。

## 属性

<a id="member-gfsteeringbehaviorresource-properties-behavior_type"></a>

### `behavior_type`

- API：`public`

```gdscript
var behavior_type: BehaviorType = BehaviorType.SEEK
```

行为类型。

<a id="member-gfsteeringbehaviorresource-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用该行为。

<a id="member-gfsteeringbehaviorresource-properties-weight"></a>

### `weight`

- API：`public`

```gdscript
var weight: float = 1.0
```

组合时使用的权重。

<a id="member-gfsteeringbehaviorresource-properties-target_position"></a>

### `target_position`

- API：`public`

```gdscript
var target_position: Vector3 = Vector3.ZERO
```

静态目标位置；context 中的 `target_position` 会覆盖该值。

<a id="member-gfsteeringbehaviorresource-properties-target_orientation"></a>

### `target_orientation`

- API：`public`

```gdscript
var target_orientation: float = 0.0
```

静态目标朝向；context 中的 `target_orientation` 会覆盖该值。

<a id="member-gfsteeringbehaviorresource-properties-arrival_radius"></a>

### `arrival_radius`

- API：`public`

```gdscript
var arrival_radius: float = 4.0
```

抵达半径。

<a id="member-gfsteeringbehaviorresource-properties-slow_radius"></a>

### `slow_radius`

- API：`public`

```gdscript
var slow_radius: float = 64.0
```

减速半径。

<a id="member-gfsteeringbehaviorresource-properties-time_to_target"></a>

### `time_to_target`

- API：`public`

```gdscript
var time_to_target: float = 0.1
```

逼近期望时间。

<a id="member-gfsteeringbehaviorresource-properties-align_tolerance"></a>

### `align_tolerance`

- API：`public`

```gdscript
var align_tolerance: float = 0.001
```

角度对齐容差。

<a id="member-gfsteeringbehaviorresource-properties-slow_angle"></a>

### `slow_angle`

- API：`public`

```gdscript
var slow_angle: float = 0.5
```

开始角速度减速的角度。

<a id="member-gfsteeringbehaviorresource-properties-use_z_axis"></a>

### `use_z_axis`

- API：`public`

```gdscript
var use_z_axis: bool = false
```

3D 转向是否使用 x/z 平面。

<a id="member-gfsteeringbehaviorresource-properties-max_prediction_seconds"></a>

### `max_prediction_seconds`

- API：`public`

```gdscript
var max_prediction_seconds: float = 1.0
```

目标预测最大秒数。

<a id="member-gfsteeringbehaviorresource-properties-decay_coefficient"></a>

### `decay_coefficient`

- API：`public`

```gdscript
var decay_coefficient: float = 1.0
```

分离行为距离衰减系数。

<a id="member-gfsteeringbehaviorresource-properties-max_distance"></a>

### `max_distance`

- API：`public`

```gdscript
var max_distance: float = -1.0
```

最大影响距离；小于 0 时由算法使用代理半径。

<a id="member-gfsteeringbehaviorresource-properties-collision_radius"></a>

### `collision_radius`

- API：`public`

```gdscript
var collision_radius: float = -1.0
```

避让碰撞半径；小于 0 时由算法使用双方半径。

<a id="member-gfsteeringbehaviorresource-properties-minimum_separation"></a>

### `minimum_separation`

- API：`public`

```gdscript
var minimum_separation: float = -1.0
```

避让最小分离距离；小于 0 时由算法使用碰撞半径。

<a id="member-gfsteeringbehaviorresource-properties-path_offset"></a>

### `path_offset`

- API：`public`

```gdscript
var path_offset: float = 0.0
```

路径跟随前进偏移。

## 方法

<a id="member-gfsteeringbehaviorresource-methods-calculate"></a>

### `calculate`

- API：`public`

```gdscript
func calculate(agent: GFSteeringAgent, context: Dictionary = {}) -> GFSteeringAcceleration:
```

计算 steering 加速度。

参数：

| 名称 | 说明 |
|---|---|
| `agent` | 代理状态。 |
| `context` | 动态上下文，支持 target_position、target_orientation、target_agent、neighbors、targets、path。 |

返回：steering 加速度。

结构：

- `context`: Dictionary steering behavior context with optional target_position, target_orientation, target_agent, neighbors, targets, and path.

<a id="member-gfsteeringbehaviorresource-methods-duplicate_behavior"></a>

### `duplicate_behavior`

- API：`public`

```gdscript
func duplicate_behavior() -> Resource:
```

创建配置副本。

返回：新行为资源。
