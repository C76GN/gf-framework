## 测试配置表通用查询器。
extends GutTest


# --- 测试 ---

func test_query_filters_nested_values_sorts_and_pages() -> void:
	var records: Array[Dictionary] = [
		{
			"id": 1,
			"stats": { "power": 4 },
			"tags": ["melee", "starter"],
		},
		{
			"id": 2,
			"stats": { "power": 9 },
			"tags": ["ranged"],
		},
		{
			"id": 3,
			"stats": { "power": 7 },
			"tags": ["melee"],
		},
	]

	var query: GFConfigTableQuery = GFConfigTableQuery.from_records(records)
	var _query_result: GFConfigTableQuery = query.where_gte("stats.power", 5).where_contains("tags", "melee").order_by("id", false).page(0, 1)
	var result: Array[Dictionary] = query.to_array()

	assert_eq(query.count(), 1, "分页前的匹配数量应只统计过滤条件。")
	assert_eq(result.size(), 1, "分页应限制返回数量。")
	assert_eq(GFVariantData.get_option_int(result[0], "id"), 3, "查询器应支持嵌套字段、数组包含和降序排序。")


func test_query_reads_array_paths_and_returns_values() -> void:
	var records: Array[Dictionary] = [
		{
			"id": "chest_a",
			"loot": [
				{ "item_id": "coin" },
				{ "item_id": "gem" },
			],
		},
		{
			"id": "chest_b",
			"loot": [
				{ "item_id": "key" },
			],
		},
	]

	var query: GFConfigTableQuery = GFConfigTableQuery.from_records(records)
	var ids: Array = query.where_exists("loot.1.item_id").values("loot.1.item_id")
	var first_item_id: String = GFVariantData.to_text(GFConfigTableQuery.read_path(records[1], "loot.0.item_id"))

	assert_eq(ids, ["gem"], "字段路径应能读取数组下标和嵌套 Dictionary。")
	assert_eq(first_item_id, "key", "静态路径读取应可独立复用。")


func test_query_read_path_fails_closed_for_freed_object() -> void:
	var source: DisposableQueryObject = DisposableQueryObject.new()
	source.value = 7
	source.free()

	var result: Variant = GFConfigTableQuery.read_path(source, "value", "fallback")

	assert_eq(typeof(result), TYPE_STRING, "fallback 应保留调用方声明的值类型。")
	assert_eq(
		GFVariantData.to_text(result),
		"fallback",
		"已释放 Object 的路径读取应视为未命中，不得访问悬空实例。"
	)


func test_query_read_path_treats_object_getter_as_trusted_execution_boundary() -> void:
	var source: ObservableQueryObject = ObservableQueryObject.new()

	var result: Variant = GFConfigTableQuery.read_path(source, "observed_value", "fallback")

	assert_eq(typeof(result), TYPE_INT, "有效 Object 属性应保留原始值类型。")
	assert_eq(GFVariantData.to_int(result), 7, "有效 Object 属性应继续按公开路径读取契约返回值。")
	assert_eq(source.getter_call_count, 1, "一次路径读取只应执行目标 getter 一次。")


func test_query_values_duplicates_mutable_projections_by_default() -> void:
	var query: GFConfigTableQuery = GFConfigTableQuery.from_records([{
		"id": 1,
		"payload": {
			"tags": ["base"],
		},
	}])
	var projected_records: Array = query.values()
	var projected_payloads: Array = query.values("payload")
	var projected_record: Dictionary = GFVariantData.as_dictionary(projected_records[0])
	var projected_payload: Dictionary = GFVariantData.as_dictionary(projected_payloads[0])
	projected_record["id"] = 99
	var projected_tags: Array = projected_payload["tags"]
	projected_tags.append("mutated")

	var current: Dictionary = GFVariantData.as_dictionary(query.first())
	var current_payload: Dictionary = GFVariantData.get_option_dictionary(current, "payload")

	assert_eq(GFVariantData.get_option_int(current, "id"), 1, "values() 默认不得暴露内部记录写通道。")
	assert_eq(
		GFVariantData.get_option_array(current_payload, "tags"),
		["base"],
		"values(path) 默认应深复制可变投影值。"
	)


func test_query_values_allows_explicit_mutable_borrow() -> void:
	var query: GFConfigTableQuery = GFConfigTableQuery.from_records([{
		"id": 1,
		"payload": {
			"tags": ["base"],
		},
	}])
	var borrowed_payloads: Array = query.values("payload", false)
	var borrowed_payload: Dictionary = GFVariantData.as_dictionary(borrowed_payloads[0])
	var borrowed_tags: Array = borrowed_payload["tags"]
	borrowed_tags.append("borrowed")

	var current: Dictionary = GFVariantData.as_dictionary(query.first())
	var current_payload: Dictionary = GFVariantData.get_option_dictionary(current, "payload")

	assert_eq(
		GFVariantData.get_option_array(current_payload, "tags"),
		["base", "borrowed"],
		"duplicate_values=false 应作为显式零复制借用入口。"
	)


