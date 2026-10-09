# GFLinearProjectileMotion

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_linear_projectile_motion.gd`
- 模块：`Combat`
- 继承：`GFProjectileMotion`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

2D/3D 对称的直线 intent 策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`speed`](#member-gflinearprojectilemotion-properties-speed) | `var speed: float = 0.0` |
| 属性 | [`direction_2d`](#member-gflinearprojectilemotion-properties-direction_2d) | `var direction_2d: Vector2 = Vector2.RIGHT` |
| 属性 | [`direction_3d`](#member-gflinearprojectilemotion-properties-direction_3d) | `var direction_3d: Vector3 = Vector3.FORWARD` |
| 属性 | [`use_local_direction`](#member-gflinearprojectilemotion-properties-use_local_direction) | `var use_local_direction: bool = true` |
| 属性 | [`normalize_direction`](#member-gflinearprojectilemotion-properties-normalize_direction) | `var normalize_direction: bool = true` |
| 方法 | [`_create_state_2d`](#member-gflinearprojectilemotion-methods-_create_state_2d) | `func _create_state_2d( _launch_input: GFProjectileLaunchInput2D, initial_body: GFProjectileBodyResult2D ) -> GFProjectileMotionState:` |
| 方法 | [`_create_state_3d`](#member-gflinearprojectilemotion-methods-_create_state_3d) | `func _create_state_3d( _launch_input: GFProjectileLaunchInput3D, initial_body: GFProjectileBodyResult3D ) -> GFProjectileMotionState:` |
| 方法 | [`_compute_intent_2d`](#member-gflinearprojectilemotion-methods-_compute_intent_2d) | `func _compute_intent_2d( state: GFProjectileMotionState, _current_body: GFProjectileBodyResult2D, delta: float ) -> GFProjectileMotionIntent2D:` |
| 方法 | [`_compute_intent_3d`](#member-gflinearprojectilemotion-methods-_compute_intent_3d) | `func _compute_intent_3d( state: GFProjectileMotionState, _current_body: GFProjectileBodyResult3D, delta: float ) -> GFProjectileMotionIntent3D:` |

## 属性

<a id="member-gflinearprojectilemotion-properties-speed"></a>

### `speed`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var speed: float = 0.0
```

world-space 运动速度。

<a id="member-gflinearprojectilemotion-properties-direction_2d"></a>

### `direction_2d`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var direction_2d: Vector2 = Vector2.RIGHT
```

2D 基础方向。

<a id="member-gflinearprojectilemotion-properties-direction_3d"></a>

### `direction_3d`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var direction_3d: Vector3 = Vector3.FORWARD
```

3D 基础方向。

<a id="member-gflinearprojectilemotion-properties-use_local_direction"></a>

### `use_local_direction`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var use_local_direction: bool = true
```

是否按初始 body basis 将基础方向转换到 world-space。

<a id="member-gflinearprojectilemotion-properties-normalize_direction"></a>

### `normalize_direction`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var normalize_direction: bool = true
```

是否在乘以 speed 前单位化方向。

## 方法

<a id="member-gflinearprojectilemotion-methods-_create_state_2d"></a>

### `_create_state_2d`

- API：`protected`
- 首次版本：`11.0.0`

```gdscript
func _create_state_2d( _launch_input: GFProjectileLaunchInput2D, initial_body: GFProjectileBodyResult2D ) -> GFProjectileMotionState:
```

以初始二维 body 的基向量和当前配置计算并锁定本次 session 的 world-space 速度。 可选的方向单位化发生在局部方向转换之后；之后修改策略配置不会重算该状态的速度。

参数：

| 名称 | 说明 |
|---|---|
| `_launch_input` | 保留基类发射协议参数；直线策略不读取目标或其他发射输入。 |
| `initial_body` | 成功的初始 body 快照；开启局部方向时读取其 transform basis。 |

返回：保存锁定速度的 session 状态；body 失效或配置、转换后方向及速度非有限时返回 null。

<a id="member-gflinearprojectilemotion-methods-_create_state_3d"></a>

### `_create_state_3d`

- API：`protected`
- 首次版本：`11.0.0`

```gdscript
func _create_state_3d( _launch_input: GFProjectileLaunchInput3D, initial_body: GFProjectileBodyResult3D ) -> GFProjectileMotionState:
```

以初始三维 body 的基向量和当前配置计算并锁定本次 session 的 world-space 速度。 可选的方向单位化发生在局部方向转换之后；之后修改策略配置不会重算该状态的速度。

参数：

| 名称 | 说明 |
|---|---|
| `_launch_input` | 保留基类发射协议参数；直线策略不读取目标或其他发射输入。 |
| `initial_body` | 成功的初始 body 快照；开启局部方向时读取其 transform basis。 |

返回：保存锁定速度的 session 状态；body 失效或配置、转换后方向及速度非有限时返回 null。

<a id="member-gflinearprojectilemotion-methods-_compute_intent_2d"></a>

### `_compute_intent_2d`

- API：`protected`
- 首次版本：`11.0.0`

```gdscript
func _compute_intent_2d( state: GFProjectileMotionState, _current_body: GFProjectileBodyResult2D, delta: float ) -> GFProjectileMotionIntent2D:
```

将 session 已锁定的二维速度交给 intent 工厂，保持发射时确定的直线航向。 不重新读取策略配置，也不修改状态或 body。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 本策略创建的 session 状态；其他状态类型返回 invalid_motion_state。 |
| `_current_body` | 保留基类快照参数；本实现不依赖当前位置或朝向。 |
| `delta` | 原样传给 intent 工厂的帧秒数，必须非负且有限。 |

返回：锁定速度的 MOVE；状态失效或速度、时长及位移乘积非法时返回 REJECTED。

<a id="member-gflinearprojectilemotion-methods-_compute_intent_3d"></a>

### `_compute_intent_3d`

- API：`protected`
- 首次版本：`11.0.0`

```gdscript
func _compute_intent_3d( state: GFProjectileMotionState, _current_body: GFProjectileBodyResult3D, delta: float ) -> GFProjectileMotionIntent3D:
```

将 session 已锁定的三维速度交给 intent 工厂，保持发射时确定的直线航向。 不重新读取策略配置，也不修改状态或 body。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 本策略创建的 session 状态；其他状态类型返回 invalid_motion_state。 |
| `_current_body` | 保留基类快照参数；本实现不依赖当前位置或朝向。 |
| `delta` | 原样传给 intent 工厂的帧秒数，必须非负且有限。 |

返回：锁定速度的 MOVE；状态失效或速度、时长及位移乘积非法时返回 REJECTED。
