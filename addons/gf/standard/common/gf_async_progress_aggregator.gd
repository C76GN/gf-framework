## GFAsyncProgressAggregator: 多任务加权进度聚合器。
##
## 用于把调用方定义的多个子任务进度合成为一个 0 到 1 的总进度，并复用
## GFAsyncProgress 的数值、消息和时间节流。它只记录和发布进度，不执行任务、
## 不加载资源，也不决定 UI 平滑或展示策略。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 8.0.0
class_name GFAsyncProgressAggregator
extends RefCounted


# --- 信号 ---

## 总进度通过节流条件并对外发布时发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param value: 当前总进度，范围 0 到 1。
## [br]
## @param message: 当前进度消息。
## [br]
## @param metadata: 当前进度元数据。
## [br]
## @schema metadata: Dictionary，包含调用方元数据，并补充 total_progress、task_count、total_weight、task_index、task_key、task_progress、task_weight 和 task_metadata 等上下文。
signal progressed(value: float, message: String, metadata: Dictionary)


# --- 常量 ---

const _GF_REPORT_VALUE_CODEC_SCRIPT = preload("res://addons/gf/kernel/core/gf_report_value_codec.gd")
const _GF_VARIANT_KEY_CODEC_SCRIPT = preload("res://addons/gf/standard/foundation/variant/gf_variant_key_codec.gd")


# --- 公共变量 ---

## 子任务进度是否允许回退。默认 false，用于避免乱序回调造成总进度回跳。
## [br]
## @api public
## [br]
## @since 8.0.0
var allow_decrease: bool = false

## 触发总进度信号的最小数值变化。设为 0 时任意数值变化都会触发。
## [br]
## @api public
## [br]
## @since 8.0.0
var min_delta: float:
	get:
		return _progress.min_delta
	set(value):
		_progress.min_delta = maxf(value, 0.0)

## 触发总进度信号的最小时间间隔，单位毫秒。设为 0 时不按时间节流。
## [br]
## @api public
## [br]
## @since 8.0.0
var min_interval_msec: int:
	get:
		return _progress.min_interval_msec
	set(value):
		_progress.min_interval_msec = maxi(value, 0)

## 消息变化时是否允许触发信号，即使数值变化小于 min_delta。
## [br]
## @api public
## [br]
## @since 8.0.0
var emit_on_message_change: bool:
	get:
		return _progress.emit_on_message_change
	set(value):
		_progress.emit_on_message_change = value


# --- 私有变量 ---

var _progress: GFAsyncProgress = GFAsyncProgress.new(1.0)
var _tasks: Array[Dictionary] = []
var _task_indexes_by_key: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init() -> void:
	var connect_error: Error = _progress.progressed.connect(Callable(self, "_on_progressed")) as Error
	if connect_error != OK:
		push_warning("GFAsyncProgressAggregator failed to connect internal progress signal.")


# --- 公共方法 ---

## 添加一个子任务，并返回任务索引。
## [br]
## 如果 task_key 非 null 且已经存在，返回既有任务索引，不修改既有任务。权重会夹到不小于 0。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param task_key: 可选稳定任务 key；传 null 时创建未命名任务。
## [br]
## @param weight: 任务权重；小于 0 时按 0 处理。
## [br]
## @param task_metadata: 任务元数据。
## [br]
## @return 新任务或既有 keyed 任务的索引。
## [br]
## @schema task_key: Variant，null 表示无名任务；非 null 时必须是 GFVariantKeyCodec 接受的稳定 key。
## [br]
## @schema task_metadata: Dictionary，调用方定义的任务上下文。
func add_task(task_key: Variant = null, weight: float = 1.0, task_metadata: Dictionary = {}) -> int:
	var has_key: bool = _has_task_key(task_key)
	var key_token: String = ""
	if has_key:
		key_token = _make_task_key_token(task_key)
		if key_token.is_empty():
			return -1
		if _task_indexes_by_key.has(key_token):
			return GFVariantData.to_int(_task_indexes_by_key[key_token], -1)

	var task_index: int = _tasks.size()
	var task: Dictionary = {
		"index": task_index,
		"has_key": has_key,
		"key": GFVariantData.duplicate_variant(task_key),
		"key_token": key_token,
		"weight": maxf(weight, 0.0),
		"progress": 0.0,
		"metadata": task_metadata.duplicate(true),
	}
	_tasks.append(task)
	if has_key:
		_task_indexes_by_key[key_token] = task_index

	var _emitted: bool = _publish_progress("", {
		"event": &"task_added",
		"task_index": task_index,
		"task_key": _GF_REPORT_VALUE_CODEC_SCRIPT.to_json_compatible(task_key),
		"task_weight": maxf(weight, 0.0),
		"task_metadata": task_metadata.duplicate(true),
	})
	return task_index


