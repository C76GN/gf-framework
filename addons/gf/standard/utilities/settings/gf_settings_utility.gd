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

## 设置加载进入终态时发出。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param result: 隔离的结构化加载结果。
signal settings_load_completed(result: GFSettingsLoadResult)

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
const _SAVE_RECORD_ID_KEY: String = "record_id"
const _SAVE_RECORD_FILE_NAME_KEY: String = "file_name"
const _SAVE_RECORD_DATA_KEY: String = "data"
const _SAVE_RECORD_ELAPSED_SECONDS_KEY: String = "elapsed_seconds"
const _SAVE_RECORD_CAPTURE_ERROR_CODE_KEY: String = "capture_error_code"
const _SAVE_RECORD_AUTO_RETRY_BLOCKED_KEY: String = "auto_retry_blocked"
const _FLUSH_REPORT_ATTEMPTED_RECORD_IDS_KEY: String = "attempted_record_ids"


# --- 公共变量 ---

## 默认持久化文件名。
## [br]
## @api public
var storage_file_name: String = "settings.sav"

## standalone 模式在 init()、Architecture 模式在 activation 阶段是否自动读取持久化设置。
## [br]
## @api public
## [br]
## @since 3.17.0
var auto_load_on_init: bool = true

## set_value() 修改持久化设置时是否自动保存。
## [br]
## @api public
var auto_save_on_change: bool = true

## 自动保存的防抖秒数；小于等于 0 时保持立即保存。
## [br]
## @api public
var save_debounce_seconds: float = 0.25

## 是否启用设置持久化。
##
## 架构模式启用时必须注册唯一的 GFSettingsStoreUtility；关闭时设置工具保持纯内存模式。
## [br]
## @api public
## [br]
## @since unreleased
var persistence_enabled: bool = true:
	set(value):
		if _settings_store_binding_frozen and persistence_enabled != value:
			push_error("[GFSettingsUtility] persistence_enabled 在生命周期计划冻结后不可修改。")
			return
		persistence_enabled = value


# --- 私有变量 ---

var _definitions: Dictionary = {}
var _values: Dictionary = {}
var _staged_values: Dictionary = {}
var _pending_save_records: Array[Dictionary] = []
var _batch_save_records: Array[Dictionary] = []
var _batch_depth: int = 0
var _last_load_result: GFSettingsLoadResult = null
var _settings_store: GFSettingsStoreUtility = null
var _owns_settings_store: bool = false
var _settings_store_binding_frozen: bool = false
var _architecture_mode: bool = false
var _mutation_admission_open: bool = true
var _disposed: bool = false
var _initialized: bool = false
var _activation_started: bool = false
var _load_store_on_activation: bool = false
var _next_save_record_id: int = 1
var _quiesce_completion: GFAsyncCompletion = null
var _lifecycle_critical_depth: int = 0
var _critical_exit_processing: bool = false
var _persistence_hook_depth: int = 0
var _save_flush_in_progress: bool = false
var _quiesce_prepared: bool = false
var _quiesce_flush_started: bool = false
var _quiesce_join_active_flush: bool = false
var _quiesce_joined_flush_report: Dictionary = {}
var _dispose_requested: bool = false


# --- GF 生命周期方法 ---

## 初始化设置工具，并在 standalone 模式按配置自动加载持久化设置或应用默认值。
## [br]
## @api public
## [br]
## @since 3.17.0
func init() -> void:
	if (
		_initialized
		or _disposed
		or _dispose_requested
		or _quiesce_completion != null
	):
		return
	_settings_store_binding_frozen = true
	_initialized = true
	if not persistence_enabled:
		_apply_defaults_to_missing()
		return
	if not _architecture_mode and _settings_store == null:
		var _replace_error: Error = _replace_settings_store(
			GFSettingsFileStoreUtility.new(),
			true
		)
	if not auto_load_on_init:
		_apply_defaults_to_missing()
		return
	if _architecture_mode:
		return
	_enter_lifecycle_critical()
	var store_available: bool = false
	if _settings_store != null:
		_persistence_hook_depth += 1
		store_available = _settings_store.is_persistence_enabled()
		_persistence_hook_depth -= 1
	if _disposed or _dispose_requested:
		_leave_lifecycle_critical()
		return
	if store_available:
		var _load_result: GFSettingsLoadResult = _load_settings_admitted(
			storage_file_name,
			null
		)
	else:
		_apply_defaults_to_missing()
	_leave_lifecycle_critical()


## 返回设置持久化端口依赖。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 启用持久化时仅包含 GFSettingsStoreUtility，否则为空。
func get_required_utilities() -> Array[Script]:
	var dependencies: Array[Script] = []
	if persistence_enabled:
		dependencies.append(GFSettingsStoreUtility)
	return dependencies


## 在架构 ready 阶段解析唯一的设置持久化端口。
## [br]
## @api public
## [br]
## @since unreleased
func ready() -> void:
	if not _architecture_mode or not persistence_enabled:
		return
	var store_value: Object = get_utility(GFSettingsStoreUtility, true)
	if store_value is GFSettingsStoreUtility:
		var architecture_store: GFSettingsStoreUtility = store_value
		var _replace_error: Error = _replace_settings_store(architecture_store, false)


