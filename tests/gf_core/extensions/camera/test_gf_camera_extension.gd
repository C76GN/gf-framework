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


## 验证配置了缺失目标的 Rig 不会被 Director 选中。
func test_camera_rig_2d_missing_target_is_unavailable() -> void:
	var root: Node2D = Node2D.new()
	add_child_autofree(root)

	var rig: GFCameraRig2D = GFCameraRig2D.new()
	rig.target_path = NodePath("MissingTarget")
	root.add_child(rig)
	await get_tree().process_frame

	assert_false(rig.is_available(), "非空 target_path 解析失败时 Rig 应不可用。")


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
