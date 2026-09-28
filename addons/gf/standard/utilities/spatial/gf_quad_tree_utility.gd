## GFQuadTreeUtility: 纯逻辑 2D 四叉树空间划分工具。
##
## 继承自 GFUtility，提供不依赖引擎物理节点的 2D 空间划分和范围查询能力。
## 适用于模拟经营、RTS 等需要对海量实体进行高效范围检索的场景。
##
## 用法：
##   1. 调用 setup(bounds, max_depth, max_entities) 初始化树的参数。
##   2. 调用 insert(entity_id, rect) 将 bounds 内实体插入四叉树。
##   3. 调用 query_rect(rect)、query_radius(center, radius) 或 query_point(point) 查询。
##   4. 调用 update(entity_id, rect) 更新实体位置（内部先移除再插入）。
##   5. 调用 remove(entity_id) 移除实体。
##
## 注意：entity_id 为 int，由调用方自行管理 ID 映射。四叉树使用固定世界边界，
## 不会自动扩容；不在 bounds 内的实体会被拒绝，避免出现已存储但不可查询的记录。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFQuadTreeUtility
extends GFUtility


# --- 常量 ---

## 默认最大树深度。
## [br]
## @api public
const DEFAULT_MAX_DEPTH: int = 8

## 默认每节点最大实体数（超过后分裂）。
## [br]
## @api public
const DEFAULT_MAX_ENTITIES: int = 8

## 为调试报告提供 JSON 兼容值转换的内部编解码器。
## [br]
## @api private
## [br]
const _GF_REPORT_VALUE_CODEC_SCRIPT = preload("res://addons/gf/kernel/core/gf_report_value_codec.gd")


# --- 公共变量 ---

## 四叉树覆盖的世界边界。
## [br]
## @api public
## [br]
## @since 3.17.0
var bounds: Rect2:
	get:
		return _bounds
	set(value):
		var normalized_bounds: Rect2 = _normalize_rect(value)
		if not _is_finite_rect(normalized_bounds):
			push_error("[GFQuadTreeUtility][quad_tree_utility.bounds_non_finite] bounds must contain only finite values.")
			return
		_bounds = normalized_bounds
		_rebuild_root_from_current_entities()

## 最大递归深度。
## [br]
## @api public
var max_depth: int = DEFAULT_MAX_DEPTH

## 每个节点在分裂前允许的最大实体数。
## [br]
## @api public
var max_entities_per_node: int = DEFAULT_MAX_ENTITIES


# --- 私有变量 ---

## 规范化后的固定世界边界。
## [br]
## @api private
## [br]
var _bounds: Rect2 = Rect2()

# 根节点。
## 当前空间索引的四叉树根节点。
## [br]
## @api private
## [br]
var _root: _QTNode

# 全局实体索引。Key 为 entity_id (int)，Value 为 Rect2。
## 全局实体 ID 到规范化包围矩形的索引。
## [br]
## @api private
## [br]
var _entity_rects: Dictionary = {}

# 实体点命中测试。Key 为 entity_id (int)，Value 为 Callable。
## 实体 ID 到可选精确点命中回调的映射。
## [br]
## @api private
## [br]
var _entity_hit_tests: Dictionary = {}


# --- GF 生命周期方法 ---

## 第一阶段初始化：创建空根节点。
## [br]
## @api public
func init() -> void:
	_entity_rects.clear()
	_entity_hit_tests.clear()
	_rebuild_root()


# --- 公共方法 ---

## 配置四叉树参数并重建。应在 init() 之前或之后调用。
## [br]
## @api public
## [br]
## @param world_bounds: 世界边界矩形。
## [br]
## @param depth: 最大递归深度。
## [br]
## @param entities_per_node: 每节点最大实体数。
func setup(world_bounds: Rect2, depth: int = DEFAULT_MAX_DEPTH, entities_per_node: int = DEFAULT_MAX_ENTITIES) -> void:
	var normalized_bounds: Rect2 = _normalize_rect(world_bounds)
	if not _is_finite_rect(normalized_bounds):
		push_error("[GFQuadTreeUtility][quad_tree_utility.bounds_non_finite] bounds must contain only finite values.")
		return
	max_depth = maxi(depth, 0)
	max_entities_per_node = maxi(entities_per_node, 1)
	_bounds = normalized_bounds
	clear()


