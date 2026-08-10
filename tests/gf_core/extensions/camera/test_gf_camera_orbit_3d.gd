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


func test_orbit_rig_reuses_base_rotation_offset_and_look_at_target() -> void:
	var root: Node3D = Node3D.new()
	add_child(root)
	var focus: Node3D = Node3D.new()
	root.add_child(focus)
	var look_target: Node3D = Node3D.new()
	look_target.position = Vector3.RIGHT * 10.0
	root.add_child(look_target)
	var rig: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	assert_not_null(rig, "应能创建环绕 Rig。")
	if rig == null:
		root.queue_free()
		await get_tree().process_frame
		return
	root.add_child(rig)
	rig.set(&"target_path", rig.get_path_to(focus))
	rig.set(&"look_at_enabled", true)
	rig.set(&"look_at_target_path", rig.get_path_to(look_target))
	rig.set(&"rotation_degrees_offset", Vector3(0.0, 45.0, 0.0))
	_call_set_orbit(rig, 0.0, 0.0, 6.0)
	await get_tree().process_frame

	var transform_with_offset: Transform3D = _call_camera_transform(rig)
	rig.set(&"rotation_degrees_offset", Vector3.ZERO)
	var transform_without_offset: Transform3D = _call_camera_transform(rig)
	var direction_to_target: Vector3 = (look_target.global_position - transform_without_offset.origin).normalized()
	var camera_forward: Vector3 = -transform_without_offset.basis.z.normalized()

	assert_true(camera_forward.dot(direction_to_target) > 0.99, "显式 look_at_target_path 应覆盖默认 focus 朝向。")
	assert_true(transform_with_offset.basis.z.normalized().distance_to(transform_without_offset.basis.z.normalized()) > 0.01, "OrbitRig 应继承 rotation_degrees_offset 语义。")

	root.queue_free()
	await get_tree().process_frame


func test_orbit_rig_ignores_non_finite_orbit_values() -> void:
	var rig: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	assert_not_null(rig, "应能创建环绕 Rig。")
	if rig == null:
		return
	add_child(rig)
	_call_set_orbit(rig, 10.0, 20.0, 5.0)

	_call_set_orbit(rig, NAN, INF, INF)

	assert_almost_eq(_get_float_property(rig, &"yaw_degrees"), 10.0, 0.001, "NaN yaw 不应污染 Rig。")
	assert_almost_eq(_get_float_property(rig, &"pitch_degrees"), 20.0, 0.001, "INF pitch 不应污染 Rig。")
	assert_almost_eq(_get_float_property(rig, &"distance"), 5.0, 0.001, "INF distance 不应污染 Rig。")

	rig.queue_free()
	await get_tree().process_frame


func test_orbit_rig_sanitizes_non_finite_pose_inputs() -> void:
	var rig: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	assert_not_null(rig, "应能创建环绕 Rig。")
	if rig == null:
		return
	add_child(rig)
	rig.set(&"offset", Vector3(INF, NAN, 1.0))
	rig.set(&"rotation_degrees_offset", Vector3(NAN, INF, 0.0))
	_call_set_orbit(rig, 20.0, 10.0, 8.0)

	var transform: Transform3D = _call_camera_transform(rig)
	assert_true(_is_finite_transform(transform), "非法 offset 不得污染输出 Transform3D。")

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


func test_orbit_input_does_not_capture_mouse_without_rig() -> void:
	var input: Node = _new_node(ORBIT_INPUT_SCRIPT_PATH)
	assert_not_null(input, "应能创建环绕输入节点。")
	if input == null:
		return
	add_child(input)
	input.set(&"update_mode", UPDATE_MODE_MANUAL)
	input.set(&"mouse_orbit_enabled", true)
	input.set(&"mouse_degrees_per_pixel", 1.0)
	await get_tree().process_frame

	_call_unhandled_input(input, _make_mouse_button(MOUSE_BUTTON_RIGHT, true, 9))
	var rig: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	assert_not_null(rig, "应能创建环绕 Rig。")
	if rig != null:
		add_child(rig)
		input.set(&"orbit_rig_path", input.get_path_to(rig))
		_call_set_orbit(rig, 0.0, 0.0, 8.0)
		_call_unhandled_input(input, _make_mouse_motion(Vector2(5.0, 0.0), 9))
		assert_almost_eq(_get_float_property(rig, &"yaw_degrees"), 0.0, 0.001, "无 Rig 时的按下事件不应留下延迟鼠标捕获。")
		rig.queue_free()

	input.queue_free()
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