## 在依赖完成 activation 后执行架构模式的自动加载。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param _scope: 当前 Settings 激活阶段的取消作用域。
## [br]
## @return Store 可用并完成同步自动加载尝试时成功的一次性完成源。
func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
	_activation_started = true
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	if _disposed or _dispose_requested:
		var _failed_disposed: bool = completion.fail("Settings utility is disposed.")
		return completion
	if _quiesce_completion != null:
		var _failed_quiesced: bool = completion.fail(
			"Settings utility cannot reactivate after quiesce."
		)
		return completion
	_enter_lifecycle_critical()
	var store_available: bool = not persistence_enabled
	if persistence_enabled and _settings_store != null:
		_persistence_hook_depth += 1
		store_available = _settings_store.is_persistence_enabled()
		_persistence_hook_depth -= 1
	var activation_error: String = ""
	if _disposed or _dispose_requested:
		activation_error = "Settings utility was disposed during activation."
	elif not store_available:
		activation_error = (
			"GFSettingsStoreUtility must be available before Settings activation."
		)
	else:
		if (
			(_architecture_mode or _load_store_on_activation)
			and persistence_enabled
			and auto_load_on_init
		):
			var _load_result: GFSettingsLoadResult = _load_settings_admitted(
				storage_file_name,
				null
			)
		_load_store_on_activation = false
		if _disposed or _dispose_requested:
			activation_error = "Settings utility was disposed during activation."
		elif _quiesce_completion == null:
			_mutation_admission_open = true
	_leave_lifecycle_critical()
	if _disposed or _dispose_requested:
		var _failed_disposed_during_activation: bool = completion.fail(
			"Settings utility was disposed during activation."
		)
	elif not activation_error.is_empty():
		var _failed_activation: bool = completion.fail(activation_error)
	else:
		var _succeeded_activation: bool = completion.succeed()
	return completion


## 停止接纳设置变化与保存请求，并排空全部已接纳的冻结保存记录。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param scope: 当前 Settings 静默阶段的取消作用域。
## [br]
## @return 全部已接纳记录成功持久化时成功；失败时保留 target 证据；scope 取消时返回 CANCELLED，提升开放 batch 但不启动新 I/O，并保留 pending 供显式重试。
func begin_quiesce(scope: GFAsyncScope) -> GFAsyncCompletion:
	_mutation_admission_open = false
	if _quiesce_completion != null:
		return _quiesce_completion
	_quiesce_completion = GFAsyncCompletion.new()
	_quiesce_join_active_flush = _save_flush_in_progress
	if scope != null:
		var _bound: bool = _quiesce_completion.bind_cancel_token(scope)
	if _disposed or _dispose_requested:
		if _quiesce_completion.is_pending():
			var _succeeded_disposed: bool = _quiesce_completion.succeed()
		return _quiesce_completion
	_progress_lifecycle_exit()
	return _quiesce_completion


## 释放设置工具，并清理内存状态；持久化排空由 begin_quiesce() 负责。
## [br]
## @api public
## [br]
## @since 3.17.0
func dispose() -> void:
	_mutation_admission_open = false
	if _disposed:
		return
	if _lifecycle_critical_depth > 0 or _critical_exit_processing:
		_dispose_requested = true
		return
	_dispose_now()


## 释放架构 Store 引用和基类依赖作用域。
## [br]
## @api public
## [br]
## @since unreleased
func release_dependencies() -> void:
	_architecture_mode = false
	if not _owns_settings_store:
		_settings_store = null
	super.release_dependencies()


# --- 公共方法 ---

## 注册一个设置定义。
## [br]
## @api public
## [br]
## @param definition: 设置定义。
## [br]
## @param apply_default: 缺少当前值时是否写入默认值。
func register_definition(definition: GFSettingDefinition, apply_default: bool = true) -> void:
	if not _can_accept_mutation("register_definition"):
		return
	_enter_lifecycle_critical()
	_register_definition_internal(definition, apply_default)
	_leave_lifecycle_critical()


## 使用参数快速注册一个设置定义。
## [br]
## @api public
## [br]
## @since 3.17.0
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
## @return 注册成功时返回新设置定义；mutation gate 关闭时返回 null。
func register_setting(
	key: StringName,
	default_value: Variant = null,
	value_type: GFSettingDefinition.ValueType = GFSettingDefinition.ValueType.ANY,
	persistent: bool = true,
	metadata: Dictionary = {}
) -> GFSettingDefinition:
	if not _can_accept_mutation("register_setting"):
		return null
	_enter_lifecycle_critical()
	var definition: GFSettingDefinition = GFSettingDefinition.new()
	definition.key = key
	definition.default_value = default_value
	definition.value_type = value_type
	definition.persistent = persistent
	definition.metadata = metadata.duplicate(true)
	_register_definition_internal(definition)
	_leave_lifecycle_critical()
	return definition


## 批量注册设置定义。
## [br]
## @api public
## [br]
## @param definitions: 设置定义数组。
func register_definitions(definitions: Array[GFSettingDefinition]) -> void:
	if not _can_accept_mutation("register_definitions"):
		return
	_enter_lifecycle_critical()
	for definition: GFSettingDefinition in definitions:
		_register_definition_internal(definition)
	_leave_lifecycle_critical()


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
	if not _can_accept_mutation("set_value"):
		return
	_enter_lifecycle_critical()
	_set_value_internal(key, value, true, save_after_change)
	_leave_lifecycle_critical()


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
	if not _can_accept_mutation("stage_value"):
		return
	_enter_lifecycle_critical()
	_stage_value_internal(key, value, true)
	_leave_lifecycle_critical()


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
	if not _can_accept_mutation("discard_staged_value"):
		return false
	_enter_lifecycle_critical()
	var discarded: bool = _discard_staged_value_internal(key, true)
	if discarded:
		var keys: PackedStringArray = PackedStringArray()
		var _key_appended: bool = keys.append(String(key))
		staged_settings_discarded.emit(keys)
	_leave_lifecycle_critical()
	return discarded


