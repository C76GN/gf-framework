@tool

## GFInputMappingDock: GF 输入映射工作区页面。
##
## 读取 GFInputContext 资源，展示默认绑定或可选 GFInputRemapConfig 覆盖后的
## 有效动作、绑定与重绑定冲突诊断。页面只读，不修改 InputMap 或重映射配置。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
class_name GFInputMappingDock
extends Control


# --- 常量 ---

## 预载编辑器工作区 UI 辅助脚本，用于构建页面控件和状态显示。
## [br]
## @api private
## [br]
const _GFEditorWorkspaceUI = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")

## 预载资源路径工具，用于规范化并比较输入上下文资源路径。
## [br]
## @api private
## [br]
const _GFPathTools = preload("res://addons/gf/kernel/core/gf_path_tools.gd")

## 预载报告值编解码脚本，提供带脱敏和预算限制的 JSON 输出。
## [br]
## @api private
## [br]
const _GF_REPORT_VALUE_CODEC_SCRIPT = preload("res://addons/gf/kernel/core/gf_report_value_codec.gd")

## 预载输入冲突分析器，用于收集绑定并估算候选冲突预算。
## [br]
## @api private
## [br]
const _GFInputConflictAnalyzer = preload("res://addons/gf/standard/input/rebinding/gf_input_conflict_analyzer.gd")

## 预载输入上下文诊断工具，生成报告并提供后续操作建议。
## [br]
## @api private
## [br]
const _GFInputContextDiagnostics = preload("res://addons/gf/standard/input/mapping/gf_input_context_diagnostics.gd")

## 允许预检并载入的输入上下文主资源文件大小上限。
## [br]
## @api private
## [br]
const _MAX_RESOURCE_FILE_BYTES: int = 4 * 1024 * 1024

## 单次输入上下文诊断允许处理的映射数量上限。
## [br]
## @api private
## [br]
const _MAX_MAPPING_COUNT: int = 512

## 单个映射允许参与诊断的绑定数量上限。
## [br]
## @api private
## [br]
const _MAX_BINDINGS_PER_MAPPING: int = 256

## 单次上下文允许累计处理的绑定总数上限。
## [br]
## @api private
## [br]
const _MAX_TOTAL_BINDINGS: int = 512

## 映射、绑定、修饰器与触发器的诊断项数量上限。
## [br]
## @api private
## [br]
const _MAX_NESTED_DIAGNOSTIC_ITEMS: int = 4096

## 冲突候选组合预算上限。
## [br]
## @api private
## [br]
const _MAX_CONFLICT_CANDIDATES: int = 512

## 诊断报告中 items、conflicts 与 issues 集合的显示上限。
## [br]
## @api private
## [br]
const _MAX_REPORT_COLLECTION_ITEMS: int = 512

## 输入映射树视图允许创建的行数上限。
## [br]
## @api private
## [br]
const _MAX_TREE_ROWS: int = 1024

## 右侧详情 JSON 文本允许显示的 UTF-8 字节数上限。
## [br]
## @api private
## [br]
const _MAX_DETAIL_JSON_BYTES: int = 128 * 1024


# --- 私有变量 ---

## 当前展示和诊断的 GFInputContext。
## [br]
## @api private
## [br]
var _context: GFInputContext = null

## 当前用于计算有效绑定的可选 GFInputRemapConfig。
## [br]
## @api private
## [br]
var _remap_config: GFInputRemapConfig = null

## 最近一次成功提交到路径输入框的规范化资源路径。
## [br]
## @api private
## [br]
var _committed_context_path: String = ""

## 最近一次为当前输入上下文生成的诊断报告。
## [br]
## @api private
## [br]
var _last_report: Dictionary = {}

## 最近一次上下文载入失败的状态、提示和错误码。
## [br]
## @api private
## [br]
var _last_load_failure: Dictionary = {}

## 输入 GFInputContext 资源路径的 LineEdit 控件。
## [br]
## @api private
## [br]
var _path_edit: LineEdit = null

## 控制冲突诊断是否纳入不可重绑项的复选框。
## [br]
## @api private
## [br]
var _include_non_remappable_check: CheckBox = null

## 显示当前诊断摘要、资源摘要和下一步建议的标签。
## [br]
## @api private
## [br]
var _summary_label: Label = null

## 无上下文或报告内容时显示提示的标签。
## [br]
## @api private
## [br]
var _empty_label: Label = null

## 承载诊断树和详情文本的水平分栏控件。
## [br]
## @api private
## [br]
var _content_split: HSplitContainer = null

## 展示上下文、映射、绑定及问题项的树控件。
## [br]
## @api private
## [br]
var _tree: Tree = null

## 显示所选树项元数据或报告 JSON 的文本控件。
## [br]
## @api private
## [br]
var _details: TextEdit = null

## 选择 GFInputContext 资源文件的文件对话框。
## [br]
## @api private
## [br]
var _file_dialog: FileDialog = null

## 当前诊断树已经创建的行数。
## [br]
## @api private
## [br]
var _rendered_tree_rows: int = 0

## 标记树视图是否因行数预算而截断。
## [br]
## @api private
## [br]
var _tree_render_truncated: bool = false

## 控制上下文与 remap 配置变化是否允许触发自动刷新。
## [br]
## @api private
## [br]
var _source_observation_enabled: bool = true

## 标记是否已有一次延迟的源数据刷新待执行。
## [br]
## @api private
## [br]
var _source_refresh_queued: bool = false

## 防止诊断刷新重入的状态标志。
## [br]
## @api private
## [br]
var _refresh_in_progress: bool = false


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "GF Input Mapping"
	_GFEditorWorkspaceUI.apply_page_root(self)
	_build_ui()
	refresh()


func _enter_tree() -> void:
	_source_observation_enabled = true
	_connect_context_changed()
	_connect_remap_config_changed()
	if _context != null:
		_queue_source_refresh()


