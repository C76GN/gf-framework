extends GutTest


# --- 常量 ---

const GF_NETWORK_EDITOR_ACTIONS_SCRIPT = preload("res://addons/gf/extensions/network/editor/gf_network_editor_actions.gd")
const GF_NETWORK_CONTRACT_GENERATOR_SCRIPT = preload("res://addons/gf/extensions/network/editor/gf_network_contract_generator.gd")
const GF_TRANSIENT_GDSCRIPT_TEST_SUPPORT = preload("res://tests/gf_core/support/gf_transient_gdscript_test_support.gd")
const CONTRACT_PATHS_SETTING: String = "gf/network/contract_paths"
const CONTRACT_OUTPUT_DIR_SETTING: String = "gf/network/contract_output_dir"


# --- 测试方法 ---

class CapturingActions extends GF_NETWORK_EDITOR_ACTIONS_SCRIPT:
	var diagnostic_text: String = ""

	func _show_diagnostic_dialog(_title: String, text: String) -> void:
		diagnostic_text = text


func test_network_audit_menu_preserves_resource_provenance() -> void:
	var paths: PackedStringArray = PackedStringArray()
	for index: int in 2:
		var path: String = (
			"user://gf_audit_origin_%d_%d.tres"
			% [Time.get_ticks_usec(), index]
		)
		var contract: GFNetworkContract = _make_contract(StringName("origin_%d" % index))
		contract.messages[0].fields[0].required = false
		contract.messages[0].fields[0].default_value = "bad integer"
		assert_eq(
			ResourceSaver.save(contract, path),
			OK
		)
		var _appended: bool = paths.append(path)
	var previous: Variant = ProjectSettings.get_setting(CONTRACT_PATHS_SETTING)
	ProjectSettings.set_setting(CONTRACT_PATHS_SETTING, paths)
	var actions: CapturingActions = CapturingActions.new()
	actions.handle_menu_action(&"audit_network_contracts")
	ProjectSettings.set_setting(CONTRACT_PATHS_SETTING, previous)
	for path: String in paths:
		assert_true(
			actions.diagnostic_text.contains(path),
			actions.diagnostic_text
		)
		_remove_file_if_present(path)
	actions.cleanup()


## 生成入口直接保留来源与非法字段，且单个契约的详细诊断数量有界。
func test_network_generation_reports_preserve_bounded_definition_details() -> void:
	var paths: PackedStringArray = PackedStringArray()
	for index: int in 2:
		var path: String = (
			"user://gf_generation_origin_%d_%d.tres"
			% [Time.get_ticks_usec(), index]
		)
		var contract: GFNetworkContract = _make_contract(&"same_id")
		contract.messages[0].fields.clear()
		for field_index: int in 20:
			var field: GFNetworkContractField = GFNetworkContractField.new()
			field.field_name = StringName(
				"invalid_%d_%d"
				% [index, field_index]
			)
			field.value_type = GFNetworkContractField.ValueType.INT
			field.required = false
			field.default_value = "bad integer"
			contract.messages[0].fields.append(field)
		assert_eq(
			ResourceSaver.save(contract, path),
			OK
		)
		var _appended: bool = paths.append(path)
	var generator: GFNetworkContractGenerator = GF_NETWORK_CONTRACT_GENERATOR_SCRIPT.new()
	var report: Dictionary = generator.generate_many(paths, "user://gf_generation_unused")
	var actions: CapturingActions = CapturingActions.new()
	assert_true(actions.has_method("_format_generation_report"))
	if actions.has_method("_format_generation_report"):
		var text: String = actions._format_generation_report(report, "user://gf_generation_unused")
		for index: int in paths.size():
			assert_true(text.contains(paths[index]))
			assert_true(text.contains("invalid_%d_0" % index))
	for path: String in paths:
		var loaded_contract: Resource = load(path)
		assert_true(loaded_contract is GFNetworkContract)
		if not loaded_contract is GFNetworkContract:
			_remove_file_if_present(path)
			continue
		var contract: GFNetworkContract = loaded_contract
		var single: Dictionary = generator.generate_with_report(contract)
		var details: Array = GFVariantData.get_option_array(single, "validation_issues")
		assert_eq(
			details.size(),
			16
		)
		assert_eq(
			GFVariantData.get_option_int(single, "validation_issue_count"),
			20
		)
		for detail: Dictionary in details:
			assert_eq(
				GFVariantData.get_option_string(detail, "resource_path"),
				path
			)
		_remove_file_if_present(path)
	actions.cleanup()


