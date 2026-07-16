## GFGravityProbe3D: 通用 3D 重力采样器。
##
## 从场景树分组中采样 GFGravityField3D 或任何暴露 get_acceleration_at()
## 方法的对象，并按组合策略计算当前位置处的加速度、上下方向。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFGravityProbe3D
extends Node3D


# --- 枚举 ---

## 多个力场重叠时的采样组合策略。
## [br]
## @api public
## [br]
## @since 3.17.0
enum CombinationMode {
	## 汇总所有有效力场的加速度。
	SUM,
	## 只使用当前点加速度长度最大的力场。
	STRONGEST,
	## 只汇总当前点非零加速度中最高优先级的力场。
	HIGHEST_PRIORITY,
}


# --- 导出变量 ---

## 要采样的力场分组。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var field_group: StringName = &"gf_gravity_field_3d"

## 多个力场重叠时的组合策略。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var combination_mode: CombinationMode = CombinationMode.SUM

## 找不到力场时是否返回 fallback_acceleration。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var use_fallback_when_empty: bool = true

## 找不到力场时使用的默认加速度。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var fallback_acceleration: Vector3 = Vector3.DOWN * 9.8

## 同一帧、同一位置重复 sample() 时是否复用上次结果。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var cache_samples_per_frame: bool = true


# --- 公共变量 ---

## 最近一次 sample() 得到的加速度。
## [br]
## @api public
## [br]
## @since 3.17.0
var last_acceleration: Vector3 = Vector3.ZERO


# --- 私有变量 ---

var _cached_process_frame: int = -1
var _cached_physics_frame: int = -1
var _cached_position: Vector3 = Vector3.ZERO
var _cached_field_group: StringName = &""
var _cached_combination_mode: CombinationMode = CombinationMode.SUM
var _cached_use_fallback_when_empty: bool = true
var _cached_fallback_acceleration: Vector3 = Vector3.DOWN * 9.8
var _cached_field_signature: String = ""
var _cached_acceleration: Vector3 = Vector3.ZERO


# --- 公共方法 ---

## 采样场景树分组中的所有力场。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 按 combination_mode 组合后的加速度。
func sample() -> Vector3:
	var fields: Array[Node] = _get_fields_from_group()
	var field_signature: String = _get_field_group_signature(fields)
	if _can_use_cached_sample(field_signature):
		last_acceleration = _cached_acceleration
		return last_acceleration

	last_acceleration = sample_fields(fields)
	_store_sample_cache(field_signature)
	return last_acceleration


## 采样指定力场列表。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param fields: 力场对象列表。
## [br]
## @schema fields: Array，包含 GFGravityField3D 或任何暴露 get_acceleration_at(Vector3) 的 Object。
## [br]
## @return: 按 combination_mode 组合后的加速度。
func sample_fields(fields: Array) -> Vector3:
	var samples: Array[Dictionary] = _collect_field_samples(fields)
	if samples.is_empty() and use_fallback_when_empty:
		return _get_finite_fallback_acceleration()

	match combination_mode:
		CombinationMode.STRONGEST:
			return _sample_strongest_field(samples)
		CombinationMode.HIGHEST_PRIORITY:
			return _sample_highest_priority_fields(samples)
		_:
			return _sample_sum_fields(samples)


## 从候选 provider 采样力场。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param candidate_provider: 暴露 get_candidate_objects(options) 的候选 provider。
## [br]
## @param options: 候选查询选项；未设置 method_name 时默认筛选 get_acceleration_at。
## [br]
## @schema options: Dictionary passed to candidate_provider.get_candidate_objects(); method_name defaults to get_acceleration_at.
## [br]
## @return: 按 combination_mode 组合后的加速度。
func sample_field_provider(candidate_provider: Object, options: Dictionary = {}) -> Vector3:
	last_acceleration = sample_fields(_get_field_provider_objects(candidate_provider, options))
	return last_acceleration


## 获取当前位置的向下方向。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 向下方向。
func get_down_direction() -> Vector3:
	var acceleration: Vector3 = sample()
	if acceleration.is_zero_approx():
		return Vector3.DOWN
	return acceleration.normalized()


## 获取当前位置的向上方向。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 向上方向。
func get_up_direction() -> Vector3:
	return -get_down_direction()


## 清空当前帧采样缓存。
## [br]
## @api public
## [br]
## @since 7.0.0
func invalidate_cache() -> void:
	_cached_process_frame = -1
	_cached_physics_frame = -1
	_cached_field_signature = ""


