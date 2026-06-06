## GFVirtualListModel: 可变尺寸虚拟列表布局模型。
##
## 维护条目数量、估算尺寸、实测尺寸、累计偏移和可见范围，供聊天流、
## 日志面板、资源列表或编辑器 Dock 自行渲染可见 Control。它不创建 UI 节点，
## 不保存条目数据，也不规定列表视觉或交互规则。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 4.4.0
class_name GFVirtualListModel
extends RefCounted


# --- 常量 ---

## 默认条目估算尺寸。
## [br]
## @api public
const DEFAULT_ESTIMATED_ITEM_EXTENT: float = 60.0

## 默认可见范围两端额外保留的条目数。
## [br]
## @api public
const DEFAULT_OVERSCAN_ITEMS: int = 2

## 条目尺寸下限，避免零尺寸条目破坏二分搜索和滚动范围。
## [br]
## @api public
const MIN_ITEM_EXTENT: float = 1.0


# --- 公共变量 ---

## 未实测条目的估算尺寸。
## [br]
## @api public
var estimated_item_extent: float:
	get:
		return _estimated_item_extent
	set(value):
		_set_estimated_item_extent(value)

## 可见范围前后额外保留的条目数量。
## [br]
## @api public
var overscan_items: int:
	get:
		return _overscan_items
	set(value):
		_overscan_items = maxi(value, 0)

## 列表末尾额外报告的滚动尺寸。
## [br]
## @api public
var trailing_padding: float:
	get:
		return _trailing_padding
	set(value):
		_trailing_padding = maxf(value, 0.0)


# --- 私有变量 ---

var _estimated_item_extent: float = DEFAULT_ESTIMATED_ITEM_EXTENT
var _overscan_items: int = DEFAULT_OVERSCAN_ITEMS
var _trailing_padding: float = 0.0
var _extents: PackedFloat32Array = PackedFloat32Array()
var _measured: PackedByteArray = PackedByteArray()
var _offsets: PackedFloat32Array = PackedFloat32Array()
var _offsets_dirty: bool = true
var _content_extent: float = 0.0


# --- 公共方法 ---

## 清空所有条目尺寸和偏移缓存。
## [br]
## @api public
func clear() -> void:
	var _extents_resize_result: int = _extents.resize(0)
	var _measured_resize_result: int = _measured.resize(0)
	var _offsets_resize_result: int = _offsets.resize(0)
	_offsets_dirty = false
	_content_extent = 0.0


## 设置条目数量，并为新增条目填入估算尺寸。
## [br]
## @api public
## [br]
## @param item_count: 目标条目数量，小于 0 时按 0 处理。
func set_item_count(item_count: int) -> void:
	var next_count: int = maxi(item_count, 0)
	var previous_count: int = _extents.size()
	var _extents_resize_result: int = _extents.resize(next_count)
	var _measured_resize_result: int = _measured.resize(next_count)
	if next_count > previous_count:
		for index: int in range(previous_count, next_count):
			_extents[index] = _estimated_item_extent
			_measured[index] = 0
	_offsets_dirty = true


## 追加一个条目。
## [br]
## @api public
## [br]
## @param extent: 可选条目尺寸；小于等于 0 时使用 estimated_item_extent。
## [br]
## @param measured: 是否把 extent 视为实测尺寸。
## [br]
## @return 新条目的索引。
func append_item(extent: float = -1.0, measured: bool = false) -> int:
	var next_index: int = _extents.size()
	var resolved_extent: float = _estimated_item_extent
	if extent > 0.0:
		resolved_extent = _normalize_item_extent(extent)
	var _extent_appended: bool = _extents.append(resolved_extent)
	var measured_flag: int = 0
	if measured:
		measured_flag = 1
	var _measured_appended: bool = _measured.append(measured_flag)
	_offsets_dirty = true
	return next_index