## 判断矩形是否能被当前四叉树索引。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param rect: 待检测的轴对齐包围矩形。
## [br]
## @return: 矩形有限且完全位于 bounds 内时返回 true。
func can_index_rect(rect: Rect2) -> bool:
	return _is_indexable_rect(_normalize_rect(rect))


## 将实体插入四叉树。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param entity_id: 实体唯一标识。
## [br]
## @param rect: 实体的轴对齐包围矩形。
## [br]
## @return: 插入成功返回 true；rect 不可索引时返回 false 且不修改旧实体。
func insert(entity_id: int, rect: Rect2) -> bool:
	_ensure_root()
	var normalized_rect: Rect2 = _normalize_rect(rect)
	if not _is_indexable_rect(normalized_rect):
		return false
	if _entity_rects.has(entity_id):
		_remove_entity(entity_id, true)

	return _insert_normalized_rect(entity_id, normalized_rect)


## 将带精确点命中测试的实体插入四叉树。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param entity_id: 实体唯一标识。
## [br]
## @param rect: 实体的轴对齐包围矩形。
## [br]
## @param hit_test: 可选精确命中测试，签名为 `(entity_id, point, rect) -> bool`。
## [br]
## @return: 插入和命中测试注册都成功时返回 true。
func insert_with_hit_test(entity_id: int, rect: Rect2, hit_test: Callable) -> bool:
	if not insert(entity_id, rect):
		return false
	return set_entity_hit_test(entity_id, hit_test)


## 从四叉树中移除实体。
## [br]
## @api public
## [br]
## @param entity_id: 要移除的实体标识。
func remove(entity_id: int) -> void:
	_remove_entity(entity_id, true)


## 更新实体的位置（先移除再插入）。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param entity_id: 实体标识。
## [br]
## @param new_rect: 新的包围矩形。
## [br]
## @return: 更新成功返回 true；new_rect 不可索引时返回 false 且旧实体保持不变。
func update(entity_id: int, new_rect: Rect2) -> bool:
	var normalized_rect: Rect2 = _normalize_rect(new_rect)
	if not _is_indexable_rect(normalized_rect):
		return false

	var hit_test: Callable = _variant_to_callable(GFVariantData.get_option_value(_entity_hit_tests, entity_id, Callable()))
	_remove_entity(entity_id, false)
	var inserted: bool = _insert_normalized_rect(entity_id, normalized_rect)
	if hit_test.is_valid():
		_entity_hit_tests[entity_id] = hit_test
	return inserted


## 设置实体的精确点命中测试。
## [br]
## @api public
## [br]
## @param entity_id: 实体标识。
## [br]
## @param hit_test: 命中测试 Callable，签名为 `(entity_id, point, rect) -> bool`。
## [br]
## @return 设置成功返回 true。
func set_entity_hit_test(entity_id: int, hit_test: Callable) -> bool:
	if not _entity_rects.has(entity_id):
		return false
	if not hit_test.is_valid():
		var _removed: bool = _entity_hit_tests.erase(entity_id)
		return true

	_entity_hit_tests[entity_id] = hit_test
	return true


## 清除实体的精确点命中测试。
## [br]
## @api public
## [br]
## @param entity_id: 实体标识。
## [br]
## @return 清除成功返回 true。
func clear_entity_hit_test(entity_id: int) -> bool:
	var existed: bool = _entity_hit_tests.has(entity_id)
	var _removed: bool = _entity_hit_tests.erase(entity_id)
	return existed


## 获取实体矩形。
## [br]
## @api public
## [br]
## @param entity_id: 实体标识。
## [br]
## @return 实体矩形；不存在时返回空 Rect2。
func get_entity_rect(entity_id: int) -> Rect2:
	return _variant_to_rect2(GFVariantData.get_option_value(_entity_rects, entity_id, Rect2()))


## 矩形范围查询：返回与查询区域有交集的所有实体 ID。
## [br]
## @api public
## [br]
## @param area: 查询矩形。
## [br]
## @return 匹配的实体 ID 数组。
func query_rect(area: Rect2) -> Array[int]:
	_ensure_root()
	var result: Array[int] = []
	var visited: Dictionary = {}
	_root._query_rect(_normalize_rect(area), result, visited)
	return result


