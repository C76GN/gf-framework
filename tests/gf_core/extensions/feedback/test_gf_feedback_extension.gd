## 测试通用反馈采样与接收器。
extends GutTest


# --- 常量 ---

const GF_FEEDBACK_EXTENSION = preload("res://addons/gf/extensions/feedback/extension.gd")
const GF_HAPTIC_BACKEND_SCRIPT = preload("res://addons/gf/extensions/feedback/runtime/gf_haptic_backend.gd")


# --- 辅助类 ---

class RecordingHapticBackend extends RefCounted:
	var outputs: Array[Dictionary] = []
	var stops: Array[Dictionary] = []

	func start_output(
		target_type: int,
		target_id: int,
		weak_magnitude: float,
		strong_magnitude: float,
		duration_seconds: float,
		p_metadata: Dictionary = {}
	) -> bool:
		outputs.append({
			"target_type": target_type,
			"target_id": target_id,
			"weak_magnitude": weak_magnitude,
			"strong_magnitude": strong_magnitude,
			"duration_seconds": duration_seconds,
			"metadata": p_metadata,
		})
		return true

	func stop_output(target_type: int, target_id: int, p_metadata: Dictionary = {}) -> bool:
		stops.append({
			"target_type": target_type,
			"target_id": target_id,
			"metadata": p_metadata,
		})
		return true


class StubShakeUtility extends GFShakeUtility:
	var current_sample: Dictionary = GFShakePreset.zero_sample()

	func sample_channel(_channel: StringName = &"") -> Dictionary:
		return current_sample


# --- 测试方法 ---

func test_feedback_extension_installer_registers_shake_and_haptic_utilities() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var installer: GFInstaller = GF_FEEDBACK_EXTENSION.new()

	installer.install(architecture, GFAsyncScope.new())

	assert_not_null(architecture.get_local_utility(GFShakeUtility), "启用 Feedback 扩展应注册 GFShakeUtility。")
	assert_not_null(architecture.get_local_utility(GFHapticUtility), "启用 Feedback 扩展应注册 GFHapticUtility。")
	architecture.dispose()


## 验证反馈工具可播放、采样并在持续时间结束后清理。
func test_shake_utility_samples_and_finishes() -> void:
	var utility: GFShakeUtility = GFShakeUtility.new()
	utility.init()
	utility.randomize_phase = false

	var preset: GFShakePreset = GFShakePreset.new()
	preset.duration_seconds = 0.1
	preset.frequency = 10.0
	preset.waveform = GFShakePreset.Waveform.SINE
	preset.position_axis = Vector3.RIGHT

	var shake_id: int = utility.play_shake(&"camera", preset)
	utility.tick(0.025)
	var sample: Dictionary = utility.sample_channel(&"camera")
	var position: Vector3 = GFVariantData.get_option_vector3(sample, "position")

	assert_true(utility.is_shake_active(shake_id), "播放后反馈实例应处于活跃状态。")
	assert_gt(absf(position.x), 0.5, "采样应产生位移偏移。")

	utility.tick(0.2)

	assert_false(utility.is_shake_active(shake_id), "超过持续时间后反馈实例应自动结束。")


func test_shake_utility_short_tick_keeps_one_sample_before_finishing() -> void:
	var utility: GFShakeUtility = GFShakeUtility.new()
	utility.init()
	utility.randomize_phase = false

	var preset: GFShakePreset = GFShakePreset.new()
	preset.duration_seconds = 0.01
	preset.frequency = 50.0
	preset.waveform = GFShakePreset.Waveform.SINE
	preset.position_axis = Vector3.RIGHT

	var shake_id: int = utility.play_shake(&"camera", preset)
	utility.tick(0.1)
	var sample: Dictionary = utility.sample_channel(&"camera")
	var position: Vector3 = GFVariantData.get_option_vector3(sample, "position")

	assert_true(utility.is_shake_active(shake_id), "首帧超过持续时间时应保留一次可采样状态。")
	assert_gt(absf(position.x), 0.5, "短反馈不应在首帧被直接吞掉。")

	utility.tick(0.1)

	assert_false(utility.is_shake_active(shake_id), "下一次 tick 后短反馈应完成。")


func test_shake_info_sanitizes_metadata_for_reports() -> void:
	var utility: GFShakeUtility = GFShakeUtility.new()
	utility.init()
	var preset: GFShakePreset = GFShakePreset.new()
	preset.duration_seconds = 1.0

	var shake_id: int = utility.play_shake(&"camera", preset, 1.0, {
		"owner": self,
	})
	var info: Dictionary = utility.get_shake_info(shake_id)
	var info_json: String = JSON.stringify(info)
	var metadata_owner: Dictionary = GFVariantData.get_option_dictionary(
		GFVariantData.get_option_dictionary(info, "metadata"),
		"owner"
	)

	assert_false(info_json.is_empty(), "shake info 应可直接 JSON.stringify。")
	assert_true(metadata_owner.has("__gf_report_value__"), "metadata Object 应转换为报告 marker。")


func test_shake_debug_snapshot_is_json_safe() -> void:
	var utility: GFShakeUtility = GFShakeUtility.new()
	utility.init()
	var preset: GFShakePreset = GFShakePreset.new()
	preset.duration_seconds = 1.0

	var _shake_id: int = utility.play_shake(&"camera", preset)
	var snapshot: Dictionary = utility.get_debug_snapshot()
	var snapshot_json: String = JSON.stringify(snapshot)

	assert_false(snapshot_json.is_empty(), "shake debug snapshot 应可直接 JSON.stringify。")
	assert_eq(GFVariantData.get_option_int(snapshot, "active_count"), 1, "调试快照应保留活跃数量。")


