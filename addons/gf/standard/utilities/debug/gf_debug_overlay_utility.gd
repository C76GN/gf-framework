## GFDebugOverlayUtility: 开发期运行时观察覆盖层。
##
## 提供 watch / panel 注册、轻量运行时快照和可选调试 GUI。默认只在 debug 构建中创建 GUI。
## 发布构建如确实需要显示，必须显式关闭 debug_only 并自行确认可见性与数据脱敏策略。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFDebugOverlayUtility
extends GFUtility


# --- 公共变量 ---

## 呼出/隐藏面板的快捷键。默认为 KEY_QUOTELEFT (`~` 键)。
## [br]
## @api public
var toggle_key: Key = KEY_QUOTELEFT

## 可见时刷新模型反射数据的间隔（秒）。设为 0 时每帧刷新。
## [br]
## @api public
var refresh_interval_seconds: float = 0.25

## 是否把 GFDiagnosticsUtility 的监控预设合并显示到 Watch 区。
## [br]
## @api public
var include_diagnostics_monitors: bool = true

## Overlay 默认读取的诊断监控预设。
## [br]
## @api public
var diagnostics_monitor_preset: StringName = &"overlay"

## 是否在 Overlay 中附加最近日志面板。
## [br]
## @api public
var include_recent_logs: bool = true

## 最近日志面板读取的日志数量。
## [br]
## @api public
var recent_log_count: int = 12

## 是否在 Overlay 中附加短期指标趋势面板。
## [br]
## @api public
var include_metric_series_panel: bool = true

## 指标趋势 sparkline 输出宽度。
## [br]
## @api public
var metric_series_width: int = 32

## Overlay 最多维护的指标序列数量。设为 0 表示不限制。
## [br]
## @api public
## [br]
## @since 6.0.0
var max_metric_series: int = 256:
	set(value):
		max_metric_series = maxi(value, 0)

## 单个推送值输出容器最多保留的元素数量。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_value_collection_items: int = 32:
	set(value):
		max_value_collection_items = maxi(value, 0)

## 单个推送值最多编码的值节点数量。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_value_snapshot_nodes: int = 256:
	set(value):
		max_value_snapshot_nodes = maxi(value, 0)

## 单个面板最终文本的最大字符数量。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_panel_content_chars: int = 8192:
	set(value):
		max_panel_content_chars = maxi(value, 0)

## 是否只在 debug 构建中创建 Overlay GUI。发布构建需要显式关闭此项才会创建 GUI。
## [br]
## @api public
var debug_only: bool = true


# --- 私有变量 ---

var _overlay_gui: _GFDebugGUI
var _watches: Dictionary = {}
var _watch_order_counter: int = 0
var _panels: Dictionary = {}
var _panel_order_counter: int = 0
var _metric_series: Dictionary = {}
var _overlay_attach_generation: int = 0


# --- GF 生命周期方法 ---

## 初始化调试覆盖层 GUI。
## [br]
## @api public
func init() -> void:
	if is_instance_valid(_overlay_gui):
		_overlay_gui._toggle_key = toggle_key
		_overlay_gui._refresh_interval_seconds = refresh_interval_seconds
		_overlay_gui._architecture_provider = Callable(self, "_get_architecture_or_null")
		_overlay_gui._watch_snapshot_provider = Callable(self, "get_watch_snapshot")
		_overlay_gui._panel_snapshot_provider = Callable(self, "get_panel_snapshot")
		return

	if debug_only and not OS.is_debug_build():
		return

	_overlay_gui = _GFDebugGUI.new()
	_overlay_gui.name = "GFDebugOverlay"
	_overlay_gui._toggle_key = toggle_key
	_overlay_gui._refresh_interval_seconds = refresh_interval_seconds
	_overlay_gui._architecture_provider = Callable(self, "_get_architecture_or_null")
	_overlay_gui._watch_snapshot_provider = Callable(self, "get_watch_snapshot")
	_overlay_gui._panel_snapshot_provider = Callable(self, "get_panel_snapshot")
	_overlay_attach_generation += 1
	
	var tree: SceneTree = _get_main_scene_tree()
	if tree != null:
		call_deferred("_add_overlay_gui_if_current", _overlay_attach_generation)


## 释放调试覆盖层 GUI 和所有 watch / panel 注册。
## [br]
## @api public
func dispose() -> void:
	_overlay_attach_generation += 1
	if is_instance_valid(_overlay_gui):
		_overlay_gui.visible = false
		_overlay_gui.set_process(false)
		_overlay_gui.set_process_input(false)
		_overlay_gui._architecture_provider = Callable()
		_overlay_gui._watch_snapshot_provider = Callable()
		_overlay_gui._panel_snapshot_provider = Callable()
		var parent: Node = _overlay_gui.get_parent()
		if parent != null and not GFAutoload.is_tree_exit_in_progress():
			parent.remove_child(_overlay_gui)
		if not _overlay_gui.is_queued_for_deletion():
			_overlay_gui.queue_free()
	_overlay_gui = null
	clear_watches()
	clear_panels()
	clear_metric_series()


