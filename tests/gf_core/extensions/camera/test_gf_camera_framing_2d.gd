# 测试多目标 Rig 通过真实 Director、Camera2D 与 SubViewport 产生的取景行为。
extends GutTest


# --- 测试用例 ---

func test_director_frames_targets_and_recomputes_after_movement() -> void:
	var scene: FramingScene = _create_scene()
	var first: Node2D = _add_target(scene, Vector2(-100.0, -50.0))
	var second: Node2D = _add_target(scene, Vector2(100.0, 50.0))
	assert_true(scene.director.process_camera(0.0))
	assert_eq(scene.director.get_active_rig(), scene.rig)
	assert_eq(scene.camera.global_position, Vector2.ZERO)
	assert_almost_eq(scene.camera.zoom.x, 2.0, 0.0001)
	_assert_native_targets_inside(scene.camera, scene.viewport, [first, second])

	first.position = Vector2(0.0, 0.0)
	second.position = Vector2(100.0, 50.0)
	assert_true(scene.director.process_camera(0.0))
	assert_eq(scene.camera.global_position, Vector2(50.0, 25.0))
	assert_almost_eq(scene.camera.zoom.x, 4.0, 0.0001)
	_assert_native_targets_inside(scene.camera, scene.viewport, [first, second])


func test_single_and_coincident_targets_use_minimum_extent_and_maximum_zoom() -> void:
	var scene: FramingScene = _create_scene()
	scene.rig.min_extent = Vector2(40.0, 20.0)
	scene.rig.max_zoom = 5.0
	var first: Node2D = _add_target(scene, Vector2(17.0, 23.0))
	assert_true(scene.director.process_camera(0.0))
	assert_eq(scene.camera.global_position, first.global_position)
	assert_eq(scene.camera.zoom, Vector2(5.0, 5.0))
	var second: Node2D = _add_target(scene, first.global_position)
	assert_true(scene.director.process_camera(0.0))
	assert_eq(scene.camera.zoom, Vector2(5.0, 5.0))
	var report: Dictionary = scene.rig.get_framing_report(scene.camera)
	assert_eq(_int_field(report, "target_count"), 2)
	assert_true(_bool_field(report, "fits"))
	assert_true(_bool_field(report, "zoom_limited"))
	_assert_native_targets_inside(scene.camera, scene.viewport, [first, second])


func test_camera_viewport_is_used_when_rig_and_director_live_elsewhere() -> void:
	var scene: FramingScene = _create_scene()
	var first: Node2D = _add_target(scene, Vector2(-100.0, -50.0))
	var second: Node2D = _add_target(scene, Vector2(100.0, 50.0))
	var output: SubViewport = _create_viewport(Vector2i(200, 400), scene.viewport.find_world_2d())
	scene.camera.reparent(output)
	scene.director.camera_path = scene.director.get_path_to(scene.camera)
	assert_true(scene.director.process_camera(0.0))
	assert_eq(scene.camera.zoom, Vector2.ONE)
	assert_eq(_vector_field(scene.rig.get_framing_report(scene.camera), "viewport_size"), Vector2(200.0, 400.0))
	_assert_native_targets_inside(scene.camera, output, [first, second])

	output.size = Vector2i(800, 400)
	assert_true(scene.director.process_camera(0.0))
	assert_eq(scene.camera.zoom, Vector2(4.0, 4.0))
	_assert_native_targets_inside(scene.camera, output, [first, second])