## 判断任务 key 是否已经注册。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param task_key: 任务 key。
## [br]
## @return key 已注册时返回 true。
## [br]
## @schema task_key: Variant，必须是 GFVariantKeyCodec 接受的稳定 key。
func has_task(task_key: Variant) -> bool:
	if not _has_task_key(task_key):
		return false
	var key_token: String = _make_task_key_token(task_key)
	if key_token.is_empty():
		return false
	return _task_indexes_by_key.has(key_token)


## 获取任务 key 对应的任务索引。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param task_key: 任务 key。
## [br]
## @return 已注册任务索引；不存在时返回 -1。
## [br]
## @schema task_key: Variant，必须是 GFVariantKeyCodec 接受的稳定 key。
func get_task_index(task_key: Variant) -> int:
	if not has_task(task_key):
		return -1
	var key_token: String = _make_task_key_token(task_key)
	return GFVariantData.to_int(_task_indexes_by_key[key_token], -1)


## 设置指定任务的 0 到 1 进度。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param task_index: add_task() 返回的任务索引。
## [br]
## @param value: 新任务进度，范围会被夹到 0 到 1。
## [br]
## @param message: 总进度消息。
## [br]
## @param task_metadata: 本次任务元数据，会合并到任务快照。
## [br]
## @return 本次更新是否发出了 progressed。
## [br]
## @schema task_metadata: Dictionary，调用方定义的任务上下文。
func set_task_progress(task_index: int, value: float, message: String = "", task_metadata: Dictionary = {}) -> bool:
	if not _is_valid_task_index(task_index):
		return false

	var task: Dictionary = _tasks[task_index]
	var previous_value: float = _get_task_progress(task)
	var next_value: float = clampf(value, 0.0, 1.0)
	if (
		not allow_decrease
		and next_value < previous_value
		and not is_equal_approx(next_value, previous_value)
	):
		return false

	var value_changed: bool = not is_equal_approx(next_value, previous_value)
	if not value_changed and message == "" and task_metadata.is_empty():
		return false

	task["progress"] = next_value
	if not task_metadata.is_empty():
		var metadata: Dictionary = GFVariantData.get_option_dictionary(task, "metadata")
		var _merge_result: Dictionary = GFVariantData.merge_dictionary(metadata, task_metadata, true, true)
		task["metadata"] = metadata
	_tasks[task_index] = task

	return _publish_task_progress(task_index, message)


## 通过任务 key 设置 0 到 1 进度。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param task_key: 任务 key。
## [br]
## @param value: 新任务进度，范围会被夹到 0 到 1。
## [br]
## @param message: 总进度消息。
## [br]
## @param task_metadata: 本次任务元数据，会合并到任务快照。
## [br]
## @return 本次更新是否发出了 progressed。
## [br]
## @schema task_key: Variant，调用方定义的任务 key。
## [br]
## @schema task_metadata: Dictionary，调用方定义的任务上下文。
func set_task_progress_by_key(task_key: Variant, value: float, message: String = "", task_metadata: Dictionary = {}) -> bool:
	return set_task_progress(get_task_index(task_key), value, message, task_metadata)


