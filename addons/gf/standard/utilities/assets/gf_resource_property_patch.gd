## GFResourcePropertyPatch: 通用资源属性差异补丁。
##
## 用声明式属性列表和覆盖值描述一份 Resource 或 Object 的小范围差异。
## 它只会写入声明过的属性路径，不规定资源类型、主题语义或项目业务规则。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 7.0.0
class_name GFResourcePropertyPatch
extends Resource


# --- 常量 ---

## 定义字段：属性路径。
## [br]
## @api public
## [br]
## @since 7.0.0
const KEY_PROPERTY_PATH: String = "property_path"

## 定义字段：Godot Variant 类型。
## [br]
## @api public
## [br]
## @since 7.0.0
const KEY_TYPE: String = "type"

## 定义字段：Inspector hint。
## [br]
## @api public
## [br]
## @since 7.0.0
const KEY_HINT: String = "hint"

## 定义字段：Inspector hint_string。
## [br]
## @api public
## [br]
## @since 7.0.0
const KEY_HINT_STRING: String = "hint_string"

## 定义字段：Inspector 分组名。
## [br]
## @api public
## [br]
## @since 7.0.0
const KEY_GROUP: String = "group"

## 定义字段：属性默认值。
## [br]
## @api public
## [br]
## @since 7.0.0
const KEY_DEFAULT_VALUE: String = "default_value"

## 定义字段：是否允许补丁值为 null。
## [br]
## @api public
## [br]
## @since 7.0.0
const KEY_ALLOW_NULL: String = "allow_null"


# --- 导出变量 ---

## 可被补丁写入的属性定义列表。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema definitions: Array[Dictionary]，每项可由 make_definition() 创建，包含 property_path、type、hint、hint_string、group、default_value 与 allow_null。
@export var definitions: Array = []

## 当前启用的覆盖值。键为属性路径，值为要写入目标的 Variant。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema values: Dictionary[StringName, Variant]，只会应用 definitions 声明过的属性路径。
@export var values: Dictionary = {}

## 项目自定义元数据。GF 不解释该字段。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema metadata: Dictionary[String, Variant]，项目工具或编辑器 UI 自行读取的补充信息。
@export var metadata: Dictionary = {}

## build() 时是否默认复制 base Resource 后再应用补丁。
## [br]
## @api public
## [br]
## @since 7.0.0
var duplicate_base_on_build: bool = true

## 应用补丁时是否默认要求目标对象已经声明对应属性。
## [br]
## @api public
## [br]
## @since 7.0.0
var require_existing_property: bool = true

## 写入目标前是否默认复制 Array、Dictionary 与 Resource 值。
## [br]
## @api public
## [br]
## @since 7.0.0
var copy_values: bool = true

## 复制值时是否默认复制 Resource 实例。
## [br]
## @api public
## [br]
## @since 7.0.0
var duplicate_resources: bool = false


# --- 公共方法 ---

## 设置一个补丁值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param property_path: 已声明的属性路径。
## [br]
## @param value: 要保存的补丁值。
## [br]
## @return: 设置成功返回 true。
## [br]
## @schema value: Variant，必须符合对应 definition 的类型与 allow_null 约束。
func set_patch_value(property_path: StringName, value: Variant) -> bool:
	if not has_definition(property_path):
		return false
	values[property_path] = GFVariantData.duplicate_variant(value, true, duplicate_resources)
	emit_changed()
	return true


## 检查当前补丁是否包含指定属性值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param property_path: 属性路径。
## [br]
## @return: 已设置补丁值时返回 true。
func has_patch_value(property_path: StringName) -> bool:
	return _find_dictionary_key(values, property_path) != null


## 获取一个补丁值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param property_path: 属性路径。
## [br]
## @param default_value: 未设置时返回的默认值。
## [br]
## @return: 补丁值副本或默认值。
## [br]
## @schema default_value: Variant fallback value returned unchanged when no patch value exists.
## [br]
## @schema return: Variant patch value copy or default value.
func get_patch_value(property_path: StringName, default_value: Variant = null) -> Variant:
	var key: Variant = _find_dictionary_key(values, property_path)
	if key == null:
		return default_value
	return GFVariantData.duplicate_variant(values[key], true, duplicate_resources)


