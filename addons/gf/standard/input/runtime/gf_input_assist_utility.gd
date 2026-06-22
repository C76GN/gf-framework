## GFInputAssistUtility: 输入手感辅助工具。
##
## 负责动作意图缓冲和通用宽容窗口。它不读取 InputEvent、不处理重绑定、
## 不维护玩家设备，也不替代 GFInputMappingUtility；正式输入映射仍应由
## GFInputMappingUtility 负责。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFInputAssistUtility
extends GFUtility


# --- 信号 ---

## 宽容窗口自然倒计时结束时发出。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param window_id: 窗口标识。
## [br]
## @param player_index: 玩家索引；小于 0 表示全局窗口。
signal grace_window_expired(window_id: StringName, player_index: int)


# --- 私有变量 ---

var _action_buffers: Dictionary = {}
var _grace_windows: Dictionary = {}
var _grace_window_ids: Dictionary = {}
var _grace_window_player_indices: Dictionary = {}


# --- GF 生命周期方法 ---

## 初始化输入辅助状态并让计时不受时间缩放影响。
## [br]
## @api public
func init() -> void:
	ignore_time_scale = true
	_action_buffers.clear()
	_grace_windows.clear()
	_grace_window_ids.clear()
	_grace_window_player_indices.clear()


## 清理全部动作缓冲和宽容窗口。
## [br]
## @api public
func dispose() -> void:
	_action_buffers.clear()
	_grace_windows.clear()
	_grace_window_ids.clear()
	_grace_window_player_indices.clear()


# --- 公共方法 ---

## 每帧驱动计时器递减。所有计时器归零后自动清除。
## [br]
## @api public
## [br]
## @param delta: 帧间隔时间（秒）。
func tick(delta: float) -> void:
	_tick_timers(_action_buffers, delta)
	_tick_grace_windows(delta)


## 缓冲一个动作意图，在 duration 秒内可被消费。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @param duration: 缓冲持续时间（秒）。
## [br]
## @param player_index: 玩家索引；小于 0 时使用全局缓冲。
func buffer_action(action_id: StringName, duration: float, player_index: int = -1) -> void:
	if action_id == &"" or duration <= 0.0:
		return

	var key: String = _make_scoped_key(action_id, player_index)
	var current: float = GFVariantData.get_option_float(_action_buffers, key, 0.0)
	_action_buffers[key] = maxf(current, duration)


## 尝试消费一个缓冲动作。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @param player_index: 玩家索引；小于 0 时使用全局缓冲。
## [br]
## @return 是否成功消费。
func consume_buffered_action(action_id: StringName, player_index: int = -1) -> bool:
	var key: String = _make_scoped_key(action_id, player_index)
	if _action_buffers.has(key) and GFVariantData.to_float(_action_buffers[key]) > 0.0:
		var _erase_result_83: Variant = _action_buffers.erase(key)
		return true
	return false


## 查询指定动作是否有活跃的缓冲（不消费）。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @param player_index: 玩家索引；小于 0 时使用全局缓冲。
## [br]
## @return 是否有活跃缓冲。
func has_buffered_action(action_id: StringName, player_index: int = -1) -> bool:
	var key: String = _make_scoped_key(action_id, player_index)
	return _action_buffers.has(key) and GFVariantData.to_float(_action_buffers[key]) > 0.0


## 清除指定动作缓冲。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @param player_index: 玩家索引；小于 0 时使用全局缓冲。
func clear_buffered_action(action_id: StringName, player_index: int = -1) -> void:
	var _erase_result_110: Variant = _action_buffers.erase(_make_scoped_key(action_id, player_index))


## 开始一个通用宽容窗口。
## [br]
## @api public
## [br]
## @param window_id: 窗口标识。
## [br]
## @param duration: 宽容窗口持续时间（秒）。
## [br]
## @param player_index: 玩家索引；小于 0 时使用全局窗口。
func start_grace_window(window_id: StringName, duration: float, player_index: int = -1) -> void:
	var key: String = _make_scoped_key(window_id, player_index)
	if window_id == &"" or duration <= 0.0:
		_erase_grace_window_key(key)
		return
	_grace_windows[key] = duration
	_grace_window_ids[key] = window_id
	_grace_window_player_indices[key] = player_index


