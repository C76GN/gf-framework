## GFArchitectureSnapshotCoordinator: GFArchitecture 的 Model 与全局快照内部协调器。
##
## 负责 Model 快照收集/恢复、分帧等待和命令历史聚合，让
## GFArchitecture 保持公共门面职责。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since 4.4.0
## [br]
## @layer kernel/core
class_name GFArchitectureSnapshotCoordinator
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 私有变量 ---

var _models: Dictionary = {}
var _command_history_store_resolver: Callable = Callable()
var _default_models_per_frame: int = 8


# --- 框架内部方法 ---

## 绑定 Model 注册表和命令历史解析入口。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @param model_registry: 当前架构的 Model 注册表实例字典。
## [br]
## @schema model_registry: Dictionary keyed by Script, storing GFModel instances.
## [br]
## @param command_history_store_resolver: 返回命令历史 Utility 的 Callable。
## [br]
## @param default_models_per_frame: 分帧快照默认每帧处理的 Model 数量。
## [br]
## @return: 当前快照协调器实例。
func configure(
	model_registry: Dictionary,
	command_history_store_resolver: Callable,
	default_models_per_frame: int
) -> GFArchitectureSnapshotCoordinator:
	_models = model_registry
	_command_history_store_resolver = command_history_store_resolver
	_default_models_per_frame = maxi(default_models_per_frame, 0)
	return self


## 收集所有已注册 Model 的状态快照。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @return: Model 状态字典。
## [br]
## @schema return: Dictionary keyed by stable model save key, storing each Model.to_dict() result.
func get_all_models_state() -> Dictionary:
	var entry_report: Dictionary = _collect_model_snapshot_entries()
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(entry_report, "ok", false):
		return {}

	var state: Dictionary = {}
	var entries: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(entry_report, "entries")
	for entry_variant: Variant in entries:
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(entry_variant)
		var model: GFModel = _get_model_from_snapshot_entry(entry)
		if model == null:
			continue
		var class_name_key: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "key")
		state[class_name_key] = _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(model.to_dict(), true)
	return state


## 分帧收集所有已注册 Model 的状态快照。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @param options: 可选参数，支持 max_models_per_frame；小于等于 0 时不主动让出帧。
## [br]
## @schema options: Dictionary，可包含 max_models_per_frame: int。
## [br]
## @return: Model 状态字典。
## [br]
## @schema return: Dictionary keyed by stable model save key, storing each Model.to_dict() result.
func get_all_models_state_async(options: Dictionary = {}) -> Dictionary:
	var entry_report: Dictionary = _collect_model_snapshot_entries()
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(entry_report, "ok", false):
		return {}

	var state: Dictionary = {}
	var max_models_per_frame: int = _get_snapshot_models_per_frame(options)
	var processed_since_yield: int = 0
	var entries: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(entry_report, "entries")
	for entry_variant: Variant in entries:
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(entry_variant)
		var model: GFModel = _get_model_from_snapshot_entry(entry)
		if model == null:
			continue
		var class_name_key: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "key")
		state[class_name_key] = _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(model.to_dict(), true)
		processed_since_yield += 1
		var yielded: bool = await _wait_snapshot_frame_if_needed(processed_since_yield, max_models_per_frame)
		if yielded:
			processed_since_yield = 0
	return state


## 从状态字典恢复所有已注册 Model 的数据。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @param data: Model 状态字典。
## [br]
## @schema data: Dictionary keyed by stable model save key, storing serialized model data.
func restore_all_models_state(data: Dictionary) -> void:
	var entry_report: Dictionary = _collect_model_snapshot_entries()
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(entry_report, "ok", false):
		return

	var entries: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(entry_report, "entries")
	for entry_variant: Variant in entries:
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(entry_variant)
		var model: GFModel = _get_model_from_snapshot_entry(entry)
		if model == null:
			continue
		var class_name_key: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "key")
		if data.has(class_name_key) and data[class_name_key] is Dictionary:
			model.from_dict(_GF_VARIANT_ACCESS_SCRIPT.as_dictionary(data[class_name_key]))
		elif data.has(class_name_key):
			push_warning("[GFArchitecture] restore_all_models_state：Model 数据必须是 Dictionary，已跳过：%s。" % class_name_key)


