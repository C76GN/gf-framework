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

	var point_hits: Array[Variant] = index.query_point(Vector2(2.0, 2.0))
	var radius_hits: Array[Variant] = index.query_radius(Vector2(21.0, 21.0), 3.0)
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
	var hits: Array = [99]
	var records: Array[Dictionary] = [{ "old": true }]

	var returned_hits: Array = index.query_rect_into(Rect2(Vector2.ZERO, Vector2(20.0, 20.0)), hits)
	var returned_records: Array[Dictionary] = index.query_records_rect_into(Rect2(Vector2.ZERO, Vector2(20.0, 20.0)), records)
	records[0]["metadata"]["kind"] = "changed"
	var stored_record: Dictionary = index.get_entity_record(1)

	assert_eq(returned_hits, hits, "into 查询应返回调用方传入的数组。")
	assert_eq(hits, [1], "into 查询默认应清空旧输出并写入匹配 ID。")
	assert_eq(returned_records, records, "record into 查询应返回调用方传入的数组。")
	assert_eq(records.size(), 1, "record into 查询应清空旧输出并写入匹配记录。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.get_option_dictionary(stored_record, "metadata"), "kind"), "unit", "record 查询应返回 metadata 快照而不是内部引用。")


func test_spatial_query_index_2d_debug_snapshot_has_json_compatible_export() -> void:
	var index: GF_SPATIAL_QUERY_INDEX_2D_SCRIPT = GF_SPATIAL_QUERY_INDEX_2D_SCRIPT.new()
	var _configured: GF_SPATIAL_QUERY_INDEX_2D_SCRIPT = index.configure(
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		GF_SPATIAL_QUERY_INDEX_2D_SCRIPT.STRATEGY_LINEAR
	)
	var _inserted: bool = index.upsert(1, Rect2(Vector2.ZERO, Vector2(10.0, 10.0)))

	var snapshot: Dictionary = index.get_json_compatible_debug_snapshot()
	var json_text: String = JSON.stringify(snapshot)

	assert_false(json_text.is_empty(), "JSON-safe 2D 空间索引快照应可序列化。")
	assert_false(json_text.contains(":null"), "JSON-safe 2D 空间索引快照不应依赖 JSON.stringify 降级非法值。")


func test_spatial_query_identity_is_shared_by_2d_and_3d_indexes() -> void:
	var index_2d: GF_SPATIAL_QUERY_INDEX_2D_SCRIPT = GF_SPATIAL_QUERY_INDEX_2D_SCRIPT.new()
	var _configured_2d: GF_SPATIAL_QUERY_INDEX_2D_SCRIPT = index_2d.configure(
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		GF_SPATIAL_QUERY_INDEX_2D_SCRIPT.STRATEGY_LINEAR
	)
	var index_3d: GF_SPATIAL_QUERY_INDEX_3D_SCRIPT = GF_SPATIAL_QUERY_INDEX_3D_SCRIPT.new()
	var _configured_3d: GF_SPATIAL_QUERY_INDEX_3D_SCRIPT = index_3d.configure(GF_SPATIAL_QUERY_INDEX_3D_SCRIPT.STRATEGY_LINEAR)
	var node: Node = Node.new()
	add_child_autofree(node)

	var _inserted_2d_name: bool = index_2d.upsert(&"unit", Rect2(Vector2.ZERO, Vector2(10.0, 10.0)))
	var _inserted_3d_name: bool = index_3d.upsert(&"unit", AABB(Vector3.ZERO, Vector3.ONE))
	var _inserted_2d_object: bool = index_2d.upsert(node, Rect2(Vector2(20.0, 20.0), Vector2(10.0, 10.0)))
	var _inserted_3d_object: bool = index_3d.upsert(node, AABB(Vector3(20.0, 0.0, 0.0), Vector3.ONE))

	var hits_2d: Array[Variant] = index_2d.query_point(Vector2(2.0, 2.0))
	var hits_3d: Array[Variant] = index_3d.query_aabb(AABB(Vector3.ZERO, Vector3.ONE))
	var record_2d: Dictionary = index_2d.get_entity_record(&"unit")
	var record_3d: Dictionary = index_3d.get_entity_record(&"unit")
	var object_record_2d: Dictionary = index_2d.get_entity_record(node)
	var identity_2d: Dictionary = GFVariantData.get_option_dictionary(record_2d, "identity")
	var identity_3d: Dictionary = GFVariantData.get_option_dictionary(record_3d, "identity")
	var object_identity_2d: Dictionary = GFVariantData.get_option_dictionary(object_record_2d, "identity")

	assert_eq(hits_2d, [&"unit"], "2D 查询应返回调用方传入的 StringName 实体。")
	assert_eq(hits_3d, [&"unit"], "3D 查询应返回调用方传入的 StringName 实体。")
	assert_eq(GFVariantData.get_option_string(identity_2d, "key"), "string_name:unit", "2D 记录应暴露统一 identity key。")
	assert_eq(GFVariantData.get_option_string(identity_3d, "key"), "string_name:unit", "3D 记录应暴露同一套 identity key。")
	assert_true(GFVariantData.get_option_string(object_identity_2d, "key").begins_with("object:"), "Object 实体应使用 object identity key。")
	assert_true(index_2d.has_entity(node), "2D Object 身份应可查询。")
	assert_true(index_3d.has_entity(node), "3D Object 身份应可查询。")


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


func test_spatial_query_indexes_reject_non_finite_geometry() -> void:
	var index_2d: GF_SPATIAL_QUERY_INDEX_2D_SCRIPT = GF_SPATIAL_QUERY_INDEX_2D_SCRIPT.new()
	var index_3d: GF_SPATIAL_QUERY_INDEX_3D_SCRIPT = GF_SPATIAL_QUERY_INDEX_3D_SCRIPT.new()

	assert_false(index_2d.upsert(1, Rect2(Vector2(NAN, 0.0), Vector2.ONE)))
	assert_false(index_2d.upsert_point(2, Vector2.ZERO, INF))
	assert_true(index_2d.query_rect(Rect2(Vector2.ZERO, Vector2(INF, 1.0))).is_empty())
	assert_true(index_2d.query_point(Vector2(NAN, 0.0)).is_empty())
	assert_eq(index_2d.get_entity_count(), 0, "非法 2D geometry 不得进入记录表。")

	assert_false(index_3d.upsert(1, AABB(Vector3(NAN, 0.0, 0.0), Vector3.ONE)))
	assert_true(index_3d.query_aabb(AABB(Vector3.ZERO, Vector3(INF, 1.0, 1.0))).is_empty())
	assert_true(index_3d.query_radius(Vector3.ZERO, NAN).is_empty())
	assert_eq(index_3d.get_entity_count(), 0, "非法 3D geometry 不得进入记录表。")


func test_spatial_query_index_3d_falls_back_when_hash_cannot_index_record() -> void:
	var index: GF_SPATIAL_QUERY_INDEX_3D_SCRIPT = GF_SPATIAL_QUERY_INDEX_3D_SCRIPT.new()
	var _configured: GF_SPATIAL_QUERY_INDEX_3D_SCRIPT = index.configure(
		GF_SPATIAL_QUERY_INDEX_3D_SCRIPT.STRATEGY_SPATIAL_HASH,
		{ "cell_size": 1.0 }
	)
	var huge_bounds: AABB = AABB(Vector3.ZERO, Vector3(100.0, 100.0, 100.0))

	assert_true(index.upsert("huge", huge_bounds), "facade 应保留可由 linear 查询的有限记录。")
	assert_eq(index.query_aabb(huge_bounds), ["huge"], "空间哈希拒绝记录后必须回退 linear，不能漏报。")
	var snapshot: Dictionary = index.get_debug_snapshot()
	assert_eq(
		GFVariantData.get_option_string_name(snapshot, "active_strategy"),
		GF_SPATIAL_QUERY_INDEX_3D_SCRIPT.STRATEGY_LINEAR,
		"调试快照应报告实际回退策略。"
	)
	assert_true(GFVariantData.get_option_bool(snapshot, "backend_build_failed"), "快照应暴露后端构建失败事实。")
	assert_false(GFVariantData.get_option_bool(snapshot, "index_dirty", true), "失败结果应被缓存，避免每次查询重复重建。")


func test_spatial_query_index_3d_debug_snapshot_has_json_compatible_export() -> void:
	var index: GF_SPATIAL_QUERY_INDEX_3D_SCRIPT = GF_SPATIAL_QUERY_INDEX_3D_SCRIPT.new()
	var _configured: GF_SPATIAL_QUERY_INDEX_3D_SCRIPT = index.configure(GF_SPATIAL_QUERY_INDEX_3D_SCRIPT.STRATEGY_LINEAR)
	var _inserted: bool = index.upsert(1, AABB(Vector3.ZERO, Vector3.ONE))

	var json_text: String = JSON.stringify(index.get_json_compatible_debug_snapshot())

	assert_false(json_text.is_empty(), "JSON-safe 3D 空间索引快照应可序列化。")
	assert_false(json_text.contains(":null"), "JSON-safe 3D 空间索引快照不应依赖非法值降级。")
