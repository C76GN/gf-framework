## GFCommandHistoryUtility: 可撤销命令历史管理器。
##
## 负责维护 `GFUndoableCommand` 的撤销栈与重做栈，
## 并提供同步/异步重放与历史序列化能力。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFCommandHistoryUtility
extends GFUtility


# --- 常量 ---

const _GF_ASYNC_WAIT_SUPPORT = preload("res://addons/gf/standard/common/gf_async_wait_support.gd")


# --- 公共变量 ---

## 撤销栈的最大容量；为 0 时表示不限制。
## [br]
## @api public
var max_history_size: int:
	get:
		return _max_history_size
	set(value):
		_max_history_size = maxi(value, 0)
		_trim_undo_stack()

## 当前撤销栈深度。
## [br]
## @api public
var undo_count: int:
	get:
		return _undo_stack.size()

## 当前重做栈深度。
## [br]
## @api public
var redo_count: int:
	get:
		return _redo_stack.size()

## 异步命令等待超时时间（秒）。小于等于 0 时表示不启用超时。
## [br]
## @api public
var async_timeout_seconds: float = 30.0

## 当前是否正在等待一条异步命令完成。
## [br]
## @api public
var is_processing_async: bool:
	get:
		return _is_processing_async


# --- 私有变量 ---

# 已执行命令的撤销栈。
var _undo_stack: Array[GFUndoableCommand] = []

# 已撤销命令的重做栈。
var _redo_stack: Array[GFUndoableCommand] = []

# 当前是否正在等待一条异步命令完成。
var _is_processing_async: bool = false

var _max_history_size: int = 1024
var _lifecycle_serial: int = 0


# --- GF 生命周期方法 ---

## 初始化命令历史并清空撤销、重做栈。
## [br]
## @api public
func init() -> void:
	_lifecycle_serial += 1
	_undo_stack = []
	_redo_stack = []
	_is_processing_async = false


## 释放命令历史并取消等待中的异步历史操作。
## [br]
## @api public
func dispose() -> void:
	_lifecycle_serial += 1
	_undo_stack.clear()
	_redo_stack.clear()
	_is_processing_async = false


# --- 公共方法 ---

## 记录一条已经执行完成的命令。
## [br]
## @api public
## [br]
## @param cmd: 已执行的命令实例。
func record(cmd: GFUndoableCommand) -> void:
	if not is_instance_valid(cmd):
		return
	if _is_processing_async:
		push_warning("[GFCommandHistoryUtility] 当前正在处理异步命令，忽略新的历史记录。")
		return

	_inject_command_dependencies(cmd)
	_record_internal(cmd)


## 执行命令并自动记录到撤销栈。
## [br]
## @api public
## [br]
## @param cmd: 要执行的命令实例。
## [br]
## @return `execute()` 的原始返回值；异步命令可由调用方自行 `await`。
## [br]
## @schema return: Variant returned by GFUndoableCommand.execute(), including null or Signal.
func execute_command(cmd: GFUndoableCommand) -> Variant:
	if not is_instance_valid(cmd):
		return null
	if _is_processing_async:
		push_warning("[GFCommandHistoryUtility] 当前正在处理异步命令，忽略新的执行请求。")
		return null

	_inject_command_dependencies(cmd)
	var result: Variant = cmd.execute()
	if result is Signal:
		_is_processing_async = true
		var current_serial: int = _lifecycle_serial
		var result_signal: Signal = result
		var completed: bool = await _await_command_signal(result_signal, current_serial)
		if current_serial != _lifecycle_serial:
			return result
		_is_processing_async = false
		if not completed:
			return result
	if not cmd.should_record(result):
		return result
	_record_internal(cmd)
	return result


## 撤销最后一条命令。
## [br]
## @api public
## [br]
## @return 成功撤销时返回 `true`。
func undo_last() -> bool:
	if _is_processing_async or _undo_stack.is_empty():
		return false

	var cmd: GFUndoableCommand = _undo_stack.pop_back()
	_inject_command_dependencies(cmd)
	var result: Variant = cmd.undo()
	if result is Signal:
		push_warning("[GFCommandHistoryUtility] undo_last() 不支持异步命令，请使用 await undo_last_async()。")
		_undo_stack.push_back(cmd)
		return false

	_redo_stack.push_back(cmd)
	return true