func _exit_tree() -> void:
	_source_observation_enabled = false
	_source_refresh_queued = false
	_disconnect_context_changed()
	_disconnect_remap_config_changed()


# --- 公共方法 ---

## 载入输入上下文资源。
## [br]
## @api public
## [br]
## @param context: 输入上下文资源。
func set_input_context(context: GFInputContext) -> void:
	_set_current_context(context)
	_commit_context_path(context.resource_path if context != null else "")
	refresh()


## 设置诊断使用的可选重映射配置。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param config: 玩家或项目层重映射配置；null 表示只诊断默认绑定。
func set_remap_config(config: GFInputRemapConfig) -> void:
	_set_current_remap_config(config)
	refresh()


## 获取当前诊断使用的重映射配置。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 当前重映射配置；未配置时为 null。
func get_remap_config() -> GFInputRemapConfig:
	return _remap_config


## 从资源路径载入输入上下文。
## [br]
## @api public
## [br]
## @param path: 输入上下文资源路径。
## [br]
## @return Godot 错误码。
func load_context_path(path: String) -> Error:
	var normalized_path: String = _GFPathTools.normalize_resource_path(path)
	if normalized_path.is_empty():
		return _render_load_failure("输入上下文路径为空。", "请填写 GFInputContext 资源路径后再加载。", ERR_INVALID_PARAMETER)
	if not normalized_path.begins_with("res://") and not normalized_path.begins_with("user://"):
		return _render_load_failure("输入上下文路径无效。", "仅支持 res:// 或 user:// 资源路径。", ERR_INVALID_PARAMETER)
	if not _is_supported_resource_extension(normalized_path):
		return _render_load_failure(
			"输入上下文路径无效。",
			"仅支持可预检主资源类型的 .tres 资源：%s" % normalized_path,
			ERR_INVALID_PARAMETER
		)
	if not FileAccess.file_exists(normalized_path):
		return _render_load_failure("输入上下文不存在。", "找不到资源：%s" % normalized_path, ERR_FILE_NOT_FOUND)

	var resource_file: FileAccess = FileAccess.open(normalized_path, FileAccess.READ)
	if resource_file == null:
		var open_error: Error = FileAccess.get_open_error()
		return _render_load_failure("输入上下文不可读。", "无法读取资源：%s" % normalized_path, open_error)
	var resource_file_bytes: int = resource_file.get_length()
	resource_file.close()
	if resource_file_bytes > _MAX_RESOURCE_FILE_BYTES:
		return _render_load_failure(
			"输入上下文超过大小预算。",
			"资源大小 %d bytes，大小预算为 %d bytes：%s" % [
				resource_file_bytes,
				_MAX_RESOURCE_FILE_BYTES,
				normalized_path,
			],
			ERR_OUT_OF_MEMORY
		)
	var declared_resource_type: String = _read_text_resource_declared_type(normalized_path)
	if not _is_input_context_resource_type(declared_resource_type):
		return _render_load_failure(
			"输入上下文类型不匹配。",
			"资源声明类型 %s 不是 GFInputContext：%s" % [
				declared_resource_type if not declared_resource_type.is_empty() else "<unknown>",
				normalized_path,
			],
			ERR_INVALID_DATA
		)

	var reloads_current_context: bool = (
		_context != null
		and _resource_paths_share_identity(_context.resource_path, normalized_path)
	)
	if reloads_current_context:
		_disconnect_context_changed()
	var resource: Resource = ResourceLoader.load(
		normalized_path,
		"GFInputContext",
		ResourceLoader.CACHE_MODE_REPLACE
	)
	var context: GFInputContext = _get_input_context_value(resource)
	if context == null:
		if reloads_current_context:
			_connect_context_changed()
		return _render_load_failure(
			"输入上下文加载失败。",
			"资源不是 GFInputContext：%s" % normalized_path,
			ERR_INVALID_DATA
		)

	_set_current_context(context)
	var committed_path: String = normalized_path
	if reloads_current_context and _resource_paths_share_identity(_committed_context_path, normalized_path):
		committed_path = _committed_context_path
	elif not context.resource_path.is_empty():
		committed_path = context.resource_path
	_commit_context_path(committed_path)
	refresh()
	return OK


## 刷新当前上下文诊断。
## [br]
## @api public
func refresh() -> void:
	_source_refresh_queued = false
	if _refresh_in_progress:
		_queue_source_refresh()
		return
	_refresh_in_progress = true
	_last_load_failure = {}
	_refresh_current_context()
	_refresh_in_progress = false

## 获取最近一次诊断报告。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 诊断报告副本。
## [br]
## @schema return: Dictionary，基于当前 GFInputContext 与可选 GFInputRemapConfig 构建的校验报告，包含摘要、问题计数、冲突、remap_configured 和后续动作。
func get_last_report() -> Dictionary:
	return _last_report.duplicate(true)


# --- 私有/辅助方法 ---

## 构建 UI；无上下文时清空报告并显示空态，否则生成报告并渲染。
## [br]
## @api private
## [br]
func _refresh_current_context() -> void:
	_build_ui()
	if _context == null:
		_last_report = {}
		_render_empty("未加载输入上下文。", "选择或填写 GFInputContext 资源后点击加载。")
		return

	_last_report = _build_report(_context)
	_render_context()


