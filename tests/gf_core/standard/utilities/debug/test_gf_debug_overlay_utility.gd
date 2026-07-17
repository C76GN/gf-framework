extends GutTest


# --- 常量 ---

const GF_AUTOLOAD_NODE_SCRIPT = preload("res://addons/gf/kernel/core/gf.gd")


# --- 私有变量 ---

var _debug: GFDebugOverlayUtility


func before_each() -> void:
	GFAutoload.reset_tree_exit_state()
	var arch: GFArchitecture = GFArchitecture.new()
	Gf._architecture = arch
	_debug = GFDebugOverlayUtility.new()
	_debug.debug_only = false
	await Gf.register_utility(_debug)
	await Gf.set_architecture(arch)
	await get_tree().process_frame


func after_each() -> void:
	GFAutoload.reset_tree_exit_state()
	var arch: GFArchitecture = Gf.get_architecture()
	if arch != null:
		arch.dispose()
		await Gf.set_architecture(GFArchitecture.new())
	await get_tree().process_frame


func test_overlay_is_debug_only_by_default() -> void:
	var overlay: GFDebugOverlayUtility = GFDebugOverlayUtility.new()
	assert_true(overlay.debug_only, "Overlay 默认应只在 debug 构建创建 GUI。")


func test_overlay_creation_and_toggle() -> void:
	var snapshot: Dictionary = _debug.get_debug_snapshot()
	var gui: Dictionary = _gui_snapshot(snapshot)

	assert_true(GFVariantData.get_option_bool(gui, "created"), "Overlay UI 应该被创建。")
	assert_false(GFVariantData.get_option_bool(gui, "visible"), "默认应该隐藏。")

	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_QUOTELEFT
	event.pressed = true
	get_tree().root.push_input(event)

	snapshot = _debug.get_debug_snapshot()
	gui = _gui_snapshot(snapshot)
	assert_true(GFVariantData.get_option_bool(gui, "visible"), "按键触发后应该显示。")


func test_overlay_init_is_idempotent() -> void:
	_debug.init()
	await get_tree().process_frame

	var overlay_count: int = 0
	for child: Node in get_tree().root.get_children():
		if child.name == "GFDebugOverlay":
			overlay_count += 1

	assert_eq(overlay_count, 1, "重复 init 不应创建多个 DebugOverlay GUI。")


func test_dispose_before_deferred_attach_invalidates_pending_callback() -> void:
	var debug_utility: GFDebugOverlayUtility = GFDebugOverlayUtility.new()
	debug_utility.debug_only = false
	debug_utility.init()
	var pending_overlay: CanvasLayer = debug_utility._overlay_gui

	assert_null(pending_overlay.get_parent(), "延迟回调执行前 Overlay 不应提前进入场景树。")

	debug_utility.dispose()
	await get_tree().process_frame

	assert_false(is_instance_valid(pending_overlay), "立即 dispose 后待挂载 Overlay 应安全释放。")
	assert_false(
		GFVariantData.get_option_bool(
			GFVariantData.get_option_dictionary(debug_utility.get_debug_snapshot(), "gui"),
			"created"
		),
		"失效的延迟挂载回调不得重新创建或挂载 Overlay。"
	)


func test_dispose_detaches_overlay_callbacks_before_queue_free() -> void:
	_debug.set_overlay_visible(true)
	var before_snapshot: Dictionary = _debug.get_debug_snapshot()
	var before_gui: Dictionary = _gui_snapshot(before_snapshot)

	assert_true(GFVariantData.get_option_bool(before_gui, "visible"), "dispose 前 overlay 应可被公开 API 显示。")
	assert_true(GFVariantData.get_option_bool(before_gui, "architecture_provider_valid"), "dispose 前架构回调应有效。")
	assert_true(GFVariantData.get_option_bool(before_gui, "watch_snapshot_provider_valid"), "dispose 前 watch 回调应有效。")
	assert_true(GFVariantData.get_option_bool(before_gui, "panel_snapshot_provider_valid"), "dispose 前 panel 回调应有效。")

	_debug.dispose()

	var after_snapshot: Dictionary = _debug.get_debug_snapshot()
	var after_gui: Dictionary = _gui_snapshot(after_snapshot)

	assert_false(GFVariantData.get_option_bool(after_gui, "created"), "dispose 应释放 overlay GUI。")
	assert_eq(GFVariantData.get_option_int(after_snapshot, "watch_count"), 0, "dispose 应清空 watch 注册表。")
	assert_eq(GFVariantData.get_option_int(after_snapshot, "panel_count"), 0, "dispose 应清空 panel 注册表。")


func test_dispose_leaves_overlay_attached_during_autoload_tree_exit() -> void:
	var overlay_gui: CanvasLayer = _debug._overlay_gui
	GFAutoload.begin_tree_exit_scope()

	_debug.dispose()

	assert_not_null(overlay_gui.get_parent(), "AutoLoad 退出时不应重入修改 Debug Overlay 的父节点。")

	GFAutoload.end_tree_exit_scope()
	await get_tree().process_frame
	assert_false(is_instance_valid(overlay_gui), "退出阶段登记 queue_free 后 Debug Overlay 仍应完成释放。")


