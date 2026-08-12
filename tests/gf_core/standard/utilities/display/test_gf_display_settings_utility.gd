## 测试 GFDisplaySettingsUtility 的运行时设置应用和 GFSettingsUtility 集成。
extends GutTest


# --- 私有变量 ---

var _arch: GFArchitecture = null
var _original_locale: String = ""


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_original_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_original_locale)
	if _arch != null:
		_arch.dispose()
		_arch = null
	Gf._architecture = null


# --- 测试方法 ---

func test_runtime_locale_works_without_settings_utility() -> void:
	var display: GFDisplaySettingsUtility = GFDisplaySettingsUtility.new()
	display.init()

	display.set_locale("en")

	assert_eq(display.get_locale(), "en", "未注册 GFSettingsUtility 时也应保留运行时设置值。")
	assert_eq(TranslationServer.get_locale(), "en", "运行时设置应直接应用到 TranslationServer。")
	display.dispose()


func test_external_settings_change_auto_applies_locale() -> void:
	_arch = GFArchitecture.new()
	var settings: GFSettingsUtility = GFSettingsUtility.new()
	settings.persistence_enabled = false
	settings.auto_load_on_init = false
	settings.auto_save_on_change = false
	var display: GFDisplaySettingsUtility = GFDisplaySettingsUtility.new()
	display.register_defaults_on_ready = false
	display.apply_on_ready = false

	await _arch.register_utility_instance(settings)
	await _arch.register_utility_instance(display)
	await Gf.set_architecture(_arch)

	settings.set_value(GFDisplaySettingsUtility.LOCALE_KEY, "en", false)

	assert_eq(TranslationServer.get_locale(), "en", "外部设置变化应自动应用到引擎层。")


func test_architecture_activation_load_reapplies_persisted_display_state() -> void:
	_arch = GFArchitecture.new()
	var store: RecordingSettingsLoadStore = RecordingSettingsLoadStore.new()
	store.payload = {
		GFDisplaySettingsUtility.WINDOW_MODE_KEY: int(DisplayServer.WINDOW_MODE_WINDOWED),
		GFDisplaySettingsUtility.WINDOW_SIZE_KEY: Vector2i(960, 540),
	}
	var settings: GFSettingsUtility = GFSettingsUtility.new()
	settings.auto_load_on_init = true
	settings.auto_save_on_change = false
	var display: FakeWindowDisplaySettingsUtility = FakeWindowDisplaySettingsUtility.new()
	display.engine_mode = DisplayServer.WINDOW_MODE_WINDOWED
	display.engine_size = Vector2i(1152, 648)

	assert_true(await _arch.register_utility_instance_as(store, GFSettingsStoreUtility))
	assert_true(await _arch.register_utility_instance(settings))
	assert_true(await _arch.register_utility_instance(display))
	assert_true(await _arch.init())

	var restored_size_value: Variant = settings.get_value(
		GFDisplaySettingsUtility.WINDOW_SIZE_KEY
	)
	assert_true(restored_size_value is Vector2i)
	if restored_size_value is Vector2i:
		var restored_size: Vector2i = restored_size_value
		assert_eq(
			restored_size,
			Vector2i(960, 540),
			"Settings activation 必须先恢复持久化显示尺寸。"
		)
	assert_eq(
		display.engine_size,
		Vector2i(960, 540),
		"Settings activation 静默替换完成后，Display 必须重新应用完整持久化状态。"
	)


func test_architecture_activation_load_respects_apply_on_ready_opt_out() -> void:
	_arch = GFArchitecture.new()
	var store: RecordingSettingsLoadStore = RecordingSettingsLoadStore.new()
	store.payload = {
		GFDisplaySettingsUtility.WINDOW_MODE_KEY: int(DisplayServer.WINDOW_MODE_WINDOWED),
		GFDisplaySettingsUtility.WINDOW_SIZE_KEY: Vector2i(960, 540),
	}
	var settings: GFSettingsUtility = GFSettingsUtility.new()
	settings.auto_load_on_init = true
	settings.auto_save_on_change = false
	var display: FakeWindowDisplaySettingsUtility = FakeWindowDisplaySettingsUtility.new()
	display.apply_on_ready = false
	display.engine_mode = DisplayServer.WINDOW_MODE_WINDOWED
	display.engine_size = Vector2i(1152, 648)

	assert_true(await _arch.register_utility_instance_as(store, GFSettingsStoreUtility))
	assert_true(await _arch.register_utility_instance(settings))
	assert_true(await _arch.register_utility_instance(display))
	assert_true(await _arch.init())

	assert_eq(
		display.engine_size,
		Vector2i(1152, 648),
		"apply_on_ready=false 必须同时关闭 ready 与延迟加载完成后的自动应用。"
	)


