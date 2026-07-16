## GFDisplaySettingsUtility: 通用显示、语言与音频总线设置应用器。
##
## 该工具把抽象设置值应用到 Godot 引擎层。设置值本身由 GFSettingsUtility 管理；
## 未注册 GFSettingsUtility 时，也可以直接作为运行时应用器使用。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFDisplaySettingsUtility
extends GFUtility


# --- 信号 ---

## 某个引擎设置应用完成时发出。
## [br]
## @api public
## [br]
## @param key: 设置键。
## [br]
## @param value: 已应用的值。
## [br]
## @schema value: Variant，与设置键匹配的值，例如 int、Vector2i、String 或 float。
signal display_setting_applied(key: StringName, value: Variant)


# --- 常量 ---

## 窗口模式设置键。
## [br]
## @api public
const WINDOW_MODE_KEY: StringName = &"display/window_mode"

## 窗口尺寸设置键。
## [br]
## @api public
const WINDOW_SIZE_KEY: StringName = &"display/window_size"

## 垂直同步模式设置键。
## [br]
## @api public
const VSYNC_MODE_KEY: StringName = &"display/vsync_mode"

## 语言设置键。
## [br]
## @api public
const LOCALE_KEY: StringName = &"display/locale"

const _PROJECT_WINDOW_WIDTH_OVERRIDE: String = "display/window/size/window_width_override"
const _PROJECT_WINDOW_HEIGHT_OVERRIDE: String = "display/window/size/window_height_override"
const _PROJECT_VIEWPORT_WIDTH: String = "display/window/size/viewport_width"
const _PROJECT_VIEWPORT_HEIGHT: String = "display/window/size/viewport_height"
const _ENGINE_DEFAULT_WINDOWED_SIZE: Vector2i = Vector2i(1152, 648)


# --- 公共变量 ---

## ready() 时是否注册默认设置定义。
## [br]
## @api public
var register_defaults_on_ready: bool = true

## ready() 时是否立刻应用当前设置。
## [br]
## @api public
var apply_on_ready: bool = true

## GFSettingsUtility 中相关设置变化时是否自动应用。
## [br]
## @api public
var auto_apply_setting_changes: bool = true

## 设置变化时是否写入 GFSettingsUtility。
## [br]
## @api public
var persist_changes: bool = true

## 非窗口模式启动且尚无持久化尺寸时使用的窗口尺寸。
##
## 任一分量小于等于 0 时，从项目窗口 override 或 viewport 尺寸推导。
## [br]
## @api public
## [br]
## @since 8.0.0
var default_windowed_size: Vector2i = Vector2i.ZERO

## 音频设置键前缀。
## [br]
## @api public
var audio_setting_prefix: StringName = &"audio"


# --- 私有变量 ---

var _runtime_values: Dictionary = {}
var _connected_settings: GFSettingsUtility = null
var _internal_setting_write_depth: int = 0


# --- GF 生命周期方法 ---

## 初始化显示设置应用器的时间与暂停策略。
## [br]
## @api public
func init() -> void:
	ignore_pause = true
	ignore_time_scale = true


## 注册默认设置、连接设置变化并按配置应用当前值。
## [br]
## @api public
func ready() -> void:
	if register_defaults_on_ready:
		register_default_settings()
	_connect_settings_changed()
	if apply_on_ready:
		apply_all()


## 释放设置连接并清空运行时缓存。
## [br]
## @api public
func dispose() -> void:
	_disconnect_settings_changed()
	_runtime_values.clear()


# --- 公共方法 ---

## 注册显示相关默认设置定义。
## [br]
## @api public
func register_default_settings() -> void:
	var settings: GFSettingsUtility = _get_settings_utility()
	if settings == null:
		return

	var _register_setting_result_126: Variant = settings.register_setting(
		WINDOW_MODE_KEY,
		int(_window_get_mode()),
		GFSettingDefinition.ValueType.INT
	)
	var _register_setting_result_131: Variant = settings.register_setting(
		WINDOW_SIZE_KEY,
		_resolve_initial_windowed_size(),
		GFSettingDefinition.ValueType.VECTOR2I
	)
	var _register_setting_result_136: Variant = settings.register_setting(
		VSYNC_MODE_KEY,
		int(DisplayServer.window_get_vsync_mode()),
		GFSettingDefinition.ValueType.INT
	)
	var _register_setting_result_141: Variant = settings.register_setting(
		LOCALE_KEY,
		OS.get_locale_language(),
		GFSettingDefinition.ValueType.STRING
	)


