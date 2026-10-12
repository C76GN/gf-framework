@tool

## Tween 配置 Inspector 的独立样机预览入口。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
class_name GFTweenPreviewPanel
extends VBoxContainer


# --- 常量 ---

## 用有界纯值签名比较来源变化，不修改已经捕获的预览计划。
## [br]
## @api private
const _SNAPSHOT_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/authoring/gf_tween_authoring_snapshot.gd")

## 根据冻结计划绘制步骤区段的控件类型，不参与执行来源配置。
## [br]
## @api private
const _TIMELINE_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/authoring/gf_tween_timeline.gd")

## 复用资源路径到运行时绑定示例的文本生成入口。
## [br]
## @api private
const _ACTIONS_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/gf_tween_editor_actions.gd")

## 只根据同次捕获计划和倍率换算目标总秒数，提交仍归原生历史。
## [br]
## @api private
const _DURATION_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/authoring/gf_tween_authoring_duration.gd")


# --- 私有变量 ---

## 由面板滚动容器持有的只读时间条，随当前视口会话同步计划与游标。
## [br]
## @api private
var _timeline: _TIMELINE_SCRIPT = null

## 最近一次准备成功的来源纯值签名；继续冻结会话不覆盖，重新配置或释放时清空。
## [br]
## @api private
var _captured_source: Array = []

## 冻结计划对应的作者身份；来源值相同而步骤对象改变也不能按旧索引导航。
## [br]
## @api private
var _captured_navigation: Dictionary = {}

## 与当前计划及播放签名同次读取的根倍率，仅用于总时长换算。
## [br]
## @api private
var _captured_scale: float = 0.0

## 输入框只在换计划时同步总秒数，不能因刷新或失焦覆盖尚未提交的用户值。
## [br]
## @api private
var _duration_plan: GFTweenPreviewPlan = null

## 目标完整时间轴秒数；独立于用于查看旧快照的定位控件。
## [br]
## @api private
var _target_seconds: SpinBox = null

## 明确提交倍率的离散操作，过期来源不允许用旧计划提交。
## [br]
## @api private
var _apply_duration: Button = null

## 总时长换算拒绝原因，不通过日志或部分候选报告成功。
## [br]
## @api private
var _duration_feedback: Label = null

## 只有同源结构化步骤和字段才允许的纠错入口。
## [br]
## @api private
var _error_location: Button = null

## 可见处理期间累加的来源检查间隔，到半秒时归零并刷新过期提示。
## [br]
## @api private
var _source_check_seconds: float = 0.0

## 只提示来源与冻结会话是否不同，不因提示过期而中断播放。
## [br]
## @api private
var _stale_label: Label = null

## 反向播放按钮；仅在当前快照支持播放控制时启用。
## [br]
## @api private
var _backward_button: Button = null

## 正向播放按钮；与反向按钮共享当前受控会话的可用性条件。
## [br]
## @api private
var _forward_button: Button = null

## 当前绑定的 Tween 配置资源。
## [br]
## @api private
var _config: Resource = null

## 与步骤编辑器共享的预览上下文；面板独立使用时自行创建，释放只撤销自身订阅。
## [br]
## @api private
var _context: GFTweenPreviewContext = null

## 绑定目标、初值及两种租约的独立身份；无关目录或来源字段变化不打断当前冻结会话。
## [br]
## @api private
var _binding_identity: Dictionary = {}

## 目标重绑定或释放的代次；适配器回调重入后旧准备不能继续操作新样机。
## [br]
## @api private
var _binding_generation: int = 0

## 目标下拉框最近显示的纯值选项；相同刷新不重建用户正在浏览的目录。
## [br]
## @api private
var _choice_snapshot: Array[Dictionary] = []

## 显式重新捕获但不播放的按钮，受当前目标准入状态控制。
## [br]
## @api private
var _prepare_button: Button = null

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

## 建立预览子树并配置当前来源，随后监听可见性以在面板隐藏时复位会话。
## [br]
## @api private
func _ready() -> void:
	_build_controls()
	if _context == null:
		_context = GFTweenPreviewContext.new()
		_context.configure(_config)
	_connect_context()
	_on_preview_context_changed()
	var _visibility_connected: int = visibility_changed.connect(_on_visibility_changed)