## 验证 2D 接收器能把 channel 采样应用到目标节点。
func test_shake_receiver_2d_applies_sample_to_target() -> void:
	var utility: GFShakeUtility = GFShakeUtility.new()
	utility.init()
	utility.randomize_phase = false

	var preset: GFShakePreset = GFShakePreset.new()
	preset.duration_seconds = 0.2
	preset.frequency = 10.0
	preset.waveform = GFShakePreset.Waveform.SINE
	preset.position_axis = Vector3.RIGHT

	var target: Node2D = Node2D.new()
	var receiver: GFShakeReceiver2D = GFShakeReceiver2D.new()
	receiver.utility = utility
	target.add_child(receiver)
	add_child_autofree(target)
	await get_tree().process_frame

	var _play_shake_result_51: Variant = utility.play_shake(&"default", preset)
	utility.tick(0.025)
	var _apply_current_sample_result_53: Variant = receiver.apply_current_sample()

	assert_gt(target.position.x, 0.5, "接收器应把采样位移叠加到目标节点。")


func test_shake_receiver_2d_rebinds_target_path_and_resets_previous_target() -> void:
	var utility: GFShakeUtility = GFShakeUtility.new()
	utility.init()
	utility.randomize_phase = false

	var preset: GFShakePreset = GFShakePreset.new()
	preset.duration_seconds = 0.2
	preset.frequency = 10.0
	preset.waveform = GFShakePreset.Waveform.SINE
	preset.position_axis = Vector3.RIGHT

	var root: Node2D = Node2D.new()
	var first_target: Node2D = Node2D.new()
	first_target.name = "FirstTarget"
	var second_target: Node2D = Node2D.new()
	second_target.name = "SecondTarget"
	var receiver: GFShakeReceiver2D = GFShakeReceiver2D.new()
	receiver.utility = utility
	receiver.target_path = NodePath("../FirstTarget")
	root.add_child(first_target)
	root.add_child(second_target)
	root.add_child(receiver)
	add_child_autofree(root)
	await get_tree().process_frame

	var _play_shake_result: Variant = utility.play_shake(&"default", preset)
	utility.tick(0.025)
	var _apply_first_result: Variant = receiver.apply_current_sample()

	assert_gt(first_target.position.x, 0.5, "初始 target_path 应绑定到第一目标。")

	receiver.target_path = NodePath("../SecondTarget")
	var _apply_second_result: Variant = receiver.apply_current_sample()

	assert_almost_eq(first_target.position.x, 0.0, 0.001, "重绑目标时应撤销旧目标上的上一帧偏移。")
	assert_eq(receiver.get_target(), second_target, "运行时修改 target_path 后应重新解析目标。")
	assert_gt(second_target.position.x, 0.5, "重绑后采样应应用到新目标。")


func test_shake_receiver_2d_preserves_external_motion_between_samples() -> void:
	var utility: GFShakeUtility = GFShakeUtility.new()
	utility.init()
	utility.randomize_phase = false

	var preset: GFShakePreset = GFShakePreset.new()
	preset.duration_seconds = 0.2
	preset.frequency = 10.0
	preset.waveform = GFShakePreset.Waveform.SINE
	preset.position_axis = Vector3.RIGHT

	var target: Node2D = Node2D.new()
	var receiver: GFShakeReceiver2D = GFShakeReceiver2D.new()
	receiver.utility = utility
	target.add_child(receiver)
	add_child_autofree(target)
	await get_tree().process_frame

	var _play_shake_result_76: Variant = utility.play_shake(&"default", preset)
	utility.tick(0.025)
	var _apply_current_sample_result_78: Variant = receiver.apply_current_sample()
	target.position.y += 12.0
	utility.tick(0.025)
	var _apply_current_sample_result_81: Variant = receiver.apply_current_sample()

	assert_almost_eq(target.position.y, 12.0, 0.001, "接收器应只撤销自身上一帧偏移，不应覆盖外部移动。")


func test_shake_receiver_2d_drops_stale_offset_when_dead_target_is_rebound() -> void:
	var utility: StubShakeUtility = StubShakeUtility.new()
	utility.current_sample = {
		"position": Vector3(3.0, 0.0, 0.0),
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3.ZERO,
	}
	var root: Node2D = Node2D.new()
	var first_target: Node2D = Node2D.new()
	first_target.name = "FirstTarget"
	var second_target: Node2D = Node2D.new()
	second_target.name = "SecondTarget"
	second_target.position = Vector2(10.0, 0.0)
	var receiver: GFShakeReceiver2D = GFShakeReceiver2D.new()
	receiver.utility = utility
	receiver.capture_on_ready = false
	receiver.target_path = NodePath("../FirstTarget")
	root.add_child(first_target)
	root.add_child(second_target)
	root.add_child(receiver)
	add_child_autofree(root)
	await get_tree().process_frame
	receiver.set_process(false)

	assert_true(receiver.apply_current_sample(), "首个目标应成功应用采样。")
	first_target.queue_free()
	await get_tree().process_frame
	utility.current_sample["position"] = Vector3(5.0, 0.0, 0.0)
	receiver.target_path = NodePath("../SecondTarget")

	assert_true(receiver.apply_current_sample(), "失效目标重绑后应成功应用采样。")
	assert_eq(second_target.position, Vector2(15.0, 0.0), "新目标不得减去已失效目标遗留的 offset。")