# --- 私有/辅助方法 ---

func _collect_field_samples(fields: Array) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	var field_snapshot: Array = fields.duplicate()
	for field_value: Variant in field_snapshot:
		var field: Object = _variant_to_valid_object(field_value)
		if field == null or not _is_field_in_probe_scope(field) or not _can_call_get_acceleration_at(field):
			continue
		var value: Variant = field.call("get_acceleration_at", global_position)
		if not is_instance_valid(field):
			continue
		if value is Vector3:
			var acceleration_value: Vector3 = value
			if not _is_finite_vector3(acceleration_value):
				continue
			samples.append({
				"acceleration": acceleration_value,
				"priority": _get_field_priority(field),
				"order_key": _get_field_order_key(field),
			})
	return samples


func _get_field_provider_objects(candidate_provider: Object, options: Dictionary) -> Array[Object]:
	var objects: Array[Object] = []
	if not is_instance_valid(candidate_provider) or not candidate_provider.has_method("get_candidate_objects"):
		return objects

	var query_options: Dictionary = options.duplicate()
	if not query_options.has("method_name"):
		query_options["method_name"] = &"get_acceleration_at"
	var value: Variant = candidate_provider.call("get_candidate_objects", query_options)
	if not (value is Array):
		return objects

	for candidate_value: Variant in GFVariantData.as_array(value):
		var candidate: Object = _variant_to_valid_object(candidate_value)
		if candidate == null:
			continue
		if not _can_call_get_acceleration_at(candidate):
			continue
		objects.append(candidate)
	return objects


func _sample_sum_fields(samples: Array[Dictionary]) -> Vector3:
	var acceleration_sum: Vector3 = Vector3.ZERO
	for sample_record: Dictionary in samples:
		acceleration_sum += _get_sample_acceleration(sample_record)
	return acceleration_sum


func _sample_strongest_field(samples: Array[Dictionary]) -> Vector3:
	var best_acceleration: Vector3 = Vector3.ZERO
	var best_length_squared: float = -1.0
	var best_order_key: String = ""
	for sample_record: Dictionary in samples:
		var acceleration_value: Vector3 = _get_sample_acceleration(sample_record)
		var length_squared: float = acceleration_value.length_squared()
		var order_key: String = GFVariantData.get_option_string(sample_record, "order_key")
		if (
			length_squared > best_length_squared
			or (is_equal_approx(length_squared, best_length_squared) and (best_order_key.is_empty() or order_key < best_order_key))
		):
			best_length_squared = length_squared
			best_order_key = order_key
			best_acceleration = acceleration_value
	return best_acceleration


func _sample_highest_priority_fields(samples: Array[Dictionary]) -> Vector3:
	var best_priority: int = -2147483648
	var has_active_sample: bool = false
	for sample_record: Dictionary in samples:
		var acceleration_value: Vector3 = _get_sample_acceleration(sample_record)
		if acceleration_value.is_zero_approx():
			continue
		best_priority = maxi(best_priority, _get_sample_priority(sample_record))
		has_active_sample = true

	if not has_active_sample:
		return Vector3.ZERO

	var acceleration_sum: Vector3 = Vector3.ZERO
	for sample_record: Dictionary in samples:
		var acceleration_value: Vector3 = _get_sample_acceleration(sample_record)
		if acceleration_value.is_zero_approx():
			continue
		if _get_sample_priority(sample_record) == best_priority:
			acceleration_sum += acceleration_value
	return acceleration_sum


func _get_field_priority(field: Object) -> int:
	if field.has_method("get_gravity_priority"):
		var priority_value: Variant = field.call("get_gravity_priority")
		if priority_value is int:
			return priority_value
		if priority_value is float:
			var float_priority: float = priority_value
			if is_nan(float_priority) or is_inf(float_priority):
				return 0
			return int(float_priority)
	return 0


func _get_sample_acceleration(sample_record: Dictionary) -> Vector3:
	var value: Variant = sample_record.get("acceleration", Vector3.ZERO)
	if value is Vector3:
		var acceleration_value: Vector3 = value
		return acceleration_value
	return Vector3.ZERO


func _get_sample_priority(sample_record: Dictionary) -> int:
	var value: Variant = sample_record.get("priority", 0)
	if value is int:
		return value
	if value is float:
		var float_priority: float = value
		return int(float_priority)
	return 0


