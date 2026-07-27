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


func test_occupy_move_commits_before_notifications_and_rejects_reentrant_mutation() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(3, 1))
	var actor_a: Object = _make_object()
	var actor_b: Object = _make_object()
	var source_cell: Vector2i = Vector2i.ZERO
	var target_cell: Vector2i = Vector2i(1, 0)
	var nested_results: Array[bool] = []
	var observed_cells: Array[Vector2i] = []

	assert_true(grid.occupy(actor_a, source_cell), "外层接收者应能建立初始占用。")
	var release_callback: Callable = func(
		_receiver: Variant,
		released_cell: Vector2i
	) -> void:
		if released_cell != source_cell:
			return
		observed_cells.append(grid.get_receiver_cell(actor_a))
		nested_results.append(grid.occupy(actor_b, target_cell))
	var connect_error: Error = grid.cell_released.connect(
		release_callback
	) as Error
	assert_eq(connect_error, OK, "测试应能监听格子释放通知。")

	assert_true(grid.occupy(actor_a, target_cell), "外层移动事务应成功提交。")

	assert_eq(observed_cells, [target_cell], "通知回调必须观察到已经完整提交的外层状态。")
	assert_eq(nested_results, [false], "通知期的重入写入必须失败关闭。")
	assert_push_error_count(1, "被拒绝的重入写入应报告一次明确错误。")
	assert_false(grid.is_cell_occupied(source_cell), "外层移动后旧格子应为空。")
	assert_eq(grid.get_cell_occupants(target_cell), [actor_a], "目标格不得因重入超过容量。")
	grid.cell_released.disconnect(release_callback)


func test_reservation_blocks_other_receivers_and_can_confirm() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(3, 3))
	var actor_a: Object = _make_object()
	var actor_b: Object = _make_object()

	assert_true(grid.reserve_cell(actor_a, Vector2i(2, 1)), "接收者应能预约空格子。")
	assert_false(grid.can_occupy(actor_b, Vector2i(2, 1)), "其他接收者不应占用已预约格子。")
	assert_true(grid.confirm_reservation(actor_a), "预约应可确认成占用。")
	assert_eq(grid.get_receiver_cell(actor_a), Vector2i(2, 1), "确认后接收者应占用预约格。")
	assert_false(grid.is_cell_reserved(Vector2i(2, 1)), "确认后预约记录应释放。")


func test_supported_receiver_identities_are_distinct_and_reachable() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(4, 1))
	var actor: Object = _make_object()
	var receivers: Array[Variant] = [
		actor,
		&"shared",
		"shared",
		17,
	]

	for index: int in range(receivers.size()):
		var cell: Vector2i = Vector2i(index, 0)
		var receiver: Variant = receivers[index]
		assert_true(grid.occupy(receiver, cell), "受支持的稳定身份应能占用格子。")

	for index: int in range(receivers.size()):
		var cell: Vector2i = Vector2i(index, 0)
		var receiver: Variant = receivers[index]
		assert_eq(grid.get_receiver_cell(receiver), cell, "稳定身份应能查询自己的占用。")
		assert_eq(grid.get_cell_occupants(cell), [receiver], "每种稳定身份都必须使用互异 key。")

	for index: int in range(receivers.size()):
		var cell: Vector2i = Vector2i(index, 0)
		var receiver: Variant = receivers[index]
		grid.release(receiver)
		assert_false(grid.is_cell_occupied(cell), "受支持的稳定身份应能释放自己的占用。")
		assert_eq(grid.get_receiver_cell(receiver), Vector2i(-1, -1))
		for remaining_index: int in range(index + 1, receivers.size()):
			assert_eq(
				grid.get_receiver_cell(receivers[remaining_index]),
				Vector2i(remaining_index, 0),
				"释放一个身份不得让其他稳定身份失去可达性。"
			)


