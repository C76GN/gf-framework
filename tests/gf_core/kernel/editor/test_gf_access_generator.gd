extends GutTest


# --- 常量 ---

const GF_CAPABILITY_ACCESS_GENERATOR_EXTENSION_BASE = preload("res://addons/gf/extensions/capability/editor/gf_capability_access_generator_extension.gd")
const GF_CAPABILITY_BASE = preload("res://addons/gf/extensions/capability/core/gf_capability.gd")
const GF_NODE_CAPABILITY_BASE = preload("res://addons/gf/extensions/capability/nodes/gf_node_capability.gd")
const GF_NODE_2D_CAPABILITY_BASE = preload("res://addons/gf/extensions/capability/nodes/gf_node_2d_capability.gd")
const GF_NODE_3D_CAPABILITY_BASE = preload("res://addons/gf/extensions/capability/nodes/gf_node_3d_capability.gd")
const GF_CONTROL_CAPABILITY_BASE = preload("res://addons/gf/extensions/capability/nodes/gf_control_capability.gd")
const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const GF_PROJECT_ARTIFACT_PATHS = preload("res://addons/gf/kernel/core/gf_project_artifact_paths.gd")


# --- 测试用例 ---

func test_project_artifact_policy_drives_codegen_defaults_and_matches_json_mirror() -> void:
	assert_eq(GF_PROJECT_ARTIFACT_PATHS.GENERATED_ROOT, "res://generated")
	assert_eq(GFAccessGenerator.DEFAULT_OUTPUT_PATH, GF_PROJECT_ARTIFACT_PATHS.ACCESS_OUTPUT_PATH)
	assert_eq(GFAccessGenerator.DEFAULT_PROJECT_OUTPUT_PATH, GF_PROJECT_ARTIFACT_PATHS.PROJECT_ACCESS_OUTPUT_PATH)
	assert_true(GF_PROJECT_ARTIFACT_PATHS.validate_policy_file().is_empty(), "跨运行时路径策略镜像必须与 kernel 常量一致。")


func test_build_source_generates_typed_accessors() -> void:
	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var source: String = generator.build_source([
		{
			"class_name": "PlayerModel",
			"path": "res://player_model.gd",
			"kind": GFAccessGenerator.TargetKind.MODEL,
		},
		{
			"class_name": "BattleSystem",
			"path": "res://battle_system.gd",
			"kind": GFAccessGenerator.TargetKind.SYSTEM,
		},
		{
			"class_name": "StorageUtility",
			"path": "res://storage_utility.gd",
			"kind": GFAccessGenerator.TargetKind.UTILITY,
		},
		{
			"class_name": "GFUIUtility",
			"path": "res://gf_ui_utility.gd",
			"kind": GFAccessGenerator.TargetKind.UTILITY,
		},
		{
			"class_name": "DealDamageCommand",
			"path": "res://deal_damage_command.gd",
			"kind": GFAccessGenerator.TargetKind.COMMAND,
		},
		{
			"class_name": "HealthCapability",
			"path": "res://health_capability.gd",
			"kind": GFAccessGenerator.TargetKind.CAPABILITY,
			"utility_path": "res://addons/gf/extensions/capability/core/gf_capability_utility.gd",
		},
	])
	var unsafe_cast_snippet: String = "return resolved_architecture.get_system(BattleSystem) " + "as BattleSystem"

	assert_true(source.contains("static func get_player_model(architecture: GFArchitecture = null) -> PlayerModel:"), "应生成 Model 强类型访问器。")
	assert_true(source.contains("var system_value: Variant = resolved_architecture.resolve_module_access("), "应通过共享解析入口查询 System。")
	assert_true(source.contains("GFArchitecture.ModuleKind.SYSTEM,"), "System 访问器应冻结模块类型。")
	assert_true(source.contains("GFArchitecture.ModuleLookupScope.INHERITED,"), "默认访问器应冻结 inherited 作用域。")
	assert_true(source.contains("if system_value is BattleSystem:"), "System 查询应先收窄再返回。")
	assert_false(source.contains(unsafe_cast_snippet), "生成访问器不应传播 unsafe cast。")
	assert_true(source.contains("static func get_storage_utility(architecture: GFArchitecture = null) -> StorageUtility:"), "应生成 Utility 强类型访问器。")
	assert_true(source.contains("static func get_gf_ui_utility(architecture: GFArchitecture = null) -> GFUIUtility:"), "GF 前缀加缩写类名应生成可读函数名。")
	assert_true(source.contains("static func create_deal_damage_command(architecture: GFArchitecture = null) -> DealDamageCommand:"), "应生成 Command 创建入口。")
	assert_true(source.contains("static func get_health_capability(receiver: Object, architecture: GFArchitecture = null) -> HealthCapability:"), "应生成能力查询入口。")
	assert_true(source.contains("static func add_health_capability(receiver: Object, architecture: GFArchitecture = null) -> HealthCapability:"), "应生成能力添加入口。")
	assert_true(source.contains("static func if_has_health_capability(receiver: Object, callback: Callable, architecture: GFArchitecture = null) -> Variant:"), "应生成能力条件回调入口。")
	assert_true(source.contains("_CAPABILITY_UTILITY_SCRIPT_PATH"), "包含能力记录时才应生成能力扩展运行时入口。")
	assert_true(source.contains("instance.call(\"_gf_set_dependency_scope\", architecture)"), "fallback new() 的对象应先绑定内部依赖作用域。")


