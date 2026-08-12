## 测试 GFSettingsUtility 与 GFSettingDefinition 的设置注册、类型钳制和序列化行为。
extends GutTest


# --- 私有变量 ---

var _settings: GFSettingsUtility
var _fallback_file_names: PackedStringArray = PackedStringArray()


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_settings = GFSettingsUtility.new()
	_settings.auto_load_on_init = false
	_settings.auto_save_on_change = false
	_settings.init()


func after_each() -> void:
	if _settings != null:
		_settings.dispose()
		_settings = null
	for file_name: String in _fallback_file_names:
		var path: String = "user://" + file_name
		if FileAccess.file_exists(path):
			var _remove_error: Error = DirAccess.remove_absolute(path)
	_fallback_file_names.clear()


# --- 测试方法 ---

func test_register_setting_applies_default_and_coerces_values() -> void:
	var _register_setting_result_28: Variant = _settings.register_setting(&"gameplay/max_lives", 3, GFSettingDefinition.ValueType.INT)
	_settings.set_value(&"gameplay/max_lives", "5")

	assert_eq(_setting_int(_settings, &"gameplay/max_lives"), 5, "设置值应按定义转换为 int。")


func test_string_settings_accept_non_string_values() -> void:
	var _register_setting_result_35: Variant = _settings.register_setting(&"profile/slot", "", GFSettingDefinition.ValueType.STRING)
	var _register_setting_result_36: Variant = _settings.register_setting(&"profile/tag", &"", GFSettingDefinition.ValueType.STRING_NAME)
	_settings.set_value(&"profile/slot", 42)
	_settings.set_value(&"profile/tag", 7)

	assert_eq(_setting_text(_settings, &"profile/slot"), "42", "字符串设置应使用安全字符串化。")
	assert_eq(_setting_string_name(_settings, &"profile/tag"), &"7", "StringName 设置应使用安全字符串化。")


func test_register_definition_coerces_preloaded_value() -> void:
	_settings.replace_from_dict({
		"display/window_size": {
			"__gf_setting_type": "Vector2",
			"x": 1280,
			"y": 720,
		},
	}, false)
	var _register_setting_result_52: Variant = _settings.register_setting(
		&"display/window_size",
		Vector2i(800, 600),
		GFSettingDefinition.ValueType.VECTOR2I
	)

	assert_eq(_setting_vector2i(_settings, &"display/window_size"), Vector2i(1280, 720), "后注册定义时应钳制已加载值。")


func test_to_dict_skips_non_persistent_definitions() -> void:
	var _register_setting_result_62: Variant = _settings.register_setting(&"runtime/debug", true, GFSettingDefinition.ValueType.BOOL, false)
	var _register_setting_result_63: Variant = _settings.register_setting(&"audio/master", 0.5, GFSettingDefinition.ValueType.FLOAT, true)

	var data: Dictionary = _settings.to_dict(true)

	assert_false(data.has("runtime/debug"), "非持久化设置不应写入持久化字典。")
	assert_true(data.has("audio/master"), "持久化设置应写入持久化字典。")


func test_serialized_values_roundtrip_structured_types() -> void:
	var _register_setting_result_72: Variant = _settings.register_setting(&"video/size", Vector2i.ZERO, GFSettingDefinition.ValueType.VECTOR2I)
	var _register_setting_result_73: Variant = _settings.register_setting(&"ui/accent", Color.WHITE, GFSettingDefinition.ValueType.COLOR)
	_settings.set_value(&"video/size", Vector2(1024.4, 768.6))
	_settings.set_value(&"ui/accent", Color(0.25, 0.5, 0.75, 1.0))

	var restored: GFSettingsUtility = GFSettingsUtility.new()
	restored.auto_load_on_init = false
	restored.auto_save_on_change = false
	restored.init()
	restored.replace_from_dict(_settings.to_dict(true), false)
	var _register_setting_result_82: Variant = restored.register_setting(&"video/size", Vector2i.ZERO, GFSettingDefinition.ValueType.VECTOR2I)
	var _register_setting_result_83: Variant = restored.register_setting(&"ui/accent", Color.WHITE, GFSettingDefinition.ValueType.COLOR)

	assert_eq(_setting_vector2i(restored, &"video/size"), Vector2i(1024, 769), "Vector2i 设置应可序列化往返。")
	assert_eq(_setting_color(restored, &"ui/accent"), Color(0.25, 0.5, 0.75, 1.0), "Color 设置应可序列化往返。")
	restored.dispose()


func test_serialized_settings_preserve_unsafe_int64_values_through_json() -> void:
	var large_revision: int = 9_007_199_254_740_993
	var _register_setting_result_92: Variant = _settings.register_setting(&"sync/revision", 0, GFSettingDefinition.ValueType.INT)
	_settings.set_value(&"sync/revision", large_revision)

	var parsed: Dictionary = GFVariantData.as_dictionary(JSON.parse_string(JSON.stringify(_settings.to_dict(true))))
	var restored: GFSettingsUtility = GFSettingsUtility.new()
	restored.auto_load_on_init = false
	restored.auto_save_on_change = false
	restored.init()
	restored.replace_from_dict(parsed, false)
	var _register_setting_result_101: Variant = restored.register_setting(&"sync/revision", 0, GFSettingDefinition.ValueType.INT)

	assert_eq(_setting_int(restored, &"sync/revision"), large_revision, "持久化设置中的大整数应精确往返 JSON。")
	restored.dispose()


func test_dictionary_values_may_use_setting_type_key_as_data() -> void:
	var payload: Dictionary = {
		"__gf_setting_type": "Color",
		"value": "business-data",
	}
	var _register_setting_result: Variant = _settings.register_setting(&"meta/payload", {}, GFSettingDefinition.ValueType.DICTIONARY)
	_settings.set_value(&"meta/payload", payload)

	var restored: GFSettingsUtility = GFSettingsUtility.new()
	restored.auto_load_on_init = false
	restored.auto_save_on_change = false
	restored.init()
	restored.replace_from_dict(_settings.to_dict(true), false)
	var _restored_register_result: Variant = restored.register_setting(&"meta/payload", {}, GFSettingDefinition.ValueType.DICTIONARY)
	var restored_payload: Dictionary = GFVariantData.as_dictionary(restored.get_value(&"meta/payload"))

	assert_eq(GFVariantData.get_option_string(restored_payload, "__gf_setting_type"), "Color", "业务字典中的 marker 字段应保留为普通字段。")
	assert_eq(GFVariantData.get_option_string(restored_payload, "value"), "business-data", "业务字典字段不应被类型包装解析吞掉。")
	restored.dispose()


func test_dictionary_settings_preserve_non_string_key_collisions() -> void:
	var payload: Dictionary = {
		1: "integer-key",
		"1": "string-key",
	}
	var _register_setting_result: Variant = _settings.register_setting(&"meta/keyed_payload", {}, GFSettingDefinition.ValueType.DICTIONARY)
	_settings.set_value(&"meta/keyed_payload", payload)

	var restored: GFSettingsUtility = GFSettingsUtility.new()
	restored.auto_load_on_init = false
	restored.auto_save_on_change = false
	restored.init()
	restored.replace_from_dict(_settings.to_dict(true), false)
	var _restored_register_result: Variant = restored.register_setting(&"meta/keyed_payload", {}, GFSettingDefinition.ValueType.DICTIONARY)
	var restored_payload: Dictionary = GFVariantData.as_dictionary(restored.get_value(&"meta/keyed_payload"))

	assert_eq(GFVariantData.get_option_string(restored_payload, 1), "integer-key", "整数 key 应无损往返。")
	assert_eq(GFVariantData.get_option_string(restored_payload, "1"), "string-key", "字符串 key 不应覆盖整数 key。")
	restored.dispose()


