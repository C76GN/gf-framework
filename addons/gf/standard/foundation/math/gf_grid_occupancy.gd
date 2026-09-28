## GFGridOccupancy: 网格占用与预约数据结构。
##
## 适合格子移动、战棋、推箱子和解谜类玩法在 System 中跟踪运行时占用。
## 它不负责路径查找、碰撞或胜负规则。
## 占用变更会先完整提交内部映射，再同步发出通知；通知回调可以查询已提交状态，
## 但通知期间重入调用本类型的写入方法会失败关闭，避免嵌套修改破坏容量与双向索引。
## receiver 只接受 Object、非空 StringName、非空 String 或 int 稳定身份；可变复合值
## 和其他 Variant 类型失败关闭。公开信号只描述实际状态变化，成功恒等操作不发信号。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFGridOccupancy
extends RefCounted


# --- 信号 ---

## 接收者实际新建占用或移动到其他格子时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Object, non-empty StringName, non-empty String, or int stable identity.
## [br]
## @param cell: 格子坐标。
signal cell_occupied(receiver: Variant, cell: Vector2i)

## 接收者的既有占用实际释放时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Object, non-empty StringName, non-empty String, int, or null for an expired weak Object.
## [br]
## @param cell: 格子坐标。
signal cell_released(receiver: Variant, cell: Vector2i)

## 接收者实际新建预约或移动预约到其他格子时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Object, non-empty StringName, non-empty String, or int stable identity.
## [br]
## @param cell: 格子坐标。
signal cell_reserved(receiver: Variant, cell: Vector2i)

## 接收者的既有预约实际释放时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Object, non-empty StringName, non-empty String, int, or null for an expired weak Object.
## [br]
## @param cell: 格子坐标。
signal reservation_released(receiver: Variant, cell: Vector2i)


# --- 常量 ---

## 未建立占用或预约时使用的格子哨兵值。
## [br]
## @api private
const _INVALID_CELL: Vector2i = Vector2i(-1, -1)

## 占用通知队列中的占用信号名称。
## [br]
## @api private
const _NOTIFICATION_CELL_OCCUPIED: StringName = &"cell_occupied"

## 占用通知队列中的释放信号名称。
## [br]
## @api private
const _NOTIFICATION_CELL_RELEASED: StringName = &"cell_released"

## 预约通知队列中的预约信号名称。
## [br]
## @api private
const _NOTIFICATION_CELL_RESERVED: StringName = &"cell_reserved"

## 预约通知队列中的释放信号名称。
## [br]
## @api private
const _NOTIFICATION_RESERVATION_RELEASED: StringName = &"reservation_released"


# --- 公共变量 ---

## 网格尺寸，默认为 [constant Vector2i.ZERO]。小于等于 0 的维度会让所有格子视为越界。
## 直接赋值会像 configure() 一样清空现有占用与预约；通知期间的赋值会失败关闭。
## [br]
## @api public
## [br]
## @since 10.0.0
var grid_size: Vector2i:
	get:
		return _grid_size
	set(value):
		_set_grid_size(value)

## 单格允许的最大占用数量，默认为 1，最小为 1。
## 直接赋值会像 configure() 一样清空现有占用与预约；通知期间的赋值会失败关闭。
## [br]
## @api public
## [br]
## @since 10.0.0
var max_occupants_per_cell: int:
	get:
		return _max_occupants_per_cell
	set(value):
		_set_max_occupants_per_cell(value)


# --- 私有变量 ---

## 将格子映射到其占用接收者键数组。
## [br]
## @api private
var _cell_occupants: Dictionary = {}

## 将接收者键映射到占用记录。
## [br]
## @api private
var _receiver_records: Dictionary = {}

## 将已预约格子映射到预约接收者键。
## [br]
## @api private
var _cell_reservations: Dictionary = {}

## 将预约接收者键反向映射到其格子。
## [br]
## @api private
var _receiver_reservations: Dictionary = {}