## 移除一个补丁值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param property_path: 属性路径。
## [br]
## @return: 实际移除时返回 true。
func clear_patch_value(property_path: StringName) -> bool:
	var key: Variant = _find_dictionary_key(values, property_path)
	if key == null:
		return false
	var removed: bool = values.erase(key)
	if removed:
		emit_changed()
	return removed


## 检查属性路径是否已被 definitions 声明。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param property_path: 属性路径。
## [br]
## @return: 已声明时返回 true。
func has_definition(property_path: StringName) -> bool:
	return _build_definition_map(definitions).has(_normalize_property_path(property_path))


## 应用当前补丁到目标对象。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param target: 目标对象。
## [br]
## @param options: 应用选项。
## [br]
## @return: 应用报告。
## [br]
## @schema options: Dictionary，支持 require_existing_property、copy_values、duplicate_resources、skip_unchanged。
## [br]
## @schema return: Dictionary，包含 ok、applied_count、failed_count、skipped_count、unchanged_count、applied_paths、skipped_paths 与 errors。
func apply(target: Object, options: Dictionary = {}) -> Dictionary:
	return apply_values(target, definitions, values, _merge_default_options(options))


## 复制或修改 base Resource，并应用当前补丁。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param base_resource: 来源资源。
## [br]
## @param options: 构建选项。
## [br]
## @return: 构建报告，成功或部分成功时 resource 字段为结果资源。
## [br]
## @schema options: Dictionary，支持 duplicate_base、require_existing_property、copy_values、duplicate_resources、skip_unchanged。
## [br]
## @schema return: Dictionary，包含 apply_values() 报告字段和 resource。
func build(base_resource: Resource, options: Dictionary = {}) -> Dictionary:
	var merged_options: Dictionary = _merge_default_options(options)
	if not merged_options.has("duplicate_base"):
		merged_options["duplicate_base"] = duplicate_base_on_build
	return build_resource(base_resource, definitions, values, merged_options)


## 收集目标对象上的当前属性值，替换当前补丁值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param target: 目标对象。
## [br]
## @param options: 收集选项。
## [br]
## @return: 收集到的补丁值。
## [br]
## @schema options: Dictionary，支持 require_existing_property、include_null、copy_values、duplicate_resources。
## [br]
## @schema return: Dictionary[StringName, Variant]，以声明属性路径为键的值字典。
func collect_from(target: Object, options: Dictionary = {}) -> Dictionary:
	var collected: Dictionary = collect_values(target, definitions, _merge_default_options(options))
	values = collected
	emit_changed()
	return collected.duplicate(true)


## 获取当前补丁值副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return: 补丁值字典副本。
## [br]
## @schema return: Dictionary[StringName, Variant]，当前 patch values 的副本。
func get_patch_values() -> Dictionary:
	return _normalize_patch_values(values, true, duplicate_resources)


## 创建一个属性定义。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param property_path: 属性路径。
## [br]
## @param property_type: Godot Variant 类型；TYPE_NIL 表示不做类型约束。
## [br]
## @param options: 定义选项。
## [br]
## @return: 属性定义字典。
## [br]
## @schema options: Dictionary，支持 hint、hint_string、group、default_value、allow_null。
## [br]
## @schema return: Dictionary resource property patch definition.
static func make_definition(
	property_path: StringName,
	property_type: int = TYPE_NIL,
	options: Dictionary = {}
) -> Dictionary:
	var definition: Dictionary = {
		KEY_PROPERTY_PATH: property_path,
		KEY_TYPE: property_type,
	}
	if options.has(KEY_HINT):
		definition[KEY_HINT] = GFVariantData.get_option_int(options, KEY_HINT)
	if options.has(KEY_HINT_STRING):
		definition[KEY_HINT_STRING] = GFVariantData.get_option_string(options, KEY_HINT_STRING)
	if options.has(KEY_GROUP):
		definition[KEY_GROUP] = GFVariantData.get_option_string(options, KEY_GROUP)
	if options.has(KEY_DEFAULT_VALUE):
		definition[KEY_DEFAULT_VALUE] = GFVariantData.duplicate_variant(
			GFVariantData.get_option_value(options, KEY_DEFAULT_VALUE),
			true,
			GFVariantData.get_option_bool(options, "duplicate_resources", false)
		)
	if options.has(KEY_ALLOW_NULL):
		definition[KEY_ALLOW_NULL] = GFVariantData.get_option_bool(options, KEY_ALLOW_NULL)
	return definition


