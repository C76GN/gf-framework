extends GutTest

const GF_SPATIAL_QUERY_INDEX_2D_SCRIPT = preload("res://addons/gf/standard/utilities/spatial/gf_spatial_query_index_2d.gd")
const GF_SPATIAL_QUERY_INDEX_3D_SCRIPT = preload("res://addons/gf/standard/utilities/spatial/gf_spatial_query_index_3d.gd")


func test_spatial_query_index_2d_switches_strategy_and_returns_records() -> void:
	var index: GF_SPATIAL_QUERY_INDEX_2D_SCRIPT = GF_SPATIAL_QUERY_INDEX_2D_SCRIPT.new()
	var _configured: GF_SPATIAL_QUERY_INDEX_2D_SCRIPT = index.configure(
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		GF_SPATIAL_QUERY_INDEX_2D_SCRIPT.STRATEGY_AUTO,
		{ "auto_quadtree_threshold": 1 }
	)
	var _first: bool = index.upsert(1, Rect2(Vector2(0.0, 0.0), Vector2(10.0, 10.0)), { "kind": "unit" })
	var _second: bool = index.upsert(2, Rect2(Vector2(20.0, 20.0), Vector2(5.0, 5.0)), { "kind": "prop" })
	var _third: bool = index.upsert_point(3, Vector2(50.0, 50.0), 2.0)

	var point_hits: Array[int] = index.query_point(Vector2(2.0, 2.0))
	var radius_hits: Array[int] = index.query_radius(Vector2(21.0, 21.0), 3.0)
	var records: Array[Dictionary] = index.query_records_rect(Rect2(Vector2.ZERO, Vector2(30.0, 30.0)))
	var snapshot: Dictionary = index.get_debug_snapshot()

	assert_eq(point_hits, [1], "点查询应返回包含该点的实体。")
	assert_eq(radius_hits, [2], "半径查询应返回相交实体。")
	assert_eq(records.size(), 2, "矩形记录查询应返回匹配记录。")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "active_strategy"), GF_SPATIAL_QUERY_INDEX_2D_SCRIPT.STRATEGY_QUADTREE, "auto 达阈值后应使用 quadtree。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.get_option_dictionary(records[0], "metadata"), "kind"), "unit", "记录应保留 metadata。")


func test_spatial_query_index_2d_quadtree_expands_configured_bounds_to_records() -> void:
	var index: GF_SPATIAL_QUERY_INDEX_2D_SCRIPT = GF_SPATIAL_QUERY_INDEX_2D_SCRIPT.new()
	var _configured: GF_SPATIAL_QUERY_INDEX_2D_SCRIPT = index.configure(
		Rect2(Vector2.ZERO, Vector2(10.0, 10.0)),
		GF_SPATIAL_QUERY_INDEX_2D_SCRIPT.STRATEGY_AUTO,
		{ "auto_quadtree_threshold": 1 }
	)
	var _inserted: bool = index.upsert(7, Rect2(Vector2(100.0, 100.0), Vector2(5.0, 5.0)))

	assert_eq(index.query_point(Vector2(101.0, 101.0)), [7], "配置 bounds 之外的记录也应被索引，而不是被 quadtree 根边界丢弃。")
	assert_eq(GFVariantData.get_option_string_name(index.get_debug_snapshot(), "active_strategy"), GF_SPATIAL_QUERY_INDEX_2D_SCRIPT.STRATEGY_QUADTREE)


