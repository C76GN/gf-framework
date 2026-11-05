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
	target.position = Vector3(
		1.0,
		2.0,
		3.0
	)
	root.add_child(target)

	var rig: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	assert_not_null(rig, "应能创建环绕 Rig。")
	if rig == null:
		root.queue_free()
		await get_tree().process_frame
		return
	root.add_child(rig)
	rig.set(
		&"target_path",
		rig.get_path_to(target)
	)
	_call_set_orbit(
		rig,
		0.0,
		0.0,
		10.0
	)
	await get_tree().process_frame

	var transform: Transform3D = _call_camera_transform(rig)
	assert_almost_eq(
		transform.origin.distance_to(target.global_position),
		10.0,
		0.001,
		"相机位置应保持指定距离。"
	)
	assert_almost_eq(
		transform.origin.x,
		1.0,
		0.001,
		"yaw 为 0 时 x 应与焦点一致。"
	)
	assert_almost_eq(
		transform.origin.z,
		13.0,
		0.001,
		"yaw 为 0 时相机应位于焦点后方。"
	)

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

	_call_set_orbit(
		rig,
		0.0,
		90.0,
		20.0
	)

	assert_almost_eq(
		_get_float_property(rig, &"pitch_degrees"),
		45.0,
		0.001,
		"pitch 应按上限夹紧。"
	)
	assert_almost_eq(
		_get_float_property(rig, &"distance"),
		6.0,
		0.001,
		"distance 应按上限夹紧。"
	)

	rig.call(&"apply_zoom_delta", -20.0)
	assert_almost_eq(
		_get_float_property(rig, &"distance"),
		2.0,
		0.001,
		"缩放拉近时应按下限夹紧。"
	)

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
	rig.set(
		&"target_path",
		rig.get_path_to(focus)
	)
	rig.set(&"look_at_enabled", true)
	rig.set(
		&"look_at_target_path",
		rig.get_path_to(look_target)
	)
	rig.set(
		&"rotation_degrees_offset",
		Vector3(
			0.0,
			45.0,
			0.0
		)
	)
	_call_set_orbit(
		rig,
		0.0,
		0.0,
		6.0
	)
	await get_tree().process_frame

	var transform_with_offset: Transform3D = _call_camera_transform(rig)
	rig.set(&"rotation_degrees_offset", Vector3.ZERO)
	var transform_without_offset: Transform3D = _call_camera_transform(rig)
	var direction_to_target: Vector3 = (look_target.global_position - transform_without_offset.origin).normalized()
	var camera_forward: Vector3 = -transform_without_offset.basis.z.normalized()

	assert_true(
		camera_forward.dot(direction_to_target) > 0.99,
		"显式 look_at_target_path 应覆盖默认 focus 朝向。"
	)
	assert_true(
		transform_with_offset.basis.z.normalized().distance_to(transform_without_offset.basis.z.normalized()) > 0.01,
		"OrbitRig 应继承 rotation_degrees_offset 语义。"
	)

	root.queue_free()
	await get_tree().process_frame


func test_orbit_rig_ignores_non_finite_orbit_values() -> void:
	var rig: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	assert_not_null(rig, "应能创建环绕 Rig。")
	if rig == null:
		return
	add_child(rig)
	_call_set_orbit(
		rig,
		10.0,
		20.0,
		5.0
	)

	_call_set_orbit(
		rig,
		NAN,
		INF,
		INF
	)

	assert_almost_eq(
		_get_float_property(rig, &"yaw_degrees"),
		10.0,
		0.001,
		"NaN yaw 不应污染 Rig。"
	)
	assert_almost_eq(
		_get_float_property(rig, &"pitch_degrees"),
		20.0,
		0.001,
		"INF pitch 不应污染 Rig。"
	)
	assert_almost_eq(
		_get_float_property(rig, &"distance"),
		5.0,
		0.001,
		"INF distance 不应污染 Rig。"
	)

	rig.queue_free()
	await get_tree().process_frame