func test_custom_viewport_overrides_camera_ancestry_and_updates_after_resize() -> void:
	var scene: FramingScene = _create_scene()
	var first: Node2D = _add_target(scene, Vector2(-100.0, -50.0))
	var second: Node2D = _add_target(scene, Vector2(100.0, 50.0))
	var output: SubViewport = _create_viewport(Vector2i(200, 400), scene.viewport.find_world_2d())
	scene.camera.custom_viewport = output
	assert_true(scene.director.process_camera(0.0))
	assert_eq(scene.camera.zoom, Vector2.ONE)
	_assert_native_targets_inside(scene.camera, output, [first, second])

	output.size = Vector2i(600, 300)
	assert_true(scene.director.process_camera(0.0))
	assert_eq(scene.camera.zoom, Vector2(3.0, 3.0))
	_assert_native_targets_inside(scene.camera, output, [first, second])
	# 原生 API 对非 Viewport 的 custom_viewport 使用默认 Viewport。
	scene.camera.custom_viewport = scene.root
	assert_true(scene.director.process_camera(0.0))
	assert_eq(scene.camera.zoom, Vector2(2.0, 2.0))


func test_rotation_and_ignore_rotation_use_the_effective_view_axes() -> void:
	var scene: FramingScene = _create_scene()
	var first: Node2D = _add_target(scene, Vector2(-100.0, 0.0))
	var second: Node2D = _add_target(scene, Vector2(100.0, 0.0))
	scene.rig.rotation = PI * 0.5
	assert_true(scene.director.process_camera(0.0))
	assert_almost_eq(scene.camera.global_rotation, PI * 0.5, 0.0001)
	assert_almost_eq(scene.camera.zoom.x, 1.0, 0.0001)
	_assert_native_targets_inside(scene.camera, scene.viewport, [first, second])

	scene.camera.ignore_rotation = true
	assert_true(scene.director.process_camera(0.0))
	assert_eq(scene.camera.global_rotation, 0.0)
	assert_almost_eq(scene.camera.zoom.x, 2.0, 0.0001)
	_assert_native_targets_inside(scene.camera, scene.viewport, [first, second])


func test_margins_and_native_camera_offset_are_respected_without_mutating_options() -> void:
	var scene: FramingScene = _create_scene()
	var first: Node2D = _add_target(scene, Vector2(-100.0, -50.0))
	var second: Node2D = _add_target(scene, Vector2(100.0, 50.0))
	scene.rig.viewport_margin = Vector2(20.0, 10.0)
	scene.camera.offset = Vector2(37.0, -29.0)
	scene.rig.rotation = 0.4
	assert_true(scene.director.process_camera(0.0))
	assert_eq(scene.camera.offset, Vector2(37.0, -29.0))
	assert_eq(scene.rig.viewport_margin, Vector2(20.0, 10.0))
	_assert_native_targets_inside(scene.camera, scene.viewport, [first, second], scene.rig.viewport_margin)
	scene.camera.force_update_scroll()
	assert_almost_eq(scene.camera.get_screen_center_position().x, 0.0, 0.001)
	assert_almost_eq(scene.camera.get_screen_center_position().y, 0.0, 0.001)


func test_rig_offset_can_follow_rotation_without_cropping_other_targets() -> void:
	var scene: FramingScene = _create_scene()
	var first: Node2D = _add_target(scene, Vector2(-100.0, -50.0))
	var second: Node2D = _add_target(scene, Vector2(100.0, 50.0))
	scene.rig.offset = Vector2(40.0, 0.0)
	scene.rig.offset_follows_rotation = true
	scene.rig.rotation = PI * 0.5
	assert_true(scene.director.process_camera(0.0))
	_assert_native_targets_inside(scene.camera, scene.viewport, [first, second])
	scene.camera.force_update_scroll()
	assert_almost_eq(scene.camera.get_screen_center_position().x, 0.0, 0.001)
	assert_almost_eq(scene.camera.get_screen_center_position().y, 40.0, 0.001)


