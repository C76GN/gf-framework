## GFDecisionContext: 通用决策上下文。
##
## 组合黑板、主体/目标快照视图和元数据，供决策候选与考虑项读取状态。
## 赋值时先主动捕获可见值；缺失 key 可由对象的 `get_decision_value()` 按需提供并写入当前上下文缓存。
## 该类型只用弱引用暴露当前对象，不通过上下文延长对象生命周期。
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

## 主体决策值快照视图。容器会复制，但其中的 Object/Resource 身份保持共享；缺失 key 可被懒缓存补充。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema subject_values: Dictionary[StringName, Variant] eagerly captured at assignment and optionally extended by bounded lazy reads.
var subject_values: Dictionary = {}

## 目标决策值快照视图。容器会复制，但其中的 Object/Resource 身份保持共享；缺失 key 可被懒缓存补充。
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


# --- Godot 生命周期方法 ---

func _init(
	context_blackboard: GFDecisionBlackboard = null,
	context_subject: Object = null,
	context_target: Object = null,
	context_metadata: Dictionary = {},
	context_capture_options: Dictionary = {}
) -> void:
	blackboard = context_blackboard if context_blackboard != null else GFDecisionBlackboard.new()
	capture_options = context_capture_options.duplicate(true)
	_capture_diagnostics = {}
	_set_subject(context_subject)
	_set_target(context_target)
	metadata = context_metadata.duplicate(true)


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


## 从主体快照视图读取决策值；缺失 key 可触发一次受预算约束的 provider 懒读取并缓存。
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


## 从目标快照视图读取决策值；缺失 key 可触发一次受预算约束的 provider 懒读取并缓存。
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
## 默认复用 subject 与 target 弱引用；复制黑板、快照容器、捕获诊断和元数据，嵌套 Object/Resource 身份保持共享。
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
		metadata.duplicate(true),
		capture_options.duplicate(true)
	)
	var current_subject: Object = get_subject_or_null()
	var current_target: Object = get_target_or_null()
	duplicated._subject_ref = weakref(current_subject) if current_subject != null else null
	duplicated._target_ref = weakref(current_target) if current_target != null else null
	duplicated.subject_values = subject_values.duplicate(true)
	duplicated.target_values = target_values.duplicate(true)
	duplicated._capture_diagnostics = _capture_diagnostics.duplicate(true)
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
	return GFReportValueCodec.to_report_dictionary({
		"blackboard": _ensure_blackboard().get_debug_snapshot(),
		"metadata": metadata.duplicate(true),
		"subject_class": current_subject.get_class() if current_subject != null else "",
		"target_class": current_target.get_class() if current_target != null else "",
		"subject_values": subject_values.duplicate(true),
		"target_values": target_values.duplicate(true),
		"capture_diagnostics": _capture_diagnostics.duplicate(true),
	})


# --- 私有/辅助方法 ---

func _ensure_blackboard() -> GFDecisionBlackboard:
	if blackboard == null:
		blackboard = GFDecisionBlackboard.new()
	return blackboard


func _set_subject(value: Object) -> void:
	_subject_ref = weakref(value) if value != null else null
	subject_values = _snapshot_decision_object(value, &"subject")


func _set_target(value: Object) -> void:
	_target_ref = weakref(value) if value != null else null
	target_values = _snapshot_decision_object(value, &"target")


func _snapshot_decision_object(object_ref: Object, capture_slot: StringName) -> Dictionary:
	_capture_diagnostics[capture_slot] = {
		"truncated": false,
		"captured_count": 0,
		"source": &"none",
	}
	if object_ref == null or not is_instance_valid(object_ref):
		return {}

	if object_ref.has_method("get_decision_snapshot"):
		var method_snapshot: Variant = object_ref.call("get_decision_snapshot")
		if method_snapshot is Dictionary:
			var method_result: Dictionary = _copy_snapshot_dictionary(
				GFVariantData.as_dictionary(method_snapshot),
				capture_slot,
				&"get_decision_snapshot"
			)
			_apply_decision_value_overrides(object_ref, method_result)
			return method_result
	if object_ref.has_method("get_decision_values"):
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
	if not object_ref.has_method("get_decision_value"):
		return

	var sentinel: RefCounted = RefCounted.new()
	for key_variant: Variant in snapshot.keys():
		var normalized_key: Variant = _normalize_snapshot_key(key_variant)
		if not (normalized_key is StringName):
			continue

		var key: StringName = normalized_key
		var value: Variant = object_ref.call("get_decision_value", key, sentinel)
		if value is RefCounted:
			var ref_value: RefCounted = value
			if ref_value == sentinel:
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
	if object_ref == null or not is_instance_valid(object_ref) or not object_ref.has_method("get_decision_value"):
		return fallback
	var limit: int = _get_capture_limit("max_snapshot_entries", DEFAULT_MAX_SNAPSHOT_ENTRIES)
	if snapshot.size() >= limit:
		_set_capture_diagnostics(capture_slot, &"lazy_cache", snapshot.size(), true, limit)
		return fallback

	var sentinel: RefCounted = RefCounted.new()
	var value: Variant = object_ref.call("get_decision_value", key, sentinel)
	if value is RefCounted:
		var ref_value: RefCounted = value
		if ref_value == sentinel:
			return fallback
	snapshot[key] = GFVariantData.duplicate_variant(value)
	_set_capture_diagnostics(capture_slot, &"lazy_cache", snapshot.size(), false, limit)
	return GFVariantData.duplicate_variant(value)


func _snapshot_has_key(snapshot: Dictionary, key: StringName) -> bool:
	if snapshot.has(key):
		return true
	return snapshot.has(String(key))


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


func _set_capture_diagnostics(
	capture_slot: StringName,
	capture_source: StringName,
	captured_count: int,
	truncated: bool,
	limit: int
) -> void:
	var previous: Dictionary = GFVariantData.get_option_dictionary(_capture_diagnostics, capture_slot)
	_capture_diagnostics[capture_slot] = {
		"truncated": truncated or GFVariantData.get_option_bool(previous, "truncated", false),
		"captured_count": captured_count,
		"source": capture_source,
		"limit": limit,
	}