func test_dispose_disconnects_settings_load_completion() -> void:
	_arch = GFArchitecture.new()
	var store: RecordingSettingsLoadStore = RecordingSettingsLoadStore.new()
	var settings: GFSettingsUtility = GFSettingsUtility.new()
	settings.auto_load_on_init = false
	settings.auto_save_on_change = false
	var display: FakeWindowDisplaySettingsUtility = FakeWindowDisplaySettingsUtility.new()
	display.engine_mode = DisplayServer.WINDOW_MODE_WINDOWED
	display.engine_size = Vector2i(1152, 648)

	assert_true(await _arch.register_utility_instance_as(store, GFSettingsStoreUtility))
	assert_true(await _arch.register_utility_instance(settings))
	assert_true(await _arch.register_utility_instance(display))
	assert_true(await _arch.init())
	display.dispose()
	store.payload = {
		GFDisplaySettingsUtility.WINDOW_MODE_KEY: int(DisplayServer.WINDOW_MODE_WINDOWED),
		GFDisplaySettingsUtility.WINDOW_SIZE_KEY: Vector2i(960, 540),
	}

	var load_result: GFSettingsLoadResult = settings.load_settings()

	assert_true(load_result.was_applied())
	assert_eq(
		display.engine_size,
		Vector2i(1152, 648),
		"Display dispose 后不得继续响应 Settings 加载完成信号。"
	)


func test_external_window_mode_change_to_windowed_applies_saved_size() -> void:
	_arch = GFArchitecture.new()
	var settings: GFSettingsUtility = GFSettingsUtility.new()
	settings.persistence_enabled = false
	settings.auto_load_on_init = false
	settings.auto_save_on_change = false
	var display: GFDisplaySettingsUtility = GFDisplaySettingsUtility.new()
	display.register_defaults_on_ready = false
	display.apply_on_ready = false
	var original_mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var original_size: Vector2i = DisplayServer.window_get_size()

	await _arch.register_utility_instance(settings)
	await _arch.register_utility_instance(display)
	await Gf.set_architecture(_arch)
	var target_size: Vector2i = Vector2i(maxi(original_size.x - 8, 320), maxi(original_size.y - 8, 240))
	settings.set_value(GFDisplaySettingsUtility.WINDOW_SIZE_KEY, target_size, false)
	watch_signals(display)

	settings.set_value(GFDisplaySettingsUtility.WINDOW_MODE_KEY, DisplayServer.WINDOW_MODE_WINDOWED, false)
	var applied_parameters: Array = GFVariantData.as_array(get_signal_parameters(display, "display_setting_applied"))

	assert_eq(
		applied_parameters,
		[GFDisplaySettingsUtility.WINDOW_SIZE_KEY, target_size],
		"切回窗口模式后最近一次应用信号应恢复保存的窗口尺寸。"
	)
	DisplayServer.window_set_mode(original_mode)
	DisplayServer.window_set_size(original_size)


func test_fullscreen_start_uses_explicit_windowed_fallback() -> void:
	var display: FakeWindowDisplaySettingsUtility = FakeWindowDisplaySettingsUtility.new()
	display.register_defaults_on_ready = false
	display.apply_on_ready = false
	display.default_windowed_size = Vector2i(960, 540)
	display.engine_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	display.engine_size = Vector2i(1920, 1080)
	display.init()

	var fallback_size: Vector2i = display.get_window_size()

	assert_eq(fallback_size, Vector2i(960, 540), "非窗口模式启动时不应把全屏尺寸误作窗口尺寸。")
	display.dispose()


func test_leaving_windowed_mode_captures_current_window_size() -> void:
	var display: FakeWindowDisplaySettingsUtility = FakeWindowDisplaySettingsUtility.new()
	display.register_defaults_on_ready = false
	display.apply_on_ready = false
	display.persist_changes = false
	display.init()
	var target_size: Vector2i = Vector2i(960, 540)
	display.engine_mode = DisplayServer.WINDOW_MODE_WINDOWED
	display.engine_size = target_size
	display.set_window_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	assert_eq(display.get_window_size(), target_size, "离开窗口模式前应保存最后一次有效窗口尺寸。")
	assert_eq(display.engine_mode, DisplayServer.WINDOW_MODE_FULLSCREEN, "捕获尺寸后仍应应用目标窗口模式。")
	display.dispose()


