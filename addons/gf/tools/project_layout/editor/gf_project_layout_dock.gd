@tool

## GFProjectLayoutDock: GF Project Layout 只读工作区页面。
##
## 页面按用户操作捕获项目库存，在后台生成分析结果，并展示 finding、解释、影响和计划。
## 它不提供 Apply、自动修复、创建、移动、重命名或删除入口。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since unreleased
class_name GFProjectLayoutDock
extends VBoxContainer


# --- 常量 ---

## 页面尚未开始捕获。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_IDLE: String = "idle"

## 页面正在主线程分批捕获库存。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_CAPTURING: String = "capturing"

## 页面正在后台分析冻结库存。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_ANALYZING: String = "analyzing"

## 分析完整结束。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_COMPLETE: String = "complete"

## 输入或分析不完整。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_PARTIAL: String = "partial"

## 用户取消了请求。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_CANCELLED: String = "cancelled"

## 请求因输入或执行错误失败。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_FAILED: String = "failed"

const _ANALYZER_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_analyzer.gd"
)
const _ANALYSIS_CONTRACT_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_analysis_contract.gd"
)
const _BACKGROUND_TASK_SCRIPT = preload(
	"res://addons/gf/kernel/editor/gf_editor_background_request_task.gd"
)
const _BOUNDED_JSON_OBJECT_READER_SCRIPT = preload(
	"res://addons/gf/kernel/core/gf_bounded_json_object_reader.gd"
)
const _SNAPSHOT_BUILDER_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/editor/gf_project_layout_editor_snapshot_builder.gd"
)
const _WORKER_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/editor/gf_project_layout_scan_worker.gd"
)
const _WORKSPACE_UI = preload(
	"res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd"
)
const _EXAMPLE_PROFILE_PATH: String = \
	"res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json"
const _CAPTURE_ENTRIES_PER_FRAME: int = 256
const _DETAIL_TEXT_LIMIT: int = 131072
const _CLIPBOARD_TEXT_LIMIT: int = 1048576
const _FINDING_LIST_ITEM_LIMIT: int = 256
const _FINDING_RENDER_BATCH_SIZE: int = 64
const _FINDING_LABEL_CHARACTER_LIMIT: int = 256
const _QUERY_KINDS: PackedStringArray = [
	"explain_finding",
	"analyze_change_impact",
]
const _QUERY_RESULT_FIELDS: PackedStringArray = [
	"schema_version",
	"kind",
	"generation",
	"analysis_digest",
	"query_kind",
	"status",
	"explanation",
	"impact",
	"issues",
]
const _EXPLANATION_RESULT_FIELDS: PackedStringArray = [
	"schema_version",
	"kind",
	"complete",
	"finding_id",
	"headline",
	"observation",
	"implication",
	"next_steps",
	"certainty",
	"evidence",
	"issues",
	"effects",
]
const _IMPACT_RESULT_FIELDS: PackedStringArray = [
	"schema_version",
	"kind",
	"complete",
	"status",
	"source_analysis_digest",
	"change",
	"affected_node_ids",
	"blockers",
	"evidence_ids",
	"issues",
	"effects",
]
const _EFFECT_FIELDS: PackedStringArray = ["writes_project"]
const _ISSUE_FIELDS: PackedStringArray = ["severity", "kind", "message"]
const _BLOCKER_FIELDS: PackedStringArray = ["kind", "path", "message"]
const _CHANGE_FIELDS: PackedStringArray = ["kind", "source_path", "target_path"]
const _INVENTORY_EVIDENCE_FIELDS: PackedStringArray = [
	"evidence_id",
	"kind",
	"root_path",
	"relative_path",
	"scope",
	"authority",
	"observed",
]
const _BOUNDARY_EVIDENCE_FIELDS: PackedStringArray = [
	"evidence_id",
	"kind",
	"root_path",
	"scope",
	"capture_scope",
	"capture_status",
	"authority",
	"complete",
	"file_count",
	"directory_count",
	"input_digest",
]
const _SCOPE_FIELDS: PackedStringArray = [
	"kind",
	"root_path",
	"include_hidden",
	"excluded_prefixes",
	"max_scanned_files",
	"max_scanned_directories",
	"max_scan_depth",
]
const _MAX_QUERY_DATA_NODES: int = 500_000
const _MAX_QUERY_DATA_DEPTH: int = 65
const _MAX_QUERY_COLLECTION_ITEMS: int = _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_NODES
const _MAX_QUERY_STRING_LENGTH: int = _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH
const _MAX_QUERY_STRING_BYTES: int = _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_STRING_BYTES


# --- 私有变量 ---

var _state: String = STATE_IDLE
var _generation: int = 0
var _active_generation: int = 0
var _snapshot_builder: GFProjectLayoutEditorSnapshotBuilder = null
var _background_task: GFEditorBackgroundRequestTask = null
var _query_task: GFEditorBackgroundRequestTask = null
var _pending_query_request: Dictionary = {}
var _active_query_generation: int = 0
var _active_query_analysis_digest: String = ""
var _active_query_kind: String = ""
var _active_profile_present: bool = false
var _active_profile_compilation: Dictionary = {}
var _last_analysis: Dictionary = {}
var _last_plan: Dictionary = {}
var _last_impact: Dictionary = {}
var _finding_render_source: Array = []
var _finding_render_cursor: int = 0
var _finding_summary_added: bool = false