## 丢弃全部暂存值。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 被丢弃暂存值的设置键。
func discard_staged_values() -> PackedStringArray:
	if not _can_accept_mutation("discard_staged_values"):
		return PackedStringArray()
	_enter_lifecycle_critical()
	var discarded_keys: PackedStringArray = _discard_staged_values_internal()
	_leave_lifecycle_critical()
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
	if not _can_accept_mutation("apply_staged_values"):
		var rejected_report: Dictionary = _make_rejected_apply_values_report()
		rejected_report["staged_applied_count"] = 0
		rejected_report["staged_remaining_count"] = _staged_values.size()
		rejected_report["staged_applied_keys"] = PackedStringArray()
		return rejected_report
	_enter_lifecycle_critical()
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
	var report: Dictionary = _apply_values_internal(selected_values, apply_options)
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
	_leave_lifecycle_critical()
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
	if not _can_accept_mutation("apply_values"):
		return _make_rejected_apply_values_report()
	_enter_lifecycle_critical()
	var report: Dictionary = _apply_values_internal(values, options)
	_leave_lifecycle_critical()
	return report


## 开始一批设置修改。批处理中自动保存会延后到 end_batch()。
## [br]
## @api public
func begin_batch() -> void:
	if not _can_accept_mutation("begin_batch"):
		return
	_begin_batch_internal()


## 结束一批设置修改，并在需要时合并触发一次自动保存。
## [br]
## @api public
## [br]
## @param save_after_change: 本批变化结束后是否允许保存。
func end_batch(save_after_change: bool = true) -> void:
	if not _can_accept_mutation("end_batch"):
		return
	_end_batch_internal(save_after_change)


## 将当前设置标记为稍后保存，受 save_debounce_seconds 控制。
## [br]
## @api public
func queue_save() -> void:
	if not _can_accept_mutation("queue_save") or not persistence_enabled:
		return
	var record: Dictionary = _capture_save_record(storage_file_name)
	var record_id: int = _upsert_save_record(_pending_save_records, record)
	if save_debounce_seconds <= 0.0:
		var record_ids: Array[int] = [record_id]
		var _flush_report: Dictionary = _flush_pending_save_records(record_ids)


## 立即执行正在等待的自动保存。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 返回 OK、ERR_UNAVAILABLE、ERR_BUSY、冻结快照捕获错误或 Store 写入错误。
func flush_pending_save() -> Error:
	if _disposed or _dispose_requested:
		return ERR_UNAVAILABLE
	var flush_report: Dictionary = _flush_pending_save_records()
	return GFVariantData.get_option_int(flush_report, "error_code", int(OK)) as Error


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
	if not _can_accept_mutation("reset_value"):
		return
	_enter_lifecycle_critical()
	_reset_value_internal(key, true, save_after_change)
	_leave_lifecycle_critical()


## 重置所有已定义设置到默认值，并移除未定义的临时设置。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param save_after_change: 是否保存。
func reset_all(save_after_change: bool = true) -> void:
	if not _can_accept_mutation("reset_all"):
		return
	_enter_lifecycle_critical()
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
	_leave_lifecycle_critical()


## 转换为可持久化字典。
## [br]
## @api public
## [br]
## @since 3.17.0
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
	if not _can_accept_mutation("replace_from_dict"):
		return
	_enter_lifecycle_critical()
	_replace_from_dict_internal(data, emit_changes)
	_leave_lifecycle_critical()


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
	if not _can_accept_mutation("merge_from_dict"):
		return
	_enter_lifecycle_critical()
	for key_variant: Variant in data.keys():
		var key: StringName = GFVariantData.to_string_name(key_variant)
		_set_value_internal(key, _deserialize_value(data[key_variant]), emit_changes, false)
	_apply_defaults_to_missing()
	for staged_key_variant: Variant in _staged_values.keys():
		_reconcile_staged_value(GFVariantData.to_string_name(staged_key_variant))
	_leave_lifecycle_critical()


## 读取持久化设置并返回结构化终态。
##
## 默认策略严格失败；缺失、损坏、未来 schema、迁移失败或 IO 失败不会被
## 降级为空字典。只有显式恢复策略可以处理缺失或损坏，且加载本身从不保存。
## 非空策略会在 IO 前验证；合法加载请求会取消全部旧延迟/批处理保存请求，
## 防止新加载状态被旧保存目标重新序列化。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param file_name: 可选文件名；为空时使用 storage_file_name。
## [br]
## @param recovery_policy: 可选显式恢复策略；null 表示严格失败。
## [br]
## @return 隔离的结构化加载结果。
## [br]
## @schema return: GFSettingsLoadResult preserving status, application state, recovery action, and storage evidence.
func load_settings(
	file_name: String = "",
	recovery_policy: GFSettingsRecoveryPolicy = null
) -> GFSettingsLoadResult:
	var target_file_name: String = storage_file_name if file_name.is_empty() else file_name
	if _disposed or _dispose_requested:
		return _make_unavailable_settings_load_result(
			target_file_name,
			"Settings utility is disposed."
		)
	if not persistence_enabled:
		return _complete_settings_load(
			_make_unavailable_settings_load_result(
				target_file_name,
				"Settings persistence is disabled."
			)
		)
	if not _can_accept_mutation("load_settings"):
		return _complete_settings_load(
			_make_unavailable_settings_load_result(
				target_file_name,
				"Settings no longer accepts load requests."
			)
		)
	_enter_lifecycle_critical()
	var completed_result: GFSettingsLoadResult = _load_settings_admitted(
		target_file_name,
		recovery_policy
	)
	_leave_lifecycle_critical()
	return completed_result


## 获取最近一次加载终态。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 最近结果的隔离副本；尚未加载或已释放时为 null。
func get_last_load_result() -> GFSettingsLoadResult:
	return _last_load_result.duplicate_result() if _last_load_result != null else null


## 保存持久化设置。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param file_name: 可选文件名；为空时使用 storage_file_name。
## [br]
## @return 返回 OK、ERR_UNAVAILABLE、ERR_BUSY、快照捕获错误或 Store 写入错误。
func save_settings(file_name: String = "") -> Error:
	if not _can_accept_mutation("save_settings") or not persistence_enabled:
		return ERR_UNAVAILABLE
	var target_file_name: String = storage_file_name if file_name.is_empty() else file_name
	var record: Dictionary = _capture_save_record(target_file_name)
	var record_id: int = _upsert_save_record(_pending_save_records, record)
	var record_ids: Array[int] = [record_id]
	var flush_report: Dictionary = _flush_pending_save_records(record_ids)
	return GFVariantData.get_option_int(flush_report, "error_code", int(OK)) as Error


