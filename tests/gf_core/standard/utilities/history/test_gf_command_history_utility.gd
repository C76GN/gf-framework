## 测试 GFCommandHistoryUtility 的记录、撤销、重做与序列化行为。
extends GutTest


# --- 私有变量 ---

var _history: GFCommandHistoryUtility


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_history = GFCommandHistoryUtility.new()
	_history.init()


func after_each() -> void:
	_history = null


# --- 测试：record ---

func test_undoable_command_default_action_name_is_empty() -> void:
	var cmd: GFUndoableCommand = GFUndoableCommand.new()

	assert_eq(cmd.action_name, "", "可撤销命令默认不应生成历史面板展示文案。")


## 验证 record 后 undo_count 自增。
func test_record_increases_undo_count() -> void:
	var counter: CounterState = CounterState.new()
	var cmd: CounterCommand = CounterCommand.new(counter)
	cmd.execute()
	_history.record(cmd)

	assert_eq(_history.undo_count, 1, "record 后撤销栈应有一条记录。")


## 验证 record 后 redo_count 归零（新操作打断重做分支）。
func test_record_clears_redo_stack() -> void:
	var counter: CounterState = CounterState.new()
	var cmd1: CounterCommand = CounterCommand.new(counter)
	cmd1.execute()
	_history.record(cmd1)

	var _undo_last_result_46: Variant = _history.undo_last()
	assert_eq(_history.redo_count, 1, "撤销后重做栈应有一条。")

	var cmd2: CounterCommand = CounterCommand.new(counter)
	cmd2.execute()
	_history.record(cmd2)

	assert_eq(_history.redo_count, 0, "record 新命令后重做栈应被清空。")


## 验证 execute_command 会执行命令并自动记录到撤销栈。
func test_execute_command_executes_and_records() -> void:
	var counter: CounterState = CounterState.new()
	var cmd: CounterCommand = CounterCommand.new(counter)

	await _history.execute_command(cmd)

	assert_eq(counter.value, 1, "execute_command 应先执行命令。")
	assert_eq(_history.undo_count, 1, "execute_command 后应自动记录到撤销栈。")


func test_execute_command_injects_history_architecture() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	_history.inject_dependencies(arch)

	var cmd: InjectedHistoryCommand = InjectedHistoryCommand.new()
	await _history.execute_command(cmd)

	assert_eq(cmd.injected_architecture, arch, "History 执行命令时应注入自身所属架构。")
	arch.dispose()


func test_execute_command_can_skip_history_recording() -> void:
	var cmd: ConditionalRecordCommand = ConditionalRecordCommand.new(false)

	var result: Variant = await _history.execute_command(cmd)

	assert_eq(GFVariantData.to_int(result), 1, "execute_command 应返回命令原始结果。")
	assert_eq(cmd.execute_count, 1, "跳过记录不应跳过命令执行。")
	assert_eq(_history.undo_count, 0, "should_record 返回 false 时不应写入撤销栈。")


# --- 测试：undo_last ---

## 验证 undo_last 调用命令的 undo() 并恢复状态。
func test_execute_command_async_records_after_completion() -> void:
	var counter: CounterState = CounterState.new()
	var cmd: AsyncCounterCommand = AsyncCounterCommand.new(counter, 5, 0)

	@warning_ignore("missing_await")
	_history.execute_command(cmd)
	assert_eq(_history.undo_count, 0, "异步命令完成前，不应提前写入撤销栈。")

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(counter.value, 5, "异步 execute 完成后应更新状态。")
	assert_eq(_history.undo_count, 1, "异步命令完成后才应写入撤销栈。")


func test_undo_last_restores_state() -> void:
	var counter: CounterState = CounterState.new()
	var cmd: CounterCommand = CounterCommand.new(counter)
	cmd.execute()
	_history.record(cmd)

	assert_eq(counter.value, 1, "execute 后 value 应为 1。")

	var _undo_last_result_114: Variant = _history.undo_last()
	assert_eq(counter.value, 0, "undo_last 后 value 应恢复为 0。")


