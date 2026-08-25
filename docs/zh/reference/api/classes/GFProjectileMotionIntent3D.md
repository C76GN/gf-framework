# GFProjectileMotionIntent3D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_motion_intent_3d.gd`
- 模块：`Combat`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

3D 移动策略的不可变输出。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Kind`](#member-gfprojectilemotionintent3d-enums-kind) | `enum Kind` |
| 方法 | [`move`](#member-gfprojectilemotionintent3d-methods-move) | `static func move(velocity: Vector3, delta_seconds: float) -> GFProjectileMotionIntent3D:` |
| 方法 | [`rejected`](#member-gfprojectilemotionintent3d-methods-rejected) | `static func rejected(reason: StringName) -> GFProjectileMotionIntent3D:` |
| 方法 | [`finish`](#member-gfprojectilemotionintent3d-methods-finish) | `static func finish() -> GFProjectileMotionIntent3D:` |
| 方法 | [`get_kind`](#member-gfprojectilemotionintent3d-methods-get_kind) | `func get_kind() -> Kind:` |
| 方法 | [`get_velocity`](#member-gfprojectilemotionintent3d-methods-get_velocity) | `func get_velocity() -> Vector3:` |
| 方法 | [`get_delta_seconds`](#member-gfprojectilemotionintent3d-methods-get_delta_seconds) | `func get_delta_seconds() -> float:` |
| 方法 | [`get_failure_reason`](#member-gfprojectilemotionintent3d-methods-get_failure_reason) | `func get_failure_reason() -> StringName:` |
| 方法 | [`is_valid`](#member-gfprojectilemotionintent3d-methods-is_valid) | `func is_valid() -> bool:` |

## 枚举

<a id="member-gfprojectilemotionintent3d-enums-kind"></a>

### `Kind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Kind {
	## 未配置 intent。
	NONE = 0,
	## 请求按 world-space 速度移动。
	MOVE = 1,
	## 策略拒绝产生可应用 intent。
	REJECTED = 2,
	## 策略正常请求结束当前 session。
	FINISH = 3,
}
```

定义 motion 计算的封闭输出种类。

## 方法

<a id="member-gfprojectilemotionintent3d-methods-move"></a>

### `move`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func move(velocity: Vector3, delta_seconds: float) -> GFProjectileMotionIntent3D:
```

构造 world-space MOVE intent。

参数：

| 名称 | 说明 |
|---|---|
| `velocity` | world-space 速度。 |
| `delta_seconds` | 本 intent 对应的非负帧时长。 |

返回：velocity、delta 或位移乘积非法时返回 REJECTED，否则返回 MOVE intent。

<a id="member-gfprojectilemotionintent3d-methods-rejected"></a>

### `rejected`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func rejected(reason: StringName) -> GFProjectileMotionIntent3D:
```

构造被策略拒绝的 intent。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 稳定失败原因。 |

返回：REJECTED intent。

<a id="member-gfprojectilemotionintent3d-methods-finish"></a>

### `finish`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func finish() -> GFProjectileMotionIntent3D:
```

构造正常结束当前 session 的 FINISH intent。

返回：不交给 body adapter 的 FINISH intent。

<a id="member-gfprojectilemotionintent3d-methods-get_kind"></a>

### `get_kind`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_kind() -> Kind:
```

返回 intent 种类。

返回：封闭 `Kind` 值。

<a id="member-gfprojectilemotionintent3d-methods-get_velocity"></a>

### `get_velocity`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_velocity() -> Vector3:
```

返回 MOVE 的 world-space 速度。

返回：3D world-space velocity。

<a id="member-gfprojectilemotionintent3d-methods-get_delta_seconds"></a>

### `get_delta_seconds`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_delta_seconds() -> float:
```

返回 MOVE 对应的帧时长。

返回：非负秒数。

<a id="member-gfprojectilemotionintent3d-methods-get_failure_reason"></a>

### `get_failure_reason`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_failure_reason() -> StringName:
```

返回 REJECTED 原因。

返回：REJECTED 时为非空稳定原因。

<a id="member-gfprojectilemotionintent3d-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_valid() -> bool:
```

返回 intent 是否为 runtime 可处理的非拒绝输出。

返回：NONE、MOVE 或 FINISH 时为 true。