## 驱动自动保存防抖。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param delta: 距离上一帧的秒数。
func tick(delta: float = 0.0) -> void:
	if not _mutation_admission_open or _pending_save_records.is_empty():
		return
	var due_record_ids: Array[int] = []
	var debounce_seconds: float = maxf(save_debounce_seconds, 0.0)
	for record: Dictionary in _pending_save_records:
		if GFVariantData.get_option_bool(
			record,
			_SAVE_RECORD_AUTO_RETRY_BLOCKED_KEY,
			false
		):
			continue
		var elapsed_seconds: float = GFVariantData.get_option_float(
			record,
			_SAVE_RECORD_ELAPSED_SECONDS_KEY,
			0.0
		)
		elapsed_seconds += maxf(delta, 0.0)
		record[_SAVE_RECORD_ELAPSED_SECONDS_KEY] = elapsed_seconds
		if elapsed_seconds >= debounce_seconds:
			due_record_ids.append(
				GFVariantData.get_option_int(record, _SAVE_RECORD_ID_KEY, 0)
			)
	if not due_record_ids.is_empty():
		var _flush_report: Dictionary = _flush_pending_save_records(due_record_ids)


# --- 可重写钩子 / 虚方法 ---

## 读取持久化设置数据。子类可覆盖该钩子以接入自定义存储后端。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param file_name: 要读取的设置文件名。
## [br]
## @return 保留成功空载荷与稳定失败分类的存储读取结果。
## [br]
## @schema return: GFStorageReadResult with isolated Settings payload and failure_kind evidence.
func _read_persisted_data(file_name: String) -> GFStorageReadResult:
	if not persistence_enabled or _settings_store == null:
		return _make_persisted_read_failure(
			"Settings persistence store is unavailable.",
			ERR_UNAVAILABLE,
			GFStorageReadResult.FailureKind.UNAVAILABLE
		)
	var read_result: GFStorageReadResult = _settings_store.read_settings(file_name)
	if read_result == null:
		return _make_persisted_read_failure(
			"Settings storage returned no read result.",
			ERR_INVALID_DATA,
			GFStorageReadResult.FailureKind.IO_FAILED
		)
	return read_result.duplicate_result()


## 写入持久化设置数据。子类可覆盖该钩子以接入自定义存储后端。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param file_name: 要写入的设置文件名。
## [br]
## @param data: 要写入的设置数据。
## [br]
## @schema data: Dictionary[String, Variant] persisted settings data produced by to_dict(true).
## [br]
## @return Godot 错误码。
func _write_persisted_data(file_name: String, data: Dictionary) -> Error:
	if not persistence_enabled or _settings_store == null:
		return ERR_UNAVAILABLE
	return _settings_store.write_settings(file_name, data.duplicate(true))


# --- 框架内部方法 ---

## 记录当前 Settings Utility 已由 Architecture 精确挂载，并注入依赖作用域。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param architecture: 当前注册该 Settings Utility 的架构。
func inject_dependencies(architecture: GFArchitecture) -> void:
	super.inject_dependencies(architecture)
	_architecture_mode = architecture != null


## 在 activation 前注入 standalone Settings Store。
##
## standalone 可在 init() 前注入，也可在 init()/ready 后、activation 前替换。
## Architecture 模式、activation、quiesce、dispose 或存在已接纳保存记录后拒绝替换，
## 避免改变声明依赖或冻结快照的物理目标语义。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param store: 新的同步 Settings Store；null 表示清除当前 Store。
## [br]
## @param owns: Settings Utility 是否负责 dispose 该 Store。
## [br]
## @return 注入成功返回 OK；生命周期或待保存状态已冻结时返回 ERR_BUSY。
func set_settings_store_for_framework(
	store: GFSettingsStoreUtility,
	owns: bool = false
) -> Error:
	if (
		_disposed
		or _architecture_mode
		or _activation_started
		or _quiesce_completion != null
		or not _pending_save_records.is_empty()
		or not _batch_save_records.is_empty()
		or _batch_depth > 0
		or _lifecycle_critical_depth > 0
		or _persistence_hook_depth > 0
		or _save_flush_in_progress
	):
		return ERR_BUSY
	var replace_error: Error = _replace_settings_store(store, owns)
	if replace_error != OK:
		return replace_error
	if _initialized and not _architecture_mode:
		_load_store_on_activation = persistence_enabled and auto_load_on_init
	return OK


# --- 私有/辅助方法 ---

func _dispose_now() -> void:
	if _disposed:
		return
	_dispose_requested = false
	_disposed = true
	var owned_store: GFSettingsStoreUtility = _settings_store if _owns_settings_store else null
	_settings_store = null
	_owns_settings_store = false
	_definitions.clear()
	_values.clear()
	_staged_values.clear()
	_pending_save_records.clear()
	_batch_save_records.clear()
	_batch_depth = 0
	_last_load_result = null
	_quiesce_joined_flush_report.clear()
	if owned_store != null:
		owned_store.dispose()


func _register_definition_internal(
	definition: GFSettingDefinition,
	apply_default: bool = true
) -> void:
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


func _discard_staged_values_internal() -> PackedStringArray:
	var discarded_keys: PackedStringArray = get_staged_keys()
	for key_text: String in discarded_keys:
		var _discarded: bool = _discard_staged_value_internal(StringName(key_text), true)
	if not discarded_keys.is_empty():
		staged_settings_discarded.emit(discarded_keys)
	return discarded_keys