func test_spatial_query_index_2d_into_queries_reuse_outputs_and_snapshot_records() -> void:
	var index: GF_SPATIAL_QUERY_INDEX_2D_SCRIPT = GF_SPATIAL_QUERY_INDEX_2D_SCRIPT.new()
	var _configured: GF_SPATIAL_QUERY_INDEX_2D_SCRIPT = index.configure(
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		GF_SPATIAL_QUERY_INDEX_2D_SCRIPT.STRATEGY_LINEAR
	)
	var _first: bool = index.upsert(1, Rect2(Vector2.ZERO, Vector2(10.0, 10.0)), { "kind": "unit" })
	var _second: bool = index.upsert(2, Rect2(Vector2(50.0, 50.0), Vector2(5.0, 5.0)), { "kind": "prop" })
	var hits: Array[int] = [99]
	var records: Array[Dictionary] = [{ "old": true }]

	var returned_hits: Array[int] = index.query_rect_into(Rect2(Vector2.ZERO, Vector2(20.0, 20.0)), hits)
	var returned_records: Array[Dictionary] = index.query_records_rect_into(Rect2(Vector2.ZERO, Vector2(20.0, 20.0)), records)
	records[0]["metadata"]["kind"] = "changed"
	var stored_record: Dictionary = index.get_entity_record(1)

	assert_eq(returned_hits, hits, "into 查询应返回调用方传入的数组。")
	assert_eq(hits, [1], "into 查询默认应清空旧输出并写入匹配 ID。")
	assert_eq(returned_records, records, "record into 查询应返回调用方传入的数组。")
	assert_eq(records.size(), 1, "record into 查询应清空旧输出并写入匹配记录。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.get_option_dictionary(stored_record, "metadata"), "kind"), "unit", "record 查询应返回 metadata 快照而不是内部引用。")


func test_spatial_query_index_3d_switches_strategy_and_filters_radius() -> void:
	var index: GF_SPATIAL_QUERY_INDEX_3D_SCRIPT = GF_SPATIAL_QUERY_INDEX_3D_SCRIPT.new()
	var _configured: GF_SPATIAL_QUERY_INDEX_3D_SCRIPT = index.configure(GF_SPATIAL_QUERY_INDEX_3D_SCRIPT.STRATEGY_AUTO, {
		"auto_spatial_hash_threshold": 1,
		"cell_size": 4.0,
	})
	var _first: bool = index.upsert(10, AABB(Vector3.ZERO, Vector3.ONE * 2.0), { "kind": "near" })
	var _second: bool = index.upsert(20, AABB(Vector3(10.0, 0.0, 0.0), Vector3.ONE), { "kind": "far" })

	var aabb_hits: Array[Variant] = index.query_aabb(AABB(Vector3(-1.0, -1.0, -1.0), Vector3(4.0, 4.0, 4.0)))
	var radius_records: Array[Dictionary] = index.query_records_radius(Vector3.ZERO, 3.0)
	var snapshot: Dictionary = index.get_debug_snapshot()

	assert_eq(aabb_hits, [10], "AABB 查询应返回相交实体。")
	assert_eq(radius_records.size(), 1, "半径记录查询应过滤远处实体。")
	var raw_record_entity: Variant = GFVariantData.get_option_value(radius_records[0], "entity")
	var record_entity: int = raw_record_entity if raw_record_entity is int else -1
	assert_eq(record_entity, 10, "记录应保留实体值。")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "active_strategy"), GF_SPATIAL_QUERY_INDEX_3D_SCRIPT.STRATEGY_SPATIAL_HASH, "auto 达阈值后应使用空间哈希。")

	assert_true(index.remove(10), "已存在实体应可移除。")
	assert_false(index.has_entity(10), "移除后实体应不存在。")


func test_spatial_query_index_3d_into_queries_reuse_outputs() -> void:
	var index: GF_SPATIAL_QUERY_INDEX_3D_SCRIPT = GF_SPATIAL_QUERY_INDEX_3D_SCRIPT.new()
	var _configured: GF_SPATIAL_QUERY_INDEX_3D_SCRIPT = index.configure(GF_SPATIAL_QUERY_INDEX_3D_SCRIPT.STRATEGY_LINEAR)
	var _first: bool = index.upsert(10, AABB(Vector3.ZERO, Vector3.ONE * 2.0), { "kind": "near" })
	var _second: bool = index.upsert(20, AABB(Vector3(10.0, 0.0, 0.0), Vector3.ONE), { "kind": "far" })
	var entities: Array = ["old"]
	var records: Array[Dictionary] = [{ "old": true }]

	var returned_entities: Array = index.query_aabb_into(AABB(Vector3.ZERO, Vector3.ONE * 3.0), entities)
	var returned_records: Array[Dictionary] = index.query_records_radius_into(Vector3.ZERO, 3.0, records)

	assert_eq(returned_entities, entities, "3D entity into 查询应返回调用方传入的数组。")
	assert_eq(entities, [10], "3D entity into 查询默认应清空旧输出并写入匹配实体。")
	assert_eq(returned_records, records, "3D record into 查询应返回调用方传入的数组。")
	assert_eq(records.size(), 1, "3D record into 查询应写入半径过滤后的记录。")
	assert_eq(GFVariantData.get_option_int(records[0], "entity"), 10, "3D record into 查询应保留实体值。")


