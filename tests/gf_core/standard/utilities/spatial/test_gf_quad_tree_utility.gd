## 测试 GFQuadTreeUtility 的插入、删除、更新和范围查询功能。
extends GutTest


# --- 私有变量 ---

var _tree: GFQuadTreeUtility


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_tree = GFQuadTreeUtility.new()
	_tree.setup(Rect2(0, 0, 1000, 1000), 6, 4)
	_tree.init()


func after_each() -> void:
	_tree = null


# --- 测试：插入与查询 ---

## 验证插入后可通过矩形查询找到实体。
func test_insert_and_query() -> void:
	_insert_entity(1, Rect2(100, 100, 50, 50))
	var result: Array[int] = _tree.query_rect(Rect2(90, 90, 70, 70))
	assert_true(result.has(1), "查询应找到已插入的实体。")


func test_insert_before_init_lazily_rebuilds_root() -> void:
	var tree: GFQuadTreeUtility = GFQuadTreeUtility.new()
	tree.bounds = Rect2(0, 0, 100, 100)
	tree.max_depth = -1
	tree.max_entities_per_node = 0

	var inserted: bool = tree.insert(1, Rect2(10, 10, 5, 5))
	var result: Array[int] = tree.query_rect(Rect2(0, 0, 20, 20))

	assert_true(inserted, "未显式 init 时合法插入应成功。")
	assert_true(result.has(1), "未显式 init 时插入应惰性创建根节点。")
	assert_eq(tree.max_depth, 0, "无效 depth 应被归一化。")
	assert_eq(tree.max_entities_per_node, 1, "无效 capacity 应被归一化。")


func test_insert_rejects_out_of_bounds_rect_without_storing_entity() -> void:
	var inserted: bool = _tree.insert(10, Rect2(1100, 1100, 10, 10))

	assert_false(inserted, "固定边界四叉树应拒绝 bounds 外实体。")
	assert_false(_tree.has_entity(10), "拒绝插入后实体不应进入全局索引。")
	assert_false(_tree.query_rect(Rect2(1090, 1090, 40, 40)).has(10), "拒绝插入后查询不应找到实体。")


func test_update_rejects_out_of_bounds_without_losing_existing_entity() -> void:
	var inserted: bool = _tree.insert_with_hit_test(7, Rect2(100, 100, 20, 20), func(_entity_id: int, _point: Vector2, _rect: Rect2) -> bool:
		return false
	)

	var updated: bool = _tree.update(7, Rect2(1200, 1200, 10, 10))
	var rough_result: Array[int] = _tree.query_point(Vector2(105, 105), false)
	var exact_result: Array[int] = _tree.query_point(Vector2(105, 105), true)

	assert_true(inserted, "测试准备应成功插入实体。")
	assert_false(updated, "越界 update 应失败。")
	assert_eq(_tree.get_entity_rect(7), Rect2(100, 100, 20, 20), "失败 update 不应修改旧矩形。")
	assert_true(rough_result.has(7), "失败 update 后旧位置仍应可粗略查询。")
	assert_false(exact_result.has(7), "失败 update 后旧命中测试仍应保留。")


func test_bounds_setter_prunes_entities_that_no_longer_fit() -> void:
	var inserted_inside: bool = _tree.insert(1, Rect2(10, 10, 10, 10))
	var inserted_edge: bool = _tree.insert(2, Rect2(900, 900, 20, 20))

	_tree.bounds = Rect2(0, 0, 100, 100)

	assert_true(inserted_inside, "测试准备应插入 bounds 内实体。")
	assert_true(inserted_edge, "测试准备应插入将被新 bounds 剔除的实体。")
	assert_true(_tree.has_entity(1), "新 bounds 内实体应保留。")
	assert_false(_tree.has_entity(2), "修改 bounds 后无法索引的实体应被剔除。")