func test_replace_and_merge_restore_have_explicit_missing_key_semantics() -> void:
	var _register_master: Variant = _settings.register_setting(&"audio/master", 1.0, GFSettingDefinition.ValueType.FLOAT)
	var _register_music: Variant = _settings.register_setting(&"audio/music", 0.8, GFSettingDefinition.ValueType.FLOAT)
	_settings.set_value(&"audio/master", 0.2, false)
	_settings.set_value(&"audio/music", 0.3, false)
	_settings.set_value(&"legacy/flag", true, false)

	_settings.merge_from_dict({"audio/master": 0.4}, false)
	assert_eq(_setting_float(_settings, &"audio/music"), 0.3, "merge 应保留输入中缺失的当前值。")
	assert_true(_settings.has_setting(&"legacy/flag"), "merge 不应删除未定义的覆盖层值。")

	_settings.replace_from_dict({"audio/master": 0.6}, false)
	assert_eq(_setting_float(_settings, &"audio/master"), 0.6, "replace 应恢复输入值。")
	assert_eq(_setting_float(_settings, &"audio/music"), 0.8, "replace 应把缺失的已定义键恢复为默认值。")
	assert_false(_settings.has_setting(&"legacy/flag"), "replace 应移除输入中缺失的未定义旧键。")


func test_load_settings_uses_replace_semantics() -> void:
	var settings: LoadedSettingsUtility = LoadedSettingsUtility.new()
	settings.auto_load_on_init = false
	settings.auto_save_on_change = false
	settings.init()
	var _register_master: Variant = settings.register_setting(&"audio/master", 1.0, GFSettingDefinition.ValueType.FLOAT)
	var _register_music: Variant = settings.register_setting(&"audio/music", 0.8, GFSettingDefinition.ValueType.FLOAT)
	settings.set_value(&"audio/master", 0.2, false)
	settings.set_value(&"audio/music", 0.3, false)
	settings.loaded_data = {"audio/master": 0.5}

	var load_result: GFSettingsLoadResult = settings.load_settings("profile.json")
	var storage_result: GFStorageReadResult = load_result.get_storage_result()

	assert_true(load_result.is_successful(), "合法持久化数据应进入成功终态。")
	assert_eq(load_result.get_status(), GFSettingsLoadResult.STATUS_LOADED, "成功读取应报告 loaded。")
	assert_true(load_result.was_applied(), "成功读取应应用持久化设置。")
	assert_false(load_result.was_recovered(), "普通成功读取不应标记为恢复。")
	assert_not_null(storage_result, "Settings 结果应保留底层 Storage 结果。")
	assert_true(storage_result.ok, "底层读取应保持成功证据。")
	assert_eq(_setting_float(settings, &"audio/master"), 0.5, "load 应应用持久化值。")
	assert_eq(_setting_float(settings, &"audio/music"), 0.8, "load 应重置持久化数据中缺失的已定义键。")
	settings.dispose()


func test_load_settings_treats_successful_empty_payload_as_loaded_replace() -> void:
	var settings: ScriptedSettingsUtility = _make_scripted_settings(
		GFStorageReadResult.new().configure_success({})
	)
	var _register_master: Variant = settings.register_setting(
		&"audio/master",
		1.0,
		GFSettingDefinition.ValueType.FLOAT
	)
	settings.set_value(&"audio/master", 0.25, false)
	settings.set_value(&"legacy/flag", true, false)
	settings.stage_value(&"audio/master", 0.75)

	var load_result: GFSettingsLoadResult = settings.load_settings("empty.json")
	var storage_result: GFStorageReadResult = load_result.get_storage_result()

	assert_true(load_result.is_successful(), "合法空载荷仍应是成功读取。")
	assert_eq(load_result.get_status(), GFSettingsLoadResult.STATUS_LOADED, "合法空载荷不得被误判为 missing。")
	assert_true(load_result.was_applied(), "合法空载荷应执行 replace 语义。")
	assert_false(load_result.was_recovered(), "合法空载荷不应经过恢复策略。")
	assert_not_null(storage_result, "结果应保留合法空载荷的底层读取证据。")
	assert_true(storage_result.ok, "底层空载荷读取应保持 ok。")
	assert_true(storage_result.payload.is_empty(), "底层载荷应保持合法空字典。")
	assert_eq(_setting_float(settings, &"audio/master"), 1.0, "空载荷应把已定义键恢复默认值。")
	assert_false(settings.has_setting(&"legacy/flag"), "空载荷应移除未定义的旧键。")
	assert_false(settings.has_staged_values(), "成功 replace 后不应保留旧 staged 值。")
	assert_eq(settings.write_count, 0, "读取合法空载荷不应产生保存副作用。")
	settings.dispose()


func test_load_settings_strict_missing_preserves_current_and_staged_state() -> void:
	var settings: ScriptedSettingsUtility = _make_scripted_settings(
		_make_storage_failure(
			GFStorageReadResult.FailureKind.NOT_FOUND,
			ERR_FILE_NOT_FOUND,
			"Settings file not found."
		)
	)
	var _register_master: Variant = settings.register_setting(
		&"audio/master",
		1.0,
		GFSettingDefinition.ValueType.FLOAT
	)
	settings.set_value(&"audio/master", 0.25, false)
	settings.set_value(&"runtime/marker", "current", false)
	settings.stage_value(&"audio/master", 0.75)
	var values_before: Dictionary = settings.to_dict(false)
	var staged_before: Dictionary = settings.get_staged_values()
	watch_signals(settings)

	var load_result: GFSettingsLoadResult = settings.load_settings("missing.json")
	var storage_result: GFStorageReadResult = load_result.get_storage_result()

	assert_false(load_result.is_successful(), "默认策略下缺失文件应严格失败。")
	assert_eq(load_result.get_status(), GFSettingsLoadResult.STATUS_MISSING, "缺失文件应保留稳定状态。")
	assert_false(load_result.was_applied(), "严格失败不得应用空载荷。")
	assert_false(load_result.was_recovered(), "未提供策略时不得自动恢复。")
	assert_not_null(storage_result, "失败结果应保留底层 Storage 证据。")
	assert_eq(storage_result.failure_kind, GFStorageReadResult.FailureKind.NOT_FOUND)
	assert_eq(settings.to_dict(false), values_before, "缺失文件失败不得修改当前设置。")
	assert_eq(settings.get_staged_values(), staged_before, "缺失文件失败不得清除 staged 设置。")
	assert_eq(settings.write_count, 0, "缺失文件失败不得创建或覆盖文件。")
	assert_signal_emitted(settings, "settings_load_completed", "失败读取也应发出类型化终态信号。")
	assert_signal_not_emitted(settings, "setting_changed", "严格失败不得发出设置变化。")
	settings.dispose()


func test_load_settings_cancels_stale_batch_save_across_sources() -> void:
	var settings: ScriptedSettingsUtility = _make_scripted_settings(
		_make_storage_failure(
			GFStorageReadResult.FailureKind.NOT_FOUND,
			ERR_FILE_NOT_FOUND,
			"Settings file not found."
		)
	)
	settings.storage_file_name = "missing.json"
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 0.0
	var _register_master: Variant = settings.register_setting(
		&"audio/master",
		1.0,
		GFSettingDefinition.ValueType.FLOAT
	)
	settings.begin_batch()
	settings.set_value(&"audio/master", 0.25)

	var load_result: GFSettingsLoadResult = settings.load_settings("other_missing.json")
	settings.end_batch()

	assert_false(load_result.is_successful(), "严格缺失仍应失败。")
	assert_eq(settings.write_count, 0, "加载屏障应取消其他源尚未形成的批处理自动保存。")
	settings.dispose()


