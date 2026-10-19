@tool

## GFCodeQualityDock: 按项目显式策略执行的只读 GDScript 检查页面。
##
## 当前脚本检查使用编辑器缓冲；项目检查读取磁盘文件。页面只在点击后启动检查，
## 不生成配置或改写源码，取消、隐藏与退树均撤销后台结果的发布资格。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since unreleased
class_name GFCodeQualityDock
extends VBoxContainer


# --- 常量 ---

## 与命令行共享的配置读取及检查入口。
## [br]
## @api private
const _ANALYZER_SCRIPT = preload("res://addons/gf/tools/code_quality/gf_code_quality_analyzer.gd")

## 持有单次线程请求并统一归属线程收尾。
## [br]
## @api private
const _TASK_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_background_request_task.gd")

## 不访问编辑器对象的只读检查 worker。
## [br]
## @api private
const _WORKER_SCRIPT = preload("res://addons/gf/tools/code_quality/editor/gf_code_quality_scan_worker.gd")

## 工作区原生控件构建辅助。
## [br]
## @api private
const _UI_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")

## 从报告边界读取类型明确的字段。
## [br]
## @api private
const _ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

## 单页最多创建的诊断行，避免一次构造全部控件。
## [br]
## @api private
const _PAGE_SIZE: int = 100

## 示例仅展示给项目作者，不会由页面保存到磁盘。
## [br]
## @api private
const _CONFIG_EXAMPLE: String = """在项目中主动创建 .gf/code_quality.json，并按实际源码目录修改 include：

{
  "schema_version": 1,
  "preset": "gf-game@1",
  "include": ["res://scripts"],
  "exclude": ["res://scripts/generated"]
}

gf-game@1 是可选预设。配置和文件读取失败会标记为不完整，未配置不会显示为检查通过。
页面不会创建配置、补写注释或修改排版。"""


# --- 私有变量 ---

## 当前请求独占的后台句柄；收尾后立即释放。
## [br]
## @api private
var _task: GFEditorBackgroundRequestTask = null

## 单次报告的本地快照，不代表文件后续修改后的状态。
## [br]
## @api private
var _report: Dictionary = {}

## 当前请求检查编辑器缓冲还是已保存项目文件。
## [br]
## @api private
var _source_kind: String = ""

## 请求捕获时的项目根目录，发布前仍从同一路径复核配置。
## [br]
## @api private
var _request_root: String = ""

## 只保留本次请求实际使用的规范值；复核不会采用扫描期间的新配置。
## [br]
## @api private
var _request_config: Dictionary = {}

## 只在缓冲请求期间保留其文本，用于发布前检测编辑变化。
## [br]
## @api private
var _buffer_source: String = ""

## 缓冲控件使用弱引用，关闭脚本不会因检查任务而延长其生命周期。
## [br]
## @api private
var _buffer_editor_ref: WeakRef = null

## 当前页在诊断清单中的起始偏移。
## [br]
## @api private
var _offset: int = 0

## 当前脚本的显式检查入口。
## [br]
## @api private
var _buffer_button: Button

## 已保存项目的显式检查入口。
## [br]
## @api private
var _project_button: Button

## 取消期间保持禁用，直到后台请求已实际收尾。
## [br]
## @api private
var _cancel_button: Button

## 显示未配置、执行中、完整或不完整等实际状态。
## [br]
## @api private
var _summary: Label

## 每页诊断列表；行元数据持有该诊断的副本。
## [br]
## @api private
var _results: Tree

## 显示当前诊断的建议或只读配置示例。
## [br]
## @api private
var _details: TextEdit

## 当前结果页范围说明。
## [br]
## @api private
var _page_summary: Label

## 上一页入口。
## [br]
## @api private
var _previous_button: Button

## 下一页入口。
## [br]
## @api private
var _next_button: Button


# --- Godot 生命周期方法 ---

## 构造页面但不扫描项目；首次打开只说明配置和检查入口。
## [br]
## @api private
func _init() -> void:
	name = "GFCodeQualityDock"
	_UI_SCRIPT.apply_page_root(self)
	_build_ui()
	var _visibility_connection: int = visibility_changed.connect(_on_visibility_changed)
	set_process(false)


