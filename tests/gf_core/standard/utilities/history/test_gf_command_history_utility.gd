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
func test_undo_last_rejects_async_command_and_preserves_stack() -> void:
	var cmd: ManualAsyncCommand = ManualAsyncCommand.new()
	_history.record(cmd)

	var result: bool = _history.undo_last()

	assert_false(result, "同步 undo_last 不应接受异步命令。")
	assert_true(cmd.undo_called, "同步 undo_last 应调用命令以识别返回值。")
	assert_eq(_history.undo_count, 1, "异步命令被拒绝后应放回撤销栈。")
	assert_eq(_history.redo_count, 0, "异步命令被拒绝后不应进入重做栈。")
	assert_push_warning("[GFCommandHistoryUtility] undo_last() 不支持异步命令，请使用 await undo_last_async()。")


func test_failed_sync_undo_preserves_both_stack_orders() -> void:
	_history.max_history_size = 0
	var failing_cmd: ConditionalOutcomeCommand = ConditionalOutcomeCommand.new()
	var redo_first: ConditionalOutcomeCommand = ConditionalOutcomeCommand.new()
	var redo_second: ConditionalOutcomeCommand = ConditionalOutcomeCommand.new()
	var redo_third: ConditionalOutcomeCommand = ConditionalOutcomeCommand.new()
	_history.record(failing_cmd)
	_history.record(redo_first)
	_history.record(redo_second)
	_history.record(redo_third)
	assert_true(_history.undo_last(), "测试前置撤销第三条命令应成功。")
	assert_true(_history.undo_last(), "测试前置撤销第二条命令应成功。")
	assert_true(_history.undo_last(), "测试前置撤销第一条命令应成功。")
	_history.max_history_size = 3
	failing_cmd.undo_success = false
	var undo_before: Array[GFUndoableCommand] = _history.get_undo_history()
	var redo_before: Array[GFUndoableCommand] = _history.get_redo_history()

	var result: bool = _history.undo_last()

	assert_false(result, "命令报告撤销失败时 undo_last 应返回 false。")
	var undo_after: Array[GFUndoableCommand] = _history.get_undo_history()
	var redo_after: Array[GFUndoableCommand] = _history.get_redo_history()
	assert_eq(undo_after.size(), undo_before.size(), "失败撤销不得改变撤销栈深度。")
	if undo_after.size() == undo_before.size():
		assert_same(undo_after[0], undo_before[0], "失败撤销必须把命令恢复到原撤销栈位置。")
	assert_eq(redo_after.size(), redo_before.size(), "失败撤销不得触发重做栈容量裁剪。")
	if redo_after.size() == redo_before.size():
		for index: int in range(redo_before.size()):
			assert_same(redo_after[index], redo_before[index], "失败撤销不得改变重做栈顺序。")


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
func test_redo_rejects_async_command_and_preserves_stack() -> void:
	var counter: CounterState = CounterState.new()
	var cmd: AsyncCounterCommand = AsyncCounterCommand.new(counter, 5, 0)
	_history.record(cmd)
	await _history.undo_last_async()

	var result: bool = _history.redo()

	assert_false(result, "同步 redo 不应接受异步命令。")
	assert_eq(_history.undo_count, 0, "异步 redo 被拒绝后不应进入撤销栈。")
	assert_eq(_history.redo_count, 1, "异步 redo 被拒绝后应放回重做栈。")
	assert_push_warning("[GFCommandHistoryUtility] redo() 不支持异步命令，请使用 await redo_async()。")


