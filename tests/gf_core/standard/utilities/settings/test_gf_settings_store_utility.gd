# 测试 Settings Store 端口的不可用语义与 user:// 文件实现。
extends GutTest


# --- 常量 ---

const _OWNED_FILE_PREFIX: String = "gf-settings-store-test-"


# --- 私有变量 ---

var _owned_file_names: PackedStringArray = PackedStringArray()


# --- GUT 生命周期方法 ---

func after_each() -> void:
	for file_name: String in _owned_file_names:
		var is_owned_file: bool = (
			file_name.begins_with(_OWNED_FILE_PREFIX)
			and file_name == file_name.get_file()
		)
		assert_true(is_owned_file, "测试清理只能删除本例创建的 UUID basename。")
		if not is_owned_file:
			continue
		var path: String = "user://" + file_name
		if FileAccess.file_exists(path):
			var remove_error: Error = DirAccess.remove_absolute(path)
			assert_eq(remove_error, OK, "测试创建的 Settings Store 文件必须清理。")
	_owned_file_names.clear()


# --- 测试用例 ---

func test_base_store_returns_explicit_unavailable_results() -> void:
	_assert_explicitly_unavailable(GFSettingsStoreUtility.new(), "base Store")


func test_null_store_returns_explicit_unavailable_results() -> void:
	_assert_explicitly_unavailable(GFSettingsNullStoreUtility.new(), "Null Store")


func test_file_store_distinguishes_successful_empty_payload_from_missing_file() -> void:
	var store: GFSettingsFileStoreUtility = GFSettingsFileStoreUtility.new()
	var empty_file_name: String = _new_owned_file_name("empty")
	var missing_file_name: String = _new_owned_file_name("missing")

	assert_true(store.is_persistence_enabled(), "File Store 应声明同步持久化可用。")
	assert_eq(store.write_settings(empty_file_name, {}), OK, "空字典应作为合法载荷写入。")

	var empty_result: GFStorageReadResult = store.read_settings(empty_file_name)
	assert_true(empty_result.ok, "空字典文件必须是成功读取，不得误判为缺失。")
	assert_true(empty_result.payload.is_empty(), "成功空载荷应保持空字典。")
	assert_eq(empty_result.error_code, OK)
	assert_eq(empty_result.failure_kind, GFStorageReadResult.FailureKind.NONE)

	var missing_result: GFStorageReadResult = store.read_settings(missing_file_name)
	assert_false(missing_result.ok, "不存在的 UUID 文件必须返回明确失败。")
	assert_eq(missing_result.error_code, ERR_FILE_NOT_FOUND)
	assert_eq(missing_result.failure_kind, GFStorageReadResult.FailureKind.NOT_FOUND)


func test_file_store_classifies_corrupt_json() -> void:
	var store: GFSettingsFileStoreUtility = GFSettingsFileStoreUtility.new()
	var file_name: String = _new_owned_file_name("corrupt")
	assert_eq(_write_raw_file(file_name, "{not-json"), OK, "测试夹具应写入损坏 JSON。")

	var result: GFStorageReadResult = store.read_settings(file_name)

	assert_false(result.ok, "损坏 JSON 不得返回成功。")
	assert_eq(result.error_code, ERR_PARSE_ERROR)
	assert_eq(result.failure_kind, GFStorageReadResult.FailureKind.CORRUPT)


func test_file_store_rejects_unsafe_paths() -> void:
	var store: GFSettingsFileStoreUtility = GFSettingsFileStoreUtility.new()
	var unsafe_file_name: String = "../outside-%s.json" % GFUuid.generate_v4()

	var read_result: GFStorageReadResult = store.read_settings(unsafe_file_name)
	assert_push_error("[GFSettingsUtility] 已拒绝不安全设置文件名")
	assert_false(read_result.ok)
	assert_eq(read_result.error_code, ERR_INVALID_PARAMETER)
	assert_eq(read_result.failure_kind, GFStorageReadResult.FailureKind.INVALID_REQUEST)

	var write_error: Error = store.write_settings(unsafe_file_name, { "value": 1 })
	assert_push_error("[GFSettingsUtility] 已拒绝不安全设置文件名")
	assert_eq(write_error, ERR_INVALID_PARAMETER)


func test_file_store_write_and_read_are_isolated_by_json_boundary() -> void:
	var store: GFSettingsFileStoreUtility = GFSettingsFileStoreUtility.new()
	var file_name: String = _new_owned_file_name("isolated")
	var source_data: Dictionary = {
		"nested": { "value": 7 },
		"label": "persisted",
	}

	assert_eq(store.write_settings(file_name, source_data), OK)
	source_data["nested"] = { "value": 99 }
	source_data["label"] = "mutated-source"

	var first_result: GFStorageReadResult = store.read_settings(file_name)
	assert_true(first_result.ok)
	var first_nested: Dictionary = GFVariantData.get_option_dictionary(
		first_result.payload,
		"nested"
	)
	assert_eq(GFVariantData.get_option_int(first_nested, "value"), 7)
	assert_eq(GFVariantData.get_option_string(first_result.payload, "label"), "persisted")

	first_result.payload["nested"] = { "value": 123 }
	first_result.payload["label"] = "mutated-result"
	var second_result: GFStorageReadResult = store.read_settings(file_name)
	var second_nested: Dictionary = GFVariantData.get_option_dictionary(
		second_result.payload,
		"nested"
	)
	assert_true(second_result.ok)
	assert_eq(GFVariantData.get_option_int(second_nested, "value"), 7)
	assert_eq(GFVariantData.get_option_string(second_result.payload, "label"), "persisted")


# --- 私有/辅助方法 ---

func _assert_explicitly_unavailable(
	store: GFSettingsStoreUtility,
	store_label: String
) -> void:
	assert_false(store.is_persistence_enabled(), "%s 不得宣称持久化可用。" % store_label)
	var read_result: GFStorageReadResult = store.read_settings("settings.json")
	assert_false(read_result.ok, "%s 读取必须明确失败。" % store_label)
	assert_eq(read_result.error_code, ERR_UNAVAILABLE)
	assert_eq(read_result.failure_kind, GFStorageReadResult.FailureKind.UNAVAILABLE)
	assert_eq(
		store.write_settings("settings.json", {}),
		ERR_UNAVAILABLE,
		"%s 写入必须返回 ERR_UNAVAILABLE。" % store_label
	)


func _new_owned_file_name(label: String) -> String:
	var file_name: String = "%s%s-%s.json" % [
		_OWNED_FILE_PREFIX,
		label,
		GFUuid.generate_v4(),
	]
	var _appended: bool = _owned_file_names.append(file_name)
	return file_name


func _write_raw_file(file_name: String, content: String) -> Error:
	var file: FileAccess = FileAccess.open("user://" + file_name, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored: bool = file.store_string(content)
	var write_error: Error = file.get_error()
	file.close()
	if stored and write_error == OK:
		return OK
	return write_error if write_error != OK else ERR_FILE_CANT_WRITE
