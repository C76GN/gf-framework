## GFSettingsUtility: 通用设置注册、读写与持久化工具。
##
## 设置项以 StringName 键访问，可选使用 GFSettingDefinition 声明默认值和类型。
## 该工具只管理抽象设置值，不直接绑定窗口、音频、输入或任何项目业务。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFSettingsUtility
extends GFUtility


# --- 信号 ---

## 设置值变化时发出。
## [br]
## @api public
## [br]
## @param key: 设置键。
## [br]
## @param old_value: 旧值。
## [br]
## @schema old_value: Variant previous setting value or null when the setting did not exist.
## [br]
## @param new_value: 新值。
## [br]
## @schema new_value: Variant next setting value or null when the setting was removed.
signal setting_changed(key: StringName, old_value: Variant, new_value: Variant)

## 设置加载完成时发出。
## [br]
## @api public
## [br]
## @param data: 已加载的持久化设置数据。
## [br]
## @schema data: Dictionary[String, Variant] loaded persisted settings data.
signal settings_loaded(data: Dictionary)

## 设置保存完成时发出。
## [br]
## @api public
## [br]
## @param data: 已保存的持久化设置数据。
## [br]
## @schema data: Dictionary[String, Variant] saved persisted settings data produced by to_dict(true).
signal settings_saved(data: Dictionary)

## 暂存设置值变化时发出。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param key: 暂存状态变化的设置键。
signal staged_setting_changed(key: StringName)

## 暂存设置值被应用到真实设置后发出。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param report: 应用报告。
## [br]
## @schema report: Dictionary with apply_values() report fields plus staged_applied_count, staged_remaining_count, and staged_applied_keys.
signal staged_settings_applied(report: Dictionary)

## 暂存设置值被丢弃后发出。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param keys: 被丢弃暂存值的设置键。
signal staged_settings_discarded(keys: PackedStringArray)


# --- 常量 ---

const _SETTING_TYPE_KEY: String = "__gf_setting_type"
const _SETTING_VALUE_KEY: String = "value"
const _SETTING_SERIALIZATION_ERROR_COUNT_KEY: String = "error_count"


# --- 公共变量 ---

## 默认持久化文件名。
## [br]
## @api public
var storage_file_name: String = "settings.sav"

## init() 时是否自动读取持久化设置。
## [br]
## @api public
var auto_load_on_init: bool = true

## set_value() 修改持久化设置时是否自动保存。
## [br]
## @api public
var auto_save_on_change: bool = true

## 自动保存的防抖秒数；小于等于 0 时保持立即保存。
## [br]
## @api public
var save_debounce_seconds: float = 0.25


# --- 私有变量 ---

var _definitions: Dictionary = {}
var _values: Dictionary = {}
var _staged_values: Dictionary = {}
var _save_queued: bool = false
var _save_elapsed_seconds: float = 0.0
var _save_queued_file_name: String = ""
var _batch_depth: int = 0
var _batch_save_requested: bool = false


# --- GF 生命周期方法 ---

## 初始化设置工具，并按配置自动加载持久化设置或应用默认值。
## [br]
## @api public
func init() -> void:
	if auto_load_on_init:
		var _loaded_data: Dictionary = load_settings()
	else:
		_apply_defaults_to_missing()


## 释放设置工具，并清理已注册定义、当前值和等待中的自动保存状态。
## [br]
## @api public
func dispose() -> void:
	var _flush_error: Error = flush_pending_save()
	_definitions.clear()
	_values.clear()
	_staged_values.clear()
	_save_queued = false
	_save_elapsed_seconds = 0.0
	_save_queued_file_name = ""
	_batch_depth = 0
	_batch_save_requested = false


# --- 公共方法 ---

## 注册一个设置定义。
## [br]
## @api public
## [br]
## @param definition: 设置定义。
## [br]
## @param apply_default: 缺少当前值时是否写入默认值。
func register_definition(definition: GFSettingDefinition, apply_default: bool = true) -> void:
	if definition == null:
		push_error("[GFSettingsUtility] register_definition 失败：definition 为空。")
		return

	var key: StringName = definition.get_setting_key()
	if key == &"":
		push_error("[GFSettingsUtility] register_definition 失败：设置键为空。")
		return

	_definitions[key] = definition.duplicate_definition()
	if _values.has(key):
		_values[key] = definition.coerce_value(_values[key])
	elif apply_default:
		_values[key] = definition.coerce_value(definition.default_value)
	_reconcile_staged_value(key)