func _apply_values_internal(values: Dictionary, options: Dictionary) -> Dictionary:
	var report: Dictionary = _make_apply_values_report()
	var save_after_change: bool = GFVariantData.get_option_bool(options, "save_after_change", true)
	var emit_changes: bool = GFVariantData.get_option_bool(options, "emit_changes", true)
	var reset_missing: bool = GFVariantData.get_option_bool(options, "reset_missing", false)
	var scope: Dictionary = _normalize_apply_scope(
		GFVariantData.get_option_value(options, "scope", [])
	)
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

	_begin_batch_internal()
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

	_end_batch_internal(save_after_change)
	_finalize_apply_values_report(report)
	return report


func _begin_batch_internal() -> void:
	_batch_depth += 1


func _end_batch_internal(save_after_change: bool = true) -> void:
	if _batch_depth <= 0:
		return

	_batch_depth -= 1
	if _batch_depth > 0:
		return
	if not save_after_change or not auto_save_on_change:
		_batch_save_records.clear()
		return

	var promoted_record_ids: Array[int] = _promote_batch_save_records()
	if (
		_quiesce_completion == null
		and not _dispose_requested
		and save_debounce_seconds <= 0.0
		and not promoted_record_ids.is_empty()
	):
		var _flush_report: Dictionary = _flush_pending_save_records(promoted_record_ids)


func _replace_from_dict_internal(data: Dictionary, emit_changes: bool = true) -> void:
	var previous_values: Dictionary = _values.duplicate(false)
	_values = _build_restored_values(data)
	if emit_changes:
		_emit_replaced_value_changes(previous_values)
		var _discarded_staged_keys: PackedStringArray = _discard_staged_values_internal()
	else:
		_staged_values.clear()


func _load_settings_admitted(
	target_file_name: String,
	recovery_policy: GFSettingsRecoveryPolicy
) -> GFSettingsLoadResult:
	if recovery_policy != null:
		var policy_report: Dictionary = recovery_policy.validate_policy()
		if _disposed or _dispose_requested:
			return _make_unavailable_settings_load_result(
				target_file_name,
				"Settings utility was disposed during recovery policy validation."
			)
		if not GFVariantData.get_option_bool(policy_report, "ok", false):
			var policy_read_result: GFStorageReadResult = _make_persisted_read_failure(
				"Settings recovery policy is invalid.",
				ERR_INVALID_PARAMETER,
				GFStorageReadResult.FailureKind.INVALID_REQUEST
			)
			return _complete_settings_load(
				_make_settings_load_result(
					false,
					GFSettingsLoadResult.STATUS_INVALID_REQUEST,
					target_file_name,
					false,
					false,
					&"",
					ERR_INVALID_PARAMETER,
					"Settings recovery policy is invalid.",
					policy_read_result
				)
			)

	_clear_pending_saves_for_load()
	_persistence_hook_depth += 1
	var read_result: GFStorageReadResult = _read_persisted_data(target_file_name)
	_persistence_hook_depth -= 1
	if _disposed or _dispose_requested:
		return _make_unavailable_settings_load_result(
			target_file_name,
			"Settings utility was disposed during load."
		)
	if read_result == null:
		read_result = _make_persisted_read_failure(
			"Settings storage returned no read result.",
			ERR_INVALID_DATA,
			GFStorageReadResult.FailureKind.IO_FAILED
		)

	var load_result: GFSettingsLoadResult
	if read_result.ok and read_result.is_integrity_accepted():
		_replace_from_dict_internal(read_result.payload, false)
		load_result = _make_settings_load_result(
			true,
			GFSettingsLoadResult.STATUS_LOADED,
			target_file_name,
			true,
			false,
			&"",
			OK,
			"",
			read_result
		)
	else:
		var failure_status: StringName = _get_settings_load_failure_status(read_result)
		var recovery_action: StringName = _resolve_settings_recovery_action(
			read_result,
			recovery_policy
		)
		match recovery_action:
			GFSettingsRecoveryPolicy.ACTION_USE_CURRENT_STATE:
				load_result = _make_settings_load_result(
					true,
					GFSettingsLoadResult.STATUS_RECOVERED,
					target_file_name,
					false,
					true,
					recovery_action,
					OK,
					"",
					read_result
				)
			GFSettingsRecoveryPolicy.ACTION_RESET_TO_DEFAULTS:
				_replace_from_dict_internal({}, false)
				load_result = _make_settings_load_result(
					true,
					GFSettingsLoadResult.STATUS_RECOVERED,
					target_file_name,
					true,
					true,
					recovery_action,
					OK,
					"",
					read_result
				)
			_:
				var failure_error_code: Error = _get_settings_load_error_code(read_result)
				var failure_error: String = _get_settings_load_error(
					read_result,
					failure_status
				)
				load_result = _make_settings_load_result(
					false,
					failure_status,
					target_file_name,
					false,
					false,
					&"",
					failure_error_code,
					failure_error,
					read_result
				)

	return _complete_settings_load(load_result)


func _enter_lifecycle_critical() -> void:
	_lifecycle_critical_depth += 1


func _leave_lifecycle_critical() -> void:
	assert(_lifecycle_critical_depth > 0)
	_lifecycle_critical_depth -= 1
	_progress_lifecycle_exit()


func _progress_lifecycle_exit() -> void:
	if _lifecycle_critical_depth > 0 or _critical_exit_processing:
		return
	_critical_exit_processing = true
	_try_finish_quiesce()
	if _dispose_requested:
		_dispose_now()
	_critical_exit_processing = false