func test_scaled_rotated_camera_parent_and_transformed_target_parent_preserve_framing() -> void:
	var scene: FramingScene = _create_scene()
	var camera_parent: Node2D = Node2D.new()
	scene.root.add_child(camera_parent)
	camera_parent.position = Vector2(80.0, 40.0)
	camera_parent.rotation = 0.35
	camera_parent.scale = Vector2(-2.0, 0.5)
	scene.camera.reparent(camera_parent)
	scene.director.camera_path = scene.director.get_path_to(scene.camera)
	var target_parent: Node2D = Node2D.new()
	scene.root.add_child(target_parent)
	target_parent.position = Vector2(50.0, 60.0)
	target_parent.rotation = -0.6
	target_parent.scale = Vector2(-1.5, 2.0)
	var first: Node2D = _add_target(scene, Vector2(-100.0, -50.0))
	var second: Node2D = _add_target(scene, Vector2(100.0, 50.0))
	first.reparent(target_parent, false)
	second.reparent(target_parent, false)
	scene.rig.target_paths = [scene.rig.get_path_to(first), scene.rig.get_path_to(second)]
	scene.rig.rotation = 0.7
	assert_true(scene.director.process_camera(0.0))
	_assert_native_targets_inside(scene.camera, scene.viewport, [first, second])
	assert_almost_eq(scene.camera.global_rotation, 0.7, 0.0001)
	assert_eq(camera_parent.scale, Vector2(-2.0, 0.5))


func test_duplicate_missing_and_queued_targets_are_observable_and_paths_can_be_replaced() -> void:
	var scene: FramingScene = _create_scene()
	var first: Node2D = _add_target(scene, Vector2(-10.0, 0.0))
	var second: Node2D = _add_target(scene, Vector2(10.0, 0.0))
	scene.rig.target_paths.append(scene.rig.get_path_to(first))
	scene.rig.target_paths.append(NodePath("../Missing"))
	var report: Dictionary = scene.rig.get_framing_report(scene.camera)
	assert_eq(_int_field(report, "target_count"), 2)
	assert_eq(_int_field(report, "ignored_target_count"), 2)
	second.queue_free()
	report = scene.rig.get_framing_report(scene.camera)
	assert_eq(_int_field(report, "target_count"), 1)
	assert_eq(_int_field(report, "ignored_target_count"), 3)
	assert_true(scene.director.process_camera(0.0))
	assert_eq(scene.camera.global_position, first.global_position)

	var replacement: Node2D = _add_target(scene, Vector2(100.0, 20.0))
	scene.rig.target_paths = [scene.rig.get_path_to(replacement)]
	assert_true(scene.director.process_camera(0.0))
	assert_eq(scene.camera.global_position, replacement.global_position)


func test_detached_targets_are_ignored_and_reentry_resolves_them_again() -> void:
	var scene: FramingScene = _create_scene()
	var target: Node2D = _add_target(scene, Vector2(10.0, 20.0))
	scene.root.remove_child(target)
	assert_false(scene.rig.is_available())
	assert_eq(_name_field(scene.rig.get_framing_report(scene.camera), "reason"), &"empty_targets")
	scene.root.add_child(target)
	assert_true(scene.rig.is_available())
	assert_true(scene.director.process_camera(0.0))
	assert_eq(scene.camera.global_position, target.global_position)


func test_losing_all_targets_selects_existing_fallback_in_the_same_process() -> void:
	var scene: FramingScene = _create_scene()
	var target: Node2D = _add_target(scene, Vector2(100.0, 20.0))
	var fallback: GFCameraRig2D = GFCameraRig2D.new()
	scene.root.add_child(fallback)
	fallback.priority = -1
	fallback.position = Vector2(-40.0, 30.0)
	assert_true(scene.director.process_camera(0.0))
	assert_eq(scene.director.get_active_rig(), scene.rig)
	target.queue_free()
	assert_false(scene.rig.is_available())
	assert_true(scene.director.process_camera(0.0))
	assert_eq(scene.director.get_active_rig(), fallback)
	assert_eq(scene.camera.global_position, fallback.global_position)


