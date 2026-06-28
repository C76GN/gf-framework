## GFLevelUtility: 关卡流程管理工具。
##
## 负责统一关卡数据读取、开始、重开、胜利和失败信号派发。
## 默认通过 GFConfigProvider 读取静态关卡表，并可在重开关卡时清理
## 命令历史与外部显式注册的运行时残留。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFLevelUtility
extends GFUtility


# --- 信号 ---

## 当关卡开始时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param level_id: 关卡 ID。
## [br]
## @param level_data: 当前关卡数据。
## [br]
## @schema level_id: StringName，入口规范化后的关卡 ID。
## [br]
## @schema level_data: Dictionary，当前关卡数据副本。
signal level_started(level_id: StringName, level_data: Dictionary)

## 当关卡重开时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param level_id: 关卡 ID。
## [br]
## @param level_data: 当前关卡数据。
## [br]
## @schema level_id: StringName，入口规范化后的关卡 ID。
## [br]
## @schema level_data: Dictionary，当前关卡数据副本。
signal level_restarted(level_id: StringName, level_data: Dictionary)

## 当关卡胜利时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param level_id: 关卡 ID。
## [br]
## @schema level_id: StringName，入口规范化后的关卡 ID。
signal level_won(level_id: StringName)

## 当关卡失败时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param level_id: 关卡 ID。
## [br]
## @schema level_id: StringName，入口规范化后的关卡 ID。
signal level_lost(level_id: StringName)


# --- 公共变量 ---

## 默认关卡配置表名。
## [br]
## @api public
var level_table_name: StringName = &"levels"

## 当前关卡 ID。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema current_level_id: StringName，入口规范化后的当前关卡 ID；未启动关卡时为空。
var current_level_id: StringName = &""

## 当前关卡数据副本。
## [br]
## @api public
## [br]
## @schema current_level_data: Dictionary，当前关卡数据副本；来源可以是配置表、目录条目或外部覆盖。
var current_level_data: Dictionary = {}

## 可选关卡目录资源。
## [br]
## @api public
var catalog: GFLevelCatalog = null

## 为 true 时，找不到关卡数据会拒绝启动或重开当前关卡。
## [br]
## @api public
var fail_on_missing_level_data: bool = false


# --- 私有变量 ---

var _current_level_override: Dictionary = {}
var _runtime_cleanup_callbacks: Dictionary = {}


# --- GF 生命周期方法 ---

## 初始化关卡服务运行态。
## [br]
## @api framework_internal
func init() -> void:
	current_level_id = &""
	current_level_data.clear()
	_current_level_override.clear()


## 释放关卡服务运行态。
## [br]
## @api framework_internal
func dispose() -> void:
	current_level_id = &""
	current_level_data.clear()
	_current_level_override.clear()
	_runtime_cleanup_callbacks.clear()
	catalog = null


# --- 公共方法 ---

## 配置关卡数据表名。
## [br]
## @api public
## [br]
## @param table_name: 用于 GFConfigProvider.get_record() 的表名。
func configure(table_name: StringName = &"levels") -> void:
	level_table_name = table_name


## 设置关卡目录资源。
## [br]
## @api public
## [br]
## @param level_catalog: 关卡目录。
func set_catalog(level_catalog: GFLevelCatalog) -> void:
	catalog = level_catalog


## 获取关卡目录资源。
## [br]
## @api public
## [br]
## @return: 关卡目录；不存在时返回 null。
func get_catalog() -> GFLevelCatalog:
	return catalog


## 获取目录中的关卡条目。
## [br]
## @api public
## [br]
## @param level_id: 关卡 ID。
## [br]
## @return: 关卡条目；不存在时返回 null。
func get_level_entry(level_id: StringName) -> GFLevelEntry:
	if catalog == null:
		return null
	return catalog.get_entry(level_id)


## 获取目录中的关卡列表。
## [br]
## @api public
## [br]
## @param pack_id: 可选关卡扩展 ID；为空时返回全部。
## [br]
## @return: 关卡条目数组。
## [br]
## @schema return: Array[GFLevelEntry]，目录返回的已排序关卡条目拷贝。
func get_catalog_levels(pack_id: StringName = &"") -> Array[GFLevelEntry]:
	if catalog == null:
		return []
	return catalog.get_levels(pack_id)