func _try_finish_quiesce() -> void:
	if (
		_quiesce_completion == null
		or _quiesce_prepared
		or _quiesce_flush_started
		or _lifecycle_critical_depth > 0
	):
		return
	_quiesce_prepared = true
	_promote_open_batch_save_records()
	if not _quiesce_completion.is_pending():
		return
	_quiesce_flush_started = true
	var flush_report: Dictionary
	if _quiesce_join_active_flush:
		var attempted_record_ids: Array[int] = _get_flush_report_attempted_record_ids(
			_quiesce_joined_flush_report
		)
		var remaining_record_ids: Array[int] = []
		for record: Dictionary in _pending_save_records:
			var record_id: int = GFVariantData.get_option_int(
				record,
				_SAVE_RECORD_ID_KEY,
				0
			)
			if not attempted_record_ids.has(record_id):
				remaining_record_ids.append(record_id)
		var remaining_flush_report: Dictionary = {}
		if not remaining_record_ids.is_empty():
			remaining_flush_report = _flush_pending_save_records(
				remaining_record_ids,
				true
			)
		flush_report = _merge_flush_reports(
			_quiesce_joined_flush_report,
			remaining_flush_report
		)
	else:
		flush_report = _flush_pending_save_records([], true)
	if not _quiesce_completion.is_pending():
		return
	var flush_error: Error = (
		GFVariantData.get_option_int(flush_report, "error_code", int(OK)) as Error
	)
	if flush_error != OK:
		var failed_file_names: PackedStringArray = PackedStringArray()
		var failed_file_names_value: Variant = GFVariantData.get_option_value(
			flush_report,
			"failed_file_names",
			PackedStringArray()
		)
		if failed_file_names_value is PackedStringArray:
			failed_file_names = failed_file_names_value
		var failure_metadata: Dictionary = {
			"failed_file_names": failed_file_names,
			"error_codes": GFVariantData.get_option_dictionary(flush_report, "error_codes"),
			"pending_file_names": _get_pending_save_file_names(),
			"failed_count": GFVariantData.get_option_int(flush_report, "failed_count"),
			"pending_count": _pending_save_records.size(),
		}
		var _failed_flush: bool = _quiesce_completion.fail(
			"Settings pending saves failed to flush.",
			failure_metadata
		)
		return
	var _succeeded: bool = _quiesce_completion.succeed()


func _get_flush_report_attempted_record_ids(report: Dictionary) -> Array[int]:
	var record_ids: Array[int] = []
	var record_ids_value: Variant = GFVariantData.get_option_value(
		report,
		_FLUSH_REPORT_ATTEMPTED_RECORD_IDS_KEY,
		[]
	)
	if not record_ids_value is Array:
		return record_ids
	var source_record_ids: Array = record_ids_value
	for record_id_value: Variant in source_record_ids:
		var record_id: int = GFVariantData.to_int(record_id_value)
		if record_id > 0 and not record_ids.has(record_id):
			record_ids.append(record_id)
	return record_ids


func _merge_flush_reports(first_report: Dictionary, second_report: Dictionary) -> Dictionary:
	var first_error: Error = (
		GFVariantData.get_option_int(first_report, "error_code", int(OK)) as Error
	)
	var second_error: Error = (
		GFVariantData.get_option_int(second_report, "error_code", int(OK)) as Error
	)
	var error_codes: Dictionary = GFVariantData.get_option_dictionary(
		first_report,
		"error_codes"
	)
	for file_name_value: Variant in GFVariantData.get_option_dictionary(
		second_report,
		"error_codes"
	).keys():
		var file_name: String = GFVariantData.to_text(file_name_value)
		error_codes[file_name] = GFVariantData.get_option_int(
			GFVariantData.get_option_dictionary(second_report, "error_codes"),
			file_name
		)
	var failed_file_names: PackedStringArray = PackedStringArray()
	for record: Dictionary in _pending_save_records:
		var file_name: String = GFVariantData.get_option_string(
			record,
			_SAVE_RECORD_FILE_NAME_KEY
		)
		if error_codes.has(file_name):
			var _file_name_appended: bool = failed_file_names.append(file_name)
	var attempted_record_ids: Array[int] = _get_flush_report_attempted_record_ids(
		first_report
	)
	for record_id: int in _get_flush_report_attempted_record_ids(second_report):
		if not attempted_record_ids.has(record_id):
			attempted_record_ids.append(record_id)
	return {
		"error_code": int(first_error if first_error != OK else second_error),
		"failed_file_names": failed_file_names,
		"error_codes": error_codes,
		"failed_count": failed_file_names.size(),
		_FLUSH_REPORT_ATTEMPTED_RECORD_IDS_KEY: attempted_record_ids,
	}


func _make_settings_load_result(
	ok: bool,
	status: StringName,
	file_name: String,
	applied: bool,
	recovered: bool,
	recovery_action: StringName,
	error_code: Error,
	error_message: String,
	storage_result: GFStorageReadResult
) -> GFSettingsLoadResult:
	var result: GFSettingsLoadResult = GFSettingsLoadResult.new()
	var configured: bool = result.configure_for_framework(
		ok,
		status,
		file_name,
		applied,
		recovered,
		recovery_action,
		error_code,
		error_message,
		storage_result
	)
	assert(configured, "GFSettingsUtility produced an invalid load result.")
	return result


func _make_unavailable_settings_load_result(
	file_name: String,
	error_message: String
) -> GFSettingsLoadResult:
	var read_result: GFStorageReadResult = _make_persisted_read_failure(
		error_message,
		ERR_UNAVAILABLE,
		GFStorageReadResult.FailureKind.UNAVAILABLE
	)
	return _make_settings_load_result(
		false,
		GFSettingsLoadResult.STATUS_STORAGE_FAILED,
		file_name,
		false,
		false,
		&"",
		ERR_UNAVAILABLE,
		error_message,
		read_result
	)


