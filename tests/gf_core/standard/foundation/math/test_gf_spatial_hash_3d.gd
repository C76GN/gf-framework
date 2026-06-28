## 测试 GFSpatialHash3D 的插入、更新、移除和范围查询。
extends GutTest

# --- 测试方法 ---

## 验证 AABB 查询只返回相交实体。
func test_query_aabb_returns_intersecting_entities() -> void:
	var spatial_hash: GFSpatialHash3D = GFSpatialHash3D.new(2.0)
	var _insert_result_9: Variant = spatial_hash.insert("near", AABB(Vector3.ZERO, Vector3.ONE))
	var _insert_result_10: Variant = spatial_hash.insert("far", AABB(Vector3(8.0, 0.0, 0.0), Vector3.ONE))

	var result: Array[Variant] = spatial_hash.query_aabb(AABB(Vector3(-1.0, -1.0, -1.0), Vector3(3.0, 3.0, 3.0)))

	assert_true(result.has("near"), "查询范围应包含相交实体。")
	assert_false(result.has("far"), "查询范围不应包含未相交实体。")


## 验证更新实体会刷新桶索引。
func test_update_moves_entity_between_buckets() -> void:
	var spatial_hash: GFSpatialHash3D = GFSpatialHash3D.new(2.0)
	var _insert_result_21: Variant = spatial_hash.insert("unit", AABB(Vector3.ZERO, Vector3.ONE))

	var _update_result_23: Variant = spatial_hash.update("unit", AABB(Vector3(6.0, 0.0, 0.0), Vector3.ONE))

	assert_false(spatial_hash.query_aabb(AABB(Vector3.ZERO, Vector3.ONE)).has("unit"), "旧范围不应再查询到实体。")
	assert_true(spatial_hash.query_aabb(AABB(Vector3(5.5, -1.0, -1.0), Vector3(3.0, 3.0, 3.0))).has("unit"), "新范围应查询到实体。")


## 验证半径查询会按 AABB 与球体相交做二次过滤。
func test_query_radius_filters_candidates() -> void:
	var spatial_hash: GFSpatialHash3D = GFSpatialHash3D.new(4.0)
	var _insert_result_32: Variant = spatial_hash.insert("inside", AABB(Vector3(1.0, 0.0, 0.0), Vector3.ONE))
	var _insert_result_33: Variant = spatial_hash.insert("outside", AABB(Vector3(5.0, 0.0, 0.0), Vector3.ONE))

	var result: Array[Variant] = spatial_hash.query_radius(Vector3.ZERO, 2.5)

	assert_true(result.has("inside"), "半径内实体应被返回。")
	assert_false(result.has("outside"), "半径外实体应被过滤。")


## 验证移除实体会同步更新数量和查询结果。
func test_remove_erases_entity() -> void:
	var spatial_hash: GFSpatialHash3D = GFSpatialHash3D.new(2.0)
	var _insert_result_44: Variant = spatial_hash.insert("unit", AABB(Vector3.ZERO, Vector3.ONE))
	spatial_hash.remove("unit")

	assert_eq(spatial_hash.get_entity_count(), 0, "移除后实体数量应为 0。")
	assert_false(spatial_hash.has_entity("unit"), "移除后实体不应存在。")


## 验证世界坐标会按 floor 规则映射到格子，负坐标不会被截断到 0。
func test_get_cell_for_position_uses_floor_for_negative_positions() -> void:
	var spatial_hash: GFSpatialHash3D = GFSpatialHash3D.new(4.0)

	assert_eq(spatial_hash.get_cell_for_position(Vector3(-0.1, 0.0, -4.1)), Vector3i(-1, 0, -2), "负坐标应映射到正确格子。")


## 验证可以直接查询指定空间格子的候选实体。
func test_query_cell_returns_bucket_candidates() -> void:
	var spatial_hash: GFSpatialHash3D = GFSpatialHash3D.new(4.0)
	var _insert_result_60: Variant = spatial_hash.insert("inside", AABB(Vector3(1.0, 0.0, 1.0), Vector3.ONE))
	var _insert_result_61: Variant = spatial_hash.insert("outside", AABB(Vector3(10.0, 0.0, 0.0), Vector3.ONE))

	var result: Array[Variant] = spatial_hash.query_cell(Vector3i(0, 0, 0))

	assert_true(result.has("inside"), "目标格子应返回桶内实体。")
	assert_false(result.has("outside"), "其他格子的实体不应返回。")


## 验证格子范围查询会跨格收集并去重。
func test_query_cell_range_collects_cells_and_deduplicates_entities() -> void:
	var spatial_hash: GFSpatialHash3D = GFSpatialHash3D.new(4.0)
	var _insert_result_72: Variant = spatial_hash.insert("wide", AABB(Vector3(3.5, 0.0, 0.0), Vector3(2.0, 1.0, 1.0)))
	var _insert_result_73: Variant = spatial_hash.insert("far", AABB(Vector3(20.0, 0.0, 0.0), Vector3.ONE))

	var result: Array[Variant] = spatial_hash.query_cell_range(Vector3i(0, 0, 0), Vector3i(1, 0, 0))

	assert_eq(result.count("wide"), 1, "跨多个格子的实体只应返回一次。")
	assert_false(result.has("far"), "范围外实体不应返回。")