var _profile_selector: OptionButton = null
var _scan_button: Button = null
var _cancel_button: Button = null
var _copy_button: Button = null
var _status_label: Label = null
var _overview_output: TextEdit = null
var _finding_list: ItemList = null
var _finding_details: TextEdit = null
var _impact_kind_selector: OptionButton = null
var _impact_source_edit: LineEdit = null
var _impact_target_edit: LineEdit = null
var _impact_output: TextEdit = null
var _plan_output: TextEdit = null


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "GF Project Layout"
	_WORKSPACE_UI.apply_page_root(self)
	_build_ui()
	_set_state(STATE_IDLE, "选择可选 profile 后点击“扫描项目”。页面不会自动扫描。")
	set_process(false)


func _process(_delta: float) -> void:
	_process_query_result()
	if _background_task != null and _background_task.is_cancel_requested():
		_process_cancelled_background_task()
		return
	if _state == STATE_CAPTURING:
		_process_capture()
	elif _state == STATE_ANALYZING:
		_process_background_result()
	elif _has_pending_finding_render():
		_render_finding_batch()


func _exit_tree() -> void:
	_generation += 1
	_pending_query_request = {}
	if _snapshot_builder != null:
		_snapshot_builder.cancel()
	if _background_task != null:
		_background_task.request_cancel()
		var _discarded_result: Variant = _background_task.wait_to_finish()
	_background_task = null
	if _query_task != null:
		_query_task.request_cancel()
		var _discarded_query_result: Variant = _query_task.wait_to_finish()
	_query_task = null
	set_process(false)


# --- 公共方法 ---

## 请求一次新的只读项目扫描。
## [br]
## @api public
## [br]
## @since unreleased
func scan_project() -> void:
	if _background_task != null:
		_cancel_active_request(false)
		_set_state(STATE_CANCELLED, "正在停止上一条后台请求；停止完成后可再次扫描。")
		return
	_cancel_active_request(false)
	_generation += 1
	_active_generation = _generation
	if not _freeze_active_profile_request():
		return
	_snapshot_builder = _SNAPSHOT_BUILDER_SCRIPT.new()
	var begin_error: Error = _snapshot_builder.begin("res://")
	if begin_error != OK:
		_set_state(STATE_FAILED, "无法开始项目库存捕获。")
		_render_capture_failure(_snapshot_builder.make_snapshot())
		return
	_clear_results()
	_set_state(STATE_CAPTURING, "正在分批读取项目库存……")
	set_process(true)


## 取消当前捕获或后台分析。
## [br]
## @api public
## [br]
## @since unreleased
func cancel_scan() -> void:
	_cancel_active_request(true)


## 返回页面当前状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: String，页面当前状态；值属于 STATE_* 常量闭集。
func get_state() -> String:
	return _state


## 返回最近一次 data-only 页面结果；输入不完整时仍保留 partial 结果供解释。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: Dictionary，包含 analysis、plan 和 impact。
## [br]
## @schema return: Dictionary，精确包含 analysis、plan 和 impact；尚无相应结果时值为空 Dictionary。
func get_last_result() -> Dictionary:
	return {
		"analysis": _last_analysis.duplicate(true),
		"plan": _last_plan.duplicate(true),
		"impact": _last_impact.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _build_ui() -> void:
	var toolbar: HBoxContainer = _WORKSPACE_UI.make_toolbar()
	add_child(toolbar)
	var profile_label: Label = Label.new()
	profile_label.text = "Profile"
	toolbar.add_child(profile_label)
	_profile_selector = OptionButton.new()
	_profile_selector.tooltip_text = "Profile 是可选策略，不会强迫项目采用统一目录模板。"
	_profile_selector.add_item("无（只观察）")
	_profile_selector.add_item("Feature Cohesive 示例")
	_profile_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_profile_selector)
	_scan_button = _WORKSPACE_UI.make_button(
		"扫描项目",
		"分批捕获库存并在后台生成只读分析。",
		scan_project
	)
	toolbar.add_child(_scan_button)
	_cancel_button = _WORKSPACE_UI.make_button(
		"取消",
		"取消当前捕获或后台分析。",
		cancel_scan
	)
	toolbar.add_child(_cancel_button)
	_copy_button = _WORKSPACE_UI.make_button(
		"复制报告",
		"把当前 data-only 报告复制到剪贴板，不写入项目。",
		_copy_report
	)
	toolbar.add_child(_copy_button)

	_status_label = _WORKSPACE_UI.make_summary_label()
	add_child(_status_label)

	var tabs: TabContainer = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	_build_overview_tab(tabs)
	_build_findings_tab(tabs)
	_build_impact_tab(tabs)
	_build_plan_tab(tabs)


func _build_overview_tab(tabs: TabContainer) -> void:
	var page: VBoxContainer = VBoxContainer.new()
	page.name = "总览"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(page)
	var note: Label = _WORKSPACE_UI.make_summary_label(
		"Project Layout 只解释当前项目；没有 Apply，也不会自动创建或整理目录。"
	)
	page.add_child(note)
	_overview_output = _WORKSPACE_UI.make_details_output(220.0)
	_overview_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_overview_output)


func _build_findings_tab(tabs: TabContainer) -> void:
	var page: VBoxContainer = VBoxContainer.new()
	page.name = "问题与解释"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(page)
	_finding_list = ItemList.new()
	_finding_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_finding_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var _selection_connection: Variant = _finding_list.item_selected.connect(
		_on_finding_selected
	)
	page.add_child(_finding_list)
	_finding_details = _WORKSPACE_UI.make_details_output(150.0)
	page.add_child(_finding_details)