## 仅在控件尚未创建时构建输入工具栏、诊断树、详情面板和资源选择框。
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

	var toolbar: HBoxContainer = _GFEditorWorkspaceUI.make_toolbar()
	root_box.add_child(toolbar)

	_path_edit = LineEdit.new()
	_path_edit.placeholder_text = "res://path/to/input_context.tres"
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _path_submitted_connected: Error = _path_edit.text_submitted.connect(_on_path_submitted) as Error
	toolbar.add_child(_path_edit)

	toolbar.add_child(_GFEditorWorkspaceUI.make_button("...", "选择输入上下文资源。", _on_browse_pressed))
	toolbar.add_child(_GFEditorWorkspaceUI.make_button("加载", "载入当前路径中的输入上下文。", _on_load_pressed))
	toolbar.add_child(_GFEditorWorkspaceUI.make_button("刷新", "重新分析当前输入上下文。", refresh))

	_include_non_remappable_check = CheckBox.new()
	_include_non_remappable_check.text = "包含不可重绑"
	_include_non_remappable_check.button_pressed = true
	_include_non_remappable_check.tooltip_text = "冲突分析是否包含不可重绑定的动作和绑定。"
	var _option_toggled_connected: Error = _include_non_remappable_check.toggled.connect(_on_option_toggled) as Error
	toolbar.add_child(_include_non_remappable_check)

	toolbar.add_child(_GFEditorWorkspaceUI.make_button("复制报告", "复制当前输入映射诊断 JSON。", _on_copy_pressed))

	_summary_label = _GFEditorWorkspaceUI.make_summary_label()
	root_box.add_child(_summary_label)

	_empty_label = _GFEditorWorkspaceUI.make_empty_label()
	root_box.add_child(_empty_label)

	_content_split = HSplitContainer.new()
	_content_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(_content_split)

	_tree = Tree.new()
	_tree.columns = 4
	_tree.hide_root = true
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "类型")
	_tree.set_column_title(1, "标识")
	_tree.set_column_title(2, "绑定")
	_tree.set_column_title(3, "说明")
	_tree.set_column_expand(3, true)
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var _tree_item_selected_connected: Error = _tree.item_selected.connect(_on_tree_item_selected) as Error
	_content_split.add_child(_tree)

	_details = _GFEditorWorkspaceUI.make_details_output()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_split.add_child(_details)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.filters = PackedStringArray(["*.tres ; GFInputContext resources"])
	var _file_selected_connected: Error = _file_dialog.file_selected.connect(_on_file_selected) as Error
	add_child(_file_dialog)


## 先检查上下文与冲突预算；通过后构建诊断报告并限制其集合长度。
## [br]
## @api private
## [br]
func _build_report(context: GFInputContext) -> Dictionary:
	var include_non_remappable: bool = (
		_include_non_remappable_check == null
		or _include_non_remappable_check.button_pressed
	)
	var budget_issue: Dictionary = _get_context_budget_issue(context, include_non_remappable)
	if not budget_issue.is_empty():
		return _make_budget_report(context, budget_issue)
	var report: Dictionary = _GFInputContextDiagnostics.build_context_report(
		context,
		_remap_config,
		include_non_remappable
	)
	report["remap_configured"] = _remap_config != null
	return _bound_report_collections(report)


## 检查映射数、绑定数、嵌套诊断项及轴冲突候选预算，返回首个超限问题。
## [br]
## @api private
## [br]
func _get_context_budget_issue(context: GFInputContext, include_non_remappable: bool) -> Dictionary:
	var mapping_count: int = context.mappings.size()
	if mapping_count > _MAX_MAPPING_COUNT:
		return _make_budget_issue(
			"mapping_budget_exceeded",
			"mappings",
			"输入上下文包含 %d 个映射，超过编辑器诊断预算 %d。" % [mapping_count, _MAX_MAPPING_COUNT],
			mapping_count,
			_MAX_MAPPING_COUNT
		)

	var total_binding_count: int = 0
	var nested_item_count: int = mapping_count
	for mapping_index: int in range(mapping_count):
		var mapping: GFInputMapping = context.mappings[mapping_index]
		if mapping == null:
			continue
		var mapping_binding_count: int = mapping.bindings.size()
		if mapping_binding_count > _MAX_BINDINGS_PER_MAPPING:
			return _make_budget_issue(
				"binding_budget_exceeded",
				"mappings/%d/bindings" % mapping_index,
				"单个映射包含 %d 个绑定，超过编辑器诊断预算 %d。" % [
					mapping_binding_count,
					_MAX_BINDINGS_PER_MAPPING,
				],
				mapping_binding_count,
				_MAX_BINDINGS_PER_MAPPING
			)
		total_binding_count += mapping_binding_count
		if total_binding_count > _MAX_TOTAL_BINDINGS:
			return _make_budget_issue(
				"binding_budget_exceeded",
				"mappings",
				"输入上下文包含 %d 个绑定，超过编辑器诊断预算 %d。" % [
					total_binding_count,
					_MAX_TOTAL_BINDINGS,
				],
				total_binding_count,
				_MAX_TOTAL_BINDINGS
			)

		nested_item_count += mapping_binding_count + mapping.modifiers.size() + mapping.triggers.size()
		for binding: GFInputBinding in mapping.bindings:
			if binding != null:
				nested_item_count += binding.modifiers.size()
		if nested_item_count > _MAX_NESTED_DIAGNOSTIC_ITEMS:
			return _make_budget_issue(
				"diagnostic_item_budget_exceeded",
				"mappings/%d" % mapping_index,
				"输入上下文的嵌套诊断条目超过预算 %d。" % _MAX_NESTED_DIAGNOSTIC_ITEMS,
				nested_item_count,
				_MAX_NESTED_DIAGNOSTIC_ITEMS
			)

	var contexts: Array[GFInputContext] = [context]
	var binding_items: Array[Dictionary] = _GFInputConflictAnalyzer.collect_binding_items(
		contexts,
		_remap_config,
		include_non_remappable
	)
	var candidate_count_by_bucket: Dictionary = {}
	var conflict_candidate_count: int = 0
	for item: Dictionary in binding_items:
		var event_key: String = GFVariantData.get_option_string(item, "event_key")
		var bucket_key: String = _get_conflict_candidate_bucket(event_key)
		if bucket_key.is_empty():
			continue
		var existing_count: int = GFVariantData.get_option_int(candidate_count_by_bucket, bucket_key)
		conflict_candidate_count += existing_count
		if conflict_candidate_count > _MAX_CONFLICT_CANDIDATES:
			return _make_budget_issue(
				"conflict_budget_exceeded",
				"bindings",
				"潜在绑定冲突数量超过编辑器诊断预算 %d。" % _MAX_CONFLICT_CANDIDATES,
				conflict_candidate_count,
				_MAX_CONFLICT_CANDIDATES
			)
		candidate_count_by_bucket[bucket_key] = existing_count + 1
	return {}