## 将预约接收者键映射到对应的接收者记录。
## [br]
## @api private
var _reservation_records: Dictionary = {}

## 网格尺寸属性的内部存储。
## [br]
## @api private
var _grid_size: Vector2i = Vector2i.ZERO

## 每格最大占用数属性的内部存储。
## [br]
## @api private
var _max_occupants_per_cell: int = 1

## 标记占用/预约状态更新与通知发送是否正在进行。
## [br]
## @api private
var _mutation_in_progress: bool = false


# --- Godot 生命周期方法 ---

func _init(p_grid_size: Vector2i = Vector2i.ZERO, p_max_occupants_per_cell: int = 1) -> void:
	_grid_size = p_grid_size
	_max_occupants_per_cell = maxi(p_max_occupants_per_cell, 1)


# --- 公共方法 ---

## 设置网格参数并清空占用。
## [br]
## @api public
## [br]
## @param p_grid_size: 网格尺寸。
## [br]
## @param p_max_occupants_per_cell: 单格最大占用数量。
func configure(p_grid_size: Vector2i, p_max_occupants_per_cell: int = 1) -> void:
	if not _begin_mutation(&"configure"):
		return

	_grid_size = p_grid_size
	_max_occupants_per_cell = maxi(p_max_occupants_per_cell, 1)
	_clear_records()
	_finish_mutation([])


## 检查格子是否在边界内。
## [br]
## @api public
## [br]
## @param cell: 格子坐标。
## [br]
## @return 在边界内返回 true。
func is_in_bounds(cell: Vector2i) -> bool:
	return GFGridCoordinateMath2D.is_in_bounds(cell, grid_size)


## 检查接收者是否可以占用格子。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Object, non-empty StringName, non-empty String, or int stable identity.
## [br]
## @param cell: 格子坐标。
## [br]
## @return 可占用时返回 true。
func can_occupy(receiver: Variant, cell: Vector2i) -> bool:
	var receiver_key: String = _make_receiver_key(receiver)
	return _can_occupy_key_current(receiver_key, cell, true)


## 获取当前被占用的格子快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 被至少一个接收者占用的格子数组，按 y/x 稳定顺序返回。
func get_occupied_cells() -> Array[Vector2i]:
	return _collect_occupied_cells()


## 获取当前被预约的格子快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 被接收者预约的格子数组，按 y/x 稳定顺序返回。
func get_reserved_cells() -> Array[Vector2i]:
	return _collect_reserved_cells()