## 移除指定条目。
## [br]
## @api public
## [br]
## @param item_index: 要移除的条目索引。
## [br]
## @return 移除成功返回 true。
func remove_item(item_index: int) -> bool:
	if not _is_valid_index(item_index):
		return false
	_extents.remove_at(item_index)
	_measured.remove_at(item_index)
	_offsets_dirty = true
	return true


## 写入条目尺寸。
##
## 返回报告中的 scroll_adjustment 可用于保持视口锚点：当被修改条目位于
## scroll_offset 之前时，调用方可把当前滚动偏移加上该值。
## [br]
## @api public
## [br]
## @param item_index: 条目索引。
## [br]
## @param extent: 条目尺寸，会被限制到 MIN_ITEM_EXTENT 以上。
## [br]
## @param measured: 是否把该尺寸视为实测尺寸。
## [br]
## @param scroll_offset: 可选当前滚动偏移；小于 0 时不计算锚点修正。
## [br]
## @return 尺寸更新报告。
## [br]
## @schema return: Dictionary，包含 ok、changed、index、previous_extent、extent、delta 与 scroll_adjustment 字段。
func set_item_extent(
	item_index: int,
	extent: float,
	measured: bool = true,
	scroll_offset: float = -1.0
) -> Dictionary:
	var report: Dictionary = {
		"ok": false,
		"changed": false,
		"index": item_index,
		"previous_extent": 0.0,
		"extent": 0.0,
		"delta": 0.0,
		"scroll_adjustment": 0.0,
	}
	if not _is_valid_index(item_index):
		return report

	_ensure_offsets()
	var previous_extent: float = _extents[item_index]
	var next_extent: float = _normalize_item_extent(extent)
	var delta: float = next_extent - previous_extent
	report["ok"] = true
	report["previous_extent"] = previous_extent
	report["extent"] = next_extent
	report["delta"] = delta
	var measured_flag: int = 0
	if measured:
		measured_flag = 1
	if absf(delta) < 0.001 and _measured[item_index] == measured_flag:
		return report

	var item_bottom: float = _offsets[item_index] + previous_extent
	if scroll_offset >= 0.0 and item_bottom <= scroll_offset + 0.5:
		report["scroll_adjustment"] = delta

	_extents[item_index] = next_extent
	_measured[item_index] = measured_flag
	_offsets_dirty = true
	report["changed"] = true
	return report


## 把指定条目重置为估算尺寸。
## [br]
## @api public
## [br]
## @param item_index: 条目索引。
## [br]
## @return 重置成功返回 true。
func reset_item_extent(item_index: int) -> bool:
	if not _is_valid_index(item_index):
		return false
	_extents[item_index] = _estimated_item_extent
	_measured[item_index] = 0
	_offsets_dirty = true
	return true


## 获取条目数量。
## [br]
## @api public
## [br]
## @return 当前条目数量。
func get_item_count() -> int:
	return _extents.size()


## 获取条目尺寸。
## [br]
## @api public
## [br]
## @param item_index: 条目索引。
## [br]
## @return 条目尺寸；索引无效时返回 0。
func get_item_extent(item_index: int) -> float:
	if not _is_valid_index(item_index):
		return 0.0
	return _extents[item_index]


## 判断条目尺寸是否来自实测。
## [br]
## @api public
## [br]
## @param item_index: 条目索引。
## [br]
## @return 已实测返回 true。
func is_item_measured(item_index: int) -> bool:
	if not _is_valid_index(item_index):
		return false
	return _measured[item_index] == 1


## 获取条目顶部偏移。
## [br]
## @api public
## [br]
## @param item_index: 条目索引。
## [br]
## @return 条目顶部偏移；索引无效时返回 0。
func get_item_offset(item_index: int) -> float:
	if not _is_valid_index(item_index):
		return 0.0
	_ensure_offsets()
	return _offsets[item_index]


