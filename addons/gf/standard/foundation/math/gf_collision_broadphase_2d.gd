## GFCollisionBroadphase2D: 纯 2D AABB broadphase 候选对生成工具。
##
## 使用 `Rect2` body 记录生成可能相交的候选对，提供暴力枚举、Sweep and Prune、
## Quadtree 和自动组合入口。它只做 AABB 粗筛，不执行 SAT、接触点计算、
## 物理响应、命中分发或玩法规则判断。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 5.0.0
class_name GFCollisionBroadphase2D
extends RefCounted


# --- 常量 ---

## 暴力枚举 broadphase。
## [br]
## @api public
## [br]
## @since 5.0.0
const ALGORITHM_BRUTE_FORCE: StringName = &"bruteforce"

## Sweep and Prune broadphase。
## [br]
## @api public
## [br]
## @since 5.0.0
const ALGORITHM_SAP: StringName = &"sap"

## Quadtree broadphase。
## [br]
## @api public
## [br]
## @since 5.0.0
const ALGORITHM_QUADTREE: StringName = &"quadtree"

## 自动选择 broadphase。
## [br]
## @api public
## [br]
## @since 5.0.0
const ALGORITHM_AUTO: StringName = &"auto"

## 默认碰撞层。
## [br]
## @api public
## [br]
## @since 5.0.0
const DEFAULT_COLLISION_LAYER: int = 1

## 默认碰撞掩码。
## [br]
## @api public
## [br]
## @since 5.0.0
const DEFAULT_COLLISION_MASK: int = 0xffffffff

const _DEFAULT_BRUTE_FORCE_THRESHOLD: int = 24
const _DEFAULT_QUADTREE_THRESHOLD: int = 64
const _DEFAULT_QUADTREE_MAX_DEPTH: int = 8
const _DEFAULT_QUADTREE_CAPACITY: int = 8


# --- 公共方法 ---

## 创建 2D broadphase body 记录。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param entity: 调用方实体标识。
## [br]
## @schema entity: Variant entity identity copied into generated pair reports.
## [br]
## @param bounds: 轴对齐包围矩形；负尺寸会被归一化。
## [br]
## @param collision_layer: 当前 body 所在层。
## [br]
## @param collision_mask: 当前 body 可匹配的层。
## [br]
## @param enabled: 为 false 时默认不会参与候选对生成。
## [br]
## @param metadata: 调用方附加元数据；候选对不会解释这些字段。
## [br]
## @return body 字典。
## [br]
## @schema metadata: Dictionary caller metadata copied by value.
## [br]
## @schema return: Dictionary with `entity`, `bounds: Rect2`, `collision_layer: int`, `collision_mask: int`, `enabled: bool`, and `metadata: Dictionary`.
static func make_body(
	entity: Variant,
	bounds: Rect2,
	collision_layer: int = DEFAULT_COLLISION_LAYER,
	collision_mask: int = DEFAULT_COLLISION_MASK,
	enabled: bool = true,
	metadata: Dictionary = {}
) -> Dictionary:
	return {
		"entity": entity,
		"bounds": _normalize_rect(bounds),
		"collision_layer": collision_layer,
		"collision_mask": collision_mask,
		"enabled": enabled,
		"metadata": metadata.duplicate(true),
	}


## 使用暴力枚举生成 2D AABB 候选对。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param bodies: body 字典数组，建议由 `make_body()` 创建。
## [br]
## @param options: 可选控制，支持 `include_touching`、`use_collision_masks`、`enabled_only` 与 `max_pairs`。
## [br]
## @return 候选对数组。
## [br]
## @schema bodies: Array[Dictionary] broadphase body records.
## [br]
## @schema options: Dictionary with optional `include_touching: bool`, `use_collision_masks: bool`, `enabled_only: bool`, and `max_pairs: int`.
## [br]
## @schema return: Array[Dictionary] pair records with `a`, `b`, `a_index`, `b_index`, `a_bounds`, and `b_bounds`.
static func find_pairs_bruteforce(bodies: Array, options: Dictionary = {}) -> Array[Dictionary]:
	var normalized_bodies: Array[Dictionary] = _normalize_bodies(bodies, options)
	var pairs: Array[Dictionary] = []
	var seen: Dictionary = {}
	var max_pairs: int = _get_max_pairs(options)
	for left_index: int in range(normalized_bodies.size()):
		for right_index: int in range(left_index + 1, normalized_bodies.size()):
			if _append_pair_if_overlapping(
				normalized_bodies[left_index],
				normalized_bodies[right_index],
				options,
				seen,
				pairs,
				max_pairs
			):
				return pairs
	return pairs