func test_query_predicate_and_description_are_reported() -> void:
	var records: Array[Dictionary] = [
		{ "id": &"a", "power": 1 },
		{ "id": &"b", "power": 3 },
	]
	var query: GFConfigTableQuery = GFConfigTableQuery.from_records(records)
	var predicate: Callable = func(record: Dictionary) -> bool:
		return GFVariantData.get_option_int(record, "power") > 1
	var _predicate_query_result: GFConfigTableQuery = query.where_predicate(predicate, &"power_gt_one")

	var result: Array[Dictionary] = query.to_array()
	var description: Dictionary = query.describe_query()
	var filters: Array = GFVariantData.get_option_array(description, "filters")
	var first_filter: Dictionary = GFVariantData.as_dictionary(filters[0])

	assert_eq(result.size(), 1, "predicate 应参与记录过滤。")
	assert_eq(GFVariantData.get_option_string_name(result[0], "id"), &"b", "predicate 应保留匹配记录。")
	assert_eq(GFVariantData.get_option_string_name(first_filter, "description"), &"power_gt_one", "查询描述应保留 predicate 描述。")


func test_query_predicate_cannot_mutate_internal_records() -> void:
	var query: GFConfigTableQuery = GFConfigTableQuery.from_records([
		{"id": 1, "enabled": true},
	])
	var predicate: Callable = func(record: Dictionary) -> bool:
		record["enabled"] = false
		return true
	var _configured: GFConfigTableQuery = query.where_predicate(predicate)

	assert_eq(query.count(), 1, "predicate 应正常参与过滤。")
	var result: Array[Dictionary] = query.to_array()
	assert_true(GFVariantData.get_option_bool(result[0], "enabled"), "predicate 只能收到记录副本，不得把查询变成隐式写通道。")


func test_query_any_and_none_condition_groups_are_declarative() -> void:
	var records: Array[Dictionary] = [
		{ "id": "warrior", "role": "front", "stats": { "power": 6 }, "tags": ["starter"] },
		{ "id": "mage", "role": "back", "stats": { "power": 9 }, "tags": ["elite"] },
		{ "id": "summon", "role": "back", "stats": { "power": 3 }, "tags": ["temporary"] },
		{ "id": "trap", "role": "field", "stats": { "power": 8 }, "tags": ["temporary"] },
	]

	var query: GFConfigTableQuery = GFConfigTableQuery.from_records(records)
	var _condition_group_query_result: GFConfigTableQuery = query.where_any([
		GFConfigTableQuery.condition(GFConfigTableQuery.Operator.EQ, "role", "front"),
		GFConfigTableQuery.condition(GFConfigTableQuery.Operator.GTE, "stats.power", 8),
	], &"front_or_strong").where_none([
		GFConfigTableQuery.condition(GFConfigTableQuery.Operator.CONTAINS, "tags", "temporary"),
	], &"not_temporary").order_by("id")

	var ids: Array = query.values("id")
	var description: Dictionary = query.describe_query()
	var filters: Array = GFVariantData.get_option_array(description, "filters")
	var any_description: Dictionary = GFVariantData.as_dictionary(filters[0])
	var child_filters: Array = GFVariantData.get_option_array(any_description, "filters")

	assert_eq(ids, ["mage", "warrior"], "ANY 条件组应提供 OR 语义，NONE 条件组应排除任一命中的记录。")
	assert_eq(GFVariantData.get_option_string(any_description, "operator_name"), "ANY", "查询描述应暴露条件组操作符。")
	assert_eq(child_filters.size(), 2, "查询描述应保留条件组子条件。")


func test_query_empty_condition_groups_are_unconfigured_no_ops() -> void:
	var query: GFConfigTableQuery = GFConfigTableQuery.from_records([
		{ "id": 1 },
		{ "id": 2 },
	])
	var empty_conditions: Array[Dictionary] = []
	var _any_result: GFConfigTableQuery = query.where_any(empty_conditions, &"empty_any")
	var _none_result: GFConfigTableQuery = query.where_none(empty_conditions, &"empty_none")
	var _declarative_any_result: GFConfigTableQuery = query.where_filter(
		GFConfigTableQuery.condition(GFConfigTableQuery.Operator.ANY, "", [])
	)
	var _declarative_none_result: GFConfigTableQuery = query.where_filter(
		GFConfigTableQuery.condition(GFConfigTableQuery.Operator.NONE, "", [])
	)
	var description: Dictionary = query.describe_query()

	assert_eq(query.count(), 2, "builder 收到零个有效子条件时应保持未配置状态。")
	assert_eq(
		GFVariantData.get_option_int(description, "filter_count"),
		0,
		"fluent 与声明式入口都不应把空组注册成可执行布尔表达式。"
	)
	assert_true(
		GFVariantData.get_option_array(description, "filters").is_empty(),
		"空组 no-op 不应在 query description 中伪装成有效过滤器。"
	)