func _build_impact_tab(tabs: TabContainer) -> void:
	var page: VBoxContainer = VBoxContainer.new()
	page.name = "影响模拟"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(page)
	var note: Label = _WORKSPACE_UI.make_summary_label(
		"这里只模拟 move / rename / delete。依赖证据不足时会显示 UNKNOWN，不会执行变更。"
	)
	page.add_child(note)
	var toolbar: HBoxContainer = _WORKSPACE_UI.make_toolbar()
	page.add_child(toolbar)
	_impact_kind_selector = OptionButton.new()
	_impact_kind_selector.add_item("删除")
	_impact_kind_selector.set_item_metadata(0, "delete")
	_impact_kind_selector.add_item("移动")
	_impact_kind_selector.set_item_metadata(1, "move")
	_impact_kind_selector.add_item("重命名")
	_impact_kind_selector.set_item_metadata(2, "rename")
	toolbar.add_child(_impact_kind_selector)
	_impact_source_edit = LineEdit.new()
	_impact_source_edit.placeholder_text = "源项目相对路径，例如 features/inventory"
	_impact_source_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_impact_source_edit)
	_impact_target_edit = LineEdit.new()
	_impact_target_edit.placeholder_text = "目标项目相对路径（移动/重命名）"
	_impact_target_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_impact_target_edit)
	var simulate_button: Button = _WORKSPACE_UI.make_button(
		"模拟影响",
		"只计算影响和 blocker。",
		_simulate_impact
	)
	toolbar.add_child(simulate_button)
	_impact_output = _WORKSPACE_UI.make_details_output(220.0)
	_impact_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_impact_output)


func _build_plan_tab(tabs: TabContainer) -> void:
	var page: VBoxContainer = VBoxContainer.new()
	page.name = "只读计划"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(page)
	var note: Label = _WORKSPACE_UI.make_summary_label(
		"计划只描述候选相对路径、前置条件和 blocker；不包含命令或 Apply。"
	)
	page.add_child(note)
	_plan_output = _WORKSPACE_UI.make_details_output(250.0)
	_plan_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_plan_output)


func _process_capture() -> void:
	if _snapshot_builder == null:
		_set_state(STATE_FAILED, "库存捕获器不可用。")
		_refresh_process_state()
		return
	var progress: Dictionary = _snapshot_builder.step(_CAPTURE_ENTRIES_PER_FRAME)
	_set_status_text(
		"正在读取库存：%d 个文件，%d 个目录。" % [
			_get_int(progress, "file_count"),
			_get_int(progress, "directory_count"),
		]
	)
	var capture_status: String = _get_string(progress, "status")
	if capture_status == "capturing":
		return
	if capture_status == "cancelled":
		_set_state(STATE_CANCELLED, "项目库存捕获已取消。")
		_refresh_process_state()
		return
	if capture_status == "failed":
		_set_state(STATE_FAILED, "项目库存捕获失败。")
		_render_capture_failure(_snapshot_builder.make_snapshot())
		_refresh_process_state()
		return
	_start_background_analysis(_snapshot_builder.make_snapshot())


func _start_background_analysis(snapshot: Dictionary) -> void:
	_snapshot_builder = null
	var worker: GFProjectLayoutScanWorker = _WORKER_SCRIPT.new()
	var profile_compilation: Dictionary = _active_profile_compilation
	_active_profile_compilation = {}
	_background_task = _BACKGROUND_TASK_SCRIPT.new().configure(
		worker,
		{
			"generation": _active_generation,
			"snapshot": snapshot,
			"profile_compilation_present": _active_profile_present,
			"profile_compilation": profile_compilation,
			"plan_options": {},
		}
	)
	var start_error: Error = _background_task.start()
	if start_error != OK:
		_background_task = null
		_set_state(STATE_FAILED, "后台分析无法启动：%s。" % error_string(start_error))
		_refresh_process_state()
		return
	_set_state(STATE_ANALYZING, "库存已冻结，正在后台分析……")
	set_process(true)


func _freeze_active_profile_request() -> bool:
	_active_profile_compilation = {}
	_active_profile_present = _profile_selector.selected == 1
	if not _active_profile_present:
		return true
	var read_result: Dictionary = _BOUNDED_JSON_OBJECT_READER_SCRIPT.read_object(
		_EXAMPLE_PROFILE_PATH
	)
	if not _get_bool(read_result, "ok"):
		_set_state(STATE_FAILED, "示例 profile 无法读取。")
		_overview_output.text = _format_json(read_result, _DETAIL_TEXT_LIMIT)
		_refresh_process_state()
		return false
	var profile: Dictionary = _get_dictionary(read_result, "data")
	var analyzer: _ANALYZER_SCRIPT = _ANALYZER_SCRIPT.new()
	_active_profile_compilation = analyzer.compile_profile(profile)
	if not _get_bool(_active_profile_compilation, "success"):
		_active_profile_present = false
		_set_state(STATE_FAILED, "示例 profile 无法通过闭合契约编译。")
		_overview_output.text = _format_json(
			_active_profile_compilation,
			_DETAIL_TEXT_LIMIT
		)
		_refresh_process_state()
		return false
	return true