## 以完成数 / 总数设置指定任务进度。
## [br]
## total 小于等于 0 时按已完成处理，避免未知总量流程永久卡在 0。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param task_index: add_task() 返回的任务索引。
## [br]
## @param completed: 已完成数量。
## [br]
## @param total: 总数量。
## [br]
## @param message: 总进度消息。
## [br]
## @param task_metadata: 本次任务元数据，会合并到任务快照。
## [br]
## @return 本次更新是否发出了 progressed。
## [br]
## @schema task_metadata: Dictionary，调用方定义的任务上下文。
func set_task_fraction(
	task_index: int,
	completed: float,
	total: float,
	message: String = "",
	task_metadata: Dictionary = {}
) -> bool:
	var value: float = completed / total if total > 0.0 else 1.0
	return set_task_progress(task_index, value, message, task_metadata)


## 通过任务 key 以完成数 / 总数设置进度。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param task_key: 任务 key。
## [br]
## @param completed: 已完成数量。
## [br]
## @param total: 总数量。
## [br]
## @param message: 总进度消息。
## [br]
## @param task_metadata: 本次任务元数据，会合并到任务快照。
## [br]
## @return 本次更新是否发出了 progressed。
## [br]
## @schema task_key: Variant，调用方定义的任务 key。
## [br]
## @schema task_metadata: Dictionary，调用方定义的任务上下文。
func set_task_fraction_by_key(
	task_key: Variant,
	completed: float,
	total: float,
	message: String = "",
	task_metadata: Dictionary = {}
) -> bool:
	return set_task_fraction(get_task_index(task_key), completed, total, message, task_metadata)


## 将指定任务标记为完成。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param task_index: add_task() 返回的任务索引。
## [br]
## @param message: 总进度消息。
## [br]
## @param task_metadata: 本次任务元数据，会合并到任务快照。
## [br]
## @return 本次更新是否发出了 progressed。
## [br]
## @schema task_metadata: Dictionary，调用方定义的任务上下文。
func complete_task(task_index: int, message: String = "", task_metadata: Dictionary = {}) -> bool:
	return set_task_progress(task_index, 1.0, message, task_metadata)


## 通过任务 key 标记任务完成。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param task_key: 任务 key。
## [br]
## @param message: 总进度消息。
## [br]
## @param task_metadata: 本次任务元数据，会合并到任务快照。
## [br]
## @return 本次更新是否发出了 progressed。
## [br]
## @schema task_key: Variant，调用方定义的任务 key。
## [br]
## @schema task_metadata: Dictionary，调用方定义的任务上下文。
func complete_task_by_key(task_key: Variant, message: String = "", task_metadata: Dictionary = {}) -> bool:
	return complete_task(get_task_index(task_key), message, task_metadata)


## 将所有任务标记为完成，并强制发布总进度 1.0。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param message: 总进度消息。
## [br]
## @param metadata: 完成元数据。
## [br]
## @return 是否成功发出 progressed。
## [br]
## @schema metadata: Dictionary，调用方定义的完成上下文。
func complete_all(message: String = "", metadata: Dictionary = {}) -> bool:
	for task_index: int in range(_tasks.size()):
		var task: Dictionary = _tasks[task_index]
		task["progress"] = 1.0
		_tasks[task_index] = task
	var progress_metadata: Dictionary = _make_progress_metadata(metadata)
	return _progress.complete(message, progress_metadata)


## 重置聚合器状态，不发出信号。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param clear_tasks: 为 true 时移除全部任务；否则保留任务并把进度归零。
func reset(clear_tasks: bool = false) -> void:
	if clear_tasks:
		_tasks.clear()
		_task_indexes_by_key.clear()
	else:
		for task_index: int in range(_tasks.size()):
			var task: Dictionary = _tasks[task_index]
			task["progress"] = 0.0
			_tasks[task_index] = task
	_progress.reset(get_total_progress(), "", _make_progress_metadata({}))


## 获取当前加权总进度。
## [br]
## 没有正权重任务时返回 1.0，表示当前没有待完成工作。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前总进度，范围 0 到 1。
func get_total_progress() -> float:
	var total_weight: float = _get_total_weight()
	if total_weight <= 0.0:
		return 1.0

	var weighted_progress: float = 0.0
	for task: Dictionary in _tasks:
		var task_weight: float = _get_task_weight(task)
		if task_weight <= 0.0:
			continue
		weighted_progress += _get_task_progress(task) * task_weight
	return clampf(weighted_progress / total_weight, 0.0, 1.0)


