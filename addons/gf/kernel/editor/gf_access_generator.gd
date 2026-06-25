@tool

## GFAccessGenerator: 生成强类型 GF 访问器脚本。
##
## 生成结果用于减少 `Gf.get_model(Type) as Type` 这类重复样板，
## 并为 Model / System / Utility / Command / Query 提供稳定的 IDE 补全入口。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
## [br]
## @layer kernel/editor
class_name GFAccessGenerator
extends RefCounted


# --- 枚举 ---

## 访问器目标类型。
## [br]
## @api public
enum TargetKind {
	## Model 访问器目标。
	MODEL,
	## System 访问器目标。
	SYSTEM,
	## Utility 访问器目标。
	UTILITY,
	## Command 访问器目标。
	COMMAND,
	## Query 访问器目标。
	QUERY,
	## Capability 访问器目标。
	CAPABILITY,
}


# --- 常量 ---

## 默认强类型访问器输出路径。
## [br]
## @api public
const DEFAULT_OUTPUT_PATH: String = "res://gf/generated/gf_access.gd"

## 默认项目常量访问器输出路径。
## [br]
## @api public
const DEFAULT_PROJECT_OUTPUT_PATH: String = "res://gf/generated/gf_project_access.gd"
const _BASE_MODEL_SCRIPT = preload("res://addons/gf/kernel/base/gf_model.gd")
const _BASE_SYSTEM_SCRIPT = preload("res://addons/gf/kernel/base/gf_system.gd")
const _BASE_UTILITY_SCRIPT = preload("res://addons/gf/kernel/base/gf_utility.gd")
const _BASE_COMMAND_SCRIPT = preload("res://addons/gf/kernel/base/gf_command.gd")
const _BASE_QUERY_SCRIPT = preload("res://addons/gf/kernel/base/gf_query.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GENERATED_ARTIFACT_REPORT_SCRIPT = preload("res://addons/gf/kernel/editor/gf_generated_artifact_report.gd")
const _LAYER_TYPES: Dictionary = {
	"2d_render": 20,
	"2d_physics": 32,
	"2d_navigation": 32,
	"3d_render": 20,
	"3d_physics": 32,
	"3d_navigation": 32,
	"avoidance": 32,
}
const _KNOWN_GF_PROJECT_SETTINGS: Array[String] = [
	"gf/codegen/access_output_path",
	"gf/codegen/project_access_output_path",
	"gf/extensions/auto_install_enabled_installers",
	"gf/extensions/enabled",
	"gf/extensions/export_exclude_disabled",
	"gf/extensions/export_fail_on_disabled_references",
	"gf/project/fail_on_installer_error",
	"gf/project/installer_timeout_seconds",
	"gf/project/installers",
]


# --- 公共方法 ---

## 扫描项目 class_name 脚本并生成访问器。
## [br]
## @api public
## [br]
## @param output_path: 生成文件输出路径。
## [br]
## @param overwrite_existing: 为 false 时目标已存在会返回 ERR_ALREADY_EXISTS。
## [br]
## @return 写入结果错误码。
func generate(output_path: String = DEFAULT_OUTPUT_PATH, overwrite_existing: bool = true) -> Error:
	var report: Dictionary = generate_with_report(output_path, {
		"overwrite_existing": overwrite_existing,
	})
	return _GENERATED_ARTIFACT_REPORT_SCRIPT.get_error_code(report)


## 扫描项目 class_name 脚本并生成访问器报告。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param output_path: 生成文件输出路径。
## [br]
## @param options: 保存选项，支持 overwrite_existing、dry_run、scan_filesystem 和 metadata。
## [br]
## @schema options: Dictionary，可包含 overwrite_existing、dry_run、scan_filesystem 和 metadata。
## [br]
## @return: 生成产物报告。
## [br]
## @schema return: Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、size_bytes 和 metadata。
func generate_with_report(output_path: String = DEFAULT_OUTPUT_PATH, options: Dictionary = {}) -> Dictionary:
	var records: Array[Dictionary] = collect_records()
	var source: String = build_source(records)
	return save_source_with_report(output_path, source, options)


## 生成项目常量访问器。
## [br]
## @api public
## [br]
## @param output_path: 生成文件输出路径。
## [br]
## @param overwrite_existing: 为 false 时目标已存在会返回 ERR_ALREADY_EXISTS。
## [br]
## @return 写入结果错误码。
func generate_project_access(output_path: String = DEFAULT_PROJECT_OUTPUT_PATH, overwrite_existing: bool = true) -> Error:
	var report: Dictionary = generate_project_access_with_report(output_path, {
		"overwrite_existing": overwrite_existing,
	})
	return _GENERATED_ARTIFACT_REPORT_SCRIPT.get_error_code(report)


## 生成项目常量访问器报告。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param output_path: 生成文件输出路径。
## [br]
## @param options: 保存选项，支持 overwrite_existing、dry_run、scan_filesystem 和 metadata。
## [br]
## @schema options: Dictionary，可包含 overwrite_existing、dry_run、scan_filesystem 和 metadata。
## [br]
## @return: 生成产物报告。
## [br]
## @schema return: Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、size_bytes 和 metadata。
func generate_project_access_with_report(
	output_path: String = DEFAULT_PROJECT_OUTPUT_PATH,
	options: Dictionary = {}
) -> Dictionary:
	var records: Dictionary = collect_project_records()
	var source: String = build_project_source(records)
	return save_source_with_report(output_path, source, options)


## 收集当前项目中可生成访问器的 GF 类型记录。
## [br]
## @api public
## [br]
## @return 类型记录列表。
## [br]
## @schema return: Array of Dictionary type records with class_name, path, script, kind, and access metadata.
func collect_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for global_class: Dictionary in ProjectSettings.get_global_class_list():
		var class_name_value: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(global_class, "class")
		var path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(global_class, "path")
		if class_name_value.is_empty() or path.is_empty():
			continue

		var script: Script = _variant_to_script(load(path))
		if script == null:
			continue

		var kind: int = _resolve_kind(script)
		if kind == -1:
			continue

		records.append({
			"class_name": class_name_value,
			"path": path,
			"kind": kind,
		})

	_append_access_generator_extension_records(records)
	_sort_records(records)
	return records


## 收集项目层常量记录，包括命名层、InputMap 动作和 GF ProjectSettings。
## [br]
## @api public
## [br]
## @return 项目常量记录。
## [br]
## @schema return: Dictionary with layers, input_actions, and settings arrays.
func collect_project_records() -> Dictionary:
	return {
		"layers": _collect_layer_records(),
		"input_actions": _collect_input_actions(),
		"settings": _collect_gf_project_settings(),
	}


## 根据记录生成访问器源码。测试可直接调用该方法验证输出。
## [br]
## @api public
## [br]
## @param records: 生成访问器时使用的类型记录列表。
## [br]
## @schema records: Array of Dictionary type records containing class_name, path, and kind.
## [br]
## @return GDScript 源码。
func build_source(records: Array) -> String:
	var builder: GFSourceBuilder = GFSourceBuilder.new()
	var has_capability_records: bool = _records_include_kind(records, TargetKind.CAPABILITY)
	builder.doc("GFAccess: 自动生成的强类型 GF 访问器。")
	builder.doc()
	builder.doc("该文件由 GFAccessGenerator 生成，可以提交到版本库；请不要手动编辑。")
	builder.line("class_name GFAccess")
	builder.line("extends RefCounted")
	if has_capability_records:
		var capability_utility_script_path: String = _get_capability_utility_script_path(records)
		builder.blank(2)
		builder.section("常量")
		builder.line("const _CAPABILITY_UTILITY_SCRIPT_PATH: String = \"%s\"" % capability_utility_script_path)
	builder.blank(2)
	builder.section("公共方法")
	builder.doc("获取传入架构或当前全局架构。")
	builder.line("static func architecture_or_null(architecture: GFArchitecture = null) -> GFArchitecture:")
	builder.indent()
	builder.line("if architecture != null:")
	builder.indent()
	builder.line("return architecture")
	builder.dedent()
	builder.line("return GFAutoload.get_architecture_or_null()")
	builder.dedent()
	builder.blank()

	var used_names: Dictionary = {}
	for record: Dictionary in records:
		_append_record_function(builder, record, used_names)

	_append_access_generator_extensions(builder, records)

	builder.blank()
	builder.section("私有/辅助方法")
	builder.line("static func _create_instance(script_cls: Script, architecture: GFArchitecture = null) -> Object:")
	builder.indent()
	builder.line("var resolved_architecture: GFArchitecture = architecture_or_null(architecture)")
	builder.line("if resolved_architecture != null and resolved_architecture.has_factory(script_cls):")
	builder.indent()
	builder.line("return resolved_architecture.create_instance(script_cls)")
	builder.dedent()
	builder.blank()
	builder.line("var instance: Object = _instantiate_script(script_cls)")
	builder.line("if resolved_architecture != null:")
	builder.indent()
	builder.line("_inject_if_needed(instance, resolved_architecture)")
	builder.dedent()
	builder.line("return instance")
	builder.dedent()
	if has_capability_records:
		builder.blank(2)
		builder.line("static func _get_capability_utility(architecture: GFArchitecture = null) -> Object:")
		builder.indent()
		builder.line("var resolved_architecture: GFArchitecture = architecture_or_null(architecture)")
		builder.line("if resolved_architecture == null:")
		builder.indent()
		builder.line("return null")
		builder.dedent()
		builder.line("if not ResourceLoader.exists(_CAPABILITY_UTILITY_SCRIPT_PATH):")
		builder.indent()
		builder.line("return null")
		builder.dedent()
		builder.line("var capability_utility_script: Script = _load_script(_CAPABILITY_UTILITY_SCRIPT_PATH)")
		builder.line("if capability_utility_script == null:")
		builder.indent()
		builder.line("return null")
		builder.dedent()
		builder.line("return resolved_architecture.get_utility(capability_utility_script)")
		builder.dedent()
	builder.blank(2)
	builder.line("static func _instantiate_script(script_cls: Script) -> Object:")
	builder.indent()
	builder.line("if script_cls == null or not (script_cls is GDScript):")
	builder.indent()
	builder.line("return null")
	builder.dedent()
	builder.line("var gdscript: GDScript = script_cls")
	builder.line("if not gdscript.can_instantiate():")
	builder.indent()
	builder.line("return null")
	builder.dedent()
	builder.line("var instance_value: Variant = gdscript.new()")
	builder.line("if instance_value is Object:")
	builder.indent()
	builder.line("var instance: Object = instance_value")
	builder.line("return instance")
	builder.dedent()
	builder.line("return null")
	builder.dedent()
	if has_capability_records:
		builder.blank(2)
		builder.line("static func _load_script(path: String) -> Script:")
		builder.indent()
		builder.line("var loaded: Variant = load(path)")
		builder.line("if loaded is Script:")
		builder.indent()
		builder.line("var script: Script = loaded")
		builder.line("return script")
		builder.dedent()
		builder.line("return null")
		builder.dedent()
	builder.blank(2)
	builder.line("static func _inject_if_needed(instance: Object, architecture: GFArchitecture) -> void:")
	builder.indent()
	builder.line("if instance == null or architecture == null:")
	builder.indent()
	builder.line("return")
	builder.dedent()
	builder.line("if instance.has_method(\"_gf_set_dependency_scope\"):")
	builder.indent()
	builder.line("var _scope_result: Variant = instance.call(\"_gf_set_dependency_scope\", architecture)")
	builder.dedent()
	builder.line("if instance.has_method(\"inject_dependencies\"):")
	builder.indent()
	builder.line("var _inject_dependencies_result: Variant = instance.call(\"inject_dependencies\", architecture)")
	builder.dedent()
	builder.line("if instance.has_method(\"inject\"):")
	builder.indent()
	builder.line("var _inject_result: Variant = instance.call(\"inject\", architecture)")
	builder.dedent(2)

	return builder.build()


## 根据项目常量记录生成访问器源码。
## [br]
## @api public
## [br]
## @param records: 生成访问器时使用的类型记录列表。
## [br]
## @schema records: Dictionary with layers, input_actions, and settings arrays.
## [br]
## @return GDScript 源码。
func build_project_source(records: Dictionary) -> String:
	var builder: GFSourceBuilder = GFSourceBuilder.new()
	builder.doc("GFProjectAccess: 自动生成的项目常量访问器。")
	builder.doc()
	builder.doc("该文件由 GFAccessGenerator 生成，可以提交到版本库；请不要手动编辑。")
	builder.line("class_name GFProjectAccess")
	builder.line("extends RefCounted")
	builder.blank(2)
	_append_project_layer_constants(builder, _GF_VARIANT_ACCESS_SCRIPT.get_option_array(records, "layers"))
	_append_project_input_constants(builder, _GF_VARIANT_ACCESS_SCRIPT.get_option_array(records, "input_actions"))
	_append_project_setting_constants(builder, _GF_VARIANT_ACCESS_SCRIPT.get_option_array(records, "settings"))
	return builder.build()


## 保存生成源码到指定路径。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param output_path: 生成文件输出路径。
## [br]
## @param source: GDScript 源码。
## [br]
## @param overwrite_existing: 为 false 时目标已存在会返回 ERR_ALREADY_EXISTS。
## [br]
## @return 写入结果错误码。
func save_source(output_path: String, source: String, overwrite_existing: bool = true) -> Error:
	var report: Dictionary = save_source_with_report(output_path, source, {
		"overwrite_existing": overwrite_existing,
	})
	return _GENERATED_ARTIFACT_REPORT_SCRIPT.get_error_code(report)


## 保存生成源码到指定路径并返回生成产物报告。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param output_path: 生成文件输出路径。
## [br]
## @param source: GDScript 源码。
## [br]
## @param options: 保存选项，支持 overwrite_existing、dry_run、scan_filesystem 和 metadata。
## [br]
## @schema options: Dictionary，可包含 overwrite_existing、dry_run、scan_filesystem 和 metadata。
## [br]
## @return: 生成产物报告。
## [br]
## @schema return: Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、size_bytes 和 metadata。
func save_source_with_report(output_path: String, source: String, options: Dictionary = {}) -> Dictionary:
	var save_options: Dictionary = options.duplicate(true)
	save_options["label"] = "GFAccessGenerator"
	return _GENERATED_ARTIFACT_REPORT_SCRIPT.save_text(output_path, source, save_options)


# --- 私有/辅助方法 ---

func _collect_layer_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for layer_group: String in _LAYER_TYPES.keys():
		var max_count: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_LAYER_TYPES, layer_group)
		for index: int in range(1, max_count + 1):
			var setting_name: String = "layer_names/%s/layer_%d" % [layer_group, index]
			var layer_name: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(ProjectSettings.get_setting(setting_name, "")).strip_edges()
			if layer_name.is_empty():
				continue
			records.append({
				"group": layer_group,
				"name": layer_name,
				"index": index,
			})
	return records