## 首次显示仅读取项目是否已配置，不启动源码扫描。
## [br]
## @api private
func _ready() -> void:
	set_process(false)
	var config: Dictionary = _load_config()
	if not config.is_empty():
		_summary.text = "已读取项目配置。请选择当前编辑缓冲或已保存项目开始检查。"


## 只有后台任务结束后才回收线程，并在配置及来源仍有效时发布未取消的结果。
## [br]
## @api private
func _process(_delta: float) -> void:
	if _task == null or _task.is_running():
		return
	var was_cancelled: bool = _task.is_cancel_requested()
	var result_value: Variant = _task.wait_to_finish()
	_task = null
	set_process(false)
	_set_busy(false)
	if was_cancelled or not is_visible_in_tree():
		_summary.text = "检查已取消；本次结果未发布。"
	elif not _config_is_unchanged():
		_summary.text = "项目规范配置已变化或不可用；本次结果未发布，请重新检查。"
	elif _source_kind == "buffer" and not _buffer_is_unchanged():
		_summary.text = "脚本缓冲已修改或关闭，请重新检查。"
	elif result_value is Dictionary:
		var result: Dictionary = result_value
		_report = result.duplicate(true)
		_render_report()
	else:
		_summary.text = "检查未能取得有效报告，请重新检查。"
	_buffer_source = ""
	_buffer_editor_ref = null
	_request_root = ""
	_request_config.clear()


## 页面销毁时先撤销发布资格，再归属已启动线程，避免 worker 悬挂。
## [br]
## @api private
func _exit_tree() -> void:
	if _task != null:
		_task.request_cancel()
		var _discarded_result: Variant = _task.wait_to_finish()
		_task = null
	_buffer_source = ""
	_buffer_editor_ref = null
	_request_root = ""
	_request_config.clear()
	set_process(false)


# --- 私有/辅助方法 ---

## 统一构建显式检查、只读列表、分页与诊断说明，避免保存或自动采用入口。
## [br]
## @api private
func _build_ui() -> void:
	add_child(_UI_SCRIPT.make_summary_label("按 .gf/code_quality.json 中显式选择的策略检查；当前脚本使用编辑缓冲，项目检查使用已保存文件。"))
	var toolbar: HBoxContainer = _UI_SCRIPT.make_toolbar()
	add_child(toolbar)
	_buffer_button = _UI_SCRIPT.make_button(
		"检查当前脚本",
		"读取当前 GDScript 编辑缓冲，包括尚未保存的文本",
		_on_check_buffer
	)
	_buffer_button.name = "CheckBuffer"
	toolbar.add_child(_buffer_button)
	_project_button = _UI_SCRIPT.make_button(
		"检查已保存项目",
		"只扫描配置声明的 include 范围，不包含未保存编辑",
		_on_check_project
	)
	_project_button.name = "CheckProject"
	toolbar.add_child(_project_button)
	_cancel_button = _UI_SCRIPT.make_button(
		"取消",
		"停止后续扫描并丢弃本次结果",
		_on_cancel
	)
	_cancel_button.name = "Cancel"
	_cancel_button.disabled = true
	toolbar.add_child(_cancel_button)
	var example_button: Button = _UI_SCRIPT.make_button(
		"配置示例",
		"只显示示例，不创建或保存项目配置",
		_on_show_example
	)
	toolbar.add_child(example_button)
	_summary = _UI_SCRIPT.make_summary_label("尚未检查。没有配置时会显示“未配置”，不会自动采用预设。")
	_summary.name = "Summary"
	add_child(_summary)
	_results = Tree.new()
	_results.name = "Results"
	_results.columns = 4
	_results.hide_root = true
	_results.select_mode = Tree.SELECT_ROW
	_results.column_titles_visible = true
	_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results.custom_minimum_size.y = 150.0
	_results.set_column_title(0, "级别")
	_results.set_column_title(1, "位置")
	_results.set_column_title(2, "规则")
	_results.set_column_title(3, "说明")
	var _selection_connection: int = _results.item_selected.connect(_on_item_selected)
	var _activation_connection: int = _results.item_activated.connect(_on_open_location)
	add_child(_results)
	var paging: HBoxContainer = _UI_SCRIPT.make_toolbar()
	add_child(paging)
	_previous_button = _UI_SCRIPT.make_button(
		"上一页",
		"",
		_on_previous
	)
	_previous_button.name = "PreviousPage"
	paging.add_child(_previous_button)
	_page_summary = _UI_SCRIPT.make_summary_label("暂无结果。")
	_page_summary.name = "PageSummary"
	_page_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paging.add_child(_page_summary)
	_next_button = _UI_SCRIPT.make_button(
		"下一页",
		"",
		_on_next
	)
	_next_button.name = "NextPage"
	paging.add_child(_next_button)
	paging.add_child(
		_UI_SCRIPT.make_button(
			"定位源码",
			"双击诊断也可打开对应文件和行",
			_on_open_location
		)
	)
	_details = _UI_SCRIPT.make_details_output(110.0)
	_details.name = "Details"
	add_child(_details)
	_render_page()