func test_project_access_policy_is_frozen_into_generated_accessor() -> void:
	var setting_name: String = GFAccessGenerator.ACCESS_POLICIES_SETTING
	var had_setting: bool = ProjectSettings.has_setting(setting_name)
	var previous_value: Variant = ProjectSettings.get_setting(setting_name, null)
	ProjectSettings.set_setting(setting_name, {
		"res://addons/gf/standard/utilities/time/gf_time_utility.gd": {
			"scope": "local",
			"required": false,
			"require_ready": true,
		},
	})

	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var records: Array[Dictionary] = [
		{
			"class_name": "GFTimeUtility",
			"path": "res://addons/gf/standard/utilities/time/gf_time_utility.gd",
			"kind": GFAccessGenerator.TargetKind.UTILITY,
		},
	]
	var policy_result: Dictionary = generator._apply_access_policies(records)
	var frozen_records: Array = GF_VARIANT_ACCESS.get_option_array(policy_result, "records")
	var source: String = generator.build_source(frozen_records)
	var accessor_source: String = _get_generated_function_source(
		source,
		"static func get_gf_time_utility("
	)

	if had_setting:
		ProjectSettings.set_setting(setting_name, previous_value)
	else:
		ProjectSettings.clear(setting_name)

	assert_false(accessor_source.is_empty(), "GFTimeUtility 应有生成访问器。")
	assert_true(
		accessor_source.contains("GFArchitecture.ModuleKind.UTILITY,"),
		"应冻结 Utility 模块类型。"
	)
	assert_true(
		accessor_source.contains("GFArchitecture.ModuleLookupScope.LOCAL,"),
		"应冻结 local 作用域。"
	)
	assert_true(
		accessor_source.contains("\n\t\tfalse,\n\t\ttrue\n\t)"),
		"应按顺序冻结 required=false 与 require_ready=true。"
	)
	assert_false(
		accessor_source.contains("ProjectSettings"),
		"运行时访问器不应重新读取生成期策略。"
	)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(policy_result, "valid"), "合法策略应整体冻结成功。")
	assert_false(records[0].has("scope"), "策略冻结不得修改调用方或扩展持有的原始记录。")