func _collect_input_actions() -> Array[StringName]:
	var action_names: Dictionary = {}
	for property: Dictionary in ProjectSettings.get_property_list():
		var setting_name: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(property, "name")
		if not setting_name.begins_with("input/"):
			continue
		var action_text: String = setting_name.trim_prefix("input/").strip_edges()
		if not _should_include_project_input_action(action_text):
			continue
		action_names[action_text] = true

	var action_ids: Array[StringName] = []
	for action_text: String in action_names.keys():
		action_ids.append(StringName(action_text))
	action_ids.sort_custom(func(left: StringName, right: StringName) -> bool:
		return String(left) < String(right)
	)
	return action_ids


func _collect_gf_project_settings() -> Array[String]:
	var settings_by_name: Dictionary = {}
	for setting_name: String in _KNOWN_GF_PROJECT_SETTINGS:
		settings_by_name[setting_name] = true

	for property: Dictionary in ProjectSettings.get_property_list():
		var setting_name: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(property, "name")
		if setting_name.begins_with("gf/"):
			settings_by_name[setting_name] = true

	var settings: Array[String] = []
	for setting_name: String in settings_by_name.keys():
		settings.append(setting_name)
	settings.sort()
	return settings


func _should_include_project_input_action(action_name: String) -> bool:
	if action_name.is_empty():
		return false
	if action_name.begins_with("ui_"):
		return false
	if action_name.begins_with("spatial_editor/") or action_name.begins_with("editor/"):
		return false
	return true


