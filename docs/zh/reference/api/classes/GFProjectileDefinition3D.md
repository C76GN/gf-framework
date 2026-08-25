# GFProjectileDefinition3D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_definition_3d.gd`
- 模块：`Combat`
- 继承：`GFProjectileDefinition`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`unreleased`

3D projectile typed 定义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`body_adapter`](#member-gfprojectiledefinition3d-properties-body_adapter) | `var body_adapter: GFProjectileBodyAdapter3D = null` |
| 方法 | [`bind_instance`](#member-gfprojectiledefinition3d-methods-bind_instance) | `func bind_instance(root: Node) -> GFProjectileBinding3D:` |

## 属性

<a id="member-gfprojectiledefinition3d-properties-body_adapter"></a>

### `body_adapter`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var body_adapter: GFProjectileBodyAdapter3D = null
```

驱动 3D root 的 body adapter。

## 方法

<a id="member-gfprojectiledefinition3d-methods-bind_instance"></a>

### `bind_instance`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func bind_instance(root: Node) -> GFProjectileBinding3D:
```

校验并绑定一个已进入 SceneTree 的完整 3D 实例。

参数：

| 名称 | 说明 |
|---|---|
| `root` | definition.scene 对应的完整实例 root。 |

返回：有效 topology snapshot 或带确定失败原因的 binding。
