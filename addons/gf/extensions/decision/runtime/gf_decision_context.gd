## GFDecisionContext: 通用决策上下文。
##
## 组合黑板、主体/目标快照视图和元数据，供决策候选与考虑项读取状态。
## 赋值时先主动捕获可见值；缺失 key 可由对象的 `get_decision_value()` 按需提供并写入当前上下文缓存。
## subject/target 顶层句柄使用弱引用；项目提供的快照值仍可包含 Object/Resource 强引用，
## 因此返回 self 或包含 self 的对象图会延长其生命周期。需要严格弱所有权时，provider 不得把当前对象放入快照值图。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 4.3.0
class_name GFDecisionContext
extends RefCounted


# --- 常量 ---

## 主体或目标主动捕获的默认最大条目数。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_SNAPSHOT_ENTRIES: int = 1024

## 反射属性捕获的默认最大条目数。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_REFLECTION_PROPERTIES: int = 256

const _REPORT_SCHEMA_PROJECTION = preload(
	"res://addons/gf/kernel/core/gf_report_schema_projection.gd"
)
const _HARD_MAX_CAPTURE_ENTRIES: int = 65536


# --- 公共变量 ---

## 决策黑板。
## [br]
## @api public
var blackboard: GFDecisionBlackboard = null

## 决策主体，例如当前 agent、系统或导演对象。
## [br]
## @api public
## [br]
## @since 7.0.0
var subject: Object:
	get:
		return get_subject_or_null()
	set(value):
		_set_subject(value)

## 可选决策目标。
## [br]
## @api public
## [br]
## @since 7.0.0
var target: Object:
	get:
		return get_target_or_null()
	set(value):
		_set_target(value)

## 主体决策值快照视图。容器会循环安全地复制，但其中的 Object/Resource 身份保持共享；缺失 key 可被懒缓存补充。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema subject_values: Dictionary[StringName, Variant] eagerly captured at assignment and optionally extended by bounded lazy reads.
var subject_values: Dictionary = {}

## 目标决策值快照视图。容器会循环安全地复制，但其中的 Object/Resource 身份保持共享；缺失 key 可被懒缓存补充。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema target_values: Dictionary[StringName, Variant] eagerly captured at assignment and optionally extended by bounded lazy reads.
var target_values: Dictionary = {}

## 项目自定义上下文元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary[StringName, Variant] project-defined decision metadata.
var metadata: Dictionary = {}

## 捕获预算选项。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema capture_options: Dictionary with optional max_snapshot_entries and max_reflection_properties integer fields.
var capture_options: Dictionary = {}


# --- 私有变量 ---

var _subject_ref: WeakRef = null
var _target_ref: WeakRef = null
var _capture_diagnostics: Dictionary = {}
var _capture_entries: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init(
	context_blackboard: GFDecisionBlackboard = null,
	context_subject: Object = null,
	context_target: Object = null,
	context_metadata: Dictionary = {},
	context_capture_options: Dictionary = {}
) -> void:
	blackboard = context_blackboard if context_blackboard != null else GFDecisionBlackboard.new()
	capture_options = _copy_dictionary(context_capture_options)
	_capture_diagnostics = {}
	_capture_entries = {}
	_set_subject(context_subject)
	_set_target(context_target)
	metadata = _copy_dictionary(context_metadata)


# --- 公共方法 ---

## 设置黑板值。
## [br]
## @api public
## [br]
## @param key: 值键。
## [br]
## @param value: 要写入或修改的值。
## [br]
## @schema value: 要写入黑板的任意项目值。
func set_value(key: StringName, value: Variant) -> void:
	_ensure_blackboard().set_value(key, value)


## 获取黑板值。
## [br]
## @api public
## [br]
## @param key: 值键。
## [br]
## @param default_value: 缺失时返回的默认值。
## [br]
## @return: 黑板值或默认值。
## [br]
## @schema default_value: 黑板缺失时返回的任意默认值。
## [br]
## @schema return: 黑板中的项目值，或传入的 default_value。
func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return _ensure_blackboard().get_value(key, default_value)


