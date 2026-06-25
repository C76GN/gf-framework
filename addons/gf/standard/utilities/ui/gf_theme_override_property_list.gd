## GFThemeOverridePropertyList: Control 主题覆盖属性列表构建器。
##
## 帮助自定义 Control 把一组主题覆盖项暴露到 Inspector。它只生成 Godot 属性列表
## 与 revert 信息，不规定控件外观、主题命名或业务语义。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 6.0.0
class_name GFThemeOverridePropertyList
extends RefCounted


# --- 常量 ---

## 定义字段：主题项名称。
## [br]
## @api public
## [br]
## @since 6.0.0
const KEY_NAME: String = "name"

## 定义字段：Theme.DataType。
## [br]
## @api public
## [br]
## @since 6.0.0
const KEY_DATA_TYPE: String = "data_type"

## 定义字段：可选 hint。
## [br]
## @api public
## [br]
## @since 6.0.0
const KEY_HINT: String = "hint"

## 定义字段：可选 hint_string。
## [br]
## @api public
## [br]
## @since 6.0.0
const KEY_HINT_STRING: String = "hint_string"

const _GROUP_BY_DATA_TYPE: Dictionary = {
	Theme.DATA_TYPE_COLOR: "theme_override_colors",
	Theme.DATA_TYPE_CONSTANT: "theme_override_constants",
	Theme.DATA_TYPE_FONT: "theme_override_fonts",
	Theme.DATA_TYPE_FONT_SIZE: "theme_override_font_sizes",
	Theme.DATA_TYPE_ICON: "theme_override_icons",
	Theme.DATA_TYPE_STYLEBOX: "theme_override_styles",
}

const _TYPE_BY_DATA_TYPE: Dictionary = {
	Theme.DATA_TYPE_COLOR: TYPE_COLOR,
	Theme.DATA_TYPE_CONSTANT: TYPE_INT,
	Theme.DATA_TYPE_FONT: TYPE_OBJECT,
	Theme.DATA_TYPE_FONT_SIZE: TYPE_INT,
	Theme.DATA_TYPE_ICON: TYPE_OBJECT,
	Theme.DATA_TYPE_STYLEBOX: TYPE_OBJECT,
}

const _HINT_STRING_BY_DATA_TYPE: Dictionary = {
	Theme.DATA_TYPE_FONT: "Font",
	Theme.DATA_TYPE_ICON: "Texture2D",
	Theme.DATA_TYPE_STYLEBOX: "StyleBox",
}


# --- 公共方法 ---

## 创建主题覆盖定义。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param override_name: 主题项名称。
## [br]
## @param data_type: Theme.DataType 值。
## [br]
## @param options: 可选 hint/hint_string。
## [br]
## @return 定义字典。
## [br]
## @schema options: Dictionary with optional hint and hint_string.
## [br]
## @schema return: Dictionary theme override definition.
static func make_definition(override_name: StringName, data_type: int, options: Dictionary = {}) -> Dictionary:
	var definition: Dictionary = {
		KEY_NAME: override_name,
		KEY_DATA_TYPE: data_type,
	}
	if options.has(KEY_HINT):
		definition[KEY_HINT] = GFVariantData.get_option_int(options, KEY_HINT)
	if options.has(KEY_HINT_STRING):
		definition[KEY_HINT_STRING] = GFVariantData.get_option_string(options, KEY_HINT_STRING)
	return definition


