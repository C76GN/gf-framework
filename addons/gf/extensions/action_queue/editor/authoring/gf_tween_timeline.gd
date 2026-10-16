@tool

# 冻结预览的步骤时间条；每一行对应来源步骤，循环和回程使用真实秒数。
extends Control


# --- 信号 ---

## 点击仍属于冻结计划的时间块；面板复核计划、租约和作者来源后分别定位与选择步骤。
## [br]
## @api framework_internal
## [br]
## @param step_index: 冻结计划的零基步骤索引。
## [br]
## @param time_seconds: 点击位置对应的实际秒数。
## [br]
## @param plan: 发出事件时的冻结计划身份。
signal span_selected(
	step_index: int,
	time_seconds: float,
	plan: GFTweenPreviewPlan
)


# --- 私有变量 ---

## 持有当前会话的冻结计划；同一对象再次配置时不会重建区段，调用方不得原地修改它。
## [br]
## @api private
var _plan: GFTweenPreviewPlan = null

## 根据计划展开的前进、回程与循环区段；更换计划时整体替换，不读取来源资源。
## [br]
## @api private
var _spans: Array[Dictionary] = []

## 当前会话的实际秒数，只控制游标绘制，不推进计划或触发步骤通知。
## [br]
## @api private
var _time_seconds: float = 0.0

## 仅用于显示的冻结名称，不参与执行计划或播放签名。
## [br]
## @api private
var _names: Array[StringName] = []

## 当前选中时间块的步骤；更换计划时清除高亮，不向来源写入。
## [br]
## @api private
var _selected: int = -1


# --- Godot 生命周期方法 ---

## 输入只来自此控件的原生 GUI 信号；离树事件仍由处理入口拒绝。
## [br]
## @api private
func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	var _connected: int = gui_input.connect(_on_gui_input)


# --- Godot 回调方法 ---

## 按冻结计划时长绘制循环与回程区段，再叠加当前时间游标；空计划不绘制。
## [br]
## @api private
func _draw() -> void:
	if _plan == null:
		return
	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_default_font_size()
	var foreground: Color = get_theme_color(&"font_color", &"Label")
	var accent: Color = get_theme_color(&"accent_color", &"Editor")
	if accent.a == 0.0:
		accent = foreground
	var left: float = 82.0
	var width: float = maxf(
		1.0,
		size.x - left - 8.0
	)
	var duration: float = maxf(0.001, _plan.duration_seconds)
	for index: int in range(_plan.steps.size()):
		var y: float = float(index) * 23.0
		var caption: String = "%d" % (index + 1)
		if index < _names.size() and _names[index] != &"":
			caption += " · " + _display_name(index, 64)
		draw_string(
			font,
			Vector2(
				2.0,
				y + 16.0
			),
			caption,
			HORIZONTAL_ALIGNMENT_LEFT,
			76.0,
			font_size,
			foreground
		)
		draw_line(
			Vector2(
				left,
				y + 18.0
			),
			Vector2(
				left + width,
				y + 18.0
			),
			Color(foreground, 0.15)
		)
	for span: Dictionary in _spans:
		var index: int = span["index"]
		var reverse: bool = span["reverse"]
		var color: Color = Color(
			accent,
			0.45 if reverse else 0.85
		)
		var rect: Rect2 = _span_rect(span)
		draw_rect(rect, color)
		if index == _selected:
			draw_rect(
				rect.grow(1.0),
				foreground,
				false,
				1.0
			)
	var cursor: float = left + _time_seconds / duration * width
	draw_line(
		Vector2(cursor, 0.0),
		Vector2(cursor, size.y),
		foreground,
		1.0
	)


# --- 框架内部方法 ---

## 替换冻结时间轴；同一计划只更新时间，不重复编译区段。
## [br]
## @api framework_internal
## [br]
## @param plan: 当前冻结的只读计划；null 清除时间条。
## [br]
## @param step_names: 与计划步骤对应的显示名称；最多 128 项，不写入计划。
func configure(plan: GFTweenPreviewPlan, step_names: Array[StringName] = []) -> void:
	if plan == _plan and step_names == _names:
		return
	if plan != _plan:
		_selected = -1
	_plan = plan
	_names = step_names.slice(0, 128)
	_spans = build_spans(plan)
	custom_minimum_size = Vector2(
		220.0,
		float(plan.steps.size()) * 23.0 if plan != null else 0.0
	)
	queue_redraw()


## 同步当前会话的实际秒数。
## [br]
## @api framework_internal
## [br]
## @param value: 当前会话时间，单位为秒。
func set_time_seconds(value: float) -> void:
	if value != _time_seconds:
		_time_seconds = value
		queue_redraw()