func test_shake_receiver_3d_drops_stale_offset_when_dead_target_is_rebound() -> void:
	var utility: StubShakeUtility = StubShakeUtility.new()
	utility.current_sample = {
		"position": Vector3(3.0, 0.0, 0.0),
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3.ZERO,
	}
	var root: Node3D = Node3D.new()
	var first_target: Node3D = Node3D.new()
	first_target.name = "FirstTarget"
	var second_target: Node3D = Node3D.new()
	second_target.name = "SecondTarget"
	second_target.position = Vector3(10.0, 0.0, 0.0)
	var receiver: GFShakeReceiver3D = GFShakeReceiver3D.new()
	receiver.utility = utility
	receiver.capture_on_ready = false
	receiver.target_path = NodePath("../FirstTarget")
	root.add_child(first_target)
	root.add_child(second_target)
	root.add_child(receiver)
	add_child_autofree(root)
	await get_tree().process_frame
	receiver.set_process(false)

	assert_true(receiver.apply_current_sample(), "首个 3D 目标应成功应用采样。")
	first_target.queue_free()
	await get_tree().process_frame
	utility.current_sample["position"] = Vector3(5.0, 0.0, 0.0)
	receiver.target_path = NodePath("../SecondTarget")

	assert_true(receiver.apply_current_sample(), "失效 3D 目标重绑后应成功应用采样。")
	assert_eq(second_target.position, Vector3(15.0, 0.0, 0.0), "新 3D 目标不得减去旧目标遗留的 offset。")


func test_shake_receiver_reset_to_base_restores_captured_baseline() -> void:
	var utility: StubShakeUtility = StubShakeUtility.new()
	utility.current_sample = {
		"position": Vector3(2.0, 0.0, 0.0),
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3.ZERO,
	}
	var target: Node2D = Node2D.new()
	target.position = Vector2(10.0, 4.0)
	var receiver: GFShakeReceiver2D = GFShakeReceiver2D.new()
	receiver.utility = utility
	target.add_child(receiver)
	add_child_autofree(target)
	await get_tree().process_frame
	receiver.set_process(false)

	assert_true(receiver.apply_current_sample(), "测试前应成功应用采样。")
	target.position.y += 5.0

	assert_true(receiver.reset_to_base(), "已捕获基线时应能恢复目标。")
	assert_eq(target.position, Vector2(10.0, 4.0), "reset_to_base 应恢复捕获时基线，而不是重新捕获当前变换。")


func test_shake_receivers_reject_non_finite_samples_atomically() -> void:
	var utility: StubShakeUtility = StubShakeUtility.new()
	utility.current_sample = {
		"position": Vector3(NAN, 1.0, 2.0),
		"rotation_degrees": Vector3(3.0, INF, 4.0),
		"scale": Vector3.ZERO,
	}
	var target_2d: Node2D = Node2D.new()
	target_2d.position = Vector2(8.0, 9.0)
	var receiver_2d: GFShakeReceiver2D = GFShakeReceiver2D.new()
	receiver_2d.utility = utility
	target_2d.add_child(receiver_2d)
	add_child_autofree(target_2d)
	var target_3d: Node3D = Node3D.new()
	target_3d.position = Vector3(8.0, 9.0, 10.0)
	var receiver_3d: GFShakeReceiver3D = GFShakeReceiver3D.new()
	receiver_3d.utility = utility
	target_3d.add_child(receiver_3d)
	add_child_autofree(target_3d)
	await get_tree().process_frame
	receiver_2d.set_process(false)
	receiver_3d.set_process(false)
	var initial_2d_position: Vector2 = target_2d.position
	var initial_3d_position: Vector3 = target_3d.position

	assert_false(receiver_2d.apply_current_sample(), "2D 接收器必须拒绝非有限采样。")
	assert_false(receiver_3d.apply_current_sample(), "3D 接收器必须拒绝非有限采样。")
	assert_eq(target_2d.position, initial_2d_position, "拒绝非有限采样时 2D 变换必须保持原子不变。")
	assert_eq(target_3d.position, initial_3d_position, "拒绝非有限采样时 3D 变换必须保持原子不变。")


## 验证反馈预设可以按多轨道合成采样。
func test_shake_preset_combines_tracks() -> void:
	var preset: GFShakePreset = GFShakePreset.new()
	preset.duration_seconds = 1.0
	var position_track: GFShakeTrack = GFShakeTrack.new()
	position_track.waveform = GFShakeTrack.Waveform.CURVE
	position_track.position_axis = Vector3.RIGHT
	position_track.amplitude = 2.0
	position_track.wave_curve = Curve.new()
	var _add_point_result_95: Variant = position_track.wave_curve.add_point(Vector2(0.0, 1.0))
	var _add_point_result_96: Variant = position_track.wave_curve.add_point(Vector2(1.0, 1.0))
	position_track.envelope_curve = Curve.new()
	var _add_point_result_98: Variant = position_track.envelope_curve.add_point(Vector2(0.0, 1.0))
	var _add_point_result_99: Variant = position_track.envelope_curve.add_point(Vector2(1.0, 1.0))
	var rotation_track: GFShakeTrack = GFShakeTrack.new()
	rotation_track.waveform = GFShakeTrack.Waveform.CURVE
	rotation_track.position_axis = Vector3.ZERO
	rotation_track.rotation_axis_degrees = Vector3(0.0, 0.0, 1.0)
	rotation_track.amplitude = 3.0
	rotation_track.wave_curve = Curve.new()
	var _add_point_result_106: Variant = rotation_track.wave_curve.add_point(Vector2(0.0, 1.0))
	var _add_point_result_107: Variant = rotation_track.wave_curve.add_point(Vector2(1.0, 1.0))
	rotation_track.envelope_curve = Curve.new()
	var _add_point_result_109: Variant = rotation_track.envelope_curve.add_point(Vector2(0.0, 1.0))
	var _add_point_result_110: Variant = rotation_track.envelope_curve.add_point(Vector2(1.0, 1.0))
	preset.tracks = [position_track, rotation_track]

	var sample: Dictionary = preset.sample_at_progress(0.5, 0.5)
	var sample_position: Vector3 = GFVariantData.get_option_vector3(sample, "position")
	var sample_rotation: Vector3 = GFVariantData.get_option_vector3(sample, "rotation_degrees")

	assert_eq(sample_position.x, 2.0, "位置轨道应贡献位移。")
	assert_eq(sample_rotation.z, 3.0, "旋转轨道应贡献旋转。")


