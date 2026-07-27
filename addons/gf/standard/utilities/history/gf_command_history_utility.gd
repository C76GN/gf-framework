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

## 命令历史栈的最大容量；为 0 时表示不限制。该上限分别约束撤销栈和重做栈。
## [br]
## @api public
## [br]
## @since 3.17.0
var max_history_size: int:
	get:
		return _max_history_size
	set(value):
		if _is_processing_history_operation:
			push_warning("[GFCommandHistoryUtility] 当前正在处理历史操作，忽略容量修改请求。")
			return
		_max_history_size = maxi(value, 0)
		_trim_history_stacks()

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

## 异步命令等待告警阈值（秒）。超过阈值只告警并继续持有历史锁，直到命令进入真实终态。
## [br]
## @api public
## [br]
## @since 8.0.0
var async_stall_warning_seconds: float = 30.0:
	set(value):
		if is_finite(value):
			async_stall_warning_seconds = maxf(value, 0.0)

## 当前是否正在处理一条异步命令的等待、终态判断或历史栈提交。
## [br]
## @api public
## [br]
## @since 3.17.0
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

var _is_processing_history_operation: bool = false
var _max_history_size: int = 1024
var _lifecycle_serial: int = 0
var _operation_serial: int = 0
var _active_operation_serial: int = 0
var _stall_warning_operation_serial: int = 0
var _stall_warning_tree: SceneTree = null
var _stall_warning_callback: Callable = Callable()


# --- GF 生命周期方法 ---

## 初始化命令历史并清空撤销、重做栈。
## [br]
## @api public
func init() -> void:
	_disconnect_stall_warning_observer()
	_lifecycle_serial += 1
	_undo_stack = []
	_redo_stack = []
	_is_processing_async = false
	_is_processing_history_operation = false
	_active_operation_serial = 0


## 释放命令历史并取消等待中的异步历史操作。
## [br]
## @api public
func dispose() -> void:
	_disconnect_stall_warning_observer()
	_lifecycle_serial += 1
	_undo_stack.clear()
	_redo_stack.clear()
	_is_processing_async = false
	_is_processing_history_operation = false
	_active_operation_serial = 0


# --- 公共方法 ---

## 注入当前架构并注册命令历史服务 capability。
## [br]
## @api framework_internal
## [br]
## @param architecture: 当前注册该工具的架构。
func inject_dependencies(architecture: GFArchitecture) -> void:
	super.inject_dependencies(architecture)
	if architecture != null:
		var _registered_history_service: bool = architecture.register_service(
			GFArchitecture.SERVICE_COMMAND_HISTORY_STORE,
			self
		)


## 记录一条已经执行完成的命令。
## [br]
## @api public
## [br]
## @param cmd: 已执行的命令实例。
func record(cmd: GFUndoableCommand) -> void:
	if not is_instance_valid(cmd):
		return
	if _is_processing_history_operation:
		_push_history_operation_rejection(
			"[GFCommandHistoryUtility] 当前正在处理异步命令，忽略新的历史记录。",
			"[GFCommandHistoryUtility] 当前正在处理历史操作，忽略新的历史记录。"
		)
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
	if _is_processing_history_operation:
		_push_history_operation_rejection(
			"[GFCommandHistoryUtility] 当前正在处理异步命令，忽略新的执行请求。",
			"[GFCommandHistoryUtility] 当前正在处理历史操作，忽略新的执行请求。"
		)
		return null

	var lifecycle_serial: int = _lifecycle_serial
	var operation_serial: int = _begin_history_operation()
	_inject_command_dependencies(cmd)
	if not _is_history_operation_current(operation_serial, lifecycle_serial):
		_finish_history_operation(operation_serial)
		return null

	var result: Variant = cmd.execute()
	if not _is_history_operation_current(operation_serial, lifecycle_serial):
		_finish_history_operation(operation_serial)
		return result
	if result is Signal:
		_is_processing_async = true
		var result_signal: Signal = result
		var wait_state: Dictionary = await _await_command_signal(
			result_signal,
			operation_serial,
			lifecycle_serial
		)
		if not _is_history_operation_current(operation_serial, lifecycle_serial):
			_finish_history_operation(operation_serial)
			return result
		if not GFVariantData.get_option_bool(wait_state, "completed"):
			_finish_history_operation(operation_serial)
			return result
	if not cmd.should_record(result):
		_finish_history_operation(operation_serial)
		return result
	if not _is_history_operation_current(operation_serial, lifecycle_serial):
		_finish_history_operation(operation_serial)
		return result
	_record_internal(cmd)
	_finish_history_operation(operation_serial)
	return result


