## 测试 GFShaderInterfaceSnapshot 的稳定捕获、持久化与参数契约校验。
extends GutTest


var _temporary_resource_paths: PackedStringArray = PackedStringArray()


func after_each() -> void:
	for resource_path: String in _temporary_resource_paths:
		var absolute_path: String = ProjectSettings.globalize_path(resource_path)
		if FileAccess.file_exists(absolute_path):
			var _remove_result: Error = DirAccess.remove_absolute(absolute_path)
	_temporary_resource_paths.clear()


func test_capture_normalizes_uniform_schema_and_stable_order() -> void:
	var shader: Shader = _make_contract_shader()
	var snapshot: GFShaderInterfaceSnapshot = GFShaderInterfaceSnapshot.capture(shader)

	assert_not_null(snapshot)
	assert_eq(snapshot.get_schema_version(), GFShaderInterfaceSnapshot.CURRENT_SCHEMA_VERSION)
	assert_eq(snapshot.get_shader_mode(), Shader.MODE_CANVAS_ITEM)
	assert_eq(
		snapshot.get_uniform_names(),
		[&"albedo_texture", &"amount", &"direction", &"z_tint"],
		"接口快照必须脱离 shader 声明顺序，按参数名稳定排序。"
	)

	var amount_uniform: Dictionary = snapshot.get_uniform(&"amount")
	for field_name: String in ["name", "type", "class_name", "hint", "hint_string", "usage"]:
		assert_has(amount_uniform, field_name, "规范化 uniform 必须包含字段：%s。" % field_name)
	assert_eq(GFVariantData.get_option_string_name(amount_uniform, "name"), &"amount")
	assert_eq(GFVariantData.get_option_int(amount_uniform, "type"), TYPE_FLOAT)
	assert_eq(GFVariantData.get_option_int(amount_uniform, "hint"), PROPERTY_HINT_RANGE)


func test_snapshot_getters_return_deep_copies() -> void:
	var snapshot: GFShaderInterfaceSnapshot = GFShaderInterfaceSnapshot.capture(
		_make_contract_shader()
	)
	var uniforms: Array[Dictionary] = snapshot.get_uniforms()
	var first_uniform: Dictionary = uniforms[0]
	first_uniform["name"] = &"mutated"
	first_uniform["hint_string"] = "mutated"
	uniforms[0] = first_uniform

	var amount_uniform: Dictionary = snapshot.get_uniform(&"amount")
	amount_uniform["type"] = TYPE_STRING

	assert_eq(
		snapshot.get_uniform_names(),
		[&"albedo_texture", &"amount", &"direction", &"z_tint"],
		"调用方修改返回值不得污染已捕获的契约。"
	)
	assert_eq(
		GFVariantData.get_option_int(snapshot.get_uniform(&"amount"), "type"),
		TYPE_FLOAT
	)