func test_zoom_minimum_reports_incomplete_framing_instead_of_claiming_visibility() -> void:
	var scene: FramingScene = _create_scene()
	var first: Node2D = _add_target(scene, Vector2(-100.0, -50.0))
	var second: Node2D = _add_target(scene, Vector2(100.0, 50.0))
	scene.rig.min_zoom = 3.0
	var report: Dictionary = scene.rig.get_framing_report(scene.camera)
	assert_true(_bool_field(report, "ok"))
	assert_false(_bool_field(report, "fits"))
	assert_true(_bool_field(report, "zoom_limited"))
	assert_eq(_name_field(report, "reason"), &"min_zoom_limited")
	assert_almost_eq(_float_field(report, "required_zoom"), 2.0, 0.0001)
	assert_true(scene.director.process_camera(0.0))
	assert_eq(scene.camera.zoom, Vector2(3.0, 3.0))
	scene.camera.force_update_scroll()
	assert_false(_is_inside_viewport(scene.viewport, first, Vector2.ZERO))
	assert_false(_is_inside_viewport(scene.viewport, second, Vector2.ZERO))


func test_no_camera_or_empty_targets_returns_no_pose_or_default_json_pose() -> void:
	var scene: FramingScene = _create_scene()
	assert_false(scene.rig.is_available())
	assert_eq(_name_field(scene.rig.get_framing_report(scene.camera), "reason"), &"empty_targets")
	var _target: Node2D = _add_target(scene, Vector2.ZERO)
	assert_eq(_name_field(scene.rig.get_framing_report(null), "reason"), &"missing_camera")
	assert_true(scene.rig.get_camera_pose().is_empty())
	assert_true(scene.rig.get_camera_pose_data().is_empty())
	assert_false(scene.rig.get_camera_pose_data(scene.camera).is_empty())


func test_minimum_extent_does_not_turn_visible_single_target_into_a_false_fit() -> void:
	var scene: FramingScene = _create_scene()
	var target: Node2D = _add_target(scene, Vector2(37.0, 59.0))
	scene.rig.min_extent = Vector2(10000.0, 10000.0)
	scene.rig.min_zoom = 1.0
	var report: Dictionary = scene.rig.get_framing_report(scene.camera)
	assert_true(_bool_field(report, "ok"))
	assert_true(_bool_field(report, "zoom_limited"))
	assert_true(_bool_field(report, "fits"))
	assert_eq(_name_field(report, "reason"), &"")
	assert_true(scene.director.process_camera(0.0))
	_assert_native_targets_inside(scene.camera, scene.viewport, [target])


func test_invalid_output_size_does_not_move_camera_to_a_default_pose() -> void:
	var scene: FramingScene = _create_scene(Vector2i(16, 16))
	var _target: Node2D = _add_target(scene, Vector2.ZERO)
	scene.rig.viewport_margin = Vector2(8.0, 8.0)
	scene.camera.position = Vector2(51.0, 67.0)
	scene.camera.zoom = Vector2(0.5, 0.75)
	assert_false(scene.director.process_camera(0.0))
	assert_eq(scene.camera.position, Vector2(51.0, 67.0))
	assert_eq(scene.camera.zoom, Vector2(0.5, 0.75))
	assert_eq(_name_field(scene.rig.get_framing_report(scene.camera), "reason"), &"invalid_viewport_size")


