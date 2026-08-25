# GFProjectileBinding3D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_binding_3d.gd`
- 模块：`Combat`
- 继承：`GFProjectileBinding`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

3D projectile 的 typed 拓扑快照。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_definition`](#member-gfprojectilebinding3d-methods-get_definition) | `func get_definition() -> GFProjectileDefinition3D:` |
| 方法 | [`get_instance_root`](#member-gfprojectilebinding3d-methods-get_instance_root) | `func get_instance_root() -> Node3D:` |
| 方法 | [`get_runtime`](#member-gfprojectilebinding3d-methods-get_runtime) | `func get_runtime() -> GFProjectile3D:` |
| 方法 | [`get_body_adapter`](#member-gfprojectilebinding3d-methods-get_body_adapter) | `func get_body_adapter() -> GFProjectileBodyAdapter3D:` |

## 方法

<a id="member-gfprojectilebinding3d-methods-get_definition"></a>

### `get_definition`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_definition() -> GFProjectileDefinition3D:
```

返回创建本快照的 3D definition。

返回：3D definition；准入前失败时可能为 null。

<a id="member-gfprojectilebinding3d-methods-get_instance_root"></a>

### `get_instance_root`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_instance_root() -> Node3D:
```

返回绑定的完整 3D 实例根节点。

返回：live Node3D root；已释放时返回 null。

<a id="member-gfprojectilebinding3d-methods-get_runtime"></a>

### `get_runtime`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_runtime() -> GFProjectile3D:
```

返回唯一 3D runtime 节点。

返回：live GFProjectile3D；已释放时返回 null。

<a id="member-gfprojectilebinding3d-methods-get_body_adapter"></a>

### `get_body_adapter`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_body_adapter() -> GFProjectileBodyAdapter3D:
```

返回冻结的 3D body adapter。

返回：绑定准入时的 GFProjectileBodyAdapter3D。