## 检查黑板值是否存在。
## [br]
## @api public
## [br]
## @param key: 值键。
## [br]
## @return: 存在返回 true。
func has_value(key: StringName) -> bool:
	return _ensure_blackboard().has_value(key)


## 设置元数据值。
## [br]
## @api public
## [br]
## @param key: 元数据键。
## [br]
## @param value: 元数据值。
## [br]
## @schema value: 要写入元数据的任意项目值。
func set_metadata_value(key: StringName, value: Variant) -> void:
	if key == &"":
		return
	metadata[key] = value


## 获取元数据值。
## [br]
## @api public
## [br]
## @param key: 元数据键。
## [br]
## @param default_value: 缺失时返回的默认值。
## [br]
## @return: 元数据值或默认值。
## [br]
## @schema default_value: 元数据缺失时返回的任意默认值。
## [br]
## @schema return: 元数据中的项目值，或传入的 default_value。
func get_metadata_value(key: StringName, default_value: Variant = null) -> Variant:
	return GFVariantData.get_option_value(metadata, key, default_value)


## 从主体快照视图读取决策值；每个缺失 key 最多触发一次受预算约束的 provider 懒读取，miss 也会负缓存并消费预算。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param key: 值键或属性名。
## [br]
## @param fallback: 读取失败时的兜底值。
## [br]
## @return: 主体值或兜底值。
## [br]
## @schema fallback: 读取失败时返回的任意项目值。
## [br]
## @schema return: 从主体读取的项目值，或传入的 fallback。
func get_subject_value(key: StringName, fallback: Variant = null) -> Variant:
	return _read_object_snapshot_value(subject_values, get_subject_or_null(), key, fallback, &"subject")


## 从目标快照视图读取决策值；每个缺失 key 最多触发一次受预算约束的 provider 懒读取，miss 也会负缓存并消费预算。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param key: 值键或属性名。
## [br]
## @param fallback: 读取失败时的兜底值。
## [br]
## @return: 目标值或兜底值。
## [br]
## @schema fallback: 读取失败时返回的任意项目值。
## [br]
## @schema return: 从目标读取的项目值，或传入的 fallback。
func get_target_value(key: StringName, fallback: Variant = null) -> Variant:
	return _read_object_snapshot_value(target_values, get_target_or_null(), key, fallback, &"target")


## 获取当前主体对象；对象已释放时返回 null。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return: 当前主体对象或 null。
func get_subject_or_null() -> Object:
	if _subject_ref == null:
		return null
	var value: Variant = _subject_ref.get_ref()
	if value is Object and is_instance_valid(value):
		var object_value: Object = value
		return object_value
	return null


## 获取当前目标对象；对象已释放时返回 null。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return: 当前目标对象或 null。
func get_target_or_null() -> Object:
	if _target_ref == null:
		return null
	var value: Variant = _target_ref.get_ref()
	if value is Object and is_instance_valid(value):
		var object_value: Object = value
		return object_value
	return null