## 使用参数快速注册一个设置定义。
## [br]
## @api public
## [br]
## @param key: 设置键。
## [br]
## @param default_value: 默认值。
## [br]
## @schema default_value: Variant default setting value accepted by value_type.
## [br]
## @param value_type: 值类型。
## [br]
## @param persistent: 是否持久化。
## [br]
## @param metadata: 可选元数据。
## [br]
## @schema metadata: Dictionary with optional UI grouping, ordering, label, and project-defined metadata.
## [br]
## @return 新设置定义。
func register_setting(
	key: StringName,
	default_value: Variant = null,
	value_type: GFSettingDefinition.ValueType = GFSettingDefinition.ValueType.ANY,
	persistent: bool = true,
	metadata: Dictionary = {}
) -> GFSettingDefinition:
	var definition: GFSettingDefinition = GFSettingDefinition.new()
	definition.key = key
	definition.default_value = default_value
	definition.value_type = value_type
	definition.persistent = persistent
	definition.metadata = metadata.duplicate(true)
	register_definition(definition)
	return definition


## 批量注册设置定义。
## [br]
## @api public
## [br]
## @param definitions: 设置定义数组。
func register_definitions(definitions: Array[GFSettingDefinition]) -> void:
	for definition: GFSettingDefinition in definitions:
		register_definition(definition)


## 获取指定设置定义。
## [br]
## @api public
## [br]
## @param key: 设置键。
## [br]
## @return 设置定义；不存在时返回 null。
func get_definition(key: StringName) -> GFSettingDefinition:
	var definition: GFSettingDefinition = _get_definition(key)
	if definition == null:
		return null
	return definition.duplicate_definition()


## 获取所有设置定义。
## [br]
## @api public
## [br]
## @return 设置定义数组。
func get_definitions() -> Array[GFSettingDefinition]:
	var result: Array[GFSettingDefinition] = []
	for definition: GFSettingDefinition in _definitions.values():
		result.append(definition.duplicate_definition())
	return result


## 设置一个值。
## [br]
## @api public
## [br]
## @param key: 设置键。
## [br]
## @param value: 设置值。
## [br]
## @schema value: Variant setting value coerced by the registered definition when present.
## [br]
## @param save_after_change: 若为持久化设置，变化后是否保存。
func set_value(key: StringName, value: Variant, save_after_change: bool = true) -> void:
	_set_value_internal(key, value, true, save_after_change)


## 设置一个暂存值。
##
## 暂存值不会改变当前有效设置，也不会触发保存；调用 apply_staged_values() 后才会写入真实设置。
## 如果暂存值等于当前有效值，会清除该键已有的暂存值。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param key: 设置键。
## [br]
## @param value: 暂存设置值。
## [br]
## @schema value: Variant setting value coerced by the registered definition when present.
func stage_value(key: StringName, value: Variant) -> void:
	_stage_value_internal(key, value, true)


## 获取指定键的暂存值。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param key: 设置键。
## [br]
## @param fallback: 没有暂存值时返回的值。
## [br]
## @schema fallback: Variant value returned when the setting has no staged value.
## [br]
## @return 暂存值或 fallback。
## [br]
## @schema return: Variant pending staged value or fallback.
func get_staged_value(key: StringName, fallback: Variant = null) -> Variant:
	if _staged_values.has(key):
		return _staged_values[key]
	return fallback


## 获取用于预览的设置值。
##
## 若存在暂存值则返回暂存值，否则返回当前有效值。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param key: 设置键。
## [br]
## @param fallback: 无当前值、默认值和暂存值时返回的值。
## [br]
## @schema fallback: Variant value returned when the setting has no staged, current, or default value.
## [br]
## @return 暂存值或当前有效值。
## [br]
## @schema return: Variant staged value when present, otherwise current setting value.
func get_staged_or_value(key: StringName, fallback: Variant = null) -> Variant:
	if _staged_values.has(key):
		return _staged_values[key]
	return get_value(key, fallback)


## 检查指定键是否存在暂存值。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param key: 设置键。
## [br]
## @return 存在暂存值时返回 true。
func has_staged_value(key: StringName) -> bool:
	return _staged_values.has(key)


## 检查是否存在任意暂存值。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 至少有一个暂存值时返回 true。
func has_staged_values() -> bool:
	return not _staged_values.is_empty()


## 获取所有暂存值。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 暂存设置字典副本。
## [br]
## @schema return: Dictionary[StringName, Variant] staged setting values that are not yet applied.
func get_staged_values() -> Dictionary:
	return _staged_values.duplicate(true)


## 获取所有存在暂存值的设置键。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 排序后的暂存设置键。
func get_staged_keys() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key_variant: Variant in _staged_values.keys():
		var key: StringName = GFVariantData.to_string_name(key_variant)
		if key != &"":
			var _key_appended: bool = result.append(String(key))
	result.sort()
	return result