## 撤销最后一条命令，并仅在结果 hook 成功时提交历史栈移动。
## `is_undo_successful()` 返回 `false` 时，命令保留在撤销栈原位置，重做栈不变。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 成功提交撤销历史时返回 `true`，否则返回 `false`。
func undo_last() -> bool:
	if _is_processing_history_operation or _undo_stack.is_empty():
		return false

	var lifecycle_serial: int = _lifecycle_serial
	var operation_serial: int = _begin_history_operation()
	var cmd: GFUndoableCommand = _undo_stack.back()
	_inject_command_dependencies(cmd)
	if not _is_history_operation_current(operation_serial, lifecycle_serial):
		_finish_history_operation(operation_serial)
		return false

	var result: Variant = cmd.undo()
	if not _is_history_operation_current(operation_serial, lifecycle_serial):
		_finish_history_operation(operation_serial)
		return false
	if result is Signal:
		push_warning("[GFCommandHistoryUtility] undo_last() 不支持异步命令，请使用 await undo_last_async()。")
		_finish_history_operation(operation_serial)
		return false
	return _complete_undo_operation(cmd, result, operation_serial, lifecycle_serial)


## 异步撤销最后一条命令，并仅在结果 hook 成功时提交历史栈移动。
## Signal 完成参数会规范化后传入 `is_undo_successful()`：无参数为 null，一个参数为该值，
## 两个至 16 个参数为保持发射顺序的 Array；超过 16 个时告警并只保留前 16 个。
## 结果 hook 返回 `false` 时，命令保留在撤销栈原位置，重做栈不变。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 成功提交撤销历史时返回 `true`，否则返回 `false`。
func undo_last_async() -> bool:
	if _is_processing_history_operation or _undo_stack.is_empty():
		return false

	var lifecycle_serial: int = _lifecycle_serial
	var operation_serial: int = _begin_history_operation()
	var cmd: GFUndoableCommand = _undo_stack.back()
	_inject_command_dependencies(cmd)
	if not _is_history_operation_current(operation_serial, lifecycle_serial):
		_finish_history_operation(operation_serial)
		return false

	var result: Variant = cmd.undo()
	if not _is_history_operation_current(operation_serial, lifecycle_serial):
		_finish_history_operation(operation_serial)
		return false
	if result is Signal:
		_is_processing_async = true
		var result_signal: Signal = result
		var wait_state: Dictionary = await _await_command_signal(
			result_signal,
			operation_serial,
			lifecycle_serial
		)
		if not _is_history_operation_current(operation_serial, lifecycle_serial):
			_finish_history_operation(operation_serial)
			return false
		if not GFVariantData.get_option_bool(wait_state, "completed"):
			_finish_history_operation(operation_serial)
			return false
		result = _normalize_signal_payload(GFVariantData.get_option_array(wait_state, "args"))
	return _complete_undo_operation(cmd, result, operation_serial, lifecycle_serial)


## 重做最近被撤销的命令，并仅在结果 hook 成功时提交历史栈移动。
## `is_redo_successful()` 返回 `false` 时，命令保留在重做栈原位置，撤销栈不变。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 成功提交重做历史时返回 `true`，否则返回 `false`。
func redo() -> bool:
	if _is_processing_history_operation or _redo_stack.is_empty():
		return false

	var lifecycle_serial: int = _lifecycle_serial
	var operation_serial: int = _begin_history_operation()
	var cmd: GFUndoableCommand = _redo_stack.back()
	_inject_command_dependencies(cmd)
	if not _is_history_operation_current(operation_serial, lifecycle_serial):
		_finish_history_operation(operation_serial)
		return false

	var result: Variant = cmd.execute()
	if not _is_history_operation_current(operation_serial, lifecycle_serial):
		_finish_history_operation(operation_serial)
		return false
	if result is Signal:
		push_warning("[GFCommandHistoryUtility] redo() 不支持异步命令，请使用 await redo_async()。")
		_finish_history_operation(operation_serial)
		return false
	return _complete_redo_operation(cmd, result, operation_serial, lifecycle_serial)


