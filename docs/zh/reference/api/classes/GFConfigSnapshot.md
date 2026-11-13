# GFConfigSnapshot

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_snapshot.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

已验收配置集合的独立查询快照。 捕获时隔离表、schema 和集合，查询返回副本；增量候选复用未改变的内部表。 Resource 字段保留共享资产身份，不承诺资产内部状态不可变。自定义校验规则 仍属于受信任代码；快照只保证通过公开入口不能改写已捕获的配置集合。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`capture`](#member-gfconfigsnapshot-methods-capture) | `static func capture(database: GFConfigDatabaseResource, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`is_ready`](#member-gfconfigsnapshot-methods-is_ready) | `func is_ready() -> bool:` |
| 方法 | [`get_database_id`](#member-gfconfigsnapshot-methods-get_database_id) | `func get_database_id() -> StringName:` |
| 方法 | [`get_version`](#member-gfconfigsnapshot-methods-get_version) | `func get_version() -> String:` |
| 方法 | [`get_digest_report`](#member-gfconfigsnapshot-methods-get_digest_report) | `func get_digest_report() -> Dictionary:` |
| 方法 | [`get_table_ids`](#member-gfconfigsnapshot-methods-get_table_ids) | `func get_table_ids() -> PackedStringArray:` |
| 方法 | [`has_table`](#member-gfconfigsnapshot-methods-has_table) | `func has_table(table_name: StringName) -> bool:` |
| 方法 | [`get_table_resource`](#member-gfconfigsnapshot-methods-get_table_resource) | `func get_table_resource(table_name: StringName) -> GFConfigTableResource:` |
| 方法 | [`get_schema`](#member-gfconfigsnapshot-methods-get_schema) | `func get_schema(table_name: StringName) -> GFConfigTableSchema:` |
| 方法 | [`has_schema`](#member-gfconfigsnapshot-methods-has_schema) | `func has_schema(table_name: StringName) -> bool:` |
| 方法 | [`get_record`](#member-gfconfigsnapshot-methods-get_record) | `func get_record(table_name: StringName, record_id: Variant) -> Variant:` |
| 方法 | [`get_table`](#member-gfconfigsnapshot-methods-get_table) | `func get_table(table_name: StringName) -> Variant:` |
| 方法 | [`make_index_key`](#member-gfconfigsnapshot-methods-make_index_key) | `func make_index_key( table_name: StringName, index_id: StringName, record: Dictionary ) -> String:` |
| 方法 | [`get_index_records`](#member-gfconfigsnapshot-methods-get_index_records) | `func get_index_records( table_name: StringName, index_id: StringName, index_key: String ) -> Array[Dictionary]:` |
| 方法 | [`has_index_key`](#member-gfconfigsnapshot-methods-has_index_key) | `func has_index_key( table_name: StringName, index_id: StringName, index_key: String ) -> bool:` |
| 方法 | [`get_index_record`](#member-gfconfigsnapshot-methods-get_index_record) | `func get_index_record( table_name: StringName, index_id: StringName, index_key: String ) -> Variant:` |

## 方法

<a id="member-gfconfigsnapshot-methods-capture"></a>

### `capture`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func capture(database: GFConfigDatabaseResource, options: Dictionary = {}) -> Dictionary:
```

捕获完整或增量候选，校验失败不返回部分快照。 database.tables 是本次新增/替换集合；提供 base_snapshot 时，其余表复用旧快照。 引用校验覆盖合并后的集合，移除仍被引用的表会失败。输入缓存索引不被信任。

参数：

| 名称 | 说明 |
|---|---|
| `database` | 本次候选的作者数据。 |
| `options` | 增量来源、移除项和工作预算。 |

返回：包含完整候选或失败原因的结果。

结构：

- `options`: Dictionary，可包含 base_snapshot: GFConfigSnapshot、removed_tables: PackedStringArray、work_budget: GFConfigWorkBudget 或 work_limits: Dictionary。
- `return`: Dictionary，含 ok: bool、snapshot: GFConfigSnapshot 或 null、error_kind: StringName、validation_report: Dictionary、work_report: Dictionary。

<a id="member-gfconfigsnapshot-methods-is_ready"></a>

### `is_ready`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_ready() -> bool:
```

检查快照是否已通过完整捕获与校验。

返回：可发布时为 true。

<a id="member-gfconfigsnapshot-methods-get_database_id"></a>

### `get_database_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_database_id() -> StringName:
```

读取配置集合身份。

返回：捕获时的 database_id。

<a id="member-gfconfigsnapshot-methods-get_version"></a>

### `get_version`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_version() -> String:
```

读取项目声明的内容版本。

返回：捕获时的版本字符串。

<a id="member-gfconfigsnapshot-methods-get_digest_report"></a>

### `get_digest_report`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_digest_report() -> Dictionary:
```

返回规范内容摘要与覆盖范围。 包含记录、schema 描述、表元数据、集合身份与版本。Resource 值或编码预算 不支持时 complete 为 false 且 value 为空；这不会拒绝合法的共享资产配置。 摘要不包含自定义校验代码实现，也不证明外部资产内容或跨版本浮点计算一致。

返回：独立摘要报告。

结构：

- `return`: Dictionary，含 algorithm: StringName、value: String、complete: bool、unavailable_tables: PackedStringArray。

<a id="member-gfconfigsnapshot-methods-get_table_ids"></a>

### `get_table_ids`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_table_ids() -> PackedStringArray:
```

取得已捕获的表名，排序且不暴露内部集合。

返回：已准备表名列表。

<a id="member-gfconfigsnapshot-methods-has_table"></a>

### `has_table`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func has_table(table_name: StringName) -> bool:
```

检查该表是否已包含在此快照中。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：已准备时为 true；未准备不等价于来源不存在。

<a id="member-gfconfigsnapshot-methods-get_table_resource"></a>

### `get_table_resource`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_table_resource(table_name: StringName) -> GFConfigTableResource:
```

取得独立的表资源副本，可用于编辑新的候选。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：表副本；未准备时为 null。

<a id="member-gfconfigsnapshot-methods-get_schema"></a>

### `get_schema`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_schema(table_name: StringName) -> GFConfigTableSchema:
```

取得独立的 schema 副本。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：schema 副本；表或声明不存在时为 null。

<a id="member-gfconfigsnapshot-methods-has_schema"></a>

### `has_schema`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func has_schema(table_name: StringName) -> bool:
```

检查 schema 是否存在，不复制声明。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：已捕获该表且包含声明时为 true。

<a id="member-gfconfigsnapshot-methods-get_record"></a>

### `get_record`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_record(table_name: StringName, record_id: Variant) -> Variant:
```

按稳定记录 ID 查询副本。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `record_id` | 项目记录 ID。 |

返回：记录副本或 null。

结构：

- `record_id`: Variant，使用表 schema 声明的 ID 值类型。
- `return`: Dictionary 记录或 null。

<a id="member-gfconfigsnapshot-methods-get_table"></a>

### `get_table`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_table(table_name: StringName) -> Variant:
```

取得整表记录副本。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：已准备表的记录副本；未准备时为 null。

结构：

- `return`: Array[Dictionary] 或 null。

<a id="member-gfconfigsnapshot-methods-make_index_key"></a>

### `make_index_key`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func make_index_key( table_name: StringName, index_id: StringName, record: Dictionary ) -> String:
```

按命名索引声明生成键。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `index_id` | 索引 ID。 |
| `record` | 参与索引的字段数据。 |

返回：索引键；缺少表或索引时为空。

结构：

- `record`: Dictionary，含命名索引要求的字段。

<a id="member-gfconfigsnapshot-methods-get_index_records"></a>

### `get_index_records`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_index_records( table_name: StringName, index_id: StringName, index_key: String ) -> Array[Dictionary]:
```

取得命名索引命中的记录副本。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `index_id` | 索引 ID。 |
| `index_key` | 编码后的索引键。 |

返回：命中记录，未命中时为空。

结构：

- `return`: Array[Dictionary]，不会暴露内部记录集合。

<a id="member-gfconfigsnapshot-methods-has_index_key"></a>

### `has_index_key`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func has_index_key( table_name: StringName, index_id: StringName, index_key: String ) -> bool:
```

检查索引键，不复制命中记录。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `index_id` | 索引 ID。 |
| `index_key` | 编码后的索引键。 |

返回：命中时为 true。

<a id="member-gfconfigsnapshot-methods-get_index_record"></a>

### `get_index_record`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_index_record( table_name: StringName, index_id: StringName, index_key: String ) -> Variant:
```

取得索引首条记录副本，避免复制全部命中项。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `index_id` | 索引 ID。 |
| `index_key` | 编码后的索引键。 |

返回：首条记录副本或 null。

结构：

- `return`: Dictionary 或 null。