func _append_project_layer_constants(builder: GFSourceBuilder, layer_records: Array) -> void:
	builder.doc("项目命名层常量。")
	builder.line("class Layers:")
	if layer_records.is_empty():
		builder.indent()
		builder.line("pass")
		builder.dedent()
		builder.blank(2)
		return

	builder.indent()
	var used_names: Dictionary = {}
	for record_variant: Variant in layer_records:
		var record: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(record_variant)
		var group_name: String = _layer_group_constant_prefix(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "group"))
		var layer_name: String = _to_constant_name(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "name"), "LAYER")
		var base_name: String = _make_unique_constant_name("%s_%s" % [group_name, layer_name], used_names)
		var layer_index: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(record, "index")
		var layer_bit: int = 1 << maxi(layer_index - 1, 0)
		builder.line("const %s_LAYER: int = %d" % [base_name, layer_index])
		builder.line("const %s_BIT: int = %d" % [base_name, layer_bit])
	builder.dedent()
	builder.blank(2)


func _append_project_input_constants(builder: GFSourceBuilder, input_actions: Array) -> void:
	builder.doc("项目 InputMap 动作常量。")
	builder.line("class InputActions:")
	if input_actions.is_empty():
		builder.indent()
		builder.line("pass")
		builder.dedent()
		builder.blank(2)
		return

	builder.indent()
	var used_names: Dictionary = {}
	for action_variant: Variant in input_actions:
		var action_name: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(action_variant)
		var constant_name: String = _make_unique_constant_name(_to_constant_name(action_name, "ACTION"), used_names)
		builder.line("const %s: StringName = &\"%s\"" % [constant_name, action_name.c_escape()])
	builder.dedent()
	builder.blank(2)


