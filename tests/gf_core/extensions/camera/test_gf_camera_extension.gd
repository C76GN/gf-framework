## 测试通用相机 Rig、Director 与过渡资源。
extends GutTest


# --- 测试方法 ---

## 验证 2D Director 会选择最高优先级 Rig 并应用姿态。
func test_camera_director_2d_applies_highest_priority_rig() -> void:
	var root: Node2D = Node2D.new()
	add_child_autofree(root)

	var camera: Camera2D = Camera2D.new()
	camera.name = "Camera"
	root.add_child(camera)

	var director: GFCameraDirector2D = GFCameraDirector2D.new()
	director.name = "Director"
	director.update_mode = GFCameraDirector2D.UpdateMode.MANUAL
	director.default_blend.duration_seconds = 0.0
	root.add_child(director)
	director.camera_path = director.get_path_to(camera)

	var low_rig: GFCameraRig2D = GFCameraRig2D.new()
	low_rig.priority = 1
	low_rig.global_position = Vector2(10.0, 0.0)
	root.add_child(low_rig)

	var high_rig: GFCameraRig2D = GFCameraRig2D.new()
	high_rig.priority = 5
	high_rig.global_position = Vector2(42.0, 8.0)
	root.add_child(high_rig)
	await get_tree().process_frame

	assert_true(director.process_camera(0.0), "Director 应能应用相机姿态。")
	assert_eq(director.get_active_rig(), high_rig, "Director 应选择最高优先级 Rig。")
	assert_eq(camera.global_position, Vector2(42.0, 8.0), "Camera2D 应应用 Rig 姿态。")


func test_camera_director_2d_make_current_is_explicit_opt_in() -> void:
	var root: Node2D = Node2D.new()
	add_child_autofree(root)
	var camera: Camera2D = Camera2D.new()
	root.add_child(camera)
	var director: GFCameraDirector2D = GFCameraDirector2D.new()
	director.update_mode = GFCameraDirector2D.UpdateMode.MANUAL
	director.default_blend.duration_seconds = 0.0
	director.make_current_on_apply = true
	root.add_child(director)
	director.camera_path = director.get_path_to(camera)
	var rig: GFCameraRig2D = GFCameraRig2D.new()
	root.add_child(rig)
	await get_tree().process_frame

	assert_true(director.process_camera(0.0), "Director 应能应用 2D 相机姿态。")
	if camera.has_method("is_current"):
		assert_true(GFVariantData.to_bool(camera.call("is_current")), "opt-in 时 Director 应把 Camera2D 设为当前相机。")
	else:
		assert_true(camera.enabled, "旧引擎 API 下 opt-in 至少应启用 Camera2D。")


func test_camera_director_2d_group_collection_is_scoped_by_parent() -> void:
	var root: Node2D = Node2D.new()
	add_child_autofree(root)
	var area_a: Node2D = Node2D.new()
	root.add_child(area_a)
	var area_b: Node2D = Node2D.new()
	root.add_child(area_b)

	var camera_a: Camera2D = Camera2D.new()
	area_a.add_child(camera_a)
	var director_a: GFCameraDirector2D = GFCameraDirector2D.new()
	director_a.update_mode = GFCameraDirector2D.UpdateMode.MANUAL
	director_a.default_blend.duration_seconds = 0.0
	area_a.add_child(director_a)
	director_a.camera_path = director_a.get_path_to(camera_a)

	var local_rig: GFCameraRig2D = GFCameraRig2D.new()
	local_rig.priority = 1
	local_rig.global_position = Vector2(10.0, 0.0)
	area_a.add_child(local_rig)

	var foreign_rig: GFCameraRig2D = GFCameraRig2D.new()
	foreign_rig.priority = 100
	foreign_rig.global_position = Vector2(1000.0, 0.0)
	area_b.add_child(foreign_rig)
	await get_tree().process_frame

	assert_true(director_a.process_camera(0.0), "Director A 应能应用本作用域 Rig。")
	assert_eq(director_a.get_active_rig(), local_rig, "Director A 不应串选其他父作用域中的高优先级 Rig。")
	assert_eq(camera_a.global_position, Vector2(10.0, 0.0))