func test_orbit_input_debug_snapshot_reports_missing_mapping_and_actions() -> void:
	var input: Node = _new_node(ORBIT_INPUT_SCRIPT_PATH)
	assert_not_null(input, "应能创建环绕输入节点。")
	if input == null:
		return
	add_child(input)
	input.set(&"use_input_mapping", true)

	var missing_mapping_snapshot: Dictionary = _call_dictionary(input, &"get_debug_snapshot")
	var missing_mapping_actions: PackedStringArray = GFVariantData.get_option_packed_string_array(
		missing_mapping_snapshot,
		"missing_actions"
	)

	assert_true(GFVariantData.get_option_bool(missing_mapping_snapshot, "input_mapping_missing"), "启用输入映射但缺少工具时应报告 input_mapping_missing。")
	assert_eq(missing_mapping_actions, PackedStringArray(["camera_orbit", "camera_zoom"]), "缺少输入映射工具时应列出无法解析的动作。")

	input.set(&"input_mapping_utility", GFInputMappingUtility.new())
	var missing_action_snapshot: Dictionary = _call_dictionary(input, &"get_debug_snapshot")
	var missing_actions: PackedStringArray = GFVariantData.get_option_packed_string_array(
		missing_action_snapshot,
		"missing_actions"
	)

	assert_false(GFVariantData.get_option_bool(missing_action_snapshot, "input_mapping_missing"), "显式工具存在时不应报告 input_mapping_missing。")
	assert_eq(missing_actions, PackedStringArray(["camera_orbit", "camera_zoom"]), "工具存在但动作未声明时应报告缺失动作。")
	assert_false(GFVariantData.get_option_bool(missing_action_snapshot, "ready"), "缺少动作时输入桥接不应标记 ready。")

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


func test_orbit_input_changing_mouse_button_cancels_existing_capture() -> void:
	var rig: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	var input: Node = _new_node(ORBIT_INPUT_SCRIPT_PATH)
	assert_not_null(rig)
	assert_not_null(input)
	if rig == null or input == null:
		return
	add_child(rig)
	rig.add_child(input)
	_call_set_orbit(rig, 0.0, 0.0, 8.0)
	input.set(&"update_mode", UPDATE_MODE_MANUAL)
	input.set(&"mouse_orbit_enabled", true)
	input.set(&"mouse_degrees_per_pixel", 1.0)
	await get_tree().process_frame

	_call_unhandled_input(input, _make_mouse_button(MOUSE_BUTTON_RIGHT, true, 21))
	input.set(&"mouse_button", MOUSE_BUTTON_LEFT)
	var snapshot: Dictionary = _call_dictionary(input, &"get_debug_snapshot")
	assert_false(
		GFVariantData.get_option_bool(snapshot, "mouse_orbit_captured"),
		"运行时改键必须立即终止由旧按键创建的捕获。"
	)
	_call_unhandled_input(input, _make_mouse_button(MOUSE_BUTTON_RIGHT, false, 21))
	_call_unhandled_input(input, _make_mouse_motion(Vector2(5.0, 0.0), 21))
	assert_almost_eq(
		_get_float_property(rig, &"yaw_degrees"),
		0.0,
		0.001,
		"旧按键释放后，裸 motion 不得继续驱动 Rig。"
	)

	rig.queue_free()
	await get_tree().process_frame


func test_orbit_input_window_focus_out_cancels_mouse_capture() -> void:
	var rig: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	var input: Node = _new_node(ORBIT_INPUT_SCRIPT_PATH)
	assert_not_null(rig)
	assert_not_null(input)
	if rig == null or input == null:
		return
	add_child(rig)
	rig.add_child(input)
	_call_set_orbit(rig, 0.0, 0.0, 8.0)
	input.set(&"update_mode", UPDATE_MODE_MANUAL)
	input.set(&"mouse_orbit_enabled", true)
	input.set(&"mouse_degrees_per_pixel", 1.0)
	await get_tree().process_frame

	_call_unhandled_input(input, _make_mouse_button(MOUSE_BUTTON_RIGHT, true, 22))
	input.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_call_unhandled_input(input, _make_mouse_motion(Vector2(5.0, 0.0), 22))
	assert_almost_eq(
		_get_float_property(rig, &"yaw_degrees"),
		0.0,
		0.001,
		"窗口失焦后即使 release 丢失，motion 也不得继续驱动 Rig。"
	)
	assert_false(GFVariantData.get_option_bool(
		_call_dictionary(input, &"get_debug_snapshot"),
		"mouse_orbit_captured"
	))

	rig.queue_free()
	await get_tree().process_frame