func _append_project_setting_constants(builder: GFSourceBuilder, settings: Array) -> void:
	builder.doc("GF ProjectSettings 键名常量。")
	builder.line("class Settings:")
	if settings.is_empty():
		builder.indent()
		builder.line("pass")
		builder.dedent()
		builder.blank()
		return

	builder.indent()
	var used_names: Dictionary = {}
	for setting_variant: Variant in settings:
		var setting_name: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(setting_variant)
		var constant_name: String = _make_unique_constant_name(_to_constant_name(setting_name, "SETTING"), used_names)
		builder.line("const %s: String = \"%s\"" % [constant_name, setting_name.c_escape()])
	builder.dedent()
	builder.blank()


func _resolve_kind(script: Script) -> int:
	if script == _BASE_MODEL_SCRIPT or script == _BASE_SYSTEM_SCRIPT or script == _BASE_UTILITY_SCRIPT:
		return -1
	if script == _BASE_COMMAND_SCRIPT or script == _BASE_QUERY_SCRIPT:
		return -1

	if GFScriptTypeInspector.script_extends_or_equals(script, _BASE_MODEL_SCRIPT):
		return TargetKind.MODEL
	if GFScriptTypeInspector.script_extends_or_equals(script, _BASE_SYSTEM_SCRIPT):
		return TargetKind.SYSTEM
	if GFScriptTypeInspector.script_extends_or_equals(script, _BASE_UTILITY_SCRIPT):
		return TargetKind.UTILITY
	if GFScriptTypeInspector.script_extends_or_equals(script, _BASE_COMMAND_SCRIPT):
		return TargetKind.COMMAND
	if GFScriptTypeInspector.script_extends_or_equals(script, _BASE_QUERY_SCRIPT):
		return TargetKind.QUERY

	return -1


