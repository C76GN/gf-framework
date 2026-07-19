extends GutTest


# --- 常量 ---

const GF_NETWORK_EDITOR_ACTIONS_SCRIPT = preload("res://addons/gf/extensions/network/editor/gf_network_editor_actions.gd")
const GF_NETWORK_CONTRACT_GENERATOR_SCRIPT = preload("res://addons/gf/extensions/network/editor/gf_network_contract_generator.gd")
const CONTRACT_PATHS_SETTING: String = "gf/network/contract_paths"
const CONTRACT_OUTPUT_DIR_SETTING: String = "gf/network/contract_output_dir"


# --- 测试方法 ---

func test_network_editor_actions_contribute_menu_entries_settings_and_sections() -> void:
	var actions: RefCounted = GF_NETWORK_EDITOR_ACTIONS_SCRIPT.new()

	var entries: Array = GFVariantData.as_array(actions.call("get_menu_entries"))
	var setting_records: Array = GFVariantData.as_array(
		actions.call("get_project_setting_records")
	)
	var section_records: Array = GFVariantData.as_array(
		actions.call("get_project_setting_section_records")
	)
	actions.call("cleanup")

	assert_eq(entries.size(), 2, "Network editor tool 应贡献生成与审计两个菜单动作。")
	var entry_ids: Array[StringName] = []
	for entry_value: Variant in entries:
		assert_true(entry_value is Dictionary, "菜单动作应返回 Dictionary。")
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		entry_ids.append(GFVariantData.get_option_string_name(entry, "id"))
	assert_eq(entry_ids, [&"generate_network_contracts", &"audit_network_contracts"])
	assert_eq(setting_records.size(), 2, "Network editor tool 应显式贡献两个项目设置。")
	assert_eq(
		GFVariantData.get_option_string(_find_record(setting_records, "name", CONTRACT_PATHS_SETTING), "name"),
		CONTRACT_PATHS_SETTING
	)
	assert_eq(
		GFVariantData.get_option_string(
			_find_record(setting_records, "name", CONTRACT_OUTPUT_DIR_SETTING),
			"default_value"
		),
		"res://generated/network"
	)
	assert_eq(section_records.size(), 1, "Network editor tool 应贡献独立项目设置分区展示。")
	assert_eq(
		GFVariantData.get_option_string(_find_record(section_records, "path", "gf/network"), "path"),
		"gf/network"
	)


func test_network_contract_generator_script_exposes_generation_api() -> void:
	var generator: RefCounted = GF_NETWORK_CONTRACT_GENERATOR_SCRIPT.new()

	assert_eq(GF_NETWORK_CONTRACT_GENERATOR_SCRIPT.DEFAULT_OUTPUT_DIR, "res://generated/network")
	assert_true(generator.has_method("generate_with_report"), "Network tool package 应包含生成器报告入口。")
	assert_true(generator.has_method("generate_many"), "Network tool package 应包含批量生成入口。")


# --- 私有/辅助方法 ---

func _find_record(records: Array, identity_key: String, identity: String) -> Dictionary:
	for record_value: Variant in records:
		if not record_value is Dictionary:
			continue
		var record: Dictionary = record_value
		if GFVariantData.get_option_string(record, identity_key) == identity:
			return record
	return {}
