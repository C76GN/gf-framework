## 测试通用反馈采样与接收器。
extends GutTest


# --- 常量 ---

const GF_FEEDBACK_EXTENSION = preload("res://addons/gf/extensions/feedback/extension.gd")


# --- 测试方法 ---

func test_feedback_extension_installer_registers_shake_and_haptic_utilities() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var installer: GFInstaller = GF_FEEDBACK_EXTENSION.new()

	installer.install(architecture)

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