## 获取内容总尺寸。
## [br]
## @api public
## [br]
## @param include_trailing_padding: 是否包含 trailing_padding。
## [br]
## @return 内容总尺寸。
func get_content_extent(include_trailing_padding: bool = true) -> float:
	_ensure_offsets()
	var extra_extent: float = 0.0
	if include_trailing_padding and _extents.size() > 0:
		extra_extent = _trailing_padding
	return _content_extent + extra_extent


## 计算当前滚动窗口内应被物化的条目范围。
## [br]
## @api public
## [br]
## @param scroll_offset: 当前滚动偏移。
## [br]
## @param viewport_extent: 视口尺寸。
## [br]
## @return Vector2i(start, end)，end 为不包含的结束索引。
func get_visible_range(scroll_offset: float, viewport_extent: float) -> Vector2i:
	if _extents.is_empty():
		return Vector2i.ZERO
	_ensure_offsets()
	var scroll_top: float = maxf(scroll_offset, 0.0)
	var scroll_bottom: float = scroll_top + maxf(viewport_extent, 0.0)
	var start_index: int = _search_first_bottom_after(scroll_top)
	var end_index: int = _search_first_top_at_or_after(scroll_bottom)
	start_index = maxi(start_index - _overscan_items, 0)
	end_index = mini(end_index + _overscan_items, _extents.size())
	if end_index < start_index:
		end_index = start_index
	return Vector2i(start_index, end_index)


## 获取当前滚动窗口内的条目布局记录。
## [br]
## @api public
## [br]
## @param scroll_offset: 当前滚动偏移。
## [br]
## @param viewport_extent: 视口尺寸。
## [br]
## @return 可见条目记录数组。
## [br]
## @schema return: Array[Dictionary]，每项包含 index、offset、extent 与 measured 字段。
func get_visible_items(scroll_offset: float, viewport_extent: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var visible_range: Vector2i = get_visible_range(scroll_offset, viewport_extent)
	for item_index: int in range(visible_range.x, visible_range.y):
		result.append({
			"index": item_index,
			"offset": get_item_offset(item_index),
			"extent": get_item_extent(item_index),
			"measured": is_item_measured(item_index),
		})
	return result


# --- 私有/辅助方法 ---

func _set_estimated_item_extent(value: float) -> void:
	var next_extent: float = _normalize_item_extent(value)
	if is_equal_approx(_estimated_item_extent, next_extent):
		return
	_estimated_item_extent = next_extent
	for item_index: int in range(_extents.size()):
		if _measured[item_index] == 0:
			_extents[item_index] = next_extent
	_offsets_dirty = true


func _ensure_offsets() -> void:
	if not _offsets_dirty and _offsets.size() == _extents.size() + 1:
		return
	var _offsets_resize_result: int = _offsets.resize(_extents.size() + 1)
	var running: float = 0.0
	for item_index: int in range(_extents.size()):
		_offsets[item_index] = running
		running += _extents[item_index]
	_offsets[_extents.size()] = running
	_content_extent = running
	_offsets_dirty = false


func _search_first_bottom_after(offset: float) -> int:
	if _extents.is_empty():
		return 0
	var low: int = 0
	var high: int = _extents.size() - 1
	var result: int = _extents.size()
	while low <= high:
		var middle: int = floori(float(low + high) * 0.5)
		if _offsets[middle + 1] > offset:
			result = middle
			high = middle - 1
		else:
			low = middle + 1
	return result


func _search_first_top_at_or_after(offset: float) -> int:
	if _extents.is_empty():
		return 0
	var low: int = 0
	var high: int = _extents.size() - 1
	var result: int = _extents.size()
	while low <= high:
		var middle: int = floori(float(low + high) * 0.5)
		if _offsets[middle] >= offset:
			result = middle
			high = middle - 1
		else:
			low = middle + 1
	return result


func _is_valid_index(item_index: int) -> bool:
	return item_index >= 0 and item_index < _extents.size()


func _normalize_item_extent(value: float) -> float:
	return maxf(value, MIN_ITEM_EXTENT)
