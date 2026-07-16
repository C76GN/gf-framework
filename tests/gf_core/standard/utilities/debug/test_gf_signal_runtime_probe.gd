## 测试 GFSignalRuntimeProbe 的运行时信号追踪能力。
extends GutTest


# --- 测试方法 ---

func test_probe_records_watched_signal_emissions() -> void:
	var source: SignalSource = SignalSource.new()
	source.name = "Source"
	var probe: GFSignalRuntimeProbe = GFSignalRuntimeProbe.new()

	var report: Dictionary = probe.watch_node(source, {
		"include_signals": [&"no_args", &"value_changed", &"pair_changed"],
	})
	source.no_args.emit()
	source.value_changed.emit(42)
	source.pair_changed.emit("left", true)

	var events: Array[Dictionary] = probe.get_events()
	var no_args_event: Dictionary = events[0]
	var first_value_event: Dictionary = events[1]
	var pair_event: Dictionary = events[2]
	var first_arguments: Array = GFVariantData.as_array(GFVariantData.get_option_value(first_value_event, "arguments"))
	var second_arguments: Array = GFVariantData.as_array(GFVariantData.get_option_value(pair_event, "arguments"))

	assert_true(GFVariantData.get_option_bool(report, "ok"), "监听指定信号应成功。")
	assert_eq(GFVariantData.get_option_int(report, "watched_count"), 3, "应监听三个指定信号。")
	assert_eq(events.size(), 3, "三次发射都应被记录。")
	assert_eq(GFVariantData.get_option_string(no_args_event, "signal_name"), "no_args", "零参数信号应被记录。")
	assert_eq(GFVariantData.to_int(first_arguments[0]), 42, "单参数信号应记录参数。")
	assert_true(GFVariantData.to_bool(second_arguments[1]), "多参数信号应记录全部参数。")

	var _unwatch_all_result_30: Variant = probe.unwatch_all()
	source.free()


func test_probe_records_wide_signal_payload() -> void:
	var source: SignalSource = SignalSource.new()
	var probe: GFSignalRuntimeProbe = GFSignalRuntimeProbe.new()

	var report: Dictionary = probe.watch_node(source, {
		"include_signals": [&"wide_payload"],
	})
	source.wide_payload.emit(0, 1, 2, 3, 4, 5, 6, 7, 8)

	var events: Array[Dictionary] = probe.get_events()
	var wide_event: Dictionary = events[0]
	var arguments: Array = GFVariantData.as_array(GFVariantData.get_option_value(wide_event, "arguments"))

	assert_true(GFVariantData.get_option_bool(report, "ok"), "9 参数信号应能被运行时探针监听。")
	assert_eq(events.size(), 1, "9 参数信号发射应被记录。")
	assert_eq(arguments.size(), 9, "运行时探针应保留 9 参数 payload。")
	assert_eq(GFVariantData.to_int(arguments[8]), 8, "运行时探针应保留第 9 个参数。")

	var _unwatch_all_result_51: Variant = probe.unwatch_all()
	source.free()


func test_probe_snapshots_object_arguments_without_live_references() -> void:
	var source: SignalSource = SignalSource.new()
	autofree(source)
	var payload: Resource = Resource.new()
	payload.resource_name = "Payload"
	payload.take_over_path("res://private/payload.tres")
	var probe: GFSignalRuntimeProbe = GFSignalRuntimeProbe.new()

	var report: Dictionary = probe.watch_node(source, {
		"include_signals": [&"object_payload"],
	})
	source.object_payload.emit(payload)

	var events: Array[Dictionary] = probe.get_events()
	var event: Dictionary = events[0]
	var arguments: Array = GFVariantData.as_array(GFVariantData.get_option_value(event, "arguments"))
	var argument_snapshot: Dictionary = GFVariantData.as_dictionary(arguments[0])
	var exported_events: Array[Dictionary] = probe.get_json_compatible_events()
	var exported_event: Dictionary = exported_events[0]
	var exported_arguments: Array = GFVariantData.get_option_array(exported_event, "arguments")
	var exported_argument_snapshot: Dictionary = GFVariantData.as_dictionary(exported_arguments[0])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "对象参数信号应能被监听。")
	assert_eq(GFVariantData.get_option_string(argument_snapshot, "type"), "Resource", "对象参数应转换为诊断快照。")
	assert_false(arguments[0] is Resource, "事件历史不应保留 live Resource 引用。")
	assert_eq(GFVariantData.get_option_string(argument_snapshot, "resource_path"), "res://private/payload.tres", "raw 事件应保留调试用资源路径。")
	assert_eq(GFVariantData.get_option_string(exported_event, "source_node_path"), "<redacted_path>", "JSON-safe 事件应默认脱敏节点路径。")
	assert_eq(GFVariantData.get_option_string(exported_argument_snapshot, "resource_path"), "<redacted_path>", "JSON-safe 事件应默认脱敏资源路径。")

	var _unwatch_all_result: Variant = probe.unwatch_all()


