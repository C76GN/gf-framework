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
const _SNAPSHOT_FORMAT_VERSION: int = 1
const _SNAPSHOT_BUSY_ERROR: String = (
	"已有快照事务正在执行；不允许并发或重入 capture/restore。"
)


# --- 私有变量 ---

var _models: Dictionary = {}
var _command_history_store_resolver: Callable = Callable()
var _default_models_per_frame: int = 8
var _snapshot_transaction_generation: int = 0
var _active_snapshot_transaction_generation: int = 0


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
## @return: 显式捕获 Result；成功时包含 snapshot，失败时不包含 snapshot；
## snapshot 事务忙时额外包含 phase=&"busy"。
## [br]
## @schema return: Dictionary with ok: bool, optional snapshot: Dictionary keyed by stable model save key, error: String, and optional phase: StringName for busy transaction failures.
func get_all_models_state() -> Dictionary:
	var snapshot_generation: int = _begin_snapshot_transaction()
	if snapshot_generation == 0:
		return _make_capture_busy_failure()
	var capture_result: Dictionary = _capture_all_models_state()
	return _finish_capture_transaction(snapshot_generation, capture_result)


func _capture_all_models_state() -> Dictionary:
	var frozen_capture: Dictionary = _freeze_model_capture()
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(frozen_capture, "ok", false):
		return _make_capture_failure(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				frozen_capture,
				"error",
				"Model 快照捕获失败。"
			)
		)
	var stability_result: Dictionary = _verify_frozen_model_capture_stability(
		frozen_capture
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(stability_result, "ok", false):
		return stability_result
	return _make_capture_success(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			frozen_capture,
			"snapshot"
		)
	)


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
## 所有 Model.to_dict() 的初始冻结与反序稳定性复核都会在首次让帧前完成；
## max_models_per_frame 只控制冻结数据的分帧物化。
## 若注册表身份或稳定键在等待期间变化，捕获会显式失败。
## [br]
## @return: 显式捕获 Result；成功时包含 snapshot，失败时不包含 snapshot；
## snapshot 事务忙时额外包含 phase=&"busy"。
## [br]
## @schema return: Dictionary with ok: bool, optional snapshot: Dictionary keyed by stable model save key, error: String, and optional phase: StringName for busy transaction failures.
func get_all_models_state_async(options: Dictionary = {}) -> Dictionary:
	var snapshot_generation: int = _begin_snapshot_transaction()
	if snapshot_generation == 0:
		return _make_capture_busy_failure()
	var capture_result: Dictionary = await _capture_all_models_state_async(options)
	return _finish_capture_transaction(snapshot_generation, capture_result)


func _capture_all_models_state_async(options: Dictionary) -> Dictionary:
	var frozen_capture: Dictionary = _freeze_model_capture()
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(frozen_capture, "ok", false):
		return _make_capture_failure(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				frozen_capture,
				"error",
				"Model 快照捕获失败。"
			)
		)
	var stability_result: Dictionary = _verify_frozen_model_capture_stability(
		frozen_capture
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(stability_result, "ok", false):
		return stability_result
	return await _materialize_frozen_model_capture(frozen_capture, options)


## 从状态字典恢复所有已注册 Model 的数据。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @param data: 捕获成功 Result 中的 Model snapshot 字典，不含 Result 外壳。
## [br]
## @schema data: Dictionary keyed by stable model save key, storing serialized model data.
## [br]
## @return 原子恢复 Result。
## [br]
## @schema return: Dictionary with ok: bool, phase: StringName, rolled_back: bool, and error: String.
func restore_all_models_state(data: Dictionary) -> Dictionary:
	var restore_generation: int = _begin_snapshot_transaction()
	if restore_generation == 0:
		return _make_restore_busy_failure()
	var plan_result: Dictionary = _build_model_restore_plan(data)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(plan_result, "ok", false):
		return _finish_restore_transaction(restore_generation, plan_result)
	var restore_result: Dictionary = _apply_model_restore_plan(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_array(plan_result, "entries")
	)
	return _finish_restore_transaction(restore_generation, restore_result)


## 分帧恢复所有已注册 Model 的数据。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @param data: 捕获成功 Result 中的 Model snapshot 字典，不含 Result 外壳。
## [br]
## @schema data: Dictionary keyed by stable model save key, storing serialized model data.
## [br]
## @param options: 可选参数，支持 max_models_per_frame；小于等于 0 时不主动让出帧。
## [br]
## @schema options: Dictionary，可包含 max_models_per_frame: int。
## [br]
## @return 原子恢复 Result。
## [br]
## @schema return: Dictionary with ok: bool, phase: StringName, rolled_back: bool, and error: String.
func restore_all_models_state_async(
	data: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var restore_generation: int = _begin_snapshot_transaction()
	if restore_generation == 0:
		return _make_restore_busy_failure()
	var plan_result: Dictionary = _build_model_restore_plan(data)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(plan_result, "ok", false):
		return _finish_restore_transaction(restore_generation, plan_result)
	var restore_result: Dictionary = await _apply_model_restore_plan_async(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_array(plan_result, "entries"),
		options
	)
	return _finish_restore_transaction(restore_generation, restore_result)


## 获取包含 Model 状态和可选命令历史的全局快照。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @return: 显式捕获 Result；成功时包含 snapshot，失败时不包含 snapshot；
## snapshot 事务忙时额外包含 phase=&"busy"。
## [br]
## @schema return: Dictionary with ok: bool, optional snapshot: Dictionary with format_version, models, and optional command_history fields, error: String, and optional phase: StringName for busy transaction failures.
func get_global_snapshot() -> Dictionary:
	var snapshot_generation: int = _begin_snapshot_transaction()
	if snapshot_generation == 0:
		return _make_capture_busy_failure()
	var capture_result: Dictionary = _capture_global_snapshot()
	return _finish_capture_transaction(snapshot_generation, capture_result)


func _capture_global_snapshot() -> Dictionary:
	var frozen_models: Dictionary = _freeze_model_capture()
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(frozen_models, "ok", false):
		return _make_capture_failure(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				frozen_models,
				"error",
				"Model 快照捕获失败。"
			)
		)

	var frozen_history: Dictionary = {}
	var has_history: bool = false
	var history_util: Object = _get_command_history_store()
	if history_util != null:
		var history_result: Dictionary = _capture_history_state(history_util)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(history_result, "ok", false):
			return _make_capture_failure(
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					history_result,
					"error",
					"命令历史快照捕获失败。"
				)
			)
		frozen_history = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			history_result,
			"snapshot"
		)
		has_history = true

	var stability_result: Dictionary = _verify_global_capture_stability(
		frozen_models,
		history_util,
		frozen_history,
		has_history
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(stability_result, "ok", false):
		return stability_result

	var snapshot: Dictionary = {
		"format_version": _SNAPSHOT_FORMAT_VERSION,
		"models": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			frozen_models,
			"snapshot"
		),
	}
	if has_history:
		snapshot["command_history"] = frozen_history
	return _make_capture_success(snapshot)


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
## Model 与命令历史的初始冻结及反序稳定性复核会在首次让帧前完成；
## max_models_per_frame 只控制冻结 Model 数据的分帧物化。
## 若注册表身份或稳定键在等待期间变化，捕获会显式失败。
## [br]
## @return: 显式捕获 Result；成功时包含 snapshot，失败时不包含 snapshot；
## snapshot 事务忙时额外包含 phase=&"busy"。
## [br]
## @schema return: Dictionary with ok: bool, optional snapshot: Dictionary with format_version, models, and optional command_history fields, error: String, and optional phase: StringName for busy transaction failures.
func get_global_snapshot_async(options: Dictionary = {}) -> Dictionary:
	var snapshot_generation: int = _begin_snapshot_transaction()
	if snapshot_generation == 0:
		return _make_capture_busy_failure()
	var capture_result: Dictionary = await _capture_global_snapshot_async(options)
	return _finish_capture_transaction(snapshot_generation, capture_result)