## 以单调时钟推进可见且未释放的预览，并每半秒检查来源是否改变；隐藏期间不推进会话。
## [br]
## @api private
func _process(_delta: float) -> void:
	var now_usec: int = Time.get_ticks_usec()
	var elapsed: float = float(now_usec - _last_tick_usec) / 1000000.0 if _last_tick_usec > 0 else 0.0
	_last_tick_usec = now_usec
	if _disposed or _viewport == null or not is_visible_in_tree():
		return
	if _viewport.has_session() and not _qualify_binding():
		return
	_viewport.advance(elapsed)
	if not is_instance_valid(self) or _disposed:
		return
	_refresh_values()
	_source_check_seconds += elapsed
	if _source_check_seconds >= 0.5:
		_source_check_seconds = 0.0
		if _context != null:
			_context.refresh()
		if not is_instance_valid(self) or _disposed:
			return
		_on_preview_context_changed()
		if not is_instance_valid(self) or _disposed:
			return
		_refresh_stale_state()


## 离树时复用幂等释放入口，停止处理并撤销当前视口会话与来源引用。
## [br]
## @api private
func _exit_tree() -> void:
	dispose_preview()


# --- 框架内部方法 ---

## 绑定资源和共享上下文；入树后立即准备时间轴，不自动播放。
## [br]
## @api framework_internal
## [br]
## @param config: 待预览资源，null 清除当前配置。
## [br]
## @param context: 同一资源的 Inspector 上下文；null 创建独立上下文，不与配置资源混存。
func configure(config: Resource, context: GFTweenPreviewContext = null) -> void:
	_disconnect_context()
	_config = config
	_context = context
	if _context == null:
		_context = GFTweenPreviewContext.new()
		_context.configure(config)
	_connect_context()
	_binding_generation += 1
	_binding_identity.clear()
	_choice_snapshot.clear()
	_captured_source.clear()
	_captured_navigation.clear()
	_disposed = false
	show()
	if _viewport != null:
		_on_preview_context_changed()
	set_process(true)


## 终止并释放当前预览会话，可重复调用。
## [br]
## @api framework_internal
func dispose_preview() -> void:
	_disposed = true
	_binding_generation += 1
	set_process(false)
	hide()
	_disconnect_context()
	_context = null
	_config = null
	_binding_identity.clear()
	_choice_snapshot.clear()
	_captured_source.clear()
	_captured_navigation.clear()
	if is_instance_valid(_viewport):
		_viewport.dispose_preview()


# --- 私有/辅助方法 ---

## 对共享上下文只订阅一次；信号不带来源引用，当前绑定决定可操作资格。
## [br]
## @api private
func _connect_context() -> void:
	if _context != null and not _context.changed.is_connected(_on_preview_context_changed):
		var _connected: int = _context.changed.connect(_on_preview_context_changed)
	if _config != null and not _config.changed.is_connected(_on_source_changed):
		var _connected: int = _config.changed.connect(_on_source_changed)


## 撤销本面板的上下文订阅，不释放其他 Inspector 控件仍持有的上下文及其目录订阅。
## [br]
## @api private
func _disconnect_context() -> void:
	if _context != null and _context.changed.is_connected(_on_preview_context_changed):
		_context.changed.disconnect(_on_preview_context_changed)
	if _config != null and _config.changed.is_connected(_on_source_changed):
		_config.changed.disconnect(_on_source_changed)


## 比较实际目标和初值资格，不把标签或来源兼容性变化当成重绑定。
## [br]
## @api private
func _target_identity(target: Dictionary) -> Dictionary:
	return {"id": target.get("id"), "kind": target.get("kind"), "adapter_id": target.get("adapter_id"),
		"initial_values": target.get("initial_values"), "lease": target.get("lease"),
		"binding_lease": target.get("binding_lease"), "revision": target.get("revision")}


