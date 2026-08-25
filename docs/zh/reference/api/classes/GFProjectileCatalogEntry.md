# GFProjectileCatalogEntry

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_catalog_entry.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

稳定 ID 到 typed projectile definition 的映射。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`projectile_id`](#member-gfprojectilecatalogentry-properties-projectile_id) | `var projectile_id: StringName = &""` |
| 属性 | [`definition`](#member-gfprojectilecatalogentry-properties-definition) | `var definition: GFProjectileDefinition = null` |
| 方法 | [`is_valid_entry`](#member-gfprojectilecatalogentry-methods-is_valid_entry) | `func is_valid_entry() -> bool:` |

## 属性

<a id="member-gfprojectilecatalogentry-properties-projectile_id"></a>

### `projectile_id`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var projectile_id: StringName = &""
```

definition 的稳定目录 ID。

<a id="member-gfprojectilecatalogentry-properties-definition"></a>

### `definition`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var definition: GFProjectileDefinition = null
```

与 ID 关联的 typed projectile definition。

## 方法

<a id="member-gfprojectilecatalogentry-methods-is_valid_entry"></a>

### `is_valid_entry`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func is_valid_entry() -> bool:
```

判断条目是否可参与目录查找。

返回：ID 非空且 definition 非 null 时为 true。