func test_spatial_query_index_3d_rejects_unstable_composite_entity_keys() -> void:
	var index: GF_SPATIAL_QUERY_INDEX_3D_SCRIPT = GF_SPATIAL_QUERY_INDEX_3D_SCRIPT.new()

	assert_false(index.upsert(["unit"], AABB(Vector3.ZERO, Vector3.ONE)), "Array 不能作为 3D 查询索引实体 key。")
	assert_false(index.upsert({ "id": "unit" }, AABB(Vector3.ZERO, Vector3.ONE)), "Dictionary 不能作为 3D 查询索引实体 key。")
	assert_eq(index.get_entity_count(), 0, "被拒绝的实体不应进入 3D 查询索引。")


func test_spatial_query_index_2d_radius_zero_uses_point_query_semantics() -> void:
	var index: GF_SPATIAL_QUERY_INDEX_2D_SCRIPT = GF_SPATIAL_QUERY_INDEX_2D_SCRIPT.new()
	var _configured: GF_SPATIAL_QUERY_INDEX_2D_SCRIPT = index.configure(
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		GF_SPATIAL_QUERY_INDEX_2D_SCRIPT.STRATEGY_AUTO,
		{ "auto_quadtree_threshold": 1 }
	)
	var _inside: bool = index.upsert(1, Rect2(Vector2.ZERO, Vector2(10.0, 10.0)))
	var _outside: bool = index.upsert(2, Rect2(Vector2(20.0, 20.0), Vector2(5.0, 5.0)))

	assert_eq(index.query_radius(Vector2(2.0, 2.0), 0.0), [1], "2D 零半径查询应返回包含点的实体。")


func test_spatial_query_index_3d_radius_zero_uses_point_query_semantics() -> void:
	var index: GF_SPATIAL_QUERY_INDEX_3D_SCRIPT = GF_SPATIAL_QUERY_INDEX_3D_SCRIPT.new()
	var _configured: GF_SPATIAL_QUERY_INDEX_3D_SCRIPT = index.configure(GF_SPATIAL_QUERY_INDEX_3D_SCRIPT.STRATEGY_AUTO, {
		"auto_spatial_hash_threshold": 1,
		"cell_size": 4.0,
	})
	var _inside: bool = index.upsert(1, AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0)))
	var _outside: bool = index.upsert(2, AABB(Vector3(2.0, 0.0, 0.0), Vector3.ONE))

	assert_eq(index.query_radius(Vector3.ZERO, 0.0), [1], "3D 零半径查询应返回包含点的实体。")


func test_spatial_query_index_3d_sorts_integer_entities_numerically() -> void:
	var index: GF_SPATIAL_QUERY_INDEX_3D_SCRIPT = GF_SPATIAL_QUERY_INDEX_3D_SCRIPT.new()
	var _configured: GF_SPATIAL_QUERY_INDEX_3D_SCRIPT = index.configure(GF_SPATIAL_QUERY_INDEX_3D_SCRIPT.STRATEGY_LINEAR)
	var _ten: bool = index.upsert(10, AABB(Vector3.ZERO, Vector3.ONE))
	var _two: bool = index.upsert(2, AABB(Vector3.ZERO, Vector3.ONE))
	var _one: bool = index.upsert(1, AABB(Vector3.ZERO, Vector3.ONE))

	assert_eq(index.query_aabb(AABB(Vector3.ZERO, Vector3.ONE)), [1, 2, 10], "int 实体结果应按数值排序，而不是按字符串排序。")
