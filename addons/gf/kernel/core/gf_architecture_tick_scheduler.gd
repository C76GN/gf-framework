## GFArchitectureTickScheduler: GFArchitecture 的 tick/physics_tick 内部调度器。
##
## 持有 tick 缓存记录、模块参与判断、排序和时间策略调用，避免
## GFArchitecture 同时承担注册表门面与每帧调度细节。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since 4.4.0
## [br]
## @layer kernel/core
class_name GFArchitectureTickScheduler
extends RefCounted


# --- 常量 ---

const _GF_ARCHITECTURE_TICK_RECORD_SCRIPT = preload("res://addons/gf/kernel/core/gf_architecture_tick_record.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 私有变量 ---

var _systems: Dictionary = {}
var _utilities: Dictionary = {}
var _module_lifecycle_stages: Dictionary = {}
var _tick_systems: Array[GFArchitectureTickRecord] = []
var _physics_systems: Array[GFArchitectureTickRecord] = []
var _tick_utilities: Array[GFArchitectureTickRecord] = []
var _physics_utilities: Array[GFArchitectureTickRecord] = []
var _tick_records: Array[GFArchitectureTickRecord] = []
var _physics_records: Array[GFArchitectureTickRecord] = []
var _is_iterating_tick_caches: bool = false
var _tick_caches_dirty: bool = false


# --- 框架内部方法 ---

## 绑定架构注册表引用并立即构建 tick 缓存。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @param system_registry: 当前架构的 System 注册表实例字典。
## [br]
## @schema system_registry: Dictionary keyed by Script, storing GFSystem instances.
## [br]
## @param utility_registry: 当前架构的 Utility 注册表实例字典。
## [br]
## @schema utility_registry: Dictionary keyed by Script, storing GFUtility instances.
## [br]
## @param lifecycle_stages: 当前架构的模块生命周期阶段字典。
## [br]
## @schema lifecycle_stages: Dictionary keyed by module Object, storing integer lifecycle stage values.
## [br]
## @return: 当前调度器实例。
func configure(
	system_registry: Dictionary,
	utility_registry: Dictionary,
	lifecycle_stages: Dictionary
) -> GFArchitectureTickScheduler:
	_systems = system_registry
	_utilities = utility_registry
	_module_lifecycle_stages = lifecycle_stages
	refresh()
	return self


## 请求刷新 tick 缓存。
## 如果当前正在迭代缓存，则延迟到本轮 tick 结束后重建。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
func refresh() -> void:
	if _is_iterating_tick_caches:
		_tick_caches_dirty = true
		return

	_rebuild_tick_caches()


## 驱动所有参与 tick 的 System 与 Utility。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @param delta: Godot 原始帧 delta。
## [br]
## @param time_provider: 当前架构解析到的时间提供器；为空时使用原始 delta。
func drive_tick(delta: float, time_provider: Object) -> void:
	var scaled_delta: float = _get_scaled_delta(delta, time_provider)
	var time_paused: bool = _is_time_paused(time_provider)
	_drive_records(_tick_records, delta, scaled_delta, time_paused)


## 驱动所有参与 physics_tick 的 System 与 Utility。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @param delta: Godot 原始物理帧 delta。
## [br]
## @param time_provider: 当前架构解析到的时间提供器；为空时使用原始 delta。
func drive_physics_tick(delta: float, time_provider: Object) -> void:
	if time_provider != null and _GF_VARIANT_ACCESS_SCRIPT.to_bool(time_provider.call("should_substep_physics", delta)):
		var raw_scaled_steps: Variant = time_provider.call("get_physics_scaled_delta_steps", delta)
		if not raw_scaled_steps is Array:
			return
		var scaled_steps: Array = raw_scaled_steps
		if scaled_steps.is_empty():
			return
		var raw_step: float = delta / float(scaled_steps.size())
		for scaled_step_variant: Variant in scaled_steps:
			_drive_physics_tick_step(raw_step, _GF_VARIANT_ACCESS_SCRIPT.to_float(scaled_step_variant), time_provider)
		return

	var scaled_delta: float = _get_scaled_delta(delta, time_provider)
	_drive_physics_tick_step(delta, scaled_delta, time_provider)


## 获取 tick 缓存诊断计数。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @return: tick 与 physics_tick 缓存数量。
## [br]
## @schema return: Dictionary with systems, physics_systems, utilities, and physics_utilities counts.
func get_debug_state() -> Dictionary:
	return {
		"systems": _tick_systems.size(),
		"physics_systems": _physics_systems.size(),
		"utilities": _tick_utilities.size(),
		"physics_utilities": _physics_utilities.size(),
	}


## 获取单个模块的 tick 相关诊断字段。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @param instance: 要诊断的模块实例。
## [br]
## @return: 模块 tick 开关、优先级和时间策略。
## [br]
## @schema return: Dictionary containing has_tick, has_physics_tick, ignore_pause, ignore_time_scale, tick_enabled, physics_tick_enabled, tick_priority, and physics_tick_priority.
func get_module_debug_fields(instance: Object) -> Dictionary:
	return {
		"has_tick": _module_participates_in_tick(instance, &"tick", &"tick_enabled"),
		"has_physics_tick": _module_participates_in_tick(instance, &"physics_tick", &"physics_tick_enabled"),
		"ignore_pause": _module_ignores_pause(instance),
		"ignore_time_scale": _module_ignores_time_scale(instance),
		"tick_enabled": _get_module_bool(instance, &"tick_enabled"),
		"physics_tick_enabled": _get_module_bool(instance, &"physics_tick_enabled"),
		"tick_priority": _get_module_priority(instance, &"tick_priority"),
		"physics_tick_priority": _get_module_priority(instance, &"physics_tick_priority"),
	}


# --- 私有/辅助方法 ---

func _drive_physics_tick_step(raw_delta: float, scaled_delta: float, time_provider: Object) -> void:
	var time_paused: bool = _is_time_paused(time_provider)
	_drive_records(_physics_records, raw_delta, scaled_delta, time_paused)


func _drive_records(
	records: Array[GFArchitectureTickRecord],
	raw_delta: float,
	scaled_delta: float,
	time_paused: bool
) -> void:
	_is_iterating_tick_caches = true
	for record: GFArchitectureTickRecord in records:
		if _is_tick_record_ready_for_tick(record):
			record.invoke(raw_delta, scaled_delta, time_paused)
	_is_iterating_tick_caches = false
	_flush_tick_cache_refresh()


func _get_scaled_delta(delta: float, time_provider: Object) -> float:
	if time_provider == null:
		return delta
	return _GF_VARIANT_ACCESS_SCRIPT.to_float(time_provider.call("get_scaled_delta", delta), delta)


func _is_time_paused(time_provider: Object) -> bool:
	if time_provider == null:
		return false
	return _GF_VARIANT_ACCESS_SCRIPT.to_bool(time_provider.call("is_time_paused"))


func _rebuild_tick_caches() -> void:
	_tick_systems.clear()
	_physics_systems.clear()
	_tick_utilities.clear()
	_physics_utilities.clear()
	_tick_records.clear()
	_physics_records.clear()
	_tick_caches_dirty = false

	var tick_order: int = 0
	var physics_order: int = 0
	for system: Object in _systems.values():
		var system_tick_record: GFArchitectureTickRecord = _make_tick_record(
			system,
			&"tick",
			&"tick_enabled",
			&"tick_priority",
			tick_order
		)
		if system_tick_record != null:
			_tick_systems.append(system_tick_record)
			_tick_records.append(system_tick_record)
			tick_order += 1
		var system_physics_record: GFArchitectureTickRecord = _make_tick_record(
			system,
			&"physics_tick",
			&"physics_tick_enabled",
			&"physics_tick_priority",
			physics_order
		)
		if system_physics_record != null:
			_physics_systems.append(system_physics_record)
			_physics_records.append(system_physics_record)
			physics_order += 1

	for utility: Object in _utilities.values():
		var utility_tick_record: GFArchitectureTickRecord = _make_tick_record(
			utility,
			&"tick",
			&"tick_enabled",
			&"tick_priority",
			tick_order
		)
		if utility_tick_record != null:
			_tick_utilities.append(utility_tick_record)
			_tick_records.append(utility_tick_record)
			tick_order += 1
		var utility_physics_record: GFArchitectureTickRecord = _make_tick_record(
			utility,
			&"physics_tick",
			&"physics_tick_enabled",
			&"physics_tick_priority",
			physics_order
		)
		if utility_physics_record != null:
			_physics_utilities.append(utility_physics_record)
			_physics_records.append(utility_physics_record)
			physics_order += 1

	_sort_tick_records_for_tick(_tick_records)
	_sort_tick_records_for_tick(_physics_records)
	_sort_tick_records_for_tick(_tick_systems)
	_sort_tick_records_for_tick(_physics_systems)
	_sort_tick_records_for_tick(_tick_utilities)
	_sort_tick_records_for_tick(_physics_utilities)


func _flush_tick_cache_refresh() -> void:
	if _tick_caches_dirty:
		_rebuild_tick_caches()


func _sort_tick_records_for_tick(records: Array[GFArchitectureTickRecord]) -> void:
	records.sort_custom(func(left: GFArchitectureTickRecord, right: GFArchitectureTickRecord) -> bool:
		if left.priority == right.priority:
			return left.order < right.order
		return left.priority > right.priority
	)


func _is_tick_record_ready_for_tick(record: GFArchitectureTickRecord) -> bool:
	if record == null or not record.is_valid_record():
		return false
	return _is_module_ready_for_tick(record.module)


func _is_module_ready_for_tick(instance: Object) -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_module_lifecycle_stages, instance, 0) >= 3