## 使用 Sweep and Prune 生成 2D AABB 候选对。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param bodies: body 字典数组，建议由 `make_body()` 创建。
## [br]
## @param options: 可选控制，支持 `include_touching`、`use_collision_masks`、`enabled_only` 与 `max_pairs`。
## [br]
## @return 候选对数组。
## [br]
## @schema bodies: Array[Dictionary] broadphase body records.
## [br]
## @schema options: Dictionary with optional `include_touching: bool`, `use_collision_masks: bool`, `enabled_only: bool`, and `max_pairs: int`.
## [br]
## @schema return: Array[Dictionary] pair records with `a`, `b`, `a_index`, `b_index`, `a_bounds`, and `b_bounds`.
static func find_pairs_sap(bodies: Array, options: Dictionary = {}) -> Array[Dictionary]:
	var normalized_bodies: Array[Dictionary] = _normalize_bodies(bodies, options)
	_sort_bodies_by_x(normalized_bodies)

	var pairs: Array[Dictionary] = []
	var seen: Dictionary = {}
	var max_pairs: int = _get_max_pairs(options)
	var include_touching: bool = GFVariantData.get_option_bool(options, "include_touching", false)
	for left_index: int in range(normalized_bodies.size()):
		var left_body: Dictionary = normalized_bodies[left_index]
		var left_max_x: float = _rect_max_x(_get_body_bounds(left_body))
		for right_index: int in range(left_index + 1, normalized_bodies.size()):
			var right_body: Dictionary = normalized_bodies[right_index]
			var right_min_x: float = _get_body_bounds(right_body).position.x
			if _sap_can_break(left_max_x, right_min_x, include_touching):
				break
			if _append_pair_if_overlapping(left_body, right_body, options, seen, pairs, max_pairs):
				return pairs
	return pairs


## 使用 Quadtree 生成 2D AABB 候选对。`world_bounds` 只用于分割提示，不作为过滤条件；
## body 不落入当前分割范围时会退回局部暴力枚举，避免静默丢 pair。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param bodies: body 字典数组，建议由 `make_body()` 创建。
## [br]
## @param options: 可选控制，支持 `world_bounds: Rect2`、`quadtree_max_depth`、`quadtree_capacity`、`include_touching`、`use_collision_masks`、`enabled_only` 与 `max_pairs`。
## [br]
## @return 候选对数组。
## [br]
## @schema bodies: Array[Dictionary] broadphase body records.
## [br]
## @schema options: Dictionary with optional `world_bounds: Rect2`, `quadtree_max_depth: int`, `quadtree_capacity: int`, `include_touching: bool`, `use_collision_masks: bool`, `enabled_only: bool`, and `max_pairs: int`.
## [br]
## @schema return: Array[Dictionary] pair records with `a`, `b`, `a_index`, `b_index`, `a_bounds`, and `b_bounds`.
static func find_pairs_quadtree(bodies: Array, options: Dictionary = {}) -> Array[Dictionary]:
	var normalized_bodies: Array[Dictionary] = _normalize_bodies(bodies, options)
	var pairs: Array[Dictionary] = []
	if normalized_bodies.size() < 2:
		return pairs

	var world_bounds: Rect2 = _get_world_bounds(normalized_bodies, options)
	if world_bounds.size.x <= 0.0 or world_bounds.size.y <= 0.0:
		return find_pairs_sap(bodies, options)

	var seen: Dictionary = {}
	var max_pairs: int = _get_max_pairs(options)
	var max_depth: int = maxi(GFVariantData.get_option_int(options, "quadtree_max_depth", _DEFAULT_QUADTREE_MAX_DEPTH), 0)
	var capacity: int = maxi(GFVariantData.get_option_int(options, "quadtree_capacity", _DEFAULT_QUADTREE_CAPACITY), 1)
	var _stopped: bool = _collect_quadtree_pairs(
		normalized_bodies,
		world_bounds,
		0,
		max_depth,
		capacity,
		options,
		seen,
		pairs,
		max_pairs
	)
	return pairs