func test_bounds_setter_rejects_non_finite_values_atomically() -> void:
	var original_bounds: Rect2 = _tree.bounds
	var inserted: bool = _tree.insert_with_hit_test(
		7,
		Rect2(100, 100, 20, 20),
		func(_entity_id: int, _point: Vector2, _rect: Rect2) -> bool:
			return false
	)

	_tree.bounds = Rect2(Vector2(NAN, 0.0), Vector2.ONE)

	assert_true(inserted)
	assert_push_error("[GFQuadTreeUtility] bounds 必须只包含有限值。")
	assert_eq(_tree.bounds, original_bounds, "非法配置不得覆盖最后有效边界。")
	assert_eq(_tree.get_entity_rect(7), Rect2(100, 100, 20, 20), "非法配置不得删除实体。")
	assert_true(_tree.query_point(Vector2(105, 105), false).has(7), "粗筛索引必须保留。")
	assert_false(_tree.query_point(Vector2(105, 105), true).has(7), "精确 hit test 必须保留。")


func test_setup_rejects_non_finite_bounds_before_mutating_limits_or_entities() -> void:
	var original_bounds: Rect2 = _tree.bounds
	var original_max_depth: int = _tree.max_depth
	var original_max_entities: int = _tree.max_entities_per_node
	var inserted: bool = _tree.insert(7, Rect2(100, 100, 20, 20))

	_tree.setup(Rect2(Vector2.ZERO, Vector2(INF, 1.0)), 1, 1)

	assert_true(inserted)
	assert_push_error("[GFQuadTreeUtility] bounds 必须只包含有限值。")
	assert_eq(_tree.bounds, original_bounds)
	assert_eq(_tree.max_depth, original_max_depth)
	assert_eq(_tree.max_entities_per_node, original_max_entities)
	assert_true(_tree.has_entity(7), "非法 setup 不得清除实体。")


func test_debug_snapshot_has_json_compatible_export() -> void:
	var inserted: bool = _tree.insert(1, Rect2(10, 10, 10, 10))
	var snapshot: Dictionary = _tree.get_json_compatible_debug_snapshot()
	var json_text: String = JSON.stringify(snapshot)

	assert_true(inserted, "测试准备应插入实体。")
	assert_false(json_text.is_empty(), "JSON-safe 四叉树快照应可序列化。")
	assert_false(json_text.contains(":null"), "JSON-safe 四叉树快照不应依赖 JSON.stringify 把非法值替换为 null。")


## 验证不在查询范围内的实体不被返回。
func test_query_miss() -> void:
	_insert_entity(1, Rect2(100, 100, 50, 50))
	var result: Array[int] = _tree.query_rect(Rect2(500, 500, 50, 50))
	assert_false(result.has(1), "不在范围内的实体不应被返回。")


## 验证多个实体的查询。
func test_multiple_entities() -> void:
	_insert_entity(1, Rect2(100, 100, 50, 50))
	_insert_entity(2, Rect2(120, 120, 50, 50))
	_insert_entity(3, Rect2(800, 800, 50, 50))
	var result: Array[int] = _tree.query_rect(Rect2(90, 90, 100, 100))
	assert_true(result.has(1), "实体 1 应在查询范围内。")
	assert_true(result.has(2), "实体 2 应在查询范围内。")
	assert_false(result.has(3), "实体 3 不应在查询范围内。")


# --- 测试：删除 ---

## 验证删除后查询不再返回。
func test_remove() -> void:
	_insert_entity(1, Rect2(100, 100, 50, 50))
	_tree.remove(1)
	var result: Array[int] = _tree.query_rect(Rect2(90, 90, 70, 70))
	assert_false(result.has(1), "删除后不应找到该实体。")


## 验证删除不存在的实体不报错。
func test_remove_nonexistent() -> void:
	_tree.remove(999)
	assert_eq(_tree.get_entity_count(), 0, "删除不存在的实体不应影响计数。")


# --- 测试：更新 ---