# --- 公共方法 ---

## 更新快捷键绑定
## [br]
## @api public
## [br]
## @param key: 新的触发按键
func set_toggle_key(key: Key) -> void:
	toggle_key = key
	if is_instance_valid(_overlay_gui):
		_overlay_gui._toggle_key = key


## 设置可见时的刷新间隔。
## [br]
## @api public
## [br]
## @param seconds: 刷新间隔；小于等于 0 时每帧刷新。
func set_refresh_interval(seconds: float) -> void:
	refresh_interval_seconds = maxf(seconds, 0.0)
	if is_instance_valid(_overlay_gui):
		_overlay_gui._refresh_interval_seconds = refresh_interval_seconds


## 设置 Overlay 使用的诊断监控预设。
## [br]
## @api public
## [br]
## @param preset_id: 诊断监控预设标识；为空时采集全部可见监控项。
func set_diagnostics_monitor_preset(preset_id: StringName) -> void:
	diagnostics_monitor_preset = preset_id


## 设置 Overlay GUI 可见性。
## [br]
## @api public
## [br]
## @param visible: 为 true 时显示 Overlay GUI。
func set_overlay_visible(visible: bool) -> void:
	if not is_instance_valid(_overlay_gui):
		return
	_overlay_gui.visible = visible
	if visible:
		_overlay_gui._refresh_now()


## 检查 Overlay GUI 是否可见。
## [br]
## @api public
## [br]
## @return 可见时返回 true。
func is_overlay_visible() -> bool:
	return is_instance_valid(_overlay_gui) and _overlay_gui.visible


## 立即刷新 Overlay GUI 文本。
## [br]
## @api public
func refresh_overlay() -> void:
	if is_instance_valid(_overlay_gui):
		_overlay_gui._refresh_now()


## 推送一个由调用方主动更新的运行时观察值。
## [br]
## @api public
## [br]
## @param id: 观察值唯一标识。
## [br]
## @param value: 要显示的当前值。
## [br]
## @param options: 可选显示参数，支持 label、group、visible。
## [br]
## @return 注册成功返回 true；id 为空时返回 false。
## [br]
## @schema value: Variant，可为任意可显示值。
## [br]
## @schema options: Dictionary，支持 label、group 和 visible。
func push_watch_value(id: StringName, value: Variant, options: Dictionary = {}) -> bool:
	if id == &"":
		return false

	_upsert_watch_entry(id, _bound_published_value(value), options)
	return true


## 移除一个运行时观察值。
## [br]
## @api public
## [br]
## @param id: 要移除的观察值标识。
func remove_watch(id: StringName) -> void:
	_erase_dictionary_key(_watches, id)


## 清空所有运行时观察值。
## [br]
## @api public
func clear_watches() -> void:
	_watches.clear()
	_watch_order_counter = 0


## 检查运行时观察值是否已注册。
## [br]
## @api public
## [br]
## @param id: 要检查的观察值标识。
## [br]
## @return 已注册时返回 true。
func has_watch(id: StringName) -> bool:
	return _watches.has(id)


## 读取当前运行时观察值快照。
## [br]
## @api public
## [br]
## @param include_hidden: 为 true 时同时返回 visible=false 的观察值。
## [br]
## @return 按注册顺序排列的观察值字典数组。
## [br]
## @schema return: Array[Dictionary]，每个元素包含 id、label、group、value 和 valid。
func get_watch_snapshot(include_hidden: bool = false) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for id: StringName in _watches:
		var source_entry: Dictionary = GFVariantData.get_option_dictionary(_watches, id)
		var is_visible: bool = GFVariantData.get_option_bool(source_entry, "visible", true)
		if not include_hidden and not is_visible:
			continue

		var entry: Dictionary = source_entry.duplicate()
		entry["id"] = id
		entries.append(entry)

	entries.sort_custom(_sort_watch_entries)

	var snapshot: Array[Dictionary] = []
	for entry: Dictionary in entries:
		snapshot.append({
			"id": GFVariantData.get_option_string_name(entry, "id", &""),
			"label": GFVariantData.get_option_string(entry, "label", GFVariantData.get_option_string(entry, "id", "")),
			"group": GFVariantData.get_option_string(entry, "group", "Runtime"),
			"value": GFVariantData.get_option_value(entry, "value", null),
			"valid": true,
			"error": "",
		})

	if include_diagnostics_monitors:
		_append_diagnostics_watch_snapshot(snapshot, include_hidden)
	return snapshot


