# 验证命令历史指南中的项目编辑会话与真实历史栈共同遵守提交边界。
extends GutTest


# --- 常量 ---

const EDIT_SESSION_SCRIPT = preload("res://tests/gf_core/standard/utilities/history/fixtures/position_edit_session.gd")
const INITIAL_POSITION: Vector2 = Vector2(2.0, 3.0)
const FINAL_POSITION: Vector2 = Vector2(8.0, 9.0)


# --- 私有变量 ---

var _history: GFCommandHistoryUtility
var _model: EDIT_SESSION_SCRIPT.PositionModel
var _session: EDIT_SESSION_SCRIPT


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_history = GFCommandHistoryUtility.new()
	_history.init()
	_model = EDIT_SESSION_SCRIPT.PositionModel.new()
	_model.position = INITIAL_POSITION
	_session = EDIT_SESSION_SCRIPT.new(_model, _history)
	watch_signals(_model)


func after_each() -> void:
	_history.dispose()
	_session = null
	_model = null
	_history = null


# --- 公共方法 ---

func test_many_previews_confirm_once_then_undo_and_redo_endpoints() -> void:
	assert_true(_session.begin_edit())
	assert_true(_session.update_preview(Vector2(4.0, 5.0)))
	assert_false(_session.begin_edit(), "重复开始不能重置本次操作的最初值。")
	assert_true(_session.update_preview(Vector2(6.0, 7.0)))
	assert_true(_session.update_preview(FINAL_POSITION))

	assert_eq(_session.get_preview_position(), FINAL_POSITION, "视图应能读取最新草稿。")
	assert_eq(_model.position, INITIAL_POSITION, "多次预览不能提前改变模型。")
	assert_signal_not_emitted(_model, "position_changed")
	assert_eq(_history.undo_count, 0)

	assert_true(await _session.confirm_edit())
	assert_eq(_model.position, FINAL_POSITION)
	assert_signal_emit_count(_model, "position_changed", 1, "确认只能应用一次最终值。")
	assert_eq(_history.undo_count, 1, "一次用户操作只产生一条历史。")
	assert_false(await _session.confirm_edit(), "重复结束通知不能重复执行或压栈。")
	assert_signal_emit_count(_model, "position_changed", 1)
	assert_eq(_history.undo_count, 1)

	assert_true(_history.undo_last())
	assert_eq(_model.position, INITIAL_POSITION, "撤销恢复操作开始时的值。")
	assert_true(_history.redo())
	assert_eq(_model.position, FINAL_POSITION, "重做恢复操作确认时的值。")
	assert_signal_emit_count(_model, "position_changed", 3)
	assert_true(_history.undo_last())
	assert_eq(_model.position, INITIAL_POSITION, "重做不能覆盖命令保存的最初值。")


func test_cancel_discards_preview_and_preserves_existing_redo() -> void:
	await _prepare_redo_branch()
	assert_true(_session.begin_edit())
	assert_true(_session.update_preview(Vector2(20.0, 30.0)))
	assert_true(_session.cancel_edit())

	assert_eq(_session.get_preview_position(), INITIAL_POSITION)
	assert_eq(_model.position, INITIAL_POSITION)
	assert_signal_emit_count(_model, "position_changed", 2, "取消不能写入草稿或触发补偿写入。")
	assert_eq(_history.undo_count, 0)
	assert_eq(_history.redo_count, 1, "取消不能截断此前的重做分支。")
	assert_false(await _session.confirm_edit(), "已取消会话不能再提交。")
	assert_true(_history.redo())
	assert_eq(_model.position, FINAL_POSITION)


func test_returning_to_initial_value_does_not_write_or_clear_redo() -> void:
	await _prepare_redo_branch()
	assert_true(_session.begin_edit())
	assert_true(_session.update_preview(Vector2(20.0, 30.0)))
	assert_true(_session.update_preview(INITIAL_POSITION))

	assert_false(await _session.confirm_edit(), "净变化为零时不执行命令。")
	assert_eq(_model.position, INITIAL_POSITION)
	assert_signal_emit_count(_model, "position_changed", 2)
	assert_eq(_history.undo_count, 0)
	assert_eq(_history.redo_count, 1, "净零操作不能截断此前的重做分支。")
	assert_true(_history.redo())
	assert_eq(_model.position, FINAL_POSITION)


func test_separate_edits_keep_their_own_initial_and_final_values() -> void:
	assert_true(_session.begin_edit())
	assert_true(_session.update_preview(FINAL_POSITION))
	assert_true(await _session.confirm_edit())
	assert_true(_session.begin_edit())
	assert_true(_session.update_preview(Vector2(12.0, 13.0)))
	assert_true(await _session.confirm_edit())

	assert_eq(_history.undo_count, 2)
	assert_true(_history.undo_last())
	assert_eq(_model.position, FINAL_POSITION)
	assert_true(_history.undo_last())
	assert_eq(_model.position, INITIAL_POSITION)
	assert_true(_history.redo())
	assert_eq(_model.position, FINAL_POSITION)
	assert_true(_history.redo())
	assert_eq(_model.position, Vector2(12.0, 13.0))


func test_inactive_session_ignores_preview_confirm_and_cancel() -> void:
	assert_false(_session.update_preview(FINAL_POSITION))
	assert_false(await _session.confirm_edit())
	assert_false(_session.cancel_edit())
	assert_eq(_session.get_preview_position(), INITIAL_POSITION)
	assert_eq(_history.undo_count, 0)
	assert_signal_not_emitted(_model, "position_changed")


func test_record_keeps_an_already_applied_command_without_executing_again() -> void:
	var command: EDIT_SESSION_SCRIPT.MovePositionCommand = EDIT_SESSION_SCRIPT.MovePositionCommand.new(
		_model, INITIAL_POSITION, FINAL_POSITION
	)
	var execute_result: Variant = command.execute()
	assert_true(GFVariantData.to_bool(execute_result, false))

	_history.record(command)

	assert_eq(_model.position, FINAL_POSITION)
	assert_signal_emit_count(_model, "position_changed", 1, "record 只压栈，不再调用 execute。")
	assert_eq(_history.undo_count, 1)
	assert_true(_history.undo_last())
	assert_eq(_model.position, INITIAL_POSITION)
	assert_true(_history.redo())
	assert_eq(_model.position, FINAL_POSITION)


# --- 私有/辅助方法 ---

func _prepare_redo_branch() -> void:
	var command: EDIT_SESSION_SCRIPT.MovePositionCommand = EDIT_SESSION_SCRIPT.MovePositionCommand.new(
		_model, INITIAL_POSITION, FINAL_POSITION
	)
	var result: Variant = await _history.execute_command(command)
	assert_true(GFVariantData.to_bool(result, false))
	assert_true(_history.undo_last())
	assert_eq(_history.redo_count, 1)
