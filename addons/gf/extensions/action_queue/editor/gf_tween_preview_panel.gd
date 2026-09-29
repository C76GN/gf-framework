@tool

## Tween 配置 Inspector 的独立样机预览入口。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
class_name GFTweenPreviewPanel
extends VBoxContainer


# --- 常量 ---

const _SNAPSHOT_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/authoring/gf_tween_authoring_snapshot.gd")
const _TIMELINE_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/authoring/gf_tween_timeline.gd")
const _ACTIONS_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/gf_tween_editor_actions.gd")


# --- 私有变量 ---

var _timeline: _TIMELINE_SCRIPT = null
var _captured_source: Array = []
var _source_check_seconds: float = 0.0
var _stale_label: Label = null
var _backward_button: Button = null
var _forward_button: Button = null

## 当前绑定的 Tween 配置资源。
## [br]
## @api private
var _config: Resource = null

## 执行配置预览的子视口。
## [br]
## @api private
var _viewport: GFTweenPreviewViewport = null

## 选择预览目标类型的选项控件。
## [br]
## @api private
var _target_kind: OptionButton = null

## 启动或继续预览的按钮。
## [br]
## @api private
var _play_button: Button = null

## 暂停预览的按钮。
## [br]
## @api private
var _pause_button: Button = null

## 显示预览播放状态或错误的标签。
## [br]
## @api private
var _status_label: Label = null

## 显示当前预览属性值的标签。
## [br]
## @api private
var _values_label: Label = null

## 容纳时间滑块和定位输入控件的容器。
## [br]
## @api private
var _time_controls: VBoxContainer = null

## 控制预览时间位置的滑块。
## [br]
## @api private
var _time_slider: HSlider = null

## 输入预览时间位置的数值控件。
## [br]
## @api private
var _time_input: SpinBox = null

## 将输入的时间位置应用到预览的按钮。
## [br]
## @api private
var _inspect_button: Button = null

## 显示当前时间和预览时长的标签。
## [br]
## @api private
var _time_label: Label = null

## 容纳样机初始属性编辑器的容器。
## [br]
## @api private
var _initial_fields: VBoxContainer = null

## 指示预览面板是否已停止处理和释放预览。
## [br]
## @api private
var _disposed: bool = false

## 上一帧记录的单调时钟微秒值，用于计算帧间隔。
## [br]
## @api private
var _last_tick_usec: int = 0


# --- Godot 回调方法 ---

func _ready() -> void:
	_build_controls()
	_viewport.configure(_config, _target_kind.selected)
	_rebuild_initial_fields()
	_refresh_state()
	var _visibility_connected: int = visibility_changed.connect(_on_visibility_changed)


func _process(_delta: float) -> void:
	var now_usec: int = Time.get_ticks_usec()
	var elapsed: float = float(now_usec - _last_tick_usec) / 1000000.0 if _last_tick_usec > 0 else 0.0
	_last_tick_usec = now_usec
	if _disposed or _viewport == null or not is_visible_in_tree():
		return
	_viewport.advance(elapsed)
	_refresh_values()
	_source_check_seconds += elapsed
	if _source_check_seconds >= 0.5:
		_source_check_seconds = 0.0
		_refresh_stale_state()


func _exit_tree() -> void:
	dispose_preview()


# --- 框架内部方法 ---

## 绑定原生 Tween 配置资源；只在点击播放时读取配置快照。
## [br]
## @api framework_internal
## [br]
## @param config: 待预览资源，null 清除当前配置。
func configure(config: Resource) -> void:
	_config = config
	_captured_source.clear()
	_disposed = false
	show()
	if _viewport != null:
		_viewport.configure(config, _target_kind.selected)
		_rebuild_time_controls()
		_rebuild_initial_fields()
		_refresh_state()
	set_process(true)


## 终止并释放当前预览会话，可重复调用。
## [br]
## @api framework_internal
func dispose_preview() -> void:
	_disposed = true
	set_process(false)
	hide()
	_config = null
	_captured_source.clear()
	if is_instance_valid(_viewport):
		_viewport.dispose_preview()


# --- 私有/辅助方法 ---