func test_load_settings_cancels_queued_save_before_replacing_from_other_source() -> void:
	var settings: ScriptedSettingsUtility = _make_scripted_settings(
		GFStorageReadResult.new().configure_success({"audio/master": 0.8})
	)
	settings.storage_file_name = "source_a.json"
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 10.0
	var _register_master: Variant = settings.register_setting(
		&"audio/master",
		1.0,
		GFSettingDefinition.ValueType.FLOAT
	)
	settings.set_value(&"audio/master", 0.25)

	var load_result: GFSettingsLoadResult = settings.load_settings("source_b.json")
	settings.tick(20.0)

	assert_true(load_result.is_successful(), "第二来源的合法设置应加载成功。")
	assert_eq(_setting_float(settings, &"audio/master"), 0.8)
	assert_eq(
		settings.write_count,
		0,
		"加载后的值不得被陈旧队列重新序列化并写回先前来源。"
	)
	settings.dispose()


func test_load_settings_strict_corrupt_preserves_current_and_staged_state() -> void:
	var settings: ScriptedSettingsUtility = _make_scripted_settings(
		_make_storage_failure(
			GFStorageReadResult.FailureKind.CORRUPT,
			ERR_FILE_CORRUPT,
			"Settings payload is corrupt."
		)
	)
	var _register_master: Variant = settings.register_setting(
		&"audio/master",
		1.0,
		GFSettingDefinition.ValueType.FLOAT
	)
	settings.set_value(&"audio/master", 0.4, false)
	settings.set_value(&"runtime/marker", "current", false)
	settings.stage_value(&"audio/master", 0.8)
	var values_before: Dictionary = settings.to_dict(false)
	var staged_before: Dictionary = settings.get_staged_values()

	var load_result: GFSettingsLoadResult = settings.load_settings("corrupt.json")
	var storage_result: GFStorageReadResult = load_result.get_storage_result()

	assert_false(load_result.is_successful(), "默认策略下损坏文件应严格失败。")
	assert_eq(load_result.get_status(), GFSettingsLoadResult.STATUS_CORRUPT, "损坏文件应保留稳定状态。")
	assert_false(load_result.was_applied(), "损坏文件不得被降级为空载荷应用。")
	assert_false(load_result.was_recovered(), "未提供策略时不得自动恢复损坏文件。")
	assert_not_null(storage_result, "损坏结果应保留底层 Storage 证据。")
	assert_eq(storage_result.failure_kind, GFStorageReadResult.FailureKind.CORRUPT)
	assert_eq(settings.to_dict(false), values_before, "损坏文件失败不得修改当前设置。")
	assert_eq(settings.get_staged_values(), staged_before, "损坏文件失败不得清除 staged 设置。")
	assert_eq(settings.write_count, 0, "损坏文件失败不得覆盖原文件。")
	settings.dispose()


func test_load_settings_can_explicitly_recover_missing_with_current_state() -> void:
	var settings: ScriptedSettingsUtility = _make_scripted_settings(
		_make_storage_failure(
			GFStorageReadResult.FailureKind.NOT_FOUND,
			ERR_FILE_NOT_FOUND,
			"Settings file not found."
		)
	)
	var _register_master: Variant = settings.register_setting(
		&"audio/master",
		1.0,
		GFSettingDefinition.ValueType.FLOAT
	)
	settings.set_value(&"audio/master", 0.35, false)
	settings.set_value(&"runtime/marker", "current", false)
	settings.stage_value(&"audio/master", 0.7)
	var values_before: Dictionary = settings.to_dict(false)
	var staged_before: Dictionary = settings.get_staged_values()
	var policy: GFSettingsRecoveryPolicy = GFSettingsRecoveryPolicy.new()
	policy.missing_file_action = GFSettingsRecoveryPolicy.ACTION_USE_CURRENT_STATE

	var load_result: GFSettingsLoadResult = settings.load_settings("missing.json", policy)

	assert_true(load_result.is_successful(), "显式接受当前状态应形成成功恢复终态。")
	assert_eq(load_result.get_status(), GFSettingsLoadResult.STATUS_RECOVERED)
	assert_false(load_result.was_applied(), "保留当前状态不应应用替代载荷。")
	assert_true(load_result.was_recovered(), "结果应记录恢复动作。")
	assert_eq(
		load_result.get_recovery_action(),
		GFSettingsRecoveryPolicy.ACTION_USE_CURRENT_STATE
	)
	assert_eq(settings.to_dict(false), values_before, "保留当前状态不得修改有效设置。")
	assert_eq(settings.get_staged_values(), staged_before, "保留当前状态不得清除 staged 设置。")
	assert_eq(settings.write_count, 0, "显式接受当前状态仍不得自动保存。")
	settings.dispose()


func test_load_settings_can_explicitly_recover_corrupt_with_defaults_without_saving() -> void:
	var settings: ScriptedSettingsUtility = _make_scripted_settings(
		_make_storage_failure(
			GFStorageReadResult.FailureKind.CORRUPT,
			ERR_FILE_CORRUPT,
			"Settings payload is corrupt."
		)
	)
	var _register_master: Variant = settings.register_setting(
		&"audio/master",
		1.0,
		GFSettingDefinition.ValueType.FLOAT
	)
	settings.set_value(&"audio/master", 0.2, false)
	settings.set_value(&"legacy/flag", true, false)
	settings.stage_value(&"audio/master", 0.8)
	var policy: GFSettingsRecoveryPolicy = GFSettingsRecoveryPolicy.new()
	policy.corrupt_file_action = GFSettingsRecoveryPolicy.ACTION_RESET_TO_DEFAULTS

	var load_result: GFSettingsLoadResult = settings.load_settings("corrupt.json", policy)
	var storage_result: GFStorageReadResult = load_result.get_storage_result()

	assert_true(load_result.is_successful(), "显式默认值恢复应形成成功终态。")
	assert_eq(load_result.get_status(), GFSettingsLoadResult.STATUS_RECOVERED)
	assert_true(load_result.was_applied(), "默认值恢复应应用空 replace 语义。")
	assert_true(load_result.was_recovered(), "结果应记录恢复动作。")
	assert_eq(
		load_result.get_recovery_action(),
		GFSettingsRecoveryPolicy.ACTION_RESET_TO_DEFAULTS
	)
	assert_not_null(storage_result, "恢复结果仍应保留原始损坏证据。")
	assert_eq(storage_result.failure_kind, GFStorageReadResult.FailureKind.CORRUPT)
	assert_eq(_setting_float(settings, &"audio/master"), 1.0, "恢复应重置已定义设置。")
	assert_false(settings.has_setting(&"legacy/flag"), "恢复应移除未定义旧设置。")
	assert_false(settings.has_staged_values(), "默认值恢复应清除旧 staged 设置。")
	assert_eq(settings.write_count, 0, "默认值恢复不得隐式覆盖损坏文件。")
	settings.dispose()


func test_settings_recovery_policy_defaults_to_strict_and_rejects_unknown_actions() -> void:
	var policy: GFSettingsRecoveryPolicy = GFSettingsRecoveryPolicy.new()

	assert_eq(policy.missing_file_action, GFSettingsRecoveryPolicy.ACTION_FAIL)
	assert_eq(policy.corrupt_file_action, GFSettingsRecoveryPolicy.ACTION_FAIL)
	assert_true(
		GFVariantData.get_option_bool(policy.validate_policy(), "ok", false),
		"默认策略应是合法的严格策略。"
	)

	policy.corrupt_file_action = &"overwrite_source"
	var invalid_report: Dictionary = policy.validate_policy()

	assert_false(
		GFVariantData.get_option_bool(invalid_report, "ok", true),
		"未知动作不得被恢复策略接受。"
	)
	assert_eq(
		GFVariantData.get_option_int(invalid_report, "error_count"),
		1,
		"无效动作应形成结构化校验问题。"
	)