## 已提交但后置失败的产物必须与写入前失败区分，避免用户误以为文件未变化。
func test_network_generation_menu_displays_each_artifact_commit_fact() -> void:
	var actions: CapturingActions = CapturingActions.new()
	assert_true(actions.has_method("_format_generation_report"))
	if actions.has_method("_format_generation_report"):
		var text: String = actions._format_generation_report(
			{
				"generated": [
					{
						"contract_path": "res://a.tres",
						"output_path": "res://a.gd",
						"status": "failed",
						"written": true,
						"changed": true,
						"error_name": "File corrupt",
					},
					{
						"contract_path": "res://b.tres",
						"output_path": "res://b.gd",
						"status": "failed",
						"written": false,
						"changed": false,
						"error_name": "File corrupt",
					},
				],
				"next_action": "Review generated files.",
			},
			"res://"
		)
		assert_true(text.contains("res://a.gd (failed, File corrupt, written=true, changed=true)"))
		assert_true(text.contains("res://b.gd (failed, File corrupt, written=false, changed=false)"))
		assert_true(text.contains("Review generated files."))
	actions.cleanup()


func test_network_editor_actions_contribute_menu_entries_settings_and_sections() -> void:
	var actions: RefCounted = GF_NETWORK_EDITOR_ACTIONS_SCRIPT.new()

	var entries: Array = GFVariantData.as_array(actions.call("get_menu_entries"))
	var setting_records: Array = GFVariantData.as_array(actions.call("get_project_setting_records"))
	var section_records: Array = GFVariantData.as_array(actions.call("get_project_setting_section_records"))
	actions.call("cleanup")

	assert_eq(
		entries.size(),
		2,
		"Network editor tool 应贡献生成与审计两个菜单动作。"
	)
	var entry_ids: Array[StringName] = []
	for entry_value: Variant in entries:
		assert_true(
			entry_value is Dictionary,
			"菜单动作应返回 Dictionary。"
		)
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		entry_ids.append(GFVariantData.get_option_string_name(entry, "id"))
	assert_eq(
		entry_ids,
		[&"generate_network_contracts", &"audit_network_contracts"]
	)
	assert_eq(
		setting_records.size(),
		2,
		"Network editor tool 应显式贡献两个项目设置。"
	)
	assert_eq(
		GFVariantData.get_option_string(
			_find_record(
				setting_records,
				"name",
				CONTRACT_PATHS_SETTING
			),
			"name"
		),
		CONTRACT_PATHS_SETTING
	)
	assert_eq(
		GFVariantData.get_option_string(
			_find_record(
				setting_records,
				"name",
				CONTRACT_OUTPUT_DIR_SETTING
			),
			"default_value"
		),
		"res://generated/network"
	)
	assert_eq(
		section_records.size(),
		1,
		"Network editor tool 应贡献独立项目设置分区展示。"
	)
	assert_eq(
		GFVariantData.get_option_string(
			_find_record(
				section_records,
				"path",
				"gf/network"
			),
			"path"
		),
		"gf/network"
	)