## 把预算超限信息包装为 error 级问题，并携带观测数量与上限。
## [br]
## @api private
## [br]
func _make_budget_issue(
	kind: String,
	path: String,
	message: String,
	observed_count: int,
	max_count: int
) -> Dictionary:
	return _make_issue("error", kind, path, message, {
		"observed_count": observed_count,
		"max_count": max_count,
	})


## 为预算超限构建停止深入扫描的最小报告，并补充相应的 next action。
## [br]
## @api private
## [br]
func _make_budget_report(context: GFInputContext, issue: Dictionary) -> Dictionary:
	var report: Dictionary = {
		"context_count": 1,
		"mapping_count": context.mappings.size(),
		"binding_count": 0,
		"conflict_count": 0,
		"item_count": 0,
		"items": [],
		"conflicts": [],
		"contexts": [_make_context_details(context)],
		"context_id": context.get_context_id(),
		"context_name": context.get_display_name(),
		"remap_configured": _remap_config != null,
		"issues": [issue],
		"resource_summary": "上下文诊断已在安全预算边界停止。",
	}
	var next_actions: Dictionary = _GFInputContextDiagnostics.get_next_actions()
	next_actions["mapping_budget_exceeded"] = "拆分输入上下文，或减少单次编辑器诊断包含的映射。"
	next_actions["binding_budget_exceeded"] = "拆分输入上下文或映射，降低单次诊断的绑定数量。"
	next_actions["diagnostic_item_budget_exceeded"] = "减少嵌套修饰器与触发器，或拆分输入上下文。"
	next_actions["conflict_budget_exceeded"] = "先拆分冲突域，再分别运行输入映射诊断。"
	return GFValidationReportDictionary.finalize_report(report, "Input mapping", {
		"include_issue_count": true,
		"next_actions": next_actions,
		"fallback_action": "缩小输入上下文后重新诊断。",
		"no_action": "当前输入上下文结构健康。",
	})


## 截断报告中的 items、conflicts 和 issues，并记录原总数与截断标记。
## [br]
## @api private
## [br]
func _bound_report_collections(report: Dictionary) -> Dictionary:
	for collection_key: String in ["items", "conflicts", "issues"]:
		var values: Array = GFVariantData.get_option_array(report, collection_key)
		if values.size() <= _MAX_REPORT_COLLECTION_ITEMS:
			continue
		var original_count: int = values.size()
		var bounded_values: Array = values.slice(0, _MAX_REPORT_COLLECTION_ITEMS)
		if collection_key == "issues":
			var _resize_result: int = bounded_values.resize(_MAX_REPORT_COLLECTION_ITEMS - 1)
			bounded_values.append(_make_issue(
				"warning",
				"issue_budget_truncated",
				"issues",
				"问题列表已按编辑器显示预算截断；总数为 %d。" % original_count,
				{
					"reported_count": original_count,
					"displayed_count": _MAX_REPORT_COLLECTION_ITEMS,
				}
			))
		report[collection_key] = bounded_values
		report["%s_truncated" % collection_key] = true
		report["%s_total_count" % collection_key] = original_count
	return report


## 普通事件键原样分桶；joy_axis 键按轴号合并正负方向以计算候选冲突量。
## [br]
## @api private
## [br]
func _get_conflict_candidate_bucket(event_key: String) -> String:
	if not event_key.begins_with("joy_axis:"):
		return event_key
	var parts: PackedStringArray = event_key.split(":")
	if parts.size() < 2:
		return event_key
	return "joy_axis:%s" % parts[1]


## 清空并重绘诊断摘要、上下文及其映射、绑定和问题树项，受行数预算限制。
## [br]
## @api private
## [br]
func _render_context() -> void:
	if _tree == null:
		return

	_tree.clear()
	_details.text = _safe_json(_make_report_overview())
	_empty_label.visible = false
	_content_split.visible = true
	_tree.visible = true
	_rendered_tree_rows = 0
	_tree_render_truncated = false
	var resource_summary: String = GFVariantData.get_option_string(_last_report, "resource_summary", "")
	_summary_label.text = "%s\n%s\n下一步：%s" % [
		GFVariantData.get_option_string(_last_report, "summary", ""),
		resource_summary,
		GFVariantData.get_option_string(_last_report, "next_action", ""),
	]
	_summary_label.modulate = _GFEditorWorkspaceUI.get_report_color(_last_report)

	var root_item: TreeItem = _tree.create_item()
	var context_item: TreeItem = _create_bounded_tree_item(root_item)
	if context_item == null:
		_append_tree_truncation_item(root_item)
		return
	context_item.set_text(0, "上下文")
	context_item.set_text(1, String(_context.get_context_id()))
	context_item.set_text(2, "%d mappings" % _context.mappings.size())
	context_item.set_text(3, _context.get_display_name())
	context_item.set_metadata(0, _make_context_details(_context))

	for mapping_index: int in range(_context.mappings.size()):
		if _tree_render_truncated:
			break
		var mapping: GFInputMapping = _context.mappings[mapping_index]
		if mapping == null:
			continue
		var mapping_item: TreeItem = _create_bounded_tree_item(root_item)
		if mapping_item == null:
			break
		mapping_item.set_text(0, "动作")
		mapping_item.set_text(1, String(mapping.get_action_id()))
		mapping_item.set_text(2, GFInputFormatter.mapping_as_text(
			mapping,
			_context.get_context_id(),
			_remap_config
		))
		mapping_item.set_text(3, "%s · %s" % [
			mapping.get_display_name(),
			_get_value_type_name(mapping.action.value_type) if mapping.action != null else "missing action",
		])
		mapping_item.set_metadata(0, _make_mapping_details(mapping, mapping_index))
		_add_binding_items(mapping_item, mapping)

	if not _tree_render_truncated:
		for issue_value: Variant in GFVariantData.get_option_array(_last_report, "issues"):
			if not (issue_value is Dictionary):
				continue
			var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
			_add_issue_item(root_item, issue)
			if _tree_render_truncated:
				break
	_append_tree_truncation_item(root_item)