## 获取指定接收者当前可占用的格子。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Object, non-empty StringName, non-empty String, or int stable identity.
## [br]
## @return 当前可被该接收者占用的格子数组，按 y/x 稳定顺序返回。
func get_occupiable_cells(receiver: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if grid_size.x <= 0 or grid_size.y <= 0:
		return result
	var receiver_key: String = _make_receiver_key(receiver)
	if receiver_key.is_empty():
		return result

	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			if _can_occupy_key_current(receiver_key, cell, true):
				result.append(cell)
	return result


## 占用格子；已有其他格占用时先移动，已占用目标格时成功且不发信号。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Object, non-empty StringName, non-empty String, or int stable identity.
## [br]
## @param cell: 格子坐标。
## [br]
## @return 成功时返回 true。
func occupy(receiver: Variant, cell: Vector2i) -> bool:
	if not _begin_mutation(&"occupy"):
		return false

	var notifications: Array[Dictionary] = []
	_prune_invalid_records(notifications)
	var receiver_key: String = _make_receiver_key(receiver)
	if not _can_occupy_key_current(receiver_key, cell, true):
		_finish_mutation(notifications)
		return false

	var current_record: Dictionary = _get_record(_receiver_records, receiver_key)
	var current_cell: Vector2i = _get_record_cell(current_record)
	if current_cell == cell:
		_finish_mutation(notifications)
		return true
	if current_cell != _INVALID_CELL:
		_remove_occupancy_by_key(receiver_key, notifications, true)

	var occupants: Array = _get_or_create_occupant_keys(cell)
	if not occupants.has(receiver_key):
		occupants.append(receiver_key)

	_receiver_records[receiver_key] = _make_receiver_record(receiver, cell)
	_append_notification(notifications, _NOTIFICATION_CELL_OCCUPIED, receiver, cell)
	_finish_mutation(notifications)
	return true


## 释放接收者当前占用。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Object, non-empty StringName, non-empty String, or int stable identity.
func release(receiver: Variant) -> void:
	if not _begin_mutation(&"release"):
		return

	var notifications: Array[Dictionary] = []
	var receiver_key: String = _make_receiver_key(receiver)
	_remove_occupancy_by_key(receiver_key, notifications, true)
	_finish_mutation(notifications)


## 释放指定格子的所有占用。
## [br]
## @api public
## [br]
## @param cell: 格子坐标。
func release_cell(cell: Vector2i) -> void:
	if not _begin_mutation(&"release_cell"):
		return

	var notifications: Array[Dictionary] = []
	var occupants: Array = _get_occupant_keys(cell).duplicate()
	for receiver_key: String in occupants:
		_remove_occupancy_by_key(receiver_key, notifications, true)
	_finish_mutation(notifications)


## 预约格子；已有其他预约时先移动，已有效预约目标格时成功且不发释放或预约信号。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Object, non-empty StringName, non-empty String, or int stable identity.
## [br]
## @param cell: 格子坐标。
## [br]
## @return 成功时返回 true。
func reserve_cell(receiver: Variant, cell: Vector2i) -> bool:
	if not _begin_mutation(&"reserve_cell"):
		return false

	var notifications: Array[Dictionary] = []
	_prune_invalid_records(notifications)
	var receiver_key: String = _make_receiver_key(receiver)
	if not _can_occupy_key_current(receiver_key, cell):
		_finish_mutation(notifications)
		return false

	var current_cell: Vector2i = _get_dictionary_vector2i(
		_receiver_reservations,
		receiver_key,
		_INVALID_CELL
	)
	if current_cell == cell and _cell_has_valid_reservation(cell):
		_finish_mutation(notifications)
		return true
	if current_cell != _INVALID_CELL:
		_remove_reservation_by_key(receiver_key, notifications, true)

	_cell_reservations[cell] = receiver_key
	_receiver_reservations[receiver_key] = cell
	_reservation_records[receiver_key] = _make_receiver_record(receiver, cell)
	_append_notification(notifications, _NOTIFICATION_CELL_RESERVED, receiver, cell)
	_finish_mutation(notifications)
	return true


## 将接收者预约确认成占用。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Object, non-empty StringName, non-empty String, or int stable identity.
## [br]
## @return 成功时返回 true。
func confirm_reservation(receiver: Variant) -> bool:
	if not _begin_mutation(&"confirm_reservation"):
		return false

	var notifications: Array[Dictionary] = []
	_prune_invalid_records(notifications)
	var receiver_key: String = _make_receiver_key(receiver)
	if not _receiver_reservations.has(receiver_key):
		_finish_mutation(notifications)
		return false

	var cell: Vector2i = _get_dictionary_vector2i(
		_receiver_reservations,
		receiver_key,
		_INVALID_CELL
	)
	if not _can_occupy_key_current(receiver_key, cell):
		_finish_mutation(notifications)
		return false

	_remove_reservation_by_key(receiver_key, notifications, true)
	var current_record: Dictionary = _get_record(_receiver_records, receiver_key)
	var current_cell: Vector2i = _get_record_cell(current_record)
	if current_cell == cell:
		_finish_mutation(notifications)
		return true
	if current_cell != _INVALID_CELL:
		_remove_occupancy_by_key(receiver_key, notifications, true)

	var occupants: Array = _get_or_create_occupant_keys(cell)
	if not occupants.has(receiver_key):
		occupants.append(receiver_key)
	_receiver_records[receiver_key] = _make_receiver_record(receiver, cell)
	_append_notification(notifications, _NOTIFICATION_CELL_OCCUPIED, receiver, cell)
	_finish_mutation(notifications)
	return true


## 释放接收者预约。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Object, non-empty StringName, non-empty String, or int stable identity.
func release_reservation(receiver: Variant) -> void:
	if not _begin_mutation(&"release_reservation"):
		return

	var notifications: Array[Dictionary] = []
	var receiver_key: String = _make_receiver_key(receiver)
	_remove_reservation_by_key(receiver_key, notifications, true)
	_finish_mutation(notifications)


## 检查格子是否有占用。
## [br]
## @api public
## [br]
## @param cell: 格子坐标。
## [br]
## @return 有占用时返回 true。
func is_cell_occupied(cell: Vector2i) -> bool:
	return not get_cell_occupants(cell).is_empty()


## 检查格子是否被预约。
## [br]
## @api public
## [br]
## @param cell: 格子坐标。
## [br]
## @return 被预约时返回 true。
func is_cell_reserved(cell: Vector2i) -> bool:
	return _cell_has_valid_reservation(cell)


## 获取格子中的所有接收者。
## [br]
## @api public
## [br]
## @param cell: 格子坐标。
## [br]
## @return 接收者数组。
## [br]
## @schema return: Array receiver values restored from occupancy records.
func get_cell_occupants(cell: Vector2i) -> Array[Variant]:
	var result: Array[Variant] = []
	for receiver_key: String in _get_occupant_keys(cell):
		var record: Dictionary = _get_record(_receiver_records, receiver_key)
		if _record_is_valid(record) and _get_record_cell(record) == cell:
			result.append(_record_to_receiver(record))
	return result


## 获取格子中的第一个接收者。
## [br]
## @api public
## [br]
## @param cell: 格子坐标。
## [br]
## @return 接收者；不存在时返回 null。
## [br]
## @schema return: Variant receiver value restored from the occupancy record.
func get_cell_occupant(cell: Vector2i) -> Variant:
	var occupants: Array[Variant] = get_cell_occupants(cell)
	return occupants[0] if not occupants.is_empty() else null


## 获取接收者当前占用格。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Object, non-empty StringName, non-empty String, or int stable identity.
## [br]
## @return 格子坐标；未占用时返回 Vector2i(-1, -1)。
func get_receiver_cell(receiver: Variant) -> Vector2i:
	var receiver_key: String = _make_receiver_key(receiver)
	var record: Dictionary = _get_record(_receiver_records, receiver_key)
	if record.is_empty():
		return _INVALID_CELL
	if not _record_is_valid(record):
		return _INVALID_CELL
	return _get_record_cell(record)


## 清理已释放 Object 接收者。
## [br]
## @api public
func prune_invalid_receivers() -> void:
	if not _begin_mutation(&"prune_invalid_receivers"):
		return

	var notifications: Array[Dictionary] = []
	_prune_invalid_records(notifications)
	_finish_mutation(notifications)


## 清空占用和预约。
## [br]
## @api public
func clear() -> void:
	if not _begin_mutation(&"clear"):
		return

	_clear_records()
	_finish_mutation([])


# --- 私有/辅助方法 ---

## 拒绝通知期间的重入写入并记录错误，否则进入变更状态。
## [br]
## @api private
func _begin_mutation(operation_name: StringName) -> bool:
	if _mutation_in_progress:
		push_error(
			"[GFGridOccupancy][grid_occupancy.reentrant_mutation] Rejected %s: reentrant mutation is not allowed during occupancy transaction notifications."
			% operation_name
		)
		return false

	_mutation_in_progress = true
	return true


## 网格尺寸变化时进入变更状态、更新属性并清空全部记录。
## [br]
## @api private
func _set_grid_size(value: Vector2i) -> void:
	if value == _grid_size:
		return
	if not _begin_mutation(&"grid_size"):
		return
	_grid_size = value
	_clear_records()
	_finish_mutation([])


## 将最大占用数限制为至少 1；值变化时清空全部记录。
## [br]
## @api private
func _set_max_occupants_per_cell(value: int) -> void:
	var normalized_value: int = maxi(value, 1)
	if normalized_value == _max_occupants_per_cell:
		return
	if not _begin_mutation(&"max_occupants_per_cell"):
		return
	_max_occupants_per_cell = normalized_value
	_clear_records()
	_finish_mutation([])


## 按队列顺序发出已提交变更通知，并在通知循环结束后清除变更标记。
## [br]
## @api private
func _finish_mutation(notifications: Array[Dictionary]) -> void:
	for notification_data: Dictionary in notifications:
		var notification_name: StringName = GFVariantData.get_option_string_name(
			notification_data,
			"name"
		)
		var receiver: Variant = GFVariantData.get_option_value(notification_data, "receiver")
		var cell: Vector2i = _get_dictionary_vector2i(
			notification_data,
			"cell",
			_INVALID_CELL
		)
		match notification_name:
			_NOTIFICATION_CELL_OCCUPIED:
				cell_occupied.emit(receiver, cell)
			_NOTIFICATION_CELL_RELEASED:
				cell_released.emit(receiver, cell)
			_NOTIFICATION_CELL_RESERVED:
				cell_reserved.emit(receiver, cell)
			_NOTIFICATION_RESERVATION_RELEASED:
				reservation_released.emit(receiver, cell)

	_mutation_in_progress = false


## 将信号名称、接收者和格子封装为通知字典追加到队列。
## [br]
## @api private
func _append_notification(
	notifications: Array[Dictionary],
	notification_name: StringName,
	receiver: Variant,
	cell: Vector2i
) -> void:
	notifications.append({
		"name": notification_name,
		"receiver": receiver,
		"cell": cell,
	})


## 清空占用、预约及其正反向索引记录。
## [br]
## @api private
func _clear_records() -> void:
	_cell_occupants.clear()
	_receiver_records.clear()
	_cell_reservations.clear()
	_receiver_reservations.clear()
	_reservation_records.clear()


## 读取格子的占用键数组；缺失或不可转换时得到空数组。
## [br]
## @api private
func _get_occupant_keys(cell: Vector2i) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(_cell_occupants, cell, []))