func _make_tick_record(
	instance: Object,
	method_name: StringName,
	explicit_property: StringName,
	priority_property: StringName,
	order: int
) -> GFArchitectureTickRecord:
	if not _module_participates_in_tick(instance, method_name, explicit_property):
		return null
	var callback: Callable = Callable(instance, method_name)
	if not callback.is_valid():
		return null
	var record: GFArchitectureTickRecord = _GF_ARCHITECTURE_TICK_RECORD_SCRIPT.new()
	return record.configure(
		instance,
		callback,
		_get_module_priority(instance, priority_property),
		order,
		_module_ignores_pause(instance),
		_module_ignores_time_scale(instance)
	)


func _module_participates_in_tick(instance: Object, method_name: StringName, explicit_property: StringName) -> bool:
	if instance == null:
		return false
	if not (instance is GFSystem or instance is GFUtility):
		return false
	if not instance.has_method(method_name):
		return false
	if _get_module_bool(instance, explicit_property):
		return true
	if _script_chain_declares_method_before_framework_base(instance, method_name):
		return true
	return false


func _get_module_bool(instance: Object, property_name: StringName) -> bool:
	if instance == null:
		return false
	if instance is GFSystem:
		var system: GFSystem = instance
		match property_name:
			&"tick_enabled":
				return system.tick_enabled
			&"physics_tick_enabled":
				return system.physics_tick_enabled
	if instance is GFUtility:
		var utility: GFUtility = instance
		match property_name:
			&"tick_enabled":
				return utility.tick_enabled
			&"physics_tick_enabled":
				return utility.physics_tick_enabled
	return false