func test_frozen_access_policy_source_parses_as_gdscript() -> void:
	var setting_name: String = GFAccessGenerator.ACCESS_POLICIES_SETTING
	var script_path: String = "res://addons/gf/standard/utilities/time/gf_time_utility.gd"
	var had_setting: bool = ProjectSettings.has_setting(setting_name)
	var previous_value: Variant = ProjectSettings.get_setting(setting_name, null)
	var local_policies: Dictionary = {}
	local_policies[StringName(script_path)] = {
		"scope": "local",
		"required": false,
		"require_ready": true,
	}
	ProjectSettings.set_setting(setting_name, local_policies)
	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var result: Dictionary = generator._apply_access_policies([{
		"class_name": "GFTimeUtility",
		"path": script_path,
		"kind": GFAccessGenerator.TargetKind.UTILITY,
	}])
	if had_setting:
		ProjectSettings.set_setting(setting_name, previous_value)
	else:
		ProjectSettings.clear(setting_name)
	var source: String = generator.build_source(
		GF_VARIANT_ACCESS.get_option_array(result, "records")
	)
	var generated_script: GDScript = GDScript.new()
	generated_script.source_code = source

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "valid"))
	assert_eq(generated_script.reload(), OK, "冻结策略生成物必须通过真实 GDScript 解析。")


func test_string_name_access_policy_fields_are_canonicalized_before_freezing() -> void:
	var setting_name: String = GFAccessGenerator.ACCESS_POLICIES_SETTING
	var script_path: String = "res://addons/gf/standard/utilities/time/gf_time_utility.gd"
	var had_setting: bool = ProjectSettings.has_setting(setting_name)
	var previous_value: Variant = ProjectSettings.get_setting(setting_name, null)
	var configured_policy: Dictionary = {}
	configured_policy[StringName("scope")] = StringName("local")
	configured_policy[StringName("required")] = false
	configured_policy[StringName("require_ready")] = true
	var configured_policies: Dictionary = {}
	configured_policies[StringName(script_path)] = configured_policy
	ProjectSettings.set_setting(setting_name, configured_policies)

	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var records: Array[Dictionary] = [{
		"class_name": "GFTimeUtility",
		"path": script_path,
		"kind": GFAccessGenerator.TargetKind.UTILITY,
	}]
	var result: Dictionary = generator._apply_access_policies(records)
	if had_setting:
		ProjectSettings.set_setting(setting_name, previous_value)
	else:
		ProjectSettings.clear(setting_name)

	var frozen_records: Array = GF_VARIANT_ACCESS.get_option_array(result, "records")
	var frozen_record: Dictionary = GF_VARIANT_ACCESS.as_dictionary(frozen_records[0])
	var string_name_policy_key_count: int = 0
	for raw_key: Variant in frozen_record:
		if raw_key is StringName:
			var policy_key_name: StringName = raw_key
			if ["scope", "required", "require_ready"].has(String(policy_key_name)):
				string_name_policy_key_count += 1

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "valid"))
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(frozen_record, "scope"),
		GFAccessGenerator.ACCESS_SCOPE_LOCAL
	)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(frozen_record, "required", true))
	assert_true(GF_VARIANT_ACCESS.get_option_bool(frozen_record, "require_ready"))
	assert_eq(string_name_policy_key_count, 0, "冻结记录只应保留 canonical String 策略键。")
	assert_false(records[0].has("scope"), "字段键规范化不得修改调用方记录。")


func test_string_and_string_name_policy_aliases_freeze_one_canonical_value() -> void:
	var setting_name: String = GFAccessGenerator.ACCESS_POLICIES_SETTING
	var script_path: String = "res://addons/gf/standard/utilities/time/gf_time_utility.gd"
	var had_setting: bool = ProjectSettings.has_setting(setting_name)
	var previous_value: Variant = ProjectSettings.get_setting(setting_name, null)
	var aliased_policy: Dictionary = {
		"scope": "local",
	}
	aliased_policy[StringName("scope")] = "inherited"
	ProjectSettings.set_setting(setting_name, {
		script_path: aliased_policy,
	})

	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var result: Dictionary = generator._apply_access_policies([{
		"class_name": "GFTimeUtility",
		"path": script_path,
		"kind": GFAccessGenerator.TargetKind.UTILITY,
	}])
	if had_setting:
		ProjectSettings.set_setting(setting_name, previous_value)
	else:
		ProjectSettings.clear(setting_name)

	var frozen_records: Array = GF_VARIANT_ACCESS.get_option_array(result, "records")
	var frozen_record: Dictionary = GF_VARIANT_ACCESS.as_dictionary(frozen_records[0])
	assert_eq(aliased_policy.size(), 1, "Godot Dictionary 会在验证前折叠等价字符串键。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "valid"))
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(frozen_record, "scope"),
		GFAccessGenerator.ACCESS_SCOPE_INHERITED,
		"折叠后的最终值应冻结到 canonical String 字段。"
	)