## 更新可见选项和当前 ID；歧义有明确占位项，不暗中选择默认样机。
## [br]
## @api private
func _refresh_target_choices(target: Dictionary) -> void:
	var choices: Array[Dictionary] = []
	if _context != null:
		choices = _context.get_choices()
	_target_kind.set_block_signals(true)
	if choices != _choice_snapshot or _target_kind.item_count == 0:
		_choice_snapshot = choices.duplicate(true)
		_target_kind.clear()
		_target_kind.add_item("选择预览目标…")
		_target_kind.set_item_metadata(0, &"")
		_target_kind.set_item_disabled(0, true)
		for choice: Dictionary in choices:
			var target_label: String = choice["label"]
			var target_id: StringName = choice["id"]
			var reason: String = choice["reason"]
			_target_kind.add_item(target_label)
			var index: int = _target_kind.item_count - 1
			_target_kind.set_item_metadata(index, target_id)
			_target_kind.set_item_tooltip(index, reason)
	var selected_id: Variant = target.get("id", &"")
	_target_kind.select(0)
	for index: int in range(1, _target_kind.item_count):
		var choice_label: String = choices[index - 1]["label"]
		_target_kind.set_item_text(index, choice_label)
		if _target_kind.get_item_metadata(index) == selected_id:
			_target_kind.select(index)
			var label_value: Variant = target.get("label", choice_label)
			if label_value is String:
				var target_label: String = label_value
				_target_kind.set_item_text(index, target_label)
	_target_kind.set_block_signals(false)


## 重建真正改变身份的样机并同步全部初值；每个可能调用项目适配器的入口后复核绑定代次。
## [br]
## @api private
func _configure_context_target(target: Dictionary) -> bool:
	_binding_generation += 1
	var generation: int = _binding_generation
	_binding_identity = _target_identity(target).duplicate(true)
	_captured_source.clear()
	_captured_navigation.clear()
	var id_value: Variant = target.get("id", &"")
	if not id_value is StringName or id_value == &"":
		_viewport.dispose_preview()
		return false
	var adapter_value: Variant = target.get("adapter_id", &"")
	if adapter_value is StringName and adapter_value != &"":
		var adapter_id: StringName = adapter_value
		var configured: bool = _viewport.configure_adapter(_config, adapter_id, _context.get_registry())
		if not configured:
			return false
	else:
		var kind_value: Variant = target.get("kind", -1)
		if not kind_value is int:
			return false
		var kind: int = kind_value
		_viewport.configure(_config, kind)
	if not is_instance_valid(self) or not _owns_binding(generation):
		return false
	var initial_value: Variant = target.get("initial_values", {})
	if not initial_value is Dictionary:
		return false
	var initial_values: Dictionary = initial_value
	for key: Variant in initial_values:
		if not key is String:
			return false
		var property_name: String = key
		var applied: bool = _viewport.set_initial_value(StringName(property_name), initial_values[key])
		if not is_instance_valid(self) or not _owns_binding(generation) or not applied:
			return false
	return true


## 准备最新配置但不推进时钟；成功签名来自准备前，回调改写来源会立即显示为过期。
## [br]
## @api private
func _prepare_current() -> bool:
	if _disposed or not is_visible_in_tree() or _context == null or not _target_supported():
		return false
	if not _qualify_binding():
		return false
	var generation: int = _binding_generation
	var source_snapshot: Array = _SNAPSHOT_SCRIPT.capture(_config)
	var navigation: Dictionary = _context.get_navigation_snapshot()
	var source_scale: float = 0.0
	var scale_value: Variant = source_snapshot[0] if not source_snapshot.is_empty() else null
	if scale_value is float:
		source_scale = scale_value
	var prepared: bool = _viewport.prepare()
	if not is_instance_valid(self) or not _owns_binding(generation):
		return false
	if prepared:
		_captured_source = source_snapshot
		_captured_navigation = navigation
		_captured_scale = source_scale
		_last_tick_usec = Time.get_ticks_usec()
	_refresh_stale_state()
	_refresh_state()
	return prepared


