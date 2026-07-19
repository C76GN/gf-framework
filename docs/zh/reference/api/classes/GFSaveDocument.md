# GFSaveDocument

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/document/gf_save_document.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`9.0.0`

项目级版本化存档文档。 文档把项目 schema 身份、文档版本和多个独立版本化分区组合成规范载荷。 物理编码、校验和与文件事务仍由 GFStorageUtility 负责。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`FORMAT_ID`](#member-gfsavedocument-constants-format_id) | `const FORMAT_ID: String = "gf_save_document"` |
| 常量 | [`FORMAT_VERSION`](#member-gfsavedocument-constants-format_version) | `const FORMAT_VERSION: int = 1` |
| 方法 | [`configure`](#member-gfsavedocument-methods-configure) | `func configure( schema_id: StringName, schema_version: int, sections: Array[GFSaveSection] = [], metadata: Dictionary = {} ) -> GFSaveDocument:` |
| 方法 | [`get_schema_id`](#member-gfsavedocument-methods-get_schema_id) | `func get_schema_id() -> StringName:` |
| 方法 | [`get_schema_version`](#member-gfsavedocument-methods-get_schema_version) | `func get_schema_version() -> int:` |
| 方法 | [`get_metadata`](#member-gfsavedocument-methods-get_metadata) | `func get_metadata() -> Dictionary:` |
| 方法 | [`set_section`](#member-gfsavedocument-methods-set_section) | `func set_section(section: GFSaveSection) -> bool:` |
| 方法 | [`has_section`](#member-gfsavedocument-methods-has_section) | `func has_section(section_id: StringName) -> bool:` |
| 方法 | [`get_section`](#member-gfsavedocument-methods-get_section) | `func get_section(section_id: StringName) -> GFSaveSection:` |
| 方法 | [`get_sections`](#member-gfsavedocument-methods-get_sections) | `func get_sections() -> Array[GFSaveSection]:` |
| 方法 | [`get_section_ids`](#member-gfsavedocument-methods-get_section_ids) | `func get_section_ids() -> PackedStringArray:` |
| 方法 | [`remove_section`](#member-gfsavedocument-methods-remove_section) | `func remove_section(section_id: StringName) -> bool:` |
| 方法 | [`validate_document`](#member-gfsavedocument-methods-validate_document) | `func validate_document() -> Dictionary:` |
| 方法 | [`to_dict`](#member-gfsavedocument-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`duplicate_document`](#member-gfsavedocument-methods-duplicate_document) | `func duplicate_document() -> GFSaveDocument:` |
| 方法 | [`inspect_dict`](#member-gfsavedocument-methods-inspect_dict) | `static func inspect_dict(data: Dictionary) -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfsavedocument-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFSaveDocument:` |

## 常量

<a id="member-gfsavedocument-constants-format_id"></a>

### `FORMAT_ID`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const FORMAT_ID: String = "gf_save_document"
```

文档格式标识。

<a id="member-gfsavedocument-constants-format_version"></a>

### `FORMAT_VERSION`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
const FORMAT_VERSION: int = 1
```

当前文档容器格式版本。

## 方法

<a id="member-gfsavedocument-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func configure( schema_id: StringName, schema_version: int, sections: Array[GFSaveSection] = [], metadata: Dictionary = {} ) -> GFSaveDocument:
```

配置文档头与初始分区。

参数：

| 名称 | 说明 |
|---|---|
| `schema_id` | 项目定义的稳定 schema ID。 |
| `schema_version` | 文档 schema 版本。 |
| `sections` | 初始分区；无效或重复分区不会写入。 |
| `metadata` | 项目定义且可持久化的文档元数据。 |

返回：当前文档。

结构：

- `metadata`: Dictionary with project-defined persisted metadata.

<a id="member-gfsavedocument-methods-get_schema_id"></a>

### `get_schema_id`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_schema_id() -> StringName:
```

获取项目 schema ID。

返回：schema ID。

<a id="member-gfsavedocument-methods-get_schema_version"></a>

### `get_schema_version`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_schema_version() -> int:
```

获取文档 schema 版本。

返回：文档 schema 版本。

<a id="member-gfsavedocument-methods-get_metadata"></a>

### `get_metadata`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_metadata() -> Dictionary:
```

获取文档元数据副本。

返回：深复制的文档元数据。

结构：

- `return`: Dictionary with project-defined persisted metadata.

<a id="member-gfsavedocument-methods-set_section"></a>

### `set_section`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func set_section(section: GFSaveSection) -> bool:
```

添加或替换分区。 写入前会校验分区，文档始终只持有隔离副本。

参数：

| 名称 | 说明 |
|---|---|
| `section` | 要写入的分区。 |

返回：分区有效时返回 true。

<a id="member-gfsavedocument-methods-has_section"></a>

### `has_section`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func has_section(section_id: StringName) -> bool:
```

检查分区是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `section_id` | 分区 ID。 |

返回：存在时返回 true。

<a id="member-gfsavedocument-methods-get_section"></a>

### `get_section`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_section(section_id: StringName) -> GFSaveSection:
```

获取分区副本。

参数：

| 名称 | 说明 |
|---|---|
| `section_id` | 分区 ID。 |

返回：分区副本；不存在时返回 null。

<a id="member-gfsavedocument-methods-get_sections"></a>

### `get_sections`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_sections() -> Array[GFSaveSection]:
```

获取全部分区副本。

返回：按 section_id 排序的分区数组。

<a id="member-gfsavedocument-methods-get_section_ids"></a>

### `get_section_ids`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_section_ids() -> PackedStringArray:
```

获取全部分区 ID。

返回：排序后的分区 ID。

<a id="member-gfsavedocument-methods-remove_section"></a>

### `remove_section`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func remove_section(section_id: StringName) -> bool:
```

移除分区。

参数：

| 名称 | 说明 |
|---|---|
| `section_id` | 分区 ID。 |

返回：原本存在时返回 true。

<a id="member-gfsavedocument-methods-validate_document"></a>

### `validate_document`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func validate_document() -> Dictionary:
```

校验文档头、分区和持久化安全性。

返回：结构化校验报告。

结构：

- `return`: GFValidationReportDictionary-compatible report with issues, counts, summary, and next_actions.

<a id="member-gfsavedocument-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为规范持久化字典。

返回：文档字典。

结构：

- `return`: Dictionary with format, format_version, schema_id, schema_version, sections, and metadata.

<a id="member-gfsavedocument-methods-duplicate_document"></a>

### `duplicate_document`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func duplicate_document() -> GFSaveDocument:
```

创建隔离副本。

返回：文档副本。

<a id="member-gfsavedocument-methods-inspect_dict"></a>

### `inspect_dict`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
static func inspect_dict(data: Dictionary) -> Dictionary:
```

检查持久化字典是否为当前文档容器格式。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 待检查字典。 |

返回：结构化校验报告。

结构：

- `data`: Dictionary expected to follow GFSaveDocument.to_dict().
- `return`: GFValidationReportDictionary-compatible report with issues, counts, summary, and next_actions.

<a id="member-gfsavedocument-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFSaveDocument:
```

从规范字典解析文档。 容器或任一分区无效时 fail-closed 返回 null，不接受旧裸 Dictionary。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 文档字典。 |

返回：有效文档；解析失败时返回 null。

结构：

- `data`: Dictionary following GFSaveDocument.to_dict().