## 创建上下文副本。
##
## 默认复用 subject 与 target 弱引用；循环安全地复制黑板、快照容器、捕获账本、诊断和元数据，嵌套 Object/Resource 身份保持共享。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return: 新上下文实例。
func duplicate_context() -> GFDecisionContext:
	var duplicated: GFDecisionContext = GFDecisionContext.new(
		_ensure_blackboard().duplicate_blackboard(),
		null,
		null,
		_copy_dictionary(metadata),
		_copy_dictionary(capture_options)
	)
	var current_subject: Object = get_subject_or_null()
	var current_target: Object = get_target_or_null()
	duplicated._subject_ref = weakref(current_subject) if current_subject != null else null
	duplicated._target_ref = weakref(current_target) if current_target != null else null
	duplicated.subject_values = _copy_dictionary(subject_values)
	duplicated.target_values = _copy_dictionary(target_values)
	duplicated._capture_diagnostics = _copy_dictionary(_capture_diagnostics)
	duplicated._capture_entries = _copy_dictionary(_capture_entries)
	return duplicated


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 4.3.0
## [br]
## @return: 调试快照字典。
## [br]
## @schema return: JSON-safe Dictionary，包含 blackboard、metadata、subject_class、target_class、subject_values、target_values 和 capture_diagnostics 字段。
func get_debug_snapshot() -> Dictionary:
	var current_subject: Object = get_subject_or_null()
	var current_target: Object = get_target_or_null()
	var report_options: Dictionary = {}
	return {
		"blackboard": GFReportValueCodec.to_report_dictionary(
			_ensure_blackboard().get_debug_snapshot(),
			report_options
		),
		"metadata": _REPORT_SCHEMA_PROJECTION.to_report_dictionary(metadata, report_options),
		"subject_class": current_subject.get_class() if current_subject != null else "",
		"target_class": current_target.get_class() if current_target != null else "",
		"subject_values": _REPORT_SCHEMA_PROJECTION.to_report_dictionary(
			subject_values,
			report_options
		),
		"target_values": _REPORT_SCHEMA_PROJECTION.to_report_dictionary(
			target_values,
			report_options
		),
		"capture_diagnostics": _REPORT_SCHEMA_PROJECTION.to_report_dictionary(
			_capture_diagnostics,
			report_options
		),
	}


# --- 私有/辅助方法 ---

func _ensure_blackboard() -> GFDecisionBlackboard:
	if blackboard == null:
		blackboard = GFDecisionBlackboard.new()
	return blackboard


func _set_subject(value: Object) -> void:
	_reset_capture_slot(&"subject")
	_subject_ref = weakref(value) if value != null else null
	subject_values = _snapshot_decision_object(value, &"subject")
	_seed_capture_entries(&"subject", subject_values)


func _set_target(value: Object) -> void:
	_reset_capture_slot(&"target")
	_target_ref = weakref(value) if value != null else null
	target_values = _snapshot_decision_object(value, &"target")
	_seed_capture_entries(&"target", target_values)


func _snapshot_decision_object(object_ref: Object, capture_slot: StringName) -> Dictionary:
	_capture_diagnostics[capture_slot] = {
		"truncated": false,
		"captured_count": 0,
		"source": &"none",
	}
	if object_ref == null or not is_instance_valid(object_ref):
		return {}

	if _can_invoke_provider_method(object_ref, &"get_decision_snapshot", 0):
		var method_snapshot: Variant = object_ref.call("get_decision_snapshot")
		if method_snapshot is Dictionary:
			var method_result: Dictionary = _copy_snapshot_dictionary(
				GFVariantData.as_dictionary(method_snapshot),
				capture_slot,
				&"get_decision_snapshot"
			)
			_apply_decision_value_overrides(object_ref, method_result)
			return method_result
	if _can_invoke_provider_method(object_ref, &"get_decision_values", 0):
		var method_values: Variant = object_ref.call("get_decision_values")
		if method_values is Dictionary:
			var values_result: Dictionary = _copy_snapshot_dictionary(
				GFVariantData.as_dictionary(method_values),
				capture_slot,
				&"get_decision_values"
			)
			_apply_decision_value_overrides(object_ref, values_result)
			return values_result

	var snapshot: Dictionary = _snapshot_object_properties(object_ref, capture_slot)
	_apply_decision_value_overrides(object_ref, snapshot)
	return snapshot