func test_orbit_rig_sanitizes_non_finite_pose_inputs() -> void:
	var rig: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	assert_not_null(rig, "应能创建环绕 Rig。")
	if rig == null:
		return
	add_child(rig)
	rig.set(
		&"offset",
		Vector3(
			INF,
			NAN,
			1.0
		)
	)
	rig.set(
		&"rotation_degrees_offset",
		Vector3(
			NAN,
			INF,
			0.0
		)
	)
	_call_set_orbit(
		rig,
		20.0,
		10.0,
		8.0
	)

	var transform: Transform3D = _call_camera_transform(rig)
	assert_true(
		_is_finite_transform(transform),
		"非法 offset 不得污染输出 Transform3D。"
	)

	rig.queue_free()
	await get_tree().process_frame


func test_orbit_input_applies_direct_values() -> void:
	var rig: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	assert_not_null(rig, "应能创建环绕 Rig。")
	if rig == null:
		return
	add_child(rig)
	_call_set_orbit(
		rig,
		0.0,
		0.0,
		8.0
	)

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

	assert_true(
		_call_bool(
			input,
			&"apply_orbit_vector",
			[Vector2(1.0, -0.5), 10.0]
		),
		"直接环绕输入应能应用。"
	)
	assert_almost_eq(
		_get_float_property(rig, &"yaw_degrees"),
		10.0,
		0.001,
		"yaw 应按输入和缩放变化。"
	)
	assert_almost_eq(
		_get_float_property(rig, &"pitch_degrees"),
		-5.0,
		0.001,
		"pitch 应按输入和缩放变化。"
	)

	assert_true(
		_call_bool(
			input,
			&"apply_zoom_value",
			[-1.0, 2.0]
		),
		"直接缩放输入应能应用。"
	)
	assert_almost_eq(
		_get_float_property(rig, &"distance"),
		6.0,
		0.001,
		"缩放输入应改变 Rig 距离。"
	)

	rig.queue_free()
	await get_tree().process_frame


## 已禁用的映射入口不得读取项目映射或改变 Rig。
## [br]
## @api private
func test_mapped_input_disabled_at_entry_does_not_read_mapping() -> void:
	var mapping: MappingBoundaryProbe = MappingBoundaryProbe.new()
	var rig: Node3D = _new_mapped_orbit_rig(mapping)
	if rig == null:
		mapping.dispose()
		return
	add_child(rig)
	var input: Node = rig.get_child(0)
	input.set(&"enabled", false)
	watch_signals(rig)

	assert_false(
		_call_bool(
			input,
			&"process_input",
			[0.5]
		)
	)
	_assert_mapped_orbit_state(
		rig,
		0.0,
		8.0
	)
	assert_eq(mapping.orbit_read_count, 0)
	assert_eq(mapping.zoom_read_count, 0)
	assert_signal_not_emitted(rig, "orbit_changed")

	rig.queue_free()
	await get_tree().process_frame
	mapping.dispose()


## orbit 已提交后禁用只取消剩余 zoom，返回值仍报告已应用的 orbit。
## [br]
## @api private
func test_mapped_input_orbit_callback_disable_stops_remaining_zoom() -> void:
	var mapping: MappingBoundaryProbe = MappingBoundaryProbe.new()
	var rig: Node3D = _new_mapped_orbit_rig(mapping)
	if rig == null:
		mapping.dispose()
		return
	add_child(rig)
	var input: Node = rig.get_child(0)
	watch_signals(rig)
	var disable_input: Callable = func(
		_yaw: float,
		_pitch: float,
		_distance: float
	) -> void:
		input.set(&"enabled", false)
	var _connected: Error = rig.connect(
		&"orbit_changed",
		disable_input,
		CONNECT_ONE_SHOT
	)

	assert_true(
		_call_bool(
			input,
			&"process_input",
			[0.5]
		)
	)
	_assert_mapped_orbit_state(
		rig,
		60.0,
		8.0
	)
	assert_false(_get_bool_property(input, &"enabled"))
	assert_eq(
		mapping.zoom_read_count,
		0,
		"失效调用不应再进入项目 zoom 读取边界。"
	)
	assert_signal_emit_count(
		rig,
		"orbit_changed",
		1
	)

	rig.queue_free()
	await get_tree().process_frame
	mapping.dispose()