func _records_include_kind(records: Array, kind: int) -> bool:
	for record_variant: Variant in records:
		var record: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(record_variant)
		if not record.is_empty() and _GF_VARIANT_ACCESS_SCRIPT.get_option_int(record, "kind", -1) == kind:
			return true
	return false


func _get_capability_utility_script_path(records: Array) -> String:
	for record_variant: Variant in records:
		var record: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(record_variant)
		if record.is_empty() or _GF_VARIANT_ACCESS_SCRIPT.get_option_int(record, "kind", -1) != TargetKind.CAPABILITY:
			continue
		var utility_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "utility_path")
		if not utility_path.is_empty():
			return utility_path
	return ""


func _append_access_generator_extension_records(records: Array[Dictionary]) -> void:
	for extension_path: String in GFExtensionSettings.get_enabled_access_generator_extension_paths():
		var extension: Object = _load_access_generator_extension(extension_path)
		if extension == null:
			continue
		_append_access_generator_extension_records_from_instance(records, extension, extension_path)


func _append_access_generator_extension_records_from_instance(
	records: Array[Dictionary],
	extension: Object,
	_extension_path: String = ""
) -> void:
	if extension == null:
		return
	if not extension.has_method("append_access_records"):
		return
	extension.call("append_access_records", records)


func _append_access_generator_extensions(builder: GFSourceBuilder, records: Array) -> void:
	for extension_path: String in GFExtensionSettings.get_enabled_access_generator_extension_paths():
		_append_access_generator_extension_path(builder, records, extension_path)


