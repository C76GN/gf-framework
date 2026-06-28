## 测试 GFInputMapping / GFInputContext 资源上的查询与回退逻辑。
extends GutTest

const _GFInputContextDiagnostics = preload("res://addons/gf/standard/input/mapping/gf_input_context_diagnostics.gd")


func test_input_mapping_get_action_id_delegates_to_action() -> void:
	var action: GFInputAction = GFInputAction.new()
	action.action_id = &"fire"
	var mapping: GFInputMapping = GFInputMapping.new()
	mapping.action = action
	assert_eq(mapping.get_action_id(), &"fire")


func test_input_action_id_does_not_fall_back_to_resource_path() -> void:
	var action: GFInputAction = GFInputAction.new()
	action.take_over_path("res://tests/gf_core/input_action_unit.tres")

	assert_eq(action.get_action_id(), &"", "动作稳定 ID 必须显式设置，不能由资源路径隐式生成。")


func test_input_mapping_get_action_id_empty_without_action() -> void:
	var mapping: GFInputMapping = GFInputMapping.new()
	assert_eq(mapping.get_action_id(), &"")


func test_input_mapping_display_name_and_category_override_action() -> void:
	var action: GFInputAction = GFInputAction.new()
	action.action_id = &"jump"
	action.display_name = "动作默认名"
	action.display_category = "动作分类"
	var mapping: GFInputMapping = GFInputMapping.new()
	mapping.action = action
	mapping.display_name = "映射覆盖名"
	mapping.display_category = "映射分类"
	assert_eq(mapping.get_display_name(), "映射覆盖名")
	assert_eq(mapping.get_display_category(), "映射分类")


func test_input_mapping_display_fallback_to_action() -> void:
	var action: GFInputAction = GFInputAction.new()
	action.display_name = "仅动作名"
	var mapping: GFInputMapping = GFInputMapping.new()
	mapping.action = action
	assert_eq(mapping.get_display_name(), "仅动作名")
	assert_eq(mapping.get_display_category(), "")


func test_input_mapping_default_display_name_when_no_action() -> void:
	var mapping: GFInputMapping = GFInputMapping.new()
	assert_eq(mapping.get_display_name(), "Input Mapping")


func test_input_context_get_context_id_prefers_exported_id() -> void:
	var context: GFInputContext = GFInputContext.new()
	context.context_id = &"gameplay"
	assert_eq(context.get_context_id(), &"gameplay")


func test_input_context_get_display_name_prefers_exported_name() -> void:
	var context: GFInputContext = GFInputContext.new()
	context.context_id = &"menu"
	context.display_name = "主菜单"
	assert_eq(context.get_display_name(), "主菜单")


func test_input_context_get_display_name_falls_back_to_context_id_string() -> void:
	var context: GFInputContext = GFInputContext.new()
	context.context_id = &"dialogue"
	assert_eq(context.get_display_name(), "dialogue")


func test_input_context_get_context_id_falls_back_to_resource_path() -> void:
	var context: GFInputContext = GFInputContext.new()
	context.take_over_path("res://tests/gf_core/input_context_unit.tres")
	assert_eq(context.get_context_id(), StringName("res://tests/gf_core/input_context_unit.tres"))


func test_input_context_display_name_falls_back_to_resource_basename() -> void:
	var context: GFInputContext = GFInputContext.new()
	context.take_over_path("res://tests/gf_core/gameplay_input.tres")
	assert_eq(context.get_display_name(), "Gameplay Input")


func test_input_context_diagnostics_reports_healthy_context() -> void:
	var context: GFInputContext = GFInputContext.new()
	context.context_id = &"gameplay"
	context.mappings = [_make_valid_mapping(&"jump")]

	var report: Dictionary = _GFInputContextDiagnostics.build_context_report(context)

	assert_eq(GFVariantData.get_option_int(report, "mapping_count"), 1)
	assert_eq(GFVariantData.get_option_int(report, "binding_count"), 1)
	assert_eq(GFVariantData.get_option_int(report, "issue_count"), 0)
	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_true(GFVariantData.get_option_bool(report, "healthy"))


func test_input_context_diagnostics_reports_structure_issues() -> void:
	var context: GFInputContext = GFInputContext.new()
	var missing_action_mapping: GFInputMapping = GFInputMapping.new()
	var invalid_mapping: GFInputMapping = _make_valid_mapping(&"jump")
	invalid_mapping.action.activation_threshold = 1.5
	invalid_mapping.modifiers = [null]
	invalid_mapping.triggers = [null]
	invalid_mapping.bindings = [
		null,
		GFInputBinding.new(),
		_make_invalid_deadzone_binding(),
		_make_input_event_action_binding(&"gf_missing_project_action_for_test"),
	]
	context.mappings = [
		null,
		missing_action_mapping,
		invalid_mapping,
		_make_valid_mapping(&"jump"),
	]

	var report: Dictionary = _GFInputContextDiagnostics.build_context_report(context)
	var issue_counts: Dictionary = GFVariantData.get_option_dictionary(report, "issue_counts_by_kind")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "结构错误应让报告失败。")
	assert_true(issue_counts.has("empty_context_id"))
	assert_true(issue_counts.has("null_mapping"))
	assert_true(issue_counts.has("missing_action"))
	assert_true(issue_counts.has("duplicate_action_id"))
	assert_true(issue_counts.has("invalid_activation_threshold"))
	assert_true(issue_counts.has("empty_bindings"))
	assert_true(issue_counts.has("null_mapping_modifier"))
	assert_true(issue_counts.has("null_trigger"))
	assert_true(issue_counts.has("null_binding"))
	assert_true(issue_counts.has("empty_input_event"))
	assert_true(issue_counts.has("invalid_deadzone"))
	assert_true(issue_counts.has("null_binding_modifier"))
	assert_true(issue_counts.has("missing_project_input_action"))


func test_input_context_diagnostics_can_skip_project_input_map_checks() -> void:
	var context: GFInputContext = GFInputContext.new()
	context.context_id = &"gameplay"
	context.mappings = [_make_mapping_with_binding(
		&"open_map",
		_make_input_event_action_binding(&"gf_missing_project_action_for_test")
	)]

	var report: Dictionary = _GFInputContextDiagnostics.build_context_report(
		context,
		null,
		true,
		{ "include_project_input_map_checks": false }
	)
	var issue_counts: Dictionary = GFVariantData.get_option_dictionary(report, "issue_counts_by_kind")

	assert_false(issue_counts.has("missing_project_input_action"))
	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_true(GFVariantData.get_option_bool(report, "healthy"))


# --- 私有/辅助方法 ---

func _make_valid_mapping(action_id: StringName) -> GFInputMapping:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	var binding: GFInputBinding = GFInputBinding.new()
	binding.input_event = event
	return _make_mapping_with_binding(action_id, binding)


func _make_mapping_with_binding(action_id: StringName, binding: GFInputBinding) -> GFInputMapping:
	var action: GFInputAction = GFInputAction.new()
	action.action_id = action_id
	var mapping: GFInputMapping = GFInputMapping.new()
	mapping.action = action
	mapping.bindings = [binding]
	return mapping


func _make_invalid_deadzone_binding() -> GFInputBinding:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ENTER
	var binding: GFInputBinding = GFInputBinding.new()
	binding.input_event = event
	binding.deadzone = -0.1
	binding.modifiers = [null]
	return binding


func _make_input_event_action_binding(action_name: StringName) -> GFInputBinding:
	var event: InputEventAction = InputEventAction.new()
	event.action = action_name
	var binding: GFInputBinding = GFInputBinding.new()
	binding.input_event = event
	return binding
