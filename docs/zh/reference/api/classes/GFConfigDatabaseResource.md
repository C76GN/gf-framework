# GFConfigDatabaseResource

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_database_resource.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`5.2.0`

可保存为 Godot Resource 的通用配置数据库。 用于聚合多张 GFConfigTableResource，作为导表工具生成的整包配置产物。 该资源只承载通用表集合、校验入口和元数据，不绑定业务表语义、构建 profile 或热更新策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`database_id`](#member-gfconfigdatabaseresource-properties-database_id) | `var database_id: StringName = &""` |
| 属性 | [`version`](#member-gfconfigdatabaseresource-properties-version) | `var version: String = ""` |
| 属性 | [`tables`](#member-gfconfigdatabaseresource-properties-tables) | `var tables: Array[GFConfigTableResource] = []` |
| 属性 | [`metadata`](#member-gfconfigdatabaseresource-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_database_key`](#member-gfconfigdatabaseresource-methods-get_database_key) | `func get_database_key() -> StringName:` |
| 方法 | [`register_table`](#member-gfconfigdatabaseresource-methods-register_table) | `func register_table(table_resource: GFConfigTableResource) -> bool:` |
| 方法 | [`register_tables`](#member-gfconfigdatabaseresource-methods-register_tables) | `func register_tables(table_resources: Array[GFConfigTableResource]) -> int:` |
| 方法 | [`unregister_table`](#member-gfconfigdatabaseresource-methods-unregister_table) | `func unregister_table(table_name: StringName) -> bool:` |
| 方法 | [`clear_tables`](#member-gfconfigdatabaseresource-methods-clear_tables) | `func clear_tables() -> void:` |
| 方法 | [`has_table`](#member-gfconfigdatabaseresource-methods-has_table) | `func has_table(table_name: StringName) -> bool:` |
| 方法 | [`get_table_ids`](#member-gfconfigdatabaseresource-methods-get_table_ids) | `func get_table_ids() -> PackedStringArray:` |
| 方法 | [`get_tables_by_name`](#member-gfconfigdatabaseresource-methods-get_tables_by_name) | `func get_tables_by_name(duplicate_records: bool = true) -> Dictionary:` |
| 方法 | [`get_schemas`](#member-gfconfigdatabaseresource-methods-get_schemas) | `func get_schemas(duplicate_schemas: bool = true) -> Array[GFConfigTableSchema]:` |
| 方法 | [`get_table_resources`](#member-gfconfigdatabaseresource-methods-get_table_resources) | `func get_table_resources(duplicate_tables: bool = true) -> Array[GFConfigTableResource]:` |
| 方法 | [`get_table_resource`](#member-gfconfigdatabaseresource-methods-get_table_resource) | `func get_table_resource(table_name: StringName, duplicate_table: bool = true) -> GFConfigTableResource:` |
| 方法 | [`validate_database`](#member-gfconfigdatabaseresource-methods-validate_database) | `func validate_database(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`rebuild_table_indexes`](#member-gfconfigdatabaseresource-methods-rebuild_table_indexes) | `func rebuild_table_indexes() -> int:` |
| 方法 | [`duplicate_database`](#member-gfconfigdatabaseresource-methods-duplicate_database) | `func duplicate_database() -> GFConfigDatabaseResource:` |

## 属性

<a id="member-gfconfigdatabaseresource-properties-database_id"></a>

### `database_id`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var database_id: StringName = &""
```

配置数据库稳定标识。可用于区分主配置、测试配置或项目侧不同配置集合。

<a id="member-gfconfigdatabaseresource-properties-version"></a>

### `version`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var version: String = ""
```

可选配置版本。GF 不解释版本语义，只保存导表工具或项目层写入的字符串。

<a id="member-gfconfigdatabaseresource-properties-tables"></a>

### `tables`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
var tables: Array[GFConfigTableResource] = []
```

配置表资源列表。表名由每张 GFConfigTableResource.get_table_key() 决定。

结构：

- `tables`: Array[GFConfigTableResource]，每个元素是一张配置表资源。

<a id="member-gfconfigdatabaseresource-properties-metadata"></a>

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

<a id="member-gfconfigdatabaseresource-methods-get_database_key"></a>

### `get_database_key`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_database_key() -> StringName:
```

获取配置数据库稳定标识。

返回：配置数据库 ID；未声明时返回空 StringName。

<a id="member-gfconfigdatabaseresource-methods-register_table"></a>

### `register_table`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func register_table(table_resource: GFConfigTableResource) -> bool:
```

注册一张配置表资源。

参数：

| 名称 | 说明 |
|---|---|
| `table_resource` | 要注册的配置表资源。 |

返回：注册成功返回 true。

<a id="member-gfconfigdatabaseresource-methods-register_tables"></a>

### `register_tables`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func register_tables(table_resources: Array[GFConfigTableResource]) -> int:
```

批量注册配置表资源。

参数：

| 名称 | 说明 |
|---|---|
| `table_resources` | 要注册的配置表资源列表。 |

返回：成功注册的数量。

结构：

- `table_resources`: Array[GFConfigTableResource]，每个元素是一张配置表资源。

<a id="member-gfconfigdatabaseresource-methods-unregister_table"></a>

### `unregister_table`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func unregister_table(table_name: StringName) -> bool:
```

注销配置表资源。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：找到并移除时返回 true。

<a id="member-gfconfigdatabaseresource-methods-clear_tables"></a>

### `clear_tables`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func clear_tables() -> void:
```

清空所有配置表资源。

<a id="member-gfconfigdatabaseresource-methods-has_table"></a>

### `has_table`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func has_table(table_name: StringName) -> bool:
```

检查配置表是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：存在返回 true。

<a id="member-gfconfigdatabaseresource-methods-get_table_ids"></a>

### `get_table_ids`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_table_ids() -> PackedStringArray:
```

获取配置表名列表。

返回：排序后的表名列表。

<a id="member-gfconfigdatabaseresource-methods-get_tables_by_name"></a>

### `get_tables_by_name`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_tables_by_name(duplicate_records: bool = true) -> Dictionary:
```

获取表名到表数据的字典。

参数：

| 名称 | 说明 |
|---|---|
| `duplicate_records` | 为 true 时返回记录深拷贝，避免调用方修改数据库资源内数据。 |

返回：表名到表数据的字典。

结构：

- `return`: Dictionary，键为表名 StringName，值为 Array[Dictionary] 表数据。

<a id="member-gfconfigdatabaseresource-methods-get_schemas"></a>

### `get_schemas`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_schemas(duplicate_schemas: bool = true) -> Array[GFConfigTableSchema]:
```

获取数据库中的 schema 列表。

参数：

| 名称 | 说明 |
|---|---|
| `duplicate_schemas` | 为 true 时返回 schema 深拷贝，避免调用方修改数据库资源内数据。 |

返回：schema 列表。

结构：

- `return`: Array[GFConfigTableSchema]，每个元素是一张表的 schema。

<a id="member-gfconfigdatabaseresource-methods-get_table_resources"></a>

### `get_table_resources`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_table_resources(duplicate_tables: bool = true) -> Array[GFConfigTableResource]:
```

获取配置表资源列表。

参数：

| 名称 | 说明 |
|---|---|
| `duplicate_tables` | 为 true 时返回资源深拷贝，避免调用方修改数据库资源内数据。 |

返回：表资源列表。

结构：

- `return`: Array[GFConfigTableResource]，每个元素是一张配置表资源。

<a id="member-gfconfigdatabaseresource-methods-get_table_resource"></a>

### `get_table_resource`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_table_resource(table_name: StringName, duplicate_table: bool = true) -> GFConfigTableResource:
```

获取配置表资源。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `duplicate_table` | 为 true 时返回资源深拷贝，避免调用方修改数据库资源内数据。 |

返回：配置表资源；未命中时返回 null。

<a id="member-gfconfigdatabaseresource-methods-validate_database"></a>

### `validate_database`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func validate_database(options: Dictionary = {}) -> Dictionary:
```

校验数据库中的表结构、表数据和跨表引用。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选上下文，支持 validate_schema，并透传给引用校验器。 |

返回：聚合校验报告字典。

结构：

- `options`: Dictionary，可包含 validate_schema。
- `return`: GFConfigValidationReport 兼容 Dictionary。

<a id="member-gfconfigdatabaseresource-methods-rebuild_table_indexes"></a>

### `rebuild_table_indexes`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func rebuild_table_indexes() -> int:
```

重建所有表资源的 ID 索引和命名索引缓存。

返回：成功处理的有效表数量。

<a id="member-gfconfigdatabaseresource-methods-duplicate_database"></a>

### `duplicate_database`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func duplicate_database() -> GFConfigDatabaseResource:
```

创建同内容拷贝，避免运行时修改污染共享 Resource。

返回：新配置数据库资源。
