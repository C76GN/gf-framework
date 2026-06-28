## GFGravityProbe3D: 通用 3D 重力采样器。
##
## 从场景树分组中采样 GFGravityField3D 或任何暴露 get_acceleration_at()
## 方法的对象，并按组合策略计算当前位置处的加速度、上下方向。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFGravityProbe3D
extends Node3D


# --- 枚举 ---

## 多个力场重叠时的采样组合策略。
## [br]
## @api public
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
@export var field_group: StringName = &"gf_gravity_field_3d"

## 多个力场重叠时的组合策略。
## [br]
## @api public
@export var combination_mode: CombinationMode = CombinationMode.SUM

## 找不到力场时是否返回 fallback_acceleration。
## [br]
## @api public
@export var use_fallback_when_empty: bool = true

## 找不到力场时使用的默认加速度。
## [br]
## @api public
@export var fallback_acceleration: Vector3 = Vector3.DOWN * 9.8

## 同一帧、同一位置重复 sample() 时是否复用上次结果。
## [br]
## @api public
@export var cache_samples_per_frame: bool = true


# --- 公共变量 ---

## 最近一次 sample() 得到的加速度。
## [br]
## @api public
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
## @return 按 combination_mode 组合后的加速度。
func sample() -> Vector3:
	if _can_use_cached_sample():
		last_acceleration = _cached_acceleration
		return last_acceleration

	if get_tree() == null or field_group == &"":
		last_acceleration = Vector3.ZERO
		if use_fallback_when_empty:
			last_acceleration = fallback_acceleration
		_store_sample_cache()
		return last_acceleration

	var fields: Array[Node] = get_tree().get_nodes_in_group(String(field_group))
	last_acceleration = sample_fields(fields)
	_store_sample_cache()
	return last_acceleration


## 采样指定力场列表。
## [br]
## @api public
## [br]
## @param fields: 力场对象列表。
## [br]
## @schema fields: Array，包含 GFGravityField3D 或任何暴露 get_acceleration_at(Vector3) 的 Object。
## [br]
## @return 按 combination_mode 组合后的加速度。
func sample_fields(fields: Array) -> Vector3:
	var samples: Array[Dictionary] = _collect_field_samples(fields)
	if samples.is_empty() and use_fallback_when_empty:
		return fallback_acceleration

	match combination_mode:
		CombinationMode.STRONGEST:
			return _sample_strongest_field(samples)
		CombinationMode.HIGHEST_PRIORITY:
			return _sample_highest_priority_fields(samples)
		_:
			return _sample_sum_fields(samples)


## 获取当前位置的向下方向。
## [br]
## @api public
## [br]
## @return 向下方向。
func get_down_direction() -> Vector3:
	var acceleration: Vector3 = sample()
	if acceleration.is_zero_approx():
		return Vector3.DOWN
	return acceleration.normalized()


## 获取当前位置的向上方向。
## [br]
## @api public
## [br]
## @return 向上方向。
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
	for field_value: Variant in fields:
		if field_value == null or not is_instance_valid(field_value) or not (field_value is Object):
			continue
		var field: Object = field_value
		if not field.has_method("get_acceleration_at"):
			continue
		var value: Variant = field.call("get_acceleration_at", global_position)
		if value is Vector3:
			var acceleration_value: Vector3 = value
			samples.append({
				"acceleration": acceleration_value,
				"priority": _get_field_priority(field),
			})
	return samples


func _sample_sum_fields(samples: Array[Dictionary]) -> Vector3:
	var acceleration_sum: Vector3 = Vector3.ZERO
	for sample_record: Dictionary in samples:
		acceleration_sum += _get_sample_acceleration(sample_record)
	return acceleration_sum


func _sample_strongest_field(samples: Array[Dictionary]) -> Vector3:
	var best_acceleration: Vector3 = Vector3.ZERO
	var best_length_squared: float = -1.0
	for sample_record: Dictionary in samples:
		var acceleration_value: Vector3 = _get_sample_acceleration(sample_record)
		var length_squared: float = acceleration_value.length_squared()
		if length_squared > best_length_squared:
			best_length_squared = length_squared
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


func _can_use_cached_sample() -> bool:
	return (
		cache_samples_per_frame
		and _cached_process_frame == Engine.get_process_frames()
		and _cached_physics_frame == Engine.get_physics_frames()
		and _cached_field_group == field_group
		and _cached_combination_mode == combination_mode
		and _cached_use_fallback_when_empty == use_fallback_when_empty
		and _cached_fallback_acceleration == fallback_acceleration
		and _cached_position == global_position
		and _cached_field_signature == _get_field_group_signature()
	)


func _store_sample_cache() -> void:
	_cached_process_frame = Engine.get_process_frames()
	_cached_physics_frame = Engine.get_physics_frames()
	_cached_field_group = field_group
	_cached_combination_mode = combination_mode
	_cached_use_fallback_when_empty = use_fallback_when_empty
	_cached_fallback_acceleration = fallback_acceleration
	_cached_position = global_position
	_cached_field_signature = _get_field_group_signature()
	_cached_acceleration = last_acceleration


func _get_field_group_signature() -> String:
	if get_tree() == null or field_group == &"":
		return ""
	var ids: PackedStringArray = PackedStringArray()
	for node: Node in get_tree().get_nodes_in_group(String(field_group)):
		var _append_result: bool = ids.append(str(node.get_instance_id()))
	ids.sort()
	return "|".join(ids)