## 同一回调中重新启用不能复活旧调用，但后续显式调用仍可正常处理。
## [br]
## @api private
func test_mapped_input_disable_then_enable_does_not_revive_old_call() -> void:
	var mapping: MappingBoundaryProbe = MappingBoundaryProbe.new()
	var rig: Node3D = _new_mapped_orbit_rig(mapping)
	if rig == null:
		mapping.dispose()
		return
	add_child(rig)
	var input: Node = rig.get_child(0)
	watch_signals(rig)
	var restart_input: Callable = func(
		_yaw: float,
		_pitch: float,
		_distance: float
	) -> void:
		input.set(&"enabled", false)
		input.set(&"enabled", true)
	var _connected: Error = rig.connect(
		&"orbit_changed",
		restart_input,
		CONNECT_ONE_SHOT
	)

	assert_true(
		_call_bool(
			input,
			&"process_input",
			[0.5]
		)
	)
	_assert_mapped_orbit_state(
		rig,
		60.0,
		8.0
	)
	assert_true(_get_bool_property(input, &"enabled"))
	assert_eq(mapping.zoom_read_count, 0)
	assert_signal_emit_count(
		rig,
		"orbit_changed",
		1
	)
	assert_true(
		_call_bool(
			input,
			&"process_input",
			[0.5]
		)
	)
	_assert_mapped_orbit_state(
		rig,
		120.0,
		12.0
	)
	assert_eq(mapping.zoom_read_count, 1)
	assert_signal_emit_count(
		rig,
		"orbit_changed",
		3
	)

	rig.queue_free()
	await get_tree().process_frame
	mapping.dispose()


## 项目覆写的 orbit 读取中禁用时，尚未提交 orbit；重新启用也不会复活旧调用。
## [br]
## @api private
func test_mapped_input_custom_orbit_read_disable_cancels_before_orbit() -> void:
	for reenable: bool in [false, true]:
		var mapping: MappingBoundaryProbe = MappingBoundaryProbe.new()
		mapping.init()
		var rig: Node3D = _new_mapped_orbit_rig(mapping)
		if rig == null:
			mapping.dispose()
			return
		add_child(rig)
		var input: Node = rig.get_child(0)
		mapping.orbit_read_callback = func() -> void:
			input.set(&"enabled", false)
			if reenable:
				input.set(&"enabled", true)
		watch_signals(rig)

		assert_false(
			_call_bool(
				input,
				&"process_input",
				[0.5]
			)
		)
		_assert_mapped_orbit_state(
			rig,
			0.0,
			8.0
		)
		assert_eq(mapping.orbit_read_count, 1)
		assert_eq(mapping.zoom_read_count, 0)
		assert_eq(
			_get_bool_property(input, &"enabled"),
			reenable
		)
		assert_signal_not_emitted(rig, "orbit_changed")

		# 每轮在节点释放前结束信号观察，避免清理器同时持有多个已释放的对象键。
		clear_signal_watcher()
		mapping.orbit_read_callback = Callable()
		rig.queue_free()
		await get_tree().process_frame
		mapping.dispose()


## 映射在输入写入时运行普通修饰器；相机消费已提交样本时不重复调用它。
## [br]
## @api private
func test_mapped_input_reads_committed_modifier_result_after_reenable() -> void:
	var mapping: GFInputMappingUtility = GFInputMappingUtility.new()
	mapping.init()
	var rig: Node3D = _new_mapped_orbit_rig(mapping)
	if rig == null:
		mapping.dispose()
		return
	add_child(rig)
	var input: Node = rig.get_child(0)
	var control: Dictionary = { "calls": 0 }
	var modifier: CallbackInputModifier = CallbackInputModifier.new()
	modifier.callback = func() -> void:
		control["calls"] = GFVariantData.get_option_int(control, "calls") + 1
		input.set(&"enabled", false)
	_configure_real_orbit_mapping(mapping, modifier)
	assert_eq(
		GFVariantData.get_option_int(control, "calls"),
		1
	)
	assert_false(
		_call_bool(
			input,
			&"process_input",
			[0.5]
		)
	)
	_assert_mapped_orbit_state(
		rig,
		0.0,
		8.0
	)
	input.set(&"enabled", true)
	assert_true(
		_call_bool(
			input,
			&"process_input",
			[0.5]
		)
	)
	assert_eq(
		GFVariantData.get_option_int(control, "calls"),
		1
	)
	rig.queue_free()
	await get_tree().process_frame
	mapping.dispose()