func test_failed_sync_redo_preserves_both_stack_orders() -> void:
	_history.max_history_size = 0
	var undo_first: ConditionalOutcomeCommand = ConditionalOutcomeCommand.new()
	var undo_second: ConditionalOutcomeCommand = ConditionalOutcomeCommand.new()
	var undo_third: ConditionalOutcomeCommand = ConditionalOutcomeCommand.new()
	var failing_cmd: ConditionalOutcomeCommand = ConditionalOutcomeCommand.new()
	_history.record(undo_first)
	_history.record(undo_second)
	_history.record(undo_third)
	_history.record(failing_cmd)
	assert_true(_history.undo_last(), "测试前置撤销失败命令应成功。")
	_history.max_history_size = 3
	failing_cmd.redo_success = false
	var undo_before: Array[GFUndoableCommand] = _history.get_undo_history()
	var redo_before: Array[GFUndoableCommand] = _history.get_redo_history()

	var result: bool = _history.redo()

	assert_false(result, "命令报告重做失败时 redo 应返回 false。")
	var undo_after: Array[GFUndoableCommand] = _history.get_undo_history()
	var redo_after: Array[GFUndoableCommand] = _history.get_redo_history()
	assert_eq(undo_after.size(), undo_before.size(), "失败重做不得触发撤销栈容量裁剪。")
	if undo_after.size() == undo_before.size():
		for index: int in range(undo_before.size()):
			assert_same(undo_after[index], undo_before[index], "失败重做不得改变撤销栈顺序。")
	assert_eq(redo_after.size(), redo_before.size(), "失败重做不得改变重做栈深度。")
	if redo_after.size() == redo_before.size():
		assert_same(redo_after[0], redo_before[0], "失败重做必须把命令恢复到原重做栈位置。")


## 验证 undo_last_async 会等待异步撤销命令完成后再移动到重做栈。
func test_undo_last_async_awaits_async_command() -> void:
	var counter: CounterState = CounterState.new(10)
	var cmd: AsyncCounterCommand = AsyncCounterCommand.new(counter, 20, 0)
	_history.record(cmd)

	var result: bool = await _history.undo_last_async()

	assert_true(result, "异步撤销完成后应返回 true。")
	assert_true(cmd.undo_hook_called, "无参数完成 Signal 仍应调用默认成功 hook。")
	assert_true(cmd.observed_undo_payload == null, "无参数完成 Signal 应规范化为 null。")
	assert_eq(counter.value, 0, "异步 undo 完成后应恢复指定值。")
	assert_eq(_history.redo_count, 1, "异步 undo 完成后应推入重做栈。")


func test_failed_async_undo_preserves_stacks_and_holds_lock_through_hook() -> void:
	_history.max_history_size = 0
	var failing_cmd: AsyncUndoOutcomeCommand = AsyncUndoOutcomeCommand.new(_history, false)
	var redo_first: ConditionalOutcomeCommand = ConditionalOutcomeCommand.new()
	var redo_second: ConditionalOutcomeCommand = ConditionalOutcomeCommand.new()
	var redo_third: ConditionalOutcomeCommand = ConditionalOutcomeCommand.new()
	_history.record(failing_cmd)
	_history.record(redo_first)
	_history.record(redo_second)
	_history.record(redo_third)
	assert_true(_history.undo_last(), "测试前置撤销第三条命令应成功。")
	assert_true(_history.undo_last(), "测试前置撤销第二条命令应成功。")
	assert_true(_history.undo_last(), "测试前置撤销第一条命令应成功。")
	_history.max_history_size = 3
	var undo_before: Array[GFUndoableCommand] = _history.get_undo_history()
	var redo_before: Array[GFUndoableCommand] = _history.get_redo_history()

	var result: bool = await _history.undo_last_async()

	assert_false(result, "异步命令报告撤销失败时 undo_last_async 应返回 false。")
	assert_eq(typeof(failing_cmd.observed_payload), TYPE_BOOL, "单参数完成 Signal 应保留参数类型。")
	assert_false(GFVariantData.to_bool(failing_cmd.observed_payload, true), "单参数完成 Signal 应直接传给撤销结果 hook。")
	assert_true(failing_cmd.hook_saw_async_lock, "撤销结果 hook 执行期间必须继续持有异步历史锁。")
	assert_false(_history.is_processing_async, "异步撤销终态提交后必须释放历史锁。")
	var undo_after: Array[GFUndoableCommand] = _history.get_undo_history()
	var redo_after: Array[GFUndoableCommand] = _history.get_redo_history()
	assert_eq(undo_after.size(), undo_before.size(), "失败异步撤销不得改变撤销栈深度。")
	if undo_after.size() == undo_before.size():
		assert_same(undo_after[0], undo_before[0], "失败异步撤销必须保持原撤销栈位置。")
	assert_eq(redo_after.size(), redo_before.size(), "失败异步撤销不得触发重做栈容量裁剪。")
	if redo_after.size() == redo_before.size():
		for index: int in range(redo_before.size()):
			assert_same(redo_after[index], redo_before[index], "失败异步撤销不得改变重做栈顺序。")