## 创建预览面板的目标选择、视口、时间控件和状态展示。
## [br]
## @api private
func _build_controls() -> void:
	name = "TweenPreviewPanel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title: Label = Label.new()
	title.text = "Tween 预览"
	add_child(title)

	_target_kind = OptionButton.new()
	_target_kind.name = "TargetKind"
	_target_kind.add_item("2D 样机", 0)
	_target_kind.add_item("UI 样机", 1)
	_target_kind.add_item("3D 样机", 2)
	var _kind_connected: int = _target_kind.item_selected.connect(_on_target_kind_selected)
	add_child(_target_kind)

	var viewport_container: SubViewportContainer = SubViewportContainer.new()
	viewport_container.name = "PreviewCanvas"
	viewport_container.custom_minimum_size = Vector2(0.0, 240.0)
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(viewport_container)
	_viewport = GFTweenPreviewViewport.new()
	_viewport.name = "PreviewViewport"
	viewport_container.add_child(_viewport)
	var _state_connected: int = _viewport.state_changed.connect(_refresh_state)

	var controls: HBoxContainer = HBoxContainer.new()
	add_child(controls)
	_play_button = _add_button(controls, "Play", "播放", _on_play_pressed)
	_pause_button = _add_button(controls, "Pause", "暂停", _on_pause_pressed)
	var stop_button: Button = _add_button(controls, "Stop", "停止", _on_stop_pressed)
	stop_button.tooltip_text = "停止并保留当前画面；再次播放从初值开始。"
	var reset_button: Button = _add_button(controls, "Reset", "复位", _on_reset_pressed)
	reset_button.tooltip_text = "停止并恢复样机初值。"
	var direction_controls: HBoxContainer = HBoxContainer.new()
	add_child(direction_controls)
	_forward_button = _add_button(direction_controls, "Forward", "正向", _on_direction_pressed.bind(false))
	_backward_button = _add_button(direction_controls, "Backward", "反向", _on_direction_pressed.bind(true))
	var _recapture_button: Button = _add_button(direction_controls, "Recapture", "重新预览", _on_recapture_pressed)
	_stale_label = Label.new()
	_stale_label.name = "PreviewFreshness"
	_stale_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_stale_label)
	_time_controls = VBoxContainer.new()
	_time_controls.name = "PreviewTimeline"
	add_child(_time_controls)
	_rebuild_time_controls()
	var timeline_scroll: ScrollContainer = ScrollContainer.new()
	timeline_scroll.custom_minimum_size = Vector2(0.0, 110.0)
	add_child(timeline_scroll)
	_timeline = _TIMELINE_SCRIPT.new()
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_scroll.add_child(_timeline)
	var _binding_button: Button = _add_button(self, "CopyBinding", "复制运行时绑定示例", _on_copy_binding_pressed)

	_status_label = Label.new()
	_status_label.name = "PreviewStatus"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)
	_values_label = Label.new()
	_values_label.name = "PreviewValues"
	_values_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_values_label)

	var initial_toggle: CheckButton = CheckButton.new()
	initial_toggle.name = "InitialValues"
	initial_toggle.text = "样机初值"
	var _initial_connected: int = initial_toggle.toggled.connect(_on_initial_values_toggled)
	add_child(initial_toggle)
	_initial_fields = VBoxContainer.new()
	_initial_fields.visible = false
	add_child(_initial_fields)

	var hint: Label = Label.new()
	hint.text = "先播放捕获配置，再拖动时间或输入秒数定位。定位使用同一快照并暂停；修改配置后停止再播放生效。步骤标记不发出通知。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)


