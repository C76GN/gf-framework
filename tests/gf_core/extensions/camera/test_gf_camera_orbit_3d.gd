extends GutTest


# --- 常量 ---

const ORBIT_RIG_SCRIPT_PATH: String = "res://addons/gf/extensions/camera/nodes/gf_camera_orbit_rig_3d.gd"
const ORBIT_INPUT_SCRIPT_PATH: String = "res://addons/gf/extensions/camera/nodes/gf_camera_orbit_input_3d.gd"
const UPDATE_MODE_MANUAL: int = 2


# --- 测试用例 ---

func test_orbit_rig_computes_transform_around_target() -> void:
	var root: Node3D = Node3D.new()
	add_child(root)

	var target: Node3D = Node3D.new()
	target.position = Vector3(1.0, 2.0, 3.0)
	root.add_child(target)

	var rig: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	assert_not_null(rig, "应能创建环绕 Rig。")
	if rig == null:
		root.queue_free()
		await get_tree().process_frame
		return
	root.add_child(rig)
	rig.set(&"target_path", rig.get_path_to(target))
	_call_set_orbit(rig, 0.0, 0.0, 10.0)
	await get_tree().process_frame

	var transform: Transform3D = _call_camera_transform(rig)
	assert_almost_eq(transform.origin.distance_to(target.global_position), 10.0, 0.001, "相机位置应保持指定距离。")
	assert_almost_eq(transform.origin.x, 1.0, 0.001, "yaw 为 0 时 x 应与焦点一致。")
	assert_almost_eq(transform.origin.z, 13.0, 0.001, "yaw 为 0 时相机应位于焦点后方。")

	root.queue_free()
	await get_tree().process_frame


func test_orbit_rig_clamps_pitch_and_distance() -> void:
	var rig: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	assert_not_null(rig, "应能创建环绕 Rig。")
	if rig == null:
		return
	add_child(rig)
	rig.set(&"min_pitch_degrees", -30.0)
	rig.set(&"max_pitch_degrees", 45.0)
	rig.set(&"min_distance", 2.0)
	rig.set(&"max_distance", 6.0)

	_call_set_orbit(rig, 0.0, 90.0, 20.0)

	assert_almost_eq(_get_float_property(rig, &"pitch_degrees"), 45.0, 0.001, "pitch 应按上限夹紧。")
	assert_almost_eq(_get_float_property(rig, &"distance"), 6.0, 0.001, "distance 应按上限夹紧。")

	rig.call(&"apply_zoom_delta", -20.0)
	assert_almost_eq(_get_float_property(rig, &"distance"), 2.0, 0.001, "缩放拉近时应按下限夹紧。")

	rig.queue_free()
	await get_tree().process_frame


func test_orbit_input_applies_direct_values() -> void:
	var rig: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	assert_not_null(rig, "应能创建环绕 Rig。")
	if rig == null:
		return
	add_child(rig)
	_call_set_orbit(rig, 0.0, 0.0, 8.0)

	var input: Node = _new_node(ORBIT_INPUT_SCRIPT_PATH)
	assert_not_null(input, "应能创建环绕输入节点。")
	if input == null:
		rig.queue_free()
		await get_tree().process_frame
		return
	input.set(&"update_mode", UPDATE_MODE_MANUAL)
	input.set(&"use_input_mapping", false)
	rig.add_child(input)
	await get_tree().process_frame

	assert_true(_call_bool(input, &"apply_orbit_vector", [Vector2(1.0, -0.5), 10.0]), "直接环绕输入应能应用。")
	assert_almost_eq(_get_float_property(rig, &"yaw_degrees"), 10.0, 0.001, "yaw 应按输入和缩放变化。")
	assert_almost_eq(_get_float_property(rig, &"pitch_degrees"), -5.0, 0.001, "pitch 应按输入和缩放变化。")

	assert_true(_call_bool(input, &"apply_zoom_value", [-1.0, 2.0]), "直接缩放输入应能应用。")
	assert_almost_eq(_get_float_property(rig, &"distance"), 6.0, 0.001, "缩放输入应改变 Rig 距离。")

	rig.queue_free()
	await get_tree().process_frame