func test_sync_outcome_hook_cannot_clear_or_reenter_history() -> void:
	var cmd: ReentrantUndoOutcomeCommand = ReentrantUndoOutcomeCommand.new(_history)
	var redo_cmd: ConditionalOutcomeCommand = ConditionalOutcomeCommand.new()
	assert_true(cmd.set_snapshot({ "id": "undo_source" }), "测试命令快照应可保存。")
	assert_true(redo_cmd.set_snapshot({ "id": "redo_source" }), "测试重做命令快照应可保存。")
	_history.record(cmd)
	_history.record(redo_cmd)
	assert_true(_history.undo_last(), "测试前置撤销应生成非空重做栈。")
	_history.max_history_size = 3
	var undo_before: Array[GFUndoableCommand] = _history.get_undo_history()
	var redo_before: Array[GFUndoableCommand] = _history.get_redo_history()
	var serialized_before: Dictionary = _history.serialize_full_history()

	var result: bool = _history.undo_last()

	assert_false(result, "失败结果 hook 外层撤销应返回 false。")
	assert_false(cmd.reentrant_undo_result, "结果 hook 内不得重入另一条撤销操作。")
	assert_eq(cmd.nested_execute_count, 0, "结果 hook 内的嵌套 execute_command 不得执行业务命令。")
	assert_true(cmd.nested_execute_result == null, "被拒绝的嵌套 execute_command 应返回 null。")
	assert_eq(cmd.observed_max_history_size, 3, "结果 hook 内不得修改历史容量。")
	assert_push_warning("[GFCommandHistoryUtility] 当前正在处理历史操作，忽略新的历史记录。")
	assert_push_warning("[GFCommandHistoryUtility] 当前正在处理历史操作，忽略新的执行请求。")
	assert_push_warning("[GFCommandHistoryUtility] 当前正在处理历史操作，忽略容量修改请求。")
	assert_push_warning("[GFCommandHistoryUtility] 当前正在处理历史操作，忽略清空请求。")
	assert_eq(cmd.observed_serialized_history, serialized_before, "结果 hook 内序列化必须观察到提交前完整历史。")
	_assert_same_history_ids(cmd.observed_undo_history_ids, undo_before, "结果 hook 内撤销栈必须保持提交前身份与顺序。")
	_assert_same_history_ids(cmd.observed_redo_history_ids, redo_before, "结果 hook 内重做栈必须保持提交前身份与顺序。")
	var undo_after: Array[GFUndoableCommand] = _history.get_undo_history()
	var redo_after: Array[GFUndoableCommand] = _history.get_redo_history()
	assert_eq(undo_after.size(), undo_before.size(), "hook 内 clear 与重入不得改变撤销栈。")
	if undo_after.size() == undo_before.size():
		assert_same(undo_after[0], undo_before[0], "失败命令应回到原撤销栈位置。")
	assert_eq(redo_after.size(), redo_before.size(), "hook 内 clear 与重入不得改变重做栈。")
	if redo_after.size() == redo_before.size():
		assert_same(redo_after[0], redo_before[0], "既有重做命令的身份与顺序必须保留。")
	assert_false(undo_after.has(cmd.nested_record_command), "结果 hook 内的 record 请求不得写入历史。")


func test_dispose_in_async_outcome_hook_does_not_commit_stale_generation() -> void:
	var replacement: ConditionalOutcomeCommand = ConditionalOutcomeCommand.new()
	var cmd: AsyncUndoOutcomeCommand = AsyncUndoOutcomeCommand.new(_history, false)
	cmd.dispose_in_hook = true
	cmd.replacement_after_dispose = replacement
	_history.record(cmd)

	var result: bool = await _history.undo_last_async()

	assert_false(result, "hook 切换生命周期后旧异步撤销必须返回 false。")
	assert_true(cmd.hook_saw_async_lock, "dispose 前的结果 hook 仍应观察到异步锁。")
	assert_false(_history.is_processing_async, "dispose 切代后不得遗留旧异步锁。")
	var undo_history: Array[GFUndoableCommand] = _history.get_undo_history()
	assert_eq(undo_history.size(), 1, "新生命周期写入的历史不得被旧操作覆盖。")
	if undo_history.size() == 1:
		assert_same(undo_history[0], replacement, "旧操作不得把失败命令恢复进新生命周期。")
	assert_eq(_history.redo_count, 0, "旧操作不得向新生命周期的重做栈提交。")