## 验证 undo_last 将命令压入重做栈。
func test_undo_last_moves_to_redo_stack() -> void:
	var counter: CounterState = CounterState.new()
	var cmd: CounterCommand = CounterCommand.new(counter)
	cmd.execute()
	_history.record(cmd)
	var _undo_last_result_124: Variant = _history.undo_last()

	assert_eq(_history.redo_count, 1, "undo_last 后重做栈应有一条。")
	assert_eq(_history.undo_count, 0, "undo_last 后撤销栈应为空。")


## 验证撤销栈为空时 undo_last 返回 false 且不崩溃。
func test_undo_last_empty_stack_returns_false() -> void:
	var result: bool = _history.undo_last()
	assert_false(result, "空栈时 undo_last 应返回 false。")


## 验证同步 undo 遇到异步命令时会回滚撤销栈并提示使用异步接口。
func test_undo_last_rejects_async_command_and_restores_stack() -> void:
	var cmd: ManualAsyncCommand = ManualAsyncCommand.new()
	_history.record(cmd)

	var result: bool = _history.undo_last()

	assert_false(result, "同步 undo_last 不应接受异步命令。")
	assert_true(cmd.undo_called, "同步 undo_last 应调用命令以识别返回值。")
	assert_eq(_history.undo_count, 1, "异步命令被拒绝后应放回撤销栈。")
	assert_eq(_history.redo_count, 0, "异步命令被拒绝后不应进入重做栈。")
	assert_push_warning("[GFCommandHistoryUtility] undo_last() 不支持异步命令，请使用 await undo_last_async()。")


# --- 测试：redo ---

## 验证 redo 重新执行被撤销的命令。
func test_redo_reapplies_command() -> void:
	var counter: CounterState = CounterState.new()
	var cmd: CounterCommand = CounterCommand.new(counter)
	cmd.execute()
	_history.record(cmd)
	var _undo_last_result_158: Variant = _history.undo_last()

	assert_eq(counter.value, 0, "undo 后 value 应为 0。")

	var _redo_result_162: Variant = _history.redo()
	assert_eq(counter.value, 1, "redo 后 value 应恢复为 1。")


## 验证 redo 后命令重回撤销栈。
func test_redo_moves_back_to_undo_stack() -> void:
	var counter: CounterState = CounterState.new()
	var cmd: CounterCommand = CounterCommand.new(counter)
	cmd.execute()
	_history.record(cmd)
	var _undo_last_result_172: Variant = _history.undo_last()
	var _redo_result_173: Variant = _history.redo()

	assert_eq(_history.undo_count, 1, "redo 后撤销栈应有一条。")
	assert_eq(_history.redo_count, 0, "redo 后重做栈应为空。")


## 验证重做栈为空时 redo 返回 false 且不崩溃。
func test_redo_empty_stack_returns_false() -> void:
	var result: bool = _history.redo()
	assert_false(result, "空栈时 redo 应返回 false。")


## 验证同步 redo 遇到异步命令时会回滚重做栈并提示使用异步接口。
func test_redo_rejects_async_command_and_restores_stack() -> void:
	var counter: CounterState = CounterState.new()
	var cmd: AsyncCounterCommand = AsyncCounterCommand.new(counter, 5, 0)
	_history.record(cmd)
	await _history.undo_last_async()

	var result: bool = _history.redo()

	assert_false(result, "同步 redo 不应接受异步命令。")
	assert_eq(_history.undo_count, 0, "异步 redo 被拒绝后不应进入撤销栈。")
	assert_eq(_history.redo_count, 1, "异步 redo 被拒绝后应放回重做栈。")
	assert_push_warning("[GFCommandHistoryUtility] redo() 不支持异步命令，请使用 await redo_async()。")


