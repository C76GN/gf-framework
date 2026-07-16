# 配置表运行时查询

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

如果查询条件必须调用项目逻辑，可以使用 `where_predicate()`。Predicate 不适合长期序列化或跨工具复用；能用字段路径表达的条件，优先使用声明式条件组。