## 从唯一配置加载入口取得同一配置；未配置或读取失败时不启动线程。
## [br]
## @api private
func _load_config() -> Dictionary:
	_report.clear()
	_offset = 0
	_render_page()
	var loaded: Dictionary = _ANALYZER_SCRIPT.load_project_config(ProjectSettings.globalize_path("res://"))
	if not _ACCESS_SCRIPT.get_option_bool(
		loaded,
		"ok",
		false
	):
		var status: String = _ACCESS_SCRIPT.get_option_string(
			loaded,
			"status",
			"incomplete"
		)
		if status == "unconfigured":
			_summary.text = "未配置：请主动创建 .gf/code_quality.json 或查看配置示例。"
		else:
			var message: String = _ACCESS_SCRIPT.get_option_string(
				loaded,
				"error",
				"无法读取有效配置。"
			)
			_summary.text = "配置不可用：%s" % message
		return {}
	return _ACCESS_SCRIPT.get_option_dictionary(
		loaded,
		"config",
		{}
	)


## 在主线程冻结请求后启动 worker；忙碌期间不接受第二个请求。
## [br]
## @api private
func _start_request(request: Dictionary) -> void:
	if _task != null:
		return
	_report.clear()
	_offset = 0
	_details.text = ""
	_source_kind = _ACCESS_SCRIPT.get_option_string(
		request,
		"mode",
		""
	)
	_request_root = _ACCESS_SCRIPT.get_option_string(
		request,
		"root",
		""
	)
	_request_config = _ACCESS_SCRIPT.get_option_dictionary(
		request,
		"config",
		{}
	).duplicate(true)
	_render_page()
	var worker: GFCodeQualityScanWorker = _WORKER_SCRIPT.new()
	_task = _TASK_SCRIPT.new()
	var _configured_task: GFEditorBackgroundRequestTask = _task.configure(worker, request)
	var start_error: Error = _task.start()
	if start_error != OK:
		_task = null
		_buffer_source = ""
		_buffer_editor_ref = null
		_request_root = ""
		_request_config.clear()
		_summary.text = "无法启动检查：%s。" % error_string(start_error)
		return
	_set_busy(true)
	_summary.text = "正在检查编辑缓冲…" if _source_kind == "buffer" else "正在检查已保存项目…未保存编辑不在本次结果中。"
	set_process(true)


## 配置重读仅验证本次请求的规则与范围仍有效，不更新冻结输入或自动重试。
## [br]
## @api private
func _config_is_unchanged() -> bool:
	var current: Dictionary = _ANALYZER_SCRIPT.load_project_config(_request_root)
	return (
		_ACCESS_SCRIPT.get_option_bool(
			current,
			"ok",
			false
		)
		and _ACCESS_SCRIPT.get_option_dictionary(
			current,
			"config",
			{}
		) == _request_config
	)


## 发布前复核同一文本控件仍存在且内容等于捕获值。
## [br]
## @api private
func _buffer_is_unchanged() -> bool:
	if _buffer_editor_ref == null:
		return false
	var editor_value: Variant = _buffer_editor_ref.get_ref()
	if not editor_value is TextEdit:
		return false
	var text_editor: TextEdit = editor_value
	return text_editor.text == _buffer_source