func _capture_global_snapshot_async(options: Dictionary) -> Dictionary:
	var frozen_models: Dictionary = _freeze_model_capture()
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(frozen_models, "ok", false):
		return _make_capture_failure(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				frozen_models,
				"error",
				"Model 快照捕获失败。"
			)
		)

	var frozen_history: Dictionary = {}
	var has_history: bool = false
	var history_util: Object = _get_command_history_store()
	if history_util != null:
		var history_result: Dictionary = _capture_history_state(history_util)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(history_result, "ok", false):
			return _make_capture_failure(
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					history_result,
					"error",
					"命令历史快照捕获失败。"
				)
			)
		frozen_history = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			history_result,
			"snapshot"
		)
		has_history = true

	var stability_result: Dictionary = _verify_global_capture_stability(
		frozen_models,
		history_util,
		frozen_history,
		has_history
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(stability_result, "ok", false):
		return stability_result

	var models_result: Dictionary = await _materialize_frozen_model_capture(
		frozen_models,
		options
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(models_result, "ok", false):
		return models_result
	if has_history and not _is_command_history_store_current(history_util):
		return _make_capture_failure(
			"命令历史存储目标在全局快照分帧等待期间发生变化。"
		)
	var snapshot: Dictionary = {
		"format_version": _SNAPSHOT_FORMAT_VERSION,
		"models": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			models_result,
			"snapshot"
		),
	}
	if has_history:
		snapshot["command_history"] = frozen_history
	return _make_capture_success(snapshot)


## 从全局快照中恢复 Model 状态和可选命令历史。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @param data: 捕获成功 Result 中的全局 snapshot 字典，不含 Result 外壳。
## [br]
## @schema data: Inner Dictionary with current format_version, models, and optional command_history fields.
## [br]
## @param command_builder: 用于反序列化具体 Command 实例的 Callable。
## [br]
## @return 原子恢复 Result。
## [br]
## @schema return: Dictionary with ok: bool, phase: StringName, rolled_back: bool, and error: String.
func restore_global_snapshot(
	data: Dictionary,
	command_builder: Callable = Callable()
) -> Dictionary:
	var restore_generation: int = _begin_snapshot_transaction()
	if restore_generation == 0:
		return _make_restore_busy_failure()
	var validation_result: Dictionary = _validate_global_snapshot(data, command_builder)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(validation_result, "ok", false):
		return _finish_restore_transaction(
			restore_generation,
			validation_result
		)

	var models_data: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
		data,
		"models"
	)
	var plan_result: Dictionary = _build_model_restore_plan(models_data)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(plan_result, "ok", false):
		return _finish_restore_transaction(restore_generation, plan_result)
	var model_entries: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(
		plan_result,
		"entries"
	)

	var history_util: Object = null
	var history_before: Dictionary = {}
	var history_target: Dictionary = {}
	if data.has("command_history"):
		history_util = _get_dictionary_object(
			validation_result,
			"history_store"
		)
		if history_util == null:
			return _finish_restore_transaction(
				restore_generation,
				_make_restore_failure(
					&"validate",
					"命令历史存储目标在验证后失效。"
				)
			)
		var history_baseline_result: Dictionary = _capture_history_state(history_util)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			history_baseline_result,
			"ok",
			false
		):
			return _finish_restore_transaction(
				restore_generation,
				_make_restore_failure(
					&"validate",
					_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
						history_baseline_result,
						"error",
						"无法读取命令历史恢复基线。"
					)
				)
			)
		history_before = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			history_baseline_result,
			"snapshot"
		)
		history_target = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			data,
			"command_history"
		).duplicate(true)

	var models_result: Dictionary = _apply_model_restore_plan(model_entries)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(models_result, "ok", false):
		return _finish_restore_transaction(restore_generation, models_result)

	if history_util != null:
		if not _is_command_history_store_current(history_util):
			var _models_rollback_succeeded: bool = (
				_rollback_model_restore_entries(model_entries)
			)
			return _finish_restore_transaction(
				restore_generation,
				_make_restore_failure(
					&"commit",
					"命令历史存储目标在提交前发生变化。",
					false
				)
			)
		var history_apply_result: Dictionary = _apply_and_verify_history_state(
			history_util,
			history_target,
			command_builder
		)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			history_apply_result,
			"ok",
			false
		):
			var global_rolled_back: bool = _rollback_global_restore(
				history_util,
				history_before,
				command_builder,
				model_entries,
				_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
					history_apply_result,
					"target_current",
					false
				)
			)
			return _finish_restore_transaction(
				restore_generation,
				_make_restore_failure(
					&"commit",
					"命令历史应用后状态与目标快照不一致。",
					global_rolled_back
				)
			)
		if not _model_restore_entries_match_state(
			model_entries,
			"target"
		):
			var global_rolled_back: bool = _rollback_global_restore(
				history_util,
				history_before,
				command_builder,
				model_entries,
				true
			)
			return _finish_restore_transaction(
				restore_generation,
				_make_restore_failure(
					&"commit",
					"命令历史提交后 Model 聚合状态与目标快照不一致。",
					global_rolled_back
				)
			)
	return _finish_restore_transaction(
		restore_generation,
		_make_restore_success()
	)


