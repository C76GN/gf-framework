# GFProjectileDefinition2D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_definition_2d.gd`
- 模块：`Combat`
- 继承：`GFProjectileDefinition`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`11.0.0`

2D projectile typed 定义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`body_adapter`](#member-gfprojectiledefinition2d-properties-body_adapter) | `var body_adapter: GFProjectileBodyAdapter2D = null` |
| 方法 | [`bind_instance`](#member-gfprojectiledefinition2d-methods-bind_instance) | `func bind_instance(root: Node) -> GFProjectileBinding2D:` |

## 属性

<a id="member-gfprojectiledefinition2d-properties-body_adapter"></a>

### `body_adapter`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var body_adapter: GFProjectileBodyAdapter2D = null
```

驱动 2D root 的 body adapter。

## 方法

<a id="member-gfprojectiledefinition2d-methods-bind_instance"></a>

### `bind_instance`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func bind_instance(root: Node) -> GFProjectileBinding2D:
```

校验并绑定一个已进入 SceneTree 的完整 2D 实例。

参数：

| 名称 | 说明 |
|---|---|
| `root` | definition.scene 对应的完整实例 root。 |

返回：有效 topology snapshot 或带确定失败原因的 binding。