## 只有当前可见生命周期与目标绑定仍有效时，旧回调才可继续更新工具控件。
## [br]
## @api private
func _owns_binding(generation: int) -> bool:
	return not _disposed and generation == _binding_generation and is_inside_tree() and not is_queued_for_deletion()


## 同步复核租约和绑定身份；失权先撤销旧会话，延后重解目录，拒绝本次旧控件动作。
## 目录查询可触发失效所有者通知，回调中较新的绑定不被旧撤销覆盖。
## [br]
## @api private
func _qualify_binding() -> bool:
	if _disposed or not is_visible_in_tree() or _context == null or not is_instance_valid(_viewport):
		return false
	var generation: int = _binding_generation
	var context: GFTweenPreviewContext = _context
	var current: bool = context.is_target_current()
	if not is_instance_valid(self) or not _owns_binding(generation) or _context != context:
		return false
	if current and not _binding_identity.is_empty() and _target_identity(context.get_target()) == _binding_identity:
		return true
	_binding_generation += 1
	var revoked_generation: int = _binding_generation
	_binding_identity.clear()
	_captured_source.clear()
	_captured_navigation.clear()
	_viewport.dispose_preview()
	if not is_instance_valid(self) or not _owns_binding(revoked_generation) or _context != context:
		return false
	_rebuild_time_controls()
	_rebuild_initial_fields()
	if not is_instance_valid(self) or not _owns_binding(revoked_generation) or _context != context:
		return false
	_refresh_stale_state()
	_refresh_state()
	context.refresh.call_deferred()
	return false


## 当前来源可用于新播放时返回 true；已冻结的旧会话仍可展示和定位。
## [br]
## @api private
func _target_supported() -> bool:
	if _context == null:
		return false
	var supported: Variant = _context.get_target().get("supported", false)
	return supported is bool and supported == true


## 继续暂停快照不读取已修改来源；尚未播放的 ready 和其他新播放仍须通过当前来源准入。
## [br]
## @api private
func _can_play() -> bool:
	if _binding_identity.is_empty() or _viewport.get_state() == &"playing":
		return false
	return (_viewport.get_state() == &"paused" and _viewport.has_session()) or _target_supported()


## 已定位或播放过的受控快照可改变方向；ready 不得借旧计划绕过当前无效来源。
## [br]
## @api private
func _can_change_direction() -> bool:
	return (
		not _binding_identity.is_empty() and _viewport.has_session() and _viewport.is_controlled_session()
		and (_viewport.get_state() != &"ready" or _target_supported())
	)


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
	_prepare_button = _add_button(direction_controls, "Recapture", "重新准备", _on_recapture_pressed)
	_prepare_button.tooltip_text = "捕获当前配置与初值并恢复准备状态，不开始播放。"
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
	_timeline.name = "StepTimeline"
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_scroll.add_child(_timeline)
	var _timeline_connected: int = _timeline.span_selected.connect(_on_timeline_span_selected.bind(_timeline))
	var duration_row: HBoxContainer = HBoxContainer.new()
	add_child(duration_row)
	var duration_caption: Label = Label.new()
	duration_caption.text = "完整总时长"
	duration_row.add_child(duration_caption)
	_target_seconds = SpinBox.new()
	_target_seconds.name = "TargetDurationSeconds"
	_target_seconds.min_value = 0.001
	_target_seconds.max_value = 120.0
	_target_seconds.step = 0.001
	_target_seconds.suffix = "s"
	_target_seconds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_seconds.tooltip_text = "包含延迟、串并行、循环和往返；通过一个 duration_scale 调整完整节奏。"
	duration_row.add_child(_target_seconds)
	_apply_duration = _add_button(duration_row, "ApplyDuration", "应用总时长", _on_apply_duration_pressed)
	_duration_feedback = Label.new()
	_duration_feedback.name = "DurationFeedback"
	_duration_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_duration_feedback.visible = false
	add_child(_duration_feedback)
	var _binding_button: Button = _add_button(self, "CopyBinding", "复制运行时绑定示例", _on_copy_binding_pressed)

	_status_label = Label.new()
	_status_label.name = "PreviewStatus"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)
	_error_location = _add_button(self, "LocateError", "定位错误字段", _on_error_location_pressed)
	_values_label = Label.new()
	_values_label.name = "PreviewValues"
	_values_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_values_label.visible = false
	var values_toggle: CheckButton = CheckButton.new()
	values_toggle.name = "ShowValues"
	values_toggle.text = "属性数值"
	var _values_connected: int = values_toggle.toggled.connect(_values_label.set_visible)
	add_child(values_toggle)
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
	hint.text = "点击时间块定位并选中步骤；修改后重新准备。"
	hint.tooltip_text = "选择目标后自动准备时间轴，可直接拖动或输入秒数定位。播放与定位使用同一冻结快照；配置修改不会打断播放，点击“重新准备”接纳新版本。步骤标记不发出通知。"
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
	_time_slider.tooltip_text = "定位准备好的快照并暂停，不读取后续配置修改。"
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
	_time_label.text = "/ %.3f s" % duration_seconds if has_session else "选择有效目标以准备时间轴"


