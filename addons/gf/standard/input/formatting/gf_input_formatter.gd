## GFInputFormatter: 输入事件与绑定的轻量文本格式化工具。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFInputFormatter
extends RefCounted


# --- 常量 ---

const _INPUT_EVENT_TOOLS = preload("res://addons/gf/standard/input/common/gf_input_event_tools.gd")


# --- 私有变量 ---

static var _default_registry: GFInputFormatterRegistry = null


# --- 公共方法 ---

## 将 Godot 输入事件格式化为通用文本。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param input_event: 输入事件。
## [br]
## @param options: 可选格式化参数。
## [br]
## @schema options: Dictionary，可包含 unbound_text、formatter_registry 和 provider 特定格式化字段。
## [br]
## @return 可显示文本。
static func input_event_as_text(input_event: InputEvent, options: Dictionary = {}) -> String:
	if input_event == null:
		return GFVariantData.get_option_string(options, "unbound_text", "Unbound")

	for provider: GFInputTextProvider in _get_formatter_registry(options).get_text_providers():
		if provider == null or not provider.supports_event(input_event, options):
			continue
		var provider_text: String = provider.get_event_text(input_event, options)
		if not provider_text.is_empty():
			return provider_text

	var action_event: InputEventAction = _INPUT_EVENT_TOOLS.get_action_event(input_event)
	if action_event != null:
		return String(action_event.action)

	var key_event: InputEventKey = _INPUT_EVENT_TOOLS.get_key_event(input_event)
	if key_event != null:
		return _key_event_as_text(key_event)

	var mouse_button_event: InputEventMouseButton = _INPUT_EVENT_TOOLS.get_mouse_button_event(input_event)
	if mouse_button_event != null:
		return _mouse_button_as_text(mouse_button_event.button_index)

	if input_event is InputEventJoypadButton:
		return GFInputDeviceTextProvider.format_joypad_event(input_event, options)

	if input_event is InputEventJoypadMotion:
		return GFInputDeviceTextProvider.format_joypad_event(input_event, options)

	if input_event is InputEventScreenTouch:
		return "Touch"

	return input_event.as_text()


## 将 Godot 输入事件格式化为 RichTextLabel BBCode。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param input_event: 输入事件。
## [br]
## @param options: 可选格式化参数。
## [br]
## @schema options: Dictionary，可包含 unbound_text、icon_size、formatter_registry 和 provider 特定富文本字段。
## [br]
## @return BBCode 文本。
static func input_event_as_rich_text(input_event: InputEvent, options: Dictionary = {}) -> String:
	if input_event == null:
		return _escape_bbcode(GFVariantData.get_option_string(options, "unbound_text", "Unbound"))

	for provider: GFInputIconProvider in _get_formatter_registry(options).get_icon_providers():
		if provider == null or not provider.supports_event(input_event, options):
			continue
		var rich_text: String = provider.get_event_rich_text(input_event, options)
		if not rich_text.is_empty():
			return rich_text

	return _escape_bbcode(input_event_as_text(input_event, options))


## 获取输入事件图标。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param input_event: 输入事件。
## [br]
## @param options: 可选格式化参数。
## [br]
## @schema options: Dictionary，可包含 formatter_registry，并透传给已注册的图标 provider。
## [br]
## @return 图标资源。
static func input_event_icon(input_event: InputEvent, options: Dictionary = {}) -> Texture2D:
	if input_event == null:
		return null

	for provider: GFInputIconProvider in _get_formatter_registry(options).get_icon_providers():
		if provider == null or not provider.supports_event(input_event, options):
			continue
		var icon: Texture2D = provider.get_event_icon(input_event, options)
		if icon != null:
			return icon
	return null


## 将 InputMap 动作的首选事件格式化为通用文本。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param action_name: InputMap 动作名。
## [br]
## @param options: 可选格式化参数。
## [br]
## @schema options: Dictionary，可包含 unbound_text、preferred_device_type、preferred_event_index、formatter_registry 和 provider 特定格式化字段。
## [br]
## @return 可显示文本。
static func action_as_text(action_name: StringName, options: Dictionary = {}) -> String:
	var fallback_text: String = GFVariantData.get_option_string(options, "unbound_text", "Unbound")
	if action_name == &"":
		return fallback_text

	var selected_event: InputEvent = _select_action_event(action_name, options)
	if selected_event == null:
		return fallback_text
	return input_event_as_text(selected_event, options)


