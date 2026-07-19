# GFSaveSlotMetadata

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/slots/gf_save_slot_metadata.gd`
- 模块：`Save`
- 继承：`Resource`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

通用存档槽元数据。 只描述槽位、版本、时间、标签和项目自定义字典，不绑定任何具体游戏业务字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`slot_id`](#member-gfsaveslotmetadata-properties-slot_id) | `var slot_id: StringName = &""` |
| 属性 | [`display_name`](#member-gfsaveslotmetadata-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`description`](#member-gfsaveslotmetadata-properties-description) | `var description: String = ""` |
| 属性 | [`schema_id`](#member-gfsaveslotmetadata-properties-schema_id) | `var schema_id: StringName = &""` |
| 属性 | [`schema_version`](#member-gfsaveslotmetadata-properties-schema_version) | `var schema_version: int = 1` |
| 属性 | [`app_version`](#member-gfsaveslotmetadata-properties-app_version) | `var app_version: String = ""` |
| 属性 | [`created_at_unix`](#member-gfsaveslotmetadata-properties-created_at_unix) | `var created_at_unix: int = 0` |
| 属性 | [`updated_at_unix`](#member-gfsaveslotmetadata-properties-updated_at_unix) | `var updated_at_unix: int = 0` |
| 属性 | [`elapsed_seconds`](#member-gfsaveslotmetadata-properties-elapsed_seconds) | `var elapsed_seconds: float = 0.0` |
| 属性 | [`tags`](#member-gfsaveslotmetadata-properties-tags) | `var tags: PackedStringArray = PackedStringArray()` |
| 属性 | [`custom_metadata`](#member-gfsaveslotmetadata-properties-custom_metadata) | `var custom_metadata: Dictionary = {}` |
| 方法 | [`to_dict`](#member-gfsaveslotmetadata-methods-to_dict) | `func to_dict(include_empty: bool = true) -> Dictionary:` |
| 方法 | [`to_patch_dict`](#member-gfsaveslotmetadata-methods-to_patch_dict) | `func to_patch_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfsaveslotmetadata-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_metadata`](#member-gfsaveslotmetadata-methods-duplicate_metadata) | `func duplicate_metadata() -> GFSaveSlotMetadata:` |
| 方法 | [`get_display_name`](#member-gfsaveslotmetadata-methods-get_display_name) | `func get_display_name(fallback: String = "") -> String:` |
| 方法 | [`validate_metadata`](#member-gfsaveslotmetadata-methods-validate_metadata) | `func validate_metadata() -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfsaveslotmetadata-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFSaveSlotMetadata:` |
| 方法 | [`from_values`](#member-gfsaveslotmetadata-methods-from_values) | `static func from_values( p_slot_id: StringName, p_display_name: String = "", p_custom_metadata: Dictionary = {}, unix_time_seconds: int = 0 ) -> GFSaveSlotMetadata:` |

## 属性

<a id="member-gfsaveslotmetadata-properties-slot_id"></a>

### `slot_id`

- API：`public`

```gdscript
var slot_id: StringName = &""
```

槽位逻辑标识。可由项目映射到整数槽、文件名或云端 key。

<a id="member-gfsaveslotmetadata-properties-display_name"></a>

### `display_name`

- API：`public`

```gdscript
var display_name: String = ""
```

展示名称。

<a id="member-gfsaveslotmetadata-properties-description"></a>

### `description`

- API：`public`

```gdscript
var description: String = ""
```

展示描述。

<a id="member-gfsaveslotmetadata-properties-schema_id"></a>

### `schema_id`

- API：`public`

```gdscript
var schema_id: StringName = &""
```

存档数据结构标识。

<a id="member-gfsaveslotmetadata-properties-schema_version"></a>

### `schema_version`

- API：`public`

```gdscript
var schema_version: int = 1
```

存档数据结构版本。

<a id="member-gfsaveslotmetadata-properties-app_version"></a>

### `app_version`

- API：`public`

```gdscript
var app_version: String = ""
```

项目版本号。

<a id="member-gfsaveslotmetadata-properties-created_at_unix"></a>

### `created_at_unix`

- API：`public`

```gdscript
var created_at_unix: int = 0
```

创建时间戳。

<a id="member-gfsaveslotmetadata-properties-updated_at_unix"></a>

### `updated_at_unix`

- API：`public`

```gdscript
var updated_at_unix: int = 0
```

更新时间戳。

<a id="member-gfsaveslotmetadata-properties-elapsed_seconds"></a>

### `elapsed_seconds`

- API：`public`

```gdscript
var elapsed_seconds: float = 0.0
```

通用游玩时长或业务耗时。

<a id="member-gfsaveslotmetadata-properties-tags"></a>

### `tags`

- API：`public`

```gdscript
var tags: PackedStringArray = PackedStringArray()
```

通用标签。

<a id="member-gfsaveslotmetadata-properties-custom_metadata"></a>

### `custom_metadata`

- API：`public`

```gdscript
var custom_metadata: Dictionary = {}
```

项目自定义元数据。

结构：

- `custom_metadata`: Dictionary，可包含项目自定义展示、兼容性或索引字段。

## 方法

<a id="member-gfsaveslotmetadata-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict(include_empty: bool = true) -> Dictionary:
```

