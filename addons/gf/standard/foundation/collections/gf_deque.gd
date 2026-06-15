## GFDeque: 通用双端队列。
##
## 使用环形数组保存队列内容，支持从头尾 O(1) 追加、读取和移除。
## 它只维护元素顺序和容量，不解释任务、历史、动画或业务载荷语义。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 5.0.0
class_name GFDeque
extends RefCounted


# --- 常量 ---

## 默认底层容量。
## [br]
## @api public
## [br]
## @since 5.0.0
const DEFAULT_CAPACITY: int = 8


# --- 私有变量 ---

var _data: Array = []
var _front_index: int = 0
var _count: int = 0


# --- Godot 生命周期方法 ---

func _init(initial_capacity: int = DEFAULT_CAPACITY) -> void:
	var _resize_result: int = _data.resize(maxi(initial_capacity, 1))


# --- 公共方法 ---

## 从数组创建双端队列。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param values: 按队列顺序写入的初始元素。
## [br]
## @param initial_capacity: 初始容量；小于元素数量时会自动扩容。
## [br]
## @return 新双端队列；实际对象类型为 GFDeque。
## [br]
## @schema values: Array of queue values copied by reference.
## [br]
## @schema return: RefCounted GFDeque instance.
static func from_array(values: Array, initial_capacity: int = 0) -> RefCounted:
	var deque: GFDeque = GFDeque.new(maxi(maxi(initial_capacity, values.size()), DEFAULT_CAPACITY))
	for value: Variant in values:
		deque.push_back(value)
	return deque


## 在队头追加元素。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param value: 要追加的元素。
## [br]
## @schema value: Variant queue value.
func push_front(value: Variant) -> void:
	_ensure_capacity(_count + 1)
	_front_index = posmod(_front_index - 1, _data.size())
	_data[_front_index] = value
	_count += 1


## 在队尾追加元素。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param value: 要追加的元素。
## [br]
## @schema value: Variant queue value.
func push_back(value: Variant) -> void:
	_ensure_capacity(_count + 1)
	_data[_physical_index(_count)] = value
	_count += 1


## 移除并返回队头元素。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param default_value: 队列为空时返回的默认值。
## [br]
## @return 队头元素或默认值。
## [br]
## @schema default_value: Variant fallback value.
## [br]
## @schema return: Variant queue value or fallback value.
func pop_front(default_value: Variant = null) -> Variant:
	if _count <= 0:
		return default_value

	var value: Variant = _data[_front_index]
	_data[_front_index] = null
	_count -= 1
	if _count <= 0:
		_front_index = 0
	else:
		_front_index = (_front_index + 1) % _data.size()
	return value


## 移除并返回队尾元素。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param default_value: 队列为空时返回的默认值。
## [br]
## @return 队尾元素或默认值。
## [br]
## @schema default_value: Variant fallback value.
## [br]
## @schema return: Variant queue value or fallback value.
func pop_back(default_value: Variant = null) -> Variant:
	if _count <= 0:
		return default_value

	var index: int = _physical_index(_count - 1)
	var value: Variant = _data[index]
	_data[index] = null
	_count -= 1
	if _count <= 0:
		_front_index = 0
	return value


## 读取队头元素但不移除。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param default_value: 队列为空时返回的默认值。
## [br]
## @return 队头元素或默认值。
## [br]
## @schema default_value: Variant fallback value.
## [br]
## @schema return: Variant queue value or fallback value.
func peek_front(default_value: Variant = null) -> Variant:
	if _count <= 0:
		return default_value
	return _data[_front_index]


## 读取队尾元素但不移除。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param default_value: 队列为空时返回的默认值。
## [br]
## @return 队尾元素或默认值。
## [br]
## @schema default_value: Variant fallback value.
## [br]
## @schema return: Variant queue value or fallback value.
func peek_back(default_value: Variant = null) -> Variant:
	if _count <= 0:
		return default_value
	return _data[_physical_index(_count - 1)]


## 按队列顺序读取元素。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param index: 队列顺序索引；负数从队尾倒数。
## [br]
## @param default_value: 索引越界时返回的默认值。
## [br]
## @return 对应元素或默认值。
## [br]
## @schema default_value: Variant fallback value.
## [br]
## @schema return: Variant queue value or fallback value.
func at(index: int, default_value: Variant = null) -> Variant:
	var normalized_index: int = _normalize_index(index)
	if normalized_index < 0:
		return default_value
	return _data[_physical_index(normalized_index)]