## 推送一个由调用方主动更新的 Overlay 面板值。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param panel_id: 面板唯一标识。
## [br]
## @param content: 面板内容；Dictionary 和 Array 会按报告边界编码后格式化。
## [br]
## @param options: 可选显示参数，支持 label、group、visible。
## [br]
## @return 注册成功返回 true。
## [br]
## @schema content: 任意 Variant 报告值；写入前由 GFReportValueCodec 编码并受 Overlay 集合、节点、深度和文本长度预算约束。
## [br]
## @schema options: Dictionary，支持 label、group 和 visible。
func push_panel_content(panel_id: StringName, content: Variant, options: Dictionary = {}) -> bool:
	if panel_id == &"":
		return false
	_upsert_panel_entry(panel_id, _format_panel_content(_bound_published_value(content)), options)
	return true


## 推送一个静态 Overlay 面板文本。
## [br]
## @api public
## [br]
## @param panel_id: 面板唯一标识。
## [br]
## @param content: 面板内容。
## [br]
## @param options: 可选显示参数，支持 label、group、visible。
## [br]
## @return 注册成功返回 true。
## [br]
## @schema options: Dictionary，支持 label、group 和 visible。
func push_panel_text(panel_id: StringName, content: String, options: Dictionary = {}) -> bool:
	return push_panel_content(panel_id, content, options)


## 移除一个 Overlay 面板。
## [br]
## @api public
## [br]
## @param panel_id: 面板唯一标识。
func remove_panel(panel_id: StringName) -> void:
	_erase_dictionary_key(_panels, panel_id)


## 清空 Overlay 面板注册表。
## [br]
## @api public
func clear_panels() -> void:
	_panels.clear()
	_panel_order_counter = 0


## 检查 Overlay 面板是否已注册。
## [br]
## @api public
## [br]
## @param panel_id: 面板唯一标识。
## [br]
## @return 已注册时返回 true。
func has_panel(panel_id: StringName) -> bool:
	return _panels.has(panel_id)


## 读取当前 Overlay 面板快照。
## [br]
## @api public
## [br]
## @param include_hidden: 为 true 时同时返回 visible=false 的面板。
## [br]
## @return 面板快照数组。
## [br]
## @schema return: Array[Dictionary]，每个元素包含 id、label、group、content 和 valid。
func get_panel_snapshot(include_hidden: bool = false) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for panel_id: StringName in _panels:
		var source_entry: Dictionary = GFVariantData.get_option_dictionary(_panels, panel_id)
		if not include_hidden and not GFVariantData.get_option_bool(source_entry, "visible", true):
			continue

		var entry: Dictionary = source_entry.duplicate()
		entry["id"] = panel_id
		entries.append(entry)

	entries.sort_custom(_sort_panel_entries)

	var snapshot: Array[Dictionary] = []
	for entry: Dictionary in entries:
		snapshot.append(_build_panel_snapshot_entry(entry))

	if include_metric_series_panel:
		_append_metric_series_panel(snapshot, include_hidden)
	if include_recent_logs:
		_append_recent_log_panel(snapshot, include_hidden)
	return snapshot


## 追加一个短期指标采样。
## [br]
## @api public
## [br]
## @param metric_id: 指标唯一标识。
## [br]
## @param value: 采样值。
## [br]
## @param options: 可选配置，支持 label、group、visible、max_samples、timestamp_seconds、metadata 和 sample_metadata。
## [br]
## @return 采样成功返回 true。
## [br]
## @schema options: Dictionary，支持 label、group、visible、max_samples、timestamp_seconds、metadata 和 sample_metadata。
func record_metric_sample(metric_id: StringName, value: float, options: Dictionary = {}) -> bool:
	var series: GFMetricSeries = get_or_create_metric_series(metric_id, options)
	if series == null:
		return false

	var sample_metadata: Dictionary = {}
	var sample_metadata_value: Variant = GFVariantData.get_option_value(options, "sample_metadata", {})
	if sample_metadata_value is Dictionary:
		var source_metadata: Dictionary = sample_metadata_value
		sample_metadata = source_metadata.duplicate(true)
	series.add_sample(
		value,
		GFVariantData.get_option_float(options, "timestamp_seconds", -1.0),
		sample_metadata
	)
	return true