## 返回格子的现有占用键数组，或创建并存入新的空数组。
## [br]
## @api private
func _get_or_create_occupant_keys(cell: Vector2i) -> Array:
	if _cell_occupants.has(cell):
		var value: Variant = _cell_occupants[cell]
		if value is Array:
			var occupants: Array = value
			return occupants
	var new_occupants: Array = []
	_cell_occupants[cell] = new_occupants
	return new_occupants


## 按当前有效占用与预约判断资格；allow_idempotent_occupant 允许已有占用者在检查他人预约之前成功返回。
## 非幂等路径先拒绝他人的有效预约，再接受自身既有占用或剩余容量。
## [br]
## @api private
func _can_occupy_key_current(
	receiver_key: String,
	cell: Vector2i,
	allow_idempotent_occupant: bool = false
) -> bool:
	if not is_in_bounds(cell):
		return false
	if receiver_key.is_empty():
		return false

	var valid_occupant_count: int = 0
	var receiver_already_occupies: bool = false
	for occupant_key: String in _get_occupant_keys(cell):
		var record: Dictionary = _get_record(_receiver_records, occupant_key)
		if not _record_is_valid(record) or _get_record_cell(record) != cell:
			continue
		if occupant_key == receiver_key:
			receiver_already_occupies = true
		else:
			valid_occupant_count += 1
	if allow_idempotent_occupant and receiver_already_occupies:
		return true

	var reserved_by: String = GFVariantData.get_option_string(_cell_reservations, cell, "")
	if (
		not reserved_by.is_empty()
		and _reservation_is_valid_for_cell(reserved_by, cell)
		and reserved_by != receiver_key
	):
		return false
	if receiver_already_occupies:
		return true
	return valid_occupant_count < max_occupants_per_cell


