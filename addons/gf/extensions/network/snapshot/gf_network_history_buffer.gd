## GFNetworkHistoryBuffer: 按 tick 保存网络快照的环形历史。
##
## 用于插值、重放、状态对账或项目自定义同步流程；不会自动执行预测、回滚或冲突解决。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFNetworkHistoryBuffer
extends RefCounted


# --- 公共变量 ---

## 最大保存快照数量。小于等于 0 表示不限制。
## [br]
## @api public
var capacity: int = 120


# --- 私有变量 ---

## 按 tick 保存快照值。
## [br]
## @api private
## [br]
var _snapshots: Dictionary = {}

## 按升序保存当前历史中的 tick。
## [br]
## @api private
## [br]
var _tick_order: Array[int] = []


# --- Godot 生命周期方法 ---

func _init(p_capacity: int = 120) -> void:
	capacity = p_capacity


# --- 公共方法 ---

## 添加快照。
## [br]
## @api public
## [br]
## @param snapshot: 快照。
## [br]
## @return 添加成功返回 true。
func add_snapshot(snapshot: GFNetworkSnapshot) -> bool:
	if snapshot == null:
		return false

	_snapshots[snapshot.tick] = snapshot.duplicate_snapshot()
	if not _tick_order.has(snapshot.tick):
		_tick_order.append(snapshot.tick)
		_tick_order.sort()
	_prune_to_capacity()
	return true


## 添加状态字典并返回生成的快照。
## [br]
## @api public
## [br]
## @param tick: 快照 tick。
## [br]
## @param state: 状态字典。
## [br]
## @param peer_id: 来源 peer。
## [br]
## @param metadata: 元数据。
## [br]
## @return 新快照。
## [br]
## @schema state: Dictionary[StringName|String, Variant]，保存项目自定义同步状态。
## [br]
## @schema metadata: Dictionary，保存项目自定义快照元数据。
func add_state(
	tick: int,
	state: Dictionary,
	peer_id: int = -1,
	metadata: Dictionary = {}
) -> GFNetworkSnapshot:
	var snapshot: GFNetworkSnapshot = GFNetworkSnapshot.new(tick, state, peer_id, metadata)
	var _add_snapshot_result_79: Variant = add_snapshot(snapshot)
	return snapshot


## 检查指定 tick 是否存在快照。
## [br]
## @api public
## [br]
## @param tick: 快照 tick。
## [br]
## @return 存在返回 true。
func has_snapshot(tick: int) -> bool:
	return _snapshots.has(tick)


## 获取指定 tick 的快照副本。
## [br]
## @api public
## [br]
## @param tick: 快照 tick。
## [br]
## @return 快照副本；不存在时返回 null。
func get_snapshot(tick: int) -> GFNetworkSnapshot:
	var snapshot: GFNetworkSnapshot = _variant_to_snapshot(GFVariantData.get_option_value(_snapshots, tick))
	return snapshot.duplicate_snapshot() if snapshot != null else null


## 获取最新快照副本。
## [br]
## @api public
## [br]
## @return 最新快照；不存在时返回 null。
func get_latest_snapshot() -> GFNetworkSnapshot:
	if _tick_order.is_empty():
		return null
	return get_snapshot(_tick_order[_tick_order.size() - 1])


## 获取最早快照副本。
## [br]
## @api public
## [br]
## @return 最早快照；不存在时返回 null。
func get_earliest_snapshot() -> GFNetworkSnapshot:
	if _tick_order.is_empty():
		return null
	return get_snapshot(_tick_order[0])


## 获取最接近指定 tick 的快照副本。
## [br]
## @api public
## [br]
## @param tick: 查询 tick。
## [br]
## @param prefer_older: 距离相同时是否优先旧快照。
## [br]
## @return 快照副本；不存在时返回 null。
func get_closest_snapshot(tick: int, prefer_older: bool = true) -> GFNetworkSnapshot:
	if _tick_order.is_empty():
		return null

	var best_tick: int = _tick_order[0]
	var best_distance: int = absi(best_tick - tick)
	for candidate_tick: int in _tick_order:
		var distance: int = absi(candidate_tick - tick)
		if distance < best_distance:
			best_tick = candidate_tick
			best_distance = distance
		elif distance == best_distance:
			if prefer_older and candidate_tick < best_tick:
				best_tick = candidate_tick
			elif not prefer_older and candidate_tick > best_tick:
				best_tick = candidate_tick
	return get_snapshot(best_tick)