func test_string_name_access_policy_field_with_wrong_type_fails_closed() -> void:
	var setting_name: String = GFAccessGenerator.ACCESS_POLICIES_SETTING
	var script_path: String = "res://addons/gf/standard/utilities/time/gf_time_utility.gd"
	var had_setting: bool = ProjectSettings.has_setting(setting_name)
	var previous_value: Variant = ProjectSettings.get_setting(setting_name, null)
	var invalid_policy: Dictionary = {}
	invalid_policy[StringName("required")] = 1
	ProjectSettings.set_setting(setting_name, {
		script_path: invalid_policy,
	})

	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var result: Dictionary = generator._apply_access_policies([{
		"class_name": "GFTimeUtility",
		"path": script_path,
		"kind": GFAccessGenerator.TargetKind.UTILITY,
	}])
	if had_setting:
		ProjectSettings.set_setting(setting_name, previous_value)
	else:
		ProjectSettings.clear(setting_name)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "valid"))
	assert_true(GF_VARIANT_ACCESS.get_option_array(result, "records").is_empty())
	assert_push_error("[GFAccessGenerator] access policy 值无效：%s" % script_path)


func test_invalid_access_policy_fails_closed_without_generating_accessor() -> void:
	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var source: String = generator.build_source([
		{
			"class_name": "ValidPolicyModel",
			"path": "res://valid_policy_model.gd",
			"kind": GFAccessGenerator.TargetKind.MODEL,
		},
		{
			"class_name": "InvalidPolicyUtility",
			"path": "res://invalid_policy_utility.gd",
			"kind": GFAccessGenerator.TargetKind.UTILITY,
			"scope": "nearest",
			"required": false,
			"require_ready": true,
		},
	])

	assert_true(source.is_empty(), "任一 policy 非法时不得生成同批合法记录或扩展源码。")
	assert_push_error(
		"[GFAccessGenerator] access policy 无效，整批生成已中止：InvalidPolicyUtility"
	)


func test_unknown_configured_access_policy_field_fails_closed() -> void:
	var setting_name: String = GFAccessGenerator.ACCESS_POLICIES_SETTING
	var script_path: String = "res://addons/gf/standard/utilities/time/gf_time_utility.gd"
	var had_setting: bool = ProjectSettings.has_setting(setting_name)
	var previous_value: Variant = ProjectSettings.get_setting(setting_name, null)
	ProjectSettings.set_setting(setting_name, {
		script_path: {
			"scope": "local",
			"requires": false,
		},
	})

	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var records: Array[Dictionary] = [
		{
			"class_name": "GFTimeUtility",
			"path": script_path,
			"kind": GFAccessGenerator.TargetKind.UTILITY,
		},
	]
	var policy_result: Dictionary = generator._apply_access_policies(records)
	var frozen_records: Array = GF_VARIANT_ACCESS.get_option_array(policy_result, "records")
	var source: String = generator.build_source(frozen_records)

	if had_setting:
		ProjectSettings.set_setting(setting_name, previous_value)
	else:
		ProjectSettings.clear(setting_name)

	assert_false(
		source.contains("static func get_gf_time_utility("),
		"未知字段不应回退默认策略生成访问器。"
	)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(policy_result, "valid"), "未知字段应使整批策略失败。")
	assert_true(frozen_records.is_empty(), "失败批次不得暴露部分冻结记录。")
	assert_push_error(
		"[GFAccessGenerator] access policy 包含未知字段：%s" % script_path
	)


