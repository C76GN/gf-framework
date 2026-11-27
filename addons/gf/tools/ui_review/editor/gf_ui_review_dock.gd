@tool

# 比较项目磁盘场景在多组窗口、语言和缩放下的实际画面。运行状态仅属于当前打开的工具实例。
extends VBoxContainer


# --- 常量 ---

## 原生工作区按钮、焦点和尺寸约定。
## [br]
## @api private
const _WORKSPACE_UI = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")

## 独立批次进程入口。
## [br]
## @api private
const _COORDINATOR: String = "res://addons/gf/tools/ui_review/editor/gf_ui_review_coordinator.gd"

## 负责一组真实游戏窗口设置的工作进程。
## [br]
## @api private
const _WORKER: String = "res://addons/gf/tools/ui_review/editor/gf_ui_review_worker.gd"


# --- 私有变量 ---

## 项目显式提供的真实页面样例。
## [br]
## @api private
var _fixture: EditorResourcePicker

## 项目样例状态标识。
## [br]
## @api private
var _state: LineEdit

## 待运行的窗口尺寸。
## [br]
## @api private
var _sizes: LineEdit

## 待运行的语言。
## [br]
## @api private
var _locales: LineEdit

## 待运行的缩放百分比。
## [br]
## @api private
var _scales: LineEdit

## 统一采样时刻，以秒计。
## [br]
## @api private
var _time: SpinBox

## 本地文件与采样状态反馈。
## [br]
## @api private
var _status: Label

## 本次运行结果缩略图。
## [br]
## @api private
var _images: GridContainer

## 当前调度进程及唯一输出目录。
## [br]
## @api private
var _pid: int = -1

## 本次采样隔离目录。
## [br]
## @api private
var _folder: String = ""


# --- Godot 生命周期方法 ---

func _ready() -> void:
	var heading: Label = Label.new()
	heading.text = "选择已保存的场景。每组条件在独立游戏进程中采样。"
	add_child(heading)
	_fixture = EditorResourcePicker.new()
	_fixture.base_type = "PackedScene"
	_fixture.tooltip_text = "含项目样例状态的真实场景"
	add_child(_fixture)
	_state = _field("样例状态", "")
	_sizes = _field("窗口尺寸", "1280x720,960x540,1470x630,540x810")
	_locales = _field("语言", "zh,en")
	_scales = _field("UI 缩放（%）", "85,100,125")
	var time_row: HBoxContainer = HBoxContainer.new()
	add_child(time_row)
	var caption: Label = Label.new()
	caption.text = "采样时刻（秒）"
	time_row.add_child(caption)
	_time = SpinBox.new()
	_time.max_value = 60.0
	_time.step = 0.01
	time_row.add_child(_time)
	var commands: HFlowContainer = HFlowContainer.new()
	add_child(commands)
	commands.add_child(
		_WORKSPACE_UI.make_button(
			"运行对照",
			"",
			_compare
		)
	)
	commands.add_child(
		_WORKSPACE_UI.make_button(
			"停止采样",
			"",
			_stop
		)
	)
	commands.add_child(
		_WORKSPACE_UI.make_button(
			"实播所选场景",
			"",
			_compare.bind(true)
		)
	)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_images = GridContainer.new()
	_images.columns = 2
	add_child(_images)
	set_process(false)


func _process(_delta: float) -> void:
	var path: String = _folder.path_join("report.json")
	if not FileAccess.file_exists(path):
		if _pid > 0 and not OS.is_process_running(_pid):
			_status.text = "对照进程提前退出。日志位于 " + _folder
			_pid = -1
			set_process(false)
		return
	set_process(false)
	_pid = -1
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_status.text = "无法读取对照结果 " + path
		return
	var report: Dictionary = parsed
	var results: Array = report.results
	var message: String = report.message
	for result: Dictionary in results:
		if result.has("error"):
			message = (
				"%s  %s"
				% [message, result.error]
			).strip_edges()
			break
	if report.get("interactive", false):
		_status.text = (
			"%s  %s"
			% ["实播已结束。" if message.is_empty() else message, _folder]
		)
		return
	var success: int = 0
	for result: Dictionary in results:
		if result.has("image"):
			var case_index: int = result.index
			var image_name: String = result.image
			var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(_folder.path_join("case_%03d.json" % case_index)))
			var image: Image = Image.load_from_file(_folder.path_join(image_name))
			if (
				image != null
				and not image.is_empty()
				and metadata is Dictionary
			):
				var tile: VBoxContainer = VBoxContainer.new()
				_images.add_child(tile)
				var title: Label = Label.new()
				title.text = (
					"%d×%d · %s · %d%%"
					% [
						metadata.case.width,
						metadata.case.height,
						metadata.case.locale,
						metadata.case.scale,
					]
				)
				tile.add_child(title)
				var preview: TextureRect = TextureRect.new()
				image.resize(
					200,
					maxi(
						1,
						roundi(200.0 * image.get_height() / image.get_width())
					),
					Image.INTERPOLATE_BILINEAR
				)
				preview.texture = ImageTexture.create_from_image(image)
				preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				preview.custom_minimum_size = Vector2(128, 82)
				tile.add_child(preview)
				success += 1
	_status.text = (
		"%d/%d 组已采集。%s  %s"
		% [
			success,
			results.size(),
			message,
			_folder,
		]
	)


