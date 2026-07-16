# GFSaveSlotCard

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/slots/gf_save_slot_card.gd`
- 模块：`Save`
- 继承：`Resource`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

通用存档槽摘要数据。 作为项目 UI 和存档系统之间的轻量 DTO，不规定具体界面布局、文案或业务字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`slot_index`](#member-gfsaveslotcard-properties-slot_index) | `var slot_index: int = -1` |
| 属性 | [`slot_id`](#member-gfsaveslotcard-properties-slot_id) | `var slot_id: StringName = &""` |
| 属性 | [`display_name`](#member-gfsaveslotcard-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`description`](#member-gfsaveslotcard-properties-description) | `var description: String = ""` |
| 属性 | [`is_empty`](#member-gfsaveslotcard-properties-is_empty) | `var is_empty: bool = true` |
| 属性 | [`is_active`](#member-gfsaveslotcard-properties-is_active) | `var is_active: bool = false` |
| 属性 | [`is_compatible`](#member-gfsaveslotcard-properties-is_compatible) | `var is_compatible: bool = true` |
| 属性 | [`modified_time`](#member-gfsaveslotcard-properties-modified_time) | `var modified_time: int = 0` |
| 属性 | [`metadata`](#member-gfsaveslotcard-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`compatibility_errors`](#member-gfsaveslotcard-properties-compatibility_errors) | `var compatibility_errors: PackedStringArray = PackedStringArray()` |
| 方法 | [`configure_from_slot_summary`](#member-gfsaveslotcard-methods-configure_from_slot_summary) | `func configure_from_slot_summary( summary: Dictionary, fallback_slot_id: StringName = &"", active_slot_index: int = -1 ) -> GFSaveSlotCard:` |
| 方法 | [`to_dict`](#member-gfsaveslotcard-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`get_status_id`](#member-gfsaveslotcard-methods-get_status_id) | `func get_status_id() -> StringName:` |
| 方法 | [`from_slot_summary`](#member-gfsaveslotcard-methods-from_slot_summary) | `static func from_slot_summary( summary: Dictionary, fallback_slot_id: StringName = &"", active_slot_index: int = -1 ) -> GFSaveSlotCard:` |

## 属性

<a id="member-gfsaveslotcard-properties-slot_index"></a>

### `slot_index`

- API：`public`

```gdscript
var slot_index: int = -1
```

整数槽位索引。文件名/云端 key 场景可保持为 -1。

<a id="member-gfsaveslotcard-properties-slot_id"></a>

### `slot_id`

- API：`public`

```gdscript
var slot_id: StringName = &""
```

逻辑槽位标识。

<a id="member-gfsaveslotcard-properties-display_name"></a>

### `display_name`

- API：`public`

```gdscript
var display_name: String = ""
```

项目可选展示名称。

<a id="member-gfsaveslotcard-properties-description"></a>

### `description`

- API：`public`

```gdscript
var description: String = ""
```

项目可选展示描述。

<a id="member-gfsaveslotcard-properties-is_empty"></a>

### `is_empty`

- API：`public`

```gdscript
var is_empty: bool = true
```

是否为空槽位。

<a id="member-gfsaveslotcard-properties-is_active"></a>

### `is_active`

- API：`public`

```gdscript
var is_active: bool = false
```

是否为当前选中槽位。

<a id="member-gfsaveslotcard-properties-is_compatible"></a>

### `is_compatible`

- API：`public`

```gdscript
var is_compatible: bool = true
```

是否兼容当前项目版本或数据结构。

<a id="member-gfsaveslotcard-properties-modified_time"></a>

### `modified_time`

- API：`public`

```gdscript
var modified_time: int = 0
```

最近修改时间戳。

<a id="member-gfsaveslotcard-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`3.6.0`

```gdscript
var metadata: Dictionary = {}
```

原始元数据副本。

结构：

- `metadata`: Dictionary，通常来自 GFSaveSlotMetadata.to_dict() 或槽位存储摘要的 metadata 字段。

<a id="member-gfsaveslotcard-properties-compatibility_errors"></a>

### `compatibility_errors`

- API：`public`

```gdscript
var compatibility_errors: PackedStringArray = PackedStringArray()
```

兼容性问题列表。

## 方法

<a id="member-gfsaveslotcard-methods-configure_from_slot_summary"></a>

### `configure_from_slot_summary`

- API：`public`
- 首次版本：`3.6.0`

```gdscript
func configure_from_slot_summary( summary: Dictionary, fallback_slot_id: StringName = &"", active_slot_index: int = -1 ) -> GFSaveSlotCard:
```

从槽位存储适配器的通用摘要配置卡片。

参数：

| 名称 | 说明 |
|---|---|
| `summary` | 槽位摘要。 |
| `fallback_slot_id` | 摘要缺少 slot_id 时的兜底标识。 |
| `active_slot_index` | 当前选中槽位索引。 |

返回：当前卡片。

结构：

- `summary`: Dictionary，可包含 slot_index、slot_id、modified_time、is_compatible、compatibility_errors 与 metadata。

<a id="member-gfsaveslotcard-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

转换为 Dictionary。

返回：卡片字典。

结构：

- `return`: Dictionary，包含 slot_index、slot_id、display_name、description、is_empty、is_active、is_compatible、status_id、modified_time、metadata 与 compatibility_errors。

<a id="member-gfsaveslotcard-methods-get_status_id"></a>

### `get_status_id`

- API：`public`

```gdscript
func get_status_id() -> StringName:
```

获取非本地化状态标识。 项目 UI 可基于该标识映射自己的文案、样式或图标。

返回：状态标识：empty、incompatible、active 或 ready。

<a id="member-gfsaveslotcard-methods-from_slot_summary"></a>

### `from_slot_summary`

- API：`public`

```gdscript
static func from_slot_summary( summary: Dictionary, fallback_slot_id: StringName = &"", active_slot_index: int = -1 ) -> GFSaveSlotCard:
```

从摘要创建卡片。

参数：

| 名称 | 说明 |
|---|---|
| `summary` | 槽位摘要。 |
| `fallback_slot_id` | 兜底标识。 |
| `active_slot_index` | 当前选中槽位索引。 |

返回：新卡片。

结构：

- `summary`: Dictionary，可包含 slot_index、slot_id、modified_time、is_compatible、compatibility_errors 与 metadata。
