# Provider 适配器

`GFConfigProvider` 是抽象适配器，本身不存数据；默认实现会报错并返回 `null`。

```gdscript
class_name JSONConfigProvider
extends GFConfigProvider

var _configs: Dictionary = {}

func async_init(scope: GFAsyncScope) -> void:
	# 由项目实现这个异步加载入口。
	var loaded_value: Variant = await load_config_tables_async()
	if scope.is_cancel_requested():
		return
	if not loaded_value is Dictionary:
		push_error("配置表加载结果不是 Dictionary。")
		return
	var loaded_configs: Dictionary = loaded_value as Dictionary
	_configs.clear()
	for raw_table_name: Variant in loaded_configs.keys():
		var table_name: StringName = GFVariantData.to_string_name(raw_table_name)
		if table_name == &"":
			continue
		_configs[table_name] = GFVariantData.duplicate_variant(
			loaded_configs[raw_table_name]
		)

func get_record(table_name: StringName, id: Variant) -> Variant:
	var table_value: Variant = _configs.get(table_name)
	if not table_value is Dictionary:
		return null
	var table: Dictionary = table_value as Dictionary
	return GFVariantData.duplicate_variant(table.get(id))

func get_table(table_name: StringName) -> Variant:
	return GFVariantData.duplicate_variant(_configs.get(table_name))
```

`load_config_tables_async()` 是项目侧占位入口，需要替换为实际的加载函数。

返回类型保持 `Variant` 是为了兼容不同导表方案：可以返回 `Dictionary`、`Resource`、自定义记录对象，或整张表容器。

框架内调用方会按自己的需求解释返回值。例如 `GFLevelUtility` 会接受字典记录，或带 `to_dict()` 方法的记录对象。

`init()` 只适合组装已经在内存中的数据；文件、网络等异步加载应放在 `async_init(scope)`，并在每次 `await` 后检查取消状态。`get_record()` 应返回只读数据或副本，避免业务代码直接改坏导表缓存。

上面的非法加载结果只 `push_error()`，属于允许 Provider 保持为空的 soft-fail 示例。配置是启动必需项时，应由项目 Installer 先加载和校验，再在失败时调用 `architecture.fail_initialization()`，不要把致命失败隐藏在 Provider 内部。

表名建议使用稳定 `StringName`，记录 ID 可保持项目导表原始类型。

## 通用表源适配

如果项目已经有生成表对象、远程配置缓存、字典表或懒加载函数，不必为了接入 GF 先转换成 Resource。`GFConfigProviderAdapter` 可以注册单张表源，并在 `get_record()` / `get_table()` 时统一查询：

```gdscript
var provider := GFConfigProviderAdapter.new()
var registered: bool = provider.register_table_source(&"items", func(table_name: StringName, metadata: Dictionary) -> Array[Dictionary]:
	return load_items_from_project_cache(table_name, metadata)
, {
	"id_field": &"id",
	"metadata": { "source": "runtime_cache" },
})
if not registered:
	push_error("items 表源注册失败。")
	return

var load_report: Dictionary = provider.preload_table(&"items")
if not bool(load_report.get("ok", false)):
	push_error("items 表加载失败。")
	return

var item: Variant = provider.get_record(&"items", 1001)
if item == null:
	push_error("items[1001] 不存在。")
```

表源可以是 `Array`、`Dictionary`、自定义对象或 `Callable`。数组表默认按 `id_field` 查找记录；字典表按键查找，并支持 `String` / `StringName` 文本等价；对象源会先尝试通过 `table_method`（默认 `get_table()`）解析整表，只有解析后的表值仍是对象时，单条查询才调用 `record_method`（默认 `get_record(record_id)`）。`cache` 默认为 `true`，懒加载结果会缓存到 Provider 内，`clear_table_cache()` 可清掉单表缓存。

这个适配器只做运行时读取边界，不解析 CSV、JSON、二进制包或网络协议，也不规定表名、字段名和热更新策略。复杂导入、签名、下载和分端裁剪仍应放在项目工具或独立制作期包里。

代码生成式导表同样不需要进入 GF 核心。项目 adapter 只需把生成容器投影为表源，例如返回生成表的记录数组，或通过 `table_method` / `record_method` 映射其查询 API；GF 继续只消费 `GFConfigProvider`。生成代码版本、二进制格式、加载顺序和热更新原子切换由项目 Installer 校验，避免框架绑定某一种导表工具。

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