## 验证调试快照包含空间桶基础统计。
func test_get_debug_snapshot_reports_bucket_statistics() -> void:
	var spatial_hash: GFSpatialHash3D = GFSpatialHash3D.new(4.0)
	var _insert_result_84: Variant = spatial_hash.insert("a", AABB(Vector3.ZERO, Vector3.ONE))
	var _insert_result_85: Variant = spatial_hash.insert("b", AABB(Vector3(8.0, 0.0, 0.0), Vector3.ONE))

	var snapshot: Dictionary = spatial_hash.get_debug_snapshot()
	var cell_size: float = GFVariantData.get_option_float(snapshot, "cell_size")
	var entity_count: int = GFVariantData.get_option_int(snapshot, "entity_count")
	var bucket_count: int = GFVariantData.get_option_int(snapshot, "bucket_count")
	var max_bucket_size: int = GFVariantData.get_option_int(snapshot, "max_bucket_size")

	assert_eq(cell_size, 4.0, "快照应包含格子尺寸。")
	assert_eq(entity_count, 2, "快照应包含实体数量。")
	assert_gt(bucket_count, 0, "快照应包含桶数量。")
	assert_gt(max_bucket_size, 0, "快照应包含最大桶大小。")


## 验证正好贴到格子边界的 AABB 使用半开区间映射，不额外占用下一格。
func test_aabb_cell_mapping_uses_half_open_max_corner() -> void:
	var spatial_hash: GFSpatialHash3D = GFSpatialHash3D.new(4.0)
	var _inserted: bool = spatial_hash.insert("exact", AABB(Vector3.ZERO, Vector3(4.0, 4.0, 4.0)))

	assert_true(spatial_hash.query_cell(Vector3i(0, 0, 0)).has("exact"), "实体应占据自身范围所在格。")
	assert_false(spatial_hash.query_cell(Vector3i(1, 0, 0)).has("exact"), "最大边界正好贴格线时不应额外占据下一格。")
	assert_false(spatial_hash.query_cell(Vector3i(0, 1, 0)).has("exact"), "Y 最大边界也应使用半开区间。")
	assert_false(spatial_hash.query_cell(Vector3i(0, 0, 1)).has("exact"), "Z 最大边界也应使用半开区间。")


## 验证不稳定的复合 Variant 不会被接受为实体 key。
func test_insert_rejects_unstable_composite_entity_keys() -> void:
	var spatial_hash: GFSpatialHash3D = GFSpatialHash3D.new(4.0)

	assert_false(spatial_hash.insert(["unit"], AABB(Vector3.ZERO, Vector3.ONE)), "Array 不能作为稳定实体 key。")
	assert_false(spatial_hash.insert({ "id": "unit" }, AABB(Vector3.ZERO, Vector3.ONE)), "Dictionary 不能作为稳定实体 key。")
	assert_eq(spatial_hash.get_entity_count(), 0, "被拒绝的实体不应进入索引。")


## 验证超出覆盖格子上限的更新不会先删除旧实体。
func test_insert_over_covered_cell_limit_preserves_existing_record() -> void:
	var spatial_hash: GFSpatialHash3D = GFSpatialHash3D.new(1.0)
	spatial_hash.max_covered_cells = 8
	var _inserted: bool = spatial_hash.insert("unit", AABB(Vector3.ZERO, Vector3.ONE))

	var updated: bool = spatial_hash.update("unit", AABB(Vector3.ZERO, Vector3(10.0, 10.0, 10.0)))

	assert_false(updated, "超出覆盖格子上限的更新应失败。")
	assert_true(spatial_hash.has_entity("unit"), "失败更新不应删除已有实体。")
	assert_true(spatial_hash.query_aabb(AABB(Vector3.ZERO, Vector3.ONE)).has("unit"), "旧索引仍应可查询。")


## 验证超出覆盖格子上限的范围查询会直接返回空结果。
func test_query_aabb_over_covered_cell_limit_returns_empty() -> void:
	var spatial_hash: GFSpatialHash3D = GFSpatialHash3D.new(1.0)
	spatial_hash.max_covered_cells = 4
	var _inserted: bool = spatial_hash.insert("unit", AABB(Vector3.ZERO, Vector3.ONE))

	var result: Array[Variant] = spatial_hash.query_aabb(AABB(Vector3.ZERO, Vector3(3.0, 3.0, 3.0)))

	assert_true(result.is_empty(), "超出覆盖格子上限的 AABB 查询应短路为空。")


## 验证格子范围查询同样受覆盖格子上限保护。
func test_query_cell_range_over_covered_cell_limit_returns_empty() -> void:
	var spatial_hash: GFSpatialHash3D = GFSpatialHash3D.new(1.0)
	spatial_hash.max_covered_cells = 4
	var _inserted: bool = spatial_hash.insert("unit", AABB(Vector3.ZERO, Vector3.ONE))

	var result: Array[Variant] = spatial_hash.query_cell_range(Vector3i.ZERO, Vector3i(2, 0, 0))

	assert_true(result.is_empty(), "超出覆盖格子上限的格子范围查询应短路为空。")


## 验证零半径查询按点查询语义返回包含该点的实体。
func test_query_radius_zero_returns_entities_containing_point() -> void:
	var spatial_hash: GFSpatialHash3D = GFSpatialHash3D.new(4.0)
	var _inside: bool = spatial_hash.insert("inside", AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0)))
	var _outside: bool = spatial_hash.insert("outside", AABB(Vector3(2.0, 0.0, 0.0), Vector3.ONE))

	var result: Array[Variant] = spatial_hash.query_radius(Vector3.ZERO, 0.0)

	assert_true(result.has("inside"), "零半径查询应返回包含点的实体。")
	assert_false(result.has("outside"), "零半径查询不应返回同格但不包含点的实体。")
