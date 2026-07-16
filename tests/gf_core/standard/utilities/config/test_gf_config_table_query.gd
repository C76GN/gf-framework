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