func _process_background_result() -> void:
	if _background_task == null or _background_task.is_running():
		return
	var result_value: Variant = _background_task.wait_to_finish()
	_background_task = null
	if not result_value is Dictionary:
		_clear_results()
		_set_state(STATE_FAILED, "后台分析返回了无效结果。")
		_refresh_process_state()
		return
	var result: Dictionary = result_value
	if _get_int(result, "generation", -1) != _active_generation:
		_clear_results()
		_set_state(STATE_CANCELLED, "已安全丢弃过期后台结果；可以开始新的扫描。")
		_refresh_process_state()
		return
	if _get_string(result, "status") == "cancelled":
		_clear_results()
		_set_state(STATE_CANCELLED, "后台分析已取消。")
		_refresh_process_state()
		return
	if _get_string(result, "status") == "failed":
		_clear_results()
		_set_state(STATE_FAILED, "后台分析失败；请查看结构化诊断。")
		_overview_output.text = _format_json({
			"schema_version": 1,
			"kind": "project_layout_worker_failure",
			"generation": _get_int(result, "generation", -1),
			"issues": _get_array(result, "issues"),
		}, _DETAIL_TEXT_LIMIT)
		_refresh_process_state()
		return
	# worker 已结束且不再持有可变 owner；直接接管结果，避免在主线程再次深复制大型图。
	_last_analysis = _get_dictionary(result, "analysis")
	_last_plan = _get_dictionary(result, "plan")
	var result_status: String = _get_string(result, "status")
	if result_status == "complete":
		_set_state(STATE_COMPLETE, _make_completion_summary())
	elif result_status == "partial":
		_set_state(STATE_PARTIAL, _make_partial_summary())
	else:
		_clear_results()
		_set_state(STATE_FAILED, "后台分析失败。")
		_refresh_process_state()
		return
	_render_results()
	_refresh_process_state()


func _process_cancelled_background_task() -> void:
	if _background_task == null or _background_task.is_running():
		return
	var _discarded_result: Variant = _background_task.wait_to_finish()
	_background_task = null
	_clear_results()
	if _state == STATE_CANCELLED:
		_set_state(STATE_CANCELLED, "当前请求已取消；可以开始新的扫描。")
	_refresh_process_state()


func _render_results() -> void:
	_overview_output.text = _format_json(_make_overview(), _DETAIL_TEXT_LIMIT)
	_plan_output.text = (
		(
			"分析不完整；为避免把 UNKNOWN 当事实，本次没有生成计划。"
			if _active_profile_present
			else "未选择 profile；当前只有观察结果。"
		)
		if _last_plan.is_empty()
		else _format_json(_last_plan, _DETAIL_TEXT_LIMIT)
	)
	_impact_output.text = "输入项目相对路径后，可以模拟影响。"
	_finding_details.text = "选择一条 finding 查看解释和证据。"
	_finding_list.clear()
	_finding_render_source = _get_array(_last_analysis, "findings")
	_finding_render_cursor = 0
	_finding_summary_added = false
	_render_finding_batch()


func _render_finding_batch() -> void:
	var render_limit: int = mini(_finding_render_source.size(), _FINDING_LIST_ITEM_LIMIT)
	var batch_end: int = mini(
		_finding_render_cursor + _FINDING_RENDER_BATCH_SIZE,
		render_limit
	)
	while _finding_render_cursor < batch_end:
		var finding_value: Variant = _finding_render_source[_finding_render_cursor]
		_finding_render_cursor += 1
		if not finding_value is Dictionary:
			continue
		var finding: Dictionary = finding_value
		var label: String = "[%s] %s" % [
			_get_string(finding, "severity", "info").to_upper(),
			_get_string(finding, "message", _get_string(finding, "kind")),
		]
		if label.length() > _FINDING_LABEL_CHARACTER_LIMIT:
			label = label.left(_FINDING_LABEL_CHARACTER_LIMIT - 1) + "…"
		var index: int = _finding_list.add_item(label)
		_finding_list.set_item_metadata(index, _get_string(finding, "finding_id"))
	if (
		_finding_render_cursor >= render_limit
		and _finding_render_source.size() > render_limit
		and not _finding_summary_added
	):
		var omitted_count: int = _finding_render_source.size() - render_limit
		var summary_index: int = _finding_list.add_item(
			"… 另有 %d 条 finding 未在列表中展开" % omitted_count
		)
		_finding_list.set_item_disabled(summary_index, true)
		_finding_summary_added = true
	if not _has_pending_finding_render():
		_refresh_process_state()


func _has_pending_finding_render() -> bool:
	var render_limit: int = mini(_finding_render_source.size(), _FINDING_LIST_ITEM_LIMIT)
	if _finding_render_cursor < render_limit:
		return true
	return _finding_render_source.size() > render_limit and not _finding_summary_added


func _render_capture_failure(snapshot: Dictionary) -> void:
	_overview_output.text = _format_json(snapshot, _DETAIL_TEXT_LIMIT)


func _make_overview() -> Dictionary:
	return {
		"state": _state,
		"profile_id": _get_string(_last_analysis, "profile_id"),
		"evaluation_complete": _get_bool(_last_analysis, "evaluation_complete"),
		"input_complete": _get_bool(_last_analysis, "input_complete"),
		"file_count": _get_int(_last_analysis, "file_count"),
		"directory_count": _get_int(_last_analysis, "directory_count"),
		"error_count": _get_int(_last_analysis, "error_count"),
		"warning_count": _get_int(_last_analysis, "warning_count"),
		"finding_count": _get_array(_last_analysis, "findings").size(),
		"finding_list_display_limit": _FINDING_LIST_ITEM_LIMIT,
		"writes_project": false,
		"input_digest": _get_string(_last_analysis, "input_digest"),
	}


