## 测试 GFInputProfileBank 的命名重映射配置管理行为。
extends GutTest


# --- 测试方法 ---

## 验证设置 profile 时默认保存配置副本。
func test_set_profile_stores_config_copy() -> void:
	var bank: GFInputProfileBank = GFInputProfileBank.new()
	var config: GFInputRemapConfig = GFInputRemapConfig.new()
	config.set_binding(&"gameplay", &"jump", 0, _make_key_event(KEY_SPACE, true))

	bank.set_profile(&"keyboard", config)
	config.clear_binding(&"gameplay", &"jump", 0)
	var stored: GFInputRemapConfig = bank.get_profile(&"keyboard")

	assert_true(stored.has_binding(&"gameplay", &"jump", 0), "profile bank 应保存配置副本，避免外部修改污染。")
	assert_eq(bank.active_profile_id, &"keyboard", "首个 profile 应自动成为 active profile。")


## 验证 profile ID 会排序返回，active profile 可切换。
func test_profile_ids_are_sorted_and_active_profile_switches() -> void:
	var bank: GFInputProfileBank = GFInputProfileBank.new()
	bank.set_profile(&"zeta", GFInputRemapConfig.new())
	bank.set_profile(&"alpha", GFInputRemapConfig.new())

	var ids: PackedStringArray = bank.get_profile_ids()
	var switched: bool = bank.set_active_profile(&"alpha")

	assert_eq(ids[0], "alpha", "profile ID 应按字典序返回。")
	assert_eq(ids[1], "zeta", "profile ID 应按字典序返回。")
	assert_true(switched, "存在的 profile 应允许设为 active。")
	assert_eq(bank.active_profile_id, &"alpha", "active profile ID 应更新。")


## 验证从资源反序列化来的 String 键也能按 StringName 查询。
func test_string_profile_keys_are_accepted() -> void:
	var bank: GFInputProfileBank = GFInputProfileBank.new()
	bank.profiles["keyboard"] = GFInputRemapConfig.new()

	assert_true(bank.has_profile(&"keyboard"), "String 键 profile 应可用 StringName 查询。")
	assert_true(bank.remove_profile(&"keyboard"), "String 键 profile 应可用 StringName 移除。")
	assert_false(bank.has_profile(&"keyboard"), "移除后 profile 不应继续存在。")


## 验证 active profile 可返回副本。
func test_get_active_profile_can_return_copy() -> void:
	var bank: GFInputProfileBank = GFInputProfileBank.new()
	var config: GFInputRemapConfig = bank.ensure_profile(&"keyboard")
	config.set_binding(&"gameplay", &"jump", 0, _make_key_event(KEY_SPACE, true))

	var duplicate_config: GFInputRemapConfig = bank.get_active_profile(true)
	duplicate_config.clear_binding(&"gameplay", &"jump", 0)

	assert_true(
		bank.get_active_profile().has_binding(&"gameplay", &"jump", 0),
		"请求副本时修改返回值不应影响 bank 内部配置。"
	)


## 验证 Profile bank 可序列化到字典再恢复。
func test_profile_bank_to_dict_roundtrip_preserves_profiles_active_and_custom_data() -> void:
	var bank: GFInputProfileBank = GFInputProfileBank.new()
	var keyboard_config: GFInputRemapConfig = GFInputRemapConfig.new()
	keyboard_config.set_binding(&"gameplay", &"jump", 0, _make_key_event(KEY_SPACE, true))
	bank.set_profile(&"keyboard", keyboard_config)
	bank.set_profile(&"gamepad", GFInputRemapConfig.new())
	var switched: bool = bank.set_active_profile(&"gamepad")
	bank.custom_data = {
		"label": "Player One",
	}

	var restored: GFInputProfileBank = GFInputProfileBank.from_dict(bank.to_dict())
	var restored_keyboard: GFInputRemapConfig = restored.get_profile(&"keyboard")
	var restored_event: InputEventKey = _variant_to_input_event_key(
		restored_keyboard.get_bound_event_or_null(&"gameplay", &"jump", 0)
	)

	assert_true(switched, "测试应能切换 active profile。")
	assert_eq(restored.get_profile_ids(), PackedStringArray(["gamepad", "keyboard"]))
	assert_eq(restored.active_profile_id, &"gamepad")
	assert_eq(GFVariantData.get_option_string(restored.custom_data, "label"), "Player One")
	assert_not_null(restored_event, "Profile bank 往返后应保留 profile 内的输入事件。")
	assert_eq(restored_event.physical_keycode, KEY_SPACE)