func test_load_settings_rejects_invalid_recovery_policy_before_storage_read() -> void:
	var settings: ScriptedSettingsUtility = _make_scripted_settings(
		GFStorageReadResult.new().configure_success({"audio/master": 0.1})
	)
	var _register_master: Variant = settings.register_setting(
		&"audio/master",
		1.0,
		GFSettingDefinition.ValueType.FLOAT
	)
	settings.set_value(&"audio/master", 0.45, false)
	settings.stage_value(&"audio/master", 0.9)
	var values_before: Dictionary = settings.to_dict(false)
	var staged_before: Dictionary = settings.get_staged_values()
	var policy: GFSettingsRecoveryPolicy = GFSettingsRecoveryPolicy.new()
	policy.corrupt_file_action = &"overwrite_source"
	watch_signals(settings)

	var load_result: GFSettingsLoadResult = settings.load_settings(
		"profile.json",
		policy
	)
	var storage_result: GFStorageReadResult = load_result.get_storage_result()

	assert_false(load_result.is_successful(), "无效恢复策略必须形成失败终态。")
	assert_eq(load_result.get_status(), GFSettingsLoadResult.STATUS_INVALID_REQUEST)
	assert_eq(load_result.get_error_code(), ERR_INVALID_PARAMETER)
	assert_not_null(storage_result)
	assert_eq(
		storage_result.failure_kind,
		GFStorageReadResult.FailureKind.INVALID_REQUEST
	)
	assert_eq(settings.read_count, 0, "无效策略不得触发底层读取。")
	assert_eq(settings.to_dict(false), values_before)
	assert_eq(settings.get_staged_values(), staged_before)
	assert_signal_emitted(settings, "settings_load_completed")
	settings.dispose()


func test_settings_load_result_rejects_status_storage_mismatch() -> void:
	var missing_storage: GFStorageReadResult = _make_storage_failure(
		GFStorageReadResult.FailureKind.NOT_FOUND,
		ERR_FILE_NOT_FOUND,
		"Settings file not found."
	)
	var load_result: GFSettingsLoadResult = GFSettingsLoadResult.new()

	var configured: bool = load_result.configure_for_framework(
		false,
		GFSettingsLoadResult.STATUS_CORRUPT,
		"profile.json",
		false,
		false,
		&"",
		ERR_FILE_CORRUPT,
		"Settings payload is corrupt.",
		missing_storage
	)

	assert_false(configured, "终态 status 必须与底层 Storage 失败分类一致。")
	assert_push_error("[GFSettingsLoadResult] 已拒绝不一致的加载终态配置。")


func test_load_settings_never_recovers_non_recoverable_failure_kinds() -> void:
	var failure_kinds: Array[GFStorageReadResult.FailureKind] = [
		GFStorageReadResult.FailureKind.INVALID_REQUEST,
		GFStorageReadResult.FailureKind.IO_FAILED,
		GFStorageReadResult.FailureKind.FUTURE_VERSION,
		GFStorageReadResult.FailureKind.MIGRATION_FAILED,
		GFStorageReadResult.FailureKind.UNAVAILABLE,
	]
	var error_codes: Array[Error] = [
		ERR_INVALID_PARAMETER,
		ERR_FILE_CANT_OPEN,
		ERR_FILE_UNRECOGNIZED,
		ERR_INVALID_DATA,
		ERR_UNAVAILABLE,
	]
	var expected_statuses: Array[StringName] = [
		GFSettingsLoadResult.STATUS_INVALID_REQUEST,
		GFSettingsLoadResult.STATUS_STORAGE_FAILED,
		GFSettingsLoadResult.STATUS_FUTURE_SCHEMA,
		GFSettingsLoadResult.STATUS_MIGRATION_FAILED,
		GFSettingsLoadResult.STATUS_STORAGE_FAILED,
	]
	var settings: ScriptedSettingsUtility = _make_scripted_settings(
		_make_storage_failure(failure_kinds[0], error_codes[0], "Load failed.")
	)
	var _register_master: Variant = settings.register_setting(
		&"audio/master",
		1.0,
		GFSettingDefinition.ValueType.FLOAT
	)
	settings.set_value(&"audio/master", 0.45, false)
	settings.stage_value(&"audio/master", 0.9)
	var values_before: Dictionary = settings.to_dict(false)
	var staged_before: Dictionary = settings.get_staged_values()
	var policy: GFSettingsRecoveryPolicy = GFSettingsRecoveryPolicy.new()
	policy.missing_file_action = GFSettingsRecoveryPolicy.ACTION_RESET_TO_DEFAULTS
	policy.corrupt_file_action = GFSettingsRecoveryPolicy.ACTION_RESET_TO_DEFAULTS

	for index: int in range(failure_kinds.size()):
		settings.read_result = _make_storage_failure(
			failure_kinds[index],
			error_codes[index],
			"Load failed."
		)
		var load_result: GFSettingsLoadResult = settings.load_settings(
			"unrecoverable_%d.json" % index,
			policy
		)

		assert_false(load_result.is_successful(), "不可恢复失败不能被 missing/corrupt 策略接受。")
		assert_eq(load_result.get_status(), expected_statuses[index])
		assert_false(load_result.was_applied(), "不可恢复失败不得应用默认值。")
		assert_false(load_result.was_recovered(), "不可恢复失败不得标记为 recovered。")
		assert_eq(settings.to_dict(false), values_before, "不可恢复失败不得修改有效设置。")
		assert_eq(settings.get_staged_values(), staged_before, "不可恢复失败不得清除 staged 设置。")

	assert_eq(settings.write_count, 0, "不可恢复失败不得产生保存副作用。")
	settings.dispose()


func test_load_settings_rejects_unaccepted_integrity_even_when_storage_read_is_ok() -> void:
	var read_result: GFStorageReadResult = GFStorageReadResult.new().configure_success(
		{"audio/master": 0.1},
		{},
		GFStorageReadResult.IntegrityStatus.INVALID
	)
	var settings: ScriptedSettingsUtility = _make_scripted_settings(read_result)
	var _register_master: Variant = settings.register_setting(
		&"audio/master",
		1.0,
		GFSettingDefinition.ValueType.FLOAT
	)
	settings.set_value(&"audio/master", 0.55, false)
	settings.stage_value(&"audio/master", 0.9)
	var values_before: Dictionary = settings.to_dict(false)
	var staged_before: Dictionary = settings.get_staged_values()

	var load_result: GFSettingsLoadResult = settings.load_settings("invalid_integrity.json")
	var stored_read_result: GFStorageReadResult = load_result.get_storage_result()

	assert_false(load_result.is_successful(), "未接受的完整性状态不得应用。")
	assert_eq(load_result.get_status(), GFSettingsLoadResult.STATUS_CORRUPT)
	assert_false(load_result.was_applied(), "完整性失败不得应用底层 payload。")
	assert_not_null(stored_read_result, "结果应保留底层完整性证据。")
	assert_true(stored_read_result.ok, "底层非严格 codec 的 ok 证据不应被改写。")
	assert_eq(
		stored_read_result.integrity_status,
		GFStorageReadResult.IntegrityStatus.INVALID
	)
	assert_eq(settings.to_dict(false), values_before, "完整性失败不得修改有效设置。")
	assert_eq(settings.get_staged_values(), staged_before, "完整性失败不得清除 staged 设置。")
	assert_eq(settings.write_count, 0, "完整性失败不得自动覆盖文件。")
	settings.dispose()