## 异步重做最近被撤销的命令，并仅在结果 hook 成功时提交历史栈移动。
## Signal 完成参数会规范化后传入 `is_redo_successful()`：无参数为 null，一个参数为该值，
## 两个至 16 个参数为保持发射顺序的 Array；超过 16 个时告警并只保留前 16 个。
## 结果 hook 返回 `false` 时，命令保留在重做栈原位置，撤销栈不变。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 成功提交重做历史时返回 `true`，否则返回 `false`。
func redo_async() -> bool:
	if _is_processing_history_operation or _redo_stack.is_empty():
		return false

	var lifecycle_serial: int = _lifecycle_serial
	var operation_serial: int = _begin_history_operation()
	var cmd: GFUndoableCommand = _redo_stack.back()
	_inject_command_dependencies(cmd)
	if not _is_history_operation_current(operation_serial, lifecycle_serial):
		_finish_history_operation(operation_serial)
		return false

	var result: Variant = cmd.execute()
	if not _is_history_operation_current(operation_serial, lifecycle_serial):
		_finish_history_operation(operation_serial)
		return false
	if result is Signal:
		_is_processing_async = true
		var result_signal: Signal = result
		var wait_state: Dictionary = await _await_command_signal(
			result_signal,
			operation_serial,
			lifecycle_serial
		)
		if not _is_history_operation_current(operation_serial, lifecycle_serial):
			_finish_history_operation(operation_serial)
			return false
		if not GFVariantData.get_option_bool(wait_state, "completed"):
			_finish_history_operation(operation_serial)
			return false
		result = _normalize_signal_payload(GFVariantData.get_option_array(wait_state, "args"))
	return _complete_redo_operation(cmd, result, operation_serial, lifecycle_serial)


## 清空所有历史记录。
## [br]
## @api public
func clear() -> void:
	if _is_processing_history_operation:
		_push_history_operation_rejection(
			"[GFCommandHistoryUtility] 当前正在处理异步命令，忽略清空请求。",
			"[GFCommandHistoryUtility] 当前正在处理历史操作，忽略清空请求。"
		)
		return

	_undo_stack.clear()
	_redo_stack.clear()


## 检查当前是否允许撤销。
## [br]
## @api public
## [br]
## @return 有可撤销命令时返回 `true`。
func can_undo() -> bool:
	return not _is_processing_history_operation and not _undo_stack.is_empty()


## 检查当前是否允许重做。
## [br]
## @api public
## [br]
## @return 有可重做命令时返回 `true`。
func can_redo() -> bool:
	return not _is_processing_history_operation and not _redo_stack.is_empty()


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
	if _is_processing_history_operation:
		_push_history_operation_rejection(
			"[GFCommandHistoryUtility] 当前正在处理异步命令，忽略历史恢复请求。",
			"[GFCommandHistoryUtility] 当前正在处理历史操作，忽略历史恢复请求。"
		)
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
	_trim_history_stacks()


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
	if _is_processing_history_operation:
		_push_history_operation_rejection(
			"[GFCommandHistoryUtility] 当前正在处理异步命令，忽略完整历史恢复请求。",
			"[GFCommandHistoryUtility] 当前正在处理历史操作，忽略完整历史恢复请求。"
		)
		return

	_undo_stack.clear()
	_redo_stack.clear()

	if not command_builder.is_valid():
		push_error("[GFCommandHistoryUtility] deserialize_full_history 失败：传入的 builder Callable 无效。")
		return

	_undo_stack = _deserialize_stack(GFVariantData.get_option_array(data, "undo"), command_builder)
	_redo_stack = _deserialize_stack(GFVariantData.get_option_array(data, "redo"), command_builder)
	_trim_history_stacks()


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


func _trim_redo_stack() -> void:
	if max_history_size <= 0 or _redo_stack.size() <= max_history_size:
		return

	var overflow: int = _redo_stack.size() - max_history_size
	_redo_stack = _redo_stack.slice(overflow)


func _trim_history_stacks() -> void:
	_trim_undo_stack()
	_trim_redo_stack()


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


func _begin_history_operation() -> int:
	_operation_serial += 1
	_active_operation_serial = _operation_serial
	_is_processing_history_operation = true
	return _active_operation_serial


func _push_history_operation_rejection(async_message: String, sync_message: String) -> void:
	push_warning(async_message if _is_processing_async else sync_message)


func _is_history_operation_current(operation_serial: int, lifecycle_serial: int) -> bool:
	return (
		_is_processing_history_operation
		and _active_operation_serial == operation_serial
		and _lifecycle_serial == lifecycle_serial
	)


func _finish_history_operation(operation_serial: int) -> void:
	if _active_operation_serial != operation_serial:
		return
	_disconnect_stall_warning_observer(operation_serial)
	_active_operation_serial = 0
	_is_processing_history_operation = false
	_is_processing_async = false