## 验证异步撤销过程中不会允许第二次撤销污染栈顺序。
func test_undo_last_async_blocks_reentrant_history_mutation() -> void:
	var first_cmd: CounterCommand = CounterCommand.new(CounterState.new())
	var second_cmd: ManualAsyncCommand = ManualAsyncCommand.new()
	assert_true(first_cmd.set_snapshot({ "id": "first" }), "第一条测试命令快照应可保存。")
	assert_true(second_cmd.set_snapshot({ "id": "second" }), "第二条测试命令快照应可保存。")
	_history.record(first_cmd)
	_history.record(second_cmd)
	var undo_before: Array[GFUndoableCommand] = _history.get_undo_history()
	var redo_before: Array[GFUndoableCommand] = _history.get_redo_history()
	var serialized_before: Dictionary = _history.serialize_full_history()

	@warning_ignore("missing_await")
	@warning_ignore("return_value_discarded")
	_history.undo_last_async()
	await get_tree().process_frame

	var sync_result: bool = _history.undo_last()

	assert_true(second_cmd.undo_called, "第一条异步 undo 应已开始执行。")
	assert_false(sync_result, "异步 undo 未完成时，同步 undo 应被拒绝。")
	assert_eq(_history.undo_count, 2, "异步等待期间来源栈必须保持提交前深度。")
	_assert_same_history(_history.get_undo_history(), undo_before, "异步等待期间撤销栈身份与顺序必须不变。")
	_assert_same_history(_history.get_redo_history(), redo_before, "异步等待期间重做栈身份与顺序必须不变。")
	assert_eq(_history.serialize_full_history(), serialized_before, "异步等待期间序列化必须保留完整提交前历史。")

	second_cmd.complete()
	await get_tree().process_frame

	assert_eq(_history.undo_count, 1, "异步 undo 成功后才应从来源栈移除命令。")
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
	assert_eq(_history.undo_count, 1, "命令等待期间必须保留在来源 undo 栈。")
	assert_eq(_history.redo_count, 0, "命令等待期间不得提前写入 redo 栈。")
	_history.record(CounterCommand.new(CounterState.new()))
	assert_eq(_history.undo_count, 1, "迟到完成前新的历史 mutation 必须继续被锁拒绝。")

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
	assert_true(cmd.redo_hook_called, "无参数完成 Signal 仍应调用默认重做成功 hook。")
	assert_true(cmd.observed_redo_payload == null, "无参数完成 Signal 应规范化为 null。")
	assert_eq(counter.value, 20, "异步 redo 完成后应应用指定值。")
	assert_eq(_history.undo_count, 1, "异步 redo 完成后应推回撤销栈。")


func test_failed_async_redo_preserves_stacks_and_normalizes_multi_payload() -> void:
	_history.max_history_size = 0
	var undo_first: ConditionalOutcomeCommand = ConditionalOutcomeCommand.new()
	var undo_second: ConditionalOutcomeCommand = ConditionalOutcomeCommand.new()
	var undo_third: ConditionalOutcomeCommand = ConditionalOutcomeCommand.new()
	var failing_cmd: AsyncRedoOutcomeCommand = AsyncRedoOutcomeCommand.new(_history, false, "redo_rejected")
	_history.record(undo_first)
	_history.record(undo_second)
	_history.record(undo_third)
	_history.record(failing_cmd)
	assert_true(_history.undo_last(), "测试前置撤销失败命令应成功。")
	_history.max_history_size = 3
	var undo_before: Array[GFUndoableCommand] = _history.get_undo_history()
	var redo_before: Array[GFUndoableCommand] = _history.get_redo_history()

	var result: bool = await _history.redo_async()

	assert_false(result, "异步命令报告重做失败时 redo_async 应返回 false。")
	assert_true(failing_cmd.observed_payload is Array, "多参数完成 Signal 应规范化为 Array。")
	var observed_payload: Array = GFVariantData.as_array(failing_cmd.observed_payload)
	assert_eq(
		observed_payload,
		[false, "redo_rejected"],
		"多参数完成 Signal 应以保持顺序的 Array 传给重做结果 hook。"
	)
	assert_true(failing_cmd.hook_saw_async_lock, "重做结果 hook 执行期间必须继续持有异步历史锁。")
	assert_false(_history.is_processing_async, "异步重做终态提交后必须释放历史锁。")
	var undo_after: Array[GFUndoableCommand] = _history.get_undo_history()
	var redo_after: Array[GFUndoableCommand] = _history.get_redo_history()
	assert_eq(undo_after.size(), undo_before.size(), "失败异步重做不得触发撤销栈容量裁剪。")
	if undo_after.size() == undo_before.size():
		for index: int in range(undo_before.size()):
			assert_same(undo_after[index], undo_before[index], "失败异步重做不得改变撤销栈顺序。")
	assert_eq(redo_after.size(), redo_before.size(), "失败异步重做不得改变重做栈深度。")
	if redo_after.size() == redo_before.size():
		assert_same(redo_after[0], redo_before[0], "失败异步重做必须保持原重做栈位置。")


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