func test_load_settings_signal_and_last_result_are_defensive_copies() -> void:
	var settings: ScriptedSettingsUtility = _make_scripted_settings(
		GFStorageReadResult.new().configure_success({"audio/master": 0.4})
	)
	var _register_master: Variant = settings.register_setting(
		&"audio/master",
		1.0,
		GFSettingDefinition.ValueType.FLOAT
	)
	watch_signals(settings)

	var returned_result: GFSettingsLoadResult = settings.load_settings("profile.json")
	var signal_parameters: Array = get_signal_parameters(settings, "settings_load_completed")
	var signal_value: Variant = signal_parameters[0] if not signal_parameters.is_empty() else null
	var first_last_result: GFSettingsLoadResult = settings.get_last_load_result()
	var second_last_result: GFSettingsLoadResult = settings.get_last_load_result()

	assert_signal_emitted(settings, "settings_load_completed")
	assert_true(signal_value is GFSettingsLoadResult, "完成信号应携带类型化结果。")
	assert_not_null(first_last_result, "最近读取结果应可观察。")
	assert_not_null(second_last_result, "重复读取最近结果应继续可用。")
	assert_false(is_same(returned_result, first_last_result), "last result 不应暴露返回对象身份。")
	assert_false(is_same(first_last_result, second_last_result), "每次查询应返回隔离结果。")
	if signal_value is GFSettingsLoadResult:
		var signal_result: GFSettingsLoadResult = signal_value
		assert_false(is_same(returned_result, signal_result), "信号应发送隔离结果副本。")
		assert_eq(signal_result.get_status(), GFSettingsLoadResult.STATUS_LOADED)

	var mutable_storage_copy: GFStorageReadResult = returned_result.get_storage_result()
	mutable_storage_copy.payload["audio/master"] = 0.95
	var observed_storage_copy: GFStorageReadResult = first_last_result.get_storage_result()
	var result_summary: Dictionary = returned_result.to_dict()
	var storage_summary: Dictionary = GFVariantData.get_option_dictionary(
		result_summary,
		"storage_result"
	)
	assert_eq(
		GFVariantData.get_option_float(observed_storage_copy.payload, "audio/master"),
		0.4,
		"修改调用方取得的 Storage 副本不得污染 last result。"
	)
	assert_false(storage_summary.has("payload"), "可报告结果摘要不得泄露设置载荷。")
	settings.dispose()


func test_fallback_load_classifies_missing_corrupt_and_successful_empty_payloads() -> void:
	var _register_master: Variant = _settings.register_setting(
		&"audio/master",
		1.0,
		GFSettingDefinition.ValueType.FLOAT
	)
	_settings.set_value(&"audio/master", 0.3, false)
	_settings.stage_value(&"audio/master", 0.8)
	var values_before: Dictionary = _settings.to_dict(false)
	var staged_before: Dictionary = _settings.get_staged_values()
	var missing_file: String = _new_fallback_file_name("missing")

	var missing_result: GFSettingsLoadResult = _settings.load_settings(missing_file)
	var missing_storage: GFStorageReadResult = missing_result.get_storage_result()

	assert_eq(missing_result.get_status(), GFSettingsLoadResult.STATUS_MISSING)
	assert_eq(missing_storage.failure_kind, GFStorageReadResult.FailureKind.NOT_FOUND)
	assert_eq(_settings.to_dict(false), values_before, "fallback 缺失失败不得修改当前值。")
	assert_eq(_settings.get_staged_values(), staged_before, "fallback 缺失失败不得清 staged。")

	var empty_file: String = _new_fallback_file_name("empty")
	_write_fallback_text(empty_file, "")
	var empty_result: GFSettingsLoadResult = _settings.load_settings(empty_file)
	var empty_storage: GFStorageReadResult = empty_result.get_storage_result()

	assert_eq(empty_result.get_status(), GFSettingsLoadResult.STATUS_CORRUPT)
	assert_eq(empty_storage.failure_kind, GFStorageReadResult.FailureKind.CORRUPT)
	assert_eq(_settings.to_dict(false), values_before, "空文件不得被降级为合法空载荷。")
	assert_eq(_settings.get_staged_values(), staged_before, "空文件失败不得清 staged。")

	var malformed_file: String = _new_fallback_file_name("malformed")
	_write_fallback_text(malformed_file, "{invalid")
	var malformed_result: GFSettingsLoadResult = _settings.load_settings(malformed_file)
	var malformed_storage: GFStorageReadResult = malformed_result.get_storage_result()

	assert_eq(malformed_result.get_status(), GFSettingsLoadResult.STATUS_CORRUPT)
	assert_eq(malformed_storage.failure_kind, GFStorageReadResult.FailureKind.CORRUPT)
	assert_eq(_settings.to_dict(false), values_before, "解析失败不得修改当前值。")
	assert_eq(_settings.get_staged_values(), staged_before, "解析失败不得清 staged。")

	var non_dictionary_file: String = _new_fallback_file_name("array")
	_write_fallback_text(non_dictionary_file, "[]")
	var non_dictionary_result: GFSettingsLoadResult = _settings.load_settings(non_dictionary_file)
	var non_dictionary_storage: GFStorageReadResult = non_dictionary_result.get_storage_result()

	assert_eq(non_dictionary_result.get_status(), GFSettingsLoadResult.STATUS_CORRUPT)
	assert_eq(non_dictionary_storage.failure_kind, GFStorageReadResult.FailureKind.CORRUPT)
	assert_eq(_settings.to_dict(false), values_before, "非 Dictionary JSON 不得当作合法空设置。")
	assert_eq(_settings.get_staged_values(), staged_before, "非 Dictionary JSON 不得清 staged。")

	var valid_empty_file: String = _new_fallback_file_name("valid_empty")
	_write_fallback_text(valid_empty_file, "{}")
	var valid_empty_result: GFSettingsLoadResult = _settings.load_settings(valid_empty_file)
	var valid_empty_storage: GFStorageReadResult = valid_empty_result.get_storage_result()

	assert_true(valid_empty_result.is_successful(), "合法空 JSON 对象应读取成功。")
	assert_eq(valid_empty_result.get_status(), GFSettingsLoadResult.STATUS_LOADED)
	assert_true(valid_empty_storage.ok, "合法空 JSON 对象应保留底层成功证据。")
	assert_true(valid_empty_storage.payload.is_empty())
	assert_eq(_setting_float(_settings, &"audio/master"), 1.0, "合法空对象应应用 replace 默认值。")
	assert_false(_settings.has_staged_values(), "合法空对象成功应用后应清 staged。")


func test_save_settings_rejects_cyclic_values_without_recursing() -> void:
	var cyclic: Array = []
	cyclic.append(cyclic)
	var _register_setting_result: Variant = _settings.register_setting(&"debug/cyclic", null, GFSettingDefinition.ValueType.ANY)
	_settings.set_value(&"debug/cyclic", cyclic)

	var save_error: Error = _settings.save_settings("cyclic_settings.json")

	assert_eq(save_error, ERR_INVALID_DATA, "循环引用设置不应被写入持久化文件。")
	assert_push_error("[GFSettingsUtility] 设置数据包含循环引用，已拒绝持久化：cyclic_settings.json。")


func test_store_port_write_failure_is_returned_without_success_signal() -> void:
	var settings: GFSettingsUtility = GFSettingsUtility.new()
	var failing_store: FailingSettingsStoreUtility = FailingSettingsStoreUtility.new()
	assert_eq(settings.set_settings_store_for_framework(failing_store, true), OK)
	settings.auto_load_on_init = false
	settings.auto_save_on_change = false
	settings.init()
	var file_name: String = _new_fallback_file_name("store_failure")
	var _register_setting_result: GFSettingDefinition = settings.register_setting(
		&"audio/master",
		1.0,
		GFSettingDefinition.ValueType.FLOAT
	)
	watch_signals(settings)

	var save_error: Error = settings.save_settings(file_name)

	assert_eq(save_error, ERR_FILE_CANT_WRITE, "Store port 必须传播实际写入失败。")
	assert_signal_not_emitted(settings, "settings_saved", "payload 未写入时不得发出保存成功信号。")
	settings.dispose()


