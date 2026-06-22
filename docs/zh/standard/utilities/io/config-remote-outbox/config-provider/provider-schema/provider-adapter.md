# Provider 适配器

`GFConfigProvider` 是抽象适配器，本身不存数据；默认实现会报错并返回 `null`。

```gdscript
class_name JSONConfigProvider
extends GFConfigProvider

var _configs: Dictionary = {}

func async_init() -> void:
	# 异步加载你的表...
	pass

func get_record(table_name: StringName, id: Variant) -> Variant:
	if _configs.has(table_name) and _configs[table_name].has(id):
		return _configs[table_name][id]
	return null

func get_table(table_name: StringName) -> Variant:
	return _configs.get(table_name)
```

返回类型保持 `Variant` 是为了兼容不同导表方案：可以返回 `Dictionary`、`Resource`、自定义记录对象，或整张表容器。

框架内调用方会按自己的需求解释返回值。例如 `GFLevelUtility` 会接受字典记录，或带 `to_dict()` 方法的记录对象。

建议子类在 `async_init()` 或 `init()` 阶段完成加载，并在 `get_record()` 中返回只读数据或副本，避免业务代码直接改坏导表缓存。

表名建议使用稳定 `StringName`，记录 ID 可保持项目导表原始类型。

## Resource 表 Provider

如果导表流水线已经输出 Godot 原生 `.tres/.res`，可以用 `GFConfigTableResource` 承载单张表，再交给 `GFResourceConfigProvider` 查询。

```gdscript
var table := GFConfigTableResource.new()
table.table_name = &"items"
table.schema = item_schema
table.records = [
	{ "id": 1, "name": "Potion" },
	{ "id": 2, "name": "Ether" },
]
table.rebuild_index()
table.rebuild_indexes()

var provider := GFResourceConfigProvider.new()
provider.register_table(table)

var item := provider.get_record(&"items", 1)
```

`GFConfigTableResource` 保留稳定记录顺序、可选 `records_by_id` 主键索引和 `records_by_index` 命名索引缓存。命名索引来自 `schema.indexes`，可用 `make_index_key()` 构建查询键，再通过 `get_index_record()` 或 `get_index_records()` 查询；如果缓存为空，表资源会按 schema 临时构建查询结果。

多表导表产物可以用 `GFConfigDatabaseResource` 聚合。数据库资源只保存多张表和通用 metadata；运行时读取时由 `GFResourceConfigProvider.from_database()` 创建查询 Provider：

```gdscript
var database := GFConfigDatabaseResource.new()
database.database_id = &"main"
database.version = "2026.06.17"
database.register_table(item_table)
database.register_table(skill_table)
database.rebuild_table_indexes()

var report := database.validate_database()
var provider := GFResourceConfigProvider.from_database(database)
var item := provider.get_record(&"items", 1)
```

`validate_database()` 会聚合表资源状态、schema 校验、表数据校验和跨表引用校验，返回 `GFConfigValidationReport` 兼容字典。它适合在导入后、CI 或运行时调试入口检查整包配置是否可用。

`GFResourceConfigProvider` 负责运行时查询面：`get_record()`、`get_table()`、`get_index_record()` 和 `get_index_records()` 默认返回副本，避免业务代码修改共享资源数据。Provider 内部会维护表名和 schema registry，替换表资源时应使用 `set_table_resources()` 或 `register_table()`，不要绕过 Provider 入口维护缓存。

这层只解决运行时读取 `.tres/.res` 表资源的问题；源表导入、xlsx/xml/yaml 解析、代码生成、构建报告和编辑器 UI 仍应留给项目工具或独立工具包。
