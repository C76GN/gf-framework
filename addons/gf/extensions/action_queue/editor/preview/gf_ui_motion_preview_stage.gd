@tool

# 双页和局部组件的独立样机。按配方实际使用的输入创建视口，所有场景节点均归本样机。
extends Control


# --- 公共变量 ---

## 两个显示通道可各自冻结首帧，默认保留新页实时变化。
## [br]
## @api framework_internal
var freeze_old: bool = true

## 为对照冻结新页，实时演示时为 false。
## [br]
## @api framework_internal
var freeze_new: bool = false

## 用于工具检查、定位和实播的有限会话。
## [br]
## @api framework_internal
var player: GFUIMotionPlayer

## 当前配方要求的目标与输入，在首次采样前建立。
## [br]
## @api framework_internal
var binding_summary: String = ""


# --- 私有变量 ---

## 一次样机挂载的所有场景内容。
## [br]
## @api private
var _body: Control

## 样机的旧页与新页显示节点。
## [br]
## @api private
var _pages: Array[Control] = []

## 合成期间按需持有的离屏输入。
## [br]
## @api private
var _views: Array[SubViewport] = []

## 项目式具名显示目标，随新样机重建。
## [br]
## @api private
var _targets: Dictionary = {}

## 本轮实测布局及纹理。
## [br]
## @api private
var _inputs: Dictionary = {}

## 新页的原生进度条。由轨道绑定时交给配方驱动。
## [br]
## @api private
var _indicator: ProgressBar

## 作者在样机里选择的叠放顺序，0 为自动、1 为旧页在前、2 为新页在前。
## [br]
## @api private
var _page_order: int = 0

## 配方单独编辑退场时，默认以旧页为前景。
## [br]
## @api private
var _preview_exit: bool = false

## 当前用于实播的局部时间。
## [br]
## @api private
var _seconds: float = 0.0


# --- Godot 生命周期方法 ---

func _ready() -> void:
	clip_contents = true
	player = GFUIMotionPlayer.new()
	add_child(player)
	var _ended: int = player.ended.connect(_on_ended)
	var _resized: int = resized.connect(_resize_views)
	set_process(false)


func _process(delta: float) -> void:
	_seconds += delta
	set_fixture_time(_seconds)


# --- 框架内部方法 ---

## 在自有节点上装配一个完整配方，选择直接或像素路径。
## [br]
## @api framework_internal
## [br]
## @param recipe: 待预览配方。
## [br]
## @param paused: 保留初始可定位画面。
## [br]
## @return: 绑定或启动错误码。
func present(recipe: GFUIMotionRecipe, paused: bool = false) -> Error:
	if player == null or recipe == null:
		return ERR_UNCONFIGURED
	player.cancel()
	if is_instance_valid(_body):
		remove_child(_body)
		_body.queue_free()
	_pages.clear()
	_views.clear()
	_targets = {}
	_inputs = {}
	_seconds = 0.0
	_body = Control.new()
	add_child(_body)
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var roles: Array[StringName] = []
	for track: GFUIMotionTrack in recipe.tracks:
		if track != null:
			if not roles.has(track.target):
				roles.append(track.target)
	var pixel: bool = roles.has(&"composite")
	for i: int in 2:
		var parent: Node = _body
		if pixel:
			var view: SubViewport = SubViewport.new()
			view.disable_3d = true
			view.transparent_bg = false
			var frozen: bool = freeze_old if i == 0 else freeze_new
			view.render_target_update_mode = SubViewport.UPDATE_ONCE if frozen else SubViewport.UPDATE_ALWAYS
			_body.add_child(view)
			_views.append(view)
			view.size = Vector2i(size).max(Vector2i.ONE)
			parent = view
			_inputs[&"old_texture" if i == 0 else &"new_texture"] = view.get_texture()
		var page: Control = _make_page(
			parent,
			i == 1
		)
		_pages.append(page)
		_targets[&"outgoing" if i == 0 else &"incoming"] = page
	_preview_exit = roles.has(&"outgoing") and not roles.has(&"incoming")
	set_page_order(_page_order)
	if pixel:
		var destination: TextureRect = TextureRect.new()
		_body.add_child(destination)
		destination.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		destination.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		destination.texture = _views[1].get_texture()
		destination.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_targets[&"composite"] = _panel(
			_body,
			Rect2(
				0,
				0,
				1,
				1
			),
			Color.WHITE
		)
	if roles.has(&"cover"):
		_targets[&"cover"] = _panel(
			_body,
			Rect2(
				0,
				0,
				1,
				1
			),
			Color.TRANSPARENT
		)
	if roles.has(&"meter"):
		_targets[&"meter"] = _indicator
	var bound: Array[String] = []
	var missing: Array[String] = []
	for role: StringName in roles:
		if _targets.has(role):
			bound.append(role)
		else:
			missing.append(role)
	var slots: Dictionary = {}
	for track: GFUIMotionTrack in recipe.tracks:
		if track != null and track.effect != null:
			slots.merge(track.effect.input_types())
	for slot: Variant in slots:
		var label: String = "输入 " + str(slot)
		if _inputs.has(slot):
			bound.append(label)
		else:
			missing.append(label)
	binding_summary = "已绑定 " + "、".join(PackedStringArray(bound))
	if not missing.is_empty():
		binding_summary += "　缺少 " + "、".join(PackedStringArray(missing))
	_resize_views()
	set_fixture_time(0.0)
	var result: Error = player.play(
		recipe,
		_targets,
		_inputs,
		paused
	)
	set_process(result == OK and not paused)
	return result