## 获取或创建短期指标序列。
## [br]
## @api public
## [br]
## @param metric_id: 指标唯一标识。
## [br]
## @param options: 可选配置，支持 label、group、visible、max_samples 和 metadata。
## [br]
## @return 指标序列；metric_id 为空时返回 null。
## [br]
## @schema options: Dictionary，支持 label、group、visible、max_samples 和 metadata。
func get_or_create_metric_series(metric_id: StringName, options: Dictionary = {}) -> GFMetricSeries:
	if metric_id == &"":
		return null

	var series: GFMetricSeries = _get_metric_series_or_null(metric_id)
	if series == null:
		if not _has_metric_series_capacity(metric_id):
			push_warning("[GFDebugOverlayUtility] 指标序列数量已达到上限，已拒绝创建：%s" % String(metric_id))
			return null
		series = GFMetricSeries.new()
		_metric_series[metric_id] = series
	series = series.configure(metric_id, options)
	return series


## 注册一个外部维护的指标序列。
## [br]
## @api public
## [br]
## @param series: 指标序列。
## [br]
## @return 注册成功返回 true。
func register_metric_series(series: GFMetricSeries) -> bool:
	if series == null or series.id == &"":
		return false
	if not _has_metric_series_capacity(series.id):
		push_warning("[GFDebugOverlayUtility] 指标序列数量已达到上限，已拒绝注册：%s" % String(series.id))
		return false
	if series.label.is_empty():
		series.label = String(series.id)
	_metric_series[series.id] = series
	return true


## 移除一个指标序列。
## [br]
## @api public
## [br]
## @param metric_id: 指标唯一标识。
func remove_metric_series(metric_id: StringName) -> void:
	_erase_dictionary_key(_metric_series, metric_id)


## 清空全部指标序列。
## [br]
## @api public
func clear_metric_series() -> void:
	_metric_series.clear()


## 检查指标序列是否已注册。
## [br]
## @api public
## [br]
## @param metric_id: 指标唯一标识。
## [br]
## @return 已注册时返回 true。
func has_metric_series(metric_id: StringName) -> bool:
	return _metric_series.has(metric_id)


## 读取当前指标序列快照。
## [br]
## @api public
## [br]
## @param include_hidden: 为 true 时同时返回 visible=false 的指标序列。
## [br]
## @return 指标序列快照数组。
## [br]
## @schema return: Array[Dictionary]，每个元素包含 id、label、group、visible、sample_count、latest_value、min_value、max_value、average_value、sparkline 和 metadata。
func get_metric_series_snapshot(include_hidden: bool = false) -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for metric_id: StringName in _metric_series:
		var series: GFMetricSeries = _get_metric_series_or_null(metric_id)
		if series == null:
			continue
		if not include_hidden and not series.visible:
			continue

		var entry: Dictionary = series.to_dict(false, metric_series_width)
		snapshot.append(entry)

	snapshot.sort_custom(_sort_metric_series_entries)
	return snapshot


## 获取 Overlay 运行时调试快照。
## [br]
## @api public
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 debug_only、watch_count、panel_count、metric_series_count、include_diagnostics_monitors、include_recent_logs、include_metric_series_panel、recent_log_count、metric_series_width、diagnostics_monitor_preset 和 gui 分区。
func get_debug_snapshot() -> Dictionary:
	var gui_created: bool = is_instance_valid(_overlay_gui)
	return {
		"debug_only": debug_only,
		"watch_count": _watches.size(),
		"panel_count": _panels.size(),
		"metric_series_count": _metric_series.size(),
		"include_diagnostics_monitors": include_diagnostics_monitors,
		"include_recent_logs": include_recent_logs,
		"include_metric_series_panel": include_metric_series_panel,
		"recent_log_count": recent_log_count,
		"metric_series_width": metric_series_width,
		"max_value_collection_items": max_value_collection_items,
		"max_value_snapshot_nodes": max_value_snapshot_nodes,
		"max_panel_content_chars": max_panel_content_chars,
		"diagnostics_monitor_preset": diagnostics_monitor_preset,
		"gui": {
			"created": gui_created,
			"visible": _overlay_gui.visible if gui_created else false,
			"processing": _overlay_gui.is_processing() if gui_created else false,
			"processing_input": _overlay_gui.is_processing_input() if gui_created else false,
			"has_parent": _overlay_gui.get_parent() != null if gui_created else false,
			"architecture_provider_valid": _overlay_gui._architecture_provider.is_valid() if gui_created else false,
			"watch_snapshot_provider_valid": _overlay_gui._watch_snapshot_provider.is_valid() if gui_created else false,
			"panel_snapshot_provider_valid": _overlay_gui._panel_snapshot_provider.is_valid() if gui_created else false,
			"text": _overlay_gui._get_rendered_text() if gui_created else "",
		},
	}


# --- 私有/辅助方法 ---

func _get_main_scene_tree() -> SceneTree:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree: SceneTree = main_loop
		return tree
	return null