## 查询指定宽容窗口是否活跃。
## [br]
## @api public
## [br]
## @param window_id: 窗口标识。
## [br]
## @param player_index: 玩家索引；小于 0 时使用全局窗口。
## [br]
## @return 是否在窗口内。
func is_grace_window_active(window_id: StringName, player_index: int = -1) -> bool:
	var key: String = _make_scoped_key(window_id, player_index)
	return _grace_windows.has(key) and GFVariantData.to_float(_grace_windows[key]) > 0.0


## 手动取消指定宽容窗口。
## [br]
## @api public
## [br]
## @param window_id: 窗口标识。
## [br]
## @param player_index: 玩家索引；小于 0 时使用全局窗口。
func cancel_grace_window(window_id: StringName, player_index: int = -1) -> void:
	var key: String = _make_scoped_key(window_id, player_index)
	_erase_grace_window_key(key)


## 清除指定玩家的全部输入辅助状态。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
func clear_player(player_index: int) -> void:
	_clear_keys_with_prefix(_action_buffers, _make_scope_prefix(player_index))
	_clear_keys_with_prefix(_grace_windows, _make_scope_prefix(player_index))
	_clear_keys_with_prefix(_grace_window_ids, _make_scope_prefix(player_index))
	_clear_keys_with_prefix(_grace_window_player_indices, _make_scope_prefix(player_index))


## 清除所有缓冲和宽容窗口状态。
## [br]
## @api public
func clear_all() -> void:
	_action_buffers.clear()
	_grace_windows.clear()
	_grace_window_ids.clear()
	_grace_window_player_indices.clear()


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 包含缓冲和宽容窗口剩余时间的字典。
## [br]
## @schema return: Dictionary，包含按 scoped action 或 window id 索引的 action_buffers 与 grace_windows 计时器快照。
func get_debug_snapshot() -> Dictionary:
	return {
		"action_buffers": _duplicate_timer_snapshot(_action_buffers),
		"grace_windows": _duplicate_timer_snapshot(_grace_windows),
	}


# --- 私有/辅助方法 ---

func _tick_timers(timers: Dictionary, delta: float) -> void:
	if timers.is_empty() or delta <= 0.0:
		return

	var expired: Array[String] = []

	for key: String in timers:
		timers[key] = GFVariantData.to_float(timers[key]) - delta
		if GFVariantData.to_float(timers[key]) <= 0.0:
			expired.append(key)

	for key: String in expired:
		var _erase_result_201: Variant = timers.erase(key)


func _tick_grace_windows(delta: float) -> void:
	if _grace_windows.is_empty() or delta <= 0.0:
		return

	var expired: Array[String] = []

	for key: String in _grace_windows:
		_grace_windows[key] = GFVariantData.to_float(_grace_windows[key]) - delta
		if GFVariantData.to_float(_grace_windows[key]) <= 0.0:
			expired.append(key)

	for key: String in expired:
		_emit_grace_window_expired(key)


func _emit_grace_window_expired(key: String) -> void:
	if not _grace_windows.has(key) or GFVariantData.to_float(_grace_windows[key]) > 0.0:
		return

	var window_id: StringName = GFVariantData.get_option_string_name(_grace_window_ids, key)
	var player_index: int = GFVariantData.get_option_int(_grace_window_player_indices, key, -1)
	_erase_grace_window_key(key)
	grace_window_expired.emit(window_id, player_index)


func _erase_grace_window_key(key: String) -> void:
	var _erase_result: Variant = _grace_windows.erase(key)
	var _id_erase_result: Variant = _grace_window_ids.erase(key)
	var _player_erase_result: Variant = _grace_window_player_indices.erase(key)


func _make_scoped_key(id: StringName, player_index: int) -> String:
	return "%s/%s" % [_make_scope_prefix(player_index), String(id)]


func _make_scope_prefix(player_index: int) -> String:
	if player_index >= 0:
		return "player:%d" % player_index
	return "global"


func _clear_keys_with_prefix(timers: Dictionary, prefix: String) -> void:
	var keys_to_remove: Array[String] = []
	for key: String in timers.keys():
		if key.begins_with(prefix + "/"):
			keys_to_remove.append(key)

	for key: String in keys_to_remove:
		var _erase_result_221: Variant = timers.erase(key)


func _duplicate_timer_snapshot(timers: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in timers.keys():
		result[key] = GFVariantData.to_float(timers[key])
	return result