func test_shake_preset_first_track_uses_track_sample_as_blend_seed() -> void:
	var preset: GFShakePreset = GFShakePreset.new()
	preset.duration_seconds = 1.0
	var multiply_track: GFShakeTrack = GFShakeTrack.new()
	multiply_track.blend_mode = GFShakeTrack.BlendMode.MULTIPLY
	multiply_track.waveform = GFShakeTrack.Waveform.CURVE
	multiply_track.position_axis = Vector3.RIGHT
	multiply_track.amplitude = 2.0
	multiply_track.wave_curve = Curve.new()
	var _wave_start_result: Variant = multiply_track.wave_curve.add_point(Vector2(0.0, 1.0))
	var _wave_end_result: Variant = multiply_track.wave_curve.add_point(Vector2(1.0, 1.0))
	multiply_track.envelope_curve = Curve.new()
	var _envelope_start_result: Variant = multiply_track.envelope_curve.add_point(Vector2(0.0, 1.0))
	var _envelope_end_result: Variant = multiply_track.envelope_curve.add_point(Vector2(1.0, 1.0))
	preset.tracks = [multiply_track]

	var sample: Dictionary = preset.sample_at_progress(0.5, 0.5)
	var sample_position: Vector3 = GFVariantData.get_option_vector3(sample, "position")

	assert_eq(sample_position.x, 2.0, "非 ADD 首轨不应被 zero_sample 的 0 中性值吞掉。")


func test_shake_sampling_sanitizes_non_finite_resource_and_call_values() -> void:
	var preset: GFShakePreset = GFShakePreset.new()
	preset.duration_seconds = NAN
	preset.amplitude = INF
	preset.frequency = NAN
	preset.position_axis = Vector3(NAN, INF, -INF)
	preset.rotation_axis_degrees = Vector3(INF, NAN, 1.0)
	preset.scale_axis = Vector3(1.0, -INF, NAN)

	var legacy_sample: Dictionary = preset.sample_at_progress(NAN, INF, NAN, NAN)
	assert_true(_shake_sample_is_finite(legacy_sample), "单波形预设必须把所有非有限输入收束成有限采样。")

	var track: GFShakeTrack = GFShakeTrack.new()
	track.amplitude = INF
	track.frequency = NAN
	track.position_axis = Vector3(NAN, 1.0, INF)
	track.rotation_axis_degrees = Vector3(-INF, NAN, 1.0)
	track.scale_axis = Vector3(1.0, INF, NAN)
	preset.tracks = [track]

	var track_sample: Dictionary = preset.sample_at_progress(NAN, INF, NAN, NAN)
	assert_true(_shake_sample_is_finite(track_sample), "轨道预设必须把所有非有限输入收束成有限采样。")


func test_haptic_preset_samples_motor_curves() -> void:
	var preset: GFHapticPreset = GFHapticPreset.new()
	preset.duration_seconds = 1.0
	preset.weak_magnitude = 0.8
	preset.strong_magnitude = 0.5
	preset.weak_curve = Curve.new()
	var _weak_start_result: Variant = preset.weak_curve.add_point(Vector2(0.0, 0.0))
	var _weak_end_result: Variant = preset.weak_curve.add_point(Vector2(1.0, 1.0))
	preset.strong_curve = Curve.new()
	var _strong_start_result: Variant = preset.strong_curve.add_point(Vector2(0.0, 1.0))
	var _strong_end_result: Variant = preset.strong_curve.add_point(Vector2(1.0, 1.0))

	var sample: Dictionary = preset.sample_at_progress(0.5, 0.5)

	assert_almost_eq(GFVariantData.get_option_float(sample, "weak_magnitude"), 0.2, 0.001, "弱马达应按曲线和强度采样。")
	assert_almost_eq(GFVariantData.get_option_float(sample, "strong_magnitude"), 0.25, 0.001, "强马达应按曲线和强度采样。")


func test_haptic_preset_combine_intensity_tracks_clamped_output() -> void:
	var combined: Dictionary = GFHapticPreset.combine_samples([
		{ "weak_magnitude": 0.8, "strong_magnitude": 0.1, "intensity": 0.2, "progress": 0.25 },
		{ "weak_magnitude": 0.7, "strong_magnitude": 0.2, "intensity": 0.2, "progress": 0.5 },
	])

	assert_eq(GFVariantData.get_option_float(combined, "weak_magnitude"), 1.0, "弱马达合成应钳制到 1。")
	assert_eq(GFVariantData.get_option_float(combined, "intensity"), 1.0, "合成 intensity 应反映最终输出强度，而不是输入 intensity 最大值。")


