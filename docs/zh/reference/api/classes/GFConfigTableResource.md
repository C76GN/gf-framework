# GFConfigTableResource

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_table_resource.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`5.2.0`

可保存为 Godot Resource 的通用配置表。 用于承载导表工具生成的单表数据，保留稳定顺序、可选 schema、可选 ID 索引和元数据。 该资源不绑定业务表语义，适合保存为 `.tres` / `.res` 后由运行时 Provider 读取。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`table_name`](#member-gfconfigtableresource-properties-table_name) | `var table_name: StringName = &""` |
| 属性 | [`schema`](#member-gfconfigtableresource-properties-schema) | `var schema: GFConfigTableSchema = null` |
| 属性 | [`records`](#member-gfconfigtableresource-properties-records) | `var records: Array[Dictionary] = []` |
| 属性 | [`records_by_id`](#member-gfconfigtableresource-properties-records_by_id) | `var records_by_id: Dictionary = {}` |
| 属性 | [`records_by_index`](#member-gfconfigtableresource-properties-records_by_index) | `var records_by_index: Dictionary = {}` |
| 属性 | [`metadata`](#member-gfconfigtableresource-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_table_key`](#member-gfconfigtableresource-methods-get_table_key) | `func get_table_key() -> StringName:` |
| 方法 | [`get_id_field`](#member-gfconfigtableresource-methods-get_id_field) | `func get_id_field() -> StringName:` |
| 方法 | [`get_records`](#member-gfconfigtableresource-methods-get_records) | `func get_records(duplicate_records: bool = true) -> Array[Dictionary]:` |
| 方法 | [`get_records_by_id`](#member-gfconfigtableresource-methods-get_records_by_id) | `func get_records_by_id(duplicate_records: bool = true) -> Dictionary:` |
| 方法 | [`get_index_ids`](#member-gfconfigtableresource-methods-get_index_ids) | `func get_index_ids() -> PackedStringArray:` |
| 方法 | [`has_record`](#member-gfconfigtableresource-methods-has_record) | `func has_record(record_id: Variant) -> bool:` |
| 方法 | [`get_record`](#member-gfconfigtableresource-methods-get_record) | `func get_record(record_id: Variant, duplicate_record: bool = true) -> Variant:` |
| 方法 | [`make_index_key`](#member-gfconfigtableresource-methods-make_index_key) | `func make_index_key(index_id: StringName, record: Dictionary) -> String:` |
| 方法 | [`has_index_key`](#member-gfconfigtableresource-methods-has_index_key) | `func has_index_key(index_id: StringName, index_key: String) -> bool:` |
| 方法 | [`get_index_records`](#member-gfconfigtableresource-methods-get_index_records) | `func get_index_records(index_id: StringName, index_key: String, duplicate_records: bool = true) -> Array[Dictionary]:` |
| 方法 | [`get_index_record`](#member-gfconfigtableresource-methods-get_index_record) | `func get_index_record(index_id: StringName, index_key: String, duplicate_record: bool = true) -> Variant:` |
| 方法 | [`rebuild_index`](#member-gfconfigtableresource-methods-rebuild_index) | `func rebuild_index() -> int:` |
| 方法 | [`rebuild_indexes`](#member-gfconfigtableresource-methods-rebuild_indexes) | `func rebuild_indexes() -> int:` |
| 方法 | [`validate_records`](#member-gfconfigtableresource-methods-validate_records) | `func validate_records(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`duplicate_table`](#member-gfconfigtableresource-methods-duplicate_table) | `func duplicate_table() -> GFConfigTableResource:` |

## 属性

<a id="member-gfconfigtableresource-properties-table_name"></a>

### `table_name`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var table_name: StringName = &""
```

表名。为空时优先使用 schema.table_name。

<a id="member-gfconfigtableresource-properties-schema"></a>

### `schema`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var schema: GFConfigTableSchema = null
```

可选表结构声明，用于校验、字段转换和默认 ID 字段声明。

<a id="member-gfconfigtableresource-properties-records"></a>

### `records`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var records: Array[Dictionary] = []
```

表记录列表。记录顺序应保持导出时的稳定顺序，便于 Inspector、调试和确定性导出。

结构：

- `records`: Array[Dictionary]，每个 Dictionary 是一条配置记录。

<a id="member-gfconfigtableresource-properties-records_by_id"></a>

### `records_by_id`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var records_by_id: Dictionary = {}
```

可选 ID 索引。为空时 get_record() 会按 schema.id_field 或默认 id 字段扫描 records。

结构：

- `records_by_id`: Dictionary，键为配置记录 ID，值为对应记录 Dictionary。

<a id="member-gfconfigtableresource-properties-records_by_index"></a>

### `records_by_index`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var records_by_index: Dictionary = {}
```

可选命名索引缓存。为空时索引查询会按 schema.indexes 临时构建。

结构：

- `records_by_index`: Dictionary，键为索引 ID，值为索引键到记录列表的 Dictionary。

<a id="member-gfconfigtableresource-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var metadata: Dictionary = {}
```

可选元数据，供导入器、编辑器或项目层扩展使用。

结构：

- `metadata`: Dictionary，保存导表来源、构建摘要或项目侧附加信息。

## 方法

<a id="member-gfconfigtableresource-methods-get_table_key"></a>

### `get_table_key`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_table_key() -> StringName:
```

获取稳定表键。

返回：表名；本资源未声明且 schema 也未声明时返回空 StringName。

<a id="member-gfconfigtableresource-methods-get_id_field"></a>

### `get_id_field`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_id_field() -> StringName:
```

获取用于构建默认索引的 ID 字段。

返回：ID 字段名；schema 显式声明空 id_field 时返回空 StringName。

<a id="member-gfconfigtableresource-methods-get_records"></a>

### `get_records`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_records(duplicate_records: bool = true) -> Array[Dictionary]:
```

获取表记录列表。

参数：

| 名称 | 说明 |
|---|---|
| `duplicate_records` | 为 true 时返回记录深拷贝，避免调用方修改资源内数据。 |

返回：表记录列表。

结构：

- `return`: Array[Dictionary]，每个 Dictionary 是一条配置记录。

<a id="member-gfconfigtableresource-methods-get_records_by_id"></a>

### `get_records_by_id`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_records_by_id(duplicate_records: bool = true) -> Dictionary:
```

获取 ID 索引。

参数：

| 名称 | 说明 |
|---|---|
| `duplicate_records` | 为 true 时返回记录深拷贝，避免调用方修改资源内数据。 |

返回：ID 索引副本；records_by_id 为空时按 records 临时构建。

结构：

- `return`: Dictionary，键为配置记录 ID，值为对应记录 Dictionary。

<a id="member-gfconfigtableresource-methods-get_index_ids"></a>

### `get_index_ids`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_index_ids() -> PackedStringArray:
```

获取当前可查询的命名索引 ID。

返回：排序后的索引 ID 列表。

<a id="member-gfconfigtableresource-methods-has_record"></a>

### `has_record`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func has_record(record_id: Variant) -> bool:
```

检查记录是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `record_id` | 记录 ID。 |

返回：存在返回 true。

结构：

- `record_id`: Variant，项目配置表使用的记录键，通常为 String、StringName 或 int。

<a id="member-gfconfigtableresource-methods-get_record"></a>

### `get_record`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_record(record_id: Variant, duplicate_record: bool = true) -> Variant:
```

根据 ID 获取记录。

参数：

| 名称 | 说明 |
|---|---|
| `record_id` | 记录 ID。 |
| `duplicate_record` | 为 true 时返回记录深拷贝，避免调用方修改资源内数据。 |

返回：找到时返回记录 Dictionary，否则返回 null。

结构：

- `record_id`: Variant，项目配置表使用的记录键，通常为 String、StringName 或 int。
- `return`: Variant，找到时为 Dictionary，未命中时为 null。

<a id="member-gfconfigtableresource-methods-make_index_key"></a>

### `make_index_key`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func make_index_key(index_id: StringName, record: Dictionary) -> String:
```

根据索引声明构建索引键。

参数：

| 名称 | 说明 |
|---|---|
| `index_id` | 索引 ID。 |
| `record` | 用于构建索引键的记录或字段值字典。 |

返回：索引键；索引不存在、字段缺失或字段值不符合索引声明时返回空字符串。

结构：

- `record`: Dictionary，键为索引字段名，值为字段数据。

<a id="member-gfconfigtableresource-methods-has_index_key"></a>

### `has_index_key`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func has_index_key(index_id: StringName, index_key: String) -> bool:
```

检查命名索引键是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `index_id` | 索引 ID。 |
| `index_key` | 由 make_index_key() 或同等规则生成的索引键。 |

返回：存在返回 true。

<a id="member-gfconfigtableresource-methods-get_index_records"></a>

### `get_index_records`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_index_records(index_id: StringName, index_key: String, duplicate_records: bool = true) -> Array[Dictionary]:
```

根据命名索引获取记录列表。

参数：

| 名称 | 说明 |
|---|---|
| `index_id` | 索引 ID。 |
| `index_key` | 由 make_index_key() 或同等规则生成的索引键。 |
| `duplicate_records` | 为 true 时返回记录深拷贝，避免调用方修改资源内数据。 |

返回：命中的记录列表；未命中时返回空数组。

结构：

- `return`: Array[Dictionary]，每个 Dictionary 是一条配置记录。

<a id="member-gfconfigtableresource-methods-get_index_record"></a>

### `get_index_record`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_index_record(index_id: StringName, index_key: String, duplicate_record: bool = true) -> Variant:
```

根据命名索引获取第一条记录。

参数：

| 名称 | 说明 |
|---|---|
| `index_id` | 索引 ID。 |
| `index_key` | 由 make_index_key() 或同等规则生成的索引键。 |
| `duplicate_record` | 为 true 时返回记录深拷贝，避免调用方修改资源内数据。 |

返回：找到时返回第一条记录 Dictionary，否则返回 null。

结构：

- `return`: Variant，找到时为 Dictionary，未命中时为 null。

<a id="member-gfconfigtableresource-methods-rebuild_index"></a>

### `rebuild_index`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func rebuild_index() -> int:
```

按 records 重建 records_by_id。

返回：新索引中的记录数量。

<a id="member-gfconfigtableresource-methods-rebuild_indexes"></a>

### `rebuild_indexes`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func rebuild_indexes() -> int:
```

按 schema.indexes 重建 records_by_index。

返回：新索引缓存中的索引数量。

<a id="member-gfconfigtableresource-methods-validate_records"></a>

### `validate_records`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func validate_records(options: Dictionary = {}) -> Dictionary:
```

使用 schema 校验当前记录列表。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选上下文，支持 source、row_locations 等校验报告字段。 |

返回：校验报告字典。

结构：

- `options`: Dictionary，可包含 source、line、column、row_index、column_index 和 row_locations。
- `return`: GFConfigValidationReport 兼容 Dictionary。

<a id="member-gfconfigtableresource-methods-duplicate_table"></a>

### `duplicate_table`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func duplicate_table() -> GFConfigTableResource:
```

创建同内容拷贝，避免运行时修改污染共享 Resource。

返回：新配置表资源。