## 验证 undo_last_async 会等待异步撤销命令完成后再移动到重做栈。
func test_undo_last_async_awaits_async_command() -> void:
	var counter: CounterState = CounterState.new(10)
	var cmd: AsyncCounterCommand = AsyncCounterCommand.new(counter, 20, 0)
	_history.record(cmd)

	var result: bool = await _history.undo_last_async()

	assert_true(result, "异步撤销完成后应返回 true。")
	assert_eq(counter.value, 0, "异步 undo 完成后应恢复指定值。")
	assert_eq(_history.redo_count, 1, "异步 undo 完成后应推入重做栈。")


## 验证异步撤销过程中不会允许第二次撤销污染栈顺序。
func test_undo_last_async_blocks_reentrant_history_mutation() -> void:
	var first_cmd: CounterCommand = CounterCommand.new(CounterState.new())
	var second_cmd: ManualAsyncCommand = ManualAsyncCommand.new()
	_history.record(first_cmd)
	_history.record(second_cmd)

	@warning_ignore("missing_await")
	@warning_ignore("return_value_discarded")
	_history.undo_last_async()
	await get_tree().process_frame

	var sync_result: bool = _history.undo_last()

	assert_true(second_cmd.undo_called, "第一条异步 undo 应已开始执行。")
	assert_false(sync_result, "异步 undo 未完成时，同步 undo 应被拒绝。")
	assert_eq(_history.undo_count, 1, "被锁保护期间不应继续弹出更早的命令。")

	second_cmd.complete()
	await get_tree().process_frame

	assert_eq(_history.redo_count, 1, "异步 undo 完成后才应写入 redo 栈。")


func test_async_stall_warning_keeps_history_locked_until_late_completion() -> void:
	var cmd: ManualAsyncCommand = ManualAsyncCommand.new()
	_history.async_stall_warning_seconds = 0.001
	_history.record(cmd)

	@warning_ignore("missing_await")
	@warning_ignore("return_value_discarded")
	_history.undo_last_async()
	for _frame: int in range(5):
		await get_tree().process_frame

	assert_true(_history.is_processing_async, "告警阈值不能被当成异步命令终态。")
	assert_eq(_history.undo_count, 0, "命令等待期间不得提前放回 undo 栈。")
	assert_eq(_history.redo_count, 0, "命令等待期间不得提前写入 redo 栈。")
	_history.record(CounterCommand.new(CounterState.new()))
	assert_eq(_history.undo_count, 0, "迟到完成前新的历史 mutation 必须继续被锁拒绝。")

	cmd.complete()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(_history.is_processing_async, "真实完成后应释放历史锁。")
	assert_eq(_history.redo_count, 1, "迟到完成后命令应只进入正确的 redo 栈。")
	assert_push_warning("[GFCommandHistoryUtility] 异步命令尚未完成；历史锁将保持到真实终态。")
	assert_push_warning("[GFCommandHistoryUtility] 当前正在处理异步命令，忽略新的历史记录。")


func test_dispose_cancels_pending_async_history_operation() -> void:
	var cmd: ManualAsyncCommand = ManualAsyncCommand.new()

	@warning_ignore("missing_await")
	_history.execute_command(cmd)
	await get_tree().process_frame
	assert_true(_history.is_processing_async, "异步命令未完成时应进入处理锁。")

	_history.dispose()
	cmd.complete()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(_history.is_processing_async, "dispose 应解除异步处理锁。")
	assert_eq(_history.undo_count, 0, "dispose 后旧异步命令完成不应写入历史。")


## 验证 redo_async 会等待异步执行命令完成后再移动回撤销栈。
func test_redo_async_awaits_async_command() -> void:
	var counter: CounterState = CounterState.new()
	var cmd: AsyncCounterCommand = AsyncCounterCommand.new(counter, 20, 0)
	_history.record(cmd)
	await _history.undo_last_async()

	var result: bool = await _history.redo_async()

	assert_true(result, "异步重做完成后应返回 true。")
	assert_eq(counter.value, 20, "异步 redo 完成后应应用指定值。")
	assert_eq(_history.undo_count, 1, "异步 redo 完成后应推回撤销栈。")