## 项目覆盖的 zoom getter 也可能改变启用状态，返回后须拒绝旧调用的结果。
## [br]
## @api private
func test_mapped_input_zoom_getter_disable_then_enable_stops_zoom() -> void:
	var mapping: MappingBoundaryProbe = MappingBoundaryProbe.new()
	var rig: Node3D = _new_mapped_orbit_rig(mapping)
	if rig == null:
		mapping.dispose()
		return
	add_child(rig)
	var input: Node = rig.get_child(0)
	watch_signals(rig)
	mapping.zoom_read_callback = func() -> void:
		input.set(&"enabled", false)
		input.set(&"enabled", true)

	assert_true(
		_call_bool(
			input,
			&"process_input",
			[0.5]
		)
	)
	_assert_mapped_orbit_state(
		rig,
		60.0,
		8.0
	)
	assert_true(_get_bool_property(input, &"enabled"))
	assert_eq(mapping.zoom_read_count, 1)
	assert_signal_emit_count(
		rig,
		"orbit_changed",
		1
	)

	mapping.zoom_read_callback = Callable()
	rig.queue_free()
	await get_tree().process_frame
	mapping.dispose()


## 没有取消时，一次显式映射调用应完整应用 orbit 和 zoom。
## [br]
## @api private
func test_mapped_input_without_disable_applies_orbit_and_zoom() -> void:
	var mapping: MappingBoundaryProbe = MappingBoundaryProbe.new()
	var rig: Node3D = _new_mapped_orbit_rig(mapping)
	if rig == null:
		mapping.dispose()
		return
	add_child(rig)
	var input: Node = rig.get_child(0)
	await get_tree().process_frame
	_assert_mapped_orbit_state(
		rig,
		0.0,
		8.0
	)
	watch_signals(rig)

	assert_true(
		_call_bool(
			input,
			&"process_input",
			[0.5]
		)
	)
	_assert_mapped_orbit_state(
		rig,
		60.0,
		12.0
	)
	assert_eq(mapping.orbit_read_count, 1)
	assert_eq(mapping.zoom_read_count, 1)
	assert_signal_emit_count(
		rig,
		"orbit_changed",
		2
	)

	rig.queue_free()
	await get_tree().process_frame
	mapping.dispose()


## MANUAL 调用方可让回调只登记停止意图，在完整调用返回后再禁用输入。
## [br]
## @api private
func test_manual_input_finishes_current_call_before_requested_disable() -> void:
	var mapping: MappingBoundaryProbe = MappingBoundaryProbe.new()
	var rig: Node3D = _new_mapped_orbit_rig(mapping)
	if rig == null:
		mapping.dispose()
		return
	add_child(rig)
	var input: Node = rig.get_child(0)
	var control: Dictionary = { "stop_requested": false }
	watch_signals(rig)
	var request_stop: Callable = func(
		_yaw: float,
		_pitch: float,
		_distance: float
	) -> void:
		control["stop_requested"] = true
	var _connected: Error = rig.connect(
		&"orbit_changed",
		request_stop,
		CONNECT_ONE_SHOT
	)

	assert_true(
		_call_bool(
			input,
			&"process_input",
			[0.5]
		)
	)
	_assert_mapped_orbit_state(
		rig,
		60.0,
		12.0
	)
	assert_true(GFVariantData.get_option_bool(control, "stop_requested"))
	assert_true(_get_bool_property(input, &"enabled"))
	if GFVariantData.get_option_bool(control, "stop_requested"):
		input.set(&"enabled", false)
	assert_false(
		_call_bool(
			input,
			&"process_input",
			[0.5]
		)
	)
	assert_signal_emit_count(
		rig,
		"orbit_changed",
		2
	)
	await get_tree().process_frame
	_assert_mapped_orbit_state(
		rig,
		60.0,
		12.0
	)

	rig.queue_free()
	await get_tree().process_frame
	mapping.dispose()