func test_deserialize_history_failure_preserves_existing_stacks() -> void:
	var first: GFUndoableCommand = GFUndoableCommand.new()
	var second: GFUndoableCommand = GFUndoableCommand.new()
	_history.record(first)
	_history.record(second)
	assert_true(_history.undo_last(), "测试前置应建立 undo/redo 两个非空栈。")
	var undo_before: Array[GFUndoableCommand] = _history.get_undo_history()
	var redo_before: Array[GFUndoableCommand] = _history.get_redo_history()

	_history.deserialize_history([{ "snapshot": 1 }], Callable())

	_assert_history_identity(undo_before, redo_before, "无效 builder")
	assert_push_error("[GFCommandHistoryUtility] deserialize_history 失败：传入的 builder Callable 无效。")

	var builder_state: Dictionary = { "build_count": 0 }
	var late_failure_builder: Callable = func(_data: Dictionary) -> Variant:
		var build_count: int = GFVariantData.get_option_int(builder_state, "build_count") + 1
		builder_state["build_count"] = build_count
		return GFUndoableCommand.new() if build_count == 1 else null
	_history.deserialize_history(
		[{ "snapshot": 1 }, { "snapshot": 2 }],
		late_failure_builder
	)

	_assert_history_identity(undo_before, redo_before, "中途构建失败")
	assert_push_error("[GFCommandHistoryUtility] deserialize_history 失败：builder 未返回 GFUndoableCommand。")

	var valid_builder: Callable = func(_data: Dictionary) -> GFUndoableCommand:
		return GFUndoableCommand.new()
	_history.deserialize_history([{ "snapshot": 1 }, "invalid"], valid_builder)

	_assert_history_identity(undo_before, redo_before, "非法条目")
	assert_push_error("[GFCommandHistoryUtility] deserialize_history 失败：历史条目必须是 Dictionary。")


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


func test_deserialize_full_history_failure_preserves_existing_stacks() -> void:
	var first: GFUndoableCommand = GFUndoableCommand.new()
	var second: GFUndoableCommand = GFUndoableCommand.new()
	_history.record(first)
	_history.record(second)
	assert_true(_history.undo_last(), "测试前置应建立 undo/redo 两个非空栈。")
	var undo_before: Array[GFUndoableCommand] = _history.get_undo_history()
	var redo_before: Array[GFUndoableCommand] = _history.get_redo_history()
	_history.deserialize_full_history({ "undo": [] }, Callable())
	_assert_history_identity(undo_before, redo_before, "完整历史无效 builder")
	assert_push_error("[GFCommandHistoryUtility] deserialize_full_history 失败：传入的 builder Callable 无效。")

	var builder_state: Dictionary = { "build_count": 0 }
	var late_failure_builder: Callable = func(_data: Dictionary) -> Variant:
		var build_count: int = GFVariantData.get_option_int(builder_state, "build_count") + 1
		builder_state["build_count"] = build_count
		return GFUndoableCommand.new() if build_count == 1 else null

	_history.deserialize_full_history(
		{
			"undo": [{ "snapshot": 1 }],
			"redo": [{ "snapshot": 2 }],
		},
		late_failure_builder
	)

	_assert_history_identity(undo_before, redo_before, "完整历史中途构建失败")
	assert_push_error("[GFCommandHistoryUtility] deserialize_full_history 失败：builder 未返回 GFUndoableCommand。")


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