## 验证更新位置后旧位置查询不到、新位置可查到。
func test_update_moves_entity() -> void:
	_insert_entity(1, Rect2(100, 100, 50, 50))
	_update_entity(1, Rect2(800, 800, 50, 50))

	var old_result: Array[int] = _tree.query_rect(Rect2(90, 90, 70, 70))
	assert_false(old_result.has(1), "旧位置不应查到实体。")

	var new_result: Array[int] = _tree.query_rect(Rect2(790, 790, 70, 70))
	assert_true(new_result.has(1), "新位置应查到实体。")


func test_reinsert_same_entity_replaces_old_rect() -> void:
	_insert_entity(1, Rect2(100, 100, 50, 50))
	_insert_entity(1, Rect2(800, 800, 50, 50))

	var old_result: Array[int] = _tree.query_rect(Rect2(90, 90, 70, 70))
	var new_result: Array[int] = _tree.query_rect(Rect2(790, 790, 70, 70))

	assert_false(old_result.has(1), "重复插入同 ID 应移除旧位置。")
	assert_true(new_result.has(1), "重复插入同 ID 应写入新位置。")
	assert_eq(_tree.get_entity_count(), 1, "重复插入同 ID 不应增加实体计数。")


func test_reinsert_same_entity_clears_old_hit_test() -> void:
	_insert_entity_with_hit_test(1, Rect2(100, 100, 50, 50), func(_entity_id: int, _point: Vector2, _rect: Rect2) -> bool:
		return false
	)
	_insert_entity(1, Rect2(100, 100, 50, 50))

	var result: Array[int] = _tree.query_point(Vector2(110, 110), true)

	assert_true(result.has(1), "普通重复插入应替换旧记录并清除旧命中测试。")


# --- 测试：圆形查询 ---

## 验证圆形范围查询找到范围内的实体。
func test_query_radius_hit() -> void:
	_insert_entity(1, Rect2(100, 100, 10, 10))
	var result: Array[int] = _tree.query_radius(Vector2(105, 105), 50.0)
	assert_true(result.has(1), "圆形查询应找到范围内的实体。")


## 验证圆形范围查询排除范围外的实体。
func test_query_radius_miss() -> void:
	_insert_entity(1, Rect2(100, 100, 10, 10))
	var result: Array[int] = _tree.query_radius(Vector2(500, 500), 10.0)
	assert_false(result.has(1), "圆形查询不应找到范围外的实体。")


func test_query_radius_rejects_negative_radius() -> void:
	_insert_entity(1, Rect2(100, 100, 10, 10))
	var result: Array[int] = _tree.query_radius(Vector2(105, 105), -1.0)
	assert_true(result.is_empty(), "负半径查询应返回空结果。")


# --- 测试：点查询 ---

func test_query_point_returns_containing_entities() -> void:
	_insert_entity(1, Rect2(100, 100, 40, 40))
	_insert_entity(2, Rect2(300, 300, 40, 40))

	var result: Array[int] = _tree.query_point(Vector2(120, 120))

	assert_true(result.has(1), "点查询应返回包含查询点的实体。")
	assert_false(result.has(2), "点查询不应返回未包含查询点的实体。")
	assert_eq(_tree.query_first_point(Vector2(120, 120)), 1, "query_first_point 应返回第一个命中实体。")


func test_query_point_uses_exact_hit_test_when_registered() -> void:
	_insert_entity_with_hit_test(1, Rect2(100, 100, 100, 100), func(_entity_id: int, point: Vector2, rect: Rect2) -> bool:
		return point.distance_to(rect.get_center()) <= 10.0
	)

	var rough_result: Array[int] = _tree.query_point(Vector2(105, 105), false)
	var exact_result: Array[int] = _tree.query_point(Vector2(105, 105), true)
	var center_result: Array[int] = _tree.query_point(Vector2(150, 150), true)

	assert_true(rough_result.has(1), "关闭精确测试时应返回 AABB 命中实体。")
	assert_false(exact_result.has(1), "开启精确测试时应允许项目过滤 AABB 命中。")
	assert_true(center_result.has(1), "精确测试通过时应返回实体。")