func test_haptic_utility_applies_player_output_with_channel_strength() -> void:
	var utility: GFHapticUtility = GFHapticUtility.new()
	utility.init()
	utility.set_channel_strength(&"impact", 0.5)
	var outputs: Array[Dictionary] = []
	var stops: Array[Dictionary] = []
	utility.output_handler = func(
		target_type: int,
		target_id: int,
		weak_magnitude: float,
		strong_magnitude: float,
		duration_seconds: float,
		metadata: Dictionary
	) -> bool:
		outputs.append({
			"target_type": target_type,
			"target_id": target_id,
			"weak_magnitude": weak_magnitude,
			"strong_magnitude": strong_magnitude,
			"duration_seconds": duration_seconds,
			"metadata": metadata,
		})
		return true
	utility.stop_handler = func(target_type: int, target_id: int, metadata: Dictionary) -> bool:
		stops.append({
			"target_type": target_type,
			"target_id": target_id,
			"metadata": metadata,
		})
		return true

	var preset: GFHapticPreset = GFHapticPreset.new()
	preset.duration_seconds = 0.1
	preset.weak_magnitude = 1.0
	preset.strong_magnitude = 0.5
	var haptic_id: int = utility.play_haptic(&"impact", preset, 2)

	utility.tick(0.025)
	var player_sample: Dictionary = utility.sample_player(2)

	assert_true(utility.is_haptic_active(haptic_id), "播放后震动实例应处于活跃状态。")
	assert_almost_eq(GFVariantData.get_option_float(player_sample, "weak_magnitude"), 0.5, 0.001, "channel 强度应影响玩家采样。")
	assert_eq(outputs.size(), 1, "tick 应输出一次当前震动。")
	assert_eq(GFVariantData.get_option_int(outputs[0], "target_type"), GFHapticUtility.TargetType.PLAYER, "输出目标应为玩家。")
	assert_eq(GFVariantData.get_option_int(outputs[0], "target_id"), 2, "输出目标玩家应匹配播放请求。")

	utility.tick(0.2)

	assert_false(utility.is_haptic_active(haptic_id), "超过持续时间后震动实例应自动结束。")
	assert_eq(stops.size(), 1, "震动结束后应停止上一帧输出过的目标。")


func test_haptic_backend_protocol_defaults_to_rejecting_outputs() -> void:
	var backend: RefCounted = GF_HAPTIC_BACKEND_SCRIPT.new()

	assert_false(GFVariantData.to_bool(backend.call(
		"start_output",
		GFHapticUtility.TargetType.DEVICE,
		0,
		0.1,
		0.2,
		0.3,
		{}
	)), "基础 backend 不应假装平台输出成功。")
	assert_false(GFVariantData.to_bool(backend.call(
		"stop_output",
		GFHapticUtility.TargetType.DEVICE,
		0,
		{}
	)), "基础 backend 不应假装平台停止成功。")


func test_haptic_utility_prefers_backend_adapter_over_callbacks() -> void:
	var utility: GFHapticUtility = GFHapticUtility.new()
	var backend: RecordingHapticBackend = RecordingHapticBackend.new()
	utility.init()
	utility.haptic_backend = backend
	utility.output_handler = func(
		_target_type: int,
		_target_id: int,
		_weak_magnitude: float,
		_strong_magnitude: float,
		_duration_seconds: float,
		_p_metadata: Dictionary
	) -> bool:
		fail_test("配置 backend 后不应再落到 output_handler。")
		return false

	var preset: GFHapticPreset = GFHapticPreset.new()
	preset.duration_seconds = 0.05
	preset.weak_magnitude = 0.4
	preset.strong_magnitude = 0.8
	var haptic_id: int = utility.play_haptic_for_device(&"rumble", preset, 3)

	utility.tick(0.01)
	var stopped: bool = utility.stop_haptic(haptic_id)

	assert_eq(backend.outputs.size(), 1, "tick 应通过 backend 输出。")
	assert_eq(GFVariantData.get_option_int(backend.outputs[0], "target_type"), GFHapticUtility.TargetType.DEVICE)
	assert_eq(GFVariantData.get_option_int(backend.outputs[0], "target_id"), 3)
	assert_true(stopped, "backend stop_output 成功时 stop_haptic 应成功。")
	assert_eq(backend.stops.size(), 1, "stop_haptic 应通过 backend 停止输出。")


func test_haptic_utility_stop_haptic_immediately_stops_last_output() -> void:
	var utility: GFHapticUtility = GFHapticUtility.new()
	utility.init()
	var outputs: Array[Dictionary] = []
	var stops: Array[Dictionary] = []
	utility.output_handler = func(
		target_type: int,
		target_id: int,
		_weak_magnitude: float,
		_strong_magnitude: float,
		_duration_seconds: float,
		_metadata: Dictionary
	) -> bool:
		outputs.append({ "target_type": target_type, "target_id": target_id })
		return true
	utility.stop_handler = func(target_type: int, target_id: int, _metadata: Dictionary) -> bool:
		stops.append({ "target_type": target_type, "target_id": target_id })
		return true

	var preset: GFHapticPreset = GFHapticPreset.new()
	preset.duration_seconds = 1.0
	preset.weak_magnitude = 0.5
	var haptic_id: int = utility.play_haptic(&"impact", preset, 0)
	utility.tick(0.01)
	var stopped: bool = utility.stop_haptic(haptic_id)

	assert_true(stopped, "活跃震动应可停止。")
	assert_eq(outputs.size(), 1, "测试应先产生一次输出。")
	assert_eq(stops.size(), 1, "stop_haptic 应立即停止上一帧输出过的目标。")


