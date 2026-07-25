## 测试通用编辑器 Command、Action 与 Tool 协议。
@tool

extends GutTest


const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const GF_EDITOR_COMMAND_REGISTRY_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_command_registry.gd")
const GF_EDITOR_SCENE_METADATA_PATCH_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_scene_metadata_patch.gd")


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


func test_editor_command_rejects_configuration_change_after_execute() -> void:
	var state: CounterState = CounterState.new()
	var command: CounterCommand = CounterCommand.new()
	command.target = state
	command.command_name = "Initial"

	assert_eq(command.execute(), OK, "命令执行成功后应进入冻结配置状态。")
	command.command_name = "Changed"

	assert_true(command.is_sealed(), "执行成功后命令配置应冻结。")
	assert_eq(command.command_name, "Initial", "冻结后的命令名称不应被改写。")
	assert_push_error("[GFEditorCommand] 命令配置已冻结，不能修改：command_name。")


func test_editor_scene_metadata_patch_sets_removes_and_reverts() -> void:
	var node: Node = Node.new()
	node.set_meta(&"gf_test_guides", { "axis": "x", "offset": 10 })
	var set_command: GFEditorCommand = _make_metadata_patch(
		node,
		&"gf_test_guides",
		{ "axis": "y", "offset": 20 },
		false
	)

	assert_eq(set_command.execute(), OK, "metadata 写入命令应能执行。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string(GF_VARIANT_ACCESS.as_dictionary(node.get_meta(&"gf_test_guides")), "axis"),
		"y",
		"执行后应写入新 metadata。"
	)
	assert_eq(set_command.revert(), OK, "metadata 写入命令应能撤销。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string(GF_VARIANT_ACCESS.as_dictionary(node.get_meta(&"gf_test_guides")), "axis"),
		"x",
		"撤销后应恢复旧 metadata。"
	)

	var remove_command: GFEditorCommand = _make_metadata_patch(node, &"gf_test_guides", null, true)
	assert_eq(remove_command.execute(), OK, "metadata 移除命令应能执行。")
	assert_false(node.has_meta(&"gf_test_guides"), "执行移除命令后 metadata 应不存在。")
	assert_eq(remove_command.revert(), OK, "metadata 移除命令应能撤销。")
	assert_true(node.has_meta(&"gf_test_guides"), "撤销移除命令后 metadata 应恢复。")
	node.free()


func test_editor_scene_metadata_patch_rejects_reconfigure_after_execute() -> void:
	var node: Node = Node.new()
	node.set_meta(&"gf_test_guides", "old")
	var command: GFEditorSceneMetadataPatch = _make_typed_metadata_patch(
		node,
		&"gf_test_guides",
		"new",
		false
	)

	assert_eq(command.execute(), OK, "metadata 命令执行后应冻结配置。")
	var _reconfigured_command: GFEditorCommand = command.configure(node, &"gf_other", "changed")

	assert_true(command.is_sealed(), "执行后的 metadata 命令应冻结。")
	assert_eq(command.metadata_key, &"gf_test_guides", "冻结后 configure 不应改写 metadata key。")
	var raw_command_value: Variant = command.value
	var command_value: String = ""
	if raw_command_value is String:
		command_value = raw_command_value
	assert_eq(command_value, "new", "冻结后 configure 不应改写 value。")
	assert_push_error("[GFEditorCommand] 命令配置已冻结，不能修改：configure。")
	node.free()


func test_editor_scene_metadata_patch_rejects_field_change_after_undo_registration() -> void:
	var node: Node = Node.new()
	var command: GFEditorSceneMetadataPatch = _make_typed_metadata_patch(
		node,
		&"gf_test_guides",
		"new",
		false
	)
	var undo_manager: FakeUndoManager = FakeUndoManager.new()

	assert_eq(command.add_to_undo_manager(undo_manager, false), OK, "写入 UndoRedo 后应冻结命令配置。")
	command.metadata_key = &"gf_other"

	assert_true(command.is_sealed(), "写入 UndoRedo 后命令配置应冻结。")
	assert_eq(command.metadata_key, &"gf_test_guides", "冻结后 public 字段写入不应改变命令配置。")
	assert_push_error("[GFEditorCommand] 命令配置已冻结，不能修改：metadata_key。")
	node.free()


