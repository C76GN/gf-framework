extends GutTest


# --- 常量 ---

const SHARED_SCHEMA_PATH: String = "res://addons/gf/kernel/package/gf_package_cache_schema.json"
const PYTHON_INSTALLER_PATH: String = "res://tools/gf_package_installer.py"
const GF_PACKAGE_CACHE_POLICY = preload("res://addons/gf/kernel/package/gf_package_cache_policy.gd")
const GF_PACKAGE_FILESYSTEM_CACHE_STORE = preload("res://addons/gf/kernel/package/gf_package_filesystem_cache_store.gd")
const GF_PACKAGE_CLI = preload("res://addons/gf/kernel/package/gf_package_cli.gd")


# --- 测试用例 ---

func test_package_cache_implementations_share_one_versioned_policy_schema() -> void:
	var schema: Dictionary = _read_json(SHARED_SCHEMA_PATH)
	var expected_modes: PackedStringArray = PackedStringArray([
		"external_read_only",
		"external_shared_rw",
		"project_local",
	])
	var expected_report_fields: PackedStringArray = PackedStringArray([
		"artifact_read_roots",
		"artifact_write_root",
		"external",
		"marker_path",
		"marker_valid",
		"mode",
		"read_only",
		"schema_version",
		"workspace_root",
	])
	var schema_modes: PackedStringArray = _dictionary_string_array(schema, "modes")
	var schema_report_fields: PackedStringArray = _dictionary_string_array(schema, "context_report_fields")
	expected_modes.sort()
	expected_report_fields.sort()
	schema_modes.sort()
	schema_report_fields.sort()
	var schema_version_value: Variant = schema.get("schema_version")
	var layout_version_value: Variant = schema.get("layout_version")

	assert_true(schema_version_value is float, "Package cache policy runtime schema 版本必须为数字。")
	if schema_version_value is float:
		var schema_version: float = schema_version_value
		assert_eq(schema_version, 1.0, "Package cache policy runtime schema 版本必须为 1。")
	assert_true(layout_version_value is float, "Package cache artifact runtime layout 版本必须为数字。")
	if layout_version_value is float:
		var layout_version: float = layout_version_value
		assert_eq(layout_version, 1.0, "Package cache artifact runtime layout 版本必须为 1。")
	assert_eq(schema_modes, expected_modes, "共享 schema 必须固定三种 cache mode。")
	assert_eq(schema_report_fields, expected_report_fields, "共享 schema 必须固定 cache report 字段。")


func test_package_cache_store_exposes_content_addressed_layout_behavior() -> void:
	var digest: String = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
	assert_eq(
		GF_PACKAGE_FILESYSTEM_CACHE_STORE.artifact_path("res://cache-root", digest, ".zip"),
		"res://cache-root/objects/sha256/aa/%s.zip" % digest.to_lower(),
		"Artifact store 必须以完整 SHA-256 构造两级内容寻址路径。"
	)
	assert_false(FileAccess.file_exists(PYTHON_INSTALLER_PATH), "Python cache 可以服务维护构建，但不得恢复第二套项目安装器。")


func test_package_cache_cli_keeps_explicit_initialization_and_modes() -> void:
	assert_eq(GF_PACKAGE_CLI.COMMAND_CACHE_INIT, "cache-init", "Godot CLI 必须保留显式 cache-init。")
	assert_eq(GF_PACKAGE_CACHE_POLICY.MODE_PROJECT_LOCAL, "project_local")
	assert_eq(GF_PACKAGE_CACHE_POLICY.MODE_EXTERNAL_READ_ONLY, "external_read_only")
	assert_eq(GF_PACKAGE_CACHE_POLICY.MODE_EXTERNAL_SHARED_RW, "external_shared_rw")


# --- 私有/辅助方法 ---

func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "维护测试应能读取：%s" % path)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	if parsed is Dictionary:
		var data: Dictionary = parsed
		return data
	return {}


func _dictionary_string_array(data: Dictionary, key: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var raw_values: Variant = data.get(key, [])
	if not raw_values is Array:
		return result
	var values: Array = raw_values
	for raw_value: Variant in values:
		if raw_value is String:
			var text_value: String = raw_value
			var _append_value: bool = result.append(text_value)
	return result
