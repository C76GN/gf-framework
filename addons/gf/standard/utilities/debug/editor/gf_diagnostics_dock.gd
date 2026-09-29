@tool

## GFDiagnosticsDock: GF 诊断工作区页面。
##
## 采集通用运行时、性能、监控和场景树诊断快照，供编辑器内只读查看。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
class_name GFDiagnosticsDock
extends Control


# --- 常量 ---

## 复用 GF 编辑器工作区控件工厂和布局常量的脚本资源。
## [br]
## @api private
## [br]
const _EDITOR_WORKSPACE_UI = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")

## 提供诊断字典到 Tree 的展示辅助脚本资源。
## [br]
## @api private
## [br]
const _DIAGNOSTIC_TREE_PRESENTER = preload(
	"res://addons/gf/standard/utilities/debug/editor/gf_diagnostic_tree_presenter.gd"
)


# --- 私有变量 ---

## 负责采集运行时诊断数据的工具实例。
## [br]
## @api private
## [br]
var _diagnostics: GFDiagnosticsUtility = null

## 最近一次采集的诊断快照。
## [br]
## @api private
## [br]
var _last_snapshot: Dictionary = {}

## 选择诊断监控预设的选项控件。
## [br]
## @api private
## [br]
var _preset_option: OptionButton = null

## 控制快照是否包含场景树的复选框。
## [br]
## @api private
## [br]
var _include_scene_tree_check: CheckBox = null

## 控制快照是否包含最近日志的复选框。
## [br]
## @api private
## [br]
var _include_logs_check: CheckBox = null

## 显示诊断快照摘要和状态的标签。
## [br]
## @api private
## [br]
var _summary_label: Label = null

## 无可显示树内容时显示提示的标签。
## [br]
## @api private
## [br]
var _empty_label: Label = null

## 展示诊断分区和值的树控件。
## [br]
## @api private
## [br]
var _tree: Tree = null

## 显示当前选中诊断值 JSON 的文本控件。
## [br]
## @api private
## [br]
var _details: TextEdit = null


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "GF Diagnostics"
	_EDITOR_WORKSPACE_UI.apply_page_root(self)
	_diagnostics = GFDiagnosticsUtility.new()
	_diagnostics.init()
	_build_ui()
	call_deferred("collect_snapshot")


func _exit_tree() -> void:
	if _diagnostics != null:
		_diagnostics.dispose()
	_diagnostics = null


# --- 公共方法 ---

## 采集诊断快照。
## [br]
## @api public
func collect_snapshot() -> void:
	_build_ui()
	if _diagnostics == null:
		_render_empty("诊断工具不可用。")
		return

	_last_snapshot = _diagnostics.collect_snapshot({
		"include_scene_tree": _include_scene_tree_check != null and _include_scene_tree_check.button_pressed,
		"include_recent_logs": _include_logs_check == null or _include_logs_check.button_pressed,
		"monitor_preset": _get_selected_preset_id(),
	})
	_render_snapshot()


## 获取最近一次诊断快照。
## [br]
## @api public
## [br]
## @return 快照副本。
## [br]
## @schema return: Dictionary，包含 GFDiagnosticsUtility.collect_snapshot() 返回的诊断分区。
func get_last_snapshot() -> Dictionary:
	return _last_snapshot.duplicate(true)


## 获取面板调试快照。
## [br]
## @api public
## [br]
## @return 面板调试快照。
## [br]
## @schema return: Dictionary，包含 last_snapshot、summary_text、details_text 和 ui 分区。
func get_debug_snapshot() -> Dictionary:
	_build_ui()
	return {
		"last_snapshot": get_last_snapshot(),
		"summary_text": _summary_label.text if _summary_label != null else "",
		"details_text": _details.text if _details != null else "",
		"ui": {
			"tree_visible": _tree != null and _tree.visible,
			"empty_visible": _empty_label != null and _empty_label.visible,
			"empty_text": _empty_label.text if _empty_label != null else "",
			"include_scene_tree": _include_scene_tree_check != null and _include_scene_tree_check.button_pressed,
			"include_logs": _include_logs_check == null or _include_logs_check.button_pressed,
			"selected_preset": _get_selected_preset_id(),
		},
	}


# --- 私有/辅助方法 ---

## 在树控件尚未创建时构建一次工具栏、过滤选项、摘要、诊断树和详情区域。
## [br]
## @api private
## [br]
func _build_ui() -> void:
	if _tree != null:
		return

	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.clip_contents = true
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root_box)
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var toolbar: HBoxContainer = _EDITOR_WORKSPACE_UI.make_toolbar()
	root_box.add_child(toolbar)

	toolbar.add_child(_EDITOR_WORKSPACE_UI.make_button("采集快照", "采集当前诊断快照。", collect_snapshot))

	_preset_option = OptionButton.new()
	_preset_option.tooltip_text = "选择诊断监控预设。"
	_preset_option.add_item("全部监控", 0)
	_preset_option.set_item_metadata(0, &"")
	_add_monitor_preset_option(&"minimal", "Minimal")
	_add_monitor_preset_option(&"performance", "Performance")
	_add_monitor_preset_option(&"architecture", "Architecture")
	_add_monitor_preset_option(&"tools", "Tools")
	_add_monitor_preset_option(&"overlay", "Overlay")
	var _preset_connected: int = _preset_option.item_selected.connect(_on_option_selected)
	toolbar.add_child(_preset_option)

	_include_scene_tree_check = CheckBox.new()
	_include_scene_tree_check.text = "场景树"
	_include_scene_tree_check.tooltip_text = "采集只读场景树摘要。"
	var _scene_tree_connected: int = _include_scene_tree_check.toggled.connect(_on_option_toggled)
	toolbar.add_child(_include_scene_tree_check)

	_include_logs_check = CheckBox.new()
	_include_logs_check.text = "最近日志"
	_include_logs_check.button_pressed = true
	_include_logs_check.tooltip_text = "快照中包含最近内存日志条目。"
	var _logs_connected: int = _include_logs_check.toggled.connect(_on_option_toggled)
	toolbar.add_child(_include_logs_check)

	toolbar.add_child(_EDITOR_WORKSPACE_UI.make_button("复制快照", "复制当前诊断快照 JSON。", _on_copy_pressed))

	_summary_label = _EDITOR_WORKSPACE_UI.make_summary_label()
	root_box.add_child(_summary_label)

	_empty_label = _EDITOR_WORKSPACE_UI.make_empty_label()
	root_box.add_child(_empty_label)

	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(split)

	_tree = Tree.new()
	_tree.columns = 3
	_tree.hide_root = true
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "分区")
	_tree.set_column_title(1, "项目")
	_tree.set_column_title(2, "摘要")
	_tree.set_column_expand(2, true)
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var _tree_connected: int = _tree.item_selected.connect(_on_tree_item_selected)
	split.add_child(_tree)

	_details = _EDITOR_WORKSPACE_UI.make_details_output()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_details)
	toolbar.add_child(_EDITOR_WORKSPACE_UI.make_details_toggle(_details))


