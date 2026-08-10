# GFResourceConfigProvider

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_resource_config_provider.gd`
- 模块：`Standard`
- 继承：`GFConfigProvider`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`5.2.0`

读取 GFConfigTableResource 的运行时配置 Provider。 用于把导表工具生成的 `.tres` / `.res` 表资源接入 `GFConfigProvider` 查询协议。 它只处理通用表资源注册、表查询和记录查询，不绑定业务字段、构建 profile 或热更新策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`register_table`](#member-gfresourceconfigprovider-methods-register_table) | `func register_table(table_resource: GFConfigTableResource) -> bool:` |
| 方法 | [`register_tables`](#member-gfresourceconfigprovider-methods-register_tables) | `func register_tables(table_resources: Array[GFConfigTableResource]) -> int:` |
| 方法 | [`set_table_resources`](#member-gfresourceconfigprovider-methods-set_table_resources) | `func set_table_resources(table_resources: Array[GFConfigTableResource], duplicate_tables: bool = false) -> int:` |
| 方法 | [`get_table_resources`](#member-gfresourceconfigprovider-methods-get_table_resources) | `func get_table_resources(duplicate_tables: bool = true) -> Array[GFConfigTableResource]:` |
| 方法 | [`from_database`](#member-gfresourceconfigprovider-methods-from_database) | `static func from_database(database: GFConfigDatabaseResource, duplicate_tables: bool = false) -> GFResourceConfigProvider:` |
| 方法 | [`rebuild_table_registry`](#member-gfresourceconfigprovider-methods-rebuild_table_registry) | `func rebuild_table_registry() -> int:` |
| 方法 | [`unregister_table`](#member-gfresourceconfigprovider-methods-unregister_table) | `func unregister_table(table_name: StringName) -> bool:` |
| 方法 | [`clear_tables`](#member-gfresourceconfigprovider-methods-clear_tables) | `func clear_tables() -> void:` |
| 方法 | [`has_table`](#member-gfresourceconfigprovider-methods-has_table) | `func has_table(table_name: StringName) -> bool:` |
| 方法 | [`get_table_ids`](#member-gfresourceconfigprovider-methods-get_table_ids) | `func get_table_ids() -> PackedStringArray:` |
| 方法 | [`get_table_resource`](#member-gfresourceconfigprovider-methods-get_table_resource) | `func get_table_resource(table_name: StringName, duplicate_table: bool = true) -> GFConfigTableResource:` |
| 方法 | [`get_record`](#member-gfresourceconfigprovider-methods-get_record) | `func get_record(table_name: StringName, record_id: Variant) -> Variant:` |
| 方法 | [`make_index_key`](#member-gfresourceconfigprovider-methods-make_index_key) | `func make_index_key(table_name: StringName, index_id: StringName, record: Dictionary) -> String:` |
| 方法 | [`has_index_key`](#member-gfresourceconfigprovider-methods-has_index_key) | `func has_index_key(table_name: StringName, index_id: StringName, index_key: String) -> bool:` |
| 方法 | [`get_index_records`](#member-gfresourceconfigprovider-methods-get_index_records) | `func get_index_records(table_name: StringName, index_id: StringName, index_key: String) -> Array[Dictionary]:` |
| 方法 | [`get_index_record`](#member-gfresourceconfigprovider-methods-get_index_record) | `func get_index_record(table_name: StringName, index_id: StringName, index_key: String) -> Variant:` |
| 方法 | [`get_table`](#member-gfresourceconfigprovider-methods-get_table) | `func get_table(table_name: StringName) -> Variant:` |

## 方法

<a id="member-gfresourceconfigprovider-methods-register_table"></a>

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

<a id="member-gfresourceconfigprovider-methods-register_tables"></a>

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

<a id="member-gfresourceconfigprovider-methods-set_table_resources"></a>

### `set_table_resources`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func set_table_resources(table_resources: Array[GFConfigTableResource], duplicate_tables: bool = false) -> int:
```

以 best-effort 方式批量替换配置表资源并重建内部查询索引。 调用时会先清空旧表，再逐项注册候选；无效候选会被跳过并通过返回数量反映， 不会回滚已经接受的新表，也不保留旧表。需要 last-good 原子切换时，应在调用前 完整校验候选，或由项目层使用独立 Provider/Snapshot 完成 staging 与 swap。

参数：

| 名称 | 说明 |
|---|---|
| `table_resources` | 要设置的配置表资源列表。 |
| `duplicate_tables` | 为 true 时保存表资源副本。 |

返回：成功注册的表数量；小于输入数量表示已留下部分新状态。

结构：

- `table_resources`: Array[GFConfigTableResource]，每个元素是一张配置表资源。

<a id="member-gfresourceconfigprovider-methods-get_table_resources"></a>