func _exit_tree() -> void:
	_stop()


# --- 框架内部方法 ---

## 从工作区任务进入场景选择，采样由用户启动。
## [br]
## @api framework_internal
## [br]
## @param action_id: 页面任务名。
## [br]
## @return: 任务入口状态。
## [br]
## @schema return: Dictionary，包含 ok、status 和 message。
func run_workspace_task(action_id: String) -> Dictionary:
	if action_id != "compare" or not is_node_ready():
		return {
			"ok": false,
			"status": "unavailable",
			"message": "页面对照未就绪",
		}
	_state.grab_focus()
	return {
		"ok": true,
		"status": "opened",
		"message": "已打开真实页面对照",
	}


# --- 私有/辅助方法 ---

## 为每种配置维度提供独立的可编辑输入。
## [br]
## @api private
func _field(title: String, value: String) -> LineEdit:
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)
	var label: Label = Label.new()
	label.text = title
	row.add_child(label)
	var field: LineEdit = LineEdit.new()
	field.text = value
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	return field


## 将有效维度展开为有限、可重复的采样列表。
## [br]
## @api private
func _cases() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	for item: String in _sizes.text.split(",", false):
		var dims: PackedStringArray = item.strip_edges().to_lower().replace("×", "x").split("x")
		if (
			dims.size() != 2
			or not dims[0].is_valid_int()
			or not dims[1].is_valid_int()
		):
			return []
		var width: int = dims[0].to_int()
		var height: int = dims[1].to_int()
		if (
			width < 32
			or width > 8192
			or height < 32
			or height > 8192
		):
			return []
		for locale: String in _locales.text.split(",", false):
			for percent: String in _scales.text.split(",", false):
				var value: String = percent.strip_edges()
				if (
					locale.strip_edges().is_empty()
					or not value.is_valid_int()
					or value.to_int() < 25
					or value.to_int() > 400
					or cases.size() >= 128
				):
					return []
				cases.append(
					{
						"width": width,
						"height": height,
						"locale": locale.strip_edges(),
						"scale": value.to_int(),
						"state": _state.text,
						"seconds": _time.value,
						"seed": 1,
					}
				)
	return cases


## 用独立目录启动无项目依赖的调度进程，保留追踪此次运行所需的 PID。
## [br]
## @api private
func _launch(
	scene: String,
	cases: Array[Dictionary],
	interactive: bool
) -> void:
	var cache: String = EditorInterface.get_editor_paths().get_cache_dir()
	_folder = cache.path_join("gf-ui-review").path_join(
		"%d-%d"
		% [OS.get_process_id(), Time.get_ticks_usec()]
	)
	var bootstrap: String = _folder.path_join("bootstrap")
	if DirAccess.make_dir_recursive_absolute(bootstrap) != OK:
		_status.text = "无法创建对照目录"
		return
	var config: FileAccess = FileAccess.open(
		bootstrap.path_join("project.godot"),
		FileAccess.WRITE
	)
	if config == null:
		_status.text = "无法创建隔离项目描述"
		return
	if not config.store_string("config_version=5\n"):
		_status.text = "写入隔离项目描述失败"
		return
	config.close()
	var job: Dictionary = {
		"interactive": interactive,
		"cases": cases,
		"scene": scene,
		"project": ProjectSettings.globalize_path("res://"),
		"private_dir": _folder.path_join("private"),
		"worker": _WORKER,
	}
	var path: String = _folder.path_join("job.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_status.text = "无法写入采样配置"
		return
	if not file.store_string(JSON.stringify(job)):
		_status.text = "写入采样配置失败"
		return
	file.close()
	_pid = OS.create_instance(
		PackedStringArray(
			[
				"--headless",
				"--path",
				bootstrap,
				"--log-file",
				_folder.path_join("coordinator.log"),
				"--script",
				ProjectSettings.globalize_path(_COORDINATOR),
				"--",
				path,
			]
		)
	)
	if _pid <= 0:
		_status.text = "无法启动隔离采样进程"
		return
	_status.text = "正在采集 %d 个组合" % cases.size()
	set_process(true)


## 仅对由用户选择且已保存的项目场景运行采样。
## [br]
## @api private
func _compare(interactive: bool = false) -> void:
	if _pid > 0:
		return
	var cases: Array[Dictionary] = _cases()
	if (
		_fixture.edited_resource == null
		or _fixture.edited_resource.resource_path.is_empty()
		or cases.is_empty()
	):
		_status.text = "请选择已保存的场景并检查尺寸、语言和缩放"
		return
	for child: Node in _images.get_children():
		_images.remove_child(child)
		child.queue_free()
	if interactive:
		cases = [cases[0]]
	_launch(
		_fixture.edited_resource.resource_path,
		cases,
		interactive
	)


## 调度进程读取标志后回收自己拥有的游戏进程。
## [br]
## @api private
func _stop() -> void:
	if _pid > 0 and not _folder.is_empty():
		var file: FileAccess = FileAccess.open(
			_folder.path_join("cancel"),
			FileAccess.WRITE
		)
		if file != null:
			file.close()