func test_snapshot_enforces_type_aware_cumulative_byte_budget() -> void:
	var cmd: GFUndoableCommand = GFUndoableCommand.new()
	assert_true(cmd.set_snapshot({ "value": 7 }), "测试应先保存一个有效快照。")
	var oversized_text: String = "x".repeat(
		int(GFUndoableCommand.MAX_SNAPSHOT_BYTES / 4.0) + 1
	)

	assert_false(cmd.set_snapshot(oversized_text), "超出累计字节预算的单个 String 必须被拒绝。")
	assert_push_error("[GFUndoableCommand] 快照必须是有界的纯 Variant 数据，不能包含运行时引用或递归结构。")
	var preserved_snapshot: Dictionary = GFVariantData.as_dictionary(cmd.get_snapshot())
	assert_eq(preserved_snapshot, { "value": 7 }, "字节预算失败不得覆盖最近一次有效快照。")

	var bounded_values: Array = [
		"x",
		&"x",
		NodePath("x"),
		PackedByteArray([1]),
		PackedInt32Array([1]),
		PackedInt64Array([1]),
		PackedFloat32Array([1.0]),
		PackedFloat64Array([1.0]),
		PackedStringArray(["x"]),
		PackedVector2Array([Vector2.ONE]),
		PackedVector3Array([Vector3.ONE]),
		PackedVector4Array([Vector4.ONE]),
		PackedColorArray([Color.WHITE]),
	]
	for value: Variant in bounded_values:
		var exhausted_state: Dictionary = {
			"bytes": GFUndoableCommand.MAX_SNAPSHOT_BYTES - 64,
			"items": 0,
		}
		assert_false(
			cmd._is_snapshot_value_supported(value, 0, exhausted_state),
			"%s 的载荷成本必须进入累计字节预算。" % type_string(typeof(value))
		)

	var exact_boundary_state: Dictionary = {
		"bytes": GFUndoableCommand.MAX_SNAPSHOT_BYTES - 68,
		"items": 0,
	}
	assert_true(
		cmd._is_snapshot_value_supported("x", 0, exact_boundary_state),
		"固定节点成本加一个字符的保守成本恰好命中边界时应被接受。"
	)
	assert_eq(
		GFVariantData.get_option_int(exact_boundary_state, "bytes"),
		GFUndoableCommand.MAX_SNAPSHOT_BYTES,
		"边界校验应准确消费完整 byte budget。"
	)


func _assert_same_history(
	actual: Array[GFUndoableCommand],
	expected: Array[GFUndoableCommand],
	message: String
) -> void:
	assert_eq(actual.size(), expected.size(), "%s（数量）" % message)
	if actual.size() != expected.size():
		return
	for index: int in range(expected.size()):
		assert_same(actual[index], expected[index], "%s（索引 %d）" % [message, index])


func _assert_history_identity(
	undo_expected: Array[GFUndoableCommand],
	redo_expected: Array[GFUndoableCommand],
	context: String
) -> void:
	_assert_same_history(
		_history.get_undo_history(),
		undo_expected,
		"%s不得改变撤销栈" % context
	)
	_assert_same_history(
		_history.get_redo_history(),
		redo_expected,
		"%s不得改变重做栈" % context
	)


func _assert_same_history_ids(
	actual: Array[int],
	expected: Array[GFUndoableCommand],
	message: String
) -> void:
	assert_eq(actual.size(), expected.size(), "%s（数量）" % message)
	if actual.size() != expected.size():
		return
	for index: int in range(expected.size()):
		assert_eq(actual[index], expected[index].get_instance_id(), "%s（索引 %d）" % [message, index])


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

	var undo_hook_called: bool = false
	var redo_hook_called: bool = false
	var observed_undo_payload: Variant = "not_called"
	var observed_redo_payload: Variant = "not_called"
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

	func is_undo_successful(undo_result: Variant) -> bool:
		undo_hook_called = true
		observed_undo_payload = undo_result
		return super.is_undo_successful(undo_result)

	func is_redo_successful(execute_result: Variant) -> bool:
		redo_hook_called = true
		observed_redo_payload = execute_result
		return super.is_redo_successful(execute_result)

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


