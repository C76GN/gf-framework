# GFProjectileDefinition

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_definition.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`11.0.0`

projectile 场景、runtime 与策略的 typed 定义基类。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`scene`](#member-gfprojectiledefinition-properties-scene) | `var scene: PackedScene = null` |
| 属性 | [`runtime_path`](#member-gfprojectiledefinition-properties-runtime_path) | `var runtime_path: NodePath = NodePath("ProjectileRuntime")` |
| 属性 | [`impact_source_paths`](#member-gfprojectiledefinition-properties-impact_source_paths) | `var impact_source_paths: Array[NodePath] = []` |
| 属性 | [`motion`](#member-gfprojectiledefinition-properties-motion) | `var motion: GFProjectileMotion = null` |
| 属性 | [`lifetime_policy`](#member-gfprojectiledefinition-properties-lifetime_policy) | `var lifetime_policy: GFProjectileLifetimePolicy = null` |

## 属性

<a id="member-gfprojectiledefinition-properties-scene"></a>

### `scene`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var scene: PackedScene = null
```

可实例化的完整 projectile scene。

<a id="member-gfprojectiledefinition-properties-runtime_path"></a>

### `runtime_path`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var runtime_path: NodePath = NodePath("ProjectileRuntime")
```

scene root 到唯一 runtime 的显式路径。

<a id="member-gfprojectiledefinition-properties-impact_source_paths"></a>

### `impact_source_paths`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var impact_source_paths: Array[NodePath] = []
```

scene root 到 0..N impact source 的显式有序路径。

结构：

- `impact_source_paths`: Array[NodePath]，每项必须显式指向同维 GFHitBox2D/GFHitScan2D 或 GFHitBox3D/GFHitScan3D；不得重复、越过 root 或混用维度。

<a id="member-gfprojectiledefinition-properties-motion"></a>

### `motion`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var motion: GFProjectileMotion = null
```

每个 session 使用的 motion 策略。

<a id="member-gfprojectiledefinition-properties-lifetime_policy"></a>

### `lifetime_policy`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var lifetime_policy: GFProjectileLifetimePolicy = null
```

可选生命周期策略；null 表示不自动结束。