func test_query_where_filter_accepts_nested_condition_groups() -> void:
	var records: Array[Dictionary] = [
		{ "id": "a", "kind": "weapon", "stats": { "power": 2 } },
		{ "id": "b", "kind": "armor", "stats": { "power": 5 } },
		{ "id": "c", "kind": "weapon", "stats": { "power": 7 } },
	]
	var nested_any: Dictionary = GFConfigTableQuery.condition(
		GFConfigTableQuery.Operator.ANY,
		"",
		[
			GFConfigTableQuery.condition(GFConfigTableQuery.Operator.EQ, "kind", "armor"),
			GFConfigTableQuery.condition(GFConfigTableQuery.Operator.GT, "stats.power", 6),
		],
		&"armor_or_powerful"
	)

	var ids: Array = GFConfigTableQuery.from_records(records).where_filter(nested_any).values("id")

	assert_eq(ids, ["b", "c"], "where_filter 应能接收嵌套条件组，便于工具层保存或复用查询条件。")


func test_query_sorts_mixed_value_types_with_stable_order() -> void:
	var records: Array[Dictionary] = [
		{ "id": "string", "rank": "2" },
		{ "id": "int", "rank": 1 },
		{ "id": "string_name", "rank": &"2" },
		{ "id": "float", "rank": 1.5 },
	]

	var query: GFConfigTableQuery = GFConfigTableQuery.from_records(records)
	var result: Array[Dictionary] = query.order_by("rank", true).to_array()
	var ids: Array = []
	for record: Dictionary in result:
		ids.append(GFVariantData.get_option_string(record, "id"))

	assert_eq(ids, ["int", "float", "string", "string_name"], "混合类型字段排序应使用确定的通用 Variant 顺序。")


func test_query_numeric_sort_defines_total_order_for_non_finite_values() -> void:
	var query: GFConfigTableQuery = GFConfigTableQuery.from_records([
		{"id": "nan", "rank": NAN},
		{"id": "positive_infinity", "rank": INF},
		{"id": "finite", "rank": 2.0},
		{"id": "negative_infinity", "rank": -INF},
	])
	var ids: Array = query.order_by("rank").values("id")

	assert_eq(
		ids,
		["negative_infinity", "finite", "positive_infinity", "nan"],
		"数值排序应把 NaN 固定放在有限数和无穷值之后，保持比较器反对称。"
	)


func test_query_numeric_comparison_preserves_adjacent_large_integers() -> void:
	var lower_rank: int = 9_007_199_254_740_992
	var upper_rank: int = 9_007_199_254_740_993
	var records: Array[Dictionary] = [
		{"id": "upper", "rank": upper_rank},
		{"id": "lower", "rank": lower_rank},
	]

	var sorted_ids: Array = (
		GFConfigTableQuery.from_records(records)
		.order_by("rank")
		.values("id")
	)
	var greater_ids: Array = (
		GFConfigTableQuery.from_records(records)
		.where_gt("rank", lower_rank)
		.values("id")
	)
	var lesser_ids: Array = (
		GFConfigTableQuery.from_records(records)
		.where_lt("rank", upper_rank)
		.values("id")
	)

	assert_eq(sorted_ids, ["lower", "upper"], "相邻 64-bit 整数不得因 float 转换折叠。")
	assert_eq(greater_ids, ["upper"], "GT 必须精确区分 2^53 边界后的整数。")
	assert_eq(lesser_ids, ["lower"], "LT 必须精确区分 2^53 边界后的整数。")


func test_query_numeric_comparison_does_not_use_approximate_sort_equality() -> void:
	var lower_rank: float = 1.0
	var upper_rank: float = 1.000001
	var forward_records: Array[Dictionary] = [
		{"id": "upper", "rank": upper_rank},
		{"id": "lower", "rank": lower_rank},
	]
	var reverse_records: Array[Dictionary] = forward_records.duplicate(true)
	reverse_records.reverse()

	var forward_ids: Array = (
		GFConfigTableQuery.from_records(forward_records)
		.order_by("rank")
		.values("id")
	)
	var reverse_ids: Array = (
		GFConfigTableQuery.from_records(reverse_records)
		.order_by("rank")
		.values("id")
	)
	var greater_ids: Array = (
		GFConfigTableQuery.from_records(forward_records)
		.where_gt("rank", lower_rank)
		.values("id")
	)

	assert_eq(forward_ids, ["lower", "upper"], "精确浮点次序不得依赖输入排列。")
	assert_eq(reverse_ids, ["lower", "upper"], "反向输入也必须得到同一精确次序。")
	assert_eq(greater_ids, ["upper"], "范围谓词不得把不同浮点值近似合并。")


# --- 内部类 ---

class DisposableQueryObject extends Node:

	var value: int = 0


class ObservableQueryObject extends RefCounted:

	var getter_call_count: int = 0
	var observed_value: int:
		get:
			getter_call_count += 1
			return 7
