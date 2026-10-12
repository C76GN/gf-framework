# F6 运行此场景；默认项目 Boot 和 AutoLoad 装配不变。
extends Control


# --- 常量 ---

const SESSION = preload("res://examples/first_task/task_session.gd")


# --- 私有变量 ---

var _session: SESSION = null
var _count_label: Label = null
var _status_label: Label = null
var _increment_button: Button = null
var _save_button: Button = null
var _quit_button: Button = null
var _force_quit_button: Button = null
var _start_buttons: Array[Button] = []
var _last_request: GFAsyncCompletion = null
var _previous_auto_quit: bool = true
var _smoke_failures: Array[String] = []


# --- Godot 生命周期方法 ---

func _ready() -> void:
	_previous_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	_build_ui()
	if OS.get_cmdline_user_args().has("--first-task-smoke"):
		call_deferred("_run_smoke")


func _process(delta: float) -> void:
	if _session != null:
		_session.tick(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_close_and_quit.call_deferred()


func _exit_tree() -> void:
	if _session != null:
		_session.dispose()
	get_tree().auto_accept_quit = _previous_auto_quit


# --- 私有/辅助方法 ---

func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 32)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var title: Label = Label.new()
	title.text = "第一个完整任务 · 可保存的计数器"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var description: Label = Label.new()
	description.text = "选择一种会话开始。完成一次加分、保存并退出，再次运行可恢复计数。\n异步模式增加有界工作队列；退出会等待已接纳工作并确认保存成功。"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	var starts: HBoxContainer = HBoxContainer.new()
	column.add_child(starts)
	_start_buttons.append(_button(starts, "基础会话", _start.bind(false)))
	_start_buttons.append(_button(starts, "异步服务会话", _start.bind(true)))
	_count_label = Label.new()
	_count_label.text = "尚未开始"
	_count_label.add_theme_font_size_override("font_size", 36)
	column.add_child(_count_label)
	var actions: HBoxContainer = HBoxContainer.new()
	column.add_child(actions)
	_increment_button = _button(actions, "加 1", _increment)
	var _cancel_button: Button = _button(actions, "取消最近工作", _cancel_last)
	_save_button = _button(actions, "保存", _save)
	_quit_button = _button(actions, "保存并退出", _close_and_quit)
	_force_quit_button = _button(actions, "强制退出（可能丢失进度）", _force_quit)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status_label)
	_render()