func test_setting_changed_signal_reports_old_and_new_value() -> void:
	var _register_setting_result_108: Variant = _settings.register_setting(&"audio/master", 1.0, GFSettingDefinition.ValueType.FLOAT)
	watch_signals(_settings)

	_settings.set_value(&"audio/master", 0.25)

	assert_signal_emitted(_settings, "setting_changed", "设置变化时应发出信号。")
	assert_signal_emitted_with_parameters(_settings, "setting_changed", [&"audio/master", 1.0, 0.25])


func test_stage_value_keeps_effective_value_until_applied() -> void:
	var _register_setting_result_118: Variant = _settings.register_setting(&"audio/master", 1.0, GFSettingDefinition.ValueType.FLOAT)
	watch_signals(_settings)

	_settings.stage_value(&"audio/master", "0.5")

	assert_eq(_setting_float(_settings, &"audio/master"), 1.0, "暂存值不应立刻改变有效设置。")
	assert_eq(GFVariantData.to_float(_settings.get_staged_value(&"audio/master")), 0.5, "暂存值应按设置定义钳制。")
	assert_eq(GFVariantData.to_float(_settings.get_staged_or_value(&"audio/master")), 0.5, "预览读取应优先返回暂存值。")
	assert_true(_settings.has_staged_value(&"audio/master"), "设置应记录暂存状态。")
	assert_signal_not_emitted(_settings, "setting_changed", "暂存值不应触发有效设置变化信号。")
	assert_signal_emitted(_settings, "staged_setting_changed", "暂存状态变化应发出信号。")


func test_stage_value_equal_to_effective_value_clears_pending_value() -> void:
	var _register_setting_result_136: Variant = _settings.register_setting(&"audio/master", 1.0, GFSettingDefinition.ValueType.FLOAT)
	_settings.stage_value(&"audio/master", 0.5)

	_settings.stage_value(&"audio/master", 1.0)

	assert_false(_settings.has_staged_value(&"audio/master"), "暂存值回到当前有效值时应清除 pending。")
	assert_false(_settings.has_staged_values(), "唯一暂存值清除后应报告无 pending。")


func test_apply_staged_values_commits_selected_keys_and_preserves_remaining() -> void:
	var _register_setting_result_149: Variant = _settings.register_setting(&"audio/master", 1.0, GFSettingDefinition.ValueType.FLOAT)
	var _register_setting_result_150: Variant = _settings.register_setting(&"audio/music", 1.0, GFSettingDefinition.ValueType.FLOAT)
	_settings.stage_value(&"audio/master", 0.5)
	_settings.stage_value(&"audio/music", 0.25)
	watch_signals(_settings)

	var report: Dictionary = _settings.apply_staged_values({
		"scope": PackedStringArray(["audio/master"]),
		"save_after_change": false,
	})

	assert_true(GFVariantData.get_option_bool(report, "ok"), "暂存应用应成功。")
	assert_eq(GFVariantData.get_option_int(report, "applied_count"), 1, "只应应用 scope 中的暂存键。")
	assert_eq(GFVariantData.get_option_int(report, "changed_count"), 1, "实际变化数量应来自 apply_values。")
	assert_eq(GFVariantData.get_option_int(report, "staged_applied_count"), 1, "应报告已提交暂存键数量。")
	assert_eq(GFVariantData.get_option_int(report, "staged_remaining_count"), 1, "scope 外暂存值应保留。")
	assert_eq(_setting_float(_settings, &"audio/master"), 0.5, "scope 内暂存值应提交为有效设置。")
	assert_eq(_setting_float(_settings, &"audio/music"), 1.0, "scope 外暂存值不应提交。")
	assert_false(_settings.has_staged_value(&"audio/master"), "已提交键应移出暂存层。")
	assert_true(_settings.has_staged_value(&"audio/music"), "未提交键应继续暂存。")
	assert_signal_emitted(_settings, "setting_changed", "提交暂存值应触发有效设置变化。")
	assert_signal_emitted(_settings, "staged_settings_applied", "提交暂存值应发出批量应用信号。")


func test_apply_staged_values_batches_auto_save_once() -> void:
	var settings: RecordingSettingsUtility = RecordingSettingsUtility.new()
	settings.auto_load_on_init = false
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 0.5
	settings.init()
	var _register_setting_result_189: Variant = settings.register_setting(&"audio/master", 1.0, GFSettingDefinition.ValueType.FLOAT)
	var _register_setting_result_190: Variant = settings.register_setting(&"audio/music", 1.0, GFSettingDefinition.ValueType.FLOAT)
	settings.stage_value(&"audio/master", 0.8)
	settings.stage_value(&"audio/music", 0.6)

	var report: Dictionary = settings.apply_staged_values()
	settings.tick(0.25)
	settings.tick(0.25)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "暂存应用应成功。")
	assert_eq(settings.save_count, 1, "提交多个暂存值时应合并自动保存。")
	assert_eq(settings.saved_files, [settings.storage_file_name], "暂存应用保存应使用当前 storage_file_name。")
	assert_false(settings.has_staged_values(), "全部暂存值提交后不应保留 pending。")

	settings.dispose()


func test_discard_staged_values_clears_pending_without_changing_effective_values() -> void:
	var _register_setting_result_211: Variant = _settings.register_setting(&"audio/master", 1.0, GFSettingDefinition.ValueType.FLOAT)
	var _register_setting_result_212: Variant = _settings.register_setting(&"video/fullscreen", false, GFSettingDefinition.ValueType.BOOL)
	_settings.stage_value(&"audio/master", 0.5)
	_settings.stage_value(&"video/fullscreen", true)
	watch_signals(_settings)

	var discarded_keys: PackedStringArray = _settings.discard_staged_values()

	assert_eq(discarded_keys, PackedStringArray(["audio/master", "video/fullscreen"]), "丢弃应返回排序后的暂存键。")
	assert_false(_settings.has_staged_values(), "丢弃后不应还有暂存值。")
	assert_eq(_setting_float(_settings, &"audio/master"), 1.0, "丢弃暂存不应改变有效设置。")
	assert_eq(_setting_bool(_settings, &"video/fullscreen"), false, "丢弃暂存不应改变有效设置。")
	assert_signal_not_emitted(_settings, "setting_changed", "丢弃暂存不应触发有效设置变化。")
	assert_signal_emitted(_settings, "staged_settings_discarded", "丢弃暂存应发出批量信号。")


func test_apply_values_coerces_values_and_reports_counts() -> void:
	var _register_setting_result_118: Variant = _settings.register_setting(&"audio/master", 1.0, GFSettingDefinition.ValueType.FLOAT)
	var _register_setting_result_119: Variant = _settings.register_setting(&"video/fullscreen", false, GFSettingDefinition.ValueType.BOOL)

	var report: Dictionary = _settings.apply_values({
		"audio/master": "0.5",
		&"video/fullscreen": true,
	}, { "save_after_change": false })

	assert_true(GFVariantData.get_option_bool(report, "ok"), "合法预设应应用成功。")
	assert_true(GFVariantData.get_option_bool(report, "healthy"), "无警告和错误时报告应 healthy。")
	assert_eq(GFVariantData.get_option_int(report, "applied_count"), 2, "应报告已应用设置数量。")
	assert_eq(GFVariantData.get_option_int(report, "changed_count"), 2, "应报告实际变化数量。")
	assert_eq(_setting_float(_settings, &"audio/master"), 0.5, "批量应用应沿用设置定义做类型转换。")
	assert_eq(_setting_bool(_settings, &"video/fullscreen"), true, "批量应用应支持 StringName 键。")