## 获取指定 tick 范围内的快照副本。
## [br]
## @api public
## [br]
## @param from_tick: 起始 tick。
## [br]
## @param to_tick: 结束 tick。
## [br]
## @param include_bounds: 是否包含边界 tick。
## [br]
## @return 按 tick 升序排列的快照副本。
## [br]
## @schema return: Array[GFNetworkSnapshot]，按 tick 升序排列的快照副本。
func get_snapshots_between(
	from_tick: int,
	to_tick: int,
	include_bounds: bool = true
) -> Array[GFNetworkSnapshot]:
	var result: Array[GFNetworkSnapshot] = []
	var start_tick: int = mini(from_tick, to_tick)
	var end_tick: int = maxi(from_tick, to_tick)
	for stored_tick: int in _tick_order:
		var in_range: bool = (
			stored_tick >= start_tick
			and stored_tick <= end_tick
		) if include_bounds else (
			stored_tick > start_tick
			and stored_tick < end_tick
		)
		if not in_range:
			continue

		var snapshot: GFNetworkSnapshot = get_snapshot(stored_tick)
		if snapshot != null:
			result.append(snapshot)
	return result


## 获取包围指定 tick 的快照副本。
## [br]
## @api public
## [br]
## @param tick: 查询 tick。
## [br]
## @return 字典，包含 exact、previous、next 三个可选快照。
## [br]
## @schema return: Dictionary，包含 exact、previous、next，值为 GFNetworkSnapshot 或 null。
func get_surrounding_snapshots(tick: int) -> Dictionary:
	var result: Dictionary = {
		"exact": null,
		"previous": null,
		"next": null,
	}
	for stored_tick: int in _tick_order:
		if stored_tick == tick:
			result["exact"] = get_snapshot(stored_tick)
			continue
		if stored_tick < tick:
			result["previous"] = get_snapshot(stored_tick)
			continue
		if stored_tick > tick:
			result["next"] = get_snapshot(stored_tick)
			break
	return result


## 获取已保存 tick 列表。
## [br]
## @api public
## [br]
## @return tick 列表。
func get_ticks() -> PackedInt64Array:
	var result: PackedInt64Array = PackedInt64Array()
	for tick: int in _tick_order:
		_append_packed_int64(result, tick)
	return result


## 删除指定 tick 之前的快照。
## [br]
## @api public
## [br]
## @param tick: 保留起点 tick。
## [br]
## @return 删除数量。
func prune_before(tick: int) -> int:
	var removed_count: int = 0
	for index: int in range(_tick_order.size() - 1, -1, -1):
		var stored_tick: int = _tick_order[index]
		if stored_tick >= tick:
			continue
		var _erased: bool = _snapshots.erase(stored_tick)
		_tick_order.remove_at(index)
		removed_count += 1
	return removed_count


## 清空历史。
## [br]
## @api public
func clear() -> void:
	_snapshots.clear()
	_tick_order.clear()


## 获取快照数量。
## [br]
## @api public
## [br]
## @return 快照数量。
func size() -> int:
	return _tick_order.size()


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary，包含 capacity、size、earliest_tick、latest_tick。
func get_debug_snapshot() -> Dictionary:
	return {
		"capacity": capacity,
		"size": size(),
		"earliest_tick": _tick_order[0] if not _tick_order.is_empty() else -1,
		"latest_tick": _tick_order[_tick_order.size() - 1] if not _tick_order.is_empty() else -1,
	}


# --- 私有/辅助方法 ---

## 超出正容量时移除最早的快照；非正容量不执行裁剪。
## [br]
## @api private
## [br]
func _prune_to_capacity() -> void:
	if capacity <= 0:
		return

	var remove_count: int = _tick_order.size() - capacity
	if remove_count <= 0:
		return

	for index: int in range(remove_count):
		var _erased: bool = _snapshots.erase(_tick_order[index])

	var kept_order: Array[int] = []
	for index: int in range(remove_count, _tick_order.size()):
		kept_order.append(_tick_order[index])
	_tick_order = kept_order


## 将 Variant 转为快照类型；类型不符时返回 null。
## [br]
## @api private
## [br]
func _variant_to_snapshot(value: Variant) -> GFNetworkSnapshot:
	if value is GFNetworkSnapshot:
		var snapshot: GFNetworkSnapshot = value
		return snapshot
	return null


## 将整数附加到 PackedInt64Array；目标不接受时不再处理。
## [br]
## @api private
## [br]
func _append_packed_int64(target: PackedInt64Array, value: int) -> void:
	var appended: bool = target.append(value)
	if appended:
		return