## 分帧恢复所有已注册 Model 的数据。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @param data: Model 状态字典。
## [br]
## @schema data: Dictionary keyed by stable model save key, storing serialized model data.
## [br]
## @param options: 可选参数，支持 max_models_per_frame；小于等于 0 时不主动让出帧。
## [br]
## @schema options: Dictionary，可包含 max_models_per_frame: int。
func restore_all_models_state_async(data: Dictionary, options: Dictionary = {}) -> void:
	var entry_report: Dictionary = _collect_model_snapshot_entries()
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(entry_report, "ok", false):
		return

	var max_models_per_frame: int = _get_snapshot_models_per_frame(options)
	var processed_since_yield: int = 0
	var entries: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(entry_report, "entries")
	for entry_variant: Variant in entries:
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(entry_variant)
		var model: GFModel = _get_model_from_snapshot_entry(entry)
		if model == null:
			continue
		var class_name_key: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "key")
		if data.has(class_name_key) and data[class_name_key] is Dictionary:
			model.from_dict(_GF_VARIANT_ACCESS_SCRIPT.as_dictionary(data[class_name_key]))
		elif data.has(class_name_key):
			push_warning("[GFArchitecture] restore_all_models_state_async：Model 数据必须是 Dictionary，已跳过：%s。" % class_name_key)
		processed_since_yield += 1
		var yielded: bool = await _wait_snapshot_frame_if_needed(processed_since_yield, max_models_per_frame)
		if yielded:
			processed_since_yield = 0


## 获取包含 Model 状态和可选命令历史的全局快照。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @return: 全局快照字典。
## [br]
## @schema return: Dictionary with models and optional command_history fields.
func get_global_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["models"] = get_all_models_state()
	var history_util: Object = _get_command_history_store()
	if history_util != null:
		snapshot["command_history"] = _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(history_util.call("serialize_full_history"), true)
	return snapshot


## 分帧获取包含 Model 状态和可选命令历史的全局快照。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @param options: 可选参数，支持 max_models_per_frame；小于等于 0 时不主动让出帧。
## [br]
## @schema options: Dictionary，可包含 max_models_per_frame: int。
## [br]
## @return: 全局快照字典。
## [br]
## @schema return: Dictionary with models and optional command_history fields.
func get_global_snapshot_async(options: Dictionary = {}) -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot["models"] = await get_all_models_state_async(options)
	var history_util: Object = _get_command_history_store()
	if history_util != null:
		snapshot["command_history"] = _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(history_util.call("serialize_full_history"), true)
	return snapshot


## 从全局快照中恢复 Model 状态和可选命令历史。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @param data: 全局快照字典。
## [br]
## @schema data: Dictionary produced by get_global_snapshot().
## [br]
## @param command_builder: 用于反序列化具体 Command 实例的 Callable。
func restore_global_snapshot(data: Dictionary, command_builder: Callable = Callable()) -> void:
	if data.has("models"):
		var models_data: Variant = data["models"]
		if typeof(models_data) == TYPE_DICTIONARY:
			restore_all_models_state(_GF_VARIANT_ACCESS_SCRIPT.as_dictionary(models_data))
		else:
			push_warning("[GFArchitecture] restore_global_snapshot：models 必须是 Dictionary，已跳过 Model 恢复。")

	if data.has("command_history"):
		var history_util: Object = _get_command_history_store()
		if history_util != null:
			if command_builder.is_valid():
				var history_data: Variant = data["command_history"]
				if typeof(history_data) == TYPE_DICTIONARY and history_util.has_method("deserialize_full_history"):
					history_util.call("deserialize_full_history", history_data, command_builder)
				elif typeof(history_data) == TYPE_ARRAY and history_util.has_method("deserialize_history"):
					history_util.call("deserialize_history", history_data, command_builder)
			else:
				push_warning("[GFArchitecture] restore_global_snapshot：快照包含命令历史数据，但未提供有效的 command_builder，跳过历史恢复。")