func test_editor_scene_metadata_patch_redo_keeps_original_snapshot() -> void:
	var node: Node = Node.new()
	node.set_meta(&"gf_test_guides", "old")
	var command: GFEditorSceneMetadataPatch = _make_typed_metadata_patch(
		node,
		&"gf_test_guides",
		"new",
		false
	)

	assert_eq(command.execute(), OK, "首次执行应写入新 metadata。")
	assert_eq(command.revert(), OK, "撤销应恢复首次执行前的旧值。")
	node.set_meta(&"gf_test_guides", "between")
	assert_eq(command.execute(), OK, "redo 应重新写入新 metadata。")
	assert_eq(command.revert(), OK, "redo 后撤销仍应恢复首次执行前的旧值。")

	var raw_metadata_value: Variant = node.get_meta(&"gf_test_guides")
	var metadata_value: String = ""
	if raw_metadata_value is String:
		metadata_value = raw_metadata_value
	assert_eq(metadata_value, "old", "redo 不应刷新 previous snapshot 到中间态。")
	node.free()


func test_editor_scene_metadata_patch_rejects_freed_target() -> void:
	var node: Node = Node.new()
	var command: GFEditorCommand = _make_metadata_patch(node, &"gf_test_guides", { "axis": "x" }, false)
	node.free()

	assert_false(command.can_execute(), "目标节点已释放时 metadata 命令不应可执行。")
	assert_eq(command.execute(), ERR_UNAVAILABLE, "目标节点已释放时执行应返回命令不可用。")


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