func _append_access_generator_extension_path(
	builder: GFSourceBuilder,
	records: Array,
	extension_path: String
) -> void:
	var normalized_path: String = extension_path.strip_edges()
	if normalized_path.is_empty():
		return

	var extension: Object = _load_access_generator_extension(normalized_path)
	if extension == null:
		return

	_append_access_generator_extension(builder, records, extension, normalized_path)


func _append_access_generator_extension(
	builder: GFSourceBuilder,
	records: Array,
	extension: Object,
	extension_path: String = ""
) -> void:
	if extension == null:
		return

	if extension.has_method("append_access_source"):
		extension.call("append_access_source", builder, records)
		return

	if extension.has_method("get_access_source_sections"):
		var sections: Variant = extension.call("get_access_source_sections", records)
		if not (sections is Array or sections is PackedStringArray):
			push_error("[GFAccessGenerator] 访问器扩展返回值必须是数组：%s" % extension_path)
			return
		for section_variant: Variant in sections:
			_append_source_section(builder, _GF_VARIANT_ACCESS_SCRIPT.to_text(section_variant))
		return

	if extension.has_method("append_access_records"):
		return

	push_warning("[GFAccessGenerator] 访问器扩展缺少源码或记录扩展方法：%s" % extension_path)


func _load_access_generator_extension(extension_path: String) -> Object:
	var normalized_path: String = extension_path.strip_edges()
	if normalized_path.is_empty():
		return null

	var extension_script: GDScript = _variant_to_gdscript(load(normalized_path))
	if extension_script == null or not extension_script.can_instantiate():
		push_error("[GFAccessGenerator] 访问器扩展脚本加载失败：%s" % normalized_path)
		return null

	var extension: Object = _variant_to_object(extension_script.call("new"))
	if extension == null:
		push_error("[GFAccessGenerator] 访问器扩展实例创建失败：%s" % normalized_path)
		return null
	return extension


func _append_source_section(builder: GFSourceBuilder, source: String) -> void:
	for line_text: String in source.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
		builder.line(line_text)