## 验证移除 active profile 后会选择剩余 profile。
func test_remove_active_profile_selects_remaining_profile() -> void:
	var bank: GFInputProfileBank = GFInputProfileBank.new()
	bank.set_profile(&"first", GFInputRemapConfig.new())
	bank.set_profile(&"second", GFInputRemapConfig.new())

	var removed: bool = bank.remove_profile(&"first")

	assert_true(removed, "存在的 profile 应可移除。")
	assert_eq(bank.active_profile_id, &"second", "移除 active profile 后应选择剩余 profile。")


## 验证重映射配置可序列化到字典再恢复。
func test_remap_config_to_dict_roundtrip_preserves_events_and_unbinds() -> void:
	var config: GFInputRemapConfig = GFInputRemapConfig.new()
	config.set_binding(&"gameplay", &"jump", 0, _make_key_event(KEY_SPACE, true))
	config.unbind(&"gameplay", &"jump", 1)
	config.set_custom_data("profile_name", "Keyboard")

	var restored: GFInputRemapConfig = GFInputRemapConfig.from_dict(config.to_dict())
	var event: InputEventKey = _variant_to_input_event_key(
		restored.get_bound_event_or_null(&"gameplay", &"jump", 0)
	)

	assert_not_null(event, "序列化恢复后应保留 InputEvent。")
	assert_eq(event.physical_keycode, KEY_SPACE, "InputEventKey 字段应恢复。")
	assert_true(restored.has_binding(&"gameplay", &"jump", 1), "显式解绑也应被序列化。")
	assert_null(restored.get_bound_event_or_null(&"gameplay", &"jump", 1), "显式解绑恢复后应返回 null。")
	assert_eq(GFVariantData.to_text(restored.get_custom_data("profile_name")), "Keyboard", "custom_data 应恢复。")


## 验证资源中保存为 String 的重映射键也能按 StringName API 读取和清理。
func test_remap_config_accepts_string_resource_keys() -> void:
	var config: GFInputRemapConfig = GFInputRemapConfig.new()
	config.remapped_events["gameplay"] = {
		"jump": {
			0: _make_key_event(KEY_SPACE, true),
			1: null,
		},
	}

	var event: InputEventKey = _variant_to_input_event_key(
		config.get_bound_event_or_null(&"gameplay", &"jump", 0)
	)
	assert_not_null(event, "String 键保存的重映射事件应可被 StringName API 读取。")
	assert_eq(event.keycode, KEY_SPACE, "读取到的事件应保持原始按键。")
	assert_true(config.has_binding(&"gameplay", &"jump", 1), "String 键保存的显式解绑也应可被识别。")

	config.clear_binding(&"gameplay", &"jump", 0)
	assert_false(config.has_binding(&"gameplay", &"jump", 0), "按 StringName 清理时应删除原 String 键中的绑定。")
	assert_true(config.has_binding(&"gameplay", &"jump", 1), "清理单个绑定不应移除同动作的显式解绑。")

	config.clear_binding(&"gameplay", &"jump", 1)
	assert_false(config.remapped_events.has("gameplay"), "动作清空后应移除原 String context 键。")


# --- 私有/辅助方法 ---

func _variant_to_input_event_key(value: Variant) -> InputEventKey:
	if value is InputEventKey:
		var input_event: InputEventKey = value
		return input_event
	return null


func _make_key_event(key: Key, pressed: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	return event