func test_unsupported_receiver_identities_fail_closed() -> void:
	var unsupported_receivers: Array[Variant] = [
		null,
		true,
		1.5,
		"",
		Vector2.ZERO,
		Vector2i.ZERO,
		Rect2(),
		Rect2i(),
		Vector3.ZERO,
		Vector3i.ZERO,
		Transform2D(),
		Vector4.ZERO,
		Vector4i.ZERO,
		Plane(),
		Quaternion(),
		AABB(),
		Basis(),
		Transform3D(),
		Projection(),
		Color.WHITE,
		&"",
		NodePath(),
		RID(),
		Callable(),
		Signal(),
		{},
		[],
		PackedByteArray(),
		PackedInt32Array(),
		PackedInt64Array(),
		PackedFloat32Array(),
		PackedFloat64Array(),
		PackedStringArray(),
		PackedVector2Array(),
		PackedVector3Array(),
		PackedColorArray(),
		PackedVector4Array(),
	]

	for receiver: Variant in unsupported_receivers:
		var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(3, 1), 2)
		var occupied_cell: Vector2i = Vector2i.ZERO
		var reserved_cell: Vector2i = Vector2i(1, 0)
		var candidate_cell: Vector2i = Vector2i(2, 0)
		assert_true(grid.occupy(&"baseline_occupant", occupied_cell))
		assert_true(grid.reserve_cell(&"baseline_reservation", reserved_cell))
		watch_signals(grid)

		assert_false(grid.can_occupy(receiver, candidate_cell))
		assert_true(grid.get_occupiable_cells(receiver).is_empty())
		assert_false(grid.occupy(receiver, candidate_cell))
		assert_false(grid.reserve_cell(receiver, candidate_cell))
		assert_false(grid.confirm_reservation(receiver))
		assert_eq(grid.get_receiver_cell(receiver), Vector2i(-1, -1))
		grid.release(receiver)
		grid.release_reservation(receiver)

		assert_eq(grid.get_receiver_cell(&"baseline_occupant"), occupied_cell)
		assert_eq(grid.get_occupied_cells(), [occupied_cell])
		assert_eq(grid.get_reserved_cells(), [reserved_cell])
		assert_signal_not_emitted(grid, "cell_occupied")
		assert_signal_not_emitted(grid, "cell_released")
		assert_signal_not_emitted(grid, "cell_reserved")
		assert_signal_not_emitted(grid, "reservation_released")


func test_same_cell_reservation_is_successful_without_duplicate_notifications() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i.ONE)
	var receiver: StringName = &"actor"
	watch_signals(grid)

	assert_true(grid.reserve_cell(receiver, Vector2i.ZERO))
	assert_true(grid.reserve_cell(receiver, Vector2i.ZERO))

	assert_signal_emit_count(
		grid,
		"cell_reserved",
		1,
		"重复预约同一格只是成功恒等操作，不得重复发出预约通知。"
	)
	assert_signal_not_emitted(
		grid,
		"reservation_released",
		"重复预约同一格不得伪造释放与重新预约状态变化。"
	)
	assert_true(grid.is_cell_reserved(Vector2i.ZERO))


func test_existing_occupant_remains_idempotent_under_another_reservation() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i.ONE, 2)
	var occupant: StringName = &"occupant"
	var reserver: StringName = &"reserver"
	watch_signals(grid)

	assert_true(grid.occupy(occupant, Vector2i.ZERO))
	assert_true(grid.reserve_cell(reserver, Vector2i.ZERO))
	assert_true(
		grid.can_occupy(occupant, Vector2i.ZERO),
		"第三方预约不得让既有 occupant 的同格恒等查询失败。"
	)
	assert_eq(
		grid.get_occupiable_cells(occupant),
		[Vector2i.ZERO],
		"第三方预约不得从既有 occupant 的可占用格快照中移除当前格。"
	)
	assert_true(
		grid.occupy(occupant, Vector2i.ZERO),
		"第三方预约不得让既有 occupant 的同格恒等提交失败。"
	)

	assert_signal_emit_count(
		grid,
		"cell_occupied",
		1,
		"既有 occupant 的同格恒等提交不得重复发出占用信号。"
	)
	assert_signal_not_emitted(grid, "cell_released")
	assert_eq(grid.get_cell_occupants(Vector2i.ZERO), [occupant])
	assert_true(grid.is_cell_reserved(Vector2i.ZERO))
	assert_false(
		grid.reserve_cell(occupant, Vector2i.ZERO),
		"既有 occupant 不得越权覆盖另一个 receiver 的预约。"
	)
	assert_true(grid.is_cell_reserved(Vector2i.ZERO), "被拒绝的预约不得破坏现有预约。")
	assert_true(grid.confirm_reservation(reserver), "原预约者仍应能确认预约。")
	assert_eq(grid.get_cell_occupants(Vector2i.ZERO), [occupant, reserver])
	assert_false(grid.is_cell_reserved(Vector2i.ZERO))