## 按选定或自动算法生成 2D AABB 候选对。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param bodies: body 字典数组，建议由 `make_body()` 创建。
## [br]
## @param options: 可选控制，支持 `algorithm: StringName` 以及各算法选项。
## [br]
## @return 候选对数组。
## [br]
## @schema bodies: Array[Dictionary] broadphase body records.
## [br]
## @schema options: Dictionary with optional `algorithm: StringName` plus bruteforce, SAP, or quadtree options.
## [br]
## @schema return: Array[Dictionary] pair records with `a`, `b`, `a_index`, `b_index`, `a_bounds`, and `b_bounds`.
static func find_pairs_combined(bodies: Array, options: Dictionary = {}) -> Array[Dictionary]:
	var algorithm: StringName = _choose_algorithm(bodies, options)
	match algorithm:
		ALGORITHM_BRUTE_FORCE:
			return find_pairs_bruteforce(bodies, options)
		ALGORITHM_QUADTREE:
			return find_pairs_quadtree(bodies, options)
		_:
			return find_pairs_sap(bodies, options)


## 生成包含算法、输入数量和候选对的 2D broadphase 报告。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param bodies: body 字典数组，建议由 `make_body()` 创建。
## [br]
## @param options: 可选控制，支持 `algorithm: StringName` 以及各算法选项。
## [br]
## @return broadphase 报告。
## [br]
## @schema bodies: Array[Dictionary] broadphase body records.
## [br]
## @schema options: Dictionary with optional `algorithm: StringName` plus bruteforce, SAP, or quadtree options.
## [br]
## @schema return: Dictionary with `algorithm: StringName`, `body_count: int`, `pair_count: int`, and `pairs: Array[Dictionary]`.
static func build_pair_report(bodies: Array, options: Dictionary = {}) -> Dictionary:
	var algorithm: StringName = _choose_algorithm(bodies, options)
	var pair_options: Dictionary = options.duplicate(true)
	pair_options["algorithm"] = algorithm
	var pairs: Array[Dictionary] = find_pairs_combined(bodies, pair_options)
	return {
		"algorithm": algorithm,
		"body_count": _normalize_bodies(bodies, options).size(),
		"pair_count": pairs.size(),
		"pairs": pairs,
	}


# --- 私有/辅助方法 ---

