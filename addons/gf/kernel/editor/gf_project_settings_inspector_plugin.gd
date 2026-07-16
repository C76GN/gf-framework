@tool

# GF ProjectSettings 本地化展示适配器。
#
# 稳定设置键和原生属性编辑器保持不变；该插件只负责编辑器标签、说明与枚举显示文本。
extends EditorInspectorPlugin


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_PROJECT_SETTING_PRESENTATION_CATALOG_SCRIPT = preload("res://addons/gf/kernel/editor/gf_project_setting_presentation_catalog.gd")
const _GF_EDITOR_PROPERTY_PLAIN_TOOLTIP_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_property_plain_tooltip.gd")
const _GF_RESOURCE_PATH_INSPECTOR_PLUGIN_SCRIPT = preload("res://addons/gf/kernel/editor/gf_resource_path_inspector_plugin.gd")
const _SECTIONED_INSPECTOR_FILTER_CLASS: String = "SectionedInspectorFilter"


# --- 私有变量 ---

var _catalog: RefCounted = null
var _section_by_filter_id: Dictionary = {}
var _instantiating_native_editor: bool = false
var _presentation_locale: String = ""


# --- Godot 生命周期方法 ---

func _init() -> void:
	var catalog_value: Variant = _GF_PROJECT_SETTING_PRESENTATION_CATALOG_SCRIPT.new()
	if catalog_value is RefCounted:
		_catalog = catalog_value
	configure()


# --- Godot 回调方法 ---

func _can_handle(object: Object) -> bool:
	if _instantiating_native_editor:
		return false
	if object == ProjectSettings:
		return true
	if object == null or object.get_class() != _SECTIONED_INSPECTOR_FILTER_CLASS:
		return false

	var object_id: int = object.get_instance_id()
	var section: String = _resolve_project_settings_section(object)
	if section.is_empty():
		var _erase_result: bool = _section_by_filter_id.erase(object_id)
		return false
	_section_by_filter_id[object_id] = section
	return true


func _parse_property(
	object: Object,
	type: Variant.Type,
	name: String,
	hint_type: PropertyHint,
	hint_string: String,
	usage_flags: int,
	wide: bool
) -> bool:
	var setting_name: String = _resolve_setting_name(object, name)
	var presentation: Dictionary = _get_presentation(setting_name, _presentation_locale)
	if presentation.is_empty():
		return false

	var editor_property: EditorProperty = _create_editor_property(
		object,
		type,
		name,
		hint_type,
		hint_string,
		usage_flags,
		wide,
		presentation
	)
	if editor_property == null:
		return false

	add_property_editor(
		name,
		editor_property,
		false,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(presentation, "label")
	)
	return true


# --- 框架内部方法 ---

## 配置标准库贡献的项目设置展示记录。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param contributed_records: 已通过编辑器贡献清单校验的项目设置记录。
## [br]
## @schema contributed_records: Array[Dictionary]，每项可包含 ProjectSettings 注册字段与编辑器展示映射。
## [br]
## @param contributed_section_records: 已通过编辑器贡献清单校验的项目设置分区记录。
## [br]
## @schema contributed_section_records: Array[Dictionary]，每项包含 path、editor_labels 与 editor_descriptions。
## [br]
## @param locale: 展示语言覆盖；留空时跟随 Godot 当前工具语言。
func configure(
	contributed_records: Array[Dictionary] = [],
	contributed_section_records: Array[Dictionary] = [],
	locale: String = ""
) -> void:
	_presentation_locale = locale.strip_edges()
	if _catalog == null or not _catalog.has_method(&"configure"):
		return
	var _configure_result: Variant = _catalog.call(
		&"configure",
		contributed_records,
		contributed_section_records
	)


# --- 私有/辅助方法 ---

func _get_presentation(setting_name: String, locale: String = "") -> Dictionary:
	if _catalog == null or not _catalog.has_method(&"get_presentation"):
		return {}
	var presentation_value: Variant = _catalog.call(&"get_presentation", setting_name, locale)
	return _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(presentation_value)


func _create_editor_property(
	object: Object,
	type: Variant.Type,
	name: String,
	hint_type: PropertyHint,
	hint_string: String,
	usage_flags: int,
	wide: bool,
	presentation: Dictionary
) -> EditorProperty:
	var editor_property: EditorProperty = _GF_RESOURCE_PATH_INSPECTOR_PLUGIN_SCRIPT.create_editor_property(
		type,
		hint_type,
		hint_string
	)
	if editor_property == null:
		_instantiating_native_editor = true
		editor_property = EditorInspector.instantiate_property_editor(
			object,
			type,
			name,
			hint_type,
			hint_string,
			usage_flags,
			wide
		)
		_instantiating_native_editor = false
	if editor_property == null:
		return null

	var tooltip: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(presentation, "tooltip")
	var existing_script: Variant = editor_property.get_script()
	if existing_script == null:
		editor_property.set_script(_GF_EDITOR_PROPERTY_PLAIN_TOOLTIP_SCRIPT)
	editor_property.set_meta(_GF_EDITOR_PROPERTY_PLAIN_TOOLTIP_SCRIPT.TOOLTIP_METADATA, tooltip)
	editor_property.tooltip_text = tooltip
	_apply_tooltip_to_empty_controls(editor_property, tooltip)
	if type == TYPE_STRING and hint_type == PROPERTY_HINT_ENUM:
		_apply_enum_presentation(editor_property, presentation, tooltip)
	return editor_property