## 丢弃指定键的暂存值。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param key: 设置键。
## [br]
## @return 实际丢弃暂存值时返回 true。
func discard_staged_value(key: StringName) -> bool:
	var discarded: bool = _discard_staged_value_internal(key, true)
	if discarded:
		var keys: PackedStringArray = PackedStringArray()
		var _key_appended: bool = keys.append(String(key))
		staged_settings_discarded.emit(keys)
	return discarded


## 丢弃全部暂存值。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 被丢弃暂存值的设置键。
func discard_staged_values() -> PackedStringArray:
	var discarded_keys: PackedStringArray = get_staged_keys()
	for key_text: String in discarded_keys:
		var _discarded: bool = _discard_staged_value_internal(StringName(key_text), true)
	if not discarded_keys.is_empty():
		staged_settings_discarded.emit(discarded_keys)
	return discarded_keys


## 应用暂存设置值。
##
## 只把暂存层提交到真实设置；真实设置变化、类型钳制和自动保存仍沿用 apply_values() 语义。
## 可通过 options.scope 只提交指定键。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param options: 可选行为。支持 save_after_change、emit_changes 与 scope。
## [br]
## @schema options: Dictionary with save_after_change: bool, emit_changes: bool, and scope as Array, PackedStringArray, Dictionary, String, or StringName.
## [br]
## @return 应用报告。
## [br]
## @schema return: Dictionary with apply_values() report fields plus staged_applied_count, staged_remaining_count, and staged_applied_keys: PackedStringArray.
func apply_staged_values(options: Dictionary = {}) -> Dictionary:
	var scope: Dictionary = _normalize_apply_scope(GFVariantData.get_option_value(options, "scope", []))
	var selected_values: Dictionary = {}
	for key_variant: Variant in _staged_values.keys():
		var key: StringName = GFVariantData.to_string_name(key_variant)
		if key == &"":
			continue
		if not scope.is_empty() and not scope.has(key):
			continue
		selected_values[key] = GFVariantData.duplicate_variant(_staged_values[key_variant])

	var apply_options: Dictionary = {
		"save_after_change": GFVariantData.get_option_bool(options, "save_after_change", true),
		"emit_changes": GFVariantData.get_option_bool(options, "emit_changes", true),
	}
	var report: Dictionary = apply_values(selected_values, apply_options)
	var applied_keys: PackedStringArray = PackedStringArray()
	if GFVariantData.get_option_bool(report, "ok"):
		for key: StringName in selected_values.keys():
			var discarded: bool = _discard_staged_value_internal(key, true)
			if discarded:
				var _key_appended: bool = applied_keys.append(String(key))
		applied_keys.sort()

	report["staged_applied_count"] = applied_keys.size()
	report["staged_remaining_count"] = _staged_values.size()
	report["staged_applied_keys"] = applied_keys
	staged_settings_applied.emit(report)
	return report