## 创建并连接一个按钮，然后添加到指定容器。
## [br]
## @api private
func _add_button(parent: Control, node_name: String, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _pressed_connected: int = button.pressed.connect(callback)
	parent.add_child(button)
	return button


## 退役旧时间控件并根据当前会话重建时间轴控件。
## [br]
## @api private
func _rebuild_time_controls() -> void:
	if _disposed or _time_controls == null:
		return
	# 原生控件离树时也可能同步提交编辑，先撤销旧输入源身份。
	var retired_controls: Array[Control] = [_time_slider, _time_input, _inspect_button, _time_label]
	_time_slider = null
	_time_input = null
	_inspect_button = null
	_time_label = null
	for retired_control: Control in retired_controls:
		if is_instance_valid(retired_control):
			retired_control.name = "RetiredTimeControl"
	for child: Node in _time_controls.get_children():
		child.name = "RetiredTimelineRow"
		if child is Control:
			var retired_row: Control = child
			retired_row.hide()
		child.queue_free()
	_time_slider = HSlider.new()
	_time_slider.name = "PreviewTimeSlider"
	_time_slider.min_value = 0.0
	_time_slider.step = 0.0
	_time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_slider.tooltip_text = "先播放一次；定位暂停同一快照，不读取后续配置修改。"
	_time_controls.add_child(_time_slider)
	var time_row: HBoxContainer = HBoxContainer.new()
	_time_controls.add_child(time_row)
	_time_input = SpinBox.new()
	_time_input.name = "PreviewTimeInput"
	_time_input.min_value = 0.0
	_time_input.step = 0.001
	_time_input.suffix = "s"
	_time_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_row.add_child(_time_input)
	_inspect_button = _add_button(time_row, "InspectTime", "定位", _on_inspect_time_pressed.bind(_time_input))
	_inspect_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_inspect_button.tooltip_text = "重复定位当前秒数；零时长配置也可检查其瞬时终值。"
	_time_label = Label.new()
	_time_label.name = "PreviewTimeReadout"
	time_row.add_child(_time_label)
	_refresh_time_controls()
	var _slider_connected: int = _time_slider.value_changed.connect(_on_time_changed.bind(_time_slider))
	var _input_connected: int = _time_input.value_changed.connect(_on_time_changed.bind(_time_input))


## 根据视口会话同步时间范围、当前位置和控件可编辑状态。
## [br]
## @api private
func _refresh_time_controls() -> void:
	if _time_slider == null or _time_input == null:
		return
	var has_session: bool = _viewport.has_session()
	var duration_seconds: float = _viewport.get_duration_seconds()
	var current_seconds: float = _viewport.get_time_seconds()
	# max_value 收窄本身也可能发 value_changed，必须连同数值同步一起阻止回调。
	_time_slider.set_block_signals(true)
	_time_slider.max_value = duration_seconds
	_time_slider.set_value_no_signal(current_seconds)
	_time_slider.editable = has_session
	_time_slider.set_block_signals(false)
	_time_input.set_block_signals(true)
	_time_input.max_value = duration_seconds
	_time_input.set_value_no_signal(current_seconds)
	_time_input.editable = has_session
	_time_input.set_block_signals(false)
	_inspect_button.disabled = not has_session
	_time_label.text = "/ %.3f s" % duration_seconds if has_session else "先播放以捕获时间轴"


## 根据视口的初始属性值重建编辑字段。
## [br]
## @api private
func _rebuild_initial_fields() -> void:
	for child: Node in _initial_fields.get_children():
		child.name = "RetiredInitialValue"
		if child is Control:
			var control: Control = child
			control.hide()
		child.queue_free()
	var values: Dictionary = _viewport.get_initial_values()
	for key: Variant in values:
		var property_name: StringName = StringName(str(key))
		var field: GFEditorValueField = GFEditorValueField.new()
		field.name = "Initial_%s" % property_name
		field.set_label(String(property_name))
		field.configure({ "name": property_name, "type": typeof(values[key]) }, values[key])
		var _value_connected: int = field.value_changed.connect(_on_initial_value_changed.bind(property_name, field))
		_initial_fields.add_child(field)


## 按视口状态更新按钮和状态标签，并刷新属性值展示。
## [br]
## @api private
func _refresh_state() -> void:
	if _status_label == null or _disposed:
		return
	var state: StringName = _viewport.get_state()
	_play_button.text = "继续" if state == &"paused" else "播放"
	_play_button.disabled = state == &"playing"
	_pause_button.disabled = state != &"playing"
	_forward_button.disabled = not _viewport.is_controlled_session()
	_backward_button.disabled = not _viewport.is_controlled_session()
	match state:
		&"playing":
			_status_label.text = "播放中"
		&"paused":
			_status_label.text = "已暂停"
		&"finished":
			_status_label.text = "播放完成"
		&"error":
			_status_label.text = _viewport.get_error()
		_:
			_status_label.text = "就绪"
	_refresh_values()


## 将当前属性值写入展示标签，并同步时间控件。
## [br]
## @api private
func _refresh_values() -> void:
	if _values_label == null:
		return
	var values: Dictionary = _viewport.get_current_values()
	var parts: PackedStringArray = PackedStringArray()
	for key: Variant in values:
		var _appended: bool = parts.append("%s: %s" % [key, values[key]])
	_values_label.text = "\n".join(parts)
	_refresh_time_controls()
	if _timeline != null:
		_timeline.configure(_viewport.get_preview_plan())
		_timeline.set_time_seconds(_viewport.get_time_seconds())


## 比较有界纯值签名；状态只作提示，不自动打断当前冻结会话。
## [br]
## @api private
func _refresh_stale_state() -> void:
	if _stale_label == null:
		return
	var stale: bool = _viewport.has_session() and _captured_source != _SNAPSHOT_SCRIPT.capture(_config)
	_stale_label.text = "预览已过期：配置已修改；当前画面使用旧快照。点击“重新预览”更新。" if stale else ""


# --- 信号处理函数 ---

## 播放或继续预览，并在捕获新会话后更新时间控件。
## [br]
## @api private
func _on_play_pressed() -> void:
	if not _disposed:
		var captures_new_session: bool = _viewport.get_state() != &"paused"
		_last_tick_usec = Time.get_ticks_usec()
		var _started: bool = _viewport.play()
		if captures_new_session:
			_captured_source = _SNAPSHOT_SCRIPT.capture(_config)
			_rebuild_time_controls()
		_refresh_stale_state()


## 显式开始新快照。
## [br]
## @api private
func _on_recapture_pressed() -> void:
	if not _disposed:
		_viewport.stop()
		_on_play_pressed()


## 只对受控快照切换方向。
## [br]
## @api private
func _on_direction_pressed(backward: bool) -> void:
	if not _disposed:
		_last_tick_usec = Time.get_ticks_usec()
		var _accepted: bool = _viewport.play_direction(backward)


## 复制当前资源的绑定示例；未保存资源使用明确占位路径。
## [br]
## @api private
func _on_copy_binding_pressed() -> void:
	if not _disposed and _config != null:
		DisplayServer.clipboard_set(_ACTIONS_SCRIPT.make_binding_example(_config.resource_path))


## 暂停当前预览会话。
## [br]
## @api private
func _on_pause_pressed() -> void:
	if not _disposed:
		_viewport.pause()


## 停止当前预览会话并保留当前画面。
## [br]
## @api private
func _on_stop_pressed() -> void:
	if not _disposed:
		_viewport.stop()


## 重置预览并刷新时间控件。
## [br]
## @api private
func _on_reset_pressed() -> void:
	if not _disposed:
		_viewport.reset_preview()
		_rebuild_time_controls()


## 重新配置目标类型对应的预览，并刷新初值和状态控件。
## [br]
## @api private
func _on_target_kind_selected(index: int) -> void:
	if _disposed:
		return
	_viewport.configure(_config, index)
	_rebuild_time_controls()
	_rebuild_initial_fields()
	_refresh_state()


## 按切换状态显示或隐藏初始属性编辑器。
## [br]
## @api private
func _on_initial_values_toggled(pressed: bool) -> void:
	if not _disposed:
		_initial_fields.visible = pressed


## 更新样机初始属性；值无效时将字段恢复为当前初值。
## [br]
## @api private
func _on_initial_value_changed(value: Variant, property_name: StringName, field: GFEditorValueField) -> void:
	if (
		_disposed or not is_instance_valid(field) or field.is_queued_for_deletion()
		or field.get_parent() != _initial_fields
	):
		return
	if not _viewport.set_initial_value(property_name, value):
		field.set_value(_viewport.get_initial_values().get(property_name))
	_rebuild_time_controls()
	_refresh_state()


## 将有效时间控件提交的位置应用为视口预览时间。
## [br]
## @api private
func _on_time_changed(time_seconds: float, source: Range) -> void:
	if (
		_disposed or not is_visible_in_tree() or not is_instance_valid(source)
		or source.is_queued_for_deletion() or (source != _time_slider and source != _time_input)
		or not _viewport.has_session()
	):
		return
	var _located: bool = _viewport.seek(time_seconds)
	_refresh_state()


## 将定位输入控件的当前数值交给时间变更处理函数。
## [br]
## @api private
func _on_inspect_time_pressed(source: SpinBox) -> void:
	if is_instance_valid(source):
		_on_time_changed(source.value, source)


## 面板隐藏时重置预览并重建时间控件状态。
## [br]
## @api private
func _on_visibility_changed() -> void:
	if not _disposed and _viewport != null and not is_visible_in_tree():
		_viewport.reset_preview()
		_rebuild_time_controls()