## enabled 约束映射入口，不改变调用方显式 apply_* 的直接控制能力。
## [br]
## @api private
func test_disabled_input_still_allows_explicit_apply_methods() -> void:
	var mapping: MappingBoundaryProbe = MappingBoundaryProbe.new()
	var rig: Node3D = _new_mapped_orbit_rig(mapping)
	if rig == null:
		mapping.dispose()
		return
	add_child(rig)
	var input: Node = rig.get_child(0)
	input.set(&"enabled", false)

	assert_true(
		_call_bool(
			input,
			&"apply_orbit_vector",
			[Vector2.RIGHT, 10.0]
		)
	)
	assert_true(
		_call_bool(
			input,
			&"apply_zoom_value",
			[-1.0, 2.0]
		)
	)
	_assert_mapped_orbit_state(
		rig,
		10.0,
		6.0
	)
	assert_eq(mapping.orbit_read_count, 0)
	assert_eq(mapping.zoom_read_count, 0)

	rig.queue_free()
	await get_tree().process_frame
	mapping.dispose()


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

	_call_unhandled_input(
		input,
		_make_mouse_button(
			MOUSE_BUTTON_RIGHT,
			true,
			9
		)
	)
	var rig: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	assert_not_null(rig, "应能创建环绕 Rig。")
	if rig != null:
		add_child(rig)
		input.set(
			&"orbit_rig_path",
			input.get_path_to(rig)
		)
		_call_set_orbit(
			rig,
			0.0,
			0.0,
			8.0
		)
		_call_unhandled_input(
			input,
			_make_mouse_motion(
				Vector2(5.0, 0.0),
				9
			)
		)
		assert_almost_eq(
			_get_float_property(rig, &"yaw_degrees"),
			0.0,
			0.001,
			"无 Rig 时的按下事件不应留下延迟鼠标捕获。"
		)
		rig.queue_free()

	input.queue_free()
	await get_tree().process_frame


func test_orbit_input_is_inert_by_default() -> void:
	var input: Node = _new_node(ORBIT_INPUT_SCRIPT_PATH)
	assert_not_null(input, "应能创建环绕输入节点。")
	if input == null:
		return
	add_child(input)

	assert_false(
		_get_bool_property(input, &"use_input_mapping"),
		"输入映射桥接默认应关闭，避免隐式绑定项目动作。"
	)
	assert_false(
		_get_bool_property(input, &"mouse_orbit_enabled"),
		"鼠标环绕默认应关闭，避免隐式接管鼠标拖拽。"
	)
	assert_false(
		_get_bool_property(input, &"mouse_zoom_enabled"),
		"鼠标缩放默认应关闭，避免隐式接管鼠标滚轮。"
	)

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
	var missing_mapping_actions: PackedStringArray = GFVariantData.get_option_packed_string_array(missing_mapping_snapshot, "missing_actions")

	assert_true(
		GFVariantData.get_option_bool(missing_mapping_snapshot, "input_mapping_missing"),
		"启用输入映射但缺少工具时应报告 input_mapping_missing。"
	)
	assert_eq(
		missing_mapping_actions,
		PackedStringArray(["camera_orbit", "camera_zoom"]),
		"缺少输入映射工具时应列出无法解析的动作。"
	)

	input.set(
		&"input_mapping_utility",
		GFInputMappingUtility.new()
	)
	var missing_action_snapshot: Dictionary = _call_dictionary(input, &"get_debug_snapshot")
	var missing_actions: PackedStringArray = GFVariantData.get_option_packed_string_array(missing_action_snapshot, "missing_actions")

	assert_false(
		GFVariantData.get_option_bool(missing_action_snapshot, "input_mapping_missing"),
		"显式工具存在时不应报告 input_mapping_missing。"
	)
	assert_eq(
		missing_actions,
		PackedStringArray(["camera_orbit", "camera_zoom"]),
		"工具存在但动作未声明时应报告缺失动作。"
	)
	assert_false(
		GFVariantData.get_option_bool(missing_action_snapshot, "ready"),
		"缺少动作时输入桥接不应标记 ready。"
	)

	input.queue_free()
	await get_tree().process_frame