### `get_table_resources`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_table_resources(duplicate_tables: bool = true) -> Array[GFConfigTableResource]:
```

获取已注册配置表资源。

参数：

| 名称 | 说明 |
|---|---|
| `duplicate_tables` | 为 true 时返回资源深拷贝，避免调用方修改 Provider 内部数据。 |

返回：配置表资源列表。

结构：

- `return`: Array[GFConfigTableResource]，每个元素是一张配置表资源。

<a id="member-gfresourceconfigprovider-methods-from_database"></a>

### `from_database`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
static func from_database(database: GFConfigDatabaseResource, duplicate_tables: bool = false) -> GFResourceConfigProvider:
```

从配置数据库资源创建 Provider。

参数：

| 名称 | 说明 |
|---|---|
| `database` | 配置数据库资源。 |
| `duplicate_tables` | 为 true 时把表资源副本注册到 Provider。 |

返回：新 Resource Provider；database 为空时返回 null。

<a id="member-gfresourceconfigprovider-methods-rebuild_table_registry"></a>

### `rebuild_table_registry`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func rebuild_table_registry() -> int:
```

重新建立内部查询索引和 schema registry。

返回：成功注册的表数量。

<a id="member-gfresourceconfigprovider-methods-unregister_table"></a>

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

<a id="member-gfresourceconfigprovider-methods-clear_tables"></a>

### `clear_tables`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func clear_tables() -> void:
```

清空所有配置表资源和由表资源注册的 schema。

<a id="member-gfresourceconfigprovider-methods-has_table"></a>

### `has_table`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func has_table(table_name: StringName) -> bool:
```

检查配置表是否已注册。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：已注册返回 true。

<a id="member-gfresourceconfigprovider-methods-get_table_ids"></a>

### `get_table_ids`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_table_ids() -> PackedStringArray:
```

获取已注册配置表名。

返回：排序后的表名列表。

<a id="member-gfresourceconfigprovider-methods-get_table_resource"></a>

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
| `duplicate_table` | 为 true 时返回资源深拷贝，避免调用方修改 Provider 内部数据。 |

返回：配置表资源；未命中时返回 null。

<a id="member-gfresourceconfigprovider-methods-get_record"></a>

### `get_record`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_record(table_name: StringName, record_id: Variant) -> Variant:
```

根据表名和 ID 获取单条记录。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `record_id` | 记录的唯一标识符。 |

返回：返回对应记录副本，未命中时返回 null。

结构：

- `record_id`: Variant，项目配置表使用的记录键，通常为 String、StringName 或 int。
- `return`: Variant，找到时为 Dictionary，未命中时为 null。

<a id="member-gfresourceconfigprovider-methods-make_index_key"></a>

### `make_index_key`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func make_index_key(table_name: StringName, index_id: StringName, record: Dictionary) -> String:
```

根据表名和索引声明构建索引键。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `index_id` | 索引 ID。 |
| `record` | 用于构建索引键的记录或字段值字典。 |

返回：索引键；表、索引或字段无效时返回空字符串。

结构：

- `record`: Dictionary，键为索引字段名，值为字段数据。

<a id="member-gfresourceconfigprovider-methods-has_index_key"></a>

### `has_index_key`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func has_index_key(table_name: StringName, index_id: StringName, index_key: String) -> bool:
```

检查表资源中的命名索引键是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `index_id` | 索引 ID。 |
| `index_key` | 由 make_index_key() 或同等规则生成的索引键。 |

返回：存在返回 true。

<a id="member-gfresourceconfigprovider-methods-get_index_records"></a>

### `get_index_records`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_index_records(table_name: StringName, index_id: StringName, index_key: String) -> Array[Dictionary]:
```

根据表名和命名索引获取记录列表。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `index_id` | 索引 ID。 |
| `index_key` | 由 make_index_key() 或同等规则生成的索引键。 |

返回：命中的记录列表；未命中时返回空数组。

结构：

- `return`: Array[Dictionary]，每个 Dictionary 是一条配置记录。

<a id="member-gfresourceconfigprovider-methods-get_index_record"></a>

### `get_index_record`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_index_record(table_name: StringName, index_id: StringName, index_key: String) -> Variant:
```

根据表名和命名索引获取第一条记录。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |
| `index_id` | 索引 ID。 |
| `index_key` | 由 make_index_key() 或同等规则生成的索引键。 |

返回：找到时返回第一条记录 Dictionary，否则返回 null。

结构：

- `return`: Variant，找到时为 Dictionary，未命中时为 null。

<a id="member-gfresourceconfigprovider-methods-get_table"></a>

### `get_table`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_table(table_name: StringName) -> Variant:
```

根据表名获取整张表的数据。

参数：

| 名称 | 说明 |
|---|---|
| `table_name` | 表名。 |

返回：返回 Array[Dictionary] 表数据副本，未命中时返回 null。

结构：

- `return`: Variant，找到时为 Array[Dictionary]，未命中时为 null。