func test_haptic_utility_reports_failed_output_stops() -> void:
	var utility: GFHapticUtility = GFHapticUtility.new()
	utility.init()
	utility.auto_apply_on_tick = false
	utility.output_handler = func(
		_target_type: int,
		_target_id: int,
		_weak_magnitude: float,
		_strong_magnitude: float,
		_duration_seconds: float,
		_metadata: Dictionary
	) -> bool:
		return true
	utility.stop_handler = func(
		_target_type: int,
		_target_id: int,
		_metadata: Dictionary
	) -> bool:
		return false

	var preset: GFHapticPreset = GFHapticPreset.new()
	preset.duration_seconds = 0.01
	preset.weak_magnitude = 0.5
	var _haptic_id: int = utility.play_haptic(&"impact", preset, 0)
	var _first_apply: Dictionary = utility.apply_current_outputs()
	utility.tick(0.1)
	var stop_report: Dictionary = utility.apply_current_outputs()
	var failed_stops: Array = GFVariantData.get_option_array(stop_report, "failed_stops")
	var first_failed_stop: Dictionary = GFVariantData.as_dictionary(failed_stops[0])

	assert_eq(GFVariantData.get_option_int(stop_report, "stopped_count"), 0, "停止失败不应计入成功停止。")
	assert_eq(GFVariantData.get_option_int(stop_report, "failed_stop_count"), 1, "停止失败应保留在报告中。")
	assert_eq(GFVariantData.get_option_string(first_failed_stop, "reason"), "stop_failed", "失败报告应有稳定 reason。")


func test_haptic_utility_retries_failed_stop_after_clear() -> void:
	var utility: GFHapticUtility = GFHapticUtility.new()
	utility.init()
	utility.auto_apply_on_tick = false
	var stop_attempts: Array[int] = [0]
	utility.output_handler = func(
		_target_type: int,
		_target_id: int,
		_weak_magnitude: float,
		_strong_magnitude: float,
		_duration_seconds: float,
		_metadata: Dictionary
	) -> bool:
		return true
	utility.stop_handler = func(
		_target_type: int,
		_target_id: int,
		_metadata: Dictionary
	) -> bool:
		stop_attempts[0] += 1
		return stop_attempts[0] >= 2

	var preset: GFHapticPreset = GFHapticPreset.new()
	preset.duration_seconds = 1.0
	preset.weak_magnitude = 0.5
	var _haptic_id: int = utility.play_haptic(&"impact", preset, 0)
	var _first_apply: Dictionary = utility.apply_current_outputs()
	utility.clear()
	var retry_report: Dictionary = utility.apply_current_outputs()

	assert_eq(stop_attempts[0], 2, "clear 中停止失败的目标必须保留到下一次 apply 重试。")
	assert_eq(GFVariantData.get_option_int(retry_report, "stopped_count"), 1, "后续 stop 重试成功应进入成功报告。")
	assert_eq(GFVariantData.get_option_int(retry_report, "failed_stop_count"), 0, "成功重试后不应继续报告失败目标。")
	assert_eq(GFVariantData.get_option_dictionary(utility.get_debug_snapshot(), "last_output_targets"), {}, "成功重试后目标追踪应清空。")


func test_haptic_manual_tick_requires_explicit_apply_to_stop_finished_output() -> void:
	var utility: GFHapticUtility = GFHapticUtility.new()
	utility.init()
	utility.auto_apply_on_tick = false
	var stops: Array[Dictionary] = []
	utility.output_handler = func(
		_target_type: int,
		_target_id: int,
		_weak_magnitude: float,
		_strong_magnitude: float,
		_duration_seconds: float,
		_metadata: Dictionary
	) -> bool:
		return true
	utility.stop_handler = func(target_type: int, target_id: int, _metadata: Dictionary) -> bool:
		stops.append({ "target_type": target_type, "target_id": target_id })
		return true

	var preset: GFHapticPreset = GFHapticPreset.new()
	preset.duration_seconds = 0.01
	preset.weak_magnitude = 0.5
	var _haptic_id: int = utility.play_haptic(&"impact", preset, 0)
	var _first_apply: Dictionary = utility.apply_current_outputs()
	utility.tick(0.1)

	assert_eq(stops.size(), 0, "手动输出模式下 tick 不应隐式 stop 输出设备。")
	var stop_report: Dictionary = utility.apply_current_outputs()
	assert_eq(stops.size(), 1, "手动输出模式下调用方显式 apply 后应 stop 已结束输出。")
	assert_eq(GFVariantData.get_option_int(stop_report, "stopped_count"), 1, "显式 apply 应报告 stop 成功。")


func test_haptic_info_sanitizes_metadata_for_reports() -> void:
	var utility: GFHapticUtility = GFHapticUtility.new()
	utility.init()
	var preset: GFHapticPreset = GFHapticPreset.new()
	preset.duration_seconds = 1.0
	preset.weak_magnitude = 0.5

	var haptic_id: int = utility.play_haptic(&"impact", preset, 0, 1.0, {
		"owner": self,
	})
	var info: Dictionary = utility.get_haptic_info(haptic_id)
	var info_json: String = JSON.stringify(info)
	var metadata_owner: Dictionary = GFVariantData.get_option_dictionary(
		GFVariantData.get_option_dictionary(info, "metadata"),
		"owner"
	)

	assert_false(info_json.is_empty(), "haptic info 应可直接 JSON.stringify。")
	assert_true(metadata_owner.has("__gf_report_value__"), "metadata Object 应转换为报告 marker。")


