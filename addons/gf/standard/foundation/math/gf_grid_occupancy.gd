## GFGridOccupancy: 网格占用与预约数据结构。
##
## 适合格子移动、战棋、推箱子和解谜类玩法在 System 中跟踪运行时占用。
## 它不负责路径查找、碰撞或胜负规则。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFGridOccupancy
extends RefCounted


# --- 信号 ---

## 接收者占用格子时发出。
## [br]
## @api public
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Variant receiver identity stored by value or weak Object reference.
## [br]
## @param cell: 格子坐标。
signal cell_occupied(receiver: Variant, cell: Vector2i)

## 接收者释放格子时发出。
## [br]
## @api public
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Variant receiver identity stored by value or weak Object reference.
## [br]
## @param cell: 格子坐标。
signal cell_released(receiver: Variant, cell: Vector2i)

## 接收者预约格子时发出。
## [br]
## @api public
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Variant receiver identity stored by value or weak Object reference.
## [br]
## @param cell: 格子坐标。
signal cell_reserved(receiver: Variant, cell: Vector2i)

## 接收者释放预约时发出。
## [br]
## @api public
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Variant receiver identity stored by value or weak Object reference.
## [br]
## @param cell: 格子坐标。
signal reservation_released(receiver: Variant, cell: Vector2i)


# --- 公共变量 ---

## 网格尺寸。小于等于 0 的维度会让所有格子视为越界。
## [br]
## @api public
var grid_size: Vector2i = Vector2i.ZERO

## 单格允许的最大占用数量。
## [br]
## @api public
var max_occupants_per_cell: int = 1


# --- 私有变量 ---

var _cell_occupants: Dictionary = {}
var _receiver_records: Dictionary = {}
var _cell_reservations: Dictionary = {}
var _receiver_reservations: Dictionary = {}
var _reservation_records: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init(p_grid_size: Vector2i = Vector2i.ZERO, p_max_occupants_per_cell: int = 1) -> void:
	grid_size = p_grid_size
	max_occupants_per_cell = maxi(p_max_occupants_per_cell, 1)


# --- 公共方法 ---

## 设置网格参数并清空占用。
## [br]
## @api public
## [br]
## @param p_grid_size: 网格尺寸。
## [br]
## @param p_max_occupants_per_cell: 单格最大占用数量。
func configure(p_grid_size: Vector2i, p_max_occupants_per_cell: int = 1) -> void:
	grid_size = p_grid_size
	max_occupants_per_cell = maxi(p_max_occupants_per_cell, 1)
	clear()


## 检查格子是否在边界内。
## [br]
## @api public
## [br]
## @param cell: 格子坐标。
## [br]
## @return 在边界内返回 true。
func is_in_bounds(cell: Vector2i) -> bool:
	return GFGridMath.is_in_bounds(cell, grid_size)


## 检查接收者是否可以占用格子。
## [br]
## @api public
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Variant receiver identity stored by value or weak Object reference.
## [br]
## @param cell: 格子坐标。
## [br]
## @return 可占用时返回 true。
func can_occupy(receiver: Variant, cell: Vector2i) -> bool:
	prune_invalid_receivers()
	return _can_occupy_after_prune(receiver, cell)


## 获取当前被占用的格子快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 被至少一个接收者占用的格子数组，按 y/x 稳定顺序返回。
func get_occupied_cells() -> Array[Vector2i]:
	prune_invalid_receivers()
	return _collect_cells_with_keys(_cell_occupants)


## 获取当前被预约的格子快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 被接收者预约的格子数组，按 y/x 稳定顺序返回。
func get_reserved_cells() -> Array[Vector2i]:
	prune_invalid_receivers()
	return _collect_cells_with_keys(_cell_reservations)


## 获取指定接收者当前可占用的格子。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Variant receiver identity stored by value or weak Object reference.
## [br]
## @return 当前可被该接收者占用的格子数组，按 y/x 稳定顺序返回。
func get_occupiable_cells(receiver: Variant) -> Array[Vector2i]:
	prune_invalid_receivers()
	var result: Array[Vector2i] = []
	if grid_size.x <= 0 or grid_size.y <= 0:
		return result

	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			if _can_occupy_after_prune(receiver, cell):
				result.append(cell)
	return result


## 占用格子。接收者若已占用其他格子，会先释放旧格子。
## [br]
## @api public
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Variant receiver identity stored by value or weak Object reference.
## [br]
## @param cell: 格子坐标。
## [br]
## @return 成功时返回 true。
func occupy(receiver: Variant, cell: Vector2i) -> bool:
	if not can_occupy(receiver, cell):
		return false

	var receiver_key: String = _make_receiver_key(receiver)
	var current_cell: Vector2i = get_receiver_cell(receiver)
	if current_cell == cell:
		return true
	if current_cell != Vector2i(-1, -1):
		release(receiver)

	var occupants: Array = _get_or_create_occupant_keys(cell)
	if not occupants.has(receiver_key):
		occupants.append(receiver_key)

	_receiver_records[receiver_key] = _make_receiver_record(receiver, cell)
	cell_occupied.emit(receiver, cell)
	return true


