## 测试通用编辑器 Command、Action 与 Tool 协议。
@tool

extends GutTest


const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 测试 ---

func test_editor_command_executes_and_reverts() -> void:
	var state: CounterState = CounterState.new()
	var command: CounterCommand = CounterCommand.new()
	command.target = state
	command.delta = 3
	command.command_name = "Increase Value"

	assert_eq(command.execute(), OK, "命令应能直接执行。")
	assert_eq(state.value, 3, "执行后应写入目标状态。")
	assert_true(command.is_executed(), "执行成功后应记录状态。")

	assert_eq(command.revert(), OK, "命令应能撤销。")
	assert_eq(state.value, 0, "撤销后应恢复目标状态。")


func test_editor_command_session_previews_commits_and_reverts() -> void:
	var state: CounterState = CounterState.new()
	var command: CounterCommand = CounterCommand.new()
	command.target = state
	command.delta = 5
	command.command_name = "Session Increase"
	var session: GFEditorCommandSession = GFEditorCommandSession.new()
	var _configured_session: GFEditorCommandSession = session.configure(&"counter", "Counter")

	var preview: Dictionary = session.preview_command(command, { "source": "test" })
	var commit: Dictionary = session.commit_command(command)
	var snapshot: Dictionary = session.get_debug_snapshot()

	assert_true(GF_VARIANT_ACCESS.get_option_bool(preview, "ok"), "会话预览应报告命令可执行。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(preview, "status"), &"ready", "预览状态应为 ready。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(commit, "ok"), "会话应能提交命令。")
	assert_eq(state.value, 5, "提交后应影响目标状态。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(snapshot, "history_count"), 1, "提交后会话历史应记录命令。")
	var revert: Dictionary = session.revert_last()
	assert_true(GF_VARIANT_ACCESS.get_option_bool(revert, "ok"), "会话应能撤销最近命令。")
	assert_eq(state.value, 0, "撤销后目标状态应恢复。")
	assert_eq(session.get_history_count(), 0, "撤销后历史应移除命令。")


func test_editor_action_creates_and_invokes_command() -> void:
	var state: CounterState = CounterState.new()
	var action: GFEditorActionDefinition = GFEditorActionDefinition.new()
	action.action_id = &"increase"
	action.label = "Increase"
	action.command_factory = func(context: Dictionary) -> GFEditorCommand:
		var command: CounterCommand = CounterCommand.new()
		command.target = _context_state(context)
		command.delta = 2
		return command

	assert_true(action.is_available({ "state": state }), "有效工厂应让动作可用。")
	assert_eq(action.invoke({ "state": state }), OK, "动作应能执行命令。")
	assert_eq(state.value, 2, "动作执行后应影响目标状态。")


func test_editor_tool_lifecycle_and_input_forwarding() -> void:
	var tool: RecordingTool = RecordingTool.new()
	var context: GFEditorToolContext = GFEditorToolContext.new()

	assert_true(tool.can_handle(context), "默认工具应能处理有效上下文。")
	tool.activate(context)
	assert_true(tool.is_active(), "activate 后工具应进入激活状态。")

	var consumed: bool = tool.gui_input(InputEventAction.new())
	assert_true(consumed, "激活工具应能转发输入。")
	assert_eq(tool.input_count, 1, "输入次数应被工具记录。")

	tool.deactivate()
	assert_false(tool.is_active(), "deactivate 后工具应离开激活状态。")


func test_editor_tool_option_schema_normalizes_values() -> void:
	var schema: GFEditorToolOptionSchema = GFEditorToolOptionSchema.new()
	var radius: GFEditorToolOption = GFEditorToolOption.new()
	radius.option_id = &"radius"
	radius.value_type = GFEditorToolOption.ValueType.INT
	radius.min_value = 1.0
	radius.max_value = 10.0
	radius.default_value = 3
	var _add_option_result_65: Variant = schema.add_option(radius)

	var tool: RecordingTool = RecordingTool.new()
	tool.set_option_schema(schema)

	assert_eq(GF_VARIANT_ACCESS.to_int(tool.get_tool_option(&"radius")), 3, "设置 schema 后应写入默认工具选项。")
	assert_true(tool.set_tool_option(&"radius", 99), "已声明选项应可设置。")
	assert_eq(GF_VARIANT_ACCESS.to_int(tool.get_tool_option(&"radius")), 10, "工具选项应按声明裁剪。")


func test_editor_pick_operation_tracks_preview_and_apply_result() -> void:
	var tool: RecordingTool = RecordingTool.new()
	var context: GFEditorToolContext = GFEditorToolContext.new()
	var operation: RecordingPickOperation = RecordingPickOperation.new()
	tool.activate(context)

	assert_true(tool.begin_pick_operation(operation), "激活工具应能开始拾取操作。")
	assert_eq(tool.pick({ "position": Vector2(1.0, 2.0) }), GFEditorPickOperation.State.READY, "输入有效数据后拾取应进入 ready。")

	var snapshot: Dictionary = tool.get_debug_snapshot()
	var pick_snapshot: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(snapshot, "pick_operation")
	var result: Dictionary = tool.apply_pick_operation()
	var preview: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(pick_snapshot, "preview")
	var result_value: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(result, "result")

	assert_eq(GF_VARIANT_ACCESS.get_option_vector2(preview, "position"), Vector2(1.0, 2.0), "拾取预览应进入工具快照。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "ready 状态应可应用。")
	assert_eq(GF_VARIANT_ACCESS.get_option_vector2(result_value, "position"), Vector2(1.0, 2.0), "应用结果应包含拾取结果。")


# --- 私有/辅助方法 ---

func _context_state(context: Dictionary) -> CounterState:
	var value: Variant = GF_VARIANT_ACCESS.get_option_value(context, "state")
	assert_true(value is CounterState, "测试上下文应包含 CounterState。")
	if value is CounterState:
		var state: CounterState = value
		return state
	return null


# --- 内部类 ---

class CounterState:
	extends RefCounted

	var value: int = 0


class CounterCommand extends GFEditorCommand:
	var target: CounterState
	var delta: int = 1


	func _do_it() -> Error:
		if target == null:
			return ERR_INVALID_PARAMETER
		target.value += delta
		return OK


	func _undo_it() -> Error:
		if target == null:
			return ERR_INVALID_PARAMETER
		target.value -= delta
		return OK


class RecordingTool extends GFEditorTool:
	var input_count: int = 0


	func _handle_gui_input(_event: InputEvent) -> bool:
		input_count += 1
		return true


class RecordingPickOperation extends GFEditorPickOperation:
	func _on_pick(input_data: Dictionary) -> Dictionary:
		return {
			"preview": input_data.duplicate(true),
			"result": input_data.duplicate(true),
			"ready": input_data.has("position"),
		}