func test_haptic_utility_merges_player_and_device_for_same_joypad_output() -> void:
	var input_devices: GFInputDeviceUtility = GFInputDeviceUtility.new()
	input_devices.max_players = 2
	input_devices.set_assignment(input_devices.create_assignment(0, GFInputDeviceAssignment.DeviceType.JOYPAD, 7))
	var utility: GFHapticUtility = GFHapticUtility.new()
	utility.init()
	utility.input_device_utility = input_devices
	var outputs: Array[Dictionary] = []
	utility.output_handler = func(
		target_type: int,
		target_id: int,
		_weak_magnitude: float,
		_strong_magnitude: float,
		_duration_seconds: float,
		output_metadata: Dictionary
	) -> bool:
		outputs.append({
			"target_type": target_type,
			"target_id": target_id,
			"metadata": output_metadata,
		})
		return true

	var preset: GFHapticPreset = GFHapticPreset.new()
	preset.duration_seconds = 1.0
	preset.weak_magnitude = 0.5
	var _player_haptic_id: int = utility.play_haptic(&"player", preset, 0)
	var _device_haptic_id: int = utility.play_haptic_for_device(&"device", preset, 7)
	var _report: Dictionary = utility.apply_current_outputs()
	var output_report: Dictionary = GFVariantData.as_dictionary(outputs[0])
	var merged_metadata: Dictionary = GFVariantData.get_option_dictionary(output_report, "metadata")
	var haptic_ids: Array[int] = GFVariantData.get_option_int_array(merged_metadata, "haptic_ids")

	assert_eq(outputs.size(), 1, "同一物理手柄不应被玩家目标和设备目标重复输出。")
	assert_eq(GFVariantData.get_option_int(output_report, "target_type"), GFHapticUtility.TargetType.DEVICE, "合并后应使用物理设备目标输出。")
	assert_eq(GFVariantData.get_option_int(output_report, "target_id"), 7, "合并目标应是玩家映射到的手柄设备。")
	assert_eq(haptic_ids.size(), 2, "合并输出 metadata 应保留两个震动实例。")
	assert_eq(utility.sample_player(0), utility.sample_device(7), "player/device 采样 API 都应返回最终物理输出视图。")


func test_haptic_utility_stop_device_stops_player_state_routed_to_device() -> void:
	var input_devices: GFInputDeviceUtility = GFInputDeviceUtility.new()
	input_devices.max_players = 2
	input_devices.set_assignment(input_devices.create_assignment(0, GFInputDeviceAssignment.DeviceType.JOYPAD, 7))
	var utility: GFHapticUtility = GFHapticUtility.new()
	utility.init()
	utility.input_device_utility = input_devices
	var stops: Array[Dictionary] = []
	utility.output_handler = func(
		_target_type: int,
		_target_id: int,
		_weak_magnitude: float,
		_strong_magnitude: float,
		_duration_seconds: float,
		_metadata: Dictionary
	) -> bool:
		return true
	utility.stop_handler = func(target_type: int, target_id: int, _metadata: Dictionary) -> bool:
		stops.append({"target_type": target_type, "target_id": target_id})
		return true

	var preset: GFHapticPreset = GFHapticPreset.new()
	preset.duration_seconds = 1.0
	preset.weak_magnitude = 0.5
	var haptic_id: int = utility.play_haptic(&"player", preset, 0)
	var _first_apply: Dictionary = utility.apply_current_outputs()
	var stopped_count: int = utility.stop_device(7)

	assert_eq(stopped_count, 1, "stop_device 应停止路由到该物理设备的玩家震动状态。")
	assert_false(utility.is_haptic_active(haptic_id), "被物理设备停止的玩家震动不应继续活跃。")
	assert_eq(stops.size(), 1, "物理设备停止应立即刷新并停止已输出目标。")


func test_haptic_output_callback_cannot_reenter_state_mutation() -> void:
	var utility: GFHapticUtility = GFHapticUtility.new()
	utility.init()
	utility.auto_apply_on_tick = false
	utility.output_handler = func(
		_target_type: int,
		_target_id: int,
		_weak_magnitude: float,
		_strong_magnitude: float,
		_duration_seconds: float,
		_metadata: Dictionary
	) -> bool:
		utility.clear()
		return true

	var preset: GFHapticPreset = GFHapticPreset.new()
	preset.duration_seconds = 1.0
	preset.weak_magnitude = 0.5
	var haptic_id: int = utility.play_haptic(&"impact", preset, 0)
	var report: Dictionary = utility.apply_current_outputs()

	assert_push_error("[GFHapticUtility] clear 失败：输出后端或回调执行期间不允许同步修改震动状态。请在当前输出结束后再修改。")
	assert_true(utility.is_haptic_active(haptic_id), "被拒绝的回调重入不得清除活跃状态。")
	assert_eq(GFVariantData.get_option_int(report, "applied_count"), 1, "回调自身成功时本轮输出仍应按稳定快照完成。")
	utility.dispose()
	assert_false(utility.output_handler.is_valid(), "dispose 应由工具自身释放捕获工具的输出回调。")


func test_haptic_dispose_releases_injected_dependencies_and_callbacks() -> void:
	var utility: GFHapticUtility = GFHapticUtility.new()
	utility.init()
	utility.input_device_utility = GFInputDeviceUtility.new()
	utility.haptic_backend = RefCounted.new()
	utility.output_handler = func(
		_target_type: int,
		_target_id: int,
		_weak_magnitude: float,
		_strong_magnitude: float,
		_duration_seconds: float,
		_metadata: Dictionary
	) -> bool:
		return utility != null
	utility.stop_handler = func(
		_target_type: int,
		_target_id: int,
		_metadata: Dictionary
	) -> bool:
		return utility != null

	utility.dispose()

	assert_null(utility.input_device_utility, "dispose 应释放注入的输入设备工具。")
	assert_null(utility.haptic_backend, "dispose 应释放注入的震动后端。")
	assert_false(utility.output_handler.is_valid(), "dispose 应释放输出回调。")
	assert_false(utility.stop_handler.is_valid(), "dispose 应释放停止回调。")


