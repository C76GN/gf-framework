# GFConfigReferenceResolver

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_reference_resolver.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用导表引用校验与解析工具。 在多张表加载后统一检查引用、构建复合索引，并可把记录中的引用解析为目标记录副本。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`build_index`](#member-gfconfigreferenceresolver-methods-build_index) | `static func build_index(table_data: Variant, field_names: PackedStringArray) -> Dictionary:` |
| 方法 | [`validate_tables`](#member-gfconfigreferenceresolver-methods-validate_tables) | `static func validate_tables( tables_by_name: Dictionary, schemas: Array[GFConfigTableSchema], options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`resolve_record_references`](#member-gfconfigreferenceresolver-methods-resolve_record_references) | `static func resolve_record_references( record: Dictionary, schema: GFConfigTableSchema, tables_by_name: Dictionary, schemas_by_name: Dictionary = {} ) -> Dictionary:` |

## 方法

<a id="member-gfconfigreferenceresolver-methods-build_index"></a>

### `build_index`

- API：`public`

```gdscript
static func build_index(table_data: Variant, field_names: PackedStringArray) -> Dictionary:
```

构建表数据索引。

参数：

| 名称 | 说明 |
|---|---|
| `table_data` | Array[Dictionary] 或 Dictionary 形式的表数据。 |
| `field_names` | 参与索引的字段名。 |

返回：索引字典，key 为复合键，value 为记录数组。

结构：

- `table_data`: Variant，支持 Array[Dictionary] 或 Dictionary，记录值必须为 Dictionary。
- `return`: Dictionary，键为复合索引字符串，值为匹配记录副本组成的 Array[Dictionary]。

<a id="member-gfconfigreferenceresolver-methods-validate_tables"></a>

### `validate_tables`

- API：`public`

```gdscript
static func validate_tables( tables_by_name: Dictionary, schemas: Array[GFConfigTableSchema], options: Dictionary = {} ) -> Dictionary:
```

校验多张表的 schema 与引用关系。

参数：

| 名称 | 说明 |
|---|---|
| `tables_by_name` | 表名到表数据的字典。 |
| `schemas` | schema 列表。 |
| `options` | 可选参数，当前支持 validate_schema。 |

返回：聚合校验报告字典。

结构：

- `tables_by_name`: Dictionary，键为表名 StringName，值为 Array[Dictionary] 或 Dictionary 表数据。
- `schemas`: Array[GFConfigTableSchema]，参与校验的表结构声明。
- `options`: Dictionary，可包含 validate_schema。
- `return`: GFConfigValidationReport 兼容 Dictionary。

<a id="member-gfconfigreferenceresolver-methods-resolve_record_references"></a>

### `resolve_record_references`

- API：`public`

```gdscript
static func resolve_record_references( record: Dictionary, schema: GFConfigTableSchema, tables_by_name: Dictionary, schemas_by_name: Dictionary = {} ) -> Dictionary:
```

解析单条记录的引用目标。

参数：

| 名称 | 说明 |
|---|---|
| `record` | 来源记录。 |
| `schema` | 来源 schema。 |
| `tables_by_name` | 表名到表数据的字典。 |
| `schemas_by_name` | 可选 schema 字典。 |

返回：引用 ID 到目标记录副本的字典。

结构：

- `record`: Dictionary，来源配置记录。
- `tables_by_name`: Dictionary，键为表名 StringName，值为 Array[Dictionary] 或 Dictionary 表数据。
- `schemas_by_name`: Dictionary，键为表名 StringName，值为 GFConfigTableSchema。
- `return`: Dictionary，键为 reference_id，值为解析出的目标记录 Dictionary 副本。