## 将 InputMap 动作的首选事件格式化为 RichTextLabel BBCode。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param action_name: InputMap 动作名。
## [br]
## @param options: 可选格式化参数。
## [br]
## @schema options: Dictionary，可包含 unbound_text、icon_size、preferred_device_type、preferred_event_index、prefer_action_icon、formatter_registry 和 provider 特定富文本字段。
## [br]
## @return BBCode 文本。
static func action_as_rich_text(action_name: StringName, options: Dictionary = {}) -> String:
	var fallback_text: String = _escape_bbcode(GFVariantData.get_option_string(options, "unbound_text", "Unbound"))
	if action_name == &"":
		return fallback_text

	if GFVariantData.get_option_bool(options, "prefer_action_icon", false):
		var action_rich_text: String = _action_event_as_rich_text(action_name, options)
		if not action_rich_text.is_empty():
			return action_rich_text

	var selected_event: InputEvent = _select_action_event(action_name, options)
	if selected_event != null:
		return input_event_as_rich_text(selected_event, options)

	var fallback_rich_text: String = _action_event_as_rich_text(action_name, options)
	return fallback_rich_text if not fallback_rich_text.is_empty() else fallback_text


## 获取 InputMap 动作的首选图标。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param action_name: InputMap 动作名。
## [br]
## @param options: 可选格式化参数。
## [br]
## @schema options: Dictionary，可包含 preferred_device_type、preferred_event_index、prefer_action_icon、formatter_registry 和 provider 特定图标字段。
## [br]
## @return 图标资源。
static func action_icon(action_name: StringName, options: Dictionary = {}) -> Texture2D:
	if action_name == &"":
		return null

	if GFVariantData.get_option_bool(options, "prefer_action_icon", false):
		var action_texture: Texture2D = _action_event_icon(action_name, options)
		if action_texture != null:
			return action_texture

	var selected_event: InputEvent = _select_action_event(action_name, options)
	if selected_event != null:
		var event_texture: Texture2D = input_event_icon(selected_event, options)
		if event_texture != null:
			return event_texture
	return _action_event_icon(action_name, options)


## 将绑定格式化为通用文本。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param binding: 输入绑定。
## [br]
## @param options: 可选格式化参数。
## [br]
## @schema options: Dictionary，可包含 unbound_text、formatter_registry 和 provider 特定格式化字段。
## [br]
## @return 可显示文本。
static func binding_as_text(binding: GFInputBinding, options: Dictionary = {}) -> String:
	if binding == null:
		return GFVariantData.get_option_string(options, "unbound_text", "Unbound")
	if not binding.display_name.is_empty():
		return binding.display_name
	return input_event_as_text(binding.input_event, options)


## 将绑定格式化为 RichTextLabel BBCode。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param binding: 输入绑定。
## [br]
## @param options: 可选格式化参数。
## [br]
## @schema options: Dictionary，可包含 unbound_text、icon_size、formatter_registry 和 provider 特定富文本字段。
## [br]
## @return BBCode 文本。
static func binding_as_rich_text(binding: GFInputBinding, options: Dictionary = {}) -> String:
	if binding == null:
		return _escape_bbcode(GFVariantData.get_option_string(options, "unbound_text", "Unbound"))
	if not binding.display_name.is_empty():
		return _escape_bbcode(binding.display_name)
	return input_event_as_rich_text(binding.input_event, options)


## 将映射的当前有效绑定格式化为通用文本。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param mapping: 输入映射。
## [br]
## @param context_id: 上下文标识。
## [br]
## @param remap_config: 可选重映射配置。
## [br]
## @param options: 可选格式化参数。
## [br]
## @schema options: Dictionary，可包含 unbound_text、formatter_registry 和 provider 特定格式化字段。
## [br]
## @return 可显示文本。
static func mapping_as_text(
	mapping: GFInputMapping,
	context_id: StringName = &"",
	remap_config: GFInputRemapConfig = null,
	options: Dictionary = {}
) -> String:
	if mapping == null:
		return ""

	var action_id: StringName = mapping.get_action_id()
	var parts: Array[String] = []
	for index: int in range(mapping.bindings.size()):
		var binding: GFInputBinding = mapping.bindings[index]
		if binding == null:
			continue

		var event: InputEvent = binding.input_event
		if remap_config != null and remap_config.has_binding(context_id, action_id, index):
			event = remap_config.get_bound_event_or_null(context_id, action_id, index)
		parts.append(input_event_as_text(event, options))

	return " / ".join(parts)


## 将映射的当前有效绑定格式化为 RichTextLabel BBCode。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param mapping: 输入映射。
## [br]
## @param context_id: 上下文标识。
## [br]
## @param remap_config: 可选重映射配置。
## [br]
## @param options: 可选格式化参数。
## [br]
## @schema options: Dictionary，可包含 unbound_text、icon_size、formatter_registry 和 provider 特定富文本字段。
## [br]
## @return BBCode 文本。
static func mapping_as_rich_text(
	mapping: GFInputMapping,
	context_id: StringName = &"",
	remap_config: GFInputRemapConfig = null,
	options: Dictionary = {}
) -> String:
	if mapping == null:
		return ""

	var action_id: StringName = mapping.get_action_id()
	var parts: Array[String] = []
	for index: int in range(mapping.bindings.size()):
		var binding: GFInputBinding = mapping.bindings[index]
		if binding == null:
			continue

		var event: InputEvent = binding.input_event
		if remap_config != null and remap_config.has_binding(context_id, action_id, index):
			event = remap_config.get_bound_event_or_null(context_id, action_id, index)
		parts.append(input_event_as_rich_text(event, options))

	return " / ".join(parts)