func test_access_policy_freezing_is_transactional_across_reuse() -> void:
	var setting_name: String = GFAccessGenerator.ACCESS_POLICIES_SETTING
	var script_path: String = "res://addons/gf/standard/utilities/time/gf_time_utility.gd"
	var had_setting: bool = ProjectSettings.has_setting(setting_name)
	var previous_value: Variant = ProjectSettings.get_setting(setting_name, null)
	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var records: Array[Dictionary] = [{
		"class_name": "GFTimeUtility",
		"path": script_path,
		"kind": GFAccessGenerator.TargetKind.UTILITY,
	}]
	ProjectSettings.set_setting(setting_name, {
		script_path: {
			"scope": "local",
			"required": false,
			"require_ready": true,
		},
	})
	var local_result: Dictionary = generator._apply_access_policies(records)
	ProjectSettings.set_setting(setting_name, {})
	var default_result: Dictionary = generator._apply_access_policies(records)
	if had_setting:
		ProjectSettings.set_setting(setting_name, previous_value)
	else:
		ProjectSettings.clear(setting_name)

	var local_records: Array = GF_VARIANT_ACCESS.get_option_array(local_result, "records")
	var default_records: Array = GF_VARIANT_ACCESS.get_option_array(default_result, "records")
	var local_record: Dictionary = GF_VARIANT_ACCESS.as_dictionary(local_records[0])
	var default_record: Dictionary = GF_VARIANT_ACCESS.as_dictionary(default_records[0])
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(local_record, "scope"), GFAccessGenerator.ACCESS_SCOPE_LOCAL)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(local_record, "required", true))
	assert_true(GF_VARIANT_ACCESS.get_option_bool(local_record, "require_ready"))
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(default_record, "scope"), GFAccessGenerator.ACCESS_SCOPE_INHERITED)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(default_record, "required"))
	assert_false(GF_VARIANT_ACCESS.get_option_bool(default_record, "require_ready"))
	assert_false(records[0].has("scope"), "重复冻结不得把上次策略残留到原始记录。")


func test_stale_access_policy_path_fails_closed() -> void:
	var setting_name: String = GFAccessGenerator.ACCESS_POLICIES_SETTING
	var had_setting: bool = ProjectSettings.has_setting(setting_name)
	var previous_value: Variant = ProjectSettings.get_setting(setting_name, null)
	var stale_path: String = "res://moved/old_time_utility.gd"
	ProjectSettings.set_setting(setting_name, {
		stale_path: { "scope": "local" },
	})
	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var result: Dictionary = generator._apply_access_policies([{
		"class_name": "GFTimeUtility",
		"path": "res://addons/gf/standard/utilities/time/gf_time_utility.gd",
		"kind": GFAccessGenerator.TargetKind.UTILITY,
	}])
	if had_setting:
		ProjectSettings.set_setting(setting_name, previous_value)
	else:
		ProjectSettings.clear(setting_name)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "valid"), "移动后遗留路径必须阻断生成。")
	assert_true(GF_VARIANT_ACCESS.get_option_array(result, "records").is_empty())
	assert_push_error("[GFAccessGenerator] access policy 路径未匹配可生成模块：%s" % stale_path)


func test_invalid_access_policy_root_does_not_overwrite_generated_artifact() -> void:
	var setting_name: String = GFAccessGenerator.ACCESS_POLICIES_SETTING
	var had_setting: bool = ProjectSettings.has_setting(setting_name)
	var previous_value: Variant = ProjectSettings.get_setting(setting_name, null)
	var path: String = "user://gf_access_generator_invalid_policy_%d.gd" % Time.get_ticks_usec()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	var _stored: bool = file.store_string("sentinel")
	file.close()
	ProjectSettings.set_setting(setting_name, "invalid")

	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var report: Dictionary = generator.generate_with_report(path, {
		"written": true,
		"changed": true,
		"size_bytes": 1024,
		"content_sha256": "spoofed-content",
		"previous_sha256": "spoofed-previous",
		"dry_run": true,
		"artifact_owner": GFGeneratedArtifactReport.OWNER_EXTERNAL,
		"source_id": "access-policy-test",
		"metadata": {
			"case": "invalid-policy",
		},
	})
	if had_setting:
		ProjectSettings.set_setting(setting_name, previous_value)
	else:
		ProjectSettings.clear(setting_name)
	var read_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(read_file)
	var content: String = read_file.get_as_text() if read_file != null else ""
	if read_file != null:
		read_file.close()
	var _removed: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "success"))
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(report, "status"), GFGeneratedArtifactReport.STATUS_FAILED)
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "error_code"), ERR_INVALID_DATA)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "written"), "失败报告不得接受伪造写入状态。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "changed"), "验证失败尚未形成可比较产物。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "size_bytes", -1), 0)
	assert_eq(GF_VARIANT_ACCESS.get_option_string(report, "content_sha256"), "")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(report, "previous_sha256"), "")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "dry_run"))
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(report, "artifact_owner"),
		GFGeneratedArtifactReport.OWNER_EXTERNAL
	)
	assert_eq(GF_VARIANT_ACCESS.get_option_string(report, "generator_id"), "GFAccessGenerator")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(report, "source_id"), "access-policy-test")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string(
			GF_VARIANT_ACCESS.get_option_dictionary(report, "metadata"),
			"case"
		),
		"invalid-policy"
	)
	assert_eq(content, "sentinel", "策略根非法时不得覆盖既有生成物。")
	assert_push_error("[GFAccessGenerator] gf/codegen/access_policies 必须是 Dictionary。")


