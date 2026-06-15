## 测试 GFProjectSettingsTools 的默认值和属性信息注册。
extends GutTest


# --- 常量 ---

const GF_PROJECT_SETTINGS_TOOLS = preload("res://addons/gf/kernel/core/gf_project_settings_tools.gd")
const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

const TEST_SETTING: String = "gf/tests/project_settings_tools/value"
const TEST_RANGE_SETTING: String = "gf/tests/project_settings_tools/range"


# --- Godot 生命周期方法 ---

func after_each() -> void:
	_restore_setting(TEST_SETTING)
	_restore_setting(TEST_RANGE_SETTING)


# --- 测试 ---

func test_ensure_setting_writes_missing_default() -> void:
	_restore_setting(TEST_SETTING)

	var wrote_default: bool = GF_PROJECT_SETTINGS_TOOLS.ensure_setting(TEST_SETTING, 42, {
		"register_property_info": false,
	})

	assert_true(wrote_default, "缺失设置应写入默认值。")
	var stored_value: int = GF_VARIANT_ACCESS.to_int(ProjectSettings.get_setting(TEST_SETTING, 0))
	assert_eq(stored_value, 42)


func test_ensure_setting_preserves_existing_value() -> void:
	ProjectSettings.set_setting(TEST_SETTING, 7)

	var wrote_default: bool = GF_PROJECT_SETTINGS_TOOLS.ensure_setting(TEST_SETTING, 42, {
		"register_property_info": false,
	})

	assert_false(wrote_default, "已有设置不应被默认值覆盖。")
	var stored_value: int = GF_VARIANT_ACCESS.to_int(ProjectSettings.get_setting(TEST_SETTING, 0))
	assert_eq(stored_value, 7)


func test_ensure_setting_registers_property_info() -> void:
	_restore_setting(TEST_RANGE_SETTING)

	var wrote_default: bool = GF_PROJECT_SETTINGS_TOOLS.ensure_setting(TEST_RANGE_SETTING, 3, {
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,10,1",
		"basic": true,
	})
	var property_info: Dictionary = _find_project_property(TEST_RANGE_SETTING)

	assert_true(wrote_default, "首次声明应写入默认值。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(property_info, "type", -1), TYPE_INT)
	assert_eq(GF_VARIANT_ACCESS.get_option_int(property_info, "hint", -1), PROPERTY_HINT_RANGE)
	assert_eq(GF_VARIANT_ACCESS.get_option_string(property_info, "hint_string", ""), "0,10,1")


func test_register_property_info_can_describe_existing_setting() -> void:
	ProjectSettings.set_setting(TEST_SETTING, "res://gf/generated.gd")

	GF_PROJECT_SETTINGS_TOOLS.register_property_info(TEST_SETTING, TYPE_STRING, {
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.gd",
	})
	var property_info: Dictionary = _find_project_property(TEST_SETTING)

	assert_eq(GF_VARIANT_ACCESS.get_option_int(property_info, "type", -1), TYPE_STRING)
	assert_eq(GF_VARIANT_ACCESS.get_option_int(property_info, "hint", -1), PROPERTY_HINT_FILE)
	assert_eq(GF_VARIANT_ACCESS.get_option_string(property_info, "hint_string", ""), "*.gd")


# --- 私有/辅助方法 ---

func _find_project_property(setting_name: String) -> Dictionary:
	for property_info: Dictionary in ProjectSettings.get_property_list():
		if GF_VARIANT_ACCESS.get_option_string(property_info, "name", "") == setting_name:
			return property_info
	return {}


func _restore_setting(setting_name: String) -> void:
	if ProjectSettings.has_setting(setting_name):
		ProjectSettings.clear(setting_name)