func _add_overlay_gui_if_current(generation: int) -> void:
	if generation != _overlay_attach_generation:
		return
	var overlay_gui: _GFDebugGUI = _overlay_gui
	if not is_instance_valid(overlay_gui):
		return
	if overlay_gui.is_queued_for_deletion():
		return
	var tree: SceneTree = _get_main_scene_tree()
	if tree == null or not is_instance_valid(tree.root):
		return
	if overlay_gui.get_parent() == null:
		tree.root.add_child(overlay_gui)


func _get_log_utility() -> GFLogUtility:
	var utility: Variant = get_utility(GFLogUtility)
	if utility is GFLogUtility:
		var log_utility: GFLogUtility = utility
		return log_utility
	return null


func _get_diagnostics_utility() -> GFDiagnosticsUtility:
	var utility: Variant = get_utility(GFDiagnosticsUtility)
	if utility is GFDiagnosticsUtility:
		var diagnostics: GFDiagnosticsUtility = utility
		return diagnostics
	return null


func _get_metric_series_or_null(metric_id: StringName) -> GFMetricSeries:
	var value: Variant = GFVariantData.get_option_value(_metric_series, metric_id)
	if value is GFMetricSeries:
		var series: GFMetricSeries = value
		return series
	return null


func _has_metric_series_capacity(metric_id: StringName) -> bool:
	if _metric_series.has(metric_id):
		return true
	if max_metric_series <= 0:
		return true
	return _metric_series.size() < max_metric_series


func _erase_dictionary_key(source: Dictionary, key: Variant) -> void:
	var erased: bool = source.erase(key)
	if erased:
		return


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


func _upsert_watch_entry(id: StringName, value: Variant, options: Dictionary) -> void:
	var entry: Dictionary = {}
	if _watches.has(id):
		entry = GFVariantData.get_option_dictionary(_watches, id).duplicate()
	else:
		entry = {
			"label": String(id),
			"group": "Runtime",
			"visible": true,
			"order": _watch_order_counter,
		}
		_watch_order_counter += 1

	entry["value"] = value
	_apply_watch_options(entry, id, options)
	_watches[id] = entry


func _apply_watch_options(entry: Dictionary, id: StringName, options: Dictionary) -> void:
	if not entry.has("label") or GFVariantData.get_option_string(entry, "label", "").is_empty():
		entry["label"] = String(id)
	if not entry.has("group") or GFVariantData.get_option_string(entry, "group", "").is_empty():
		entry["group"] = "Runtime"
	if not entry.has("visible"):
		entry["visible"] = true

	if options.has("label"):
		var label: String = str(options["label"])
		if not label.is_empty():
			entry["label"] = label
	if options.has("group"):
		var group: String = str(options["group"])
		if not group.is_empty():
			entry["group"] = group
	if options.has("visible"):
		var visible_value: Variant = options["visible"]
		if visible_value is bool:
			entry["visible"] = visible_value


func _sort_watch_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_order: int = GFVariantData.get_option_int(left, "order", 0)
	var right_order: int = GFVariantData.get_option_int(right, "order", 0)
	if left_order != right_order:
		return left_order < right_order
	return GFVariantData.get_option_string(left, "id", "") < GFVariantData.get_option_string(right, "id", "")


func _upsert_panel_entry(panel_id: StringName, content: String, options: Dictionary) -> void:
	var entry: Dictionary = {}
	if _panels.has(panel_id):
		entry = GFVariantData.get_option_dictionary(_panels, panel_id).duplicate()
	else:
		entry = {
			"label": String(panel_id),
			"group": "Runtime",
			"visible": true,
			"order": _panel_order_counter,
		}
		_panel_order_counter += 1

	entry["content"] = content
	_apply_panel_options(entry, panel_id, options)
	_panels[panel_id] = entry


func _apply_panel_options(entry: Dictionary, panel_id: StringName, options: Dictionary) -> void:
	if not entry.has("label") or GFVariantData.get_option_string(entry, "label", "").is_empty():
		entry["label"] = String(panel_id)
	if not entry.has("group") or GFVariantData.get_option_string(entry, "group", "").is_empty():
		entry["group"] = "Runtime"
	if not entry.has("visible"):
		entry["visible"] = true

	if options.has("label"):
		var label: String = str(options["label"])
		if not label.is_empty():
			entry["label"] = label
	if options.has("group"):
		var group: String = str(options["group"])
		if not group.is_empty():
			entry["group"] = group
	if options.has("visible"):
		var visible_value: Variant = options["visible"]
		if visible_value is bool:
			entry["visible"] = visible_value


