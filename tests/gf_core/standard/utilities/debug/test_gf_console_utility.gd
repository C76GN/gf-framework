## 测试 GFConsoleUtility 的命令注册、执行与日志信号解绑行为。
extends GutTest

var _console: GFConsoleUtility
var _subscriptions: Array[GFLifetimeSubscription] = []


func before_each() -> void:
	_subscriptions.clear()
	_console = GFConsoleUtility.new()
	_console.debug_only = false
	_console.init()
	await get_tree().process_frame


func after_each() -> void:
	for subscription: GFLifetimeSubscription in _subscriptions:
		var _cancelled: bool = subscription.cancel()
	_subscriptions.clear()
	GFAutoload.reset_tree_exit_state()
	if _console != null:
		_console.dispose()
		_console = null

	if Gf._architecture != null:
		Gf._architecture.dispose()
		Gf._architecture = null

	await get_tree().process_frame


func test_register_command() -> void:
	var called: CommandCallState = CommandCallState.new()
	var cb: Callable = func(_args: PackedStringArray) -> void:
		called.count += 1

	_register_command("test_cmd", cb, "测试指令。")
	assert_true(_console.has_command("test_cmd"), "register_command 后应记录命令。")


func test_register_command_rejects_empty_name_and_invalid_callback() -> void:
	_register_command("", Callable(), "空指令。")
	assert_push_warning("[GFConsoleUtility] 注册命令失败：命令名为空。")
	_register_command("broken", Callable(), "无效回调。")
	assert_push_warning("[GFConsoleUtility] 注册命令失败：callback 无效：broken。")

	assert_false(_console.has_command(""), "空命令名不应进入命令表。")
	assert_false(_console.has_command("broken"), "无效 callback 不应进入命令表。")
	assert_false(_console.execute_command("broken"), "无效 callback 命令不应可执行。")


func test_builtin_help_registered() -> void:
	assert_true(_console.has_command("help"), "init 后应注册内置 help 指令。")


func test_builtin_clear_registered() -> void:
	assert_true(_console.has_command("clear"), "init 后应注册内置 clear 指令。")


func test_builtin_scene_commands_registered_as_observe() -> void:
	var catalog: Dictionary = _console.get_command_catalog()
	var scene_tree_entry: Dictionary = GFVariantData.get_option_dictionary(catalog, "scene.tree")

	assert_true(_console.has_command("scene.tree"), "init 后应注册只读场景树指令。")
	assert_true(_console.has_command("scene.node"), "init 后应注册只读节点查看指令。")
	assert_eq(GFVariantData.get_option_int(scene_tree_entry, "tier"), GFConsoleUtility.CommandTier.OBSERVE, "scene.tree 应是观察级命令。")


func test_init_is_idempotent_for_console_overlay() -> void:
	_console.init()
	await get_tree().process_frame

	assert_eq(_count_console_overlays(), 1, "重复 init 不应创建多个控制台 overlay。")


func test_subscription_cancels_command_registration() -> void:
	var cb: Callable = func(_args: PackedStringArray) -> void:
		pass

	var subscription: GFLifetimeSubscription = _console.register_command(self, "temp_cmd", cb, "临时指令。")
	assert_true(_console.has_command("temp_cmd"), "注册后命令应存在。")

	assert_true(subscription.cancel(), "首次取消注册句柄应成功。")
	assert_false(_console.has_command("temp_cmd"), "注销后命令应被移除。")


func test_registration_owner_cannot_be_replaced_by_another_owner() -> void:
	var first_owner: Object = Object.new()
	var other_owner: Object = Object.new()
	var callback: Callable = func(_args: PackedStringArray) -> void:
		pass

	var first: GFLifetimeSubscription = _console.register_command(first_owner, "owned", callback, "Owned。")
	var rejected: GFLifetimeSubscription = _console.register_command(other_owner, "owned", callback, "Rejected。")

	assert_true(first.is_active(), "首个 owner 的注册句柄应激活。")
	assert_false(rejected.is_active(), "其他 owner 不应抢占同名命令。")
	assert_true(_console.has_command("owned"), "被拒绝的注册不应破坏原命令。")
	first_owner.free()
	other_owner.free()