## 圆形范围查询：返回包围矩形与圆有交集的所有实体 ID。
## [br]
## @api public
## [br]
## @param center: 圆心坐标。
## [br]
## @param radius: 查询半径。
## [br]
## @return 匹配的实体 ID 数组。
func query_radius(center: Vector2, radius: float) -> Array[int]:
	if radius < 0.0:
		return []

	var query_bounds: Rect2 = Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
	var candidates: Array[int] = query_rect(query_bounds)
	var result: Array[int] = []
	var radius_sq: float = radius * radius

	for entity_id: int in candidates:
		if _entity_rects.has(entity_id):
			var rect: Rect2 = _variant_to_rect2(_entity_rects[entity_id])
			var closest: Vector2 = Vector2(
				clampf(center.x, rect.position.x, rect.position.x + rect.size.x),
				clampf(center.y, rect.position.y, rect.position.y + rect.size.y),
			)
			if center.distance_squared_to(closest) <= radius_sq:
				result.append(entity_id)

	return result


## 点查询：返回包含该点的实体 ID，可选执行精确命中测试。
## [br]
## @api public
## [br]
## @param point: 查询点。
## [br]
## @param use_exact_hit_tests: 是否执行通过 set_entity_hit_test() 注册的精确命中测试。
## [br]
## @return 匹配的实体 ID 数组。
func query_point(point: Vector2, use_exact_hit_tests: bool = true) -> Array[int]:
	_ensure_root()
	var candidates: Array[int] = []
	var visited: Dictionary = {}
	_root._query_point(point, candidates, visited)
	if not use_exact_hit_tests:
		return candidates

	var result: Array[int] = []
	for entity_id: int in candidates:
		if _passes_point_hit_test(entity_id, point):
			result.append(entity_id)
	return result


## 点查询：返回第一个包含该点的实体 ID，不存在时返回 -1。
## [br]
## @api public
## [br]
## @param point: 查询点。
## [br]
## @param use_exact_hit_tests: 是否执行精确命中测试。
## [br]
## @return 第一个实体 ID；不存在时返回 -1。
func query_first_point(point: Vector2, use_exact_hit_tests: bool = true) -> int:
	var result: Array[int] = query_point(point, use_exact_hit_tests)
	return result[0] if not result.is_empty() else -1


## 重建四叉树节点结构，保留实体、矩形和命中测试。
## [br]
## @api public
func compact() -> void:
	var rects: Dictionary = _entity_rects.duplicate()
	var hit_tests: Dictionary = _entity_hit_tests.duplicate()
	_entity_rects.clear()
	_entity_hit_tests.clear()
	_rebuild_root()
	for entity_id: int in rects.keys():
		var rect: Rect2 = _variant_to_rect2(rects[entity_id])
		if _insert_normalized_rect(entity_id, rect) and hit_tests.has(entity_id):
			_entity_hit_tests[entity_id] = _variant_to_callable(hit_tests[entity_id])


## 清空四叉树中的所有实体并重建根节点。
## [br]
## @api public
func clear() -> void:
	_entity_rects.clear()
	_entity_hit_tests.clear()
	_rebuild_root()


## 获取当前存储的实体总数。
## [br]
## @api public
## [br]
## @return 实体数量。
func get_entity_count() -> int:
	return _entity_rects.size()


## 检查实体是否存在于四叉树中。
## [br]
## @api public
## [br]
## @param entity_id: 实体标识。
## [br]
## @return 是否存在。
func has_entity(entity_id: int) -> bool:
	return _entity_rects.has(entity_id)


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 四叉树状态。
## [br]
## @schema return: Dictionary with `bounds: Rect2`, `entity_count: int`, `hit_test_count: int`, `max_depth: int`, `max_entities_per_node: int`, and `node_count: int`.
func get_debug_snapshot() -> Dictionary:
	_ensure_root()
	return {
		"bounds": _bounds,
		"entity_count": _entity_rects.size(),
		"hit_test_count": _entity_hit_tests.size(),
		"max_depth": max_depth,
		"max_entities_per_node": max_entities_per_node,
		"node_count": _root._get_node_count(),
	}


## 获取 JSON.stringify() 安全的调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 报告编码选项，透传给 GFReportValueCodec。
## [br]
## @return: JSON 兼容调试快照。
## [br]
## @schema options: Dictionary with GFReportValueCodec options.
## [br]
## @schema return: Dictionary safe for JSON.stringify().
func get_json_compatible_debug_snapshot(options: Dictionary = {}) -> Dictionary:
	return GFVariantData.as_dictionary(_GF_REPORT_VALUE_CODEC_SCRIPT.to_json_compatible(get_debug_snapshot(), options))