func test_editor_command_session_does_not_revert_undo_manager_commands_directly() -> void:
	var state: CounterState = CounterState.new()
	var command: CounterCommand = CounterCommand.new()
	command.target = state
	command.delta = 7
	var context: GFEditorToolContext = GFEditorToolContext.new()
	context.undo_manager = FakeUndoManager.new()
	var session: GFEditorCommandSession = GFEditorCommandSession.new()

	var commit: Dictionary = session.commit_command(command, context, true)
	var revert: Dictionary = session.revert_last()

	assert_true(GF_VARIANT_ACCESS.get_option_bool(commit, "ok"), "UndoRedo command 应能提交。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(commit, "status"), &"committed_to_undo_manager", "UndoRedo 管理的命令应有独立状态。")
	assert_eq(state.value, 7, "测试 UndoRedo 替身应立即执行 do 方法。")
	assert_eq(session.get_history_count(), 0, "UndoRedo 管理的命令不应进入本地 history。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(revert, "ok"), "本地 revert_last 不应绕过 UndoRedo 直接撤销命令。")
	assert_eq(state.value, 7, "本地撤销失败时不应改动 UndoRedo 管理的状态。")


func test_editor_command_undo_manager_registration_keeps_callback_error_on_command() -> void:
	var command: FailingDoCommand = FailingDoCommand.new()
	var undo_manager: FakeUndoManager = FakeUndoManager.new()

	var add_result: Error = command.add_to_undo_manager(undo_manager, true)
	var snapshot: Dictionary = command.get_debug_snapshot()

	assert_eq(add_result, OK, "UndoRedo 注册成功只表示 action 已提交给管理器。")
	assert_eq(command.get_last_execute_error(), ERR_INVALID_DATA, "do 回调错误应记录在命令自身。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(snapshot, "last_execute_error"), ERR_INVALID_DATA, "调试快照应暴露最近 execute 错误。")
	assert_false(command.is_executed(), "do 回调失败不应把命令标记为已执行。")


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


func test_editor_action_invocation_report_checks_command_without_executing() -> void:
	var state: CounterState = CounterState.new()
	var factory_calls: Array[int] = [0]
	var action: GFEditorActionDefinition = GFEditorActionDefinition.new()
	action.action_id = &"increase"
	action.label = "Increase"
	action.metadata = { "owner": self }
	action.command_factory = func(context: Dictionary) -> GFEditorCommand:
		factory_calls[0] += 1
		var command: CounterCommand = CounterCommand.new()
		command.command_name = "Increase Counter"
		command.target = _context_state(context)
		command.delta = 3
		return command

	var report: Dictionary = action.get_invocation_report({ "state": state })
	var metadata: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(report, "metadata")
	var owner_payload: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(metadata, "owner")
	var owner_marker: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(owner_payload, "__gf_report_value__")

	assert_true(action.is_available({ "state": state }), "轻量可用性检查应通过。")
	assert_eq(factory_calls[0], 1, "调用报告应创建一次临时命令。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "可执行命令应得到 ok 调用报告。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(report, "status"), GFEditorActionDefinition.INVOCATION_STATUS_READY, "调用报告应说明动作 ready。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "command_created"), "调用报告应记录已创建临时命令。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "command_can_execute"), "调用报告应记录命令可执行。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(report, "command_name"), "Increase Counter", "调用报告应暴露命令名称。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(owner_marker, "type"), "Object", "调用报告 metadata 应走 JSON-safe 报告边界。")
	assert_eq(state.value, 0, "调用报告不应执行命令。")
	assert_true(action.can_invoke({ "state": state }), "can_invoke 应复用严格调用探针。")
	assert_eq(factory_calls[0], 2, "can_invoke 会额外创建一次临时命令。")
	assert_eq(state.value, 0, "can_invoke 不应执行命令。")


func test_editor_action_invocation_report_rejects_non_executable_command() -> void:
	var action: GFEditorActionDefinition = GFEditorActionDefinition.new()
	action.action_id = &"blocked"
	action.label = "Blocked"
	action.command_factory = func(_context: Dictionary) -> GFEditorCommand:
		return NonExecutableCommand.new()

	var report: Dictionary = action.get_invocation_report()

	assert_true(action.is_available(), "命令不可执行不应影响纯 UI 可用性。")
	assert_false(action.can_invoke(), "严格调用探针应拒绝不可执行命令。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "不可执行命令应得到失败调用报告。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(report, "status"), GFEditorActionDefinition.INVOCATION_STATUS_COMMAND_UNAVAILABLE, "调用报告应说明命令不可执行。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "available"), "action 本身仍可展示为可用。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "command_created"), "调用报告应记录已创建临时命令。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "command_can_execute"), "调用报告应记录命令不可执行。")
	assert_eq(action.invoke(), ERR_UNAVAILABLE, "直接调用不可执行命令应返回不可用。")


func test_editor_action_availability_callback_does_not_create_command() -> void:
	var state: CounterState = CounterState.new()
	var factory_calls: Array[int] = [0]
	var action: GFEditorActionDefinition = GFEditorActionDefinition.new()
	action.action_id = &"increase"
	action.label = "Increase"
	action.availability_callback = func(context: Dictionary) -> bool:
		return GF_VARIANT_ACCESS.get_option_bool(context, "allow")
	action.command_factory = func(context: Dictionary) -> GFEditorCommand:
		factory_calls[0] += 1
		var command: CounterCommand = CounterCommand.new()
		command.target = _context_state(context)
		command.delta = 2
		return command

	assert_false(action.is_available({ "state": state, "allow": false }), "可用性回调应能禁用动作。")
	assert_true(action.is_available({ "state": state, "allow": true }), "可用性回调应能启用动作。")
	assert_eq(factory_calls[0], 0, "可用性检查不应创建命令或触发工厂副作用。")
	var unavailable_report: Dictionary = action.get_invocation_report({ "state": state, "allow": false })
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(unavailable_report, "status"), GFEditorActionDefinition.INVOCATION_STATUS_UNAVAILABLE, "调用报告应保留 availability callback 失败原因。")
	assert_false(action.can_invoke({ "state": state, "allow": false }), "严格调用探针应尊重 availability callback。")
	assert_eq(action.invoke({ "state": state, "allow": false }), ERR_UNAVAILABLE, "直接调用也应尊重 availability callback。")
	assert_eq(factory_calls[0], 0, "不可用时调用探针和 invoke 都不应创建命令。")
	assert_eq(action.invoke({ "state": state, "allow": true }), OK, "动作执行时才应创建并执行命令。")
	assert_eq(factory_calls[0], 1, "invoke 应创建一次命令。")
	assert_eq(state.value, 2, "动作执行后应影响目标状态。")


func test_editor_command_registry_resolves_layout_and_invokes_actions() -> void:
	var state: CounterState = CounterState.new()
	var action: GFEditorActionDefinition = GFEditorActionDefinition.new()
	action.action_id = &"increase"
	action.label = "Increase"
	action.group = &"tools"
	action.source_id = &"fixture"
	action.sort_order = 20
	action.command_factory = func(context: Dictionary) -> GFEditorCommand:
		var command: CounterCommand = CounterCommand.new()
		command.target = _context_state(context)
		command.delta = 4
		return command

	var registry: GF_EDITOR_COMMAND_REGISTRY_SCRIPT = GF_EDITOR_COMMAND_REGISTRY_SCRIPT.new()
	var result: Dictionary = registry.register_action(action, {
		"metadata": {
			"owner": "test",
		},
	})
	var snapshots: Array[Dictionary] = registry.get_action_snapshots({ "state": state }, {
		"include_availability": true,
		"include_invocation": true,
	})
	var layout: Dictionary = registry.resolve_layout(PackedStringArray(["increase", "missing"]), { "state": state })
	var invoke: Dictionary = registry.invoke_action(&"increase", { "state": state })
	var first_snapshot: Dictionary = snapshots[0]
	var invocation: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(first_snapshot, "invocation")
	var layout_entries: Array = GF_VARIANT_ACCESS.get_option_array(layout, "entries")
	var missing_ids: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(layout, "missing_ids")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "有效动作应能注册。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(result, "status"), GF_EDITOR_COMMAND_REGISTRY_SCRIPT.STATUS_REGISTERED, "首次注册应报告 registered。")
	assert_eq(registry.get_action_ids(), PackedStringArray(["increase"]), "注册表应能按稳定 ID 列表输出。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(first_snapshot, "group"), &"tools", "快照应包含动作分组。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(first_snapshot, "source_id"), &"fixture", "快照应包含动作来源。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(first_snapshot, "available"), "带上下文时可用性应可计算。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(invocation, "ok"), "动作快照可按需包含调用探针报告。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(invocation, "status"), GFEditorActionDefinition.INVOCATION_STATUS_READY, "调用探针报告应说明动作 ready。")
	assert_eq(layout_entries.size(), 1, "布局解析应返回存在的动作。")
	assert_eq(missing_ids, PackedStringArray(["missing"]), "布局解析应报告缺失的动作 ID。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(invoke, "ok"), "注册表应能按 ID 调用动作。")
	assert_eq(state.value, 4, "按 ID 调用动作应执行底层命令。")


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


func _make_metadata_patch(
	node: Node,
	metadata_key: StringName,
	value: Variant,
	remove_on_execute: bool
) -> GFEditorCommand:
	return _make_typed_metadata_patch(node, metadata_key, value, remove_on_execute)


func _make_typed_metadata_patch(
	node: Node,
	metadata_key: StringName,
	value: Variant,
	remove_on_execute: bool
) -> GFEditorSceneMetadataPatch:
	var command: GFEditorSceneMetadataPatch = GF_EDITOR_SCENE_METADATA_PATCH_SCRIPT.new()
	var _configured_command: Variant = command.call("configure", node, metadata_key, value, {
		"remove_on_execute": remove_on_execute,
	})
	return command


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


class FailingDoCommand extends GFEditorCommand:
	func _do_it() -> Error:
		return ERR_INVALID_DATA


class NonExecutableCommand extends GFEditorCommand:
	func can_execute() -> bool:
		return false


class FakeUndoManager extends RefCounted:
	var do_target: Object
	var do_method: String = ""
	var undo_target: Object
	var undo_method: String = ""


	func create_action(_action_name: String) -> void:
		pass


	func add_do_method(target: Object, method_name: String) -> void:
		do_target = target
		do_method = method_name


	func add_undo_method(target: Object, method_name: String) -> void:
		undo_target = target
		undo_method = method_name


	func add_do_reference(_target: Object) -> void:
		pass


	func add_undo_reference(_target: Object) -> void:
		pass


	func commit_action(execute_immediately: bool = true) -> void:
		if execute_immediately and do_target != null and not do_method.is_empty():
			var _call_result: Variant = do_target.call(do_method)


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
