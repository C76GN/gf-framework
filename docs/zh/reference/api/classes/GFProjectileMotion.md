# GFProjectileMotion

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_motion.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

以 per-session state 计算 typed intent 的移动策略基类。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`create_state_2d`](#member-gfprojectilemotion-methods-create_state_2d) | `func create_state_2d( launch_input: GFProjectileLaunchInput2D, initial_body: GFProjectileBodyResult2D ) -> GFProjectileMotionState:` |
| 方法 | [`create_state_3d`](#member-gfprojectilemotion-methods-create_state_3d) | `func create_state_3d( launch_input: GFProjectileLaunchInput3D, initial_body: GFProjectileBodyResult3D ) -> GFProjectileMotionState:` |
| 方法 | [`compute_intent_2d`](#member-gfprojectilemotion-methods-compute_intent_2d) | `func compute_intent_2d( state: GFProjectileMotionState, current_body: GFProjectileBodyResult2D, delta: float ) -> GFProjectileMotionIntent2D:` |
| 方法 | [`compute_intent_3d`](#member-gfprojectilemotion-methods-compute_intent_3d) | `func compute_intent_3d( state: GFProjectileMotionState, current_body: GFProjectileBodyResult3D, delta: float ) -> GFProjectileMotionIntent3D:` |
| 方法 | [`_create_state_2d`](#member-gfprojectilemotion-methods-_create_state_2d) | `func _create_state_2d( _launch_input: GFProjectileLaunchInput2D, _initial_body: GFProjectileBodyResult2D ) -> Variant:` |
| 方法 | [`_create_state_3d`](#member-gfprojectilemotion-methods-_create_state_3d) | `func _create_state_3d( _launch_input: GFProjectileLaunchInput3D, _initial_body: GFProjectileBodyResult3D ) -> Variant:` |
| 方法 | [`_compute_intent_2d`](#member-gfprojectilemotion-methods-_compute_intent_2d) | `func _compute_intent_2d( _state: GFProjectileMotionState, _current_body: GFProjectileBodyResult2D, _delta: float ) -> Variant:` |
| 方法 | [`_compute_intent_3d`](#member-gfprojectilemotion-methods-_compute_intent_3d) | `func _compute_intent_3d( _state: GFProjectileMotionState, _current_body: GFProjectileBodyResult3D, _delta: float ) -> Variant:` |

## 方法

<a id="member-gfprojectilemotion-methods-create_state_2d"></a>

### `create_state_2d`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func create_state_2d( launch_input: GFProjectileLaunchInput2D, initial_body: GFProjectileBodyResult2D ) -> GFProjectileMotionState:
```

为一次 2D session 创建私有 motion state。

参数：

| 名称 | 说明 |
|---|---|
| `launch_input` | 已冻结的 2D 发射输入。 |
| `initial_body` | reserve 阶段捕获的初始 body 快照。 |

返回：仅供该 session 使用的 state；拒绝时返回 null。

<a id="member-gfprojectilemotion-methods-create_state_3d"></a>

### `create_state_3d`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func create_state_3d( launch_input: GFProjectileLaunchInput3D, initial_body: GFProjectileBodyResult3D ) -> GFProjectileMotionState:
```

为一次 3D session 创建私有 motion state。

参数：

| 名称 | 说明 |
|---|---|
| `launch_input` | 已冻结的 3D 发射输入。 |
| `initial_body` | reserve 阶段捕获的初始 body 快照。 |

返回：仅供该 session 使用的 state；拒绝时返回 null。

<a id="member-gfprojectilemotion-methods-compute_intent_2d"></a>

### `compute_intent_2d`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func compute_intent_2d( state: GFProjectileMotionState, current_body: GFProjectileBodyResult2D, delta: float ) -> GFProjectileMotionIntent2D:
```

根据 state 与当前 body 快照计算 2D intent，不直接修改 root。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 当前 session 私有 state。 |
| `current_body` | 当前 body 快照。 |
| `delta` | 本帧秒数。 |

返回：typed 2D intent。

<a id="member-gfprojectilemotion-methods-compute_intent_3d"></a>

### `compute_intent_3d`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func compute_intent_3d( state: GFProjectileMotionState, current_body: GFProjectileBodyResult3D, delta: float ) -> GFProjectileMotionIntent3D:
```

根据 state 与当前 body 快照计算 3D intent，不直接修改 root。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 当前 session 私有 state。 |
| `current_body` | 当前 body 快照。 |
| `delta` | 本帧秒数。 |

返回：typed 3D intent。

<a id="member-gfprojectilemotion-methods-_create_state_2d"></a>

### `_create_state_2d`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _create_state_2d( _launch_input: GFProjectileLaunchInput2D, _initial_body: GFProjectileBodyResult2D ) -> Variant:
```

实现 2D state 创建策略。

参数：

| 名称 | 说明 |
|---|---|
| `_launch_input` | 已冻结的发射输入。 |
| `_initial_body` | 初始 body 快照。 |

返回：session 私有 state。

结构：

- `return`: Variant，必须为 live `GFProjectileMotionState`。

<a id="member-gfprojectilemotion-methods-_create_state_3d"></a>

### `_create_state_3d`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _create_state_3d( _launch_input: GFProjectileLaunchInput3D, _initial_body: GFProjectileBodyResult3D ) -> Variant:
```

实现 3D state 创建策略。

参数：

| 名称 | 说明 |
|---|---|
| `_launch_input` | 已冻结的发射输入。 |
| `_initial_body` | 初始 body 快照。 |

返回：session 私有 state。

结构：

- `return`: Variant，必须为 live `GFProjectileMotionState`。

<a id="member-gfprojectilemotion-methods-_compute_intent_2d"></a>

### `_compute_intent_2d`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _compute_intent_2d( _state: GFProjectileMotionState, _current_body: GFProjectileBodyResult2D, _delta: float ) -> Variant:
```

实现 2D intent 计算策略。

参数：

| 名称 | 说明 |
|---|---|
| `_state` | session 私有 state。 |
| `_current_body` | 当前 body 快照。 |
| `_delta` | 本帧秒数。 |

返回：typed 2D intent。

结构：

- `return`: Variant，必须为 live `GFProjectileMotionIntent2D`。

<a id="member-gfprojectilemotion-methods-_compute_intent_3d"></a>

### `_compute_intent_3d`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _compute_intent_3d( _state: GFProjectileMotionState, _current_body: GFProjectileBodyResult3D, _delta: float ) -> Variant:
```

实现 3D intent 计算策略。

参数：

| 名称 | 说明 |
|---|---|
| `_state` | session 私有 state。 |
| `_current_body` | 当前 body 快照。 |
| `_delta` | 本帧秒数。 |

返回：typed 3D intent。

结构：

- `return`: Variant，必须为 live `GFProjectileMotionIntent3D`。