func test_snapshot_resource_roundtrip_preserves_sealed_storage() -> void:
	var snapshot: GFShaderInterfaceSnapshot = GFShaderInterfaceSnapshot.capture(
		_make_contract_shader()
	)
	var reversed_uniforms: Array[Dictionary] = snapshot.get_uniforms()
	reversed_uniforms.reverse()
	snapshot.set(&"_uniforms", reversed_uniforms)
	assert_eq(
		snapshot.get_uniform_names(),
		[&"albedo_texture", &"amount", &"direction", &"z_tint"],
		"Storage setter 必须在保存前恢复规范顺序。"
	)
	var resource_path: String = "user://gf_shader_interface_snapshot_%d.tres" % Time.get_ticks_usec()
	var _path_appended: bool = _temporary_resource_paths.append(resource_path)

	assert_eq(ResourceSaver.save(snapshot, resource_path), OK)
	var loaded_value: Variant = ResourceLoader.load(
		resource_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	var loaded_snapshot: GFShaderInterfaceSnapshot = _variant_to_snapshot(loaded_value)

	assert_not_null(loaded_snapshot, "@export_storage 字段必须支持 Resource 持久化。")
	assert_eq(loaded_snapshot.to_dict(), snapshot.to_dict())
	assert_true(loaded_snapshot.validate_definition().is_ok())


func test_blank_snapshot_resource_is_not_a_valid_empty_spatial_contract() -> void:
	var snapshot: GFShaderInterfaceSnapshot = GFShaderInterfaceSnapshot.new()
	var resource_path: String = (
		"user://gf_shader_interface_blank_%d.tres" % Time.get_ticks_usec()
	)
	var _path_appended: bool = _temporary_resource_paths.append(resource_path)

	var report: GFValidationReport = snapshot.validate_definition()
	assert_false(report.is_ok(), "未捕获的空 Resource 不得伪装成合法接口。")
	assert_eq(
		GFVariantData.get_option_int(
			report.get_issue_counts_by_kind(),
			"shader_interface_snapshot_missing"
		),
		1
	)

	assert_eq(ResourceSaver.save(snapshot, resource_path), OK)
	var loaded_value: Variant = ResourceLoader.load(
		resource_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	var loaded_snapshot: GFShaderInterfaceSnapshot = _variant_to_snapshot(
		loaded_value
	)

	assert_not_null(loaded_snapshot)
	assert_false(
		loaded_snapshot.validate_definition().is_ok(),
		"字段缺失的持久化 Resource 重载后仍必须失败关闭。"
	)


func test_definition_validation_rejects_future_schema_and_invalid_uniforms() -> void:
	var future_snapshot: GFShaderInterfaceSnapshot = GFShaderInterfaceSnapshot.from_dict({
		"schema_version": GFShaderInterfaceSnapshot.CURRENT_SCHEMA_VERSION + 1,
		"shader_mode": Shader.MODE_CANVAS_ITEM,
		"uniforms": [_make_uniform_entry(&"amount", TYPE_FLOAT)],
	})
	var future_report: GFValidationReport = future_snapshot.validate_definition()

	assert_false(future_report.is_ok(), "未来 schema 不得被当前实现静默接受。")
	assert_eq(
		GFVariantData.get_option_int(
			future_report.get_issue_counts_by_kind(),
			"shader_interface_schema_version_unsupported"
		),
		1
	)
	assert_false(
		future_snapshot.accepts_parameter_value(&"amount", 0.5),
		"不支持的快照 schema 不得通过单参数快捷校验。"
	)

	var invalid_snapshot: GFShaderInterfaceSnapshot = GFShaderInterfaceSnapshot.from_dict({
		"schema_version": GFShaderInterfaceSnapshot.CURRENT_SCHEMA_VERSION,
		"shader_mode": Shader.MODE_CANVAS_ITEM,
		"uniforms": [
			_make_uniform_entry(&"amount", TYPE_FLOAT),
			_make_uniform_entry(&"amount", TYPE_FLOAT),
			_make_uniform_entry(&"", TYPE_NIL),
		],
	})
	var invalid_report: GFValidationReport = invalid_snapshot.validate_definition()
	var issue_counts: Dictionary = invalid_report.get_issue_counts_by_kind()

	assert_false(invalid_report.is_ok())
	assert_eq(
		GFVariantData.get_option_int(issue_counts, "shader_uniform_duplicate"),
		1,
		"重复 uniform 必须使契约定义失败。"
	)
	assert_gt(
		GFVariantData.get_option_int(issue_counts, "shader_uniform_invalid"),
		0,
		"空名称和 TYPE_NIL 必须作为无效 uniform 报告。"
	)


func test_from_dict_rejects_malformed_schema_without_coercion() -> void:
	var malformed_entries: Array[Dictionary] = []
	for field_name: String in [
		"name",
		"type",
		"class_name",
		"hint",
		"hint_string",
		"usage",
	]:
		var malformed_entry: Dictionary = _make_uniform_entry(&"amount", TYPE_FLOAT)
		if field_name in ["name", "class_name", "hint_string"]:
			malformed_entry[field_name] = 123
		else:
			malformed_entry[field_name] = "123"
		malformed_entries.append(malformed_entry)

	var malformed_snapshot: GFShaderInterfaceSnapshot = (
		GFShaderInterfaceSnapshot.from_dict({
			"schema_version": "1",
			"shader_mode": "canvas_item",
			"uniforms": malformed_entries,
		})
	)
	var malformed_counts: Dictionary = (
		malformed_snapshot.validate_definition().get_issue_counts_by_kind()
	)

	assert_eq(
		GFVariantData.get_option_int(
			malformed_counts,
			"shader_interface_schema_version_unsupported"
		),
		1,
		"schema_version 不得从字符串强转。"
	)
	assert_eq(
		GFVariantData.get_option_int(
			malformed_counts,
			"shader_interface_mode_invalid"
		),
		1,
		"shader_mode 不得从字符串强转。"
	)
	assert_eq(
		GFVariantData.get_option_int(malformed_counts, "shader_uniform_invalid"),
		malformed_entries.size(),
		"uniform 字段必须保持显式类型，错误字段不得被默认值掩盖。"
	)

	var missing_uniforms_snapshot: GFShaderInterfaceSnapshot = (
		GFShaderInterfaceSnapshot.from_dict({
			"schema_version": GFShaderInterfaceSnapshot.CURRENT_SCHEMA_VERSION,
			"shader_mode": Shader.MODE_CANVAS_ITEM,
		})
	)
	var missing_uniforms_counts: Dictionary = (
		missing_uniforms_snapshot.validate_definition().get_issue_counts_by_kind()
	)
	assert_eq(
		GFVariantData.get_option_int(
			missing_uniforms_counts,
			"shader_uniform_invalid"
		),
		1,
		"缺失 uniforms 数组必须失败关闭。"
	)

	var wrong_uniforms_snapshot: GFShaderInterfaceSnapshot = (
		GFShaderInterfaceSnapshot.from_dict({
			"schema_version": GFShaderInterfaceSnapshot.CURRENT_SCHEMA_VERSION,
			"shader_mode": Shader.MODE_CANVAS_ITEM,
			"uniforms": {},
		})
	)
	assert_eq(
		GFVariantData.get_option_int(
			wrong_uniforms_snapshot.validate_definition().get_issue_counts_by_kind(),
			"shader_uniform_invalid"
		),
		1,
		"非数组 uniforms 也必须失败关闭。"
	)


func test_parameter_validation_is_partial_but_strict_by_default() -> void:
	var snapshot: GFShaderInterfaceSnapshot = GFShaderInterfaceSnapshot.capture(
		_make_contract_shader()
	)
	var partial_report: GFValidationReport = snapshot.validate_parameters({
		&"amount": 0.5,
	})

	assert_true(partial_report.is_ok(), "Profile 默认是部分覆盖，不应要求声明全部 uniform。")

	var invalid_report: GFValidationReport = snapshot.validate_parameters({
		&"amount": 1,
		&"unknown_parameter": 1.0,
	})
	var invalid_counts: Dictionary = invalid_report.get_issue_counts_by_kind()

	assert_false(invalid_report.is_ok())
	assert_eq(
		GFVariantData.get_option_int(invalid_counts, "shader_parameter_type_mismatch"),
		1,
		"float uniform 不得隐式接受 int。"
	)
	assert_eq(
		GFVariantData.get_option_int(invalid_counts, "shader_parameter_extra"),
		1,
		"未知参数必须默认作为契约错误。"
	)

	var complete_report: GFValidationReport = snapshot.validate_parameters({
		&"amount": 0.5,
	}, {
		"missing_severity": "error",
	})
	assert_false(complete_report.is_ok(), "完整契约模式必须显式报告缺失参数。")
	assert_gt(
		GFVariantData.get_option_int(
			complete_report.get_issue_counts_by_kind(),
			"shader_parameter_missing"
		),
		0
	)


func test_sampler_contract_accepts_null_and_expected_resource_class_only() -> void:
	var snapshot: GFShaderInterfaceSnapshot = GFShaderInterfaceSnapshot.capture(
		_make_contract_shader()
	)

	var null_report: GFValidationReport = snapshot.validate_parameters({
		&"albedo_texture": null,
	})
	var texture_report: GFValidationReport = snapshot.validate_parameters({
		&"albedo_texture": ImageTexture.new(),
	})
	var wrong_class_report: GFValidationReport = snapshot.validate_parameters({
		&"albedo_texture": Curve.new(),
	})

	assert_true(null_report.is_ok(), "sampler 参数必须允许用 null 清除纹理。")
	assert_true(texture_report.is_ok(), "sampler 参数必须接受声明的 Texture2D 子类。")
	assert_false(wrong_class_report.is_ok())
	assert_eq(
		GFVariantData.get_option_int(
			wrong_class_report.get_issue_counts_by_kind(),
			"shader_parameter_class_mismatch"
		),
		1,
		"TYPE_OBJECT 外层类型相同仍必须校验 shader 声明的资源类型。"
	)


func test_compare_reports_mode_presence_signature_and_usage_drift() -> void:
	var expected: GFShaderInterfaceSnapshot = GFShaderInterfaceSnapshot.from_dict({
		"schema_version": GFShaderInterfaceSnapshot.CURRENT_SCHEMA_VERSION,
		"shader_mode": Shader.MODE_CANVAS_ITEM,
		"uniforms": [
			_make_uniform_entry(&"amount", TYPE_FLOAT),
			_make_uniform_entry(&"only_expected", TYPE_FLOAT),
			_make_uniform_entry(&"usage_only", TYPE_FLOAT),
		],
	})
	var changed_usage_entry: Dictionary = _make_uniform_entry(&"usage_only", TYPE_FLOAT)
	changed_usage_entry["usage"] = PROPERTY_USAGE_DEFAULT + 1
	var actual: GFShaderInterfaceSnapshot = GFShaderInterfaceSnapshot.from_dict({
		"schema_version": GFShaderInterfaceSnapshot.CURRENT_SCHEMA_VERSION,
		"shader_mode": Shader.MODE_SPATIAL,
		"uniforms": [
			_make_uniform_entry(&"amount", TYPE_VECTOR2),
			_make_uniform_entry(&"only_actual", TYPE_FLOAT),
			changed_usage_entry,
		],
	})

	var report: GFValidationReport = expected.compare_with(actual)
	var issue_counts: Dictionary = report.get_issue_counts_by_kind()

	assert_false(report.is_ok(), "mode、缺失和类型漂移必须使契约失败。")
	assert_false(report.is_healthy(), "新增参数和 usage 漂移默认也应保留 warning。")
	assert_eq(
		GFVariantData.get_option_int(issue_counts, "shader_interface_mode_mismatch"),
		1
	)
	assert_eq(GFVariantData.get_option_int(issue_counts, "shader_uniform_missing"), 1)
	assert_eq(GFVariantData.get_option_int(issue_counts, "shader_uniform_extra"), 1)
	assert_eq(
		GFVariantData.get_option_int(issue_counts, "shader_uniform_signature_mismatch"),
		2,
		"类型签名与 usage 漂移必须分别形成稳定问题。"
	)


func _make_contract_shader() -> Shader:
	var shader: Shader = Shader.new()
	shader.code = "\n".join(PackedStringArray([
		"shader_type canvas_item;",
		"uniform vec4 z_tint : source_color = vec4(1.0);",
		"uniform vec2 direction = vec2(1.0, 0.0);",
		"uniform float amount : hint_range(0.0, 1.0) = 0.0;",
		"uniform sampler2D albedo_texture;",
		"void fragment() {",
		"	COLOR = z_tint * amount;",
		"}",
	]))
	return shader


func _make_uniform_entry(parameter_name: StringName, value_type: int) -> Dictionary:
	return {
		"name": parameter_name,
		"type": value_type,
		"class_name": &"",
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"usage": PROPERTY_USAGE_DEFAULT,
	}


func _variant_to_snapshot(value: Variant) -> GFShaderInterfaceSnapshot:
	if value is GFShaderInterfaceSnapshot:
		var snapshot: GFShaderInterfaceSnapshot = value
		return snapshot
	return null