## 按 y/x 顺序收集至少有一个有效占用记录的网格内格子。
## [br]
## @api private
func _collect_occupied_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if grid_size.x <= 0 or grid_size.y <= 0:
		return result

	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			if _cell_has_valid_occupant(cell):
				result.append(cell)
	return result


## 按 y/x 顺序收集当前有效预约所在的网格内格子。
## [br]
## @api private
func _collect_reserved_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if grid_size.x <= 0 or grid_size.y <= 0:
		return result

	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			if _cell_has_valid_reservation(cell):
				result.append(cell)
	return result


## 检查格子占用键是否对应有效且记录在同一格的接收者。
## [br]
## @api private
func _cell_has_valid_occupant(cell: Vector2i) -> bool:
	for receiver_key: String in _get_occupant_keys(cell):
		var record: Dictionary = _get_record(_receiver_records, receiver_key)
		if _record_is_valid(record) and _get_record_cell(record) == cell:
			return true
	return false


## 从格子预约索引取出接收者键并验证双向预约记录。
## [br]
## @api private
func _cell_has_valid_reservation(cell: Vector2i) -> bool:
	var receiver_key: String = GFVariantData.get_option_string(
		_cell_reservations,
		cell,
		""
	)
	return _reservation_is_valid_for_cell(receiver_key, cell)