func _can_use_cached_sample(field_signature: String) -> bool:
	return (
		cache_samples_per_frame
		and _cached_process_frame == Engine.get_process_frames()
		and _cached_physics_frame == Engine.get_physics_frames()
		and _cached_field_group == field_group
		and _cached_combination_mode == combination_mode
		and _cached_use_fallback_when_empty == use_fallback_when_empty
		and _cached_fallback_acceleration == fallback_acceleration
		and _cached_position == global_position
		and _cached_field_signature == field_signature
	)


func _store_sample_cache(field_signature: String) -> void:
	_cached_process_frame = Engine.get_process_frames()
	_cached_physics_frame = Engine.get_physics_frames()
	_cached_field_group = field_group
	_cached_combination_mode = combination_mode
	_cached_use_fallback_when_empty = use_fallback_when_empty
	_cached_fallback_acceleration = fallback_acceleration
	_cached_position = global_position
	_cached_field_signature = field_signature
	_cached_acceleration = last_acceleration


func _get_field_group_signature(fields: Array[Node]) -> String:
	if fields.is_empty():
		return ""
	var ids: PackedStringArray = PackedStringArray()
	for node: Node in fields:
		var _append_result: bool = ids.append(_get_field_signature(node))
	ids.sort()
	return "|".join(ids)


func _get_fields_from_group() -> Array[Node]:
	var result: Array[Node] = []
	if get_tree() == null or field_group == &"":
		return result
	for node: Node in get_tree().get_nodes_in_group(String(field_group)):
		if _is_field_in_probe_scope(node) and _can_call_get_acceleration_at(node):
			result.append(node)
	return result


func _variant_to_valid_object(value: Variant) -> Object:
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	var object_value: Object = value
	return object_value


func _is_field_in_probe_scope(field: Object) -> bool:
	if field is Node3D:
		var field_node: Node3D = field
		if is_inside_tree() and field_node.is_inside_tree() and field_node.get_world_3d() != get_world_3d():
			return false
	return true


func _can_call_get_acceleration_at(field: Object) -> bool:
	if not is_instance_valid(field) or not field.has_method("get_acceleration_at"):
		return false
	for method_info: Dictionary in field.get_method_list():
		if StringName(GFVariantData.get_option_string(method_info, "name")) != &"get_acceleration_at":
			continue
		return _method_accepts_argument_count(method_info, 1)
	return false


func _method_accepts_argument_count(method_info: Dictionary, argument_count: int) -> bool:
	var arguments: Array = GFVariantData.get_option_array(method_info, "args")
	var default_arguments: Array = GFVariantData.get_option_array(method_info, "default_args")
	var required_count: int = maxi(arguments.size() - default_arguments.size(), 0)
	var method_flags: int = GFVariantData.get_option_int(method_info, "flags", 0)
	var accepts_varargs: bool = (method_flags & METHOD_FLAG_VARARG) != 0
	return required_count <= argument_count and (argument_count <= arguments.size() or accepts_varargs)


func _get_field_order_key(field: Object) -> String:
	if field is Node:
		var node: Node = field
		if node.is_inside_tree():
			return String(node.get_path())
	return "%020d" % field.get_instance_id()


func _get_field_signature(field: Node) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var _id_appended: bool = parts.append(_get_field_order_key(field))
	if field is Node3D:
		var node_3d: Node3D = field
		var _position_appended: bool = parts.append(str(node_3d.global_position))
	if field is GFGravityField3D:
		var gravity_field: GFGravityField3D = field
		var _state_appended: bool = parts.append("%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s" % [
			str(gravity_field.enabled),
			str(gravity_field.priority),
			str(gravity_field.acceleration),
			str(gravity_field.radius),
			str(gravity_field.min_distance),
			str(gravity_field.direction_mode),
			str(gravity_field.constant_direction),
			str(gravity_field.falloff_mode),
			str(gravity_field.falloff_curve.get_instance_id() if gravity_field.falloff_curve != null else 0),
			str(gravity_field.is_inside_tree()),
			str(gravity_field.get_gravity_revision_for_probe()),
		])
	return ":".join(parts)


func _get_finite_fallback_acceleration() -> Vector3:
	return fallback_acceleration if _is_finite_vector3(fallback_acceleration) else Vector3.ZERO


func _is_finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x)
		and not is_inf(value.x)
		and not is_nan(value.y)
		and not is_inf(value.y)
		and not is_nan(value.z)
		and not is_inf(value.z)
	)