# --- 私有/辅助方法 ---

## 规范化树限制，并在根节点缺失或限制变化时重建树。
## [br]
## @api private
## [br]
func _ensure_root() -> void:
	var limits_changed: bool = _normalize_tree_limits()
	if _root == null:
		_rebuild_root()
	elif limits_changed:
		_rebuild_root_from_current_entities()


## 规范化边界和限制后创建新的空根节点。
## [br]
## @api private
## [br]
func _rebuild_root() -> void:
	var _limits_changed: bool = _normalize_tree_limits()
	_bounds = _normalize_rect(_bounds)
	_root = _QTNode.new(_bounds, 0, max_depth, max_entities_per_node)


## 将最大深度限制为非负数、节点容量限制为至少 1，并返回是否改变。
## [br]
## @api private
## [br]
func _normalize_tree_limits() -> bool:
	var normalized_depth: int = maxi(max_depth, 0)
	var normalized_capacity: int = maxi(max_entities_per_node, 1)
	var changed: bool = normalized_depth != max_depth or normalized_capacity != max_entities_per_node
	max_depth = normalized_depth
	max_entities_per_node = normalized_capacity
	return changed


## 重建根节点后重新插入仍位于世界边界内的实体及其命中回调。
## [br]
## @api private
## [br]
func _rebuild_root_from_current_entities() -> void:
	var rects: Dictionary = _entity_rects.duplicate()
	var hit_tests: Dictionary = _entity_hit_tests.duplicate()
	_entity_rects.clear()
	_entity_hit_tests.clear()
	_rebuild_root()
	for entity_id: int in rects.keys():
		var rect: Rect2 = _variant_to_rect2(rects[entity_id])
		if _insert_normalized_rect(entity_id, rect) and hit_tests.has(entity_id):
			_entity_hit_tests[entity_id] = _variant_to_callable(hit_tests[entity_id])


## 拒绝不可索引矩形；否则同时更新全局索引和四叉树节点。
## [br]
## @api private
## [br]
func _insert_normalized_rect(entity_id: int, normalized_rect: Rect2) -> bool:
	if not _is_indexable_rect(normalized_rect):
		return false
	_entity_rects[entity_id] = normalized_rect
	_root._insert(entity_id, normalized_rect)
	return true


## 从四叉树和全局矩形索引移除实体，并按选项清除精确命中回调。
## [br]
## @api private
## [br]
func _remove_entity(entity_id: int, erase_hit_test: bool) -> void:
	if not _entity_rects.has(entity_id):
		return
	_ensure_root()
	var rect: Rect2 = _variant_to_rect2(_entity_rects[entity_id])
	_root._remove(entity_id, rect)
	var _removed: bool = _entity_rects.erase(entity_id)
	if erase_hit_test:
		var _hit_test_removed: bool = _entity_hit_tests.erase(entity_id)


## 对已索引实体执行自定义点命中回调；无回调时使用矩形包含测试。
## [br]
## @api private
## [br]
func _passes_point_hit_test(entity_id: int, point: Vector2) -> bool:
	if not _entity_rects.has(entity_id):
		return false

	var rect: Rect2 = _variant_to_rect2(_entity_rects[entity_id])
	var hit_test: Callable = _variant_to_callable(GFVariantData.get_option_value(_entity_hit_tests, entity_id, Callable()))
	if hit_test.is_valid():
		return GFVariantData.to_bool(hit_test.call(entity_id, point, rect))
	return _rect_contains_point(rect, point)


## 将负宽或负高转换为正尺寸，并移动原点以保留矩形覆盖范围。
## [br]
## @api private
## [br]
func _normalize_rect(rect: Rect2) -> Rect2:
	var position: Vector2 = rect.position
	var size: Vector2 = rect.size
	if size.x < 0.0:
		position.x += size.x
		size.x = -size.x
	if size.y < 0.0:
		position.y += size.y
		size.y = -size.y
	return Rect2(position, size)


## 检查矩形坐标有限且整个矩形位于固定世界边界内。
## [br]
## @api private
## [br]
func _is_indexable_rect(rect: Rect2) -> bool:
	return _is_finite_rect(rect) and _rect_contains_rect(_bounds, rect)