func _get_settings_load_failure_status(read_result: GFStorageReadResult) -> StringName:
	if read_result.ok and not read_result.is_integrity_accepted():
		return GFSettingsLoadResult.STATUS_CORRUPT

	match read_result.failure_kind:
		GFStorageReadResult.FailureKind.INVALID_REQUEST:
			return GFSettingsLoadResult.STATUS_INVALID_REQUEST
		GFStorageReadResult.FailureKind.NOT_FOUND:
			return GFSettingsLoadResult.STATUS_MISSING
		GFStorageReadResult.FailureKind.CORRUPT:
			return GFSettingsLoadResult.STATUS_CORRUPT
		GFStorageReadResult.FailureKind.FUTURE_VERSION:
			return GFSettingsLoadResult.STATUS_FUTURE_SCHEMA
		GFStorageReadResult.FailureKind.MIGRATION_FAILED:
			return GFSettingsLoadResult.STATUS_MIGRATION_FAILED
		_:
			return GFSettingsLoadResult.STATUS_STORAGE_FAILED


func _resolve_settings_recovery_action(
	read_result: GFStorageReadResult,
	recovery_policy: GFSettingsRecoveryPolicy
) -> StringName:
	if recovery_policy == null:
		return GFSettingsRecoveryPolicy.ACTION_FAIL

	var failure_status: StringName = _get_settings_load_failure_status(read_result)
	match failure_status:
		GFSettingsLoadResult.STATUS_MISSING:
			return recovery_policy.missing_file_action
		GFSettingsLoadResult.STATUS_CORRUPT:
			return recovery_policy.corrupt_file_action
		_:
			return GFSettingsRecoveryPolicy.ACTION_FAIL


func _get_settings_load_error_code(read_result: GFStorageReadResult) -> Error:
	if read_result.ok and not read_result.is_integrity_accepted():
		return ERR_FILE_CORRUPT
	return read_result.error_code if read_result.error_code != OK else FAILED


func _get_settings_load_error(
	read_result: GFStorageReadResult,
	failure_status: StringName
) -> String:
	if read_result.ok and not read_result.is_integrity_accepted():
		return "Settings integrity status is not accepted."
	if not read_result.error.is_empty():
		return read_result.error
	return "Settings load failed with status: %s." % String(failure_status)


func _make_persisted_read_failure(
	error_message: String,
	error_code: Error,
	failure_kind: GFStorageReadResult.FailureKind
) -> GFStorageReadResult:
	return GFStorageReadResult.new().configure_failure(
		error_message,
		error_code,
		{},
		GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
		0,
		failure_kind
	)


func _complete_settings_load(
	load_result: GFSettingsLoadResult
) -> GFSettingsLoadResult:
	_last_load_result = load_result.duplicate_result()
	settings_load_completed.emit(load_result.duplicate_result())
	return load_result


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


func _make_rejected_apply_values_report() -> Dictionary:
	var report: Dictionary = _make_apply_values_report()
	_add_apply_values_issue(
		report,
		"error",
		"settings_quiescing",
		&"",
		"Settings 已停止接纳新的设置变化。"
	)
	_finalize_apply_values_report(report)
	return report


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
	if (
		not persistence_enabled
		or _disposed
		or _persistence_hook_depth > 0
		or (not _mutation_admission_open and _lifecycle_critical_depth <= 0)
	):
		return
	var record: Dictionary = _capture_save_record(storage_file_name)
	if _batch_depth > 0:
		var _record_id: int = _upsert_save_record(_batch_save_records, record)
		return
	var record_id: int = _upsert_save_record(_pending_save_records, record)
	if (
		_quiesce_completion == null
		and not _dispose_requested
		and save_debounce_seconds <= 0.0
	):
		var record_ids: Array[int] = [record_id]
		var _flush_report: Dictionary = _flush_pending_save_records(record_ids)


func _capture_save_record(file_name: String) -> Dictionary:
	var target_file_name: String = storage_file_name if file_name.is_empty() else file_name
	var serialization_state: Dictionary = {}
	var data: Dictionary = _to_dict_with_state(true, serialization_state)
	var capture_error_code: Error = OK
	if (
		GFVariantData.get_option_int(
			serialization_state,
			_SETTING_SERIALIZATION_ERROR_COUNT_KEY,
			0
		) > 0
	):
		push_error(
			"[GFSettingsUtility] 设置数据包含循环引用，已拒绝持久化：%s。" % target_file_name
		)
		capture_error_code = ERR_INVALID_DATA
		data = {}
	var record: Dictionary = {
		_SAVE_RECORD_ID_KEY: _next_save_record_id,
		_SAVE_RECORD_FILE_NAME_KEY: target_file_name,
		_SAVE_RECORD_DATA_KEY: data.duplicate(true),
		_SAVE_RECORD_ELAPSED_SECONDS_KEY: 0.0,
		_SAVE_RECORD_CAPTURE_ERROR_CODE_KEY: int(capture_error_code),
		_SAVE_RECORD_AUTO_RETRY_BLOCKED_KEY: false,
	}
	_next_save_record_id += 1
	return record


func _upsert_save_record(records: Array[Dictionary], record: Dictionary) -> int:
	var file_name: String = GFVariantData.get_option_string(
		record,
		_SAVE_RECORD_FILE_NAME_KEY
	)
	for record_index: int in range(records.size()):
		var existing_record: Dictionary = records[record_index]
		if (
			GFVariantData.get_option_string(
				existing_record,
				_SAVE_RECORD_FILE_NAME_KEY
			) == file_name
		):
			records[record_index] = record
			return GFVariantData.get_option_int(record, _SAVE_RECORD_ID_KEY, 0)
	records.append(record)
	return GFVariantData.get_option_int(record, _SAVE_RECORD_ID_KEY, 0)


func _promote_batch_save_records() -> Array[int]:
	var promoted_record_ids: Array[int] = []
	for record: Dictionary in _batch_save_records:
		promoted_record_ids.append(_upsert_save_record(_pending_save_records, record))
	_batch_save_records.clear()
	return promoted_record_ids


func _promote_open_batch_save_records() -> void:
	_batch_depth = 0
	var _promoted_record_ids: Array[int] = _promote_batch_save_records()


