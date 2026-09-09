@tool

## Tween 配置 Inspector 的独立样机预览入口。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
class_name GFTweenPreviewPanel
extends VBoxContainer


# --- 私有变量 ---

var _config: Resource = null
var _viewport: GFTweenPreviewViewport = null
var _target_kind: OptionButton = null
var _play_button: Button = null
var _pause_button: Button = null
var _status_label: Label = null
var _values_label: Label = null
var _initial_fields: VBoxContainer = null
var _disposed: bool = false
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
	_disposed = false
	show()
	if _viewport != null:
		_viewport.configure(config, _target_kind.selected)
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
	if is_instance_valid(_viewport):
		_viewport.dispose_preview()


# --- 私有/辅助方法 ---

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
	hint.text = "修改配置后重新播放生效。预览使用独立时钟，步骤标记不发出通知。样机初值只用于当前预览。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)


func _add_button(parent: HBoxContainer, node_name: String, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var _pressed_connected: int = button.pressed.connect(callback)
	parent.add_child(button)
	return button


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


func _refresh_state() -> void:
	if _status_label == null or _disposed:
		return
	var state: StringName = _viewport.get_state()
	_play_button.text = "继续" if state == &"paused" else "播放"
	_play_button.disabled = state == &"playing"
	_pause_button.disabled = state != &"playing"
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


func _refresh_values() -> void:
	if _values_label == null:
		return
	var values: Dictionary = _viewport.get_current_values()
	var parts: PackedStringArray = PackedStringArray()
	for key: Variant in values:
		var _appended: bool = parts.append("%s: %s" % [key, values[key]])
	_values_label.text = "\n".join(parts)


# --- 信号处理函数 ---

func _on_play_pressed() -> void:
	if not _disposed:
		_last_tick_usec = Time.get_ticks_usec()
		var _started: bool = _viewport.play()


func _on_pause_pressed() -> void:
	if not _disposed:
		_viewport.pause()


func _on_stop_pressed() -> void:
	if not _disposed:
		_viewport.stop()


func _on_reset_pressed() -> void:
	if not _disposed:
		_viewport.reset_preview()


func _on_target_kind_selected(index: int) -> void:
	if _disposed:
		return
	_viewport.configure(_config, index)
	_rebuild_initial_fields()
	_refresh_state()


func _on_initial_values_toggled(pressed: bool) -> void:
	if not _disposed:
		_initial_fields.visible = pressed


func _on_initial_value_changed(value: Variant, property_name: StringName, field: GFEditorValueField) -> void:
	if (
		_disposed or not is_instance_valid(field) or field.is_queued_for_deletion()
		or field.get_parent() != _initial_fields
	):
		return
	if not _viewport.set_initial_value(property_name, value):
		field.set_value(_viewport.get_initial_values().get(property_name))
	_refresh_state()


func _on_visibility_changed() -> void:
	if not _disposed and _viewport != null and not is_visible_in_tree():
		_viewport.reset_preview()