## 读取关卡数据。
## [br]
## @api public
## [br]
## @param level_id: 关卡 ID。
## [br]
## @return: 关卡数据副本，找不到时返回空字典。
## [br]
## @schema level_id: Variant，项目传入的关卡 ID，通常为 StringName 或 String。
## [br]
## @schema return: Dictionary，当前关卡数据副本；找不到数据时为空字典。
func load_level_data(level_id: Variant) -> Dictionary:
	var canonical_level_id: StringName = _to_level_id(level_id)
	var config_provider: GFConfigProvider = _get_config_provider()
	if config_provider != null:
		var record: Variant = config_provider.get_record(level_table_name, canonical_level_id)
		if record is Dictionary:
			var record_data: Dictionary = record
			return record_data.duplicate(true)

		var record_object: Object = _variant_to_object(record)
		if record_object != null and record_object.has_method("to_dict"):
			var raw_data: Variant = record_object.call("to_dict")
			if raw_data is Dictionary:
				var data: Dictionary = raw_data
				return data.duplicate(true)

	var entry: GFLevelEntry = get_level_entry(canonical_level_id)
	if entry != null:
		var entry_data: Dictionary = entry.metadata.duplicate(true)
		entry_data["level_id"] = entry.get_level_id()
		entry_data["pack_id"] = entry.pack_id
		entry_data["scene_path"] = entry.scene_path
		entry_data["sort_order"] = entry.sort_order
		entry_data["unlocks_on_complete"] = entry.unlocks_on_complete.duplicate()
		return entry_data

	return {}


## 开始指定关卡。
## [br]
## @api public
## [br]
## @param level_id: 关卡 ID。
## [br]
## @param level_data_override: 可选的外部数据覆盖；为空时从配置表读取。
## [br]
## @return: 当前关卡数据副本。
## [br]
## @schema level_id: Variant，项目传入的关卡 ID，通常为 StringName 或 String。
## [br]
## @schema level_data_override: Dictionary，项目提供的关卡数据覆盖；非空时优先使用。
## [br]
## @schema return: Dictionary，启动后的当前关卡数据副本；失败时为空字典。
func start_level(level_id: Variant, level_data_override: Dictionary = {}) -> Dictionary:
	var canonical_level_id: StringName = _to_level_id(level_id)
	var next_override: Dictionary = level_data_override.duplicate(true)
	var next_data: Dictionary = next_override.duplicate(true) if not next_override.is_empty() else load_level_data(canonical_level_id)
	if fail_on_missing_level_data and next_data.is_empty():
		push_error("[GFLevelUtility] 找不到关卡数据：%s" % String(canonical_level_id))
		return {}

	current_level_id = canonical_level_id
	_current_level_override = next_override
	current_level_data = next_data
	level_started.emit(current_level_id, current_level_data.duplicate(true))
	return current_level_data.duplicate(true)


## 重开当前关卡，并清理常见运行时队列。
## [br]
## @api public
## [br]
## @param clear_runtime: 是否清理命令历史与表现队列。
## [br]
## @return: 当前关卡数据副本。
## [br]
## @schema return: Dictionary，重开后的当前关卡数据副本；失败时为空字典。
func restart_level(clear_runtime: bool = true) -> Dictionary:
	if current_level_id == &"":
		return {}

	if clear_runtime:
		clear_level_runtime()

	var next_data: Dictionary = _resolve_level_data(current_level_id)
	if fail_on_missing_level_data and next_data.is_empty():
		push_error("[GFLevelUtility] 找不到关卡数据：%s" % GFVariantData.to_text(current_level_id))
		return {}

	current_level_data = next_data
	level_restarted.emit(current_level_id, current_level_data.duplicate(true))
	return current_level_data.duplicate(true)


## 标记当前关卡胜利。
## [br]
## @api public
func win_current_level() -> void:
	if current_level_id == &"":
		return

	level_won.emit(current_level_id)


## 完成当前关卡并可选更新通用进度模型与后续解锁。
## [br]
## @api public
## [br]
## @param result: 项目层结果数据。
## [br]
## @param unlock_next: 是否解锁目录中的后续关卡。
## [br]
## @param emit_win_signal: 是否发出 level_won。
## [br]
## @schema result: Dictionary，项目自定义关卡完成结果。
func complete_current_level(
	result: Dictionary = {},
	unlock_next: bool = true,
	emit_win_signal: bool = true
) -> void:
	if current_level_id == &"":
		return

	var level_id: StringName = _to_level_id(current_level_id)
	var progress: GFLevelProgressModel = _get_progress_model()
	if progress != null:
		progress.complete_level(level_id, result)
		_unlock_declared_next_levels(level_id, progress)
		if unlock_next and catalog != null:
			var next_level_id: StringName = catalog.get_next_level_id(level_id)
			if next_level_id != &"":
				progress.unlock_level(next_level_id)

	if emit_win_signal:
		level_won.emit(current_level_id)


## 标记当前关卡失败。
## [br]
## @api public
func lose_current_level() -> void:
	if current_level_id == &"":
		return

	level_lost.emit(current_level_id)


