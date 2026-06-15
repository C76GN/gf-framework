## 测试 GFPhysicsQueryUtility 的物理查询辅助。
extends GutTest


var _utility: GFPhysicsQueryUtility


func before_each() -> void:
	_utility = GFPhysicsQueryUtility.new()


func after_each() -> void:
	_utility = null
	await get_tree().process_frame


func test_raycast_all_3d_returns_empty_for_invalid_world() -> void:
	var results: Array[Dictionary] = _utility.raycast_all_3d(null, Vector3.ZERO, Vector3.FORWARD)

	assert_eq(results, [], "无 World3D 时应返回空结果。")


func test_raycast_all_3d_returns_empty_for_zero_length() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)

	var results: Array[Dictionary] = _utility.raycast_all_3d(root.get_world_3d(), Vector3.ONE, Vector3.ONE)

	assert_eq(results, [], "零长度射线应返回空结果。")


func test_raycast_all_3d_collects_multiple_bodies_in_order() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var first: StaticBody3D = _make_static_box(Vector3(0.0, 0.0, -2.0))
	var second: StaticBody3D = _make_static_box(Vector3(0.0, 0.0, -4.0))
	root.add_child(first)
	root.add_child(second)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var results: Array[Dictionary] = _utility.raycast_all_3d(
		root.get_world_3d(),
		Vector3.ZERO,
		Vector3(0.0, 0.0, -6.0),
		{
			"max_results": 4,
			"margin": 0.05,
		}
	)
	var first_result: Dictionary = results[0]
	var second_result: Dictionary = results[1]

	assert_eq(results.size(), 2, "穿透射线应按顺序收集两个碰撞体。")
	assert_same(_object_option(first_result, "collider"), first)
	assert_same(_object_option(second_result, "collider"), second)
	assert_eq(GFVariantData.get_option_int(first_result, "index"), 0)
	assert_eq(GFVariantData.get_option_int(second_result, "index"), 1)
	assert_lt(
		GFVariantData.get_option_float(first_result, "distance"),
		GFVariantData.get_option_float(second_result, "distance"),
		"distance 字段应沿射线方向递增。"
	)


func test_raycast_all_3d_respects_initial_exclude() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var first: StaticBody3D = _make_static_box(Vector3(0.0, 0.0, -2.0))
	var second: StaticBody3D = _make_static_box(Vector3(0.0, 0.0, -4.0))
	root.add_child(first)
	root.add_child(second)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var results: Array[Dictionary] = _utility.raycast_all_3d(
		root.get_world_3d(),
		Vector3.ZERO,
		Vector3(0.0, 0.0, -6.0),
		{
			"exclude": [first],
			"max_results": 4,
		}
	)

	assert_eq(results.size(), 1, "初始排除列表中的碰撞体不应出现在结果中。")
	assert_same(_object_option(results[0], "collider"), second)


func _make_static_box(position: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = position
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	collision_shape.shape = box
	body.add_child(collision_shape)
	return body


func _object_option(options: Dictionary, key: Variant) -> Object:
	var value: Variant = GFVariantData.get_option_value(options, key)
	if value is Object:
		var object: Object = value
		return object
	return null