func test_orbit_input_rejects_non_finite_scaled_results() -> void:
	var rig: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	var input: Node = _new_node(ORBIT_INPUT_SCRIPT_PATH)
	assert_not_null(rig)
	assert_not_null(input)
	if rig == null or input == null:
		return
	add_child(rig)
	rig.add_child(input)
	_call_set_orbit(rig, 0.0, 0.0, 8.0)
	input.set(&"update_mode", UPDATE_MODE_MANUAL)
	await get_tree().process_frame

	var largest_component: float = _find_largest_finite_vector_component()
	assert_false(
		_call_bool(input, &"apply_orbit_vector", [Vector2(largest_component, 0.0), 2.0]),
		"有限操作数的非有限乘积不得报告为已应用。"
	)
	assert_almost_eq(_get_float_property(rig, &"yaw_degrees"), 0.0, 0.001)
	assert_false(
		_call_bool(input, &"apply_zoom_value", [1.0e308, 2.0]),
		"缩放乘积溢出时不得报告成功。"
	)
	assert_almost_eq(_get_float_property(rig, &"distance"), 8.0, 0.001)

	rig.queue_free()
	await get_tree().process_frame


func test_orbit_input_mouse_capture_does_not_transfer_between_rigs() -> void:
	var root: Node3D = Node3D.new()
	add_child(root)
	var rig_a: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	var rig_b: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	var input: Node = _new_node(ORBIT_INPUT_SCRIPT_PATH)
	assert_not_null(rig_a)
	assert_not_null(rig_b)
	assert_not_null(input)
	if rig_a == null or rig_b == null or input == null:
		root.queue_free()
		await get_tree().process_frame
		return
	root.add_child(rig_a)
	root.add_child(rig_b)
	root.add_child(input)
	_call_set_orbit(rig_a, 0.0, 0.0, 8.0)
	_call_set_orbit(rig_b, 0.0, 0.0, 8.0)
	input.set(&"update_mode", UPDATE_MODE_MANUAL)
	input.set(&"mouse_orbit_enabled", true)
	input.set(&"mouse_degrees_per_pixel", 1.0)
	input.set(&"orbit_rig_path", input.get_path_to(rig_a))
	await get_tree().process_frame

	_call_unhandled_input(input, _make_mouse_button(MOUSE_BUTTON_RIGHT, true, 18))
	_call_unhandled_input(input, _make_mouse_motion(Vector2(3.0, 0.0), 18))
	assert_almost_eq(_get_float_property(rig_a, &"yaw_degrees"), 3.0, 0.001)

	input.set(&"orbit_rig_path", input.get_path_to(rig_b))
	_call_unhandled_input(input, _make_mouse_motion(Vector2(5.0, 0.0), 18))
	assert_almost_eq(
		_get_float_property(rig_b, &"yaw_degrees"),
		0.0,
		0.001,
		"Rig A 的旧捕获不得转移到 Rig B。"
	)
	var stale_capture_snapshot: Dictionary = _call_dictionary(input, &"get_debug_snapshot")
	assert_false(GFVariantData.get_option_bool(stale_capture_snapshot, "mouse_orbit_captured"))

	_call_unhandled_input(input, _make_mouse_button(MOUSE_BUTTON_RIGHT, true, 18))
	_call_unhandled_input(input, _make_mouse_motion(Vector2(2.0, 0.0), 18))
	assert_almost_eq(_get_float_property(rig_b, &"yaw_degrees"), 2.0, 0.001)
	assert_ne(JSON.stringify(_call_dictionary(input, &"get_debug_snapshot")), "")

	root.queue_free()
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


func _call_dictionary(target: Object, method_name: StringName, args: Array = []) -> Dictionary:
	var value: Variant = target.callv(method_name, args)
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


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


func _is_finite_transform(value: Transform3D) -> bool:
	return (
		is_finite(value.origin.x)
		and is_finite(value.origin.y)
		and is_finite(value.origin.z)
		and is_finite(value.basis.x.x)
		and is_finite(value.basis.x.y)
		and is_finite(value.basis.x.z)
		and is_finite(value.basis.y.x)
		and is_finite(value.basis.y.y)
		and is_finite(value.basis.y.z)
		and is_finite(value.basis.z.x)
		and is_finite(value.basis.z.y)
		and is_finite(value.basis.z.z)
	)


func _find_largest_finite_vector_component() -> float:
	var value: float = 1.0
	for _iteration: int in range(2048):
		var candidate: float = value * 2.0
		if not is_finite(candidate) or not is_finite(Vector2(candidate, 0.0).x):
			return value
		value = candidate
	return value