func _make_completion_summary() -> String:
	return "分析完成：%d 个文件，%d 个目录，%d 个错误，%d 个警告。" % [
		_get_int(_last_analysis, "file_count"),
		_get_int(_last_analysis, "directory_count"),
		_get_int(_last_analysis, "error_count"),
		_get_int(_last_analysis, "warning_count"),
	]


func _make_partial_summary() -> String:
	var evaluation_status: String = _get_string(_last_analysis, "evaluation_status")
	match evaluation_status:
		"input_incomplete":
			return "分析部分完成：项目库存输入不完整；未观察到的内容保持 UNKNOWN。"
		"evaluation_cancelled":
			return "分析部分完成：评估过程已取消；未完成的结论保持 UNKNOWN。"
		"evaluation_work_budget_exhausted":
			return "分析部分完成：已达到工作量上限；未完成的结论保持 UNKNOWN。"
		"evaluation_finding_budget_exhausted":
			return "分析部分完成：已达到 finding 数量上限；报告仅保留有界结果。"
		_:
			return "分析部分完成；请查看 evaluation_status 和结构化结果。"


func _request_background_query(query_kind: String, query: Dictionary) -> void:
	if _last_analysis.is_empty():
		return
	var analysis_digest: String = _get_string(_last_analysis, "input_digest")
	if analysis_digest.is_empty():
		_render_query_message(query_kind, "当前分析没有可绑定的 input digest；请重新扫描项目。")
		return
	_generation += 1
	_active_query_generation = _generation
	_active_query_analysis_digest = analysis_digest
	_active_query_kind = query_kind
	_pending_query_request = {
		"generation": _active_query_generation,
		"analysis_digest": analysis_digest,
		"query_kind": query_kind,
		"query": query,
	}
	if query_kind == "analyze_change_impact":
		_last_impact = {}
	_cancel_active_query(false)
	if _query_task == null:
		_start_pending_query()
	set_process(true)


func _start_pending_query() -> void:
	if _query_task != null or _pending_query_request.is_empty():
		return
	var request: Dictionary = _pending_query_request
	_pending_query_request = {}
	var generation: int = _get_int(request, "generation", -1)
	var analysis_digest: String = _get_string(request, "analysis_digest")
	var query_kind: String = _get_string(request, "query_kind")
	if (
		generation != _active_query_generation
		or analysis_digest != _active_query_analysis_digest
		or query_kind != _active_query_kind
		or analysis_digest != _get_string(_last_analysis, "input_digest")
	):
		_refresh_process_state()
		return
	var worker: GFProjectLayoutScanWorker = _WORKER_SCRIPT.new()
	var _configured_worker: GFProjectLayoutScanWorker = worker.configure_query_session(
		_last_analysis,
		generation,
		analysis_digest
	)
	_query_task = _BACKGROUND_TASK_SCRIPT.new().configure(
		worker,
		request,
		{ "worker_method": &"run_query_request" }
	)
	var start_error: Error = _query_task.start()
	if start_error != OK:
		_query_task = null
		_render_query_message(
			query_kind,
			"后台查询无法启动：%s。" % error_string(start_error)
		)
		_refresh_process_state()
		return
	_render_query_message(
		query_kind,
		"正在后台生成 finding 解释……"
		if query_kind == "explain_finding"
		else "正在后台模拟影响……"
	)


func _process_query_result() -> void:
	if _query_task == null:
		_start_pending_query()
		return
	if _query_task.is_running():
		return
	var result_value: Variant = _query_task.wait_to_finish()
	_query_task = null
	if not result_value is Dictionary:
		_render_query_message(_active_query_kind, "后台查询返回了无效结果。")
		_start_pending_query()
		_refresh_process_state()
		return
	var result: Dictionary = result_value
	if not _query_result_is_well_formed(result):
		_render_query_message(_active_query_kind, "后台查询返回了未闭合结果。")
		_start_pending_query()
		_refresh_process_state()
		return
	var query_kind: String = _get_string(result, "query_kind")
	var result_generation: int = _get_int(result, "generation", -1)
	var result_digest: String = _get_string(result, "analysis_digest")
	var stale_result: bool = (
		result_generation != _active_query_generation
		or result_digest != _active_query_analysis_digest
		or query_kind != _active_query_kind
		or result_digest != _get_string(_last_analysis, "input_digest")
	)
	if not stale_result:
		var result_status: String = _get_string(result, "status")
		if result_status == "complete":
			_adopt_query_result(result, query_kind)
		elif result_status == "failed":
			_render_query_message(
				query_kind,
				_format_json({
					"schema_version": 1,
					"kind": "project_layout_query_failure",
					"generation": result_generation,
					"analysis_digest": result_digest,
					"issues": _get_array(result, "issues"),
				}, _DETAIL_TEXT_LIMIT)
			)
	_start_pending_query()
	_refresh_process_state()


func _adopt_query_result(result: Dictionary, query_kind: String) -> void:
	if query_kind == "explain_finding":
		var explanation: Dictionary = _get_dictionary(result, "explanation")
		if explanation.is_empty():
			_render_query_message(query_kind, "后台解释结果为空。")
			return
		_finding_details.text = _format_json(explanation, _DETAIL_TEXT_LIMIT)
	else:
		var impact: Dictionary = _get_dictionary(result, "impact")
		if impact.is_empty():
			_render_query_message(query_kind, "后台影响结果为空。")
			return
		_last_impact = impact
		_impact_output.text = _format_json(_last_impact, _DETAIL_TEXT_LIMIT)
	_set_status_text(
		_make_completion_summary()
		if _state == STATE_COMPLETE
		else _make_partial_summary()
	)