func _copy_snapshot_dictionary(
	source: Dictionary,
	capture_slot: StringName,
	capture_source: StringName
) -> Dictionary:
	var snapshot: Dictionary = {}
	var limit: int = _get_capture_limit("max_snapshot_entries", DEFAULT_MAX_SNAPSHOT_ENTRIES)
	var eligible_count: int = 0
	for key_variant: Variant in source.keys():
		var normalized_key: Variant = _normalize_snapshot_key(key_variant)
		if not normalized_key is StringName:
			continue
		eligible_count += 1
		if snapshot.size() >= limit:
			continue
		snapshot[normalized_key] = GFVariantData.duplicate_variant(source[key_variant])
	_set_capture_diagnostics(capture_slot, capture_source, snapshot.size(), eligible_count > snapshot.size(), limit)
	return snapshot


func _snapshot_object_properties(object_ref: Object, capture_slot: StringName) -> Dictionary:
	var snapshot: Dictionary = {}
	var limit: int = _get_capture_limit("max_reflection_properties", DEFAULT_MAX_REFLECTION_PROPERTIES)
	var eligible_count: int = 0
	for property_info: Dictionary in object_ref.get_property_list():
		var usage: int = GFVariantData.get_option_int(property_info, "usage")
		if usage & PROPERTY_USAGE_STORAGE == 0 and usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var property_name: String = GFVariantData.get_option_string(property_info, "name")
		if property_name.is_empty() or property_name == "script":
			continue
		eligible_count += 1
		if snapshot.size() >= limit:
			continue
		var value: Variant = object_ref.get(property_name)
		snapshot[StringName(property_name)] = GFVariantData.duplicate_variant(value)
	_set_capture_diagnostics(capture_slot, &"reflection", snapshot.size(), eligible_count > snapshot.size(), limit)
	return snapshot


func _apply_decision_value_overrides(object_ref: Object, snapshot: Dictionary) -> void:
	if not _can_invoke_provider_method(object_ref, &"get_decision_value", 2):
		return

	var sentinel: RefCounted = RefCounted.new()
	for key_variant: Variant in snapshot.keys():
		var normalized_key: Variant = _normalize_snapshot_key(key_variant)
		if not (normalized_key is StringName):
			continue

		var key: StringName = normalized_key
		var value: Variant = object_ref.call("get_decision_value", key, sentinel)
		if value is RefCounted and is_same(value, sentinel):
			continue
		snapshot[key] = GFVariantData.duplicate_variant(value)


func _read_snapshot_value(snapshot: Dictionary, key: StringName, fallback: Variant = null) -> Variant:
	if snapshot.has(key):
		return GFVariantData.duplicate_variant(snapshot[key])
	var string_key: String = String(key)
	if snapshot.has(string_key):
		return GFVariantData.duplicate_variant(snapshot[string_key])
	return fallback


func _read_object_snapshot_value(
	snapshot: Dictionary,
	object_ref: Object,
	key: StringName,
	fallback: Variant,
	capture_slot: StringName
) -> Variant:
	if _snapshot_has_key(snapshot, key):
		return _read_snapshot_value(snapshot, key, fallback)
	var capture_entries: Dictionary = _get_capture_entries(capture_slot)
	if _snapshot_has_key(capture_entries, key):
		return fallback
	if object_ref == null or not is_instance_valid(object_ref):
		return fallback
	var limit: int = _get_capture_limit("max_snapshot_entries", DEFAULT_MAX_SNAPSHOT_ENTRIES)
	var attempted_count: int = capture_entries.size()
	if attempted_count >= limit:
		_set_capture_diagnostics(
			capture_slot,
			&"lazy_cache",
			snapshot.size(),
			true,
			limit,
			attempted_count
		)
		return fallback

	# Reserve the key before executing project code. The entry remains as the hard
	# per-frame call ledger; when the provider returns the sentinel it also serves
	# as the negative-cache entry and blocks same-key reentry.
	capture_entries[key] = true
	attempted_count += 1
	if not _can_invoke_provider_method(object_ref, &"get_decision_value", 2):
		_set_capture_diagnostics(
			capture_slot,
			&"lazy_cache",
			snapshot.size(),
			false,
			limit,
			attempted_count
		)
		return fallback
	var sentinel: RefCounted = RefCounted.new()
	var value: Variant = object_ref.call("get_decision_value", key, sentinel)
	if not is_same(_get_capture_entries(capture_slot), capture_entries):
		return fallback
	if value is RefCounted and is_same(value, sentinel):
		_set_capture_diagnostics(
			capture_slot,
			&"lazy_cache",
			snapshot.size(),
			false,
			limit,
			attempted_count
		)
		return fallback
	snapshot[key] = GFVariantData.duplicate_variant(value)
	_set_capture_diagnostics(
		capture_slot,
		&"lazy_cache",
		snapshot.size(),
		false,
		limit,
		attempted_count
	)
	return GFVariantData.duplicate_variant(value)