var provider := GFResourceConfigProvider.new()
if not provider.register_table(table):
	push_error("items 表注册失败。")
	return

var item: Variant = provider.get_record(&"items", 1)
if item == null:
	push_error("items[1] 不存在。")
```

`GFConfigTableResource` 保留稳定记录顺序，也可把 `records_by_id` 和 `records_by_index` 作为导出、检查或无有效 Schema 声明时的索引快照。`get_record()` 会以当前 `records` 为准查找；存在有效 `schema.indexes` 时，命名索引查询也会从当前记录构建结果，避免陈旧缓存覆盖真实数据。可用 `make_index_key()` 构建查询键，再通过 `get_index_record()` 或 `get_index_records()` 查询；不要把 `rebuild_index()` / `rebuild_indexes()` 理解为所有运行时查询都会自动命中的加速缓存。

多表导表产物可以用 `GFConfigDatabaseResource` 聚合。数据库资源只保存多张表和通用 metadata；运行时读取时由 `GFResourceConfigProvider.from_database()` 创建查询 Provider：

```gdscript
var database := GFConfigDatabaseResource.new()
database.database_id = &"main"
database.version = "2026.06.17"
if not database.register_table(item_table) or not database.register_table(skill_table):
	push_error("配置表注册到数据库失败。")
	return

var validation: Dictionary = database.validate_database()
if not bool(validation.get("ok", false)):
	push_error("配置数据库校验失败。")
	return

# true 表示把表资源副本注册到 Provider，避免修改共享导表 Resource。
var provider := GFResourceConfigProvider.from_database(database, true)
var item: Variant = provider.get_record(&"items", 1)
if item == null:
	push_error("items[1] 不存在。")
```

`validate_database()` 会聚合表资源状态、schema 校验、表数据校验和跨表引用校验，返回 `GFConfigValidationReport` 兼容字典。它适合在导入后、CI 或运行时调试入口检查整包配置是否可用。

`GFResourceConfigProvider` 负责运行时查询面：`get_record()`、`get_table()`、`get_index_record()` 和 `get_index_records()` 默认返回副本，避免业务代码修改共享资源数据。Provider 内部会维护表名和 schema registry，替换表资源时应使用 `set_table_resources()` 或 `register_table()`，不要绕过 Provider 入口维护缓存。

这层只解决运行时读取 `.tres/.res` 表资源的问题；源表导入、xlsx/xml/yaml 解析、代码生成、构建报告和编辑器 UI 仍应留给项目工具或独立工具包。

## 作为架构协议注册

无论选择 Adapter、自定义 Provider 还是 Resource Provider，运行时通常都应以抽象 `GFConfigProvider` 作为稳定查询键。GF 8 的注册入口是可等待操作；在 Installer 中应检查结果与取消状态：

```gdscript
const DATABASE: GFConfigDatabaseResource = preload(
	"res://generated/config/main_config.tres"
)


func install(architecture: GFArchitecture, scope: GFAsyncScope) -> void:
	var validation: Dictionary = DATABASE.validate_database()
	if not bool(validation.get("ok", false)):
		architecture.fail_initialization("配置数据库校验失败。")
		return

	var provider := GFResourceConfigProvider.from_database(DATABASE, true)
	if provider == null:
		architecture.fail_initialization("无法创建配置 Provider。")
		return

	var registered: bool = await architecture.register_utility_instance_as(
		provider,
		GFConfigProvider
	)
	if scope.is_cancel_requested():
		return
	if not registered:
		architecture.fail_initialization("配置 Provider 注册失败。")
		return
```

只调用 `register_utility_instance(provider)` 会按具体实现类型注册。当当前架构中只有一个可赋值的 Provider 实现时，`get_utility(GFConfigProvider)` 仍可自动解析；存在多个实现时，抽象类型查询会因歧义返回 `null`。显式使用 `register_utility_instance_as()` 可以固定抽象查询键并消除歧义。

`GFConfigProviderAdapter` 的 Callable 表源会在首次查询时同步调用，不会被框架自动 `await`；需要异步加载时，应在项目自定义 `GFConfigProvider.async_init(scope)` 中完成。