func test_object_identity_remains_reachable_when_confirmation_callback_mutates_object() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(2, 1))
	var actor: Node = Node.new()
	_objects.append(actor)
	var target_cell: Vector2i = Vector2i(1, 0)
	var observed_cells: Array[Vector2i] = []
	watch_signals(grid)
	var release_callback: Callable = func(
		_receiver: Variant,
		_released_cell: Vector2i
	) -> void:
		actor.set_meta(&"label", "changed")
		observed_cells.append(grid.get_receiver_cell(actor))
	var connect_error: Error = grid.reservation_released.connect(
		release_callback
	) as Error
	assert_eq(connect_error, OK)

	assert_true(grid.reserve_cell(actor, target_cell))
	assert_true(grid.confirm_reservation(actor))

	assert_eq(str(actor.get_meta(&"label")), "changed")
	assert_eq(observed_cells, [target_cell], "回调应观察到已提交且仍可寻址的 Object 占用。")
	assert_eq(grid.get_receiver_cell(actor), target_cell)
	grid.release(actor)
	assert_false(grid.is_cell_occupied(target_cell), "Object 内容变化不得破坏实例身份键。")
	assert_signal_emit_count(grid, "cell_reserved", 1)
	assert_signal_emit_count(grid, "reservation_released", 1)
	assert_signal_emit_count(grid, "cell_occupied", 1)
	assert_signal_emit_count(grid, "cell_released", 1)
	grid.reservation_released.disconnect(release_callback)


func test_confirm_reservation_is_atomic_against_release_notification_reentry() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(2, 1))
	var actor_a: Object = _make_object()
	var actor_b: Object = _make_object()
	var target_cell: Vector2i = Vector2i(1, 0)
	var nested_results: Array[bool] = []

	assert_true(grid.reserve_cell(actor_a, target_cell), "外层接收者应能预约目标格。")
	var release_callback: Callable = func(
		_receiver: Variant,
		released_cell: Vector2i
	) -> void:
		if released_cell == target_cell:
			nested_results.append(grid.occupy(actor_b, target_cell))
	var connect_error: Error = grid.reservation_released.connect(
		release_callback
	) as Error
	assert_eq(connect_error, OK, "测试应能监听预约释放通知。")

	assert_true(grid.confirm_reservation(actor_a), "确认预约应原子提交为占用。")

	assert_eq(nested_results, [false], "预约释放通知不得允许其他接收者抢占提交中的目标格。")
	assert_push_error_count(1, "被拒绝的确认期重入应报告一次明确错误。")
	assert_false(grid.is_cell_reserved(target_cell), "确认后预约记录应被清理。")
	assert_eq(grid.get_cell_occupants(target_cell), [actor_a], "预约所有者应成为唯一占用者。")
	grid.reservation_released.disconnect(release_callback)


func test_reservation_move_is_atomic_against_release_notification_reentry() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(3, 1))
	var actor_a: Object = _make_object()
	var actor_b: Object = _make_object()
	var source_cell: Vector2i = Vector2i.ZERO
	var target_cell: Vector2i = Vector2i(1, 0)
	var nested_results: Array[bool] = []

	assert_true(grid.reserve_cell(actor_a, source_cell), "外层接收者应能建立初始预约。")
	var release_callback: Callable = func(
		_receiver: Variant,
		released_cell: Vector2i
	) -> void:
		if released_cell == source_cell:
			nested_results.append(grid.reserve_cell(actor_b, target_cell))
	var connect_error: Error = grid.reservation_released.connect(
		release_callback
	) as Error
	assert_eq(connect_error, OK, "测试应能监听预约释放通知。")

	assert_true(grid.reserve_cell(actor_a, target_cell), "外层预约移动应成功提交。")

	assert_eq(nested_results, [false], "预约移动通知期的重入写入必须失败关闭。")
	assert_push_error_count(1, "被拒绝的预约移动重入应报告一次明确错误。")
	grid.release_reservation(actor_b)
	assert_true(grid.is_cell_reserved(target_cell), "被拒绝的接收者不得残留可破坏预约的反向记录。")
	assert_true(grid.confirm_reservation(actor_a), "外层接收者应能确认目标预约。")
	grid.reservation_released.disconnect(release_callback)


func test_max_occupants_per_cell_allows_shared_cells() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(2, 2), 2)

	assert_true(grid.occupy("a", Vector2i.ZERO), "第一个值接收者应能占用格子。")
	assert_true(grid.occupy("b", Vector2i.ZERO), "容量允许时第二个值接收者应能共享格子。")
	assert_false(grid.occupy("c", Vector2i.ZERO), "超过容量后不应继续占用。")
	assert_eq(grid.get_cell_occupants(Vector2i.ZERO).size(), 2, "格子中应只有两个接收者。")


func test_release_cell_is_atomic_against_reentrant_occupy() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(1, 1), 2)
	var nested_results: Array[bool] = []

	assert_true(grid.occupy("a", Vector2i.ZERO), "第一个接收者应能占用格子。")
	assert_true(grid.occupy("b", Vector2i.ZERO), "第二个接收者应能共享格子。")
	var release_callback: Callable = func(
		_receiver: Variant,
		_released_cell: Vector2i
	) -> void:
		if not nested_results.is_empty():
			return
		nested_results.append(grid.occupy("c", Vector2i.ZERO))
	var connect_error: Error = grid.cell_released.connect(
		release_callback
	) as Error
	assert_eq(connect_error, OK, "测试应能监听批量释放通知。")

	grid.release_cell(Vector2i.ZERO)

	assert_eq(nested_results, [false], "批量释放通知期的重入占用必须失败关闭。")
	assert_push_error_count(1, "被拒绝的批量释放重入应报告一次明确错误。")
	assert_true(grid.get_cell_occupants(Vector2i.ZERO).is_empty(), "批量释放必须留下完整的空格状态。")
	grid.cell_released.disconnect(release_callback)


