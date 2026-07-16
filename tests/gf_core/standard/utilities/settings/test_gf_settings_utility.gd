## 测试 GFSettingsUtility 与 GFSettingDefinition 的设置注册、类型钳制和序列化行为。
extends GutTest


# --- 私有变量 ---

var _settings: GFSettingsUtility


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

	var _loaded: Dictionary = settings.load_settings("profile.json")

	assert_eq(_setting_float(settings, &"audio/master"), 0.5, "load 应应用持久化值。")
	assert_eq(_setting_float(settings, &"audio/music"), 0.8, "load 应重置持久化数据中缺失的已定义键。")
	settings.dispose()


func test_save_settings_rejects_cyclic_values_without_recursing() -> void:
	var cyclic: Array = []
	cyclic.append(cyclic)
	var _register_setting_result: Variant = _settings.register_setting(&"debug/cyclic", null, GFSettingDefinition.ValueType.ANY)
	_settings.set_value(&"debug/cyclic", cyclic)

	var save_error: Error = _settings.save_settings("cyclic_settings.json")

	assert_eq(save_error, ERR_INVALID_DATA, "循环引用设置不应被写入持久化文件。")
	assert_push_error("[GFSettingsUtility] 设置数据包含循环引用，已拒绝持久化：cyclic_settings.json。")


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
	var loaded: Dictionary = _settings.load_settings(native_absolute_path)

	assert_eq(save_error, ERR_INVALID_PARAMETER, "无 GFStorageUtility 后端时 fallback 持久化不应写入原生绝对路径。")
	assert_true(loaded.is_empty(), "被拒绝的原生绝对路径不应读取数据。")
	assert_push_error("[GFSettingsUtility] 已拒绝原生绝对设置路径：C:/gf_settings_denied.json。")
	assert_push_error("[GFSettingsUtility] 已拒绝原生绝对设置路径：C:/gf_settings_denied.json。")


func test_fallback_persistence_rejects_parent_traversal_paths() -> void:
	var _register_setting_result: Variant = _settings.register_setting(&"audio/master", 1.0, GFSettingDefinition.ValueType.FLOAT)

	var save_error: Error = _settings.save_settings("../gf_settings_escape.json")
	var loaded: Dictionary = _settings.load_settings("../gf_settings_escape.json")

	assert_eq(save_error, ERR_INVALID_PARAMETER, "fallback 持久化只应接受纯文件名。")
	assert_true(loaded.is_empty(), "被拒绝的 traversal 路径不应读取数据。")
	assert_push_error("[GFSettingsUtility] 已拒绝不安全设置文件名：../gf_settings_escape.json。")
	assert_push_error("[GFSettingsUtility] 已拒绝不安全设置文件名：../gf_settings_escape.json。")


# --- 私有/辅助方法 ---

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


class LoadedSettingsUtility:
	extends GFSettingsUtility

	var loaded_data: Dictionary = {}

	func _read_persisted_data(_file_name: String) -> Dictionary:
		return loaded_data.duplicate(true)