转换为 Dictionary。

参数：

| 名称 | 说明 |
|---|---|
| `include_empty` | 是否包含空值。 |

返回：元数据字典。

结构：

- `return`: Dictionary，可包含 slot_id、display_name、description、schema_id、schema_version、app_version、created_at_unix、updated_at_unix、elapsed_seconds、tags 与 custom_metadata。

<a id="member-gfsaveslotmetadata-methods-to_patch_dict"></a>

### `to_patch_dict`

- API：`public`

```gdscript
func to_patch_dict() -> Dictionary:
```

转换为只包含非空值的补丁字典。

返回：补丁字典。

结构：

- `return`: Dictionary，字段同 to_dict()，但会省略空值。

<a id="member-gfsaveslotmetadata-methods-apply_dict"></a>

### `apply_dict`

- API：`public`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

应用字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 元数据字典。 |

结构：

- `data`: Dictionary，可包含 slot_id、display_name、description、schema_id、schema_version、app_version、created_at_unix、updated_at_unix、elapsed_seconds、tags 与 custom_metadata。

<a id="member-gfsaveslotmetadata-methods-duplicate_metadata"></a>

### `duplicate_metadata`

- API：`public`

```gdscript
func duplicate_metadata() -> GFSaveSlotMetadata:
```

创建深拷贝。

返回：新元数据。

<a id="member-gfsaveslotmetadata-methods-get_display_name"></a>

### `get_display_name`

- API：`public`

```gdscript
func get_display_name(fallback: String = "") -> String:
```

获取展示名称，允许调用方提供兜底文本。

参数：

| 名称 | 说明 |
|---|---|
| `fallback` | 兜底文本。 |

返回：展示名称。

<a id="member-gfsaveslotmetadata-methods-validate_metadata"></a>

### `validate_metadata`

- API：`public`

```gdscript
func validate_metadata() -> Dictionary:
```

校验元数据的通用结构。

返回：诊断报告。

结构：

- `return`: Dictionary，包含 ok、healthy、issues、issue_count、warning_count、error_count、summary 与 next_actions 等校验报告字段。

<a id="member-gfsaveslotmetadata-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
static func from_dict(data: Dictionary) -> GFSaveSlotMetadata:
```

从 Dictionary 创建元数据。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 元数据字典。 |

返回：新元数据。

结构：

- `data`: Dictionary，字段同 to_dict() 返回值。

<a id="member-gfsaveslotmetadata-methods-from_values"></a>

### `from_values`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
static func from_values( p_slot_id: StringName, p_display_name: String = "", p_custom_metadata: Dictionary = {}, unix_time_seconds: int = 0 ) -> GFSaveSlotMetadata:
```

使用常用字段创建元数据。

参数：

| 名称 | 说明 |
|---|---|
| `p_slot_id` | 槽位标识。 |
| `p_display_name` | 展示名称。 |
| `p_custom_metadata` | 自定义元数据。 |
| `unix_time_seconds` | 显式 Unix epoch 秒时间戳；0 表示未知。 |

返回：新元数据。

结构：

- `p_custom_metadata`: Dictionary，可包含项目自定义展示、兼容性或索引字段。