## 分帧恢复全局快照中的 Model 状态和可选命令历史。
## [br]
## @api framework_internal
## [br]
## @since 4.4.0
## [br]
## @param data: 捕获成功 Result 中的全局 snapshot 字典，不含 Result 外壳。
## [br]
## @schema data: Inner Dictionary with current format_version, models, and optional command_history fields.
## [br]
## @param command_builder: 用于反序列化具体 Command 实例的 Callable。
## [br]
## @param options: 可选参数，支持 max_models_per_frame；小于等于 0 时不主动让出帧。
## [br]
## @schema options: Dictionary，可包含 max_models_per_frame: int。
## [br]
## @return 原子恢复 Result。
## [br]
## @schema return: Dictionary with ok: bool, phase: StringName, rolled_back: bool, and error: String.
func restore_global_snapshot_async(
	data: Dictionary,
	command_builder: Callable = Callable(),
	options: Dictionary = {}
) -> Dictionary:
	var restore_generation: int = _begin_snapshot_transaction()
	if restore_generation == 0:
		return _make_restore_busy_failure()
	var validation_result: Dictionary = _validate_global_snapshot(
		data,
		command_builder
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(validation_result, "ok", false):
		return _finish_restore_transaction(
			restore_generation,
			validation_result
		)

	var models_data: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
		data,
		"models"
	)
	var plan_result: Dictionary = _build_model_restore_plan(models_data)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(plan_result, "ok", false):
		return _finish_restore_transaction(restore_generation, plan_result)
	var model_entries: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(
		plan_result,
		"entries"
	)

	var history_util: Object = null
	var history_before: Dictionary = {}
	var history_target: Dictionary = {}
	if data.has("command_history"):
		history_util = _get_dictionary_object(
			validation_result,
			"history_store"
		)
		if history_util == null:
			return _finish_restore_transaction(
				restore_generation,
				_make_restore_failure(
					&"validate",
					"命令历史存储目标在验证后失效。"
				)
			)
		var history_baseline_result: Dictionary = _capture_history_state(
			history_util
		)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			history_baseline_result,
			"ok",
			false
		):
			return _finish_restore_transaction(
				restore_generation,
				_make_restore_failure(
					&"validate",
					_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
						history_baseline_result,
						"error",
						"无法读取命令历史恢复基线。"
					)
				)
			)
		history_before = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			history_baseline_result,
			"snapshot"
		)
		history_target = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			data,
			"command_history"
		).duplicate(true)

	var models_result: Dictionary = await _apply_model_restore_plan_async(
		model_entries,
		options
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(models_result, "ok", false):
		return _finish_restore_transaction(restore_generation, models_result)

	if history_util != null:
		if not _is_command_history_store_current(history_util):
			var _models_rollback_succeeded: bool = (
				_rollback_model_restore_entries(model_entries)
			)
			return _finish_restore_transaction(
				restore_generation,
				_make_restore_failure(
					&"commit",
					"命令历史存储目标在异步提交前发生变化。",
					false
				)
			)
		var history_apply_result: Dictionary = _apply_and_verify_history_state(
			history_util,
			history_target,
			command_builder
		)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			history_apply_result,
			"ok",
			false
		):
			var global_rolled_back: bool = _rollback_global_restore(
				history_util,
				history_before,
				command_builder,
				model_entries,
				_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
					history_apply_result,
					"target_current",
					false
				)
			)
			return _finish_restore_transaction(
				restore_generation,
				_make_restore_failure(
					&"commit",
					"命令历史应用后状态与目标快照不一致。",
					global_rolled_back
				)
			)
		if not _model_restore_entries_match_state(
			model_entries,
			"target"
		):
			var global_rolled_back: bool = _rollback_global_restore(
				history_util,
				history_before,
				command_builder,
				model_entries,
				true
			)
			return _finish_restore_transaction(
				restore_generation,
				_make_restore_failure(
					&"commit",
					"命令历史提交后 Model 聚合状态与目标快照不一致。",
					global_rolled_back
				)
			)
	return _finish_restore_transaction(
		restore_generation,
		_make_restore_success()
	)


