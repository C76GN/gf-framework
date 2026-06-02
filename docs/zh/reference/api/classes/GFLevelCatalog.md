# GFLevelCatalog

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/level/gf_level_catalog.gd`
- 模块：`Domain`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用关卡目录资源。 用于按关卡包和排序值组织 GFLevelEntry，保持目录查询与具体关卡规则解耦。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`entries`](#member-gflevelcatalog-properties-entries) | `var entries: Array[GFLevelEntry] = []` |
| 方法 | [`add_entry`](#member-gflevelcatalog-methods-add_entry) | `func add_entry(entry: GFLevelEntry) -> void:` |
| 方法 | [`has_level`](#member-gflevelcatalog-methods-has_level) | `func has_level(level_id: StringName) -> bool:` |
| 方法 | [`get_entry`](#member-gflevelcatalog-methods-get_entry) | `func get_entry(level_id: StringName) -> GFLevelEntry:` |
| 方法 | [`get_levels`](#member-gflevelcatalog-methods-get_levels) | `func get_levels(pack_id: StringName = &"") -> Array[GFLevelEntry]:` |
| 方法 | [`get_pack_ids`](#member-gflevelcatalog-methods-get_pack_ids) | `func get_pack_ids() -> Array[StringName]:` |
| 方法 | [`get_next_level_id`](#member-gflevelcatalog-methods-get_next_level_id) | `func get_next_level_id(level_id: StringName) -> StringName:` |
| 方法 | [`get_previous_level_id`](#member-gflevelcatalog-methods-get_previous_level_id) | `func get_previous_level_id(level_id: StringName) -> StringName:` |

## 属性

<a id="member-gflevelcatalog-properties-entries"></a>

### `entries`

- API：`public`

```gdscript
var entries: Array[GFLevelEntry] = []
```

关卡条目列表。

结构：

- `entries`: Array[GFLevelEntry]，关卡目录条目列表；查询方法会返回条目拷贝。

## 方法

<a id="member-gflevelcatalog-methods-add_entry"></a>

### `add_entry`

- API：`public`

```gdscript
func add_entry(entry: GFLevelEntry) -> void:
```

添加关卡条目。

参数：

| 名称 | 说明 |
|---|---|
| `entry` | 关卡条目。 |

<a id="member-gflevelcatalog-methods-has_level"></a>

### `has_level`

- API：`public`

```gdscript
func has_level(level_id: StringName) -> bool:
```

检查关卡是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |

返回：存在时返回 true。

<a id="member-gflevelcatalog-methods-get_entry"></a>

### `get_entry`

- API：`public`

```gdscript
func get_entry(level_id: StringName) -> GFLevelEntry:
```

获取关卡条目。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 关卡 ID。 |

返回：条目拷贝；不存在时返回 null。

<a id="member-gflevelcatalog-methods-get_levels"></a>

### `get_levels`

- API：`public`

```gdscript
func get_levels(pack_id: StringName = &"") -> Array[GFLevelEntry]:
```

获取指定关卡扩展中的条目。

参数：

| 名称 | 说明 |
|---|---|
| `pack_id` | 关卡扩展 ID；为空时返回全部。 |

返回：已排序的条目拷贝数组。

结构：

- `return`: Array[GFLevelEntry]，按 sort_order 与 level_id 排序后的关卡条目拷贝。

<a id="member-gflevelcatalog-methods-get_pack_ids"></a>

### `get_pack_ids`

- API：`public`

```gdscript
func get_pack_ids() -> Array[StringName]:
```

获取所有关卡扩展 ID。

返回：关卡扩展 ID 数组。

结构：

- `return`: Array[StringName]，已排序的关卡包或章节 ID 列表。

<a id="member-gflevelcatalog-methods-get_next_level_id"></a>

### `get_next_level_id`

- API：`public`

```gdscript
func get_next_level_id(level_id: StringName) -> StringName:
```

获取同关卡扩展内下一个关卡 ID。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 当前关卡 ID。 |

返回：后续关卡 ID；没有时返回空 StringName。

<a id="member-gflevelcatalog-methods-get_previous_level_id"></a>

### `get_previous_level_id`

- API：`public`

```gdscript
func get_previous_level_id(level_id: StringName) -> StringName:
```

获取同关卡扩展内上一个关卡 ID。

参数：

| 名称 | 说明 |
|---|---|
| `level_id` | 当前关卡 ID。 |

返回：前序关卡 ID；没有时返回空 StringName。