class AsyncUndoOutcomeCommand:
	extends GFUndoableCommand

	signal undo_completed(success: bool)

	var observed_payload: Variant = null
	var hook_saw_async_lock: bool = false
	var dispose_in_hook: bool = false
	var replacement_after_dispose: GFUndoableCommand = null
	var _history_ref: WeakRef
	var _undo_success: bool

	func _init(history: GFCommandHistoryUtility, undo_success: bool) -> void:
		_history_ref = weakref(history)
		_undo_success = undo_success

	func undo() -> Variant:
		call_deferred("_finish_undo")
		return undo_completed

	func is_undo_successful(undo_result: Variant) -> bool:
		observed_payload = undo_result
		var history_value: Variant = _history_ref.get_ref()
		var history: GFCommandHistoryUtility = null
		if history_value is GFCommandHistoryUtility:
			history = history_value
		hook_saw_async_lock = history != null and history.is_processing_async
		if dispose_in_hook and history != null:
			history.dispose()
			if replacement_after_dispose != null:
				history.record(replacement_after_dispose)
		return GFVariantData.to_bool(undo_result, false)

	func _finish_undo() -> void:
		undo_completed.emit(_undo_success)


class AsyncRedoOutcomeCommand:
	extends GFUndoableCommand

	signal redo_completed(success: bool, reason: String)

	var observed_payload: Variant = null
	var hook_saw_async_lock: bool = false
	var _history_ref: WeakRef
	var _redo_success: bool
	var _reason: String

	func _init(history: GFCommandHistoryUtility, redo_success: bool, reason: String) -> void:
		_history_ref = weakref(history)
		_redo_success = redo_success
		_reason = reason

	func execute() -> Variant:
		call_deferred("_finish_redo")
		return redo_completed

	func undo() -> Variant:
		return true

	func is_redo_successful(execute_result: Variant) -> bool:
		observed_payload = execute_result
		var history_value: Variant = _history_ref.get_ref()
		var history: GFCommandHistoryUtility = null
		if history_value is GFCommandHistoryUtility:
			history = history_value
		hook_saw_async_lock = history != null and history.is_processing_async
		if not (execute_result is Array):
			return false
		var payload: Array = execute_result
		return not payload.is_empty() and GFVariantData.to_bool(payload[0], false)

	func _finish_redo() -> void:
		redo_completed.emit(_redo_success, _reason)


class ReentrantUndoOutcomeCommand:
	extends GFUndoableCommand

	var reentrant_undo_result: bool = true
	var nested_execute_result: Variant = "not_called"
	var nested_execute_count: int = -1
	var nested_record_command: GFUndoableCommand = null
	var observed_max_history_size: int = -1
	var observed_undo_history_ids: Array[int] = []
	var observed_redo_history_ids: Array[int] = []
	var observed_serialized_history: Dictionary = {}
	var _history_ref: WeakRef

	func _init(history: GFCommandHistoryUtility) -> void:
		_history_ref = weakref(history)
		nested_record_command = CounterCommand.new(CounterState.new())

	func undo() -> Variant:
		return false

	func is_undo_successful(_undo_result: Variant) -> bool:
		var history_value: Variant = _history_ref.get_ref()
		var history: GFCommandHistoryUtility = null
		if history_value is GFCommandHistoryUtility:
			history = history_value
		if history != null:
			observed_undo_history_ids = _history_instance_ids(history.get_undo_history())
			observed_redo_history_ids = _history_instance_ids(history.get_redo_history())
			observed_serialized_history = history.serialize_full_history()
			history.record(nested_record_command)
			var nested_counter: CounterState = CounterState.new()
			var nested_execute_command: CounterCommand = CounterCommand.new(nested_counter)
			nested_execute_result = history.call("execute_command", nested_execute_command)
			nested_execute_count = nested_counter.value
			history.max_history_size = history.max_history_size + 1
			observed_max_history_size = history.max_history_size
			history.clear()
			reentrant_undo_result = history.undo_last()
		return false

	static func _history_instance_ids(history: Array[GFUndoableCommand]) -> Array[int]:
		var instance_ids: Array[int] = []
		for command: GFUndoableCommand in history:
			instance_ids.append(command.get_instance_id())
		return instance_ids


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


class ConditionalOutcomeCommand:
	extends GFUndoableCommand

	var undo_success: bool = true
	var redo_success: bool = true

	func execute() -> Variant:
		return redo_success

	func undo() -> Variant:
		return undo_success

	func is_undo_successful(undo_result: Variant) -> bool:
		return GFVariantData.to_bool(undo_result, false)

	func is_redo_successful(execute_result: Variant) -> bool:
		return GFVariantData.to_bool(execute_result, false)