# --- 测试：clear 与辅助方法 ---

## 验证 clear 清空两个栈。
func test_clear_empties_both_stacks() -> void:
	var counter: CounterState = CounterState.new()
	var cmd: CounterCommand = CounterCommand.new(counter)
	cmd.execute()
	_history.record(cmd)
	var _undo_last_result_275: Variant = _history.undo_last()

	_history.clear()

	assert_eq(_history.undo_count, 0, "clear 后撤销栈应为空。")
	assert_eq(_history.redo_count, 0, "clear 后重做栈应为空。")


## 验证 can_undo 与 can_redo 的返回值。
func test_can_undo_and_can_redo() -> void:
	assert_false(_history.can_undo(), "初始时 can_undo 应为 false。")
	assert_false(_history.can_redo(), "初始时 can_redo 应为 false。")

	var counter: CounterState = CounterState.new()
	var cmd: CounterCommand = CounterCommand.new(counter)
	cmd.execute()
	_history.record(cmd)

	assert_true(_history.can_undo(), "record 后 can_undo 应为 true。")
	assert_false(_history.can_redo(), "record 后 can_redo 应为 false。")

	var _undo_last_result_296: Variant = _history.undo_last()
	assert_false(_history.can_undo(), "undo 后 can_undo 应为 false。")
	assert_true(_history.can_redo(), "undo 后 can_redo 应为 true。")


## 验证 get_undo_history 和 get_redo_history 返回的数组及元素正确，且原栈不受外部修改影响。
func test_get_history_methods() -> void:
	var counter: CounterState = CounterState.new()
	var cmd1: CounterCommand = CounterCommand.new(counter)
	var cmd2: CounterCommand = CounterCommand.new(counter)
	cmd1.action_name = "动作1"
	cmd2.action_name = "动作2"

	cmd1.execute()
	_history.record(cmd1)
	cmd2.execute()
	_history.record(cmd2)

	var _undo_last_result_314: Variant = _history.undo_last()

	var undo_history: Array[GFUndoableCommand] = _history.get_undo_history()
	var redo_history: Array[GFUndoableCommand] = _history.get_redo_history()

	assert_eq(undo_history.size(), 1, "撤销历史应有 1 个元素。")
	assert_eq(undo_history[0].action_name, "动作1", "撤销历史的命令描述应正确。")

	assert_eq(redo_history.size(), 1, "重做历史应有 1 个元素。")
	assert_eq(redo_history[0].action_name, "动作2", "重做历史的命令描述应正确。")

	undo_history.clear()
	redo_history.clear()

	assert_eq(_history.undo_count, 1, "返回的原撤销栈的拷贝被清空，不应影响内部撤销栈。")
	assert_eq(_history.redo_count, 1, "返回的原重做栈的拷贝被清空，不应影响内部重做栈。")


# --- 测试：持久化与上限 ---

## 验证 serialize_history 能够提取正确的快照信息。
func test_serialize_history() -> void:
	var counter: CounterState = CounterState.new()
	var cmd1: CounterCommand = CounterCommand.new(counter)
	var cmd2: CounterCommand = CounterCommand.new(counter)

	cmd1.execute()
	_history.record(cmd1)
	cmd2.execute()
	_history.record(cmd2)

	var data_array: Array[Dictionary] = _history.serialize_history()
	var first_record: Dictionary = data_array[0]
	var second_record: Dictionary = data_array[1]
	assert_eq(data_array.size(), 2, "序列化后的数据长度应为2。")
	assert_eq(GFVariantData.get_option_int(first_record, "snapshot"), 0, "第一个快照值应正确。")
	assert_eq(GFVariantData.get_option_int(second_record, "snapshot"), 1, "第二个快照值应正确。")


