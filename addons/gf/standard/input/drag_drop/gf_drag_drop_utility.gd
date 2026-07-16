## GFDragDropUtility: 通用拖拽会话与落点匹配工具。
##
## 该工具只管理拖拽生命周期、落点注册、命中排序和结果包装。
## 它不读取输入、不移动节点、不保存业务历史，也不规定具体 UI 或玩法语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFDragDropUtility
extends GFUtility


# --- 信号 ---

## 拖拽开始时发出。
## [br]
## @api public
## [br]
## @param session_id: 会话 ID。
## [br]
## @param drag_type: 拖拽类型。
signal drag_started(session_id: int, drag_type: StringName)

## 拖拽位置更新时发出。
## [br]
## @api public
## [br]
## @param session_id: 会话 ID。
## [br]
## @param position: 当前位置。
## [br]
## @param delta: 本次位移。
signal drag_moved(session_id: int, position: Vector2, delta: Vector2)

## 拖拽成功释放到落点时发出。
## [br]
## @api public
## [br]
## @param session_id: 会话 ID。
## [br]
## @param zone_id: 落点 ID。
## [br]
## @param result: 落点返回结果。
## [br]
## @schema result: Dictionary，由 drop() 规范化，包含 ok、session_id、zone_id、reason 和可选 value。
signal drag_dropped(session_id: int, zone_id: StringName, result: Dictionary)

## 拖拽释放被拒绝时发出。
## [br]
## @api public
## [br]
## @param session_id: 会话 ID。
## [br]
## @param reason: 拒绝原因。
signal drag_drop_rejected(session_id: int, reason: StringName)

## 拖拽取消时发出。
## [br]
## @api public
## [br]
## @param session_id: 会话 ID。
signal drag_cancelled(session_id: int)

## 落点注册后发出。
## [br]
## @api public
## [br]
## @param zone_id: 落点 ID。
signal drop_zone_registered(zone_id: StringName)

## 落点注销后发出。
## [br]
## @api public
## [br]
## @param zone_id: 落点 ID。
signal drop_zone_unregistered(zone_id: StringName)


# --- 私有变量 ---

var _session_serial: int = 0
var _sessions: Dictionary = {}
var _zones: Dictionary = {}


# --- GF 生命周期方法 ---

## 释放拖拽工具持有的会话与落点。
## [br]
## @api public
func dispose() -> void:
	clear_sessions()
	clear_zones()


# --- 公共方法 ---

## 注册落点。
## [br]
## @api public
## [br]
## @param zone: 落点规则。
## [br]
## @return 注册成功返回 true。
func register_zone(zone: GFDropZone) -> bool:
	if zone == null or zone.zone_id == &"":
		return false
	if _zones.has(zone.zone_id):
		drop_zone_unregistered.emit(zone.zone_id)
	_zones[zone.zone_id] = zone
	drop_zone_registered.emit(zone.zone_id)
	return true


## 注册矩形落点。
## [br]
## @param zone_id: 落点 ID。
## [br]
## @param rect: 全局矩形区域。
## [br]
## @param accepted_types: 可接收类型；为空表示不限制。
## [br]
## @param options: 可选参数，支持 priority、enabled、metadata、can_accept、drop。
## [br]
## @return 注册成功时返回落点，否则返回 null。
## [br]
## @api public
## [br]
## @schema options: Dictionary，透传给 GFDropZone.from_rect()。
func register_rect_zone(
	zone_id: StringName,
	rect: Rect2,
	accepted_types: PackedStringArray = PackedStringArray(),
	options: Dictionary = {}
) -> GFDropZone:
	var zone: GFDropZone = GFDropZone.from_rect(zone_id, rect, accepted_types, options)
	return zone if register_zone(zone) else null


## 注册 Control 全局矩形落点。
## [br]
## @param zone_id: 落点 ID。
## [br]
## @param control: 用于读取 get_global_rect() 的 Control。
## [br]
## @param accepted_types: 可接收类型；为空表示不限制。
## [br]
## @param options: 可选参数，支持 priority、enabled、metadata、can_accept、drop。
## [br]
## @return 注册成功时返回落点，否则返回 null。
## [br]
## @api public
## [br]
## @schema options: Dictionary，透传给 GFDropZone.from_control()。
func register_control_zone(
	zone_id: StringName,
	control: Control,
	accepted_types: PackedStringArray = PackedStringArray(),
	options: Dictionary = {}
) -> GFDropZone:
	var zone: GFDropZone = GFDropZone.from_control(zone_id, control, accepted_types, options)
	return zone if register_zone(zone) else null


## 注销落点。
## [br]
## @api public
## [br]
## @param zone_id: 落点 ID。
## [br]
## @return 找到并移除时返回 true。
func unregister_zone(zone_id: StringName) -> bool:
	if not _zones.has(zone_id):
		return false
	var _removed: bool = _zones.erase(zone_id)
	drop_zone_unregistered.emit(zone_id)
	return true