## 验证预约记录有效、记录格子匹配且接收者反向索引指回该格。
## [br]
## @api private
func _reservation_is_valid_for_cell(receiver_key: String, cell: Vector2i) -> bool:
	if receiver_key.is_empty():
		return false

	var record: Dictionary = _get_record(_reservation_records, receiver_key)
	if not _record_is_valid(record) or _get_record_cell(record) != cell:
		return false
	return (
		_get_dictionary_vector2i(_receiver_reservations, receiver_key, _INVALID_CELL)
		== cell
	)


## 委托空间查询身份工具为接收者生成索引键。
## [br]
## @api private
func _make_receiver_key(receiver: Variant) -> String:
	return GFSpatialQueryIdentity.make_key(receiver)


## 为 Object 保存 WeakRef，为其他接收者值保存直接值，并记录格子。
## [br]
## @api private
func _make_receiver_record(receiver: Variant, cell: Vector2i) -> Dictionary:
	if receiver is Object:
		return {
			"receiver_ref": weakref(receiver),
			"receiver": null,
			"cell": cell,
		}

	return {
		"receiver_ref": null,
		"receiver": receiver,
		"cell": cell,
	}


## 从记录解引用 WeakRef，或返回记录中的直接接收者值。
## [br]
## @api private
func _record_to_receiver(record: Dictionary) -> Variant:
	var receiver_ref_variant: Variant = GFVariantData.get_option_value(record, "receiver_ref")
	if receiver_ref_variant is WeakRef:
		var receiver_ref: WeakRef = receiver_ref_variant
		return receiver_ref.get_ref()
	return GFVariantData.get_option_value(record, "receiver")


## 空记录无效；WeakRef 记录仅在仍能取得对象时有效。
## [br]
## @api private
func _record_is_valid(record: Dictionary) -> bool:
	if record.is_empty():
		return false

	var receiver_ref_variant: Variant = GFVariantData.get_option_value(record, "receiver_ref")
	if receiver_ref_variant is WeakRef:
		var receiver_ref: WeakRef = receiver_ref_variant
		return receiver_ref.get_ref() != null
	return true