# --- 私有/辅助方法 ---

func _make_capture_success(snapshot: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"snapshot": snapshot,
		"error": "",
	}


func _make_capture_failure(
	error: String,
	phase: StringName = &""
) -> Dictionary:
	var failure_error: String = error
	if failure_error.is_empty():
		failure_error = "快照捕获失败。"
	var result: Dictionary = {
		"ok": false,
		"error": failure_error,
	}
	if phase != &"":
		result["phase"] = phase
	return result


func _make_restore_success() -> Dictionary:
	return {
		"ok": true,
		"phase": &"commit",
		"rolled_back": false,
		"error": "",
	}


func _make_restore_failure(
	phase: StringName,
	error: String,
	rolled_back: bool = false
) -> Dictionary:
	var failure_error: String = error
	if failure_error.is_empty():
		failure_error = "快照恢复失败。"
	return {
		"ok": false,
		"phase": phase,
		"rolled_back": rolled_back,
		"error": failure_error,
	}


func _make_restore_busy_failure() -> Dictionary:
	return _make_restore_failure(&"busy", _SNAPSHOT_BUSY_ERROR)


func _make_capture_busy_failure() -> Dictionary:
	return _make_capture_failure(_SNAPSHOT_BUSY_ERROR, &"busy")


func _begin_snapshot_transaction() -> int:
	if _active_snapshot_transaction_generation != 0:
		return 0
	_snapshot_transaction_generation += 1
	_active_snapshot_transaction_generation = _snapshot_transaction_generation
	return _active_snapshot_transaction_generation


func _finish_capture_transaction(
	snapshot_generation: int,
	result: Dictionary
) -> Dictionary:
	if (
		snapshot_generation <= 0
		or _active_snapshot_transaction_generation != snapshot_generation
	):
		return _make_capture_failure(
			"快照捕获事务 generation 在完成前失效。",
			&"commit"
		)
	_active_snapshot_transaction_generation = 0
	return result


func _finish_restore_transaction(
	restore_generation: int,
	result: Dictionary
) -> Dictionary:
	if (
		restore_generation <= 0
		or _active_snapshot_transaction_generation != restore_generation
	):
		return _make_restore_failure(
			&"commit",
			"快照恢复事务 generation 在完成前失效。"
		)
	_active_snapshot_transaction_generation = 0
	return result


func _freeze_model_capture() -> Dictionary:
	var entry_report: Dictionary = _collect_model_snapshot_entries()
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(entry_report, "ok", false):
		return _make_capture_failure(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				entry_report,
				"error",
				"Model 快照目标收集失败。"
			)
		)

	var entries: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(
		entry_report,
		"entries"
	)
	var frozen_state: Dictionary = {}
	for entry_variant: Variant in entries:
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(
			entry_variant
		)
		var model: GFModel = _get_model_from_snapshot_entry(entry)
		if model == null:
			return _make_capture_failure("Model 快照目标在冻结期间失效。")
		var class_name_key: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"key"
		)
		var model_state: Variant = _GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(
			model.to_dict()
		)
		if not model_state is Dictionary:
			return _make_capture_failure(
				"Model 快照无法转换为 Dictionary：%s。" % class_name_key
			)
		frozen_state[class_name_key] = model_state

	if not _are_frozen_model_targets_current(entries):
		return _make_capture_failure("Model 快照目标集合在冻结期间发生变化。")
	return {
		"ok": true,
		"snapshot": frozen_state,
		"entries": entries,
		"error": "",
	}


func _verify_global_capture_stability(
	frozen_models: Dictionary,
	history_util: Object,
	frozen_history: Dictionary,
	has_history: bool
) -> Dictionary:
	if has_history:
		if history_util == null:
			return _make_capture_failure(
				"命令历史快照稳定性复核失败：存储目标已经失效。"
			)
		var history_result: Dictionary = _capture_history_state(history_util)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			history_result,
			"ok",
			false
		):
			return _make_capture_failure(
				"命令历史快照稳定性复核失败：%s"
				% _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					history_result,
					"error",
					"无法再次读取命令历史。"
				)
			)
		var current_history: Dictionary = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
				history_result,
				"snapshot"
			)
		)
		if current_history != frozen_history:
			return _make_capture_failure(
				"命令历史快照稳定性复核失败：当前 JSON 状态与冻结状态不一致。"
			)
	return _verify_frozen_model_capture_stability(frozen_models)