func test_real_autoload_tree_exit_disposes_overlay_without_reentrant_detach() -> void:
	var current_architecture: GFArchitecture = Gf.get_architecture()
	if current_architecture != null:
		current_architecture.dispose()
	Gf._architecture = GFArchitecture.new()
	_debug = null
	await get_tree().process_frame

	var architecture: GFArchitecture = GFArchitecture.new()
	var debug_utility: GFDebugOverlayUtility = GFDebugOverlayUtility.new()
	debug_utility.debug_only = false
	assert_true(await architecture.register_utility_instance(debug_utility), "测试 Debug Overlay 应成功注册。")
	assert_true(await architecture.init(), "测试架构应成功初始化。")
	await get_tree().process_frame

	var overlay_gui: CanvasLayer = debug_utility._overlay_gui
	var autoload_node: GF_AUTOLOAD_NODE_SCRIPT = GF_AUTOLOAD_NODE_SCRIPT.new()
	autoload_node.name = "GfDebugOverlayExitProbe"
	autoload_node.set(&"_architecture", architecture)
	get_tree().root.add_child(autoload_node)
	get_tree().root.remove_child(autoload_node)

	assert_false(GFAutoload.is_tree_exit_in_progress(), "真实 _exit_tree 返回后应结束退出作用域。")
	assert_not_null(overlay_gui.get_parent(), "真实 AutoLoad 退出期间不应同步拆除 Debug Overlay。")
	assert_true(overlay_gui.is_queued_for_deletion(), "真实 AutoLoad 退出期间应登记 Debug Overlay 延迟释放。")
	autoload_node.free()

	await get_tree().process_frame
	assert_false(is_instance_valid(overlay_gui), "真实 AutoLoad 退出后 Debug Overlay 应完成释放。")


func test_process_model() -> void:
	await Gf.register_model(DebugTestModel.new())
	_debug.set_overlay_visible(true)
	_debug.refresh_overlay()

	var label_text: String = _get_overlay_text()
	assert_true("health" in label_text, "Overlay 应输出 Model 中的变量名。")
	assert_true("100" in label_text, "Overlay 应输出变量的值。")
	assert_true("TestPlayer" in label_text, "Overlay 应输出字符串变量的值。")


func test_push_watch_value_is_rendered_without_models() -> void:
	assert_true(_debug.push_watch_value(&"fps", 60, {
		"label": "FPS",
		"group": "Runtime",
	}), "有效 watch 值应该能注册。")
	_debug.set_overlay_visible(true)

	_debug.refresh_overlay()

	var label_text: String = _get_overlay_text()
	assert_true("Watches: Runtime" in label_text, "Overlay 应输出 watch 分组。")
	assert_true("FPS" in label_text, "Overlay 应输出 watch 标签。")
	assert_true("60" in label_text, "Overlay 应输出 watch 值。")
	assert_false("No GFModels registered." in label_text, "已有 watch 时不应只显示无模型提示。")


func test_watch_text_escapes_bbcode_control_characters() -> void:
	assert_true(_debug.push_watch_value(&"tagged", "[b]42[/b]", {
		"label": "[Label]",
		"group": "[Group]",
	}), "带 BBCode 控制字符的 watch 应该能注册。")
	_debug.set_overlay_visible(true)

	_debug.refresh_overlay()

	var label_text: String = _get_overlay_text()
	assert_true("[lb]Group[rb]" in label_text, "Overlay 应转义 watch 分组中的 BBCode 控制字符。")
	assert_true("[lb]Label[rb]" in label_text, "Overlay 应转义 watch 标签中的 BBCode 控制字符。")
	assert_true("[lb]b[rb]42[lb]/b[rb]" in label_text, "Overlay 应转义 watch 值中的 BBCode 控制字符。")


func test_pushed_watch_value_updates_snapshot() -> void:
	assert_true(_debug.push_watch_value(&"counter", 1), "有效值应该能发布。")

	var snapshot: Array[Dictionary] = _debug.get_watch_snapshot()
	var watch_snapshot: Dictionary = snapshot[0]
	assert_eq(snapshot.size(), 1, "应该返回一个 watch 快照。")
	assert_eq(GFVariantData.get_option_int(watch_snapshot, "value"), 1, "快照应读取已发布值。")

	assert_true(_debug.push_watch_value(&"counter", 2), "同一 id 应能发布新值。")
	snapshot = _debug.get_watch_snapshot()
	watch_snapshot = snapshot[0]
	assert_eq(GFVariantData.get_option_int(watch_snapshot, "value"), 2, "快照应反映最新发布值。")