## 在执行期间禁止重复请求；取消按钮保持可见但不会重入取消。
## [br]
## @api private
func _set_busy(busy: bool) -> void:
	_buffer_button.disabled = busy
	_project_button.disabled = busy
	_cancel_button.disabled = not busy


## 完整、违规与不完整分开呈现；零条诊断不替代完整性状态。
## [br]
## @api private
func _render_report() -> void:
	var status: String = _ACCESS_SCRIPT.get_option_string(
		_report,
		"status",
		"incomplete"
	)
	var scope: String = "编辑缓冲" if _source_kind == "buffer" else "已保存文件"
	var prefix: String = "检查不完整"
	match status:
		"clean":
			prefix = "检查完整，未发现已启用规则的问题"
		"violations":
			prefix = "检查完整，发现规则问题"
		"unconfigured":
			prefix = "未配置，未执行规则检查"
	_summary.text = (
		"%s；来源：%s；已检查 %d 个文件，失败 %d 个。结果为本次读取快照。"
		% [
			prefix,
			scope,
			_ACCESS_SCRIPT.get_option_int(
				_report,
				"files_checked",
				0
			),
			_ACCESS_SCRIPT.get_option_int(
				_report,
				"files_failed",
				0
			),
		]
	)
	_render_page()


## 分页渲染报告诊断，行元数据只含本页诊断，不重新读取源码。
## [br]
## @api private
func _render_page() -> void:
	_results.clear()
	var diagnostics: Array = _ACCESS_SCRIPT.get_option_array(
		_report,
		"diagnostics",
		[]
	)
	var tree_root: TreeItem = _results.create_item()
	var page_end: int = mini(
		_offset + _PAGE_SIZE,
		diagnostics.size()
	)
	for index: int in range(_offset, page_end):
		var diagnostic_value: Variant = diagnostics[index]
		if not diagnostic_value is Dictionary:
			continue
		var diagnostic: Dictionary = diagnostic_value
		var item: TreeItem = _results.create_item(tree_root)
		var path: String = _ACCESS_SCRIPT.get_option_string(
			diagnostic,
			"path",
			""
		)
		item.set_text(
			0,
			_ACCESS_SCRIPT.get_option_string(
				diagnostic,
				"severity",
				""
			)
		)
		item.set_text(
			1,
			"%s:%d"
			% [
				path,
				_ACCESS_SCRIPT.get_option_int(
					diagnostic,
					"line",
					1
				),
			]
		)
		item.set_text(
			2,
			_ACCESS_SCRIPT.get_option_string(
				diagnostic,
				"rule",
				""
			)
		)
		item.set_text(
			3,
			_ACCESS_SCRIPT.get_option_string(
				diagnostic,
				"message",
				""
			)
		)
		item.set_metadata(
			0,
			diagnostic.duplicate(true)
		)
	_page_summary.text = (
		"%d–%d / %d 条诊断"
		% [
			_offset + 1 if page_end > _offset else 0,
			page_end,
			diagnostics.size(),
		]
	)
	_previous_button.disabled = _offset == 0
	_next_button.disabled = page_end >= diagnostics.size()


# --- 信号处理函数 ---

## 仅在点击时读取当前脚本和 TextEdit 缓冲；不回退到可能过期的 Script.source_code。
## [br]
## @api private
func _on_check_buffer() -> void:
	if _task != null:
		return
	var config: Dictionary = _load_config()
	if config.is_empty():
		return
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	var script: Script = script_editor.get_current_script()
	var editor: ScriptEditorBase = script_editor.get_current_editor()
	if (
		script == null
		or editor == null
		or not script.resource_path.ends_with(".gd")
	):
		_summary.text = "请先在脚本编辑器中打开一个项目 GDScript 文件。"
		return
	var base_editor: Control = editor.get_base_editor()
	if not base_editor is TextEdit:
		_summary.text = "当前编辑器未提供可读文本缓冲，请改用已保存项目检查。"
		return
	var text_editor: TextEdit = base_editor
	_buffer_source = text_editor.text
	_buffer_editor_ref = weakref(text_editor)
	_start_request(
		{
			"mode": "buffer",
			"root": ProjectSettings.globalize_path("res://"),
			"config": config,
			"path": script.resource_path,
			"source": _buffer_source,
		}
	)