## 获取落点。
## [br]
## @api public
## [br]
## @param zone_id: 落点 ID。
## [br]
## @return 落点；不存在时返回 null。
func get_zone(zone_id: StringName) -> GFDropZone:
	var _pruned_stale_zones: int = _prune_stale_zones()
	return _variant_to_drop_zone(GFVariantData.get_option_value(_zones, zone_id))


## 清空落点。
## [br]
## @api public
func clear_zones() -> void:
	for zone_id: StringName in _zones.keys():
		drop_zone_unregistered.emit(zone_id)
	_zones.clear()


## 主动剪枝已失效的落点。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 本次移除的落点数量。
func prune_stale_zones() -> int:
	return _prune_stale_zones()


## 开始拖拽。
## [br]
## @param drag_type: 拖拽类型。
## [br]
## @param payload: 项目自定义载荷。
## [br]
## @param position: 起始位置。
## [br]
## @param source: 可选来源对象。
## [br]
## @param metadata: 项目自定义元数据。
## [br]
## @return 会话 ID；失败时返回 -1。
## [br]
## @api public
## [br]
## @schema payload: Variant，透传给 drop zone 的项目侧拖拽载荷。
## [br]
## @schema metadata: Dictionary，复制到拖拽会话中的项目侧元数据。
func start_drag(
	drag_type: StringName,
	payload: Variant,
	position: Vector2,
	source: Object = null,
	metadata: Dictionary = {}
) -> int:
	if drag_type == &"":
		return -1

	_session_serial += 1
	var session: GFDragSession = GFDragSession.new()
	session.setup(_session_serial, drag_type, payload, position, source, metadata)
	_sessions[session.session_id] = session
	drag_started.emit(session.session_id, drag_type)
	return session.session_id


## 更新拖拽位置。
## [br]
## @api public
## [br]
## @param session_id: 会话 ID。
## [br]
## @param position: 当前位置。
## [br]
## @return 更新成功返回 true。
func update_drag(session_id: int, position: Vector2) -> bool:
	var session: GFDragSession = get_session(session_id)
	if session == null:
		return false
	session.update_position(position)
	drag_moved.emit(session_id, position, session.get_delta())
	return true


## 将拖拽释放到当前位置匹配到的最佳落点。
## [br]
## @api public
## [br]
## @param session_id: 会话 ID。
## [br]
## @param position: 释放位置。
## [br]
## @return 结构化结果字典。
## [br]
## @schema return: Dictionary，包含 ok、session_id、zone_id、reason 和可选 value。
func drop(session_id: int, position: Vector2) -> Dictionary:
	var session: GFDragSession = get_session(session_id)
	if session == null:
		return _make_result(false, session_id, &"", &"missing_session")

	session.update_position(position)
	var zone: GFDropZone = get_best_drop_zone(session_id, position)
	if zone == null:
		var _removed_no_zone: bool = _sessions.erase(session_id)
		drag_drop_rejected.emit(session_id, &"no_drop_zone")
		return _make_result(false, session_id, &"", &"no_drop_zone")

	var raw_result: Variant = zone.drop(session, position)
	var result: Dictionary = _normalize_drop_result(raw_result, session_id, zone.zone_id)
	if not GFVariantData.get_option_bool(result, "ok"):
		drag_drop_rejected.emit(session_id, GFVariantData.get_option_string_name(result, "reason", &"drop_rejected"))
		return result

	var _removed: bool = _sessions.erase(session_id)
	drag_dropped.emit(session_id, zone.zone_id, result)
	return result


## 取消拖拽。
## [br]
## @api public
## [br]
## @param session_id: 会话 ID。
## [br]
## @return 找到并取消时返回 true。
func cancel_drag(session_id: int) -> bool:
	if not _sessions.has(session_id):
		return false
	var _removed: bool = _sessions.erase(session_id)
	drag_cancelled.emit(session_id)
	return true


## 获取会话。
## [br]
## @api public
## [br]
## @param session_id: 会话 ID。
## [br]
## @return 会话；不存在时返回 null。
func get_session(session_id: int) -> GFDragSession:
	return _variant_to_drag_session(GFVariantData.get_option_value(_sessions, session_id))


## 检查会话是否存在。
## [br]
## @api public
## [br]
## @param session_id: 会话 ID。
## [br]
## @return 存在时返回 true。
func has_active_session(session_id: int) -> bool:
	return _sessions.has(session_id)


## 获取当前位置命中的落点候选。
## [br]
## @param session_id: 会话 ID。
## [br]
## @param position: 要检查的位置。
## [br]
## @param only_accepting: 为 true 时只返回当前可接收会话的落点。
## [br]
## @return 按优先级排序的落点列表。
## [br]
## @api public
func get_drop_candidates(
	session_id: int,
	position: Vector2,
	only_accepting: bool = true
) -> Array[GFDropZone]:
	var _pruned_stale_zones: int = _prune_stale_zones()
	var session: GFDragSession = get_session(session_id)
	if session == null:
		return []

	var result: Array[GFDropZone] = []
	for zone_variant: Variant in _zones.values():
		var zone: GFDropZone = _variant_to_drop_zone(zone_variant)
		if zone == null:
			continue
		if only_accepting and not zone.can_accept(session):
			continue
		if not zone.contains(position, session):
			continue
		result.append(zone)
	result.sort_custom(_sort_zones)
	return result


