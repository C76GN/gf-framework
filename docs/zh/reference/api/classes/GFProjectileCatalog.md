# GFProjectileCatalog

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_catalog.gd`
- 模块：`Combat`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

typed projectile definition 目录。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`entries`](#member-gfprojectilecatalog-properties-entries) | `var entries: Array[GFProjectileCatalogEntry] = []` |
| 方法 | [`set_definition`](#member-gfprojectilecatalog-methods-set_definition) | `func set_definition( projectile_id: StringName, definition: GFProjectileDefinition ) -> void:` |
| 方法 | [`get_definition`](#member-gfprojectilecatalog-methods-get_definition) | `func get_definition(projectile_id: StringName) -> GFProjectileDefinition:` |
| 方法 | [`has_definition`](#member-gfprojectilecatalog-methods-has_definition) | `func has_definition(projectile_id: StringName) -> bool:` |
| 方法 | [`remove_definition`](#member-gfprojectilecatalog-methods-remove_definition) | `func remove_definition(projectile_id: StringName) -> bool:` |
| 方法 | [`get_projectile_ids`](#member-gfprojectilecatalog-methods-get_projectile_ids) | `func get_projectile_ids() -> PackedStringArray:` |
| 方法 | [`prune_invalid_entries`](#member-gfprojectilecatalog-methods-prune_invalid_entries) | `func prune_invalid_entries() -> int:` |

## 属性

<a id="member-gfprojectilecatalog-properties-entries"></a>

### `entries`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var entries: Array[GFProjectileCatalogEntry] = []
```

目录条目；重复或无效条目不会参与查找结果。

结构：

- `entries`: Array[GFProjectileCatalogEntry]，每个有效 projectile_id 只保留首个定义。

## 方法

<a id="member-gfprojectilecatalog-methods-set_definition"></a>

### `set_definition`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func set_definition( projectile_id: StringName, definition: GFProjectileDefinition ) -> void:
```

设置或替换一个 typed definition。

参数：

| 名称 | 说明 |
|---|---|
| `projectile_id` | 非空稳定 ID。 |
| `definition` | typed definition；null 等价于移除。 |

<a id="member-gfprojectilecatalog-methods-get_definition"></a>

### `get_definition`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_definition(projectile_id: StringName) -> GFProjectileDefinition:
```

查找指定 ID 的 typed definition。

参数：

| 名称 | 说明 |
|---|---|
| `projectile_id` | 稳定 ID。 |

返回：definition；不存在时返回 null。

<a id="member-gfprojectilecatalog-methods-has_definition"></a>

### `has_definition`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func has_definition(projectile_id: StringName) -> bool:
```

判断指定 ID 是否有有效 definition。

参数：

| 名称 | 说明 |
|---|---|
| `projectile_id` | 稳定 ID。 |

返回：是否存在有效 definition。

<a id="member-gfprojectilecatalog-methods-remove_definition"></a>

### `remove_definition`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func remove_definition(projectile_id: StringName) -> bool:
```

移除指定 ID 的所有重复条目。

参数：

| 名称 | 说明 |
|---|---|
| `projectile_id` | 稳定 ID。 |

返回：是否至少移除一个条目。

<a id="member-gfprojectilecatalog-methods-get_projectile_ids"></a>

### `get_projectile_ids`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_projectile_ids() -> PackedStringArray:
```

返回已排序且去重的有效 projectile ID。

返回：字典序排序的 ID 快照。

<a id="member-gfprojectilecatalog-methods-prune_invalid_entries"></a>

### `prune_invalid_entries`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func prune_invalid_entries() -> int:
```

清理 null、无效和重复条目。

返回：被移除的条目数量。