## 根据视口的初始属性值重建编辑字段。
## [br]
## @api private
func _rebuild_initial_fields() -> void:
	var generation: int = _binding_generation
	for child: Node in _initial_fields.get_children():
		child.name = "RetiredInitialValue"
		if child is Control:
			var control: Control = child
			control.hide()
		child.queue_free()
	var values: Dictionary = _viewport.get_initial_values()
	var records: Array[Dictionary] = []
	if _context != null:
		records = _context.get_property_records()
	if not is_instance_valid(self) or not _owns_binding(generation):
		return
	for key: Variant in values:
		var property_name: StringName = StringName(str(key))
		var field: GFEditorValueField = GFEditorValueField.new()
		field.name = "Initial_%s" % property_name
		field.set_label(String(property_name))
		var info: Dictionary = {"name": property_name, "type": typeof(values[key])}
		for record: Dictionary in records:
			if record["name"] == String(property_name):
				info["hint"] = PROPERTY_HINT_RANGE
				info["hint_string"] = "%s,%s,%s" % [record["minimum"], record["maximum"], "1" if typeof(values[key]) == TYPE_INT else "0.001"]
		field.configure(info, values[key])
		var _value_connected: int = field.value_changed.connect(_on_initial_value_changed.bind(property_name, field, _binding_generation))
		_initial_fields.add_child(field)


## 按视口状态更新按钮和状态标签，并刷新属性值展示。
## [br]
## @api private
func _refresh_state() -> void:
	if _status_label == null or _disposed:
		return
	var state: StringName = _viewport.get_state()
	_play_button.text = "继续" if state == &"paused" else "播放"
	var supported: bool = _target_supported()
	_play_button.disabled = not _can_play()
	_prepare_button.disabled = _binding_identity.is_empty() or not supported
	_pause_button.disabled = state != &"playing"
	_forward_button.disabled = not _can_change_direction()
	_backward_button.disabled = not _can_change_direction()
	match state:
		&"ready":
			_status_label.text = "已准备，可播放或定位"
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
	if not supported:
		var target: Dictionary = _context.get_target() if _context != null else {}
		var reason_value: Variant = target.get("reason", "请选择预览目标。")
		if reason_value is String:
			var reason: String = reason_value
			if state == &"playing":
				_status_label.text = "播放中（旧快照）\n" + reason
			elif state == &"paused" and _viewport.has_session():
				_status_label.text = "已暂停（旧快照）\n" + reason
			else:
				_status_label.text = reason
	_refresh_values()
	_refresh_authoring_actions()


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
		var names: Array[StringName] = []
		var names_value: Variant = _captured_navigation.get("names")
		if names_value is Array:
			var captured_names: Array = names_value
			for value: Variant in captured_names:
				if value is StringName:
					var step_name: StringName = value
					names.append(step_name)
		_timeline.configure(_viewport.get_preview_plan(), names)
		_timeline.set_time_seconds(_viewport.get_time_seconds())