func _append_record_function(builder: GFSourceBuilder, record: Dictionary, used_names: Dictionary) -> void:
	var class_name_value: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "class_name")
	var kind: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(record, "kind")
	var function_name: String = _get_function_name(class_name_value, kind)
	if used_names.has(function_name):
		push_warning("[GFAccessGenerator] 函数名重复，已跳过：%s" % function_name)
		return
	used_names[function_name] = true

	match kind:
		TargetKind.MODEL:
			builder.doc("获取 %s Model。" % class_name_value)
			builder.line("static func %s(architecture: GFArchitecture = null) -> %s:" % [function_name, class_name_value])
			builder.indent()
			builder.line("var resolved_architecture: GFArchitecture = architecture_or_null(architecture)")
			builder.line("if resolved_architecture == null:")
			builder.indent()
			builder.line("return null")
			builder.dedent()
			builder.line("var model_value: Variant = resolved_architecture.get_model(%s)" % class_name_value)
			builder.line("if model_value is %s:" % class_name_value)
			builder.indent()
			builder.line("var model: %s = model_value" % class_name_value)
			builder.line("return model")
			builder.dedent()
			builder.line("return null")
			builder.dedent()
			builder.blank(2)

		TargetKind.SYSTEM:
			builder.doc("获取 %s System。" % class_name_value)
			builder.line("static func %s(architecture: GFArchitecture = null) -> %s:" % [function_name, class_name_value])
			builder.indent()
			builder.line("var resolved_architecture: GFArchitecture = architecture_or_null(architecture)")
			builder.line("if resolved_architecture == null:")
			builder.indent()
			builder.line("return null")
			builder.dedent()
			builder.line("var system_value: Variant = resolved_architecture.get_system(%s)" % class_name_value)
			builder.line("if system_value is %s:" % class_name_value)
			builder.indent()
			builder.line("var system: %s = system_value" % class_name_value)
			builder.line("return system")
			builder.dedent()
			builder.line("return null")
			builder.dedent()
			builder.blank(2)

		TargetKind.UTILITY:
			builder.doc("获取 %s Utility。" % class_name_value)
			builder.line("static func %s(architecture: GFArchitecture = null) -> %s:" % [function_name, class_name_value])
			builder.indent()
			builder.line("var resolved_architecture: GFArchitecture = architecture_or_null(architecture)")
			builder.line("if resolved_architecture == null:")
			builder.indent()
			builder.line("return null")
			builder.dedent()
			builder.line("var utility_value: Variant = resolved_architecture.get_utility(%s)" % class_name_value)
			builder.line("if utility_value is %s:" % class_name_value)
			builder.indent()
			builder.line("var utility: %s = utility_value" % class_name_value)
			builder.line("return utility")
			builder.dedent()
			builder.line("return null")
			builder.dedent()
			builder.blank(2)

		TargetKind.COMMAND, TargetKind.QUERY:
			builder.doc("创建 %s 实例。" % class_name_value)
			builder.line("static func %s(architecture: GFArchitecture = null) -> %s:" % [function_name, class_name_value])
			builder.indent()
			builder.line("var instance: Object = _create_instance(%s, architecture)" % class_name_value)
			builder.line("if instance is %s:" % class_name_value)
			builder.indent()
			builder.line("var typed_instance: %s = instance" % class_name_value)
			builder.line("return typed_instance")
			builder.dedent()
			builder.line("return null")
			builder.dedent()
			builder.blank(2)

		TargetKind.CAPABILITY:
			var base_name: String = _trim_suffix(_to_accessor_base_name(class_name_value), "_capability")
			builder.doc("获取 receiver 上的 %s 能力。" % class_name_value)
			builder.line("static func get_%s_capability(receiver: Object, architecture: GFArchitecture = null) -> %s:" % [base_name, class_name_value])
			builder.indent()
			builder.line("var capability_utility: Object = _get_capability_utility(architecture)")
			builder.line("if capability_utility == null:")
			builder.indent()
			builder.line("return null")
			builder.dedent()
			builder.line("var capability_value: Variant = capability_utility.call(\"get_capability\", receiver, %s)" % class_name_value)
			builder.line("if capability_value is %s:" % class_name_value)
			builder.indent()
			builder.line("var capability: %s = capability_value" % class_name_value)
			builder.line("return capability")
			builder.dedent()
			builder.line("return null")
			builder.dedent()
			builder.blank(2)
			builder.doc("给 receiver 添加 %s 能力。" % class_name_value)
			builder.line("static func add_%s_capability(receiver: Object, architecture: GFArchitecture = null) -> %s:" % [base_name, class_name_value])
			builder.indent()
			builder.line("var capability_utility: Object = _get_capability_utility(architecture)")
			builder.line("if capability_utility == null:")
			builder.indent()
			builder.line("return null")
			builder.dedent()
			builder.line("var capability_value: Variant = capability_utility.call(\"add_capability\", receiver, %s)" % class_name_value)
			builder.line("if capability_value is %s:" % class_name_value)
			builder.indent()
			builder.line("var capability: %s = capability_value" % class_name_value)
			builder.line("return capability")
			builder.dedent()
			builder.line("return null")
			builder.dedent()
			builder.blank(2)
			builder.doc("检查 receiver 是否拥有 %s 能力。" % class_name_value)
			builder.line("static func has_%s_capability(receiver: Object, architecture: GFArchitecture = null) -> bool:" % base_name)
			builder.indent()
			builder.line("var capability_utility: Object = _get_capability_utility(architecture)")
			builder.line("if capability_utility == null:")
			builder.indent()
			builder.line("return false")
			builder.dedent()
			builder.line("var has_capability_value: Variant = capability_utility.call(\"has_capability\", receiver, %s)" % class_name_value)
			builder.line("return has_capability_value == true")
			builder.dedent()
			builder.blank(2)
			builder.doc("移除 receiver 上的 %s 能力。" % class_name_value)
			builder.line("static func remove_%s_capability(receiver: Object, architecture: GFArchitecture = null) -> void:" % base_name)
			builder.indent()
			builder.line("var capability_utility: Object = _get_capability_utility(architecture)")
			builder.line("if capability_utility != null:")
			builder.indent()
			builder.line("var _removed: Variant = capability_utility.call(\"remove_capability\", receiver, %s)" % class_name_value)
			builder.dedent(2)
			builder.blank(2)
			builder.doc("当 receiver 拥有 %s 能力时执行回调。" % class_name_value)
			builder.line("static func if_has_%s_capability(receiver: Object, callback: Callable, architecture: GFArchitecture = null) -> Variant:" % base_name)
			builder.indent()
			builder.line("var capability: %s = get_%s_capability(receiver, architecture)" % [class_name_value, base_name])
			builder.line("if capability == null or not callback.is_valid():")
			builder.indent()
			builder.line("return null")
			builder.dedent()
			builder.line("return callback.call(capability)")
			builder.dedent()
			builder.blank(2)