## 异步撤销最后一条命令。
## [br]
## @api public
## [br]
## @return 成功撤销时返回 `true`。
func undo_last_async() -> bool:
	if _is_processing_async or _undo_stack.is_empty():
		return false

	var cmd: GFUndoableCommand = _undo_stack.pop_back()
	_inject_command_dependencies(cmd)
	var result: Variant = cmd.undo()
	if result is Signal:
		_is_processing_async = true
		var current_serial: int = _lifecycle_serial
		var result_signal: Signal = result
		var completed: bool = await _await_command_signal(result_signal, current_serial)
		if current_serial != _lifecycle_serial:
			return false
		_is_processing_async = false
		if not completed:
			_undo_stack.push_back(cmd)
			return false

	_redo_stack.push_back(cmd)
	return true


## 重做最近被撤销的命令。
## [br]
## @api public
## [br]
## @return 成功重做时返回 `true`。
func redo() -> bool:
	if _is_processing_async or _redo_stack.is_empty():
		return false

	var cmd: GFUndoableCommand = _redo_stack.pop_back()
	_inject_command_dependencies(cmd)
	var result: Variant = cmd.execute()
	if result is Signal:
		push_warning("[GFCommandHistoryUtility] redo() 不支持异步命令，请使用 await redo_async()。")
		_redo_stack.push_back(cmd)
		return false

	_undo_stack.push_back(cmd)
	return true


## 异步重做最近被撤销的命令。
## [br]
## @api public
## [br]
## @return 成功重做时返回 `true`。
func redo_async() -> bool:
	if _is_processing_async or _redo_stack.is_empty():
		return false

	var cmd: GFUndoableCommand = _redo_stack.pop_back()
	_inject_command_dependencies(cmd)
	var result: Variant = cmd.execute()
	if result is Signal:
		_is_processing_async = true
		var current_serial: int = _lifecycle_serial
		var result_signal: Signal = result
		var completed: bool = await _await_command_signal(result_signal, current_serial)
		if current_serial != _lifecycle_serial:
			return false
		_is_processing_async = false
		if not completed:
			_redo_stack.push_back(cmd)
			return false

	_undo_stack.push_back(cmd)
	return true


## 清空所有历史记录。
## [br]
## @api public
func clear() -> void:
	if _is_processing_async:
		push_warning("[GFCommandHistoryUtility] 当前正在处理异步命令，忽略清空请求。")
		return

	_undo_stack.clear()
	_redo_stack.clear()


## 检查当前是否允许撤销。
## [br]
## @api public
## [br]
## @return 有可撤销命令时返回 `true`。
func can_undo() -> bool:
	return not _is_processing_async and not _undo_stack.is_empty()


## 检查当前是否允许重做。
## [br]
## @api public
## [br]
## @return 有可重做命令时返回 `true`。
func can_redo() -> bool:
	return not _is_processing_async and not _redo_stack.is_empty()


## 获取撤销栈副本。
## [br]
## @api public
## [br]
## @return 撤销历史的浅拷贝。
func get_undo_history() -> Array[GFUndoableCommand]:
	return _undo_stack.duplicate()


## 获取重做栈副本。
## [br]
## @api public
## [br]
## @return 重做历史的浅拷贝。
func get_redo_history() -> Array[GFUndoableCommand]:
	return _redo_stack.duplicate()


## 将撤销栈序列化为纯数据数组。
## [br]
## @api public
## [br]
## @return 适合持久化的历史数据。
## [br]
## @schema return: Array[Dictionary] serialized command snapshots produced by command serialize() or get_snapshot().
func serialize_history() -> Array[Dictionary]:
	return _serialize_stack(_undo_stack)


## 将完整命令历史序列化为纯数据字典。
## 包含 `undo` 与 `redo` 两个栈，可用于全量运行时快照恢复。
## [br]
## @api public
## [br]
## @return 适合持久化的完整历史数据。
## [br]
## @schema return: Dictionary with undo and redo Array[Dictionary] stacks.
func serialize_full_history() -> Dictionary:
	return {
		"undo": _serialize_stack(_undo_stack),
		"redo": _serialize_stack(_redo_stack),
	}


## 通过构造器从纯数据恢复撤销栈。
## [br]
## @api public
## [br]
## @param data_array: 历史数据数组。
## [br]
## @schema data_array: Array[Dictionary] serialized command snapshots produced by serialize_history().
## [br]
## @param command_builder: 负责反序列化命令实例的构造器。
func deserialize_history(data_array: Array, command_builder: Callable) -> void:
	if _is_processing_async:
		push_warning("[GFCommandHistoryUtility] 当前正在处理异步命令，忽略历史恢复请求。")
		return

	_undo_stack.clear()
	_redo_stack.clear()

	if not command_builder.is_valid():
		push_error("[GFCommandHistoryUtility] deserialize_history 失败：传入的 builder Callable 无效。")
		return

	for data: Variant in data_array:
		if data is Dictionary:
			var command_data: Dictionary = data
			var restored_cmd: GFUndoableCommand = _build_command(command_builder, command_data)
			if is_instance_valid(restored_cmd):
				_inject_command_dependencies(restored_cmd)
				_undo_stack.append(restored_cmd)