## 比较有界纯值签名；状态只作提示，不自动打断当前冻结会话。
## [br]
## @api private
func _refresh_stale_state() -> void:
	if _stale_label == null:
		return
	var stale: bool = _viewport.has_session() and _captured_source != _SNAPSHOT_SCRIPT.capture(_config)
	_stale_label.text = "预览已过期：配置已修改；当前画面使用旧快照。点击“重新准备”更新。" if stale else ""
	if not stale and _viewport.has_session() and _context != null and not _context.is_navigation_current(_captured_navigation):
		_stale_label.text = "来源步骤已替换或改名：时间块仍定位旧快照。重新准备后可联动当前步骤表单。"
	_refresh_authoring_actions()


## 总时长仅用于当前来源；错误位置只读取结构化字段，不解析面向作者的文本。
## [br]
## @api private
func _refresh_authoring_actions() -> void:
	if _duration_feedback != null:
		_duration_feedback.visible = not _duration_feedback.text.is_empty()
	if _apply_duration != null:
		_apply_duration.disabled = not _viewport.has_session() or _captured_source != _SNAPSHOT_SCRIPT.capture(_config) or not _target_supported() or _viewport.get_duration_seconds() <= 0.0
		_target_seconds.editable = not _apply_duration.disabled
		var plan: GFTweenPreviewPlan = _viewport.get_preview_plan()
		if plan != _duration_plan:
			_duration_plan = plan
			if not _apply_duration.disabled:
				_target_seconds.set_value_no_signal(_viewport.get_duration_seconds())
	if _error_location != null:
		var diagnostic: Dictionary = _context.get_diagnostic() if _context != null else {}
		var index_value: Variant = diagnostic.get("step_index", -1)
		var field_value: Variant = diagnostic.get("field", &"")
		_error_location.disabled = not index_value is int or index_value < 0 or not field_value is StringName or field_value == &""
		_error_location.visible = not _error_location.disabled


## 仅查找同一原生 Inspector 的根倍率属性；跳过属性子树和预览子树，最多检查 256 个容器。
## 嵌套原生提交保留实际属性刷新和历史归属，不通过全量 property-list 重建打断冻结预览。
## [br]
## @api private
func _duration_property() -> EditorProperty:
	var ancestor: Node = get_parent()
	while ancestor != null and not ancestor is EditorInspector:
		ancestor = ancestor.get_parent()
	if not ancestor is EditorInspector:
		return null
	var inspector: EditorInspector = ancestor
	if inspector.get_edited_object() != _config:
		return null
	var pending: Array[Node] = [inspector]
	var remaining: int = 256
	while not pending.is_empty() and remaining > 0:
		remaining -= 1
		var node: Node = pending.pop_back()
		if node is EditorProperty:
			var property: EditorProperty = node
			if property.get_edited_object() == _config and property.get_edited_property() == &"duration_scale":
				return property
			continue
		if node is GFTweenPreviewPanel:
			continue
		for child: Node in node.get_children():
			pending.append(child)
	return null


# --- 信号处理函数 ---

## 播放或继续预览，并在捕获新会话后更新时间控件。
## [br]
## @api private
func _on_play_pressed() -> void:
	if not _qualify_binding():
		return
	var generation: int = _binding_generation
	if _viewport.get_state() != &"paused" or not _viewport.has_session():
		_on_source_changed()
		if not is_instance_valid(self) or not _owns_binding(generation) or not _can_play():
			return
	if not _can_play() or not _qualify_binding():
		return
	var captures_new_session: bool = _viewport.get_state() not in [&"paused", &"ready"]
	var source_snapshot: Array = _SNAPSHOT_SCRIPT.capture(_config)
	var navigation: Dictionary = _context.get_navigation_snapshot()
	_last_tick_usec = Time.get_ticks_usec()
	var started: bool = _viewport.play()
	if not is_instance_valid(self) or not _owns_binding(generation):
		return
	if started and captures_new_session:
		_captured_source = source_snapshot
		_captured_navigation = navigation
		var scale_value: Variant = source_snapshot[0] if not source_snapshot.is_empty() else null
		if scale_value is float:
			_captured_scale = scale_value
		_rebuild_time_controls()
	_refresh_stale_state()