func test_network_contract_generator_allocates_complete_symbol_scopes() -> void:
	var contract: GFNetworkContract = GFNetworkContract.new()
	contract.contract_id = &"symbols"
	for entry: Array in [
		[
			"update",
			"payload",
			"message",
			"channel_id",
		],
		["a", "b_c"],
		["a_b", "c"],
		["contract", "version"],
	]:
		var message_contract: GFNetworkContractMessage = GFNetworkContractMessage.new()
		message_contract.message_type = StringName(GFVariantData.to_text(entry[0]))
		for index: int in range(
			1,
			entry.size()
		):
			var field: GFNetworkContractField = GFNetworkContractField.new()
			field.field_name = StringName(GFVariantData.to_text(entry[index]))
			field.value_type = GFNetworkContractField.ValueType.INT
			message_contract.fields.append(field)
		contract.messages.append(message_contract)
	assert_true(
		GFVariantData.get_option_bool(
			contract.validate_contract(),
			"ok"
		)
	)
	var generator: GFNetworkContractGenerator = GF_NETWORK_CONTRACT_GENERATOR_SCRIPT.new()
	var source: String = (
		generator.build_source(
			contract,
			{ "class_name": "ScopeCollisionFixture" }
		).replace("class_name ScopeCollisionFixture\n", "")
	)
	var runtime_script: GDScript = GDScript.new()
	runtime_script.source_code = source
	var compile_error: Error = runtime_script.reload(false)
	assert_eq(compile_error, OK)
	if compile_error == OK:
		var message_value: Variant = runtime_script.call(
			"make_update",
			7,
			8,
			9
		)
		assert_true(message_value is GFNetworkMessage)
		if message_value is GFNetworkMessage:
			var message: GFNetworkMessage = message_value
			var payload_matches: bool = message.payload[&"payload"] == 7
			var message_field_matches: bool = message.payload[&"message"] == 8
			var channel_id_matches: bool = message.payload[&"channel_id"] == 9
			assert_true(payload_matches)
			assert_true(message_field_matches)
			assert_true(channel_id_matches)
	var _release_errors: Array[int] = GF_TRANSIENT_GDSCRIPT_TEST_SUPPORT.release(runtime_script)


func test_network_nullable_getters_accept_null_fallback_with_typed_payloads() -> void:
	var contract: GFNetworkContract = GFNetworkContract.new()
	contract.contract_id = &"nullable_values"
	var message_contract: GFNetworkContractMessage = GFNetworkContractMessage.new()
	message_contract.message_type = &"update"
	var cases: Array[Array] = [
		[GFNetworkContractField.ValueType.COLOR, Color.RED],
		[GFNetworkContractField.ValueType.VECTOR2I, Vector2i(2, 3)],
		[
			GFNetworkContractField.ValueType.VECTOR3I,
			Vector3i(
				2,
				3,
				4
			),
		],
		[GFNetworkContractField.ValueType.VECTOR2, Vector2(2.0, 3.0)],
		[
			GFNetworkContractField.ValueType.VECTOR3,
			Vector3(
				2.0,
				3.0,
				4.0
			),
		],
		[GFNetworkContractField.ValueType.NODE_PATH, NodePath("Target")],
	]
	for index: int in range(cases.size()):
		var field: GFNetworkContractField = GFNetworkContractField.new()
		field.field_name = StringName("field_%d" % index)
		var field_type_value: Variant = cases[index][0]
		assert_true(field_type_value is int)
		if not field_type_value is int:
			return
		var field_type: int = field_type_value
		field.value_type = field_type as GFNetworkContractField.ValueType
		field.allow_null = true
		message_contract.fields.append(field)
	contract.messages.append(message_contract)
	var generator: GFNetworkContractGenerator = GF_NETWORK_CONTRACT_GENERATOR_SCRIPT.new()
	var runtime_script: GDScript = GDScript.new()
	runtime_script.source_code = generator.build_source(
		contract,
		{ "class_name": "NullableGetterFixture" }
	).replace("class_name NullableGetterFixture\n", "")
	var compile_error: Error = runtime_script.reload(false)
	assert_eq(compile_error, OK)
	if compile_error == OK:
		var message: GFNetworkMessage = GFNetworkMessage.new()
		for index: int in range(cases.size()):
			var field_name: StringName = StringName("field_%d" % index)
			var getter_name: String = "get_update_field_%d" % index
			message.payload[field_name] = cases[index][1]
			var value: Variant = runtime_script.call(
				getter_name,
				message,
				null
			)
			var payload_matches: bool = value == cases[index][1]
			assert_true(payload_matches)
			assert_eq(
				typeof(value),
				typeof(cases[index][1])
			)
			message.payload[field_name] = null
			var explicit_null_returned: bool = runtime_script.call(getter_name, message) == null
			assert_true(explicit_null_returned)
			var _erased: bool = message.payload.erase(field_name)
			var missing_returns_null: bool = (
				runtime_script.call(
					getter_name,
					message,
					null
				)
				== null
			)
			assert_true(missing_returns_null)
	var _release_errors: Array[int] = GF_TRANSIENT_GDSCRIPT_TEST_SUPPORT.release(runtime_script)