## 为映射逐个创建绑定树行，并展示 remap 后的有效事件及绑定属性。
## [br]
## @api private
## [br]
func _add_binding_items(parent: TreeItem, mapping: GFInputMapping) -> void:
	for binding_index: int in range(mapping.bindings.size()):
		if _tree_render_truncated:
			return
		var binding: GFInputBinding = mapping.bindings[binding_index]
		if binding == null:
			continue
		var item: TreeItem = _create_bounded_tree_item(parent)
		if item == null:
			return
		var binding_is_remapped: bool = _is_binding_remapped(mapping, binding_index)
		var effective_event: InputEvent = _get_effective_binding_event(mapping, binding_index)
		var effective_text: String = (
			GFInputFormatter.input_event_as_text(effective_event)
			if binding_is_remapped
			else GFInputFormatter.binding_as_text(binding)
		)
		item.set_text(0, "绑定")
		item.set_text(1, "%d" % binding_index)
		item.set_text(2, effective_text)
		item.set_text(3, "%s · deadzone %.2f · scale %.2f" % [
			_get_value_target_name(binding.value_target),
			binding.deadzone,
			binding.scale,
		])
		item.set_metadata(0, _make_binding_details(
			mapping,
			binding,
			binding_index,
			effective_event,
			effective_text,
			binding_is_remapped
		))


## 把诊断问题的严重度、类别、路径和消息写入树行及元数据。
## [br]
## @api private
## [br]
func _add_issue_item(parent: TreeItem, issue: Dictionary) -> void:
	var item: TreeItem = _create_bounded_tree_item(parent)
	if item == null:
		return
	item.set_text(0, GFVariantData.get_option_string(issue, "severity", ""))
	item.set_text(1, GFVariantData.get_option_string(issue, "kind", ""))
	item.set_text(2, GFVariantData.get_option_string(issue, "path", ""))
	item.set_text(3, GFVariantData.get_option_string(issue, "message", ""))
	item.set_metadata(0, issue.duplicate(true))


## 在达到保留截断提示行的显示预算前创建一行，否则标记树截断。
## [br]
## @api private
## [br]
func _create_bounded_tree_item(parent: TreeItem) -> TreeItem:
	if _rendered_tree_rows >= _MAX_TREE_ROWS - 1:
		_tree_render_truncated = true
		return null
	_rendered_tree_rows += 1
	return _tree.create_item(parent)


## 树已截断且仍有行预算时追加预算提示行及其元数据。
## [br]
## @api private
## [br]
func _append_tree_truncation_item(parent: TreeItem) -> void:
	if not _tree_render_truncated or _rendered_tree_rows >= _MAX_TREE_ROWS:
		return
	var item: TreeItem = _tree.create_item(parent)
	_rendered_tree_rows += 1
	item.set_text(0, "截断")
	item.set_text(1, "tree_row_budget")
	item.set_text(3, "树视图已达到 %d 行显示预算。" % _MAX_TREE_ROWS)
	item.set_metadata(0, {
		"kind": "tree_row_budget",
		"max_rows": _MAX_TREE_ROWS,
		"truncated": true,
	})


## 清空或隐藏诊断树与详情区，显示空态提示并设置状态颜色。
## [br]
## @api private
## [br]
func _render_empty(status: String, hint: String = "") -> void:
	if _tree != null:
		_tree.clear()
		_tree.visible = false
	if _content_split != null:
		_content_split.visible = false
	if _details != null:
		_details.text = hint if not hint.is_empty() else status
	if _empty_label != null:
		_empty_label.text = hint if not hint.is_empty() else status
		_empty_label.visible = true
	_set_status(status, _GFEditorWorkspaceUI.INFO_TEXT_COLOR)


## 恢复已提交路径并保存失败信息；有旧报告时保留并标记旧结果，否则显示空态。
## [br]
## @api private
## [br]
func _render_load_failure(status: String, hint: String, error_code: Error) -> Error:
	_restore_committed_context_path()
	_last_load_failure = {
		"status": status,
		"hint": hint,
		"error_code": error_code,
		"committed_context_path": _committed_context_path,
	}
	if _context != null and not _last_report.is_empty():
		_render_context()
		_details.text = _safe_json(_make_copy_payload())
		_set_status(
			"%s\n已保留上次成功载入的上下文与诊断。" % status,
			_GFEditorWorkspaceUI.ERROR_TEXT_COLOR
		)
	else:
		_render_empty(status, hint)
	return error_code


## 规范化并提交资源路径，然后同步到路径输入框。
## [br]
## @api private
## [br]
func _commit_context_path(path: String) -> void:
	_committed_context_path = _GFPathTools.normalize_resource_path(path)
	_restore_committed_context_path()


## 路径输入控件存在时恢复最近提交的路径文本。
## [br]
## @api private
## [br]
func _restore_committed_context_path() -> void:
	if _path_edit != null:
		_path_edit.text = _committed_context_path