func test_released_owner_command_is_pruned_before_execution() -> void:
	var command_owner: Object = Object.new()
	var called: CommandCallState = CommandCallState.new()
	var callback: Callable = func(_args: PackedStringArray) -> void:
		called.count += 1
	var subscription: GFLifetimeSubscription = _console.register_command(command_owner, "released", callback, "Released。")
	assert_true(subscription.is_active(), "有效 owner 应得到激活句柄。")

	command_owner.free()

	assert_false(_console.has_command("released"), "owner 释放后命令应在查询时清理。")
	assert_false(_console.execute_command("released"), "owner 释放后命令不应执行。")
	assert_eq(called.count, 0, "失效 owner 的回调不得被调用。")


func test_get_command_names_returns_sorted_names() -> void:
	var cb: Callable = func(_args: PackedStringArray) -> void:
		pass

	_register_command("zeta", cb, "Z。")
	_register_command("alpha", cb, "A。")
	var names: PackedStringArray = _console.get_command_names()

	assert_true(names.find("alpha") < names.find("zeta"), "命令名应按字典序返回。")


func test_suggest_commands_filters_by_prefix() -> void:
	var cb: Callable = func(_args: PackedStringArray) -> void:
		pass

	_register_command("teleport", cb, "传送。")
	_register_command("time_scale", cb, "时间。")
	_register_command("spawn", cb, "生成。")
	var suggestions: PackedStringArray = _console.suggest_commands("t")

	assert_true(suggestions.has("teleport"), "前缀匹配应返回 teleport。")
	assert_true(suggestions.has("time_scale"), "前缀匹配应返回 time_scale。")
	assert_false(suggestions.has("spawn"), "不匹配前缀的命令不应返回。")


func test_suggest_command_arguments_uses_definition_suggester() -> void:
	var definition: GFConsoleCommandDefinition = GFConsoleCommandDefinition.new()
	definition.command_name = "teleport"
	definition.aliases = PackedStringArray(["tp"])
	definition.argument_suggester = func(context: Dictionary) -> PackedStringArray:
		assert_eq(GFVariantData.get_option_string(context, "command_name"), "tp", "补全上下文应使用当前输入的命令名。")
		assert_eq(GFVariantData.get_option_int(context, "argument_index"), 0, "第一个参数应报告 index 0。")
		return PackedStringArray(["player", "portal", "enemy"])
	var cb: Callable = func(_args: PackedStringArray) -> void:
		pass

	_register_command_definition(definition, cb)
	var suggestions: PackedStringArray = _console.suggest_command_arguments("tp p")

	assert_eq(suggestions, PackedStringArray(["player", "portal"]), "参数补全应按当前前缀过滤并排序。")


func test_console_tab_completion_applies_single_argument_suggestion() -> void:
	var cb: Callable = func(_args: PackedStringArray) -> void:
		pass
	_register_command("spawn", cb, "生成。", {
		"argument_suggester": func(_context: Dictionary) -> PackedStringArray:
			return PackedStringArray(["slime"])
	})

	_console._console_gui._input_field.text = "spawn sl"
	_console._console_gui._apply_command_completion()

	assert_eq(_console._console_gui._input_field.text, "spawn slime ", "Tab 应把唯一参数候选写回当前参数位置。")


func test_suggest_similar_commands_returns_likely_matches() -> void:
	var cb: Callable = func(_args: PackedStringArray) -> void:
		pass

	_register_command("teleport", cb, "传送。")
	_register_command("time_scale", cb, "时间。")
	var suggestions: PackedStringArray = _console.suggest_similar_commands("teleprt")

	assert_gt(suggestions.size(), 0, "拼写接近已注册命令时应返回候选。")
	assert_eq(suggestions[0], "teleport", "最接近的命令应排在第一位。")


func test_execute_command_calls_callback() -> void:
	var called: CommandCallState = CommandCallState.new()
	var cb: Callable = func(_args: PackedStringArray) -> void:
		called.count += 1

	_register_command("inc", cb, "递增计数器。")
	var result: bool = _console.execute_command("inc")

	assert_true(result, "已注册指令执行后应返回 true。")
	assert_eq(called.count, 1, "回调应被调用一次。")