## FLOAT 契约允许整数载荷；null 回退不能将合法数字变为空值，也不能放宽 INT 的类型范围。
func test_network_nullable_numeric_getters_preserve_contract_types_with_null_fallback() -> void:
	var contract: GFNetworkContract = GFNetworkContract.new()
	contract.contract_id = &"nullable_numbers"
	var message_contract: GFNetworkContractMessage = GFNetworkContractMessage.new()
	message_contract.message_type = &"update"
	var amount_field: GFNetworkContractField = GFNetworkContractField.new()
	amount_field.field_name = &"amount"
	amount_field.value_type = GFNetworkContractField.ValueType.FLOAT
	amount_field.allow_null = true
	var count_field: GFNetworkContractField = GFNetworkContractField.new()
	count_field.field_name = &"count"
	count_field.value_type = GFNetworkContractField.ValueType.INT
	count_field.allow_null = true
	message_contract.fields = [amount_field, count_field]
	contract.messages = [message_contract]
	assert_true(
		GFVariantData.get_option_bool(
			amount_field.validate_value(1),
			"ok"
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			count_field.validate_value(1.5),
			"ok"
		)
	)
	var generator: GFNetworkContractGenerator = GF_NETWORK_CONTRACT_GENERATOR_SCRIPT.new()
	var runtime_script: GDScript = GDScript.new()
	runtime_script.source_code = generator.build_source(
		contract,
		{ "class_name": "NullableNumericGetterFixture" }
	).replace("class_name NullableNumericGetterFixture\n", "")
	var compile_error: Error = runtime_script.reload(false)
	assert_eq(compile_error, OK)
	if compile_error == OK:
		var cases: Array[Dictionary] = [
			{
				"field": &"amount",
				"payload": 1,
				"expected": 1.0,
			},
			{
				"field": &"amount",
				"payload": 1.5,
				"expected": 1.5,
			},
			{
				"field": &"count",
				"payload": 1,
				"expected": 1,
			},
			{
				"field": &"count",
				"payload": 1.5,
				"expected": null,
			},
		]
		var message: GFNetworkMessage = GFNetworkMessage.new()
		for test_case: Dictionary in cases:
			var field_name: StringName = GFVariantData.get_option_string_name(test_case, "field")
			message.payload[field_name] = test_case["payload"]
			var actual: Variant = runtime_script.call(
				"get_update_%s" % field_name,
				message,
				null
			)
			var expected: Variant = test_case["expected"]
			var numeric_value_matches: bool = actual == expected
			assert_true(numeric_value_matches)
			assert_eq(
				typeof(actual),
				typeof(expected)
			)
		for field_name: StringName in [&"amount", &"count"]:
			var getter_name: String = "get_update_%s" % field_name
			for invalid_or_null: Variant in [
				null,
				"1",
				true,
				Vector2.ONE,
			]:
				message.payload[field_name] = invalid_or_null
				var invalid_returns_null: bool = (
					runtime_script.call(
						getter_name,
						message,
						null
					)
					== null
				)
				assert_true(invalid_returns_null)
			var _erased: bool = message.payload.erase(field_name)
			var missing_returns_null: bool = (
				runtime_script.call(
					getter_name,
					message,
					null
				)
				== null
			)
			assert_true(missing_returns_null)
		message.payload[&"amount"] = 1
		var numeric_with_fallback: Variant = runtime_script.call(
			"get_update_amount",
			message,
			2.5
		)
		assert_true(numeric_with_fallback is float)
		if numeric_with_fallback is float:
			var numeric_value: float = numeric_with_fallback
			assert_eq(numeric_value, 1.0)
	var _release_errors: Array[int] = GF_TRANSIENT_GDSCRIPT_TEST_SUPPORT.release(runtime_script)


func test_network_contract_generator_script_exposes_generation_api() -> void:
	var generator: RefCounted = GF_NETWORK_CONTRACT_GENERATOR_SCRIPT.new()

	assert_eq(GF_NETWORK_CONTRACT_GENERATOR_SCRIPT.DEFAULT_OUTPUT_DIR, "res://generated/network")
	assert_true(
		generator.has_method("generate_with_report"),
		"Network tool module 应包含生成器报告入口。"
	)
	assert_true(
		generator.has_method("generate_many"),
		"Network tool module 应包含批量生成入口。"
	)