func test_update_preserves_point_hit_test() -> void:
	_insert_entity_with_hit_test(1, Rect2(100, 100, 100, 100), func(_entity_id: int, point: Vector2, rect: Rect2) -> bool:
		return point.distance_to(rect.get_center()) <= 10.0
	)

	_update_entity(1, Rect2(300, 300, 100, 100))
	var result: Array[int] = _tree.query_point(Vector2(305, 305), true)

	assert_false(result.has(1), "更新位置后仍应保留精确命中测试。")


func test_compact_rebuilds_tree_without_losing_entities() -> void:
	for i: int in range(16):
		_insert_entity(i, Rect2(i * 20.0, i * 20.0, 10, 10))

	var before: Array[int] = _tree.query_point(Vector2(5, 5))
	_tree.compact()
	var after: Array[int] = _tree.query_point(Vector2(5, 5))

	assert_eq(before, after, "compact 后点查询结果应保持一致。")
	assert_eq(_tree.get_entity_count(), 16, "compact 不应改变实体数量。")


# --- 测试：边界条件 ---

## 验证空树查询返回空数组。
func test_empty_tree_query() -> void:
	var result: Array[int] = _tree.query_rect(Rect2(0, 0, 1000, 1000))
	assert_eq(result.size(), 0, "空树查询应返回空数组。")


## 验证 clear 后实体被清除。
func test_clear() -> void:
	_insert_entity(1, Rect2(100, 100, 50, 50))
	var hit_test_set: bool = _tree.set_entity_hit_test(1, func(_entity_id: int, _point: Vector2, _rect: Rect2) -> bool:
		return true
	)
	_insert_entity(2, Rect2(200, 200, 50, 50))
	_tree.clear()
	assert_eq(_tree.get_entity_count(), 0, "clear 后实体数应为 0。")
	assert_true(hit_test_set, "已存在实体应能设置命中测试。")
	assert_eq(GFVariantData.get_option_int(_tree.get_debug_snapshot(), "hit_test_count"), 0, "clear 后命中测试也应清空。")
	var result: Array[int] = _tree.query_rect(Rect2(0, 0, 1000, 1000))
	assert_eq(result.size(), 0, "clear 后查询应返回空。")


## 验证 has_entity 检查。
func test_has_entity() -> void:
	_insert_entity(42, Rect2(0, 0, 10, 10))
	assert_true(_tree.has_entity(42), "已插入的实体应存在。")
	assert_false(_tree.has_entity(99), "未插入的实体不应存在。")


## 验证大量实体触发分裂后仍可正确查询。
func test_split_and_query() -> void:
	for i: int in range(20):
		_insert_entity(i, Rect2(i * 40.0, i * 40.0, 30, 30))
	var result: Array[int] = _tree.query_rect(Rect2(0, 0, 200, 200))
	assert_true(result.size() > 0, "分裂后查询应仍能找到实体。")
	assert_true(result.has(0), "实体 0 应在查询范围内。")


## 验证边界上的实体能被查到。
func test_entity_on_boundary() -> void:
	_insert_entity(1, Rect2(0, 0, 10, 10))
	var result: Array[int] = _tree.query_rect(Rect2(0, 0, 10, 10))
	assert_true(result.has(1), "边界上的实体应被查到。")


# --- 私有/辅助方法 ---

func _insert_entity(entity_id: int, rect: Rect2) -> void:
	var inserted: bool = _tree.insert(entity_id, rect)
	assert_true(inserted, "测试准备应插入实体。")


func _insert_entity_with_hit_test(entity_id: int, rect: Rect2, hit_test: Callable) -> void:
	var inserted: bool = _tree.insert_with_hit_test(entity_id, rect, hit_test)
	assert_true(inserted, "测试准备应插入带命中测试的实体。")


func _update_entity(entity_id: int, rect: Rect2) -> void:
	var updated: bool = _tree.update(entity_id, rect)
	assert_true(updated, "测试准备应更新实体。")