func test_haptic_utility_clear_stops_and_clears_last_output_targets() -> void:
	var utility: GFHapticUtility = GFHapticUtility.new()
	utility.init()
	var stops: Array[Dictionary] = []
	utility.output_handler = func(
		_target_type: int,
		_target_id: int,
		_weak_magnitude: float,
		_strong_magnitude: float,
		_duration_seconds: float,
		_metadata: Dictionary
	) -> bool:
		return true
	utility.stop_handler = func(target_type: int, target_id: int, _metadata: Dictionary) -> bool:
		stops.append({ "target_type": target_type, "target_id": target_id })
		return true

	var preset: GFHapticPreset = GFHapticPreset.new()
	preset.duration_seconds = 1.0
	preset.weak_magnitude = 0.5
	var _haptic_id: int = utility.play_haptic(&"impact", preset, 0)
	utility.tick(0.01)
	utility.clear()
	var snapshot: Dictionary = utility.get_debug_snapshot()

	assert_eq(stops.size(), 1, "clear 应停止上一帧输出过的目标。")
	assert_eq(GFVariantData.get_option_dictionary(snapshot, "last_output_targets"), {}, "clear 后 last_output_targets 应同步清空。")


func test_haptic_utility_short_tick_outputs_before_finishing() -> void:
	var utility: GFHapticUtility = GFHapticUtility.new()
	utility.init()
	var outputs: Array[Dictionary] = []
	var stops: Array[Dictionary] = []
	utility.output_handler = func(
		target_type: int,
		target_id: int,
		weak_magnitude: float,
		strong_magnitude: float,
		_duration_seconds: float,
		_metadata: Dictionary
	) -> bool:
		outputs.append({
			"target_type": target_type,
			"target_id": target_id,
			"weak_magnitude": weak_magnitude,
			"strong_magnitude": strong_magnitude,
		})
		return true
	utility.stop_handler = func(target_type: int, target_id: int, _metadata: Dictionary) -> bool:
		stops.append({ "target_type": target_type, "target_id": target_id })
		return true

	var preset: GFHapticPreset = GFHapticPreset.new()
	preset.duration_seconds = 0.01
	preset.weak_magnitude = 0.5
	preset.strong_magnitude = 0.25
	var haptic_id: int = utility.play_haptic(&"impact", preset, 0)
	utility.tick(0.1)

	assert_false(utility.is_haptic_active(haptic_id), "短震动在超长 tick 后应结束。")
	assert_eq(outputs.size(), 1, "即使单帧超过持续时间，也应先输出一次采样。")
	assert_eq(stops.size(), 1, "同一帧结束后应停止输出目标。")


func test_haptic_utility_can_target_device_ids() -> void:
	var utility: GFHapticUtility = GFHapticUtility.new()
	utility.init()
	var outputs: Array[Dictionary] = []
	utility.output_handler = func(
		target_type: int,
		target_id: int,
		weak_magnitude: float,
		strong_magnitude: float,
		duration_seconds: float,
		metadata: Dictionary
	) -> bool:
		outputs.append({
			"target_type": target_type,
			"target_id": target_id,
			"weak_magnitude": weak_magnitude,
			"strong_magnitude": strong_magnitude,
			"duration_seconds": duration_seconds,
			"metadata": metadata,
		})
		return true

	var preset: GFHapticPreset = GFHapticPreset.new()
	preset.duration_seconds = 0.2
	preset.weak_magnitude = 0.25
	preset.strong_magnitude = 0.75
	var haptic_id: int = utility.play_haptic_for_device(&"device", preset, 7)

	utility.tick(0.01)

	assert_true(utility.is_haptic_active(haptic_id), "设备震动实例应处于活跃状态。")
	assert_eq(outputs.size(), 1, "设备目标应输出一次。")
	assert_eq(GFVariantData.get_option_int(outputs[0], "target_type"), GFHapticUtility.TargetType.DEVICE, "输出目标应为设备。")
	assert_eq(GFVariantData.get_option_int(outputs[0], "target_id"), 7, "输出设备 ID 应匹配播放请求。")


func test_haptic_default_backend_does_not_report_disconnected_device_as_applied() -> void:
	var utility: GFHapticUtility = GFHapticUtility.new()
	utility.init()
	utility.auto_apply_on_tick = false
	var preset: GFHapticPreset = GFHapticPreset.new()
	preset.duration_seconds = 1.0
	preset.weak_magnitude = 0.5
	var disconnected_device_id: int = 999999
	var _haptic_id: int = utility.play_haptic_for_device(&"device", preset, disconnected_device_id)

	var report: Dictionary = utility.apply_current_outputs()

	assert_eq(GFVariantData.get_option_int(report, "applied_count"), 0, "默认后端不得把未连接设备报告为输出成功。")
	assert_eq(GFVariantData.get_option_array(report, "applied"), [], "未连接设备不得进入成功输出明细。")


# --- 辅助方法 ---

func _shake_sample_is_finite(sample: Dictionary) -> bool:
	return (
		_vector3_is_finite(GFVariantData.get_option_vector3(sample, "position"))
		and _vector3_is_finite(GFVariantData.get_option_vector3(sample, "rotation_degrees"))
		and _vector3_is_finite(GFVariantData.get_option_vector3(sample, "scale"))
		and is_finite(GFVariantData.get_option_float(sample, "intensity"))
		and is_finite(GFVariantData.get_option_float(sample, "progress"))
	)


func _vector3_is_finite(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
