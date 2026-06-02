# GFLevelEntry

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/level/gf_level_entry.gd`
- 模块：`Domain`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用关卡目录条目。 只描述关卡 ID、所属分组、可选场景路径和元数据，不规定关卡玩法规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`level_id`](#member-gflevelentry-properties-level_id) | `var level_id: StringName = &""` |
| 属性 | [`pack_id`](#member-gflevelentry-properties-pack_id) | `var pack_id: StringName = &""` |
| 属性 | [`scene_path`](#member-gflevelentry-properties-scene_path) | `var scene_path: String = ""` |
| 属性 | [`sort_order`](#member-gflevelentry-properties-sort_order) | `var sort_order: int = 0` |
| 属性 | [`metadata`](#member-gflevelentry-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`unlocks_on_complete`](#member-gflevelentry-properties-unlocks_on_complete) | `var unlocks_on_complete: Array[StringName] = []` |
| 方法 | [`get_level_id`](#member-gflevelentry-methods-get_level_id) | `func get_level_id() -> StringName:` |
| 方法 | [`duplicate_entry`](#member-gflevelentry-methods-duplicate_entry) | `func duplicate_entry() -> GFLevelEntry:` |

## 属性

<a id="member-gflevelentry-properties-level_id"></a>

### `level_id`

- API：`public`

```gdscript
var level_id: StringName = &""
```

关卡稳定 ID。

<a id="member-gflevelentry-properties-pack_id"></a>

### `pack_id`

- API：`public`

```gdscript
var pack_id: StringName = &""
```

可选关卡包或章节 ID。

<a id="member-gflevelentry-properties-scene_path"></a>

### `scene_path`

- API：`public`

```gdscript
var scene_path: String = ""
```

可选关卡场景路径。

<a id="member-gflevelentry-properties-sort_order"></a>

### `sort_order`

- API：`public`

```gdscript
var sort_order: int = 0
```

目录排序值，数值越小越靠前。

<a id="member-gflevelentry-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

关卡通用元数据。

结构：

- `metadata`: Dictionary，项目自定义关卡元数据；GF 会在构建关卡数据时复制透传。

<a id="member-gflevelentry-properties-unlocks_on_complete"></a>

### `unlocks_on_complete`

- API：`public`

```gdscript
var unlocks_on_complete: Array[StringName] = []
```

当前关卡完成后建议解锁的后续关卡 ID。

结构：

- `unlocks_on_complete`: Array[StringName]，完成当前关卡后建议解锁的关卡 ID 列表。

## 方法

<a id="member-gflevelentry-methods-get_level_id"></a>

### `get_level_id`

- API：`public`

```gdscript
func get_level_id() -> StringName:
```

获取稳定关卡 ID。

返回：关卡 ID。

<a id="member-gflevelentry-methods-duplicate_entry"></a>

### `duplicate_entry`

- API：`public`

```gdscript
func duplicate_entry() -> GFLevelEntry:
```

创建条目拷贝。

返回：新条目。