func _render_query_message(query_kind: String, message: String) -> void:
	if query_kind == "analyze_change_impact":
		_impact_output.text = message
	else:
		_finding_details.text = message


func _query_result_is_well_formed(result: Dictionary) -> bool:
	var data_state: Dictionary = { "nodes": 0, "string_bytes": 0 }
	if (
		not _query_value_is_strict_data_only(result, 0, [], data_state)
		or not _has_exact_fields(result, _QUERY_RESULT_FIELDS)
	):
		return false
	if (
		result.get("schema_version") != 1
		or result.get("kind") != "project_layout_query_result"
		or not result.get("generation") is int
		or not result.get("analysis_digest") is String
		or not result.get("query_kind") is String
		or not result.get("status") is String
		or not result.get("explanation") is Dictionary
		or not result.get("impact") is Dictionary
		or not result.get("issues") is Array
	):
		return false
	var analysis_digest: String = _get_string(result, "analysis_digest")
	var query_kind: String = _get_string(result, "query_kind")
	var result_status: String = _get_string(result, "status")
	if (
		not _is_lower_sha256(analysis_digest)
		or not _QUERY_KINDS.has(query_kind)
		or not ["complete", "cancelled", "failed"].has(result_status)
		or not _issue_array_is_closed(_get_array(result, "issues"))
	):
		return false
	var explanation: Dictionary = _get_dictionary(result, "explanation")
	var impact: Dictionary = _get_dictionary(result, "impact")
	if result_status == "complete":
		return (
			(_explanation_is_closed(explanation) and impact.is_empty())
			if query_kind == "explain_finding"
			else (
				explanation.is_empty()
				and _impact_is_closed(impact, analysis_digest)
			)
		)
	if not explanation.is_empty() or not impact.is_empty():
		return false
	var top_level_issues: Array = _get_array(result, "issues")
	return (
		(top_level_issues.is_empty() if result_status == "cancelled" else not top_level_issues.is_empty())
		and explanation.is_empty()
		and impact.is_empty()
	)


func _explanation_is_closed(explanation: Dictionary) -> bool:
	return (
		_has_exact_fields(explanation, _EXPLANATION_RESULT_FIELDS)
		and explanation.get("schema_version") == 1
		and explanation.get("kind") == "project_layout_explanation"
		and explanation.get("complete") is bool
		and explanation.get("finding_id") is String
		and explanation.get("headline") is String
		and explanation.get("observation") is String
		and explanation.get("implication") is String
		and explanation.get("next_steps") is Array
		and _string_array_is_closed(_get_array(explanation, "next_steps"))
		and explanation.get("certainty") is String
		and explanation.get("evidence") is Array
		and _evidence_array_is_closed(_get_array(explanation, "evidence"))
		and explanation.get("issues") is Array
		and _issue_array_is_closed(_get_array(explanation, "issues"))
		and _effects_are_read_only(_get_dictionary(explanation, "effects"))
	)


func _impact_is_closed(impact: Dictionary, analysis_digest: String) -> bool:
	return (
		_has_exact_fields(impact, _IMPACT_RESULT_FIELDS)
		and impact.get("schema_version") == 1
		and impact.get("kind") == "project_layout_impact"
		and impact.get("complete") is bool
		and impact.get("status") is String
		and ["safe", "unsafe", "unknown"].has(_get_string(impact, "status"))
		and impact.get("source_analysis_digest") == analysis_digest
		and impact.get("change") is Dictionary
		and _change_is_closed(_get_dictionary(impact, "change"))
		and impact.get("affected_node_ids") is Array
		and _string_array_is_closed(_get_array(impact, "affected_node_ids"))
		and impact.get("blockers") is Array
		and _blocker_array_is_closed(_get_array(impact, "blockers"))
		and impact.get("evidence_ids") is Array
		and _string_array_is_closed(_get_array(impact, "evidence_ids"))
		and impact.get("issues") is Array
		and _issue_array_is_closed(_get_array(impact, "issues"))
		and _effects_are_read_only(_get_dictionary(impact, "effects"))
	)


func _change_is_closed(change: Dictionary) -> bool:
	return (
		_has_exact_fields(change, _CHANGE_FIELDS)
		and change.get("kind") is String
		and change.get("source_path") is String
		and change.get("target_path") is String
	)


func _effects_are_read_only(effects: Dictionary) -> bool:
	return (
		_has_exact_fields(effects, _EFFECT_FIELDS)
		and effects.get("writes_project") is bool
		and not _get_bool(effects, "writes_project", true)
	)


func _string_array_is_closed(values: Array) -> bool:
	for value: Variant in values:
		if not value is String:
			return false
	return true


func _issue_array_is_closed(values: Array) -> bool:
	for value: Variant in values:
		if not value is Dictionary:
			return false
		var issue: Dictionary = value
		if (
			not _has_exact_fields(issue, _ISSUE_FIELDS)
			or not issue.get("severity") is String
			or not issue.get("kind") is String
			or not issue.get("message") is String
		):
			return false
	return true


func _blocker_array_is_closed(values: Array) -> bool:
	for value: Variant in values:
		if not value is Dictionary:
			return false
		var blocker: Dictionary = value
		if (
			not _has_exact_fields(blocker, _BLOCKER_FIELDS)
			or not blocker.get("kind") is String
			or not blocker.get("path") is String
			or not blocker.get("message") is String
		):
			return false
	return true