func test_audio_bus_volume_uses_registered_setting_value() -> void:
	_arch = GFArchitecture.new()
	var settings: GFSettingsUtility = GFSettingsUtility.new()
	settings.persistence_enabled = false
	settings.auto_load_on_init = false
	settings.auto_save_on_change = false
	var display: GFDisplaySettingsUtility = GFDisplaySettingsUtility.new()
	display.register_defaults_on_ready = false
	display.apply_on_ready = false

	await _arch.register_utility_instance(settings)
	await _arch.register_utility_instance(display)
	await Gf.set_architecture(_arch)

	var original_volume: float = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	display.register_audio_bus_volume("Master", original_volume)
	display.set_audio_bus_volume("Master", 0.5)
	var applied_volume: float = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))

	assert_almost_eq(applied_volume, 0.5, 0.05, "音频总线音量设置应应用到 AudioServer。")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(maxf(original_volume, 0.0001)))


func test_missing_audio_bus_does_not_emit_applied_signal() -> void:
	var display: GFDisplaySettingsUtility = GFDisplaySettingsUtility.new()
	display.register_defaults_on_ready = false
	display.apply_on_ready = false
	display.init()
	watch_signals(display)

	display.set_audio_bus_volume("__gf_missing_bus__", 0.5)

	assert_signal_not_emitted(display, "display_setting_applied", "缺失音频总线不应发出应用成功信号。")
	assert_push_warning("[GFDisplaySettingsUtility] 无法应用音频总线音量，未找到总线或后端拒绝：__gf_missing_bus__。")
	display.dispose()


func test_audio_bus_volume_rejects_non_finite_input_without_backend_call() -> void:
	var audio: RecordingAudioUtility = RecordingAudioUtility.new()
	var display: RecordingAudioDisplaySettingsUtility = RecordingAudioDisplaySettingsUtility.new()
	display.audio_backend = audio
	display.register_defaults_on_ready = false
	display.apply_on_ready = false
	display.init()

	display.set_audio_bus_volume("Master", 0.5)
	display.set_audio_bus_volume("Master", NAN)
	display.set_audio_bus_volume("Master", INF)

	assert_eq(audio.volume_write_count, 1, "NaN/Infinity 不得到达音频后端。")
	assert_true(is_finite(audio.last_volume_db), "音频后端只应接收有限 dB。")
	assert_almost_eq(display.get_audio_bus_volume("Master"), 0.5, 0.001, "非法输入不得覆盖最后一个有效音量。")
	assert_push_warning("[GFDisplaySettingsUtility] 已拒绝非有限音频总线音量：Master。")
	assert_push_warning("[GFDisplaySettingsUtility] 已拒绝非有限音频总线音量：Master。")
	display.dispose()


# --- 测试替身 ---

class RecordingAudioUtility:
	extends GFAudioUtility

	var volume_write_count: int = 0
	var last_volume_db: float = 0.0

	func set_bus_volume_db(_bus_name: String, volume_db: float, _transition_seconds: float = 0.0) -> bool:
		volume_write_count += 1
		last_volume_db = volume_db
		return true


class RecordingAudioDisplaySettingsUtility:
	extends GFDisplaySettingsUtility

	var audio_backend: GFAudioUtility = null

	func _get_audio_utility() -> GFAudioUtility:
		return audio_backend


class RecordingSettingsLoadStore:
	extends GFSettingsStoreUtility

	var payload: Dictionary = {}

	func is_persistence_enabled() -> bool:
		return true

	func read_settings(_file_name: String) -> GFStorageReadResult:
		return GFStorageReadResult.new().configure_success(payload)

	func write_settings(_file_name: String, _data: Dictionary) -> Error:
		return OK



class FakeWindowDisplaySettingsUtility:
	extends GFDisplaySettingsUtility

	var engine_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
	var engine_size: Vector2i = Vector2i(1152, 648)

	func _window_get_mode() -> DisplayServer.WindowMode:
		return engine_mode

	func _window_set_mode(mode: DisplayServer.WindowMode) -> void:
		engine_mode = mode

	func _window_get_size() -> Vector2i:
		return engine_size

	func _window_set_size(size: Vector2i) -> void:
		engine_size = size