func test_network_contract_generator_rejects_batch_output_collisions_before_writing() -> void:
	var stamp: int = Time.get_ticks_usec()
	var first_contract_path: String = "user://gf_network_collision_first_%d.tres" % stamp
	var second_contract_path: String = "user://gf_network_collision_second_%d.tres" % stamp
	var output_dir: String = "user://gf_network_collision_output_%d" % stamp
	var output_path: String = output_dir.path_join("foo_bar_network_messages.gd")
	var first_contract: GFNetworkContract = _make_contract(&"foo-bar")
	var second_contract: GFNetworkContract = _make_contract(&"foo_bar")
	assert_eq(
		ResourceSaver.save(first_contract, first_contract_path),
		OK
	)
	assert_eq(
		ResourceSaver.save(second_contract, second_contract_path),
		OK
	)
	var generator: GFNetworkContractGenerator = GF_NETWORK_CONTRACT_GENERATOR_SCRIPT.new()

	var report: Dictionary = generator.generate_many(
		PackedStringArray([first_contract_path, second_contract_path]),
		output_dir,
		true,
		{ "scan_filesystem": false }
	)

	assert_false(
		GFVariantData.get_option_bool(report, "ok"),
		"批次输出碰撞必须使整个预检失败。"
	)
	assert_eq(
		GFVariantData.get_option_string(
			_find_issue(report, "duplicate_output_path"),
			"kind"
		),
		"duplicate_output_path",
		"碰撞应提供稳定 issue kind。"
	)
	assert_false(
		FileAccess.file_exists(output_path),
		"碰撞批次必须保持零写入。"
	)
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
	assert_eq(
		ResourceSaver.save(valid_contract, valid_path),
		OK
	)
	assert_eq(
		ResourceSaver.save(invalid_contract, invalid_path),
		OK
	)
	var generator: GFNetworkContractGenerator = GF_NETWORK_CONTRACT_GENERATOR_SCRIPT.new()

	var report: Dictionary = generator.generate_many(
		PackedStringArray([valid_path, invalid_path]),
		output_dir,
		true,
		{ "scan_filesystem": false }
	)

	assert_false(
		GFVariantData.get_option_bool(report, "ok"),
		"任一无效定义都必须阻止批次进入写阶段。"
	)
	assert_false(_find_issue(report, "invalid_contract_definition").is_empty())
	assert_false(
		FileAccess.file_exists(valid_output_path),
		"批次预检失败时前面的合法契约也不得写入。"
	)
	_remove_file_if_present(valid_path)
	_remove_file_if_present(invalid_path)
	_remove_file_if_present(valid_output_path)
	_remove_directory_if_present(output_dir)


func test_network_contract_generator_dry_run_and_commit_share_plan_fingerprint() -> void:
	var stamp: int = Time.get_ticks_usec()
	var contract_path: String = "user://gf_network_plan_fingerprint_%d.tres" % stamp
	var output_dir: String = "user://gf_network_plan_fingerprint_output_%d" % stamp
	var output_path: String = output_dir.path_join("stable_network_messages.gd")
	assert_eq(
		ResourceSaver.save(
			_make_contract(&"stable"),
			contract_path
		),
		OK
	)
	var generator: GFNetworkContractGenerator = GF_NETWORK_CONTRACT_GENERATOR_SCRIPT.new()

	var dry_run_report: Dictionary = generator.generate_many(
		PackedStringArray([contract_path]),
		output_dir,
		true,
		{ "dry_run": true, "scan_filesystem": false, }
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
	assert_true(
		FileAccess.file_exists(output_path),
		"真实提交应写出计划中的唯一目标。"
	)
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

	assert_false(
		GFVariantData.get_option_bool(report, "ok"),
		"超过调用方预算的批次必须在 load 前失败。"
	)
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


func _find_record(
	records: Array,
	identity_key: String,
	identity: String
) -> Dictionary:
	for record_value: Variant in records:
		if not record_value is Dictionary:
			continue
		var record: Dictionary = record_value
		if GFVariantData.get_option_string(record, identity_key) == identity:
			return record
	return {}