## 清理常见关卡运行时残留。
## [br]
## @api public
func clear_level_runtime() -> void:
	var history: GFCommandHistoryUtility = _get_command_history_utility()
	if history != null:
		history.clear()

	for cleanup_id: StringName in _runtime_cleanup_callbacks.keys():
		var callback: Callable = _get_runtime_cleanup_callback(cleanup_id)
		if callback.is_valid():
			callback.call()


## 注册关卡运行时清理回调。
## [br]
## @api public
## [br]
## @param cleanup_id: 清理项唯一标识。
## [br]
## @param callback: 无参数清理回调。
## [br]
## @return: 注册成功返回 true。
func register_runtime_cleanup(cleanup_id: StringName, callback: Callable) -> bool:
	if cleanup_id == &"" or not callback.is_valid():
		return false
	_runtime_cleanup_callbacks[cleanup_id] = callback
	return true


## 注销关卡运行时清理回调。
## [br]
## @api public
## [br]
## @param cleanup_id: 清理项唯一标识。
func unregister_runtime_cleanup(cleanup_id: StringName) -> void:
	var _erase_result_363: Variant = _runtime_cleanup_callbacks.erase(cleanup_id)


## 检查关卡运行时清理回调是否存在。
## [br]
## @api public
## [br]
## @param cleanup_id: 清理项唯一标识。
## [br]
## @return: 存在返回 true。
func has_runtime_cleanup(cleanup_id: StringName) -> bool:
	return _runtime_cleanup_callbacks.has(cleanup_id)


## 获取已注册清理项标识。
## [br]
## @api public
## [br]
## @return: 排序后的清理项标识。
func get_runtime_cleanup_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for cleanup_id: StringName in _runtime_cleanup_callbacks.keys():
		var _append_result_385: Variant = result.append(String(cleanup_id))
	result.sort()
	return result


## 清除当前关卡记录。
## [br]
## @api public
func clear_current_level() -> void:
	current_level_id = &""
	current_level_data.clear()
	_current_level_override.clear()


## 启动目录中的下一个关卡。
## [br]
## @api public
## [br]
## @return: 下一个关卡数据；没有后续关卡时返回空字典。
## [br]
## @schema return: Dictionary，下一个关卡数据副本；没有后续关卡时为空字典。
func start_next_level() -> Dictionary:
	if current_level_id == &"" or catalog == null:
		return {}

	var next_level_id: StringName = catalog.get_next_level_id(_to_level_id(current_level_id))
	if next_level_id == &"":
		return {}

	return start_level(next_level_id)


## 解锁关卡进度。
## [br]
## @api public
## [br]
## @param level_id: 关卡 ID。
func unlock_level(level_id: StringName) -> void:
	var progress: GFLevelProgressModel = _get_progress_model()
	if progress != null:
		progress.unlock_level(level_id)


## 检查关卡是否已解锁。
## [br]
## @api public
## [br]
## @param level_id: 关卡 ID。
## [br]
## @return: 已解锁时返回 true；未注册进度模型时返回 true。
func is_level_unlocked(level_id: StringName) -> bool:
	var progress: GFLevelProgressModel = _get_progress_model()
	if progress == null:
		return true
	return progress.is_level_unlocked(level_id)


# --- 私有/辅助方法 ---

func _get_config_provider() -> GFConfigProvider:
	var utility: Object = get_utility(GFConfigProvider)
	if utility is GFConfigProvider:
		return utility
	return null


func _get_command_history_utility() -> GFCommandHistoryUtility:
	var utility: Object = get_utility(GFCommandHistoryUtility)
	if utility is GFCommandHistoryUtility:
		return utility
	return null


func _get_progress_model() -> GFLevelProgressModel:
	var model: Object = get_model(GFLevelProgressModel)
	if model is GFLevelProgressModel:
		return model
	return null


func _resolve_level_data(level_id: Variant) -> Dictionary:
	if not _current_level_override.is_empty():
		return _current_level_override.duplicate(true)

	return load_level_data(level_id)


func _unlock_declared_next_levels(level_id: StringName, progress: GFLevelProgressModel) -> void:
	if catalog == null or progress == null:
		return

	var entry: GFLevelEntry = catalog.get_entry(level_id)
	if entry == null:
		return

	for next_level_id: StringName in entry.unlocks_on_complete:
		progress.unlock_level(next_level_id)


func _to_level_id(value: Variant) -> StringName:
	return GFVariantData.to_string_name(value)


func _variant_to_object(value: Variant) -> Object:
	if value is Object:
		var object: Object = value
		if is_instance_valid(object):
			return object
	return null


func _get_runtime_cleanup_callback(cleanup_id: StringName) -> Callable:
	var value: Variant = _runtime_cleanup_callbacks[cleanup_id]
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()
