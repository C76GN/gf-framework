extends GutTest


# --- 常量 ---

const GODOT_POLICY_PATH: String = "res://addons/gf/kernel/package/gf_package_cache_policy.gd"
const GODOT_STORE_PATH: String = "res://addons/gf/kernel/package/gf_package_filesystem_cache_store.gd"
const GODOT_BACKEND_PATH: String = "res://addons/gf/kernel/package/gf_package_manager_backend.gd"
const GODOT_CLI_PATH: String = "res://addons/gf/kernel/package/gf_package_cli.gd"
const SHARED_SCHEMA_PATH: String = "res://addons/gf/kernel/package/gf_package_cache_schema.json"
const PYTHON_CACHE_PATH: String = "res://tools/gf_package_cache.py"
const PYTHON_INSTALLER_PATH: String = "res://tools/gf_package_installer.py"


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

	assert_eq(_dictionary_int(schema, "schema_version"), 1, "Package cache policy schema 必须显式版本化。")
	assert_eq(_dictionary_int(schema, "layout_version"), 1, "Package cache artifact layout 必须显式版本化。")
	assert_eq(schema_modes, expected_modes, "共享 schema 必须固定三种 cache mode。")
	assert_eq(schema_report_fields, expected_report_fields, "共享 schema 必须固定 cache report 字段。")
	assert_true(_read_text(GODOT_POLICY_PATH).contains("gf_package_cache_schema.json"), "Godot policy 必须读取共享 schema。")
	assert_true(_read_text(PYTHON_CACHE_PATH).contains("gf_package_cache_schema.json"), "Python cache 必须读取共享 schema。")


func test_package_backends_delegate_cache_policy_and_store_ownership() -> void:
	var godot_backend: String = _read_text(GODOT_BACKEND_PATH)
	var python_installer: String = _read_text(PYTHON_INSTALLER_PATH)

	assert_true(godot_backend.contains("gf_package_cache_policy.gd"), "Godot backend 必须委托 cache policy。")
	assert_true(godot_backend.contains("gf_package_filesystem_cache_store.gd"), "Godot backend 必须委托 filesystem artifact store。")
	assert_false(godot_backend.contains("static func _resolve_cache_dir("), "Godot backend 不得重新解释裸 cache_dir。")
	assert_true(python_installer.contains("import gf_package_cache"), "Python installer 必须委托共享 cache 模块。")
	assert_false(python_installer.contains("def resolve_cache_dir("), "Python installer 不得重新解释裸 cache_dir。")
	assert_true(_read_text(GODOT_STORE_PATH).contains("objects/sha256"), "Godot store 必须使用完整 SHA-256 内容寻址布局。")
	assert_true(_read_text(PYTHON_CACHE_PATH).contains("\"objects\" / \"sha256\""), "Python store 必须使用完整 SHA-256 内容寻址布局。")


func test_package_cache_cli_keeps_explicit_initialization_and_modes() -> void:
	var godot_cli: String = _read_text(GODOT_CLI_PATH)
	var python_installer: String = _read_text(PYTHON_INSTALLER_PATH)

	assert_true(godot_cli.contains("const COMMAND_CACHE_INIT: String = \"cache-init\""), "Godot CLI 必须保留显式 cache-init。")
	assert_true(godot_cli.contains("--cache-mode"), "Godot CLI 必须暴露显式 cache mode。")
	assert_true(python_installer.contains("subparsers.add_parser(\"cache-init\""), "Python CLI 必须保留显式 cache-init。")
	assert_true(python_installer.contains("add_argument(\"--cache-mode\""), "Python CLI 必须暴露显式 cache mode。")
	assert_true(_read_text(GODOT_POLICY_PATH).contains("Refusing to claim a non-empty directory"), "Godot cache-init 必须拒绝接管非空未知目录。")
	assert_true(_read_text(PYTHON_CACHE_PATH).contains("Refusing to claim a non-empty directory"), "Python cache-init 必须拒绝接管非空未知目录。")


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


func _dictionary_int(data: Dictionary, key: String) -> int:
	var raw_value: Variant = data.get(key, 0)
	if raw_value is int:
		var integer_value: int = raw_value
		return integer_value
	if raw_value is float:
		var float_value: float = raw_value
		return int(float_value)
	return 0
