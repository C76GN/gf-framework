extends GutTest


# --- 常量 ---

const GODOT_ENGINE_PATH: String = "res://addons/gf/kernel/package/gf_package_transaction_engine.gd"
const GODOT_BACKEND_PATH: String = "res://addons/gf/kernel/package/gf_package_manager_backend.gd"
const GODOT_CLI_PATH: String = "res://addons/gf/kernel/package/gf_package_cli.gd"
const SHARED_SCHEMA_PATH: String = "res://addons/gf/kernel/package/gf_package_transaction_schema.json"
const PYTHON_ENGINE_PATH: String = "res://tools/gf_package_transaction.py"
const PYTHON_INSTALLER_PATH: String = "res://tools/gf_package_installer.py"


# --- 测试用例 ---

func test_package_mutation_has_one_transaction_engine_owner_per_backend() -> void:
	var godot_backend_source: String = _read_text(GODOT_BACKEND_PATH)
	var python_installer_source: String = _read_text(PYTHON_INSTALLER_PATH)
	var forbidden_godot_markers: PackedStringArray = PackedStringArray([
		"static func _copy_staged_files_to_project(",
		"static func _delete_package_files_from_project(",
		"static func _write_lockfile_last(",
		"static func _rollback_install_files(",
	])
	var forbidden_python_markers: PackedStringArray = PackedStringArray([
		"def copy_staged_files_to_project(",
		"def delete_package_files_from_project(",
		"def write_lockfile_last(",
		"def rollback_files(",
	])

	assert_true(godot_backend_source.contains("gf_package_transaction_engine.gd"), "Godot package backend 必须委托内核事务引擎。")
	assert_true(godot_backend_source.contains("_execute_package_transaction("), "Godot package backend 必须通过单一事务 adapter 提交文件。")
	assert_true(python_installer_source.contains("import gf_package_transaction"), "Python installer 必须委托维护侧事务引擎。")
	assert_true(python_installer_source.contains("execute_package_transaction("), "Python installer 必须通过单一事务 adapter 提交文件。")
	var godot_engine_source: String = _read_text(GODOT_ENGINE_PATH)
	var python_engine_source: String = _read_text(PYTHON_ENGINE_PATH)
	assert_true(godot_engine_source.contains("DirAccess.rename_absolute(active_root, cleanup_root)"), "Godot transaction cleanup 必须先原子移出 active 目录。")
	assert_true(python_engine_source.contains("os.rename(active_root, cleanup_root)"), "Python transaction cleanup 必须先原子移出 active 目录。")
	for marker: String in forbidden_godot_markers:
		assert_false(godot_backend_source.contains(marker), "Godot backend 不得重新引入旧事务实现：%s" % marker)
	for marker: String in forbidden_python_markers:
		assert_false(python_installer_source.contains(marker), "Python installer 不得重新引入旧事务实现：%s" % marker)


func test_package_transaction_engines_share_one_versioned_schema() -> void:
	var godot_engine_source: String = _read_text(GODOT_ENGINE_PATH)
	var python_engine_source: String = _read_text(PYTHON_ENGINE_PATH)
	var schema: Dictionary = _read_json(SHARED_SCHEMA_PATH)
	var required_report_fields: PackedStringArray = PackedStringArray([
		"schema_version",
		"ok",
		"transaction_id",
		"operation",
		"phase",
		"outcome",
		"write_count",
		"delete_count",
		"lockfile_written",
		"rolled_back",
		"recovered",
		"recovery_required",
		"issue_count",
		"issues",
		"warning_count",
		"warnings",
	])
	var schema_report_fields: PackedStringArray = _dictionary_string_array(schema, "report_fields")
	var schema_version: int = _dictionary_int(schema, "schema_version")
	var report_schema_version: int = _dictionary_int(schema, "report_schema_version")
	required_report_fields.sort()
	schema_report_fields.sort()

	assert_eq(schema_version, 1, "Package transaction journal schema 必须显式版本化。")
	assert_eq(report_schema_version, 1, "Package transaction report schema 必须显式版本化。")
	assert_eq(schema_report_fields, required_report_fields, "共享 schema 必须完整声明稳定事务报告字段。")
	assert_true(godot_engine_source.contains("gf_package_transaction_schema.json"), "Godot engine 必须读取共享 schema。")
	assert_true(python_engine_source.contains("gf_package_transaction_schema.json"), "Python engine 必须读取共享 schema。")


func test_package_cli_keeps_explicit_recovery_entry_points() -> void:
	var godot_cli_source: String = _read_text(GODOT_CLI_PATH)
	var python_installer_source: String = _read_text(PYTHON_INSTALLER_PATH)

	assert_true(godot_cli_source.contains("const COMMAND_RECOVER: String = \"recover\""), "Godot CLI 必须保留 recover 命令。")
	assert_true(godot_cli_source.contains("recover_package_transaction("), "Godot CLI recover 必须委托 backend。")
	assert_true(python_installer_source.contains("subparsers.add_parser(\"recover\""), "Python installer 必须保留 recover 命令。")
	assert_true(python_installer_source.contains("gf_package_transaction.recover_pending("), "Python recover 必须委托事务引擎。")


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
			var value: String = raw_value
			var _append_value: bool = result.append(value)
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