static func _normalize_bodies(bodies: Array, options: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var enabled_only: bool = GFVariantData.get_option_bool(options, "enabled_only", true)
	for index: int in range(bodies.size()):
		var body: Dictionary = _normalize_body(bodies[index], index)
		if body.is_empty():
			continue
		if enabled_only and not GFVariantData.get_option_bool(body, "enabled", true):
			continue
		result.append(body)
	return result


static func _normalize_body(value: Variant, index: int) -> Dictionary:
	if not (value is Dictionary):
		return {}

	var source: Dictionary = GFVariantData.as_dictionary(value)
	var bounds_value: Variant = GFVariantData.get_option_value(source, "bounds")
	if not (bounds_value is Rect2):
		return {}

	var metadata_value: Variant = GFVariantData.get_option_value(source, "metadata", {})
	var metadata: Dictionary = GFVariantData.as_dictionary(metadata_value, {})
	var entity: Variant = GFVariantData.get_option_value(source, "entity", index)
	var bounds: Rect2 = bounds_value
	return {
		"entity": entity,
		"bounds": _normalize_rect(bounds),
		"collision_layer": GFVariantData.get_option_int(source, "collision_layer", DEFAULT_COLLISION_LAYER),
		"collision_mask": GFVariantData.get_option_int(source, "collision_mask", DEFAULT_COLLISION_MASK),
		"enabled": GFVariantData.get_option_bool(source, "enabled", true),
		"metadata": metadata.duplicate(true),
		"index": index,
	}


static func _append_pair_if_overlapping(
	left_body: Dictionary,
	right_body: Dictionary,
	options: Dictionary,
	seen: Dictionary,
	pairs: Array[Dictionary],
	max_pairs: int
) -> bool:
	if not _bodies_can_pair(left_body, right_body, options):
		return false

	var include_touching: bool = GFVariantData.get_option_bool(options, "include_touching", false)
	if not _rects_overlap(_get_body_bounds(left_body), _get_body_bounds(right_body), include_touching):
		return false

	var pair_key: String = _make_pair_key(left_body, right_body)
	if seen.has(pair_key):
		return false

	seen[pair_key] = true
	pairs.append(_make_pair(left_body, right_body))
	return max_pairs > 0 and pairs.size() >= max_pairs


static func _collect_quadtree_pairs(
	node_bodies: Array[Dictionary],
	node_bounds: Rect2,
	depth: int,
	max_depth: int,
	capacity: int,
	options: Dictionary,
	seen: Dictionary,
	pairs: Array[Dictionary],
	max_pairs: int
) -> bool:
	if node_bodies.size() <= capacity or depth >= max_depth or node_bounds.size.x <= 0.0001 or node_bounds.size.y <= 0.0001:
		return _append_subset_pairs(node_bodies, options, seen, pairs, max_pairs)

	var half_size: Vector2 = node_bounds.size * 0.5
	var position: Vector2 = node_bounds.position
	var children: Array[Rect2] = [
		Rect2(position, half_size),
		Rect2(Vector2(position.x + half_size.x, position.y), half_size),
		Rect2(Vector2(position.x, position.y + half_size.y), half_size),
		Rect2(position + half_size, half_size),
	]
	var child_bodies: Array[Array] = [[], [], [], []]
	for body: Dictionary in node_bodies:
		var bounds: Rect2 = _get_body_bounds(body)
		var assigned_to_child: bool = false
		for child_index: int in range(children.size()):
			if _rects_overlap(bounds, children[child_index], true):
				child_bodies[child_index].append(body)
				assigned_to_child = true
		if not assigned_to_child:
			return _append_subset_pairs(node_bodies, options, seen, pairs, max_pairs)

	var split_made_progress: bool = false
	for child_index: int in range(child_bodies.size()):
		var child_list: Array = child_bodies[child_index]
		if child_list.is_empty():
			continue
		if child_list.size() < node_bodies.size():
			split_made_progress = true
		var typed_child_list: Array[Dictionary] = []
		for child_body: Variant in child_list:
			if child_body is Dictionary:
				typed_child_list.append(GFVariantData.as_dictionary(child_body))
		if _collect_quadtree_pairs(
			typed_child_list,
			children[child_index],
			depth + 1,
			max_depth,
			capacity,
			options,
			seen,
			pairs,
			max_pairs
		):
			return true

	if not split_made_progress:
		return _append_subset_pairs(node_bodies, options, seen, pairs, max_pairs)
	return max_pairs > 0 and pairs.size() >= max_pairs


static func _append_subset_pairs(
	node_bodies: Array[Dictionary],
	options: Dictionary,
	seen: Dictionary,
	pairs: Array[Dictionary],
	max_pairs: int
) -> bool:
	for left_index: int in range(node_bodies.size()):
		for right_index: int in range(left_index + 1, node_bodies.size()):
			if _append_pair_if_overlapping(node_bodies[left_index], node_bodies[right_index], options, seen, pairs, max_pairs):
				return true
	return false


static func _bodies_can_pair(left_body: Dictionary, right_body: Dictionary, options: Dictionary) -> bool:
	if not GFVariantData.get_option_bool(options, "use_collision_masks", true):
		return true

	var left_layer: int = GFVariantData.get_option_int(left_body, "collision_layer", DEFAULT_COLLISION_LAYER)
	var left_mask: int = GFVariantData.get_option_int(left_body, "collision_mask", DEFAULT_COLLISION_MASK)
	var right_layer: int = GFVariantData.get_option_int(right_body, "collision_layer", DEFAULT_COLLISION_LAYER)
	var right_mask: int = GFVariantData.get_option_int(right_body, "collision_mask", DEFAULT_COLLISION_MASK)
	return (left_layer & right_mask) != 0 and (right_layer & left_mask) != 0


static func _make_pair(left_body: Dictionary, right_body: Dictionary) -> Dictionary:
	var ordered: Array[Dictionary] = _ordered_pair(left_body, right_body)
	var first: Dictionary = ordered[0]
	var second: Dictionary = ordered[1]
	return {
		"a": GFVariantData.get_option_value(first, "entity"),
		"b": GFVariantData.get_option_value(second, "entity"),
		"a_index": GFVariantData.get_option_int(first, "index"),
		"b_index": GFVariantData.get_option_int(second, "index"),
		"a_bounds": _get_body_bounds(first),
		"b_bounds": _get_body_bounds(second),
	}


static func _make_pair_key(left_body: Dictionary, right_body: Dictionary) -> String:
	var first_index: int = GFVariantData.get_option_int(left_body, "index")
	var second_index: int = GFVariantData.get_option_int(right_body, "index")
	if first_index > second_index:
		var swap: int = first_index
		first_index = second_index
		second_index = swap
	return "%d:%d" % [first_index, second_index]


static func _ordered_pair(left_body: Dictionary, right_body: Dictionary) -> Array[Dictionary]:
	if GFVariantData.get_option_int(left_body, "index") <= GFVariantData.get_option_int(right_body, "index"):
		return [left_body, right_body]
	return [right_body, left_body]


static func _choose_algorithm(bodies: Array, options: Dictionary) -> StringName:
	var requested: StringName = GFVariantData.get_option_string_name(options, "algorithm", ALGORITHM_AUTO)
	if requested == ALGORITHM_BRUTE_FORCE or requested == ALGORITHM_SAP or requested == ALGORITHM_QUADTREE:
		return requested

	var body_count: int = _normalize_bodies(bodies, options).size()
	if body_count <= GFVariantData.get_option_int(options, "bruteforce_threshold", _DEFAULT_BRUTE_FORCE_THRESHOLD):
		return ALGORITHM_BRUTE_FORCE
	if body_count >= GFVariantData.get_option_int(options, "quadtree_threshold", _DEFAULT_QUADTREE_THRESHOLD):
		return ALGORITHM_QUADTREE
	return ALGORITHM_SAP


static func _sort_bodies_by_x(bodies: Array[Dictionary]) -> void:
	bodies.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_bounds: Rect2 = _get_body_bounds(left)
		var right_bounds: Rect2 = _get_body_bounds(right)
		if left_bounds.position.x != right_bounds.position.x:
			return left_bounds.position.x < right_bounds.position.x
		if _rect_max_x(left_bounds) != _rect_max_x(right_bounds):
			return _rect_max_x(left_bounds) < _rect_max_x(right_bounds)
		return GFVariantData.get_option_int(left, "index") < GFVariantData.get_option_int(right, "index")
	)


