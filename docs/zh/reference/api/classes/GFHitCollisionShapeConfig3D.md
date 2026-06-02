# GFHitCollisionShapeConfig3D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/hit_detection/gf_hit_collision_shape_config_3d.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

3D 命中区域碰撞形状配置。 用于把可复用的 Shape3D、偏移、旋转、缩放、调试颜色和禁用状态应用到 HitBox / HurtBox 自动生成的 CollisionShape3D 上。不表达伤害、阵营或其他玩法规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`shape`](#member-gfhitcollisionshapeconfig3d-properties-shape) | `var shape: Shape3D = null` |
| 属性 | [`position`](#member-gfhitcollisionshapeconfig3d-properties-position) | `var position: Vector3 = Vector3.ZERO` |
| 属性 | [`rotation_degrees`](#member-gfhitcollisionshapeconfig3d-properties-rotation_degrees) | `var rotation_degrees: Vector3 = Vector3.ZERO` |
| 属性 | [`scale`](#member-gfhitcollisionshapeconfig3d-properties-scale) | `var scale: Vector3 = Vector3.ONE` |
| 属性 | [`debug_color`](#member-gfhitcollisionshapeconfig3d-properties-debug_color) | `var debug_color: Color = Color(0.0, 0.0, 0.0, 0.0)` |
| 属性 | [`disabled`](#member-gfhitcollisionshapeconfig3d-properties-disabled) | `var disabled: bool = false` |
| 方法 | [`apply_to`](#member-gfhitcollisionshapeconfig3d-methods-apply_to) | `func apply_to(collision_shape: CollisionShape3D) -> bool:` |
| 方法 | [`instantiate_collision_shape`](#member-gfhitcollisionshapeconfig3d-methods-instantiate_collision_shape) | `func instantiate_collision_shape() -> CollisionShape3D:` |

## 属性

<a id="member-gfhitcollisionshapeconfig3d-properties-shape"></a>

### `shape`

- API：`public`

```gdscript
var shape: Shape3D = null
```

要应用的 Godot 3D 碰撞形状。

<a id="member-gfhitcollisionshapeconfig3d-properties-position"></a>

### `position`

- API：`public`

```gdscript
var position: Vector3 = Vector3.ZERO
```

碰撞形状相对 HitBox / HurtBox 节点的位置。

<a id="member-gfhitcollisionshapeconfig3d-properties-rotation_degrees"></a>

### `rotation_degrees`

- API：`public`

```gdscript
var rotation_degrees: Vector3 = Vector3.ZERO
```

碰撞形状相对 HitBox / HurtBox 节点的旋转角度。

<a id="member-gfhitcollisionshapeconfig3d-properties-scale"></a>

### `scale`

- API：`public`

```gdscript
var scale: Vector3 = Vector3.ONE
```

碰撞形状相对 HitBox / HurtBox 节点的缩放。

<a id="member-gfhitcollisionshapeconfig3d-properties-debug_color"></a>

### `debug_color`

- API：`public`

```gdscript
var debug_color: Color = Color(0.0, 0.0, 0.0, 0.0)
```

调试绘制颜色。透明色会沿用 Godot 默认调试显示。

<a id="member-gfhitcollisionshapeconfig3d-properties-disabled"></a>

### `disabled`

- API：`public`

```gdscript
var disabled: bool = false
```

是否禁用生成的 CollisionShape3D。

## 方法

<a id="member-gfhitcollisionshapeconfig3d-methods-apply_to"></a>

### `apply_to`

- API：`public`

```gdscript
func apply_to(collision_shape: CollisionShape3D) -> bool:
```

将配置应用到指定 CollisionShape3D。

参数：

| 名称 | 说明 |
|---|---|
| `collision_shape` | 目标 CollisionShape3D。 |

返回：应用成功返回 true。

<a id="member-gfhitcollisionshapeconfig3d-methods-instantiate_collision_shape"></a>

### `instantiate_collision_shape`

- API：`public`

```gdscript
func instantiate_collision_shape() -> CollisionShape3D:
```

创建一个已应用当前配置的 CollisionShape3D。

返回：创建成功返回 CollisionShape3D；配置缺少 shape 时返回 null。