## 释放接收者当前占用。
## [br]
## @api public
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Variant receiver identity stored by value or weak Object reference.
func release(receiver: Variant) -> void:
	var receiver_key: String = _make_receiver_key(receiver)
	var record: Dictionary = _get_record(_receiver_records, receiver_key)
	if record.is_empty():
		return

	var cell: Vector2i = _get_record_cell(record)
	_release_cell_occupant_key(cell, receiver_key)

	_erase_dictionary_key(_receiver_records, receiver_key)
	cell_released.emit(receiver, cell)


## 释放指定格子的所有占用。
## [br]
## @api public
## [br]
## @param cell: 格子坐标。
func release_cell(cell: Vector2i) -> void:
	var occupants: Array = _get_occupant_keys(cell).duplicate()
	for receiver_key: String in occupants:
		var record: Dictionary = _get_record(_receiver_records, receiver_key)
		if not record.is_empty():
			release(_record_to_receiver(record))


## 预约格子，防止其他接收者抢占。
## [br]
## @api public
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Variant receiver identity stored by value or weak Object reference.
## [br]
## @param cell: 格子坐标。
## [br]
## @return 成功时返回 true。
func reserve_cell(receiver: Variant, cell: Vector2i) -> bool:
	if not can_occupy(receiver, cell):
		return false

	var receiver_key: String = _make_receiver_key(receiver)
	release_reservation(receiver)
	_cell_reservations[cell] = receiver_key
	_receiver_reservations[receiver_key] = cell
	_reservation_records[receiver_key] = _make_receiver_record(receiver, cell)
	cell_reserved.emit(receiver, cell)
	return true


## 将接收者预约确认成占用。
## [br]
## @api public
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Variant receiver identity stored by value or weak Object reference.
## [br]
## @return 成功时返回 true。
func confirm_reservation(receiver: Variant) -> bool:
	var receiver_key: String = _make_receiver_key(receiver)
	if not _receiver_reservations.has(receiver_key):
		return false

	var cell: Vector2i = _get_dictionary_vector2i(_receiver_reservations, receiver_key, Vector2i(-1, -1))
	release_reservation(receiver)
	return occupy(receiver, cell)


## 释放接收者预约。
## [br]
## @api public
## [br]
## @param receiver: 接收者。
## [br]
## @schema receiver: Variant receiver identity stored by value or weak Object reference.
func release_reservation(receiver: Variant) -> void:
	var receiver_key: String = _make_receiver_key(receiver)
	if not _receiver_reservations.has(receiver_key):
		return

	var cell: Vector2i = _get_dictionary_vector2i(_receiver_reservations, receiver_key, Vector2i(-1, -1))
	_erase_dictionary_key(_receiver_reservations, receiver_key)
	_erase_dictionary_key(_cell_reservations, cell)
	_erase_dictionary_key(_reservation_records, receiver_key)
	reservation_released.emit(receiver, cell)


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
	return _cell_reservations.has(cell)


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
	prune_invalid_receivers()
	var result: Array[Variant] = []
	for receiver_key: String in _get_occupant_keys(cell):
		var record: Dictionary = _get_record(_receiver_records, receiver_key)
		if not record.is_empty():
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
## @param receiver: 接收者。
## [br]
## @schema receiver: Variant receiver identity stored by value or weak Object reference.
## [br]
## @return 格子坐标；未占用时返回 Vector2i(-1, -1)。
func get_receiver_cell(receiver: Variant) -> Vector2i:
	var receiver_key: String = _make_receiver_key(receiver)
	var record: Dictionary = _get_record(_receiver_records, receiver_key)
	if record.is_empty():
		return Vector2i(-1, -1)
	if not _record_is_valid(record):
		release(receiver)
		return Vector2i(-1, -1)
	return _get_record_cell(record)


## 清理已释放 Object 接收者。
## [br]
## @api public
func prune_invalid_receivers() -> void:
	var keys_to_release: Array[String] = []
	for receiver_key: String in _receiver_records.keys():
		var record: Dictionary = _get_record(_receiver_records, receiver_key)
		if not _record_is_valid(record):
			keys_to_release.append(receiver_key)

	for receiver_key: String in keys_to_release:
		_release_by_key(receiver_key, true)

	var reservation_keys_to_release: Array[String] = []
	for receiver_key: String in _reservation_records.keys():
		var record: Dictionary = _get_record(_reservation_records, receiver_key)
		if not _record_is_valid(record):
			reservation_keys_to_release.append(receiver_key)

	for receiver_key: String in reservation_keys_to_release:
		_release_reservation_by_key(receiver_key)


