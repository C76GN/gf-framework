# GFProjectileCatalogEntry

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_catalog_entry.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

发射体目录中的单个场景映射。 只把稳定 ID 映射到 PackedScene，不解释该场景的玩法含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`projectile_id`](#member-gfprojectilecatalogentry-properties-projectile_id) | `var projectile_id: StringName = &""` |
| 属性 | [`scene`](#member-gfprojectilecatalogentry-properties-scene) | `var scene: PackedScene = null` |
| 方法 | [`is_valid_entry`](#member-gfprojectilecatalogentry-methods-is_valid_entry) | `func is_valid_entry() -> bool:` |

## 属性

<a id="member-gfprojectilecatalogentry-properties-projectile_id"></a>

### `projectile_id`

- API：`public`

```gdscript
var projectile_id: StringName = &""
```

发射体 ID。

<a id="member-gfprojectilecatalogentry-properties-scene"></a>

### `scene`

- API：`public`

```gdscript
var scene: PackedScene = null
```

发射体场景。

## 方法

<a id="member-gfprojectilecatalogentry-methods-is_valid_entry"></a>

### `is_valid_entry`

- API：`public`

```gdscript
func is_valid_entry() -> bool:
```

检查条目是否可用于实例化。

返回：ID 和场景都有效时返回 true。