func test_watch_visibility_and_removal() -> void:
	assert_true(_debug.push_watch_value(&"hidden", "secret", {
		"label": "Hidden",
		"visible": false,
	}), "隐藏 watch 仍应该能注册。")

	assert_true(_debug.has_watch(&"hidden"), "隐藏 watch 应该存在于注册表中。")
	assert_eq(_debug.get_watch_snapshot().size(), 0, "默认快照不应返回隐藏 watch。")
	assert_eq(_debug.get_watch_snapshot(true).size(), 1, "显式 include_hidden 时应返回隐藏 watch。")

	_debug.remove_watch(&"hidden")
	assert_false(_debug.has_watch(&"hidden"), "remove_watch 应移除 watch。")


func test_invalid_watch_registration_is_rejected() -> void:
	assert_false(_debug.push_watch_value(&"", 1), "空 id 的 push watch 应被拒绝。")
	assert_false(_debug.has_watch(&""), "被拒绝的 watch 不应进入注册表。")


func test_pushed_panel_content_is_rendered() -> void:
	assert_true(_debug.push_panel_content(&"state", {
		"ready": true,
	}, {
		"label": "State",
		"group": "Runtime",
	}), "有效 panel 内容应可发布。")

	var snapshot: Array[Dictionary] = _debug.get_panel_snapshot()
	var panel_snapshot: Dictionary = snapshot[0]
	assert_eq(snapshot.size(), 1, "应返回一个 panel 快照。")
	assert_true(GFVariantData.get_option_string(panel_snapshot, "content").contains("ready"), "Dictionary panel 内容应格式化为文本。")

	_debug.set_overlay_visible(true)
	_debug.refresh_overlay()

	var label_text: String = _get_overlay_text()
	assert_true("Panel: Runtime / State" in label_text, "Overlay 应输出 panel 标题。")
	assert_true("ready" in label_text, "Overlay 应输出 panel 内容。")


func test_panel_visibility_and_removal() -> void:
	assert_true(_debug.push_panel_text(&"hidden_panel", "secret", {
		"visible": false,
	}), "隐藏 panel 仍应注册。")

	assert_true(_debug.has_panel(&"hidden_panel"), "隐藏 panel 应存在于注册表。")
	assert_eq(_debug.get_panel_snapshot().size(), 0, "默认不应返回隐藏 panel。")
	assert_eq(_debug.get_panel_snapshot(true).size(), 1, "include_hidden 时应返回隐藏 panel。")

	_debug.remove_panel(&"hidden_panel")
	assert_false(_debug.has_panel(&"hidden_panel"), "remove_panel 应移除 panel。")


func test_invalid_panel_registration_is_rejected() -> void:
	assert_false(_debug.push_panel_text(&"", "empty"), "空 id 的 panel 应被拒绝。")
	assert_false(_debug.has_panel(&""), "被拒绝的 panel 不应进入注册表。")


func test_snapshot_never_executes_callable_values() -> void:
	var state: OverlayValueState = OverlayValueState.new()
	assert_true(_debug.push_watch_value(&"callable", Callable(state, "get_value")), "Callable 可作为待报告值发布。")

	var snapshot: Array[Dictionary] = _debug.get_watch_snapshot()

	assert_eq(snapshot.size(), 1, "已发布值应进入快照。")
	assert_eq(state.call_count, 0, "读取 Overlay 快照不得执行外部 Callable。")


func test_pushed_values_and_output_are_bounded() -> void:
	_debug.max_value_collection_items = 2
	_debug.max_value_snapshot_nodes = 16
	_debug.max_panel_content_chars = 64
	var values: Array[int] = []
	for index: int in range(1000):
		values.append(index)
	assert_true(_debug.push_watch_value(&"large_watch", values), "大型 watch 应在发布边界被编码。")
	assert_true(_debug.push_panel_content(&"large", values), "大型 panel 应在发布边界被编码。")

	var watches: Array[Dictionary] = _debug.get_watch_snapshot()
	var panels: Array[Dictionary] = _debug.get_panel_snapshot()
	var content: String = GFVariantData.get_option_string(panels[0], "content")

	assert_eq(watches.size(), 1, "有界编码不应丢失 watch 条目。")
	assert_lte(content.length(), 76, "面板最终文本应受字符预算限制。")
	assert_true(content.contains("CollectionBudget") or content.contains("<truncated>"), "大型容器输出应暴露截断状态。")


func _get_overlay_text() -> String:
	var snapshot: Dictionary = _debug.get_debug_snapshot()
	var gui: Dictionary = _gui_snapshot(snapshot)
	return GFVariantData.get_option_string(gui, "text")


func _gui_snapshot(snapshot: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(snapshot, "gui"))


class DebugTestModel extends GFModel:
	var health: int = 100
	var player_name: String = "TestPlayer"


class OverlayValueState:
	extends RefCounted

	var call_count: int = 0

	func get_value() -> int:
		call_count += 1
		return call_count