## 按串并行组和循环展开真实时间区段；不读取来源资源。
## [br]
## @api framework_internal
## [br]
## @param plan: 已通过预览准入的冻结计划。
## [br]
## @return: 完整循环与回程区段；null 返回空数组。
## [br]
## @schema return: Array[Dictionary]，每项包含 index/group/loop: int（index 为零基，组和循环为一基）、property_name: NodePath、start/duration: float 秒数、reverse: bool。
static func build_spans(plan: GFTweenPreviewPlan) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if plan == null:
		return result
	var cycle: Array[Dictionary] = []
	var start: float = 0.0
	var group_duration: float = 0.0
	var group: int = 1
	for index: int in range(plan.steps.size()):
		var step: Dictionary = plan.steps[index]
		var parallel: bool = step["parallel"]
		if index > 0 and not parallel:
			start += group_duration
			group_duration = 0.0
			group += 1
		var delay: float = step["delay"]
		var duration: float = step["duration"]
		cycle.append(
			{
				"index": index,
				"group": group,
				"loop": 1,
				"property_name": step["property_name"],
				"start": start + delay,
				"duration": duration,
				"reverse": false,
			}
		)
		group_duration = maxf(
			group_duration,
			delay + duration
		)
	var cycle_duration: float = start + group_duration
	var loops: int = plan.loop_count if cycle_duration > 0.0 else 1
	for loop_index: int in range(loops):
		var offset: float = float(loop_index) * cycle_duration * (2.0 if plan.ping_pong else 1.0)
		for source: Dictionary in cycle:
			var forward: Dictionary = source.duplicate()
			var source_start: float = source["start"]
			var source_duration: float = source["duration"]
			forward["start"] = offset + source_start
			forward["loop"] = loop_index + 1
			result.append(forward)
			if plan.ping_pong:
				result.append(
					{
						"index": source["index"],
						"group": source["group"],
						"loop": loop_index + 1,
						"property_name": source["property_name"],
						"start": offset + cycle_duration * 2.0 - source_start - source_duration,
						"duration": source_duration,
						"reverse": true,
					}
				)
	return result


# --- 私有/辅助方法 ---

## 悬停说明来自冻结纯值；循环和回程区段均显示本次实际起止秒数。
## [br]
## @api private
func _get_tooltip(at_position: Vector2) -> String:
	var span: Dictionary = _span_at(at_position)
	if span.is_empty() or _plan == null:
		return ""
	var index: int = span["index"]
	var property_name: NodePath = span["property_name"]
	var loop_index: int = span["loop"]
	var group: int = span["group"]
	var start: float = span["start"]
	var duration: float = span["duration"]
	var reverse: bool = span["reverse"]
	var caption: String = "步骤 %d" % (index + 1)
	if index < _names.size() and _names[index] != &"":
		caption += " · " + _display_name(index, 40)
	var property_text: String = String(property_name)
	if property_text.length() > 64:
		property_text = property_text.left(64) + "…"
	var text: String = (
		"%s\n%s · 组 %d · 循环 %d · %s\n%.3f–%.3f s（%.3f s）\n点击定位；来源仍一致时同步选中步骤。"
		% [
			caption,
			property_text,
			group,
			loop_index,
			"反向" if reverse else "正向",
			start,
			start + duration,
			duration,
		]
	)
	return text.left(255) + "…" if text.length() > 256 else text


## 名称显示有限前缀并标明省略，不把截断文本用于作者身份比较。
## [br]
## @api private
func _display_name(index: int, limit: int) -> String:
	var value: String = String(_names[index])
	return value.left(limit) + "…" if value.length() > limit else value


## 绘制和命中测试共享同一矩形，零时长块保留两像素的可观察入口。
## [br]
## @api private
func _span_rect(span: Dictionary) -> Rect2:
	var index: int = span["index"]
	var start: float = span["start"]
	var duration: float = span["duration"]
	var total: float = maxf(0.001, _plan.duration_seconds)
	var width: float = maxf(
		1.0,
		size.x - 90.0
	)
	return Rect2(
		82.0 + start / total * width,
		float(index) * 23.0 + 3.0,
		maxf(
			2.0,
			duration / total * width
		),
		14.0
	)


## 只返回当前冻结区段，不因点击空白区域猜测一个来源步骤。
## [br]
## @api private
func _span_at(point: Vector2) -> Dictionary:
	if _plan == null or not Rect2(Vector2.ZERO, size).has_point(point):
		return {}
	for span: Dictionary in _spans:
		if _span_rect(span).has_point(point):
			return span
	return {}


# --- 信号处理函数 ---

## 左键时间块只交付定位意图；接收者负责较新会话和来源资格，控件离树时不再交付。
## [br]
## @api private
func _on_gui_input(event: InputEvent) -> void:
	if (
		not is_inside_tree()
		or is_queued_for_deletion()
		or not event is InputEventMouseButton
	):
		return
	var button_event: InputEventMouseButton = event
	if not button_event.pressed or button_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var span: Dictionary = _span_at(button_event.position)
	if span.is_empty() or _plan == null:
		return
	var index: int = span["index"]
	var start: float = span["start"]
	var length: float = span["duration"]
	var rect: Rect2 = _span_rect(span)
	var fraction: float = clampf(
		(button_event.position.x - rect.position.x) / rect.size.x,
		0.0,
		1.0
	)
	var seconds: float = start + length * fraction
	_selected = index
	queue_redraw()
	accept_event()
	span_selected.emit(
		index,
		seconds,
		_plan
	)
