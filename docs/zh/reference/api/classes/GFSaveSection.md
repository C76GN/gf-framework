# GFSaveSection

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/document/gf_save_section.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`9.0.0`

版本化存档分区值对象。 分区用稳定 section_id、独立 schema_version 和任意可持久化 payload 表达一个模块拥有的数据边界，不解释项目业务字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`configure`](#member-gfsavesection-methods-configure) | `func configure( section_id: StringName, schema_version: int, payload: Variant, metadata: Dictionary = {} ) -> GFSaveSection:` |
| 方法 | [`get_section_id`](#member-gfsavesection-methods-get_section_id) | `func get_section_id() -> StringName:` |
| 方法 | [`get_schema_version`](#member-gfsavesection-methods-get_schema_version) | `func get_schema_version() -> int:` |
| 方法 | [`get_payload`](#member-gfsavesection-methods-get_payload) | `func get_payload() -> Variant:` |
| 方法 | [`get_metadata`](#member-gfsavesection-methods-get_metadata) | `func get_metadata() -> Dictionary:` |
| 方法 | [`validate_section`](#member-gfsavesection-methods-validate_section) | `func validate_section() -> Dictionary:` |
| 方法 | [`to_dict`](#member-gfsavesection-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`duplicate_section`](#member-gfsavesection-methods-duplicate_section) | `func duplicate_section() -> GFSaveSection:` |
| 方法 | [`from_dict`](#member-gfsavesection-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFSaveSection:` |

## 方法

<a id="member-gfsavesection-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func configure( section_id: StringName, schema_version: int, payload: Variant, metadata: Dictionary = {} ) -> GFSaveSection:
```

配置分区并复制所有动态数据。

参数：

| 名称 | 说明 |
|---|---|
| `section_id` | 稳定分区 ID。 |
| `schema_version` | 分区 schema 版本，必须大于 0。 |
| `payload` | 项目定义且可持久化的分区载荷。 |
| `metadata` | 项目定义且可持久化的分区元数据。 |

返回：当前分区。

结构：

- `payload`: Variant accepted by GFSavePersistedValueValidator.
- `metadata`: Dictionary with project-defined persisted metadata.

<a id="member-gfsavesection-methods-get_section_id"></a>

### `get_section_id`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_section_id() -> StringName:
```

获取稳定分区 ID。

返回：分区 ID。

<a id="member-gfsavesection-methods-get_schema_version"></a>

### `get_schema_version`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_schema_version() -> int:
```

获取分区 schema 版本。

返回：分区 schema 版本。

<a id="member-gfsavesection-methods-get_payload"></a>

### `get_payload`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_payload() -> Variant:
```

获取分区载荷副本。

返回：深复制的项目载荷。

结构：

- `return`: Variant accepted by GFSavePersistedValueValidator.

<a id="member-gfsavesection-methods-get_metadata"></a>

### `get_metadata`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_metadata() -> Dictionary:
```

获取分区元数据副本。

返回：深复制的分区元数据。

结构：

- `return`: Dictionary with project-defined persisted metadata.

<a id="member-gfsavesection-methods-validate_section"></a>

### `validate_section`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func validate_section() -> Dictionary:
```

校验分区身份、版本和持久化安全性。

返回：结构化校验报告。

结构：

- `return`: GFValidationReportDictionary-compatible report with issues, counts, summary, and next_actions.

<a id="member-gfsavesection-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为规范持久化字典。

返回：分区字典。

结构：

- `return`: Dictionary with section_id, schema_version, payload, and metadata.

<a id="member-gfsavesection-methods-duplicate_section"></a>

### `duplicate_section`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func duplicate_section() -> GFSaveSection:
```

创建隔离副本。

返回：分区副本。

<a id="member-gfsavesection-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFSaveSection:
```

从持久化字典创建分区。 该方法执行严格边界检查，不修补非法字段或忽略未知字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 分区字典。 |

返回：新分区；输入不规范时返回 null。

结构：

- `data`: Dictionary with section_id, schema_version, payload, and metadata.