func test_camera_director_2d_process_camera_returns_false_when_no_pose_applied() -> void:
	var root: Node2D = Node2D.new()
	add_child_autofree(root)
	var camera: Camera2D = Camera2D.new()
	camera.global_position = Vector2(4.0, 5.0)
	root.add_child(camera)
	var director: GFCameraDirector2D = GFCameraDirector2D.new()
	director.update_mode = GFCameraDirector2D.UpdateMode.MANUAL
	root.add_child(director)
	director.camera_path = director.get_path_to(camera)
	watch_signals(director)
	await get_tree().process_frame

	assert_false(director.process_camera(0.0), "无可用 Rig 时不应报告本帧已应用姿态。")
	assert_signal_not_emitted(director, "camera_pose_applied", "无可用 Rig 时不应发出应用信号。")
	assert_eq(camera.global_position, Vector2(4.0, 5.0), "保持当前相机不等于应用了新姿态。")


func test_camera_director_2d_reports_selected_rig_without_camera_as_not_applied() -> void:
	var root: Node2D = Node2D.new()
	add_child_autofree(root)
	var director: GFCameraDirector2D = GFCameraDirector2D.new()
	director.update_mode = GFCameraDirector2D.UpdateMode.MANUAL
	root.add_child(director)
	var rig: GFCameraRig2D = GFCameraRig2D.new()
	rig.name = "Rig"
	root.add_child(rig)
	await get_tree().process_frame

	assert_false(director.process_camera(0.0), "缺少 Camera2D 时不应报告姿态已应用。")
	assert_eq(director.get_active_rig(), rig, "缺少 Camera2D 不应阻止 Director 选中可用 Rig。")
	var snapshot: Dictionary = director.get_debug_snapshot()
	var last_process: Dictionary = GFVariantData.get_option_dictionary(snapshot, "last_process")
	assert_false(GFVariantData.get_option_bool(last_process, "applied"), "报告应明确本帧未应用。")
	assert_eq(GFVariantData.get_option_string(last_process, "reason"), "missing_camera")
	assert_true(GFVariantData.get_option_bool(last_process, "has_active_rig"), "报告应保留已选中 Rig 状态。")
	assert_eq(GFVariantData.get_option_string(last_process, "active_rig_name"), "Rig")


## 验证 2D Rig 修改分组名时会同步场景树 group 注册。
func test_camera_rig_2d_group_name_updates_runtime_registration() -> void:
	var root: Node2D = Node2D.new()
	add_child_autofree(root)

	var rig: GFCameraRig2D = GFCameraRig2D.new()
	root.add_child(rig)
	await get_tree().process_frame

	assert_true(rig.is_in_group(&"gf_camera_rig_2d"), "Rig 入树后应注册默认分组。")

	rig.group_name = &"gf_camera_custom"

	assert_false(rig.is_in_group(&"gf_camera_rig_2d"), "修改分组名后应退出旧分组。")
	assert_true(rig.is_in_group(&"gf_camera_custom"), "修改分组名后应加入新分组。")


## 验证显式设置 Rig 会进入手动覆盖模式，直到主动清除。
func test_camera_director_2d_manual_active_rig_override_survives_refresh() -> void:
	var root: Node2D = Node2D.new()
	add_child_autofree(root)

	var camera: Camera2D = Camera2D.new()
	root.add_child(camera)

	var director: GFCameraDirector2D = GFCameraDirector2D.new()
	director.update_mode = GFCameraDirector2D.UpdateMode.MANUAL
	director.default_blend.duration_seconds = 0.0
	root.add_child(director)
	director.camera_path = director.get_path_to(camera)

	var low_rig: GFCameraRig2D = GFCameraRig2D.new()
	low_rig.priority = 1
	low_rig.global_position = Vector2(10.0, 0.0)
	root.add_child(low_rig)

	var high_rig: GFCameraRig2D = GFCameraRig2D.new()
	high_rig.priority = 10
	high_rig.global_position = Vector2(30.0, 0.0)
	root.add_child(high_rig)
	await get_tree().process_frame

	assert_true(director.process_camera(0.0), "自动模式应能先选择最高优先级 Rig。")
	assert_eq(director.get_active_rig(), high_rig, "自动刷新应选择最高优先级 Rig。")

	assert_true(director.set_active_rig(low_rig, true), "显式设置可用 Rig 应成功。")
	assert_true(director.process_camera(0.0), "手动覆盖后仍应能应用相机姿态。")
	assert_eq(director.get_active_rig(), low_rig, "手动覆盖应阻止自动抢占。")
	assert_eq(camera.global_position, Vector2(10.0, 0.0), "Camera2D 应应用手动 Rig 姿态。")

	var restored_rig: GFCameraRig2D = director.clear_active_rig_override(true)
	assert_eq(restored_rig, high_rig, "清除手动覆盖后应恢复自动选择。")