func test_build_source_omits_capability_helper_without_capability_records() -> void:
	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var source: String = generator.build_source([
		{
			"class_name": "PlayerModel",
			"path": "res://player_model.gd",
			"kind": GFAccessGenerator.TargetKind.MODEL,
		},
	])

	assert_false(source.contains("_CAPABILITY_UTILITY_SCRIPT_PATH"), "没有能力记录时不应生成能力扩展路径常量。")
	assert_false(source.contains("res://addons/gf/extensions/capability"), "没有能力记录时生成脚本不应直接引用能力扩展路径。")


func test_build_source_skips_duplicate_function_names() -> void:
	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var source: String = generator.build_source([
		{
			"class_name": "PlayerModel",
			"path": "res://a.gd",
			"kind": GFAccessGenerator.TargetKind.MODEL,
		},
		{
			"class_name": "Player",
			"path": "res://b.gd",
			"kind": GFAccessGenerator.TargetKind.MODEL,
		},
	])

	assert_eq(source.count("static func get_player_model"), 1, "重复函数名应只保留一个。")
	assert_push_warning("[GFAccessGenerator] 函数名重复，已跳过：get_player_model")


func test_access_generator_extension_can_append_source_with_builder() -> void:
	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var builder: GFSourceBuilder = GFSourceBuilder.new()
	var extension: AppendAccessExtension = AppendAccessExtension.new()

	generator._append_access_generator_extension(builder, [
		{
			"class_name": "PlayerModel",
			"kind": GFAccessGenerator.TargetKind.MODEL,
		},
	], extension, "test://append")
	var source: String = builder.build()

	assert_eq(extension.record_count, 1, "扩展应收到当前生成记录。")
	assert_true(source.contains("static func get_test_extension_marker() -> String:"), "扩展应能直接追加访问器源码。")
	assert_true(source.contains("return \"append\""), "扩展追加的函数体应保留。")


func test_access_generator_extension_can_return_source_sections() -> void:
	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var builder: GFSourceBuilder = GFSourceBuilder.new()

	generator._append_access_generator_extension(builder, [
		{
			"class_name": "PlayerModel",
			"kind": GFAccessGenerator.TargetKind.MODEL,
		},
		{
			"class_name": "BattleSystem",
			"kind": GFAccessGenerator.TargetKind.SYSTEM,
		},
	], SectionAccessExtension.new(), "test://sections")
	var source: String = builder.build()

	assert_true(source.contains("static func get_test_section_marker() -> int:"), "扩展应能返回源码片段。")
	assert_true(source.contains("\treturn 2"), "返回片段中的换行与缩进应被保留。")