static func _get_world_bounds(bodies: Array[Dictionary], options: Dictionary) -> Rect2:
	var world_value: Variant = GFVariantData.get_option_value(options, "world_bounds")
	if world_value is Rect2:
		var world_bounds: Rect2 = world_value
		return _normalize_rect(world_bounds)

	var result: Rect2 = _get_body_bounds(bodies[0])
	for index: int in range(1, bodies.size()):
		result = _rect_union(result, _get_body_bounds(bodies[index]))
	return result


static func _rect_union(left: Rect2, right: Rect2) -> Rect2:
	var min_x: float = minf(left.position.x, right.position.x)
	var min_y: float = minf(left.position.y, right.position.y)
	var max_x: float = maxf(_rect_max_x(left), _rect_max_x(right))
	var max_y: float = maxf(_rect_max_y(left), _rect_max_y(right))
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


static func _normalize_rect(rect: Rect2) -> Rect2:
	var position: Vector2 = rect.position
	var size: Vector2 = rect.size
	if size.x < 0.0:
		position.x += size.x
		size.x = -size.x
	if size.y < 0.0:
		position.y += size.y
		size.y = -size.y
	return Rect2(position, size)


static func _rects_overlap(left: Rect2, right: Rect2, include_touching: bool) -> bool:
	if include_touching:
		return (
			left.position.x <= _rect_max_x(right)
			and _rect_max_x(left) >= right.position.x
			and left.position.y <= _rect_max_y(right)
			and _rect_max_y(left) >= right.position.y
		)

	return (
		left.position.x < _rect_max_x(right)
		and _rect_max_x(left) > right.position.x
		and left.position.y < _rect_max_y(right)
		and _rect_max_y(left) > right.position.y
	)


static func _sap_can_break(left_max_x: float, right_min_x: float, include_touching: bool) -> bool:
	return right_min_x > left_max_x if include_touching else right_min_x >= left_max_x


static func _get_body_bounds(body: Dictionary) -> Rect2:
	var bounds_value: Variant = GFVariantData.get_option_value(body, "bounds", Rect2())
	if bounds_value is Rect2:
		var bounds: Rect2 = bounds_value
		return bounds
	return Rect2()


static func _rect_max_x(rect: Rect2) -> float:
	return rect.position.x + rect.size.x


static func _rect_max_y(rect: Rect2) -> float:
	return rect.position.y + rect.size.y


static func _get_max_pairs(options: Dictionary) -> int:
	return maxi(GFVariantData.get_option_int(options, "max_pairs", 0), 0)