func test_camera_director_2d_manual_empty_selection_persists_until_cleared() -> void:
	var root: Node2D = Node2D.new()
	add_child_autofree(root)
	var camera: Camera2D = Camera2D.new()
	root.add_child(camera)
	var director: GFCameraDirector2D = GFCameraDirector2D.new()
	director.update_mode = GFCameraDirector2D.UpdateMode.MANUAL
	director.default_blend.duration_seconds = 0.0
	root.add_child(director)
	director.camera_path = director.get_path_to(camera)
	var rig: GFCameraRig2D = GFCameraRig2D.new()
	rig.global_position = Vector2(12.0, 3.0)
	root.add_child(rig)
	await get_tree().process_frame

	assert_true(director.process_camera(0.0))
	assert_true(director.set_active_rig(null, true), "显式 null 应进入手动空选择。")
	assert_false(director.process_camera(0.0))
	assert_false(director.process_camera(0.0), "后续刷新不得把手动空选择误判为自动模式。")
	assert_null(director.get_active_rig())
	assert_eq(
		GFVariantData.get_option_string(director.get_debug_snapshot(), "selection_mode"),
		"manual_empty"
	)

	assert_eq(director.clear_active_rig_override(true), rig)
	assert_true(director.process_camera(0.0), "显式清除覆盖后才恢复自动选择。")


## 验证配置了缺失目标的 Rig 不会被 Director 选中。
func test_camera_rig_2d_missing_target_is_unavailable() -> void:
	var root: Node2D = Node2D.new()
	add_child_autofree(root)

	var rig: GFCameraRig2D = GFCameraRig2D.new()
	rig.target_path = NodePath("MissingTarget")
	root.add_child(rig)
	await get_tree().process_frame

	assert_false(rig.is_available(), "非空 target_path 解析失败时 Rig 应不可用。")


func test_camera_rig_2d_pose_data_is_json_safe_and_omits_rig_object() -> void:
	var root: Node2D = Node2D.new()
	add_child_autofree(root)
	var rig: GFCameraRig2D = GFCameraRig2D.new()
	rig.global_position = Vector2(2.0, 3.0)
	root.add_child(rig)
	await get_tree().process_frame

	var pose_data: Dictionary = rig.get_camera_pose_data()
	var encoded_position: Dictionary = GFVariantData.get_option_dictionary(pose_data, "position")

	assert_false(pose_data.has("rig"), "JSON-safe pose data 不应包含运行时 Object 引用。")
	assert_true(encoded_position.has(GFVariantJsonCodec.JSON_MARKER_KEY), "Vector2 姿态应使用 JSON-safe typed marker。")
	assert_ne(JSON.stringify(pose_data), "", "pose data 应可直接 stringify。")


## 验证 2D Director 使用过渡资源采样中间姿态。
func test_camera_director_2d_blends_from_current_camera_pose() -> void:
	var root: Node2D = Node2D.new()
	add_child_autofree(root)

	var camera: Camera2D = Camera2D.new()
	camera.name = "Camera"
	camera.global_position = Vector2.ZERO
	root.add_child(camera)

	var director: GFCameraDirector2D = GFCameraDirector2D.new()
	director.name = "Director"
	director.update_mode = GFCameraDirector2D.UpdateMode.MANUAL
	var blend: GFCameraBlend = GFCameraBlend.new()
	blend.duration_seconds = 1.0
	blend.transition_type = Tween.TRANS_LINEAR
	blend.ease_type = Tween.EASE_IN_OUT
	director.default_blend = blend
	root.add_child(director)
	director.camera_path = director.get_path_to(camera)

	var rig: GFCameraRig2D = GFCameraRig2D.new()
	rig.global_position = Vector2(100.0, 0.0)
	root.add_child(rig)
	await get_tree().process_frame

	var _process_camera_result_65: Variant = director.process_camera(0.5)

	assert_almost_eq(camera.global_position.x, 50.0, 0.001, "过渡中点应位于当前姿态与目标姿态之间。")
	assert_eq(director.set_active_rig(rig, true), true, "同一 Rig 也应允许强制停止过渡。")
	var _process_camera_result_69: Variant = director.process_camera(0.0)
	assert_almost_eq(camera.global_position.x, 100.0, 0.001, "强制切换后应立即应用目标姿态。")