## 显式准备新快照，不把重新捕获当成播放操作。
## [br]
## @api private
func _on_recapture_pressed() -> void:
	if not _disposed:
		var _prepared: bool = _prepare_current()


## 只对受控快照切换方向。
## [br]
## @api private
func _on_direction_pressed(backward: bool) -> void:
	if not _qualify_binding():
		return
	var generation: int = _binding_generation
	if _viewport.get_state() == &"ready":
		_on_source_changed()
		if not is_instance_valid(self) or not _owns_binding(generation):
			return
	if not _can_change_direction() or not _qualify_binding():
		return
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
		var _prepared: bool = _prepare_current()
		_rebuild_time_controls()


## 把当前下拉框的 ID 交给共享上下文，面板与步骤目录一起改变。
## [br]
## @api private
func _on_target_kind_selected(index: int) -> void:
	if _disposed or _context == null or index < 1 or index >= _target_kind.item_count:
		return
	var value: Variant = _target_kind.get_item_metadata(index)
	if value is StringName:
		var target_id: StringName = value
		var _selected: bool = _context.select_target(target_id)


## 绑定身份变化撤销旧会话；未开始的 ready 自动更新合法来源，播放或定位后的冻结快照只提示过期。
## [br]
## @api private
func _on_preview_context_changed() -> void:
	if _disposed or _target_kind == null or _viewport == null:
		return
	var target: Dictionary = _context.get_target() if _context != null else {}
	_refresh_target_choices(target)
	if _target_identity(target) != _binding_identity:
		var generation: int = _binding_generation + 1
		var configured: bool = _configure_context_target(target)
		if not is_instance_valid(self) or not _owns_binding(generation):
			return
		_rebuild_time_controls()
		_rebuild_initial_fields()
		if configured:
			var _prepared: bool = _prepare_current()
	elif not _viewport.has_session() and _target_supported():
		var _prepared: bool = _prepare_current()
	elif _viewport.get_state() == &"ready" and _target_supported() and (_captured_source != _SNAPSHOT_SCRIPT.capture(_config) or _captured_navigation != _context.get_navigation_snapshot()):
		var _prepared: bool = _prepare_current()
	if not is_instance_valid(self) or _disposed:
		return
	_refresh_stale_state()
	_refresh_state()


## 来源发出编辑通知后刷新兼容性与准备状态；结果目录不变时也同步 ready 来源签名。
## [br]
## @api private
func _on_source_changed() -> void:
	if _disposed or _context == null:
		return
	_context.refresh()
	if is_instance_valid(self) and not _disposed:
		_on_preview_context_changed()


## 按切换状态显示或隐藏初始属性编辑器。
## [br]
## @api private
func _on_initial_values_toggled(pressed: bool) -> void:
	if not _disposed:
		_initial_fields.visible = pressed


## 更新样机初始属性；值无效时将字段恢复为当前初值。
## [br]
## @api private
func _on_initial_value_changed(value: Variant, property_name: StringName, field: GFEditorValueField, generation: int) -> void:
	if (
		not _owns_binding(generation) or _context == null or not is_instance_valid(field) or field.is_queued_for_deletion()
		or field.get_parent() != _initial_fields
	):
		return
	var accepted: bool = _context.set_initial_value(property_name, value)
	if not is_instance_valid(self) or not _owns_binding(generation):
		return
	if not accepted:
		field.set_value(_viewport.get_initial_values().get(property_name))
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
	if not _qualify_binding():
		return
	var generation: int = _binding_generation
	var _located: bool = _viewport.seek(time_seconds)
	if is_instance_valid(self) and _owns_binding(generation):
		_refresh_state()


## 将定位输入控件的当前数值交给时间变更处理函数。
## [br]
## @api private
func _on_inspect_time_pressed(source: SpinBox) -> void:
	if is_instance_valid(source):
		_on_time_changed(source.value, source)