func test_execute_command_passes_args() -> void:
	var captured_args: PackedStringArray = PackedStringArray()
	var cb: Callable = func(args: PackedStringArray) -> void:
		for a: String in args:
			var _append_result_116: Variant = captured_args.append(a)

	_register_command("echo", cb, "回显参数。")
	var _execute_command_result_119: Variant = _console.execute_command("echo hello world")

	assert_eq(captured_args.size(), 2, "参数数量应为 2。")
	assert_eq(captured_args[0], "hello", "第一个参数应为 hello。")
	assert_eq(captured_args[1], "world", "第二个参数应为 world。")


func test_execute_command_supports_quotes_and_escapes() -> void:
	var captured_args: PackedStringArray = PackedStringArray()
	var cb: Callable = func(args: PackedStringArray) -> void:
		for a: String in args:
			var _append_result_130: Variant = captured_args.append(a)

	_register_command("echo", cb, "回显参数。")
	var _execute_command_result_133: Variant = _console.execute_command("echo \"red potion\" path\\ with\\ spaces ''")

	assert_eq(captured_args, PackedStringArray(["red potion", "path with spaces", ""]), "命令解析应支持引号、转义空格和空字符串参数。")


func test_danger_command_requires_tier_and_confirmation() -> void:
	var called: CommandCallState = CommandCallState.new()
	var cb: Callable = func(args: PackedStringArray) -> void:
		called.count += 1
		called.args = args

	_register_command("wipe", cb, "危险指令。", { "tier": GFConsoleUtility.CommandTier.DANGER })

	assert_false(_console.execute_command("wipe"), "默认最高 CONTROL 时不应执行 DANGER 指令。")
	_console.max_command_tier = GFConsoleUtility.CommandTier.DANGER
	assert_false(_console.execute_command("wipe"), "DANGER 指令缺少确认参数时不应执行。")
	assert_true(_console.execute_command("wipe --confirm slot_1"), "DANGER 指令带确认参数后应执行。")
	assert_eq(called.count, 1, "危险指令只应成功执行一次。")
	assert_eq(called.args, PackedStringArray(["slot_1"]), "确认参数不应传入业务回调。")


func test_register_command_definition_registers_aliases() -> void:
	var definition: GFConsoleCommandDefinition = GFConsoleCommandDefinition.new()
	definition.command_name = "primary"
	definition.aliases = PackedStringArray(["alias"])
	var called: CommandCallState = CommandCallState.new()
	var cb: Callable = func(_args: PackedStringArray) -> void:
		called.count += 1

	_register_command_definition(definition, cb)
	var result: bool = _console.execute_command("alias")

	assert_true(result, "资源化命令别名应可执行。")
	assert_eq(called.count, 1, "别名应调用同一回调。")


func test_definition_subscription_removes_all_names() -> void:
	var definition: GFConsoleCommandDefinition = GFConsoleCommandDefinition.new()
	definition.command_name = "primary"
	definition.aliases = PackedStringArray(["alias"])
	var cb: Callable = func(_args: PackedStringArray) -> void:
		pass

	var subscription: GFLifetimeSubscription = _console.register_command_definition(self, definition, cb)
	assert_true(subscription.cancel(), "定义注册句柄应可取消。")

	assert_false(_console.has_command("primary"), "从别名注销资源化命令时应移除主命令。")
	assert_false(_console.has_command("alias"), "从别名注销资源化命令时应移除别名。")


func test_stale_definition_subscription_preserves_replaced_alias() -> void:
	var definition: GFConsoleCommandDefinition = GFConsoleCommandDefinition.new()
	definition.command_name = "primary"
	definition.aliases = PackedStringArray(["alias"])
	var definition_callback: Callable = func(_args: PackedStringArray) -> void:
		pass
	var replacement_state: CommandCallState = CommandCallState.new()
	var replacement_callback: Callable = func(_args: PackedStringArray) -> void:
		replacement_state.count += 1

	var definition_subscription: GFLifetimeSubscription = _console.register_command_definition(self, definition, definition_callback)
	var replacement_subscription: GFLifetimeSubscription = _console.register_command(self, "alias", replacement_callback, "替代命令。")
	assert_true(replacement_subscription.is_active(), "同一 owner 应能替换单个别名。")
	assert_true(definition_subscription.cancel(), "旧定义句柄应可取消。")
	var executed: bool = _console.execute_command("alias")

	assert_false(_console.has_command("primary"), "注销定义应移除仍由定义拥有的主命令。")
	assert_true(_console.has_command("alias"), "注销定义不应移除已被其他注册覆盖的别名。")
	assert_true(executed, "覆盖后的别名应仍可执行。")
	assert_eq(replacement_state.count, 1, "覆盖后的别名应调用新注册者的回调。")


