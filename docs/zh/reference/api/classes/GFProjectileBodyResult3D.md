# GFProjectileBodyResult3D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_body_result_3d.gd`
- 模块：`Combat`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`11.0.0`

3D body adapter 的捕获或应用结果。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`successful`](#member-gfprojectilebodyresult3d-methods-successful) | `static func successful( transform_value: Transform3D, actual_displacement: Vector3 = Vector3.ZERO ) -> GFProjectileBodyResult3D:` |
| 方法 | [`failed`](#member-gfprojectilebodyresult3d-methods-failed) | `static func failed( reason: StringName, transform_value: Transform3D = Transform3D.IDENTITY ) -> GFProjectileBodyResult3D:` |
| 方法 | [`is_successful`](#member-gfprojectilebodyresult3d-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_failure_reason`](#member-gfprojectilebodyresult3d-methods-get_failure_reason) | `func get_failure_reason() -> StringName:` |
| 方法 | [`get_transform`](#member-gfprojectilebodyresult3d-methods-get_transform) | `func get_transform() -> Transform3D:` |
| 方法 | [`get_position`](#member-gfprojectilebodyresult3d-methods-get_position) | `func get_position() -> Vector3:` |
| 方法 | [`get_actual_displacement`](#member-gfprojectilebodyresult3d-methods-get_actual_displacement) | `func get_actual_displacement() -> Vector3:` |

## 方法

<a id="member-gfprojectilebodyresult3d-methods-successful"></a>

### `successful`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
static func successful( transform_value: Transform3D, actual_displacement: Vector3 = Vector3.ZERO ) -> GFProjectileBodyResult3D:
```

构造成功的 3D body 结果。

参数：

| 名称 | 说明 |
|---|---|
| `transform_value` | 应用后的 world transform。 |
| `actual_displacement` | 本次操作产生的真实 world displacement。 |

返回：成功结果。

<a id="member-gfprojectilebodyresult3d-methods-failed"></a>

### `failed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
static func failed( reason: StringName, transform_value: Transform3D = Transform3D.IDENTITY ) -> GFProjectileBodyResult3D:
```

构造失败的 3D body 结果。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 非空失败原因。 |
| `transform_value` | 失败边界观测到的 transform。 |

返回：失败结果。

<a id="member-gfprojectilebodyresult3d-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_successful() -> bool:
```

返回 body 操作是否成功。

返回：成功时为 true。

<a id="member-gfprojectilebodyresult3d-methods-get_failure_reason"></a>

### `get_failure_reason`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_failure_reason() -> StringName:
```

返回失败原因。

返回：成功结果为空，失败结果为稳定原因。

<a id="member-gfprojectilebodyresult3d-methods-get_transform"></a>

### `get_transform`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_transform() -> Transform3D:
```

返回操作后的 world transform。

返回：3D transform 快照。

<a id="member-gfprojectilebodyresult3d-methods-get_position"></a>

### `get_position`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_position() -> Vector3:
```

返回 transform 的 world position。

返回：3D world position。

<a id="member-gfprojectilebodyresult3d-methods-get_actual_displacement"></a>

### `get_actual_displacement`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_actual_displacement() -> Vector3:
```

返回本次操作实际产生的 world displacement。

返回：真实位移向量；捕获或停止操作为零。
