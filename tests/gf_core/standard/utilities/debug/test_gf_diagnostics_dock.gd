extends GutTest


# --- 测试方法 ---

func test_diagnostics_dock_collects_runtime_snapshot() -> void:
	var dock: GFDiagnosticsDock = GFDiagnosticsDock.new()

	dock.collect_snapshot()
	var snapshot: Dictionary = dock.get_last_snapshot()
	var dock_snapshot: Dictionary = dock.get_debug_snapshot()
	var monitors: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(snapshot, "monitors")
	)

	assert_false(snapshot.is_empty(), "Diagnostics 页面应能采集快照。")
	assert_true(snapshot.has("performance"), "诊断快照应包含性能分区。")
	assert_true(snapshot.has("monitors"), "诊断快照应包含监控分区。")
	assert_gt(GFVariantData.get_option_int(monitors, "monitor_count"), 0, "诊断快照应采集内置监控项。")
	assert_false(GFVariantData.get_option_string(dock_snapshot, "details_text").is_empty(), "Diagnostics 页面右侧应默认展示快照内容。")

	dock.free()


func test_runtime_debugger_tab_renders_debugger_payloads() -> void:
	var tab: GFRuntimeDebuggerTab = GFRuntimeDebuggerTab.new()

	tab.handle_snapshot({
		"performance": { "fps": 60.0 },
		"architecture": {
			"models": {},
			"systems": {},
			"utilities": {},
		},
	})
	tab.handle_catalog({
		"commands": {
			"diagnostics.snapshot": {},
		},
		"monitors": {
			"performance.fps": {},
		},
	})
	tab.handle_command_result(&"diagnostics.performance", {
		"ok": true,
		"value": { "fps": 60.0 },
	})

	var snapshot: Dictionary = tab.get_debug_snapshot()
	var ui: Dictionary = GFVariantData.get_option_dictionary(snapshot, "ui")
	var command_result: Dictionary = GFVariantData.get_option_dictionary(snapshot, "last_command_result")

	assert_false(GFVariantData.get_option_dictionary(snapshot, "last_snapshot").is_empty(), "Debugger 页应保存最近快照。")
	assert_false(GFVariantData.get_option_dictionary(snapshot, "last_catalog").is_empty(), "Debugger 页应保存最近目录。")
	assert_eq(GFVariantData.get_option_string_name(command_result, "command_name"), &"diagnostics.performance", "Debugger 页应保存最近命令名。")
	assert_true(GFVariantData.get_option_bool(ui, "tree_visible"), "渲染 payload 后树应可见。")
	assert_true(GFVariantData.get_option_string(ui, "details").contains("diagnostics.performance"), "详情 JSON 应包含最近命令。")

	tab.free()


func test_debug_editor_panels_share_report_safe_json_codec() -> void:
	var panels: Array[Control] = [
		GFDiagnosticsDock.new(),
		GFRuntimeDebuggerTab.new(),
		GFSignalGraphDock.new(),
	]
	var payload: Dictionary = {
		"value": NAN,
		"color": Color.RED,
		"owner": self,
	}

	for panel: Control in panels:
		var json_text: String = GFVariantData.to_text(panel.call("_safe_json", payload))
		assert_true(json_text.contains("\"Float\""), "Editor JSON 应通过 typed marker 编码 NaN。")
		assert_true(json_text.contains("\"Color\""), "Editor JSON 应通过 typed marker 编码 Color。")
		assert_true(json_text.contains("__gf_report_value__"), "Editor JSON 应脱敏运行时 Object。")
		assert_false(json_text.contains("\"value\":null"), "Editor JSON 不应把 NaN 退化为 null。")
		panel.free()