func test_invalid_configuration_and_target_budget_fail_without_applying_a_pose() -> void:
	var scene: FramingScene = _create_scene()
	var _target: Node2D = _add_target(scene, Vector2.ZERO)
	var cases: Array[Dictionary] = [
		{ "property": &"viewport_margin", "value": Vector2(-1.0, 0.0), "reason": &"invalid_margin" },
		{ "property": &"viewport_margin", "value": Vector2(INF, 0.0), "reason": &"invalid_margin" },
		{ "property": &"min_extent", "value": Vector2.ZERO, "reason": &"invalid_min_extent" },
		{ "property": &"min_extent", "value": Vector2(1000001.0, 1.0), "reason": &"invalid_min_extent" },
		{ "property": &"min_zoom", "value": 0.0, "reason": &"invalid_zoom_limits" },
		{ "property": &"max_zoom", "value": NAN, "reason": &"invalid_zoom_limits" },
		{ "property": &"max_zoom", "value": 0.01, "reason": &"invalid_zoom_limits" },
		{ "property": &"rotation_degrees_offset", "value": INF, "reason": &"invalid_rig_offset" },
	]
	for invalid_case: Dictionary in cases:
		var property: StringName = _name_field(invalid_case, "property")
		var original_value: Variant = scene.rig.get(property)
		scene.rig.set(property, invalid_case.get("value"))
		assert_false(scene.rig.is_available())
		assert_true(scene.rig.get_camera_pose(scene.camera).is_empty())
		assert_eq(_name_field(scene.rig.get_framing_report(scene.camera), "reason"), _name_field(invalid_case, "reason"))
		scene.rig.set(property, original_value)

	var _resize_error: int = scene.rig.target_paths.resize(257)
	assert_false(scene.rig.is_available())
	assert_eq(_name_field(scene.rig.get_framing_report(scene.camera), "reason"), &"target_limit")
	assert_true(scene.rig.get_camera_pose(scene.camera).is_empty())


func test_targets_in_another_world_or_canvas_layer_are_explicitly_rejected() -> void:
	var scene: FramingScene = _create_scene()
	var target: Node2D = _add_target(scene, Vector2.ZERO)
	var canvas_layer: CanvasLayer = CanvasLayer.new()
	scene.root.add_child(canvas_layer)
	target.reparent(canvas_layer)
	scene.rig.target_paths = [scene.rig.get_path_to(target)]
	assert_eq(_name_field(scene.rig.get_framing_report(scene.camera), "reason"), &"target_canvas_mismatch")
	assert_false(scene.director.process_camera(0.0))

	var other_world: SubViewport = _create_viewport(Vector2i(400, 200))
	target.reparent(other_world)
	scene.rig.target_paths = [scene.rig.get_path_to(target)]
	assert_eq(_name_field(scene.rig.get_framing_report(scene.camera), "reason"), &"target_canvas_mismatch")
	assert_false(scene.director.process_camera(0.0))


func test_unsupported_anchor_and_singular_parent_are_reported_without_mutation() -> void:
	var scene: FramingScene = _create_scene()
	var _target: Node2D = _add_target(scene, Vector2.ZERO)
	scene.camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	assert_eq(_name_field(scene.rig.get_framing_report(scene.camera), "reason"), &"unsupported_camera_anchor")
	assert_false(scene.director.process_camera(0.0))
	assert_eq(scene.camera.anchor_mode, Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT)
	scene.camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	var camera_parent: Node2D = Node2D.new()
	scene.root.add_child(camera_parent)
	scene.camera.reparent(camera_parent)
	scene.director.camera_path = scene.director.get_path_to(scene.camera)
	camera_parent.transform = Transform2D(Vector2.ZERO, Vector2.DOWN, Vector2.ZERO)
	assert_eq(camera_parent.get_global_transform().determinant(), 0.0)
	assert_eq(_name_field(scene.rig.get_framing_report(scene.camera), "reason"), &"invalid_camera_transform")
	assert_true(scene.rig.get_camera_pose(scene.camera).is_empty())
	# 恢复可逆变换，避免测试清理自身向原生变换系统提交退化状态。
	camera_parent.scale = Vector2.ONE