## 将带有 preset ID 元数据的监控预设加入选项控件。
## [br]
## @api private
## [br]
func _add_monitor_preset_option(preset_id: StringName, label: String) -> void:
	var index: int = _preset_option.item_count
	_preset_option.add_item(label, index)
	_preset_option.set_item_metadata(index, preset_id)


## 清空并显示最近快照，更新摘要、详情文本和诊断树。
## [br]
## @api private
## [br]
func _render_snapshot() -> void:
	if _tree == null:
		return

	_tree.clear()
	_details.text = _safe_json(_last_snapshot)
	_empty_label.visible = false
	_tree.visible = true
	_summary_label.text = _make_snapshot_summary(_last_snapshot)
	_EDITOR_WORKSPACE_UI.set_status(_summary_label, _summary_label.text, _EDITOR_WORKSPACE_UI.OK_TEXT_COLOR)

	_DIAGNOSTIC_TREE_PRESENTER.populate_dictionary(_tree, _last_snapshot)


## 隐藏并清空诊断内容，显示空状态提示及警告状态。
## [br]
## @api private
## [br]
func _render_empty(message: String) -> void:
	if _tree != null:
		_tree.clear()
		_tree.visible = false
	if _details != null:
		_details.text = ""
	if _empty_label != null:
		_empty_label.text = message + "\n选择监控范围后点击“采集快照”；选择条目查看摘要，需要原始数据时展开“高级详情”。"
		_empty_label.visible = true
	_EDITOR_WORKSPACE_UI.set_status(_summary_label, message, _EDITOR_WORKSPACE_UI.WARNING_TEXT_COLOR)


## 汇总性能、架构模块和监控数量，生成人类可读摘要。
## [br]
## @api private
## [br]
func _make_snapshot_summary(snapshot: Dictionary) -> String:
	var performance: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(snapshot, "performance", {}))
	var architecture: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(snapshot, "architecture", {}))
	var monitors: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(snapshot, "monitors", {}))
	var fps: float = GFVariantData.get_option_float(performance, "fps", 0.0)
	var model_count: int = _count_dictionary_section(architecture, "models")
	var system_count: int = _count_dictionary_section(architecture, "systems")
	var utility_count: int = _count_dictionary_section(architecture, "utilities")
	var monitor_count: int = GFVariantData.get_option_int(monitors, "monitor_count", 0)
	return "FPS：%.1f  Models：%d  Systems：%d  Utilities：%d  Monitors：%d" % [
		fps,
		model_count,
		system_count,
		utility_count,
		monitor_count,
	]


## 读取快照的指定字典分区并返回其键数。
## [br]
## @api private
## [br]
func _count_dictionary_section(source: Dictionary, key: String) -> int:
	var section: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(source, key, {}))
	return section.size()


## 读取当前选项的元数据并转换为预设 ID；控件未初始化时返回空 ID。
## [br]
## @api private
## [br]
func _get_selected_preset_id() -> StringName:
	if _preset_option == null:
		return &""
	var metadata: Variant = _preset_option.get_item_metadata(_preset_option.selected)
	return GFVariantData.to_string_name(metadata)


## 使用诊断树展示器的 debug 脱敏规则序列化诊断值。
## [br]
## @api private
## [br]
func _safe_json(value: Variant) -> String:
	return _DIAGNOSTIC_TREE_PRESENTER.safe_json(value)


# --- 信号处理函数 ---

## 监控预设变化后重新采集诊断快照。
## [br]
## @api private
## [br]
func _on_option_selected(_index: int) -> void:
	collect_snapshot()


## 场景树或日志选项变化后重新采集诊断快照。
## [br]
## @api private
## [br]
func _on_option_toggled(_pressed: bool) -> void:
	collect_snapshot()


## 读取选中树项的元数据并在详情控件显示其脱敏 JSON。
## [br]
## @api private
## [br]
func _on_tree_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	if item == null:
		return
	_details.text = _safe_json(item.get_metadata(0))


## 快照非空时将其脱敏 JSON 复制到剪贴板并更新状态提示。
## [br]
## @api private
## [br]
func _on_copy_pressed() -> void:
	if _last_snapshot.is_empty():
		return
	DisplayServer.clipboard_set(_safe_json(_last_snapshot))
	_EDITOR_WORKSPACE_UI.set_status(_summary_label, "已复制诊断快照。", _EDITOR_WORKSPACE_UI.OK_TEXT_COLOR)