## 检查矩形的位置、尺寸及终点坐标均为有限数值。
## [br]
## @api private
## [br]
func _is_finite_rect(rect: Rect2) -> bool:
	var end: Vector2 = rect.position + rect.size
	return (
		_is_finite_float(rect.position.x)
		and _is_finite_float(rect.position.y)
		and _is_finite_float(rect.size.x)
		and _is_finite_float(rect.size.y)
		and _is_finite_float(end.x)
		and _is_finite_float(end.y)
	)


## 拒绝 NaN 和正负无穷浮点值。
## [br]
## @api private
## [br]
func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


## 判断有限容器矩形是否包含目标矩形的两个对角端点。
## [br]
## @api private
## [br]
func _rect_contains_rect(container: Rect2, rect: Rect2) -> bool:
	return (
		_is_finite_rect(container)
		and _rect_contains_point(container, rect.position)
		and _rect_contains_point(container, rect.position + rect.size)
	)


## 使用包含边界的比较判断矩形是否覆盖指定点。
## [br]
## @api private
## [br]
func _rect_contains_point(rect: Rect2, point: Vector2) -> bool:
	return (
		point.x >= rect.position.x
		and point.y >= rect.position.y
		and point.x <= rect.position.x + rect.size.x
		and point.y <= rect.position.y + rect.size.y
	)


## 将 Variant 收窄为 Callable；类型不符时返回无效 Callable。
## [br]
## @api private
## [br]
static func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


## 将 Variant 收窄为 Rect2；类型不符时返回空 Rect2。
## [br]
## @api private
## [br]
static func _variant_to_rect2(value: Variant) -> Rect2:
	if value is Rect2:
		var rect: Rect2 = value
		return rect
	return Rect2()


# --- 内部类 ---

