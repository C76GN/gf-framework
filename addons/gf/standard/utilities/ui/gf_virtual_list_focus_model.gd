## GFVirtualListFocusModel: 虚拟列表焦点索引模型。
##
## 用数据索引维护虚拟焦点，供回收式列表、长日志、资源浏览器或编辑器表格在
## 不绑定具体 Control 节点的前提下处理键盘/手柄焦点。它不创建 UI、不读取输入、
## 不提交业务选择，只负责焦点索引、可聚焦判断和前后移动。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFVirtualListFocusModel
extends RefCounted


# --- 信号 ---

## 当前虚拟焦点索引变化后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param previous_index: 变化前的焦点索引；无焦点时为 NO_FOCUS。
## [br]
## @param focused_index: 变化后的焦点索引；无焦点时为 NO_FOCUS。
signal focused_index_changed(previous_index: int, focused_index: int)


# --- 常量 ---

## 无焦点标记。
## [br]
## @api public
## [br]
## @since 8.0.0
const NO_FOCUS: int = -1


# --- 公共变量 ---

## 当前条目数量，小于 0 时按 0 处理。
## [br]
## @api public
## [br]
## @since 8.0.0
var item_count: int:
	get:
		return _item_count
	set(value):
		_apply_item_count(value, true)

## 当前虚拟焦点索引；无焦点时为 NO_FOCUS。设置不可聚焦索引会被忽略。
## [br]
## @api public
## [br]
## @since 8.0.0
var focused_index: int:
	get:
		return _focused_index
	set(value):
		_apply_focused_index(value)

## 焦点移动到首尾边界后是否环绕。
## [br]
## @api public
## [br]
## @since 8.0.0
var wrap_navigation: bool = false

## 当条目数量变化且当前没有焦点时，是否自动聚焦第一个可聚焦条目。
## [br]
## @api public
## [br]
## @since 8.0.0
var auto_focus_on_count_change: bool = false

## 可选可聚焦判断回调。回调接收 item_index，返回 false 时该索引会被跳过。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema focusable_callback: Callable(item_index: int) -> bool。
var focusable_callback: Callable:
	get:
		return _focusable_callback
	set(value):
		_focusable_callback = value
		_repair_focus_internal(_focused_index)


# --- 私有变量 ---

var _item_count: int = 0
var _focused_index: int = NO_FOCUS
var _focusable_callback: Callable = Callable()


# --- 公共方法 ---

## 配置焦点模型并返回自身。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_item_count: 条目数量。
## [br]
## @param options: 可选项。
## [br]
## @return 当前焦点模型。
## [br]
## @schema options: Dictionary，支持 focused_index、wrap_navigation、auto_focus_on_count_change 和 focusable_callback。
func configure(p_item_count: int, options: Dictionary = {}) -> GFVirtualListFocusModel:
	var previous_focus_index: int = _focused_index
	wrap_navigation = GFVariantData.get_option_bool(options, "wrap_navigation", wrap_navigation)
	auto_focus_on_count_change = GFVariantData.get_option_bool(
		options,
		"auto_focus_on_count_change",
		auto_focus_on_count_change
	)
	var raw_callback: Variant = GFVariantData.get_option_value(options, "focusable_callback", Callable())
	if raw_callback is Callable:
		_focusable_callback = raw_callback

	_apply_item_count(p_item_count, false)
	if options.has("focused_index"):
		var requested_focus_index: int = GFVariantData.get_option_int(options, "focused_index", NO_FOCUS)
		if requested_focus_index == NO_FOCUS or is_focusable(requested_focus_index):
			_apply_focused_index(requested_focus_index)
		else:
			_repair_focus_internal(previous_focus_index)
	else:
		_repair_focus_internal(previous_focus_index)
	return self


## 设置条目数量，并按需修正当前焦点。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_item_count: 条目数量。
## [br]
## @param repair_focus_enabled: 是否修正越界或不可聚焦的当前焦点。
## [br]
## @return 条目数量或焦点发生变化时返回 true。
func set_item_count(p_item_count: int, repair_focus_enabled: bool = true) -> bool:
	var previous_count: int = _item_count
	var previous_focus_index: int = _focused_index
	_apply_item_count(p_item_count, repair_focus_enabled)
	return previous_count != _item_count or previous_focus_index != _focused_index


## 设置当前虚拟焦点索引。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param item_index: 目标条目索引；传入 NO_FOCUS 会清空焦点。
## [br]
## @return 焦点发生变化时返回 true。
func set_focused_index(item_index: int) -> bool:
	var previous_focus_index: int = _focused_index
	_apply_focused_index(item_index)
	return previous_focus_index != _focused_index


## 清空当前虚拟焦点。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 焦点发生变化时返回 true。
func clear_focus() -> bool:
	return set_focused_index(NO_FOCUS)


## 判断当前是否有虚拟焦点。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前存在有效焦点时返回 true。
func has_focus() -> bool:
	return _focused_index != NO_FOCUS


## 聚焦第一个可聚焦条目。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 焦点发生变化时返回 true。
func focus_first() -> bool:
	var next_index: int = _find_first_focusable(0, 1)
	if next_index == NO_FOCUS:
		return clear_focus()
	return set_focused_index(next_index)


## 聚焦最后一个可聚焦条目。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 焦点发生变化时返回 true。
func focus_last() -> bool:
	var next_index: int = _find_first_focusable(_item_count - 1, -1)
	if next_index == NO_FOCUS:
		return clear_focus()
	return set_focused_index(next_index)