## 验证 3D Director 会应用最高优先级 Rig 的 Transform。
func test_camera_director_3d_applies_highest_priority_rig() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)

	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera"
	root.add_child(camera)

	var director: GFCameraDirector3D = GFCameraDirector3D.new()
	director.name = "Director"
	director.update_mode = GFCameraDirector3D.UpdateMode.MANUAL
	director.default_blend.duration_seconds = 0.0
	root.add_child(director)
	director.camera_path = director.get_path_to(camera)

	var low_rig: GFCameraRig3D = GFCameraRig3D.new()
	low_rig.priority = 1
	low_rig.position = Vector3(1.0, 0.0, 0.0)
	root.add_child(low_rig)

	var high_rig: GFCameraRig3D = GFCameraRig3D.new()
	high_rig.priority = 5
	high_rig.position = Vector3(0.0, 3.0, 7.0)
	root.add_child(high_rig)
	await get_tree().process_frame

	assert_true(director.process_camera(0.0), "Director 应能应用 3D 相机姿态。")
	assert_eq(director.get_active_rig(), high_rig, "Director 应选择最高优先级 3D Rig。")
	assert_eq(camera.global_position, Vector3(0.0, 3.0, 7.0), "Camera3D 应应用 Rig Transform。")


func test_camera_director_3d_make_current_is_explicit_opt_in() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	var director: GFCameraDirector3D = GFCameraDirector3D.new()
	director.update_mode = GFCameraDirector3D.UpdateMode.MANUAL
	director.default_blend.duration_seconds = 0.0
	director.make_current_on_apply = true
	root.add_child(director)
	director.camera_path = director.get_path_to(camera)
	var rig: GFCameraRig3D = GFCameraRig3D.new()
	root.add_child(rig)
	await get_tree().process_frame

	assert_true(director.process_camera(0.0), "Director 应能应用 3D 相机姿态。")
	assert_true(camera.is_current(), "opt-in 时 Director 应把 Camera3D 设为当前相机。")


func test_camera_director_3d_group_collection_is_scoped_by_parent() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var area_a: Node3D = Node3D.new()
	root.add_child(area_a)
	var area_b: Node3D = Node3D.new()
	root.add_child(area_b)

	var camera_a: Camera3D = Camera3D.new()
	area_a.add_child(camera_a)
	var director_a: GFCameraDirector3D = GFCameraDirector3D.new()
	director_a.update_mode = GFCameraDirector3D.UpdateMode.MANUAL
	director_a.default_blend.duration_seconds = 0.0
	area_a.add_child(director_a)
	director_a.camera_path = director_a.get_path_to(camera_a)

	var local_rig: GFCameraRig3D = GFCameraRig3D.new()
	local_rig.priority = 1
	area_a.add_child(local_rig)
	local_rig.global_position = Vector3(2.0, 0.0, 0.0)

	var foreign_rig: GFCameraRig3D = GFCameraRig3D.new()
	foreign_rig.priority = 100
	area_b.add_child(foreign_rig)
	foreign_rig.global_position = Vector3(999.0, 0.0, 0.0)
	await get_tree().process_frame

	assert_true(director_a.process_camera(0.0), "3D Director A 应能应用本作用域 Rig。")
	assert_eq(director_a.get_active_rig(), local_rig, "3D Director A 不应串选其他父作用域中的高优先级 Rig。")
	assert_eq(camera_a.global_position, Vector3(2.0, 0.0, 0.0))


func test_camera_director_3d_reports_selected_rig_without_camera_as_not_applied() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var director: GFCameraDirector3D = GFCameraDirector3D.new()
	director.update_mode = GFCameraDirector3D.UpdateMode.MANUAL
	root.add_child(director)
	var rig: GFCameraRig3D = GFCameraRig3D.new()
	rig.name = "Rig3D"
	root.add_child(rig)
	await get_tree().process_frame

	assert_false(director.process_camera(0.0), "缺少 Camera3D 时不应报告姿态已应用。")
	assert_eq(director.get_active_rig(), rig, "缺少 Camera3D 不应阻止 Director 选中可用 Rig。")
	var snapshot: Dictionary = director.get_debug_snapshot()
	var last_process: Dictionary = GFVariantData.get_option_dictionary(snapshot, "last_process")
	assert_false(GFVariantData.get_option_bool(last_process, "applied"), "报告应明确本帧未应用。")
	assert_eq(GFVariantData.get_option_string(last_process, "reason"), "missing_camera")
	assert_true(GFVariantData.get_option_bool(last_process, "has_active_rig"), "报告应保留已选中 Rig 状态。")
	assert_eq(GFVariantData.get_option_string(last_process, "active_rig_name"), "Rig3D")