## 从当前上下文和报告中构造适合详情面板展示的摘要字典。
## [br]
## @api private
## [br]
func _make_report_overview() -> Dictionary:
	return {
		"context": _make_context_details(_context),
		"report": {
			"ok": GFVariantData.get_option_bool(_last_report, "ok"),
			"healthy": GFVariantData.get_option_bool(_last_report, "healthy"),
			"summary": GFVariantData.get_option_string(_last_report, "summary"),
			"resource_summary": GFVariantData.get_option_string(_last_report, "resource_summary"),
			"next_action": GFVariantData.get_option_string(_last_report, "next_action"),
			"mapping_count": GFVariantData.get_option_int(_last_report, "mapping_count"),
			"binding_count": GFVariantData.get_option_int(_last_report, "binding_count"),
			"conflict_count": GFVariantData.get_option_int(_last_report, "conflict_count"),
			"issue_count": GFVariantData.get_option_int(_last_report, "issue_count"),
			"issues_truncated": GFVariantData.get_option_bool(_last_report, "issues_truncated"),
			"remap_configured": GFVariantData.get_option_bool(_last_report, "remap_configured"),
		},
	}


## 生成上下文 ID、显示名、资源路径和映射数快照。
## [br]
## @api private
## [br]
func _make_context_details(context: GFInputContext) -> Dictionary:
	return {
		"context_id": context.get_context_id(),
		"display_name": context.get_display_name(),
		"resource_path": context.resource_path,
		"mapping_count": context.mappings.size(),
	}


## 生成映射索引、动作信息、值类型及绑定、修饰器和触发器计数。
## [br]
## @api private
## [br]
func _make_mapping_details(mapping: GFInputMapping, mapping_index: int) -> Dictionary:
	return {
		"index": mapping_index,
		"action_id": mapping.get_action_id(),
		"display_name": mapping.get_display_name(),
		"display_category": mapping.get_display_category(),
		"value_type": _get_value_type_name(mapping.action.value_type) if mapping.action != null else "",
		"binding_count": mapping.bindings.size(),
		"modifier_count": mapping.modifiers.size(),
		"trigger_count": mapping.triggers.size(),
	}


## 生成绑定有效事件、目标、deadzone、scale、匹配设置和 remap 来源详情。
## [br]
## @api private
## [br]
func _make_binding_details(
	mapping: GFInputMapping,
	binding: GFInputBinding,
	binding_index: int,
	effective_event: InputEvent,
	effective_text: String,
	remapped: bool
) -> Dictionary:
	var details: Dictionary = {
		"index": binding_index,
		"text": effective_text,
		"input_event": GFInputFormatter.input_event_as_text(effective_event),
		"value_target": _get_value_target_name(binding.value_target),
		"deadzone": binding.deadzone,
		"scale": binding.scale,
		"match_device": binding.match_device,
		"match_touch_index": binding.match_touch_index,
		"remappable": binding.remappable,
		"remapped": remapped,
		"modifier_count": binding.modifiers.size(),
	}
	if remapped:
		details["source_input_event"] = GFInputFormatter.input_event_as_text(binding.input_event)
		details["context_id"] = _context.get_context_id() if _context != null else &""
		details["action_id"] = mapping.get_action_id()
	return details


## 检查当前 remap 配置是否覆盖给定上下文、动作和绑定索引。
## [br]
## @api private
## [br]
func _is_binding_remapped(mapping: GFInputMapping, binding_index: int) -> bool:
	return (
		_remap_config != null
		and _context != null
		and _remap_config.has_binding(
			_context.get_context_id(),
			mapping.get_action_id(),
			binding_index
		)
	)


## 绑定被 remap 时返回覆盖事件，否则返回绑定自身的输入事件。
## [br]
## @api private
## [br]
func _get_effective_binding_event(mapping: GFInputMapping, binding_index: int) -> InputEvent:
	var binding: GFInputBinding = mapping.bindings[binding_index]
	if _is_binding_remapped(mapping, binding_index):
		return _remap_config.get_bound_event_or_null(
			_context.get_context_id(),
			mapping.get_action_id(),
			binding_index
		)
	return binding.input_event


## 无载入失败时复制报告；有失败时返回失败尝试与上次成功报告的组合快照。
## [br]
## @api private
## [br]
func _make_copy_payload() -> Dictionary:
	if _last_load_failure.is_empty():
		return _last_report.duplicate(true)
	return {
		"kind": "input_mapping_load_failure",
		"stale": not _last_report.is_empty(),
		"current_attempt": _last_load_failure.duplicate(true),
		"committed_context": _make_context_details(_context) if _context != null else {},
		"last_successful_report": _last_report.duplicate(true),
	}


## 构造包含严重度、类别、路径和消息的问题字典，并在非空时复制 metadata。
## [br]
## @api private
## [br]
func _make_issue(
	severity: String,
	kind: String,
	path: String,
	message: String,
	metadata: Dictionary = {}
) -> Dictionary:
	var issue: Dictionary = {
		"severity": severity,
		"kind": kind,
		"path": path,
		"message": message,
	}
	if not metadata.is_empty():
		issue["metadata"] = metadata.duplicate(true)
	return issue


## 把状态消息与颜色委派给工作区 UI 辅助脚本。
## [br]
## @api private
## [br]
func _set_status(message: String, color: Color) -> void:
	_GFEditorWorkspaceUI.set_status(_summary_label, message, color)


## 把 GFInputAction.ValueType 枚举映射为稳定文本，未知值带原整数。
## [br]
## @api private
## [br]
func _get_value_type_name(value_type: int) -> String:
	match value_type:
		GFInputAction.ValueType.BOOL:
			return "bool"
		GFInputAction.ValueType.AXIS_1D:
			return "axis_1d"
		GFInputAction.ValueType.AXIS_2D:
			return "axis_2d"
		GFInputAction.ValueType.AXIS_3D:
			return "axis_3d"
		_:
			return "unknown(%d)" % value_type