func test_apply_values_batches_auto_save_once() -> void:
	var settings: RecordingSettingsUtility = RecordingSettingsUtility.new()
	settings.auto_load_on_init = false
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 0.5
	settings.init()
	var _register_setting_result_140: Variant = settings.register_setting(&"audio/master", 1.0, GFSettingDefinition.ValueType.FLOAT)
	var _register_setting_result_141: Variant = settings.register_setting(&"audio/music", 1.0, GFSettingDefinition.ValueType.FLOAT)

	var report: Dictionary = settings.apply_values({
		"audio/master": 0.8,
		"audio/music": 0.6,
	})
	settings.tick(0.25)
	settings.tick(0.25)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "批量应用设置应成功。")
	assert_eq(settings.save_count, 1, "批量应用设置时应合并自动保存。")
	assert_eq(settings.saved_files, [settings.storage_file_name], "批量应用保存应使用当前 storage_file_name。")

	settings.dispose()


func test_apply_values_requires_scope_before_reset_missing() -> void:
	var _register_setting_result_158: Variant = _settings.register_setting(&"audio/master", 1.0, GFSettingDefinition.ValueType.FLOAT)
	_settings.set_value(&"audio/master", 0.25)

	var report: Dictionary = _settings.apply_values({}, { "reset_missing": true, "save_after_change": false })
	var issues: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "issues"))
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺少 scope 时不应执行 reset_missing。")
	assert_eq(GFVariantData.get_option_int(report, "error_count"), 1, "缺少 scope 应报告一个错误。")
	assert_eq(GFVariantData.get_option_string(first_issue, "kind"), "missing_reset_scope", "问题类型应说明缺少重置作用域。")
	assert_eq(_setting_float(_settings, &"audio/master"), 0.25, "失败的重置预设不应改变设置。")


func test_apply_values_resets_missing_keys_inside_explicit_scope() -> void:
	var _register_setting_result_172: Variant = _settings.register_setting(&"audio/master", 1.0, GFSettingDefinition.ValueType.FLOAT)
	var _register_setting_result_173: Variant = _settings.register_setting(&"audio/music", 1.0, GFSettingDefinition.ValueType.FLOAT)
	var _register_setting_result_174: Variant = _settings.register_setting(&"video/fullscreen", false, GFSettingDefinition.ValueType.BOOL)
	_settings.set_value(&"audio/master", 0.25)
	_settings.set_value(&"audio/music", 0.3)
	_settings.set_value(&"video/fullscreen", true)

	var report: Dictionary = _settings.apply_values({
		"audio/master": 0.75,
		"video/fullscreen": false,
	}, {
		"reset_missing": true,
		"scope": PackedStringArray(["audio/master", "audio/music"]),
		"save_after_change": false,
	})

	assert_true(GFVariantData.get_option_bool(report, "ok"), "显式作用域内的预设应应用成功。")
	assert_false(GFVariantData.get_option_bool(report, "healthy"), "跳过作用域外键时应标记非 healthy。")
	assert_eq(GFVariantData.get_option_int(report, "applied_count"), 1, "只应应用作用域内传入键。")
	assert_eq(GFVariantData.get_option_int(report, "reset_count"), 1, "缺失的作用域内键应重置。")
	assert_eq(GFVariantData.get_option_int(report, "skipped_count"), 1, "作用域外键应被跳过。")
	assert_eq(GFVariantData.get_option_int(report, "warning_count"), 1, "作用域外键应报告 warning。")
	assert_eq(_setting_float(_settings, &"audio/master"), 0.75, "作用域内值应被应用。")
	assert_eq(_setting_float(_settings, &"audio/music"), 1.0, "作用域内缺失值应重置默认值。")
	assert_eq(_setting_bool(_settings, &"video/fullscreen"), true, "作用域外值不应被修改。")


func test_auto_save_debounce_and_batch_flush_once() -> void:
	var settings: RecordingSettingsUtility = RecordingSettingsUtility.new()
	settings.auto_load_on_init = false
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 0.5
	settings.init()
	var _register_setting_result_205: Variant = settings.register_setting(&"audio/master", 1.0, GFSettingDefinition.ValueType.FLOAT)

	settings.begin_batch()
	settings.set_value(&"audio/master", 0.8)
	settings.set_value(&"audio/master", 0.6)
	settings.end_batch()
	settings.tick(0.25)
	settings.tick(0.25)

	assert_eq(settings.save_count, 1, "批量修改结束后应合并为一次防抖保存。")
	assert_eq(settings.saved_files, [settings.storage_file_name], "防抖保存应使用当前 storage_file_name。")

	settings.dispose()


func test_fallback_persistence_rejects_native_absolute_paths() -> void:
	var native_absolute_path: String = "C:/gf_settings_denied.json"
	var _register_setting_result: Variant = _settings.register_setting(&"audio/master", 1.0, GFSettingDefinition.ValueType.FLOAT)

	var save_error: Error = _settings.save_settings(native_absolute_path)
	var load_result: GFSettingsLoadResult = _settings.load_settings(native_absolute_path)
	var storage_result: GFStorageReadResult = load_result.get_storage_result()

	assert_eq(save_error, ERR_INVALID_PARAMETER, "无 GFStorageUtility 后端时 fallback 持久化不应写入原生绝对路径。")
	assert_false(load_result.is_successful(), "被拒绝的原生绝对路径不应读取数据。")
	assert_eq(load_result.get_status(), GFSettingsLoadResult.STATUS_INVALID_REQUEST)
	assert_not_null(storage_result, "非法 fallback 路径应返回结构化读取失败。")
	assert_eq(storage_result.failure_kind, GFStorageReadResult.FailureKind.INVALID_REQUEST)
	assert_push_error("[GFSettingsUtility] 已拒绝原生绝对设置路径：C:/gf_settings_denied.json。")
	assert_push_error("[GFSettingsUtility] 已拒绝原生绝对设置路径：C:/gf_settings_denied.json。")


