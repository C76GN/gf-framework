@tool

# 显示当前配方的页时钟和目标区间。样机只操作工具创建的节点。
extends VBoxContainer


# --- 常量 ---

## 可以在本工具创建的控件上独立运行的采样脚本。
## [br]
## @api private
const _PREVIEW_EFFECTS: Array[String] = [
	"res://addons/gf/extensions/action_queue/ui_motion/gf_ui_property_motion.gd",
	"res://addons/gf/extensions/action_queue/ui_motion/gf_ui_material_motion.gd",
	"res://addons/gf/extensions/action_queue/ui_motion/gf_ui_layout_motion.gd",
]

## 每个面板都使用独立的双页样机。
## [br]
## @api private
const _STAGE = preload("res://addons/gf/extensions/action_queue/editor/preview/gf_ui_motion_preview_stage.gd")


# --- 公共变量 ---

## 可另存或在 Inspector 中修改的原生配方。
## [br]
## @api framework_internal
var recipe: GFUIMotionRecipe


# --- 私有变量 ---

## 已绑定的页面与局部轨道，双击时跳到其起始位置。
## [br]
## @api private
var _timeline: ItemList

## 按实际总秒数定位。
## [br]
## @api private
var _time: HSlider

## 显示绑定和预览结果。
## [br]
## @api private
var _status: Label

## 持有运行中样机。
## [br]
## @api private
var _stage: _STAGE

## 用于显示实播进度并阻止反向派发 slider 回调。
## [br]
## @api private
var _syncing: bool = false


# --- Godot 生命周期方法 ---

func _ready() -> void:
	set_process(false)
	var bar: HFlowContainer = HFlowContainer.new()
	add_child(bar)
	for entry: Array in [
		["播放", _play],
		["暂停", _pause],
		["继续", _resume],
	]:
		var button: Button = Button.new()
		button.text = str(entry[0])
		var callback: Callable = entry[1]
		var _pressed: int = button.pressed.connect(callback)
		bar.add_child(button)
	_stage = _STAGE.new()
	_stage.custom_minimum_size = Vector2(180, 176)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_stage)
	var order: OptionButton = OptionButton.new()
	order.tooltip_text = "样机页面叠放"
	for label: String in [
		"自动叠放",
		"旧页在前",
		"新页在前",
	]:
		order.add_item(label)
	bar.add_child(order)
	var _selected_order: int = order.item_selected.connect(_stage.set_page_order)
	_time = HSlider.new()
	_time.step = 0.001
	add_child(_time)
	var _seeked: int = _time.value_changed.connect(_seek)
	_timeline = ItemList.new()
	_timeline.custom_minimum_size.y = 76
	_timeline.tooltip_text = "每个目标的起止时刻；双击可定位"
	add_child(_timeline)
	var _selected: int = _timeline.item_activated.connect(_locate)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	open_recipe(GFUIMotionRecipe.new())


func _process(_delta: float) -> void:
	if is_instance_valid(_stage) and _stage.player != null:
		_syncing = true
		_time.value = _stage.player.get_time_seconds()
		_syncing = false
		if not _stage.player.is_active():
			set_process(false)


# --- 框架内部方法 ---

## 打开原生配方。工具不在编辑器进程执行项目自定义扩展，真实场景可从对照工具运行。
## [br]
## @api framework_internal
## [br]
## @param value: 当前配方。
func open_recipe(value: GFUIMotionRecipe) -> void:
	if recipe != null and recipe.changed.is_connected(_refresh):
		recipe.changed.disconnect(_refresh)
	recipe = value
	if recipe != null:
		var _changed: int = recipe.changed.connect(_refresh)
	_refresh()


# --- 私有/辅助方法 ---

## 重建当前配方在样机上的实际绑定，撤销轨道修改后同步清理显示。
## [br]
## @api private
func _refresh() -> void:
	if _admitted():
		_stage.show()
		_show(true)
	else:
		_stage.player.cancel()
		_time.editable = false
		_stage.hide()
		_timeline.clear()
		set_process(false)


## 在编辑器样机只运行本工具自有的采样脚本；正式运行场景由项目显式提供绑定。
## [br]
## @api private
func _admitted() -> bool:
	if recipe == null or recipe.tracks.is_empty():
		_status.text = "添加轨道后可在样机上预览。"
		return false
	if Engine.is_editor_hint():
		var recipe_script: Script = recipe.get_script()
		if recipe_script.resource_path != "res://addons/gf/extensions/action_queue/ui_motion/gf_ui_motion_recipe.gd":
			_status.text = "项目配方请使用真实场景对照"
			return false
		for track: GFUIMotionTrack in recipe.tracks:
			if track != null:
				var track_script: Script = track.get_script()
				if track_script.resource_path == "res://addons/gf/extensions/action_queue/ui_motion/gf_ui_motion_track.gd":
					if track.effect == null:
						continue
					var effect_script: Script = track.effect.get_script()
					if effect_script.resource_path in _PREVIEW_EFFECTS:
						continue
			_status.text = "此配方需要项目场景与绑定，请使用真实场景对照"
			return false
	return true


## 从同一资源建立一个可播放或冻结的会话。
## [br]
## @api private
func _show(paused: bool) -> void:
	var error: Error = _stage.present(recipe, paused)
	var source: String = recipe.resource_path if not recipe.resource_path.is_empty() else "尚未保存的配方"
	var identity: String = (
		"%s（当前编辑值）\n%s"
		% [source, _stage.binding_summary]
	)
	if error != OK:
		_status.text = identity + "\n" + _stage.player.get_diagnostic() + "。项目专用目标可在真实页面对照中运行。"
		_timeline.clear()
		_time.editable = false
		set_process(false)
		return
	_syncing = true
	_time.max_value = _stage.player.get_duration_seconds()
	_time.value = _stage.player.get_time_seconds()
	_syncing = false
	_timeline.clear()
	for interval: Dictionary in _stage.player.get_track_intervals():
		var track: GFUIMotionTrack = recipe.tracks[interval.track_index]
		var title: String = (
			"%s    %.3f – %.3f s"
			% [
				track.target,
				interval.start_seconds,
				interval.end_seconds,
			]
		)
		var index: int = _timeline.add_item(title)
		_timeline.set_item_metadata(index, interval.start_seconds)
	set_process(not paused)
	_time.editable = _stage.player.can_seek()
	_status.text = (
		"%s　·　%.3f s"
		% [identity, _time.max_value]
	)


## 重新捕获编辑中的配方参数。
## [br]
## @api private
func _play() -> void:
	if _admitted():
		_stage.show()
		_show(false)


## 定位到选定目标实际开始的时间。
## [br]
## @api private
func _locate(index: int) -> void:
	if _time.editable:
		_time.value = _timeline.get_item_metadata(index)


## 同时暂停样机的局部读数时钟。
## [br]
## @api private
func _pause() -> void:
	_stage.player.pause()
	_stage.set_process(false)
	set_process(false)


## 继续实播，结束态则从头启动。
## [br]
## @api private
func _resume() -> void:
	if not _stage.player.is_active():
		_play()
	else:
		_stage.set_process(true)
		set_process(true)
		_stage.player.resume()


## 拖动时按当前秒数重建外层与局部姿态。
## [br]
## @api private
func _seek(seconds: float) -> void:
	if _syncing or not _admitted():
		return
	if not _stage.player.is_active():
		_show(true)
	if _stage.player.seek(seconds):
		set_process(false)
		_stage.set_process(false)
		_stage.set_fixture_time(seconds)