func _flush_pending_save_records(
	record_ids: Array[int] = [],
	is_quiesce_drain: bool = false
) -> Dictionary:
	if _save_flush_in_progress or _persistence_hook_depth > 0:
		return {
			"error_code": int(ERR_BUSY),
			"failed_file_names": PackedStringArray(),
			"error_codes": {},
			"failed_count": 0,
			_FLUSH_REPORT_ATTEMPTED_RECORD_IDS_KEY: [],
		}
	_save_flush_in_progress = true
	_enter_lifecycle_critical()
	var records_to_flush: Array[Dictionary] = []
	for record: Dictionary in _pending_save_records:
		var record_id: int = GFVariantData.get_option_int(record, _SAVE_RECORD_ID_KEY, 0)
		if not record_ids.is_empty() and not record_ids.has(record_id):
			continue
		records_to_flush.append(record.duplicate(true))

	var first_error: Error = OK
	var failed_file_names: PackedStringArray = PackedStringArray()
	var error_codes: Dictionary = {}
	var attempted_record_ids: Array[int] = []
	for record: Dictionary in records_to_flush:
		var record_id: int = GFVariantData.get_option_int(record, _SAVE_RECORD_ID_KEY, 0)
		if _find_pending_save_record_index(record_id) < 0:
			continue
		if _should_stop_current_flush_for_quiesce(is_quiesce_drain):
			if not is_quiesce_drain and first_error == OK:
				first_error = ERR_BUSY
			break
		attempted_record_ids.append(record_id)
		var file_name: String = GFVariantData.get_option_string(
			record,
			_SAVE_RECORD_FILE_NAME_KEY
		)
		var data_value: Variant = GFVariantData.get_option_value(
			record,
			_SAVE_RECORD_DATA_KEY,
			{}
		)
		var error: Error = (
			GFVariantData.get_option_int(
				record,
				_SAVE_RECORD_CAPTURE_ERROR_CODE_KEY,
				int(OK)
			) as Error
		)
		if error == OK and data_value is Dictionary:
			var data: Dictionary = data_value
			_persistence_hook_depth += 1
			error = _write_persisted_data(file_name, data)
			_persistence_hook_depth -= 1
		elif error == OK:
			error = ERR_INVALID_DATA
		if error == OK:
			_erase_pending_save_record(record_id)
			if data_value is Dictionary:
				var saved_data: Dictionary = data_value
				settings_saved.emit(saved_data.duplicate(true))
			continue
		if first_error == OK:
			first_error = error
		var _file_name_appended: bool = failed_file_names.append(file_name)
		error_codes[file_name] = int(error)
		_mark_pending_save_record_failed(record_id)

	var flush_report: Dictionary = {
		"error_code": int(first_error),
		"failed_file_names": failed_file_names,
		"error_codes": error_codes,
		"failed_count": failed_file_names.size(),
		_FLUSH_REPORT_ATTEMPTED_RECORD_IDS_KEY: attempted_record_ids,
	}
	if _quiesce_join_active_flush and not _quiesce_prepared:
		_quiesce_joined_flush_report = flush_report.duplicate(true)
	_save_flush_in_progress = false
	_leave_lifecycle_critical()
	return flush_report


func _should_stop_current_flush_for_quiesce(is_quiesce_drain: bool) -> bool:
	if _quiesce_completion == null or _quiesce_completion.is_pending():
		return false
	if is_quiesce_drain:
		return true
	return _quiesce_join_active_flush and not _quiesce_prepared


func _find_pending_save_record_index(record_id: int) -> int:
	for record_index: int in range(_pending_save_records.size()):
		if (
			GFVariantData.get_option_int(
				_pending_save_records[record_index],
				_SAVE_RECORD_ID_KEY,
				0
			) == record_id
		):
			return record_index
	return -1


func _erase_pending_save_record(record_id: int) -> void:
	var record_index: int = _find_pending_save_record_index(record_id)
	if record_index >= 0:
		_pending_save_records.remove_at(record_index)


func _mark_pending_save_record_failed(record_id: int) -> void:
	var record_index: int = _find_pending_save_record_index(record_id)
	if record_index >= 0:
		_pending_save_records[record_index][_SAVE_RECORD_ELAPSED_SECONDS_KEY] = 0.0
		_pending_save_records[record_index][_SAVE_RECORD_AUTO_RETRY_BLOCKED_KEY] = true


func _get_pending_save_file_names() -> PackedStringArray:
	var file_names: PackedStringArray = PackedStringArray()
	for record: Dictionary in _pending_save_records:
		var _file_name_appended: bool = file_names.append(
			GFVariantData.get_option_string(record, _SAVE_RECORD_FILE_NAME_KEY)
		)
	return file_names


func _clear_pending_saves_for_load() -> void:
	_pending_save_records.clear()
	_batch_save_records.clear()
	_batch_depth = 0


func _can_accept_mutation(_operation: String) -> bool:
	if (
		_mutation_admission_open
		and not _disposed
		and not _dispose_requested
		and _persistence_hook_depth <= 0
	):
		return true
	return false


func _replace_settings_store(store: GFSettingsStoreUtility, owns: bool) -> Error:
	if _disposed or _dispose_requested or _quiesce_completion != null:
		return ERR_BUSY
	if _settings_store == store:
		_owns_settings_store = owns and store != null
		return OK
	_enter_lifecycle_critical()
	var expected_owns_store: bool = owns and store != null
	var owned_store: GFSettingsStoreUtility = _settings_store if _owns_settings_store else null
	_settings_store = store
	_owns_settings_store = expected_owns_store
	if owned_store != null:
		_persistence_hook_depth += 1
		owned_store.dispose()
		_persistence_hook_depth -= 1
	_leave_lifecycle_critical()
	var replace_error: Error = (
		ERR_BUSY
		if (
			_disposed
			or _dispose_requested
			or _settings_store != store
			or _owns_settings_store != expected_owns_store
		)
		else OK
	)
	return replace_error


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