## 把 GFInputBinding.ValueTarget 枚举映射为稳定文本，未知值带原整数。
## [br]
## @api private
## [br]
func _get_value_target_name(value_target: int) -> String:
	match value_target:
		GFInputBinding.ValueTarget.AUTO:
			return "auto"
		GFInputBinding.ValueTarget.BOOL:
			return "bool"
		GFInputBinding.ValueTarget.AXIS_1D_POSITIVE:
			return "axis_1d_positive"
		GFInputBinding.ValueTarget.AXIS_1D_NEGATIVE:
			return "axis_1d_negative"
		GFInputBinding.ValueTarget.AXIS_2D_X_POSITIVE:
			return "axis_2d_x_positive"
		GFInputBinding.ValueTarget.AXIS_2D_X_NEGATIVE:
			return "axis_2d_x_negative"
		GFInputBinding.ValueTarget.AXIS_2D_Y_POSITIVE:
			return "axis_2d_y_positive"
		GFInputBinding.ValueTarget.AXIS_2D_Y_NEGATIVE:
			return "axis_2d_y_negative"
		GFInputBinding.ValueTarget.AXIS_3D_X_POSITIVE:
			return "axis_3d_x_positive"
		GFInputBinding.ValueTarget.AXIS_3D_X_NEGATIVE:
			return "axis_3d_x_negative"
		GFInputBinding.ValueTarget.AXIS_3D_Y_POSITIVE:
			return "axis_3d_y_positive"
		GFInputBinding.ValueTarget.AXIS_3D_Y_NEGATIVE:
			return "axis_3d_y_negative"
		GFInputBinding.ValueTarget.AXIS_3D_Z_POSITIVE:
			return "axis_3d_z_positive"
		GFInputBinding.ValueTarget.AXIS_3D_Z_NEGATIVE:
			return "axis_3d_z_negative"
		_:
			return "unknown(%d)" % value_target


## 使用 debug 脱敏选项和遍历预算序列化 JSON；超出详情字节预算时返回截断摘要。
## [br]
## @api private
## [br]
func _safe_json(value: Variant) -> String:
	var options: Dictionary = _GF_REPORT_VALUE_CODEC_SCRIPT.make_redaction_options(
		_GF_REPORT_VALUE_CODEC_SCRIPT.REDACTION_PROFILE_DEBUG,
		{
			"max_depth": 16,
			"max_string_length": 4096,
			"max_collection_items": _MAX_REPORT_COLLECTION_ITEMS,
			"max_total_nodes": 8192,
		}
	)
	var text: String = _GF_REPORT_VALUE_CODEC_SCRIPT.stringify_json_compatible(
		value,
		"\t",
		true,
		options
	)
	var encoded_bytes: int = text.to_utf8_buffer().size()
	if encoded_bytes <= _MAX_DETAIL_JSON_BYTES:
		return text
	return _GF_REPORT_VALUE_CODEC_SCRIPT.stringify_json_compatible({
		"kind": "detail_text_budget_exceeded",
		"truncated": true,
		"encoded_size_bytes": encoded_bytes,
		"max_bytes": _MAX_DETAIL_JSON_BYTES,
	}, "\t", true, options)


## 仅当资源路径扩展名为 tres 时返回 true。
## [br]
## @api private
## [br]
func _is_supported_resource_extension(path: String) -> bool:
	var extension: String = path.get_extension().to_lower()
	return extension == "tres"


## 规范化并绝对化资源路径；Windows 按大小写不敏感方式比较。
## [br]
## @api private
## [br]
func _resource_paths_share_identity(left: String, right: String) -> bool:
	var normalized_left: String = _GFPathTools.normalize_resource_path(left)
	var normalized_right: String = _GFPathTools.normalize_resource_path(right)
	if normalized_left.is_empty() or normalized_right.is_empty():
		return normalized_left == normalized_right
	var absolute_left: String = _GFPathTools.normalize_path(
		ProjectSettings.globalize_path(normalized_left)
	)
	var absolute_right: String = _GFPathTools.normalize_path(
		ProjectSettings.globalize_path(normalized_right)
	)
	if OS.get_name() == "Windows":
		return absolute_left.to_lower() == absolute_right.to_lower()
	return absolute_left == absolute_right


