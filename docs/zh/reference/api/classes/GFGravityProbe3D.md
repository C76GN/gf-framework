# GFGravityProbe3D

[API Reference](../index.md) / [Physics](../extensions-physics.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/physics/nodes/gf_gravity_probe_3d.gd`
- 模块：`Physics`
- 继承：`Node3D`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用 3D 重力采样器。 从场景树分组中采样 GFGravityField3D 或任何暴露 get_acceleration_at() 方法的对象，并汇总为当前节点位置处的加速度、上下方向。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`field_group`](#member-gfgravityprobe3d-properties-field_group) | `var field_group: StringName = &"gf_gravity_field_3d"` |
| 属性 | [`use_fallback_when_empty`](#member-gfgravityprobe3d-properties-use_fallback_when_empty) | `var use_fallback_when_empty: bool = true` |
| 属性 | [`fallback_acceleration`](#member-gfgravityprobe3d-properties-fallback_acceleration) | `var fallback_acceleration: Vector3 = Vector3.DOWN * 9.8` |
| 属性 | [`cache_samples_per_frame`](#member-gfgravityprobe3d-properties-cache_samples_per_frame) | `var cache_samples_per_frame: bool = true` |
| 属性 | [`last_acceleration`](#member-gfgravityprobe3d-properties-last_acceleration) | `var last_acceleration: Vector3 = Vector3.ZERO` |
| 方法 | [`sample`](#member-gfgravityprobe3d-methods-sample) | `func sample() -> Vector3:` |
| 方法 | [`sample_fields`](#member-gfgravityprobe3d-methods-sample_fields) | `func sample_fields(fields: Array) -> Vector3:` |
| 方法 | [`get_down_direction`](#member-gfgravityprobe3d-methods-get_down_direction) | `func get_down_direction() -> Vector3:` |
| 方法 | [`get_up_direction`](#member-gfgravityprobe3d-methods-get_up_direction) | `func get_up_direction() -> Vector3:` |

## 属性

<a id="member-gfgravityprobe3d-properties-field_group"></a>

### `field_group`

- API：`public`

```gdscript
var field_group: StringName = &"gf_gravity_field_3d"
```

要采样的力场分组。

<a id="member-gfgravityprobe3d-properties-use_fallback_when_empty"></a>

### `use_fallback_when_empty`

- API：`public`

```gdscript
var use_fallback_when_empty: bool = true
```

找不到力场时是否返回 fallback_acceleration。

<a id="member-gfgravityprobe3d-properties-fallback_acceleration"></a>

### `fallback_acceleration`

- API：`public`

```gdscript
var fallback_acceleration: Vector3 = Vector3.DOWN * 9.8
```

找不到力场时使用的默认加速度。

<a id="member-gfgravityprobe3d-properties-cache_samples_per_frame"></a>

### `cache_samples_per_frame`

- API：`public`

```gdscript
var cache_samples_per_frame: bool = true
```

同一帧、同一位置重复 sample() 时是否复用上次结果。

<a id="member-gfgravityprobe3d-properties-last_acceleration"></a>

### `last_acceleration`

- API：`public`

```gdscript
var last_acceleration: Vector3 = Vector3.ZERO
```

最近一次 sample() 得到的加速度。

## 方法

<a id="member-gfgravityprobe3d-methods-sample"></a>

### `sample`

- API：`public`

```gdscript
func sample() -> Vector3:
```

采样场景树分组中的所有力场。

返回：汇总后的加速度。

<a id="member-gfgravityprobe3d-methods-sample_fields"></a>

### `sample_fields`

- API：`public`

```gdscript
func sample_fields(fields: Array) -> Vector3:
```

采样指定力场列表。

参数：

| 名称 | 说明 |
|---|---|
| `fields` | 力场对象列表。 |

返回：汇总后的加速度。

结构：

- `fields`: Array，包含 GFGravityField3D 或任何暴露 get_acceleration_at(Vector3) 的 Object。

<a id="member-gfgravityprobe3d-methods-get_down_direction"></a>

### `get_down_direction`

- API：`public`

```gdscript
func get_down_direction() -> Vector3:
```

获取当前位置的向下方向。

返回：向下方向。

<a id="member-gfgravityprobe3d-methods-get_up_direction"></a>

### `get_up_direction`

- API：`public`

```gdscript
func get_up_direction() -> Vector3:
```

获取当前位置的向上方向。

返回：向上方向。