## 按可聚焦条目步进移动焦点。
##
## step 为正时向后移动，为负时向前移动；绝对值表示跨过多少个可聚焦条目。
## 当前没有焦点时，正向移动会聚焦第一个可聚焦条目，反向移动会聚焦最后一个。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param step: 移动步数。
## [br]
## @return 焦点发生变化时返回 true。
func move_focus(step: int) -> bool:
	if step == 0:
		return false
	if _item_count <= 0:
		return clear_focus()

	var direction: int = 1
	if step < 0:
		direction = -1
	if _focused_index == NO_FOCUS:
		if direction > 0:
			return focus_first()
		return focus_last()

	var next_index: int = _focused_index
	var remaining_steps: int = absi(step)
	while remaining_steps > 0:
		var candidate_index: int = _find_next_focusable(next_index, direction)
		if candidate_index == NO_FOCUS:
			break
		next_index = candidate_index
		remaining_steps -= 1

	if next_index == _focused_index:
		return false
	return set_focused_index(next_index)


## 聚焦下一个可聚焦条目。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 焦点发生变化时返回 true。
func focus_next() -> bool:
	return move_focus(1)


## 聚焦上一个可聚焦条目。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 焦点发生变化时返回 true。
func focus_previous() -> bool:
	return move_focus(-1)


## 根据当前条目数量和可聚焦规则修正焦点。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param preferred_index: 优先尝试的索引；无偏好时传 NO_FOCUS。
## [br]
## @return 焦点发生变化时返回 true。
func repair_focus(preferred_index: int = NO_FOCUS) -> bool:
	var previous_focus_index: int = _focused_index
	_repair_focus_internal(preferred_index)
	return previous_focus_index != _focused_index


## 判断某个条目索引是否可聚焦。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param item_index: 条目索引。
## [br]
## @return 可聚焦时返回 true。
func is_focusable(item_index: int) -> bool:
	if item_index < 0 or item_index >= _item_count:
		return false
	if not _focusable_callback.is_valid():
		return true

	var callback_result: Variant = _focusable_callback.call(item_index)
	return GFVariantData.to_bool(callback_result, true)


## 获取焦点模型调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 焦点状态字典。
## [br]
## @schema return: Dictionary，包含 item_count、focused_index、has_focus、wrap_navigation 和 auto_focus_on_count_change。
func get_debug_snapshot() -> Dictionary:
	return {
		"item_count": _item_count,
		"focused_index": _focused_index,
		"has_focus": has_focus(),
		"wrap_navigation": wrap_navigation,
		"auto_focus_on_count_change": auto_focus_on_count_change,
	}


# --- 私有/辅助方法 ---

func _apply_item_count(value: int, repair_focus_enabled: bool) -> void:
	var previous_focus_index: int = _focused_index
	_item_count = maxi(value, 0)
	if repair_focus_enabled:
		_repair_focus_internal(previous_focus_index)


func _apply_focused_index(item_index: int) -> void:
	if item_index == NO_FOCUS:
		_set_focus_unchecked(NO_FOCUS)
		return
	if not is_focusable(item_index):
		return
	_set_focus_unchecked(item_index)


func _repair_focus_internal(preferred_index: int) -> void:
	if _item_count <= 0:
		_set_focus_unchecked(NO_FOCUS)
		return

	if preferred_index != NO_FOCUS:
		var preferred_focus_index: int = _find_nearest_focusable(_clamp_index(preferred_index))
		if preferred_focus_index != NO_FOCUS:
			_set_focus_unchecked(preferred_focus_index)
			return

	if _focused_index != NO_FOCUS and is_focusable(_focused_index):
		return

	if _focused_index != NO_FOCUS:
		var nearest_focus_index: int = _find_nearest_focusable(_clamp_index(_focused_index))
		if nearest_focus_index != NO_FOCUS:
			_set_focus_unchecked(nearest_focus_index)
			return

	if auto_focus_on_count_change:
		_set_focus_unchecked(_find_first_focusable(0, 1))
		return

	_set_focus_unchecked(NO_FOCUS)


func _find_next_focusable(from_index: int, direction: int) -> int:
	if _item_count <= 0:
		return NO_FOCUS

	var step_direction: int = 1
	if direction < 0:
		step_direction = -1
	var candidate_index: int = from_index
	for _iteration: int in range(_item_count):
		candidate_index += step_direction
		if candidate_index < 0 or candidate_index >= _item_count:
			if not wrap_navigation:
				return NO_FOCUS
			candidate_index = _item_count - 1 if step_direction < 0 else 0
		if candidate_index == from_index:
			return NO_FOCUS
		if is_focusable(candidate_index):
			return candidate_index
	return NO_FOCUS


func _find_first_focusable(start_index: int, direction: int) -> int:
	if _item_count <= 0:
		return NO_FOCUS

	var step_direction: int = 1
	if direction < 0:
		step_direction = -1
	var candidate_index: int = _clamp_index(start_index)
	while candidate_index >= 0 and candidate_index < _item_count:
		if is_focusable(candidate_index):
			return candidate_index
		candidate_index += step_direction
	return NO_FOCUS


func _find_nearest_focusable(seed_index: int) -> int:
	if _item_count <= 0:
		return NO_FOCUS
	if is_focusable(seed_index):
		return seed_index

	for distance: int in range(1, _item_count):
		var forward_index: int = seed_index + distance
		if forward_index < _item_count and is_focusable(forward_index):
			return forward_index

		var backward_index: int = seed_index - distance
		if backward_index >= 0 and is_focusable(backward_index):
			return backward_index

	return NO_FOCUS


func _set_focus_unchecked(next_index: int) -> void:
	if _focused_index == next_index:
		return
	var previous_focus_index: int = _focused_index
	_focused_index = next_index
	focused_index_changed.emit(previous_focus_index, _focused_index)


func _clamp_index(item_index: int) -> int:
	if _item_count <= 0:
		return NO_FOCUS
	return mini(maxi(item_index, 0), _item_count - 1)