## 读取资源文件头首行，去除 BOM，并提取 script_class 或 type 声明。
## [br]
## @api private
## [br]
func _read_text_resource_declared_type(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var header_bytes: PackedByteArray = file.get_buffer(mini(file.get_length(), 4096))
	file.close()
	var header: String = header_bytes.get_string_from_utf8().get_slice("\n", 0).strip_edges()
	if header.begins_with(String.chr(0xFEFF)):
		header = header.substr(1)
	if not header.begins_with("[gd_resource ") or not header.ends_with("]"):
		return ""
	var script_class: String = _get_resource_header_attribute(header, "script_class")
	if not script_class.is_empty():
		return script_class
	return _get_resource_header_attribute(header, "type")


## 从资源头中读取指定 attribute 的双引号值，格式或属性缺失时返回空文本。
## [br]
## @api private
## [br]
func _get_resource_header_attribute(header: String, attribute: String) -> String:
	var marker: String = "%s=\"" % attribute
	var value_start: int = header.find(marker)
	if value_start < 0:
		return ""
	value_start += marker.length()
	var value_end: int = header.find("\"", value_start)
	if value_end < value_start:
		return ""
	return header.substr(value_start, value_end - value_start)


## 沿 Godot 全局类的 base 链检查声明类型是否为 GFInputContext 或其派生类。
## [br]
## @api private
## [br]
func _is_input_context_resource_type(resource_type: String) -> bool:
	if resource_type == "GFInputContext":
		return true

	var base_by_class: Dictionary = {}
	for class_value: Variant in ProjectSettings.get_global_class_list():
		if not (class_value is Dictionary):
			continue
		var class_record: Dictionary = GFVariantData.as_dictionary(class_value)
		var class_name_value: String = GFVariantData.get_option_string(class_record, "class")
		if class_name_value.is_empty():
			continue
		base_by_class[class_name_value] = GFVariantData.get_option_string(class_record, "base")

	var visited: Dictionary = {}
	var current_type: String = resource_type
	while not current_type.is_empty() and not visited.has(current_type):
		if current_type == "GFInputContext":
			return true
		visited[current_type] = true
		current_type = GFVariantData.get_option_string(base_by_class, current_type)
	return false


## 上下文对象变化时断开旧信号、替换引用，并确保连接当前 changed 信号。
## [br]
## @api private
## [br]
func _set_current_context(context: GFInputContext) -> void:
	if _context != context:
		_disconnect_context_changed()
		_context = context
	_connect_context_changed()


## remap 配置变化时断开旧信号、替换引用，并确保连接当前 changed 信号。
## [br]
## @api private
## [br]
func _set_current_remap_config(config: GFInputRemapConfig) -> void:
	if _remap_config != config:
		_disconnect_remap_config_changed()
		_remap_config = config
	_connect_remap_config_changed()


## 仅在源观察开启且上下文存在时，幂等连接 changed 刷新回调。
## [br]
## @api private
## [br]
func _connect_context_changed() -> void:
	if not _source_observation_enabled or _context == null:
		return
	var callback: Callable = _on_context_changed
	if not _context.changed.is_connected(callback):
		var _changed_connected: Error = _context.changed.connect(callback) as Error


## 上下文存在且 changed 回调已连接时断开。
## [br]
## @api private
## [br]
func _disconnect_context_changed() -> void:
	if _context == null:
		return
	var callback: Callable = _on_context_changed
	if _context.changed.is_connected(callback):
		_context.changed.disconnect(callback)


## 仅在源观察开启且 remap 配置存在时，幂等连接 changed 刷新回调。
## [br]
## @api private
## [br]
func _connect_remap_config_changed() -> void:
	if not _source_observation_enabled or _remap_config == null:
		return
	var callback: Callable = _on_remap_config_changed
	if not _remap_config.changed.is_connected(callback):
		var _changed_connected: Error = _remap_config.changed.connect(callback) as Error


## remap 配置存在且 changed 回调已连接时断开。
## [br]
## @api private
## [br]
func _disconnect_remap_config_changed() -> void:
	if _remap_config == null:
		return
	var callback: Callable = _on_remap_config_changed
	if _remap_config.changed.is_connected(callback):
		_remap_config.changed.disconnect(callback)


## 源观察开启且尚无排队刷新时，设置标志并延迟调用刷新处理。
## [br]
## @api private
## [br]
func _queue_source_refresh() -> void:
	if not _source_observation_enabled or _source_refresh_queued:
		return
	_source_refresh_queued = true
	call_deferred("_flush_source_refresh")


## 仅在观察仍开启且刷新仍排队时清除标志并调用 refresh。
## [br]
## @api private
## [br]
func _flush_source_refresh() -> void:
	if not _source_observation_enabled or not _source_refresh_queued:
		return
	_source_refresh_queued = false
	refresh()


## 将 Variant 收窄为 GFInputContext，类型不符时返回 null。
## [br]
## @api private
## [br]
func _get_input_context_value(value: Variant) -> GFInputContext:
	if value is GFInputContext:
		var context: GFInputContext = value
		return context
	return null


# --- 信号处理函数 ---

## 上下文 changed 信号到达时排队执行一次源数据刷新。
## [br]
## @api private
## [br]
func _on_context_changed() -> void:
	_queue_source_refresh()


## remap 配置 changed 信号到达时排队执行一次源数据刷新。
## [br]
## @api private
## [br]
func _on_remap_config_changed() -> void:
	_queue_source_refresh()


## 路径输入框提交时调用 load_context_path 载入该路径。
## [br]
## @api private
## [br]
func _on_path_submitted(path: String) -> void:
	var _load_error: Error = load_context_path(path)


## 文件对话框有效时居中弹出资源选择窗口。
## [br]
## @api private
## [br]
func _on_browse_pressed() -> void:
	if is_instance_valid(_file_dialog):
		_file_dialog.popup_centered_ratio(0.6)


## 选择文件后更新路径输入框并尝试载入该资源。
## [br]
## @api private
## [br]
func _on_file_selected(path: String) -> void:
	if _path_edit != null:
		_path_edit.text = path
	var _load_error: Error = load_context_path(path)


## 路径输入控件存在时载入其中填写的资源路径。
## [br]
## @api private
## [br]
func _on_load_pressed() -> void:
	if _path_edit == null:
		return
	var _load_error: Error = load_context_path(_path_edit.text)


## 不可重绑选项变化后重新刷新当前诊断。
## [br]
## @api private
## [br]
func _on_option_toggled(_pressed: bool) -> void:
	refresh()


## 选中树项后将该项 metadata 安全序列化到详情面板。
## [br]
## @api private
## [br]
func _on_tree_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	if item == null:
		return
	_details.text = _safe_json(item.get_metadata(0))


## 生成非空诊断/失败快照并写入剪贴板，再按载入状态显示成功或警告。
## [br]
## @api private
## [br]
func _on_copy_pressed() -> void:
	var payload: Dictionary = _make_copy_payload()
	if payload.is_empty():
		return
	DisplayServer.clipboard_set(_safe_json(payload))
	if _last_load_failure.is_empty():
		_set_status("已复制输入映射诊断报告。", _GFEditorWorkspaceUI.OK_TEXT_COLOR)
	else:
		_set_status(
			"%s\n已复制加载失败与上次成功诊断。" % GFVariantData.get_option_string(
				_last_load_failure,
				"status"
			),
			_GFEditorWorkspaceUI.WARNING_TEXT_COLOR
		)
