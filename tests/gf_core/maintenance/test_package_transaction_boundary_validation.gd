extends GutTest


# --- 常量 ---

const SHARED_SCHEMA_PATH: String = "res://addons/gf/kernel/package/gf_package_transaction_schema.json"
const PYTHON_ENGINE_PATH: String = "res://tools/gf_package_transaction.py"
const PYTHON_INSTALLER_PATH: String = "res://tools/gf_package_installer.py"
const GF_PACKAGE_TRANSACTION_ENGINE = preload("res://addons/gf/kernel/package/gf_package_transaction_engine.gd")
const GF_PACKAGE_CLI = preload("res://addons/gf/kernel/package/gf_package_cli.gd")


# --- 测试用例 ---

func test_package_transaction_engine_owns_one_versioned_schema() -> void:
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
	required_report_fields.sort()
	schema_report_fields.sort()
	var schema_version_value: Variant = schema.get("schema_version")
	var report_schema_version_value: Variant = schema.get("report_schema_version")

	assert_true(schema_version_value is float, "Package transaction runtime journal schema 版本必须为数字。")
	if schema_version_value is float:
		var schema_version: float = schema_version_value
		assert_eq(schema_version, 1.0, "Package transaction runtime journal schema 版本必须为 1。")
	assert_true(report_schema_version_value is float, "Package transaction runtime report schema 版本必须为数字。")
	if report_schema_version_value is float:
		var report_schema_version: float = report_schema_version_value
		assert_eq(report_schema_version, 1.0, "Package transaction runtime report schema 版本必须为 1。")
	assert_eq(schema_report_fields, required_report_fields, "事务 schema 必须完整声明稳定报告字段。")


func test_package_cli_keeps_explicit_recovery_entry_points() -> void:
	assert_eq(GF_PACKAGE_CLI.COMMAND_RECOVER, "recover", "Godot CLI 必须保留 recover 命令。")
	assert_eq(GF_PACKAGE_CLI.COMMAND_INSTALL, "install", "Godot CLI 必须保留 install 命令。")
	assert_eq(GF_PACKAGE_CLI.COMMAND_UPDATE, "update", "Godot CLI 必须保留 update 命令。")
	assert_eq(GF_PACKAGE_CLI.COMMAND_UNINSTALL, "uninstall", "Godot CLI 必须保留 uninstall 命令。")
	var recover_report: Dictionary = GF_PACKAGE_TRANSACTION_ENGINE.make_empty_report("recover")
	var recovery_operation_value: Variant = recover_report.get("operation")
	assert_true(recovery_operation_value is String, "空恢复报告的 operation 必须为字符串。")
	if recovery_operation_value is String:
		assert_eq(str(recovery_operation_value), "recover")
	assert_false(FileAccess.file_exists(PYTHON_ENGINE_PATH), "不得恢复 Python 第二套 package transaction engine。")
	assert_false(FileAccess.file_exists(PYTHON_INSTALLER_PATH), "不得恢复 Python 第二套 package installer。")


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