func test_orbit_input_requires_local_mouse_capture_before_motion() -> void:
	var rig: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	assert_not_null(rig, "应能创建环绕 Rig。")
	if rig == null:
		return
	add_child(rig)
	_call_set_orbit(
		rig,
		0.0,
		0.0,
		8.0
	)

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

	_call_unhandled_input(
		input,
		_make_mouse_motion(
			Vector2(5.0, 0.0),
			12
		)
	)
	assert_almost_eq(
		_get_float_property(rig, &"yaw_degrees"),
		0.0,
		0.001,
		"未捕获鼠标按键时 motion 不应驱动环绕。"
	)

	_call_unhandled_input(
		input,
		_make_mouse_button(
			MOUSE_BUTTON_RIGHT,
			true,
			12
		)
	)
	_call_unhandled_input(
		input,
		_make_mouse_motion(
			Vector2(5.0, 0.0),
			12
		)
	)
	assert_almost_eq(
		_get_float_property(rig, &"yaw_degrees"),
		5.0,
		0.001,
		"捕获鼠标按键后 motion 应驱动环绕。"
	)

	_call_unhandled_input(
		input,
		_make_mouse_button(
			MOUSE_BUTTON_RIGHT,
			false,
			12
		)
	)
	_call_unhandled_input(
		input,
		_make_mouse_motion(
			Vector2(5.0, 0.0),
			12
		)
	)
	assert_almost_eq(
		_get_float_property(rig, &"yaw_degrees"),
		5.0,
		0.001,
		"释放捕获按键后 motion 不应继续驱动环绕。"
	)

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
	_call_set_orbit(
		rig,
		0.0,
		0.0,
		8.0
	)
	input.set(&"update_mode", UPDATE_MODE_MANUAL)
	input.set(&"mouse_orbit_enabled", true)
	input.set(&"mouse_degrees_per_pixel", 1.0)
	await get_tree().process_frame

	_call_unhandled_input(
		input,
		_make_mouse_button(
			MOUSE_BUTTON_RIGHT,
			true,
			21
		)
	)
	input.set(&"mouse_button", MOUSE_BUTTON_LEFT)
	var snapshot: Dictionary = _call_dictionary(input, &"get_debug_snapshot")
	assert_false(
		GFVariantData.get_option_bool(snapshot, "mouse_orbit_captured"),
		"运行时改键必须立即终止由旧按键创建的捕获。"
	)
	_call_unhandled_input(
		input,
		_make_mouse_button(
			MOUSE_BUTTON_RIGHT,
			false,
			21
		)
	)
	_call_unhandled_input(
		input,
		_make_mouse_motion(
			Vector2(5.0, 0.0),
			21
		)
	)
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
	_call_set_orbit(
		rig,
		0.0,
		0.0,
		8.0
	)
	input.set(&"update_mode", UPDATE_MODE_MANUAL)
	input.set(&"mouse_orbit_enabled", true)
	input.set(&"mouse_degrees_per_pixel", 1.0)
	await get_tree().process_frame

	_call_unhandled_input(
		input,
		_make_mouse_button(
			MOUSE_BUTTON_RIGHT,
			true,
			22
		)
	)
	input.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_call_unhandled_input(
		input,
		_make_mouse_motion(
			Vector2(5.0, 0.0),
			22
		)
	)
	assert_almost_eq(
		_get_float_property(rig, &"yaw_degrees"),
		0.0,
		0.001,
		"窗口失焦后即使 release 丢失，motion 也不得继续驱动 Rig。"
	)
	assert_false(
		GFVariantData.get_option_bool(
			_call_dictionary(input, &"get_debug_snapshot"),
			"mouse_orbit_captured"
		)
	)

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
	_call_set_orbit(
		rig,
		0.0,
		0.0,
		8.0
	)
	input.set(&"update_mode", UPDATE_MODE_MANUAL)
	await get_tree().process_frame

	var largest_component: float = _find_largest_finite_vector_component()
	assert_false(
		_call_bool(
			input,
			&"apply_orbit_vector",
			[Vector2(largest_component, 0.0), 2.0]
		),
		"有限操作数的非有限乘积不得报告为已应用。"
	)
	assert_almost_eq(
		_get_float_property(rig, &"yaw_degrees"),
		0.0,
		0.001
	)
	assert_false(
		_call_bool(
			input,
			&"apply_zoom_value",
			[1.0e308, 2.0]
		),
		"缩放乘积溢出时不得报告成功。"
	)
	assert_almost_eq(
		_get_float_property(rig, &"distance"),
		8.0,
		0.001
	)

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
	if (
		rig_a == null
		or rig_b == null
		or input == null
	):
		root.queue_free()
		await get_tree().process_frame
		return
	root.add_child(rig_a)
	root.add_child(rig_b)
	root.add_child(input)
	_call_set_orbit(
		rig_a,
		0.0,
		0.0,
		8.0
	)
	_call_set_orbit(
		rig_b,
		0.0,
		0.0,
		8.0
	)
	input.set(&"update_mode", UPDATE_MODE_MANUAL)
	input.set(&"mouse_orbit_enabled", true)
	input.set(&"mouse_degrees_per_pixel", 1.0)
	input.set(
		&"orbit_rig_path",
		input.get_path_to(rig_a)
	)
	await get_tree().process_frame

	_call_unhandled_input(
		input,
		_make_mouse_button(
			MOUSE_BUTTON_RIGHT,
			true,
			18
		)
	)
	_call_unhandled_input(
		input,
		_make_mouse_motion(
			Vector2(3.0, 0.0),
			18
		)
	)
	assert_almost_eq(
		_get_float_property(rig_a, &"yaw_degrees"),
		3.0,
		0.001
	)

	input.set(
		&"orbit_rig_path",
		input.get_path_to(rig_b)
	)
	_call_unhandled_input(
		input,
		_make_mouse_motion(
			Vector2(5.0, 0.0),
			18
		)
	)
	assert_almost_eq(
		_get_float_property(rig_b, &"yaw_degrees"),
		0.0,
		0.001,
		"Rig A 的旧捕获不得转移到 Rig B。"
	)
	var stale_capture_snapshot: Dictionary = _call_dictionary(input, &"get_debug_snapshot")
	assert_false(GFVariantData.get_option_bool(stale_capture_snapshot, "mouse_orbit_captured"))

	_call_unhandled_input(
		input,
		_make_mouse_button(
			MOUSE_BUTTON_RIGHT,
			true,
			18
		)
	)
	_call_unhandled_input(
		input,
		_make_mouse_motion(
			Vector2(2.0, 0.0),
			18
		)
	)
	assert_almost_eq(
		_get_float_property(rig_b, &"yaw_degrees"),
		2.0,
		0.001
	)
	assert_ne(
		JSON.stringify(_call_dictionary(input, &"get_debug_snapshot")),
		""
	)

	root.queue_free()
	await get_tree().process_frame