func _evidence_array_is_closed(values: Array) -> bool:
	for value: Variant in values:
		if not value is Dictionary:
			return false
		var evidence: Dictionary = value
		var evidence_kind: String = _get_string(evidence, "kind")
		if evidence_kind == "filesystem_inventory":
			if not _inventory_evidence_is_closed(evidence):
				return false
		elif evidence_kind == "filesystem_inventory_boundary":
			if not _boundary_evidence_is_closed(evidence):
				return false
		else:
			return false
	return true


func _inventory_evidence_is_closed(evidence: Dictionary) -> bool:
	return (
		_has_exact_fields(evidence, _INVENTORY_EVIDENCE_FIELDS)
		and evidence.get("evidence_id") is String
		and evidence.get("kind") == "filesystem_inventory"
		and evidence.get("root_path") is String
		and evidence.get("relative_path") is String
		and evidence.get("scope") is String
		and evidence.get("authority") is String
		and evidence.get("observed") is bool
	)


func _boundary_evidence_is_closed(evidence: Dictionary) -> bool:
	return (
		_has_exact_fields(evidence, _BOUNDARY_EVIDENCE_FIELDS)
		and evidence.get("evidence_id") is String
		and evidence.get("kind") == "filesystem_inventory_boundary"
		and evidence.get("root_path") is String
		and evidence.get("scope") is String
		and evidence.get("capture_scope") is Dictionary
		and _scope_is_closed(_get_dictionary(evidence, "capture_scope"))
		and evidence.get("capture_status") is String
		and evidence.get("authority") is String
		and evidence.get("complete") is bool
		and evidence.get("file_count") is int
		and evidence.get("directory_count") is int
		and evidence.get("input_digest") is String
	)


func _scope_is_closed(scope: Dictionary) -> bool:
	return (
		_has_exact_fields(scope, _SCOPE_FIELDS)
		and scope.get("kind") is String
		and scope.get("root_path") is String
		and scope.get("include_hidden") is bool
		and scope.get("excluded_prefixes") is Array
		and _string_array_is_closed(_get_array(scope, "excluded_prefixes"))
		and scope.get("max_scanned_files") is int
		and scope.get("max_scanned_directories") is int
		and scope.get("max_scan_depth") is int
	)


func _query_value_is_strict_data_only(
	value: Variant,
	depth: int,
	active_containers: Array,
	state: Dictionary
) -> bool:
	var node_count: int = _get_int(state, "nodes") + 1
	state["nodes"] = node_count
	if node_count > _MAX_QUERY_DATA_NODES or depth > _MAX_QUERY_DATA_DEPTH:
		return false
	if value == null or value is bool or value is int:
		return true
	if value is float:
		var float_value: float = value
		return is_finite(float_value)
	if value is String:
		var text: String = value
		if text.length() > _MAX_QUERY_STRING_LENGTH:
			return false
		var text_bytes: int = text.to_utf8_buffer().size()
		var string_bytes: int = _get_int(state, "string_bytes")
		if string_bytes > _MAX_QUERY_STRING_BYTES - text_bytes:
			return false
		state["string_bytes"] = string_bytes + text_bytes
		return true
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		if packed_value.size() > _MAX_QUERY_COLLECTION_ITEMS:
			return false
		for item: String in packed_value:
			if not _query_value_is_strict_data_only(
				item,
				depth + 1,
				active_containers,
				state
			):
				return false
		return true
	if value is Array:
		var array_value: Array = value
		if (
			array_value.size() > _MAX_QUERY_COLLECTION_ITEMS
			or _active_container_exists(active_containers, array_value)
		):
			return false
		active_containers.append(array_value)
		for item: Variant in array_value:
			if not _query_value_is_strict_data_only(
				item,
				depth + 1,
				active_containers,
				state
			):
				var _discarded_array_on_failure: Variant = active_containers.pop_back()
				return false
		var _discarded_array_on_success: Variant = active_containers.pop_back()
		return true
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		if (
			dictionary_value.size() > _MAX_QUERY_COLLECTION_ITEMS
			or _active_container_exists(active_containers, dictionary_value)
		):
			return false
		active_containers.append(dictionary_value)
		for key_value: Variant in dictionary_value.keys():
			if not key_value is String:
				var _discarded_invalid_dictionary: Variant = active_containers.pop_back()
				return false
			if not _query_value_is_strict_data_only(
				key_value,
				depth + 1,
				active_containers,
				state
			):
				var _discarded_dictionary_key: Variant = active_containers.pop_back()
				return false
			if not _query_value_is_strict_data_only(
				dictionary_value[key_value],
				depth + 1,
				active_containers,
				state
			):
				var _discarded_dictionary_value: Variant = active_containers.pop_back()
				return false
		var _discarded_dictionary_on_success: Variant = active_containers.pop_back()
		return true
	return false


func _active_container_exists(active_containers: Array, candidate: Variant) -> bool:
	for active_container: Variant in active_containers:
		if is_same(active_container, candidate):
			return true
	return false


func _is_lower_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character_index: int in value.length():
		var codepoint: int = value.unicode_at(character_index)
		if (
			(codepoint < 48 or codepoint > 57)
			and (codepoint < 97 or codepoint > 102)
		):
			return false
	return true


func _on_finding_selected(index: int) -> void:
	var metadata: Variant = _finding_list.get_item_metadata(index)
	if not metadata is String:
		return
	var finding_id: String = metadata
	_request_background_query(
		"explain_finding",
		{ "finding_id": finding_id }
	)