## 构建通用 Inspector 属性列表。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param patch_definitions: 属性定义列表。
## [br]
## @param patch_values: 当前启用的覆盖值。
## [br]
## @param options: 属性列表选项。
## [br]
## @return: Godot _get_property_list() 可返回的属性列表。
## [br]
## @schema patch_definitions: Array[Dictionary] created by make_definition() or compatible dictionaries.
## [br]
## @schema patch_values: Dictionary[StringName, Variant] patch values used to mark storage usage.
## [br]
## @schema options: Dictionary，支持 group_prefix、usage。
## [br]
## @schema return: Array[Dictionary] property list entries.
static func make_property_list(
	patch_definitions: Array,
	patch_values: Dictionary = {},
	options: Dictionary = {}
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var current_group: String = ""
	var group_prefix: String = GFVariantData.get_option_string(options, "group_prefix", "")
	var base_usage: int = GFVariantData.get_option_int(
		options,
		"usage",
		PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_CHECKABLE
	)
	for definition_variant: Variant in patch_definitions:
		var definition: Dictionary = GFVariantData.as_dictionary(definition_variant)
		var property_path: StringName = _get_definition_path(definition)
		if property_path == &"":
			continue
		var group_name: String = GFVariantData.get_option_string(definition, KEY_GROUP)
		if group_name != current_group:
			current_group = group_name
			if not current_group.is_empty():
				entries.append(_make_group_entry(group_prefix, current_group))

		var entry: Dictionary = _make_property_entry(definition, property_path, patch_values, base_usage)
		entries.append(entry)
	return entries


## 收集目标对象上的属性值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param target: 目标对象。
## [br]
## @param patch_definitions: 属性定义列表。
## [br]
## @param options: 收集选项。
## [br]
## @return: 以声明属性路径为键的值字典。
## [br]
## @schema patch_definitions: Array[Dictionary] created by make_definition() or compatible dictionaries.
## [br]
## @schema options: Dictionary，支持 require_existing_property、include_null、copy_values、duplicate_resources。
## [br]
## @schema return: Dictionary[StringName, Variant] collected values.
static func collect_values(target: Object, patch_definitions: Array, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	if target == null:
		return result

	var require_property: bool = GFVariantData.get_option_bool(options, "require_existing_property", true)
	var include_null: bool = GFVariantData.get_option_bool(options, "include_null", false)
	var should_copy_values: bool = GFVariantData.get_option_bool(options, "copy_values", true)
	var should_duplicate_resources: bool = GFVariantData.get_option_bool(options, "duplicate_resources", false)
	for definition_variant: Variant in patch_definitions:
		var definition: Dictionary = GFVariantData.as_dictionary(definition_variant)
		var property_path: StringName = _get_definition_path(definition)
		if property_path == &"":
			continue
		if require_property and not _object_has_property(target, property_path):
			continue
		var value: Variant = target.get(String(property_path))
		if value == null and not include_null:
			continue
		result[property_path] = _copy_value(value, should_copy_values, should_duplicate_resources)
	return result


## 应用属性值到目标对象。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param target: 目标对象。
## [br]
## @param patch_definitions: 属性定义列表。
## [br]
## @param patch_values: 要应用的补丁值。
## [br]
## @param options: 应用选项。
## [br]
## @return: 应用报告。
## [br]
## @schema patch_definitions: Array[Dictionary] created by make_definition() or compatible dictionaries.
## [br]
## @schema patch_values: Dictionary[StringName, Variant] patch values.
## [br]
## @schema options: Dictionary，支持 require_existing_property、copy_values、duplicate_resources、skip_unchanged。
## [br]
## @schema return: Dictionary，包含 ok、applied_count、failed_count、skipped_count、unchanged_count、applied_paths、skipped_paths 与 errors。
static func apply_values(
	target: Object,
	patch_definitions: Array,
	patch_values: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = _make_report()
	if target == null:
		_add_report_error(report, &"", "invalid_target", "Target is null.")
		return report

	var require_property: bool = GFVariantData.get_option_bool(options, "require_existing_property", true)
	var should_copy_values: bool = GFVariantData.get_option_bool(options, "copy_values", true)
	var should_duplicate_resources: bool = GFVariantData.get_option_bool(options, "duplicate_resources", false)
	var skip_unchanged: bool = GFVariantData.get_option_bool(options, "skip_unchanged", false)
	var definition_map: Dictionary = _build_definition_map(patch_definitions)
	var normalized_values: Dictionary = _normalize_patch_values(patch_values, false, false)
	for raw_property_path: Variant in normalized_values.keys():
		var property_path: StringName = _normalize_property_path(raw_property_path)
		if property_path == &"":
			_add_report_error(report, &"", "invalid_property_path", "Property path is empty.")
			continue
		if not definition_map.has(property_path):
			_add_report_error(report, property_path, "undefined_property", "Property is not declared by this patch.")
			continue

		var definition: Dictionary = GFVariantData.as_dictionary(definition_map[property_path])
		var value: Variant = normalized_values[property_path]
		var value_error: String = _validate_value(definition, value)
		if not value_error.is_empty():
			_add_report_error(report, property_path, value_error, "Patch value does not match its definition.")
			continue
		if require_property and not _object_has_property(target, property_path):
			_add_report_error(report, property_path, "missing_property", "Target does not declare this property.")
			continue
		if skip_unchanged and GFVariantData.values_equal(target.get(String(property_path)), value):
			_add_report_skip(report, property_path, true)
			continue

		target.set(String(property_path), _copy_value(value, should_copy_values, should_duplicate_resources))
		_add_report_applied(report, property_path)
	return report


## 复制或修改 base Resource，并应用补丁值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param base_resource: 来源资源。
## [br]
## @param patch_definitions: 属性定义列表。
## [br]
## @param patch_values: 要应用的补丁值。
## [br]
## @param options: 构建选项。
## [br]
## @return: 构建报告，成功或部分成功时 resource 字段为结果资源。
## [br]
## @schema patch_definitions: Array[Dictionary] created by make_definition() or compatible dictionaries.
## [br]
## @schema patch_values: Dictionary[StringName, Variant] patch values.
## [br]
## @schema options: Dictionary，支持 duplicate_base、require_existing_property、copy_values、duplicate_resources、skip_unchanged。
## [br]
## @schema return: Dictionary，包含 apply_values() 报告字段和 resource。
static func build_resource(
	base_resource: Resource,
	patch_definitions: Array,
	patch_values: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	if base_resource == null:
		var failed_report: Dictionary = _make_report()
		failed_report["resource"] = null
		_add_report_error(failed_report, &"", "invalid_base_resource", "Base resource is null.")
		return failed_report

	var duplicate_base: bool = GFVariantData.get_option_bool(options, "duplicate_base", true)
	var result_resource: Resource = base_resource.duplicate(true) if duplicate_base else base_resource
	var report: Dictionary = apply_values(result_resource, patch_definitions, patch_values, options)
	report["resource"] = result_resource
	return report


## 按顺序把一组补丁应用到目标对象。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param target: 目标对象。
## [br]
## @param patch_chain: 补丁链。
## [br]
## @param options: 应用选项。
## [br]
## @return 覆盖链应用报告。
## [br]
## @schema patch_chain: Array[GFResourcePropertyPatch]，按数组顺序应用，越靠后的补丁优先级越高。
## [br]
## @schema options: Dictionary，支持 require_existing_property、copy_values、duplicate_resources、skip_unchanged、include_patch_reports、stop_on_failure 和 metadata。
## [br]
## @schema return: Dictionary，包含 ok、patch_count、计数、路径、errors、patch_reports 和 metadata。
static func apply_patch_chain(target: Object, patch_chain: Array, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_chain_report(options)
	if target == null:
		_add_report_error(report, &"", "invalid_target", "Target is null.")
		return report

	var include_patch_reports: bool = GFVariantData.get_option_bool(options, "include_patch_reports", true)
	var stop_on_failure: bool = GFVariantData.get_option_bool(options, "stop_on_failure", false)
	for patch_index: int in range(patch_chain.size()):
		var patch: GFResourcePropertyPatch = _variant_to_patch(patch_chain[patch_index])
		if patch == null:
			_add_chain_error(report, patch_index, {}, "invalid_patch", "Patch is null or not GFResourcePropertyPatch.")
			if stop_on_failure:
				break
			continue

		var patch_report: Dictionary = patch.apply(target, options)
		_merge_patch_report(report, patch_report, patch_index, patch.metadata, include_patch_reports)
		if stop_on_failure and not GFVariantData.get_option_bool(patch_report, "ok", false):
			break
	return report


## 复制或修改 base Resource，并按顺序应用一组补丁。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param base_resource: 来源资源。
## [br]
## @param patch_chain: 补丁链。
## [br]
## @param options: 构建选项。
## [br]
## @return 覆盖链构建报告，成功或部分成功时 resource 字段为结果资源。
## [br]
## @schema patch_chain: Array[GFResourcePropertyPatch]，按数组顺序应用，越靠后的补丁优先级越高。
## [br]
## @schema options: Dictionary，支持 duplicate_base、require_existing_property、copy_values、duplicate_resources、skip_unchanged、include_patch_reports、stop_on_failure 和 metadata。
## [br]
## @schema return: Dictionary，包含 apply_patch_chain() 报告字段和 resource。
static func build_resource_chain(base_resource: Resource, patch_chain: Array, options: Dictionary = {}) -> Dictionary:
	if base_resource == null:
		var failed_report: Dictionary = _make_chain_report(options)
		failed_report["resource"] = null
		_add_report_error(failed_report, &"", "invalid_base_resource", "Base resource is null.")
		return failed_report

	var duplicate_base: bool = GFVariantData.get_option_bool(options, "duplicate_base", true)
	var result_resource: Resource = base_resource.duplicate(true) if duplicate_base else base_resource
	var report: Dictionary = apply_patch_chain(result_resource, patch_chain, options)
	report["resource"] = result_resource
	return report


# --- 私有/辅助方法 ---

func _merge_default_options(options: Dictionary) -> Dictionary:
	var merged: Dictionary = options.duplicate(true)
	if not merged.has("require_existing_property"):
		merged["require_existing_property"] = require_existing_property
	if not merged.has("copy_values"):
		merged["copy_values"] = copy_values
	if not merged.has("duplicate_resources"):
		merged["duplicate_resources"] = duplicate_resources
	return merged


static func _build_definition_map(patch_definitions: Array) -> Dictionary:
	var result: Dictionary = {}
	for definition_variant: Variant in patch_definitions:
		var definition: Dictionary = GFVariantData.as_dictionary(definition_variant)
		var property_path: StringName = _get_definition_path(definition)
		if property_path == &"":
			continue
		result[property_path] = definition.duplicate(true)
	return result


static func _get_definition_path(definition: Dictionary) -> StringName:
	var raw_path: Variant = GFVariantData.get_option_value(
		definition,
		KEY_PROPERTY_PATH,
		GFVariantData.get_option_value(
			definition,
			"path",
			GFVariantData.get_option_value(definition, "name", &"")
		)
	)
	return _normalize_property_path(raw_path)


static func _normalize_patch_values(
	patch_values: Dictionary,
	should_copy_values: bool,
	should_duplicate_resources: bool
) -> Dictionary:
	var result: Dictionary = {}
	for raw_property_path: Variant in patch_values.keys():
		var property_path: StringName = _normalize_property_path(raw_property_path)
		if property_path == &"":
			continue
		result[property_path] = _copy_value(
			patch_values[raw_property_path],
			should_copy_values,
			should_duplicate_resources
		)
	return result


static func _normalize_property_path(value: Variant) -> StringName:
	var text: String = GFVariantData.to_text(value).strip_edges()
	if text.is_empty():
		return &""
	return StringName(text)


static func _find_dictionary_key(source: Dictionary, property_path: StringName) -> Variant:
	if source.has(property_path):
		return property_path
	var text_path: String = String(property_path)
	if source.has(text_path):
		return text_path
	for key: Variant in source.keys():
		if String(_normalize_property_path(key)) == text_path:
			return key
	return null


static func _object_has_property(target: Object, property_path: StringName) -> bool:
	if target == null:
		return false
	var text_path: String = String(property_path)
	for property_variant: Variant in target.get_property_list():
		var property: Dictionary = GFVariantData.as_dictionary(property_variant)
		if GFVariantData.get_option_string(property, "name") == text_path:
			return true
	return false


static func _copy_value(value: Variant, should_copy_values: bool, should_duplicate_resources: bool) -> Variant:
	if not should_copy_values:
		return value
	return GFVariantData.duplicate_variant(value, true, should_duplicate_resources)


static func _validate_value(definition: Dictionary, value: Variant) -> String:
	if value == null:
		return "" if GFVariantData.get_option_bool(definition, KEY_ALLOW_NULL, true) else "null_not_allowed"

	var property_type: int = GFVariantData.get_option_int(definition, KEY_TYPE, TYPE_NIL)
	if property_type == TYPE_NIL:
		return ""
	if property_type == TYPE_FLOAT and typeof(value) == TYPE_INT:
		return ""
	if property_type == TYPE_OBJECT:
		if not value is Object:
			return "type_mismatch"
		var object_value: Object = value
		var hint_string: String = GFVariantData.get_option_string(definition, KEY_HINT_STRING)
		return "" if _object_matches_hint(object_value, hint_string) else "type_hint_mismatch"
	return "" if typeof(value) == property_type else "type_mismatch"


static func _object_matches_hint(value: Object, hint_string: String) -> bool:
	var trimmed_hint: String = hint_string.strip_edges()
	if value == null or trimmed_hint.is_empty():
		return true
	if value.is_class(trimmed_hint):
		return true

	var script: Script = _get_script_value(value.get_script())
	while script != null:
		if String(script.get_global_name()) == trimmed_hint or script.resource_path == trimmed_hint:
			return true
		script = _get_script_value(script.get_base_script())
	return false


static func _get_script_value(value: Variant) -> Script:
	if value is Script:
		var script: Script = value
		return script
	return null


static func _make_property_entry(
	definition: Dictionary,
	property_path: StringName,
	patch_values: Dictionary,
	base_usage: int
) -> Dictionary:
	var usage: int = base_usage
	if _find_dictionary_key(patch_values, property_path) != null:
		usage = usage | PROPERTY_USAGE_STORAGE
	var property_type: int = _get_property_type(definition)
	return {
		"name": String(property_path),
		"type": property_type,
		"hint": GFVariantData.get_option_int(definition, KEY_HINT, PROPERTY_HINT_NONE),
		"hint_string": GFVariantData.get_option_string(definition, KEY_HINT_STRING),
		"usage": usage,
	}


static func _get_property_type(definition: Dictionary) -> int:
	var property_type: int = GFVariantData.get_option_int(definition, KEY_TYPE, TYPE_NIL)
	if property_type != TYPE_NIL:
		return property_type
	var default_value: Variant = GFVariantData.get_option_value(definition, KEY_DEFAULT_VALUE)
	return typeof(default_value)


static func _make_group_entry(group_prefix: String, group_name: String) -> Dictionary:
	var entry_name: String = group_name
	if not group_prefix.is_empty():
		entry_name = "%s/%s" % [group_prefix, group_name]
	return {
		"name": entry_name,
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP,
	}


static func _make_report() -> Dictionary:
	return {
		"ok": true,
		"applied_count": 0,
		"failed_count": 0,
		"skipped_count": 0,
		"unchanged_count": 0,
		"applied_paths": PackedStringArray(),
		"skipped_paths": PackedStringArray(),
		"errors": [],
	}


static func _make_chain_report(options: Dictionary) -> Dictionary:
	var report: Dictionary = _make_report()
	report["patch_count"] = 0
	report["patch_reports"] = []
	report["metadata"] = GFVariantData.get_option_dictionary(options, "metadata").duplicate(true)
	return report


static func _variant_to_patch(value: Variant) -> GFResourcePropertyPatch:
	if value is GFResourcePropertyPatch:
		var patch: GFResourcePropertyPatch = value
		return patch
	return null


static func _merge_patch_report(
	target_report: Dictionary,
	patch_report: Dictionary,
	patch_index: int,
	patch_metadata: Dictionary,
	include_patch_reports: bool
) -> void:
	target_report["patch_count"] = GFVariantData.get_option_int(target_report, "patch_count") + 1
	target_report["applied_count"] = GFVariantData.get_option_int(target_report, "applied_count") + GFVariantData.get_option_int(patch_report, "applied_count")
	target_report["failed_count"] = GFVariantData.get_option_int(target_report, "failed_count") + GFVariantData.get_option_int(patch_report, "failed_count")
	target_report["skipped_count"] = GFVariantData.get_option_int(target_report, "skipped_count") + GFVariantData.get_option_int(patch_report, "skipped_count")
	target_report["unchanged_count"] = GFVariantData.get_option_int(target_report, "unchanged_count") + GFVariantData.get_option_int(patch_report, "unchanged_count")
	target_report["ok"] = GFVariantData.get_option_bool(target_report, "ok", true) and GFVariantData.get_option_bool(patch_report, "ok", false)
	_append_report_paths(target_report, "applied_paths", _get_report_paths(patch_report, "applied_paths"))
	_append_report_paths(target_report, "skipped_paths", _get_report_paths(patch_report, "skipped_paths"))
	_append_patch_errors(target_report, patch_report, patch_index, patch_metadata)
	if include_patch_reports:
		var patch_reports: Array = GFVariantData.get_option_array(target_report, "patch_reports")
		var patch_report_copy: Dictionary = patch_report.duplicate(true)
		patch_report_copy["patch_index"] = patch_index
		patch_report_copy["patch_metadata"] = patch_metadata.duplicate(true)
		patch_reports.append(patch_report_copy)
		target_report["patch_reports"] = patch_reports


static func _append_report_paths(target_report: Dictionary, key: String, paths: PackedStringArray) -> void:
	var target_paths: PackedStringArray = _get_report_paths(target_report, key)
	for path: String in paths:
		var _appended: bool = target_paths.append(path)
	target_report[key] = target_paths


static func _append_patch_errors(
	target_report: Dictionary,
	patch_report: Dictionary,
	patch_index: int,
	patch_metadata: Dictionary
) -> void:
	var target_errors: Array = GFVariantData.get_option_array(target_report, "errors")
	for error_variant: Variant in GFVariantData.get_option_array(patch_report, "errors"):
		var error: Dictionary = GFVariantData.as_dictionary(error_variant).duplicate(true)
		error["patch_index"] = patch_index
		error["patch_metadata"] = patch_metadata.duplicate(true)
		target_errors.append(error)
	target_report["errors"] = target_errors


static func _add_chain_error(
	report: Dictionary,
	patch_index: int,
	patch_metadata: Dictionary,
	kind: String,
	message: String
) -> void:
	_add_report_error(report, &"", kind, message)
	var errors: Array = GFVariantData.get_option_array(report, "errors")
	if errors.is_empty():
		return
	var last_error: Dictionary = GFVariantData.as_dictionary(errors[errors.size() - 1])
	last_error["patch_index"] = patch_index
	last_error["patch_metadata"] = patch_metadata.duplicate(true)
	errors[errors.size() - 1] = last_error
	report["errors"] = errors


static func _add_report_applied(report: Dictionary, property_path: StringName) -> void:
	report["applied_count"] = GFVariantData.get_option_int(report, "applied_count") + 1
	var paths: PackedStringArray = _get_report_paths(report, "applied_paths")
	var _appended: bool = paths.append(String(property_path))
	report["applied_paths"] = paths


static func _add_report_skip(report: Dictionary, property_path: StringName, unchanged: bool) -> void:
	report["skipped_count"] = GFVariantData.get_option_int(report, "skipped_count") + 1
	if unchanged:
		report["unchanged_count"] = GFVariantData.get_option_int(report, "unchanged_count") + 1
	var paths: PackedStringArray = _get_report_paths(report, "skipped_paths")
	var _appended: bool = paths.append(String(property_path))
	report["skipped_paths"] = paths


static func _add_report_error(
	report: Dictionary,
	property_path: StringName,
	kind: String,
	message: String
) -> void:
	report["ok"] = false
	report["failed_count"] = GFVariantData.get_option_int(report, "failed_count") + 1
	var errors: Array = GFVariantData.get_option_array(report, "errors")
	errors.append({
		"property_path": property_path,
		"kind": kind,
		"message": message,
	})
	report["errors"] = errors
	var paths: PackedStringArray = _get_report_paths(report, "skipped_paths")
	var _appended: bool = paths.append(String(property_path))
	report["skipped_paths"] = paths


static func _get_report_paths(report: Dictionary, key: String) -> PackedStringArray:
	var value: Variant = GFVariantData.get_option_value(report, key, PackedStringArray())
	if value is PackedStringArray:
		var paths: PackedStringArray = value
		return paths
	return PackedStringArray()