func test_singular_or_non_finite_camera_basis_rejects_pose_without_mutation() -> void:
	var scene: FramingScene = _create_scene()
	var _first: Node2D = _add_target(scene, Vector2(0.0, -100.0))
	var _second: Node2D = _add_target(scene, Vector2(0.0, 100.0))
	scene.rig.rotation = PI * 0.5
	scene.camera.zoom = Vector2(0.5, 0.75)
	for invalid_transform: Transform2D in [
		Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2(37.0, -29.0)),
		Transform2D(Vector2.RIGHT, Vector2.RIGHT, Vector2(37.0, -29.0)),
		Transform2D(Vector2(INF, 0.0), Vector2.DOWN, Vector2(37.0, -29.0)),
		Transform2D(Vector2.RIGHT, Vector2(0.0, NAN), Vector2(37.0, -29.0)),
	]:
		scene.camera.transform = invalid_transform
		if is_finite(invalid_transform.determinant()):
			assert_eq(scene.camera.transform.determinant(), 0.0)
		var before_transform: PackedByteArray = var_to_bytes(scene.camera.transform)
		var report: Dictionary = scene.rig.get_framing_report(scene.camera)
		assert_false(_bool_field(report, "ok"))
		assert_false(_bool_field(report, "fits"))
		assert_eq(_name_field(report, "reason"), &"invalid_camera_transform")
		assert_true(scene.rig.get_camera_pose(scene.camera).is_empty())
		assert_false(scene.director.process_camera(0.0))
		assert_eq(var_to_bytes(scene.camera.transform), before_transform)
		assert_eq(scene.camera.zoom, Vector2(0.5, 0.75))
		scene.camera.transform = Transform2D.IDENTITY


func test_native_minimum_scale_camera_can_apply_rotated_framing() -> void:
	var scene: FramingScene = _create_scene()
	var first: Node2D = _add_target(scene, Vector2(0.0, -100.0))
	var second: Node2D = _add_target(scene, Vector2(0.0, 100.0))
	scene.rig.rotation = PI * 0.5
	scene.camera.scale = Vector2.ZERO
	var native_scale: Vector2 = scene.camera.scale
	assert_gt(native_scale.x, 0.0)
	assert_gt(native_scale.y, 0.0)
	assert_lt(native_scale.x, 0.001)
	assert_lt(native_scale.y, 0.001)
	assert_ne(scene.camera.transform.determinant(), 0.0)
	var report: Dictionary = scene.rig.get_framing_report(scene.camera)
	assert_true(_bool_field(report, "ok"))
	assert_true(_bool_field(report, "fits"))
	assert_true(scene.director.process_camera(0.0))
	assert_almost_eq(scene.camera.global_rotation, PI * 0.5, 0.0001)
	assert_almost_eq(scene.camera.scale.x, native_scale.x, 0.000000001)
	assert_almost_eq(scene.camera.scale.y, native_scale.y, 0.000000001)
	_assert_native_targets_inside(scene.camera, scene.viewport, [first, second])


func test_group_pose_keeps_existing_director_blending_and_manual_selection() -> void:
	var scene: FramingScene = _create_scene()
	var _first: Node2D = _add_target(scene, Vector2(0.0, -50.0))
	var _second: Node2D = _add_target(scene, Vector2(200.0, 50.0))
	var static_rig: GFCameraRig2D = GFCameraRig2D.new()
	scene.root.add_child(static_rig)
	assert_true(scene.director.set_active_rig(static_rig, true))
	assert_true(scene.director.process_camera(0.0))
	assert_eq(scene.director.get_active_rig(), static_rig)
	var blend: GFCameraBlend = GFCameraBlend.new()
	blend.duration_seconds = 1.0
	blend.transition_type = Tween.TRANS_LINEAR
	blend.ease_type = Tween.EASE_IN_OUT
	scene.rig.blend = blend
	assert_eq(scene.director.clear_active_rig_override(), scene.rig)
	assert_true(scene.director.process_camera(0.5))
	assert_almost_eq(scene.camera.global_position.x, 50.0, 0.0001)
	assert_almost_eq(scene.camera.zoom.x, 1.5, 0.0001)
	assert_true(_bool_field(scene.rig.get_framing_report(scene.camera), "fits"))
	assert_true(scene.director.process_camera(0.5))
	assert_almost_eq(scene.camera.global_position.x, 100.0, 0.0001)
	assert_almost_eq(scene.camera.zoom.x, 2.0, 0.0001)