func test_save_source_can_refuse_overwrite() -> void:
	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var path: String = "user://gf_access_generator_no_overwrite.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建临时访问器源文件。")
	if file == null:
		return
	var _store_string_result_146: Variant = file.store_string("old")
	file.close()

	var error: Error = generator.save_source(path, "new", false)
	var read_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(read_file, "测试应能读取临时访问器源文件。")
	if read_file == null:
		return
	var content: String = read_file.get_as_text()
	read_file.close()
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK, "测试应能删除临时访问器源文件。")

	assert_eq(error, ERR_ALREADY_EXISTS, "禁止覆盖时已有目标文件应返回 ERR_ALREADY_EXISTS。")
	assert_eq(content, "old", "禁止覆盖时不应改写已有文件。")
	assert_push_warning("[GFAccessGenerator] 目标文件已存在，已跳过：%s" % path)


func test_save_source_with_report_supports_dry_run_without_writing() -> void:
	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var path: String = "user://gf_access_generator_dry_run_%d.gd" % Time.get_ticks_usec()

	var report: Dictionary = generator.save_source_with_report(path, "new", {
		"dry_run": true,
	})

	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "success"), "dry-run 报告应成功。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(report, "status"), GFGeneratedArtifactReport.STATUS_NEW, "不存在的目标应报告 new。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "written"), "dry-run 不应写入文件。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "changed"), "dry-run 应报告有待写入内容。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "dry_run"), "报告应保留 dry_run 标记。")
	assert_false(FileAccess.file_exists(path), "dry-run 不应创建目标文件。")


func test_capability_access_extension_accepts_spatial_node_capability_bases() -> void:
	var extension: Object = _new_object(GF_CAPABILITY_ACCESS_GENERATOR_EXTENSION_BASE)

	assert_false(_call_bool(extension, &"_is_capability_script", [GF_CAPABILITY_BASE]), "GFCapability 基类不应生成访问器。")
	assert_false(_call_bool(extension, &"_is_capability_script", [GF_NODE_CAPABILITY_BASE]), "GFNodeCapability 基类不应生成访问器。")
	assert_true(_call_bool(extension, &"_is_capability_script", [GF_NODE_2D_CAPABILITY_BASE]), "GFNode2DCapability 应由能力扩展识别。")
	assert_true(_call_bool(extension, &"_is_capability_script", [GF_NODE_3D_CAPABILITY_BASE]), "GFNode3DCapability 应由能力扩展识别。")
	assert_true(_call_bool(extension, &"_is_capability_script", [GF_CONTROL_CAPABILITY_BASE]), "GFControlCapability 应由能力扩展识别。")


func test_kernel_access_generator_no_longer_resolves_capability_kind() -> void:
	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var kind: int = generator._resolve_kind(GF_NODE_2D_CAPABILITY_BASE)

	assert_eq(kind, -1, "Capability 记录应由能力扩展的访问器扩展贡献，而不是 kernel 直接识别。")


