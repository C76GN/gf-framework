# 配置表运行时查询

## 活动快照与发布

`GFConfigSnapshot` 表示一次完整验收的配置集合。调用 `provider.get_snapshot()` 固定一代数据后，可以在多个业务步骤中查询同一组表；其他流程发布新版时，这个引用仍读取旧版。

完整替换用 `replace_database()`，局部更新用 `update_tables()`；需要在发布前做项目验收时，先 `prepare_database()` / `prepare_update()`，再以准备结果的 `expected_generation` 调用 `publish_snapshot()`。发布只切换已验收引用，不调用加载器或项目校验回调。任何表、schema、引用或预算失败都保留活动快照。

| 原有使用场景 | 当前入口 |
| --- | --- |
| 启动载入 Resource 数据库 | `from_database(database)`；失败为 null。 |
| 章节按需加载、外部生成表 | 注册来源后显式 `load_tables()`，自动补齐声明的引用闭包。 |
| 单表热更新、调试改表 | 编辑表副本，`prepare_update()` 后发布。 |
| 多表一起变更或移除 | 同一候选中提交所有变化与 `removed_tables`。 |
| 业务计算期间版本稳定 | 持有同一个 `GFConfigSnapshot`。 |
| 来源释放、活动数据卸载 | 分别注销来源、发布移除项；旧读者按引用生命周期释放。 |

记录、表、schema 和集合查询返回独立副本；ID 与命名索引在候选阶段构建，运行查询不重建索引。Resource 字段仍表示共享资产引用，修改资产内部状态不属于快照隔离保证。需要严格内容固定时，项目应使用稳定资源标识或不可变资产，并在发布前完成资产版本管理。

`get_digest_report()` 返回 SHA-256 与覆盖状态。摘要覆盖记录、schema 描述、表元数据、数据库身份和版本；共享 Resource 等不可规范编码内容会使 `complete` 为 false，`value` 为空，不能把部分摘要当作完整内容证明。自定义校验代码及外部资产内容不由该摘要认证。

准备是同步的有界工作，校验、复制、索引和内容摘要有实际成本；安排在加载阶段，并用 `work_limits` 控制准入。增量复用未改变表，旧快照与新候选仍会同时占用内存。大量查询使用 ID 或命名索引；取整表副本仍与结果大小成正比。框架不承诺候选准备能在一帧内完成。

候选摘要在一次捕获内共用规范编码计量，工作预算通过后才生成完整编码；摘要和失败优先级保持一致。普通标量表在单次校验内复用固定声明检查，只在需要规则上下文或错误定位时构造相应数据。自定义规则、类型转换和结构化声明仍执行各自完整的校验路径，跨次准备不缓存校验结论。

局部更新优先提交实际变化的表：未变化表复用已验收数据、索引和摘要，合并后的集合仍执行跨表引用校验。摘要准备会短暂持有当前表载荷的隔离副本；优化减少重复遍历，不取消输入隔离、预算或完整验收。

来源接入与迁移示例见 [Provider 适配器](provider-schema/provider-adapter.md)。

## 纯数据查询器

`GFConfigTableQuery` 是纯数据查询器，面向 `GFConfigTableResource`、导表记录数组和编辑器工具。它只处理 `Array[Dictionary]` 记录、字段路径、过滤、排序和分页，不绑定表名、字段含义或业务枚举。

基础查询可以直接链式组合，多个 `where_*()` 条件之间是 AND 关系：

```gdscript
var rows := GFConfigTableQuery.from_records(item_records) \
	.where_gte("stats.power", 5) \
	.where_contains("tags", "melee") \
	.order_by("id", false) \
	.page(0, 20) \
	.to_array()
```

字段路径支持用 `.` 访问嵌套 `Dictionary`、数组下标和对象属性，例如 `stats.power`、`loot.0.item_id`。需要单独读取路径时可以调用 `GFConfigTableQuery.read_path(record, "stats.power")`。

Object path 是受信任执行边界：读取已声明属性会调用该 Object 的 getter，框架无法把昂贵、递归或有副作用的项目 getter 变成纯数据访问。外部配置、模组或其他不受信任输入应先投影为 Dictionary/Array；已释放的 Object 会被当作路径未命中并返回默认值，不会访问悬空实例。

`to_array()`、`first()` 和 `values()` 默认复制可变集合结果，修改返回的记录、嵌套 Dictionary、Array 或 PackedArray 不会写回 Query。确实需要零复制且调用方能遵守只读/所有权约定时，可显式传 `false`，例如 `query.values("payload", false)`；Object 与未要求复制的 Resource 仍保留其引用语义。

## 条件组

当工具层需要保存、复用或序列化查询条件时，可以用 `condition()` 构建声明式条件，再交给 `where_filter()`、`where_any()` 或 `where_none()`：

```gdscript
var query := GFConfigTableQuery.from_table(items)
query.where_any([
	GFConfigTableQuery.condition(GFConfigTableQuery.Operator.EQ, "role", "front"),
	GFConfigTableQuery.condition(GFConfigTableQuery.Operator.GTE, "stats.power", 8),
], &"front_or_strong")
query.where_none([
	GFConfigTableQuery.condition(GFConfigTableQuery.Operator.CONTAINS, "tags", "temporary"),
], &"not_temporary")
```

`where_any()` 表示任一子条件命中即可通过；`where_none()` 表示任一子条件命中都会拒绝记录。更复杂的工具可以把 `Operator.ANY` / `Operator.NONE` 条件字典传给 `where_filter()`，形成嵌套条件组。`describe_query()` 会保留条件组、子条件和描述 ID，便于调试 UI 或测试断言展示查询结构。

Query API 是“逐步添加有效过滤器”的 builder，不是可独立求值的布尔表达式解释器。空组或归一化后没有有效子条件的组表示尚未配置，`where_any([])`、`where_none([])` 以及相同内容的 `where_filter()` 都是 no-op，不会应用“空析取为 false”的数学单位元，也不会出现在 `describe_query()`。从外部读取查询定义时，应先由项目工具校验必填筛选条件；不要把一个可为空的 UI 查询直接当作授权规则。

如果查询条件必须调用项目逻辑，可以使用 `where_predicate()`。Predicate 不适合长期序列化或跨工具复用；能用字段路径表达的条件，优先使用声明式条件组。