## 获取子任务数量。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前任务数量。
func get_task_count() -> int:
	return _tasks.size()


## 判断当前加权总进度是否已完成。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 总进度为 1.0 时返回 true。
func is_complete() -> bool:
	return is_equal_approx(get_total_progress(), 1.0)


## 获取指定任务快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param task_index: add_task() 返回的任务索引。
## [br]
## @return 任务快照；索引无效时返回空字典。
## [br]
## @schema return: Dictionary，包含 index、has_key、key、weight、progress 和 metadata。
func get_task_snapshot(task_index: int) -> Dictionary:
	if not _is_valid_task_index(task_index):
		return {}
	var task: Dictionary = _tasks[task_index]
	return {
		"index": GFVariantData.get_option_int(task, "index", task_index),
		"has_key": GFVariantData.get_option_bool(task, "has_key"),
		"key": _GF_REPORT_VALUE_CODEC_SCRIPT.to_json_compatible(GFVariantData.get_option_value(task, "key")),
		"weight": _get_task_weight(task),
		"progress": _get_task_progress(task),
		"metadata": GFVariantData.get_option_dictionary(task, "metadata"),
	}


## 获取聚合器调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 聚合器状态快照。
## [br]
## @schema return: Dictionary，包含 total_progress、total_weight、task_count、is_complete、allow_decrease、tasks 和 progress。
func get_debug_snapshot() -> Dictionary:
	var task_snapshots: Array[Dictionary] = []
	for task_index: int in range(_tasks.size()):
		task_snapshots.append(get_task_snapshot(task_index))
	return {
		"total_progress": get_total_progress(),
		"total_weight": _get_total_weight(),
		"task_count": _tasks.size(),
		"is_complete": is_complete(),
		"allow_decrease": allow_decrease,
		"tasks": task_snapshots,
		"progress": _progress.get_debug_snapshot(),
	}


# --- 私有/辅助方法 ---

func _publish_task_progress(task_index: int, message: String) -> bool:
	var task: Dictionary = _tasks[task_index]
	return _publish_progress(message, {
		"event": &"task_progressed",
		"task_index": task_index,
		"task_key": _GF_REPORT_VALUE_CODEC_SCRIPT.to_json_compatible(GFVariantData.get_option_value(task, "key")),
		"task_progress": _get_task_progress(task),
		"task_weight": _get_task_weight(task),
		"task_metadata": GFVariantData.get_option_dictionary(task, "metadata"),
	})


func _publish_progress(message: String, metadata: Dictionary) -> bool:
	var progress_metadata: Dictionary = _make_progress_metadata(metadata)
	return _progress.update(get_total_progress(), message, progress_metadata)


func _make_progress_metadata(metadata: Dictionary) -> Dictionary:
	var result: Dictionary = metadata.duplicate(true)
	result["total_progress"] = get_total_progress()
	result["task_count"] = _tasks.size()
	result["total_weight"] = _get_total_weight()
	return result


func _get_total_weight() -> float:
	var total_weight: float = 0.0
	for task: Dictionary in _tasks:
		total_weight += _get_task_weight(task)
	return total_weight


func _get_task_weight(task: Dictionary) -> float:
	return maxf(GFVariantData.get_option_float(task, "weight"), 0.0)


func _get_task_progress(task: Dictionary) -> float:
	return clampf(GFVariantData.get_option_float(task, "progress"), 0.0, 1.0)


func _is_valid_task_index(task_index: int) -> bool:
	return task_index >= 0 and task_index < _tasks.size()


func _has_task_key(task_key: Variant) -> bool:
	return typeof(task_key) != TYPE_NIL


func _make_task_key_token(task_key: Variant) -> String:
	return _GF_VARIANT_KEY_CODEC_SCRIPT.make_key_token(task_key)


func _on_progressed(value: float, message: String, metadata: Dictionary) -> void:
	progressed.emit(value, message, metadata.duplicate(true))