# --- 私有/辅助方法 ---

## 创建仅显式调度的输入和 Rig，避免测试帧引入第二次自动映射处理。
## [br]
## @api private
func _new_mapped_orbit_rig(mapping: GFInputMappingUtility) -> Node3D:
	var rig: Node3D = _new_node3d(ORBIT_RIG_SCRIPT_PATH)
	var input: Node = _new_node(ORBIT_INPUT_SCRIPT_PATH)
	assert_not_null(rig)
	assert_not_null(input)
	if rig == null or input == null:
		if rig != null:
			rig.free()
		if input != null:
			input.free()
		return null
	input.set(&"update_mode", UPDATE_MODE_MANUAL)
	input.set(&"use_input_mapping", true)
	var _set_mapping_result: Variant = input.call(&"set_input_mapping_utility", mapping)
	rig.add_child(input)
	_call_set_orbit(
		rig,
		0.0,
		-20.0,
		8.0
	)
	return rig


## 通过正式上下文和虚拟输入写入动作值，在输入刷新时执行真实修饰器链。
## [br]
## @api private
func _configure_real_orbit_mapping(mapping: GFInputMappingUtility, modifier: GFInputModifier) -> void:
	var orbit_action: GFInputAction = GFInputAction.new()
	orbit_action.action_id = &"camera_orbit"
	orbit_action.value_type = GFInputAction.ValueType.AXIS_2D
	var orbit_mapping: GFInputMapping = GFInputMapping.new()
	orbit_mapping.action = orbit_action
	orbit_mapping.modifiers = [modifier]
	var zoom_action: GFInputAction = GFInputAction.new()
	zoom_action.action_id = &"camera_zoom"
	zoom_action.value_type = GFInputAction.ValueType.AXIS_1D
	var zoom_mapping: GFInputMapping = GFInputMapping.new()
	zoom_mapping.action = zoom_action
	var context: GFInputContext = GFInputContext.new()
	context.context_id = &"camera_cancel_contract"
	context.mappings = [orbit_mapping, zoom_mapping]
	mapping.enable_context(context)
	assert_true(mapping.set_virtual_action_value(&"camera_orbit", Vector2.RIGHT))
	assert_true(mapping.set_virtual_action_value(&"camera_zoom", 1.0))