## 应用所有当前已知显示设置。
## [br]
## @api public
func apply_all() -> void:
	apply_window_mode()
	if get_window_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		_apply_window_size(true)
	apply_vsync_mode()
	apply_locale()
	apply_registered_audio_bus_volumes()


## 设置窗口模式并应用。
## [br]
## @api public
## [br]
## @param mode: 目标窗口模式。
func set_window_mode(mode: DisplayServer.WindowMode) -> void:
	_capture_current_windowed_size(mode)
	_set_setting_value(WINDOW_MODE_KEY, int(mode))
	apply_window_mode()
	if mode == DisplayServer.WINDOW_MODE_WINDOWED:
		_apply_window_size(true)


## 获取窗口模式设置。
## [br]
## @api public
## [br]
## @return 窗口模式。
func get_window_mode() -> DisplayServer.WindowMode:
	var mode_value: int = GFVariantData.to_int(
		_get_setting_value(WINDOW_MODE_KEY, int(_window_get_mode())),
		int(_window_get_mode())
	)
	return _to_window_mode(mode_value)


## 设置是否全屏。
## [br]
## @api public
## [br]
## @param enabled: true 时切换到全屏，false 时切回窗口模式。
func set_fullscreen(enabled: bool) -> void:
	set_window_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)


## 切换全屏状态。
## [br]
## @api public
func toggle_fullscreen() -> void:
	var current_mode: DisplayServer.WindowMode = get_window_mode()
	set_fullscreen(current_mode != DisplayServer.WINDOW_MODE_FULLSCREEN)


## 应用窗口模式设置。
## [br]
## @api public
func apply_window_mode() -> void:
	var mode: DisplayServer.WindowMode = get_window_mode()
	_window_set_mode(mode)
	display_setting_applied.emit(WINDOW_MODE_KEY, int(mode))


## 设置窗口尺寸并应用。
## [br]
## @api public
## [br]
## @param size: 窗口尺寸。
func set_window_size(size: Vector2i) -> void:
	if size.x <= 0 or size.y <= 0:
		push_error("[GFDisplaySettingsUtility] set_window_size 失败：窗口尺寸必须大于 0。")
		return

	_set_setting_value(WINDOW_SIZE_KEY, size)
	apply_window_size()


## 获取窗口尺寸设置。
## [br]
## @api public
## [br]
## @return 窗口尺寸。
func get_window_size() -> Vector2i:
	var value: Variant = _get_setting_value(WINDOW_SIZE_KEY, _resolve_initial_windowed_size())
	if value is Vector2i:
		var size_2i: Vector2i = value
		return size_2i
	if value is Vector2:
		var vector2: Vector2 = value
		return Vector2i(roundi(vector2.x), roundi(vector2.y))
	return _resolve_initial_windowed_size()


## 应用窗口尺寸设置。
## [br]
## @api public
func apply_window_size() -> void:
	_apply_window_size(false)


## 设置垂直同步模式并应用。
## [br]
## @api public
## [br]
## @param mode: VSync 模式。
func set_vsync_mode(mode: DisplayServer.VSyncMode) -> void:
	_set_setting_value(VSYNC_MODE_KEY, int(mode))
	apply_vsync_mode()


## 获取垂直同步模式设置。
## [br]
## @api public
## [br]
## @return VSync 模式。
func get_vsync_mode() -> DisplayServer.VSyncMode:
	var mode_value: int = GFVariantData.to_int(
		_get_setting_value(VSYNC_MODE_KEY, int(DisplayServer.window_get_vsync_mode())),
		int(DisplayServer.window_get_vsync_mode())
	)
	return _to_vsync_mode(mode_value)


## 应用垂直同步设置。
## [br]
## @api public
func apply_vsync_mode() -> void:
	var mode: DisplayServer.VSyncMode = get_vsync_mode()
	DisplayServer.window_set_vsync_mode(mode)
	display_setting_applied.emit(VSYNC_MODE_KEY, int(mode))


## 设置语言并应用。
## [br]
## @api public
## [br]
## @param locale: 语言代码，例如 "en" 或 "zh_CN"。
func set_locale(locale: String) -> void:
	_set_setting_value(LOCALE_KEY, locale)
	apply_locale()


## 获取当前语言设置。
## [br]
## @api public
## [br]
## @return 语言代码。
func get_locale() -> String:
	return GFVariantData.to_text(_get_setting_value(LOCALE_KEY, OS.get_locale_language()), OS.get_locale_language())


## 应用语言设置。
## [br]
## @api public
func apply_locale() -> void:
	var locale: String = get_locale()
	if locale.is_empty():
		return

	TranslationServer.set_locale(locale)
	display_setting_applied.emit(LOCALE_KEY, locale)