func test_command_catalog_redacts_runtime_metadata() -> void:
	var definition: GFConsoleCommandDefinition = GFConsoleCommandDefinition.new()
	definition.command_name = "teleport"
	definition.aliases = PackedStringArray(["tp"])
	definition.argument_suggester = func(_context: Dictionary) -> PackedStringArray:
		return PackedStringArray(["player"])
	var cb: Callable = func(_args: PackedStringArray) -> void:
		pass

	_register_command_definition(definition, cb)
	var catalog: Dictionary = _console.get_command_catalog()
	var entry: Dictionary = GFVariantData.get_option_dictionary(catalog, "teleport")
	var metadata: Dictionary = GFVariantData.get_option_dictionary(entry, "metadata")

	assert_false(metadata.has("definition"), "公开命令目录不应泄漏 Resource definition。")
	assert_false(metadata.has("argument_suggester"), "公开命令目录不应泄漏 Callable。")
	assert_eq(GFVariantData.get_option_string(metadata, "primary_command_name"), "teleport", "安全元数据仍应保留。")


func test_register_command_definition_preserves_metadata_tier() -> void:
	var definition: GFConsoleCommandDefinition = GFConsoleCommandDefinition.new()
	definition.command_name = "resource_wipe"
	definition.metadata = { "tier": GFConsoleUtility.CommandTier.DANGER }
	var called: CommandCallState = CommandCallState.new()
	var cb: Callable = func(_args: PackedStringArray) -> void:
		called.count += 1

	_register_command_definition(definition, cb)

	assert_false(_console.execute_command("resource_wipe"), "资源化 DANGER 命令默认应被风险等级拒绝。")
	_console.max_command_tier = GFConsoleUtility.CommandTier.DANGER
	assert_false(_console.execute_command("resource_wipe"), "资源化 DANGER 命令缺少确认参数时仍应拒绝。")
	assert_true(_console.execute_command("resource_wipe --confirm"), "资源化 DANGER 命令确认后应可执行。")
	assert_eq(called.count, 1, "资源化 DANGER 命令只应成功执行一次。")


func test_execute_unknown_command_returns_false() -> void:
	var result: bool = _console.execute_command("nonexistent_cmd")
	assert_false(result, "未知指令应返回 false。")


func test_execute_empty_input_returns_false() -> void:
	var result: bool = _console.execute_command("")
	assert_false(result, "空字符串输入应返回 false。")


func test_execute_whitespace_only_returns_false() -> void:
	var result: bool = _console.execute_command("   ")
	assert_false(result, "纯空白输入应返回 false。")


func test_console_output_keeps_max_lines() -> void:
	_console.max_output_lines = 2
	_console.append_output_line("line-1")
	_console.append_output_line("line-2")
	_console.append_output_line("line-3")
	_console.flush_output()
	var output_lines: PackedStringArray = _get_console_output_lines()

	assert_eq(output_lines.size(), 2, "控制台输出应按上限裁剪。")
	assert_eq(output_lines[0], "line-2", "控制台应丢弃最旧输出。")
	assert_eq(output_lines[1], "line-3", "控制台应保留最新输出。")


func test_console_output_batches_until_flush() -> void:
	_console.append_output_line("batched")

	assert_eq(_get_console_output_lines().size(), 0, "批量刷新前不应立即重绘输出。")

	_console.flush_output()
	var output_lines: PackedStringArray = _get_console_output_lines()

	assert_eq(output_lines.size(), 1, "flush 后应写入待输出行。")
	assert_eq(output_lines[0], "batched", "flush 后应保留待输出内容。")