func test_configuration_property_writes_are_rejected_during_notification() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(2, 1), 2)
	var configuration_callback: Callable = func(
		_receiver: Variant,
		_cell: Vector2i
	) -> void:
		grid.grid_size = Vector2i.ZERO
		grid.max_occupants_per_cell = 0
	var connect_error: Error = grid.cell_occupied.connect(
		configuration_callback
	) as Error
	assert_eq(connect_error, OK, "测试应能监听格子占用通知。")

	assert_true(grid.occupy("actor", Vector2i.ZERO), "外层占用事务应成功提交。")

	assert_eq(grid.grid_size, Vector2i(2, 1), "通知期不得直接改写网格尺寸。")
	assert_eq(grid.max_occupants_per_cell, 2, "通知期不得直接改写格子容量。")
	assert_eq(grid.get_cell_occupants(Vector2i.ZERO), ["actor"], "被拒绝的配置写入不得破坏已提交占用。")
	assert_push_error_count(2, "两个被拒绝的配置写入都应报告明确错误。")
	grid.cell_occupied.disconnect(configuration_callback)


func test_configuration_property_write_clears_existing_records() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(2, 1), 2)
	assert_true(grid.occupy("actor", Vector2i.ZERO), "修改配置前应存在占用记录。")
	assert_true(grid.reserve_cell("reservation", Vector2i(1, 0)), "修改配置前应存在预约记录。")

	grid.max_occupants_per_cell = 1

	assert_eq(grid.max_occupants_per_cell, 1, "直接配置赋值应规范化并提交新容量。")
	assert_true(grid.get_occupied_cells().is_empty(), "直接配置赋值必须清空旧占用，避免容量失配。")
	assert_true(grid.get_reserved_cells().is_empty(), "直接配置赋值必须清空旧预约，避免双向索引失配。")


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


func test_queries_ignore_invalid_receiver_without_cleanup_side_effects() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(2, 1))
	var receiver: Node = Node.new()
	var released_count: Array[int] = [0]
	var release_callback: Callable = func(
		_released_receiver: Variant,
		_released_cell: Vector2i
	) -> void:
		released_count[0] += 1
	var connect_error: Error = grid.cell_released.connect(
		release_callback
	) as Error
	assert_eq(connect_error, OK, "测试应能监听格子释放通知。")
	assert_true(grid.occupy(receiver, Vector2i.ZERO), "对象接收者应能建立占用。")

	receiver.free()
	receiver = null

	assert_false(grid.is_cell_occupied(Vector2i.ZERO), "查询应忽略已释放对象。")
	assert_true(grid.get_occupied_cells().is_empty(), "批量查询应过滤已释放对象。")
	assert_eq(released_count[0], 0, "只读查询不得清理索引或发出释放通知。")

	grid.prune_invalid_receivers()

	assert_eq(released_count[0], 1, "显式清理应发出唯一释放通知。")


func test_prune_keeps_reservation_release_before_occupancy_release() -> void:
	var grid: GFGridOccupancy = GFGridOccupancy.new(Vector2i(2, 1))
	var receiver: Node = Node.new()
	var notification_order: Array[String] = []
	var reservation_callback: Callable = func(
		_released_receiver: Variant,
		_released_cell: Vector2i
	) -> void:
		notification_order.append("reservation")
	var occupancy_callback: Callable = func(
		_released_receiver: Variant,
		_released_cell: Vector2i
	) -> void:
		notification_order.append("occupancy")
	var reservation_connect_error: Error = grid.reservation_released.connect(
		reservation_callback
	) as Error
	var occupancy_connect_error: Error = grid.cell_released.connect(
		occupancy_callback
	) as Error
	assert_eq(reservation_connect_error, OK, "测试应能监听预约释放通知。")
	assert_eq(occupancy_connect_error, OK, "测试应能监听占用释放通知。")
	assert_true(grid.occupy(receiver, Vector2i.ZERO), "对象接收者应能建立占用。")
	assert_true(grid.reserve_cell(receiver, Vector2i(1, 0)), "同一接收者应能预约另一个格子。")

	receiver.free()
	receiver = null
	grid.prune_invalid_receivers()

	assert_eq(
		notification_order,
		["reservation", "occupancy"],
		"同一失效接收者的预约应先于占用释放通知。"
	)


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