## 验证 deserialize_history 能够正确通过构造器恢复栈。
func test_deserialize_history() -> void:
	var counter: CounterState = CounterState.new()
	var builder: Callable = func(data: Dictionary) -> GFUndoableCommand:
		var command: CounterCommand = CounterCommand.new(counter)
		var _snapshot_saved: bool = command.set_snapshot(GFVariantData.get_option_value(data, "snapshot", 0))
		return command

	var src_data: Array[Dictionary] = [{ "snapshot": 5 }, { "snapshot": 6 }]
	_history.deserialize_history(src_data, builder)

	assert_eq(_history.undo_count, 2, "撤销栈应恢复2条。")
	var _undo_last_result_365: Variant = _history.undo_last()
	assert_eq(counter.value, 6, "反序列化后的命令能正常提取之前快照执行 undo。")
	assert_eq(_history.redo_count, 1, "撤销后正常推入重做栈。")


## 验证 max_history_size 超限清理 (FIFO抛弃)。
func test_serialize_full_history_roundtrip() -> void:
	var cmd1: GFUndoableCommand = GFUndoableCommand.new()
	var cmd2: GFUndoableCommand = GFUndoableCommand.new()

	_history.record(cmd1)
	_history.record(cmd2)
	var _undo_last_result_377: Variant = _history.undo_last()

	var full_history: Dictionary = _history.serialize_full_history()
	var restored: GFCommandHistoryUtility = GFCommandHistoryUtility.new()
	restored.init()

	var builder: Callable = func(_data: Dictionary) -> GFUndoableCommand:
		return GFUndoableCommand.new()

	restored.deserialize_full_history(full_history, builder)

	assert_eq(restored.undo_count, 1, "完整历史恢复后应保留 undo 栈。")
	assert_eq(restored.redo_count, 1, "完整历史恢复后应保留 redo 栈。")


func test_history_size_limit() -> void:
	_history.max_history_size = 2
	var counter: CounterState = CounterState.new()

	for _index: int in range(3):
		var cmd: CounterCommand = CounterCommand.new(counter)
		cmd.execute()
		_history.record(cmd)

	assert_eq(_history.undo_count, 2, "超出最大限制时撤销栈大小应保持为 max_history_size (2)。")

	var _undo_last_result_403: Variant = _history.undo_last()
	assert_eq(counter.value, 2, "最新撤销的应是第三个命令，执行撤销后恢复为 2。")

	var _undo_last_result_406: Variant = _history.undo_last()
	assert_eq(counter.value, 1, "再次撤销的是第二个命令，执行撤销后恢复为 1。")

	assert_false(_history.undo_last(), "第一条命令应已被超限丢弃，无法再撤销。")


func test_history_size_limit_trims_deserialized_redo_stack() -> void:
	_history.max_history_size = 2
	var builder: Callable = func(_data: Dictionary) -> GFUndoableCommand:
		return GFUndoableCommand.new()
	_history.deserialize_full_history({
		"undo": [{ "snapshot": 1 }, { "snapshot": 2 }, { "snapshot": 3 }],
		"redo": [{ "snapshot": 4 }, { "snapshot": 5 }, { "snapshot": 6 }],
	}, builder)

	assert_eq(_history.undo_count, 2, "反序列化后撤销栈应遵守容量上限。")
	assert_eq(_history.redo_count, 2, "反序列化后重做栈应遵守容量上限。")


# --- 测试：深拷贝快照 (Task 7) ---