func _build_panel_snapshot_entry(entry: Dictionary) -> Dictionary:
	return {
		"id": GFVariantData.get_option_string_name(entry, "id", &""),
		"label": GFVariantData.get_option_string(entry, "label", GFVariantData.get_option_string(entry, "id", "")),
		"group": GFVariantData.get_option_string(entry, "group", "Runtime"),
		"content": GFVariantData.get_option_string(entry, "content"),
		"valid": true,
		"error": "",
	}


func _sort_panel_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_order: int = GFVariantData.get_option_int(left, "order", 0)
	var right_order: int = GFVariantData.get_option_int(right, "order", 0)
	if left_order != right_order:
		return left_order < right_order
	return GFVariantData.get_option_string(left, "id", "") < GFVariantData.get_option_string(right, "id", "")


func _sort_metric_series_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_group: String = GFVariantData.get_option_string(left, "group", "Runtime")
	var right_group: String = GFVariantData.get_option_string(right, "group", "Runtime")
	if left_group != right_group:
		return left_group < right_group
	var left_label: String = GFVariantData.get_option_string(left, "label", GFVariantData.get_option_string(left, "id", ""))
	var right_label: String = GFVariantData.get_option_string(right, "label", GFVariantData.get_option_string(right, "id", ""))
	if left_label != right_label:
		return left_label < right_label
	return GFVariantData.get_option_string(left, "id", "") < GFVariantData.get_option_string(right, "id", "")


func _format_panel_content(value: Variant) -> String:
	var content: String = ""
	if value is Dictionary or value is Array:
		content = GFReportValueCodec.stringify_json_compatible(value, "\t")
	else:
		content = str(value)
	if content.length() <= max_panel_content_chars:
		return content
	return "%s\n<truncated>" % content.substr(0, max_panel_content_chars)


func _bound_published_value(value: Variant) -> Variant:
	return GFReportValueCodec.to_json_compatible(
		value,
		GFReportValueCodec.make_redaction_options(GFReportValueCodec.REDACTION_PROFILE_DEBUG, {
			"max_collection_items": max_value_collection_items,
			"max_total_nodes": max_value_snapshot_nodes,
			"max_depth": 8,
			"max_string_length": max_panel_content_chars,
		})
	)


func _append_metric_series_panel(snapshot: Array[Dictionary], include_hidden: bool) -> void:
	var metrics: Array[Dictionary] = get_metric_series_snapshot(include_hidden)
	if metrics.is_empty():
		return

	var lines: PackedStringArray = PackedStringArray()
	for metric: Dictionary in metrics:
		_append_packed_string(lines, "%s: latest=%s avg=%s min=%s max=%s %s" % [
			GFVariantData.get_option_string(metric, "label", GFVariantData.get_option_string(metric, "id", "")),
			_format_metric_number(GFVariantData.get_option_float(metric, "latest_value", 0.0)),
			_format_metric_number(GFVariantData.get_option_float(metric, "average_value", 0.0)),
			_format_metric_number(GFVariantData.get_option_float(metric, "min_value", 0.0)),
			_format_metric_number(GFVariantData.get_option_float(metric, "max_value", 0.0)),
			GFVariantData.get_option_string(metric, "sparkline", ""),
		])

	snapshot.append({
		"id": &"gf.metrics",
		"label": "Metric Series",
		"group": "Diagnostics",
		"content": "\n".join(lines),
		"valid": true,
	})


func _format_metric_number(value: float) -> String:
	return "%.3f" % value


func _append_recent_log_panel(snapshot: Array[Dictionary], include_hidden: bool) -> void:
	var log_utility: GFLogUtility = _get_log_utility()
	if log_utility == null:
		return
	if not include_hidden and recent_log_count <= 0:
		return

	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in log_utility.get_recent_entries(recent_log_count):
		_append_packed_string(lines, "[%s][%s] %s" % [
			GFVariantData.get_option_string(entry, "level_name", ""),
			GFVariantData.get_option_string(entry, "tag", ""),
			GFVariantData.get_option_string(entry, "message", ""),
		])
	if lines.is_empty():
		return

	snapshot.append({
		"id": &"gf.logs",
		"label": "Recent Logs",
		"group": "Diagnostics",
		"content": "\n".join(lines),
		"valid": true,
	})