func _get_function_name(class_name_value: String, kind: int) -> String:
	var base_name: String = _to_accessor_base_name(class_name_value)
	match kind:
		TargetKind.MODEL:
			return "get_%s_model" % _trim_suffix(base_name, "_model")
		TargetKind.SYSTEM:
			return "get_%s_system" % _trim_suffix(base_name, "_system")
		TargetKind.UTILITY:
			return "get_%s_utility" % _trim_suffix(base_name, "_utility")
		TargetKind.COMMAND:
			return "create_%s_command" % _trim_suffix(base_name, "_command")
		TargetKind.QUERY:
			return "create_%s_query" % _trim_suffix(base_name, "_query")
		TargetKind.CAPABILITY:
			return "get_%s_capability" % _trim_suffix(base_name, "_capability")
		_:
			return base_name


func _to_accessor_base_name(class_name_value: String) -> String:
	if class_name_value.begins_with("GF") and class_name_value.length() > 2:
		return "gf_%s" % class_name_value.substr(2).to_snake_case()
	return class_name_value.to_snake_case()


func _trim_suffix(value: String, suffix: String) -> String:
	if value.ends_with(suffix):
		return value.substr(0, value.length() - suffix.length())
	return value


func _layer_group_constant_prefix(layer_group: String) -> String:
	match layer_group:
		"2d_render":
			return "RENDER_2D"
		"2d_physics":
			return "PHYSICS_2D"
		"2d_navigation":
			return "NAVIGATION_2D"
		"3d_render":
			return "RENDER_3D"
		"3d_physics":
			return "PHYSICS_3D"
		"3d_navigation":
			return "NAVIGATION_3D"
		_:
			return _to_constant_name(layer_group, "LAYER_GROUP")


func _to_constant_name(value: String, fallback: String) -> String:
	var snake: String = value.to_snake_case().to_upper()
	var result: String = ""
	var previous_was_separator: bool = false
	for index: int in range(snake.length()):
		var code: int = snake.unicode_at(index)
		var valid: bool = (
			(code >= 65 and code <= 90)
			or (code >= 48 and code <= 57)
			or code == 95
		)
		if valid:
			result += snake.substr(index, 1)
			previous_was_separator = code == 95
		elif not previous_was_separator:
			result += "_"
			previous_was_separator = true

	result = result.strip_edges().trim_prefix("_").trim_suffix("_")
	if result.is_empty():
		result = fallback
	if result.unicode_at(0) >= 48 and result.unicode_at(0) <= 57:
		result = "%s_%s" % [fallback, result]
	return result


func _make_unique_constant_name(base_name: String, used_names: Dictionary) -> String:
	var candidate: String = base_name
	var index: int = 2
	while used_names.has(candidate):
		candidate = "%s_%d" % [base_name, index]
		index += 1
	used_names[candidate] = true
	return candidate


func _sort_records(records: Array[Dictionary]) -> void:
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_kind: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(left, "kind")
		var right_kind: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(right, "kind")
		if left_kind != right_kind:
			return left_kind < right_kind
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_string(left, "class_name") < _GF_VARIANT_ACCESS_SCRIPT.get_option_string(right, "class_name")
	)


func _store_file_string(file: FileAccess, value: String) -> void:
	var _stored: bool = file.store_string(value)


func _variant_to_gdscript(value: Variant) -> GDScript:
	if value is GDScript:
		return value
	return null


func _variant_to_object(value: Variant) -> Object:
	if value is Object:
		return value
	return null


func _variant_to_script(value: Variant) -> Script:
	if value is Script:
		return value
	return null
