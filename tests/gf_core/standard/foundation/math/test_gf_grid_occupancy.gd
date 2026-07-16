## 测试 GFGridOccupancy 的格子占用、预约和失效对象清理。
extends GutTest


# --- 私有变量 ---

var _objects: Array[Object] = []


# --- Godot 生命周期方法 ---

func after_each() -> void:
	for object: Object in _objects:
		if is_instance_valid(object):
			object.free()
	_objects.clear()


# --- 测试方法 ---

func test_occupy_moves_receiver_between_cells() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(3, 3))
	var actor: Object = _make_object()

	assert_true(grid.occupy(actor, Vector2i.ZERO), "接收者应能占用有效格子。")
	assert_true(grid.occupy(actor, Vector2i(1, 0)), "重复占用应移动到新格子。")
	assert_false(grid.is_cell_occupied(Vector2i.ZERO), "移动后旧格子应释放。")
	assert_eq(grid.get_receiver_cell(actor), Vector2i(1, 0), "接收者当前位置应更新。")


func test_reservation_blocks_other_receivers_and_can_confirm() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(3, 3))
	var actor_a: Object = _make_object()
	var actor_b: Object = _make_object()

	assert_true(grid.reserve_cell(actor_a, Vector2i(2, 1)), "接收者应能预约空格子。")
	assert_false(grid.can_occupy(actor_b, Vector2i(2, 1)), "其他接收者不应占用已预约格子。")
	assert_true(grid.confirm_reservation(actor_a), "预约应可确认成占用。")
	assert_eq(grid.get_receiver_cell(actor_a), Vector2i(2, 1), "确认后接收者应占用预约格。")
	assert_false(grid.is_cell_reserved(Vector2i(2, 1)), "确认后预约记录应释放。")


func test_max_occupants_per_cell_allows_shared_cells() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(2, 2), 2)

	assert_true(grid.occupy("a", Vector2i.ZERO), "第一个值接收者应能占用格子。")
	assert_true(grid.occupy("b", Vector2i.ZERO), "容量允许时第二个值接收者应能共享格子。")
	assert_false(grid.occupy("c", Vector2i.ZERO), "超过容量后不应继续占用。")
	assert_eq(grid.get_cell_occupants(Vector2i.ZERO).size(), 2, "格子中应只有两个接收者。")


func test_occupied_and_reserved_cell_snapshots_are_stable() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(4, 3))
	var expected_occupied: Array[Vector2i] = [
		Vector2i(3, 0),
		Vector2i(2, 1),
		Vector2i(0, 2),
	]
	var expected_reserved: Array[Vector2i] = [
		Vector2i(1, 0),
	]

	assert_true(grid.occupy("lower", Vector2i(0, 2)), "应能占用后排格。")
	assert_true(grid.occupy("middle", Vector2i(2, 1)), "应能占用中间格。")
	assert_true(grid.occupy("upper", Vector2i(3, 0)), "应能占用前排格。")
	assert_true(grid.reserve_cell("reserved", Vector2i(1, 0)), "应能预约格子。")

	assert_eq(grid.get_occupied_cells(), expected_occupied, "占用快照应按 y/x 稳定排序。")
	assert_eq(grid.get_reserved_cells(), expected_reserved, "预约快照应按 y/x 稳定排序。")


func test_get_occupiable_cells_respects_capacity_and_reservations() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(3, 2), 2)

	assert_true(grid.occupy("full_a", Vector2i(0, 0)), "应能占用容量格。")
	assert_true(grid.occupy("full_b", Vector2i(0, 0)), "容量格应能被第二个接收者占用。")
	assert_true(grid.occupy("partial", Vector2i(1, 0)), "应能占用未满格。")
	assert_true(grid.reserve_cell("reserved_owner", Vector2i(2, 0)), "应能预约空格。")

	var spawn_cells: Array[Vector2i] = grid.get_occupiable_cells("spawn")
	assert_false(spawn_cells.has(Vector2i(0, 0)), "满员格不应出现在可占用列表。")
	assert_true(spawn_cells.has(Vector2i(1, 0)), "未满格应继续可占用。")
	assert_false(spawn_cells.has(Vector2i(2, 0)), "其他接收者预约的格子不应可占用。")
	assert_true(spawn_cells.has(Vector2i(0, 1)), "空格应可占用。")

	var reserved_owner_cells: Array[Vector2i] = grid.get_occupiable_cells("reserved_owner")
	assert_true(reserved_owner_cells.has(Vector2i(2, 0)), "预约所有者应能占用自己的预约格。")


func test_prune_invalid_receiver_releases_stale_reservation() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(2, 2))
	var actor: Node = Node.new()
	var cell: Vector2i = Vector2i(1, 1)

	assert_true(grid.reserve_cell(actor, cell), "应能为对象接收者预约格子。")
	actor.free()
	grid.prune_invalid_receivers()

	assert_false(grid.is_cell_reserved(cell), "对象释放后预约应能被清理。")


func test_prune_invalid_receiver_emits_cell_released() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(2, 2))
	var actor: Node = Node.new()
	var cell: Vector2i = Vector2i(1, 0)
	watch_signals(grid)

	assert_true(grid.occupy(actor, cell), "应能占用格子。")
	actor.free()
	grid.prune_invalid_receivers()

	assert_false(grid.is_cell_occupied(cell), "对象释放后占用应能被清理。")
	assert_signal_emitted(grid, "cell_released", "清理失效对象时也应通知格子释放。")


# --- 私有/辅助方法 ---

func _make_object() -> Object:
	var object: Node = Node.new()
	_objects.append(object)
	return object