## 注册一个音频总线音量设置。
## [br]
## @api public
## [br]
## @param bus_name: 音频总线名。
## [br]
## @param default_linear: 默认线性音量，范围 0 到 1。
func register_audio_bus_volume(bus_name: String, default_linear: float = 1.0) -> void:
	var settings: GFSettingsUtility = _get_settings_utility()
	if settings == null:
		return

	var _register_setting_result_325: Variant = settings.register_setting(
		_get_audio_bus_volume_key(bus_name),
		clampf(default_linear, 0.0, 1.0),
		GFSettingDefinition.ValueType.FLOAT
	)


## 设置音频总线音量并应用。
## [br]
## @api public
## [br]
## @param bus_name: 音频总线名。
## [br]
## @param volume_linear: 线性音量，范围 0 到 1。
func set_audio_bus_volume(bus_name: String, volume_linear: float) -> void:
	var clamped_volume: float = clampf(volume_linear, 0.0, 1.0)
	_set_setting_value(_get_audio_bus_volume_key(bus_name), clamped_volume)
	apply_audio_bus_volume(bus_name)


## 获取音频总线音量。
## [br]
## @api public
## [br]
## @param bus_name: 音频总线名。
## [br]
## @param fallback: 设置缺失时的回退值。
## [br]
## @return 线性音量。
func get_audio_bus_volume(bus_name: String, fallback: float = 1.0) -> float:
	return clampf(GFVariantData.to_float(_get_setting_value(_get_audio_bus_volume_key(bus_name), fallback), fallback), 0.0, 1.0)


## 应用指定音频总线音量。
## [br]
## @api public
## [br]
## @param bus_name: 音频总线名。
func apply_audio_bus_volume(bus_name: String) -> void:
	var volume: float = get_audio_bus_volume(bus_name)
	var volume_db: float = linear_to_db(maxf(volume, 0.0001))
	var applied: bool = false
	var audio: GFAudioUtility = _get_audio_utility()
	if audio != null:
		applied = audio.set_bus_volume_db(bus_name, volume_db)
	else:
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			AudioServer.set_bus_volume_db(bus_index, volume_db)
			applied = true

	if applied:
		display_setting_applied.emit(_get_audio_bus_volume_key(bus_name), volume)
	else:
		push_warning("[GFDisplaySettingsUtility] 无法应用音频总线音量，未找到总线或后端拒绝：%s。" % bus_name)


## 应用所有已注册音频总线音量设置。
## [br]
## @api public
func apply_registered_audio_bus_volumes() -> void:
	var settings: GFSettingsUtility = _get_settings_utility()
	if settings == null:
		return

	var prefix: String = "%s/" % String(audio_setting_prefix)
	for definition: GFSettingDefinition in settings.get_definitions():
		var key: String = String(definition.get_setting_key())
		if key.begins_with(prefix) and key.ends_with("/volume"):
			var bus_name: String = key.trim_prefix(prefix).trim_suffix("/volume")
			apply_audio_bus_volume(bus_name)


# --- 私有/辅助方法 ---

func _apply_window_size(allow_window_mode_transition: bool) -> void:
	var size: Vector2i = get_window_size()
	if size.x <= 0 or size.y <= 0:
		return
	if (
		not allow_window_mode_transition
		and _window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED
	):
		return

	_window_set_size(size)
	display_setting_applied.emit(WINDOW_SIZE_KEY, size)


func _capture_current_windowed_size(target_mode: DisplayServer.WindowMode) -> void:
	if target_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		return
	if _window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var current_size: Vector2i = _window_get_size()
	if current_size.x > 0 and current_size.y > 0:
		_set_setting_value(WINDOW_SIZE_KEY, current_size)


func _resolve_initial_windowed_size() -> Vector2i:
	var current_size: Vector2i = _window_get_size()
	if _window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		if current_size.x > 0 and current_size.y > 0:
			return current_size
	if default_windowed_size.x > 0 and default_windowed_size.y > 0:
		return default_windowed_size

	var override_size: Vector2i = Vector2i(
		_project_setting_int(_PROJECT_WINDOW_WIDTH_OVERRIDE),
		_project_setting_int(_PROJECT_WINDOW_HEIGHT_OVERRIDE)
	)
	if override_size.x > 0 and override_size.y > 0:
		return override_size

	var viewport_size: Vector2i = Vector2i(
		_project_setting_int(_PROJECT_VIEWPORT_WIDTH),
		_project_setting_int(_PROJECT_VIEWPORT_HEIGHT)
	)
	if viewport_size.x > 0 and viewport_size.y > 0:
		return viewport_size
	return _ENGINE_DEFAULT_WINDOWED_SIZE