func _verify_frozen_model_capture_stability(
	frozen_capture: Dictionary
) -> Dictionary:
	var entries: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(
		frozen_capture,
		"entries"
	)
	if not _are_frozen_model_targets_current(entries):
		return _make_capture_failure(
			"Model 快照稳定性复核失败：目标集合已经变化。"
		)
	var frozen_state: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
		frozen_capture,
		"snapshot"
	)

	# 初次冻结按正序执行；反序复核先观察后序 serializer 对前序 Model 的写入。
	for entry_index: int in range(entries.size() - 1, -1, -1):
		var entry_variant: Variant = entries[entry_index]
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(
			entry_variant
		)
		if not _is_frozen_model_target_current(entry):
			return _make_capture_failure(
				"Model 快照稳定性复核失败：目标身份或稳定键已经变化。"
			)
		var model: GFModel = _get_model_from_snapshot_entry(entry)
		if model == null:
			return _make_capture_failure(
				"Model 快照稳定性复核失败：目标已经失效。"
			)
		var class_name_key: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"key"
		)
		var current_state_value: Variant = (
			_GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(model.to_dict())
		)
		if not current_state_value is Dictionary:
			return _make_capture_failure(
				"Model 快照稳定性复核失败：%s 无法转换为 Dictionary。"
				% class_name_key
			)
		if not _is_frozen_model_target_current(entry):
			return _make_capture_failure(
				"Model 快照稳定性复核失败：%s 的目标身份或稳定键已经变化。"
				% class_name_key
			)
		var expected_state_value: Variant = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_value(
				frozen_state,
				class_name_key
			)
		)
		if not expected_state_value is Dictionary:
			return _make_capture_failure(
				"Model 快照稳定性复核失败：%s 缺少冻结 Dictionary。"
				% class_name_key
			)
		var current_state: Dictionary = current_state_value
		var expected_state: Dictionary = expected_state_value
		if current_state != expected_state:
			return _make_capture_failure(
				"Model 快照稳定性复核失败：%s 的当前 JSON 状态与冻结状态不一致。"
				% class_name_key
			)

	if not _are_frozen_model_targets_current(entries):
		return _make_capture_failure(
			"Model 快照稳定性复核失败：目标集合在复核期间发生变化。"
		)
	return {
		"ok": true,
		"error": "",
	}


func _materialize_frozen_model_capture(
	frozen_capture: Dictionary,
	options: Dictionary
) -> Dictionary:
	var entries: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(
		frozen_capture,
		"entries"
	)
	if not _are_frozen_model_targets_current(entries):
		return _make_capture_failure("Model 快照目标集合在分帧物化前发生变化。")

	var frozen_state: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
		frozen_capture,
		"snapshot"
	)
	var materialized_state: Dictionary = {}
	var max_models_per_frame: int = _get_snapshot_models_per_frame(options)
	var processed_since_yield: int = 0
	for entry_index: int in range(entries.size()):
		var entry_variant: Variant = entries[entry_index]
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(
			entry_variant
		)
		if not _is_frozen_model_target_current(entry):
			return _make_capture_failure("Model 快照目标在分帧物化期间失效。")
		var class_name_key: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"key"
		)
		materialized_state[class_name_key] = (
			_GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(
				_GF_VARIANT_ACCESS_SCRIPT.get_option_value(
					frozen_state,
					class_name_key
				)
			)
		)
		processed_since_yield += 1
		if entry_index + 1 >= entries.size():
			continue
		var yielded: bool = await _wait_snapshot_frame_if_needed(
			processed_since_yield,
			max_models_per_frame
		)
		if yielded:
			processed_since_yield = 0
			if not _are_frozen_model_targets_current(entries):
				return _make_capture_failure(
					"Model 快照目标集合在分帧等待期间发生变化。"
				)

	if not _are_frozen_model_targets_current(entries):
		return _make_capture_failure("Model 快照目标集合在分帧物化后发生变化。")
	return _make_capture_success(materialized_state)


func _are_frozen_model_targets_current(entries: Array) -> bool:
	if _models.size() != entries.size():
		return false
	for entry_variant: Variant in entries:
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(
			entry_variant
		)
		if not _is_frozen_model_target_current(entry):
			return false
	return true


func _is_frozen_model_target_current(entry: Dictionary) -> bool:
	var model: GFModel = _get_model_from_snapshot_entry(entry)
	if model == null:
		return false
	var script_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		entry,
		"script"
	)
	if not script_value is Script:
		return false
	var script_cls: Script = script_value
	if (
		_get_model_key(script_cls, model)
		!= _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "key")
	):
		return false
	return _get_model_from_snapshot_entry(entry) == model


func _validate_global_snapshot(
	data: Dictionary,
	command_builder: Callable
) -> Dictionary:
	if not data.has("format_version"):
		return _make_restore_failure(&"validate", "全局快照格式版本无效。")
	var format_version_value: Variant = data["format_version"]
	if (
		typeof(format_version_value) != TYPE_INT
		or format_version_value != _SNAPSHOT_FORMAT_VERSION
	):
		return _make_restore_failure(&"validate", "全局快照格式版本无效。")
	if not data.has("models") or not data["models"] is Dictionary:
		return _make_restore_failure(&"validate", "全局快照 models 必须是 Dictionary。")
	if not data.has("command_history"):
		return _make_restore_success()
	if not data["command_history"] is Dictionary:
		return _make_restore_failure(&"validate", "全局快照 command_history 必须是 Dictionary。")
	if not command_builder.is_valid():
		return _make_restore_failure(&"validate", "恢复命令历史需要有效的 command_builder。")
	var history_util: Object = _get_command_history_store()
	if history_util == null:
		return _make_restore_failure(&"validate", "快照包含命令历史，但当前架构没有命令历史存储服务。")
	if (
		not history_util.has_method("serialize_full_history")
		or not history_util.has_method("deserialize_full_history")
	):
		return _make_restore_failure(&"validate", "命令历史存储服务不支持完整快照事务。")
	if not _is_command_history_store_current(history_util):
		return _make_restore_failure(&"validate", "命令历史存储目标在验证期间发生变化。")
	var success_result: Dictionary = _make_restore_success()
	success_result["history_store"] = history_util
	return success_result