## 获取默认 provider registry。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 默认 provider registry。
static func get_default_registry() -> GFInputFormatterRegistry:
	if _default_registry == null:
		_default_registry = GFInputFormatterRegistry.new()
	return _default_registry


## 设置默认 provider registry。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param registry: 新的默认 provider registry；传入 null 会重建空 registry。
static func set_default_registry(registry: GFInputFormatterRegistry) -> void:
	_default_registry = registry if registry != null else GFInputFormatterRegistry.new()


## 注册文本 provider 并返回释放句柄。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param provider: 文本 provider。
## [br]
## @param owner: 可选拥有者；拥有者释放后注册会自动失效。
## [br]
## @return 注册句柄；provider 为空时返回非活动句柄。
static func register_text_provider(
	provider: GFInputTextProvider,
	owner: Object = null
) -> GFInputProviderRegistration:
	return get_default_registry().register_text_provider(provider, owner)


## 注册文本 provider。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param provider: 文本 provider。
## [br]
## @param owner: 可选拥有者；拥有者释放后注册会自动失效。
static func add_text_provider(provider: GFInputTextProvider, owner: Object = null) -> void:
	get_default_registry().add_text_provider(provider, owner)


## 移除文本 provider。
## [br]
## @api public
## [br]
## @param provider: 文本 provider。
static func remove_text_provider(provider: GFInputTextProvider) -> void:
	var _removed: bool = get_default_registry().remove_text_provider(provider)


## 清空文本 provider。
## [br]
## @api public
static func clear_text_providers() -> void:
	get_default_registry().clear_text_providers()


## 获取已注册文本 provider。
## [br]
## @api public
## [br]
## @return provider 列表副本。
static func get_text_providers() -> Array[GFInputTextProvider]:
	return get_default_registry().get_text_providers()


## 注册图标 provider 并返回释放句柄。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param provider: 图标 provider。
## [br]
## @param owner: 可选拥有者；拥有者释放后注册会自动失效。
## [br]
## @return 注册句柄；provider 为空时返回非活动句柄。
static func register_icon_provider(
	provider: GFInputIconProvider,
	owner: Object = null
) -> GFInputProviderRegistration:
	return get_default_registry().register_icon_provider(provider, owner)


## 注册图标 provider。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param provider: 图标 provider。
## [br]
## @param owner: 可选拥有者；拥有者释放后注册会自动失效。
static func add_icon_provider(provider: GFInputIconProvider, owner: Object = null) -> void:
	get_default_registry().add_icon_provider(provider, owner)


## 移除图标 provider。
## [br]
## @api public
## [br]
## @param provider: 图标 provider。
static func remove_icon_provider(provider: GFInputIconProvider) -> void:
	var _removed: bool = get_default_registry().remove_icon_provider(provider)


## 清空图标 provider。
## [br]
## @api public
static func clear_icon_providers() -> void:
	get_default_registry().clear_icon_providers()


## 获取已注册图标 provider。
## [br]
## @api public
## [br]
## @return provider 列表副本。
static func get_icon_providers() -> Array[GFInputIconProvider]:
	return get_default_registry().get_icon_providers()


# --- 私有/辅助方法 ---

static func _select_action_event(action_name: StringName, options: Dictionary) -> InputEvent:
	var action_events: Array[InputEvent] = _get_action_events(action_name)
	if action_events.is_empty():
		return null

	var preferred_device_type: StringName = GFVariantData.get_option_string_name(options, "preferred_device_type", &"")
	var candidate_events: Array[InputEvent] = _filter_action_events_by_device(action_events, preferred_device_type)
	if candidate_events.is_empty():
		candidate_events = action_events

	var preferred_index: int = maxi(GFVariantData.get_option_int(options, "preferred_event_index", 0), 0)
	if preferred_index >= candidate_events.size():
		preferred_index = 0
	return candidate_events[preferred_index]