func _project_setting_int(path: String) -> int:
	return GFVariantData.to_int(ProjectSettings.get_setting(path, 0), 0)


func _window_get_mode() -> DisplayServer.WindowMode:
	return DisplayServer.window_get_mode()


func _window_set_mode(mode: DisplayServer.WindowMode) -> void:
	DisplayServer.window_set_mode(mode)


func _window_get_size() -> Vector2i:
	return DisplayServer.window_get_size()


func _window_set_size(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)


func _set_setting_value(key: StringName, value: Variant) -> void:
	var settings: GFSettingsUtility = _get_settings_utility()
	if settings != null:
		_internal_setting_write_depth += 1
		settings.set_value(key, value, persist_changes)
		_internal_setting_write_depth -= 1
	else:
		_runtime_values[key] = value


func _get_setting_value(key: StringName, fallback: Variant = null) -> Variant:
	var settings: GFSettingsUtility = _get_settings_utility()
	if settings == null:
		return GFVariantData.get_option_value(_runtime_values, key, fallback)
	return settings.get_value(key, fallback)


func _get_settings_utility() -> GFSettingsUtility:
	var arch: GFArchitecture = _get_architecture_or_null()
	if arch == null:
		return null
	var utility: Object = arch.get_utility(GFSettingsUtility)
	if utility is GFSettingsUtility:
		var settings: GFSettingsUtility = utility
		return settings
	return null


func _get_audio_utility() -> GFAudioUtility:
	var arch: GFArchitecture = _get_architecture_or_null()
	if arch == null:
		return null
	var utility: Object = arch.get_utility(GFAudioUtility)
	if utility is GFAudioUtility:
		var audio: GFAudioUtility = utility
		return audio
	return null


func _get_audio_bus_volume_key(bus_name: String) -> StringName:
	return StringName("%s/%s/volume" % [String(audio_setting_prefix), bus_name])


func _connect_settings_changed() -> void:
	var settings: GFSettingsUtility = _get_settings_utility()
	if settings == null or settings == _connected_settings:
		return

	_disconnect_settings_changed()
	_connected_settings = settings
	if not _connected_settings.setting_changed.is_connected(_on_setting_changed):
		var _settings_changed_connected: int = _connected_settings.setting_changed.connect(_on_setting_changed)


func _disconnect_settings_changed() -> void:
	if _connected_settings == null:
		return
	if _connected_settings.setting_changed.is_connected(_on_setting_changed):
		_connected_settings.setting_changed.disconnect(_on_setting_changed)
	_connected_settings = null


func _to_window_mode(value: int) -> DisplayServer.WindowMode:
	match value:
		DisplayServer.WINDOW_MODE_MINIMIZED:
			return DisplayServer.WINDOW_MODE_MINIMIZED
		DisplayServer.WINDOW_MODE_MAXIMIZED:
			return DisplayServer.WINDOW_MODE_MAXIMIZED
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			return DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			return DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		_:
			return DisplayServer.WINDOW_MODE_WINDOWED


func _to_vsync_mode(value: int) -> DisplayServer.VSyncMode:
	match value:
		DisplayServer.VSYNC_DISABLED:
			return DisplayServer.VSYNC_DISABLED
		DisplayServer.VSYNC_ADAPTIVE:
			return DisplayServer.VSYNC_ADAPTIVE
		DisplayServer.VSYNC_MAILBOX:
			return DisplayServer.VSYNC_MAILBOX
		_:
			return DisplayServer.VSYNC_ENABLED


# --- 信号处理函数 ---

func _on_setting_changed(key: StringName, _old_value: Variant, _new_value: Variant) -> void:
	if not auto_apply_setting_changes or _internal_setting_write_depth > 0:
		return

	match key:
		WINDOW_MODE_KEY:
			_capture_current_windowed_size(get_window_mode())
			apply_window_mode()
			if get_window_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
				_apply_window_size(true)
		WINDOW_SIZE_KEY:
			apply_window_size()
		VSYNC_MODE_KEY:
			apply_vsync_mode()
		LOCALE_KEY:
			apply_locale()
		_:
			var key_text: String = String(key)
			var prefix: String = "%s/" % String(audio_setting_prefix)
			if key_text.begins_with(prefix) and key_text.ends_with("/volume"):
				var bus_name: String = key_text.trim_prefix(prefix).trim_suffix("/volume")
				apply_audio_bus_volume(bus_name)
