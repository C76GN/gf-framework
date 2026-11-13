# GFResourceConfigProvider

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_resource_config_provider.gd`
- 模块：`Standard`
- 继承：`GFConfigProvider`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`5.2.0`

通过已验收快照发布 Resource 配置集合。 作者资源可以编辑；运行查询读取隔离快照。替换、增量更新和移除均先验证 完整候选，随后检查发布代际，失败不会留下部分新表。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`prepare_database`](#member-gfresourceconfigprovider-methods-prepare_database) | `func prepare_database(database: GFConfigDatabaseResource, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`replace_database`](#member-gfresourceconfigprovider-methods-replace_database) | `func replace_database(database: GFConfigDatabaseResource, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`prepare_update`](#member-gfresourceconfigprovider-methods-prepare_update) | `func prepare_update(tables: Array[GFConfigTableResource], options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`update_tables`](#member-gfresourceconfigprovider-methods-update_tables) | `func update_tables(tables: Array[GFConfigTableResource], options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`from_database`](#member-gfresourceconfigprovider-methods-from_database) | `static func from_database(database: GFConfigDatabaseResource) -> GFResourceConfigProvider:` |
| 方法 | [`has_table`](#member-gfresourceconfigprovider-methods-has_table) | `func has_table(table_name: StringName) -> bool:` |
| 方法 | [`get_table_ids`](#member-gfresourceconfigprovider-methods-get_table_ids) | `func get_table_ids() -> PackedStringArray:` |
| 方法 | [`get_table_resource`](#member-gfresourceconfigprovider-methods-get_table_resource) | `func get_table_resource(table_name: StringName) -> GFConfigTableResource:` |
| 方法 | [`get_table_resources`](#member-gfresourceconfigprovider-methods-get_table_resources) | `func get_table_resources() -> Array[GFConfigTableResource]:` |
| 方法 | [`get_record`](#member-gfresourceconfigprovider-methods-get_record) | `func get_record(table_name: StringName, record_id: Variant) -> Variant:` |
| 方法 | [`get_table`](#member-gfresourceconfigprovider-methods-get_table) | `func get_table(table_name: StringName) -> Variant:` |
| 方法 | [`make_index_key`](#member-gfresourceconfigprovider-methods-make_index_key) | `func make_index_key( table_name: StringName, index_id: StringName, record: Dictionary ) -> String:` |
| 方法 | [`has_index_key`](#member-gfresourceconfigprovider-methods-has_index_key) | `func has_index_key( table_name: StringName, index_id: StringName, index_key: String ) -> bool:` |
| 方法 | [`get_index_records`](#member-gfresourceconfigprovider-methods-get_index_records) | `func get_index_records( table_name: StringName, index_id: StringName, index_key: String ) -> Array[Dictionary]:` |
| 方法 | [`get_index_record`](#member-gfresourceconfigprovider-methods-get_index_record) | `func get_index_record( table_name: StringName, index_id: StringName, index_key: String ) -> Variant:` |

## 方法

<a id="member-gfresourceconfigprovider-methods-prepare_database"></a>

### `prepare_database`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func prepare_database(database: GFConfigDatabaseResource, options: Dictionary = {}) -> Dictionary:
```

准备完整数据库候选，保留准备开始时的代际供发布使用。

参数：

| 名称 | 说明 |
|---|---|
| `database` | 待捕获的作者数据库。 |
| `options` | 候选工作预算。 |

返回：捕获结果及 expected_generation。

结构：

- `options`: Dictionary，可包含 work_budget 或 work_limits；不接受增量 base_snapshot。
- `return`: GFConfigSnapshot.capture() 结果，另含 expected_generation: int。

<a id="member-gfresourceconfigprovider-methods-replace_database"></a>

### `replace_database`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func replace_database(database: GFConfigDatabaseResource, options: Dictionary = {}) -> Dictionary:
```

捕获并原子替换完整数据库；校验期间发生其他发布时拒绝旧候选。

参数：

| 名称 | 说明 |
|---|---|
| `database` | 待发布的数据库。 |
| `options` | 捕获预算。 |

返回：包含捕获诊断与发布状态的结果。

结构：

- `options`: Dictionary，可包含 work_budget 或 work_limits。
- `return`: Dictionary，含 ok、error_kind、generation、validation_report、work_report。

<a id="member-gfresourceconfigprovider-methods-prepare_update"></a>

### `prepare_update`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func prepare_update(tables: Array[GFConfigTableResource], options: Dictionary = {}) -> Dictionary:
```

基于当前快照准备增量候选，校验合并后的跨表引用。

参数：

| 名称 | 说明 |
|---|---|
| `tables` | 本次新增或替换的表。 |
| `options` | 移除项、内容版本与捕获预算。 |

返回：捕获结果及 expected_generation；不修改当前快照。

结构：

- `tables`: Array[GFConfigTableResource]，同一表只能出现一次。
- `options`: Dictionary，可包含 removed_tables: PackedStringArray、version: String、work_budget 或 work_limits。
- `return`: GFConfigSnapshot.capture() 结果，另含 expected_generation: int。

<a id="member-gfresourceconfigprovider-methods-update_tables"></a>

### `update_tables`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func update_tables(tables: Array[GFConfigTableResource], options: Dictionary = {}) -> Dictionary:
```

验收并原子发布增量更新，包括明确声明的移除项。

参数：

| 名称 | 说明 |
|---|---|
| `tables` | 新增或替换的表。 |
| `options` | 与 prepare_update() 相同。 |

返回：捕获诊断及发布状态，失败保留当前快照。

结构：

- `tables`: Array[GFConfigTableResource]，每个表是本次候选。
- `options`: Dictionary，可包含 removed_tables、version、work_budget 或 work_limits。
- `return`: Dictionary，含 ok、error_kind、generation、validation_report、work_report。

<a id="member-gfresourceconfigprovider-methods-from_database"></a>

### `from_database`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
static func from_database(database: GFConfigDatabaseResource) -> GFResourceConfigProvider:
```

从完整数据库创建已发布的 Provider。

参数：

| 名称 | 说明 |
|---|---|
| `database` | 待捕获的数据库。 |

返回：已发布 Provider；任一候选校验失败时为 null。

<a id="member-gfresourceconfigprovider-methods-has_table"></a>

### `has_table`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func has_table(table_name: StringName) -> bool:
```

检查当前快照是否包含表，未准备不表示来源不存在。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：已准备时为 true。

<a id="member-gfresourceconfigprovider-methods-get_table_ids"></a>

### `get_table_ids`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_table_ids() -> PackedStringArray:
```

取得已发布的表名。

返回：排序后的表名。

<a id="member-gfresourceconfigprovider-methods-get_table_resource"></a>

### `get_table_resource`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_table_resource(table_name: StringName) -> GFConfigTableResource:
```

取得已发布表的作者副本，用于构建下一次候选。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：表副本；未准备时为 null。

<a id="member-gfresourceconfigprovider-methods-get_table_resources"></a>

### `get_table_resources`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_table_resources() -> Array[GFConfigTableResource]:
```

取得全部已发布表的独立副本。

返回：表资源副本；任一复制失败时返回空集合。

结构：

- `return`: Array[GFConfigTableResource]。

<a id="member-gfresourceconfigprovider-methods-get_record"></a>

### `get_record`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_record(table_name: StringName, record_id: Variant) -> Variant:
```

从当前快照查询记录副本，不隐式加载或更新表。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `record_id` | 记录 ID。 |

返回：记录副本或 null。

结构：

- `record_id`: Variant，使用项目声明的记录键类型。
- `return`: Dictionary 或 null。

<a id="member-gfresourceconfigprovider-methods-get_table"></a>

### `get_table`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_table(table_name: StringName) -> Variant:
```

从当前快照查询整表副本，不执行来源回调。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：表记录副本或 null。

结构：

- `return`: Array[Dictionary] 或 null。

<a id="member-gfresourceconfigprovider-methods-make_index_key"></a>

### `make_index_key`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func make_index_key( table_name: StringName, index_id: StringName, record: Dictionary ) -> String:
```

按命名索引声明生成查询键。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `index_id` | 索引 ID。 |
| `record` | 索引字段数据。 |

返回：查询键；无效时为空。

结构：

- `record`: Dictionary，含索引所需字段。

<a id="member-gfresourceconfigprovider-methods-has_index_key"></a>

### `has_index_key`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func has_index_key( table_name: StringName, index_id: StringName, index_key: String ) -> bool:
```

检查命名索引键。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `index_id` | 索引 ID。 |
| `index_key` | 编码后的查询键。 |

返回：命中时为 true。

<a id="member-gfresourceconfigprovider-methods-get_index_records"></a>

### `get_index_records`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_index_records( table_name: StringName, index_id: StringName, index_key: String ) -> Array[Dictionary]:
```

返回命名索引命中的记录副本。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `index_id` | 索引 ID。 |
| `index_key` | 编码后的查询键。 |

返回：匹配记录副本；未命中时为空。

结构：

- `return`: Array[Dictionary]。

<a id="member-gfresourceconfigprovider-methods-get_index_record"></a>

### `get_index_record`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_index_record( table_name: StringName, index_id: StringName, index_key: String ) -> Variant:
```

返回命名索引命中的第一条记录副本。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `index_id` | 索引 ID。 |
| `index_key` | 编码后的查询键。 |

返回：第一条匹配记录，未命中时为 null。

结构：

- `return`: Dictionary 或 null。