func test_scene_tree_command_outputs_readonly_summary() -> void:
	var previous_scene: Node = get_tree().current_scene
	var root: Node = Node.new()
	root.name = "ConsoleSceneRoot"
	var child: Node = Node.new()
	child.name = "Child"
	root.add_child(child)
	get_tree().root.add_child(root)
	get_tree().current_scene = root

	assert_true(_console.execute_command("scene.tree 1 10"), "scene.tree 指令应可执行。")
	_console.flush_output()
	var output: String = "\n".join(_get_console_output_lines())

	assert_true(output.contains("ConsoleSceneRoot"), "场景树输出应包含当前场景根节点。")
	assert_true(output.contains("Child"), "场景树输出应包含子节点。")

	get_tree().current_scene = previous_scene
	root.queue_free()


func test_scene_node_command_outputs_node_summary() -> void:
	var previous_scene: Node = get_tree().current_scene
	var root: Node = Node.new()
	root.name = "ConsoleNodeRoot"
	var child: Node = Node.new()
	child.name = "Target"
	root.add_child(child)
	get_tree().root.add_child(root)
	get_tree().current_scene = root

	assert_true(_console.execute_command("scene.node Target"), "scene.node 指令应可执行。")
	_console.flush_output()
	var output: String = "\n".join(_get_console_output_lines())

	assert_true(output.contains("Target"), "节点摘要应包含目标节点路径或名称。")
	assert_true(output.contains("type:"), "节点摘要应包含类型字段。")

	get_tree().current_scene = previous_scene
	root.queue_free()


func test_console_escapes_log_bbcode_and_handles_negative_level() -> void:
	_console._on_log_emitted(-1, "[tag]", "[b]message[/b]")
	_console.flush_output()
	var line: String = String(_get_console_output_lines()[0])

	assert_true(line.contains("UNKNOWN"), "非法日志等级应显示为 UNKNOWN。")
	assert_false(line.contains("[b]message[/b]"), "日志正文中的 BBCode 不应被原样注入 RichText。")
	assert_false(line.contains("[tag]"), "日志标签中的 BBCode 不应被原样注入 RichText。")


func test_console_history_keeps_max_entries() -> void:
	_console._console_gui.max_history_size = 2

	_console._console_gui._on_input_submitted("one")
	_console._console_gui._on_input_submitted("two")
	_console._console_gui._on_input_submitted("three")

	assert_eq(_get_console_command_history(), PackedStringArray(["two", "three"]), "命令历史应按上限裁剪。")


func test_console_background_alpha_updates_gui() -> void:
	_console.background_alpha = 0.42

	var gui_snapshot: Dictionary = _get_console_gui_snapshot()
	assert_almost_eq(_console.background_alpha, 0.42, 0.001, "控制台透明度配置应保存在工具上。")
	assert_almost_eq(GFVariantData.get_option_float(gui_snapshot, "background_alpha"), 0.42, 0.001, "控制台透明度配置应同步到 GUI。")
	assert_almost_eq(GFVariantData.get_option_float(gui_snapshot, "panel_background_alpha"), 0.42, 0.001, "GUI 背景样式应立即应用透明度。")


func test_console_background_alpha_is_clamped() -> void:
	_console.background_alpha = 2.0

	var gui_snapshot: Dictionary = _get_console_gui_snapshot()
	assert_almost_eq(_console.background_alpha, 1.0, 0.001, "透明度上限应被钳制为 1。")
	assert_almost_eq(GFVariantData.get_option_float(gui_snapshot, "panel_background_alpha"), 1.0, 0.001, "GUI 样式透明度也应应用钳制结果。")


func test_console_windowed_mode_uses_panel_layout_and_resize_handle() -> void:
	_console.windowed = true
	var gui_snapshot: Dictionary = _get_console_gui_snapshot()

	assert_true(GFVariantData.get_option_bool(gui_snapshot, "windowed"), "窗口模式配置应同步到 GUI。")
	assert_true(GFVariantData.get_option_bool(gui_snapshot, "resize_handle_visible"), "窗口模式应显示缩放手柄。")
	var panel_size: Vector2 = GFVariantData.get_option_vector2(gui_snapshot, "panel_size")
	assert_gt(panel_size.x, 0.0, "窗口模式应给面板设置有效宽度。")
	assert_gt(panel_size.y, 0.0, "窗口模式应给面板设置有效高度。")


