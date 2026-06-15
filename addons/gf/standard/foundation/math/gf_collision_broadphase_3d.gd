## GFCollisionBroadphase3D: 纯 3D AABB broadphase 候选对生成工具。
##
## 使用 `AABB` body 记录生成可能相交的候选对，提供暴力枚举、Sweep and Prune
## 和自动组合入口。它只做 AABB 粗筛，不执行 SAT、GJK、接触点计算、
## 物理响应、命中分发或玩法规则判断。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 5.0.0
class_name GFCollisionBroadphase3D
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


# --- 公共方法 ---

## 创建 3D broadphase body 记录。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param entity: 调用方实体标识。
## [br]
## @schema entity: Variant entity identity copied into generated pair reports.
## [br]
## @param bounds: 轴对齐包围盒；负尺寸会被归一化。
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
## @schema return: Dictionary with `entity`, `bounds: AABB`, `collision_layer: int`, `collision_mask: int`, `enabled: bool`, and `metadata: Dictionary`.
static func make_body(
	entity: Variant,
	bounds: AABB,
	collision_layer: int = DEFAULT_COLLISION_LAYER,
	collision_mask: int = DEFAULT_COLLISION_MASK,
	enabled: bool = true,
	metadata: Dictionary = {}
) -> Dictionary:
	return {
		"entity": entity,
		"bounds": _normalize_aabb(bounds),
		"collision_layer": collision_layer,
		"collision_mask": collision_mask,
		"enabled": enabled,
		"metadata": metadata.duplicate(true),
	}


## 使用暴力枚举生成 3D AABB 候选对。
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


## 使用 Sweep and Prune 生成 3D AABB 候选对。
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
		var left_max_x: float = _aabb_max_x(_get_body_bounds(left_body))
		for right_index: int in range(left_index + 1, normalized_bodies.size()):
			var right_body: Dictionary = normalized_bodies[right_index]
			var right_min_x: float = _get_body_bounds(right_body).position.x
			if _sap_can_break(left_max_x, right_min_x, include_touching):
				break
			if _append_pair_if_overlapping(left_body, right_body, options, seen, pairs, max_pairs):
				return pairs
	return pairs


## 按选定或自动算法生成 3D AABB 候选对。
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
## @schema options: Dictionary with optional `algorithm: StringName` plus bruteforce or SAP options.
## [br]
## @schema return: Array[Dictionary] pair records with `a`, `b`, `a_index`, `b_index`, `a_bounds`, and `b_bounds`.
static func find_pairs_combined(bodies: Array, options: Dictionary = {}) -> Array[Dictionary]:
	var algorithm: StringName = _choose_algorithm(bodies, options)
	match algorithm:
		ALGORITHM_BRUTE_FORCE:
			return find_pairs_bruteforce(bodies, options)
		_:
			return find_pairs_sap(bodies, options)


## 生成包含算法、输入数量和候选对的 3D broadphase 报告。
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
## @schema options: Dictionary with optional `algorithm: StringName` plus bruteforce or SAP options.
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
	if not (bounds_value is AABB):
		return {}

	var metadata_value: Variant = GFVariantData.get_option_value(source, "metadata", {})
	var metadata: Dictionary = GFVariantData.as_dictionary(metadata_value, {})
	var entity: Variant = GFVariantData.get_option_value(source, "entity", index)
	var bounds: AABB = bounds_value
	return {
		"entity": entity,
		"bounds": _normalize_aabb(bounds),
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
	if not _aabbs_overlap(_get_body_bounds(left_body), _get_body_bounds(right_body), include_touching):
		return false

	var pair_key: String = _make_pair_key(left_body, right_body)
	if seen.has(pair_key):
		return false

	seen[pair_key] = true
	pairs.append(_make_pair(left_body, right_body))
	return max_pairs > 0 and pairs.size() >= max_pairs


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
	if requested == ALGORITHM_BRUTE_FORCE or requested == ALGORITHM_SAP:
		return requested

	var body_count: int = _normalize_bodies(bodies, options).size()
	if body_count <= GFVariantData.get_option_int(options, "bruteforce_threshold", _DEFAULT_BRUTE_FORCE_THRESHOLD):
		return ALGORITHM_BRUTE_FORCE
	return ALGORITHM_SAP


static func _sort_bodies_by_x(bodies: Array[Dictionary]) -> void:
	bodies.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_bounds: AABB = _get_body_bounds(left)
		var right_bounds: AABB = _get_body_bounds(right)
		if left_bounds.position.x != right_bounds.position.x:
			return left_bounds.position.x < right_bounds.position.x
		if _aabb_max_x(left_bounds) != _aabb_max_x(right_bounds):
			return _aabb_max_x(left_bounds) < _aabb_max_x(right_bounds)
		return GFVariantData.get_option_int(left, "index") < GFVariantData.get_option_int(right, "index")
	)


static func _normalize_aabb(bounds: AABB) -> AABB:
	var position: Vector3 = bounds.position
	var size: Vector3 = bounds.size
	if size.x < 0.0:
		position.x += size.x
		size.x = -size.x
	if size.y < 0.0:
		position.y += size.y
		size.y = -size.y
	if size.z < 0.0:
		position.z += size.z
		size.z = -size.z
	return AABB(position, size)


static func _aabbs_overlap(left: AABB, right: AABB, include_touching: bool) -> bool:
	if include_touching:
		return (
			left.position.x <= _aabb_max_x(right)
			and _aabb_max_x(left) >= right.position.x
			and left.position.y <= _aabb_max_y(right)
			and _aabb_max_y(left) >= right.position.y
			and left.position.z <= _aabb_max_z(right)
			and _aabb_max_z(left) >= right.position.z
		)

	return (
		left.position.x < _aabb_max_x(right)
		and _aabb_max_x(left) > right.position.x
		and left.position.y < _aabb_max_y(right)
		and _aabb_max_y(left) > right.position.y
		and left.position.z < _aabb_max_z(right)
		and _aabb_max_z(left) > right.position.z
	)


static func _sap_can_break(left_max_x: float, right_min_x: float, include_touching: bool) -> bool:
	return right_min_x > left_max_x if include_touching else right_min_x >= left_max_x


static func _get_body_bounds(body: Dictionary) -> AABB:
	var bounds_value: Variant = GFVariantData.get_option_value(body, "bounds", AABB())
	if bounds_value is AABB:
		var bounds: AABB = bounds_value
		return bounds
	return AABB()


static func _aabb_max_x(bounds: AABB) -> float:
	return bounds.position.x + bounds.size.x


static func _aabb_max_y(bounds: AABB) -> float:
	return bounds.position.y + bounds.size.y


static func _aabb_max_z(bounds: AABB) -> float:
	return bounds.position.z + bounds.size.z


static func _get_max_pairs(options: Dictionary) -> int:
	return maxi(GFVariantData.get_option_int(options, "max_pairs", 0), 0)
