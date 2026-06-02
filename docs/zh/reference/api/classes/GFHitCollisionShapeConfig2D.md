# GFHitCollisionShapeConfig2D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/hit_detection/gf_hit_collision_shape_config_2d.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

2D 命中区域碰撞形状配置。 用于把可复用的 Shape2D、偏移、旋转、缩放、调试颜色和禁用状态应用到 HitBox / HurtBox 自动生成的 CollisionShape2D 上。不表达伤害、阵营或其他玩法规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`shape`](#member-gfhitcollisionshapeconfig2d-properties-shape) | `var shape: Shape2D = null` |
| 属性 | [`position`](#member-gfhitcollisionshapeconfig2d-properties-position) | `var position: Vector2 = Vector2.ZERO` |
| 属性 | [`rotation_degrees`](#member-gfhitcollisionshapeconfig2d-properties-rotation_degrees) | `var rotation_degrees: float = 0.0` |
| 属性 | [`scale`](#member-gfhitcollisionshapeconfig2d-properties-scale) | `var scale: Vector2 = Vector2.ONE` |
| 属性 | [`debug_color`](#member-gfhitcollisionshapeconfig2d-properties-debug_color) | `var debug_color: Color = Color(0.0, 0.0, 0.0, 0.0)` |
| 属性 | [`disabled`](#member-gfhitcollisionshapeconfig2d-properties-disabled) | `var disabled: bool = false` |
| 方法 | [`apply_to`](#member-gfhitcollisionshapeconfig2d-methods-apply_to) | `func apply_to(collision_shape: CollisionShape2D) -> bool:` |
| 方法 | [`instantiate_collision_shape`](#member-gfhitcollisionshapeconfig2d-methods-instantiate_collision_shape) | `func instantiate_collision_shape() -> CollisionShape2D:` |

## 属性

<a id="member-gfhitcollisionshapeconfig2d-properties-shape"></a>

### `shape`

- API：`public`

```gdscript
var shape: Shape2D = null
```

要应用的 Godot 2D 碰撞形状。

<a id="member-gfhitcollisionshapeconfig2d-properties-position"></a>

### `position`

- API：`public`

```gdscript
var position: Vector2 = Vector2.ZERO
```

碰撞形状相对 HitBox / HurtBox 节点的位置。

<a id="member-gfhitcollisionshapeconfig2d-properties-rotation_degrees"></a>

### `rotation_degrees`

- API：`public`

```gdscript
var rotation_degrees: float = 0.0
```

碰撞形状相对 HitBox / HurtBox 节点的旋转角度。

<a id="member-gfhitcollisionshapeconfig2d-properties-scale"></a>

### `scale`

- API：`public`

```gdscript
var scale: Vector2 = Vector2.ONE
```

碰撞形状相对 HitBox / HurtBox 节点的缩放。

<a id="member-gfhitcollisionshapeconfig2d-properties-debug_color"></a>

### `debug_color`

- API：`public`

```gdscript
var debug_color: Color = Color(0.0, 0.0, 0.0, 0.0)
```

调试绘制颜色。透明色会沿用 Godot 默认调试显示。

<a id="member-gfhitcollisionshapeconfig2d-properties-disabled"></a>

### `disabled`

- API：`public`

```gdscript
var disabled: bool = false
```

是否禁用生成的 CollisionShape2D。

## 方法

<a id="member-gfhitcollisionshapeconfig2d-methods-apply_to"></a>

### `apply_to`

- API：`public`

```gdscript
func apply_to(collision_shape: CollisionShape2D) -> bool:
```

将配置应用到指定 CollisionShape2D。

参数：

| 名称 | 说明 |
|---|---|
| `collision_shape` | 目标 CollisionShape2D。 |

返回：应用成功返回 true。

<a id="member-gfhitcollisionshapeconfig2d-methods-instantiate_collision_shape"></a>

### `instantiate_collision_shape`

- API：`public`

```gdscript
func instantiate_collision_shape() -> CollisionShape2D:
```

创建一个已应用当前配置的 CollisionShape2D。

返回：创建成功返回 CollisionShape2D；配置缺少 shape 时返回 null。
