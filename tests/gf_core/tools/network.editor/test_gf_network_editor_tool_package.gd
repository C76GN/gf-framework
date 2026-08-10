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


func test_network_contract_generator_rejects_batch_output_collisions_before_writing() -> void:
	var stamp: int = Time.get_ticks_usec()
	var first_contract_path: String = "user://gf_network_collision_first_%d.tres" % stamp
	var second_contract_path: String = "user://gf_network_collision_second_%d.tres" % stamp
	var output_dir: String = "user://gf_network_collision_output_%d" % stamp
	var output_path: String = output_dir.path_join("foo_bar_network_messages.gd")
	var first_contract: GFNetworkContract = _make_contract(&"foo-bar")
	var second_contract: GFNetworkContract = _make_contract(&"foo_bar")
	assert_eq(ResourceSaver.save(first_contract, first_contract_path), OK)
	assert_eq(ResourceSaver.save(second_contract, second_contract_path), OK)
	var generator: GFNetworkContractGenerator = GF_NETWORK_CONTRACT_GENERATOR_SCRIPT.new()

	var report: Dictionary = generator.generate_many(
		PackedStringArray([first_contract_path, second_contract_path]),
		output_dir,
		true,
		{ "scan_filesystem": false }
	)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "批次输出碰撞必须使整个预检失败。")
	assert_eq(
		GFVariantData.get_option_string(_find_issue(report, "duplicate_output_path"), "kind"),
		"duplicate_output_path",
		"碰撞应提供稳定 issue kind。"
	)
	assert_false(FileAccess.file_exists(output_path), "碰撞批次必须保持零写入。")
	_remove_file_if_present(first_contract_path)
	_remove_file_if_present(second_contract_path)
	_remove_file_if_present(output_path)
	_remove_directory_if_present(output_dir)


func test_network_contract_generator_preflights_all_definitions_before_writing() -> void:
	var stamp: int = Time.get_ticks_usec()
	var valid_path: String = "user://gf_network_plan_valid_%d.tres" % stamp
	var invalid_path: String = "user://gf_network_plan_invalid_%d.tres" % stamp
	var output_dir: String = "user://gf_network_plan_output_%d" % stamp
	var valid_output_path: String = output_dir.path_join("valid_network_messages.gd")
	var valid_contract: GFNetworkContract = _make_contract(&"valid")
	var invalid_contract: GFNetworkContract = _make_contract(&"invalid")
	var invalid_message: GFNetworkContractMessage = invalid_contract.messages[0]
	var invalid_field: GFNetworkContractField = invalid_message.fields[0]
	invalid_field.required = false
	invalid_field.default_value = "wrong_type"
	assert_eq(ResourceSaver.save(valid_contract, valid_path), OK)
	assert_eq(ResourceSaver.save(invalid_contract, invalid_path), OK)
	var generator: GFNetworkContractGenerator = GF_NETWORK_CONTRACT_GENERATOR_SCRIPT.new()

	var report: Dictionary = generator.generate_many(
		PackedStringArray([valid_path, invalid_path]),
		output_dir,
		true,
		{ "scan_filesystem": false }
	)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "任一无效定义都必须阻止批次进入写阶段。")
	assert_false(_find_issue(report, "invalid_contract_definition").is_empty())
	assert_false(FileAccess.file_exists(valid_output_path), "批次预检失败时前面的合法契约也不得写入。")
	_remove_file_if_present(valid_path)
	_remove_file_if_present(invalid_path)
	_remove_file_if_present(valid_output_path)
	_remove_directory_if_present(output_dir)


func test_network_contract_generator_dry_run_and_commit_share_plan_fingerprint() -> void:
	var stamp: int = Time.get_ticks_usec()
	var contract_path: String = "user://gf_network_plan_fingerprint_%d.tres" % stamp
	var output_dir: String = "user://gf_network_plan_fingerprint_output_%d" % stamp
	var output_path: String = output_dir.path_join("stable_network_messages.gd")
	assert_eq(ResourceSaver.save(_make_contract(&"stable"), contract_path), OK)
	var generator: GFNetworkContractGenerator = GF_NETWORK_CONTRACT_GENERATOR_SCRIPT.new()

	var dry_run_report: Dictionary = generator.generate_many(
		PackedStringArray([contract_path]),
		output_dir,
		true,
		{
			"dry_run": true,
			"scan_filesystem": false,
		}
	)
	var commit_report: Dictionary = generator.generate_many(
		PackedStringArray([contract_path]),
		output_dir,
		true,
		{ "scan_filesystem": false }
	)

	assert_true(GFVariantData.get_option_bool(dry_run_report, "ok"))
	assert_true(GFVariantData.get_option_bool(commit_report, "ok"))
	assert_eq(
		GFVariantData.get_option_string(dry_run_report, "plan_fingerprint"),
		GFVariantData.get_option_string(commit_report, "plan_fingerprint"),
		"相同输入的 preview 与 commit 必须由同一个确定性计划驱动。"
	)
	assert_true(FileAccess.file_exists(output_path), "真实提交应写出计划中的唯一目标。")
	_remove_file_if_present(contract_path)
	_remove_file_if_present(output_path)
	_remove_directory_if_present(output_dir)


func test_network_contract_generator_enforces_configured_batch_budget_before_loading() -> void:
	var generator: GFNetworkContractGenerator = GF_NETWORK_CONTRACT_GENERATOR_SCRIPT.new()
	var output_dir: String = "user://gf_network_budget_%d" % Time.get_ticks_usec()

	var report: Dictionary = generator.generate_many(
		PackedStringArray(["user://one.tres", "user://two.tres"]),
		output_dir,
		true,
		{ "max_contracts": 1 }
	)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "超过调用方预算的批次必须在 load 前失败。")
	assert_false(_find_issue(report, "generation_budget_exceeded").is_empty())
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(output_dir)))


# --- 私有/辅助方法 ---

func _make_contract(contract_id: StringName) -> GFNetworkContract:
	var field: GFNetworkContractField = GFNetworkContractField.new()
	field.field_name = &"value"
	field.value_type = GFNetworkContractField.ValueType.INT
	var message_contract: GFNetworkContractMessage = GFNetworkContractMessage.new()
	message_contract.message_type = &"update"
	message_contract.fields = [field]
	var contract: GFNetworkContract = GFNetworkContract.new()
	contract.contract_id = contract_id
	contract.messages = [message_contract]
	return contract


func _find_issue(report: Dictionary, kind: String) -> Dictionary:
	for issue_value: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string(issue, "kind") == kind:
			return issue
	return {}


func _remove_file_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		var _remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _remove_directory_if_present(path: String) -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		var _remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _find_record(records: Array, identity_key: String, identity: String) -> Dictionary:
	for record_value: Variant in records:
		if not record_value is Dictionary:
			continue
		var record: Dictionary = record_value
		if GFVariantData.get_option_string(record, identity_key) == identity:
			return record
	return {}