static func _get_action_events(action_name: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	if InputMap.has_action(action_name):
		for event_value: Variant in InputMap.action_get_events(action_name):
			var input_event: InputEvent = _INPUT_EVENT_TOOLS.get_input_event(event_value)
			if input_event != null:
				events.append(input_event)
	if not events.is_empty():
		return events
	return _get_project_setting_action_events(action_name)


static func _get_project_setting_action_events(action_name: StringName) -> Array[InputEvent]:
	var setting_name: String = "input/%s" % String(action_name)
	if not ProjectSettings.has_setting(setting_name):
		return []

	var setting_value: Variant = ProjectSettings.get_setting(setting_name)
	if not (setting_value is Dictionary):
		return []

	var setting_dictionary: Dictionary = setting_value
	var event_values: Variant = GFVariantData.get_option_value(setting_dictionary, "events", [])
	if not (event_values is Array):
		return []

	var events: Array[InputEvent] = []
	var event_array: Array = event_values
	for event_value: Variant in event_array:
		var input_event: InputEvent = _INPUT_EVENT_TOOLS.get_input_event(event_value)
		if input_event != null:
			events.append(input_event)
	return events


static func _filter_action_events_by_device(
	action_events: Array[InputEvent],
	preferred_device_type: StringName
) -> Array[InputEvent]:
	if preferred_device_type == &"" or preferred_device_type == &"any":
		return action_events.duplicate()

	var result: Array[InputEvent] = []
	for input_event: InputEvent in action_events:
		if _event_matches_preferred_device_type(input_event, preferred_device_type):
			result.append(input_event)
	return result


static func _event_matches_preferred_device_type(
	input_event: InputEvent,
	preferred_device_type: StringName
) -> bool:
	match String(preferred_device_type).strip_edges().to_lower():
		"keyboard_mouse", "key_mouse", "keys_mouse":
			return input_event is InputEventKey or input_event is InputEventMouse
		"keyboard", "key", "keys":
			return input_event is InputEventKey
		"mouse":
			return input_event is InputEventMouse
		"joypad", "gamepad", "controller":
			return input_event is InputEventJoypadButton or input_event is InputEventJoypadMotion
		"touch", "screen":
			return input_event is InputEventScreenTouch or input_event is InputEventScreenDrag
		_:
			return false


static func _action_event_as_rich_text(action_name: StringName, options: Dictionary) -> String:
	var action_event: InputEventAction = _make_action_event(action_name)
	for provider: GFInputIconProvider in _get_formatter_registry(options).get_icon_providers():
		if provider == null or not provider.supports_event(action_event, options):
			continue
		var rich_text: String = provider.get_event_rich_text(action_event, options)
		if not rich_text.is_empty():
			return rich_text
	return ""


static func _action_event_icon(action_name: StringName, options: Dictionary) -> Texture2D:
	var action_event: InputEventAction = _make_action_event(action_name)
	for provider: GFInputIconProvider in _get_formatter_registry(options).get_icon_providers():
		if provider == null or not provider.supports_event(action_event, options):
			continue
		var icon: Texture2D = provider.get_event_icon(action_event, options)
		if icon != null:
			return icon
	return null


static func _make_action_event(action_name: StringName) -> InputEventAction:
	var action_event: InputEventAction = InputEventAction.new()
	action_event.action = action_name
	action_event.pressed = true
	action_event.strength = 1.0
	return action_event


static func _get_formatter_registry(options: Dictionary) -> GFInputFormatterRegistry:
	var registry_value: Variant = GFVariantData.get_option_value(options, &"formatter_registry")
	if registry_value is GFInputFormatterRegistry:
		var registry: GFInputFormatterRegistry = registry_value
		return registry
	return get_default_registry()


static func _key_event_as_text(event: InputEventKey) -> String:
	var parts: Array[String] = []
	if event.ctrl_pressed:
		parts.append("Ctrl")
	if event.alt_pressed:
		parts.append("Alt")
	if event.shift_pressed:
		parts.append("Shift")
	if event.meta_pressed:
		parts.append("Meta")

	var keycode: Key = event.physical_keycode
	if keycode == KEY_NONE:
		keycode = event.keycode

	var key_text: String = OS.get_keycode_string(keycode)
	parts.append(key_text if not key_text.is_empty() else "Key %d" % int(keycode))
	return " + ".join(parts)


static func _mouse_button_as_text(button: MouseButton) -> String:
	match button:
		MOUSE_BUTTON_LEFT:
			return "Mouse Left"
		MOUSE_BUTTON_RIGHT:
			return "Mouse Right"
		MOUSE_BUTTON_MIDDLE:
			return "Mouse Middle"
		MOUSE_BUTTON_WHEEL_UP:
			return "Mouse Wheel Up"
		MOUSE_BUTTON_WHEEL_DOWN:
			return "Mouse Wheel Down"
		_:
			return "Mouse Button %d" % int(button)


static func _escape_bbcode(text: String) -> String:
	var result: String = ""
	for index: int in range(text.length()):
		var character: String = text.substr(index, 1)
		match character:
			"[":
				result += "[lb]"
			"]":
				result += "[rb]"
			_:
				result += character
	return result