func _capture_history_state(history_util: Object) -> Dictionary:
	if history_util == null or not history_util.has_method("serialize_full_history"):
		return _make_capture_failure("无法读取命令历史快照。")
	if not _is_command_history_store_current(history_util):
		return _make_capture_failure("命令历史存储目标在捕获前发生变化。")
	var serialized_state: Variant = history_util.call("serialize_full_history")
	if not _is_command_history_store_current(history_util):
		return _make_capture_failure("命令历史存储目标在捕获期间发生变化。")
	if not serialized_state is Dictionary:
		return _make_capture_failure("命令历史快照必须是 Dictionary。")
	var json_state: Variant = _GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(
		serialized_state
	)
	if not json_state is Dictionary:
		return _make_capture_failure("命令历史快照无法转换为 Dictionary。")
	var history_state: Dictionary = json_state
	return _make_capture_success(history_state.duplicate(true))


func _apply_and_verify_history_state(
	history_util: Object,
	target: Dictionary,
	command_builder: Callable
) -> Dictionary:
	if (
		history_util == null
		or not history_util.has_method("deserialize_full_history")
		or not history_util.has_method("serialize_full_history")
	):
		return {
			"ok": false,
			"target_current": false,
		}
	if not _is_command_history_store_current(history_util):
		return {
			"ok": false,
			"target_current": false,
		}
	history_util.call(
		"deserialize_full_history",
		target.duplicate(true),
		command_builder
	)
	if not _is_command_history_store_current(history_util):
		return {
			"ok": false,
			"target_current": false,
		}
	var current_state: Variant = history_util.call("serialize_full_history")
	if not _is_command_history_store_current(history_util):
		return {
			"ok": false,
			"target_current": false,
		}
	if not current_state is Dictionary:
		return {
			"ok": false,
			"target_current": true,
		}
	return {
		"ok": _GF_VARIANT_ACCESS_SCRIPT.values_equal(
			_GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(current_state),
			_GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(target)
		),
		"target_current": true,
	}


func _history_state_matches(
	history_util: Object,
	expected_state: Dictionary
) -> bool:
	if (
		history_util == null
		or not history_util.has_method("serialize_full_history")
		or not _is_command_history_store_current(history_util)
	):
		return false
	var current_state: Variant = history_util.call("serialize_full_history")
	if not _is_command_history_store_current(history_util):
		return false
	if not current_state is Dictionary:
		return false
	return _GF_VARIANT_ACCESS_SCRIPT.values_equal(
		_GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(current_state),
		_GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(expected_state)
	)


func _rollback_global_restore(
	history_util: Object,
	history_before: Dictionary,
	command_builder: Callable,
	model_entries: Array,
	history_target_current: bool
) -> bool:
	var history_rolled_back: bool = false
	if (
		history_target_current
		and _is_command_history_store_current(history_util)
	):
		var history_rollback_result: Dictionary = _apply_and_verify_history_state(
			history_util,
			history_before,
			command_builder
		)
		history_rolled_back = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			history_rollback_result,
			"ok",
			false
		)
	var models_rolled_back: bool = _rollback_model_restore_entries(
		model_entries,
		model_entries
	)
	if history_rolled_back:
		history_rolled_back = _history_state_matches(
			history_util,
			history_before
		)
	if models_rolled_back:
		models_rolled_back = _model_restore_entries_match_state(
			model_entries,
			"before"
		)
	return history_rolled_back and models_rolled_back


func _build_model_restore_plan(data: Dictionary) -> Dictionary:
	for data_key: Variant in data.keys():
		if typeof(data_key) != TYPE_STRING:
			return _make_restore_failure(
				&"validate",
				"Model 快照键必须是 String。"
			)

	var entry_report: Dictionary = _collect_model_snapshot_entries()
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(entry_report, "ok", false):
		return _make_restore_failure(
			&"validate",
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				entry_report,
				"error",
				"Model 快照目标收集失败。"
			)
		)

	var entries: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(
		entry_report,
		"entries"
	)
	var known_keys: Dictionary = {}
	for entry_variant: Variant in entries:
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(entry_variant)
		var model: GFModel = _get_model_from_snapshot_entry(entry)
		if model == null or not _is_frozen_model_target_current(entry):
			return _make_restore_failure(&"validate", "Model 快照目标在验证期间失效。")
		var class_name_key: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"key"
		)
		known_keys[class_name_key] = true

	for data_key: Variant in data.keys():
		var data_key_string: String = data_key
		if not known_keys.has(data_key_string):
			return _make_restore_failure(
				&"validate",
				"快照包含未注册的 Model 键：%s。" % data_key_string
			)

	for known_key_variant: Variant in known_keys.keys():
		var known_key: String = known_key_variant
		if not data.has(known_key):
			return _make_restore_failure(
				&"validate",
				"快照缺少已注册的 Model 键：%s。" % known_key
			)

	var restore_entries: Array[Dictionary] = []
	for entry_variant: Variant in entries:
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(
			entry_variant
		)
		var model: GFModel = _get_model_from_snapshot_entry(entry)
		if model == null or not _is_frozen_model_target_current(entry):
			return _make_restore_failure(&"validate", "Model 快照目标在验证期间失效。")
		var class_name_key: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			entry,
			"key"
		)
		if not data[class_name_key] is Dictionary:
			return _make_restore_failure(
				&"validate",
				"Model 数据必须是 Dictionary：%s。" % class_name_key
			)
		var restore_entry: Dictionary = entry.duplicate()
		restore_entry["before"] = model.to_dict().duplicate(true)
		if not _is_frozen_model_target_current(entry):
			return _make_restore_failure(
				&"validate",
				"Model 快照目标在读取恢复基线期间发生变化。"
			)
		restore_entry["target"] = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(
			data[class_name_key]
		).duplicate(true)
		restore_entries.append(restore_entry)

	if not _are_model_restore_targets_current(restore_entries):
		return _make_restore_failure(
			&"validate",
			"Model 快照目标集合在验证期间发生变化。"
		)
	return {
		"ok": true,
		"entries": restore_entries,
		"phase": &"validate",
		"rolled_back": false,
		"error": "",
	}