func test_camera_director_3d_manual_empty_selection_persists_until_cleared() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	var director: GFCameraDirector3D = GFCameraDirector3D.new()
	director.update_mode = GFCameraDirector3D.UpdateMode.MANUAL
	director.default_blend.duration_seconds = 0.0
	root.add_child(director)
	director.camera_path = director.get_path_to(camera)
	var rig: GFCameraRig3D = GFCameraRig3D.new()
	rig.position = Vector3(1.0, 2.0, 3.0)
	root.add_child(rig)
	await get_tree().process_frame

	assert_true(director.process_camera(0.0))
	assert_true(director.set_active_rig(null, true), "显式 null 应进入 3D 手动空选择。")
	assert_false(director.process_camera(0.0))
	assert_false(director.process_camera(0.0), "3D 手动空选择应跨刷新保持。")
	assert_null(director.get_active_rig())
	assert_eq(
		GFVariantData.get_option_string(director.get_debug_snapshot(), "selection_mode"),
		"manual_empty"
	)

	assert_eq(director.clear_active_rig_override(true), rig)
	assert_true(director.process_camera(0.0))


func test_camera_director_2d_target_loss_switches_directly_to_fallback() -> void:
	var root: Node2D = Node2D.new()
	add_child_autofree(root)
	var target: Node2D = Node2D.new()
	root.add_child(target)
	var camera: Camera2D = Camera2D.new()
	root.add_child(camera)
	var director: GFCameraDirector2D = GFCameraDirector2D.new()
	director.update_mode = GFCameraDirector2D.UpdateMode.MANUAL
	director.default_blend.duration_seconds = 0.0
	root.add_child(director)
	director.camera_path = director.get_path_to(camera)

	var fallback_rig: GFCameraRig2D = GFCameraRig2D.new()
	fallback_rig.priority = 1
	root.add_child(fallback_rig)
	var target_rig: GFCameraRig2D = GFCameraRig2D.new()
	target_rig.priority = 10
	root.add_child(target_rig)
	target_rig.target_path = target_rig.get_path_to(target)
	var changes: Array = []
	var _connect_result: int = director.active_rig_changed.connect(func(previous_rig: GFCameraRig2D, new_rig: GFCameraRig2D) -> void:
		changes.append([previous_rig, new_rig])
	)
	await get_tree().process_frame

	assert_true(director.process_camera(0.0))
	changes.clear()
	target.queue_free()
	await get_tree().process_frame

	assert_true(director.process_camera(0.0), "目标丢失后应直接切到 fallback Rig。")
	assert_eq(director.get_active_rig(), fallback_rig)
	assert_eq(changes.size(), 1, "同帧有 fallback 时不应先广播 null 再广播 fallback。")
	var change: Array = GFVariantData.as_array(changes[0])
	var previous_value: Variant = change[0]
	var next_value: Variant = change[1]
	var observed_previous_rig: GFCameraRig2D = null
	var observed_next_rig: GFCameraRig2D = null
	if previous_value is GFCameraRig2D:
		observed_previous_rig = previous_value
	if next_value is GFCameraRig2D:
		observed_next_rig = next_value
	assert_eq(observed_previous_rig, target_rig)
	assert_eq(observed_next_rig, fallback_rig)


func test_camera_director_manual_rig_loss_falls_back_in_same_refresh() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var target: Node3D = Node3D.new()
	root.add_child(target)
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	var director: GFCameraDirector3D = GFCameraDirector3D.new()
	director.update_mode = GFCameraDirector3D.UpdateMode.MANUAL
	director.default_blend.duration_seconds = 0.0
	root.add_child(director)
	director.camera_path = director.get_path_to(camera)

	var fallback_rig: GFCameraRig3D = GFCameraRig3D.new()
	fallback_rig.priority = 1
	fallback_rig.position = Vector3(4.0, 0.0, 0.0)
	root.add_child(fallback_rig)
	var manual_rig: GFCameraRig3D = GFCameraRig3D.new()
	manual_rig.priority = 10
	root.add_child(manual_rig)
	manual_rig.target_path = manual_rig.get_path_to(target)
	await get_tree().process_frame

	assert_true(director.set_active_rig(manual_rig, true))
	target.queue_free()
	await get_tree().process_frame

	assert_true(director.process_camera(0.0), "手动 Rig 失效后同一刷新应继续选择 fallback。")
	assert_eq(director.get_active_rig(), fallback_rig)
	assert_eq(camera.global_position, Vector3(4.0, 0.0, 0.0))