func _append_diagnostics_watch_snapshot(snapshot: Array[Dictionary], include_hidden: bool) -> void:
	var diagnostics: GFDiagnosticsUtility = _get_diagnostics_utility()
	if diagnostics == null:
		return

	var monitor_snapshot: Dictionary = {}
	if diagnostics_monitor_preset != &"":
		monitor_snapshot = diagnostics.collect_monitor_preset(diagnostics_monitor_preset, include_hidden)
	else:
		monitor_snapshot = diagnostics.collect_monitor_snapshot(PackedStringArray(), include_hidden)
	var monitors: Dictionary = GFVariantData.get_option_dictionary(monitor_snapshot, "monitors")
	if monitors == null or monitors.is_empty():
		return

	var ids: PackedStringArray = PackedStringArray()
	for monitor_id: Variant in monitors.keys():
		_append_packed_string(ids, str(monitor_id))
	ids.sort()
	for id_text: String in ids:
		var monitor: Dictionary = GFVariantData.get_option_dictionary(monitors, StringName(id_text))
		if monitor.is_empty():
			continue
		snapshot.append({
			"id": StringName(id_text),
			"label": GFVariantData.get_option_string(monitor, "label", id_text),
			"group": GFVariantData.get_option_string(monitor, "group", "Diagnostics"),
			"value": GFVariantData.get_option_value(monitor, "value", null),
			"valid": GFVariantData.get_option_bool(monitor, "valid", false),
		})


# --- 内部类 ---