## 按队列顺序替换元素。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param index: 队列顺序索引；负数从队尾倒数。
## [br]
## @param value: 新元素。
## [br]
## @return 替换成功返回 true。
## [br]
## @schema value: Variant queue value.
func set_at(index: int, value: Variant) -> bool:
	var normalized_index: int = _normalize_index(index)
	if normalized_index < 0:
		return false
	_data[_physical_index(normalized_index)] = value
	return true


## 至少保留指定底层容量。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param min_capacity: 最小底层容量。
func reserve(min_capacity: int) -> void:
	_ensure_capacity(maxi(maxi(min_capacity, _count), 1))


## 从队头裁剪多余元素，使队列最多保留 max_size 个元素。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param max_size: 保留数量；小于 0 时不裁剪。
## [br]
## @return 实际移除数量。
func trim_front(max_size: int) -> int:
	if max_size < 0:
		return 0

	var removed_count: int = 0
	while _count > max_size:
		var _removed_value: Variant = pop_front()
		removed_count += 1
	return removed_count


## 从队尾裁剪多余元素，使队列最多保留 max_size 个元素。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param max_size: 保留数量；小于 0 时不裁剪。
## [br]
## @return 实际移除数量。
func trim_back(max_size: int) -> int:
	if max_size < 0:
		return 0

	var removed_count: int = 0
	while _count > max_size:
		var _removed_value: Variant = pop_back()
		removed_count += 1
	return removed_count


## 清空队列。
## [br]
## @api public
## [br]
## @since 5.0.0
func clear() -> void:
	for index: int in range(_count):
		_data[_physical_index(index)] = null
	_count = 0
	_front_index = 0


## 队列是否为空。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 为空返回 true。
func is_empty() -> bool:
	return _count <= 0


## 获取元素数量。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 元素数量。
func size() -> int:
	return _count


## 获取底层容量。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 底层容量。
func capacity() -> int:
	return _data.size()


## 按队列顺序导出数组。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param deep: 为 true 时深拷贝元素中的 Array、Dictionary、Object Resource 等可复制值。
## [br]
## @return 队列元素数组。
## [br]
## @schema return: Array of queue values in front-to-back order.
func to_array(deep: bool = false) -> Array:
	var result: Array = []
	var _resize_result: int = result.resize(_count)
	for index: int in range(_count):
		var value: Variant = _data[_physical_index(index)]
		result[index] = GFVariantData.duplicate_variant(value) if deep else value
	return result


## 复制双端队列。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param deep: 为 true 时深拷贝元素中的 Array、Dictionary、Object Resource 等可复制值。
## [br]
## @return 新双端队列；实际对象类型为 GFDeque。
## [br]
## @schema return: RefCounted GFDeque instance.
func duplicate_deque(deep: bool = false) -> RefCounted:
	var deque: GFDeque = GFDeque.new(capacity())
	for value: Variant in to_array(deep):
		deque.push_back(value)
	return deque


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary with size, capacity, and front_index.
func get_debug_snapshot() -> Dictionary:
	return {
		"size": _count,
		"capacity": capacity(),
		"front_index": _front_index,
	}


# --- 私有/辅助方法 ---

func _ensure_capacity(required_capacity: int) -> void:
	if required_capacity <= _data.size():
		return

	var next_capacity: int = maxi(maxi(_data.size(), DEFAULT_CAPACITY), 1)
	while next_capacity < required_capacity:
		next_capacity *= 2
	_resize_storage(next_capacity)


func _resize_storage(new_capacity: int) -> void:
	var ordered_values: Array = to_array(false)
	_data.clear()
	var _resize_result: int = _data.resize(maxi(maxi(new_capacity, ordered_values.size()), 1))
	_front_index = 0
	_count = ordered_values.size()
	for index: int in range(_count):
		_data[index] = ordered_values[index]


func _physical_index(index: int) -> int:
	return (_front_index + index) % _data.size()


func _normalize_index(index: int) -> int:
	var normalized_index: int = index
	if normalized_index < 0:
		normalized_index = _count + normalized_index
	if normalized_index < 0 or normalized_index >= _count:
		return -1
	return normalized_index