func _apply_model_restore_plan(entries: Array) -> Dictionary:
	var applied_entries: Array[Dictionary] = []
	for entry_variant: Variant in entries:
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(entry_variant)
		if not _is_frozen_model_target_current(entry):
			var _partial_rollback_succeeded: bool = _rollback_model_restore_entries(
				applied_entries,
				entries
			)
			return _make_restore_failure(
				&"apply",
				"Model 快照目标在应用期间失效。",
				false
			)
		var model: GFModel = _get_model_from_snapshot_entry(entry)
		if model == null:
			var _missing_target_rollback_succeeded: bool = (
				_rollback_model_restore_entries(applied_entries, entries)
			)
			return _make_restore_failure(
				&"apply",
				"Model 快照目标在应用期间失效。",
				false
			)
		applied_entries.append(entry)
		var target: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			entry,
			"target"
		)
		model.from_dict(target.duplicate(true))
		if not _is_frozen_model_target_current(entry):
			var target_drift_rollback_succeeded: bool = (
				_rollback_model_restore_entries(applied_entries, entries)
			)
			return _make_restore_failure(
				&"apply",
				"Model 应用期间注册 identity 或 save key 发生变化：%s。"
				% _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "key"),
				target_drift_rollback_succeeded
			)
		var applied_state: Variant = _GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(
			model.to_dict()
		)
		if not _is_frozen_model_target_current(entry):
			var verify_target_drift_rollback_succeeded: bool = (
				_rollback_model_restore_entries(applied_entries, entries)
			)
			return _make_restore_failure(
				&"apply",
				"Model 验证期间注册 identity 或 save key 发生变化：%s。"
				% _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "key"),
				verify_target_drift_rollback_succeeded
			)
		var target_state: Variant = _GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(
			target
		)
		if not _GF_VARIANT_ACCESS_SCRIPT.values_equal(applied_state, target_state):
			var apply_rollback_succeeded: bool = _rollback_model_restore_entries(
				applied_entries,
				entries
			)
			return _make_restore_failure(
				&"apply",
				"Model 应用后状态与目标快照不一致：%s。"
				% _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "key"),
				apply_rollback_succeeded
			)
	if not _model_restore_entries_match_state(entries, "target"):
		var final_rollback_succeeded: bool = _rollback_model_restore_entries(
			applied_entries,
			entries
		)
		return _make_restore_failure(
			&"commit",
			"Model 聚合状态在恢复提交前与目标快照不一致。",
			final_rollback_succeeded
		)
	return _make_restore_success()


func _apply_model_restore_plan_async(
	entries: Array,
	options: Dictionary
) -> Dictionary:
	var applied_entries: Array[Dictionary] = []
	var max_models_per_frame: int = _get_snapshot_models_per_frame(options)
	var processed_since_yield: int = 0
	for entry_index: int in range(entries.size()):
		var entry_variant: Variant = entries[entry_index]
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(
			entry_variant
		)
		if not _is_frozen_model_target_current(entry):
			var _partial_rollback_succeeded: bool = _rollback_model_restore_entries(
				applied_entries,
				entries
			)
			return _make_restore_failure(
				&"apply",
				"Model 快照目标在异步应用期间失效。",
				false
			)
		var model: GFModel = _get_model_from_snapshot_entry(entry)
		if model == null:
			var _missing_target_rollback_succeeded: bool = (
				_rollback_model_restore_entries(applied_entries, entries)
			)
			return _make_restore_failure(
				&"apply",
				"Model 快照目标在异步应用期间失效。",
				false
			)
		applied_entries.append(entry)
		var target: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			entry,
			"target"
		)
		model.from_dict(target.duplicate(true))
		if not _is_frozen_model_target_current(entry):
			var target_drift_rollback_succeeded: bool = (
				_rollback_model_restore_entries(applied_entries, entries)
			)
			return _make_restore_failure(
				&"apply",
				"Model 异步应用期间注册 identity 或 save key 发生变化：%s。"
				% _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "key"),
				target_drift_rollback_succeeded
			)
		var applied_state: Variant = _GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(
			model.to_dict()
		)
		if not _is_frozen_model_target_current(entry):
			var verify_target_drift_rollback_succeeded: bool = (
				_rollback_model_restore_entries(applied_entries, entries)
			)
			return _make_restore_failure(
				&"apply",
				"Model 异步验证期间注册 identity 或 save key 发生变化：%s。"
				% _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "key"),
				verify_target_drift_rollback_succeeded
			)
		var target_state: Variant = _GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(
			target
		)
		if not _GF_VARIANT_ACCESS_SCRIPT.values_equal(applied_state, target_state):
			var apply_rollback_succeeded: bool = (
				_rollback_model_restore_entries(applied_entries, entries)
			)
			return _make_restore_failure(
				&"apply",
				"Model 异步应用后状态与目标快照不一致：%s。"
				% _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "key"),
				apply_rollback_succeeded
			)

		processed_since_yield += 1
		if entry_index + 1 >= entries.size():
			continue
		var yielded: bool = await _wait_snapshot_frame_if_needed(
			processed_since_yield,
			max_models_per_frame
		)
		if yielded:
			processed_since_yield = 0
			if not _are_model_restore_targets_current(entries):
				var _wait_rollback_succeeded: bool = (
					_rollback_model_restore_entries(applied_entries, entries)
				)
				return _make_restore_failure(
					&"apply",
					"Model 快照目标集合在异步恢复等待期间发生变化。",
					false
				)

	if not _model_restore_entries_match_state(entries, "target"):
		var final_rollback_succeeded: bool = _rollback_model_restore_entries(
			applied_entries,
			entries
		)
		return _make_restore_failure(
			&"commit",
			"Model 聚合状态在异步恢复提交前与目标快照不一致。",
			final_rollback_succeeded
		)
	return _make_restore_success()