func _complete_undo_operation(
	cmd: GFUndoableCommand,
	result: Variant,
	operation_serial: int,
	lifecycle_serial: int
) -> bool:
	var successful: bool = cmd.is_undo_successful(result)
	if not _is_history_operation_current(operation_serial, lifecycle_serial):
		_finish_history_operation(operation_serial)
		return false
	if not successful:
		_finish_history_operation(operation_serial)
		return false
	var committed_cmd: GFUndoableCommand = _pop_expected_history_top(_undo_stack, cmd, "撤销")
	if committed_cmd == null:
		_finish_history_operation(operation_serial)
		return false
	_redo_stack.push_back(committed_cmd)
	_trim_redo_stack()
	_finish_history_operation(operation_serial)
	return true


func _complete_redo_operation(
	cmd: GFUndoableCommand,
	result: Variant,
	operation_serial: int,
	lifecycle_serial: int
) -> bool:
	var successful: bool = cmd.is_redo_successful(result)
	if not _is_history_operation_current(operation_serial, lifecycle_serial):
		_finish_history_operation(operation_serial)
		return false
	if not successful:
		_finish_history_operation(operation_serial)
		return false
	var committed_cmd: GFUndoableCommand = _pop_expected_history_top(_redo_stack, cmd, "重做")
	if committed_cmd == null:
		_finish_history_operation(operation_serial)
		return false
	_undo_stack.push_back(committed_cmd)
	_trim_undo_stack()
	_finish_history_operation(operation_serial)
	return true


func _pop_expected_history_top(
	source_stack: Array[GFUndoableCommand],
	expected_cmd: GFUndoableCommand,
	operation_name: String
) -> GFUndoableCommand:
	if source_stack.is_empty() or not is_same(source_stack.back(), expected_cmd):
		push_error(
			"[GFCommandHistoryUtility] %s提交失败：来源栈顶身份已变化。" % operation_name
		)
		return null
	return source_stack.pop_back()


func _await_command_signal(
	result_signal: Signal,
	operation_serial: int,
	lifecycle_serial: int
) -> Dictionary:
	if result_signal.is_null():
		return {
			"completed": true,
			"args": [],
		}

	_start_async_stall_warning_observer(operation_serial, lifecycle_serial)
	var should_continue: Callable = func() -> bool:
		return _is_history_operation_current(operation_serial, lifecycle_serial)
	return await _GF_ASYNC_WAIT_SUPPORT.await_signal_state(result_signal, {
		"capture_payload": true,
		"should_continue": should_continue,
		"timeout_seconds": 0.0,
	})


func _start_async_stall_warning_observer(operation_serial: int, lifecycle_serial: int) -> void:
	_disconnect_stall_warning_observer()
	var warning_seconds: float = async_stall_warning_seconds
	if warning_seconds <= 0.0:
		return
	var main_loop: MainLoop = Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return
	var scene_tree: SceneTree = main_loop
	var warning_msec: int = maxi(ceili(warning_seconds * 1000.0), 1)
	var start_msec: int = Time.get_ticks_msec()
	var on_process_frame: Callable = func() -> void:
		if not _is_history_operation_current(operation_serial, lifecycle_serial):
			_disconnect_stall_warning_observer(operation_serial)
			return
		if Time.get_ticks_msec() - start_msec < warning_msec:
			return
		push_warning("[GFCommandHistoryUtility] 异步命令尚未完成；历史锁将保持到真实终态。")
		_disconnect_stall_warning_observer(operation_serial)
	_stall_warning_operation_serial = operation_serial
	_stall_warning_tree = scene_tree
	_stall_warning_callback = on_process_frame
	var connect_result: Error = scene_tree.process_frame.connect(on_process_frame) as Error
	if connect_result != OK:
		_stall_warning_operation_serial = 0
		_stall_warning_tree = null
		_stall_warning_callback = Callable()


func _disconnect_stall_warning_observer(operation_serial: int = 0) -> void:
	if operation_serial > 0 and _stall_warning_operation_serial != operation_serial:
		return
	if (
		_stall_warning_tree != null
		and _stall_warning_callback.is_valid()
		and _stall_warning_tree.process_frame.is_connected(_stall_warning_callback)
	):
		_stall_warning_tree.process_frame.disconnect(_stall_warning_callback)
	_stall_warning_operation_serial = 0
	_stall_warning_tree = null
	_stall_warning_callback = Callable()


func _normalize_signal_payload(args: Array) -> Variant:
	match args.size():
		0:
			return null
		1:
			return args[0]
		_:
			return args.duplicate(true)


func _build_command(command_builder: Callable, command_data: Dictionary) -> GFUndoableCommand:
	var command: Variant = command_builder.call(command_data)
	if command is GFUndoableCommand:
		var undoable_command: GFUndoableCommand = command
		return undoable_command
	return null