## 获取当前位置最佳落点。
## [br]
## @api public
## [br]
## @param session_id: 会话 ID。
## [br]
## @param position: 要检查的位置。
## [br]
## @return 最佳落点；没有可用落点时返回 null。
func get_best_drop_zone(session_id: int, position: Vector2) -> GFDropZone:
	var _pruned_stale_zones: int = _prune_stale_zones()
	var session: GFDragSession = get_session(session_id)
	if session == null:
		return null

	var best_zone: GFDropZone = null
	for zone_variant: Variant in _zones.values():
		var zone: GFDropZone = _variant_to_drop_zone(zone_variant)
		if zone == null or not zone.can_accept(session) or not zone.contains(position, session):
			continue
		if best_zone == null or _sort_zones(zone, best_zone):
			best_zone = zone
	return best_zone


## 清空拖拽会话。
## [br]
## @api public
func clear_sessions() -> void:
	for session_id_variant: Variant in _sessions.keys():
		var session_id: int = GFVariantData.to_int(session_id_variant)
		drag_cancelled.emit(session_id)
	_sessions.clear()


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 3.9.0
## [br]
## @param json_compatible: 为 true 时返回可直接 JSON.stringify() 的值。
## [br]
## @return 当前拖拽与落点状态。
## [br]
## @schema return: Dictionary，包含 active_session_count、zone_count、sessions: Array[Dictionary] 和 zones: Array[Dictionary]。
func get_debug_snapshot(json_compatible: bool = true) -> Dictionary:
	var _pruned_stale_zones: int = _prune_stale_zones()
	var sessions: Array[Dictionary] = []
	for session_variant: Variant in _sessions.values():
		var session: GFDragSession = _variant_to_drag_session(session_variant)
		if session != null:
			sessions.append(session.to_dictionary(json_compatible))

	var zones: Array[Dictionary] = []
	for zone_variant: Variant in _zones.values():
		var zone: GFDropZone = _variant_to_drop_zone(zone_variant)
		if zone != null:
			zones.append(zone.to_dictionary(json_compatible))

	return {
		"active_session_count": _sessions.size(),
		"zone_count": _zones.size(),
		"sessions": sessions,
		"zones": zones,
	}


# --- 私有/辅助方法 ---

func _sort_zones(left: GFDropZone, right: GFDropZone) -> bool:
	if left.priority != right.priority:
		return left.priority > right.priority
	return String(left.zone_id) < String(right.zone_id)


func _normalize_drop_result(raw_result: Variant, session_id: int, zone_id: StringName) -> Dictionary:
	if raw_result is Dictionary:
		var result_dictionary: Dictionary = GFVariantData.to_dictionary(raw_result)
		if not result_dictionary.has("ok"):
			result_dictionary["ok"] = true
		result_dictionary["session_id"] = session_id
		result_dictionary["zone_id"] = zone_id
		if not GFVariantData.get_option_bool(result_dictionary, "ok") and not result_dictionary.has("reason"):
			result_dictionary["reason"] = &"drop_rejected"
		return result_dictionary

	var ok: bool = GFVariantData.to_bool(raw_result) if raw_result is bool else true
	var normalized_result: Dictionary = {
		"ok": ok,
		"session_id": session_id,
		"zone_id": zone_id,
		"value": raw_result,
	}
	if not ok:
		normalized_result["reason"] = &"drop_rejected"
	return normalized_result


func _make_result(ok: bool, session_id: int, zone_id: StringName, reason: StringName) -> Dictionary:
	return {
		"ok": ok,
		"session_id": session_id,
		"zone_id": zone_id,
		"reason": reason,
	}


func _prune_stale_zones() -> int:
	var removed_zone_ids: Array[StringName] = []
	for zone_id_variant: Variant in _zones.keys():
		var zone_id: StringName = GFVariantData.to_string_name(zone_id_variant)
		var zone: GFDropZone = _variant_to_drop_zone(GFVariantData.get_option_value(_zones, zone_id))
		if zone != null and zone.is_stale():
			removed_zone_ids.append(zone_id)

	for zone_id: StringName in removed_zone_ids:
		var _removed: bool = _zones.erase(zone_id)
		drop_zone_unregistered.emit(zone_id)
	return removed_zone_ids.size()


func _variant_to_drag_session(value: Variant) -> GFDragSession:
	if value is GFDragSession:
		var session: GFDragSession = value
		return session
	return null


func _variant_to_drop_zone(value: Variant) -> GFDropZone:
	if value is GFDropZone:
		var zone: GFDropZone = value
		return zone
	return null