## 找出失效接收者键并移除其预约和占用，同时追加释放通知。
## [br]
## @api private
func _prune_invalid_records(notifications: Array[Dictionary]) -> void:
	var occupancy_keys: Array[String] = []
	for receiver_key: String in _receiver_records.keys():
		var record: Dictionary = _get_record(_receiver_records, receiver_key)
		if not _record_is_valid(record):
			occupancy_keys.append(receiver_key)

	for receiver_key: String in occupancy_keys:
		_remove_reservation_by_key(receiver_key, notifications, true)
		_remove_occupancy_by_key(receiver_key, notifications, true)

	var reservation_keys: Array[String] = []
	for receiver_key: String in _reservation_records.keys():
		var record: Dictionary = _get_record(_reservation_records, receiver_key)
		if not _record_is_valid(record):
			reservation_keys.append(receiver_key)

	for receiver_key: String in reservation_keys:
		_remove_reservation_by_key(receiver_key, notifications, true)


## 按接收者键移除占用索引和记录，并可排队占用释放通知。
## [br]
## @api private
func _remove_occupancy_by_key(
	receiver_key: String,
	notifications: Array[Dictionary],
	emit_notification: bool
) -> void:
	var record: Dictionary = _get_record(_receiver_records, receiver_key)
	if record.is_empty():
		return

	var cell: Vector2i = _get_record_cell(record)
	var receiver: Variant = _record_to_receiver(record)
	_release_cell_occupant_key(cell, receiver_key)

	_erase_dictionary_key(_receiver_records, receiver_key)
	if emit_notification:
		_append_notification(
			notifications,
			_NOTIFICATION_CELL_RELEASED,
			receiver,
			cell
		)


## 按接收者键移除预约正反向索引，并可排队预约释放通知。
## [br]
## @api private
func _remove_reservation_by_key(
	receiver_key: String,
	notifications: Array[Dictionary],
	emit_notification: bool
) -> void:
	if not _receiver_reservations.has(receiver_key):
		_erase_dictionary_key(_reservation_records, receiver_key)
		return

	var cell: Vector2i = _get_dictionary_vector2i(
		_receiver_reservations,
		receiver_key,
		_INVALID_CELL
	)
	var record: Dictionary = _get_record(_reservation_records, receiver_key)
	var receiver: Variant = null
	if not record.is_empty():
		receiver = _record_to_receiver(record)
	_erase_dictionary_key(_receiver_reservations, receiver_key)
	if GFVariantData.get_option_string(_cell_reservations, cell, "") == receiver_key:
		_erase_dictionary_key(_cell_reservations, cell)
	_erase_dictionary_key(_reservation_records, receiver_key)
	if emit_notification:
		_append_notification(
			notifications,
			_NOTIFICATION_RESERVATION_RELEASED,
			receiver,
			cell
		)


## 从记录映射读取接收者条目并转换为 Dictionary。
## [br]
## @api private
func _get_record(records: Dictionary, receiver_key: String) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(records, receiver_key, {}))


## 从接收者记录读取格子坐标，缺失或类型不符时返回哨兵值。
## [br]
## @api private
func _get_record_cell(record: Dictionary) -> Vector2i:
	return _get_dictionary_vector2i(record, "cell", _INVALID_CELL)


## 从格子的占用键数组移除指定键，数组清空时删除该格子索引。
## [br]
## @api private
func _release_cell_occupant_key(cell: Vector2i, receiver_key: String) -> void:
	if not _cell_occupants.has(cell):
		return
	var occupants: Array = _get_occupant_keys(cell)
	_erase_array_value(occupants, receiver_key)
	if occupants.is_empty():
		_erase_dictionary_key(_cell_occupants, cell)


## 从字典读取 Vector2i；缺失或类型不符时返回 fallback。
## [br]
## @api private
func _get_dictionary_vector2i(source: Dictionary, key: Variant, fallback: Vector2i) -> Vector2i:
	var value: Variant = GFVariantData.get_option_value(source, key, fallback)
	if value is Vector2i:
		var vector: Vector2i = value
		return vector
	return fallback


## 删除字典中的指定键；忽略 erase 返回的是否存在标记。
## [br]
## @api private
func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var erased: bool = target.erase(key)
	if erased:
		return


## 从数组中删除与 value 匹配的元素。
## [br]
## @api private
func _erase_array_value(target: Array, value: Variant) -> void:
	target.erase(value)