## 批量应用一组设置值，适合图形质量、辅助功能或输入方案等项目预设。
## [br]
## @api public
## [br]
## @param values: 设置键到设置值的字典。
## [br]
## @schema values: Dictionary[String, Variant] mapping setting keys to new values.
## [br]
## @param options: 可选行为。支持 save_after_change、emit_changes、reset_missing 与 scope。
## [br]
## @schema options: Dictionary with save_after_change: bool, emit_changes: bool, reset_missing: bool, and scope as Array, PackedStringArray, Dictionary, String, or StringName.
## [br]
## @return 应用报告；问题项使用标准 kind 字段。
## [br]
## @schema return: Dictionary with ok, healthy, applied_count, changed_count, reset_count, skipped_count, error_count, warning_count, issue_count, and issues: Array[Dictionary].
func apply_values(values: Dictionary, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_apply_values_report()
	var save_after_change: bool = GFVariantData.get_option_bool(options, "save_after_change", true)
	var emit_changes: bool = GFVariantData.get_option_bool(options, "emit_changes", true)
	var reset_missing: bool = GFVariantData.get_option_bool(options, "reset_missing", false)
	var scope: Dictionary = _normalize_apply_scope(GFVariantData.get_option_value(options, "scope", []))
	if reset_missing and scope.is_empty():
		_add_apply_values_issue(
			report,
			"error",
			"missing_reset_scope",
			&"",
			"reset_missing 需要显式 scope，避免误重置全部设置。"
		)
		_finalize_apply_values_report(report)
		return report

	var normalized_values: Dictionary = {}
	for key_variant: Variant in values.keys():
		var key: StringName = GFVariantData.to_string_name(key_variant)
		if key == &"":
			_add_apply_values_issue(
				report,
				"error",
				"empty_setting_key",
				&"",
				"设置预设包含空键。"
			)
			continue
		if not scope.is_empty() and not scope.has(key):
			_increment_report_count(report, "skipped_count")
			_add_apply_values_issue(
				report,
				"warning",
				"outside_scope",
				key,
				"设置键不在本次预设作用域内：%s。" % String(key)
			)
			continue
		normalized_values[key] = values[key_variant]

	begin_batch()
	for key: StringName in normalized_values.keys():
		var old_value: Variant = get_value(key)
		_set_value_internal(key, normalized_values[key], emit_changes, save_after_change)
		var new_value: Variant = get_value(key)
		_increment_report_count(report, "applied_count")
		if old_value != new_value:
			_increment_report_count(report, "changed_count")

	if reset_missing:
		for key: StringName in scope.keys():
			if normalized_values.has(key) or not has_setting(key):
				continue
			var old_value: Variant = get_value(key)
			_reset_value_internal(key, emit_changes, save_after_change)
			var new_value: Variant = get_value(key)
			_increment_report_count(report, "reset_count")
			if old_value != new_value:
				_increment_report_count(report, "changed_count")

	end_batch(save_after_change)
	_finalize_apply_values_report(report)
	return report


## 开始一批设置修改。批处理中自动保存会延后到 end_batch()。
## [br]
## @api public
func begin_batch() -> void:
	_batch_depth += 1


## 结束一批设置修改，并在需要时合并触发一次自动保存。
## [br]
## @api public
## [br]
## @param save_after_change: 本批变化结束后是否允许保存。
func end_batch(save_after_change: bool = true) -> void:
	if _batch_depth <= 0:
		return

	_batch_depth -= 1
	if _batch_depth > 0:
		return
	if not _batch_save_requested:
		return

	_batch_save_requested = false
	if save_after_change and auto_save_on_change:
		queue_save()


## 将当前设置标记为稍后保存，受 save_debounce_seconds 控制。
## [br]
## @api public
func queue_save() -> void:
	if save_debounce_seconds <= 0.0:
		var _save_error: Error = save_settings()
		return

	_save_queued = true
	_save_elapsed_seconds = 0.0
	_save_queued_file_name = storage_file_name


## 立即执行正在等待的自动保存。
## [br]
## @api public
## [br]
## @return 保存结果；没有待保存内容时返回 OK。
func flush_pending_save() -> Error:
	if not _save_queued:
		return OK

	var target_file_name: String = _save_queued_file_name
	_save_queued = false
	_save_elapsed_seconds = 0.0
	_save_queued_file_name = ""
	return save_settings(target_file_name)


## 获取一个值。
## [br]
## @api public
## [br]
## @param key: 设置键。
## [br]
## @param fallback: 无当前值和默认值时返回的值。
## [br]
## @schema fallback: Variant value returned when the setting has no current value or definition.
## [br]
## @return 设置值。
## [br]
## @schema return: Variant current setting value, coerced default, or fallback.
func get_value(key: StringName, fallback: Variant = null) -> Variant:
	if _values.has(key):
		return _values[key]

	var definition: GFSettingDefinition = _get_definition(key)
	if definition != null:
		return definition.coerce_value(definition.default_value)

	return fallback


## 检查设置是否存在当前值或定义。
## [br]
## @api public
## [br]
## @param key: 设置键。
## [br]
## @return 存在时返回 true。
func has_setting(key: StringName) -> bool:
	return _values.has(key) or _definitions.has(key)


## 重置单个设置到默认值。未定义设置会被移除。
## [br]
## @api public
## [br]
## @param key: 设置键。
## [br]
## @param save_after_change: 若为持久化设置，变化后是否保存。
func reset_value(key: StringName, save_after_change: bool = true) -> void:
	_reset_value_internal(key, true, save_after_change)


## 重置所有已定义设置到默认值，并移除未定义的临时设置。
## [br]
## @api public
## [br]
## @param save_after_change: 是否保存。
func reset_all(save_after_change: bool = true) -> void:
	var previous_values: Dictionary = _values.duplicate(true)
	_values.clear()
	_apply_defaults_to_missing()

	for key_variant: Variant in previous_values.keys():
		var key: StringName = GFVariantData.to_string_name(key_variant)
		var old_value: Variant = previous_values[key]
		var new_value: Variant = GFVariantData.get_option_value(_values, key)
		if old_value != new_value:
			setting_changed.emit(key, old_value, new_value)

	for key: StringName in _values.keys():
		if not previous_values.has(key):
			setting_changed.emit(key, null, _values[key])

	if save_after_change:
		_queue_auto_save()


## 转换为可持久化字典。
## [br]
## @api public
## [br]
## @param persistent_only: 是否仅包含 persistent 定义。
## [br]
## @return 设置字典。
## [br]
## @schema return: Dictionary[String, Variant] serialized setting values suitable for persistence.
func to_dict(persistent_only: bool = true) -> Dictionary:
	var serialization_state: Dictionary = {}
	return _to_dict_with_state(persistent_only, serialization_state)


## 使用字典完整替换当前设置。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 设置数据。
## [br]
## @schema data: Dictionary[String, Variant] serialized setting values produced by to_dict().
## [br]
## @param emit_changes: 变化时是否发出 setting_changed。
func replace_from_dict(data: Dictionary, emit_changes: bool = true) -> void:
	var previous_values: Dictionary = _values.duplicate(false)
	_values = _build_restored_values(data)
	if emit_changes:
		_emit_replaced_value_changes(previous_values)
		var _discarded_staged_keys: PackedStringArray = discard_staged_values()
	else:
		_staged_values.clear()


## 将字典作为覆盖层合并到当前设置。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 设置数据。
## [br]
## @schema data: Dictionary[String, Variant] serialized setting values produced by to_dict().
## [br]
## @param emit_changes: 变化时是否发出 setting_changed。
func merge_from_dict(data: Dictionary, emit_changes: bool = true) -> void:
	for key_variant: Variant in data.keys():
		var key: StringName = GFVariantData.to_string_name(key_variant)
		_set_value_internal(key, _deserialize_value(data[key_variant]), emit_changes, false)
	_apply_defaults_to_missing()
	for staged_key_variant: Variant in _staged_values.keys():
		_reconcile_staged_value(GFVariantData.to_string_name(staged_key_variant))


## 读取持久化设置。
## [br]
## @api public
## [br]
## @param file_name: 可选文件名；为空时使用 storage_file_name。
## [br]
## @return 已读取的数据。
## [br]
## @schema return: Dictionary[String, Variant] loaded persisted settings data.
func load_settings(file_name: String = "") -> Dictionary:
	var target_file_name: String = storage_file_name if file_name.is_empty() else file_name
	_clear_pending_save(target_file_name)
	var data: Dictionary = _read_persisted_data(target_file_name)
	replace_from_dict(data, false)
	settings_loaded.emit(data)
	return data


## 保存持久化设置。
## [br]
## @api public
## [br]
## @param file_name: 可选文件名；为空时使用 storage_file_name。
## [br]
## @return Godot 错误码。
func save_settings(file_name: String = "") -> Error:
	var target_file_name: String = storage_file_name if file_name.is_empty() else file_name
	var serialization_state: Dictionary = {}
	var data: Dictionary = _to_dict_with_state(true, serialization_state)
	if GFVariantData.get_option_int(serialization_state, _SETTING_SERIALIZATION_ERROR_COUNT_KEY, 0) > 0:
		push_error("[GFSettingsUtility] 设置数据包含循环引用，已拒绝持久化：%s。" % target_file_name)
		return ERR_INVALID_DATA
	var error: Error = _write_persisted_data(target_file_name, data)
	_clear_pending_save(target_file_name)
	if error == OK:
		settings_saved.emit(data)
	return error


## 驱动自动保存防抖。
## [br]
## @api public
## [br]
## @param delta: 距离上一帧的秒数。
func tick(delta: float = 0.0) -> void:
	if not _save_queued:
		return

	_save_elapsed_seconds += maxf(delta, 0.0)
	if _save_elapsed_seconds >= maxf(save_debounce_seconds, 0.0):
		var _flush_error: Error = flush_pending_save()


# --- 可重写钩子 / 虚方法 ---

## 读取持久化设置数据。子类可覆盖该钩子以接入自定义存储后端。
## [br]
## @api protected
## [br]
## @param file_name: 要读取的设置文件名。
## [br]
## @return 已读取的数据；不存在或无法解析时返回空字典。
## [br]
## @schema return: Dictionary[String, Variant] persisted settings data.
func _read_persisted_data(file_name: String) -> Dictionary:
	var storage: GFStorageUtility = _get_storage_utility()
	if storage != null:
		return storage.load_data(file_name)

	var path: String = _get_fallback_path(file_name)
	if path.is_empty():
		return {}
	if not FileAccess.file_exists(path):
		return {}

	var content: String = FileAccess.get_file_as_string(path)
	if content.is_empty():
		return {}

	var parsed: Variant = JSON.parse_string(content)
	return GFVariantData.as_dictionary(parsed)


## 写入持久化设置数据。子类可覆盖该钩子以接入自定义存储后端。
## [br]
## @api protected
## [br]
## @param file_name: 要写入的设置文件名。
## [br]
## @param data: 要写入的设置数据。
## [br]
## @schema data: Dictionary[String, Variant] persisted settings data produced by to_dict(true).
## [br]
## @return Godot 错误码。
func _write_persisted_data(file_name: String, data: Dictionary) -> Error:
	var storage: GFStorageUtility = _get_storage_utility()
	if storage != null:
		return storage.save_data(file_name, data)

	var path: String = _get_fallback_path(file_name)
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	var base_dir: String = path.get_base_dir()
	if not base_dir.is_empty():
		var dir_error: Error = DirAccess.make_dir_recursive_absolute(base_dir)
		if dir_error != OK:
			return dir_error

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	_store_string_checked(file, JSON.stringify(data, "\t"))
	file.close()
	return OK


# --- 私有/辅助方法 ---

func _reset_value_internal(key: StringName, emit_change: bool, save_after_change: bool) -> void:
	var definition: GFSettingDefinition = _get_definition(key)
	if definition != null:
		_set_value_internal(key, definition.default_value, emit_change, save_after_change)
		return

	if not _values.has(key):
		return

	var old_value: Variant = _values[key]
	var _erased: bool = _values.erase(key)
	if emit_change:
		setting_changed.emit(key, old_value, null)
	if save_after_change and auto_save_on_change:
		_queue_auto_save()


func _set_value_internal(
	key: StringName,
	value: Variant,
	emit_change: bool,
	save_after_change: bool
) -> void:
	if key == &"":
		push_error("[GFSettingsUtility] set_value 失败：设置键为空。")
		return

	var definition: GFSettingDefinition = _get_definition(key)
	var next_value: Variant = definition.coerce_value(value) if definition != null else value
	var old_value: Variant = GFVariantData.get_option_value(_values, key)
	if _values.has(key) and old_value == next_value:
		return

	_values[key] = next_value
	if emit_change:
		setting_changed.emit(key, old_value, next_value)

	if save_after_change and auto_save_on_change and _should_persist(key):
		_queue_auto_save()


func _stage_value_internal(key: StringName, value: Variant, emit_change: bool) -> void:
	if key == &"":
		push_error("[GFSettingsUtility] stage_value 失败：设置键为空。")
		return

	var definition: GFSettingDefinition = _get_definition(key)
	var next_value: Variant = definition.coerce_value(value) if definition != null else value
	var current_value: Variant = get_value(key)
	if current_value == next_value:
		var _discarded_equal_value: bool = _discard_staged_value_internal(key, emit_change)
		return

	var previous_staged_value: Variant = GFVariantData.get_option_value(_staged_values, key)
	if _staged_values.has(key) and previous_staged_value == next_value:
		return

	_staged_values[key] = GFVariantData.duplicate_variant(next_value)
	if emit_change:
		staged_setting_changed.emit(key)


func _discard_staged_value_internal(key: StringName, emit_change: bool) -> bool:
	if not _staged_values.has(key):
		return false

	var _erased: bool = _staged_values.erase(key)
	if emit_change:
		staged_setting_changed.emit(key)
	return true


func _reconcile_staged_value(key: StringName) -> void:
	if not _staged_values.has(key):
		return
	_stage_value_internal(key, _staged_values[key], true)


func _make_apply_values_report() -> Dictionary:
	return {
		"ok": true,
		"healthy": true,
		"applied_count": 0,
		"changed_count": 0,
		"reset_count": 0,
		"skipped_count": 0,
		"error_count": 0,
		"warning_count": 0,
		"issue_count": 0,
		"issues": [],
	}


func _add_apply_values_issue(
	report: Dictionary,
	severity: String,
	kind: String,
	key: StringName,
	message: String
) -> void:
	var issues: Array = _get_report_issues(report)
	var issue: Dictionary = {
		"severity": severity,
		"kind": kind,
		"message": message,
	}
	if key != &"":
		issue["key"] = key
	issues.append(issue)
	if severity == "error":
		_increment_report_count(report, "error_count")
	elif severity == "warning":
		_increment_report_count(report, "warning_count")


func _finalize_apply_values_report(report: Dictionary) -> void:
	report["issue_count"] = _get_report_issues(report).size()
	report["ok"] = GFVariantData.get_option_int(report, "error_count", 0) == 0
	report["healthy"] = GFVariantData.get_option_int(report, "error_count", 0) == 0 and GFVariantData.get_option_int(report, "warning_count", 0) == 0


func _normalize_apply_scope(scope_value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if scope_value is Dictionary:
		var scope_dictionary: Dictionary = scope_value
		for key_variant: Variant in scope_dictionary.keys():
			_add_scope_key(result, key_variant)
		return result
	if scope_value is PackedStringArray:
		for key: String in scope_value:
			_add_scope_key(result, key)
		return result
	if scope_value is Array:
		for key_variant: Variant in scope_value:
			_add_scope_key(result, key_variant)
		return result
	if typeof(scope_value) == TYPE_STRING or typeof(scope_value) == TYPE_STRING_NAME:
		_add_scope_key(result, scope_value)
	return result


func _add_scope_key(scope: Dictionary, key_value: Variant) -> void:
	var key: StringName = GFVariantData.to_string_name(key_value)
	if key != &"":
		scope[key] = true


func _queue_auto_save() -> void:
	if _batch_depth > 0:
		_batch_save_requested = true
		return

	queue_save()


func _clear_pending_save(file_name: String) -> void:
	var target_file_name: String = storage_file_name if file_name.is_empty() else file_name
	if _save_queued and _save_queued_file_name == target_file_name:
		_save_queued = false
		_save_elapsed_seconds = 0.0
		_save_queued_file_name = ""


func _should_persist(key: StringName) -> bool:
	var definition: GFSettingDefinition = _get_definition(key)
	return definition == null or definition.persistent


func _apply_defaults_to_missing() -> void:
	for key: StringName in _definitions.keys():
		if _values.has(key):
			continue
		var definition: GFSettingDefinition = _get_definition(key)
		if definition != null:
			_values[key] = definition.coerce_value(definition.default_value)


func _build_restored_values(data: Dictionary) -> Dictionary:
	var restored_values: Dictionary = {}
	for key_variant: Variant in data.keys():
		var key: StringName = GFVariantData.to_string_name(key_variant)
		if key == &"":
			continue
		var value: Variant = _deserialize_value(data[key_variant])
		var definition: GFSettingDefinition = _get_definition(key)
		restored_values[key] = definition.coerce_value(value) if definition != null else value

	for key: StringName in _definitions.keys():
		if restored_values.has(key):
			continue
		var definition: GFSettingDefinition = _get_definition(key)
		if definition != null:
			restored_values[key] = definition.coerce_value(definition.default_value)
	return restored_values


func _emit_replaced_value_changes(previous_values: Dictionary) -> void:
	for key_variant: Variant in previous_values.keys():
		var key: StringName = GFVariantData.to_string_name(key_variant)
		var old_value: Variant = previous_values[key_variant]
		var has_new_value: bool = _values.has(key)
		var new_value: Variant = GFVariantData.get_option_value(_values, key)
		if not has_new_value or old_value != new_value:
			setting_changed.emit(key, old_value, new_value if has_new_value else null)

	for key: StringName in _values.keys():
		if previous_values.has(key):
			continue
		setting_changed.emit(key, null, _values[key])


func _get_storage_utility() -> GFStorageUtility:
	var arch: GFArchitecture = _get_architecture_or_null()
	if arch == null:
		return null
	var utility: Variant = arch.get_utility(GFStorageUtility)
	if utility is GFStorageUtility:
		return utility
	return null


func _get_definition(key: StringName) -> GFSettingDefinition:
	var value: Variant = GFVariantData.get_option_value(_definitions, key)
	if value is GFSettingDefinition:
		var definition: GFSettingDefinition = value
		return definition
	return null


func _get_report_issues(report: Dictionary) -> Array:
	var issues_value: Variant = GFVariantData.get_option_value(report, "issues", [])
	if issues_value is Array:
		var existing_issues: Array = issues_value
		return existing_issues

	var new_issues: Array = []
	report["issues"] = new_issues
	return new_issues


func _increment_report_count(report: Dictionary, key: String) -> void:
	report[key] = GFVariantData.get_option_int(report, key, 0) + 1


func _store_string_checked(file: FileAccess, value: String) -> void:
	var store_result: Variant = file.store_string(value)
	if store_result != null:
		return


func _get_fallback_path(file_name: String) -> String:
	if file_name.is_absolute_path():
		push_error("[GFSettingsUtility] 已拒绝原生绝对设置路径：%s。" % file_name)
		return ""
	if not _is_safe_fallback_file_name(file_name):
		push_error("[GFSettingsUtility] 已拒绝不安全设置文件名：%s。" % file_name)
		return ""
	return "user://" + file_name


func _serialize_value(value: Variant) -> Variant:
	if value is Vector2:
		var vector2: Vector2 = value
		return {
			_SETTING_TYPE_KEY: "Vector2",
			"x": vector2.x,
			"y": vector2.y,
		}
	if value is Vector2i:
		var vector2i: Vector2i = value
		return {
			_SETTING_TYPE_KEY: "Vector2i",
			"x": vector2i.x,
			"y": vector2i.y,
		}
	if value is Color:
		var color: Color = value
		return {
			_SETTING_TYPE_KEY: "Color",
			"r": color.r,
			"g": color.g,
			"b": color.b,
			"a": color.a,
		}
	if typeof(value) == TYPE_STRING_NAME:
		return {
			_SETTING_TYPE_KEY: "StringName",
			_SETTING_VALUE_KEY: GFVariantData.to_text(value),
		}
	if value is Array:
		var source_array: Array = value
		return GFVariantJsonCodec.variant_to_json_compatible(source_array, { "encode_dictionary_keys": true })
	if value is Dictionary:
		var source_dictionary: Dictionary = value
		return GFVariantJsonCodec.variant_to_json_compatible(source_dictionary, { "encode_dictionary_keys": true })
	return GFVariantJsonCodec.variant_to_json_compatible(value, { "encode_dictionary_keys": true })


func _deserialize_value(value: Variant) -> Variant:
	if value is Array:
		var array_result: Array = []
		for item: Variant in value:
			array_result.append(_deserialize_value(item))
		return array_result

	if not value is Dictionary:
		return value

	var data: Dictionary = value
	if data.size() == 1 and data.has(GFVariantJsonCodec.JSON_MARKER_KEY):
		return GFVariantJsonCodec.json_compatible_to_variant(data)

	if _is_serialized_setting_wrapper(data):
		match str(data[_SETTING_TYPE_KEY]):
			"Vector2":
				return Vector2(GFVariantData.get_option_float(data, "x", 0.0), GFVariantData.get_option_float(data, "y", 0.0))
			"Vector2i":
				return Vector2i(GFVariantData.get_option_int(data, "x", 0), GFVariantData.get_option_int(data, "y", 0))
			"Color":
				return Color(
					GFVariantData.get_option_float(data, "r", 1.0),
					GFVariantData.get_option_float(data, "g", 1.0),
					GFVariantData.get_option_float(data, "b", 1.0),
					GFVariantData.get_option_float(data, "a", 1.0)
				)
			"StringName":
				return GFVariantData.get_option_string_name(data, _SETTING_VALUE_KEY, &"")

	var dictionary_result: Dictionary = {}
	for key_variant: Variant in data.keys():
		dictionary_result[key_variant] = _deserialize_value(data[key_variant])
	return dictionary_result


func _is_serialized_setting_wrapper(data: Dictionary) -> bool:
	if not data.has(_SETTING_TYPE_KEY):
		return false
	match str(data[_SETTING_TYPE_KEY]):
		"Vector2", "Vector2i":
			return data.size() == 3 and data.has("x") and data.has("y")
		"Color":
			return data.size() == 5 and data.has("r") and data.has("g") and data.has("b") and data.has("a")
		"StringName":
			return data.size() == 2 and data.has(_SETTING_VALUE_KEY)
	return false


func _to_dict_with_state(persistent_only: bool, serialization_state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in _values.keys():
		var definition: GFSettingDefinition = _get_definition(key)
		if persistent_only and definition != null and not definition.persistent:
			continue
		var serialized_value: Variant = _serialize_value(_values[key])
		if _contains_circular_reference_marker(serialized_value):
			serialization_state[_SETTING_SERIALIZATION_ERROR_COUNT_KEY] = (
				GFVariantData.get_option_int(serialization_state, _SETTING_SERIALIZATION_ERROR_COUNT_KEY, 0) + 1
			)
		result[String(key)] = serialized_value
	return result


func _is_safe_fallback_file_name(file_name: String) -> bool:
	var normalized_file_name: String = file_name.strip_edges()
	if normalized_file_name.is_empty() or normalized_file_name != file_name:
		return false
	if normalized_file_name != normalized_file_name.get_file():
		return false
	if normalized_file_name.contains(".."):
		return false
	if normalized_file_name.contains("/") or normalized_file_name.contains("\\"):
		return false
	if normalized_file_name.contains(":"):
		return false
	return true


func _contains_circular_reference_marker(value: Variant) -> bool:
	if value is Array:
		var array_value: Array = value
		for item: Variant in array_value:
			if _contains_circular_reference_marker(item):
				return true
		return false
	if not value is Dictionary:
		return false

	var dictionary_value: Dictionary = value
	if dictionary_value.has(GFVariantJsonCodec.JSON_MARKER_KEY):
		var marker: Dictionary = GFVariantData.as_dictionary(
			GFVariantData.get_option_value(dictionary_value, GFVariantJsonCodec.JSON_MARKER_KEY)
		)
		if GFVariantData.get_option_string(marker, GFVariantJsonCodec.JSON_TYPE_KEY) == "CircularReference":
			return true
	for key_variant: Variant in dictionary_value.keys():
		if _contains_circular_reference_marker(dictionary_value[key_variant]):
			return true
	return false