func _button(parent: Control, title: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = title
	button.custom_minimum_size.y = 42.0
	var _connected: Error = button.pressed.connect(action) as Error
	parent.add_child(button)
	return button


func _start(asynchronous: bool) -> void:
	if _session != null:
		return
	var _started: bool = await _open_session("gf_first_task.json", asynchronous)


func _open_session(file_name: String, asynchronous: bool, store: GFSettingsStoreUtility = null) -> bool:
	_session = SESSION.new()
	var _connected: Error = _session.changed.connect(_render) as Error
	for button: Button in _start_buttons:
		button.disabled = true
	var started: bool = await _session.start(file_name, asynchronous, store)
	_render()
	return started


func _render() -> void:
	var accepting: bool = _session != null and _session.ready and not _session.closing
	_increment_button.disabled = not accepting
	_save_button.disabled = not accepting
	_quit_button.disabled = false
	_force_quit_button.visible = _session != null and not _session.last_error.is_empty() and (_session.closing or _session.closed)
	if _session == null:
		_status_label.text = "设置写入 user://gf_first_task.json，与其他项目数据分开。"
		return
	_count_label.text = str(_session.count)
	if not _session.last_error.is_empty():
		_status_label.text = _session.last_error
	elif _session.closed:
		_status_label.text = "会话已关闭。"
	elif _session.closing:
		_status_label.text = "停止接纳新工作，正在收尾并保存……"
	else:
		_status_label.text = "会话已就绪。加分后点击保存，或保存并退出。"


func _increment() -> void:
	if _session == null:
		return
	_last_request = _session.increment()
	if _last_request.is_pending():
		_status_label.text = "工作已接纳，等待完成……"
	elif _last_request.is_failed():
		_status_label.text = _last_request.get_error()


func _cancel_last() -> void:
	if _last_request != null and _last_request.is_pending():
		var _cancelled: bool = _last_request.cancel(&"user_cancelled")
		_status_label.text = "最近工作已取消，计数未增加。"


func _save() -> void:
	if _session != null and _session.save() == OK:
		_status_label.text = "设置已保存。"


func _close_and_quit() -> void:
	if _session == null:
		get_tree().quit()
		return
	if await _session.close():
		get_tree().quit()


func _force_quit() -> void:
	get_tree().quit()


## 场景自身的真实进程验收：独立临时文件、实际按钮、重启恢复和失败不退出。
func _run_smoke() -> void:
	var file_name: String = "gf_first_task_smoke_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	_check(await _open_session(file_name, false), "基础会话启动")
	_increment_button.pressed.emit()
	_check(_session.count == 1 and _count_label.text == "1", "按钮更新状态与界面")
	_save_button.pressed.emit()
	_check(_status_label.text == "设置已保存。", "保存反馈")
	_check(await _session.close(), "基础会话退出")
	_session = null
	_check(await _open_session(file_name, true), "异步会话恢复")
	_check(_session.count == 1, "保存重启恢复计数")
	_increment_button.pressed.emit()
	_cancel_last()
	_check(_session.count == 1, "取消不提交副作用")
	_increment_button.pressed.emit()
	_check(_last_request.is_pending(), "异步工作接纳")
	var close_state: Dictionary = {"refused": false}
	var guard: Callable = func() -> void:
		if _session.closing and not _session.closed:
			close_state["refused"] = _session.increment().is_failed()
	var _guard_connected: Error = _session.changed.connect(guard) as Error
	_check(await _session.close(), "排空后保存并退出")
	_session.changed.disconnect(guard)
	_check(GFVariantData.get_option_bool(close_state, "refused"), "退出期间拒绝新工作")
	_check(_session.count == 2, "已接纳工作在退出前完成")
	_session = null
	_check(await _open_session(file_name, false), "最终恢复")
	_check(_session.count == 2, "收尾结果已持久化")
	_check(await _session.close(), "最终关闭")
	var removed: Error = DirAccess.remove_absolute("user://%s" % file_name)
	_check(removed == OK, "只清除本次 smoke 文件")
	_session = null
	var failing_store: FailingStore = FailingStore.new()
	_check(await _open_session("first_task_memory", true, failing_store), "失败场景启动")
	_increment_button.pressed.emit()
	_check(not await _session.close(), "保存失败阻止正常退出")
	_check(not _session.closed and _session.count == 1, "失败保留状态")
	failing_store.fail_writes = false
	_check(await _session.close(), "保存重试后退出")
	print("FIRST_TASK_SMOKE=%s" % JSON.stringify({"ok": _smoke_failures.is_empty(), "failures": _smoke_failures}))
	get_tree().quit(0 if _smoke_failures.is_empty() else 1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_smoke_failures.append(description)
		push_error("First task smoke failed: %s" % description)


# --- 内部类 ---

class FailingStore extends GFSettingsStoreUtility:
	var fail_writes: bool = true


	func is_persistence_enabled() -> bool:
		return true


	func read_settings(_file_name: String) -> GFStorageReadResult:
		return GFStorageReadResult.new().configure_failure("First use", ERR_FILE_NOT_FOUND, {}, GFStorageReadResult.IntegrityStatus.NOT_CHECKED, 0, GFStorageReadResult.FailureKind.NOT_FOUND)


	func write_settings(_file_name: String, _data: Dictionary) -> Error:
		return ERR_FILE_CANT_WRITE if fail_writes else OK