## 只在两张直接绘制的样机页面之间调整叠放，保留当前时间、遮罩和像素输入。
## [br]
## @api framework_internal
## [br]
## @param order: 0 为自动、1 为旧页在前、2 为新页在前。
func set_page_order(order: int) -> void:
	_page_order = order
	if _pages.size() != 2 or not _views.is_empty():
		return
	var auto_exit: bool = order == 0 and _preview_exit
	var front: Control = _pages[0] if order == 1 or auto_exit else _pages[1]
	_body.move_child(
		front,
		maxi(
			_pages[0].get_index(),
			_pages[1].get_index()
		)
	)


## 推进独立新页内容；定位时传入相同秒数可重建读数。
## [br]
## @api framework_internal
## [br]
## @param seconds: 样机局部时钟。
func set_fixture_time(seconds: float) -> void:
	_seconds = seconds
	if is_instance_valid(_indicator) and not _targets.has(&"meter"):
		_indicator.value = 16.0 + 78.0 * fmod(
			maxf(seconds, 0.0) * 1.43,
			1.0
		)


## 返回供图形和资源回收检查使用的视口数量。
## [br]
## @api framework_internal
## [br]
## @return: 当前样机拥有的离屏输入数。
func viewport_count() -> int:
	return _views.size()


# --- 私有/辅助方法 ---

## 创建供轨道绑定的页面、标题、列表与进度条。
## [br]
## @api private
func _make_page(parent: Node, incoming: bool) -> Control:
	var page: ColorRect = _panel(
		parent,
		Rect2(
			0,
			0,
			1,
			1
		),
		Color("#142d3b") if incoming else Color("#302338")
	)
	var accent: Color = Color("#91d7c6") if incoming else Color("#f1bba2")
	var heading: Label = _caption(
		page,
		Rect2(
			0.085,
			0.075,
			0.83,
			0.18
		),
		tr("入场页") if incoming else tr("退场页"),
		27
	)
	var items: Array[Control] = []
	var x: float = 0.10 if incoming else 0.075
	for index: int in 3:
		var row: ColorRect = _panel(
			page,
			Rect2(
				x,
				0.32 + index * 0.155,
				0.81,
				0.115
			),
			accent.darkened(0.64)
		)
		var _label: Label = _caption(
			row,
			Rect2(
				0.06,
				0,
				0.9,
				1
			),
			tr("列表项 %d") % (index + 1),
			17
		)
		items.append(row)
	if incoming:
		_targets[&"rows"] = items
		_targets[&"title"] = heading
		_indicator = ProgressBar.new()
		page.add_child(_indicator)
		_position(
			_indicator,
			Rect2(
				0.10,
				0.84,
				0.81,
				0.052
			)
		)
		_indicator.show_percentage = false
		_indicator.step = 0.01
	return page


## 所有空间均从真实父控件的布局得到。
## [br]
## @api private
func _position(node: Control, rect: Rect2) -> void:
	node.anchor_left = rect.position.x
	node.anchor_top = rect.position.y
	node.anchor_right = rect.end.x
	node.anchor_bottom = rect.end.y
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0
	node.pivot_offset = node.size * 0.5
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE


## 创建单一平面，由所属内容根统一释放。
## [br]
## @api private
func _panel(
	parent: Node,
	bounds: Rect2,
	color: Color
) -> ColorRect:
	var node: ColorRect = ColorRect.new()
	node.color = color
	parent.add_child(node)
	_position(node, bounds)
	return node


## 使用 Label 展示状态文本并允许窗口变化后重新排版。
## [br]
## @api private
func _caption(
	parent: Control,
	bounds: Rect2,
	title: String,
	points: int
) -> Label:
	var label: Label = Label.new()
	parent.add_child(label)
	_position(label, bounds)
	label.text = title
	label.add_theme_font_size_override(&"font_size", points)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## 树退出和重新挂载也会取消播放，延后移动子节点，并验证样机仍是原实例。
## [br]
## @api private
func _settle_views(body_id: int, selected: int) -> void:
	if not is_inside_tree() or not is_instance_valid(_body):
		return
	if _body.get_instance_id() != body_id or _views.is_empty():
		return
	_pages[selected].reparent(_body, false)
	_pages[selected].set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.move_child(
		_pages[selected],
		0
	)
	var panel: CanvasItem = _targets[&"composite"]
	panel.hide()
	for view: SubViewport in _views:
		_body.remove_child(view)
		view.queue_free()
	_views.clear()
	_pages = [_pages[selected]]
	_inputs.clear()
	for child: Node in _body.get_children():
		if child is TextureRect:
			child.queue_free()


## 在真实窗口变化时更新像素输入，而普通动作直接采用 Control 布局。
## [br]
## @api private
func _resize_views() -> void:
	for view: SubViewport in _views:
		var pixels: Vector2i = Vector2i(size).max(Vector2i.ONE)
		if view.size != pixels:
			view.size = pixels
			if view.render_target_update_mode == SubViewport.UPDATE_DISABLED:
				view.render_target_update_mode = SubViewport.UPDATE_ONCE
	for page: Control in _pages:
		page.pivot_offset = page.size * 0.5


# --- 信号处理函数 ---

## 转场退出后将样机拥有的新页交还直接显示并释放离屏输入。
## [br]
## @api private
func _on_ended(reason: GFUIMotionBinding.EndReason) -> void:
	set_process(false)
	if _pages.size() != 2:
		return
	var selected: int = 0 if reason == GFUIMotionBinding.EndReason.CANCELLED else 1
	_pages[1 - selected].hide()
	if not _views.is_empty():
		_settle_views.call_deferred(
			_body.get_instance_id(),
			selected
		)