func test_probe_bounds_wide_and_large_signal_payloads() -> void:
	var source: SignalSource = SignalSource.new()
	var probe: GFSignalRuntimeProbe = GFSignalRuntimeProbe.new()
	probe.max_container_items = 4
	probe.max_snapshot_nodes = 64
	probe.max_snapshot_bytes = 32
	var _report: Dictionary = probe.watch_node(source, {
		"include_signals": [&"object_payload"],
	})
	var wide_array: Array[int] = []
	var packed_bytes: PackedByteArray = PackedByteArray()
	for index: int in range(1000):
		wide_array.append(index)
		var _packed_appended: bool = packed_bytes.append(index % 256)

	source.object_payload.emit(wide_array)
	source.object_payload.emit("x".repeat(10_000))
	source.object_payload.emit(packed_bytes)
	var events: Array[Dictionary] = probe.get_events()
	var wide_arguments: Array = GFVariantData.get_option_array(events[0], "arguments")
	var wide_snapshot: Array = GFVariantData.as_array(wide_arguments[0])
	var wide_budget: Dictionary = GFVariantData.get_option_dictionary(events[0], "snapshot_budget")
	var text_arguments: Array = GFVariantData.get_option_array(events[1], "arguments")
	var text_snapshot: Dictionary = GFVariantData.as_dictionary(text_arguments[0])
	var text_budget: Dictionary = GFVariantData.get_option_dictionary(events[1], "snapshot_budget")
	var packed_arguments: Array = GFVariantData.get_option_array(events[2], "arguments")
	var packed_snapshot: Dictionary = GFVariantData.as_dictionary(packed_arguments[0])

	assert_eq(wide_snapshot.size(), 5, "宽 Array 应只保留预算内元素和一个截断 marker。")
	assert_true(GFVariantData.get_option_bool(wide_budget, "truncated"), "宽 Array 截断应可观察。")
	assert_lte(GFVariantData.get_option_int(wide_budget, "node_count"), 64, "参数快照不应超过节点预算。")
	assert_true(GFVariantData.get_option_bool(text_snapshot, "truncated"), "超长字符串应转换为截断快照。")
	assert_lte(GFVariantData.get_option_int(text_budget, "estimated_bytes"), 32, "参数快照不应超过字节预算。")
	assert_eq(GFVariantData.get_option_int(packed_snapshot, "count"), 1000, "PackedArray 快照应保留原始计数。")
	assert_eq(GFVariantData.get_option_array(packed_snapshot, "sample").size(), 4, "PackedArray 只应复制预算内样本。")
	assert_true(GFVariantData.get_option_bool(packed_snapshot, "truncated"), "PackedArray 截断应可观察。")

	var _unwatch_all_result: Variant = probe.unwatch_all()
	source.free()


func test_probe_respects_event_limit_and_unwatch() -> void:
	var source: SignalSource = SignalSource.new()
	var probe: GFSignalRuntimeProbe = GFSignalRuntimeProbe.new()
	probe.max_events = 1
	var _report: Dictionary = probe.watch_node(source, {
		"include_signals": [&"value_changed"],
	})

	source.value_changed.emit(1)
	source.value_changed.emit(2)
	assert_eq(probe.get_events().size(), 1, "事件数量应受 max_events 限制。")

	assert_eq(probe.unwatch_node(source), 1, "unwatch_node 应断开已监听信号。")
	source.value_changed.emit(3)
	assert_eq(probe.get_events().size(), 1, "断开后不应继续记录。")

	source.free()


