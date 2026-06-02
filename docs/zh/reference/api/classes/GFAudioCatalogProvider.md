# GFAudioCatalogProvider

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_catalog_provider.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用音频目录提供器。 为编辑器选择器或构建工具提供事件、参数、状态和开关 ID 查询入口。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`events`](#member-gfaudiocatalogprovider-properties-events) | `var events: Dictionary = {}` |
| 属性 | [`parameters`](#member-gfaudiocatalogprovider-properties-parameters) | `var parameters: Dictionary = {}` |
| 属性 | [`states`](#member-gfaudiocatalogprovider-properties-states) | `var states: Dictionary = {}` |
| 属性 | [`switches`](#member-gfaudiocatalogprovider-properties-switches) | `var switches: Dictionary = {}` |
| 方法 | [`set_entry`](#member-gfaudiocatalogprovider-methods-set_entry) | `func set_entry(catalog_id: StringName, entry_id: StringName, metadata: Dictionary = {}) -> void:` |
| 方法 | [`remove_entry`](#member-gfaudiocatalogprovider-methods-remove_entry) | `func remove_entry(catalog_id: StringName, entry_id: StringName) -> void:` |
| 方法 | [`get_ids`](#member-gfaudiocatalogprovider-methods-get_ids) | `func get_ids(catalog_id: StringName) -> PackedStringArray:` |
| 方法 | [`describe_entry`](#member-gfaudiocatalogprovider-methods-describe_entry) | `func describe_entry(catalog_id: StringName, entry_id: StringName) -> Dictionary:` |
| 方法 | [`describe_catalog`](#member-gfaudiocatalogprovider-methods-describe_catalog) | `func describe_catalog() -> Dictionary:` |

## 属性

<a id="member-gfaudiocatalogprovider-properties-events"></a>

### `events`

- API：`public`

```gdscript
var events: Dictionary = {}
```

事件目录。

结构：

- `events`: 事件目录 Dictionary，键为事件 ID，值为条目元数据 Dictionary。

<a id="member-gfaudiocatalogprovider-properties-parameters"></a>

### `parameters`

- API：`public`

```gdscript
var parameters: Dictionary = {}
```

参数目录。

结构：

- `parameters`: 参数目录 Dictionary，键为参数 ID，值为条目元数据 Dictionary。

<a id="member-gfaudiocatalogprovider-properties-states"></a>

### `states`

- API：`public`

```gdscript
var states: Dictionary = {}
```

状态目录。

结构：

- `states`: 状态目录 Dictionary，键为状态 ID，值为条目元数据 Dictionary。

<a id="member-gfaudiocatalogprovider-properties-switches"></a>

### `switches`

- API：`public`

```gdscript
var switches: Dictionary = {}
```

开关目录。

结构：

- `switches`: 开关目录 Dictionary，键为开关 ID，值为条目元数据 Dictionary。

## 方法

<a id="member-gfaudiocatalogprovider-methods-set_entry"></a>

### `set_entry`

- API：`public`

```gdscript
func set_entry(catalog_id: StringName, entry_id: StringName, metadata: Dictionary = {}) -> void:
```

设置目录条目。

参数：

| 名称 | 说明 |
|---|---|
| `catalog_id` | 目录标识，如 events、parameters、states、switches。 |
| `entry_id` | 条目标识。 |
| `metadata` | 条目元数据。 |

结构：

- `metadata`: 条目元数据 Dictionary；键和值由目录提供器或项目工具约定。

<a id="member-gfaudiocatalogprovider-methods-remove_entry"></a>

### `remove_entry`

- API：`public`

```gdscript
func remove_entry(catalog_id: StringName, entry_id: StringName) -> void:
```

移除目录条目。

参数：

| 名称 | 说明 |
|---|---|
| `catalog_id` | 目录标识。 |
| `entry_id` | 条目标识。 |

<a id="member-gfaudiocatalogprovider-methods-get_ids"></a>

### `get_ids`

- API：`public`

```gdscript
func get_ids(catalog_id: StringName) -> PackedStringArray:
```

获取目录 ID 列表。

参数：

| 名称 | 说明 |
|---|---|
| `catalog_id` | 目录标识。 |

返回：排序后的条目 ID。

<a id="member-gfaudiocatalogprovider-methods-describe_entry"></a>

### `describe_entry`

- API：`public`

```gdscript
func describe_entry(catalog_id: StringName, entry_id: StringName) -> Dictionary:
```

获取目录条目描述。

参数：

| 名称 | 说明 |
|---|---|
| `catalog_id` | 目录标识。 |
| `entry_id` | 条目标识。 |

返回：条目元数据副本。

结构：

- `return`: 条目元数据 Dictionary；键和值由目录提供器或项目工具约定。

<a id="member-gfaudiocatalogprovider-methods-describe_catalog"></a>

### `describe_catalog`

- API：`public`

```gdscript
func describe_catalog() -> Dictionary:
```

获取完整目录快照。

返回：目录快照字典。

结构：

- `return`: 目录快照 Dictionary，包含 events、parameters、states 和 switches 字段。
