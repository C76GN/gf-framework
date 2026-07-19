# GFSaveSlotStorageAdapter

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/slots/gf_save_slot_storage_adapter.gd`
- 模块：`Save`
- 继承：`Resource`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

Save 扩展的通用槽位存储适配器。 把逻辑槽位索引映射到可配置的数据/元数据文件名，并通过 GFStorageUtility 的通用字典事务 API 完成持久化。该类不定义项目存档字段，也不绑定 UI。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_DATA_FILE_TEMPLATE`](#member-gfsaveslotstorageadapter-constants-default_data_file_template) | `const DEFAULT_DATA_FILE_TEMPLATE: String = "slot_{index}_data.sav"` |
| 常量 | [`DEFAULT_METADATA_FILE_TEMPLATE`](#member-gfsaveslotstorageadapter-constants-default_metadata_file_template) | `const DEFAULT_METADATA_FILE_TEMPLATE: String = "slot_{index}_meta.sav"` |
| 属性 | [`data_file_template`](#member-gfsaveslotstorageadapter-properties-data_file_template) | `var data_file_template: String = DEFAULT_DATA_FILE_TEMPLATE` |
| 属性 | [`metadata_file_template`](#member-gfsaveslotstorageadapter-properties-metadata_file_template) | `var metadata_file_template: String = DEFAULT_METADATA_FILE_TEMPLATE` |
| 方法 | [`setup`](#member-gfsaveslotstorageadapter-methods-setup) | `func setup(storage: GFStorageUtility, clock: GFClock = null) -> GFSaveSlotStorageAdapter:` |
| 方法 | [`get_storage`](#member-gfsaveslotstorageadapter-methods-get_storage) | `func get_storage() -> GFStorageUtility:` |
| 方法 | [`set_clock`](#member-gfsaveslotstorageadapter-methods-set_clock) | `func set_clock(clock: GFClock) -> bool:` |
| 方法 | [`get_clock`](#member-gfsaveslotstorageadapter-methods-get_clock) | `func get_clock() -> GFClock:` |
| 方法 | [`get_data_file_name`](#member-gfsaveslotstorageadapter-methods-get_data_file_name) | `func get_data_file_name(slot_index: int) -> String:` |
| 方法 | [`get_metadata_file_name`](#member-gfsaveslotstorageadapter-methods-get_metadata_file_name) | `func get_metadata_file_name(slot_index: int) -> String:` |
| 方法 | [`save_slot`](#member-gfsaveslotstorageadapter-methods-save_slot) | `func save_slot( slot_index: int, document: GFSaveDocument, metadata: Dictionary = {} ) -> Error:` |
| 方法 | [`load_slot`](#member-gfsaveslotstorageadapter-methods-load_slot) | `func load_slot( slot_index: int, target_schema: GFSaveDocumentSchema = null, migrations: GFSaveMigrationRegistry = null, context: Dictionary = {} ) -> GFSaveDocumentReadResult:` |
| 方法 | [`load_slot_metadata`](#member-gfsaveslotstorageadapter-methods-load_slot_metadata) | `func load_slot_metadata(slot_index: int) -> Dictionary:` |
| 方法 | [`has_slot`](#member-gfsaveslotstorageadapter-methods-has_slot) | `func has_slot(slot_index: int) -> bool:` |
| 方法 | [`delete_slot`](#member-gfsaveslotstorageadapter-methods-delete_slot) | `func delete_slot(slot_index: int) -> Error:` |
| 方法 | [`list_slots`](#member-gfsaveslotstorageadapter-methods-list_slots) | `func list_slots() -> Array[Dictionary]:` |

## 常量

<a id="member-gfsaveslotstorageadapter-constants-default_data_file_template"></a>

### `DEFAULT_DATA_FILE_TEMPLATE`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_DATA_FILE_TEMPLATE: String = "slot_{index}_data.sav"
```

默认槽位数据文件模板。

<a id="member-gfsaveslotstorageadapter-constants-default_metadata_file_template"></a>

### `DEFAULT_METADATA_FILE_TEMPLATE`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_METADATA_FILE_TEMPLATE: String = "slot_{index}_meta.sav"
```

默认槽位元数据文件模板。

## 属性

<a id="member-gfsaveslotstorageadapter-properties-data_file_template"></a>

### `data_file_template`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var data_file_template: String = DEFAULT_DATA_FILE_TEMPLATE
```

数据文件模板，支持 `{index}` 占位符。

<a id="member-gfsaveslotstorageadapter-properties-metadata_file_template"></a>

### `metadata_file_template`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata_file_template: String = DEFAULT_METADATA_FILE_TEMPLATE
```

元数据文件模板，支持 `{index}` 占位符。

## 方法

<a id="member-gfsaveslotstorageadapter-methods-setup"></a>

### `setup`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func setup(storage: GFStorageUtility, clock: GFClock = null) -> GFSaveSlotStorageAdapter:
```

设置底层存储工具。

参数：

| 名称 | 说明 |
|---|---|
| `storage` | 底层 GFStorageUtility。 |
| `clock` | 可选墙上时钟；为空时保留当前时钟。 |

返回：当前适配器。

<a id="member-gfsaveslotstorageadapter-methods-get_storage"></a>

### `get_storage`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_storage() -> GFStorageUtility:
```

获取底层存储工具。

返回：当前 GFStorageUtility；未配置时返回 null。

<a id="member-gfsaveslotstorageadapter-methods-set_clock"></a>

### `set_clock`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func set_clock(clock: GFClock) -> bool:
```

设置缺省元数据时间戳使用的墙上时钟。

参数：

| 名称 | 说明 |
|---|---|
| `clock` | 新时钟。 |

返回：时钟合法并完成设置时返回 true。

<a id="member-gfsaveslotstorageadapter-methods-get_clock"></a>

### `get_clock`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_clock() -> GFClock:
```

获取缺省元数据时间戳使用的时钟。

返回：当前时钟。

<a id="member-gfsaveslotstorageadapter-methods-get_data_file_name"></a>

### `get_data_file_name`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_data_file_name(slot_index: int) -> String:
```

生成槽位数据文件名。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |

返回：数据文件名。

<a id="member-gfsaveslotstorageadapter-methods-get_metadata_file_name"></a>

### `get_metadata_file_name`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_metadata_file_name(slot_index: int) -> String:
```

生成槽位元数据文件名。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |

返回：元数据文件名。

<a id="member-gfsaveslotstorageadapter-methods-save_slot"></a>

### `save_slot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func save_slot( slot_index: int, document: GFSaveDocument, metadata: Dictionary = {} ) -> Error:
```

保存版本化槽位文档和元数据。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引；必须大于等于 0。 |
| `document` | 项目聚合后的版本化存档文档。 |
| `metadata` | 槽位摘要元数据。 |

返回：Godot 的 `Error` 结果码。

结构：

- `metadata`: Dictionary，通常来自 GFSaveSlotMetadata.to_dict()。

<a id="member-gfsaveslotstorageadapter-methods-load_slot"></a>

### `load_slot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func load_slot( slot_index: int, target_schema: GFSaveDocumentSchema = null, migrations: GFSaveMigrationRegistry = null, context: Dictionary = {} ) -> GFSaveDocumentReadResult:
```

读取、迁移并校验槽位文档。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |
| `target_schema` | 可选目标 schema；提供后要求最终版本完全匹配。 |
| `migrations` | 可选迁移注册表；旧版本文档需要迁移时必须提供。 |
| `context` | 项目定义的迁移上下文。 |

返回：强类型读取结果。

结构：

- `context`: Dictionary with caller-defined ephemeral migration data.

<a id="member-gfsaveslotstorageadapter-methods-load_slot_metadata"></a>

### `load_slot_metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func load_slot_metadata(slot_index: int) -> Dictionary:
```

读取槽位元数据。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |

返回：槽位元数据；读取失败时为空字典。

结构：

- `return`: Dictionary，通常兼容 GFSaveSlotMetadata.to_dict()。

<a id="member-gfsaveslotstorageadapter-methods-has_slot"></a>

### `has_slot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_slot(slot_index: int) -> bool:
```

检查槽位是否同时具备数据和元数据文件。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |

返回：同时存在数据和元数据时返回 true。

<a id="member-gfsaveslotstorageadapter-methods-delete_slot"></a>

### `delete_slot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func delete_slot(slot_index: int) -> Error:
```

删除槽位数据和元数据文件。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |

返回：两个文件都成功删除时返回 OK；任一文件缺失时返回 ERR_FILE_NOT_FOUND。

<a id="member-gfsaveslotstorageadapter-methods-list_slots"></a>

### `list_slots`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func list_slots() -> Array[Dictionary]:
```

枚举现有槽位摘要。

返回：槽位摘要数组。

结构：

- `return`: Array[Dictionary]，每项包含 slot_index、slot_id、metadata 和 modified_time。