func test_watch_tree_reports_node_limit() -> void:
	var root: Node = Node.new()
	var first_child: SignalSource = SignalSource.new()
	var second_child: SignalSource = SignalSource.new()
	root.add_child(first_child)
	root.add_child(second_child)
	var probe: GFSignalRuntimeProbe = GFSignalRuntimeProbe.new()

	var report: Dictionary = probe.watch_tree(root, {
		"include_signals": [&"value_changed"],
		"max_nodes": 1,
	})
	var errors: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "errors"))

	assert_false(GFVariantData.get_option_bool(report, "ok"), "节点树监听被截断时报告应标记失败。")
	assert_true(errors.has("max_nodes_reached:1"), "报告应包含 max_nodes 截断原因。")
	assert_eq(probe.get_watch_count(), 0, "达到节点上限时只收集根节点，根节点无业务信号不应产生监听。")

	var _unwatch_all_result_92: Variant = probe.unwatch_all()
	root.free()


func test_signal_graph_dock_keeps_empty_runtime_page_compact() -> void:
	var dock: GFSignalGraphDock = GFSignalGraphDock.new()
	var snapshot: Dictionary = dock.get_debug_snapshot()
	var ui: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(snapshot, "ui"))

	assert_eq(dock.custom_minimum_size, Vector2.ZERO, "Signal Diagnostics 不应设置自定义最小高度。")
	assert_eq(GFVariantData.get_option_float(ui, "root_anchor_right"), 1.0, "Signal Diagnostics 内容应横向铺满父容器。")
	assert_eq(GFVariantData.get_option_float(ui, "root_anchor_bottom"), 1.0, "Signal Diagnostics 内容应纵向跟随父容器。")
	assert_true(GFVariantData.get_option_bool(ui, "event_empty_visible"), "没有发射记录时应显示紧凑空态说明。")
	assert_false(GFVariantData.get_option_bool(ui, "event_tree_visible"), "没有发射记录时不应显示只有表头的空表格。")
	assert_eq(GFVariantData.get_option_string(ui, "persistent_only_text"), "保存连接", "连接过滤选项应使用面向用户的直观命名。")
	assert_eq(GFVariantData.get_option_string(ui, "include_empty_text"), "未连接信号", "信号过滤选项应说明它显示未连接的信号。")
	assert_eq(GFVariantData.get_option_string(ui, "live_text"), "追踪发射", "发射记录开关应说明它记录信号发射。")
	assert_true(
		GFVariantData.get_option_string(ui, "event_empty_text").contains("追踪发射"),
		"发射记录空态应说明如何开始记录信号发射。"
	)

	dock.free()


func test_signal_graph_dock_tracks_saved_connection_signals_without_unconnected_noise() -> void:
	var source: SignalSource = SignalSource.new()
	source.name = "Source"
	add_child(source)
	var connect_error: int = source.no_args.connect(source._on_no_args, CONNECT_PERSIST as Object.ConnectFlags)
	assert_eq(connect_error, OK, "测试应能创建保存连接。")
	var dock: GFSignalGraphDock = GFSignalGraphDock.new()
	add_child(dock)
	dock.set_graph_source(source)

	dock.set_live_tracking_enabled(true)
	var before_rendering: Dictionary = GFVariantData.get_option_dictionary(dock.get_debug_snapshot(), "rendering")
	source.value_changed.emit(7)
	source.no_args.emit()

	var events: Array[Dictionary] = dock.get_recent_events()
	var after_rendering: Dictionary = GFVariantData.get_option_dictionary(dock.get_debug_snapshot(), "rendering")

	assert_eq(events.size(), 1, "追踪发射默认应只记录保存连接中的信号，避免 draw 等未连接噪音。")
	var saved_event: Dictionary = events[0]
	assert_eq(GFVariantData.get_option_string(saved_event, "signal_name"), "no_args", "保存连接里的信号应被记录。")
	assert_eq(
		GFVariantData.get_option_int(after_rendering, "graph_revision"),
		GFVariantData.get_option_int(before_rendering, "graph_revision"),
		"新增发射记录不应重建静态连接图。"
	)
	assert_gt(
		GFVariantData.get_option_int(after_rendering, "event_revision"),
		GFVariantData.get_option_int(before_rendering, "event_revision"),
		"新增发射记录应只刷新事件视图。"
	)

	dock.queue_free()
	source.queue_free()
	await get_tree().process_frame


# --- 内部类 ---

class SignalSource extends Node:
	signal no_args
	signal value_changed(value: Variant)
	signal pair_changed(left: Variant, right: Variant)
	signal object_payload(payload: Variant)
	signal wide_payload(
		a: Variant,
		b: Variant,
		c: Variant,
		d: Variant,
		e: Variant,
		f: Variant,
		g: Variant,
		h: Variant,
		i: Variant
	)

	func _on_no_args() -> void:
		pass