func _resolve_setting_name(object: Object, property_name: String) -> String:
	if object == ProjectSettings:
		return property_name
	var object_id: int = object.get_instance_id()
	var section: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		_section_by_filter_id,
		object_id,
		""
	)
	if section.is_empty():
		section = _resolve_project_settings_section(object)
	if section.is_empty():
		return ""
	return "%s/%s" % [section, property_name]


func _resolve_project_settings_section(filter_object: Object) -> String:
	var filter_signature: Dictionary = _collect_property_signature(filter_object.get_property_list())
	if filter_signature.is_empty():
		return ""

	var matching_section: String = ""
	for section: String in _get_catalog_sections():
		var section_signature: Dictionary = _collect_project_section_signature(section)
		if section_signature != filter_signature:
			continue
		if not matching_section.is_empty():
			return ""
		matching_section = section
	return matching_section


func _get_catalog_sections() -> PackedStringArray:
	var sections: PackedStringArray = PackedStringArray()
	if _catalog == null or not _catalog.has_method(&"get_setting_names"):
		return sections
	var setting_names_value: Variant = _catalog.call(&"get_setting_names")
	if not setting_names_value is PackedStringArray:
		return sections
	var setting_names: PackedStringArray = setting_names_value
	for setting_name: String in setting_names:
		var path_parts: PackedStringArray = setting_name.split("/", false)
		if path_parts.size() < 3:
			continue
		var section: String = "%s/%s" % [path_parts[0], path_parts[1]]
		if sections.has(section):
			continue
		var _append_result: bool = sections.append(section)
	sections.sort()
	return sections


func _collect_project_section_signature(section: String) -> Dictionary:
	var relative_properties: Array[Dictionary] = []
	var section_prefix: String = section + "/"
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var setting_name: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(property_info, "name")
		if not setting_name.begins_with(section_prefix):
			continue
		var relative_info: Dictionary = property_info.duplicate()
		relative_info["name"] = setting_name.trim_prefix(section_prefix)
		relative_properties.append(relative_info)
	return _collect_property_signature(relative_properties)


func _collect_property_signature(property_list: Array[Dictionary]) -> Dictionary:
	var signature: Dictionary = {}
	for property_info: Dictionary in property_list:
		var property_name: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(property_info, "name")
		var usage: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			property_info,
			"usage",
			PROPERTY_USAGE_NONE
		)
		if (
			property_name.is_empty()
			or property_name == "script"
			or usage & PROPERTY_USAGE_CATEGORY != 0
		):
			continue
		signature[property_name] = {
			"type": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(property_info, "type", TYPE_NIL),
			"hint": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(property_info, "hint", PROPERTY_HINT_NONE),
			"hint_string": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(property_info, "hint_string"),
			"usage": usage,
			"class_name": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(property_info, "class_name"),
		}
	return signature


func _apply_tooltip_to_empty_controls(root: Control, tooltip: String) -> void:
	for child: Node in root.get_children():
		if not child is Control:
			continue
		var control: Control = child
		if control.tooltip_text.is_empty():
			control.tooltip_text = tooltip
		_apply_tooltip_to_empty_controls(control, tooltip)


func _apply_enum_presentation(
	editor_property: EditorProperty,
	presentation: Dictionary,
	tooltip: String
) -> void:
	var enum_labels: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(presentation, "enum_labels")
	if enum_labels.is_empty():
		return
	var enum_descriptions: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
		presentation,
		"enum_descriptions"
	)
	var option_button: OptionButton = _find_option_button(editor_property)
	if option_button == null:
		return

	option_button.tooltip_text = tooltip
	for index: int in range(option_button.item_count):
		var value: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(option_button.get_item_metadata(index))
		if enum_labels.has(value):
			option_button.set_item_text(index, _GF_VARIANT_ACCESS_SCRIPT.to_text(enum_labels[value]))
		if enum_descriptions.has(value):
			option_button.set_item_tooltip(index, _GF_VARIANT_ACCESS_SCRIPT.to_text(enum_descriptions[value]))


func _find_option_button(root: Node) -> OptionButton:
	for child: Node in root.get_children():
		if child is OptionButton:
			var option_button: OptionButton = child
			return option_button
		var nested_option: OptionButton = _find_option_button(child)
		if nested_option != null:
			return nested_option
	return null
