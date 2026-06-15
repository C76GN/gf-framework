extends GutTest


var _debug: GFDebugOverlayUtility


func before_each() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	Gf._architecture = arch
	_debug = GFDebugOverlayUtility.new()
	_debug.debug_only = false
	await Gf.register_utility(_debug)
	await Gf.set_architecture(arch)
	await get_tree().process_frame


func after_each() -> void:
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


func test_watch_value_provider_updates_snapshot() -> void:
	var state: IntState = IntState.new()
	state.value = 1
	assert_true(_debug.watch_value(&"counter", func() -> int:
		return state.value
	), "有效 provider 应该能注册。")

	var snapshot: Array[Dictionary] = _debug.get_watch_snapshot()
	var watch_snapshot: Dictionary = snapshot[0]
	assert_eq(snapshot.size(), 1, "应该返回一个 watch 快照。")
	assert_eq(GFVariantData.get_option_int(watch_snapshot, "value"), 1, "快照应读取 provider 的当前值。")

	state.value = 2
	snapshot = _debug.get_watch_snapshot()
	watch_snapshot = snapshot[0]
	assert_eq(GFVariantData.get_option_int(watch_snapshot, "value"), 2, "provider watch 应在读取快照时更新。")


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
	assert_false(_debug.watch_value(&"invalid", Callable()), "无效 provider 应被拒绝。")
	assert_false(_debug.has_watch(&"invalid"), "被拒绝的 watch 不应进入注册表。")


func test_panel_provider_is_rendered() -> void:
	var provider: Callable = func() -> Dictionary:
		return {
			"ready": true,
		}
	assert_true(_debug.register_panel(&"state", provider, {
		"label": "State",
		"group": "Runtime",
	}), "有效 panel provider 应可注册。")

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
	assert_false(_debug.register_panel(&"invalid_panel", Callable()), "无效 panel provider 应被拒绝。")
	assert_false(_debug.has_panel(&"invalid_panel"), "被拒绝的 panel 不应进入注册表。")


func _get_overlay_text() -> String:
	var snapshot: Dictionary = _debug.get_debug_snapshot()
	var gui: Dictionary = _gui_snapshot(snapshot)
	return GFVariantData.get_option_string(gui, "text")


func _gui_snapshot(snapshot: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(snapshot, "gui"))


class DebugTestModel extends GFModel:
	var health: int = 100
	var player_name: String = "TestPlayer"


class IntState:
	extends RefCounted

	var value: int = 0
