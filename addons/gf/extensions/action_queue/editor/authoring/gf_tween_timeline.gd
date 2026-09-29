@tool

# 冻结预览的步骤时间条；每一行对应来源步骤，循环和回程使用真实秒数。
extends Control


# --- 私有变量 ---

var _plan: GFTweenPreviewPlan = null
var _spans: Array[Dictionary] = []
var _time_seconds: float = 0.0


# --- Godot 回调方法 ---

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
	var width: float = maxf(1.0, size.x - left - 8.0)
	var duration: float = maxf(0.001, _plan.duration_seconds)
	for index: int in range(_plan.steps.size()):
		var y: float = float(index) * 23.0
		draw_string(font, Vector2(2.0, y + 16.0), "%d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, 76.0, font_size, foreground)
		draw_line(Vector2(left, y + 18.0), Vector2(left + width, y + 18.0), Color(foreground, 0.15))
	for span: Dictionary in _spans:
		var index: int = span["index"]
		var start: float = span["start"]
		var length: float = span["duration"]
		var reverse: bool = span["reverse"]
		var color: Color = Color(accent, 0.45 if reverse else 0.85)
		draw_rect(Rect2(left + start / duration * width, float(index) * 23.0 + 3.0, maxf(2.0, length / duration * width), 14.0), color)
	var cursor: float = left + _time_seconds / duration * width
	draw_line(Vector2(cursor, 0.0), Vector2(cursor, size.y), foreground, 1.0)


# --- 框架内部方法 ---

## 替换冻结时间轴；同一计划只更新时间，不重复编译区段。
## [br]
## @api framework_internal
## [br]
## @param plan: 当前冻结的只读计划；null 清除时间条。
func configure(plan: GFTweenPreviewPlan) -> void:
	if plan == _plan:
		return
	_plan = plan
	_spans = build_spans(plan)
	custom_minimum_size = Vector2(220.0, float(plan.steps.size()) * 23.0 if plan != null else 0.0)
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
## @schema return: Array[Dictionary]，每项包含 index: int、start/duration: float 秒数、reverse: bool。
static func build_spans(plan: GFTweenPreviewPlan) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if plan == null:
		return result
	var cycle: Array[Dictionary] = []
	var start: float = 0.0
	var group_duration: float = 0.0
	for index: int in range(plan.steps.size()):
		var step: Dictionary = plan.steps[index]
		var parallel: bool = step["parallel"]
		if index > 0 and not parallel:
			start += group_duration
			group_duration = 0.0
		var delay: float = step["delay"]
		var duration: float = step["duration"]
		cycle.append({"index": index, "start": start + delay, "duration": duration, "reverse": false})
		group_duration = maxf(group_duration, delay + duration)
	var cycle_duration: float = start + group_duration
	var loops: int = plan.loop_count if cycle_duration > 0.0 else 1
	for loop_index: int in range(loops):
		var offset: float = float(loop_index) * cycle_duration * (2.0 if plan.ping_pong else 1.0)
		for source: Dictionary in cycle:
			var forward: Dictionary = source.duplicate()
			var source_start: float = source["start"]
			var source_duration: float = source["duration"]
			forward["start"] = offset + source_start
			result.append(forward)
			if plan.ping_pong:
				result.append({"index": source["index"], "start": offset + cycle_duration * 2.0 - source_start - source_duration, "duration": source_duration, "reverse": true})
	return result