func test_console_keep_topmost_updates_layer() -> void:
	_console.keep_topmost = false
	assert_eq(GFVariantData.get_option_int(_get_console_gui_snapshot(), "layer"), 1, "关闭 keep_topmost 后应使用普通层级。")

	_console.keep_topmost = true
	assert_eq(GFVariantData.get_option_int(_get_console_gui_snapshot(), "layer"), 150, "开启 keep_topmost 后应使用高层级。")


func test_console_is_debug_only_by_default() -> void:
	var console: GFConsoleUtility = GFConsoleUtility.new()

	assert_true(console.debug_only, "控制台默认应只在 debug 构建启用。")


func test_dispose_detaches_console_gui_immediately() -> void:
	var gui: CanvasLayer = _console._console_gui

	_console.dispose()
	_console = null

	assert_null(gui.get_parent(), "dispose 应立即从 SceneTree.root 移除控制台 GUI。")

	await get_tree().process_frame
	assert_false(is_instance_valid(gui), "下一帧控制台 GUI 应完成释放。")


func test_dispose_leaves_console_attached_during_autoload_tree_exit() -> void:
	var gui: CanvasLayer = _console._console_gui
	GFAutoload.begin_tree_exit_scope()

	_console.dispose()
	_console = null

	assert_not_null(gui.get_parent(), "AutoLoad 退出时不应重入修改控制台 GUI 的父节点。")

	GFAutoload.end_tree_exit_scope()
	await get_tree().process_frame
	assert_false(is_instance_valid(gui), "退出阶段登记 queue_free 后仍应完成释放。")


func test_dispose_disconnects_log_signal() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var log_util: GFLogUtility = GFLogUtility.new()
	var console: GFConsoleUtility = GFConsoleUtility.new()

	await arch.register_utility_instance(log_util)
	await arch.register_utility_instance(console)
	await Gf.set_architecture(arch)

	var log_callable: Callable = Callable(console, "_on_log_emitted")
	assert_true(log_util.log_emitted.is_connected(log_callable), "ready 后控制台应连接日志信号。")

	assert_true(
		await arch.unregister_utility(_script_from_object(console))
	)
	assert_false(log_util.log_emitted.is_connected(log_callable), "dispose 后应断开日志信号，避免悬挂监听。")


func _register_command(
	command_name: String,
	callback: Callable,
	description: String,
	metadata: Dictionary = {}
) -> void:
	var subscription: GFLifetimeSubscription = _console.register_command(
		self,
		command_name,
		callback,
		description,
		metadata
	)
	if subscription.is_active():
		_subscriptions.append(subscription)


func _register_command_definition(definition: GFConsoleCommandDefinition, callback: Callable) -> void:
	var subscription: GFLifetimeSubscription = _console.register_command_definition(self, definition, callback)
	if subscription.is_active():
		_subscriptions.append(subscription)


func _get_console_gui_snapshot() -> Dictionary:
	var snapshot: Dictionary = _console.get_debug_snapshot()
	return GFVariantData.get_option_dictionary(snapshot, "gui")


func _get_console_output_lines() -> PackedStringArray:
	var gui_snapshot: Dictionary = _get_console_gui_snapshot()
	return GFVariantData.get_option_packed_string_array(gui_snapshot, "output_lines")


func _get_console_command_history() -> PackedStringArray:
	var gui_snapshot: Dictionary = _get_console_gui_snapshot()
	return GFVariantData.get_option_packed_string_array(gui_snapshot, "command_history")


func _count_console_overlays() -> int:
	var count: int = 0
	for child: Node in get_tree().root.get_children():
		if child.name == "GFConsoleOverlay":
			count += 1
	return count


func _script_from_object(object: Object) -> Script:
	var script_value: Variant = object.get_script()
	if script_value is Script:
		var script: Script = script_value
		return script
	return null


# --- 内部类 ---

class CommandCallState:
	var count: int = 0
	var args: PackedStringArray = PackedStringArray()