## 冻结项目已采用的配置后开始后台磁盘扫描；不强制保存编辑缓冲。
## [br]
## @api private
func _on_check_project() -> void:
	if _task != null:
		return
	var config: Dictionary = _load_config()
	if config.is_empty():
		return
	_start_request(
		{
			"mode": "disk",
			"root": ProjectSettings.globalize_path("res://"),
			"config": config,
		}
	)


## 发出取消后保留线程句柄，直到逐帧收尾实际确认任务结束。
## [br]
## @api private
func _on_cancel() -> void:
	if _task == null:
		return
	_task.request_cancel()
	_cancel_button.disabled = true
	_summary.text = "正在取消检查…"


## 隐藏页面或工作区时立即撤销在途结果，不在后台自动刷新。
## [br]
## @api private
func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_on_cancel()


## 示例作为普通文本展示，用户自行选择是否采用并保存配置。
## [br]
## @api private
func _on_show_example() -> void:
	_details.text = _CONFIG_EXAMPLE


## 选择诊断后显示稳定规则、完整位置、原因和建议。
## [br]
## @api private
func _on_item_selected() -> void:
	var selected: TreeItem = _results.get_selected()
	if selected == null:
		return
	var metadata_value: Variant = selected.get_metadata(0)
	if not metadata_value is Dictionary:
		return
	var diagnostic: Dictionary = metadata_value
	_details.text = (
		"%s:%d:%d\n%s\n%s\n\n建议：%s"
		% [
			_ACCESS_SCRIPT.get_option_string(
				diagnostic,
				"path",
				""
			),
			_ACCESS_SCRIPT.get_option_int(
				diagnostic,
				"line",
				1
			),
			_ACCESS_SCRIPT.get_option_int(
				diagnostic,
				"column",
				1
			),
			_ACCESS_SCRIPT.get_option_string(
				diagnostic,
				"rule",
				""
			),
			_ACCESS_SCRIPT.get_option_string(
				diagnostic,
				"message",
				""
			),
			_ACCESS_SCRIPT.get_option_string(
				diagnostic,
				"suggestion",
				""
			),
		]
	)


## 用户主动定位时才加载目标 GDScript 并交给编辑器；扫描 worker 不加载资源。
## [br]
## @api private
func _on_open_location() -> void:
	var selected: TreeItem = _results.get_selected()
	if selected == null:
		return
	var metadata_value: Variant = selected.get_metadata(0)
	if not metadata_value is Dictionary:
		return
	var diagnostic: Dictionary = metadata_value
	var path: String = _ACCESS_SCRIPT.get_option_string(
		diagnostic,
		"path",
		""
	)
	if not path.begins_with("res://") or not path.ends_with(".gd"):
		return
	if not FileAccess.file_exists(path):
		_details.text = "源文件已不存在，请重新检查。"
		return
	var resource: Resource = ResourceLoader.load(path)
	if resource is Script:
		var script: Script = resource
		EditorInterface.edit_script(
			script,
			maxi(
				0,
				_ACCESS_SCRIPT.get_option_int(
					diagnostic,
					"line",
					1
				) - 1
			),
			maxi(
				0,
				_ACCESS_SCRIPT.get_option_int(
					diagnostic,
					"column",
					1
				) - 1
			)
		)


## 仅切换已经取得的诊断页，不触发源码读取或重新检查。
## [br]
## @api private
func _on_previous() -> void:
	_offset = maxi(
		0,
		_offset - _PAGE_SIZE
	)
	_render_page()


## 只有仍有后续诊断时前进一页。
## [br]
## @api private
func _on_next() -> void:
	var diagnostics: Array = _ACCESS_SCRIPT.get_option_array(
		_report,
		"diagnostics",
		[]
	)
	if _offset + _PAGE_SIZE < diagnostics.size():
		_offset += _PAGE_SIZE
	_render_page()