## 管理局部实体集合及其子节点的四叉树节点。
## [br]
## @api private
## [br]
class _QTNode:
	# --- 私有变量 ---
	## 本节点覆盖的固定矩形，子节点由其四等分产生。
	## [br]
	## @api private
	var _node_bounds: Rect2

	## 根为零的层级，用于限制继续分裂。
	## [br]
	## @api private
	var _depth: int

	## 创建时继承的最大深度；外层设置变化由重建整棵树生效。
	## [br]
	## @api private
	var _max_depth_limit: int

	## 未分裂叶节点的容量阈值，超过且深度允许时触发分裂。
	## [br]
	## @api private
	var _max_entities_limit: int

	## 仍保留在本节点的实体标识；已下放的实体可同时出现在多个子节点。
	## [br]
	## @api private
	var _entities: Array[int] = []

	## 本节点实体矩形索引，和本地标识数组一起维护。
	## [br]
	## @api private
	var _entity_rects: Dictionary = {}

	## 分裂后按四象限顺序保存的子节点；查询跨节点以 visited 去重。
	## [br]
	## @api private
	var _children: Array = []

	## 是否已创建四个子节点；删除不会合并节点，压缩由外层重建实现。
	## [br]
	## @api private
	var _is_split: bool = false


	# --- Godot 生命周期方法 ---

	func _init(
		p_bounds: Rect2,
		p_depth: int,
		p_max_depth: int,
		p_max_entities: int
	) -> void:
		_node_bounds = p_bounds
		_depth = p_depth
		_max_depth_limit = p_max_depth
		_max_entities_limit = p_max_entities


	# --- 私有/辅助方法 ---

	## 已分裂时尝试放入所有相交子节点；没有子节点接纳才留在本地。叶节点超过容量且未达深度上限时分裂。
	## [br]
	## @api private
	func _insert(entity_id: int, rect: Rect2) -> void:
		if _is_split:
			if _insert_into_children(entity_id, rect):
				return

		if not _entities.has(entity_id):
			_entities.append(entity_id)
		_entity_rects[entity_id] = rect

		if not _is_split and _entities.size() > _max_entities_limit and _depth < _max_depth_limit:
			_split()


	## 移除本地标识与矩形，并递归清理所有与旧矩形相交的子树；保留已有分裂结构。
	## [br]
	## @api private
	func _remove(entity_id: int, rect: Rect2) -> void:
		_entities.erase(entity_id)
		var _removed: bool = _entity_rects.erase(entity_id)

		if _is_split:
			for child: _QTNode in _children:
				if child._node_bounds.intersects(rect):
					child._remove(entity_id, rect)


	## 不相交子树直接剪枝；先查本地再递归子树，共享 visited 防止跨象限实体重复返回。
	## [br]
	## @api private
	func _query_rect(query: Rect2, result: Array[int], visited: Dictionary) -> void:
		if not _node_bounds.intersects(query):
			return

		_query_local_rect(query, result, visited)
		if _is_split:
			for child: _QTNode in _children:
				child._query_rect(query, result, visited)


	## 使用包含边界的点测试剪枝，先查本地再查子树；共享 visited 对分界线上的重复候选去重。
	## [br]
	## @api private
	func _query_point(point: Vector2, result: Array[int], visited: Dictionary) -> void:
		if not _contains_point(_node_bounds, point):
			return

		_query_local_point(point, result, visited)
		if _is_split:
			for child: _QTNode in _children:
				child._query_point(point, result, visited)


	## 统计自身及所有已分裂后代，用于结构调试；空节点仍计入。
	## [br]
	## @api private
	func _get_node_count() -> int:
		var count: int = 1
		if _is_split:
			for child: _QTNode in _children:
				count += child._get_node_count()
		return count


	## 创建四个半尺寸子节点后清空本地索引，再按原实体快照重新插入；跨象限矩形可被多份索引。
	## [br]
	## @api private
	func _split() -> void:
		var half_size: Vector2 = _node_bounds.size * 0.5
		var pos: Vector2 = _node_bounds.position
		var next_depth: int = _depth + 1

		_children = [
			_QTNode.new(Rect2(pos, half_size), next_depth, _max_depth_limit, _max_entities_limit),
			_QTNode.new(Rect2(Vector2(pos.x + half_size.x, pos.y), half_size), next_depth, _max_depth_limit, _max_entities_limit),
			_QTNode.new(Rect2(Vector2(pos.x, pos.y + half_size.y), half_size), next_depth, _max_depth_limit, _max_entities_limit),
			_QTNode.new(Rect2(pos + half_size, half_size), next_depth, _max_depth_limit, _max_entities_limit),
		]
		_is_split = true

		var old_entities: Array[int] = _entities.duplicate()
		var old_rects: Dictionary = _entity_rects.duplicate()
		_entities.clear()
		_entity_rects.clear()

		for entity_id: int in old_entities:
			if old_rects.has(entity_id):
				_insert(entity_id, GFQuadTreeUtility._variant_to_rect2(old_rects[entity_id]))


	## 向每个相交子节点插入同一实体；返回是否至少有一处接纳，不要求矩形完整落入单个子节点。
	## [br]
	## @api private
	func _insert_into_children(entity_id: int, rect: Rect2) -> bool:
		var inserted: bool = false
		for child: _QTNode in _children:
			if child._node_bounds.intersects(rect):
				child._insert(entity_id, rect)
				inserted = true
		return inserted


	## 只把本地矩形与查询相交且尚未返回的实体加入结果，并同步登记 visited。
	## [br]
	## @api private
	func _query_local_rect(query: Rect2, result: Array[int], visited: Dictionary) -> void:
		for entity_id: int in _entities:
			if visited.has(entity_id) or not _entity_rects.has(entity_id):
				continue

			var rect: Rect2 = GFQuadTreeUtility._variant_to_rect2(_entity_rects[entity_id])
			if rect.intersects(query):
				visited[entity_id] = true
				result.append(entity_id)


	## 按包含边界的矩形测试加入本地候选，并登记 visited；精确形状命中由外层随后处理。
	## [br]
	## @api private
	func _query_local_point(point: Vector2, result: Array[int], visited: Dictionary) -> void:
		for entity_id: int in _entities:
			if visited.has(entity_id) or not _entity_rects.has(entity_id):
				continue

			var rect: Rect2 = GFQuadTreeUtility._variant_to_rect2(_entity_rects[entity_id])
			if _contains_point(rect, point):
				visited[entity_id] = true
				result.append(entity_id)


	## 使用含四条边界的比较，使位于树边缘或分割线上的点仍可作为候选。
	## [br]
	## @api private
	func _contains_point(rect: Rect2, point: Vector2) -> bool:
		return (
			point.x >= rect.position.x
			and point.y >= rect.position.y
			and point.x <= rect.position.x + rect.size.x
			and point.y <= rect.position.y + rect.size.y
		)