## 对照统一初值检查已提交参数，避免只以 bool 返回值推断取消边界。
## [br]
## @api private
func _assert_mapped_orbit_state(
	rig: Node3D,
	yaw: float,
	distance: float
) -> void:
	assert_almost_eq(
		_get_float_property(rig, &"yaw_degrees"),
		yaw,
		0.001
	)
	assert_almost_eq(
		_get_float_property(rig, &"pitch_degrees"),
		-20.0,
		0.001
	)
	assert_almost_eq(
		_get_float_property(rig, &"distance"),
		distance,
		0.001
	)


func _new_node(script_path: String) -> Node:
	var resource: Resource = ResourceLoader.load(
		script_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	)
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


func _call_set_orbit(
	rig: Object,
	yaw_degrees: float,
	pitch_degrees: float,
	distance: float
) -> void:
	rig.call(
		&"set_orbit",
		yaw_degrees,
		pitch_degrees,
		distance
	)


func _call_camera_transform(rig: Object) -> Transform3D:
	var value: Variant = rig.call(&"get_camera_transform")
	if value is Transform3D:
		var transform: Transform3D = value
		return transform
	return Transform3D()


func _call_dictionary(
	target: Object,
	method_name: StringName,
	args: Array = []
) -> Dictionary:
	var value: Variant = target.callv(method_name, args)
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


func _get_float_property(target: Object, property_name: StringName) -> float:
	return GFVariantData.to_float(target.call(&"get", property_name))


func _get_bool_property(target: Object, property_name: StringName) -> bool:
	return GFVariantData.to_bool(target.call(&"get", property_name))


func _call_bool(
	target: Object,
	method_name: StringName,
	arguments: Array
) -> bool:
	return GFVariantData.to_bool(target.callv(method_name, arguments))


func _call_unhandled_input(target: Object, event: InputEvent) -> void:
	var _call_result: Variant = target.call(&"_unhandled_input", event)


func _make_mouse_button(
	button_index: MouseButton,
	pressed: bool,
	device: int
) -> InputEventMouseButton:
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


# --- 内部类 ---

## 提供固定映射输入并记录读取边界，供测试同步改变桥接器启用状态。
## [br]
## @api private
class MappingBoundaryProbe extends GFInputMappingUtility:
	## 已进入 orbit 读取的次数，用于确认禁用入口没有调用项目代码。
	## [br]
	## @api private
	var orbit_read_count: int = 0

	## 在自定义 orbit 读取返回前执行，验证调用代际检查。
	## [br]
	## @api private
	var orbit_read_callback: Callable = Callable()

	## 已进入 zoom 读取的次数，用于区分读取前取消与读取返回后取消。
	## [br]
	## @api private
	var zoom_read_count: int = 0

	## 在 zoom 值返回前执行的测试回调；测试结束时显式清空。
	## [br]
	## @api private
	var zoom_read_callback: Callable = Callable()


	## 模拟持续向右的环绕输入，不涉及相机节点或全局输入设备。
	func get_action_vector(_action_id: StringName) -> Vector2:
		orbit_read_count += 1
		if orbit_read_callback.is_valid():
			var _callback_result: Variant = orbit_read_callback.call()
		return Vector2.RIGHT


	## 在返回固定缩放输入前运行项目回调，模拟映射子类的同步扩展边界。
	func get_action_value(_action_id: StringName) -> Variant:
		zoom_read_count += 1
		if zoom_read_callback.is_valid():
			var _callback_result: Variant = zoom_read_callback.call()
		return 1.0


## 在真实映射修饰链中运行测试回调，保持输入值不变。
## [br]
## @api private
class CallbackInputModifier extends GFInputModifier:
	## 由测试控制何时禁用输入；运行时副本共享回调中的控制状态。
	## [br]
	## @api private
	var callback: Callable = Callable()


	## 执行同步回调以暴露修饰器返回后的输入资格检查。
	func modify(
		value: Vector2,
		_event: InputEvent = null,
		_action: GFInputAction = null
	) -> Vector2:
		if callback.is_valid():
			var _callback_result: Variant = callback.call()
		return value


	## 创建独立修饰器副本，并保留同一测试控制回调。
	func duplicate_modifier() -> GFInputModifier:
		var modifier: CallbackInputModifier = CallbackInputModifier.new()
		modifier.callback = callback
		return modifier