func _are_model_restore_targets_current(entries: Array) -> bool:
	if _models.size() != entries.size():
		return false
	for entry_variant: Variant in entries:
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(
			entry_variant
		)
		if not _is_frozen_model_target_current(entry):
			return false
	return true


func _model_restore_entries_match_state(
	entries: Array,
	state_field: String
) -> bool:
	if not _are_model_restore_targets_current(entries):
		return false
	for entry_variant: Variant in entries:
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(
			entry_variant
		)
		if (
			not entry.has(state_field)
			or not entry[state_field] is Dictionary
		):
			return false
		var model: GFModel = _get_model_from_snapshot_entry(entry)
		if model == null or not _is_frozen_model_target_current(entry):
			return false
		var current_state: Variant = _GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(
			model.to_dict()
		)
		if not _is_frozen_model_target_current(entry):
			return false
		var expected_state: Variant = _GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(
			entry[state_field]
		)
		if not _GF_VARIANT_ACCESS_SCRIPT.values_equal(
			current_state,
			expected_state
		):
			return false
	return _are_model_restore_targets_current(entries)


func _rollback_model_restore_entries(
	applied_entries: Array[Dictionary],
	transaction_entries: Array = []
) -> bool:
	var rolled_back: bool = true
	for index: int in range(applied_entries.size() - 1, -1, -1):
		var entry: Dictionary = applied_entries[index]
		if not _is_frozen_model_target_current(entry):
			rolled_back = false
			continue
		var model: GFModel = _get_model_from_snapshot_entry(entry)
		if model == null:
			rolled_back = false
			continue
		var before: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			entry,
			"before"
		)
		model.from_dict(before.duplicate(true))
		if not _is_frozen_model_target_current(entry):
			rolled_back = false
			continue
		var rolled_back_state: Variant = (
			_GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(model.to_dict())
		)
		if not _is_frozen_model_target_current(entry):
			rolled_back = false
			continue
		var expected_state: Variant = (
			_GF_VARIANT_ACCESS_SCRIPT.to_json_compatible(before)
		)
		if not _GF_VARIANT_ACCESS_SCRIPT.values_equal(
			rolled_back_state,
			expected_state
		):
			rolled_back = false
	var verification_entries: Array = transaction_entries
	if verification_entries.is_empty():
		verification_entries = applied_entries
	return (
		rolled_back
		and _model_restore_entries_match_state(
			verification_entries,
			"before"
		)
	)


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


func _is_command_history_store_current(expected_store: Object) -> bool:
	if expected_store == null or not is_instance_valid(expected_store):
		return false
	var current_store: Object = _get_command_history_store()
	return (
		current_store != null
		and is_instance_valid(current_store)
		and current_store == expected_store
	)


func _collect_model_snapshot_entries() -> Dictionary:
	var entries: Array[Dictionary] = []
	var used_keys: Dictionary = {}
	var duplicate_keys: PackedStringArray = PackedStringArray()
	var invalid_target_error: String = ""
	for script_cls: Script in _models:
		var model_object: Object = _get_dictionary_object(_models, script_cls)
		if not model_object is GFModel:
			invalid_target_error = "Model 注册表包含无效快照目标。"
			break
		var model: GFModel = model_object
		var class_name_key: String = _get_model_key(script_cls, model)
		if class_name_key.is_empty():
			invalid_target_error = "Model 缺少稳定快照键。"
			break
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

	if not invalid_target_error.is_empty():
		return {
			"ok": false,
			"entries": [],
			"error": invalid_target_error,
		}

	if not duplicate_keys.is_empty():
		var duplicate_error: String = (
			"Model 快照键重复：%s。请为每个 Model 提供唯一 get_save_key()。"
			% ", ".join(duplicate_keys)
		)
		push_error("[GFArchitecture] %s" % duplicate_error)
		return {
			"ok": false,
			"entries": [],
			"error": duplicate_error,
		}

	return {
		"ok": true,
		"entries": entries,
		"error": "",
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
	push_error("[GFArchitecture] 可序列化 Model 缺少稳定标识：请为脚本声明 class_name 或重写 get_save_key()。")
	return ""