## 通过构造器从完整历史数据恢复撤销栈与重做栈。
## [br]
## @api public
## [br]
## @param data: 由 `serialize_full_history()` 生成的字典数据。
## [br]
## @schema data: Dictionary with undo and redo Array[Dictionary] stacks.
## [br]
## @param command_builder: 负责反序列化命令实例的构造器。
func deserialize_full_history(data: Dictionary, command_builder: Callable) -> void:
	if _is_processing_async:
		push_warning("[GFCommandHistoryUtility] 当前正在处理异步命令，忽略完整历史恢复请求。")
		return

	_undo_stack.clear()
	_redo_stack.clear()

	if not command_builder.is_valid():
		push_error("[GFCommandHistoryUtility] deserialize_full_history 失败：传入的 builder Callable 无效。")
		return

	_undo_stack = _deserialize_stack(GFVariantData.get_option_array(data, "undo"), command_builder)
	_redo_stack = _deserialize_stack(GFVariantData.get_option_array(data, "redo"), command_builder)


# --- 私有/辅助方法 ---

func _record_internal(cmd: GFUndoableCommand) -> void:
	_undo_stack.push_back(cmd)
	_redo_stack.clear()

	_trim_undo_stack()


func _trim_undo_stack() -> void:
	if max_history_size <= 0 or _undo_stack.size() <= max_history_size:
		return

	var overflow: int = _undo_stack.size() - max_history_size
	_undo_stack = _undo_stack.slice(overflow)


func _serialize_stack(stack: Array[GFUndoableCommand]) -> Array[Dictionary]:
	var arr: Array[Dictionary] = []
	for cmd: GFUndoableCommand in stack:
		if cmd.has_method("serialize"):
			arr.append(GFVariantData.to_dictionary(cmd.call("serialize")))
		else:
			arr.append({ "snapshot": GFVariantData.duplicate_variant(cmd.get_snapshot()) })

	return arr


func _deserialize_stack(data_array: Array, command_builder: Callable) -> Array[GFUndoableCommand]:
	var restored_stack: Array[GFUndoableCommand] = []

	for data: Variant in data_array:
		if not (data is Dictionary):
			continue

		var command_data: Dictionary = data
		var restored_cmd: GFUndoableCommand = _build_command(command_builder, command_data)
		if is_instance_valid(restored_cmd):
			_inject_command_dependencies(restored_cmd)
			restored_stack.append(restored_cmd)

	return restored_stack


func _inject_command_dependencies(cmd: GFUndoableCommand) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return
	if cmd.has_method("inject_dependencies"):
		cmd.call("inject_dependencies", architecture)
	if cmd.has_method("inject"):
		cmd.call("inject", architecture)


func _await_command_signal(result_signal: Signal, lifecycle_serial: int) -> bool:
	if result_signal.is_null():
		return true

	var target_obj: Object = result_signal.get_object()
	if not is_instance_valid(target_obj):
		return false

	var completed: Array[bool] = [false]
	var on_resume: Callable = func(
		_arg1: Variant = null,
		_arg2: Variant = null,
		_arg3: Variant = null,
		_arg4: Variant = null
	) -> void:
		completed[0] = true

	var _connect_result_446: Variant = result_signal.connect(
		on_resume,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	)

	var timeout_msec: int = int(async_timeout_seconds * 1000.0)
	var start_msec: int = Time.get_ticks_msec()

	while not completed[0]:
		if lifecycle_serial != _lifecycle_serial:
			break
		if not is_instance_valid(target_obj):
			break
		if timeout_msec > 0 and Time.get_ticks_msec() - start_msec >= timeout_msec:
			push_warning("[GFCommandHistoryUtility] 等待异步命令超时，历史操作已取消。")
			break
		var main_loop: MainLoop = Engine.get_main_loop()
		if not (main_loop is SceneTree):
			break
		var scene_tree: SceneTree = main_loop
		await scene_tree.process_frame

	_GF_ASYNC_WAIT_SUPPORT.disconnect_signal_if_connected(result_signal, on_resume)
	return completed[0] and lifecycle_serial == _lifecycle_serial


func _build_command(command_builder: Callable, command_data: Dictionary) -> GFUndoableCommand:
	var command: Variant = command_builder.call(command_data)
	if command is GFUndoableCommand:
		var undoable_command: GFUndoableCommand = command
		return undoable_command
	return null