func test_camera_pose_signal_observes_current_process_report() -> void:
	var root: Node2D = Node2D.new()
	add_child_autofree(root)
	var camera: Camera2D = Camera2D.new()
	root.add_child(camera)
	var director: GFCameraDirector2D = GFCameraDirector2D.new()
	director.update_mode = GFCameraDirector2D.UpdateMode.MANUAL
	director.default_blend.duration_seconds = 0.0
	root.add_child(director)
	director.camera_path = director.get_path_to(camera)
	var rig: GFCameraRig2D = GFCameraRig2D.new()
	rig.name = "AppliedRig"
	root.add_child(rig)
	var observed_reports: Array[Dictionary] = []
	var _connect_result: int = director.camera_pose_applied.connect(func(_rig: GFCameraRig2D) -> void:
		observed_reports.append(GFVariantData.get_option_dictionary(
			director.get_debug_snapshot(),
			"last_process"
		))
	)
	await get_tree().process_frame

	assert_true(director.process_camera(0.0))
	assert_eq(observed_reports.size(), 1)
	var observed_report: Dictionary = observed_reports[0]
	assert_true(GFVariantData.get_option_bool(observed_report, "applied"))
	assert_eq(GFVariantData.get_option_string(observed_report, "active_rig_name"), "AppliedRig")
	assert_ne(JSON.stringify(director.get_debug_snapshot()), "", "公开调试报告应可直接 JSON 编码。")


func test_camera_blend_rejects_invalid_runtime_values() -> void:
	var blend: GFCameraBlend = GFCameraBlend.new()
	blend.duration_seconds = NAN
	blend.set(&"transition_type", 999)
	blend.set(&"ease_type", 999)

	assert_almost_eq(blend.duration_seconds, 0.35, 0.001, "非有限时长不得覆盖最后有效值。")
	assert_eq(blend.transition_type, Tween.TRANS_LINEAR)
	assert_eq(blend.ease_type, Tween.EASE_IN_OUT)
	assert_true(is_finite(blend.sample_weight(0.1)))


## 验证 3D Rig 使用目标旋转时不会把目标缩放带入相机 basis 或 offset。
func test_camera_rig_3d_ignores_target_scale_for_rotation_and_offset() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)

	var target: Node3D = Node3D.new()
	target.scale = Vector3(4.0, 2.0, 0.5)
	root.add_child(target)

	var rig: GFCameraRig3D = GFCameraRig3D.new()
	rig.offset = Vector3.RIGHT
	rig.offset_follows_rotation = true
	root.add_child(rig)
	rig.target_path = rig.get_path_to(target)
	await get_tree().process_frame

	var transform: Transform3D = rig.get_camera_transform()
	assert_almost_eq(transform.origin.distance_to(target.global_position), 1.0, 0.001, "offset 不应被目标缩放放大。")
	assert_almost_eq(transform.basis.x.length(), 1.0, 0.001, "相机 basis.x 应保持单位长度。")
	assert_almost_eq(transform.basis.y.length(), 1.0, 0.001, "相机 basis.y 应保持单位长度。")
	assert_almost_eq(transform.basis.z.length(), 1.0, 0.001, "相机 basis.z 应保持单位长度。")


## 验证 look_at 方向与 up_axis 平行时会选择安全上方向。
func test_camera_rig_3d_look_at_parallel_up_axis_remains_orthonormal() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)

	var target: Node3D = Node3D.new()
	target.position = Vector3.UP
	root.add_child(target)

	var rig: GFCameraRig3D = GFCameraRig3D.new()
	rig.look_at_enabled = true
	rig.up_axis = Vector3.UP
	root.add_child(rig)
	rig.look_at_target_path = rig.get_path_to(target)
	await get_tree().process_frame

	var transform: Transform3D = rig.get_camera_transform()
	assert_almost_eq(transform.basis.x.length(), 1.0, 0.001, "parallel look_at 后 basis.x 应保持单位长度。")
	assert_almost_eq(transform.basis.y.length(), 1.0, 0.001, "parallel look_at 后 basis.y 应保持单位长度。")
	assert_almost_eq(transform.basis.z.length(), 1.0, 0.001, "parallel look_at 后 basis.z 应保持单位长度。")