func _simulate_impact() -> void:
	if _last_analysis.is_empty():
		_impact_output.text = "请先扫描项目。"
		return
	var selected_metadata: Variant = _impact_kind_selector.get_selected_metadata()
	var change_kind: String = selected_metadata if selected_metadata is String else "delete"
	_request_background_query(
		"analyze_change_impact",
		{
			"kind": change_kind,
			"source_path": _impact_source_edit.text,
			"target_path": _impact_target_edit.text,
		}
	)


func _copy_report() -> void:
	# JSON.stringify() 只读消费当前结果；这里不调用公开 getter 的深复制，避免在用户
	# 主动复制大型报告时先在主线程制造第二份完整分析图。
	var report_text: String = JSON.stringify({
		"analysis": _last_analysis,
		"plan": _last_plan,
		"impact": _last_impact,
	}, "  ", false)
	var report_size_bytes: int = report_text.to_utf8_buffer().size()
	var copied_summary: bool = report_size_bytes > _CLIPBOARD_TEXT_LIMIT
	if copied_summary:
		report_text = JSON.stringify({
			"schema_version": 1,
			"kind": "project_layout_report_summary",
			"truncated": true,
			"reason": "clipboard_size_limit",
			"full_report_size_bytes": report_size_bytes,
			"analysis_input_digest": _get_string(_last_analysis, "input_digest"),
			"overview": _make_overview(),
		}, "  ", false)
	DisplayServer.clipboard_set(report_text)
	_set_status_text(
		"报告超过 1 MiB，已复制合法 JSON 摘要；完整结果仍只保留在当前页面内。"
		if copied_summary
		else "报告已复制到剪贴板；没有写入项目文件。"
	)


func _cancel_active_request(update_state: bool) -> void:
	_generation += 1
	_active_generation = _generation
	_cancel_active_query(true)
	if _snapshot_builder != null:
		_snapshot_builder.cancel()
	if _background_task != null:
		_background_task.request_cancel()
		set_process(true)
	if update_state and _state != STATE_IDLE:
		_clear_results()
		_set_state(
			STATE_CANCELLED,
			"已请求取消后台分析，正在安全停止……"
			if _background_task != null
			else "当前请求已取消。"
		)
	if _background_task == null:
		_refresh_process_state()


func _cancel_active_query(clear_pending: bool) -> void:
	if clear_pending:
		_pending_query_request = {}
		_active_query_generation = 0
		_active_query_analysis_digest = ""
		_active_query_kind = ""
	if _query_task != null:
		_query_task.request_cancel()
		set_process(true)


func _refresh_process_state() -> void:
	set_process(
		_state == STATE_CAPTURING
		or _state == STATE_ANALYZING
		or _background_task != null
		or _query_task != null
		or not _pending_query_request.is_empty()
		or _has_pending_finding_render()
	)


func _clear_results() -> void:
	_last_analysis = {}
	_last_plan = {}
	_last_impact = {}
	_finding_render_source = []
	_finding_render_cursor = 0
	_finding_summary_added = false
	_finding_list.clear()
	_overview_output.text = ""
	_finding_details.text = ""
	_impact_output.text = ""
	_plan_output.text = ""


func _set_state(state: String, message: String) -> void:
	_state = state
	var background_cleanup_pending: bool = _background_task != null
	var request_active: bool = state == STATE_CAPTURING or state == STATE_ANALYZING
	_scan_button.disabled = request_active or background_cleanup_pending
	_profile_selector.disabled = request_active or background_cleanup_pending
	_cancel_button.disabled = not request_active or (
		background_cleanup_pending and _background_task.is_cancel_requested()
	)
	_copy_button.disabled = _last_analysis.is_empty()
	_set_status_text(message)


func _set_status_text(message: String) -> void:
	var color: Color = _WORKSPACE_UI.INFO_TEXT_COLOR
	if _state == STATE_COMPLETE:
		color = _WORKSPACE_UI.OK_TEXT_COLOR
	elif _state == STATE_PARTIAL:
		color = _WORKSPACE_UI.WARNING_TEXT_COLOR
	elif _state == STATE_FAILED:
		color = _WORKSPACE_UI.ERROR_TEXT_COLOR
	_WORKSPACE_UI.set_status(_status_label, message, color)


func _format_json(value: Variant, max_characters: int) -> String:
	var text: String = JSON.stringify(value, "  ", false)
	if text.length() <= max_characters:
		return text
	return "%s\n…（报告显示已截断，共 %d 字符）" % [
		text.substr(0, max_characters),
		text.length(),
	]


func _get_string(source: Dictionary, key: String, default_value: String = "") -> String:
	var value: Variant = source.get(key, default_value)
	return value if value is String else default_value


func _get_bool(source: Dictionary, key: String, default_value: bool = false) -> bool:
	var value: Variant = source.get(key, default_value)
	return value if value is bool else default_value


func _get_int(source: Dictionary, key: String, default_value: int = 0) -> int:
	var value: Variant = source.get(key, default_value)
	return value if value is int else default_value


func _get_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	return value if value is Array else []


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return value if value is Dictionary else {}


func _has_exact_fields(source: Dictionary, fields: PackedStringArray) -> bool:
	if source.size() != fields.size():
		return false
	for key_value: Variant in source.keys():
		if not key_value is String:
			return false
		var key: String = key_value
		if not fields.has(key):
			return false
	return true