class _GFDebugGUI extends CanvasLayer:
	var _container: VBoxContainer
	var _label: RichTextLabel
	var _toggle_key: Key
	var _refresh_interval_seconds: float = 0.25
	var _architecture_provider: Callable
	var _watch_snapshot_provider: Callable
	var _panel_snapshot_provider: Callable
	var _refresh_elapsed: float = 0.25

	func _append_packed_string(target: PackedStringArray, value: String) -> void:
		var appended: bool = target.append(value)
		if appended:
			return
	
	func _init() -> void:
		layer = 120 # 确保在所有 UI 之上
		visible = false
		process_mode = Node.PROCESS_MODE_ALWAYS as Node.ProcessMode # 即使主游戏暂停也能工作
		
		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE as Control.MouseFilter
		add_child(margin)
		
		var panel: PanelContainer = PanelContainer.new()
		panel.self_modulate = Color(0, 0, 0, 0.6)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE as Control.MouseFilter
		margin.add_child(panel)
		
		_container = VBoxContainer.new()
		panel.add_child(_container)
		
		var header: Label = Label.new()
		header.text = "[ GF Debug Overlay ]"
		header.modulate = Color(0.4, 0.8, 1.0)
		_container.add_child(header)
		
		_label = RichTextLabel.new()
		_label.fit_content = true
		_label.autowrap_mode = TextServer.AUTOWRAP_OFF as TextServer.AutowrapMode
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE as Control.MouseFilter
		_label.custom_minimum_size = Vector2(300, 0)
		_label.bbcode_enabled = true
		_container.add_child(_label)


	func _input(event: InputEvent) -> void:
		if event is InputEventKey:
			var key_event: InputEventKey = event
			if not key_event.pressed or key_event.echo:
				return
			if key_event.keycode == _toggle_key:
				visible = not visible
				if visible:
					_refresh_elapsed = _refresh_interval_seconds
				get_viewport().set_input_as_handled()


	func _process(delta: float) -> void:
		if not visible:
			_refresh_elapsed = _refresh_interval_seconds
			return

		if _refresh_interval_seconds > 0.0:
			_refresh_elapsed += delta
			if _refresh_elapsed < _refresh_interval_seconds:
				return
			_refresh_elapsed = 0.0

		_refresh_now()


	func _refresh_now() -> void:
		var text: String = _build_debug_text()
		if _label.text != text:
			_label.text = text


	func _get_rendered_text() -> String:
		return _label.text if _label != null else ""


	func _build_debug_text() -> String:
		var watch_text: String = _build_watch_text()
		var panel_text: String = _build_panel_text()
		var arch: Object = null
		if _architecture_provider.is_valid():
			var architecture_result: Variant = _architecture_provider.call()
			if architecture_result is Object:
				arch = architecture_result
		if arch == null:
			if watch_text.is_empty() and panel_text.is_empty():
				return "Wait: Architecture is null."
			return _join_non_empty(PackedStringArray([watch_text, panel_text]))

		var model_text: String = _build_model_text(arch)
		if watch_text.is_empty() and model_text.is_empty() and panel_text.is_empty():
			return "No GFModels registered."
		return _join_non_empty(PackedStringArray([watch_text, model_text, panel_text]))


	func _build_watch_text() -> String:
		if not _watch_snapshot_provider.is_valid():
			return ""

		var snapshot_result: Variant = _watch_snapshot_provider.call()
		if not (snapshot_result is Array):
			return ""

		var snapshot: Array = snapshot_result
		if snapshot.is_empty():
			return ""

		var group_order: PackedStringArray = []
		var groups: Dictionary = {}
		for watch_variant: Variant in snapshot:
			if not (watch_variant is Dictionary):
				continue
			var watch: Dictionary = watch_variant

			var group: String = GFVariantData.get_option_string(watch, "group", "Runtime")
			if group.is_empty():
				group = "Runtime"
			if not groups.has(group):
				var empty_group: Array[Dictionary] = []
				groups[group] = empty_group
				_append_packed_string(group_order, group)
			var group_items: Array = GFVariantData.get_option_array(groups, group)
			group_items.append(watch)
			groups[group] = group_items

		var text: String = ""
		for group: String in group_order:
			if not text.is_empty():
				text += "\n"
			text += "[color=yellow]=== Watches: %s ===[/color]\n" % _escape_bbcode(group)

			var watches: Array = GFVariantData.get_option_array(groups, group)
			for watch_variant: Variant in watches:
				var watch: Dictionary = GFVariantData.as_dictionary(watch_variant)
				if watch.is_empty():
					continue
				var label: String = GFVariantData.get_option_string(watch, "label", GFVariantData.get_option_string(watch, "id", "watch"))
				if label.is_empty():
					label = GFVariantData.get_option_string(watch, "id", "watch")
				var is_valid: bool = GFVariantData.get_option_bool(watch, "valid", true)
				var value: Variant = GFVariantData.get_option_value(watch, "value", null)
				var value_text: String = str(value)
				if not is_valid:
					value_text = "<invalid>"
				text += "  [color=lightblue]%s[/color]: %s\n" % [
					_escape_bbcode(label),
					_escape_bbcode(value_text),
				]

		return text


	func _build_panel_text() -> String:
		if not _panel_snapshot_provider.is_valid():
			return ""

		var snapshot_result: Variant = _panel_snapshot_provider.call()
		if not (snapshot_result is Array):
			return ""

		var snapshot: Array = snapshot_result
		if snapshot.is_empty():
			return ""

		var text: String = ""
		for panel_variant: Variant in snapshot:
			if not (panel_variant is Dictionary):
				continue
			var panel: Dictionary = panel_variant
			if not text.is_empty():
				text += "\n"
			var label: String = GFVariantData.get_option_string(panel, "label", GFVariantData.get_option_string(panel, "id", "panel"))
			var group: String = GFVariantData.get_option_string(panel, "group", "Runtime")
			var content: String = GFVariantData.get_option_string(panel, "content", "")
			if not GFVariantData.get_option_bool(panel, "valid", true):
				content = "<invalid>"
			text += "[color=yellow]=== Panel: %s / %s ===[/color]\n%s\n" % [
				_escape_bbcode(group),
				_escape_bbcode(label),
				_escape_bbcode(content),
			]
		return text


	func _build_model_text(arch: Object) -> String:
		var models_value: Variant = GFObjectPropertyTools.read_property(arch, NodePath("_models"))
		if not (models_value is Dictionary):
			return ""
		var models: Dictionary = models_value
		if models.is_empty():
			return ""
			
		var text: String = ""
		for script_cls: Script in models:
			var model_value: Variant = models[script_cls]
			if not (model_value is Object):
				continue
			var model: Object = model_value
			var class_title: String = ""
			
			var global_name: StringName = script_cls.get_global_name()
			if global_name != &"":
				class_title = String(global_name)
			else:
				class_title = script_cls.resource_path.get_file().get_basename()
				if class_title.is_empty():
					class_title = "AnonymousModel"
				else:
					class_title = class_title.capitalize().replace(" ", "")
				
			text += "[color=yellow]=== %s ===[/color]\n" % _escape_bbcode(class_title)
			
			var prop_list: Array[Dictionary] = model.get_property_list()
			for prop: Dictionary in prop_list:
				var usage: int = prop.usage
				# 过滤 Godot 内置变量，只显示脚本中声明的用户变量
				if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
					var var_name: String = prop.name
					var var_val: Variant = GFObjectPropertyTools.read_property(model, NodePath(var_name))
					text += "  [color=lightblue]%s[/color]: %s\n" % [
						_escape_bbcode(var_name),
						_escape_bbcode(str(var_val)),
					]
			
			text += "\n"

		return text


	func _join_non_empty(parts: PackedStringArray) -> String:
		var non_empty: PackedStringArray = PackedStringArray()
		for part: String in parts:
			if not part.is_empty():
				_append_packed_string(non_empty, part)
		return "\n".join(non_empty)


	func _escape_bbcode(text: String) -> String:
		var escaped: PackedStringArray = PackedStringArray()
		for index: int in range(text.length()):
			var character: String = text.substr(index, 1)
			if character == "[":
				_append_packed_string(escaped, "[lb]")
			elif character == "]":
				_append_packed_string(escaped, "[rb]")
			else:
				_append_packed_string(escaped, character)
		return "".join(escaped)
