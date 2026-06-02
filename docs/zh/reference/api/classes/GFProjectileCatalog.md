# GFProjectileCatalog

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_catalog.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

发射体场景目录。 用稳定 ID 管理 PackedScene，供发射器、技能或项目自己的生成流程复用。 目录不规定发射体的伤害、阵营、消耗或命中特效。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`entries`](#member-gfprojectilecatalog-properties-entries) | `var entries: Array[GFProjectileCatalogEntry] = []` |
| 方法 | [`set_scene`](#member-gfprojectilecatalog-methods-set_scene) | `func set_scene(projectile_id: StringName, scene: PackedScene) -> void:` |
| 方法 | [`get_scene`](#member-gfprojectilecatalog-methods-get_scene) | `func get_scene(projectile_id: StringName) -> PackedScene:` |
| 方法 | [`remove_scene`](#member-gfprojectilecatalog-methods-remove_scene) | `func remove_scene(projectile_id: StringName) -> bool:` |
| 方法 | [`has_scene`](#member-gfprojectilecatalog-methods-has_scene) | `func has_scene(projectile_id: StringName) -> bool:` |
| 方法 | [`get_projectile_ids`](#member-gfprojectilecatalog-methods-get_projectile_ids) | `func get_projectile_ids() -> PackedStringArray:` |
| 方法 | [`prune_invalid_entries`](#member-gfprojectilecatalog-methods-prune_invalid_entries) | `func prune_invalid_entries() -> int:` |

## 属性

<a id="member-gfprojectilecatalog-properties-entries"></a>

### `entries`

- API：`public`

```gdscript
var entries: Array[GFProjectileCatalogEntry] = []
```

发射体场景条目列表。

## 方法

<a id="member-gfprojectilecatalog-methods-set_scene"></a>

### `set_scene`

- API：`public`

```gdscript
func set_scene(projectile_id: StringName, scene: PackedScene) -> void:
```

设置或替换一个发射体场景。

参数：

| 名称 | 说明 |
|---|---|
| `projectile_id` | 发射体 ID。 |
| `scene` | 发射体场景；为 null 时移除该 ID。 |

<a id="member-gfprojectilecatalog-methods-get_scene"></a>

### `get_scene`

- API：`public`

```gdscript
func get_scene(projectile_id: StringName) -> PackedScene:
```

获取指定 ID 的发射体场景。

参数：

| 名称 | 说明 |
|---|---|
| `projectile_id` | 发射体 ID。 |

返回：找到时返回 PackedScene，否则返回 null。

<a id="member-gfprojectilecatalog-methods-remove_scene"></a>

### `remove_scene`

- API：`public`

```gdscript
func remove_scene(projectile_id: StringName) -> bool:
```

移除指定 ID 的发射体场景。

参数：

| 名称 | 说明 |
|---|---|
| `projectile_id` | 发射体 ID。 |

返回：移除成功返回 true。

<a id="member-gfprojectilecatalog-methods-has_scene"></a>

### `has_scene`

- API：`public`

```gdscript
func has_scene(projectile_id: StringName) -> bool:
```

检查指定 ID 是否存在有效场景。

参数：

| 名称 | 说明 |
|---|---|
| `projectile_id` | 发射体 ID。 |

返回：存在有效场景时返回 true。

<a id="member-gfprojectilecatalog-methods-get_projectile_ids"></a>

### `get_projectile_ids`

- API：`public`

```gdscript
func get_projectile_ids() -> PackedStringArray:
```

获取所有有效发射体 ID。

返回：按字典序排序的 ID 数组。

<a id="member-gfprojectilecatalog-methods-prune_invalid_entries"></a>

### `prune_invalid_entries`

- API：`public`

```gdscript
func prune_invalid_entries() -> int:
```

清理空条目、空 ID 或空场景。

返回：被清理的条目数量。