## 时间块先定位同一冻结会话，再按作者身份选择表单；旧来源仍可定位但不会跳到新索引。
## [br]
## @api private
func _on_timeline_span_selected(index: int, time_seconds: float, plan: GFTweenPreviewPlan, source: Control) -> void:
	if _disposed or source != _timeline or not _viewport.has_session() or plan != _viewport.get_preview_plan() or not _qualify_binding():
		return
	var generation: int = _binding_generation
	var located: bool = _viewport.seek(time_seconds)
	if not is_instance_valid(self) or not _owns_binding(generation) or not located or plan != _viewport.get_preview_plan():
		return
	var context: GFTweenPreviewContext = _context
	if context != null:
		var _requested: bool = context.request_step_selection(index, &"property_name", _captured_navigation)
	if is_instance_valid(self) and _owns_binding(generation):
		_refresh_stale_state()
		_refresh_state()


## 纠错按钮交给共享上下文在同一次作者捕获内刷新诊断；不重建旧播放快照。
## [br]
## @api private
func _on_error_location_pressed() -> void:
	if _disposed or _context == null or not is_visible_in_tree() or not _qualify_binding():
		return
	var generation: int = _binding_generation
	var context: GFTweenPreviewContext = _context
	var _requested: bool = context.request_error_selection()
	if is_instance_valid(self) and _owns_binding(generation) and _context == context:
		_refresh_authoring_actions()


## 把同源计划换算的一个倍率作为原生离散动作提交；准备和定位本身不会改变资源。
## [br]
## @api private
func _on_apply_duration_pressed() -> void:
	if _disposed or _context == null or not _qualify_binding():
		return
	var generation: int = _binding_generation
	var result: Dictionary = _DURATION_SCRIPT.calculate(_viewport.get_preview_plan(), _captured_scale, _captured_source, _SNAPSHOT_SCRIPT.capture(_config), _target_seconds.value)
	var accepted_value: Variant = result.get("ok")
	if not accepted_value is bool or accepted_value != true:
		_duration_feedback.text = "无法换算总时长；原配置未改动。"
		var error_value: Variant = result.get("error")
		if error_value is String:
			var error_text: String = error_value
			if not error_text.is_empty():
				_duration_feedback.text = error_text
		_duration_feedback.show()
		return
	var scale_value: Variant = result.get("duration_scale")
	var next_scale: float = 0.0
	if scale_value is float:
		next_scale = scale_value
	elif scale_value is int:
		var integer_scale: int = scale_value
		next_scale = float(integer_scale)
	if not is_finite(next_scale) or next_scale <= 0.0:
		_duration_feedback.text = "换算结果的倍率无效；原配置未改动。"
		_duration_feedback.show()
		return
	if not Engine.is_editor_hint():
		_duration_feedback.text = "请在原生 Inspector 中提交总时长。"
		_duration_feedback.show()
		return
	var property: EditorProperty = _duration_property()
	if property == null:
		_duration_feedback.text = "当前 Inspector 的时长倍率字段不可用，原配置未改动。"
		_duration_feedback.show()
		return
	var undo_manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if undo_manager == null or undo_manager.is_committing_action() or not _owns_binding(generation):
		_duration_feedback.text = "请在原生 Inspector 中提交总时长；当前历史不可用。"
		_duration_feedback.show()
		return
	var config: Resource = _config
	undo_manager.create_action("调整 GF Tween 总时长", UndoRedo.MERGE_DISABLE, config)
	property.emit_changed(&"duration_scale", next_scale)
	undo_manager.add_do_method(config, &"emit_changed")
	undo_manager.add_undo_method(config, &"emit_changed")
	undo_manager.commit_action()
	if is_instance_valid(self) and _owns_binding(generation):
		_duration_feedback.text = "总时长已提交；播放中的旧快照仍保持冻结。"
		_refresh_authoring_actions()


## 面板隐藏时重置预览并重建时间控件状态。
## [br]
## @api private
func _on_visibility_changed() -> void:
	if _disposed or _viewport == null:
		return
	if not is_visible_in_tree():
		_viewport.reset_preview()
		_rebuild_time_controls()
	else:
		_on_preview_context_changed()