## 清空占用和预约。
## [br]
## @api public
func clear() -> void:
	_cell_occupants.clear()
	_receiver_records.clear()
	_cell_reservations.clear()
	_receiver_reservations.clear()
	_reservation_records.clear()


# --- 私有/辅助方法 ---

func _get_occupant_keys(cell: Vector2i) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(_cell_occupants, cell, []))


func _get_or_create_occupant_keys(cell: Vector2i) -> Array:
	if _cell_occupants.has(cell):
		var value: Variant = _cell_occupants[cell]
		if value is Array:
			var occupants: Array = value
			return occupants
	var new_occupants: Array = []
	_cell_occupants[cell] = new_occupants
	return new_occupants


func _can_occupy_after_prune(receiver: Variant, cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false

	var receiver_key: String = _make_receiver_key(receiver)
	if receiver_key.is_empty():
		return false

	var reserved_by: String = GFVariantData.get_option_string(_cell_reservations, cell, "")
	if not reserved_by.is_empty() and reserved_by != receiver_key:
		return false

	var occupants: Array = _get_occupant_keys(cell)
	if occupants.has(receiver_key):
		return true
	return occupants.size() < max_occupants_per_cell


func _collect_cells_with_keys(source: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if grid_size.x <= 0 or grid_size.y <= 0:
		return result

	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			if source.has(cell):
				result.append(cell)
	return result


func _make_receiver_key(receiver: Variant) -> String:
	if receiver == null:
		return ""
	if receiver is Object:
		var object: Object = receiver
		return "object:%d" % object.get_instance_id()
	return "%d:%s" % [typeof(receiver), str(receiver)]


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


func _record_to_receiver(record: Dictionary) -> Variant:
	var receiver_ref_variant: Variant = GFVariantData.get_option_value(record, "receiver_ref")
	if receiver_ref_variant is WeakRef:
		var receiver_ref: WeakRef = receiver_ref_variant
		return receiver_ref.get_ref()
	return GFVariantData.get_option_value(record, "receiver")


func _record_is_valid(record: Dictionary) -> bool:
	if record.is_empty():
		return false

	var receiver_ref_variant: Variant = GFVariantData.get_option_value(record, "receiver_ref")
	if receiver_ref_variant is WeakRef:
		var receiver_ref: WeakRef = receiver_ref_variant
		return receiver_ref.get_ref() != null
	return true


func _release_by_key(receiver_key: String, emit_cell_signal: bool = false) -> void:
	var record: Dictionary = _get_record(_receiver_records, receiver_key)
	if record.is_empty():
		return

	var cell: Vector2i = _get_record_cell(record)
	var receiver: Variant = _record_to_receiver(record)
	_release_cell_occupant_key(cell, receiver_key)

	_erase_dictionary_key(_receiver_records, receiver_key)
	_release_reservation_by_key(receiver_key)
	if emit_cell_signal:
		cell_released.emit(receiver, cell)


func _release_reservation_by_key(receiver_key: String) -> void:
	if not _receiver_reservations.has(receiver_key):
		_erase_dictionary_key(_reservation_records, receiver_key)
		return

	var cell: Vector2i = _get_dictionary_vector2i(_receiver_reservations, receiver_key, Vector2i(-1, -1))
	var record: Dictionary = _get_record(_reservation_records, receiver_key)
	var receiver: Variant = null
	if not record.is_empty():
		receiver = _record_to_receiver(record)
	_erase_dictionary_key(_receiver_reservations, receiver_key)
	_erase_dictionary_key(_cell_reservations, cell)
	_erase_dictionary_key(_reservation_records, receiver_key)
	reservation_released.emit(receiver, cell)


func _get_record(records: Dictionary, receiver_key: String) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(records, receiver_key, {}))


func _get_record_cell(record: Dictionary) -> Vector2i:
	return _get_dictionary_vector2i(record, "cell", Vector2i(-1, -1))


func _release_cell_occupant_key(cell: Vector2i, receiver_key: String) -> void:
	if not _cell_occupants.has(cell):
		return
	var occupants: Array = _get_occupant_keys(cell)
	_erase_array_value(occupants, receiver_key)
	if occupants.is_empty():
		_erase_dictionary_key(_cell_occupants, cell)


func _get_dictionary_vector2i(source: Dictionary, key: Variant, fallback: Vector2i) -> Vector2i:
	var value: Variant = GFVariantData.get_option_value(source, key, fallback)
	if value is Vector2i:
		var vector: Vector2i = value
		return vector
	return fallback


func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var erased: bool = target.erase(key)
	if erased:
		return


func _erase_array_value(target: Array, value: Variant) -> void:
	target.erase(value)