func test_access_generator_extension_can_append_records() -> void:
	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var records: Array[Dictionary] = []
	var extension: RecordAccessExtension = RecordAccessExtension.new()

	generator._append_access_generator_extension_records_from_instance(records, extension, "test://records")

	assert_eq(records.size(), 1, "扩展应能向访问器记录列表追加记录。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(records[0], "class_name"), "GeneratedModel", "追加记录应保留 class_name。")


func test_record_only_access_generator_extension_does_not_warn_for_missing_source_hook() -> void:
	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var builder: GFSourceBuilder = GFSourceBuilder.new()
	var extension: RecordAccessExtension = RecordAccessExtension.new()

	generator._append_access_generator_extension(builder, [], extension, "test://records")

	assert_eq(builder.build(), "", "只贡献记录的访问器扩展不需要追加源码。")
	assert_push_warning_count(0, "只贡献记录的访问器扩展不应误报缺少源码钩子。")


func test_build_project_source_generates_layer_input_and_setting_constants() -> void:
	var generator: GFAccessGenerator = GFAccessGenerator.new()
	var source: String = generator.build_project_source({
		"layers": [
			{
				"group": "2d_physics",
				"name": "Player",
				"index": 3,
			},
		],
		"input_actions": [&"jump"],
		"settings": ["gf/project/installers"],
	})

	assert_true(source.contains("class_name GFProjectAccess"), "应生成项目常量访问器类。")
	assert_true(source.contains("const PHYSICS_2D_PLAYER_LAYER: int = 3"), "应生成层序号常量。")
	assert_true(source.contains("const PHYSICS_2D_PLAYER_BIT: int = 4"), "应生成层 bit 常量。")
	assert_true(source.contains("const JUMP: StringName = &\"jump\""), "应生成输入动作常量。")
	assert_true(source.contains("const GF_PROJECT_INSTALLERS: String = \"gf/project/installers\""), "应生成设置键常量。")


func test_collect_project_records_uses_project_input_settings_only() -> void:
	var generator: GFAccessGenerator = GFAccessGenerator.new()
	ProjectSettings.set_setting("input/gf_test_jump", { "deadzone": 0.5, "events": [] })
	ProjectSettings.set_setting("input/ui_gf_test_accept", { "deadzone": 0.5, "events": [] })
	ProjectSettings.set_setting("input/spatial_editor/gf_test_forward", { "deadzone": 0.5, "events": [] })

	var records: Dictionary = generator.collect_project_records()
	var actions: Array = GF_VARIANT_ACCESS.get_option_array(records, "input_actions")

	ProjectSettings.clear("input/gf_test_jump")
	ProjectSettings.clear("input/ui_gf_test_accept")
	ProjectSettings.clear("input/spatial_editor/gf_test_forward")

	assert_true(actions.has(&"gf_test_jump"), "项目自定义 input 设置应生成常量。")
	assert_false(actions.has(&"ui_gf_test_accept"), "内置 UI 风格动作不应生成项目常量。")
	assert_false(actions.has(&"spatial_editor/gf_test_forward"), "编辑器专用动作不应生成项目常量。")


func test_collect_project_records_includes_known_gf_settings_without_plugin_registration() -> void:
	var generator: GFAccessGenerator = GFAccessGenerator.new()

	var records: Dictionary = generator.collect_project_records()
	var settings: Array = GF_VARIANT_ACCESS.get_option_array(records, "settings")

	assert_true(settings.has("gf/codegen/access_output_path"), "生成器应稳定包含 GF codegen 设置。")
	assert_true(settings.has("gf/codegen/access_policies"), "生成器应稳定包含访问策略设置。")
	assert_true(settings.has("gf/project/installers"), "生成器应稳定包含 GF installer 设置。")
	assert_false(settings.has("gf/build/export/write_metadata"), "kernel 生成器不应硬编码标准库 debug 导出设置。")
	assert_false(settings.has("gf/build/export/build_metadata"), "kernel 生成器不应硬编码标准库 debug 导出元数据设置。")


# --- 私有/辅助方法 ---

func _get_generated_function_source(source: String, signature_prefix: String) -> String:
	var start_index: int = source.find(signature_prefix)
	if start_index < 0:
		return ""
	var next_function_index: int = source.find(
		"\nstatic func ",
		start_index + signature_prefix.length()
	)
	if next_function_index < 0:
		return source.substr(start_index)
	return source.substr(start_index, next_function_index - start_index)


func _new_object(script: Variant) -> Object:
	if script is Script:
		var helper_script: Script = script
		var instance: Variant = helper_script.call(&"new")
		if instance is Object:
			var object_instance: Object = instance
			return object_instance
	return null


func _call_bool(target: Object, method_name: StringName, args: Array = []) -> bool:
	return GF_VARIANT_ACCESS.to_bool(target.callv(method_name, args))


# --- 内部类 ---

class AppendAccessExtension:
	var record_count: int = -1

	func append_access_source(builder: GFSourceBuilder, records: Array) -> void:
		record_count = records.size()
		builder.doc("测试扩展访问器。")
		builder.line("static func get_test_extension_marker() -> String:")
		builder.indent()
		builder.line("return \"append\"")
		builder.dedent()
		builder.blank(2)


class SectionAccessExtension:
	func get_access_source_sections(records: Array) -> Array[String]:
		return [
			"static func get_test_section_marker() -> int:\n\treturn %d" % records.size(),
		]


class RecordAccessExtension:
	func append_access_records(records: Array[Dictionary]) -> void:
		records.append({
			"class_name": "GeneratedModel",
			"path": "res://generated_model.gd",
			"kind": GFAccessGenerator.TargetKind.MODEL,
		})