## 构建 Inspector 属性列表。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param control: 目标 Control；用于判断当前 override 是否需要 storage usage。
## [br]
## @param definitions: 主题覆盖定义列表。
## [br]
## @param options: 可选参数，支持 group_prefix。
## [br]
## @return Godot _get_property_list() 可返回的属性列表。
## [br]
## @schema definitions: Array[Dictionary] created by make_definition() or compatible dictionaries.
## [br]
## @schema options: Dictionary with optional `group_prefix: String`.
## [br]
## @schema return: Array[Dictionary] property list entries.
static func make_property_list(
	control: Control,
	definitions: Array,
	options: Dictionary = {}
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var grouped: Dictionary = _group_definitions(definitions)
	var group_prefix: String = GFVariantData.get_option_string(options, "group_prefix", "Theme Overrides")
	for data_type: int in _get_sorted_data_types(grouped):
		var group_name: String = _get_group_name(data_type)
		if group_name.is_empty():
			continue
		entries.append({
			"name": "%s/%s" % [group_prefix, group_name],
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP,
		})

		var group_definitions: Array = GFVariantData.as_array(grouped[data_type])
		for definition_variant: Variant in group_definitions:
			var definition: Dictionary = GFVariantData.as_dictionary(definition_variant)
			var property_path: String = get_property_path(definition)
			if property_path.is_empty():
				continue
			entries.append(_make_property_entry(control, property_path, definition))
	return entries


## 获取定义对应的 Control 属性路径。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param definition: 主题覆盖定义。
## [br]
## @return 形如 theme_override_colors/accent 的属性路径。
## [br]
## @schema definition: Dictionary theme override definition.
static func get_property_path(definition: Dictionary) -> String:
	var override_name: String = GFVariantData.get_option_string(definition, KEY_NAME).strip_edges()
	if override_name.is_empty():
		return ""
	var data_type: int = GFVariantData.get_option_int(definition, KEY_DATA_TYPE, -1)
	var group_name: String = _get_group_name(data_type)
	if group_name.is_empty():
		return ""
	return "%s/%s" % [group_name, override_name]


## 检查属性是否由定义列表声明。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param property_path: Control 属性路径。
## [br]
## @param definitions: 主题覆盖定义列表。
## [br]
## @return 存在返回 true。
## [br]
## @schema definitions: Array[Dictionary] theme override definitions.
static func has_property_path(property_path: StringName, definitions: Array) -> bool:
	var path_text: String = String(property_path)
	for definition_variant: Variant in definitions:
		var definition: Dictionary = GFVariantData.as_dictionary(definition_variant)
		if get_property_path(definition) == path_text:
			return true
	return false


## 判断属性是否可以 revert。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param property_path: Control 属性路径。
## [br]
## @param definitions: 主题覆盖定义列表。
## [br]
## @return 由定义声明时返回 true。
## [br]
## @schema definitions: Array[Dictionary] theme override definitions.
static func can_revert(property_path: StringName, definitions: Array) -> bool:
	return has_property_path(property_path, definitions)


## 获取主题覆盖属性的 revert 值。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param _property_path: Control 属性路径。
## [br]
## @return Godot theme override 的默认空值。
## [br]
## @schema return: null clears the override.
static func get_revert_value(_property_path: StringName) -> Variant:
	return null


## 收集控件当前已设置的主题覆盖值。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param control: 目标 Control。
## [br]
## @param definitions: 主题覆盖定义列表。
## [br]
## @param options: 可选参数，支持 include_null、copy_values、duplicate_resources。
## [br]
## @return 以属性路径为键的覆盖值字典。
## [br]
## @schema definitions: Array[Dictionary] created by make_definition() or compatible dictionaries.
## [br]
## @schema options: Dictionary with optional include_null: bool, copy_values: bool, duplicate_resources: bool.
## [br]
## @schema return: Dictionary[String, Variant] mapping theme override property paths to values.
static func collect_override_values(
	control: Control,
	definitions: Array,
	options: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {}
	if control == null:
		return result

	var include_null: bool = GFVariantData.get_option_bool(options, "include_null", false)
	var copy_values: bool = GFVariantData.get_option_bool(options, "copy_values", true)
	var duplicate_resources: bool = GFVariantData.get_option_bool(options, "duplicate_resources", false)
	for definition_variant: Variant in definitions:
		var definition: Dictionary = GFVariantData.as_dictionary(definition_variant)
		var property_path: String = get_property_path(definition)
		if property_path.is_empty():
			continue
		var value: Variant = control.get(property_path)
		if value == null and not include_null:
			continue
		if copy_values:
			value = GFVariantData.duplicate_variant(value, true, duplicate_resources)
		result[property_path] = value
	return result


## 清空控件上由定义列表声明的主题覆盖。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param control: 目标 Control。
## [br]
## @param definitions: 主题覆盖定义列表。
## [br]
## @return 清空报告。
## [br]
## @schema definitions: Array[Dictionary] created by make_definition() or compatible dictionaries.
## [br]
## @schema return: Dictionary { ok: bool, cleared_count: int, skipped_count: int, issues: Array[Dictionary] }.
static func clear_overrides(control: Control, definitions: Array) -> Dictionary:
	var issues: Array[Dictionary] = []
	var report: Dictionary = {
		"ok": true,
		"cleared_count": 0,
		"skipped_count": 0,
		"issues": issues,
	}
	var cleared_count: int = 0
	var skipped_count: int = 0
	if control == null:
		_append_report_issue(issues, "", "invalid_control", "Control is null.")
		report["ok"] = false
		report["skipped_count"] = definitions.size()
		return report

	for definition_variant: Variant in definitions:
		var definition: Dictionary = GFVariantData.as_dictionary(definition_variant)
		var property_path: String = get_property_path(definition)
		if property_path.is_empty():
			skipped_count += 1
			continue
		if control.get(property_path) == null:
			skipped_count += 1
			continue

		control.set(property_path, null)
		cleared_count += 1

	report["ok"] = issues.is_empty()
	report["cleared_count"] = cleared_count
	report["skipped_count"] = skipped_count
	return report


## 从控件当前主题覆盖创建 Theme。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param control: 目标 Control。
## [br]
## @param definitions: 主题覆盖定义列表。
## [br]
## @param theme_type: Theme 类型名；为空时使用 control.get_class()。
## [br]
## @param options: 透传给 collect_override_values()。
## [br]
## @return 新建 Theme，包含定义列表中已设置的有效覆盖值。
## [br]
## @schema definitions: Array[Dictionary] created by make_definition() or compatible dictionaries.
## [br]
## @schema options: Dictionary with optional include_null: bool, copy_values: bool, duplicate_resources: bool.
static func make_theme_from_control(
	control: Control,
	definitions: Array,
	theme_type: StringName = &"",
	options: Dictionary = {}
) -> Theme:
	if control == null:
		return Theme.new()
	var resolved_theme_type: StringName = theme_type
	if resolved_theme_type == &"":
		resolved_theme_type = StringName(control.get_class())
	var values: Dictionary = collect_override_values(control, definitions, options)
	return make_theme_from_values(definitions, values, resolved_theme_type)


## 从已收集的主题覆盖值创建 Theme。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param definitions: 主题覆盖定义列表。
## [br]
## @param values: 以属性路径为键的覆盖值字典。
## [br]
## @param theme_type: Theme 类型名。
## [br]
## @return 新建 Theme，包含定义列表中已设置的有效覆盖值。
## [br]
## @schema definitions: Array[Dictionary] created by make_definition() or compatible dictionaries.
## [br]
## @schema values: Dictionary[String, Variant] mapping theme override property paths to values.
static func make_theme_from_values(
	definitions: Array,
	values: Dictionary,
	theme_type: StringName
) -> Theme:
	var theme: Theme = Theme.new()
	if theme_type == &"":
		return theme

	for definition_variant: Variant in definitions:
		var definition: Dictionary = GFVariantData.as_dictionary(definition_variant)
		var property_path: String = get_property_path(definition)
		if property_path.is_empty() or not values.has(property_path):
			continue
		var value: Variant = values[property_path]
		if value == null:
			continue
		_apply_theme_value(theme, theme_type, definition, value)
	return theme


# --- 私有/辅助方法 ---

static func _group_definitions(definitions: Array) -> Dictionary:
	var grouped: Dictionary = {}
	for definition_variant: Variant in definitions:
		var definition: Dictionary = GFVariantData.as_dictionary(definition_variant)
		var data_type: int = GFVariantData.get_option_int(definition, KEY_DATA_TYPE, -1)
		if _get_group_name(data_type).is_empty():
			continue
		if not grouped.has(data_type):
			grouped[data_type] = []
		var entries: Array = GFVariantData.as_array(grouped[data_type])
		entries.append(definition.duplicate(true))
	return grouped


static func _get_sorted_data_types(grouped: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for data_type_variant: Variant in grouped.keys():
		if data_type_variant is int:
			var data_type: int = data_type_variant
			result.append(data_type)
	result.sort()
	return result


static func _make_property_entry(control: Control, property_path: String, definition: Dictionary) -> Dictionary:
	var data_type: int = GFVariantData.get_option_int(definition, KEY_DATA_TYPE, -1)
	var usage: int = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_CHECKABLE
	if control != null and control.get(property_path) != null:
		usage = usage | PROPERTY_USAGE_STORAGE

	return {
		"name": property_path,
		"type": GFVariantData.get_option_int(_TYPE_BY_DATA_TYPE, data_type, TYPE_NIL),
		"hint": _get_property_hint(definition, data_type),
		"hint_string": _get_property_hint_string(definition, data_type),
		"usage": usage,
	}


static func _get_property_hint(definition: Dictionary, data_type: int) -> int:
	if definition.has(KEY_HINT):
		return GFVariantData.get_option_int(definition, KEY_HINT)
	if data_type == Theme.DATA_TYPE_FONT or data_type == Theme.DATA_TYPE_ICON or data_type == Theme.DATA_TYPE_STYLEBOX:
		return PROPERTY_HINT_RESOURCE_TYPE
	return PROPERTY_HINT_NONE


static func _get_property_hint_string(definition: Dictionary, data_type: int) -> String:
	if definition.has(KEY_HINT_STRING):
		return GFVariantData.get_option_string(definition, KEY_HINT_STRING)
	return GFVariantData.get_option_string(_HINT_STRING_BY_DATA_TYPE, data_type)


static func _get_group_name(data_type: int) -> String:
	return GFVariantData.get_option_string(_GROUP_BY_DATA_TYPE, data_type)


static func _apply_theme_value(
	theme: Theme,
	theme_type: StringName,
	definition: Dictionary,
	value: Variant
) -> void:
	var override_name: StringName = GFVariantData.get_option_string_name(definition, KEY_NAME)
	if override_name == &"":
		return

	var data_type: int = GFVariantData.get_option_int(definition, KEY_DATA_TYPE, -1)
	match data_type:
		Theme.DATA_TYPE_COLOR:
			if value is Color:
				var color_value: Color = value
				theme.set_color(override_name, theme_type, color_value)
		Theme.DATA_TYPE_CONSTANT:
			if value is int:
				var constant_value: int = value
				theme.set_constant(override_name, theme_type, constant_value)
		Theme.DATA_TYPE_FONT:
			if value is Font:
				var font_value: Font = value
				theme.set_font(override_name, theme_type, font_value)
		Theme.DATA_TYPE_FONT_SIZE:
			if value is int:
				var font_size_value: int = value
				theme.set_font_size(override_name, theme_type, font_size_value)
		Theme.DATA_TYPE_ICON:
			if value is Texture2D:
				var icon_value: Texture2D = value
				theme.set_icon(override_name, theme_type, icon_value)
		Theme.DATA_TYPE_STYLEBOX:
			if value is StyleBox:
				var stylebox_value: StyleBox = value
				theme.set_stylebox(override_name, theme_type, stylebox_value)


static func _append_report_issue(
	issues: Array[Dictionary],
	property_path: String,
	kind: String,
	message: String
) -> void:
	issues.append({
		"property_path": property_path,
		"kind": kind,
		"message": message,
	})
