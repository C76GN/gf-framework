# Provider 适配器

配置来源与活动数据分开管理。Godot 数据库用 `GFResourceConfigProvider`；数组、字典、生成对象或同步加载函数用 `GFConfigProviderAdapter`。两者都发布 `GFConfigSnapshot`，查询返回记录副本，跨表读取可以固定同一快照。

`GFConfigProvider` 保留自定义查询协议。未发布快照、也未重写查询的基类会报告未实现；自定义 Provider 仍可注册 schema 做独立验证。活动快照的 schema 随候选发布，不能用 `register_schema()` 单独替换。

## Resource 输入

`GFConfigDatabaseResource` 与 `GFConfigTableResource` 是可编辑的作者数据。数据库中的表名必须唯一，表与 schema 身份必须一致；完整 schema、记录、索引约束和跨表引用验收通过后才可以发布。

```gdscript
# database 是项目已经加载的 GFConfigDatabaseResource。
var provider := GFResourceConfigProvider.new()
var result: Dictionary = provider.replace_database(database)
if not GFVariantData.get_option_bool(result, "ok"):
	# result 包含 error_kind、validation_report 与 work_report。
	return
var snapshot: GFConfigSnapshot = provider.get_snapshot()
var item: Variant = snapshot.get_record(&"items", 1001)
```

`from_database(database)` 是创建并发布的便捷入口；失败返回 `null`，不会返回部分可用的 Provider。输入中的缓存索引不作为验收依据，运行索引在候选阶段重建。启用 schema 的显式类型转换时，发布校验后的记录。

准备与发布也可以分开：`prepare_database()` / `prepare_update()` 返回候选和 `expected_generation`，随后调用 `publish_snapshot(snapshot, expected_generation)`。代际不匹配时拒绝发布，避免迟到候选覆盖较新状态。异步下载必须先在项目侧固定请求的内容版本、验证清单及取消状态，再把捕获结果交给这些入口。

## 显式按需加载

注册来源不会执行 loader，也不改变活动数据。`prepare_tables()` 只构建候选；`load_tables()` 完成准备与发布。两者按 schema 引用声明补齐请求闭包，未请求且未被引用的表保持未加载。无需在启动时加载全部游戏配置。

```gdscript
var provider := GFConfigProviderAdapter.new()
var registered: bool = provider.register_table_source(
	&"items",
	items_by_id,
	{
		"schema": item_schema,
		"content_version": "content-42",
	}
)
if not registered:
	return
var result: Dictionary = provider.load_tables(
	PackedStringArray(["items"]),
	{ "version": "content-42" }
)
if not GFVariantData.get_option_bool(result, "ok"):
	return
var item: Variant = provider.get_record(&"items", 1001)
```

来源形态：

| 来源 | 捕获规则 |
| --- | --- |
| Array | 每项为 Dictionary，按 schema 的 ID 字段建立索引。 |
| Dictionary | 键为记录 ID，值为 Dictionary；缺少 ID 字段时填入键，冲突时失败。 |
| Object | 调用 `table_method`（默认 `get_table`）返回整个集合；或通过显式 `record_ids` 与 `record_method`（默认 `get_record`）枚举。 |
| Callable | 同步接收 `(table_name, metadata)`，返回上述数据；metadata 是独立副本。 |
| 对象记录 | 用 `record_projector` 明确转换为 Dictionary；不保留任意对象方法与身份。 |

loader 不会被自动 `await`。异步文件或网络 IO 由项目先完成，再注册其结果。loader 可以查询旧快照，但不能重入准备；重入、来源替换或准备期间的其他发布会使外层候选失败。schema 的循环引用可以作为同一集合捕获，不等同于 loader 递归调用。

`has_table_source()` / `get_source_ids()` 查询来源清单；`has_table()` / `get_table_ids()` 查询活动快照。`get_load_report()` 同时给出最近准备状态和 `loaded`，失败报告不代表旧数据消失。

## Luban 等生成表接入

项目负责生成器、二进制格式、下载与清单。明确列出表、schema、内容版本与引用依赖；把生成表的集合 API 映射为来源，或提供记录 ID 清单和对象记录投影函数。GF 不硬编码表名，也不要求修改生成器来输出 GF Resource。

每次显式准备会重新捕获选中闭包；来源声明中的非空 `content_version` 必须匹配请求版本。声明完整的增量集合由项目负责，框架无法从任意版本字符串推断未提交的外部文件变化。业务跨表含义、奖励与数值计算放在项目 Domain Repository，Repository 读取同一快照。

## 更新与释放

`update_tables(tables, options)` 基于当前快照构建增量，支持 `removed_tables: PackedStringArray`、内容 `version` 和共享 `work_budget` / `work_limits`。所有候选表一起验收；仍被引用的表不能单独删除。未改变表复用隔离后的内部数据，已有读者继续持有旧快照。

`unregister_table_source()` 与 `clear_table_sources()` 只释放来源。活动数据通过增量移除或完整替换释放；旧快照在读者放弃引用后回收。调试改表也先取得副本、修改、发布，不提供可写活动表入口。

旧的逐表注册、clear-then-register、重建 registry、隐式查询加载、缓存清理及返回可写引用参数已经移除。对应场景的新入口见[运行快照与查询](../runtime-query.md)。

## 架构装配

安装时使用 `architecture.register_utility_instance_as(GFConfigProvider, provider)` 固定抽象查询键。配置是启动必需项时，Installer 在加载、验收或注册失败后调用 `architecture.fail_initialization()`。每次异步等待后检查作用域取消，不能把失败包装成初始化成功。