func test_orbit_input_is_inert_by_default() -> void:
	var input: Node = _new_node(ORBIT_INPUT_SCRIPT_PATH)
	assert_not_null(input, "应能创建环绕输入节点。")
	if input == null:
		return
	add_child(input)

	assert_false(_get_bool_property(input, &"use_input_mapping"), "输入映射桥接默认应关闭，避免隐式绑定项目动作。")
	assert_false(_get_bool_property(input, &"mouse_orbit_enabled"), "鼠标环绕默认应关闭，避免隐式接管鼠标拖拽。")
	assert_false(_get_bool_property(input, &"mouse_zoom_enabled"), "鼠标缩放默认应关闭，避免隐式接管鼠标滚轮。")

	input.queue_free()
	await get_tree().process_frame


func test_orbit_input_requires_local_mouse_capture_before_motion() -> void:
	var rig: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	assert_not_null(rig, "应能创建环绕 Rig。")
	if rig == null:
		return
	add_child(rig)
	_call_set_orbit(rig, 0.0, 0.0, 8.0)

	var input: Node = _new_node(ORBIT_INPUT_SCRIPT_PATH)
	assert_not_null(input, "应能创建环绕输入节点。")
	if input == null:
		rig.queue_free()
		await get_tree().process_frame
		return
	input.set(&"update_mode", UPDATE_MODE_MANUAL)
	input.set(&"mouse_orbit_enabled", true)
	input.set(&"mouse_degrees_per_pixel", 1.0)
	rig.add_child(input)
	await get_tree().process_frame

	_call_unhandled_input(input, _make_mouse_motion(Vector2(5.0, 0.0), 12))
	assert_almost_eq(_get_float_property(rig, &"yaw_degrees"), 0.0, 0.001, "未捕获鼠标按键时 motion 不应驱动环绕。")

	_call_unhandled_input(input, _make_mouse_button(MOUSE_BUTTON_RIGHT, true, 12))
	_call_unhandled_input(input, _make_mouse_motion(Vector2(5.0, 0.0), 12))
	assert_almost_eq(_get_float_property(rig, &"yaw_degrees"), 5.0, 0.001, "捕获鼠标按键后 motion 应驱动环绕。")

	_call_unhandled_input(input, _make_mouse_button(MOUSE_BUTTON_RIGHT, false, 12))
	_call_unhandled_input(input, _make_mouse_motion(Vector2(5.0, 0.0), 12))
	assert_almost_eq(_get_float_property(rig, &"yaw_degrees"), 5.0, 0.001, "释放捕获按键后 motion 不应继续驱动环绕。")

	rig.queue_free()
	await get_tree().process_frame


# --- 私有/辅助方法 ---

func _new_node(script_path: String) -> Node:
	var resource: Resource = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource is Script:
		var script: Script = resource
		var instance: Variant = script.call(&"new")
		if instance is Node:
			var node: Node = instance
			return node
	return null


func _new_node3d(script_path: String) -> Node3D:
	var node: Node = _new_node(script_path)
	if node is Node3D:
		var node3d: Node3D = node
		return node3d
	if node != null:
		node.queue_free()
	return null


func _call_set_orbit(rig: Object, yaw_degrees: float, pitch_degrees: float, distance: float) -> void:
	rig.call(&"set_orbit", yaw_degrees, pitch_degrees, distance)


func _call_camera_transform(rig: Object) -> Transform3D:
	var value: Variant = rig.call(&"get_camera_transform")
	if value is Transform3D:
		var transform: Transform3D = value
		return transform
	return Transform3D()


func _get_float_property(target: Object, property_name: StringName) -> float:
	return GFVariantData.to_float(target.call(&"get", property_name))


func _get_bool_property(target: Object, property_name: StringName) -> bool:
	return GFVariantData.to_bool(target.call(&"get", property_name))


func _call_bool(target: Object, method_name: StringName, arguments: Array) -> bool:
	return GFVariantData.to_bool(target.callv(method_name, arguments))


func _call_unhandled_input(target: Object, event: InputEvent) -> void:
	var _call_result: Variant = target.call(&"_unhandled_input", event)


func _make_mouse_button(button_index: MouseButton, pressed: bool, device: int) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.device = device
	return event


func _make_mouse_motion(relative: Vector2, device: int) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.relative = relative
	event.device = device
	return event