func test_storage_backed_settings_roundtrip_keeps_framework_metadata_out_of_business_data() -> void:
	var storage: GFStorageUtility = GFStorageUtility.new()
	storage.save_dir_name = "test_settings_storage"
	storage.include_storage_metadata = true
	storage.init()
	var file_name: String = "settings_roundtrip.sav"
	var settings: GFSettingsUtility = GFSettingsUtility.new()
	var settings_store: StorageBackedSettingsStoreUtility = (
		StorageBackedSettingsStoreUtility.new()
	)
	settings_store.storage_backend = storage
	assert_eq(settings.set_settings_store_for_framework(settings_store, true), OK)
	settings.storage_file_name = file_name
	settings.auto_load_on_init = false
	settings.auto_save_on_change = false
	settings.init()
	var _register_profile_result: Variant = settings.register_setting(
		&"profile/metadata",
		{},
		GFSettingDefinition.ValueType.DICTIONARY
	)
	settings.set_value(&"profile/metadata", {
		"_meta": {"owner": "project"},
		"value": 7,
	}, false)

	assert_eq(settings.save_settings(), OK, "Settings 应通过严格 Storage 文档保存。")
	var storage_result: GFStorageReadResult = storage.load_data(file_name)
	assert_true(storage_result.ok, "Settings 物理文档应可由 Storage 读取。")
	assert_true(storage_result.metadata.has(GFStorageCodec.VERSION_KEY), "存储版本应位于独立 metadata。")
	assert_false(storage_result.payload.has(GFStorageCodec.VERSION_KEY), "存储版本不得渗入 Settings 业务字典。")

	var restored: GFSettingsUtility = GFSettingsUtility.new()
	var restored_store: StorageBackedSettingsStoreUtility = (
		StorageBackedSettingsStoreUtility.new()
	)
	restored_store.storage_backend = storage
	assert_eq(restored.set_settings_store_for_framework(restored_store, true), OK)
	restored.storage_file_name = file_name
	restored.auto_load_on_init = false
	restored.auto_save_on_change = false
	restored.init()
	var _register_restored_profile_result: Variant = restored.register_setting(
		&"profile/metadata",
		{},
		GFSettingDefinition.ValueType.DICTIONARY
	)
	var load_result: GFSettingsLoadResult = restored.load_settings()
	var loaded_storage_result: GFStorageReadResult = load_result.get_storage_result()
	var profile: Dictionary = GFVariantData.as_dictionary(restored.get_value(&"profile/metadata"))
	var project_meta: Dictionary = GFVariantData.get_option_dictionary(profile, "_meta")

	assert_true(load_result.is_successful(), "Storage-backed Settings 应返回成功终态。")
	assert_not_null(loaded_storage_result, "Settings 结果应保留底层读取结果。")
	assert_false(
		loaded_storage_result.payload.has(GFStorageCodec.VERSION_KEY),
		"Settings 业务载荷不得包含存储 metadata。"
	)
	assert_eq(GFVariantData.get_option_string(project_meta, "owner"), "project", "业务 `_meta` 应完整往返。")
	assert_eq(GFVariantData.get_option_int(profile, "value"), 7, "业务设置值应完整往返。")

	restored.dispose()
	settings.dispose()
	for suffix: String in ["", ".tmp", ".bak", ".txn"]:
		var path: String = storage._get_full_path(file_name + suffix)
		if FileAccess.file_exists(path):
			var _remove_result: Error = DirAccess.remove_absolute(path)
	storage.dispose()


func test_fallback_persistence_rejects_parent_traversal_paths() -> void:
	var _register_setting_result: Variant = _settings.register_setting(&"audio/master", 1.0, GFSettingDefinition.ValueType.FLOAT)

	var save_error: Error = _settings.save_settings("../gf_settings_escape.json")
	var load_result: GFSettingsLoadResult = _settings.load_settings("../gf_settings_escape.json")
	var storage_result: GFStorageReadResult = load_result.get_storage_result()

	assert_eq(save_error, ERR_INVALID_PARAMETER, "fallback 持久化只应接受纯文件名。")
	assert_false(load_result.is_successful(), "被拒绝的 traversal 路径不应读取数据。")
	assert_eq(load_result.get_status(), GFSettingsLoadResult.STATUS_INVALID_REQUEST)
	assert_not_null(storage_result, "非法 traversal 应返回结构化读取失败。")
	assert_eq(storage_result.failure_kind, GFStorageReadResult.FailureKind.INVALID_REQUEST)
	assert_push_error("[GFSettingsUtility] 已拒绝不安全设置文件名：../gf_settings_escape.json。")
	assert_push_error("[GFSettingsUtility] 已拒绝不安全设置文件名：../gf_settings_escape.json。")


# --- 私有/辅助方法 ---

func _make_scripted_settings(read_result: GFStorageReadResult) -> ScriptedSettingsUtility:
	var settings: ScriptedSettingsUtility = ScriptedSettingsUtility.new()
	settings.read_result = read_result.duplicate_result()
	settings.auto_load_on_init = false
	settings.auto_save_on_change = false
	settings.init()
	return settings


func _make_storage_failure(
	failure_kind: GFStorageReadResult.FailureKind,
	error_code: Error,
	error_message: String
) -> GFStorageReadResult:
	return GFStorageReadResult.new().configure_failure(
		error_message,
		error_code,
		{},
		GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
		0,
		failure_kind
	)


func _new_fallback_file_name(label: String) -> String:
	var file_name: String = "gf_settings_contract_%d_%d_%s.json" % [
		get_instance_id(),
		_fallback_file_names.size(),
		label,
	]
	var _appended: bool = _fallback_file_names.append(file_name)
	var path: String = "user://" + file_name
	if FileAccess.file_exists(path):
		var _remove_error: Error = DirAccess.remove_absolute(path)
	return file_name


func _write_fallback_text(file_name: String, content: String) -> void:
	var file: FileAccess = FileAccess.open("user://" + file_name, FileAccess.WRITE)
	assert_not_null(file, "fallback 测试夹具应可写入 user://。")
	if file == null:
		return
	var _store_result: Variant = file.store_string(content)
	file.close()


func _setting_bool(settings: GFSettingsUtility, key: StringName) -> bool:
	return GFVariantData.to_bool(settings.get_value(key))


func _setting_int(settings: GFSettingsUtility, key: StringName) -> int:
	return GFVariantData.to_int(settings.get_value(key))


func _setting_float(settings: GFSettingsUtility, key: StringName) -> float:
	return GFVariantData.to_float(settings.get_value(key))


func _setting_text(settings: GFSettingsUtility, key: StringName) -> String:
	return GFVariantData.to_text(settings.get_value(key))


func _setting_string_name(settings: GFSettingsUtility, key: StringName) -> StringName:
	return GFVariantData.to_string_name(settings.get_value(key))


func _setting_vector2i(settings: GFSettingsUtility, key: StringName) -> Vector2i:
	var value: Variant = settings.get_value(key)
	if value is Vector2i:
		var vector: Vector2i = value
		return vector
	if value is Vector2:
		var vector2: Vector2 = value
		return Vector2i(roundi(vector2.x), roundi(vector2.y))
	return Vector2i.ZERO


func _setting_color(settings: GFSettingsUtility, key: StringName) -> Color:
	var value: Variant = settings.get_value(key)
	if value is Color:
		var color: Color = value
		return color
	return Color.TRANSPARENT


# --- 辅助类 ---

class RecordingSettingsUtility:
	extends GFSettingsUtility

	var save_count: int = 0
	var saved_files: Array[String] = []

	func _write_persisted_data(file_name: String, _data: Dictionary) -> Error:
		save_count += 1
		saved_files.append(file_name)
		return OK


class FailingSettingsStoreUtility:
	extends GFSettingsStoreUtility

	func is_persistence_enabled() -> bool:
		return true

	func write_settings(_file_name: String, _data: Dictionary) -> Error:
		return ERR_FILE_CANT_WRITE


class LoadedSettingsUtility:
	extends GFSettingsUtility

	var loaded_data: Dictionary = {}

	func _read_persisted_data(_file_name: String) -> GFStorageReadResult:
		return GFStorageReadResult.new().configure_success(loaded_data)


class ScriptedSettingsUtility:
	extends GFSettingsUtility

	var read_result: GFStorageReadResult = GFStorageReadResult.new().configure_success({})
	var read_count: int = 0
	var write_count: int = 0

	func _read_persisted_data(_file_name: String) -> GFStorageReadResult:
		read_count += 1
		return read_result.duplicate_result()

	func _write_persisted_data(_file_name: String, _data: Dictionary) -> Error:
		write_count += 1
		return OK


class StorageBackedSettingsStoreUtility:
	extends GFSettingsStoreUtility

	var storage_backend: GFStorageUtility

	func is_persistence_enabled() -> bool:
		return storage_backend != null

	func read_settings(file_name: String) -> GFStorageReadResult:
		if storage_backend == null:
			return super.read_settings(file_name)
		return storage_backend.load_data(file_name)

	func write_settings(file_name: String, data: Dictionary) -> Error:
		if storage_backend == null:
			return ERR_UNAVAILABLE
		return storage_backend.save_data(file_name, data)