func _get_module_priority(instance: Object, property_name: StringName) -> int:
	if instance is GFSystem:
		var system: GFSystem = instance
		match property_name:
			&"tick_priority":
				return system.tick_priority
			&"physics_tick_priority":
				return system.physics_tick_priority
	if instance is GFUtility:
		var utility: GFUtility = instance
		match property_name:
			&"tick_priority":
				return utility.tick_priority
			&"physics_tick_priority":
				return utility.physics_tick_priority
	return 0


func _module_ignores_pause(instance: Object) -> bool:
	if instance is GFSystem:
		var system: GFSystem = instance
		return system.ignore_pause
	if instance is GFUtility:
		var utility: GFUtility = instance
		return utility.ignore_pause
	return false


func _module_ignores_time_scale(instance: Object) -> bool:
	if instance is GFSystem:
		var system: GFSystem = instance
		return system.ignore_time_scale
	if instance is GFUtility:
		var utility: GFUtility = instance
		return utility.ignore_time_scale
	return false


func _script_chain_declares_method_before_framework_base(instance: Object, method_name: StringName) -> bool:
	var script: Script = _get_instance_script(instance)
	var framework_method_count: int = _get_framework_module_method_count(instance, method_name)
	while script != null:
		if _is_framework_module_base_script(script):
			return false
		if _count_script_methods(script, method_name) > framework_method_count:
			return true
		script = script.get_base_script()
	return false


func _is_framework_module_base_script(script: Script) -> bool:
	return script == GFSystem or script == GFUtility


func _get_framework_module_method_count(instance: Object, method_name: StringName) -> int:
	if instance is GFSystem:
		return _count_script_methods(GFSystem, method_name)
	if instance is GFUtility:
		return _count_script_methods(GFUtility, method_name)
	return 0


func _count_script_methods(script: Script, method_name: StringName) -> int:
	var count: int = 0
	for method: Dictionary in script.get_script_method_list():
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(method, "name", "") == String(method_name):
			count += 1
	return count


func _get_instance_script(instance: Object) -> Script:
	if instance == null:
		return null
	var raw_script: Variant = instance.get_script()
	if raw_script is Script:
		var script: Script = raw_script
		return script
	return null
