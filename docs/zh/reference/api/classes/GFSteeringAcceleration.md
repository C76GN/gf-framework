# GFSteeringAcceleration

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_steering_acceleration.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

steering 计算输出的线性与角加速度。 作为纯数据对象在多个 steering 行为之间传递，不绑定节点或物理体。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`linear`](#member-gfsteeringacceleration-properties-linear) | `var linear: Vector3 = Vector3.ZERO` |
| 属性 | [`angular`](#member-gfsteeringacceleration-properties-angular) | `var angular: float = 0.0` |
| 方法 | [`clear`](#member-gfsteeringacceleration-methods-clear) | `func clear() -> GFSteeringAcceleration:` |
| 方法 | [`set_values`](#member-gfsteeringacceleration-methods-set_values) | `func set_values( linear_acceleration: Vector3, angular_acceleration: float = 0.0 ) -> GFSteeringAcceleration:` |
| 方法 | [`add_scaled`](#member-gfsteeringacceleration-methods-add_scaled) | `func add_scaled(other: GFSteeringAcceleration, weight: float = 1.0) -> GFSteeringAcceleration:` |
| 方法 | [`clamp_to`](#member-gfsteeringacceleration-methods-clamp_to) | `func clamp_to(max_linear: float = -1.0, max_angular: float = -1.0) -> GFSteeringAcceleration:` |
| 方法 | [`is_zero`](#member-gfsteeringacceleration-methods-is_zero) | `func is_zero(threshold: float = 0.001) -> bool:` |
| 方法 | [`duplicate_acceleration`](#member-gfsteeringacceleration-methods-duplicate_acceleration) | `func duplicate_acceleration() -> GFSteeringAcceleration:` |

## 属性

<a id="member-gfsteeringacceleration-properties-linear"></a>

### `linear`

- API：`public`

```gdscript
var linear: Vector3 = Vector3.ZERO
```

线性加速度。

<a id="member-gfsteeringacceleration-properties-angular"></a>

### `angular`

- API：`public`

```gdscript
var angular: float = 0.0
```

角加速度。

## 方法

<a id="member-gfsteeringacceleration-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> GFSteeringAcceleration:
```

清零加速度。

返回：当前实例。

<a id="member-gfsteeringacceleration-methods-set_values"></a>

### `set_values`

- API：`public`

```gdscript
func set_values( linear_acceleration: Vector3, angular_acceleration: float = 0.0 ) -> GFSteeringAcceleration:
```

写入加速度值。

参数：

| 名称 | 说明 |
|---|---|
| `linear_acceleration` | 线性加速度。 |
| `angular_acceleration` | 角加速度。 |

返回：当前实例。

<a id="member-gfsteeringacceleration-methods-add_scaled"></a>

### `add_scaled`

- API：`public`

```gdscript
func add_scaled(other: GFSteeringAcceleration, weight: float = 1.0) -> GFSteeringAcceleration:
```

按权重叠加另一个加速度。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 另一个加速度。 |
| `weight` | 权重。 |

返回：当前实例。

<a id="member-gfsteeringacceleration-methods-clamp_to"></a>

### `clamp_to`

- API：`public`

```gdscript
func clamp_to(max_linear: float = -1.0, max_angular: float = -1.0) -> GFSteeringAcceleration:
```

按上限裁剪加速度。

参数：

| 名称 | 说明 |
|---|---|
| `max_linear` | 最大线性加速度；小于 0 时不限制。 |
| `max_angular` | 最大角加速度；小于 0 时不限制。 |

返回：当前实例。

<a id="member-gfsteeringacceleration-methods-is_zero"></a>

### `is_zero`

- API：`public`

```gdscript
func is_zero(threshold: float = 0.001) -> bool:
```

判断加速度是否接近零。

参数：

| 名称 | 说明 |
|---|---|
| `threshold` | 零阈值。 |

返回：接近零返回 true。

<a id="member-gfsteeringacceleration-methods-duplicate_acceleration"></a>

### `duplicate_acceleration`

- API：`public`

```gdscript
func duplicate_acceleration() -> GFSteeringAcceleration:
```

创建深拷贝。

返回：新加速度对象。