func _snapshot_has_key(snapshot: Dictionary, key: StringName) -> bool:
	if snapshot.has(key):
		return true
	return snapshot.has(String(key))


func _get_capture_entries(capture_slot: StringName) -> Dictionary:
	var value: Variant = _capture_entries.get(capture_slot)
	if value is Dictionary:
		var entries: Dictionary = value
		return entries
	var created: Dictionary = {}
	_capture_entries[capture_slot] = created
	return created


func _seed_capture_entries(capture_slot: StringName, snapshot: Dictionary) -> void:
	var entries: Dictionary = _get_capture_entries(capture_slot)
	for key_variant: Variant in snapshot.keys():
		var normalized_key: Variant = _normalize_snapshot_key(key_variant)
		if normalized_key is StringName:
			entries[normalized_key] = true


func _reset_capture_slot(capture_slot: StringName) -> void:
	_capture_entries[capture_slot] = {}
	var _diagnostics_erased: bool = _capture_diagnostics.erase(capture_slot)


func _normalize_snapshot_key(key: Variant) -> Variant:
	if key is StringName:
		return key
	if key is String:
		var string_key: String = key
		return StringName(string_key)
	return key


func _get_capture_limit(option_name: String, default_value: int) -> int:
	return clampi(
		GFVariantData.get_option_int(capture_options, option_name, default_value),
		0,
		_HARD_MAX_CAPTURE_ENTRIES
	)


func _can_invoke_provider_method(
	object_ref: Object,
	method_name: StringName,
	argument_count: int
) -> bool:
	if object_ref == null or not is_instance_valid(object_ref) or not object_ref.has_method(method_name):
		return false
	for method_info: Dictionary in object_ref.get_method_list():
		if GFVariantData.get_option_string_name(method_info, "name") != method_name:
			continue
		var arguments: Array = GFVariantData.get_option_array(method_info, "args")
		var default_arguments: Array = GFVariantData.get_option_array(method_info, "default_args")
		if default_arguments.size() > arguments.size():
			return false
		var required_count: int = arguments.size() - default_arguments.size()
		var method_flags: int = GFVariantData.get_option_int(method_info, "flags", 0)
		var accepts_varargs: bool = (method_flags & METHOD_FLAG_VARARG) != 0
		return (
			required_count <= argument_count
			and (argument_count <= arguments.size() or accepts_varargs)
		)
	return false


func _copy_dictionary(source: Dictionary) -> Dictionary:
	var copied: Variant = GFVariantData.duplicate_variant(source)
	if copied is Dictionary:
		var copied_dictionary: Dictionary = copied
		return copied_dictionary
	return {}


func _set_capture_diagnostics(
	capture_slot: StringName,
	capture_source: StringName,
	captured_count: int,
	truncated: bool,
	limit: int,
	attempted_count: int = -1
) -> void:
	var previous: Dictionary = GFVariantData.get_option_dictionary(_capture_diagnostics, capture_slot)
	var resolved_attempted_count: int = captured_count if attempted_count < 0 else attempted_count
	_capture_diagnostics[capture_slot] = {
		"truncated": truncated or GFVariantData.get_option_bool(previous, "truncated", false),
		"captured_count": captured_count,
		"attempted_count": resolved_attempted_count,
		"source": capture_source,
		"limit": limit,
	}
