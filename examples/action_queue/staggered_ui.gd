# F6 运行有序交错演示；暂停、取消、重播和离树清理复用 GF 动作组。
extends Control


const _BUILDER_SCRIPT = preload("res://examples/action_queue/stagger_builder.gd")


var _targets: Array[Node] = []
var _action: GFVisualActionGroup = null
var _completion: Signal = Signal()
var _completion_callback: Callable = Callable()
var _status: Label = null
var _pause_button: Button = null
var _paused: bool = false
var _serial: int = 0


func _ready() -> void:
	_build_ui()


func _exit_tree() -> void:
	_stop()


func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 28)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var title: Label = Label.new()
	title.text = "一组目标，依次入场"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var description: Label = Label.new()
	description.text = "每项相隔 0.08 秒开始渐显；整组可暂停、取消和重播。取消保留当前姿态，重播重新建立初值。"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	var toolbar: HBoxContainer = HBoxContainer.new()
	column.add_child(toolbar)
	var _start_button: Button = _button(toolbar, "开始 / 重播", _start)
	_pause_button = _button(toolbar, "暂停", _toggle_pause)
	_pause_button.disabled = true
	var _cancel_button: Button = _button(toolbar, "取消", _cancel)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	for index: int in range(12):
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(132.0, 72.0)
		var label: Label = Label.new()
		label.text = "目标 %d" % (index + 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(label)
		card.modulate.a = 0.15
		grid.add_child(card)
		_targets.append(card)
	_status = Label.new()
	_status.text = "就绪"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)


func _button(parent: Control, label: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.custom_minimum_size.y = 36.0
	parent.add_child(button)
	var _connected: Error = button.pressed.connect(callback)
	return button


func _make_action(target: Node) -> GFVisualAction:
	return GFAction.fade_to(target, 1.0, 0.35)


func _stop() -> void:
	_serial += 1
	if not _completion.is_null() and _completion_callback.is_valid() and _completion.is_connected(_completion_callback):
		_completion.disconnect(_completion_callback)
	_completion = Signal()
	_completion_callback = Callable()
	if _action != null:
		_action.cancel()
	_action = null
	_paused = false


func _start() -> void:
	_stop()
	for target: Node in _targets:
		if target is CanvasItem:
			var canvas: CanvasItem = target
			canvas.modulate.a = 0.0
	var result: Dictionary = _BUILDER_SCRIPT.build(_targets, 0.08, _make_action, self)
	var action_value: Variant = result.get("action")
	if result.get("ok") != true or not action_value is GFVisualActionGroup:
		_status.text = "无法开始：%s" % result.get("error", &"")
		return
	_action = action_value
	_status.text = "播放中"
	_pause_button.disabled = false
	_pause_button.text = "暂停"
	var completion: Variant = _action.execute()
	if completion is Signal:
		_completion = completion
		_completion_callback = _on_completed.bind(_serial)
		var _connected: Error = _completion.connect(_completion_callback, CONNECT_ONE_SHOT)
	else:
		_on_completed(_serial)


func _toggle_pause() -> void:
	if _action == null:
		return
	_paused = not _paused
	if _paused:
		_action.pause()
	else:
		_action.resume()
	_pause_button.text = "继续" if _paused else "暂停"
	_status.text = "已暂停" if _paused else "播放中"


func _cancel() -> void:
	_stop()
	_status.text = "已取消，保留当前姿态"
	_pause_button.disabled = true
	_pause_button.text = "暂停"


func _on_completed(serial: int) -> void:
	if serial != _serial or not is_inside_tree():
		return
	_completion = Signal()
	_completion_callback = Callable()
	_action = null
	_status.text = "全部完成"
	_pause_button.disabled = true