## 验证 set_snapshot 对于引用类型（字典/数组）执行深拷贝，防止外部修改破坏快照。
func test_snapshot_deep_copy() -> void:
	var data: Dictionary = { "a": 1, "b": [1, 2] }
	var cmd: CounterCommand = CounterCommand.new(CounterState.new())

	assert_true(cmd.set_snapshot(data), "纯 Variant 快照应保存成功。")

	# 修改原数据
	data["a"] = 99
	var data_values: Array = GFVariantData.as_array(data["b"])
	data_values.append(3)

	var snapshot: Dictionary = GFVariantData.as_dictionary(cmd.get_snapshot())
	assert_eq(GFVariantData.get_option_int(snapshot, "a"), 1, "字典快照不应受原字典修改影响。")
	assert_eq(GFVariantData.get_option_array(snapshot, "b").size(), 2, "嵌套数组快照不应受原数组修改影响。")

	snapshot["a"] = 42
	var snapshot_values: Array = GFVariantData.get_option_array(snapshot, "b")
	snapshot_values.append(99)
	var second_snapshot: Dictionary = GFVariantData.as_dictionary(cmd.get_snapshot())
	assert_eq(GFVariantData.get_option_int(second_snapshot, "a"), 1, "get_snapshot 返回值不应共享内部快照。")
	assert_eq(GFVariantData.get_option_array(second_snapshot, "b").size(), 2, "修改已返回快照不应污染内部嵌套数组。")


func test_snapshot_rejects_runtime_references_transactionally() -> void:
	var cmd: CounterCommand = CounterCommand.new(CounterState.new())
	assert_true(cmd.set_snapshot({ "value": 7 }), "初始纯数据快照应保存成功。")

	assert_false(cmd.set_snapshot({ "owner": cmd }), "快照不应保留运行时 Object 引用。")
	assert_push_error("[GFUndoableCommand] 快照必须是有界的纯 Variant 数据，不能包含运行时引用或递归结构。")
	var preserved_snapshot: Dictionary = GFVariantData.as_dictionary(cmd.get_snapshot())
	assert_eq(preserved_snapshot, { "value": 7 }, "无效快照不应覆盖最近一次有效快照。")


# --- 内部类 ---

class CounterState:
	var value: int = 0

	func _init(initial_value: int = 0) -> void:
		value = initial_value


class CounterCommand:
	extends GFUndoableCommand

	var _counter: CounterState

	func _init(counter: CounterState) -> void:
		_counter = counter

	func execute() -> Variant:
		var _snapshot_saved: bool = set_snapshot(_counter.value)
		_counter.value += 1
		return null

	func undo() -> Variant:
		_counter.value = GFVariantData.to_int(get_snapshot())
		return null


class AsyncCounterCommand:
	extends GFUndoableCommand

	signal completed

	var _counter: CounterState
	var _execute_value: int
	var _undo_value: int

	func _init(counter: CounterState, execute_value: int, undo_value: int) -> void:
		_counter = counter
		_execute_value = execute_value
		_undo_value = undo_value

	func execute() -> Variant:
		call_deferred("_finish_execute")
		return completed

	func undo() -> Variant:
		call_deferred("_finish_undo")
		return completed

	func _finish_execute() -> void:
		_counter.value = _execute_value
		completed.emit()

	func _finish_undo() -> void:
		_counter.value = _undo_value
		completed.emit()


class ManualAsyncCommand:
	extends GFUndoableCommand

	signal completed

	var undo_called: bool = false
	var execute_called: bool = false

	func execute() -> Variant:
		execute_called = true
		return completed

	func undo() -> Variant:
		undo_called = true
		return completed

	func complete() -> void:
		completed.emit()


class InjectedHistoryCommand:
	extends GFUndoableCommand

	var injected_architecture: GFArchitecture = null

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		injected_architecture = architecture


class ConditionalRecordCommand:
	extends GFUndoableCommand

	var should_store: bool = true
	var execute_count: int = 0

	func _init(p_should_store: bool) -> void:
		should_store = p_should_store

	func execute() -> Variant:
		execute_count += 1
		return execute_count

	func should_record(_execute_result: Variant) -> bool:
		return should_store