# --- 私有/辅助方法 ---

func _create_scene(viewport_size: Vector2i = Vector2i(400, 200)) -> FramingScene:
	var scene: FramingScene = FramingScene.new()
	scene.viewport = _create_viewport(viewport_size)
	scene.root = Node2D.new()
	scene.root.name = "FramingScene"
	scene.viewport.add_child(scene.root)
	scene.camera = Camera2D.new()
	scene.camera.name = "Camera"
	scene.camera.ignore_rotation = false
	scene.root.add_child(scene.camera)
	scene.director = GFCameraDirector2D.new()
	scene.director.name = "Director"
	scene.director.update_mode = GFCameraDirector2D.UpdateMode.MANUAL
	scene.director.default_blend.duration_seconds = 0.0
	scene.director.make_current_on_apply = true
	scene.root.add_child(scene.director)
	scene.director.camera_path = scene.director.get_path_to(scene.camera)
	scene.rig = GFCameraFramingRig2D.new()
	scene.rig.name = "FramingRig"
	scene.rig.priority = 10
	scene.rig.viewport_margin = Vector2.ZERO
	scene.root.add_child(scene.rig)
	return scene


func _create_viewport(viewport_size: Vector2i, shared_world: World2D = null) -> SubViewport:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = viewport_size
	viewport.world_2d = shared_world if shared_world != null else World2D.new()
	add_child_autofree(viewport)
	return viewport


func _add_target(scene: FramingScene, point: Vector2) -> Node2D:
	var target: Node2D = Node2D.new()
	target.name = "Target%d" % scene.root.get_child_count()
	scene.root.add_child(target)
	target.position = point
	scene.rig.target_paths.append(scene.rig.get_path_to(target))
	return target


func _assert_native_targets_inside(
	camera: Camera2D,
	viewport: SubViewport,
	targets: Array[Node2D],
	margin: Vector2 = Vector2.ZERO
) -> void:
	camera.force_update_scroll()
	for target: Node2D in targets:
		assert_true(_is_inside_viewport(viewport, target, margin), "实际原生画布投影应位于带边距的输出 Viewport 内。")


func _is_inside_viewport(viewport: SubViewport, target: Node2D, margin: Vector2) -> bool:
	var pixel: Vector2 = viewport.canvas_transform * target.global_position
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	return (
		pixel.x >= margin.x - 0.01 and pixel.y >= margin.y - 0.01
		and pixel.x <= viewport_size.x - margin.x + 0.01
		and pixel.y <= viewport_size.y - margin.y + 0.01
	)


func _bool_field(report: Dictionary, key: String) -> bool:
	var value: Variant = report.get(key)
	assert_true(value is bool, "字段 %s 必须为 bool。" % key)
	if value is bool:
		return value
	return false


func _int_field(report: Dictionary, key: String) -> int:
	var value: Variant = report.get(key)
	assert_true(value is int, "字段 %s 必须为 int。" % key)
	if value is int:
		return value
	return -1


func _float_field(report: Dictionary, key: String) -> float:
	var value: Variant = report.get(key)
	assert_true(value is float, "字段 %s 必须为 float。" % key)
	if value is float:
		return value
	return NAN


func _name_field(report: Dictionary, key: String) -> StringName:
	var value: Variant = report.get(key)
	assert_true(value is StringName, "字段 %s 必须为 StringName。" % key)
	if value is StringName:
		return value
	return &"invalid_test_field"


func _vector_field(report: Dictionary, key: String) -> Vector2:
	var value: Variant = report.get(key)
	assert_true(value is Vector2, "字段 %s 必须为 Vector2。" % key)
	if value is Vector2:
		return value
	return Vector2(INF, INF)


# --- 内部类 ---

class FramingScene extends RefCounted:
	var viewport: SubViewport
	var root: Node2D
	var camera: Camera2D
	var director: GFCameraDirector2D
	var rig: GFCameraFramingRig2D