## 分帧恢复全局快照中的 Model 状态和可选命令历史。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @param data: 全局快照字典。
## [br]
## @schema data: Dictionary produced by get_global_snapshot_async().
## [br]
## @param command_builder: 用于反序列化具体 Command 实例的 Callable。
## [br]
## @param options: 可选参数，支持 max_models_per_frame；小于等于 0 时不主动让出帧。
## [br]
## @schema options: Dictionary，可包含 max_models_per_frame: int。
func restore_global_snapshot_async(
	data: Dictionary,
	command_builder: Callable = Callable(),
	options: Dictionary = {}
) -> void:
	if data.has("models"):
		var models_data: Variant = data["models"]
		if typeof(models_data) == TYPE_DICTIONARY:
			await restore_all_models_state_async(_GF_VARIANT_ACCESS_SCRIPT.as_dictionary(models_data), options)
		else:
			push_warning("[GFArchitecture] restore_global_snapshot_async：models 必须是 Dictionary，已跳过 Model 恢复。")

	if data.has("command_history"):
		var history_util: Object = _get_command_history_store()
		if history_util != null:
			if command_builder.is_valid():
				var history_data: Variant = data["command_history"]
				if typeof(history_data) == TYPE_DICTIONARY and history_util.has_method("deserialize_full_history"):
					history_util.call("deserialize_full_history", history_data, command_builder)
				elif typeof(history_data) == TYPE_ARRAY and history_util.has_method("deserialize_history"):
					history_util.call("deserialize_history", history_data, command_builder)
			else:
				push_warning("[GFArchitecture] restore_global_snapshot_async：快照包含命令历史数据，但未提供有效的 command_builder，跳过历史恢复。")


# --- 私有/辅助方法 ---

func _get_snapshot_models_per_frame(options: Dictionary) -> int:
	return maxi(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_models_per_frame", _default_models_per_frame),
		0
	)


func _wait_snapshot_frame_if_needed(processed_count: int, max_models_per_frame: int) -> bool:
	if max_models_per_frame <= 0 or processed_count < max_models_per_frame:
		return false
	var scene_tree: SceneTree = _get_scene_tree_or_null()
	if scene_tree == null:
		return false
	await scene_tree.process_frame
	return true


func _get_scene_tree_or_null() -> SceneTree:
	var main_loop: Variant = Engine.get_main_loop()
	if main_loop is SceneTree:
		var scene_tree: SceneTree = main_loop
		return scene_tree
	return null


func _get_command_history_store() -> Object:
	if not _command_history_store_resolver.is_valid():
		return null
	var result: Variant = _command_history_store_resolver.call()
	if result is Object:
		var history_store: Object = result
		return history_store
	return null


func _collect_model_snapshot_entries() -> Dictionary:
	var entries: Array[Dictionary] = []
	var used_keys: Dictionary = {}
	var duplicate_keys: PackedStringArray = PackedStringArray()
	for script_cls: Script in _models:
		var model_object: Object = _get_dictionary_object(_models, script_cls)
		if not model_object is GFModel:
			continue
		var model: GFModel = model_object
		var class_name_key: String = _get_model_key(script_cls, model)
		if class_name_key.is_empty():
			continue
		if used_keys.has(class_name_key):
			if not duplicate_keys.has(class_name_key):
				var _duplicate_appended: bool = duplicate_keys.append(class_name_key)
			continue
		used_keys[class_name_key] = true
		entries.append({
			"key": class_name_key,
			"script": script_cls,
			"model": model,
		})

	if not duplicate_keys.is_empty():
		push_error("[GFArchitecture] Model 快照键重复：%s。请为每个 Model 提供唯一 get_save_key()。" % ", ".join(duplicate_keys))
		return {
			"ok": false,
			"entries": [],
		}

	return {
		"ok": true,
		"entries": entries,
	}


func _get_model_from_snapshot_entry(entry: Dictionary) -> GFModel:
	var model_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(entry, "model")
	var script_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(entry, "script")
	if not (model_value is GFModel) or not (script_value is Script):
		return null
	var script_cls: Script = script_value
	var model: GFModel = model_value
	if not is_instance_valid(model):
		return null
	var current_model: Object = _get_dictionary_object(_models, script_cls)
	if current_model != model:
		return null
	return model


func _get_dictionary_object(source: Dictionary, field_name: Variant) -> Object:
	var value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(source, field_name)
	if value is Object:
		var object_value: Object = value
		return object_value
	return null


func _get_model_key(script_cls: Script, model: GFModel = null) -> String:
	if model != null:
		var save_key: String = String(model.get_save_key())
		if not save_key.is_empty():
			return save_key

	var global_name: StringName = script_cls.get_global_name()
	if global_name != &"":
		return String(global_name)
	if not script_cls.resource_path.is_empty():
		return script_cls.resource_path
	push_error("[GFArchitecture] 可序列化 Model 缺少稳定标识：请为脚本声明 class_name 或提供可用的资源路径。")
	return ""
